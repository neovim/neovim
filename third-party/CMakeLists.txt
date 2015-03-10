# This is not meant to be included by the top-level.
cmake_minimum_required (VERSION 2.8.7)
project(NEOVIM_DEPS)
 
# Point CMake at any custom modules we may ship
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

set(DEPS_INSTALL_DIR "${CMAKE_BINARY_DIR}/usr")
set(DEPS_BIN_DIR "${CMAKE_BINARY_DIR}/usr/bin")
set(DEPS_LIB_DIR "${CMAKE_BINARY_DIR}/usr/lib")
set(DEPS_BUILD_DIR "${CMAKE_BINARY_DIR}/build")
set(DEPS_DOWNLOAD_DIR "${DEPS_BUILD_DIR}/downloads")

option(USE_BUNDLED "Use bundled dependencies." ON)

option(USE_BUNDLED_UNIBILIUM "Use the bundled unibilium." ${USE_BUNDLED})
option(USE_BUNDLED_LIBTERMKEY "Use the bundled libtermkey." ${USE_BUNDLED})
option(USE_BUNDLED_LIBVTERM "Use the bundled libvterm." ${USE_BUNDLED})
option(USE_BUNDLED_LIBUV "Use the bundled libuv." ${USE_BUNDLED})
option(USE_BUNDLED_MSGPACK "Use the bundled msgpack." ${USE_BUNDLED})
option(USE_BUNDLED_LUAJIT "Use the bundled version of luajit." ${USE_BUNDLED})
option(USE_BUNDLED_LUAROCKS "Use the bundled version of luarocks." ${USE_BUNDLED})

# TODO: add windows support

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

include(ExternalProject)

set(LIBUV_URL https://github.com/libuv/libuv/archive/v1.2.0.tar.gz)
set(LIBUV_SHA256 bebf424bb239867bbf609abad09a256cae7808c9d5cb346b779acd4b97a56693)

set(MSGPACK_URL https://github.com/msgpack/msgpack-c/archive/f6d0cd9a4ba46f4341014a199e3d352fad76b215.tar.gz)
set(MSGPACK_SHA256 988bb2bf86bb0f69816cbcbe2218285b94dbaa27e839f8b1ffdb0b934a7d726a)

set(LUAJIT_URL http://luajit.org/download/LuaJIT-2.0.3.tar.gz)
set(LUAJIT_SHA256 55be6cb2d101ed38acca32c5b1f99ae345904b365b642203194c585d27bebd79)

set(LUAROCKS_URL https://github.com/keplerproject/luarocks/archive/0587afbb5fe8ceb2f2eea16f486bd6183bf02f29.tar.gz)
set(LUAROCKS_SHA256 c8ad50938fed66beba74a73621d14121d4a40b796e01c45238de4cdcb47d5e0b)

set(UNIBILIUM_URL https://github.com/mauke/unibilium/archive/bb979ff6f66a18663e15d086dec6276561b86ee0.tar.gz)
set(UNIBILIUM_SHA256 bec06ea90128b46f28b91b8b52b861dede5f4ede0a92f05178b3c7bcec237dd1)

set(LIBTERMKEY_URL https://github.com/neovim/libtermkey/archive/8c0cb7108cc63218ea19aa898968eede19e19603.tar.gz)
set(LIBTERMKEY_SHA256 21846369081e6c9a0b615f4b3889c4cb809321c5ccc6e6c1640eb138f1590072)

set(LIBVTERM_URL https://github.com/neovim/libvterm/archive/1b745d29d45623aa8d22a7b9288c7b0e331c7088.tar.gz)
set(LIBVTERM_SHA256 3fc75908256c0d158d6c2a32d39f34e86bfd26364f5404b7d9c03bb70cdc3611)


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

if(USE_BUNDLED_LUAROCKS)
  include(BuildLuarocks)
endif()

add_custom_target(third-party ALL
  COMMAND ${CMAKE_COMMAND} -E touch .third-party
  DEPENDS ${THIRD_PARTY_DEPS})
