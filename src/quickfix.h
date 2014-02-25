#ifndef NEOVIM_QUICKFIX_H
#define NEOVIM_QUICKFIX_H
/* quickfix.c */
int qf_init __ARGS((win_T *wp, char_u *efile, char_u *errorformat, int newlist,
                    char_u *qf_title));
void qf_free_all __ARGS((win_T *wp));
void copy_loclist __ARGS((win_T *from, win_T *to));
void qf_jump __ARGS((qf_info_T *qi, int dir, int errornr, int forceit));
void qf_list __ARGS((exarg_T *eap));
void qf_age __ARGS((exarg_T *eap));
void qf_mark_adjust __ARGS((win_T *wp, linenr_T line1, linenr_T line2,
                            long amount,
                            long amount_after));
void ex_cwindow __ARGS((exarg_T *eap));
void ex_cclose __ARGS((exarg_T *eap));
void ex_copen __ARGS((exarg_T *eap));
linenr_T qf_current_entry __ARGS((win_T *wp));
int bt_quickfix __ARGS((buf_T *buf));
int bt_nofile __ARGS((buf_T *buf));
int bt_dontwrite __ARGS((buf_T *buf));
int bt_dontwrite_msg __ARGS((buf_T *buf));
int buf_hide __ARGS((buf_T *buf));
int grep_internal __ARGS((cmdidx_T cmdidx));
void ex_make __ARGS((exarg_T *eap));
void ex_cc __ARGS((exarg_T *eap));
void ex_cnext __ARGS((exarg_T *eap));
void ex_cfile __ARGS((exarg_T *eap));
void ex_vimgrep __ARGS((exarg_T *eap));
char_u *skip_vimgrep_pat __ARGS((char_u *p, char_u **s, int *flags));
int get_errorlist __ARGS((win_T *wp, list_T *list));
int set_errorlist __ARGS((win_T *wp, list_T *list, int action, char_u *title));
void ex_cbuffer __ARGS((exarg_T *eap));
void ex_cexpr __ARGS((exarg_T *eap));
void ex_helpgrep __ARGS((exarg_T *eap));
/* vim: set ft=c : */
#endif /* NEOVIM_QUICKFIX_H */
