static int
sug_compare(const void *s1, const void *s2);
static int
rep_compare(const void *s1, const void *s2);
static void init_spellfile(void);
static void spell_message(spellinfo_T *spin, char_u *str);
static void mkspell(int fcount, char_u **fnames, int ascii,
                    int over_write,
                    int added_word);
static void sug_write(spellinfo_T *spin, char_u *fname);
static int bytes2offset(char_u **pp);
static int offset2bytes(int nr, char_u *buf);
static int sug_filltable(spellinfo_T *spin, wordnode_T *node,
                         int startwordnr,
                         garray_T *gap);
static int sug_maketable(spellinfo_T *spin);
static int sug_filltree(spellinfo_T *spin, slang_T *slang);
static void spell_make_sugfile(spellinfo_T *spin, char_u *wfname);
static int put_node(FILE *fd, wordnode_T *node, int idx, int regionmask,
                    int prefixtree);
static void clear_node(wordnode_T *node);
static int write_vim_spell(spellinfo_T *spin, char_u *fname);
static int node_equal(wordnode_T *n1, wordnode_T *n2);
static int node_compress(spellinfo_T *spin, wordnode_T *node,
                         hashtab_T *ht,
                         int *tot);
static void wordtree_compress(spellinfo_T *spin, wordnode_T *root);
static void free_wordnode(spellinfo_T *spin, wordnode_T *n);
static int deref_wordnode(spellinfo_T *spin, wordnode_T *node);
static wordnode_T *get_wordnode(spellinfo_T *spin);
static int tree_add_word(spellinfo_T *spin, char_u *word,
                         wordnode_T *tree, int flags, int region,
                         int affixID);
static int store_word(spellinfo_T *spin, char_u *word, int flags,
                      int region, char_u *pfxlist,
                      int need_affix);
static wordnode_T *wordtree_alloc(spellinfo_T *spin);
static void free_blocks(sblock_T *bl);
static char_u *getroom_save(spellinfo_T *spin, char_u *s);
static int spell_read_wordfile(spellinfo_T *spin, char_u *fname);
static int store_aff_word(spellinfo_T *spin, char_u *word, char_u *afflist,
                          afffile_T *affile, hashtab_T *ht,
                          hashtab_T *xht, int condit, int flags,
                          char_u *pfxlist,
                          int pfxlen);
static void get_compflags(afffile_T *affile, char_u *afflist,
                          char_u *store_afflist);
static int get_pfxlist(afffile_T *affile, char_u *afflist,
                       char_u *store_afflist);
static int get_affix_flags(afffile_T *affile, char_u *afflist);
static int spell_read_dic(spellinfo_T *spin, char_u *fname,
                          afffile_T *affile);
static void spell_free_aff(afffile_T *aff);
static int sal_to_bool(char_u *s);
static void add_fromto(spellinfo_T *spin, garray_T *gap, char_u *from,
                       char_u *to);
static int str_equal(char_u *s1, char_u *s2);
static void aff_check_string(char_u *spinval, char_u *affval,
                             char *name);
static void aff_check_number(int spinval, int affval, char *name);
static int flag_in_afflist(int flagtype, char_u *afflist, unsigned flag);
static void check_renumber(spellinfo_T *spin);
static void process_compflags(spellinfo_T *spin, afffile_T *aff,
                              char_u *compflags);
static unsigned get_affitem(int flagtype, char_u **pp);
static unsigned affitem2flag(int flagtype, char_u *item, char_u *fname,
                             int lnum);
static int spell_info_item(char_u *s);
static void aff_process_flags(afffile_T *affile, affentry_T *entry);
static int is_aff_rule(char_u **items, int itemcnt, char *rulename,
                       int mincount);
static afffile_T *spell_read_aff(spellinfo_T *spin, char_u *fname);
static void close_spellbuf(buf_T *buf);
static buf_T *open_spellbuf(void);
static linenr_T dump_prefixes(slang_T *slang, char_u *word, char_u *pat,
                              int *dir, int round, int flags,
                              linenr_T startlnum);
static void dump_word(slang_T *slang, char_u *word, char_u *pat,
                      int *dir, int round, int flags,
                      linenr_T lnum);
static int spell_edit_score_limit_w(slang_T *slang, char_u *badword,
                                    char_u *goodword,
                                    int limit);
static int spell_edit_score_limit(slang_T *slang, char_u *badword,
                                  char_u *goodword,
                                  int limit);
static int spell_edit_score(slang_T *slang, char_u *badword,
                            char_u *goodword);
static int soundalike_score(char_u *goodsound, char_u *badsound);
static void spell_soundfold_wsal(slang_T *slang, char_u *inword,
                                 char_u *res);
static void spell_soundfold_sal(slang_T *slang, char_u *inword,
                                char_u *res);
static void spell_soundfold_sofo(slang_T *slang, char_u *inword,
                                 char_u *res);
static void spell_soundfold(slang_T *slang, char_u *inword, int folded,
                            char_u *res);
static int cleanup_suggestions(garray_T *gap, int maxscore, int keep);
static void rescore_one(suginfo_T *su, suggest_T *stp);
static void rescore_suggestions(suginfo_T *su);
static void add_banned(suginfo_T *su, char_u *word);
static void check_suggestions(suginfo_T *su, garray_T *gap);
static void add_suggestion(suginfo_T *su, garray_T *gap, char_u *goodword,
                           int badlen, int score,
                           int altscore, int had_bonus, slang_T *slang,
                           int maxsf);
