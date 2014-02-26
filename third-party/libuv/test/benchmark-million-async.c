/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#include "task.h"
#include "uv.h"

struct async_container {
  unsigned async_events;
  unsigned handles_seen;
  uv_async_t async_handles[1024 * 1024];
};

static volatile int done;
static uv_thread_t thread_id;
static struct async_container* container;


static unsigned fastrand(void) {
  static unsigned g = 0;
  g = g * 214013 + 2531011;
  return g;
}


static void thread_cb(void* arg) {
  unsigned i;

  while (done == 0) {
    i = fastrand() % ARRAY_SIZE(container->async_handles);
    uv_async_send(container->async_handles + i);
  }
}


static void async_cb(uv_async_t* handle, int status) {
  container->async_events++;
  handle->data = handle;
}


static void timer_cb(uv_timer_t* handle, int status) {
  unsigned i;

  done = 1;
  ASSERT(0 == uv_thread_join(&thread_id));

  for (i = 0; i < ARRAY_SIZE(container->async_handles); i++) {
    uv_async_t* handle = container->async_handles + i;

    if (handle->data != NULL)
      container->handles_seen++;

    uv_close((uv_handle_t*) handle, NULL);
  }

  uv_close((uv_handle_t*) handle, NULL);
}


BENCHMARK_IMPL(million_async) {
  uv_timer_t timer_handle;
  uv_async_t* handle;
  uv_loop_t* loop;
  int timeout;
  unsigned i;

  loop = uv_default_loop();
  timeout = 5000;

  container = malloc(sizeof(*container));
  ASSERT(container != NULL);
  container->async_events = 0;
  container->handles_seen = 0;

  for (i = 0; i < ARRAY_SIZE(container->async_handles); i++) {
    handle = container->async_handles + i;
    ASSERT(0 == uv_async_init(loop, handle, async_cb));
    handle->data = NULL;
  }

  ASSERT(0 == uv_timer_init(loop, &timer_handle));
  ASSERT(0 == uv_timer_start(&timer_handle, timer_cb, timeout, 0));
  ASSERT(0 == uv_thread_create(&thread_id, thread_cb, NULL));
  ASSERT(0 == uv_run(loop, UV_RUN_DEFAULT));
  printf("%s async events in %.1f seconds (%s/s, %s unique handles seen)\n",
          fmt(container->async_events),
          timeout / 1000.,
          fmt(container->async_events / (timeout / 1000.)),
          fmt(container->handles_seen));
  free(container);

  MAKE_VALGRIND_HAPPY();
  return 0;
}
