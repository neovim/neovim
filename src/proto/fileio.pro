/* fileio.c */
void filemess __ARGS((buf_T *buf, char_u *name, char_u *s, int attr));
int readfile __ARGS((char_u *fname, char_u *sfname, linenr_T from,
                     linenr_T lines_to_skip, linenr_T lines_to_read, exarg_T *
                     eap,
                     int flags));
int prep_exarg __ARGS((exarg_T *eap, buf_T *buf));
void set_file_options __ARGS((int set_options, exarg_T *eap));
void set_forced_fenc __ARGS((exarg_T *eap));
int prepare_crypt_read __ARGS((FILE *fp));
char_u *prepare_crypt_write __ARGS((buf_T *buf, int *lenp));
int check_file_readonly __ARGS((char_u *fname, int perm));
int buf_write __ARGS((buf_T *buf, char_u *fname, char_u *sfname, linenr_T start,
                      linenr_T end, exarg_T *eap, int append, int forceit,
                      int reset_changed,
                      int filtering));
void msg_add_fname __ARGS((buf_T *buf, char_u *fname));
void msg_add_lines __ARGS((int insert_space, long lnum, off_t nchars));
char_u *shorten_fname1 __ARGS((char_u *full_path));
char_u *shorten_fname __ARGS((char_u *full_path, char_u *dir_name));
void shorten_fnames __ARGS((int force));
void shorten_filenames __ARGS((char_u **fnames, int count));
char_u *modname __ARGS((char_u *fname, char_u *ext, int prepend_dot));
char_u *buf_modname __ARGS((int shortname, char_u *fname, char_u *ext,
                            int prepend_dot));
int vim_fgets __ARGS((char_u *buf, int size, FILE *fp));
int tag_fgets __ARGS((char_u *buf, int size, FILE *fp));
int vim_rename __ARGS((char_u *from, char_u *to));
int check_timestamps __ARGS((int focus));
int buf_check_timestamp __ARGS((buf_T *buf, int focus));
void buf_reload __ARGS((buf_T *buf, int orig_mode));
void buf_store_time __ARGS((buf_T *buf, struct stat *st, char_u *fname));
void write_lnum_adjust __ARGS((linenr_T offset));
void vim_deltempdir __ARGS((void));
char_u *vim_tempname __ARGS((int extra_char));
void forward_slash __ARGS((char_u *fname));
void aubuflocal_remove __ARGS((buf_T *buf));
int au_has_group __ARGS((char_u *name));
void do_augroup __ARGS((char_u *arg, int del_group));
void free_all_autocmds __ARGS((void));
int check_ei __ARGS((void));
char_u *au_event_disable __ARGS((char *what));
void au_event_restore __ARGS((char_u *old_ei));
void do_autocmd __ARGS((char_u *arg, int forceit));
int do_doautocmd __ARGS((char_u *arg, int do_msg));
void ex_doautoall __ARGS((exarg_T *eap));
int check_nomodeline __ARGS((char_u **argp));
void aucmd_prepbuf __ARGS((aco_save_T *aco, buf_T *buf));
void aucmd_restbuf __ARGS((aco_save_T *aco));
int apply_autocmds __ARGS((event_T event, char_u *fname, char_u *fname_io,
                           int force,
                           buf_T *buf));
int apply_autocmds_retval __ARGS((event_T event, char_u *fname, char_u *
                                  fname_io, int force, buf_T *buf,
                                  int *retval));
int has_cursorhold __ARGS((void));
int trigger_cursorhold __ARGS((void));
int has_cursormoved __ARGS((void));
int has_cursormovedI __ARGS((void));
int has_textchanged __ARGS((void));
int has_textchangedI __ARGS((void));
int has_insertcharpre __ARGS((void));
void block_autocmds __ARGS((void));
void unblock_autocmds __ARGS((void));
int is_autocmd_blocked __ARGS((void));
char_u *getnextac __ARGS((int c, void *cookie, int indent));
int has_autocmd __ARGS((event_T event, char_u *sfname, buf_T *buf));
char_u *get_augroup_name __ARGS((expand_T *xp, int idx));
char_u *set_context_in_autocmd __ARGS((expand_T *xp, char_u *arg, int doautocmd));
char_u *get_event_name __ARGS((expand_T *xp, int idx));
int autocmd_supported __ARGS((char_u *name));
int au_exists __ARGS((char_u *arg));
int match_file_pat __ARGS((char_u *pattern, regprog_T *prog, char_u *fname,
                           char_u *sfname, char_u *tail,
                           int allow_dirs));
int match_file_list __ARGS((char_u *list, char_u *sfname, char_u *ffname));
char_u *file_pat_to_reg_pat __ARGS((char_u *pat, char_u *pat_end,
                                    char *allow_dirs,
                                    int no_bslash));
long read_eintr __ARGS((int fd, void *buf, size_t bufsize));
long write_eintr __ARGS((int fd, void *buf, size_t bufsize));
/* vim: set ft=c : */
