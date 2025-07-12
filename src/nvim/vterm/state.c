#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "nvim/grid.h"
#include "nvim/mbyte.h"
#include "nvim/vterm/encoding.h"
#include "nvim/vterm/parser.h"
#include "nvim/vterm/pen.h"
#include "nvim/vterm/state.h"
#include "nvim/vterm/vterm.h"
#include "nvim/vterm/vterm_internal_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "vterm/state.c.generated.h"
#endif

#define strneq(a, b, n) (strncmp(a, b, n) == 0)

// Primary Device Attributes (DA1) response.
// We make this a global (extern) variable so that we can override it with FFI
// in tests.
char vterm_primary_device_attr[] = "61;22;52";

// Some convenient wrappers to make callback functions easier

static void putglyph(VTermState *state, const schar_T schar, int width, VTermPos pos)
{
  VTermGlyphInfo info = {
    .schar = schar,
    .width = width,
    .protected_cell = state->protected_cell,
    .dwl = state->lineinfo[pos.row].doublewidth,
    .dhl = state->lineinfo[pos.row].doubleheight,
  };

  if (state->callbacks && state->callbacks->putglyph) {
    if ((*state->callbacks->putglyph)(&info, pos, state->cbdata)) {
      return;
    }
  }

  DEBUG_LOG("libvterm: Unhandled putglyph U+%04x at (%d,%d)\n", chars[0], pos.col, pos.row);
}

static void updatecursor(VTermState *state, VTermPos *oldpos, int cancel_phantom)
{
  if (state->pos.col == oldpos->col && state->pos.row == oldpos->row) {
    return;
  }

  if (cancel_phantom) {
    state->at_phantom = 0;
  }

  if (state->callbacks && state->callbacks->movecursor) {
    if ((*state->callbacks->movecursor)(state->pos, *oldpos, state->mode.cursor_visible,
                                        state->cbdata)) {
      return;
    }
  }
}

static void erase(VTermState *state, VTermRect rect, int selective)
{
  if (rect.end_col == state->cols) {
    // If we're erasing the final cells of any lines, cancel the continuation marker on the
    // subsequent line
    for (int row = rect.start_row + 1; row < rect.end_row + 1 && row < state->rows; row++) {
      state->lineinfo[row].continuation = 0;
    }
  }

  if (state->callbacks && state->callbacks->erase) {
    if ((*state->callbacks->erase)(rect, selective, state->cbdata)) {
      return;
    }
  }
}

static VTermState *vterm_state_new(VTerm *vt)
{
  VTermState *state = vterm_allocator_malloc(vt, sizeof(VTermState));

  state->vt = vt;

  state->rows = vt->rows;
  state->cols = vt->cols;

  state->mouse_col = 0;
  state->mouse_row = 0;
  state->mouse_buttons = 0;

  state->mouse_protocol = MOUSE_X10;

  state->callbacks = NULL;
  state->cbdata = NULL;

  state->selection.callbacks = NULL;
  state->selection.user = NULL;
  state->selection.buffer = NULL;

  vterm_state_newpen(state);

  state->bold_is_highbright = 0;

  state->combine_pos.row = -1;

  state->tabstops = vterm_allocator_malloc(state->vt, ((size_t)state->cols + 7) / 8);

  state->lineinfos[BUFIDX_PRIMARY] = vterm_allocator_malloc(state->vt,
                                                            (size_t)state->rows *
                                                            sizeof(VTermLineInfo));
  // TODO(vterm): Make an 'enable' function
  state->lineinfos[BUFIDX_ALTSCREEN] = vterm_allocator_malloc(state->vt,
                                                              (size_t)state->rows *
                                                              sizeof(VTermLineInfo));
  state->lineinfo = state->lineinfos[BUFIDX_PRIMARY];

  state->encoding_utf8.enc = vterm_lookup_encoding(ENC_UTF8, 'u');
  if (*state->encoding_utf8.enc->init) {
    (*state->encoding_utf8.enc->init)(state->encoding_utf8.enc, state->encoding_utf8.data);
  }

  for (size_t i = 0; i < ARRAY_SIZE(state->key_encoding_stacks); i++) {
    struct VTermKeyEncodingStack *stack = &state->key_encoding_stacks[i];
    for (size_t j = 0; j < ARRAY_SIZE(stack->items); j++) {
      memset(&stack->items[j], 0, sizeof(stack->items[j]));
    }

    stack->size = 1;
  }

  return state;
}

void vterm_state_free(VTermState *state)
{
  vterm_allocator_free(state->vt, state->tabstops);
  vterm_allocator_free(state->vt, state->lineinfos[BUFIDX_PRIMARY]);
  if (state->lineinfos[BUFIDX_ALTSCREEN]) {
    vterm_allocator_free(state->vt, state->lineinfos[BUFIDX_ALTSCREEN]);
  }
  vterm_allocator_free(state->vt, state);
}

static void scroll(VTermState *state, VTermRect rect, int downward, int rightward)
{
  if (!downward && !rightward) {
    return;
  }

  int rows = rect.end_row - rect.start_row;
  if (downward > rows) {
    downward = rows;
  } else if (downward < -rows) {
    downward = -rows;
  }

  int cols = rect.end_col - rect.start_col;
  if (rightward > cols) {
    rightward = cols;
  } else if (rightward < -cols) {
    rightward = -cols;
  }

  // Update lineinfo if full line
  if (rect.start_col == 0 && rect.end_col == state->cols && rightward == 0) {
    int height = rect.end_row - rect.start_row - abs(downward);

    if (downward > 0) {
      memmove(state->lineinfo + rect.start_row,
              state->lineinfo + rect.start_row + downward,
              (size_t)height * sizeof(state->lineinfo[0]));
      for (int row = rect.end_row - downward; row < rect.end_row; row++) {
        state->lineinfo[row] = (VTermLineInfo){ 0 };
      }
    } else {
      memmove(state->lineinfo + rect.start_row - downward,
              state->lineinfo + rect.start_row,
              (size_t)height * sizeof(state->lineinfo[0]));
      for (int row = rect.start_row; row < rect.start_row - downward; row++) {
        state->lineinfo[row] = (VTermLineInfo){ 0 };
      }
    }
  }

  if (state->callbacks && state->callbacks->scrollrect) {
    if ((*state->callbacks->scrollrect)(rect, downward, rightward, state->cbdata)) {
      return;
    }
  }

  if (state->callbacks) {
    vterm_scroll_rect(rect, downward, rightward,
                      state->callbacks->moverect, state->callbacks->erase, state->cbdata);
  }
}

static void linefeed(VTermState *state)
{
  if (state->pos.row == SCROLLREGION_BOTTOM(state) - 1) {
    VTermRect rect = {
      .start_row = state->scrollregion_top,
      .end_row = SCROLLREGION_BOTTOM(state),
      .start_col = SCROLLREGION_LEFT(state),
      .end_col = SCROLLREGION_RIGHT(state),
    };

    scroll(state, rect, 1, 0);
  } else if (state->pos.row < state->rows - 1) {
    state->pos.row++;
  }
}

static void set_col_tabstop(VTermState *state, int col)
{
  uint8_t mask = (uint8_t)(1 << (col & 7));
  state->tabstops[col >> 3] |= mask;
}

static void clear_col_tabstop(VTermState *state, int col)
{
  uint8_t mask = (uint8_t)(1 << (col & 7));
  state->tabstops[col >> 3] &= ~mask;
}

static int is_col_tabstop(VTermState *state, int col)
{
  uint8_t mask = (uint8_t)(1 << (col & 7));
  return state->tabstops[col >> 3] & mask;
}

static int is_cursor_in_scrollregion(const VTermState *state)
{
  if (state->pos.row < state->scrollregion_top
      || state->pos.row >= SCROLLREGION_BOTTOM(state)) {
    return 0;
  }
  if (state->pos.col < SCROLLREGION_LEFT(state)
      || state->pos.col >= SCROLLREGION_RIGHT(state)) {
    return 0;
  }

  return 1;
}

static void tab(VTermState *state, int count, int direction)
{
  while (count > 0) {
    if (direction > 0) {
      if (state->pos.col >= THISROWWIDTH(state) - 1) {
        return;
      }

      state->pos.col++;
    } else if (direction < 0) {
      if (state->pos.col < 1) {
        return;
      }

      state->pos.col--;
    }

    if (is_col_tabstop(state, state->pos.col)) {
      count--;
    }
  }
}

#define NO_FORCE 0
#define FORCE    1

#define DWL_OFF 0
#define DWL_ON  1

#define DHL_OFF    0
#define DHL_TOP    1
#define DHL_BOTTOM 2

static void set_lineinfo(VTermState *state, int row, int force, int dwl, int dhl)
{
  VTermLineInfo info = state->lineinfo[row];

  if (dwl == DWL_OFF) {
    info.doublewidth = DWL_OFF;
  } else if (dwl == DWL_ON) {
    info.doublewidth = DWL_ON;
  }
  // else -1 to ignore

  if (dhl == DHL_OFF) {
    info.doubleheight = DHL_OFF;
  } else if (dhl == DHL_TOP) {
    info.doubleheight = DHL_TOP;
  } else if (dhl == DHL_BOTTOM) {
    info.doubleheight = DHL_BOTTOM;
  }

  if ((state->callbacks
       && state->callbacks->setlineinfo
       && (*state->callbacks->setlineinfo)(row, &info, state->lineinfo + row, state->cbdata))
      || force) {
    state->lineinfo[row] = info;
  }
}

