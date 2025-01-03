#include <stdio.h>
#include <string.h>

#include "nvim/grid.h"
#include "nvim/mbyte.h"
#include "nvim/vterm/pen.h"
#include "nvim/vterm/screen.h"
#include "nvim/vterm/vterm_internal_defs.h"
#include "vterm_test.h"

int parser_text(const char bytes[], size_t len, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "text ");
  size_t i;
  for (i = 0; i < len; i++) {
    unsigned char b = (unsigned char)bytes[i];
    if (b < 0x20 || b == 0x7f || (b >= 0x80 && b < 0xa0)) {
      break;
    }
    fprintf(f, i ? ",%x" : "%x", b);
  }
  fprintf(f, "\n");
  fclose(f);

  return (int)i;
}

static void printchars(const char *s, size_t len, FILE *f)
{
  while (len--) {
    fprintf(f, "%c", (s++)[0]);
  }
}

int parser_csi(const char *leader, const long args[], int argcount, const char *intermed,
               char command, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "csi %02x", command);

  if (leader && leader[0]) {
    fprintf(f, " L=");
    for (int i = 0; leader[i]; i++) {
      fprintf(f, "%02x", leader[i]);
    }
  }

  for (int i = 0; i < argcount; i++) {
    char sep = i ? ',' : ' ';

    if (args[i] == CSI_ARG_MISSING) {
      fprintf(f, "%c*", sep);
    } else {
      fprintf(f, "%c%ld%s", sep, CSI_ARG(args[i]), CSI_ARG_HAS_MORE(args[i]) ? "+" : "");
    }
  }

  if (intermed && intermed[0]) {
    fprintf(f, " I=");
    for (int i = 0; intermed[i]; i++) {
      fprintf(f, "%02x", intermed[i]);
    }
  }

  fprintf(f, "\n");

  fclose(f);

  return 1;
}

int parser_osc(int command, VTermStringFragment frag, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "osc ");

  if (frag.initial) {
    if (command == -1) {
      fprintf(f, "[");
    } else {
      fprintf(f, "[%d;", command);
    }
  }

  printchars(frag.str, frag.len, f);

  if (frag.final) {
    fprintf(f, "]");
  }

  fprintf(f, "\n");
  fclose(f);

  return 1;
}

int parser_dcs(const char *command, size_t commandlen, VTermStringFragment frag, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "dcs ");

  if (frag.initial) {
    fprintf(f, "[");
    for (size_t i = 0; i < commandlen; i++) {
      fprintf(f, "%c", command[i]);
    }
  }

  printchars(frag.str, frag.len, f);

  if (frag.final) {
    fprintf(f, "]");
  }

  fprintf(f, "\n");
  fclose(f);

  return 1;
}

int parser_apc(VTermStringFragment frag, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "apc ");

  if (frag.initial) {
    fprintf(f, "[");
  }

  printchars(frag.str, frag.len, f);

  if (frag.final) {
    fprintf(f, "]");
  }

  fprintf(f, "\n");
  fclose(f);

  return 1;
}

int parser_pm(VTermStringFragment frag, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "pm ");

  if (frag.initial) {
    fprintf(f, "[");
  }

  printchars(frag.str, frag.len, f);

  if (frag.final) {
    fprintf(f, "]");
  }

  fprintf(f, "\n");
  fclose(f);

  return 1;
}

int parser_sos(VTermStringFragment frag, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "sos ");

  if (frag.initial) {
    fprintf(f, "[");
  }

  printchars(frag.str, frag.len, f);

  if (frag.final) {
    fprintf(f, "]");
  }

  fprintf(f, "\n");
  fclose(f);

  return 1;
}

int selection_set(VTermSelectionMask mask, VTermStringFragment frag, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "selection-set mask=%04X ", mask);
  if (frag.initial) {
    fprintf(f, "[");
  }
  printchars(frag.str, frag.len, f);
  if (frag.final) {
    fprintf(f, "]");
  }
  fprintf(f, "\n");

  fclose(f);
  return 1;
}

