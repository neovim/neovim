#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <uv.h>

#include "nvim/api/private/defs.h"
#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/errors.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/vars.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/option_vars.h"
#include "nvim/strings.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "keycode_names.generated.h"
# include "keycodes.c.generated.h"
#endif

// Some useful tables.

static const struct modmasktable {
  uint16_t mod_mask;  ///< Bit-mask for particular key modifier.
  uint16_t mod_flag;  ///< Bit(s) for particular key modifier.
  char name;  ///< Single letter name of modifier.
} mod_mask_table[] = {
  { MOD_MASK_ALT,              MOD_MASK_ALT,           'M' },
  { MOD_MASK_META,             MOD_MASK_META,          'T' },
  { MOD_MASK_CTRL,             MOD_MASK_CTRL,          'C' },
  { MOD_MASK_SHIFT,            MOD_MASK_SHIFT,         'S' },
  { MOD_MASK_MULTI_CLICK,      MOD_MASK_2CLICK,        '2' },
  { MOD_MASK_MULTI_CLICK,      MOD_MASK_3CLICK,        '3' },
  { MOD_MASK_MULTI_CLICK,      MOD_MASK_4CLICK,        '4' },
  { MOD_MASK_CMD,              MOD_MASK_CMD,           'D' },
  // 'A' must be the last one
  { MOD_MASK_ALT,              MOD_MASK_ALT,           'A' },
  { 0, 0, NUL }
  // NOTE: when adding an entry, update MAX_KEY_NAME_LEN!
};

// Shifted key terminal codes and their unshifted equivalent.
// Don't add mouse codes here, they are handled separately!

#define MOD_KEYS_ENTRY_SIZE 5

static uint8_t modifier_keys_table[] = {
  //  mod mask      with modifier               without modifier
  MOD_MASK_SHIFT, '&', '9',                   '@', '1',         // begin
  MOD_MASK_SHIFT, '&', '0',                   '@', '2',         // cancel
  MOD_MASK_SHIFT, '*', '1',                   '@', '4',         // command
  MOD_MASK_SHIFT, '*', '2',                   '@', '5',         // copy
  MOD_MASK_SHIFT, '*', '3',                   '@', '6',         // create
  MOD_MASK_SHIFT, '*', '4',                   'k', 'D',         // delete char
  MOD_MASK_SHIFT, '*', '5',                   'k', 'L',         // delete line
  MOD_MASK_SHIFT, '*', '7',                   '@', '7',         // end
  MOD_MASK_CTRL,  KS_EXTRA, KE_C_END,         '@', '7',         // end
  MOD_MASK_SHIFT, '*', '9',                   '@', '9',         // exit
  MOD_MASK_SHIFT, '*', '0',                   '@', '0',         // find
  MOD_MASK_SHIFT, '#', '1',                   '%', '1',         // help
  MOD_MASK_SHIFT, '#', '2',                   'k', 'h',         // home
  MOD_MASK_CTRL,  KS_EXTRA, KE_C_HOME,        'k', 'h',         // home
  MOD_MASK_SHIFT, '#', '3',                   'k', 'I',         // insert
  MOD_MASK_SHIFT, '#', '4',                   'k', 'l',         // left arrow
  MOD_MASK_CTRL,  KS_EXTRA, KE_C_LEFT,        'k', 'l',         // left arrow
  MOD_MASK_SHIFT, '%', 'a',                   '%', '3',         // message
  MOD_MASK_SHIFT, '%', 'b',                   '%', '4',         // move
  MOD_MASK_SHIFT, '%', 'c',                   '%', '5',         // next
  MOD_MASK_SHIFT, '%', 'd',                   '%', '7',         // options
  MOD_MASK_SHIFT, '%', 'e',                   '%', '8',         // previous
  MOD_MASK_SHIFT, '%', 'f',                   '%', '9',         // print
  MOD_MASK_SHIFT, '%', 'g',                   '%', '0',         // redo
  MOD_MASK_SHIFT, '%', 'h',                   '&', '3',         // replace
  MOD_MASK_SHIFT, '%', 'i',                   'k', 'r',         // right arr.
  MOD_MASK_CTRL,  KS_EXTRA, KE_C_RIGHT,       'k', 'r',         // right arr.
  MOD_MASK_SHIFT, '%', 'j',                   '&', '5',         // resume
  MOD_MASK_SHIFT, '!', '1',                   '&', '6',         // save
  MOD_MASK_SHIFT, '!', '2',                   '&', '7',         // suspend
  MOD_MASK_SHIFT, '!', '3',                   '&', '8',         // undo
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_UP,          'k', 'u',         // up arrow
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_DOWN,        'k', 'd',         // down arrow

  // vt100 F1
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_XF1,         KS_EXTRA, KE_XF1,
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_XF2,         KS_EXTRA, KE_XF2,
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_XF3,         KS_EXTRA, KE_XF3,
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_XF4,         KS_EXTRA, KE_XF4,

  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F1,          'k', '1',         // F1
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F2,          'k', '2',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F3,          'k', '3',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F4,          'k', '4',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F5,          'k', '5',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F6,          'k', '6',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F7,          'k', '7',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F8,          'k', '8',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F9,          'k', '9',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F10,         'k', ';',         // F10

  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F11,         'F', '1',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F12,         'F', '2',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F13,         'F', '3',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F14,         'F', '4',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F15,         'F', '5',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F16,         'F', '6',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F17,         'F', '7',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F18,         'F', '8',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F19,         'F', '9',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F20,         'F', 'A',

  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F21,         'F', 'B',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F22,         'F', 'C',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F23,         'F', 'D',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F24,         'F', 'E',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F25,         'F', 'F',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F26,         'F', 'G',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F27,         'F', 'H',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F28,         'F', 'I',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F29,         'F', 'J',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F30,         'F', 'K',

  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F31,         'F', 'L',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F32,         'F', 'M',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F33,         'F', 'N',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F34,         'F', 'O',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F35,         'F', 'P',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F36,         'F', 'Q',
  MOD_MASK_SHIFT, KS_EXTRA, KE_S_F37,         'F', 'R',

  // TAB pseudo code
  MOD_MASK_SHIFT, 'k', 'B',                   KS_EXTRA, KE_TAB,

  NUL
};

