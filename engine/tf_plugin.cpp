#include "tf_plugin.h"

namespace PLUGIN_NAMESPACE
{
	//#define WAITFORDEBUGGER
	#define checkCUDAError(msg) if(getLastCudaError (msg, __FILE__, __LINE__)) return
	#define MEASURE_TIME

	namespace SPF = stingray_plugin_foundation;
	namespace TF = tensorflow;

	// Typedefs to use the high precision time measure clock
	typedef std::ratio<1l, 1000000000000l> pico;
	typedef std::chrono::duration<long long, pico> picoseconds;
	typedef std::ratio<1l, 1000000l> micro;
	typedef std::chrono::duration<long long, micro> microseconds;

	// Checks to see if the plugin apis have been properly initialized
	bool _compiler_api_initialized = false;
	bool _game_api_initialized = false;

	// This is actually bad, should find a more flexible solution at some point
	const unsigned NUMBER_OF_CHANNELS = 4;

	// pointers to the render resources we are flushing through the network
	enum RenderTargetStep { ReceivingNormals, ReceivingDepth, ReceivingNNAO, ReceivedEverything };
	static RenderResource *normals_resource = nullptr;
	static ID3D11Texture2D *normals_render_target = nullptr;
	static RenderResource *depth_resource = nullptr;
	static ID3D11Texture2D *depth_render_target = nullptr;
	static RenderResource *nnao_resource = nullptr;
	static ID3D11Texture2D *nnao_render_target = nullptr;
	static RenderTargetStep step_identifier = ReceivingNormals;

	// Structure to define a tensorflow session, only one is supported right now
	struct Graph_Execution_Session
	{
		bool initialized = false;
		unsigned texture_width;
		unsigned texture_height;
		unsigned iterations_done;
		unsigned iterations_max;
		uint32_t override_texture_id;
		std::string output_node_name;
		cudaArray *normals_array = nullptr;
		cudaArray *depth_array = nullptr;
		cudaArray *ao_array = nullptr;
		cudaGraphicsResource *normals_resource = nullptr;
		ID3D11Texture2D *normals_texture = nullptr;
		cudaGraphicsResource *depth_resource = nullptr;
		ID3D11Texture2D *depth_texture = nullptr;
		cudaGraphicsResource *ao_resource = nullptr;
		ID3D11Texture2D *ao_texture = nullptr;
		TF::Tensor *zero_input = nullptr;
		TF::Session *tf_session = nullptr;
		TF::GraphDef tf_graph;
	};

	static Graph_Execution_Session *session = nullptr;

	void wait_for_debugger()
	{
	#ifdef WAITFORDEBUGGER
		while( !IsDebuggerPresent() )
				Sleep( 100 ); 
	#endif
	}

	ApiInterface _api;
	ApiInterface& TFPlugin::get_api()
	{
		return _api;
	}

	SPF::ApiAllocator _tensorflow_allocator = SPF::ApiAllocator(nullptr, nullptr);
	SPF::ApiAllocator& TFPlugin::get_allocator()
	{
		return _tensorflow_allocator;
	}

	void init_compiler_api(GetApiFunction get_engine_api)
	{
		_api._data_compiler = static_cast<DataCompilerApi *>(get_engine_api(DATA_COMPILER_API_ID));
		_api._data_compile_parameters = static_cast<DataCompileParametersApi*>(get_engine_api(DATA_COMPILE_PARAMETERS_API_ID));
		_api._resource_manager = static_cast<ResourceManagerApi*>(get_engine_api(RESOURCE_MANAGER_API_ID));
		_api._application = static_cast<ApplicationApi*>(get_engine_api(APPLICATION_API_ID));
		_api._allocator = static_cast<AllocatorApi*>(get_engine_api(ALLOCATOR_API_ID));
		_api._allocator_object = _api._allocator->make_plugin_allocator(TFPlugin::get_name());
		_tensorflow_allocator = SPF::ApiAllocator(_api._allocator, _api._allocator_object);
		_compiler_api_initialized = true;
	}

