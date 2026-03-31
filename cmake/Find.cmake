# Functions to aid the built-in find_ functions

# Same as find_path, but always search in .deps directory first and then everything else.
function(find_path2)
  find_path_nvim(${ARGV})
  find_path(${ARGV})
endfunction()

function(find_path_nvim)
  set(CMAKE_FIND_FRAMEWORK NEVER)
  set(CMAKE_FIND_APPBUNDLE NEVER)
  find_path(${ARGV} NO_CMAKE_SYSTEM_PATH NO_CMAKE_ENVIRONMENT_PATH NO_SYSTEM_ENVIRONMENT_PATH)
endfunction()

# Same as find_library, but with the following search order:
# 1. Only search in .deps directory. Only search for static libraries.
# 2. Only search in .deps directory. Search all libraries
# 3. Search everywhere, all libraries
function(find_library2)
  find_library_nvim(STATIC ${ARGV})
  find_library_nvim(${ARGV})
  find_library(${ARGV})
endfunction()

function(find_library_nvim)
  cmake_parse_arguments(ARG
    "STATIC"
    ""
    ""
    ${ARGN})
  list(REMOVE_ITEM ARGN STATIC)

  if(ARG_STATIC)
    set(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_STATIC_LIBRARY_SUFFIX})
  endif()
  set(CMAKE_FIND_FRAMEWORK NEVER)
  set(CMAKE_FIND_APPBUNDLE NEVER)
  find_library(${ARGN} NO_CMAKE_SYSTEM_PATH NO_CMAKE_ENVIRONMENT_PATH NO_SYSTEM_ENVIRONMENT_PATH)
endfunction()
