#include <string.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/os/shell.h"
#include "nvim/os/signal.h"
#include "nvim/types.h"
#include "nvim/vim.h"
#include "nvim/message.h"
#include "nvim/ascii.h"
#include "nvim/memory.h"
#include "nvim/term.h"
#include "nvim/misc2.h"
#include "nvim/screen.h"
#include "nvim/memline.h"
#include "nvim/option_defs.h"
#include "nvim/charset.h"
#include "nvim/strings.h"

#define BUFFER_LENGTH 1024

typedef struct {
  bool reading;
  int old_state, old_mode, exit_status, exited;
  char *wbuffer;
  char rbuffer[BUFFER_LENGTH];
  uv_buf_t bufs[2];
  uv_stream_t *shell_stdin;
  garray_T ga;
} ProcessData;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/shell.c.generated.h"
#endif


// Callbacks for libuv

/// Builds the argument vector for running the shell configured in `sh`
/// ('shell' option), optionally with a command that will be passed with `shcf`
/// ('shellcmdflag').
///
/// @param cmd Command string. If NULL it will run an interactive shell.
/// @param extra_shell_opt Extra argument to the shell. If NULL it is ignored
/// @return A newly allocated argument vector. It must be freed with
///         `shell_free_argv` when no longer needed.
char ** shell_build_argv(char_u *cmd, char_u *extra_shell_opt)
{
  int i;
  char **rv;
  int argc = tokenize(p_sh, NULL) + tokenize(p_shcf, NULL);

  rv = (char **)xmalloc((unsigned)((argc + 4) * sizeof(char *)));

  // Split 'shell'
  i = tokenize(p_sh, rv);

  if (extra_shell_opt != NULL) {
    // Push a copy of `extra_shell_opt`
    rv[i++] = xstrdup((char *)extra_shell_opt);
  }

  if (cmd != NULL) {
    // Split 'shellcmdflag'
    i += tokenize(p_shcf, rv + i);
    rv[i++] = xstrdup((char *)cmd);
  }

  rv[i] = NULL;

  return rv;
}

/// Releases the memory allocated by `shell_build_argv`.
///
/// @param argv The argument vector.
void shell_free_argv(char **argv)
{
  char **p = argv;

  if (p == NULL) {
    // Nothing was allocated, return
    return;
  }

  while (*p != NULL) {
    // Free each argument
    free(*p);
    p++;
  }

  free(argv);
}

