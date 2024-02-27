#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/api/buffer.h"
#include "nvim/api/deprecated.h"
#include "nvim/api/extmark.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/api/vimscript.h"
#include "nvim/buffer_defs.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/extmark.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/lua/executor.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/deprecated.c.generated.h"
#endif

/// @deprecated Use nvim_exec2() instead.
/// @see nvim_exec2
String nvim_exec(uint64_t channel_id, String src, Boolean output, Error *err)
  FUNC_API_SINCE(7) FUNC_API_DEPRECATED_SINCE(11)
  FUNC_API_RET_ALLOC
{
  Dict(exec_opts) opts = { .output = output };
  return exec_impl(channel_id, src, &opts, err);
}

/// @deprecated
/// @see nvim_exec2
String nvim_command_output(uint64_t channel_id, String command, Error *err)
  FUNC_API_SINCE(1) FUNC_API_DEPRECATED_SINCE(7)
  FUNC_API_RET_ALLOC
{
  Dict(exec_opts) opts = { .output = true };
  return exec_impl(channel_id, command, &opts, err);
}

/// @deprecated Use nvim_exec_lua() instead.
/// @see nvim_exec_lua
Object nvim_execute_lua(String code, Array args, Arena *arena, Error *err)
  FUNC_API_SINCE(3)
  FUNC_API_DEPRECATED_SINCE(7)
  FUNC_API_REMOTE_ONLY
{
  return nlua_exec(code, args, kRetObject, arena, err);
}

/// Gets the buffer number
///
/// @deprecated The buffer number now is equal to the object id
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param[out] err   Error details, if any
/// @return Buffer number
Integer nvim_buf_get_number(Buffer buffer, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(2)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return 0;
  }

  return buf->b_fnum;
}

/// Clears highlights and virtual text from namespace and range of lines
///
/// @deprecated use |nvim_buf_clear_namespace()|.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param ns_id      Namespace to clear, or -1 to clear all.
/// @param line_start Start of range of lines to clear
/// @param line_end   End of range of lines to clear (exclusive) or -1 to clear
///                   to end of file.
/// @param[out] err   Error details, if any
void nvim_buf_clear_highlight(Buffer buffer, Integer ns_id, Integer line_start, Integer line_end,
                              Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(7)
{
  nvim_buf_clear_namespace(buffer, ns_id, line_start, line_end, err);
}

/// Set the virtual text (annotation) for a buffer line.
///
/// @deprecated use nvim_buf_set_extmark to use full virtual text functionality.
///
/// The text will be placed after the buffer text. Virtual text will never
/// cause reflow, rather virtual text will be truncated at the end of the screen
/// line. The virtual text will begin one cell (|lcs-eol| or space) after the
/// ordinary text.
///
/// Namespaces are used to support batch deletion/updating of virtual text.
/// To create a namespace, use |nvim_create_namespace()|. Virtual text is
/// cleared using |nvim_buf_clear_namespace()|. The same `ns_id` can be used for
/// both virtual text and highlights added by |nvim_buf_add_highlight()|, both
/// can then be cleared with a single call to |nvim_buf_clear_namespace()|. If
/// the virtual text never will be cleared by an API call, pass `ns_id = -1`.
///
/// As a shorthand, `ns_id = 0` can be used to create a new namespace for the
/// virtual text, the allocated id is then returned.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param src_id     Namespace to use or 0 to create a namespace,
///                   or -1 for a ungrouped annotation
/// @param line       Line to annotate with virtual text (zero-indexed)
/// @param chunks     A list of [text, hl_group] arrays, each representing a
///                   text chunk with specified highlight. `hl_group` element
///                   can be omitted for no highlight.
/// @param opts       Optional parameters. Currently not used.
/// @param[out] err   Error details, if any
/// @return The ns_id that was used
Integer nvim_buf_set_virtual_text(Buffer buffer, Integer src_id, Integer line, Array chunks,
                                  Dict(empty) *opts, Error *err)
  FUNC_API_SINCE(5)
  FUNC_API_DEPRECATED_SINCE(8)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }

  if (line < 0 || line >= MAXLNUM) {
    api_set_error(err, kErrorTypeValidation, "Line number outside range");
    return 0;
  }

  uint32_t ns_id = src2ns(&src_id);
  int width;

  VirtText virt_text = parse_virt_text(chunks, err, &width);
  if (ERROR_SET(err)) {
    return 0;
  }

  DecorVirtText *existing = decor_find_virttext(buf, (int)line, ns_id);

  if (existing) {
    clear_virttext(&existing->data.virt_text);
    existing->data.virt_text = virt_text;
    existing->width = width;
    return src_id;
  }

  DecorVirtText *vt = xmalloc(sizeof *vt);
  *vt = (DecorVirtText)DECOR_VIRT_TEXT_INIT;
  vt->data.virt_text = virt_text;
  vt->width = width;
  vt->priority = 0;

  DecorInline decor = { .ext = true, .data.ext.vt = vt, .data.ext.sh_idx = DECOR_ID_INVALID };

  extmark_set(buf, ns_id, NULL, (int)line, 0, -1, -1, decor, 0, true,
              false, false, false, false, NULL);
  return src_id;
}

