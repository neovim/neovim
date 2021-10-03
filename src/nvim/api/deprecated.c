// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/buffer.h"
#include "nvim/api/deprecated.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/extmark.h"
#include "nvim/lua/executor.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/deprecated.c.generated.h"
#endif

/// @deprecated
/// @see nvim_exec
String nvim_command_output(String command, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(7)
{
  return nvim_exec(command, true, err);
}

/// @deprecated Use nvim_exec_lua() instead.
/// @see nvim_exec_lua
Object nvim_execute_lua(String code, Array args, Error *err)
  FUNC_API_SINCE(3)
  FUNC_API_DEPRECATED_SINCE(7)
  FUNC_API_REMOTE_ONLY
{
  return nlua_exec(code, args, err);
}

/// Gets the buffer number
///
/// @deprecated The buffer number now is equal to the object id,
///             so there is no need to use this function.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param[out] err   Error details, if any
/// @return Buffer number
Integer nvim_buf_get_number(Buffer buffer, Error *err)
  FUNC_API_SINCE(1)
  FUNC_API_DEPRECATED_SINCE(2)
{
  Integer rv = 0;
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return rv;
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
/// @deprecated use nvim_buf_set_extmark to use full virtual text
///             functionality.
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
/// @param ns_id      Namespace to use or 0 to create a namespace,
///                   or -1 for a ungrouped annotation
/// @param line       Line to annotate with virtual text (zero-indexed)
/// @param chunks     A list of [text, hl_group] arrays, each representing a
///                   text chunk with specified highlight. `hl_group` element
///                   can be omitted for no highlight.
/// @param opts       Optional parameters. Currently not used.
/// @param[out] err   Error details, if any
/// @return The ns_id that was used
Integer nvim_buf_set_virtual_text(Buffer buffer, Integer src_id, Integer line, Array chunks,
                                  Dictionary opts, Error *err)
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

  if (opts.size > 0) {
    api_set_error(err, kErrorTypeValidation, "opts dict isn't empty");
    return 0;
  }

  uint64_t ns_id = src2ns(&src_id);
  int width;

  VirtText virt_text = parse_virt_text(chunks, err, &width);
  if (ERROR_SET(err)) {
    return 0;
  }


  Decoration *existing = decor_find_virttext(buf, (int)line, ns_id);

  if (existing) {
    clear_virttext(&existing->virt_text);
    existing->virt_text = virt_text;
    existing->virt_text_width = width;
    return src_id;
  }

  Decoration *decor = xcalloc(1, sizeof(*decor));
  decor->virt_text = virt_text;
  decor->virt_text_width = width;

  extmark_set(buf, ns_id, NULL, (int)line, 0, -1, -1, decor, true,
              false, kExtmarkNoUndo);
  return src_id;
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
void buffer_insert(Buffer buffer, Integer lnum, ArrayOf(String) lines, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  // "lnum" will be the index of the line after inserting,
  // no matter if it is negative or not
  nvim_buf_set_lines(0, buffer, lnum, lnum, true, lines, err);
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
String buffer_get_line(Buffer buffer, Integer index, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  String rv = { .size = 0 };

  index = convert_index(index);
  Array slice = nvim_buf_get_lines(0, buffer, index, index+1, true, err);

  if (!ERROR_SET(err) && slice.size) {
    rv = slice.items[0].data.string;
  }

  xfree(slice.items);

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
void buffer_set_line(Buffer buffer, Integer index, String line, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  Object l = STRING_OBJ(line);
  Array array = { .items = &l, .size = 1 };
  index = convert_index(index);
  nvim_buf_set_lines(0, buffer, index, index+1, true,  array, err);
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
void buffer_del_line(Buffer buffer, Integer index, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  Array array = ARRAY_DICT_INIT;
  index = convert_index(index);
  nvim_buf_set_lines(0, buffer, index, index+1, true, array, err);
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
                                      Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  start = convert_index(start) + !include_start;
  end = convert_index(end) + include_end;
  return nvim_buf_get_lines(0, buffer, start, end, false, err);
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
                           Boolean include_end, ArrayOf(String) replacement, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  start = convert_index(start) + !include_start;
  end = convert_index(end) + include_end;
  nvim_buf_set_lines(0, buffer, start, end, false, replacement, err);
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
Object buffer_set_var(Buffer buffer, String name, Object value, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return NIL;
  }

  return dict_set_var(buf->b_vars, name, value, false, true, err);
}

/// Removes a buffer-scoped (b:) variable
///
/// @deprecated
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Variable name
/// @param[out] err   Error details, if any
/// @return Old value
Object buffer_del_var(Buffer buffer, String name, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return NIL;
  }

  return dict_set_var(buf->b_vars, name, NIL, true, true, err);
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
Object window_set_var(Window window, String name, Object value, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return NIL;
  }

  return dict_set_var(win->w_vars, name, value, false, true, err);
}

/// Removes a window-scoped (w:) variable
///
/// @deprecated
///
/// @param window   Window handle, or 0 for current window
/// @param name     variable name
/// @param[out] err Error details, if any
/// @return Old value
Object window_del_var(Window window, String name, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return NIL;
  }

  return dict_set_var(win->w_vars, name, NIL, true, true, err);
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
Object tabpage_set_var(Tabpage tabpage, String name, Object value, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return NIL;
  }

  return dict_set_var(tab->tp_vars, name, value, false, true, err);
}

/// Removes a tab-scoped (t:) variable
///
/// @deprecated
///
/// @param tabpage  Tabpage handle, or 0 for current tabpage
/// @param name     Variable name
/// @param[out] err Error details, if any
/// @return Old value
Object tabpage_del_var(Tabpage tabpage, String name, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  tabpage_T *tab = find_tab_by_handle(tabpage, err);

  if (!tab) {
    return NIL;
  }

  return dict_set_var(tab->tp_vars, name, NIL, true, true, err);
}

/// @deprecated
/// @see nvim_set_var
/// @warning May return nil if there was no previous value
///          OR if previous value was `v:null`.
/// @return Old value or nil if there was no previous value.
Object vim_set_var(String name, Object value, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  return dict_set_var(&globvardict, name, value, false, true, err);
}

/// @deprecated
/// @see nvim_del_var
Object vim_del_var(String name, Error *err)
  FUNC_API_DEPRECATED_SINCE(1)
{
  return dict_set_var(&globvardict, name, NIL, true, true, err);
}

static int64_t convert_index(int64_t index)
{
  return index < 0 ? index - 1 : index;
}
