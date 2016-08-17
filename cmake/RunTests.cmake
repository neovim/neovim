get_filename_component(BUSTED_DIR ${BUSTED_PRG} PATH)
set(ENV{PATH} "${BUSTED_DIR}:$ENV{PATH}")

set(ENV{VIMRUNTIME} ${WORKING_DIR}/runtime)
set(ENV{NVIM_RPLUGIN_MANIFEST} ${WORKING_DIR}/Xtest_rplugin_manifest)
set(ENV{XDG_CONFIG_HOME} ${WORKING_DIR}/Xtest_xdg/config)
set(ENV{XDG_DATA_HOME} ${WORKING_DIR}/Xtest_xdg/share)

if(NVIM_PRG)
  set(ENV{NVIM_PROG} "${NVIM_PRG}")
endif()

if(DEFINED ENV{TEST_FILE})
  set(TEST_PATH "$ENV{TEST_FILE}")
else()
  set(TEST_PATH "${TEST_DIR}/${TEST_TYPE}")
endif()

if(BUSTED_OUTPUT_TYPE STREQUAL junit)
  set(EXTRA_ARGS OUTPUT_FILE ${BUILD_DIR}/${TEST_TYPE}test-junit.xml)
endif()

if(DEFINED ENV{TEST_TAG})
  set(TEST_TAG "--tags=$ENV{TEST_TAG}")
endif()

if(DEFINED ENV{TEST_FILTER})
  set(TEST_TAG "--filter=$ENV{TEST_FILTER}")
endif()

execute_process(
  COMMAND ${BUSTED_PRG} ${TEST_TAG} ${TEST_FILTER} -v -o ${BUSTED_OUTPUT_TYPE}
    --lua=${LUA_PRG} --lazy --helper=${TEST_DIR}/${TEST_TYPE}/preload.lua
    --lpath=${BUILD_DIR}/?.lua ${TEST_PATH}
  WORKING_DIRECTORY ${WORKING_DIR}
  ERROR_VARIABLE err
  RESULT_VARIABLE res
  ${EXTRA_ARGS})

file(REMOVE ${WORKING_DIR}/Xtest_rplugin_manifest)
file(REMOVE_RECURSE ${WORKING_DIR}/Xtest_xdg)

if(NOT res EQUAL 0)
  message(STATUS "Output to stderr:\n${err}")
  message(FATAL_ERROR "Running ${TEST_TYPE} tests failed with error: ${res}.")
endif()
