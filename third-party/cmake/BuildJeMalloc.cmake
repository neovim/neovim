if(WIN32)
  message(STATUS "Building jemalloc in Windows is not supported (skipping)")
  return()
endif()

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
    -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ${DEPS_BUILD_DIR}/src/jemalloc/configure
     CC=${DEPS_C_COMPILER} --prefix=${DEPS_INSTALL_DIR}
  BUILD_COMMAND ""
  INSTALL_COMMAND ${MAKE_PRG} install_include install_lib_static)

list(APPEND THIRD_PARTY_DEPS jemalloc)