int selection_query(VTermSelectionMask mask, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "selection-query mask=%04X\n", mask);

  fclose(f);
  return 1;
}

static void print_schar(FILE *f, schar_T schar)
{
  char buf[MAX_SCHAR_SIZE];
  schar_get(buf, schar);
  StrCharInfo ci = utf_ptr2StrCharInfo(buf);
  bool did = false;
  while (*ci.ptr != 0) {
    if (did) {
      fprintf(f, ",");
    }

    if (ci.chr.len == 1 && ci.chr.value >= 0x80) {
      fprintf(f, "??%x", ci.chr.value);
    } else {
      fprintf(f, "%x", ci.chr.value);
    }
    did = true;
    ci = utf_ptr2StrCharInfo(ci.ptr + ci.chr.len);
  }
}

bool want_state_putglyph;
int state_putglyph(VTermGlyphInfo *info, VTermPos pos, void *user)
{
  if (!want_state_putglyph) {
    return 1;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "putglyph ");
  print_schar(f, info->schar);
  fprintf(f, " %d %d,%d", info->width, pos.row, pos.col);
  if (info->protected_cell) {
    fprintf(f, " prot");
  }
  if (info->dwl) {
    fprintf(f, " dwl");
  }
  if (info->dhl) {
    fprintf(f, " dhl-%s", info->dhl == 1 ? "top" : info->dhl == 2 ? "bottom" : "?");
  }
  fprintf(f, "\n");

  fclose(f);

  return 1;
}

bool want_state_movecursor;
VTermPos state_pos;
int state_movecursor(VTermPos pos, VTermPos oldpos, int visible, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  state_pos = pos;

  if (want_state_movecursor) {
    fprintf(f, "movecursor %d,%d\n", pos.row, pos.col);
  }

  fclose(f);
  return 1;
}

bool want_state_scrollrect;
int state_scrollrect(VTermRect rect, int downward, int rightward, void *user)
{
  if (!want_state_scrollrect) {
    return 0;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");

  fprintf(f, "scrollrect %d..%d,%d..%d => %+d,%+d\n",
          rect.start_row, rect.end_row, rect.start_col, rect.end_col,
          downward, rightward);

  fclose(f);
  return 1;
}

bool want_state_moverect;
int state_moverect(VTermRect dest, VTermRect src, void *user)
{
  if (!want_state_moverect) {
    return 0;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "moverect %d..%d,%d..%d -> %d..%d,%d..%d\n",
          src.start_row,  src.end_row,  src.start_col,  src.end_col,
          dest.start_row, dest.end_row, dest.start_col, dest.end_col);

  fclose(f);
  return 1;
}

void print_color(const VTermColor *col)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  if (VTERM_COLOR_IS_RGB(col)) {
    fprintf(f, "rgb(%d,%d,%d", col->rgb.red, col->rgb.green, col->rgb.blue);
  } else if (VTERM_COLOR_IS_INDEXED(col)) {
    fprintf(f, "idx(%d", col->indexed.idx);
  } else {
    fprintf(f, "invalid(%d", col->type);
  }
  if (VTERM_COLOR_IS_DEFAULT_FG(col)) {
    fprintf(f, ",is_default_fg");
  }
  if (VTERM_COLOR_IS_DEFAULT_BG(col)) {
    fprintf(f, ",is_default_bg");
  }
  fprintf(f, ")");
  fclose(f);
}

