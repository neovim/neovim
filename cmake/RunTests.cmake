get_filename_component(BUSTED_DIR ${BUSTED_PRG} PATH)
set(ENV{PATH} "${BUSTED_DIR}:$ENV{PATH}")
if(DEFINED ENV{TEST_FILE})
  set(TEST_DIR $ENV{TEST_FILE})
endif()

if(TEST_TYPE STREQUAL "functional")
  execute_process(
    COMMAND python ${BUSTED_PRG} ${BUSTED_REAL_PRG} -v -o
      ${BUSTED_OUTPUT_TYPE} --lpath=${BUILD_DIR}/?.lua ${TEST_DIR}/functional
    WORKING_DIRECTORY ${WORKING_DIR}
    RESULT_VARIABLE res)
else()
  execute_process(
    COMMAND ${BUSTED_PRG} -v -o ${BUSTED_OUTPUT_TYPE}
      --lpath=${BUILD_DIR}/?.lua ${TEST_DIR}/unit
    WORKING_DIRECTORY ${WORKING_DIR}
    RESULT_VARIABLE res)
endif()

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Unit tests failed.")
endif()
