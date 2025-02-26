# Set LC_ALL to meet expectations of some locale-sensitive tests.
set(ENV{LC_ALL} "en_US.UTF-8")
set(ENV{VIMRUNTIME} ${WORKING_DIR}/runtime)
set(ENV{NVIM_RPLUGIN_MANIFEST} ${BUILD_DIR}/Xtest_rplugin_manifest)
set(ENV{XDG_CONFIG_HOME} ${BUILD_DIR}/Xtest_xdg/config)
set(ENV{XDG_DATA_HOME} ${BUILD_DIR}/Xtest_xdg/share)
set(ENV{XDG_STATE_HOME} ${BUILD_DIR}/Xtest_xdg/state)
unset(ENV{XDG_DATA_DIRS})
unset(ENV{NVIM})  # Clear $NVIM in case tests are running from Nvim. #11009

# TODO(dundargoc): The CIRRUS_CI environment variable isn't passed to here from
# the main CMakeLists.txt, so we have to manually pass it to this script and
# re-set the environment variable. Investigate if we can avoid manually setting
# it like with the GITHUB_CI environment variable.
set(ENV{CIRRUS_CI} ${CIRRUS_CI})

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

separate_arguments(BUSTED_ARGS NATIVE_COMMAND $ENV{BUSTED_ARGS})

if(DEFINED ENV{TEST_TAG} AND NOT "$ENV{TEST_TAG}" STREQUAL "")
  list(APPEND BUSTED_ARGS --tags $ENV{TEST_TAG})
endif()

if(DEFINED ENV{TEST_FILTER} AND NOT "$ENV{TEST_FILTER}" STREQUAL "")
  list(APPEND BUSTED_ARGS --filter $ENV{TEST_FILTER})
endif()

if(DEFINED ENV{TEST_FILTER_OUT} AND NOT "$ENV{TEST_FILTER_OUT}" STREQUAL "")
  list(APPEND BUSTED_ARGS --filter-out $ENV{TEST_FILTER_OUT})
endif()

# TMPDIR: for testutil.tmpname() and Nvim tempname().
set(ENV{TMPDIR} "${BUILD_DIR}/Xtest_tmpdir")
execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory $ENV{TMPDIR})

# HISTFILE: do not write into user's ~/.bash_history
set(ENV{HISTFILE} "/dev/null")

if(NOT DEFINED ENV{TEST_TIMEOUT} OR "$ENV{TEST_TIMEOUT}" STREQUAL "")
  set(ENV{TEST_TIMEOUT} 1200)
endif()

set(ENV{SYSTEM_NAME} ${CMAKE_HOST_SYSTEM_NAME})  # used by test/testutil.lua.

if(NOT WIN32)
  # Tests assume POSIX "sh" and may fail if SHELL=fish. #24941 #6172
  set(ENV{SHELL} sh)
endif()

execute_process(
  # Note: because of "-ll" (low-level interpreter mode), some modules like
  # _editor.lua are not loaded.
  COMMAND ${NVIM_PRG} -ll ${WORKING_DIR}/test/lua_runner.lua ${DEPS_INSTALL_DIR} busted -v -o test.busted.outputHandlers.nvim
    --lazy --helper=${TEST_DIR}/${TEST_TYPE}/preload.lua
    --lpath=${BUILD_DIR}/?.lua
    --lpath=${WORKING_DIR}/src/?.lua
    --lpath=${WORKING_DIR}/runtime/lua/?.lua
    --lpath=?.lua
    ${BUSTED_ARGS}
    ${TEST_PATH}
  TIMEOUT $ENV{TEST_TIMEOUT}
  WORKING_DIRECTORY ${WORKING_DIR}
  ERROR_VARIABLE err
  RESULT_VARIABLE res
  ${EXTRA_ARGS})

file(GLOB RM_FILES ${BUILD_DIR}/Xtest_*)
file(REMOVE_RECURSE ${RM_FILES})

if(res)
  message(STATUS "Tests exited non-zero: ${res}")
  if("${err}" STREQUAL "")
    message(STATUS "No output to stderr.")
  else()
    message(STATUS "Output to stderr:\n${err}")
  endif()

  # Dump the logfile on CI (if not displayed and moved already).
  if(CI_BUILD)
    if(EXISTS $ENV{NVIM_LOG_FILE} AND NOT EXISTS $ENV{NVIM_LOG_FILE}.displayed)
      file(READ $ENV{NVIM_LOG_FILE} out)
      message(STATUS "$NVIM_LOG_FILE: $ENV{NVIM_LOG_FILE}\n${out}")
    endif()
  endif()

  message(FATAL_ERROR "${TEST_TYPE} tests failed with error: ${res}")
endif()
