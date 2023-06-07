if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(LUA_TARGET linux)
elseif(APPLE)
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

if(ENABLE_ASAN_UBSAN)
  set(LUA_CFLAGS "${LUA_CFLAGS} -fsanitize=address")
  set(LUA_CFLAGS "${LUA_CFLAGS} -fno-omit-frame-pointer")
  set(LUA_CFLAGS "${LUA_CFLAGS} -fno-optimize-sibling-calls")

  set(LUA_LDFLAGS "${LUA_LDFLAGS} -fsanitize=address")
endif()

set(LUA_CONFIGURE_COMMAND
  sed -e "/^CC/s@gcc@${CMAKE_C_COMPILER}@"
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

message(STATUS "Lua target is ${LUA_TARGET}")

ExternalProject_Add(lua
  URL ${LUA_URL}
  URL_HASH SHA256=${LUA_SHA256}
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/lua
  CONFIGURE_COMMAND "${LUA_CONFIGURE_COMMAND}"
  BUILD_IN_SOURCE 1
  BUILD_COMMAND ${MAKE_PRG} ${LUA_INSTALL_TOP_ARG} ${LUA_TARGET}
  INSTALL_COMMAND ${MAKE_PRG} ${LUA_INSTALL_TOP_ARG} install)
