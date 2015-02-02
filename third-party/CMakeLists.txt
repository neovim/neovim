# This is not meant to be included by the top-level.
cmake_minimum_required (VERSION 2.8.7)
project(NEOVIM_DEPS)

set(DEPS_INSTALL_DIR "${CMAKE_BINARY_DIR}/usr")
set(DEPS_BIN_DIR "${CMAKE_BINARY_DIR}/usr/bin")
set(DEPS_LIB_DIR "${CMAKE_BINARY_DIR}/usr/lib")
set(DEPS_BUILD_DIR "${CMAKE_BINARY_DIR}/build")
set(DEPS_DOWNLOAD_DIR "${DEPS_BUILD_DIR}/downloads")

option(USE_BUNDLED "Use bundled dependencies." ON)

option(USE_BUNDLED_LIBUNIBILIUM "Use the bundled libunibilium." ${USE_BUNDLED})
option(USE_BUNDLED_LIBTERMKEY "Use the bundled libtermkey." ${USE_BUNDLED})
option(USE_BUNDLED_LIBTICKIT "Use the bundled libtickit." ${USE_BUNDLED})
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
set(LIBUV_SHA1 38d1ba349fcfc1b221140523ba3d7cf3ea38c20b)
set(LIBUV_MD5 e7712a100635ec2ca1f145f2bb217200)

