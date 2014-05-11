#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void win_init(win_T *newp, win_T *oldp, int flags);
static void win_init_some(win_T *newp, win_T *oldp);
static void win_exchange(long Prenum);
static void win_rotate(int upwards, int count);
static void win_totop(int size, int flags);
static void win_equal_rec(win_T *next_curwin, int current, frame_T *topfr, int dir, int col, int row, int width, int height);
static int last_window(void);
static int close_last_window_tabpage(win_T *win, int free_buf, tabpage_T *prev_curtab);
static win_T *win_free_mem(win_T *win, int *dirp, tabpage_T *tp);
static frame_T *win_altframe(win_T *win, tabpage_T *tp);
static tabpage_T *alt_tabpage(void);
static win_T *frame2win(frame_T *frp);
static int frame_has_win(frame_T *frp, win_T *wp);
static void frame_new_height(frame_T *topfrp, int height, int topfirst, int wfh);
static int frame_fixed_height(frame_T *frp);
static int frame_fixed_width(frame_T *frp);
static void frame_add_statusline(frame_T *frp);
static void frame_new_width(frame_T *topfrp, int width, int leftfirst, int wfw);
static void frame_add_vsep(frame_T *frp);
static void frame_fix_width(win_T *wp);
static void frame_fix_height(win_T *wp);
static int frame_minheight(frame_T *topfrp, win_T *next_curwin);
static int frame_minwidth(frame_T *topfrp, win_T *next_curwin);
static int win_alloc_firstwin(win_T *oldwin);
static void new_frame(win_T *wp);
static tabpage_T *alloc_tabpage(void);
static int leave_tabpage(buf_T *new_curbuf, int trigger_leave_autocmds);
static void enter_tabpage(tabpage_T *tp, buf_T *old_curbuf, int trigger_enter_autocmds, int trigger_leave_autocmds);
static void win_goto_ver(int up, long count);
static void win_goto_hor(int left, long count);
static void win_enter_ext(win_T *wp, int undo_sync, int curwin_invalid, int trigger_enter_autocmds, int trigger_leave_autocmds);
static win_T *win_alloc(win_T *after, int hidden);
static void win_free(win_T *wp, tabpage_T *tp);
static void frame_append(frame_T *after, frame_T *frp);
static void frame_insert(frame_T *before, frame_T *frp);
static void frame_remove(frame_T *frp);
static void frame_comp_pos(frame_T *topfrp, int *row, int *col);
static void frame_setheight(frame_T *curfrp, int height);
static void frame_setwidth(frame_T *curfrp, int width);
static void set_fraction(win_T *wp);
static void frame_add_height(frame_T *frp, int n);
static void last_status_rec(frame_T *fr, int statusline);
static void make_snapshot_rec(frame_T *fr, frame_T **frp);
static void clear_snapshot(tabpage_T *tp, int idx);
static void clear_snapshot_rec(frame_T *fr);
static int check_snapshot_rec(frame_T *sn, frame_T *fr);
static win_T *restore_snapshot_rec(frame_T *sn, frame_T *fr);
static int frame_check_height(frame_T *topfrp, int height);
static int frame_check_width(frame_T *topfrp, int width);
#include "func_attr.h"