	void init_game_api(GetApiFunction get_engine_api)
	{
		_api._render_buffer = static_cast<RenderBufferApi*>(get_engine_api(RENDER_BUFFER_API_ID));
		_api._render_interface = static_cast<RenderInterfaceApi*>(get_engine_api(RENDER_INTERFACE_API_ID));
		_api._capture = static_cast<StreamCaptureApi*>(get_engine_api(STREAM_CAPTURE_API_ID));
		_api._mesh = static_cast<MeshObjectApi*>(get_engine_api(MESH_API_ID));
		_api._material = static_cast<MaterialApi*>(get_engine_api(MATERIAL_API_ID));
		_api._lua = static_cast<LuaApi*>(get_engine_api(LUA_API_ID));
		_api._logging = static_cast<LoggingApi*>(get_engine_api(LOGGING_API_ID));
		_api._error = static_cast<ErrorApi*>(get_engine_api(ERROR_API_ID));
		_api._file_system = static_cast<FileSystemApi*>(get_engine_api(FILESYSTEM_API_ID));
		_api._resource_manager = static_cast<ResourceManagerApi*>(get_engine_api(RESOURCE_MANAGER_API_ID));
		_api._options = static_cast<ApplicationOptionsApi*>(get_engine_api(APPLICATION_OPTIONS_API_ID));
		_api._allocator = static_cast<AllocatorApi*>(get_engine_api(ALLOCATOR_API_ID));
		_api._allocator_object = _api._allocator->make_plugin_allocator(TFPlugin::get_name());
		_tensorflow_allocator = SPF::ApiAllocator(_api._allocator, _api._allocator_object);
		_game_api_initialized = true;
	}

	void deinit_game_api()
	{
		_api._allocator->destroy_plugin_allocator(_api._allocator_object);
		_api._allocator = nullptr;
		_api._render_buffer = nullptr;
		_api._render_interface = nullptr;
		_api._capture = nullptr;
		_api._mesh = nullptr;
		_api._material = nullptr;
		_api._lua = nullptr;
		_api._error = nullptr;
		_api._logging = nullptr;
		_api._file_system = nullptr;
		_api._resource_manager = nullptr;
		_game_api_initialized = false;
	}

	void deinit_compiler_api()
	{
		_api._data_compiler = nullptr;
		_api._data_compile_parameters = nullptr;
		_api._allocator->destroy_plugin_allocator(_api._allocator_object);
		_api._data_compiler = nullptr;
		_api._data_compile_parameters = nullptr;
		_api._resource_manager = nullptr;
		_api._application = nullptr;
		_api._allocator = nullptr;
		_compiler_api_initialized = false;
	}

	bool TFPlugin::read_tf_graph(const std::string &path, unsigned mode, TF::GraphDef *def)
	{
		TF::Status status;
		if (mode == 0)
			status = TF::ReadBinaryProto(TF::Env::Default(), path, def);
		else if (mode == 1)
			status = TF::ReadTextProto(TF::Env::Default(), path, def);

		if (!status.ok())
		{
			_api._logging->error(get_name(), status.ToString().c_str());
			return false;
		}

		return true;
	}

