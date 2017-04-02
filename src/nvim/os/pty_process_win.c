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

static void CALLBACK pty_process_finish1(void *context, BOOLEAN unused)
  FUNC_ATTR_NONNULL_ALL
{
  PtyProcess *ptyproc = (PtyProcess *)context;
  Process *proc = (Process *)ptyproc;

  uv_timer_init(&proc->loop->uv, &ptyproc->wait_eof_timer);
  ptyproc->wait_eof_timer.data = (void *)ptyproc;
  uv_timer_start(&ptyproc->wait_eof_timer, wait_eof_timer_cb, 200, 200);
}

/// @returns zero on sucess, or error code of winpty or MultiByteToWideChar.
int pty_process_spawn(PtyProcess *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  Process *proc = (Process *)ptyproc;
  int status = 0;
  winpty_error_ptr_t err = NULL;
  winpty_config_t *cfg = NULL;
  winpty_spawn_config_t *spawncfg = NULL;
  winpty_t *winpty_object = NULL;
  char *in_name = NULL;
  char *out_name = NULL;
  HANDLE process_handle = NULL;
  uv_connect_t *in_req = NULL;
  uv_connect_t *out_req = NULL;
  wchar_t *cmd_line = NULL;
  wchar_t *cwd = NULL;

  assert(!proc->err);

  cfg = winpty_config_new(WINPTY_FLAG_ALLOW_CURPROC_DESKTOP_CREATION, &err);
  if (cfg == NULL) {
    goto cleanup;
  }

  winpty_config_set_initial_size(cfg, ptyproc->width, ptyproc->height);
  winpty_object = winpty_open(cfg, &err);
  if (winpty_object == NULL) {
    goto cleanup;
  }

  status = utf16_to_utf8(winpty_conin_name(winpty_object), &in_name);
  if (status != 0) {
    goto cleanup;
  }

  status = utf16_to_utf8(winpty_conout_name(winpty_object), &out_name);
  if (status != 0) {
    goto cleanup;
  }

  if (proc->in != NULL) {
    in_req = xmalloc(sizeof(uv_connect_t));
    uv_pipe_connect(
        in_req,
        &proc->in->uv.pipe,
        in_name,
        pty_process_connect_cb);
  }

  if (proc->out != NULL) {
    out_req = xmalloc(sizeof(uv_connect_t));
    uv_pipe_connect(
        out_req,
        &proc->out->uv.pipe,
        out_name,
        pty_process_connect_cb);
  }

  if (proc->cwd != NULL) {
    status = utf8_to_utf16(proc->cwd, &cwd);
    if (status != 0) {
      goto cleanup;
    }
  }

  status = build_cmd_line(proc->argv, &cmd_line);
  if (status != 0) {
    goto cleanup;
  }

  spawncfg = winpty_spawn_config_new(
      WINPTY_SPAWN_FLAG_AUTO_SHUTDOWN,
      NULL,  // Optional application name
      cmd_line,
      cwd,
      NULL,  // Optional environment variables
      &err);
  if (spawncfg == NULL) {
    goto cleanup;
  }

  if (!winpty_spawn(winpty_object,
                    spawncfg,
                    &process_handle,
                    NULL,  // Optional thread handle
                    NULL,  // Optional create process error
                    &err)) {
    goto cleanup;
  }
  proc->pid = GetProcessId(process_handle);

  if (!RegisterWaitForSingleObject(
      &ptyproc->finish_wait,
      process_handle,
      pty_process_finish1,
      ptyproc,
      INFINITE,
      WT_EXECUTEDEFAULT | WT_EXECUTEONLYONCE)) {
    abort();
  }

  // Wait until pty_process_connect_cb is called.
  while ((in_req != NULL && in_req->handle != NULL)
         || (out_req != NULL && out_req->handle != NULL)) {
    uv_run(&proc->loop->uv, UV_RUN_ONCE);
  }

  ptyproc->winpty_object = winpty_object;
  ptyproc->process_handle = process_handle;
  winpty_object = NULL;
  process_handle = NULL;

cleanup:
  winpty_error_free(err);
  winpty_config_free(cfg);
  winpty_spawn_config_free(spawncfg);
  winpty_free(winpty_object);
  xfree(in_name);
  xfree(out_name);
  if (process_handle != NULL) {
    CloseHandle(process_handle);
  }
  xfree(in_req);
  xfree(out_req);
  xfree(cmd_line);
  xfree(cwd);
  return status;
}

