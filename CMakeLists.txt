cmake_minimum_required(VERSION 2.8.7)
project(NEOVIM)

# Point CMake at any custom modules we may ship
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

# Prefer our bundled versions of dependencies.
set(DEPS_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/.deps/usr" CACHE PATH "Path prefix for finding dependencies")
list(INSERT CMAKE_PREFIX_PATH 0 ${DEPS_PREFIX})
set(ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:${DEPS_PREFIX}/lib/pkgconfig")

# used for check_c_compiler_flag
include(CheckCCompilerFlag)

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  # CMake tries to treat /sw and /opt/local as extension of the system path, but
  # that doesn't really work out very well.  Once you have a dependency that
  # resides there and have to add it as an include directory, then any other
  # dependency that could be satisfied from there must be--otherwise you can end
  # up with conflicting versions.  So, let's make them more of a priority having
  # them be included as one of the first places to look for dependencies.
  list(APPEND CMAKE_PREFIX_PATH /sw /opt/local)

  # Work around some old, broken detection by CMake for knowing when to use the
  # isystem flag.  Apple's compilers have supported this for quite some time
  # now.
  if(CMAKE_COMPILER_IS_GNUCC)
    set(CMAKE_INCLUDE_SYSTEM_FLAG_C "-isystem ")
  endif()
  if(CMAKE_COMPILER_IS_GNUCXX)
    set(CMAKE_INCLUDE_SYSTEM_FLAG_CXX "-isystem ")
  endif()

  # Enable fixing case-insensitive filenames for Mac.
  set(USE_FNAME_CASE TRUE)
endif()

# Set available build types for CMake GUIs.
# A different build type can still be set by -DCMAKE_BUILD_TYPE=...
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY
  STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")

# Set default build type.
if(NOT CMAKE_BUILD_TYPE)
  message(STATUS "CMAKE_BUILD_TYPE not given; setting to 'RelWithDebInfo'.")
  set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "Choose the type of build." FORCE)
endif()

# Version tokens
include(GetGitRevisionDescription)
file(TO_NATIVE_PATH ${CMAKE_CURRENT_LIST_DIR}/.git GIT_DIR)
get_git_head_revision(GIT_REFSPEC NVIM_VERSION_COMMIT)
if(NOT NVIM_VERSION_COMMIT)
  set(NVIM_VERSION_COMMIT "?")
endif()
set(NVIM_VERSION_MAJOR 0)
set(NVIM_VERSION_MINOR 0)
set(NVIM_VERSION_PATCH 0)
set(NVIM_VERSION_PRERELEASE "-alpha")
# TODO(justinmk): UTC time would be nice here #1071
git_timestamp(GIT_TIMESTAMP)
# TODO(justinmk): do not set this for "release" builds #1071
if(GIT_TIMESTAMP)
  set(NVIM_VERSION_BUILD "+${GIT_TIMESTAMP}")
endif()
set(NVIM_VERSION_BUILD_TYPE "${CMAKE_BUILD_TYPE}")
# NVIM_VERSION_CFLAGS set further below.

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Default to -O2 on release builds.
if(CMAKE_C_FLAGS_RELEASE MATCHES "-O3")
  message(STATUS "Replacing -O3 in CMAKE_C_FLAGS_RELEASE with -O2.")
  string(REPLACE "-O3" "-O2" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}")
endif()

# Enable -Wconversion.
if(NOT MSVC)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wconversion")
endif()

# gcc 4.0 and better turn on _FORTIFY_SOURCE=2 automatically.  This currently
# does not work with Neovim due to some uses of dynamically-sized structures.
# See https://github.com/neovim/neovim/issues/223 for details.
include(CheckCSourceCompiles)

# Include the build type's default flags in the check for _FORTIFY_SOURCE,
# otherwise we may incorrectly identify the level as acceptable and find out
# later that it was not when optimizations were enabled.  CFLAGS is applied
# even though you don't see it in CMAKE_REQUIRED_FLAGS.
set(INIT_FLAGS_NAME CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE})
string(TOUPPER ${INIT_FLAGS_NAME} INIT_FLAGS_NAME)
if(${INIT_FLAGS_NAME})
  set(CMAKE_REQUIRED_FLAGS "${${INIT_FLAGS_NAME}}")
