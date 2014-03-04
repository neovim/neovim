#ifndef NEOVIM_NORMAL_H
#define NEOVIM_NORMAL_H
/* normal.c */
void init_normal_cmds(void);
void normal_cmd(oparg_T *oap, int toplevel);
void do_pending_operator(cmdarg_T *cap, int old_col, int gui_yank);
int do_mouse(oparg_T *oap, int c, int dir, long count, int fixindent);
void check_visual_highlight(void);
void end_visual_mode(void);
void reset_VIsual_and_resel(void);
void reset_VIsual(void);
int find_ident_under_cursor(char_u **string, int find_type);
int find_ident_at_pos(win_T *wp, linenr_T lnum, colnr_T startcol,
                      char_u **string,
                      int find_type);
void clear_showcmd(void);
int add_to_showcmd(int c);
void add_to_showcmd_c(int c);
void push_showcmd(void);
void pop_showcmd(void);
void do_check_scrollbind(int check);
void check_scrollbind(linenr_T topline_diff, long leftcol_diff);
int find_decl(char_u *ptr, int len, int locally, int thisblock,
              int searchflags);
void scroll_redraw(int up, long count);
void handle_tabmenu(void);
void do_nv_ident(int c1, int c2);
int get_visual_text(cmdarg_T *cap, char_u **pp, int *lenp);
void start_selection(void);
void may_start_select(int c);
/* vim: set ft=c : */
#endif /* NEOVIM_NORMAL_H */
