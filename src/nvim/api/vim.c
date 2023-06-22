// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "lauxlib.h"
#include "nvim/api/buffer.h"
#include "nvim/api/deprecated.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/api/vim.h"
#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/channel.h"
#include "nvim/context.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/macros.h"
#include "nvim/mapping.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/msgpack_rpc/unpacker.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/optionstr.h"
#include "nvim/os/input.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/process.h"
#include "nvim/popupmenu.h"
#include "nvim/pos.h"
#include "nvim/runtime.h"
#include "nvim/sign.h"
#include "nvim/state.h"
#include "nvim/statusline.h"
#include "nvim/strings.h"
#include "nvim/terminal.h"
#include "nvim/types.h"
#include "nvim/ui.h"
#include "nvim/vim.h"
#include "nvim/window.h"

#define LINE_BUFFER_MIN_SIZE 4096

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.c.generated.h"
#endif

/// Gets a highlight group by name
///
/// similar to |hlID()|, but allocates a new ID if not present.
Integer nvim_get_hl_id_by_name(String name)
  FUNC_API_SINCE(7)
{
  return syn_check_group(name.data, name.size);
}

/// Gets all or specific highlight groups in a namespace.
///
/// @param ns_id Get highlight groups for namespace ns_id |nvim_get_namespaces()|.
///              Use 0 to get global highlight groups |:highlight|.
/// @param opts  Options dict:
///                 - name: (string) Get a highlight definition by name.
///                 - id: (integer) Get a highlight definition by id.
///                 - link: (boolean, default true) Show linked group name instead of effective definition |:hi-link|.
///
/// @param[out] err Error details, if any.
/// @return Highlight groups as a map from group name to a highlight definition map as in |nvim_set_hl()|,
///                   or only a single highlight definition map if requested by name or id.
///
/// @note When the `link` attribute is defined in the highlight definition
///       map, other attributes will not be taking effect (see |:hi-link|).
Dictionary nvim_get_hl(Integer ns_id, Dict(get_highlight) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(11)
{
  return ns_get_hl_defs((NS)ns_id, opts, arena, err);
}

/// Sets a highlight group.
///
/// @note Unlike the `:highlight` command which can update a highlight group,
///       this function completely replaces the definition. For example:
///       ``nvim_set_hl(0, 'Visual', {})`` will clear the highlight group
///       'Visual'.
///
/// @note The fg and bg keys also accept the string values `"fg"` or `"bg"`
///       which act as aliases to the corresponding foreground and background
///       values of the Normal group. If the Normal group has not been defined,
///       using these values results in an error.
///
///
/// @note If `link` is used in combination with other attributes; only the
///       `link` will take effect (see |:hi-link|).
///
/// @param ns_id Namespace id for this highlight |nvim_create_namespace()|.
///              Use 0 to set a highlight group globally |:highlight|.
///              Highlights from non-global namespaces are not active by default, use
///              |nvim_set_hl_ns()| or |nvim_win_set_hl_ns()| to activate them.
/// @param name  Highlight group name, e.g. "ErrorMsg"
/// @param val   Highlight definition map, accepts the following keys:
///                - fg (or foreground): color name or "#RRGGBB", see note.
///                - bg (or background): color name or "#RRGGBB", see note.
///                - sp (or special): color name or "#RRGGBB"
///                - blend: integer between 0 and 100
///                - bold: boolean
///                - standout: boolean
///                - underline: boolean
///                - undercurl: boolean
///                - underdouble: boolean
///                - underdotted: boolean
///                - underdashed: boolean
///                - strikethrough: boolean
///                - italic: boolean
///                - reverse: boolean
///                - nocombine: boolean
///                - link: name of another highlight group to link to, see |:hi-link|.
///                - default: Don't override existing definition |:hi-default|
///                - ctermfg: Sets foreground of cterm color |ctermfg|
///                - ctermbg: Sets background of cterm color |ctermbg|
///                - cterm: cterm attribute map, like |highlight-args|. If not set,
///                         cterm attributes will match those from the attribute map
///                         documented above.
/// @param[out] err Error details, if any
///
// TODO(bfredl): val should take update vs reset flag
void nvim_set_hl(Integer ns_id, String name, Dict(highlight) *val, Error *err)
  FUNC_API_SINCE(7)
{
  int hl_id = syn_check_group(name.data, name.size);
  VALIDATE_S((hl_id != 0), "highlight name", name.data, {
    return;
  });
  int link_id = -1;

  HlAttrs attrs = dict2hlattrs(val, true, &link_id, err);
  if (!ERROR_SET(err)) {
    ns_hl_def((NS)ns_id, hl_id, attrs, link_id, val);
  }
}

/// Set active namespace for highlights defined with |nvim_set_hl()|. This can be set for
/// a single window, see |nvim_win_set_hl_ns()|.
///
/// @param ns_id the namespace to use
/// @param[out] err Error details, if any
void nvim_set_hl_ns(Integer ns_id, Error *err)
  FUNC_API_SINCE(10)
{
  VALIDATE_INT((ns_id >= 0), "namespace", ns_id, {
    return;
  });

  ns_hl_global = (NS)ns_id;
  hl_check_ns();
  redraw_all_later(UPD_NOT_VALID);
}

/// Set active namespace for highlights defined with |nvim_set_hl()| while redrawing.
///
/// This function meant to be called while redrawing, primarily from
/// |nvim_set_decoration_provider()| on_win and on_line callbacks, which
/// are allowed to change the namespace during a redraw cycle.
///
/// @param ns_id the namespace to activate
/// @param[out] err Error details, if any
void nvim_set_hl_ns_fast(Integer ns_id, Error *err)
  FUNC_API_SINCE(10)
  FUNC_API_FAST
{
  ns_hl_fast = (NS)ns_id;
  hl_check_ns();
}

/// Sends input-keys to Nvim, subject to various quirks controlled by `mode`
/// flags. This is a blocking call, unlike |nvim_input()|.
///
/// On execution error: does not fail, but updates v:errmsg.
///
/// To input sequences like <C-o> use |nvim_replace_termcodes()| (typically
/// with escape_ks=false) to replace |keycodes|, then pass the result to
/// nvim_feedkeys().
///
/// Example:
/// <pre>vim
///     :let key = nvim_replace_termcodes("<C-o>", v:true, v:false, v:true)
///     :call nvim_feedkeys(key, 'n', v:false)
/// </pre>
///
/// @param keys         to be typed
/// @param mode         behavior flags, see |feedkeys()|
/// @param escape_ks    If true, escape K_SPECIAL bytes in `keys`.
///                     This should be false if you already used
///                     |nvim_replace_termcodes()|, and true otherwise.
/// @see feedkeys()
/// @see vim_strsave_escape_ks
void nvim_feedkeys(String keys, String mode, Boolean escape_ks)
  FUNC_API_SINCE(1)
{
  bool remap = true;
  bool insert = false;
  bool typed = false;
  bool execute = false;
  bool dangerous = false;

  for (size_t i = 0; i < mode.size; i++) {
    switch (mode.data[i]) {
    case 'n':
      remap = false; break;
    case 'm':
      remap = true; break;
    case 't':
      typed = true; break;
    case 'i':
      insert = true; break;
    case 'x':
      execute = true; break;
    case '!':
      dangerous = true; break;
    }
  }

  if (keys.size == 0 && !execute) {
    return;
  }

  char *keys_esc;
  if (escape_ks) {
    // Need to escape K_SPECIAL before putting the string in the
    // typeahead buffer.
    keys_esc = vim_strsave_escape_ks(keys.data);
  } else {
    keys_esc = keys.data;
  }
  ins_typebuf(keys_esc, (remap ? REMAP_YES : REMAP_NONE),
              insert ? 0 : typebuf.tb_len, !typed, false);
  if (vgetc_busy) {
    typebuf_was_filled = true;
  }

  if (escape_ks) {
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
/// @param button Mouse button: one of "left", "right", "middle", "wheel", "move".
/// @param action For ordinary buttons, one of "press", "drag", "release".
///               For the wheel, one of "up", "down", "left", "right". Ignored for "move".
/// @param modifier String of modifiers each represented by a single char.
///                 The same specifiers are used as for a key press, except
///                 that the "-" separator is optional, so "C-A-", "c-a"
///                 and "CA" can all be used to specify Ctrl+Alt+click.
/// @param grid Grid number if the client uses |ui-multigrid|, else 0.
/// @param row Mouse row-position (zero-based, like redraw events)
/// @param col Mouse column-position (zero-based, like redraw events)
/// @param[out] err Error details, if any
void nvim_input_mouse(String button, String action, String modifier, Integer grid, Integer row,
                      Integer col, Error *err)
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
  } else if (strequal(button.data, "move")) {
    code = KE_MOUSEMOVE;
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
  } else if (code != KE_MOUSEMOVE) {
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
    VALIDATE((mod != 0), "Invalid modifier: %c", byte, {
      return;
    });
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
/// @param special    Replace |keycodes|, e.g. <CR> becomes a "\r" char.
/// @see replace_termcodes
/// @see cpoptions
String nvim_replace_termcodes(String str, Boolean from_part, Boolean do_lt, Boolean special)
  FUNC_API_SINCE(1)
{
  if (str.size == 0) {
    // Empty string
    return (String) { .data = NULL, .size = 0 };
  }

  int flags = 0;
  if (from_part) {
    flags |= REPTERM_FROM_PART;
  }
  if (do_lt) {
    flags |= REPTERM_DO_LT;
  }
  if (!special) {
    flags |= REPTERM_NO_SPECIAL;
  }

  char *ptr = NULL;
  replace_termcodes(str.data, str.size, &ptr, flags, NULL, CPO_TO_CPO_FLAGS);
  return cstr_as_string(ptr);
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
  MAXSIZE_TEMP_ARRAY(args, 3);
  ADD_C(args, STRING_OBJ(msg));
  ADD_C(args, INTEGER_OBJ(log_level));
  ADD_C(args, DICTIONARY_OBJ(opts));

  return NLUA_EXEC_STATIC("return vim.notify(...)", args, err);
}

/// Calculates the number of display cells occupied by `text`.
/// Control characters including <Tab> count as one cell.
///
/// @param text       Some text
/// @param[out] err   Error details, if any
/// @return Number of cells
Integer nvim_strwidth(String text, Error *err)
  FUNC_API_SINCE(1)
{
  VALIDATE_S((text.size <= INT_MAX), "text length", "(too long)", {
    return 0;
  });

  return (Integer)mb_string2cells(text.data);
}

/// Gets the paths contained in |runtime-search-path|.
///
/// @return List of paths
ArrayOf(String) nvim_list_runtime_paths(Error *err)
  FUNC_API_SINCE(1)
{
  return nvim_get_runtime_file(NULL_STRING, true, err);
}

Array nvim__runtime_inspect(void)
{
  return runtime_inspect();
}

/// Find files in runtime directories
///
/// "name" can contain wildcards. For example
/// nvim_get_runtime_file("colors/*.vim", true) will return all color
/// scheme files. Always use forward slashes (/) in the search pattern for
/// subdirectories regardless of platform.
///
/// It is not an error to not find any files. An empty array is returned then.
///
/// @param name pattern of files to search for
/// @param all whether to return all matches or only the first
/// @return list of absolute paths to the found files
ArrayOf(String) nvim_get_runtime_file(String name, Boolean all, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_FAST
{
  Array rv = ARRAY_DICT_INIT;

  int flags = DIP_DIRFILE | (all ? DIP_ALL : 0);

  TRY_WRAP(err, {
    do_in_runtimepath((name.size ? name.data : ""), flags, find_runtime_cb, &rv);
  });
  return rv;
}

static void find_runtime_cb(char *fname, void *cookie)
{
  Array *rv = (Array *)cookie;
  if (fname != NULL) {
    ADD(*rv, CSTR_TO_OBJ(fname));
  }
}

String nvim__get_lib_dir(void)
{
  return cstr_as_string(get_lib_dir());
}

/// Find files in runtime directories
///
/// @param pat pattern of files to search for
/// @param all whether to return all matches or only the first
/// @param opts is_lua: only search Lua subdirs
/// @return list of absolute paths to the found files
ArrayOf(String) nvim__get_runtime(Array pat, Boolean all, Dict(runtime) *opts, Error *err)
  FUNC_API_SINCE(8)
  FUNC_API_FAST
{
  bool is_lua = api_object_to_bool(opts->is_lua, "is_lua", false, err);
  bool source = api_object_to_bool(opts->do_source, "do_source", false, err);
  VALIDATE((!source || nlua_is_deferred_safe()), "%s", "'do_source' used in fast callback", {});
  if (ERROR_SET(err)) {
    return (Array)ARRAY_DICT_INIT;
  }

  ArrayOf(String) res = runtime_get_named(is_lua, pat, all);

  if (source) {
    for (size_t i = 0; i < res.size; i++) {
      String name = res.items[i].data.string;
      (void)do_source(name.data, false, DOSO_NONE, NULL);
    }
  }

  return res;
}

/// Changes the global working directory.
///
/// @param dir      Directory path
/// @param[out] err Error details, if any
void nvim_set_current_dir(String dir, Error *err)
  FUNC_API_SINCE(1)
{
  VALIDATE_S((dir.size < MAXPATHL), "directory name", "(too long)", {
    return;
  });

  char string[MAXPATHL];
  memcpy(string, dir.data, dir.size);
  string[dir.size] = NUL;

  try_start();

  if (!changedir_func(string, kCdScopeGlobal)) {
    if (!try_end(err)) {
      api_set_error(err, kErrorTypeException, "Failed to change directory");
    }
    return;
  }

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
  dictitem_T *di = tv_dict_find(&globvardict, name.data, (ptrdiff_t)name.size);
  if (di == NULL) {  // try to autoload script
    bool found = script_autoload(name.data, name.size, false) && !aborting();
    VALIDATE(found, "Key not found: %s", name.data, {
      return (Object)OBJECT_INIT;
    });
    di = tv_dict_find(&globvardict, name.data, (ptrdiff_t)name.size);
  }
  VALIDATE((di != NULL), "Key not found: %s", name.data, {
    return (Object)OBJECT_INIT;
  });
  return vim_to_object(&di->di_tv);
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

/// Echo a message.
///
/// @param chunks  A list of [text, hl_group] arrays, each representing a
///                text chunk with specified highlight. `hl_group` element
///                can be omitted for no highlight.
/// @param history  if true, add to |message-history|.
/// @param opts  Optional parameters.
///          - verbose: Message was printed as a result of 'verbose' option
///            if Nvim was invoked with -V3log_file, the message will be
///            redirected to the log_file and suppressed from direct output.
void nvim_echo(Array chunks, Boolean history, Dict(echo_opts) *opts, Error *err)
  FUNC_API_SINCE(7)
{
  HlMessage hl_msg = parse_hl_msg(chunks, err);
  if (ERROR_SET(err)) {
    goto error;
  }

  bool verbose = api_object_to_bool(opts->verbose, "verbose", false, err);

  if (verbose) {
    verbose_enter();
  }

  msg_multiattr(hl_msg, history ? "echomsg" : "echo", history);

  if (verbose) {
    verbose_leave();
    verbose_stop();  // flush now
  }

  if (history) {
    // history takes ownership
    return;
  }

error:
  hl_msg_free(hl_msg);
}

/// Writes a message to the Vim output buffer. Does not append "\n", the
/// message is buffered (won't display) until a linefeed is written.
///
/// @param str Message
void nvim_out_write(String str)
  FUNC_API_SINCE(1)
{
  write_msg(str, false, false);
}

/// Writes a message to the Vim error buffer. Does not append "\n", the
/// message is buffered (won't display) until a linefeed is written.
///
/// @param str Message
void nvim_err_write(String str)
  FUNC_API_SINCE(1)
{
  write_msg(str, true, false);
}

/// Writes a message to the Vim error buffer. Appends "\n", so the buffer is
/// flushed (and displayed).
///
/// @param str Message
/// @see nvim_err_write()
void nvim_err_writeln(String str)
  FUNC_API_SINCE(1)
{
  write_msg(str, true, true);
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
    set_option_value("bufhidden", STATIC_CSTR_AS_OPTVAL("hide"), OPT_LOCAL);
    set_option_value("buftype", STATIC_CSTR_AS_OPTVAL("nofile"), OPT_LOCAL);
    set_option_value("swapfile", BOOLEAN_OPTVAL(false), OPT_LOCAL);
    set_option_value("modeline", BOOLEAN_OPTVAL(false), OPT_LOCAL);  // 'nomodeline'
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
/// Then |nvim_chan_send()| can be called immediately to process sequences
/// in a virtual terminal having the intended size.
///
/// @param buffer the buffer to use (expected to be empty)
/// @param opts   Optional parameters.
///          - on_input: Lua callback for input sent, i e keypresses in terminal
///            mode. Note: keypresses are sent raw as they would be to the pty
///            master end. For instance, a carriage return is sent
///            as a "\r", not as a "\n". |textlock| applies. It is possible
///            to call |nvim_chan_send()| directly in the callback however.
///                 ["input", term, bufnr, data]
/// @param[out] err Error details, if any
/// @return Channel id, or 0 on error
Integer nvim_open_term(Buffer buffer, DictionaryOf(LuaRef) opts, Error *err)
  FUNC_API_SINCE(7)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }

  LuaRef cb = LUA_NOREF;
  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("on_input", k.data)) {
      VALIDATE_T("on_input", kObjectTypeLuaRef, v->type, {
        return 0;
      });
      cb = v->data.luaref;
      v->data.luaref = LUA_NOREF;
      break;
    } else {
      VALIDATE_S(false, "'opts' key", k.data, {});
    }
  }

  TerminalOptions topts;
  Channel *chan = channel_alloc(kChannelStreamInternal);
  chan->stream.internal.cb = cb;
  chan->stream.internal.closed = false;
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
  return (Integer)chan->id;
}

static void term_write(char *buf, size_t size, void *data)  // NOLINT(readability-non-const-parameter)
{
  Channel *chan = data;
  LuaRef cb = chan->stream.internal.cb;
  if (cb == LUA_NOREF) {
    return;
  }
  MAXSIZE_TEMP_ARRAY(args, 3);
  ADD_C(args, INTEGER_OBJ((Integer)chan->id));
  ADD_C(args, BUFFER_OBJ(terminal_buf(chan->term)));
  ADD_C(args, STRING_OBJ(((String){ .data = buf, .size = size })));
  textlock++;
  nlua_call_ref(cb, "input", args, false, NULL);
  textlock--;
}

static void term_resize(uint16_t width, uint16_t height, void *data)
{
  // TODO(bfredl): Lua callback
}

static void term_close(void *data)
{
  Channel *chan = data;
  terminal_destroy(&chan->term);
  api_free_luaref(chan->stream.internal.cb);
  chan->stream.internal.cb = LUA_NOREF;
  channel_decref(chan);
}

/// Send data to channel `id`. For a job, it writes it to the
/// stdin of the process. For the stdio channel |channel-stdio|,
/// it writes to Nvim's stdout.  For an internal terminal instance
/// (|nvim_open_term()|) it writes directly to terminal output.
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
  VALIDATE(!error, "%s", error, {});
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

  VALIDATE_INT((phase >= -1 && phase <= 3), "phase", phase, {
    return false;
  });
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
  if (!(State & (MODE_CMDLINE | MODE_INSERT)) && (phase == -1 || phase == 1)) {
    ResetRedobuff();
    AppendCharToRedobuff('a');  // Dot-repeat.
  }
  // vim.paste() decides if client should cancel.  Errors do NOT cancel: we
  // want to drain remaining chunks (rather than divert them to main input).
  cancel = (rv.type == kObjectTypeBoolean && !rv.data.boolean);
  if (!cancel && !(State & MODE_CMDLINE)) {  // Dot-repeat.
    for (size_t i = 0; i < lines.size; i++) {
      String s = lines.items[i].data.string;
      assert(s.size <= INT_MAX);
      AppendToRedobuffLit(s.data, (int)s.size);
      // readfile()-style: "\n" is indicated by presence of N+1 item.
      if (i + 1 < lines.size) {
        AppendCharToRedobuff(NL);
      }
    }
  }
  if (!(State & (MODE_CMDLINE | MODE_INSERT)) && (phase == -1 || phase == 3)) {
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
void nvim_put(ArrayOf(String) lines, String type, Boolean after, Boolean follow, Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_CHECK_TEXTLOCK
{
  yankreg_T *reg = xcalloc(1, sizeof(yankreg_T));
  VALIDATE_S((prepare_yankreg_from_object(reg, type, lines.size)), "type", type.data, {
    goto cleanup;
  });
  if (lines.size == 0) {
    goto cleanup;  // Nothing to do.
  }

  for (size_t i = 0; i < lines.size; i++) {
    VALIDATE_T("line", kObjectTypeString, lines.items[i].type, {
      goto cleanup;
    });
    String line = lines.items[i].data.string;
    reg->y_array[i] = xmemdupz(line.data, line.size);
    memchrsub(reg->y_array[i], NUL, NL, line.size);
  }

  finish_yankreg_from_object(reg, false);

  TRY_WRAP(err, {
    bool VIsual_was_active = VIsual_active;
    msg_silent++;  // Avoid "N more lines" message.
    do_put(0, reg, after ? FORWARD : BACKWARD, 1, follow ? PUT_CURSEND : 0);
    msg_silent--;
    VIsual_active = VIsual_was_active;
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
/// <pre>vim
///     :echo nvim_get_color_by_name("Pink")
///     :echo nvim_get_color_by_name("#cbcbcb")
/// </pre>
///
/// @param name Color name or "#rrggbb" string
/// @return 24-bit RGB value, or -1 for invalid argument.
Integer nvim_get_color_by_name(String name)
  FUNC_API_SINCE(1)
{
  int dummy;
  return name_to_color(name.data, &dummy);
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
Dictionary nvim_get_context(Dict(context) *opts, Error *err)
  FUNC_API_SINCE(6)
{
  Array types = ARRAY_DICT_INIT;
  if (HAS_KEY(opts->types)) {
    VALIDATE_T("types", kObjectTypeArray, opts->types.type, {
      return (Dictionary)ARRAY_DICT_INIT;
    });
    types = opts->types.data.array;
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
          VALIDATE_S(false, "type", s, {
            return (Dictionary)ARRAY_DICT_INIT;
          });
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
  char modestr[MODE_MAX_LENGTH];
  get_mode(modestr);
  bool blocked = input_blocking();

  PUT(rv, "mode", CSTR_TO_OBJ(modestr));
  PUT(rv, "blocking", BOOLEAN_OBJ(blocked));

  return rv;
}

/// Gets a list of global (non-buffer-local) |mapping| definitions.
///
/// @param  mode       Mode short-name ("n", "i", "v", ...)
/// @returns Array of |maparg()|-like dictionaries describing mappings.
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
/// Unlike |:map|, leading/trailing whitespace is accepted as part of the {lhs} or {rhs}.
/// Empty {rhs} is |<Nop>|. |keycodes| are replaced as usual.
///
/// Example:
/// <pre>vim
///     call nvim_set_keymap('n', ' <NL>', '', {'nowait': v:true})
/// </pre>
///
/// is equivalent to:
/// <pre>vim
///     nmap <nowait> <Space><NL> <Nop>
/// </pre>
///
/// @param channel_id
/// @param  mode  Mode short-name (map command prefix: "n", "i", "v", "x", …)
///               or "!" for |:map!|, or empty string for |:map|.
///               "ia", "ca" or "!a" for abbreviation in Insert mode, Cmdline mode, or both, respectively
/// @param  lhs   Left-hand-side |{lhs}| of the mapping.
/// @param  rhs   Right-hand-side |{rhs}| of the mapping.
/// @param  opts  Optional parameters map: Accepts all |:map-arguments| as keys except |<buffer>|,
///               values are booleans (default false). Also:
///               - "noremap" non-recursive mapping |:noremap|
///               - "desc" human-readable description.
///               - "callback" Lua function called in place of {rhs}.
///               - "replace_keycodes" (boolean) When "expr" is true, replace keycodes in the
///                 resulting string (see |nvim_replace_termcodes()|). Returning nil from the Lua
///                 "callback" is equivalent to returning an empty string.
/// @param[out]   err   Error details, if any.
void nvim_set_keymap(uint64_t channel_id, String mode, String lhs, String rhs, Dict(keymap) *opts,
                     Error *err)
  FUNC_API_SINCE(6)
{
  modify_keymap(channel_id, -1, false, mode, lhs, rhs, opts, err);
}

/// Unmaps a global |mapping| for the given mode.
///
/// To unmap a buffer-local mapping, use |nvim_buf_del_keymap()|.
///
/// @see |nvim_set_keymap()|
void nvim_del_keymap(uint64_t channel_id, String mode, String lhs, Error *err)
  FUNC_API_SINCE(6)
{
  nvim_buf_del_keymap(channel_id, -1, mode, lhs, err);
}

/// Returns a 2-tuple (Array), where item 0 is the current channel id and item
/// 1 is the |api-metadata| map (Dictionary).
///
/// @returns 2-tuple [{channel-id}, {api-metadata}]
Array nvim_get_api_info(uint64_t channel_id, Arena *arena)
  FUNC_API_SINCE(1) FUNC_API_FAST FUNC_API_REMOTE_ONLY
{
  Array rv = arena_array(arena, 2);

  assert(channel_id <= INT64_MAX);
  ADD_C(rv, INTEGER_OBJ((int64_t)channel_id));
  ADD_C(rv, DICTIONARY_OBJ(api_metadata()));

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
void nvim_set_client_info(uint64_t channel_id, String name, Dictionary version, String type,
                          Dictionary methods, Dictionary attributes, Error *err)
  FUNC_API_SINCE(4) FUNC_API_REMOTE_ONLY
{
  Dictionary info = ARRAY_DICT_INIT;
  PUT(info, "name", copy_object(STRING_OBJ(name), NULL));

  version = copy_dictionary(version, NULL);
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

  PUT(info, "type", copy_object(STRING_OBJ(type), NULL));
  PUT(info, "methods", DICTIONARY_OBJ(copy_dictionary(methods, NULL)));
  PUT(info, "attributes", DICTIONARY_OBJ(copy_dictionary(attributes, NULL)));

  rpc_set_client_info(channel_id, info);
}

/// Gets information about a channel.
///
/// @returns Dictionary describing a channel, with these keys:
///    - "id"       Channel id.
///    - "argv"     (optional) Job arguments list.
///    - "stream"   Stream underlying the channel.
///         - "stdio"      stdin and stdout of this Nvim instance
///         - "stderr"     stderr of this Nvim instance
///         - "socket"     TCP/IP socket or named pipe
///         - "job"        Job with communication over its stdio.
///    -  "mode"    How data received on the channel is interpreted.
///         - "bytes"      Send and receive raw bytes.
///         - "terminal"   |terminal| instance interprets ASCII sequences.
///         - "rpc"        |RPC| communication on the channel is active.
///    -  "pty"     (optional) Name of pseudoterminal. On a POSIX system this
///                 is a device path like "/dev/pts/1". If the name is unknown,
///                 the key will still be present if a pty is used (e.g. for
///                 conpty on Windows).
///    -  "buffer"  (optional) Buffer with connected |terminal| instance.
///    -  "client"  (optional) Info about the peer (client on the other end of
///                 the RPC channel), if provided by it via
///                 |nvim_set_client_info()|.
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
///    processing which have such side effects, e.g. |:sleep| may wake timers).
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
Array nvim_call_atomic(uint64_t channel_id, Array calls, Arena *arena, Error *err)
  FUNC_API_SINCE(1) FUNC_API_REMOTE_ONLY
{
  Array rv = arena_array(arena, 2);
  Array results = arena_array(arena, calls.size);
  Error nested_error = ERROR_INIT;

  size_t i;  // also used for freeing the variables
  for (i = 0; i < calls.size; i++) {
    VALIDATE_T("'calls' item", kObjectTypeArray, calls.items[i].type, {
      goto theend;
    });
    Array call = calls.items[i].data.array;
    VALIDATE_EXP((call.size == 2), "'calls' item", "2-item Array", NULL, {
      goto theend;
    });
    VALIDATE_T("name", kObjectTypeString, call.items[0].type, {
      goto theend;
    });
    String name = call.items[0].data.string;
    VALIDATE_T("call args", kObjectTypeArray, call.items[1].type, {
      goto theend;
    });
    Array args = call.items[1].data.array;

    MsgpackRpcRequestHandler handler =
      msgpack_rpc_get_handler_for(name.data,
                                  name.size,
                                  &nested_error);

    if (ERROR_SET(&nested_error)) {
      break;
    }

    Object result = handler.fn(channel_id, args, arena, &nested_error);
    if (ERROR_SET(&nested_error)) {
      // error handled after loop
      break;
    }
    // TODO(bfredl): wasteful copy. It could be avoided to encoding to msgpack
    // directly here. But `result` might become invalid when next api function
    // is called in the loop.
    ADD_C(results, copy_object(result, arena));
    if (!handler.arena_return) {
      api_free_object(result);
    }
  }

  ADD_C(rv, ARRAY_OBJ(results));
  if (ERROR_SET(&nested_error)) {
    Array errval = arena_array(arena, 3);
    ADD_C(errval, INTEGER_OBJ((Integer)i));
    ADD_C(errval, INTEGER_OBJ(nested_error.type));
    ADD_C(errval, STRING_OBJ(copy_string(cstr_as_string(nested_error.msg), arena)));
    ADD_C(rv, ARRAY_OBJ(errval));
  } else {
    ADD_C(rv, NIL);
  }

theend:
  api_clear_error(&nested_error);
  return rv;
}

/// Writes a message to vim output or error buffer. The string is split
/// and flushed after each newline. Incomplete lines are kept for writing
/// later.
///
/// @param message  Message to write
/// @param to_err   true: message is an error (uses `emsg` instead of `msg`)
/// @param writeln  Append a trailing newline
static void write_msg(String message, bool to_err, bool writeln)
{
  static StringBuilder out_line_buf = KV_INITIAL_VALUE;
  static StringBuilder err_line_buf = KV_INITIAL_VALUE;

#define PUSH_CHAR(c, line_buf, msg) \
  if (kv_max(line_buf) == 0) { \
    kv_resize(line_buf, LINE_BUFFER_MIN_SIZE); \
  } \
  if (c == NL) { \
    kv_push(line_buf, NUL); \
    msg(line_buf.items); \
    kv_drop(line_buf, kv_size(line_buf)); \
    kv_resize(line_buf, LINE_BUFFER_MIN_SIZE); \
  } else { \
    kv_push(line_buf, c); \
  }

  no_wait_return++;
  for (uint32_t i = 0; i < message.size; i++) {
    if (got_int) {
      break;
    }
    if (to_err) {
      PUSH_CHAR(message.data[i], err_line_buf, emsg);
    } else {
      PUSH_CHAR(message.data[i], out_line_buf, msg);
    }
  }
  if (writeln) {
    if (to_err) {
      PUSH_CHAR(NL, err_line_buf, emsg);
    } else {
      PUSH_CHAR(NL, out_line_buf, msg);
    }
  }
  no_wait_return--;
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
  return copy_object(obj, NULL);
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
  return copy_array(arr, NULL);
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
  return copy_dictionary(dct, NULL);
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
  PUT(rv, "log_skip", INTEGER_OBJ(g_stats.log_skip));
  PUT(rv, "lua_refcount", INTEGER_OBJ(nlua_get_global_ref_count()));
  PUT(rv, "redraw", INTEGER_OBJ(g_stats.redraw));
  PUT(rv, "arena_alloc_count", INTEGER_OBJ((Integer)arena_alloc_count));
  return rv;
}

/// Gets a list of dictionaries representing attached UIs.
///
/// @return Array of UI dictionaries, each with these keys:
///   - "height"  Requested height of the UI
///   - "width"   Requested width of the UI
///   - "rgb"     true if the UI uses RGB colors (false implies |cterm-colors|)
///   - "ext_..." Requested UI extensions, see |ui-option|
///   - "chan"    |channel-id| of remote UI
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

  VALIDATE_INT((pid > 0 && pid <= INT_MAX), "pid", pid, {
    goto end;
  });

  size_t proc_count;
  int rv = os_proc_children((int)pid, &proc_list, &proc_count);
  if (rv == 2) {
    // syscall failed (possibly because of kernel options), try shelling out.
    DLOG("fallback to vim._os_proc_children()");
    MAXSIZE_TEMP_ARRAY(a, 1);
    ADD(a, INTEGER_OBJ(pid));
    Object o = NLUA_EXEC_STATIC("return vim._os_proc_children(...)", a, err);
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

  VALIDATE_INT((pid > 0 && pid <= INT_MAX), "pid", pid, {
    return NIL;
  });

#ifdef MSWIN
  rvobj.data.dictionary = os_proc_info((int)pid);
  if (rvobj.data.dictionary.size == 0) {  // Process not found.
    return NIL;
  }
#else
  // Cross-platform process info APIs are miserable, so use `ps` instead.
  MAXSIZE_TEMP_ARRAY(a, 1);
  ADD(a, INTEGER_OBJ(pid));
  Object o = NLUA_EXEC_STATIC("return vim._os_proc_info(...)", a, err);
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

/// Selects an item in the completion popup menu.
///
/// If neither |ins-completion| nor |cmdline-completion| popup menu is active
/// this API call is silently ignored.
/// Useful for an external UI using |ui-popupmenu| to control the popup menu with the mouse.
/// Can also be used in a mapping; use <Cmd> |:map-cmd| or a Lua mapping to ensure the mapping
/// doesn't end completion mode.
///
/// @param item    Index (zero-based) of the item to select. Value of -1 selects nothing
///                and restores the original text.
/// @param insert  For |ins-completion|, whether the selection should be inserted in the buffer.
///                Ignored for |cmdline-completion|.
/// @param finish  Finish the completion and dismiss the popup menu. Implies {insert}.
/// @param opts    Optional parameters. Reserved for future use.
/// @param[out] err Error details, if any
void nvim_select_popupmenu_item(Integer item, Boolean insert, Boolean finish, Dictionary opts,
                                Error *err)
  FUNC_API_SINCE(6)
{
  VALIDATE((opts.size == 0), "%s", "opts dict isn't empty", {
    return;
  });

  if (finish) {
    insert = true;
  }

  pum_ext_select_item((int)item, insert, finish);
}

/// NB: if your UI doesn't use hlstate, this will not return hlstate first time
Array nvim__inspect_cell(Integer grid, Integer row, Integer col, Arena *arena, Error *err)
{
  Array ret = ARRAY_DICT_INIT;

  // TODO(bfredl): if grid == 0 we should read from the compositor's buffer.
  // The only problem is that it does not yet exist.
  ScreenGrid *g = &default_grid;
  if (grid == pum_grid.handle) {
    g = &pum_grid;
  } else if (grid > 1) {
    win_T *wp = get_win_by_grid_handle((handle_T)grid);
    VALIDATE_INT((wp != NULL && wp->w_grid_alloc.chars != NULL), "grid handle", grid, {
      return ret;
    });
    g = &wp->w_grid_alloc;
  }

  if (row < 0 || row >= g->rows
      || col < 0 || col >= g->cols) {
    return ret;
  }
  ret = arena_array(arena, 3);
  size_t off = g->line_offset[(size_t)row] + (size_t)col;
  ADD_C(ret, CSTR_AS_OBJ((char *)g->chars[off]));
  int attr = g->attrs[off];
  ADD_C(ret, DICTIONARY_OBJ(hl_get_attr_by_id(attr, true, arena, err)));
  // will not work first time
  if (!highlight_use_hlstate()) {
    ADD_C(ret, ARRAY_OBJ(hl_inspect(attr)));
  }
  return ret;
}

void nvim__screenshot(String path)
  FUNC_API_FAST
{
  ui_call_screenshot(path);
}

Object nvim__unpack(String str, Error *err)
  FUNC_API_FAST
{
  return unpack(str.data, str.size, err);
}

/// Deletes an uppercase/file named mark. See |mark-motions|.
///
/// @note fails with error if a lowercase or buffer local named mark is used.
/// @param name       Mark name
/// @return true if the mark was deleted, else false.
/// @see |nvim_buf_del_mark()|
/// @see |nvim_get_mark()|
Boolean nvim_del_mark(String name, Error *err)
  FUNC_API_SINCE(8)
{
  bool res = false;
  VALIDATE_S((name.size == 1), "mark name (must be a single char)", name.data, {
    return res;
  });
  // Only allow file/uppercase marks
  // TODO(muniter): Refactor this ASCII_ISUPPER macro to a proper function
  VALIDATE_S((ASCII_ISUPPER(*name.data) || ascii_isdigit(*name.data)),
             "mark name (must be file/uppercase)", name.data, {
    return res;
  });
  res = set_mark(NULL, name, 0, 0, err);
  return res;
}

/// Return a tuple (row, col, buffer, buffername) representing the position of
/// the uppercase/file named mark. See |mark-motions|.
///
/// Marks are (1,0)-indexed. |api-indexing|
///
/// @note fails with error if a lowercase or buffer local named mark is used.
/// @param name       Mark name
/// @param opts       Optional parameters. Reserved for future use.
/// @return 4-tuple (row, col, buffer, buffername), (0, 0, 0, '') if the mark is
/// not set.
/// @see |nvim_buf_set_mark()|
/// @see |nvim_del_mark()|
Array nvim_get_mark(String name, Dictionary opts, Error *err)
  FUNC_API_SINCE(8)
{
  Array rv = ARRAY_DICT_INIT;

  VALIDATE_S((name.size == 1), "mark name (must be a single char)", name.data, {
    return rv;
  });
  VALIDATE_S((ASCII_ISUPPER(*name.data) || ascii_isdigit(*name.data)),
             "mark name (must be file/uppercase)", name.data, {
    return rv;
  });

  xfmark_T *mark = mark_get_global(false, *name.data);  // false avoids loading the mark buffer
  pos_T pos = mark->fmark.mark;
  bool allocated = false;
  int bufnr;
  char *filename;

  // Marks are from an open buffer it fnum is non zero
  if (mark->fmark.fnum != 0) {
    bufnr = mark->fmark.fnum;
    filename = buflist_nr2name(bufnr, true, true);
    allocated = true;
    // Marks comes from shada
  } else {
    filename = mark->fname;
    bufnr = 0;
  }

  bool exists = filename != NULL;
  Integer row;
  Integer col;

  if (!exists || pos.lnum <= 0) {
    if (allocated) {
      xfree(filename);
      allocated = false;
    }
    filename = "";
    bufnr = 0;
    row = 0;
    col = 0;
  } else {
    row = pos.lnum;
    col = pos.col;
  }

  ADD(rv, INTEGER_OBJ(row));
  ADD(rv, INTEGER_OBJ(col));
  ADD(rv, INTEGER_OBJ(bufnr));
  ADD(rv, CSTR_TO_OBJ(filename));

  if (allocated) {
    xfree(filename);
  }

  return rv;
}

/// Evaluates statusline string.
///
/// @param str Statusline string (see 'statusline').
/// @param opts Optional parameters.
///           - winid: (number) |window-ID| of the window to use as context for statusline.
///           - maxwidth: (number) Maximum width of statusline.
///           - fillchar: (string) Character to fill blank spaces in the statusline (see
///                                'fillchars'). Treated as single-width even if it isn't.
///           - highlights: (boolean) Return highlight information.
///           - use_winbar: (boolean) Evaluate winbar instead of statusline.
///           - use_tabline: (boolean) Evaluate tabline instead of statusline. When true, {winid}
///                                    is ignored. Mutually exclusive with {use_winbar}.
///           - use_statuscol_lnum: (number) Evaluate statuscolumn for this line number instead of statusline.
///
/// @param[out] err Error details, if any.
/// @return Dictionary containing statusline information, with these keys:
///       - str: (string) Characters that will be displayed on the statusline.
///       - width: (number) Display width of the statusline.
///       - highlights: Array containing highlight information of the statusline. Only included when
///                     the "highlights" key in {opts} is true. Each element of the array is a
///                     |Dictionary| with these keys:
///           - start: (number) Byte index (0-based) of first character that uses the highlight.
///           - group: (string) Name of highlight group.
Dictionary nvim_eval_statusline(String str, Dict(eval_statusline) *opts, Error *err)
  FUNC_API_SINCE(8) FUNC_API_FAST
{
  Dictionary result = ARRAY_DICT_INIT;

  int maxwidth;
  int fillchar = 0;
  int use_bools = 0;
  int statuscol_lnum = 0;
  Window window = 0;
  bool use_winbar = false;
  bool use_tabline = false;
  bool highlights = false;

  if (str.size < 2 || memcmp(str.data, "%!", 2) != 0) {
    const char *const errmsg = check_stl_option(str.data);
    VALIDATE(!errmsg, "%s", errmsg, {
      return result;
    });
  }

  if (HAS_KEY(opts->winid)) {
    VALIDATE_T("winid", kObjectTypeInteger, opts->winid.type, {
      return result;
    });

    window = (Window)opts->winid.data.integer;
  }
  if (HAS_KEY(opts->fillchar)) {
    VALIDATE_T("fillchar", kObjectTypeString, opts->fillchar.type, {
      return result;
    });
    VALIDATE_EXP((opts->fillchar.data.string.size != 0
                  && ((size_t)utf_ptr2len(opts->fillchar.data.string.data)
                      == opts->fillchar.data.string.size)),
                 "fillchar", "single character", NULL, {
      return result;
    });
    fillchar = utf_ptr2char(opts->fillchar.data.string.data);
  }
  if (HAS_KEY(opts->highlights)) {
    highlights = api_object_to_bool(opts->highlights, "highlights", false, err);

    if (ERROR_SET(err)) {
      return result;
    }
  }
  if (HAS_KEY(opts->use_winbar)) {
    use_winbar = api_object_to_bool(opts->use_winbar, "use_winbar", false, err);
    if (ERROR_SET(err)) {
      return result;
    }
    use_bools++;
  }
  if (HAS_KEY(opts->use_tabline)) {
    use_tabline = api_object_to_bool(opts->use_tabline, "use_tabline", false, err);
    if (ERROR_SET(err)) {
      return result;
    }
    use_bools++;
  }

  win_T *wp = use_tabline ? curwin : find_window_by_handle(window, err);
  if (wp == NULL) {
    api_set_error(err, kErrorTypeException, "unknown winid %d", window);
    return result;
  }

  if (HAS_KEY(opts->use_statuscol_lnum)) {
    VALIDATE_T("use_statuscol_lnum", kObjectTypeInteger, opts->use_statuscol_lnum.type, {
      return result;
    });
    statuscol_lnum = (int)opts->use_statuscol_lnum.data.integer;
    VALIDATE_RANGE(statuscol_lnum > 0 && statuscol_lnum <= wp->w_buffer->b_ml.ml_line_count,
                   "use_statuscol_lnum", {
      return result;
    });
    use_bools++;
  }
  VALIDATE(use_bools <= 1, "%s",
           "Can only use one of 'use_winbar', 'use_tabline' and 'use_statuscol_lnum'", {
    return result;
  });

  int stc_hl_id = 0;
  statuscol_T statuscol = { 0 };
  SignTextAttrs sattrs[SIGN_SHOW_MAX] = { 0 };

  if (use_tabline) {
    fillchar = ' ';
  } else {
    if (fillchar == 0) {
      if (use_winbar) {
        fillchar = wp->w_p_fcs_chars.wbr;
      } else {
        int attr;
        fillchar = fillchar_status(&attr, wp);
      }
    }
    if (statuscol_lnum) {
      HlPriId line = { 0 };
      HlPriId cul  = { 0 };
      HlPriId num  = { 0 };
      linenr_T lnum = statuscol_lnum;
      int num_signs = buf_get_signattrs(wp->w_buffer, lnum, sattrs, &num, &line, &cul);
      decor_redraw_signs(wp->w_buffer, lnum - 1, &num_signs, sattrs, &num, &line, &cul);
      wp->w_scwidth = win_signcol_count(wp);

      statuscol.sattrs = sattrs;
      statuscol.foldinfo = fold_info(wp, lnum);
      wp->w_cursorline = win_cursorline_standout(wp) ? wp->w_cursor.lnum : 0;

      if (wp->w_p_cul) {
        if (statuscol.foldinfo.fi_level != 0 && statuscol.foldinfo.fi_lines > 0) {
          wp->w_cursorline = statuscol.foldinfo.fi_lnum;
        }
        statuscol.use_cul = lnum == wp->w_cursorline && (wp->w_p_culopt_flags & CULOPT_NBR);
      }

      statuscol.sign_cul_id = statuscol.use_cul ? cul.hl_id : 0;
      if (num.hl_id) {
        stc_hl_id = num.hl_id;
      } else if (statuscol.use_cul) {
        stc_hl_id = HLF_CLN + 1;
      } else if (wp->w_p_rnu) {
        stc_hl_id = (lnum < wp->w_cursor.lnum ? HLF_LNA : HLF_LNB) + 1;
      } else {
        stc_hl_id = HLF_N + 1;
      }

      set_vim_var_nr(VV_LNUM, lnum);
      set_vim_var_nr(VV_RELNUM, labs(get_cursor_rel_lnum(wp, lnum)));
      set_vim_var_nr(VV_VIRTNUM, 0);
    }
  }

  if (HAS_KEY(opts->maxwidth)) {
    VALIDATE_T("maxwidth", kObjectTypeInteger, opts->maxwidth.type, {
      return result;
    });

    maxwidth = (int)opts->maxwidth.data.integer;
  } else {
    maxwidth = statuscol_lnum ? win_col_off(wp)
               : (use_tabline || (!use_winbar && global_stl_height() > 0)) ? Columns : wp->w_width;
  }

  char buf[MAXPATHL];
  stl_hlrec_t *hltab;

  // Temporarily reset 'cursorbind' to prevent side effects from moving the cursor away and back.
  int p_crb_save = wp->w_p_crb;
  wp->w_p_crb = false;

  int width = build_stl_str_hl(wp,
                               buf,
                               sizeof(buf),
                               str.data,
                               NULL,
                               0,
                               fillchar,
                               maxwidth,
                               highlights ? &hltab : NULL,
                               NULL,
                               statuscol_lnum ? &statuscol : NULL);

  PUT(result, "width", INTEGER_OBJ(width));

  // Restore original value of 'cursorbind'
  wp->w_p_crb = p_crb_save;

  if (highlights) {
    Array hl_values = ARRAY_DICT_INIT;
    const char *grpname;
    char user_group[15];  // strlen("User") + strlen("2147483647") + NUL

    // If first character doesn't have a defined highlight,
    // add the default highlight at the beginning of the highlight list
    if (hltab->start == NULL || (hltab->start - buf) != 0) {
      Dictionary hl_info = ARRAY_DICT_INIT;
      grpname = get_default_stl_hl(use_tabline ? NULL : wp, use_winbar, stc_hl_id);

      PUT(hl_info, "start", INTEGER_OBJ(0));
      PUT(hl_info, "group", CSTR_TO_OBJ(grpname));

      ADD(hl_values, DICTIONARY_OBJ(hl_info));
    }

    for (stl_hlrec_t *sp = hltab; sp->start != NULL; sp++) {
      Dictionary hl_info = ARRAY_DICT_INIT;

      PUT(hl_info, "start", INTEGER_OBJ(sp->start - buf));

      if (sp->userhl == 0) {
        grpname = get_default_stl_hl(use_tabline ? NULL : wp, use_winbar, stc_hl_id);
      } else if (sp->userhl < 0) {
        grpname = syn_id2name(-sp->userhl);
      } else {
        snprintf(user_group, sizeof(user_group), "User%d", sp->userhl);
        grpname = user_group;
      }
      PUT(hl_info, "group", CSTR_TO_OBJ(grpname));
      ADD(hl_values, DICTIONARY_OBJ(hl_info));
    }
    PUT(result, "highlights", ARRAY_OBJ(hl_values));
  }
  PUT(result, "str", CSTR_TO_OBJ(buf));

  return result;
}

void nvim_error_event(uint64_t channel_id, Integer lvl, String data)
  FUNC_API_REMOTE_ONLY
{
  // TODO(bfredl): consider printing message to user, as will be relevant
  // if we fork nvim processes as async workers
  ELOG("async error on channel %" PRId64 ": %s", channel_id, data.size ? data.data : "");
}