static int on_text(const char bytes[], size_t len, void *user)
{
  VTermState *state = user;

  VTermPos oldpos = state->pos;

  uint32_t *codepoints = (uint32_t *)(state->vt->tmpbuffer);
  size_t maxpoints = (state->vt->tmpbuffer_len) / sizeof(uint32_t);

  int npoints = 0;
  size_t eaten = 0;

  VTermEncodingInstance *encoding =
    state->gsingle_set ? &state->encoding[state->gsingle_set]
                       : !(bytes[eaten] & 0x80) ? &state->encoding[state->gl_set]
                                                : state->vt->mode.utf8 ? &state->encoding_utf8
                                                                       : &state->encoding[state->
                                                                                          gr_set];

  (*encoding->enc->decode)(encoding->enc, encoding->data,
                           codepoints, &npoints, state->gsingle_set ? 1 : (int)maxpoints,
                           bytes, &eaten, len);

  // There's a chance an encoding (e.g. UTF-8) hasn't found enough bytes yet for even a single codepoint
  if (!npoints) {
    return (int)eaten;
  }

  if (state->gsingle_set && npoints) {
    state->gsingle_set = 0;
  }

  int i = 0;
  GraphemeState grapheme_state = GRAPHEME_STATE_INIT;
  size_t grapheme_len = 0;
  bool recombine = false;

  // See if the cursor has moved since
  if (state->pos.row == state->combine_pos.row
      && state->pos.col == state->combine_pos.col + state->combine_width) {
    // This is a combining char. that needs to be merged with the previous glyph output
    if (utf_iscomposing((int)state->grapheme_last, (int)codepoints[i], &state->grapheme_state)) {
      // Find where we need to append these combining chars
      grapheme_len = state->grapheme_len;
      grapheme_state = state->grapheme_state;
      state->pos.col = state->combine_pos.col;
      recombine = true;
    } else {
      DEBUG_LOG("libvterm: TODO: Skip over split char+combining\n");
    }
  }

  while (i < npoints) {
    // Try to find combining characters following this
    do {
      if (grapheme_len < sizeof(state->grapheme_buf) - 4) {
        grapheme_len += (size_t)utf_char2bytes((int)codepoints[i],
                                               state->grapheme_buf + grapheme_len);
      }
      i++;
    } while (i < npoints && utf_iscomposing((int)codepoints[i - 1], (int)codepoints[i],
                                            &grapheme_state));

    int width = utf_ptr2cells_len(state->grapheme_buf, (int)grapheme_len);

    if (state->at_phantom || state->pos.col + width > THISROWWIDTH(state)) {
      linefeed(state);
      state->pos.col = 0;
      state->at_phantom = 0;
      state->lineinfo[state->pos.row].continuation = 1;
    }

    if (state->mode.insert && !recombine) {
      // TODO(vterm): This will be a little inefficient for large bodies of text, as it'll have to
      // 'ICH' effectively before every glyph. We should scan ahead and ICH as many times as
      // required
      VTermRect rect = {
        .start_row = state->pos.row,
        .end_row = state->pos.row + 1,
        .start_col = state->pos.col,
        .end_col = THISROWWIDTH(state),
      };
      scroll(state, rect, 0, -1);
    }

    schar_T sc = schar_from_buf(state->grapheme_buf, grapheme_len);
    putglyph(state, sc, width, state->pos);

    if (i == npoints) {
      // End of the buffer. Save the chars in case we have to combine with more on the next call
      state->grapheme_len = grapheme_len;
      state->grapheme_last = codepoints[i - 1];
      state->grapheme_state = grapheme_state;
      state->combine_width = width;
      state->combine_pos = state->pos;
    } else {
      grapheme_len = 0;
      recombine = false;
    }

    if (state->pos.col + width >= THISROWWIDTH(state)) {
      if (state->mode.autowrap) {
        state->at_phantom = 1;
      }
    } else {
      state->pos.col += width;
    }
  }

  updatecursor(state, &oldpos, 0);

#ifdef DEBUG
  if (state->pos.row < 0 || state->pos.row >= state->rows
      || state->pos.col < 0 || state->pos.col >= state->cols) {
    fprintf(stderr, "Position out of bounds after text: (%d,%d)\n",
            state->pos.row, state->pos.col);
    abort();
  }
#endif

  return (int)eaten;
}

static int on_control(uint8_t control, void *user)
{
  VTermState *state = user;

  VTermPos oldpos = state->pos;

  switch (control) {
  case 0x07:  // BEL - ECMA-48 8.3.3
    if (state->callbacks && state->callbacks->bell) {
      (*state->callbacks->bell)(state->cbdata);
    }
    break;

  case 0x08:  // BS - ECMA-48 8.3.5
    if (state->pos.col > 0) {
      state->pos.col--;
    }
    break;

  case 0x09:  // HT - ECMA-48 8.3.60
    tab(state, 1, +1);
    break;

  case 0x0a:  // LF - ECMA-48 8.3.74
  case 0x0b:  // VT
  case 0x0c:  // FF
    linefeed(state);
    if (state->mode.newline) {
      state->pos.col = 0;
    }
    break;

  case 0x0d:  // CR - ECMA-48 8.3.15
    state->pos.col = 0;
    break;

  case 0x0e:  // LS1 - ECMA-48 8.3.76
    state->gl_set = 1;
    break;

  case 0x0f:  // LS0 - ECMA-48 8.3.75
    state->gl_set = 0;
    break;

  case 0x84:  // IND - DEPRECATED but implemented for completeness
    linefeed(state);
    break;

  case 0x85:  // NEL - ECMA-48 8.3.86
    linefeed(state);
    state->pos.col = 0;
    break;

  case 0x88:  // HTS - ECMA-48 8.3.62
    set_col_tabstop(state, state->pos.col);
    break;

  case 0x8d:  // RI - ECMA-48 8.3.104
    if (state->pos.row == state->scrollregion_top) {
      VTermRect rect = {
        .start_row = state->scrollregion_top,
        .end_row = SCROLLREGION_BOTTOM(state),
        .start_col = SCROLLREGION_LEFT(state),
        .end_col = SCROLLREGION_RIGHT(state),
      };

      scroll(state, rect, -1, 0);
    } else if (state->pos.row > 0) {
      state->pos.row--;
    }
    break;

  case 0x8e:  // SS2 - ECMA-48 8.3.141
    state->gsingle_set = 2;
    break;

  case 0x8f:  // SS3 - ECMA-48 8.3.142
    state->gsingle_set = 3;
    break;

  default:
    if (state->fallbacks && state->fallbacks->control) {
      if ((*state->fallbacks->control)(control, state->fbdata)) {
        return 1;
      }
    }

    return 0;
  }

  updatecursor(state, &oldpos, 1);

#ifdef DEBUG
  if (state->pos.row < 0 || state->pos.row >= state->rows
      || state->pos.col < 0 || state->pos.col >= state->cols) {
    fprintf(stderr, "Position out of bounds after Ctrl %02x: (%d,%d)\n",
            control, state->pos.row, state->pos.col);
    abort();
  }
#endif

  return 1;
}

static int settermprop_bool(VTermState *state, VTermProp prop, int v)
{
  VTermValue val = { .boolean = v };
  return vterm_state_set_termprop(state, prop, &val);
}

static int settermprop_int(VTermState *state, VTermProp prop, int v)
{
  VTermValue val = { .number = v };
  return vterm_state_set_termprop(state, prop, &val);
}

static int settermprop_string(VTermState *state, VTermProp prop, VTermStringFragment frag)
{
  VTermValue val = { .string = frag };
  return vterm_state_set_termprop(state, prop, &val);
}

static void savecursor(VTermState *state, int save)
{
  if (save) {
    state->saved.pos = state->pos;
    state->saved.mode.cursor_visible = state->mode.cursor_visible;
    state->saved.mode.cursor_blink = state->mode.cursor_blink;
    state->saved.mode.cursor_shape = state->mode.cursor_shape;

    vterm_state_savepen(state, 1);
  } else {
    VTermPos oldpos = state->pos;

    state->pos = state->saved.pos;

    settermprop_bool(state, VTERM_PROP_CURSORVISIBLE, state->saved.mode.cursor_visible);
    settermprop_bool(state, VTERM_PROP_CURSORBLINK,   state->saved.mode.cursor_blink);
    settermprop_int(state, VTERM_PROP_CURSORSHAPE,   state->saved.mode.cursor_shape);

    vterm_state_savepen(state, 0);

    updatecursor(state, &oldpos, 1);
  }
}

