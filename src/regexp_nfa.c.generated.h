static int match_zref(int subidx, int *bytelen);
static int pim_equal(nfa_pim_T *one, nfa_pim_T *two);
static int match_backref(regsub_T *sub, int subidx, int *bytelen);
static int sub_equal(regsub_T *sub1, regsub_T *sub2);
static void copy_ze_off(regsub_T *to, regsub_T *from);
static void copy_sub_off(regsub_T *to, regsub_T *from);
static void copy_sub(regsub_T *to, regsub_T *from);
static void clear_sub(regsub_T *sub);
static void copy_pim(nfa_pim_T *to, nfa_pim_T *from);
static Frag_T st_pop(Frag_T **p, Frag_T *stack);
static void st_push(Frag_T s, Frag_T **p, Frag_T *stack_end);
static Ptrlist *append(Ptrlist *l1, Ptrlist *l2);
static int check_char_class(int class, int c);
static void st_error(int *postfix, int *end, int *p);
static int *re2post(void);
static int nfa_reg(int paren);
static int nfa_regbranch(void);
static int nfa_regconcat(void);
static int nfa_regpiece(void);
static int nfa_regatom(void);
static void nfa_emit_equi_class(int c);
static int nfa_recognize_char_class(char_u *start, char_u *end,
                                    int extra_newl);
static void realloc_post_list(void);
static void nfa_regcomp_start(char_u *expr, int re_flags);
static long find_match_text(colnr_T startcol, int regstart,
                            char_u *match_text);
static int skip_to_start(int c, colnr_T *colp);
static int nfa_regmatch(nfa_regprog_T *prog, nfa_state_T *start,
                        regsubs_T *submatch,
                        regsubs_T *m);
static int recursive_regmatch(nfa_state_T *state, nfa_pim_T *pim,
                              nfa_regprog_T *prog, regsubs_T *submatch,
                              regsubs_T *m,
                              int **listids);
static void addstate_here(nfa_list_T *l, nfa_state_T *state,
                          regsubs_T *subs, nfa_pim_T *pim,
                          int *ip);
static regsubs_T *addstate(nfa_list_T *l, nfa_state_T *state,
                           regsubs_T *subs_arg, nfa_pim_T *pim,
                           int off);
static int state_in_list(nfa_list_T *l, nfa_state_T *state,
                         regsubs_T *subs);
static int has_state_with_pos(nfa_list_T *l, nfa_state_T *state,
                              regsubs_T *subs,
                              nfa_pim_T *pim);
static void patch(Ptrlist *l, nfa_state_T *s);
static Ptrlist *list1(nfa_state_T **outp);
static Frag_T frag(nfa_state_T *start, Ptrlist *out);
static int failure_chance(nfa_state_T *state, int depth);
static int match_follows(nfa_state_T *startstate, int depth);
static long nfa_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf,
                              linenr_T lnum, colnr_T col,
                              proftime_T *tm);
static int nfa_regexec_nl(regmatch_T *rmp, char_u *line, colnr_T col, bool line_lbr);
static void nfa_regfree(regprog_T *prog);
static regprog_T *nfa_regcomp(char_u *expr, int re_flags);
static long nfa_regexec_both(char_u *line, colnr_T col);
static long nfa_regtry(nfa_regprog_T *prog, colnr_T col);
static int nfa_re_num_cmp(long_u val, int op, long_u pos);
static void nfa_restore_listids(nfa_regprog_T *prog, int *list);
static void nfa_save_listids(nfa_regprog_T *prog, int *list);
static void nfa_postprocess(nfa_regprog_T *prog);
static nfa_state_T *post2nfa(int *postfix, int *end, int nfa_calc_size);
static int nfa_max_width(nfa_state_T *startstate, int depth);
static nfa_state_T *alloc_state(int c, nfa_state_T *out,
                                nfa_state_T *out1);
static char_u *nfa_get_match_text(nfa_state_T *start);
static int nfa_get_regstart(nfa_state_T *start, int depth);
static int nfa_get_reganch(nfa_state_T *start, int depth);
