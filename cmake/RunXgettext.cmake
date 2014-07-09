set(ENV{OLD_PO_FILE_INPUT} yes)
set(ENV{OLD_PO_FILE_OUTPUT} yes)

list(SORT SOURCES)

execute_process(
  COMMAND ${XGETTEXT_PRG} -o ${POT_FILE} --default-domain=nvim
      --add-comments --keyword=_ --keyword=N_ -D ${SEARCH_DIR}
      ${SOURCES}
  ERROR_VARIABLE err
  RESULT_VARIABLE res)
if(NOT res EQUAL 0)
  message(FATAL_ERROR "xgettext failed to run correctly: ${err}")
endif()
