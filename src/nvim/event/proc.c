#include <assert.h>
#include <inttypes.h>
#include <signal.h>
#include <string.h>
#include <uv.h>

#include "klib/kvec.h"
#include "nvim/event/libuv_proc.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/proc.h"
#include "nvim/event/rstream.h"
#include "nvim/event/stream.h"
#include "nvim/event/wstream.h"
#include "nvim/globals.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/memory_defs.h"
#include "nvim/os/proc.h"
#include "nvim/os/pty_proc.h"
#include "nvim/os/shell.h"
#include "nvim/os/time.h"
#include "nvim/ui_client.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/proc.c.generated.h"
#endif

// Time for a process to exit cleanly before we send KILL.
// For PTY processes SIGTERM is sent first (in case SIGHUP was not enough).
#define KILL_TIMEOUT_MS 2000

/// Externally defined with gcov.
#ifdef USE_GCOV
void __gcov_flush(void);
#endif

static bool proc_is_tearing_down = false;

// Delay exit until handles are closed, to avoid deadlocks
static int exit_need_delay = 0;

/// @returns zero on success, or negative error code
int proc_spawn(Proc *proc, bool in, bool out, bool err)
  FUNC_ATTR_NONNULL_ALL
{
  // forwarding stderr contradicts with processing it internally
  assert(!(err && proc->fwd_err));

  if (in) {
    uv_pipe_init(&proc->loop->uv, &proc->in.uv.pipe, 0);
  } else {
    proc->in.closed = true;
  }

  if (out) {
    uv_pipe_init(&proc->loop->uv, &proc->out.s.uv.pipe, 0);
  } else {
    proc->out.s.closed = true;
  }

  if (err) {
    uv_pipe_init(&proc->loop->uv, &proc->err.s.uv.pipe, 0);
  } else {
    proc->err.s.closed = true;
  }

#ifdef USE_GCOV
  // Flush coverage data before forking, to avoid "Merge mismatch" errors.
  __gcov_flush();
#endif

  int status;
  switch (proc->type) {
  case kProcTypeUv:
    status = libuv_proc_spawn((LibuvProc *)proc);
    break;
  case kProcTypePty:
    status = pty_proc_spawn((PtyProc *)proc);
    break;
  }

  if (status) {
    if (in) {
      uv_close((uv_handle_t *)&proc->in.uv.pipe, NULL);
    }
    if (out) {
      uv_close((uv_handle_t *)&proc->out.s.uv.pipe, NULL);
    }
    if (err) {
      uv_close((uv_handle_t *)&proc->err.s.uv.pipe, NULL);
    }

    if (proc->type == kProcTypeUv) {
      uv_close((uv_handle_t *)&(((LibuvProc *)proc)->uv), NULL);
    } else {
      proc_close(proc);
    }
    proc_free(proc);
    proc->status = -1;
    return status;
  }

  if (in) {
    stream_init(NULL, &proc->in, -1, (uv_stream_t *)&proc->in.uv.pipe);
    proc->in.internal_data = proc;
    proc->in.internal_close_cb = on_proc_stream_close;
    proc->refcount++;
  }

  if (out) {
    stream_init(NULL, &proc->out.s, -1, (uv_stream_t *)&proc->out.s.uv.pipe);
    proc->out.s.internal_data = proc;
    proc->out.s.internal_close_cb = on_proc_stream_close;
    proc->refcount++;
  }

  if (err) {
    stream_init(NULL, &proc->err.s, -1, (uv_stream_t *)&proc->err.s.uv.pipe);
    proc->err.s.internal_data = proc;
    proc->err.s.internal_close_cb = on_proc_stream_close;
    proc->refcount++;
  }

  proc->internal_exit_cb = on_proc_exit;
  proc->internal_close_cb = decref;
  proc->refcount++;
  kv_push(proc->loop->children, proc);
  DLOG("new: pid=%d exepath=[%s]", proc->pid, proc_get_exepath(proc));
  return 0;
}

void proc_teardown(Loop *loop) FUNC_ATTR_NONNULL_ALL
{
  proc_is_tearing_down = true;
  for (size_t i = 0; i < kv_size(loop->children); i++) {
    Proc *proc = kv_A(loop->children, i);
    if (proc->detach || proc->type == kProcTypePty) {
      // Close handles to process without killing it.
      CREATE_EVENT(loop->events, proc_close_handles, proc);
    } else {
      proc_stop(proc);
    }
  }

  // Wait until all children exit and all close events are processed.
  LOOP_PROCESS_EVENTS_UNTIL(loop, loop->events, -1,
                            kv_size(loop->children) == 0 && multiqueue_empty(loop->events));
  pty_proc_teardown(loop);
}

