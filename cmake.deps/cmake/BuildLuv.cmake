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

list(APPEND LUV_CMAKE_ARGS "-DCMAKE_C_FLAGS:STRING=${DEPS_INCLUDE_FLAGS} -w")
if(CMAKE_GENERATOR MATCHES "Unix Makefiles" AND
    (CMAKE_SYSTEM_NAME MATCHES ".*BSD" OR CMAKE_SYSTEM_NAME MATCHES "DragonFly"))
    list(APPEND LUV_CMAKE_ARGS -D CMAKE_MAKE_PROGRAM=gmake)
endif()

get_sha(lua_compat53 ${DEPS_IGNORE_SHA})
ExternalProject_Add(lua_compat53
  URL ${LUA_COMPAT53_URL}
  ${EXTERNALPROJECT_URL_HASH}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/lua_compat53
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  ${EXTERNALPROJECT_OPTIONS})

get_sha(luv ${DEPS_IGNORE_SHA})
ExternalProject_Add(luv
  DEPENDS lua_compat53
  URL ${LUV_URL}
  ${EXTERNALPROJECT_URL_HASH}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luv
  SOURCE_DIR ${DEPS_BUILD_DIR}/src/luv
  CMAKE_ARGS ${DEPS_CMAKE_ARGS} ${LUV_CMAKE_ARGS}
  CMAKE_CACHE_ARGS ${DEPS_CMAKE_CACHE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})

if(USE_BUNDLED_LUAJIT)
  add_dependencies(luv luajit)
elseif(USE_BUNDLED_LUA)
  add_dependencies(luv lua)
endif()
if(USE_BUNDLED_LIBUV)
  add_dependencies(luv libuv)
endif()
