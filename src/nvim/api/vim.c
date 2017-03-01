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
#include "nvim/file_search.h"
#include "nvim/window.h"
#include "nvim/types.h"
#include "nvim/ex_docmd.h"
#include "nvim/screen.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/eval.h"
#include "nvim/option.h"
#include "nvim/syntax.h"
#include "nvim/getchar.h"
#include "nvim/os/input.h"

#define LINE_BUFFER_SIZE 4096

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.c.generated.h"
#endif

/// Executes an ex-command.
/// On VimL error: Returns the VimL error; v:errmsg is not updated.
///
/// @param command  Ex-command string
/// @param[out] err Error details (including actual VimL error), if any
void nvim_command(String command, Error *err)
{
  // Run the command
  try_start();
  do_cmdline_cmd(command.data);
  update_screen(VALID);
  try_end(err);
}

/// Passes input keys to Nvim.
/// On VimL error: Does not fail, but updates v:errmsg.
///
/// @param keys         to be typed
/// @param mode         mapping options
/// @param escape_csi   If true, escape K_SPECIAL/CSI bytes in `keys`
/// @see feedkeys()
/// @see vim_strsave_escape_csi
void nvim_feedkeys(String keys, String mode, Boolean escape_csi)
{
  bool remap = true;
  bool insert = false;
  bool typed = false;
  bool execute = false;
  bool dangerous = false;

  for (size_t i = 0; i < mode.size; ++i) {
    switch (mode.data[i]) {
    case 'n': remap = false; break;
    case 'm': remap = true; break;
    case 't': typed = true; break;
    case 'i': insert = true; break;
    case 'x': execute = true; break;
    case '!': dangerous = true; break;
    }
  }

  if (keys.size == 0 && !execute) {
    return;
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
    int save_msg_scroll = msg_scroll;

    /* Avoid a 1 second delay when the keys start Insert mode. */
    msg_scroll = false;
    if (!dangerous) {
      ex_normal_busy++;
    }
    exec_normal(true);
    if (!dangerous) {
      ex_normal_busy--;
    }
    msg_scroll |= save_msg_scroll;
  }
}

/// Passes keys to Nvim as raw user-input.
/// On VimL error: Does not fail, but updates v:errmsg.
///
/// Unlike `nvim_feedkeys`, this uses a lower-level input buffer and the call
/// is not deferred. This is the most reliable way to emulate real user input.
///
/// @param keys to be typed
/// @return Number of bytes actually written (can be fewer than
///         requested if the buffer becomes full).
Integer nvim_input(String keys)
    FUNC_API_ASYNC
{
  return (Integer)input_enqueue(keys);
}

