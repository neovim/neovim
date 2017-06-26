# - Try to find jemalloc
# Once done this will define
#  JEMALLOC_FOUND - System has jemalloc
#  JEMALLOC_INCLUDE_DIRS - The jemalloc include directories
#  JEMALLOC_LIBRARIES - The libraries needed to use jemalloc

if(NOT USE_BUNDLED_JEMALLOC)
  find_package(PkgConfig)
  if (PKG_CONFIG_FOUND)
    pkg_check_modules(PC_JEMALLOC QUIET jemalloc)
  endif()
else()
  set(PC_JEMALLOC_INCLUDEDIR)
  set(PC_JEMALLOC_INCLUDE_DIRS)
  set(PC_JEMALLOC_LIBDIR)
  set(PC_JEMALLOC_LIBRARY_DIRS)
  set(LIMIT_SEARCH NO_DEFAULT_PATH)
endif()

set(JEMALLOC_DEFINITIONS ${PC_JEMALLOC_CFLAGS_OTHER})

find_path(JEMALLOC_INCLUDE_DIR jemalloc/jemalloc.h
          PATHS ${PC_JEMALLOC_INCLUDEDIR} ${PC_JEMALLOC_INCLUDE_DIRS}
          ${LIMIT_SEARCH})

# If we're asked to use static linkage, add libjemalloc.a as a preferred library name.
if(JEMALLOC_USE_STATIC)
  list(APPEND JEMALLOC_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}jemalloc${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

list(APPEND JEMALLOC_NAMES jemalloc)

find_library(JEMALLOC_LIBRARY NAMES ${JEMALLOC_NAMES}
  HINTS ${PC_JEMALLOC_LIBDIR} ${PC_JEMALLOC_LIBRARY_DIRS}
  ${LIMIT_SEARCH})

set(JEMALLOC_LIBRARIES ${JEMALLOC_LIBRARY})
set(JEMALLOC_INCLUDE_DIRS ${JEMALLOC_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set JEMALLOC_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(JeMalloc DEFAULT_MSG
  JEMALLOC_LIBRARY JEMALLOC_INCLUDE_DIR)

mark_as_advanced(JEMALLOC_INCLUDE_DIR JEMALLOC_LIBRARY)
