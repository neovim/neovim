# Set LC_ALL to meet expectations of some locale-sensitive tests.
set(ENV{LC_ALL} "en_US.UTF-8")

if(POLICY CMP0012)
  # Handle CI=true, without dev warnings.
  cmake_policy(SET CMP0012 NEW)
endif()

set(ENV{VIMRUNTIME} ${WORKING_DIR}/runtime)
set(ENV{NVIM_RPLUGIN_MANIFEST} ${BUILD_DIR}/Xtest_rplugin_manifest)
set(ENV{XDG_CONFIG_HOME} ${BUILD_DIR}/Xtest_xdg/config)
set(ENV{XDG_DATA_HOME} ${BUILD_DIR}/Xtest_xdg/share)

if(NOT DEFINED ENV{NVIM_LOG_FILE})
  set(ENV{NVIM_LOG_FILE} ${BUILD_DIR}/.nvimlog)
endif()

if(NVIM_PRG)
  set(ENV{NVIM_PRG} "${NVIM_PRG}")
endif()

if(DEFINED ENV{TEST_FILE})
  set(TEST_PATH "$ENV{TEST_FILE}")
else()
  set(TEST_PATH "${TEST_DIR}/${TEST_TYPE}")
endif()

# Force $TEST_PATH to workdir-relative path ("test/…").
if(IS_ABSOLUTE ${TEST_PATH})
  file(RELATIVE_PATH TEST_PATH "${WORKING_DIR}" "${TEST_PATH}")
endif()

if(BUSTED_OUTPUT_TYPE STREQUAL junit)
  set(EXTRA_ARGS OUTPUT_FILE ${BUILD_DIR}/${TEST_TYPE}test-junit.xml)
endif()

set(BUSTED_ARGS $ENV{BUSTED_ARGS})
separate_arguments(BUSTED_ARGS)

if(DEFINED ENV{TEST_TAG} AND NOT "$ENV{TEST_TAG}" STREQUAL "")
  list(APPEND BUSTED_ARGS --tags $ENV{TEST_TAG})
endif()

if(DEFINED ENV{TEST_FILTER} AND NOT "$ENV{TEST_FILTER}" STREQUAL "")
  list(APPEND BUSTED_ARGS --filter $ENV{TEST_FILTER})
endif()

# TMPDIR: use relative test path (for parallel test runs / isolation).
set(ENV{TMPDIR} "${BUILD_DIR}/Xtest_tmpdir/${TEST_PATH}")
execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory $ENV{TMPDIR})

set(ENV{SYSTEM_NAME} ${CMAKE_HOST_SYSTEM_NAME})  # used by test/helpers.lua.
execute_process(
  COMMAND ${BUSTED_PRG} -v -o test.busted.outputHandlers.${BUSTED_OUTPUT_TYPE}
    --lazy --helper=${TEST_DIR}/${TEST_TYPE}/preload.lua
    --lpath=${BUILD_DIR}/?.lua
    --lpath=${WORKING_DIR}/runtime/lua/?.lua
    --lpath=?.lua
    ${BUSTED_ARGS}
    ${TEST_PATH}
  WORKING_DIRECTORY ${WORKING_DIR}
  ERROR_VARIABLE err
  RESULT_VARIABLE res
  ${EXTRA_ARGS})

file(GLOB RM_FILES ${BUILD_DIR}/Xtest_*)
file(REMOVE_RECURSE ${RM_FILES})

if(NOT res EQUAL 0)
  message(STATUS "Tests exited non-zero: ${res}")
  if("${err}" STREQUAL "")
    message(STATUS "No output to stderr.")
  else()
    message(STATUS "Output to stderr:\n${err}")
  endif()

  # Dump the logfile on CI (if not displayed and moved already).
  if($ENV{CI})
    if(EXISTS $ENV{NVIM_LOG_FILE} AND NOT EXISTS $ENV{NVIM_LOG_FILE}.displayed)
      file(READ $ENV{NVIM_LOG_FILE} out)
      message(STATUS "$NVIM_LOG_FILE: $ENV{NVIM_LOG_FILE}\n${out}")
    endif()
  endif()

  message(FATAL_ERROR "${TEST_TYPE} tests failed with error: ${res}")
endif()
