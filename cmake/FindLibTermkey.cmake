# - Try to find libtermkey
# Once done this will define
#  LIBTERMKEY_FOUND - System has libtermkey
#  LIBTERMKEY_INCLUDE_DIRS - The libtermkey include directories
#  LIBTERMKEY_LIBRARIES - The libraries needed to use libtermkey

if(NOT USE_BUNDLED_LIBTERMKEY)
  find_package(PkgConfig)
  if (PKG_CONFIG_FOUND)
    pkg_check_modules(PC_LIBTERMKEY QUIET termkey)
  endif()
else()
  set(PC_LIBTERMKEY_INCLUDEDIR)
  set(PC_LIBTERMKEY_INCLUDE_DIRS)
  set(PC_LIBTERMKEY_LIBDIR)
  set(PC_LIBTERMKEY_LIBRARY_DIRS)
  set(LIMIT_SEARCH NO_DEFAULT_PATH)
endif()

set(LIBTERMKEY_DEFINITIONS ${PC_LIBTERMKEY_CFLAGS_OTHER})

find_path(LIBTERMKEY_INCLUDE_DIR termkey.h
          PATHS ${PC_LIBTERMKEY_INCLUDEDIR} ${PC_LIBTERMKEY_INCLUDE_DIRS}
          ${LIMIT_SEARCH})

# If we're asked to use static linkage, add libuv.a as a preferred library name.
if(LIBTERMKEY_USE_STATIC)
  list(APPEND LIBTERMKEY_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}termkey${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

list(APPEND LIBTERMKEY_NAMES termkey)

find_library(LIBTERMKEY_LIBRARY NAMES ${LIBTERMKEY_NAMES}
  HINTS ${PC_LIBTERMKEY_LIBDIR} ${PC_LIBTERMKEY_LIBRARY_DIRS}
  ${LIMIT_SEARCH})

set(LIBTERMKEY_LIBRARIES ${LIBTERMKEY_LIBRARY})
set(LIBTERMKEY_INCLUDE_DIRS ${LIBTERMKEY_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LIBTERMKEY_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(LibTermkey DEFAULT_MSG
  LIBTERMKEY_LIBRARY LIBTERMKEY_INCLUDE_DIR)

mark_as_advanced(LIBTERMKEY_INCLUDE_DIR LIBTERMKEY_LIBRARY)
