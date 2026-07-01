#include <emscripten.h>
#include <pthread.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
#include <uv.h>

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

// Report an idle virtual system
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
  *rss = uv_get_total_memory() / 2;
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

int uv__io_fork(uv_loop_t *loop)
{
  (void)loop;
  return 0;
}

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

void uv__platform_invalidate_fd(uv_loop_t *loop, int fd)
{
  (void)loop; (void)fd;
}
int uv__io_check_fd(uv_loop_t *loop, void *w)
{
  (void)loop; (void)w; return 0;
}

// Replaces the kernel poll() call
void uv__io_poll(uv_loop_t *loop, int timeout)
{
  if (timeout > 0) {
    emscripten_sleep(timeout);
    uv_update_time(loop);
    emscripten_sleep(10);
    uv_update_time(loop);
  } else if (timeout == 0) {
    emscripten_sleep(0);
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

// Fakes thread names when nvim tracks or debugs its internal processes
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
  (void)thread; (void)name; return 0;
}
int pthread_setschedparam(pthread_t thread, int policy, const struct sched_param *param)
{
  (void)thread; (void)policy; (void)param; return 0;
}
int sched_get_priority_max(int policy)
{
  (void)policy; return 1;
}
int sched_get_priority_min(int policy)
{
  (void)policy; return 1;
}
