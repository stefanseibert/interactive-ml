cmake_minimum_required(VERSION 3.8)

# Set each source file proper source group
macro(set_source_groups pList)
	foreach(FilePath ${pList})
		get_filename_component(DirName ${FilePath} DIRECTORY)
		if( NOT "${DirName}" STREQUAL "" )
			string(REGEX REPLACE "[.][.][/]" "" GroupName "${DirName}")
			string(REGEX REPLACE "/" "\\\\" GroupName "${GroupName}")
			source_group("${GroupName}" FILES ${FilePath})
		else()
			source_group("" FILES ${FilePath})
		endif()
	endforeach()
endmacro()

# Get all source files recursively and add them to pResult
macro(find_source_files_of_type pFileExtensions pResult)
	set(FileList)
	set(SearchDir "${ARGN}")

	# Retrive all source files recursively
	if( "${SearchDir}" STREQUAL "" )
		file(GLOB_RECURSE FileList RELATIVE ${PROJECT_SOURCE_DIR} ${pFileExtensions})
	else()
		set(UpdatedFileExtensions)
		foreach(FileExtension ${pFileExtensions})
			list(APPEND UpdatedFileExtensions "${SearchDir}/${FileExtension}")
		endforeach()
		file(GLOB_RECURSE FileList RELATIVE ${PROJECT_SOURCE_DIR} ${UpdatedFileExtensions})
	endif()
	list(APPEND ${pResult} ${FileList})

	set_source_groups("${FileList}")
endmacro()

# Get all source files recursively and add them to pResult
macro(find_source_files pResult)
	set(FileList)
	set(SearchDir "${ARGN}")

	# Retrive all source files recursively
	set(FileExtensions)
	list(APPEND FileExtensions "*.h" "*.c" "*.cpp" "*.inl" "*.cc")
	if( PLATFORM_OSX OR PLATFORM_IOS )
		list(APPEND FileExtensions "*.m" "*.mm")
	endif()
	if( "${SearchDir}" STREQUAL "" )
		file(GLOB_RECURSE FileList RELATIVE ${PROJECT_SOURCE_DIR} ${FileExtensions})
	else()
		set(UpdatedFileExtensions)
		foreach(FileExtension ${FileExtensions})
			list(APPEND UpdatedFileExtensions "${SearchDir}/${FileExtension}")
		endforeach()
		file(GLOB_RECURSE FileList RELATIVE ${PROJECT_SOURCE_DIR} ${UpdatedFileExtensions})
	endif()
	list(APPEND ${pResult} ${FileList})

	set_source_groups("${FileList}")

	# Patch for Android compiler that refuse -std=c++11 flag on .c files.
	# Normally we would use CMAKE_CXX_FLAGS to add this flag only to .cpp files,
	# but somehow with NVidia NSight Tegra it also passes to .c files.
	if( PLATFORM_ANDROID OR PLATFORM_WEB )
		foreach(FilePath ${FileList})
			get_filename_component(ExtName ${FilePath} EXT)
			if( "${ExtName}" STREQUAL ".cpp" )
				set_source_files_properties(${FilePath} PROPERTIES COMPILE_FLAGS "-std=c++11")
			endif()
		endforeach()
	endif()
endmacro()

macro(find_cuda_files pResult)
	set(FileList)
	set(SearchDir "${ARGN}")

	# Retrive all source files recursively
	set(FileExtensions)
	list(APPEND FileExtensions "*.cu.cc")
	if( "${SearchDir}" STREQUAL "" )
		file(GLOB_RECURSE FileList RELATIVE ${PROJECT_SOURCE_DIR} ${FileExtensions})
	else()
		set(UpdatedFileExtensions)
		foreach(FileExtension ${FileExtensions})
			list(APPEND UpdatedFileExtensions "${SearchDir}/${FileExtension}")
		endforeach()
		file(GLOB_RECURSE FileList RELATIVE ${PROJECT_SOURCE_DIR} ${UpdatedFileExtensions})
	endif()
	list(APPEND ${pResult} ${FileList})

	set_source_groups("${FileList}")
endmacro()

