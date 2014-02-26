#ifndef NEOVIM_MOVE_H
#define NEOVIM_MOVE_H
/* move.c */
void update_topline_redraw __ARGS((void));
void update_topline __ARGS((void));
void update_curswant __ARGS((void));
void check_cursor_moved __ARGS((win_T *wp));
void changed_window_setting __ARGS((void));
void changed_window_setting_win __ARGS((win_T *wp));
void set_topline __ARGS((win_T *wp, linenr_T lnum));
void changed_cline_bef_curs __ARGS((void));
void changed_cline_bef_curs_win __ARGS((win_T *wp));
void changed_line_abv_curs __ARGS((void));
void changed_line_abv_curs_win __ARGS((win_T *wp));
void validate_botline __ARGS((void));
void invalidate_botline __ARGS((void));
void invalidate_botline_win __ARGS((win_T *wp));
void approximate_botline_win __ARGS((win_T *wp));
int cursor_valid __ARGS((void));
void validate_cursor __ARGS((void));
void validate_cline_row __ARGS((void));
void validate_virtcol __ARGS((void));
void validate_virtcol_win __ARGS((win_T *wp));
void validate_cursor_col __ARGS((void));
int win_col_off __ARGS((win_T *wp));
int curwin_col_off __ARGS((void));
int win_col_off2 __ARGS((win_T *wp));
int curwin_col_off2 __ARGS((void));
void curs_columns __ARGS((int may_scroll));
void scrolldown __ARGS((long line_count, int byfold));
void scrollup __ARGS((long line_count, int byfold));
void check_topfill __ARGS((win_T *wp, int down));
void scrolldown_clamp __ARGS((void));
void scrollup_clamp __ARGS((void));
void scroll_cursor_top __ARGS((int min_scroll, int always));
void set_empty_rows __ARGS((win_T *wp, int used));
void scroll_cursor_bot __ARGS((int min_scroll, int set_topbot));
void scroll_cursor_halfway __ARGS((int atend));
void cursor_correct __ARGS((void));
int onepage __ARGS((int dir, long count));
void halfpage __ARGS((int flag, linenr_T Prenum));
void do_check_cursorbind __ARGS((void));
/* vim: set ft=c : */
#endif /* NEOVIM_MOVE_H */
