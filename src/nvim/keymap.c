// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/keymap.h"
#include "nvim/charset.h"
#include "nvim/memory.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/message.h"
#include "nvim/strings.h"
#include "nvim/mouse.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "keymap.c.generated.h"
#endif

/*
 * Some useful tables.
 */

static const struct modmasktable {
  uint16_t mod_mask;  ///< Bit-mask for particular key modifier.
  uint16_t mod_flag;  ///< Bit(s) for particular key modifier.
  char_u name;  ///< Single letter name of modifier.
} mod_mask_table[] = {
  { MOD_MASK_ALT,              MOD_MASK_ALT,           (char_u)'M' },
  { MOD_MASK_META,             MOD_MASK_META,          (char_u)'T' },
  { MOD_MASK_CTRL,             MOD_MASK_CTRL,          (char_u)'C' },
  { MOD_MASK_SHIFT,            MOD_MASK_SHIFT,         (char_u)'S' },
  { MOD_MASK_MULTI_CLICK,      MOD_MASK_2CLICK,        (char_u)'2' },
  { MOD_MASK_MULTI_CLICK,      MOD_MASK_3CLICK,        (char_u)'3' },
  { MOD_MASK_MULTI_CLICK,      MOD_MASK_4CLICK,        (char_u)'4' },
  { MOD_MASK_CMD,              MOD_MASK_CMD,           (char_u)'D' },
  // 'A' must be the last one
  { MOD_MASK_ALT,              MOD_MASK_ALT,           (char_u)'A' },
  { 0, 0, NUL }
  // NOTE: when adding an entry, update MAX_KEY_NAME_LEN!
};

/*
 * Shifted key terminal codes and their unshifted equivalent.
 * Don't add mouse codes here, they are handled separately!
 */
#define MOD_KEYS_ENTRY_SIZE 5

static char_u modifier_keys_table[] =
{
  /*  mod mask	    with modifier		without modifier */
  MOD_MASK_SHIFT, '&', '9',                   '@', '1',         /* begin */
  MOD_MASK_SHIFT, '&', '0',                   '@', '2',         /* cancel */
  MOD_MASK_SHIFT, '*', '1',                   '@', '4',         /* command */
  MOD_MASK_SHIFT, '*', '2',                   '@', '5',         /* copy */
  MOD_MASK_SHIFT, '*', '3',                   '@', '6',         /* create */
  MOD_MASK_SHIFT, '*', '4',                   'k', 'D',         /* delete char */
  MOD_MASK_SHIFT, '*', '5',                   'k', 'L',         /* delete line */
  MOD_MASK_SHIFT, '*', '7',                   '@', '7',         /* end */
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_END,    '@', '7',         /* end */
  MOD_MASK_SHIFT, '*', '9',                   '@', '9',         /* exit */
  MOD_MASK_SHIFT, '*', '0',                   '@', '0',         /* find */
  MOD_MASK_SHIFT, '#', '1',                   '%', '1',         /* help */
  MOD_MASK_SHIFT, '#', '2',                   'k', 'h',         /* home */
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_HOME,   'k', 'h',         /* home */
  MOD_MASK_SHIFT, '#', '3',                   'k', 'I',         /* insert */
  MOD_MASK_SHIFT, '#', '4',                   'k', 'l',         /* left arrow */
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_LEFT,   'k', 'l',         /* left arrow */
  MOD_MASK_SHIFT, '%', 'a',                   '%', '3',         /* message */
  MOD_MASK_SHIFT, '%', 'b',                   '%', '4',         /* move */
  MOD_MASK_SHIFT, '%', 'c',                   '%', '5',         /* next */
  MOD_MASK_SHIFT, '%', 'd',                   '%', '7',         /* options */
  MOD_MASK_SHIFT, '%', 'e',                   '%', '8',         /* previous */
  MOD_MASK_SHIFT, '%', 'f',                   '%', '9',         /* print */
  MOD_MASK_SHIFT, '%', 'g',                   '%', '0',         /* redo */
  MOD_MASK_SHIFT, '%', 'h',                   '&', '3',         /* replace */
  MOD_MASK_SHIFT, '%', 'i',                   'k', 'r',         /* right arr. */
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_RIGHT,  'k', 'r',         /* right arr. */
  MOD_MASK_SHIFT, '%', 'j',                   '&', '5',         /* resume */
  MOD_MASK_SHIFT, '!', '1',                   '&', '6',         /* save */
  MOD_MASK_SHIFT, '!', '2',                   '&', '7',         /* suspend */
  MOD_MASK_SHIFT, '!', '3',                   '&', '8',         /* undo */
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_UP,     'k', 'u',         /* up arrow */
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_DOWN,   'k', 'd',         /* down arrow */

  /* vt100 F1 */
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF1,    KS_EXTRA, (int)KE_XF1,
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF2,    KS_EXTRA, (int)KE_XF2,
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF3,    KS_EXTRA, (int)KE_XF3,
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF4,    KS_EXTRA, (int)KE_XF4,

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F1,     'k', '1',         /* F1 */
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F2,     'k', '2',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F3,     'k', '3',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F4,     'k', '4',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F5,     'k', '5',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F6,     'k', '6',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F7,     'k', '7',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F8,     'k', '8',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F9,     'k', '9',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F10,    'k', ';',         /* F10 */

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F11,    'F', '1',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F12,    'F', '2',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F13,    'F', '3',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F14,    'F', '4',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F15,    'F', '5',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F16,    'F', '6',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F17,    'F', '7',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F18,    'F', '8',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F19,    'F', '9',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F20,    'F', 'A',

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F21,    'F', 'B',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F22,    'F', 'C',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F23,    'F', 'D',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F24,    'F', 'E',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F25,    'F', 'F',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F26,    'F', 'G',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F27,    'F', 'H',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F28,    'F', 'I',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F29,    'F', 'J',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F30,    'F', 'K',

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F31,    'F', 'L',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F32,    'F', 'M',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F33,    'F', 'N',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F34,    'F', 'O',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F35,    'F', 'P',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F36,    'F', 'Q',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F37,    'F', 'R',

  /* TAB pseudo code*/
  MOD_MASK_SHIFT, 'k', 'B',                   KS_EXTRA, (int)KE_TAB,

  NUL
};

