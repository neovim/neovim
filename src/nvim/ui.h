#ifndef NVIM_UI_H
#define NVIM_UI_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#include "api/private/defs.h"
#include "nvim/buffer_defs.h"

typedef enum {
  kUICmdline = 0,
  kUIPopupmenu,
  kUITabline,
  kUIWildmenu,
} UIWidget;
#define UI_WIDGETS (kUIWildmenu + 1)

typedef struct {
  bool bold, underline, undercurl, italic, reverse;
  int foreground, background, special;
} HlAttrs;

typedef struct ui_t UI;

struct ui_t {
  bool rgb;
  bool ui_ext[UI_WIDGETS];  ///< Externalized widgets
  int width, height;
  void *data;
  void (*resize)(UI *ui, int rows, int columns);
  void (*clear)(UI *ui);
  void (*eol_clear)(UI *ui);
  void (*cursor_goto)(UI *ui, int row, int col);
  void (*mode_info_set)(UI *ui, bool enabled, Array cursor_styles);
  void (*update_menu)(UI *ui);
  void (*busy_start)(UI *ui);
  void (*busy_stop)(UI *ui);
  void (*mouse_on)(UI *ui);
  void (*mouse_off)(UI *ui);
  void (*mode_change)(UI *ui, int mode_idx);
  void (*set_scroll_region)(UI *ui, int top, int bot, int left, int right);
  void (*scroll)(UI *ui, int count);
  void (*highlight_set)(UI *ui, HlAttrs attrs);
  void (*put)(UI *ui, uint8_t *str, size_t len);
  void (*bell)(UI *ui);
  void (*visual_bell)(UI *ui);
  void (*flush)(UI *ui);
  void (*update_fg)(UI *ui, int fg);
  void (*update_bg)(UI *ui, int bg);
  void (*update_sp)(UI *ui, int sp);
  void (*suspend)(UI *ui);
  void (*set_title)(UI *ui, char *title);
  void (*set_icon)(UI *ui, char *icon);
  void (*event)(UI *ui, char *name, Array args, bool *args_consumed);
  void (*stop)(UI *ui);
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.h.generated.h"
#endif
#endif  // NVIM_UI_H
