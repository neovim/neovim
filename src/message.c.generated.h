#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int other_sourcing_name(void);
static char_u *get_emsg_source(void);
static char_u *get_emsg_lnum(void);
static void add_msg_hist(char_u *s, int len, int attr);
static void hit_return_msg(void);
static void msg_home_replace_attr(char_u *fname, int attr);
static char_u *screen_puts_mbyte(char_u *s, int l, int attr);
static void msg_puts_attr_len(char_u *str, int maxlen, int attr);
static void msg_puts_display(char_u *str, int maxlen, int attr, int recurse);
static void msg_scroll_up(void);
static void inc_msg_scrolled(void);
static void store_sb_text(char_u **sb_str, char_u *s, int attr, int *sb_col, int finish);
static msgchunk_T *msg_sb_start(msgchunk_T *mps);
static msgchunk_T *disp_sb_line(int row, msgchunk_T *smp);
static void t_puts(int *t_col, char_u *t_s, char_u *s, int attr);
static void msg_puts_printf(char_u *str, int maxlen);
static int do_more_prompt(int typed_char);
static void msg_screen_putchar(int c, int attr);
static int msg_check_screen(void);
static void redir_write(char_u *str, int maxlen);
static int copy_char(char_u *from, char_u *to, int lowercase);
static char_u *msg_show_console_dialog(char_u *message, char_u *buttons, int dfltbutton);
#include "func_attr.h"