# Remove files matching the given base path(s) from the list
macro(remove_paths_from_list file_list_name)
	set (files ${${file_list_name}})
	foreach(path ${ARGN})
		foreach(item IN LISTS files)
			if(${item} MATCHES "${path}/.*")
				LIST(REMOVE_ITEM ${file_list_name} ${item})
			endif(${item} MATCHES "${path}/.*")
		endforeach(item)
	endforeach(path)
endmacro()

# Add compilation flags, configuration type is optional
macro(add_compile_flags pFlags)
	set(MacroArgs "${ARGN}")
	if( NOT MacroArgs )
		set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${pFlags}")
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${pFlags}")
	else()
		foreach(MacroArg IN LISTS MacroArgs)
			if( MacroArg STREQUAL "debug" )
				set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} ${pFlags}")
				set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} ${pFlags}")
			elseif( MacroArg STREQUAL "dev" )
				set(CMAKE_C_FLAGS_DEV "${CMAKE_C_FLAGS_DEV} ${pFlags}")
				set(CMAKE_CXX_FLAGS_DEV "${CMAKE_CXX_FLAGS_DEV} ${pFlags}")
			elseif( MacroArg STREQUAL "release" )
				set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} ${pFlags}")
				set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} ${pFlags}")
			else()
				message(FATAL_ERROR "Unknown configuration ${MacroArg}, cannot add compile flags!")
			endif()
		endforeach()
	endif()
endmacro()

# Replace compilation flags, configuration type is optional
macro(replace_compile_flags pSearch pReplace)
	set(MacroArgs "${ARGN}")
	if( NOT MacroArgs )
		string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
		string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
	else()
		foreach(MacroArg IN LISTS MacroArgs)
			if( MacroArg STREQUAL "debug" )
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}")
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
			elseif( MacroArg STREQUAL "dev" )
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_C_FLAGS_DEV "${CMAKE_C_FLAGS_DEV}")
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_CXX_FLAGS_DEV "${CMAKE_CXX_FLAGS_DEV}")
			elseif( MacroArg STREQUAL "release" )
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}")
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
			else()
				message(FATAL_ERROR "Unknown configuration, cannot replace compile flags!")
			endif()
		endforeach()
	endif()
endmacro()

# Add linker flags, configuration type is optional
macro(add_linker_flags pFlags)
	set(MacroArgs "${ARGN}")
	if( NOT MacroArgs )
		set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${pFlags}")
		set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} ${pFlags}")
		set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${pFlags}")
	else()
		foreach(MacroArg IN LISTS MacroArgs)
			if( MacroArg STREQUAL "debug" )
				set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG} ${pFlags}")
				set(CMAKE_STATIC_LINKER_FLAGS_DEBUG "${CMAKE_STATIC_LINKER_FLAGS_DEBUG} ${pFlags}")
				set(CMAKE_SHARED_LINKER_FLAGS_DEBUG "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} ${pFlags}")
			elseif( MacroArg STREQUAL "dev" )
				set(CMAKE_EXE_LINKER_FLAGS_DEV "${CMAKE_EXE_LINKER_FLAGS_DEV} ${pFlags}")
				set(CMAKE_STATIC_LINKER_FLAGS_DEV "${CMAKE_STATIC_LINKER_FLAGS_DEV} ${pFlags}")
				set(CMAKE_SHARED_LINKER_FLAGS_DEV "${CMAKE_SHARED_LINKER_FLAGS_DEV} ${pFlags}")
			elseif( MacroArg STREQUAL "release" )
				set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} ${pFlags}")
				set(CMAKE_STATIC_LINKER_FLAGS_RELEASE "${CMAKE_STATIC_LINKER_FLAGS_RELEASE} ${pFlags}")
				set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} ${pFlags}")
			else()
				message(FATAL_ERROR "Unknown configuration, cannot add linker flags!")
			endif()
		endforeach()
	endif()
endmacro()

