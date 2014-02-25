#ifndef NEOVIM_SYNTAX_H
#define NEOVIM_SYNTAX_H
/* syntax.c */
void syntax_start __ARGS((win_T *wp, linenr_T lnum));
void syn_stack_free_all __ARGS((synblock_T *block));
void syn_stack_apply_changes __ARGS((buf_T *buf));
void syntax_end_parsing __ARGS((linenr_T lnum));
int syntax_check_changed __ARGS((linenr_T lnum));
int get_syntax_attr __ARGS((colnr_T col, int *can_spell, int keep_state));
void syntax_clear __ARGS((synblock_T *block));
void reset_synblock __ARGS((win_T *wp));
void ex_syntax __ARGS((exarg_T *eap));
void ex_ownsyntax __ARGS((exarg_T *eap));
int syntax_present __ARGS((win_T *win));
void reset_expand_highlight __ARGS((void));
void set_context_in_echohl_cmd __ARGS((expand_T *xp, char_u *arg));
void set_context_in_syntax_cmd __ARGS((expand_T *xp, char_u *arg));
char_u *get_syntax_name __ARGS((expand_T *xp, int idx));
int syn_get_id __ARGS((win_T *wp, long lnum, colnr_T col, int trans,
                       int *spellp,
                       int keep_state));
int get_syntax_info __ARGS((int *seqnrp));
int syn_get_sub_char __ARGS((void));
int syn_get_stack_item __ARGS((int i));
int syn_get_foldlevel __ARGS((win_T *wp, long lnum));
void ex_syntime __ARGS((exarg_T *eap));
char_u *get_syntime_arg __ARGS((expand_T *xp, int idx));
void init_highlight __ARGS((int both, int reset));
int load_colors __ARGS((char_u *name));
void do_highlight __ARGS((char_u *line, int forceit, int init));
void free_highlight __ARGS((void));
void restore_cterm_colors __ARGS((void));
void set_normal_colors __ARGS((void));
char_u *hl_get_font_name __ARGS((void));
void hl_set_font_name __ARGS((char_u *font_name));
void hl_set_bg_color_name __ARGS((char_u *name));
void hl_set_fg_color_name __ARGS((char_u *name));
void clear_hl_tables __ARGS((void));
int hl_combine_attr __ARGS((int char_attr, int prim_attr));
attrentry_T *syn_gui_attr2entry __ARGS((int attr));
int syn_attr2attr __ARGS((int attr));
attrentry_T *syn_term_attr2entry __ARGS((int attr));
attrentry_T *syn_cterm_attr2entry __ARGS((int attr));
char_u *highlight_has_attr __ARGS((int id, int flag, int modec));
char_u *highlight_color __ARGS((int id, char_u *what, int modec));
long_u highlight_gui_color_rgb __ARGS((int id, int fg));
int syn_name2id __ARGS((char_u *name));
int highlight_exists __ARGS((char_u *name));
char_u *syn_id2name __ARGS((int id));
int syn_namen2id __ARGS((char_u *linep, int len));
int syn_check_group __ARGS((char_u *pp, int len));
int syn_id2attr __ARGS((int hl_id));
int syn_id2colors __ARGS((int hl_id, guicolor_T *fgp, guicolor_T *bgp));
int syn_get_final_id __ARGS((int hl_id));
void highlight_gui_started __ARGS((void));
int highlight_changed __ARGS((void));
void set_context_in_highlight_cmd __ARGS((expand_T *xp, char_u *arg));
char_u *get_highlight_name __ARGS((expand_T *xp, int idx));
void free_highlight_fonts __ARGS((void));
/* vim: set ft=c : */
#endif /* NEOVIM_SYNTAX_H */
