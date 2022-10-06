if(MSVC)
  if(USE_EXISTING_SRC_DIR)
    unset(LIBICONV_URL)
  endif()
  ExternalProject_Add(libiconv
    URL ${LIBICONV_URL}
    URL_HASH SHA256=${LIBICONV_SHA256}
    DOWNLOAD_NO_PROGRESS TRUE
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libiconv
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/LibiconvCMakeLists.txt
        ${DEPS_BUILD_DIR}/src/libiconv/CMakeLists.txt
      COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/libiconv
        -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
        ${BUILD_TYPE_STRING}
        -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
        -DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}
    BUILD_COMMAND ${CMAKE_COMMAND} --build . --config $<CONFIG>
    INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config $<CONFIG>)
else()
  message(FATAL_ERROR "Trying to build libiconv in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

list(APPEND THIRD_PARTY_DEPS libiconv)
