// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
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
#include "nvim/api/window.h"
#include "nvim/api/deprecated.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/lua/executor.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/context.h"
#include "nvim/file_search.h"
#include "nvim/highlight.h"
#include "nvim/window.h"
#include "nvim/types.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/screen.h"
#include "nvim/memline.h"
#include "nvim/mark.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/popupmnu.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/fileio.h"
#include "nvim/move.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/state.h"
#include "nvim/decoration.h"
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

void api_vim_init(void)
  FUNC_API_NOEXPORT
{
  namespace_ids = map_new(String, handle_T)();
}

void api_vim_free_all_mem(void)
  FUNC_API_NOEXPORT
{
  String name;
  handle_T id;
  map_foreach(namespace_ids, name, id, {
    (void)id;
    xfree(name.data);
  })
  map_free(String, handle_T)(namespace_ids);
}

/// Executes Vimscript (multiline block of Ex-commands), like anonymous
/// |:source|.
///
/// Unlike |nvim_command()| this function supports heredocs, script-scope (s:),
/// etc.
///
/// On execution error: fails with VimL error, does not update v:errmsg.
///
/// @see |execute()|
/// @see |nvim_command()|
///
/// @param src      Vimscript code
/// @param output   Capture and return all (non-error, non-shell |:!|) output
/// @param[out] err Error details (Vim error), if any
/// @return Output (non-error, non-shell |:!|) if `output` is true,
///         else empty string.
String nvim_exec(String src, Boolean output, Error *err)
  FUNC_API_SINCE(7)
{
  const int save_msg_silent = msg_silent;
  garray_T *const save_capture_ga = capture_ga;
  garray_T capture_local;
  if (output) {
    ga_init(&capture_local, 1, 80);
    capture_ga = &capture_local;
  }

  try_start();
  if (output) {
    msg_silent++;
  }
  do_source_str(src.data, "nvim_exec()");
  if (output) {
    capture_ga = save_capture_ga;
    msg_silent = save_msg_silent;
  }
  try_end(err);

  if (ERROR_SET(err)) {
    goto theend;
  }

  if (output && capture_local.ga_len > 1) {
    String s = (String){
      .data = capture_local.ga_data,
      .size = (size_t)capture_local.ga_len,
    };
    // redir usually (except :echon) prepends a newline.
    if (s.data[0] == '\n') {
      memmove(s.data, s.data + 1, s.size - 1);
      s.data[s.size - 1] = '\0';
      s.size = s.size - 1;
    }
    return s;  // Caller will free the memory.
  }
theend:
  if (output) {
    ga_clear(&capture_local);
  }
  return (String)STRING_INIT;
}

