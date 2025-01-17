#include <stdio.h>

#include "nvim/ascii_defs.h"
#include "nvim/tui/termkey/termkey.h"
#include "nvim/vterm/keyboard.h"
#include "nvim/vterm/vterm.h"
#include "nvim/vterm/vterm_internal_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "vterm/keyboard.c.generated.h"
#endif

static VTermKeyEncodingFlags vterm_state_get_key_encoding_flags(const VTermState *state)
{
  int screen = state->mode.alt_screen ? BUFIDX_ALTSCREEN : BUFIDX_PRIMARY;
  const struct VTermKeyEncodingStack *stack = &state->key_encoding_stacks[screen];
  assert(stack->size > 0);
  return stack->items[stack->size - 1];
}

void vterm_keyboard_unichar(VTerm *vt, uint32_t c, VTermModifier mod)
{
  bool passthru = false;
  if (c == ' ') {
    // Space is passed through only when there are no modifiers (including shift)
    passthru = mod == VTERM_MOD_NONE;
  } else {
    // Otherwise pass through when there are no modifiers (ignoring shift)
    passthru = (mod & (unsigned)~VTERM_MOD_SHIFT) == 0;
  }

  if (passthru) {
    char str[6];
    int seqlen = fill_utf8((int)c, str);
    vterm_push_output_bytes(vt, str, (size_t)seqlen);
    return;
  }

  VTermKeyEncodingFlags flags = vterm_state_get_key_encoding_flags(vt->state);
  if (flags.disambiguate) {
    // Always use unshifted codepoint
    if (c >= 'A' && c <= 'Z') {
      c += 'a' - 'A';
      mod |= VTERM_MOD_SHIFT;
    }

    vterm_push_output_sprintf_ctrl(vt, C1_CSI, "%d;%du", c, mod + 1);
    return;
  }

  if (mod & VTERM_MOD_CTRL) {
    // Handle special cases. These are taken from kitty, but seem mostly
    // consistent across terminals.
    switch (c) {
    case '2':
    case ' ':
      // Ctrl+2 is NUL to match Ctrl+@ (which is Shift+2 on US keyboards)
      // Ctrl+Space is also NUL for some reason
      c = 0x00;
      break;
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
      // Ctrl+3 through Ctrl+7 are sequential starting from 0x1b. Importantly,
      // this means that Ctrl+6 emits 0x1e (the same as Ctrl+^ on US keyboards)
      c = 0x1b + c - '3';
      break;
    case '8':
      // Ctrl+8 is DEL
      c = 0x7f;
      break;
    case '/':
      // Ctrl+/ is equivalent to Ctrl+_ for historic reasons
      c = 0x1f;
      break;
    default:
      if (c >= '@' && c <= 0x7f) {
        c &= 0x1f;
      }
      break;
    }
  }

  vterm_push_output_sprintf(vt, "%s%c", mod & VTERM_MOD_ALT ? ESC_S : "", c);
}

typedef struct {
  enum {
    KEYCODE_NONE,
    KEYCODE_LITERAL,
    KEYCODE_TAB,
    KEYCODE_ENTER,
    KEYCODE_SS3,
    KEYCODE_CSI,
    KEYCODE_CSI_CURSOR,
    KEYCODE_CSINUM,
    KEYCODE_KEYPAD,
  } type;
  int literal;
  int csinum;
} keycodes_s;

static keycodes_s keycodes[] = {
  { KEYCODE_NONE, NUL, 0 },  // NONE

  { KEYCODE_ENTER,   '\r',   0 },  // ENTER
  { KEYCODE_TAB,     '\t',   0 },  // TAB
  { KEYCODE_LITERAL, '\x7f', 0 },  // BACKSPACE == ASCII DEL
  { KEYCODE_LITERAL, '\x1b', 0 },  // ESCAPE

  { KEYCODE_CSI_CURSOR, 'A', 0 },  // UP
  { KEYCODE_CSI_CURSOR, 'B', 0 },  // DOWN
  { KEYCODE_CSI_CURSOR, 'D', 0 },  // LEFT
  { KEYCODE_CSI_CURSOR, 'C', 0 },  // RIGHT

  { KEYCODE_CSINUM, '~', 2     },  // INS
  { KEYCODE_CSINUM, '~', 3     },  // DEL
  { KEYCODE_CSI_CURSOR, 'H', 0 },  // HOME
  { KEYCODE_CSI_CURSOR, 'F', 0 },  // END
  { KEYCODE_CSINUM, '~', 5     },  // PAGEUP
  { KEYCODE_CSINUM, '~', 6     },  // PAGEDOWN
};