void pty_process_resize(PtyProcess *ptyproc, uint16_t width,
                        uint16_t height)
  FUNC_ATTR_NONNULL_ALL
{
  if (ptyproc->winpty_object != NULL) {
    winpty_set_size(ptyproc->winpty_object, width, height, NULL);
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
  if (ptyproc->winpty_object != NULL) {
    winpty_free(ptyproc->winpty_object);
    ptyproc->winpty_object = NULL;
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

/// Build the command line to pass to CreateProcessW.
///
/// @param[in]  argv  Array with string arguments.
/// @param[out]  cmd_line  Location where saved bulded cmd line.
///
/// @returns zero on sucess, or error code of MultiByteToWideChar function.
///
static int build_cmd_line(char **argv, wchar_t **cmd_line)
  FUNC_ATTR_NONNULL_ALL
{
  size_t utf8_cmd_line_len = 0;
  size_t argc = 0;
  QUEUE args_q;

  QUEUE_INIT(&args_q);
  while (*argv) {
    size_t buf_len = strlen(*argv) * 2 + 3;
    ArgNode *arg_node = xmalloc(sizeof(*arg_node));
    arg_node->arg = xmalloc(buf_len);
    quote_cmd_arg(arg_node->arg, buf_len, *argv);
    utf8_cmd_line_len += strlen(arg_node->arg);
    QUEUE_INIT(&arg_node->node);
    QUEUE_INSERT_TAIL(&args_q, &arg_node->node);
    argc++;
    argv++;
  }

  utf8_cmd_line_len += argc;
  char *utf8_cmd_line = xmalloc(utf8_cmd_line_len);
  *utf8_cmd_line = NUL;
  while (1) {
    QUEUE *head = QUEUE_HEAD(&args_q);
    QUEUE_REMOVE(head);
    ArgNode *arg_node = QUEUE_DATA(head, ArgNode, node);
    xstrlcat(utf8_cmd_line, arg_node->arg, utf8_cmd_line_len);
    xfree(arg_node->arg);
    xfree(arg_node);
    if (QUEUE_EMPTY(&args_q)) {
      break;
    } else {
      xstrlcat(utf8_cmd_line, " ", utf8_cmd_line_len);
    }
  }

  int result = utf8_to_utf16(utf8_cmd_line, cmd_line);
  if (result != 0) {
  }
  xfree(utf8_cmd_line);
  return result;
}

/// Emulate quote_cmd_arg of libuv and quotes command line argument.
/// Most of the code came from libuv.
///
/// @param[out]  dist  Location where saved quotes argument.
/// @param  dist_remaining  Deistnation buffer size.
/// @param[in]  src Pointer to argument.
///
static void quote_cmd_arg(char *dist, size_t dist_remaining, const char *src)
  FUNC_ATTR_NONNULL_ALL
{
  size_t src_len = strlen(src);
  bool quote_hit = true;
  char *start = dist;

  if (src_len == 0) {
    // Need double quotation for empty argument.
    snprintf(dist, dist_remaining, "\"\"");
    return;
  }

  if (NULL == strpbrk(src, " \t\"")) {
    // No quotation needed.
    xstrlcpy(dist, src, dist_remaining);
    return;
  }

  if (NULL == strpbrk(src, "\"\\")) {
    // No embedded double quotes or backlashes, so I can just wrap quote marks.
    // around the whole thing.
    snprintf(dist, dist_remaining, "\"%s\"", src);
    return;
  }

  // Expected input/output:
  //   input : hello"world
  //   output: "hello\"world"
  //   input : hello""world
  //   output: "hello\"\"world"
  //   input : hello\world
  //   output: hello\world
  //   input : hello\\world
  //   output: hello\\world
  //   input : hello\"world
  //   output: "hello\\\"world"
  //   input : hello\\"world
  //   output: "hello\\\\\"world"
  //   input : hello world\
  //   output: "hello world\\"

  assert(dist_remaining--);
  *(dist++) = NUL;
  assert(dist_remaining--);
  *(dist++) = '"';
  for (size_t i = src_len; i > 0; i--) {
    assert(dist_remaining--);
    *(dist++) = src[i - 1];
    if (quote_hit && src[i - 1] == '\\') {
      assert(dist_remaining--);
      *(dist++) = '\\';
    } else if (src[i - 1] == '"') {
      quote_hit = true;
      assert(dist_remaining--);
      *(dist++) = '\\';
    } else {
      quote_hit = false;
    }
  }
  assert(dist_remaining);
  *dist = '"';

  while (start < dist) {
    char tmp = *start;
    *start = *dist;
    *dist = tmp;
    start++;
    dist--;
  }
}
