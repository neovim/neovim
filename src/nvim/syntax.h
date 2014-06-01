#ifndef NVIM_SYNTAX_H
#define NVIM_SYNTAX_H

#include "nvim/buffer_defs.h"

typedef int guicolor_T;

/*
 * Terminal highlighting attribute bits.
 * Attributes above HL_ALL are used for syntax highlighting.
 */
#define HL_NORMAL      0x00
#define HL_INVERSE     0x01
#define HL_BOLD        0x02
#define HL_ITALIC      0x04
#define HL_UNDERLINE   0x08
#define HL_UNDERCURL   0x10
#define HL_STANDOUT    0x20
#define HL_ALL         0x3f

#define HL_CONTAINED   0x01    /* not used on toplevel */
#define HL_TRANSP      0x02    /* has no highlighting	*/
#define HL_ONELINE     0x04    /* match within one line only */
#define HL_HAS_EOL     0x08    /* end pattern that matches with $ */
#define HL_SYNC_HERE   0x10    /* sync point after this item (syncing only) */
#define HL_SYNC_THERE  0x20    /* sync point at current line (syncing only) */
#define HL_MATCH       0x40    /* use match ID instead of item ID */
#define HL_SKIPNL      0x80    /* nextgroup can skip newlines */
#define HL_SKIPWHITE   0x100   /* nextgroup can skip white space */
#define HL_SKIPEMPTY   0x200   /* nextgroup can skip empty lines */
#define HL_KEEPEND     0x400   /* end match always kept */
#define HL_EXCLUDENL   0x800   /* exclude NL from match */
#define HL_DISPLAY     0x1000  /* only used for displaying, not syncing */
#define HL_FOLD        0x2000  /* define fold */
#define HL_EXTEND      0x4000  /* ignore a keepend */
#define HL_MATCHCONT   0x8000  /* match continued from previous line */
#define HL_TRANS_CONT  0x10000 /* transparent item without contains arg */
#define HL_CONCEAL     0x20000 /* can be concealed */
#define HL_CONCEALENDS 0x40000 /* can be concealed */

/* syntax.c */
void syntax_start(win_T *wp, linenr_T lnum);
void syn_stack_free_all(synblock_T *block);
void syn_stack_apply_changes(buf_T *buf);
void syntax_end_parsing(linenr_T lnum);
int syntax_check_changed(linenr_T lnum);
int get_syntax_attr(colnr_T col, int *can_spell, int keep_state);
void syntax_clear(synblock_T *block);
void reset_synblock(win_T *wp);
void ex_syntax(exarg_T *eap);
void ex_ownsyntax(exarg_T *eap);
int syntax_present(win_T *win);
void reset_expand_highlight(void);
void set_context_in_echohl_cmd(expand_T *xp, char_u *arg);
void set_context_in_syntax_cmd(expand_T *xp, char_u *arg);
char_u *get_syntax_name(expand_T *xp, int idx);
int syn_get_id(win_T *wp, long lnum, colnr_T col, int trans,
               int *spellp,
               int keep_state);
int get_syntax_info(int *seqnrp);
int syn_get_sub_char(void);
int syn_get_stack_item(int i);
int syn_get_foldlevel(win_T *wp, long lnum);
void ex_syntime(exarg_T *eap);
char_u *get_syntime_arg(expand_T *xp, int idx);
void init_highlight(int both, int reset);
int load_colors(char_u *name);
void do_highlight(char_u *line, int forceit, int init);
void free_highlight(void);
void restore_cterm_colors(void);
char_u *hl_get_font_name(void);
void clear_hl_tables(void);
int hl_combine_attr(int char_attr, int prim_attr);
attrentry_T *syn_gui_attr2entry(int attr);
int syn_attr2attr(int attr);
attrentry_T *syn_term_attr2entry(int attr);
attrentry_T *syn_cterm_attr2entry(int attr);
char_u *highlight_has_attr(int id, int flag, int modec);
char_u *highlight_color(int id, char_u *what, int modec);
int syn_name2id(char_u *name);
int highlight_exists(char_u *name);
char_u *syn_id2name(int id);
int syn_namen2id(char_u *linep, int len);
int syn_check_group(char_u *pp, int len);
int syn_id2attr(int hl_id);
int syn_get_final_id(int hl_id);
int highlight_changed(void);
void set_context_in_highlight_cmd(expand_T *xp, char_u *arg);
char_u *get_highlight_name(expand_T *xp, int idx);

#endif /* NVIM_SYNTAX_H */
