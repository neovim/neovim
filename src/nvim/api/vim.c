// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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
#include "nvim/api/private/dispatch.h"
#include "nvim/api/buffer.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/lua/executor.h"
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
#include "nvim/eval/typval.h"
#include "nvim/option.h"
#include "nvim/state.h"
#include "nvim/syntax.h"
#include "nvim/getchar.h"
#include "nvim/os/input.h"
#include "nvim/os/process.h"
#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/parser.h"
#include "nvim/ui.h"

#define LINE_BUFFER_SIZE 4096

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.c.generated.h"
#endif

/// Executes an ex-command.
///
/// On parse error: forwards the Vim error; does not update v:errmsg.
/// On runtime error: forwards the Vim error; does not update v:errmsg.
///
/// @param command  Ex-command string
/// @param[out] err Error details (Vim error), if any
void nvim_command(String command, Error *err)
  FUNC_API_SINCE(1)
{
  try_start();
  do_cmdline_cmd(command.data);
  update_screen(VALID);
  try_end(err);
}

/// Gets a highlight definition by name.
///
/// @param name Highlight group name
/// @param rgb Export RGB colors
/// @param[out] err Error details, if any
/// @return Highlight definition map
/// @see nvim_get_hl_by_id
Dictionary nvim_get_hl_by_name(String name, Boolean rgb, Error *err)
  FUNC_API_SINCE(3)
{
  Dictionary result = ARRAY_DICT_INIT;
  int id = syn_name2id((const char_u *)name.data);

  if (id == 0) {
    api_set_error(err, kErrorTypeException, "Invalid highlight name: %s",
                  name.data);
    return result;
  }
  result = nvim_get_hl_by_id(id, rgb, err);
  return result;
}

