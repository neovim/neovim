# Helper function to download treesitter parsers
#
# Single value arguments:
# LANG        - Parser language
# CMAKE_FILE  - Cmake file to build the parser with. Defaults to
#               TreesitterParserCMakeLists.txt.
function(BuildTSParser)
  cmake_parse_arguments(TS
    ""
    "LANG;CMAKE_FILE"
    ""
    ${ARGN})

  if(NOT TS_CMAKE_FILE)
    set(TS_CMAKE_FILE TreesitterParserCMakeLists.txt)
  endif()

  set(NAME treesitter_${TS_LANG})

  get_externalproject_options(${NAME} ${DEPS_IGNORE_SHA})
  ExternalProject_Add(${NAME}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/${NAME}
    PATCH_COMMAND ${CMAKE_COMMAND} -E copy
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/${TS_CMAKE_FILE}
      ${DEPS_BUILD_DIR}/src/${NAME}/CMakeLists.txt
    CMAKE_ARGS ${DEPS_CMAKE_ARGS}
      -D PARSERLANG=${TS_LANG}
    ${EXTERNALPROJECT_OPTIONS})
endfunction()

foreach(lang c lua vim vimdoc query)
  BuildTSParser(LANG ${lang})
endforeach()
BuildTSParser(LANG markdown CMAKE_FILE MarkdownParserCMakeLists.txt)

if(USE_BUNDLED_TS_PARSERS AND ENABLE_WASMTIME)
  if(DEPS_IGNORE_SHA)
    set(_lua_wasm_hash "")
  else()
    set(_lua_wasm_hash "URL_HASH;SHA256=${TREESITTER_LUA_WASM_SHA256}")
  endif()
  ExternalProject_Add(treesitter_lua_wasm
    DOWNLOAD_NO_PROGRESS TRUE
    DOWNLOAD_NO_EXTRACT TRUE
    URL ${TREESITTER_LUA_WASM_URL}
    ${_lua_wasm_hash}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/treesitter_lua_wasm
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy
      ${DEPS_DOWNLOAD_DIR}/treesitter_lua_wasm/tree-sitter-lua.wasm
      ${DEPS_INSTALL_DIR}/lib/nvim/parser/lua.wasm)
endif()
