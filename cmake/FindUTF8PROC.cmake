# - Try to find utf8proc
# Once done this will define
#  UTF8PROC_FOUND - System has utf8proc
#  UTF8PROC_INCLUDE_DIRS - The utf8proc include directories
#  UTF8PROC_LIBRARIES - The libraries needed to use utf8proc

include(LibFindMacros)

# TODO: required?
# list(APPEND UTF8PROC_NAMES utf8proc)
# if(MSVC)
#   list(APPEND UTF8PROC_NAMES utf8proc_static)
# endif()

libfind_pkg_detect(UTF8PROC utf8proc FIND_PATH utf8proc.h FIND_LIBRARY utf8proc)
libfind_process(UTF8PROC REQUIRED)
