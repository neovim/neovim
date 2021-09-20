// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// highlight.c: low level code for UI and syntax highlighting

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/lua/executor.h"
#include "nvim/map.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/popupmnu.h"
#include "nvim/screen.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "highlight.c.generated.h"
#endif

static bool hlstate_active = false;

static kvec_t(HlEntry) attr_entries = KV_INITIAL_VALUE;

static Map(HlEntry, int) attr_entry_ids = MAP_INIT;
static Map(int, int) combine_attr_entries = MAP_INIT;
static Map(int, int) blend_attr_entries = MAP_INIT;
static Map(int, int) blendthrough_attr_entries = MAP_INIT;

/// highlight entries private to a namespace
static Map(ColorKey, ColorItem) ns_hl;

void highlight_init(void)
{
  // index 0 is no attribute, add dummy entry:
  kv_push(attr_entries, ((HlEntry){ .attr = HLATTRS_INIT, .kind = kHlUnknown,
                                    .id1 = 0, .id2 = 0 }));
}

/// @return true if hl table was reset
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

  int id = map_get(HlEntry, int)(&attr_entry_ids, entry);
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

  size_t next_id = kv_size(attr_entries);
  if (next_id > INT_MAX) {
    ELOG("The index on attr_entries has overflowed");
    return 0;
  }
  id = (int)next_id;
  kv_push(attr_entries, entry);

  map_put(HlEntry, int)(&attr_entry_ids, entry, id);

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
  if (ui->hl_attr_define) {
    for (size_t i = 1; i < kv_size(attr_entries); i++) {
      Array inspect = hl_inspect((int)i);
      ui->hl_attr_define(ui, (Integer)i, kv_A(attr_entries, i).attr,
                         kv_A(attr_entries, i).attr, inspect);
      api_free_array(inspect);
    }
  }
  if (ui->hl_group_set) {
    for (size_t hlf = 0; hlf < HLF_COUNT; hlf++) {
      ui->hl_group_set(ui, cstr_as_string((char *)hlf_names[hlf]),
                       highlight_attr[hlf]);
    }
  }
}

/// Get attribute code for a syntax group.
int hl_get_syn_attr(int ns_id, int idx, HlAttrs at_en)
{
  // TODO(bfredl): should we do this unconditionally
  if (at_en.cterm_fg_color != 0 || at_en.cterm_bg_color != 0
      || at_en.rgb_fg_color != -1 || at_en.rgb_bg_color != -1
      || at_en.rgb_sp_color != -1 || at_en.cterm_ae_attr != 0
      || at_en.rgb_ae_attr != 0 || ns_id != 0) {
    return get_attr_entry((HlEntry){ .attr = at_en, .kind = kHlSyntax,
                                     .id1 = idx, .id2 = ns_id });
  } else {
    // If all the fields are cleared, clear the attr field back to default value
    return 0;
  }
}

void ns_hl_def(NS ns_id, int hl_id, HlAttrs attrs, int link_id)
{
  DecorProvider *p = get_decor_provider(ns_id, true);
  if ((attrs.rgb_ae_attr & HL_DEFAULT)
      && map_has(ColorKey, ColorItem)(&ns_hl, ColorKey(ns_id, hl_id))) {
    return;
  }
  int attr_id = link_id > 0 ? -1 : hl_get_syn_attr(ns_id, hl_id, attrs);
  ColorItem it = { .attr_id = attr_id,
                   .link_id = link_id,
                   .version = p->hl_valid,
                   .is_default = (attrs.rgb_ae_attr & HL_DEFAULT) };
  map_put(ColorKey, ColorItem)(&ns_hl, ColorKey(ns_id, hl_id), it);
}

