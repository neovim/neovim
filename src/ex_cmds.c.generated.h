#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int linelen(int *has_tab);
static int sort_compare(const void *s1, const void *s2);
static void do_filter(linenr_T line1, linenr_T line2, exarg_T *eap, char_u *cmd, int do_in, int do_out);
static int no_viminfo(void);
static char_u *viminfo_filename(char_u *file);
static void do_viminfo(FILE *fp_in, FILE *fp_out, int flags);
static int read_viminfo_up_to_marks(vir_T *virp, int forceit, int writing);
static int viminfo_encoding(vir_T *virp);
static int check_readonly(int *forceit, buf_T *buf);
static void delbuf_msg(char_u *name);
static int help_compare(const void *s1, const void *s2);
static void helptags_one(char_u *dir, char_u *ext, char_u *tagfname, int add_help_tags);
static int sign_cmd_idx(char_u *begin_cmd, char_u *end_cmd);
static void sign_list_defined(sign_T *sp);
static void sign_undefine(sign_T *sp, sign_T *sp_prev);
#include "func_attr.h"