/// Calls the user shell for running a command, interactive session or
/// wildcard expansion. It uses the shell set in the `sh` option.
///
/// @param cmd The command to be executed. If NULL it will run an interactive
///        shell
/// @param opts Various options that control how the shell will work
/// @param extra_shell_arg Extra argument to be passed to the shell
int os_call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg)
{
  uv_stdio_container_t proc_stdio[3];
  uv_process_options_t proc_opts;
  uv_process_t proc;
  uv_pipe_t proc_stdin, proc_stdout;
  uv_write_t write_req;
  int expected_exits = 1;
  ProcessData pdata = {
    .reading = false,
    .exited = 0,
    .old_mode = cur_tmode,
    .old_state = State,
    .shell_stdin = (uv_stream_t *)&proc_stdin,
    .wbuffer = NULL,
  };

  out_flush();
  if (opts & kShellOptCooked) {
    // set to normal mode
    settmode(TMODE_COOK);
  }

  // While the child is running, ignore terminating signals
  signal_reject_deadly();

  // Create argv for `uv_spawn`
  // TODO(tarruda): we can use a static buffer for small argument vectors. 1024
  // bytes should be enough for most of the commands and if more is necessary
  // we can allocate a another buffer
  proc_opts.args = shell_build_argv(cmd, extra_shell_arg);
  proc_opts.file = proc_opts.args[0];
  proc_opts.exit_cb = exit_cb;
  // Initialize libuv structures
  proc_opts.stdio = proc_stdio;
  proc_opts.stdio_count = 3;
  // Hide window on Windows :)
  proc_opts.flags = UV_PROCESS_WINDOWS_HIDE;
  proc_opts.cwd = NULL;
  proc_opts.env = NULL;

  // The default is to inherit all standard file descriptors(this will change
  // when the UI is moved to an external process)
  proc_stdio[0].flags = UV_INHERIT_FD;
  proc_stdio[0].data.fd = 0;
  proc_stdio[1].flags = UV_INHERIT_FD;
  proc_stdio[1].data.fd = 1;
  proc_stdio[2].flags = UV_INHERIT_FD;
  proc_stdio[2].data.fd = 2;

  if (opts & (kShellOptHideMess | kShellOptExpand)) {
    // Ignore the shell stdio(redirects to /dev/null on unixes)
    proc_stdio[0].flags = UV_IGNORE;
    proc_stdio[1].flags = UV_IGNORE;
    proc_stdio[2].flags = UV_IGNORE;
  } else {
    State = EXTERNCMD;

    if (opts & kShellOptWrite) {
      // Write from the current buffer into the process stdin
      uv_pipe_init(uv_default_loop(), &proc_stdin, 0);
      write_req.data = &pdata;
      proc_stdio[0].flags = UV_CREATE_PIPE | UV_READABLE_PIPE;
      proc_stdio[0].data.stream = (uv_stream_t *)&proc_stdin;
    }

    if (opts & kShellOptRead) {
      // Read from the process stdout into the current buffer
      uv_pipe_init(uv_default_loop(), &proc_stdout, 0);
      proc_stdout.data = &pdata;
      proc_stdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
      proc_stdio[1].data.stream = (uv_stream_t *)&proc_stdout;
      ga_init(&pdata.ga, 1, BUFFER_LENGTH);
    }
  }

  if (uv_spawn(uv_default_loop(), &proc, &proc_opts)) {
    // Failed, probably due to `sh` not being executable
    if (!emsg_silent) {
      MSG_PUTS(_("\nCannot execute shell "));
      msg_outtrans(p_sh);
      msg_putchar('\n');
    }

    return proc_cleanup_exit(&pdata, &proc_opts, opts);
  }

  // Assign the flag address after `proc` is initialized by `uv_spawn`
  proc.data = &pdata;

  if (opts & kShellOptWrite) {
    // Queue everything for writing to the shell stdin
    write_selection(&write_req);
    expected_exits++;
  }

  if (opts & kShellOptRead) {
    // Start the read stream for the shell stdout
    uv_read_start((uv_stream_t *)&proc_stdout, alloc_cb, read_cb);
    expected_exits++;
  }

  // Keep running the loop until all three handles are completely closed
  while (pdata.exited < expected_exits) {
    uv_run(uv_default_loop(), UV_RUN_ONCE);

    if (got_int) {
      // Forward SIGINT to the shell
      // TODO(tarruda): for now this is only needed if the terminal is in raw
      // mode, but when the UI is externalized we'll also need it, so leave it
      // here
      uv_process_kill(&proc, SIGINT);
      got_int = false;
    }
  }

  if (opts & kShellOptRead) {
    if (!GA_EMPTY(&pdata.ga)) {
      // If there's an unfinished line in the growable array, append it now.
      append_ga_line(&pdata.ga);
      // remember that the NL was missing
      curbuf->b_no_eol_lnum = curwin->w_cursor.lnum;
    } else {
      curbuf->b_no_eol_lnum = 0;
    }
    ga_clear(&pdata.ga);
  }

  if (opts & kShellOptWrite) {
    free(pdata.wbuffer);
  }

  return proc_cleanup_exit(&pdata, &proc_opts, opts);
}

/// Parses a command string into a sequence of words, taking quotes into
/// consideration.
///
/// @param str The command string to be parsed
/// @param argv The vector that will be filled with copies of the parsed
///        words. It can be NULL if the caller only needs to count words.
/// @return The number of words parsed.
static int tokenize(char_u *str, char **argv)
{
  int argc = 0, len;
  char_u *p = str;

  while (*p != NUL) {
    len = word_length(p);

    if (argv != NULL) {
      // Fill the slot
      argv[argc] = xmalloc(len + 1);
      memcpy(argv[argc], p, len);
      argv[argc][len] = NUL;
    }

    argc++;
    p += len;
    p = skipwhite(p);
  }

  return argc;
}

/// Calculates the length of a shell word.
///
/// @param str A pointer to the first character of the word
/// @return The offset from `str` at which the word ends.
static int word_length(char_u *str)
{
  char_u *p = str;
  bool inquote = false;
  int length = 0;

  // Move `p` to the end of shell word by advancing the pointer while it's
  // inside a quote or it's a non-whitespace character
  while (*p && (inquote || (*p != ' ' && *p != TAB))) {
    if (*p == '"') {
      // Found a quote character, switch the `inquote` flag
      inquote = !inquote;
    }

    p++;
    length++;
  }

  return length;
}