static const struct key_name_entry {
  int key;              // Special key code or ascii value
  const char *name;           // Name of key
} key_names_table[] = {
  { ' ',               "Space" },
  { TAB,               "Tab" },
  { K_TAB,             "Tab" },
  { NL,                "NL" },
  { NL,                "NewLine" },     // Alternative name
  { NL,                "LineFeed" },    // Alternative name
  { NL,                "LF" },          // Alternative name
  { CAR,               "CR" },
  { CAR,               "Return" },      // Alternative name
  { CAR,               "Enter" },       // Alternative name
  { K_BS,              "BS" },
  { K_BS,              "BackSpace" },   // Alternative name
  { ESC,               "Esc" },
  { CSI,               "CSI" },
  { K_CSI,             "xCSI" },
  { '|',               "Bar" },
  { '\\',              "Bslash" },
  { K_DEL,             "Del" },
  { K_DEL,             "Delete" },      // Alternative name
  { K_KDEL,            "kDel" },
  { K_KDEL,            "KPPeriod" },    // libtermkey name
  { K_UP,              "Up" },
  { K_DOWN,            "Down" },
  { K_LEFT,            "Left" },
  { K_RIGHT,           "Right" },
  { K_XUP,             "xUp" },
  { K_XDOWN,           "xDown" },
  { K_XLEFT,           "xLeft" },
  { K_XRIGHT,          "xRight" },
  { K_KUP,             "kUp" },
  { K_KUP,             "KP8" },
  { K_KDOWN,           "kDown" },
  { K_KDOWN,           "KP2" },
  { K_KLEFT,           "kLeft" },
  { K_KLEFT,           "KP4" },
  { K_KRIGHT,          "kRight" },
  { K_KRIGHT,          "KP6" },

  { K_F1,              "F1" },
  { K_F2,              "F2" },
  { K_F3,              "F3" },
  { K_F4,              "F4" },
  { K_F5,              "F5" },
  { K_F6,              "F6" },
  { K_F7,              "F7" },
  { K_F8,              "F8" },
  { K_F9,              "F9" },
  { K_F10,             "F10" },

  { K_F11,             "F11" },
  { K_F12,             "F12" },
  { K_F13,             "F13" },
  { K_F14,             "F14" },
  { K_F15,             "F15" },
  { K_F16,             "F16" },
  { K_F17,             "F17" },
  { K_F18,             "F18" },
  { K_F19,             "F19" },
  { K_F20,             "F20" },

  { K_F21,             "F21" },
  { K_F22,             "F22" },
  { K_F23,             "F23" },
  { K_F24,             "F24" },
  { K_F25,             "F25" },
  { K_F26,             "F26" },
  { K_F27,             "F27" },
  { K_F28,             "F28" },
  { K_F29,             "F29" },
  { K_F30,             "F30" },

  { K_F31,             "F31" },
  { K_F32,             "F32" },
  { K_F33,             "F33" },
  { K_F34,             "F34" },
  { K_F35,             "F35" },
  { K_F36,             "F36" },
  { K_F37,             "F37" },

  { K_XF1,             "xF1" },
  { K_XF2,             "xF2" },
  { K_XF3,             "xF3" },
  { K_XF4,             "xF4" },

  { K_HELP,            "Help" },
  { K_UNDO,            "Undo" },
  { K_INS,             "Insert" },
  { K_INS,             "Ins" },         // Alternative name
  { K_KINS,            "kInsert" },
  { K_KINS,            "KP0" },
  { K_HOME,            "Home" },
  { K_KHOME,           "kHome" },
  { K_KHOME,           "KP7" },
  { K_XHOME,           "xHome" },
  { K_ZHOME,           "zHome" },
  { K_END,             "End" },
  { K_KEND,            "kEnd" },
  { K_KEND,            "KP1" },
  { K_XEND,            "xEnd" },
  { K_ZEND,            "zEnd" },
  { K_PAGEUP,          "PageUp" },
  { K_PAGEDOWN,        "PageDown" },
  { K_KPAGEUP,         "kPageUp" },
  { K_KPAGEUP,         "KP9" },
  { K_KPAGEDOWN,       "kPageDown" },
  { K_KPAGEDOWN,       "KP3" },
  { K_KORIGIN,         "kOrigin" },
  { K_KORIGIN,         "KP5" },

  { K_KPLUS,           "kPlus" },
  { K_KPLUS,           "KPPlus" },
  { K_KMINUS,          "kMinus" },
  { K_KMINUS,          "KPMinus" },
  { K_KDIVIDE,         "kDivide" },
  { K_KDIVIDE,         "KPDiv" },
  { K_KMULTIPLY,       "kMultiply" },
  { K_KMULTIPLY,       "KPMult" },
  { K_KENTER,          "kEnter" },
  { K_KENTER,          "KPEnter" },
  { K_KPOINT,          "kPoint" },
  { K_KCOMMA,          "kComma" },
  { K_KCOMMA,          "KPComma" },
  { K_KEQUAL,          "kEqual" },
  { K_KEQUAL,          "KPEquals" },

  { K_K0,              "k0" },
  { K_K1,              "k1" },
  { K_K2,              "k2" },
  { K_K3,              "k3" },
  { K_K4,              "k4" },
  { K_K5,              "k5" },
  { K_K6,              "k6" },
  { K_K7,              "k7" },
  { K_K8,              "k8" },
  { K_K9,              "k9" },

  { '<',               "lt" },

  { K_MOUSE,           "Mouse" },
  { K_LEFTMOUSE,       "LeftMouse" },
  { K_LEFTMOUSE_NM,    "LeftMouseNM" },
  { K_LEFTDRAG,        "LeftDrag" },
  { K_LEFTRELEASE,     "LeftRelease" },
  { K_LEFTRELEASE_NM,  "LeftReleaseNM" },
  { K_MIDDLEMOUSE,     "MiddleMouse" },
  { K_MIDDLEDRAG,      "MiddleDrag" },
  { K_MIDDLERELEASE,   "MiddleRelease" },
  { K_RIGHTMOUSE,      "RightMouse" },
  { K_RIGHTDRAG,       "RightDrag" },
  { K_RIGHTRELEASE,    "RightRelease" },
  { K_MOUSEDOWN,       "ScrollWheelUp" },
  { K_MOUSEUP,         "ScrollWheelDown" },
  { K_MOUSELEFT,       "ScrollWheelRight" },
  { K_MOUSERIGHT,      "ScrollWheelLeft" },
  { K_MOUSEDOWN,       "MouseDown" },   // OBSOLETE: Use
  { K_MOUSEUP,         "MouseUp" },     // ScrollWheelXXX instead
  { K_X1MOUSE,         "X1Mouse" },
  { K_X1DRAG,          "X1Drag" },
  { K_X1RELEASE,       "X1Release" },
  { K_X2MOUSE,         "X2Mouse" },
  { K_X2DRAG,          "X2Drag" },
  { K_X2RELEASE,       "X2Release" },
  { K_DROP,            "Drop" },
  { K_ZERO,            "Nul" },
  { K_SNR,             "SNR" },
  { K_PLUG,            "Plug" },
  { K_COMMAND,         "Cmd" },
  { 0,                 NULL }
  // NOTE: When adding a long name update MAX_KEY_NAME_LEN.
};

