// wasm/shim.h - Emscripten/WASM build shim.
//
// This header is force-included into EVERY emcc compilation (deps + nvim) via
// the EMCC_CFLAGS environment variable set by wasm/build-deps.sh and
// wasm/build-nvim.sh:
//
//     export EMCC_CFLAGS="-include /abs/path/to/wasm/shim.h"
//
// emcc prepends EMCC_CFLAGS to every invocation, so this is a uniform way to
// patch over small portability gaps in third-party sources (libuv, lua, ...)
// without modifying the upstream tarballs. Everything here is guarded by
// __EMSCRIPTEN__ so it is a no-op for any non-emscripten compiler that happens
// to pick the header up.
//
// Keep this minimal and well-documented: each shim should explain *why* it is
// needed.

#ifndef NVIM_WASM_SHIM_H
#define NVIM_WASM_SHIM_H

#ifdef __EMSCRIPTEN__

#include <stddef.h>
#include <pthread.h>  // for pthread_t (a pointer type under emscripten)

// ---------------------------------------------------------------------------
// pthread thread-name helpers.
//
// libuv's src/unix/thread.c unconditionally calls pthread_setname_np() /
// pthread_getname_np() on the generic POSIX path. Emscripten's <pthread.h>
// only *declares* these under _GNU_SOURCE, so when libuv is compiled WITHOUT
// _GNU_SOURCE the build fails with -Werror=implicit-function-declaration. We
// provide trivial inline stubs so libuv compiles; they get baked into libuv.a.
//
// Neovim itself compiles with -D_GNU_SOURCE, where <pthread.h> already declares
// these (and never references them in nvim code, since libuv.a carries the
// inlined stubs). Defining our own `static inline` there would clash with the
// real prototype, so the stubs are guarded out when _GNU_SOURCE is present.
#if !defined(_GNU_SOURCE) && !defined(__USE_GNU)

#ifdef __cplusplus
extern "C" {
#endif

static inline int pthread_setname_np(pthread_t thread, const char *name)
{
  (void)thread;
  (void)name;
  return 0;
}

static inline int pthread_getname_np(pthread_t thread, char *name, size_t len)
{
  (void)thread;
  if (name != NULL && len > 0) {
    name[0] = '\0';
  }
  return 0;
}

#ifdef __cplusplus
}
#endif

#endif  // !_GNU_SOURCE && !__USE_GNU

#endif  // __EMSCRIPTEN__

#endif  // NVIM_WASM_SHIM_H
