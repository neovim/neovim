char_u *backslash_halve_save(char_u *p);
void backslash_halve(char_u *p);
int rem_backslash(char_u *str);
int hex2nr(int c);
void vim_str2nr(char_u *start, int *hexp, int *len, int dooct,
                int dohex, long *nptr,
                unsigned long *unptr);
int vim_isblankline(char_u *lbuf);
long getdigits(char_u **pp);
char_u *skiptowhite_esc(char_u *p);
char_u *skiptowhite(char_u *p);
int vim_tolower(int c);
int vim_toupper(int c);
int vim_isupper(int c);
int vim_islower(int c);
int vim_isxdigit(int c);
int vim_isdigit(int c);
char_u *skiptohex(char_u *q);
char_u *skiptodigit(char_u *q);
char_u *skiphex(char_u *q);
char_u *skipdigits(char_u *q);
char_u *skipwhite(char_u *q);
void getvcols(win_T *wp, pos_T *pos1, pos_T *pos2, colnr_T *left,
              colnr_T *right);
void getvvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor,
              colnr_T *end);
colnr_T getvcol_nolist(pos_T *posp);
void getvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor,
             colnr_T *end);
int in_win_border(win_T *wp, colnr_T vcol);
int win_lbr_chartabsize(win_T *wp, char_u *s, colnr_T col, int *headp);
int lbr_chartabsize_adv(char_u **s, colnr_T col);
int lbr_chartabsize(unsigned char *s, colnr_T col);
int vim_isprintc_strict(int c);
int vim_isprintc(int c);
int vim_isfilec_or_wc(int c);
int vim_isfilec(int c);
int vim_iswordp_buf(char_u *p, buf_T *buf);
int vim_iswordp(char_u *p);
int vim_iswordc_buf(int c, buf_T *buf);
int vim_iswordc(int c);
int vim_isIDc(int c);
int win_linetabsize(win_T *wp, char_u *p, colnr_T len);
int linetabsize_col(int startcol, char_u *s);
int linetabsize(char_u *s);
int vim_strnsize(char_u *s, int len);
int vim_strsize(char_u *s);
int ptr2cells(char_u *p);
int char2cells(int c);
int byte2cells(int b);
void transchar_hex(char_u *buf, int c);
void transchar_nonprint(char_u *buf, int c);
char_u *transchar_byte(int c);
char_u *transchar(int c);
char_u *str_foldcase(char_u *str, int orglen, char_u *buf, int buflen);
void trans_characters(char_u *buf, int bufsize);
int buf_init_chartab(buf_T *buf, int global);
int init_chartab(void);
int hexhex2nr(char_u *p);
int chartabsize(char_u *p, colnr_T col);
char_u *transstr(char_u *s);
