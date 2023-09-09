add_subdirectory(functional/fixtures)  # compile test programs
get_directory_property(GENERATED_HELP_TAGS DIRECTORY ${PROJECT_SOURCE_DIR}/runtime DEFINITION GENERATED_HELP_TAGS)

if(NOT BUSTED_OUTPUT_TYPE)
  set(BUSTED_OUTPUT_TYPE "nvim")
endif()

get_target_property(TEST_INCLUDE_DIRS main_lib INTERFACE_INCLUDE_DIRECTORIES)

set(UNITTEST_PREREQS nvim)
set(FUNCTIONALTEST_PREREQS nvim printenv-test printargs-test shell-test pwsh-test streams-test tty-test ${GENERATED_HELP_TAGS})
set(BENCHMARK_PREREQS nvim tty-test)

check_lua_module(${LUA_PRG} "ffi" LUA_HAS_FFI)
if(LUA_HAS_FFI)
  add_custom_target(unittest
    COMMAND ${CMAKE_COMMAND}
      -D NVIM_PRG=$<TARGET_FILE:nvim>
      -D WORKING_DIR=${PROJECT_SOURCE_DIR}
      -D BUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
      -D TEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}
      -D BUILD_DIR=${CMAKE_BINARY_DIR}
      -D DEPS_INSTALL_DIR=${DEPS_INSTALL_DIR}
      -D TEST_TYPE=unit
      -D CIRRUS_CI=$ENV{CIRRUS_CI}
      -D CI_BUILD=${CI_BUILD}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS ${UNITTEST_PREREQS}
    USES_TERMINAL)
  add_dependencies(unittest test_deps)
else()
  message(WARNING "disabling unit tests: no Luajit FFI in ${LUA_PRG}")
endif()

configure_file(
  ${CMAKE_SOURCE_DIR}/test/cmakeconfig/paths.lua.in
  ${CMAKE_BINARY_DIR}/test/cmakeconfig/paths.lua)

add_custom_target(functionaltest
  COMMAND ${CMAKE_COMMAND}
    -D NVIM_PRG=$<TARGET_FILE:nvim>
    -D WORKING_DIR=${PROJECT_SOURCE_DIR}
    -D BUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
    -D TEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}
    -D BUILD_DIR=${CMAKE_BINARY_DIR}
    -D DEPS_INSTALL_DIR=${DEPS_INSTALL_DIR}
    -D TEST_TYPE=functional
    -D CIRRUS_CI=$ENV{CIRRUS_CI}
    -D CI_BUILD=${CI_BUILD}
    -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
  DEPENDS ${FUNCTIONALTEST_PREREQS}
  USES_TERMINAL)

add_custom_target(benchmark
  COMMAND ${CMAKE_COMMAND}
    -D NVIM_PRG=$<TARGET_FILE:nvim>
    -D WORKING_DIR=${PROJECT_SOURCE_DIR}
    -D BUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
    -D TEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}
    -D BUILD_DIR=${CMAKE_BINARY_DIR}
    -D DEPS_INSTALL_DIR=${DEPS_INSTALL_DIR}
    -D TEST_TYPE=benchmark
    -D CIRRUS_CI=$ENV{CIRRUS_CI}
    -D CI_BUILD=${CI_BUILD}
    -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
  DEPENDS ${BENCHMARK_PREREQS}
  USES_TERMINAL)

add_dependencies(functionaltest test_deps)
add_dependencies(benchmark test_deps)
