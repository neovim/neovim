# CMAKE REFERENCE
#   intro: https://codingnest.com/basic-cmake/
#   best practices (3.0+): https://gist.github.com/mbinna/c61dbb39bca0e4fb7d1f73b0d66a4fd1

cmake_minimum_required(VERSION 2.8.12)
project(nvim C)

if(POLICY CMP0059)
  cmake_policy(SET CMP0059 OLD)  # Needed until cmake 2.8.12. #4389
endif()

# Point CMake at any custom modules we may ship
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

# We don't support building in-tree.
include(PreventInTreeBuilds)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Prefer our bundled versions of dependencies.
if(DEFINED ENV{DEPS_BUILD_DIR})
  set(DEPS_PREFIX "$ENV{DEPS_BUILD_DIR}/usr" CACHE PATH "Path prefix for finding dependencies")
else()
  set(DEPS_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/.deps/usr" CACHE PATH "Path prefix for finding dependencies")
  # When running from within CLion or Visual Studio,
  # build bundled dependencies automatically.
  if(NOT EXISTS ${DEPS_PREFIX}
     AND (DEFINED ENV{CLION_IDE}
          OR DEFINED ENV{VisualStudioEdition}))
    message(STATUS "Building dependencies...")
    set(DEPS_BUILD_DIR ${PROJECT_BINARY_DIR}/.deps)
    file(MAKE_DIRECTORY ${DEPS_BUILD_DIR})
    execute_process(
      COMMAND ${CMAKE_COMMAND} -G ${CMAKE_GENERATOR}
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
        -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
        -DCMAKE_C_FLAGS_DEBUG=${CMAKE_C_FLAGS_DEBUG}
        -DCMAKE_C_FLAGS_MINSIZEREL=${CMAKE_C_FLAGS_MINSIZEREL}
        -DCMAKE_C_FLAGS_RELWITHDEBINFO=${CMAKE_C_FLAGS_RELWITHDEBINFO}
        -DCMAKE_C_FLAGS_RELEASE=${CMAKE_C_FLAGS_RELEASE}
        -DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}
        ${PROJECT_SOURCE_DIR}/third-party
      WORKING_DIRECTORY ${DEPS_BUILD_DIR})
    execute_process(
      COMMAND ${CMAKE_COMMAND} --build ${DEPS_BUILD_DIR}
        --config ${CMAKE_BUILD_TYPE})
    set(DEPS_PREFIX ${DEPS_BUILD_DIR}/usr)
  endif()
endif()

if(CMAKE_CROSSCOMPILING AND NOT UNIX)
  list(INSERT CMAKE_FIND_ROOT_PATH 0 ${DEPS_PREFIX})
  list(INSERT CMAKE_PREFIX_PATH 0 ${DEPS_PREFIX}/../host/bin)
