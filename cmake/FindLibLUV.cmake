# - Try to find luv
# Once done this will define
#  LIBLUV_FOUND - System has libluv
#  LIBLUV_INCLUDE_DIRS - The libluv include directories
#  LIBLUV_LIBRARIES - The libraries needed to use libluv

find_package(PkgConfig)
if (PKG_CONFIG_FOUND)
  pkg_check_modules(PC_LIBLUV QUIET luv)
endif()

set(LIBLUV_DEFINITIONS ${PC_LIBLUV_CFLAGS_OTHER})

find_path(LIBLUV_INCLUDE_DIR luv/luv.h
          PATHS ${PC_LIBLUV_INCLUDEDIR} ${PC_LIBLUV_INCLUDE_DIRS})

list(APPEND LIBLUV_NAMES luv)

find_library(LIBLUV_LIBRARY NAMES ${LIBLUV_NAMES}
  HINTS ${PC_LIBLUV_LIBDIR} ${PC_LIBLUV_LIBRARY_DIRS})

set(LIBLUV_LIBRARIES ${LIBLUV_LIBRARY})
set(LIBLUV_INCLUDE_DIRS ${LIBLUV_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LIBLUV_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(LibLUV DEFAULT_MSG
  LIBLUV_LIBRARY LIBLUV_INCLUDE_DIR)

mark_as_advanced(LIBLUV_INCLUDE_DIR LIBLUV_LIBRARY)
