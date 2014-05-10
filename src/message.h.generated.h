int vim_dialog_yesnoallcancel(int type, char_u *title, char_u *message,
                              int dflt);
int vim_dialog_yesnocancel(int type, char_u *title, char_u *message,
                           int dflt);
int vim_dialog_yesno(int type, char_u *title, char_u *message, int dflt);
void display_confirm_msg(void);
int do_dialog(int type, char_u *title, char_u *message, char_u *buttons,
              int dfltbutton, char_u *textfield,
              int ex_cmd);
void msg_advance(int col);
void give_warning(char_u *message, int hl);
int verbose_open(void);
void verbose_stop(void);
void verbose_leave_scroll(void);
void verbose_enter_scroll(void);
void verbose_leave(void);
void verbose_enter(void);
int redirecting(void);
void msg_check(void);
int msg_end(void);
void msg_clr_cmdline(void);
void msg_clr_eos_force(void);
void msg_clr_eos(void);
void repeat_message(void);
void msg_moremsg(int full);
int msg_use_printf(void);
void msg_sb_eol(void);
void show_sb_text(void);
void clear_sb_text(void);
void may_clear_sb_text(void);
void msg_puts_attr(char_u *s, int attr);
void msg_puts_long_len_attr(char_u *longstr, int len, int attr);
void msg_puts_long_attr(char_u *longstr, int attr);
void msg_puts_title(char_u *s);
void msg_puts(char_u *s);
void msg_prt_line(char_u *s, int list);
void str2specialbuf(char_u *sp, char_u *buf, int len);
char_u *str2special(char_u **sp, int from);
char_u *str2special_save(char_u *str, int is_lhs);
int msg_outtrans_special(char_u *strstart, int from);
void msg_make(char_u *arg);
int msg_outtrans_len_attr(char_u *msgstr, int len, int attr);
char_u *msg_outtrans_one(char_u *p, int attr);
int msg_outtrans_len(char_u *str, int len);
int msg_outtrans_attr(char_u *str, int attr);
int msg_outtrans(char_u *str);
void msg_home_replace_hl(char_u *fname);
void msg_home_replace(char_u *fname);
void msg_outnum(long n);
void msg_putchar_attr(int c, int attr);
void msg_putchar(int c);
void msg_starthere(void);
void msg_start(void);
void set_keep_msg_from_hist(void);
void set_keep_msg(char_u *s, int attr);
void wait_return(int redraw);
void msg_end_prompt(void);
void ex_messages(exarg_T *eap);
int delete_first_msg(void);
char_u *msg_may_trunc(int force, char_u *s);
char_u *msg_trunc_attr(char_u *s, int force, int attr);
void emsg_invreg(int name);
int emsg2(char_u *s, char_u *a1);
int emsg(char_u *s);
int emsg_not_now(void);
void msg_source(int attr);
void reset_last_sourcing(void);
void trunc_string(char_u *s, char_u *buf, int room, int buflen);
char_u *msg_strtrunc(char_u *s, int force);
int msg_attr_keep(char_u *s, int attr, int keep);
int msg_attr(char_u *s, int attr);
int msg(char_u *s);
int verb_msg(char_u *s);
char_u *do_browse(int flags, char_u *title, char_u *dflt, char_u *ext,
                  char_u *initdir, char_u *filter,
                  buf_T *buf);
#ifdef USE_MCH_ERRMSG
void mch_errmsg(char *str);
void mch_msg(char *str);
#endif
