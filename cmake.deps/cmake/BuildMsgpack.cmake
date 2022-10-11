set(MSGPACK_CONFIGURE_COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/msgpack
  -DMSGPACK_BUILD_TESTS=OFF
  -DMSGPACK_BUILD_EXAMPLES=OFF
  -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
  -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
  -DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES_ALT_SEP}
  "-DCMAKE_C_FLAGS:STRING=-fPIC"
  -DCMAKE_GENERATOR=${CMAKE_GENERATOR})

if(MSVC)
  # The msgpack project has a dependency on C++ compiler.
  # The string `MSGPACK_CXX_COMPILER` is used to specify the C++ compiler.
  # If the C++ compiler has been been specified, that one is used, and
  # `MSGPACK_CXX_COMPILER` is set to "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}".
  # Otherwise, if LLVM/clang-cl is used as the C compiler, it shall also be used
  # as the C++ compiler for consistency, and `MSGPACK_CXX_COMPILER` # is set to
  # "-DCMAKE_CXX_COMPILER=${CMAKE_C_COMPILER}".
  # Otherwise, `MSGPACK_CXX_COMPILER` remains an empty string, which shall not
  # break other builds.
  set(MSGPACK_CXX_COMPILER)
  if(CMAKE_CXX_COMPILER)
    set(MSGPACK_CXX_COMPILER -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER})
  elseif(CMAKE_C_COMPILER_ID MATCHES "Clang")
    set(MSGPACK_CXX_COMPILER -DCMAKE_CXX_COMPILER=${CMAKE_C_COMPILER})
  endif()
  # Same as Unix without fPIC
  set(MSGPACK_CONFIGURE_COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/msgpack
    -DMSGPACK_BUILD_TESTS=OFF
    -DMSGPACK_BUILD_EXAMPLES=OFF
    -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    ${MSGPACK_CXX_COMPILER}
    -DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}
    ${BUILD_TYPE_STRING}
    # Make sure we use the same generator, otherwise we may
    # accidentally end up using different MSVC runtimes
    -DCMAKE_GENERATOR=${CMAKE_GENERATOR})
endif()

if(USE_EXISTING_SRC_DIR)
  unset(MSGPACK_URL)
endif()
ExternalProject_Add(msgpack
  URL ${MSGPACK_URL}
  URL_HASH SHA256=${MSGPACK_SHA256}
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/msgpack
  CONFIGURE_COMMAND "${MSGPACK_CONFIGURE_COMMAND}"
  BUILD_COMMAND ${CMAKE_COMMAND} --build . --config $<CONFIG>
  INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config $<CONFIG>
  LIST_SEPARATOR |)

list(APPEND THIRD_PARTY_DEPS msgpack)
