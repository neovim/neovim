#include "vterm_internal.h"

#include "auto/config.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*****************
 * API functions *
 *****************/

static void *default_malloc(size_t size, void *allocdata)
{
  void *ptr = malloc(size);
  if(ptr)
    memset(ptr, 0, size);
  return ptr;
}

static void default_free(void *ptr, void *allocdata)
{
  free(ptr);
}

static VTermAllocatorFunctions default_allocator = {
  .malloc = &default_malloc,
  .free   = &default_free,
};

VTerm *vterm_new(int rows, int cols)
{
  return vterm_build(&(const struct VTermBuilder){
      .rows = rows,
      .cols = cols,
    });
}

VTerm *vterm_new_with_allocator(int rows, int cols, VTermAllocatorFunctions *funcs, void *allocdata)
{
  return vterm_build(&(const struct VTermBuilder){
      .rows = rows,
      .cols = cols,
      .allocator = funcs,
      .allocdata = allocdata,
    });
}

/* A handy macro for defaulting values out of builder fields */
#define DEFAULT(v, def)  ((v) ? (v) : (def))

VTerm *vterm_build(const struct VTermBuilder *builder)
{
  const VTermAllocatorFunctions *allocator = DEFAULT(builder->allocator, &default_allocator);

  /* Need to bootstrap using the allocator function directly */
  VTerm *vt = (*allocator->malloc)(sizeof(VTerm), builder->allocdata);

  vt->allocator = allocator;
  vt->allocdata = builder->allocdata;

  vt->rows = builder->rows;
  vt->cols = builder->cols;

  vt->parser.state = NORMAL;

  vt->parser.callbacks = NULL;
  vt->parser.cbdata    = NULL;

  vt->parser.emit_nul  = false;

  vt->outfunc = NULL;
  vt->outdata = NULL;

  vt->outbuffer_len = DEFAULT(builder->outbuffer_len, 4096);
  vt->outbuffer_cur = 0;
  vt->outbuffer = vterm_allocator_malloc(vt, vt->outbuffer_len);

  vt->tmpbuffer_len = DEFAULT(builder->tmpbuffer_len, 4096);
  vt->tmpbuffer = vterm_allocator_malloc(vt, vt->tmpbuffer_len);

  return vt;
}

void vterm_free(VTerm *vt)
{
  if(vt->screen)
    vterm_screen_free(vt->screen);

  if(vt->state)
    vterm_state_free(vt->state);

  vterm_allocator_free(vt, vt->outbuffer);
  vterm_allocator_free(vt, vt->tmpbuffer);

  vterm_allocator_free(vt, vt);
}

INTERNAL void *vterm_allocator_malloc(VTerm *vt, size_t size)
{
  return (*vt->allocator->malloc)(size, vt->allocdata);
}

INTERNAL void vterm_allocator_free(VTerm *vt, void *ptr)
{
  (*vt->allocator->free)(ptr, vt->allocdata);
}

void vterm_get_size(const VTerm *vt, int *rowsp, int *colsp)
{
  if(rowsp)
    *rowsp = vt->rows;
  if(colsp)
    *colsp = vt->cols;
}

void vterm_set_size(VTerm *vt, int rows, int cols)
{
  if(rows < 1 || cols < 1)
    return;

  vt->rows = rows;
  vt->cols = cols;

  if(vt->parser.callbacks && vt->parser.callbacks->resize)
    (*vt->parser.callbacks->resize)(rows, cols, vt->parser.cbdata);
}

int vterm_get_utf8(const VTerm *vt)
{
  return vt->mode.utf8;
}

void vterm_set_utf8(VTerm *vt, int is_utf8)
{
  vt->mode.utf8 = is_utf8;
}

void vterm_output_set_callback(VTerm *vt, VTermOutputCallback *func, void *user)
{
  vt->outfunc = func;
  vt->outdata = user;
}

INTERNAL void vterm_push_output_bytes(VTerm *vt, const char *bytes, size_t len)
{
  if(vt->outfunc) {
    (vt->outfunc)(bytes, len, vt->outdata);
    return;
  }

  if(len > vt->outbuffer_len - vt->outbuffer_cur)
    return;

  memcpy(vt->outbuffer + vt->outbuffer_cur, bytes, len);
  vt->outbuffer_cur += len;
}

INTERNAL void vterm_push_output_vsprintf(VTerm *vt, const char *format, va_list args)
{
  size_t len = vsnprintf(vt->tmpbuffer, vt->tmpbuffer_len,
      format, args);

  vterm_push_output_bytes(vt, vt->tmpbuffer, len);
}

INTERNAL void vterm_push_output_sprintf(VTerm *vt, const char *format, ...)
{
  va_list args;
  va_start(args, format);
  vterm_push_output_vsprintf(vt, format, args);
  va_end(args);
}

