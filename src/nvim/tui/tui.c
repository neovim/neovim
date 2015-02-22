#include <assert.h>
#include <stdbool.h>
#include <stdio.h>

#include <uv.h>
#include <unibilium.h>

#include "nvim/lib/kvec.h"

#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/map.h"
#include "nvim/memory.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/helpers.h"
#include "nvim/os/event.h"
#include "nvim/tui/tui.h"

typedef struct term_input TermInput;

#include "term_input.inl"

typedef struct {
  int top, bot, left, right;
} Rect;

typedef struct {
  char data[7];
  HlAttrs attrs;
} Cell;

typedef struct {
  unibi_var_t params[9];
  char buf[0xffff];
  size_t bufpos;
  TermInput *input;
  uv_loop_t *write_loop;
  unibi_term *ut;
  uv_tty_t output_handle;
  uv_signal_t winch_handle;
  Rect scroll_region;
  kvec_t(Rect) invalid_regions;
  int row, col;
  int bg, fg;
  int out_fd;
  int old_height;
  bool can_use_terminal_scroll;
  HlAttrs attrs, print_attrs;
  Cell **screen;
  struct {
    int enable_mouse, disable_mouse;
    int enable_bracketed_paste, disable_bracketed_paste;
    int enter_insert_mode, exit_insert_mode;
  } unibi_ext;
} TUIData;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/tui.c.generated.h"
#endif

#define EMPTY_ATTRS ((HlAttrs){false, false, false, false, false, -1, -1})

#define FOREACH_CELL(ui, top, bot, left, right, go, code)               \
  do {                                                                  \
    TUIData *data = ui->data;                                           \
    for (int row = top; row <= bot; ++row) {                            \
      Cell *cells = data->screen[row];                                  \
      if (go) {                                                         \
        unibi_goto(ui, row, left);                                      \
      }                                                                 \
      for (int col = left; col <= right; ++col) {                       \
        Cell *cell = cells + col;                                       \
        (void)(cell);                                                   \
        code;                                                           \
      }                                                                 \
    }                                                                   \
  } while (0)


void tui_start(void)
{
  TUIData *data = xcalloc(1, sizeof(TUIData));
  UI *ui = xcalloc(1, sizeof(UI));
  ui->data = data;
  data->attrs = data->print_attrs = EMPTY_ATTRS;
  data->fg = data->bg = -1;
  data->can_use_terminal_scroll = true;
  data->bufpos = 0;
  data->unibi_ext.enable_mouse = -1;
  data->unibi_ext.disable_mouse = -1;
  data->unibi_ext.enable_bracketed_paste = -1;
  data->unibi_ext.disable_bracketed_paste = -1;
  data->unibi_ext.enter_insert_mode = -1;
  data->unibi_ext.exit_insert_mode = -1;

  // write output to stderr if stdout is not a tty
  data->out_fd = os_isatty(1) ? 1 : (os_isatty(2) ? 2 : 1);
  kv_init(data->invalid_regions);
  // setup term input
  data->input = term_input_new();
  // setup unibilium
  data->ut = unibi_from_env();
  if (!data->ut) {
    // For some reason could not read terminfo file, use a dummy entry that
    // will be populated with common values by fix_terminfo below
    data->ut = unibi_dummy();
  }
  fix_terminfo(data);
  // Enter alternate screen and clear
  unibi_out(ui, unibi_enter_ca_mode);
  unibi_out(ui, unibi_clear_screen);
  // Enable bracketed paste
  unibi_out(ui, (int)data->unibi_ext.enable_bracketed_paste);

  // setup output handle in a separate event loop(we wanna do synchronous
  // write to the tty)
  data->write_loop = xmalloc(sizeof(uv_loop_t));
  uv_loop_init(data->write_loop);
  uv_tty_init(data->write_loop, &data->output_handle, data->out_fd, 0);
  uv_tty_set_mode(&data->output_handle, UV_TTY_MODE_RAW);

  // Obtain screen dimensions
  update_size(ui);

  // listen for SIGWINCH
  uv_signal_init(uv_default_loop(), &data->winch_handle);
  uv_signal_start(&data->winch_handle, sigwinch_cb, SIGWINCH);
  data->winch_handle.data = ui;

  ui->stop = tui_stop;
  ui->rgb = false;
  ui->data = data;
  ui->resize = tui_resize;
  ui->clear = tui_clear;
  ui->eol_clear = tui_eol_clear;
  ui->cursor_goto = tui_cursor_goto;
  ui->cursor_on = tui_cursor_on;
  ui->cursor_off = tui_cursor_off;
  ui->mouse_on = tui_mouse_on;
  ui->mouse_off = tui_mouse_off;
  ui->insert_mode = tui_insert_mode;
  ui->normal_mode = tui_normal_mode;
  ui->set_scroll_region = tui_set_scroll_region;
  ui->scroll = tui_scroll;
  ui->highlight_set = tui_highlight_set;
  ui->put = tui_put;
  ui->bell = tui_bell;
  ui->visual_bell = tui_visual_bell;
  ui->update_fg = tui_update_fg;
  ui->update_bg = tui_update_bg;
  ui->flush = tui_flush;
  ui->suspend = tui_suspend;
  ui->set_title = tui_set_title;
  ui->set_icon = tui_set_icon;
  // Attach
  ui_attach(ui);
}

