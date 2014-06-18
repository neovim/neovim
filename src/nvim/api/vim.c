#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/vim.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/buffer.h"
#include "nvim/os/channel.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/window.h"
#include "nvim/types.h"
#include "nvim/ascii.h"
#include "nvim/ex_docmd.h"
#include "nvim/screen.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/eval.h"
#include "nvim/misc2.h"

#define LINE_BUFFER_SIZE 4096

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.c.generated.h"
#endif

/// Send keys to vim input buffer, simulating user input.
///
/// @param str The keys to send
void vim_push_keys(String str)
{
  abort();
}

/// Executes an ex-mode command str
///
/// @param str The command str
/// @param[out] err Details of an error that may have occurred
void vim_command(String str, Error *err)
{
  // Run the command
  try_start();
  do_cmdline_cmd((char_u *) str.data);
  update_screen(VALID);
  try_end(err);
}

/// Evaluates the expression str using the vim internal expression
/// evaluator (see |expression|).
/// Dictionaries and lists are recursively expanded.
///
/// @param str The expression str
/// @param[out] err Details of an error that may have occurred
/// @return The expanded object
Object vim_eval(String str, Error *err)
{
  Object rv;
  // Evaluate the expression
  try_start();
  typval_T *expr_result = eval_expr((char_u *) str.data, NULL);

  if (!expr_result) {
    set_api_error("Failed to eval expression", err);
  }

  if (!try_end(err)) {
    // No errors, convert the result
    rv = vim_to_object(expr_result);
  }

  // Free the vim object
  free_tv(expr_result);
  return rv;
}

/// Calculates the number of display cells `str` occupies, tab is counted as
/// one cell.
///
/// @param str Some text
/// @param[out] err Details of an error that may have occurred
/// @return The number of cells
Integer vim_strwidth(String str, Error *err)
{
  if (str.size > INT_MAX) {
    set_api_error("String length is too high", err);
    return 0;
  }

  return (Integer) mb_string2cells((char_u *) str.data);
}

/// Returns a list of paths contained in 'runtimepath'
///
/// @return The list of paths
StringArray vim_list_runtime_paths(void)
{
  StringArray rv = ARRAY_DICT_INIT;
  uint8_t *rtp = p_rtp;

  if (*rtp == NUL) {
    // No paths
    return rv;
  }

  // Count the number of paths in rtp
  while (*rtp != NUL) {
    if (*rtp == ',') {
      rv.size++;
    }
    rtp++;
  }

  // Allocate memory for the copies
  rv.items = xmalloc(sizeof(String) * rv.size);
  // reset the position
  rtp = p_rtp;
  // Start copying
  for (size_t i = 0; i < rv.size && *rtp != NUL; i++) {
    rv.items[i].data = xmalloc(MAXPATHL);
    // Copy the path from 'runtimepath' to rv.items[i]
    int length = copy_option_part(&rtp,
                                 (char_u *)rv.items[i].data,
                                 MAXPATHL,
                                 ",");
    assert(length >= 0);
    rv.items[i].size = (size_t)length;
  }

  return rv;
}

/// Changes vim working directory
///
/// @param dir The new working directory
/// @param[out] err Details of an error that may have occurred
void vim_change_directory(String dir, Error *err)
{
  if (dir.size >= MAXPATHL) {
    set_api_error("directory string is too long", err);
    return;
  }

  char string[MAXPATHL];
  strncpy(string, dir.data, dir.size);
  string[dir.size] = NUL;

  try_start();

  if (vim_chdir((char_u *)string)) {
    if (!try_end(err)) {
      set_api_error("failed to change directory", err);
    }
    return;
  }

  post_chdir(false);
  try_end(err);
}

/// Return the current line
///
/// @param[out] err Details of an error that may have occurred
/// @return The current line string
String vim_get_current_line(Error *err)
{
  return buffer_get_line(curbuf->handle, curwin->w_cursor.lnum - 1, err);
}

/// Sets the current line
///
/// @param line The line contents
/// @param[out] err Details of an error that may have occurred
void vim_set_current_line(String line, Error *err)
{
  buffer_set_line(curbuf->handle, curwin->w_cursor.lnum - 1, line, err);
}

/// Delete the current line
///
/// @param[out] err Details of an error that may have occurred
void vim_del_current_line(Error *err)
{
  buffer_del_line(curbuf->handle, curwin->w_cursor.lnum - 1, err);
}

/// Gets a global variable
///
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object vim_get_var(String name, Error *err)
{
  return dict_get_value(&globvardict, name, err);
}

/// Sets a global variable. Passing 'nil' as value deletes the variable.
///
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return the old value if any
Object vim_set_var(String name, Object value, Error *err)
{
  return dict_set_value(&globvardict, name, value, err);
}

/// Gets a vim variable
///
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object vim_get_vvar(String name, Error *err)
{
  return dict_get_value(&vimvardict, name, err);
}

/// Get an option value string
///
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return The option value
Object vim_get_option(String name, Error *err)
{
  return get_option_from(NULL, SREQ_GLOBAL, name, err);
}

/// Sets an option value
///
/// @param name The option name
/// @param value The new option value
/// @param[out] err Details of an error that may have occurred
void vim_set_option(String name, Object value, Error *err)
{
  set_option_to(NULL, SREQ_GLOBAL, name, value, err);
}

