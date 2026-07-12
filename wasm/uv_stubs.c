// wasm/uv_stubs.c - libuv functions missing from the Emscripten build.
//
// libuv's Emscripten/wasm target omits its Linux-specific source file
// (src/unix/linux.c) and the inotify-based fs-event backend, so a handful of
// public libuv symbols end up undefined at link time. They are referenced both
// by Neovim core and by luv (vim.uv). We provide conservative implementations
// here. This file is linked into nvim_bin ONLY for the Emscripten build (see
// src/nvim/CMakeLists.txt, guarded by `if(EMSCRIPTEN)`), so native builds use
// the real libuv implementations.
//
// Design notes:
//   * System-info queries (memory/loadavg/uptime/cpu) return benign constants
//     or UV_ENOSYS. Neovim only uses these for option defaults and `vim.uv`
//     introspection; none are load-bearing for editing.
//   * Filesystem watching (uv_fs_event_*) returns UV_ENOSYS, mirroring libuv's
//     own src/unix/no-fsevents.c. Callers (autoread, vim.uv.new_fs_event) treat
//     ENOSYS as "watching unsupported" and degrade gracefully.

#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <uv.h>

// --- executable path -------------------------------------------------------
// Neovim calls uv_exepath() to locate $VIMRUNTIME relative to the binary. In
// the wasm runtime there is no real executable path; the launcher sets
// $VIMRUNTIME explicitly, so this only needs to be non-fatal. We report a
// stable, plausible path.
int uv_exepath(char *buffer, size_t *size)
{
  static const char path[] = "/usr/bin/nvim";
  if (buffer == NULL || size == NULL || *size == 0) {
    return UV_EINVAL;
  }
  size_t n = sizeof(path) - 1;
  if (n >= *size) {
    n = *size - 1;
  }
  memcpy(buffer, path, n);
  buffer[n] = '\0';
  *size = n;
  return 0;
}

// --- system info -----------------------------------------------------------
int uv_uptime(double *uptime)
{
  if (uptime != NULL) {
    *uptime = 0.0;
  }
  return 0;
}

void uv_loadavg(double avg[3])
{
  avg[0] = avg[1] = avg[2] = 0.0;
}

uint64_t uv_get_total_memory(void)
{
  return (uint64_t)2 * 1024 * 1024 * 1024;  // 2 GiB
}

uint64_t uv_get_free_memory(void)
{
  return (uint64_t)1 * 1024 * 1024 * 1024;  // 1 GiB
}

uint64_t uv_get_constrained_memory(void)
{
  return 0;  // "no limit known"
}

uint64_t uv_get_available_memory(void)
{
  return (uint64_t)1 * 1024 * 1024 * 1024;  // 1 GiB
}

int uv_resident_set_memory(size_t *rss)
{
  if (rss != NULL) {
    *rss = 0;
  }
  return 0;
}

int uv_cpu_info(uv_cpu_info_t **cpu_infos, int *count)
{
  *cpu_infos = NULL;
  *count = 0;
  return UV_ENOSYS;
}

int uv_interface_addresses(uv_interface_address_t **addresses, int *count)
{
  *addresses = NULL;
  *count = 0;
  return UV_ENOSYS;
}

// Note: uv_{get,set}_process_title and uv_fs_event_{init,start,stop} are NOT
// stubbed here: the Emscripten libuv build (patched via
// PatchLibuvEmscripten.cmake) pulls in libuv's own src/unix/no-proctitle.c and
// src/unix/no-fsevents.c, which provide portable no-op implementations.

// --- libc scheduling gaps --------------------------------------------------
// libuv's src/unix/thread.c references these POSIX scheduling functions (for
// uv_thread_create thread priorities). Emscripten *declares* them in
// <pthread.h>/<sched.h> but its libc provides no implementation, so they are
// undefined when linking the prebuilt libuv.a into nvim. Neovim never creates
// prioritized threads in the wasm runtime, so trivial stubs suffice.
#include <pthread.h>
#include <sched.h>

// libuv's thread.c (compiled with _GNU_SOURCE in our Emscripten branch) calls
// pthread_setname_np()/pthread_getname_np(). Emscripten declares them under
// _GNU_SOURCE but its libc has no implementation, so they're undefined when the
// prebuilt libuv.a is linked. Thread names are meaningless in the wasm runtime.
// (wasm/shim.h only stubs these for translation units compiled WITHOUT
// _GNU_SOURCE; this file is compiled WITH it, matching the real prototype.)
int pthread_setname_np(pthread_t thread, const char *name)
{
  (void)thread;
  (void)name;
  return 0;
}

int pthread_getname_np(pthread_t thread, char *name, size_t len)
{
  (void)thread;
  if (name != NULL && len > 0) {
    name[0] = '\0';
  }
  return 0;
}

int sched_get_priority_max(int policy)
{
  (void)policy;
  return 0;
}

int sched_get_priority_min(int policy)
{
  (void)policy;
  return 0;
}

int pthread_setschedparam(pthread_t thread, int policy,
                          const struct sched_param *param)
{
  (void)thread;
  (void)policy;
  (void)param;
  return 0;
}