static struct mousetable {
  int pseudo_code;            // Code for pseudo mouse event
  int button;                 // Which mouse button is it?
  bool is_click;              // Is it a mouse button click event?
  bool is_drag;               // Is it a mouse drag event?
} mouse_table[] = {
  { KE_LEFTMOUSE,        MOUSE_LEFT,     true,   false },
  { KE_LEFTDRAG,         MOUSE_LEFT,     false,  true },
  { KE_LEFTRELEASE,      MOUSE_LEFT,     false,  false },
  { KE_MIDDLEMOUSE,      MOUSE_MIDDLE,   true,   false },
  { KE_MIDDLEDRAG,       MOUSE_MIDDLE,   false,  true },
  { KE_MIDDLERELEASE,    MOUSE_MIDDLE,   false,  false },
  { KE_RIGHTMOUSE,       MOUSE_RIGHT,    true,   false },
  { KE_RIGHTDRAG,        MOUSE_RIGHT,    false,  true },
  { KE_RIGHTRELEASE,     MOUSE_RIGHT,    false,  false },
  { KE_X1MOUSE,          MOUSE_X1,       true,   false },
  { KE_X1DRAG,           MOUSE_X1,       false,  true },
  { KE_X1RELEASE,        MOUSE_X1,       false,  false },
  { KE_X2MOUSE,          MOUSE_X2,       true,   false },
  { KE_X2DRAG,           MOUSE_X2,       false,  true },
  { KE_X2RELEASE,        MOUSE_X2,       false,  false },
  // DRAG without CLICK
  { KE_MOUSEMOVE,        MOUSE_RELEASE,  false,  true },
  // RELEASE without CLICK
  { KE_IGNORE,           MOUSE_RELEASE,  false,  false },
  { 0,                   0,              0,      0 },
};

