# HACK: This script is invoked with "cmake -P …" as a workaround to silence uncrustify.

# Split space-separated string into a cmake list, so that execute_process()
# will pass each file as individual arg to uncrustify.
string(REPLACE " " ";" NVIM_SOURCES ${NVIM_SOURCES})
string(REPLACE " " ";" NVIM_HEADERS ${NVIM_HEADERS})

execute_process(
  COMMAND ${UNCRUSTIFY_PRG} -c "${PROJECT_SOURCE_DIR}/src/uncrustify.cfg" -q --check ${NVIM_SOURCES} ${NVIM_HEADERS}
  OUTPUT_VARIABLE crusty_out
  ERROR_VARIABLE crusty_err
  RESULT_VARIABLE crusty_res)

if(NOT crusty_res EQUAL 0)
  message(FATAL_ERROR "crusty: ${crusty_res} ${crusty_err}")
endif()
