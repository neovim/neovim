# Luarocks recipe. Luarocks is only required when testing Neovim.
# NOTE: LuaRocks rocks need to "DEPENDS" on the previous module, because
#       running luarocks in parallel will break, e.g. when some rocks have
#       the same dependency.

# The luarocks binary location
set(LUAROCKS_BINARY ${DEPS_BIN_DIR}/luarocks)

# Arguments for calls to 'luarocks build'
if(NOT MSVC)
  # In MSVC don't pass the compiler/linker to luarocks, the bundled
  # version already knows, and passing them here breaks the build
  set(LUAROCKS_BUILDARGS CC=${DEPS_C_COMPILER} LD=${DEPS_C_COMPILER})
endif()

if(UNIX)
  if(PREFER_LUA)
    find_package(Lua 5.1 EXACT REQUIRED)
    get_filename_component(LUA_ROOT ${LUA_INCLUDE_DIR} DIRECTORY)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${LUA_ROOT})
  else()
    find_package(Luajit REQUIRED)
    get_filename_component(LUA_ROOT ${LUAJIT_INCLUDE_DIR} DIRECTORY)
    get_filename_component(LUA_ROOT ${LUA_ROOT} DIRECTORY)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${LUA_ROOT}
      --with-lua-include=${LUAJIT_INCLUDE_DIR}
      --with-lua-interpreter=luajit)
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

  find_package(Luajit REQUIRED)
  # Always assume bundled luajit for native Win32
  set(LUAROCKS_INSTALL_COMMAND install.bat /FORCECONFIG /NOREG /NOADMIN /Q /F
    /LUA ${DEPS_PREFIX}
    /INC ${LUAJIT_INCLUDE_DIR}
    /P ${DEPS_INSTALL_DIR}/luarocks
    /TREE ${DEPS_INSTALL_DIR}
    /SCRIPTS ${DEPS_BIN_DIR}
    ${COMPILER_FLAG})

  set(LUAROCKS_BINARY ${DEPS_INSTALL_DIR}/luarocks/luarocks.bat)
else()
  message(FATAL_ERROR "Trying to build luarocks in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

ExternalProject_Add(luarocks
  URL https://github.com/luarocks/luarocks/archive/v3.9.2.tar.gz
  URL_HASH SHA256=a0b36cd68586cd79966d0106bb2e5a4f5523327867995fd66bee4237062b3e3b
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luarocks
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND "${LUAROCKS_CONFIGURE_COMMAND}"
  BUILD_COMMAND ""
  INSTALL_COMMAND "${LUAROCKS_INSTALL_COMMAND}"
  EXCLUDE_FROM_ALL TRUE)

set(ROCKS_DIR ${DEPS_LIB_DIR}/luarocks/rocks)

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
  add_custom_target(${ROCK} DEPENDS ${OUTPUT})
  set(CURRENT_DEP ${ROCK} PARENT_SCOPE)
endfunction()

if(WIN32)
  set(LUACHECK_EXE "${DEPS_BIN_DIR}/luacheck.bat")
else()
  set(LUACHECK_EXE "${DEPS_BIN_DIR}/luacheck")
endif()

add_custom_target(test_deps)

Download(luacheck 1.1.0-1 ${LUACHECK_EXE})

if(PREFER_LUA)
  Download(coxpcall 1.17.0-1)
  add_dependencies(test_deps coxpcall)
endif()
