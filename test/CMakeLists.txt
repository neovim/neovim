add_subdirectory(functional/fixtures)  # compile test programs

get_directory_property(TEST_INCLUDE_DIRS DIRECTORY ${PROJECT_SOURCE_DIR}/src/nvim DEFINITION TEST_INCLUDE_DIRS)

set(TEST_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(TEST_OPTIONS
      -D BUILD_DIR=${CMAKE_BINARY_DIR}
      -D CIRRUS_CI=$ENV{CIRRUS_CI}
      -D CI_BUILD=${CI_BUILD}
      -D DEPS_INSTALL_DIR=${DEPS_INSTALL_DIR}
      -D NVIM_PRG=$<TARGET_FILE:nvim_bin>
      -D TEST_DIR=${TEST_DIR}
      -D WORKING_DIR=${PROJECT_SOURCE_DIR})

check_lua_module(${LUA_PRG} "ffi" LUA_HAS_FFI)
if(LUA_HAS_FFI)
  add_custom_target(unittest
    COMMAND ${CMAKE_COMMAND}
      -D TEST_TYPE=unit
      ${TEST_OPTIONS}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    USES_TERMINAL)
  add_dependencies(unittest lua_dev_deps nvim)
else()
  message(WARNING "disabling unit tests: no Luajit FFI in ${LUA_PRG}")
endif()

configure_file(
  ${CMAKE_SOURCE_DIR}/test/cmakeconfig/paths.lua.in
  ${CMAKE_BINARY_DIR}/test/cmakeconfig/paths.lua)

add_custom_target(benchmark
  COMMAND ${CMAKE_COMMAND}
    -D TEST_TYPE=benchmark
    ${TEST_OPTIONS}
    -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
  DEPENDS tty-test
  USES_TERMINAL)
add_dependencies(benchmark lua_dev_deps nvim)

add_custom_target(functionaltest
  COMMAND ${CMAKE_COMMAND}
    -D TEST_TYPE=functional
    ${TEST_OPTIONS}
    -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
  DEPENDS printenv-test printargs-test shell-test pwsh-test streams-test tty-test
  USES_TERMINAL)
add_dependencies(functionaltest lua_dev_deps nvim)

# Create multiple targets for groups of functional tests to enable parallel testing.
set(group_targets "")
set(summary_files "")
file(GLOB_RECURSE test_files RELATIVE "${TEST_DIR}/functional" "${TEST_DIR}/functional/*_spec*")
foreach(test_file ${test_files})
  # Get test group: "test/functional/foo/bar_spec.lua" => "foo".
  string(REGEX REPLACE "/.*" "" test_group ${test_file})
  set(group_target "functionaltest_${test_group}")
  string(REGEX REPLACE "[^A-Za-z0-9_]" "_" group_target ${group_target})
  list(FIND group_targets ${group_target} group_idx)
  if(${group_idx} EQUAL -1)
    # Create new target for test group.
    set(summary_file "${CMAKE_BINARY_DIR}/${group_target}.summary")
    add_custom_target(${group_target}
      COMMAND ${CMAKE_COMMAND}
        -D TEST_TYPE=functional -D TEST_PARALLEL_GROUP=${test_group} -D TEST_SUMMARY_FILE=${summary_file}
        ${TEST_OPTIONS}
        -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
      DEPENDS printenv-test printargs-test shell-test pwsh-test streams-test tty-test)
    add_dependencies(${group_target} lua_dev_deps nvim)
    list(APPEND group_targets ${group_target})
    list(APPEND summary_files ${summary_file})
  endif()
endforeach()

add_custom_target(functionaltest_parallel DEPENDS ${group_targets})
add_custom_target(functionaltest_summary COMMAND ${CMAKE_COMMAND} -E cat ${summary_files} USES_TERMINAL)
