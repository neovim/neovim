int mch_has_wildcard(char_u *p);
int mch_has_exp_wildcard(char_u *p);
int mch_expand_wildcards(int num_pat, char_u **pat, int *num_file,
                         char_u ***file,
                         int flags);
void mch_set_shellsize(void);
int mch_get_shellsize(void);
void check_mouse_termcode(void);
void mch_setmouse(int on);
void get_stty(void);
void mch_settmode(int tmode);
void mch_exit(int r);
void mch_early_init(void);
int mch_nodetype(char_u *name);
void mch_hide(char_u *name);
void mch_free_acl(vim_acl_T aclent);
void mch_set_acl(char_u *fname, vim_acl_T aclent);
vim_acl_T mch_get_acl(char_u *fname);
int vim_is_fastterm(char_u *name);
int vim_is_vt300(char_u *name);
int vim_is_iris(char_u *name);
int use_xterm_mouse(void);
int use_xterm_like_mouse(char_u *name);
int vim_is_xterm(char_u *name);
void mch_restore_title(int which);
void mch_settitle(char_u *title, char_u *icon);
int mch_can_restore_icon(void);
int mch_can_restore_title(void);
void mch_init(void);
void mch_suspend(void);
void mch_write(char_u *s, int len);
void mch_free_mem(void);
int mch_libcall(char_u *libname, char_u *funcname, char_u *argstring,
                int argint, char_u **string_result,
                int *number_result);
void mch_copy_sec(char_u *from_file, char_u *to_file);
void fname_case(char_u *name, int len);
void slash_adjust(char_u *p);
