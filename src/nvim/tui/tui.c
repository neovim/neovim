#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <limits.h>

#include <uv.h>
#include <unibilium.h>

#include "nvim/lib/kvec.h"

#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/map.h"
#include "nvim/memory.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/helpers.h"
#include "nvim/event/loop.h"
#include "nvim/event/signal.h"
#include "nvim/tui/tui.h"
#include "nvim/tui/input.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/strings.h"
#include "nvim/ugrid.h"
#include "nvim/ui_bridge.h"

// Space reserved in the output buffer to restore the cursor to normal when
// flushing. No existing terminal will require 32 bytes to do that.
#define CNORM_COMMAND_MAX_SIZE 32
#define OUTBUF_SIZE 0xffff

typedef struct {
  int top, bot, left, right;
} Rect;

typedef struct {
  UIBridgeData *bridge;
  Loop *loop;
  bool stop;
  unibi_var_t params[9];
  char buf[OUTBUF_SIZE];
  size_t bufpos, bufsize;
  TermInput input;
  uv_loop_t write_loop;
  unibi_term *ut;
  union {
    uv_tty_t tty;
    uv_pipe_t pipe;
  } output_handle;
  bool out_isatty;
  SignalWatcher winch_handle, cont_handle;
  bool cont_received;
  // Event scheduled by the ui bridge. Since the main thread suspends until
  // the event is handled, it is fine to use a single field instead of a queue
  Event scheduled_event;
  UGrid grid;
  kvec_t(Rect) invalid_regions;
  int out_fd;
  bool can_use_terminal_scroll;
  bool mouse_enabled;
  bool busy;
  HlAttrs print_attrs;
  int showing_mode;
  struct {
    int enable_mouse, disable_mouse;
    int enable_bracketed_paste, disable_bracketed_paste;
    int enter_insert_mode, enter_replace_mode, exit_insert_mode;
    int set_rgb_foreground, set_rgb_background;
    int enable_focus_reporting, disable_focus_reporting;
  } unibi_ext;
} TUIData;

static bool volatile got_winch = false;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/tui.c.generated.h"
#endif


UI *tui_start(void)
{
  UI *ui = xcalloc(1, sizeof(UI));
  ui->stop = tui_stop;
  ui->rgb = os_getenv("NVIM_TUI_ENABLE_TRUE_COLOR") != NULL;
  ui->resize = tui_resize;
  ui->clear = tui_clear;
  ui->eol_clear = tui_eol_clear;
  ui->cursor_goto = tui_cursor_goto;
  ui->update_menu = tui_update_menu;
  ui->busy_start = tui_busy_start;
  ui->busy_stop = tui_busy_stop;
  ui->mouse_on = tui_mouse_on;
  ui->mouse_off = tui_mouse_off;
  ui->mode_change = tui_mode_change;
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
  return ui_bridge_attach(ui, tui_main, tui_scheduler);
}

static void terminfo_start(UI *ui)
{
  TUIData *data = ui->data;
  data->can_use_terminal_scroll = true;
  data->bufpos = 0;
  data->bufsize = sizeof(data->buf) - CNORM_COMMAND_MAX_SIZE;
  data->showing_mode = 0;
  data->unibi_ext.enable_mouse = -1;
  data->unibi_ext.disable_mouse = -1;
  data->unibi_ext.enable_bracketed_paste = -1;
  data->unibi_ext.disable_bracketed_paste = -1;
  data->unibi_ext.enter_insert_mode = -1;
  data->unibi_ext.enter_replace_mode = -1;
  data->unibi_ext.exit_insert_mode = -1;
  data->unibi_ext.enable_focus_reporting = -1;
  data->unibi_ext.disable_focus_reporting = -1;
  data->out_fd = 1;
  data->out_isatty = os_isatty(data->out_fd);
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
  unibi_out(ui, data->unibi_ext.enable_bracketed_paste);
  // Enable focus reporting
  unibi_out(ui, data->unibi_ext.enable_focus_reporting);
  uv_loop_init(&data->write_loop);
  if (data->out_isatty) {
    uv_tty_init(&data->write_loop, &data->output_handle.tty, data->out_fd, 0);
    uv_tty_set_mode(&data->output_handle.tty, UV_TTY_MODE_RAW);
  } else {
    uv_pipe_init(&data->write_loop, &data->output_handle.pipe, 0);
    uv_pipe_open(&data->output_handle.pipe, data->out_fd);
  }
}

