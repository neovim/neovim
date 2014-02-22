cmake_minimum_required (VERSION 2.6)
project (NEOVIM)

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

# add dependencies to include/lib directories
link_directories ("${PROJECT_SOURCE_DIR}/.deps/usr/lib")
include_directories ("${PROJECT_SOURCE_DIR}/.deps/usr/include") 

include_directories ("${PROJECT_BINARY_DIR}/config") 

set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(src)
add_subdirectory(config)
