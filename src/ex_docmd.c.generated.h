static int ses_fname(FILE *fd, buf_T *buf, unsigned *flagp);
static int ses_put_fname(FILE *fd, char_u *name, unsigned *flagp);
static int ses_arglist(FILE *fd, char *cmd, garray_T *gap, int fullname,
                       unsigned *flagp);
static int ses_do_win(win_T *wp);
static int ses_do_frame(frame_T *fr);
static frame_T *ses_skipframe(frame_T *fr);
static int ses_win_rec(FILE *fd, frame_T *fr);
static int ses_winsizes(FILE *fd, int restore_size, win_T *tab_firstwin);
static char_u   *skip_grep_pat(exarg_T *eap);
static void restore_dbg_stuff(struct dbg_stuff *dsp);
static void save_dbg_stuff(struct dbg_stuff *dsp);
static void free_cmdlines(garray_T *gap);
static void store_loop_line(garray_T *gap, char_u *line);
static char_u   *get_loop_line(int c, void *cookie, int indent);
static void ex_folddo(exarg_T *eap);
static void ex_foldopen(exarg_T *eap);
static void ex_fold(exarg_T *eap);
static void ex_X(exarg_T *eap);
static void ex_match(exarg_T *eap);
static void ex_nohlsearch(exarg_T *eap);
static void ex_set(exarg_T *eap);
static void ex_digraphs(exarg_T *eap);
static void ex_setfiletype(exarg_T *eap);
static void ex_filetype(exarg_T *eap);
static void ex_behave(exarg_T *eap);
static void ex_viminfo(exarg_T *eap);
static char_u   *get_view_file(int c);
static void ex_loadview(exarg_T *eap);
static int put_view(FILE *fd, win_T *wp, int add_edit, unsigned *flagp,
                    int current_arg_idx);
static int makeopens(FILE *fd, char_u *dirnow);
static char_u   *arg_all(void);
static void ex_tag_cmd(exarg_T *eap, char_u *name);
static void ex_tag(exarg_T *eap);
static void ex_psearch(exarg_T *eap);
static void ex_findpat(exarg_T *eap);
static void ex_checkpath(exarg_T *eap);
static void ex_stopinsert(exarg_T *eap);
static void ex_startinsert(exarg_T *eap);
static void ex_normal(exarg_T *eap);
static char_u   *find_ucmd(exarg_T *eap, char_u *p, int *full,
                           expand_T *xp,
                           int *compl);