static void tui_stop(UI *ui)
{
  TUIData *data = ui->data;
  // Destroy common stuff
  kv_destroy(data->invalid_regions);
  uv_signal_stop(&data->winch_handle);
  uv_close((uv_handle_t *)&data->winch_handle, NULL);
  // Destroy input stuff
  term_input_destroy(data->input);
  // Destroy output stuff
  tui_normal_mode(ui);
  tui_mouse_off(ui);
  unibi_out(ui, unibi_exit_attribute_mode);
  unibi_out(ui, unibi_cursor_normal);
  unibi_out(ui, unibi_exit_ca_mode);
  // Disable bracketed paste
  unibi_out(ui, (int)data->unibi_ext.disable_bracketed_paste);
  flush_buf(ui);
  uv_tty_reset_mode();
  uv_close((uv_handle_t *)&data->output_handle, NULL);
  uv_run(data->write_loop, UV_RUN_DEFAULT);
  if (uv_loop_close(data->write_loop)) {
    abort();
  }
  free(data->write_loop);
  unibi_destroy(data->ut);
  destroy_screen(data);
  free(data);
  ui_detach(ui);
  free(ui);
}

static void try_resize(Event ev)
{
  UI *ui = ev.data;
  update_size(ui);
  ui_refresh();
}

static void sigwinch_cb(uv_signal_t *handle, int signum)
{
  // Queue the event because resizing can result in recursive event_poll calls
  event_push((Event) {
    .data = handle->data,
    .handler = try_resize
  }, false);
}

static bool attrs_differ(HlAttrs a1, HlAttrs a2)
{
  return a1.foreground != a2.foreground || a1.background != a2.background
    || a1.bold != a2.bold || a1.italic != a2.italic
    || a1.undercurl != a2.undercurl || a1.underline != a2.underline
    || a1.reverse != a2.reverse;
}

static void update_attrs(UI *ui, HlAttrs attrs)
{
  TUIData *data = ui->data;

  if (!attrs_differ(attrs, data->print_attrs)) {
    return;
  }

  data->print_attrs = attrs;
  unibi_out(ui, unibi_exit_attribute_mode);

  data->params[0].i = attrs.foreground != -1 ? attrs.foreground : data->fg;
  if (data->params[0].i != -1) {
    unibi_out(ui, unibi_set_a_foreground);
  }

  data->params[0].i = attrs.background != -1 ? attrs.background : data->bg;
  if (data->params[0].i != -1) {
    unibi_out(ui, unibi_set_a_background);
  }

  if (attrs.bold) {
    unibi_out(ui, unibi_enter_bold_mode);
  }
  if (attrs.italic) {
    unibi_out(ui, unibi_enter_italics_mode);
  }
  if (attrs.underline) {
    unibi_out(ui, unibi_enter_underline_mode);
  }
  if (attrs.reverse) {
    unibi_out(ui, unibi_enter_reverse_mode);
  }
}

