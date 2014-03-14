/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * os.c -- OS-level calls to query hardware, etc.
 */

#include <uv.h>

#include "os/os.h"

/*
 * Return total amount of memory available in Kbyte.
 * Doesn't change when memory has been allocated.
 */
long_u mch_total_mem(int special) {
  /* We need to return memory in *Kbytes* but uv_get_total_memory() returns the
   * number of bytes of total memory. */
  return uv_get_total_memory() >> 10;
}