static int on_escape(const char *bytes, size_t len, void *user)
{
  VTermState *state = user;

  // Easier to decode this from the first byte, even though the final byte terminates it
  switch (bytes[0]) {
  case ' ':
    if (len != 2) {
      return 0;
    }

    switch (bytes[1]) {
    case 'F':  // S7C1T
      state->vt->mode.ctrl8bit = 0;
      break;

    case 'G':  // S8C1T
      state->vt->mode.ctrl8bit = 1;
      break;

    default:
      return 0;
    }
    return 2;

  case '#':
    if (len != 2) {
      return 0;
    }

    switch (bytes[1]) {
    case '3':  // DECDHL top
      if (state->mode.leftrightmargin) {
        break;
      }
      set_lineinfo(state, state->pos.row, NO_FORCE, DWL_ON, DHL_TOP);
      break;

    case '4':  // DECDHL bottom
      if (state->mode.leftrightmargin) {
        break;
      }
      set_lineinfo(state, state->pos.row, NO_FORCE, DWL_ON, DHL_BOTTOM);
      break;

    case '5':  // DECSWL
      if (state->mode.leftrightmargin) {
        break;
      }
      set_lineinfo(state, state->pos.row, NO_FORCE, DWL_OFF, DHL_OFF);
      break;

    case '6':  // DECDWL
      if (state->mode.leftrightmargin) {
        break;
      }
      set_lineinfo(state, state->pos.row, NO_FORCE, DWL_ON, DHL_OFF);
      break;

    case '8':  // DECALN
    {
      VTermPos pos;
      schar_T E = schar_from_ascii('E');  // E
      for (pos.row = 0; pos.row < state->rows; pos.row++) {
        for (pos.col = 0; pos.col < ROWWIDTH(state, pos.row); pos.col++) {
          putglyph(state, E, 1, pos);
        }
      }
      break;
    }

    default:
      return 0;
    }
    return 2;

  case '(':
  case ')':
  case '*':
  case '+':  // SCS
    if (len != 2) {
      return 0;
    }

    {
      int setnum = bytes[0] - 0x28;
      VTermEncoding *newenc = vterm_lookup_encoding(ENC_SINGLE_94, bytes[1]);

      if (newenc) {
        state->encoding[setnum].enc = newenc;

        if (newenc->init) {
          (*newenc->init)(newenc, state->encoding[setnum].data);
        }
      }
    }

    return 2;

  case '7':  // DECSC
    savecursor(state, 1);
    return 1;

  case '8':  // DECRC
    savecursor(state, 0);
    return 1;

  case '<':  // Ignored by VT100. Used in VT52 mode to switch up to VT100
    return 1;

  case '=':  // DECKPAM
    state->mode.keypad = 1;
    return 1;

  case '>':  // DECKPNM
    state->mode.keypad = 0;
    return 1;

  case 'c':  // RIS - ECMA-48 8.3.105
  {
    VTermPos oldpos = state->pos;
    vterm_state_reset(state, 1);
    if (state->callbacks && state->callbacks->movecursor) {
      (*state->callbacks->movecursor)(state->pos, oldpos, state->mode.cursor_visible,
                                      state->cbdata);
    }
    return 1;
  }

  case 'n':  // LS2 - ECMA-48 8.3.78
    state->gl_set = 2;
    return 1;

  case 'o':  // LS3 - ECMA-48 8.3.80
    state->gl_set = 3;
    return 1;

  case '~':  // LS1R - ECMA-48 8.3.77
    state->gr_set = 1;
    return 1;

  case '}':  // LS2R - ECMA-48 8.3.79
    state->gr_set = 2;
    return 1;

  case '|':  // LS3R - ECMA-48 8.3.81
    state->gr_set = 3;
    return 1;

  default:
    return 0;
  }
}

static void set_mode(VTermState *state, int num, int val)
{
  switch (num) {
  case 4:  // IRM - ECMA-48 7.2.10
    state->mode.insert = (unsigned)val;
    break;

  case 20:  // LNM - ANSI X3.4-1977
    state->mode.newline = (unsigned)val;
    break;

  default:
    DEBUG_LOG("libvterm: Unknown mode %d\n", num);
    return;
  }
}

static void set_dec_mode(VTermState *state, int num, int val)
{
  switch (num) {
  case 1:
    state->mode.cursor = (unsigned)val;
    break;

  case 5:  // DECSCNM - screen mode
    settermprop_bool(state, VTERM_PROP_REVERSE, val);
    break;

  case 6:  // DECOM - origin mode
  {
    VTermPos oldpos = state->pos;
    state->mode.origin = (unsigned)val;
    state->pos.row = state->mode.origin ? state->scrollregion_top : 0;
    state->pos.col = state->mode.origin ? SCROLLREGION_LEFT(state) : 0;
    updatecursor(state, &oldpos, 1);
  }
  break;

  case 7:
    state->mode.autowrap = (unsigned)val;
    break;

  case 12:
    settermprop_bool(state, VTERM_PROP_CURSORBLINK, val);
    break;

  case 25:
    settermprop_bool(state, VTERM_PROP_CURSORVISIBLE, val);
    break;

  case 69:  // DECVSSM - vertical split screen mode
            // DECLRMM - left/right margin mode
    state->mode.leftrightmargin = (unsigned)val;
    if (val) {
      // Setting DECVSSM must clear doublewidth/doubleheight state of every line
      for (int row = 0; row < state->rows; row++) {
        set_lineinfo(state, row, FORCE, DWL_OFF, DHL_OFF);
      }
    }

    break;

  case 1000:
  case 1002:
  case 1003:
    settermprop_int(state, VTERM_PROP_MOUSE,
                    !val ? VTERM_PROP_MOUSE_NONE
                         : (num == 1000) ? VTERM_PROP_MOUSE_CLICK
                                         : (num == 1002) ? VTERM_PROP_MOUSE_DRAG
                                                         : VTERM_PROP_MOUSE_MOVE);
    break;

  case 1004:
    settermprop_bool(state, VTERM_PROP_FOCUSREPORT, val);
    state->mode.report_focus = (unsigned)val;
    break;

  case 1005:
    state->mouse_protocol = val ? MOUSE_UTF8 : MOUSE_X10;
    break;

  case 1006:
    state->mouse_protocol = val ? MOUSE_SGR : MOUSE_X10;
    break;

  case 1015:
    state->mouse_protocol = val ? MOUSE_RXVT : MOUSE_X10;
    break;

  case 1047:
    settermprop_bool(state, VTERM_PROP_ALTSCREEN, val);
    break;

  case 1048:
    savecursor(state, val);
    break;

  case 1049:
    settermprop_bool(state, VTERM_PROP_ALTSCREEN, val);
    savecursor(state, val);
    break;

  case 2004:
    state->mode.bracketpaste = (unsigned)val;
    break;

  case 2031:
    settermprop_bool(state, VTERM_PROP_THEMEUPDATES, val);
    break;

  default:
    DEBUG_LOG("libvterm: Unknown DEC mode %d\n", num);
    return;
  }
}

static void request_dec_mode(VTermState *state, int num)
{
  int reply;

  switch (num) {
  case 1:
    reply = state->mode.cursor;
    break;

  case 5:
    reply = state->mode.screen;
    break;

  case 6:
    reply = state->mode.origin;
    break;

  case 7:
    reply = state->mode.autowrap;
    break;

  case 12:
    reply = state->mode.cursor_blink;
    break;

  case 25:
    reply = state->mode.cursor_visible;
    break;

  case 69:
    reply = state->mode.leftrightmargin;
    break;

  case 1000:
    reply = state->mouse_flags == MOUSE_WANT_CLICK;
    break;

  case 1002:
    reply = state->mouse_flags == (MOUSE_WANT_CLICK|MOUSE_WANT_DRAG);
    break;

  case 1003:
    reply = state->mouse_flags == (MOUSE_WANT_CLICK|MOUSE_WANT_MOVE);
    break;

  case 1004:
    reply = state->mode.report_focus;
    break;

  case 1005:
    reply = state->mouse_protocol == MOUSE_UTF8;
    break;

  case 1006:
    reply = state->mouse_protocol == MOUSE_SGR;
    break;

  case 1015:
    reply = state->mouse_protocol == MOUSE_RXVT;
    break;

  case 1047:
    reply = state->mode.alt_screen;
    break;

  case 2004:
    reply = state->mode.bracketpaste;
    break;

  case 2031:
    reply = state->mode.theme_updates;
    break;

  default:
    vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "?%d;%d$y", num, 0);
    return;
  }

  vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "?%d;%d$y", num, reply ? 1 : 2);
}

static void request_version_string(VTermState *state)
{
  vterm_push_output_sprintf_str(state->vt, C1_DCS, true, ">|libvterm(%d.%d)",
                                VTERM_VERSION_MAJOR, VTERM_VERSION_MINOR);
}

static void request_key_encoding_flags(VTermState *state)
{
  int screen = state->mode.alt_screen ? BUFIDX_ALTSCREEN : BUFIDX_PRIMARY;
  struct VTermKeyEncodingStack *stack = &state->key_encoding_stacks[screen];

  int reply = 0;

  assert(stack->size > 0);
  VTermKeyEncodingFlags flags = stack->items[stack->size - 1];

  if (flags.disambiguate) {
    reply |= KEY_ENCODING_DISAMBIGUATE;
  }

  if (flags.report_events) {
    reply |= KEY_ENCODING_REPORT_EVENTS;
  }

  if (flags.report_alternate) {
    reply |= KEY_ENCODING_REPORT_ALTERNATE;
  }

  if (flags.report_all_keys) {
    reply |= KEY_ENCODING_REPORT_ALL_KEYS;
  }

  if (flags.report_associated) {
    reply |= KEY_ENCODING_REPORT_ASSOCIATED;
  }

  vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "?%du", reply);
}

