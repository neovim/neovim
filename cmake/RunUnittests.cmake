get_filename_component(BUSTED_DIR ${BUSTED_PRG} PATH)
set(ENV{PATH} "${BUSTED_DIR}:$ENV{PATH}")
set(ENV{NVIM_TEST_LIB} ${NVIM_TEST_LIB})
set(ENV{TEST_INCLUDES} ${TEST_INCLUDES})
if(DEFINED ENV{TEST_FILE})
  set(TEST_DIR $ENV{TEST_FILE})
endif()

execute_process(
  COMMAND ${BUSTED_PRG} -o ${BUSTED_OUTPUT_TYPE} --pattern=.moon ${TEST_DIR}
  WORKING_DIRECTORY ${WORKING_DIR}
  RESULT_VARIABLE res)

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Unit tests failed.")
endif()
