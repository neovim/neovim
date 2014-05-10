static var_flavour_T var_flavour(char_u *varname);
static int get_winnr(tabpage_T *tp, typval_T *argvar);
static int
item_compare2(const void *s1, const void *s2);
static int
item_compare(const void *s1, const void *s2);
static void set_qf_ll_list(win_T *wp, typval_T *list_arg,
                           typval_T *action_arg,
                           typval_T *rettv);
static int get_search_arg(typval_T *varp, int *flagsp);
static int list2proftime(typval_T *arg, proftime_T *tm);
static int mkdir_recurse(char_u *dir, int prot);
static void max_min(typval_T *argvars, typval_T *rettv, int domax);
static void find_some_match(typval_T *argvars, typval_T *rettv, int start);
static void get_maparg(typval_T *argvars, typval_T *rettv, int exact);
static void libcall_common(typval_T *argvars, typval_T *rettv, int type);
static void dict_list(typval_T *argvars, typval_T *rettv, int what);
static void get_user_input(typval_T *argvars, typval_T *rettv,
                           int inputdialog);
static void get_buffer_lines(buf_T *buf, linenr_T start, linenr_T end,
                             int retlist,
                             typval_T *rettv);
static void foldclosed_both(typval_T *argvars, typval_T *rettv, int end);
static int filter_map_one(typval_T *tv, char_u *expr, int map, int *remp);
static void filter_map(typval_T *argvars, typval_T *rettv, int map);
static void findfilendir(typval_T *argvars, typval_T *rettv,
                                 int find_what);
static buf_T *get_buf_tv(typval_T *tv, int curtab_only);
static buf_T *find_buffer(typval_T *avar);
static int get_float_arg(typval_T *argvars, float_T *f);
static char_u *cat_prefix_varname(int prefix, char_u *name);
static void setwinvar(typval_T *argvars, typval_T *rettv, int off);
static int search_cmn(typval_T *argvars, pos_T *match_pos, int *flagsp);
static int searchpair_cmn(typval_T *argvars, pos_T *match_pos);
static void getwinvar(typval_T *argvars, typval_T *rettv, int off);
static win_T *find_win_by_nr(typval_T *vp, tabpage_T *tp);
static void add_nr_var(dict_T *dp, dictitem_T *v, char *name,
                       varnumber_T nr);
static void free_funccal(funccall_T *fc, int free_val);
static int can_free_funccal(funccall_T *fc, int copyID);
static void call_user_func(ufunc_T *fp, int argcount, typval_T *argvars,
                           typval_T *rettv, linenr_T firstline,
                           linenr_T lastline,
                           dict_T *selfdict);
static void func_free(ufunc_T *fp);
static void cat_func_name(char_u *buf, ufunc_T *fp);
static char_u *autoload_name(char_u *name);
static int script_autoload(char_u *name, int reload);
static int
prof_self_cmp(const void *s1, const void *s2);
static int
prof_total_cmp(const void *s1, const void *s2);
static void prof_func_line(FILE *fd, int count, proftime_T *total,
                           proftime_T *self,
                           int prefer_self);
static void prof_sort_list(FILE *fd, ufunc_T **sorttab, int st_len,
                           char *title,
                           int prefer_self);
static void func_do_profile(ufunc_T *fp);
static int function_exists(char_u *name);
static ufunc_T *find_func(char_u *name);
static void list_func_head(ufunc_T *fp, int indent);
static int eval_fname_sid(char_u *p);
static int eval_fname_script(char_u *p);
static char_u *trans_function_name(char_u **pp, int skip, int flags,
                                   funcdict_T *fd);
static char_u *find_option_end(char_u **arg, int *opt_flags);
static int item_copy(typval_T *from, typval_T *to, int deep, int copyID);
static int tv_check_lock(int lock, char_u *name);
static int valid_varname(char_u *varname);
static int var_check_func_name(char_u *name, int new_var);
static int var_check_fixed(int flags, char_u *name);
static int var_check_ro(int flags, char_u *name);
static void set_var(char_u *name, typval_T *varp, int copy);
static void list_one_var_a(char_u *prefix, char_u *name, int type,
                           char_u *string,
                           int *first);
