# TODO(dundargoc): FindIconv is shipped by default on cmake version 3.11+. This
# file can be removed once we decide to upgrade minimum cmake version.

# - Try to find iconv
# Once done, this will define
#
#  Iconv_FOUND        - system has iconv
#  Iconv_INCLUDE_DIRS - the iconv include directories
#  Iconv_LIBRARIES    - link these to use iconv

include(LibFindMacros)

find_path(ICONV_INCLUDE_DIR NAMES iconv.h)
find_library(ICONV_LIBRARY NAMES iconv libiconv)

set(Iconv_PROCESS_INCLUDES ICONV_INCLUDE_DIR)
if(ICONV_LIBRARY)
  set(Iconv_PROCESS_LIBS ICONV_LIBRARY)
endif()

libfind_process(Iconv)

mark_as_advanced(ICONV_LIBRARY)
