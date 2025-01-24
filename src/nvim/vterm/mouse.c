#include "nvim/math.h"
#include "nvim/tui/termkey/termkey.h"
#include "nvim/vterm/mouse.h"
#include "nvim/vterm/vterm.h"
#include "nvim/vterm/vterm_internal_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "vterm/mouse.c.generated.h"
#endif

static void output_mouse(VTermState *state, int code, int pressed, int modifiers, int col, int row)
{
  modifiers <<= 2;

  switch (state->mouse_protocol) {
  case MOUSE_X10:
    if (col + 0x21 > 0xff) {
      col = 0xff - 0x21;
    }
    if (row + 0x21 > 0xff) {
      row = 0xff - 0x21;
    }

    if (!pressed) {
      code = 3;
    }

    if (code & 0x80) {
      break;
    }
    vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "M%c%c%c",
                                   (code | modifiers) + 0x20, col + 0x21, row + 0x21);
    break;

  case MOUSE_UTF8: {
    char utf8[18];
    size_t len = 0;

    if (!pressed) {
      code = 3;
    }

    len += (size_t)fill_utf8((code | modifiers) + 0x20, utf8 + len);
    len += (size_t)fill_utf8(col + 0x21, utf8 + len);
    len += (size_t)fill_utf8(row + 0x21, utf8 + len);
    utf8[len] = 0;

    vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "M%s", utf8);
  }
  break;

  case MOUSE_SGR:
    vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "<%d;%d;%d%c",
                                   code | modifiers, col + 1, row + 1, pressed ? 'M' : 'm');
    break;

  case MOUSE_RXVT:
    if (!pressed) {
      code = 3;
    }

    vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "%d;%d;%dM",
                                   code | modifiers, col + 1, row + 1);
    break;
  }
}

void vterm_mouse_move(VTerm *vt, int row, int col, VTermModifier mod)
{
  VTermState *state = vt->state;

  if (col == state->mouse_col && row == state->mouse_row) {
    return;
  }

  state->mouse_col = col;
  state->mouse_row = row;

  if ((state->mouse_flags & MOUSE_WANT_DRAG && state->mouse_buttons)
      || (state->mouse_flags & MOUSE_WANT_MOVE)) {
    if (state->mouse_buttons) {
      int button = xctz((uint64_t)state->mouse_buttons) + 1;
      if (button < 4) {
        output_mouse(state, button - 1 + 0x20, 1, (int)mod, col, row);
      } else if (button >= 8 && button < 12) {
        output_mouse(state, button - 8 + 0x80 + 0x20, 1, (int)mod, col, row);
      }
    } else {
      output_mouse(state, 3 + 0x20, 1, (int)mod, col, row);
    }
  }
}

void vterm_mouse_button(VTerm *vt, int button, bool pressed, VTermModifier mod)
{
  VTermState *state = vt->state;

  int old_buttons = state->mouse_buttons;

  if ((button > 0 && button <= 3) || (button >= 8 && button <= 11)) {
    if (pressed) {
      state->mouse_buttons |= (1 << (button - 1));
    } else {
      state->mouse_buttons &= ~(1 << (button - 1));
    }
  }

  // Most of the time we don't get button releases from 4/5/6/7
  if (state->mouse_buttons == old_buttons && (button < 4 || button > 7)) {
    return;
  }

  if (!state->mouse_flags) {
    return;
  }

  if (button < 4) {
    output_mouse(state, button - 1, pressed, (int)mod, state->mouse_col, state->mouse_row);
  } else if (button < 8) {
    output_mouse(state, button - 4 + 0x40, pressed, (int)mod, state->mouse_col, state->mouse_row);
  } else if (button < 12) {
    output_mouse(state, button - 8 + 0x80, pressed, (int)mod, state->mouse_col, state->mouse_row);
  }
}
