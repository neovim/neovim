include(CMakeParseArguments)

# BuildLibuv(TARGET targetname CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build libuv, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildLibuv)
  cmake_parse_arguments(_libuv
    ""
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
    CONFIGURE_COMMAND "${_libuv_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_libuv_BUILD_COMMAND}"
    INSTALL_COMMAND "${_libuv_INSTALL_COMMAND}")
endfunction()

set(UNIX_CFGCMD sh ${DEPS_BUILD_DIR}/src/libuv/autogen.sh &&
  ${DEPS_BUILD_DIR}/src/libuv/configure --with-pic --disable-shared
  --prefix=${DEPS_INSTALL_DIR} --libdir=${DEPS_INSTALL_DIR}/lib
  CC=${DEPS_C_COMPILER})

if(UNIX)
  BuildLibUv(
    CONFIGURE_COMMAND ${UNIX_CFGCMD}
    INSTALL_COMMAND ${MAKE_PRG} V=1 install)

elseif(MINGW AND CMAKE_CROSSCOMPILING)
  # Build libuv for the host
  BuildLibUv(TARGET libuv_host
    CONFIGURE_COMMAND sh ${DEPS_BUILD_DIR}/src/libuv_host/autogen.sh && ${DEPS_BUILD_DIR}/src/libuv_host/configure --with-pic --disable-shared --prefix=${HOSTDEPS_INSTALL_DIR} CC=${HOST_C_COMPILER}
    INSTALL_COMMAND ${MAKE_PRG} V=1 install)

  # Build libuv for the target
  BuildLibUv(
    CONFIGURE_COMMAND ${UNIX_CFGCMD} --host=${CROSS_TARGET}
    INSTALL_COMMAND ${MAKE_PRG} V=1 install)


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
  BuildLibUv(
    # By default this creates Debug builds
    BUILD_COMMAND set PYTHON=${PYTHON_EXECUTABLE} COMMAND ${DEPS_BUILD_DIR}/src/libuv/vcbuild.bat static debug ${VS_ARCH}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/lib
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/libuv/Debug/lib/libuv.lib ${DEPS_INSTALL_DIR}/lib
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/include
      COMMAND ${CMAKE_COMMAND} -E copy_directory ${DEPS_BUILD_DIR}/src/libuv/include ${DEPS_INSTALL_DIR}/include)

else()
  message(FATAL_ERROR "Trying to build libuv in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

list(APPEND THIRD_PARTY_DEPS libuv)