	// Exposed to LUA
	void TFPlugin::run_tf_graph(const char *texture_name, const char *graph_name, const char *node, unsigned iterations)
	{
		if (normals_render_target == nullptr || depth_render_target == nullptr || nnao_render_target == nullptr)
		{
			_api._logging->error(get_name(), "Could not initialize Tensorflow Graph Session, Render Targets are missing.");
			return;
		}

		session = MAKE_NEW(get_allocator(), Graph_Execution_Session);
		session->output_node_name = node;
		session->iterations_done = 0;
		session->iterations_max = iterations;

		ID3D11Device* device = reinterpret_cast<ID3D11Device*>(_api._render_interface->device());
		ID3D11DeviceContext *immediate_context;
		device->GetImmediateContext(&immediate_context);

		D3D11_TEXTURE2D_DESC desc;
		normals_render_target->GetDesc(&desc);
		session->texture_width = desc.Width;
		session->texture_height = desc.Height;
		desc.MipLevels = 1;
		desc.ArraySize = 1;
		desc.Format = DXGI_FORMAT_R8G8B8A8_UINT;
		desc.SampleDesc.Count = 1;
		desc.Usage = D3D11_USAGE_DEFAULT;
		device->CreateTexture2D(&desc, nullptr, &session->normals_texture);
		device->CreateTexture2D(&desc, nullptr, &session->ao_texture);
		immediate_context->CopyResource(session->normals_texture, normals_render_target);

		cudaGraphicsD3D11RegisterResource(&session->normals_resource, session->normals_texture, cudaGraphicsRegisterFlagsNone);
		checkCUDAError("cudaGraphicsD3D11RegisterResource() failed");

		cudaGraphicsD3D11RegisterResource(&session->ao_resource, session->ao_texture, cudaGraphicsRegisterFlagsNone);
		checkCUDAError("cudaGraphicsD3D11RegisterResource() failed");

		D3D11_TEXTURE2D_DESC depthDesc;
		depth_render_target->GetDesc(&depthDesc);
		depthDesc.MipLevels = 1;
		depthDesc.ArraySize = 1;
		depthDesc.Format = DXGI_FORMAT_R32_FLOAT;
		depthDesc.SampleDesc.Count = 1;
		depthDesc.Usage = D3D11_USAGE_DEFAULT;
		device->CreateTexture2D(&depthDesc, nullptr, &session->depth_texture);
		immediate_context->CopyResource(session->depth_texture, depth_render_target);

		cudaGraphicsD3D11RegisterResource(&session->depth_resource, session->depth_texture, cudaGraphicsRegisterFlagsNone);
		checkCUDAError("cudaGraphicsD3D11RegisterResource() failed");

		void* inputLinearMemory = nullptr;
		void* depthLinearMemory = nullptr;
		void* outputLinearMemory = nullptr;
		size_t mainPitch = 0;
		size_t depthPitch = 0;

		cudaMallocPitch(&inputLinearMemory, &mainPitch, session->texture_width * sizeof(unsigned char) * NUMBER_OF_CHANNELS, session->texture_height);
		checkCUDAError("cudaMallocPitch() failed");
		cudaMallocPitch(&depthLinearMemory, &depthPitch, session->texture_width * sizeof(float), session->texture_height);
		checkCUDAError("cudaMallocPitch() failed");

		if (mainPitch != depthPitch)
		{
			_api._logging->error(get_name(), "Input Data have different memory layout, not supported.");
			return;
		}

		cudaMallocPitch(&outputLinearMemory, &mainPitch, session->texture_width * sizeof(unsigned char) * NUMBER_OF_CHANNELS, session->texture_height);
		checkCUDAError("cudaMallocPitch() failed");

		if (mainPitch != depthPitch)
		{
			_api._logging->error(get_name(), "Input Data have different memory layout, not supported.");
			return;
		}

		cudaMemset(inputLinearMemory, 1, mainPitch * session->texture_height);
		checkCUDAError("cudaMemset() failed");
		cudaMemset(depthLinearMemory, 1, mainPitch * session->texture_height);
		checkCUDAError("cudaMemset() failed");
		cudaMemset(outputLinearMemory, 1, mainPitch * session->texture_height);
		checkCUDAError("cudaMemset() failed");

		cudaGraphicsResourceSetMapFlags(session->normals_resource, cudaGraphicsMapFlagsNone);
		checkCUDAError("cudaGraphicsResourceSetMapFlags() failed");
		cudaGraphicsResourceSetMapFlags(session->depth_resource, cudaGraphicsMapFlagsNone);
		checkCUDAError("cudaGraphicsResourceSetMapFlags() failed");
		cudaGraphicsResourceSetMapFlags(session->ao_resource, cudaGraphicsMapFlagsNone);
		checkCUDAError("cudaGraphicsResourceSetMapFlags() failed");
		cudaGraphicsMapResources(1, &session->normals_resource);
		checkCUDAError("cudaGraphicsMapResources() failed");
		cudaGraphicsMapResources(1, &session->depth_resource);
		checkCUDAError("cudaGraphicsMapResources() failed");
		cudaGraphicsMapResources(1, &session->ao_resource);
		checkCUDAError("cudaGraphicsMapResources() failed");

		cudaGraphicsSubResourceGetMappedArray(&session->normals_array, session->normals_resource, 0, 0);
		checkCUDAError("cudaGraphicsSubResourceGetMappedArray() failed");
		cudaGraphicsSubResourceGetMappedArray(&session->depth_array, session->depth_resource, 0, 0);
		checkCUDAError("cudaGraphicsSubResourceGetMappedArray() failed");
		cudaGraphicsSubResourceGetMappedArray(&session->ao_array, session->ao_resource, 0, 0);
		checkCUDAError("cudaGraphicsSubResourceGetMappedArray() failed");

		TFCuda::set_input_memory_pointer(inputLinearMemory);
		TFCuda::set_depth_memory_pointer(depthLinearMemory);
		TFCuda::set_output_memory_pointer(outputLinearMemory);
		TFCuda::set_pitch(mainPitch);
		TFCuda::set_api(&_api);

		// Create tensor input data to fulfill graph conditions, could maybe refactored later
		session->zero_input = new TF::Tensor(TF::DT_FLOAT, TF::TensorShape({ 1, session->texture_width, session->texture_height, NUMBER_OF_CHANNELS }));

		// Create a new Tensorflow Session
		TF::SessionOptions options = TF::SessionOptions();
		options.config.mutable_gpu_options()->set_allow_growth(true);
		options.config.mutable_gpu_options()->set_per_process_gpu_memory_fraction(0.5);
		session->tf_session = NewSession(options);
		read_tf_graph(graph_name, 1, &session->tf_graph);
		TF::Status status = session->tf_session->Create(session->tf_graph);
		if (!status.ok()) {
			_api._logging->error(get_name(), status.ToString().c_str());
		}
		session->initialized = true;
	}