static keycodes_s keycodes_fn[] = {
  { KEYCODE_NONE,   NUL,  0 },    // F0 - shouldn't happen
  { KEYCODE_SS3,    'P',  0 },    // F1
  { KEYCODE_SS3,    'Q',  0 },    // F2
  { KEYCODE_SS3,    'R',  0 },    // F3
  { KEYCODE_SS3,    'S',  0 },    // F4
  { KEYCODE_CSINUM, '~',  15 },   // F5
  { KEYCODE_CSINUM, '~',  17 },   // F6
  { KEYCODE_CSINUM, '~',  18 },   // F7
  { KEYCODE_CSINUM, '~',  19 },   // F8
  { KEYCODE_CSINUM, '~',  20 },   // F9
  { KEYCODE_CSINUM, '~',  21 },   // F10
  { KEYCODE_CSINUM, '~',  23 },   // F11
  { KEYCODE_CSINUM, '~',  24 },   // F12
};

static keycodes_s keycodes_kp[] = {
  { KEYCODE_KEYPAD, '0',  'p' },  // KP_0
  { KEYCODE_KEYPAD, '1',  'q' },  // KP_1
  { KEYCODE_KEYPAD, '2',  'r' },  // KP_2
  { KEYCODE_KEYPAD, '3',  's' },  // KP_3
  { KEYCODE_KEYPAD, '4',  't' },  // KP_4
  { KEYCODE_KEYPAD, '5',  'u' },  // KP_5
  { KEYCODE_KEYPAD, '6',  'v' },  // KP_6
  { KEYCODE_KEYPAD, '7',  'w' },  // KP_7
  { KEYCODE_KEYPAD, '8',  'x' },  // KP_8
  { KEYCODE_KEYPAD, '9',  'y' },  // KP_9
  { KEYCODE_KEYPAD, '*',  'j' },  // KP_MULT
  { KEYCODE_KEYPAD, '+',  'k' },  // KP_PLUS
  { KEYCODE_KEYPAD, ',',  'l' },  // KP_COMMA
  { KEYCODE_KEYPAD, '-',  'm' },  // KP_MINUS
  { KEYCODE_KEYPAD, '.',  'n' },  // KP_PERIOD
  { KEYCODE_KEYPAD, '/',  'o' },  // KP_DIVIDE
  { KEYCODE_KEYPAD, '\n', 'M' },  // KP_ENTER
  { KEYCODE_KEYPAD, '=',  'X' },  // KP_EQUAL
};

static keycodes_s keycodes_kp_csiu[] = {
  { KEYCODE_KEYPAD, 57399, 'p' },  // KP_0
  { KEYCODE_KEYPAD, 57400, 'q' },  // KP_1
  { KEYCODE_KEYPAD, 57401, 'r' },  // KP_2
  { KEYCODE_KEYPAD, 57402, 's' },  // KP_3
  { KEYCODE_KEYPAD, 57403, 't' },  // KP_4
  { KEYCODE_KEYPAD, 57404, 'u' },  // KP_5
  { KEYCODE_KEYPAD, 57405, 'v' },  // KP_6
  { KEYCODE_KEYPAD, 57406, 'w' },  // KP_7
  { KEYCODE_KEYPAD, 57407, 'x' },  // KP_8
  { KEYCODE_KEYPAD, 57408, 'y' },  // KP_9
  { KEYCODE_KEYPAD, 57411, 'j' },  // KP_MULT
  { KEYCODE_KEYPAD, 57413, 'k' },  // KP_PLUS
  { KEYCODE_KEYPAD, 57416, 'l' },  // KP_COMMA
  { KEYCODE_KEYPAD, 57412, 'm' },  // KP_MINUS
  { KEYCODE_KEYPAD, 57409, 'n' },  // KP_PERIOD
  { KEYCODE_KEYPAD, 57410, 'o' },  // KP_DIVIDE
  { KEYCODE_KEYPAD, 57414, 'M' },  // KP_ENTER
  { KEYCODE_KEYPAD, 57415, 'X' },  // KP_EQUAL
};