static void set_key_encoding_flags(VTermState *state, int arg, int mode)
{
  // When mode is 3, bits set in arg reset the corresponding mode
  bool set = mode != 3;

  // When mode is 1, unset bits are reset
  bool reset_unset = mode == 1;

  struct VTermKeyEncodingFlags flags = { 0 };
  if (arg & KEY_ENCODING_DISAMBIGUATE) {
    flags.disambiguate = set;
  } else if (reset_unset) {
    flags.disambiguate = false;
  }

  if (arg & KEY_ENCODING_REPORT_EVENTS) {
    flags.report_events = set;
  } else if (reset_unset) {
    flags.report_events = false;
  }

  if (arg & KEY_ENCODING_REPORT_ALTERNATE) {
    flags.report_alternate = set;
  } else if (reset_unset) {
    flags.report_alternate = false;
  }
  if (arg & KEY_ENCODING_REPORT_ALL_KEYS) {
    flags.report_all_keys = set;
  } else if (reset_unset) {
    flags.report_all_keys = false;
  }

  if (arg & KEY_ENCODING_REPORT_ASSOCIATED) {
    flags.report_associated = set;
  } else if (reset_unset) {
    flags.report_associated = false;
  }

  int screen = state->mode.alt_screen ? BUFIDX_ALTSCREEN : BUFIDX_PRIMARY;
  struct VTermKeyEncodingStack *stack = &state->key_encoding_stacks[screen];
  assert(stack->size > 0);
  stack->items[stack->size - 1] = flags;
}

static void push_key_encoding_flags(VTermState *state, int arg)
{
  int screen = state->mode.alt_screen ? BUFIDX_ALTSCREEN : BUFIDX_PRIMARY;
  struct VTermKeyEncodingStack *stack = &state->key_encoding_stacks[screen];
  assert(stack->size <= ARRAY_SIZE(stack->items));

  if (stack->size == ARRAY_SIZE(stack->items)) {
    // Evict oldest entry when stack is full
    for (size_t i = 0; i < ARRAY_SIZE(stack->items) - 1; i++) {
      stack->items[i] = stack->items[i + 1];
    }
  } else {
    stack->size++;
  }

  set_key_encoding_flags(state, arg, 1);
}

static void pop_key_encoding_flags(VTermState *state, int arg)
{
  int screen = state->mode.alt_screen ? BUFIDX_ALTSCREEN : BUFIDX_PRIMARY;
  struct VTermKeyEncodingStack *stack = &state->key_encoding_stacks[screen];
  if (arg >= stack->size) {
    stack->size = 1;

    // If a pop request is received that empties the stack, all flags are reset.
    memset(&stack->items[0], 0, sizeof(stack->items[0]));
  } else if (arg > 0) {
    stack->size -= arg;
  }
}

