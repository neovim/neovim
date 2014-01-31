/* menu.c */
void ex_menu __ARGS((exarg_T *eap));
char_u *set_context_in_menu_cmd __ARGS((expand_T *xp, char_u *cmd, char_u *arg,
                                        int forceit));
char_u *get_menu_name __ARGS((expand_T *xp, int idx));
char_u *get_menu_names __ARGS((expand_T *xp, int idx));
char_u *menu_name_skip __ARGS((char_u *name));
int get_menu_index __ARGS((vimmenu_T *menu, int state));
int menu_is_menubar __ARGS((char_u *name));
int menu_is_popup __ARGS((char_u *name));
int menu_is_child_of_popup __ARGS((vimmenu_T *menu));
int menu_is_toolbar __ARGS((char_u *name));
int menu_is_separator __ARGS((char_u *name));
int check_menu_pointer __ARGS((vimmenu_T *root, vimmenu_T *menu_to_check));
void gui_create_initial_menus __ARGS((vimmenu_T *menu));
void gui_update_menus __ARGS((int modes));
int gui_is_menu_shortcut __ARGS((int key));
void gui_show_popupmenu __ARGS((void));
void gui_mch_toggle_tearoffs __ARGS((int enable));
void ex_emenu __ARGS((exarg_T *eap));
vimmenu_T *gui_find_menu __ARGS((char_u *path_name));
void ex_menutranslate __ARGS((exarg_T *eap));
/* vim: set ft=c : */
