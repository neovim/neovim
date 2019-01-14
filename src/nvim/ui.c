// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/log.h"
#include "nvim/ui.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_getln.h"
#include "nvim/fold.h"
#include "nvim/main.h"
#include "nvim/ascii.h"
#include "nvim/misc1.h"
#include "nvim/mbyte.h"
#include "nvim/garray.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/event/loop.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"
#include "nvim/os/signal.h"
#include "nvim/popupmnu.h"
#include "nvim/screen.h"
#include "nvim/highlight.h"
#include "nvim/window.h"
#include "nvim/cursor_shape.h"
#ifdef FEAT_TUI
# include "nvim/tui/tui.h"
#else
# include "nvim/msgpack_rpc/server.h"
#endif
#include "nvim/api/private/helpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.c.generated.h"
#endif

#define MAX_UI_COUNT 16

static UI *uis[MAX_UI_COUNT];
static bool ui_ext[kUIExtCount] = { 0 };
static size_t ui_count = 0;
static int ui_mode_idx = SHAPE_IDX_N;
static int cursor_row = 0, cursor_col = 0;
static bool pending_cursor_update = false;
static int busy = 0;
static bool pending_mode_info_update = false;
static bool pending_mode_update = false;
static handle_T cursor_grid_handle = DEFAULT_GRID_HANDLE;

#if MIN_LOG_LEVEL > DEBUG_LOG_LEVEL
# define UI_LOG(funname, ...)
#else
static size_t uilog_seen = 0;
static char uilog_last_event[1024] = { 0 };
# define UI_LOG(funname, ...) \
  do { \
    if (strequal(uilog_last_event, STR(funname))) { \
      uilog_seen++; \
    } else { \
      if (uilog_seen > 0) { \
        logmsg(DEBUG_LOG_LEVEL, "UI: ", NULL, -1, true, \
               "%s (+%zu times...)", uilog_last_event, uilog_seen); \
      } \
      logmsg(DEBUG_LOG_LEVEL, "UI: ", NULL, -1, true, STR(funname)); \
      uilog_seen = 0; \
      xstrlcpy(uilog_last_event, STR(funname), sizeof(uilog_last_event)); \
    } \
  } while (0)
#endif

// UI_CALL invokes a function on all registered UI instances. The functions can
// have 0-10 arguments (configurable by SELECT_NTH).
//
// See http://stackoverflow.com/a/11172679 for how it works.
#ifdef _MSC_VER
# define UI_CALL(funname, ...) \
    do { \
      UI_LOG(funname, 0); \
      for (size_t i = 0; i < ui_count; i++) { \
        UI *ui = uis[i]; \
        UI_CALL_MORE(funname, __VA_ARGS__); \
      } \
    } while (0)
#else
# define UI_CALL(...) \
    do { \
      UI_LOG(__VA_ARGS__, 0); \
      for (size_t i = 0; i < ui_count; i++) { \
        UI *ui = uis[i]; \
        UI_CALL_HELPER(CNT(__VA_ARGS__), __VA_ARGS__); \
      } \
    } while (0)
#endif
#define CNT(...) SELECT_NTH(__VA_ARGS__, MORE, MORE, MORE, MORE, MORE, \
                            MORE, MORE, MORE, MORE, ZERO, ignore)
#define SELECT_NTH(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, ...) a11
#define UI_CALL_HELPER(c, ...) UI_CALL_HELPER2(c, __VA_ARGS__)
// Resolves to UI_CALL_MORE or UI_CALL_ZERO.
#define UI_CALL_HELPER2(c, ...) UI_CALL_##c(__VA_ARGS__)
#define UI_CALL_MORE(method, ...) if (ui->method) ui->method(ui, __VA_ARGS__)
#define UI_CALL_ZERO(method) if (ui->method) ui->method(ui)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_events_call.generated.h"
#endif

void ui_builtin_start(void)
{
#ifdef FEAT_TUI
  tui_start();
#else
  fprintf(stderr, "Nvim headless-mode started.\n");
  size_t len;
  char **addrs = server_address_list(&len);
  if (addrs != NULL) {
    fprintf(stderr, "Listening on:\n");
    for (size_t i = 0; i < len; i++) {
      fprintf(stderr, "\t%s\n", addrs[i]);
    }
    xfree(addrs);
  }
  fprintf(stderr, "Press CTRL+C to exit.\n");
#endif
}

