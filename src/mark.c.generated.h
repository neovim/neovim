#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void fname2fnum(xfmark_T *fm);
static void fmarks_check_one(xfmark_T *fm, char_u *name, buf_T *buf);
static char_u *mark_line(pos_T *mp, int lead_len);
static void show_one_mark(int c, char_u *arg, pos_T *p, char_u *name, int current);
static void cleanup_jumplist(void);
static void write_one_filemark(FILE *fp, xfmark_T *fm, int c1, int c2);
static void write_one_mark(FILE *fp_out, int c, pos_T *pos);
#include "func_attr.h"
