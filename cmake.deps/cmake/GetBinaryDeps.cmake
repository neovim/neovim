# This is similar to the build recipes, but instead downloads a third party
# binary and installs it under the DEPS_PREFIX.
# The INSTALL_COMMAND is executed in the folder where downloaded files are
# extracted and the ${DEPS_INSTALL_DIR} holds the path to the third-party
# install root.
function(GetBinaryDep)
  cmake_parse_arguments(_gettool
    ""
    "TARGET"
    "INSTALL_COMMAND"
    ${ARGN})

  string(TOUPPER "${_gettool_TARGET}_URL" URL_VARNAME)
  string(TOUPPER "${_gettool_TARGET}_SHA256" HASH_VARNAME)
  set(URL ${${URL_VARNAME}})
  set(HASH ${${HASH_VARNAME}})

  ExternalProject_Add(${_gettool_TARGET}
    URL ${URL}
    URL_HASH SHA256=${HASH}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    BUILD_COMMAND ""
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_BIN_DIR}
    COMMAND "${_gettool_INSTALL_COMMAND}"
    DOWNLOAD_NO_PROGRESS TRUE)
endfunction()

# Download executable and move it to DEPS_BIN_DIR
function(GetExecutable)
  cmake_parse_arguments(ARG
    ""
    "TARGET"
    ""
    ${ARGN})

  string(TOUPPER "${ARG_TARGET}_URL" URL_VARNAME)
  string(TOUPPER "${ARG_TARGET}_SHA256" HASH_VARNAME)
  set(URL ${${URL_VARNAME}})
  set(HASH ${${HASH_VARNAME}})

  ExternalProject_Add(${ARG_TARGET}
    URL ${URL}
    URL_HASH SHA256=${HASH}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}
    DOWNLOAD_NO_EXTRACT TRUE
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_BIN_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy <DOWNLOADED_FILE> ${DEPS_BIN_DIR}
    DOWNLOAD_NO_PROGRESS TRUE)
endfunction()
