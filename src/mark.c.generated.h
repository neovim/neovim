static void write_one_mark(FILE *fp_out, int c, pos_T *pos);
static void write_one_filemark(FILE *fp, xfmark_T *fm, int c1, int c2);
static void cleanup_jumplist(void);
static void show_one_mark(int, char_u *, pos_T *, char_u *, int current);
static char_u *mark_line(pos_T *mp, int lead_len);
static void fmarks_check_one(xfmark_T *fm, char_u *name, buf_T *buf);
static void fname2fnum(xfmark_T *fm);
