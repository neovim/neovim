#ifndef NVIM_EVAL_FUNCS_H
#define NVIM_EVAL_FUNCS_H


char_u *get_function_name(expand_T *xp, int idx);

char_u *get_expr_name(expand_T *xp, int idx);

char_u *get_user_func_name(expand_T *xp, int idx);
#endif
