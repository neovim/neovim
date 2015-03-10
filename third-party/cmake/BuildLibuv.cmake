
ExternalProject_Add(libuv
  PREFIX ${DEPS_BUILD_DIR}
  URL ${LIBUV_URL}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libuv
  DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libuv
    -DURL=${LIBUV_URL}
    -DEXPECTED_SHA256=${LIBUV_SHA256}
    -DTARGET=libuv
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  CONFIGURE_COMMAND sh ${DEPS_BUILD_DIR}/src/libuv/autogen.sh &&
    ${DEPS_BUILD_DIR}/src/libuv/configure --with-pic --disable-shared
      --prefix=${DEPS_INSTALL_DIR} --libdir=${DEPS_INSTALL_DIR}/lib
      CC=${DEPS_C_COMPILER}
  INSTALL_COMMAND ${MAKE_PRG} install)
list(APPEND THIRD_PARTY_DEPS libuv)

