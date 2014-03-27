// os.c -- OS-level calls to query hardware, etc.

#include <uv.h>

#include "os/os.h"

// Return total amount of memory available in Kbyte.
// Doesn't change when memory has been allocated.
long_u os_total_mem(int special) {
  // We need to return memory in *Kbytes* but uv_get_total_memory() returns the
  // number of bytes of total memory.
  return uv_get_total_memory() >> 10;
}