int ns_get_hl(NS ns_id, int hl_id, bool link, bool nodefault)
{
  static int recursive = 0;

  if (ns_id < 0) {
    if (ns_hl_active <= 0) {
      return -1;
    }
    ns_id = ns_hl_active;
  }

  DecorProvider *p = get_decor_provider(ns_id, true);
  ColorItem it = map_get(ColorKey, ColorItem)(&ns_hl, ColorKey(ns_id, hl_id));
  // TODO(bfredl): map_ref true even this?
  bool valid_cache = it.version >= p->hl_valid;

  if (!valid_cache && p->hl_def != LUA_NOREF && !recursive) {
    FIXED_TEMP_ARRAY(args, 3);
    args.items[0] = INTEGER_OBJ((Integer)ns_id);
    args.items[1] = STRING_OBJ(cstr_to_string((char *)syn_id2name(hl_id)));
    args.items[2] = BOOLEAN_OBJ(link);
    // TODO(bfredl): preload the "global" attr dict?

    Error err = ERROR_INIT;
    recursive++;
    Object ret = nlua_call_ref(p->hl_def, "hl_def", args, true, &err);
    recursive--;

    // TODO(bfredl): or "inherit", combine with global value?
    bool fallback = true;
    int tmp = false;
    HlAttrs attrs = HLATTRS_INIT;
    if (ret.type == kObjectTypeDictionary) {
      Dictionary dict = ret.data.dictionary;
      fallback = false;
      attrs = dict2hlattrs(dict, true, &it.link_id, &err);
      for (size_t i = 0; i < dict.size; i++) {
        char *key = dict.items[i].key.data;
        Object val = dict.items[i].value;
        bool truthy = api_object_to_bool(val, key, false, &err);

        if (strequal(key, "fallback")) {
          fallback = truthy;
        } else if (strequal(key, "temp")) {
          tmp = truthy;
        }
      }
      if (it.link_id >= 0) {
        fallback = true;
      }
    }

    it.attr_id = fallback ? -1 : hl_get_syn_attr((int)ns_id, hl_id, attrs);
    it.version = p->hl_valid-tmp;
    it.is_default = attrs.rgb_ae_attr & HL_DEFAULT;
    map_put(ColorKey, ColorItem)(&ns_hl, ColorKey(ns_id, hl_id), it);
  }

  if (it.is_default && nodefault) {
    return -1;
  }

  if (link) {
    return it.attr_id >= 0 ? 0 : it.link_id;
  } else {
    return it.attr_id;
  }
}


bool win_check_ns_hl(win_T *wp)
{
  if (ns_hl_changed) {
    highlight_changed();
    if (wp) {
      update_window_hl(wp, true);
    }
    ns_hl_changed = false;
    return true;
  }
  return false;
}

