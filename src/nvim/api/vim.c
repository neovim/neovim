#include <assert.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#include "nvim/api/vim.h"
#include "nvim/ascii.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/buffer.h"
#include "nvim/msgpack_rpc/channel.h"
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
#include "nvim/syntax.h"
#include "nvim/getchar.h"
#include "nvim/os/input.h"

#define LINE_BUFFER_SIZE 4096

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.c.generated.h"
#endif

/// Executes an ex-mode command str
///
/// @param str The command str
/// @param[out] err Details of an error that may have occurred
void vim_command(String str, Error *err)
{
  // Run the command
  try_start();
  do_cmdline_cmd(str.data);
  update_screen(VALID);
  try_end(err);
}

/// Passes input keys to Neovim
///
/// @param keys to be typed
/// @param mode specifies the mapping options
/// @param escape_csi the string needs escaping for K_SPECIAL/CSI bytes
/// @see feedkeys()
/// @see vim_strsave_escape_csi
void vim_feedkeys(String keys, String mode, Boolean escape_csi)
{
  bool remap = true;
  bool insert = false;
  bool typed = false;
  bool execute = false;

  if (keys.size == 0) {
    return;
  }

  for (size_t i = 0; i < mode.size; ++i) {
    switch (mode.data[i]) {
    case 'n': remap = false; break;
    case 'm': remap = true; break;
    case 't': typed = true; break;
    case 'i': insert = true; break;
    case 'x': execute = true; break;
    }
  }

  char *keys_esc;
  if (escape_csi) {
      // Need to escape K_SPECIAL and CSI before putting the string in the
      // typeahead buffer.
      keys_esc = (char *)vim_strsave_escape_csi((char_u *)keys.data);
  } else {
      keys_esc = keys.data;
  }
  ins_typebuf((char_u *)keys_esc, (remap ? REMAP_YES : REMAP_NONE),
      insert ? 0 : typebuf.tb_len, !typed, false);

  if (escape_csi) {
      xfree(keys_esc);
  }

  if (vgetc_busy) {
    typebuf_was_filled = true;
  }
  if (execute) {
    exec_normal(true);
  }
}

/// Passes input keys to Neovim. Unlike `vim_feedkeys`, this will use a
/// lower-level input buffer and the call is not deferred.
/// This is the most reliable way to emulate real user input.
///
/// @param keys to be typed
/// @return The number of bytes actually written, which can be lower than
///         requested if the buffer becomes full.
Integer vim_input(String keys)
    FUNC_API_ASYNC
{
  return (Integer)input_enqueue(keys);
}

/// Replaces any terminal codes with the internal representation
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
  // Set 'cpoptions' the way we want it.
  //    FLAG_CPO_BSLASH  set - backslashes are *not* treated specially
  //    FLAG_CPO_KEYCODE set - keycodes are *not* reverse-engineered
  //    FLAG_CPO_SPECI unset - <Key> sequences *are* interpreted
  //  The third from end parameter of replace_termcodes() is true so that the
  //  <lt> sequence is recognised - needed for a real backslash.
  replace_termcodes((char_u *)str.data, str.size, (char_u **)&ptr,
                    from_part, do_lt, special, CPO_TO_CPO_FLAGS);
  return cstr_as_string(ptr);
}

String vim_command_output(String str, Error *err)
{
  do_cmdline_cmd("redir => v:command_output");
  vim_command(str, err);
  do_cmdline_cmd("redir END");

  if (err->set) {
    return (String) STRING_INIT;
  }

  return cstr_to_string((char *)get_vim_var_str(VV_COMMAND_OUTPUT));
}

