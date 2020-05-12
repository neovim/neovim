#include <stdbool.h>

#include "nvim/types.h"
#include "nvim/keymap.h"
#include "nvim/ascii.h"
#include "nvim/eval/typval.h"

#define MOD_KEYS_ENTRY_SIZE 5

static char_u modifier_keys_table[] =
{
  MOD_MASK_SHIFT, '&', '9',                   '@', '1',
  MOD_MASK_SHIFT, '&', '0',                   '@', '2',
  MOD_MASK_SHIFT, '*', '1',                   '@', '4',
  MOD_MASK_SHIFT, '*', '2',                   '@', '5',
  MOD_MASK_SHIFT, '*', '3',                   '@', '6',
  MOD_MASK_SHIFT, '*', '4',                   'k', 'D',
  MOD_MASK_SHIFT, '*', '5',                   'k', 'L',
  MOD_MASK_SHIFT, '*', '7',                   '@', '7',
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_END,    '@', '7',
  MOD_MASK_SHIFT, '*', '9',                   '@', '9',
  MOD_MASK_SHIFT, '*', '0',                   '@', '0',
  MOD_MASK_SHIFT, '#', '1',                   '%', '1',
  MOD_MASK_SHIFT, '#', '2',                   'k', 'h',
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_HOME,   'k', 'h',
  MOD_MASK_SHIFT, '#', '3',                   'k', 'I',
  MOD_MASK_SHIFT, '#', '4',                   'k', 'l',
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_LEFT,   'k', 'l',
  MOD_MASK_SHIFT, '%', 'a',                   '%', '3',
  MOD_MASK_SHIFT, '%', 'b',                   '%', '4',
  MOD_MASK_SHIFT, '%', 'c',                   '%', '5',
  MOD_MASK_SHIFT, '%', 'd',                   '%', '7',
  MOD_MASK_SHIFT, '%', 'e',                   '%', '8',
  MOD_MASK_SHIFT, '%', 'f',                   '%', '9',
  MOD_MASK_SHIFT, '%', 'g',                   '%', '0',
  MOD_MASK_SHIFT, '%', 'h',                   '&', '3',
  MOD_MASK_SHIFT, '%', 'i',                   'k', 'r',
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_RIGHT,  'k', 'r',
  MOD_MASK_SHIFT, '%', 'j',                   '&', '5',
  MOD_MASK_SHIFT, '!', '1',                   '&', '6',
  MOD_MASK_SHIFT, '!', '2',                   '&', '7',
  MOD_MASK_SHIFT, '!', '3',                   '&', '8',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_UP,     'k', 'u',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_DOWN,   'k', 'd',

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF1,    KS_EXTRA, (int)KE_XF1,
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF2,    KS_EXTRA, (int)KE_XF2,
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF3,    KS_EXTRA, (int)KE_XF3,
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF4,    KS_EXTRA, (int)KE_XF4,

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F1,     'k', '1',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F2,     'k', '2',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F3,     'k', '3',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F4,     'k', '4',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F5,     'k', '5',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F6,     'k', '6',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F7,     'k', '7',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F8,     'k', '8',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F9,     'k', '9',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F10,    'k', ';',

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

  MOD_MASK_SHIFT, 'k', 'B',                   KS_EXTRA, (int)KE_TAB,

  NUL
};

int simplify_key(const int key, int *modifiers)
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
  { K_KDEL,            "KPPeriod" },    // termkey KPPeriod value
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
  { K_PASTE,           "Paste" },
  { 0,                 NULL }
};

int get_special_key_code(const char_u *name)
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


static const struct modmasktable {
  short mod_mask;  ///< Bit-mask for particular key modifier.
  short mod_flag;  ///< Bit(s) for particular key modifier.
  char_u name;  ///< Single letter name of modifier.
} mod_mask_table[] = {
  {MOD_MASK_ALT,              MOD_MASK_ALT,           (char_u)'M'},
  {MOD_MASK_META,             MOD_MASK_META,          (char_u)'T'},
  {MOD_MASK_CTRL,             MOD_MASK_CTRL,          (char_u)'C'},
  {MOD_MASK_SHIFT,            MOD_MASK_SHIFT,         (char_u)'S'},
  {MOD_MASK_MULTI_CLICK,      MOD_MASK_2CLICK,        (char_u)'2'},
  {MOD_MASK_MULTI_CLICK,      MOD_MASK_3CLICK,        (char_u)'3'},
  {MOD_MASK_MULTI_CLICK,      MOD_MASK_4CLICK,        (char_u)'4'},
  {MOD_MASK_CMD,              MOD_MASK_CMD,           (char_u)'D'},
  // 'A' must be the last one
  {MOD_MASK_ALT,              MOD_MASK_ALT,           (char_u)'A'},
  {0, 0, NUL}
};

int name_to_mod_mask(int c)
{
  c = TOUPPER_ASC(c);
  for (size_t i = 0; mod_mask_table[i].mod_mask != 0; i++) {
    if (c == mod_mask_table[i].name) {
      return mod_mask_table[i].mod_flag;
    }
  }
  return 0;
}

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

int find_special_key(const char_u **srcp, const size_t src_len, int *const modp,
                     const bool keycode, const bool keep_x_key,
                     const bool in_string)
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
        if (end - bp > l && !(in_string && bp[1] == '"') && bp[2] == '>') {
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
          off = 2;
        }
        l = mb_ptr2len(last_dash + 1);
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
      }
    }
  }
  return 0;
}

char_u *add_char2buf(int c, char_u *s)
{
  char_u temp[MB_MAXBYTES + 1];
  const int len = utf_char2bytes(c, temp);
  for (int i = 0; i < len; ++i) {
    c = temp[i];
    // Need to escape K_SPECIAL and CSI like in the typeahead buffer.
    if (c == K_SPECIAL) {
      *s++ = K_SPECIAL;
      *s++ = KS_SPECIAL;
      *s++ = KE_FILLER;
    } else {
      *s++ = c;
    }
  }
  return s;
}

unsigned int trans_special(const char_u **srcp, const size_t src_len,
                           char_u *const dst, const bool keycode,
                           const bool in_string)
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
  } else if (has_mbyte && !keycode) {
    dlen += (unsigned int)(*mb_char2bytes)(key, dst + dlen);
  } else if (keycode) {
    char_u *after = add_char2buf(key, dst + dlen);
    assert(after >= dst && (uintmax_t)(after - dst) <= UINT_MAX);
    dlen = (unsigned int)(after - dst);
  } else {
    dst[dlen++] = (char_u)key;
  }

  return dlen;
}
