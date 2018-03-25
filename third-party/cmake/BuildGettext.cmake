if(MSVC)

  ExternalProject_Add(gettext
    PREFIX ${DEPS_BUILD_DIR}
    URL ${GETTEXT_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/gettext
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/gettext
      -DURL=${GETTEXT_URL}
      -DEXPECTED_SHA256=${GETTEXT_SHA256}
      -DTARGET=gettext
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    PATCH_COMMAND ${GIT_EXECUTABLE} -C ${DEPS_BUILD_DIR}/src/gettext init
      COMMAND ${GIT_EXECUTABLE} -C ${DEPS_BUILD_DIR}/src/gettext apply --ignore-whitespace
        ${CMAKE_CURRENT_SOURCE_DIR}/patches/gettext-Fix-compilation-on-a-system-without-alloca.patch
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/GettextCMakeLists.txt
        ${DEPS_BUILD_DIR}/src/gettext/gettext-runtime/CMakeLists.txt
      COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/gettext/gettext-runtime
        -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
        # Pass toolchain
        -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
    BUILD_COMMAND ${CMAKE_COMMAND} --build . --config ${CMAKE_BUILD_TYPE}
    INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE})

else()
  message(FATAL_ERROR "Trying to build gettext in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

list(APPEND THIRD_PARTY_DEPS gettext)
