if(WIN32)
  set(LIBVTERM_CONFIGURE_COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/LibvtermCMakeLists.txt
      ${DEPS_BUILD_DIR}/src/libvterm/CMakeLists.txt
    COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Libvterm-tbl2inc_c.cmake
      ${DEPS_BUILD_DIR}/src/libvterm/tbl2inc_c.cmake
    COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/libvterm
      -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR})
  if(NOT MSVC)
    list(APPEND LIBVTERM_CONFIGURE_COMMAND "-DCMAKE_C_FLAGS:STRING=-fPIC")
  endif()
  set(LIBVTERM_BUILD_COMMAND ${CMAKE_COMMAND} --build . --config $<CONFIG>)
  set(LIBVTERM_INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config $<CONFIG>)
else()
  set(LIBVTERM_INSTALL_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                                           PREFIX=${DEPS_INSTALL_DIR}
                                           CFLAGS=-fPIC
                                           LDFLAGS+=-static
                                           ${DEFAULT_MAKE_CFLAGS}
                                           install)
endif()

if(USE_EXISTING_SRC_DIR)
  unset(LIBVTERM_URL)
endif()
ExternalProject_Add(libvterm
  URL ${LIBVTERM_URL}
  URL_HASH SHA256=${LIBVTERM_SHA256}
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libvterm
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND "${LIBVTERM_CONFIGURE_COMMAND}"
  BUILD_COMMAND "${LIBVTERM_BUILD_COMMAND}"
  INSTALL_COMMAND "${LIBVTERM_INSTALL_COMMAND}")

list(APPEND THIRD_PARTY_DEPS libvterm)
