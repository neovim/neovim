#ifndef NEOVIM_MISC2_H
#define NEOVIM_MISC2_H

#include "func_attr.h"
#include "os/shell.h"

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
char_u *vim_strsave(char_u *string);
char_u *vim_strnsave(char_u *string, int len);
char_u *vim_strsave_escaped(char_u *string, char_u *esc_chars);
char_u *vim_strsave_escaped_ext(char_u *string, char_u *esc_chars,
                                int cc,
                                int bsl);
int csh_like_shell(void);
char_u *vim_strsave_shellescape(char_u *string, bool do_special, bool do_newline);
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
int call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg);
int get_real_state(void);
int vim_chdirfile(char_u *fname);
int illegal_slash(char *name);
int vim_chdir(char_u *new_dir);
void sort_strings(char_u **files, int count);
int emsg3(char_u *s, char_u *a1, char_u *a2);
int emsgn(char_u *s, int64_t n);
int get2c(FILE *fd);
int get3c(FILE *fd);
int get4c(FILE *fd);
time_t get8ctime(FILE *fd);
char_u *read_string(FILE *fd, int cnt);
int put_bytes(FILE *fd, long_u nr, int len);
void put_time(FILE *fd, time_t the_time);
int has_non_ascii(char_u *s);

#endif /* NEOVIM_MISC2_H */