/// Gets a highlight definition by id. |hlID()|
///
/// @deprecated use |nvim_get_hl()| instead
///
/// @param hl_id Highlight id as returned by |hlID()|
/// @param rgb Export RGB colors
/// @param[out] err Error details, if any
/// @return Highlight definition map
/// @see nvim_get_hl_by_name
Dictionary nvim_get_hl_by_id(Integer hl_id, Boolean rgb, Arena *arena, Error *err)
  FUNC_API_SINCE(3)
  FUNC_API_DEPRECATED_SINCE(9)
{
  Dictionary dic = ARRAY_DICT_INIT;
  VALIDATE_INT((syn_get_final_id((int)hl_id) != 0), "highlight id", hl_id, {
    return dic;
  });
  int attrcode = syn_id2attr((int)hl_id);
  return hl_get_attr_by_id(attrcode, rgb, arena, err);
}

/// Gets a highlight definition by name.
///
/// @deprecated use |nvim_get_hl()| instead
///
/// @param name Highlight group name
/// @param rgb Export RGB colors
/// @param[out] err Error details, if any
/// @return Highlight definition map
/// @see nvim_get_hl_by_id
Dictionary nvim_get_hl_by_name(String name, Boolean rgb, Arena *arena, Error *err)
  FUNC_API_SINCE(3)
  FUNC_API_DEPRECATED_SINCE(9)
{
  Dictionary result = ARRAY_DICT_INIT;
  int id = syn_name2id(name.data);

  VALIDATE_S((id != 0), "highlight name", name.data, {
    return result;
  });
  return nvim_get_hl_by_id(id, rgb, arena, err);
}

/// Inserts a sequence of lines to a buffer at a certain index
///
/// @deprecated use nvim_buf_set_lines(buffer, lnum, lnum, true, lines)
///
/// @param buffer     Buffer handle
/// @param lnum       Insert the lines after `lnum`. If negative, appends to
///                   the end of the buffer.
/// @param lines      Array of lines
/// @param[out] err   Error details, if any
void buffer_insert(Buffer buffer, Integer lnum, ArrayOf(String) lines, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  // "lnum" will be the index of the line after inserting,
  // no matter if it is negative or not
  nvim_buf_set_lines(0, buffer, lnum, lnum, true, lines, arena, err);
}

