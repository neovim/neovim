#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor_shape.h"
#include "nvim/ex_getln.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight_group.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/mouse.h"
#include "nvim/option_vars.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/ui.h"

#include "cursor_shape.c.generated.h"

static const char e_digit_expected[] = N_("E548: Digit expected");

/// Handling of cursor and mouse pointer shapes in various modes.
cursorentry_T shape_table[SHAPE_IDX_COUNT] = {
  // Values are set by 'guicursor' and 'mouseshape'.
  // Adjust the SHAPE_IDX_ defines when changing this!
  { "normal", 0, NULL, 0, 700, 400, 250, 0, 0, "n", SHAPE_CURSOR + SHAPE_MOUSE },
  { "visual", 0, NULL, 0, 700, 400, 250, 0, 0, "v", SHAPE_CURSOR + SHAPE_MOUSE },
  { "insert", 0, NULL, 0, 700, 400, 250, 0, 0, "i", SHAPE_CURSOR + SHAPE_MOUSE },
  { "replace", 0, NULL, 0, 700, 400, 250, 0, 0, "r", SHAPE_CURSOR + SHAPE_MOUSE },
  { "cmdline_normal", 0, NULL, 0, 700, 400, 250, 0, 0, "c", SHAPE_CURSOR + SHAPE_MOUSE },
  { "cmdline_insert", 0, NULL, 0, 700, 400, 250, 0, 0, "ci", SHAPE_CURSOR + SHAPE_MOUSE },
  { "cmdline_replace", 0, NULL, 0, 700, 400, 250, 0, 0, "cr",
    SHAPE_CURSOR + SHAPE_MOUSE },
  { "operator", 0, NULL, 0, 700, 400, 250, 0, 0, "o", SHAPE_CURSOR + SHAPE_MOUSE },
  { "visual_select", 0, NULL, 0, 700, 400, 250, 0, 0, "ve", SHAPE_CURSOR + SHAPE_MOUSE },
  { "cmdline_hover", 0, NULL, 0,   0,   0,   0, 0, 0, "e", SHAPE_MOUSE },
  { "statusline_hover", 0, NULL, 0,   0,   0,   0, 0, 0, "s", SHAPE_MOUSE },
  { "statusline_drag", 0, NULL, 0,   0,   0,   0, 0, 0, "sd", SHAPE_MOUSE },
  { "vsep_hover", 0, NULL, 0,   0,   0,   0, 0, 0, "vs", SHAPE_MOUSE },
  { "vsep_drag", 0, NULL, 0,   0,   0,   0, 0, 0, "vd", SHAPE_MOUSE },
  { "more", 0, NULL, 0,   0,   0,   0, 0, 0, "m", SHAPE_MOUSE },
  { "more_lastline", 0, NULL, 0,   0,   0,   0, 0, 0, "ml", SHAPE_MOUSE },
  { "showmatch", 0, NULL, 0, 100, 100, 100, 0, 0, "sm", SHAPE_CURSOR },
  { "terminal", 0, NULL, 0, 0, 0, 0, 0, 0, "t", SHAPE_CURSOR },
  { "hsep_hover", 0, NULL, 0,   0,   0,   0, 0, 0, "hs", SHAPE_MOUSE },
  { "hsep_drag", 0, NULL, 0,   0,   0,   0, 0, 0, "hd", SHAPE_MOUSE },
};

