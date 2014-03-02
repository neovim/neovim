#ifndef NEOVIM_INDENT_H
#define NEOVIM_INDENT_H
#include "vim.h"
int get_indent(void);
int get_indent_lnum(linenr_T lnum);
int get_indent_buf(buf_T *buf, linenr_T lnum);
int get_indent_str(char_u *ptr, int ts);
int set_indent(int size, int flags);
int copy_indent(int size, char_u *src);
int get_number_indent(linenr_T lnum);
#endif
