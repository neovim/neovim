if(USE_EXISTING_SRC_DIR)
  unset(UNIBILIUM_URL)
endif()
ExternalProject_Add(unibilium
  URL ${UNIBILIUM_URL}
  URL_HASH SHA256=${UNIBILIUM_SHA256}
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/unibilium
  CMAKE_ARGS
    -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
    -DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}
    -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    ${BUILD_TYPE_STRING})

list(APPEND THIRD_PARTY_DEPS unibilium)
