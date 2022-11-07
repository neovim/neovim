set(NVIM_VERSION
    "v${NVIM_VERSION_MAJOR}.${NVIM_VERSION_MINOR}.${NVIM_VERSION_PATCH}${NVIM_VERSION_PRERELEASE}")

execute_process(
  COMMAND git --git-dir=${NVIM_SOURCE_DIR}/.git --work-tree=${NVIM_SOURCE_DIR} describe --first-parent --dirty --always
  OUTPUT_VARIABLE GIT_TAG
  OUTPUT_STRIP_TRAILING_WHITESPACE
  RESULT_VARIABLE RES)

if(RES AND NOT RES EQUAL 0)
  message(STATUS "Using NVIM_VERSION: ${NVIM_VERSION}")
  file(WRITE "${OUTPUT}" "")
  return()
endif()

# `git describe` annotates the most recent tagged release; for pre-release
# builds we append that to the dev version.
if(NVIM_VERSION_PRERELEASE)
  string(REGEX REPLACE "^v[0-9]+.[0-9]+.[0-9]+-" "" NVIM_VERSION_GIT "${GIT_TAG}")
  string(REGEX REPLACE "^([0-9]+)-([a-z0-9]+)" "\\1+\\2" NVIM_VERSION_GIT "${NVIM_VERSION_GIT}")
  set(NVIM_VERSION "${NVIM_VERSION}-${NVIM_VERSION_GIT}")
endif()

set(NVIM_VERSION_STRING "#define NVIM_VERSION_MEDIUM \"${NVIM_VERSION}\"\n")

string(SHA1 CURRENT_VERSION_HASH "${NVIM_VERSION_STRING}")
if(EXISTS ${OUTPUT})
  file(SHA1 "${OUTPUT}" NVIM_VERSION_HASH)
endif()

if(NOT "${NVIM_VERSION_HASH}" STREQUAL "${CURRENT_VERSION_HASH}")
  message(STATUS "Using NVIM_VERSION: ${NVIM_VERSION}")
  file(WRITE "${OUTPUT}" "${NVIM_VERSION_STRING}")
endif()
