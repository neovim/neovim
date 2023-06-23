// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "klib/kvec.h"
#include "lauxlib.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/decoration.h"
#include "nvim/decoration_provider.h"
#include "nvim/drawscreen.h"
#include "nvim/extmark.h"
#include "nvim/highlight_group.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/pos.h"
#include "nvim/strings.h"
#include "nvim/vim.h"

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

/// Creates a new namespace or gets an existing one. \*namespace\*
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
  handle_T id = map_get(String, handle_T)(&namespace_ids, name);
  if (id > 0) {
    return id;
  }
  id = next_namespace_id++;
  if (name.size > 0) {
    String name_alloc = copy_string(name, NULL);
    map_put(String, handle_T)(&namespace_ids, name_alloc, id);
  }
  return (Integer)id;
}

/// Gets existing, non-anonymous |namespace|s.
///
/// @return dict that maps from names to namespace ids.
Dictionary nvim_get_namespaces(void)
  FUNC_API_SINCE(5)
{
  Dictionary retval = ARRAY_DICT_INIT;
  String name;
  handle_T id;

  map_foreach(handle_T, &namespace_ids, name, id, {
    PUT(retval, name.data, INTEGER_OBJ(id));
  })

  return retval;
}

const char *describe_ns(NS ns_id)
{
  String name;
  handle_T id;
  map_foreach(handle_T, &namespace_ids, name, id, {
    if ((NS)id == ns_id && name.size) {
      return name.data;
    }
  })
  return "(UNKNOWN PLUGIN)";
}

// Is the Namespace in use?
bool ns_initialized(uint32_t ns)
{
  if (ns < 1) {
    return false;
  }
  return ns < (uint32_t)next_namespace_id;
}

static Object hl_group_name(int hl_id, bool hl_name)
{
  if (hl_name) {
    return CSTR_TO_OBJ(syn_id2name(hl_id));
  } else {
    return INTEGER_OBJ(hl_id);
  }
}

