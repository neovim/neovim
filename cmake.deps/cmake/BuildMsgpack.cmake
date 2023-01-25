if(USE_EXISTING_SRC_DIR)
  unset(MSGPACK_URL)
endif()
ExternalProject_Add(msgpack
  URL ${MSGPACK_URL}
  URL_HASH SHA256=${MSGPACK_SHA256}
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/msgpack
  CMAKE_ARGS ${DEPS_CMAKE_ARGS}
    -DMSGPACK_BUILD_TESTS=OFF
    -DMSGPACK_BUILD_EXAMPLES=OFF
  CMAKE_CACHE_ARGS ${DEPS_CMAKE_CACHE_ARGS})

list(APPEND THIRD_PARTY_DEPS msgpack)
