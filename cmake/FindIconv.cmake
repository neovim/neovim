# - Try to find iconv
# Once done, this will define
#
#  Iconv_FOUND        - system has iconv
#  Iconv_INCLUDE_DIRS - the iconv include directories
#  Iconv_LIBRARIES    - link these to use iconv

include(LibFindMacros)

find_path(ICONV_INCLUDE_DIR NAMES iconv.h)
if(NVIM_BUILD_STATIC)
  list(APPEND ICONV_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}iconv${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()
list(APPEND ICONV_NAMES iconv)

find_library(ICONV_LIBRARY NAMES ${ICONV_NAMES})

set(Iconv_PROCESS_INCLUDES ICONV_INCLUDE_DIR)
if(ICONV_LIBRARY)
  set(Iconv_PROCESS_LIBS ICONV_LIBRARY)
endif()

libfind_process(Iconv)