static void print_cell(UI *ui, Cell *ptr)
{
  update_attrs(ui, ptr->attrs);
  out(ui, ptr->data, strlen(ptr->data));
}

static void clear_region(UI *ui, int top, int bot, int left, int right,
    bool refresh)
{
  TUIData *data = ui->data;
  HlAttrs clear_attrs = EMPTY_ATTRS;
  clear_attrs.foreground = data->fg;
  clear_attrs.background = data->bg;
  update_attrs(ui, clear_attrs);

  bool cleared = false;
  if (refresh && data->bg == -1 && right == ui->width -1) {
    // Background is set to the default color and the right edge matches the
    // screen end, try to use terminal codes for clearing the requested area.
    if (left == 0) {
      if (bot == ui->height - 1) {
        if (top == 0) {
          unibi_out(ui, unibi_clear_screen);
        } else {
          unibi_goto(ui, top, 0);
          unibi_out(ui, unibi_clr_eos);
        }
        cleared = true;
      }
    }

    if (!cleared) {
      // iterate through each line and clear with clr_eol
      for (int row = top; row <= bot; ++row) {
        unibi_goto(ui, row, left);
        unibi_out(ui, unibi_clr_eol);
      }
      cleared = true;
    }
  }

  bool clear = refresh && !cleared;
  FOREACH_CELL(ui, top, bot, left, right, clear, {
    cell->data[0] = ' ';
    cell->data[1] = 0;
    cell->attrs = clear_attrs;
    if (clear) {
      print_cell(ui, cell);
    }
  });

  // restore cursor
  unibi_goto(ui, data->row, data->col);
}

static void tui_resize(UI *ui, int width, int height)
{
  TUIData *data = ui->data;
  destroy_screen(data);

  data->screen = xmalloc((size_t)height * sizeof(Cell *));
  for (int i = 0; i < height; i++) {
    data->screen[i] = xcalloc((size_t)width, sizeof(Cell));
  }

  data->old_height = height;
  data->scroll_region.top = 0;
  data->scroll_region.bot = height - 1;
  data->scroll_region.left = 0;
  data->scroll_region.right = width - 1;
  data->row = data->col = 0;
}

static void tui_clear(UI *ui)
{
  TUIData *data = ui->data;
  clear_region(ui, data->scroll_region.top, data->scroll_region.bot,
      data->scroll_region.left, data->scroll_region.right, true);
}

static void tui_eol_clear(UI *ui)
{
  TUIData *data = ui->data;
  clear_region(ui, data->row, data->row, data->col,
      data->scroll_region.right, true);
}

static void tui_cursor_goto(UI *ui, int row, int col)
{
  TUIData *data = ui->data;
  data->row = row;
  data->col = col;
  unibi_goto(ui, row, col);
}

static void tui_cursor_on(UI *ui)
{
  unibi_out(ui, unibi_cursor_normal);
}

static void tui_cursor_off(UI *ui)
{
  unibi_out(ui, unibi_cursor_invisible);
}

static void tui_mouse_on(UI *ui)
{
  TUIData *data = ui->data;
  unibi_out(ui, (int)data->unibi_ext.enable_mouse);
}

static void tui_mouse_off(UI *ui)
{
  TUIData *data = ui->data;
  unibi_out(ui, (int)data->unibi_ext.disable_mouse);
}

