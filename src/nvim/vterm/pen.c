#include <stdio.h>

#include "nvim/vterm/pen.h"
#include "nvim/vterm/vterm.h"
#include "nvim/vterm/vterm_internal_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "vterm/pen.c.generated.h"
#endif

// Structure used to store RGB triples without the additional metadata stored in VTermColor.
typedef struct {
  uint8_t red, green, blue;
} VTermRGB;

static const VTermRGB ansi_colors[] = {
  // R    G    B
  {   0,   0,   0 },  // black
  { 224,   0,   0 },  // red
  {   0, 224,   0 },  // green
  { 224, 224,   0 },  // yellow
  {   0,   0, 224 },  // blue
  { 224,   0, 224 },  // magenta
  {   0, 224, 224 },  // cyan
  { 224, 224, 224 },  // white == light grey

  // high intensity
  { 128, 128, 128 },  // black
  { 255,  64,  64 },  // red
  {  64, 255,  64 },  // green
  { 255, 255,  64 },  // yellow
  {  64,  64, 255 },  // blue
  { 255,  64, 255 },  // magenta
  {  64, 255, 255 },  // cyan
  { 255, 255, 255 },  // white for real
};

static uint8_t ramp6[] = {
  0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF,
};

static uint8_t ramp24[] = {
  0x00, 0x0B, 0x16, 0x21, 0x2C, 0x37, 0x42, 0x4D, 0x58, 0x63, 0x6E, 0x79,
  0x85, 0x90, 0x9B, 0xA6, 0xB1, 0xBC, 0xC7, 0xD2, 0xDD, 0xE8, 0xF3, 0xFF,
};

static void lookup_default_colour_ansi(long idx, VTermColor *col)
{
  if (idx >= 0 && idx < 16) {
    vterm_color_rgb(col,
                    ansi_colors[idx].red, ansi_colors[idx].green, ansi_colors[idx].blue);
  }
}

static bool lookup_colour_ansi(const VTermState *state, long index, VTermColor *col)
{
  if (index >= 0 && index < 16) {
    *col = state->colors[index];
    return true;
  }

  return false;
}

static bool lookup_colour_palette(const VTermState *state, long index, VTermColor *col)
{
  if (index >= 0 && index < 16) {
    // Normal 8 colours or high intensity - parse as palette 0
    return lookup_colour_ansi(state, index, col);
  } else if (index >= 16 && index < 232) {
    // 216-colour cube
    index -= 16;

    vterm_color_rgb(col, ramp6[index/6/6 % 6],
                    ramp6[index/6   % 6],
                    ramp6[index     % 6]);

    return true;
  } else if (index >= 232 && index < 256) {
    // 24 greyscales
    index -= 232;

    vterm_color_rgb(col, ramp24[index], ramp24[index], ramp24[index]);

    return true;
  }

  return false;
}

static int lookup_colour(const VTermState *state, int palette, const long args[], int argcount,
                         VTermColor *col)
{
  switch (palette) {
  case 2:  // RGB mode - 3 args contain colour values directly
    if (argcount < 3) {
      return argcount;
    }

    vterm_color_rgb(col, (uint8_t)CSI_ARG(args[0]), (uint8_t)CSI_ARG(args[1]),
                    (uint8_t)CSI_ARG(args[2]));

    return 3;

  case 5:  // XTerm 256-colour mode
    if (!argcount || CSI_ARG_IS_MISSING(args[0])) {
      return argcount ? 1 : 0;
    }

    vterm_color_indexed(col, (uint8_t)args[0]);

    return argcount ? 1 : 0;

  default:
    DEBUG_LOG("Unrecognised colour palette %d\n", palette);
    return 0;
  }
}

// Some conveniences

static void setpenattr(VTermState *state, VTermAttr attr, VTermValueType type, VTermValue *val)
{
#ifdef DEBUG
  if (type != vterm_get_attr_type(attr)) {
    DEBUG_LOG("Cannot set attr %d as it has type %d, not type %d\n",
              attr, vterm_get_attr_type(attr), type);
    return;
  }
#endif
  if (state->callbacks && state->callbacks->setpenattr) {
    (*state->callbacks->setpenattr)(attr, val, state->cbdata);
  }
}

static void setpenattr_bool(VTermState *state, VTermAttr attr, int boolean)
{
  VTermValue val = { .boolean = boolean };
  setpenattr(state, attr, VTERM_VALUETYPE_BOOL, &val);
}

