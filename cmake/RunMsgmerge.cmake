set(ENV{OLD_PO_FILE_INPUT} yes)
set(ENV{OLD_PO_FILE_OUTPUT} yes)

execute_process(
  COMMAND ${MSGMERGE_PRG} -q --update --backup=none --sort-by-file
      ${PO_FILE} ${POT_FILE}
  ERROR_VARIABLE err
  RESULT_VARIABLE res)
if(NOT res EQUAL 0)
  message(FATAL_ERROR "msgmerge failed to run correctly: ${err}")
endif()
