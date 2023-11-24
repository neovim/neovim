add_subdirectory(functional/fixtures)  # compile test programs
get_directory_property(GENERATED_HELP_TAGS DIRECTORY ${PROJECT_SOURCE_DIR}/runtime DEFINITION GENERATED_HELP_TAGS)

get_target_property(TEST_INCLUDE_DIRS main_lib INTERFACE_INCLUDE_DIRECTORIES)

set(TEST_OPTIONS
      -D BUILD_DIR=${CMAKE_BINARY_DIR}
      -D CIRRUS_CI=$ENV{CIRRUS_CI}
      -D CI_BUILD=${CI_BUILD}
      -D DEPS_INSTALL_DIR=${DEPS_INSTALL_DIR}
      -D NVIM_PRG=$<TARGET_FILE:nvim>
      -D TEST_DIR=${CMAKE_CURRENT_SOURCE_DIR}
      -D WORKING_DIR=${PROJECT_SOURCE_DIR})

check_lua_module(${LUA_PRG} "ffi" LUA_HAS_FFI)
if(LUA_HAS_FFI)
  add_custom_target(unittest
    COMMAND ${CMAKE_COMMAND}
      -D TEST_TYPE=unit
      ${TEST_OPTIONS}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
    DEPENDS nvim
    USES_TERMINAL)
  add_dependencies(unittest lua-dev-deps)
else()
  message(WARNING "disabling unit tests: no Luajit FFI in ${LUA_PRG}")
endif()

configure_file(
  ${CMAKE_SOURCE_DIR}/test/cmakeconfig/paths.lua.in
  ${CMAKE_BINARY_DIR}/test/cmakeconfig/paths.lua)

add_custom_target(functionaltest
  COMMAND ${CMAKE_COMMAND}
    -D TEST_TYPE=functional
    ${TEST_OPTIONS}
    -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
  DEPENDS nvim printenv-test printargs-test shell-test pwsh-test streams-test tty-test ${GENERATED_HELP_TAGS}
  USES_TERMINAL)

add_custom_target(benchmark
  COMMAND ${CMAKE_COMMAND}
    -D TEST_TYPE=benchmark
    ${TEST_OPTIONS}
    -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
  DEPENDS nvim tty-test
  USES_TERMINAL)

add_dependencies(functionaltest lua-dev-deps)
add_dependencies(benchmark lua-dev-deps)
