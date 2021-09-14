// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <limits.h>
#include <uv.h>

#include "nvim/assert.h"
#include "nvim/event/loop.h"
#include "nvim/main.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"

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
/// @see uv_sleep() (libuv v1.34.0)
///
/// @param ms          Number of milliseconds to sleep
/// @param ignoreinput If true, only SIGINT (CTRL-C) can interrupt.
void os_delay(uint64_t ms, bool ignoreinput)
{
  DLOG("%" PRIu64 " ms", ms);
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
/// @see uv_sleep() (libuv v1.34.0)
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
      abort();
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

// Cache of the current timezone name as retrieved from TZ, or an empty string
// where unset, up to 64 octets long including trailing null byte.
static char tz_cache[64];

/// Portable version of POSIX localtime_r()
///
/// @return NULL in case of error
struct tm *os_localtime_r(const time_t *restrict clock,
                          struct tm *restrict result) FUNC_ATTR_NONNULL_ALL
{
#ifdef UNIX
  // POSIX provides localtime_r() as a thread-safe version of localtime().
  //
  // Check to see if the environment variable TZ has changed since the last run.
  // Call tzset(3) to update the global timezone variables if it has.
  // POSIX standard doesn't require localtime_r() implementations to do that
  // as it does with localtime(), and we don't want to call tzset() every time.
  const char *tz = os_getenv("TZ");
  if (tz == NULL) {
    tz = "";
  }
  if (strncmp(tz_cache, tz, sizeof(tz_cache) - 1) != 0) {
    tzset();
    xstrlcpy(tz_cache, tz, sizeof(tz_cache));
  }
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

/// Portable version of POSIX ctime_r()
///
/// @param clock[in]
/// @param result[out] Pointer to a 'char' where the result should be placed
/// @param result_len length of result buffer
/// @return human-readable string of current local time
char *os_ctime_r(const time_t *restrict clock, char *restrict result, size_t result_len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  struct tm clock_local;
  struct tm *clock_local_ptr = os_localtime_r(clock, &clock_local);
  // MSVC returns NULL for an invalid value of seconds.
  if (clock_local_ptr == NULL) {
    xstrlcpy(result, _("(Invalid)"), result_len);
  } else {
    strftime(result, result_len, _("%a %b %d %H:%M:%S %Y"), clock_local_ptr);
  }
  xstrlcat(result, "\n", result_len);
  return result;
}

/// Gets the current Unix timestamp and adjusts it to local time.
///
/// @param result[out] Pointer to a 'char' where the result should be placed
/// @param result_len length of result buffer
/// @return human-readable string of current local time
char *os_ctime(char *result, size_t result_len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  time_t rawtime = time(NULL);
  return os_ctime_r(&rawtime, result, result_len);
}

/// Portable version of POSIX strptime()
///
/// @param str[in]  string to convert
/// @param format[in]  format to parse "str"
/// @param tm[out]  time representation of "str"
/// @return Pointer to first unprocessed character or NULL
char *os_strptime(const char *str, const char *format, struct tm *tm)
  FUNC_ATTR_NONNULL_ALL
{
#ifdef HAVE_STRPTIME
  return strptime(str, format, tm);
#else
  return NULL;
#endif
}

/// Obtains the current Unix timestamp.
///
/// @return Seconds since epoch.
Timestamp os_time(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (Timestamp)time(NULL);
}
