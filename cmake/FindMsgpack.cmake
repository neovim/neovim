# - Try to find msgpack
# Once done this will define
#  MSGPACK_FOUND - System has msgpack
#  MSGPACK_INCLUDE_DIRS - The msgpack include directories
#  MSGPACK_LIBRARIES - The libraries needed to use msgpack

find_package(PkgConfig)
if(NOT MSGPACK_USE_BUNDLED)
  find_package(PkgConfig)
  if (PKG_CONFIG_FOUND)
    pkg_check_modules(PC_MSGPACK QUIET msgpack)
  endif()
else()
  set(PC_MSGPACK_INCLUDEDIR)
  set(PC_MSGPACK_INCLUDE_DIRS)
  set(PC_MSGPACK_LIBDIR)
  set(PC_MSGPACK_LIBRARY_DIRS)
  set(LIMIT_SEARCH NO_DEFAULT_PATH)
endif()

set(MSGPACK_DEFINITIONS ${PC_MSGPACK_CFLAGS_OTHER})

find_path(MSGPACK_INCLUDE_DIR msgpack.h
  HINTS ${PC_MSGPACK_INCLUDEDIR} ${PC_MSGPACK_INCLUDE_DIRS}
  ${LIMIT_SEARCH})

# If we're asked to use static linkage, add libmsgpackc.a as a preferred library name.
if(MSGPACK_USE_STATIC)
  list(APPEND MSGPACK_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}msgpackc${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

list(APPEND MSGPACK_NAMES msgpackc)

find_library(MSGPACK_LIBRARY NAMES ${MSGPACK_NAMES}
  HINTS ${PC_MSGPACK_LIBDIR} ${PC_MSGPACK_LIBRARY_DIRS}
  ${LIMIT_SEARCH})

mark_as_advanced(MSGPACK_INCLUDE_DIR MSGPACK_LIBRARY)

set(MSGPACK_LIBRARIES ${MSGPACK_LIBRARY})
set(MSGPACK_INCLUDE_DIRS ${MSGPACK_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set MSGPACK_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(Msgpack DEFAULT_MSG
                                  MSGPACK_LIBRARY MSGPACK_INCLUDE_DIR)

