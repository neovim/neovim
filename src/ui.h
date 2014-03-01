#ifndef NEOVIM_UI_H
#define NEOVIM_UI_H
/* ui.c */
void ui_write(char_u *s, int len);
void ui_inchar_undo(char_u *s, int len);
int ui_inchar(char_u *buf, int maxlen, long wtime, int tb_change_cnt);
int ui_char_avail(void);
void ui_delay(long msec, int ignoreinput);
void ui_suspend(void);
void suspend_shell(void);
int ui_get_shellsize(void);
void ui_set_shellsize(int mustset);
void ui_new_shellsize(void);
void ui_breakcheck(void);
void clip_init(int can_use);
void clip_update_selection(VimClipboard *clip);
void clip_own_selection(VimClipboard *cbd);
void clip_lose_selection(VimClipboard *cbd);
void clip_auto_select(void);
int clip_isautosel_star(void);
int clip_isautosel_plus(void);
void clip_modeless(int button, int is_click, int is_drag);
void clip_start_selection(int col, int row, int repeated_click);
void clip_process_selection(int button, int col, int row,
                            int_u repeated_click);
void clip_may_redraw_selection(int row, int col, int len);
void clip_clear_selection(VimClipboard *cbd);
void clip_may_clear_selection(int row1, int row2);
void clip_scroll_selection(int rows);
void clip_copy_modeless_selection(int both);
int clip_gen_own_selection(VimClipboard *cbd);
void clip_gen_lose_selection(VimClipboard *cbd);
void clip_gen_set_selection(VimClipboard *cbd);
void clip_gen_request_selection(VimClipboard *cbd);
int clip_gen_owner_exists(VimClipboard *cbd);
int vim_is_input_buf_full(void);
int vim_is_input_buf_empty(void);
int vim_free_in_input_buf(void);
int vim_used_in_input_buf(void);
char_u *get_input_buf(void);
void set_input_buf(char_u *p);
void add_to_input_buf(char_u *s, int len);
void add_to_input_buf_csi(char_u *str, int len);
void push_raw_key(char_u *s, int len);
void trash_input_buf(void);
int read_from_input_buf(char_u *buf, long maxlen);
void fill_input_buf(int exit_on_error);
void read_error_exit(void);
void ui_cursor_shape(void);
int check_col(int col);
int check_row(int row);
void open_app_context(void);
void x11_setup_atoms(Display *dpy);
void x11_setup_selection(Widget w);
void clip_x11_request_selection(Widget myShell, Display *dpy,
                                VimClipboard *cbd);
void clip_x11_lose_selection(Widget myShell, VimClipboard *cbd);
int clip_x11_own_selection(Widget myShell, VimClipboard *cbd);
void clip_x11_set_selection(VimClipboard *cbd);
int clip_x11_owner_exists(VimClipboard *cbd);
void yank_cut_buffer0(Display *dpy, VimClipboard *cbd);
int jump_to_mouse(int flags, int *inclusive, int which_button);
int mouse_comp_pos(win_T *win, int *rowp, int *colp, linenr_T *lnump);
win_T *mouse_find_win(int *rowp, int *colp);
int get_fpos_of_mouse(pos_T *mpos);
int vcol2col(win_T *wp, linenr_T lnum, int vcol);
void ui_focus_change(int in_focus);
void im_save_status(long *psave);
/* vim: set ft=c : */
#endif /* NEOVIM_UI_H */
