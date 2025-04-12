#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>

#include "nvim/ascii_defs.h"
#include "nvim/eval/typval.h"
#include "nvim/event/loop.h"
#include "nvim/log.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/os/os.h"
#include "nvim/os/pty_conpty_win.h"
#include "nvim/os/pty_proc_win.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_proc_win.c.generated.h"
#endif

static void CALLBACK pty_proc_terminate_cb(void *context, BOOLEAN unused)
  FUNC_ATTR_NONNULL_ALL
{
  PtyProc *ptyproc = (PtyProc *)context;
  Proc *proc = (Proc *)ptyproc;

  os_conpty_free(ptyproc->conpty);
  // NB: pty_proc_terminate_cb() is called on a separate thread,
  // but finishing up the process needs to be done on the main thread.
  loop_schedule_fast(proc->loop, event_create(pty_proc_finish_when_eof, ptyproc));
}

static void pty_proc_finish_when_eof(void **argv)
  FUNC_ATTR_NONNULL_ALL
{
  PtyProc *ptyproc = (PtyProc *)argv[0];

  if (ptyproc->finish_wait != NULL) {
    if (pty_proc_can_finish(ptyproc)) {
      pty_proc_finish(ptyproc);
    } else {
      uv_timer_start(&ptyproc->wait_eof_timer, wait_eof_timer_cb, 200, 200);
    }
  }
}

static bool pty_proc_can_finish(PtyProc *ptyproc)
{
  Proc *proc = (Proc *)ptyproc;

  assert(ptyproc->finish_wait != NULL);
  return proc->out.s.closed || proc->out.did_eof || !uv_is_readable(proc->out.s.uvstream);
}

/// @returns zero on success, or negative error code.
int pty_proc_spawn(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  Proc *proc = (Proc *)ptyproc;
  int status = 0;
  conpty_t *conpty_object = NULL;
  char *in_name = NULL;
  char *out_name = NULL;
  HANDLE proc_handle = NULL;
  uv_connect_t *in_req = NULL;
  uv_connect_t *out_req = NULL;
  wchar_t *cmd_line = NULL;
  wchar_t *cwd = NULL;
  wchar_t *env = NULL;
  const char *emsg = NULL;

  assert(proc->err.s.closed);

  if (!os_has_conpty_working() || (conpty_object = os_conpty_init(&in_name,
                                                                  &out_name, ptyproc->width,
                                                                  ptyproc->height)) == NULL) {
    status = UV_ENOSYS;
    goto cleanup;
  }

  if (!proc->in.closed) {
    in_req = xmalloc(sizeof(uv_connect_t));
    uv_pipe_connect(in_req,
                    &proc->in.uv.pipe,
                    in_name,
                    pty_proc_connect_cb);
  }

  if (!proc->out.s.closed) {
    out_req = xmalloc(sizeof(uv_connect_t));
    uv_pipe_connect(out_req,
                    &proc->out.s.uv.pipe,
                    out_name,
                    pty_proc_connect_cb);
  }

  if (proc->cwd != NULL) {
    status = utf8_to_utf16(proc->cwd, -1, &cwd);
    if (status != 0) {
      emsg = "utf8_to_utf16(proc->cwd) failed";
      goto cleanup;
    }
  }

  status = build_cmd_line(proc->argv, &cmd_line,
                          os_shell_is_cmdexe(proc->argv[0]));
  if (status != 0) {
    emsg = "build_cmd_line failed";
    goto cleanup;
  }

  if (proc->env != NULL) {
    status = build_env_block(proc->env, &env);
  }

  if (status != 0) {
    emsg = "build_env_block failed";
    goto cleanup;
  }

  if (!os_conpty_spawn(conpty_object,
                       &proc_handle,
                       NULL,
                       cmd_line,
                       cwd,
                       env)) {
    emsg = "os_conpty_spawn failed";
    status = (int)GetLastError();
    goto cleanup;
  }
  proc->pid = (int)GetProcessId(proc_handle);

  uv_timer_init(&proc->loop->uv, &ptyproc->wait_eof_timer);
  ptyproc->wait_eof_timer.data = (void *)ptyproc;
  if (!RegisterWaitForSingleObject(&ptyproc->finish_wait,
                                   proc_handle,
                                   pty_proc_terminate_cb,
                                   ptyproc,
                                   INFINITE,
                                   WT_EXECUTEDEFAULT | WT_EXECUTEONLYONCE)) {
    abort();
  }

  // Wait until pty_proc_connect_cb is called.
  while ((in_req != NULL && in_req->handle != NULL)
         || (out_req != NULL && out_req->handle != NULL)) {
    uv_run(&proc->loop->uv, UV_RUN_ONCE);
  }

  ptyproc->conpty = conpty_object;
  ptyproc->proc_handle = proc_handle;
  conpty_object = NULL;
  proc_handle = NULL;

cleanup:
  if (status) {
    // In the case of an error of MultiByteToWideChar or CreateProcessW.
    ELOG("pty_proc_spawn(%s): %s: error code: %d",
         proc->argv[0], emsg, status);
    status = os_translate_sys_error(status);
  }
  os_conpty_free(conpty_object);
  xfree(in_name);
  xfree(out_name);
  if (proc_handle != NULL) {
    CloseHandle(proc_handle);
  }
  xfree(in_req);
  xfree(out_req);
  xfree(cmd_line);
  xfree(env);
  xfree(cwd);
  return status;
}

