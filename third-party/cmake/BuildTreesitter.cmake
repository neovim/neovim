include(CMakeParseArguments)

# BuildTreeSitter(TARGET targetname CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
function(BuildTreeSitter)
  cmake_parse_arguments(_treesitter
    "BUILD_IN_SOURCE"
    "TARGET"
    "CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})

  if(NOT _treesitter_CONFIGURE_COMMAND AND NOT _treesitter_BUILD_COMMAND
      AND NOT _treesitter_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND,  BUILD_COMMAND, INSTALL_COMMAND")
  endif()
  if(NOT _treesitter_TARGET)
    set(_treesitter_TARGET "tree-sitter")
  endif()

  ExternalProject_Add(tree-sitter
    PREFIX ${DEPS_BUILD_DIR}
    URL ${TREESITTER_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/tree-sitter
    INSTALL_DIR ${DEPS_INSTALL_DIR}
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/tree-sitter
    -DURL=${TREESITTER_URL}
    -DEXPECTED_SHA256=${TREESITTER_SHA256}
    -DTARGET=tree-sitter
    -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    BUILD_IN_SOURCE ${_treesitter_BUILD_IN_SOURCE}
    PATCH_COMMAND ""
    CONFIGURE_COMMAND "${_treesitter_CONFIGURE_COMMAND}"
    BUILD_COMMAND "${_treesitter_BUILD_COMMAND}"
    INSTALL_COMMAND "${_treesitter_INSTALL_COMMAND}")
endfunction()

if(MSVC)
  BuildTreeSitter(BUILD_IN_SOURCE
    CONFIGURE_COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/TreesitterCMakeLists.txt
    ${DEPS_BUILD_DIR}/src/tree-sitter/CMakeLists.txt
    COMMAND ${CMAKE_COMMAND} ${DEPS_BUILD_DIR}/src/tree-sitter/CMakeLists.txt
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
    BUILD_COMMAND ${CMAKE_COMMAND} --build . --config ${CMAKE_BUILD_TYPE}
    INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE}
    )
else()
  set(TS_CFLAGS "-O3 -Wall -Wextra")
  BuildTreeSitter(BUILD_IN_SOURCE
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER} CFLAGS=${TS_CFLAGS}
    INSTALL_COMMAND ${MAKE_PRG} CC=${DEPS_C_COMPILER} PREFIX=${DEPS_INSTALL_DIR} install)
endif()

list(APPEND THIRD_PARTY_DEPS tree-sitter)
