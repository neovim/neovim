// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/decoration_provider.h"
#include "nvim/extmark.h"
#include "nvim/highlight_group.h"
#include "nvim/lua/executor.h"
#include "nvim/memline.h"
#include "nvim/screen.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/extmark.c.generated.h"
#endif

void api_extmark_free_all_mem(void)
{
  String name;
  handle_T id;
  map_foreach(&namespace_ids, name, id, {
    (void)id;
    xfree(name.data);
  })
  map_destroy(String, handle_T)(&namespace_ids);
}

/// Creates a new \*namespace\* or gets an existing one.
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
    String name_alloc = copy_string(name);
    map_put(String, handle_T)(&namespace_ids, name_alloc, id);
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

  map_foreach(&namespace_ids, name, id, {
    PUT(retval, name.data, INTEGER_OBJ(id));
  })

  return retval;
}

const char *describe_ns(NS ns_id)
{
  String name;
  handle_T id;
  map_foreach(&namespace_ids, name, id, {
    if ((NS)id == ns_id && name.size) {
      return name.data;
    }
  })
  return "(UNKNOWN PLUGIN)";
}

// Is the Namespace in use?
static bool ns_initialized(uint32_t ns)
{
  if (ns < 1) {
    return false;
  }
  return ns < (uint32_t)next_namespace_id;
}

static Array extmark_to_array(const ExtmarkInfo *extmark, bool id, bool add_dict)
{
  Array rv = ARRAY_DICT_INIT;
  if (id) {
    ADD(rv, INTEGER_OBJ((Integer)extmark->mark_id));
  }
  ADD(rv, INTEGER_OBJ(extmark->row));
  ADD(rv, INTEGER_OBJ(extmark->col));

  if (add_dict) {
    Dictionary dict = ARRAY_DICT_INIT;

    PUT(dict, "right_gravity", BOOLEAN_OBJ(extmark->right_gravity));

    if (extmark->end_row >= 0) {
      PUT(dict, "end_row", INTEGER_OBJ(extmark->end_row));
      PUT(dict, "end_col", INTEGER_OBJ(extmark->end_col));
      PUT(dict, "end_right_gravity", BOOLEAN_OBJ(extmark->end_right_gravity));
    }

    const Decoration *decor = &extmark->decor;
    if (decor->hl_id) {
      String name = cstr_to_string((const char *)syn_id2name(decor->hl_id));
      PUT(dict, "hl_group", STRING_OBJ(name));
      PUT(dict, "hl_eol", BOOLEAN_OBJ(decor->hl_eol));
    }
    if (decor->hl_mode) {
      PUT(dict, "hl_mode", STRING_OBJ(cstr_to_string(hl_mode_str[decor->hl_mode])));
    }

    if (kv_size(decor->virt_text)) {
      Array chunks = ARRAY_DICT_INIT;
      for (size_t i = 0; i < decor->virt_text.size; i++) {
        Array chunk = ARRAY_DICT_INIT;
        VirtTextChunk *vtc = &decor->virt_text.items[i];
        ADD(chunk, STRING_OBJ(cstr_to_string(vtc->text)));
        if (vtc->hl_id > 0) {
          ADD(chunk,
              STRING_OBJ(cstr_to_string((const char *)syn_id2name(vtc->hl_id))));
        }
        ADD(chunks, ARRAY_OBJ(chunk));
      }
      PUT(dict, "virt_text", ARRAY_OBJ(chunks));
      PUT(dict, "virt_text_hide", BOOLEAN_OBJ(decor->virt_text_hide));
      if (decor->virt_text_pos == kVTWinCol) {
        PUT(dict, "virt_text_win_col", INTEGER_OBJ(decor->col));
      }
      PUT(dict, "virt_text_pos",
          STRING_OBJ(cstr_to_string(virt_text_pos_str[decor->virt_text_pos])));
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
          ADD(chunk, STRING_OBJ(cstr_to_string(vtc->text)));
          if (vtc->hl_id > 0) {
            ADD(chunk,
                STRING_OBJ(cstr_to_string((const char *)syn_id2name(vtc->hl_id))));
          }
          ADD(chunks, ARRAY_OBJ(chunk));
        }
        ADD(all_chunks, ARRAY_OBJ(chunks));
      }
      PUT(dict, "virt_lines", ARRAY_OBJ(all_chunks));
      PUT(dict, "virt_lines_above", BOOLEAN_OBJ(decor->virt_lines_above));
      PUT(dict, "virt_lines_leftcol", BOOLEAN_OBJ(virt_lines_leftcol));
    }

    if (decor->hl_id || kv_size(decor->virt_text) || decor->ui_watched) {
      PUT(dict, "priority", INTEGER_OBJ(decor->priority));
    }

    if (dict.size) {
      ADD(rv, DICTIONARY_OBJ(dict));
    }
  }

  return rv;
}

