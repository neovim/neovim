// FIXME(tarruda): This module is very repetitive. It might be a good idea to
// automatically generate it with a lua script during build
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/memory.h"
#include "nvim/ui_bridge.h"
#include "nvim/ugrid.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_bridge.c.generated.h"
#endif

#define UI(b) (((UIBridgeData *)b)->ui)

// Call a function in the UI thread
#define UI_CALL(ui, name, argc, ...)                                      \
  ((UIBridgeData *)ui)->scheduler(                                        \
    event_create(1, ui_bridge_##name##_event, argc, __VA_ARGS__), UI(ui))

#define INT2PTR(i) ((void *)(uintptr_t)i)
#define PTR2INT(p) ((int)(uintptr_t)p)

UI *ui_bridge_attach(UI *ui, ui_main_fn ui_main, event_scheduler scheduler)
{
  UIBridgeData *rv = xcalloc(1, sizeof(UIBridgeData));
  rv->ui = ui;
  rv->bridge.rgb = ui->rgb;
  rv->bridge.stop = ui_bridge_stop;
  rv->bridge.resize = ui_bridge_resize;
  rv->bridge.clear = ui_bridge_clear;
  rv->bridge.eol_clear = ui_bridge_eol_clear;
  rv->bridge.cursor_goto = ui_bridge_cursor_goto;
  rv->bridge.update_menu = ui_bridge_update_menu;
  rv->bridge.busy_start = ui_bridge_busy_start;
  rv->bridge.busy_stop = ui_bridge_busy_stop;
  rv->bridge.mouse_on = ui_bridge_mouse_on;
  rv->bridge.mouse_off = ui_bridge_mouse_off;
  rv->bridge.mode_change = ui_bridge_mode_change;
  rv->bridge.set_scroll_region = ui_bridge_set_scroll_region;
  rv->bridge.scroll = ui_bridge_scroll;
  rv->bridge.highlight_set = ui_bridge_highlight_set;
  rv->bridge.put = ui_bridge_put;
  rv->bridge.bell = ui_bridge_bell;
  rv->bridge.visual_bell = ui_bridge_visual_bell;
  rv->bridge.update_fg = ui_bridge_update_fg;
  rv->bridge.update_bg = ui_bridge_update_bg;
  rv->bridge.flush = ui_bridge_flush;
  rv->bridge.suspend = ui_bridge_suspend;
  rv->bridge.set_title = ui_bridge_set_title;
  rv->bridge.set_icon = ui_bridge_set_icon;
  rv->scheduler = scheduler;

  rv->ui_main = ui_main;
  uv_mutex_init(&rv->mutex);
  uv_cond_init(&rv->cond);
  uv_mutex_lock(&rv->mutex);
  rv->ready = false;

  if (uv_thread_create(&rv->ui_thread, ui_thread_run, rv)) {
    abort();
  }

  while (!rv->ready) {
    uv_cond_wait(&rv->cond, &rv->mutex);
  }
  uv_mutex_unlock(&rv->mutex);

  ui_attach(&rv->bridge);
  return &rv->bridge;
}

void ui_bridge_stopped(UIBridgeData *bridge)
{
  uv_mutex_lock(&bridge->mutex);
  bridge->stopped = true;
  uv_mutex_unlock(&bridge->mutex);
}

static void ui_thread_run(void *data)
{
  UIBridgeData *bridge = data;
  bridge->ui_main(bridge, bridge->ui);
}

static void ui_bridge_stop(UI *b)
{
  UIBridgeData *bridge = (UIBridgeData *)b;
  bool stopped = bridge->stopped = false;
  UI_CALL(b, stop, 1, b);
  for (;;) {
    uv_mutex_lock(&bridge->mutex);
    stopped = bridge->stopped;
    uv_mutex_unlock(&bridge->mutex);
    if (stopped) {
      break;
    }
    loop_poll_events(&loop, 10);
  }
  uv_thread_join(&bridge->ui_thread);
  uv_mutex_destroy(&bridge->mutex);
  uv_cond_destroy(&bridge->cond);
  ui_detach(b);
  xfree(b);
}
static void ui_bridge_stop_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->stop(ui);
}

static void ui_bridge_resize(UI *b, int width, int height)
{
  UI_CALL(b, resize, 3, b, INT2PTR(width), INT2PTR(height));
}
static void ui_bridge_resize_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->resize(ui, PTR2INT(argv[1]), PTR2INT(argv[2]));
}

static void ui_bridge_clear(UI *b)
{
  UI_CALL(b, clear, 1, b);
}
static void ui_bridge_clear_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->clear(ui);
}

static void ui_bridge_eol_clear(UI *b)
{
  UI_CALL(b, eol_clear, 1, b);
}
static void ui_bridge_eol_clear_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->eol_clear(ui);
}

static void ui_bridge_cursor_goto(UI *b, int row, int col)
{
  UI_CALL(b, cursor_goto, 3, b, INT2PTR(row), INT2PTR(col));
}
static void ui_bridge_cursor_goto_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->cursor_goto(ui, PTR2INT(argv[1]), PTR2INT(argv[2]));
}