static void list_one_var(dictitem_T *v, char_u *prefix, int *first);
static void delete_var(hashtab_T *ht, hashitem_T *hi);
static void vars_clear_ext(hashtab_T *ht, int free_val);
static hashtab_T *find_var_ht(char_u *name, char_u **varname);
static dictitem_T *find_var_in_ht(hashtab_T *ht, int htname,
                                  char_u *varname,
                                  int no_autoload);
static dictitem_T *find_var(char_u *name, hashtab_T **htp,
                            int no_autoload);
static char_u *get_tv_string_buf_chk(typval_T *varp, char_u *buf);
static char_u *get_tv_string_buf(typval_T *varp, char_u *buf);
static char_u *get_tv_string(typval_T *varp);
static linenr_T get_tv_lnum_buf(typval_T *argvars, buf_T *buf);
static linenr_T get_tv_lnum(typval_T *argvars);
static long get_tv_number(typval_T *varp);
static void init_tv(typval_T *varp);
static int handle_subscript(char_u **arg, typval_T *rettv, int evaluate,
                            int verbose);
static int get_var_tv(char_u *name, int len, typval_T *rettv,
                      int verbose,
                      int no_autoload);
static int eval_isnamec1(int c);
static int eval_isnamec(int c);
static char_u *
make_expanded_name(char_u *in_start, char_u *expr_start, char_u *
                   expr_end,
                   char_u *in_end);
static char_u *find_name_end(char_u *arg, char_u **expr_start, char_u *
                             *expr_end,
                             int flags);
static int get_name_len(char_u **arg, char_u **alias, int evaluate,
                        int verbose);
