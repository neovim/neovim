#ifndef NVIM_CURSOR_H
#define NVIM_CURSOR_H

#include <stdbool.h>

#include "nvim/vim.h"
#include "nvim/misc2.h"

int coladvance(colnr_T wcol);
int coladvance_force(colnr_T wcol);
int getvpos(pos_T *pos, colnr_T wcol);
int getviscol(void);
int getviscol2(colnr_T col, colnr_T coladd);
int inc_cursor(void);
int dec_cursor(void);
linenr_T get_cursor_rel_lnum(win_T *wp, linenr_T lnum);
void check_cursor_lnum(void);
void check_cursor_col(void);
void check_cursor_col_win(win_T *win);
void check_cursor(void);
void adjust_cursor_col(void);
bool leftcol_changed(void);
int gchar_cursor(void);
void pchar_cursor(char_u c);
char_u *get_cursor_line_ptr(void);
char_u *get_cursor_pos_ptr(void);

#endif  // NVIM_CURSOR_H