static struct mousetable {
  int pseudo_code;              /* Code for pseudo mouse event */
  int button;                   /* Which mouse button is it? */
  int is_click;                 /* Is it a mouse button click event? */
  int is_drag;                  /* Is it a mouse drag event? */
} mouse_table[] =
{
  {(int)KE_LEFTMOUSE,         MOUSE_LEFT,     TRUE,   FALSE},
  {(int)KE_LEFTDRAG,          MOUSE_LEFT,     FALSE,  TRUE},
  {(int)KE_LEFTRELEASE,       MOUSE_LEFT,     FALSE,  FALSE},
  {(int)KE_MIDDLEMOUSE,       MOUSE_MIDDLE,   TRUE,   FALSE},
  {(int)KE_MIDDLEDRAG,        MOUSE_MIDDLE,   FALSE,  TRUE},
  {(int)KE_MIDDLERELEASE,     MOUSE_MIDDLE,   FALSE,  FALSE},
  {(int)KE_RIGHTMOUSE,        MOUSE_RIGHT,    TRUE,   FALSE},
  {(int)KE_RIGHTDRAG,         MOUSE_RIGHT,    FALSE,  TRUE},
  {(int)KE_RIGHTRELEASE,      MOUSE_RIGHT,    FALSE,  FALSE},
  {(int)KE_X1MOUSE,           MOUSE_X1,       TRUE,   FALSE},
  {(int)KE_X1DRAG,            MOUSE_X1,       FALSE,  TRUE},
  {(int)KE_X1RELEASE,         MOUSE_X1,       FALSE,  FALSE},
  {(int)KE_X2MOUSE,           MOUSE_X2,       TRUE,   FALSE},
  {(int)KE_X2DRAG,            MOUSE_X2,       FALSE,  TRUE},
  {(int)KE_X2RELEASE,         MOUSE_X2,       FALSE,  FALSE},
  /* DRAG without CLICK */
  {(int)KE_IGNORE,            MOUSE_RELEASE,  FALSE,  TRUE},
  /* RELEASE without CLICK */
  {(int)KE_IGNORE,            MOUSE_RELEASE,  FALSE,  FALSE},
  {0,                         0,              0,      0},
};

