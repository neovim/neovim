#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static FILE *open_log_file(void);
static _Bool do_log_to_file(FILE *log_file, int log_level, const char *func_name, int line_num, const char *fmt, ...);
static _Bool v_do_log_to_file(FILE *log_file, int log_level, const char *func_name, int line_num, const char *fmt, va_list args);
#include "func_attr.h"