static void setpenattr_int(VTermState *state, VTermAttr attr, int number)
{
  VTermValue val = { .number = number };
  setpenattr(state, attr, VTERM_VALUETYPE_INT, &val);
}

static void setpenattr_col(VTermState *state, VTermAttr attr, VTermColor color)
{
  VTermValue val = { .color = color };
  setpenattr(state, attr, VTERM_VALUETYPE_COLOR, &val);
}

static void set_pen_col_ansi(VTermState *state, VTermAttr attr, long col)
{
  VTermColor *colp = (attr == VTERM_ATTR_BACKGROUND) ? &state->pen.bg : &state->pen.fg;

  vterm_color_indexed(colp, (uint8_t)col);

  setpenattr_col(state, attr, *colp);
}

void vterm_state_newpen(VTermState *state)
{
  // 90% grey so that pure white is brighter
  vterm_color_rgb(&state->default_fg, 240, 240, 240);
  vterm_color_rgb(&state->default_bg, 0, 0, 0);
  vterm_state_set_default_colors(state, &state->default_fg, &state->default_bg);

  for (int col = 0; col < 16; col++) {
    lookup_default_colour_ansi(col, &state->colors[col]);
  }
}

void vterm_state_resetpen(VTermState *state)
{
  state->pen.bold = 0;      setpenattr_bool(state, VTERM_ATTR_BOLD, 0);
  state->pen.underline = 0; setpenattr_int(state, VTERM_ATTR_UNDERLINE, 0);
  state->pen.italic = 0;    setpenattr_bool(state, VTERM_ATTR_ITALIC, 0);
  state->pen.blink = 0;     setpenattr_bool(state, VTERM_ATTR_BLINK, 0);
  state->pen.reverse = 0;   setpenattr_bool(state, VTERM_ATTR_REVERSE, 0);
  state->pen.conceal = 0;   setpenattr_bool(state, VTERM_ATTR_CONCEAL, 0);
  state->pen.strike = 0;    setpenattr_bool(state, VTERM_ATTR_STRIKE, 0);
  state->pen.font = 0;      setpenattr_int(state, VTERM_ATTR_FONT, 0);
  state->pen.small = 0;     setpenattr_bool(state, VTERM_ATTR_SMALL, 0);
  state->pen.baseline = 0;  setpenattr_int(state, VTERM_ATTR_BASELINE, 0);

  state->pen.fg = state->default_fg;
  setpenattr_col(state, VTERM_ATTR_FOREGROUND, state->default_fg);
  state->pen.bg = state->default_bg;
  setpenattr_col(state, VTERM_ATTR_BACKGROUND, state->default_bg);

  state->pen.uri = 0; setpenattr_int(state, VTERM_ATTR_URI, 0);
}

void vterm_state_savepen(VTermState *state, int save)
{
  if (save) {
    state->saved.pen = state->pen;
  } else {
    state->pen = state->saved.pen;

    setpenattr_bool(state, VTERM_ATTR_BOLD,      state->pen.bold);
    setpenattr_int(state, VTERM_ATTR_UNDERLINE, state->pen.underline);
    setpenattr_bool(state, VTERM_ATTR_ITALIC,    state->pen.italic);
    setpenattr_bool(state, VTERM_ATTR_BLINK,     state->pen.blink);
    setpenattr_bool(state, VTERM_ATTR_REVERSE,   state->pen.reverse);
    setpenattr_bool(state, VTERM_ATTR_CONCEAL,   state->pen.conceal);
    setpenattr_bool(state, VTERM_ATTR_STRIKE,    state->pen.strike);
    setpenattr_int(state, VTERM_ATTR_FONT,      state->pen.font);
    setpenattr_bool(state, VTERM_ATTR_SMALL,     state->pen.small);
    setpenattr_int(state, VTERM_ATTR_BASELINE,  state->pen.baseline);

    setpenattr_col(state, VTERM_ATTR_FOREGROUND, state->pen.fg);
    setpenattr_col(state, VTERM_ATTR_BACKGROUND, state->pen.bg);

    setpenattr_int(state, VTERM_ATTR_URI, state->pen.uri);
  }
}

void vterm_state_set_default_colors(VTermState *state, const VTermColor *default_fg,
                                    const VTermColor *default_bg)
{
  if (default_fg) {
    state->default_fg = *default_fg;
    state->default_fg.type = (state->default_fg.type & ~VTERM_COLOR_DEFAULT_MASK)
                             | VTERM_COLOR_DEFAULT_FG;
  }

  if (default_bg) {
    state->default_bg = *default_bg;
    state->default_bg.type = (state->default_bg.type & ~VTERM_COLOR_DEFAULT_MASK)
                             | VTERM_COLOR_DEFAULT_BG;
  }
}

