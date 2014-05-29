#ifndef NVIM_SEARCH_H
#define NVIM_SEARCH_H

/* Values for the find_pattern_in_path() function args 'type' and 'action': */
#define FIND_ANY        1
#define FIND_DEFINE     2
#define CHECK_PATH      3

#define ACTION_SHOW     1
#define ACTION_GOTO     2
#define ACTION_SPLIT    3
#define ACTION_SHOW_ALL 4
#define ACTION_EXPAND   5

/* Values for 'options' argument in do_search() and searchit() */
#define SEARCH_REV    0x01  /* go in reverse of previous dir. */
#define SEARCH_ECHO   0x02  /* echo the search command and handle options */
#define SEARCH_MSG    0x0c  /* give messages (yes, it's not 0x04) */
#define SEARCH_NFMSG  0x08  /* give all messages except not found */
#define SEARCH_OPT    0x10  /* interpret optional flags */
#define SEARCH_HIS    0x20  /* put search pattern in history */
#define SEARCH_END    0x40  /* put cursor at end of match */
#define SEARCH_NOOF   0x80  /* don't add offset to position */
#define SEARCH_START 0x100  /* start search without col offset */
#define SEARCH_MARK  0x200  /* set previous context mark */
#define SEARCH_KEEP  0x400  /* keep previous search pattern */
#define SEARCH_PEEK  0x800  /* peek for typed char, cancel search */

/* Values for flags argument for findmatchlimit() */
#define FM_BACKWARD     0x01    /* search backwards */
#define FM_FORWARD      0x02    /* search forwards */
#define FM_BLOCKSTOP    0x04    /* stop at start/end of block */
#define FM_SKIPCOMM     0x08    /* skip comments */




/* search.c */
int search_regcomp(char_u *pat, int pat_save, int pat_use, int options,
                   regmmatch_T *regmatch);
char_u *get_search_pat(void);
char_u *reverse_text(char_u *s);
void save_search_patterns(void);
void restore_search_patterns(void);
void free_search_patterns(void);
int ignorecase(char_u *pat);
int pat_has_uppercase(char_u *pat);
char_u *last_search_pat(void);
void reset_search_dir(void);
void set_last_search_pat(char_u *s, int idx, int magic, int setlast);
void last_pat_prog(regmmatch_T *regmatch);
int searchit(win_T *win, buf_T *buf, pos_T *pos, int dir, char_u *pat,
             long count, int options, int pat_use, linenr_T stop_lnum,
             proftime_T *tm);
void set_search_direction(int cdir);
int do_search(oparg_T *oap, int dirc, char_u *pat, long count,
              int options,
              proftime_T *tm);
int search_for_exact_line(buf_T *buf, pos_T *pos, int dir, char_u *pat);
int searchc(cmdarg_T *cap, int t_cmd);
pos_T *findmatch(oparg_T *oap, int initc);
pos_T *findmatchlimit(oparg_T *oap, int initc, int flags, int maxtravel);
void showmatch(int c);
int findsent(int dir, long count);
int findpar(int *pincl, int dir, long count, int what, int both);
int startPS(linenr_T lnum, int para, int both);
int fwd_word(long count, int bigword, int eol);
int bck_word(long count, int bigword, int stop);
int end_word(long count, int bigword, int stop, int empty);
int bckend_word(long count, int bigword, int eol);
int current_word(oparg_T *oap, long count, int include, int bigword);
int current_sent(oparg_T *oap, long count, int include);
int current_block(oparg_T *oap, long count, int include, int what,
                  int other);
int current_tagblock(oparg_T *oap, long count_arg, int include);
int current_par(oparg_T *oap, long count, int include, int type);
int current_quote(oparg_T *oap, long count, int include, int quotechar);
int current_search(long count, int forward);
int linewhite(linenr_T lnum);
void find_pattern_in_path(char_u *ptr, int dir, int len, int whole,
                          int skip_comments, int type, long count,
                          int action, linenr_T start_lnum,
                          linenr_T end_lnum);
int read_viminfo_search_pattern(vir_T *virp, int force);
void write_viminfo_search_pattern(FILE *fp);

#endif /* NVIM_SEARCH_H */
