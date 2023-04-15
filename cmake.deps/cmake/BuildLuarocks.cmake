# Luarocks recipe. Luarocks is only required when building Neovim.
# NOTE: LuaRocks rocks need to "DEPENDS" on the previous module, because
#       running luarocks in parallel will break, e.g. when some rocks have
#       the same dependency.

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

if(MSVC)
  # Workaround for luarocks failing to find the md5sum.exe it is shipped with.
  list(APPEND LUAROCKS_BUILDARGS MD5SUM=md5sum)
  set(PATH PATH=${DEPS_INSTALL_DIR}/luarocks/tools;$ENV{PATH})
endif()

set(CURRENT_DEP luarocks)

function(Download ROCK VER)
  if(ARGV2)
    set(OUTPUT ${ARGV2})
  else()
    set(OUTPUT ${ROCKS_DIR}/${ROCK})
  endif()
  add_custom_command(OUTPUT ${OUTPUT}
    COMMAND ${CMAKE_COMMAND} -E env "${PATH}" ${LUAROCKS_BINARY} build ${ROCK} ${VER} ${LUAROCKS_BUILDARGS}
    DEPENDS ${CURRENT_DEP})
  add_custom_target(${ROCK} ALL DEPENDS ${OUTPUT})
  set(CURRENT_DEP ${ROCK} PARENT_SCOPE)
endfunction()

Download(mpack 1.0.10-0)
Download(lpeg 1.0.2-1)

if((NOT USE_BUNDLED_LUAJIT) AND USE_BUNDLED_LUA)
  Download(luabitop 1.0.2-3)
endif()

if(USE_BUNDLED_BUSTED)
  if(WIN32)
    set(BUSTED_EXE "${DEPS_BIN_DIR}/busted.bat")
    set(LUACHECK_EXE "${DEPS_BIN_DIR}/luacheck.bat")
  else()
    set(BUSTED_EXE "${DEPS_BIN_DIR}/busted")
    set(LUACHECK_EXE "${DEPS_BIN_DIR}/luacheck")
  endif()

  Download(busted 2.1.1 ${BUSTED_EXE})
  Download(luacheck 1.1.0-1 ${LUACHECK_EXE})

  if (USE_BUNDLED_LUA OR NOT USE_BUNDLED_LUAJIT)
    Download(coxpcall 1.17.0-1)
  endif()
endif()
