# This is not meant to be included by the top-level.
cmake_minimum_required (VERSION 2.8.12)
project(NVIM_DEPS C)

# Needed for: check_c_compiler_flag()
include(CheckCCompilerFlag)

# Point CMake at any custom modules we may ship
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake" "${PROJECT_SOURCE_DIR}/../cmake")

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
option(USE_BUNDLED_TS_PARSERS "Use the bundled treesitter parsers." ${USE_BUNDLED})
option(USE_BUNDLED_TS "Use the bundled treesitter runtime." ${USE_BUNDLED})

if(USE_BUNDLED AND MSVC)
  option(USE_BUNDLED_GETTEXT "Use the bundled version of gettext." ON)
  option(USE_BUNDLED_LIBICONV "Use the bundled version of libiconv." ON)
else()
  option(USE_BUNDLED_GETTEXT "Use the bundled version of gettext." OFF)
  option(USE_BUNDLED_LIBICONV "Use the bundled version of libiconv." OFF)
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

if(MINGW AND CMAKE_GENERATOR MATCHES "Ninja")
  find_program(MAKE_PRG NAMES mingw32-make)
  if(NOT MAKE_PRG)
    message(FATAL_ERROR "GNU Make for mingw32 is required to build the dependecies.")
  else()
    message(STATUS "Found GNU Make for mingw32: ${MAKE_PRG}")
  endif()
endif()

if(CMAKE_C_COMPILER_ARG1)
  set(DEPS_C_COMPILER "${CMAKE_C_COMPILER} ${CMAKE_C_COMPILER_ARG1}")
else()
  set(DEPS_C_COMPILER "${CMAKE_C_COMPILER}")
endif()

if(USE_BUNDLED_GPERF)
  enable_language(CXX)
endif()

if(CMAKE_CXX_COMPILER)
  set(DEPS_CXX_COMPILER "${CMAKE_CXX_COMPILER}")
endif()

if(CMAKE_OSX_SYSROOT)
  set(DEPS_C_COMPILER "${DEPS_C_COMPILER} -isysroot${CMAKE_OSX_SYSROOT}")
  if(DEPS_CXX_COMPILER)
    set(DEPS_CXX_COMPILER "${DEPS_CXX_COMPILER} -isysroot${CMAKE_OSX_SYSROOT}")
  endif()
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
  set(HOSTDEPS_CXX_COMPILER "${HOST_CXX_COMPILER}")
else()
  set(HOSTDEPS_INSTALL_DIR "${DEPS_INSTALL_DIR}")
  set(HOSTDEPS_BIN_DIR "${DEPS_BIN_DIR}")
  set(HOSTDEPS_LIB_DIR "${DEPS_LIB_DIR}")
  set(HOSTDEPS_C_COMPILER "${DEPS_C_COMPILER}")
  set(HOSTDEPS_CXX_COMPILER "${DEPS_CXX_COMPILER}")
endif()

include(ExternalProject)