/// Return the modifier mask bit (#MOD_MASK_*) corresponding to mod name
///
/// E.g. 'S' for shift, 'C' for ctrl.
int name_to_mod_mask(int c)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  c = TOUPPER_ASC(c);
  for (size_t i = 0; mod_mask_table[i].mod_mask != 0; i++) {
    if (c == (uint8_t)mod_mask_table[i].name) {
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
  if (!(*modifiers & (MOD_MASK_SHIFT | MOD_MASK_CTRL))) {
    return key;
  }

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
  return key;
}

/// Change <xKey> to <Key>
int handle_x_keys(const int key)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (key) {
  case K_XUP:
    return K_UP;
  case K_XDOWN:
    return K_DOWN;
  case K_XLEFT:
    return K_LEFT;
  case K_XRIGHT:
    return K_RIGHT;
  case K_XHOME:
    return K_HOME;
  case K_ZHOME:
    return K_HOME;
  case K_XEND:
    return K_END;
  case K_ZEND:
    return K_END;
  case K_XF1:
    return K_F1;
  case K_XF2:
    return K_F2;
  case K_XF3:
    return K_F3;
  case K_XF4:
    return K_F4;
  case K_S_XF1:
    return K_S_F1;
  case K_S_XF2:
    return K_S_F2;
  case K_S_XF3:
    return K_S_F3;
  case K_S_XF4:
    return K_S_F4;
  }
  return key;
}

