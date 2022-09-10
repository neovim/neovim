# Distributed under the OSI-approved BSD 3-Clause License.
# See https://cmake.org/licensing for details.

#[=======================================================================[.rst:
Busted
-----
#]=======================================================================]

#------------------------------------------------------------------------------
function(busted_discover_tests TARGET)
  cmake_parse_arguments(
    ""
    ""
    "BUSTED_PRG;LUA_PRG;TEST_PREFIX;TEST_SUFFIX;WORKING_DIRECTORY;BUILD_DIR;TEST_LIST"
    "EXTRA_ARGS;TEST_ENVIRONMENT;PROPERTIES"
    ${ARGN}
  )

  if(NOT _WORKING_DIRECTORY)
    set(_WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}")
  endif()
  if(NOT _TEST_LIST)
    set(_TEST_LIST ${TARGET}_TESTS)
  endif()

  # TODO(kylo252): figure out if we can use a generator expression instead
  get_target_property(SPECS ${TARGET} SOURCES)

  foreach(SPEC_ROOT ${SPECS})
    if(NOT IS_DIRECTORY "${SPEC_ROOT}")
      get_filename_component(ctest_file_base ${SPEC_ROOT} NAME_WLE)
    else()
      file(RELATIVE_PATH ctest_file_base "${_WORKING_DIRECTORY}/test" "${SPEC_ROOT}")
    endif()
    set(ctest_include_file "${CMAKE_CURRENT_BINARY_DIR}/${ctest_file_base}_include.cmake")
    set(ctest_tests_file "${CMAKE_CURRENT_BINARY_DIR}/${ctest_file_base}_tests.cmake")

    add_custom_command(
      TARGET ${TARGET} POST_BUILD
      BYPRODUCTS "${ctest_tests_file}"
      COMMAND "${CMAKE_COMMAND}"
      -D "TEST_TARGET=${TARGET}"
      -D "BUSTED_PRG=${_BUSTED_PRG}"
      -D "SPEC_ROOT=${SPEC_ROOT}"
      -D "LUA_PRG=${_LUA_PRG}"
      -D "WORKING_DIR=${_WORKING_DIRECTORY}"
      -D "BUILD_DIR=${_BUILD_DIR}"
      -D "TEST_EXTRA_ARGS=${_EXTRA_ARGS}"
      -D "TEST_PROPERTIES=${_PROPERTIES}"
      -D "TEST_ENVIRONMENT=${_TEST_ENVIRONMENT}"
      -D "TEST_PREFIX=${_TEST_PREFIX}"
      -D "TEST_SUFFIX=${_TEST_SUFFIX}"
      -D "TEST_LIST=${_TEST_LIST}"
      -D "CTEST_FILE=${ctest_tests_file}"
      -P "${_BUSTED_DISCOVER_TESTS_SCRIPT}"
      VERBATIM
    )

    file(
      WRITE "${ctest_include_file}"
      "if(EXISTS \"${ctest_tests_file}\")\n"
      "  include(\"${ctest_tests_file}\")\n"
      "else()\n"
      "  add_test(${TARGET}_NOT_BUILT ${TARGET}_NOT_BUILT)\n"
      "endif()\n"
    )

    # Add discovered tests to directory TEST_INCLUDE_FILES
    set_property(
      DIRECTORY
      APPEND PROPERTY TEST_INCLUDE_FILES "${ctest_include_file}"
    )
  endforeach()

endfunction()

###############################################################################

set(
  _BUSTED_DISCOVER_TESTS_SCRIPT
  ${CMAKE_CURRENT_LIST_DIR}/BustedAddTests.cmake
  CACHE INTERNAL "busted full path to BustedAddTests.cmake helper file"
)