	void TFPlugin::end_tf_execution()
	{
		if (session)
		{
			cudaGraphicsUnmapResources(1, &session->normals_resource);
			checkCUDAError("cudaGraphicsUnmapResources() failed");
			cudaGraphicsUnmapResources(1, &session->depth_resource);
			checkCUDAError("cudaGraphicsUnmapResources() failed");
			cudaGraphicsUnmapResources(1, &session->ao_resource);
			checkCUDAError("cudaGraphicsUnmapResources() failed");
			cudaGraphicsUnregisterResource(session->normals_resource);
			checkCUDAError("cudaGraphicsUnregisterResource() failed");
			cudaGraphicsUnregisterResource(session->depth_resource);
			checkCUDAError("cudaGraphicsUnregisterResource() failed");
			cudaGraphicsUnregisterResource(session->ao_resource);
			checkCUDAError("cudaGraphicsUnregisterResource() failed");
			cudaFree(TFCuda::get_input_memory_pointer());
			checkCUDAError("cudaFree() failed");
			cudaFree(TFCuda::get_depth_memory_pointer());
			checkCUDAError("cudaFree() failed");
			cudaFree(TFCuda::get_output_memory_pointer());
			checkCUDAError("cudaFree() failed");
			session->normals_texture->Release();
			session->depth_texture->Release();
			session->ao_texture->Release();
			MAKE_DELETE(get_allocator(), session);
			session = nullptr;
		}
	}

	void TFPlugin::setup_plugin(GetApiFunction get_engine_api)
	{	
		wait_for_debugger();

		if (!TF::IsGoogleCudaEnabled())
		{
			_api._logging->error(get_name(), "Could not initiate Tensorflow Plugin, no GPU support found.");
			return;
		}

		if (!_game_api_initialized)
			init_game_api(get_engine_api);
		setup_lua();

		// Register the Interactive Ops and Kernels
		REGISTER_OP("InteractiveNormalsInput")
			.Input("interactive_input: float")
			.Output("from_interactive: float")
			.SetShapeFn(::tensorflow::shape_inference::UnchangedShape);

		REGISTER_OP("InteractiveDepthInput")
			.Input("interactive_input: float")
			.Output("from_interactive: float")
			.SetShapeFn(::tensorflow::shape_inference::UnchangedShape);

		REGISTER_OP("InteractiveOutput")
			.Input("to_interactive: float")
			.Output("interactive_output: float")
			.SetShapeFn(::tensorflow::shape_inference::UnchangedShape);
		REGISTER_KERNEL_BUILDER(Name("InteractiveNormalsInput").Device(TF::DEVICE_GPU), InteractiveNormalsInputOp<Eigen::GpuDevice, float>);
		REGISTER_KERNEL_BUILDER(Name("InteractiveDepthInput").Device(TF::DEVICE_GPU), InteractiveDepthInputOp<Eigen::GpuDevice, float>);
		REGISTER_KERNEL_BUILDER(Name("InteractiveOutput").Device(TF::DEVICE_GPU), InteractiveOutputOp<Eigen::GpuDevice, float>);
	}

	void TFPlugin::update_plugin(float dt)
	{}

	void TFPlugin::end_frame()
	{
		step_identifier = ReceivingNormals;
	}