static int get_id_len(char_u **arg);
static int get_env_len(char_u **arg);
static pos_T *var2fpos(typval_T *varp, int dollar_lnum, int *fnum);
static int list2fpos(typval_T *arg, pos_T *posp, int *fnump);
static void f_xor(typval_T *argvars, typval_T *rettv);
static void f_writefile(typval_T *argvars, typval_T *rettv);
static void f_winwidth(typval_T *argvars, typval_T *rettv);
static void f_winsaveview(typval_T *argvars, typval_T *rettv);
static void f_winrestview(typval_T *argvars, typval_T *rettv);
static void f_winrestcmd(typval_T *argvars, typval_T *rettv);
static void f_winnr(typval_T *argvars, typval_T *rettv);
static void f_winline(typval_T *argvars, typval_T *rettv);
static void f_winheight(typval_T *argvars, typval_T *rettv);
static void f_wincol(typval_T *argvars, typval_T *rettv);
static void f_winbufnr(typval_T *argvars, typval_T *rettv);
static void f_wildmenumode(typval_T *argvars, typval_T *rettv);
static void f_visualmode(typval_T *argvars, typval_T *rettv);
static void f_virtcol(typval_T *argvars, typval_T *rettv);
static void f_values(typval_T *argvars, typval_T *rettv);
static void f_uniq(typval_T *argvars, typval_T *rettv);
static void f_undotree(typval_T *argvars, typval_T *rettv);
static void f_undofile(typval_T *argvars, typval_T *rettv);
static void f_type(typval_T *argvars, typval_T *rettv);
static void f_trunc(typval_T *argvars, typval_T *rettv);
static void f_tr(typval_T *argvars, typval_T *rettv);
static void f_toupper(typval_T *argvars, typval_T *rettv);
static void f_tolower(typval_T *argvars, typval_T *rettv);
static void f_tanh(typval_T *argvars, typval_T *rettv);
static void f_tan(typval_T *argvars, typval_T *rettv);
static void f_test(typval_T *argvars, typval_T *rettv);
static void f_tempname(typval_T *argvars, typval_T *rettv);
static void f_tagfiles(typval_T *argvars, typval_T *rettv);
static void f_taglist(typval_T *argvars, typval_T *rettv);
static void f_tabpagewinnr(typval_T *argvars, typval_T *rettv);
static void f_tabpagenr(typval_T *argvars, typval_T *rettv);
static void f_tabpagebuflist(typval_T *argvars, typval_T *rettv);
static void f_system(typval_T *argvars, typval_T *rettv);
static void f_synconcealed(typval_T *argvars, typval_T *rettv);
static void f_synstack(typval_T *argvars, typval_T *rettv);
static void f_synIDtrans(typval_T *argvars, typval_T *rettv);
static void f_synIDattr(typval_T *argvars, typval_T *rettv);
static void f_synID(typval_T *argvars, typval_T *rettv);
static void f_substitute(typval_T *argvars, typval_T *rettv);
static void f_submatch(typval_T *argvars, typval_T *rettv);
static void f_strwidth(typval_T *argvars, typval_T *rettv);
static void f_strdisplaywidth(typval_T *argvars, typval_T *rettv);
static void f_strtrans(typval_T *argvars, typval_T *rettv);
static void f_strridx(typval_T *argvars, typval_T *rettv);
static void f_strpart(typval_T *argvars, typval_T *rettv);
static void f_strlen(typval_T *argvars, typval_T *rettv);
static void f_string(typval_T *argvars, typval_T *rettv);
static void f_stridx(typval_T *argvars, typval_T *rettv);
static void f_strftime(typval_T *argvars, typval_T *rettv);
static void f_strchars(typval_T *argvars, typval_T *rettv);
static void f_str2nr(typval_T *argvars, typval_T *rettv);
static void f_str2float(typval_T *argvars, typval_T *rettv);
static void f_sqrt(typval_T *argvars, typval_T *rettv);
static void f_split(typval_T *argvars, typval_T *rettv);
static void f_spellsuggest(typval_T *argvars, typval_T *rettv);
static void f_spellbadword(typval_T *argvars, typval_T *rettv);
static void f_soundfold(typval_T *argvars, typval_T *rettv);
static void f_sort(typval_T *argvars, typval_T *rettv);
static void f_sinh(typval_T *argvars, typval_T *rettv);
static void f_sin(typval_T *argvars, typval_T *rettv);
static void f_simplify(typval_T *argvars, typval_T *rettv);
static void f_shiftwidth(typval_T *argvars, typval_T *rettv);
static void f_shellescape(typval_T *argvars, typval_T *rettv);
static void f_sha256(typval_T *argvars, typval_T *rettv);
static void f_setwinvar(typval_T *argvars, typval_T *rettv);
static void f_settabwinvar(typval_T *argvars, typval_T *rettv);
static void f_settabvar(typval_T *argvars, typval_T *rettv);
static void f_setreg(typval_T *argvars, typval_T *rettv);
static void f_setqflist(typval_T *argvars, typval_T *rettv);
static void f_setpos(typval_T *argvars, typval_T *rettv);
static void f_setmatches(typval_T *argvars, typval_T *rettv);
static void f_setloclist(typval_T *argvars, typval_T *rettv);
static void f_setline(typval_T *argvars, typval_T *rettv);
static void f_setcmdpos(typval_T *argvars, typval_T *rettv);
static void f_setbufvar(typval_T *argvars, typval_T *rettv);
static void f_serverlist(typval_T *argvars, typval_T *rettv);
static void f_server2client(typval_T *argvars, typval_T *rettv);
static void f_searchpos(typval_T *argvars, typval_T *rettv);
static void f_searchpairpos(typval_T *argvars, typval_T *rettv);
static void f_searchpair(typval_T *argvars, typval_T *rettv);
static void f_searchdecl(typval_T *argvars, typval_T *rettv);
static void f_search(typval_T *argvars, typval_T *rettv);
static void f_screenrow(typval_T *argvars, typval_T *rettv);
static void f_screencol(typval_T *argvars, typval_T *rettv);
static void f_screenchar(typval_T *argvars, typval_T *rettv);
static void f_screenattr(typval_T *argvars, typval_T *rettv);
static void f_round(typval_T *argvars, typval_T *rettv);
static void f_reverse(typval_T *argvars, typval_T *rettv);
static void f_resolve(typval_T *argvars, typval_T *rettv);
static void f_repeat(typval_T *argvars, typval_T *rettv);
static void f_rename(typval_T *argvars, typval_T *rettv);
static void f_remove(typval_T *argvars, typval_T *rettv);
static void f_remote_send(typval_T *argvars, typval_T *rettv);
static void f_remote_read(typval_T *argvars, typval_T *rettv);
static void f_remote_peek(typval_T *argvars, typval_T *rettv);
static void f_remote_foreground(typval_T *argvars, typval_T *rettv);
static void f_remote_expr(typval_T *argvars, typval_T *rettv);
static void f_reltimestr(typval_T *argvars, typval_T *rettv);
static void f_reltime(typval_T *argvars, typval_T *rettv);
static void f_readfile(typval_T *argvars, typval_T *rettv);
static void f_range(typval_T *argvars, typval_T *rettv);
static void f_pumvisible(typval_T *argvars, typval_T *rettv);
static void f_printf(typval_T *argvars, typval_T *rettv);
static void f_prevnonblank(typval_T *argvars, typval_T *rettv);
static void f_pow(typval_T *argvars, typval_T *rettv);
static void f_pathshorten(typval_T *argvars, typval_T *rettv);
static void f_or(typval_T *argvars, typval_T *rettv);
static void f_nr2char(typval_T *argvars, typval_T *rettv);
static void f_nextnonblank(typval_T *argvars, typval_T *rettv);
static void f_mode(typval_T *argvars, typval_T *rettv);
static void f_mkdir(typval_T *argvars, typval_T *rettv);
static void f_min(typval_T *argvars, typval_T *rettv);
static void f_max(typval_T *argvars, typval_T *rettv);
static void f_matchstr(typval_T *argvars, typval_T *rettv);
static void f_matchlist(typval_T *argvars, typval_T *rettv);
static void f_matchend(typval_T *argvars, typval_T *rettv);
static void f_matchdelete(typval_T *argvars, typval_T *rettv);
static void f_matcharg(typval_T *argvars, typval_T *rettv);
static void f_matchadd(typval_T *argvars, typval_T *rettv);
static void f_match(typval_T *argvars, typval_T *rettv);
static void f_mapcheck(typval_T *argvars, typval_T *rettv);
static void f_maparg(typval_T *argvars, typval_T *rettv);
static void f_map(typval_T *argvars, typval_T *rettv);
static void f_log10(typval_T *argvars, typval_T *rettv);
static void f_log(typval_T *argvars, typval_T *rettv);
static void f_localtime(typval_T *argvars, typval_T *rettv);
static void f_lispindent(typval_T *argvars, typval_T *rettv);
static void f_line2byte(typval_T *argvars, typval_T *rettv);
static void f_line(typval_T *argvars, typval_T *rettv);
static void f_libcallnr(typval_T *argvars, typval_T *rettv);
static void f_libcall(typval_T *argvars, typval_T *rettv);
static void f_len(typval_T *argvars, typval_T *rettv);
static void f_last_buffer_nr(typval_T *argvars, typval_T *rettv);
static void f_keys(typval_T *argvars, typval_T *rettv);
static void f_join(typval_T *argvars, typval_T *rettv);
static void f_job_write(typval_T *argvars, typval_T *rettv);
static void f_job_stop(typval_T *argvars, typval_T *rettv);
static void f_job_start(typval_T *argvars, typval_T *rettv);
static void f_items(typval_T *argvars, typval_T *rettv);
static void f_islocked(typval_T *argvars, typval_T *rettv);
static void f_isdirectory(typval_T *argvars, typval_T *rettv);
static void f_invert(typval_T *argvars, typval_T *rettv);
static void f_insert(typval_T *argvars, typval_T *rettv);
static void f_inputsecret(typval_T *argvars, typval_T *rettv);
static void f_inputsave(typval_T *argvars, typval_T *rettv);
static void f_inputrestore(typval_T *argvars, typval_T *rettv);
static void f_inputlist(typval_T *argvars, typval_T *rettv);
static void f_inputdialog(typval_T *argvars, typval_T *rettv);
static void f_input(typval_T *argvars, typval_T *rettv);
static void f_index(typval_T *argvars, typval_T *rettv);
static void f_indent(typval_T *argvars, typval_T *rettv);
static void f_iconv(typval_T *argvars, typval_T *rettv);
static void f_hostname(typval_T *argvars, typval_T *rettv);
static void f_hlexists(typval_T *argvars, typval_T *rettv);
static void f_hlID(typval_T *argvars, typval_T *rettv);
static void f_histnr(typval_T *argvars, typval_T *rettv);
static void f_histget(typval_T *argvars, typval_T *rettv);
static void f_histdel(typval_T *argvars, typval_T *rettv);
static void f_histadd(typval_T *argvars, typval_T *rettv);
static void f_hasmapto(typval_T *argvars, typval_T *rettv);
static void f_haslocaldir(typval_T *argvars, typval_T *rettv);
static void f_has_key(typval_T *argvars, typval_T *rettv);
static void f_has(typval_T *argvars, typval_T *rettv);
static void f_globpath(typval_T *argvars, typval_T *rettv);
static void f_glob(typval_T *argvars, typval_T *rettv);
static void f_getwinvar(typval_T *argvars, typval_T *rettv);
static void f_getwinposy(typval_T *argvars, typval_T *rettv);
static void f_getwinposx(typval_T *argvars, typval_T *rettv);
static void f_gettabwinvar(typval_T *argvars, typval_T *rettv);
static void f_gettabvar(typval_T *argvars, typval_T *rettv);
static void f_getregtype(typval_T *argvars, typval_T *rettv);
static void f_getreg(typval_T *argvars, typval_T *rettv);
static void f_getqflist(typval_T *argvars, typval_T *rettv);
static void f_getpos(typval_T *argvars, typval_T *rettv);
static void f_getpid(typval_T *argvars, typval_T *rettv);
static void f_getmatches(typval_T *argvars, typval_T *rettv);
static void f_getline(typval_T *argvars, typval_T *rettv);
static void f_getftype(typval_T *argvars, typval_T *rettv);
static void f_getftime(typval_T *argvars, typval_T *rettv);
static void f_getfsize(typval_T *argvars, typval_T *rettv);
static void f_getfperm(typval_T *argvars, typval_T *rettv);
static void f_getfontname(typval_T *argvars, typval_T *rettv);
static void f_getcwd(typval_T *argvars, typval_T *rettv);
static void f_getcmdtype(typval_T *argvars, typval_T *rettv);
static void f_getcmdpos(typval_T *argvars, typval_T *rettv);
static void f_getcmdline(typval_T *argvars, typval_T *rettv);
static void f_getcharmod(typval_T *argvars, typval_T *rettv);
static void f_getchar(typval_T *argvars, typval_T *rettv);
static void f_getbufvar(typval_T *argvars, typval_T *rettv);
static void f_getbufline(typval_T *argvars, typval_T *rettv);
static void f_get(typval_T *argvars, typval_T *rettv);
static void f_garbagecollect(typval_T *argvars, typval_T *rettv);
static void f_function(typval_T *argvars, typval_T *rettv);
static void f_foreground(typval_T *argvars, typval_T *rettv);
static void f_foldtextresult(typval_T *argvars, typval_T *rettv);
static void f_foldtext(typval_T *argvars, typval_T *rettv);
static void f_foldlevel(typval_T *argvars, typval_T *rettv);
static void f_foldclosedend(typval_T *argvars, typval_T *rettv);
static void f_foldclosed(typval_T *argvars, typval_T *rettv);
static void f_fnamemodify(typval_T *argvars, typval_T *rettv);
static void f_fnameescape(typval_T *argvars, typval_T *rettv);
static void f_fmod(typval_T *argvars, typval_T *rettv);
static void f_floor(typval_T *argvars, typval_T *rettv);
static void f_float2nr(typval_T *argvars, typval_T *rettv);
static void f_findfile(typval_T *argvars, typval_T *rettv);
static void f_finddir(typval_T *argvars, typval_T *rettv);
static void f_filter(typval_T *argvars, typval_T *rettv);
static void f_filewritable(typval_T *argvars, typval_T *rettv);
static void f_filereadable(typval_T *argvars, typval_T *rettv);
static void f_feedkeys(typval_T *argvars, typval_T *rettv);
static void f_extend(typval_T *argvars, typval_T *rettv);
static void f_expand(typval_T *argvars, typval_T *rettv);
static void f_exp(typval_T *argvars, typval_T *rettv);
static void f_exists(typval_T *argvars, typval_T *rettv);
static void f_executable(typval_T *argvars, typval_T *rettv);
static void f_eventhandler(typval_T *argvars, typval_T *rettv);
static void f_eval(typval_T *argvars, typval_T *rettv);
static void f_escape(typval_T *argvars, typval_T *rettv);
static void f_empty(typval_T *argvars, typval_T *rettv);
static void f_diff_hlID(typval_T *argvars, typval_T *rettv);
static void f_diff_filler(typval_T *argvars, typval_T *rettv);
static void f_did_filetype(typval_T *argvars, typval_T *rettv);
static void f_delete(typval_T *argvars, typval_T *rettv);
static void f_deepcopy(typval_T *argvars, typval_T *rettv);
static void f_cursor(typval_T *argsvars, typval_T *rettv);
static void f_cscope_connection(typval_T *argvars, typval_T *rettv);
static void f_count(typval_T *argvars, typval_T *rettv);
static void f_cosh(typval_T *argvars, typval_T *rettv);
static void f_cos(typval_T *argvars, typval_T *rettv);
static void f_copy(typval_T *argvars, typval_T *rettv);
static void f_confirm(typval_T *argvars, typval_T *rettv);
static void f_complete_check(typval_T *argvars, typval_T *rettv);
static void f_complete_add(typval_T *argvars, typval_T *rettv);
static void f_complete(typval_T *argvars, typval_T *rettv);
static void f_col(typval_T *argvars, typval_T *rettv);
static void f_clearmatches(typval_T *argvars, typval_T *rettv);
static void f_cindent(typval_T *argvars, typval_T *rettv);
static void f_char2nr(typval_T *argvars, typval_T *rettv);
static void f_changenr(typval_T *argvars, typval_T *rettv);
static void f_ceil(typval_T *argvars, typval_T *rettv);
static void f_call(typval_T *argvars, typval_T *rettv);
static void f_byteidxcomp(typval_T *argvars, typval_T *rettv);
static void f_byteidx(typval_T *argvars, typval_T *rettv);
static void byteidx(typval_T *argvars, typval_T *rettv, int comp);
static void f_byte2line(typval_T *argvars, typval_T *rettv);
static void f_bufwinnr(typval_T *argvars, typval_T *rettv);
static void f_bufnr(typval_T *argvars, typval_T *rettv);
static void f_bufname(typval_T *argvars, typval_T *rettv);
static void f_bufloaded(typval_T *argvars, typval_T *rettv);
static void f_buflisted(typval_T *argvars, typval_T *rettv);
static void f_bufexists(typval_T *argvars, typval_T *rettv);
static void f_browsedir(typval_T *argvars, typval_T *rettv);
static void f_browse(typval_T *argvars, typval_T *rettv);
static void f_atan2(typval_T *argvars, typval_T *rettv);
static void f_atan(typval_T *argvars, typval_T *rettv);
static void f_asin(typval_T *argvars, typval_T *rettv);
static void f_argv(typval_T *argvars, typval_T *rettv);
static void f_argidx(typval_T *argvars, typval_T *rettv);
static void f_argc(typval_T *argvars, typval_T *rettv);
static void f_append(typval_T *argvars, typval_T *rettv);
static void f_and(typval_T *argvars, typval_T *rettv);
static void f_add(typval_T *argvars, typval_T *rettv);
static void f_acos(typval_T *argvars, typval_T *rettv);
static void f_abs(typval_T *argvars, typval_T *rettv);
static int non_zero_arg(typval_T *argvars);
static void emsg_funcname(char *ermsg, char_u *name);
static int call_func(char_u *funcname, int len, typval_T *rettv,
                     int argcount, typval_T *argvars,
                     linenr_T firstline, linenr_T lastline,
                     int *doesrange, int evaluate,
                     dict_T *selfdict);