/// Gets a highlight definition by id. |hlID()|
///
/// @param hl_id Highlight id as returned by |hlID()|
/// @param rgb Export RGB colors
/// @param[out] err Error details, if any
/// @return Highlight definition map
/// @see nvim_get_hl_by_name
Dictionary nvim_get_hl_by_id(Integer hl_id, Boolean rgb, Error *err)
  FUNC_API_SINCE(3)
{
  Dictionary dic = ARRAY_DICT_INIT;
  if (syn_get_final_id((int)hl_id) == 0) {
    api_set_error(err, kErrorTypeException,
                  "Invalid highlight id: %" PRId64, hl_id);
    return dic;
  }
  int attrcode = syn_id2attr((int)hl_id);
  return hl_get_attr_by_id(attrcode, rgb, err);
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
  FUNC_API_SINCE(1)
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
/// is not deferred. This is the most reliable way to send real user input.
///
/// @note |keycodes| like <CR> are translated, so "<" is special.
///       To input a literal "<", send <LT>.
///
/// @param keys to be typed
/// @return Number of bytes actually written (can be fewer than
///         requested if the buffer becomes full).
Integer nvim_input(String keys)
  FUNC_API_SINCE(1) FUNC_API_ASYNC
{
  return (Integer)input_enqueue(keys);
}

/// Replaces terminal codes and |keycodes| (<CR>, <Esc>, ...) in a string with
/// the internal representation.
///
/// @param str        String to be converted.
/// @param from_part  Legacy Vim parameter. Usually true.
/// @param do_lt      Also translate <lt>. Ignored if `special` is false.
/// @param special    Replace |keycodes|, e.g. <CR> becomes a "\n" char.
/// @see replace_termcodes
/// @see cpoptions
String nvim_replace_termcodes(String str, Boolean from_part, Boolean do_lt,
                              Boolean special)
  FUNC_API_SINCE(1)
{
  if (str.size == 0) {
    // Empty string
    return (String) { .data = NULL, .size = 0 };
  }

  char *ptr = NULL;
  replace_termcodes((char_u *)str.data, str.size, (char_u **)&ptr,
                    from_part, do_lt, special, CPO_TO_CPO_FLAGS);
  return cstr_as_string(ptr);
}

/// Executes an ex-command and returns its (non-error) output.
/// Shell |:!| output is not captured.
///
/// On parse error: forwards the Vim error; does not update v:errmsg.
/// On runtime error: forwards the Vim error; does not update v:errmsg.
///
/// @param command  Ex-command string
/// @param[out] err Error details (Vim error), if any
String nvim_command_output(String command, Error *err)
  FUNC_API_SINCE(1)
{
  const int save_msg_silent = msg_silent;
  garray_T *const save_capture_ga = capture_ga;
  garray_T capture_local;
  ga_init(&capture_local, 1, 80);

  try_start();
  msg_silent++;
  capture_ga = &capture_local;
  do_cmdline_cmd(command.data);
  capture_ga = save_capture_ga;
  msg_silent = save_msg_silent;
  try_end(err);

  if (ERROR_SET(err)) {
    goto theend;
  }

  if (capture_local.ga_len > 1) {
    // redir always(?) prepends a newline; remove it.
    char *s = capture_local.ga_data;
    assert(s[0] == '\n');
    memmove(s, s + 1, (size_t)capture_local.ga_len);
    s[capture_local.ga_len - 1] = '\0';
    return (String) {  // Caller will free the memory.
      .data = s,
      .size = (size_t)(capture_local.ga_len - 1),
    };
  }

theend:
  ga_clear(&capture_local);
  return (String)STRING_INIT;
}

/// Evaluates a VimL expression (:help expression).
/// Dictionaries and Lists are recursively expanded.
/// On VimL error: Returns a generic error; v:errmsg is not updated.
///
/// @param expr     VimL expression string
/// @param[out] err Error details, if any
/// @return         Evaluation result or expanded object
Object nvim_eval(String expr, Error *err)
  FUNC_API_SINCE(1)
{
  Object rv = OBJECT_INIT;
  // Evaluate the expression
  try_start();

  typval_T rettv;
  if (eval0((char_u *)expr.data, &rettv, NULL, true) == FAIL) {
    api_set_error(err, kErrorTypeException, "Failed to evaluate expression");
  }

  if (!try_end(err)) {
    // No errors, convert the result
    rv = vim_to_object(&rettv);
  }

  // Free the Vim object
  tv_clear(&rettv);

  return rv;
}

/// Calls a VimL function with the given arguments
///
/// On VimL error: Returns a generic error; v:errmsg is not updated.
///
/// @param fname    Function to call
/// @param args     Function arguments packed in an Array
/// @param[out] err Error details, if any
/// @return Result of the function call
Object nvim_call_function(String fname, Array args, Error *err)
  FUNC_API_SINCE(1)
{
  Object rv = OBJECT_INIT;
  if (args.size > MAX_FUNC_ARGS) {
    api_set_error(err, kErrorTypeValidation,
                  "Function called with too many arguments.");
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
    api_set_error(err, kErrorTypeException, "Error calling function.");
  }
  if (!try_end(err)) {
    rv = vim_to_object(&rettv);
  }
  tv_clear(&rettv);

free_vim_args:
  while (i > 0) {
    tv_clear(&vim_args[--i]);
  }

  return rv;
}

/// Execute lua code. Parameters (if any) are available as `...` inside the
/// chunk. The chunk can return a value.
///
/// Only statements are executed. To evaluate an expression, prefix it
/// with `return`: return my_function(...)
///
/// @param code       lua code to execute
/// @param args       Arguments to the code
/// @param[out] err   Details of an error encountered while parsing
///                   or executing the lua code.
///
/// @return           Return value of lua code if present or NIL.
Object nvim_execute_lua(String code, Array args, Error *err)
  FUNC_API_SINCE(3) FUNC_API_REMOTE_ONLY
{
  return executor_exec_lua_api(code, args, err);
}

/// Calculates the number of display cells occupied by `text`.
/// <Tab> counts as one cell.
///
/// @param text       Some text
/// @param[out] err   Error details, if any
/// @return Number of cells
Integer nvim_strwidth(String text, Error *err)
  FUNC_API_SINCE(1)
{
  if (text.size > INT_MAX) {
    api_set_error(err, kErrorTypeValidation, "String length is too high");
    return 0;
  }

  return (Integer)mb_string2cells((char_u *)text.data);
}

/// Gets the paths contained in 'runtimepath'.
///
/// @return List of paths
ArrayOf(String) nvim_list_runtime_paths(void)
  FUNC_API_SINCE(1)
{
  Array rv = ARRAY_DICT_INIT;
  char_u *rtp = p_rtp;

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
  rv.size++;

  // Allocate memory for the copies
  rv.items = xmalloc(sizeof(*rv.items) * rv.size);
  // Reset the position
  rtp = p_rtp;
  // Start copying
  for (size_t i = 0; i < rv.size; i++) {
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
  FUNC_API_SINCE(1)
{
  if (dir.size >= MAXPATHL) {
    api_set_error(err, kErrorTypeValidation, "Directory string is too long");
    return;
  }

  char string[MAXPATHL];
  memcpy(string, dir.data, dir.size);
  string[dir.size] = NUL;

  try_start();

  if (vim_chdir((char_u *)string, kCdScopeGlobal)) {
    if (!try_end(err)) {
      api_set_error(err, kErrorTypeException, "Failed to change directory");
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
  FUNC_API_SINCE(1)
{
  return buffer_get_line(curbuf->handle, curwin->w_cursor.lnum - 1, err);
}

/// Sets the current line
///
/// @param line     Line contents
/// @param[out] err Error details, if any
void nvim_set_current_line(String line, Error *err)
  FUNC_API_SINCE(1)
{
  buffer_set_line(curbuf->handle, curwin->w_cursor.lnum - 1, line, err);
}

/// Deletes the current line
///
/// @param[out] err Error details, if any
void nvim_del_current_line(Error *err)
  FUNC_API_SINCE(1)
{
  buffer_del_line(curbuf->handle, curwin->w_cursor.lnum - 1, err);
}

/// Gets a global (g:) variable
///
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_get_var(String name, Error *err)
  FUNC_API_SINCE(1)
{
  return dict_get_value(&globvardict, name, err);
}

/// Sets a global (g:) variable
///
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_set_var(String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  dict_set_var(&globvardict, name, value, false, false, err);
}

/// Removes a global (g:) variable
///
/// @param name     Variable name
/// @param[out] err Error details, if any
void nvim_del_var(String name, Error *err)
  FUNC_API_SINCE(1)
{
  dict_set_var(&globvardict, name, NIL, true, false, err);
}

/// @deprecated
/// @see nvim_set_var
/// @return Old value or nil if there was no previous value.
/// @warning May return nil if there was no previous value
///          OR if previous value was `v:null`.
Object vim_set_var(String name, Object value, Error *err)
{
  return dict_set_var(&globvardict, name, value, false, true, err);
}

/// @deprecated
/// @see nvim_del_var
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
  FUNC_API_SINCE(1)
{
  return dict_get_value(&vimvardict, name, err);
}

/// Gets an option value string
///
/// @param name     Option name
/// @param[out] err Error details, if any
/// @return         Option value (global)
Object nvim_get_option(String name, Error *err)
  FUNC_API_SINCE(1)
{
  return get_option_from(NULL, SREQ_GLOBAL, name, err);
}

/// Sets an option value
///
/// @param name     Option name
/// @param value    New option value
/// @param[out] err Error details, if any
void nvim_set_option(String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  set_option_to(NULL, SREQ_GLOBAL, name, value, err);
}

/// Writes a message to the Vim output buffer. Does not append "\n", the
/// message is buffered (won't display) until a linefeed is written.
///
/// @param str Message
void nvim_out_write(String str)
  FUNC_API_SINCE(1)
{
  write_msg(str, false);
}

/// Writes a message to the Vim error buffer. Does not append "\n", the
/// message is buffered (won't display) until a linefeed is written.
///
/// @param str Message
void nvim_err_write(String str)
  FUNC_API_SINCE(1)
{
  write_msg(str, true);
}

/// Writes a message to the Vim error buffer. Appends "\n", so the buffer is
/// flushed (and displayed).
///
/// @param str Message
/// @see nvim_err_write()
void nvim_err_writeln(String str)
  FUNC_API_SINCE(1)
{
  nvim_err_write(str);
  nvim_err_write((String) { .data = "\n", .size = 1 });
}

/// Gets the current list of buffer handles
///
/// @return List of buffer handles
ArrayOf(Buffer) nvim_list_bufs(void)
  FUNC_API_SINCE(1)
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
  FUNC_API_SINCE(1)
{
  return curbuf->handle;
}

/// Sets the current buffer
///
/// @param buffer   Buffer handle
/// @param[out] err Error details, if any
void nvim_set_current_buf(Buffer buffer, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  try_start();
  int result = do_buffer(DOBUF_GOTO, DOBUF_FIRST, FORWARD, buf->b_fnum, 0);
  if (!try_end(err) && result == FAIL) {
    api_set_error(err,
                  kErrorTypeException,
                  "Failed to switch to buffer %d",
                  buffer);
  }
}

/// Gets the current list of window handles
///
/// @return List of window handles
ArrayOf(Window) nvim_list_wins(void)
  FUNC_API_SINCE(1)
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
  FUNC_API_SINCE(1)
{
  return curwin->handle;
}

/// Sets the current window
///
/// @param window Window handle
void nvim_set_current_win(Window window, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  try_start();
  goto_tabpage_win(win_find_tabpage(win), win);
  if (!try_end(err) && win != curwin) {
    api_set_error(err,
                  kErrorTypeException,
                  "Failed to switch to window %d",
                  window);
  }
}

/// Gets the current list of tabpage handles
///
/// @return List of tabpage handles
ArrayOf(Tabpage) nvim_list_tabpages(void)
  FUNC_API_SINCE(1)
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
  FUNC_API_SINCE(1)
{
  return curtab->handle;
}

/// Sets the current tabpage
///
/// @param tabpage  Tabpage handle
/// @param[out] err Error details, if any
void nvim_set_current_tabpage(Tabpage tabpage, Error *err)
  FUNC_API_SINCE(1)
{
  tabpage_T *tp = find_tab_by_handle(tabpage, err);

  if (!tp) {
    return;
  }

  try_start();
  goto_tabpage_tp(tp, true, true);
  if (!try_end(err) && tp != curtab) {
    api_set_error(err,
                  kErrorTypeException,
                  "Failed to switch to tabpage %d",
                  tabpage);
  }
}

/// Subscribes to event broadcasts
///
/// @param channel_id Channel id (passed automatically by the dispatcher)
/// @param event      Event type string
void nvim_subscribe(uint64_t channel_id, String event)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  size_t length = (event.size < METHOD_MAXLEN ? event.size : METHOD_MAXLEN);
  char e[METHOD_MAXLEN + 1];
  memcpy(e, event.data, length);
  e[length] = NUL;
  rpc_subscribe(channel_id, e);
}

/// Unsubscribes to event broadcasts
///
/// @param channel_id Channel id (passed automatically by the dispatcher)
/// @param event      Event type string
void nvim_unsubscribe(uint64_t channel_id, String event)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  size_t length = (event.size < METHOD_MAXLEN ?
                   event.size :
                   METHOD_MAXLEN);
  char e[METHOD_MAXLEN + 1];
  memcpy(e, event.data, length);
  e[length] = NUL;
  rpc_unsubscribe(channel_id, e);
}

Integer nvim_get_color_by_name(String name)
  FUNC_API_SINCE(1)
{
  return name_to_color((char_u *)name.data);
}

Dictionary nvim_get_color_map(void)
  FUNC_API_SINCE(1)
{
  Dictionary colors = ARRAY_DICT_INIT;

  for (int i = 0; color_name_table[i].name != NULL; i++) {
    PUT(colors, color_name_table[i].name,
        INTEGER_OBJ(color_name_table[i].color));
  }
  return colors;
}


/// Gets the current mode. |mode()|
/// "blocking" is true if Nvim is waiting for input.
///
/// @returns Dictionary { "mode": String, "blocking": Boolean }
Dictionary nvim_get_mode(void)
  FUNC_API_SINCE(2) FUNC_API_ASYNC
{
  Dictionary rv = ARRAY_DICT_INIT;
  char *modestr = get_mode();
  bool blocked = input_blocking();

  PUT(rv, "mode", STRING_OBJ(cstr_as_string(modestr)));
  PUT(rv, "blocking", BOOLEAN_OBJ(blocked));

  return rv;
}

/// Gets a list of dictionaries describing global (non-buffer) mappings.
/// The "buffer" key in the returned dictionary is always zero.
///
/// @param  mode       Mode short-name ("n", "i", "v", ...)
/// @returns Array of maparg()-like dictionaries describing mappings
ArrayOf(Dictionary) nvim_get_keymap(String mode)
    FUNC_API_SINCE(3)
{
  return keymap_array(mode, NULL);
}

/// Returns a 2-tuple (Array), where item 0 is the current channel id and item
/// 1 is the |api-metadata| map (Dictionary).
///
/// @returns 2-tuple [{channel-id}, {api-metadata}]
Array nvim_get_api_info(uint64_t channel_id)
  FUNC_API_SINCE(1) FUNC_API_ASYNC FUNC_API_REMOTE_ONLY
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
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  Array rv = ARRAY_DICT_INIT;
  Array results = ARRAY_DICT_INIT;
  Error nested_error = ERROR_INIT;

  size_t i;  // also used for freeing the variables
  for (i = 0; i < calls.size; i++) {
    if (calls.items[i].type != kObjectTypeArray) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "All items in calls array must be arrays");
      goto validation_error;
    }
    Array call = calls.items[i].data.array;
    if (call.size != 2) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "All items in calls array must be arrays of size 2");
      goto validation_error;
    }

    if (call.items[0].type != kObjectTypeString) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Name must be String");
      goto validation_error;
    }
    String name = call.items[0].data.string;

    if (call.items[1].type != kObjectTypeArray) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Args must be Array");
      goto validation_error;
    }
    Array args = call.items[1].data.array;

    MsgpackRpcRequestHandler handler = msgpack_rpc_get_handler_for(name.data,
                                                                   name.size);
    Object result = handler.fn(channel_id, args, &nested_error);
    if (ERROR_SET(&nested_error)) {
      // error handled after loop
      break;
    }

    ADD(results, result);
  }

  ADD(rv, ARRAY_OBJ(results));
  if (ERROR_SET(&nested_error)) {
    Array errval = ARRAY_DICT_INIT;
    ADD(errval, INTEGER_OBJ((Integer)i));
    ADD(errval, INTEGER_OBJ(nested_error.type));
    ADD(errval, STRING_OBJ(cstr_to_string(nested_error.msg)));
    ADD(rv, ARRAY_OBJ(errval));
  } else {
    ADD(rv, NIL);
  }
  goto theend;

