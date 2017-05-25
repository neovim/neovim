set(IGNORE_FILES "${TEST_DIR}/*/preload.lua")

execute_process(
  COMMAND ${LUACHECK_PRG} -q ${TEST_DIR} --exclude-files ${IGNORE_FILES}
  WORKING_DIRECTORY ${TEST_DIR}
  ERROR_VARIABLE err
  RESULT_VARIABLE res
  ${EXTRA_ARGS})

if(NOT res EQUAL 0)
  message(STATUS "Output to stderr:\n${err}")
  message(FATAL_ERROR "Linting tests failed with error: ${res}.")
endif()