static int get_func_tv(char_u *name, int len, typval_T *rettv,
                       char_u **arg, linenr_T firstline, linenr_T lastline,
                       int *doesrange, int evaluate,
                       dict_T *selfdict);
static char_u *deref_func_name(char_u *name, int *lenp, int no_autoload);
static int find_internal_func(char_u *name);
static int get_env_tv(char_u **arg, typval_T *rettv, int evaluate);
static int string2float(char_u *text, float_T *value);
static char_u *string_quote(char_u *str, int function);
static char_u *tv2string(typval_T *tv, char_u **tofree, char_u *numbuf,
                         int copyID);
static char_u *echo_string(typval_T *tv, char_u **tofree,
                           char_u *numbuf,
                           int copyID);
static int get_dict_tv(char_u **arg, typval_T *rettv, int evaluate);
static char_u *dict2string(typval_T *tv, int copyID);
static long dict_len(dict_T *d);
static dict_T *dict_copy(dict_T *orig, int deep, int copyID);
static void dictitem_remove(dict_T *dict, dictitem_T *item);
static dictitem_T *dictitem_copy(dictitem_T *org);
static int rettv_dict_alloc(typval_T *rettv);
static int free_unref_items(int copyID);
static int list_join(garray_T *gap, list_T *l, char_u *sep, int echo,
                     int copyID);
