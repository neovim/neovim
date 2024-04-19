# The cargo environment variables are needed to optimize neovim runtime
get_externalproject_options(wasmtime ${DEPS_IGNORE_SHA})
ExternalProject_Add(wasmtime
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/wasmtime
  SOURCE_SUBDIR crates/c-api
  CMAKE_ARGS ${DEPS_CMAKE_ARGS} -D WASMTIME_FASTEST_RUNTIME=ON
  USES_TERMINAL_BUILD TRUE
  ${EXTERNALPROJECT_OPTIONS})