/// To remain compatible with the old implementation(which forked a process
/// for writing) the entire text is copied to a temporary buffer before the
/// event loop starts. If we don't(by writing in chunks returned by `ml_get`)
/// the buffer being modified might get modified by reading from the process
/// before we finish writing.
/// Queues selected range for writing to the child process stdin.
///
/// @param req The structure containing information to peform the write
static void write_selection(uv_write_t *req)
{
  ProcessData *pdata = (ProcessData *)req->data;
  // TODO(tarruda): use a static buffer for up to a limit(BUFFER_LENGTH) and
  // only after filled we should start allocating memory(skip unnecessary
  // allocations for small writes)
  int buflen = BUFFER_LENGTH;
  pdata->wbuffer = (char *)xmalloc(buflen);
  uv_buf_t uvbuf;
  linenr_T lnum = curbuf->b_op_start.lnum;
  int off = 0;
  int written = 0;
  char_u      *lp = ml_get(lnum);
  int l;
  int len;

  for (;;) {
    l = strlen((char *)lp + written);
    if (l == 0) {
      len = 0;
    } else if (lp[written] == NL) {
      // NL -> NUL translation
      len = 1;
      if (off + len >= buflen) {
        // Resize the buffer
        buflen *= 2;
        pdata->wbuffer = xrealloc(pdata->wbuffer, buflen);
      }
      pdata->wbuffer[off++] = NUL;
    } else {
      char_u  *s = vim_strchr(lp + written, NL);
      len = s == NULL ? l : s - (lp + written);
      while (off + len >= buflen) {
        // Resize the buffer
        buflen *= 2;
        pdata->wbuffer = xrealloc(pdata->wbuffer, buflen);
      }
      memcpy(pdata->wbuffer + off, lp + written, len);
      off += len;
    }
    if (len == l) {
      // Finished a line, add a NL, unless this line
      // should not have one.
      // FIXME need to make this more readable
      if (lnum != curbuf->b_op_end.lnum
          || !curbuf->b_p_bin
          || (lnum != curbuf->b_no_eol_lnum
            && (lnum !=
              curbuf->b_ml.ml_line_count
              || curbuf->b_p_eol))) {
        if (off + 1 >= buflen) {
          // Resize the buffer
          buflen *= 2;
          pdata->wbuffer = xrealloc(pdata->wbuffer, buflen);
        }
        pdata->wbuffer[off++] = NL;
      }
      ++lnum;
      if (lnum > curbuf->b_op_end.lnum) {
        break;
      }
      lp = ml_get(lnum);
      written = 0;
    } else if (len > 0) {
      written += len;
    }
  }

  uvbuf.base = pdata->wbuffer;
  uvbuf.len = off;

  uv_write(req, pdata->shell_stdin, &uvbuf, 1, write_cb);
}

// "Allocates" a buffer for reading from the shell stdout.
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  ProcessData *pdata = (ProcessData *)handle->data;

  if (pdata->reading) {
    buf->len = 0;
    return;
  }

  buf->base = pdata->rbuffer;
  buf->len = BUFFER_LENGTH;
  // Avoid `alloc_cb`, `alloc_cb` sequences on windows
  pdata->reading = true;
}

static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf)
{
  // TODO(tarruda): avoid using a growable array for this, refactor the
  // algorithm to call `ml_append` directly(skip unnecessary copies/resizes)
  int i;
  ProcessData *pdata = (ProcessData *)stream->data;

  if (cnt <= 0) {
    if (cnt != UV_ENOBUFS) {
      uv_read_stop(stream);
      uv_close((uv_handle_t *)stream, NULL);
      pdata->exited++;
    }
    return;
  }

  for (i = 0; i < cnt; ++i) {
    if (pdata->rbuffer[i] == NL) {
      // Insert the line
      append_ga_line(&pdata->ga);
    } else if (pdata->rbuffer[i] == NUL) {
      // Translate NUL to NL
      ga_append(&pdata->ga, NL);
    } else {
      // buffer data into the grow array
      ga_append(&pdata->ga, pdata->rbuffer[i]);
    }
  }

  windgoto(msg_row, msg_col);
  cursor_on();
  out_flush();

  pdata->reading = false;
}

static void write_cb(uv_write_t *req, int status)
{
  ProcessData *pdata = (ProcessData *)req->data;
  uv_close((uv_handle_t *)pdata->shell_stdin, NULL);
  pdata->exited++;
}

/// Cleanup memory and restore state modified by `os_call_shell`.
///
/// @param data State shared by all functions collaborating with
///        `os_call_shell`.
/// @param opts Process spawning options, containing some allocated memory
/// @param shellopts Options passed to `os_call_shell`. Used for deciding
///        if/which messages are displayed.
static int proc_cleanup_exit(ProcessData *proc_data,
                             uv_process_options_t *proc_opts,
                             int shellopts)
{
  if (proc_data->exited) {
    if (!emsg_silent && proc_data->exit_status != 0 &&
        !(shellopts & kShellOptSilent)) {
      MSG_PUTS(_("\nshell returned "));
      msg_outnum((int64_t)proc_data->exit_status);
      msg_putchar('\n');
    }
  }

  State = proc_data->old_state;

  if (proc_data->old_mode == TMODE_RAW) {
    // restore mode
    settmode(TMODE_RAW);
  }

  signal_accept_deadly();

  // Release argv memory
  shell_free_argv(proc_opts->args);

  return proc_data->exit_status;
}

static void exit_cb(uv_process_t *proc, int64_t status, int term_signal)
{
  ProcessData *data = (ProcessData *)proc->data;
  data->exited++;
  data->exit_status = status;
  uv_close((uv_handle_t *)proc, NULL);
}
