#include <assert.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/vim.h"
#include "nvim/ascii.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/buffer.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/os/provider.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/window.h"
#include "nvim/types.h"
#include "nvim/ex_docmd.h"
#include "nvim/screen.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/eval.h"
#include "nvim/misc2.h"
#include "nvim/term.h"
#include "nvim/getchar.h"

#define LINE_BUFFER_SIZE 4096

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.c.generated.h"
#endif

/// Executes an ex-mode command str
///
/// @param str The command str
/// @param[out] err Details of an error that may have occurred
void vim_command(String str, Error *err)
  FUNC_ATTR_DEFERRED
{
  // Run the command
  try_start();
  do_cmdline_cmd((char_u *) str.data);
  update_screen(VALID);
  try_end(err);
}

/// Pass input keys to Neovim
///
/// @param keys to be typed
/// @param mode specifies the mapping options
/// @see feedkeys()
void vim_feedkeys(String keys, String mode)
{
  bool remap = true;
  bool typed = false;

  if (keys.size == 0) {
    return;
  }

  for (size_t i = 0; i < mode.size; ++i) {
    switch (mode.data[i]) {
    case 'n': remap = false; break;
    case 'm': remap = true; break;
    case 't': typed = true; break;
    }
  }

  /* Need to escape K_SPECIAL and CSI before putting the string in the
   * typeahead buffer. */
  char *keys_esc = (char *)vim_strsave_escape_csi((char_u *)keys.data);
  ins_typebuf((char_u *)keys_esc, (remap ? REMAP_YES : REMAP_NONE),
      typebuf.tb_len, !typed, false);
  free(keys_esc);

  if (vgetc_busy)
    typebuf_was_filled = true;
}

/// Replace any terminal codes with the internal representation
///
/// @see replace_termcodes
/// @see cpoptions
String vim_replace_termcodes(String str, Boolean from_part, Boolean do_lt,
                              Boolean special)
{
  if (str.size == 0) {
    // Empty string
    return str;
  }

  char *ptr = NULL;
  replace_termcodes((char_u *)str.data, (char_u **)&ptr,
                                            from_part, do_lt, special);
  return cstr_as_string(ptr);
}

String vim_command_output(String str, Error *err)
{
  do_cmdline_cmd((char_u *)"redir => v:command_output");
  vim_command(str, err);
  do_cmdline_cmd((char_u *)"redir END");

  if (err->set) {
    return (String) STRING_INIT;
  }

  return cstr_to_string((char *)get_vim_var_str(VV_COMMAND_OUTPUT));
}

/// Evaluates the expression str using the vim internal expression
/// evaluator (see |expression|).
/// Dictionaries and lists are recursively expanded.
///
/// @param str The expression str
/// @param[out] err Details of an error that may have occurred
/// @return The expanded object
Object vim_eval(String str, Error *err)
  FUNC_ATTR_DEFERRED
{
  Object rv;
  // Evaluate the expression
  try_start();
  typval_T *expr_result = eval_expr((char_u *) str.data, NULL);

  if (!expr_result) {
    api_set_error(err, Exception, _("Failed to evaluate expression"));
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
    api_set_error(err, Validation, _("String length is too high"));
    return 0;
  }

  return (Integer) mb_string2cells((char_u *) str.data);
}

