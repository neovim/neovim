include(CMakeParseArguments)

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
      -DTARGET=luv
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    PATCH_COMMAND "${_luv_PATCH_COMMAND}"
    CONFIGURE_COMMAND "${_luv_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_luv_BUILD_COMMAND}"
    INSTALL_COMMAND "${_luv_INSTALL_COMMAND}")
endfunction()

set(LUV_SRC_DIR ${DEPS_BUILD_DIR}/src/luv)
set(LUV_INCLUDE_FLAGS
  "-I${DEPS_INSTALL_DIR}/include -I${DEPS_INSTALL_DIR}/include/luajit-2.0")

# Replace luv default rockspec with the alternate one under the "rockspecs"
# directory
set(LUV_PATCH_COMMAND
    ${CMAKE_COMMAND} -E copy_directory ${LUV_SRC_DIR}/rockspecs ${LUV_SRC_DIR})

set(LUV_CONFIGURE_COMMAND_COMMON
  ${CMAKE_COMMAND} ${LUV_SRC_DIR}
  -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
  -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
  -DLUA_BUILD_TYPE=System
  -DWITH_SHARED_LIBUV=ON
  -DBUILD_SHARED_LIBS=OFF
  -DBUILD_MODULE=OFF)

if(USE_BUNDLED_LIBUV)
  set(LUV_CONFIGURE_COMMAND_COMMON
    ${LUV_CONFIGURE_COMMAND_COMMON}
    -DCMAKE_PREFIX_PATH=${DEPS_INSTALL_DIR})
endif()

if(MINGW AND CMAKE_CROSSCOMPILING)
  get_filename_component(TOOLCHAIN ${CMAKE_TOOLCHAIN_FILE} REALPATH)
  set(LUV_CONFIGURE_COMMAND
    ${LUV_CONFIGURE_COMMAND_COMMON}
    # Pass toolchain
    -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN}
    "-DCMAKE_C_FLAGS:STRING=${LUV_INCLUDE_FLAGS} -D_WIN32_WINNT=0x0600"
    # Hack to avoid -rdynamic in Mingw
    -DCMAKE_SHARED_LIBRARY_LINK_C_FLAGS="")
elseif(MSVC)
  set(LUV_CONFIGURE_COMMAND
    ${LUV_CONFIGURE_COMMAND_COMMON}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    # Same as Unix without fPIC
    "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1} ${LUV_INCLUDE_FLAGS}"
    # Make sure we use the same generator, otherwise we may
    # accidentaly end up using different MSVC runtimes
    -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
    # Use static runtime
    -DCMAKE_C_FLAGS_DEBUG="-MTd"
    -DCMAKE_C_FLAGS_RELEASE="-MT")
else()
  set(LUV_CONFIGURE_COMMAND
    ${LUV_CONFIGURE_COMMAND_COMMON}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1} ${LUV_INCLUDE_FLAGS} -fPIC")
endif()

if(CMAKE_GENERATOR MATCHES "Unix Makefiles" AND
        (CMAKE_SYSTEM_NAME MATCHES ".*BSD" OR CMAKE_SYSTEM_NAME MATCHES "DragonFly"))
        set(LUV_BUILD_COMMAND ${CMAKE_COMMAND}
          "-DLUA_COMPAT53_DIR=${DEPS_BUILD_DIR}/src/lua-compat-5.3"
          "-DCMAKE_MAKE_PROGRAM=gmake" --build .)
else()
  set(LUV_BUILD_COMMAND ${CMAKE_COMMAND}
    "-DLUA_COMPAT53_DIR=${DEPS_BUILD_DIR}/src/lua-compat-5.3" --build .)
endif()
set(LUV_INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install)

BuildLuv(PATCH_COMMAND ${LUV_PATCH_COMMAND}
  CONFIGURE_COMMAND ${LUV_CONFIGURE_COMMAND}
  BUILD_COMMAND ${LUV_BUILD_COMMAND}
  INSTALL_COMMAND ${LUV_INSTALL_COMMAND})

list(APPEND THIRD_PARTY_DEPS luv-static)
if(USE_BUNDLED_LUAJIT)
  add_dependencies(luv-static luajit)
endif()
if(USE_BUNDLED_LIBUV)
  add_dependencies(luv-static libuv)
endif()
