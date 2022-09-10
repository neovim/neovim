# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

set(prefix "${TEST_PREFIX}")
set(suffix "${TEST_SUFFIX}")
set(extra_args ${TEST_EXTRA_ARGS})
set(properties ${TEST_PROPERTIES})
set(script)
set(suite)
set(tests)

if(POLICY CMP0110)
  # supports arbitrary characters in test names
  cmake_policy(SET CMP0110 NEW)
endif()

function(add_command NAME)
  set(_args "")
  # use ARGV* instead of ARGN, because ARGN splits arrays into multiple arguments
  math(EXPR _last_arg ${ARGC}-1)
  foreach(_n RANGE 1 ${_last_arg})
    set(_arg "${ARGV${_n}}")
    if(_arg MATCHES "[^-./:a-zA-Z0-9_]")
      set(_args "${_args} [==[${_arg}]==]") # form a bracket_argument
    else()
      set(_args "${_args} ${_arg}")
    endif()
  endforeach()
  set(script "${script}${NAME}(${_args})\n" PARENT_SCOPE)
endfunction()

# Run test executable to get list of available tests
if(NOT EXISTS "${SPEC_ROOT}")
  message(
    FATAL_ERROR
    "Specified test file '${SPEC_ROOT}' does not exist"
  )
endif()

get_filename_component(suite ${SPEC_ROOT} NAME_WLE CACHE)

# This is useful to avoid long paths issues
file(RELATIVE_PATH SPEC_ROOT_RELATIVE "${WORKING_DIR}" "${SPEC_ROOT}")

# if(IS_ABSOLUTE ${SPEC_ROOT})
#   file(RELATIVE_PATH SPEC_ROOT "${WORKING_DIR}" "${SPEC_ROOT}")
# endif()

execute_process(
  COMMAND ${BUSTED_PRG} ${SPEC_ROOT_RELATIVE} --list ${extra_args}
  OUTPUT_VARIABLE output
  RESULT_VARIABLE result
  WORKING_DIRECTORY "${WORKING_DIR}"
)

if(NOT ${result} EQUAL 0)
  message(
    FATAL_ERROR
    "Error running test file '${SPEC_ROOT_RELATIVE}':\n"
    "  Result: ${result}\n"
    "  Output: ${output}\n"
  )
endif()

string(REPLACE "\n" ";" output "${output}")

# Parse output
foreach(line ${output})
  string(REGEX REPLACE ".*:[0-9]+: (.*)" "\\1" testname ${line})

  if(POLICY CMP0110)
    # supports arbitrary characters in test names
    set(testname_clean ${testname})
  else()
    # Escape certain problematic characters
    string(REGEX REPLACE "[^-+./:a-zA-Z0-9_]" "." testname_clean ${testname})
  endif()

  set(guarded_testname "${prefix}${testname_clean}${suffix}")

  # busted allows using wildcards
  string(REGEX REPLACE "[-+%]" "." test_filter ${testname_clean})

  if(BUSTED_ARGS)
    list(APPEND extra_args "--output=${OUTPUT_HANDLER}")
  endif()


  separate_arguments(extra_args)

  add_command(
    add_test
    "${guarded_testname}"
    ${BUSTED_PRG}
    ${SPEC_ROOT_RELATIVE}
    --filter=${test_filter}
    ${extra_args}
  )

  add_command(
    set_tests_properties
    "${guarded_testname}"
    PROPERTIES
    WORKING_DIRECTORY "${WORKING_DIR}"
    LABELS "${suite}"
    ENVIRONMENT "${TEST_ENVIRONMENT}"
    ${TEST_PROPERTIES}
  )
  list(APPEND tests "${guarded_testname}")
endforeach()

# Create a list of all discovered tests, which users may use to e.g. set
# properties on the tests
add_command(set ${TEST_LIST} ${tests})

# Write CTest script
file(WRITE "${CTEST_FILE}" "${script}")
