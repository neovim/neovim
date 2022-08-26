# - Try to find libtermkey
# Once done this will define
#  LIBTERMKEY_FOUND - System has libtermkey
#  LIBTERMKEY_INCLUDE_DIRS - The libtermkey include directories
#  LIBTERMKEY_LIBRARIES - The libraries needed to use libtermkey

find_package(PkgConfig)
if (PKG_CONFIG_FOUND)
  pkg_check_modules(PC_LIBTERMKEY QUIET termkey)
endif()

set(LIBTERMKEY_DEFINITIONS ${PC_LIBTERMKEY_CFLAGS_OTHER})

find_path(LIBTERMKEY_INCLUDE_DIR termkey.h
          PATHS ${PC_LIBTERMKEY_INCLUDEDIR} ${PC_LIBTERMKEY_INCLUDE_DIRS})

list(APPEND LIBTERMKEY_NAMES termkey)

find_library(LIBTERMKEY_LIBRARY NAMES ${LIBTERMKEY_NAMES}
  HINTS ${PC_LIBTERMKEY_LIBDIR} ${PC_LIBTERMKEY_LIBRARY_DIRS})

set(LIBTERMKEY_LIBRARIES ${LIBTERMKEY_LIBRARY})
set(LIBTERMKEY_INCLUDE_DIRS ${LIBTERMKEY_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LIBTERMKEY_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(LibTermkey DEFAULT_MSG
  LIBTERMKEY_LIBRARY LIBTERMKEY_INCLUDE_DIR)

mark_as_advanced(LIBTERMKEY_INCLUDE_DIR LIBTERMKEY_LIBRARY)
