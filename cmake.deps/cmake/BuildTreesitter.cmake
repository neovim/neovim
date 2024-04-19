if(ENABLE_WASMTIME)
  if(USE_BUNDLED_WASMTIME)
    set(WASMTIME_CACHE_ARGS "-DCMAKE_C_FLAGS:STRING=-I${DEPS_INSTALL_DIR}/include/wasmtime -I${DEPS_INSTALL_DIR}/include")
  else()
    find_package(Wasmtime 24.0.0 EXACT REQUIRED)
    set(WASMTIME_CACHE_ARGS "-DCMAKE_C_FLAGS:STRING=-I${WASMTIME_INCLUDE_DIR}")
  endif()
  string(APPEND WASMTIME_CACHE_ARGS " -DTREE_SITTER_FEATURE_WASM")
  set(WASMTIME_ARGS -D CMAKE_C_STANDARD=11)
endif()

get_externalproject_options(treesitter ${DEPS_IGNORE_SHA})
ExternalProject_Add(treesitter
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/treesitter
  PATCH_COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/TreesitterCMakeLists.txt
    ${DEPS_BUILD_DIR}/src/treesitter/CMakeLists.txt
  CMAKE_ARGS ${DEPS_CMAKE_ARGS} ${WASMTIME_ARGS}
  CMAKE_CACHE_ARGS ${WASMTIME_CACHE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})

if(USE_BUNDLED_WASMTIME)
  add_dependencies(treesitter wasmtime)
endif()