const char *pty_proc_tty_name(PtyProc *ptyproc)
{
  return "?";
}

void pty_proc_resize(PtyProc *ptyproc, uint16_t width, uint16_t height)
  FUNC_ATTR_NONNULL_ALL
{
  os_conpty_set_size(ptyproc->conpty, width, height);
}

void pty_proc_close(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  Proc *proc = (Proc *)ptyproc;

  pty_proc_close_master(ptyproc);

  if (ptyproc->finish_wait != NULL) {
    UnregisterWaitEx(ptyproc->finish_wait, NULL);
    ptyproc->finish_wait = NULL;
    uv_close((uv_handle_t *)&ptyproc->wait_eof_timer, NULL);
  }
  if (ptyproc->proc_handle != NULL) {
    CloseHandle(ptyproc->proc_handle);
    ptyproc->proc_handle = NULL;
  }

  if (proc->internal_close_cb) {
    proc->internal_close_cb(proc);
  }
}

void pty_proc_close_master(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
}

void pty_proc_teardown(Loop *loop)
  FUNC_ATTR_NONNULL_ALL
{
}

static void pty_proc_connect_cb(uv_connect_t *req, int status)
  FUNC_ATTR_NONNULL_ALL
{
  assert(status == 0);
  req->handle = NULL;
}

static void wait_eof_timer_cb(uv_timer_t *wait_eof_timer)
  FUNC_ATTR_NONNULL_ALL
{
  PtyProc *ptyproc = wait_eof_timer->data;
  if (pty_proc_can_finish(ptyproc)) {
    uv_timer_stop(&ptyproc->wait_eof_timer);
    pty_proc_finish(ptyproc);
  }
}

static void pty_proc_finish(PtyProc *ptyproc)
  FUNC_ATTR_NONNULL_ALL
{
  Proc *proc = (Proc *)ptyproc;

  DWORD exit_code = 0;
  GetExitCodeProcess(ptyproc->proc_handle, &exit_code);
  proc->status = proc->exit_signal ? 128 + proc->exit_signal : (int)exit_code;

  proc->internal_exit_cb(proc);
}

/// Build the command line to pass to CreateProcessW.
///
/// @param[in]  argv  Array with string arguments.
/// @param[out]  cmd_line  Location where saved built cmd line.
///
/// @returns zero on success, or error code of MultiByteToWideChar function.
///
static int build_cmd_line(char **argv, wchar_t **cmd_line, bool is_cmdexe)
  FUNC_ATTR_NONNULL_ALL
{
  size_t utf8_cmd_line_len = 0;
  size_t argc = 0;
  QUEUE args_q;

  QUEUE_INIT(&args_q);
  while (*argv) {
    size_t buf_len = is_cmdexe ? (strlen(*argv) + 1) : (strlen(*argv) * 2 + 3);
    ArgNode *arg_node = xmalloc(sizeof(*arg_node));
    arg_node->arg = xmalloc(buf_len);
    if (is_cmdexe) {
      xstrlcpy(arg_node->arg, *argv, buf_len);
    } else {
      quote_cmd_arg(arg_node->arg, buf_len, *argv);
    }
    utf8_cmd_line_len += strlen(arg_node->arg);
    QUEUE_INIT(&arg_node->node);
    QUEUE_INSERT_TAIL(&args_q, &arg_node->node);
    argc++;
    argv++;
  }

  utf8_cmd_line_len += argc;
  char *utf8_cmd_line = xmalloc(utf8_cmd_line_len);
  *utf8_cmd_line = NUL;
  QUEUE *q;
  QUEUE_FOREACH(q, &args_q, {
    ArgNode *arg_node = QUEUE_DATA(q, ArgNode, node);
    xstrlcat(utf8_cmd_line, arg_node->arg, utf8_cmd_line_len);
    QUEUE_REMOVE(q);
    xfree(arg_node->arg);
    xfree(arg_node);
    if (!QUEUE_EMPTY(&args_q)) {
      xstrlcat(utf8_cmd_line, " ", utf8_cmd_line_len);
    }
  })

  int result = utf8_to_utf16(utf8_cmd_line, -1, cmd_line);
  xfree(utf8_cmd_line);
  return result;
}

