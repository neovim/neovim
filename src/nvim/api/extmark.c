#include <assert.h>
#include <lauxlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/decoration_provider.h"
#include "nvim/drawscreen.h"
#include "nvim/extmark.h"
#include "nvim/grid.h"
#include "nvim/highlight_group.h"
#include "nvim/map_defs.h"
#include "nvim/marktree.h"
#include "nvim/marktree_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/pos_defs.h"
#include "nvim/sign.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/extmark.c.generated.h"
#endif

void api_extmark_free_all_mem(void)
{
  String name;
  map_foreach_key(&namespace_ids, name, {
    xfree(name.data);
  })
  map_destroy(String, &namespace_ids);
}

/// Creates a new namespace or gets an existing one. [namespace]()
///
/// Namespaces are used for buffer highlights and virtual text, see
/// |nvim_buf_add_highlight()| and |nvim_buf_set_extmark()|.
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
  handle_T id = map_get(String, int)(&namespace_ids, name);
  if (id > 0) {
    return id;
  }
  id = next_namespace_id++;
  if (name.size > 0) {
    String name_alloc = copy_string(name, NULL);
    map_put(String, int)(&namespace_ids, name_alloc, id);
  }
  return (Integer)id;
}

/// Gets existing, non-anonymous |namespace|s.
///
/// @return dict that maps from names to namespace ids.
Dictionary nvim_get_namespaces(Arena *arena)
  FUNC_API_SINCE(5)
{
  Dictionary retval = arena_dict(arena, map_size(&namespace_ids));
  String name;
  handle_T id;

  map_foreach(&namespace_ids, name, id, {
    PUT_C(retval, name.data, INTEGER_OBJ(id));
  })

  return retval;
}

const char *describe_ns(NS ns_id, const char *unknown)
{
  String name;
  handle_T id;
  map_foreach(&namespace_ids, name, id, {
    if ((NS)id == ns_id && name.size) {
      return name.data;
    }
  })
  return unknown;
}

// Is the Namespace in use?
bool ns_initialized(uint32_t ns)
{
  if (ns < 1) {
    return false;
  }
  return ns < (uint32_t)next_namespace_id;
}

Array virt_text_to_array(VirtText vt, bool hl_name, Arena *arena)
{
  Array chunks = arena_array(arena, kv_size(vt));
  for (size_t i = 0; i < kv_size(vt); i++) {
    size_t j = i;
    for (; j < kv_size(vt); j++) {
      if (kv_A(vt, j).text != NULL) {
        break;
      }
    }

    Array hl_array = arena_array(arena, i < j ? j - i + 1 : 0);
    for (; i < j; i++) {
      int hl_id = kv_A(vt, i).hl_id;
      if (hl_id > 0) {
        ADD_C(hl_array, hl_group_name(hl_id, hl_name));
      }
    }

    char *text = kv_A(vt, i).text;
    int hl_id = kv_A(vt, i).hl_id;
    Array chunk = arena_array(arena, 2);
    ADD_C(chunk, CSTR_AS_OBJ(text));
    if (hl_array.size > 0) {
      if (hl_id > 0) {
        ADD_C(hl_array, hl_group_name(hl_id, hl_name));
      }
      ADD_C(chunk, ARRAY_OBJ(hl_array));
    } else if (hl_id > 0) {
      ADD_C(chunk, hl_group_name(hl_id, hl_name));
    }
    ADD_C(chunks, ARRAY_OBJ(chunk));
  }
  return chunks;
}

static Array extmark_to_array(MTPair extmark, bool id, bool add_dict, bool hl_name, Arena *arena)
{
  MTKey start = extmark.start;
  Array rv = arena_array(arena, 4);
  if (id) {
    ADD_C(rv, INTEGER_OBJ((Integer)start.id));
  }
  ADD_C(rv, INTEGER_OBJ(start.pos.row));
  ADD_C(rv, INTEGER_OBJ(start.pos.col));

  if (add_dict) {
    // TODO(bfredl): coding the size like this is a bit fragile.
    // We want ArrayOf(Dict(set_extmark)) as the return type..
    Dictionary dict = arena_dict(arena, ARRAY_SIZE(set_extmark_table));

    PUT_C(dict, "ns_id", INTEGER_OBJ((Integer)start.ns));

    PUT_C(dict, "right_gravity", BOOLEAN_OBJ(mt_right(start)));

    if (mt_paired(start)) {
      PUT_C(dict, "end_row", INTEGER_OBJ(extmark.end_pos.row));
      PUT_C(dict, "end_col", INTEGER_OBJ(extmark.end_pos.col));
      PUT_C(dict, "end_right_gravity", BOOLEAN_OBJ(extmark.end_right_gravity));
    }

    if (mt_no_undo(start)) {
      PUT_C(dict, "undo_restore", BOOLEAN_OBJ(false));
    }

    if (mt_invalidate(start)) {
      PUT_C(dict, "invalidate", BOOLEAN_OBJ(true));
    }
    if (mt_invalid(start)) {
      PUT_C(dict, "invalid", BOOLEAN_OBJ(true));
    }

    if (mt_scoped(start)) {
      PUT_C(dict, "scoped", BOOLEAN_OBJ(true));
    }

    decor_to_dict_legacy(&dict, mt_decor(start), hl_name, arena);

    ADD_C(rv, DICTIONARY_OBJ(dict));
  }

  return rv;
}

