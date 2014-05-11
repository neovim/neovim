#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
int name_to_mod_mask(int c);
int simplify_key(int key, int *modifiers);
int handle_x_keys(int key);
char_u *get_special_key_name(int c, int modifiers);
int trans_special(char_u **srcp, char_u *dst, int keycode);
int find_special_key(char_u **srcp, int *modp, int keycode, int keep_x_key);
int extract_modifiers(int key, int *modp);
int find_special_key_in_table(int c);
int get_special_key_code(char_u *name);
char_u *get_key_name(int i);
int get_mouse_button(int code, int *is_click, int *is_drag);
int get_pseudo_mouse_code(int button, int is_click, int is_drag);
#include "func_attr.h"
