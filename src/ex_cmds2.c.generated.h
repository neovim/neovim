#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int dbg_parsearg(char_u *arg, garray_T *gap);
static linenr_T debuggy_find(int file, char_u *fname, linenr_T after, garray_T *gap, int *fp);
static void script_do_profile(scriptitem_T *si);
static void script_dump_profile(FILE *fd);
static void add_bufnum(int *bufnrs, int *bufnump, int nr);
static char_u *do_one_arg(char_u *str);
static int do_arglist(char_u *str, int what, int after);
static void alist_check_arg_idx(void);
static int editing_arg_idx(win_T *win);
static int alist_add_list(int count, char_u **files, int after);
static void source_callback(char_u *fname, void *cookie);
static void cmd_source(char_u *fname, exarg_T *eap);
static char_u *get_one_sourceline(struct source_cookie *sp);
static char_u *get_mess_env(void);
static void init_locales(void);
static char_u **find_locales(void);
#include "func_attr.h"