/// Gets the position (0-indexed) of an |extmark|.
///
/// @param buffer  Buffer handle, or 0 for current buffer
/// @param ns_id  Namespace id from |nvim_create_namespace()|
/// @param id  Extmark id
/// @param opts  Optional parameters. Keys:
///          - details: Whether to include the details dict
///          - hl_name: Whether to include highlight group name instead of id, true if omitted
/// @param[out] err   Error details, if any
/// @return 0-indexed (row, col) tuple or empty list () if extmark id was
/// absent
ArrayOf(Integer) nvim_buf_get_extmark_by_id(Buffer buffer, Integer ns_id,
                                            Integer id, Dict(get_extmark) *opts,
                                            Arena *arena, Error *err)
  FUNC_API_SINCE(7)
{
  Array rv = ARRAY_DICT_INIT;

  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return rv;
  }

  VALIDATE_INT(ns_initialized((uint32_t)ns_id), "ns_id", ns_id, {
    return rv;
  });

  bool details = opts->details;

  bool hl_name = GET_BOOL_OR_TRUE(opts, get_extmark, hl_name);

  MTPair extmark = extmark_from_id(buf, (uint32_t)ns_id, (uint32_t)id);
  if (extmark.start.pos.row < 0) {
    return rv;
  }
  return extmark_to_array(extmark, false, details, hl_name, arena);
}

/// Gets |extmarks| in "traversal order" from a |charwise| region defined by
/// buffer positions (inclusive, 0-indexed |api-indexing|).
///
/// Region can be given as (row,col) tuples, or valid extmark ids (whose
/// positions define the bounds). 0 and -1 are understood as (0,0) and (-1,-1)
/// respectively, thus the following are equivalent:
///
/// ```lua
/// vim.api.nvim_buf_get_extmarks(0, my_ns, 0, -1, {})
/// vim.api.nvim_buf_get_extmarks(0, my_ns, {0,0}, {-1,-1}, {})
/// ```
///
/// If `end` is less than `start`, traversal works backwards. (Useful
/// with `limit`, to get the first marks prior to a given position.)
///
/// Note: when using extmark ranges (marks with a end_row/end_col position)
/// the `overlap` option might be useful. Otherwise only the start position
/// of an extmark will be considered.
///
/// Note: legacy signs placed through the |:sign| commands are implemented
/// as extmarks and will show up here. Their details array will contain a
/// `sign_name` field.
///
/// Example:
///
/// ```lua
/// local api = vim.api
/// local pos = api.nvim_win_get_cursor(0)
/// local ns  = api.nvim_create_namespace('my-plugin')
/// -- Create new extmark at line 1, column 1.
/// local m1  = api.nvim_buf_set_extmark(0, ns, 0, 0, {})
/// -- Create new extmark at line 3, column 1.
/// local m2  = api.nvim_buf_set_extmark(0, ns, 2, 0, {})
/// -- Get extmarks only from line 3.
/// local ms  = api.nvim_buf_get_extmarks(0, ns, {2,0}, {2,0}, {})
/// -- Get all marks in this buffer + namespace.
/// local all = api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
/// vim.print(ms)
/// ```
///
/// @param buffer  Buffer handle, or 0 for current buffer
/// @param ns_id  Namespace id from |nvim_create_namespace()| or -1 for all namespaces
/// @param start  Start of range: a 0-indexed (row, col) or valid extmark id
/// (whose position defines the bound). |api-indexing|
/// @param end  End of range (inclusive): a 0-indexed (row, col) or valid
/// extmark id (whose position defines the bound). |api-indexing|
/// @param opts  Optional parameters. Keys:
///          - limit:  Maximum number of marks to return
///          - details: Whether to include the details dict
///          - hl_name: Whether to include highlight group name instead of id, true if omitted
///          - overlap: Also include marks which overlap the range, even if
///                     their start position is less than `start`
///          - type: Filter marks by type: "highlight", "sign", "virt_text" and "virt_lines"
/// @param[out] err   Error details, if any
/// @return List of `[extmark_id, row, col]` tuples in "traversal order".
Array nvim_buf_get_extmarks(Buffer buffer, Integer ns_id, Object start, Object end,
                            Dict(get_extmarks) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(7)
{
  Array rv = ARRAY_DICT_INIT;

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return rv;
  }

  VALIDATE_INT(ns_id == -1 || ns_initialized((uint32_t)ns_id), "ns_id", ns_id, {
    return rv;
  });

  bool details = opts->details;
  bool hl_name = GET_BOOL_OR_TRUE(opts, get_extmarks, hl_name);

  ExtmarkType type = kExtmarkNone;
  if (HAS_KEY(opts, get_extmarks, type)) {
    if (strequal(opts->type.data, "sign")) {
      type = kExtmarkSign;
    } else if (strequal(opts->type.data, "virt_text")) {
      type = kExtmarkVirtText;
    } else if (strequal(opts->type.data, "virt_lines")) {
      type = kExtmarkVirtLines;
    } else if (strequal(opts->type.data, "highlight")) {
      type = kExtmarkHighlight;
    } else {
      VALIDATE_EXP(false, "type", "sign, virt_text, virt_lines or highlight", opts->type.data, {
        return rv;
      });
    }
  }

  Integer limit = HAS_KEY(opts, get_extmarks, limit) ? opts->limit : -1;

  if (limit == 0) {
    return rv;
  } else if (limit < 0) {
    limit = INT64_MAX;
  }

  bool reverse = false;

  int l_row;
  colnr_T l_col;
  if (!extmark_get_index_from_obj(buf, ns_id, start, &l_row, &l_col, err)) {
    return rv;
  }

  int u_row;
  colnr_T u_col;
  if (!extmark_get_index_from_obj(buf, ns_id, end, &u_row, &u_col, err)) {
    return rv;
  }

  if (l_row > u_row || (l_row == u_row && l_col > u_col)) {
    reverse = true;
  }

  // note: ns_id=-1 allowed, represented as UINT32_MAX
  ExtmarkInfoArray marks = extmark_get(buf, (uint32_t)ns_id, l_row, l_col, u_row,
                                       u_col, (int64_t)limit, reverse, type, opts->overlap);

  rv = arena_array(arena, kv_size(marks));
  for (size_t i = 0; i < kv_size(marks); i++) {
    ADD_C(rv, ARRAY_OBJ(extmark_to_array(kv_A(marks, i), true, details, hl_name, arena)));
  }

  kv_destroy(marks);
  return rv;
}

