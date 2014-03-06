#ifndef NEOVIM_POPUPMNU_H
#define NEOVIM_POPUPMNU_H

/*
 * Used for popup menu items.
 */
typedef struct {
  char_u      *pum_text;        /* main menu text */
  char_u      *pum_kind;        /* extra kind text (may be truncated) */
  char_u      *pum_extra;       /* extra menu text (may be truncated) */
  char_u      *pum_info;        /* extra info */
} pumitem_T;

void pum_display(pumitem_T *array, int size, int selected);
void pum_redraw(void);
void pum_undisplay(void);
void pum_clear(void);
int pum_visible(void);
int pum_get_height(void);
/* vim: set ft=c : */
#endif /* NEOVIM_POPUPMNU_H */
