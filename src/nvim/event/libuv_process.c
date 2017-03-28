#include <assert.h>

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/event/process.h"
#include "nvim/event/libuv_process.h"
#include "nvim/log.h"
#include "nvim/path.h"
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
  if (proc->detach) {
      uvproc->uvopts.flags |= UV_PROCESS_DETACHED;
  }
#ifdef WIN32
  // libuv assumes spawned processes follow the convention from
  // CommandLineToArgvW(), cmd.exe does not. Disable quoting since it will
  // result in unexpected behaviour, the caller is left with the responsibility
  // to quote arguments accordingly. system('') has shell* options for this.
  //
  // Disable quoting for cmd, cmd.exe and $COMSPEC with a cmd.exe filename
  bool is_cmd = STRICMP(proc->argv[0], "cmd.exe") == 0
                || STRICMP(proc->argv[0], "cmd") == 0;
  if (!is_cmd) {
    const char_u *comspec = (char_u *)os_getenv("COMSPEC");
    const char_u *comspecshell = path_tail((char_u *)proc->argv[0]);
    is_cmd = comspec != NULL && STRICMP(proc->argv[0], comspec) == 0
             && STRICMP("cmd.exe", (char *)comspecshell) == 0;
  }

  if (is_cmd) {
    uvproc->uvopts.flags |= UV_PROCESS_WINDOWS_VERBATIM_ARGUMENTS;
  }
#endif
  uvproc->uvopts.exit_cb = exit_cb;
  uvproc->uvopts.cwd = proc->cwd;
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
}

static void exit_cb(uv_process_t *handle, int64_t status, int term_signal)
{
  Process *proc = handle->data;
  proc->status = (int)status;
  proc->internal_exit_cb(proc);
}