/// Emulate quote_cmd_arg of libuv and quotes command line argument.
/// Most of the code came from libuv.
///
/// @param[out]  dest  Location where saved quotes argument.
/// @param  dest_remaining  Destination buffer size.
/// @param[in]  src Pointer to argument.
///
static void quote_cmd_arg(char *dest, size_t dest_remaining, const char *src)
  FUNC_ATTR_NONNULL_ALL
{
  size_t src_len = strlen(src);
  bool quote_hit = true;
  char *start = dest;

  if (src_len == 0) {
    // Need double quotation for empty argument.
    snprintf(dest, dest_remaining, "\"\"");
    return;
  }

  if (NULL == strpbrk(src, " \t\"")) {
    // No quotation needed.
    xstrlcpy(dest, src, dest_remaining);
    return;
  }

  if (NULL == strpbrk(src, "\"\\")) {
    // No embedded double quotes or backlashes, so I can just wrap quote marks.
    // around the whole thing.
    snprintf(dest, dest_remaining, "\"%s\"", src);
    return;
  }

  // Expected input/output:
  //   input : 'hello"world'
  //   output: '"hello\"world"'
  //   input : 'hello""world'
  //   output: '"hello\"\"world"'
  //   input : 'hello\world'
  //   output: 'hello\world'
  //   input : 'hello\\world'
  //   output: 'hello\\world'
  //   input : 'hello\"world'
  //   output: '"hello\\\"world"'
  //   input : 'hello\\"world'
  //   output: '"hello\\\\\"world"'
  //   input : 'hello world\'
  //   output: '"hello world\\"'

  assert(dest_remaining--);
  *(dest++) = NUL;
  assert(dest_remaining--);
  *(dest++) = '"';
  for (size_t i = src_len; i > 0; i--) {
    assert(dest_remaining--);
    *(dest++) = src[i - 1];
    if (quote_hit && src[i - 1] == '\\') {
      assert(dest_remaining--);
      *(dest++) = '\\';
    } else if (src[i - 1] == '"') {
      quote_hit = true;
      assert(dest_remaining--);
      *(dest++) = '\\';
    } else {
      quote_hit = false;
    }
  }
  assert(dest_remaining);
  *dest = '"';

  while (start < dest) {
    char tmp = *start;
    *start = *dest;
    *dest = tmp;
    start++;
    dest--;
  }
}

typedef struct EnvNode {
  wchar_t *str;
  size_t len;
  QUEUE node;
} EnvNode;

/// Build the environment block to pass to CreateProcessW.
///
/// @param[in]  denv  Dict of environment name/value pairs
/// @param[out]  env  Allocated environment block
///
/// @returns zero on success or error code of MultiByteToWideChar function.
static int build_env_block(dict_T *denv, wchar_t **env_block)
{
  const size_t denv_size = (size_t)tv_dict_len(denv);
  size_t env_block_len = 0;
  int rc = 0;
  char **env = tv_dict_to_env(denv);

  QUEUE *q;
  QUEUE env_q;
  QUEUE_INIT(&env_q);
  // Convert env vars to wchar_t and calculate how big the final env block
  // needs to be
  for (size_t i = 0; i < denv_size; i++) {
    EnvNode *env_node = xmalloc(sizeof(*env_node));
    rc = utf8_to_utf16(env[i], -1, &env_node->str);
    if (rc != 0) {
      goto cleanup;
    }
    env_node->len = wcslen(env_node->str) + 1;
    env_block_len += env_node->len;
    QUEUE_INSERT_TAIL(&env_q, &env_node->node);
  }

  // Additional NUL after the final entry
  env_block_len++;

  *env_block = xmalloc(sizeof(**env_block) * env_block_len);
  wchar_t *pos = *env_block;

  QUEUE_FOREACH(q, &env_q, {
    EnvNode *env_node = QUEUE_DATA(q, EnvNode, node);
    memcpy(pos, env_node->str, env_node->len * sizeof(*pos));
    pos += env_node->len;
  })

  *pos = L'\0';

cleanup:
  q = QUEUE_HEAD(&env_q);
  while (q != &env_q) {
    QUEUE *next = q->next;
    EnvNode *env_node = QUEUE_DATA(q, EnvNode, node);
    XFREE_CLEAR(env_node->str);
    QUEUE_REMOVE(q);
    xfree(env_node);
    q = next;
  }

  return rc;
}

PtyProc pty_proc_init(Loop *loop, void *data)
{
  PtyProc rv;
  rv.proc = proc_init(loop, kProcTypePty, data);
  rv.width = 80;
  rv.height = 24;
  rv.conpty = NULL;
  rv.finish_wait = NULL;
  rv.proc_handle = NULL;
  return rv;
}