endif()

check_c_source_compiles("
#if defined(_FORTIFY_SOURCE) && _FORTIFY_SOURCE > 1
#error \"_FORTIFY_SOURCE > 1\"
#endif
int
main(void)
{
  return 0;
}
" HAS_ACCEPTABLE_FORTIFY)

if(NOT HAS_ACCEPTABLE_FORTIFY)
  message(STATUS "Unsupported _FORTIFY_SOURCE found, forcing _FORTIFY_SOURCE=1.")
  # Extract possible prefix to _FORTIFY_SOURCE (e.g. -Wp,-D_FORTIFY_SOURCE).
  STRING(REGEX MATCH "[^\ ]+-D_FORTIFY_SOURCE" _FORTIFY_SOURCE_PREFIX "${CMAKE_C_FLAGS}")
  STRING(REPLACE "-D_FORTIFY_SOURCE" "" _FORTIFY_SOURCE_PREFIX "${_FORTIFY_SOURCE_PREFIX}" )
  if(NOT _FORTIFY_SOURCE_PREFIX STREQUAL "")
    message(STATUS "Detected _FORTIFY_SOURCE Prefix=${_FORTIFY_SOURCE_PREFIX}.")
  endif()
  # -U in add_definitions doesn't end up in the correct spot, so we add it to
  # the flags variable instead.
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${_FORTIFY_SOURCE_PREFIX}-U_FORTIFY_SOURCE ${_FORTIFY_SOURCE_PREFIX}-D_FORTIFY_SOURCE=1")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${_FORTIFY_SOURCE_PREFIX}-U_FORTIFY_SOURCE ${_FORTIFY_SOURCE_PREFIX}-D_FORTIFY_SOURCE=1")
endif()

