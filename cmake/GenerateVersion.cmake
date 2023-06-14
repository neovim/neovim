set(NVIM_VERSION
    "v${NVIM_VERSION_MAJOR}.${NVIM_VERSION_MINOR}.${NVIM_VERSION_PATCH}${NVIM_VERSION_PRERELEASE}")

execute_process(
  COMMAND git --git-dir=${NVIM_SOURCE_DIR}/.git --work-tree=${NVIM_SOURCE_DIR} describe --first-parent --dirty --always
  OUTPUT_VARIABLE GIT_TAG
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_QUIET
  RESULT_VARIABLE RES)

if(RES)
  message(STATUS "Using NVIM_VERSION: ${NVIM_VERSION}")
  file(WRITE "${OUTPUT}" "")
  return()
endif()

# Extract build info: "v0.9.0-145-g0f9113907" => "g0f9113907"
string(REGEX REPLACE ".*\\-" "" NVIM_VERSION_BUILD "${GIT_TAG}")

# `git describe` annotates the most recent tagged release; for pre-release
# builds we append that to the dev version.
if(NVIM_VERSION_PRERELEASE)
  # Extract pre-release info: "v0.8.0-145-g0f9113907" => "145-g0f9113907"
  string(REGEX REPLACE "^v[0-9]+.[0-9]+.[0-9]+-" "" NVIM_VERSION_GIT "${GIT_TAG}")
  # Replace "-" with "+": "145-g0f9113907" => "145+g0f9113907"
  string(REGEX REPLACE "^([0-9]+)-([a-z0-9]+)" "\\1+\\2" NVIM_VERSION_GIT "${NVIM_VERSION_GIT}")
  set(NVIM_VERSION "${NVIM_VERSION}-${NVIM_VERSION_GIT}")
endif()

set(NVIM_VERSION_STRING "#define NVIM_VERSION_MEDIUM \"${NVIM_VERSION}\"\n#define NVIM_VERSION_BUILD \"${NVIM_VERSION_BUILD}\"\n")

string(SHA1 CURRENT_VERSION_HASH "${NVIM_VERSION_STRING}")
if(EXISTS ${OUTPUT})
  file(SHA1 "${OUTPUT}" NVIM_VERSION_HASH)
endif()

if(NOT "${NVIM_VERSION_HASH}" STREQUAL "${CURRENT_VERSION_HASH}")
  message(STATUS "Using NVIM_VERSION: ${NVIM_VERSION}")
  file(WRITE "${OUTPUT}" "${NVIM_VERSION_STRING}")
  if(WIN32)
    configure_file("${OUTPUT}" "${OUTPUT}" NEWLINE_STYLE UNIX)
  endif()
endif()