/// Creates or updates an |extmark|.
///
/// By default a new extmark is created when no id is passed in, but it is also
/// possible to create a new mark by passing in a previously unused id or move
/// an existing mark by passing in its id. The caller must then keep track of
/// existing and unused ids itself. (Useful over RPC, to avoid waiting for the
/// return value.)
///
/// Using the optional arguments, it is possible to use this to highlight
/// a range of text, and also to associate virtual text to the mark.
///
/// If present, the position defined by `end_col` and `end_row` should be after
/// the start position in order for the extmark to cover a range.
/// An earlier end position is not an error, but then it behaves like an empty
/// range (no highlighting).
///
/// @param buffer  Buffer handle, or 0 for current buffer
/// @param ns_id  Namespace id from |nvim_create_namespace()|
/// @param line  Line where to place the mark, 0-based. |api-indexing|
/// @param col  Column where to place the mark, 0-based. |api-indexing|
/// @param opts  Optional parameters.
///               - id : id of the extmark to edit.
///               - end_row : ending line of the mark, 0-based inclusive.
///               - end_col : ending col of the mark, 0-based exclusive.
///               - hl_group : name of the highlight group used to highlight
///                   this mark.
///               - hl_eol : when true, for a multiline highlight covering the
///                          EOL of a line, continue the highlight for the rest
///                          of the screen line (just like for diff and
///                          cursorline highlight).
///               - virt_text : virtual text to link to this mark.
///                   A list of `[text, highlight]` tuples, each representing a
///                   text chunk with specified highlight. `highlight` element
///                   can either be a single highlight group, or an array of
///                   multiple highlight groups that will be stacked
///                   (highest priority last). A highlight group can be supplied
///                   either as a string or as an integer, the latter which
///                   can be obtained using |nvim_get_hl_id_by_name()|.
///               - virt_text_pos : position of virtual text. Possible values:
///                 - "eol": right after eol character (default).
///                 - "overlay": display over the specified column, without
///                              shifting the underlying text.
///                 - "right_align": display right aligned in the window.
///                 - "inline": display at the specified column, and
///                             shift the buffer text to the right as needed.
///               - virt_text_win_col : position the virtual text at a fixed
///                                     window column (starting from the first
///                                     text column of the screen line) instead
///                                     of "virt_text_pos".
///               - virt_text_hide : hide the virtual text when the background
///                                  text is selected or hidden because of
///                                  scrolling with 'nowrap' or 'smoothscroll'.
///                                  Currently only affects "overlay" virt_text.
///               - virt_text_repeat_linebreak : repeat the virtual text on
///                                              wrapped lines.
///               - hl_mode : control how highlights are combined with the
///                           highlights of the text. Currently only affects
///                           virt_text highlights, but might affect `hl_group`
///                           in later versions.
///                 - "replace": only show the virt_text color. This is the default.
///                 - "combine": combine with background text color.
///                 - "blend": blend with background text color.
///                            Not supported for "inline" virt_text.
///
///               - virt_lines : virtual lines to add next to this mark
///                   This should be an array over lines, where each line in
///                   turn is an array over `[text, highlight]` tuples. In
///                   general, buffer and window options do not affect the
///                   display of the text. In particular 'wrap'
///                   and 'linebreak' options do not take effect, so
///                   the number of extra screen lines will always match
///                   the size of the array. However the 'tabstop' buffer
///                   option is still used for hard tabs. By default lines are
///                   placed below the buffer line containing the mark.
///
///               - virt_lines_above: place virtual lines above instead.
///               - virt_lines_leftcol: Place extmarks in the leftmost
///                                     column of the window, bypassing
///                                     sign and number columns.
///
///               - ephemeral : for use with |nvim_set_decoration_provider()|
///                   callbacks. The mark will only be used for the current
///                   redraw cycle, and not be permantently stored in the
///                   buffer.
///               - right_gravity : boolean that indicates the direction
///                   the extmark will be shifted in when new text is inserted
///                   (true for right, false for left). Defaults to true.
///               - end_right_gravity : boolean that indicates the direction
///                   the extmark end position (if it exists) will be shifted
///                   in when new text is inserted (true for right, false
///                   for left). Defaults to false.
///               - undo_restore : Restore the exact position of the mark
///                   if text around the mark was deleted and then restored by undo.
///                   Defaults to true.
///               - invalidate : boolean that indicates whether to hide the
///                   extmark if the entirety of its range is deleted. For
///                   hidden marks, an "invalid" key is added to the "details"
///                   array of |nvim_buf_get_extmarks()| and family. If
///                   "undo_restore" is false, the extmark is deleted instead.
///               - priority: a priority value for the highlight group, sign
///                   attribute or virtual text. For virtual text, item with
///                   highest priority is drawn last. For example treesitter
///                   highlighting uses a value of 100.
///               - strict: boolean that indicates extmark should not be placed
///                   if the line or column value is past the end of the
///                   buffer or end of the line respectively. Defaults to true.
///               - sign_text: string of length 1-2 used to display in the
///                   sign column.
///               - sign_hl_group: name of the highlight group used to
///                   highlight the sign column text.
///               - number_hl_group: name of the highlight group used to
///                   highlight the number column.
///               - line_hl_group: name of the highlight group used to
///                   highlight the whole line.
///               - cursorline_hl_group: name of the highlight group used to
///                   highlight the sign column text when the cursor is on
///                   the same line as the mark and 'cursorline' is enabled.
///               - conceal: string which should be either empty or a single
///                   character. Enable concealing similar to |:syn-conceal|.
///                   When a character is supplied it is used as |:syn-cchar|.
///                   "hl_group" is used as highlight for the cchar if provided,
///                   otherwise it defaults to |hl-Conceal|.
///               - spell: boolean indicating that spell checking should be
///                   performed within this extmark
///               - ui_watched: boolean that indicates the mark should be drawn
///                   by a UI. When set, the UI will receive win_extmark events.
///                   Note: the mark is positioned by virt_text attributes. Can be
///                   used together with virt_text.
///               - url: A URL to associate with this extmark. In the TUI, the OSC 8 control
///                   sequence is used to generate a clickable hyperlink to this URL.
///               - scoped: boolean that indicates that the extmark should only be
///                   displayed in the namespace scope. (experimental)
///
/// @param[out]  err   Error details, if any
/// @return Id of the created/updated extmark
Integer nvim_buf_set_extmark(Buffer buffer, Integer ns_id, Integer line, Integer col,
                             Dict(set_extmark) *opts, Error *err)
  FUNC_API_SINCE(7)
{
  DecorHighlightInline hl = DECOR_HIGHLIGHT_INLINE_INIT;
  // TODO(bfredl): in principle signs with max one (1) hl group and max 4 bytes of text.
  // should be a candidate for inlining as well.
  DecorSignHighlight sign = DECOR_SIGN_HIGHLIGHT_INIT;
  DecorVirtText virt_text = DECOR_VIRT_TEXT_INIT;
  DecorVirtText virt_lines = DECOR_VIRT_LINES_INIT;
  char *url = NULL;
  bool has_hl = false;

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    goto error;
  }

  VALIDATE_INT(ns_initialized((uint32_t)ns_id), "ns_id", ns_id, {
    goto error;
  });

  uint32_t id = 0;
  if (HAS_KEY(opts, set_extmark, id)) {
    VALIDATE_EXP((opts->id > 0), "id", "positive Integer", NULL, {
      goto error;
    });

    id = (uint32_t)opts->id;
  }

  int line2 = -1;
  bool did_end_line = false;

  // For backward compatibility we support "end_line" as an alias for "end_row"
  if (HAS_KEY(opts, set_extmark, end_line)) {
    VALIDATE(!HAS_KEY(opts, set_extmark, end_row),
             "%s", "cannot use both 'end_row' and 'end_line'", {
      goto error;
    });

    opts->end_row = opts->end_line;
    did_end_line = true;
  }

  bool strict = GET_BOOL_OR_TRUE(opts, set_extmark, strict);

  if (HAS_KEY(opts, set_extmark, end_row) || did_end_line) {
    Integer val = opts->end_row;
    VALIDATE_RANGE((val >= 0 && !(val > buf->b_ml.ml_line_count && strict)), "end_row", {
      goto error;
    });
    line2 = (int)val;
  }

  colnr_T col2 = -1;
  if (HAS_KEY(opts, set_extmark, end_col)) {
    Integer val = opts->end_col;
    VALIDATE_RANGE((val >= 0 && val <= MAXCOL), "end_col", {
      goto error;
    });
    col2 = (int)val;
  }

  hl.hl_id = (int)opts->hl_group;
  has_hl = hl.hl_id > 0;
  sign.hl_id = (int)opts->sign_hl_group;
  sign.cursorline_hl_id = (int)opts->cursorline_hl_group;
  sign.number_hl_id = (int)opts->number_hl_group;
  sign.line_hl_id = (int)opts->line_hl_group;

  if (sign.hl_id || sign.cursorline_hl_id || sign.number_hl_id || sign.line_hl_id) {
    sign.flags |= kSHIsSign;
  }

  if (HAS_KEY(opts, set_extmark, conceal)) {
    hl.flags |= kSHConceal;
    has_hl = true;
    String c = opts->conceal;
    if (c.size > 0) {
      int ch;
      hl.conceal_char = utfc_ptr2schar_len(c.data, (int)c.size, &ch);
      if (!hl.conceal_char || !vim_isprintc(ch)) {
        api_set_error(err, kErrorTypeValidation, "conceal char has to be printable");
        goto error;
      }
    }
  }

  if (HAS_KEY(opts, set_extmark, virt_text)) {
    virt_text.data.virt_text = parse_virt_text(opts->virt_text, err, &virt_text.width);
    if (ERROR_SET(err)) {
      goto error;
    }
  }

  if (HAS_KEY(opts, set_extmark, virt_text_pos)) {
    String str = opts->virt_text_pos;
    if (strequal("eol", str.data)) {
      virt_text.pos = kVPosEndOfLine;
    } else if (strequal("overlay", str.data)) {
      virt_text.pos = kVPosOverlay;
    } else if (strequal("right_align", str.data)) {
      virt_text.pos = kVPosRightAlign;
    } else if (strequal("inline", str.data)) {
      virt_text.pos = kVPosInline;
    } else {
      VALIDATE_S(false, "virt_text_pos", str.data, {
        goto error;
      });
    }
  }

  if (HAS_KEY(opts, set_extmark, virt_text_win_col)) {
    virt_text.col = (int)opts->virt_text_win_col;
    virt_text.pos = kVPosWinCol;
  }

  hl.flags |= opts->hl_eol ? kSHHlEol : 0;
  virt_text.flags |= ((opts->virt_text_hide ? kVTHide : 0)
                      | (opts->virt_text_repeat_linebreak ? kVTRepeatLinebreak : 0));

  if (HAS_KEY(opts, set_extmark, hl_mode)) {
    String str = opts->hl_mode;
    if (strequal("replace", str.data)) {
      virt_text.hl_mode = kHlModeReplace;
    } else if (strequal("combine", str.data)) {
      virt_text.hl_mode = kHlModeCombine;
    } else if (strequal("blend", str.data)) {
      if (virt_text.pos == kVPosInline) {
        VALIDATE(false, "%s", "cannot use 'blend' hl_mode with inline virtual text", {
          goto error;
        });
      }
      virt_text.hl_mode = kHlModeBlend;
    } else {
      VALIDATE_S(false, "hl_mode", str.data, {
        goto error;
      });
    }
  }

  bool virt_lines_leftcol = opts->virt_lines_leftcol;

  if (HAS_KEY(opts, set_extmark, virt_lines)) {
    Array a = opts->virt_lines;
    for (size_t j = 0; j < a.size; j++) {
      VALIDATE_T("virt_text_line", kObjectTypeArray, a.items[j].type, {
        goto error;
      });
      int dummig;
      VirtText jtem = parse_virt_text(a.items[j].data.array, err, &dummig);
      kv_push(virt_lines.data.virt_lines, ((struct virt_line){ jtem, virt_lines_leftcol }));
      if (ERROR_SET(err)) {
        goto error;
      }
    }
  }

  virt_lines.flags |= opts->virt_lines_above ? kVTLinesAbove : 0;

  if (HAS_KEY(opts, set_extmark, priority)) {
    VALIDATE_RANGE((opts->priority >= 0 && opts->priority <= UINT16_MAX), "priority", {
      goto error;
    });
    hl.priority = (DecorPriority)opts->priority;
    sign.priority = (DecorPriority)opts->priority;
    virt_text.priority = (DecorPriority)opts->priority;
    virt_lines.priority = (DecorPriority)opts->priority;
  }

  if (HAS_KEY(opts, set_extmark, sign_text)) {
    sign.text[0] = 0;
    VALIDATE_S(init_sign_text(NULL, sign.text, opts->sign_text.data), "sign_text", "", {
      goto error;
    });
    sign.flags |= kSHIsSign;
  }

  bool right_gravity = GET_BOOL_OR_TRUE(opts, set_extmark, right_gravity);

  // Only error out if they try to set end_right_gravity without
  // setting end_col or end_row
  VALIDATE(!(line2 == -1 && col2 == -1 && HAS_KEY(opts, set_extmark, end_right_gravity)),
           "%s", "cannot set end_right_gravity without end_row or end_col", {
    goto error;
  });

  colnr_T len = 0;

  if (HAS_KEY(opts, set_extmark, spell)) {
    hl.flags |= (opts->spell) ? kSHSpellOn : kSHSpellOff;
    has_hl = true;
  }

  if (HAS_KEY(opts, set_extmark, url)) {
    url = string_to_cstr(opts->url);
  }

  if (opts->ui_watched) {
    hl.flags |= kSHUIWatched;
    if (virt_text.pos == kVPosOverlay) {
      // TODO(bfredl): in a revised interface this should be the default.
      hl.flags |= kSHUIWatchedOverlay;
    }
    has_hl = true;
  }

  VALIDATE_RANGE((line >= 0), "line", {
    goto error;
  });

  if (line > buf->b_ml.ml_line_count) {
    VALIDATE_RANGE(!strict, "line", {
      goto error;
    });
    line = buf->b_ml.ml_line_count;
  } else if (line < buf->b_ml.ml_line_count) {
    len = opts->ephemeral ? MAXCOL : ml_get_buf_len(buf, (linenr_T)line + 1);
  }

  if (col == -1) {
    col = len;
  } else if (col > len) {
    VALIDATE_RANGE(!strict, "col", {
      goto error;
    });
    col = len;
  } else if (col < -1) {
    VALIDATE_RANGE(false, "col", {
      goto error;
    });
  }

  if (col2 >= 0) {
    if (line2 >= 0 && line2 < buf->b_ml.ml_line_count) {
      len = opts->ephemeral ? MAXCOL : ml_get_buf_len(buf, (linenr_T)line2 + 1);
    } else if (line2 == buf->b_ml.ml_line_count) {
      // We are trying to add an extmark past final newline
      len = 0;
    } else {
      // reuse len from before
      line2 = (int)line;
    }
    if (col2 > len) {
      VALIDATE_RANGE(!strict, "end_col", {
        goto error;
      });
      col2 = len;
    }
  } else if (line2 >= 0) {
    col2 = 0;
  }

  if (opts->ephemeral && decor_state.win && decor_state.win->w_buffer == buf) {
    if (opts->scoped) {
      api_set_error(err, kErrorTypeException, "not yet implemented");
      goto error;
    }

    int r = (int)line;
    int c = (int)col;
    if (line2 == -1) {
      line2 = r;
      col2 = c;
    }

    DecorPriority subpriority = DECOR_PRIORITY_BASE;
    if (HAS_KEY(opts, set_extmark, _subpriority)) {
      VALIDATE_RANGE((opts->_subpriority >= 0 && opts->_subpriority <= UINT16_MAX),
                     "_subpriority", {
        goto error;
      });
      subpriority = (DecorPriority)opts->_subpriority;
    }

    if (kv_size(virt_text.data.virt_text)) {
      decor_range_add_virt(&decor_state, r, c, line2, col2, decor_put_vt(virt_text, NULL), true,
                           subpriority);
    }
    if (kv_size(virt_lines.data.virt_lines)) {
      decor_range_add_virt(&decor_state, r, c, line2, col2, decor_put_vt(virt_lines, NULL), true,
                           subpriority);
    }
    if (url != NULL) {
      DecorSignHighlight sh = DECOR_SIGN_HIGHLIGHT_INIT;
      sh.url = url;
      decor_range_add_sh(&decor_state, r, c, line2, col2, &sh, true, 0, 0, subpriority);
    }
    if (has_hl) {
      DecorSignHighlight sh = decor_sh_from_inline(hl);
      decor_range_add_sh(&decor_state, r, c, line2, col2, &sh, true, (uint32_t)ns_id, id,
                         subpriority);
    }
  } else {
    if (opts->ephemeral) {
      api_set_error(err, kErrorTypeException, "not yet implemented");
      goto error;
    }

    uint16_t decor_flags = 0;

    DecorVirtText *decor_alloc = NULL;
    if (kv_size(virt_text.data.virt_text)) {
      decor_alloc = decor_put_vt(virt_text, decor_alloc);
      if (virt_text.pos == kVPosInline) {
        decor_flags |= MT_FLAG_DECOR_VIRT_TEXT_INLINE;
      }
    }
    if (kv_size(virt_lines.data.virt_lines)) {
      decor_alloc = decor_put_vt(virt_lines, decor_alloc);
      decor_flags |= MT_FLAG_DECOR_VIRT_LINES;
    }

    uint32_t decor_indexed = DECOR_ID_INVALID;
    if (url != NULL) {
      DecorSignHighlight sh = DECOR_SIGN_HIGHLIGHT_INIT;
      sh.url = url;
      sh.next = decor_indexed;
      decor_indexed = decor_put_sh(sh);
    }
    if (sign.flags & kSHIsSign) {
      sign.next = decor_indexed;
      decor_indexed = decor_put_sh(sign);
      if (sign.text[0]) {
        decor_flags |= MT_FLAG_DECOR_SIGNTEXT;
      }
      if (sign.number_hl_id || sign.line_hl_id || sign.cursorline_hl_id) {
        decor_flags |= MT_FLAG_DECOR_SIGNHL;
      }
    }

    DecorInline decor = DECOR_INLINE_INIT;
    if (decor_alloc || decor_indexed != DECOR_ID_INVALID || schar_high(hl.conceal_char)) {
      if (has_hl) {
        DecorSignHighlight sh = decor_sh_from_inline(hl);
        sh.next = decor_indexed;
        decor_indexed = decor_put_sh(sh);
      }
      decor.ext = true;
      decor.data.ext = (DecorExt){ .sh_idx = decor_indexed, .vt = decor_alloc };
    } else {
      decor.data.hl = hl;
    }

    if (has_hl) {
      decor_flags |= MT_FLAG_DECOR_HL;
    }

    extmark_set(buf, (uint32_t)ns_id, &id, (int)line, (colnr_T)col, line2, col2,
                decor, decor_flags, right_gravity, opts->end_right_gravity,
                !GET_BOOL_OR_TRUE(opts, set_extmark, undo_restore),
                opts->invalidate, opts->scoped, err);
    if (ERROR_SET(err)) {
      decor_free(decor);
      return 0;
    }
  }

  return (Integer)id;