static Array extmark_to_array(const ExtmarkInfo *extmark, bool id, bool add_dict, bool hl_name)
{
  Array rv = ARRAY_DICT_INIT;
  if (id) {
    ADD(rv, INTEGER_OBJ((Integer)extmark->mark_id));
  }
  ADD(rv, INTEGER_OBJ(extmark->row));
  ADD(rv, INTEGER_OBJ(extmark->col));

  if (add_dict) {
    Dictionary dict = ARRAY_DICT_INIT;

    PUT(dict, "ns_id", INTEGER_OBJ((Integer)extmark->ns_id));

    PUT(dict, "right_gravity", BOOLEAN_OBJ(extmark->right_gravity));

    if (extmark->end_row >= 0) {
      PUT(dict, "end_row", INTEGER_OBJ(extmark->end_row));
      PUT(dict, "end_col", INTEGER_OBJ(extmark->end_col));
      PUT(dict, "end_right_gravity", BOOLEAN_OBJ(extmark->end_right_gravity));
    }

    const Decoration *decor = &extmark->decor;
    if (decor->hl_id) {
      PUT(dict, "hl_group", hl_group_name(decor->hl_id, hl_name));
      PUT(dict, "hl_eol", BOOLEAN_OBJ(decor->hl_eol));
    }
    if (decor->hl_mode) {
      PUT(dict, "hl_mode", CSTR_TO_OBJ(hl_mode_str[decor->hl_mode]));
    }

    if (kv_size(decor->virt_text)) {
      Array chunks = ARRAY_DICT_INIT;
      for (size_t i = 0; i < decor->virt_text.size; i++) {
        Array chunk = ARRAY_DICT_INIT;
        VirtTextChunk *vtc = &decor->virt_text.items[i];
        ADD(chunk, CSTR_TO_OBJ(vtc->text));
        if (vtc->hl_id > 0) {
          ADD(chunk, hl_group_name(vtc->hl_id, hl_name));
        }
        ADD(chunks, ARRAY_OBJ(chunk));
      }
      PUT(dict, "virt_text", ARRAY_OBJ(chunks));
      PUT(dict, "virt_text_hide", BOOLEAN_OBJ(decor->virt_text_hide));
      if (decor->virt_text_pos == kVTWinCol) {
        PUT(dict, "virt_text_win_col", INTEGER_OBJ(decor->col));
      }
      PUT(dict, "virt_text_pos",
          CSTR_TO_OBJ(virt_text_pos_str[decor->virt_text_pos]));
    }

    if (decor->ui_watched) {
      PUT(dict, "ui_watched", BOOLEAN_OBJ(true));
    }

    if (kv_size(decor->virt_lines)) {
      Array all_chunks = ARRAY_DICT_INIT;
      bool virt_lines_leftcol = false;
      for (size_t i = 0; i < decor->virt_lines.size; i++) {
        Array chunks = ARRAY_DICT_INIT;
        VirtText *vt = &decor->virt_lines.items[i].line;
        virt_lines_leftcol = decor->virt_lines.items[i].left_col;
        for (size_t j = 0; j < vt->size; j++) {
          Array chunk = ARRAY_DICT_INIT;
          VirtTextChunk *vtc = &vt->items[j];
          ADD(chunk, CSTR_TO_OBJ(vtc->text));
          if (vtc->hl_id > 0) {
            ADD(chunk, hl_group_name(vtc->hl_id, hl_name));
          }
          ADD(chunks, ARRAY_OBJ(chunk));
        }
        ADD(all_chunks, ARRAY_OBJ(chunks));
      }
      PUT(dict, "virt_lines", ARRAY_OBJ(all_chunks));
      PUT(dict, "virt_lines_above", BOOLEAN_OBJ(decor->virt_lines_above));
      PUT(dict, "virt_lines_leftcol", BOOLEAN_OBJ(virt_lines_leftcol));
    }

    if (decor->sign_text) {
      PUT(dict, "sign_text", CSTR_TO_OBJ(decor->sign_text));
    }

    // uncrustify:off

    struct { char *name; const int val; } hls[] = {
      { "sign_hl_group"      , decor->sign_hl_id       },
      { "number_hl_group"    , decor->number_hl_id     },
      { "line_hl_group"      , decor->line_hl_id       },
      { "cursorline_hl_group", decor->cursorline_hl_id },
      { NULL, 0 },
    };

    // uncrustify:on

    for (int j = 0; hls[j].name; j++) {
      if (hls[j].val) {
        PUT(dict, hls[j].name, hl_group_name(hls[j].val, hl_name));
      }
    }

    if (decor->sign_text
        || decor->hl_id
        || kv_size(decor->virt_text)
        || decor->ui_watched) {
      PUT(dict, "priority", INTEGER_OBJ(decor->priority));
    }

    if (decor->conceal) {
      String name = cstr_to_string((char *)&decor->conceal_char);
      PUT(dict, "conceal", STRING_OBJ(name));
    }

    if (decor->spell != kNone) {
      PUT(dict, "spell", BOOLEAN_OBJ(decor->spell == kTrue));
    }

    if (dict.size) {
      ADD(rv, DICTIONARY_OBJ(dict));
    }
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
                                            Integer id, Dictionary opts,
                                            Error *err)
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

  bool details = false;
  bool hl_name = true;
  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("details", k.data)) {
      details = api_object_to_bool(*v, "details", false, err);
      if (ERROR_SET(err)) {
        return rv;
      }
    } else if (strequal("hl_name", k.data)) {
      hl_name = api_object_to_bool(*v, "hl_name", false, err);
      if (ERROR_SET(err)) {
        return rv;
      }
    } else {
      VALIDATE_S(false, "'opts' key", k.data, {
        return rv;
      });
    }
  }

  ExtmarkInfo extmark = extmark_from_id(buf, (uint32_t)ns_id, (uint32_t)id);
  if (extmark.row < 0) {
    return rv;
  }
  return extmark_to_array(&extmark, false, details, hl_name);
}

