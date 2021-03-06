#ifdef __CUDACC__

#include "tf_kernel.h"

#define KERNEL_SIZE 128

namespace TF = tensorflow;

template <typename T>
__global__ void InteractiveInputKernel(int width, int height, size_t pitch, float min, float max, const unsigned char* normals, const float* depth, T* out) {

	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	const unsigned char *normal_src;
	const float *depth_src;
	const float range = max - min;
	T *dest;

	// in the case where, due to quantization into grids, we have
	// more threads than pixels, skip the threads which don't
	// correspond to valid pixels
	if (x >= width || y >= height || x < 0 || y < 0) return;

	// get a pointer to the pixel at (x,y)
	normal_src = (normals + y*pitch) + 4*x;
	depth_src = (depth + y*pitch/4) + x;
	dest = (out + y*pitch) + 4*x;

	dest[0] = ((T) normal_src[0]) / 255.0f;
	dest[1] = ((T) normal_src[1]) / 255.0f;
	dest[2] = ((T) normal_src[2]) / 255.0f;
	dest[3] = (T) ((depth_src[0] - min) / range);
}

template <typename T>
__global__ void InteractiveNormalsInputKernel(int width, int height, size_t pitch, const unsigned char* in, T* out) {

	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	const unsigned char *src;
	T *dest;

	// in the case where, due to quantization into grids, we have
	// more threads than pixels, skip the threads which don't
	// correspond to valid pixels
	if (x >= width || y >= height) return;

	// get a pointer to the pixel at (x,y)
	src = (in + y*pitch) + 4*x;
	dest = (out + y*pitch) + 4*x;

	dest[0] = ((T) src[0]) / 255.0f;
	dest[1] = ((T) src[1]) / 255.0f;
	dest[2] = ((T) src[2]) / 255.0f;
	dest[3] = ((T) src[3]) / 255.0f;
}

template <typename T>
__global__ void InteractiveDepthInputKernel(int width, int height, size_t pitch, float min, float max, const float* in, T* out) {

	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	const float *src;
	const float range = max - min;
	T *dest;

	// in the case where, due to quantization into grids, we have
	// more threads than pixels, skip the threads which don't
	// correspond to valid pixels
	if (x >= width || y >= height) return;

	// get a pointer to the pixel at (x,y)
	src = (in + y*pitch/4) + x;
	dest = (out + y*pitch) + 4*x;

	dest[0] = (T) ((src[0] - min) / range);
	dest[1] = (T) ((src[0] - min) / range);
	dest[2] = (T) ((src[0] - min) / range);
	dest[3] = (T) ((src[0] - min) / range);
}

template <typename T>
__global__ void InteractiveOutputKernel(int width, int height, size_t pitch, const T* in, float* out) {

	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	const T *cuda_src;
	float *dest;

	// in the case where, due to quantization into grids, we have
	// more threads than pixels, skip the threads which don't
	// correspond to valid pixels
	if (x >= width || y >= height) return;

	// get a pointer to the pixel at (x,y)
	cuda_src = (in + y*pitch/4) + x;
	dest = (out + y*pitch/4) + x;

	*dest = (float) (*cuda_src);
}

template <typename T>
__global__ void InteractiveDepthOutputKernel(int width, int height, size_t pitch, float min, float max, const T* in, float* out) {

	int x = blockIdx.x*blockDim.x + threadIdx.x;
	int y = blockIdx.y*blockDim.y + threadIdx.y;
	const T *src;
	const float range = max - min;
	float *dest;

	// in the case where, due to quantization into grids, we have
	// more threads than pixels, skip the threads which don't
	// correspond to valid pixels
	if (x >= width || y >= height) return;

	// get a pointer to the pixel at (x,y)
	src = (in + y*pitch) + 4*x;
	dest = (out + y*pitch/4) + x;

	*dest = (float) (src[1] * range) + min;
}

template <typename T>
struct InteractiveInputFunctor<Eigen::GpuDevice, T> {
	cudaError_t operator()(const Eigen::GpuDevice& d, int width, int height, size_t pitch, float min, float max, const void* normals, const void* depth, T* out) {
		dim3 blockSize = dim3(KERNEL_SIZE, KERNEL_SIZE);
		dim3 threadSize = dim3((width + blockSize.x - 1) / blockSize.x, (height + blockSize.y - 1) / blockSize.y);
		InteractiveInputKernel<T><<<blockSize, threadSize, 0, d.stream()>>>(width, height, pitch, min, max, (const unsigned char *)normals, (const float *)depth, out);
		return cudaGetLastError();
	}
};

template <typename T>
struct InteractiveNormalsInputFunctor<Eigen::GpuDevice, T> {
	cudaError_t operator()(const Eigen::GpuDevice& d, int width, int height, size_t pitch, const void* in, T* out) {
		dim3 blockSize = dim3(KERNEL_SIZE, KERNEL_SIZE);
		dim3 threadSize = dim3((width + blockSize.x - 1) / blockSize.x, (height + blockSize.y - 1) / blockSize.y);
		InteractiveNormalsInputKernel<T><<<blockSize, threadSize, 0, d.stream()>>>(width, height, pitch, (const unsigned char *) in, out);
		return cudaGetLastError();
	}
};

template <typename T>
struct InteractiveDepthInputFunctor<Eigen::GpuDevice, T> {
	cudaError_t operator()(const Eigen::GpuDevice& d, int width, int height, size_t pitch, float min, float max, const void* in, T* out) {
		dim3 blockSize = dim3(KERNEL_SIZE, KERNEL_SIZE);
		dim3 threadSize = dim3((width + blockSize.x - 1) / blockSize.x, (height + blockSize.y - 1) / blockSize.y);
		InteractiveDepthInputKernel<T><<<blockSize, threadSize, 0, d.stream()>>>(width, height, pitch, min, max, (const float *) in, out);
		return cudaGetLastError();
	}
};

template <typename T>
struct InteractiveOutputFunctor<Eigen::GpuDevice, T> {
	cudaError_t operator()(const Eigen::GpuDevice& d, int width, int height, size_t pitch, const T* in, void* out) {
		dim3 blockSize = dim3(KERNEL_SIZE, KERNEL_SIZE);
		dim3 threadSize = dim3((width + blockSize.x - 1) / blockSize.x, (height + blockSize.y - 1) / blockSize.y);
		InteractiveOutputKernel<T><<<blockSize, threadSize, 0, d.stream()>>>(width, height, pitch, in, (float *) out);
		return cudaGetLastError();
	}
};

template <typename T>
struct InteractiveDepthOutputFunctor<Eigen::GpuDevice, T> {
	cudaError_t operator()(const Eigen::GpuDevice& d, int width, int height, size_t pitch, float min, float max, const T* in, void* out) {
		dim3 blockSize = dim3(KERNEL_SIZE, KERNEL_SIZE);
		dim3 threadSize = dim3((width + blockSize.x - 1) / blockSize.x, (height + blockSize.y - 1) / blockSize.y);
		InteractiveDepthOutputKernel<T><<<blockSize, threadSize, 0, d.stream()>>>(width, height, pitch, min, max, in, (float *) out);
		return cudaGetLastError();
	}
};

template struct InteractiveInputFunctor<Eigen::GpuDevice, float>;
template struct InteractiveNormalsInputFunctor<Eigen::GpuDevice, float>;
template struct InteractiveDepthInputFunctor<Eigen::GpuDevice, float>;
template struct InteractiveOutputFunctor<Eigen::GpuDevice, float>;
template struct InteractiveDepthOutputFunctor<Eigen::GpuDevice, float>;

#endif  // __CUDACC__