error:
  clear_virttext(&virt_text.data.virt_text);
  clear_virtlines(&virt_lines.data.virt_lines);
  if (url != NULL) {
    xfree(url);
  }

  return 0;
}

/// Removes an |extmark|.
///
/// @param buffer Buffer handle, or 0 for current buffer
/// @param ns_id Namespace id from |nvim_create_namespace()|
/// @param id Extmark id
/// @param[out] err   Error details, if any
/// @return true if the extmark was found, else false
Boolean nvim_buf_del_extmark(Buffer buffer, Integer ns_id, Integer id, Error *err)
  FUNC_API_SINCE(7)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return false;
  }
  VALIDATE_INT(ns_initialized((uint32_t)ns_id), "ns_id", ns_id, {
    return false;
  });

  return extmark_del_id(buf, (uint32_t)ns_id, (uint32_t)id);
}

uint32_t src2ns(Integer *src_id)
{
  if (*src_id == 0) {
    *src_id = nvim_create_namespace((String)STRING_INIT);
  }
  if (*src_id < 0) {
    return (((uint32_t)1) << 31) - 1;
  }
  return (uint32_t)(*src_id);
}

/// Adds a highlight to buffer.
///
/// Useful for plugins that dynamically generate highlights to a buffer
/// (like a semantic highlighter or linter). The function adds a single
/// highlight to a buffer. Unlike |matchaddpos()| highlights follow changes to
/// line numbering (as lines are inserted/removed above the highlighted line),
/// like signs and marks do.
///
/// Namespaces are used for batch deletion/updating of a set of highlights. To
/// create a namespace, use |nvim_create_namespace()| which returns a namespace
/// id. Pass it in to this function as `ns_id` to add highlights to the
/// namespace. All highlights in the same namespace can then be cleared with
/// single call to |nvim_buf_clear_namespace()|. If the highlight never will be
/// deleted by an API call, pass `ns_id = -1`.
///
/// As a shorthand, `ns_id = 0` can be used to create a new namespace for the
/// highlight, the allocated id is then returned. If `hl_group` is the empty
/// string no highlight is added, but a new `ns_id` is still returned. This is
/// supported for backwards compatibility, new code should use
/// |nvim_create_namespace()| to create a new empty namespace.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param ns_id      namespace to use or -1 for ungrouped highlight
/// @param hl_group   Name of the highlight group to use
/// @param line       Line to highlight (zero-indexed)
/// @param col_start  Start of (byte-indexed) column range to highlight
/// @param col_end    End of (byte-indexed) column range to highlight,
///                   or -1 to highlight to end of line
/// @param[out] err   Error details, if any
/// @return The ns_id that was used
Integer nvim_buf_add_highlight(Buffer buffer, Integer ns_id, String hl_group, Integer line,
                               Integer col_start, Integer col_end, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return 0;
  }

  VALIDATE_RANGE((line >= 0 && line < MAXLNUM), "line number", {
    return 0;
  });
  VALIDATE_RANGE((col_start >= 0 && col_start <= MAXCOL), "column", {
    return 0;
  });

  if (col_end < 0 || col_end > MAXCOL) {
    col_end = MAXCOL;
  }

  uint32_t ns = src2ns(&ns_id);

  if (!(line < buf->b_ml.ml_line_count)) {
    // safety check, we can't add marks outside the range
    return ns_id;
  }

  int hl_id = 0;
  if (hl_group.size > 0) {
    hl_id = syn_check_group(hl_group.data, hl_group.size);
  } else {
    return ns_id;
  }

  int end_line = (int)line;
  if (col_end == MAXCOL) {
    col_end = 0;
    end_line++;
  }

  DecorInline decor = DECOR_INLINE_INIT;
  decor.data.hl.hl_id = hl_id;

  extmark_set(buf, ns, NULL, (int)line, (colnr_T)col_start, end_line, (colnr_T)col_end,
              decor, MT_FLAG_DECOR_HL, true, false, false, false, false, NULL);
  return ns_id;
}

