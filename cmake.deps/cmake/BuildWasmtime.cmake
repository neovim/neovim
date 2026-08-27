# wasmtime is a chungus -- optimize _extra hard_ to keep nvim svelte
get_externalproject_options(wasmtime ${DEPS_IGNORE_SHA})
ExternalProject_Add(wasmtime
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/wasmtime
  SOURCE_SUBDIR crates/c-api
  CMAKE_ARGS ${DEPS_CMAKE_ARGS}
    -D WASMTIME_FASTEST_RUNTIME=ON       # build with full LTO
    -D WASMTIME_DISABLE_ALL_FEATURES=ON  # don't need all that crap...
    -D WASMTIME_FEATURE_CRANELIFT=ON     # ...except this one (compiles wasm to platform code)
    -D WASMTIME_FEATURE_GC=ON            # ...and this one (needed by ts to create engines)
    -D WASMTIME_FEATURE_GC_NULL=ON       # ...and this one (reasons)
  USES_TERMINAL_BUILD TRUE
  ${EXTERNALPROJECT_OPTIONS})
