#ifndef NEOVIM_DIFF_H
#define NEOVIM_DIFF_H
/* diff.c */
void diff_buf_delete(buf_T *buf);
void diff_buf_adjust(win_T *win);
void diff_buf_add(buf_T *buf);
void diff_invalidate(buf_T *buf);
void diff_mark_adjust(linenr_T line1, linenr_T line2, long amount,
                      long amount_after);
void ex_diffupdate(exarg_T *eap);
void ex_diffpatch(exarg_T *eap);
void ex_diffsplit(exarg_T *eap);
void ex_diffthis(exarg_T *eap);
void diff_win_options(win_T *wp, int addbuf);
void ex_diffoff(exarg_T *eap);
void diff_clear(tabpage_T *tp);
int diff_check(win_T *wp, linenr_T lnum);
int diff_check_fill(win_T *wp, linenr_T lnum);
void diff_set_topline(win_T *fromwin, win_T *towin);
int diffopt_changed(void);
int diffopt_horizontal(void);
int diff_find_change(win_T *wp, linenr_T lnum, int *startp, int *endp);
int diff_infold(win_T *wp, linenr_T lnum);
void nv_diffgetput(int put);
void ex_diffgetput(exarg_T *eap);
int diff_mode_buf(buf_T *buf);
int diff_move_to(int dir, long count);
linenr_T diff_get_corresponding_line(buf_T *buf1, linenr_T lnum1,
                                     buf_T *buf2,
                                     linenr_T lnum3);
linenr_T diff_lnum_win(linenr_T lnum, win_T *wp);
/* vim: set ft=c : */
#endif /* NEOVIM_DIFF_H */