void proc_close_streams(Proc *proc) FUNC_ATTR_NONNULL_ALL
{
  wstream_may_close(&proc->in);
  rstream_may_close(&proc->out);
  rstream_may_close(&proc->err);
}

/// Synchronously wait for a process to finish
///
/// @param process  Process instance
/// @param ms       Time in milliseconds to wait for the process.
///                 0 for no wait. -1 to wait until the process quits.
/// @return Exit code of the process. proc->status will have the same value.
///         -1 if the timeout expired while the process is still running.
///         -2 if the user interrupted the wait.
int proc_wait(Proc *proc, int ms, MultiQueue *events)
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

  // Assume that a user hitting CTRL-C does not like the current job.  Kill it.
  if (got_int) {
    got_int = false;
    proc_stop(proc);
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
    if (proc->events) {
      // decref() created an exit event, process it now.
      multiqueue_process_events(proc->events);
    }
  } else {
    proc->refcount--;
  }

  return proc->status;
}

/// Ask a process to terminate and eventually kill if it doesn't respond
void proc_stop(Proc *proc) FUNC_ATTR_NONNULL_ALL
{
  bool exited = (proc->status >= 0);
  if (exited || proc->stopped_time) {
    return;
  }
  proc->stopped_time = os_hrtime();
  proc->exit_signal = SIGTERM;

  switch (proc->type) {
  case kProcTypeUv:
    os_proc_tree_kill(proc->pid, SIGTERM);
    break;
  case kProcTypePty:
    // close all streams for pty processes to send SIGHUP to the process
    proc_close_streams(proc);
    pty_proc_close_master((PtyProc *)proc);
    break;
  }

  // (Re)start timer to verify that stopped process(es) died.
  uv_timer_start(&proc->loop->children_kill_timer, children_kill_cb,
                 KILL_TIMEOUT_MS, 0);
}

/// Frees process-owned resources.
void proc_free(Proc *proc) FUNC_ATTR_NONNULL_ALL
{
  if (proc->argv != NULL) {
    shell_free_argv(proc->argv);
    proc->argv = NULL;
  }
}

/// Sends SIGKILL (or SIGTERM..SIGKILL for PTY jobs) to processes that did
/// not terminate after proc_stop().
static void children_kill_cb(uv_timer_t *handle)
{
  Loop *loop = handle->loop->data;

  for (size_t i = 0; i < kv_size(loop->children); i++) {
    Proc *proc = kv_A(loop->children, i);
    bool exited = (proc->status >= 0);
    if (exited || !proc->stopped_time) {
      continue;
    }
    uint64_t term_sent = UINT64_MAX == proc->stopped_time;
    if (kProcTypePty != proc->type || term_sent) {
      proc->exit_signal = SIGKILL;
      os_proc_tree_kill(proc->pid, SIGKILL);
    } else {
      proc->exit_signal = SIGTERM;
      os_proc_tree_kill(proc->pid, SIGTERM);
      proc->stopped_time = UINT64_MAX;  // Flag: SIGTERM was sent.
      // Restart timer.
      uv_timer_start(&proc->loop->children_kill_timer, children_kill_cb,
                     KILL_TIMEOUT_MS, 0);
    }
  }
}

static void proc_close_event(void **argv)
{
  Proc *proc = argv[0];
  if (proc->cb) {
    // User (hint: channel_job_start) is responsible for calling
    // proc_free().
    proc->cb(proc, proc->status, proc->data);
  } else {
    proc_free(proc);
  }
}

static void decref(Proc *proc)
{
  if (--proc->refcount != 0) {
    return;
  }

  Loop *loop = proc->loop;
  size_t i;
  for (i = 0; i < kv_size(loop->children); i++) {
    Proc *current = kv_A(loop->children, i);
    if (current == proc) {
      break;
    }
  }
  assert(i < kv_size(loop->children));  // element found
  if (i < kv_size(loop->children) - 1) {
    memmove(&kv_A(loop->children, i), &kv_A(loop->children, i + 1),
            sizeof(&kv_A(loop->children, i)) * (kv_size(loop->children) - (i + 1)));
  }
  kv_size(loop->children)--;
  CREATE_EVENT(proc->events, proc_close_event, proc);
}

