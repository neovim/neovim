#include "vterm_test.h"

#include <stdio.h>

int parser_text(const char bytes[], size_t len, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "text ");
  size_t i;
  for(i = 0; i < len; i++) {
    unsigned char b = (unsigned char)bytes[i];
    if(b < 0x20 || b == 0x7f || (b >= 0x80 && b < 0xa0)) {
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
  while(len--) {
    fprintf(f, "%c", (s++)[0]);
  }
}

int parser_csi(const char *leader, const long args[], int argcount, const char *intermed, char command, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "csi %02x", command);

  if(leader && leader[0]) {
    fprintf(f, " L=");
    for(int i = 0; leader[i]; i++) {
      fprintf(f, "%02x", leader[i]);
    }
  }

  for(int i = 0; i < argcount; i++) {
    char sep = i ? ',' : ' ';

    if(args[i] == CSI_ARG_MISSING) {
      fprintf(f, "%c*", sep);
    } else {
      fprintf(f, "%c%ld%s", sep, CSI_ARG(args[i]), CSI_ARG_HAS_MORE(args[i]) ? "+" : "");
    }
  }

  if(intermed && intermed[0]) {
    fprintf(f, " I=");
    for(int i = 0; intermed[i]; i++) {
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

  if(frag.initial) {
    if(command == -1) {
      fprintf(f, "[");
    } else {
      fprintf(f, "[%d;", command);
    }
  }

  printchars(frag.str, frag.len, f);

  if(frag.final) {
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

  if(frag.initial) {
    fprintf(f, "[");
    for(size_t i = 0; i < commandlen; i++) {
      fprintf(f, "%c", command[i]);
    }
  }

  printchars(frag.str, frag.len,f);

  if(frag.final) {
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

  if(frag.initial) {
    fprintf(f, "[");
  }

  printchars(frag.str, frag.len, f);

  if(frag.final) {
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

  if(frag.initial) {
    fprintf(f, "[");
  }

  printchars(frag.str, frag.len,f);

  if(frag.final) {
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

  if(frag.initial) {
    fprintf(f, "[");
  }

  printchars(frag.str, frag.len,f);

  if(frag.final) {
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
  if(frag.initial) {
    fprintf(f, "[");
}
  printchars(frag.str, frag.len, f);
  if(frag.final) {
    fprintf(f, "]");
}
  fprintf(f,"\n");

  fclose(f);
  return 1;
}

int selection_query(VTermSelectionMask mask, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f,"selection-query mask=%04X\n", mask);

  fclose(f);
  return 1;
}

bool want_state_putglyph;
int state_putglyph(VTermGlyphInfo *info, VTermPos pos, void *user)
{
  if(!want_state_putglyph) {
    return 1;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "putglyph ");
  for(int i = 0; i < VTERM_MAX_CHARS_PER_CELL && info->chars[i]; i++) {
    fprintf(f, i ? ",%x" : "%x", info->chars[i]);
  }
  fprintf(f, " %d %d,%d", info->width, pos.row, pos.col);
  if(info->protected_cell) {
    fprintf(f, " prot");
  }
  if(info->dwl) {
    fprintf(f, " dwl");
  }
  if(info->dhl) {
    fprintf(f, " dhl-%s", info->dhl == 1 ? "top" : info->dhl == 2 ? "bottom" : "?" );
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

  if(want_state_movecursor) {
    fprintf(f,"movecursor %d,%d\n", pos.row, pos.col);
  }

  fclose(f);
  return 1;
}

bool want_state_scrollrect;
int state_scrollrect(VTermRect rect, int downward, int rightward, void *user)
{
  if(!want_state_scrollrect) {
    return 0;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");

  fprintf(f,"scrollrect %d..%d,%d..%d => %+d,%+d\n",
      rect.start_row, rect.end_row, rect.start_col, rect.end_col,
      downward, rightward);

  fclose(f);
  return 1;
}

bool want_state_moverect;
int state_moverect(VTermRect dest, VTermRect src, void *user)
{
  if(!want_state_moverect) {
    return 0;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f,"moverect %d..%d,%d..%d -> %d..%d,%d..%d\n",
      src.start_row,  src.end_row,  src.start_col,  src.end_col,
      dest.start_row, dest.end_row, dest.start_col, dest.end_col);

  fclose(f);
  return 1;
}

void print_color(const VTermColor *col)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  if (VTERM_COLOR_IS_RGB(col)) {
    fprintf(f,"rgb(%d,%d,%d", col->rgb.red, col->rgb.green, col->rgb.blue);
  }
  else if (VTERM_COLOR_IS_INDEXED(col)) {
    fprintf(f,"idx(%d", col->indexed.idx);
  }
  else {
    fprintf(f,"invalid(%d", col->type);
  }
  if (VTERM_COLOR_IS_DEFAULT_FG(col)) {
    fprintf(f,",is_default_fg");
  }
  if (VTERM_COLOR_IS_DEFAULT_BG(col)) {
    fprintf(f,",is_default_bg");
  }
  fprintf(f,")");
  fclose(f);
}

bool want_state_settermprop;
int state_settermprop(VTermProp prop, VTermValue *val, void *user)
{
  if(!want_state_settermprop) {
    return 1;
  }

  int errcode = 0;
  FILE *f = fopen(VTERM_TEST_FILE, "a");

  VTermValueType type = vterm_get_prop_type(prop);
  switch(type) {
    case VTERM_VALUETYPE_BOOL:
      fprintf(f,"settermprop %d %s\n", prop, val->boolean ? "true" : "false");
      errcode = 1;
      goto end;
    case VTERM_VALUETYPE_INT:
      fprintf(f,"settermprop %d %d\n", prop, val->number);
      errcode = 1;
      goto end;
    case VTERM_VALUETYPE_STRING:
      fprintf(f,"settermprop %d %s\"%.*s\"%s\n", prop,
          val->string.initial ? "[" : "", (int)val->string.len, val->string.str, val->string.final ? "]" : "");
      errcode=0;
      goto end;
    case VTERM_VALUETYPE_COLOR:
      fprintf(f,"settermprop %d ", prop);
      print_color(&val->color);
      fprintf(f,"\n");
      errcode=1;
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
  if(!want_state_erase) {
    return 1;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");

  fprintf(f,"erase %d..%d,%d..%d%s\n",
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
  switch(attr) {
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
int state_sb_clear(void *user) {
  if(!want_state_scrollback) {
    return 1;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f,"sb_clear\n");
  fclose(f);

  return 0;
}

bool want_screen_scrollback;
int screen_sb_pushline(int cols, const VTermScreenCell *cells, void *user)
{
  if(!want_screen_scrollback) {
    return 1;
  }

  int eol = cols;
  while(eol && !cells[eol-1].chars[0]) {
    eol--;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "sb_pushline %d =", cols);
  for(int c = 0; c < eol; c++) {
    fprintf(f, " %02X", cells[c].chars[0]);
  }
  fprintf(f, "\n");

  fclose(f);

  return 1;
}

int screen_sb_popline(int cols, VTermScreenCell *cells, void *user)
{
  if(!want_screen_scrollback) {
    return 0;
  }

  // All lines of scrollback contain "ABCDE"
  for(int col = 0; col < cols; col++) {
    if(col < 5) {
      cells[col].chars[0] = (uint32_t)('A' + col);
    } else {
      cells[col].chars[0] = 0;
    }

    cells[col].width = 1;
  }

  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f,"sb_popline %d\n", cols);
  fclose(f);
  return 1;
}

int screen_sb_clear(void *user)
{
  if(!want_screen_scrollback) {
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
  for(size_t i = 0; i < len; i++) {
    fprintf(f, "%x%s", (unsigned char)s[i], i < len-1 ? "," : "\n");
  }
  fclose(f);
}
