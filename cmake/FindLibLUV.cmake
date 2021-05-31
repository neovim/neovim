# - Try to find luv
# Once done this will define
#  LIBLUV_FOUND - System has libluv
#  LIBLUV_INCLUDE_DIRS - The libluv include directories
#  LIBLUV_LIBRARIES - The libraries needed to use libluv

find_package(PkgConfig)
if (PKG_CONFIG_FOUND)
  # Inconsistently, the .pc file is libluv.pc.
  pkg_check_modules(PC_LIBLUV QUIET libluv)
endif()

set(LIBLUV_DEFINITIONS ${PC_LIBLUV_CFLAGS_OTHER})

# Remove cflags returned by pkg-config as it contains unnecessary trailing luv.
if (PC_LIBLUV_INCLUDEDIR)
  string(REGEX REPLACE "/luv/?$" "" PC_LIBLUV_INCLUDEDIR ${PC_LIBLUV_INCLUDEDIR})
endif()
if (PC_LIBLUV_INCLUDE_DIRS)
  string(REGEX REPLACE "/luv/?$" "" PC_LIBLUV_INCLUDE_DIRS ${PC_LIBLUV_INCLUDE_DIRS})
endif()

find_path(LIBLUV_INCLUDE_DIR luv/luv.h
          PATHS ${PC_LIBLUV_INCLUDEDIR} ${PC_LIBLUV_INCLUDE_DIRS})

# Explicitly look for luv.so. #10407. Also, version 1.34.2-1 has a static
# library named luv_a.a installed, so look for luv_a.
list(APPEND LIBLUV_NAMES luv luv${CMAKE_SHARED_LIBRARY_SUFFIX} luv_a)

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