set(MSGPACK_URL https://github.com/msgpack/msgpack-c/archive/ecf4b09acd29746829b6a02939db91dfdec635b4.tar.gz)
set(MSGPACK_SHA1 c160ff99f20d9d0a25bea0a57f4452f1c9bde370)
set(MSGPACK_MD5 3599eaf904b8ba0c36cea7ed80973364)

set(LUAJIT_URL http://luajit.org/download/LuaJIT-2.0.3.tar.gz)
set(LUAJIT_SHA1 2db39e7d1264918c2266b0436c313fbd12da4ceb)
set(LUAJIT_MD5 f14e9104be513913810cd59c8c658dc0)

set(LUAROCKS_URL https://github.com/keplerproject/luarocks/archive/0587afbb5fe8ceb2f2eea16f486bd6183bf02f29.tar.gz)
set(LUAROCKS_SHA1 61a894fd5d61987bf7e7f9c3e0c5de16ba4b68c4)
set(LUAROCKS_MD5 0f53f42909fbcd2c88be303e8f970516)

set(LIBUNIBILIUM_URL https://github.com/mauke/unibilium/archive/520abbc8b26910e2580619f669b5cc2c4ef7f864.tar.gz)
set(LIBUNIBILIUM_SHA1 c546e5e8861380f5c109a256f25c93419e4076bf)
set(LIBUNIBILIUM_MD5 d80d1fc45b22b1e92bebd5bf76e8a98b)

set(LIBTERMKEY_URL https://github.com/neovim/libtermkey/archive/7b3bdafdf589d08478f2493273d4d75636ecc183.tar.gz)
set(LIBTERMKEY_SHA1 28bfe54dfd9269910a132b51dee7725a2121578d)
set(LIBTERMKEY_MD5 f0bac9c2467cc80c821be937ea5c13bc)

set(LIBTICKIT_URL https://github.com/neovim/libtickit/archive/33f4afb3891df05955429acbf5b406dfe87ec22b.tar.gz)
set(LIBTICKIT_SHA1 3aab459b9fb3cd83e85ac2e08f05e5f162c8c9d2)
set(LIBTICKIT_MD5 19ee9271c16716620d0906db74158ec6)

if(USE_BUNDLED_LIBUNIBILIUM)
  ExternalProject_Add(libunibilium
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LIBUNIBILIUM_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libunibilium
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libunibilium
      -DURL=${LIBUNIBILIUM_URL}
      -DEXPECTED_SHA1=${LIBUNIBILIUM_SHA1}
      -DEXPECTED_MD5=${LIBUNIBILIUM_MD5}
      -DTARGET=libunibilium
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    BUILD_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                              PREFIX=${DEPS_INSTALL_DIR}
                              CFLAGS=-fPIC
    INSTALL_COMMAND ${MAKE_PRG} PREFIX=${DEPS_INSTALL_DIR} install)
  list(APPEND THIRD_PARTY_DEPS libunibilium)
endif()

if(USE_BUNDLED_LIBTERMKEY)
  ExternalProject_Add(libtermkey
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LIBTERMKEY_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libtermkey
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libtermkey
      -DURL=${LIBTERMKEY_URL}
      -DEXPECTED_SHA1=${LIBTERMKEY_SHA1}
      -DEXPECTED_MD5=${LIBTERMKEY_MD5}
      -DTARGET=libtermkey
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    BUILD_COMMAND ""
    INSTALL_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                                PREFIX=${DEPS_INSTALL_DIR}
                                PKG_CONFIG_PATH=${DEPS_LIB_DIR}/pkgconfig
                                CFLAGS=-fPIC
                                install)
  list(APPEND THIRD_PARTY_DEPS libtermkey)
  add_dependencies(libtermkey libunibilium)
endif()

if(USE_BUNDLED_LIBTICKIT)
  ExternalProject_Add(libtickit
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LIBTICKIT_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libtickit
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libtickit
      -DURL=${LIBTICKIT_URL}
      -DEXPECTED_SHA1=${LIBTICKIT_SHA1}
      -DEXPECTED_MD5=${LIBTICKIT_MD5}
      -DTARGET=libtickit
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    BUILD_COMMAND ""
    INSTALL_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                                PREFIX=${DEPS_INSTALL_DIR}
                                PKG_CONFIG_PATH=${DEPS_LIB_DIR}/pkgconfig
                                CFLAGS=-fPIC
                                install)
  list(APPEND THIRD_PARTY_DEPS libtickit)
  add_dependencies(libtickit libtermkey)
endif()

if(USE_BUNDLED_LIBUV)
  ExternalProject_Add(libuv
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LIBUV_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libuv
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libuv
      -DURL=${LIBUV_URL}
      -DEXPECTED_SHA1=${LIBUV_SHA1}
      -DEXPECTED_MD5=${LIBUV_MD5}
      -DTARGET=libuv
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND sh ${DEPS_BUILD_DIR}/src/libuv/autogen.sh &&
      ${DEPS_BUILD_DIR}/src/libuv/configure --with-pic --disable-shared
        --prefix=${DEPS_INSTALL_DIR} CC=${DEPS_C_COMPILER}
    INSTALL_COMMAND ${MAKE_PRG} install)
  list(APPEND THIRD_PARTY_DEPS libuv)
endif()

if(USE_BUNDLED_MSGPACK)
  ExternalProject_Add(msgpack
    PREFIX ${DEPS_BUILD_DIR}
    URL ${MSGPACK_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/msgpack
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/msgpack
      -DURL=${MSGPACK_URL}
      -DEXPECTED_SHA1=${MSGPACK_SHA1}
      -DEXPECTED_MD5=${MSGPACK_MD5}
      -DTARGET=msgpack
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND cmake ${DEPS_BUILD_DIR}/src/msgpack
       -DMSGPACK_ENABLE_CXX=OFF
       -DMSGPACK_BUILD_TESTS=OFF
       -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
       -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
       "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1} -fPIC"
    BUILD_COMMAND ${CMAKE_COMMAND} --build .
    INSTALL_COMMAND ${CMAKE_COMMAND}
      -DREMOVE_FILE_GLOB=${DEPS_INSTALL_DIR}/lib/${CMAKE_SHARED_LIBRARY_PREFIX}msgpack*${CMAKE_SHARED_LIBRARY_SUFFIX}*
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/InstallMsgpack.cmake)
  list(APPEND THIRD_PARTY_DEPS msgpack)
endif()

if(USE_BUNDLED_LUAJIT)
  ExternalProject_Add(luajit
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LUAJIT_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luajit
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/luajit
      -DURL=${LUAJIT_URL}
      -DEXPECTED_SHA1=${LUAJIT_SHA1}
      -DEXPECTED_MD5=${LUAJIT_MD5}
      -DTARGET=luajit
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    BUILD_COMMAND ""
    INSTALL_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                                PREFIX=${DEPS_INSTALL_DIR}
                                CFLAGS=-fPIC
                                BUILDMODE=static
                                install)
  list(APPEND THIRD_PARTY_DEPS luajit)
endif()

if(USE_BUNDLED_LUAROCKS)
  if(USE_BUNDLED_LUAJIT)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${DEPS_INSTALL_DIR}
      --with-lua-include=${DEPS_INSTALL_DIR}/include/luajit-2.0)
  endif()
  ExternalProject_Add(luarocks
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LUAROCKS_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luarocks
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/luarocks
      -DURL=${LUAROCKS_URL}
      -DEXPECTED_SHA1=${LUAROCKS_SHA1}
      -DEXPECTED_MD5=${LUAROCKS_MD5}
      -DTARGET=luarocks
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND ${DEPS_BUILD_DIR}/src/luarocks/configure
      --prefix=${DEPS_INSTALL_DIR} --force-config ${LUAROCKS_OPTS}
      --lua-suffix=jit
    BUILD_COMMAND ""
    INSTALL_COMMAND ${MAKE_PRG} bootstrap)
  list(APPEND THIRD_PARTY_DEPS luarocks)
  if(USE_BUNDLED_LUAJIT)
    add_dependencies(luarocks luajit)
  endif()

  add_custom_command(OUTPUT ${DEPS_BIN_DIR}/busted
    COMMAND ${DEPS_BIN_DIR}/luarocks
    ARGS build busted 2.0.rc4 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
    DEPENDS luarocks)
  add_custom_target(busted
    DEPENDS ${DEPS_BIN_DIR}/busted)

  # lua-messagepack doesn't depend on busted, but luarocks is unhappy to have
  # two instances running in parallel.  So we depend on busted to force it to
  # be serialized.
  add_custom_command(OUTPUT ${DEPS_LIB_DIR}/luarocks/rocks/lua-messagepack
    COMMAND ${DEPS_BIN_DIR}/luarocks
    ARGS build lua-messagepack CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
    DEPENDS busted)
  add_custom_target(lua-messagepack
    DEPENDS ${DEPS_LIB_DIR}/luarocks/rocks/lua-messagepack)

  # Like before, depend on lua-messagepack to ensure serialization of install
  # commands
  add_custom_command(OUTPUT ${DEPS_LIB_DIR}/luarocks/rocks/lpeg
    COMMAND ${DEPS_BIN_DIR}/luarocks
    ARGS build lpeg CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
    DEPENDS lua-messagepack)
  add_custom_target(lpeg
    DEPENDS ${DEPS_LIB_DIR}/luarocks/rocks/lpeg)

  add_custom_command(OUTPUT ${DEPS_LIB_DIR}/luarocks/rocks/nvim-client
    COMMAND ${DEPS_BIN_DIR}/luarocks
    ARGS build https://raw.githubusercontent.com/neovim/lua-client/af161f5f89c7877d0f650b5de6b3a6126b38f012/nvim-client-0.0.1-10.rockspec CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER} LIBUV_DIR=${DEPS_INSTALL_DIR}
    DEPENDS lpeg libuv)
  add_custom_target(nvim-client
    DEPENDS ${DEPS_LIB_DIR}/luarocks/rocks/nvim-client)

  list(APPEND THIRD_PARTY_DEPS busted lua-messagepack lpeg nvim-client)
endif()

add_custom_target(third-party ALL
  COMMAND ${CMAKE_COMMAND} -E touch .third-party
  DEPENDS ${THIRD_PARTY_DEPS})
