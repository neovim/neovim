option(USE_BUNDLED_BUSTED "Use the bundled version of busted to run tests." ON)

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
    -DEXPECTED_SHA256=${LUAROCKS_SHA256}
    -DTARGET=luarocks
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ${DEPS_BUILD_DIR}/src/luarocks/configure
    --prefix=${DEPS_INSTALL_DIR} --force-config ${LUAROCKS_OPTS}
    --lua-suffix=jit
  BUILD_COMMAND ""
  INSTALL_COMMAND ${MAKE_PRG} bootstrap)

list(APPEND THIRD_PARTY_DEPS luarocks)

# The path to the luarocks executable
set(LUAROCKS_BINARY ${DEPS_BIN_DIR}/luarocks)
# Common build arguments for luarocks build
set(LUAROCKS_BUILDARGS CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER})

if(USE_BUNDLED_LUAJIT)
  add_dependencies(luarocks luajit)
endif()

# Each target depends on the previous module, this serializes all calls to
# luarocks since it is unhappy to be called in parallel.
add_custom_command(OUTPUT ${DEPS_LIB_DIR}/luarocks/rocks/lua-messagepack
  COMMAND ${LUAROCKS_BINARY}
  ARGS build lua-messagepack ${LUAROCKS_BUILDARGS}
  DEPENDS luarocks)
add_custom_target(lua-messagepack
  DEPENDS ${DEPS_LIB_DIR}/luarocks/rocks/lua-messagepack)

# Like before, depend on lua-messagepack to ensure serialization of install
# commands
add_custom_command(OUTPUT ${DEPS_LIB_DIR}/luarocks/rocks/lpeg
  COMMAND ${LUAROCKS_BINARY}
  ARGS build lpeg ${LUAROCKS_BUILDARGS}
  DEPENDS lua-messagepack)
add_custom_target(lpeg
  DEPENDS ${DEPS_LIB_DIR}/luarocks/rocks/lpeg)

list(APPEND THIRD_PARTY_DEPS lua-messagepack lpeg)

if(USE_BUNDLED_BUSTED)
  # The following are only required if we want to run tests
  # with busted
  
  add_custom_command(OUTPUT ${DEPS_LIB_DIR}/luarocks/rocks/stable-busted-deps
    COMMAND ${LUAROCKS_BINARY}
    ARGS build lua_cliargs 2.3-3 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build luafilesystem 1.6.3-1 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build dkjson 2.5-1 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build say 1.3-0 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build luassert 1.7.4-0 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build lua-term 0.1-1 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build penlight 1.0.0-1 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build mediator_lua 1.1-3 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build luasocket 3.0rc1-2 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build xml 1.1.2-1 ${LUAROCKS_BUILDARGS}
    COMMAND touch ${DEPS_LIB_DIR}/luarocks/rocks/stable-busted-deps
    DEPENDS lpeg)
  add_custom_target(stable-busted-deps
    DEPENDS ${DEPS_LIB_DIR}/luarocks/rocks/stable-busted-deps)
  
  add_custom_command(OUTPUT ${DEPS_BIN_DIR}/busted
    COMMAND ${LUAROCKS_BINARY}
    ARGS build https://raw.githubusercontent.com/Olivine-Labs/busted/v2.0.rc8-0/busted-2.0.rc8-0.rockspec ${LUAROCKS_BUILDARGS}
    DEPENDS stable-busted-deps)
  add_custom_target(busted
    DEPENDS ${DEPS_BIN_DIR}/busted)
  
  add_custom_command(OUTPUT ${DEPS_LIB_DIR}/luarocks/rocks/nvim-client
    COMMAND ${LUAROCKS_BINARY}
    ARGS build https://raw.githubusercontent.com/neovim/lua-client/8cc5b6090ac61cd0bba53ba984f15792fbb64573/nvim-client-0.0.1-11.rockspec ${LUAROCKS_BUILDARGS} LIBUV_DIR=${DEPS_INSTALL_DIR}
    DEPENDS busted libuv)
  add_custom_target(nvim-client
    DEPENDS ${DEPS_LIB_DIR}/luarocks/rocks/nvim-client)
  
  list(APPEND THIRD_PARTY_DEPS stable-busted-deps busted nvim-client)
endif()
