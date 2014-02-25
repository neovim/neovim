#ifndef NEOVIM_SCREEN_H
#define NEOVIM_SCREEN_H
/* screen.c */
void redraw_later __ARGS((int type));
void redraw_win_later __ARGS((win_T *wp, int type));
void redraw_later_clear __ARGS((void));
void redraw_all_later __ARGS((int type));
void redraw_curbuf_later __ARGS((int type));
void redraw_buf_later __ARGS((buf_T *buf, int type));
int redraw_asap __ARGS((int type));
void redrawWinline __ARGS((linenr_T lnum, int invalid));
void update_curbuf __ARGS((int type));
void update_screen __ARGS((int type));
int conceal_cursor_line __ARGS((win_T *wp));
void conceal_check_cursur_line __ARGS((void));
void update_single_line __ARGS((win_T *wp, linenr_T lnum));
void update_debug_sign __ARGS((buf_T *buf, linenr_T lnum));
void updateWindow __ARGS((win_T *wp));
void rl_mirror __ARGS((char_u *str));
void status_redraw_all __ARGS((void));
void status_redraw_curbuf __ARGS((void));
void redraw_statuslines __ARGS((void));
void win_redraw_last_status __ARGS((frame_T *frp));
void win_redr_status_matches __ARGS((expand_T *xp, int num_matches, char_u *
                                     *matches, int match,
                                     int showtail));
void win_redr_status __ARGS((win_T *wp));
int stl_connected __ARGS((win_T *wp));
int get_keymap_str __ARGS((win_T *wp, char_u *buf, int len));
void screen_putchar __ARGS((int c, int row, int col, int attr));
void screen_getbytes __ARGS((int row, int col, char_u *bytes, int *attrp));
void screen_puts __ARGS((char_u *text, int row, int col, int attr));
void screen_puts_len __ARGS((char_u *text, int len, int row, int col, int attr));
void screen_stop_highlight __ARGS((void));
void reset_cterm_colors __ARGS((void));
void screen_draw_rectangle __ARGS((int row, int col, int height, int width,
                                   int invert));
void screen_fill __ARGS((int start_row, int end_row, int start_col, int end_col,
                         int c1, int c2,
                         int attr));
void check_for_delay __ARGS((int check_msg_scroll));
int screen_valid __ARGS((int doclear));
void screenalloc __ARGS((int doclear));
void free_screenlines __ARGS((void));
void screenclear __ARGS((void));
int can_clear __ARGS((char_u *p));
void screen_start __ARGS((void));
void windgoto __ARGS((int row, int col));
void setcursor __ARGS((void));
int win_ins_lines __ARGS((win_T *wp, int row, int line_count, int invalid,
                          int mayclear));
int win_del_lines __ARGS((win_T *wp, int row, int line_count, int invalid,
                          int mayclear));
int screen_ins_lines __ARGS((int off, int row, int line_count, int end,
                             win_T *wp));
int screen_del_lines __ARGS((int off, int row, int line_count, int end,
                             int force,
                             win_T *wp));
int showmode __ARGS((void));
void unshowmode __ARGS((int force));
void get_trans_bufname __ARGS((buf_T *buf));
int redrawing __ARGS((void));
int messaging __ARGS((void));
void showruler __ARGS((int always));
int number_width __ARGS((win_T *wp));
int screen_screencol __ARGS((void));
int screen_screenrow __ARGS((void));
/* vim: set ft=c : */
#endif /* NEOVIM_SCREEN_H */
