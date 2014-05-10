static void langmap_set_entry(int from, int to);
static void redraw_titles(void);
static int check_opt_wim(void);
static int check_opt_strings(char_u *val, char **values, int);
static int opt_strings_flags(char_u *val, char **values,
                             unsigned *flagp,
                             int list);
static void fill_breakat_flags(void);
static void compatible_set(void);
static void paste_option_changed(void);
static void langmap_set(void);
static void langmap_init(void);
static int wc_use_keyname(char_u *varp, long *wcp);
static void option_value2string(struct vimoption *, int opt_flags);
static char_u *get_varp(struct vimoption *);
static char_u *get_varp_scope(struct vimoption *p, int opt_flags);
static int istermoption(struct vimoption *);
static int put_setbool(FILE *fd, char *cmd, char *name, int value);
static int put_setnum(FILE *fd, char *cmd, char *name, long *valuep);
static int put_setstring(FILE *fd, char *cmd, char *name, char_u **valuep,
                         int expand);
static void showoneopt(struct vimoption *, int opt_flags);
static int optval_default(struct vimoption *, char_u *varp);
static void showoptions(int all, int opt_flags);
static int find_key_option(char_u *);
static int findoption(char_u *);
static void check_redraw(long_u flags);
static char_u *set_bool_option(int opt_idx, char_u *varp, int value,
                               int opt_flags);
static void set_option_scriptID_idx(int opt_idx, int opt_flags, int id);
static char_u *compile_cap_prog(synblock_T *synblock);
static int int_cmp(const void *a, const void *b);
static char_u *set_chars_option(char_u **varp);
static char_u *did_set_string_option(int opt_idx, char_u **varp,
                                     int new_value_alloced,
                                     char_u *oldval, char_u *errbuf,
                                     int opt_flags);
static char_u *set_string_option(int opt_idx, char_u *value,
                                 int opt_flags);
static void set_string_option_global(int opt_idx, char_u **varp);
static long_u *insecure_flag(int opt_idx, int opt_flags);
static void check_string_option(char_u **pp);
static void didset_options(void);
static char_u *option_expand(int opt_idx, char_u *val);
static void did_set_title(int icon);
static char_u *check_cedit(void);
static int string_to_key(char_u *arg);
static char_u *illegal_char(char_u *, int);
static void did_set_option(int opt_idx, int opt_flags, int new_value);
static char_u *term_bg_default(void);
static void set_options_default(int opt_flags);
static void set_option_default(int, int opt_flags, int compatible);
static char_u *set_num_option(int opt_idx, char_u *varp, long value,
                              char_u *errbuf, size_t errbuflen,
                              int opt_flags);