/// Executes an ex-command.
///
/// On execution error: fails with VimL error, does not update v:errmsg.
///
/// @see |nvim_exec()|
///
/// @param command  Ex-command string
/// @param[out] err Error details (Vim error), if any
void nvim_command(String command, Error *err)
  FUNC_API_SINCE(1)
{
  try_start();
  do_cmdline_cmd(command.data);
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

/// Gets a highlight group by name
///
/// similar to |hlID()|, but allocates a new ID if not present.
Integer nvim_get_hl_id_by_name(String name)
  FUNC_API_SINCE(7)
{
  return syn_check_group((const char_u *)name.data, (int)name.size);
}

Dictionary nvim__get_hl_defs(Integer ns_id, Error *err)
{
  if (ns_id == 0) {
    return get_global_hl_defs();
  }
  abort();
}

/// Set a highlight group.
///
/// @param ns_id number of namespace for this highlight
/// @param name highlight group name, like ErrorMsg
/// @param val highlight definition map, like |nvim_get_hl_by_name|.
///            in addition the following keys are also recognized:
///              `default`: don't override existing definition,
///                         like `hi default`
///              `ctermfg`: sets foreground of cterm color
///              `ctermbg`: sets background of cterm color
///              `cterm`  : cterm attribute map. sets attributed for
///                         cterm colors. similer to `hi cterm`
///                         Note: by default cterm attributes are
///                               same as attributes of gui color
/// @param[out] err Error details, if any
///
/// TODO: ns_id = 0, should modify :highlight namespace
/// TODO val should take update vs reset flag
void nvim_set_hl(Integer ns_id, String name, Dictionary val, Error *err)
  FUNC_API_SINCE(7)
{
  int hl_id = syn_check_group( (char_u *)(name.data), (int)name.size);
  int link_id = -1;

  HlAttrs attrs = dict2hlattrs(val, true, &link_id, err);
  if (!ERROR_SET(err)) {
    ns_hl_def((NS)ns_id, hl_id, attrs, link_id);
  }
}

/// Set active namespace for highlights.
///
/// NB: this function can be called from async contexts, but the
/// semantics are not yet well-defined. To start with
/// |nvim_set_decoration_provider| on_win and on_line callbacks
/// are explicitly allowed to change the namespace during a redraw cycle.
///
/// @param ns_id the namespace to activate
/// @param[out] err Error details, if any
void nvim__set_hl_ns(Integer ns_id, Error *err)
  FUNC_API_FAST
{
  if (ns_id >= 0) {
    ns_hl_active = (NS)ns_id;
  }

  // TODO(bfredl): this is a little bit hackish.  Eventually we want a standard
  // event path for redraws caused by "fast" events. This could tie in with
  // better throttling of async events causing redraws, such as non-batched
  // nvim_buf_set_extmark calls from async contexts.
  if (!provider_active && !ns_hl_changed) {
    multiqueue_put(main_loop.events, on_redraw_event, 0);
  }
  ns_hl_changed = true;
}

static void on_redraw_event(void **argv)
  FUNC_API_NOEXPORT
{
  redraw_all_later(NOT_VALID);
}


/// Sends input-keys to Nvim, subject to various quirks controlled by `mode`
/// flags. This is a blocking call, unlike |nvim_input()|.
///
/// On execution error: does not fail, but updates v:errmsg.
///
/// If you need to input sequences like <C-o> use |nvim_replace_termcodes| to
/// replace the termcodes and then pass the resulting string to nvim_feedkeys.
/// You'll also want to enable escape_csi.
///
/// Example:
/// <pre>
///     :let key = nvim_replace_termcodes("<C-o>", v:true, v:false, v:true)
///     :call nvim_feedkeys(key, 'n', v:true)
/// </pre>
///
/// @param keys         to be typed
/// @param mode         behavior flags, see |feedkeys()|
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
  if (vgetc_busy) {
    typebuf_was_filled = true;
  }

  if (escape_csi) {
      xfree(keys_esc);
  }

  if (execute) {
    int save_msg_scroll = msg_scroll;

    // Avoid a 1 second delay when the keys start Insert mode.
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

/// Queues raw user-input. Unlike |nvim_feedkeys()|, this uses a low-level
/// input buffer and the call is non-blocking (input is processed
/// asynchronously by the eventloop).
///
/// On execution error: does not fail, but updates v:errmsg.
///
/// @note |keycodes| like <CR> are translated, so "<" is special.
///       To input a literal "<", send <LT>.
///
/// @note For mouse events use |nvim_input_mouse()|. The pseudokey form
///       "<LeftMouse><col,row>" is deprecated since |api-level| 6.
///
/// @param keys to be typed
/// @return Number of bytes actually written (can be fewer than
///         requested if the buffer becomes full).
Integer nvim_input(String keys)
  FUNC_API_SINCE(1) FUNC_API_FAST
{
  return (Integer)input_enqueue(keys);
}

/// Send mouse event from GUI.
///
/// Non-blocking: does not wait on any result, but queues the event to be
/// processed soon by the event loop.
///
/// @note Currently this doesn't support "scripting" multiple mouse events
///       by calling it multiple times in a loop: the intermediate mouse
///       positions will be ignored. It should be used to implement real-time
///       mouse input in a GUI. The deprecated pseudokey form
///       ("<LeftMouse><col,row>") of |nvim_input()| has the same limitation.
///
/// @param button Mouse button: one of "left", "right", "middle", "wheel".
/// @param action For ordinary buttons, one of "press", "drag", "release".
///               For the wheel, one of "up", "down", "left", "right".
/// @param modifier String of modifiers each represented by a single char.
///                 The same specifiers are used as for a key press, except
///                 that the "-" separator is optional, so "C-A-", "c-a"
///                 and "CA" can all be used to specify Ctrl+Alt+click.
/// @param grid Grid number if the client uses |ui-multigrid|, else 0.
/// @param row Mouse row-position (zero-based, like redraw events)
/// @param col Mouse column-position (zero-based, like redraw events)
/// @param[out] err Error details, if any
void nvim_input_mouse(String button, String action, String modifier,
                      Integer grid, Integer row, Integer col, Error *err)
  FUNC_API_SINCE(6) FUNC_API_FAST
{
  if (button.data == NULL || action.data == NULL) {
    goto error;
  }

  int code = 0;

  if (strequal(button.data, "left")) {
    code = KE_LEFTMOUSE;
  } else if (strequal(button.data, "middle")) {
    code = KE_MIDDLEMOUSE;
  } else if (strequal(button.data, "right")) {
    code = KE_RIGHTMOUSE;
  } else if (strequal(button.data, "wheel")) {
    code = KE_MOUSEDOWN;
  } else {
    goto error;
  }

  if (code == KE_MOUSEDOWN) {
    if (strequal(action.data, "down")) {
      code = KE_MOUSEUP;
    } else if (strequal(action.data, "up")) {
      // code = KE_MOUSEDOWN
    } else if (strequal(action.data, "left")) {
      code = KE_MOUSERIGHT;
    } else if (strequal(action.data, "right")) {
      code = KE_MOUSELEFT;
    } else {
      goto error;
    }
  } else {
    if (strequal(action.data, "press")) {
      // pass
    } else if (strequal(action.data, "drag")) {
      code += KE_LEFTDRAG - KE_LEFTMOUSE;
    } else if (strequal(action.data, "release")) {
      code += KE_LEFTRELEASE - KE_LEFTMOUSE;
    } else {
      goto error;
    }
  }

  int modmask = 0;
  for (size_t i = 0; i < modifier.size; i++) {
    char byte = modifier.data[i];
    if (byte == '-') {
      continue;
    }
    int mod = name_to_mod_mask(byte);
    if (mod == 0) {
      api_set_error(err, kErrorTypeValidation,
                    "invalid modifier %c", byte);
      return;
    }
    modmask |= mod;
  }

  input_enqueue_mouse(code, (uint8_t)modmask, (int)grid, (int)row, (int)col);
  return;

error:
  api_set_error(err, kErrorTypeValidation,
                "invalid button or action");
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

/// Evaluates a VimL |expression|.
/// Dictionaries and Lists are recursively expanded.
///
/// On execution error: fails with VimL error, does not update v:errmsg.
///
/// @param expr     VimL expression string
/// @param[out] err Error details, if any
/// @return         Evaluation result or expanded object
Object nvim_eval(String expr, Error *err)
  FUNC_API_SINCE(1)
{
  static int recursive = 0;  // recursion depth
  Object rv = OBJECT_INIT;

  TRY_WRAP({
  // Initialize `force_abort`  and `suppress_errthrow` at the top level.
  if (!recursive) {
    force_abort = false;
    suppress_errthrow = false;
    current_exception = NULL;
    // `did_emsg` is set by emsg(), which cancels execution.
    did_emsg = false;
  }
  recursive++;
  try_start();

  typval_T rettv;
  int ok = eval0((char_u *)expr.data, &rettv, NULL, true);

  if (!try_end(err)) {
    if (ok == FAIL) {
      // Should never happen, try_end() should get the error. #8371
      api_set_error(err, kErrorTypeException,
                    "Failed to evaluate expression: '%.*s'", 256, expr.data);
    } else {
      rv = vim_to_object(&rettv);
    }
  }

  tv_clear(&rettv);
  recursive--;
  });

  return rv;
}

/// Execute Lua code. Parameters (if any) are available as `...` inside the
/// chunk. The chunk can return a value.
///
/// Only statements are executed. To evaluate an expression, prefix it
/// with `return`: return my_function(...)
///
/// @param code       Lua code to execute
/// @param args       Arguments to the code
/// @param[out] err   Details of an error encountered while parsing
///                   or executing the Lua code.
///
/// @return           Return value of Lua code if present or NIL.
Object nvim_exec_lua(String code, Array args, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_REMOTE_ONLY
{
  return nlua_exec(code, args, err);
}

/// Notify the user with a message
///
/// Relays the call to vim.notify . By default forwards your message in the
/// echo area but can be overridden to trigger desktop notifications.
///
/// @param msg        Message to display to the user
/// @param log_level  The log level
/// @param opts       Reserved for future use.
/// @param[out] err   Error details, if any
Object nvim_notify(String msg, Integer log_level, Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
{
  FIXED_TEMP_ARRAY(args, 3);
  args.items[0] = STRING_OBJ(msg);
  args.items[1] = INTEGER_OBJ(log_level);
  args.items[2] = DICTIONARY_OBJ(opts);

  return nlua_exec(STATIC_CSTR_AS_STRING("return vim.notify(...)"), args, err);
}

/// Calls a VimL function.
///
/// @param fn Function name
/// @param args Function arguments
/// @param self `self` dict, or NULL for non-dict functions
/// @param[out] err Error details, if any
/// @return Result of the function call
static Object _call_function(String fn, Array args, dict_T *self, Error *err)
{
  static int recursive = 0;  // recursion depth
  Object rv = OBJECT_INIT;

  if (args.size > MAX_FUNC_ARGS) {
    api_set_error(err, kErrorTypeValidation,
                  "Function called with too many arguments");
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

  TRY_WRAP({
  // Initialize `force_abort`  and `suppress_errthrow` at the top level.
  if (!recursive) {
    force_abort = false;
    suppress_errthrow = false;
    current_exception = NULL;
    // `did_emsg` is set by emsg(), which cancels execution.
    did_emsg = false;
  }
  recursive++;
  try_start();
  typval_T rettv;
  int dummy;
  // call_func() retval is deceptive, ignore it.  Instead we set `msg_list`
  // (see above) to capture abort-causing non-exception errors.
  (void)call_func((char_u *)fn.data, (int)fn.size, &rettv, (int)args.size,
                  vim_args, NULL, curwin->w_cursor.lnum, curwin->w_cursor.lnum,
                  &dummy, true, NULL, self);
  if (!try_end(err)) {
    rv = vim_to_object(&rettv);
  }
  tv_clear(&rettv);
  recursive--;
  });

free_vim_args:
  while (i > 0) {
    tv_clear(&vim_args[--i]);
  }

  return rv;
}

/// Calls a VimL function with the given arguments.
///
/// On execution error: fails with VimL error, does not update v:errmsg.
///
/// @param fn       Function to call
/// @param args     Function arguments packed in an Array
/// @param[out] err Error details, if any
/// @return Result of the function call
Object nvim_call_function(String fn, Array args, Error *err)
  FUNC_API_SINCE(1)
{
  return _call_function(fn, args, NULL, err);
}

/// Calls a VimL |Dictionary-function| with the given arguments.
///
/// On execution error: fails with VimL error, does not update v:errmsg.
///
/// @param dict Dictionary, or String evaluating to a VimL |self| dict
/// @param fn Name of the function defined on the VimL dict
/// @param args Function arguments packed in an Array
/// @param[out] err Error details, if any
/// @return Result of the function call
Object nvim_call_dict_function(Object dict, String fn, Array args, Error *err)
  FUNC_API_SINCE(4)
{
  Object rv = OBJECT_INIT;

  typval_T rettv;
  bool mustfree = false;
  switch (dict.type) {
    case kObjectTypeString: {
      try_start();
      if (eval0((char_u *)dict.data.string.data, &rettv, NULL, true) == FAIL) {
        api_set_error(err, kErrorTypeException,
                      "Failed to evaluate dict expression");
      }
      if (try_end(err)) {
        return rv;
      }
      // Evaluation of the string arg created a new dict or increased the
      // refcount of a dict. Not necessary for a RPC dict.
      mustfree = true;
      break;
    }
    case kObjectTypeDictionary: {
      if (!object_to_vim(dict, &rettv, err)) {
        goto end;
      }
      break;
    }
    default: {
      api_set_error(err, kErrorTypeValidation,
                    "dict argument type must be String or Dictionary");
      return rv;
    }
  }
  dict_T *self_dict = rettv.vval.v_dict;
  if (rettv.v_type != VAR_DICT || !self_dict) {
    api_set_error(err, kErrorTypeValidation, "dict not found");
    goto end;
  }

  if (fn.data && fn.size > 0 && dict.type != kObjectTypeDictionary) {
    dictitem_T *const di = tv_dict_find(self_dict, fn.data, (ptrdiff_t)fn.size);
    if (di == NULL) {
      api_set_error(err, kErrorTypeValidation, "Not found: %s", fn.data);
      goto end;
    }
    if (di->di_tv.v_type == VAR_PARTIAL) {
      api_set_error(err, kErrorTypeValidation,
                    "partial function not supported");
      goto end;
    }
    if (di->di_tv.v_type != VAR_FUNC) {
      api_set_error(err, kErrorTypeValidation, "Not a function: %s", fn.data);
      goto end;
    }
    fn = (String) {
      .data = (char *)di->di_tv.vval.v_string,
      .size = strlen((char *)di->di_tv.vval.v_string),
    };
  }

  if (!fn.data || fn.size < 1) {
    api_set_error(err, kErrorTypeValidation, "Invalid (empty) function name");
    goto end;
  }

  rv = _call_function(fn, args, self_dict, err);
end:
  if (mustfree) {
    tv_clear(&rettv);
  }

  return rv;
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
    api_set_error(err, kErrorTypeValidation, "String is too long");
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
  // TODO(bfredl): this should just work:
  // return nvim_get_runtime_file(NULL_STRING, true);

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

/// Find files in runtime directories
///
/// 'name' can contain wildcards. For example
/// nvim_get_runtime_file("colors/*.vim", true) will return all color
/// scheme files. Always use forward slashes (/) in the search pattern for
/// subdirectories regardless of platform.
///
/// It is not an error to not find any files. An empty array is returned then.
///
/// To find a directory, `name` must end with a forward slash, like
/// "rplugin/python/". Without the slash it would instead look for an ordinary
/// file called "rplugin/python".
///
/// @param name pattern of files to search for
/// @param all whether to return all matches or only the first
/// @return list of absolute paths to the found files
ArrayOf(String) nvim_get_runtime_file(String name, Boolean all, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_FAST
{
  Array rv = ARRAY_DICT_INIT;

  int flags = DIP_START | (all ? DIP_ALL : 0);

  if (name.size == 0 || name.data[name.size-1] == '/') {
    flags |= DIP_DIR;
  }

  do_in_runtimepath((char_u *)(name.size ? name.data : ""),
                    flags, find_runtime_cb, &rv);
  return rv;
}

static void find_runtime_cb(char_u *fname, void *cookie)
{
  Array *rv = (Array *)cookie;
  if (fname != NULL) {
    ADD(*rv, STRING_OBJ(cstr_to_string((char *)fname)));
  }
}

String nvim__get_lib_dir(void)
{
  return cstr_as_string(get_lib_dir());
}

/// Changes the global working directory.
///
/// @param dir      Directory path
/// @param[out] err Error details, if any
void nvim_set_current_dir(String dir, Error *err)
  FUNC_API_SINCE(1)
{
  if (dir.size >= MAXPATHL) {
    api_set_error(err, kErrorTypeValidation, "Directory name is too long");
    return;
  }

  char string[MAXPATHL];
  memcpy(string, dir.data, dir.size);
  string[dir.size] = NUL;

  try_start();

  if (vim_chdir((char_u *)string)) {
    if (!try_end(err)) {
      api_set_error(err, kErrorTypeException, "Failed to change directory");
    }
    return;
  }

  post_chdir(kCdScopeGlobal, true);
  try_end(err);
}

/// Gets the current line.
///
/// @param[out] err Error details, if any
/// @return Current line string
String nvim_get_current_line(Error *err)
  FUNC_API_SINCE(1)
{
  return buffer_get_line(curbuf->handle, curwin->w_cursor.lnum - 1, err);
}

/// Sets the current line.
///
/// @param line     Line contents
/// @param[out] err Error details, if any
void nvim_set_current_line(String line, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_CHECK_TEXTLOCK
{
  buffer_set_line(curbuf->handle, curwin->w_cursor.lnum - 1, line, err);
}

/// Deletes the current line.
///
/// @param[out] err Error details, if any
void nvim_del_current_line(Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_CHECK_TEXTLOCK
{
  buffer_del_line(curbuf->handle, curwin->w_cursor.lnum - 1, err);
}

/// Gets a global (g:) variable.
///
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_get_var(String name, Error *err)
  FUNC_API_SINCE(1)
{
  return dict_get_value(&globvardict, name, err);
}

/// Sets a global (g:) variable.
///
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_set_var(String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  dict_set_var(&globvardict, name, value, false, false, err);
}

/// Removes a global (g:) variable.
///
/// @param name     Variable name
/// @param[out] err Error details, if any
void nvim_del_var(String name, Error *err)
  FUNC_API_SINCE(1)
{
  dict_set_var(&globvardict, name, NIL, true, false, err);
}

/// Gets a v: variable.
///
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return         Variable value
Object nvim_get_vvar(String name, Error *err)
  FUNC_API_SINCE(1)
{
  return dict_get_value(&vimvardict, name, err);
}

/// Sets a v: variable, if it is not readonly.
///
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_set_vvar(String name, Object value, Error *err)
  FUNC_API_SINCE(6)
{
  dict_set_var(&vimvardict, name, value, false, false, err);
}

/// Gets an option value string.
///
/// @param name     Option name
/// @param[out] err Error details, if any
/// @return         Option value (global)
Object nvim_get_option(String name, Error *err)
  FUNC_API_SINCE(1)
{
  return get_option_from(NULL, SREQ_GLOBAL, name, err);
}

/// Gets the option information for all options.
///
/// The dictionary has the full option names as keys and option metadata
/// dictionaries as detailed at |nvim_get_option_info|.
///
/// @return dictionary of all options
Dictionary nvim_get_all_options_info(Error *err)
  FUNC_API_SINCE(7)
{
  return get_all_vimoptions();
}

/// Gets the option information for one option
///
/// Resulting dictionary has keys:
///     - name: Name of the option (like 'filetype')
///     - shortname: Shortened name of the option (like 'ft')
///     - type: type of option ("string", "number" or "boolean")
///     - default: The default value for the option
///     - was_set: Whether the option was set.
///
///     - last_set_sid: Last set script id (if any)
///     - last_set_linenr: line number where option was set
///     - last_set_chan: Channel where option was set (0 for local)
///
///     - scope: one of "global", "win", or "buf"
///     - global_local: whether win or buf option has a global value
///
///     - commalist: List of comma separated values
///     - flaglist: List of single char flags
///
///
/// @param          name Option name
/// @param[out] err Error details, if any
/// @return         Option Information
Dictionary nvim_get_option_info(String name, Error *err)
  FUNC_API_SINCE(7)
{
  return get_vimoption(name, err);
}

/// Sets an option value.
///
/// @param channel_id
/// @param name     Option name
/// @param value    New option value
/// @param[out] err Error details, if any
void nvim_set_option(uint64_t channel_id, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  set_option_to(channel_id, NULL, SREQ_GLOBAL, name, value, err);
}

/// Echo a message.
///
/// @param chunks  A list of [text, hl_group] arrays, each representing a
///                text chunk with specified highlight. `hl_group` element
///                can be omitted for no highlight.
/// @param history  if true, add to |message-history|.
/// @param opts  Optional parameters. Reserved for future use.
void nvim_echo(Array chunks, Boolean history, Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
{
  HlMessage hl_msg = parse_hl_msg(chunks, err);
  if (ERROR_SET(err)) {
    goto error;
  }

  if (opts.size > 0) {
    api_set_error(err, kErrorTypeValidation, "opts dict isn't empty");
    goto error;
  }

  no_wait_return++;
  msg_start();
  msg_clr_eos();
  bool need_clear = false;
  for (uint32_t i = 0; i < kv_size(hl_msg); i++) {
    HlMessageChunk chunk = kv_A(hl_msg, i);
    msg_multiline_attr((const char *)chunk.text.data, chunk.attr,
                       false, &need_clear);
  }
  if (history) {
    msg_ext_set_kind("echomsg");
    add_hl_msg_hist(hl_msg);
  } else {
    msg_ext_set_kind("echo");
  }
  no_wait_return--;
  msg_end();

error:
  clear_hl_msg(&hl_msg);
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
/// Includes unlisted (unloaded/deleted) buffers, like `:ls!`.
/// Use |nvim_buf_is_loaded()| to check if a buffer is loaded.
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

/// Gets the current buffer.
///
/// @return Buffer handle
Buffer nvim_get_current_buf(void)
  FUNC_API_SINCE(1)
{
  return curbuf->handle;
}

/// Sets the current buffer.
///
/// @param buffer   Buffer handle
/// @param[out] err Error details, if any
void nvim_set_current_buf(Buffer buffer, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_CHECK_TEXTLOCK
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

/// Gets the current list of window handles.
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

/// Gets the current window.
///
/// @return Window handle
Window nvim_get_current_win(void)
  FUNC_API_SINCE(1)
{
  return curwin->handle;
}

/// Sets the current window.
///
/// @param window Window handle
/// @param[out] err Error details, if any
void nvim_set_current_win(Window window, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_CHECK_TEXTLOCK
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

/// Creates a new, empty, unnamed buffer.
///
/// @param listed Sets 'buflisted'
/// @param scratch Creates a "throwaway" |scratch-buffer| for temporary work
///                (always 'nomodified'). Also sets 'nomodeline' on the buffer.
/// @param[out] err Error details, if any
/// @return Buffer handle, or 0 on error
///
/// @see buf_open_scratch
Buffer nvim_create_buf(Boolean listed, Boolean scratch, Error *err)
  FUNC_API_SINCE(6)
{
  try_start();
  buf_T *buf = buflist_new(NULL, NULL, (linenr_T)0,
                           BLN_NOOPT | BLN_NEW | (listed ? BLN_LISTED : 0));
  try_end(err);
  if (buf == NULL) {
    goto fail;
  }

  // Open the memline for the buffer. This will avoid spurious autocmds when
  // a later nvim_buf_set_lines call would have needed to "open" the buffer.
  try_start();
  block_autocmds();
  int status = ml_open(buf);
  unblock_autocmds();
  try_end(err);
  if (status == FAIL) {
    goto fail;
  }

  if (scratch) {
    aco_save_T aco;
    aucmd_prepbuf(&aco, buf);
    set_option_value("bufhidden", 0L, "hide", OPT_LOCAL);
    set_option_value("buftype", 0L, "nofile", OPT_LOCAL);
    set_option_value("swapfile", 0L, NULL, OPT_LOCAL);
    set_option_value("modeline", 0L, NULL, OPT_LOCAL);  // 'nomodeline'
    aucmd_restbuf(&aco);
  }
  return buf->b_fnum;

fail:
  if (!ERROR_SET(err)) {
    api_set_error(err, kErrorTypeException, "Failed to create buffer");
  }
  return 0;
}

/// Open a terminal instance in a buffer
///
/// By default (and currently the only option) the terminal will not be
/// connected to an external process. Instead, input send on the channel
/// will be echoed directly by the terminal. This is useful to display
/// ANSI terminal sequences returned as part of a rpc message, or similar.
///
/// Note: to directly initiate the terminal using the right size, display the
/// buffer in a configured window before calling this. For instance, for a
/// floating display, first create an empty buffer using |nvim_create_buf()|,
/// then display it using |nvim_open_win()|, and then  call this function.
/// Then |nvim_chan_send()| cal be called immediately to process sequences
/// in a virtual terminal having the intended size.
///
/// @param buffer the buffer to use (expected to be empty)
/// @param opts   Optional parameters. Reserved for future use.
/// @param[out] err Error details, if any
/// @return Channel id, or 0 on error
Integer nvim_open_term(Buffer buffer, Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }

  if (opts.size > 0) {
    api_set_error(err, kErrorTypeValidation, "opts dict isn't empty");
    return 0;
  }

  TerminalOptions topts;
  Channel *chan = channel_alloc(kChannelStreamInternal);
  topts.data = chan;
  // NB: overridden in terminal_check_size if a window is already
  // displaying the buffer
  topts.width = (uint16_t)MAX(curwin->w_width_inner - win_col_off(curwin), 0);
  topts.height = (uint16_t)curwin->w_height_inner;
  topts.write_cb = term_write;
  topts.resize_cb = term_resize;
  topts.close_cb = term_close;
  Terminal *term = terminal_open(buf, topts);
  terminal_check_size(term);
  chan->term = term;
  channel_incref(chan);
  return (Integer)chan->id;
}

static void term_write(char *buf, size_t size, void *data)
{
  // TODO(bfredl): lua callback
}

static void term_resize(uint16_t width, uint16_t height, void *data)
{
  // TODO(bfredl): lua callback
}

static void term_close(void *data)
{
  Channel *chan = data;
  terminal_destroy(chan->term);
  chan->term = NULL;
  channel_decref(chan);
}


/// Send data to channel `id`. For a job, it writes it to the
/// stdin of the process. For the stdio channel |channel-stdio|,
/// it writes to Nvim's stdout.  For an internal terminal instance
/// (|nvim_open_term()|) it writes directly to terimal output.
/// See |channel-bytes| for more information.
///
/// This function writes raw data, not RPC messages.  If the channel
/// was created with `rpc=true` then the channel expects RPC
/// messages, use |vim.rpcnotify()| and |vim.rpcrequest()| instead.
///
/// @param chan id of the channel
/// @param data data to write. 8-bit clean: can contain NUL bytes.
/// @param[out] err Error details, if any
void nvim_chan_send(Integer chan, String data, Error *err)
  FUNC_API_SINCE(7) FUNC_API_REMOTE_ONLY FUNC_API_LUA_ONLY
{
  const char *error = NULL;
  if (!data.size) {
    return;
  }

  channel_send((uint64_t)chan, data.data, data.size,
               false, &error);
  if (error) {
    api_set_error(err, kErrorTypeValidation, "%s", error);
  }
}

/// Open a new window.
///
/// Currently this is used to open floating and external windows.
/// Floats are windows that are drawn above the split layout, at some anchor
/// position in some other window. Floats can be drawn internally or by external
/// GUI with the |ui-multigrid| extension. External windows are only supported
/// with multigrid GUIs, and are displayed as separate top-level windows.
///
/// For a general overview of floats, see |api-floatwin|.
///
/// Exactly one of `external` and `relative` must be specified. The `width` and
/// `height` of the new window must be specified.
///
/// With relative=editor (row=0,col=0) refers to the top-left corner of the
/// screen-grid and (row=Lines-1,col=Columns-1) refers to the bottom-right
/// corner. Fractional values are allowed, but the builtin implementation
/// (used by non-multigrid UIs) will always round down to nearest integer.
///
/// Out-of-bounds values, and configurations that make the float not fit inside
/// the main editor, are allowed. The builtin implementation truncates values
/// so floats are fully within the main screen grid. External GUIs
/// could let floats hover outside of the main window like a tooltip, but
/// this should not be used to specify arbitrary WM screen positions.
///
/// Example (Lua): window-relative float
/// <pre>
///     vim.api.nvim_open_win(0, false,
///       {relative='win', row=3, col=3, width=12, height=3})
/// </pre>
///
/// Example (Lua): buffer-relative float (travels as buffer is scrolled)
/// <pre>
///     vim.api.nvim_open_win(0, false,
///       {relative='win', width=12, height=3, bufpos={100,10}})
/// </pre>
///
/// @param buffer Buffer to display, or 0 for current buffer
/// @param enter  Enter the window (make it the current window)
/// @param config Map defining the window configuration. Keys:
///   - `relative`: Sets the window layout to "floating", placed at (row,col)
///                 coordinates relative to:
///      - "editor" The global editor grid
///      - "win"    Window given by the `win` field, or current window.
///      - "cursor" Cursor position in current window.
///   - `win`: |window-ID| for relative="win".
///   - `anchor`: Decides which corner of the float to place at (row,col):
///      - "NW" northwest (default)
///      - "NE" northeast
///      - "SW" southwest
///      - "SE" southeast
///   - `width`: Window width (in character cells). Minimum of 1.
///   - `height`: Window height (in character cells). Minimum of 1.
///   - `bufpos`: Places float relative to buffer text (only when
///               relative="win"). Takes a tuple of zero-indexed [line, column].
///               `row` and `col` if given are applied relative to this
///               position, else they default to `row=1` and `col=0`
///               (thus like a tooltip near the buffer text).
///   - `row`: Row position in units of "screen cell height", may be fractional.
///   - `col`: Column position in units of "screen cell width", may be
///            fractional.
///   - `focusable`: Enable focus by user actions (wincmds, mouse events).
///       Defaults to true. Non-focusable windows can be entered by
///       |nvim_set_current_win()|.
///   - `external`: GUI should display the window as an external
///       top-level window. Currently accepts no other positioning
///       configuration together with this.
///   - `zindex`: Stacking order. floats with higher `zindex` go on top on
///               floats with lower indices. Must be larger than zero. The
///               following screen elements have hard-coded z-indices:
///       - 100: insert completion popupmenu
///       - 200: message scrollback
///       - 250: cmdline completion popupmenu (when wildoptions+=pum)
///     The default value for floats are 50.  In general, values below 100 are
///     recommended, unless there is a good reason to overshadow builtin
///     elements.
///   - `style`: Configure the appearance of the window. Currently only takes
///       one non-empty value:
///       - "minimal"  Nvim will display the window with many UI options
///                    disabled. This is useful when displaying a temporary
///                    float where the text should not be edited. Disables
///                    'number', 'relativenumber', 'cursorline', 'cursorcolumn',
///                    'foldcolumn', 'spell' and 'list' options. 'signcolumn'
///                    is changed to `auto` and 'colorcolumn' is cleared. The
///                    end-of-buffer region is hidden by setting `eob` flag of
///                    'fillchars' to a space char, and clearing the
///                    |EndOfBuffer| region in 'winhighlight'.
///   - `border`: Style of (optional) window border. This can either be a string
///      or an array. The string values are
///     - "none": No border (default).
///     - "single": A single line box.
///     - "double": A double line box.
///     - "rounded": Like "single", but with rounded corners ("╭" etc.).
///     - "solid": Adds padding by a single whitespace cell.
///     - "shadow": A drop shadow effect by blending with the background.
///     - If it is an array, it should have a length of eight or any divisor of
///     eight. The array will specifify the eight chars building up the border
///     in a clockwise fashion starting with the top-left corner. As an
///     example, the double box style could be specified as
///       [ "╔", "═" ,"╗", "║", "╝", "═", "╚", "║" ].
///     If the number of chars are less than eight, they will be repeated. Thus
///     an ASCII border could be specified as
///       [ "/", "-", "\\", "|" ],
///     or all chars the same as
///       [ "x" ].
///     An empty string can be used to turn off a specific border, for instance,
///       [ "", "", "", ">", "", "", "", "<" ]
///     will only make vertical borders but not horizontal ones.
///     By default, `FloatBorder` highlight is used, which links to `VertSplit`
///     when not defined.  It could also be specified by character:
///       [ {"+", "MyCorner"}, {"x", "MyBorder"} ].
///   - `noautocmd`: If true then no buffer-related autocommand events such as
///                  |BufEnter|, |BufLeave| or |BufWinEnter| may fire from
///                  calling this function.
///
/// @param[out] err Error details, if any
///
/// @return Window handle, or 0 on error
Window nvim_open_win(Buffer buffer, Boolean enter, Dictionary config,
                     Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_CHECK_TEXTLOCK
{
  FloatConfig fconfig = FLOAT_CONFIG_INIT;
  if (!parse_float_config(config, &fconfig, false, true, err)) {
    return 0;
  }
  win_T *wp = win_new_float(NULL, fconfig, err);
  if (!wp) {
    return 0;
  }
  if (enter) {
    win_enter(wp, false);
  }
  if (!win_valid(wp)) {
    api_set_error(err, kErrorTypeException, "Window was closed immediately");
    return 0;
  }
  if (buffer > 0) {
    win_set_buf(wp->handle, buffer, fconfig.noautocmd, err);
  }

  if (fconfig.style == kWinStyleMinimal) {
    win_set_minimal_style(wp);
    didset_window_options(wp);
  }
  return wp->handle;
}

/// Gets the current list of tabpage handles.
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

/// Gets the current tabpage.
///
/// @return Tabpage handle
Tabpage nvim_get_current_tabpage(void)
  FUNC_API_SINCE(1)
{
  return curtab->handle;
}

/// Sets the current tabpage.
///
/// @param tabpage  Tabpage handle
/// @param[out] err Error details, if any
void nvim_set_current_tabpage(Tabpage tabpage, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_CHECK_TEXTLOCK
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

/// Creates a new namespace, or gets an existing one.
///
/// Namespaces are used for buffer highlights and virtual text, see
/// |nvim_buf_add_highlight()| and |nvim_buf_set_virtual_text()|.
///
/// Namespaces can be named or anonymous. If `name` matches an existing
/// namespace, the associated id is returned. If `name` is an empty string
/// a new, anonymous namespace is created.
///
/// @param name Namespace name or empty string
/// @return Namespace id
Integer nvim_create_namespace(String name)
  FUNC_API_SINCE(5)
{
  handle_T id = map_get(String, handle_T)(namespace_ids, name);
  if (id > 0) {
    return id;
  }
  id = next_namespace_id++;
  if (name.size > 0) {
    String name_alloc = copy_string(name);
    map_put(String, handle_T)(namespace_ids, name_alloc, id);
  }
  return (Integer)id;
}

/// Gets existing, non-anonymous namespaces.
///
/// @return dict that maps from names to namespace ids.
Dictionary nvim_get_namespaces(void)
  FUNC_API_SINCE(5)
{
  Dictionary retval = ARRAY_DICT_INIT;
  String name;
  handle_T id;

  map_foreach(namespace_ids, name, id, {
    PUT(retval, name.data, INTEGER_OBJ(id));
  })

  return retval;
}

/// Pastes at cursor, in any mode.
///
/// Invokes the `vim.paste` handler, which handles each mode appropriately.
/// Sets redo/undo. Faster than |nvim_input()|. Lines break at LF ("\n").
///
/// Errors ('nomodifiable', `vim.paste()` failure, …) are reflected in `err`
/// but do not affect the return value (which is strictly decided by
/// `vim.paste()`).  On error, subsequent calls are ignored ("drained") until
/// the next paste is initiated (phase 1 or -1).
///
/// @param data  Multiline input. May be binary (containing NUL bytes).
/// @param crlf  Also break lines at CR and CRLF.
/// @param phase  -1: paste in a single call (i.e. without streaming).
///               To "stream" a paste, call `nvim_paste` sequentially with
///               these `phase` values:
///                 - 1: starts the paste (exactly once)
///                 - 2: continues the paste (zero or more times)
///                 - 3: ends the paste (exactly once)
/// @param[out] err Error details, if any
/// @return
///     - true: Client may continue pasting.
///     - false: Client must cancel the paste.
Boolean nvim_paste(String data, Boolean crlf, Integer phase, Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_CHECK_TEXTLOCK
{
  static bool draining = false;
  bool cancel = false;

  if (phase < -1 || phase > 3) {
    api_set_error(err, kErrorTypeValidation, "Invalid phase: %"PRId64, phase);
    return false;
  }
  Array args = ARRAY_DICT_INIT;
  Object rv = OBJECT_INIT;
  if (phase == -1 || phase == 1) {  // Start of paste-stream.
    draining = false;
  } else if (draining) {
    // Skip remaining chunks.  Report error only once per "stream".
    goto theend;
  }
  Array lines = string_to_array(data, crlf);
  ADD(args, ARRAY_OBJ(lines));
  ADD(args, INTEGER_OBJ(phase));
  rv = nvim_exec_lua(STATIC_CSTR_AS_STRING("return vim.paste(...)"), args,
                     err);
  if (ERROR_SET(err)) {
    draining = true;
    goto theend;
  }
  if (!(State & (CMDLINE | INSERT)) && (phase == -1 || phase == 1)) {
    ResetRedobuff();
    AppendCharToRedobuff('a');  // Dot-repeat.
  }
  // vim.paste() decides if client should cancel.  Errors do NOT cancel: we
  // want to drain remaining chunks (rather than divert them to main input).
  cancel = (rv.type == kObjectTypeBoolean && !rv.data.boolean);
  if (!cancel && !(State & CMDLINE)) {  // Dot-repeat.
    for (size_t i = 0; i < lines.size; i++) {
      String s = lines.items[i].data.string;
      assert(data.size <= INT_MAX);
      AppendToRedobuffLit((char_u *)s.data, (int)s.size);
      // readfile()-style: "\n" is indicated by presence of N+1 item.
      if (i + 1 < lines.size) {
        AppendCharToRedobuff(NL);
      }
    }
  }
  if (!(State & (CMDLINE | INSERT)) && (phase == -1 || phase == 3)) {
    AppendCharToRedobuff(ESC);  // Dot-repeat.
  }
theend:
  api_free_object(rv);
  api_free_array(args);
  if (cancel || phase == -1 || phase == 3) {  // End of paste-stream.
    draining = false;
  }

  return !cancel;
}

/// Puts text at cursor, in any mode.
///
/// Compare |:put| and |p| which are always linewise.
///
/// @param lines  |readfile()|-style list of lines. |channel-lines|
/// @param type  Edit behavior: any |getregtype()| result, or:
///              - "b" |blockwise-visual| mode (may include width, e.g. "b3")
///              - "c" |charwise| mode
///              - "l" |linewise| mode
///              - ""  guess by contents, see |setreg()|
/// @param after  If true insert after cursor (like |p|), or before (like |P|).
/// @param follow  If true place cursor at end of inserted text.
/// @param[out] err Error details, if any
void nvim_put(ArrayOf(String) lines, String type, Boolean after,
              Boolean follow, Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_CHECK_TEXTLOCK
{
  yankreg_T *reg = xcalloc(sizeof(yankreg_T), 1);
  if (!prepare_yankreg_from_object(reg, type, lines.size)) {
    api_set_error(err, kErrorTypeValidation, "Invalid type: '%s'", type.data);
    goto cleanup;
  }
  if (lines.size == 0) {
    goto cleanup;  // Nothing to do.
  }

  for (size_t i = 0; i < lines.size; i++) {
    if (lines.items[i].type != kObjectTypeString) {
      api_set_error(err, kErrorTypeValidation,
                    "Invalid lines (expected array of strings)");
      goto cleanup;
    }
    String line = lines.items[i].data.string;
    reg->y_array[i] = (char_u *)xmemdupz(line.data, line.size);
    memchrsub(reg->y_array[i], NUL, NL, line.size);
  }

  finish_yankreg_from_object(reg, false);

  TRY_WRAP({
    try_start();
    bool VIsual_was_active = VIsual_active;
    msg_silent++;  // Avoid "N more lines" message.
    do_put(0, reg, after ? FORWARD : BACKWARD, 1, follow ? PUT_CURSEND : 0);
    msg_silent--;
    VIsual_active = VIsual_was_active;
    try_end(err);
  });

cleanup:
  free_register(reg);
  xfree(reg);
}

/// Subscribes to event broadcasts.
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

/// Unsubscribes to event broadcasts.
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

/// Returns the 24-bit RGB value of a |nvim_get_color_map()| color name or
/// "#rrggbb" hexadecimal string.
///
/// Example:
/// <pre>
///     :echo nvim_get_color_by_name("Pink")
///     :echo nvim_get_color_by_name("#cbcbcb")
/// </pre>
///
/// @param name Color name or "#rrggbb" string
/// @return 24-bit RGB value, or -1 for invalid argument.
Integer nvim_get_color_by_name(String name)
  FUNC_API_SINCE(1)
{
  return name_to_color(name.data);
}

/// Returns a map of color names and RGB values.
///
/// Keys are color names (e.g. "Aqua") and values are 24-bit RGB color values
/// (e.g. 65535).
///
/// @return Map of color names and RGB values.
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

/// Gets a map of the current editor state.
///
/// @param opts  Optional parameters.
///               - types:  List of |context-types| ("regs", "jumps", "bufs",
///                 "gvars", …) to gather, or empty for "all".
/// @param[out]  err  Error details, if any
///
/// @return map of global |context|.
Dictionary nvim_get_context(Dictionary opts, Error *err)
  FUNC_API_SINCE(6)
{
  Array types = ARRAY_DICT_INIT;
  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object v = opts.items[i].value;
    if (strequal("types", k.data)) {
      if (v.type != kObjectTypeArray) {
        api_set_error(err, kErrorTypeValidation, "invalid value for key: %s",
                      k.data);
        return (Dictionary)ARRAY_DICT_INIT;
      }
      types = v.data.array;
    } else {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      return (Dictionary)ARRAY_DICT_INIT;
    }
  }

  int int_types = types.size > 0 ? 0 : kCtxAll;
  if (types.size > 0) {
    for (size_t i = 0; i < types.size; i++) {
      if (types.items[i].type == kObjectTypeString) {
        const char *const s = types.items[i].data.string.data;
        if (strequal(s, "regs")) {
          int_types |= kCtxRegs;
        } else if (strequal(s, "jumps")) {
          int_types |= kCtxJumps;
        } else if (strequal(s, "bufs")) {
          int_types |= kCtxBufs;
        } else if (strequal(s, "gvars")) {
          int_types |= kCtxGVars;
        } else if (strequal(s, "sfuncs")) {
          int_types |= kCtxSFuncs;
        } else if (strequal(s, "funcs")) {
          int_types |= kCtxFuncs;
        } else {
          api_set_error(err, kErrorTypeValidation, "unexpected type: %s", s);
          return (Dictionary)ARRAY_DICT_INIT;
        }
      }
    }
  }

  Context ctx = CONTEXT_INIT;
  ctx_save(&ctx, int_types);
  Dictionary dict = ctx_to_dict(&ctx);
  ctx_free(&ctx);
  return dict;
}

/// Sets the current editor state from the given |context| map.
///
/// @param  dict  |Context| map.
Object nvim_load_context(Dictionary dict)
  FUNC_API_SINCE(6)
{
  Context ctx = CONTEXT_INIT;

  int save_did_emsg = did_emsg;
  did_emsg = false;

  ctx_from_dict(dict, &ctx);
  if (!did_emsg) {
    ctx_restore(&ctx, kCtxAll);
  }

  ctx_free(&ctx);

  did_emsg = save_did_emsg;
  return (Object)OBJECT_INIT;
}

/// Gets the current mode. |mode()|
/// "blocking" is true if Nvim is waiting for input.
///
/// @returns Dictionary { "mode": String, "blocking": Boolean }
Dictionary nvim_get_mode(void)
  FUNC_API_SINCE(2) FUNC_API_FAST
{
  Dictionary rv = ARRAY_DICT_INIT;
  char *modestr = get_mode();
  bool blocked = input_blocking();

  PUT(rv, "mode", STRING_OBJ(cstr_as_string(modestr)));
  PUT(rv, "blocking", BOOLEAN_OBJ(blocked));

  return rv;
}

/// Gets a list of global (non-buffer-local) |mapping| definitions.
///
/// @param  mode       Mode short-name ("n", "i", "v", ...)
/// @returns Array of maparg()-like dictionaries describing mappings.
///          The "buffer" key is always zero.
ArrayOf(Dictionary) nvim_get_keymap(String mode)
  FUNC_API_SINCE(3)
{
  return keymap_array(mode, NULL);
}

/// Sets a global |mapping| for the given mode.
///
/// To set a buffer-local mapping, use |nvim_buf_set_keymap()|.
///
/// Unlike |:map|, leading/trailing whitespace is accepted as part of the {lhs}
/// or {rhs}. Empty {rhs} is |<Nop>|. |keycodes| are replaced as usual.
///
/// Example:
/// <pre>
///     call nvim_set_keymap('n', ' <NL>', '', {'nowait': v:true})
/// </pre>
///
/// is equivalent to:
/// <pre>
///     nmap <nowait> <Space><NL> <Nop>
/// </pre>
///
/// @param  mode  Mode short-name (map command prefix: "n", "i", "v", "x", …)
///               or "!" for |:map!|, or empty string for |:map|.
/// @param  lhs   Left-hand-side |{lhs}| of the mapping.
/// @param  rhs   Right-hand-side |{rhs}| of the mapping.
/// @param  opts  Optional parameters map. Accepts all |:map-arguments|
///               as keys excluding |<buffer>| but including |noremap|.
///               Values are Booleans. Unknown key is an error.
/// @param[out]   err   Error details, if any.
void nvim_set_keymap(String mode, String lhs, String rhs,
                     Dictionary opts, Error *err)
  FUNC_API_SINCE(6)
{
  modify_keymap(-1, false, mode, lhs, rhs, opts, err);
}

/// Unmaps a global |mapping| for the given mode.
///
/// To unmap a buffer-local mapping, use |nvim_buf_del_keymap()|.
///
/// @see |nvim_set_keymap()|
void nvim_del_keymap(String mode, String lhs, Error *err)
  FUNC_API_SINCE(6)
{
  nvim_buf_del_keymap(-1, mode, lhs, err);
}

/// Gets a map of global (non-buffer-local) Ex commands.
///
/// Currently only |user-commands| are supported, not builtin Ex commands.
///
/// @param  opts  Optional parameters. Currently only supports
///               {"builtin":false}
/// @param[out]  err   Error details, if any.
///
/// @returns Map of maps describing commands.
Dictionary nvim_get_commands(Dictionary opts, Error *err)
  FUNC_API_SINCE(4)
{
  return nvim_buf_get_commands(-1, opts, err);
}

/// Returns a 2-tuple (Array), where item 0 is the current channel id and item
/// 1 is the |api-metadata| map (Dictionary).
///
/// @returns 2-tuple [{channel-id}, {api-metadata}]
Array nvim_get_api_info(uint64_t channel_id)
  FUNC_API_SINCE(1) FUNC_API_FAST FUNC_API_REMOTE_ONLY
{
  Array rv = ARRAY_DICT_INIT;

  assert(channel_id <= INT64_MAX);
  ADD(rv, INTEGER_OBJ((int64_t)channel_id));
  ADD(rv, DICTIONARY_OBJ(api_metadata()));

  return rv;
}

/// Self-identifies the client.
///
/// The client/plugin/application should call this after connecting, to provide
/// hints about its identity and purpose, for debugging and orchestration.
///
/// Can be called more than once; the caller should merge old info if
/// appropriate. Example: library first identifies the channel, then a plugin
/// using that library later identifies itself.
///
/// @note "Something is better than nothing". You don't need to include all the
///       fields.
///
/// @param channel_id
/// @param name Short name for the connected client
/// @param version  Dictionary describing the version, with these
///                 (optional) keys:
///     - "major" major version (defaults to 0 if not set, for no release yet)
///     - "minor" minor version
///     - "patch" patch number
///     - "prerelease" string describing a prerelease, like "dev" or "beta1"
///     - "commit" hash or similar identifier of commit
/// @param type Must be one of the following values. Client libraries should
///             default to "remote" unless overridden by the user.
///     - "remote" remote client connected to Nvim.
///     - "ui" gui frontend
///     - "embedder" application using Nvim as a component (for example,
///                  IDE/editor implementing a vim mode).
///     - "host" plugin host, typically started by nvim
///     - "plugin" single plugin, started by nvim
/// @param methods Builtin methods in the client. For a host, this does not
///                include plugin methods which will be discovered later.
///                The key should be the method name, the values are dicts with
///                these (optional) keys (more keys may be added in future
///                versions of Nvim, thus unknown keys are ignored. Clients
///                must only use keys defined in this or later versions of
///                Nvim):
///     - "async"  if true, send as a notification. If false or unspecified,
///                use a blocking request
///     - "nargs" Number of arguments. Could be a single integer or an array
///                of two integers, minimum and maximum inclusive.
///
/// @param attributes Arbitrary string:string map of informal client properties.
///     Suggested keys:
///     - "website": Client homepage URL (e.g. GitHub repository)
///     - "license": License description ("Apache 2", "GPLv3", "MIT", …)
///     - "logo":    URI or path to image, preferably small logo or icon.
///                  .png or .svg format is preferred.
///
/// @param[out] err Error details, if any
void nvim_set_client_info(uint64_t channel_id, String name,
                          Dictionary version, String type,
                          Dictionary methods, Dictionary attributes,
                          Error *err)
  FUNC_API_SINCE(4) FUNC_API_REMOTE_ONLY
{
  Dictionary info = ARRAY_DICT_INIT;
  PUT(info, "name", copy_object(STRING_OBJ(name)));

  version = copy_dictionary(version);
  bool has_major = false;
  for (size_t i = 0; i < version.size; i++) {
    if (strequal(version.items[i].key.data, "major")) {
      has_major = true;
      break;
    }
  }
  if (!has_major) {
    PUT(version, "major", INTEGER_OBJ(0));
  }
  PUT(info, "version", DICTIONARY_OBJ(version));

  PUT(info, "type", copy_object(STRING_OBJ(type)));
  PUT(info, "methods", DICTIONARY_OBJ(copy_dictionary(methods)));
  PUT(info, "attributes", DICTIONARY_OBJ(copy_dictionary(attributes)));

  rpc_set_client_info(channel_id, info);
}

/// Get information about a channel.
///
/// @returns Dictionary describing a channel, with these keys:
///    - "stream"  the stream underlying the channel
///         - "stdio"      stdin and stdout of this Nvim instance
///         - "stderr"     stderr of this Nvim instance
///         - "socket"     TCP/IP socket or named pipe
///         - "job"        job with communication over its stdio
///    -  "mode"    how data received on the channel is interpreted
///         - "bytes"      send and receive raw bytes
///         - "terminal"   a |terminal| instance interprets ASCII sequences
///         - "rpc"        |RPC| communication on the channel is active
///    -  "pty"     Name of pseudoterminal, if one is used (optional).
///                 On a POSIX system, this will be a device path like
///                 /dev/pts/1. Even if the name is unknown, the key will
///                 still be present to indicate a pty is used. This is
///                 currently the case when using winpty on windows.
///    -  "buffer"  buffer with connected |terminal| instance (optional)
///    -  "client"  information about the client on the other end of the
///                 RPC channel, if it has added it using
///                 |nvim_set_client_info()|. (optional)
///
Dictionary nvim_get_chan_info(Integer chan, Error *err)
  FUNC_API_SINCE(4)
{
  if (chan < 0) {
    return (Dictionary)ARRAY_DICT_INIT;
  }
  return channel_info((uint64_t)chan);
}

/// Get information about all open channels.
///
/// @returns Array of Dictionaries, each describing a channel with
///          the format specified at |nvim_get_chan_info()|.
Array nvim_list_chans(void)
  FUNC_API_SINCE(4)
{
  return channel_all_info();
}

/// Calls many API methods atomically.
///
/// This has two main usages:
/// 1. To perform several requests from an async context atomically, i.e.
///    without interleaving redraws, RPC requests from other clients, or user
///    interactions (however API methods may trigger autocommands or event
///    processing which have such side-effects, e.g. |:sleep| may wake timers).
/// 2. To minimize RPC overhead (roundtrips) of a sequence of many requests.
///
/// @param channel_id
/// @param calls an array of calls, where each call is described by an array
///              with two elements: the request name, and an array of arguments.
/// @param[out] err Validation error details (malformed `calls` parameter),
///             if any. Errors from batched calls are given in the return value.
///
/// @return Array of two elements. The first is an array of return
/// values. The second is NIL if all calls succeeded. If a call resulted in
/// an error, it is a three-element array with the zero-based index of the call
/// which resulted in an error, the error type and the error message. If an
/// error occurred, the values from all preceding calls will still be returned.
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
                    "Items in calls array must be arrays");
      goto validation_error;
    }
    Array call = calls.items[i].data.array;
    if (call.size != 2) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Items in calls array must be arrays of size 2");
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

    MsgpackRpcRequestHandler handler =
        msgpack_rpc_get_handler_for(name.data,
                                    name.size,
                                    &nested_error);

    if (ERROR_SET(&nested_error)) {
      break;
    }
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

/// Parse a VimL expression.
///
/// @param[in]  expr  Expression to parse. Always treated as a single line.
/// @param[in]  flags Flags:
///                    - "m" if multiple expressions in a row are allowed (only
///                      the first one will be parsed),
///                    - "E" if EOC tokens are not allowed (determines whether
///                      they will stop parsing process or be recognized as an
///                      operator/space, though also yielding an error).
///                    - "l" when needing to start parsing with lvalues for
///                      ":let" or ":for".
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
/// @return
///      - AST: top-level dictionary with these keys:
///        - "error": Dictionary with error, present only if parser saw some
///                 error. Contains the following keys:
///          - "message": String, error message in printf format, translated.
///                       Must contain exactly one "%.*s".
///          - "arg": String, error message argument.
///        - "len": Amount of bytes successfully parsed. With flags equal to ""
///                 that should be equal to the length of expr string.
///                 (“Successfully parsed” here means “participated in AST
///                  creation”, not “till the first error”.)
///        - "ast": AST, either nil or a dictionary with these keys:
///          - "type": node type, one of the value names from ExprASTNodeType
///                    stringified without "kExprNode" prefix.
///          - "start": a pair [line, column] describing where node is "started"
///                     where "line" is always 0 (will not be 0 if you will be
///                     using nvim_parse_viml() on e.g. ":let", but that is not
///                     present yet). Both elements are Integers.
///          - "len": “length” of the node. This and "start" are there for
///                   debugging purposes primary (debugging parser and providing
///                   debug information).
///          - "children": a list of nodes described in top/"ast". There always
///                        is zero, one or two children, key will not be present
///                        if node has no children. Maximum number of children
///                        may be found in node_maxchildren array.
///      - Local values (present only for certain nodes):
///        - "scope": a single Integer, specifies scope for "Option" and
///                   "PlainIdentifier" nodes. For "Option" it is one of
///                   ExprOptScope values, for "PlainIdentifier" it is one of
///                   ExprVarScope values.
///        - "ident": identifier (without scope, if any), present for "Option",
///                   "PlainIdentifier", "PlainKey" and "Environment" nodes.
///        - "name": Integer, register name (one character) or -1. Only present
///                for "Register" nodes.
///        - "cmp_type": String, comparison type, one of the value names from
///                      ExprComparisonType, stringified without "kExprCmp"
///                      prefix. Only present for "Comparison" nodes.
///        - "ccs_strategy": String, case comparison strategy, one of the
///                          value names from ExprCaseCompareStrategy,
///                          stringified without "kCCStrategy" prefix. Only
///                          present for "Comparison" nodes.
///        - "augmentation": String, augmentation type for "Assignment" nodes.
///                          Is either an empty string, "Add", "Subtract" or
///                          "Concat" for "=", "+=", "-=" or ".=" respectively.
///        - "invert": Boolean, true if result of comparison needs to be
///                    inverted. Only present for "Comparison" nodes.
///        - "ivalue": Integer, integer value for "Integer" nodes.
///        - "fvalue": Float, floating-point value for "Float" nodes.
///        - "svalue": String, value for "SingleQuotedString" and
///                    "DoubleQuotedString" nodes.
/// @param[out] err Error details, if any
Dictionary nvim_parse_expression(String expr, String flags, Boolean highlight,
                                 Error *err)
  FUNC_API_SINCE(4) FUNC_API_FAST
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
      } else {
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

/// Returns object given as argument.
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

/// Returns array given as argument.
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

/// Returns dictionary given as argument.
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

/// Returns floating-point value given as argument.
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

/// Gets internal stats.
///
/// @return Map of various internal stats.
Dictionary nvim__stats(void)
{
  Dictionary rv = ARRAY_DICT_INIT;
  PUT(rv, "fsync", INTEGER_OBJ(g_stats.fsync));
  PUT(rv, "redraw", INTEGER_OBJ(g_stats.redraw));
  PUT(rv, "lua_refcount", INTEGER_OBJ(nlua_refcount));
  return rv;
}

/// Gets a list of dictionaries representing attached UIs.
///
/// @return Array of UI dictionaries, each with these keys:
///   - "height"  Requested height of the UI
///   - "width"   Requested width of the UI
///   - "rgb"     true if the UI uses RGB colors (false implies |cterm-colors|)
///   - "ext_..." Requested UI extensions, see |ui-option|
///   - "chan"    Channel id of remote UI (not present for TUI)
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
    Object o = nlua_exec(s, a, err);
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
  Object o = nlua_exec(s, a, err);
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

/// Selects an item in the completion popupmenu.
///
/// If |ins-completion| is not active this API call is silently ignored.
/// Useful for an external UI using |ui-popupmenu| to control the popupmenu
/// with the mouse. Can also be used in a mapping; use <cmd> |:map-cmd| to
/// ensure the mapping doesn't end completion mode.
///
/// @param item   Index (zero-based) of the item to select. Value of -1 selects
///               nothing and restores the original text.
/// @param insert Whether the selection should be inserted in the buffer.
/// @param finish Finish the completion and dismiss the popupmenu. Implies
///               `insert`.
/// @param  opts  Optional parameters. Reserved for future use.
/// @param[out] err Error details, if any
void nvim_select_popupmenu_item(Integer item, Boolean insert, Boolean finish,
                                Dictionary opts, Error *err)
  FUNC_API_SINCE(6)
{
  if (opts.size > 0) {
    api_set_error(err, kErrorTypeValidation, "opts dict isn't empty");
    return;
  }

  if (finish) {
    insert = true;
  }

  pum_ext_select_item((int)item, insert, finish);
}

/// NB: if your UI doesn't use hlstate, this will not return hlstate first time
Array nvim__inspect_cell(Integer grid, Integer row, Integer col, Error *err)
{
  Array ret = ARRAY_DICT_INIT;

  // TODO(bfredl): if grid == 0 we should read from the compositor's buffer.
  // The only problem is that it does not yet exist.
  ScreenGrid *g = &default_grid;
  if (grid == pum_grid.handle) {
    g = &pum_grid;
  } else if (grid > 1) {
    win_T *wp = get_win_by_grid_handle((handle_T)grid);
    if (wp != NULL && wp->w_grid_alloc.chars != NULL) {
      g = &wp->w_grid_alloc;
    } else {
      api_set_error(err, kErrorTypeValidation,
                    "No grid with the given handle");
      return ret;
    }
  }

  if (row < 0 || row >= g->Rows
      || col < 0 || col >= g->Columns) {
    return ret;
  }
  size_t off = g->line_offset[(size_t)row] + (size_t)col;
  ADD(ret, STRING_OBJ(cstr_to_string((char *)g->chars[off])));
  int attr = g->attrs[off];
  ADD(ret, DICTIONARY_OBJ(hl_get_attr_by_id(attr, true, err)));
  // will not work first time
  if (!highlight_use_hlstate()) {
    ADD(ret, ARRAY_OBJ(hl_inspect(attr)));
  }
  return ret;
}

void nvim__screenshot(String path)
  FUNC_API_FAST
{
  ui_call_screenshot(path);
}

/// Set or change decoration provider for a namespace
///
/// This is a very general purpose interface for having lua callbacks
/// being triggered during the redraw code.
///
/// The expected usage is to set extmarks for the currently
/// redrawn buffer. |nvim_buf_set_extmark| can be called to add marks
/// on a per-window or per-lines basis. Use the `ephemeral` key to only
/// use the mark for the current screen redraw (the callback will be called
/// again for the next redraw ).
///
/// Note: this function should not be called often. Rather, the callbacks
/// themselves can be used to throttle unneeded callbacks. the `on_start`
/// callback can return `false` to disable the provider until the next redraw.
/// Similarly, return `false` in `on_win` will skip the `on_lines` calls
/// for that window (but any extmarks set in `on_win` will still be used).
/// A plugin managing multiple sources of decoration should ideally only set
/// one provider, and merge the sources internally. You can use multiple `ns_id`
/// for the extmarks set/modified inside the callback anyway.
///
/// Note: doing anything other than setting extmarks is considered experimental.
/// Doing things like changing options are not expliticly forbidden, but is
/// likely to have unexpected consequences (such as 100% CPU consumption).
/// doing `vim.rpcnotify` should be OK, but `vim.rpcrequest` is quite dubious
/// for the moment.
///
/// @param ns_id  Namespace id from |nvim_create_namespace()|
/// @param opts   Callbacks invoked during redraw:
///             - on_start: called first on each screen redraw
///                 ["start", tick]
///             - on_buf: called for each buffer being redrawn (before window
///                 callbacks)
///                 ["buf", bufnr, tick]
///             - on_win: called when starting to redraw a specific window.
///                 ["win", winid, bufnr, topline, botline_guess]
///             - on_line: called for each buffer line being redrawn. (The
///                 interation with fold lines is subject to change)
///                 ["win", winid, bufnr, row]
///             - on_end: called at the end of a redraw cycle
///                 ["end", tick]
void nvim_set_decoration_provider(Integer ns_id, DictionaryOf(LuaRef) opts,
                                  Error *err)
  FUNC_API_SINCE(7) FUNC_API_LUA_ONLY
{
  DecorProvider *p = get_decor_provider((NS)ns_id, true);
  assert(p != NULL);
  decor_provider_clear(p);

  // regardless of what happens, it seems good idea to redraw
  redraw_all_later(NOT_VALID);  // TODO(bfredl): too soon?

  struct {
    const char *name;
    LuaRef *dest;
  } cbs[] = {
    { "on_start", &p->redraw_start },
    { "on_buf", &p->redraw_buf },
    { "on_win", &p->redraw_win },
    { "on_line", &p->redraw_line },
    { "on_end", &p->redraw_end },
    { "_on_hl_def", &p->hl_def },
    { NULL, NULL },
  };

  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    size_t j;
    for (j = 0; cbs[j].name && cbs[j].dest; j++) {
      if (strequal(cbs[j].name, k.data)) {
        if (v->type != kObjectTypeLuaRef) {
          api_set_error(err, kErrorTypeValidation,
                        "%s is not a function", cbs[j].name);
          goto error;
        }
        *(cbs[j].dest) = v->data.luaref;
        v->data.luaref = LUA_NOREF;
        break;
      }
    }
    if (!cbs[j].name) {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      goto error;
    }
  }

  p->active = true;
  return;
error:
  decor_provider_clear(p);
}
