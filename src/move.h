#ifndef NEOVIM_MOVE_H
#define NEOVIM_MOVE_H
/* move.c */
void update_topline_redraw(void);
void update_topline(void);
void update_curswant(void);
void check_cursor_moved(win_T *wp);
void changed_window_setting(void);
void changed_window_setting_win(win_T *wp);
void set_topline(win_T *wp, linenr_T lnum);
void changed_cline_bef_curs(void);
void changed_cline_bef_curs_win(win_T *wp);
void changed_line_abv_curs(void);
void changed_line_abv_curs_win(win_T *wp);
void validate_botline(void);
void invalidate_botline(void);
void invalidate_botline_win(win_T *wp);
void approximate_botline_win(win_T *wp);
int cursor_valid(void);
void validate_cursor(void);
void validate_cline_row(void);
void validate_virtcol(void);
void validate_virtcol_win(win_T *wp);
void validate_cursor_col(void);
int win_col_off(win_T *wp);
int curwin_col_off(void);
int win_col_off2(win_T *wp);
int curwin_col_off2(void);
void curs_columns(int may_scroll);
void scrolldown(long line_count, int byfold);
void scrollup(long line_count, int byfold);
void check_topfill(win_T *wp, int down);
void scrolldown_clamp(void);
void scrollup_clamp(void);
void scroll_cursor_top(int min_scroll, int always);
void set_empty_rows(win_T *wp, int used);
void scroll_cursor_bot(int min_scroll, int set_topbot);
void scroll_cursor_halfway(int atend);
void cursor_correct(void);
int onepage(int dir, long count);
void halfpage(int flag, linenr_T Prenum);
void do_check_cursorbind(void);
/* vim: set ft=c : */
#endif /* NEOVIM_MOVE_H */
