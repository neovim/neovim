/* charset.c */
int init_chartab __ARGS((void));
int buf_init_chartab __ARGS((buf_T *buf, int global));
void trans_characters __ARGS((char_u *buf, int bufsize));
char_u *transstr __ARGS((char_u *s));
char_u *str_foldcase __ARGS((char_u *str, int orglen, char_u *buf, int buflen));
char_u *transchar __ARGS((int c));
char_u *transchar_byte __ARGS((int c));
void transchar_nonprint __ARGS((char_u *buf, int c));
void transchar_hex __ARGS((char_u *buf, int c));
int byte2cells __ARGS((int b));
int char2cells __ARGS((int c));
int ptr2cells __ARGS((char_u *p));
int vim_strsize __ARGS((char_u *s));
int vim_strnsize __ARGS((char_u *s, int len));
int chartabsize __ARGS((char_u *p, colnr_T col));
int linetabsize __ARGS((char_u *s));
int linetabsize_col __ARGS((int startcol, char_u *s));
int win_linetabsize __ARGS((win_T *wp, char_u *p, colnr_T len));
int vim_isIDc __ARGS((int c));
int vim_iswordc __ARGS((int c));
int vim_iswordc_buf __ARGS((int c, buf_T *buf));
int vim_iswordp __ARGS((char_u *p));
int vim_iswordp_buf __ARGS((char_u *p, buf_T *buf));
int vim_isfilec __ARGS((int c));
int vim_isfilec_or_wc __ARGS((int c));
int vim_isprintc __ARGS((int c));
int vim_isprintc_strict __ARGS((int c));
int lbr_chartabsize __ARGS((unsigned char *s, colnr_T col));
int lbr_chartabsize_adv __ARGS((char_u **s, colnr_T col));
int win_lbr_chartabsize __ARGS((win_T *wp, char_u *s, colnr_T col, int *headp));
int in_win_border __ARGS((win_T *wp, colnr_T vcol));
void getvcol __ARGS((win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor,
                     colnr_T *end));
colnr_T getvcol_nolist __ARGS((pos_T *posp));
void getvvcol __ARGS((win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor,
                      colnr_T *end));
void getvcols __ARGS((win_T *wp, pos_T *pos1, pos_T *pos2, colnr_T *left,
                      colnr_T *right));
char_u *skipwhite __ARGS((char_u *q));
char_u *skipdigits __ARGS((char_u *q));
char_u *skiphex __ARGS((char_u *q));
char_u *skiptodigit __ARGS((char_u *q));
char_u *skiptohex __ARGS((char_u *q));
int vim_isdigit __ARGS((int c));
int vim_isxdigit __ARGS((int c));
int vim_islower __ARGS((int c));
int vim_isupper __ARGS((int c));
int vim_toupper __ARGS((int c));
int vim_tolower __ARGS((int c));
char_u *skiptowhite __ARGS((char_u *p));
char_u *skiptowhite_esc __ARGS((char_u *p));
long getdigits __ARGS((char_u **pp));
int vim_isblankline __ARGS((char_u *lbuf));
void vim_str2nr __ARGS((char_u *start, int *hexp, int *len, int dooct,
                        int dohex, long *nptr,
                        unsigned long *unptr));
int hex2nr __ARGS((int c));
int hexhex2nr __ARGS((char_u *p));
int rem_backslash __ARGS((char_u *str));
void backslash_halve __ARGS((char_u *p));
char_u *backslash_halve_save __ARGS((char_u *p));
void ebcdic2ascii __ARGS((char_u *buffer, int len));
/* vim: set ft=c : */
