#ifndef NVIM_MISC2_H
#define NVIM_MISC2_H

#include "nvim/func_attr.h"
#include "nvim/os/shell.h"

/* misc2.c */
int virtual_active(void);
int inc(pos_T *lp);
int incl(pos_T *lp);
int dec(pos_T *lp);
int decl(pos_T *lp);
int csh_like_shell(void);
int copy_option_part(char_u **option, char_u *buf, int maxlen,
                     char *sep_chars);
int get_fileformat(buf_T *buf);
int get_fileformat_force(buf_T *buf, exarg_T *eap);
void set_fileformat(int t, int opt_flags);
int default_fileformat(void);
int call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg);
int get_real_state(void);
int vim_chdirfile(char_u *fname);
int illegal_slash(char *name);
int vim_chdir(char_u *new_dir);
int emsg3(char_u *s, char_u *a1, char_u *a2);
int emsgn(char_u *s, int64_t n);
int emsgu(char_u *s, uint64_t n);
int get2c(FILE *fd);
int get3c(FILE *fd);
int get4c(FILE *fd);
time_t get8ctime(FILE *fd);
char_u *read_string(FILE *fd, int cnt);
int put_bytes(FILE *fd, long_u nr, int len);
void put_time(FILE *fd, time_t the_time);
int has_non_ascii(char_u *s);

#endif /* NVIM_MISC2_H */
