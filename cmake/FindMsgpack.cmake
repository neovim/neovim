find_path2(MSGPACK_INCLUDE_DIR msgpack/version_master.h)

if(MSGPACK_INCLUDE_DIR)
  file(READ ${MSGPACK_INCLUDE_DIR}/msgpack/version_master.h msgpack_version_h)
  string(REGEX REPLACE ".*MSGPACK_VERSION_MAJOR +([0-9]+).*" "\\1" MSGPACK_VERSION_MAJOR "${msgpack_version_h}")
  string(REGEX REPLACE ".*MSGPACK_VERSION_MINOR +([0-9]+).*" "\\1" MSGPACK_VERSION_MINOR "${msgpack_version_h}")
  string(REGEX REPLACE ".*MSGPACK_VERSION_REVISION +([0-9]+).*" "\\1" MSGPACK_VERSION_REVISION "${msgpack_version_h}")
  set(MSGPACK_VERSION_STRING "${MSGPACK_VERSION_MAJOR}.${MSGPACK_VERSION_MINOR}.${MSGPACK_VERSION_REVISION}")
else()
  set(MSGPACK_VERSION_STRING)
endif()

find_library2(MSGPACK_LIBRARY NAMES msgpackc msgpack msgpackc_import msgpack-c
  NAMES_PER_DIR)

mark_as_advanced(MSGPACK_INCLUDE_DIR MSGPACK_LIBRARY)

find_package_handle_standard_args(Msgpack
  REQUIRED_VARS MSGPACK_LIBRARY MSGPACK_INCLUDE_DIR
  VERSION_VAR MSGPACK_VERSION_STRING)

add_library(msgpack INTERFACE)
target_include_directories(msgpack SYSTEM BEFORE INTERFACE ${MSGPACK_INCLUDE_DIR})
target_link_libraries(msgpack INTERFACE ${MSGPACK_LIBRARY})
