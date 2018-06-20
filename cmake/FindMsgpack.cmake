# - Try to find msgpack
# Once done this will define
#  MSGPACK_FOUND - System has msgpack
#  MSGPACK_INCLUDE_DIRS - The msgpack include directories
#  MSGPACK_LIBRARIES - The libraries needed to use msgpack

if(NOT USE_BUNDLED_MSGPACK)
  find_package(PkgConfig)
  if (PKG_CONFIG_FOUND)
    pkg_search_module(PC_MSGPACK QUIET
      msgpackc>=${Msgpack_FIND_VERSION}
      msgpack>=${Msgpack_FIND_VERSION})
  endif()
else()
  set(PC_MSGPACK_INCLUDEDIR)
  set(PC_MSGPACK_INCLUDE_DIRS)
  set(PC_MSGPACK_LIBDIR)
  set(PC_MSGPACK_LIBRARY_DIRS)
  set(LIMIT_SEARCH NO_DEFAULT_PATH)
endif()

set(MSGPACK_DEFINITIONS ${PC_MSGPACK_CFLAGS_OTHER})

find_path(MSGPACK_INCLUDE_DIR msgpack/version_master.h
  HINTS ${PC_MSGPACK_INCLUDEDIR} ${PC_MSGPACK_INCLUDE_DIRS}
  ${LIMIT_SEARCH})

if(MSGPACK_INCLUDE_DIR)
  file(READ ${MSGPACK_INCLUDE_DIR}/msgpack/version_master.h msgpack_version_h)
  string(REGEX REPLACE ".*MSGPACK_VERSION_MAJOR +([0-9]+).*" "\\1" MSGPACK_VERSION_MAJOR "${msgpack_version_h}")
  string(REGEX REPLACE ".*MSGPACK_VERSION_MINOR +([0-9]+).*" "\\1" MSGPACK_VERSION_MINOR "${msgpack_version_h}")
  string(REGEX REPLACE ".*MSGPACK_VERSION_REVISION +([0-9]+).*" "\\1" MSGPACK_VERSION_REVISION "${msgpack_version_h}")
  set(MSGPACK_VERSION_STRING "${MSGPACK_VERSION_MAJOR}.${MSGPACK_VERSION_MINOR}.${MSGPACK_VERSION_REVISION}")
else()
  set(MSGPACK_VERSION_STRING)
endif()

# If we're asked to use static linkage, add libmsgpack{,c}.a as a preferred library name.
if(MSGPACK_USE_STATIC)
  list(APPEND MSGPACK_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}msgpackc${CMAKE_STATIC_LIBRARY_SUFFIX}"
    "${CMAKE_STATIC_LIBRARY_PREFIX}msgpack${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

if(MSVC)
  # The import library for the msgpack DLL has a different name
  list(APPEND MSGPACK_NAMES msgpackc_import)
else()
  list(APPEND MSGPACK_NAMES msgpackc msgpack)
endif()

find_library(MSGPACK_LIBRARY NAMES ${MSGPACK_NAMES}
  # Check each directory for all names to avoid using headers/libraries from
  # different places.
  NAMES_PER_DIR
  HINTS ${PC_MSGPACK_LIBDIR} ${PC_MSGPACK_LIBRARY_DIRS}
  ${LIMIT_SEARCH})

mark_as_advanced(MSGPACK_INCLUDE_DIR MSGPACK_LIBRARY)

set(MSGPACK_LIBRARIES ${MSGPACK_LIBRARY})
set(MSGPACK_INCLUDE_DIRS ${MSGPACK_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set MSGPACK_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(Msgpack
  REQUIRED_VARS MSGPACK_LIBRARY MSGPACK_INCLUDE_DIR
  VERSION_VAR MSGPACK_VERSION_STRING)

