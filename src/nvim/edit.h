#ifndef NVIM_EDIT_H
#define NVIM_EDIT_H

#include "nvim/vim.h"

/*
 * Array indexes used for cptext argument of ins_compl_add().
 */
#define CPT_ABBR    0   /* "abbr" */
#define CPT_MENU    1   /* "menu" */
#define CPT_KIND    2   /* "kind" */
#define CPT_INFO    3   /* "info" */
#define CPT_COUNT   4   /* Number of entries */

/* Values for in_cinkeys() */
#define KEY_OPEN_FORW   0x101
#define KEY_OPEN_BACK   0x102
#define KEY_COMPLETE    0x103   /* end of completion */

/* Values for change_indent() */
#define INDENT_SET      1       /* set indent */
#define INDENT_INC      2       /* increase indent */
#define INDENT_DEC      3       /* decrease indent */

/* flags for beginline() */
#define BL_WHITE        1       /* cursor on first non-white in the line */
#define BL_SOL          2       /* use 'sol' option */
#define BL_FIX          4       /* don't leave cursor on a NUL */

/* flags for insertchar() */
#define INSCHAR_FORMAT  1       /* force formatting */
#define INSCHAR_DO_COM  2       /* format comments */
#define INSCHAR_CTRLV   4       /* char typed just after CTRL-V */
#define INSCHAR_NO_FEX  8       /* don't use 'formatexpr' */
#define INSCHAR_COM_LIST 16     /* format comments with list/2nd line indent */

/* direction for nv_mousescroll() and ins_mousescroll() */
#define MSCR_DOWN       0       /* DOWN must be FALSE */
#define MSCR_UP         1
#define MSCR_LEFT       -1
#define MSCR_RIGHT      -2

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
int ins_copychar(linenr_T lnum);

#endif /* NVIM_EDIT_H */
