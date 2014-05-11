#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static unsigned nr2hex(unsigned c);
static int win_chartabsize(win_T *wp, char_u *p, colnr_T col);
static int win_nolbr_chartabsize(win_T *wp, char_u *s, colnr_T col, int *headp);
#include "func_attr.h"
