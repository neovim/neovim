
ExternalProject_Add(luajit
  PREFIX ${DEPS_BUILD_DIR}
  URL ${LUAJIT_URL}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luajit
  DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/luajit
    -DURL=${LUAJIT_URL}
    -DEXPECTED_SHA256=${LUAJIT_SHA256}
    -DTARGET=luajit
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  CONFIGURE_COMMAND ""
  BUILD_IN_SOURCE 1
  BUILD_COMMAND ""
  INSTALL_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                              PREFIX=${DEPS_INSTALL_DIR}
                              CFLAGS=-fPIC
                              CFLAGS+=-DLUAJIT_DISABLE_JIT
                              CFLAGS+=-DLUA_USE_APICHECK
                              CFLAGS+=-DLUA_USE_ASSERT
                              CCDEBUG+=-g
                              BUILDMODE=static
                              install)
list(APPEND THIRD_PARTY_DEPS luajit)