# Add exe linker flags, configuration type is optional
macro(add_exe_linker_flags pFlags)
	set(MacroArgs "${ARGN}")
	if( NOT MacroArgs )
		set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${pFlags}")
		set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${pFlags}")
		set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} ${pFlags}")
	else()
		foreach(MacroArg IN LISTS MacroArgs)
			if( MacroArg STREQUAL "debug" )
				set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG} ${pFlags}")
				set(CMAKE_SHARED_LINKER_FLAGS_DEBUG "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} ${pFlags}")
				set(CMAKE_MODULE_LINKER_FLAGS_DEBUG "${CMAKE_MODULE_LINKER_FLAGS_DEBUG} ${pFlags}")
			elseif( MacroArg STREQUAL "dev" )
				set(CMAKE_EXE_LINKER_FLAGS_DEV "${CMAKE_EXE_LINKER_FLAGS_DEV} ${pFlags}")
				set(CMAKE_SHARED_LINKER_FLAGS_DEV "${CMAKE_SHARED_LINKER_FLAGS_DEV} ${pFlags}")
				set(CMAKE_MODULE_LINKER_FLAGS_DEV "${CMAKE_MODULE_LINKER_FLAGS_DEV} ${pFlags}")
			elseif( MacroArg STREQUAL "release" )
				set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} ${pFlags}")
				set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} ${pFlags}")
				set(CMAKE_MODULE_LINKER_FLAGS_RELEASE "${CMAKE_MODULE_LINKER_FLAGS_RELEASE} ${pFlags}")
			else()
				message(FATAL_ERROR "Unknown configuration, cannot add linker flags!")
			endif()
		endforeach()
	endif()
endmacro()

# Replace linker flags, configuration type is optional
macro(replace_linker_flags pSearch pReplace)
	set(MacroArgs "${ARGN}")
	if( NOT MacroArgs )
		string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}")
		string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")
		string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS}")
	else()
		foreach(MacroArg IN LISTS MacroArgs)
			if( MacroArg STREQUAL "debug" )
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG}")
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_SHARED_LINKER_FLAGS_DEBUG "${CMAKE_SHARED_LINKER_FLAGS_DEBUG}")
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_MODULE_LINKER_FLAGS_DEBUG "${CMAKE_MODULE_LINKER_FLAGS_DEBUG}")
			elseif( MacroArg STREQUAL "dev" )
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_EXE_LINKER_FLAGS_DEV "${CMAKE_EXE_LINKER_FLAGS_DEV}")
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_SHARED_LINKER_FLAGS_DEV "${CMAKE_SHARED_LINKER_FLAGS_DEV}")
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_MODULE_LINKER_FLAGS_DEV "${CMAKE_MODULE_LINKER_FLAGS_DEV}")
			elseif( MacroArg STREQUAL "release" )
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
				string(REGEX REPLACE "${pSearch}" "${pReplace}" CMAKE_MODULE_LINKER_FLAGS_RELEASE "${CMAKE_MODULE_LINKER_FLAGS_RELEASE}")
			else()
				message(FATAL_ERROR "Unknown configuration, cannot replace linker flags!")
			endif()
		endforeach()
	endif()
endmacro()

# Used to find and link an IOS framework
macro(target_link_ios_framework)
	set(PROJ_NAME ${ARGV0})
	set(NAME ${ARGV1})
	find_library(FRAMEWORK_${NAME} NAMES ${NAME} PATHS ${CMAKE_OSX_SYSROOT}/System/Library PATH_SUFFIXES Frameworks NO_DEFAULT_PATH)
	mark_as_advanced(FRAMEWORK_${NAME})
	if( ${FRAMEWORK_${NAME}} STREQUAL FRAMEWORK_${NAME}-NOTFOUND )
		message(ERROR ": Framework ${NAME} not found")
	else()
		target_link_libraries(${PROJ_NAME} ${FRAMEWORK_${NAME}})
		message(STATUS "Found Framework ${NAME}: ${FRAMEWORK_${NAME}}")
	endif()
endmacro()

