get_externalproject_options(ghostty ${DEPS_IGNORE_SHA})
ExternalProject_Add(ghostty
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/ghostty
  CMAKE_ARGS ${DEPS_CMAKE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})