/// Evaluates the expression str using the Vim internal expression
/// evaluator (see |expression|).
/// Dictionaries and lists are recursively expanded.
///
/// @param str The expression str
/// @param[out] err Details of an error that may have occurred
/// @return The expanded object
Object vim_eval(String str, Error *err)
{
  Object rv = OBJECT_INIT;
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

/// Call the given function with the given arguments stored in an array.
///
/// @param fname Function to call
/// @param args Functions arguments packed in an Array
/// @param[out] err Details of an error that may have occurred
/// @return Result of the function call
Object vim_call_function(String fname, Array args, Error *err)
{
  Object rv = OBJECT_INIT;
  if (args.size > MAX_FUNC_ARGS) {
    api_set_error(err, Validation,
      _("Function called with too many arguments."));
    return rv;
  }

  // Convert the arguments in args from Object to typval_T values
  typval_T vim_args[MAX_FUNC_ARGS + 1];
  size_t i = 0;  // also used for freeing the variables
  for (; i < args.size; i++) {
    if (!object_to_vim(args.items[i], &vim_args[i], err)) {
      goto free_vim_args;
    }
  }

  try_start();
  // Call the function
  typval_T rettv;
  int dummy;
  int r = call_func((char_u *) fname.data, (int) fname.size,
                    &rettv, (int) args.size, vim_args,
                    curwin->w_cursor.lnum, curwin->w_cursor.lnum, &dummy,
                    true,
                    NULL);
  if (r == FAIL) {
    api_set_error(err, Exception, _("Error calling function."));
  }
  if (!try_end(err)) {
    rv = vim_to_object(&rettv);
  }
  clear_tv(&rettv);

free_vim_args:
  while (i > 0) {
    clear_tv(&vim_args[--i]);
  }

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

/// Gets a list of paths contained in 'runtimepath'
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
  // Reset the position
  rtp = p_rtp;
  // Start copying
  for (size_t i = 0; i < rv.size && *rtp != NUL; i++) {
    rv.items[i].type = kObjectTypeString;
    rv.items[i].data.string.data = xmalloc(MAXPATHL);
    // Copy the path from 'runtimepath' to rv.items[i]
    size_t length = copy_option_part(&rtp,
                                     (char_u *)rv.items[i].data.string.data,
                                     MAXPATHL,
                                     ",");
    rv.items[i].data.string.size = length;
  }

  return rv;
}

/// Changes Vim working directory
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

  post_chdir(kCdScopeGlobal);
  try_end(err);
}

/// Gets the current line
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

/// Deletes the current line
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

/// Sets a global variable
///
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return The old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object vim_set_var(String name, Object value, Error *err)
{
  return dict_set_value(&globvardict, name, value, false, err);
}

/// Removes a global variable
///
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object vim_del_var(String name, Error *err)
{
  return dict_set_value(&globvardict, name, NIL, true, err);
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

/// Gets an option value string
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

/// Writes a message to vim output buffer
///
/// @param str The message
void vim_out_write(String str)
{
  write_msg(str, false);
}

/// Writes a message to vim error buffer
///
/// @param str The message
void vim_err_write(String str)
{
  write_msg(str, true);
}

/// Higher level error reporting function that ensures all str contents
/// are written by sending a trailing linefeed to `vim_err_write`
///
/// @param str The message
void vim_report_error(String str)
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

  FOR_ALL_BUFFERS(b) {
    rv.size++;
  }

  rv.items = xmalloc(sizeof(Object) * rv.size);
  size_t i = 0;

  FOR_ALL_BUFFERS(b) {
    rv.items[i++] = BUFFER_OBJ(b->handle);
  }

  return rv;
}

/// Gets the current buffer
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

/// Gets the current window
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

  FOR_ALL_TABS(tp) {
    rv.size++;
  }

  rv.items = xmalloc(sizeof(Object) * rv.size);
  size_t i = 0;

  FOR_ALL_TABS(tp) {
    rv.items[i++] = TABPAGE_OBJ(tp->handle);
  }

  return rv;
}

/// Gets the current tab page
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
  if (!try_end(err) && tp != curtab) {
    api_set_error(err,
                  Exception,
                  _("Failed to switch to tabpage %" PRIu64),
                  tabpage);
  }
}

/// Subscribes to event broadcasts
///
/// @param channel_id The channel id (passed automatically by the dispatcher)
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
/// @param channel_id The channel id (passed automatically by the dispatcher)
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

Integer vim_name_to_color(String name)
{
  return name_to_color((uint8_t *)name.data);
}

Dictionary vim_get_color_map(void)
{
  Dictionary colors = ARRAY_DICT_INIT;

  for (int i = 0; color_name_table[i].name != NULL; i++) {
    PUT(colors, color_name_table[i].name,
        INTEGER_OBJ(color_name_table[i].color));
  }
  return colors;
}


Array vim_get_api_info(uint64_t channel_id)
    FUNC_API_ASYNC
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
/// @param to_err true if it should be treated as an error message (use
///        `emsg` instead of `msg` to print each line)
static void write_msg(String message, bool to_err)
{
  static size_t out_pos = 0, err_pos = 0;
  static char out_line_buf[LINE_BUFFER_SIZE], err_line_buf[LINE_BUFFER_SIZE];

#define PUSH_CHAR(i, pos, line_buf, msg) \
  if (message.data[i] == NL || pos == LINE_BUFFER_SIZE - 1) { \
    line_buf[pos] = NUL; \
    msg((uint8_t *)line_buf); \
    pos = 0; \
    continue; \
  } \
  \
  line_buf[pos++] = message.data[i];

  ++no_wait_return;
  for (uint32_t i = 0; i < message.size; i++) {
    if (to_err) {
      PUSH_CHAR(i, err_pos, err_line_buf, emsg);
    } else {
      PUSH_CHAR(i, out_pos, out_line_buf, msg);
    }
  }
  --no_wait_return;
  msg_end();
}
