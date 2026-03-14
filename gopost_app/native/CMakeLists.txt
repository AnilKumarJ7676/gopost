cmake_minimum_required(VERSION 3.20)
project(gopost_native VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 17)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Platform detection
if(APPLE)
    if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
        set(GOPOST_PLATFORM_IOS TRUE)
        set(GOPOST_GPU_BACKEND "metal")
    else()
        set(GOPOST_PLATFORM_MACOS TRUE)
        set(GOPOST_GPU_BACKEND "metal")
    endif()
elseif(ANDROID)
    set(GOPOST_PLATFORM_ANDROID TRUE)
    set(GOPOST_GPU_BACKEND "vulkan")
elseif(WIN32)
    set(GOPOST_PLATFORM_WINDOWS TRUE)
    set(GOPOST_GPU_BACKEND "vulkan")
elseif(UNIX)
    set(GOPOST_PLATFORM_LINUX TRUE)
    set(GOPOST_GPU_BACKEND "vulkan")
elseif(EMSCRIPTEN)
    set(GOPOST_PLATFORM_WEB TRUE)
    set(GOPOST_GPU_BACKEND "webgl")
endif()

message(STATUS "GPU Backend: ${GOPOST_GPU_BACKEND}")

option(ENABLE_ASAN "Enable AddressSanitizer (standalone testing only)" OFF)

# OpenSSL (shared by core)
find_package(OpenSSL QUIET)
if(OpenSSL_FOUND)
    message(STATUS "OpenSSL found — AES-GCM, RSA-OAEP, SHA-256 enabled")
else()
    if(APPLE)
        message(STATUS "OpenSSL not found — install via Homebrew (brew install openssl) for crypto support")
    else()
        message(STATUS "OpenSSL not found — AES-GCM/RSA-OAEP unavailable")
    endif()
endif()

# WebP encoding on non-Apple platforms
if(NOT APPLE)
    find_library(WEBP_LIB webp HINTS ${WEBP_ROOT}/lib $ENV{WEBP_ROOT}/lib)
    find_path(WEBP_INCLUDE_DIR webp/encode.h HINTS ${WEBP_ROOT}/include $ENV{WEBP_ROOT}/include)
    if(WEBP_LIB AND WEBP_INCLUDE_DIR)
        set(GOPOST_HAS_WEBP TRUE)
        message(STATUS "libwebp found — WebP encoding enabled")
    else()
        message(STATUS "libwebp not found — WebP encoding unavailable on this platform")
    endif()
endif()

# FFmpeg (video/audio decode on non-Apple platforms)
if(NOT APPLE)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(FFMPEG_LIBAV QUIET
            libavformat libavcodec libswscale libswresample libavutil)
    endif()

    if(NOT FFMPEG_LIBAV_FOUND)
        find_path(FFMPEG_INCLUDE_DIR libavformat/avformat.h
            HINTS ${FFMPEG_ROOT}/include $ENV{FFMPEG_ROOT}/include)
        find_library(AVFORMAT_LIB avformat
            HINTS ${FFMPEG_ROOT}/lib $ENV{FFMPEG_ROOT}/lib)
        find_library(AVCODEC_LIB avcodec
            HINTS ${FFMPEG_ROOT}/lib $ENV{FFMPEG_ROOT}/lib)
        find_library(SWSCALE_LIB swscale
            HINTS ${FFMPEG_ROOT}/lib $ENV{FFMPEG_ROOT}/lib)
        find_library(SWRESAMPLE_LIB swresample
            HINTS ${FFMPEG_ROOT}/lib $ENV{FFMPEG_ROOT}/lib)
        find_library(AVUTIL_LIB avutil
            HINTS ${FFMPEG_ROOT}/lib $ENV{FFMPEG_ROOT}/lib)

        if(FFMPEG_INCLUDE_DIR AND AVFORMAT_LIB AND AVCODEC_LIB
           AND SWSCALE_LIB AND SWRESAMPLE_LIB AND AVUTIL_LIB)
            set(GOPOST_HAS_FFMPEG TRUE)
            set(FFMPEG_INCLUDE_DIRS ${FFMPEG_INCLUDE_DIR})
            set(FFMPEG_LIBRARIES
                ${AVFORMAT_LIB} ${AVCODEC_LIB} ${SWSCALE_LIB}
                ${SWRESAMPLE_LIB} ${AVUTIL_LIB})
        endif()
    else()
        set(GOPOST_HAS_FFMPEG TRUE)
        set(FFMPEG_INCLUDE_DIRS ${FFMPEG_LIBAV_INCLUDE_DIRS})
        set(FFMPEG_LIBRARIES ${FFMPEG_LIBAV_LIBRARIES})
        set(FFMPEG_LIBRARY_DIRS ${FFMPEG_LIBAV_LIBRARY_DIRS})
    endif()

    if(GOPOST_HAS_FFMPEG)
        message(STATUS "FFmpeg found — real video/audio decoding enabled")
    else()
        message(STATUS "FFmpeg not found — video/audio decoders will use stubs")
        message(STATUS "  Install FFmpeg dev libraries or set -DFFMPEG_ROOT=<path>")
    endif()
endif()

# version.h generation (in gopost_core)
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/gopost_core/include/gopost/version.h.in
    ${CMAKE_CURRENT_SOURCE_DIR}/gopost_core/include/gopost/version.h
)

# --- Sub-projects ---
add_subdirectory(gopost_core)
add_subdirectory(gopost_image_engine)
add_subdirectory(gopost_video_engine)

# --- Tests ---
option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS AND NOT ANDROID AND NOT GOPOST_PLATFORM_IOS)
    enable_testing()
    find_package(GTest QUIET)
    if(GTest_FOUND)
        add_executable(gopost_engine_tests
            tests/test_allocator.cpp
            tests/test_thread_pool.cpp
            tests/test_gpu_context.cpp
            tests/test_crypto.cpp
            tests/test_template_parser.cpp
            tests/test_image_codec.cpp
            tests/test_canvas.cpp
            tests/test_artistic_filters.cpp
        )
        target_link_libraries(gopost_engine_tests PRIVATE
            gopost_image_engine
            gopost_video_engine
            GTest::GTest
            GTest::Main
        )
        if(OpenSSL_FOUND)
            target_compile_definitions(gopost_engine_tests PRIVATE GOPOST_USE_OPENSSL)
        endif()
        if(GOPOST_HAS_STB)
            target_include_directories(gopost_engine_tests PRIVATE
                ${CMAKE_CURRENT_SOURCE_DIR}/gopost_core/third_party/stb
            )
        endif()
        add_test(NAME gopost_engine_tests COMMAND gopost_engine_tests)
    else()
        message(STATUS "GTest not found, skipping tests")
    endif()
endif()
