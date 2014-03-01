#ifndef NEOVIM_REGEXP_H
#define NEOVIM_REGEXP_H
/* regexp.c */
int re_multiline(regprog_T *prog);
int re_lookbehind(regprog_T *prog);
char_u *skip_regexp(char_u *startp, int dirc, int magic, char_u **newp);
int vim_regcomp_had_eol(void);
void free_regexp_stuff(void);
reg_extmatch_T *ref_extmatch(reg_extmatch_T *em);
void unref_extmatch(reg_extmatch_T *em);
char_u *regtilde(char_u *source, int magic);
int vim_regsub(regmatch_T *rmp, char_u *source, char_u *dest, int copy,
                       int magic,
                       int backslash);
int vim_regsub_multi(regmmatch_T *rmp, linenr_T lnum, char_u *source,
                             char_u *dest, int copy, int magic,
                             int backslash);
char_u *reg_submatch(int no);
regprog_T *vim_regcomp(char_u *expr_arg, int re_flags);
void vim_regfree(regprog_T *prog);
int vim_regexec(regmatch_T *rmp, char_u *line, colnr_T col);
int vim_regexec_nl(regmatch_T *rmp, char_u *line, colnr_T col);
long vim_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf,
                               linenr_T lnum, colnr_T col,
                               proftime_T *tm);
/* vim: set ft=c : */
#endif /* NEOVIM_REGEXP_H */
