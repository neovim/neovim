void find_mps_values(int *initc, int *findc, int *backwards,
                             int switchit);
long get_sts_value(void);
long get_sw_value(buf_T *buf);
int check_ff_value(char_u *p);
int file_ff_differs(buf_T *buf, int ignore_empty);
void save_file_ff(buf_T *buf);
int can_bs(int what);
void reset_option_was_set(char_u *name);
int option_was_set(char_u *name);
void change_compatible(int on);
void vimrc_found(char_u *fname, char_u *envname);
int shortmess(int x);
int has_format_option(int x);
int langmap_adjust_mb(int c);
int ExpandOldSetting(int *num_file, char_u ***file);
int ExpandSettings(expand_T *xp, regmatch_T *regmatch, int *num_file,
                           char_u ***file);
void set_context_in_set_cmd(expand_T *xp, char_u *arg, int opt_flags);
void set_imsearch_global(void);
void set_iminsert_global(void);
void reset_modifiable(void);
void buf_copy_options(buf_T *buf, int flags);
void clear_winopt(winopt_T *wop);
void check_winopt(winopt_T *wop);
void check_win_options(win_T *win);
void copy_winopt(winopt_T *from, winopt_T *to);
void win_copy_options(win_T *wp_from, win_T *wp_to);
char_u *get_equalprg(void);
void comp_col(void);
void set_term_defaults(void);
void free_one_termoption(char_u *var);
void free_termoptions(void);
void clear_termoptions(void);
int makefoldset(FILE *fd);
int makeset(FILE *fd, int opt_flags, int local_only);
char_u *get_encoding_default(void);
char_u *get_highlight_default(void);
char_u *get_term_code(char_u *tname);
char_u *set_option_value(char_u *name, long number, char_u *string,
                                 int opt_flags);
int get_option_value(char_u *name, long *numval, char_u **stringval,
                             int opt_flags);
char_u *check_stl_option(char_u *s);
char_u *check_colorcolumn(win_T *wp);
void set_string_option_direct(char_u *name, int opt_idx, char_u *val,
                                      int opt_flags,
                                      int set_sid);
int was_set_insecurely(char_u *opt, int opt_flags);
void set_term_option_alloced(char_u **p);
void clear_string_option(char_u **pp);
void free_string_option(char_u *p);
void check_buf_options(buf_T *buf);
void check_options(void);
char_u *find_viminfo_parameter(int type);
int get_viminfo_parameter(int type);
void set_options_bin(int oldval, int newval, int opt_flags);
int do_set(char_u *arg, int opt_flags);
void set_title_defaults(void);
void set_helplang_default(char_u *lang);
void set_init_3(void);
void set_init_2(void);
void set_number_default(char *name, long val);
void set_string_default(char *name, char_u *val);
void set_init_1(void);
void free_all_options(void);