static void tui_insert_mode(UI *ui)
{
  TUIData *data = ui->data;
  unibi_out(ui, (int)data->unibi_ext.enter_insert_mode);
}

static void tui_normal_mode(UI *ui)
{
  TUIData *data = ui->data;
  unibi_out(ui, (int)data->unibi_ext.exit_insert_mode);
}

static void tui_set_scroll_region(UI *ui, int top, int bot, int left,
    int right)
{
  TUIData *data = ui->data;
  data->scroll_region.top = top;
  data->scroll_region.bot = bot;
  data->scroll_region.left = left;
  data->scroll_region.right = right;

  data->can_use_terminal_scroll =
    left == 0 && right == ui->width - 1
    && ((top == 0 && bot == ui->height - 1)
        || unibi_get_str(data->ut, unibi_change_scroll_region));
}

static void tui_scroll(UI *ui, int count)
{
  TUIData *data = ui->data;
  int top = data->scroll_region.top;
  int bot = data->scroll_region.bot;
  int left = data->scroll_region.left;
  int right = data->scroll_region.right;

  if (data->can_use_terminal_scroll) {
    // Change terminal scroll region and move cursor to the top
    data->params[0].i = top;
    data->params[1].i = bot;
    unibi_out(ui, unibi_change_scroll_region);
    unibi_goto(ui, top, left);
    // also set default color attributes or some terminals can become funny
    HlAttrs clear_attrs = EMPTY_ATTRS;
    clear_attrs.foreground = data->fg;
    clear_attrs.background = data->bg;
    update_attrs(ui, clear_attrs);
  }

  // Compute start/stop/step for the loop below, also use terminal scroll
  // if possible
  int start, stop, step;
  if (count > 0) {
    start = top;
    stop = bot - count + 1;
    step = 1;
    if (data->can_use_terminal_scroll) {
      if (count == 1) {
        unibi_out(ui, unibi_delete_line);
      } else {
        data->params[0].i = count;
        unibi_out(ui, unibi_parm_delete_line);
      }
    }

  } else {
    start = bot;
    stop = top - count - 1;
    step = -1;
    if (data->can_use_terminal_scroll) {
      if (count == -1) {
        unibi_out(ui, unibi_insert_line);
      } else {
        data->params[0].i = -count;
        unibi_out(ui, unibi_parm_insert_line);
      }
    }
  }

  if (data->can_use_terminal_scroll) {
    // Restore terminal scroll region and cursor
    data->params[0].i = 0;
    data->params[1].i = ui->height - 1;
    unibi_out(ui, unibi_change_scroll_region);
    unibi_goto(ui, data->row, data->col);
  }

  int i;
  // Scroll internal screen
  for (i = start; i != stop; i += step) {
    Cell *target_row = data->screen[i] + left;
    Cell *source_row = data->screen[i + count] + left;
    memcpy(target_row, source_row, sizeof(Cell) * (size_t)(right - left + 1));
  }

  // clear emptied region, updating the terminal if its builtin scrolling
  // facility was used. This is done when the background color is not the
  // default, since scrolling may leave wrong background in the cleared area.
  bool update_clear = data->bg != -1 && data->can_use_terminal_scroll;
  if (count > 0) {
    clear_region(ui, stop, stop + count - 1, left, right, update_clear);
  } else {
    clear_region(ui, stop + count + 1, stop, left, right, update_clear);
  }

  if (!data->can_use_terminal_scroll) {
    // Mark the entire scroll region as invalid for redrawing later
    invalidate(ui, data->scroll_region.top, data->scroll_region.bot,
        data->scroll_region.left, data->scroll_region.right);
  }
}

static void tui_highlight_set(UI *ui, HlAttrs attrs)
{
  ((TUIData *)ui->data)->attrs = attrs;
}

