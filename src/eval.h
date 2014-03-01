#ifndef NEOVIM_EVAL_H
#define NEOVIM_EVAL_H
/* eval.c */
void eval_init(void);
void eval_clear(void);
char_u *func_name(void *cookie);
linenr_T *func_breakpoint(void *cookie);
int *func_dbg_tick(void *cookie);
int func_level(void *cookie);
int current_func_returned(void);
void set_internal_string_var(char_u *name, char_u *value);
int var_redir_start(char_u *name, int append);
void var_redir_str(char_u *value, int value_len);
void var_redir_stop(void);
int eval_charconvert(char_u *enc_from, char_u *enc_to, char_u *
                     fname_from,
                     char_u *fname_to);
int eval_printexpr(char_u *fname, char_u *args);
void eval_diff(char_u *origfile, char_u *newfile, char_u *outfile);
void eval_patch(char_u *origfile, char_u *difffile, char_u *outfile);
int eval_to_bool(char_u *arg, int *error, char_u **nextcmd, int skip);
char_u *eval_to_string_skip(char_u *arg, char_u **nextcmd, int skip);
int skip_expr(char_u **pp);
char_u *eval_to_string(char_u *arg, char_u **nextcmd, int convert);
char_u *eval_to_string_safe(char_u *arg, char_u **nextcmd,
                            int use_sandbox);
int eval_to_number(char_u *expr);
list_T *eval_spell_expr(char_u *badword, char_u *expr);
int get_spellword(list_T *list, char_u **pp);
typval_T *eval_expr(char_u *arg, char_u **nextcmd);
int call_vim_function(char_u *func, int argc, char_u **argv, int safe,
                      int str_arg_only,
                      typval_T *rettv);
long call_func_retnr(char_u *func, int argc, char_u **argv, int safe);
void *call_func_retstr(char_u *func, int argc, char_u **argv, int safe);
void *call_func_retlist(char_u *func, int argc, char_u **argv, int safe);
void *save_funccal(void);
void restore_funccal(void *vfc);
void prof_child_enter(proftime_T *tm);
void prof_child_exit(proftime_T *tm);
int eval_foldexpr(char_u *arg, int *cp);
void ex_let(exarg_T *eap);
void list_add_watch(list_T *l, listwatch_T *lw);
void list_rem_watch(list_T *l, listwatch_T *lwrem);
void *eval_for_line(char_u *arg, int *errp, char_u **nextcmdp, int skip);
int next_for_item(void *fi_void, char_u *arg);
void free_for_info(void *fi_void);
void set_context_for_expression(expand_T *xp, char_u *arg,
                                cmdidx_T cmdidx);
void ex_call(exarg_T *eap);
void ex_unlet(exarg_T *eap);
void ex_lockvar(exarg_T *eap);
int do_unlet(char_u *name, int forceit);
void del_menutrans_vars(void);
char_u *get_user_var_name(expand_T *xp, int idx);
list_T *list_alloc(void);
void list_unref(list_T *l);
void list_free(list_T *l, int recurse);
listitem_T *listitem_alloc(void);
void listitem_free(listitem_T *item);
void listitem_remove(list_T *l, listitem_T *item);
dictitem_T *dict_lookup(hashitem_T *hi);
listitem_T *list_find(list_T *l, long n);
char_u *list_find_str(list_T *l, long idx);
void list_append(list_T *l, listitem_T *item);
int list_append_tv(list_T *l, typval_T *tv);
int list_append_dict(list_T *list, dict_T *dict);
int list_append_string(list_T *l, char_u *str, int len);
int list_insert_tv(list_T *l, typval_T *tv, listitem_T *item);
void list_remove(list_T *l, listitem_T *item, listitem_T *item2);
void list_insert(list_T *l, listitem_T *ni, listitem_T *item);
int garbage_collect(void);
void set_ref_in_ht(hashtab_T *ht, int copyID);
void set_ref_in_list(list_T *l, int copyID);
void set_ref_in_item(typval_T *tv, int copyID);
dict_T *dict_alloc(void);
void dict_unref(dict_T *d);
void dict_free(dict_T *d, int recurse);
dictitem_T *dictitem_alloc(char_u *key);
void dictitem_free(dictitem_T *item);
int dict_add(dict_T *d, dictitem_T *item);
int dict_add_nr_str(dict_T *d, char *key, long nr, char_u *str);
int dict_add_list(dict_T *d, char *key, list_T *list);
dictitem_T *dict_find(dict_T *d, char_u *key, int len);
char_u *get_dict_string(dict_T *d, char_u *key, int save);
long get_dict_number(dict_T *d, char_u *key);
char_u *get_function_name(expand_T *xp, int idx);
char_u *get_expr_name(expand_T *xp, int idx);
int func_call(char_u *name, typval_T *args, dict_T *selfdict,
              typval_T *rettv);
