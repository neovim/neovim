# - Try to find libunibilium
# Once done this will define
#  LIBUNIBILIUM_FOUND - System has libunibilium
#  LIBUNIBILIUM_INCLUDE_DIRS - The libunibilium include directories
#  LIBUNIBILIUM_LIBRARIES - The libraries needed to use libunibilium

find_package(PkgConfig)
if(NOT LIBUNIBILIUM_USE_BUNDLED)
  find_package(PkgConfig)
  if (PKG_CONFIG_FOUND)
    pkg_check_modules(PC_LIBUNIBILIUM QUIET unibilium)
  endif()
else()
  set(PC_LIBUNIBILIUM_INCLUDEDIR)
  set(PC_LIBUNIBILIUM_INCLUDE_DIRS)
  set(PC_LIBUNIBILIUM_LIBDIR)
  set(PC_LIBUNIBILIUM_LIBRARY_DIRS)
  set(LIMIT_SEARCH NO_DEFAULT_PATH)
endif()

set(LIBUNIBILIUM_DEFINITIONS ${PC_LIBUNIBILIUM_CFLAGS_OTHER})

find_path(LIBUNIBILIUM_INCLUDE_DIR unibilium.h
          PATHS ${PC_LIBUNIBILIUM_INCLUDEDIR} ${PC_LIBUNIBILIUM_INCLUDE_DIRS}
          ${LIMIT_SEARCH})

# If we're asked to use static linkage, add libuv.a as a preferred library name.
if(LIBUNIBILIUM_USE_STATIC)
  list(APPEND LIBUNIBILIUM_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}unibilium${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

list(APPEND LIBUNIBILIUM_NAMES unibilium)

find_library(LIBUNIBILIUM_LIBRARY NAMES ${LIBUNIBILIUM_NAMES}
  HINTS ${PC_LIBUNIBILIUM_LIBDIR} ${PC_LIBUNIBILIUM_LIBRARY_DIRS}
  ${LIMIT_SEARCH})

set(LIBUNIBILIUM_LIBRARIES ${LIBUNIBILIUM_LIBRARY})
set(LIBUNIBILIUM_INCLUDE_DIRS ${LIBUNIBILIUM_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LIBUNIBILIUM_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(LibUnibilium DEFAULT_MSG
  LIBUNIBILIUM_LIBRARY LIBUNIBILIUM_INCLUDE_DIR)

mark_as_advanced(LIBUNIBILIUM_INCLUDE_DIR LIBUNIBILIUM_LIBRARY)
