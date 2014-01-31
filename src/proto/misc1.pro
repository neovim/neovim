/* misc1.c */
int get_indent __ARGS((void));
int get_indent_lnum __ARGS((linenr_T lnum));
int get_indent_buf __ARGS((buf_T *buf, linenr_T lnum));
int get_indent_str __ARGS((char_u *ptr, int ts));
int set_indent __ARGS((int size, int flags));
int get_number_indent __ARGS((linenr_T lnum));
int open_line __ARGS((int dir, int flags, int second_line_indent));
int get_leader_len __ARGS((char_u *line, char_u **flags, int backward,
                           int include_space));
int get_last_leader_offset __ARGS((char_u *line, char_u **flags));
int plines __ARGS((linenr_T lnum));
int plines_win __ARGS((win_T *wp, linenr_T lnum, int winheight));
int plines_nofill __ARGS((linenr_T lnum));
int plines_win_nofill __ARGS((win_T *wp, linenr_T lnum, int winheight));
int plines_win_nofold __ARGS((win_T *wp, linenr_T lnum));
int plines_win_col __ARGS((win_T *wp, linenr_T lnum, long column));
int plines_m_win __ARGS((win_T *wp, linenr_T first, linenr_T last));
void ins_bytes __ARGS((char_u *p));
void ins_bytes_len __ARGS((char_u *p, int len));
void ins_char __ARGS((int c));
void ins_char_bytes __ARGS((char_u *buf, int charlen));
void ins_str __ARGS((char_u *s));
int del_char __ARGS((int fixpos));
int del_chars __ARGS((long count, int fixpos));
int del_bytes __ARGS((long count, int fixpos_arg, int use_delcombine));
int truncate_line __ARGS((int fixpos));
void del_lines __ARGS((long nlines, int undo));
int gchar_pos __ARGS((pos_T *pos));
int gchar_cursor __ARGS((void));
void pchar_cursor __ARGS((int c));
int inindent __ARGS((int extra));
char_u *skip_to_option_part __ARGS((char_u *p));
void changed __ARGS((void));
void changed_int __ARGS((void));
void changed_bytes __ARGS((linenr_T lnum, colnr_T col));
void appended_lines __ARGS((linenr_T lnum, long count));
void appended_lines_mark __ARGS((linenr_T lnum, long count));
void deleted_lines __ARGS((linenr_T lnum, long count));
void deleted_lines_mark __ARGS((linenr_T lnum, long count));
void changed_lines __ARGS((linenr_T lnum, colnr_T col, linenr_T lnume,
                           long xtra));
void unchanged __ARGS((buf_T *buf, int ff));
void check_status __ARGS((buf_T *buf));
void change_warning __ARGS((int col));
int ask_yesno __ARGS((char_u *str, int direct));
int is_mouse_key __ARGS((int c));
int get_keystroke __ARGS((void));
int get_number __ARGS((int colon, int *mouse_used));
int prompt_for_number __ARGS((int *mouse_used));
void msgmore __ARGS((long n));
void beep_flush __ARGS((void));
void vim_beep __ARGS((void));
void init_homedir __ARGS((void));
void free_homedir __ARGS((void));
void free_users __ARGS((void));
char_u *expand_env_save __ARGS((char_u *src));
char_u *expand_env_save_opt __ARGS((char_u *src, int one));
void expand_env __ARGS((char_u *src, char_u *dst, int dstlen));
void expand_env_esc __ARGS((char_u *srcp, char_u *dst, int dstlen, int esc,
                            int one,
                            char_u *startstr));
char_u *vim_getenv __ARGS((char_u *name, int *mustfree));
void vim_setenv __ARGS((char_u *name, char_u *val));
char_u *get_env_name __ARGS((expand_T *xp, int idx));
char_u *get_users __ARGS((expand_T *xp, int idx));
int match_user __ARGS((char_u *name));
void home_replace __ARGS((buf_T *buf, char_u *src, char_u *dst, int dstlen,
                          int one));
char_u *home_replace_save __ARGS((buf_T *buf, char_u *src));
int fullpathcmp __ARGS((char_u *s1, char_u *s2, int checkname));
char_u *gettail __ARGS((char_u *fname));
char_u *gettail_sep __ARGS((char_u *fname));
char_u *getnextcomp __ARGS((char_u *fname));
char_u *get_past_head __ARGS((char_u *path));
int vim_ispathsep __ARGS((int c));
int vim_ispathsep_nocolon __ARGS((int c));
int vim_ispathlistsep __ARGS((int c));
void shorten_dir __ARGS((char_u *str));
int dir_of_file_exists __ARGS((char_u *fname));
int vim_fnamecmp __ARGS((char_u *x, char_u *y));
int vim_fnamencmp __ARGS((char_u *x, char_u *y, size_t len));
char_u *concat_fnames __ARGS((char_u *fname1, char_u *fname2, int sep));
char_u *concat_str __ARGS((char_u *str1, char_u *str2));
void add_pathsep __ARGS((char_u *p));
char_u *FullName_save __ARGS((char_u *fname, int force));
pos_T *find_start_comment __ARGS((int ind_maxcomment));
void do_c_expr_indent __ARGS((void));
int cin_islabel __ARGS((void));
int cin_iscase __ARGS((char_u *s, int strict));
int cin_isscopedecl __ARGS((char_u *s));
void parse_cino __ARGS((buf_T *buf));
int get_c_indent __ARGS((void));
int get_expr_indent __ARGS((void));
int get_lisp_indent __ARGS((void));
void prepare_to_exit __ARGS((void));
void preserve_exit __ARGS((void));
int vim_fexists __ARGS((char_u *fname));
void line_breakcheck __ARGS((void));
void fast_breakcheck __ARGS((void));
int expand_wildcards_eval __ARGS((char_u **pat, int *num_file, char_u ***file,
                                  int flags));
int expand_wildcards __ARGS((int num_pat, char_u **pat, int *num_file, char_u *
                             **file,
                             int flags));
int match_suffix __ARGS((char_u *fname));
int unix_expandpath __ARGS((garray_T *gap, char_u *path, int wildoff, int flags,
                            int didstar));
void remove_duplicates __ARGS((garray_T *gap));
int gen_expand_wildcards __ARGS((int num_pat, char_u **pat, int *num_file,
                                 char_u ***file,
                                 int flags));
void addfile __ARGS((garray_T *gap, char_u *f, int flags));
char_u *get_cmd_output __ARGS((char_u *cmd, char_u *infile, int flags));
void FreeWild __ARGS((int count, char_u **files));
int goto_im __ARGS((void));
/* vim: set ft=c : */
