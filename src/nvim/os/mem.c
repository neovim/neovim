// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// Functions for accessing system memory information.

#include <uv.h>

#include "nvim/os/os.h"

/// Get the total system physical memory in KiB.
uint64_t os_get_total_mem_kib(void)
{
  // Convert bytes to KiB.
  return uv_get_total_memory() / 1024;
}