static void proc_close(Proc *proc)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (proc_is_tearing_down && proc->closed && (proc->detach || proc->type == kProcTypePty)) {
    // If a detached/pty process dies while tearing down it might get closed twice.
    return;
  }
  assert(!proc->closed);
  proc->closed = true;

  if (proc->detach) {
    if (proc->type == kProcTypeUv) {
      uv_unref((uv_handle_t *)&(((LibuvProc *)proc)->uv));
    }
  }

  switch (proc->type) {
  case kProcTypeUv:
    libuv_proc_close((LibuvProc *)proc);
    break;
  case kProcTypePty:
    pty_proc_close((PtyProc *)proc);
    break;
  }
}

/// Flush output stream.
///
/// @param proc     Process, for which an output stream should be flushed.
/// @param stream   Stream to flush.
static void flush_stream(Proc *proc, RStream *stream)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (!stream || stream->s.closed) {
    return;
  }

  // Maximal remaining data size of terminated process is system
  // buffer size.
  // Also helps with a child process that keeps the output streams open. If it
  // keeps sending data, we only accept as much data as the system buffer size.
  // Otherwise this would block cleanup/teardown.
  int system_buffer_size = 0;
  int err = uv_recv_buffer_size((uv_handle_t *)&stream->s.uv.pipe,
                                &system_buffer_size);
  if (err) {
    system_buffer_size = ARENA_BLOCK_SIZE;
  }

  size_t max_bytes = stream->num_bytes + (size_t)system_buffer_size;

  // Read remaining data.
  while (!stream->s.closed && stream->num_bytes < max_bytes) {
    // Remember number of bytes before polling
    size_t num_bytes = stream->num_bytes;

    // Poll for data and process the generated events.
    loop_poll_events(proc->loop, 0);
    if (stream->s.events) {
      multiqueue_process_events(stream->s.events);
    }

    // Stream can be closed if it is empty.
    if (num_bytes == stream->num_bytes) {
      if (stream->read_cb && !stream->did_eof) {
        // Stream callback could miss EOF handling if a child keeps the stream
        // open. But only send EOF if we haven't already.
        stream->read_cb(stream, stream->buffer, 0, stream->s.cb_data, true);
      }
      break;
    }
  }
}

static void proc_close_handles(void **argv)
{
  Proc *proc = argv[0];

  exit_need_delay++;
  flush_stream(proc, &proc->out);
  flush_stream(proc, &proc->err);

  proc_close_streams(proc);
  proc_close(proc);
  exit_need_delay--;
}

static void exit_delay_cb(uv_timer_t *handle)
{
  uv_timer_stop(&main_loop.exit_delay_timer);
  multiqueue_put(main_loop.fast_events, exit_event, main_loop.exit_delay_timer.data);
}

static void exit_event(void **argv)
{
  int status = (int)(intptr_t)argv[0];
  if (exit_need_delay) {
    main_loop.exit_delay_timer.data = argv[0];
    uv_timer_start(&main_loop.exit_delay_timer, exit_delay_cb, 0, 0);
    return;
  }

  if (!exiting) {
    if (ui_client_channel_id) {
      ui_client_exit_status = status;
      os_exit(status);
    } else {
      assert(status == 0);  // Called from rpc_close(), which passes 0 as status.
      preserve_exit(NULL);
    }
  }
}

/// Performs self-exit because the primary RPC channel was closed.
void exit_on_closed_chan(int status)
{
  DLOG("self-exit triggered by closed RPC channel...");
  multiqueue_put(main_loop.fast_events, exit_event, (void *)(intptr_t)status);
}

static void on_proc_exit(Proc *proc)
{
  Loop *loop = proc->loop;
  ILOG("child exited: pid=%d status=%d" PRIu64, proc->pid, proc->status);

#ifdef MSWIN
  // XXX: This assumes the TUI never spawns any other processes...?
  // TODO(justinmk): figure out why rpc_close sometimes(??) isn't called, then remove this jank.
  // Theories:
  // - EOF not received in receive_msgpack, then doesn't call chan_close_on_err().
  // - proc_close_handles not tickled by ui_client.c's LOOP_PROCESS_EVENTS?
  if (ui_client_channel_id) {
    exit_on_closed_chan(proc->status);
  }
#endif

  // Process has terminated, but there could still be data to be read from the
  // OS. We are still in the libuv loop, so we cannot call code that polls for
  // more data directly. Instead delay the reading after the libuv loop by
  // queueing proc_close_handles() as an event.
  MultiQueue *queue = proc->events ? proc->events : loop->events;
  CREATE_EVENT(queue, proc_close_handles, proc);
}

static void on_proc_stream_close(Stream *stream, void *data)
{
  Proc *proc = data;
  decref(proc);
}
