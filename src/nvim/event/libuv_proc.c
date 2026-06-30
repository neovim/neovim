#include <assert.h>
#include <locale.h>
#include <stdint.h>
#include <uv.h>

#include "nvim/eval/typval.h"
#include "nvim/event/defs.h"
#include "nvim/event/libuv_proc.h"
#include "nvim/event/loop.h"
#include "nvim/event/proc.h"
#include "nvim/log.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/types_defs.h"
#include "nvim/ui_client.h"

#include "event/libuv_proc.c.generated.h"

/// Configures a stdio slot (`idx`) before spawning a process: connects the parent end to
/// `parent_pipe` and sets up the fd/pipe the child inherits. `child_readable` is true for the
/// child's stdin (the child reads), false for stdout/stderr (the child writes).
///
/// On Windows, `win_create_pipe` requests a non-inherited pipe (UV_CREATE_PIPE).
/// - stdout always needs this (IOCP);
/// - channel jobs also set it for stdin/stderr.
/// - NOTE(!): libuv sets CREATE_NO_WINDOW only when *all* stdio slots are non-UV_INHERIT_FD!
///   A single UV_INHERIT_FD slot re-attaches child => leaks CON writes to TUI #40074.
///   https://github.com/libuv/libuv/blob/601a1537bb5628398c2389efbc7eecd062e8aac2/src/win/process.c#L1032-L1041
///
/// Records any fd the parent must close after spawn in `to_close[idx]`.
static void libuv_proc_stdio(LibuvProc *uvproc, int idx, uv_pipe_t *parent_pipe,
                             bool child_readable, bool overlapped, bool win_create_pipe,
                             int *to_close)
{
#ifdef MSWIN
  if (win_create_pipe) {
    uvproc->uvstdio[idx].flags = UV_CREATE_PIPE
                                 | (child_readable ? UV_READABLE_PIPE : UV_WRITABLE_PIPE);
    if (overlapped) {
      // Pipe must also be readable for IOCP to work on Windows.
      uvproc->uvstdio[idx].flags |= UV_OVERLAPPED_PIPE | UV_READABLE_PIPE;
    }
    uvproc->uvstdio[idx].data.stream = (uv_stream_t *)parent_pipe;
    return;
  }
#endif

  // Inherited-fd pipe: create a uv_pipe() pair, hand one end to child via UV_INHERIT_FD and keep
  // other for parent.
  //
  // On non-Windows uv_pipe() is preferred over UV_CREATE_PIPE: as of libuv 1.51, UV_CREATE_PIPE
  // uses socketpair() (behaves confusingly on Linux: breaks /proc/<pid>/fd/0, which the Linux
  // socket maintainer disowned).
  int child_flags = 0;
#ifdef MSWIN
  // Overlapped child stdin must be non-blocking.
  child_flags = (child_readable && overlapped) ? UV_NONBLOCK_PIPE : 0;
#endif
  // pipe_pair[0] is the read end, pipe_pair[1] the write end; the parent end is non-blocking.
  uv_file pipe_pair[2];
  uv_pipe(pipe_pair,
          child_readable ? child_flags : UV_NONBLOCK_PIPE,
          child_readable ? UV_NONBLOCK_PIPE : child_flags);

  // child_readable: child reads pipe_pair[0], parent writes pipe_pair[1].
  // else:           child writes pipe_pair[1], parent reads pipe_pair[0].
  int child_fd = child_readable ? pipe_pair[0] : pipe_pair[1];
  int parent_fd = child_readable ? pipe_pair[1] : pipe_pair[0];
  uvproc->uvstdio[idx].flags = UV_INHERIT_FD;
  uvproc->uvstdio[idx].data.fd = child_fd;
  to_close[idx] = child_fd;
  uv_pipe_open(parent_pipe, parent_fd);
}

