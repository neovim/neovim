#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "os/event.h"
#include "os/input.h"

static uv_timer_t timer;
static uv_prepare_t timer_prepare;
static void timer_cb(uv_timer_t *handle, int);
static void timer_prepare_cb(uv_prepare_t *, int);

void event_init()
{
  // Initialize input events
  input_init();
  // Timer to wake the event loop if a timeout argument is passed to
  // `event_poll`
  uv_timer_init(uv_default_loop(), &timer);
  // This prepare handle that actually starts the timer
  uv_prepare_init(uv_default_loop(), &timer_prepare);
}

// Wait for some event
bool event_poll(int32_t ms)
{
  bool timed_out;
  uv_run_mode run_mode = UV_RUN_ONCE;

  if (input_ready()) {
    // If there's a pending input event to be consumed, do it now
    return true;
  }

  input_start();
  timed_out = false;

  if (ms > 0) {
    // Timeout passed as argument to the timer
    timer.data = &timed_out;
    // We only start the timer after the loop is running, for that we
    // use an prepare handle(pass the interval as data to it)
    timer_prepare.data = &ms;
    uv_prepare_start(&timer_prepare, timer_prepare_cb);
  } else if (ms == 0) {
    // For ms == 0, we need to do a non-blocking event poll by
    // setting the run mode to UV_RUN_NOWAIT.
    run_mode = UV_RUN_NOWAIT;
  }

  do {
    // Run one event loop iteration, blocking for events if run_mode is
    // UV_RUN_ONCE
    uv_run(uv_default_loop(), run_mode);
  } while (
      // Continue running if ...
      !input_ready()  // ... we have no input
      && run_mode != UV_RUN_NOWAIT  // ... ms != 0
      && !timed_out);  // ... we didn't get a timeout

  input_stop();

  if (ms > 0) {
    // Stop the timer
    uv_timer_stop(&timer);
  }

  return input_ready();
}

// Set a flag in the `event_poll` loop for signaling of a timeout
static void timer_cb(uv_timer_t *handle, int status)
{
  *((bool *)handle->data) = true;
}

static void timer_prepare_cb(uv_prepare_t *handle, int status)
{
  uv_timer_start(&timer, timer_cb, *(uint32_t *)timer_prepare.data, 0);
  uv_prepare_stop(&timer_prepare);
}