/// Return the modifier mask bit (#MOD_MASK_*) corresponding to mod name
///
/// E.g. 'S' for shift, 'C' for ctrl.
int name_to_mod_mask(int c)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  c = TOUPPER_ASC(c);
  for (size_t i = 0; mod_mask_table[i].mod_mask != 0; i++) {
    if (c == mod_mask_table[i].name) {
      return mod_mask_table[i].mod_flag;
    }
  }
  return 0;
}

/// Check if there is a special key code for "key" with specified modifiers
///
/// @param[in]  key  Initial key code.
/// @param[in,out]  modifiers  Initial modifiers, is adjusted to have simplified
///                            modifiers.
///
/// @return Simplified key code.
int simplify_key(const int key, int *modifiers)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (*modifiers & (MOD_MASK_SHIFT | MOD_MASK_CTRL | MOD_MASK_ALT)) {
    // TAB is a special case.
    if (key == TAB && (*modifiers & MOD_MASK_SHIFT)) {
      *modifiers &= ~MOD_MASK_SHIFT;
      return K_S_TAB;
    }
    const int key0 = KEY2TERMCAP0(key);
    const int key1 = KEY2TERMCAP1(key);
    for (int i = 0; modifier_keys_table[i] != NUL; i += MOD_KEYS_ENTRY_SIZE) {
      if (key0 == modifier_keys_table[i + 3]
          && key1 == modifier_keys_table[i + 4]
          && (*modifiers & modifier_keys_table[i])) {
        *modifiers &= ~modifier_keys_table[i];
        return TERMCAP2KEY(modifier_keys_table[i + 1],
                           modifier_keys_table[i + 2]);
      }
    }
  }
  return key;
}

/// Change <xKey> to <Key>
int handle_x_keys(const int key)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (key) {
    case K_XUP:     return K_UP;
    case K_XDOWN:   return K_DOWN;
    case K_XLEFT:   return K_LEFT;
    case K_XRIGHT:  return K_RIGHT;
    case K_XHOME:   return K_HOME;
    case K_ZHOME:   return K_HOME;
    case K_XEND:    return K_END;
    case K_ZEND:    return K_END;
    case K_XF1:     return K_F1;
    case K_XF2:     return K_F2;
    case K_XF3:     return K_F3;
    case K_XF4:     return K_F4;
    case K_S_XF1:   return K_S_F1;
    case K_S_XF2:   return K_S_F2;
    case K_S_XF3:   return K_S_F3;
    case K_S_XF4:   return K_S_F4;
  }
  return key;
}

