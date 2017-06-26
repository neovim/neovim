find_package(PkgConfig REQUIRED)

if(WIN32)
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
  CONFIGURE_COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/libtermkey
    -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
    # Pass toolchain
    -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    # Hack to avoid -rdynamic in Mingw
    -DCMAKE_SHARED_LIBRARY_LINK_C_FLAGS=""
    -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
  BUILD_COMMAND ${CMAKE_COMMAND} --build . --config ${CMAKE_BUILD_TYPE}
  INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE})
else()
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
endif()

list(APPEND THIRD_PARTY_DEPS libtermkey)
if(NOT WIN32)
  # There is no unibilium build recipe for Windows yet
  add_dependencies(libtermkey unibilium)
endif()
