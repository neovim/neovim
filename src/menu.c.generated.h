static char_u *menu_translate_tab_and_shift(char_u *arg_start);
static void menu_unescape_name(char_u  *p);
static char_u *menutrans_lookup(char_u *name, int len);
static char_u *menu_skip_part(char_u *p);
static int menu_is_hidden(char_u *name);
static char_u *menu_text(char_u *text, int *mnemonic, char_u **actext);
static char_u *popup_mode_name(char_u *name, int idx);
static int get_menu_cmd_modes(char_u *, int, int *, int *);
static int menu_namecmp(char_u *name, char_u *mname);
static int menu_name_equal(char_u *name, vimmenu_T *menu);
static void show_menus_recursive(vimmenu_T *, int, int);
static int show_menus(char_u *, int);
static void free_menu_string(vimmenu_T *, int);
static void free_menu(vimmenu_T **menup);
static int remove_menu(vimmenu_T **, char_u *, int, int silent);
static int menu_nable_recurse(vimmenu_T *menu, char_u *name, int modes,
                              int enable);
static int add_menu_path(char_u *, vimmenu_T *, int *, char_u *);
static int menu_is_tearoff(char_u *name);
