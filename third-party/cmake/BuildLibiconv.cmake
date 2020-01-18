if(MSVC)

  ExternalProject_Add(libiconv
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LIBICONV_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libiconv
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libiconv
      -DURL=${LIBICONV_URL}
      -DEXPECTED_SHA256=${LIBICONV_SHA256}
      -DTARGET=libiconv
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/LibiconvCMakeLists.txt
        ${DEPS_BUILD_DIR}/src/libiconv/CMakeLists.txt
      COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/libiconv
        -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
        # Pass toolchain
        -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
    BUILD_COMMAND ${CMAKE_COMMAND} --build . --config ${CMAKE_BUILD_TYPE}
    INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE})

else()
  message(FATAL_ERROR "Trying to build libiconv in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

list(APPEND THIRD_PARTY_DEPS libiconv)
