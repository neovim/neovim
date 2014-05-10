static int add_tag_field(dict_T *dict, char *field_name, char_u *start,
                         char_u *end);
static void found_tagfile_cb(char_u *fname, void *cookie);
static void prepare_pats(pat_T *pats, int has_re);
static int find_extra(char_u **pp);
static int test_for_current(char_u *, char_u *, char_u *, char_u *);
static char_u *expand_tag_fname(char_u *fname, char_u *tag_fname,
                                int expand);
static char_u *tag_full_fname(tagptrs_T *tagp);
static int parse_match(char_u *lbuf, tagptrs_T *tagp);
static int test_for_static(tagptrs_T *);
static int parse_tag_line(char_u *lbuf, tagptrs_T *tagp);
static int jumpto_tag(char_u *lbuf, int forceit, int keep_help);
static void taglen_advance(int l);
static int tag_strnicmp(char_u *s1, char_u *s2, size_t len);