static int on_csi(const char *leader, const long args[], int argcount, const char *intermed,
                  char command, void *user)
{
  VTermState *state = user;
  int leader_byte = 0;
  int intermed_byte = 0;
  int cancel_phantom = 1;

  if (leader && leader[0]) {
    if (leader[1]) {  // longer than 1 char
      return 0;
    }

    switch (leader[0]) {
    case '?':
    case '>':
    case '<':
    case '=':
      leader_byte = (int)leader[0];
      break;
    default:
      return 0;
    }
  }

  if (intermed && intermed[0]) {
    if (intermed[1]) {  // longer than 1 char
      return 0;
    }

    switch (intermed[0]) {
    case ' ':
    case '!':
    case '"':
    case '$':
    case '\'':
      intermed_byte = (int)intermed[0];
      break;
    default:
      return 0;
    }
  }

  VTermPos oldpos = state->pos;

  // Some temporaries for later code
  int count, val;
  int row, col;
  VTermRect rect;
  int selective;

#define LBOUND(v, min) if ((v) < (min))(v) = (min)
#define UBOUND(v, max) if ((v) > (max))(v) = (max)

#define LEADER(l, b) ((l << 8) | b)
#define INTERMED(i, b) ((i << 16) | b)

  switch (intermed_byte << 16 | leader_byte << 8 | command) {
  case 0x40:  // ICH - ECMA-48 8.3.64
    count = CSI_ARG_COUNT(args[0]);

    if (!is_cursor_in_scrollregion(state)) {
      break;
    }

    rect.start_row = state->pos.row;
    rect.end_row = state->pos.row + 1;
    rect.start_col = state->pos.col;
    if (state->mode.leftrightmargin) {
      rect.end_col = SCROLLREGION_RIGHT(state);
    } else {
      rect.end_col = THISROWWIDTH(state);
    }

    scroll(state, rect, 0, -count);

    break;

  case 0x41:  // CUU - ECMA-48 8.3.22
    count = CSI_ARG_COUNT(args[0]);
    state->pos.row -= count;
    state->at_phantom = 0;
    break;

  case 0x42:  // CUD - ECMA-48 8.3.19
    count = CSI_ARG_COUNT(args[0]);
    state->pos.row += count;
    state->at_phantom = 0;
    break;

  case 0x43:  // CUF - ECMA-48 8.3.20
    count = CSI_ARG_COUNT(args[0]);
    state->pos.col += count;
    state->at_phantom = 0;
    break;

  case 0x44:  // CUB - ECMA-48 8.3.18
    count = CSI_ARG_COUNT(args[0]);
    state->pos.col -= count;
    state->at_phantom = 0;
    break;

  case 0x45:  // CNL - ECMA-48 8.3.12
    count = CSI_ARG_COUNT(args[0]);
    state->pos.col = 0;
    state->pos.row += count;
    state->at_phantom = 0;
    break;

  case 0x46:  // CPL - ECMA-48 8.3.13
    count = CSI_ARG_COUNT(args[0]);
    state->pos.col = 0;
    state->pos.row -= count;
    state->at_phantom = 0;
    break;

  case 0x47:  // CHA - ECMA-48 8.3.9
    val = CSI_ARG_OR(args[0], 1);
    state->pos.col = val - 1;
    state->at_phantom = 0;
    break;

  case 0x48:  // CUP - ECMA-48 8.3.21
    row = CSI_ARG_OR(args[0], 1);
    col = argcount < 2 || CSI_ARG_IS_MISSING(args[1]) ? 1 : CSI_ARG(args[1]);
    // zero-based
    state->pos.row = row - 1;
    state->pos.col = col - 1;
    if (state->mode.origin) {
      state->pos.row += state->scrollregion_top;
      state->pos.col += SCROLLREGION_LEFT(state);
    }
    state->at_phantom = 0;
    break;

  case 0x49:  // CHT - ECMA-48 8.3.10
    count = CSI_ARG_COUNT(args[0]);
    tab(state, count, +1);
    break;

  case 0x4a:  // ED - ECMA-48 8.3.39
  case LEADER('?', 0x4a):  // DECSED - Selective Erase in Display
    selective = (leader_byte == '?');
    switch (CSI_ARG(args[0])) {
    case CSI_ARG_MISSING:
    case 0:
      rect.start_row = state->pos.row; rect.end_row = state->pos.row + 1;
      rect.start_col = state->pos.col; rect.end_col = state->cols;
      if (rect.end_col > rect.start_col) {
        erase(state, rect, selective);
      }

      rect.start_row = state->pos.row + 1; rect.end_row = state->rows;
      rect.start_col = 0;
      for (int row_ = rect.start_row; row_ < rect.end_row; row_++) {
        set_lineinfo(state, row_, FORCE, DWL_OFF, DHL_OFF);
      }
      if (rect.end_row > rect.start_row) {
        erase(state, rect, selective);
      }
      break;

    case 1:
      rect.start_row = 0; rect.end_row = state->pos.row;
      rect.start_col = 0; rect.end_col = state->cols;
      for (int row_ = rect.start_row; row_ < rect.end_row; row_++) {
        set_lineinfo(state, row_, FORCE, DWL_OFF, DHL_OFF);
      }
      if (rect.end_col > rect.start_col) {
        erase(state, rect, selective);
      }

      rect.start_row = state->pos.row; rect.end_row = state->pos.row + 1;
      rect.end_col = state->pos.col + 1;
      if (rect.end_row > rect.start_row) {
        erase(state, rect, selective);
      }
      break;

    case 2:
      rect.start_row = 0; rect.end_row = state->rows;
      rect.start_col = 0; rect.end_col = state->cols;
      for (int row_ = rect.start_row; row_ < rect.end_row; row_++) {
        set_lineinfo(state, row_, FORCE, DWL_OFF, DHL_OFF);
      }
      erase(state, rect, selective);
      break;

    case 3:
      if (state->callbacks && state->callbacks->sb_clear) {
        if ((*state->callbacks->sb_clear)(state->cbdata)) {
          return 1;
        }
      }
      break;
    }
    break;

  case 0x4b:  // EL - ECMA-48 8.3.41
  case LEADER('?', 0x4b):  // DECSEL - Selective Erase in Line
    selective = (leader_byte == '?');
    rect.start_row = state->pos.row;
    rect.end_row = state->pos.row + 1;

    switch (CSI_ARG(args[0])) {
    case CSI_ARG_MISSING:
    case 0:
      rect.start_col = state->pos.col; rect.end_col = THISROWWIDTH(state); break;
    case 1:
      rect.start_col = 0; rect.end_col = state->pos.col + 1; break;
    case 2:
      rect.start_col = 0; rect.end_col = THISROWWIDTH(state); break;
    default:
      return 0;
    }

    if (rect.end_col > rect.start_col) {
      erase(state, rect, selective);
    }

    break;

  case 0x4c:  // IL - ECMA-48 8.3.67
    count = CSI_ARG_COUNT(args[0]);

    if (!is_cursor_in_scrollregion(state)) {
      break;
    }

    rect.start_row = state->pos.row;
    rect.end_row = SCROLLREGION_BOTTOM(state);
    rect.start_col = SCROLLREGION_LEFT(state);
    rect.end_col = SCROLLREGION_RIGHT(state);

    scroll(state, rect, -count, 0);

    break;

  case 0x4d:  // DL - ECMA-48 8.3.32
    count = CSI_ARG_COUNT(args[0]);

    if (!is_cursor_in_scrollregion(state)) {
      break;
    }

    rect.start_row = state->pos.row;
    rect.end_row = SCROLLREGION_BOTTOM(state);
    rect.start_col = SCROLLREGION_LEFT(state);
    rect.end_col = SCROLLREGION_RIGHT(state);

    scroll(state, rect, count, 0);

    break;

  case 0x50:  // DCH - ECMA-48 8.3.26
    count = CSI_ARG_COUNT(args[0]);

    if (!is_cursor_in_scrollregion(state)) {
      break;
    }

    rect.start_row = state->pos.row;
    rect.end_row = state->pos.row + 1;
    rect.start_col = state->pos.col;
    if (state->mode.leftrightmargin) {
      rect.end_col = SCROLLREGION_RIGHT(state);
    } else {
      rect.end_col = THISROWWIDTH(state);
    }

    scroll(state, rect, 0, count);

    break;

  case 0x53:  // SU - ECMA-48 8.3.147
    count = CSI_ARG_COUNT(args[0]);

    rect.start_row = state->scrollregion_top;
    rect.end_row = SCROLLREGION_BOTTOM(state);
    rect.start_col = SCROLLREGION_LEFT(state);
    rect.end_col = SCROLLREGION_RIGHT(state);

    scroll(state, rect, count, 0);

    break;

  case 0x54:  // SD - ECMA-48 8.3.113
    count = CSI_ARG_COUNT(args[0]);

    rect.start_row = state->scrollregion_top;
    rect.end_row = SCROLLREGION_BOTTOM(state);
    rect.start_col = SCROLLREGION_LEFT(state);
    rect.end_col = SCROLLREGION_RIGHT(state);

    scroll(state, rect, -count, 0);

    break;

  case 0x58:  // ECH - ECMA-48 8.3.38
    count = CSI_ARG_COUNT(args[0]);

    rect.start_row = state->pos.row;
    rect.end_row = state->pos.row + 1;
    rect.start_col = state->pos.col;
    rect.end_col = state->pos.col + count;
    UBOUND(rect.end_col, THISROWWIDTH(state));

    erase(state, rect, 0);
    break;

  case 0x5a:  // CBT - ECMA-48 8.3.7
    count = CSI_ARG_COUNT(args[0]);
    tab(state, count, -1);
    break;

  case 0x60:  // HPA - ECMA-48 8.3.57
    col = CSI_ARG_OR(args[0], 1);
    state->pos.col = col - 1;
    state->at_phantom = 0;
    break;

  case 0x61:  // HPR - ECMA-48 8.3.59
    count = CSI_ARG_COUNT(args[0]);
    state->pos.col += count;
    state->at_phantom = 0;
    break;

  case 0x62: {  // REP - ECMA-48 8.3.103
    const int row_width = THISROWWIDTH(state);
    count = CSI_ARG_COUNT(args[0]);
    col = state->pos.col + count;
    UBOUND(col, row_width);
    schar_T sc = schar_from_buf(state->grapheme_buf, state->grapheme_len);
    while (state->pos.col < col) {
      putglyph(state, sc, state->combine_width, state->pos);
      state->pos.col += state->combine_width;
    }
    if (state->pos.col + state->combine_width >= row_width) {
      if (state->mode.autowrap) {
        state->at_phantom = 1;
        cancel_phantom = 0;
      }
    }
    break;
  }

  case 0x63:  // DA - ECMA-48 8.3.24
    val = CSI_ARG_OR(args[0], 0);
    if (val == 0) {
      // DEC VT100 response
      vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "?%sc", vterm_primary_device_attr);
    }
    break;

  case LEADER('>', 0x63):  // DEC secondary Device Attributes
    vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, ">%d;%d;%dc", 0, 100, 0);
    break;

  case 0x64:  // VPA - ECMA-48 8.3.158
    row = CSI_ARG_OR(args[0], 1);
    state->pos.row = row - 1;
    if (state->mode.origin) {
      state->pos.row += state->scrollregion_top;
    }
    state->at_phantom = 0;
    break;

  case 0x65:  // VPR - ECMA-48 8.3.160
    count = CSI_ARG_COUNT(args[0]);
    state->pos.row += count;
    state->at_phantom = 0;
    break;

  case 0x66:  // HVP - ECMA-48 8.3.63
    row = CSI_ARG_OR(args[0], 1);
    col = argcount < 2 || CSI_ARG_IS_MISSING(args[1]) ? 1 : CSI_ARG(args[1]);
    // zero-based
    state->pos.row = row - 1;
    state->pos.col = col - 1;
    if (state->mode.origin) {
      state->pos.row += state->scrollregion_top;
      state->pos.col += SCROLLREGION_LEFT(state);
    }
    state->at_phantom = 0;
    break;

  case 0x67:  // TBC - ECMA-48 8.3.154
    val = CSI_ARG_OR(args[0], 0);

    switch (val) {
    case 0:
      clear_col_tabstop(state, state->pos.col);
      break;
    case 3:
    case 5:
      for (col = 0; col < state->cols; col++) {
        clear_col_tabstop(state, col);
      }
      break;
    case 1:
    case 2:
    case 4:
      break;
    // TODO(vterm): 1, 2 and 4 aren't meaningful yet without line tab stops
    default:
      return 0;
    }
    break;

  case 0x68:  // SM - ECMA-48 8.3.125
    if (!CSI_ARG_IS_MISSING(args[0])) {
      set_mode(state, CSI_ARG(args[0]), 1);
    }
    break;

  case LEADER('?', 0x68):  // DEC private mode set
    for (int i = 0; i < argcount; i++) {
      if (!CSI_ARG_IS_MISSING(args[i])) {
        set_dec_mode(state, CSI_ARG(args[i]), 1);
      }
    }
    break;

  case 0x6a:  // HPB - ECMA-48 8.3.58
    count = CSI_ARG_COUNT(args[0]);
    state->pos.col -= count;
    state->at_phantom = 0;
    break;

  case 0x6b:  // VPB - ECMA-48 8.3.159
    count = CSI_ARG_COUNT(args[0]);
    state->pos.row -= count;
    state->at_phantom = 0;
    break;

  case 0x6c:  // RM - ECMA-48 8.3.106
    if (!CSI_ARG_IS_MISSING(args[0])) {
      set_mode(state, CSI_ARG(args[0]), 0);
    }
    break;

  case LEADER('?', 0x6c):  // DEC private mode reset
    for (int i = 0; i < argcount; i++) {
      if (!CSI_ARG_IS_MISSING(args[i])) {
        set_dec_mode(state, CSI_ARG(args[i]), 0);
      }
    }
    break;

  case 0x6d:  // SGR - ECMA-48 8.3.117
    vterm_state_setpen(state, args, argcount);
    break;

  case LEADER('?', 0x6d):  // DECSGR
    // No actual DEC terminal recognised these, but some printers did. These are alternative ways to
    // request subscript/superscript/off
    for (int argi = 0; argi < argcount; argi++) {
      long arg;
      switch (arg = CSI_ARG(args[argi])) {
      case 4:  // Superscript on
        arg = 73;
        vterm_state_setpen(state, &arg, 1);
        break;
      case 5:  // Subscript on
        arg = 74;
        vterm_state_setpen(state, &arg, 1);
        break;
      case 24:  // Super+subscript off
        arg = 75;
        vterm_state_setpen(state, &arg, 1);
        break;
      }
    }
    break;

  case 0x6e:  // DSR - ECMA-48 8.3.35
  case LEADER('?', 0x6e):  // DECDSR
    val = CSI_ARG_OR(args[0], 0);

    {
      char *qmark = (leader_byte == '?') ? "?" : "";
      bool dark = false;

      switch (val) {
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
        // ignore - these are replies
        break;
      case 5:
        vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "%s0n", qmark);
        break;
      case 6:  // CPR - cursor position report
        vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "%s%d;%dR", qmark, state->pos.row + 1,
                                       state->pos.col + 1);
        break;
      case 996:
        if (state->callbacks && state->callbacks->theme) {
          if (state->callbacks->theme(&dark, state->cbdata)) {
            vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "?997;%cn", dark ? '1' : '2');
          }
        }
        break;
      }
    }
    break;

  case INTERMED('!', 0x70):  // DECSTR - DEC soft terminal reset
    vterm_state_reset(state, 0);
    break;

  case LEADER('?', INTERMED('$', 0x70)):
    request_dec_mode(state, CSI_ARG(args[0]));
    break;

  case LEADER('>', 0x71):  // XTVERSION - xterm query version string
    request_version_string(state);
    break;

  case INTERMED(' ', 0x71):  // DECSCUSR - DEC set cursor shape
    val = CSI_ARG_OR(args[0], 1);

    switch (val) {
    case 0:
    case 1:
      settermprop_bool(state, VTERM_PROP_CURSORBLINK, 1);
      settermprop_int(state, VTERM_PROP_CURSORSHAPE, VTERM_PROP_CURSORSHAPE_BLOCK);
      break;
    case 2:
      settermprop_bool(state, VTERM_PROP_CURSORBLINK, 0);
      settermprop_int(state, VTERM_PROP_CURSORSHAPE, VTERM_PROP_CURSORSHAPE_BLOCK);
      break;
    case 3:
      settermprop_bool(state, VTERM_PROP_CURSORBLINK, 1);
      settermprop_int(state, VTERM_PROP_CURSORSHAPE, VTERM_PROP_CURSORSHAPE_UNDERLINE);
      break;
    case 4:
      settermprop_bool(state, VTERM_PROP_CURSORBLINK, 0);
      settermprop_int(state, VTERM_PROP_CURSORSHAPE, VTERM_PROP_CURSORSHAPE_UNDERLINE);
      break;
    case 5:
      settermprop_bool(state, VTERM_PROP_CURSORBLINK, 1);
      settermprop_int(state, VTERM_PROP_CURSORSHAPE, VTERM_PROP_CURSORSHAPE_BAR_LEFT);
      break;
    case 6:
      settermprop_bool(state, VTERM_PROP_CURSORBLINK, 0);
      settermprop_int(state, VTERM_PROP_CURSORSHAPE, VTERM_PROP_CURSORSHAPE_BAR_LEFT);
      break;
    }

    break;

  case INTERMED('"', 0x71):  // DECSCA - DEC select character protection attribute
    val = CSI_ARG_OR(args[0], 0);

    switch (val) {
    case 0:
    case 2:
      state->protected_cell = 0;
      break;
    case 1:
      state->protected_cell = 1;
      break;
    }

    break;

  case 0x72:  // DECSTBM - DEC custom
    state->scrollregion_top = CSI_ARG_OR(args[0], 1) - 1;
    state->scrollregion_bottom = argcount < 2
                                 || CSI_ARG_IS_MISSING(args[1]) ? -1 : CSI_ARG(args[1]);
    LBOUND(state->scrollregion_top, 0);
    UBOUND(state->scrollregion_top, state->rows);
    LBOUND(state->scrollregion_bottom, -1);
    if (state->scrollregion_top == 0 && state->scrollregion_bottom == state->rows) {
      state->scrollregion_bottom = -1;
    } else {
      UBOUND(state->scrollregion_bottom, state->rows);
    }

    if (SCROLLREGION_BOTTOM(state) <= state->scrollregion_top) {
      // Invalid
      state->scrollregion_top = 0;
      state->scrollregion_bottom = -1;
    }

    // Setting the scrolling region restores the cursor to the home position
    state->pos.row = 0;
    state->pos.col = 0;
    if (state->mode.origin) {
      state->pos.row += state->scrollregion_top;
      state->pos.col += SCROLLREGION_LEFT(state);
    }

    break;

  case 0x73:  // DECSLRM - DEC custom
    // Always allow setting these margins, just they won't take effect without DECVSSM
    state->scrollregion_left = CSI_ARG_OR(args[0], 1) - 1;
    state->scrollregion_right = argcount < 2 || CSI_ARG_IS_MISSING(args[1]) ? -1 : CSI_ARG(args[1]);
    LBOUND(state->scrollregion_left, 0);
    UBOUND(state->scrollregion_left, state->cols);
    LBOUND(state->scrollregion_right, -1);
    if (state->scrollregion_left == 0 && state->scrollregion_right == state->cols) {
      state->scrollregion_right = -1;
    } else {
      UBOUND(state->scrollregion_right, state->cols);
    }

    if (state->scrollregion_right > -1
        && state->scrollregion_right <= state->scrollregion_left) {
      // Invalid
      state->scrollregion_left = 0;
      state->scrollregion_right = -1;
    }

    // Setting the scrolling region restores the cursor to the home position
    state->pos.row = 0;
    state->pos.col = 0;
    if (state->mode.origin) {
      state->pos.row += state->scrollregion_top;
      state->pos.col += SCROLLREGION_LEFT(state);
    }

    break;

  case LEADER('?', 0x75):  // Kitty query
    request_key_encoding_flags(state);
    break;

  case LEADER('>', 0x75):  // Kitty push flags
    push_key_encoding_flags(state, CSI_ARG_OR(args[0], 0));
    break;

  case LEADER('<', 0x75):  // Kitty pop flags
    pop_key_encoding_flags(state, CSI_ARG_OR(args[0], 1));
    break;

  case LEADER('=', 0x75):  // Kitty set flags
    val = argcount < 2 || CSI_ARG_IS_MISSING(args[1]) ? 1 : CSI_ARG(args[1]);
    set_key_encoding_flags(state, CSI_ARG_OR(args[0], 0), val);
    break;

  case INTERMED('\'', 0x7D):  // DECIC
    count = CSI_ARG_COUNT(args[0]);

    if (!is_cursor_in_scrollregion(state)) {
      break;
    }

    rect.start_row = state->scrollregion_top;
    rect.end_row = SCROLLREGION_BOTTOM(state);
    rect.start_col = state->pos.col;
    rect.end_col = SCROLLREGION_RIGHT(state);

    scroll(state, rect, 0, -count);

    break;

  case INTERMED('\'', 0x7E):  // DECDC
    count = CSI_ARG_COUNT(args[0]);

    if (!is_cursor_in_scrollregion(state)) {
      break;
    }

    rect.start_row = state->scrollregion_top;
    rect.end_row = SCROLLREGION_BOTTOM(state);
    rect.start_col = state->pos.col;
    rect.end_col = SCROLLREGION_RIGHT(state);

    scroll(state, rect, 0, count);

    break;

  default:
    if (state->fallbacks && state->fallbacks->csi) {
      if ((*state->fallbacks->csi)(leader, args, argcount, intermed, command, state->fbdata)) {
        return 1;
      }
    }

    return 0;
  }

  if (state->mode.origin) {
    LBOUND(state->pos.row, state->scrollregion_top);
    UBOUND(state->pos.row, SCROLLREGION_BOTTOM(state) - 1);
    LBOUND(state->pos.col, SCROLLREGION_LEFT(state));
    UBOUND(state->pos.col, SCROLLREGION_RIGHT(state) - 1);
  } else {
    LBOUND(state->pos.row, 0);
    UBOUND(state->pos.row, state->rows - 1);
    LBOUND(state->pos.col, 0);
    UBOUND(state->pos.col, THISROWWIDTH(state) - 1);
  }

  updatecursor(state, &oldpos, cancel_phantom);