/// Write a message to vim output buffer
///
/// @param str The message
void vim_out_write(String str)
{
  write_msg(str, false);
}

/// Write a message to vim error buffer
///
/// @param str The message
void vim_err_write(String str)
{
  write_msg(str, true);
}

/// Gets the current list of buffer handles
///
/// @return The number of buffers
BufferArray vim_get_buffers(void)
{
  BufferArray rv = ARRAY_DICT_INIT;
  buf_T *b = firstbuf;

  while (b) {
    rv.size++;
    b = b->b_next;
  }

  rv.items = xmalloc(sizeof(Buffer) * rv.size);
  size_t i = 0;
  b = firstbuf;

  while (b) {
    rv.items[i++] = b->handle;
    b = b->b_next;
  }

  return rv;
}

/// Return the current buffer
///
/// @reqturn The buffer handle
Buffer vim_get_current_buffer(void)
{
  return curbuf->handle;
}

/// Sets the current buffer
///
/// @param id The buffer handle
/// @param[out] err Details of an error that may have occurred
void vim_set_current_buffer(Buffer buffer, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  try_start();
  if (do_buffer(DOBUF_GOTO, DOBUF_FIRST, FORWARD, buf->b_fnum, 0) == FAIL) {
    if (try_end(err)) {
      return;
    }

    char msg[256];
    snprintf(msg, sizeof(msg), "failed to switch to buffer %d", (int)buffer);
    set_api_error(msg, err);
    return;
  }

  try_end(err);
}

/// Gets the current list of window handles
///
/// @return The number of windows
WindowArray vim_get_windows(void)
{
  WindowArray rv = ARRAY_DICT_INIT;
  tabpage_T *tp;
  win_T *wp;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    rv.size++;
  }

  rv.items = xmalloc(sizeof(Window) * rv.size);
  size_t i = 0;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    rv.items[i++] = wp->handle;
  }

  return rv;
}

/// Return the current window
///
/// @return The window handle
Window vim_get_current_window(void)
{
  return curwin->handle;
}

/// Sets the current window
///
/// @param handle The window handle
void vim_set_current_window(Window window, Error *err)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  try_start();
  goto_tabpage_win(win_find_tabpage(win), win);

  if (win != curwin) {
    if (try_end(err)) {
      return;
    }
    set_api_error("did not switch to the specified window", err);
    return;
  }

  try_end(err);
}

/// Gets the current list of tabpage handles
///
/// @return The number of tab pages
TabpageArray vim_get_tabpages(void)
{
  TabpageArray rv = ARRAY_DICT_INIT;
  tabpage_T *tp = first_tabpage;

  while (tp) {
    rv.size++;
    tp = tp->tp_next;
  }

  rv.items = xmalloc(sizeof(Tabpage) * rv.size);
  size_t i = 0;
  tp = first_tabpage;

  while (tp) {
    rv.items[i++] = tp->handle;
    tp = tp->tp_next;
  }

  return rv;
}

/// Return the current tab page
///
/// @return The tab page handle
Tabpage vim_get_current_tabpage(void)
{
  return curtab->handle;
}

/// Sets the current tab page
///
/// @param handle The tab page handle
/// @param[out] err Details of an error that may have occurred
void vim_set_current_tabpage(Tabpage tabpage, Error *err)
{
  tabpage_T *tp = find_tab_by_handle(tabpage, err);

  if (!tp) {
    return;
  }

  try_start();
  goto_tabpage_tp(tp, true, true);
  try_end(err);
}

/// Subscribes to event broadcasts
///
/// @param channel_id The channel id(passed automatically by the dispatcher)
/// @param event The event type string
void vim_subscribe(uint64_t channel_id, String event)
{
  size_t length = (event.size < EVENT_MAXLEN ? event.size : EVENT_MAXLEN);
  char e[EVENT_MAXLEN + 1];
  memcpy(e, event.data, length);
  e[length] = NUL;
  channel_subscribe(channel_id, e);
}

/// Unsubscribes to event broadcasts
///
/// @param channel_id The channel id(passed automatically by the dispatcher)
/// @param event The event type string
void vim_unsubscribe(uint64_t channel_id, String event)
{
  size_t length = (event.size < EVENT_MAXLEN ? event.size : EVENT_MAXLEN);
  char e[EVENT_MAXLEN + 1];
  memcpy(e, event.data, length);
  e[length] = NUL;
  channel_unsubscribe(channel_id, e);
}

/// Writes a message to vim output or error buffer. The string is split
/// and flushed after each newline. Incomplete lines are kept for writing
/// later.
///
/// @param message The message to write
/// @param to_err True if it should be treated as an error message(use
///        `emsg` instead of `msg` to print each line)
static void write_msg(String message, bool to_err)
{
  static int pos = 0;
  static char line_buf[LINE_BUFFER_SIZE];

  for (uint32_t i = 0; i < message.size; i++) {
    if (message.data[i] == NL || pos == LINE_BUFFER_SIZE - 1) {
      // Flush line
      line_buf[pos] = NUL;
      if (to_err) {
        emsg((uint8_t *)line_buf);
      } else {
        msg((uint8_t *)line_buf);
      }

      pos = 0;
      continue;
    }

    line_buf[pos++] = message.data[i];
  }
}
