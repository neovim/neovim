#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
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
#include "func_attr.h"
