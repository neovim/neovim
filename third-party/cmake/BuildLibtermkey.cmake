if(WIN32)
  message(STATUS "Building libtermkey in Windows is not supported (skipping)")
  return()
endif()
find_package(PkgConfig REQUIRED)

ExternalProject_Add(libtermkey
  PREFIX ${DEPS_BUILD_DIR}
  URL ${LIBTERMKEY_URL}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libtermkey
  DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libtermkey
    -DURL=${LIBTERMKEY_URL}
    -DEXPECTED_SHA256=${LIBTERMKEY_SHA256}
    -DTARGET=libtermkey
    -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  CONFIGURE_COMMAND ""
  BUILD_IN_SOURCE 1
  BUILD_COMMAND ""
  INSTALL_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                              PREFIX=${DEPS_INSTALL_DIR}
                              PKG_CONFIG_PATH=${DEPS_LIB_DIR}/pkgconfig
                              CFLAGS=-fPIC
                              install)

list(APPEND THIRD_PARTY_DEPS libtermkey)
add_dependencies(libtermkey unibilium)
