static void highlight_list_two(int cnt, int attr);
static void highlight_list(void);
static void syn_list_flags(struct name_list *nl, int flags, int attr);
static void syn_incl_toplevel(int id, int *flagsp);
static void syn_combine_list(short **clstr1, short **clstr2,
                             int list_op);
static int get_id_list(char_u **arg, int keylen, short **list);
static void syn_cmd_sync(exarg_T *eap, int syncing);
static char_u *get_syn_pattern(char_u *arg, synpat_T *ci);
static void init_syn_patterns(void);
static int syn_add_cluster(char_u *name);
static int syn_check_cluster(char_u *pp, int len);
static int syn_scl_namen2id(char_u *linep, int len);
static int syn_scl_name2id(char_u *name);
static void syn_cmd_cluster(exarg_T *eap, int syncing);
static int syn_compare_stub(const void *v1, const void *v2);
static void syn_cmd_region(exarg_T *eap, int syncing);
static void syn_cmd_match(exarg_T *eap, int syncing);
static void syn_cmd_keyword(exarg_T *eap, int syncing);
static void syn_cmd_include(exarg_T *eap, int syncing);
static char_u *get_syn_options(char_u *arg, syn_opt_arg_T *opt,
                               int *conceal_char);
static char_u *get_group_name(char_u *arg, char_u **name_end);
static void add_keyword(char_u *name, int id, int flags,
                        short *cont_in_list, short *next_list,
                        int conceal_char);
static void clear_keywtab(hashtab_T *ht);
static void syn_clear_keyword(int id, hashtab_T *ht);
static int syn_list_keywords(int id, hashtab_T *ht, int did_header,
                             int attr);
static void put_pattern(char *s, int c, synpat_T *spp, int attr);
static void put_id_list(char_u *name, short *list, int attr);
static void syn_list_cluster(int id);
static void syn_list_one(int id, int syncing, int link_only);
static void syn_stack_free_block(synblock_T *block);
static void syn_match_msg(void);
static void syn_lines_msg(void);
static void syn_cmd_list(exarg_T *eap, int syncing);
static void syn_cmd_onoff(exarg_T *eap, char *name);
static void syn_cmd_off(exarg_T *eap, int syncing);
static void syn_cmd_manual(exarg_T *eap, int syncing);
static void syn_cmd_reset(exarg_T *eap, int syncing);
static void syn_cmd_enable(exarg_T *eap, int syncing);
static void syn_cmd_on(exarg_T *eap, int syncing);
static void syn_clear_one(int id, int syncing);
static void syn_cmd_conceal(exarg_T *eap, int syncing);
static void syn_cmd_clear(exarg_T *eap, int syncing);
static void syn_clear_cluster(synblock_T *block, int i);
static void syn_clear_pattern(synblock_T *block, int i);
static void syn_remove_pattern(synblock_T *block, int idx);
static void syntax_sync_clear(void);
static void syn_cmd_spell(exarg_T *eap, int syncing);
static void syn_cmd_case(exarg_T *eap, int syncing);
static keyentry_T *match_keyword(char_u *keyword, hashtab_T *ht,
                                 stateitem_T *cur_si);
static int check_keyword_id(char_u *line, int startcol, int *endcol,
                            long *flags, short **next_list,
                            stateitem_T *cur_si,
                            int *ccharp);
static int syn_regexec(regmmatch_T *rmp, linenr_T lnum, colnr_T col,
                       syn_time_T *st);
static char_u *syn_getcurline(void);
static void syn_add_start_off(lpos_T *result, regmmatch_T *regmatch,
                              synpat_T *spp, int idx,
                              int extra);
static void syn_add_end_off(lpos_T *result, regmmatch_T *regmatch,
                            synpat_T *spp, int idx,
                            int extra);
static void limit_pos_zero(lpos_T *pos, lpos_T *limit);
static void limit_pos(lpos_T *pos, lpos_T *limit);
static void clear_current_state(void);
static void clear_syn_state(synstate_T *p);
static void find_endpos(int idx, lpos_T *startpos, lpos_T *m_endpos,
                        lpos_T *hl_endpos, long *flagsp, lpos_T *end_endpos,
                        int *end_idx, reg_extmatch_T *start_ext);
static void syn_stack_apply_changes_block(synblock_T *block, buf_T *buf);
static void syntime_report(void);
static int syn_compare_syntime(const void *v1, const void *v2);
static void syntime_clear(void);
static void syn_clear_time(syn_time_T *tt);
static void pop_current_state(void);
static void push_current_state(int idx);
static int in_id_list(stateitem_T *item, short *cont_list,
                      struct sp_syn *ssp,
                      int contained);
static short *copy_id_list(short *list);
static void update_si_end(stateitem_T *sip, int startcol, int force);
static void check_keepend(void);
static void update_si_attr(int idx);
static void check_state_ends(void);
static stateitem_T *push_next_match(stateitem_T *cur_si);
static int did_match_already(int idx, garray_T *gap);
static int syn_current_attr(int syncing, int displaying, int *can_spell,
                            int keep_state);
static int syn_finish_line(int syncing);
static void validate_current_state(void);
static int syn_stack_equal(synstate_T *sp);
static void invalidate_current_state(void);
static void load_current_state(synstate_T *from);
static synstate_T *store_current_state(void);
static synstate_T *syn_stack_find_entry(linenr_T lnum);
static void syn_stack_free_entry(synblock_T *block, synstate_T *p);
static int syn_stack_cleanup(void);
static void syn_stack_alloc(void);
static void syn_update_ends(int startofline);
static void syn_start_line(void);
static int syn_match_linecont(linenr_T lnum);
static void syn_sync(win_T *wp, linenr_T lnum, synstate_T *last_valid);
static void highlight_clear(int idx);
static int hl_has_settings(int idx, int check_link);
static int syn_list_header(int did_header, int outlen, int id);
static int syn_add_group(char_u *name);
static int highlight_list_arg(int id, int didh, int type, int iarg,
                              char_u *sarg,
                              char *name);
static void highlight_list_one(int id);
static void set_hl_attr(int idx);
static void syn_unadd_group(void);
static int get_attr_entry(garray_T *table, attrentry_T *aep);
