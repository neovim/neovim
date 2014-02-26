#ifndef NEOVIM_BUFFER_H
#define NEOVIM_BUFFER_H
/* buffer.c */
int open_buffer __ARGS((int read_stdin, exarg_T *eap, int flags));
int buf_valid __ARGS((buf_T *buf));
void close_buffer __ARGS((win_T *win, buf_T *buf, int action, int abort_if_last));
void buf_clear_file __ARGS((buf_T *buf));
void buf_freeall __ARGS((buf_T *buf, int flags));
void goto_buffer __ARGS((exarg_T *eap, int start, int dir, int count));
void handle_swap_exists __ARGS((buf_T *old_curbuf));
char_u *do_bufdel __ARGS((int command, char_u *arg, int addr_count,
                          int start_bnr, int end_bnr,
                          int forceit));
int do_buffer __ARGS((int action, int start, int dir, int count, int forceit));
void set_curbuf __ARGS((buf_T *buf, int action));
void enter_buffer __ARGS((buf_T *buf));
void do_autochdir __ARGS((void));
buf_T *buflist_new __ARGS((char_u *ffname, char_u *sfname, linenr_T lnum,
                           int flags));
void free_buf_options __ARGS((buf_T *buf, int free_p_ff));
int buflist_getfile __ARGS((int n, linenr_T lnum, int options, int forceit));
void buflist_getfpos __ARGS((void));
buf_T *buflist_findname_exp __ARGS((char_u *fname));
buf_T *buflist_findname __ARGS((char_u *ffname));
int buflist_findpat __ARGS((char_u *pattern, char_u *pattern_end, int unlisted,
                            int diffmode,
                            int curtab_only));
int ExpandBufnames __ARGS((char_u *pat, int *num_file, char_u ***file,
                           int options));
buf_T *buflist_findnr __ARGS((int nr));
char_u *buflist_nr2name __ARGS((int n, int fullname, int helptail));
void get_winopts __ARGS((buf_T *buf));
pos_T *buflist_findfpos __ARGS((buf_T *buf));
linenr_T buflist_findlnum __ARGS((buf_T *buf));
void buflist_list __ARGS((exarg_T *eap));
int buflist_name_nr __ARGS((int fnum, char_u **fname, linenr_T *lnum));
int setfname __ARGS((buf_T *buf, char_u *ffname, char_u *sfname, int message));
void buf_set_name __ARGS((int fnum, char_u *name));
void buf_name_changed __ARGS((buf_T *buf));
buf_T *setaltfname __ARGS((char_u *ffname, char_u *sfname, linenr_T lnum));
char_u *getaltfname __ARGS((int errmsg));
int buflist_add __ARGS((char_u *fname, int flags));
void buflist_slash_adjust __ARGS((void));
void buflist_altfpos __ARGS((win_T *win));
int otherfile __ARGS((char_u *ffname));
void buf_setino __ARGS((buf_T *buf));
void fileinfo __ARGS((int fullname, int shorthelp, int dont_truncate));
void col_print __ARGS((char_u *buf, size_t buflen, int col, int vcol));
void maketitle __ARGS((void));
void resettitle __ARGS((void));
void free_titles __ARGS((void));
int build_stl_str_hl __ARGS((win_T *wp, char_u *out, size_t outlen, char_u *fmt,
                             int use_sandbox, int fillchar, int maxwidth,
                             struct stl_hlrec *hltab,
                             struct stl_hlrec *tabtab));
void get_rel_pos __ARGS((win_T *wp, char_u *buf, int buflen));
char_u *fix_fname __ARGS((char_u *fname));
void fname_expand __ARGS((buf_T *buf, char_u **ffname, char_u **sfname));
char_u *alist_name __ARGS((aentry_T *aep));
void do_arg_all __ARGS((int count, int forceit, int keep_tabs));
void ex_buffer_all __ARGS((exarg_T *eap));
void do_modelines __ARGS((int flags));
int read_viminfo_bufferlist __ARGS((vir_T *virp, int writing));
void write_viminfo_bufferlist __ARGS((FILE *fp));
char_u *buf_spname __ARGS((buf_T *buf));
int find_win_for_buf __ARGS((buf_T *buf, win_T **wp, tabpage_T **tp));
void buf_addsign __ARGS((buf_T *buf, int id, linenr_T lnum, int typenr));
linenr_T buf_change_sign_type __ARGS((buf_T *buf, int markId, int typenr));
int buf_getsigntype __ARGS((buf_T *buf, linenr_T lnum, int type));
linenr_T buf_delsign __ARGS((buf_T *buf, int id));
int buf_findsign __ARGS((buf_T *buf, int id));
int buf_findsign_id __ARGS((buf_T *buf, linenr_T lnum));
int buf_findsigntype_id __ARGS((buf_T *buf, linenr_T lnum, int typenr));
int buf_signcount __ARGS((buf_T *buf, linenr_T lnum));
void buf_delete_signs __ARGS((buf_T *buf));
void buf_delete_all_signs __ARGS((void));
void sign_list_placed __ARGS((buf_T *rbuf));
void sign_mark_adjust __ARGS((linenr_T line1, linenr_T line2, long amount,
                              long amount_after));
void set_buflisted __ARGS((int on));
int buf_contents_changed __ARGS((buf_T *buf));
void wipe_buffer __ARGS((buf_T *buf, int aucmd));
/* vim: set ft=c : */
#endif /* NEOVIM_BUFFER_H */
