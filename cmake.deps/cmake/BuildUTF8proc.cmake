get_externalproject_options(utf8proc ${DEPS_IGNORE_SHA})
ExternalProject_Add(utf8proc
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/utf8proc
  CMAKE_ARGS ${DEPS_CMAKE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})
