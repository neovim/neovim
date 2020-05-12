# Download and install binary dependencies for windows
include(CMakeParseArguments)

# This is similar to the build recipes, but instead downloads a third party
# binary and installs it under the DEPS_PREFIX.
# The INSTALL_COMMAND is executed in the folder where downloaded files are
# extracted and the ${DEPS_INSTALL_DIR} holds the path to the third-party
# install root.
function(GetBinaryDep)
  cmake_parse_arguments(_gettool
    "BUILD_IN_SOURCE"
    "TARGET"
    "INSTALL_COMMAND"
    ${ARGN})

  if(NOT _gettool_TARGET OR NOT _gettool_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass INSTALL_COMMAND and TARGET")
  endif()

  string(TOUPPER "${_gettool_TARGET}_URL" URL_VARNAME)
  string(TOUPPER "${_gettool_TARGET}_SHA256" HASH_VARNAME)
  set(URL ${${URL_VARNAME}})
  set(HASH ${${HASH_VARNAME}})
  if(NOT URL OR NOT HASH )
    message(FATAL_ERROR "${URL_VARNAME} and ${HASH_VARNAME} must be set")
  endif()

  ExternalProject_Add(${_gettool_TARGET}
    PREFIX ${DEPS_BUILD_DIR}
    URL ${URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}
      -DURL=${URL}
      -DEXPECTED_SHA256=${HASH}
      -DTARGET=${_gettool_TARGET}
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/bin
    COMMAND "${_gettool_INSTALL_COMMAND}")
  list(APPEND THIRD_PARTY_DEPS ${__gettool_TARGET})
endfunction()