/// Gets a buffer line
///
/// @deprecated use nvim_buf_get_lines instead.
///             for positive indices (including 0) use
///                 "nvim_buf_get_lines(buffer, index, index+1, true)"
///             for negative indices use
///                 "nvim_buf_get_lines(buffer, index-1, index, true)"
///
/// @param buffer   Buffer handle
/// @param index    Line index
/// @param[out] err Error details, if any
/// @return Line string
String buffer_get_line(Buffer buffer, Integer index, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  String rv = { .size = 0 };

  index = convert_index(index);
  Array slice = nvim_buf_get_lines(0, buffer, index, index + 1, true, arena, NULL, err);

  if (!ERROR_SET(err) && slice.size) {
    rv = slice.items[0].data.string;
  }

  return rv;
}

/// Sets a buffer line
///
/// @deprecated use nvim_buf_set_lines instead.
///             for positive indices use
///                 "nvim_buf_set_lines(buffer, index, index+1, true, [line])"
///             for negative indices use
///                 "nvim_buf_set_lines(buffer, index-1, index, true, [line])"
///
/// @param buffer   Buffer handle
/// @param index    Line index
/// @param line     Contents of the new line
/// @param[out] err Error details, if any
void buffer_set_line(Buffer buffer, Integer index, String line, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  Object l = STRING_OBJ(line);
  Array array = { .items = &l, .size = 1 };
  index = convert_index(index);
  nvim_buf_set_lines(0, buffer, index, index + 1, true,  array, arena, err);
}

/// Deletes a buffer line
///
/// @deprecated use nvim_buf_set_lines instead.
///             for positive indices use
///                 "nvim_buf_set_lines(buffer, index, index+1, true, [])"
///             for negative indices use
///                 "nvim_buf_set_lines(buffer, index-1, index, true, [])"
/// @param buffer   buffer handle
/// @param index    line index
/// @param[out] err Error details, if any
void buffer_del_line(Buffer buffer, Integer index, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  Array array = ARRAY_DICT_INIT;
  index = convert_index(index);
  nvim_buf_set_lines(0, buffer, index, index + 1, true, array, arena, err);
}

/// Retrieves a line range from the buffer
///
/// @deprecated use nvim_buf_get_lines(buffer, newstart, newend, false)
///             where newstart = start + int(not include_start) - int(start < 0)
///                   newend = end + int(include_end) - int(end < 0)
///                   int(bool) = 1 if bool is true else 0
/// @param buffer         Buffer handle
/// @param start          First line index
/// @param end            Last line index
/// @param include_start  True if the slice includes the `start` parameter
/// @param include_end    True if the slice includes the `end` parameter
/// @param[out] err       Error details, if any
/// @return Array of lines
ArrayOf(String) buffer_get_line_slice(Buffer buffer,
                                      Integer start,
                                      Integer end,
                                      Boolean include_start,
                                      Boolean include_end,
                                      Arena *arena,
                                      Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  start = convert_index(start) + !include_start;
  end = convert_index(end) + include_end;
  return nvim_buf_get_lines(0, buffer, start, end, false, arena, NULL, err);
}

/// Replaces a line range on the buffer
///
/// @deprecated use nvim_buf_set_lines(buffer, newstart, newend, false, lines)
///             where newstart = start + int(not include_start) + int(start < 0)
///                   newend = end + int(include_end) + int(end < 0)
///                   int(bool) = 1 if bool is true else 0
///
/// @param buffer         Buffer handle, or 0 for current buffer
/// @param start          First line index
/// @param end            Last line index
/// @param include_start  True if the slice includes the `start` parameter
/// @param include_end    True if the slice includes the `end` parameter
/// @param replacement    Array of lines to use as replacement (0-length
//                        array will delete the line range)
/// @param[out] err       Error details, if any
void buffer_set_line_slice(Buffer buffer, Integer start, Integer end, Boolean include_start,
                           Boolean include_end, ArrayOf(String) replacement, Arena *arena,
                           Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  start = convert_index(start) + !include_start;
  end = convert_index(end) + include_end;
  nvim_buf_set_lines(0, buffer, start, end, false, replacement, arena, err);
}

