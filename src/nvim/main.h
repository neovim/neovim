#ifndef NEOVIM_MAIN_H
#define NEOVIM_MAIN_H

#include "nvim/normal.h"

void main_loop(int cmdwin, int noexmode);
void getout(int exitval);
int process_env(char_u *env, int is_viminit);
void mainerr_arg_missing(char_u *str);
void time_push(void *tv_rel, void *tv_start);
void time_pop(void *tp);
void time_msg(char *mesg, void *tv_start);
char_u *eval_client_expr_to_string(char_u *expr);
char_u *serverConvert(char_u *client_enc, char_u *data, char_u **tofree);

#endif /* NEOVIM_MAIN_H */