/// Get attribute code for a builtin highlight group.
///
/// The final syntax group could be modified by hi-link or 'winhighlight'.
int hl_get_ui_attr(int idx, int final_id, bool optional)
{
  HlAttrs attrs = HLATTRS_INIT;
  bool available = false;

  if (final_id > 0) {
    int syn_attr = syn_id2attr(final_id);
    if (syn_attr != 0) {
      attrs = syn_attr2entry(syn_attr);
      available = true;
    }
  }

  if (HLF_PNI <= idx && idx <= HLF_PST) {
    if (attrs.hl_blend == -1 && p_pb > 0) {
      attrs.hl_blend = (int)p_pb;
    }
    if (pum_drawn()) {
      must_redraw_pum = true;
    }
  } else if (idx == HLF_MSG) {
    msg_grid.blending = attrs.hl_blend > -1;
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

  // If a floating window is blending it always have a named
  // wp->w_hl_attr_normal group. HL_ATTR(HLF_NFLOAT) is always named.
  bool has_blend = wp->w_floating && wp->w_p_winbl != 0;

  // determine window specific background set in 'winhighlight'
  bool float_win = wp->w_floating && !wp->w_float_config.external;
  if (wp != curwin && wp->w_hl_ids[HLF_INACTIVE] != 0) {
    wp->w_hl_attr_normal = hl_get_ui_attr(HLF_INACTIVE,
                                          wp->w_hl_ids[HLF_INACTIVE],
                                          !has_blend);
  } else if (float_win && wp->w_hl_ids[HLF_NFLOAT] != 0) {
    wp->w_hl_attr_normal = hl_get_ui_attr(HLF_NFLOAT,
                                          wp->w_hl_ids[HLF_NFLOAT], !has_blend);
  } else if (wp->w_hl_id_normal != 0) {
    wp->w_hl_attr_normal = hl_get_ui_attr(-1, wp->w_hl_id_normal, !has_blend);
  } else {
    wp->w_hl_attr_normal = float_win ? HL_ATTR(HLF_NFLOAT) : 0;
  }

  // NOOOO! You cannot just pretend that "Normal" is just like any other
  // syntax group! It needs at least 10 layers of special casing! Noooooo!
  //
  // haha, theme engine go brrr
  int normality = syn_check_group((const char_u *)S_LEN("Normal"));
  int ns_attr = ns_get_hl(-1, normality, false, false);
  if (ns_attr > 0) {
    // TODO(bfredl): hantera NormalNC and so on
    wp->w_hl_attr_normal = ns_attr;
  }

  // if blend= attribute is not set, 'winblend' value overrides it.
  if (wp->w_floating && wp->w_p_winbl > 0) {
    HlEntry entry = kv_A(attr_entries, wp->w_hl_attr_normal);
    if (entry.attr.hl_blend == -1) {
      entry.attr.hl_blend = (int)wp->w_p_winbl;
      wp->w_hl_attr_normal = get_attr_entry(entry);
    }
  }

  if (wp != curwin && wp->w_hl_ids[HLF_INACTIVE] == 0) {
    wp->w_hl_attr_normal = hl_combine_attr(HL_ATTR(HLF_INACTIVE),
                                           wp->w_hl_attr_normal);
  }

  for (int hlf = 0; hlf < (int)HLF_COUNT; hlf++) {
    int attr;
    if (wp->w_hl_ids[hlf] != 0) {
      attr = hl_get_ui_attr(hlf, wp->w_hl_ids[hlf], false);
    } else {
      attr = HL_ATTR(hlf);
    }
    wp->w_hl_attrs[hlf] = attr;
  }

  wp->w_float_config.shadow = false;
  if (wp->w_floating && wp->w_float_config.border) {
    for (int i = 0; i < 8; i++) {
      int attr = wp->w_hl_attrs[HLF_BORDER];
      if (wp->w_float_config.border_hl_ids[i]) {
        attr = hl_get_ui_attr(HLF_BORDER, wp->w_float_config.border_hl_ids[i],
                              false);
        HlAttrs a = syn_attr2entry(attr);
        if (a.hl_blend) {
          wp->w_float_config.shadow = true;
        }
      }
      wp->w_float_config.border_attr[i] = attr;
    }
  }

  // shadow might cause blending
  check_blending(wp);
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
      .hl_blend = -1,
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
    map_clear(HlEntry, int)(&attr_entry_ids);
    map_clear(int, int)(&combine_attr_entries);
    map_clear(int, int)(&blend_attr_entries);
    map_clear(int, int)(&blendthrough_attr_entries);
    memset(highlight_attr_last, -1, sizeof(highlight_attr_last));
    highlight_attr_set_all();
    highlight_changed();
    screen_invalidate_highlights();
  } else {
    kv_destroy(attr_entries);
    map_destroy(HlEntry, int)(&attr_entry_ids);
    map_destroy(int, int)(&combine_attr_entries);
    map_destroy(int, int)(&blend_attr_entries);
    map_destroy(int, int)(&blendthrough_attr_entries);
    map_destroy(ColorKey, ColorItem)(&ns_hl);
  }
}

void hl_invalidate_blends(void)
{
  map_clear(int, int)(&blend_attr_entries);
  map_clear(int, int)(&blendthrough_attr_entries);
  highlight_changed();
  update_window_hl(curwin, true);
}

