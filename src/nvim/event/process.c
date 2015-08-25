#include <assert.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/os/shell.h"
#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/event/process.h"
#include "nvim/event/libuv_process.h"
#include "nvim/event/pty_process.h"
#include "nvim/globals.h"
#include "nvim/log.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/process.c.generated.h"
#endif

// {SIGNAL}_TIMEOUT is the time (in nanoseconds) that a process has to cleanly
// exit before we send SIGNAL to it
#define TERM_TIMEOUT 1000000000
#define KILL_TIMEOUT (TERM_TIMEOUT * 2)

#define CLOSE_PROC_STREAM(proc, stream)                             \
  do {                                                              \
    if (proc->stream && !proc->stream->closed) {                    \
      stream_close(proc->stream, NULL);                             \
    }                                                               \
  } while (0)


bool process_spawn(Process *proc) FUNC_ATTR_NONNULL_ALL
{
  if (proc->in) {
    uv_pipe_init(&proc->loop->uv, &proc->in->uv.pipe, 0);
  }

  if (proc->out) {
    uv_pipe_init(&proc->loop->uv, &proc->out->uv.pipe, 0);
  }

  if (proc->err) {
    uv_pipe_init(&proc->loop->uv, &proc->err->uv.pipe, 0);
  }

  bool success;
  switch (proc->type) {
    case kProcessTypeUv:
      success = libuv_process_spawn((LibuvProcess *)proc);
      break;
    case kProcessTypePty:
      success = pty_process_spawn((PtyProcess *)proc);
      break;
    default:
      abort();
  }

  if (!success) {
    if (proc->in) {
      uv_close((uv_handle_t *)&proc->in->uv.pipe, NULL);
    }
    if (proc->out) {
      uv_close((uv_handle_t *)&proc->out->uv.pipe, NULL);
    }
    if (proc->err) {
      uv_close((uv_handle_t *)&proc->err->uv.pipe, NULL);
    }

    if (proc->type == kProcessTypeUv) {
      uv_close((uv_handle_t *)&(((LibuvProcess *)proc)->uv), NULL);
    } else {
      process_close(proc);
    }
    shell_free_argv(proc->argv);
    proc->status = -1;
    return false;
  }

  void *data = proc->data;

  if (proc->in) {
    stream_init(NULL, proc->in, -1, (uv_stream_t *)&proc->in->uv.pipe, data);
    proc->in->events = proc->events;
    proc->in->internal_data = proc;
    proc->in->internal_close_cb = on_process_stream_close;
    proc->refcount++;
  }

  if (proc->out) {
    stream_init(NULL, proc->out, -1, (uv_stream_t *)&proc->out->uv.pipe, data);
    proc->out->events = proc->events;
    proc->out->internal_data = proc;
    proc->out->internal_close_cb = on_process_stream_close;
    proc->refcount++;
  }

  if (proc->err) {
    stream_init(NULL, proc->err, -1, (uv_stream_t *)&proc->err->uv.pipe, data);
    proc->err->events = proc->events;
    proc->err->internal_data = proc;
    proc->err->internal_close_cb = on_process_stream_close;
    proc->refcount++;
  }

  proc->internal_exit_cb = on_process_exit;
  proc->internal_close_cb = decref;
  proc->refcount++;
  kl_push(WatcherPtr, proc->loop->children, proc);
  return true;
}

void process_teardown(Loop *loop) FUNC_ATTR_NONNULL_ALL
{
  kl_iter(WatcherPtr, loop->children, current) {
    Process *proc = (*current)->data;
    uv_kill(proc->pid, SIGTERM);
    proc->term_sent = true;
    process_stop(proc);
  }

  // Wait until all children exit
  LOOP_PROCESS_EVENTS_UNTIL(loop, loop->events, -1, kl_empty(loop->children));
  pty_process_teardown(loop);
}

// Wrappers around `stream_close` that protect against double-closing.
void process_close_streams(Process *proc) FUNC_ATTR_NONNULL_ALL
{
  process_close_in(proc);
  process_close_out(proc);
  process_close_err(proc);
}

void process_close_in(Process *proc) FUNC_ATTR_NONNULL_ALL
{
  CLOSE_PROC_STREAM(proc, in);
}

void process_close_out(Process *proc) FUNC_ATTR_NONNULL_ALL
{
  CLOSE_PROC_STREAM(proc, out);
}

void process_close_err(Process *proc) FUNC_ATTR_NONNULL_ALL
{
  CLOSE_PROC_STREAM(proc, err);
}

