char_u *script_get(exarg_T *eap, char_u *cmd);
int cmd_gchar(int offset);
void cmd_pchar(int c, int offset);
void write_viminfo_history(FILE *fp, int merge);
void finish_viminfo_history(void);
int read_viminfo_history(vir_T *virp, int writing);
void prepare_viminfo_history(int asklen, int writing);
void ex_history(exarg_T *eap);
int get_list_range(char_u **str, int *num1, int *num2);
void remove_key_from_history(void);
int del_history_idx(int histype, int idx);
int del_history_entry(int histype, char_u *str);
int clr_history(int histype);
char_u *get_history_entry(int histype, int idx);
int get_cmdline_type(void);
int set_cmdline_pos(int pos);
int get_cmdline_pos(void);
char_u *get_cmdline_str(void);
int get_history_idx(int histype);
void add_to_history(int histype, char_u *new_entry, int in_map, int sep);
int get_histtype(char_u *name);
void init_history(void);
char_u *globpath(char_u *path, char_u *file, int expand_options);
int ExpandGeneric(expand_T *xp, regmatch_T *regmatch, int *num_file,
                  char_u ***file, char_u *((*func)(expand_T *, int)),
                  int escaped);
int expand_cmdline(expand_T *xp, char_u *str, int col, int *matchcount,
                   char_u ***matches);
void set_cmd_context(expand_T *xp, char_u *str, int len, int col);
char_u *addstar(char_u *fname, int len, int context);
char_u *sm_gettail(char_u *s);
void tilde_replace(char_u *orig_pat, int num_files, char_u **files);
char_u *vim_strsave_fnameescape(char_u *fname, int shell);
void ExpandEscape(expand_T *xp, char_u *str, int numfiles, char_u *
                  *files,
                  int options);
void ExpandCleanup(expand_T *xp);
void ExpandInit(expand_T *xp);
char_u *ExpandOne(expand_T *xp, char_u *str, char_u *orig, int options,
                  int mode);
void gotocmdline(int clr);
void compute_cmdrow(void);
void redrawcmd(void);
void redrawcmdline(void);
void cmdline_paste_str(char_u *s, int literally);
void restore_cmdline_alloc(char_u *p);
char_u *save_cmdline_alloc(void);
int put_on_cmdline(char_u *str, int len, int redraw);
void unputcmdline(void);
void putcmdline(int c, int shift);
char_u *getexmodeline(int promptc, void *cookie, int indent);
char_u *getexline(int c, void *cookie, int indent);
int allbuf_locked(void);
int curbuf_locked(void);
void text_locked_msg(void);
int text_locked(void);
char_u *getcmdline_prompt(int firstc, char_u *prompt, int attr,
                          int xp_context,
                          char_u *xp_arg);
char_u *getcmdline(int firstc, long count, int indent);
void free_cmdline_buf(void);