static int list_join_inner(garray_T *gap, list_T *l, char_u *sep,
                           int echo_style, int copyID,
                           garray_T *join_gap);
static char_u *list2string(typval_T *tv, int copyID);
static list_T *list_copy(list_T *orig, int deep, int copyID);
static int list_concat(list_T *l1, list_T *l2, typval_T *tv);
static int list_extend(list_T   *l1, list_T *l2, listitem_T *bef);
static void list_append_number(list_T *l, varnumber_T n);
static long list_idx_of_item(list_T *l, listitem_T *item);
static long list_find_nr(list_T *l, long idx, int *errorp);
static int tv_equal(typval_T *tv1, typval_T *tv2, int ic, int recursive);
static int dict_equal(dict_T *d1, dict_T *d2, int ic, int recursive);
static int list_equal(list_T *l1, list_T *l2, int ic, int recursive);
static long list_len(list_T *l);
static void rettv_list_alloc(typval_T *rettv);
static int get_list_tv(char_u **arg, typval_T *rettv, int evaluate);
static int get_lit_string_tv(char_u **arg, typval_T *rettv, int evaluate);
static int get_string_tv(char_u **arg, typval_T *rettv, int evaluate);
static int get_option_tv(char_u **arg, typval_T *rettv, int evaluate);
static int eval_index(char_u **arg, typval_T *rettv, int evaluate,
                      int verbose);