/// Replaces any terminal codes with the internal representation
///
/// @see replace_termcodes
/// @see cpoptions
String nvim_replace_termcodes(String str, Boolean from_part, Boolean do_lt,
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

String nvim_command_output(String str, Error *err)
{
  do_cmdline_cmd("redir => v:command_output");
  nvim_command(str, err);
  do_cmdline_cmd("redir END");

  if (err->set) {
    return (String) STRING_INIT;
  }

  return cstr_to_string((char *)get_vim_var_str(VV_COMMAND_OUTPUT));
}

/// Evaluates a VimL expression (:help expression).
/// Dictionaries and Lists are recursively expanded.
/// On VimL error: Returns a generic error; v:errmsg is not updated.
///
/// @param expr     VimL expression string
/// @param[out] err Error details, if any
/// @return         Evaluation result or expanded object
Object nvim_eval(String expr, Error *err)
{
  Object rv = OBJECT_INIT;
  // Evaluate the expression
  try_start();
  typval_T *expr_result = eval_expr((char_u *)expr.data, NULL);

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

/// Calls a VimL function with the given arguments.
/// On VimL error: Returns a generic error; v:errmsg is not updated.
///
/// @param fname    Function to call
/// @param args     Function arguments packed in an Array
/// @param[out] err Error details, if any
/// @return Result of the function call
Object nvim_call_function(String fname, Array args, Error *err)
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
  int r = call_func((char_u *)fname.data, (int)fname.size,
                    &rettv, (int)args.size, vim_args, NULL,
                    curwin->w_cursor.lnum, curwin->w_cursor.lnum, &dummy,
                    true, NULL, NULL);
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

/// Calculates the number of display cells occupied by `text`.
/// <Tab> counts as one cell.
///
/// @param text       Some text
/// @param[out] err   Error details, if any
/// @return Number of cells
Integer nvim_strwidth(String str, Error *err)
{
  if (str.size > INT_MAX) {
    api_set_error(err, Validation, _("String length is too high"));
    return 0;
  }

  return (Integer) mb_string2cells((char_u *) str.data);
}

/// Gets the paths contained in 'runtimepath'.
///
/// @return List of paths
ArrayOf(String) nvim_list_runtime_paths(void)
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

/// Changes the global working directory.
///
/// @param dir      Directory path
/// @param[out] err Error details, if any
void nvim_set_current_dir(String dir, Error *err)
{
  if (dir.size >= MAXPATHL) {
    api_set_error(err, Validation, _("Directory string is too long"));
    return;
  }

  char string[MAXPATHL];
  memcpy(string, dir.data, dir.size);
  string[dir.size] = NUL;

  try_start();

  if (vim_chdir((char_u *)string, kCdScopeGlobal)) {
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
/// @param[out] err Error details, if any
/// @return Current line string
String nvim_get_current_line(Error *err)
{
  return buffer_get_line(curbuf->handle, curwin->w_cursor.lnum - 1, err);
}

/// Sets the current line
///
/// @param line     Line contents
/// @param[out] err Error details, if any
void nvim_set_current_line(String line, Error *err)
{
  buffer_set_line(curbuf->handle, curwin->w_cursor.lnum - 1, line, err);
}

/// Deletes the current line
///
/// @param[out] err Error details, if any
void nvim_del_current_line(Error *err)
{
  buffer_del_line(curbuf->handle, curwin->w_cursor.lnum - 1, err);
}

/// Gets a global (g:) variable
///
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_get_var(String name, Error *err)
{
  return dict_get_value(&globvardict, name, err);
}

/// Sets a global (g:) variable
///
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_set_var(String name, Object value, Error *err)
{
  dict_set_var(&globvardict, name, value, false, false, err);
}

/// Removes a global (g:) variable
///
/// @param name     Variable name
/// @param[out] err Error details, if any
void nvim_del_var(String name, Error *err)
{
  dict_set_var(&globvardict, name, NIL, true, false, err);
}

/// Sets a global variable
///
/// @deprecated
///
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
/// @return Old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object vim_set_var(String name, Object value, Error *err)
{
  return dict_set_var(&globvardict, name, value, false, true, err);
}

/// Removes a global variable
///
/// @deprecated
///
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Old value
Object vim_del_var(String name, Error *err)
{
  return dict_set_var(&globvardict, name, NIL, true, true, err);
}

/// Gets a v: variable
///
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return         Variable value
Object nvim_get_vvar(String name, Error *err)
{
  return dict_get_value(&vimvardict, name, err);
}

/// Gets an option value string
///
/// @param name     Option name
/// @param[out] err Error details, if any
/// @return         Option value
Object nvim_get_option(String name, Error *err)
{
  return get_option_from(NULL, SREQ_GLOBAL, name, err);
}

/// Sets an option value
///
/// @param name     Option name
/// @param value    New option value
/// @param[out] err Error details, if any
void nvim_set_option(String name, Object value, Error *err)
{
  set_option_to(NULL, SREQ_GLOBAL, name, value, err);
}

/// Writes a message to vim output buffer
///
/// @param str Message
void nvim_out_write(String str)
{
  write_msg(str, false);
}

/// Writes a message to vim error buffer
///
/// @param str Message
void nvim_err_write(String str)
{
  write_msg(str, true);
}

/// Writes a message to vim error buffer. Appends a linefeed to ensure all
/// contents are written.
///
/// @param str Message
/// @see nvim_err_write()
void nvim_err_writeln(String str)
{
  nvim_err_write(str);
  nvim_err_write((String) { .data = "\n", .size = 1 });
}

/// Gets the current list of buffer handles
///
/// @return List of buffer handles
ArrayOf(Buffer) nvim_list_bufs(void)
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
/// @return Buffer handle
Buffer nvim_get_current_buf(void)
{
  return curbuf->handle;
}

/// Sets the current buffer
///
/// @param id       Buffer handle
/// @param[out] err Error details, if any
void nvim_set_current_buf(Buffer buffer, Error *err)
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
                  _("Failed to switch to buffer %d"),
                  buffer);
  }
}

/// Gets the current list of window handles
///
/// @return List of window handles
ArrayOf(Window) nvim_list_wins(void)
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
/// @return Window handle
Window nvim_get_current_win(void)
{
  return curwin->handle;
}

/// Sets the current window
///
/// @param handle Window handle
void nvim_set_current_win(Window window, Error *err)
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
                  _("Failed to switch to window %d"),
                  window);
  }
}

/// Gets the current list of tabpage handles
///
/// @return List of tabpage handles
ArrayOf(Tabpage) nvim_list_tabpages(void)
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

/// Gets the current tabpage
///
/// @return Tabpage handle
Tabpage nvim_get_current_tabpage(void)
{
  return curtab->handle;
}

/// Sets the current tabpage
///
/// @param handle   Tabpage handle
/// @param[out] err Error details, if any
void nvim_set_current_tabpage(Tabpage tabpage, Error *err)
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
                  _("Failed to switch to tabpage %d"),
                  tabpage);
  }
}

