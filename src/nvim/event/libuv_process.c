#include <assert.h>
#include <locale.h>
#include <stdint.h>
#include <uv.h>

#include "nvim/eval/typval.h"
#include "nvim/event/defs.h"
#include "nvim/event/libuv_process.h"
#include "nvim/event/loop.h"
#include "nvim/event/process.h"
#include "nvim/log.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/types_defs.h"
#include "nvim/ui_client.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/libuv_process.c.generated.h"
#endif

/// @returns zero on success, or negative error code
int libuv_process_spawn(LibuvProcess *uvproc)
  FUNC_ATTR_NONNULL_ALL
{
  Process *proc = (Process *)uvproc;
  uvproc->uvopts.file = process_get_exepath(proc);
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

  if (!proc->in.closed) {
    uvproc->uvstdio[0].flags = UV_CREATE_PIPE | UV_READABLE_PIPE;
#ifdef MSWIN
    uvproc->uvstdio[0].flags |= proc->overlapped ? UV_OVERLAPPED_PIPE : 0;
#endif
    uvproc->uvstdio[0].data.stream = (uv_stream_t *)(&proc->in.uv.pipe);
  }

  if (!proc->out.s.closed) {
    uvproc->uvstdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
#ifdef MSWIN
    // pipe must be readable for IOCP to work on Windows.
    uvproc->uvstdio[1].flags |= proc->overlapped
                                ? (UV_READABLE_PIPE | UV_OVERLAPPED_PIPE) : 0;
#endif
    uvproc->uvstdio[1].data.stream = (uv_stream_t *)(&proc->out.s.uv.pipe);
  }

  if (!proc->err.s.closed) {
    uvproc->uvstdio[2].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
    uvproc->uvstdio[2].data.stream = (uv_stream_t *)(&proc->err.s.uv.pipe);
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
    return status;
  }

  proc->pid = uvproc->uv.pid;
  return status;
}

void libuv_process_close(LibuvProcess *uvproc)
  FUNC_ATTR_NONNULL_ARG(1)
{
  uv_close((uv_handle_t *)&uvproc->uv, close_cb);
}

static void close_cb(uv_handle_t *handle)
{
  Process *proc = handle->data;
  if (proc->internal_close_cb) {
    proc->internal_close_cb(proc);
  }
  LibuvProcess *uvproc = (LibuvProcess *)proc;
  if (uvproc->uvopts.env) {
    os_free_fullenv(uvproc->uvopts.env);
  }
}

static void exit_cb(uv_process_t *handle, int64_t status, int term_signal)
{
  Process *proc = handle->data;
#if defined(MSWIN)
  // Use stored/expected signal.
  term_signal = proc->exit_signal;
#endif
  proc->status = term_signal ? 128 + term_signal : (int)status;
  proc->internal_exit_cb(proc);
}

LibuvProcess libuv_process_init(Loop *loop, void *data)
{
  LibuvProcess rv = {
    .process = process_init(loop, kProcessTypeUv, data)
  };
  return rv;
}
