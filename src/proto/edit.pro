/* edit.c */
int edit __ARGS((int cmdchar, int startln, long count));
void edit_putchar __ARGS((int c, int highlight));
void edit_unputchar __ARGS((void));
void display_dollar __ARGS((colnr_T col));
void change_indent __ARGS((int type, int amount, int round, int replaced,
                           int call_changed_bytes));
void truncate_spaces __ARGS((char_u *line));
void backspace_until_column __ARGS((int col));
int vim_is_ctrl_x_key __ARGS((int c));
int ins_compl_add_infercase __ARGS((char_u *str, int len, int icase, char_u *
                                    fname, int dir,
                                    int flags));
void set_completion __ARGS((colnr_T startcol, list_T *list));
void ins_compl_show_pum __ARGS((void));
char_u *find_word_start __ARGS((char_u *ptr));
char_u *find_word_end __ARGS((char_u *ptr));
int ins_compl_active __ARGS((void));
int ins_compl_add_tv __ARGS((typval_T *tv, int dir));
void ins_compl_check_keys __ARGS((int frequency));
int get_literal __ARGS((void));
void insertchar __ARGS((int c, int flags, int second_indent));
void auto_format __ARGS((int trailblank, int prev_line));
int comp_textwidth __ARGS((int ff));
int stop_arrow __ARGS((void));
void set_last_insert __ARGS((int c));
void free_last_insert __ARGS((void));
char_u *add_char2buf __ARGS((int c, char_u *s));
void beginline __ARGS((int flags));
int oneright __ARGS((void));
int oneleft __ARGS((void));
int cursor_up __ARGS((long n, int upd_topline));
int cursor_down __ARGS((long n, int upd_topline));
int stuff_inserted __ARGS((int c, long count, int no_esc));
char_u *get_last_insert __ARGS((void));
char_u *get_last_insert_save __ARGS((void));
void replace_push __ARGS((int c));
int replace_push_mb __ARGS((char_u *p));
void fixthisline __ARGS((int (*get_the_indent)(void)));
void fix_indent __ARGS((void));
int in_cinkeys __ARGS((int keytyped, int when, int line_is_empty));
int hkmap __ARGS((int c));
void ins_scroll __ARGS((void));
void ins_horscroll __ARGS((void));
int ins_copychar __ARGS((linenr_T lnum));
/* vim: set ft=c : */