// Combine special attributes (e.g., for spelling) with other attributes
// (e.g., for syntax highlighting).
// "prim_attr" overrules "char_attr".
// This creates a new group when required.
// Since we expect there to be a lot of spelling mistakes we cache the result.
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
  int id = map_get(int, int)(&combine_attr_entries, combine_tag);
  if (id > 0) {
    return id;
  }

  HlAttrs char_aep = syn_attr2entry(char_attr);
  HlAttrs spell_aep = syn_attr2entry(prim_attr);

  // start with low-priority attribute, and override colors if present below.
  HlAttrs new_en = char_aep;

  if (spell_aep.cterm_ae_attr & HL_NOCOMBINE) {
    new_en.cterm_ae_attr = spell_aep.cterm_ae_attr;
  } else {
    new_en.cterm_ae_attr |= spell_aep.cterm_ae_attr;
  }
  if (spell_aep.rgb_ae_attr & HL_NOCOMBINE) {
    new_en.rgb_ae_attr = spell_aep.rgb_ae_attr;
  } else {
    new_en.rgb_ae_attr |= spell_aep.rgb_ae_attr;
  }

  if (spell_aep.cterm_fg_color > 0) {
    new_en.cterm_fg_color = spell_aep.cterm_fg_color;
    new_en.rgb_ae_attr &= ((~HL_FG_INDEXED)
                           | (spell_aep.rgb_ae_attr & HL_FG_INDEXED));
  }

  if (spell_aep.cterm_bg_color > 0) {
    new_en.cterm_bg_color = spell_aep.cterm_bg_color;
    new_en.rgb_ae_attr &= ((~HL_BG_INDEXED)
                           | (spell_aep.rgb_ae_attr & HL_BG_INDEXED));
  }

  if (spell_aep.rgb_fg_color >= 0) {
    new_en.rgb_fg_color = spell_aep.rgb_fg_color;
    new_en.rgb_ae_attr &= ((~HL_FG_INDEXED)
                           | (spell_aep.rgb_ae_attr & HL_FG_INDEXED));
  }

  if (spell_aep.rgb_bg_color >= 0) {
    new_en.rgb_bg_color = spell_aep.rgb_bg_color;
    new_en.rgb_ae_attr &= ((~HL_BG_INDEXED)
                           | (spell_aep.rgb_ae_attr & HL_BG_INDEXED));
  }

  if (spell_aep.rgb_sp_color >= 0) {
    new_en.rgb_sp_color = spell_aep.rgb_sp_color;
  }

  if (spell_aep.hl_blend >= 0) {
    new_en.hl_blend = spell_aep.hl_blend;
  }

  id = get_attr_entry((HlEntry){ .attr = new_en, .kind = kHlCombine,
                                 .id1 = char_attr, .id2 = prim_attr });
  if (id > 0) {
    map_put(int, int)(&combine_attr_entries, combine_tag, id);
  }

  return id;
}

/// Get the used rgb colors for an attr group.
///
/// If colors are unset, use builtin default colors. Never returns -1
/// Cterm colors are unchanged.
static HlAttrs get_colors_force(int attr)
{
  HlAttrs attrs = syn_attr2entry(attr);
  if (attrs.rgb_bg_color == -1) {
    attrs.rgb_bg_color = normal_bg;
  }
  if (attrs.rgb_fg_color == -1) {
    attrs.rgb_fg_color = normal_fg;
  }
  if (attrs.rgb_sp_color == -1) {
    attrs.rgb_sp_color = normal_sp;
  }
  HL_SET_DEFAULT_COLORS(attrs.rgb_fg_color, attrs.rgb_bg_color,
                        attrs.rgb_sp_color);

  if (attrs.rgb_ae_attr & HL_INVERSE) {
    int temp = attrs.rgb_bg_color;
    attrs.rgb_bg_color = attrs.rgb_fg_color;
    attrs.rgb_fg_color = temp;
    attrs.rgb_ae_attr &= ~HL_INVERSE;
  }

  return attrs;
}

