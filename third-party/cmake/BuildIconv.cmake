if(NOT WIN32)
  message(STATUS "Building iconv only need on Windows (skipping)")
  return()
endif()

# TODO: need for more toolchains
set(CONFIGURE_PARAMTER
  -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
  "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1} -fPIC"
  -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
  # Make sure we use the same generator, otherwise we may
  # accidentaly end up using different MSVC runtimes
  -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
  # Hack to avoid -rdynamic in Mingw
  -DCMAKE_SHARED_LIBRARY_LINK_C_FLAGS=""
)

ExternalProject_Add(iconv
  PREFIX ${DEPS_BUILD_DIR}
  URL ${ICONV_URL}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/iconv
  DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/iconv
    -DURL=${ICONV_URL}
    -DEXPECTED_SHA256=${ICONV_SHA256}
    -DTARGET=iconv
    -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ${CMAKE_COMMAND}
    ${CONFIGURE_PARAMTER}
    -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
    -DBUILD_STATIC=1
    -DBUILD_SHARED=0
  BUILD_COMMAND ${MAKE_PRG}
  INSTALL_COMMAND ${MAKE_PRG} install)

list(APPEND THIRD_PARTY_DEPS iconv)