validation_error:
  api_free_array(results);
theend:
  api_clear_error(&nested_error);
  return rv;
}

typedef struct {
  ExprASTNode **node_p;
  Object *ret_node_p;
} ExprASTConvStackItem;

/// @cond DOXYGEN_NOT_A_FUNCTION
typedef kvec_withinit_t(ExprASTConvStackItem, 16) ExprASTConvStack;
/// @endcond

/// Parse a VimL expression
///
/// @param[in]  expr  Expression to parse. Is always treated as a single line.
/// @param[in]  flags  Flags:
///
///                    - "m" if multiple expressions in a row are allowed (only
///                      the first one will be parsed),
///                    - "E" if EOC tokens are not allowed (determines whether
///                      they will stop parsing process or be recognized as an
///                      operator/space, though also yielding an error).
///                    - "l" when needing to start parsing with lvalues for
///                      ":let" or ":for".
///
///                    Common flag sets:
///                    - "m" to parse like for ":echo".
///                    - "E" to parse like for "<C-r>=".
///                    - empty string for ":call".
///                    - "lm" to parse for ":let".
/// @param[in]  highlight  If true, return value will also include "highlight"
///                        key containing array of 4-tuples (arrays) (Integer,
///                        Integer, Integer, String), where first three numbers
///                        define the highlighted region and represent line,
///                        starting column and ending column (latter exclusive:
///                        one should highlight region [start_col, end_col)).
///
/// @return AST: top-level dictionary with these keys:
///
///         "error": Dictionary with error, present only if parser saw some
///                  error. Contains the following keys:
///
///           "message": String, error message in printf format, translated.
///                      Must contain exactly one "%.*s".
///           "arg": String, error message argument.
///
///         "len": Amount of bytes successfully parsed. With flags equal to ""
///                that should be equal to the length of expr string.
///
///                @note: “Sucessfully parsed” here means “participated in AST
///                       creation”, not “till the first error”.
///
///         "ast": AST, either nil or a dictionary with these keys:
///
///           "type": node type, one of the value names from ExprASTNodeType
///                   stringified without "kExprNode" prefix.
///           "start": a pair [line, column] describing where node is “started”
///                    where "line" is always 0 (will not be 0 if you will be
///                    using nvim_parse_viml() on e.g. ":let", but that is not
///                    present yet). Both elements are Integers.
///           "len": “length” of the node. This and "start" are there for
///                  debugging purposes primary (debugging parser and providing
///                  debug information).
///           "children": a list of nodes described in top/"ast". There always
///                       is zero, one or two children, key will not be present
///                       if node has no children. Maximum number of children
///                       may be found in node_maxchildren array.
///
///           Local values (present only for certain nodes):
///
///           "scope": a single Integer, specifies scope for "Option" and
///                    "PlainIdentifier" nodes. For "Option" it is one of
///                    ExprOptScope values, for "PlainIdentifier" it is one of
///                    ExprVarScope values.
///           "ident": identifier (without scope, if any), present for "Option",
///                    "PlainIdentifier", "PlainKey" and "Environment" nodes.
///           "name": Integer, register name (one character) or -1. Only present
///                   for "Register" nodes.
///           "cmp_type": String, comparison type, one of the value names from
///                       ExprComparisonType, stringified without "kExprCmp"
///                       prefix. Only present for "Comparison" nodes.
///           "ccs_strategy": String, case comparison strategy, one of the
///                           value names from ExprCaseCompareStrategy,
///                           stringified without "kCCStrategy" prefix. Only
///                           present for "Comparison" nodes.
///           "augmentation": String, augmentation type for "Assignment" nodes.
///                           Is either an empty string, "Add", "Subtract" or
///                           "Concat" for "=", "+=", "-=" or ".=" respectively.
///           "invert": Boolean, true if result of comparison needs to be
///                     inverted. Only present for "Comparison" nodes.
///           "ivalue": Integer, integer value for "Integer" nodes.
///           "fvalue": Float, floating-point value for "Float" nodes.
///           "svalue": String, value for "SingleQuotedString" and
///                     "DoubleQuotedString" nodes.
Dictionary nvim_parse_expression(String expr, String flags, Boolean highlight,
                                 Error *err)
  FUNC_API_SINCE(4) FUNC_API_ASYNC
{
  int pflags = 0;
  for (size_t i = 0 ; i < flags.size ; i++) {
    switch (flags.data[i]) {
      case 'm': { pflags |= kExprFlagsMulti; break; }
      case 'E': { pflags |= kExprFlagsDisallowEOC; break; }
      case 'l': { pflags |= kExprFlagsParseLet; break; }
      case NUL: {
        api_set_error(err, kErrorTypeValidation, "Invalid flag: '\\0' (%u)",
                      (unsigned)flags.data[i]);
        return (Dictionary)ARRAY_DICT_INIT;
      }
      default: {
        api_set_error(err, kErrorTypeValidation, "Invalid flag: '%c' (%u)",
                      flags.data[i], (unsigned)flags.data[i]);
        return (Dictionary)ARRAY_DICT_INIT;
      }
    }
  }
  ParserLine plines[] = {
    {
      .data = expr.data,
      .size = expr.size,
      .allocated = false,
    },
    { NULL, 0, false },
  };
  ParserLine *plines_p = plines;
  ParserHighlight colors;
  kvi_init(colors);
  ParserHighlight *const colors_p = (highlight ? &colors : NULL);
  ParserState pstate;
  viml_parser_init(
      &pstate, parser_simple_get_line, &plines_p, colors_p);
  ExprAST east = viml_pexpr_parse(&pstate, pflags);

  const size_t ret_size = (
      2  // "ast", "len"
      + (size_t)(east.err.msg != NULL)  // "error"
      + (size_t)highlight  // "highlight"
      + 0);
  Dictionary ret = {
    .items = xmalloc(ret_size * sizeof(ret.items[0])),
    .size = 0,
    .capacity = ret_size,
  };
  ret.items[ret.size++] = (KeyValuePair) {
    .key = STATIC_CSTR_TO_STRING("ast"),
    .value = NIL,
  };
  ret.items[ret.size++] = (KeyValuePair) {
    .key = STATIC_CSTR_TO_STRING("len"),
    .value = INTEGER_OBJ((Integer)(pstate.pos.line == 1
                                   ? plines[0].size
                                   : pstate.pos.col)),
  };
  if (east.err.msg != NULL) {
    Dictionary err_dict = {
      .items = xmalloc(2 * sizeof(err_dict.items[0])),
      .size = 2,
      .capacity = 2,
    };
    err_dict.items[0] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("message"),
      .value = STRING_OBJ(cstr_to_string(east.err.msg)),
    };
    if (east.err.arg == NULL) {
      err_dict.items[1] = (KeyValuePair) {
        .key = STATIC_CSTR_TO_STRING("arg"),
        .value = STRING_OBJ(STRING_INIT),
      };
    } else {
      err_dict.items[1] = (KeyValuePair) {
        .key = STATIC_CSTR_TO_STRING("arg"),
        .value = STRING_OBJ(((String) {
          .data = xmemdupz(east.err.arg, (size_t)east.err.arg_len),
          .size = (size_t)east.err.arg_len,
        })),
      };
    }
    ret.items[ret.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("error"),
      .value = DICTIONARY_OBJ(err_dict),
    };
  }
  if (highlight) {
    Array hl = (Array) {
      .items = xmalloc(kv_size(colors) * sizeof(hl.items[0])),
      .capacity = kv_size(colors),
      .size = kv_size(colors),
    };
    for (size_t i = 0 ; i < kv_size(colors) ; i++) {
      const ParserHighlightChunk chunk = kv_A(colors, i);
      Array chunk_arr = (Array) {
        .items = xmalloc(4 * sizeof(chunk_arr.items[0])),
        .capacity = 4,
        .size = 4,
      };
      chunk_arr.items[0] = INTEGER_OBJ((Integer)chunk.start.line);
      chunk_arr.items[1] = INTEGER_OBJ((Integer)chunk.start.col);
      chunk_arr.items[2] = INTEGER_OBJ((Integer)chunk.end_col);
      chunk_arr.items[3] = STRING_OBJ(cstr_to_string(chunk.group));
      hl.items[i] = ARRAY_OBJ(chunk_arr);
    }
    ret.items[ret.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("highlight"),
      .value = ARRAY_OBJ(hl),
    };
  }
  kvi_destroy(colors);

  // Walk over the AST, freeing nodes in process.
  ExprASTConvStack ast_conv_stack;
  kvi_init(ast_conv_stack);
  kvi_push(ast_conv_stack, ((ExprASTConvStackItem) {
    .node_p = &east.root,
    .ret_node_p = &ret.items[0].value,
  }));
  while (kv_size(ast_conv_stack)) {
    ExprASTConvStackItem cur_item = kv_last(ast_conv_stack);
    ExprASTNode *const node = *cur_item.node_p;
    if (node == NULL) {
      assert(kv_size(ast_conv_stack) == 1);
      kv_drop(ast_conv_stack, 1);
    } else {
      if (cur_item.ret_node_p->type == kObjectTypeNil) {
        const size_t ret_node_items_size = (size_t)(
            3  // "type", "start" and "len"
            + (node->children != NULL)  // "children"
            + (node->type == kExprNodeOption
               || node->type == kExprNodePlainIdentifier)  // "scope"
            + (node->type == kExprNodeOption
               || node->type == kExprNodePlainIdentifier
               || node->type == kExprNodePlainKey
               || node->type == kExprNodeEnvironment)  // "ident"
            + (node->type == kExprNodeRegister)  // "name"
            + (3  // "cmp_type", "ccs_strategy", "invert"
               * (node->type == kExprNodeComparison))
            + (node->type == kExprNodeInteger)  // "ivalue"
            + (node->type == kExprNodeFloat)  // "fvalue"
            + (node->type == kExprNodeDoubleQuotedString
               || node->type == kExprNodeSingleQuotedString)  // "svalue"
            + (node->type == kExprNodeAssignment)  // "augmentation"
            + 0);
        Dictionary ret_node = {
          .items = xmalloc(ret_node_items_size * sizeof(ret_node.items[0])),
          .capacity = ret_node_items_size,
          .size = 0,
        };
        *cur_item.ret_node_p = DICTIONARY_OBJ(ret_node);
      }
      Dictionary *ret_node = &cur_item.ret_node_p->data.dictionary;
      if (node->children != NULL) {
        const size_t num_children = 1 + (node->children->next != NULL);
        Array children_array = {
          .items = xmalloc(num_children * sizeof(children_array.items[0])),
          .capacity = num_children,
          .size = num_children,
        };
        for (size_t i = 0; i < num_children; i++) {
          children_array.items[i] = NIL;
        }
        ret_node->items[ret_node->size++] = (KeyValuePair) {
          .key = STATIC_CSTR_TO_STRING("children"),
          .value = ARRAY_OBJ(children_array),
        };
        kvi_push(ast_conv_stack, ((ExprASTConvStackItem) {
          .node_p = &node->children,
          .ret_node_p = &children_array.items[0],
        }));
      } else if (node->next != NULL) {
        kvi_push(ast_conv_stack, ((ExprASTConvStackItem) {
          .node_p = &node->next,
          .ret_node_p = cur_item.ret_node_p + 1,
        }));
      } else if (node != NULL) {
        kv_drop(ast_conv_stack, 1);
        ret_node->items[ret_node->size++] = (KeyValuePair) {
          .key = STATIC_CSTR_TO_STRING("type"),
          .value = STRING_OBJ(cstr_to_string(east_node_type_tab[node->type])),
        };
        Array start_array = {
          .items = xmalloc(2 * sizeof(start_array.items[0])),
          .capacity = 2,
          .size = 2,
        };
        start_array.items[0] = INTEGER_OBJ((Integer)node->start.line);
        start_array.items[1] = INTEGER_OBJ((Integer)node->start.col);
        ret_node->items[ret_node->size++] = (KeyValuePair) {
          .key = STATIC_CSTR_TO_STRING("start"),
          .value = ARRAY_OBJ(start_array),
        };
        ret_node->items[ret_node->size++] = (KeyValuePair) {
          .key = STATIC_CSTR_TO_STRING("len"),
          .value = INTEGER_OBJ((Integer)node->len),
        };
        switch (node->type) {
          case kExprNodeDoubleQuotedString:
          case kExprNodeSingleQuotedString: {
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("svalue"),
              .value = STRING_OBJ(((String) {
                .data = node->data.str.value,
                .size = node->data.str.size,
              })),
            };
            break;
          }
          case kExprNodeOption: {
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("scope"),
              .value = INTEGER_OBJ(node->data.opt.scope),
            };
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("ident"),
              .value = STRING_OBJ(((String) {
                .data = xmemdupz(node->data.opt.ident,
                                 node->data.opt.ident_len),
                .size = node->data.opt.ident_len,
              })),
            };
            break;
          }
          case kExprNodePlainIdentifier: {
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("scope"),
              .value = INTEGER_OBJ(node->data.var.scope),
            };
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("ident"),
              .value = STRING_OBJ(((String) {
                .data = xmemdupz(node->data.var.ident,
                                 node->data.var.ident_len),
                .size = node->data.var.ident_len,
              })),
            };
            break;
          }
          case kExprNodePlainKey: {
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("ident"),
              .value = STRING_OBJ(((String) {
                .data = xmemdupz(node->data.var.ident,
                                 node->data.var.ident_len),
                .size = node->data.var.ident_len,
              })),
            };
            break;
          }
          case kExprNodeEnvironment: {
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("ident"),
              .value = STRING_OBJ(((String) {
                .data = xmemdupz(node->data.env.ident,
                                 node->data.env.ident_len),
                .size = node->data.env.ident_len,
              })),
            };
            break;
          }
          case kExprNodeRegister: {
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("name"),
              .value = INTEGER_OBJ(node->data.reg.name),
            };
            break;
          }
          case kExprNodeComparison: {
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("cmp_type"),
              .value = STRING_OBJ(cstr_to_string(
                  eltkn_cmp_type_tab[node->data.cmp.type])),
            };
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("ccs_strategy"),
              .value = STRING_OBJ(cstr_to_string(
                  ccs_tab[node->data.cmp.ccs])),
            };
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("invert"),
              .value = BOOLEAN_OBJ(node->data.cmp.inv),
            };
            break;
          }
          case kExprNodeFloat: {
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("fvalue"),
              .value = FLOAT_OBJ(node->data.flt.value),
            };
            break;
          }
          case kExprNodeInteger: {
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("ivalue"),
              .value = INTEGER_OBJ((Integer)(
                  node->data.num.value > API_INTEGER_MAX
                  ? API_INTEGER_MAX
                  : (Integer)node->data.num.value)),
            };
            break;
          }
          case kExprNodeAssignment: {
            const ExprAssignmentType asgn_type = node->data.ass.type;
            ret_node->items[ret_node->size++] = (KeyValuePair) {
              .key = STATIC_CSTR_TO_STRING("augmentation"),
              .value = STRING_OBJ(
                  asgn_type == kExprAsgnPlain
                  ? (String)STRING_INIT
                  : cstr_to_string(expr_asgn_type_tab[asgn_type])),
            };
            break;
          }
          case kExprNodeMissing:
          case kExprNodeOpMissing:
          case kExprNodeTernary:
          case kExprNodeTernaryValue:
          case kExprNodeSubscript:
          case kExprNodeListLiteral:
          case kExprNodeUnaryPlus:
          case kExprNodeBinaryPlus:
          case kExprNodeNested:
          case kExprNodeCall:
          case kExprNodeComplexIdentifier:
          case kExprNodeUnknownFigure:
          case kExprNodeLambda:
          case kExprNodeDictLiteral:
          case kExprNodeCurlyBracesIdentifier:
          case kExprNodeComma:
          case kExprNodeColon:
          case kExprNodeArrow:
          case kExprNodeConcat:
          case kExprNodeConcatOrSubscript:
          case kExprNodeOr:
          case kExprNodeAnd:
          case kExprNodeUnaryMinus:
          case kExprNodeBinaryMinus:
          case kExprNodeNot:
          case kExprNodeMultiplication:
          case kExprNodeDivision:
          case kExprNodeMod: {
            break;
          }
        }
        assert(cur_item.ret_node_p->data.dictionary.size
               == cur_item.ret_node_p->data.dictionary.capacity);
        xfree(*cur_item.node_p);
        *cur_item.node_p = NULL;
      }
    }
  }
  kvi_destroy(ast_conv_stack);

  assert(ret.size == ret.capacity);
  // Should be a no-op actually, leaving it in case non-nodes will need to be
  // freed later.
  viml_pexpr_free_ast(east);
  viml_parser_destroy(&pstate);
  return ret;
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
    msg((char_u *)line_buf); \
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

