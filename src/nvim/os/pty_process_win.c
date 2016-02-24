#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>

#include "nvim/memory.h"
#include "nvim/os/pty_process_win.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process_win.c.generated.h"
#endif

static void CALLBACK pty_process_finish1(void *context, BOOLEAN unused)
{
  uv_async_t *finish_async = (uv_async_t *)context;
  uv_async_send(finish_async);
}

bool pty_process_spawn(PtyProcess *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  Process *proc = (Process *)ptyproc;
  bool success = false;
  winpty_error_ptr_t err = NULL;
  winpty_config_t *cfg = NULL;
  winpty_spawn_config_t *spawncfg = NULL;
  winpty_t *wp = NULL;
  char *in_name = NULL, *out_name = NULL;
  HANDLE process_handle = NULL;

  assert(proc->in && proc->out && !proc->err);

  if (!(cfg = winpty_config_new(
      WINPTY_FLAG_ALLOW_CURPROC_DESKTOP_CREATION, &err))) {
    goto cleanup;
  }
  winpty_config_set_initial_size(cfg, ptyproc->width, ptyproc->height);

  if (!(wp = winpty_open(cfg, &err))) {
    goto cleanup;
  }

  in_name = utf16_to_utf8(winpty_conin_name(wp));
  out_name = utf16_to_utf8(winpty_conout_name(wp));
  uv_pipe_connect(
      xmalloc(sizeof(uv_connect_t)),
      &proc->in->uv.pipe,
      in_name,
      pty_process_connect_cb);
  uv_pipe_connect(
      xmalloc(sizeof(uv_connect_t)),
      &proc->out->uv.pipe,
      out_name,
      pty_process_connect_cb);

  // XXX: Provide the correct ptyprocess parameters (at least, the cmdline...
  // probably cwd too?  what about environ?)
  if (!(spawncfg = winpty_spawn_config_new(
      WINPTY_SPAWN_FLAG_AUTO_SHUTDOWN,
      L"C:\\Windows\\System32\\cmd.exe",
      L"C:\\Windows\\System32\\cmd.exe",
      NULL, NULL,
      &err))) {
    goto cleanup;
  }
  if (!winpty_spawn(wp, spawncfg, &process_handle, NULL, NULL, &err)) {
    goto cleanup;
  }

  uv_async_init(&proc->loop->uv, &ptyproc->finish_async, pty_process_finish2);
  if (!RegisterWaitForSingleObject(&ptyproc->finish_wait, process_handle,
      pty_process_finish1, &ptyproc->finish_async, INFINITE, 0)) {
    abort();
  }

  ptyproc->wp = wp;
  ptyproc->process_handle = process_handle;
  wp = NULL;
  process_handle = NULL;
  success = true;

cleanup:
  winpty_error_free(err);
  winpty_config_free(cfg);
  winpty_spawn_config_free(spawncfg);
  winpty_free(wp);
  xfree(in_name);
  xfree(out_name);
  if (process_handle != NULL) {
    CloseHandle(process_handle);
  }
  return success;
}

void pty_process_resize(PtyProcess *ptyproc, uint16_t width,
                        uint16_t height)
  FUNC_ATTR_NONNULL_ALL
{
  if (ptyproc->wp != NULL) {
    winpty_set_size(ptyproc->wp, width, height, NULL);
  }
}

void pty_process_close(PtyProcess *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  Process *proc = (Process *)ptyproc;

  ptyproc->is_closing = true;
  pty_process_close_master(ptyproc);

  uv_handle_t *finish_async_handle = (uv_handle_t *)&ptyproc->finish_async;
  if (ptyproc->finish_wait != NULL) {
    // Use INVALID_HANDLE_VALUE to block until either the wait is cancelled
    // or the callback has signalled the uv_async_t.
    UnregisterWaitEx(ptyproc->finish_wait, INVALID_HANDLE_VALUE);
    uv_close(finish_async_handle, pty_process_finish_closing);
  } else {
    pty_process_finish_closing(finish_async_handle);
  }
}

void pty_process_close_master(PtyProcess *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  if (ptyproc->wp != NULL) {
    winpty_free(ptyproc->wp);
    ptyproc->wp = NULL;
  }
}

void pty_process_teardown(Loop *loop)
  FUNC_ATTR_NONNULL_ALL
{
}

// Returns a string freeable with xfree.  Never returns NULL (OOM is a fatal
// error).  Windows appears to replace invalid UTF-16 code points (i.e.
// unpaired surrogates) using U+FFFD (the replacement character).
static char *utf16_to_utf8(LPCWSTR str)
  FUNC_ATTR_NONNULL_ALL
{
  int len = WideCharToMultiByte(CP_UTF8, 0, str, -1, NULL, 0, NULL, NULL);
  assert(len >= 1);  // Even L"" has a non-zero length due to NUL terminator.
  char *ret = xmalloc(len);
  int len2 = WideCharToMultiByte(CP_UTF8, 0, str, -1, ret, len, NULL, NULL);
  assert(len == len2);
  return ret;
}

static void pty_process_connect_cb(uv_connect_t *req, int status)
{
  assert(status == 0);
  xfree(req);
}

static void pty_process_finish2(uv_async_t *finish_async)
{
  PtyProcess *ptyproc =
    (PtyProcess *)((char *)finish_async - offsetof(PtyProcess, finish_async));
  Process *proc = (Process *)ptyproc;

  if (!ptyproc->is_closing) {
    // If pty_process_close has already been called, be consistent and never
    // call the internal_exit callback.

    DWORD exit_code = 0;
    GetExitCodeProcess(ptyproc->process_handle, &exit_code);
    proc->status = exit_code;

    if (proc->internal_exit_cb) {
      proc->internal_exit_cb(proc);
    }
  }
}

static void pty_process_finish_closing(uv_handle_t *finish_async)
{
  PtyProcess *ptyproc =
    (PtyProcess *)((char *)finish_async - offsetof(PtyProcess, finish_async));
  Process *proc = (Process *)ptyproc;

  if (ptyproc->process_handle != NULL) {
    CloseHandle(ptyproc->process_handle);
    ptyproc->process_handle = NULL;
  }
  if (proc->internal_close_cb) {
    proc->internal_close_cb(proc);
  }
}