# Used to link Android specific library types, such as .so/.jar/.aar
macro(target_link_android_libraries target libs)
	foreach(_lib ${libs})
		if( "${_lib}" MATCHES "^.*\\.so$" )
			# Add native library directory only once
			get_target_property(_lib_dirs ${PROJECT_NAME} ANDROID_NATIVE_LIB_DIRECTORIES)
			get_filename_component(_lib_dir ${_lib} DIRECTORY)
			if( NOT "${_lib_dirs}" MATCHES "${_lib_dir}" )
				set_property(TARGET ${target} APPEND PROPERTY ANDROID_NATIVE_LIB_DIRECTORIES ${_lib_dir})
			endif()
			# Add native libraries dependencies
			get_filename_component(_lib_name ${_lib} NAME_WE)
			if( "${_lib_name}" MATCHES "^lib.*$" )
				string(SUBSTRING ${_lib_name} 3 -1 _lib_name)
			endif()
			set_property(TARGET ${target} APPEND PROPERTY ANDROID_NATIVE_LIB_DEPENDENCIES ${_lib_name})
		elseif( "${_lib}" MATCHES "^.*\\.jar$" )
			# Add jar directory only once
			get_target_property(_lib_dirs ${PROJECT_NAME} ANDROID_JAR_DIRECTORIES)
			get_filename_component(_lib_dir ${_lib} DIRECTORY)
			if( NOT "${_lib_dirs}" MATCHES "${_lib_dir}" )
				set_property(TARGET ${target} APPEND PROPERTY ANDROID_JAR_DIRECTORIES ${_lib_dir})
			endif()
			# Add jar dependencies
			get_filename_component(_lib_name ${_lib} NAME_WE)
			if( "${_lib_name}" MATCHES "^lib.*$" )
				string(SUBSTRING ${_lib_name} 3 -1 _lib_name)
			endif()
			set_property(TARGET ${target} APPEND PROPERTY ANDROID_JAR_DEPENDENCIES ${_lib_name})
		elseif( "${_lib}" MATCHES "^.*\\.aar$" )
			# Simply copy aar library into project binary libs dir to be compiled by Gradle
			file(COPY ${_lib} DESTINATION ${${target}_BINARY_DIR}/libs)
		endif()
	endforeach()
endmacro()

