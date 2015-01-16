execute_process(
  COMMAND ${CMAKE_COMMAND} --build . --target install
  RESULT_VARIABLE res)

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Installing msgpack failed.")
endif()

file(GLOB_RECURSE FILES_TO_REMOVE ${REMOVE_FILE_GLOB})
if(FILES_TO_REMOVE)
  file(REMOVE ${FILES_TO_REMOVE})
endif()
