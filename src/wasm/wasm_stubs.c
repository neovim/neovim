#include <emscripten.h>
#include <emscripten/threading.h>
#include <math.h>
#include <poll.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
#include <uv.h>

void uv__io_cb(uv_loop_t *loop, uv__io_t *w, unsigned events);

// System info stubs

uint64_t uv_get_free_memory(void)
{
  return 8 * 1024 * 1024;
}
uint64_t uv_get_total_memory(void)
{
  return 256 * 1024 * 1024;
}
uint64_t uv_get_available_memory(void)
{
  return uv_get_free_memory();
}
uint64_t uv_get_constrained_memory(void)
{
  return uv_get_total_memory();
}

void uv_loadavg(double avg[3])
{
  avg[0] = 0.0; avg[1] = 0.0; avg[2] = 0.0;
}

int uv_uptime(double *uptime)
{
  if (!uptime) {
    return UV_EINVAL;
  }
  *uptime = emscripten_get_now() / 1000.0;
  return 0;
}

int uv_resident_set_memory(size_t *rss)
{
  if (!rss) {
    return UV_EINVAL;
  }
  *rss = uv_get_total_memory() / 2;  // fake value
  return 0;
}

int uv_exepath(char *buffer, size_t *size)
{
  if (!buffer || !size) {
    return UV_EINVAL;
  }
  const char *exepath = "/nvim.wasm";
  size_t len = strlen(exepath);
  if (*size <= len) {
    *size = len + 1;
    return UV_ENOBUFS;
  }
  memcpy(buffer, exepath, len);
  buffer[len] = '\0';
  *size = len;
  return 0;
}

// Browsers have no native CPU information. So return a single virtual CPU
int uv_cpu_info(uv_cpu_info_t * *cpu_infos, int *count)
{
  if (!cpu_infos || !count) {
    return UV_EINVAL;
  }
  *cpu_infos = (uv_cpu_info_t *)malloc(sizeof(uv_cpu_info_t));
  if (!*cpu_infos) {
    return UV_ENOMEM;
  }

  uv_cpu_info_t *cpu = *cpu_infos;
  cpu->model = "WebAssembly Virtual CPU";
  cpu->speed = 0;
  cpu->cpu_times.user = 0; cpu->cpu_times.nice = 0; cpu->cpu_times.sys = 0;
  cpu->cpu_times.idle = 0; cpu->cpu_times.irq = 0;
  *count = 1;
  return 0;
}

// Browsers do not expose host network interfaces. Report only loopback.
int uv_interface_addresses(uv_interface_address_t * *addresses, int *count)
{
  if (!addresses || !count) {
    return UV_EINVAL;
  }
  *addresses = (uv_interface_address_t *)malloc(sizeof(uv_interface_address_t));
  if (!*addresses) {
    return UV_ENOMEM;
  }

  uv_interface_address_t *addr = *addresses;
  memset(addr, 0, sizeof(uv_interface_address_t));
  addr->name = strdup("lo");
  if (!addr->name) {
    free(addr); return UV_ENOMEM;
  }
  addr->is_internal = 1;
  uv_ip4_addr("127.0.0.1", 0, (struct sockaddr_in *)&addr->address);
  uv_ip4_addr("255.0.0.0", 0, (struct sockaddr_in *)&addr->netmask);
  *count = 1;
  return 0;
}

#define UV_BROWSER_MAX_FD 256

typedef struct {
  _Atomic uint32_t generation;                   // woken on any fd state change
  _Atomic int32_t readable[UV_BROWSER_MAX_FD];
  _Atomic int32_t writable[UV_BROWSER_MAX_FD];
} uv_browser_shared_state_t;

static uv_browser_shared_state_t g_shared_state;

EMSCRIPTEN_KEEPALIVE
void *uv_browser_get_shared_state_ptr(void)
{
  return (void *)&g_shared_state;
}

EMSCRIPTEN_KEEPALIVE
void uv_browser_set_readable(int fd, int32_t nbytes)
{
  if (fd < 0 || fd >= UV_BROWSER_MAX_FD) {
    return;
  }
  atomic_store(&g_shared_state.readable[fd], nbytes);
  atomic_fetch_add(&g_shared_state.generation, 1);
  emscripten_futex_wake(&g_shared_state.generation, 1);
}

