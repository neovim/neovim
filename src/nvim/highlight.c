// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// highlight.c: low level code for UI and syntax highlighting

#include "nvim/vim.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/map.h"
#include "nvim/screen.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "highlight.c.generated.h"
#endif

static bool hlstate_active = false;

static kvec_t(HlEntry) attr_entries = KV_INITIAL_VALUE;

static Map(HlEntry, int) *attr_entry_ids;
static Map(int, int) *combine_attr_entries;

void highlight_init(void)
{
  attr_entry_ids = map_new(HlEntry, int)();
  combine_attr_entries = map_new(int, int)();

  // index 0 is no attribute, add dummy entry:
  kv_push(attr_entries, ((HlEntry){ .attr = HLATTRS_INIT, .kind = kHlUnknown,
                                    .id1 = 0, .id2 = 0 }));
}

/// @return TRUE if hl table was reset
bool highlight_use_hlstate(void)
{
  if (hlstate_active) {
    return false;
  }
  hlstate_active = true;
  // hl tables must now be rebuilt.
  clear_hl_tables(true);
  return true;
}

/// Return the attr number for a set of colors and font, and optionally
/// a semantic description (see ext_hlstate documentation).
/// Add a new entry to the attr_entries array if the combination is new.
/// @return 0 for error.
static int get_attr_entry(HlEntry entry)
{
  if (!hlstate_active) {
    // This information will not be used, erase it and reduce the table size.
    entry.kind = kHlUnknown;
    entry.id1 = 0;
    entry.id2 = 0;
  }

  int id = map_get(HlEntry, int)(attr_entry_ids, entry);
  if (id > 0) {
    return id;
  }

  static bool recursive = false;
  if (kv_size(attr_entries) > MAX_TYPENR) {
    // Running out of attribute entries!  remove all attributes, and
    // compute new ones for all groups.
    // When called recursively, we are really out of numbers.
    if (recursive) {
      EMSG(_("E424: Too many different highlighting attributes in use"));
      return 0;
    }
    recursive = true;

    clear_hl_tables(true);

    recursive = false;
    if (entry.kind == kHlCombine) {
      // This entry is now invalid, don't put it
      return 0;
    }
  }

  id = (int)kv_size(attr_entries);
  kv_push(attr_entries, entry);

  map_put(HlEntry, int)(attr_entry_ids, entry, id);

  Array inspect = hl_inspect(id);

  // Note: internally we don't distinguish between cterm and rgb attributes,
  // remote_ui_hl_attr_define will however.
  ui_call_hl_attr_define(id, entry.attr, entry.attr, inspect);
  api_free_array(inspect);
  return id;
}

/// When a UI connects, we need to send it the table of highlights used so far.
void ui_send_all_hls(UI *ui)
{
  if (!ui->hl_attr_define) {
    return;
  }
  for (size_t i = 1; i < kv_size(attr_entries); i++) {
    Array inspect = hl_inspect((int)i);
    ui->hl_attr_define(ui, (Integer)i, kv_A(attr_entries, i).attr,
                       kv_A(attr_entries, i).attr, inspect);
    api_free_array(inspect);
  }
}

/// Get attribute code for a syntax group.
int hl_get_syn_attr(int idx, HlAttrs at_en)
{
  // TODO(bfredl): should we do this unconditionally
  if (at_en.cterm_fg_color != 0 || at_en.cterm_bg_color != 0
      || at_en.rgb_fg_color != -1 || at_en.rgb_bg_color != -1
      || at_en.rgb_sp_color != -1 || at_en.cterm_ae_attr != 0
      || at_en.rgb_ae_attr != 0) {
    return get_attr_entry((HlEntry){ .attr = at_en, .kind = kHlSyntax,
                                     .id1 = idx, .id2 = 0 });
  } else {
    // If all the fields are cleared, clear the attr field back to default value
    return 0;
  }
}

/// Get attribute code for a builtin highlight group.
///
/// The final syntax group could be modified by hi-link or 'winhighlight'.
int hl_get_ui_attr(int idx, int final_id, bool optional)
{
  HlAttrs attrs = HLATTRS_INIT;
  bool available = false;

  int syn_attr = syn_id2attr(final_id);
  if (syn_attr != 0) {
    attrs = syn_attr2entry(syn_attr);
    available = true;
  }
  if (optional && !available) {
    return 0;
  }
  return get_attr_entry((HlEntry){ .attr = attrs, .kind = kHlUI,
                                   .id1 = idx, .id2 = final_id });
}