/// Converts cursor_shapes into an Array of Dictionaries
/// @param arena initialized arena where memory will be allocated
///
/// @return Array of the form {[ "cursor_shape": ... ], ...}
Array mode_style_array(Arena *arena)
{
  Array all = arena_array(arena, SHAPE_IDX_COUNT);

  for (int i = 0; i < SHAPE_IDX_COUNT; i++) {
    cursorentry_T *cur = &shape_table[i];
    Dict dic = arena_dict(arena, 4 + ((cur->used_for & SHAPE_CURSOR) ? 9 : 0));
    PUT_C(dic, "name", CSTR_AS_OBJ(cur->full_name));
    PUT_C(dic, "short_name", CSTR_AS_OBJ(cur->name));
    PUT_C(dic, "used_for", INTEGER_OBJ(cur->used_for));
    if (cur->used_for & SHAPE_MOUSE) {
      PUT_C(dic, "mouse_shape", CSTR_AS_OBJ(cur->mshape));
    }
    if (cur->used_for & SHAPE_CURSOR) {
      String shape_str;
      switch (cur->shape) {
      case SHAPE_BLOCK:
        shape_str = cstr_as_string("block"); break;
      case SHAPE_VER:
        shape_str = cstr_as_string("vertical"); break;
      case SHAPE_HOR:
        shape_str = cstr_as_string("horizontal"); break;
      default:
        shape_str = cstr_as_string("unknown");
      }
      PUT_C(dic, "cursor_shape", STRING_OBJ(shape_str));
      PUT_C(dic, "cell_percentage", INTEGER_OBJ(cur->percentage));
      PUT_C(dic, "blinkwait", INTEGER_OBJ(cur->blinkwait));
      PUT_C(dic, "blinkon", INTEGER_OBJ(cur->blinkon));
      PUT_C(dic, "blinkoff", INTEGER_OBJ(cur->blinkoff));
      PUT_C(dic, "hl_id", INTEGER_OBJ(cur->id));
      PUT_C(dic, "id_lm", INTEGER_OBJ(cur->id_lm));
      PUT_C(dic, "attr_id", INTEGER_OBJ(cur->id ? syn_id2attr(cur->id) : 0));
      PUT_C(dic, "attr_id_lm", INTEGER_OBJ(cur->id_lm ? syn_id2attr(cur->id_lm) : 0));
    }

    ADD_C(all, DICT_OBJ(dic));
  }

  return all;
}

