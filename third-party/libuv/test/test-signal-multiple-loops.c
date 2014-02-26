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


/* This test does not pretend to be cross-platform. */
#ifndef _WIN32

#include "uv.h"
#include "task.h"

#include <errno.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* The value of NUM_SIGNAL_HANDLING_THREADS is not arbitrary; it needs to be a
 * multiple of three for reasons that will become clear when you scroll down.
 * We're basically creating three different thread groups.  The total needs
 * to be divisible by three in order for the numbers in the final check to
 * match up.
 */
#define NUM_SIGNAL_HANDLING_THREADS 24
#define NUM_LOOP_CREATING_THREADS 10

enum signal_action {
  ONLY_SIGUSR1,
  ONLY_SIGUSR2,
  SIGUSR1_AND_SIGUSR2
};

static uv_sem_t sem;
static uv_mutex_t counter_lock;
static volatile int stop = 0;

static volatile int signal1_cb_counter = 0;
static volatile int signal2_cb_counter = 0;
static volatile int loop_creation_counter = 0;


static void increment_counter(volatile int* counter) {
  uv_mutex_lock(&counter_lock);
  ++(*counter);
  uv_mutex_unlock(&counter_lock);
}


static void signal1_cb(uv_signal_t* handle, int signum) {
  ASSERT(signum == SIGUSR1);
  increment_counter(&signal1_cb_counter);
  uv_signal_stop(handle);
}


static void signal2_cb(uv_signal_t* handle, int signum) {
  ASSERT(signum == SIGUSR2);
  increment_counter(&signal2_cb_counter);
  uv_signal_stop(handle);
}


static void signal_handling_worker(void* context) {
  enum signal_action action;
  uv_signal_t signal1a;
  uv_signal_t signal1b;
  uv_signal_t signal2;
  uv_loop_t* loop;
  int r;

  action = (enum signal_action) (uintptr_t) context;

  loop = uv_loop_new();
  ASSERT(loop != NULL);

  /* Setup the signal watchers and start them. */
  if (action == ONLY_SIGUSR1 || action == SIGUSR1_AND_SIGUSR2) {
    r = uv_signal_init(loop, &signal1a);
    ASSERT(r == 0);
    r = uv_signal_start(&signal1a, signal1_cb, SIGUSR1);
    ASSERT(r == 0);
    r = uv_signal_init(loop, &signal1b);
    ASSERT(r == 0);
    r = uv_signal_start(&signal1b, signal1_cb, SIGUSR1);
    ASSERT(r == 0);
  }

  if (action == ONLY_SIGUSR2 || action == SIGUSR1_AND_SIGUSR2) {
    r = uv_signal_init(loop, &signal2);
    ASSERT(r == 0);
    r = uv_signal_start(&signal2, signal2_cb, SIGUSR2);
    ASSERT(r == 0);
  }

  /* Signal watchers are now set up. */
  uv_sem_post(&sem);

  /* Wait for all signals. The signal callbacks stop the watcher, so uv_run
   * will return when all signal watchers caught a signal.
   */
  r = uv_run(loop, UV_RUN_DEFAULT);
  ASSERT(r == 0);

  /* Restart the signal watchers. */
  if (action == ONLY_SIGUSR1 || action == SIGUSR1_AND_SIGUSR2) {
    r = uv_signal_start(&signal1a, signal1_cb, SIGUSR1);
    ASSERT(r == 0);
    r = uv_signal_start(&signal1b, signal1_cb, SIGUSR1);
    ASSERT(r == 0);
  }

  if (action == ONLY_SIGUSR2 || action == SIGUSR1_AND_SIGUSR2) {
    r = uv_signal_start(&signal2, signal2_cb, SIGUSR2);
    ASSERT(r == 0);
  }

  /* Wait for signals once more. */
  uv_sem_post(&sem);

  r = uv_run(loop, UV_RUN_DEFAULT);
  ASSERT(r == 0);

  /* Close the watchers. */
  if (action == ONLY_SIGUSR1 || action == SIGUSR1_AND_SIGUSR2) {
    uv_close((uv_handle_t*) &signal1a, NULL);
    uv_close((uv_handle_t*) &signal1b, NULL);
  }

  if (action == ONLY_SIGUSR2 || action == SIGUSR1_AND_SIGUSR2) {
    uv_close((uv_handle_t*) &signal2, NULL);
  }

  /* Wait for the signal watchers to close. */
  r = uv_run(loop, UV_RUN_DEFAULT);
  ASSERT(r == 0);

  uv_loop_delete(loop);
}