static void terminfo_stop(UI *ui)
{
  TUIData *data = ui->data;
  // Destroy output stuff
  tui_mode_change(ui, NORMAL);
  tui_mouse_off(ui);
  unibi_out(ui, unibi_exit_attribute_mode);
  // cursor should be set to normal before exiting alternate screen
  unibi_out(ui, unibi_cursor_normal);
  unibi_out(ui, unibi_exit_ca_mode);
  // Disable bracketed paste
  unibi_out(ui, data->unibi_ext.disable_bracketed_paste);
  // Disable focus reporting
  unibi_out(ui, data->unibi_ext.disable_focus_reporting);
  flush_buf(ui);
  uv_tty_reset_mode();
  uv_close((uv_handle_t *)&data->output_handle, NULL);
  uv_run(&data->write_loop, UV_RUN_DEFAULT);
  if (uv_loop_close(&data->write_loop)) {
    abort();
  }
  unibi_destroy(data->ut);
}

static void tui_terminal_start(UI *ui)
{
  TUIData *data = ui->data;
  data->print_attrs = EMPTY_ATTRS;
  ugrid_init(&data->grid);
  terminfo_start(ui);
  update_size(ui);
  signal_watcher_start(&data->winch_handle, sigwinch_cb, SIGWINCH);
  term_input_start(&data->input);
}

static void tui_terminal_stop(UI *ui)
{
  TUIData *data = ui->data;
  term_input_stop(&data->input);
  signal_watcher_stop(&data->winch_handle);
  terminfo_stop(ui);
  ugrid_free(&data->grid);
}

static void tui_stop(UI *ui)
{
  tui_terminal_stop(ui);
  TUIData *data = ui->data;
  data->stop = true;
}

// Main function of the TUI thread
static void tui_main(UIBridgeData *bridge, UI *ui)
{
  Loop tui_loop;
  loop_init(&tui_loop, NULL);
  TUIData *data = xcalloc(1, sizeof(TUIData));
  ui->data = data;
  data->bridge = bridge;
  data->loop = &tui_loop;
  kv_init(data->invalid_regions);
  signal_watcher_init(data->loop, &data->winch_handle, ui);
  signal_watcher_init(data->loop, &data->cont_handle, data);
  signal_watcher_start(&data->cont_handle, sigcont_cb, SIGCONT);
  // initialize input reading structures
  term_input_init(&data->input, &tui_loop);
  tui_terminal_start(ui);
  data->stop = false;
  // allow the main thread to continue, we are ready to start handling UI
  // callbacks
  CONTINUE(bridge);

  while (!data->stop) {
    loop_poll_events(&tui_loop, -1);
  }

  ui_bridge_stopped(bridge);
  term_input_destroy(&data->input);
  signal_watcher_stop(&data->cont_handle);
  signal_watcher_close(&data->cont_handle, NULL);
  signal_watcher_close(&data->winch_handle, NULL);
  loop_close(&tui_loop);
  kv_destroy(data->invalid_regions);
  xfree(data);
  xfree(ui);
}

static void tui_scheduler(Event event, void *d)
{
  UI *ui = d;
  TUIData *data = ui->data;
  loop_schedule(data->loop, event);
}

static void refresh_event(void **argv)
{
  ui_refresh();
}

static void sigcont_cb(SignalWatcher *watcher, int signum, void *data)
{
  ((TUIData *)data)->cont_received = true;
}