static VTermValueType vterm_get_prop_type(VTermProp prop)
{
  switch (prop) {
  case VTERM_PROP_CURSORVISIBLE:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_PROP_CURSORBLINK:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_PROP_ALTSCREEN:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_PROP_TITLE:
    return VTERM_VALUETYPE_STRING;
  case VTERM_PROP_ICONNAME:
    return VTERM_VALUETYPE_STRING;
  case VTERM_PROP_REVERSE:
    return VTERM_VALUETYPE_BOOL;
  case VTERM_PROP_CURSORSHAPE:
    return VTERM_VALUETYPE_INT;
  case VTERM_PROP_MOUSE:
    return VTERM_VALUETYPE_INT;
  case VTERM_PROP_FOCUSREPORT:
    return VTERM_VALUETYPE_BOOL;

  case VTERM_N_PROPS:
    return 0;
  }
  return 0;  // UNREACHABLE
}

bool want_state_settermprop;
int state_settermprop(VTermProp prop, VTermValue *val, void *user)
{
  if (!want_state_settermprop) {
    return 1;
  }

  int errcode = 0;
  FILE *f = fopen(VTERM_TEST_FILE, "a");

  VTermValueType type = vterm_get_prop_type(prop);
  switch (type) {
  case VTERM_VALUETYPE_BOOL:
    fprintf(f, "settermprop %d %s\n", prop, val->boolean ? "true" : "false");
    errcode = 1;
    goto end;
  case VTERM_VALUETYPE_INT:
    fprintf(f, "settermprop %d %d\n", prop, val->number);
    errcode = 1;
    goto end;
  case VTERM_VALUETYPE_STRING:
    fprintf(f, "settermprop %d %s\"%.*s\"%s\n", prop,
            val->string.initial ? "[" : "", (int)val->string.len, val->string.str,
            val->string.final ? "]" : "");
    errcode = 0;
    goto end;
  case VTERM_VALUETYPE_COLOR:
    fprintf(f, "settermprop %d ", prop);
    print_color(&val->color);
    fprintf(f, "\n");
    errcode = 1;
    goto end;
  case VTERM_N_VALUETYPES:
    goto end;
  }

end:
  fclose(f);
  return errcode;
}

bool want_state_erase;
int state_erase(VTermRect rect, int selective, void *user)
{
  if (!want_state_erase) {
    return 1;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");

  fprintf(f, "erase %d..%d,%d..%d%s\n",
          rect.start_row, rect.end_row, rect.start_col, rect.end_col,
          selective ? " selective" : "");

  fclose(f);
  return 1;
}

struct {
  int bold;
  int underline;
  int italic;
  int blink;
  int reverse;
  int conceal;
  int strike;
  int font;
  int small;
  int baseline;
  VTermColor foreground;
  VTermColor background;
} state_pen;

int state_setpenattr(VTermAttr attr, VTermValue *val, void *user)
{
  switch (attr) {
  case VTERM_ATTR_BOLD:
    state_pen.bold = val->boolean;
    break;
  case VTERM_ATTR_UNDERLINE:
    state_pen.underline = val->number;
    break;
  case VTERM_ATTR_ITALIC:
    state_pen.italic = val->boolean;
    break;
  case VTERM_ATTR_BLINK:
    state_pen.blink = val->boolean;
    break;
  case VTERM_ATTR_REVERSE:
    state_pen.reverse = val->boolean;
    break;
  case VTERM_ATTR_CONCEAL:
    state_pen.conceal = val->boolean;
    break;
  case VTERM_ATTR_STRIKE:
    state_pen.strike = val->boolean;
    break;
  case VTERM_ATTR_FONT:
    state_pen.font = val->number;
    break;
  case VTERM_ATTR_SMALL:
    state_pen.small = val->boolean;
    break;
  case VTERM_ATTR_BASELINE:
    state_pen.baseline = val->number;
    break;
  case VTERM_ATTR_FOREGROUND:
    state_pen.foreground = val->color;
    break;
  case VTERM_ATTR_BACKGROUND:
    state_pen.background = val->color;
    break;

  case VTERM_N_ATTRS:
    return 0;
  default:
    break;
  }

  return 1;
}

bool want_state_scrollback;
int state_sb_clear(void *user)
{
  if (!want_state_scrollback) {
    return 1;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "sb_clear\n");
  fclose(f);

  return 0;
}

bool want_screen_scrollback;
int screen_sb_pushline(int cols, const VTermScreenCell *cells, void *user)
{
  if (!want_screen_scrollback) {
    return 1;
  }

  int eol = cols;
  while (eol && !cells[eol - 1].schar) {
    eol--;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "sb_pushline %d =", cols);
  for (int c = 0; c < eol; c++) {
    fprintf(f, " ");
    print_schar(f, cells[c].schar);
  }
  fprintf(f, "\n");

  fclose(f);

  return 1;
}

int screen_sb_popline(int cols, VTermScreenCell *cells, void *user)
{
  if (!want_screen_scrollback) {
    return 0;
  }

  // All lines of scrollback contain "ABCDE"
  for (int col = 0; col < cols; col++) {
    if (col < 5) {
      cells[col].schar = schar_from_ascii((uint32_t)('A' + col));
    } else {
      cells[col].schar = 0;
    }

    cells[col].width = 1;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "sb_popline %d\n", cols);
  fclose(f);
  return 1;
}

int screen_sb_clear(void *user)
{
  if (!want_screen_scrollback) {
    return 1;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "sb_clear\n");
  fclose(f);
  return 0;
}

void term_output(const char *s, size_t len, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "output ");
  for (size_t i = 0; i < len; i++) {
    fprintf(f, "%x%s", (unsigned char)s[i], i < len - 1 ? "," : "\n");
  }
  fclose(f);
}

