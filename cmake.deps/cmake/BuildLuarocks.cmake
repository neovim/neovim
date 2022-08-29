# Luarocks recipe. Luarocks is only required when building Neovim, when
# cross compiling we still want to build for the HOST system, whenever
# writing a recipe that is meant for cross-compile, use the HOSTDEPS_* variables
# instead of DEPS_* - check the main CMakeLists.txt for a list.
#
# NOTE: LuaRocks rocks need to "DEPENDS" on the previous module, because
#       running luarocks in parallel will break, e.g. when some rocks have
#       the same dependency..

option(USE_BUNDLED_BUSTED "Use the bundled version of busted to run tests." ON)

# The luarocks binary location
set(LUAROCKS_BINARY ${HOSTDEPS_BIN_DIR}/luarocks)

# Arguments for calls to 'luarocks build'
if(NOT MSVC)
  # In MSVC don't pass the compiler/linker to luarocks, the bundled
  # version already knows, and passing them here breaks the build
  set(LUAROCKS_BUILDARGS CC=${HOSTDEPS_C_COMPILER} LD=${HOSTDEPS_C_COMPILER})
endif()

# Lua version, used with rocks directories.
# Defaults to 5.1 for bundled LuaJIT/Lua.
set(LUA_VERSION "5.1")

if(UNIX)

  if(USE_BUNDLED_LUAJIT)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${HOSTDEPS_INSTALL_DIR}
      --with-lua-include=${HOSTDEPS_INSTALL_DIR}/include/luajit-2.1
      --with-lua-interpreter=luajit)
  elseif(USE_BUNDLED_LUA)
    list(APPEND LUAROCKS_OPTS
      --with-lua=${HOSTDEPS_INSTALL_DIR})
  else()
    find_package(LuaJit)
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
      --prefix=${HOSTDEPS_INSTALL_DIR} --force-config ${LUAROCKS_OPTS})
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
  CONFIGURE_COMMAND "${LUAROCKS_CONFIGURE_COMMAND}"
  BUILD_COMMAND ""
  INSTALL_COMMAND "${LUAROCKS_INSTALL_COMMAND}")

list(APPEND THIRD_PARTY_DEPS luarocks)

if(USE_BUNDLED_LUAJIT)
  add_dependencies(luarocks luajit)
elseif(USE_BUNDLED_LUA)
  add_dependencies(luarocks lua)
endif()
set(ROCKS_DIR ${HOSTDEPS_LIB_DIR}/luarocks/rocks-${LUA_VERSION})

# mpack
add_custom_command(OUTPUT ${ROCKS_DIR}/mpack
  COMMAND ${LUAROCKS_BINARY} build mpack 1.0.8-0 ${LUAROCKS_BUILDARGS}
  DEPENDS luarocks)
add_custom_target(mpack DEPENDS ${ROCKS_DIR}/mpack)
list(APPEND THIRD_PARTY_DEPS mpack)

# lpeg
add_custom_command(OUTPUT ${ROCKS_DIR}/lpeg
  COMMAND ${LUAROCKS_BINARY} build lpeg 1.0.2-1 ${LUAROCKS_BUILDARGS}
  DEPENDS mpack)
add_custom_target(lpeg DEPENDS ${ROCKS_DIR}/lpeg)
list(APPEND THIRD_PARTY_DEPS lpeg)

if((NOT USE_BUNDLED_LUAJIT) AND USE_BUNDLED_LUA)
  # luabitop
  add_custom_command(OUTPUT ${ROCKS_DIR}/luabitop
    COMMAND ${LUAROCKS_BINARY} build luabitop 1.0.2-3 ${LUAROCKS_BUILDARGS}
    DEPENDS lpeg)
  add_custom_target(luabitop DEPENDS ${ROCKS_DIR}/luabitop)
  list(APPEND THIRD_PARTY_DEPS luabitop)
endif()

if(USE_BUNDLED_BUSTED)
  if((NOT USE_BUNDLED_LUAJIT) AND USE_BUNDLED_LUA)
    set(PENLIGHT_DEPENDS luabitop)
  else()
    set(PENLIGHT_DEPENDS lpeg)
  endif()

  # penlight
  add_custom_command(OUTPUT ${ROCKS_DIR}/penlight
    COMMAND ${LUAROCKS_BINARY} build penlight 1.5.4-1 ${LUAROCKS_BUILDARGS}
    DEPENDS ${PENLIGHT_DEPENDS})
  add_custom_target(penlight DEPENDS ${ROCKS_DIR}/penlight)

  # busted
  if(WIN32)
    set(BUSTED_EXE "${HOSTDEPS_BIN_DIR}/busted.bat")
    set(LUACHECK_EXE "${HOSTDEPS_BIN_DIR}/luacheck.bat")
  else()
    set(BUSTED_EXE "${HOSTDEPS_BIN_DIR}/busted")
    set(LUACHECK_EXE "${HOSTDEPS_BIN_DIR}/luacheck")
  endif()
  add_custom_command(OUTPUT ${BUSTED_EXE}
    COMMAND ${LUAROCKS_BINARY} build busted 2.0.0 ${LUAROCKS_BUILDARGS}
    DEPENDS penlight)
  add_custom_target(busted DEPENDS ${BUSTED_EXE})

  # luacheck
  add_custom_command(OUTPUT ${LUACHECK_EXE}
    COMMAND ${LUAROCKS_BINARY} build luacheck 0.23.0-1 ${LUAROCKS_BUILDARGS}
    DEPENDS busted)
  add_custom_target(luacheck DEPENDS ${LUACHECK_EXE})

  # luv
  set(LUV_DEPS luacheck)
  if(USE_BUNDLED_LUV)
    set(NVIM_CLIENT_DEPS luacheck luv-static lua-compat-5.3)
  else()
    add_custom_command(OUTPUT ${ROCKS_DIR}/luv
      COMMAND ${LUAROCKS_BINARY} build luv ${LUV_VERSION} ${LUAROCKS_BUILDARGS}
      DEPENDS luacheck)
    add_custom_target(luv DEPENDS ${ROCKS_DIR}/luv)
    set(NVIM_CLIENT_DEPS luv)
  endif()

  # nvim-client: https://github.com/neovim/lua-client
  add_custom_command(OUTPUT ${ROCKS_DIR}/nvim-client
    COMMAND ${LUAROCKS_BINARY} build nvim-client 0.2.4-1 ${LUAROCKS_BUILDARGS}
    DEPENDS ${NVIM_CLIENT_DEPS})
  add_custom_target(nvim-client DEPENDS ${ROCKS_DIR}/nvim-client)

  list(APPEND THIRD_PARTY_DEPS busted luacheck nvim-client)
endif()
