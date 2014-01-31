/* diff.c */
void diff_buf_delete __ARGS((buf_T *buf));
void diff_buf_adjust __ARGS((win_T *win));
void diff_buf_add __ARGS((buf_T *buf));
void diff_invalidate __ARGS((buf_T *buf));
void diff_mark_adjust __ARGS((linenr_T line1, linenr_T line2, long amount,
                              long amount_after));
void ex_diffupdate __ARGS((exarg_T *eap));
void ex_diffpatch __ARGS((exarg_T *eap));
void ex_diffsplit __ARGS((exarg_T *eap));
void ex_diffthis __ARGS((exarg_T *eap));
void diff_win_options __ARGS((win_T *wp, int addbuf));
void ex_diffoff __ARGS((exarg_T *eap));
void diff_clear __ARGS((tabpage_T *tp));
int diff_check __ARGS((win_T *wp, linenr_T lnum));
int diff_check_fill __ARGS((win_T *wp, linenr_T lnum));
void diff_set_topline __ARGS((win_T *fromwin, win_T *towin));
int diffopt_changed __ARGS((void));
int diffopt_horizontal __ARGS((void));
int diff_find_change __ARGS((win_T *wp, linenr_T lnum, int *startp, int *endp));
int diff_infold __ARGS((win_T *wp, linenr_T lnum));
void nv_diffgetput __ARGS((int put));
void ex_diffgetput __ARGS((exarg_T *eap));
int diff_mode_buf __ARGS((buf_T *buf));
int diff_move_to __ARGS((int dir, long count));
linenr_T diff_get_corresponding_line __ARGS((buf_T *buf1, linenr_T lnum1,
                                             buf_T *buf2,
                                             linenr_T lnum3));
linenr_T diff_lnum_win __ARGS((linenr_T lnum, win_T *wp));
/* vim: set ft=c : */
