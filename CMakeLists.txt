cmake_minimum_required (VERSION 2.8.7)
project (NEOVIM)

# Point CMake at any custom modules we may ship
set(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

# Prefer our bundled versions of dependencies.
set(DEPS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.deps")
set(DEPS_BUILD_DIR "${DEPS_DIR}/build")
set(DEPS_INSTALL_DIR "${DEPS_DIR}/usr")
set(DEPS_BIN_DIR "${DEPS_INSTALL_DIR}/bin")

list(APPEND CMAKE_PREFIX_PATH ${DEPS_INSTALL_DIR})

set(NEOVIM_VERSION_MAJOR 0)
set(NEOVIM_VERSION_MINOR 0)
set(NEOVIM_VERSION_PATCH 0)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Work around some old, broken detection by CMake for knowing when to use the
# isystem flag.  Apple's compilers have supported this for quite some time now.
if(APPLE)
  if(CMAKE_COMPILER_IS_GNUCC)
    set(CMAKE_INCLUDE_SYSTEM_FLAG_C "-isystem ")
  endif()
  if(CMAKE_COMPILER_IS_GNUCXX)
    set(CMAKE_INCLUDE_SYSTEM_FLAG_CXX "-isystem ")
  endif()
endif()

add_definitions(-Wall -Wextra -pedantic -Wno-unused-parameter
    -Wstrict-prototypes -std=gnu99)

option(
  TRAVIS_CI_BUILD "Travis CI build.  Extra compilation flags will be set." OFF)

if(TRAVIS_CI_BUILD)
  message(STATUS "Travis CI build enabled.")
  add_definitions(-Werror)
endif()

add_definitions(-DINCLUDE_GENERATED_DECLARATIONS)

add_definitions(-DHAVE_CONFIG_H)
if(CMAKE_BUILD_TYPE MATCHES Debug)
  # cmake automatically appends -g to the compiler flags
  set(DEBUG 1)
else()
  set(DEBUG 0)
endif()

if(CMAKE_COMPILER_IS_GNUCXX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--no-undefined")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,--no-undefined")
endif()

option(USE_GCOV "Enable gcov support" OFF)

if(USE_GCOV)
  message(STATUS "Enabling gcov support")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --coverage")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --coverage")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} --coverage")
endif()

include_directories("${PROJECT_BINARY_DIR}/config")
include_directories("${PROJECT_SOURCE_DIR}/src")

# Modules used by platform auto-detection
include(CheckLibraryExists)

find_package(LibUV REQUIRED)
include_directories(SYSTEM ${LIBUV_INCLUDE_DIRS})

find_package(Msgpack REQUIRED)
include_directories(SYSTEM ${MSGPACK_INCLUDE_DIRS})

find_package(LuaJit REQUIRED)
include_directories(SYSTEM ${LUAJIT_INCLUDE_DIRS})

find_package(LibIntl)
if(LibIntl_FOUND)
  include_directories(SYSTEM ${LibIntl_INCLUDE_DIR})
endif()

# Determine platform's threading library. Set CMAKE_THREAD_PREFER_PTHREAD
# explicitly to indicate a strong preference for pthread.
set(CMAKE_THREAD_PREFER_PTHREAD ON)
find_package(Threads REQUIRED)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# Find Lua interpreter
include(LuaHelpers)
set(LUA_DEPENDENCIES lpeg cmsgpack)
if(NOT LUA_PRG)
  foreach(CURRENT_LUA_PRG luajit lua)
    # If LUA_PRG is set find_program() will not search
    unset(LUA_PRG CACHE)
    unset(LUA_PRG_WORKS)
    find_program(LUA_PRG ${CURRENT_LUA_PRG})

    if(LUA_PRG)
      check_lua_deps(${LUA_PRG} "${LUA_DEPENDENCIES}" LUA_PRG_WORKS)
      if(LUA_PRG_WORKS)
        break()
      endif()
    endif()
  endforeach()
else()
  check_lua_deps(${LUA_PRG} "${LUA_DEPENDENCIES}" LUA_PRG_WORKS)
endif()

if(NOT LUA_PRG_WORKS)
  message(FATAL_ERROR "A suitable Lua interpreter was not found")
endif()

message(STATUS "Using the Lua interpreter ${LUA_PRG}")

add_subdirectory(config)
add_subdirectory(src/nvim)
add_subdirectory(test/includes)

find_program(BUSTED_PRG busted)

find_program(MAKE_PRG NAMES gmake make)
if(MAKE_PRG)
  execute_process(
    COMMAND "${MAKE_PRG}" --version
    OUTPUT_VARIABLE MAKE_VERSION_INFO)
  if(NOT "${OUTPUT_VARIABLE}" MATCHES ".*GNU.*")
    unset(MAKE_PRG)
  endif()
endif()
if(NOT MAKE_PRG)
  message(FATAL_ERROR "GNU Make is required to build the dependencies.")
else()
  message(STATUS "Found GNU Make at ${MAKE_PRG}")
endif()

# When using make, use the $(MAKE) variable to avoid warnings about the job
# server.
if(CMAKE_GENERATOR MATCHES "Makefiles")
  set(MAKE_PRG "$(MAKE)")
endif()

if(NOT BUSTED_OUTPUT_TYPE)
  set(BUSTED_OUTPUT_TYPE "utf_terminal")
endif()

if(BUSTED_PRG)
  get_property(TEST_INCLUDE_DIRS DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    PROPERTY INCLUDE_DIRECTORIES)

  # Set policy CMP0026 to OLD so we avoid CMake warnings on newer
  # versions of cmake.
  if(POLICY CMP0026)
    cmake_policy(SET CMP0026 OLD)
  endif()
  get_target_property(TEST_LIBNVIM_PATH nvim-test LOCATION)

  configure_file(
    test/config/paths.lua.in
    ${CMAKE_BINARY_DIR}/test/config/paths.lua)

  add_custom_target(unittest
    COMMAND ${CMAKE_COMMAND}
      -DBUSTED_PRG=${BUSTED_PRG}
      -DLUA_PRG=${LUA_PRG}
      -DWORKING_DIR=${CMAKE_CURRENT_SOURCE_DIR}
      -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
      -DTEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}/test
      -DBUILD_DIR=${CMAKE_BINARY_DIR}
      -P ${CMAKE_MODULE_PATH}/RunUnittests.cmake
    DEPENDS nvim-test unittest-headers)
endif()

install(DIRECTORY runtime DESTINATION share/nvim)
install(SCRIPT ${CMAKE_MODULE_PATH}/GenerateHelptags.cmake)

# Unfortunately, the below does not work under Ninja.  Ninja doesn't use a
# pseudo-tty when launching processes, because it can put many jobs in parallel
# and eat-up all the available pseudo-ttys.  Unfortunately, that doesn't work
# well with the legacy tests.  I have a branch that converts them to run under
# CTest, but it needs a little more work.
# add_custom_target(test
#   COMMAND ${MAKE_PRG} -C ${CMAKE_CURRENT_SOURCE_DIR}/src/nvim/testdir
#     VIMPROG=${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/nvim)
