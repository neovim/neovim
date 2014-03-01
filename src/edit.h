#ifndef NEOVIM_EDIT_H
#define NEOVIM_EDIT_H
/* edit.c */
int edit(int cmdchar, int startln, long count);
void edit_putchar(int c, int highlight);
void edit_unputchar(void);
void display_dollar(colnr_T col);
void change_indent(int type, int amount, int round, int replaced,
                   int call_changed_bytes);
void truncate_spaces(char_u *line);
void backspace_until_column(int col);
int vim_is_ctrl_x_key(int c);
int ins_compl_add_infercase(char_u *str, int len, int icase,
                            char_u *fname, int dir,
                            int flags);
void set_completion(colnr_T startcol, list_T *list);
void ins_compl_show_pum(void);
char_u *find_word_start(char_u *ptr);
char_u *find_word_end(char_u *ptr);
int ins_compl_active(void);
int ins_compl_add_tv(typval_T *tv, int dir);
void ins_compl_check_keys(int frequency);
int get_literal(void);
void insertchar(int c, int flags, int second_indent);
void auto_format(int trailblank, int prev_line);
int comp_textwidth(int ff);
int stop_arrow(void);
void set_last_insert(int c);
void free_last_insert(void);
char_u *add_char2buf(int c, char_u *s);
void beginline(int flags);
int oneright(void);
int oneleft(void);
int cursor_up(long n, int upd_topline);
int cursor_down(long n, int upd_topline);
int stuff_inserted(int c, long count, int no_esc);
char_u *get_last_insert(void);
char_u *get_last_insert_save(void);
void replace_push(int c);
int replace_push_mb(char_u *p);
void fixthisline(int (*get_the_indent)(void));
void fix_indent(void);
int in_cinkeys(int keytyped, int when, int line_is_empty);
int hkmap(int c);
void ins_scroll(void);
void ins_horscroll(void);
int ins_copychar(linenr_T lnum);
/* vim: set ft=c : */
#endif /* NEOVIM_EDIT_H */
