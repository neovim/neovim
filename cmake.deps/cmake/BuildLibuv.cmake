# Emscripten: libuv has no platform branch for the wasm runtime, so teach its
# CMake build to use the portable poll() backend. See PatchLibuvEmscripten.cmake.
if(EMSCRIPTEN)
  set(LIBUV_PATCH_COMMAND PATCH_COMMAND ${CMAKE_COMMAND}
    -D LIBUV_SRC=${DEPS_BUILD_DIR}/src/libuv
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/PatchLibuvEmscripten.cmake)
endif()

get_externalproject_options(libuv ${DEPS_IGNORE_SHA})
ExternalProject_Add(libuv
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libuv
  ${LIBUV_PATCH_COMMAND}
  CMAKE_ARGS ${DEPS_CMAKE_ARGS}
    -D CMAKE_INSTALL_LIBDIR=lib
    -D BUILD_TESTING=OFF
    -D LIBUV_BUILD_SHARED=OFF
    -D UV_LINT_W4=OFF
  ${EXTERNALPROJECT_OPTIONS})
