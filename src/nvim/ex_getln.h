#ifndef NVIM_EX_GETLN_H
#define NVIM_EX_GETLN_H

/* Values for nextwild() and ExpandOne().  See ExpandOne() for meaning. */
#define WILD_FREE               1
#define WILD_EXPAND_FREE        2
#define WILD_EXPAND_KEEP        3
#define WILD_NEXT               4
#define WILD_PREV               5
#define WILD_ALL                6
#define WILD_LONGEST            7
#define WILD_ALL_KEEP           8

#define WILD_LIST_NOTFOUND      1
#define WILD_HOME_REPLACE       2
#define WILD_USE_NL             4
#define WILD_NO_BEEP            8
#define WILD_ADD_SLASH          16
#define WILD_KEEP_ALL           32
#define WILD_SILENT             64
#define WILD_ESCAPE             128
#define WILD_ICASE              256

/*
 * There are four history tables:
 */
#define HIST_CMD        0       /* colon commands */
#define HIST_SEARCH     1       /* search commands */
#define HIST_EXPR       2       /* expressions (from entering = register) */
#define HIST_INPUT      3       /* input() lines */
#define HIST_DEBUG      4       /* debug commands */
#define HIST_COUNT      5       /* number of history tables */


/* ex_getln.c */
char_u *getcmdline(int firstc, long count, int indent);
char_u *getcmdline_prompt(int firstc, char_u *prompt, int attr,
                          int xp_context,
                          char_u *xp_arg);
int text_locked(void);
void text_locked_msg(void);
int curbuf_locked(void);
int allbuf_locked(void);
char_u *getexline(int c, void *cookie, int indent);
char_u *getexmodeline(int promptc, void *cookie, int indent);
void free_cmdline_buf(void);
void putcmdline(int c, int shift);
void unputcmdline(void);
void put_on_cmdline(char_u *str, int len, int redraw);
char_u *save_cmdline_alloc(void);
void restore_cmdline_alloc(char_u *p);
void cmdline_paste_str(char_u *s, int literally);
void redrawcmdline(void);
void redrawcmd(void);
void compute_cmdrow(void);
void gotocmdline(int clr);
char_u *ExpandOne(expand_T *xp, char_u *str, char_u *orig, int options,
                  int mode);
void ExpandInit(expand_T *xp);
void ExpandCleanup(expand_T *xp);
void ExpandEscape(expand_T *xp, char_u *str, int numfiles, char_u *
                  *files,
                  int options);
char_u *vim_strsave_fnameescape(char_u *fname, int shell);
void tilde_replace(char_u *orig_pat, int num_files, char_u **files);
char_u *sm_gettail(char_u *s);
char_u *addstar(char_u *fname, int len, int context);
void set_cmd_context(expand_T *xp, char_u *str, int len, int col);
int expand_cmdline(expand_T *xp, char_u *str, int col, int *matchcount,
                   char_u ***matches);
int ExpandGeneric(expand_T *xp, regmatch_T *regmatch, int *num_file,
                  char_u ***file, char_u *((*func)(expand_T *, int)),
                  int escaped);
char_u *globpath(char_u *path, char_u *file, int expand_options);
void init_history(void);
int get_histtype(char_u *name);
void add_to_history(int histype, char_u *new_entry, int in_map, int sep);
int get_history_idx(int histype);
char_u *get_cmdline_str(void);
int get_cmdline_pos(void);
int set_cmdline_pos(int pos);
int get_cmdline_type(void);
char_u *get_history_entry(int histype, int idx);
int clr_history(int histype);
int del_history_entry(int histype, char_u *str);
int del_history_idx(int histype, int idx);
void remove_key_from_history(void);
int get_list_range(char_u **str, int *num1, int *num2);
void ex_history(exarg_T *eap);
void prepare_viminfo_history(int asklen, int writing);
int read_viminfo_history(vir_T *virp, int writing);
void finish_viminfo_history(void);
void write_viminfo_history(FILE *fp, int merge);
void cmd_pchar(int c, int offset);
int cmd_gchar(int offset);
char_u *script_get(exarg_T *eap, char_u *cmd);

#endif /* NVIM_EX_GETLN_H */
