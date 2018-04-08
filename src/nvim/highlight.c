// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// highlight.c: low level code for both UI, syntax and :terminal highlighting

#include "nvim/vim.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/map.h"
#include "nvim/screen.h"
#include "nvim/syntax.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "highlight.c.generated.h"
#endif

/// An attribute number is the index in attr_entries plus ATTR_OFF.
#define ATTR_OFF 1

/// Table with the specifications for an attribute number.
/// Note that this table is used by ALL buffers.  This is required because the
/// GUI can redraw at any time for any buffer.
static garray_T attr_table = GA_EMPTY_INIT_VALUE;

static inline HlAttrs * ATTR_ENTRY(int idx)
{
  return &((HlAttrs *)attr_table.ga_data)[idx];
}


/// Return the attr number for a set of colors and font.
/// Add a new entry to the term_attr_table, attr_table or gui_attr_table
/// if the combination is new.
/// @return 0 for error.
int get_attr_entry(HlAttrs *aep)
{
  garray_T *table = &attr_table;
  HlAttrs *taep;
  static int recursive = false;

  /*
   * Init the table, in case it wasn't done yet.
   */
  table->ga_itemsize = sizeof(HlAttrs);
  ga_set_growsize(table, 7);

  // Try to find an entry with the same specifications.
  for (int i = 0; i < table->ga_len; i++) {
    taep = &(((HlAttrs *)table->ga_data)[i]);
    if (aep->cterm_ae_attr == taep->cterm_ae_attr
        && aep->cterm_fg_color == taep->cterm_fg_color
        && aep->cterm_bg_color == taep->cterm_bg_color
        && aep->rgb_ae_attr == taep->rgb_ae_attr
        && aep->rgb_fg_color == taep->rgb_fg_color
        && aep->rgb_bg_color == taep->rgb_bg_color
        && aep->rgb_sp_color == taep->rgb_sp_color) {
      return i + ATTR_OFF;
    }
  }

  if (table->ga_len + ATTR_OFF > MAX_TYPENR) {
    /*
     * Running out of attribute entries!  remove all attributes, and
     * compute new ones for all groups.
     * When called recursively, we are really out of numbers.
     */
    if (recursive) {
      EMSG(_("E424: Too many different highlighting attributes in use"));
      return 0;
    }
    recursive = TRUE;

    clear_hl_tables();

    must_redraw = CLEAR;

    highlight_attr_set_all();

    recursive = FALSE;
  }

  // This is a new combination of colors and font, add an entry.
  taep = GA_APPEND_VIA_PTR(HlAttrs, table);
  memset(taep, 0, sizeof(*taep));
  taep->cterm_ae_attr = aep->cterm_ae_attr;
  taep->cterm_fg_color = aep->cterm_fg_color;
  taep->cterm_bg_color = aep->cterm_bg_color;
  taep->rgb_ae_attr = aep->rgb_ae_attr;
  taep->rgb_fg_color = aep->rgb_fg_color;
  taep->rgb_bg_color = aep->rgb_bg_color;
  taep->rgb_sp_color = aep->rgb_sp_color;

  return table->ga_len - 1 + ATTR_OFF;
}

// Clear all highlight tables.
void clear_hl_tables(void)
{
  ga_clear(&attr_table);
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
  HlAttrs *char_aep = NULL;
  HlAttrs *spell_aep;
  HlAttrs new_en = HLATTRS_INIT;

  if (char_attr == 0) {
    return prim_attr;
  }

  if (prim_attr == 0) {
    return char_attr;
  }

  // Find the entry for char_attr
  char_aep = syn_cterm_attr2entry(char_attr);

  if (char_aep != NULL) {
    // Copy all attributes from char_aep to the new entry
    new_en = *char_aep;
  }

  spell_aep = syn_cterm_attr2entry(prim_attr);
  if (spell_aep != NULL) {
    new_en.cterm_ae_attr |= spell_aep->cterm_ae_attr;
    new_en.rgb_ae_attr |= spell_aep->rgb_ae_attr;

    if (spell_aep->cterm_fg_color > 0) {
      new_en.cterm_fg_color = spell_aep->cterm_fg_color;
    }

    if (spell_aep->cterm_bg_color > 0) {
      new_en.cterm_bg_color = spell_aep->cterm_bg_color;
    }

    if (spell_aep->rgb_fg_color >= 0) {
      new_en.rgb_fg_color = spell_aep->rgb_fg_color;
    }

    if (spell_aep->rgb_bg_color >= 0) {
      new_en.rgb_bg_color = spell_aep->rgb_bg_color;
    }

    if (spell_aep->rgb_sp_color >= 0) {
      new_en.rgb_sp_color = spell_aep->rgb_sp_color;
    }
  }
  return get_attr_entry(&new_en);
}

/// \note this function does not apply exclusively to cterm attr contrary
/// to what its name implies
/// \warn don't call it with attr 0 (i.e., the null attribute)
HlAttrs *syn_cterm_attr2entry(int attr)
{
  attr -= ATTR_OFF;
  if (attr >= attr_table.ga_len) {
    // did ":syntax clear"
    return NULL;
  }
  return ATTR_ENTRY(attr);
}

/// Gets highlight description for id `attr_id` as a map.
Dictionary hl_get_attr_by_id(Integer attr_id, Boolean rgb, Error *err)
{
  HlAttrs *aep = NULL;
  Dictionary dic = ARRAY_DICT_INIT;

  if (attr_id == 0) {
    return dic;
  }

  aep = syn_cterm_attr2entry((int)attr_id);
  if (!aep) {
    api_set_error(err, kErrorTypeException,
                  "Invalid attribute id: %" PRId64, attr_id);
    return dic;
  }

  return hlattrs2dict(aep, rgb);
}

/// Converts an HlAttrs into Dictionary
///
/// @param[in] aep data to convert
/// @param use_rgb use 'gui*' settings if true, else resorts to 'cterm*'
Dictionary hlattrs2dict(const HlAttrs *aep, bool use_rgb)
{
  assert(aep);
  Dictionary hl = ARRAY_DICT_INIT;
  int mask  = use_rgb ? aep->rgb_ae_attr : aep->cterm_ae_attr;

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
    if (aep->rgb_fg_color != -1) {
      PUT(hl, "foreground", INTEGER_OBJ(aep->rgb_fg_color));
    }

    if (aep->rgb_bg_color != -1) {
      PUT(hl, "background", INTEGER_OBJ(aep->rgb_bg_color));
    }

    if (aep->rgb_sp_color != -1) {
      PUT(hl, "special", INTEGER_OBJ(aep->rgb_sp_color));
    }
  } else {
    if (cterm_normal_fg_color != aep->cterm_fg_color) {
      PUT(hl, "foreground", INTEGER_OBJ(aep->cterm_fg_color - 1));
    }

    if (cterm_normal_bg_color != aep->cterm_bg_color) {
      PUT(hl, "background", INTEGER_OBJ(aep->cterm_bg_color - 1));
    }
  }

  return hl;
}

