#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "os/event.h"
#include "os/input.h"

static uv_timer_t timer_req;
static void timer_cb(uv_timer_t *handle, int);

void event_init()
{
  /* Initialize input events */
  input_init();
  /* Timer to wake the event loop if a timeout argument is passed to
   * `event_poll` */
  uv_timer_init(uv_default_loop(), &timer_req);
}

/* Wait for some event */
bool event_poll(int32_t ms)
{
  bool timed_out;
  uv_run_mode run_mode = UV_RUN_ONCE;

  if (input_ready()) {
    /* If there's a pending input event to be consumed, do it now */
    return true;
  }

  input_start();
  timed_out = false;

  if (ms > 0) {
    /* Timeout passed as argument, start the libuv timer to wake us up and 
     * set our local flag */
    timer_req.data = &timed_out;
    uv_timer_start(&timer_req, timer_cb, ms, 0);
  } else if (ms == 0) {
    /* 
     * For ms == 0, we need to do a non-blocking event poll by
     * setting the run mode to UV_RUN_NOWAIT.
     */
    run_mode = UV_RUN_NOWAIT;
  }

  do {
    /* Run one event loop iteration, blocking for events if run_mode is
     * UV_RUN_ONCE */
    uv_run(uv_default_loop(), run_mode);
  } while (
      /* Continue running if ... */
      !input_ready() && /* ... we have no input */
      run_mode != UV_RUN_NOWAIT && /* ... ms != 0 */
      !timed_out  /* ... we didn't get a timeout */
      );

  input_stop();

  if (!timed_out && ms > 0) {
    /* Timer event did not trigger, stop the watcher since we no longer
     * care about it */
    uv_timer_stop(&timer_req);
  }

  return input_ready();
}

/* Set a flag in the `event_poll` loop for signaling of a timeout */
static void timer_cb(uv_timer_t *handle, int status)
{
  *((bool *)handle->data) = true;
}