static void sigwinch_cb(SignalWatcher *watcher, int signum, void *data)
{
  got_winch = true;
  UI *ui = data;
  update_size(ui);
  // run refresh_event in nvim main loop
  loop_schedule(&loop, event_create(1, refresh_event, 0));
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
  UGrid *grid = &data->grid;

  int fg = attrs.foreground != -1 ? attrs.foreground : grid->fg;
  int bg = attrs.background != -1 ? attrs.background : grid->bg;

  if (ui->rgb) {
    if (fg != -1) {
      data->params[0].i = (fg >> 16) & 0xff;  // red
      data->params[1].i = (fg >> 8) & 0xff;   // green
      data->params[2].i = fg & 0xff;          // blue
      unibi_out(ui, data->unibi_ext.set_rgb_foreground);
    }

    if (bg != -1) {
      data->params[0].i = (bg >> 16) & 0xff;  // red
      data->params[1].i = (bg >> 8) & 0xff;   // green
      data->params[2].i = bg & 0xff;          // blue
      unibi_out(ui, data->unibi_ext.set_rgb_background);
    }
  } else {
    if (fg != -1) {
      data->params[0].i = fg;
      unibi_out(ui, unibi_set_a_foreground);
    }

    if (bg != -1) {
      data->params[0].i = bg;
      unibi_out(ui, unibi_set_a_background);
    }
  }

  if (attrs.bold) {
    unibi_out(ui, unibi_enter_bold_mode);
  }
  if (attrs.italic) {
    unibi_out(ui, unibi_enter_italics_mode);
  }
  if (attrs.underline || attrs.undercurl) {
    unibi_out(ui, unibi_enter_underline_mode);
  }
  if (attrs.reverse) {
    unibi_out(ui, unibi_enter_reverse_mode);
  }
}

static void print_cell(UI *ui, UCell *ptr)
{
  update_attrs(ui, ptr->attrs);
  out(ui, ptr->data, strlen(ptr->data));
}

static void clear_region(UI *ui, int top, int bot, int left, int right)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  bool cleared = false;
  if (grid->bg == -1 && right == ui->width -1) {
    // Background is set to the default color and the right edge matches the
    // screen end, try to use terminal codes for clearing the requested area.
    HlAttrs clear_attrs = EMPTY_ATTRS;
    clear_attrs.foreground = grid->fg;
    clear_attrs.background = grid->bg;
    update_attrs(ui, clear_attrs);
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

  if (!cleared) {
    // could not clear using faster terminal codes, refresh the whole region
    int currow = -1;
    UGRID_FOREACH_CELL(grid, top, bot, left, right, {
      if (currow != row) {
        unibi_goto(ui, row, col);
        currow = row;
      }
      print_cell(ui, cell);
    });
  }

  // restore cursor
  unibi_goto(ui, grid->row, grid->col);
}

static void tui_resize(UI *ui, int width, int height)
{
  TUIData *data = ui->data;
  ugrid_resize(&data->grid, width, height);

  if (!got_winch) {  // Try to resize the terminal window.
    char r[16];  // enough for 9999x9999
    snprintf(r, sizeof(r), "\x1b[8;%d;%dt", height, width);
    out(ui, r, strlen(r));
  } else {  // Already handled the SIGWINCH signal; avoid double-resize.
    got_winch = false;
  }
}

static void tui_clear(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  ugrid_clear(grid);
  clear_region(ui, grid->top, grid->bot, grid->left, grid->right);
}

static void tui_eol_clear(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  ugrid_eol_clear(grid);
  clear_region(ui, grid->row, grid->row, grid->col, grid->right);
}

static void tui_cursor_goto(UI *ui, int row, int col)
{
  TUIData *data = ui->data;
  ugrid_goto(&data->grid, row, col);
  unibi_goto(ui, row, col);
}

static void tui_update_menu(UI *ui)
{
    // Do nothing; menus are for GUI only
}

static void tui_busy_start(UI *ui)
{
  ((TUIData *)ui->data)->busy = true;
}

static void tui_busy_stop(UI *ui)
{
  ((TUIData *)ui->data)->busy = false;
}

static void tui_mouse_on(UI *ui)
{
  TUIData *data = ui->data;
  unibi_out(ui, data->unibi_ext.enable_mouse);
  data->mouse_enabled = true;
}

static void tui_mouse_off(UI *ui)
{
  TUIData *data = ui->data;
  unibi_out(ui, data->unibi_ext.disable_mouse);
  data->mouse_enabled = false;
}

static void tui_mode_change(UI *ui, int mode)
{
  TUIData *data = ui->data;

  if (mode == INSERT) {
    if (data->showing_mode != INSERT) {
      unibi_out(ui, data->unibi_ext.enter_insert_mode);
    }
  } else if (mode == REPLACE) {
    if (data->showing_mode != REPLACE) {
      unibi_out(ui, data->unibi_ext.enter_replace_mode);
    }
  } else {
    assert(mode == NORMAL);
    if (data->showing_mode != NORMAL) {
      unibi_out(ui, data->unibi_ext.exit_insert_mode);
    }
  }
  data->showing_mode = mode;
}