/// @return  a string which contains the name of the given key when the given modifiers are down.
char *get_special_key_name(int c, int modifiers)
{
  static char string[MAX_KEY_NAME_LEN + 1];

  string[0] = '<';
  int idx = 1;

  // Key that stands for a normal character.
  if (IS_SPECIAL(c) && KEY2TERMCAP0(c) == KS_KEY) {
    c = KEY2TERMCAP1(c);
  }

  // Translate shifted special keys into unshifted keys and set modifier.
  // Same for CTRL and ALT modifiers.
  if (IS_SPECIAL(c)) {
    for (int i = 0; modifier_keys_table[i] != 0; i += MOD_KEYS_ENTRY_SIZE) {
      if (KEY2TERMCAP0(c) == (int)modifier_keys_table[i + 1]
          && (int)KEY2TERMCAP1(c) == (int)modifier_keys_table[i + 2]) {
        modifiers |= modifier_keys_table[i];
        c = TERMCAP2KEY(modifier_keys_table[i + 3],
                        modifier_keys_table[i + 4]);
        break;
      }
    }
  }

  // try to find the key in the special key table
  int table_idx = find_special_key_in_table(c);

  // When not a known special key, and not a printable character, try to
  // extract modifiers.
  if (c > 0
      && utf_char2len(c) == 1) {
    if (table_idx < 0
        && (!vim_isprintc(c) || (c & 0x7f) == ' ')
        && (c & 0x80)) {
      c &= 0x7f;
      modifiers |= MOD_MASK_ALT;
      // try again, to find the un-alted key in the special key table
      table_idx = find_special_key_in_table(c);
    }
    if (table_idx < 0 && !vim_isprintc(c) && c < ' ') {
      c += '@';
      modifiers |= MOD_MASK_CTRL;
    }
  }

  // translate the modifier into a string
  for (int i = 0; mod_mask_table[i].name != 'A'; i++) {
    if ((modifiers & mod_mask_table[i].mod_mask)
        == mod_mask_table[i].mod_flag) {
      string[idx++] = mod_mask_table[i].name;
      string[idx++] = '-';
    }
  }

  if (table_idx < 0) {          // unknown special key, may output t_xx
    if (IS_SPECIAL(c)) {
      string[idx++] = 't';
      string[idx++] = '_';
      string[idx++] = (char)(uint8_t)KEY2TERMCAP0(c);
      string[idx++] = (char)(uint8_t)KEY2TERMCAP1(c);
    } else {
      // Not a special key, only modifiers, output directly.
      if (utf_char2len(c) > 1) {
        idx += utf_char2bytes(c, string + idx);
      } else if (vim_isprintc(c)) {
        string[idx++] = (char)(uint8_t)c;
      } else {
        char *s = transchar(c);
        while (*s) {
          string[idx++] = *s++;
        }
      }
    }
  } else {            // use name of special key
    const String *s = &key_names_table[table_idx].name;
    if ((int)s->size + idx + 2 <= MAX_KEY_NAME_LEN) {
      STRCPY(string + idx, s->data);
      idx += (int)s->size;
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
/// @param[out]  dst  Location where translation result will be kept. It must
//                    be at least 19 bytes per "<x>" form.
/// @param[in]  flags  FSK_ values
/// @param[in]  escape_ks  escape K_SPECIAL bytes in the character
/// @param[out]  did_simplify  found <C-H>, etc.
///
/// @return Number of characters added to dst, zero for no match.
unsigned trans_special(const char **const srcp, const size_t src_len, char *const dst,
                       const int flags, const bool escape_ks, bool *const did_simplify)
  FUNC_ATTR_NONNULL_ARG(1, 3) FUNC_ATTR_WARN_UNUSED_RESULT
{
  int modifiers = 0;
  int key = find_special_key(srcp, src_len, &modifiers, flags, did_simplify);
  if (key == 0) {
    return 0;
  }

  return special_to_buf(key, modifiers, escape_ks, dst);
}

/// Put the character sequence for "key" with "modifiers" into "dst" and return
/// the resulting length.
/// When "escape_ks" is true escape K_SPECIAL bytes in the character.
/// The sequence is not NUL terminated.
/// This is how characters in a string are encoded.
unsigned special_to_buf(int key, int modifiers, bool escape_ks, char *dst)
{
  unsigned dlen = 0;

  // Put the appropriate modifier in a string.
  if (modifiers != 0) {
    dst[dlen++] = (char)(uint8_t)K_SPECIAL;
    dst[dlen++] = (char)(uint8_t)KS_MODIFIER;
    dst[dlen++] = (char)(uint8_t)modifiers;
  }

  if (IS_SPECIAL(key)) {
    dst[dlen++] = (char)(uint8_t)K_SPECIAL;
    dst[dlen++] = (char)(uint8_t)KEY2TERMCAP0(key);
    dst[dlen++] = (char)(uint8_t)KEY2TERMCAP1(key);
  } else if (escape_ks) {
    char *after = add_char2buf(key, dst + dlen);
    assert(after >= dst && (uintmax_t)(after - dst) <= UINT_MAX);
    dlen = (unsigned)(after - dst);
  } else {
    dlen += (unsigned)utf_char2bytes(key, dst + dlen);
  }

  return dlen;
}

/// Try translating a <> name
///
/// @param[in,out]  srcp  Translated <> name. Is advanced to after the <> name.
/// @param[in]  src_len  srcp length.
/// @param[out]  modp  Location where information about modifiers is saved.
/// @param[in]  flags  FSK_ values
/// @param[out]  did_simplify  FSK_SIMPLIFY and found <C-H>, etc.
///
/// @return Key and modifiers or 0 if there is no match.
int find_special_key(const char **const srcp, const size_t src_len, int *const modp,
                     const int flags, bool *const did_simplify)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1, 3)
{
  const char *bp;
  const char *const end = *srcp + src_len - 1;
  const bool in_string = flags & FSK_IN_STRING;
  uvarnumber_T n;
  int l;

  if (src_len == 0) {
    return 0;
  }

  const char *src = *srcp;
  if (src[0] != '<') {
    return 0;
  }
  if (src[1] == '*') {  // <*xxx>: do not simplify
    src++;
  }

  // Find end of modifier list
  const char *last_dash = src;
  for (bp = src + 1; bp <= end && (*bp == '-' || ascii_isident(*bp)); bp++) {
    if (*bp == '-') {
      last_dash = bp;
      if (bp + 1 <= end) {
        l = utfc_ptr2len_len(bp + 1, (int)(end - bp) + 1);
        // Anything accepted, like <C-?>.
        // <C-"> or <M-"> are not special in strings as " is
        // the string delimiter. With a backslash it works: <M-\">
        if (end - bp > l && !(in_string && bp[1] == '"') && bp[l + 1] == '>') {
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
      vim_str2nr(bp + 5, NULL, &l, STR2NR_ALL, NULL, NULL, 0, true, NULL);
      if (l == 0) {
        emsg(_(e_invarg));
        return 0;
      }
      bp += l + 5;
      break;
    }
  }

  if (bp <= end && *bp == '>') {  // found matching '>'
    int key;
    const char *end_of_name = bp + 1;

    // Which modifiers are given?
    int modifiers = 0x0;
    for (bp = src + 1; bp < last_dash; bp++) {
      if (*bp != '-') {
        int bit = name_to_mod_mask((uint8_t)(*bp));
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
        vim_str2nr(last_dash + 6, NULL, &l, STR2NR_ALL, NULL, &n, 0, true, NULL);
        if (l == 0) {
          emsg(_(e_invarg));
          return 0;
        }
        key = (int)n;
      } else {
        int off = 1;

        // Modifier with single letter, or special key name.
        if (in_string && last_dash[1] == '\\' && last_dash[2] == '"') {
          // Special case for a double-quoted string
          off = l = 2;
        } else {
          l = utfc_ptr2len(last_dash + 1);
        }
        if (modifiers != 0 && last_dash[l + 1] == '>') {
          key = utf_ptr2char(last_dash + off);
        } else {
          key = get_special_key_code(last_dash + off);
          if (!(flags & FSK_KEEP_X_KEY)) {
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

        if (!(flags & FSK_KEYCODE)) {
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
          key = extract_modifiers(key, &modifiers, flags & FSK_SIMPLIFY, did_simplify);
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
/// @param[in]  simplify  if false, don't do Ctrl
/// @param[out]  did_simplify  set when it is not NULL and "simplify" is true and
///                            Ctrl is removed from modifiers
static int extract_modifiers(int key, int *modp, const bool simplify, bool *const did_simplify)
{
  int modifiers = *modp;

  if ((modifiers & MOD_MASK_SHIFT) && ASCII_ISALPHA(key)) {
    key = TOUPPER_ASC(key);
    // With <C-S-a> we keep the shift modifier.
    // With <S-a>, <A-S-a> and <S-A> we don't keep the shift modifier.
    if (!(modifiers & MOD_MASK_CTRL)) {
      modifiers &= ~MOD_MASK_SHIFT;
    }
  }

  // <C-H> and <C-h> mean the same thing, always use "H"
  if ((modifiers & MOD_MASK_CTRL) && ASCII_ISALPHA(key)) {
    key = TOUPPER_ASC(key);
  }

  if (simplify && (modifiers & MOD_MASK_CTRL)
      && ((key >= '?' && key <= '_') || ASCII_ISALPHA(key))) {
    key = CTRL_CHR(key);
    modifiers &= ~MOD_MASK_CTRL;
    if (key == NUL) {  // <C-@> is <Nul>
      key = K_ZERO;
    }
    if (did_simplify != NULL) {
      *did_simplify = true;
    }
  }

  *modp = modifiers;
  return key;
}

/// Try to find key "c" in the special key table.
/// @return  the index when found, -1 when not found.
int find_special_key_in_table(int c)
{
  for (int i = 0; i < (int)ARRAY_SIZE(key_names_table); i++) {
    if (c == key_names_table[i].key && !key_names_table[i].is_alt) {
      return i;
    }
  }

  return -1;
}

/// Find the special key with the given name
///
/// @param[in]  name  Name of the special. Does not have to end with NUL, it is
///                   assumed to end before the first non-idchar. If name starts
///                   with "t_" the next two characters are interpreted as
///                   a termcap name.
///
/// @return Key code or 0 if not found.
int get_special_key_code(const char *name)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (name[0] == 't' && name[1] == '_' && name[2] != NUL && name[3] != NUL) {
    return TERMCAP2KEY((uint8_t)name[2], (uint8_t)name[3]);
  }

  const char *name_end = name;
  while (ascii_isident(*name_end)) {
    name_end++;
  }

  int idx = get_special_key_code_hash(name, (size_t)(name_end - name));
  return idx >= 0 ? key_names_table[idx].key : 0;
}

/// Look up the given mouse code to return the relevant information in the other arguments.
/// @return  which button is down or was released.
int get_mouse_button(int code, bool *is_click, bool *is_drag)
{
  for (int i = 0; mouse_table[i].pseudo_code; i++) {
    if (code == mouse_table[i].pseudo_code) {
      *is_click = mouse_table[i].is_click;
      *is_drag = mouse_table[i].is_drag;
      return mouse_table[i].button;
    }
  }
  return 0;         // Shouldn't get here
}

/// Replace any terminal code strings with the equivalent internal representation.
///
/// Used for the "from" and "to" part of a mapping, and the "to" part of a menu command.
/// Any strings like "<C-UP>" are also replaced, unless `special` is false.
/// K_SPECIAL by itself is replaced by K_SPECIAL KS_SPECIAL KE_FILLER.
///
/// When "flags" has REPTERM_FROM_PART, trailing <C-v> is included, otherwise it is removed (to make
/// ":map xx ^V" map xx to nothing). When cpo_val contains CPO_BSLASH, a backslash can be used in
/// place of <C-v>. All other <C-v> characters are removed.
///
/// @param[in]  from  What characters to replace.
/// @param[in]  from_len  Length of the "from" argument.
/// @param[out]  bufp  Location where results were saved in case of success (allocated).
///                    If `*bufp` is non-NULL, it will be used directly,
///                    and is assumed to be 128 bytes long (enough for transcoding LHS of mapping),
///                    and will be set to NULL in case of failure.
/// @param[in]  sid_arg  Script ID to use for <SID>, or 0 to use current_sctx
/// @param[in]  flags  REPTERM_FROM_PART    see above
///                    REPTERM_DO_LT        also translate <lt>
///                    REPTERM_NO_SPECIAL   do not accept <key> notation
///                    REPTERM_NO_SIMPLIFY  do not simplify <C-H> into 0x08, etc.
/// @param[out]  did_simplify  set when some <C-H> code was simplified, unless it is NULL.
/// @param[in]  cpo_val  The value of 'cpoptions' to use. Only CPO_BSLASH matters.
///
/// @return  The same as what `*bufp` is set to.
char *replace_termcodes(const char *const from, const size_t from_len, char **const bufp,
                        const scid_T sid_arg, const int flags, bool *const did_simplify,
                        const char *const cpo_val)
  FUNC_ATTR_NONNULL_ARG(1, 3, 7)
{
  size_t dlen = 0;
  const char *const end = from + from_len - 1;

  // backslash is a special character
  const bool do_backslash = (vim_strchr(cpo_val, CPO_BSLASH) == NULL);
  const bool do_special = !(flags & REPTERM_NO_SPECIAL);

  bool allocated = (*bufp == NULL);

  // Allocate space for the translation.  Worst case a single character is
  // replaced by 6 bytes (shifted special key), plus a NUL at the end.
  const size_t buf_len = allocated ? from_len * 6 + 1 : 128;
  char *result = allocated ? xmalloc(buf_len) : *bufp;  // buffer for resulting string

  const char *src = from;

  // Copy each byte from *from to result[dlen]
  while (src <= end) {
    if (!allocated && dlen + 64 > buf_len) {
      return NULL;
    }
    // Check for special <> keycodes, like "<C-S-LeftMouse>"
    if (do_special && ((flags & REPTERM_DO_LT) || ((end - src) >= 3
                                                   && strncmp(src, "<lt>", 4) != 0))) {
      // Change <SID>Func to K_SNR <script-nr> _Func.  This name is used
      // for script-local user functions.
      // (room: 5 * 6 = 30 bytes; needed: 3 + <nr> + 1 <= 14)
      if (end - src >= 4 && STRNICMP(src, "<SID>", 5) == 0) {
        if (sid_arg < 0 || (sid_arg == 0 && current_sctx.sc_sid <= 0)) {
          emsg(_(e_usingsid));
        } else {
          const scid_T sid = sid_arg != 0 ? sid_arg : current_sctx.sc_sid;
          src += 5;
          result[dlen++] = (char)K_SPECIAL;
          result[dlen++] = (char)KS_EXTRA;
          result[dlen++] = KE_SNR;
          snprintf(result + dlen, buf_len - dlen, "%" PRIdSCID, sid);
          dlen += strlen(result + dlen);
          result[dlen++] = '_';
          continue;
        }
      }

      size_t slen = trans_special(&src, (size_t)(end - src) + 1, result + dlen,
                                  FSK_KEYCODE | ((flags & REPTERM_NO_SIMPLIFY) ? 0 : FSK_SIMPLIFY),
                                  true, did_simplify);
      if (slen) {
        dlen += slen;
        continue;
      }
    }

    if (do_special) {
      char *p, *s;
      int len;

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
        if (p == NULL || *p == NUL || strlen(p) > 8 * 6) {
          s = "\\";
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
    char key = *src;
    if (key == Ctrl_V || (do_backslash && key == '\\')) {
      src++;  // skip CTRL-V or backslash
      if (src > end) {
        if (flags & REPTERM_FROM_PART) {
          result[dlen++] = key;
        }
        break;
      }
    }

    // skip multibyte char correctly
    for (ssize_t i = utfc_ptr2len_len(src, (int)(end - src) + 1); i > 0; i--) {
      // If the character is K_SPECIAL, replace it with K_SPECIAL
      // KS_SPECIAL KE_FILLER.
      if (*src == (char)K_SPECIAL) {
        result[dlen++] = (char)K_SPECIAL;
        result[dlen++] = (char)KS_SPECIAL;
        result[dlen++] = KE_FILLER;
      } else {
        result[dlen++] = *src;
      }
      src++;
    }
  }
  result[dlen] = NUL;

  if (allocated) {
    *bufp = xrealloc(result, dlen + 1);
  }

  return *bufp;
}

/// Add character "c" to buffer "s"
///
/// Escapes the special meaning of K_SPECIAL, handles multi-byte
/// characters.
///
/// @param[in]  c  Character to add.
/// @param[out]  s  Buffer to add to. Must have at least MB_MAXBYTES + 1 bytes.
///
/// @return Pointer to after the added bytes.
char *add_char2buf(int c, char *s)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  char temp[MB_MAXBYTES + 1];
  const int len = utf_char2bytes(c, temp);
  for (int i = 0; i < len; i++) {
    c = (uint8_t)temp[i];
    // Need to escape K_SPECIAL like in the typeahead buffer.
    if (c == K_SPECIAL) {
      *s++ = (char)(uint8_t)K_SPECIAL;
      *s++ = (char)(uint8_t)KS_SPECIAL;
      *s++ = KE_FILLER;
    } else {
      *s++ = (char)(uint8_t)c;
    }
  }
  return s;
}

/// Copy "p" to allocated memory, escaping K_SPECIAL so that the result
/// can be put in the typeahead buffer.
char *vim_strsave_escape_ks(char *p)
{
  // Need a buffer to hold up to three times as much.  Four in case of an
  // illegal utf-8 byte:
  // 0xc0 -> 0xc3 - 0x80 -> 0xc3 K_SPECIAL KS_SPECIAL KE_FILLER
  char *res = xmalloc(strlen(p) * 4 + 1);
  char *d = res;
  for (char *s = p; *s != NUL;) {
    if ((uint8_t)s[0] == K_SPECIAL && s[1] != NUL && s[2] != NUL) {
      // Copy special key unmodified.
      *d++ = *s++;
      *d++ = *s++;
      *d++ = *s++;
    } else {
      // Add character, possibly multi-byte to destination, escaping
      // K_SPECIAL. Be careful, it can be an illegal byte!
      d = add_char2buf(utf_ptr2char(s), d);
      s += utf_ptr2len(s);
    }
  }
  *d = NUL;

  return res;
}

/// Remove escaping from K_SPECIAL characters.  Reverse of
/// vim_strsave_escape_ks().  Works in-place.
void vim_unescape_ks(char *p)
{
  uint8_t *s = (uint8_t *)p;
  uint8_t *d = (uint8_t *)p;

  while (*s != NUL) {
    if (s[0] == K_SPECIAL && s[1] == KS_SPECIAL && s[2] == KE_FILLER) {
      *d++ = K_SPECIAL;
      s += 3;
    } else {
      *d++ = *s++;
    }
  }
  *d = NUL;
}
