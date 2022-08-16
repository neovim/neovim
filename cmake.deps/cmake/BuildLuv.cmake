# BuildLuv(PATCH_COMMAND ... CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build luv, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildLuv)
  cmake_parse_arguments(_luv
    ""
    ""
    "PATCH_COMMAND;CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})

  if(NOT _luv_CONFIGURE_COMMAND AND NOT _luv_BUILD_COMMAND
       AND NOT _luv_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND, BUILD_COMMAND, INSTALL_COMMAND")
  endif()

  ExternalProject_Add(lua-compat-5.3
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LUA_COMPAT53_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/lua-compat-5.3
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/lua-compat-5.3
      -DURL=${LUA_COMPAT53_URL}
      -DEXPECTED_SHA256=${LUA_COMPAT53_SHA256}
      -DTARGET=lua-compat-5.3
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    PATCH_COMMAND ""
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND "")

  ExternalProject_Add(luv-static
    PREFIX ${DEPS_BUILD_DIR}
    DEPENDS lua-compat-5.3
    URL ${LUV_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luv
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/luv
      -DURL=${LUV_URL}
      -DEXPECTED_SHA256=${LUV_SHA256}
      -DTARGET=luv-static
      # The source is shared with BuildLuarocks (with USE_BUNDLED_LUV).
      -DSRC_DIR=${DEPS_BUILD_DIR}/src/luv
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    PATCH_COMMAND "${_luv_PATCH_COMMAND}"
    CONFIGURE_COMMAND "${_luv_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_luv_BUILD_COMMAND}"
    INSTALL_COMMAND "${_luv_INSTALL_COMMAND}"
    LIST_SEPARATOR |)
endfunction()

set(LUV_SRC_DIR ${DEPS_BUILD_DIR}/src/luv)
set(LUV_INCLUDE_FLAGS
  "-I${DEPS_INSTALL_DIR}/include -I${DEPS_INSTALL_DIR}/include/luajit-2.1")

set(LUV_CONFIGURE_COMMAND_COMMON
  ${CMAKE_COMMAND} ${LUV_SRC_DIR}
  -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
  ${BUILD_TYPE_STRING}
  -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
  -DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES_ALT_SEP}
  -DLUA_BUILD_TYPE=System
  -DLUA_COMPAT53_DIR=${DEPS_BUILD_DIR}/src/lua-compat-5.3
  -DWITH_SHARED_LIBUV=ON
  -DBUILD_SHARED_LIBS=OFF
  -DBUILD_STATIC_LIBS=ON
  -DBUILD_MODULE=OFF)

if(USE_BUNDLED_LUAJIT)
  list(APPEND LUV_CONFIGURE_COMMAND_COMMON -DWITH_LUA_ENGINE=LuaJit)
elseif(USE_BUNDLED_LUA)
  list(APPEND LUV_CONFIGURE_COMMAND_COMMON -DWITH_LUA_ENGINE=Lua)
else()
  find_package(LuaJit)
  if(LUAJIT_FOUND)
    list(APPEND LUV_CONFIGURE_COMMAND_COMMON -DWITH_LUA_ENGINE=LuaJit)
  else()
    list(APPEND LUV_CONFIGURE_COMMAND_COMMON -DWITH_LUA_ENGINE=Lua)
  endif()
endif()

if(USE_BUNDLED_LIBUV)
  set(LUV_CONFIGURE_COMMAND_COMMON
    ${LUV_CONFIGURE_COMMAND_COMMON}
    -DCMAKE_PREFIX_PATH=${DEPS_INSTALL_DIR}
    -DLIBUV_LIBRARIES=uv_a)
endif()

if(MSVC)
  set(LUV_CONFIGURE_COMMAND
    ${LUV_CONFIGURE_COMMAND_COMMON}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}
    # Same as Unix without fPIC
    "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1} ${LUV_INCLUDE_FLAGS}"
    # Make sure we use the same generator, otherwise we may
    # accidentally end up using different MSVC runtimes
    -DCMAKE_GENERATOR=${CMAKE_GENERATOR})
else()
  set(LUV_CONFIGURE_COMMAND
    ${LUV_CONFIGURE_COMMAND_COMMON}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1} ${LUV_INCLUDE_FLAGS} -fPIC")
  if(CMAKE_GENERATOR MATCHES "Unix Makefiles" AND
      (CMAKE_SYSTEM_NAME MATCHES ".*BSD" OR CMAKE_SYSTEM_NAME MATCHES "DragonFly"))
      set(LUV_CONFIGURE_COMMAND ${LUV_CONFIGURE_COMMAND} -DCMAKE_MAKE_PROGRAM=gmake)
  endif()
endif()

set(LUV_BUILD_COMMAND ${CMAKE_COMMAND} --build . --config $<CONFIG>)
set(LUV_INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config $<CONFIG>)

BuildLuv(PATCH_COMMAND ${LUV_PATCH_COMMAND}
  CONFIGURE_COMMAND ${LUV_CONFIGURE_COMMAND}
  BUILD_COMMAND ${LUV_BUILD_COMMAND}
  INSTALL_COMMAND ${LUV_INSTALL_COMMAND})

list(APPEND THIRD_PARTY_DEPS luv-static)
if(USE_BUNDLED_LUAJIT)
  add_dependencies(luv-static luajit)
elseif(USE_BUNDLED_LUA)
  add_dependencies(luv-static lua)
endif()
if(USE_BUNDLED_LIBUV)
  add_dependencies(luv-static libuv)
endif()
