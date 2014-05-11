#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static char_u *get_buffcont(buffheader_T *buffer, int dozero);
static void add_buff(buffheader_T *buf, char_u *s, long slen);
static void add_num_buff(buffheader_T *buf, long n);
static void add_char_buff(buffheader_T *buf, int c);
static int read_readbuffers(int advance);
static int read_readbuf(buffheader_T *buf, int advance);
static void start_stuff(void);
static int read_redo(int init, int old_redo);
static void copy_redo(int old_redo);
static void init_typebuf(void);
static void gotchars(char_u *chars, int len);
static void may_sync_undo(void);
static void closescript(void);
static int vgetorpeek(int advance);
static void map_free(mapblock_T **mpp);
static void validate_maphash(void);
static void showmap(mapblock_T *mp, int local);
static char_u *eval_map_expr(char_u *str, int c);
static _Bool is_user_input(int k);
#include "func_attr.h"
