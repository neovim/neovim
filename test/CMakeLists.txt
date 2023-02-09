function(test)
  cmake_parse_arguments(ARG
    ""
    "TARGET;BUSTED_PRG;TEST_TYPE;CIRRUS_CI"
    ""
    ${ARGN})

  # Set LC_ALL to meet expectations of some locale-sensitive tests.
  set(ENV{LC_ALL} "en_US.UTF-8")

  set(ENV{VIMRUNTIME} ${PROJECT_SOURCE_DIR}/runtime)
  set(ENV{NVIM_RPLUGIN_MANIFEST} ${CMAKE_BINARY_DIR}/Xtest_rplugin_manifest)
  set(ENV{XDG_CONFIG_HOME} ${CMAKE_BINARY_DIR}/Xtest_xdg/config)
  set(ENV{XDG_DATA_HOME} ${CMAKE_BINARY_DIR}/Xtest_xdg/share)
  unset(ENV{XDG_DATA_DIRS})
  unset(ENV{NVIM})  # Clear $NVIM in case tests are running from Nvim. #11009

  # TODO(dundargoc): The CIRRUS_CI environment variable isn't passed to here from
  # the main CMakeLists.txt, so we have to manually pass it to this script and
  # re-set the environment variable. Investigate if we can avoid manually setting
  # it like with the GITHUB_CI environment variable.
  set(ENV{CIRRUS_CI} ${ARG_CIRRUS_CI})

  if(NOT DEFINED ENV{NVIM_LOG_FILE})
    set(ENV{NVIM_LOG_FILE} ${CMAKE_BINARY_DIR}/.nvimlog)
  endif()

  if(DEFINED ENV{TEST_FILE})
    set(TEST_PATH "$ENV{TEST_FILE}")
  else()
    set(TEST_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${ARG_TEST_TYPE}")
  endif()

  # Force $TEST_PATH to workdir-relative path ("test/…").
  if(IS_ABSOLUTE ${TEST_PATH})
    file(RELATIVE_PATH TEST_PATH "${PROJECT_SOURCE_DIR}" "${TEST_PATH}")
  endif()

  set(BUSTED_ARGS $ENV{BUSTED_ARGS})
  separate_arguments(BUSTED_ARGS)

  if(DEFINED ENV{TEST_TAG} AND NOT "$ENV{TEST_TAG}" STREQUAL "")
    list(APPEND BUSTED_ARGS --tags $ENV{TEST_TAG})
  endif()

  if(DEFINED ENV{TEST_FILTER} AND NOT "$ENV{TEST_FILTER}" STREQUAL "")
    list(APPEND BUSTED_ARGS --filter $ENV{TEST_FILTER})
  endif()

  if(DEFINED ENV{TEST_FILTER_OUT} AND NOT "$ENV{TEST_FILTER_OUT}" STREQUAL "")
    list(APPEND BUSTED_ARGS --filter-out $ENV{TEST_FILTER_OUT})
  endif()

  # TMPDIR: for helpers.tmpname() and Nvim tempname().
  set(ENV{TMPDIR} "${CMAKE_BINARY_DIR}/Xtest_tmpdir")
  execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory $ENV{TMPDIR})

  # HISTFILE: do not write into user's ~/.bash_history
  set(ENV{HISTFILE} "/dev/null")
  set(ENV{SYSTEM_NAME} ${CMAKE_HOST_SYSTEM_NAME})  # used by test/helpers.lua.

  # TODO: eventually always use NVIM_PRG as the runner
  if("${ARG_TEST_TYPE}" STREQUAL "unit")
    set(RUNNER_PRG $<TARGET_FILE:nvim> -ll ${PROJECT_SOURCE_DIR}/test/busted_runner.lua)
  else()
    set(RUNNER_PRG ${ARG_BUSTED_PRG})
  endif()

  add_custom_target(${ARG_TARGET}
    COMMAND ${RUNNER_PRG} -v -o test.busted.outputHandlers.nvim
      --lazy --helper=${CMAKE_CURRENT_SOURCE_DIR}/${ARG_TEST_TYPE}/preload.lua
      --lpath=${CMAKE_BINARY_DIR}/?.lua
      --lpath=${PROJECT_SOURCE_DIR}/runtime/lua/?.lua
      --lpath=?.lua
      ${BUSTED_ARGS}
      ${TEST_PATH}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    USES_TERMINAL)

  set_target_properties(${ARG_TARGET} PROPERTIES FOLDER test)

  file(GLOB RM_FILES ${CMAKE_BINARY_DIR}/Xtest_*)
  file(REMOVE_RECURSE ${RM_FILES})
endfunction()

add_subdirectory(functional/fixtures)  # compile test programs
get_directory_property(GENERATED_HELP_TAGS DIRECTORY ${PROJECT_SOURCE_DIR}/runtime DEFINITION GENERATED_HELP_TAGS)

find_program(BUSTED_PRG NAMES busted busted.bat)
if(BUSTED_PRG)
  get_target_property(TEST_INCLUDE_DIRS main_lib INTERFACE_INCLUDE_DIRECTORIES)

  set(UNITTEST_PREREQS nvim)
  set(FUNCTIONALTEST_PREREQS nvim printenv-test printargs-test shell-test pwsh-test streams-test tty-test ${GENERATED_HELP_TAGS})
  set(BENCHMARK_PREREQS nvim tty-test)

  check_lua_module(${LUA_PRG} "ffi" LUA_HAS_FFI)
  if(LUA_HAS_FFI)
    test(TARGET unittest
        BUSTED_PRG ${BUSTED_PRG}
        TEST_TYPE unit
        CIRRUS_CI $ENV{CIRRUS_CI})
  else()
    message(WARNING "disabling unit tests: no Luajit FFI in ${LUA_PRG}")
  endif()

  configure_file(
    ${CMAKE_SOURCE_DIR}/test/cmakeconfig/paths.lua.in
    ${CMAKE_BINARY_DIR}/test/cmakeconfig/paths.lua)

  test(TARGET functionaltest
    BUSTED_PRG ${BUSTED_PRG}
    TEST_TYPE functional
    CIRRUS_CI $ENV{CIRRUS_CI})

  test(TARGET benchmark
    BUSTED_PRG ${BUSTED_PRG}
    TEST_TYPE benchmark
    CIRRUS_CI $ENV{CIRRUS_CI})
endif()

find_program(BUSTED_LUA_PRG busted-lua)
if(BUSTED_LUA_PRG)
  test(TARGET functionaltest-lua
    BUSTED_PRG ${BUSTED_LUA_PRG}
    TEST_TYPE functional
    CIRRUS_CI $ENV{CIRRUS_CI})
endif()
