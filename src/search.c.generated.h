#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void save_re_pat(int idx, char_u *pat, int magic);
static void set_vv_searchforward(void);
static int first_submatch(regmmatch_T *rp);
static int check_prevcol(char_u *linep, int col, int ch, int *prevcol);
static int check_linecomment(char_u *line);
static int inmacro(char_u *opt, char_u *s);
static int cls(void);
static int skip_chars(int cclass, int dir);
static void back_in_line(void);
static void find_first_blank(pos_T *posp);
static void findsent_forward(long count, int at_start_sent);
static int in_html_tag(int end_tag);
static int find_next_quote(char_u *line, int col, int quotechar, char_u *escape);
static int find_prev_quote(char_u *line, int col_start, int quotechar, char_u *escape);
static int is_one_char(char_u *pattern);
static void show_pat_in_path(char_u *line, int type, int did_show, int action, FILE *fp, linenr_T *lnum, long count);
static void wvsp_one(FILE *fp, int idx, char *s, int sc);
#include "func_attr.h"
