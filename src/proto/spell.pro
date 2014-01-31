/* spell.c */
int spell_check __ARGS((win_T *wp, char_u *ptr, hlf_T *attrp, int *capcol,
                        int docount));
int spell_move_to __ARGS((win_T *wp, int dir, int allwords, int curline,
                          hlf_T *attrp));
void spell_cat_line __ARGS((char_u *buf, char_u *line, int maxlen));
char_u *did_set_spelllang __ARGS((win_T *wp));
void spell_delete_wordlist __ARGS((void));
void spell_free_all __ARGS((void));
void spell_reload __ARGS((void));
int spell_check_msm __ARGS((void));
void ex_mkspell __ARGS((exarg_T *eap));
void ex_spell __ARGS((exarg_T *eap));
void spell_add_word __ARGS((char_u *word, int len, int bad, int idx, int undo));
void init_spell_chartab __ARGS((void));
int spell_check_sps __ARGS((void));
void spell_suggest __ARGS((int count));
void ex_spellrepall __ARGS((exarg_T *eap));
void spell_suggest_list __ARGS((garray_T *gap, char_u *word, int maxcount,
                                int need_cap,
                                int interactive));
char_u *eval_soundfold __ARGS((char_u *word));
void ex_spellinfo __ARGS((exarg_T *eap));
void ex_spelldump __ARGS((exarg_T *eap));
void spell_dump_compl __ARGS((char_u *pat, int ic, int *dir, int dumpflags_arg));
char_u *spell_to_word_end __ARGS((char_u *start, win_T *win));
int spell_word_start __ARGS((int startcol));
void spell_expand_check_cap __ARGS((colnr_T col));
int expand_spelling __ARGS((linenr_T lnum, char_u *pat, char_u ***matchp));
/* vim: set ft=c : */