/// Blend overlay attributes (for popupmenu) with other attributes
///
/// This creates a new group when required.
/// This is called per-cell, so cache the result.
///
/// @return the resulting attributes.
int hl_blend_attrs(int back_attr, int front_attr, bool *through)
{
  if (front_attr < 0 || back_attr < 0) {
    return -1;
  }

  HlAttrs fattrs = get_colors_force(front_attr);
  int ratio = fattrs.hl_blend;
  if (ratio <= 0) {
    *through = false;
    return front_attr;
  }

  int combine_tag = (back_attr << 16) + front_attr;
  Map(int, int) *map = (*through
                        ? &blendthrough_attr_entries
                        : &blend_attr_entries);
  int id = map_get(int, int)(map, combine_tag);
  if (id > 0) {
    return id;
  }

  HlAttrs battrs = get_colors_force(back_attr);
  HlAttrs cattrs;

  if (*through) {
    cattrs = battrs;
    cattrs.rgb_fg_color = rgb_blend(ratio, battrs.rgb_fg_color,
                                    fattrs.rgb_bg_color);
    if (cattrs.rgb_ae_attr & (HL_UNDERLINE|HL_UNDERCURL)) {
      cattrs.rgb_sp_color = rgb_blend(ratio, battrs.rgb_sp_color,
                                      fattrs.rgb_bg_color);
    } else {
      cattrs.rgb_sp_color = -1;
    }

    cattrs.cterm_bg_color = fattrs.cterm_bg_color;
    cattrs.cterm_fg_color = cterm_blend(ratio, battrs.cterm_fg_color,
                                        fattrs.cterm_bg_color);
    cattrs.rgb_ae_attr &= ~(HL_FG_INDEXED | HL_BG_INDEXED);
  } else {
    cattrs = fattrs;
    if (ratio >= 50) {
      cattrs.rgb_ae_attr |= battrs.rgb_ae_attr;
    }
    cattrs.rgb_fg_color = rgb_blend(ratio/2, battrs.rgb_fg_color,
                                    fattrs.rgb_fg_color);
    if (cattrs.rgb_ae_attr & (HL_UNDERLINE|HL_UNDERCURL)) {
      cattrs.rgb_sp_color = rgb_blend(ratio/2, battrs.rgb_bg_color,
                                      fattrs.rgb_sp_color);
    } else {
      cattrs.rgb_sp_color = -1;
    }

    cattrs.rgb_ae_attr &= ~HL_BG_INDEXED;
  }
  cattrs.rgb_bg_color = rgb_blend(ratio, battrs.rgb_bg_color,
                                  fattrs.rgb_bg_color);

  cattrs.hl_blend = -1;  // blend property was consumed

  HlKind kind = *through ? kHlBlendThrough : kHlBlend;
  id = get_attr_entry((HlEntry){ .attr = cattrs, .kind = kind,
                                 .id1 = back_attr, .id2 = front_attr });
  if (id > 0) {
    map_put(int, int)(map, combine_tag, id);
  }
  return id;
}

static int rgb_blend(int ratio, int rgb1, int rgb2)
{
  int a = ratio, b = 100-ratio;
  int r1 = (rgb1 & 0xFF0000) >> 16;
  int g1 = (rgb1 & 0x00FF00) >> 8;
  int b1 = (rgb1 & 0x0000FF) >> 0;
  int r2 = (rgb2 & 0xFF0000) >> 16;
  int g2 = (rgb2 & 0x00FF00) >> 8;
  int b2 = (rgb2 & 0x0000FF) >> 0;
  int mr = (a * r1 + b * r2)/100;
  int mg = (a * g1 + b * g2)/100;
  int mb = (a * b1 + b * b2)/100;
  return (mr << 16) + (mg << 8) + mb;
}

static int cterm_blend(int ratio, int c1, int c2)
{
  // 1. Convert cterm color numbers to RGB.
  // 2. Blend the RGB colors.
  // 3. Convert the RGB result to a cterm color.
  int rgb1 = hl_cterm2rgb_color(c1);
  int rgb2 = hl_cterm2rgb_color(c2);
  int rgb_blended = rgb_blend(ratio, rgb1, rgb2);
  return hl_rgb2cterm_color(rgb_blended);
}

