include(CMakeParseArguments)

# BuildLibuv(TARGET targetname CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build libuv, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildLibuv)
  cmake_parse_arguments(_libuv
    "BUILD_IN_SOURCE"
    "TARGET"
    "CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})

  if(NOT _libuv_CONFIGURE_COMMAND AND NOT _libuv_BUILD_COMMAND
        AND NOT _libuv_INSTALL_COMMAND)
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
    BUILD_IN_SOURCE ${_libuv_BUILD_IN_SOURCE}
    CONFIGURE_COMMAND "${_libuv_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_libuv_BUILD_COMMAND}"
    INSTALL_COMMAND "${_libuv_INSTALL_COMMAND}")
endfunction()

set(UNIX_CFGCMD sh ${DEPS_BUILD_DIR}/src/libuv/autogen.sh &&
  ${DEPS_BUILD_DIR}/src/libuv/configure --with-pic --disable-shared
  --prefix=${DEPS_INSTALL_DIR} --libdir=${DEPS_INSTALL_DIR}/lib
  CC=${DEPS_C_COMPILER})

if(UNIX)
  BuildLibuv(
    CONFIGURE_COMMAND ${UNIX_CFGCMD}
    INSTALL_COMMAND ${MAKE_PRG} V=1 install)

elseif(MINGW AND CMAKE_CROSSCOMPILING)
  # Build libuv for the host
  BuildLibuv(TARGET libuv_host
    CONFIGURE_COMMAND sh ${DEPS_BUILD_DIR}/src/libuv_host/autogen.sh && ${DEPS_BUILD_DIR}/src/libuv_host/configure --with-pic --disable-shared --prefix=${HOSTDEPS_INSTALL_DIR} CC=${HOST_C_COMPILER}
    INSTALL_COMMAND ${MAKE_PRG} V=1 install)

  # Build libuv for the target
  BuildLibuv(
    CONFIGURE_COMMAND ${UNIX_CFGCMD} --host=${CROSS_TARGET}
    INSTALL_COMMAND ${MAKE_PRG} V=1 install)

elseif(MINGW)

  # Native MinGW
  BuildLibUv(BUILD_IN_SOURCE
    BUILD_COMMAND ${CMAKE_MAKE_PROGRAM} -f Makefile.mingw
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/lib
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/libuv/libuv.a ${DEPS_INSTALL_DIR}/lib
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/include
      COMMAND ${CMAKE_COMMAND} -E copy_directory ${DEPS_BUILD_DIR}/src/libuv/include ${DEPS_INSTALL_DIR}/include
    )

elseif(WIN32 AND MSVC)

  find_package(PythonInterp 2.6 REQUIRED)
  if(NOT PYTHONINTERP_FOUND OR PYTHON_VERSION_MAJOR GREATER 2)
    message(FATAL_ERROR "Python2 is required to build libuv on windows, use -DPYTHON_EXECUTABLE to set a python interpreter")
  endif()

  string(FIND ${CMAKE_GENERATOR} Win64 VS_WIN64)
  if(VS_WIN64 EQUAL -1)
    set(VS_ARCH x86)
  else()
    set(VS_ARCH x64)
  endif()
  string(TOLOWER ${CMAKE_BUILD_TYPE} LOWERCASE_BUILD_TYPE)
  set(UV_OUTPUT_DIR ${DEPS_BUILD_DIR}/src/libuv/${CMAKE_BUILD_TYPE})
  BuildLibUv(
    BUILD_COMMAND set PYTHON=${PYTHON_EXECUTABLE} COMMAND ${DEPS_BUILD_DIR}/src/libuv/vcbuild.bat shared ${LOWERCASE_BUILD_TYPE} ${VS_ARCH}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/lib
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/bin
      COMMAND ${CMAKE_COMMAND} -E copy ${UV_OUTPUT_DIR}/libuv.lib ${DEPS_INSTALL_DIR}/lib
      # Some applications (lua-client/luarocks) look for uv.lib instead of libuv.lib
      COMMAND ${CMAKE_COMMAND} -E copy ${UV_OUTPUT_DIR}/libuv.lib ${DEPS_INSTALL_DIR}/lib/uv.lib
      COMMAND ${CMAKE_COMMAND} -E copy ${UV_OUTPUT_DIR}/libuv.dll ${DEPS_INSTALL_DIR}/bin/
      COMMAND ${CMAKE_COMMAND} -E copy ${UV_OUTPUT_DIR}/libuv.dll ${DEPS_INSTALL_DIR}/bin/uv.dll
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/include
      COMMAND ${CMAKE_COMMAND} -E copy_directory ${DEPS_BUILD_DIR}/src/libuv/include ${DEPS_INSTALL_DIR}/include)

else()
  message(FATAL_ERROR "Trying to build libuv in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

list(APPEND THIRD_PARTY_DEPS libuv)
