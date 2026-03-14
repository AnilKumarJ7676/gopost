cmake_minimum_required(VERSION 3.20)
project(gopost_android_bridge LANGUAGES C CXX)

set(NATIVE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native")

add_subdirectory(${NATIVE_ROOT} ${CMAKE_CURRENT_BINARY_DIR}/gopost_native)