static int eval7(char_u **arg, typval_T *rettv, int evaluate,
                 int want_string);
static int eval6(char_u **arg, typval_T *rettv, int evaluate,
                 int want_string);
static int eval5(char_u **arg, typval_T *rettv, int evaluate);
static int eval4(char_u **arg, typval_T *rettv, int evaluate);
static int eval3(char_u **arg, typval_T *rettv, int evaluate);
static int eval2(char_u **arg, typval_T *rettv, int evaluate);
static int eval1(char_u **arg, typval_T *rettv, int evaluate);
static int eval0(char_u *arg,  typval_T *rettv, char_u **nextcmd,
                 int evaluate);
static int tv_islocked(typval_T *tv);
static void item_lock(typval_T *tv, int deep, int lock);
static int do_lock_var(lval_T *lp, char_u *name_end, int deep, int lock);
static int do_unlet_var(lval_T *lp, char_u *name_end, int forceit);
static void ex_unletlock(exarg_T *eap, char_u *argstart, int deep);
static void list_fix_watch(list_T *l, listitem_T *item);
static int tv_op(typval_T *tv1, typval_T *tv2, char_u  *op);
static void set_var_lval(lval_T *lp, char_u *endp, typval_T *rettv,
                         int copy,
                         char_u *op);
static void clear_lval(lval_T *lp);
static char_u *get_lval(char_u *name, typval_T *rettv, lval_T *lp,
                        int unlet, int skip, int flags,
                        int fne_flags);
