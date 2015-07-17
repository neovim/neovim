# Luarocks recipe. Luarocks is only required when building Neovim, when
# cross compiling we still want to build for the HOST system, whenever
# writing a recipe than is mean for cross-compile, use the HOSTDEPS_* variables
# instead of DEPS_* - check the main CMakeLists.txt for a list.

if(MSVC)
  message(STATUS "Building busted in Windows is not supported (skipping)")
else()
  option(USE_BUNDLED_BUSTED "Use the bundled version of busted to run tests." ON)
endif()

# BuildLuarocks(CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build luarocks, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildLuarocks)
  cmake_parse_arguments(_luarocks
    ""
    ""
    "CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})

  if(NOT _luarocks_CONFIGURE_COMMAND AND NOT _luarocks_BUILD_COMMAND
        AND NOT _luarocks_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND, BUILD_COMMAND, INSTALL_COMMAND")
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
    CONFIGURE_COMMAND "${_luarocks_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_luarocks_BUILD_COMMAND}"
    INSTALL_COMMAND "${_luarocks_INSTALL_COMMAND}")
endfunction()

# The luarocks binary location
set(LUAROCKS_BINARY ${HOSTDEPS_BIN_DIR}/luarocks)

# Arguments for calls to 'luarocks build'
if(MSVC)
  # In native Win32 don't pass the compiler/linker to luarocks, the bundled
  # version already knows, and passing them here breaks the build
  set(LUAROCKS_BUILDARGS CFLAGS=/MT)
else()
  set(LUAROCKS_BUILDARGS CC=${HOSTDEPS_C_COMPILER} LD=${HOSTDEPS_C_COMPILER})
endif()

if(UNIX OR (MINGW AND CMAKE_CROSSCOMPILING))

  if(USE_BUNDLED_LUAJIT)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${HOSTDEPS_INSTALL_DIR}
      --with-lua-include=${HOSTDEPS_INSTALL_DIR}/include/luajit-2.0)
  endif()

  BuildLuarocks(
    CONFIGURE_COMMAND ${DEPS_BUILD_DIR}/src/luarocks/configure
      --prefix=${HOSTDEPS_INSTALL_DIR} --force-config ${LUAROCKS_OPTS}
      --lua-suffix=jit
    INSTALL_COMMAND ${MAKE_PRG} bootstrap)

elseif(MSVC)
  # Ignore USE_BUNDLED_LUAJIT - always ON for native Win32
  BuildLuarocks(INSTALL_COMMAND install.bat /FORCECONFIG /NOREG /NOADMIN /Q /F
    /LUA ${DEPS_INSTALL_DIR}
    /LIB ${DEPS_LIB_DIR}
    /BIN ${DEPS_BIN_DIR}
    /INC ${DEPS_INSTALL_DIR}/include/luajit-2.0/
    /P ${DEPS_INSTALL_DIR} /TREE ${DEPS_INSTALL_DIR}
    /SCRIPTS ${DEPS_BIN_DIR}
    /CMOD ${DEPS_BIN_DIR}
    /LUAMOD ${DEPS_BIN_DIR}/lua)

  set(LUAROCKS_BINARY ${DEPS_INSTALL_DIR}/2.2/luarocks.bat)
else()
  message(FATAL_ERROR "Trying to build luarocks in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

list(APPEND THIRD_PARTY_DEPS luarocks)

if(USE_BUNDLED_LUAJIT)
  add_dependencies(luarocks luajit)
endif()

# Each target depends on the previous module, this serializes all calls to
# luarocks since it is unhappy to be called in parallel.
add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/lua-messagepack
  COMMAND ${LUAROCKS_BINARY}
  ARGS build lua-messagepack ${LUAROCKS_BUILDARGS}
  DEPENDS luarocks)
add_custom_target(lua-messagepack
  DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/lua-messagepack)
list(APPEND THIRD_PARTY_DEPS lua-messagepack)


# Like before, depend on lua-messagepack to ensure serialization of install
# commands
add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/lpeg
  COMMAND ${LUAROCKS_BINARY}
  ARGS build lpeg ${LUAROCKS_BUILDARGS}
  DEPENDS lua-messagepack)
add_custom_target(lpeg
  DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/lpeg)

list(APPEND THIRD_PARTY_DEPS lpeg)

if(USE_BUNDLED_BUSTED)
  # The following are only required if we want to run tests
  # with busted
  add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/stable-busted-deps
    COMMAND ${LUAROCKS_BINARY}
    ARGS build lua_cliargs 2.5-1 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build luafilesystem 1.6.3-1 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build dkjson 2.5-2 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build say 1.3-0 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build luassert 1.7.6-0 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build lua-term 0.3-1 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build penlight 1.3.2-2 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build mediator_lua 1.1.1-0 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build luasocket 3.0rc1-2 ${LUAROCKS_BUILDARGS}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build xml 1.1.2-1 ${LUAROCKS_BUILDARGS}
    COMMAND ${CMAKE_COMMAND} -E touch ${HOSTDEPS_LIB_DIR}/luarocks/rocks/stable-busted-deps
    DEPENDS lpeg)
  add_custom_target(stable-busted-deps
    DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/stable-busted-deps)

  add_custom_command(OUTPUT ${HOSTDEPS_BIN_DIR}/busted
    COMMAND ${LUAROCKS_BINARY}
    ARGS build https://raw.githubusercontent.com/Olivine-Labs/busted/v2.0.rc10-0/busted-2.0.rc10-0.rockspec ${LUAROCKS_BUILDARGS}
    DEPENDS stable-busted-deps)
  add_custom_target(busted
    DEPENDS ${HOSTDEPS_BIN_DIR}/busted)

  add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/nvim-client
    COMMAND ${LUAROCKS_BINARY}
    ARGS build https://raw.githubusercontent.com/neovim/lua-client/0.0.1-12/nvim-client-0.0.1-12.rockspec ${LUAROCKS_BUILDARGS} LIBUV_DIR=${HOSTDEPS_INSTALL_DIR}
    DEPENDS busted libuv)
  add_custom_target(nvim-client
    DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/nvim-client)

  list(APPEND THIRD_PARTY_DEPS stable-busted-deps busted nvim-client)
endif()