static void signal_unexpected_cb(uv_signal_t* handle, int signum) {
  ASSERT(0 && "signal_unexpected_cb should never be called");
}


static void loop_creating_worker(void* context) {
  (void) context;

  do {
    uv_loop_t* loop;
    uv_signal_t signal;
    int r;

    loop = uv_loop_new();
    ASSERT(loop != NULL);

    r = uv_signal_init(loop, &signal);
    ASSERT(r == 0);

    r = uv_signal_start(&signal, signal_unexpected_cb, SIGTERM);
    ASSERT(r == 0);

    uv_close((uv_handle_t*) &signal, NULL);

    r = uv_run(loop, UV_RUN_DEFAULT);
    ASSERT(r == 0);

    uv_loop_delete(loop);

    increment_counter(&loop_creation_counter);
  } while (!stop);
}


TEST_IMPL(signal_multiple_loops) {
  uv_thread_t loop_creating_threads[NUM_LOOP_CREATING_THREADS];
  uv_thread_t signal_handling_threads[NUM_SIGNAL_HANDLING_THREADS];
  enum signal_action action;
  sigset_t sigset;
  int i;
  int r;

  r = uv_sem_init(&sem, 0);
  ASSERT(r == 0);

  r = uv_mutex_init(&counter_lock);
  ASSERT(r == 0);

  /* Create a couple of threads that create a destroy loops continuously. */
  for (i = 0; i < NUM_LOOP_CREATING_THREADS; i++) {
    r = uv_thread_create(&loop_creating_threads[i],
                         loop_creating_worker,
                         NULL);
    ASSERT(r == 0);
  }

  /* Create a couple of threads that actually handle signals. */
  for (i = 0; i < NUM_SIGNAL_HANDLING_THREADS; i++) {
    switch (i % 3) {
      case 0: action = ONLY_SIGUSR1; break;
      case 1: action = ONLY_SIGUSR2; break;
      case 2: action = SIGUSR1_AND_SIGUSR2; break;
    }

    r = uv_thread_create(&signal_handling_threads[i],
                         signal_handling_worker,
                         (void*) (uintptr_t) action);
    ASSERT(r == 0);
  }

  /* Wait until all threads have started and set up their signal watchers. */
  for (i = 0; i < NUM_SIGNAL_HANDLING_THREADS; i++)
    uv_sem_wait(&sem);

  r = kill(getpid(), SIGUSR1);
  ASSERT(r == 0);
  r = kill(getpid(), SIGUSR2);
  ASSERT(r == 0);

  /* Wait for all threads to handle these signals. */
  for (i = 0; i < NUM_SIGNAL_HANDLING_THREADS; i++)
    uv_sem_wait(&sem);

  /* Block all signals to this thread, so we are sure that from here the signal
   * handler runs in another thread. This is is more likely to catch thread and
   * signal safety issues if there are any.
   */
  sigfillset(&sigset);
  pthread_sigmask(SIG_SETMASK, &sigset, NULL);

  r = kill(getpid(), SIGUSR1);
  ASSERT(r == 0);
  r = kill(getpid(), SIGUSR2);
  ASSERT(r == 0);

  /* Wait for all signal handling threads to exit. */
  for (i = 0; i < NUM_SIGNAL_HANDLING_THREADS; i++) {
    r = uv_thread_join(&signal_handling_threads[i]);
    ASSERT(r == 0);
  }

  /* Tell all loop creating threads to stop. */
  stop = 1;

  /* Wait for all loop creating threads to exit. */
  for (i = 0; i < NUM_LOOP_CREATING_THREADS; i++) {
    r = uv_thread_join(&loop_creating_threads[i]);
    ASSERT(r == 0);
  }

  printf("signal1_cb calls: %d\n", signal1_cb_counter);
  printf("signal2_cb calls: %d\n", signal2_cb_counter);
  printf("loops created and destroyed: %d\n", loop_creation_counter);

  /* The division by three reflects the fact that we spawn three different
   * thread groups of (NUM_SIGNAL_HANDLING_THREADS / 3) threads each.
   */
  ASSERT(signal1_cb_counter == 8 * (NUM_SIGNAL_HANDLING_THREADS / 3));
  ASSERT(signal2_cb_counter == 4 * (NUM_SIGNAL_HANDLING_THREADS / 3));

  /* We don't know exactly how much loops will be created and destroyed, but at
   * least there should be 1 for every loop creating thread.
   */
  ASSERT(loop_creation_counter >= NUM_LOOP_CREATING_THREADS);

  MAKE_VALGRIND_HAPPY();
  return 0;
}

#endif  /* !_WIN32 */
