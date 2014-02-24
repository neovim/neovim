cmake_minimum_required (VERSION 2.6)
project (NEOVIM)

# Point CMake at any custom modules we may ship
set(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

set(NEOVIM_VERSION_MAJOR 0)
set(NEOVIM_VERSION_MINOR 0)
set(NEOVIM_VERSION_PATCH 0)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_definitions(-DHAVE_CONFIG_H -Wall -std=gnu99)
if(CMAKE_BUILD_TYPE MATCHES Debug)
  # cmake automatically appends -g to the compiler flags
  set(DEBUG 1)
else()
  set(DEBUG 0)
endif()

# Determine platform's threading library. Set CMAKE_THREAD_PREFER_PTHREAD
# explicitly to indicate a strong preference for pthread. It is an error to not
# have pthread installed even if, for example, the Win32 threading API is found.
set(CMAKE_THREAD_PREFER_PTHREAD ON)
find_package(Threads REQUIRED)
if(NOT CMAKE_USE_PTHREADS_INIT)
  message(SEND_ERROR "The pthread library must be installed on your system.")
endif(NOT CMAKE_USE_PTHREADS_INIT)

# Require libuv
find_package(LibUV REQUIRED)

# add dependencies to include/lib directories
link_directories ("${PROJECT_SOURCE_DIR}/.deps/usr/lib")
include_directories ("${PROJECT_SOURCE_DIR}/.deps/usr/include") 

include_directories ("${PROJECT_BINARY_DIR}/config") 

set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(src)
add_subdirectory(config)
