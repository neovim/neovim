# Luarocks recipe. Luarocks is only required when building Neovim.
# NOTE: LuaRocks rocks need to "DEPENDS" on the previous module, because
#       running luarocks in parallel will break, e.g. when some rocks have
#       the same dependency..

option(USE_BUNDLED_BUSTED "Use the bundled version of busted to run tests." ON)

# The luarocks binary location
set(LUAROCKS_BINARY ${DEPS_BIN_DIR}/luarocks)

# Arguments for calls to 'luarocks build'
if(NOT MSVC)
  # In MSVC don't pass the compiler/linker to luarocks, the bundled
  # version already knows, and passing them here breaks the build
  set(LUAROCKS_BUILDARGS CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER})
endif()

# Lua version, used with rocks directories.
# Defaults to 5.1 for bundled LuaJIT/Lua.
set(LUA_VERSION "5.1")

if(UNIX)

  if(USE_BUNDLED_LUAJIT)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${DEPS_INSTALL_DIR}
      --with-lua-include=${DEPS_INSTALL_DIR}/include/luajit-2.1
      --with-lua-interpreter=luajit)
  elseif(USE_BUNDLED_LUA)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${DEPS_INSTALL_DIR})
  else()
    find_package(Luajit)
    if(LUAJIT_FOUND)
      list(APPEND LUAROCKS_OPTS
        --with-lua-include=${LUAJIT_INCLUDE_DIRS}
        --with-lua-interpreter=luajit)
    endif()

    # Get LUA_VERSION used with rocks output.
    if(LUAJIT_FOUND)
      set(LUA_EXE "luajit")
    else()
      set(LUA_EXE "lua")
    endif()
    execute_process(
      COMMAND ${LUA_EXE} -e "print(string.sub(_VERSION, 5))"
      OUTPUT_VARIABLE LUA_VERSION
      ERROR_VARIABLE ERR
      RESULT_VARIABLE RES)
    if(NOT RES EQUAL 0)
      message(FATAL_ERROR "Could not get LUA_VERSION with ${LUA_EXE}: ${ERR}")
    endif()
  endif()

  set(LUAROCKS_CONFIGURE_COMMAND ${DEPS_BUILD_DIR}/src/luarocks/configure
      --prefix=${DEPS_INSTALL_DIR} --force-config ${LUAROCKS_OPTS})
  set(LUAROCKS_INSTALL_COMMAND ${MAKE_PRG} -j1 bootstrap)
elseif(MSVC OR MINGW)

  if(MINGW)
    set(COMPILER_FLAG /MW)
  elseif(MSVC)
    set(COMPILER_FLAG /MSVC)
  endif()

  # Ignore USE_BUNDLED_LUAJIT - always ON for native Win32
  set(LUAROCKS_INSTALL_COMMAND install.bat /FORCECONFIG /NOREG /NOADMIN /Q /F
    /LUA ${DEPS_INSTALL_DIR}
    /LIB ${DEPS_LIB_DIR}
    /BIN ${DEPS_BIN_DIR}
    /INC ${DEPS_INSTALL_DIR}/include/luajit-2.1
    /P ${DEPS_INSTALL_DIR}/luarocks /TREE ${DEPS_INSTALL_DIR}
    /SCRIPTS ${DEPS_BIN_DIR}
    /CMOD ${DEPS_BIN_DIR}
    ${COMPILER_FLAG}
    /LUAMOD ${DEPS_BIN_DIR}/lua)

  set(LUAROCKS_BINARY ${DEPS_INSTALL_DIR}/luarocks/luarocks.bat)
else()
  message(FATAL_ERROR "Trying to build luarocks in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

ExternalProject_Add(luarocks
  URL ${LUAROCKS_URL}
  URL_HASH SHA256=${LUAROCKS_SHA256}
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luarocks
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND "${LUAROCKS_CONFIGURE_COMMAND}"
  BUILD_COMMAND ""
  INSTALL_COMMAND "${LUAROCKS_INSTALL_COMMAND}")

if(USE_BUNDLED_LUAJIT)
  add_dependencies(luarocks luajit)
elseif(USE_BUNDLED_LUA)
  add_dependencies(luarocks lua)
endif()
set(ROCKS_DIR ${DEPS_LIB_DIR}/luarocks/rocks-${LUA_VERSION})

# mpack
add_custom_command(OUTPUT ${ROCKS_DIR}/mpack
  COMMAND ${LUAROCKS_BINARY} build mpack 1.0.10-0 ${LUAROCKS_BUILDARGS}
  DEPENDS luarocks)
add_custom_target(mpack ALL DEPENDS ${ROCKS_DIR}/mpack)

# lpeg
add_custom_command(OUTPUT ${ROCKS_DIR}/lpeg
  COMMAND ${LUAROCKS_BINARY} build lpeg 1.0.2-1 ${LUAROCKS_BUILDARGS}
  DEPENDS mpack)
add_custom_target(lpeg ALL DEPENDS ${ROCKS_DIR}/lpeg)

if((NOT USE_BUNDLED_LUAJIT) AND USE_BUNDLED_LUA)
  # luabitop
  add_custom_command(OUTPUT ${ROCKS_DIR}/luabitop
    COMMAND ${LUAROCKS_BINARY} build luabitop 1.0.2-3 ${LUAROCKS_BUILDARGS}
    DEPENDS lpeg)
  add_custom_target(luabitop ALL DEPENDS ${ROCKS_DIR}/luabitop)
endif()

if(USE_BUNDLED_BUSTED)
  if((NOT USE_BUNDLED_LUAJIT) AND USE_BUNDLED_LUA)
    set(BUSTED_DEPENDS luabitop)
  else()
    set(BUSTED_DEPENDS lpeg)
  endif()

  # busted
  if(WIN32)
    set(BUSTED_EXE "${DEPS_BIN_DIR}/busted.bat")
    set(LUACHECK_EXE "${DEPS_BIN_DIR}/luacheck.bat")
  else()
    set(BUSTED_EXE "${DEPS_BIN_DIR}/busted")
    set(LUACHECK_EXE "${DEPS_BIN_DIR}/luacheck")
  endif()
  add_custom_command(OUTPUT ${BUSTED_EXE}
    COMMAND ${LUAROCKS_BINARY} build busted 2.1.1 ${LUAROCKS_BUILDARGS}
    DEPENDS ${BUSTED_DEPENDS})
  add_custom_target(busted ALL DEPENDS ${BUSTED_EXE})

  # luacheck
  add_custom_command(OUTPUT ${LUACHECK_EXE}
    COMMAND ${LUAROCKS_BINARY} build luacheck 1.1.0-1 ${LUAROCKS_BUILDARGS}
    DEPENDS busted)
  add_custom_target(luacheck ALL DEPENDS ${LUACHECK_EXE})

  if (USE_BUNDLED_LUA OR NOT USE_BUNDLED_LUAJIT)
    # coxpcall
    add_custom_command(OUTPUT ${ROCKS_DIR}/coxpcall
      COMMAND ${LUAROCKS_BINARY} build coxpcall 1.17.0-1 ${LUAROCKS_BUILDARGS}
      DEPENDS luarocks)
    add_custom_target(coxpcall ALL DEPENDS ${ROCKS_DIR}/coxpcall)
  endif()
endif()
