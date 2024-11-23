#include <assert.h>
#include <inttypes.h>
#include <lauxlib.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/buffer.h"
#include "nvim/api/deprecated.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/api/vim.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/channel.h"
#include "nvim/channel_defs.h"
#include "nvim/context.h"
#include "nvim/cursor.h"
#include "nvim/decoration.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/getchar_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/lua/treesitter.h"
#include "nvim/macros_defs.h"
#include "nvim/mapping.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/math.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/message_defs.h"
#include "nvim/move.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/msgpack_rpc/unpacker.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/input.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/proc.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/runtime.h"
#include "nvim/sign_defs.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/statusline.h"
#include "nvim/statusline_defs.h"
#include "nvim/strings.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/vim_defs.h"
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
/// @note When the `link` attribute is defined in the highlight definition
///       map, other attributes will not be taking effect (see |:hi-link|).
///
/// @param ns_id Get highlight groups for namespace ns_id |nvim_get_namespaces()|.
///              Use 0 to get global highlight groups |:highlight|.
/// @param opts  Options dict:
///                 - name: (string) Get a highlight definition by name.
///                 - id: (integer) Get a highlight definition by id.
///                 - link: (boolean, default true) Show linked group name instead of effective definition |:hi-link|.
///                 - create: (boolean, default true) When highlight group doesn't exist create it.
///
/// @param[out] err Error details, if any.
/// @return Highlight groups as a map from group name to a highlight definition map as in |nvim_set_hl()|,
///                   or only a single highlight definition map if requested by name or id.
Dict nvim_get_hl(Integer ns_id, Dict(get_highlight) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(11)
{
  return ns_get_hl_defs((NS)ns_id, opts, arena, err);
}

/// Sets a highlight group.
///
/// @note Unlike the `:highlight` command which can update a highlight group,
///       this function completely replaces the definition. For example:
///       `nvim_set_hl(0, 'Visual', {})` will clear the highlight group
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
///                - fg: color name or "#RRGGBB", see note.
///                - bg: color name or "#RRGGBB", see note.
///                - sp: color name or "#RRGGBB"
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
///                - force: if true force update the highlight group when it exists.
/// @param[out] err Error details, if any
///
// TODO(bfredl): val should take update vs reset flag
void nvim_set_hl(uint64_t channel_id, Integer ns_id, String name, Dict(highlight) *val, Error *err)
  FUNC_API_SINCE(7)
{
  int hl_id = syn_check_group(name.data, name.size);
  VALIDATE_S((hl_id != 0), "highlight name", name.data, {
    return;
  });
  int link_id = -1;

  // Setting URLs directly through highlight attributes is not supported
  if (HAS_KEY(val, highlight, url)) {
    api_free_string(val->url);
    val->url = NULL_STRING;
  }

  HlAttrs attrs = dict2hlattrs(val, true, &link_id, err);
  if (!ERROR_SET(err)) {
    WITH_SCRIPT_CONTEXT(channel_id, {
      ns_hl_def((NS)ns_id, hl_id, attrs, link_id, val);
    });
  }
}

/// Gets the active highlight namespace.
///
/// @param opts Optional parameters
///           - winid: (number) |window-ID| for retrieving a window's highlight
///             namespace. A value of -1 is returned when |nvim_win_set_hl_ns()|
///             has not been called for the window (or was called with a namespace
///             of -1).
/// @param[out] err Error details, if any
/// @return Namespace id, or -1
Integer nvim_get_hl_ns(Dict(get_ns) *opts, Error *err)
  FUNC_API_SINCE(12)
{
  if (HAS_KEY(opts, get_ns, winid)) {
    win_T *win = find_window_by_handle(opts->winid, err);
    if (!win) {
      return 0;
    }
    return win->w_ns_hl;
  } else {
    return ns_hl_global;
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
/// To input sequences like [<C-o>] use |nvim_replace_termcodes()| (typically
/// with escape_ks=false) to replace |keycodes|, then pass the result to
/// nvim_feedkeys().
///
/// Example:
///
/// ```vim
/// :let key = nvim_replace_termcodes("<C-o>", v:true, v:false, v:true)
/// :call nvim_feedkeys(key, 'n', v:false)
/// ```
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
  bool lowlevel = false;

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
    case 'L':
      lowlevel = true; break;
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
  if (lowlevel) {
    input_enqueue_raw(keys_esc, strlen(keys_esc));
  } else {
    ins_typebuf(keys_esc, (remap ? REMAP_YES : REMAP_NONE),
                insert ? 0 : typebuf.tb_len, !typed, false);
    if (vgetc_busy) {
      typebuf_was_filled = true;
    }
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

/// Queues raw user-input. Unlike |nvim_feedkeys()|, this uses a low-level input buffer and the call
/// is non-blocking (input is processed asynchronously by the eventloop).
///
/// To input blocks of text, |nvim_paste()| is much faster and should be preferred.
///
/// On execution error: does not fail, but updates v:errmsg.
///
/// @note |keycodes| like [<CR>] are translated, so "<" is special.
///       To input a literal "<", send [<LT>].
///
/// @note For mouse events use |nvim_input_mouse()|. The pseudokey form
///       `<LeftMouse><col,row>` is deprecated since |api-level| 6.
///
/// @param keys to be typed
/// @return Number of bytes actually written (can be fewer than
///         requested if the buffer becomes full).
Integer nvim_input(String keys)
  FUNC_API_SINCE(1) FUNC_API_FAST
{
  may_trigger_vim_suspend_resume(false);
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
///       (`<LeftMouse><col,row>`) of |nvim_input()| has the same limitation.
///
/// @param button Mouse button: one of "left", "right", "middle", "wheel", "move",
///               "x1", "x2".
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
  may_trigger_vim_suspend_resume(false);

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
  } else if (strequal(button.data, "x1")) {
    code = KE_X1MOUSE;
  } else if (strequal(button.data, "x2")) {
    code = KE_X2MOUSE;
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

/// Replaces terminal codes and |keycodes| ([<CR>], [<Esc>], ...) in a string with
/// the internal representation.
///
/// @param str        String to be converted.
/// @param from_part  Legacy Vim parameter. Usually true.
/// @param do_lt      Also translate [<lt>]. Ignored if `special` is false.
/// @param special    Replace |keycodes|, e.g. [<CR>] becomes a "\r" char.
/// @see replace_termcodes
/// @see cpoptions
String nvim_replace_termcodes(String str, Boolean from_part, Boolean do_lt, Boolean special)
  FUNC_API_SINCE(1) FUNC_API_RET_ALLOC
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
  replace_termcodes(str.data, str.size, &ptr, 0, flags, NULL, p_cpo);
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
Object nvim_exec_lua(String code, Array args, Arena *arena, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_REMOTE_ONLY
{
  // TODO(bfredl): convert directly from msgpack to lua and then back again
  return nlua_exec(code, args, kRetObject, arena, err);
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
Object nvim_notify(String msg, Integer log_level, Dict opts, Arena *arena, Error *err)
  FUNC_API_SINCE(7)
{
  MAXSIZE_TEMP_ARRAY(args, 3);
  ADD_C(args, STRING_OBJ(msg));
  ADD_C(args, INTEGER_OBJ(log_level));
  ADD_C(args, DICT_OBJ(opts));

  return NLUA_EXEC_STATIC("return vim.notify(...)", args, kRetObject, arena, err);
}

/// Calculates the number of display cells occupied by `text`.
/// Control characters including [<Tab>] count as one cell.
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
ArrayOf(String) nvim_list_runtime_paths(Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  return nvim_get_runtime_file(NULL_STRING, true, arena, err);
}

/// @nodoc
Array nvim__runtime_inspect(Arena *arena)
{
  return runtime_inspect(arena);
}

typedef struct {
  ArrayBuilder rv;
  Arena *arena;
} RuntimeCookie;

/// Finds files in runtime directories, in 'runtimepath' order.
///
/// "name" can contain wildcards. For example
/// `nvim_get_runtime_file("colors/*.{vim,lua}", true)` will return all color
/// scheme files. Always use forward slashes (/) in the search pattern for
/// subdirectories regardless of platform.
///
/// It is not an error to not find any files. An empty array is returned then.
///
/// @param name pattern of files to search for
/// @param all whether to return all matches or only the first
/// @return list of absolute paths to the found files
ArrayOf(String) nvim_get_runtime_file(String name, Boolean all, Arena *arena, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_FAST
{
  RuntimeCookie cookie = { .rv = ARRAY_DICT_INIT, .arena = arena, };
  kvi_init(cookie.rv);

  int flags = DIP_DIRFILE | (all ? DIP_ALL : 0);
  TryState tstate;

  try_enter(&tstate);
  do_in_runtimepath((name.size ? name.data : ""), flags, find_runtime_cb, &cookie);
  vim_ignored = try_leave(&tstate, err);

  return arena_take_arraybuilder(arena, &cookie.rv);
}

static bool find_runtime_cb(int num_fnames, char **fnames, bool all, void *c)
{
  RuntimeCookie *cookie = (RuntimeCookie *)c;
  for (int i = 0; i < num_fnames; i++) {
    // TODO(bfredl): consider memory management of gen_expand_wildcards() itself
    kvi_push(cookie->rv, CSTR_TO_ARENA_OBJ(cookie->arena, fnames[i]));
    if (!all) {
      return true;
    }
  }

  return num_fnames > 0;
}

/// @nodoc
String nvim__get_lib_dir(void)
  FUNC_API_RET_ALLOC
{
  return cstr_as_string(get_lib_dir());
}

/// Find files in runtime directories
///
/// @param pat pattern of files to search for
/// @param all whether to return all matches or only the first
/// @param opts is_lua: only search Lua subdirs
/// @return list of absolute paths to the found files
ArrayOf(String) nvim__get_runtime(Array pat, Boolean all, Dict(runtime) *opts, Arena *arena,
                                  Error *err)
  FUNC_API_SINCE(8)
  FUNC_API_FAST
{
  VALIDATE(!opts->do_source || nlua_is_deferred_safe(), "%s", "'do_source' used in fast callback",
           {});
  if (ERROR_SET(err)) {
    return (Array)ARRAY_DICT_INIT;
  }

  ArrayOf(String) res = runtime_get_named(opts->is_lua, pat, all, arena);

  if (opts->do_source) {
    for (size_t i = 0; i < res.size; i++) {
      String name = res.items[i].data.string;
      do_source(name.data, false, DOSO_NONE, NULL);
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
String nvim_get_current_line(Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  return buffer_get_line(curbuf->handle, curwin->w_cursor.lnum - 1, arena, err);
}

/// Sets the current line.
///
/// @param line     Line contents
/// @param[out] err Error details, if any
void nvim_set_current_line(String line, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  buffer_set_line(curbuf->handle, curwin->w_cursor.lnum - 1, line, arena, err);
}

/// Deletes the current line.
///
/// @param[out] err Error details, if any
void nvim_del_current_line(Arena *arena, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  buffer_del_line(curbuf->handle, curwin->w_cursor.lnum - 1, arena, err);
}

/// Gets a global (g:) variable.
///
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Variable value
Object nvim_get_var(String name, Arena *arena, Error *err)
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
  return vim_to_object(&di->di_tv, arena, true);
}

/// Sets a global (g:) variable.
///
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_set_var(String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  dict_set_var(&globvardict, name, value, false, false, NULL, err);
}

/// Removes a global (g:) variable.
///
/// @param name     Variable name
/// @param[out] err Error details, if any
void nvim_del_var(String name, Error *err)
  FUNC_API_SINCE(1)
{
  dict_set_var(&globvardict, name, NIL, true, false, NULL, err);
}

/// Gets a v: variable.
///
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return         Variable value
Object nvim_get_vvar(String name, Arena *arena, Error *err)
  FUNC_API_SINCE(1)
{
  return dict_get_value(&vimvardict, name, arena, err);
}

/// Sets a v: variable, if it is not readonly.
///
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
void nvim_set_vvar(String name, Object value, Error *err)
  FUNC_API_SINCE(6)
{
  dict_set_var(&vimvardict, name, value, false, false, NULL, err);
}

/// Echo a message.
///
/// @param chunks  A list of `[text, hl_group]` arrays, each representing a
///                text chunk with specified highlight group name or ID.
///                `hl_group` element can be omitted for no highlight.
/// @param history  if true, add to |message-history|.
/// @param opts  Optional parameters.
///          - verbose: Message is printed as a result of 'verbose' option.
///            If Nvim was invoked with -V3log_file, the message will be
///            redirected to the log_file and suppressed from direct output.
void nvim_echo(Array chunks, Boolean history, Dict(echo_opts) *opts, Error *err)
  FUNC_API_SINCE(7)
{
  HlMessage hl_msg = parse_hl_msg(chunks, err);
  if (ERROR_SET(err)) {
    goto error;
  }

  if (opts->verbose) {
    verbose_enter();
  }

  msg_multihl(hl_msg, history ? "echomsg" : "echo", history);

  if (opts->verbose) {
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
ArrayOf(Buffer) nvim_list_bufs(Arena *arena)
  FUNC_API_SINCE(1)
{
  size_t n = 0;

  FOR_ALL_BUFFERS(b) {
    n++;
  }

  Array rv = arena_array(arena, n);

  FOR_ALL_BUFFERS(b) {
    ADD_C(rv, BUFFER_OBJ(b->handle));
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
  FUNC_API_TEXTLOCK
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  if (curwin->w_p_wfb) {
    api_set_error(err, kErrorTypeException, "%s", e_winfixbuf_cannot_go_to_buffer);
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
ArrayOf(Window) nvim_list_wins(Arena *arena)
  FUNC_API_SINCE(1)
{
  size_t n = 0;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    n++;
  }

  Array rv = arena_array(arena, n);

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    ADD_C(rv, WINDOW_OBJ(wp->handle));
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
  FUNC_API_TEXTLOCK
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
  // Block autocommands for now so they don't mess with the buffer before we
  // finish configuring it.
  block_autocmds();

  buf_T *buf = buflist_new(NULL, NULL, 0,
                           BLN_NOOPT | BLN_NEW | (listed ? BLN_LISTED : 0));
  if (buf == NULL) {
    unblock_autocmds();
    goto fail;
  }

  // Open the memline for the buffer. This will avoid spurious autocmds when
  // a later nvim_buf_set_lines call would have needed to "open" the buffer.
  if (ml_open(buf) == FAIL) {
    unblock_autocmds();
    goto fail;
  }

  // Set last_changedtick to avoid triggering a TextChanged autocommand right
  // after it was added.
  buf->b_last_changedtick = buf_get_changedtick(buf);
  buf->b_last_changedtick_i = buf_get_changedtick(buf);
  buf->b_last_changedtick_pum = buf_get_changedtick(buf);

  // Only strictly needed for scratch, but could just as well be consistent
  // and do this now. Buffer is created NOW, not when it later first happens
  // to reach a window or aucmd_prepbuf() ..
  buf_copy_options(buf, BCO_ENTER | BCO_NOHELP);

  if (scratch) {
    set_option_direct_for(kOptBufhidden, STATIC_CSTR_AS_OPTVAL("hide"), OPT_LOCAL, 0,
                          kOptScopeBuf, buf);
    set_option_direct_for(kOptBuftype, STATIC_CSTR_AS_OPTVAL("nofile"), OPT_LOCAL, 0,
                          kOptScopeBuf, buf);
    assert(buf->b_ml.ml_mfp->mf_fd < 0);  // ml_open() should not have opened swapfile already
    buf->b_p_swf = false;
    buf->b_p_ml = false;
  }

  unblock_autocmds();

  bufref_T bufref;
  set_bufref(&bufref, buf);
  if (apply_autocmds(EVENT_BUFNEW, NULL, NULL, false, buf)
      && !bufref_valid(&bufref)) {
    goto fail;
  }
  if (listed
      && apply_autocmds(EVENT_BUFADD, NULL, NULL, false, buf)
      && !bufref_valid(&bufref)) {
    goto fail;
  }

  try_end(err);
  return buf->b_fnum;

fail:
  if (!try_end(err)) {
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
///                 `["input", term, bufnr, data]`
///          - force_crlf: (boolean, default true) Convert "\n" to "\r\n".
/// @param[out] err Error details, if any
/// @return Channel id, or 0 on error
Integer nvim_open_term(Buffer buffer, Dict(open_term) *opts, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }

  if (buf == cmdwin_buf) {
    api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
    return 0;
  }

  LuaRef cb = LUA_NOREF;
  if (HAS_KEY(opts, open_term, on_input)) {
    cb = opts->on_input;
    opts->on_input = LUA_NOREF;
  }

  Channel *chan = channel_alloc(kChannelStreamInternal);
  chan->stream.internal.cb = cb;
  chan->stream.internal.closed = false;
  TerminalOptions topts = {
    .data = chan,
    // NB: overridden in terminal_check_size if a window is already
    // displaying the buffer
    .width = (uint16_t)MAX(curwin->w_width_inner - win_col_off(curwin), 0),
    .height = (uint16_t)curwin->w_height_inner,
    .write_cb = term_write,
    .resize_cb = term_resize,
    .close_cb = term_close,
    .force_crlf = GET_BOOL_OR_TRUE(opts, open_term, force_crlf),
  };
  channel_incref(chan);
  terminal_open(&chan->term, buf, topts);
  if (chan->term != NULL) {
    terminal_check_size(chan->term);
  }
  channel_decref(chan);
  return (Integer)chan->id;
}

static void term_write(const char *buf, size_t size, void *data)
{
  Channel *chan = data;
  LuaRef cb = chan->stream.internal.cb;
  if (cb == LUA_NOREF) {
    return;
  }
  MAXSIZE_TEMP_ARRAY(args, 3);
  ADD_C(args, INTEGER_OBJ((Integer)chan->id));
  ADD_C(args, BUFFER_OBJ(terminal_buf(chan->term)));
  ADD_C(args, STRING_OBJ(((String){ .data = (char *)buf, .size = size })));
  textlock++;
  nlua_call_ref(cb, "input", args, kRetNilBool, NULL, NULL);
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
ArrayOf(Tabpage) nvim_list_tabpages(Arena *arena)
  FUNC_API_SINCE(1)
{
  size_t n = 0;

  FOR_ALL_TABS(tp) {
    n++;
  }

  Array rv = arena_array(arena, n);

  FOR_ALL_TABS(tp) {
    ADD_C(rv, TABPAGE_OBJ(tp->handle));
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
  FUNC_API_TEXTLOCK
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

/// Pastes at cursor (in any mode), and sets "redo" so dot (|.|) will repeat the input. UIs call
/// this to implement "paste", but it's also intended for use by scripts to input large,
/// dot-repeatable blocks of text (as opposed to |nvim_input()| which is subject to mappings/events
/// and is thus much slower).
///
/// Invokes the |vim.paste()| handler, which handles each mode appropriately.
///
/// Errors ('nomodifiable', `vim.paste()` failure, …) are reflected in `err` but do not affect the
/// return value (which is strictly decided by `vim.paste()`).  On error or cancel, subsequent calls
/// are ignored ("drained") until the next paste is initiated (phase 1 or -1).
///
/// Useful in mappings and scripts to insert multiline text. Example:
///
/// ```lua
/// vim.keymap.set('n', 'x', function()
///   vim.api.nvim_paste([[
///     line1
///     line2
///     line3
///   ]], false, -1)
/// end, { buffer = true })
/// ```
///
/// @param data  Multiline input. Lines break at LF ("\n"). May be binary (containing NUL bytes).
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
///     - false: Client should cancel the paste.
Boolean nvim_paste(uint64_t channel_id, String data, Boolean crlf, Integer phase, Arena *arena,
                   Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  static bool cancelled = false;

  VALIDATE_INT((phase >= -1 && phase <= 3), "phase", phase, {
    return false;
  });
  if (phase == -1 || phase == 1) {  // Start of paste-stream.
    cancelled = false;
  } else if (cancelled) {
    // Skip remaining chunks.  Report error only once per "stream".
    goto theend;
  }
  Array lines = string_to_array(data, crlf, arena);
  MAXSIZE_TEMP_ARRAY(args, 2);
  ADD_C(args, ARRAY_OBJ(lines));
  ADD_C(args, INTEGER_OBJ(phase));
  Object rv = NLUA_EXEC_STATIC("return vim.paste(...)", args, kRetNilBool, arena, err);
  // vim.paste() decides if client should cancel.
  if (ERROR_SET(err) || (rv.type == kObjectTypeBoolean && !rv.data.boolean)) {
    cancelled = true;
  }
  if (!cancelled && (phase == -1 || phase == 1)) {
    paste_store(channel_id, kFalse, NULL_STRING, crlf);
  }
  if (!cancelled) {
    paste_store(channel_id, kNone, data, crlf);
  }
  if (phase == 3 || phase == (cancelled ? 2 : -1)) {
    paste_store(channel_id, kTrue, NULL_STRING, crlf);
  }
theend:
  ;
  bool retval = !cancelled;
  if (phase == -1 || phase == 3) {  // End of paste-stream.
    cancelled = false;
  }
  return retval;
}

/// Puts text at cursor, in any mode. For dot-repeatable input, use |nvim_paste()|.
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
void nvim_put(ArrayOf(String) lines, String type, Boolean after, Boolean follow, Arena *arena,
              Error *err)
  FUNC_API_SINCE(6)
  FUNC_API_TEXTLOCK_ALLOW_CMDWIN
{
  yankreg_T reg[1] = { 0 };
  VALIDATE_S((prepare_yankreg_from_object(reg, type, lines.size)), "type", type.data, {
    return;
  });
  if (lines.size == 0) {
    return;  // Nothing to do.
  }

  reg->y_array = arena_alloc(arena, lines.size * sizeof(String), true);
  reg->y_size = lines.size;
  for (size_t i = 0; i < lines.size; i++) {
    VALIDATE_T("line", kObjectTypeString, lines.items[i].type, {
      return;
    });
    String line = lines.items[i].data.string;
    reg->y_array[i] = copy_string(line, arena);
    memchrsub(reg->y_array[i].data, NUL, NL, line.size);
  }

  finish_yankreg_from_object(reg, false);

  TRY_WRAP(err, {
    bool VIsual_was_active = VIsual_active;
    msg_silent++;  // Avoid "N more lines" message.
    do_put(0, reg, after ? FORWARD : BACKWARD, 1, follow ? PUT_CURSEND : 0);
    msg_silent--;
    VIsual_active = VIsual_was_active;
  });
}

/// Returns the 24-bit RGB value of a |nvim_get_color_map()| color name or
/// "#rrggbb" hexadecimal string.
///
/// Example:
///
/// ```vim
/// :echo nvim_get_color_by_name("Pink")
/// :echo nvim_get_color_by_name("#cbcbcb")
/// ```
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
Dict nvim_get_color_map(Arena *arena)
  FUNC_API_SINCE(1)
{
  Dict colors = arena_dict(arena, ARRAY_SIZE(color_name_table));

  for (int i = 0; color_name_table[i].name != NULL; i++) {
    PUT_C(colors, color_name_table[i].name, INTEGER_OBJ(color_name_table[i].color));
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
Dict nvim_get_context(Dict(context) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(6)
{
  Array types = ARRAY_DICT_INIT;
  if (HAS_KEY(opts, context, types)) {
    types = opts->types;
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
            return (Dict)ARRAY_DICT_INIT;
          });
        }
      }
    }
  }

  Context ctx = CONTEXT_INIT;
  ctx_save(&ctx, int_types);
  Dict dict = ctx_to_dict(&ctx, arena);
  ctx_free(&ctx);
  return dict;
}

/// Sets the current editor state from the given |context| map.
///
/// @param  dict  |Context| map.
Object nvim_load_context(Dict dict, Error *err)
  FUNC_API_SINCE(6)
{
  Context ctx = CONTEXT_INIT;

  int save_did_emsg = did_emsg;
  did_emsg = false;

  ctx_from_dict(dict, &ctx, err);
  if (!ERROR_SET(err)) {
    ctx_restore(&ctx, kCtxAll);
  }

  ctx_free(&ctx);

  did_emsg = save_did_emsg;
  return (Object)OBJECT_INIT;
}

/// Gets the current mode. |mode()|
/// "blocking" is true if Nvim is waiting for input.
///
/// @returns Dict { "mode": String, "blocking": Boolean }
Dict nvim_get_mode(Arena *arena)
  FUNC_API_SINCE(2) FUNC_API_FAST
{
  Dict rv = arena_dict(arena, 2);
  char *modestr = arena_alloc(arena, MODE_MAX_LENGTH, false);
  get_mode(modestr);
  bool blocked = input_blocking();

  PUT_C(rv, "mode", CSTR_AS_OBJ(modestr));
  PUT_C(rv, "blocking", BOOLEAN_OBJ(blocked));

  return rv;
}

/// Gets a list of global (non-buffer-local) |mapping| definitions.
///
/// @param  mode       Mode short-name ("n", "i", "v", ...)
/// @returns Array of |maparg()|-like dictionaries describing mappings.
///          The "buffer" key is always zero.
ArrayOf(Dict) nvim_get_keymap(String mode, Arena *arena)
  FUNC_API_SINCE(3)
{
  return keymap_array(mode, NULL, arena);
}

/// Sets a global |mapping| for the given mode.
///
/// To set a buffer-local mapping, use |nvim_buf_set_keymap()|.
///
/// Unlike |:map|, leading/trailing whitespace is accepted as part of the {lhs} or {rhs}.
/// Empty {rhs} is [<Nop>]. |keycodes| are replaced as usual.
///
/// Example:
///
/// ```vim
/// call nvim_set_keymap('n', ' <NL>', '', {'nowait': v:true})
/// ```
///
/// is equivalent to:
///
/// ```vim
/// nmap <nowait> <Space><NL> <Nop>
/// ```
///
/// @param channel_id
/// @param  mode  Mode short-name (map command prefix: "n", "i", "v", "x", …)
///               or "!" for |:map!|, or empty string for |:map|.
///               "ia", "ca" or "!a" for abbreviation in Insert mode, Cmdline mode, or both, respectively
/// @param  lhs   Left-hand-side |{lhs}| of the mapping.
/// @param  rhs   Right-hand-side |{rhs}| of the mapping.
/// @param  opts  Optional parameters map: Accepts all |:map-arguments| as keys except [<buffer>],
///               values are booleans (default false). Also:
///               - "noremap" disables |recursive_mapping|, like |:noremap|
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
/// 1 is the |api-metadata| map (Dict).
///
/// @returns 2-tuple `[{channel-id}, {api-metadata}]`
Array nvim_get_api_info(uint64_t channel_id, Arena *arena)
  FUNC_API_SINCE(1) FUNC_API_FAST FUNC_API_REMOTE_ONLY
{
  Array rv = arena_array(arena, 2);

  assert(channel_id <= INT64_MAX);
  ADD_C(rv, INTEGER_OBJ((int64_t)channel_id));
  ADD_C(rv, api_metadata());

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
/// @param version  Dict describing the version, with these
///     (optional) keys:
///     - "major" major version (defaults to 0 if not set, for no release yet)
///     - "minor" minor version
///     - "patch" patch number
///     - "prerelease" string describing a prerelease, like "dev" or "beta1"
///     - "commit" hash or similar identifier of commit
/// @param type Must be one of the following values. Client libraries should
///     default to "remote" unless overridden by the user.
///     - "remote" remote client connected "Nvim flavored" MessagePack-RPC (responses
///                must be in reverse order of requests). |msgpack-rpc|
///     - "msgpack-rpc" remote client connected to Nvim via fully MessagePack-RPC
///                     compliant protocol.
///     - "ui" gui frontend
///     - "embedder" application using Nvim as a component (for example,
///                  IDE/editor implementing a vim mode).
///     - "host" plugin host, typically started by nvim
///     - "plugin" single plugin, started by nvim
/// @param methods Builtin methods in the client. For a host, this does not
///     include plugin methods which will be discovered later.
///     The key should be the method name, the values are dicts with
///     these (optional) keys (more keys may be added in future
///     versions of Nvim, thus unknown keys are ignored. Clients
///     must only use keys defined in this or later versions of
///     Nvim):
///     - "async"  if true, send as a notification. If false or unspecified,
///                use a blocking request
///     - "nargs" Number of arguments. Could be a single integer or an array
///                of two integers, minimum and maximum inclusive.
///
/// @param attributes Arbitrary string:string map of informal client properties.
///     Suggested keys:
///     - "pid":     Process id.
///     - "website": Client homepage URL (e.g. GitHub repository)
///     - "license": License description ("Apache 2", "GPLv3", "MIT", …)
///     - "logo":    URI or path to image, preferably small logo or icon.
///                  .png or .svg format is preferred.
///
/// @param[out] err Error details, if any
void nvim_set_client_info(uint64_t channel_id, String name, Dict version, String type, Dict methods,
                          Dict attributes, Arena *arena, Error *err)
  FUNC_API_SINCE(4) FUNC_API_REMOTE_ONLY
{
  MAXSIZE_TEMP_DICT(info, 5);
  PUT_C(info, "name", STRING_OBJ(name));

  bool has_major = false;
  for (size_t i = 0; i < version.size; i++) {
    if (strequal(version.items[i].key.data, "major")) {
      has_major = true;
      break;
    }
  }
  if (!has_major) {
    Dict v = arena_dict(arena, version.size + 1);
    if (version.size) {
      memcpy(v.items, version.items, version.size * sizeof(v.items[0]));
      v.size = version.size;
    }
    PUT_C(v, "major", INTEGER_OBJ(0));
    version = v;
  }
  PUT_C(info, "version", DICT_OBJ(version));

  PUT_C(info, "type", STRING_OBJ(type));
  PUT_C(info, "methods", DICT_OBJ(methods));
  PUT_C(info, "attributes", DICT_OBJ(attributes));

  rpc_set_client_info(channel_id, copy_dict(info, NULL));
}

/// Gets information about a channel.
///
/// @param chan channel_id, or 0 for current channel
/// @returns Channel info dict with these keys:
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
///    -  "pty"     (optional) Name of pseudoterminal. On a POSIX system this is a device path like
///                 "/dev/pts/1". If unknown, the key will still be present if a pty is used (e.g.
///                 for conpty on Windows).
///    -  "buffer"  (optional) Buffer connected to |terminal| instance.
///    -  "client"  (optional) Info about the peer (client on the other end of the RPC channel),
///                 which it provided via |nvim_set_client_info()|.
///
Dict nvim_get_chan_info(uint64_t channel_id, Integer chan, Arena *arena, Error *err)
  FUNC_API_SINCE(4)
{
  if (chan < 0) {
    return (Dict)ARRAY_DICT_INIT;
  }

  if (chan == 0 && !is_internal_call(channel_id)) {
    assert(channel_id <= INT64_MAX);
    chan = (Integer)channel_id;
  }
  return channel_info((uint64_t)chan, arena);
}

/// Get information about all open channels.
///
/// @returns Array of Dictionaries, each describing a channel with
///          the format specified at |nvim_get_chan_info()|.
Array nvim_list_chans(Arena *arena)
  FUNC_API_SINCE(4)
{
  return channel_all_info(arena);
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
  StringBuilder *line_buf = to_err ? &err_line_buf : &out_line_buf;

#define PUSH_CHAR(c) \
  if (kv_max(*line_buf) == 0) { \
    kv_resize(*line_buf, LINE_BUFFER_MIN_SIZE); \
  } \
  if (c == NL) { \
    kv_push(*line_buf, NUL); \
    if (to_err) { \
      emsg(line_buf->items); \
    } else { \
      msg(line_buf->items, 0); \
    } \
    if (msg_silent == 0) { \
      msg_didout = true; \
    } \
    kv_drop(*line_buf, kv_size(*line_buf)); \
    kv_resize(*line_buf, LINE_BUFFER_MIN_SIZE); \
  } else if (c == NUL) { \
    kv_push(*line_buf, NL); \
  } else { \
    kv_push(*line_buf, c); \
  }

  no_wait_return++;
  for (uint32_t i = 0; i < message.size; i++) {
    if (got_int) {
      break;
    }
    PUSH_CHAR(message.data[i]);
  }
  if (writeln) {
    PUSH_CHAR(NL);
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
Object nvim__id(Object obj, Arena *arena)
{
  return copy_object(obj, arena);
}

/// Returns array given as argument.
///
/// This API function is used for testing. One should not rely on its presence
/// in plugins.
///
/// @param[in]  arr  Array to return.
///
/// @return its argument.
Array nvim__id_array(Array arr, Arena *arena)
{
  return copy_array(arr, arena);
}

/// Returns dict given as argument.
///
/// This API function is used for testing. One should not rely on its presence
/// in plugins.
///
/// @param[in]  dct  Dict to return.
///
/// @return its argument.
Dict nvim__id_dict(Dict dct, Arena *arena)
{
  return copy_dict(dct, arena);
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
Dict nvim__stats(Arena *arena)
{
  Dict rv = arena_dict(arena, 6);
  PUT_C(rv, "fsync", INTEGER_OBJ(g_stats.fsync));
  PUT_C(rv, "log_skip", INTEGER_OBJ(g_stats.log_skip));
  PUT_C(rv, "lua_refcount", INTEGER_OBJ(nlua_get_global_ref_count()));
  PUT_C(rv, "redraw", INTEGER_OBJ(g_stats.redraw));
  PUT_C(rv, "arena_alloc_count", INTEGER_OBJ((Integer)arena_alloc_count));
  PUT_C(rv, "ts_query_parse_count", INTEGER_OBJ((Integer)tslua_query_parse_count));
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
Array nvim_list_uis(Arena *arena)
  FUNC_API_SINCE(4)
{
  return ui_array(arena);
}

/// Gets the immediate children of process `pid`.
///
/// @return Array of child process ids, empty if process not found.
Array nvim_get_proc_children(Integer pid, Arena *arena, Error *err)
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
    ADD_C(a, INTEGER_OBJ(pid));
    Object o = NLUA_EXEC_STATIC("return vim._os_proc_children(...)", a, kRetObject, arena, err);
    if (o.type == kObjectTypeArray) {
      rvobj = o.data.array;
    } else if (!ERROR_SET(err)) {
      api_set_error(err, kErrorTypeException,
                    "Failed to get process children. pid=%" PRId64 " error=%d",
                    pid, rv);
    }
  } else {
    rvobj = arena_array(arena, proc_count);
    for (size_t i = 0; i < proc_count; i++) {
      ADD_C(rvobj, INTEGER_OBJ(proc_list[i]));
    }
  }

end:
  xfree(proc_list);
  return rvobj;
}

/// Gets info describing process `pid`.
///
/// @return Map of process properties, or NIL if process not found.
Object nvim_get_proc(Integer pid, Arena *arena, Error *err)
  FUNC_API_SINCE(4)
{
  Object rvobj = NIL;

  VALIDATE_INT((pid > 0 && pid <= INT_MAX), "pid", pid, {
    return NIL;
  });

#ifdef MSWIN
  rvobj = DICT_OBJ(os_proc_info((int)pid, arena));
  if (rvobj.data.dict.size == 0) {  // Process not found.
    return NIL;
  }
#else
  // Cross-platform process info APIs are miserable, so use `ps` instead.
  MAXSIZE_TEMP_ARRAY(a, 1);
  ADD(a, INTEGER_OBJ(pid));
  Object o = NLUA_EXEC_STATIC("return vim._os_proc_info(...)", a, kRetObject, arena, err);
  if (o.type == kObjectTypeArray && o.data.array.size == 0) {
    return NIL;  // Process not found.
  } else if (o.type == kObjectTypeDict) {
    rvobj = o;
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
/// Can also be used in a mapping; use [<Cmd>] |:map-cmd| or a Lua mapping to ensure the mapping
/// doesn't end completion mode.
///
/// @param item    Index (zero-based) of the item to select. Value of -1 selects nothing
///                and restores the original text.
/// @param insert  For |ins-completion|, whether the selection should be inserted in the buffer.
///                Ignored for |cmdline-completion|.
/// @param finish  Finish the completion and dismiss the popup menu. Implies {insert}.
/// @param opts    Optional parameters. Reserved for future use.
/// @param[out] err Error details, if any
void nvim_select_popupmenu_item(Integer item, Boolean insert, Boolean finish, Dict(empty) *opts,
                                Error *err)
  FUNC_API_SINCE(6)
{
  if (finish) {
    insert = true;
  }

  pum_ext_select_item((int)item, insert, finish);
}

/// NB: if your UI doesn't use hlstate, this will not return hlstate first time.
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
  char *sc_buf = arena_alloc(arena, MAX_SCHAR_SIZE, false);
  schar_get(sc_buf, g->chars[off]);
  ADD_C(ret, CSTR_AS_OBJ(sc_buf));
  int attr = g->attrs[off];
  ADD_C(ret, DICT_OBJ(hl_get_attr_by_id(attr, true, arena, err)));
  // will not work first time
  if (!highlight_use_hlstate()) {
    ADD_C(ret, ARRAY_OBJ(hl_inspect(attr, arena)));
  }
  return ret;
}

/// @nodoc
void nvim__screenshot(String path)
  FUNC_API_FAST
{
  ui_call_screenshot(path);
}

/// For testing. The condition in schar_cache_clear_if_full is hard to
/// reach, so this function can be used to force a cache clear in a test.
void nvim__invalidate_glyph_cache(void)
{
  schar_cache_clear();
  must_redraw = UPD_CLEAR;
}

/// @nodoc
Object nvim__unpack(String str, Arena *arena, Error *err)
  FUNC_API_FAST
{
  return unpack(str.data, str.size, arena, err);
}

/// Deletes an uppercase/file named mark. See |mark-motions|.
///
/// @note Lowercase name (or other buffer-local mark) is an error.
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

/// Returns a `(row, col, buffer, buffername)` tuple representing the position
/// of the uppercase/file named mark. "End of line" column position is returned
/// as |v:maxcol| (big number). See |mark-motions|.
///
/// Marks are (1,0)-indexed. |api-indexing|
///
/// @note Lowercase name (or other buffer-local mark) is an error.
/// @param name       Mark name
/// @param opts       Optional parameters. Reserved for future use.
/// @return 4-tuple (row, col, buffer, buffername), (0, 0, 0, '') if the mark is
/// not set.
/// @see |nvim_buf_set_mark()|
/// @see |nvim_del_mark()|
Array nvim_get_mark(String name, Dict(empty) *opts, Arena *arena, Error *err)
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

  rv = arena_array(arena, 4);
  ADD_C(rv, INTEGER_OBJ(row));
  ADD_C(rv, INTEGER_OBJ(col));
  ADD_C(rv, INTEGER_OBJ(bufnr));
  ADD_C(rv, CSTR_TO_ARENA_OBJ(arena, filename));

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
/// @return Dict containing statusline information, with these keys:
///       - str: (string) Characters that will be displayed on the statusline.
///       - width: (number) Display width of the statusline.
///       - highlights: Array containing highlight information of the statusline. Only included when
///                     the "highlights" key in {opts} is true. Each element of the array is a
///                     |Dict| with these keys:
///           - start: (number) Byte index (0-based) of first character that uses the highlight.
///           - group: (string) Name of highlight group.
Dict nvim_eval_statusline(String str, Dict(eval_statusline) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(8) FUNC_API_FAST
{
  Dict result = ARRAY_DICT_INIT;

  int maxwidth;
  schar_T fillchar = 0;
  int statuscol_lnum = 0;

  if (str.size < 2 || memcmp(str.data, "%!", 2) != 0) {
    const char *const errmsg = check_stl_option(str.data);
    VALIDATE(!errmsg, "%s", errmsg, {
      return result;
    });
  }

  Window window = opts->winid;

  if (HAS_KEY(opts, eval_statusline, fillchar)) {
    VALIDATE_EXP((*opts->fillchar.data != 0
                  && ((size_t)utfc_ptr2len(opts->fillchar.data) == opts->fillchar.size)),
                 "fillchar", "single character", NULL, {
      return result;
    });
    int c;
    fillchar = utfc_ptr2schar(opts->fillchar.data, &c);
    // TODO(bfredl): actually check c is single width
  }

  int use_bools = (int)opts->use_winbar + (int)opts->use_tabline;

  win_T *wp = opts->use_tabline ? curwin : find_window_by_handle(window, err);
  if (wp == NULL) {
    api_set_error(err, kErrorTypeException, "unknown winid %d", window);
    return result;
  }

  if (HAS_KEY(opts, eval_statusline, use_statuscol_lnum)) {
    statuscol_lnum = (int)opts->use_statuscol_lnum;
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

  if (statuscol_lnum) {
    int line_id = 0;
    int cul_id = 0;
    int num_id = 0;
    linenr_T lnum = statuscol_lnum;
    decor_redraw_signs(wp, wp->w_buffer, lnum - 1, sattrs, &line_id, &cul_id, &num_id);

    statuscol.sattrs = sattrs;
    statuscol.foldinfo = fold_info(wp, lnum);
    wp->w_cursorline = win_cursorline_standout(wp) ? wp->w_cursor.lnum : 0;

    if (wp->w_p_cul) {
      if (statuscol.foldinfo.fi_level != 0 && statuscol.foldinfo.fi_lines > 0) {
        wp->w_cursorline = statuscol.foldinfo.fi_lnum;
      }
      statuscol.use_cul = lnum == wp->w_cursorline && (wp->w_p_culopt_flags & kOptCuloptFlagNumber);
    }

    statuscol.sign_cul_id = statuscol.use_cul ? cul_id : 0;
    if (num_id) {
      stc_hl_id = num_id;
    } else if (statuscol.use_cul) {
      stc_hl_id = HLF_CLN;
    } else if (wp->w_p_rnu) {
      stc_hl_id = (lnum < wp->w_cursor.lnum ? HLF_LNA : HLF_LNB);
    } else {
      stc_hl_id = HLF_N;
    }

    set_vim_var_nr(VV_LNUM, lnum);
    set_vim_var_nr(VV_RELNUM, labs(get_cursor_rel_lnum(wp, lnum)));
    set_vim_var_nr(VV_VIRTNUM, 0);
  } else if (fillchar == 0 && !opts->use_tabline) {
    if (opts->use_winbar) {
      fillchar = wp->w_p_fcs_chars.wbr;
    } else {
      int attr;
      fillchar = fillchar_status(&attr, wp);
    }
  }

  if (HAS_KEY(opts, eval_statusline, maxwidth)) {
    maxwidth = (int)opts->maxwidth;
  } else {
    maxwidth = statuscol_lnum ? win_col_off(wp)
                              : (opts->use_tabline
                                 || (!opts->use_winbar
                                     && global_stl_height() > 0)) ? Columns : wp->w_width;
  }

  result = arena_dict(arena, 3);
  char *buf = arena_alloc(arena, MAXPATHL, false);
  stl_hlrec_t *hltab;
  size_t hltab_len = 0;

  // Temporarily reset 'cursorbind' to prevent side effects from moving the cursor away and back.
  int p_crb_save = wp->w_p_crb;
  wp->w_p_crb = false;

  int width = build_stl_str_hl(wp, buf, MAXPATHL, str.data, -1, 0, fillchar, maxwidth,
                               opts->highlights ? &hltab : NULL, &hltab_len, NULL,
                               statuscol_lnum ? &statuscol : NULL);

  PUT_C(result, "width", INTEGER_OBJ(width));

  // Restore original value of 'cursorbind'
  wp->w_p_crb = p_crb_save;

  if (opts->highlights) {
    Array hl_values = arena_array(arena, hltab_len + 1);
    char user_group[15];  // strlen("User") + strlen("2147483647") + NUL

    // If first character doesn't have a defined highlight,
    // add the default highlight at the beginning of the highlight list
    if (hltab->start == NULL || (hltab->start - buf) != 0) {
      Dict hl_info = arena_dict(arena, 2);
      const char *grpname = get_default_stl_hl(opts->use_tabline ? NULL : wp,
                                               opts->use_winbar, stc_hl_id);

      PUT_C(hl_info, "start", INTEGER_OBJ(0));
      PUT_C(hl_info, "group", CSTR_AS_OBJ(grpname));

      ADD_C(hl_values, DICT_OBJ(hl_info));
    }

    for (stl_hlrec_t *sp = hltab; sp->start != NULL; sp++) {
      Dict hl_info = arena_dict(arena, 2);

      PUT_C(hl_info, "start", INTEGER_OBJ(sp->start - buf));

      const char *grpname;
      if (sp->userhl == 0) {
        grpname = get_default_stl_hl(opts->use_tabline ? NULL : wp, opts->use_winbar, stc_hl_id);
      } else if (sp->userhl < 0) {
        grpname = syn_id2name(-sp->userhl);
      } else {
        snprintf(user_group, sizeof(user_group), "User%d", sp->userhl);
        grpname = arena_memdupz(arena, user_group, strlen(user_group));
      }
      PUT_C(hl_info, "group", CSTR_AS_OBJ(grpname));
      ADD_C(hl_values, DICT_OBJ(hl_info));
    }
    PUT_C(result, "highlights", ARRAY_OBJ(hl_values));
  }
  PUT_C(result, "str", CSTR_AS_OBJ(buf));

  return result;
}

/// @nodoc
void nvim_error_event(uint64_t channel_id, Integer lvl, String data)
  FUNC_API_REMOTE_ONLY
{
  // TODO(bfredl): consider printing message to user, as will be relevant
  // if we fork nvim processes as async workers
  ELOG("async error on channel %" PRId64 ": %s", channel_id, data.size ? data.data : "");
}

/// EXPERIMENTAL: this API may change in the future.
///
/// Sets info for the completion item at the given index. If the info text was shown in a window,
/// returns the window and buffer ids, or empty dict if not shown.
///
/// @param index  Completion candidate index
/// @param opts   Optional parameters.
///       - info: (string) info text.
/// @return Dict containing these keys:
///       - winid: (number) floating window id
///       - bufnr: (number) buffer id in floating window
Dict nvim__complete_set(Integer index, Dict(complete_set) *opts, Arena *arena)
{
  Dict rv = arena_dict(arena, 2);
  if (HAS_KEY(opts, complete_set, info)) {
    win_T *wp = pum_set_info((int)index, opts->info.data);
    if (wp) {
      PUT_C(rv, "winid", WINDOW_OBJ(wp->handle));
      PUT_C(rv, "bufnr", BUFFER_OBJ(wp->w_buffer->handle));
    }
  }
  return rv;
}

static void redraw_status(win_T *wp, Dict(redraw) *opts, bool *flush)
{
  if (opts->statuscolumn && *wp->w_p_stc != NUL) {
    wp->w_nrwidth_line_count = 0;
    changed_window_setting(wp);
  }
  win_grid_alloc(wp);

  // Flush later in case winbar was just hidden or shown for the first time, or
  // statuscolumn is being drawn.
  if (wp->w_lines_valid == 0) {
    *flush = true;
  }

  // Mark for redraw in case flush will happen, otherwise redraw now.
  if (*flush && (opts->statusline || opts->winbar)) {
    wp->w_redr_status = true;
  } else if (opts->statusline || opts->winbar) {
    win_check_ns_hl(wp);
    if (opts->winbar) {
      win_redr_winbar(wp);
    }
    if (opts->statusline) {
      win_redr_status(wp);
    }
    win_check_ns_hl(NULL);
  }
}

/// EXPERIMENTAL: this API may change in the future.
///
/// Instruct Nvim to redraw various components.
///
/// @see |:redraw|
///
/// @param opts  Optional parameters.
///               - win: Target a specific |window-ID| as described below.
///               - buf: Target a specific buffer number as described below.
///               - flush: Update the screen with pending updates.
///               - valid: When present mark `win`, `buf`, or all windows for
///                 redraw. When `true`, only redraw changed lines (useful for
///                 decoration providers). When `false`, forcefully redraw.
///               - range: Redraw a range in `buf`, the buffer in `win` or the
///                 current buffer (useful for decoration providers). Expects a
///                 tuple `[first, last]` with the first and last line number
///                 of the range, 0-based end-exclusive |api-indexing|.
///               - cursor: Immediately update cursor position on the screen in
///                 `win` or the current window.
///               - statuscolumn: Redraw the 'statuscolumn' in `buf`, `win` or
///                 all windows.
///               - statusline: Redraw the 'statusline' in `buf`, `win` or all
///                 windows.
///               - winbar: Redraw the 'winbar' in `buf`, `win` or all windows.
///               - tabline: Redraw the 'tabline'.
void nvim__redraw(Dict(redraw) *opts, Error *err)
  FUNC_API_SINCE(12)
{
  win_T *win = NULL;
  buf_T *buf = NULL;

  if (HAS_KEY(opts, redraw, win)) {
    win = find_window_by_handle(opts->win, err);
    if (ERROR_SET(err)) {
      return;
    }
  }

  if (HAS_KEY(opts, redraw, buf)) {
    VALIDATE(win == NULL, "%s", "cannot use both 'buf' and 'win'", {
      return;
    });
    buf = find_buffer_by_handle(opts->buf, err);
    if (ERROR_SET(err)) {
      return;
    }
  }

  unsigned count = (win != NULL) + (buf != NULL);
  VALIDATE(xpopcount(opts->is_set__redraw_) > count, "%s", "at least one action required", {
    return;
  });

  if (HAS_KEY(opts, redraw, valid)) {
    // UPD_VALID redraw type does not actually do anything on it's own. Setting
    // it here without scrolling or changing buffer text seems pointless but
    // the expectation is that this may be called by decoration providers whose
    // "on_win" callback may set "w_redr_top/bot".
    int type = opts->valid ? UPD_VALID : UPD_NOT_VALID;
    if (win != NULL) {
      redraw_later(win, type);
    } else if (buf != NULL) {
      redraw_buf_later(buf, type);
    } else {
      redraw_all_later(type);
    }
  }

  if (HAS_KEY(opts, redraw, range)) {
    VALIDATE(kv_size(opts->range) == 2
             && kv_A(opts->range, 0).type == kObjectTypeInteger
             && kv_A(opts->range, 1).type == kObjectTypeInteger
             && kv_A(opts->range, 0).data.integer >= 0
             && kv_A(opts->range, 1).data.integer >= -1,
             "%s", "Invalid 'range': Expected 2-tuple of Integers", {
      return;
    });
    linenr_T first = (linenr_T)kv_A(opts->range, 0).data.integer + 1;
    linenr_T last = (linenr_T)kv_A(opts->range, 1).data.integer;
    buf_T *rbuf = win ? win->w_buffer : (buf ? buf : curbuf);
    if (last == -1) {
      last = rbuf->b_ml.ml_line_count;
    }
    redraw_buf_range_later(rbuf, first, last);
  }

  // Redraw later types require update_screen() so call implicitly unless set to false.
  if (HAS_KEY(opts, redraw, valid) || HAS_KEY(opts, redraw, range)) {
    opts->flush = HAS_KEY(opts, redraw, flush) ? opts->flush : true;
  }

  // When explicitly set to false and only "redraw later" types are present,
  // don't call ui_flush() either.
  bool flush_ui = opts->flush;
  if (opts->tabline) {
    // Flush later in case tabline was just hidden or shown for the first time.
    if (redraw_tabline && firstwin->w_lines_valid == 0) {
      opts->flush = true;
    } else {
      draw_tabline();
    }
    flush_ui = true;
  }

  bool save_lz = p_lz;
  int save_rd = RedrawingDisabled;
  RedrawingDisabled = 0;
  p_lz = false;
  if (opts->statuscolumn || opts->statusline || opts->winbar) {
    if (win == NULL) {
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        if (buf == NULL || wp->w_buffer == buf) {
          redraw_status(wp, opts, &opts->flush);
        }
      }
    } else {
      redraw_status(win, opts, &opts->flush);
    }
    flush_ui = true;
  }

  win_T *cwin = win ? win : curwin;
  // Allow moving cursor to recently opened window and make sure it is drawn #28868.
  if (opts->cursor && (!cwin->w_grid.target || !cwin->w_grid.target->valid)) {
    opts->flush = true;
  }

  // Redraw pending screen updates when explicitly requested or when determined
  // that it is necessary to properly draw other requested components.
  if (opts->flush && !cmdpreview) {
    update_screen();
  }

  if (opts->cursor) {
    setcursor_mayforce(cwin, true);
    flush_ui = true;
  }

  if (flush_ui) {
    ui_flush();
  }

  RedrawingDisabled = save_rd;
  p_lz = save_lz;
}