/// Sets a buffer-scoped (b:) variable
///
/// @deprecated
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Variable name
/// @param value      Variable value
/// @param[out] err   Error details, if any
/// @return Old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object buffer_set_var(Buffer buffer, String name, Object value, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return NIL;
  }

  return dict_set_var(buf->b_vars, name, value, false, true, arena, err);
}

/// Removes a buffer-scoped (b:) variable
///
/// @deprecated
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Variable name
/// @param[out] err   Error details, if any
/// @return Old value
Object buffer_del_var(Buffer buffer, String name, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return NIL;
  }

  return dict_set_var(buf->b_vars, name, NIL, true, true, arena, err);
}

/// Sets a window-scoped (w:) variable
///
/// @deprecated
///
/// @param window   Window handle, or 0 for current window
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
/// @return Old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object window_set_var(Window window, String name, Object value, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return NIL;
  }

  return dict_set_var(win->w_vars, name, value, false, true, arena, err);
}

/// Removes a window-scoped (w:) variable
///
/// @deprecated
///
/// @param window   Window handle, or 0 for current window
/// @param name     variable name
/// @param[out] err Error details, if any
/// @return Old value
Object window_del_var(Window window, String name, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return NIL;
  }

  return dict_set_var(win->w_vars, name, NIL, true, true, arena, err);
}

/// Sets a tab-scoped (t:) variable
///
/// @deprecated
///
/// @param tabpage  Tabpage handle, or 0 for current tabpage
/// @param name     Variable name
/// @param value    Variable value
/// @param[out] err Error details, if any
/// @return Old value or nil if there was no previous value.
///
///         @warning It may return nil if there was no previous value
///                  or if previous value was `v:null`.
Object tabpage_set_var(Tabpage tabpage, String name, Object value, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return NIL;
  }

  return dict_set_var(tab->tp_vars, name, value, false, true, arena, err);
}

/// Removes a tab-scoped (t:) variable
///
/// @deprecated
///
/// @param tabpage  Tabpage handle, or 0 for current tabpage
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Old value
Object tabpage_del_var(Tabpage tabpage, String name, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return NIL;
  }

  return dict_set_var(tab->tp_vars, name, NIL, true, true, arena, err);
}

/// @deprecated
/// @see nvim_set_var
/// @warning May return nil if there was no previous value
///          OR if previous value was `v:null`.
/// @return Old value or nil if there was no previous value.
Object vim_set_var(String name, Object value, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  return dict_set_var(&globvardict, name, value, false, true, arena, err);
}

/// @deprecated
/// @see nvim_del_var
Object vim_del_var(String name, Arena *arena, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  return dict_set_var(&globvardict, name, NIL, true, true, arena, err);
}

static int64_t convert_index(int64_t index)
{
  return index < 0 ? index - 1 : index;
}

/// Gets the option information for one option
///
/// @deprecated Use @ref nvim_get_option_info2 instead.
///
/// @param          name Option name
/// @param[out] err Error details, if any
/// @return         Option Information
Dictionary nvim_get_option_info(String name, Arena *arena, Error *err)
  FUNC_API_SINCE(7)
  FUNC_API_DEPRECATED_SINCE(11)
{
  return get_vimoption(name, OPT_GLOBAL, curbuf, curwin, arena, err);
}

/// Sets the global value of an option.
///
/// @deprecated
/// @param channel_id
/// @param name     Option name
/// @param value    New option value
/// @param[out] err Error details, if any
void nvim_set_option(uint64_t channel_id, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(11)
{
  set_option_to(channel_id, NULL, kOptReqGlobal, name, value, err);
}

/// Gets the global value of an option.
///
/// @deprecated
/// @param name     Option name
/// @param[out] err Error details, if any
/// @return         Option value (global)
Object nvim_get_option(String name, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(11)
{
  return get_option_from(NULL, kOptReqGlobal, name, err);
}

/// Gets a buffer option value
///
/// @deprecated
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Option name
/// @param[out] err   Error details, if any
/// @return Option value
Object nvim_buf_get_option(Buffer buffer, String name, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(11)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object)OBJECT_INIT;
  }

  return get_option_from(buf, kOptReqBuf, name, err);
}