else()
  list(INSERT CMAKE_PREFIX_PATH 0 ${DEPS_PREFIX})
  set(ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:${DEPS_PREFIX}/lib/pkgconfig")
endif()

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
endif()

if(WIN32 OR CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  # Enable fixing case-insensitive filenames for Windows and Mac.
  set(USE_FNAME_CASE TRUE)
endif()

option(ENABLE_LIBINTL "enable libintl" ON)
option(ENABLE_LIBICONV "enable libiconv" ON)
if (MINGW)
  # Disable LTO by default as it may not compile
  # See https://github.com/Alexpux/MINGW-packages/issues/3516
  # and https://github.com/neovim/neovim/pull/8654#issuecomment-402316672
  option(ENABLE_LTO "enable link time optimization" OFF)
else()
  option(ENABLE_LTO "enable link time optimization" ON)
endif()

# Set default build type.
if(NOT CMAKE_BUILD_TYPE)
  message(STATUS "CMAKE_BUILD_TYPE not given, defaulting to 'Debug'.")
  set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Choose the type of build." FORCE)
endif()

# Set available build types for CMake GUIs.
# A different build type can still be set by -DCMAKE_BUILD_TYPE=...
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY
  STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")

# If not in a git repo (e.g., a tarball) these tokens define the complete
# version string, else they are combined with the result of `git describe`.
set(NVIM_VERSION_MAJOR 0)
set(NVIM_VERSION_MINOR 3)
set(NVIM_VERSION_PATCH 2)
set(NVIM_VERSION_PRERELEASE "-dev") # for package maintainers

# API level
set(NVIM_API_LEVEL 5)         # Bump this after any API change.
set(NVIM_API_LEVEL_COMPAT 0)  # Adjust this after a _breaking_ API change.
set(NVIM_API_PRERELEASE true)

file(TO_CMAKE_PATH ${CMAKE_CURRENT_LIST_DIR}/.git FORCED_GIT_DIR)
include(GetGitRevisionDescription)
get_git_head_revision(GIT_REFSPEC NVIM_VERSION_COMMIT)
if(NVIM_VERSION_COMMIT) # is a git repo
  git_describe(NVIM_VERSION_MEDIUM)
  # `git describe` annotates the most recent tagged release; for pre-release
  # builds we must replace that with the unreleased version.
  string(REGEX REPLACE "^v[0-9]+\\.[0-9]+\\.[0-9]+"
         "v${NVIM_VERSION_MAJOR}.${NVIM_VERSION_MINOR}.${NVIM_VERSION_PATCH}"
         NVIM_VERSION_MEDIUM
         ${NVIM_VERSION_MEDIUM})
endif()

set(NVIM_VERSION_BUILD_TYPE "${CMAKE_BUILD_TYPE}")
# NVIM_VERSION_CFLAGS set further below.

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Default to -O2 on release builds.
if(CMAKE_C_FLAGS_RELEASE MATCHES "-O3")
  message(STATUS "Replacing -O3 in CMAKE_C_FLAGS_RELEASE with -O2.")
  string(REPLACE "-O3" "-O2" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}")
endif()

# Minimize logging for release-type builds.
if(NOT CMAKE_C_FLAGS_RELEASE MATCHES DMIN_LOG_LEVEL)
  set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -DMIN_LOG_LEVEL=3")
endif()
if(NOT CMAKE_C_FLAGS_MINSIZEREL MATCHES DMIN_LOG_LEVEL)
  set(CMAKE_C_FLAGS_MINSIZEREL "${CMAKE_C_FLAGS_MINSIZEREL} -DMIN_LOG_LEVEL=3")
endif()
if(NOT CMAKE_C_FLAGS_RELWITHDEBINFO MATCHES DMIN_LOG_LEVEL)
  set(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO} -DMIN_LOG_LEVEL=3")
endif()

if(CMAKE_COMPILER_IS_GNUCC)
  check_c_compiler_flag(-Og HAS_OG_FLAG)
else()
  set(HAS_OG_FLAG 0)
endif()

#
# Build-type: RelWithDebInfo
#
if(HAS_OG_FLAG)
  set(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO} -Og -g")
endif()
# We _want_ assertions in RelWithDebInfo build-type.
if(CMAKE_C_FLAGS_RELWITHDEBINFO MATCHES DNDEBUG)
  string(REPLACE "-DNDEBUG" "" CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}")
endif()

# Enable -Wconversion.
if(NOT MSVC)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wconversion")
endif()

# gcc 4.0+ sets _FORTIFY_SOURCE=2 automatically.  This currently
# does not work with Neovim due to some uses of dynamically-sized structures.
# https://github.com/neovim/neovim/issues/223
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

# Include <string.h> because some toolchains define _FORTIFY_SOURCE=2 in
# internal header files, which should in turn be #included by <string.h>.
check_c_source_compiles("
#include <string.h>

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

check_c_source_compiles("
#include <execinfo.h>
int main(void)
{
  void *trace[1];
  int trace_size = backtrace(trace, 1);
  return 0;
}
" HAVE_EXECINFO_BACKTRACE)

if(MSVC)
  # XXX: /W4 gives too many warnings. #3241
  add_definitions(/W3 -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE)
  add_definitions(-DWIN32)
else()
  add_definitions(-Wall -Wextra -pedantic -Wno-unused-parameter
    -Wstrict-prototypes -std=gnu99)

  check_c_compiler_flag(-Wimplicit-fallthrough HAS_WIMPLICIT_FALLTHROUGH_FLAG)
  if(HAS_WIMPLICIT_FALLTHROUGH_FLAG)
    add_definitions(-Wimplicit-fallthrough)
  endif()

  # On FreeBSD 64 math.h uses unguarded C11 extension, which taints clang
  # 3.4.1 used there.
  if(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD" AND CMAKE_C_COMPILER_ID MATCHES "Clang")
    add_definitions(-Wno-c11-extensions)
  endif()
endif()

if(MINGW)
  # Use POSIX compatible stdio in Mingw
  add_definitions(-D__USE_MINGW_ANSI_STDIO)
endif()
if(WIN32)
  # Windows Vista is the minimum supported version
  add_definitions(-D_WIN32_WINNT=0x0600)
endif()

# OpenBSD's GCC (4.2.1) doesn't have -Wvla
check_c_compiler_flag(-Wvla HAS_WVLA_FLAG)
if(HAS_WVLA_FLAG)
  add_definitions(-Wvla)
endif()

if(UNIX)
  # -fstack-protector breaks non Unix builds even in Mingw-w64
  check_c_compiler_flag(-fstack-protector-strong HAS_FSTACK_PROTECTOR_STRONG_FLAG)
  check_c_compiler_flag(-fstack-protector HAS_FSTACK_PROTECTOR_FLAG)

  if(HAS_FSTACK_PROTECTOR_STRONG_FLAG)
    add_definitions(-fstack-protector-strong)
  elseif(HAS_FSTACK_PROTECTOR_FLAG)
    add_definitions(-fstack-protector --param ssp-buffer-size=4)
  endif()
endif()

check_c_compiler_flag(-fdiagnostics-color=auto HAS_DIAG_COLOR_FLAG)
if(HAS_DIAG_COLOR_FLAG)
  add_definitions(-fdiagnostics-color=auto)
endif()

if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  # 1. Array-bounds testing is broken in some GCC versions before 4.8.5.
  #    https://gcc.gnu.org/bugzilla/show_bug.cgi?id=56273
  # 2. But _Pragma("...ignored") is broken (unresolved) in GCC 5+:
  #    https://gcc.gnu.org/bugzilla/show_bug.cgi?id=66099
  # So we must disable -Warray-bounds globally for GCC (for kbtree.h, #7083).
  check_c_compiler_flag(-Wno-array-bounds HAS_NO_ARRAY_BOUNDS_FLAG)
  if(HAS_NO_ARRAY_BOUNDS_FLAG)
    add_definitions(-Wno-array-bounds)
  endif()
endif()

option(TRAVIS_CI_BUILD "Travis/QuickBuild CI. Extra flags will be set." OFF)

if(TRAVIS_CI_BUILD)
  message(STATUS "Travis/QuickBuild CI build enabled.")
  add_definitions(-Werror)
  if(DEFINED ENV{BUILD_32BIT})
    # Get some test coverage for unsigned char
    add_definitions(-funsigned-char)
  endif()
endif()

if(CMAKE_BUILD_TYPE MATCHES Debug)
  set(DEBUG 1)
else()
  set(DEBUG 0)
endif()

option(LOG_LIST_ACTIONS "Add list actions logging" OFF)

add_definitions(-DINCLUDE_GENERATED_DECLARATIONS)

if(CMAKE_C_COMPILER_ID STREQUAL "GNU" OR CMAKE_C_COMPILER_ID STREQUAL "Clang")
  if(CMAKE_SYSTEM_NAME STREQUAL "SunOS")
    set(NO_UNDEFINED "-Wl,--no-undefined -lsocket")
  elseif(NOT CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(NO_UNDEFINED "-Wl,--no-undefined")
  endif()
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${NO_UNDEFINED}")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${NO_UNDEFINED}")

  # For O_CLOEXEC, O_DIRECTORY, and O_NOFOLLOW flags on older systems
  # (pre POSIX.1-2008: glibc 2.11 and earlier). #4042
  # For ptsname(). #6743
  add_definitions(-D_GNU_SOURCE)
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

find_package(LibUV REQUIRED)
include_directories(SYSTEM ${LIBUV_INCLUDE_DIRS})

find_package(Msgpack 1.0.0 REQUIRED)
include_directories(SYSTEM ${MSGPACK_INCLUDE_DIRS})

# Note: The test lib requires LuaJIT; it will be skipped if LuaJIT is missing.
option(PREFER_LUA "Prefer Lua over LuaJIT in the nvim executable." OFF)

if(PREFER_LUA)
  find_package(Lua REQUIRED)
  set(LUA_PREFERRED_INCLUDE_DIRS ${LUA_INCLUDE_DIR})
  set(LUA_PREFERRED_LIBRARIES ${LUA_LIBRARIES})
  # Passive (not REQUIRED): if LUAJIT_FOUND is not set, nvim-test is skipped.
  find_package(LuaJit)
else()
  find_package(LuaJit REQUIRED)
  set(LUA_PREFERRED_INCLUDE_DIRS ${LUAJIT_INCLUDE_DIRS})
  set(LUA_PREFERRED_LIBRARIES ${LUAJIT_LIBRARIES})
endif()

list(APPEND CMAKE_REQUIRED_INCLUDES "${MSGPACK_INCLUDE_DIRS}")
check_c_source_compiles("
#include <msgpack.h>

int
main(void)
{
  return MSGPACK_OBJECT_FLOAT32;
}
" MSGPACK_HAS_FLOAT32)
if(MSGPACK_HAS_FLOAT32)
  add_definitions(-DNVIM_MSGPACK_HAS_FLOAT32)
endif()

option(FEAT_TUI "Enable the Terminal UI" ON)

if(FEAT_TUI)
  find_package(Unibilium REQUIRED)
  include_directories(SYSTEM ${UNIBILIUM_INCLUDE_DIRS})

  list(APPEND CMAKE_REQUIRED_INCLUDES "${UNIBILIUM_INCLUDE_DIRS}")
  list(APPEND CMAKE_REQUIRED_LIBRARIES "${UNIBILIUM_LIBRARIES}")
  check_c_source_compiles("
  #include <unibilium.h>

  int
  main(void)
  {
    return unibi_num_from_var(unibi_var_from_num(0));
  }
  " UNIBI_HAS_VAR_FROM)
  if(UNIBI_HAS_VAR_FROM)
    add_definitions(-DNVIM_UNIBI_HAS_VAR_FROM)
  endif()

  find_package(LibTermkey REQUIRED)
  include_directories(SYSTEM ${LIBTERMKEY_INCLUDE_DIRS})
endif()

find_package(LibVterm REQUIRED)
include_directories(SYSTEM ${LIBVTERM_INCLUDE_DIRS})

if(WIN32)
  find_package(Winpty REQUIRED)
  include_directories(SYSTEM ${WINPTY_INCLUDE_DIRS})
endif()

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

if(CMAKE_SYSTEM_NAME MATCHES "OpenBSD|FreeBSD|Windows")  # see #5318
  message(STATUS "skipping jemalloc on this system: ${CMAKE_SYSTEM_NAME}")
  option(ENABLE_JEMALLOC "enable jemalloc" OFF)
else()
  option(ENABLE_JEMALLOC "enable jemalloc" ON)
endif()

if(ENABLE_JEMALLOC)
  if(CLANG_ASAN_UBSAN OR CLANG_MSAN OR CLANG_TSAN)
    message(STATUS "Sanitizers have been enabled; don't use jemalloc.")
  else()
    find_package(JeMalloc REQUIRED)
    include_directories(SYSTEM ${JEMALLOC_INCLUDE_DIRS})
  endif()
endif()

if(ENABLE_LIBINTL)
  # LibIntl (not Intl) selects our FindLibIntl.cmake script. #8464
  find_package(LibIntl REQUIRED)
  include_directories(SYSTEM ${LibIntl_INCLUDE_DIRS})
endif()

if(ENABLE_LIBICONV)
  find_package(Iconv REQUIRED)
  include_directories(SYSTEM ${Iconv_INCLUDE_DIRS})
endif()

# Determine platform's threading library. Set CMAKE_THREAD_PREFER_PTHREAD
# explicitly to indicate a strong preference for pthread.
set(CMAKE_THREAD_PREFER_PTHREAD ON)
find_package(Threads REQUIRED)

# Place targets in bin/ or lib/ for all build configurations
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
foreach(CFGNAME ${CMAKE_CONFIGURATION_TYPES})
  string(TOUPPER ${CFGNAME} CFGNAME)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CFGNAME} ${CMAKE_BINARY_DIR}/bin)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CFGNAME} ${CMAKE_BINARY_DIR}/lib)
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CFGNAME} ${CMAKE_BINARY_DIR}/lib)
endforeach()

# Find Lua interpreter
include(LuaHelpers)
set(LUA_DEPENDENCIES lpeg mpack bit)
if(NOT LUA_PRG)
  foreach(CURRENT_LUA_PRG luajit lua5.1 lua5.2 lua)
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
find_program(BUSTED_PRG NAMES busted busted.bat)
find_program(BUSTED_LUA_PRG busted-lua)
if(NOT BUSTED_OUTPUT_TYPE)
  set(BUSTED_OUTPUT_TYPE "nvim")
endif()

find_program(LUACHECK_PRG luacheck)
find_program(GPERF_PRG gperf)

include(InstallHelpers)

file(GLOB MANPAGES
  RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
  man/nvim.1)
install_helper(
  FILES ${MANPAGES}
  DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)

# MIN_LOG_LEVEL for log.h
if("${MIN_LOG_LEVEL}" MATCHES "^$")
  message(STATUS "MIN_LOG_LEVEL not specified")
else()
  if(NOT MIN_LOG_LEVEL MATCHES "^[0-3]$")
    message(FATAL_ERROR "invalid MIN_LOG_LEVEL: " ${MIN_LOG_LEVEL})
  endif()
  message(STATUS "MIN_LOG_LEVEL set to ${MIN_LOG_LEVEL}")
endif()

# Go down the tree.

add_subdirectory(src/nvim)
# Read compilation flags from src/nvim, used in config subdirectory below.
include(GetCompileFlags)
get_compile_flags(NVIM_VERSION_CFLAGS)

add_subdirectory(test/includes)
add_subdirectory(config)
add_subdirectory(test/functional/fixtures)  # compile test programs
add_subdirectory(runtime)
if(WIN32)
  install_helper(
    FILES ${DEPS_PREFIX}/share/nvim-qt/runtime/plugin/nvim_gui_shim.vim
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim-qt/runtime/plugin)
endif()

# Setup some test-related bits.  We do this after going down the tree because we
# need some of the targets.
if(BUSTED_PRG)
  get_property(TEST_INCLUDE_DIRS DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    PROPERTY INCLUDE_DIRECTORIES)

  # When running tests from 'ninja' we need to use the
  # console pool: to do so we need to use the USES_TERMINAL
  # option, but this is only available in CMake 3.2
  set(TEST_TARGET_ARGS)
  if(NOT (${CMAKE_VERSION} VERSION_LESS 3.2.0))
    list(APPEND TEST_TARGET_ARGS "USES_TERMINAL")
  endif()

  set(UNITTEST_PREREQS nvim-test unittest-headers)
  set(FUNCTIONALTEST_PREREQS nvim printargs-test shell-test)
  if(NOT WIN32)
    list(APPEND FUNCTIONALTEST_PREREQS tty-test)
  endif()
  set(BENCHMARK_PREREQS nvim tty-test)

  # Useful for automated build systems, if they want to manually run the tests.
  add_custom_target(unittest-prereqs
    DEPENDS ${UNITTEST_PREREQS})
  set_target_properties(unittest-prereqs PROPERTIES FOLDER test)

  add_custom_target(functionaltest-prereqs
    DEPENDS ${FUNCTIONALTEST_PREREQS})

  add_custom_target(benchmark-prereqs
    DEPENDS ${BENCHMARK_PREREQS})

  check_lua_module(${LUA_PRG} "ffi" LUA_HAS_FFI)
  if(LUA_HAS_FFI)
    add_custom_target(unittest
      COMMAND ${CMAKE_COMMAND}
        -DBUSTED_PRG=${BUSTED_PRG}
        -DLUA_PRG=${LUA_PRG}
        -DWORKING_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
        -DTEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}/test
        -DBUILD_DIR=${CMAKE_BINARY_DIR}
        -DTEST_TYPE=unit
        -DSYSTEM_NAME=${CMAKE_SYSTEM_NAME}
        -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
      DEPENDS ${UNITTEST_PREREQS}
      ${TEST_TARGET_ARGS})
    set_target_properties(unittest PROPERTIES FOLDER test)
  else()
    message(WARNING "disabling unit tests: no Luajit FFI in ${LUA_PRG}")
  endif()

  if(LUA_HAS_FFI)
    set(TEST_LIBNVIM_PATH $<TARGET_FILE:nvim-test>)
  else()
    set(TEST_LIBNVIM_PATH "")
  endif()
  configure_file(
    ${CMAKE_SOURCE_DIR}/test/config/paths.lua.in
    ${CMAKE_BINARY_DIR}/test/config/paths.lua.gen)
  file(GENERATE
    OUTPUT ${CMAKE_BINARY_DIR}/test/config/paths.lua
    INPUT ${CMAKE_BINARY_DIR}/test/config/paths.lua.gen)

  add_custom_target(functionaltest
    COMMAND ${CMAKE_COMMAND}
      -DBUSTED_PRG=${BUSTED_PRG}
      -DLUA_PRG=${LUA_PRG}
      -DNVIM_PRG=$<TARGET_FILE:nvim>
      -DWORKING_DIR=${CMAKE_CURRENT_SOURCE_DIR}
      -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
      -DTEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}/test
      -DBUILD_DIR=${CMAKE_BINARY_DIR}
      -DTEST_TYPE=functional
      -DSYSTEM_NAME=${CMAKE_SYSTEM_NAME}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${FUNCTIONALTEST_PREREQS}
    ${TEST_TARGET_ARGS})
  set_target_properties(functionaltest functionaltest-prereqs
    PROPERTIES FOLDER test)

  add_custom_target(benchmark
    COMMAND ${CMAKE_COMMAND}
      -DBUSTED_PRG=${BUSTED_PRG}
      -DLUA_PRG=${LUA_PRG}
      -DNVIM_PRG=$<TARGET_FILE:nvim>
      -DWORKING_DIR=${CMAKE_CURRENT_SOURCE_DIR}
      -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
      -DTEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}/test
      -DBUILD_DIR=${CMAKE_BINARY_DIR}
      -DTEST_TYPE=benchmark
      -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${BENCHMARK_PREREQS}
    ${TEST_TARGET_ARGS})
  set_target_properties(benchmark benchmark-prereqs PROPERTIES FOLDER test)
