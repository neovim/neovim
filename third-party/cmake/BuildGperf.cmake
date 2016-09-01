# Gperf recipe. Gperf is only required when building Neovim, when
# cross compiling we still want to build for the HOST system, whenever
# writing a recipe that is meant for cross-compile, use the HOSTDEPS_* variables
# instead of DEPS_* - check the main CMakeLists.txt for a list.

# BuildGperf(CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build Gperf, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildGperf)
  cmake_parse_arguments(_gperf
    ""
    ""
    "CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})

  if(NOT _gperf_CONFIGURE_COMMAND AND NOT _gperf_BUILD_COMMAND
        AND NOT _gperf_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND, BUILD_COMMAND, INSTALL_COMMAND")
  endif()

  ExternalProject_Add(gperf
    PREFIX ${DEPS_BUILD_DIR}
    URL ${GPERF_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/gperf
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/gperf
      -DURL=${GPERF_URL}
      -DEXPECTED_SHA256=${GPERF_SHA256}
      -DTARGET=gperf
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND "${_gperf_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_gperf_BUILD_COMMAND}"
    INSTALL_COMMAND "${_gperf_INSTALL_COMMAND}")
endfunction()

set(GPERF_BUILDARGS CC=${HOSTDEPS_C_COMPILER} LD=${HOSTDEPS_C_COMPILER})

if(UNIX OR (MINGW AND CMAKE_CROSSCOMPILING))

  BuildGperf(
    CONFIGURE_COMMAND ${DEPS_BUILD_DIR}/src/gperf/configure
      --prefix=${HOSTDEPS_INSTALL_DIR}
    INSTALL_COMMAND ${MAKE_PRG} install)

else()
  message(FATAL_ERROR "Trying to build gperf in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

