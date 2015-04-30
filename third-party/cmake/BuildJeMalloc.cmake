ExternalProject_Add(jemalloc
  PREFIX ${DEPS_BUILD_DIR}
  URL ${JEMALLOC_URL}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/jemalloc
  DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/jemalloc
    -DURL=${JEMALLOC_URL}
    -DEXPECTED_SHA256=${JEMALLOC_SHA256}
    -DTARGET=jemalloc
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND sh ${DEPS_BUILD_DIR}/src/jemalloc/autogen.sh &&
    ${DEPS_BUILD_DIR}/src/jemalloc/configure --enable-cc-silence
    CC=${DEPS_C_COMPILER} --prefix=${DEPS_INSTALL_DIR}
  BUILD_COMMAND ""
  INSTALL_COMMAND ${MAKE_PRG} install_include install_lib)

list(APPEND THIRD_PARTY_DEPS jemalloc)
