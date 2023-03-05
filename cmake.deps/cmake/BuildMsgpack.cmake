ExternalProject_Add(msgpack
  URL ${MSGPACK_URL}
  URL_HASH SHA256=${MSGPACK_SHA256}
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/msgpack
  CMAKE_ARGS ${DEPS_CMAKE_ARGS}
    -D MSGPACK_BUILD_TESTS=OFF
    -D MSGPACK_BUILD_EXAMPLES=OFF
  CMAKE_CACHE_ARGS ${DEPS_CMAKE_CACHE_ARGS})

if (NOT MSVC)
  add_custom_target(clean_shared_libraries_msgpack ALL
    COMMAND ${CMAKE_COMMAND}
      -D REMOVE_FILE_GLOB=${DEPS_LIB_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}*${CMAKE_SHARED_LIBRARY_SUFFIX}*
      -P ${PROJECT_SOURCE_DIR}/cmake/RemoveFiles.cmake)
  add_dependencies(clean_shared_libraries_msgpack msgpack)
endif()