/// Gets the position (0-indexed) of an extmark.
///
/// @param buffer  Buffer handle, or 0 for current buffer
/// @param ns_id  Namespace id from |nvim_create_namespace()|
/// @param id  Extmark id
/// @param opts  Optional parameters. Keys:
///          - details: Whether to include the details dict
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

  if (!ns_initialized((uint32_t)ns_id)) {
    api_set_error(err, kErrorTypeValidation, "Invalid ns_id");
    return rv;
  }

  bool details = false;
  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("details", k.data)) {
      if (v->type == kObjectTypeBoolean) {
        details = v->data.boolean;
      } else if (v->type == kObjectTypeInteger) {
        details = v->data.integer;
      } else {
        api_set_error(err, kErrorTypeValidation, "details is not an boolean");
        return rv;
      }
    } else {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      return rv;
    }
  }

  ExtmarkInfo extmark = extmark_from_id(buf, (uint32_t)ns_id, (uint32_t)id);
  if (extmark.row < 0) {
    return rv;
  }
  return extmark_to_array(&extmark, false, details);
}

/// Gets extmarks in "traversal order" from a |charwise| region defined by
/// buffer positions (inclusive, 0-indexed |api-indexing|).
///
/// Region can be given as (row,col) tuples, or valid extmark ids (whose
/// positions define the bounds). 0 and -1 are understood as (0,0) and (-1,-1)
/// respectively, thus the following are equivalent:
///
/// <pre>
///   nvim_buf_get_extmarks(0, my_ns, 0, -1, {})
///   nvim_buf_get_extmarks(0, my_ns, [0,0], [-1,-1], {})
/// </pre>
///
/// If `end` is less than `start`, traversal works backwards. (Useful
/// with `limit`, to get the first marks prior to a given position.)
///
/// Example:
///
/// <pre>
///   local a   = vim.api
///   local pos = a.nvim_win_get_cursor(0)
///   local ns  = a.nvim_create_namespace('my-plugin')
///   -- Create new extmark at line 1, column 1.
///   local m1  = a.nvim_buf_set_extmark(0, ns, 0, 0, {})
///   -- Create new extmark at line 3, column 1.
///   local m2  = a.nvim_buf_set_extmark(0, ns, 0, 2, {})
///   -- Get extmarks only from line 3.
///   local ms  = a.nvim_buf_get_extmarks(0, ns, {2,0}, {2,0}, {})
///   -- Get all marks in this buffer + namespace.
///   local all = a.nvim_buf_get_extmarks(0, ns, 0, -1, {})
///   print(vim.inspect(ms))
/// </pre>
///
/// @param buffer  Buffer handle, or 0 for current buffer
/// @param ns_id  Namespace id from |nvim_create_namespace()|
/// @param start  Start of range: a 0-indexed (row, col) or valid extmark id
/// (whose position defines the bound). |api-indexing|
/// @param end  End of range (inclusive): a 0-indexed (row, col) or valid
/// extmark id (whose position defines the bound). |api-indexing|
/// @param opts  Optional parameters. Keys:
///          - limit:  Maximum number of marks to return
///          - details Whether to include the details dict
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

  if (!ns_initialized((uint32_t)ns_id)) {
    api_set_error(err, kErrorTypeValidation, "Invalid ns_id");
    return rv;
  }

  Integer limit = -1;
  bool details = false;

  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("limit", k.data)) {
      if (v->type != kObjectTypeInteger) {
        api_set_error(err, kErrorTypeValidation, "limit is not an integer");
        return rv;
      }
      limit = v->data.integer;
    } else if (strequal("details", k.data)) {
      if (v->type == kObjectTypeBoolean) {
        details = v->data.boolean;
      } else if (v->type == kObjectTypeInteger) {
        details = v->data.integer;
      } else {
        api_set_error(err, kErrorTypeValidation, "details is not an boolean");
        return rv;
      }
    } else {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      return rv;
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

  ExtmarkInfoArray marks = extmark_get(buf, (uint32_t)ns_id, l_row, l_col,
                                       u_row, u_col, (int64_t)limit, reverse);

  for (size_t i = 0; i < kv_size(marks); i++) {
    ADD(rv, ARRAY_OBJ(extmark_to_array(&kv_A(marks, i), true, (bool)details)));
  }

  kv_destroy(marks);
  return rv;
}

