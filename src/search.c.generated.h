static int is_one_char(char_u *pattern);
static int find_prev_quote(char_u *line, int col_start, int quotechar,
                           char_u *escape);
static int find_next_quote(char_u *top_ptr, int col, int quotechar,
                           char_u *escape);
static int in_html_tag(int);
static void wvsp_one(FILE *fp, int idx, char *s, int sc);
static void show_pat_in_path(char_u *, int,
                             int, int, FILE *, linenr_T *, long);
static void findsent_forward(long count, int at_start_sent);
static void find_first_blank(pos_T *);
static void back_in_line(void);
static int skip_chars(int, int);
static int cls(void);
static int check_linecomment(char_u *line);
static int inmacro(char_u *, char_u *);
static int check_prevcol(char_u *linep, int col, int ch, int *prevcol);
static int first_submatch(regmmatch_T *rp);
static void set_vv_searchforward(void);
static void save_re_pat(int idx, char_u *pat, int magic);
