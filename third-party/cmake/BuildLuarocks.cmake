# Luarocks recipe. Luarocks is only required when building Neovim, when
# cross compiling we still want to build for the HOST system, whenever
# writing a recipe that is meant for cross-compile, use the HOSTDEPS_* variables
# instead of DEPS_* - check the main CMakeLists.txt for a list.

option(USE_BUNDLED_BUSTED "Use the bundled version of busted to run tests." ON)

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
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND "${_luarocks_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_luarocks_BUILD_COMMAND}"
    INSTALL_COMMAND "${_luarocks_INSTALL_COMMAND}")
endfunction()

# The luarocks binary location
set(LUAROCKS_BINARY ${HOSTDEPS_BIN_DIR}/luarocks)

# Arguments for calls to 'luarocks build'
if(NOT MSVC)
  # In MSVC don't pass the compiler/linker to luarocks, the bundled
  # version already knows, and passing them here breaks the build
  set(LUAROCKS_BUILDARGS CC=${HOSTDEPS_C_COMPILER} LD=${HOSTDEPS_C_COMPILER})
endif()

if(UNIX OR (MINGW AND CMAKE_CROSSCOMPILING))

  if(USE_BUNDLED_LUAJIT)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${HOSTDEPS_INSTALL_DIR}
      --with-lua-include=${HOSTDEPS_INSTALL_DIR}/include/luajit-2.0
      --lua-suffix=jit)
  elseif(USE_BUNDLED_LUA)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${HOSTDEPS_INSTALL_DIR})
  else()
    find_package(LuaJit)
    if(LUAJIT_FOUND)
      list(APPEND LUAROCKS_OPTS
        --lua-version=5.1
        --with-lua-include=${LUAJIT_INCLUDE_DIRS}
        --lua-suffix=jit)
    endif()
  endif()

  BuildLuarocks(
    CONFIGURE_COMMAND ${DEPS_BUILD_DIR}/src/luarocks/configure
      --prefix=${HOSTDEPS_INSTALL_DIR} --force-config ${LUAROCKS_OPTS}
    INSTALL_COMMAND ${MAKE_PRG} -j1 bootstrap)
elseif(MSVC OR MINGW)

  if(MINGW)
    set(COMPILER_FLAG /MW)
  elseif(MSVC)
    set(COMPILER_FLAG /MSVC)
  endif()

  # Ignore USE_BUNDLED_LUAJIT - always ON for native Win32
  BuildLuarocks(INSTALL_COMMAND install.bat /FORCECONFIG /NOREG /NOADMIN /Q /F
    /LUA ${DEPS_INSTALL_DIR}
    /LIB ${DEPS_LIB_DIR}
    /BIN ${DEPS_BIN_DIR}
    /INC ${DEPS_INSTALL_DIR}/include/luajit-2.0
    /P ${DEPS_INSTALL_DIR}/luarocks /TREE ${DEPS_INSTALL_DIR}
    /SCRIPTS ${DEPS_BIN_DIR}
    /CMOD ${DEPS_BIN_DIR}
    ${COMPILER_FLAG}
    /LUAMOD ${DEPS_BIN_DIR}/lua)

  set(LUAROCKS_BINARY ${DEPS_INSTALL_DIR}/luarocks/luarocks.bat)
else()
  message(FATAL_ERROR "Trying to build luarocks in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

list(APPEND THIRD_PARTY_DEPS luarocks)

if(USE_BUNDLED_LUAJIT)
  add_dependencies(luarocks luajit)
  if(MINGW AND CMAKE_CROSSCOMPILING)
    add_dependencies(luarocks luajit_host)
  endif()
elseif(USE_BUNDLED_LUA)
  add_dependencies(luarocks lua)
endif()

# DEPENDS on the previous module, because Luarocks breaks if parallel.
add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/mpack
  COMMAND ${LUAROCKS_BINARY}
  ARGS build mpack 1.0.8-0 ${LUAROCKS_BUILDARGS}
  DEPENDS luarocks)
add_custom_target(mpack
  DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/mpack)
list(APPEND THIRD_PARTY_DEPS mpack)

# DEPENDS on the previous module, because Luarocks breaks if parallel.
add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/lpeg
  COMMAND ${LUAROCKS_BINARY}
  ARGS build lpeg 1.0.2-1 ${LUAROCKS_BUILDARGS}
  DEPENDS mpack)
add_custom_target(lpeg
  DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/lpeg)

list(APPEND THIRD_PARTY_DEPS lpeg)

