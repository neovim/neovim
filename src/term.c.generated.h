#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static struct builtin_term *find_builtin_term(char_u *term);
static void parse_builtin_tcap(char_u *term);
static void set_color_count(int nr);
static char_u *tgetent_error(char_u *tbuf, char_u *term);
static char_u *vim_tgetstr(char *s, char_u **pp);
static int term_is_builtin(char_u *name);
static int term_7to8bit(char_u *p);
static void out_char_nf(unsigned c);
static void term_color(char_u *s, int n);
static int get_long_from_buf(char_u *buf, long_u *val);
static int termcode_star(char_u *code, int len);
static void del_termcode_idx(int idx);
static void switch_to_8bit(void);
static void gather_termleader(void);
static void req_codes_from_term(void);
static void req_more_codes_from_term(void);
static void got_code_from_term(char_u *code, int len);
static void check_for_codes_from_term(void);
#include "func_attr.h"
