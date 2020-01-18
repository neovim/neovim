include(CMakeParseArguments)

# BuildLibvterm(CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Failing to pass a command argument will result in no command being run
function(BuildLibvterm)
  cmake_parse_arguments(_libvterm
    ""
    ""
    "PATCH_COMMAND;CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})

  if(NOT _libvterm_CONFIGURE_COMMAND AND NOT _libvterm_BUILD_COMMAND
       AND NOT _libvterm_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND, BUILD_COMMAND, INSTALL_COMMAND")
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
    PATCH_COMMAND "${_libvterm_PATCH_COMMAND}"
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND "${_libvterm_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_libvterm_BUILD_COMMAND}"
    INSTALL_COMMAND "${_libvterm_INSTALL_COMMAND}")
endfunction()

if(WIN32)
  if(MSVC)
    set(LIBVTERM_PATCH_COMMAND
    ${GIT_EXECUTABLE} -C ${DEPS_BUILD_DIR}/src/libvterm init
      COMMAND ${GIT_EXECUTABLE} -C ${DEPS_BUILD_DIR}/src/libvterm apply --ignore-whitespace
        ${CMAKE_CURRENT_SOURCE_DIR}/patches/libvterm-Remove-VLAs-for-MSVC.patch)
  endif()
  set(LIBVTERM_CONFIGURE_COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/LibvtermCMakeLists.txt
      ${DEPS_BUILD_DIR}/src/libvterm/CMakeLists.txt
    COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Libvterm-tbl2inc_c.cmake
      ${DEPS_BUILD_DIR}/src/libvterm/tbl2inc_c.cmake
    COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/libvterm
      -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_COMPILER_ARG1} -fPIC"
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR})
  set(LIBVTERM_BUILD_COMMAND ${CMAKE_COMMAND} --build . --config ${CMAKE_BUILD_TYPE})
  set(LIBVTERM_INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE})
else()
  set(LIBVTERM_INSTALL_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER}
                                           PREFIX=${DEPS_INSTALL_DIR}
                                           CFLAGS=-fPIC
                                           LDFLAGS+=-static
                                           ${DEFAULT_MAKE_CFLAGS}
                                           install)
endif()

BuildLibvterm(PATCH_COMMAND ${LIBVTERM_PATCH_COMMAND}
  CONFIGURE_COMMAND ${LIBVTERM_CONFIGURE_COMMAND}
  BUILD_COMMAND ${LIBVTERM_BUILD_COMMAND}
  INSTALL_COMMAND ${LIBVTERM_INSTALL_COMMAND})

list(APPEND THIRD_PARTY_DEPS libvterm)
