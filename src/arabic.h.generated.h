#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
int arabic_shape(int c, int *ccp, int *c1p, int prev_c, int prev_c1, int next_c);
int arabic_combine(int one, int two);
int arabic_maycombine(int two);
#include "func_attr.h"
