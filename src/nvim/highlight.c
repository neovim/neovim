// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// highlight.c: low level code for UI and syntax highlighting

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <string.h>

#include "klib/kvec.h"
#include "lauxlib.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/api/ui.h"
#include "nvim/decoration_provider.h"
#include "nvim/drawscreen.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/macros.h"
#include "nvim/map.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/popupmenu.h"
#include "nvim/types.h"
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
static Map(ColorKey, ColorItem) ns_hls;
typedef int NSHlAttr[HLF_COUNT + 1];
static PMap(int) ns_hl_attr;

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
      emsg(_("E424: Too many different highlighting attributes in use"));
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
  for (size_t i = 1; i < kv_size(attr_entries); i++) {
    Array inspect = hl_inspect((int)i);
    remote_ui_hl_attr_define(ui, (Integer)i, kv_A(attr_entries, i).attr,
                             kv_A(attr_entries, i).attr, inspect);
    api_free_array(inspect);
  }
  for (size_t hlf = 0; hlf < HLF_COUNT; hlf++) {
    remote_ui_hl_group_set(ui, cstr_as_string((char *)hlf_names[hlf]),
                           highlight_attr[hlf]);
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
  }
  // If all the fields are cleared, clear the attr field back to default value
  return 0;
}

void ns_hl_def(NS ns_id, int hl_id, HlAttrs attrs, int link_id, Dict(highlight) *dict)
{
  if (ns_id == 0) {
    assert(dict);
    // set in global (':highlight') namespace
    set_hl_group(hl_id, attrs, dict, link_id);
    return;
  }
  if ((attrs.rgb_ae_attr & HL_DEFAULT)
      && map_has(ColorKey, ColorItem)(&ns_hls, ColorKey(ns_id, hl_id))) {
    return;
  }
  DecorProvider *p = get_decor_provider(ns_id, true);
  int attr_id = link_id > 0 ? -1 : hl_get_syn_attr(ns_id, hl_id, attrs);
  ColorItem it = { .attr_id = attr_id,
                   .link_id = link_id,
                   .version = p->hl_valid,
                   .is_default = (attrs.rgb_ae_attr & HL_DEFAULT),
                   .link_global = (attrs.rgb_ae_attr & HL_GLOBAL) };
  map_put(ColorKey, ColorItem)(&ns_hls, ColorKey(ns_id, hl_id), it);
  p->hl_cached = false;
}

int ns_get_hl(NS *ns_hl, int hl_id, bool link, bool nodefault)
{
  static int recursive = 0;

  if (*ns_hl == 0) {
    // ns=0 (the default namespace) does not have a provider so stop here
    return -1;
  }

  if (*ns_hl < 0) {
    if (ns_hl_active <= 0) {
      return -1;
    }
    *ns_hl = ns_hl_active;
  }

  int ns_id = *ns_hl;

  DecorProvider *p = get_decor_provider(ns_id, true);
  ColorItem it = map_get(ColorKey, ColorItem)(&ns_hls, ColorKey(ns_id, hl_id));
  // TODO(bfredl): map_ref true even this?
  bool valid_item = it.version >= p->hl_valid;

  if (!valid_item && p->hl_def != LUA_NOREF && !recursive) {
    MAXSIZE_TEMP_ARRAY(args, 3);
    ADD_C(args, INTEGER_OBJ((Integer)ns_id));
    ADD_C(args, CSTR_TO_OBJ(syn_id2name(hl_id)));
    ADD_C(args, BOOLEAN_OBJ(link));
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
      fallback = false;
      Dict(highlight) dict = { 0 };
      if (api_dict_to_keydict(&dict, KeyDict_highlight_get_field,
                              ret.data.dictionary, &err)) {
        attrs = dict2hlattrs(&dict, true, &it.link_id, &err);
        fallback = api_object_to_bool(dict.fallback, "fallback", true, &err);
        tmp = api_object_to_bool(dict.fallback, "tmp", false, &err);
        if (it.link_id >= 0) {
          fallback = true;
        }
      }
    }

    it.attr_id = fallback ? -1 : hl_get_syn_attr(ns_id, hl_id, attrs);
    it.version = p->hl_valid - tmp;
    it.is_default = attrs.rgb_ae_attr & HL_DEFAULT;
    it.link_global = attrs.rgb_ae_attr & HL_GLOBAL;
    map_put(ColorKey, ColorItem)(&ns_hls, ColorKey(ns_id, hl_id), it);
    valid_item = true;
  }

  if ((it.is_default && nodefault) || !valid_item) {
    return -1;
  }

  if (link) {
    if (it.attr_id >= 0) {
      return 0;
    }
    if (it.link_global) {
      *ns_hl = 0;
    }
    return it.link_id;
  } else {
    return it.attr_id;
  }
}

