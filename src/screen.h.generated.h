int screen_screenrow(void);
int screen_screencol(void);
int number_width(win_T *wp);
void showruler(int always);
int messaging(void);
int redrawing(void);
void get_trans_bufname(buf_T *buf);
void unshowmode(int force);
int showmode(void);
int screen_del_lines(int off, int row, int line_count, int end,
                     int force,
                     win_T *wp);
int screen_ins_lines(int off, int row, int line_count, int end,
                     win_T *wp);
int win_del_lines(win_T *wp, int row, int line_count, int invalid,
                  int mayclear);
int win_ins_lines(win_T *wp, int row, int line_count, int invalid,
                  int mayclear);
void setcursor(void);
void windgoto(int row, int col);
void screen_start(void);
int can_clear(char_u *p);
void screenclear(void);
void free_screenlines(void);
void screenalloc(int doclear);
int screen_valid(int doclear);
void check_for_delay(int check_msg_scroll);
void screen_fill(int start_row, int end_row, int start_col, int end_col,
                 int c1, int c2,
                 int attr);
void screen_draw_rectangle(int row, int col, int height, int width,
                           int invert);
void reset_cterm_colors(void);
void screen_stop_highlight(void);
void screen_puts_len(char_u *text, int len, int row, int col, int attr);
void screen_puts(char_u *text, int row, int col, int attr);
void screen_getbytes(int row, int col, char_u *bytes, int *attrp);
void screen_putchar(int c, int row, int col, int attr);
int get_keymap_str(win_T *wp, char_u *buf, int len);
int stl_connected(win_T *wp);
void win_redr_status(win_T *wp);
void win_redr_status_matches(expand_T *xp, int num_matches, char_u *
                             *matches, int match,
                             int showtail);
void win_redraw_last_status(frame_T *frp);
void redraw_statuslines(void);
void status_redraw_curbuf(void);
void status_redraw_all(void);
void rl_mirror(char_u *str);
void update_debug_sign(buf_T *buf, linenr_T lnum);
void update_single_line(win_T *wp, linenr_T lnum);
void conceal_check_cursur_line(void);
int conceal_cursor_line(win_T *wp);
void update_screen(int type);
void update_curbuf(int type);
void redrawWinline(linenr_T lnum, int invalid);
int redraw_asap(int type);
void redraw_buf_later(buf_T *buf, int type);
void redraw_curbuf_later(int type);
void redraw_all_later(int type);
void redraw_later_clear(void);
void redraw_win_later(win_T *wp, int type);
void redraw_later(int type);
