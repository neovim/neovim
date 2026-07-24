get_externalproject_options(ghostty ${DEPS_IGNORE_SHA})

set(GHOSTTY_CMAKE_ARGS ${DEPS_CMAKE_ARGS})
if(APPLE)
  list(APPEND GHOSTTY_CMAKE_ARGS -DGHOSTTY_ZIG_BUILD_FLAGS=-Demit-xcframework=false)
endif()

ExternalProject_Add(ghostty
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/ghostty
  CMAKE_ARGS ${GHOSTTY_CMAKE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})