void dict_extend(dict_T *d1, dict_T *d2, char_u *action);
void mzscheme_call_vim(char_u *name, typval_T *args, typval_T *rettv);
float_T vim_round(float_T f);
long do_searchpair(char_u *spat, char_u *mpat, char_u *epat, int dir,
                   char_u *skip, int flags, pos_T *match_pos,
                   linenr_T lnum_stop,
                   long time_limit);
void set_vim_var_nr(int idx, long val);
long get_vim_var_nr(int idx);
char_u *get_vim_var_str(int idx);
list_T *get_vim_var_list(int idx);
void set_vim_var_char(int c);
void set_vcount(long count, long count1, int set_prevcount);
void set_vim_var_string(int idx, char_u *val, int len);
void set_vim_var_list(int idx, list_T *val);
void set_reg_var(int c);
char_u *v_exception(char_u *oldval);
char_u *v_throwpoint(char_u *oldval);
char_u *set_cmdarg(exarg_T *eap, char_u *oldarg);
void free_tv(typval_T *varp);
void clear_tv(typval_T *varp);
long get_tv_number_chk(typval_T *varp, int *denote);
char_u *get_tv_string_chk(typval_T *varp);
char_u *get_var_value(char_u *name);
void new_script_vars(scid_T id);
void init_var_dict(dict_T *dict, dictitem_T *dict_var, int scope);
void unref_var_dict(dict_T *dict);
void vars_clear(hashtab_T *ht);
void copy_tv(typval_T *from, typval_T *to);
void ex_echo(exarg_T *eap);
void ex_echohl(exarg_T *eap);
void ex_execute(exarg_T *eap);
void ex_function(exarg_T *eap);
void free_all_functions(void);
int translated_function_exists(char_u *name);
char_u *get_expanded_name(char_u *name, int check);
void func_dump_profile(FILE *fd);
char_u *get_user_func_name(expand_T *xp, int idx);
void ex_delfunction(exarg_T *eap);
void func_unref(char_u *name);
void func_ref(char_u *name);
void ex_return(exarg_T *eap);
int do_return(exarg_T *eap, int reanimate, int is_cmd, void *rettv);
void discard_pending_return(void *rettv);
char_u *get_return_cmd(void *rettv);
char_u *get_func_line(int c, void *cookie, int indent);
void func_line_start(void *cookie);
void func_line_exec(void *cookie);
void func_line_end(void *cookie);
int func_has_ended(void *cookie);
int func_has_abort(void *cookie);
int read_viminfo_varlist(vir_T *virp, int writing);
void write_viminfo_varlist(FILE *fp);
int store_session_globals(FILE *fd);
void last_set_msg(scid_T scriptID);
void ex_oldfiles(exarg_T *eap);
int modify_fname(char_u *src, int *usedlen, char_u **fnamep,
                 char_u **bufp,
                 int *fnamelen);
char_u *do_string_sub(char_u *str, char_u *pat, char_u *sub,
                      char_u *flags);
/* vim: set ft=c : */
#endif /* NEOVIM_EVAL_H */