/// Clears |namespace|d objects (highlights, |extmarks|, virtual text) from
/// a region.
///
/// Lines are 0-indexed. |api-indexing|  To clear the namespace in the entire
/// buffer, specify line_start=0 and line_end=-1.
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param ns_id      Namespace to clear, or -1 to clear all namespaces.
/// @param line_start Start of range of lines to clear
/// @param line_end   End of range of lines to clear (exclusive) or -1 to clear
///                   to end of buffer.
/// @param[out] err   Error details, if any
void nvim_buf_clear_namespace(Buffer buffer, Integer ns_id, Integer line_start, Integer line_end,
                              Error *err)
  FUNC_API_SINCE(5)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return;
  }

  VALIDATE_RANGE((line_start >= 0 && line_start < MAXLNUM), "line number", {
    return;
  });

  if (line_end < 0 || line_end > MAXLNUM) {
    line_end = MAXLNUM;
  }
  extmark_clear(buf, (ns_id < 0 ? 0 : (uint32_t)ns_id),
                (int)line_start, 0,
                (int)line_end - 1, MAXCOL);
}

/// Set or change decoration provider for a |namespace|
///
/// This is a very general purpose interface for having Lua callbacks
/// being triggered during the redraw code.
///
/// The expected usage is to set |extmarks| for the currently
/// redrawn buffer. |nvim_buf_set_extmark()| can be called to add marks
/// on a per-window or per-lines basis. Use the `ephemeral` key to only
/// use the mark for the current screen redraw (the callback will be called
/// again for the next redraw).
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
/// Doing things like changing options are not explicitly forbidden, but is
/// likely to have unexpected consequences (such as 100% CPU consumption).
/// doing `vim.rpcnotify` should be OK, but `vim.rpcrequest` is quite dubious
/// for the moment.
///
/// Note: It is not allowed to remove or update extmarks in 'on_line' callbacks.
///
/// @param ns_id  Namespace id from |nvim_create_namespace()|
/// @param opts  Table of callbacks:
///             - on_start: called first on each screen redraw
///               ```
///                 ["start", tick]
///               ```
///             - on_buf: called for each buffer being redrawn (before
///               window callbacks)
///               ```
///                 ["buf", bufnr, tick]
///               ```
///             - on_win: called when starting to redraw a specific window.
///               ```
///                 ["win", winid, bufnr, topline, botline]
///               ```
///             - on_line: called for each buffer line being redrawn.
///                 (The interaction with fold lines is subject to change)
///               ```
///                 ["line", winid, bufnr, row]
///               ```
///             - on_end: called at the end of a redraw cycle
///               ```
///                 ["end", tick]
///               ```
void nvim_set_decoration_provider(Integer ns_id, Dict(set_decoration_provider) *opts, Error *err)
  FUNC_API_SINCE(7) FUNC_API_LUA_ONLY
{
  DecorProvider *p = get_decor_provider((NS)ns_id, true);
  assert(p != NULL);
  decor_provider_clear(p);

  // regardless of what happens, it seems good idea to redraw
  redraw_all_later(UPD_NOT_VALID);  // TODO(bfredl): too soon?

  struct {
    const char *name;
    LuaRef *source;
    LuaRef *dest;
  } cbs[] = {
    { "on_start", &opts->on_start, &p->redraw_start },
    { "on_buf", &opts->on_buf, &p->redraw_buf },
    { "on_win", &opts->on_win, &p->redraw_win },
    { "on_line", &opts->on_line, &p->redraw_line },
    { "on_end", &opts->on_end, &p->redraw_end },
    { "_on_hl_def", &opts->_on_hl_def, &p->hl_def },
    { "_on_spell_nav", &opts->_on_spell_nav, &p->spell_nav },
    { NULL, NULL, NULL },
  };

  for (size_t i = 0; cbs[i].source && cbs[i].dest && cbs[i].name; i++) {
    LuaRef *v = cbs[i].source;
    if (*v <= 0) {
      continue;
    }

    *(cbs[i].dest) = *v;
    *v = LUA_NOREF;
  }

  p->state = kDecorProviderActive;
  p->hl_valid++;
  p->hl_cached = false;
}

