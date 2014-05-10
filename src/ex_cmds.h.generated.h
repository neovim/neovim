void set_context_in_sign_cmd(expand_T *xp, char_u *arg);
char_u *get_sign_name(expand_T *xp, int idx);
char_u *sign_typenr2name(int typenr);
char_u *sign_get_text(int typenr);
int sign_get_attr(int typenr, int line);
void ex_sign(exarg_T *eap);
void ex_helptags(exarg_T *eap);
void ex_viusage(exarg_T *eap);
void ex_exusage(exarg_T *eap);
void fix_help_buffer(void);
int find_help_tags(char_u *arg, int *num_matches, char_u ***matches,
                           int keep_lang);
int help_heuristic(char_u *matched_string, int offset, int wrong_case);
char_u *check_help_lang(char_u *arg);
void ex_help(exarg_T *eap);
int prepare_tagpreview(int undo_sync);
void write_viminfo_sub_string(FILE *fp);
int read_viminfo_sub_string(vir_T *virp, int force);
void global_exe(char_u *cmd);
void ex_global(exarg_T *eap);
int do_sub_msg(int count_only);
void do_sub(exarg_T *eap);
int check_secure(void);
int check_restricted(void);
void ex_z(exarg_T *eap);
void ex_change(exarg_T *eap);
void ex_append(exarg_T *eap);
int do_ecmd(int fnum, char_u *ffname, char_u *sfname, exarg_T *eap,
                    linenr_T newlnum, int flags,
                    win_T *oldwin);
int getfile(int fnum, char_u *ffname, char_u *sfname, int setpm,
                    linenr_T lnum,
                    int forceit);
int not_writing(void);
void do_wqall(exarg_T *eap);
void ex_wnext(exarg_T *eap);
int check_overwrite(exarg_T *eap, buf_T *buf, char_u *fname, char_u *
                            ffname,
                            int other);
int do_write(exarg_T *eap);
void ex_write(exarg_T *eap);
void ex_update(exarg_T *eap);
void ex_file(exarg_T *eap);
int rename_buffer(char_u *new_fname);
void print_line(linenr_T lnum, int use_number, int list);
void print_line_no_prefix(linenr_T lnum, int use_number, int list);
void do_fixdel(exarg_T *eap);
void viminfo_writestring(FILE *fd, char_u *p);
char_u *viminfo_readstring(vir_T *virp, int off, int convert);
int viminfo_readline(vir_T *virp);
void write_viminfo(char_u *file, int forceit);
int read_viminfo(char_u *file, int flags);
int viminfo_error(char *errnum, char *message, char_u *line);
void append_redir(char_u *buf, int buflen, char_u *opt, char_u *fname);
char_u *make_filter_cmd(char_u *cmd, char_u *itmp, char_u *otmp);
void do_shell(char_u *cmd, int flags);
void do_bang(int addr_count, exarg_T *eap, int forceit, int do_in,
                     int do_out);
void ex_copy(linenr_T line1, linenr_T line2, linenr_T n);
int do_move(linenr_T line1, linenr_T line2, linenr_T dest);
void ex_retab(exarg_T *eap);
void ex_sort(exarg_T *eap);
void ex_align(exarg_T *eap);
void do_ascii(exarg_T *eap);
void free_signs(void);
void free_old_sub(void);
void free_prev_shellcmd(void);