# Ask source control for revision number to include in a build header file
# If pResult already has a value this function does nothing
macro(determine_build_revision pBaseDir pResult)
	if( NOT ${pResult} )
		execute_process(COMMAND git log -1 --format=%H WORKING_DIRECTORY ${pBaseDir} OUTPUT_VARIABLE ${pResult} OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_VARIABLE GIT_ERROR)
		    if( "${GIT_ERROR}" STRGREATER "")
			    message(WARNING "The following git command: >> git log -1 --format=%H (get current git commit)<< could not be executed, because no .git folder was found.")
			endif()
	endif()
	if( NOT ${pResult} )
		execute_process(COMMAND hg identify -i WORKING_DIRECTORY ${pBaseDir} OUTPUT_VARIABLE ${pResult} OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
	endif()
	if( NOT ${pResult} )
		execute_process(COMMAND svn info WORKING_DIRECTORY ${pBaseDir} OUTPUT_VARIABLE OUTPUT_SVN OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
		if( OUTPUT_SVN )
			string(REGEX MATCH "Last Changed Rev: [0-9]+" OUTPUT_SVN_LAST_CHANGED_REV_LINE ${OUTPUT_SVN})
			if( OUTPUT_SVN_LAST_CHANGED_REV_LINE )
				string(REGEX MATCH "[0-9]+" OUTPUT_SVN_LAST_CHANGED_REV ${OUTPUT_SVN_LAST_CHANGED_REV_LINE})
				if( OUTPUT_SVN_LAST_CHANGED_REV )
					set(${pResult} ${OUTPUT_SVN_LAST_CHANGED_REV})
				endif()
			endif()
		endif()
	endif()
	if( NOT ${pResult} )
		execute_process(COMMAND p4 changes -m 1 -s submitted "#have" WORKING_DIRECTORY ${pBaseDir} OUTPUT_VARIABLE OUTPUT_P4 OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET TIMEOUT 5)
		if( OUTPUT_P4 )
			string(REGEX MATCH "[0-9]+" OUTPUT_P4_CL ${OUTPUT_P4})
			if( OUTPUT_P4_CL )
				set(${pResult} ${OUTPUT_P4_CL})
			endif()
		endif()
	endif()
	if( NOT ${pResult} )
		set(${pResult} "unknown")
	endif()
endmacro()

# Set a variable to pValue if pValue exists, otherwise set it to pDefault
macro(set_default pResult pValue pDefault)
	set(${pResult} ${pValue})
	if( NOT ${pResult} )
		set(${pResult} ${pDefault})
	endif()
endmacro()

# Generate the package location cache
macro(generate_package_location_cache)
	set(SpmCmd)
	# PLUGIN CUSTOM CHANGE
	list(APPEND SpmCmd "ruby" "${REPOSITORY_DIR}/tools/spm.rb" "locate" "--lib-dir" ${ENGINE_LIB_DIR} "-a")
	if( PLATFORM_WINDOWS )
		list(APPEND SpmCmd "-p" "win${ARCH_BITS}")
	elseif( PLATFORM_UWP )
		list(APPEND SpmCmd "-p" "uwp${ARCH_BITS}")
	else()
		list(APPEND SpmCmd "-p" "${PLATFORM_NAME}")
	endif()
	if( PLATFORM_WINDOWS OR PLATFORM_XBOXONE)
		list(APPEND SpmCmd "-d" "${COMPILER_NAME}")
	endif()
	execute_process(COMMAND ${SpmCmd} WORKING_DIRECTORY ${REPOSITORY_DIR} RESULT_VARIABLE ProcessResult OUTPUT_VARIABLE SpmOutput OUTPUT_STRIP_TRAILING_WHITESPACE)
	if( NOT ProcessResult EQUAL 0 )
		message(FATAL_ERROR "Failed to execute spm.rb to locate packages!")
	endif()
	file(WRITE ${PACKAGE_CACHE_FILE} ${SpmOutput})
endmacro()

# Find package root folder. Can be overwritten with environment variable SR_<LIBRARY NAME>_ROOT.
macro(find_package_root pResult pPackageName)
	if( ${pResult} )
		return()
	endif()
	set(PackageLocation)
	set(AlternatePackageLocation $ENV{SR_${pResult}})
	if( DEFINED AlternatePackageLocation )
		string(REPLACE "\\" "/" PackageLocation ${AlternatePackageLocation})
	else()
		if( NOT EXISTS "${PACKAGE_CACHE_FILE}" )
			message(FATAL_ERROR "Package location cache file not found! Expected to find it here: ${PACKAGE_CACHE_FILE}")
		endif()
		file(STRINGS ${PACKAGE_CACHE_FILE} PackageCache REGEX ".+ = .+")
		foreach(Line ${PackageCache})
			if( "${Line}" MATCHES "${pPackageName}" )
				string(STRIP ${Line} Line)
				string(REGEX REPLACE ".+ = " "" Line ${Line})
				string(REPLACE "\\" "/" PackageLocation ${Line})
				break()
			endif()
		endforeach()
	endif()
	if( NOT EXISTS "${PackageLocation}" OR NOT IS_DIRECTORY "${PackageLocation}" )
		message(FATAL_ERROR "Unable to find package '${pPackageName}' root folder!")
	endif()
	set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} ${PackageLocation})
	set(${pResult} ${PackageLocation})
endmacro()

# Encoding a list into a string using custom separator
macro(encode_list pResult pSeparator pList)
	set(ENCODED_LIST)
	foreach(ITEM ${pList})
		if( "${ENCODED_LIST}" STREQUAL "" )
			set(ENCODED_LIST "${ITEM}")
		else()
			set(ENCODED_LIST "${ENCODED_LIST}${pSeparator}${ITEM}")
		endif()
	endforeach()
	set(${pResult} ${ENCODED_LIST})
endmacro()

# Decoding a custom separated string into a list
macro(decode_list pResult pSeparator pList)
	string(REPLACE "${pSeparator}" ";" ${pResult} ${pList})
endmacro()