/// Gets the line and column of an |extmark|.
///
/// Extmarks may be queried by position, name or even special names
/// in the future such as "cursor".
///
/// @param[out] lnum extmark line
/// @param[out] colnr extmark column
///
/// @return true if the extmark was found, else false
static bool extmark_get_index_from_obj(buf_T *buf, Integer ns_id, Object obj, int *row,
                                       colnr_T *col, Error *err)
{
  // Check if it is mark id
  if (obj.type == kObjectTypeInteger) {
    Integer id = obj.data.integer;
    if (id == 0) {
      *row = 0;
      *col = 0;
      return true;
    } else if (id == -1) {
      *row = MAXLNUM;
      *col = MAXCOL;
      return true;
    } else if (id < 0) {
      VALIDATE_INT(false, "mark id", id, {
        return false;
      });
    }

    MTPair extmark = extmark_from_id(buf, (uint32_t)ns_id, (uint32_t)id);

    VALIDATE_INT((extmark.start.pos.row >= 0), "mark id (not found)", id, {
      return false;
    });
    *row = extmark.start.pos.row;
    *col = extmark.start.pos.col;
    return true;

    // Check if it is a position
  } else if (obj.type == kObjectTypeArray) {
    Array pos = obj.data.array;
    VALIDATE_EXP((pos.size == 2
                  && pos.items[0].type == kObjectTypeInteger
                  && pos.items[1].type == kObjectTypeInteger),
                 "mark position", "2 Integer items", NULL, {
      return false;
    });

    Integer pos_row = pos.items[0].data.integer;
    Integer pos_col = pos.items[1].data.integer;
    *row = (int)(pos_row >= 0 ? pos_row : MAXLNUM);
    *col = (colnr_T)(pos_col >= 0 ? pos_col : MAXCOL);
    return true;
  } else {
    VALIDATE_EXP(false, "mark position", "mark id Integer or 2-item Array", NULL, {
      return false;
    });
  }
}

