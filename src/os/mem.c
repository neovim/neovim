/// Functions for accessing system memory information.

#include <uv.h>

#include "os/os.h"

long_u os_get_total_mem_kib(void) {
  // Convert bytes to KiB.
  return uv_get_total_memory() >> 10;
}