void ui_builtin_stop(void)
{
  UI_CALL(stop);
}

bool ui_rgb_attached(void)
{
  if (!headless_mode && p_tgc) {
    return true;
  }
  for (size_t i = 0; i < ui_count; i++) {
    if (uis[i]->rgb) {
      return true;
    }
  }
  return false;
}

bool ui_active(void)
{
  return ui_count != 0;
}

void ui_event(char *name, Array args)
{
  bool args_consumed = false;
  UI_CALL(event, name, args, &args_consumed);
  if (!args_consumed) {
    api_free_array(args);
  }
}


void ui_refresh(void)
{
  if (!ui_active()) {
    return;
  }

  if (updating_screen) {
    ui_schedule_refresh();
    return;
  }

  int width = INT_MAX, height = INT_MAX;
  bool ext_widgets[kUIExtCount];
  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {
    ext_widgets[i] = true;
  }

  for (size_t i = 0; i < ui_count; i++) {
    UI *ui = uis[i];
    width = MIN(ui->width, width);
    height = MIN(ui->height, height);
    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {
      ext_widgets[j] &= ui->ui_ext[j];
    }
  }

  cursor_row = cursor_col = 0;
  pending_cursor_update = true;

  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {
    ui_ext[i] = ext_widgets[i];
    if (i < kUIGlobalCount) {
      ui_call_option_set(cstr_as_string((char *)ui_ext_names[i]),
                         BOOLEAN_OBJ(ext_widgets[i]));
    }
  }

  ui_default_colors_set();

  int save_p_lz = p_lz;
  p_lz = false;  // convince redrawing() to return true ...
  screen_resize(width, height);
  p_lz = save_p_lz;

  ui_mode_info_set();
  pending_mode_update = true;
  ui_cursor_shape();
}

static void ui_refresh_event(void **argv)
{
  ui_refresh();
}

void ui_schedule_refresh(void)
{
  loop_schedule(&main_loop, event_create(ui_refresh_event, 0));
}

void ui_resize(int width, int height)
{
  ui_call_grid_resize(1, width, height);
}

void ui_default_colors_set(void)
{
  ui_call_default_colors_set(normal_fg, normal_bg, normal_sp,
                             cterm_normal_fg_color, cterm_normal_bg_color);
}

void ui_busy_start(void)
{
  if (!(busy++)) {
    ui_call_busy_start();
  }
}

void ui_busy_stop(void)
{
  if (!(--busy)) {
    ui_call_busy_stop();
  }
}

void ui_attach_impl(UI *ui)
{
  if (ui_count == MAX_UI_COUNT) {
    abort();
  }

  uis[ui_count++] = ui;
  ui_refresh_options();

  for (UIExtension i = kUIGlobalCount; (int)i < kUIExtCount; i++) {
    ui_set_ext_option(ui, i, ui->ui_ext[i]);
  }

  bool sent = false;
  if (ui->ui_ext[kUIHlState]) {
    sent = highlight_use_hlstate();
  }
  if (!sent) {
    ui_send_all_hls(ui);
  }
  ui_refresh();
}

void ui_detach_impl(UI *ui)
{
  size_t shift_index = MAX_UI_COUNT;

  // Find the index that will be removed
  for (size_t i = 0; i < ui_count; i++) {
    if (uis[i] == ui) {
      shift_index = i;
      break;
    }
  }

  if (shift_index == MAX_UI_COUNT) {
    abort();
  }

  // Shift UIs at "shift_index"
  while (shift_index < ui_count - 1) {
    uis[shift_index] = uis[shift_index + 1];
    shift_index++;
  }

  if (--ui_count
      // During teardown/exit the loop was already destroyed, cannot schedule.
      // https://github.com/neovim/neovim/pull/5119#issuecomment-258667046
      && !exiting) {
    ui_schedule_refresh();
  }
}

void ui_set_ext_option(UI *ui, UIExtension ext, bool active)
{
  if (ext < kUIGlobalCount) {
    ui_refresh();
    return;
  }
  if (ui->option_set) {
    ui->option_set(ui, cstr_as_string((char *)ui_ext_names[ext]),
                   BOOLEAN_OBJ(active));
  }
}