/// Gets |extmarks| in "traversal order" from a |charwise| region defined by
/// buffer positions (inclusive, 0-indexed |api-indexing|).
///
/// Region can be given as (row,col) tuples, or valid extmark ids (whose
/// positions define the bounds). 0 and -1 are understood as (0,0) and (-1,-1)
/// respectively, thus the following are equivalent:
/// <pre>lua
///   vim.api.nvim_buf_get_extmarks(0, my_ns, 0, -1, {})
///   vim.api.nvim_buf_get_extmarks(0, my_ns, {0,0}, {-1,-1}, {})
/// </pre>
///
/// If `end` is less than `start`, traversal works backwards. (Useful
/// with `limit`, to get the first marks prior to a given position.)
///
/// Example:
/// <pre>lua
///   local api = vim.api
///   local pos = api.nvim_win_get_cursor(0)
///   local ns  = api.nvim_create_namespace('my-plugin')
///   -- Create new extmark at line 1, column 1.
///   local m1  = api.nvim_buf_set_extmark(0, ns, 0, 0, {})
///   -- Create new extmark at line 3, column 1.
///   local m2  = api.nvim_buf_set_extmark(0, ns, 2, 0, {})
///   -- Get extmarks only from line 3.
///   local ms  = api.nvim_buf_get_extmarks(0, ns, {2,0}, {2,0}, {})
///   -- Get all marks in this buffer + namespace.
///   local all = api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
///   vim.print(ms)
/// </pre>
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
///          - type: Filter marks by type: "highlight", "sign", "virt_text" and "virt_lines"
/// @param[out] err   Error details, if any
/// @return List of [extmark_id, row, col] tuples in "traversal order".
Array nvim_buf_get_extmarks(Buffer buffer, Integer ns_id, Object start, Object end, Dictionary opts,
                            Error *err)
  FUNC_API_SINCE(7)
{
  Array rv = ARRAY_DICT_INIT;

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return rv;
  }

  bool all_ns;
  if (ns_id == -1) {
    all_ns = true;
  } else {
    VALIDATE_INT(ns_initialized((uint32_t)ns_id), "ns_id", ns_id, {
      return rv;
    });
    all_ns = false;
  }

  Integer limit = -1;
  bool details = false;
  bool hl_name = true;
  ExtmarkType type = kExtmarkNone;

  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("limit", k.data)) {
      VALIDATE_T("limit", kObjectTypeInteger, v->type, {
        return rv;
      });
      limit = v->data.integer;
    } else if (strequal("details", k.data)) {
      details = api_object_to_bool(*v, "details", false, err);
      if (ERROR_SET(err)) {
        return rv;
      }
    } else if (strequal("hl_name", k.data)) {
      hl_name = api_object_to_bool(*v, "hl_name", false, err);
      if (ERROR_SET(err)) {
        return rv;
      }
    } else if (strequal("type", k.data)) {
      VALIDATE_EXP(v->type == kObjectTypeString, "type", "String", api_typename(v->type), {
        return rv;
      });
      if (strequal(v->data.string.data, "sign")) {
        type = kExtmarkSign;
      } else if (strequal(v->data.string.data, "virt_text")) {
        type = kExtmarkVirtText;
      } else if (strequal(v->data.string.data, "virt_lines")) {
        type = kExtmarkVirtLines;
      } else if (strequal(v->data.string.data, "highlight")) {
        type = kExtmarkHighlight;
      } else {
        VALIDATE_EXP(false, "type", "sign, virt_text, virt_lines or highlight", v->data.string.data, {
          return rv;
        });
      }
    } else {
      VALIDATE_S(false, "'opts' key", k.data, {
        return rv;
      });
    }
  }

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

  ExtmarkInfoArray marks = extmark_get(buf, (uint32_t)ns_id, l_row, l_col, u_row,
                                       u_col, (int64_t)limit, reverse, all_ns, type);

  for (size_t i = 0; i < kv_size(marks); i++) {
    ADD(rv, ARRAY_OBJ(extmark_to_array(&kv_A(marks, i), true, (bool)details, hl_name)));
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
///                   A list of [text, highlight] tuples, each representing a
///                   text chunk with specified highlight. `highlight` element
///                   can either be a single highlight group, or an array of
///                   multiple highlight groups that will be stacked
///                   (highest priority last). A highlight group can be supplied
///                   either as a string or as an integer, the latter which
///                   can be obtained using |nvim_get_hl_id_by_name()|.
///               - virt_text_pos : position of virtual text. Possible values:
///                 - "eol": right after eol character (default)
///                 - "overlay": display over the specified column, without
///                              shifting the underlying text.
///                 - "right_align": display right aligned in the window.
///                 - "inline": display at the specified column, and
///                             shift the buffer text to the right as needed
///               - virt_text_win_col : position the virtual text at a fixed
///                                     window column (starting from the first
///                                     text column)
///               - virt_text_hide : hide the virtual text when the background
///                                  text is selected or hidden because of
///                                  scrolling with 'nowrap' or 'smoothscroll'.
///                                  Currently only affects "overlay" virt_text.
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
///                   turn is an array over [text, highlight] tuples. In
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
///               - priority: a priority value for the highlight group or sign
///                   attribute. For example treesitter highlighting uses a
///                   value of 100.
///               - strict: boolean that indicates extmark should not be placed
///                   if the line or column value is past the end of the
///                   buffer or end of the line respectively. Defaults to true.
///               - sign_text: string of length 1-2 used to display in the
///                   sign column.
///                   Note: ranges are unsupported and decorations are only
///                   applied to start_row
///               - sign_hl_group: name of the highlight group used to
///                   highlight the sign column text.
///                   Note: ranges are unsupported and decorations are only
///                   applied to start_row
///               - number_hl_group: name of the highlight group used to
///                   highlight the number column.
///                   Note: ranges are unsupported and decorations are only
///                   applied to start_row
///               - line_hl_group: name of the highlight group used to
///                   highlight the whole line.
///                   Note: ranges are unsupported and decorations are only
///                   applied to start_row
///               - cursorline_hl_group: name of the highlight group used to
///                   highlight the line when the cursor is on the same line
///                   as the mark and 'cursorline' is enabled.
///                   Note: ranges are unsupported and decorations are only
///                   applied to start_row
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
///
/// @param[out]  err   Error details, if any
/// @return Id of the created/updated extmark
Integer nvim_buf_set_extmark(Buffer buffer, Integer ns_id, Integer line, Integer col,
                             Dict(set_extmark) *opts, Error *err)
  FUNC_API_SINCE(7)
{
  Decoration decor = DECORATION_INIT;
  bool has_decor = false;

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    goto error;
  }

  VALIDATE_INT(ns_initialized((uint32_t)ns_id), "ns_id", ns_id, {
    goto error;
  });

  uint32_t id = 0;
  if (HAS_KEY(opts->id)) {
    VALIDATE_EXP((opts->id.type == kObjectTypeInteger && opts->id.data.integer > 0),
                 "id", "positive Integer", NULL, {
      goto error;
    });

    id = (uint32_t)opts->id.data.integer;
  }

  int line2 = -1;

  // For backward compatibility we support "end_line" as an alias for "end_row"
  if (HAS_KEY(opts->end_line)) {
    VALIDATE(!HAS_KEY(opts->end_row), "%s", "cannot use both 'end_row' and 'end_line'", {
      goto error;
    });
    opts->end_row = opts->end_line;
  }

#define OPTION_TO_BOOL(target, name, val) \
  target = api_object_to_bool(opts->name, #name, val, err); \
  if (ERROR_SET(err)) { \
    goto error; \
  }

  bool strict = true;
  OPTION_TO_BOOL(strict, strict, true);

  if (HAS_KEY(opts->end_row)) {
    VALIDATE_T("end_row", kObjectTypeInteger, opts->end_row.type, {
      goto error;
    });

    Integer val = opts->end_row.data.integer;
    VALIDATE_RANGE((val >= 0 && !(val > buf->b_ml.ml_line_count && strict)), "end_row", {
      goto error;
    });
    line2 = (int)val;
  }

  colnr_T col2 = -1;
  if (HAS_KEY(opts->end_col)) {
    VALIDATE_T("end_col", kObjectTypeInteger, opts->end_col.type, {
      goto error;
    });

    Integer val = opts->end_col.data.integer;
    VALIDATE_RANGE((val >= 0 && val <= MAXCOL), "end_col", {
      goto error;
    });
    col2 = (int)val;
  }

  // uncrustify:off

  struct {
    const char *name;
    Object *opt;
    int *dest;
  } hls[] = {
    { "hl_group"           , &opts->hl_group           , &decor.hl_id            },
    { "sign_hl_group"      , &opts->sign_hl_group      , &decor.sign_hl_id       },
    { "number_hl_group"    , &opts->number_hl_group    , &decor.number_hl_id     },
    { "line_hl_group"      , &opts->line_hl_group      , &decor.line_hl_id       },
    { "cursorline_hl_group", &opts->cursorline_hl_group, &decor.cursorline_hl_id },
    { NULL, NULL, NULL },
  };

  // uncrustify:on

  for (int j = 0; hls[j].name && hls[j].dest; j++) {
    if (HAS_KEY(*hls[j].opt)) {
      *hls[j].dest = object_to_hl_id(*hls[j].opt, hls[j].name, err);
      if (ERROR_SET(err)) {
        goto error;
      }
      has_decor = true;
    }
  }

  if (HAS_KEY(opts->conceal)) {
    VALIDATE_T("conceal", kObjectTypeString, opts->conceal.type, {
      goto error;
    });

    String c = opts->conceal.data.string;
    decor.conceal = true;
    if (c.size) {
      decor.conceal_char = utf_ptr2char(c.data);
    }
    has_decor = true;
  }

  if (HAS_KEY(opts->virt_text)) {
    VALIDATE_T("virt_text", kObjectTypeArray, opts->virt_text.type, {
      goto error;
    });

    decor.virt_text = parse_virt_text(opts->virt_text.data.array, err,
                                      &decor.virt_text_width);
    has_decor = true;
    if (ERROR_SET(err)) {
      goto error;
    }
  }

  if (HAS_KEY(opts->virt_text_pos)) {
    VALIDATE_T("virt_text_pos", kObjectTypeString, opts->virt_text_pos.type, {
      goto error;
    });

    String str = opts->virt_text_pos.data.string;
    if (strequal("eol", str.data)) {
      decor.virt_text_pos = kVTEndOfLine;
    } else if (strequal("overlay", str.data)) {
      decor.virt_text_pos = kVTOverlay;
    } else if (strequal("right_align", str.data)) {
      decor.virt_text_pos = kVTRightAlign;
    } else if (strequal("inline", str.data)) {
      decor.virt_text_pos = kVTInline;
    } else {
      VALIDATE_S(false, "virt_text_pos", str.data, {
        goto error;
      });
    }
  }

  if (HAS_KEY(opts->virt_text_win_col)) {
    VALIDATE_T("virt_text_win_col", kObjectTypeInteger, opts->virt_text_win_col.type, {
      goto error;
    });

    decor.col = (int)opts->virt_text_win_col.data.integer;
    decor.virt_text_pos = kVTWinCol;
  }

  OPTION_TO_BOOL(decor.virt_text_hide, virt_text_hide, false);
  OPTION_TO_BOOL(decor.hl_eol, hl_eol, false);

  if (HAS_KEY(opts->hl_mode)) {
    VALIDATE_T("hl_mode", kObjectTypeString, opts->hl_mode.type, {
      goto error;
    });

    String str = opts->hl_mode.data.string;
    if (strequal("replace", str.data)) {
      decor.hl_mode = kHlModeReplace;
    } else if (strequal("combine", str.data)) {
      decor.hl_mode = kHlModeCombine;
    } else if (strequal("blend", str.data)) {
      if (decor.virt_text_pos == kVTInline) {
        VALIDATE(false, "%s", "cannot use 'blend' hl_mode with inline virtual text", {
          goto error;
        });
      }
      decor.hl_mode = kHlModeBlend;
    } else {
      VALIDATE_S(false, "hl_mode", str.data, {
        goto error;
      });
    }
  }

  bool virt_lines_leftcol = false;
  OPTION_TO_BOOL(virt_lines_leftcol, virt_lines_leftcol, false);

  if (HAS_KEY(opts->virt_lines)) {
    VALIDATE_T("virt_lines", kObjectTypeArray, opts->virt_lines.type, {
      goto error;
    });

    Array a = opts->virt_lines.data.array;
    for (size_t j = 0; j < a.size; j++) {
      VALIDATE_T("virt_text_line", kObjectTypeArray, a.items[j].type, {
        goto error;
      });
      int dummig;
      VirtText jtem = parse_virt_text(a.items[j].data.array, err, &dummig);
      kv_push(decor.virt_lines, ((struct virt_line){ jtem, virt_lines_leftcol }));
      if (ERROR_SET(err)) {
        goto error;
      }
      has_decor = true;
    }
  }

  OPTION_TO_BOOL(decor.virt_lines_above, virt_lines_above, false);

  if (HAS_KEY(opts->priority)) {
    VALIDATE_T("priority", kObjectTypeInteger, opts->priority.type, {
      goto error;
    });

    Integer val = opts->priority.data.integer;

    VALIDATE_RANGE((val >= 0 && val <= UINT16_MAX), "priority", {
      goto error;
    });
    decor.priority = (DecorPriority)val;
  }

  if (HAS_KEY(opts->sign_text)) {
    VALIDATE_T("sign_text", kObjectTypeString, opts->sign_text.type, {
      goto error;
    });

    VALIDATE_S(init_sign_text(&decor.sign_text, opts->sign_text.data.string.data),
               "sign_text", "", {
      goto error;
    });
    has_decor = true;
  }

  bool right_gravity = true;
  OPTION_TO_BOOL(right_gravity, right_gravity, true);

  // Only error out if they try to set end_right_gravity without
  // setting end_col or end_row
  VALIDATE(!(line2 == -1 && col2 == -1 && HAS_KEY(opts->end_right_gravity)),
           "%s", "cannot set end_right_gravity without end_row or end_col", {
    goto error;
  });

  bool end_right_gravity = false;
  OPTION_TO_BOOL(end_right_gravity, end_right_gravity, false);

  size_t len = 0;

  bool ephemeral = false;
  OPTION_TO_BOOL(ephemeral, ephemeral, false);

  if (!HAS_KEY(opts->spell)) {
    decor.spell = kNone;
  } else {
    bool spell = false;
    OPTION_TO_BOOL(spell, spell, false);
    decor.spell = spell ? kTrue : kFalse;
    has_decor = true;
  }

  OPTION_TO_BOOL(decor.ui_watched, ui_watched, false);
  if (decor.ui_watched) {
    has_decor = true;
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
    len = ephemeral ? MAXCOL : strlen(ml_get_buf(buf, (linenr_T)line + 1, false));
  }

  if (col == -1) {
    col = (Integer)len;
  } else if (col > (Integer)len) {
    VALIDATE_RANGE(!strict, "col", {
      goto error;
    });
    col = (Integer)len;
  } else if (col < -1) {
    VALIDATE_RANGE(false, "col", {
      goto error;
    });
  }

  if (col2 >= 0) {
    if (line2 >= 0 && line2 < buf->b_ml.ml_line_count) {
      len = ephemeral ? MAXCOL : strlen(ml_get_buf(buf, (linenr_T)line2 + 1, false));
    } else if (line2 == buf->b_ml.ml_line_count) {
      // We are trying to add an extmark past final newline
      len = 0;
    } else {
      // reuse len from before
      line2 = (int)line;
    }
    if (col2 > (Integer)len) {
      VALIDATE_RANGE(!strict, "end_col", {
        goto error;
      });
      col2 = (int)len;
    }
  } else if (line2 >= 0) {
    col2 = 0;
  }

  // TODO(bfredl): synergize these two branches even more
  if (ephemeral && decor_state.win && decor_state.win->w_buffer == buf) {
    decor_add_ephemeral((int)line, (int)col, line2, col2, &decor, (uint64_t)ns_id, id);
  } else {
    if (ephemeral) {
      api_set_error(err, kErrorTypeException, "not yet implemented");
      goto error;
    }

    extmark_set(buf, (uint32_t)ns_id, &id, (int)line, (colnr_T)col, line2, col2,
                has_decor ? &decor : NULL, right_gravity, end_right_gravity,
                kExtmarkNoUndo, err);
    if (ERROR_SET(err)) {
      goto error;
    }
  }

  return (Integer)id;

error:
  decor_clear(&decor);
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

  if (decor_state.running_on_lines) {
    api_set_error(err, kErrorTypeValidation, "Cannot remove extmarks during on_line callbacks");
    return false;
  }

  return extmark_del(buf, (uint32_t)ns_id, (uint32_t)id);
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

  Decoration decor = DECORATION_INIT;
  decor.hl_id = hl_id;

  extmark_set(buf, ns, NULL,
              (int)line, (colnr_T)col_start,
              end_line, (colnr_T)col_end,
              &decor, true, false, kExtmarkNoUndo, NULL);
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

  if (decor_state.running_on_lines) {
    api_set_error(err, kErrorTypeValidation, "Cannot remove extmarks during on_line callbacks");
    return;
  }

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
///                 ["start", tick]
///             - on_buf: called for each buffer being redrawn (before
///                 window callbacks)
///                 ["buf", bufnr, tick]
///             - on_win: called when starting to redraw a
///                 specific window.
///                 ["win", winid, bufnr, topline, botline_guess]
///             - on_line: called for each buffer line being redrawn.
///                 (The interaction with fold lines is subject to change)
///                 ["win", winid, bufnr, row]
///             - on_end: called at the end of a redraw cycle
///                 ["end", tick]
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
    Object *source;
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
    Object *v = cbs[i].source;
    if (v->type == kObjectTypeNil) {
      continue;
    }

    VALIDATE_T(cbs[i].name, kObjectTypeLuaRef, v->type, {
      goto error;
    });

    *(cbs[i].dest) = v->data.luaref;
    v->data.luaref = LUA_NOREF;
  }

  p->active = true;
  p->hl_valid++;
  p->hl_cached = false;
  return;
error:
  decor_provider_clear(p);
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

    ExtmarkInfo extmark = extmark_from_id(buf, (uint32_t)ns_id, (uint32_t)id);

    VALIDATE_INT((extmark.row >= 0), "mark id (not found)", id, {
      return false;
    });
    *row = extmark.row;
    *col = extmark.col;
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
// adapted from sign.c:sign_define_init_text.
// TODO(lewis6991): Consider merging
static int init_sign_text(char **sign_text, char *text)
{
  char *s;

  char *endp = text + (int)strlen(text);

  // Count cells and check for non-printable chars
  int cells = 0;
  for (s = text; s < endp; s += utfc_ptr2len(s)) {
    if (!vim_isprintc(utf_ptr2char(s))) {
      break;
    }
    cells += utf_ptr2cells(s);
  }
  // Currently must be empty, one or two display cells
  if (s != endp || cells > 2) {
    return FAIL;
  }
  if (cells < 1) {
    return OK;
  }

  // Allocate one byte more if we need to pad up
  // with a space.
  size_t len = (size_t)(endp - text + ((cells == 1) ? 1 : 0));
  *sign_text = xstrnsave(text, len);

  if (cells == 1) {
    STRCPY(*sign_text + len - 1, " ");
  }

  return OK;
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
            kv_push(virt_text, ((VirtTextChunk){ .text = NULL,
                                                 .hl_id = hl_id }));
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

  *width = w;
  return virt_text;

free_exit:
  clear_virttext(&virt_text);
  return virt_text;
}
