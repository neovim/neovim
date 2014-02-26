#ifndef NEOVIM_REGEXP_H
#define NEOVIM_REGEXP_H
/* regexp.c */
int re_multiline __ARGS((regprog_T *prog));
int re_lookbehind __ARGS((regprog_T *prog));
char_u *skip_regexp __ARGS((char_u *startp, int dirc, int magic, char_u **newp));
int vim_regcomp_had_eol __ARGS((void));
void free_regexp_stuff __ARGS((void));
reg_extmatch_T *ref_extmatch __ARGS((reg_extmatch_T *em));
void unref_extmatch __ARGS((reg_extmatch_T *em));
char_u *regtilde __ARGS((char_u *source, int magic));
int vim_regsub __ARGS((regmatch_T *rmp, char_u *source, char_u *dest, int copy,
                       int magic,
                       int backslash));
int vim_regsub_multi __ARGS((regmmatch_T *rmp, linenr_T lnum, char_u *source,
                             char_u *dest, int copy, int magic,
                             int backslash));
char_u *reg_submatch __ARGS((int no));
regprog_T *vim_regcomp __ARGS((char_u *expr_arg, int re_flags));
void vim_regfree __ARGS((regprog_T *prog));
int vim_regexec __ARGS((regmatch_T *rmp, char_u *line, colnr_T col));
int vim_regexec_nl __ARGS((regmatch_T *rmp, char_u *line, colnr_T col));
long vim_regexec_multi __ARGS((regmmatch_T *rmp, win_T *win, buf_T *buf,
                               linenr_T lnum, colnr_T col,
                               proftime_T *tm));
/* vim: set ft=c : */
#endif /* NEOVIM_REGEXP_H */
