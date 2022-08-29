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
  if(MSVC)
    list(APPEND LIBVTERM_CONFIGURE_COMMAND "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1}")
  else()
    list(APPEND LIBVTERM_CONFIGURE_COMMAND "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1} -fPIC")
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

ExternalProject_Add(libvterm
  PREFIX ${DEPS_BUILD_DIR}
  URL ${LIBVTERM_URL}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libvterm
  DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libvterm
    -DURL=${LIBVTERM_URL}
    -DEXPECTED_SHA256=${LIBVTERM_SHA256}
    -DTARGET=libvterm
    -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND "${LIBVTERM_CONFIGURE_COMMAND}"
  BUILD_COMMAND "${LIBVTERM_BUILD_COMMAND}"
  INSTALL_COMMAND "${LIBVTERM_INSTALL_COMMAND}")

list(APPEND THIRD_PARTY_DEPS libvterm)