VirtText parse_virt_text(Array chunks, Error *err, int *width)
{
  VirtText virt_text = KV_INITIAL_VALUE;
  int w = 0;
  for (size_t i = 0; i < chunks.size; i++) {
    VALIDATE_T("chunk", kObjectTypeArray, chunks.items[i].type, {
      goto free_exit;
    });
    Array chunk = chunks.items[i].data.array;
    VALIDATE((chunk.size > 0 && chunk.size <= 2 && chunk.items[0].type == kObjectTypeString),
             "%s", "Invalid chunk: expected Array with 1 or 2 Strings", {
      goto free_exit;
    });

    String str = chunk.items[0].data.string;

    int hl_id = 0;
    if (chunk.size == 2) {
      Object hl = chunk.items[1];
      if (hl.type == kObjectTypeArray) {
        Array arr = hl.data.array;
        for (size_t j = 0; j < arr.size; j++) {
          hl_id = object_to_hl_id(arr.items[j], "virt_text highlight", err);
          if (ERROR_SET(err)) {
            goto free_exit;
          }
          if (j < arr.size - 1) {
            kv_push(virt_text, ((VirtTextChunk){ .text = NULL, .hl_id = hl_id }));
          }
        }
      } else {
        hl_id = object_to_hl_id(hl, "virt_text highlight", err);
        if (ERROR_SET(err)) {
          goto free_exit;
        }
      }
    }

    char *text = transstr(str.size > 0 ? str.data : "", false);  // allocates
    w += (int)mb_string2cells(text);

    kv_push(virt_text, ((VirtTextChunk){ .text = text, .hl_id = hl_id }));
  }

  if (width != NULL) {
    *width = w;
  }
  return virt_text;

free_exit:
  clear_virttext(&virt_text);
  return virt_text;
}

