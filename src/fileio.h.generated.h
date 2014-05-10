char_u *file_pat_to_reg_pat(char_u *pat, char_u *pat_end,
                            char *allow_dirs,
                            int no_bslash);
int match_file_list(char_u *list, char_u *sfname, char_u *ffname);
int match_file_pat(char_u *pattern, regprog_T *prog, char_u *fname,
                   char_u *sfname, char_u *tail,
                   int allow_dirs);
int au_exists(char_u *arg);
int autocmd_supported(char_u *name);
char_u *get_event_name(expand_T *xp, int idx);
char_u *set_context_in_autocmd(expand_T *xp, char_u *arg, int doautocmd);
char_u *get_augroup_name(expand_T *xp, int idx);
int has_autocmd(event_T event, char_u *sfname, buf_T *buf);
char_u *getnextac(int c, void *cookie, int indent);
void unblock_autocmds(void);
void block_autocmds(void);
int has_insertcharpre(void);
int has_textchangedI(void);
int has_textchanged(void);
int has_cursormovedI(void);
int has_cursormoved(void);
int trigger_cursorhold(void);
int has_cursorhold(void);
int apply_autocmds_retval(event_T event, char_u *fname, char_u *fname_io,
                          int force, buf_T *buf,
                          int *retval);
int apply_autocmds(event_T event, char_u *fname, char_u *fname_io,
                   int force,
                   buf_T *buf);
void aucmd_restbuf(aco_save_T *aco);
void aucmd_prepbuf(aco_save_T *aco, buf_T *buf);
int check_nomodeline(char_u **argp);
void ex_doautoall(exarg_T *eap);
int do_doautocmd(char_u *arg, int do_msg);
void do_autocmd(char_u *arg, int forceit);
void au_event_restore(char_u *old_ei);
char_u *au_event_disable(char *what);
int check_ei(void);
void do_augroup(char_u *arg, int del_group);
int au_has_group(char_u *name);
void aubuflocal_remove(buf_T *buf);
char_u *vim_tempname(int extra_char);
void vim_deltempdir(void);
void write_lnum_adjust(linenr_T offset);
void buf_store_time(buf_T *buf, struct stat *st, char_u *fname);
void buf_reload(buf_T *buf, int orig_mode);
int buf_check_timestamp(buf_T *buf, int focus);
int check_timestamps(int focus);
int vim_rename(char_u *from, char_u *to);
int vim_fgets(char_u *buf, int size, FILE *fp);
char_u *modname(char_u *fname, char_u *ext, int prepend_dot);
void shorten_fnames(int force);
void msg_add_lines(int insert_space, long lnum, off_t nchars);
void msg_add_fname(buf_T *buf, char_u *fname);
int buf_write(buf_T *buf, char_u *fname, char_u *sfname, linenr_T start,
              linenr_T end, exarg_T *eap, int append, int forceit,
              int reset_changed,
              int filtering);
char_u *prepare_crypt_write(buf_T *buf, int *lenp);
int prepare_crypt_read(FILE *fp);
void set_forced_fenc(exarg_T *eap);
void set_file_options(int set_options, exarg_T *eap);
void prep_exarg(exarg_T *eap, buf_T *buf);
int readfile(char_u *fname, char_u *sfname, linenr_T from,
             linenr_T lines_to_skip, linenr_T lines_to_read, exarg_T *eap,
             int flags);
void filemess(buf_T *buf, char_u *name, char_u *s, int attr);
void free_all_autocmds(void);
void forward_slash(char_u *fname);
int tag_fgets(char_u *buf, int size, FILE *fp);
long read_eintr(int fd, void *buf, size_t bufsize);
long write_eintr(int fd, void *buf, size_t bufsize);
