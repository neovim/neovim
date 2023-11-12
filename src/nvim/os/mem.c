/// Functions for accessing system memory information.

#include <stdint.h>
#include <uv.h>

#include "nvim/os/os.h"

/// Get the total system physical memory in KiB.
uint64_t os_get_total_mem_kib(void)
{
  // Convert bytes to KiB.
  return uv_get_total_memory() / 1024;
}
