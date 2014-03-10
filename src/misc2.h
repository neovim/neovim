#ifndef NEOVIM_MISC2_H
#define NEOVIM_MISC2_H
/* misc2.c */
int virtual_active(void);
int getviscol(void);
int getviscol2(colnr_T col, colnr_T coladd);
int coladvance_force(colnr_T wcol);
int coladvance(colnr_T wcol);
int getvpos(pos_T *pos, colnr_T wcol);
int inc_cursor(void);
int inc(pos_T *lp);
int incl(pos_T *lp);
int dec_cursor(void);
int dec(pos_T *lp);
int decl(pos_T *lp);
linenr_T get_cursor_rel_lnum(win_T *wp, linenr_T lnum);
void check_cursor_lnum(void);
void check_cursor_col(void);
void check_cursor_col_win(win_T *win);
void check_cursor(void);
void adjust_cursor_col(void);
int leftcol_changed(void);
void vim_mem_profile_dump(void);
char_u *alloc(unsigned size);
char_u *alloc_clear(unsigned size);
char_u *alloc_check(unsigned size);
char_u *lalloc_clear(long_u size, int message);
char_u *lalloc(long_u size, int message);
void *mem_realloc(void *ptr, size_t size);
void do_outofmem_msg(long_u size);
void free_all_mem(void);
char_u *vim_strsave(char_u *string);
char_u *vim_strnsave(char_u *string, int len);
char_u *vim_strsave_escaped(char_u *string, char_u *esc_chars);
char_u *vim_strsave_escaped_ext(char_u *string, char_u *esc_chars,
                                int cc,
                                int bsl);
int csh_like_shell(void);
char_u *vim_strsave_shellescape(char_u *string, int do_special);
char_u *vim_strsave_up(char_u *string);
char_u *vim_strnsave_up(char_u *string, int len);
void vim_strup(char_u *p);
char_u *strup_save(char_u *orig);
void copy_spaces(char_u *ptr, size_t count);
void copy_chars(char_u *ptr, size_t count, int c);
void del_trailing_spaces(char_u *ptr);
void vim_strncpy(char_u *to, char_u *from, size_t len);
void vim_strcat(char_u *to, char_u *from, size_t tosize);
int copy_option_part(char_u **option, char_u *buf, int maxlen,
                     char *sep_chars);
void vim_free(void *x);
int vim_stricmp(char *s1, char *s2);
int vim_strnicmp(char *s1, char *s2, size_t len);
char_u *vim_strchr(char_u *string, int c);
char_u *vim_strbyte(char_u *string, int c);
char_u *vim_strrchr(char_u *string, int c);
int vim_isspace(int x);
int get_fileformat(buf_T *buf);
int get_fileformat_force(buf_T *buf, exarg_T *eap);
void set_fileformat(int t, int opt_flags);
int default_fileformat(void);
int call_shell(char_u *cmd, int opt);
int get_real_state(void);
int after_pathsep(char_u *b, char_u *p);
int same_directory(char_u *f1, char_u *f2);
int vim_chdirfile(char_u *fname);
int illegal_slash(char *name);
int vim_chdir(char_u *new_dir);
int get_user_name(char_u *buf, int len);
void sort_strings(char_u **files, int count);
int pathcmp(const char *p, const char *q, int maxlen);
int filewritable(char_u *fname);
int emsg3(char_u *s, char_u *a1, char_u *a2);
int emsgn(char_u *s, long n);
int get2c(FILE *fd);
int get3c(FILE *fd);
int get4c(FILE *fd);
time_t get8ctime(FILE *fd);
char_u *read_string(FILE *fd, int cnt);
int put_bytes(FILE *fd, long_u nr, int len);
void put_time(FILE *fd, time_t the_time);
int has_non_ascii(char_u *s);
/* vim: set ft=c : */
#endif /* NEOVIM_MISC2_H */
