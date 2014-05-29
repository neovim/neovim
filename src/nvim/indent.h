#ifndef NVIM_INDENT_H
#define NVIM_INDENT_H
#include "nvim/vim.h"

/* flags for set_indent() */
#define SIN_CHANGED     1       /* call changed_bytes() when line changed */
#define SIN_INSERT      2       /* insert indent before existing text */
#define SIN_UNDO        4       /* save line for undo before changing it */


int get_indent(void);
int get_indent_lnum(linenr_T lnum);
int get_indent_buf(buf_T *buf, linenr_T lnum);
int get_indent_str(char_u *ptr, int ts);
int set_indent(int size, int flags);
int copy_indent(int size, char_u *src);
int get_number_indent(linenr_T lnum);
int inindent(int extra);
int get_expr_indent(void);
int get_lisp_indent(void);
#endif  // NVIM_INDENT_H
