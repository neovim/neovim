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

#include "internal.h"
#include <stdlib.h>

#define MAX_THREADPOOL_SIZE 128

static uv_once_t once = UV_ONCE_INIT;
static uv_cond_t cond;
static uv_mutex_t mutex;
static unsigned int nthreads;
static uv_thread_t* threads;
static uv_thread_t default_threads[4];
static QUEUE exit_message;
static QUEUE wq;
static volatile int initialized;


static void uv__cancelled(struct uv__work* w) {
  abort();
}


/* To avoid deadlock with uv_cancel() it's crucial that the worker
 * never holds the global mutex and the loop-local mutex at the same time.
 */
static void worker(void* arg) {
  struct uv__work* w;
  QUEUE* q;

  (void) arg;

  for (;;) {
    uv_mutex_lock(&mutex);

    while (QUEUE_EMPTY(&wq))
      uv_cond_wait(&cond, &mutex);

    q = QUEUE_HEAD(&wq);

    if (q == &exit_message)
      uv_cond_signal(&cond);
    else {
      QUEUE_REMOVE(q);
      QUEUE_INIT(q);  /* Signal uv_cancel() that the work req is
                             executing. */
    }

    uv_mutex_unlock(&mutex);

    if (q == &exit_message)
      break;

    w = QUEUE_DATA(q, struct uv__work, wq);
    w->work(w);

    uv_mutex_lock(&w->loop->wq_mutex);
    w->work = NULL;  /* Signal uv_cancel() that the work req is done
                        executing. */
    QUEUE_INSERT_TAIL(&w->loop->wq, &w->wq);
    uv_async_send(&w->loop->wq_async);
    uv_mutex_unlock(&w->loop->wq_mutex);
  }
}


static void post(QUEUE* q) {
  uv_mutex_lock(&mutex);
  QUEUE_INSERT_TAIL(&wq, q);
  uv_cond_signal(&cond);
  uv_mutex_unlock(&mutex);
}


static void init_once(void) {
  unsigned int i;
  const char* val;

  nthreads = ARRAY_SIZE(default_threads);
  val = getenv("UV_THREADPOOL_SIZE");
  if (val != NULL)
    nthreads = atoi(val);
  if (nthreads == 0)
    nthreads = 1;
  if (nthreads > MAX_THREADPOOL_SIZE)
    nthreads = MAX_THREADPOOL_SIZE;

  threads = default_threads;
  if (nthreads > ARRAY_SIZE(default_threads)) {
    threads = malloc(nthreads * sizeof(threads[0]));
    if (threads == NULL) {
      nthreads = ARRAY_SIZE(default_threads);
      threads = default_threads;
    }
  }

  if (uv_cond_init(&cond))
    abort();

  if (uv_mutex_init(&mutex))
    abort();

  QUEUE_INIT(&wq);

  for (i = 0; i < nthreads; i++)
    if (uv_thread_create(threads + i, worker, NULL))
      abort();

  initialized = 1;
}


UV_DESTRUCTOR(static void cleanup(void)) {
  unsigned int i;

  if (initialized == 0)
    return;

  post(&exit_message);

  for (i = 0; i < nthreads; i++)
    if (uv_thread_join(threads + i))
      abort();

  if (threads != default_threads)
    free(threads);

  uv_mutex_destroy(&mutex);
  uv_cond_destroy(&cond);

  threads = NULL;
  nthreads = 0;
  initialized = 0;
}


void uv__work_submit(uv_loop_t* loop,
                     struct uv__work* w,
                     void (*work)(struct uv__work* w),
                     void (*done)(struct uv__work* w, int status)) {
  uv_once(&once, init_once);
  w->loop = loop;
  w->work = work;
  w->done = done;
  post(&w->wq);
}


static int uv__work_cancel(uv_loop_t* loop, uv_req_t* req, struct uv__work* w) {
  int cancelled;

  uv_mutex_lock(&mutex);
  uv_mutex_lock(&w->loop->wq_mutex);

  cancelled = !QUEUE_EMPTY(&w->wq) && w->work != NULL;
  if (cancelled)
    QUEUE_REMOVE(&w->wq);

  uv_mutex_unlock(&w->loop->wq_mutex);
  uv_mutex_unlock(&mutex);

  if (!cancelled)
    return -EBUSY;

  w->work = uv__cancelled;
  uv_mutex_lock(&loop->wq_mutex);
  QUEUE_INSERT_TAIL(&loop->wq, &w->wq);
  uv_async_send(&loop->wq_async);
  uv_mutex_unlock(&loop->wq_mutex);

  return 0;
}


void uv__work_done(uv_async_t* handle, int status) {
  struct uv__work* w;
  uv_loop_t* loop;
  QUEUE* q;
  QUEUE wq;
  int err;

  loop = container_of(handle, uv_loop_t, wq_async);
  QUEUE_INIT(&wq);

  uv_mutex_lock(&loop->wq_mutex);
  if (!QUEUE_EMPTY(&loop->wq)) {
    q = QUEUE_HEAD(&loop->wq);
    QUEUE_SPLIT(&loop->wq, q, &wq);
  }
  uv_mutex_unlock(&loop->wq_mutex);

  while (!QUEUE_EMPTY(&wq)) {
    q = QUEUE_HEAD(&wq);
    QUEUE_REMOVE(q);

    w = container_of(q, struct uv__work, wq);
    err = (w->work == uv__cancelled) ? -ECANCELED : 0;
    w->done(w, err);
  }
}


static void uv__queue_work(struct uv__work* w) {
  uv_work_t* req = container_of(w, uv_work_t, work_req);

  req->work_cb(req);
}


static void uv__queue_done(struct uv__work* w, int err) {
  uv_work_t* req;

  req = container_of(w, uv_work_t, work_req);
  uv__req_unregister(req->loop, req);

  if (req->after_work_cb == NULL)
    return;

  req->after_work_cb(req, err);
}


int uv_queue_work(uv_loop_t* loop,
                  uv_work_t* req,
                  uv_work_cb work_cb,
                  uv_after_work_cb after_work_cb) {
  if (work_cb == NULL)
    return -EINVAL;

  uv__req_init(loop, req, UV_WORK);
  req->loop = loop;
  req->work_cb = work_cb;
  req->after_work_cb = after_work_cb;
  uv__work_submit(loop, &req->work_req, uv__queue_work, uv__queue_done);
  return 0;
}


int uv_cancel(uv_req_t* req) {
  struct uv__work* wreq;
  uv_loop_t* loop;

  switch (req->type) {
  case UV_FS:
    loop =  ((uv_fs_t*) req)->loop;
    wreq = &((uv_fs_t*) req)->work_req;
    break;
  case UV_GETADDRINFO:
    loop =  ((uv_getaddrinfo_t*) req)->loop;
    wreq = &((uv_getaddrinfo_t*) req)->work_req;
    break;
  case UV_WORK:
    loop =  ((uv_work_t*) req)->loop;
    wreq = &((uv_work_t*) req)->work_req;
    break;
  default:
    return -EINVAL;
  }

  return uv__work_cancel(loop, req, wreq);
}
