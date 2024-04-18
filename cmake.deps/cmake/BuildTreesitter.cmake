get_externalproject_options(treesitter ${DEPS_IGNORE_SHA})
ExternalProject_Add(treesitter
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/treesitter
  PATCH_COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/TreesitterCMakeLists.txt
    ${DEPS_BUILD_DIR}/src/treesitter/CMakeLists.txt
  CMAKE_ARGS ${DEPS_CMAKE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})
