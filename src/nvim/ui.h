#ifndef NVIM_UI_H
#define NVIM_UI_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct {
  bool bold, standout, underline, undercurl, italic, reverse;
  int foreground, background;
} HlAttrs;

typedef struct ui_t UI;

struct ui_t {
  int width, height;
  void *data;
  void (*resize)(UI *ui, int rows, int columns);
  void (*clear)(UI *ui);
  void (*eol_clear)(UI *ui);
  void (*cursor_goto)(UI *ui, int row, int col);
  void (*cursor_on)(UI *ui);
  void (*cursor_off)(UI *ui);
  void (*mouse_on)(UI *ui);
  void (*mouse_off)(UI *ui);
  void (*insert_mode)(UI *ui);
  void (*normal_mode)(UI *ui);
  void (*set_scroll_region)(UI *ui, int top, int bot, int left, int right);
  void (*scroll)(UI *ui, int count);
  void (*highlight_set)(UI *ui, HlAttrs attrs);
  void (*put)(UI *ui, uint8_t *str, size_t len);
  void (*bell)(UI *ui);
  void (*visual_bell)(UI *ui);
  void (*flush)(UI *ui);
  void (*suspend)(UI *ui);
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.h.generated.h"
#endif
#endif  // NVIM_UI_H
