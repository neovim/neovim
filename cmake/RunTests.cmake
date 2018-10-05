# Set LC_ALL to meet expectations of some locale-sensitive tests.
set(ENV{LC_ALL} "en_US.UTF-8")

set(ENV{VIMRUNTIME} ${WORKING_DIR}/runtime)
set(ENV{NVIM_RPLUGIN_MANIFEST} ${WORKING_DIR}/Xtest_rplugin_manifest)
set(ENV{XDG_CONFIG_HOME} ${WORKING_DIR}/Xtest_xdg/config)
set(ENV{XDG_DATA_HOME} ${WORKING_DIR}/Xtest_xdg/share)

if(NOT DEFINED ENV{NVIM_LOG_FILE})
  set(ENV{NVIM_LOG_FILE} ${WORKING_DIR}/.nvimlog)
endif()

if(NVIM_PRG)
  set(ENV{NVIM_PRG} "${NVIM_PRG}")
endif()

if(DEFINED ENV{TEST_FILE})
  set(TEST_PATH "$ENV{TEST_FILE}")
else()
  set(TEST_PATH "${TEST_DIR}/${TEST_TYPE}")
endif()

if(BUSTED_OUTPUT_TYPE STREQUAL junit)
  set(EXTRA_ARGS OUTPUT_FILE ${BUILD_DIR}/${TEST_TYPE}test-junit.xml)
endif()

if(DEFINED ENV{TEST_TAG} AND NOT "$ENV{TEST_TAG}" STREQUAL "")
  set(TEST_TAG "--tags=$ENV{TEST_TAG}")
endif()

if(DEFINED ENV{TEST_FILTER} AND NOT "$ENV{TEST_FILTER}" STREQUAL "")
  set(TEST_FILTER "--filter=$ENV{TEST_FILTER}")
endif()

execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory ${WORKING_DIR}/Xtest-tmpdir)
set(ENV{TMPDIR} ${WORKING_DIR}/Xtest-tmpdir)
set(ENV{SYSTEM_NAME} ${SYSTEM_NAME})
execute_process(
  COMMAND ${BUSTED_PRG} ${TEST_TAG} ${TEST_FILTER} -v -o ${BUSTED_OUTPUT_TYPE}
    --lua=${LUA_PRG} --lazy --helper=${TEST_DIR}/${TEST_TYPE}/preload.lua
    --lpath=${BUILD_DIR}/?.lua --lpath=?.lua ${TEST_PATH}
  WORKING_DIRECTORY ${WORKING_DIR}
  ERROR_VARIABLE err
  RESULT_VARIABLE res
  ${EXTRA_ARGS})

file(REMOVE ${WORKING_DIR}/Xtest_rplugin_manifest)
file(REMOVE_RECURSE ${WORKING_DIR}/Xtest_xdg)
file(REMOVE_RECURSE ${WORKING_DIR}/Xtest-tmpdir)

if(NOT res EQUAL 0)
  message(STATUS "Output to stderr:\n${err}")
  message(FATAL_ERROR "${TEST_TYPE} tests failed with error: ${res}")
endif()
