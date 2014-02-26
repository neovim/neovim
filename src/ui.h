#ifndef NEOVIM_UI_H
#define NEOVIM_UI_H
/* ui.c */
void ui_write __ARGS((char_u *s, int len));
void ui_inchar_undo __ARGS((char_u *s, int len));
int ui_inchar __ARGS((char_u *buf, int maxlen, long wtime, int tb_change_cnt));
int ui_char_avail __ARGS((void));
void ui_delay __ARGS((long msec, int ignoreinput));
void ui_suspend __ARGS((void));
void suspend_shell __ARGS((void));
int ui_get_shellsize __ARGS((void));
void ui_set_shellsize __ARGS((int mustset));
void ui_new_shellsize __ARGS((void));
void ui_breakcheck __ARGS((void));
void clip_init __ARGS((int can_use));
void clip_update_selection __ARGS((VimClipboard *clip));
void clip_own_selection __ARGS((VimClipboard *cbd));
void clip_lose_selection __ARGS((VimClipboard *cbd));
void clip_auto_select __ARGS((void));
int clip_isautosel_star __ARGS((void));
int clip_isautosel_plus __ARGS((void));
void clip_modeless __ARGS((int button, int is_click, int is_drag));
void clip_start_selection __ARGS((int col, int row, int repeated_click));
void clip_process_selection __ARGS((int button, int col, int row,
                                    int_u repeated_click));
void clip_may_redraw_selection __ARGS((int row, int col, int len));
void clip_clear_selection __ARGS((VimClipboard *cbd));
void clip_may_clear_selection __ARGS((int row1, int row2));
void clip_scroll_selection __ARGS((int rows));
void clip_copy_modeless_selection __ARGS((int both));
int clip_gen_own_selection __ARGS((VimClipboard *cbd));
void clip_gen_lose_selection __ARGS((VimClipboard *cbd));
void clip_gen_set_selection __ARGS((VimClipboard *cbd));
void clip_gen_request_selection __ARGS((VimClipboard *cbd));
int clip_gen_owner_exists __ARGS((VimClipboard *cbd));
int vim_is_input_buf_full __ARGS((void));
int vim_is_input_buf_empty __ARGS((void));
int vim_free_in_input_buf __ARGS((void));
int vim_used_in_input_buf __ARGS((void));
char_u *get_input_buf __ARGS((void));
void set_input_buf __ARGS((char_u *p));
void add_to_input_buf __ARGS((char_u *s, int len));
void add_to_input_buf_csi __ARGS((char_u *str, int len));
void push_raw_key __ARGS((char_u *s, int len));
void trash_input_buf __ARGS((void));
int read_from_input_buf __ARGS((char_u *buf, long maxlen));
void fill_input_buf __ARGS((int exit_on_error));
void read_error_exit __ARGS((void));
void ui_cursor_shape __ARGS((void));
int check_col __ARGS((int col));
int check_row __ARGS((int row));
void open_app_context __ARGS((void));
void x11_setup_atoms __ARGS((Display *dpy));
void x11_setup_selection __ARGS((Widget w));
void clip_x11_request_selection __ARGS((Widget myShell, Display *dpy,
                                        VimClipboard *cbd));
void clip_x11_lose_selection __ARGS((Widget myShell, VimClipboard *cbd));
int clip_x11_own_selection __ARGS((Widget myShell, VimClipboard *cbd));
void clip_x11_set_selection __ARGS((VimClipboard *cbd));
int clip_x11_owner_exists __ARGS((VimClipboard *cbd));
void yank_cut_buffer0 __ARGS((Display *dpy, VimClipboard *cbd));
int jump_to_mouse __ARGS((int flags, int *inclusive, int which_button));
int mouse_comp_pos __ARGS((win_T *win, int *rowp, int *colp, linenr_T *lnump));
win_T *mouse_find_win __ARGS((int *rowp, int *colp));
int get_fpos_of_mouse __ARGS((pos_T *mpos));
int vcol2col __ARGS((win_T *wp, linenr_T lnum, int vcol));
void ui_focus_change __ARGS((int in_focus));
void im_save_status __ARGS((long *psave));
/* vim: set ft=c : */
#endif /* NEOVIM_UI_H */
