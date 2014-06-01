#ifndef NVIM_UI_H
#define NVIM_UI_H

/*
 * jump_to_mouse() returns one of first four these values, possibly with
 * some of the other three added.
 */
# define IN_UNKNOWN             0
# define IN_BUFFER              1
# define IN_STATUS_LINE         2       /* on status or command line */
# define IN_SEP_LINE            4       /* on vertical separator line */
# define IN_OTHER_WIN           8       /* in other window but can't go there */
# define CURSOR_MOVED           0x100
# define MOUSE_FOLD_CLOSE       0x200   /* clicked on '-' in fold column */
# define MOUSE_FOLD_OPEN        0x400   /* clicked on '+' in fold column */

/* flags for jump_to_mouse() */
# define MOUSE_FOCUS            0x01    /* need to stay in this window */
# define MOUSE_MAY_VIS          0x02    /* may start Visual mode */
# define MOUSE_DID_MOVE         0x04    /* only act when mouse has moved */
# define MOUSE_SETPOS           0x08    /* only set current mouse position */
# define MOUSE_MAY_STOP_VIS     0x10    /* may stop Visual mode */
# define MOUSE_RELEASED         0x20    /* button was released */

/* ui.c */
void ui_write(char_u *s, int len);
int ui_inchar(char_u *buf, int maxlen, long wtime, int tb_change_cnt);
int ui_char_avail(void);
void ui_delay(long msec, int ignoreinput);
void ui_suspend(void);
int ui_get_shellsize(void);
void ui_set_shellsize(int mustset);
void ui_breakcheck(void);
int vim_is_input_buf_full(void);
int vim_is_input_buf_empty(void);
char_u *get_input_buf(void);
void set_input_buf(char_u *p);
void add_to_input_buf(char_u *s, int len);
void add_to_input_buf_csi(char_u *str, int len);
void trash_input_buf(void);
int read_from_input_buf(char_u *buf, long maxlen);
void fill_input_buf(int exit_on_error);
void read_error_exit(void);
void ui_cursor_shape(void);
int check_col(int col);
int check_row(int row);
int jump_to_mouse(int flags, int *inclusive, int which_button);
int mouse_comp_pos(win_T *win, int *rowp, int *colp, linenr_T *lnump);
win_T *mouse_find_win(int *rowp, int *colp);
void im_save_status(long *psave);
#endif /* NVIM_UI_H */
