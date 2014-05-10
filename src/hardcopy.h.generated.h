void mch_print_set_fg(long_u fgcol);
void mch_print_set_bg(long_u bgcol);
void mch_print_set_font(int iBold, int iItalic, int iUnderline);
int mch_print_text_out(char_u *p, int len);
void mch_print_start_line(int margin, int page_line);
int mch_print_blank_page(void);
int mch_print_begin_page(char_u *str);
int mch_print_end_page(void);
void mch_print_end(prt_settings_T *psettings);
int mch_print_begin(prt_settings_T *psettings);
int mch_print_init(prt_settings_T *psettings, char_u *jobname,
                   int forceit);
void mch_print_cleanup(void);
void ex_hardcopy(exarg_T *eap);
int prt_get_unit(int idx);
int prt_use_number(void);
int prt_header_height(void);
char_u *parse_printmbfont(void);
char_u *parse_printoptions(void);
