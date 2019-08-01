// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/os/shell.h"
#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/event/process.h"
#include "nvim/event/libuv_process.h"
#include "nvim/os/process.h"
#include "nvim/os/pty_process.h"
#include "nvim/globals.h"
#include "nvim/macros.h"
#include "nvim/log.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/process.c.generated.h"
#endif

// Time for a process to exit cleanly before we send KILL.
// For PTY processes SIGTERM is sent first (in case SIGHUP was not enough).
#define KILL_TIMEOUT_MS 2000

/// Externally defined with gcov.
#ifdef USE_GCOV
void __gcov_flush(void);
#endif

static bool process_is_tearing_down = false;

/// @returns zero on success, or negative error code
int process_spawn(Process *proc, bool in, bool out, bool err)
  FUNC_ATTR_NONNULL_ALL
{
  if (in) {
    uv_pipe_init(&proc->loop->uv, &proc->in.uv.pipe, 0);
  } else {
    proc->in.closed = true;
  }

  if (out) {
    uv_pipe_init(&proc->loop->uv, &proc->out.uv.pipe, 0);
  } else {
    proc->out.closed = true;
  }

  if (err) {
    uv_pipe_init(&proc->loop->uv, &proc->err.uv.pipe, 0);
  } else {
    proc->err.closed = true;
  }

#ifdef USE_GCOV
  // Flush coverage data before forking, to avoid "Merge mismatch" errors.
  __gcov_flush();
#endif

  int status;
  switch (proc->type) {
    case kProcessTypeUv:
      status = libuv_process_spawn((LibuvProcess *)proc);
      break;
    case kProcessTypePty:
      status = pty_process_spawn((PtyProcess *)proc);
      break;
    default:
      abort();
  }

  if (status) {
    if (in) {
      uv_close((uv_handle_t *)&proc->in.uv.pipe, NULL);
    }
    if (out) {
      uv_close((uv_handle_t *)&proc->out.uv.pipe, NULL);
    }
    if (err) {
      uv_close((uv_handle_t *)&proc->err.uv.pipe, NULL);
    }

    if (proc->type == kProcessTypeUv) {
      uv_close((uv_handle_t *)&(((LibuvProcess *)proc)->uv), NULL);
    } else {
      process_close(proc);
    }
    shell_free_argv(proc->argv);
    proc->status = -1;
    return status;
  }

  if (in) {
    stream_init(NULL, &proc->in, -1,
                STRUCT_CAST(uv_stream_t, &proc->in.uv.pipe));
    proc->in.internal_data = proc;
    proc->in.internal_close_cb = on_process_stream_close;
    proc->refcount++;
  }

  if (out) {
    stream_init(NULL, &proc->out, -1,
                STRUCT_CAST(uv_stream_t, &proc->out.uv.pipe));
    proc->out.internal_data = proc;
    proc->out.internal_close_cb = on_process_stream_close;
    proc->refcount++;
  }

  if (err) {
    stream_init(NULL, &proc->err, -1,
                STRUCT_CAST(uv_stream_t, &proc->err.uv.pipe));
    proc->err.internal_data = proc;
    proc->err.internal_close_cb = on_process_stream_close;
    proc->refcount++;
  }

  proc->internal_exit_cb = on_process_exit;
  proc->internal_close_cb = decref;
  proc->refcount++;
  kl_push(WatcherPtr, proc->loop->children, proc);
  DLOG("new: pid=%d argv=[%s]", proc->pid, *proc->argv);
  return 0;
}

void process_teardown(Loop *loop) FUNC_ATTR_NONNULL_ALL
{
  process_is_tearing_down = true;
  kl_iter(WatcherPtr, loop->children, current) {
    Process *proc = (*current)->data;
    if (proc->detach || proc->type == kProcessTypePty) {
      // Close handles to process without killing it.
      CREATE_EVENT(loop->events, process_close_handles, 1, proc);
    } else {
      process_stop(proc);
    }
  }

  // Wait until all children exit and all close events are processed.
  LOOP_PROCESS_EVENTS_UNTIL(
      loop, loop->events, -1,
      kl_empty(loop->children) && multiqueue_empty(loop->events));
  pty_process_teardown(loop);
}

