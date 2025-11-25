if(ENABLE_WASMTIME)
  set(TREESITTER_ARGS -D TREE_SITTER_FEATURE_WASM=ON)
endif()

get_externalproject_options(treesitter ${DEPS_IGNORE_SHA})
ExternalProject_Add(treesitter
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/treesitter
  CMAKE_ARGS ${DEPS_CMAKE_ARGS} ${TREESITTER_ARGS}
  ${EXTERNALPROJECT_OPTIONS})

if(USE_BUNDLED_WASMTIME)
  add_dependencies(treesitter wasmtime)
endif()
