#ifndef NEOVIM_MISC1_H
#define NEOVIM_MISC1_H
/* misc1.c */
int open_line(int dir, int flags, int second_line_indent);
int get_leader_len(char_u *line, char_u **flags, int backward,
                   int include_space);
int get_last_leader_offset(char_u *line, char_u **flags);
int plines(linenr_T lnum);
int plines_win(win_T *wp, linenr_T lnum, int winheight);
int plines_nofill(linenr_T lnum);
int plines_win_nofill(win_T *wp, linenr_T lnum, int winheight);
int plines_win_nofold(win_T *wp, linenr_T lnum);
int plines_win_col(win_T *wp, linenr_T lnum, long column);
int plines_m_win(win_T *wp, linenr_T first, linenr_T last);
void ins_bytes(char_u *p);
void ins_bytes_len(char_u *p, int len);
void ins_char(int c);
void ins_char_bytes(char_u *buf, int charlen);
void ins_str(char_u *s);
int del_char(int fixpos);
int del_chars(long count, int fixpos);
int del_bytes(long count, int fixpos_arg, int use_delcombine);
int truncate_line(int fixpos);
void del_lines(long nlines, int undo);
int gchar_pos(pos_T *pos);
int gchar_cursor(void);
void pchar_cursor(int c);
int inindent(int extra);
char_u *skip_to_option_part(char_u *p);
void changed(void);
void changed_int(void);
void changed_bytes(linenr_T lnum, colnr_T col);
void appended_lines(linenr_T lnum, long count);
void appended_lines_mark(linenr_T lnum, long count);
void deleted_lines(linenr_T lnum, long count);
void deleted_lines_mark(linenr_T lnum, long count);
void changed_lines(linenr_T lnum, colnr_T col, linenr_T lnume,
                   long xtra);
void unchanged(buf_T *buf, int ff);
void check_status(buf_T *buf);
void change_warning(int col);
int ask_yesno(char_u *str, int direct);
int is_mouse_key(int c);
int get_keystroke(void);
int get_number(int colon, int *mouse_used);
int prompt_for_number(int *mouse_used);
void msgmore(long n);
void beep_flush(void);
void vim_beep(void);
void init_homedir(void);
void free_homedir(void);
void free_users(void);
char_u *expand_env_save(char_u *src);
char_u *expand_env_save_opt(char_u *src, int one);
void expand_env(char_u *src, char_u *dst, int dstlen);
void expand_env_esc(char_u *srcp, char_u *dst, int dstlen, int esc,
                    int one,
                    char_u *startstr);
char_u *vim_getenv(char_u *name, int *mustfree);
void vim_setenv(char_u *name, char_u *val);
char_u *get_env_name(expand_T *xp, int idx);
char_u *get_users(expand_T *xp, int idx);
int match_user(char_u *name);
void home_replace(buf_T *buf, char_u *src, char_u *dst, int dstlen,
                  int one);
char_u *home_replace_save(buf_T *buf, char_u *src);
int fullpathcmp(char_u *s1, char_u *s2, int checkname);
char_u *gettail(char_u *fname);
char_u *gettail_sep(char_u *fname);
char_u *getnextcomp(char_u *fname);
char_u *get_past_head(char_u *path);
int vim_ispathsep(int c);
int vim_ispathsep_nocolon(int c);
int vim_ispathlistsep(int c);
void shorten_dir(char_u *str);
int dir_of_file_exists(char_u *fname);
int vim_fnamecmp(char_u *x, char_u *y);
int vim_fnamencmp(char_u *x, char_u *y, size_t len);
char_u *concat_fnames(char_u *fname1, char_u *fname2, int sep);
char_u *concat_str(char_u *str1, char_u *str2);
void add_pathsep(char_u *p);
char_u *FullName_save(char_u *fname, int force);
pos_T *find_start_comment(int ind_maxcomment);
void do_c_expr_indent(void);
int cin_islabel(void);
int cin_iscase(char_u *s, int strict);
int cin_isscopedecl(char_u *s);
void parse_cino(buf_T *buf);
int get_c_indent(void);
int get_expr_indent(void);
int get_lisp_indent(void);
void prepare_to_exit(void);
void preserve_exit(void);
int vim_fexists(char_u *fname);
void line_breakcheck(void);
void fast_breakcheck(void);
int expand_wildcards_eval(char_u **pat, int *num_file, char_u ***file,
                          int flags);
int expand_wildcards(int num_pat, char_u **pat, int *num_file, char_u *
                     **file,
                     int flags);
int match_suffix(char_u *fname);
int unix_expandpath(garray_T *gap, char_u *path, int wildoff, int flags,
                    int didstar);
void remove_duplicates(garray_T *gap);
int gen_expand_wildcards(int num_pat, char_u **pat, int *num_file,
                         char_u ***file,
                         int flags);
void addfile(garray_T *gap, char_u *f, int flags);
char_u *get_cmd_output(char_u *cmd, char_u *infile, int flags);
void FreeWild(int count, char_u **files);
int goto_im(void);
/* vim: set ft=c : */
#endif /* NEOVIM_MISC1_H */