/// Synchronously wait for a process to finish
///
/// @param process The Process instance
/// @param ms Number of milliseconds to wait, 0 for not waiting, -1 for
///        waiting until the process quits.
/// @return returns the status code of the exited process. -1 if the process is
///         still running and the `timeout` has expired. Note that this is
///         indistinguishable from the process returning -1 by itself. Which
///         is possible on some OS. Returns -2 if an user has interruped the
///         wait.
int process_wait(Process *proc, int ms, Queue *events) FUNC_ATTR_NONNULL_ARG(1)
{
  // The default status is -1, which represents a timeout
  int status = -1;
  bool interrupted = false;
  if (!proc->refcount) {
    LOOP_PROCESS_EVENTS(proc->loop, proc->events, 0);
    return proc->status;
  }

  if (!events) {
    events = proc->events;
  }

  // Increase refcount to stop the exit callback from being called(and possibly
  // being freed) before we have a chance to get the status.
  proc->refcount++;
  LOOP_PROCESS_EVENTS_UNTIL(proc->loop, events, ms,
      // Until...
      got_int ||             // interrupted by the user
      proc->refcount == 1);  // job exited

  // we'll assume that a user frantically hitting interrupt doesn't like
  // the current job. Signal that it has to be killed.
  if (got_int) {
    interrupted = true;
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
  }

  if (proc->refcount == 1) {
    // Job exited, collect status and manually invoke close_cb to free the job
    // resources
    status = interrupted ? -2 : proc->status;
    decref(proc);
    if (events) {
      // the decref call created an exit event, process it now
      queue_process_events(events);
    }
  } else {
    proc->refcount--;
  }

  return status;
}

/// Ask a process to terminate and eventually kill if it doesn't respond
void process_stop(Process *proc) FUNC_ATTR_NONNULL_ALL
{
  if (proc->stopped_time) {
    return;
  }

  proc->stopped_time = os_hrtime();
  switch (proc->type) {
    case kProcessTypeUv:
      // Close the process's stdin. If the process doesn't close its own
      // stdout/stderr, they will be closed when it exits(possibly due to being
      // terminated after a timeout)
      process_close_in(proc);
      break;
    case kProcessTypePty:
      // close all streams for pty processes to send SIGHUP to the process
      process_close_streams(proc);
      pty_process_close_master((PtyProcess *)proc);
      break;
    default:
      abort();
  }

  Loop *loop = proc->loop;
  if (!loop->children_stop_requests++) {
    // When there's at least one stop request pending, start a timer that
    // will periodically check if a signal should be send to a to the job
    DLOG("Starting job kill timer");
    uv_timer_start(&loop->children_kill_timer, children_kill_cb, 100, 100);
  }
}

/// Iterates the process list sending SIGTERM to stopped processes and SIGKILL
/// to those that didn't die from SIGTERM after a while(exit_timeout is 0).
static void children_kill_cb(uv_timer_t *handle)
{
  Loop *loop = handle->loop->data;
  uint64_t now = os_hrtime();

  kl_iter(WatcherPtr, loop->children, current) {
    Process *proc = (*current)->data;
    if (!proc->stopped_time) {
      continue;
    }
    uint64_t elapsed = now - proc->stopped_time;

    if (!proc->term_sent && elapsed >= TERM_TIMEOUT) {
      ILOG("Sending SIGTERM to pid %d", proc->pid);
      uv_kill(proc->pid, SIGTERM);
      proc->term_sent = true;
    } else if (elapsed >= KILL_TIMEOUT) {
      ILOG("Sending SIGKILL to pid %d", proc->pid);
      uv_kill(proc->pid, SIGKILL);
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
  if (proc->cb) {
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
  assert(!proc->closed);
  proc->closed = true;
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

static void process_close_handles(void **argv)
{
  Process *proc = argv[0];
  process_close_streams(proc);
  process_close(proc);
}

static void on_process_exit(Process *proc)
{
  Loop *loop = proc->loop;
  if (proc->stopped_time && loop->children_stop_requests
      && !--loop->children_stop_requests) {
    // Stop the timer if no more stop requests are pending
    DLOG("Stopping process kill timer");
    uv_timer_stop(&loop->children_kill_timer);
  }
  // Process handles are closed in the next event loop tick. This is done to
  // give libuv more time to read data from the OS after the process exits(If
  // process_close_streams is called with data still in the OS buffer, we lose
  // it)
  CREATE_EVENT(proc->events, process_close_handles, 1, proc);
}

static void on_process_stream_close(Stream *stream, void *data)
{
  Process *proc = data;
  decref(proc);
}

