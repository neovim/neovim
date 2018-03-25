# This is not meant to be included by the top-level.
cmake_minimum_required (VERSION 2.8.7)
project(NVIM_DEPS)

# Needed for: check_c_compiler_flag()
include(CheckCCompilerFlag)

# Point CMake at any custom modules we may ship
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

# In Windows/MSVC CMAKE_BUILD_TYPE changes the paths/linking of the build
# recipes (libuv, msgpack), make sure it is set
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(DEFAULT_MAKE_CFLAGS CFLAGS+=-g)

check_c_compiler_flag(-Og HAS_OG_FLAG)
if(HAS_OG_FLAG)
  set(DEFAULT_MAKE_CFLAGS CFLAGS+=-Og ${DEFAULT_MAKE_CFLAGS})
endif()

set(DEPS_INSTALL_DIR "${CMAKE_BINARY_DIR}/usr" CACHE PATH "Dependencies install directory.")
set(DEPS_BIN_DIR "${DEPS_INSTALL_DIR}/bin" CACHE PATH "Dependencies binary install directory.")
set(DEPS_LIB_DIR "${DEPS_INSTALL_DIR}/lib" CACHE PATH "Dependencies library install directory.")
set(DEPS_BUILD_DIR "${CMAKE_BINARY_DIR}/build" CACHE PATH "Dependencies build directory.")
set(DEPS_DOWNLOAD_DIR "${DEPS_BUILD_DIR}/downloads" CACHE PATH "Dependencies download directory.")

option(USE_BUNDLED "Use bundled dependencies." ON)

option(USE_BUNDLED_GPERF "Use the bundled version of gperf." ${USE_BUNDLED})
option(USE_BUNDLED_JEMALLOC "Use the bundled jemalloc." ${USE_BUNDLED})
option(USE_BUNDLED_UNIBILIUM "Use the bundled unibilium." ${USE_BUNDLED})
option(USE_BUNDLED_LIBTERMKEY "Use the bundled libtermkey." ${USE_BUNDLED})
option(USE_BUNDLED_LIBVTERM "Use the bundled libvterm." ${USE_BUNDLED})
option(USE_BUNDLED_LIBUV "Use the bundled libuv." ${USE_BUNDLED})
option(USE_BUNDLED_MSGPACK "Use the bundled msgpack." ${USE_BUNDLED})
option(USE_BUNDLED_LUAJIT "Use the bundled version of luajit." ${USE_BUNDLED})
option(USE_BUNDLED_LUAROCKS "Use the bundled version of luarocks." ${USE_BUNDLED})
option(USE_BUNDLED_LUV "Use the bundled version of luv." ${USE_BUNDLED})
#XXX(tarruda): Lua is only used for debugging the functional test client, no
# build it unless explicitly requested
option(USE_BUNDLED_LUA "Use the bundled version of lua." OFF)

if(USE_BUNDLED AND MSVC)
  option(USE_BUNDLED_GETTEXT "Use the bundled version of gettext." ON)
else()
  option(USE_BUNDLED_GETTEXT "Use the bundled version of gettext." OFF)
endif()

option(USE_EXISTING_SRC_DIR "Skip download of deps sources in case of existing source directory." OFF)

if(WIN32)
  find_package(Git)
  if(NOT Git_FOUND)
    message(FATAL_ERROR "Git is required to apply patches for Windows.")
  endif()
endif()

if(UNIX)
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
endif()

# When using make, use the $(MAKE) variable to avoid warning about the job
# server.
if(CMAKE_GENERATOR MATCHES "Makefiles")
  set(MAKE_PRG "$(MAKE)")
endif()

if(CMAKE_C_COMPILER_ARG1)
  set(DEPS_C_COMPILER "${CMAKE_C_COMPILER} ${CMAKE_C_COMPILER_ARG1}")
else()
  set(DEPS_C_COMPILER "${CMAKE_C_COMPILER}")
endif()

# Cross compiling: use these for dependencies built for the
# HOST system, when not crosscompiling these should be the
# same as DEPS_*. Except when targeting Unix in which case
# want all the dependencies to use the same compiler.
if(CMAKE_CROSSCOMPILING AND NOT UNIX)
  set(HOSTDEPS_INSTALL_DIR "${CMAKE_BINARY_DIR}/host")
  set(HOSTDEPS_BIN_DIR "${HOSTDEPS_INSTALL_DIR}/bin")
  set(HOSTDEPS_LIB_DIR "${HOSTDEPS_INSTALL_DIR}/lib")
  set(HOSTDEPS_C_COMPILER "${HOST_C_COMPILER}")
