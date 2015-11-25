/************************************************************************
 * functions that use lookup tables for various things, generally to do with
 * special key codes.
 */

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


/*
 * Some useful tables.
 */

static struct modmasktable {
  short mod_mask;               /* Bit-mask for particular key modifier */
  short mod_flag;               /* Bit(s) for particular key modifier */
  char_u name;                  /* Single letter name of modifier */
} mod_mask_table[] =
{
  {MOD_MASK_ALT,              MOD_MASK_ALT,           (char_u)'M'},
  {MOD_MASK_META,             MOD_MASK_META,          (char_u)'T'},
  {MOD_MASK_CTRL,             MOD_MASK_CTRL,          (char_u)'C'},
  {MOD_MASK_SHIFT,            MOD_MASK_SHIFT,         (char_u)'S'},
  {MOD_MASK_MULTI_CLICK,      MOD_MASK_2CLICK,        (char_u)'2'},
  {MOD_MASK_MULTI_CLICK,      MOD_MASK_3CLICK,        (char_u)'3'},
  {MOD_MASK_MULTI_CLICK,      MOD_MASK_4CLICK,        (char_u)'4'},
  /* 'A' must be the last one */
  {MOD_MASK_ALT,              MOD_MASK_ALT,           (char_u)'A'},
  {0, 0, NUL}
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

static struct key_name_entry {
  int key;              /* Special key code or ascii value */
  char_u  *name;        /* Name of key */
} key_names_table[] =
{
  {' ',               (char_u *)"Space"},
  {TAB,               (char_u *)"Tab"},
  {K_TAB,             (char_u *)"Tab"},
  {NL,                (char_u *)"NL"},
  {NL,                (char_u *)"NewLine"},     /* Alternative name */
  {NL,                (char_u *)"LineFeed"},    /* Alternative name */
  {NL,                (char_u *)"LF"},          /* Alternative name */
  {CAR,               (char_u *)"CR"},
  {CAR,               (char_u *)"Return"},      /* Alternative name */
  {CAR,               (char_u *)"Enter"},       /* Alternative name */
  {K_BS,              (char_u *)"BS"},
  {K_BS,              (char_u *)"BackSpace"},   /* Alternative name */
  {ESC,               (char_u *)"Esc"},
  {CSI,               (char_u *)"CSI"},
  {K_CSI,             (char_u *)"xCSI"},
  {'|',               (char_u *)"Bar"},
  {'\\',              (char_u *)"Bslash"},
  {K_DEL,             (char_u *)"Del"},
  {K_DEL,             (char_u *)"Delete"},      /* Alternative name */
  {K_KDEL,            (char_u *)"kDel"},
  {K_UP,              (char_u *)"Up"},
  {K_DOWN,            (char_u *)"Down"},
  {K_LEFT,            (char_u *)"Left"},
  {K_RIGHT,           (char_u *)"Right"},
  {K_XUP,             (char_u *)"xUp"},
  {K_XDOWN,           (char_u *)"xDown"},
  {K_XLEFT,           (char_u *)"xLeft"},
  {K_XRIGHT,          (char_u *)"xRight"},

  {K_F1,              (char_u *)"F1"},
  {K_F2,              (char_u *)"F2"},
  {K_F3,              (char_u *)"F3"},
  {K_F4,              (char_u *)"F4"},
  {K_F5,              (char_u *)"F5"},
  {K_F6,              (char_u *)"F6"},
  {K_F7,              (char_u *)"F7"},
  {K_F8,              (char_u *)"F8"},
  {K_F9,              (char_u *)"F9"},
  {K_F10,             (char_u *)"F10"},

  {K_F11,             (char_u *)"F11"},
  {K_F12,             (char_u *)"F12"},
  {K_F13,             (char_u *)"F13"},
  {K_F14,             (char_u *)"F14"},
  {K_F15,             (char_u *)"F15"},
  {K_F16,             (char_u *)"F16"},
  {K_F17,             (char_u *)"F17"},
  {K_F18,             (char_u *)"F18"},
  {K_F19,             (char_u *)"F19"},
  {K_F20,             (char_u *)"F20"},

  {K_F21,             (char_u *)"F21"},
  {K_F22,             (char_u *)"F22"},
  {K_F23,             (char_u *)"F23"},
  {K_F24,             (char_u *)"F24"},
  {K_F25,             (char_u *)"F25"},
  {K_F26,             (char_u *)"F26"},
  {K_F27,             (char_u *)"F27"},
  {K_F28,             (char_u *)"F28"},
  {K_F29,             (char_u *)"F29"},
  {K_F30,             (char_u *)"F30"},

  {K_F31,             (char_u *)"F31"},
  {K_F32,             (char_u *)"F32"},
  {K_F33,             (char_u *)"F33"},
  {K_F34,             (char_u *)"F34"},
  {K_F35,             (char_u *)"F35"},
  {K_F36,             (char_u *)"F36"},
  {K_F37,             (char_u *)"F37"},

  {K_XF1,             (char_u *)"xF1"},
  {K_XF2,             (char_u *)"xF2"},
  {K_XF3,             (char_u *)"xF3"},
  {K_XF4,             (char_u *)"xF4"},

  {K_HELP,            (char_u *)"Help"},
  {K_UNDO,            (char_u *)"Undo"},
  {K_INS,             (char_u *)"Insert"},
  {K_INS,             (char_u *)"Ins"},         /* Alternative name */
  {K_KINS,            (char_u *)"kInsert"},
  {K_HOME,            (char_u *)"Home"},
  {K_KHOME,           (char_u *)"kHome"},
  {K_XHOME,           (char_u *)"xHome"},
  {K_ZHOME,           (char_u *)"zHome"},
  {K_END,             (char_u *)"End"},
  {K_KEND,            (char_u *)"kEnd"},
  {K_XEND,            (char_u *)"xEnd"},
  {K_ZEND,            (char_u *)"zEnd"},
  {K_PAGEUP,          (char_u *)"PageUp"},
  {K_PAGEDOWN,        (char_u *)"PageDown"},
  {K_KPAGEUP,         (char_u *)"kPageUp"},
  {K_KPAGEDOWN,       (char_u *)"kPageDown"},

  {K_KPLUS,           (char_u *)"kPlus"},
  {K_KMINUS,          (char_u *)"kMinus"},
  {K_KDIVIDE,         (char_u *)"kDivide"},
  {K_KMULTIPLY,       (char_u *)"kMultiply"},
  {K_KENTER,          (char_u *)"kEnter"},
  {K_KPOINT,          (char_u *)"kPoint"},

  {K_K0,              (char_u *)"k0"},
  {K_K1,              (char_u *)"k1"},
  {K_K2,              (char_u *)"k2"},
  {K_K3,              (char_u *)"k3"},
  {K_K4,              (char_u *)"k4"},
  {K_K5,              (char_u *)"k5"},
  {K_K6,              (char_u *)"k6"},
  {K_K7,              (char_u *)"k7"},
  {K_K8,              (char_u *)"k8"},
  {K_K9,              (char_u *)"k9"},

  {'<',               (char_u *)"lt"},

  {K_MOUSE,           (char_u *)"Mouse"},
  {K_LEFTMOUSE,       (char_u *)"LeftMouse"},
  {K_LEFTMOUSE_NM,    (char_u *)"LeftMouseNM"},
  {K_LEFTDRAG,        (char_u *)"LeftDrag"},
  {K_LEFTRELEASE,     (char_u *)"LeftRelease"},
  {K_LEFTRELEASE_NM,  (char_u *)"LeftReleaseNM"},
  {K_MIDDLEMOUSE,     (char_u *)"MiddleMouse"},
  {K_MIDDLEDRAG,      (char_u *)"MiddleDrag"},
  {K_MIDDLERELEASE,   (char_u *)"MiddleRelease"},
  {K_RIGHTMOUSE,      (char_u *)"RightMouse"},
  {K_RIGHTDRAG,       (char_u *)"RightDrag"},
  {K_RIGHTRELEASE,    (char_u *)"RightRelease"},
  {K_MOUSEDOWN,       (char_u *)"ScrollWheelUp"},
  {K_MOUSEUP,         (char_u *)"ScrollWheelDown"},
  {K_MOUSELEFT,       (char_u *)"ScrollWheelRight"},
  {K_MOUSERIGHT,      (char_u *)"ScrollWheelLeft"},
  {K_MOUSEDOWN,       (char_u *)"MouseDown"},   /* OBSOLETE: Use	  */
  {K_MOUSEUP,         (char_u *)"MouseUp"},     /* ScrollWheelXXX instead */
  {K_X1MOUSE,         (char_u *)"X1Mouse"},
  {K_X1DRAG,          (char_u *)"X1Drag"},
  {K_X1RELEASE,               (char_u *)"X1Release"},
  {K_X2MOUSE,         (char_u *)"X2Mouse"},
  {K_X2DRAG,          (char_u *)"X2Drag"},
  {K_X2RELEASE,               (char_u *)"X2Release"},
  {K_DROP,            (char_u *)"Drop"},
  {K_ZERO,            (char_u *)"Nul"},
  {K_SNR,             (char_u *)"SNR"},
  {K_PLUG,            (char_u *)"Plug"},
  {K_PASTE,           (char_u *)"Paste"},
  {K_FOCUSGAINED,     (char_u *)"FocusGained"},
  {K_FOCUSLOST,       (char_u *)"FocusLost"},
  {0,                 NULL}
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

/*
 * Return the modifier mask bit (MOD_MASK_*) which corresponds to the given
 * modifier name ('S' for Shift, 'C' for Ctrl etc).
 */
int name_to_mod_mask(int c)
{
  int i;

  c = TOUPPER_ASC(c);
  for (i = 0; mod_mask_table[i].mod_mask != 0; i++)
    if (c == mod_mask_table[i].name)
      return mod_mask_table[i].mod_flag;
  return 0;
}

/*
 * Check if if there is a special key code for "key" that includes the
 * modifiers specified.
 */
int simplify_key(int key, int *modifiers)
{
  int i;
  int key0;
  int key1;

  if (*modifiers & (MOD_MASK_SHIFT | MOD_MASK_CTRL | MOD_MASK_ALT)) {
    /* TAB is a special case */
    if (key == TAB && (*modifiers & MOD_MASK_SHIFT)) {
      *modifiers &= ~MOD_MASK_SHIFT;
      return K_S_TAB;
    }
    key0 = KEY2TERMCAP0(key);
    key1 = KEY2TERMCAP1(key);
    for (i = 0; modifier_keys_table[i] != NUL; i += MOD_KEYS_ENTRY_SIZE)
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

/*
 * Change <xHome> to <Home>, <xUp> to <Up>, etc.
 */
int handle_x_keys(int key)
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
    }
    /* Not a special key, only modifiers, output directly */
    else {
      if (has_mbyte && (*mb_char2len)(c) > 1)
        idx += (*mb_char2bytes)(c, string + idx);
      else if (vim_isprintc(c))
        string[idx++] = (char_u)c;
      else {
        s = transchar(c);
        while (*s)
          string[idx++] = *s++;
      }
    }
  } else {            /* use name of special key */
    STRCPY(string + idx, key_names_table[table_idx].name);
    idx = (int)STRLEN(string);
  }
  string[idx++] = '>';
  string[idx] = NUL;
  return string;
}

/*
 * Try translating a <> name at (*srcp)[] to dst[].
 * Return the number of characters added to dst[], zero for no match.
 * If there is a match, srcp is advanced to after the <> name.
 * dst[] must be big enough to hold the result (up to six characters)!
 */
unsigned int 
trans_special (
    char_u **srcp,
    char_u *dst,
    int keycode             /* prefer key code, e.g. K_DEL instead of DEL */
)
{
  int modifiers = 0;
  int key;
  unsigned int dlen = 0;

  key = find_special_key(srcp, &modifiers, keycode, FALSE);
  if (key == 0)
    return 0;

  /* Put the appropriate modifier in a string */
  if (modifiers != 0) {
    dst[dlen++] = K_SPECIAL;
    dst[dlen++] = KS_MODIFIER;
    dst[dlen++] = (char_u)modifiers;
  }

  if (IS_SPECIAL(key)) {
    dst[dlen++] = K_SPECIAL;
    dst[dlen++] = (char_u)KEY2TERMCAP0(key);
    dst[dlen++] = KEY2TERMCAP1(key);
  } else if (has_mbyte && !keycode)
    dlen += (unsigned int)(*mb_char2bytes)(key, dst + dlen);
  else if (keycode) {
    char_u *after = add_char2buf(key, dst + dlen);
    assert(after >= dst && (uintmax_t)(after - dst) <= UINT_MAX);
    dlen = (unsigned int)(after - dst);
  }
  else
    dst[dlen++] = (char_u)key;

  return dlen;
}

/*
 * Try translating a <> name at (*srcp)[], return the key and modifiers.
 * srcp is advanced to after the <> name.
 * returns 0 if there is no match.
 */
int 
find_special_key (
    char_u **srcp,
    int *modp,
    int keycode,                 /* prefer key code, e.g. K_DEL instead of DEL */
    int keep_x_key              /* don't translate xHome to Home key */
)
{
  char_u      *last_dash;
  char_u      *end_of_name;
  char_u      *src;
  char_u      *bp;
  int modifiers;
  int bit;
  int key;
  unsigned long n;
  int l;

  src = *srcp;
  if (src[0] != '<')
    return 0;

  /* Find end of modifier list */
  last_dash = src;
  for (bp = src + 1; *bp == '-' || vim_isIDc(*bp); bp++) {
    if (*bp == '-') {
      last_dash = bp;
      if (bp[1] != NUL) {
        if (has_mbyte)
          l = mb_ptr2len(bp + 1);
        else
          l = 1;
        if (bp[l + 1] == '>')
          bp += l;              /* anything accepted, like <C-?> */
      }
    }
    if (bp[0] == 't' && bp[1] == '_' && bp[2] && bp[3])
      bp += 3;          /* skip t_xx, xx may be '-' or '>' */
    else if (STRNICMP(bp, "char-", 5) == 0) {
      vim_str2nr(bp + 5, NULL, &l, TRUE, TRUE, NULL, NULL);
      bp += l + 5;
      break;
    }
  }

  if (*bp == '>') {     /* found matching '>' */
    end_of_name = bp + 1;

    /* Which modifiers are given? */
    modifiers = 0x0;
    for (bp = src + 1; bp < last_dash; bp++) {
      if (*bp != '-') {
        bit = name_to_mod_mask(*bp);
        if (bit == 0x0)
          break;                /* Illegal modifier name */
        modifiers |= bit;
      }
    }

    /*
     * Legal modifier name.
     */
    if (bp >= last_dash) {
      if (STRNICMP(last_dash + 1, "char-", 5) == 0
          && ascii_isdigit(last_dash[6])) {
        /* <Char-123> or <Char-033> or <Char-0x33> */
        vim_str2nr(last_dash + 6, NULL, NULL, TRUE, TRUE, NULL, &n);
        key = (int)n;
      } else {
        /*
         * Modifier with single letter, or special key name.
         */
        if (has_mbyte)
          l = mb_ptr2len(last_dash + 1);
        else
          l = 1;
        if (modifiers != 0 && last_dash[l + 1] == '>')
          key = PTR2CHAR(last_dash + 1);
        else {
          key = get_special_key_code(last_dash + 1);
          if (!keep_x_key)
            key = handle_x_keys(key);
        }
      }

      /*
       * get_special_key_code() may return NUL for invalid
       * special key name.
       */
      if (key != NUL) {
        /*
         * Only use a modifier when there is no special key code that
         * includes the modifier.
         */
        key = simplify_key(key, &modifiers);

        if (!keycode) {
          /* don't want keycode, use single byte code */
          if (key == K_BS)
            key = BS;
          else if (key == K_DEL || key == K_KDEL)
            key = DEL;
        }

        /*
         * Normal Key with modifier: Try to make a single byte code.
         */
        if (!IS_SPECIAL(key))
          key = extract_modifiers(key, &modifiers);

        *modp = modifiers;
        *srcp = end_of_name;
        return key;
      }
    }
  }
  return 0;
}

/*
 * Try to include modifiers in the key.
 * Changes "Shift-a" to 'A', "Alt-A" to 0xc0, etc.
 */
int extract_modifiers(int key, int *modp)
{
  int modifiers = *modp;

  if ((modifiers & MOD_MASK_SHIFT) && ASCII_ISALPHA(key)) {
    key = TOUPPER_ASC(key);
    modifiers &= ~MOD_MASK_SHIFT;
  }
  if ((modifiers & MOD_MASK_CTRL)
      && ((key >= '?' && key <= '_') || ASCII_ISALPHA(key))
      ) {
    key = Ctrl_chr(key);
    modifiers &= ~MOD_MASK_CTRL;
    /* <C-@> is <Nul> */
    if (key == 0)
      key = K_ZERO;
  }
  if ((modifiers & MOD_MASK_ALT) && key < 0x80
      && !enc_dbcs                      /* avoid creating a lead byte */
      ) {
    key |= 0x80;
    modifiers &= ~MOD_MASK_ALT;         /* remove the META modifier */
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

  for (i = 0; key_names_table[i].name != NULL; i++)
    if (c == key_names_table[i].key)
      break;
  if (key_names_table[i].name == NULL)
    i = -1;
  return i;
}

/*
 * Find the special key with the given name (the given string does not have to
 * end with NUL, the name is assumed to end before the first non-idchar).
 * If the name starts with "t_" the next two characters are interpreted as a
 * termcap name.
 * Return the key code, or 0 if not found.
 */
int get_special_key_code(char_u *name)
{
  char_u  *table_name;
  int i, j;

  for (i = 0; key_names_table[i].name != NULL; i++) {
    table_name = key_names_table[i].name;
    for (j = 0; vim_isIDc(name[j]) && table_name[j] != NUL; j++)
      if (TOLOWER_ASC(table_name[j]) != TOLOWER_ASC(name[j]))
        break;
    if (!vim_isIDc(name[j]) && table_name[j] == NUL)
      return key_names_table[i].key;
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

// Replace any terminal code strings in from[] with the equivalent internal
// vim representation.	This is used for the "from" and "to" part of a
// mapping, and the "to" part of a menu command.
// Any strings like "<C-UP>" are also replaced, unless 'cpoptions' contains
// '<'.
// K_SPECIAL by itself is replaced by K_SPECIAL KS_SPECIAL KE_FILLER.
//
// The replacement is done in result[] and finally copied into allocated
// memory. If this all works well *bufp is set to the allocated memory and a
// pointer to it is returned. If something fails *bufp is set to NULL and from
// is returned.
//
// CTRL-V characters are removed.  When "from_part" is TRUE, a trailing CTRL-V
// is included, otherwise it is removed (for ":map xx ^V", maps xx to
// nothing).  When 'cpoptions' does not contain 'B', a backslash can be used
// instead of a CTRL-V.
char_u * replace_termcodes (
    char_u *from,
    char_u **bufp,
    int from_part,
    int do_lt,                     // also translate <lt>
    int special                    // always accept <key> notation
)
{
  ssize_t i;
  size_t slen;
  char_u key;
  size_t dlen = 0;
  char_u      *src;
  int do_backslash;             // backslash is a special character
  int do_special;               // recognize <> key codes
  char_u      *result;          // buffer for resulting string

  do_backslash = (vim_strchr(p_cpo, CPO_BSLASH) == NULL);
  do_special = (vim_strchr(p_cpo, CPO_SPECI) == NULL) || special;

  // Allocate space for the translation.  Worst case a single character is
  // replaced by 6 bytes (shifted special key), plus a NUL at the end.
  result = xmalloc(STRLEN(from) * 6 + 1);

  src = from;

  // Check for #n at start only: function key n
  if (from_part && src[0] == '#' && ascii_isdigit(src[1])) {  // function key
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
  while (*src != NUL) {
    // If 'cpoptions' does not contain '<', check for special key codes,
    // like "<C-S-LeftMouse>"
    if (do_special && (do_lt || STRNCMP(src, "<lt>", 4) != 0)) {
      // Replace <SID> by K_SNR <script-nr> _.
      // (room: 5 * 6 = 30 bytes; needed: 3 + <nr> + 1 <= 14)
      if (STRNICMP(src, "<SID>", 5) == 0) {
        if (current_SID <= 0) {
          EMSG(_(e_usingsid));
        } else {
          src += 5;
          result[dlen++] = K_SPECIAL;
          result[dlen++] = (int)KS_EXTRA;
          result[dlen++] = (int)KE_SNR;
          sprintf((char *)result + dlen, "%" PRId64, (int64_t)current_SID);
          dlen += STRLEN(result + dlen);
          result[dlen++] = '_';
          continue;
        }
      }

      slen = trans_special(&src, result + dlen, TRUE);
      if (slen) {
        dlen += slen;
        continue;
      }
    }

    if (do_special) {
      char_u  *p, *s, len;

      // Replace <Leader> by the value of "mapleader".
      // Replace <LocalLeader> by the value of "maplocalleader".
      // If "mapleader" or "maplocalleader" isn't set use a backslash.
      if (STRNICMP(src, "<Leader>", 8) == 0) {
        len = 8;
        p = get_var_value((char_u *)"g:mapleader");
      } else if (STRNICMP(src, "<LocalLeader>", 13) == 0)   {
        len = 13;
        p = get_var_value((char_u *)"g:maplocalleader");
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
      ++src;  // skip CTRL-V or backslash
      if (*src == NUL) {
        if (from_part) {
          result[dlen++] = key;
        }
        break;
      }
    }

    // skip multibyte char correctly
    for (i = (*mb_ptr2len)(src); i > 0; --i) {
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

