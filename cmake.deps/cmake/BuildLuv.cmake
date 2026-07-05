set(LUV_CMAKE_ARGS
  -D LUA_BUILD_TYPE=System
  -D LUA_COMPAT53_DIR=${DEPS_BUILD_DIR}/src/lua_compat53
  -D WITH_SHARED_LIBUV=ON
  -D BUILD_STATIC_LIBS=ON
  -D BUILD_MODULE=OFF)

list(APPEND LUV_CMAKE_ARGS -D WITH_LUA_ENGINE=${LUA_ENGINE})

if(USE_BUNDLED_LIBUV)
  list(APPEND LUV_CMAKE_ARGS -D CMAKE_PREFIX_PATH=${DEPS_INSTALL_DIR})
endif()

# Emscripten's CMake toolchain sets CMAKE_FIND_ROOT_PATH_MODE_{LIBRARY,INCLUDE}
# to ONLY, confining find_library()/find_path() to the emscripten sysroot. That
# stops luv's find_package(Libuv) from discovering our cross-compiled libuv in
# DEPS_INSTALL_DIR. Hand luv the libuv location explicitly so it doesn't rely on
# find_package. (Native builds are unaffected.)
if(EMSCRIPTEN AND USE_BUNDLED_LIBUV)
  list(APPEND LUV_CMAKE_ARGS
    -D LIBUV_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include
    -D LIBUV_LIBRARIES=${DEPS_INSTALL_DIR}/lib/libuv.a)
endif()

# Likewise, luv needs the (PUC) Lua headers; find_package(Lua) can't locate them
# under the emscripten find-root restriction, so point it at our bundled Lua.
if(EMSCRIPTEN)
  list(APPEND LUV_CMAKE_ARGS
    -D LUA_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include
    -D LUA_LIBRARIES=${DEPS_INSTALL_DIR}/lib/liblua.a)
endif()

list(APPEND LUV_CMAKE_ARGS "-DCMAKE_C_FLAGS:STRING=${DEPS_INCLUDE_FLAGS} -w")
if(CMAKE_GENERATOR MATCHES "Unix Makefiles" AND
    (CMAKE_SYSTEM_NAME MATCHES ".*BSD" OR CMAKE_SYSTEM_NAME MATCHES "DragonFly"))
    list(APPEND LUV_CMAKE_ARGS -D CMAKE_MAKE_PROGRAM=gmake)
endif()

get_externalproject_options(lua_compat53 ${DEPS_IGNORE_SHA})
ExternalProject_Add(lua_compat53
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/lua_compat53
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  ${EXTERNALPROJECT_OPTIONS})

get_externalproject_options(luv ${DEPS_IGNORE_SHA})
ExternalProject_Add(luv
  DEPENDS lua_compat53
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luv
  SOURCE_DIR ${DEPS_BUILD_DIR}/src/luv
  CMAKE_ARGS ${DEPS_CMAKE_ARGS} ${LUV_CMAKE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})

if(USE_BUNDLED_LUAJIT)
  add_dependencies(luv luajit)
elseif(USE_BUNDLED_LUA)
  add_dependencies(luv lua)
endif()
if(USE_BUNDLED_LIBUV)
  add_dependencies(luv libuv)
endif()
