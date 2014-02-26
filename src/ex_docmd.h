#ifndef NEOVIM_EX_DOCMD_H
#define NEOVIM_EX_DOCMD_H
/* ex_docmd.c */
void do_exmode __ARGS((int improved));
int do_cmdline_cmd __ARGS((char_u *cmd));
int do_cmdline __ARGS((char_u *cmdline, char_u *
                       (*fgetline)(int, void *, int), void *cookie,
                       int flags));
int getline_equal __ARGS((char_u *
                          (*fgetline)(int, void *,
                                      int), void *cookie, char_u *
                          (*func)(int, void *,
                                  int)));
void *getline_cookie __ARGS((char_u *(*fgetline)(int, void *, int),
                             void *cookie));
int checkforcmd __ARGS((char_u **pp, char *cmd, int len));
int modifier_len __ARGS((char_u *cmd));
int cmd_exists __ARGS((char_u *name));
char_u *set_one_cmd_context __ARGS((expand_T *xp, char_u *buff));
char_u *skip_range __ARGS((char_u *cmd, int *ctx));
void ex_ni __ARGS((exarg_T *eap));
int expand_filename __ARGS((exarg_T *eap, char_u **cmdlinep, char_u **errormsgp));
void separate_nextcmd __ARGS((exarg_T *eap));
int ends_excmd __ARGS((int c));
char_u *find_nextcmd __ARGS((char_u *p));
char_u *check_nextcmd __ARGS((char_u *p));
char_u *get_command_name __ARGS((expand_T *xp, int idx));
void ex_comclear __ARGS((exarg_T *eap));
void uc_clear __ARGS((garray_T *gap));
char_u *get_user_commands __ARGS((expand_T *xp, int idx));
char_u *get_user_cmd_flags __ARGS((expand_T *xp, int idx));
char_u *get_user_cmd_nargs __ARGS((expand_T *xp, int idx));
char_u *get_user_cmd_complete __ARGS((expand_T *xp, int idx));
int parse_compl_arg __ARGS((char_u *value, int vallen, int *complp, long *argt,
                            char_u **compl_arg));
void not_exiting __ARGS((void));
void tabpage_close __ARGS((int forceit));
void tabpage_close_other __ARGS((tabpage_T *tp, int forceit));
void ex_all __ARGS((exarg_T *eap));
void handle_drop __ARGS((int filec, char_u **filev, int split));
void alist_clear __ARGS((alist_T *al));
void alist_init __ARGS((alist_T *al));
void alist_unlink __ARGS((alist_T *al));
void alist_new __ARGS((void));
void alist_expand __ARGS((int *fnum_list, int fnum_len));
void alist_set __ARGS((alist_T *al, int count, char_u **files, int use_curbuf,
                       int *fnum_list,
                       int fnum_len));
void alist_add __ARGS((alist_T *al, char_u *fname, int set_fnum));
void alist_slash_adjust __ARGS((void));
void ex_splitview __ARGS((exarg_T *eap));
void tabpage_new __ARGS((void));
void do_exedit __ARGS((exarg_T *eap, win_T *old_curwin));
void free_cd_dir __ARGS((void));
void post_chdir __ARGS((int local));
void ex_cd __ARGS((exarg_T *eap));
void do_sleep __ARGS((long msec));
int vim_mkdir_emsg __ARGS((char_u *name, int prot));
FILE *open_exfile __ARGS((char_u *fname, int forceit, char *mode));
void update_topline_cursor __ARGS((void));
void exec_normal_cmd __ARGS((char_u *cmd, int remap, int silent));
int find_cmdline_var __ARGS((char_u *src, int *usedlen));
char_u *eval_vars __ARGS((char_u *src, char_u *srcstart, int *usedlen,
                          linenr_T *lnump, char_u **errormsg,
                          int *escaped));
char_u *expand_sfile __ARGS((char_u *arg));
int put_eol __ARGS((FILE *fd));
int put_line __ARGS((FILE *fd, char *s));
void dialog_msg __ARGS((char_u *buff, char *format, char_u *fname));
char_u *get_behave_arg __ARGS((expand_T *xp, int idx));
/* vim: set ft=c : */
#endif /* NEOVIM_EX_DOCMD_H */
