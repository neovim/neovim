# BuildLibuv(TARGET targetname CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build libuv, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildLibuv)
  cmake_parse_arguments(_libuv
    ""
    ""
    "PATCH_COMMAND;CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})

  if(NOT _libuv_CONFIGURE_COMMAND AND NOT _libuv_BUILD_COMMAND AND NOT _libuv_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND, BUILD_COMMAND, INSTALL_COMMAND")
  endif()
  if(NOT _libuv_TARGET)
    set(_libuv_TARGET "libuv")
  endif()

  ExternalProject_Add(${_libuv_TARGET}
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LIBUV_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libuv
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libuv
      -DURL=${LIBUV_URL}
      -DEXPECTED_SHA256=${LIBUV_SHA256}
      -DTARGET=${_libuv_TARGET}
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    PATCH_COMMAND "${_libuv_PATCH_COMMAND}"
    CONFIGURE_COMMAND "${_libuv_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_libuv_BUILD_COMMAND}"
    INSTALL_COMMAND "${_libuv_INSTALL_COMMAND}")
endfunction()

set(LIBUV_CONFIGURE_COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/libuv
  -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
  -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
  -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
  -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
  -DBUILD_SHARED_LIBS=${BUILD_SHARED}
  -DLIBUV_BUILD_TESTS=OFF)

if(UNIX)
  list(APPEND LIBUV_CONFIGURE_COMMAND
    "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1} -fPIC")
  list(APPEND LIBUV_CONFIGURE_COMMAND
    -DCMAKE_INSTALL_LIBDIR=${DEPS_INSTALL_DIR}/lib)
endif()

if(MINGW)
  set(LIBUV_PATCH_COMMAND
    ${GIT_EXECUTABLE} -C ${DEPS_BUILD_DIR}/src/libuv init
    COMMAND ${GIT_EXECUTABLE} -C ${DEPS_BUILD_DIR}/src/libuv apply --ignore-whitespace
      ${CMAKE_CURRENT_SOURCE_DIR}/patches/libuv-disable-typedef-MinGW.patch)
endif()

set(LIBUV_BUILD_COMMAND ${CMAKE_COMMAND} --build . --config ${CMAKE_BUILD_TYPE})
if(MSVC)
  # Move the file because the installation destination by upstream
  # CMakeLists.txt is inappropriate.
  set(LIBUV_INSTALL_COMMAND ${CMAKE_COMMAND}
    --build . --target install --config ${CMAKE_BUILD_TYPE}
    COMMAND ${CMAKE_COMMAND} -E rename
      ${DEPS_INSTALL_DIR}/lib/${CMAKE_BUILD_TYPE}/uv.lib ${DEPS_INSTALL_DIR}/lib/uv.lib
    COMMAND ${CMAKE_COMMAND} -E rename
      ${DEPS_INSTALL_DIR}/lib/${CMAKE_BUILD_TYPE}/uv_a.lib ${DEPS_INSTALL_DIR}/lib/uv_a.lib
    COMMAND ${CMAKE_COMMAND} -E make_directory
      ${DEPS_INSTALL_DIR}/bin
    COMMAND ${CMAKE_COMMAND} -E rename
      ${DEPS_INSTALL_DIR}/lib/${CMAKE_BUILD_TYPE}/uv.dll ${DEPS_INSTALL_DIR}/bin/uv.dll)
else()
  # If a shared library exists, it will be used by luarocks to install luv.
  # After that, there are environments where the problem occurs because the
  # shared library is deleted by clean-shared-librares. To prevent that, delete
  # the shared library in advance here.
  set(LIBUV_INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE}
    COMMAND ${CMAKE_COMMAND}
      -DREMOVE_FILE_GLOB=${DEPS_INSTALL_DIR}/lib/${CMAKE_SHARED_LIBRARY_PREFIX}uv${CMAKE_SHARED_LIBRARY_SUFFIX}*
      -P ${PROJECT_SOURCE_DIR}/cmake/RemoveFiles.cmake)
endif()

if(MINGW AND CMAKE_CROSSCOMPILING)
  get_filename_component(TOOLCHAIN ${CMAKE_TOOLCHAIN_FILE} REALPATH)
  set(LIBUV_CONFIGURE_COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/libuv
    -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
    # Pass toolchain
    -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    # Hack to avoid -rdynamic in Mingw
    -DCMAKE_SHARED_LIBRARY_LINK_C_FLAGS="")
endif()

BuildLibuv(CONFIGURE_COMMAND ${LIBUV_CONFIGURE_COMMAND}
  PATCH_COMMAND ${LIBUV_PATCH_COMMAND}
  BUILD_COMMAND ${LIBUV_BUILD_COMMAND}
  INSTALL_COMMAND ${LIBUV_INSTALL_COMMAND})

list(APPEND THIRD_PARTY_DEPS libuv)
