# - Try to find libvterm
# Once done this will define
#  LIBVTERM_FOUND - System has libvterm
#  LIBVTERM_INCLUDE_DIRS - The libvterm include directories
#  LIBVTERM_LIBRARIES - The libraries needed to use libvterm

include(LibFindMacros)

libfind_pkg_detect(LIBVTERM vterm FIND_PATH vterm.h FIND_LIBRARY vterm)
libfind_process(LIBVTERM REQUIRED)
