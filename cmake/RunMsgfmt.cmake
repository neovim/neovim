set(ENV{OLD_PO_FILE_INPUT} yes)

execute_process(
  COMMAND ${MSGFMT_PRG} -o ${MO_FILE} ${PO_FILE}
  ERROR_VARIABLE err
  RESULT_VARIABLE res)
if(NOT res EQUAL 0)
  message(FATAL_ERROR "msgfmt failed to run correctly: ${err}")
endif()
