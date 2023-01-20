set(MSGPACK_CMAKE_ARGS
    -DMSGPACK_BUILD_TESTS=OFF
    -DMSGPACK_BUILD_EXAMPLES=OFF
    -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
    -DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}
    ${BUILD_TYPE_STRING})

if(NOT MSVC)
  list(APPEND MSGPACK_CMAKE_ARGS
    "-DCMAKE_C_FLAGS:STRING=-fPIC")
endif()

if(USE_EXISTING_SRC_DIR)
  unset(MSGPACK_URL)
endif()
ExternalProject_Add(msgpack
  URL ${MSGPACK_URL}
  URL_HASH SHA256=${MSGPACK_SHA256}
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/msgpack
  CMAKE_ARGS "${MSGPACK_CMAKE_ARGS}"
  CMAKE_CACHE_ARGS
    -DCMAKE_OSX_ARCHITECTURES:STRING=${CMAKE_OSX_ARCHITECTURES})

list(APPEND THIRD_PARTY_DEPS msgpack)