void vterm_state_set_palette_color(VTermState *state, int index, const VTermColor *col)
{
  if (index >= 0 && index < 16) {
    state->colors[index] = *col;
  }
}

/// Makes sure that the given color `col` is indeed an RGB colour. After this
/// function returns, VTERM_COLOR_IS_RGB(col) will return true, while all other
/// flags stored in `col->type` will have been reset.
///
/// @param state is the VTermState instance from which the colour palette should
/// be extracted.
/// @param col is a pointer at the VTermColor instance that should be converted
/// to an RGB colour.
void vterm_state_convert_color_to_rgb(const VTermState *state, VTermColor *col)
{
  if (VTERM_COLOR_IS_INDEXED(col)) {  // Convert indexed colors to RGB
    lookup_colour_palette(state, col->indexed.idx, col);
  }
  col->type &= VTERM_COLOR_TYPE_MASK;  // Reset any metadata but the type
}

void vterm_state_setpen(VTermState *state, const long args[], int argcount)
{
  // SGR - ECMA-48 8.3.117

  int argi = 0;
  int value;

  while (argi < argcount) {
    // This logic is easier to do 'done' backwards; set it true, and make it
    // false again in the 'default' case
    int done = 1;

    long arg;
    switch (arg = CSI_ARG(args[argi])) {
    case CSI_ARG_MISSING:
    case 0:  // Reset
      vterm_state_resetpen(state);
      break;

    case 1: {  // Bold on
      const VTermColor *fg = &state->pen.fg;
      state->pen.bold = 1;
      setpenattr_bool(state, VTERM_ATTR_BOLD, 1);
      if (!VTERM_COLOR_IS_DEFAULT_FG(fg) && VTERM_COLOR_IS_INDEXED(fg) && fg->indexed.idx < 8
          && state->bold_is_highbright) {
        set_pen_col_ansi(state, VTERM_ATTR_FOREGROUND, fg->indexed.idx + (state->pen.bold ? 8 : 0));
      }
      break;
    }

    case 3:  // Italic on
      state->pen.italic = 1;
      setpenattr_bool(state, VTERM_ATTR_ITALIC, 1);
      break;

    case 4:  // Underline
      state->pen.underline = VTERM_UNDERLINE_SINGLE;
      if (CSI_ARG_HAS_MORE(args[argi])) {
        argi++;
        switch (CSI_ARG(args[argi])) {
        case 0:
          state->pen.underline = 0;
          break;
        case 1:
          state->pen.underline = VTERM_UNDERLINE_SINGLE;
          break;
        case 2:
          state->pen.underline = VTERM_UNDERLINE_DOUBLE;
          break;
        case 3:
          state->pen.underline = VTERM_UNDERLINE_CURLY;
          break;
        }
      }
      setpenattr_int(state, VTERM_ATTR_UNDERLINE, state->pen.underline);
      break;

    case 5:  // Blink
      state->pen.blink = 1;
      setpenattr_bool(state, VTERM_ATTR_BLINK, 1);
      break;

    case 7:  // Reverse on
      state->pen.reverse = 1;
      setpenattr_bool(state, VTERM_ATTR_REVERSE, 1);
      break;

    case 8:  // Conceal on
      state->pen.conceal = 1;
      setpenattr_bool(state, VTERM_ATTR_CONCEAL, 1);
      break;

    case 9:  // Strikethrough on
      state->pen.strike = 1;
      setpenattr_bool(state, VTERM_ATTR_STRIKE, 1);
      break;

    case 10:
    case 11:
    case 12:
    case 13:
    case 14:
    case 15:
    case 16:
    case 17:
    case 18:
    case 19:  // Select font
      state->pen.font = CSI_ARG(args[argi]) - 10;
      setpenattr_int(state, VTERM_ATTR_FONT, state->pen.font);
      break;

    case 21:  // Underline double
      state->pen.underline = VTERM_UNDERLINE_DOUBLE;
      setpenattr_int(state, VTERM_ATTR_UNDERLINE, state->pen.underline);
      break;

    case 22:  // Bold off
      state->pen.bold = 0;
      setpenattr_bool(state, VTERM_ATTR_BOLD, 0);
      break;

    case 23:  // Italic and Gothic (currently unsupported) off
      state->pen.italic = 0;
      setpenattr_bool(state, VTERM_ATTR_ITALIC, 0);
      break;

    case 24:  // Underline off
      state->pen.underline = 0;
      setpenattr_int(state, VTERM_ATTR_UNDERLINE, 0);
      break;

    case 25:  // Blink off
      state->pen.blink = 0;
      setpenattr_bool(state, VTERM_ATTR_BLINK, 0);
      break;

    case 27:  // Reverse off
      state->pen.reverse = 0;
      setpenattr_bool(state, VTERM_ATTR_REVERSE, 0);
      break;

    case 28:  // Conceal off (Reveal)
      state->pen.conceal = 0;
      setpenattr_bool(state, VTERM_ATTR_CONCEAL, 0);
      break;

    case 29:  // Strikethrough off
      state->pen.strike = 0;
      setpenattr_bool(state, VTERM_ATTR_STRIKE, 0);
      break;

    case 30:
    case 31:
    case 32:
    case 33:
    case 34:
    case 35:
    case 36:
    case 37:  // Foreground colour palette
      value = CSI_ARG(args[argi]) - 30;
      if (state->pen.bold && state->bold_is_highbright) {
        value += 8;
      }
      set_pen_col_ansi(state, VTERM_ATTR_FOREGROUND, value);
      break;

    case 38:  // Foreground colour alternative palette
      if (argcount - argi < 1) {
        return;
      }
      argi += 1 + lookup_colour(state, CSI_ARG(args[argi + 1]), args + argi + 2,
                                argcount - argi - 2, &state->pen.fg);
      setpenattr_col(state, VTERM_ATTR_FOREGROUND, state->pen.fg);
      break;

    case 39:  // Foreground colour default
      state->pen.fg = state->default_fg;
      setpenattr_col(state, VTERM_ATTR_FOREGROUND, state->pen.fg);
      break;

    case 40:
    case 41:
    case 42:
    case 43:
    case 44:
    case 45:
    case 46:
    case 47:  // Background colour palette
      value = CSI_ARG(args[argi]) - 40;
      set_pen_col_ansi(state, VTERM_ATTR_BACKGROUND, value);
      break;

    case 48:  // Background colour alternative palette
      if (argcount - argi < 1) {
        return;
      }
      argi += 1 + lookup_colour(state, CSI_ARG(args[argi + 1]), args + argi + 2,
                                argcount - argi - 2, &state->pen.bg);
      setpenattr_col(state, VTERM_ATTR_BACKGROUND, state->pen.bg);
      break;

    case 49:  // Default background
      state->pen.bg = state->default_bg;
      setpenattr_col(state, VTERM_ATTR_BACKGROUND, state->pen.bg);
      break;

    case 73:  // Superscript
    case 74:  // Subscript
    case 75:  // Superscript/subscript off
      state->pen.small = (arg != 75);
      state->pen.baseline =
        (arg == 73) ? VTERM_BASELINE_RAISE
                    : (arg == 74) ? VTERM_BASELINE_LOWER
                                  : VTERM_BASELINE_NORMAL;
      setpenattr_bool(state, VTERM_ATTR_SMALL,    state->pen.small);
      setpenattr_int(state, VTERM_ATTR_BASELINE, state->pen.baseline);
      break;

    case 90:
    case 91:
    case 92:
    case 93:
    case 94:
    case 95:
    case 96:
    case 97:  // Foreground colour high-intensity palette
      value = CSI_ARG(args[argi]) - 90 + 8;
      set_pen_col_ansi(state, VTERM_ATTR_FOREGROUND, value);
      break;

    case 100:
    case 101:
    case 102:
    case 103:
    case 104:
    case 105:
    case 106:
    case 107:  // Background colour high-intensity palette
      value = CSI_ARG(args[argi]) - 100 + 8;
      set_pen_col_ansi(state, VTERM_ATTR_BACKGROUND, value);
      break;

    default:
      done = 0;
      break;
    }

    if (!done) {
      DEBUG_LOG("libvterm: Unhandled CSI SGR %ld\n", arg);
    }

    while (CSI_ARG_HAS_MORE(args[argi++])) {}
  }
}

