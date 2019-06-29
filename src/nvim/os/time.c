// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>
#include <limits.h>

#include <uv.h>

#include "nvim/assert.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"
#include "nvim/event/loop.h"
#include "nvim/vim.h"
#include "nvim/main.h"

static uv_mutex_t delay_mutex;
static uv_cond_t delay_cond;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/time.c.generated.h"
#endif

/// Initializes the time module
void time_init(void)
{
  uv_mutex_init(&delay_mutex);
  uv_cond_init(&delay_cond);
}

/// Gets the current time with microsecond (μs) precision.
///
/// Subject to system-clock quirks (drift, going backwards, skipping).
/// But it is much faster than os_hrtime() on some systems. #10328
///
/// @see gettimeofday(2)
///
/// @return Current time in microseconds.
uint64_t os_utime(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  uv_timeval64_t tm;
  int e = uv_gettimeofday(&tm);
  if (e != 0 || tm.tv_sec < 0 || tm.tv_usec < 0) {
    return 0;
  }
  uint64_t rv = (uint64_t)tm.tv_sec * 1000 * 1000;  // s => μs
  STRICT_ADD(rv, tm.tv_usec, &rv, uint64_t);
  return rv;
}

/// Gets a high-resolution (nanosecond), monotonically-increasing time relative
/// to an arbitrary time in the past.
///
/// Not related to the time of day and therefore not subject to clock drift.
///
/// @return Relative time value with nanosecond precision.
uint64_t os_hrtime(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return uv_hrtime();
}

/// Gets a millisecond-resolution, monotonically-increasing time relative to an
/// arbitrary time in the past.
///
/// Not related to the time of day and therefore not subject to clock drift.
/// The value is cached by the loop, it will not change until the next
/// loop-tick (unless uv_update_time is called).
///
/// @return Relative time value with millisecond precision.
uint64_t os_now(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return uv_now(&main_loop.uv);
}

/// Sleeps for `ms` milliseconds.
///
/// @param ms          Number of milliseconds to sleep
/// @param ignoreinput If true, only SIGINT (CTRL-C) can interrupt.
void os_delay(uint64_t ms, bool ignoreinput)
{
  if (ignoreinput) {
    if (ms > INT_MAX) {
      ms = INT_MAX;
    }
    LOOP_PROCESS_EVENTS_UNTIL(&main_loop, NULL, (int)ms, got_int);
  } else {
    os_microdelay(ms * 1000u, ignoreinput);
  }
}

/// Sleeps for `us` microseconds.
///
/// @param us          Number of microseconds to sleep.
/// @param ignoreinput If true, ignore all input (including SIGINT/CTRL-C).
///                    If false, waiting is aborted on any input.
void os_microdelay(uint64_t us, bool ignoreinput)
{
  uint64_t elapsed = 0u;
  uint64_t base = uv_hrtime();
  // Convert microseconds to nanoseconds, or UINT64_MAX on overflow.
  const uint64_t ns = (us < UINT64_MAX / 1000u) ? us * 1000u : UINT64_MAX;

  uv_mutex_lock(&delay_mutex);

  while (elapsed < ns) {
    // If ignoring input, we simply wait the full delay.
    // Else we check for input in ~100ms intervals.
    const uint64_t ns_delta = ignoreinput
                              ? ns - elapsed
                              : MIN(ns - elapsed, 100000000u);  // 100ms

    const int rv = uv_cond_timedwait(&delay_cond, &delay_mutex, ns_delta);
    if (0 != rv && UV_ETIMEDOUT != rv) {
      assert(false);
      break;
    }  // Else: Timeout proceeded normally.

    if (!ignoreinput && os_char_avail()) {
      break;
    }

    const uint64_t now = uv_hrtime();
    elapsed += now - base;
    base = now;
  }

  uv_mutex_unlock(&delay_mutex);
}

/// Portable version of POSIX localtime_r()
///
/// @return NULL in case of error
struct tm *os_localtime_r(const time_t *restrict clock,
                          struct tm *restrict result) FUNC_ATTR_NONNULL_ALL
{
#ifdef UNIX
  // POSIX provides localtime_r() as a thread-safe version of localtime().
  return localtime_r(clock, result);  // NOLINT(runtime/threadsafe_fn)
#else
  // Windows version of localtime() is thread-safe.
  // See http://msdn.microsoft.com/en-us/library/bf12f0hc%28VS.80%29.aspx
  struct tm *local_time = localtime(clock);  // NOLINT(runtime/threadsafe_fn)
  if (!local_time) {
    return NULL;
  }
  *result = *local_time;
  return result;
#endif
}

/// Gets the current Unix timestamp and adjusts it to local time.
///
/// @param result Pointer to a 'struct tm' where the result should be placed
/// @return A pointer to a 'struct tm' in the current time zone (the 'result'
///         argument) or NULL in case of error
struct tm *os_localtime(struct tm *result) FUNC_ATTR_NONNULL_ALL
{
  time_t rawtime = time(NULL);
  return os_localtime_r(&rawtime, result);
}

/// Obtains the current Unix timestamp.
///
/// @return Seconds since epoch.
Timestamp os_time(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (Timestamp) time(NULL);
}
