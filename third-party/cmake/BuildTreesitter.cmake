ExternalProject_Add(treesitter
PREFIX ${DEPS_BUILD_DIR}
URL ${TREESITER_URL}
DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/treesitter
DOWNLOAD_COMMAND ${CMAKE_COMMAND}
  -DPREFIX=${DEPS_BUILD_DIR}
  -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/treesitter
  -DURL=${TREESITTER_URL}
  -DEXPECTED_SHA256=${TREESITTER_SHA256}
  -DTARGET=treesitter
  -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
  -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
CONFIGURE_COMMAND true
BUILD_COMMAND true
INSTALL_COMMAND true
)

ExternalProject_Add(treesitter-c
PREFIX ${DEPS_BUILD_DIR}
URL ${TREESITER_C_URL}
DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/treesitter-c
DOWNLOAD_COMMAND ${CMAKE_COMMAND}
  -DPREFIX=${DEPS_BUILD_DIR}
  -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/treesitter-c
  -DURL=${TREESITTER_C_URL}
  -DEXPECTED_SHA256=${TREESITTER_C_SHA256}
  -DTARGET=treesitter-c
  -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
  -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
CONFIGURE_COMMAND true
BUILD_COMMAND true
INSTALL_COMMAND true
)
