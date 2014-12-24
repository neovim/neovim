get_filename_component(LINT_DIR ${LINT_DIR} ABSOLUTE)
get_filename_component(LINT_PREFIX ${LINT_DIR} PATH)
file(GLOB_RECURSE LINT_FILES ${LINT_DIR}/*.c ${LINT_DIR}/*.h)

if(LINT_IGNORE_FILE)
  file(READ ${LINT_IGNORE_FILE} LINT_IGNORED_FILES)
  string(REPLACE "\n" ";" LINT_IGNORED_FILES ${LINT_IGNORED_FILES})
  message(STATUS "Ignoring the following files for linting:")
  foreach(ignore_file ${LINT_IGNORED_FILES})
    message(STATUS "${ignore_file}")
    list(REMOVE_ITEM LINT_FILES "${LINT_PREFIX}/${ignore_file}")
  endforeach()
endif()

execute_process(
  COMMAND ${LINT_PRG} ${LINT_FILES}
  RESULT_VARIABLE res)

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Linting failed: ${res}.")
endif()
