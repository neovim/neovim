#ifndef NEOVIM_MAIN_H
#define NEOVIM_MAIN_H
/* main.c */
void main_loop(int cmdwin, int noexmode);
void getout_preserve_modified(int exitval);
void getout(int exitval);
int process_env(char_u *env, int is_viminit);
void mainerr_arg_missing(char_u *str);
void time_push(void *tv_rel, void *tv_start);
void time_pop(void *tp);
void time_msg(char *mesg, void *tv_start);
void server_to_input_buf(char_u *str);
char_u *eval_client_expr_to_string(char_u *expr);
char_u *serverConvert(char_u *client_enc, char_u *data, char_u **tofree);
int toF_TyA(int c);
int fkmap(int c);
void conv_to_pvim(void);
void conv_to_pstd(void);
char_u *lrswap(char_u *ibuf);
char_u *lrFswap(char_u *cmdbuf, int len);
char_u *lrF_sub(char_u *ibuf);
int cmdl_fkmap(int c);
int F_isalpha(int c);
int F_isdigit(int c);
int F_ischar(int c);
void farsi_fkey(cmdarg_T *cap);
int arabic_shape(int c, int *ccp, int *c1p, int prev_c, int prev_c1,
                 int next_c);
/* vim: set ft=c : */
#endif /* NEOVIM_MAIN_H */