endif()

if(BUSTED_LUA_PRG)
  add_custom_target(functionaltest-lua
    COMMAND ${CMAKE_COMMAND}
      -DBUSTED_PRG=${BUSTED_LUA_PRG}
      -DLUA_PRG=${LUA_PRG}
      -DNVIM_PRG=$<TARGET_FILE:nvim>
      -DWORKING_DIR=${CMAKE_CURRENT_SOURCE_DIR}
      -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
      -DTEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}/test
      -DBUILD_DIR=${CMAKE_BINARY_DIR}
      -DTEST_TYPE=functional
      -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${FUNCTIONALTEST_PREREQS}
    ${TEST_TARGET_ARGS})
    set_target_properties(functionaltest-lua PROPERTIES FOLDER test)
endif()

if(LUACHECK_PRG)
  add_custom_target(testlint
    COMMAND ${CMAKE_COMMAND}
      -DLUACHECK_PRG=${LUACHECK_PRG}
      -DLUAFILES_DIR=${CMAKE_CURRENT_SOURCE_DIR}/test
      -DIGNORE_PATTERN="*/preload.lua"
      -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunLuacheck.cmake)

  add_custom_target(
    blobcodelint
    COMMAND
      ${CMAKE_COMMAND}
        -DLUACHECK_PRG=${LUACHECK_PRG}
        -DLUAFILES_DIR=${CMAKE_CURRENT_SOURCE_DIR}/src/nvim/lua
        -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}
        -DREAD_GLOBALS=vim
        -P ${PROJECT_SOURCE_DIR}/cmake/RunLuacheck.cmake
  )
  # TODO(ZyX-I): Run linter for all lua code in src
  add_custom_target(
    lualint
    DEPENDS blobcodelint
  )
endif()

set(CPACK_PACKAGE_NAME "Neovim")
set(CPACK_PACKAGE_VENDOR "neovim.io")
set(CPACK_PACKAGE_VERSION ${NVIM_VERSION_MEDIUM})
set(CPACK_PACKAGE_INSTALL_DIRECTORY "Neovim")
# Set toplevel directory/installer name as Neovim
set(CPACK_PACKAGE_FILE_NAME "Neovim")
set(CPACK_TOPLEVEL_TAG "Neovim")
set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/LICENSE")
set(CPACK_NSIS_MODIFY_PATH ON)
set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
include(CPack)