/// Returns a list of paths contained in 'runtimepath'
///
/// @return The list of paths
ArrayOf(String) vim_list_runtime_paths(void)
{
  Array rv = ARRAY_DICT_INIT;
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
  rv.items = xmalloc(sizeof(Object) * rv.size);
  // reset the position
  rtp = p_rtp;
  // Start copying
  for (size_t i = 0; i < rv.size && *rtp != NUL; i++) {
    rv.items[i].type = kObjectTypeString;
    rv.items[i].data.string.data = xmalloc(MAXPATHL);
    // Copy the path from 'runtimepath' to rv.items[i]
    int length = copy_option_part(&rtp,
                                 (char_u *)rv.items[i].data.string.data,
                                 MAXPATHL,
                                 ",");
    assert(length >= 0);
    rv.items[i].data.string.size = (size_t)length;
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
    api_set_error(err, Validation, _("Directory string is too long"));
    return;
  }

  char string[MAXPATHL];
  strncpy(string, dir.data, dir.size);
  string[dir.size] = NUL;

  try_start();

  if (vim_chdir((char_u *)string)) {
    if (!try_end(err)) {
      api_set_error(err, Exception, _("Failed to change directory"));
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
  FUNC_ATTR_DEFERRED
{
  buffer_set_line(curbuf->handle, curwin->w_cursor.lnum - 1, line, err);
}

/// Delete the current line
///
/// @param[out] err Details of an error that may have occurred
void vim_del_current_line(Error *err)
  FUNC_ATTR_DEFERRED
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
  FUNC_ATTR_DEFERRED
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
  FUNC_ATTR_DEFERRED
{
  set_option_to(NULL, SREQ_GLOBAL, name, value, err);
}

/// Write a message to vim output buffer
///
/// @param str The message
void vim_out_write(String str)
  FUNC_ATTR_DEFERRED
{
  write_msg(str, false);
}

/// Write a message to vim error buffer
///
/// @param str The message
void vim_err_write(String str)
  FUNC_ATTR_DEFERRED
{
  write_msg(str, true);
}

/// Higher level error reporting function that ensures all str contents
/// are written by sending a trailing linefeed to `vim_wrr_write`
///
/// @param str The message
void vim_report_error(String str)
  FUNC_ATTR_DEFERRED
{
  vim_err_write(str);
  vim_err_write((String) {.data = "\n", .size = 1});
}

/// Gets the current list of buffer handles
///
/// @return The number of buffers
ArrayOf(Buffer) vim_get_buffers(void)
{
  Array rv = ARRAY_DICT_INIT;
  buf_T *b = firstbuf;

  while (b) {
    rv.size++;
    b = b->b_next;
  }

  rv.items = xmalloc(sizeof(Object) * rv.size);
  size_t i = 0;
  b = firstbuf;

  while (b) {
    rv.items[i++] = BUFFER_OBJ(b->handle);
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
  FUNC_ATTR_DEFERRED
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  try_start();
  int result = do_buffer(DOBUF_GOTO, DOBUF_FIRST, FORWARD, buf->b_fnum, 0);
  if (!try_end(err) && result == FAIL) {
    api_set_error(err,
                  Exception,
                  _("Failed to switch to buffer %" PRIu64),
                  buffer);
  }
}

/// Gets the current list of window handles
///
/// @return The number of windows
ArrayOf(Window) vim_get_windows(void)
{
  Array rv = ARRAY_DICT_INIT;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    rv.size++;
  }

  rv.items = xmalloc(sizeof(Object) * rv.size);
  size_t i = 0;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    rv.items[i++] = WINDOW_OBJ(wp->handle);
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
  FUNC_ATTR_DEFERRED
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  try_start();
  goto_tabpage_win(win_find_tabpage(win), win);
  if (!try_end(err) && win != curwin) {
    api_set_error(err,
                  Exception,
                  _("Failed to switch to window %" PRIu64),
                  window);
  }
}

/// Gets the current list of tabpage handles
///
/// @return The number of tab pages
ArrayOf(Tabpage) vim_get_tabpages(void)
{
  Array rv = ARRAY_DICT_INIT;
  tabpage_T *tp = first_tabpage;

  while (tp) {
    rv.size++;
    tp = tp->tp_next;
  }

  rv.items = xmalloc(sizeof(Object) * rv.size);
  size_t i = 0;
  tp = first_tabpage;

  while (tp) {
    rv.items[i++] = TABPAGE_OBJ(tp->handle);
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
  FUNC_ATTR_DEFERRED
{
  tabpage_T *tp = find_tab_by_handle(tabpage, err);

  if (!tp) {
    return;
  }

  try_start();
  goto_tabpage_tp(tp, true, true);
  if (!try_end(err) && tp != curtab) {
    api_set_error(err,
                  Exception,
                  _("Failed to switch to tabpage %" PRIu64),
                  tabpage);
  }
}

/// Subscribes to event broadcasts
///
/// @param channel_id The channel id(passed automatically by the dispatcher)
/// @param event The event type string
void vim_subscribe(uint64_t channel_id, String event)
{
  size_t length = (event.size < METHOD_MAXLEN ? event.size : METHOD_MAXLEN);
  char e[METHOD_MAXLEN + 1];
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
  size_t length = (event.size < METHOD_MAXLEN ?
                   event.size :
                   METHOD_MAXLEN);
  char e[METHOD_MAXLEN + 1];
  memcpy(e, event.data, length);
  e[length] = NUL;
  channel_unsubscribe(channel_id, e);
}

/// Registers the channel as the provider for `feature`. This fails if
/// a provider for `feature` is already provided by another channel.
///
/// @param channel_id The channel id
/// @param feature The feature name
/// @param[out] err Details of an error that may have occurred
void vim_register_provider(uint64_t channel_id, String feature, Error *err)
{
  char buf[METHOD_MAXLEN];
  xstrlcpy(buf, feature.data, sizeof(buf));

  if (!provider_register(buf, channel_id)) {
    api_set_error(err, Validation, _("Feature doesn't exist"));
  }
}

Array vim_get_api_info(uint64_t channel_id)
{
  Array rv = ARRAY_DICT_INIT;

  assert(channel_id <= INT64_MAX);
  ADD(rv, INTEGER_OBJ((int64_t)channel_id));
  ADD(rv, DICTIONARY_OBJ(api_metadata()));

  return rv;
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
  static int out_pos = 0, err_pos = 0;
  static char out_line_buf[LINE_BUFFER_SIZE], err_line_buf[LINE_BUFFER_SIZE];

#define PUSH_CHAR(i, pos, line_buf, msg)                                      \
  if (message.data[i] == NL || pos == LINE_BUFFER_SIZE - 1) {                 \
    line_buf[pos] = NUL;                                                      \
    msg((uint8_t *)line_buf);                                                 \
    pos = 0;                                                                  \
    continue;                                                                 \
  }                                                                           \
                                                                              \
  line_buf[pos++] = message.data[i];

  for (uint32_t i = 0; i < message.size; i++) {
    if (to_err) {
      PUSH_CHAR(i, err_pos, err_line_buf, emsg);
    } else {
      PUSH_CHAR(i, out_pos, out_line_buf, msg);
    }
  }
}