// Functions used for testing purposes

/// Returns object given as argument
///
/// This API function is used for testing. One should not rely on its presence
/// in plugins.
///
/// @param[in]  obj  Object to return.
///
/// @return its argument.
Object nvim__id(Object obj)
{
  return copy_object(obj);
}

/// Returns array given as argument
///
/// This API function is used for testing. One should not rely on its presence
/// in plugins.
///
/// @param[in]  arr  Array to return.
///
/// @return its argument.
Array nvim__id_array(Array arr)
{
  return copy_object(ARRAY_OBJ(arr)).data.array;
}

/// Returns dictionary given as argument
///
/// This API function is used for testing. One should not rely on its presence
/// in plugins.
///
/// @param[in]  dct  Dictionary to return.
///
/// @return its argument.
Dictionary nvim__id_dictionary(Dictionary dct)
{
  return copy_object(DICTIONARY_OBJ(dct)).data.dictionary;
}

/// Returns floating-point value given as argument
///
/// This API function is used for testing. One should not rely on its presence
/// in plugins.
///
/// @param[in]  flt  Value to return.
///
/// @return its argument.
Float nvim__id_float(Float flt)
{
  return flt;
}

/// Gets a list of dictionaries representing attached UIs.
///
/// @return Array of UI dictionaries
Array nvim_list_uis(void)
  FUNC_API_SINCE(4)
{
  return ui_array();
}