void ui_line(ScreenGrid *grid, int row, int startcol, int endcol, int clearcol,
             int clearattr, bool wrap)
{
  size_t off = grid->line_offset[row] + (size_t)startcol;

  UI_CALL(raw_line, grid->handle, row, startcol, endcol, clearcol, clearattr,
          wrap, (const schar_T *)grid->chars + off,
          (const sattr_T *)grid->attrs + off);

  if (p_wd) {  // 'writedelay': flush & delay each time.
    int old_row = cursor_row, old_col = cursor_col;
    handle_T old_grid = cursor_grid_handle;
    // If 'writedelay' is active, set the cursor to indicate what was drawn.
    ui_grid_cursor_goto(grid->handle, row, MIN(clearcol, (int)Columns-1));
    ui_flush();
    uint64_t wd = (uint64_t)labs(p_wd);
    os_microdelay(wd * 1000u, true);
    ui_grid_cursor_goto(old_grid, old_row, old_col);
  }
}

void ui_cursor_goto(int new_row, int new_col)
{
  ui_grid_cursor_goto(DEFAULT_GRID_HANDLE, new_row, new_col);
}

void ui_grid_cursor_goto(handle_T grid_handle, int new_row, int new_col)
{
  if (new_row == cursor_row
      && new_col == cursor_col
      && grid_handle == cursor_grid_handle) {
    return;
  }

  cursor_row = new_row;
  cursor_col = new_col;
  cursor_grid_handle = grid_handle;
  pending_cursor_update = true;
}

void ui_mode_info_set(void)
{
  pending_mode_info_update = true;
}

int ui_current_row(void)
{
  return cursor_row;
}

int ui_current_col(void)
{
  return cursor_col;
}

void ui_flush(void)
{
  cmdline_ui_flush();
  win_ui_flush();
  if (pending_cursor_update) {
    ui_call_grid_cursor_goto(cursor_grid_handle, cursor_row, cursor_col);
    pending_cursor_update = false;
  }
  if (pending_mode_info_update) {
    Array style = mode_style_array();
    bool enabled = (*p_guicursor != NUL);
    ui_call_mode_info_set(enabled, style);
    api_free_array(style);
    pending_mode_info_update = false;
  }
  if (pending_mode_update) {
    char *full_name = shape_table[ui_mode_idx].full_name;
    ui_call_mode_change(cstr_as_string(full_name), ui_mode_idx);
    pending_mode_update = false;
  }
  ui_call_flush();
}


/// Check if current mode has changed.
/// May update the shape of the cursor.
void ui_cursor_shape(void)
{
  if (!full_screen) {
    return;
  }
  int new_mode_idx = cursor_get_mode_idx();

  if (new_mode_idx != ui_mode_idx) {
    ui_mode_idx = new_mode_idx;
    pending_mode_update = true;
  }
  conceal_check_cursor_line();
}

/// Returns true if `widget` is externalized.
bool ui_is_external(UIExtension widget)
{
  return ui_ext[widget];
}

Array ui_array(void)
{
  Array all_uis = ARRAY_DICT_INIT;
  for (size_t i = 0; i < ui_count; i++) {
    UI *ui = uis[i];
    Dictionary info = ARRAY_DICT_INIT;
    PUT(info, "width", INTEGER_OBJ(ui->width));
    PUT(info, "height", INTEGER_OBJ(ui->height));
    PUT(info, "rgb", BOOLEAN_OBJ(ui->rgb));
    for (UIExtension j = 0; j < kUIExtCount; j++) {
      PUT(info, ui_ext_names[j], BOOLEAN_OBJ(ui->ui_ext[j]));
    }
    if (ui->inspect) {
      ui->inspect(ui, &info);
    }
    ADD(all_uis, DICTIONARY_OBJ(info));
  }
  return all_uis;
}

void ui_grid_resize(handle_T grid_handle, int width, int height, Error *error)
{
  if (grid_handle == DEFAULT_GRID_HANDLE) {
    screen_resize(width, height);
    return;
  }

  win_T *wp = get_win_by_grid_handle(grid_handle);
  if (wp == NULL) {
    api_set_error(error, kErrorTypeValidation,
                  "No window with the given handle");
    return;
  }

  wp->w_grid.requested_rows = (int)height;
  wp->w_grid.requested_cols = (int)width;
  redraw_win_later(wp, SOME_VALID);
}
