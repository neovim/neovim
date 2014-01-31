/* eval.c */
void eval_init __ARGS((void));
void eval_clear __ARGS((void));
char_u *func_name __ARGS((void *cookie));
linenr_T *func_breakpoint __ARGS((void *cookie));
int *func_dbg_tick __ARGS((void *cookie));
int func_level __ARGS((void *cookie));
int current_func_returned __ARGS((void));
void set_internal_string_var __ARGS((char_u *name, char_u *value));
int var_redir_start __ARGS((char_u *name, int append));
void var_redir_str __ARGS((char_u *value, int value_len));
void var_redir_stop __ARGS((void));
int eval_charconvert __ARGS((char_u *enc_from, char_u *enc_to, char_u *
                             fname_from,
                             char_u *fname_to));
int eval_printexpr __ARGS((char_u *fname, char_u *args));
void eval_diff __ARGS((char_u *origfile, char_u *newfile, char_u *outfile));
void eval_patch __ARGS((char_u *origfile, char_u *difffile, char_u *outfile));
int eval_to_bool __ARGS((char_u *arg, int *error, char_u **nextcmd, int skip));
char_u *eval_to_string_skip __ARGS((char_u *arg, char_u **nextcmd, int skip));
int skip_expr __ARGS((char_u **pp));
char_u *eval_to_string __ARGS((char_u *arg, char_u **nextcmd, int convert));
char_u *eval_to_string_safe __ARGS((char_u *arg, char_u **nextcmd,
                                    int use_sandbox));
int eval_to_number __ARGS((char_u *expr));
list_T *eval_spell_expr __ARGS((char_u *badword, char_u *expr));
int get_spellword __ARGS((list_T *list, char_u **pp));
typval_T *eval_expr __ARGS((char_u *arg, char_u **nextcmd));
int call_vim_function __ARGS((char_u *func, int argc, char_u **argv, int safe,
                              int str_arg_only,
                              typval_T *rettv));
long call_func_retnr __ARGS((char_u *func, int argc, char_u **argv, int safe));
void *call_func_retstr __ARGS((char_u *func, int argc, char_u **argv, int safe));
void *call_func_retlist __ARGS((char_u *func, int argc, char_u **argv, int safe));
void *save_funccal __ARGS((void));
void restore_funccal __ARGS((void *vfc));
void prof_child_enter __ARGS((proftime_T *tm));
void prof_child_exit __ARGS((proftime_T *tm));
int eval_foldexpr __ARGS((char_u *arg, int *cp));
void ex_let __ARGS((exarg_T *eap));
void list_add_watch __ARGS((list_T *l, listwatch_T *lw));
void list_rem_watch __ARGS((list_T *l, listwatch_T *lwrem));
void *eval_for_line __ARGS((char_u *arg, int *errp, char_u **nextcmdp, int skip));
int next_for_item __ARGS((void *fi_void, char_u *arg));
void free_for_info __ARGS((void *fi_void));
void set_context_for_expression __ARGS((expand_T *xp, char_u *arg,
                                        cmdidx_T cmdidx));
void ex_call __ARGS((exarg_T *eap));
void ex_unlet __ARGS((exarg_T *eap));
void ex_lockvar __ARGS((exarg_T *eap));
int do_unlet __ARGS((char_u *name, int forceit));
void del_menutrans_vars __ARGS((void));
char_u *get_user_var_name __ARGS((expand_T *xp, int idx));
list_T *list_alloc __ARGS((void));
void list_unref __ARGS((list_T *l));
void list_free __ARGS((list_T *l, int recurse));
listitem_T *listitem_alloc __ARGS((void));
void listitem_free __ARGS((listitem_T *item));
void listitem_remove __ARGS((list_T *l, listitem_T *item));
dictitem_T *dict_lookup __ARGS((hashitem_T *hi));
listitem_T *list_find __ARGS((list_T *l, long n));
char_u *list_find_str __ARGS((list_T *l, long idx));
void list_append __ARGS((list_T *l, listitem_T *item));
int list_append_tv __ARGS((list_T *l, typval_T *tv));
int list_append_dict __ARGS((list_T *list, dict_T *dict));
int list_append_string __ARGS((list_T *l, char_u *str, int len));
int list_insert_tv __ARGS((list_T *l, typval_T *tv, listitem_T *item));
void list_remove __ARGS((list_T *l, listitem_T *item, listitem_T *item2));
void list_insert __ARGS((list_T *l, listitem_T *ni, listitem_T *item));
int garbage_collect __ARGS((void));
void set_ref_in_ht __ARGS((hashtab_T *ht, int copyID));
void set_ref_in_list __ARGS((list_T *l, int copyID));
void set_ref_in_item __ARGS((typval_T *tv, int copyID));
dict_T *dict_alloc __ARGS((void));
void dict_unref __ARGS((dict_T *d));
void dict_free __ARGS((dict_T *d, int recurse));
dictitem_T *dictitem_alloc __ARGS((char_u *key));
void dictitem_free __ARGS((dictitem_T *item));
int dict_add __ARGS((dict_T *d, dictitem_T *item));
int dict_add_nr_str __ARGS((dict_T *d, char *key, long nr, char_u *str));
int dict_add_list __ARGS((dict_T *d, char *key, list_T *list));
dictitem_T *dict_find __ARGS((dict_T *d, char_u *key, int len));
char_u *get_dict_string __ARGS((dict_T *d, char_u *key, int save));
long get_dict_number __ARGS((dict_T *d, char_u *key));
char_u *get_function_name __ARGS((expand_T *xp, int idx));
char_u *get_expr_name __ARGS((expand_T *xp, int idx));
int func_call __ARGS((char_u *name, typval_T *args, dict_T *selfdict,
                      typval_T *rettv));
