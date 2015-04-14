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

if(USE_BUNDLED_LUAJIT)
  add_dependencies(luarocks luajit)
endif()

add_custom_command(OUTPUT ${DEPS_LIB_DIR}/luarocks/rocks/stable-busted-deps
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build lua_cliargs 2.3-3 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build luafilesystem 1.6.3-1 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build dkjson 2.5-1 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build say 1.3-0 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build luassert 1.7.4-0 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build lua-term 0.1-1 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build penlight 1.0.0-1 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build mediator_lua 1.1-3 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build luasocket 3.0rc1-2 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ARGS build xml 1.1.1-1 CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  COMMAND touch ${DEPS_LIB_DIR}/luarocks/rocks/stable-busted-deps
  DEPENDS luarocks)
add_custom_target(stable-busted-deps
  DEPENDS ${DEPS_LIB_DIR}/luarocks/rocks/stable-busted-deps)

add_custom_command(OUTPUT ${DEPS_BIN_DIR}/busted
  COMMAND ${DEPS_BIN_DIR}/luarocks
  ## Drop back to:
  ##    https://raw.githubusercontent.com/Olivine-Labs/busted/master/busted-scm-0.rockspec
  ## once the spec file is fixed in busted.
  ARGS build https://raw.githubusercontent.com/Olivine-Labs/busted/f803173cc136f7370f7416254eaf3bada01b04a9/busted-scm-0.rockspec CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER}
  DEPENDS stable-busted-deps)
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
  ARGS build https://raw.githubusercontent.com/neovim/lua-client/8cc5b6090ac61cd0bba53ba984f15792fbb64573/nvim-client-0.0.1-11.rockspec CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER} LIBUV_DIR=${DEPS_INSTALL_DIR}
  DEPENDS lpeg libuv)
add_custom_target(nvim-client
  DEPENDS ${DEPS_LIB_DIR}/luarocks/rocks/nvim-client)

list(APPEND THIRD_PARTY_DEPS stable-busted-deps busted lua-messagepack lpeg nvim-client)
