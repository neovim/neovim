find_path(MSGPACK_INCLUDE_DIR msgpack/version_master.h)

if(MSGPACK_INCLUDE_DIR)
  file(READ ${MSGPACK_INCLUDE_DIR}/msgpack/version_master.h msgpack_version_h)
  string(REGEX REPLACE ".*MSGPACK_VERSION_MAJOR +([0-9]+).*" "\\1" MSGPACK_VERSION_MAJOR "${msgpack_version_h}")
  string(REGEX REPLACE ".*MSGPACK_VERSION_MINOR +([0-9]+).*" "\\1" MSGPACK_VERSION_MINOR "${msgpack_version_h}")
  string(REGEX REPLACE ".*MSGPACK_VERSION_REVISION +([0-9]+).*" "\\1" MSGPACK_VERSION_REVISION "${msgpack_version_h}")
  set(MSGPACK_VERSION_STRING "${MSGPACK_VERSION_MAJOR}.${MSGPACK_VERSION_MINOR}.${MSGPACK_VERSION_REVISION}")
else()
  set(MSGPACK_VERSION_STRING)
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
  NAMES_PER_DIR)

mark_as_advanced(MSGPACK_INCLUDE_DIR MSGPACK_LIBRARY)

set(MSGPACK_LIBRARIES ${MSGPACK_LIBRARY})
set(MSGPACK_INCLUDE_DIRS ${MSGPACK_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set MSGPACK_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(Msgpack
  REQUIRED_VARS MSGPACK_LIBRARY MSGPACK_INCLUDE_DIR
  VERSION_VAR MSGPACK_VERSION_STRING)