if(WIN32)
  # "nvim" branch of https://github.com/neovim/libuv
  set(LIBUV_URL https://github.com/neovim/libuv/archive/b899d12b0d56d217f31222da83f8c398355b69ef.tar.gz)
  set(LIBUV_SHA256 eb7e37b824887e1b31a4e31d1d9bad4c03d8b98532d9cce5f67a3b70495a4b2a)
else()
  set(LIBUV_URL https://github.com/libuv/libuv/archive/v1.34.2.tar.gz)
  set(LIBUV_SHA256 0d9d38558b45c006c1ea4e8529bae64caf8becda570295ea74e3696362aeb7f2)
endif()

set(MSGPACK_URL https://github.com/msgpack/msgpack-c/releases/download/cpp-3.0.0/msgpack-3.0.0.tar.gz)
set(MSGPACK_SHA256 bfbb71b7c02f806393bc3cbc491b40523b89e64f83860c58e3e54af47de176e4)

# https://github.com/LuaJIT/LuaJIT/tree/v2.1
set(LUAJIT_URL https://github.com/LuaJIT/LuaJIT/archive/787736990ac3b7d5ceaba2697c7d0f58f77bb782.tar.gz)
set(LUAJIT_SHA256 2e3f74bc279f46cc463abfc67b36e69faaf0366237004771f4cac4bf2a9f5efb)

set(LUA_URL https://www.lua.org/ftp/lua-5.1.5.tar.gz)
set(LUA_SHA256 2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333)

set(LUAROCKS_URL https://github.com/luarocks/luarocks/archive/v3.2.1.tar.gz)
set(LUAROCKS_SHA256 0cab9f79311083f33e4d8f5a76021604f1d3f7141ce9a2ef1d8b717d92058370)

set(UNIBILIUM_URL https://github.com/neovim/unibilium/archive/92d929f.tar.gz)
set(UNIBILIUM_SHA256 29815283c654277ef77a3adcc8840db79ddbb20a0f0b0c8f648bd8cd49a02e4b)

set(LIBTERMKEY_URL http://www.leonerd.org.uk/code/libtermkey/libtermkey-0.22.tar.gz)
set(LIBTERMKEY_SHA256 6945bd3c4aaa83da83d80a045c5563da4edd7d0374c62c0d35aec09eb3014600)

set(LIBVTERM_URL http://www.leonerd.org.uk/code/libvterm/libvterm-0.1.4.tar.gz)
set(LIBVTERM_SHA256 bc70349e95559c667672fc8c55b9527d9db9ada0fb80a3beda533418d782d3dd)

set(LUV_VERSION 1.30.1-1)
set(LUV_URL https://github.com/luvit/luv/archive/${LUV_VERSION}.tar.gz)
set(LUV_SHA256 2b17921e2e18094df6221e3cd291c82d4569e50d8c081518d3e775dceae267cf)

set(LUA_COMPAT53_URL https://github.com/keplerproject/lua-compat-5.3/archive/v0.7.tar.gz)
set(LUA_COMPAT53_SHA256 bec3a23114a3d9b3218038309657f0f506ad10dfbc03bb54e91da7e5ffdba0a2)

set(GPERF_URL https://github.com/neovim/deps/raw/ff5b4b18a87397a8564016071ae64f64bcd8c635/opt/gperf-3.1.tar.gz)
set(GPERF_SHA256 588546b945bba4b70b6a3a616e80b4ab466e3f33024a352fc2198112cdbb3ae2)

# 7za.exe cat.exe curl.exe ca-bundle.crt diff.exe tee.exe tidy.exe xxd.exe
set(WINTOOLS_URL https://github.com/neovim/deps/raw/2f9acbecf06365c10baa3c0087f34a54c9c6f949/opt/win32tools.zip)
set(WINTOOLS_SHA256 8bfce7e3a365721a027ce842f2ec1cf878f1726233c215c05964aac07300798c)

set(WINGUI_URL https://github.com/equalsraf/neovim-qt/releases/download/v0.2.16/neovim-qt.zip)
set(WINGUI_SHA256 aad95a1f8413a9ebf36fc0298d0dfd7d786abf88cb0f4ae9f7ec895b70c7b312)

set(WIN32YANK_X86_URL https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x86.zip)
set(WIN32YANK_X86_SHA256 62f34e5a46c5d4a7b3f3b512e1ff7b77fedd432f42581cbe825233a996eed62c)
set(WIN32YANK_X86_64_URL https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip)
set(WIN32YANK_X86_64_SHA256 33a747a92da60fb65e668edbf7661d3d902411a2d545fe9dc08623cecd142a20)

set(WINPTY_URL https://github.com/rprichard/winpty/releases/download/0.4.3/winpty-0.4.3-msvc2015.zip)
set(WINPTY_SHA256 35a48ece2ff4acdcbc8299d4920de53eb86b1fb41e64d2fe5ae7898931bcee89)

set(GETTEXT_URL https://ftp.gnu.org/pub/gnu/gettext/gettext-0.20.1.tar.gz)
set(GETTEXT_SHA256 66415634c6e8c3fa8b71362879ec7575e27da43da562c798a8a2f223e6e47f5c)

set(LIBICONV_URL https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.15.tar.gz)
set(LIBICONV_SHA256 ccf536620a45458d26ba83887a983b96827001e92a13847b45e4925cc8913178)

set(TREESITTER_C_URL https://github.com/tree-sitter/tree-sitter-c/archive/99151b1.tar.gz)
set(TREESITTER_C_SHA256 950386f9ba77fb6a7e992198d4f219c34238a2bbc005c5f53c4212d0f8772b06)

set(TREESITTER_URL https://github.com/tree-sitter/tree-sitter/archive/0.18.0.zip)
set(TREESITTER_SHA256 ac53b7708ca47161dac7f8e852bd61accb8527d45b7ad72e29e12e8e72dbe440)

if(USE_BUNDLED_UNIBILIUM)
  include(BuildUnibilium)
endif()

if(USE_BUNDLED_LIBTERMKEY)
  include(BuildLibtermkey)
  if(USE_BUNDLED_UNIBILIUM)
    add_dependencies(libtermkey unibilium)
  endif()
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

if(USE_BUNDLED_LUV)
  include(BuildLuv)
endif()

if(USE_BUNDLED_GPERF)
  include(BuildGperf)
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

if(WIN32)
  include(GetBinaryDeps)

  GetBinaryDep(TARGET wintools
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_directory . ${DEPS_INSTALL_DIR}/bin)

  GetBinaryDep(TARGET wingui
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_directory bin ${DEPS_INSTALL_DIR}/bin
      COMMAND ${CMAKE_COMMAND} -E copy_directory share ${DEPS_INSTALL_DIR}/share)

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

# clean-shared-libraries removes ${DEPS_INSTALL_DIR}/lib/nvim/parser/c.dll,
# resulting in MSVC build failure in CI.
if (MSVC)
  set(ALL_DEPS ${THIRD_PARTY_DEPS})
else()
  add_custom_target(clean-shared-libraries
    COMMAND ${CMAKE_COMMAND}
      -DREMOVE_FILE_GLOB=${DEPS_INSTALL_DIR}/lib/${CMAKE_SHARED_LIBRARY_PREFIX}*${CMAKE_SHARED_LIBRARY_SUFFIX}*
      -P ${PROJECT_SOURCE_DIR}/cmake/RemoveFiles.cmake
    DEPENDS ${THIRD_PARTY_DEPS}
  )
  set(ALL_DEPS clean-shared-libraries)
endif()

add_custom_target(third-party ALL
  COMMAND ${CMAKE_COMMAND} -E touch .third-party
  DEPENDS ${ALL_DEPS}
)
