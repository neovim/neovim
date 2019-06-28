# - Try to find libvterm
# Once done this will define
#  LIBVTERM_FOUND - System has libvterm
#  LIBVTERM_INCLUDE_DIRS - The libvterm include directories
#  LIBVTERM_LIBRARIES - The libraries needed to use libvterm

find_package(PkgConfig)
if (PKG_CONFIG_FOUND)
  pkg_check_modules(PC_LIBVTERM QUIET vterm)
endif()

set(LIBVTERM_DEFINITIONS ${PC_LIBVTERM_CFLAGS_OTHER})

find_path(LIBVTERM_INCLUDE_DIR vterm.h
          PATHS ${PC_LIBVTERM_INCLUDEDIR} ${PC_LIBVTERM_INCLUDE_DIRS})

# If we're asked to use static linkage, add libuv.a as a preferred library name.
if(LIBVTERM_USE_STATIC)
  list(APPEND LIBVTERM_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}vterm${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

list(APPEND LIBVTERM_NAMES vterm)

find_library(LIBVTERM_LIBRARY NAMES ${LIBVTERM_NAMES}
  HINTS ${PC_LIBVTERM_LIBDIR} ${PC_LIBVTERM_LIBRARY_DIRS})

set(LIBVTERM_LIBRARIES ${LIBVTERM_LIBRARY})
set(LIBVTERM_INCLUDE_DIRS ${LIBVTERM_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LIBVTERM_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(LibVterm DEFAULT_MSG
  LIBVTERM_LIBRARY LIBVTERM_INCLUDE_DIR)

mark_as_advanced(LIBVTERM_INCLUDE_DIR LIBVTERM_LIBRARY)
