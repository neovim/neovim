/* ex_getln.c */
char_u *getcmdline __ARGS((int firstc, long count, int indent));
char_u *getcmdline_prompt __ARGS((int firstc, char_u *prompt, int attr,
                                  int xp_context,
                                  char_u *xp_arg));
int text_locked __ARGS((void));
void text_locked_msg __ARGS((void));
int curbuf_locked __ARGS((void));
int allbuf_locked __ARGS((void));
char_u *getexline __ARGS((int c, void *cookie, int indent));
char_u *getexmodeline __ARGS((int promptc, void *cookie, int indent));
int cmdline_overstrike __ARGS((void));
int cmdline_at_end __ARGS((void));
colnr_T cmdline_getvcol_cursor __ARGS((void));
void free_cmdline_buf __ARGS((void));
void putcmdline __ARGS((int c, int shift));
void unputcmdline __ARGS((void));
int put_on_cmdline __ARGS((char_u *str, int len, int redraw));
char_u *save_cmdline_alloc __ARGS((void));
void restore_cmdline_alloc __ARGS((char_u *p));
void cmdline_paste_str __ARGS((char_u *s, int literally));
void redrawcmdline __ARGS((void));
void redrawcmd __ARGS((void));
void compute_cmdrow __ARGS((void));
void gotocmdline __ARGS((int clr));
char_u *ExpandOne __ARGS((expand_T *xp, char_u *str, char_u *orig, int options,
                          int mode));
void ExpandInit __ARGS((expand_T *xp));
void ExpandCleanup __ARGS((expand_T *xp));
void ExpandEscape __ARGS((expand_T *xp, char_u *str, int numfiles, char_u *
                          *files,
                          int options));
char_u *vim_strsave_fnameescape __ARGS((char_u *fname, int shell));
void tilde_replace __ARGS((char_u *orig_pat, int num_files, char_u **files));
char_u *sm_gettail __ARGS((char_u *s));
char_u *addstar __ARGS((char_u *fname, int len, int context));
void set_cmd_context __ARGS((expand_T *xp, char_u *str, int len, int col));
int expand_cmdline __ARGS((expand_T *xp, char_u *str, int col, int *matchcount,
                           char_u ***matches));
int ExpandGeneric __ARGS((expand_T *xp, regmatch_T *regmatch, int *num_file,
                          char_u ***file, char_u *((*func)(expand_T *, int)),
                          int escaped));
char_u *globpath __ARGS((char_u *path, char_u *file, int expand_options));
void init_history __ARGS((void));
int get_histtype __ARGS((char_u *name));
void add_to_history __ARGS((int histype, char_u *new_entry, int in_map, int sep));
int get_history_idx __ARGS((int histype));
char_u *get_cmdline_str __ARGS((void));
int get_cmdline_pos __ARGS((void));
int set_cmdline_pos __ARGS((int pos));
int get_cmdline_type __ARGS((void));
char_u *get_history_entry __ARGS((int histype, int idx));
int clr_history __ARGS((int histype));
int del_history_entry __ARGS((int histype, char_u *str));
int del_history_idx __ARGS((int histype, int idx));
void remove_key_from_history __ARGS((void));
int get_list_range __ARGS((char_u **str, int *num1, int *num2));
void ex_history __ARGS((exarg_T *eap));
void prepare_viminfo_history __ARGS((int asklen, int writing));
int read_viminfo_history __ARGS((vir_T *virp, int writing));
void finish_viminfo_history __ARGS((void));
void write_viminfo_history __ARGS((FILE *fp, int merge));
void cmd_pchar __ARGS((int c, int offset));
int cmd_gchar __ARGS((int offset));
char_u *script_get __ARGS((exarg_T *eap, char_u *cmd));
/* vim: set ft=c : */
