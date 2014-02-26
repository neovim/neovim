#include <uv.h>

#include "os/io.h"
#include "os/time.h"
#include "vim.h"
#include "misc2.h"

#define UNUSED(x) (void)(x)
#define BUF_SIZE 4096

typedef struct {
  uint32_t rpos, wpos, apos;
  char_u data[BUF_SIZE];
} input_buffer_T;

static int pending_signal = 0;
static uv_thread_t thread;
static uv_mutex_t mutex;
static uv_cond_t cond;
static uv_async_t stop_loop_async;
static input_buffer_T in_buffer;
/* Actual conditions behind the cond */
static bool signal_consumed = false, activity = false,
            input_consumed = false, running = false, eof = false;
static void event_loop(void *);
static void loop_running(uv_idle_t *, int);
static void stop_loop(uv_async_t *, int);
static void alloc_cb(uv_handle_t *, size_t, uv_buf_t *);
static void read_cb(uv_stream_t *, ssize_t, const uv_buf_t *);
static void signal_cb(uv_signal_t *, int signum);
static void io_lock();
static void io_unlock();
static void io_timedwait(uint64_t ms, bool *condition);
static void io_wait(bool *condition);
static void io_notify(bool *condition);


/* Start event loop and wait until it's running */
void io_start() {
  sigset_t set;

  time_init();
  uv_mutex_init(&mutex);
  uv_cond_init(&cond);
  io_lock();
  /* The event loop runs in a background thread */
  uv_thread_create(&thread, event_loop, NULL);
  /* Wait for the loop thread to be ready */
  io_wait(&running);
  running = true; /* used by `io_stop` */
  /* Block all signals except SIGTSTP in the main thread */
  sigfillset(&set);
  sigdelset(&set, SIGTSTP);
  pthread_sigmask(SIG_SETMASK, &set, NULL);
  io_unlock();
}

void io_stop() {
  if (!running)
    return;

  io_lock();
  /* uv_async_send may try to write on a closed FD, causing an `abort`.
   * Make sure this doesn't happen by checking if eof is set */
  if (!eof) {
    eof = true;
    uv_async_send(&stop_loop_async);
  }
  io_unlock();
  /* io_wait for the event loop thread */
  uv_thread_join(&thread);
}

/* Replacement for `read(2)` */
uint32_t io_read(char *buf, uint32_t count) {
  uint32_t rv = 0;

  io_lock();

  /* Copy at most 'count' to the buffer argument */
  while (in_buffer.rpos < in_buffer.wpos && rv < count)
    buf[rv++] = in_buffer.data[in_buffer.rpos++];

  io_notify(&input_consumed);
  io_unlock();

  return rv;
}

/* Poll the system for user input or a signal. Signals take priority. */
poll_result_t io_poll(int32_t ms) {
  poll_result_t rv;

  io_lock();

  if (eof && in_buffer.rpos == in_buffer.wpos) {
    io_unlock();
    return POLL_EOF;
  }

  if (ms == 0) {
    rv = in_buffer.rpos < in_buffer.wpos ? POLL_INPUT : POLL_NONE;
    io_unlock();
    return rv;
  }

  if (pending_signal) {
    io_unlock();
    return POLL_SIGNAL;
  }

  if (ms < 0) {
    io_wait(&activity);
  } else {
    /* Wait up to 'ms' milliseconds */
    io_timedwait(ms, &activity);
  }

  if (pending_signal) {
    io_unlock();
    return POLL_SIGNAL;
  }

  if (in_buffer.rpos < in_buffer.wpos) {
    io_unlock();
    return POLL_INPUT;
  }

  io_unlock();

  return POLL_NONE;
}

int io_consume_signal() {
  /* FIXME pending_signal must be a queue of signals, right now the event loop
   * is blocking until this function is called. */
  int rv;

  io_lock();
  io_notify(&signal_consumed);
  rv = pending_signal;
  pending_signal = 0;
  io_unlock();

  return rv;
}