static void tui_put(UI *ui, uint8_t *text, size_t size)
{
  TUIData *data = ui->data;
  Cell *cell = data->screen[data->row] + data->col;
  cell->data[size] = 0;
  cell->attrs = data->attrs;

  if (text) {
    memcpy(cell->data, text, size);
  }

  print_cell(ui, cell);
  data->col += 1;
}

static void tui_bell(UI *ui)
{
  unibi_out(ui, unibi_bell);
}

static void tui_visual_bell(UI *ui)
{
  unibi_out(ui, unibi_flash_screen);
}

static void tui_update_fg(UI *ui, int fg)
{
  ((TUIData *)ui->data)->fg = fg;
}

static void tui_update_bg(UI *ui, int bg)
{
  ((TUIData *)ui->data)->bg = bg;
}

static void tui_flush(UI *ui)
{
  TUIData *data = ui->data;

  while (kv_size(data->invalid_regions)) {
    Rect r = kv_pop(data->invalid_regions);
    FOREACH_CELL(ui, r.top, r.bot, r.left, r.right, true, {
      print_cell(ui, cell);
    });
  }

  unibi_goto(ui, data->row, data->col);
  flush_buf(ui);
}

static void tui_suspend(UI *ui)
{
  tui_stop(ui);
  kill(0, SIGTSTP);
  tui_start();
}

static void tui_set_title(UI *ui, char *title)
{
  TUIData *data = ui->data;
  if (!(title && unibi_get_str(data->ut, unibi_to_status_line) &&
        unibi_get_str(data->ut, unibi_from_status_line))) {
    return;
  }
  unibi_out(ui, unibi_to_status_line);
  out(ui, title, strlen(title));
  unibi_out(ui, unibi_from_status_line);
}

static void tui_set_icon(UI *ui, char *icon)
{
}

static void invalidate(UI *ui, int top, int bot, int left, int right)
{
  TUIData *data = ui->data;
  Rect *intersects = NULL;
  // Increase dimensions before comparing to ensure adjacent regions are
  // treated as intersecting
  --top;
  ++bot;
  --left;
  ++right;

  for (size_t i = 0; i < kv_size(data->invalid_regions); i++) {
    Rect *r = &kv_A(data->invalid_regions, i);
    if (!(top > r->bot || bot < r->top
          || left > r->right || right < r->left)) {
      intersects = r;
      break;
    }
  }

  ++top;
  --bot;
  ++left;
  --right;

  if (intersects) {
    // If top/bot/left/right intersects with a invalid rect, we replace it
    // by the union
    intersects->top = MIN(top, intersects->top);
    intersects->bot = MAX(bot, intersects->bot);
    intersects->left = MIN(left, intersects->left);
    intersects->right = MAX(right, intersects->right);
  } else {
    // Else just add a new entry;
    kv_push(Rect, data->invalid_regions, ((Rect){top, bot, left, right}));
  }
}

static void update_size(UI *ui)
{
  TUIData *data = ui->data;
  int width = 0, height = 0;
  // 1 - try from a system call(ioctl/TIOCGWINSZ on unix)
  if (!uv_tty_get_winsize(&data->output_handle, &width, &height)) {
    goto end;
  }

  // 2 - use $LINES/$COLUMNS if available
  const char *val;
  int advance;
  if ((val = os_getenv("LINES"))
      && sscanf(val, "%d%n", &height, &advance) != EOF && advance
      && (val = os_getenv("COLUMNS"))
      && sscanf(val, "%d%n", &width, &advance) != EOF && advance) {
    goto end;
  }

  // 3- read from terminfo if available
  height = unibi_get_num(data->ut, unibi_lines);
  width = unibi_get_num(data->ut, unibi_columns);

end:
  if (width <= 0 || height <= 0) {
    // use a default of 80x24
    width = 80;
    height = 24;
  }

  ui->width = width;
  ui->height = height;
}

static void unibi_goto(UI *ui, int row, int col)
{
  TUIData *data = ui->data;
  data->params[0].i = row;
  data->params[1].i = col;
  unibi_out(ui, unibi_cursor_address);
}

