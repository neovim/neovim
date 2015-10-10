if(WIN32)
  message(STATUS "Building libvterm in Windows is not supported (skipping)")
  return()
endif()

ExternalProject_Add(libvterm
  PREFIX ${DEPS_BUILD_DIR}
  URL ${LIBVTERM_URL}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libvterm
  DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libvterm
    -DURL=${LIBVTERM_URL}
    -DEXPECTED_SHA256=${LIBVTERM_SHA256}
    -DTARGET=libvterm
    -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  CONFIGURE_COMMAND ""
  BUILD_IN_SOURCE 1
  BUILD_COMMAND ""
  INSTALL_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                              PREFIX=${DEPS_INSTALL_DIR}
                              CFLAGS=-fPIC
                              install)

list(APPEND THIRD_PARTY_DEPS libvterm)
