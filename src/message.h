#ifndef NEOVIM_MESSAGE_H
#define NEOVIM_MESSAGE_H
/* message.c */
int msg(char_u *s);
int verb_msg(char_u *s);
int msg_attr(char_u *s, int attr);
int msg_attr_keep(char_u *s, int attr, int keep);
char_u *msg_strtrunc(char_u *s, int force);
void trunc_string(char_u *s, char_u *buf, int room, int buflen);
void reset_last_sourcing(void);
void msg_source(int attr);
int emsg_not_now(void);
int emsg(char_u *s);
int emsg2(char_u *s, char_u *a1);
void emsg_invreg(int name);
char_u *msg_trunc_attr(char_u *s, int force, int attr);
char_u *msg_may_trunc(int force, char_u *s);
int delete_first_msg(void);
void ex_messages(exarg_T *eap);
void msg_end_prompt(void);
void wait_return(int redraw);
void set_keep_msg(char_u *s, int attr);
void set_keep_msg_from_hist(void);
void msg_start(void);
void msg_starthere(void);
void msg_putchar(int c);
void msg_putchar_attr(int c, int attr);
void msg_outnum(long n);
void msg_home_replace(char_u *fname);
void msg_home_replace_hl(char_u *fname);
int msg_outtrans(char_u *str);
int msg_outtrans_attr(char_u *str, int attr);
int msg_outtrans_len(char_u *str, int len);
char_u *msg_outtrans_one(char_u *p, int attr);
int msg_outtrans_len_attr(char_u *msgstr, int len, int attr);
void msg_make(char_u *arg);
int msg_outtrans_special(char_u *strstart, int from);
char_u *str2special_save(char_u *str, int is_lhs);
char_u *str2special(char_u **sp, int from);
void str2specialbuf(char_u *sp, char_u *buf, int len);
void msg_prt_line(char_u *s, int list);
void msg_puts(char_u *s);
void msg_puts_title(char_u *s);
void msg_puts_long_attr(char_u *longstr, int attr);
void msg_puts_long_len_attr(char_u *longstr, int len, int attr);
void msg_puts_attr(char_u *s, int attr);
void may_clear_sb_text(void);
void clear_sb_text(void);
void show_sb_text(void);
void msg_sb_eol(void);
int msg_use_printf(void);
#ifdef USE_MCH_ERRMSG
void mch_errmsg(char *str);
void mch_msg(char *str);
#endif
void msg_moremsg(int full);
void repeat_message(void);
void msg_clr_eos(void);
void msg_clr_eos_force(void);
void msg_clr_cmdline(void);
int msg_end(void);
void msg_check(void);
int redirecting(void);
void verbose_enter(void);
void verbose_leave(void);
void verbose_enter_scroll(void);
void verbose_leave_scroll(void);
void verbose_stop(void);
int verbose_open(void);
void give_warning(char_u *message, int hl);
void msg_advance(int col);
int do_dialog(int type, char_u *title, char_u *message, char_u *buttons,
              int dfltbutton, char_u *textfield,
              int ex_cmd);
void display_confirm_msg(void);
int vim_dialog_yesno(int type, char_u *title, char_u *message, int dflt);
int vim_dialog_yesnocancel(int type, char_u *title, char_u *message,
                           int dflt);
int vim_dialog_yesnoallcancel(int type, char_u *title, char_u *message,
                              int dflt);
char_u *do_browse(int flags, char_u *title, char_u *dflt, char_u *ext,
                  char_u *initdir, char_u *filter,
                  buf_T *buf);
/* vim: set ft=c : */
#endif /* NEOVIM_MESSAGE_H */