void update_window_hl(win_T *wp, bool invalid)
{
  if (!wp->w_hl_needs_update && !invalid) {
    return;
  }
  wp->w_hl_needs_update = false;

  // determine window specific background set in 'winhighlight'
  if (wp != curwin && wp->w_hl_ids[HLF_INACTIVE] > 0) {
    wp->w_hl_attr_normal = hl_get_ui_attr(HLF_INACTIVE,
                                          wp->w_hl_ids[HLF_INACTIVE], true);
  } else if (wp->w_hl_id_normal > 0) {
    wp->w_hl_attr_normal = hl_get_ui_attr(-1, wp->w_hl_id_normal, true);
  } else {
    wp->w_hl_attr_normal = 0;
  }
  if (wp != curwin) {
    wp->w_hl_attr_normal = hl_combine_attr(HL_ATTR(HLF_INACTIVE),
                                           wp->w_hl_attr_normal);
  }

  for (int hlf = 0; hlf < (int)HLF_COUNT; hlf++) {
    int attr;
    if (wp->w_hl_ids[hlf] > 0) {
      attr = hl_get_ui_attr(hlf, wp->w_hl_ids[hlf], false);
    } else {
      attr = HL_ATTR(hlf);
    }
    wp->w_hl_attrs[hlf] = attr;
  }
}

/// Gets HL_UNDERLINE highlight.
int hl_get_underline(void)
{
  return get_attr_entry((HlEntry){
      .attr = (HlAttrs){
          .cterm_ae_attr = (int16_t)HL_UNDERLINE,
          .cterm_fg_color = 0,
          .cterm_bg_color = 0,
          .rgb_ae_attr = (int16_t)HL_UNDERLINE,
          .rgb_fg_color = -1,
          .rgb_bg_color = -1,
          .rgb_sp_color = -1,
      },
      .kind = kHlUI,
      .id1 = 0,
      .id2 = 0,
  });
}

/// Get attribute code for forwarded :terminal highlights.
int hl_get_term_attr(HlAttrs *aep)
{
  return get_attr_entry((HlEntry){ .attr= *aep, .kind = kHlTerminal,
                                   .id1 = 0, .id2 = 0 });
}

/// Clear all highlight tables.
void clear_hl_tables(bool reinit)
{
  if (reinit) {
    kv_size(attr_entries) = 1;
    map_clear(HlEntry, int)(attr_entry_ids);
    map_clear(int, int)(combine_attr_entries);
    highlight_attr_set_all();
    highlight_changed();
    screen_invalidate_highlights();
  } else {
    kv_destroy(attr_entries);
    map_free(HlEntry, int)(attr_entry_ids);
    map_free(int, int)(combine_attr_entries);
  }
}

// Combine special attributes (e.g., for spelling) with other attributes
// (e.g., for syntax highlighting).
// "prim_attr" overrules "char_attr".
// This creates a new group when required.
// Since we expect there to be few spelling mistakes we don't cache the
// result.
// Return the resulting attributes.
int hl_combine_attr(int char_attr, int prim_attr)
{
  if (char_attr == 0) {
    return prim_attr;
  } else if (prim_attr == 0) {
    return char_attr;
  }

  // TODO(bfredl): could use a struct for clearer intent.
  int combine_tag = (char_attr << 16) + prim_attr;
  int id = map_get(int, int)(combine_attr_entries, combine_tag);
  if (id > 0) {
    return id;
  }

  HlAttrs char_aep = syn_attr2entry(char_attr);
  HlAttrs spell_aep = syn_attr2entry(prim_attr);

  // start with low-priority attribute, and override colors if present below.
  HlAttrs new_en = char_aep;

  new_en.cterm_ae_attr |= spell_aep.cterm_ae_attr;
  new_en.rgb_ae_attr |= spell_aep.rgb_ae_attr;

  if (spell_aep.cterm_fg_color > 0) {
    new_en.cterm_fg_color = spell_aep.cterm_fg_color;
  }

  if (spell_aep.cterm_bg_color > 0) {
    new_en.cterm_bg_color = spell_aep.cterm_bg_color;
  }

  if (spell_aep.rgb_fg_color >= 0) {
    new_en.rgb_fg_color = spell_aep.rgb_fg_color;
  }

  if (spell_aep.rgb_bg_color >= 0) {
    new_en.rgb_bg_color = spell_aep.rgb_bg_color;
  }

  if (spell_aep.rgb_sp_color >= 0) {
    new_en.rgb_sp_color = spell_aep.rgb_sp_color;
  }

  id = get_attr_entry((HlEntry){ .attr = new_en, .kind = kHlCombine,
                                 .id1 = char_attr, .id2 = prim_attr });
  if (id > 0) {
    map_put(int, int)(combine_attr_entries, combine_tag, id);
  }

  return id;
}

