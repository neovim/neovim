# CMAKE REFERENCE
#   intro: https://codingnest.com/basic-cmake/
#   best practices (3.0+): https://gist.github.com/mbinna/c61dbb39bca0e4fb7d1f73b0d66a4fd1
#   pitfalls: https://izzys.casa/2019/02/everything-you-never-wanted-to-know-about-cmake/

# Version should match the tested CMAKE_URL in .github/workflows/build.yml.
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
include(FindPackageHandleStandardArgs)
include(InstallHelpers)
include(LuaHelpers)
include(PreventInTreeBuilds)
include(Util)

set(TOUCHES_DIR ${PROJECT_BINARY_DIR}/touches)

find_program(CCACHE_PRG ccache)
if(CCACHE_PRG)
  set(CMAKE_C_COMPILER_LAUNCHER ${CMAKE_COMMAND} -E env CCACHE_SLOPPINESS=pch_defines,time_macros ${CCACHE_PRG})
endif()

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
        -D CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        -D CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -D CMAKE_C_COMPILER=${CMAKE_C_COMPILER}
        -D CMAKE_C_FLAGS=${CMAKE_C_FLAGS}
        -D CMAKE_C_FLAGS_DEBUG=${CMAKE_C_FLAGS_DEBUG}
        -D CMAKE_C_FLAGS_MINSIZEREL=${CMAKE_C_FLAGS_MINSIZEREL}
        -D CMAKE_C_FLAGS_RELWITHDEBINFO=${CMAKE_C_FLAGS_RELWITHDEBINFO}
        -D CMAKE_C_FLAGS_RELEASE=${CMAKE_C_FLAGS_RELEASE}
        -D CMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}
        ${PROJECT_SOURCE_DIR}/cmake.deps
      WORKING_DIRECTORY ${DEPS_BUILD_DIR})
    execute_process(
      COMMAND ${CMAKE_COMMAND} --build ${DEPS_BUILD_DIR}
        --config ${CMAKE_BUILD_TYPE})
    set(DEPS_PREFIX ${DEPS_BUILD_DIR}/usr)
  endif()
endif()

list(INSERT CMAKE_PREFIX_PATH 0 ${DEPS_PREFIX})

if(APPLE)
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

if(WIN32 OR APPLE)
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

# Default to -O2 on release builds.
if(CMAKE_C_FLAGS_RELEASE MATCHES "-O3")
  message(STATUS "Replacing -O3 in CMAKE_C_FLAGS_RELEASE with -O2")
  string(REPLACE "-O3" "-O2" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}")
endif()

# Build-type: RelWithDebInfo

# /Og means something different in MSVC
if(CMAKE_C_COMPILER_ID MATCHES "GNU" OR CMAKE_C_COMPILER_ID MATCHES "Clang")
   set(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO} -Og -g")
endif()
# We _want_ assertions in RelWithDebInfo build-type.
if(CMAKE_C_FLAGS_RELWITHDEBINFO MATCHES DNDEBUG)
  string(REPLACE "-DNDEBUG" "" CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}")
  string(REPLACE "/DNDEBUG" "" CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}")
  string(REPLACE "  " " " CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}") # Remove duplicate whitespace
endif()

option(LOG_LIST_ACTIONS "Add list actions logging" OFF)

option(ENABLE_ASAN_UBSAN "Enable Clang address & undefined behavior sanitizer for nvim binary." OFF)
option(LOG_DEBUG "Enable debug log messages even in a release build" OFF)
option(ENABLE_MSAN "Enable Clang memory sanitizer for nvim binary." OFF)
option(ENABLE_TSAN "Enable Clang thread sanitizer for nvim binary." OFF)

if((ENABLE_ASAN_UBSAN AND ENABLE_MSAN)
    OR (ENABLE_ASAN_UBSAN AND ENABLE_TSAN)
    OR (ENABLE_MSAN AND ENABLE_TSAN))
  message(FATAL_ERROR "Sanitizers cannot be enabled simultaneously")
endif()

if(ENABLE_ASAN_UBSAN OR ENABLE_MSAN OR ENABLE_TSAN)
  if(NOT CMAKE_C_COMPILER_ID MATCHES "Clang" AND NOT CMAKE_C_COMPILER_ID MATCHES "GNU")
    message(FATAL_ERROR "Sanitizers are only supported for Clang and GCC")
  endif()
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

# Some of the code generation still relies on stable table ordering in order to
# produce reproducible output - specifically the msgpack'ed data in
# funcs_metadata.generated.h and ui_events_metadata.generated.h. This should
# ideally be fixed in the generators, but until then as a workaround you may provide
# a specific lua implementation that provides the needed stability by setting LUA_GEN_PRG:
if(NOT LUA_GEN_PRG)
  set(LUA_GEN_PRG "${LUA_PRG}" CACHE FILEPATH "Path to the lua used for code generation.")
endif()

message(STATUS "Using Lua interpreter for code generation: ${LUA_GEN_PRG}")

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
find_program(SHELLCHECK_PRG shellcheck)
find_program(STYLUA_PRG stylua)
find_program(UNCRUSTIFY_PRG uncrustify)

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
  GLOB_DIRS scripts
  GLOB_PAT *.sh
  EXCLUDE
    scripts/pvscheck.sh
  TOUCH_STRATEGY SINGLE)

add_custom_target(lintcommit
  COMMAND ${PROJECT_BINARY_DIR}/bin/nvim -u NONE -es -c [[lua require('scripts.lintcommit').main({trace=false})]]
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  VERBATIM)
add_dependencies(lintcommit nvim)

add_custom_target(lint)
add_dependencies(lint clang-tidy lintc lintlua lintsh lintcommit)

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

if(EXISTS "${DEPS_PREFIX}/share/nvim-qt")
  option(USE_BUNDLED_NVIMQT "Bundle neovim-qt" ON)
else()
  option(USE_BUNDLED_NVIMQT "Bundle neovim-qt" OFF)
endif()

add_subdirectory(src/nvim)
add_subdirectory(cmake.config)
add_subdirectory(runtime)
add_subdirectory(test)
if(WIN32 AND USE_BUNDLED_NVIMQT)
  install_helper(
    FILES ${DEPS_PREFIX}/share/nvim-qt/runtime/plugin/nvim_gui_shim.vim
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim-qt/runtime/plugin)
endif()

add_custom_target(uninstall
  COMMAND ${CMAKE_COMMAND} -P ${PROJECT_SOURCE_DIR}/cmake/UninstallHelper.cmake)

if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_SOURCE_DIR})
  add_subdirectory(cmake.packaging)
endif()