# Add files to the package manifest file
macro(add_package_manifest_files pTarget pFiles)
	if( PLATFORM_WINDOWS )
		get_property(plugin_dll_filepath TARGET ${pTarget} PROPERTY PLUGIN_DLL_FILEPATH)
		encode_list(ENCODED_FILE_LIST "*" "${pFiles}")
		add_custom_command(TARGET ${pTarget} POST_BUILD COMMAND ${CMAKE_COMMAND} ARGS
			-DLOCKDIR="${CMAKE_BINARY_DIR}"
			-DOUTDIR="${ENGINE_INSTALL_DIR}"
			-DOUTFILE="package.manifest"
			-DFILENAMES="${ENCODED_FILE_LIST}"
			-DPLUGIN_DLL_FILEPATH="${plugin_dll_filepath}"
			-P "${CMAKE_MODULE_PATH}/CMakeManifest.cmake"
		)
	endif()
endmacro()

# Add files found in directories to the package manifest file
macro(add_package_manifest_dirs pTarget pDirs)
	if( PLATFORM_WINDOWS )
		encode_list(ENCODED_DIR_LIST "*" "${pDirs}")
		add_custom_command(TARGET ${pTarget} POST_BUILD COMMAND ${CMAKE_COMMAND} ARGS
			-DLOCKDIR="${CMAKE_BINARY_DIR}"
			-DOUTDIR="${ENGINE_INSTALL_DIR}"
			-DOUTFILE="package.manifest"
			-DDIRNAMES="${ENCODED_DIR_LIST}"
			-P "${CMAKE_MODULE_PATH}/CMakeManifest.cmake"
		)
	endif()
endmacro()

# Used across projects to set platform specific flags
macro(set_system_properties pTarget)
	if( PLATFORM_OSX OR PLATFORM_IOS )
		set_target_properties(${pTarget} PROPERTIES
			XCODE_ATTRIBUTE_VALID_ARCHS "${CMAKE_OSX_ARCHITECTURES}"
		)
		if( PLATFORM_IOS )
			set_target_properties(${pTarget} PROPERTIES
				XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${CMAKE_IOS_DEPLOYMENT_TARGET}"
				XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
			)
		endif()
	elseif( PLATFORM_UWP )
		set_target_properties(${pTarget} PROPERTIES VS_WINDOWS_TARGET_PLATFORM_MIN_VERSION "${UWP_VERSION_MIN}")
	elseif( PLATFORM_XBOXONE )
		set_target_properties(${pTarget} PROPERTIES VS_GLOBAL_ApplicationEnvironment "title")
		set_target_properties(${pTarget} PROPERTIES VS_GLOBAL_PlatformToolset "v140")
		set_target_properties(${pTarget} PROPERTIES VS_GLOBAL_MinimumVisualStudioVersion "14.0")
		set_target_properties(${pTarget} PROPERTIES VS_GLOBAL_TargetRuntime "Native")
		set_target_properties(${pTarget} PROPERTIES VS_GLOBAL_XdkEditionTarget "${XDK_TOOLCHAIN_VERSION}")
	endif()
endmacro()

# Used to add target link libraries that have circular dependencies. i.e. groups
macro(target_link_libraries_group pTarget pLibraries)
	if( PLATFORM_WEB )
		target_link_libraries(${pTarget} -Wl,--start-group ${pLibraries} -Wl,--end-group)
	elseif( PLATFORM_ANDROID )
		if( BUILD_SHARED_LIBS )
			target_link_libraries(${pTarget} -Wl,--start-group ${pLibraries} -Wl,--end-group)
		else()
			target_link_libraries(${pTarget} ${pLibraries})
			target_link_libraries(${pTarget} ${pLibraries})
		endif()
	else()
		target_link_libraries(${pTarget} ${pLibraries})
	endif()
endmacro()

# Used to add target dependency with platform specific code
macro(add_dependencies_platform pTarget pDependencies)
	if( PLATFORM_ANDROID )
		# Setting ANDROID_NATIVE_LIB_DEPENDENCIES tells Gradle which libraries to copy into the APK.
		foreach(Dep ${pDependencies})
			get_target_property(DependencyOutputName ${Dep} OUTPUT_NAME)
			set_property(TARGET ${pTarget} APPEND PROPERTY ANDROID_NATIVE_LIB_DEPENDENCIES ${DependencyOutputName})
		endforeach()
		# add_dependencies() makes cmake build dependencies in the correct order.
		add_dependencies(${pTarget} ${pDependencies})
	else()
		add_dependencies(${pTarget} ${pDependencies})
	endif()
