void ex_helpgrep(exarg_T *eap);
void ex_cexpr(exarg_T *eap);
void ex_cbuffer(exarg_T *eap);
int set_errorlist(win_T *wp, list_T *list, int action, char_u *title);
int get_errorlist(win_T *wp, list_T *list);
char_u *skip_vimgrep_pat(char_u *p, char_u **s, int *flags);
void ex_vimgrep(exarg_T *eap);
void ex_cfile(exarg_T *eap);
void ex_cnext(exarg_T *eap);
void ex_cc(exarg_T *eap);
void ex_make(exarg_T *eap);
int grep_internal(cmdidx_T cmdidx);
int buf_hide(buf_T *buf);
int bt_dontwrite_msg(buf_T *buf);
int bt_dontwrite(buf_T *buf);
int bt_nofile(buf_T *buf);
int bt_quickfix(buf_T *buf);
linenr_T qf_current_entry(win_T *wp);
void ex_copen(exarg_T *eap);
void ex_cclose(exarg_T *eap);
void ex_cwindow(exarg_T *eap);
void qf_mark_adjust(win_T *wp, linenr_T line1, linenr_T line2,
                    long amount,
                    long amount_after);
void qf_age(exarg_T *eap);
void qf_list(exarg_T *eap);
void qf_jump(qf_info_T *qi, int dir, int errornr, int forceit);
void copy_loclist(win_T *from, win_T *to);
void qf_free_all(win_T *wp);
int qf_init(win_T *wp, char_u *efile, char_u *errorformat, int newlist,
            char_u *qf_title);
