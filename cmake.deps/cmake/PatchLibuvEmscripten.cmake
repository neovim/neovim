# PatchLibuvEmscripten.cmake
#
# libuv's CMake build has no branch for CMAKE_SYSTEM_NAME == "Emscripten", so a
# wasm build selects no platform I/O backend and leaves uv__io_poll(),
# uv__platform_loop_init(), uv__hrtime() etc. undefined. This script inserts an
# Emscripten branch that pulls in libuv's portable poll(2) backend (which
# Emscripten's libc supports), plus the no-op fsevents/proctitle files.
#
# System-info functions normally found in src/unix/linux.c (uv_uptime,
# uv_cpu_info, uv_get_*_memory, ...) are intentionally NOT added here; Neovim's
# wasm/uv_stubs.c supplies conservative versions instead.
#
# Invoked as a PATCH_COMMAND from BuildLibuv.cmake. Idempotent (guarded by a
# marker comment), so re-running ExternalProject is safe.

# --- 1. include uv/posix.h on Emscripten -----------------------------------
# include/uv/unix.h selects a platform header that defines the loop's private
# fields. There is no Emscripten case and no fallback, so posix-poll.c can't see
# loop->poll_fds. Emscripten uses the generic poll() backend, so it wants the
# same header as Cygwin/Haiku/QNX/GNU-Hurd: uv/posix.h.
set(uv_unix_h "${LIBUV_SRC}/include/uv/unix.h")
file(READ "${uv_unix_h}" unix_h)
if(NOT unix_h MATCHES "__EMSCRIPTEN__")
  set(_before "${unix_h}")
  string(REPLACE
    "      defined(__GNU__)\n# include \"uv/posix.h\""
    "      defined(__GNU__)    || \\\n      defined(__EMSCRIPTEN__)\n# include \"uv/posix.h\""
    unix_h "${unix_h}")
  if(unix_h STREQUAL _before)
    message(FATAL_ERROR
      "PatchLibuvEmscripten: anchor 'defined(__GNU__)\\n# include \"uv/posix.h\"' "
      "not found in ${uv_unix_h}; upstream libuv layout changed -- update this patch.")
  endif()
  file(WRITE "${uv_unix_h}" "${unix_h}")
  message(STATUS "Patched libuv include/uv/unix.h to use uv/posix.h on Emscripten")
endif()

# --- 2. add an Emscripten source branch ------------------------------------
set(libuv_cmakelists "${LIBUV_SRC}/CMakeLists.txt")
file(READ "${libuv_cmakelists}" contents)

if(contents MATCHES "Emscripten-wasm-backend")
  message(STATUS "libuv CMakeLists already patched for Emscripten")
  return()
endif()

set(emscripten_branch
"# Emscripten-wasm-backend (added by Neovim's wasm build)
if(CMAKE_SYSTEM_NAME STREQUAL \"Emscripten\")
  list(APPEND uv_defines _GNU_SOURCE)
  list(APPEND uv_sources
       src/unix/no-fsevents.c
       src/unix/no-proctitle.c
       src/unix/posix-hrtime.c
       src/unix/posix-poll.c)
endif()

add_library(uv_a STATIC")

set(_before "${contents}")
string(REPLACE "add_library(uv_a STATIC" "${emscripten_branch}" contents "${contents}")
if(contents STREQUAL _before)
  message(FATAL_ERROR
    "PatchLibuvEmscripten: anchor 'add_library(uv_a STATIC' not found in "
    "${libuv_cmakelists}; upstream libuv layout changed -- update this patch.")
endif()
file(WRITE "${libuv_cmakelists}" "${contents}")
message(STATUS "Patched libuv CMakeLists.txt with Emscripten poll() backend")