static void tui_set_scroll_region(UI *ui, int top, int bot, int left,
    int right)
{
  TUIData *data = ui->data;
  ugrid_set_scroll_region(&data->grid, top, bot, left, right);
  data->can_use_terminal_scroll =
    left == 0 && right == ui->width - 1
    && ((top == 0 && bot == ui->height - 1)
        || unibi_get_str(data->ut, unibi_change_scroll_region));
}

static void tui_scroll(UI *ui, int count)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  int clear_top, clear_bot;
  ugrid_scroll(grid, count, &clear_top, &clear_bot);

  if (data->can_use_terminal_scroll) {
    // Change terminal scroll region and move cursor to the top
    data->params[0].i = grid->top;
    data->params[1].i = grid->bot;
    unibi_out(ui, unibi_change_scroll_region);
    unibi_goto(ui, grid->top, grid->left);
    // also set default color attributes or some terminals can become funny
    HlAttrs clear_attrs = EMPTY_ATTRS;
    clear_attrs.foreground = grid->fg;
    clear_attrs.background = grid->bg;
    update_attrs(ui, clear_attrs);
  }

  if (count > 0) {
    if (data->can_use_terminal_scroll) {
      if (count == 1) {
        unibi_out(ui, unibi_delete_line);
      } else {
        data->params[0].i = count;
        unibi_out(ui, unibi_parm_delete_line);
      }
    }

  } else {
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
    unibi_goto(ui, grid->row, grid->col);

    if (grid->bg != -1) {
      // Update the cleared area of the terminal if its builtin scrolling
      // facility was used and the background color is not the default. This is
      // required because scrolling may leave wrong background in the cleared
      // area.
      clear_region(ui, clear_top, clear_bot, grid->left, grid->right);
    }
  } else {
    // Mark the entire scroll region as invalid for redrawing later
    invalidate(ui, grid->top, grid->bot, grid->left, grid->right);
  }
}

static void tui_highlight_set(UI *ui, HlAttrs attrs)
{
  ((TUIData *)ui->data)->grid.attrs = attrs;
}

static void tui_put(UI *ui, uint8_t *text, size_t size)
{
  TUIData *data = ui->data;
  print_cell(ui, ugrid_put(&data->grid, text, size));
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
  ((TUIData *)ui->data)->grid.fg = fg;
}

static void tui_update_bg(UI *ui, int bg)
{
  ((TUIData *)ui->data)->grid.bg = bg;
}

static void tui_flush(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  while (kv_size(data->invalid_regions)) {
    Rect r = kv_pop(data->invalid_regions);
    int currow = -1;
    UGRID_FOREACH_CELL(grid, r.top, r.bot, r.left, r.right, {
      if (currow != row) {
        unibi_goto(ui, row, col);
        currow = row;
      }
      print_cell(ui, cell);
    });
  }

  unibi_goto(ui, grid->row, grid->col);

  flush_buf(ui);
}

static void suspend_event(void **argv)
{
  UI *ui = argv[0];
  TUIData *data = ui->data;
  bool enable_mouse = data->mouse_enabled;
  tui_terminal_stop(ui);
  data->cont_received = false;
  kill(0, SIGTSTP);
  while (!data->cont_received) {
    // poll the event loop until SIGCONT is received
    loop_poll_events(data->loop, -1);
  }
  tui_terminal_start(ui);
  if (enable_mouse) {
    tui_mouse_on(ui);
  }
  // resume the main thread
  CONTINUE(data->bridge);
}