/// Converts RGB color to 8-bit color (0-255).
static int hl_rgb2cterm_color(int rgb)
{
  int r = (rgb & 0xFF0000) >> 16;
  int g = (rgb & 0x00FF00) >> 8;
  int b = (rgb & 0x0000FF) >> 0;

  return (r * 6 / 256) * 36 + (g * 6 / 256) * 6 + (b * 6 / 256);
}

/// Converts 8-bit color (0-255) to RGB color.
/// This is compatible with xterm.
static int hl_cterm2rgb_color(int nr)
{
  static int cube_value[] = {
    0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF
  };
  static int grey_ramp[] = {
    0x08, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E, 0x58, 0x62, 0x6C, 0x76,
    0x80, 0x8A, 0x94, 0x9E, 0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
  };
  static char_u ansi_table[16][4] = {
    //  R    G    B   idx
    {   0,   0,   0,  1 },  // black
    { 224,   0,   0,  2 },  // dark red
    {   0, 224,   0,  3 },  // dark green
    { 224, 224,   0,  4 },  // dark yellow / brown
    {   0,   0, 224,  5 },  // dark blue
    { 224,   0, 224,  6 },  // dark magenta
    {   0, 224, 224,  7 },  // dark cyan
    { 224, 224, 224,  8 },  // light grey

    { 128, 128, 128,  9 },  // dark grey
    { 255,  64,  64, 10 },  // light red
    {  64, 255,  64, 11 },  // light green
    { 255, 255,  64, 12 },  // yellow
    {  64,  64, 255, 13 },  // light blue
    { 255,  64, 255, 14 },  // light magenta
    {  64, 255, 255, 15 },  // light cyan
    { 255, 255, 255, 16 },  // white
  };

  int r = 0;
  int g = 0;
  int b = 0;
  int idx;
  // *ansi_idx = 0;

  if (nr < 16) {
    r = ansi_table[nr][0];
    g = ansi_table[nr][1];
    b = ansi_table[nr][2];
    // *ansi_idx = ansi_table[nr][3];
  } else if (nr < 232) {  // 216 color-cube
    idx = nr - 16;
    r = cube_value[idx / 36 % 6];
    g = cube_value[idx / 6  % 6];
    b = cube_value[idx      % 6];
    // *ansi_idx = -1;
  } else if (nr < 256) {  // 24 greyscale ramp
    idx = nr - 232;
    r = grey_ramp[idx];
    g = grey_ramp[idx];
    b = grey_ramp[idx];
    // *ansi_idx = -1;
  }
  return (r << 16) + (g << 8) + b;
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

  if (mask & HL_STRIKETHROUGH) {
    PUT(hl, "strikethrough", BOOLEAN_OBJ(true));
  }

  if (use_rgb) {
    if (mask & HL_FG_INDEXED) {
      PUT(hl, "fg_indexed", BOOLEAN_OBJ(true));
    }

    if (mask & HL_BG_INDEXED) {
      PUT(hl, "bg_indexed", BOOLEAN_OBJ(true));
    }

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
    if (cterm_normal_fg_color != ae.cterm_fg_color && ae.cterm_fg_color != 0) {
      PUT(hl, "foreground", INTEGER_OBJ(ae.cterm_fg_color - 1));
    }

    if (cterm_normal_bg_color != ae.cterm_bg_color && ae.cterm_bg_color != 0) {
      PUT(hl, "background", INTEGER_OBJ(ae.cterm_bg_color - 1));
    }
  }

  if (ae.hl_blend > -1) {
    PUT(hl, "blend", INTEGER_OBJ(ae.hl_blend));
  }

  return hl;
}