static void unibi_out(UI *ui, int unibi_index)
{
  TUIData *data = ui->data;

  const char *str = NULL;

  if (unibi_index >= 0) {
    if (unibi_index < unibi_string_begin_) {
      str = unibi_get_ext_str(data->ut, (unsigned)unibi_index);
    } else {
      str = unibi_get_str(data->ut, (unsigned)unibi_index);
    }
  }

  if (str) {
    unibi_var_t vars[26 + 26] = {{0}};
    unibi_format(vars, vars + 26, str, data->params, out, ui, NULL, NULL);
  }
}

static void out(void *ctx, const char *str, size_t len)
{
  UI *ui = ctx;
  TUIData *data = ui->data;
  size_t available = sizeof(data->buf) - data->bufpos;

  if (len > available) {
    flush_buf(ui);
  }

  memcpy(data->buf + data->bufpos, str, len);
  data->bufpos += len;
}

static void unibi_set_if_empty(unibi_term *ut, enum unibi_string str,
    const char *val)
{
  if (!unibi_get_str(ut, str)) {
    unibi_set_str(ut, str, val);
  }
}

static void fix_terminfo(TUIData *data)
{
  unibi_term *ut = data->ut;

  const char *term = os_getenv("TERM");
  if (!term) {
    goto end;
  }

  bool inside_tmux = os_getenv("TMUX") != NULL;

#define STARTS_WITH(str, prefix) (!memcmp(str, prefix, sizeof(prefix) - 1))

  if (STARTS_WITH(term, "rxvt")) {
    unibi_set_if_empty(ut, unibi_exit_attribute_mode, "\x1b[m\x1b(B");
    unibi_set_if_empty(ut, unibi_flash_screen, "\x1b[?5h$<20/>\x1b[?5l");
    unibi_set_if_empty(ut, unibi_enter_italics_mode, "\x1b[3m");
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b]2");
  } else if (STARTS_WITH(term, "xterm")) {
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b]0;");
  } else if (STARTS_WITH(term, "screen")) {
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b_");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x1b\\");
  }

  if (STARTS_WITH(term, "xterm") || STARTS_WITH(term, "rxvt")) {
    unibi_set_if_empty(ut, unibi_cursor_normal, "\x1b[?12l\x1b[?25h");
    unibi_set_if_empty(ut, unibi_cursor_invisible, "\x1b[?25l");
    unibi_set_if_empty(ut, unibi_flash_screen, "\x1b[?5h$<100/>\x1b[?5l");
    unibi_set_if_empty(ut, unibi_exit_attribute_mode, "\x1b(B\x1b[m");
    unibi_set_if_empty(ut, unibi_change_scroll_region, "\x1b[%i%p1%d;%p2%dr");
    unibi_set_if_empty(ut, unibi_clear_screen, "\x1b[H\x1b[2J");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x07");
  }

  if (STARTS_WITH(term, "xterm") || STARTS_WITH(term, "rxvt") || inside_tmux) {
    data->unibi_ext.enable_bracketed_paste = (int)unibi_add_ext_str(ut, NULL,
        "\x1b[?2004h");
    data->unibi_ext.disable_bracketed_paste = (int)unibi_add_ext_str(ut, NULL,
        "\x1b[?2004l");
  }

#define XTERM_SETAF \
  "\x1b[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m"
#define XTERM_SETAB \
  "\x1b[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m"

  if (os_getenv("COLORTERM") != NULL
      && (!strcmp(term, "xterm") || !strcmp(term, "screen"))) {
    // probably every modern terminal that sets TERM=xterm supports 256
    // colors(eg: gnome-terminal). Also do it when TERM=screen.
    unibi_set_num(ut, unibi_max_colors, 256);
    unibi_set_str(ut, unibi_set_a_foreground, XTERM_SETAF);
    unibi_set_str(ut, unibi_set_a_background, XTERM_SETAB);
  }

  if (os_getenv("NVIM_TUI_ENABLE_CURSOR_SHAPE") == NULL) {
    goto end;
  }

