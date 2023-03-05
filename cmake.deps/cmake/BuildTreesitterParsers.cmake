function(BuildTSParser)
  cmake_parse_arguments(TS
    ""
    "LANG;URL;SHA256;CMAKE_FILE"
    ""
    ${ARGN})

  set(NAME treesitter-${TS_LANG})
  ExternalProject_Add(${NAME}
    URL ${TS_URL}
    URL_HASH SHA256=${TS_SHA256}
    DOWNLOAD_NO_PROGRESS TRUE
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/${NAME}
    PATCH_COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/${TS_CMAKE_FILE}
      ${DEPS_BUILD_DIR}/src/${NAME}/CMakeLists.txt
    CMAKE_ARGS ${DEPS_CMAKE_ARGS}
      -D PARSERLANG=${TS_LANG}
    CMAKE_CACHE_ARGS ${DEPS_CMAKE_CACHE_ARGS})
endfunction()

BuildTSParser(
  LANG c
  URL ${TREESITTER_C_URL}
  SHA256 ${TREESITTER_C_SHA256}
  CMAKE_FILE TreesitterParserCMakeLists.txt)

BuildTSParser(
  LANG lua
  URL ${TREESITTER_LUA_URL}
  SHA256 ${TREESITTER_LUA_SHA256}
  CMAKE_FILE TreesitterParserCMakeLists.txt)

BuildTSParser(
  LANG vim
  URL ${TREESITTER_VIM_URL}
  SHA256 ${TREESITTER_VIM_SHA256}
  CMAKE_FILE TreesitterParserCMakeLists.txt)

BuildTSParser(
  LANG help
  URL ${TREESITTER_HELP_URL}
  SHA256 ${TREESITTER_HELP_SHA256}
  CMAKE_FILE TreesitterParserCMakeLists.txt)

BuildTSParser(
  LANG query
  URL ${TREESITTER_QUERY_URL}
  SHA256 ${TREESITTER_QUERY_SHA256}
  CMAKE_FILE TreesitterParserCMakeLists.txt)