/*
 * Return a string which contains the name of the given key when the given
 * modifiers are down.
 */
char_u *get_special_key_name(int c, int modifiers)
{
  static char_u string[MAX_KEY_NAME_LEN + 1];

  int i, idx;
  int table_idx;
  char_u  *s;

  string[0] = '<';
  idx = 1;

  /* Key that stands for a normal character. */
  if (IS_SPECIAL(c) && KEY2TERMCAP0(c) == KS_KEY)
    c = KEY2TERMCAP1(c);

  /*
   * Translate shifted special keys into unshifted keys and set modifier.
   * Same for CTRL and ALT modifiers.
   */
  if (IS_SPECIAL(c)) {
    for (i = 0; modifier_keys_table[i] != 0; i += MOD_KEYS_ENTRY_SIZE)
      if (       KEY2TERMCAP0(c) == (int)modifier_keys_table[i + 1]
                 && (int)KEY2TERMCAP1(c) == (int)modifier_keys_table[i + 2]) {
        modifiers |= modifier_keys_table[i];
        c = TERMCAP2KEY(modifier_keys_table[i + 3],
            modifier_keys_table[i + 4]);
        break;
      }
  }

  /* try to find the key in the special key table */
  table_idx = find_special_key_in_table(c);

  /*
   * When not a known special key, and not a printable character, try to
   * extract modifiers.
   */
  if (c > 0
      && (*mb_char2len)(c) == 1
      ) {
    if (table_idx < 0
        && (!vim_isprintc(c) || (c & 0x7f) == ' ')
        && (c & 0x80)) {
      c &= 0x7f;
      modifiers |= MOD_MASK_ALT;
      /* try again, to find the un-alted key in the special key table */
      table_idx = find_special_key_in_table(c);
    }
    if (table_idx < 0 && !vim_isprintc(c) && c < ' ') {
      c += '@';
      modifiers |= MOD_MASK_CTRL;
    }
  }

  /* translate the modifier into a string */
  for (i = 0; mod_mask_table[i].name != 'A'; i++)
    if ((modifiers & mod_mask_table[i].mod_mask)
        == mod_mask_table[i].mod_flag) {
      string[idx++] = mod_mask_table[i].name;
      string[idx++] = (char_u)'-';
    }

  if (table_idx < 0) {          /* unknown special key, may output t_xx */
    if (IS_SPECIAL(c)) {
      string[idx++] = 't';
      string[idx++] = '_';
      string[idx++] = (char_u)KEY2TERMCAP0(c);
      string[idx++] = KEY2TERMCAP1(c);
    } else {
      // Not a special key, only modifiers, output directly.
      if (utf_char2len(c) > 1) {
        idx += utf_char2bytes(c, string + idx);
      } else if (vim_isprintc(c)) {
        string[idx++] = (char_u)c;
      } else {
        s = transchar(c);
        while (*s)
          string[idx++] = *s++;
      }
    }
  } else {            // use name of special key
    size_t len = STRLEN(key_names_table[table_idx].name);

    if ((int)len + idx + 2 <= MAX_KEY_NAME_LEN) {
        STRCPY(string + idx, key_names_table[table_idx].name);
        idx += (int)len;
    }
  }
  string[idx++] = '>';
  string[idx] = NUL;
  return string;
}

/// Try translating a <> name ("keycode").
///
/// @param[in,out]  srcp  Source from which <> are translated. Is advanced to
///                       after the <> name if there is a match.
/// @param[in]  src_len  Length of the srcp.
/// @param[out]  dst  Location where translation result will be kept. Must have
///                   at least six bytes.
/// @param[in]  keycode  Prefer key code, e.g. K_DEL in place of DEL.
/// @param[in]  in_string  Inside a double quoted string
///
/// @return Number of characters added to dst, zero for no match.
unsigned int trans_special(const char_u **srcp, const size_t src_len,
                           char_u *const dst, const bool keycode,
                           const bool in_string)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int modifiers = 0;
  int key;
  unsigned int dlen = 0;

  key = find_special_key(srcp, src_len, &modifiers, keycode, false, in_string);
  if (key == 0) {
    return 0;
  }

  // Put the appropriate modifier in a string.
  if (modifiers != 0) {
    dst[dlen++] = K_SPECIAL;
    dst[dlen++] = KS_MODIFIER;
    dst[dlen++] = (char_u)modifiers;
  }

  if (IS_SPECIAL(key)) {
    dst[dlen++] = K_SPECIAL;
    dst[dlen++] = (char_u)KEY2TERMCAP0(key);
    dst[dlen++] = KEY2TERMCAP1(key);
  } else if (!keycode) {
    dlen += (unsigned int)utf_char2bytes(key, dst + dlen);
  } else {
    char_u *after = add_char2buf(key, dst + dlen);
    assert(after >= dst && (uintmax_t)(after - dst) <= UINT_MAX);
    dlen = (unsigned int)(after - dst);
  }

  return dlen;
}