/// Creates or updates an extmark.
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
///                   can either be a a single highlight group, or an array of
///                   multiple highlight groups that will be stacked
///                   (highest priority last). A highlight group can be supplied
///                   either as a string or as an integer, the latter which
///                   can be obtained using |nvim_get_hl_id_by_name|.
///               - virt_text_pos : position of virtual text. Possible values:
///                 - "eol": right after eol character (default)
///                 - "overlay": display over the specified column, without
///                              shifting the underlying text.
///                 - "right_align": display right aligned in the window.
///               - virt_text_win_col : position the virtual text at a fixed
///                                     window column (starting from the first
///                                     text column)
///               - virt_text_hide : hide the virtual text when the background
///                                  text is selected or hidden due to
///                                  horizontal scroll 'nowrap'
///               - hl_mode : control how highlights are combined with the
///                           highlights of the text. Currently only affects
///                           virt_text highlights, but might affect `hl_group`
///                           in later versions.
///                 - "replace": only show the virt_text color. This is the
///                              default
///                 - "combine": combine with background text color
///                 - "blend": blend with background text color.
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
///               - ephemeral : for use with |nvim_set_decoration_provider|
///                   callbacks. The mark will only be used for the current
///                   redraw cycle, and not be permantently stored in the
///                   buffer.
///               - right_gravity : boolean that indicates the direction
///                   the extmark will be shifted in when new text is inserted
///                   (true for right, false for left).  defaults to true.
///               - end_right_gravity : boolean that indicates the direction
///                   the extmark end position (if it exists) will be shifted
///                   in when new text is inserted (true for right, false
///                   for left). Defaults to false.
///               - priority: a priority value for the highlight group. For
///                   example treesitter highlighting uses a value of 100.
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

  if (!ns_initialized((uint32_t)ns_id)) {
    api_set_error(err, kErrorTypeValidation, "Invalid ns_id");
    goto error;
  }

  uint32_t id = 0;
  if (opts->id.type == kObjectTypeInteger && opts->id.data.integer > 0) {
    id = (uint32_t)opts->id.data.integer;
  } else if (HAS_KEY(opts->id)) {
    api_set_error(err, kErrorTypeValidation, "id is not a positive integer");
    goto error;
  }

  int line2 = -1;

  // For backward compatibility we support "end_line" as an alias for "end_row"
  if (HAS_KEY(opts->end_line)) {
    if (HAS_KEY(opts->end_row)) {
      api_set_error(err, kErrorTypeValidation, "cannot use both end_row and end_line");
      goto error;
    }
    opts->end_row = opts->end_line;
  }

