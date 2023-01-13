# CMAKE REFERENCE
#   intro: https://codingnest.com/basic-cmake/
#   best practices (3.0+): https://gist.github.com/mbinna/c61dbb39bca0e4fb7d1f73b0d66a4fd1
#   pitfalls: https://izzys.casa/2019/02/everything-you-never-wanted-to-know-about-cmake/

# Version should match the tested CMAKE_URL in .github/workflows/ci.yml.
cmake_minimum_required(VERSION 3.10)

# Can be removed once minimum version is at least 3.15
if(POLICY CMP0092)
  cmake_policy(SET CMP0092 NEW)
endif()

project(nvim C)

if(POLICY CMP0075)
  cmake_policy(SET CMP0075 NEW)
endif()

# Point CMake at any custom modules we may ship
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

include(CheckCCompilerFlag)
include(CheckCSourceCompiles)
include(InstallHelpers)
include(LuaHelpers) # Find Lua interpreter
include(PreventInTreeBuilds)
include(Util)

set(TOUCHES_DIR ${PROJECT_BINARY_DIR}/touches)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Prefer our bundled versions of dependencies.
if(DEFINED ENV{DEPS_BUILD_DIR})
  if(CMAKE_SYSTEM_NAME MATCHES "OpenBSD")
    # pkg-config 29.2 has a bug on OpenBSD which causes it to drop any paths that
    # *contain* system include paths. To avoid this, we prefix what would be
    # "/usr/include" as "/_usr/include".
    # This check is also performed in the cmake.deps/CMakeLists.txt and in the
    # else clause following here.
    # https://github.com/neovim/neovim/pull/14745#issuecomment-860201794
    set(DEPS_PREFIX "$ENV{DEPS_BUILD_DIR}/_usr" CACHE PATH "Path prefix for finding dependencies")
  else()
    set(DEPS_PREFIX "$ENV{DEPS_BUILD_DIR}/usr" CACHE PATH "Path prefix for finding dependencies")
  endif()
