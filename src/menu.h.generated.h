#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
void ex_menu(exarg_T *eap);
char_u *set_context_in_menu_cmd(expand_T *xp, char_u *cmd, char_u *arg, int forceit);
char_u *get_menu_name(expand_T *xp, int idx);
char_u *get_menu_names(expand_T *xp, int idx);
char_u *menu_name_skip(char_u *name);
int menu_is_menubar(char_u *name);
int menu_is_popup(char_u *name);
int menu_is_toolbar(char_u *name);
int menu_is_separator(char_u *name);
void ex_emenu(exarg_T *eap);
vimmenu_T *gui_find_menu(char_u *path_name);
void ex_menutranslate(exarg_T *eap);
#include "func_attr.h"