bool hl_check_ns(void)
{
  int ns = 0;
  if (ns_hl_fast > 0) {
    ns = ns_hl_fast;
  } else if (ns_hl_win >= 0) {
    ns = ns_hl_win;
  } else {
    ns = ns_hl_global;
  }
  if (ns_hl_active == ns) {
    return false;
  }

  ns_hl_active = ns;
  hl_attr_active = highlight_attr;
  if (ns > 0) {
    update_ns_hl(ns);
    NSHlAttr *hl_def = (NSHlAttr *)pmap_get(int)(&ns_hl_attr, ns);
    if (hl_def) {
      hl_attr_active = *hl_def;
    }
  }
  need_highlight_changed = true;
  return true;
}

/// prepare for drawing window `wp` or global elements if NULL
///
/// Note: pum should be drawn in the context of the current window!
bool win_check_ns_hl(win_T *wp)
{
  ns_hl_win = wp ? wp->w_ns_hl : -1;
  return hl_check_ns();
}

/// Get attribute code for a builtin highlight group.
///
/// The final syntax group could be modified by hi-link or 'winhighlight'.
int hl_get_ui_attr(int ns_id, int idx, int final_id, bool optional)
{
  HlAttrs attrs = HLATTRS_INIT;
  bool available = false;

  if (final_id > 0) {
    int syn_attr = syn_ns_id2attr(ns_id, final_id, &optional);
    if (syn_attr > 0) {
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
  }

  if (optional && !available) {
    return 0;
  }
  return get_attr_entry((HlEntry){ .attr = attrs, .kind = kHlUI,
                                   .id1 = idx, .id2 = final_id });
}

void update_window_hl(win_T *wp, bool invalid)
{
  int ns_id = wp->w_ns_hl;

  update_ns_hl(ns_id);
  if (ns_id != wp->w_ns_hl_active || wp->w_ns_hl_attr == NULL) {
    wp->w_ns_hl_active = ns_id;

    wp->w_ns_hl_attr = *(NSHlAttr *)pmap_get(int)(&ns_hl_attr, ns_id);
    if (!wp->w_ns_hl_attr) {
      // No specific highlights, use the defaults.
      wp->w_ns_hl_attr = highlight_attr;
    }
  }

  int *hl_def = wp->w_ns_hl_attr;

  if (!wp->w_hl_needs_update && !invalid) {
    return;
  }
  wp->w_hl_needs_update = false;

  // If a floating window is blending it always have a named
  // wp->w_hl_attr_normal group. HL_ATTR(HLF_NFLOAT) is always named.

  // determine window specific background set in 'winhighlight'
  bool float_win = wp->w_floating && !wp->w_float_config.external;
  if (float_win && hl_def[HLF_NFLOAT] != 0) {
    wp->w_hl_attr_normal = hl_def[HLF_NFLOAT];
  } else if (hl_def[HLF_COUNT] > 0) {
    wp->w_hl_attr_normal = hl_def[HLF_COUNT];
  } else {
    wp->w_hl_attr_normal = float_win ? HL_ATTR(HLF_NFLOAT) : 0;
  }

  // if blend= attribute is not set, 'winblend' value overrides it.
  if (wp->w_floating && wp->w_p_winbl > 0) {
    HlEntry entry = kv_A(attr_entries, wp->w_hl_attr_normal);
    if (entry.attr.hl_blend == -1) {
      entry.attr.hl_blend = (int)wp->w_p_winbl;
      wp->w_hl_attr_normal = get_attr_entry(entry);
    }
  }

  wp->w_float_config.shadow = false;
  if (wp->w_floating && wp->w_float_config.border) {
    for (int i = 0; i < 8; i++) {
      int attr = hl_def[HLF_BORDER];
      if (wp->w_float_config.border_hl_ids[i]) {
        attr = hl_get_ui_attr(ns_id, HLF_BORDER,
                              wp->w_float_config.border_hl_ids[i], false);
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

  // TODO(bfredl): this a bit ad-hoc. move it from highlight ns logic to 'winhl'
  // implementation?
  if (hl_def[HLF_INACTIVE] == 0) {
    wp->w_hl_attr_normalnc = hl_combine_attr(HL_ATTR(HLF_INACTIVE),
                                             wp->w_hl_attr_normal);
  } else {
    wp->w_hl_attr_normalnc = hl_def[HLF_INACTIVE];
  }

  // if blend= attribute is not set, 'winblend' value overrides it.
  if (wp->w_floating && wp->w_p_winbl > 0) {
    HlEntry entry = kv_A(attr_entries, wp->w_hl_attr_normalnc);
    if (entry.attr.hl_blend == -1) {
      entry.attr.hl_blend = (int)wp->w_p_winbl;
      wp->w_hl_attr_normalnc = get_attr_entry(entry);
    }
  }
}

void update_ns_hl(int ns_id)
{
  if (ns_id <= 0) {
    return;
  }
  DecorProvider *p = get_decor_provider(ns_id, true);
  if (p->hl_cached) {
    return;
  }

  NSHlAttr **alloc = (NSHlAttr **)pmap_put_ref(int)(&ns_hl_attr, ns_id, NULL, NULL);
  if (*alloc == NULL) {
    *alloc = xmalloc(sizeof(**alloc));
  }
  int *hl_attrs = **alloc;

  for (int hlf = 0; hlf < HLF_COUNT; hlf++) {
    int id = syn_check_group(hlf_names[hlf], strlen(hlf_names[hlf]));
    bool optional = (hlf == HLF_INACTIVE || hlf == HLF_NFLOAT);
    hl_attrs[hlf] = hl_get_ui_attr(ns_id, hlf, id, optional);
  }

  // NOOOO! You cannot just pretend that "Normal" is just like any other
  // syntax group! It needs at least 10 layers of special casing! Noooooo!
  //
  // haha, tema engine go brrr
  int normality = syn_check_group(S_LEN("Normal"));
  hl_attrs[HLF_COUNT] = hl_get_ui_attr(ns_id, -1, normality, true);

  // hl_get_ui_attr might have invalidated the decor provider
  p = get_decor_provider(ns_id, true);
  p->hl_cached = true;
}

int win_bg_attr(win_T *wp)
{
  if (ns_hl_fast < 0) {
    int local = (wp == curwin) ? wp->w_hl_attr_normal : wp->w_hl_attr_normalnc;
    if (local) {
      return local;
    }
  }

  if (wp == curwin || hl_attr_active[HLF_INACTIVE] == 0) {
    return hl_attr_active[HLF_COUNT];
  } else {
    return hl_attr_active[HLF_INACTIVE];
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
    map_clear(HlEntry, &attr_entry_ids);
    map_clear(int, &combine_attr_entries);
    map_clear(int, &blend_attr_entries);
    map_clear(int, &blendthrough_attr_entries);
    memset(highlight_attr_last, -1, sizeof(highlight_attr_last));
    highlight_attr_set_all();
    highlight_changed();
    screen_invalidate_highlights();
  } else {
    kv_destroy(attr_entries);
    map_destroy(HlEntry, &attr_entry_ids);
    map_destroy(int, &combine_attr_entries);
    map_destroy(int, &blend_attr_entries);
    map_destroy(int, &blendthrough_attr_entries);
    map_destroy(ColorKey, &ns_hls);
  }
}

void hl_invalidate_blends(void)
{
  map_clear(int, &blend_attr_entries);
  map_clear(int, &blendthrough_attr_entries);
  highlight_changed();
  update_window_hl(curwin, true);
}

/// Combine HlAttrFlags.
/// The underline attribute in "prim_ae" overrules the one in "char_ae" if both are present.
static int16_t hl_combine_ae(int16_t char_ae, int16_t prim_ae)
{
  int16_t char_ul = char_ae & HL_UNDERLINE_MASK;
  int16_t prim_ul = prim_ae & HL_UNDERLINE_MASK;
  int16_t new_ul = prim_ul ? prim_ul : char_ul;
  return (char_ae & ~HL_UNDERLINE_MASK) | (prim_ae & ~HL_UNDERLINE_MASK) | new_ul;
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
  HlAttrs prim_aep = syn_attr2entry(prim_attr);

  // start with low-priority attribute, and override colors if present below.
  HlAttrs new_en = char_aep;

  if (prim_aep.cterm_ae_attr & HL_NOCOMBINE) {
    new_en.cterm_ae_attr = prim_aep.cterm_ae_attr;
  } else {
    new_en.cterm_ae_attr = hl_combine_ae(new_en.cterm_ae_attr, prim_aep.cterm_ae_attr);
  }
  if (prim_aep.rgb_ae_attr & HL_NOCOMBINE) {
    new_en.rgb_ae_attr = prim_aep.rgb_ae_attr;
  } else {
    new_en.rgb_ae_attr = hl_combine_ae(new_en.rgb_ae_attr, prim_aep.rgb_ae_attr);
  }

  if (prim_aep.cterm_fg_color > 0) {
    new_en.cterm_fg_color = prim_aep.cterm_fg_color;
    new_en.rgb_ae_attr &= ((~HL_FG_INDEXED)
                           | (prim_aep.rgb_ae_attr & HL_FG_INDEXED));
  }

  if (prim_aep.cterm_bg_color > 0) {
    new_en.cterm_bg_color = prim_aep.cterm_bg_color;
    new_en.rgb_ae_attr &= ((~HL_BG_INDEXED)
                           | (prim_aep.rgb_ae_attr & HL_BG_INDEXED));
  }

  if (prim_aep.rgb_fg_color >= 0) {
    new_en.rgb_fg_color = prim_aep.rgb_fg_color;
    new_en.rgb_ae_attr &= ((~HL_FG_INDEXED)
                           | (prim_aep.rgb_ae_attr & HL_FG_INDEXED));
  }

  if (prim_aep.rgb_bg_color >= 0) {
    new_en.rgb_bg_color = prim_aep.rgb_bg_color;
    new_en.rgb_ae_attr &= ((~HL_BG_INDEXED)
                           | (prim_aep.rgb_ae_attr & HL_BG_INDEXED));
  }

  if (prim_aep.rgb_sp_color >= 0) {
    new_en.rgb_sp_color = prim_aep.rgb_sp_color;
  }

  if (prim_aep.hl_blend >= 0) {
    new_en.hl_blend = prim_aep.hl_blend;
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
    if (cattrs.rgb_ae_attr & (HL_UNDERLINE_MASK)) {
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
      cattrs.rgb_ae_attr = hl_combine_ae(battrs.rgb_ae_attr, cattrs.rgb_ae_attr);
    }
    cattrs.rgb_fg_color = rgb_blend(ratio/2, battrs.rgb_fg_color,
                                    fattrs.rgb_fg_color);
    if (cattrs.rgb_ae_attr & (HL_UNDERLINE_MASK)) {
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
  int a = ratio, b = 100 - ratio;
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
  static uint8_t ansi_table[16][4] = {
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
Dictionary hl_get_attr_by_id(Integer attr_id, Boolean rgb, Arena *arena, Error *err)
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
  Dictionary retval = arena_dict(arena, HLATTRS_DICT_SIZE);
  hlattrs2dict(&retval, NULL, syn_attr2entry((int)attr_id), rgb, false);
  return retval;
}

/// Converts an HlAttrs into Dictionary
///
/// @param[in/out] hl Dictionary with pre-allocated space for HLATTRS_DICT_SIZE elements
/// @param[in] aep data to convert
/// @param use_rgb use 'gui*' settings if true, else resorts to 'cterm*'
/// @param short_keys change (foreground, background, special) to (fg, bg, sp) for 'gui*' settings
///                          (foreground, background) to (ctermfg, ctermbg) for 'cterm*' settings
void hlattrs2dict(Dictionary *hl, Dictionary *hl_attrs, HlAttrs ae, bool use_rgb, bool short_keys)
{
  hl_attrs = hl_attrs ? hl_attrs : hl;
  assert(hl->capacity >= HLATTRS_DICT_SIZE);  // at most 16 items
  assert(hl_attrs->capacity >= HLATTRS_DICT_SIZE);  // at most 16 items
  int mask  = use_rgb ? ae.rgb_ae_attr : ae.cterm_ae_attr;

  if (mask & HL_INVERSE) {
    PUT_C(*hl_attrs, "reverse", BOOLEAN_OBJ(true));
  }

  if (mask & HL_BOLD) {
    PUT_C(*hl_attrs, "bold", BOOLEAN_OBJ(true));
  }

  if (mask & HL_ITALIC) {
    PUT_C(*hl_attrs, "italic", BOOLEAN_OBJ(true));
  }

  switch (mask & HL_UNDERLINE_MASK) {
  case HL_UNDERLINE:
    PUT_C(*hl_attrs, "underline", BOOLEAN_OBJ(true));
    break;

  case HL_UNDERCURL:
    PUT_C(*hl_attrs, "undercurl", BOOLEAN_OBJ(true));
    break;

  case HL_UNDERDOUBLE:
    PUT_C(*hl_attrs, "underdouble", BOOLEAN_OBJ(true));
    break;

  case HL_UNDERDOTTED:
    PUT_C(*hl_attrs, "underdotted", BOOLEAN_OBJ(true));
    break;

  case HL_UNDERDASHED:
    PUT_C(*hl_attrs, "underdashed", BOOLEAN_OBJ(true));
    break;
  }

  if (mask & HL_STANDOUT) {
    PUT_C(*hl_attrs, "standout", BOOLEAN_OBJ(true));
  }

  if (mask & HL_STRIKETHROUGH) {
    PUT_C(*hl_attrs, "strikethrough", BOOLEAN_OBJ(true));
  }

  if (mask & HL_ALTFONT) {
    PUT_C(*hl_attrs, "altfont", BOOLEAN_OBJ(true));
  }

  if (mask & HL_NOCOMBINE) {
    PUT_C(*hl_attrs, "nocombine", BOOLEAN_OBJ(true));
  }

  if (use_rgb) {
    if (ae.rgb_fg_color != -1) {
      PUT_C(*hl, short_keys ? "fg" : "foreground", INTEGER_OBJ(ae.rgb_fg_color));
    }

    if (ae.rgb_bg_color != -1) {
      PUT_C(*hl, short_keys ? "bg" : "background", INTEGER_OBJ(ae.rgb_bg_color));
    }

    if (ae.rgb_sp_color != -1) {
      PUT_C(*hl, short_keys ? "sp" : "special", INTEGER_OBJ(ae.rgb_sp_color));
    }

    if (!short_keys) {
      if (mask & HL_FG_INDEXED) {
        PUT_C(*hl, "fg_indexed", BOOLEAN_OBJ(true));
      }

      if (mask & HL_BG_INDEXED) {
        PUT_C(*hl, "bg_indexed", BOOLEAN_OBJ(true));
      }
    }
  } else {
    if (ae.cterm_fg_color != 0) {
      PUT_C(*hl, short_keys ? "ctermfg" : "foreground", INTEGER_OBJ(ae.cterm_fg_color - 1));
    }

    if (ae.cterm_bg_color != 0) {
      PUT_C(*hl, short_keys ? "ctermbg" : "background", INTEGER_OBJ(ae.cterm_bg_color - 1));
    }
  }

  if (ae.hl_blend > -1 && (use_rgb || !short_keys)) {
    PUT_C(*hl, "blend", INTEGER_OBJ(ae.hl_blend));
  }
}

HlAttrs dict2hlattrs(Dict(highlight) *dict, bool use_rgb, int *link_id, Error *err)
{
  HlAttrs hlattrs = HLATTRS_INIT;
  int32_t fg = -1, bg = -1, ctermfg = -1, ctermbg = -1, sp = -1;
  int blend = -1;
  int16_t mask = 0;
  int16_t cterm_mask = 0;
  bool cterm_mask_provided = false;

#define CHECK_FLAG(d, m, name, extra, flag) \
  if (api_object_to_bool(d->name##extra, #name, false, err)) { \
    if (flag & HL_UNDERLINE_MASK) { \
      m &= ~HL_UNDERLINE_MASK; \
    } \
    m |= flag; \
  }

  CHECK_FLAG(dict, mask, reverse, , HL_INVERSE);
  CHECK_FLAG(dict, mask, bold, , HL_BOLD);
  CHECK_FLAG(dict, mask, italic, , HL_ITALIC);
  CHECK_FLAG(dict, mask, underline, , HL_UNDERLINE);
  CHECK_FLAG(dict, mask, undercurl, , HL_UNDERCURL);
  CHECK_FLAG(dict, mask, underdouble, , HL_UNDERDOUBLE);
  CHECK_FLAG(dict, mask, underdotted, , HL_UNDERDOTTED);
  CHECK_FLAG(dict, mask, underdashed, , HL_UNDERDASHED);
  CHECK_FLAG(dict, mask, standout, , HL_STANDOUT);
  CHECK_FLAG(dict, mask, strikethrough, , HL_STRIKETHROUGH);
  CHECK_FLAG(dict, mask, altfont, , HL_ALTFONT);
  if (use_rgb) {
    CHECK_FLAG(dict, mask, fg_indexed, , HL_FG_INDEXED);
    CHECK_FLAG(dict, mask, bg_indexed, , HL_BG_INDEXED);
  }
  CHECK_FLAG(dict, mask, nocombine, , HL_NOCOMBINE);
  CHECK_FLAG(dict, mask, default, _, HL_DEFAULT);

  if (HAS_KEY(dict->fg)) {
    fg = object_to_color(dict->fg, "fg", use_rgb, err);
  } else if (HAS_KEY(dict->foreground)) {
    fg = object_to_color(dict->foreground, "foreground", use_rgb, err);
  }
  if (ERROR_SET(err)) {
    return hlattrs;
  }

  if (HAS_KEY(dict->bg)) {
    bg = object_to_color(dict->bg, "bg", use_rgb, err);
  } else if (HAS_KEY(dict->background)) {
    bg = object_to_color(dict->background, "background", use_rgb, err);
  }
  if (ERROR_SET(err)) {
    return hlattrs;
  }

  if (HAS_KEY(dict->sp)) {
    sp = object_to_color(dict->sp, "sp", true, err);
  } else if (HAS_KEY(dict->special)) {
    sp = object_to_color(dict->special, "special", true, err);
  }
  if (ERROR_SET(err)) {
    return hlattrs;
  }

  if (HAS_KEY(dict->blend)) {
    VALIDATE_T("blend", kObjectTypeInteger, dict->blend.type, {
      return hlattrs;
    });

    Integer blend0 = dict->blend.data.integer;
    VALIDATE_RANGE((blend0 >= 0 && blend0 <= 100), "blend", {
      return hlattrs;
    });
    blend = (int)blend0;
  }

  if (HAS_KEY(dict->link) || HAS_KEY(dict->global_link)) {
    if (!link_id) {
      api_set_error(err, kErrorTypeValidation, "Invalid Key: '%s'",
                    HAS_KEY(dict->global_link) ? "global_link" : "link");
      return hlattrs;
    }
    if (HAS_KEY(dict->global_link)) {
      *link_id = object_to_hl_id(dict->global_link, "link", err);
      mask |= HL_GLOBAL;
    } else {
      *link_id = object_to_hl_id(dict->link, "link", err);
    }

    if (ERROR_SET(err)) {
      return hlattrs;
    }
  }

  // Handle cterm attrs
  if (dict->cterm.type == kObjectTypeDictionary) {
    Dict(highlight_cterm) cterm[1] = { 0 };
    if (!api_dict_to_keydict(cterm, KeyDict_highlight_cterm_get_field,
                             dict->cterm.data.dictionary, err)) {
      return hlattrs;
    }

    cterm_mask_provided = true;
    CHECK_FLAG(cterm, cterm_mask, reverse, , HL_INVERSE);
    CHECK_FLAG(cterm, cterm_mask, bold, , HL_BOLD);
    CHECK_FLAG(cterm, cterm_mask, italic, , HL_ITALIC);
    CHECK_FLAG(cterm, cterm_mask, underline, , HL_UNDERLINE);
    CHECK_FLAG(cterm, cterm_mask, undercurl, , HL_UNDERCURL);
    CHECK_FLAG(cterm, cterm_mask, standout, , HL_STANDOUT);
    CHECK_FLAG(cterm, cterm_mask, strikethrough, , HL_STRIKETHROUGH);
    CHECK_FLAG(cterm, cterm_mask, altfont, , HL_ALTFONT);
    CHECK_FLAG(cterm, cterm_mask, nocombine, , HL_NOCOMBINE);
  } else if (dict->cterm.type == kObjectTypeArray && dict->cterm.data.array.size == 0) {
    // empty list from Lua API should clear all cterm attributes
    // TODO(clason): handle via gen_api_dispatch
    cterm_mask_provided = true;
  } else if (HAS_KEY(dict->cterm)) {
    VALIDATE_EXP(false, "cterm", "Dict", api_typename(dict->cterm.type), {
      return hlattrs;
    });
  }
#undef CHECK_FLAG

  if (HAS_KEY(dict->ctermfg)) {
    ctermfg = object_to_color(dict->ctermfg, "ctermfg", false, err);
    if (ERROR_SET(err)) {
      return hlattrs;
    }
  }

  if (HAS_KEY(dict->ctermbg)) {
    ctermbg = object_to_color(dict->ctermbg, "ctermbg", false, err);
    if (ERROR_SET(err)) {
      return hlattrs;
    }
  }

  if (use_rgb) {
    // apply gui mask as default for cterm mask
    if (!cterm_mask_provided) {
      cterm_mask = mask;
    }
    hlattrs.rgb_ae_attr = mask;
    hlattrs.rgb_bg_color = bg;
    hlattrs.rgb_fg_color = fg;
    hlattrs.rgb_sp_color = sp;
    hlattrs.hl_blend = blend;
    hlattrs.cterm_bg_color = ctermbg == -1 ? 0 : ctermbg + 1;
    hlattrs.cterm_fg_color = ctermfg == -1 ? 0 : ctermfg + 1;
    hlattrs.cterm_ae_attr = cterm_mask;
  } else {
    hlattrs.cterm_bg_color = bg == -1 ? 0 : bg + 1;
    hlattrs.cterm_fg_color = fg == -1 ? 0 : fg + 1;
    hlattrs.cterm_ae_attr = mask;
  }

  return hlattrs;
}

int object_to_color(Object val, char *key, bool rgb, Error *err)
{
  if (val.type == kObjectTypeInteger) {
    return (int)val.data.integer;
  } else if (val.type == kObjectTypeString) {
    String str = val.data.string;
    // TODO(bfredl): be more fancy with "bg", "fg" etc
    if (!str.size || STRICMP(str.data, "NONE") == 0) {
      return -1;
    }
    int color;
    if (rgb) {
      int dummy;
      color = name_to_color(str.data, &dummy);
    } else {
      color = name_to_ctermcolor(str.data);
    }
    VALIDATE_S((color >= 0), "highlight color", str.data, {
      return color;
    });
    return color;
  } else {
    VALIDATE_EXP(false, key, "String or Integer", NULL, {
      return 0;
    });
  }
}

Array hl_inspect(int attr)
{
  // TODO(bfredl): use arena allocation
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
    PUT(item, "kind", CSTR_TO_OBJ("syntax"));
    PUT(item, "hi_name",
        CSTR_TO_OBJ(syn_id2name(e.id1)));
    break;

  case kHlUI:
    PUT(item, "kind", CSTR_TO_OBJ("ui"));
    const char *ui_name = (e.id1 == -1) ? "Normal" : hlf_names[e.id1];
    PUT(item, "ui_name", CSTR_TO_OBJ(ui_name));
    PUT(item, "hi_name",
        CSTR_TO_OBJ(syn_id2name(e.id2)));
    break;

  case kHlTerminal:
    PUT(item, "kind", CSTR_TO_OBJ("term"));
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