#define OPTION_TO_BOOL(target, name, val) \
  target = api_object_to_bool(opts->name, #name, val, err); \
  if (ERROR_SET(err)) { \
    goto error; \
  }

  bool strict = true;
  OPTION_TO_BOOL(strict, strict, true);

  if (opts->end_row.type == kObjectTypeInteger) {
    Integer val = opts->end_row.data.integer;
    if (val < 0 || (val > buf->b_ml.ml_line_count && strict)) {
      api_set_error(err, kErrorTypeValidation, "end_row value outside range");
      goto error;
    } else {
      line2 = (int)val;
    }
  } else if (HAS_KEY(opts->end_row)) {
    api_set_error(err, kErrorTypeValidation, "end_row is not an integer");
    goto error;
  }

  colnr_T col2 = -1;
  if (opts->end_col.type == kObjectTypeInteger) {
    Integer val = opts->end_col.data.integer;
    if (val < 0 || val > MAXCOL) {
      api_set_error(err, kErrorTypeValidation, "end_col value outside range");
      goto error;
    } else {
      col2 = (int)val;
    }
  } else if (HAS_KEY(opts->end_col)) {
    api_set_error(err, kErrorTypeValidation, "end_col is not an integer");
    goto error;
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

  if (opts->conceal.type == kObjectTypeString) {
    String c = opts->conceal.data.string;
    decor.conceal = true;
    if (c.size) {
      decor.conceal_char = utf_ptr2char(c.data);
    }
    has_decor = true;
  } else if (HAS_KEY(opts->conceal)) {
    api_set_error(err, kErrorTypeValidation, "conceal is not a String");
    goto error;
  }

  if (opts->virt_text.type == kObjectTypeArray) {
    decor.virt_text = parse_virt_text(opts->virt_text.data.array, err,
                                      &decor.virt_text_width);
    has_decor = true;
    if (ERROR_SET(err)) {
      goto error;
    }
  } else if (HAS_KEY(opts->virt_text)) {
    api_set_error(err, kErrorTypeValidation, "virt_text is not an Array");
    goto error;
  }

  if (opts->virt_text_pos.type == kObjectTypeString) {
    String str = opts->virt_text_pos.data.string;
    if (strequal("eol", str.data)) {
      decor.virt_text_pos = kVTEndOfLine;
    } else if (strequal("overlay", str.data)) {
      decor.virt_text_pos = kVTOverlay;
    } else if (strequal("right_align", str.data)) {
      decor.virt_text_pos = kVTRightAlign;
    } else {
      api_set_error(err, kErrorTypeValidation, "virt_text_pos: invalid value");
      goto error;
    }
  } else if (HAS_KEY(opts->virt_text_pos)) {
    api_set_error(err, kErrorTypeValidation, "virt_text_pos is not a String");
    goto error;
  }

  if (opts->virt_text_win_col.type == kObjectTypeInteger) {
    decor.col = (int)opts->virt_text_win_col.data.integer;
    decor.virt_text_pos = kVTWinCol;
  } else if (HAS_KEY(opts->virt_text_win_col)) {
    api_set_error(err, kErrorTypeValidation,
                  "virt_text_win_col is not a Number of the correct size");
    goto error;
  }

  OPTION_TO_BOOL(decor.virt_text_hide, virt_text_hide, false);
  OPTION_TO_BOOL(decor.hl_eol, hl_eol, false);

  if (opts->hl_mode.type == kObjectTypeString) {
    String str = opts->hl_mode.data.string;
    if (strequal("replace", str.data)) {
      decor.hl_mode = kHlModeReplace;
    } else if (strequal("combine", str.data)) {
      decor.hl_mode = kHlModeCombine;
    } else if (strequal("blend", str.data)) {
      decor.hl_mode = kHlModeBlend;
    } else {
      api_set_error(err, kErrorTypeValidation,
                    "virt_text_pos: invalid value");
      goto error;
    }
  } else if (HAS_KEY(opts->hl_mode)) {
    api_set_error(err, kErrorTypeValidation, "hl_mode is not a String");
    goto error;
  }

  bool virt_lines_leftcol = false;
  OPTION_TO_BOOL(virt_lines_leftcol, virt_lines_leftcol, false);

  if (opts->virt_lines.type == kObjectTypeArray) {
    Array a = opts->virt_lines.data.array;
    for (size_t j = 0; j < a.size; j++) {
      if (a.items[j].type != kObjectTypeArray) {
        api_set_error(err, kErrorTypeValidation, "virt_text_line item is not an Array");
        goto error;
      }
      int dummig;
      VirtText jtem = parse_virt_text(a.items[j].data.array, err, &dummig);
      kv_push(decor.virt_lines, ((struct virt_line){ jtem, virt_lines_leftcol }));
      if (ERROR_SET(err)) {
        goto error;
      }
      has_decor = true;
    }
  } else if (HAS_KEY(opts->virt_lines)) {
    api_set_error(err, kErrorTypeValidation, "virt_lines is not an Array");
    goto error;
  }

  OPTION_TO_BOOL(decor.virt_lines_above, virt_lines_above, false);

  if (opts->priority.type == kObjectTypeInteger) {
    Integer val = opts->priority.data.integer;

    if (val < 0 || val > UINT16_MAX) {
      api_set_error(err, kErrorTypeValidation, "priority is not a valid value");
      goto error;
    }
    decor.priority = (DecorPriority)val;
  } else if (HAS_KEY(opts->priority)) {
    api_set_error(err, kErrorTypeValidation, "priority is not a Number of the correct size");
    goto error;
  }

  if (opts->sign_text.type == kObjectTypeString) {
    if (!init_sign_text((char **)&decor.sign_text,
                        opts->sign_text.data.string.data)) {
      api_set_error(err, kErrorTypeValidation, "sign_text is not a valid value");
      goto error;
    }
    has_decor = true;
  } else if (HAS_KEY(opts->sign_text)) {
    api_set_error(err, kErrorTypeValidation, "sign_text is not a String");
    goto error;
  }

  bool right_gravity = true;
  OPTION_TO_BOOL(right_gravity, right_gravity, true);

  // Only error out if they try to set end_right_gravity without
  // setting end_col or end_row
  if (line2 == -1 && col2 == -1 && HAS_KEY(opts->end_right_gravity)) {
    api_set_error(err, kErrorTypeValidation,
                  "cannot set end_right_gravity without setting end_row or end_col");
    goto error;
  }

  bool end_right_gravity = false;
  OPTION_TO_BOOL(end_right_gravity, end_right_gravity, false);

  size_t len = 0;

  bool ephemeral = false;
  OPTION_TO_BOOL(ephemeral, ephemeral, false);

  OPTION_TO_BOOL(decor.ui_watched, ui_watched, false);
  if (decor.ui_watched) {
    has_decor = true;
  }

  if (line < 0) {
    api_set_error(err, kErrorTypeValidation, "line value outside range");
    goto error;
  } else if (line > buf->b_ml.ml_line_count) {
    if (strict) {
      api_set_error(err, kErrorTypeValidation, "line value outside range");
      goto error;
    } else {
      line = buf->b_ml.ml_line_count;
    }
  } else if (line < buf->b_ml.ml_line_count) {
    len = ephemeral ? MAXCOL : STRLEN(ml_get_buf(buf, (linenr_T)line + 1, false));
  }

  if (col == -1) {
    col = (Integer)len;
  } else if (col > (Integer)len) {
    if (strict) {
      api_set_error(err, kErrorTypeValidation, "col value outside range");
      goto error;
    } else {
      col = (Integer)len;
    }
  } else if (col < -1) {
    api_set_error(err, kErrorTypeValidation, "col value outside range");
    goto error;
  }

  if (col2 >= 0) {
    if (line2 >= 0 && line2 < buf->b_ml.ml_line_count) {
      len = ephemeral ? MAXCOL : STRLEN(ml_get_buf(buf, (linenr_T)line2 + 1, false));
    } else if (line2 == buf->b_ml.ml_line_count) {
      // We are trying to add an extmark past final newline
      len = 0;
    } else {
      // reuse len from before
      line2 = (int)line;
    }
    if (col2 > (Integer)len) {
      if (strict) {
        api_set_error(err, kErrorTypeValidation, "end_col value outside range");
        goto error;
      } else {
        col2 = (int)len;
      }
    }
  } else if (line2 >= 0) {
    col2 = 0;
  }

  // TODO(bfredl): synergize these two branches even more
  if (ephemeral && decor_state.buf == buf) {
    decor_add_ephemeral((int)line, (int)col, line2, col2, &decor, (uint64_t)ns_id, id);
  } else {
    if (ephemeral) {
      api_set_error(err, kErrorTypeException, "not yet implemented");
      goto error;
    }

    extmark_set(buf, (uint32_t)ns_id, &id, (int)line, (colnr_T)col, line2, col2,
                has_decor ? &decor : NULL, right_gravity, end_right_gravity,
                kExtmarkNoUndo);
  }

  return (Integer)id;

error:
  clear_virttext(&decor.virt_text);
  xfree(decor.sign_text);
  return 0;
}

/// Removes an extmark.
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
  if (!ns_initialized((uint32_t)ns_id)) {
    api_set_error(err, kErrorTypeValidation, "Invalid ns_id");
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
  } else {
    return (uint32_t)(*src_id);
  }
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

  if (line < 0 || line >= MAXLNUM) {
    api_set_error(err, kErrorTypeValidation, "Line number outside range");
    return 0;
  }
  if (col_start < 0 || col_start > MAXCOL) {
    api_set_error(err, kErrorTypeValidation, "Column value outside range");
    return 0;
  }
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
              &decor, true, false, kExtmarkNoUndo);
  return ns_id;
}

/// Clears namespaced objects (highlights, extmarks, virtual text) from
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

  if (line_start < 0 || line_start >= MAXLNUM) {
    api_set_error(err, kErrorTypeValidation, "Line number outside range");
    return;
  }
  if (line_end < 0 || line_end > MAXLNUM) {
    line_end = MAXLNUM;
  }
  extmark_clear(buf, (ns_id < 0 ? 0 : (uint32_t)ns_id),
                (int)line_start, 0,
                (int)line_end - 1, MAXCOL);
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
///                 interaction with fold lines is subject to change)
///                 ["win", winid, bufnr, row]
///             - on_end: called at the end of a redraw cycle
///                 ["end", tick]
void nvim_set_decoration_provider(Integer ns_id, DictionaryOf(LuaRef) opts, Error *err)
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