static int vterm_state_getpen_color(const VTermColor *col, int argi, long args[], int fg)
{
  // Do nothing if the given color is the default color
  if ((fg && VTERM_COLOR_IS_DEFAULT_FG(col))
      || (!fg && VTERM_COLOR_IS_DEFAULT_BG(col))) {
    return argi;
  }

  // Decide whether to send an indexed color or an RGB color
  if (VTERM_COLOR_IS_INDEXED(col)) {
    const uint8_t idx = col->indexed.idx;
    if (idx < 8) {
      args[argi++] = (idx + (fg ? 30 : 40));
    } else if (idx < 16) {
      args[argi++] = (idx - 8 + (fg ? 90 : 100));
    } else {
      args[argi++] = CSI_ARG_FLAG_MORE | (fg ? 38 : 48);
      args[argi++] = CSI_ARG_FLAG_MORE | 5;
      args[argi++] = idx;
    }
  } else if (VTERM_COLOR_IS_RGB(col)) {
    args[argi++] = CSI_ARG_FLAG_MORE | (fg ? 38 : 48);
    args[argi++] = CSI_ARG_FLAG_MORE | 2;
    args[argi++] = CSI_ARG_FLAG_MORE | col->rgb.red;
    args[argi++] = CSI_ARG_FLAG_MORE | col->rgb.green;
    args[argi++] = col->rgb.blue;
  }
  return argi;
}

