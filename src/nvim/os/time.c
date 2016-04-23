#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>
#include <limits.h>

#include <uv.h>

#include "nvim/os/time.h"
#include "nvim/event/loop.h"
#include "nvim/vim.h"

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

/// Obtain a high-resolution timer value
///
/// @return a timer value, not related to the time of day and not subject
///         to clock drift. The value is expressed in nanoseconds.
uint64_t os_hrtime(void)
{
  return uv_hrtime();
}

/// Sleeps for a certain amount of milliseconds
///
/// @param milliseconds Number of milliseconds to sleep
/// @param ignoreinput If true, allow a SIGINT to interrupt us
void os_delay(uint64_t milliseconds, bool ignoreinput)
{
  if (ignoreinput) {
    if (milliseconds > INT_MAX) {
      milliseconds = INT_MAX;
    }
    LOOP_PROCESS_EVENTS_UNTIL(&loop, NULL, (int)milliseconds, got_int);
  } else {
    os_microdelay(milliseconds * 1000);
  }
}

/// Sleeps for a certain amount of microseconds
///
/// @param microseconds Number of microseconds to sleep
void os_microdelay(uint64_t microseconds)
{
  uint64_t elapsed = 0;
  uint64_t ns = microseconds * 1000;  // convert to nanoseconds
  uint64_t base = uv_hrtime();

  uv_mutex_lock(&delay_mutex);

  while (elapsed < ns) {
    if (uv_cond_timedwait(&delay_cond, &delay_mutex, ns - elapsed)
        == UV_ETIMEDOUT)
      break;
    uint64_t now = uv_hrtime();
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

/// Obtains the current Unix timestamp and adjusts it to local time.
///
/// @param result Pointer to a 'struct tm' where the result should be placed
/// @return A pointer to a 'struct tm' in the current time zone (the 'result'
///         argument) or NULL in case of error
struct tm *os_get_localtime(struct tm *result) FUNC_ATTR_NONNULL_ALL
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