EMSCRIPTEN_KEEPALIVE
void uv_browser_set_writable(int fd, int32_t nbytes)
{
  if (fd < 0 || fd >= UV_BROWSER_MAX_FD) {
    return;
  }
  atomic_store(&g_shared_state.writable[fd], nbytes);
  atomic_fetch_add(&g_shared_state.generation, 1);
  emscripten_futex_wake(&g_shared_state.generation, 1);
}

static int uv_browser_scan_ready(uv_loop_t *loop, unsigned *out_idx, int *out_revents)
{
  unsigned i;
  uv__io_t *w;
  int revents;

  for (i = 0; i < loop->nwatchers && i < UV_BROWSER_MAX_FD; i++) {
    w = loop->watchers[i];
    if (w == NULL || w->pevents == 0) {
      continue;
    }

    revents = 0;
    if ((w->pevents & POLLIN) && atomic_load(&g_shared_state.readable[i]) > 0) {
      revents |= POLLIN;
    }
    if ((w->pevents & POLLOUT) && atomic_load(&g_shared_state.writable[i]) > 0) {
      revents |= POLLOUT;
    }

    if (revents) {
      *out_idx = i;
      *out_revents = revents;
      return 1;
    }
  }
  return 0;
}

void uv__io_poll(uv_loop_t *loop, int timeout)
{
  double deadline;
  double remaining;
  uint32_t g0;
  unsigned idx;
  int revents;
  int have_signal;
  uv__io_t *w;

  deadline = (timeout < 0) ? -1.0 : (emscripten_get_now() + (double)timeout);
  have_signal = 0;

  while (true) {
    /* Any state change that lands between this load and the scan below is still caught by the scan
       itself. Any change that lands after the scan will bump generation past g0, so the futex_wait call
       falls through immediately instead of sleeping through it. This closes the narrow window where a notify
       could otherwise land between "nothing is ready" and "waiting". */

    g0 = atomic_load(&g_shared_state.generation);

    if (uv_browser_scan_ready(loop, &idx, &revents)) {
      have_signal = 1;
      break;
    }

    if (deadline >= 0.0) {
      remaining = deadline - emscripten_get_now();
      if (remaining <= 0.0) {
        break;
      }
    } else {
      remaining = 60000.0;
    }

    int rc = emscripten_futex_wait(&g_shared_state.generation, g0, remaining);
  }

  uv_update_time(loop);

  if (!have_signal) {
    return;
  }

  for (idx = 0; idx < loop->nwatchers && idx < UV_BROWSER_MAX_FD; idx++) {
    w = loop->watchers[idx];
    if (w == NULL || w->pevents == 0) {
      continue;
    }

    revents = 0;
    if ((w->pevents & POLLIN) && atomic_load(&g_shared_state.readable[idx]) > 0) {
      revents |= POLLIN;
    }
    if ((w->pevents & POLLOUT) && atomic_load(&g_shared_state.writable[idx]) > 0) {
      revents |= POLLOUT;
    }

    revents &= w->pevents | POLLERR | POLLHUP;

    if (revents == 0) {
      continue;
    }

    uv__io_cb(loop, w, revents);
  }
}

int uv__platform_loop_init(uv_loop_t *loop)
{
  if (!loop) {
    return UV_EINVAL;
  }
  loop->backend_fd = -1;
  return 0;
}

void uv__platform_loop_delete(uv_loop_t *loop)
{
  (void)loop;
}

void uv__platform_invalidate_fd(uv_loop_t *loop, int fd)
{
  if (fd < 0 || fd >= UV_BROWSER_MAX_FD) {
    return;
  }
  atomic_store(&g_shared_state.readable[fd], 0);
  atomic_store(&g_shared_state.writable[fd], 0);
}

int uv__io_check_fd(uv_loop_t *loop, int fd)
{
  (void)loop; (void)fd;
  return 0;
}

int uv__io_fork(uv_loop_t *loop)
{
  (void)loop;
  return 0;
}

// pthread shims

int pthread_getname_np(pthread_t thread, char *name, size_t len)
{
  (void)thread;
  if (!name || len < 1) {
    return EINVAL;
  }
  strncpy(name, "nvim-main", len - 1);
  name[len - 1] = '\0';
  return 0;
}

int pthread_setname_np(pthread_t thread, const char *name)
{
  (void)thread; (void)name;
  return 0;
}

int pthread_setschedparam(pthread_t thread, int policy, const struct sched_param *param)
{
  (void)thread; (void)policy; (void)param;
  return 0;
}