/// Try translating a <> name
///
/// @param[in,out]  srcp  Translated <> name. Is advanced to after the <> name.
/// @param[in]  src_len  srcp length.
/// @param[out]  modp  Location where information about modifiers is saved.
/// @param[in]  keycode  Prefer key code, e.g. K_DEL in place of DEL.
/// @param[in]  keep_x_key  Don’t translate xHome to Home key.
/// @param[in]  in_string  In string, double quote is escaped
///
/// @return Key and modifiers or 0 if there is no match.
int find_special_key(const char_u **srcp, const size_t src_len, int *const modp,
                     const bool keycode, const bool keep_x_key,
                     const bool in_string)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  const char_u *last_dash;
  const char_u *end_of_name;
  const char_u *src;
  const char_u *bp;
  const char_u *const end = *srcp + src_len - 1;
  int modifiers;
  int bit;
  int key;
  uvarnumber_T n;
  int l;

  if (src_len == 0) {
    return 0;
  }

  src = *srcp;
  if (src[0] != '<') {
    return 0;
  }

  // Find end of modifier list
  last_dash = src;
  for (bp = src + 1; bp <= end && (*bp == '-' || ascii_isident(*bp)); bp++) {
    if (*bp == '-') {
      last_dash = bp;
      if (bp + 1 <= end) {
        l = utfc_ptr2len_len(bp + 1, (int)(end - bp) + 1);
        // Anything accepted, like <C-?>.
        // <C-"> or <M-"> are not special in strings as " is
        // the string delimiter. With a backslash it works: <M-\">
        if (end - bp > l && !(in_string && bp[1] == '"') && bp[l+1] == '>') {
          bp += l;
        } else if (end - bp > 2 && in_string && bp[1] == '\\'
                   && bp[2] == '"' && bp[3] == '>') {
          bp += 2;
        }
      }
    }
    if (end - bp > 3 && bp[0] == 't' && bp[1] == '_') {
      bp += 3;  // skip t_xx, xx may be '-' or '>'
    } else if (end - bp > 4 && STRNICMP(bp, "char-", 5) == 0) {
      vim_str2nr(bp + 5, NULL, &l, STR2NR_ALL, NULL, NULL, 0);
      bp += l + 5;
      break;
    }
  }

  if (bp <= end && *bp == '>') {  // found matching '>'
    end_of_name = bp + 1;

    /* Which modifiers are given? */
    modifiers = 0x0;
    for (bp = src + 1; bp < last_dash; bp++) {
      if (*bp != '-') {
        bit = name_to_mod_mask(*bp);
        if (bit == 0x0) {
          break;                // Illegal modifier name
        }
        modifiers |= bit;
      }
    }

    // Legal modifier name.
    if (bp >= last_dash) {
      if (STRNICMP(last_dash + 1, "char-", 5) == 0
          && ascii_isdigit(last_dash[6])) {
        // <Char-123> or <Char-033> or <Char-0x33>
        vim_str2nr(last_dash + 6, NULL, NULL, STR2NR_ALL, NULL, &n, 0);
        key = (int)n;
      } else {
        int off = 1;

        // Modifier with single letter, or special key name.
        if (in_string && last_dash[1] == '\\' && last_dash[2] == '"') {
          // Special case for a double-quoted string
          off = l = 2;
        } else {
          l = mb_ptr2len(last_dash + 1);
        }
        if (modifiers != 0 && last_dash[l + 1] == '>') {
          key = PTR2CHAR(last_dash + off);
        } else {
          key = get_special_key_code(last_dash + off);
          if (!keep_x_key) {
            key = handle_x_keys(key);
          }
        }
      }

      // get_special_key_code() may return NUL for invalid
      // special key name.
      if (key != NUL) {
        // Only use a modifier when there is no special key code that
        // includes the modifier.
        key = simplify_key(key, &modifiers);

        if (!keycode) {
          // don't want keycode, use single byte code
          if (key == K_BS) {
            key = BS;
          } else if (key == K_DEL || key == K_KDEL) {
            key = DEL;
          }
        }

        // Normal Key with modifier:
        // Try to make a single byte code (except for Alt/Meta modifiers).
        if (!IS_SPECIAL(key)) {
          key = extract_modifiers(key, &modifiers);
        }

        *modp = modifiers;
        *srcp = end_of_name;
        return key;
      }  // else { ELOG("unknown key: '%s'", src); }
    }
  }
  return 0;
}

