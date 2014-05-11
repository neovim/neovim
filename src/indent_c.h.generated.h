#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
pos_T *find_start_comment(int ind_maxcomment);
int cin_is_cinword(char_u *line);
int cin_islabel(void);
int cin_iscase(char_u *s, int strict);
int cin_isscopedecl(char_u *s);
void parse_cino(buf_T *buf);
int get_c_indent(void);
void do_c_expr_indent(void);
#include "func_attr.h"
