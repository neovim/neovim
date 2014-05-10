int expand_spelling(linenr_T lnum, char_u *pat, char_u ***matchp);
void spell_expand_check_cap(colnr_T col);
int spell_word_start(int startcol);
char_u *spell_to_word_end(char_u *start, win_T *win);
void spell_dump_compl(char_u *pat, int ic, int *dir, int dumpflags_arg);
void ex_spelldump(exarg_T *eap);
void ex_spellinfo(exarg_T *eap);
char_u *eval_soundfold(char_u *word);
void spell_suggest_list(garray_T *gap, char_u *word, int maxcount,
                        int need_cap,
                        int interactive);
void ex_spellrepall(exarg_T *eap);
void spell_suggest(int count);
int spell_check_sps(void);
void init_spell_chartab(void);
void spell_add_word(char_u *word, int len, int bad, int idx, int undo);
void ex_spell(exarg_T *eap);
void ex_mkspell(exarg_T *eap);
int spell_check_msm(void);
void spell_reload(void);
void spell_free_all(void);
void spell_delete_wordlist(void);
char_u *did_set_spelllang(win_T *wp);
void spell_cat_line(char_u *buf, char_u *line, int maxlen);
int spell_move_to(win_T *wp, int dir, int allwords, int curline,
                  hlf_T *attrp);
int spell_check(win_T *wp, char_u *ptr, hlf_T *attrp, int *capcol,
                int docount);