static int check_changedtick(char_u *arg);
static char_u *ex_let_one(char_u *arg, typval_T *tv, int copy,
                          char_u *endchars, char_u *op);
static char_u *list_arg_vars(exarg_T *eap, char_u *arg, int *first);
static void list_func_vars(int *first);
static void list_script_vars(int *first);
static void list_vim_vars(int *first);
static void list_tab_vars(int *first);
static void list_win_vars(int *first);
static void list_buf_vars(int *first);
static void list_glob_vars(int *first);
static void list_hashtable_vars(hashtab_T *ht, char_u *prefix,
                                        int empty,
                                        int *first);
static char_u *skip_var_one(char_u *arg);
static char_u *skip_var_list(char_u *arg, int *var_count,
                                     int *semicolon);
static int ex_let_vars(char_u *arg, typval_T *tv, int copy,
                       int semicolon, int var_count,
                       char_u *nextchars);
static void restore_vimvar(int idx, typval_T *save_tv);
static void prepare_vimvar(int idx, typval_T *save_tv);
static void apply_job_autocmds(Job *job, char *name, char *type, char *str);
static void on_job_exit(Job *job, void *data);
static void on_job_stdout(RStream *rstream, void *data, bool eof);
static void on_job_stderr(RStream *rstream, void *data, bool eof);
static void on_job_data(RStream *rstream, void *data, bool eof, char *type);
static bool builtin_function(char_u *name, int len);
static void do_sort_uniq(typval_T *argvars, typval_T *rettv, bool sort);
