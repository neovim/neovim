# - Try to find libtickit
# Once done this will define
#  LIBTICKIT_FOUND - System has libtickit
#  LIBTICKIT_INCLUDE_DIRS - The libtickit include directories
#  LIBTICKIT_LIBRARIES - The libraries needed to use libtickit

find_package(PkgConfig)
if(NOT LIBTICKIT_USE_BUNDLED)
  find_package(PkgConfig)
  if (PKG_CONFIG_FOUND)
    pkg_check_modules(PC_LIBTICKIT QUIET libtickit)
  endif()
else()
  set(PC_LIBTICKIT_INCLUDEDIR)
  set(PC_LIBTICKIT_INCLUDE_DIRS)
  set(PC_LIBTICKIT_LIBDIR)
  set(PC_LIBTICKIT_LIBRARY_DIRS)
  set(LIMIT_SEARCH NO_DEFAULT_PATH)
endif()

set(LIBTICKIT_DEFINITIONS ${PC_LIBTICKIT_CFLAGS_OTHER})

find_path(LIBTICKIT_INCLUDE_DIR tickit.h
          PATHS ${PC_LIBTICKIT_INCLUDEDIR} ${PC_LIBTICKIT_INCLUDE_DIRS}
          ${LIMIT_SEARCH})

# If we're asked to use static linkage, add libuv.a as a preferred library name.
if(LIBTICKIT_USE_STATIC)
  list(APPEND LIBTICKIT_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}tickit${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

list(APPEND LIBTICKIT_NAMES tickit)

find_library(LIBTICKIT_LIBRARY NAMES ${LIBTICKIT_NAMES}
  HINTS ${PC_LIBTICKIT_LIBDIR} ${PC_LIBTICKIT_LIBRARY_DIRS}
  ${LIMIT_SEARCH})

set(LIBTICKIT_LIBRARIES ${LIBTICKIT_LIBRARY})
set(LIBTICKIT_INCLUDE_DIRS ${LIBTICKIT_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LIBTICKIT_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(LibTickit DEFAULT_MSG
  LIBTICKIT_LIBRARY LIBTICKIT_INCLUDE_DIR)

mark_as_advanced(LIBTICKIT_INCLUDE_DIR LIBTICKIT_LIBRARY)
