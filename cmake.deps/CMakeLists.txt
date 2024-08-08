# This is not meant to be included by the top-level.
cmake_minimum_required (VERSION 3.13)
project(NVIM_DEPS C)

if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

# Point CMake at any custom modules we may ship
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake" "${PROJECT_SOURCE_DIR}/../cmake")

include(CheckCCompilerFlag)
include(ExternalProject)
include(FindPackageHandleStandardArgs)

include(Deps)
include(Find)
include(Util)

#-------------------------------------------------------------------------------
# User settings
#-------------------------------------------------------------------------------

set(DEPS_IGNORE_SHA FALSE)

# Options
option(USE_BUNDLED "Use bundled dependencies." ON)

option(USE_BUNDLED_LIBUV "Use the bundled libuv." ${USE_BUNDLED})
option(USE_BUNDLED_LPEG "Use the bundled lpeg." ${USE_BUNDLED})
# PUC Lua is only used for tests, unless explicitly requested.
option(USE_BUNDLED_LUA "Use the bundled version of lua." OFF)
option(USE_BUNDLED_LUAJIT "Use the bundled version of luajit." ${USE_BUNDLED})
option(USE_BUNDLED_LUV "Use the bundled version of luv." ${USE_BUNDLED})
option(USE_BUNDLED_TS "Use the bundled treesitter runtime." ${USE_BUNDLED})
option(USE_BUNDLED_TS_PARSERS "Use the bundled treesitter parsers." ${USE_BUNDLED})
option(USE_BUNDLED_UNIBILIUM "Use the bundled unibilium." ${USE_BUNDLED})
option(USE_BUNDLED_UTF8PROC "Use the bundled utf8proc library." ${USE_BUNDLED})
if(USE_BUNDLED AND MSVC)
  option(USE_BUNDLED_GETTEXT "Use the bundled version of gettext." ON)
  option(USE_BUNDLED_LIBICONV "Use the bundled version of libiconv." ON)
else()
  option(USE_BUNDLED_GETTEXT "Use the bundled version of gettext." OFF)
  option(USE_BUNDLED_LIBICONV "Use the bundled version of libiconv." OFF)
endif()

option(USE_EXISTING_SRC_DIR "Skip download of deps sources in case of existing source directory." OFF)

set_default_buildtype(Release)
get_property(isMultiConfig GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT isMultiConfig)
  list(APPEND DEPS_CMAKE_ARGS -D CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE})
endif()

set(DEFAULT_MAKE_CFLAGS CFLAGS+=-g)

check_c_compiler_flag(-Og HAS_OG_FLAG)
if(HAS_OG_FLAG)
  set(DEFAULT_MAKE_CFLAGS CFLAGS+=-Og ${DEFAULT_MAKE_CFLAGS})
endif()

set(DEPS_INCLUDE_FLAGS "-I${DEPS_INSTALL_DIR}/include -I${DEPS_INSTALL_DIR}/include/luajit-2.1")

# If the macOS deployment target is not set manually (via $MACOSX_DEPLOYMENT_TARGET),
# fall back to local system version. Needs to be done here and in top-level CMakeLists.txt.
if(APPLE)
  if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    execute_process(COMMAND sw_vers -productVersion
                    OUTPUT_VARIABLE MACOS_VERSION
                    OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "${MACOS_VERSION}")
  endif()
  message(STATUS "Using deployment target ${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()

if(USE_BUNDLED_LUAJIT)
  set(LUA_ENGINE LuaJit)
elseif(USE_BUNDLED_LUA)
  set(LUA_ENGINE Lua)
else()
  find_package(Luajit)
  find_package(Lua 5.1 EXACT)
  if(LUAJIT_FOUND)
    set(LUA_ENGINE LuaJit)
    string(APPEND DEPS_INCLUDE_FLAGS " -I${LUAJIT_INCLUDE_DIR}")
  elseif(LUA_FOUND)
    set(LUA_ENGINE Lua)
    string(APPEND DEPS_INCLUDE_FLAGS " -I${LUA_INCLUDE_DIR}")
  else()
    message(FATAL_ERROR "Could not find system lua or luajit")
  endif()
endif()

if(USE_BUNDLED_UNIBILIUM)
  include(BuildUnibilium)
endif()

if(USE_BUNDLED_LIBUV)
  include(BuildLibuv)
endif()

if(USE_BUNDLED_LUAJIT)
  include(BuildLuajit)
endif()

if(USE_BUNDLED_LUA)
  include(BuildLua)
endif()

if(USE_BUNDLED_LUV)
  include(BuildLuv)
endif()

if(USE_BUNDLED_LPEG)
  include(BuildLpeg)
endif()

if(USE_BUNDLED_GETTEXT)
  include(BuildGettext)
endif()

if(USE_BUNDLED_LIBICONV)
  include(BuildLibiconv)
endif()

if(USE_BUNDLED_TS_PARSERS)
  include(BuildTreesitterParsers)
endif()

if(USE_BUNDLED_TS)
  include(BuildTreesitter)
endif()

if(USE_BUNDLED_UTF8PROC)
  include(BuildUTF8proc)
endif()

if(WIN32)
  include(GetBinaryDeps)

  GetExecutable(TARGET cat)
  GetExecutable(TARGET tee)
  GetExecutable(TARGET xxd)

  GetBinaryDep(TARGET win32yank_X86_64
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy win32yank.exe ${DEPS_BIN_DIR})
endif()
