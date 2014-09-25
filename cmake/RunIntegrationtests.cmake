if(DEFINED ENV{TEST_FILE})
  set(TEST_DIR $ENV{TEST_FILE})
endif()

set(ENV{PATH} "${BUILD_DIR}/bin:$ENV{PATH}")

#TODO
find_package(PythonInterp 2.6 REQUIRED)
if(NOT ENV{USE_BUNDLED_DEPS} STREQUAL "OFF")
  set(ENV{PYTHONPATH} "${DEPS_INSTALL_DIR}/lib/python${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}/site-packages/:$ENV{PYTHONPATH}")
endif()

execute_process(
  COMMAND ${PYTHON_EXECUTABLE} ${VROOM_PRG} --neovim --crawl ${TEST_DIR}
  WORKING_DIRECTORY ${WORKING_DIR}
  RESULT_VARIABLE res)

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Integration tests failed.")
endif()