#ifdef DEBUG
  if (state->pos.row < 0 || state->pos.row >= state->rows
      || state->pos.col < 0 || state->pos.col >= state->cols) {
    fprintf(stderr, "Position out of bounds after CSI %c: (%d,%d)\n",
            command, state->pos.row, state->pos.col);
    abort();
  }

  if (SCROLLREGION_BOTTOM(state) <= state->scrollregion_top) {
    fprintf(stderr, "Scroll region height out of bounds after CSI %c: %d <= %d\n",
            command, SCROLLREGION_BOTTOM(state), state->scrollregion_top);
    abort();
  }

  if (SCROLLREGION_RIGHT(state) <= SCROLLREGION_LEFT(state)) {
    fprintf(stderr, "Scroll region width out of bounds after CSI %c: %d <= %d\n",
            command, SCROLLREGION_RIGHT(state), SCROLLREGION_LEFT(state));
    abort();
  }
#endif

  return 1;
}

static uint8_t unbase64one(char c)
{
  if (c >= 'A' && c <= 'Z') {
    return (uint8_t)c - 'A';
  } else if (c >= 'a' && c <= 'z') {
    return (uint8_t)c - 'a' + 26;
  } else if (c >= '0' && c <= '9') {
    return (uint8_t)c - '0' + 52;
  } else if (c == '+') {
    return 62;
  } else if (c == '/') {
    return 63;
  }

  return 0xFF;
}