/// Try to include modifiers (except alt/meta) in the key.
/// Changes "Shift-a" to 'A', "Ctrl-@" to <Nul>, etc.
static int extract_modifiers(int key, int *modp)
{
  int modifiers = *modp;

  if (!(modifiers & MOD_MASK_CMD)) {  // Command-key is special
    if ((modifiers & MOD_MASK_SHIFT) && ASCII_ISALPHA(key)) {
      key = TOUPPER_ASC(key);
      modifiers &= ~MOD_MASK_SHIFT;
    }
  }
  if ((modifiers & MOD_MASK_CTRL)
      && ((key >= '?' && key <= '_') || ASCII_ISALPHA(key))) {
    key = Ctrl_chr(key);
    modifiers &= ~MOD_MASK_CTRL;
    if (key == 0) {  // <C-@> is <Nul>
      key = K_ZERO;
    }
  }

  *modp = modifiers;
  return key;
}

/*
 * Try to find key "c" in the special key table.
 * Return the index when found, -1 when not found.
 */
int find_special_key_in_table(int c)
{
  int i;

  for (i = 0; key_names_table[i].name != NULL; i++) {
    if (c == key_names_table[i].key) {
      break;
    }
  }
  if (key_names_table[i].name == NULL) {
    i = -1;
  }
  return i;
}

/// Find the special key with the given name
///
/// @param[in]  name  Name of the special. Does not have to end with NUL, it is
///                   assumed to end before the first non-idchar. If name starts
///                   with "t_" the next two characters are interpreted as
///                   a termcap name.
///
/// @return Key code or 0 if not found.
int get_special_key_code(const char_u *name)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  for (int i = 0; key_names_table[i].name != NULL; i++) {
    const char *const table_name = key_names_table[i].name;
    int j;
    for (j = 0; ascii_isident(name[j]) && table_name[j] != NUL; j++) {
      if (TOLOWER_ASC(table_name[j]) != TOLOWER_ASC(name[j])) {
        break;
      }
    }
    if (!ascii_isident(name[j]) && table_name[j] == NUL) {
      return key_names_table[i].key;
    }
  }

  return 0;
}

/*
 * Look up the given mouse code to return the relevant information in the other
 * arguments.  Return which button is down or was released.
 */
int get_mouse_button(int code, bool *is_click, bool *is_drag)
{
  int i;

  for (i = 0; mouse_table[i].pseudo_code; i++)
    if (code == mouse_table[i].pseudo_code) {
      *is_click = mouse_table[i].is_click;
      *is_drag = mouse_table[i].is_drag;
      return mouse_table[i].button;
    }
  return 0;         /* Shouldn't get here */
}

