#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int add_menu_path(char_u *menu_path, vimmenu_T *menuarg, int *pri_tab, char_u *call_data);
static int menu_nable_recurse(vimmenu_T *menu, char_u *name, int modes, int enable);
static int remove_menu(vimmenu_T **menup, char_u *name, int modes, int silent);
static void free_menu(vimmenu_T **menup);
static void free_menu_string(vimmenu_T *menu, int idx);
static int show_menus(char_u *path_name, int modes);
static void show_menus_recursive(vimmenu_T *menu, int modes, int depth);
static int menu_name_equal(char_u *name, vimmenu_T *menu);
static int menu_namecmp(char_u *name, char_u *mname);
static int get_menu_cmd_modes(char_u *cmd, int forceit, int *noremap, int *unmenu);
static char_u *popup_mode_name(char_u *name, int idx);
static char_u *menu_text(char_u *str, int *mnemonic, char_u **actext);
static int menu_is_hidden(char_u *name);
static int menu_is_tearoff(char_u *name);
static char_u *menu_skip_part(char_u *p);
static char_u *menutrans_lookup(char_u *name, int len);
static void menu_unescape_name(char_u *name);
static char_u *menu_translate_tab_and_shift(char_u *arg_start);
#include "func_attr.h"