void process_close_streams(Process *proc) FUNC_ATTR_NONNULL_ALL
{
  stream_may_close(&proc->in);
  stream_may_close(&proc->out);
  stream_may_close(&proc->err);
}

/// Synchronously wait for a process to finish
///
/// @param process  Process instance
/// @param ms       Time in milliseconds to wait for the process.
///                 0 for no wait. -1 to wait until the process quits.
/// @return Exit code of the process. proc->status will have the same value.
///         -1 if the timeout expired while the process is still running.
///         -2 if the user interruped the wait.
int process_wait(Process *proc, int ms, MultiQueue *events)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (!proc->refcount) {
    int status = proc->status;
    LOOP_PROCESS_EVENTS(proc->loop, proc->events, 0);
    return status;
  }

  if (!events) {
    events = proc->events;
  }

  // Increase refcount to stop the exit callback from being called (and possibly
  // freed) before we have a chance to get the status.
  proc->refcount++;
  LOOP_PROCESS_EVENTS_UNTIL(proc->loop, events, ms,
                            // Until...
                            got_int                   // interrupted by the user
                            || proc->refcount == 1);  // job exited

  // we'll assume that a user frantically hitting interrupt doesn't like
  // the current job. Signal that it has to be killed.
  if (got_int) {
    got_int = false;
    process_stop(proc);
    if (ms == -1) {
      // We can only return if all streams/handles are closed and the job
      // exited.
      LOOP_PROCESS_EVENTS_UNTIL(proc->loop, events, -1,
          proc->refcount == 1);
    } else {
      LOOP_PROCESS_EVENTS(proc->loop, events, 0);
    }

    proc->status = -2;
  }

  if (proc->refcount == 1) {
    // Job exited, free its resources.
    decref(proc);
    if (events) {
      // the decref call created an exit event, process it now
      multiqueue_process_events(events);
    }
  } else {
    proc->refcount--;
  }

  return proc->status;
}

/// Ask a process to terminate and eventually kill if it doesn't respond
void process_stop(Process *proc) FUNC_ATTR_NONNULL_ALL
{
  bool exited = (proc->status >= 0);
  if (exited || proc->stopped_time) {
    return;
  }
  proc->stopped_time = os_hrtime();

  switch (proc->type) {
    case kProcessTypeUv:
      os_proc_tree_kill(proc->pid, SIGTERM);
      break;
    case kProcessTypePty:
      // close all streams for pty processes to send SIGHUP to the process
      process_close_streams(proc);
      pty_process_close_master((PtyProcess *)proc);
      break;
    default:
      abort();
  }

  // (Re)start timer to verify that stopped process(es) died.
  uv_timer_start(&proc->loop->children_kill_timer, children_kill_cb,
                 KILL_TIMEOUT_MS, 0);
}

/// Sends SIGKILL (or SIGTERM..SIGKILL for PTY jobs) to processes that did
/// not terminate after process_stop().
static void children_kill_cb(uv_timer_t *handle)
{
  Loop *loop = handle->loop->data;

  kl_iter(WatcherPtr, loop->children, current) {
    Process *proc = (*current)->data;
    bool exited = (proc->status >= 0);
    if (exited || !proc->stopped_time) {
      continue;
    }
    uint64_t term_sent = UINT64_MAX == proc->stopped_time;
    if (kProcessTypePty != proc->type || term_sent) {
      os_proc_tree_kill(proc->pid, SIGKILL);
    } else {
      os_proc_tree_kill(proc->pid, SIGTERM);
      proc->stopped_time = UINT64_MAX;  // Flag: SIGTERM was sent.
      // Restart timer.
      uv_timer_start(&proc->loop->children_kill_timer, children_kill_cb,
                     KILL_TIMEOUT_MS, 0);
    }
  }
}