/// Sets a buffer option value. Passing `nil` as value deletes the option (only
/// works if there's a global fallback)
///
/// @deprecated
/// @param channel_id
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Option name
/// @param value      Option value
/// @param[out] err   Error details, if any
void nvim_buf_set_option(uint64_t channel_id, Buffer buffer, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(11)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  set_option_to(channel_id, buf, kOptReqBuf, name, value, err);
}

/// Gets a window option value
///
/// @deprecated
/// @param window   Window handle, or 0 for current window
/// @param name     Option name
/// @param[out] err Error details, if any
/// @return Option value
Object nvim_win_get_option(Window window, String name, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(11)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object)OBJECT_INIT;
  }

  return get_option_from(win, kOptReqWin, name, err);
}

/// Sets a window option value. Passing `nil` as value deletes the option (only
/// works if there's a global fallback)
///
/// @deprecated
/// @param channel_id
/// @param window   Window handle, or 0 for current window
/// @param name     Option name
/// @param value    Option value
/// @param[out] err Error details, if any
void nvim_win_set_option(uint64_t channel_id, Window window, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(11)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  set_option_to(channel_id, win, kOptReqWin, name, value, err);
}

/// Gets the value of a global or local (buffer, window) option.
///
/// @param[in]   from       Pointer to buffer or window for local option value.
/// @param       req_scope  Requested option scope. See OptReqScope in option.h.
/// @param       name       The option name.
/// @param[out]  err        Details of an error that may have occurred.
///
/// @return  the option value.
static Object get_option_from(void *from, OptReqScope req_scope, String name, Error *err)
{
  VALIDATE_S(name.size > 0, "option name", "<empty>", {
    return (Object)OBJECT_INIT;
  });

  OptVal value = get_option_value_strict(find_option(name.data), req_scope, from, err);
  if (ERROR_SET(err)) {
    return (Object)OBJECT_INIT;
  }

  VALIDATE_S(value.type != kOptValTypeNil, "option name", name.data, {
    return (Object)OBJECT_INIT;
  });

  return optval_as_object(value);
}

/// Sets the value of a global or local (buffer, window) option.
///
/// @param[in]   to         Pointer to buffer or window for local option value.
/// @param       req_scope  Requested option scope. See OptReqScope in option.h.
/// @param       name       The option name.
/// @param       value      New option value.
/// @param[out]  err        Details of an error that may have occurred.
static void set_option_to(uint64_t channel_id, void *to, OptReqScope req_scope, String name,
                          Object value, Error *err)
{
  VALIDATE_S(name.size > 0, "option name", "<empty>", {
    return;
  });

  OptIndex opt_idx = find_option(name.data);
  VALIDATE_S(opt_idx != kOptInvalid, "option name", name.data, {
    return;
  });

  bool error = false;
  OptVal optval = object_as_optval(value, &error);

  // Handle invalid option value type.
  // Don't use `name` in the error message here, because `name` can be any String.
  // No need to check if value type actually matches the types for the option, as set_option_value()
  // already handles that.
  VALIDATE_EXP(!error, "value", "valid option type", api_typename(value.type), {
    return;
  });

  int attrs = get_option_attrs(opt_idx);
  // For global-win-local options -> setlocal
  // For        win-local options -> setglobal and setlocal (opt_flags == 0)
  const int opt_flags = (req_scope == kOptReqWin && !(attrs & SOPT_GLOBAL))
                        ? 0
                        : (req_scope == kOptReqGlobal) ? OPT_GLOBAL : OPT_LOCAL;

  WITH_SCRIPT_CONTEXT(channel_id, {
    set_option_value_for(name.data, opt_idx, optval, opt_flags, req_scope, to, err);
  });
}