/// @nodoc
String nvim__buf_debug_extmarks(Buffer buffer, Boolean keys, Boolean dot, Error *err)
  FUNC_API_SINCE(7) FUNC_API_RET_ALLOC
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return NULL_STRING;
  }

  return mt_inspect(buf->b_marktree, keys, dot);
}

/// Adds the namespace scope to the window.
///
/// @param window Window handle, or 0 for current window
/// @param ns_id the namespace to add
/// @return true if the namespace was added, else false
Boolean nvim_win_add_ns(Window window, Integer ns_id, Error *err)
  FUNC_API_SINCE(12)
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return false;
  }

  VALIDATE_INT(ns_initialized((uint32_t)ns_id), "ns_id", ns_id, {
    return false;
  });

  set_put(uint32_t, &win->w_ns_set, (uint32_t)ns_id);

  changed_window_setting(win);

  return true;
}

/// Gets all the namespaces scopes associated with a window.
///
/// @param window Window handle, or 0 for current window
/// @return a list of namespaces ids
ArrayOf(Integer) nvim_win_get_ns(Window window, Arena *arena, Error *err)
  FUNC_API_SINCE(12)
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return (Array)ARRAY_DICT_INIT;
  }

  Array rv = arena_array(arena, set_size(&win->w_ns_set));
  uint32_t i;
  set_foreach(&win->w_ns_set, i, {
    ADD_C(rv, INTEGER_OBJ((Integer)(i)));
  });

  return rv;
}

/// Removes the namespace scope from the window.
///
/// @param window Window handle, or 0 for current window
/// @param ns_id the namespace to remove
/// @return true if the namespace was removed, else false
Boolean nvim_win_remove_ns(Window window, Integer ns_id, Error *err)
  FUNC_API_SINCE(12)
{
  win_T *win = find_window_by_handle(window, err);
  if (!win) {
    return false;
  }

  if (!set_has(uint32_t, &win->w_ns_set, (uint32_t)ns_id)) {
    return false;
  }

  set_del(uint32_t, &win->w_ns_set, (uint32_t)ns_id);

  changed_window_setting(win);

  return true;
}
