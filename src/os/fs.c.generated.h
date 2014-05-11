#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static _Bool is_executable(const char_u *name);
static _Bool is_executable_in_path(const char_u *name);
#include "func_attr.h"