void dict_extend __ARGS((dict_T *d1, dict_T *d2, char_u *action));
void mzscheme_call_vim __ARGS((char_u *name, typval_T *args, typval_T *rettv));
float_T vim_round __ARGS((float_T f));
long do_searchpair __ARGS((char_u *spat, char_u *mpat, char_u *epat, int dir,
                           char_u *skip, int flags, pos_T *match_pos,
                           linenr_T lnum_stop,
                           long time_limit));
void set_vim_var_nr __ARGS((int idx, long val));
long get_vim_var_nr __ARGS((int idx));
char_u *get_vim_var_str __ARGS((int idx));
list_T *get_vim_var_list __ARGS((int idx));
void set_vim_var_char __ARGS((int c));
void set_vcount __ARGS((long count, long count1, int set_prevcount));
void set_vim_var_string __ARGS((int idx, char_u *val, int len));
void set_vim_var_list __ARGS((int idx, list_T *val));
void set_reg_var __ARGS((int c));
char_u *v_exception __ARGS((char_u *oldval));
char_u *v_throwpoint __ARGS((char_u *oldval));
char_u *set_cmdarg __ARGS((exarg_T *eap, char_u *oldarg));
void free_tv __ARGS((typval_T *varp));
void clear_tv __ARGS((typval_T *varp));
long get_tv_number_chk __ARGS((typval_T *varp, int *denote));
char_u *get_tv_string_chk __ARGS((typval_T *varp));
char_u *get_var_value __ARGS((char_u *name));
void new_script_vars __ARGS((scid_T id));
void init_var_dict __ARGS((dict_T *dict, dictitem_T *dict_var, int scope));
void unref_var_dict __ARGS((dict_T *dict));
void vars_clear __ARGS((hashtab_T *ht));
void copy_tv __ARGS((typval_T *from, typval_T *to));
void ex_echo __ARGS((exarg_T *eap));
void ex_echohl __ARGS((exarg_T *eap));
void ex_execute __ARGS((exarg_T *eap));
void ex_function __ARGS((exarg_T *eap));
void free_all_functions __ARGS((void));
int translated_function_exists __ARGS((char_u *name));
char_u *get_expanded_name __ARGS((char_u *name, int check));
void func_dump_profile __ARGS((FILE *fd));
char_u *get_user_func_name __ARGS((expand_T *xp, int idx));
void ex_delfunction __ARGS((exarg_T *eap));
void func_unref __ARGS((char_u *name));
void func_ref __ARGS((char_u *name));
void ex_return __ARGS((exarg_T *eap));
int do_return __ARGS((exarg_T *eap, int reanimate, int is_cmd, void *rettv));
void discard_pending_return __ARGS((void *rettv));
char_u *get_return_cmd __ARGS((void *rettv));
char_u *get_func_line __ARGS((int c, void *cookie, int indent));
void func_line_start __ARGS((void *cookie));
void func_line_exec __ARGS((void *cookie));
void func_line_end __ARGS((void *cookie));
int func_has_ended __ARGS((void *cookie));
int func_has_abort __ARGS((void *cookie));
int read_viminfo_varlist __ARGS((vir_T *virp, int writing));
void write_viminfo_varlist __ARGS((FILE *fp));
int store_session_globals __ARGS((FILE *fd));
void last_set_msg __ARGS((scid_T scriptID));
void ex_oldfiles __ARGS((exarg_T *eap));
int modify_fname __ARGS((char_u *src, int *usedlen, char_u **fnamep, char_u *
                         *bufp,
                         int *fnamelen));
char_u *do_string_sub __ARGS((char_u *str, char_u *pat, char_u *sub,
                              char_u *flags));
/* vim: set ft=c : */
