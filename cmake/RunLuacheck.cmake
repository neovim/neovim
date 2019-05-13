set(LUACHECK_ARGS -q "${LUAFILES_DIR}")
if(DEFINED IGNORE_PATTERN)
  list(APPEND LUACHECK_ARGS --exclude-files "${LUAFILES_DIR}/${IGNORE_PATTERN}")
endif()
if(DEFINED CHECK_PATTERN)
  list(APPEND LUACHECK_ARGS --include-files "${LUAFILES_DIR}/${CHECK_PATTERN}")
endif()
if(DEFINED READ_GLOBALS)
  list(APPEND LUACHECK_ARGS --read-globals "${READ_GLOBALS}")
endif()

execute_process(
  COMMAND "${LUACHECK_PRG}" ${LUACHECK_ARGS}
  WORKING_DIRECTORY "${LUAFILES_DIR}"
  ERROR_VARIABLE err
  RESULT_VARIABLE res
)

if(NOT res EQUAL 0)
  message(STATUS "Output to stderr:\n${err}")
  message(FATAL_ERROR "Linting tests failed with error: ${res}")
endif()
