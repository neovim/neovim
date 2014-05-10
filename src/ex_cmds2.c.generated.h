static char_u *get_one_sourceline(struct source_cookie *sp);
static void source_callback(char_u *fname, void *cookie);
static int alist_add_list(int count, char_u **files, int after);
static int editing_arg_idx(win_T *win);
static void alist_check_arg_idx(void);
static int do_arglist(char_u *str, int what, int after);
static char_u   *do_one_arg(char_u *str);
static void add_bufnum(int *bufnrs, int *bufnump, int nr);
static void script_dump_profile(FILE *fd);
static void script_do_profile(scriptitem_T *si);
static linenr_T debuggy_find(int file,char_u *fname, linenr_T after,
                             garray_T *gap,
                             int *fp);
static int dbg_parsearg(char_u *arg, garray_T *gap);
static void cmd_source(char_u *fname, exarg_T *eap);
