file(TO_CMAKE_PATH
  "$ENV{DESTDIR}/${CMAKE_INSTALL_PREFIX}/share/nvim/runtime/doc"
  HELPTAGS_WORKING_DIRECTORY)

message(STATUS "Generating helptags in ${HELPTAGS_WORKING_DIRECTORY}.")

execute_process(
  COMMAND "${CMAKE_CURRENT_BINARY_DIR}/bin/nvim"
    -u NONE
    -esX
    -c "helptags ++t ."
    -c quit
  WORKING_DIRECTORY "${HELPTAGS_WORKING_DIRECTORY}"
  OUTPUT_VARIABLE err
  ERROR_VARIABLE err
  RESULT_VARIABLE res)

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Generating helptags failed: ${err}")
endif()