/// Gets the immediate children of process `pid`.
///
/// @return Array of child process ids, empty if process not found.
Array nvim_get_proc_children(Integer pid, Error *err)
  FUNC_API_SINCE(4)
{
  Array rvobj = ARRAY_DICT_INIT;
  int *proc_list = NULL;

  if (pid <= 0 || pid > INT_MAX) {
    api_set_error(err, kErrorTypeException, "Invalid pid: %" PRId64, pid);
    goto end;
  }

  size_t proc_count;
  int rv = os_proc_children((int)pid, &proc_list, &proc_count);
  if (rv != 0) {
    // syscall failed (possibly because of kernel options), try shelling out.
    DLOG("fallback to vim._os_proc_children()");
    Array a = ARRAY_DICT_INIT;
    ADD(a, INTEGER_OBJ(pid));
    String s = cstr_to_string("return vim._os_proc_children(select(1, ...))");
    Object o = nvim_execute_lua(s, a, err);
    api_free_string(s);
    api_free_array(a);
    if (o.type == kObjectTypeArray) {
      rvobj = o.data.array;
    } else if (!ERROR_SET(err)) {
      api_set_error(err, kErrorTypeException,
                    "Failed to get process children. pid=%" PRId64 " error=%d",
                    pid, rv);
    }
    goto end;
  }

  for (size_t i = 0; i < proc_count; i++) {
    ADD(rvobj, INTEGER_OBJ(proc_list[i]));
  }

end:
  xfree(proc_list);
  return rvobj;
}