static void event_loop(void *arg) {
  sigset_t set;
  uv_loop_t *loop;
  uv_idle_t idler; 
  uv_signal_t sint, shup, squit, sabrt, sterm, swinch;
  uv_pipe_t stdin_stream;

  in_buffer.wpos = in_buffer.rpos = in_buffer.apos = 0;
#ifdef DEBUG
  memset(&in_buffer.data, 0, BUF_SIZE);
#endif

  /* Block SIGTSTP on this thread */
  sigemptyset(&set);
  sigaddset(&set, SIGTSTP);
  pthread_sigmask(SIG_SETMASK, &set, NULL);

  loop = uv_loop_new();
  /* Idler for signaling the main thread when the loop is running */
  uv_idle_init(loop, &idler);
  idler.data = &stdin_stream;
  uv_idle_start(&idler, loop_running);
  /* Async watcher used by the main thread to stop the loop */
  uv_async_init(loop, &stop_loop_async, stop_loop);
  /* stdin */
  /* FIXME setting fd to non-blocking is only needed on unix */
  fcntl(read_cmd_fd, F_SETFL, fcntl(read_cmd_fd, F_GETFL, 0) | O_NONBLOCK);
  uv_pipe_init(loop, &stdin_stream, 0);
  uv_pipe_open(&stdin_stream, read_cmd_fd);
  /* signals */
  uv_signal_init(loop, &sint);
  uv_signal_start(&sint, signal_cb, SIGINT);
  uv_signal_init(loop, &shup);
  uv_signal_start(&shup, signal_cb, SIGHUP);
  uv_signal_init(loop, &squit);
  uv_signal_start(&squit, signal_cb, SIGQUIT);
  uv_signal_init(loop, &sabrt);
  uv_signal_start(&sabrt, signal_cb, SIGABRT);
  uv_signal_init(loop, &sterm);
  uv_signal_start(&sterm, signal_cb, SIGTERM);
  uv_signal_init(loop, &swinch);
  uv_signal_start(&swinch, signal_cb, SIGWINCH);
  /* start processing events */
  uv_run(loop, UV_RUN_DEFAULT);
  /* free the event loop */
  uv_loop_delete(loop);
}

/* Signal the main thread that the loop started running */
static void loop_running(uv_idle_t *handle, int status) {
  uv_idle_stop(handle);
  io_lock();
  uv_read_start((uv_stream_t *)handle->data, alloc_cb, read_cb);
  io_notify(&running);
  io_unlock();
}

static void stop_loop(uv_async_t *handle, int status) {
  uv_stop(handle->loop);
}

/* Called by libuv to allocate memory for reading. */
static void alloc_cb(uv_handle_t *handle, size_t ssize, uv_buf_t *rv)
{
  uint32_t available;

  UNUSED(handle);
  UNUSED(ssize);

  if ((available = BUF_SIZE - in_buffer.apos) == 0) {
    rv->len = 0;
    return;
  }

  rv->base = (char *)(in_buffer.data + in_buffer.apos);
  rv->len = available;
  in_buffer.apos += available;
}

/*
 * Callback invoked by libuv after it copies the data into the buffer provided
 * by `alloc_cb`. This is also called on EOF or when `alloc_cb` returns a
 * 0-length buffer.
 */
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf) {
  uint32_t move_count;

  UNUSED(buf);

  io_lock();

  if (cnt < 0) {
    if (cnt == UV_EOF) {
      /* EOF, stop the event loop and signal the main thread. This will cause
       * vim to exit */
      if (!eof) {
        /* Dont close the loop if it was already closed in `io_stop` */
        eof = true;
        uv_stop(stream->loop);
        io_notify(&activity);
      }
    } else if (cnt == UV_ENOBUFS) {
      if (in_buffer.apos > in_buffer.wpos) {
        /* Restore `apos` to `wpos` */
        in_buffer.apos = in_buffer.wpos;
      } else {
        if (in_buffer.rpos == 0) {
          /* Pause until the main thread consumes some data. */
          io_notify(&activity);
          io_wait(&input_consumed);
        }
        /* Move data to the 'left' as much as possible. */
        move_count = in_buffer.apos - in_buffer.rpos;
        memmove(in_buffer.data, in_buffer.data + in_buffer.rpos, move_count);
        in_buffer.apos -= in_buffer.rpos;
        in_buffer.wpos -= in_buffer.rpos;
        in_buffer.rpos = 0;
      } 
    } else {
      fprintf(stderr, "Unexpected error %ld\n", cnt);
    }
    io_unlock();
    return;
  }

  /* Data was already written, so all we need is to update 'wpos' to reflect
   * the space actually used in the buffer. */
  in_buffer.wpos += cnt;

  if (cnt > 0) {
    io_notify(&activity);
  }

  io_unlock();
}

static void signal_cb(uv_signal_t *handle, int signum) {
  io_lock();
  pending_signal = signum;
  io_notify(&activity); /* unblock */
  io_wait(&signal_consumed);
  io_unlock();
}

/* Helpers for dealing with io synchronization */
static void io_lock() {
  uv_mutex_lock(&mutex);
}

static void io_unlock() {
  uv_mutex_unlock(&mutex);
}

static void io_wait(bool *condition) {
  while (!(*condition)) uv_cond_wait(&cond, &mutex);
  *condition = false;
}

static void io_timedwait(uint64_t ms, bool *condition) {
  uint64_t hrtime;
  int64_t ns = ms * 1000000; /* convert to nanoseconds */

  while (ns > 0 && !(*condition)) {
    hrtime =  uv_hrtime();
    if (uv_cond_timedwait(&cond, &mutex, ns) == UV_ETIMEDOUT)
      break;
    /* If we had a spurious wakeup, ensure the next iteration will only sleep
     * for the remaining time */
    ns -= uv_hrtime() - hrtime;
  }

  *condition = false;
}

static void io_notify(bool *condition) {
  *condition = true;
  uv_cond_signal(&cond);
}
