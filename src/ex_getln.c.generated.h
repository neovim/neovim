static int hist_type2char(int type, int use_question);
static struct cmdline_info *get_ccline_ptr(void);
static void * call_user_expand_func(user_expand_func_T user_expand_func,
                                    expand_T *xp, int *num_file,
                                    char_u ***file);
static void cleanup_help_tags(int num_file, char_u **file);
static int sort_func_compare(const void *s1, const void *s2);
static int ex_window(void);
static void clear_hist_entry(histentry_T *hisptr);
static int ExpandUserList(expand_T *xp, int *num_file, char_u ***file);
static int ExpandUserDefined(expand_T *xp, regmatch_T *regmatch,
                             int *num_file,
                             char_u ***file);
static char_u   *get_history_arg(expand_T *xp, int idx);
static int ExpandRTDir(char_u *pat, int *num_file, char_u ***file,
                               char *dirname[]);
static int expand_shellcmd(char_u *filepat, int *num_file,
                           char_u ***file,
                           int flagsarg);
static int expand_showtail(expand_T *xp);
static int ExpandFromContext(expand_T *xp, char_u *, int *, char_u ***, int);
static void set_expand_context(expand_T *xp);
static int showmatches(expand_T *xp, int wildmenu);
static void escape_fname(char_u **pp);
static int nextwild(expand_T *xp, int type, int options, int escape);
static int ccheck_abbr(int);
static void cursorcmd(void);
static void redrawcmdprompt(void);
static void cmdline_del(int from);
static int cmdline_paste(int regname, int literally, int remcr);
static void restore_cmdline(struct cmdline_info *ccp);
static void save_cmdline(struct cmdline_info *ccp);
static void draw_cmdline(int start, int len);
static int realloc_cmdbuff(int len);
static void alloc_cmdbuff(int len);
static void correct_cmdspos(int idx, int cells);
static void set_cmdspos_cursor(void);
static void set_cmdspos(void);
static int cmdline_charsize(int idx);
static int calc_hist_idx(int histype, int num);
static int in_history(int, char_u *, int, int, int);
static int hist_char2type(int c);