static void process_close_event(void **argv)
{
  Process *proc = argv[0];
  shell_free_argv(proc->argv);
  if (proc->type == kProcessTypePty) {
    xfree(((PtyProcess *)proc)->term_name);
  }
  if (proc->cb) {  // "on_exit" for jobstart(). See channel_job_start().
    proc->cb(proc, proc->status, proc->data);
  }
}

static void decref(Process *proc)
{
  if (--proc->refcount != 0) {
    return;
  }

  Loop *loop = proc->loop;
  kliter_t(WatcherPtr) **node = NULL;
  kl_iter(WatcherPtr, loop->children, current) {
    if ((*current)->data == proc) {
      node = current;
      break;
    }
  }
  assert(node);
  kl_shift_at(WatcherPtr, loop->children, node);
  CREATE_EVENT(proc->events, process_close_event, 1, proc);
}

static void process_close(Process *proc)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (process_is_tearing_down && (proc->detach || proc->type == kProcessTypePty)
      && proc->closed) {
    // If a detached/pty process dies while tearing down it might get closed
    // twice.
    return;
  }
  assert(!proc->closed);
  proc->closed = true;

  if (proc->detach) {
    if (proc->type == kProcessTypeUv) {
      uv_unref((uv_handle_t *)&(((LibuvProcess *)proc)->uv));
    }
  }

  switch (proc->type) {
    case kProcessTypeUv:
      libuv_process_close((LibuvProcess *)proc);
      break;
    case kProcessTypePty:
      pty_process_close((PtyProcess *)proc);
      break;
    default:
      abort();
  }
}

/// Flush output stream.
///
/// @param proc     Process, for which an output stream should be flushed.
/// @param stream   Stream to flush.
static void flush_stream(Process *proc, Stream *stream)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (!stream || stream->closed) {
    return;
  }

  // Maximal remaining data size of terminated process is system
  // buffer size.
  // Also helps with a child process that keeps the output streams open. If it
  // keeps sending data, we only accept as much data as the system buffer size.
  // Otherwise this would block cleanup/teardown.
  int system_buffer_size = 0;
  int err = uv_recv_buffer_size((uv_handle_t *)&stream->uv.pipe,
                                &system_buffer_size);
  if (err) {
    system_buffer_size = (int)rbuffer_capacity(stream->buffer);
  }

  size_t max_bytes = stream->num_bytes + (size_t)system_buffer_size;

  // Read remaining data.
  while (!stream->closed && stream->num_bytes < max_bytes) {
    // Remember number of bytes before polling
    size_t num_bytes = stream->num_bytes;

    // Poll for data and process the generated events.
    loop_poll_events(proc->loop, 0);
    if (stream->events) {
        multiqueue_process_events(stream->events);
    }

    // Stream can be closed if it is empty.
    if (num_bytes == stream->num_bytes) {  // -V547
      if (stream->read_cb && !stream->did_eof) {
        // Stream callback could miss EOF handling if a child keeps the stream
        // open. But only send EOF if we haven't already.
        stream->read_cb(stream, stream->buffer, 0, stream->cb_data, true);
      }
      break;
    }
  }
}

static void process_close_handles(void **argv)
{
  Process *proc = argv[0];

  flush_stream(proc, &proc->out);
  flush_stream(proc, &proc->err);

  process_close_streams(proc);
  process_close(proc);
}

static void on_process_exit(Process *proc)
{
  Loop *loop = proc->loop;
  ILOG("exited: pid=%d status=%d stoptime=%" PRIu64, proc->pid, proc->status,
       proc->stopped_time);

  // Process has terminated, but there could still be data to be read from the
  // OS. We are still in the libuv loop, so we cannot call code that polls for
  // more data directly. Instead delay the reading after the libuv loop by
  // queueing process_close_handles() as an event.
  MultiQueue *queue = proc->events ? proc->events : loop->events;
  CREATE_EVENT(queue, process_close_handles, 1, proc);
}

static void on_process_stream_close(Stream *stream, void *data)
{
  Process *proc = data;
  decref(proc);
}

