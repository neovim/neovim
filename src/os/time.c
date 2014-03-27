#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "vim.h"
#include "term.h"

static uv_mutex_t delay_mutex;
static uv_cond_t delay_cond;

static void delay(uint64_t ms);

void time_init()
{
  uv_mutex_init(&delay_mutex);
  uv_cond_init(&delay_cond);
}

void os_delay(uint64_t ms, bool ignoreinput)
{
  int old_tmode;

  if (ignoreinput) {
    // Go to cooked mode without echo, to allow SIGINT interrupting us
    // here.  But we don't want QUIT to kill us (CTRL-\ used in a
    // shell may produce SIGQUIT).
    in_os_delay = true;
    old_tmode = curr_tmode;

    if (curr_tmode == TMODE_RAW)
      settmode(TMODE_SLEEP);

    delay(ms);

    settmode(old_tmode);
    in_os_delay = false;
  } else {
    delay(ms);
  }
}

static void delay(uint64_t ms)
{
  uint64_t hrtime;
  int64_t ns = ms * 1000000;  // convert to nanoseconds

  uv_mutex_lock(&delay_mutex);

  while (ns > 0) {
    hrtime =  uv_hrtime();
    if (uv_cond_timedwait(&delay_cond, &delay_mutex, ns) == UV_ETIMEDOUT)
      break;
    ns -= uv_hrtime() - hrtime;
  }

  uv_mutex_unlock(&delay_mutex);
}
