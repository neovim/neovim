# - Try to find libacl
# Once done, this will define
#
#  LibACL_FOUND        - system has libacl
#  LibACL_INCLUDE_DIRS - the libacl include directories
#  LibACL_LIBRARIES    - link these to use libacl

include(LibFindMacros)

find_path(LIBACL_INCLUDE_DIR NAMES sys/acl.h)
find_library(LIBACL_LIBRARY NAMES acl libacl)

set(LibACL_PROCESS_INCLUDES LIBACL_INCLUDE_DIR)
if(LIBACL_LIBRARY)
  set(LibACL_PROCESS_LIBS LIBACL_LIBRARY)
endif()

libfind_process(LibACL)