void vterm_keyboard_key(VTerm *vt, VTermKey key, VTermModifier mod)
{
  if (key == VTERM_KEY_NONE) {
    return;
  }

  VTermKeyEncodingFlags flags = vterm_state_get_key_encoding_flags(vt->state);

  keycodes_s k;
  if (key < VTERM_KEY_FUNCTION_0) {
    if (key >= sizeof(keycodes)/sizeof(keycodes[0])) {
      return;
    }
    k = keycodes[key];
  } else if (key >= VTERM_KEY_FUNCTION_0 && key <= VTERM_KEY_FUNCTION_MAX) {
    if ((key - VTERM_KEY_FUNCTION_0) >= sizeof(keycodes_fn)/sizeof(keycodes_fn[0])) {
      return;
    }
    k = keycodes_fn[key - VTERM_KEY_FUNCTION_0];
  } else if (key >= VTERM_KEY_KP_0) {
    if ((key - VTERM_KEY_KP_0) >= sizeof(keycodes_kp)/sizeof(keycodes_kp[0])) {
      return;
    }

    if (flags.disambiguate) {
      k = keycodes_kp_csiu[key - VTERM_KEY_KP_0];
    } else {
      k = keycodes_kp[key - VTERM_KEY_KP_0];
    }
  }

  switch (k.type) {
  case KEYCODE_NONE:
    break;

  case KEYCODE_TAB:
    // Shift-Tab is CSI Z but plain Tab is 0x09
    if (flags.disambiguate) {
      goto case_LITERAL;
    } else if (mod == VTERM_MOD_SHIFT) {
      vterm_push_output_sprintf_ctrl(vt, C1_CSI, "Z");
    } else if (mod & VTERM_MOD_SHIFT) {
      vterm_push_output_sprintf_ctrl(vt, C1_CSI, "1;%dZ", mod + 1);
    } else {
      goto case_LITERAL;
    }
    break;

  case KEYCODE_ENTER:
    // Enter is CRLF in newline mode, but just LF in linefeed
    if (vt->state->mode.newline) {
      vterm_push_output_sprintf(vt, "\r\n");
    } else {
      goto case_LITERAL;
    }
    break;

  case KEYCODE_LITERAL:
                        case_LITERAL:
    if (flags.disambiguate) {
      switch (key) {
      case VTERM_KEY_TAB:
      case VTERM_KEY_ENTER:
      case VTERM_KEY_BACKSPACE:
        // If there are no mods then leave these as-is
        flags.disambiguate = mod != VTERM_MOD_NONE;
        break;
      default:
        break;
      }
    }

    if (flags.disambiguate) {
      vterm_push_output_sprintf_ctrl(vt, C1_CSI, "%d;%du", k.literal, mod + 1);
    } else {
      vterm_push_output_sprintf(vt, mod & VTERM_MOD_ALT ? ESC_S "%c" : "%c", k.literal);
    }
    break;

  case KEYCODE_SS3:
                    case_SS3:
    if (mod == 0) {
      vterm_push_output_sprintf_ctrl(vt, C1_SS3, "%c", k.literal);
    } else {
      goto case_CSI;
    }
    break;

  case KEYCODE_CSI:
                    case_CSI:
    if (mod == 0) {
      vterm_push_output_sprintf_ctrl(vt, C1_CSI, "%c", k.literal);
    } else {
      vterm_push_output_sprintf_ctrl(vt, C1_CSI, "1;%d%c", mod + 1, k.literal);
    }
    break;

  case KEYCODE_CSINUM:
    if (mod == 0) {
      vterm_push_output_sprintf_ctrl(vt, C1_CSI, "%d%c", k.csinum, k.literal);
    } else {
      vterm_push_output_sprintf_ctrl(vt, C1_CSI, "%d;%d%c", k.csinum, mod + 1, k.literal);
    }
    break;

  case KEYCODE_CSI_CURSOR:
    if (vt->state->mode.cursor) {
      goto case_SS3;
    } else {
      goto case_CSI;
    }

  case KEYCODE_KEYPAD:
    if (vt->state->mode.keypad) {
      k.literal = k.csinum;
      goto case_SS3;
    } else {
      goto case_LITERAL;
    }
  }
}

void vterm_keyboard_start_paste(VTerm *vt)
{
  if (vt->state->mode.bracketpaste) {
    vterm_push_output_sprintf_ctrl(vt, C1_CSI, "200~");
  }
}

void vterm_keyboard_end_paste(VTerm *vt)
{
  if (vt->state->mode.bracketpaste) {
    vterm_push_output_sprintf_ctrl(vt, C1_CSI, "201~");
  }
}
