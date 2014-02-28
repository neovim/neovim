#ifndef NEOVIM_MISC2_H
#define NEOVIM_MISC2_H
/* misc2.c */
int virtual_active __ARGS((void));
int getviscol __ARGS((void));
int getviscol2 __ARGS((colnr_T col, colnr_T coladd));
int coladvance_force __ARGS((colnr_T wcol));
int coladvance __ARGS((colnr_T wcol));
int getvpos __ARGS((pos_T *pos, colnr_T wcol));
int inc_cursor __ARGS((void));
int inc __ARGS((pos_T *lp));
int incl __ARGS((pos_T *lp));
int dec_cursor __ARGS((void));
int dec __ARGS((pos_T *lp));
int decl __ARGS((pos_T *lp));
linenr_T get_cursor_rel_lnum __ARGS((win_T *wp, linenr_T lnum));
void check_cursor_lnum __ARGS((void));
void check_cursor_col __ARGS((void));
void check_cursor_col_win __ARGS((win_T *win));
void check_cursor __ARGS((void));
void adjust_cursor_col __ARGS((void));
int leftcol_changed __ARGS((void));
void vim_mem_profile_dump __ARGS((void));
char_u *alloc __ARGS((unsigned size));
char_u *alloc_clear __ARGS((unsigned size));
char_u *alloc_check __ARGS((unsigned size));
char_u *lalloc_clear __ARGS((long_u size, int message));
char_u *lalloc __ARGS((long_u size, int message));
void *mem_realloc __ARGS((void *ptr, size_t size));
void do_outofmem_msg __ARGS((long_u size));
void free_all_mem __ARGS((void));
char_u *vim_strsave __ARGS((char_u *string));
char_u *vim_strnsave __ARGS((char_u *string, int len));
char_u *vim_strsave_escaped __ARGS((char_u *string, char_u *esc_chars));
char_u *vim_strsave_escaped_ext __ARGS((char_u *string, char_u *esc_chars,
                                        int cc,
                                        int bsl));
int csh_like_shell __ARGS((void));
char_u *vim_strsave_shellescape __ARGS((char_u *string, int do_special));
char_u *vim_strsave_up __ARGS((char_u *string));
char_u *vim_strnsave_up __ARGS((char_u *string, int len));
void vim_strup __ARGS((char_u *p));
char_u *strup_save __ARGS((char_u *orig));
void copy_spaces __ARGS((char_u *ptr, size_t count));
void copy_chars __ARGS((char_u *ptr, size_t count, int c));
void del_trailing_spaces __ARGS((char_u *ptr));
void vim_strncpy __ARGS((char_u *to, char_u *from, size_t len));
void vim_strcat __ARGS((char_u *to, char_u *from, size_t tosize));
int copy_option_part __ARGS((char_u **option, char_u *buf, int maxlen,
                             char *sep_chars));
void vim_free __ARGS((void *x));
int vim_stricmp __ARGS((char *s1, char *s2));
int vim_strnicmp __ARGS((char *s1, char *s2, size_t len));
char_u *vim_strchr __ARGS((char_u *string, int c));
char_u *vim_strbyte __ARGS((char_u *string, int c));
char_u *vim_strrchr __ARGS((char_u *string, int c));
int vim_isspace __ARGS((int x));
int name_to_mod_mask __ARGS((int c));
int simplify_key __ARGS((int key, int *modifiers));
int handle_x_keys __ARGS((int key));
char_u *get_special_key_name __ARGS((int c, int modifiers));
int trans_special __ARGS((char_u **srcp, char_u *dst, int keycode));
int find_special_key __ARGS((char_u **srcp, int *modp, int keycode,
                             int keep_x_key));
int extract_modifiers __ARGS((int key, int *modp));
int find_special_key_in_table __ARGS((int c));
int get_special_key_code __ARGS((char_u *name));
char_u *get_key_name __ARGS((int i));
int get_mouse_button __ARGS((int code, int *is_click, int *is_drag));
int get_pseudo_mouse_code __ARGS((int button, int is_click, int is_drag));
int get_fileformat __ARGS((buf_T *buf));
int get_fileformat_force __ARGS((buf_T *buf, exarg_T *eap));
void set_fileformat __ARGS((int t, int opt_flags));
int default_fileformat __ARGS((void));
int call_shell __ARGS((char_u *cmd, int opt));
int get_real_state __ARGS((void));
int after_pathsep __ARGS((char_u *b, char_u *p));
int same_directory __ARGS((char_u *f1, char_u *f2));
int vim_chdirfile __ARGS((char_u *fname));
int illegal_slash __ARGS((char *name));
char_u *parse_shape_opt __ARGS((int what));
int get_shape_idx __ARGS((int mouse));
void update_mouseshape __ARGS((int shape_idx));
int crypt_method_from_string __ARGS((char_u *s));
int get_crypt_method __ARGS((buf_T *buf));
void set_crypt_method __ARGS((buf_T *buf, int method));
void crypt_push_state __ARGS((void));
void crypt_pop_state __ARGS((void));
void crypt_encode __ARGS((char_u *from, size_t len, char_u *to));
void crypt_decode __ARGS((char_u *ptr, long len));
void crypt_init_keys __ARGS((char_u *passwd));
void free_crypt_key __ARGS((char_u *key));
char_u *get_crypt_key __ARGS((int store, int twice));
void *vim_findfile_init __ARGS((char_u *path, char_u *filename, char_u *
                                stopdirs, int level, int free_visited,
                                int find_what, void *search_ctx_arg,
                                int tagfile,
                                char_u *rel_fname));
char_u *vim_findfile_stopdir __ARGS((char_u *buf));
void vim_findfile_cleanup __ARGS((void *ctx));
char_u *vim_findfile __ARGS((void *search_ctx_arg));
void vim_findfile_free_visited __ARGS((void *search_ctx_arg));
char_u *find_file_in_path __ARGS((char_u *ptr, int len, int options, int first,
                                  char_u *rel_fname));
char_u *find_directory_in_path __ARGS((char_u *ptr, int len, int options,
                                       char_u *rel_fname));
char_u *find_file_in_path_option __ARGS((char_u *ptr, int len, int options,
                                         int first, char_u *path_option,
                                         int find_what, char_u *rel_fname,
                                         char_u *suffixes));
int vim_chdir __ARGS((char_u *new_dir));
int get_user_name __ARGS((char_u *buf, int len));
void sort_strings __ARGS((char_u **files, int count));
int pathcmp __ARGS((const char *p, const char *q, int maxlen));
int filewritable __ARGS((char_u *fname));
int emsg3 __ARGS((char_u *s, char_u *a1, char_u *a2));
int emsgn __ARGS((char_u *s, long n));
int get2c __ARGS((FILE *fd));
int get3c __ARGS((FILE *fd));
int get4c __ARGS((FILE *fd));
time_t get8ctime __ARGS((FILE *fd));
char_u *read_string __ARGS((FILE *fd, int cnt));
int put_bytes __ARGS((FILE *fd, long_u nr, int len));
void put_time __ARGS((FILE *fd, time_t the_time));
int has_non_ascii __ARGS((char_u *s));
/* vim: set ft=c : */
#endif /* NEOVIM_MISC2_H */
