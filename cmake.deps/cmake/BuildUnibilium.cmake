get_externalproject_options(unibilium ${DEPS_IGNORE_SHA})
ExternalProject_Add(unibilium
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/unibilium
  CMAKE_ARGS ${DEPS_CMAKE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})