else()
  if(CMAKE_SYSTEM_NAME MATCHES "OpenBSD")
    set(DEPS_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/.deps/_usr" CACHE PATH "Path prefix for finding dependencies")
  else()
    set(DEPS_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/.deps/usr" CACHE PATH "Path prefix for finding dependencies")
  endif()
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
        ${PROJECT_SOURCE_DIR}/cmake.deps
      WORKING_DIRECTORY ${DEPS_BUILD_DIR})
    execute_process(
      COMMAND ${CMAKE_COMMAND} --build ${DEPS_BUILD_DIR}
        --config ${CMAKE_BUILD_TYPE})
    set(DEPS_PREFIX ${DEPS_BUILD_DIR}/usr)
  endif()
endif()

list(INSERT CMAKE_PREFIX_PATH 0 ${DEPS_PREFIX})
set(ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:${DEPS_PREFIX}/lib/pkgconfig")

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  # If the macOS deployment target is not set manually (via $MACOSX_DEPLOYMENT_TARGET),
  # fall back to local system version. Needs to be done both here and in cmake.deps.
  if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    execute_process(COMMAND sw_vers -productVersion
                    OUTPUT_VARIABLE MACOS_VERSION
                    OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "${MACOS_VERSION}")
  endif()
  message(STATUS "Using deployment target ${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()

if(WIN32 OR CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  # Ignore case when comparing filenames on Windows and Mac.
  set(CASE_INSENSITIVE_FILENAME TRUE)
  # Enable fixing case-insensitive filenames for Windows and Mac.
  set(USE_FNAME_CASE TRUE)
endif()

if (MINGW)
  # Disable LTO by default as it may not compile
  # See https://github.com/Alexpux/MINGW-packages/issues/3516
  # and https://github.com/neovim/neovim/pull/8654#issuecomment-402316672
  option(ENABLE_LTO "enable link time optimization" OFF)
else()
  option(ENABLE_LTO "enable link time optimization" ON)
endif()

message(STATUS "CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}")

set_default_buildtype()
if(CMAKE_BUILD_TYPE MATCHES Debug)
  set(DEBUG 1)
else()
  set(DEBUG 0)
endif()

# If not in a git repo (e.g., a tarball) these tokens define the complete
# version string, else they are combined with the result of `git describe`.
set(NVIM_VERSION_MAJOR 0)
set(NVIM_VERSION_MINOR 9)
set(NVIM_VERSION_PATCH 0)
set(NVIM_VERSION_PRERELEASE "-dev") # for package maintainers

# API level
set(NVIM_API_LEVEL 11)         # Bump this after any API change.
set(NVIM_API_LEVEL_COMPAT 0)  # Adjust this after a _breaking_ API change.
set(NVIM_API_PRERELEASE true)

set(NVIM_VERSION_BUILD_TYPE "${CMAKE_BUILD_TYPE}")
# NVIM_VERSION_CFLAGS set further below.

# Log level (MIN_LOG_LEVEL in log.h)
if("${MIN_LOG_LEVEL}" MATCHES "^$")
  # Minimize logging for release-type builds.
  if(CMAKE_BUILD_TYPE STREQUAL "Release"
      OR CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo"
      OR CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
    message(STATUS "MIN_LOG_LEVEL not specified, default is 3 (ERROR) for release builds")
    set(MIN_LOG_LEVEL 3)
  else()
    message(STATUS "MIN_LOG_LEVEL not specified, default is 1 (INFO)")
    set(MIN_LOG_LEVEL 1)
  endif()
else()
  if(NOT MIN_LOG_LEVEL MATCHES "^[0-3]$")
    message(FATAL_ERROR "invalid MIN_LOG_LEVEL: " ${MIN_LOG_LEVEL})
  endif()
  message(STATUS "MIN_LOG_LEVEL=${MIN_LOG_LEVEL}")
endif()

# Default to -O2 on release builds.
if(CMAKE_C_FLAGS_RELEASE MATCHES "-O3")
  message(STATUS "Replacing -O3 in CMAKE_C_FLAGS_RELEASE with -O2")
  string(REPLACE "-O3" "-O2" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}")
endif()

if(CMAKE_C_COMPILER_ID MATCHES "GNU")
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

# gcc 4.0+ sets _FORTIFY_SOURCE=2 automatically.  This currently
# does not work with Neovim due to some uses of dynamically-sized structures.
# https://github.com/neovim/neovim/issues/223

# Include the build type's default flags in the check for _FORTIFY_SOURCE,
# otherwise we may incorrectly identify the level as acceptable and find out
# later that it was not when optimizations were enabled.  CFLAGS is applied
# even though you don't see it in CMAKE_REQUIRED_FLAGS.
set(INIT_FLAGS_NAME CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE})
string(TOUPPER ${INIT_FLAGS_NAME} INIT_FLAGS_NAME)
if(${INIT_FLAGS_NAME})
  set(CMAKE_REQUIRED_FLAGS "${${INIT_FLAGS_NAME}}")
endif()

option(LOG_LIST_ACTIONS "Add list actions logging" OFF)

option(CLANG_ASAN_UBSAN "Enable Clang address & undefined behavior sanitizer for nvim binary." OFF)
option(CLANG_MSAN "Enable Clang memory sanitizer for nvim binary." OFF)
option(CLANG_TSAN "Enable Clang thread sanitizer for nvim binary." OFF)

if((CLANG_ASAN_UBSAN AND CLANG_MSAN)
    OR (CLANG_ASAN_UBSAN AND CLANG_TSAN)
    OR (CLANG_MSAN AND CLANG_TSAN))
  message(FATAL_ERROR "Sanitizers cannot be enabled simultaneously")
endif()

if((CLANG_ASAN_UBSAN OR CLANG_MSAN OR CLANG_TSAN) AND NOT CMAKE_C_COMPILER_ID MATCHES "Clang")
  message(FATAL_ERROR "Sanitizers are only supported for Clang")
endif()

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

set(LUA_DEPENDENCIES lpeg mpack bit)
if(NOT LUA_PRG)
  foreach(CURRENT_LUA_PRG luajit lua5.1 lua5.2 lua)
    unset(_CHECK_LUA_PRG CACHE)
    unset(LUA_PRG_WORKS)
    find_program(_CHECK_LUA_PRG ${CURRENT_LUA_PRG})

    if(_CHECK_LUA_PRG)
      check_lua_deps(${_CHECK_LUA_PRG} "${LUA_DEPENDENCIES}" LUA_PRG_WORKS)
      if(LUA_PRG_WORKS)
        set(LUA_PRG "${_CHECK_LUA_PRG}" CACHE FILEPATH "Path to a program.")
        break()
      endif()
    endif()
  endforeach()
  unset(_CHECK_LUA_PRG CACHE)
else()
  check_lua_deps(${LUA_PRG} "${LUA_DEPENDENCIES}" LUA_PRG_WORKS)
endif()

if(NOT LUA_PRG_WORKS)
  message(FATAL_ERROR "Failed to find a Lua 5.1-compatible interpreter")
endif()

message(STATUS "Using Lua interpreter: ${LUA_PRG}")

option(COMPILE_LUA "Pre-compile Lua sources into bytecode (for sources that are included in the binary)" ON)

if(COMPILE_LUA AND NOT WIN32)
  if(PREFER_LUA)
    foreach(CURRENT_LUAC_PRG luac5.1 luac)
      find_program(_CHECK_LUAC_PRG ${CURRENT_LUAC_PRG})
      if(_CHECK_LUAC_PRG)
        set(LUAC_PRG "${_CHECK_LUAC_PRG} -s -o - %s" CACHE STRING "Format for compiling to Lua bytecode")
        break()
      endif()
    endforeach()
  elseif(LUA_PRG MATCHES "luajit")
    check_lua_module(${LUA_PRG} "jit.bcsave" LUAJIT_HAS_JIT_BCSAVE)
    if(LUAJIT_HAS_JIT_BCSAVE)
      set(LUAC_PRG "${LUA_PRG} -b -s %s -" CACHE STRING "Format for compiling to Lua bytecode")
    endif()
  endif()
endif()

if(LUAC_PRG)
  message(STATUS "Using Lua compiler: ${LUAC_PRG}")
endif()

#
# Lint
#
find_program(LUACHECK_PRG luacheck)
find_program(STYLUA_PRG stylua)
find_program(UNCRUSTIFY_PRG uncrustify)
find_program(SHELLCHECK_PRG shellcheck)

add_glob_target(
  REQUIRED
  TARGET lintlua-luacheck
  COMMAND ${LUACHECK_PRG}
  FLAGS -q
  GLOB_DIRS runtime/ scripts/ src/ test/
  GLOB_PAT *.lua
  TOUCH_STRATEGY SINGLE)

add_glob_target(
  TARGET lintlua-stylua
  COMMAND ${STYLUA_PRG}
  FLAGS --color=always --check
  GLOB_DIRS runtime/
  GLOB_PAT *.lua
  TOUCH_STRATEGY SINGLE)

add_custom_target(lintlua)
add_dependencies(lintlua lintlua-luacheck lintlua-stylua)

add_glob_target(
  TARGET lintsh
  COMMAND ${SHELLCHECK_PRG}
  FLAGS -x -a
  GLOB_DIRS scripts ci
  GLOB_PAT *.sh
  EXCLUDE
    scripts/pvscheck.sh
    ci/common
    ci/snap
  TOUCH_STRATEGY SINGLE)

add_custom_target(lintcommit
  COMMAND ${PROJECT_BINARY_DIR}/bin/nvim -u NONE -es -c [[lua require('scripts.lintcommit').main({trace=false})]]
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  VERBATIM)
add_dependencies(lintcommit nvim)

add_custom_target(lint)
add_dependencies(lint check-single-includes lintc lintlua lintsh lintcommit)

#
# Format
#
add_custom_target(formatlua
  COMMAND ${CMAKE_COMMAND}
    -D FORMAT_PRG=${STYLUA_PRG}
    -D LANG=lua
    -P ${PROJECT_SOURCE_DIR}/cmake/Format.cmake
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR})

add_custom_target(format)
add_dependencies(format formatc formatlua)

install_helper(
  FILES ${CMAKE_SOURCE_DIR}/src/man/nvim.1
  DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)

option(ENABLE_LIBICONV "enable libiconv" ON)
if(ENABLE_LIBICONV)
  find_package(Iconv REQUIRED)
endif()

#
# Go down the tree.
#

add_subdirectory(src/nvim)
get_directory_property(NVIM_VERSION_CFLAGS DIRECTORY src/nvim DEFINITION NVIM_VERSION_CFLAGS)
add_subdirectory(test/includes)
add_subdirectory(cmake.config)
add_subdirectory(test/functional/fixtures)  # compile test programs
add_subdirectory(runtime)
get_directory_property(GENERATED_HELP_TAGS DIRECTORY runtime DEFINITION GENERATED_HELP_TAGS)
if(WIN32)
  install_helper(
    FILES ${DEPS_PREFIX}/share/nvim-qt/runtime/plugin/nvim_gui_shim.vim
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim-qt/runtime/plugin)
endif()

# Setup busted.
find_program(BUSTED_PRG NAMES busted busted.bat)
find_program(BUSTED_LUA_PRG busted-lua)
if(NOT BUSTED_OUTPUT_TYPE)
  set(BUSTED_OUTPUT_TYPE "nvim")
endif()

# Setup some test-related bits.  We do this after going down the tree because we
# need some of the targets.
if(BUSTED_PRG)
  get_target_property(TEST_INCLUDE_DIRS main_lib INTERFACE_INCLUDE_DIRECTORIES)

  set(UNITTEST_PREREQS nvim-test unittest-headers)
  set(FUNCTIONALTEST_PREREQS nvim printenv-test printargs-test shell-test pwsh-test streams-test tty-test ${GENERATED_HELP_TAGS})
  set(BENCHMARK_PREREQS nvim tty-test)

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
        -DCIRRUS_CI=$ENV{CIRRUS_CI}
        -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
      DEPENDS ${UNITTEST_PREREQS}
      USES_TERMINAL)
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
    ${CMAKE_SOURCE_DIR}/test/cmakeconfig/paths.lua.in
    ${CMAKE_BINARY_DIR}/test/cmakeconfig/paths.lua.gen)
  file(GENERATE
    OUTPUT ${CMAKE_BINARY_DIR}/test/cmakeconfig/paths.lua
    INPUT ${CMAKE_BINARY_DIR}/test/cmakeconfig/paths.lua.gen)

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
      -DCIRRUS_CI=$ENV{CIRRUS_CI}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${FUNCTIONALTEST_PREREQS}
    USES_TERMINAL)
  set_target_properties(functionaltest PROPERTIES FOLDER test)

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
      -DCIRRUS_CI=$ENV{CIRRUS_CI}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${BENCHMARK_PREREQS}
    USES_TERMINAL)
  set_target_properties(benchmark PROPERTIES FOLDER test)
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
      -DCIRRUS_CI=$ENV{CIRRUS_CI}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${FUNCTIONALTEST_PREREQS}
    USES_TERMINAL)
    set_target_properties(functionaltest-lua PROPERTIES FOLDER test)
endif()

add_custom_target(uninstall
  COMMAND ${CMAKE_COMMAND} -P ${PROJECT_SOURCE_DIR}/cmake/UninstallHelper.cmake)

if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_SOURCE_DIR})
  add_subdirectory(cmake.packaging)
endif()