else()
  set(HOSTDEPS_INSTALL_DIR "${DEPS_INSTALL_DIR}")
  set(HOSTDEPS_BIN_DIR "${DEPS_BIN_DIR}")
  set(HOSTDEPS_LIB_DIR "${DEPS_LIB_DIR}")
  set(HOSTDEPS_C_COMPILER "${DEPS_C_COMPILER}")
endif()

include(ExternalProject)

set(LIBUV_URL https://github.com/libuv/libuv/archive/v1.12.0.tar.gz)
set(LIBUV_SHA256 41ce914a88da21d3b07a76023beca57576ca5b376c6ac440c80bc581cbca1250)

set(MSGPACK_URL https://github.com/msgpack/msgpack-c/releases/download/cpp-2.1.5/msgpack-2.1.5.tar.gz)
set(MSGPACK_SHA256 6126375af9b204611b9d9f154929f4f747e4599e6ae8443b337915dcf2899d2b)

set(LUAJIT_URL https://github.com/LuaJIT/LuaJIT/archive/7dbf0b05f1228c1c719866db5e5f3d58f87f74c8.tar.gz)
set(LUAJIT_SHA256 cbae019b5e396164eb5f0d07777b55cc03931bb944f83c61a010c053c9f5fd5b)

set(LUA_URL https://www.lua.org/ftp/lua-5.1.5.tar.gz)
set(LUA_SHA256 2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333)

# NOTE: Version must match LUAROCKS_VERSION in third-party/cmake/BuildLuarocks.cmake
set(LUAROCKS_URL https://github.com/luarocks/luarocks/archive/v2.4.3.tar.gz)
set(LUAROCKS_SHA256 ea1881d6954f2a98c34f93674571c8f0cbdbc28dedb3fa3cb56b6a91886d1a99)

set(UNIBILIUM_URL https://github.com/mauke/unibilium/archive/v2.0.0.tar.gz)
set(UNIBILIUM_SHA256 78997d38d4c8177c60d3d0c1aa8c53fd0806eb21825b7b335b1768d7116bc1c1)

if(WIN32)
set(LIBTERMKEY_URL https://github.com/equalsraf/libtermkey/archive/tb-windows.zip)
set(LIBTERMKEY_SHA256 c81e33e38662b151a49847ff4feef4f8c4b2a66f3e159a28b575cbc9bcd8ffea)
else()
set(LIBTERMKEY_URL http://www.leonerd.org.uk/code/libtermkey/libtermkey-0.20.tar.gz)
set(LIBTERMKEY_SHA256 6c0d87c94ab9915e76ecd313baec08dedf3bd56de83743d9aa923a081935d2f5)
endif()

set(LIBVTERM_URL https://github.com/neovim/libvterm/archive/a9c7c6fd20fa35e0ad3e0e98901ca12dfca9c25c.tar.gz)
set(LIBVTERM_SHA256 1a4272be91d9614dc183a503786df83b6584e4afaab7feaaa5409f841afbd796)

set(JEMALLOC_URL https://github.com/jemalloc/jemalloc/releases/download/4.5.0/jemalloc-4.5.0.tar.bz2)
set(JEMALLOC_SHA256 9409d85664b4f135b77518b0b118c549009dc10f6cba14557d170476611f6780)

set(LUV_URL https://github.com/luvit/luv/archive/1.9.1-1.tar.gz)
set(LUV_SHA256 562b9efaad30aa051a40eac9ade0c3df48bb8186763769abe47ec3fb3edb1268)

set(GPERF_URL https://ftp.gnu.org/pub/gnu/gperf/gperf-3.1.tar.gz)
set(GPERF_SHA256 588546b945bba4b70b6a3a616e80b4ab466e3f33024a352fc2198112cdbb3ae2)

# 7za.exe cat.exe curl.exe ca-bundle.crt diff.exe tee.exe tidy.exe xxd.exe
set(WINTOOLS_URL https://github.com/neovim/deps/raw/2f9acbecf06365c10baa3c0087f34a54c9c6f949/opt/win32tools.zip)
set(WINTOOLS_SHA256 8bfce7e3a365721a027ce842f2ec1cf878f1726233c215c05964aac07300798c)

set(WINGUI_URL https://github.com/equalsraf/neovim-qt/releases/download/v0.2.8/neovim-qt.zip)
set(WINGUI_SHA256 260efc686423e2529360b6a45c8e241fbbf276c8de6b04d44f45ab5b6fe8df8f)

set(WIN32YANK_X86_URL https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x86.zip)
set(WIN32YANK_X86_SHA256 62f34e5a46c5d4a7b3f3b512e1ff7b77fedd432f42581cbe825233a996eed62c)

set(WIN32YANK_X86_64_URL https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip)
set(WIN32YANK_X86_64_SHA256 33a747a92da60fb65e668edbf7661d3d902411a2d545fe9dc08623cecd142a20)

set(WINPTY_URL https://github.com/rprichard/winpty/releases/download/0.4.3/winpty-0.4.3-msvc2015.zip)
set(WINPTY_SHA256 35a48ece2ff4acdcbc8299d4920de53eb86b1fb41e64d2fe5ae7898931bcee89)

set(GETTEXT_URL https://ftp.gnu.org/pub/gnu/gettext/gettext-0.19.8.1.tar.gz)
set(GETTEXT_SHA256 ff942af0e438ced4a8b0ea4b0b6e0d6d657157c5e2364de57baa279c1c125c43)

if(USE_BUNDLED_UNIBILIUM)
  include(BuildUnibilium)
endif()

if(USE_BUNDLED_LIBTERMKEY)
  include(BuildLibtermkey)
endif()

if(USE_BUNDLED_LIBVTERM)
  include(BuildLibvterm)
endif()

if(USE_BUNDLED_LIBUV)
  include(BuildLibuv)
endif()

if(USE_BUNDLED_MSGPACK)
  include(BuildMsgpack)
endif()

if(USE_BUNDLED_LUAJIT)
  include(BuildLuajit)
endif()

if(USE_BUNDLED_LUA AND NOT CMAKE_CROSSCOMPILING)
  include(BuildLua)
endif()

if(USE_BUNDLED_LUAROCKS)
  include(BuildLuarocks)
endif()

if(USE_BUNDLED_JEMALLOC)
  include(BuildJeMalloc)
endif()

if(USE_BUNDLED_LUV)
  include(BuildLuv)
endif()

if(USE_BUNDLED_GPERF)
  include(BuildGperf)
endif()

if(USE_BUNDLED_GETTEXT)
  include(BuildGettext)
endif()

include(GetBinaryDeps)

if(WIN32)
  GetBinaryDep(TARGET wintools
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_directory . ${DEPS_INSTALL_DIR}/bin)

  GetBinaryDep(TARGET wingui
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_directory bin ${DEPS_INSTALL_DIR}/bin)

  include(TargetArch)
  GetBinaryDep(TARGET "win32yank_${TARGET_ARCH}"
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy win32yank.exe ${DEPS_INSTALL_DIR}/bin)

  if("${TARGET_ARCH}" STREQUAL "X86_64")
    set(TARGET_ARCH x64)
  elseif(TARGET_ARCH STREQUAL "X86")
    set(TARGET_ARCH ia32)
  endif()

  GetBinaryDep(TARGET winpty
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/bin
      COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/winpty/${TARGET_ARCH}/bin/*
        -DTO=${DEPS_INSTALL_DIR}/bin/
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake
      COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/winpty/include/*
        -DTO=${DEPS_INSTALL_DIR}/include/
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake
      COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/winpty/${TARGET_ARCH}/lib/*
        -DTO=${DEPS_INSTALL_DIR}/lib/
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake)
endif()

add_custom_target(clean-shared-libraries
  COMMAND ${CMAKE_COMMAND}
    -DREMOVE_FILE_GLOB=${DEPS_INSTALL_DIR}/lib/${CMAKE_SHARED_LIBRARY_PREFIX}*${CMAKE_SHARED_LIBRARY_SUFFIX}*
    -P ${PROJECT_SOURCE_DIR}/cmake/RemoveFiles.cmake
  DEPENDS ${THIRD_PARTY_DEPS}
)

add_custom_target(third-party ALL
  COMMAND ${CMAKE_COMMAND} -E touch .third-party
  DEPENDS clean-shared-libraries)
