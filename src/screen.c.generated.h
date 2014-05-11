#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static inline int arabic_char(int c);
static void update_prepare();
static void update_finish();
static int draw_signcolumn(win_T *wp);
static void win_update(win_T *wp);
static void win_draw_end(win_T *wp, int c1, int c2, int row, int endrow, hlf_T hl);
static int advance_color_col(int vcol, int **color_cols);
static void fold_line(win_T *wp, long fold_count, foldinfo_T *foldinfo, linenr_T lnum, int row);
static void copy_text_attr(int off, char_u *buf, int len, int attr);
static void fill_foldcolumn(char_u *p, win_T *wp, int closed, linenr_T lnum);
static int win_line(win_T *wp, linenr_T lnum, int startrow, int endrow, int nochange);
static int comp_char_differs(int off_from, int off_to);
static int char_needs_redraw(int off_from, int off_to, int cols);
static void screen_line(int row, int coloff, int endcol, int clear_width, int rlflag);
static void draw_vsep_win(win_T *wp, int row);
static int status_match_len(expand_T *xp, char_u *s);
static int skip_status_match_char(expand_T *xp, char_u *s);
static void redraw_custom_statusline(win_T *wp);
static void win_redr_custom(win_T *wp, int draw_ruler);
static int screen_comp_differs(int off, int *u8cc);
static void start_search_hl(void);
static void end_search_hl(void);
static void init_search_hl(win_T *wp);
static void prepare_search_hl(win_T *wp, linenr_T lnum);
static void next_search_hl(win_T *win, match_T *shl, linenr_T lnum, colnr_T mincol);
static void screen_start_highlight(int attr);
static void screen_char(unsigned off, int row, int col);
static void screen_char_2(unsigned off, int row, int col);
static void redraw_block(int row, int end, win_T *wp);
static void screenclear2(void);
static void lineclear(unsigned off, int width);
static void lineinvalid(unsigned off, int width);
static void linecopy(int to, int from, win_T *wp);
static int win_do_lines(win_T *wp, int row, int line_count, int mayclear, int del);
static void win_rest_invalid(win_T *wp);
static void msg_pos_mode(void);
static void draw_tabline(void);
static int fillchar_status(int *attr, int is_curwin);
static int fillchar_vsep(int *attr);
static void win_redr_ruler(win_T *wp, int always);
#include "func_attr.h"