int vterm_state_get_penattr(const VTermState *state, VTermAttr attr, VTermValue *val)
{
  switch (attr) {
  case VTERM_ATTR_BOLD:
    val->boolean = state->pen.bold;
    return 1;

  case VTERM_ATTR_UNDERLINE:
    val->number = state->pen.underline;
    return 1;

  case VTERM_ATTR_ITALIC:
    val->boolean = state->pen.italic;
    return 1;

  case VTERM_ATTR_BLINK:
    val->boolean = state->pen.blink;
    return 1;

  case VTERM_ATTR_REVERSE:
    val->boolean = state->pen.reverse;
    return 1;

  case VTERM_ATTR_CONCEAL:
    val->boolean = state->pen.conceal;
    return 1;

  case VTERM_ATTR_STRIKE:
    val->boolean = state->pen.strike;
    return 1;

  case VTERM_ATTR_FONT:
    val->number = state->pen.font;
    return 1;

  case VTERM_ATTR_FOREGROUND:
    val->color = state->pen.fg;
    return 1;

  case VTERM_ATTR_BACKGROUND:
    val->color = state->pen.bg;
    return 1;

  case VTERM_ATTR_SMALL:
    val->boolean = state->pen.small;
    return 1;

  case VTERM_ATTR_BASELINE:
    val->number = state->pen.baseline;
    return 1;

  case VTERM_ATTR_URI:
    val->number = state->pen.uri;
    return 1;

  case VTERM_N_ATTRS:
    return 0;
  }

  return 0;
}

static int attrs_differ(VTermAttrMask attrs, ScreenCell *a, ScreenCell *b)
{
  if ((attrs & VTERM_ATTR_BOLD_MASK) && (a->pen.bold != b->pen.bold)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_UNDERLINE_MASK) && (a->pen.underline != b->pen.underline)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_ITALIC_MASK) && (a->pen.italic != b->pen.italic)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_BLINK_MASK) && (a->pen.blink != b->pen.blink)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_REVERSE_MASK) && (a->pen.reverse != b->pen.reverse)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_CONCEAL_MASK) && (a->pen.conceal != b->pen.conceal)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_STRIKE_MASK) && (a->pen.strike != b->pen.strike)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_FONT_MASK) && (a->pen.font != b->pen.font)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_FOREGROUND_MASK) && !vterm_color_is_equal(&a->pen.fg, &b->pen.fg)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_BACKGROUND_MASK) && !vterm_color_is_equal(&a->pen.bg, &b->pen.bg)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_SMALL_MASK) && (a->pen.small != b->pen.small)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_BASELINE_MASK) && (a->pen.baseline != b->pen.baseline)) {
    return 1;
  }
  if ((attrs & VTERM_ATTR_URI_MASK) && (a->pen.uri != b->pen.uri)) {
    return 1;
  }

  return 0;
}