static void tui_suspend(UI *ui)
{
  TUIData *data = ui->data;
  // kill(0, SIGTSTP) won't stop the UI thread, so we must poll for SIGCONT
  // before continuing. This is done in another callback to avoid
  // loop_poll_events recursion
  queue_put_event(data->loop->fast_events,
      event_create(1, suspend_event, 1, ui));
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

  // 1 - look for non-default 'columns' and 'lines' options during startup
  if (starting != 0 && (Columns != DFLT_COLS || Rows != DFLT_ROWS)) {
    assert(Columns >= INT_MIN && Columns <= INT_MAX);
    assert(Rows >= INT_MIN && Rows <= INT_MAX);
    width = (int)Columns;
    height = (int)Rows;
    goto end;
  }

  // 2 - try from a system call(ioctl/TIOCGWINSZ on unix)
  if (data->out_isatty &&
      !uv_tty_get_winsize(&data->output_handle.tty, &width, &height)) {
    goto end;
  }

  // 3 - use $LINES/$COLUMNS if available
  const char *val;
  int advance;
  if ((val = os_getenv("LINES"))
      && sscanf(val, "%d%n", &height, &advance) != EOF && advance
      && (val = os_getenv("COLUMNS"))
      && sscanf(val, "%d%n", &width, &advance) != EOF && advance) {
    goto end;
  }

  // 4 - read from terminfo if available
  height = unibi_get_num(data->ut, unibi_lines);
  width = unibi_get_num(data->ut, unibi_columns);

end:
  if (width <= 0 || height <= 0) {
    // use the defaults
    width = DFLT_COLS;
    height = DFLT_ROWS;
  }

  data->bridge->bridge.width = ui->width = width;
  data->bridge->bridge.height = ui->height = height;
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
  size_t available = data->bufsize - data->bufpos;

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
  } else if (STARTS_WITH(term, "screen") || STARTS_WITH(term, "tmux")) {
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

  data->unibi_ext.enable_bracketed_paste = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?2004h");
  data->unibi_ext.disable_bracketed_paste = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?2004l");

  data->unibi_ext.enable_focus_reporting = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1004h");
  data->unibi_ext.disable_focus_reporting = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1004l");

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
  const char *vte_version = os_getenv("VTE_VERSION");

  if ((term_prog && !strcmp(term_prog, "Konsole"))
      || os_getenv("KONSOLE_DBUS_SESSION") != NULL) {
    // Konsole uses a proprietary escape code to set the cursor shape
    // and does not support DECSCUSR.
    data->unibi_ext.enter_insert_mode = (int)unibi_add_ext_str(ut, NULL,
        TMUX_WRAP("\x1b]50;CursorShape=1;BlinkingCursorEnabled=1\x07"));
    data->unibi_ext.enter_replace_mode = (int)unibi_add_ext_str(ut, NULL,
        TMUX_WRAP("\x1b]50;CursorShape=2;BlinkingCursorEnabled=1\x07"));
    data->unibi_ext.exit_insert_mode = (int)unibi_add_ext_str(ut, NULL,
        TMUX_WRAP("\x1b]50;CursorShape=0;BlinkingCursorEnabled=0\x07"));
  } else if (!vte_version || atoi(vte_version) >= 3900) {
    // Assume that the terminal supports DECSCUSR unless it is an
    // old VTE based terminal.  This should not get wrapped for tmux,
    // which will handle it via its Ss/Se terminfo extension - usually
    // according to its terminal-overrides.
    data->unibi_ext.enter_insert_mode = (int)unibi_add_ext_str(ut, NULL,
                                                               "\x1b[5 q");
    data->unibi_ext.enter_replace_mode = (int)unibi_add_ext_str(ut, NULL,
                                                                "\x1b[3 q");
    data->unibi_ext.exit_insert_mode = (int)unibi_add_ext_str(ut, NULL,
                                                              "\x1b[2 q");
  }

end:
  // Fill some empty slots with common terminal strings
  data->unibi_ext.enable_mouse = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1002h\x1b[?1006h");
  data->unibi_ext.disable_mouse = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1002l\x1b[?1006l");
  data->unibi_ext.set_rgb_foreground = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[38;2;%p1%d;%p2%d;%p3%dm");
  data->unibi_ext.set_rgb_background = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[48;2;%p1%d;%p2%d;%p3%dm");
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
  uv_write_t req;
  uv_buf_t buf;
  TUIData *data = ui->data;

  if (!data->busy) {
    // not busy and the cursor is invisible(see below). Append a "cursor
    // normal" command to the end of the buffer.
    data->bufsize += CNORM_COMMAND_MAX_SIZE;
    unibi_out(ui, unibi_cursor_normal);
    data->bufsize -= CNORM_COMMAND_MAX_SIZE;
  }

  buf.base = data->buf;
  buf.len = data->bufpos;
  uv_write(&req, (uv_stream_t *)&data->output_handle, &buf, 1, NULL);
  uv_run(&data->write_loop, UV_RUN_DEFAULT);
  data->bufpos = 0;

  if (!data->busy) {
    // not busy and cursor is visible(see above), append a "cursor invisible"
    // command to the beginning of the buffer for the next flush
    unibi_out(ui, unibi_cursor_invisible);
  }
}
