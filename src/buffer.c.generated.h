static int chk_modeline(linenr_T, int);
static int wininfo_other_tab_diff(wininfo_T *wip);
static int empty_curbuf(int close_others, int forceit, int action);
static void insert_sign(buf_T *buf, signlist_T *prev, signlist_T *next, int id, linenr_T lnum, int typenr);
static void clear_wininfo(buf_T *buf);
static void free_buffer_stuff(buf_T *buf, int free_options);
static void free_buffer(buf_T *);
static int append_arg_number(win_T *wp, char_u *buf, int buflen, int add_file);
static int ti_change(char_u *str, char_u **last);
static int otherfile_buf(buf_T *buf, char_u *ffname,
#ifdef UNIX
                         struct stat *stp
#endif
                         );
static wininfo_T *find_wininfo(buf_T *buf, int skip_diff_buffer);
static void buflist_setfpos(buf_T *buf, win_T *win, linenr_T lnum,
                            colnr_T col, int copy_options);
static char_u   *fname_match(regprog_T *prog, char_u *name);
static char_u   *buflist_match(regprog_T *prog, buf_T *buf);
static int buf_same_ino(buf_T *buf, struct stat *stp);
static buf_T    *buflist_findname_stat(char_u *ffname, struct stat *st);
