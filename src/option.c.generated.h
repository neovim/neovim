#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void set_option_default(int opt_idx, int opt_flags, int compatible);
static void set_options_default(int opt_flags);
static char_u *term_bg_default(void);
static void did_set_option(int opt_idx, int opt_flags, int new_value);
static char_u *illegal_char(char_u *errbuf, int c);
static int string_to_key(char_u *arg);
static char_u *check_cedit(void);
static void did_set_title(int icon);
static char_u *option_expand(int opt_idx, char_u *val);
static void didset_options(void);
static void check_string_option(char_u **pp);
static long_u *insecure_flag(int opt_idx, int opt_flags);
static void redraw_titles(void);
static void set_string_option_global(int opt_idx, char_u **varp);
static char_u *set_string_option(int opt_idx, char_u *value, int opt_flags);
static char_u *did_set_string_option(int opt_idx, char_u **varp, int new_value_alloced, char_u *oldval, char_u *errbuf, int opt_flags);
static int int_cmp(const void *a, const void *b);
static char_u *set_chars_option(char_u **varp);
static char_u *compile_cap_prog(synblock_T *synblock);
static void set_option_scriptID_idx(int opt_idx, int opt_flags, int id);
static char_u *set_bool_option(int opt_idx, char_u *varp, int value, int opt_flags);
static char_u *set_num_option(int opt_idx, char_u *varp, long value, char_u *errbuf, size_t errbuflen, int opt_flags);
static void check_redraw(long_u flags);
static int findoption(char_u *arg);
static int find_key_option(char_u *arg);
static void showoptions(int all, int opt_flags);
static int optval_default(struct vimoption *p, char_u *varp);
static void showoneopt(struct vimoption *p, int opt_flags);
static int put_setstring(FILE *fd, char *cmd, char *name, char_u **valuep, int expand);
static int put_setnum(FILE *fd, char *cmd, char *name, long *valuep);
static int put_setbool(FILE *fd, char *cmd, char *name, int value);
static int istermoption(struct vimoption *p);
static char_u *get_varp_scope(struct vimoption *p, int opt_flags);
static char_u *get_varp(struct vimoption *p);
static void option_value2string(struct vimoption *opp, int opt_flags);
static int wc_use_keyname(char_u *varp, long *wcp);
static void langmap_set_entry(int from, int to);
static void langmap_init(void);
static void langmap_set(void);
static void paste_option_changed(void);
static void compatible_set(void);
static void fill_breakat_flags(void);
static int check_opt_strings(char_u *val, char **values, int list);
static int opt_strings_flags(char_u *val, char **values, unsigned *flagp, int list);
static int check_opt_wim(void);
#include "func_attr.h"
