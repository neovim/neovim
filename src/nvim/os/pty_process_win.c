#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/memory.h"
#include "nvim/mbyte.h"  // for utf8_to_utf16, utf16_to_utf8
#include "nvim/os/pty_process_win.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process_win.c.generated.h"
#endif

static void wait_eof_timer_cb(uv_timer_t *wait_eof_timer)
  FUNC_ATTR_NONNULL_ALL
{
  PtyProcess *ptyproc =
    (PtyProcess *)((uv_handle_t *)wait_eof_timer->data);
  Process *proc = (Process *)ptyproc;

  if (!proc->out || !uv_is_readable(proc->out->uvstream)) {
    uv_timer_stop(&ptyproc->wait_eof_timer);
    pty_process_finish2(ptyproc);
  }
}

static void CALLBACK pty_process_finish1(void *context, BOOLEAN unused)
  FUNC_ATTR_NONNULL_ALL
{
  PtyProcess *ptyproc = (PtyProcess *)context;
  Process *proc = (Process *)ptyproc;

  uv_timer_init(&proc->loop->uv, &ptyproc->wait_eof_timer);
  ptyproc->wait_eof_timer.data = (void *)ptyproc;
  uv_timer_start(&ptyproc->wait_eof_timer, wait_eof_timer_cb, 200, 200);
}

