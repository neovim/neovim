#include <assert.h>

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/event/process.h"
#include "nvim/event/libuv_process.h"
#include "nvim/log.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/libuv_process.c.generated.h"
#endif

bool libuv_process_spawn(LibuvProcess *uvproc)
  FUNC_ATTR_NONNULL_ALL
{
  Process *proc = (Process *)uvproc;
  uvproc->uvopts.file = proc->argv[0];
  uvproc->uvopts.args = proc->argv;
  uvproc->uvopts.flags = UV_PROCESS_WINDOWS_HIDE
                  | UV_PROCESS_WINDOWS_VERBATIM_ARGUMENTS;
  uvproc->uvopts.exit_cb = exit_cb;
  uvproc->uvopts.cwd = NULL;
  uvproc->uvopts.env = NULL;
  uvproc->uvopts.stdio = uvproc->uvstdio;
  uvproc->uvopts.stdio_count = 3;
  uvproc->uvstdio[0].flags = UV_IGNORE;
  uvproc->uvstdio[1].flags = UV_IGNORE;
  uvproc->uvstdio[2].flags = UV_IGNORE;
  uvproc->uv.data = proc;

  if (proc->in) {
    uvproc->uvstdio[0].flags = UV_CREATE_PIPE | UV_READABLE_PIPE;
    uvproc->uvstdio[0].data.stream = (uv_stream_t *)&proc->in->uv.pipe;
  }

  if (proc->out) {
    uvproc->uvstdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
    uvproc->uvstdio[1].data.stream = (uv_stream_t *)&proc->out->uv.pipe;
  }

  if (proc->err) {
    uvproc->uvstdio[2].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
    uvproc->uvstdio[2].data.stream = (uv_stream_t *)&proc->err->uv.pipe;
  }

  int status;
  if ((status = uv_spawn(&proc->loop->uv, &uvproc->uv, &uvproc->uvopts))) {
    ELOG("uv_spawn failed: %s", uv_strerror(status));
    return false;
  }

  proc->pid = uvproc->uv.pid;
  return true;
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
}

static void exit_cb(uv_process_t *handle, int64_t status, int term_signal)
{
  Process *proc = handle->data;
  proc->status = (int)status;
  proc->internal_exit_cb(proc);
}