#define TMUX_WRAP(seq) (inside_tmux ? "\x1bPtmux;\x1b" seq "\x1b\\" : seq)
  // Support changing cursor shape on some popular terminals.
  const char *term_prog = os_getenv("TERM_PROGRAM");

  if ((term_prog && !strcmp(term_prog, "iTerm.app"))
      || os_getenv("ITERM_SESSION_ID") != NULL) {
    // iterm
    data->unibi_ext.enter_insert_mode = (int)unibi_add_ext_str(ut, NULL,
        TMUX_WRAP("\x1b]50;CursorShape=1;BlinkingCursorEnabled=1\x07"));
    data->unibi_ext.exit_insert_mode = (int)unibi_add_ext_str(ut, NULL,
        TMUX_WRAP("\x1b]50;CursorShape=0;BlinkingCursorEnabled=0\x07"));
  } else {
    // xterm-like sequences for blinking bar and solid block
    data->unibi_ext.enter_insert_mode = (int)unibi_add_ext_str(ut, NULL,
        TMUX_WRAP("\x1b[5 q"));
    data->unibi_ext.exit_insert_mode = (int)unibi_add_ext_str(ut, NULL,
        TMUX_WRAP("\x1b[2 q"));
  }

end:
  // Fill some empty slots with common terminal strings
  data->unibi_ext.enable_mouse = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1002h\x1b[?1006h");
  data->unibi_ext.disable_mouse = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1002l\x1b[?1006l");
  unibi_set_if_empty(ut, unibi_cursor_address, "\x1b[%i%p1%d;%p2%dH");
  unibi_set_if_empty(ut, unibi_exit_attribute_mode, "\x1b[0;10m");
  unibi_set_if_empty(ut, unibi_set_a_foreground, XTERM_SETAF);
  unibi_set_if_empty(ut, unibi_set_a_background, XTERM_SETAB);
  unibi_set_if_empty(ut, unibi_enter_bold_mode, "\x1b[1m");
  unibi_set_if_empty(ut, unibi_enter_underline_mode, "\x1b[4m");
  unibi_set_if_empty(ut, unibi_enter_reverse_mode, "\x1b[7m");
  unibi_set_if_empty(ut, unibi_bell, "\x07");
  unibi_set_if_empty(data->ut, unibi_enter_ca_mode, "\x1b[?1049h");
  unibi_set_if_empty(data->ut, unibi_exit_ca_mode, "\x1b[?1049l");
  unibi_set_if_empty(ut, unibi_delete_line, "\x1b[M");
  unibi_set_if_empty(ut, unibi_parm_delete_line, "\x1b[%p1%dM");
  unibi_set_if_empty(ut, unibi_insert_line, "\x1b[L");
  unibi_set_if_empty(ut, unibi_parm_insert_line, "\x1b[%p1%dL");
  unibi_set_if_empty(ut, unibi_clear_screen, "\x1b[H\x1b[J");
  unibi_set_if_empty(ut, unibi_clr_eol, "\x1b[K");
  unibi_set_if_empty(ut, unibi_clr_eos, "\x1b[J");
}

static void flush_buf(UI *ui)
{
  static uv_write_t req;
  static uv_buf_t buf;
  TUIData *data = ui->data;
  buf.base = data->buf;
  buf.len = data->bufpos;
  uv_write(&req, (uv_stream_t *)&data->output_handle, &buf, 1, NULL);
  uv_run(data->write_loop, UV_RUN_DEFAULT);
  data->bufpos = 0;
}

static void destroy_screen(TUIData *data)
{
  if (data->screen) {
    for (int i = 0; i < data->old_height; i++) {
      free(data->screen[i]);
    }
    free(data->screen);
  }
}