static void osc_selection(VTermState *state, VTermStringFragment frag)
{
  if (frag.initial) {
    state->tmp.selection.mask = 0;
    state->tmp.selection.state = SELECTION_INITIAL;
  }

  while (!state->tmp.selection.state && frag.len) {
    // Parse selection parameter
    switch (frag.str[0]) {
    case 'c':
      state->tmp.selection.mask |= VTERM_SELECTION_CLIPBOARD;
      break;
    case 'p':
      state->tmp.selection.mask |= VTERM_SELECTION_PRIMARY;
      break;
    case 'q':
      state->tmp.selection.mask |= VTERM_SELECTION_SECONDARY;
      break;
    case 's':
      state->tmp.selection.mask |= VTERM_SELECTION_SELECT;
      break;
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
      state->tmp.selection.mask |= (VTERM_SELECTION_CUT0 << (frag.str[0] - '0'));
      break;

    case ';':
      state->tmp.selection.state = SELECTION_SELECTED;
      if (!state->tmp.selection.mask) {
        state->tmp.selection.mask = VTERM_SELECTION_SELECT|VTERM_SELECTION_CUT0;
      }
      break;
    }

    frag.str++;
    frag.len--;
  }

  if (!frag.len) {
    // Clear selection if we're already finished but didn't do anything
    if (frag.final && state->selection.callbacks->set) {
      (*state->selection.callbacks->set)(state->tmp.selection.mask, (VTermStringFragment){
        .str = NULL,
        .len = 0,
        .initial = state->tmp.selection.state != SELECTION_SET,
        .final = true,
      }, state->selection.user);
    }
    return;
  }

  if (state->tmp.selection.state == SELECTION_SELECTED) {
    if (frag.str[0] == '?') {
      state->tmp.selection.state = SELECTION_QUERY;
    } else {
      state->tmp.selection.state = SELECTION_SET_INITIAL;
      state->tmp.selection.recvpartial = 0;
    }
  }

  if (state->tmp.selection.state == SELECTION_QUERY) {
    if (state->selection.callbacks->query) {
      (*state->selection.callbacks->query)(state->tmp.selection.mask, state->selection.user);
    }
    return;
  }

  if (state->tmp.selection.state == SELECTION_INVALID) {
    return;
  }

  if (state->selection.callbacks->set) {
    size_t bufcur = 0;
    char *buffer = state->selection.buffer;

    uint32_t x = 0;  // Current decoding value
    int n = 0;      // Number of sextets consumed

    if (state->tmp.selection.recvpartial) {
      n = state->tmp.selection.recvpartial >> 24;
      x = state->tmp.selection.recvpartial & 0x03FFFF;  // could be up to 18 bits of state in here

      state->tmp.selection.recvpartial = 0;
    }

    while ((state->selection.buflen - bufcur) >= 3 && frag.len) {
      if (frag.str[0] == '=') {
        if (n == 2) {
          buffer[0] = (char)(x >> 4 & 0xFF);
          buffer += 1, bufcur += 1;
        }
        if (n == 3) {
          buffer[0] = (char)(x >> 10 & 0xFF);
          buffer[1] = (char)(x >>  2 & 0xFF);
          buffer += 2, bufcur += 2;
        }

        while (frag.len && frag.str[0] == '=') {
          frag.str++, frag.len--;
        }

        n = 0;
      } else {
        uint8_t b = unbase64one(frag.str[0]);
        if (b == 0xFF) {
          DEBUG_LOG("base64decode bad input %02X\n", (uint8_t)frag.str[0]);

          state->tmp.selection.state = SELECTION_INVALID;
          if (state->selection.callbacks->set) {
            (*state->selection.callbacks->set)(state->tmp.selection.mask, (VTermStringFragment){
              .str = NULL,
              .len = 0,
              .initial = true,
              .final = true,
            }, state->selection.user);
          }
          break;
        }

        x = (x << 6) | b;
        n++;
        frag.str++, frag.len--;

        if (n == 4) {
          buffer[0] = (char)(x >> 16 & 0xFF);
          buffer[1] = (char)(x >>  8 & 0xFF);
          buffer[2] = (char)(x >>  0 & 0xFF);

          buffer += 3, bufcur += 3;
          x = 0;
          n = 0;
        }
      }

      if (!frag.len || (state->selection.buflen - bufcur) < 3) {
        if (bufcur) {
          (*state->selection.callbacks->set)(state->tmp.selection.mask, (VTermStringFragment){
            .str = state->selection.buffer,
            .len = bufcur,
            .initial = state->tmp.selection.state == SELECTION_SET_INITIAL,
            .final = frag.final && !frag.len,
          }, state->selection.user);
          state->tmp.selection.state = SELECTION_SET;
        }

        buffer = state->selection.buffer;
        bufcur = 0;
      }
    }

    if (n) {
      state->tmp.selection.recvpartial = (uint32_t)(n << 24) | x;
    }
  }
}

static int on_osc(int command, VTermStringFragment frag, void *user)
{
  VTermState *state = user;

  switch (command) {
  case 0:
    settermprop_string(state, VTERM_PROP_ICONNAME, frag);
    settermprop_string(state, VTERM_PROP_TITLE, frag);
    break;

  case 1:
    settermprop_string(state, VTERM_PROP_ICONNAME, frag);
    break;

  case 2:
    settermprop_string(state, VTERM_PROP_TITLE, frag);
    break;

  case 52:
    if (state->selection.callbacks) {
      osc_selection(state, frag);
    }
    break;
  }

  if (state->fallbacks && state->fallbacks->osc) {
    if ((*state->fallbacks->osc)(command, frag, state->fbdata)) {
      return 1;
    }
  }

  return 0;
}

static void request_status_string(VTermState *state, VTermStringFragment frag)
{
  VTerm *vt = state->vt;

  char *tmp = state->tmp.decrqss;

  if (frag.initial) {
    tmp[0] = tmp[1] = tmp[2] = tmp[3] = 0;
  }

  size_t i = 0;
  while (i < sizeof(state->tmp.decrqss) - 1 && tmp[i]) {
    i++;
  }
  while (i < sizeof(state->tmp.decrqss) - 1 && frag.len--) {
    tmp[i++] = (frag.str++)[0];
  }
  tmp[i] = 0;

  if (!frag.final) {
    return;
  }

  switch (tmp[0] | tmp[1] << 8 | tmp[2] << 16) {
  case 'm': {
    // Query SGR
    long args[20];
    int argc = vterm_state_getpen(state, args, sizeof(args)/sizeof(args[0]));
    size_t cur = 0;

    cur += (size_t)snprintf(vt->tmpbuffer + cur, vt->tmpbuffer_len - cur,
                            vt->mode.ctrl8bit ? "\x90" "1$r" : ESC_S "P" "1$r");  // DCS 1$r ...
    if (cur >= vt->tmpbuffer_len) {
      return;
    }

    for (int argi = 0; argi < argc; argi++) {
      cur += (size_t)snprintf(vt->tmpbuffer + cur, vt->tmpbuffer_len - cur,
                              argi == argc - 1 ? "%ld"
                                               : CSI_ARG_HAS_MORE(args[argi]) ? "%ld:"
                                                                              : "%ld;",
                              CSI_ARG(args[argi]));
      if (cur >= vt->tmpbuffer_len) {
        return;
      }
    }

    cur += (size_t)snprintf(vt->tmpbuffer + cur, vt->tmpbuffer_len - cur,
                            vt->mode.ctrl8bit ? "m" "\x9C" : "m" ESC_S "\\");  // ... m ST
    if (cur >= vt->tmpbuffer_len) {
      return;
    }

    vterm_push_output_bytes(vt, vt->tmpbuffer, cur);
    return;
  }

  case 'r':
    // Query DECSTBM
    vterm_push_output_sprintf_str(vt, C1_DCS, true,
                                  "1$r%d;%dr", state->scrollregion_top + 1,
                                  SCROLLREGION_BOTTOM(state));
    return;

  case 's':
    // Query DECSLRM
    vterm_push_output_sprintf_str(vt, C1_DCS, true,
                                  "1$r%d;%ds", SCROLLREGION_LEFT(state) + 1,
                                  SCROLLREGION_RIGHT(state));
    return;

  case ' '|('q' << 8): {
    // Query DECSCUSR
    int reply = 0;
    switch (state->mode.cursor_shape) {
    case VTERM_PROP_CURSORSHAPE_BLOCK:
      reply = 2; break;
    case VTERM_PROP_CURSORSHAPE_UNDERLINE:
      reply = 4; break;
    case VTERM_PROP_CURSORSHAPE_BAR_LEFT:
      reply = 6; break;
    }
    if (state->mode.cursor_blink) {
      reply--;
    }
    vterm_push_output_sprintf_str(vt, C1_DCS, true,
                                  "1$r%d q", reply);
    return;
  }

  case '\"'|('q' << 8):
    // Query DECSCA
    vterm_push_output_sprintf_str(vt, C1_DCS, true,
                                  "1$r%d\"q", state->protected_cell ? 1 : 2);
    return;
  }

  vterm_push_output_sprintf_str(state->vt, C1_DCS, true, "0$r");
}

static int on_dcs(const char *command, size_t commandlen, VTermStringFragment frag, void *user)
{
  VTermState *state = user;

  if (commandlen == 2 && strneq(command, "$q", 2)) {
    request_status_string(state, frag);
    return 1;
  } else if (state->fallbacks && state->fallbacks->dcs) {
    if ((*state->fallbacks->dcs)(command, commandlen, frag, state->fbdata)) {
      return 1;
    }
  }

  DEBUG_LOG("libvterm: Unhandled DCS %.*s\n", (int)commandlen, command);
  return 0;
}

static int on_apc(VTermStringFragment frag, void *user)
{
  VTermState *state = user;

  if (state->fallbacks && state->fallbacks->apc) {
    if ((*state->fallbacks->apc)(frag, state->fbdata)) {
      return 1;
    }
  }

  // No DEBUG_LOG because all APCs are unhandled
  return 0;
}

static int on_pm(VTermStringFragment frag, void *user)
{
  VTermState *state = user;

  if (state->fallbacks && state->fallbacks->pm) {
    if ((*state->fallbacks->pm)(frag, state->fbdata)) {
      return 1;
    }
  }

  // No DEBUG_LOG because all PMs are unhandled
  return 0;
}

static int on_sos(VTermStringFragment frag, void *user)
{
  VTermState *state = user;

  if (state->fallbacks && state->fallbacks->sos) {
    if ((*state->fallbacks->sos)(frag, state->fbdata)) {
      return 1;
    }
  }

  // No DEBUG_LOG because all SOSs are unhandled
  return 0;
}