	void TFPlugin::render(RenderDevicePluginArguments *arguments)
	{
		RenderResource *target = static_cast<RenderResource*>(arguments->engine_data.render_target);

		switch (step_identifier) {
			case ReceivingNormals:
				normals_resource = target;
				normals_render_target = reinterpret_cast<ID3D11Texture2D*>(_api._render_interface->texture_2d(normals_resource).texture);
				step_identifier = ReceivingDepth;
				break;

			case ReceivingDepth:
				depth_resource = target;
				depth_render_target = reinterpret_cast<ID3D11Texture2D*>(_api._render_interface->texture_2d(depth_resource).texture);
				step_identifier = ReceivingNNAO;
				break;

			case ReceivingNNAO:
				nnao_resource = target;
				nnao_render_target = reinterpret_cast<ID3D11Texture2D*>(_api._render_interface->texture_2d(nnao_resource).texture);
				step_identifier = ReceivedEverything;
				break;

			default:
				return;
		}

		if (step_identifier == ReceivedEverything && session && session->initialized)
		{
			ID3D11Device* device = reinterpret_cast<ID3D11Device*>(_api._render_interface->device());
			ID3D11DeviceContext *immediate_context;
			device->GetImmediateContext(&immediate_context);

			immediate_context->CopyResource(session->normals_texture, normals_render_target);
			immediate_context->CopyResource(session->depth_texture, depth_render_target);
			immediate_context->Flush();

			cudaMemcpy2DFromArray(TFCuda::get_input_memory_pointer(), TFCuda::get_pitch(), session->normals_array, 0, 0, session->texture_width * sizeof(unsigned char) * NUMBER_OF_CHANNELS, session->texture_height, cudaMemcpyDefault);
			checkCUDAError("cudaMemcpy2DFromArray() failed");

			cudaMemcpy2DFromArray(TFCuda::get_depth_memory_pointer(), TFCuda::get_pitch(), session->depth_array, 0, 0, session->texture_width * sizeof(float), session->texture_height, cudaMemcpyDefault);
			checkCUDAError("cudaMemcpy2DFromArray() failed");

			cudaDeviceSynchronize();
			checkCUDAError("cudaDeviceSynchronize failed");

			// Create input and output data structures and execute tensorflow graph
			std::vector<std::pair<std::string, tensorflow::Tensor>> inputs = { { "input", *session->zero_input } };
			std::vector<TF::Tensor> out_tensors;

#ifdef MEASURE_TIME
			auto t1 = std::chrono::system_clock::now();
#endif
			TF::Status status = session->tf_session->Run({ inputs }, { session->output_node_name }, {}, &out_tensors);
#ifdef MEASURE_TIME
			auto t2 = std::chrono::system_clock::now();
			auto time_amount = std::chrono::duration_cast<std::chrono::milliseconds>(t2 - t1);
			_api._logging->warning(get_name(), _api._error->eprintf("Running the Tensorflow Graph took: `%lld` milliseconds.", time_amount.count()));
#endif
			if (!status.ok()) {
				_api._logging->error(get_name(), status.ToString().c_str());
				end_tf_execution();
				return;
			}

			cudaDeviceSynchronize();
			checkCUDAError("cudaDeviceSynchronize failed");

			cudaMemcpy2DToArray(session->ao_array, 0, 0, TFCuda::get_output_memory_pointer(), TFCuda::get_pitch(), session->texture_width * NUMBER_OF_CHANNELS * sizeof(unsigned char), session->texture_height, cudaMemcpyDefault);
			checkCUDAError("cudaMemcpy2DToArray failed");

			cudaDeviceSynchronize();
			checkCUDAError("cudaDeviceSynchronize failed");

			//ID3D11Texture2D *back_buffer;
			//IDXGISwapChain *swap_chain = _api._render_interface->swap_chain(0).dxgi_swap_chain;
			//swap_chain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&back_buffer);
			//immediate_context->CopyResource(back_buffer, session->normals_texture);
			immediate_context->CopyResource(nnao_render_target, session->normals_texture);
			immediate_context->Flush();
			++session->iterations_done;

			if (session->iterations_done >= session->iterations_max)
				end_tf_execution();
		}
	}

	bool TFPlugin::getLastCudaError(const char *errorMessage, const char *file, const int line)
	{
		cudaError_t err = cudaGetLastError();

		if (cudaSuccess != err)
		{
			_api._logging->error(get_name(), _api._error->eprintf("%s(%i) : getLastCudaError() CUDA error : %s : (%d) %s.\n", file, line, errorMessage, static_cast<int>(err), cudaGetErrorString(err)));
			return true;
		}
		return false;
	}

	void TFPlugin::shutdown_plugin()
	{
		end_tf_execution();
	}

	void TFPlugin::setup_data_compiler(GetApiFunction get_engine_api)
	{
		if (!_compiler_api_initialized)
			init_compiler_api(get_engine_api);
	}

	void TFPlugin::shutdown_data_compiler()
	{
		deinit_compiler_api();
	}

	const char *TFPlugin::get_name()
	{
		return "TensorflowPlugin";
	}

	int TFPlugin::can_refresh(uint64_t type)
	{
		return false;
	}

	void* TFPlugin::get_render_env()
	{
		return nullptr;
	}
}