/// @returns zero on success, or negative error code
int libuv_proc_spawn(LibuvProc *uvproc)
  FUNC_ATTR_NONNULL_ALL
{
  Proc *proc = (Proc *)uvproc;
  uvproc->uvopts.file = proc_get_exepath(proc);
  uvproc->uvopts.args = proc->argv;
  uvproc->uvopts.flags = UV_PROCESS_WINDOWS_HIDE;
#ifdef MSWIN
  // libuv collapses the argv to a CommandLineToArgvW()-style string. cmd.exe
  // expects a different syntax (must be prepared by the caller before now).
  if (os_shell_is_cmdexe(proc->argv[0])) {
    uvproc->uvopts.flags |= UV_PROCESS_WINDOWS_VERBATIM_ARGUMENTS;
    // cmd.exe compatibility: backslashes required for path.
    TO_BACKSLASH(proc->argv[0]);
  }
  if (proc->detach) {
    uvproc->uvopts.flags |= UV_PROCESS_DETACHED;
  }
#else
  // Always setsid() on unix-likes. #8107
  uvproc->uvopts.flags |= UV_PROCESS_DETACHED;
#endif
  uvproc->uvopts.exit_cb = exit_cb;
  uvproc->uvopts.cwd = proc->cwd;

  uvproc->uvopts.stdio = uvproc->uvstdio;
  uvproc->uvopts.stdio_count = 3;
  uvproc->uvstdio[0].flags = UV_IGNORE;
  uvproc->uvstdio[1].flags = UV_IGNORE;
  uvproc->uvstdio[2].flags = UV_IGNORE;

  if (ui_client_forward_stdin) {
    assert(UI_CLIENT_STDIN_FD == 3);
    uvproc->uvopts.stdio_count = 4;
    uvproc->uvstdio[3].data.fd = 0;
    uvproc->uvstdio[3].flags = UV_INHERIT_FD;
  }
  uvproc->uv.data = proc;

  if (proc->env) {
    uvproc->uvopts.env = tv_dict_to_env(proc->env);
  } else {
    uvproc->uvopts.env = NULL;
  }

  int to_close[3] = { -1, -1, -1 };

  if (!proc->in.closed) {
    libuv_proc_stdio(uvproc, 0, &proc->in.uv.pipe, true, proc->overlapped, proc->stdio_noinherit,
                     to_close);
  }

  if (!proc->out.s.closed) {
    // Windows: stdout always uses a non-inherited pipe (IOCP).
    libuv_proc_stdio(uvproc, 1, &proc->out.s.uv.pipe, false, proc->overlapped, true, to_close);
  }

  if (!proc->err.s.closed) {
    libuv_proc_stdio(uvproc, 2, &proc->err.s.uv.pipe, false, proc->overlapped,
                     proc->stdio_noinherit, to_close);
  } else if (proc->fwd_err) {
    uvproc->uvstdio[2].flags = UV_INHERIT_FD;
    uvproc->uvstdio[2].data.fd = STDERR_FILENO;
  }

  int status;
  if ((status = uv_spawn(&proc->loop->uv, &uvproc->uv, &uvproc->uvopts))) {
    ILOG("uv_spawn(%s) failed: %s", uvproc->uvopts.file, uv_strerror(status));
    if (uvproc->uvopts.env) {
      os_free_fullenv(uvproc->uvopts.env);
    }
    goto exit;
  }

  proc->pid = uvproc->uv.pid;
exit:
  for (int i = 0; i < 3; i++) {
    if (to_close[i] > -1) {
      close(to_close[i]);
    }
  }
  return status;
}

void libuv_proc_close(LibuvProc *uvproc)
  FUNC_ATTR_NONNULL_ARG(1)
{
  uv_close((uv_handle_t *)&uvproc->uv, close_cb);
}

static void close_cb(uv_handle_t *handle)
{
  Proc *proc = handle->data;
  if (proc->internal_close_cb) {
    proc->internal_close_cb(proc);
  }
  LibuvProc *uvproc = (LibuvProc *)proc;
  if (uvproc->uvopts.env) {
    os_free_fullenv(uvproc->uvopts.env);
  }
}

static void exit_cb(uv_process_t *handle, int64_t status, int term_signal)
{
  Proc *proc = handle->data;
#ifdef MSWIN
  // Use stored/expected signal.
  term_signal = proc->exit_signal;
#endif
  proc->status = term_signal ? 128 + term_signal : (int)status;
  proc->internal_exit_cb(proc);
}

LibuvProc libuv_proc_init(Loop *loop, void *data)
{
  LibuvProc rv = {
    .proc = proc_init(loop, kProcTypeUv, data)
  };
  return rv;
}
