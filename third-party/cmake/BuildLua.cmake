include(CMakeParseArguments)

# BuildLua(CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build lua, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildLua)
  cmake_parse_arguments(_lua
    ""
    ""
    "CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})

  if(NOT _lua_CONFIGURE_COMMAND AND NOT _lua_BUILD_COMMAND
       AND NOT _lua_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND, BUILD_COMMAND, INSTALL_COMMAND")
  endif()

  ExternalProject_Add(lua
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LUA_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/lua
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/lua
      -DURL=${LUA_URL}
      -DEXPECTED_SHA256=${LUA_SHA256}
      -DTARGET=lua
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND "${_lua_CONFIGURE_COMMAND}"
    BUILD_IN_SOURCE 1
    BUILD_COMMAND "${_lua_BUILD_COMMAND}"
    INSTALL_COMMAND "${_lua_INSTALL_COMMAND}")
endfunction()

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(LUA_TARGET linux)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(LUA_TARGET macosx)
elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
  set(LUA_TARGET freebsd)
elseif(CMAKE_SYSTEM_NAME MATCHES "BSD")
  set(CMAKE_LUA_TARGET bsd)
elseif(CMAKE_SYSTEM_NAME MATCHES "^MINGW")
  set(CMAKE_LUA_TARGET mingw)
else()
  if(UNIX)
    set(LUA_TARGET posix)
  else()
    set(LUA_TARGET generic)
  endif()
endif()

set(LUA_CFLAGS "-O0 -g3 -fPIC")
set(LUA_LDFLAGS "")

if(CLANG_ASAN_UBSAN)
  set(LUA_CFLAGS "${LUA_CFLAGS} -fsanitize=address")
  set(LUA_CFLAGS "${LUA_CFLAGS} -fno-omit-frame-pointer")
  set(LUA_CFLAGS "${LUA_CFLAGS} -fno-optimize-sibling-calls")

  set(LUA_LDFLAGS "${LUA_LDFLAGS} -fsanitize=address")
endif()

set(LUA_CONFIGURE_COMMAND
  sed -e "/^CC/s@gcc@${CMAKE_C_COMPILER} ${CMAKE_C_COMPILER_ARG1}@"
      -e "/^CFLAGS/s@-O2@${LUA_CFLAGS}@"
      -e "/^MYLDFLAGS/s@$@${LUA_LDFLAGS}@"
      -e "s@-lreadline@@g"
      -e "s@-lhistory@@g"
      -e "s@-lncurses@@g"
      -i ${DEPS_BUILD_DIR}/src/lua/src/Makefile &&
  sed -e "/#define LUA_USE_READLINE/d"
      -e "s@\\(#define LUA_ROOT[ 	]*\"\\)/usr/local@\\1${DEPS_INSTALL_DIR}@"
      -i ${DEPS_BUILD_DIR}/src/lua/src/luaconf.h)
set(LUA_INSTALL_TOP_ARG "INSTALL_TOP=${DEPS_INSTALL_DIR}")
set(LUA_BUILD_COMMAND
    ${MAKE_PRG} ${LUA_INSTALL_TOP_ARG} ${LUA_TARGET})
set(LUA_INSTALL_COMMAND
    ${MAKE_PRG} ${LUA_INSTALL_TOP_ARG} install)

message(STATUS "Lua target is ${LUA_TARGET}")

BuildLua(CONFIGURE_COMMAND ${LUA_CONFIGURE_COMMAND}
  BUILD_COMMAND ${LUA_BUILD_COMMAND}
  INSTALL_COMMAND ${LUA_INSTALL_COMMAND})
list(APPEND THIRD_PARTY_DEPS lua)

set(BUSTED ${DEPS_INSTALL_DIR}/bin/busted)
set(BUSTED_LUA ${BUSTED}-lua)

add_custom_command(OUTPUT ${BUSTED_LUA}
  COMMAND sed -e 's/^exec/exec $$LUA_DEBUGGER/' -e 's/jit//g' < ${BUSTED} > ${BUSTED_LUA} && chmod +x ${BUSTED_LUA}
  DEPENDS lua busted ${BUSTED})
add_custom_target(busted-lua
  DEPENDS ${DEPS_INSTALL_DIR}/bin/busted-lua)

list(APPEND THIRD_PARTY_DEPS busted-lua)