static int on_resize(int rows, int cols, void *user)
{
  VTermState *state = user;
  VTermPos oldpos = state->pos;

  if (cols != state->cols) {
    uint8_t *newtabstops = vterm_allocator_malloc(state->vt, ((size_t)cols + 7) / 8);

    // TODO(vterm): This can all be done much more efficiently bytewise
    int col;
    for (col = 0; col < state->cols && col < cols; col++) {
      uint8_t mask = (uint8_t)(1 << (col & 7));
      if (state->tabstops[col >> 3] & mask) {
        newtabstops[col >> 3] |= mask;
      } else {
        newtabstops[col >> 3] &= ~mask;
      }
    }

    for (; col < cols; col++) {
      uint8_t mask = (uint8_t)(1 << (col & 7));
      if (col % 8 == 0) {
        newtabstops[col >> 3] |= mask;
      } else {
        newtabstops[col >> 3] &= ~mask;
      }
    }

    vterm_allocator_free(state->vt, state->tabstops);
    state->tabstops = newtabstops;
  }

  state->rows = rows;
  state->cols = cols;

  if (state->scrollregion_bottom > -1) {
    UBOUND(state->scrollregion_bottom, state->rows);
  }
  if (state->scrollregion_right > -1) {
    UBOUND(state->scrollregion_right, state->cols);
  }

  VTermStateFields fields = {
    .pos = state->pos,
    .lineinfos = {[0] = state->lineinfos[0], [1] = state->lineinfos[1] },
  };

  if (state->callbacks && state->callbacks->resize) {
    (*state->callbacks->resize)(rows, cols, &fields, state->cbdata);
    state->pos = fields.pos;

    state->lineinfos[0] = fields.lineinfos[0];
    state->lineinfos[1] = fields.lineinfos[1];
  } else {
    if (rows != state->rows) {
      for (int bufidx = BUFIDX_PRIMARY; bufidx <= BUFIDX_ALTSCREEN; bufidx++) {
        VTermLineInfo *oldlineinfo = state->lineinfos[bufidx];
        if (!oldlineinfo) {
          continue;
        }

        VTermLineInfo *newlineinfo = vterm_allocator_malloc(state->vt,
                                                            (size_t)rows * sizeof(VTermLineInfo));

        int row;
        for (row = 0; row < state->rows && row < rows; row++) {
          newlineinfo[row] = oldlineinfo[row];
        }

        for (; row < rows; row++) {
          newlineinfo[row] = (VTermLineInfo){
            .doublewidth = 0,
          };
        }

        vterm_allocator_free(state->vt, state->lineinfos[bufidx]);
        state->lineinfos[bufidx] = newlineinfo;
      }
    }
  }

  state->lineinfo = state->lineinfos[state->mode.alt_screen ? BUFIDX_ALTSCREEN : BUFIDX_PRIMARY];

  if (state->at_phantom && state->pos.col < cols - 1) {
    state->at_phantom = 0;
    state->pos.col++;
  }

  if (state->pos.row < 0) {
    state->pos.row = 0;
  }
  if (state->pos.row >= rows) {
    state->pos.row = rows - 1;
  }
  if (state->pos.col < 0) {
    state->pos.col = 0;
  }
  if (state->pos.col >= cols) {
    state->pos.col = cols - 1;
  }

  updatecursor(state, &oldpos, 1);

  return 1;
}

static const VTermParserCallbacks parser_callbacks = {
  .text = on_text,
  .control = on_control,
  .escape = on_escape,
  .csi = on_csi,
  .osc = on_osc,
  .dcs = on_dcs,
  .apc = on_apc,
  .pm = on_pm,
  .sos = on_sos,
  .resize = on_resize,
};

VTermState *vterm_obtain_state(VTerm *vt)
{
  if (vt->state) {
    return vt->state;
  }

  VTermState *state = vterm_state_new(vt);
  vt->state = state;

  vterm_parser_set_callbacks(vt, &parser_callbacks, state);

  return state;
}

void vterm_state_reset(VTermState *state, int hard)
{
  state->scrollregion_top = 0;
  state->scrollregion_bottom = -1;
  state->scrollregion_left = 0;
  state->scrollregion_right = -1;

  state->mode.keypad = 0;
  state->mode.cursor = 0;
  state->mode.autowrap = 1;
  state->mode.insert = 0;
  state->mode.newline = 0;
  state->mode.alt_screen = 0;
  state->mode.origin = 0;
  state->mode.leftrightmargin = 0;
  state->mode.bracketpaste = 0;
  state->mode.report_focus = 0;

  state->mouse_flags = 0;

  state->vt->mode.ctrl8bit = 0;

  for (int col = 0; col < state->cols; col++) {
    if (col % 8 == 0) {
      set_col_tabstop(state, col);
    } else {
      clear_col_tabstop(state, col);
    }
  }

  for (int row = 0; row < state->rows; row++) {
    set_lineinfo(state, row, FORCE, DWL_OFF, DHL_OFF);
  }

  if (state->callbacks && state->callbacks->initpen) {
    (*state->callbacks->initpen)(state->cbdata);
  }

  vterm_state_resetpen(state);

  VTermEncoding *default_enc = state->vt->mode.utf8
                               ? vterm_lookup_encoding(ENC_UTF8,      'u')
                               : vterm_lookup_encoding(ENC_SINGLE_94, 'B');

  for (int i = 0; i < 4; i++) {
    state->encoding[i].enc = default_enc;
    if (default_enc->init) {
      (*default_enc->init)(default_enc, state->encoding[i].data);
    }
  }

  state->gl_set = 0;
  state->gr_set = 1;
  state->gsingle_set = 0;

  state->protected_cell = 0;

  // Initialise the props
  settermprop_bool(state, VTERM_PROP_CURSORVISIBLE, 1);
  settermprop_bool(state, VTERM_PROP_CURSORBLINK,   1);
  settermprop_int(state, VTERM_PROP_CURSORSHAPE,   VTERM_PROP_CURSORSHAPE_BLOCK);

  if (hard) {
    state->pos.row = 0;
    state->pos.col = 0;
    state->at_phantom = 0;

    VTermRect rect = { 0, state->rows, 0, state->cols };
    erase(state, rect, 0);
  }
}

void vterm_state_set_callbacks(VTermState *state, const VTermStateCallbacks *callbacks, void *user)
{
  if (callbacks) {
    state->callbacks = callbacks;
    state->cbdata = user;

    if (state->callbacks && state->callbacks->initpen) {
      (*state->callbacks->initpen)(state->cbdata);
    }
  } else {
    state->callbacks = NULL;
    state->cbdata = NULL;
  }
}

void vterm_state_set_unrecognised_fallbacks(VTermState *state, const VTermStateFallbacks *fallbacks,
                                            void *user)
{
  if (fallbacks) {
    state->fallbacks = fallbacks;
    state->fbdata = user;
  } else {
    state->fallbacks = NULL;
    state->fbdata = NULL;
  }
}

int vterm_state_set_termprop(VTermState *state, VTermProp prop, VTermValue *val)
{
  // Only store the new value of the property if usercode said it was happy. This is especially
  // important for altscreen switching
  if (state->callbacks && state->callbacks->settermprop) {
    if (!(*state->callbacks->settermprop)(prop, val, state->cbdata)) {
      return 0;
    }
  }

  switch (prop) {
  case VTERM_PROP_TITLE:
  case VTERM_PROP_ICONNAME:
    // we don't store these, just transparently pass through
    return 1;
  case VTERM_PROP_CURSORVISIBLE:
    state->mode.cursor_visible = (unsigned)val->boolean;
    return 1;
  case VTERM_PROP_CURSORBLINK:
    state->mode.cursor_blink = (unsigned)val->boolean;
    return 1;
  case VTERM_PROP_CURSORSHAPE:
    state->mode.cursor_shape = (unsigned)val->number;
    return 1;
  case VTERM_PROP_REVERSE:
    state->mode.screen = (unsigned)val->boolean;
    return 1;
  case VTERM_PROP_ALTSCREEN:
    state->mode.alt_screen = (unsigned)val->boolean;
    state->lineinfo = state->lineinfos[state->mode.alt_screen ? BUFIDX_ALTSCREEN : BUFIDX_PRIMARY];
    if (state->mode.alt_screen) {
      VTermRect rect = {
        .start_row = 0,
        .start_col = 0,
        .end_row = state->rows,
        .end_col = state->cols,
      };
      erase(state, rect, 0);
    }
    return 1;
  case VTERM_PROP_MOUSE:
    state->mouse_flags = 0;
    if (val->number) {
      state->mouse_flags |= MOUSE_WANT_CLICK;
    }
    if (val->number == VTERM_PROP_MOUSE_DRAG) {
      state->mouse_flags |= MOUSE_WANT_DRAG;
    }
    if (val->number == VTERM_PROP_MOUSE_MOVE) {
      state->mouse_flags |= MOUSE_WANT_MOVE;
    }
    return 1;
  case VTERM_PROP_FOCUSREPORT:
    state->mode.report_focus = (unsigned)val->boolean;
    return 1;
  case VTERM_PROP_THEMEUPDATES:
    state->mode.theme_updates = (unsigned)val->boolean;
    return 1;

  case VTERM_N_PROPS:
    return 0;
  }

  return 0;
}

void vterm_state_focus_in(VTermState *state)
{
  if (state->mode.report_focus) {
    vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "I");
  }
}

void vterm_state_focus_out(VTermState *state)
{
  if (state->mode.report_focus) {
    vterm_push_output_sprintf_ctrl(state->vt, C1_CSI, "O");
  }
}

const VTermLineInfo *vterm_state_get_lineinfo(const VTermState *state, int row)
{
  return state->lineinfo + row;
}

void vterm_state_set_selection_callbacks(VTermState *state,
                                         const VTermSelectionCallbacks *callbacks, void *user,
                                         char *buffer, size_t buflen)
{
  if (buflen && !buffer) {
    buffer = vterm_allocator_malloc(state->vt, buflen);
  }

  state->selection.callbacks = callbacks;
  state->selection.user = user;
  state->selection.buffer = buffer;
  state->selection.buflen = buflen;
}
