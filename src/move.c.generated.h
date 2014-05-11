#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void comp_botline(win_T *wp);
static void redraw_for_cursorline(win_T *wp);
static int scrolljump_value(void);
static int check_top_offset(void);
static void validate_botline_win(win_T *wp);
static void curs_rows(win_T *wp, int do_botline);
static void validate_cheight(void);
static void max_topfill(void);
static void topline_back(lineoff_T *lp);
static void botline_forw(lineoff_T *lp);
static void botline_topline(lineoff_T *lp);
static void topline_botline(lineoff_T *lp);
static void get_scroll_overlap(lineoff_T *lp, int dir);
#include "func_attr.h"