# DEPENDS on the previous module, because Luarocks breaks if parallel.
add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/inspect
  COMMAND ${LUAROCKS_BINARY}
  ARGS build inspect 3.1.1-0 ${LUAROCKS_BUILDARGS}
  DEPENDS lpeg)
add_custom_target(inspect
  DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/inspect)

list(APPEND THIRD_PARTY_DEPS inspect)

if((NOT USE_BUNDLED_LUAJIT) AND USE_BUNDLED_LUA)
  # DEPENDS on the previous module, because Luarocks breaks if parallel.
  add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/luabitop
    COMMAND ${LUAROCKS_BINARY}
    ARGS build luabitop 1.0.2-3 ${LUAROCKS_BUILDARGS}
    DEPENDS inspect)
  add_custom_target(luabitop
    DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/luabitop)

  list(APPEND THIRD_PARTY_DEPS luabitop)
endif()

if(USE_BUNDLED_BUSTED)
  if((NOT USE_BUNDLED_LUAJIT) AND USE_BUNDLED_LUA)
    set(PENLIGHT_DEPENDS luabitop)
  else()
    set(PENLIGHT_DEPENDS inspect)
  endif()

  # DEPENDS on the previous module, because Luarocks breaks if parallel.
  add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/penlight
    COMMAND ${LUAROCKS_BINARY}
    ARGS build penlight 1.5.4-1 ${LUAROCKS_BUILDARGS}
    DEPENDS ${PENLIGHT_DEPENDS})
  add_custom_target(penlight
    DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/penlight)

  if(WIN32)
    set(BUSTED_EXE "${HOSTDEPS_BIN_DIR}/busted.bat")
    set(LUACHECK_EXE "${HOSTDEPS_BIN_DIR}/luacheck.bat")
  else()
    set(BUSTED_EXE "${HOSTDEPS_BIN_DIR}/busted")
    set(LUACHECK_EXE "${HOSTDEPS_BIN_DIR}/luacheck")
  endif()
  # DEPENDS on the previous module, because Luarocks breaks if parallel.
  add_custom_command(OUTPUT ${BUSTED_EXE}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build busted 2.0.rc13-0 ${LUAROCKS_BUILDARGS}
    DEPENDS penlight)
  add_custom_target(busted
    DEPENDS ${BUSTED_EXE})

  # DEPENDS on the previous module, because Luarocks breaks if parallel.
  add_custom_command(OUTPUT ${LUACHECK_EXE}
    COMMAND ${LUAROCKS_BINARY}
    ARGS build luacheck 0.23.0-1 ${LUAROCKS_BUILDARGS}
    DEPENDS busted)
  add_custom_target(luacheck
    DEPENDS ${LUACHECK_EXE})

  # DEPENDS on the previous module, because Luarocks breaks if parallel.
  set(LUV_DEPS luacheck)
  if(USE_BUNDLED_LUV)
    list(APPEND LUV_DEPS luv-static lua-compat-5.3)
    if(MINGW AND CMAKE_CROSSCOMPILING)
      list(APPEND LUV_DEPS libuv_host)
    endif()
    set(LUV_ARGS "CFLAGS=-O0 -g3 -fPIC")
    if(USE_BUNDLED_LIBUV)
      list(APPEND LUV_ARGS LIBUV_DIR=${HOSTDEPS_INSTALL_DIR})
    endif()
    SET(LUV_PRIVATE_ARGS LUA_COMPAT53_INCDIR=${DEPS_BUILD_DIR}/src/lua-compat-5.3)
    add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/luv
      COMMAND ${LUAROCKS_BINARY}
      ARGS make ${LUAROCKS_BUILDARGS} ${LUV_ARGS} ${LUV_PRIVATE_ARGS}
      WORKING_DIRECTORY ${DEPS_BUILD_DIR}/src/luv
      DEPENDS ${LUV_DEPS})
  else()
    add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/luv
      COMMAND ${LUAROCKS_BINARY}
      ARGS build luv ${LUV_VERSION} ${LUAROCKS_BUILDARGS}
      DEPENDS ${LUV_DEPS})
  endif()
  add_custom_target(luv
    DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/luv)

  # DEPENDS on the previous module, because Luarocks breaks if parallel.
  add_custom_command(OUTPUT ${HOSTDEPS_LIB_DIR}/luarocks/rocks/nvim-client
    COMMAND ${LUAROCKS_BINARY}
    ARGS build nvim-client 0.2.0-1 ${LUAROCKS_BUILDARGS}
    DEPENDS luv)
  add_custom_target(nvim-client
    DEPENDS ${HOSTDEPS_LIB_DIR}/luarocks/rocks/nvim-client)

  list(APPEND THIRD_PARTY_DEPS busted luacheck nvim-client)
endif()