/// Parses the 'guicursor' option.
///
/// Clears `shape_table` if 'guicursor' is empty.
///
/// @param what SHAPE_CURSOR or SHAPE_MOUSE ('mouseshape')
///
/// @returns error message for an illegal option, NULL otherwise.
const char *parse_shape_opt(int what)
{
  char *p = NULL;
  int idx = 0;                          // init for GCC
  int len;
  bool found_ve = false;                 // found "ve" flag

  // Get the appropriate option string based on what we're parsing
  char *option_str = (what == SHAPE_MOUSE) ? p_mouseshape : p_guicursor;

  // First round: check for errors; second round: do it for real.
  for (int round = 1; round <= 2; round++) {
    if (round == 2 || *option_str == NUL) {
      // Set all entries to default (block, blinkon0, default color).
      // This is the default for anything that is not set.
      if (what == SHAPE_CURSOR) {
        clear_shape_table_for_cursor();
      } else {
        clear_shape_table_for_mouse();
      }
      if (*option_str == NUL) {
        ui_mode_info_set();
        return NULL;
      }
    }
    // Repeat for all comma separated parts.
    char *modep = option_str;
    while (modep != NULL && *modep != NUL) {
      char *colonp = vim_strchr(modep, ':');
      char *commap = vim_strchr(modep, ',');

      if (colonp == NULL || (commap != NULL && commap < colonp)) {
        return N_("E545: Missing colon");
      }
      if (colonp == modep) {
        return N_("E546: Illegal mode");
      }

      // Repeat for all modes before the colon.
      // For the 'a' mode, we loop to handle all the modes.
      int all_idx = -1;
      while (modep < colonp || all_idx >= 0) {
        if (all_idx < 0) {
          // Find the mode
          if (modep[1] == '-' || modep[1] == ':') {
            len = 1;
          } else {
            len = 2;
          }

          if (len == 1 && TOLOWER_ASC(modep[0]) == 'a') {
            all_idx = SHAPE_IDX_COUNT - 1;
          } else {
            for (idx = 0; idx < SHAPE_IDX_COUNT; idx++) {
              if (STRNICMP(modep, shape_table[idx].name, len) == 0) {
                break;
              }
            }
            if (idx == SHAPE_IDX_COUNT
                || (shape_table[idx].used_for & what) == 0) {
              return N_("E546: Illegal mode");
            }
            if (len == 2 && modep[0] == 'v' && modep[1] == 'e') {
              found_ve = true;
            }
          }
          modep += len + 1;
        }

        if (all_idx >= 0) {
          idx = all_idx--;
        }

        // Parse the part after the colon
        for (p = colonp + 1; *p && *p != ',';) {
          if (what == SHAPE_MOUSE) {
            // Parse mouse shape name
            char *endp = vim_strchr(p, ',');
            if (endp == NULL) {
              endp = p + strlen(p);  // last part
            }
            if (round == 2) {
              // Store the mouse shape name
              size_t shape_len = (size_t)(endp - p);
              // Allocate and copy the shape name
              // The TUI will convert Vim name to Kitty name when needed
              xfree(shape_table[idx].mshape);
              shape_table[idx].mshape = xmemdupz(p, shape_len);
            }
            p = endp;
          } else {
            // Parse cursor shape attributes (for guicursor)
            // First handle the ones with a number argument.
            int i = (uint8_t)(*p);
            len = 0;
            if (STRNICMP(p, "ver", 3) == 0) {
              len = 3;
            } else if (STRNICMP(p, "hor", 3) == 0) {
              len = 3;
            } else if (STRNICMP(p, "blinkwait", 9) == 0) {
              len = 9;
            } else if (STRNICMP(p, "blinkon", 7) == 0) {
              len = 7;
            } else if (STRNICMP(p, "blinkoff", 8) == 0) {
              len = 8;
            }
            if (len != 0) {
              p += len;
              if (!ascii_isdigit(*p)) {
                return e_digit_expected;
              }
              int n = getdigits_int(&p, false, 0);
              if (len == 3) {               // "ver" or "hor"
                if (n == 0) {
                  return N_("E549: Illegal percentage");
                }
                if (round == 2) {
                  if (TOLOWER_ASC(i) == 'v') {
                    shape_table[idx].shape = SHAPE_VER;
                  } else {
                    shape_table[idx].shape = SHAPE_HOR;
                  }
                  shape_table[idx].percentage = n;
                }
              } else if (round == 2) {
                if (len == 9) {
                  shape_table[idx].blinkwait = n;
                } else if (len == 7) {
                  shape_table[idx].blinkon = n;
                } else {
                  shape_table[idx].blinkoff = n;
                }
              }
            } else if (STRNICMP(p, "block", 5) == 0) {
              if (round == 2) {
                shape_table[idx].shape = SHAPE_BLOCK;
              }
              p += 5;
            } else {          // must be a highlight group name then
              char *endp = vim_strchr(p, '-');
              if (commap == NULL) {                       // last part
                if (endp == NULL) {
                  endp = p + strlen(p);                  // find end of part
                }
              } else if (endp > commap || endp == NULL) {
                endp = commap;
              }
              char *slashp = vim_strchr(p, '/');
              if (slashp != NULL && slashp < endp) {
                // "group/langmap_group"
                i = syn_check_group(p, (size_t)(slashp - p));
                p = slashp + 1;
              }
              if (round == 2) {
                shape_table[idx].id = syn_check_group(p, (size_t)(endp - p));
                shape_table[idx].id_lm = shape_table[idx].id;
                if (slashp != NULL && slashp < endp) {
                  shape_table[idx].id = i;
                }
              }
              p = endp;
            }
          }

          if (*p == '-') {
            p++;
          }
        }
      }
      modep = p;
      if (modep != NULL && *modep == ',') {
        modep++;
      }
    }
  }

  // If the 's' flag is not given, use the 'v' cursor for 's'
  // Only applies to SHAPE_CURSOR (guicursor)
  if (what == SHAPE_CURSOR && !found_ve) {
    {
      shape_table[SHAPE_IDX_VE].shape = shape_table[SHAPE_IDX_V].shape;
      shape_table[SHAPE_IDX_VE].percentage =
        shape_table[SHAPE_IDX_V].percentage;
      shape_table[SHAPE_IDX_VE].blinkwait =
        shape_table[SHAPE_IDX_V].blinkwait;
      shape_table[SHAPE_IDX_VE].blinkon =
        shape_table[SHAPE_IDX_V].blinkon;
      shape_table[SHAPE_IDX_VE].blinkoff =
        shape_table[SHAPE_IDX_V].blinkoff;
      shape_table[SHAPE_IDX_VE].id = shape_table[SHAPE_IDX_V].id;
      shape_table[SHAPE_IDX_VE].id_lm = shape_table[SHAPE_IDX_V].id_lm;
    }
  }
  ui_mode_info_set();
  return NULL;
}

/// Returns true if the cursor is non-blinking "block" shape during
/// visual selection.
///
/// @param exclusive If 'selection' option is "exclusive".
bool cursor_is_block_during_visual(bool exclusive)
  FUNC_ATTR_PURE
{
  int mode_idx = exclusive ? SHAPE_IDX_VE : SHAPE_IDX_V;
  return (SHAPE_BLOCK == shape_table[mode_idx].shape
          && 0 == shape_table[mode_idx].blinkon);
}