# Remove --sort-common from linker flags, as this seems to cause bugs (see #2641, #3374).
# TODO: Figure out the root cause.
if(CMAKE_EXE_LINKER_FLAGS MATCHES "--sort-common" OR
   CMAKE_SHARED_LINKER_FLAGS MATCHES "--sort-common" OR
   CMAKE_MODULE_LINKER_FLAGS MATCHES "--sort-common")
  message(STATUS "Removing --sort-common from linker flags.")
  string(REGEX REPLACE ",--sort-common(=[^,]+)?" "" CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}")
  string(REGEX REPLACE ",--sort-common(=[^,]+)?" "" CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")
  string(REGEX REPLACE ",--sort-common(=[^,]+)?" "" CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS}")

  # If no linker flags remain for a -Wl argument, remove it.
  # '-Wl$' will match LDFLAGS="-Wl,--sort-common",
  # '-Wl ' will match LDFLAGS="-Wl,--sort-common -Wl,..."
  string(REGEX REPLACE "-Wl($| )" "" CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}")
  string(REGEX REPLACE "-Wl($| )" "" CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")
  string(REGEX REPLACE "-Wl($| )" "" CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS}")
endif()

if(MSVC)
  # XXX: /W4 gives too many warnings. #3241
  add_definitions(/W3 -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE)
else()
  add_definitions(-Wall -Wextra -pedantic -Wno-unused-parameter
    -Wstrict-prototypes -std=gnu99)
endif()

if(MINGW)
  # Use POSIX compatible stdio in Mingw
  add_definitions(-D__USE_MINGW_ANSI_STDIO)
endif()

# OpenBSD's GCC (4.2.1) doesn't have -Wvla
check_c_compiler_flag(-Wvla HAS_WVLA_FLAG)
if(HAS_WVLA_FLAG)
  add_definitions(-Wvla)
endif()

check_c_compiler_flag(-fstack-protector-strong HAS_FSTACK_PROTECTOR_STRONG_FLAG)
check_c_compiler_flag(-fstack-protector HAS_FSTACK_PROTECTOR_FLAG)
if(HAS_FSTACK_PROTECTOR_STRONG_FLAG)
  add_definitions(-fstack-protector-strong)
elseif(HAS_FSTACK_PROTECTOR_FLAG)
  add_definitions(-fstack-protector --param ssp-buffer-size=4)
endif()

check_c_compiler_flag(-fdiagnostics-color=auto HAS_DIAG_COLOR_FLAG)
if(HAS_DIAG_COLOR_FLAG)
  add_definitions(-fdiagnostics-color=auto)
endif()

option(
  TRAVIS_CI_BUILD "Travis CI build.  Extra compilation flags will be set." OFF)

if(TRAVIS_CI_BUILD)
  message(STATUS "Travis CI build enabled.")
  add_definitions(-Werror)
endif()

if(CMAKE_COMPILER_IS_GNUCC)
  check_c_compiler_flag(-Og HAS_OG_FLAG)
else()
  set(HAS_OG_FLAG 0)
endif()

# Set custom build flags for RelWithDebInfo.
# -DNDEBUG purposely omitted because we want assertions.
if(HAS_OG_FLAG)
  set(CMAKE_C_FLAGS_RELWITHDEBINFO "-Og -g"
    CACHE STRING "Flags used by the compiler during release builds with debug info." FORCE)
elseif(NOT MSVC)
  set(CMAKE_C_FLAGS_RELWITHDEBINFO "-O2 -g"
    CACHE STRING "Flags used by the compiler during release builds with debug info." FORCE)
endif()

if(CMAKE_BUILD_TYPE MATCHES Debug)
  set(DEBUG 1)
else()
  set(DEBUG 0)
endif()

add_definitions(-DINCLUDE_GENERATED_DECLARATIONS)
add_definitions(-DHAVE_CONFIG_H)

if(CMAKE_COMPILER_IS_GNUCXX AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--no-undefined")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,--no-undefined")
endif()

if(CMAKE_COMPILER_IS_GNUCXX AND CMAKE_SYSTEM_NAME STREQUAL "SunOS")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--no-undefined -lsocket")
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin" AND CMAKE_SIZEOF_VOID_P EQUAL 8)
  # Required for luajit.
  set(CMAKE_EXE_LINKER_FLAGS
    "${CMAKE_EXE_LINKER_FLAGS} -pagezero_size 10000 -image_base 100000000")
  set(CMAKE_SHARED_LINKER_FLAGS
    "${CMAKE_SHARED_LINKER_FLAGS} -image_base 100000000")
  set(CMAKE_MODULE_LINKER_FLAGS
    "${CMAKE_MODULE_LINKER_FLAGS} -image_base 100000000")
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

find_package(Unibilium REQUIRED)
include_directories(SYSTEM ${UNIBILIUM_INCLUDE_DIRS})

find_package(LibTermkey REQUIRED)
include_directories(SYSTEM ${LIBTERMKEY_INCLUDE_DIRS})

find_package(LibVterm REQUIRED)
include_directories(SYSTEM ${LIBVTERM_INCLUDE_DIRS})

option(CLANG_ASAN_UBSAN "Enable Clang address & undefined behavior sanitizer for nvim binary." OFF)
option(CLANG_MSAN "Enable Clang memory sanitizer for nvim binary." OFF)
option(CLANG_TSAN "Enable Clang thread sanitizer for nvim binary." OFF)

if((CLANG_ASAN_UBSAN AND CLANG_MSAN)
    OR (CLANG_ASAN_UBSAN AND CLANG_TSAN)
    OR (CLANG_MSAN AND CLANG_TSAN))
  message(FATAL_ERROR "Sanitizers cannot be enabled simultaneously.")
endif()

if((CLANG_ASAN_UBSAN OR CLANG_MSAN OR CLANG_TSAN) AND NOT CMAKE_C_COMPILER_ID MATCHES "Clang")
  message(FATAL_ERROR "Sanitizers are only supported for Clang.")
endif()

if(CLANG_ASAN_UBSAN OR CLANG_MSAN OR CLANG_TSAN)
  message(STATUS "Sanitizers have been enabled; don't use jemalloc.")
else()
  find_package(JeMalloc)
  if(JEMALLOC_FOUND)
    include_directories(SYSTEM ${JEMALLOC_INCLUDE_DIRS})
  endif()
endif()

find_package(LibIntl)
if(LibIntl_FOUND)
  include_directories(SYSTEM ${LibIntl_INCLUDE_DIRS})
endif()

find_package(Iconv)
if(Iconv_FOUND)
  include_directories(SYSTEM ${Iconv_INCLUDE_DIRS})
endif()

# Determine platform's threading library. Set CMAKE_THREAD_PREFER_PTHREAD
# explicitly to indicate a strong preference for pthread.
set(CMAKE_THREAD_PREFER_PTHREAD ON)
find_package(Threads REQUIRED)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Find Lua interpreter
include(LuaHelpers)
set(LUA_DEPENDENCIES lpeg MessagePack bit)
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
  message(FATAL_ERROR "A suitable Lua interpreter was not found.")
endif()

message(STATUS "Using the Lua interpreter ${LUA_PRG}.")

# Setup busted.
find_program(BUSTED_PRG busted)
if(NOT BUSTED_OUTPUT_TYPE)
  set(BUSTED_OUTPUT_TYPE "utfTerminal")
endif()

include(InstallHelpers)

file(GLOB MANPAGES
  RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
  man/nvim.1)

install_helper(
  FILES ${MANPAGES}
  DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)

# Go down the tree.

add_subdirectory(src/nvim)
# Read compilation flags from src/nvim,
# used in config subdirectory below.
include(GetCompileFlags)
get_compile_flags(NVIM_VERSION_CFLAGS)

add_subdirectory(test/includes)
add_subdirectory(config)
add_subdirectory(test/functional/fixtures) # compile pty/shell test programs
add_subdirectory(runtime)

# Setup some test-related bits.  We do this after going down the tree because we
# need some of the targets.
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

  set(UNITTEST_PREREQS nvim-test unittest-headers)
  set(FUNCTIONALTEST_PREREQS nvim tty-test shell-test)
  set(BENCHMARK_PREREQS nvim tty-test)

  # Useful for automated build systems, if they want to manually run the tests.
  add_custom_target(unittest-prereqs
    DEPENDS ${UNITTEST_PREREQS})

  add_custom_target(functionaltest-prereqs
    DEPENDS ${FUNCTIONALTEST_PREREQS})

  add_custom_target(benchmark-prereqs
    DEPENDS ${BENCHMARK_PREREQS})

  add_custom_target(unittest
    COMMAND ${CMAKE_COMMAND}
      -DBUSTED_PRG=${BUSTED_PRG}
      -DLUA_PRG=${LUA_PRG}
      -DWORKING_DIR=${CMAKE_CURRENT_SOURCE_DIR}
      -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
      -DTEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}/test
      -DBUILD_DIR=${CMAKE_BINARY_DIR}
      -DTEST_TYPE=unit
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${UNITTEST_PREREQS})

  add_custom_target(functionaltest
    COMMAND ${CMAKE_COMMAND}
      -DBUSTED_PRG=${BUSTED_PRG}
      -DNVIM_PRG=$<TARGET_FILE:nvim>
      -DWORKING_DIR=${CMAKE_CURRENT_SOURCE_DIR}
      -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
      -DTEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}/test
      -DBUILD_DIR=${CMAKE_BINARY_DIR}
      -DTEST_TYPE=functional
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${FUNCTIONALTEST_PREREQS})

  add_custom_target(benchmark
    COMMAND ${CMAKE_COMMAND}
      -DBUSTED_PRG=${BUSTED_PRG}
      -DNVIM_PRG=$<TARGET_FILE:nvim>
      -DWORKING_DIR=${CMAKE_CURRENT_SOURCE_DIR}
      -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
      -DTEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}/test
      -DBUILD_DIR=${CMAKE_BINARY_DIR}
      -DTEST_TYPE=benchmark
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${BENCHMARK_PREREQS})
endif()
