get_filename_component(LINT_DIR ${LINT_DIR} ABSOLUTE)
get_filename_component(LINT_PREFIX ${LINT_DIR} PATH)
set(LINT_SUPPRESS_FILE "${LINT_PREFIX}/errors.json")

file(GLOB_RECURSE LINT_FILES ${LINT_DIR}/*.c ${LINT_DIR}/*.h)

set(LINT_ARGS)

if(LINT_SUPPRESS_URL)
  file(DOWNLOAD ${LINT_SUPPRESS_URL} ${LINT_SUPPRESS_FILE})
  list(APPEND LINT_ARGS "--suppress-errors=${LINT_SUPPRESS_FILE}")
endif()

foreach(lint_file ${LINT_FILES})
  file(RELATIVE_PATH lint_file "${LINT_PREFIX}" "${lint_file}")
  list(APPEND LINT_ARGS "${lint_file}")
endforeach()

execute_process(
  COMMAND ${LINT_PRG} ${LINT_ARGS}
  RESULT_VARIABLE res
  WORKING_DIRECTORY "${LINT_PREFIX}")

file(REMOVE ${LINT_SUPPRESS_FILE})

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Linting failed: ${res}.")
endif()
