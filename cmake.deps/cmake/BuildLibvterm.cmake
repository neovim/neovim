get_externalproject_options(libvterm ${DEPS_IGNORE_SHA})
ExternalProject_Add(libvterm
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libvterm
  PATCH_COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/LibvtermCMakeLists.txt
    ${DEPS_BUILD_DIR}/src/libvterm/CMakeLists.txt
  CMAKE_ARGS ${DEPS_CMAKE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})