static char_u   *uc_fun_cmd(void);
static void ex_mark(exarg_T *eap);
static void ex_mkrc(exarg_T *eap);
static void close_redir(void);
static void ex_redrawstatus(exarg_T *eap);
static void ex_redraw(exarg_T *eap);
static void ex_redir(exarg_T *eap);
static void ex_later(exarg_T *eap);
static void ex_redo(exarg_T *eap);
static void ex_rundo(exarg_T *eap);
static void ex_wundo(exarg_T *eap);
static void ex_undo(exarg_T *eap);
static void ex_bang(exarg_T *eap);
static void ex_at(exarg_T *eap);
static void ex_join(exarg_T *eap);
static void ex_submagic(exarg_T *eap);
static void ex_copymove(exarg_T *eap);
static void ex_put(exarg_T *eap);
static void ex_operators(exarg_T *eap);
static void ex_wincmd(exarg_T *eap);
static void ex_winsize(exarg_T *eap);
static void do_exmap(exarg_T *eap, int isabbrev);
static void ex_sleep(exarg_T *eap);
static void ex_equal(exarg_T *eap);
static void ex_pwd(exarg_T *eap);
static void ex_read(exarg_T *eap);
static void ex_syncbind(exarg_T *eap);
static void ex_swapname(exarg_T *eap);
static void ex_nogui(exarg_T *eap);
static void ex_edit(exarg_T *eap);
static void ex_open(exarg_T *eap);
static void ex_find(exarg_T *eap);
static void ex_wrongmodifier(exarg_T *eap);
static void ex_mode(exarg_T *eap);
static void ex_recover(exarg_T *eap);
static void ex_preserve(exarg_T *eap);
static void ex_goto(exarg_T *eap);
static void ex_print(exarg_T *eap);
static void ex_exit(exarg_T *eap);
static void ex_stop(exarg_T *eap);
static void ex_hide(exarg_T *eap);
static void ex_pedit(exarg_T *eap);
static void ex_ptag(exarg_T *eap);
static void ex_pclose(exarg_T *eap);
static void ex_tabs(exarg_T *eap);
static void ex_tabmove(exarg_T *eap);
static void ex_tabnext(exarg_T *eap);
static void ex_tabonly(exarg_T *eap);
static void ex_tabclose(exarg_T *eap);
static void ex_stag(exarg_T *eap);
static void ex_resize(exarg_T *eap);
static void ex_only(exarg_T *eap);
static void ex_win_close(int forceit, win_T *win, tabpage_T *tp);
static void ex_close(exarg_T *eap);
static void ex_quit_all(exarg_T *eap);
static void ex_cquit(exarg_T *eap);
static void ex_quit(exarg_T *eap);
static void ex_colorscheme(exarg_T *eap);
static void ex_highlight(exarg_T *eap);
static char_u   *repl_cmdline(exarg_T *eap, char_u *src, int srclen,
                              char_u *repl,
                              char_u **cmdlinep);
static char_u   *replace_makeprg(exarg_T *eap, char_u *p,
                                 char_u **cmdlinep);
static void correct_range(exarg_T *eap);
static char_u   *invalid_range(exarg_T *eap);
static void ex_script_ni(exarg_T *eap);
static void get_flags(exarg_T *eap);
static linenr_T get_address(char_u **, int skip, int to_other_file);
static int check_more(int, int);
static int getargopt(exarg_T *eap);
static char_u   *skip_cmd_arg(char_u *p, int rembs);
static char_u   *getargcmd(char_u **);
static void ex_blast(exarg_T *eap);
static void ex_brewind(exarg_T *eap);
static void ex_bprevious(exarg_T *eap);
static void ex_bnext(exarg_T *eap);
static void ex_bmodified(exarg_T *eap);
static void ex_buffer(exarg_T *eap);
static void ex_bunload(exarg_T *eap);
static void ex_doautocmd(exarg_T *eap);
static void ex_autocmd(exarg_T *eap);
static void ex_abclear(exarg_T *eap);
static void ex_mapclear(exarg_T *eap);
static void ex_unmap(exarg_T *eap);
static void ex_map(exarg_T *eap);
static void ex_abbreviate(exarg_T *eap);
static char_u   *find_command(exarg_T *eap, int *full);
static void append_command(char_u *cmd);
static char_u   *do_one_cmd(char_u **, int, struct condstack *,
                            char_u *(*fgetline)(int, void *, int),
                            void *cookie);
static char_u *get_user_command_name(int idx);
static void ex_delcommand(exarg_T *eap);
static void ex_command(exarg_T *eap);
static void do_ucmd(exarg_T *eap);
static void ex_winpos(exarg_T *eap);
static size_t uc_check_code(char_u *code, size_t len, char_u *buf,
                            ucmd_T *cmd, exarg_T *eap, char_u **split_buf,
                            size_t *split_len);
static char_u   *uc_split_args(char_u *arg, size_t *lenp);
static int uc_scan_attr(char_u *attr, size_t len, long *argt, long *def,
                        int *flags, int *compl,
                        char_u **compl_arg);
static void uc_list(char_u *name, size_t name_len);
static int uc_add_command(char_u *name, size_t name_len, char_u *rep,
                                  long argt, long def, int flags, int compl,
                                  char_u *compl_arg,
                                  int force);
