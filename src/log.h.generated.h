#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
_Bool do_log(int log_level, const char *func_name, int line_num, const char *fmt, ...) FUNC_ATTR_UNUSED;
#include "func_attr.h"
