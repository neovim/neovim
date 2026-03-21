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
#include "nvim/types_defs.h"
#include "nvim/ui_client.h"

#include "event/libuv_proc.c.generated.h"

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
    uv_file pipe_pair[2];
    int client_flags = 0;
#ifdef MSWIN
    client_flags |= proc->overlapped ? UV_NONBLOCK_PIPE : 0;
#endif

    // As of libuv 1.51, UV_CREATE_PIPE can only create pipes
    // using socketpair(), not pipe(). We want the latter on linux
    // as socket pairs behave different in some confusing ways, like
    // breaking /proc/0/fd/0 which is disowned by the linux socket maintainer.
    uv_pipe(pipe_pair, client_flags, UV_NONBLOCK_PIPE);

    uvproc->uvstdio[0].flags = UV_INHERIT_FD;
    uvproc->uvstdio[0].data.fd = pipe_pair[0];
    to_close[0] = pipe_pair[0];

    uv_pipe_open(&proc->in.uv.pipe, pipe_pair[1]);
  }

  if (!proc->out.s.closed) {
#ifdef MSWIN
    // TODO(bfredl): in theory it would have been nice if the uv_pipe() branch
    // also worked for windows but IOCP happens because of reasons.
    uvproc->uvstdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
    // pipe must be readable for IOCP to work on Windows.
    uvproc->uvstdio[1].flags |= proc->overlapped
                                ? (UV_READABLE_PIPE | UV_OVERLAPPED_PIPE) : 0;
    uvproc->uvstdio[1].data.stream = (uv_stream_t *)(&proc->out.s.uv.pipe);
#else
    uv_file pipe_pair[2];
    uv_pipe(pipe_pair, UV_NONBLOCK_PIPE, 0);

    uvproc->uvstdio[1].flags = UV_INHERIT_FD;
    uvproc->uvstdio[1].data.fd = pipe_pair[1];
    to_close[1] = pipe_pair[1];

    uv_pipe_open(&proc->out.s.uv.pipe, pipe_pair[0]);
#endif
  }

  if (!proc->err.s.closed) {
    uv_file pipe_pair[2];
    uv_pipe(pipe_pair, UV_NONBLOCK_PIPE, 0);

    uvproc->uvstdio[2].flags = UV_INHERIT_FD;
    uvproc->uvstdio[2].data.fd = pipe_pair[1];
    to_close[2] = pipe_pair[1];

    uv_pipe_open(&proc->err.s.uv.pipe, pipe_pair[0]);
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
#if defined(MSWIN)
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
