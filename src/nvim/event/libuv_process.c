// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/event/process.h"
#include "nvim/event/libuv_process.h"
#include "nvim/log.h"
#include "nvim/macros.h"
#include "nvim/os/os.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/libuv_process.c.generated.h"
#endif

/// @returns zero on success, or negative error code
int libuv_process_spawn(LibuvProcess *uvproc)
  FUNC_ATTR_NONNULL_ALL
{
  Process *proc = (Process *)uvproc;
  uvproc->uvopts.file = proc->argv[0];
  uvproc->uvopts.args = proc->argv;
  uvproc->uvopts.flags = UV_PROCESS_WINDOWS_HIDE;
#ifdef WIN32
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
  uvproc->uvstdio[0].data.fd = -1;
  uvproc->uvstdio[1].data.fd = -1;
  uvproc->uvstdio[2].data.fd = -1;
  uvproc->uv.data = proc;

  if (proc->env) {
    uvproc->uvopts.env = tv_dict_to_env(proc->env);
  } else {
    uvproc->uvopts.env = NULL;
  }

#ifndef WIN32
  int fds[2];
  int server_flags, client_flags;
#endif

  if (!proc->in.closed) {
#ifdef WIN32
    uvproc->uvstdio[0].flags = UV_CREATE_PIPE | UV_READABLE_PIPE
      | (proc->overlapped ? UV_NONBLOCK_PIPE : 0);
    uvproc->uvstdio[0].data.stream = STRUCT_CAST(uv_stream_t,
                                                 &proc->in.uv.pipe);
#else
    server_flags = UV_NONBLOCK_PIPE;
    client_flags = UV_NONBLOCK_PIPE;
    uvproc->uvstdio[0].flags = UV_INHERIT_FD | UV_READABLE_PIPE;
    int err;
    if ((err = uv_pipe(fds, client_flags, server_flags)) != 0) {
      ELOG("uv_pipe failed: %s", uv_strerror(err));
      return err;
    }
    uv_pipe_open(&proc->in.uv.pipe, fds[1]);
    uvproc->uvstdio[0].data.fd = fds[0];
#endif
  }

  if (!proc->out.closed) {
#ifdef WIN32
    // pipe must be readable for IOCP to work on Windows.
    uvproc->uvstdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE
      | (proc->overlapped ? (UV_NONBLOCK_PIPE | UV_READABLE_PIPE) : 0);
    uvproc->uvstdio[1].data.stream = STRUCT_CAST(uv_stream_t,
                                                 &proc->out.uv.pipe);
#else
    server_flags = UV_NONBLOCK_PIPE;
    client_flags = UV_NONBLOCK_PIPE;
    uvproc->uvstdio[1].flags = UV_INHERIT_FD | UV_WRITABLE_PIPE;
    int err;
    if ((err = uv_pipe(fds, server_flags, client_flags)) != 0) {
      ELOG("uv_pipe failed: %s", uv_strerror(err));
      return err;
    }
    uv_pipe_open(&proc->out.uv.pipe, fds[0]);
    uvproc->uvstdio[1].data.fd = fds[1];
#endif
  }

  if (!proc->err.closed) {
#ifdef WIN32
    uvproc->uvstdio[2].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
    uvproc->uvstdio[2].data.stream = STRUCT_CAST(uv_stream_t,
                                                 &proc->err.uv.pipe);
#else
    server_flags = UV_NONBLOCK_PIPE;
    client_flags = UV_NONBLOCK_PIPE;
    uvproc->uvstdio[2].flags = UV_INHERIT_FD | UV_WRITABLE_PIPE;
    int err;
    if ((err = uv_pipe(fds, server_flags, client_flags)) != 0) {
      ELOG("uv_pipe failed: %s", uv_strerror(err));
      return err;
    }
    uv_pipe_open(&proc->err.uv.pipe, fds[0]);
    uvproc->uvstdio[2].data.fd = fds[1];
#endif
  }

  int status;
  if ((status = uv_spawn(&proc->loop->uv, &uvproc->uv, &uvproc->uvopts))) {
    ELOG("uv_spawn(%s) failed: %s", uvproc->uvopts.file, uv_strerror(status));
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
#if defined(WIN32)
  // Use stored/expected signal.
  term_signal = proc->exit_signal;
#endif
  proc->status = term_signal ? 128 + term_signal : (int)status;
  proc->internal_exit_cb(proc);
}