/// Get highlight attributes for a attribute code
HlAttrs syn_attr2entry(int attr)
{
  if (attr <= 0 || attr >= (int)kv_size(attr_entries)) {
    // invalid attribute code, or the tables were cleared
    return HLATTRS_INIT;
  }
  return kv_A(attr_entries, attr).attr;
}

/// Gets highlight description for id `attr_id` as a map.
Dictionary hl_get_attr_by_id(Integer attr_id, Boolean rgb, Error *err)
{
  Dictionary dic = ARRAY_DICT_INIT;

  if (attr_id == 0) {
    return dic;
  }

  if (attr_id <= 0 || attr_id >= (int)kv_size(attr_entries)) {
    api_set_error(err, kErrorTypeException,
                  "Invalid attribute id: %" PRId64, attr_id);
    return dic;
  }

  return hlattrs2dict(syn_attr2entry((int)attr_id), rgb);
}

/// Converts an HlAttrs into Dictionary
///
/// @param[in] aep data to convert
/// @param use_rgb use 'gui*' settings if true, else resorts to 'cterm*'
Dictionary hlattrs2dict(HlAttrs ae, bool use_rgb)
{
  Dictionary hl = ARRAY_DICT_INIT;
  int mask  = use_rgb ? ae.rgb_ae_attr : ae.cterm_ae_attr;

  if (mask & HL_BOLD) {
    PUT(hl, "bold", BOOLEAN_OBJ(true));
  }

  if (mask & HL_STANDOUT) {
    PUT(hl, "standout", BOOLEAN_OBJ(true));
  }

  if (mask & HL_UNDERLINE) {
    PUT(hl, "underline", BOOLEAN_OBJ(true));
  }

  if (mask & HL_UNDERCURL) {
    PUT(hl, "undercurl", BOOLEAN_OBJ(true));
  }

  if (mask & HL_ITALIC) {
    PUT(hl, "italic", BOOLEAN_OBJ(true));
  }

  if (mask & HL_INVERSE) {
    PUT(hl, "reverse", BOOLEAN_OBJ(true));
  }

  if (use_rgb) {
    if (ae.rgb_fg_color != -1) {
      PUT(hl, "foreground", INTEGER_OBJ(ae.rgb_fg_color));
    }

    if (ae.rgb_bg_color != -1) {
      PUT(hl, "background", INTEGER_OBJ(ae.rgb_bg_color));
    }

    if (ae.rgb_sp_color != -1) {
      PUT(hl, "special", INTEGER_OBJ(ae.rgb_sp_color));
    }
  } else {
    if (cterm_normal_fg_color != ae.cterm_fg_color) {
      PUT(hl, "foreground", INTEGER_OBJ(ae.cterm_fg_color - 1));
    }

    if (cterm_normal_bg_color != ae.cterm_bg_color) {
      PUT(hl, "background", INTEGER_OBJ(ae.cterm_bg_color - 1));
    }
  }

  return hl;
}

Array hl_inspect(int attr)
{
  Array ret = ARRAY_DICT_INIT;
  if (hlstate_active) {
    hl_inspect_impl(&ret, attr);
  }
  return ret;
}

static void hl_inspect_impl(Array *arr, int attr)
{
  Dictionary item = ARRAY_DICT_INIT;
  if (attr <= 0 || attr >= (int)kv_size(attr_entries)) {
    return;
  }

  HlEntry e = kv_A(attr_entries, attr);
  switch (e.kind) {
    case kHlSyntax:
      PUT(item, "kind", STRING_OBJ(cstr_to_string("syntax")));
      PUT(item, "hi_name",
          STRING_OBJ(cstr_to_string((char *)syn_id2name(e.id1))));
      break;

    case kHlUI:
      PUT(item, "kind", STRING_OBJ(cstr_to_string("ui")));
      const char *ui_name = (e.id1 == -1) ? "Normal" : hlf_names[e.id1];
      PUT(item, "ui_name", STRING_OBJ(cstr_to_string(ui_name)));
      PUT(item, "hi_name",
          STRING_OBJ(cstr_to_string((char *)syn_id2name(e.id2))));
      break;

    case kHlTerminal:
      PUT(item, "kind", STRING_OBJ(cstr_to_string("term")));
      break;

    case kHlCombine:
      // attribute combination is associative, so flatten to an array
      hl_inspect_impl(arr, e.id1);
      hl_inspect_impl(arr, e.id2);
      return;

     case kHlUnknown:
      return;
  }
  PUT(item, "id", INTEGER_OBJ(attr));
  ADD(*arr, DICTIONARY_OBJ(item));
}