/// Gets info describing process `pid`.
///
/// @return Map of process properties, or NIL if process not found.
Object nvim_get_proc(Integer pid, Error *err)
  FUNC_API_SINCE(4)
{
  Object rvobj = OBJECT_INIT;
  rvobj.data.dictionary = (Dictionary)ARRAY_DICT_INIT;
  rvobj.type = kObjectTypeDictionary;

  if (pid <= 0 || pid > INT_MAX) {
    api_set_error(err, kErrorTypeException, "Invalid pid: %" PRId64, pid);
    return NIL;
  }
#ifdef WIN32
  rvobj.data.dictionary = os_proc_info((int)pid);
  if (rvobj.data.dictionary.size == 0) {  // Process not found.
    return NIL;
  }
#else
  // Cross-platform process info APIs are miserable, so use `ps` instead.
  Array a = ARRAY_DICT_INIT;
  ADD(a, INTEGER_OBJ(pid));
  String s = cstr_to_string("return vim._os_proc_info(select(1, ...))");
  Object o = nvim_execute_lua(s, a, err);
  api_free_string(s);
  api_free_array(a);
  if (o.type == kObjectTypeArray && o.data.array.size == 0) {
    return NIL;  // Process not found.
  } else if (o.type == kObjectTypeDictionary) {
    rvobj.data.dictionary = o.data.dictionary;
  } else if (!ERROR_SET(err)) {
    api_set_error(err, kErrorTypeException,
                  "Failed to get process info. pid=%" PRId64, pid);
  }
#endif
  return rvobj;
}