static void ui_bridge_update_menu(UI *b)
{
  UI_CALL(b, update_menu, 1, b);
}
static void ui_bridge_update_menu_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->update_menu(ui);
}

static void ui_bridge_busy_start(UI *b)
{
  UI_CALL(b, busy_start, 1, b);
}
static void ui_bridge_busy_start_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->busy_start(ui);
}

static void ui_bridge_busy_stop(UI *b)
{
  UI_CALL(b, busy_stop, 1, b);
}
static void ui_bridge_busy_stop_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->busy_stop(ui);
}

static void ui_bridge_mouse_on(UI *b)
{
  UI_CALL(b, mouse_on, 1, b);
}
static void ui_bridge_mouse_on_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->mouse_on(ui);
}

static void ui_bridge_mouse_off(UI *b)
{
  UI_CALL(b, mouse_off, 1, b);
}
static void ui_bridge_mouse_off_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->mouse_off(ui);
}

static void ui_bridge_mode_change(UI *b, int mode)
{
  UI_CALL(b, mode_change, 2, b, INT2PTR(mode));
}
static void ui_bridge_mode_change_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->mode_change(ui, PTR2INT(argv[1]));
}

static void ui_bridge_set_scroll_region(UI *b, int top, int bot, int left,
    int right)
{
  UI_CALL(b, set_scroll_region, 5, b, INT2PTR(top), INT2PTR(bot),
      INT2PTR(left), INT2PTR(right));
}
static void ui_bridge_set_scroll_region_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->set_scroll_region(ui, PTR2INT(argv[1]), PTR2INT(argv[2]),
      PTR2INT(argv[3]), PTR2INT(argv[4]));
}

static void ui_bridge_scroll(UI *b, int count)
{
  UI_CALL(b, scroll, 2, b, INT2PTR(count));
}
static void ui_bridge_scroll_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->scroll(ui, PTR2INT(argv[1]));
}

static void ui_bridge_highlight_set(UI *b, HlAttrs attrs)
{
  HlAttrs *a = xmalloc(sizeof(HlAttrs));
  *a = attrs;
  UI_CALL(b, highlight_set, 2, b, a);
}
static void ui_bridge_highlight_set_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->highlight_set(ui, *((HlAttrs *)argv[1]));
  xfree(argv[1]);
}

static void ui_bridge_put(UI *b, uint8_t *text, size_t size)
{
  uint8_t *t = NULL;
  if (text) {
    t = xmalloc(sizeof(((UCell *)0)->data));
    memcpy(t, text, size);
  }
  UI_CALL(b, put, 3, b, t, INT2PTR(size));
}
static void ui_bridge_put_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->put(ui, (uint8_t *)argv[1], (size_t)(uintptr_t)argv[2]);
  xfree(argv[1]);
}

static void ui_bridge_bell(UI *b)
{
  UI_CALL(b, bell, 1, b);
}
static void ui_bridge_bell_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->bell(ui);
}

static void ui_bridge_visual_bell(UI *b)
{
  UI_CALL(b, visual_bell, 1, b);
}
static void ui_bridge_visual_bell_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->visual_bell(ui);
}

static void ui_bridge_update_fg(UI *b, int fg)
{
  UI_CALL(b, update_fg, 2, b, INT2PTR(fg));
}
static void ui_bridge_update_fg_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->update_fg(ui, PTR2INT(argv[1]));
}

static void ui_bridge_update_bg(UI *b, int bg)
{
  UI_CALL(b, update_bg, 2, b, INT2PTR(bg));
}
static void ui_bridge_update_bg_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->update_bg(ui, PTR2INT(argv[1]));
}

static void ui_bridge_flush(UI *b)
{
  UI_CALL(b, flush, 1, b);
}
static void ui_bridge_flush_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->flush(ui);
}

static void ui_bridge_suspend(UI *b)
{
  UIBridgeData *data = (UIBridgeData *)b;
  uv_mutex_lock(&data->mutex);
  UI_CALL(b, suspend, 1, b);
  data->ready = false;
  // suspend the main thread until CONTINUE is called by the UI thread
  while (!data->ready) {
    uv_cond_wait(&data->cond, &data->mutex);
  }
  uv_mutex_unlock(&data->mutex);
}
static void ui_bridge_suspend_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->suspend(ui);
}

static void ui_bridge_set_title(UI *b, char *title)
{
  UI_CALL(b, set_title, 2, b, title ? xstrdup(title) : NULL);
}
static void ui_bridge_set_title_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->set_title(ui, argv[1]);
  xfree(argv[1]);
}

static void ui_bridge_set_icon(UI *b, char *icon)
{
  UI_CALL(b, set_icon, 2, b, icon ? xstrdup(icon) : NULL);
}
static void ui_bridge_set_icon_event(void **argv)
{
  UI *ui = UI(argv[0]);
  ui->set_icon(ui, argv[1]);
  xfree(argv[1]);
}
