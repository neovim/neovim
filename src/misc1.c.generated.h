#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void changedOneline(buf_T *buf, linenr_T lnum);
static void changed_lines_buf(buf_T *buf, linenr_T lnum, linenr_T lnume, long xtra);
static void changed_common(linenr_T lnum, colnr_T col, linenr_T lnume, long xtra);
static char_u *vim_version_dir(char_u *vimdir);
static char_u *remove_tail(char_u *p, char_u *pend, char_u *name);
static void init_users(void);
#include "func_attr.h"
