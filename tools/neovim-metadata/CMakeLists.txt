cmake_minimum_required(VERSION 3.11.0)
project(neovim-metadata LANGUAGES CXX VERSION 0.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
find_package(LLVM REQUIRED CONFIG)

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")

include(${CMAKE_MODULE_PATH}/AddLLVM.cmake)
include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

SET(SAMPLE_SOURCES "sample.c")

add_llvm_loadable_module(neovim-metadata "neovim-metadata.cc" PLUGIN_TOOL clang)
