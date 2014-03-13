#ifndef NEOVIM_INDENT_C_H
#define NEOVIM_INDENT_C_H
#include "vim.h"
int cin_islabel(void);
int cin_iscase(char_u *s, int strict);
int cin_isscopedecl(char_u *s);
int cin_is_cinword(char_u *line);
int get_c_indent(void);
void do_c_expr_indent(void);
void parse_cino(buf_T *buf);
pos_T * find_start_comment(int ind_maxcomment);
#endif
