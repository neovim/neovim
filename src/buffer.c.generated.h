#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void free_buffer(buf_T *buf);
static void free_buffer_stuff(buf_T *buf, int free_options);
static void clear_wininfo(buf_T *buf);
static int empty_curbuf(int close_others, int forceit, int action);
static buf_T *buflist_findname_stat(char_u *ffname, struct stat *stp);
static char_u *buflist_match(regprog_T *prog, buf_T *buf);
static char_u *fname_match(regprog_T *prog, char_u *name);
static void buflist_setfpos(buf_T *buf, win_T *win, linenr_T lnum, colnr_T col, int copy_options);
static int wininfo_other_tab_diff(wininfo_T *wip);
static wininfo_T *find_wininfo(buf_T *buf, int skip_diff_buffer);
static int otherfile_buf(buf_T *buf, char_u *ffname, struct stat *stp);
static int buf_same_ino(buf_T *buf, struct stat *stp);
static int ti_change(char_u *str, char_u **last);
static int append_arg_number(win_T *wp, char_u *buf, int buflen, int add_file);
static int chk_modeline(linenr_T lnum, int flags);
static void insert_sign(buf_T *buf, signlist_T *prev, signlist_T *next, int id, linenr_T lnum, int typenr);
#include "func_attr.h"
