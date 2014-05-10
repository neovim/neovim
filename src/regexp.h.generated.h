long vim_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf,
                               linenr_T lnum, colnr_T col,
                               proftime_T *tm);
int vim_regexec(regmatch_T *rmp, char_u *line, colnr_T col);
void vim_regfree(regprog_T *prog);
regprog_T *vim_regcomp(char_u *expr_arg, int re_flags);
list_T *reg_submatch_list(int no);
char_u *reg_submatch(int no);
int vim_regsub_multi(regmmatch_T *rmp, linenr_T lnum, char_u *source,
                             char_u *dest, int copy, int magic,
                             int backslash);
int vim_regsub(regmatch_T *rmp, char_u *source, char_u *dest, int copy,
                       int magic,
                       int backslash);
char_u *regtilde(char_u *source, int magic);
void unref_extmatch(reg_extmatch_T *em);
reg_extmatch_T *ref_extmatch(reg_extmatch_T *em);
int vim_regcomp_had_eol(void);
char_u *skip_regexp(char_u *startp, int dirc, int magic, char_u **newp);
int re_multiline(regprog_T *prog);
void free_regexp_stuff(void);
int vim_regexec_nl(regmatch_T *rmp, char_u *line, colnr_T col);
