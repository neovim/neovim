#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#include <uv.h>

#include "nvim/os/time.h"
#include "nvim/vim.h"
#include "nvim/term.h"

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
  os_microdelay(milliseconds * 1000, ignoreinput);
}

/// Sleeps for a certain amount of microseconds
///
/// @param microseconds Number of microseconds to sleep
/// @param ignoreinput If true, allow a SIGINT to interrupt us
void os_microdelay(uint64_t microseconds, bool ignoreinput)
{
  int old_tmode;

  if (ignoreinput) {
    // Go to cooked mode without echo, to allow SIGINT interrupting us
    // here
    old_tmode = curr_tmode;

    if (curr_tmode == TMODE_RAW)
      settmode(TMODE_SLEEP);

    microdelay(microseconds);

    settmode(old_tmode);
  } else {
    microdelay(microseconds);
  }
}

static void microdelay(uint64_t microseconds)
{
  uint64_t hrtime;
  int64_t ns = microseconds * 1000;  // convert to nanoseconds

  uv_mutex_lock(&delay_mutex);

  while (ns > 0) {
    hrtime =  uv_hrtime();
    if (uv_cond_timedwait(&delay_cond, &delay_mutex, ns) == UV_ETIMEDOUT)
      break;
    ns -= uv_hrtime() - hrtime;
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
  return localtime_r(clock, result);
#else
  // Windows version of localtime() is thread-safe.
  // See http://msdn.microsoft.com/en-us/library/bf12f0hc%28VS.80%29.aspx
  struct tm *local_time = localtime(clock);  // NOLINT
  if (!local_time) {
    return NULL;
  }
  *result = *local_time;
  return result;
#endif
}

/// Obtains the current UNIX timestamp and adjusts it to local time
///
/// @param result Pointer to a 'struct tm' where the result should be placed
/// @return A pointer to a 'struct tm' in the current time zone (the 'result'
///         argument) or NULL in case of error
struct tm *os_get_localtime(struct tm *result) FUNC_ATTR_NONNULL_ALL
{
  time_t rawtime = time(NULL);
  return os_localtime_r(&rawtime, result);
}
