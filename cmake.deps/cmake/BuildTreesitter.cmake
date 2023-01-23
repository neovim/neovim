if(MSVC)
  set(TREESITTER_CONFIGURE_COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/TreesitterCMakeLists.txt
    ${DEPS_BUILD_DIR}/src/tree-sitter/CMakeLists.txt
    COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/tree-sitter/CMakeLists.txt
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}
      ${BUILD_TYPE_STRING}
      -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR})
  set(TREESITTER_BUILD_COMMAND ${CMAKE_COMMAND} --build . --config $<CONFIG>)
  set(TREESITTER_INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config $<CONFIG>)
else()
  set(TREESITTER_BUILD_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER})
  set(TREESITTER_INSTALL_COMMAND
    ${MAKE_PRG} CC=${DEPS_C_COMPILER} PREFIX=${DEPS_INSTALL_DIR} install)
endif()

if(USE_EXISTING_SRC_DIR)
  unset(TREESITTER_URL)
endif()
ExternalProject_Add(tree-sitter
  URL ${TREESITTER_URL}
  URL_HASH SHA256=${TREESITTER_SHA256}
  DOWNLOAD_NO_PROGRESS TRUE
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/tree-sitter
  INSTALL_DIR ${DEPS_INSTALL_DIR}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND "${TREESITTER_CONFIGURE_COMMAND}"
  BUILD_COMMAND "${TREESITTER_BUILD_COMMAND}"
  INSTALL_COMMAND "${TREESITTER_INSTALL_COMMAND}")

list(APPEND THIRD_PARTY_DEPS tree-sitter)
