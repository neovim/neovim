if(DEFINED TEST_PARALLEL_GROUP)
  if(DEFINED ENV{TEST_FILE})
    message(FATAL_ERROR "$TEST_FILE should not be used with parallel tests")
  endif()
  set(TEST_SUFFIX "_${TEST_PARALLEL_GROUP}")
  string(REGEX REPLACE "[^A-Za-z0-9_]" "_" TEST_SUFFIX ${TEST_SUFFIX})
else()
  set(TEST_SUFFIX "")
endif()

set(ENV{NVIM_TEST} "1")
# Set LC_ALL to meet expectations of some locale-sensitive tests.
set(ENV{LC_ALL} "en_US.UTF-8")
set(ENV{VIMRUNTIME} ${ROOT_DIR}/runtime)
set(TEST_XDG_PREFIX ${BUILD_DIR}/Xtest_xdg${TEST_SUFFIX})
set(ENV{XDG_CONFIG_HOME} ${TEST_XDG_PREFIX}/config)
set(ENV{XDG_DATA_HOME} ${TEST_XDG_PREFIX}/share)
set(ENV{XDG_STATE_HOME} ${TEST_XDG_PREFIX}/state)
set(ENV{NVIM_RPLUGIN_MANIFEST} ${BUILD_DIR}/Xtest_rplugin_manifest${TEST_SUFFIX})
unset(ENV{XDG_DATA_DIRS})
unset(ENV{NVIM})  # Clear $NVIM in case tests are running from Nvim. #11009
unset(ENV{TMUX})  # Nvim TUI shouldn't think it's running in tmux. #34173

# Prepare for running tests in ${TEST_XDG_PREFIX}.
file(MAKE_DIRECTORY ${TEST_XDG_PREFIX})
file(CREATE_LINK ${ROOT_DIR}/runtime ${TEST_XDG_PREFIX}/runtime SYMBOLIC)
file(CREATE_LINK ${ROOT_DIR}/src ${TEST_XDG_PREFIX}/src SYMBOLIC)
file(CREATE_LINK ${ROOT_DIR}/test ${TEST_XDG_PREFIX}/test SYMBOLIC)
file(CREATE_LINK ${ROOT_DIR}/README.md ${TEST_XDG_PREFIX}/README.md SYMBOLIC)

# TODO(dundargoc): The CIRRUS_CI environment variable isn't passed to here from
# the main CMakeLists.txt, so we have to manually pass it to this script and
# re-set the environment variable. Investigate if we can avoid manually setting
# it like with the GITHUB_CI environment variable.
set(ENV{CIRRUS_CI} ${CIRRUS_CI})

if(NOT DEFINED ENV{NVIM_LOG_FILE})
  set(ENV{NVIM_LOG_FILE} ${BUILD_DIR}/nvim.log)
endif()
set(ENV{NVIM_LOG_FILE} "$ENV{NVIM_LOG_FILE}${TEST_SUFFIX}")

if(NVIM_PRG)
  set(ENV{NVIM_PRG} "${NVIM_PRG}")
endif()

if(DEFINED ENV{TEST_FILE})
  set(TEST_PATH "$ENV{TEST_FILE}")
elseif(DEFINED TEST_PARALLEL_GROUP)
  set(TEST_PATH "${TEST_DIR}/${TEST_TYPE}/${TEST_PARALLEL_GROUP}")
else()
  set(TEST_PATH "${TEST_DIR}/${TEST_TYPE}")
endif()

if(NOT DEFINED TEST_SUMMARY_FILE)
  set(TEST_SUMMARY_FILE "-")
endif()

# Force $TEST_PATH to workdir-relative path ("test/…").
if(IS_ABSOLUTE ${TEST_PATH})
  file(RELATIVE_PATH TEST_PATH "${ROOT_DIR}" "${TEST_PATH}")
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
set(ENV{TMPDIR} "${BUILD_DIR}/Xtest_tmpdir${TEST_SUFFIX}")
file(MAKE_DIRECTORY $ENV{TMPDIR})

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
  # _core/editor.lua are not loaded.
  COMMAND ${NVIM_PRG} -ll ${ROOT_DIR}/test/lua_runner.lua ${DEPS_INSTALL_DIR}/share/lua/5.1/ busted -v -o test.busted.outputHandlers.nvim
    -Xoutput "{\"test_path\": \"${TEST_PATH}\", \"summary_file\": \"${TEST_SUMMARY_FILE}\"}"
    --lazy --helper=${TEST_DIR}/${TEST_TYPE}/preload.lua
    --lpath=${BUILD_DIR}/?.lua
    --lpath=${ROOT_DIR}/src/?.lua
    --lpath=${ROOT_DIR}/runtime/lua/?.lua
    --lpath=?.lua
    ${BUSTED_ARGS}
    ${TEST_PATH}
  TIMEOUT $ENV{TEST_TIMEOUT}
  WORKING_DIRECTORY ${TEST_XDG_PREFIX}
  RESULT_VARIABLE res
  ${EXTRA_ARGS})

file(REMOVE_RECURSE ${TEST_XDG_PREFIX})
file(REMOVE_RECURSE $ENV{NVIM_RPLUGIN_MANIFEST})
file(REMOVE_RECURSE $ENV{TMPDIR})

macro(PRINT_NVIM_LOG)
  file(READ $ENV{NVIM_LOG_FILE} out)
  if(${TEST_SUMMARY_FILE} STREQUAL "-")
    message(STATUS "$NVIM_LOG_FILE: $ENV{NVIM_LOG_FILE}\n${out}")
  else()
    file(APPEND ${TEST_SUMMARY_FILE} "$NVIM_LOG_FILE: $ENV{NVIM_LOG_FILE}\n${out}")
  endif()
endmacro()

if(res)
  message(STATUS "Tests exited non-zero: ${res}")

  # Dump the logfile on CI (if not displayed and moved already).
  if(CI_BUILD)
    if(EXISTS $ENV{NVIM_LOG_FILE} AND NOT EXISTS $ENV{NVIM_LOG_FILE}.displayed)
      PRINT_NVIM_LOG()
    endif()
  endif()

  message(FATAL_ERROR "${TEST_TYPE} tests failed with error: ${res}")
endif()

if(CI_BUILD)
  file(SIZE $ENV{NVIM_LOG_FILE} FILE_SIZE)
  if(NOT ${FILE_SIZE} MATCHES "^0$")
    PRINT_NVIM_LOG()
    message(FATAL_ERROR "$NVIM_LOG_FILE is not empty")
  endif()
endif()