static int similar_chars(slang_T *slang, int c1, int c2);
static void set_map_str(slang_T *lp, char_u *map);
static void make_case_word(char_u *fword, char_u *cword, int flags);
static int soundfold_find(slang_T *slang, char_u *word);
static void add_sound_suggest(suginfo_T *su, char_u *goodword,
                              int score,
                              langp_T *lp);
static void suggest_try_soundalike_finish(void);
static void suggest_try_soundalike(suginfo_T *su);
static void suggest_try_soundalike_prep(void);
static int stp_sal_score(suggest_T *stp, suginfo_T *su, slang_T *slang,
                         char_u *badsound);
static void score_combine(suginfo_T *su);
static void score_comp_sal(suginfo_T *su);
static void find_keepcap_word(slang_T *slang, char_u *fword,
                              char_u *kword);
static int nofold_len(char_u *fword, int flen, char_u *word);
static void go_deeper(trystate_T *stack, int depth, int score_add);
static void suggest_trie_walk(suginfo_T *su, langp_T *lp, char_u *fword,
                              int soundfold);
static void suggest_try_change(suginfo_T *su);
static void suggest_try_special(suginfo_T *su);
static void allcap_copy(char_u *word, char_u *wcopy);
static void onecap_copy(char_u *word, char_u *wcopy, int upper);
static void spell_find_cleanup(suginfo_T *su);
static void tree_count_words(char_u *byts, idx_T *idxs);
static void suggest_load_files(void);
static void spell_suggest_intern(suginfo_T *su, int interactive);
static void spell_suggest_file(suginfo_T *su, char_u *fname);
static void spell_suggest_expr(suginfo_T *su, char_u *expr);
static void spell_find_suggest(char_u *badptr, int badlen, suginfo_T *su,
                               int maxcount, int banbadword,
                               int need_cap,
                               int interactive);
static int check_need_cap(linenr_T lnum, colnr_T col);
static int spell_casefold(char_u *p, int len, char_u *buf, int buflen);
static int set_spell_chartab(char_u *fol, char_u *low, char_u *upp);
static void set_spell_charflags(char_u *flags, int cnt, char_u *upp);
static void spell_reload_one(char_u *fname, int added_word);
static int badword_captype(char_u *word, char_u *end);
static int captype(char_u *word, char_u *end);
static int find_region(char_u *rp, char_u *region);
static void use_midword(slang_T *lp, win_T *buf);
static void clear_midword(win_T *buf);
static idx_T read_tree_node(FILE *fd, char_u *byts, idx_T *idxs,
                            int maxidx, idx_T startidx, int prefixtree,
                            int maxprefcondnr);
static int spell_read_tree(FILE *fd, char_u **bytsp, idx_T **idxsp,
                           int prefixtree,
                           int prefixcnt);
static int *mb_str2wide(char_u *s);
static void set_sal_first(slang_T *lp);
static int set_sofo(slang_T *lp, char_u *from, char_u *to);
static int count_syllables(slang_T *slang, char_u *word);
static int init_syl_tab(slang_T *slang);
static int byte_in_str(char_u *str, int byte);
static int read_compound(FILE *fd, slang_T *slang, int len);
static int read_sofo_section(FILE *fd, slang_T *slang);
static int score_wordcount_adj(slang_T *slang, int score, char_u *word,
                               int split);
static void count_common_word(slang_T *lp, char_u *word, int len,
                              int count);
static int read_words_section(FILE *fd, slang_T *lp, int len);
static int read_sal_section(FILE *fd, slang_T *slang);
static int read_rep_section(FILE *fd, garray_T *gap, short *first);
static int read_prefcond_section(FILE *fd, slang_T *lp);
static int read_charflags_section(FILE *fd);
static int read_region_section(FILE *fd, slang_T *slang, int len);
static char_u *read_cnt_string(FILE *fd, int cnt_bytes, int *lenp);
static slang_T *spell_load_file(char_u *fname, char_u *lang, slang_T *old_lp,
                                int silent);
static void spell_load_cb(char_u *fname, void *cookie);
static void int_wordlist_spl(char_u *fname);
static char_u *spell_enc(void);
static void spell_load_lang(char_u *lang);
static int no_spell_checking(win_T *wp);
static int spell_valid_case(int wordflags, int treeflags);
static int fold_more(matchinf_T *mip);
static void find_prefix(matchinf_T *mip, int mode);
static int valid_word_prefix(int totprefcnt, int arridx, int flags,
                             char_u *word, slang_T *slang,
                             int cond_req);
static int match_compoundrule(slang_T *slang, char_u *compflags);
static int can_be_compound(trystate_T *sp, slang_T *slang, char_u *compflags,
                           int flag);
static int can_compound(slang_T *slang, char_u *word, char_u *flags);
static int match_checkcompoundpattern(char_u *ptr, int wlen,
                                      garray_T *gap);
static void find_word(matchinf_T *mip, int mode);
static void slang_clear_sug(slang_T *lp);
static void slang_clear(slang_T *lp);
static void slang_free(slang_T *lp);
static slang_T *slang_alloc(char_u *lang);
static int write_spell_prefcond(FILE *fd, garray_T *gap);
static int spell_iswordp_w(int *p, win_T *wp);
static int spell_mb_isword_class(int cl, win_T *wp);
static int spell_iswordp_nmw(char_u *p, win_T *wp);
static int spell_iswordp(char_u *p, win_T *wp);
static int set_spell_finish(spelltab_T  *new_st);
static void clear_spell_chartab(spelltab_T *sp);
static void *getroom(spellinfo_T *spin, size_t len, int align);