INTERNAL void vterm_push_output_sprintf_ctrl(VTerm *vt, unsigned char ctrl, const char *fmt, ...)
{
  size_t cur;

  if(ctrl >= 0x80 && !vt->mode.ctrl8bit)
    cur = snprintf(vt->tmpbuffer, vt->tmpbuffer_len,
        ESC_S "%c", ctrl - 0x40);
  else
    cur = snprintf(vt->tmpbuffer, vt->tmpbuffer_len,
        "%c", ctrl);

  if(cur >= vt->tmpbuffer_len)
    return;

  va_list args;
  va_start(args, fmt);
  cur += vsnprintf(vt->tmpbuffer + cur, vt->tmpbuffer_len - cur,
      fmt, args);
  va_end(args);

  if(cur >= vt->tmpbuffer_len)
    return;

  vterm_push_output_bytes(vt, vt->tmpbuffer, cur);
}

INTERNAL void vterm_push_output_sprintf_str(VTerm *vt, unsigned char ctrl, bool term, const char *fmt, ...)
{
  size_t cur = 0;

  if(ctrl) {
    if(ctrl >= 0x80 && !vt->mode.ctrl8bit)
      cur = snprintf(vt->tmpbuffer, vt->tmpbuffer_len,
          ESC_S "%c", ctrl - 0x40);
    else
      cur = snprintf(vt->tmpbuffer, vt->tmpbuffer_len,
          "%c", ctrl);

    if(cur >= vt->tmpbuffer_len)
      return;
  }

  va_list args;
  va_start(args, fmt);
  cur += vsnprintf(vt->tmpbuffer + cur, vt->tmpbuffer_len - cur,
      fmt, args);
  va_end(args);

  if(cur >= vt->tmpbuffer_len)
    return;

  if(term) {
    cur += snprintf(vt->tmpbuffer + cur, vt->tmpbuffer_len - cur,
        vt->mode.ctrl8bit ? "\x9C" : ESC_S "\\"); // ST

    if(cur >= vt->tmpbuffer_len)
      return;
  }

  vterm_push_output_bytes(vt, vt->tmpbuffer, cur);
}

size_t vterm_output_get_buffer_size(const VTerm *vt)
{
  return vt->outbuffer_len;
}

size_t vterm_output_get_buffer_current(const VTerm *vt)
{
  return vt->outbuffer_cur;
}

size_t vterm_output_get_buffer_remaining(const VTerm *vt)
{
  return vt->outbuffer_len - vt->outbuffer_cur;
}

size_t vterm_output_read(VTerm *vt, char *buffer, size_t len)
{
  if(len > vt->outbuffer_cur)
    len = vt->outbuffer_cur;

  memcpy(buffer, vt->outbuffer, len);

  if(len < vt->outbuffer_cur)
    memmove(vt->outbuffer, vt->outbuffer + len, vt->outbuffer_cur - len);

  vt->outbuffer_cur -= len;

  return len;
}

VTermValueType vterm_get_attr_type(VTermAttr attr)
{
  switch(attr) {
    case VTERM_ATTR_BOLD:       return VTERM_VALUETYPE_BOOL;
    case VTERM_ATTR_UNDERLINE:  return VTERM_VALUETYPE_INT;
    case VTERM_ATTR_ITALIC:     return VTERM_VALUETYPE_BOOL;
    case VTERM_ATTR_BLINK:      return VTERM_VALUETYPE_BOOL;
    case VTERM_ATTR_REVERSE:    return VTERM_VALUETYPE_BOOL;
    case VTERM_ATTR_CONCEAL:    return VTERM_VALUETYPE_BOOL;
    case VTERM_ATTR_STRIKE:     return VTERM_VALUETYPE_BOOL;
    case VTERM_ATTR_FONT:       return VTERM_VALUETYPE_INT;
    case VTERM_ATTR_FOREGROUND: return VTERM_VALUETYPE_COLOR;
    case VTERM_ATTR_BACKGROUND: return VTERM_VALUETYPE_COLOR;
    case VTERM_ATTR_SMALL:      return VTERM_VALUETYPE_BOOL;
    case VTERM_ATTR_BASELINE:   return VTERM_VALUETYPE_INT;
    case VTERM_ATTR_URI:        return VTERM_VALUETYPE_INT;

    case VTERM_N_ATTRS: return 0;
  }
  return 0; /* UNREACHABLE */
}

VTermValueType vterm_get_prop_type(VTermProp prop)
{
  switch(prop) {
    case VTERM_PROP_CURSORVISIBLE: return VTERM_VALUETYPE_BOOL;
    case VTERM_PROP_CURSORBLINK:   return VTERM_VALUETYPE_BOOL;
    case VTERM_PROP_ALTSCREEN:     return VTERM_VALUETYPE_BOOL;
    case VTERM_PROP_TITLE:         return VTERM_VALUETYPE_STRING;
    case VTERM_PROP_ICONNAME:      return VTERM_VALUETYPE_STRING;
    case VTERM_PROP_REVERSE:       return VTERM_VALUETYPE_BOOL;
    case VTERM_PROP_CURSORSHAPE:   return VTERM_VALUETYPE_INT;
    case VTERM_PROP_MOUSE:         return VTERM_VALUETYPE_INT;
    case VTERM_PROP_FOCUSREPORT:   return VTERM_VALUETYPE_BOOL;

    case VTERM_N_PROPS: return 0;
  }
  return 0; /* UNREACHABLE */
}