/// Replace any terminal code strings with the equivalent internal
/// representation
///
/// Used for the "from" and "to" part of a mapping, and the "to" part of
/// a menu command. Any strings like "<C-UP>" are also replaced, unless
/// `special` is false. K_SPECIAL by itself is replaced by K_SPECIAL
/// KS_SPECIAL KE_FILLER.
///
/// @param[in]  from  What characters to replace.
/// @param[in]  from_len  Length of the "from" argument.
/// @param[out]  bufp  Location where results were saved in case of success
///                    (allocated). Will be set to NULL in case of failure.
/// @param[in]  do_lt  If true, also translate <lt>.
/// @param[in]  from_part  If true, trailing <C-v> is included, otherwise it is
///                        removed (to make ":map xx ^V" map xx to nothing).
///                        When cpo_flags contains #FLAG_CPO_BSLASH, a backslash
///                        can be used in place of <C-v>. All other <C-v>
///                        characters are removed.
/// @param[in]  special    Replace keycodes, e.g. <CR> becomes a "\n" char.
/// @param[in]  cpo_flags  Relevant flags derived from p_cpo, see
///                        #CPO_TO_CPO_FLAGS.
///
/// @return Pointer to an allocated memory in case of success, "from" in case of
///         failure. In case of success returned pointer is also saved to
///         "bufp".
char_u *replace_termcodes(const char_u *from, const size_t from_len,
                          char_u **bufp, const bool from_part, const bool do_lt,
                          const bool special, int cpo_flags)
  FUNC_ATTR_NONNULL_ALL
{
  ssize_t i;
  size_t slen;
  char_u key;
  size_t dlen = 0;
  const char_u *src;
  const char_u *const end = from + from_len - 1;
  int do_backslash;             // backslash is a special character
  char_u      *result;          // buffer for resulting string

  do_backslash = !(cpo_flags&FLAG_CPO_BSLASH);

  // Allocate space for the translation.  Worst case a single character is
  // replaced by 6 bytes (shifted special key), plus a NUL at the end.
  const size_t buf_len = from_len * 6 + 1;
  result = xmalloc(buf_len);

  src = from;

  // Check for #n at start only: function key n
  if (from_part && from_len > 1 && src[0] == '#'
      && ascii_isdigit(src[1])) {  // function key
    result[dlen++] = K_SPECIAL;
    result[dlen++] = 'k';
    if (src[1] == '0') {
      result[dlen++] = ';';     // #0 is F10 is "k;"
    } else {
      result[dlen++] = src[1];  // #3 is F3 is "k3"
    }
    src += 2;
  }

  // Copy each byte from *from to result[dlen]
  while (src <= end) {
    // Check for special <> keycodes, like "<C-S-LeftMouse>"
    if (special && (do_lt || ((end - src) >= 3
                              && STRNCMP(src, "<lt>", 4) != 0))) {
      // Replace <SID> by K_SNR <script-nr> _.
      // (room: 5 * 6 = 30 bytes; needed: 3 + <nr> + 1 <= 14)
      if (end - src >= 4 && STRNICMP(src, "<SID>", 5) == 0) {
        if (current_sctx.sc_sid <= 0) {
          EMSG(_(e_usingsid));
        } else {
          src += 5;
          result[dlen++] = K_SPECIAL;
          result[dlen++] = (int)KS_EXTRA;
          result[dlen++] = (int)KE_SNR;
          snprintf((char *)result + dlen, buf_len - dlen, "%" PRId64,
                   (int64_t)current_sctx.sc_sid);
          dlen += STRLEN(result + dlen);
          result[dlen++] = '_';
          continue;
        }
      }

      slen = trans_special(&src, (size_t)(end - src) + 1, result + dlen, true,
                           false);
      if (slen) {
        dlen += slen;
        continue;
      }
    }

    if (special) {
      char_u  *p, *s, len;

      // Replace <Leader> by the value of "mapleader".
      // Replace <LocalLeader> by the value of "maplocalleader".
      // If "mapleader" or "maplocalleader" isn't set use a backslash.
      if (end - src >= 7 && STRNICMP(src, "<Leader>", 8) == 0) {
        len = 8;
        p = get_var_value("g:mapleader");
      } else if (end - src >= 12 && STRNICMP(src, "<LocalLeader>", 13) == 0) {
        len = 13;
        p = get_var_value("g:maplocalleader");
      } else {
        len = 0;
        p = NULL;
      }

      if (len != 0) {
        // Allow up to 8 * 6 characters for "mapleader".
        if (p == NULL || *p == NUL || STRLEN(p) > 8 * 6) {
          s = (char_u *)"\\";
        } else {
          s = p;
        }
        while (*s != NUL) {
          result[dlen++] = *s++;
        }
        src += len;
        continue;
      }
    }

    // Remove CTRL-V and ignore the next character.
    // For "from" side the CTRL-V at the end is included, for the "to"
    // part it is removed.
    // If 'cpoptions' does not contain 'B', also accept a backslash.
    key = *src;
    if (key == Ctrl_V || (do_backslash && key == '\\')) {
      src++;  // skip CTRL-V or backslash
      if (src > end) {
        if (from_part) {
          result[dlen++] = key;
        }
        break;
      }
    }

    // skip multibyte char correctly
    for (i = utfc_ptr2len_len(src, (int)(end - src) + 1); i > 0; i--) {
      // If the character is K_SPECIAL, replace it with K_SPECIAL
      // KS_SPECIAL KE_FILLER.
      // If compiled with the GUI replace CSI with K_CSI.
      if (*src == K_SPECIAL) {
        result[dlen++] = K_SPECIAL;
        result[dlen++] = KS_SPECIAL;
        result[dlen++] = KE_FILLER;
      } else {
        result[dlen++] = *src;
      }
      ++src;
    }
  }
  result[dlen] = NUL;

  *bufp = xrealloc(result, dlen + 1);

  return *bufp;
}

/// Logs a single key as a human-readable keycode.
void log_key(int log_level, int key)
{
  if (log_level < MIN_LOG_LEVEL) {
    return;
  }
  char *keyname = key == K_EVENT
    ? "K_EVENT"
    : (char *)get_special_key_name(key, mod_mask);
  LOG(log_level, "input: %s", keyname);
}