int vterm_screen_get_attrs_extent(const VTermScreen *screen, VTermRect *extent, VTermPos pos,
                                  VTermAttrMask attrs)
{
  ScreenCell *target = getcell(screen, pos.row, pos.col);

  // TODO(vterm): bounds check
  extent->start_row = pos.row;
  extent->end_row = pos.row + 1;

  if (extent->start_col < 0) {
    extent->start_col = 0;
  }
  if (extent->end_col < 0) {
    extent->end_col = screen->cols;
  }

  int col;

  for (col = pos.col - 1; col >= extent->start_col; col--) {
    if (attrs_differ(attrs, target, getcell(screen, pos.row, col))) {
      break;
    }
  }
  extent->start_col = col + 1;

  for (col = pos.col + 1; col < extent->end_col; col++) {
    if (attrs_differ(attrs, target, getcell(screen, pos.row, col))) {
      break;
    }
  }
  extent->end_col = col - 1;

  return 1;
}

/// Does not NUL-terminate the buffer
size_t vterm_screen_get_text(const VTermScreen *screen, char *buffer, size_t len,
                             const VTermRect rect)
{
  size_t outpos = 0;
  int padding = 0;

#define PUT(bytes, thislen) \
  if (true) { \
    if (buffer && outpos + thislen <= len) \
    memcpy((char *)buffer + outpos, bytes, thislen); \
    outpos += thislen; \
  } \

  for (int row = rect.start_row; row < rect.end_row; row++) {
    for (int col = rect.start_col; col < rect.end_col; col++) {
      ScreenCell *cell = getcell(screen, row, col);

      if (cell->schar == 0) {
        // Erased cell, might need a space
        padding++;
      } else if (cell->schar == (uint32_t)-1) {
        // Gap behind a double-width char, do nothing
      } else {
        while (padding) {
          PUT(" ", 1);
          padding--;
        }
        char buf[MAX_SCHAR_SIZE + 1];
        size_t thislen = schar_get(buf, cell->schar);
        PUT(buf, thislen);
      }
    }

    if (row < rect.end_row - 1) {
      PUT("\n", 1);
      padding = 0;
    }
  }

  return outpos;
}

int vterm_screen_is_eol(const VTermScreen *screen, VTermPos pos)
{
  // This cell is EOL if this and every cell to the right is black
  for (; pos.col < screen->cols; pos.col++) {
    ScreenCell *cell = getcell(screen, pos.row, pos.col);
    if (cell->schar != 0) {
      return 0;
    }
  }

  return 1;
}

void vterm_state_get_cursorpos(const VTermState *state, VTermPos *cursorpos)
{
  *cursorpos = state->pos;
}

void vterm_state_set_bold_highbright(VTermState *state, int bold_is_highbright)
{
  state->bold_is_highbright = bold_is_highbright;
}

/// Compares two colours. Returns true if the colors are equal, false otherwise.
int vterm_color_is_equal(const VTermColor *a, const VTermColor *b)
{
  // First make sure that the two colours are of the same type (RGB/Indexed)
  if (a->type != b->type) {
    return false;
  }

  // Depending on the type inspect the corresponding members
  if (VTERM_COLOR_IS_INDEXED(a)) {
    return a->indexed.idx == b->indexed.idx;
  } else if (VTERM_COLOR_IS_RGB(a)) {
    return (a->rgb.red == b->rgb.red)
           && (a->rgb.green == b->rgb.green)
           && (a->rgb.blue == b->rgb.blue);
  }

  return 0;
}