endmacro()

macro(configure_plugin_linking plugin_name plugin_enabled_flag)
	if( NOT BUILD_SHARED_LIBS )
		if (${plugin_enabled_flag})
			set(PLUGIN_NAME ${plugin_name})
			configure_file("${REPOSITORY_DIR}/runtime/plugins/plugin_static_linking.cpp.in" "${CMAKE_BINARY_DIR}/plugins/${plugin_name}_linking.cpp")
		else()
			file(REMOVE "${CMAKE_BINARY_DIR}/plugins/${plugin_name}_linking.cpp")
		endif()
	endif()
endmacro()


macro(set_plugin_runtime_output_directory target_name target_folder)
	if (PLATFORM_WINDOWS)
		# Safely clean out previously built dlls and copy them to the engine plugin folder - for hot reloading of plugins
		# PLUGIN CUSTOM CHANGE
		add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD COMMAND ${REPOSITORY_DIR}/tools/hot-reload-post-link.bat ARGS "$(OutDir)" "${target_folder}" "${target_name}")
		# Workaround for using the correct path in manifest generation
		set_target_properties(${PROJECT_NAME} PROPERTIES PLUGIN_DLL_FILEPATH "${target_folder}/${target_name}.dll")
		# PLUGIN CUSTOM CHANGE
		set_target_properties(${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${target_folder}")
	else()
		set_target_properties(${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${target_folder}")
	endif()
endmacro()

macro(get_child_folders result curdir)
	file(GLOB children RELATIVE ${curdir} ${curdir}/*)
	set(dirlist "")
	foreach(child ${children})
		if(IS_DIRECTORY ${curdir}/${child})
	    	list(APPEND dirlist ${child})
	    endif()
	endforeach()
	set(${result} ${dirlist})
endmacro()

macro(add_plugin_subfolder plugin_folder plugin_enabled_flag)
	if (${plugin_enable_flag})
		if (EXISTS "${plugin_folder}/CMakeLists.txt")
			add_subdirectory(${plugin_folder})
		endif()
	endif()
endmacro()

macro(link_plugin plugin_name plugin_enable_flag)
	if (${plugin_enable_flag})
		if( BUILD_SHARED_LIBS )
			add_dependencies_platform(${PROJECT_NAME} ${plugin_name})
		else()
			target_link_libraries(${PROJECT_NAME} ${plugin_name})
		endif()

		# In the case of Scaleform Studio on Metal, it has some additional resources that must be included.
		if (PLATFORM_IOS AND NOT ENGINE_USE_GL AND TARGET ${plugin_name})
			get_target_property(PLUGIN_RESOURCES ${plugin_name} RESOURCE)
			if (PLUGIN_RESOURCES)
				target_sources(${PROJECT_NAME} PUBLIC ${PLUGIN_RESOURCES})
				get_target_property(PROJECT_RESOURCES ${PROJECT_NAME} RESOURCE)
				set_target_properties(${PROJECT_NAME} PROPERTIES RESOURCE "${PROJECT_RESOURCES};${PLUGIN_RESOURCES}")
			endif()
		endif()

	endif()
endmacro()

macro(configure_plugin_linking_from_folder plugins_folder)
	get_child_folders(PLUGIN_FOLDER_LIST ${plugins_folder})
	foreach(plugin_dir ${PLUGIN_FOLDER_LIST})
		string(TOUPPER ${plugin_dir} plugin_preprocessor_name)
		set(plugin_enable_flag "ENGINE_USE_${plugin_preprocessor_name}")
		configure_plugin_linking(${plugin_dir} ${plugin_enable_flag})
	endforeach()
endmacro()

macro(add_plugins_from_folders plugins_folder)
	get_child_folders(PLUGIN_FOLDER_LIST ${plugins_folder})
	foreach(plugin_dir ${PLUGIN_FOLDER_LIST})
		string(TOUPPER ${plugin_dir} plugin_preprocessor_name)
		set(plugin_enable_flag "ENGINE_USE_${plugin_preprocessor_name}")
		add_plugin_subfolder(${plugins_folder}/${plugin_dir} ${plugin_enable_flag})
	endforeach()
endmacro()

macro(link_plugins_from_folders plugins_folder)
	get_child_folders(PLUGIN_FOLDER_LIST ${plugins_folder})
	foreach(plugin_dir ${PLUGIN_FOLDER_LIST})
		string(TOUPPER ${plugin_dir} plugin_preprocessor_name)
		set(plugin_enable_flag "ENGINE_USE_${plugin_preprocessor_name}")
		link_plugin(${plugin_dir} ${plugin_enable_flag})
	endforeach()
endmacro()

macro(register_plugin_file)
	if( BUILD_SHARED_LIBS)
		if( PLATFORM_IOS )
			# Registers a full path to a plugin dynamic library in the CMake cache
			# variable PLUGIN_RESOURCE_FILES so it can be read by a higher-level
			# CMake project.  This is used for adding libs to a bundle for platforms
			# that don't support doing it automatically through CMake dependencies.
			# Currently that is only iOS.
			list(APPEND PLUGIN_RESOURCE_FILES "$<TARGET_FILE:${PROJECT_NAME}>")
			set(PLUGIN_RESOURCE_FILES "${PLUGIN_RESOURCE_FILES}" CACHE INTERNAL "" FORCE)
		elseif( PLATFORM_ANDROID )
			# Remove the Gradle build directory as a post-build step for plugins.
			# This way, if a plugin changes, the main_android project is forced to
			# rebuild and rebundle the APK.  Otherwise Visual Studio doesn't notice
			# the change and rebuild, and stale plugin libraries end up in the APK.
			set(GRADLE_BUILD_DIR "${CMAKE_BINARY_DIR}/main_android/main_android.dir")
			add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
				COMMAND "${CMAKE_COMMAND}" -E remove_directory "\"${GRADLE_BUILD_DIR}\""
				COMMENT "Removing stale Gradle build")
		endif()
	endif()
endmacro()

macro(enable_ios_code_signing)
	if( PLATFORM_IOS )
		set_target_properties(${PROJECT_NAME} PROPERTIES
			XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME LaunchImage
			XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "${ENGINE_IOS_CODE_SIGN_IDENTITY}"
			XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
			XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${ENGINE_IOS_DEVELOPMENT_TEAM}"
			)
	endif()
endmacro()

# Removes all matching candidates from a list of files.
macro(exclude_project_files exclude_pattern files)
	foreach (TMP_PATH ${files})
		string (FIND ${TMP_PATH} ${exclude_pattern} EXCLUDE_MATCH_FOUND)
		if (NOT ${EXCLUDE_MATCH_FOUND} EQUAL -1)
			list (REMOVE_ITEM files ${TMP_PATH})
		endif ()
	endforeach()
endmacro()

# Defines TypeScript projects to be compiled
macro(add_typescript_project target source_dir tsconfig)
	set(files ${ARGN})

	set(TYPESCRIPT_EXTS "*.ts" "*.js" "*.json" "*.html" "*.css" "*.stingray_plugin")
	find_source_files_of_type("${TYPESCRIPT_EXTS}" files ${source_dir})

	set(tsp "${source_dir}/${tsconfig}")
	message("-- Generating typescript project ${tsp}...")

	set (tsp_stamp "${CMAKE_CURRENT_BINARY_DIR}/${target}.ts.stamp")
	add_custom_command(
		OUTPUT ${tsp_stamp}
		COMMAND "node" ./node_modules/typescript/bin/tsc -p ${tsp} --noEmitOnError --listEmittedFiles
		COMMAND ${CMAKE_COMMAND} -E touch ${tsp_stamp}
		WORKING_DIRECTORY "${REPOSITORY_DIR}"
		DEPENDS ${files}
		COMMENT "Compiling typescript project ${tsp}")

	add_custom_target(${target} ALL DEPENDS ${tsp_stamp} SOURCES ${files})
endmacro()
