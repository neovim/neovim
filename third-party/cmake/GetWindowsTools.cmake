# Download and install third party tools for windows
include(CMakeParseArguments)

# This is similar to the build recipes, but instead downloads a third party
# tool and installs it under the the DEPS_PREFIX.
function(GetTool)
  cmake_parse_arguments(_gettool
    "BUILD_IN_SOURCE"
    "TARGET"
    "INSTALL_COMMAND"
    ${ARGN})

  if(NOT _gettool_TARGET OR NOT _gettool_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass INSTALL_COMMAND and TARGET")
  endif()

  string(TOUPPER "${_gettool_TARGET}_URL" URL_VNAME)
  string(TOUPPER "${_gettool_TARGET}_SHA256" HASH_VNAME)
  set(URL ${${URL_VNAME}})
  set(HASH ${${HASH_VNAME}})
  if(NOT URL OR NOT HASH )
	  message(FATAL_ERROR "${URL_VNAME} and ${HASH_VNAME} must be set")
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
    INSTALL_COMMAND "${_gettool_INSTALL_COMMAND}")
  list(APPEND THIRD_PARTY_DEPS ${__gettool_TARGET})
endfunction()

GetTool(TARGET win32yank
  INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/bin
    COMMAND ${CMAKE_COMMAND} -E copy 
             ${DEPS_BUILD_DIR}/src/win32yank/win32yank.exe
	     ${DEPS_INSTALL_DIR}/bin)

include(TargetArch)
if("${ARCHITECTURE}" STREQUAL "X86_64")
  set(ARCH x64)
elseif(ARCHITECTURE STREQUAL "X86")
  set(ARCH ia32)
else()
  message(FATAL_ERROR "Unsupported architecture(${ARCHITECTURE}) cannot download winpty")
endif()
GetTool(TARGET winpty
  INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/bin
    COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/winpty/${ARCH}/bin/* -DTO=${DEPS_INSTALL_DIR}/bin/ -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake
    COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/winpty/include/* -DTO=${DEPS_INSTALL_DIR}/include/ -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake
    COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/winpty/${ARCH}/lib/* -DTO=${DEPS_INSTALL_DIR}/lib/ -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake)

