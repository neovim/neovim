#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/ascii.h"
#include "nvim/lib/kvec.h"
#include "nvim/log.h"
#include "nvim/os/event.h"
#include "nvim/os/job.h"
#include "nvim/os/rstream.h"
#include "nvim/os/shell.h"
#include "nvim/os/signal.h"
#include "nvim/types.h"
#include "nvim/vim.h"
#include "nvim/message.h"
#include "nvim/memory.h"
#include "nvim/ui.h"
#include "nvim/misc2.h"
#include "nvim/screen.h"
#include "nvim/memline.h"
#include "nvim/option_defs.h"
#include "nvim/charset.h"
#include "nvim/strings.h"

#define DYNAMIC_BUFFER_INIT {NULL, 0, 0}

typedef struct {
  char *data;
  size_t cap, len;
} DynamicBuffer;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/shell.c.generated.h"
#endif


/// Builds the argument vector for running the user-configured 'shell' (p_sh)
/// with an optional command prefixed by 'shellcmdflag' (p_shcf).
///
/// @param cmd Command string, or NULL to run an interactive shell.
/// @param extra_args Extra arguments to the shell, or NULL.
/// @return A newly allocated argument vector. It must be freed with
///         `shell_free_argv` when no longer needed.
char **shell_build_argv(const char *cmd, const char *extra_args)
{
  size_t argc = tokenize(p_sh, NULL) + tokenize(p_shcf, NULL);
  char **rv = xmalloc((unsigned)((argc + 4) * sizeof(char *)));

  // Split 'shell'
  size_t i = tokenize(p_sh, rv);

  if (extra_args) {
    rv[i++] = xstrdup(extra_args);   // Push a copy of `extra_args`
  }

  if (cmd) {
    i += tokenize(p_shcf, rv + i);   // Split 'shellcmdflag'
    rv[i++] = xstrdup(cmd);          // Push a copy of the command.
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

/// Calls the user-configured 'shell' (p_sh) for running a command or wildcard
/// expansion.
///
/// @param cmd The command to execute, or NULL to run an interactive shell.
/// @param opts Options that control how the shell will work.
/// @param extra_args Extra arguments to the shell, or NULL.
int os_call_shell(char_u *cmd, ShellOpts opts, char_u *extra_args)
{
  DynamicBuffer input = DYNAMIC_BUFFER_INIT;
  char *output = NULL, **output_ptr = NULL;
  int current_state = State;
  bool forward_output = true;
  ui_flush();

  // While the child is running, ignore terminating signals
  signal_reject_deadly();

  if (opts & (kShellOptHideMess | kShellOptExpand)) {
    forward_output = false;
  } else {
    State = EXTERNCMD;

    if (opts & kShellOptWrite) {
      read_input(&input);
    }

    if (opts & kShellOptRead) {
      output_ptr = &output;
      forward_output = false;
    }
  }

  size_t nread;
  int status = shell((const char *)cmd,
                     (const char *)extra_args,
                     input.data,
                     input.len,
                     output_ptr,
                     &nread,
                     emsg_silent,
                     forward_output);

  free(input.data);

  if (output) {
    (void)write_output(output, nread, true, true);
    free(output);
  }

  if (!emsg_silent && status != 0 && !(opts & kShellOptSilent)) {
    MSG_PUTS(_("\nshell returned "));
    msg_outnum(status);
    msg_putchar('\n');
  }

  State = current_state;
  signal_accept_deadly();

  return status;
}

/// os_system - synchronously execute a command in the shell
///
/// example:
///   char *output = NULL;
///   size_t nread = 0;
///   int status = os_sytem("ls -la", NULL, 0, &output, &nread);
///
/// @param cmd The full commandline to be passed to the shell
/// @param input The input to the shell (NULL for no input), passed to the
///              stdin of the resulting process.
/// @param len The length of the input buffer (not used if `input` == NULL)
/// @param[out] output A pointer to to a location where the output will be
///                    allocated and stored. Will point to NULL if the shell
///                    command did not output anything. If NULL is passed,
///                    the shell output will be ignored.
/// @param[out] nread the number of bytes in the returned buffer (if the
///             returned buffer is not NULL)
/// @return the return code of the process, -1 if the process couldn't be
///         started properly
int os_system(const char *cmd,
              const char *input,
              size_t len,
              char **output,
              size_t *nread) FUNC_ATTR_NONNULL_ARG(1)
{
  return shell(cmd, NULL, input, len, output, nread, true, false);
}

static int shell(const char *cmd,
                 const char *extra_args,
                 const char *input,
                 size_t len,
                 char **output,
                 size_t *nread,
                 bool silent,
                 bool forward_output)
{
  // the output buffer
  DynamicBuffer buf = DYNAMIC_BUFFER_INIT;
  rstream_cb data_cb = system_data_cb;
  if (nread) {
    *nread = 0;
  }

  if (forward_output) {
    data_cb = out_data_cb;
  } else if (!output) {
    data_cb = NULL;
  }

  char **argv = shell_build_argv(cmd, extra_args);

  int status;
  JobOptions opts = JOB_OPTIONS_INIT;
  opts.argv = argv;
  opts.data = &buf;
  opts.writable = input != NULL;
  opts.stdout_cb = data_cb;
  opts.stderr_cb = data_cb;
  opts.exit_cb = NULL;
  Job *job = job_start(opts, &status);

  if (status <= 0) {
    // Failed, probably due to `sh` not being executable
    ELOG("Couldn't start job, command: '%s', error code: '%d'",
        (cmd ? cmd : (char *)p_sh), status);
    if (!silent) {
      MSG_PUTS(_("\nCannot execute shell "));
      msg_outtrans(p_sh);
      msg_putchar('\n');
    }
    return -1;
  }

  // write the input, if any
  if (input) {
    WBuffer *input_buffer = wstream_new_buffer((char *) input, len, 1, NULL);

    if (!job_write(job, input_buffer)) {
      // couldn't write, stop the job and tell the user about it
      job_stop(job);
      return -1;
    }
    // close the input stream after everything is written
    job_write_cb(job, shell_write_cb);
  } else {
    // close the input stream, let the process know that no more input is
    // coming
    job_close_in(job);
  }

  status = job_wait(job, -1);

  // prepare the out parameters if requested
  if (output) {
    if (buf.len == 0) {
      // no data received from the process, return NULL
      *output = NULL;
      free(buf.data);
    } else {
      // NUL-terminate to make the output directly usable as a C string
      buf.data[buf.len] = NUL;
      *output = buf.data;
    }

    if (nread) {
      *nread = buf.len;
    }
  }

  return status;
}

///  - ensures at least `desired` bytes in buffer
///
/// TODO(aktau): fold with kvec/garray
static void dynamic_buffer_ensure(DynamicBuffer *buf, size_t desired)
{
  if (buf->cap >= desired) {
    assert(buf->data);
    return;
  }

  buf->cap = desired;
  kv_roundup32(buf->cap);
  buf->data = xrealloc(buf->data, buf->cap);
}

static void system_data_cb(RStream *rstream, void *data, bool eof)
{
  Job *job = data;
  DynamicBuffer *buf = job_data(job);

  size_t nread = rstream_pending(rstream);

  dynamic_buffer_ensure(buf, buf->len + nread + 1);
  rstream_read(rstream, buf->data + buf->len, nread);

  buf->len += nread;
}

static void out_data_cb(RStream *rstream, void *data, bool eof)
{
  RBuffer *rbuffer = rstream_buffer(rstream);
  size_t written = write_output(rbuffer_read_ptr(rbuffer),
                                rbuffer_pending(rbuffer), false, eof);
  rbuffer_consumed(rbuffer, written);
}

/// Parses a command string into a sequence of words, taking quotes into
/// consideration.
///
/// @param str The command string to be parsed
/// @param argv The vector that will be filled with copies of the parsed
///        words. It can be NULL if the caller only needs to count words.
/// @return The number of words parsed.
static size_t tokenize(const char_u *str, char **argv)
{
  size_t argc = 0, len;
  char_u *p = (char_u *) str;

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
static size_t word_length(const char_u *str)
{
  const char_u *p = str;
  bool inquote = false;
  size_t length = 0;

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

/// To remain compatible with the old implementation (which forked a process
/// for writing) the entire text is copied to a temporary buffer before the
/// event loop starts. If we don't (by writing in chunks returned by `ml_get`)
/// the buffer being modified might get modified by reading from the process
/// before we finish writing.
static void read_input(DynamicBuffer *buf)
{
  size_t written = 0, l = 0, len = 0;
  linenr_T lnum = curbuf->b_op_start.lnum;
  char_u *lp = ml_get(lnum);

  for (;;) {
    l = strlen((char *)lp + written);
    if (l == 0) {
      len = 0;
    } else if (lp[written] == NL) {
      // NL -> NUL translation
      len = 1;
      dynamic_buffer_ensure(buf, buf->len + len);
      buf->data[buf->len++] = NUL;
    } else {
      char_u  *s = vim_strchr(lp + written, NL);
      len = s == NULL ? l : (size_t)(s - (lp + written));
      dynamic_buffer_ensure(buf, buf->len + len);
      memcpy(buf->data + buf->len, lp + written, len);
      buf->len += len;
    }

    if (len == l) {
      // Finished a line, add a NL, unless this line should not have one.
      // FIXME need to make this more readable
      if (lnum != curbuf->b_op_end.lnum
          || !curbuf->b_p_bin
          || (lnum != curbuf->b_no_eol_lnum
            && (lnum !=
              curbuf->b_ml.ml_line_count
              || curbuf->b_p_eol))) {
        dynamic_buffer_ensure(buf, buf->len + 1);
        buf->data[buf->len++] = NL;
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
}

static size_t write_output(char *output, size_t remaining, bool to_buffer,
                           bool eof)
{
  if (!output) {
    return 0;
  }

  char *start = output;
  size_t off = 0;
  int lastrow = (int)Rows - 1;
  while (off < remaining) {
    if (output[off] == NL) {
      // Insert the line
      output[off] = NUL;
      if (to_buffer) {
        ml_append(curwin->w_cursor.lnum++, (char_u *)output, 0, false);
      } else {
        screen_del_lines(0, 0, 1, (int)Rows, NULL);
        screen_puts_len((char_u *)output, (int)off, lastrow, 0, 0);
      }
      size_t skip = off + 1;
      output += skip;
      remaining -= skip;
      off = 0;
      continue;
    }

    if (output[off] == NUL) {
      // Translate NUL to NL
      output[off] = NL;
    }
    off++;
  }

  if (eof) {
    if (remaining) {
      if (to_buffer) {
        // append unfinished line
        ml_append(curwin->w_cursor.lnum++, (char_u *)output, 0, false);
        // remember that the NL was missing
        curbuf->b_no_eol_lnum = curwin->w_cursor.lnum;
      } else {
        screen_del_lines(0, 0, 1, (int)Rows, NULL);
        screen_puts_len((char_u *)output, (int)remaining, lastrow, 0, 0);
      }
      output += remaining;
    } else if (to_buffer) {
      curbuf->b_no_eol_lnum = 0;
    }
  }

  ui_flush();

  return (size_t)(output - start);
}

static void shell_write_cb(WStream *wstream, void *data, int status)
{
  Job *job = data;
  job_close_in(job);
}
