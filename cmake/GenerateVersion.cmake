# Handle generating version from Git.
set(use_git_version 0)
if(NVIM_VERSION_MEDIUM)
  message(STATUS "USING NVIM_VERSION_MEDIUM: ${NVIM_VERSION_MEDIUM}")
  return()
endif()

find_program(GIT_EXECUTABLE git)
if(NOT GIT_EXECUTABLE)
  message(AUTHOR_WARNING "Skipping version-string generation (cannot find git)")
  file(WRITE "${OUTPUT}" "")
  return()
endif()

execute_process(
  COMMAND git describe --first-parent --tags --always --dirty
  OUTPUT_VARIABLE GIT_TAG
  ERROR_VARIABLE ERR
  RESULT_VARIABLE RES
)

if("${RES}" EQUAL 1)
  if(EXISTS ${OUTPUT})
    message(STATUS "Unable to extract version-string from git: keeping the last known version")
  else()
    # this will only be executed once since the file will get generated afterwards
    message(AUTHOR_WARNING "Git tag extraction failed with: " "${ERR}")
    file(WRITE "${OUTPUT}" "")
  endif()
  return()
endif()

string(STRIP "${GIT_TAG}" GIT_TAG)
string(REGEX REPLACE "^v[0-9]+.[0-9]+.[0-9]+-" "" NVIM_VERSION_GIT "${GIT_TAG}")
set(NVIM_VERSION_MEDIUM
    "v${NVIM_VERSION_MAJOR}.${NVIM_VERSION_MINOR}.${NVIM_VERSION_PATCH}-dev-${NVIM_VERSION_GIT}"
)
set(NVIM_VERSION_STRING "#define NVIM_VERSION_MEDIUM \"${NVIM_VERSION_MEDIUM}\"\n")
string(SHA1 CURRENT_VERSION_HASH "${NVIM_VERSION_STRING}")

if(EXISTS ${OUTPUT})
  file(SHA1 "${OUTPUT}" NVIM_VERSION_HASH)
endif()

if(NOT "${NVIM_VERSION_HASH}" STREQUAL "${CURRENT_VERSION_HASH}")
  message(STATUS "Updating NVIM_VERSION_MEDIUM: ${NVIM_VERSION_MEDIUM}")
  file(WRITE "${OUTPUT}" "${NVIM_VERSION_STRING}")
endif()
