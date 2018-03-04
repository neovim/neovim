if(WIN32)
  message(STATUS "Building Unibilium in Windows is not supported (skipping)")
  return()
endif()

ExternalProject_Add(unibilium
  PREFIX ${DEPS_BUILD_DIR}
  URL ${UNIBILIUM_URL}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/unibilium
  DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/unibilium
    -DURL=${UNIBILIUM_URL}
    -DEXPECTED_SHA256=${UNIBILIUM_SHA256}
    -DTARGET=unibilium
    -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  CONFIGURE_COMMAND ""
  BUILD_IN_SOURCE 1
  BUILD_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                            PREFIX=${DEPS_INSTALL_DIR}
                            CFLAGS=-fPIC
                            ${DEFAULT_MAKE_CFLAGS}
  INSTALL_COMMAND ${MAKE_PRG} PREFIX=${DEPS_INSTALL_DIR} install)

list(APPEND THIRD_PARTY_DEPS unibilium)
