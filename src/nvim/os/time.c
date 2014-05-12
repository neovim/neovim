#include <stdint.h>
#include <stdbool.h>
#include <sys/time.h>

#include <uv.h>

#include "nvim/os/time.h"
#include "nvim/vim.h"
#include "nvim/term.h"

static uv_mutex_t delay_mutex;
static uv_cond_t delay_cond;

static void microdelay(uint64_t ms);

void time_init()
{
  uv_mutex_init(&delay_mutex);
  uv_cond_init(&delay_cond);
}

void os_delay(uint64_t milliseconds, bool ignoreinput)
{
  os_microdelay(milliseconds * 1000, ignoreinput);
}

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

struct tm *os_localtime_r(const time_t *clock, struct tm *result)
{
#ifdef UNIX
  // POSIX provides localtime_r() as a thread-safe version of localtime().
  return localtime_r(clock, result);
#else
  // Windows version of localtime() is thread-safe.
  // See http://msdn.microsoft.com/en-us/library/bf12f0hc%28VS.80%29.aspx
  struct tm *local_time = localtime(clock);  // NOLINT
  *result = *local_time;
return result;
#endif
}

struct tm *os_get_localtime(struct tm *result)
{
  struct timeval tv;
  if (gettimeofday(&tv, NULL) < 0) {
    return NULL;
  }

  return os_localtime_r(&tv.tv_sec, result);
}