void vterm_scroll_rect(VTermRect rect,
    int downward,
    int rightward,
    int (*moverect)(VTermRect src, VTermRect dest, void *user),
    int (*eraserect)(VTermRect rect, int selective, void *user),
    void *user)
{
  VTermRect src;
  VTermRect dest;

  if(abs(downward)  >= rect.end_row - rect.start_row ||
     abs(rightward) >= rect.end_col - rect.start_col) {
    /* Scroll more than area; just erase the lot */
    (*eraserect)(rect, 0, user);
    return;
  }

  if(rightward >= 0) {
    /* rect: [XXX................]
     * src:     [----------------]
     * dest: [----------------]
     */
    dest.start_col = rect.start_col;
    dest.end_col   = rect.end_col   - rightward;
    src.start_col  = rect.start_col + rightward;
    src.end_col    = rect.end_col;
  }
  else {
    /* rect: [................XXX]
     * src:  [----------------]
     * dest:    [----------------]
     */
    int leftward = -rightward;
    dest.start_col = rect.start_col + leftward;
    dest.end_col   = rect.end_col;
    src.start_col  = rect.start_col;
    src.end_col    = rect.end_col - leftward;
  }

  if(downward >= 0) {
    dest.start_row = rect.start_row;
    dest.end_row   = rect.end_row   - downward;
    src.start_row  = rect.start_row + downward;
    src.end_row    = rect.end_row;
  }
  else {
    int upward = -downward;
    dest.start_row = rect.start_row + upward;
    dest.end_row   = rect.end_row;
    src.start_row  = rect.start_row;
    src.end_row    = rect.end_row - upward;
  }

  if(moverect)
    (*moverect)(dest, src, user);

  if(downward > 0)
    rect.start_row = rect.end_row - downward;
  else if(downward < 0)
    rect.end_row = rect.start_row - downward;

  if(rightward > 0)
    rect.start_col = rect.end_col - rightward;
  else if(rightward < 0)
    rect.end_col = rect.start_col - rightward;

  (*eraserect)(rect, 0, user);
}

void vterm_copy_cells(VTermRect dest,
    VTermRect src,
    void (*copycell)(VTermPos dest, VTermPos src, void *user),
    void *user)
{
  int downward  = src.start_row - dest.start_row;
  int rightward = src.start_col - dest.start_col;

  int init_row, test_row, init_col, test_col;
  int inc_row, inc_col;

  if(downward < 0) {
    init_row = dest.end_row - 1;
    test_row = dest.start_row - 1;
    inc_row = -1;
  }
  else /* downward >= 0 */ {
    init_row = dest.start_row;
    test_row = dest.end_row;
    inc_row = +1;
  }

  if(rightward < 0) {
    init_col = dest.end_col - 1;
    test_col = dest.start_col - 1;
    inc_col = -1;
  }
  else /* rightward >= 0 */ {
    init_col = dest.start_col;
    test_col = dest.end_col;
    inc_col = +1;
  }

  VTermPos pos;
  for(pos.row = init_row; pos.row != test_row; pos.row += inc_row)
    for(pos.col = init_col; pos.col != test_col; pos.col += inc_col) {
      VTermPos srcpos = { pos.row + downward, pos.col + rightward };
      (*copycell)(pos, srcpos, user);
    }
}

void vterm_check_version(int major, int minor)
{
  if(major != VTERM_VERSION_MAJOR) {
    fprintf(stderr, "libvterm major version mismatch; %d (wants) != %d (library)\n",
        major, VTERM_VERSION_MAJOR);
    exit(1);
  }

  if(minor > VTERM_VERSION_MINOR) {
    fprintf(stderr, "libvterm minor version mismatch; %d (wants) > %d (library)\n",
        minor, VTERM_VERSION_MINOR);
    exit(1);
  }

  // Happy
}

// For unit tests.
#ifndef NDEBUG

int parser_text(const char bytes[], size_t len, void *user)
{
  FILE *f = fopen(VTERM_TEST_FILE, "a");
  fprintf(f, "text ");
  int i;
  for(i = 0; i < len; i++) {
    unsigned char b = bytes[i];
    if(b < 0x20 || b == 0x7f || (b >= 0x80 && b < 0xa0)) {
      break;
    }
    fprintf(f, i ? ",%x" : "%x", b);
  }
  fprintf(f, "\n");
  fclose(f);

  return i;
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
    for(int i = 0; i < commandlen; i++) {
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
      cells[col].chars[0] = 'A' + col;
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
  for(int i = 0; i < len; i++) {
    fprintf(f, "%x%s", (unsigned char)s[i], i < len-1 ? "," : "\n");
  }
  fclose(f);
}

#endif
