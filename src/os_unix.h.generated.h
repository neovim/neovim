#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
void mch_write(char_u *s, int len);
void mch_startjmp();
void mch_endjmp();
void mch_suspend();
void mch_init();
int mch_can_restore_title();
int mch_can_restore_icon();
void mch_settitle(char_u *title, char_u *icon);
void mch_restore_title(int which);
int vim_is_xterm(char_u *name);
int use_xterm_like_mouse(char_u *name);
int use_xterm_mouse();
int vim_is_iris(char_u *name);
int vim_is_vt300(char_u *name);
int vim_is_fastterm(char_u *name);
void fname_case(char_u *name, int len);
void mch_copy_sec(char_u *from_file, char_u *to_file);
vim_acl_T mch_get_acl(char_u *fname);
void mch_set_acl(char_u *fname, vim_acl_T aclent);
void mch_free_acl(vim_acl_T aclent);
void mch_hide(char_u *name);
int mch_nodetype(char_u *name);
void mch_early_init();
void mch_free_mem();
void mch_exit(int r);
void mch_settmode(int tmode);
void get_stty();
void mch_setmouse(int on);
void check_mouse_termcode();
int mch_get_shellsize();
void mch_set_shellsize();
int mch_expand_wildcards(int num_pat, char_u **pat, int *num_file, char_u ***file, int flags);
int mch_has_exp_wildcard(char_u *p);
int mch_has_wildcard(char_u *p);
int mch_libcall(char_u *libname, char_u *funcname, char_u *argstring, int argint, char_u **string_result, int *number_result);
#include "func_attr.h"