/// Map cursor mode from string to integer
///
/// @param mode Fullname of the mode whose id we are looking for
/// @return -1 in case of failure, else the matching SHAPE_ID* integer
int cursor_mode_str2int(const char *mode)
{
  for (int mode_idx = 0; mode_idx < SHAPE_IDX_COUNT; mode_idx++) {
    if (strcmp(shape_table[mode_idx].full_name, mode) == 0) {
      return mode_idx;
    }
  }
  WLOG("Unknown mode %s", mode);
  return -1;
}

/// Check if a syntax id is used as a cursor style.
bool cursor_mode_uses_syn_id(int syn_id)
  FUNC_ATTR_PURE
{
  if (*p_guicursor == NUL) {
    return false;
  }
  for (int mode_idx = 0; mode_idx < SHAPE_IDX_COUNT; mode_idx++) {
    if (shape_table[mode_idx].id == syn_id
        || shape_table[mode_idx].id_lm == syn_id) {
      return true;
    }
  }
  return false;
}

/// Return the index into shape_table[] for the current mode.
int cursor_get_mode_idx(bool with_mouse)
  FUNC_ATTR_PURE
{
  if (with_mouse && p_mousemev) {
    pos_T m_pos = { 0 };
    int mpos_flag = get_fpos_of_mouse(&m_pos);
    if (mpos_flag & IN_STATUS_LINE) {
      return is_dragging() ? SHAPE_IDX_SDRAG : SHAPE_IDX_STATUS;
    }
    if (mpos_flag & IN_HSEP_LINE) {
      return is_dragging() ? SHAPE_IDX_HDRAG : SHAPE_IDX_HSEP;
    }
    if (mpos_flag & IN_SEP_LINE) {
      return is_dragging() ? SHAPE_IDX_VDRAG : SHAPE_IDX_VSEP;
    }
  }
  if (State == MODE_SHOWMATCH) {
    return SHAPE_IDX_SM;
  } else if (State == MODE_TERMINAL) {
    return SHAPE_IDX_TERM;
  } else if (State & VREPLACE_FLAG) {
    return SHAPE_IDX_R;
  } else if (State & REPLACE_FLAG) {
    return SHAPE_IDX_R;
  } else if (State & MODE_INSERT) {
    return SHAPE_IDX_I;
  } else if (State & MODE_CMDLINE) {
    if (cmdline_at_end()) {
      return SHAPE_IDX_C;
    } else if (cmdline_overstrike()) {
      return SHAPE_IDX_CR;
    } else {
      return SHAPE_IDX_CI;
    }
  } else if (finish_op) {
    return SHAPE_IDX_O;
  } else if (VIsual_active) {
    if (*p_sel == 'e') {
      return SHAPE_IDX_VE;
    } else {
      return SHAPE_IDX_V;
    }
  } else {
    return SHAPE_IDX_N;
  }
}

/// Clears all entries in shape_table to block, blinkon0, and default color.
static void clear_shape_table_for_cursor(void)
{
  for (int idx = 0; idx < SHAPE_IDX_COUNT; idx++) {
    shape_table[idx].shape = SHAPE_BLOCK;
    shape_table[idx].blinkwait = 0;
    shape_table[idx].blinkon = 0;
    shape_table[idx].blinkoff = 0;
    shape_table[idx].id = 0;
    shape_table[idx].id_lm = 0;
  }
}

static void clear_shape_table_for_mouse(void)
{
  for (int idx = 0; idx < SHAPE_IDX_COUNT; idx++) {
    xfree(shape_table[idx].mshape);
    shape_table[idx].mshape = NULL;
  }
}

