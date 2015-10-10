#ifndef NVIM_UI_H
#define NVIM_UI_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct {
  bool bold, underline, undercurl, italic, reverse;
  int foreground, background;
} HlAttrs;

typedef struct ui_t UI;

struct ui_t {
  bool rgb;
  int width, height;
  void *data;
  void (*resize)(UI *ui, int rows, int columns);
  void (*clear)(UI *ui);
  void (*eol_clear)(UI *ui);
  void (*cursor_goto)(UI *ui, int row, int col);
  void (*update_menu)(UI *ui);
  void (*busy_start)(UI *ui);
  void (*busy_stop)(UI *ui);
  void (*mouse_on)(UI *ui);
  void (*mouse_off)(UI *ui);
  void (*mode_change)(UI *ui, int mode);
  void (*set_scroll_region)(UI *ui, int top, int bot, int left, int right);
  void (*scroll)(UI *ui, int count);
  void (*highlight_set)(UI *ui, HlAttrs attrs);
  void (*put)(UI *ui, uint8_t *str, size_t len);
  void (*bell)(UI *ui);
  void (*visual_bell)(UI *ui);
  void (*flush)(UI *ui);
  void (*update_fg)(UI *ui, int fg);
  void (*update_bg)(UI *ui, int bg);
  void (*suspend)(UI *ui);
  void (*set_title)(UI *ui, char *title);
  void (*set_icon)(UI *ui, char *icon);
  void (*stop)(UI *ui);
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.h.generated.h"
#endif
#endif  // NVIM_UI_H
