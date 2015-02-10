if(NOT DEFINED LIBRARY_NAME)
  message(FATAL_ERROR "LIBRARY_NAME not set in InstallLibrary.cmake.")
endif()

separate_arguments(INSTALL_COMMAND)
execute_process(
  COMMAND ${INSTALL_COMMAND}
  RESULT_VARIABLE res)

if(NOT res EQUAL 0)
  message(FATAL_ERROR "Installing ${LIBRARY_NAME} failed: ${res}.")
endif()

set(REMOVE_FILE_GLOB ${DEPS_INSTALL_DIR}/lib/${CMAKE_SHARED_LIBRARY_PREFIX}${LIBRARY_NAME}*${CMAKE_SHARED_LIBRARY_SUFFIX}*)

# Do not follow symlinks.
cmake_policy(SET CMP0009 NEW)

file(GLOB_RECURSE FILES_TO_REMOVE ${REMOVE_FILE_GLOB})
if(FILES_TO_REMOVE)
  file(REMOVE ${FILES_TO_REMOVE})
endif()