int vterm_state_getpen(VTermState *state, long args[], int argcount)
{
  int argi = 0;

  if (state->pen.bold) {
    args[argi++] = 1;
  }

  if (state->pen.italic) {
    args[argi++] = 3;
  }

  if (state->pen.underline == VTERM_UNDERLINE_SINGLE) {
    args[argi++] = 4;
  }
  if (state->pen.underline == VTERM_UNDERLINE_CURLY) {
    args[argi++] = 4 | CSI_ARG_FLAG_MORE, args[argi++] = 3;
  }

  if (state->pen.blink) {
    args[argi++] = 5;
  }

  if (state->pen.reverse) {
    args[argi++] = 7;
  }

  if (state->pen.conceal) {
    args[argi++] = 8;
  }

  if (state->pen.strike) {
    args[argi++] = 9;
  }

  if (state->pen.font) {
    args[argi++] = 10 + state->pen.font;
  }

  if (state->pen.underline == VTERM_UNDERLINE_DOUBLE) {
    args[argi++] = 21;
  }

  argi = vterm_state_getpen_color(&state->pen.fg, argi, args, true);

  argi = vterm_state_getpen_color(&state->pen.bg, argi, args, false);

  if (state->pen.small) {
    if (state->pen.baseline == VTERM_BASELINE_RAISE) {
      args[argi++] = 73;
    } else if (state->pen.baseline == VTERM_BASELINE_LOWER) {
      args[argi++] = 74;
    }
  }

  return argi;
}

int vterm_state_set_penattr(VTermState *state, VTermAttr attr, VTermValueType type, VTermValue *val)
{
  if (!val) {
    return 0;
  }

  if (type != vterm_get_attr_type(attr)) {
    DEBUG_LOG("Cannot set attr %d as it has type %d, not type %d\n",
              attr, vterm_get_attr_type(attr), type);
    return 0;
  }

  switch (attr) {
  case VTERM_ATTR_BOLD:
    state->pen.bold = (unsigned)val->boolean;
    break;
  case VTERM_ATTR_UNDERLINE:
    state->pen.underline = (unsigned)val->number;
    break;
  case VTERM_ATTR_ITALIC:
    state->pen.italic = (unsigned)val->boolean;
    break;
  case VTERM_ATTR_BLINK:
    state->pen.blink = (unsigned)val->boolean;
    break;
  case VTERM_ATTR_REVERSE:
    state->pen.reverse = (unsigned)val->boolean;
    break;
  case VTERM_ATTR_CONCEAL:
    state->pen.conceal = (unsigned)val->boolean;
    break;
  case VTERM_ATTR_STRIKE:
    state->pen.strike = (unsigned)val->boolean;
    break;
  case VTERM_ATTR_FONT:
    state->pen.font = (unsigned)val->number;
    break;
  case VTERM_ATTR_FOREGROUND:
    state->pen.fg = val->color;
    break;
  case VTERM_ATTR_BACKGROUND:
    state->pen.bg = val->color;
    break;
  case VTERM_ATTR_SMALL:
    state->pen.small = (unsigned)val->boolean;
    break;
  case VTERM_ATTR_BASELINE:
    state->pen.baseline = (unsigned)val->number;
    break;
  case VTERM_ATTR_URI:
    state->pen.uri = val->number;
    break;
  default:
    return 0;
  }

  if (state->callbacks && state->callbacks->setpenattr) {
    (*state->callbacks->setpenattr)(attr, val, state->cbdata);
  }

  return 1;
}
