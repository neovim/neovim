static void ins_bs_one(colnr_T *vcolp);
static void expand_by_function(int type, char_u *base);
static char_u *do_insert_char_pre(int c);
static colnr_T get_nolist_virtcol(void);
static void ins_try_si(int c);
static int ins_ctrl_ey(int tc);
static int ins_digraph(void);
static int ins_eol(int c);
static int ins_tab(void);
static void ins_pagedown(void);
static void ins_down(int startcol);
static void ins_pageup(void);
static void ins_up(int startcol);
static void ins_s_right(void);
static void ins_right(void);
static void ins_s_left(void);
static void ins_end(int c);
static void ins_home(int c);
static void ins_left(void);
static void ins_mousescroll(int dir);
static void ins_mouse(int c);
static int ins_bs(int c, int mode, int *inserted_space_p);
static void ins_del(void);
static void ins_shift(int c, int lastc);
static void ins_ctrl_o(void);
static void ins_insert(int replaceState);
static int ins_start_select(int c);
static void ins_ctrl_(void);
static int ins_esc(long *count, int cmdchar, int nomove);
static void ins_ctrl_hat(void);
static void ins_ctrl_g(void);
static void ins_reg(void);
static int cindent_on(void);
static int del_char_after_col(int limit_col);
static void replace_do_bs(int limit_col);
static void replace_flush(void);
static void mb_replace_pop_ins(int cc);
static void replace_pop_ins(void);
static void replace_join(int off);
static int replace_pop(void);
static int echeck_abbr(int);
static void stop_insert(pos_T *end_insert_pos, int esc, int nomove);
static void spell_back_to_badword(void);
static void check_spell_redraw(void);
static void start_arrow(pos_T *end_insert_pos);
static void redo_literal(int c);
static void check_auto_format(int);
static void internal_format(int textwidth, int second_indent, int flags,
                            int format_only,
                            int c);
static void insert_special(int, int, int);
static void undisplay_dollar(void);
static void ins_ctrl_v(void);
static void ins_redraw(int ready);
static unsigned quote_meta(char_u *dest, char_u *str, int len);
static int ins_complete(int c);
static int ins_compl_use_match(int c);
static int ins_compl_key2count(int c);
static int ins_compl_pum_key(int c);
static int ins_compl_key2dir(int c);
static int ins_compl_next(int allow_get_expansion, int count,
                          int insert_match);
static void ins_compl_insert(void);
static void ins_compl_delete(void);
static int ins_compl_get_exp(pos_T *ini);
static void ins_compl_add_dict(dict_T *dict);
static void ins_compl_add_list(list_T *list);
static buf_T *ins_compl_next_buf(buf_T *buf, int flag);
static void ins_compl_fixRedoBufForLeader(char_u *ptr_arg);
static int ins_compl_prep(int c);
static void ins_compl_addfrommatch(void);
static void ins_compl_set_original_text(char_u *str);
static void ins_compl_restart(void);
static int ins_compl_len(void);
static void ins_compl_addleader(int c);
static void ins_compl_new_leader(void);
static int ins_compl_need_restart(void);
static int ins_compl_bs(void);
static void ins_compl_clear(void);
static void ins_compl_free(void);
static char_u *find_line_end(char_u *ptr);
static void ins_compl_files(int count, char_u **files, int thesaurus,
                            int flags, regmatch_T *regmatch, char_u *
                            buf,
                            int *dir);
static void ins_compl_dictionaries(char_u *dict, char_u *pat, int flags,
                                   int thesaurus);
static int pum_enough_matches(void);
static int pum_wanted(void);
static void ins_compl_del_pum(void);
static void ins_compl_upd_pum(void);
static int ins_compl_make_cyclic(void);
static void ins_compl_add_matches(int num_matches, char_u **matches,
                                  int icase);
static void ins_compl_longest_match(compl_T *match);
static int ins_compl_equal(compl_T *match, char_u *str, int len);
static int ins_compl_add(char_u *str, int len, int icase, char_u *fname,
                         char_u **cptext, int cdir, int flags,
                         int adup);
static int ins_compl_accept_char(int c);
static int has_compl_option(int dict_opt);
static void ins_ctrl_x(void);
