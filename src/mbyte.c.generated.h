#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int enc_canon_search(char_u *name);
static int dbcs_char2len(int c);
static int dbcs_char2bytes(int c, char_u *buf);
static int dbcs_ptr2len(char_u *p);
static int dbcs_ptr2len_len(char_u *p, int size);
static int intable(struct interval *table, size_t size, int c);
static int utf_ptr2cells_len(char_u *p, int size);
static int dbcs_ptr2cells_len(char_u *p, int size);
static int dbcs_char2cells(int c);
static int dbcs_ptr2char(char_u *p);
static int utf_safe_read_char_adv(char_u **s, size_t *n);
static int utf_convert(int a, convertStruct *table, int tableSize);
static int utf_strnicmp(char_u *s1, char_u *s2, size_t n1, size_t n2);
static int enc_alias_search(char_u *name);
static char_u *iconv_string(vimconv_T *vcp, char_u *str, int slen, int *unconvlenp, int *resultlenp);
static void *get_iconv_import_func(int hInst, const char *funcname);
#include "func_attr.h"
