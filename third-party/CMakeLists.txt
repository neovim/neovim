# This is not meant to be included by the top-level.
cmake_minimum_required (VERSION 2.8.7)
project(NEOVIM_DEPS)

if(NOT DEPS_DIR)
  get_filename_component(PARENT_DIR ${CMAKE_CURRENT_SOURCE_DIR} PATH)
  set(DEPS_DIR ${PARENT_DIR}/.deps)
endif()

set(DEPS_INSTALL_DIR "${DEPS_DIR}/usr")
set(DEPS_BIN_DIR "${DEPS_DIR}/usr/bin")
set(DEPS_BUILD_DIR "${DEPS_DIR}/build")
set(DEPS_DOWNLOAD_DIR "${DEPS_BUILD_DIR}/downloads")

option(USE_BUNDLED_LIBUV "Use the bundled libuv." ON)
option(USE_BUNDLED_LUAJIT "Use the bundled version of luajit." ON)
option(USE_BUNDLED_LUAROCKS "Use the bundled version of luarocks." ON)

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


include(ExternalProject)

if(USE_BUNDLED_LIBUV)
  ExternalProject_Add(libuv
    PREFIX ${DEPS_BUILD_DIR}
    URL https://github.com/joyent/libuv/archive/v0.11.21.tar.gz
    URL_MD5 bc334c8da8618754ce9e2a4c5be73487
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libuv
    CONFIGURE_COMMAND sh ${DEPS_BUILD_DIR}/src/libuv/autogen.sh &&
      ${DEPS_BUILD_DIR}/src/libuv/configure --with-pic --disable-shared
        --prefix=${DEPS_INSTALL_DIR} CC=${CMAKE_C_COMPILER}
    INSTALL_COMMAND ${MAKE_PRG} install)
  list(APPEND THIRD_PARTY_DEPS libuv)
endif()

if(USE_BUNDLED_LUAJIT)
  ExternalProject_Add(luajit
    PREFIX ${DEPS_BUILD_DIR}
    URL http://luajit.org/download/LuaJIT-2.0.2.tar.gz
    URL_MD5 112dfb82548b03377fbefbba2e0e3a5b
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luajit
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    BUILD_COMMAND ""
    INSTALL_COMMAND ${MAKE_PRG} CC=${CMAKE_C_COMPILER}
                                PREFIX=${DEPS_INSTALL_DIR}
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
    URL http://github.com/keplerproject/luarocks/archive/v2.1.2.tar.gz
    URL_MD5 df591c00a85d51fb754ec08c77896aad
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luarocks
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

  add_custom_command(OUTPUT ${DEPS_BIN_DIR}/moon ${DEPS_BIN_DIR}/moonc
    COMMAND ${DEPS_BIN_DIR}/luarocks ARGS install moonscript
            --server=http://rocks.moonscript.org
    DEPENDS luarocks)
  add_custom_target(moonscript
    DEPENDS ${DEPS_BIN_DIR}/moon ${DEPS_BIN_DIR}/moonc)

  # Busted doesn't depend on luarocks, but luarocks is unhappy to have two
  # instances running in parallel.  So we depend on moonscript to force it
  # to be serialized.
  add_custom_command(OUTPUT ${DEPS_BIN_DIR}/busted
    COMMAND ${DEPS_BIN_DIR}/luarocks ARGS install busted
            --server=http://rocks.moonscript.org
    DEPENDS moonscript)
  add_custom_target(busted
    DEPENDS ${DEPS_BIN_DIR}/busted)
  list(APPEND THIRD_PARTY_DEPS moonscript busted)
endif()

add_custom_target(third-party ALL
  COMMAND ${CMAKE_COMMAND} -E touch .third-party
  DEPENDS ${THIRD_PARTY_DEPS})