HlAttrs dict2hlattrs(Dictionary dict, bool use_rgb, int *link_id, Error *err)
{
  HlAttrs hlattrs = HLATTRS_INIT;

  int32_t fg = -1, bg = -1, ctermfg = -1, ctermbg = -1, sp = -1;
  int16_t mask = 0;
  int16_t cterm_mask = 0;
  bool cterm_mask_provided = false;

  for (size_t i = 0; i < dict.size; i++) {
    char *key = dict.items[i].key.data;
    Object val = dict.items[i].value;

    struct {
      const char *name;
      int16_t flag;
    } flags[] = {
      { "bold", HL_BOLD },
      { "standout", HL_STANDOUT },
      { "underline", HL_UNDERLINE },
      { "undercurl", HL_UNDERCURL },
      { "italic", HL_ITALIC },
      { "reverse", HL_INVERSE },
      { "default", HL_DEFAULT },
      { "global", HL_GLOBAL },
      { NULL, 0 },
    };

    int j;
    for (j = 0; flags[j].name; j++) {
      if (strequal(flags[j].name, key)) {
        if (api_object_to_bool(val, key, false, err)) {
          mask = mask | flags[j].flag;
        }
        break;
      }
    }

    // Handle cterm attrs
    if (strequal(key, "cterm") && val.type == kObjectTypeDictionary) {
      cterm_mask_provided = true;
      Dictionary cterm_dict = val.data.dictionary;
      for (size_t l = 0; l < cterm_dict.size; l++) {
        char *cterm_dict_key = cterm_dict.items[l].key.data;
        Object cterm_dict_val = cterm_dict.items[l].value;
        for (int m = 0; flags[m].name; m++) {
          if (strequal(flags[m].name, cterm_dict_key)) {
            if (api_object_to_bool(cterm_dict_val, cterm_dict_key, false,
                                   err)) {
              cterm_mask |= flags[m].flag;
            }
            break;
          }
        }
      }
    }

    struct {
      const char *name;
      const char *shortname;
      int *dest;
    } colors[] = {
      { "foreground", "fg", &fg },
      { "background", "bg", &bg },
      { "ctermfg", NULL, &ctermfg },
      { "ctermbg", NULL, &ctermbg },
      { "special", "sp", &sp },
      { NULL, NULL, NULL },
    };

    int k;
    for (k = 0; (!flags[j].name) && colors[k].name; k++) {
      if (strequal(colors[k].name, key) || strequal(colors[k].shortname, key)) {
        if (val.type == kObjectTypeInteger) {
          *colors[k].dest = (int)val.data.integer;
        } else if (val.type == kObjectTypeString) {
          String str = val.data.string;
          // TODO(bfredl): be more fancy with "bg", "fg" etc
          if (str.size) {
            *colors[k].dest = name_to_color(str.data);
          }
        } else {
          api_set_error(err, kErrorTypeValidation,
                        "'%s' must be string or integer", key);
        }
        break;
      }
    }

    if (flags[j].name || colors[k].name) {
      // handled above
    } else if (link_id && strequal(key, "link")) {
      if (val.type == kObjectTypeString) {
        String str = val.data.string;
        *link_id = syn_check_group((const char_u *)str.data, (int)str.size);
      } else if (val.type == kObjectTypeInteger) {
        // TODO(bfredl): validate range?
        *link_id = (int)val.data.integer;
      } else {
        api_set_error(err, kErrorTypeValidation,
                      "'link' must be string or integer");
      }
    }

    if (ERROR_SET(err)) {
      return hlattrs;  // error set, caller should not use retval
    }
  }

  // apply gui mask as default for cterm mask
  if (!cterm_mask_provided) {
    cterm_mask = mask;
  }
  if (use_rgb) {
    hlattrs.rgb_ae_attr = mask;
    hlattrs.rgb_bg_color = bg;
    hlattrs.rgb_fg_color = fg;
    hlattrs.rgb_sp_color = sp;
    hlattrs.cterm_bg_color =
      ctermbg == -1 ? cterm_normal_bg_color : ctermbg + 1;
    hlattrs.cterm_fg_color =
      ctermfg == -1 ? cterm_normal_fg_color : ctermfg + 1;
    hlattrs.cterm_ae_attr = cterm_mask;
  } else {
    hlattrs.cterm_ae_attr = cterm_mask;
    hlattrs.cterm_bg_color = bg == -1 ? cterm_normal_bg_color : bg + 1;
    hlattrs.cterm_fg_color = fg == -1 ? cterm_normal_fg_color : fg + 1;
  }

  return hlattrs;
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
  case kHlBlend:
  case kHlBlendThrough:
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