/// Subscribes to event broadcasts
///
/// @param channel_id Channel id (passed automatically by the dispatcher)
/// @param event      Event type string
void nvim_subscribe(uint64_t channel_id, String event)
    FUNC_API_NOEVAL
{
  size_t length = (event.size < METHOD_MAXLEN ? event.size : METHOD_MAXLEN);
  char e[METHOD_MAXLEN + 1];
  memcpy(e, event.data, length);
  e[length] = NUL;
  channel_subscribe(channel_id, e);
}

/// Unsubscribes to event broadcasts
///
/// @param channel_id Channel id (passed automatically by the dispatcher)
/// @param event      Event type string
void nvim_unsubscribe(uint64_t channel_id, String event)
    FUNC_API_NOEVAL
{
  size_t length = (event.size < METHOD_MAXLEN ?
                   event.size :
                   METHOD_MAXLEN);
  char e[METHOD_MAXLEN + 1];
  memcpy(e, event.data, length);
  e[length] = NUL;
  channel_unsubscribe(channel_id, e);
}

Integer nvim_get_color_by_name(String name)
{
  return name_to_color((uint8_t *)name.data);
}

Dictionary nvim_get_color_map(void)
{
  Dictionary colors = ARRAY_DICT_INIT;

  for (int i = 0; color_name_table[i].name != NULL; i++) {
    PUT(colors, color_name_table[i].name,
        INTEGER_OBJ(color_name_table[i].color));
  }
  return colors;
}


Array nvim_get_api_info(uint64_t channel_id)
    FUNC_API_ASYNC FUNC_API_NOEVAL
{
  Array rv = ARRAY_DICT_INIT;

  assert(channel_id <= INT64_MAX);
  ADD(rv, INTEGER_OBJ((int64_t)channel_id));
  ADD(rv, DICTIONARY_OBJ(api_metadata()));

  return rv;
}

/// Call many api methods atomically
///
/// This has two main usages: Firstly, to perform several requests from an
/// async context atomically, i.e. without processing requests from other rpc
/// clients or redrawing or allowing user interaction in between. Note that api
/// methods that could fire autocommands or do event processing still might do
/// so. For instance invoking the :sleep command might call timer callbacks.
/// Secondly, it can be used to reduce rpc overhead (roundtrips) when doing
/// many requests in sequence.
///
/// @param calls an array of calls, where each call is described by an array
/// with two elements: the request name, and an array of arguments.
/// @param[out] err Details of a validation error of the nvim_multi_request call
/// itself, i e malformatted `calls` parameter. Errors from called methods will
/// be indicated in the return value, see below.
///
/// @return an array with two elements. The first is an array of return
/// values. The second is NIL if all calls succeeded. If a call resulted in
/// an error, it is a three-element array with the zero-based index of the call
/// which resulted in an error, the error type and the error message. If an
/// error ocurred, the values from all preceding calls will still be returned.
Array nvim_call_atomic(uint64_t channel_id, Array calls, Error *err)
  FUNC_API_NOEVAL
{
  Array rv = ARRAY_DICT_INIT;
  Array results = ARRAY_DICT_INIT;
  Error nested_error = ERROR_INIT;

  size_t i;  // also used for freeing the variables
  for (i = 0; i < calls.size; i++) {
    if (calls.items[i].type != kObjectTypeArray) {
      api_set_error(err,
                    Validation,
                    _("All items in calls array must be arrays"));
      goto validation_error;
    }
    Array call = calls.items[i].data.array;
    if (call.size != 2) {
      api_set_error(err,
                    Validation,
                    _("All items in calls array must be arrays of size 2"));
      goto validation_error;
    }

    if (call.items[0].type != kObjectTypeString) {
      api_set_error(err,
                    Validation,
                    _("name must be String"));
      goto validation_error;
    }
    String name = call.items[0].data.string;

    if (call.items[1].type != kObjectTypeArray) {
      api_set_error(err,
                    Validation,
                    _("args must be Array"));
      goto validation_error;
    }
    Array args = call.items[1].data.array;

    MsgpackRpcRequestHandler handler = msgpack_rpc_get_handler_for(name.data,
                                                                   name.size);
    Object result = handler.fn(channel_id, args, &nested_error);
    if (nested_error.set) {
      // error handled after loop
      break;
    }

    ADD(results, result);
  }

  ADD(rv, ARRAY_OBJ(results));
  if (nested_error.set) {
    Array errval = ARRAY_DICT_INIT;
    ADD(errval, INTEGER_OBJ((Integer)i));
    ADD(errval, INTEGER_OBJ(nested_error.type));
    ADD(errval, STRING_OBJ(cstr_to_string(nested_error.msg)));
    ADD(rv, ARRAY_OBJ(errval));
  } else {
    ADD(rv, NIL);
  }
  xfree(nested_error.msg);
  return rv;

validation_error:
  api_free_array(results);
  xfree(nested_error.msg);
  return rv;
}


/// Writes a message to vim output or error buffer. The string is split
/// and flushed after each newline. Incomplete lines are kept for writing
/// later.
///
/// @param message  Message to write
/// @param to_err   true: message is an error (uses `emsg` instead of `msg`)
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
