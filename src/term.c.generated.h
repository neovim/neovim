static int termcode_star(char_u *code, int len);
static void out_char_nf(unsigned);
#ifndef HAVE_TGETENT
static char *tgoto(char *, int, int);
#endif
static void set_color_count(int nr);
static void switch_to_8bit(void);
static int term_7to8bit(char_u *p);
static int term_is_builtin(char_u *name);
static void del_termcode_idx(int idx);
static void check_for_codes_from_term(void);
static void got_code_from_term(char_u *code, int len);
static void req_more_codes_from_term(void);
static void req_codes_from_term(void);
static void gather_termleader(void);
static void term_color(char_u *s, int n);
static void parse_builtin_tcap(char_u *s);
static struct builtin_term *find_builtin_term(char_u *name);
static int get_long_from_buf(char_u *buf, long_u *val);