/// Convert legacy Vim mouseshape names to their Kitty pointer shape name equivalents.
///
/// If no equivalent exists, the Vim name is stored but "default" is returned for terminal output.
/// See https://github.com/mirror/libX11/blob/master/include/X11/cursorfont.h
///
/// @param vim_shape  mouseshape name from options
/// @return  Kitty pointer shape name suitable for OSC 22 sequence
const char *mshape_get_kitty_name(const char *vim_shape)
{
  if (vim_shape == NULL) {
    return MSHAPE_DEFAULT;
  }

  // First check if it's already a valid Kitty shape name (pass through)
  if (strequal(vim_shape, MSHAPE_ALIAS)) {
    return MSHAPE_ALIAS;
  } else if (strequal(vim_shape, MSHAPE_CELL)) {
    return MSHAPE_CELL;
  } else if (strequal(vim_shape, MSHAPE_COPY)) {
    return MSHAPE_COPY;
  } else if (strequal(vim_shape, MSHAPE_CROSSHAIR)) {
    return MSHAPE_CROSSHAIR;
  } else if (strequal(vim_shape, MSHAPE_DEFAULT)) {
    return MSHAPE_DEFAULT;
  } else if (strequal(vim_shape, MSHAPE_E_RESIZE)) {
    return MSHAPE_E_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_EW_RESIZE)) {
    return MSHAPE_EW_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_GRAB)) {
    return MSHAPE_GRAB;
  } else if (strequal(vim_shape, MSHAPE_GRABBING)) {
    return MSHAPE_GRABBING;
  } else if (strequal(vim_shape, MSHAPE_HELP)) {
    return MSHAPE_HELP;
  } else if (strequal(vim_shape, MSHAPE_MOVE)) {
    return MSHAPE_MOVE;
  } else if (strequal(vim_shape, MSHAPE_N_RESIZE)) {
    return MSHAPE_N_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_NE_RESIZE)) {
    return MSHAPE_NE_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_NESW_RESIZE)) {
    return MSHAPE_NESW_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_NO_DROP)) {
    return MSHAPE_NO_DROP;
  } else if (strequal(vim_shape, MSHAPE_NOT_ALLOWED)) {
    return MSHAPE_NOT_ALLOWED;
  } else if (strequal(vim_shape, MSHAPE_NS_RESIZE)) {
    return MSHAPE_NS_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_NW_RESIZE)) {
    return MSHAPE_NW_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_NWSE_RESIZE)) {
    return MSHAPE_NWSE_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_POINTER)) {
    return MSHAPE_POINTER;
  } else if (strequal(vim_shape, MSHAPE_PROGRESS)) {
    return MSHAPE_PROGRESS;
  } else if (strequal(vim_shape, MSHAPE_S_RESIZE)) {
    return MSHAPE_S_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_SE_RESIZE)) {
    return MSHAPE_SE_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_SW_RESIZE)) {
    return MSHAPE_SW_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_TEXT)) {
    return MSHAPE_TEXT;
  } else if (strequal(vim_shape, MSHAPE_VERTICAL_TEXT)) {
    return MSHAPE_VERTICAL_TEXT;
  } else if (strequal(vim_shape, MSHAPE_W_RESIZE)) {
    return MSHAPE_W_RESIZE;
  } else if (strequal(vim_shape, MSHAPE_WAIT)) {
    return MSHAPE_WAIT;
  } else if (strequal(vim_shape, MSHAPE_ZOOM_IN)) {
    return MSHAPE_ZOOM_IN;
  } else if (strequal(vim_shape, MSHAPE_ZOOM_OUT)) {
    return MSHAPE_ZOOM_OUT;
  }

  // Handle legacy Vim shape names
  if (strequal(vim_shape, "arrow")) {
    return MSHAPE_DEFAULT;
  } else if (strequal(vim_shape, "beam")) {
    return MSHAPE_TEXT;
  } else if (strequal(vim_shape, "updown") || strequal(vim_shape, "udsizing")) {
    return MSHAPE_NS_RESIZE;
  } else if (strequal(vim_shape, "leftright") || strequal(vim_shape, "lrsizing")) {
    return MSHAPE_EW_RESIZE;
  } else if (strequal(vim_shape, "busy")) {
    return MSHAPE_WAIT;
  } else if (strequal(vim_shape, "no")) {
    return MSHAPE_NOT_ALLOWED;
  } else if (strequal(vim_shape, "hand1") || strequal(vim_shape, "hand2")) {
    return MSHAPE_POINTER;
  } else if (strequal(vim_shape, "question")) {
    return MSHAPE_HELP;
  } else if (strequal(vim_shape, "rightup-arrow")) {
    return MSHAPE_NE_RESIZE;
  } else if (strequal(vim_shape, "up-arrow")) {
    return MSHAPE_N_RESIZE;
  }

  // Handle numeric X11 cursor codes
  for (const char *p = vim_shape; *p; p++) {
    if (!ascii_isdigit(*p)) {
      // Not a number, return default
      return MSHAPE_DEFAULT;
    }
  }
  int number = atoi(vim_shape);

  switch (number) {
  case 32:   // cross-reverse
  case 34:   // crosshair
  case 130:  // tcross
    return MSHAPE_CROSSHAIR;
  case 58:   // hand1
  case 60:   // hand2
    return MSHAPE_POINTER;
  default:
    return MSHAPE_DEFAULT;
  }
}
