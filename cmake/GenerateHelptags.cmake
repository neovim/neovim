message(STATUS "Generating helptags.")

execute_process(
  COMMAND "${CMAKE_CURRENT_BINARY_DIR}/bin/nvim"
    -u NONE
    -esX
    -c "helptags ++t ."
    -c quit
  WORKING_DIRECTORY "${CMAKE_INSTALL_PREFIX}/share/nvim/runtime/doc"
  ERROR_VARIABLE err
  RESULT_VARIABLE res)

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Generating helptags failed: ${err}")
endif()
