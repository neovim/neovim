execute_process(
  COMMAND ${MAKE_PRG} install
  RESULT_VARIABLE res)

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Installing msgpack failed.")
endif()

file(GLOB FILES_TO_REMOVE ${REMOVE_FILE_GLOB})
if(FILES_TO_REMOVE)
  file(REMOVE ${FILES_TO_REMOVE})
endif()
