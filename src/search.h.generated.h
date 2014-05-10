void write_viminfo_search_pattern(FILE *fp);
int read_viminfo_search_pattern(vir_T *virp, int force);
void find_pattern_in_path(char_u *ptr, int dir, int len, int whole,
                          int skip_comments, int type, long count,
                          int action, linenr_T start_lnum,
                          linenr_T end_lnum);
int current_search(long count, int forward);
int current_quote(oparg_T *oap, long count, int include, int quotechar);
int current_par(oparg_T *oap, long count, int include, int type);
int current_tagblock(oparg_T *oap, long count_arg, int include);
int current_block(oparg_T *oap, long count, int include, int what,
                  int other);
int current_sent(oparg_T *oap, long count, int include);
int current_word(oparg_T *oap, long count, int include, int bigword);
int bckend_word(long count, int bigword, int eol);
int end_word(long count, int bigword, int stop, int empty);
int bck_word(long count, int bigword, int stop);
int fwd_word(long count, int bigword, int eol);
int startPS(linenr_T lnum, int para, int both);
int findpar(int *pincl, int dir, long count, int what, int both);
int findsent(int dir, long count);
void showmatch(int c);
pos_T *findmatchlimit(oparg_T *oap, int initc, int flags, int maxtravel);
pos_T *findmatch(oparg_T *oap, int initc);
int searchc(cmdarg_T *cap, int t_cmd);
int search_for_exact_line(buf_T *buf, pos_T *pos, int dir, char_u *pat);
int do_search(oparg_T *oap, int dirc, char_u *pat, long count,
              int options,
              proftime_T *tm);
void set_search_direction(int cdir);
int searchit(win_T *win, buf_T *buf, pos_T *pos, int dir, char_u *pat,
             long count, int options, int pat_use, linenr_T stop_lnum,
             proftime_T *tm);
void last_pat_prog(regmmatch_T *regmatch);
void set_last_search_pat(char_u *s, int idx, int magic, int setlast);
void reset_search_dir(void);
char_u *last_search_pat(void);
int pat_has_uppercase(char_u *pat);
int ignorecase(char_u *pat);
void restore_search_patterns(void);
void save_search_patterns(void);
char_u *reverse_text(char_u *s);
char_u *get_search_pat(void);
int search_regcomp(char_u *pat, int pat_save, int pat_use, int options,
                   regmmatch_T *regmatch);
void free_search_patterns(void);
int linewhite(linenr_T lnum);