int pty_process_spawn(PtyProcess *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  Process *proc = (Process *)ptyproc;
  int status = 0;
  winpty_error_ptr_t err = NULL;
  winpty_config_t *cfg = NULL;
  winpty_spawn_config_t *spawncfg = NULL;
  winpty_t *wp = NULL;
  char *in_name = NULL, *out_name = NULL;
  HANDLE process_handle = NULL;
  uv_connect_t *in_req = NULL, *out_req = NULL;
  wchar_t *cmdline = NULL, *cwd = NULL;

  assert(!proc->err);

  if (!(cfg = winpty_config_new(
      WINPTY_FLAG_ALLOW_CURPROC_DESKTOP_CREATION, &err))) {
    goto cleanup;
  }
  winpty_config_set_initial_size(
      cfg,
      ptyproc->width,
      ptyproc->height);

  if (!(wp = winpty_open(cfg, &err))) {
    goto cleanup;
  }

  if ((status = utf16_to_utf8(winpty_conin_name(wp), &in_name))) {
    goto cleanup;
  }
  if ((status = utf16_to_utf8(winpty_conout_name(wp), &out_name))) {
    goto cleanup;
  }
  if (proc->in) {
    in_req = xmalloc(sizeof(uv_connect_t));
    uv_pipe_connect(
        in_req,
        &proc->in->uv.pipe,
        in_name,
        pty_process_connect_cb);
  }
  if (proc->out) {
    out_req = xmalloc(sizeof(uv_connect_t));
    uv_pipe_connect(
        out_req,
        &proc->out->uv.pipe,
        out_name,
        pty_process_connect_cb);
  }

  if (proc->cwd != NULL && (status = utf8_to_utf16(proc->cwd, &cwd))) {
    goto cleanup;
  }
  if ((status = build_cmdline(proc->argv, &cmdline))) {
    goto cleanup;
  }
  if (!(spawncfg = winpty_spawn_config_new(
      WINPTY_SPAWN_FLAG_AUTO_SHUTDOWN,
      NULL, cmdline, cwd, NULL, &err))) {
    goto cleanup;
  }
  if (!winpty_spawn(wp, spawncfg, &process_handle, NULL, NULL, &err)) {
    goto cleanup;
  }
  proc->pid = GetProcessId(process_handle);

  if (!RegisterWaitForSingleObject(
      &ptyproc->finish_wait,
      process_handle, pty_process_finish1, ptyproc,
      INFINITE, WT_EXECUTEDEFAULT | WT_EXECUTEONLYONCE)) {
    abort();
  }

  while ((in_req && in_req->handle) || (out_req && out_req->handle)) {
    uv_run(&proc->loop->uv, UV_RUN_ONCE);
  }

  ptyproc->wp = wp;
  ptyproc->process_handle = process_handle;
  wp = NULL;
  process_handle = NULL;

cleanup:
  if (err != NULL) {
    status = (int)winpty_error_code(err);
  }
  winpty_error_free(err);
  winpty_config_free(cfg);
  winpty_spawn_config_free(spawncfg);
  winpty_free(wp);
  xfree(in_name);
  xfree(out_name);
  if (process_handle != NULL) {
    CloseHandle(process_handle);
  }
  xfree(in_req);
  xfree(out_req);
  xfree(cmdline);
  xfree(cwd);
  return status;
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

  pty_process_close_master(ptyproc);

  if (proc->internal_close_cb) {
    proc->internal_close_cb(proc);
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

static void pty_process_connect_cb(uv_connect_t *req, int status)
  FUNC_ATTR_NONNULL_ALL
{
  assert(status == 0);
  req->handle = NULL;
}

static void pty_process_finish2(PtyProcess *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  Process *proc = (Process *)ptyproc;

  UnregisterWaitEx(ptyproc->finish_wait, NULL);
  uv_close((uv_handle_t *)&ptyproc->wait_eof_timer, NULL);

  DWORD exit_code = 0;
  GetExitCodeProcess(ptyproc->process_handle, &exit_code);
  proc->status = (int)exit_code;

  CloseHandle(ptyproc->process_handle);
  ptyproc->process_handle = NULL;

  proc->internal_exit_cb(proc);
}

static int build_cmdline(char **argv, wchar_t **cmdline)
  FUNC_ATTR_NONNULL_ALL
{
  char *args = NULL;
  size_t args_len = 0, argc = 0;
  int ret;
  QUEUE q;
  QUEUE_INIT(&q);

  while (*argv) {
    arg_T *arg = xmalloc(sizeof(arg_T));
    arg->arg = (char *)xmalloc(strlen(*argv) * 2 + 3);
    quote_cmd_arg(arg->arg, *argv);
    args_len += strlen(arg->arg);
    QUEUE_INIT(&arg->node);
    QUEUE_INSERT_TAIL(&q, &arg->node);
    argc++;
    argv++;
  }
  args_len += argc;
  args = xmalloc(args_len);
  *args = NUL;
  while (1) {
    QUEUE *head = QUEUE_HEAD(&q);
    QUEUE_REMOVE(head);
    arg_T *arg = QUEUE_DATA(head, arg_T, node);
    xstrlcat(args, arg->arg, args_len);
    xfree(arg->arg);
    xfree(arg);
    if (QUEUE_EMPTY(&q)) {
      break;
    } else {
      xstrlcat(args, " ", args_len);
    }
  }
  ret = utf8_to_utf16(args, cmdline);
  xfree(args);
  return ret;
}

// Emulate quote_cmd_arg of libuv and quotes command line arguments
static void quote_cmd_arg(char *target, const char *source)
  FUNC_ATTR_NONNULL_ALL
{
  size_t len = strlen(source);
  size_t i;
  bool quote_hit = true;
  char *start = target;
  char tmp;

  if (len == 0) {
    *(target++) = '"';
    *(target++) = '"';
    *target = NUL;
    return;
  }

  if (NULL == strpbrk(source, " \t\"")) {
    strcpy(target, source);
    return;
  }

  if (NULL == strpbrk(source, "\"\\")) {
    *(target++) = '"';
    strncpy(target, source, len);
    target += len;
    *(target++) = '"';
    *target = NUL;
    return;
  }

  *(target++) = NUL;
  *(target++) = '"';
  for (i = len; i > 0; --i) {
    *(target++) = source[i - 1];

    if (quote_hit && source[i - 1] == '\\') {
      *(target++) = '\\';
    } else if (source[i - 1] == '"') {
      quote_hit = true;
      *(target++) = '\\';
    } else {
      quote_hit = false;
    }
  }
  *target = '"';
  while (start < target) {
    tmp = *start;
    *start = *target;
    *target = tmp;
    start++;
    target--;
  }
  return;
}
