get_externalproject_options(ghostty ${DEPS_IGNORE_SHA})

set(GHOSTTY_CMAKE_ARGS ${DEPS_CMAKE_ARGS})

# Ghostty's Debug mode makes terminal tests slow enough for check_term_rep() in
# test/functional/terminal/buffer_spec.lua to hit a 30-second timeout on some CI
# runners, so we always build in release mode.
list(APPEND GHOSTTY_CMAKE_ARGS -D CMAKE_BUILD_TYPE=RelWithDebInfo)

if(APPLE)
  list(APPEND GHOSTTY_CMAKE_ARGS -DGHOSTTY_ZIG_BUILD_FLAGS=-Demit-xcframework=false)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  list(APPEND GHOSTTY_CMAKE_ARGS -DGHOSTTY_ZIG_BUILD_FLAGS=-Dcpu=baseline)
endif()

ExternalProject_Add(ghostty
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/ghostty
  CMAKE_ARGS ${GHOSTTY_CMAKE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})
