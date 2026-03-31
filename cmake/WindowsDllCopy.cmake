# In Windows we need to find dependency DLLs and install them along with our
# binaries. This script uses the following variables:
#
# - BINARY: The binary file whose dependencies need to be installed
# - DST: The destination path
# - CMAKE_PREFIX_PATH: A list of directories to search for dependencies

if(NOT DEFINED BINARY)
  message(FATAL_ERROR "Missing required argument -D BINARY=")
endif()
if(NOT DEFINED DST)
  message(FATAL_ERROR "Missing required arguments -D DST=")
endif()
if(NOT DEFINED CMAKE_PREFIX_PATH)
  message(FATAL_ERROR "Missing required arguments -D CMAKE_PREFIX_PATH=")
endif()

include(GetPrerequisites)
get_prerequisites(${BINARY} DLLS 1 1 "" "${CMAKE_PREFIX_PATH}")
foreach(DLL_NAME ${DLLS})
  find_program(DLL_PATH ${DLL_NAME})
  if(NOT DLL_PATH)
    message(FATAL_ERROR "Unable to find dependency ${DLL_NAME}")
  endif()

  if(CI_BUILD)
    message("Copying ${DLL_NAME} to ${DST}")
  endif()
  execute_process(COMMAND ${CMAKE_COMMAND} -E copy ${DLL_PATH} ${DST})
  unset(DLL_PATH CACHE)
endforeach()
