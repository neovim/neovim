// Code for menus.  Used for the GUI and 'wildmenu'.
// GUI/Motif support by Robert Webb

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/getchar_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memory.h"
#include "nvim/menu.h"
#include "nvim/menu_defs.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/vim_defs.h"

#define MENUDEPTH   10          // maximum depth of menus

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "menu.c.generated.h"
#endif

/// The character for each menu mode
static char *menu_mode_chars[] = { "n", "v", "s", "o", "i", "c", "tl", "t" };

static const char e_notsubmenu[] = N_("E327: Part of menu-item path is not sub-menu");
static const char e_nomenu[] = N_("E329: No menu \"%s\"");

// Return true if "name" is a window toolbar menu name.
static bool menu_is_winbar(const char *const name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return (strncmp(name, "WinBar", 6) == 0);
}

static vimmenu_T **get_root_menu(const char *const name)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return &root_menu;
}

/// Do the :menu command and relatives.
/// @param eap Ex command arguments
void ex_menu(exarg_T *eap)
{
  char *map_to;            // command mapped to the menu entry
  int noremap;
  bool silent = false;
  bool unmenu;
  char *map_buf;
  char *p;
  int i;
  int pri_tab[MENUDEPTH + 1];
  TriState enable = kNone;        // kTrue for "menu enable",
                                  // kFalse for "menu disable
  vimmenu_T menuarg;

  int modes = get_menu_cmd_modes(eap->cmd, eap->forceit, &noremap, &unmenu);
  char *arg = eap->arg;

  while (true) {
    if (strncmp(arg, "<script>", 8) == 0) {
      noremap = REMAP_SCRIPT;
      arg = skipwhite(arg + 8);
      continue;
    }
    if (strncmp(arg, "<silent>", 8) == 0) {
      silent = true;
      arg = skipwhite(arg + 8);
      continue;
    }
    if (strncmp(arg, "<special>", 9) == 0) {
      // Ignore obsolete "<special>" modifier.
      arg = skipwhite(arg + 9);
      continue;
    }
    break;
  }

  // Locate an optional "icon=filename" argument
  // TODO(nvim): Currently this is only parsed. Should expose it to UIs.
  if (strncmp(arg, "icon=", 5) == 0) {
    arg += 5;
    while (*arg != NUL && *arg != ' ') {
      if (*arg == '\\') {
        STRMOVE(arg, arg + 1);
      }
      MB_PTR_ADV(arg);
    }
    if (*arg != NUL) {
      *arg++ = NUL;
      arg = skipwhite(arg);
    }
  }

  // Fill in the priority table.
  for (p = arg; *p; p++) {
    if (!ascii_isdigit(*p) && *p != '.') {
      break;
    }
  }
  if (ascii_iswhite(*p)) {
    for (i = 0; i < MENUDEPTH && !ascii_iswhite(*arg); i++) {
      pri_tab[i] = getdigits_int(&arg, false, 0);
      if (pri_tab[i] == 0) {
        pri_tab[i] = 500;
      }
      if (*arg == '.') {
        arg++;
      }
    }
    arg = skipwhite(arg);
  } else if (eap->addr_count && eap->line2 != 0) {
    pri_tab[0] = eap->line2;
    i = 1;
  } else {
    i = 0;
  }
  while (i < MENUDEPTH) {
    pri_tab[i++] = 500;
  }
  pri_tab[MENUDEPTH] = -1;              // mark end of the table

  // Check for "disable" or "enable" argument.
  if (strncmp(arg, "enable", 6) == 0 && ascii_iswhite(arg[6])) {
    enable = kTrue;
    arg = skipwhite(arg + 6);
  } else if (strncmp(arg, "disable", 7) == 0 && ascii_iswhite(arg[7])) {
    enable = kFalse;
    arg = skipwhite(arg + 7);
  }

  // If there is no argument, display all menus.
  if (*arg == NUL) {
    show_menus(arg, modes);
    return;
  }

  char *menu_path = arg;
  if (*menu_path == '.') {
    semsg(_(e_invarg2), menu_path);
    goto theend;
  }

  map_to = menu_translate_tab_and_shift(arg);

  // If there is only a menu name, display menus with that name.
  if (*map_to == NUL && !unmenu && enable == kNone) {
    show_menus(menu_path, modes);
    goto theend;
  } else if (*map_to != NUL && (unmenu || enable != kNone)) {
    semsg(_(e_trailing_arg), map_to);
    goto theend;
  }

  vimmenu_T **root_menu_ptr = get_root_menu(menu_path);

  if (enable != kNone) {
    // Change sensitivity of the menu.
    // For the PopUp menu, remove a menu for each mode separately.
    // Careful: menu_enable_recurse() changes menu_path.
    if (strcmp(menu_path, "*") == 0) {          // meaning: do all menus
      menu_path = "";
    }

    if (menu_is_popup(menu_path)) {
      for (i = 0; i < MENU_INDEX_TIP; i++) {
        if (modes & (1 << i)) {
          p = popup_mode_name(menu_path, i);
          menu_enable_recurse(*root_menu_ptr, p, MENU_ALL_MODES, enable);
          xfree(p);
        }
      }
    }
    menu_enable_recurse(*root_menu_ptr, menu_path, modes, enable);
  } else if (unmenu) {
    // Delete menu(s).
    if (strcmp(menu_path, "*") == 0) {          // meaning: remove all menus
      menu_path = "";
    }

    // For the PopUp menu, remove a menu for each mode separately.
    if (menu_is_popup(menu_path)) {
      for (i = 0; i < MENU_INDEX_TIP; i++) {
        if (modes & (1 << i)) {
          p = popup_mode_name(menu_path, i);
          remove_menu(root_menu_ptr, p, MENU_ALL_MODES, true);
          xfree(p);
        }
      }
    }

    // Careful: remove_menu() changes menu_path
    remove_menu(root_menu_ptr, menu_path, modes, false);
  } else {
    // Add menu(s).
    // Replace special key codes.
    if (STRICMP(map_to, "<nop>") == 0) {        // "<Nop>" means nothing
      map_to = "";
      map_buf = NULL;
    } else if (modes & MENU_TIP_MODE) {
      map_buf = NULL;  // Menu tips are plain text.
    } else {
      map_buf = NULL;
      map_to = replace_termcodes(map_to, strlen(map_to), &map_buf, 0,
                                 REPTERM_DO_LT, NULL, p_cpo);
    }
    menuarg.modes = modes;
    menuarg.noremap[0] = noremap;
    menuarg.silent[0] = silent;
    add_menu_path(menu_path, &menuarg, pri_tab, map_to);

    // For the PopUp menu, add a menu for each mode separately.
    if (menu_is_popup(menu_path)) {
      for (i = 0; i < MENU_INDEX_TIP; i++) {
        if (modes & (1 << i)) {
          p = popup_mode_name(menu_path, i);
          // Include all modes, to make ":amenu" work
          menuarg.modes = modes;
          add_menu_path(p, &menuarg, pri_tab, map_to);
          xfree(p);
        }
      }
    }

    xfree(map_buf);
  }

  ui_call_update_menu();

theend:
  ;
}

/// Add the menu with the given name to the menu hierarchy
///
/// @param[out]  menuarg menu entry
/// @param[] pri_tab priority table
/// @param[in] call_data Right hand side command
static int add_menu_path(const char *const menu_path, vimmenu_T *menuarg, const int *const pri_tab,
                         const char *const call_data)
{
  int modes = menuarg->modes;
  vimmenu_T *menu = NULL;
  vimmenu_T **lower_pri;
  char *dname;
  int pri_idx = 0;
  int old_modes = 0;
  char *en_name;

  // Make a copy so we can stuff around with it, since it could be const
  char *path_name = xstrdup(menu_path);
  vimmenu_T **root_menu_ptr = get_root_menu(menu_path);
  vimmenu_T **menup = root_menu_ptr;
  vimmenu_T *parent = NULL;
  char *name = path_name;
  while (*name) {
    // Get name of this element in the menu hierarchy, and the simplified
    // name (without mnemonic and accelerator text).
    char *next_name = menu_name_skip(name);
    char *map_to = menutrans_lookup(name, (int)strlen(name));
    if (map_to != NULL) {
      en_name = name;
      name = map_to;
    } else {
      en_name = NULL;
    }
    dname = menu_text(name, NULL, NULL);
    if (*dname == NUL) {
      // Only a mnemonic or accelerator is not valid.
      emsg(_("E792: Empty menu name"));
      goto erret;
    }

    // See if it's already there
    lower_pri = menup;
    menu = *menup;
    while (menu != NULL) {
      if (menu_name_equal(name, menu) || menu_name_equal(dname, menu)) {
        if (*next_name == NUL && menu->children != NULL) {
          if (!sys_menu) {
            emsg(_("E330: Menu path must not lead to a sub-menu"));
          }
          goto erret;
        }
        if (*next_name != NUL && menu->children == NULL) {
          if (!sys_menu) {
            emsg(_(e_notsubmenu));
          }
          goto erret;
        }
        break;
      }
      menup = &menu->next;

      // Count menus, to find where this one needs to be inserted.
      // Ignore menus that are not in the menubar (PopUp and Toolbar)
      if (parent != NULL || menu_is_menubar(menu->name)) {
        if (menu->priority <= pri_tab[pri_idx]) {
          lower_pri = menup;
        }
      }
      menu = menu->next;
    }

    if (menu == NULL) {
      if (*next_name == NUL && parent == NULL) {
        emsg(_("E331: Must not add menu items directly to menu bar"));
        goto erret;
      }

      if (menu_is_separator(dname) && *next_name != NUL) {
        emsg(_("E332: Separator cannot be part of a menu path"));
        goto erret;
      }

      // Not already there, so let's add it
      menu = xcalloc(1, sizeof(vimmenu_T));

      menu->modes = modes;
      menu->enabled = MENU_ALL_MODES;
      menu->name = xstrdup(name);
      // separate mnemonic and accelerator text from actual menu name
      menu->dname = menu_text(name, &menu->mnemonic, &menu->actext);
      if (en_name != NULL) {
        menu->en_name = xstrdup(en_name);
        menu->en_dname = menu_text(en_name, NULL, NULL);
      } else {
        menu->en_name = NULL;
        menu->en_dname = NULL;
      }
      menu->priority = pri_tab[pri_idx];
      menu->parent = parent;

      // Add after menu that has lower priority.
      menu->next = *lower_pri;
      *lower_pri = menu;

      old_modes = 0;
    } else {
      old_modes = menu->modes;

      // If this menu option was previously only available in other
      // modes, then make sure it's available for this one now
      // Also enable a menu when it's created or changed.
      {
        menu->modes |= modes;
        menu->enabled |= modes;
      }
    }

    menup = &menu->children;
    parent = menu;
    name = next_name;
    XFREE_CLEAR(dname);
    if (pri_tab[pri_idx + 1] != -1) {
      pri_idx++;
    }
  }
  xfree(path_name);

  // Only add system menu items which have not been defined yet.
  // First check if this was an ":amenu".
  int amenu = ((modes & (MENU_NORMAL_MODE | MENU_INSERT_MODE)) ==
               (MENU_NORMAL_MODE | MENU_INSERT_MODE));
  if (sys_menu) {
    modes &= ~old_modes;
  }

  if (menu != NULL && modes) {
    char *p = (call_data == NULL) ? NULL : xstrdup(call_data);

    // loop over all modes, may add more than one
    for (int i = 0; i < MENU_MODES; i++) {
      if (modes & (1 << i)) {
        // free any old menu
        free_menu_string(menu, i);

        // For "amenu", may insert an extra character.
        // Don't do this for "<Nop>".
        char c = 0;
        char d = 0;
        if (amenu && call_data != NULL && *call_data != NUL) {
          switch (1 << i) {
          case MENU_VISUAL_MODE:
          case MENU_SELECT_MODE:
          case MENU_OP_PENDING_MODE:
          case MENU_CMDLINE_MODE:
            c = Ctrl_C;
            break;
          case MENU_INSERT_MODE:
            c = Ctrl_BSL;
            d = Ctrl_O;
            break;
          }
        }

        if (c != 0) {
          menu->strings[i] = xmalloc(strlen(call_data) + 5);
          menu->strings[i][0] = c;
          if (d == 0) {
            STRCPY(menu->strings[i] + 1, call_data);
          } else {
            menu->strings[i][1] = d;
            STRCPY(menu->strings[i] + 2, call_data);
          }
          if (c == Ctrl_C) {
            int len = (int)strlen(menu->strings[i]);

            menu->strings[i][len] = Ctrl_BSL;
            menu->strings[i][len + 1] = Ctrl_G;
            menu->strings[i][len + 2] = NUL;
          }
        } else {
          menu->strings[i] = p;
        }
        menu->noremap[i] = menuarg->noremap[0];
        menu->silent[i] = menuarg->silent[0];
      }
    }
  }
  return OK;

erret:
  xfree(path_name);
  xfree(dname);

  // Delete any empty submenu we added before discovering the error.  Repeat
  // for higher levels.
  while (parent != NULL && parent->children == NULL) {
    if (parent->parent == NULL) {
      menup = root_menu_ptr;
    } else {
      menup = &parent->parent->children;
    }
    for (; *menup != NULL && *menup != parent; menup = &((*menup)->next)) {}
    if (*menup == NULL) {   // safety check
      break;
    }
    parent = parent->parent;
    free_menu(menup);
  }
  return FAIL;
}

// Set the (sub)menu with the given name to enabled or disabled.
// Called recursively.
static int menu_enable_recurse(vimmenu_T *menu, char *name, int modes, int enable)
{
  if (menu == NULL) {
    return OK;                  // Got to bottom of hierarchy
  }
  // Get name of this element in the menu hierarchy
  char *p = menu_name_skip(name);

  // Find the menu
  while (menu != NULL) {
    if (*name == NUL || *name == '*' || menu_name_equal(name, menu)) {
      if (*p != NUL) {
        if (menu->children == NULL) {
          emsg(_(e_notsubmenu));
          return FAIL;
        }
        if (menu_enable_recurse(menu->children, p, modes, enable) == FAIL) {
          return FAIL;
        }
      } else if (enable) {
        menu->enabled |= modes;
      } else {
        menu->enabled &= ~modes;
      }

      // When name is empty, we are doing all menu items for the given
      // modes, so keep looping, otherwise we are just doing the named
      // menu item (which has been found) so break here.
      if (*name != NUL && *name != '*') {
        break;
      }
    }
    menu = menu->next;
  }
  if (*name != NUL && *name != '*' && menu == NULL) {
    semsg(_(e_nomenu), name);
    return FAIL;
  }

  return OK;
}

/// Remove the (sub)menu with the given name from the menu hierarchy
/// Called recursively.
///
/// @param silent  don't give error messages
static int remove_menu(vimmenu_T **menup, char *name, int modes, bool silent)
{
  vimmenu_T *menu;

  if (*menup == NULL) {
    return OK;                  // Got to bottom of hierarchy
  }
  // Get name of this element in the menu hierarchy
  char *p = menu_name_skip(name);

  // Find the menu
  while ((menu = *menup) != NULL) {
    if (*name == NUL || menu_name_equal(name, menu)) {
      if (*p != NUL && menu->children == NULL) {
        if (!silent) {
          emsg(_(e_notsubmenu));
        }
        return FAIL;
      }
      if ((menu->modes & modes) != 0x0) {
        if (remove_menu(&menu->children, p, modes, silent) == FAIL) {
          return FAIL;
        }
      } else if (*name != NUL) {
        if (!silent) {
          emsg(_(e_menu_only_exists_in_another_mode));
        }
        return FAIL;
      }

      // When name is empty, we are removing all menu items for the given
      // modes, so keep looping, otherwise we are just removing the named
      // menu item (which has been found) so break here.
      if (*name != NUL) {
        break;
      }

      // Remove the menu item for the given mode[s].  If the menu item
      // is no longer valid in ANY mode, delete it
      menu->modes &= ~modes;
      if (modes & MENU_TIP_MODE) {
        free_menu_string(menu, MENU_INDEX_TIP);
      }
      if ((menu->modes & MENU_ALL_MODES) == 0) {
        free_menu(menup);
      } else {
        menup = &menu->next;
      }
    } else {
      menup = &menu->next;
    }
  }
  if (*name != NUL) {
    if (menu == NULL) {
      if (!silent) {
        semsg(_(e_nomenu), name);
      }
      return FAIL;
    }

    // Recalculate modes for menu based on the new updated children
    menu->modes &= ~modes;
    vimmenu_T *child = menu->children;
    for (; child != NULL; child = child->next) {
      menu->modes |= child->modes;
    }
    if (modes & MENU_TIP_MODE) {
      free_menu_string(menu, MENU_INDEX_TIP);
    }
    if ((menu->modes & MENU_ALL_MODES) == 0) {
      // The menu item is no longer valid in ANY mode, so delete it
      *menup = menu;
      free_menu(menup);
    }
  }

  return OK;
}

// Free the given menu structure and remove it from the linked list.
static void free_menu(vimmenu_T **menup)
{
  vimmenu_T *menu = *menup;

  *menup = menu->next;
  xfree(menu->name);
  xfree(menu->dname);
  xfree(menu->en_name);
  xfree(menu->en_dname);
  xfree(menu->actext);
  for (int i = 0; i < MENU_MODES; i++) {
    free_menu_string(menu, i);
  }
  xfree(menu);
}

// Free the menu->string with the given index.
static void free_menu_string(vimmenu_T *menu, int idx)
{
  int count = 0;

  for (int i = 0; i < MENU_MODES; i++) {
    if (menu->strings[i] == menu->strings[idx]) {
      count++;
    }
  }
  if (count == 1) {
    xfree(menu->strings[idx]);
  }
  menu->strings[idx] = NULL;
}

/// Export menus
///
/// @param[in] menu if null, starts from root_menu
/// @param modes, a choice of \ref MENU_MODES
/// @return dict with name/commands
/// @see show_menus_recursive
/// @see menu_get
static dict_T *menu_get_recursive(const vimmenu_T *menu, int modes)
{
  if (!menu || (menu->modes & modes) == 0x0) {
    return NULL;
  }

  dict_T *dict = tv_dict_alloc();
  tv_dict_add_str(dict, S_LEN("name"), menu->dname);
  tv_dict_add_nr(dict, S_LEN("priority"), menu->priority);
  tv_dict_add_nr(dict, S_LEN("hidden"), menu_is_hidden(menu->dname));

  if (menu->mnemonic) {
    char buf[MB_MAXCHAR + 1] = { 0 };  // > max value of utf8_char2bytes
    utf_char2bytes(menu->mnemonic, buf);
    tv_dict_add_str(dict, S_LEN("shortcut"), buf);
  }

  if (menu->actext) {
    tv_dict_add_str(dict, S_LEN("actext"), menu->actext);
  }

  if (menu->modes & MENU_TIP_MODE && menu->strings[MENU_INDEX_TIP]) {
    tv_dict_add_str(dict, S_LEN("tooltip"),
                    menu->strings[MENU_INDEX_TIP]);
  }

  if (!menu->children) {
    // leaf menu
    dict_T *commands = tv_dict_alloc();
    tv_dict_add_dict(dict, S_LEN("mappings"), commands);

    for (int bit = 0; bit < MENU_MODES; bit++) {
      if ((menu->modes & modes & (1 << bit)) != 0) {
        dict_T *impl = tv_dict_alloc();
        tv_dict_add_allocated_str(impl, S_LEN("rhs"),
                                  str2special_save(menu->strings[bit], false, false));
        tv_dict_add_nr(impl, S_LEN("silent"), menu->silent[bit]);
        tv_dict_add_nr(impl, S_LEN("enabled"),
                       (menu->enabled & (1 << bit)) ? 1 : 0);
        tv_dict_add_nr(impl, S_LEN("noremap"),
                       (menu->noremap[bit] & REMAP_NONE) ? 1 : 0);
        tv_dict_add_nr(impl, S_LEN("sid"),
                       (menu->noremap[bit] & REMAP_SCRIPT) ? 1 : 0);
        tv_dict_add_dict(commands, menu_mode_chars[bit], 1, impl);
      }
    }
  } else {
    // visit recursively all children
    list_T *const children_list = tv_list_alloc(kListLenMayKnow);
    for (menu = menu->children; menu != NULL; menu = menu->next) {
      dict_T *d = menu_get_recursive(menu, modes);
      if (tv_dict_len(d) > 0) {
        tv_list_append_dict(children_list, d);
      }
    }
    tv_dict_add_list(dict, S_LEN("submenus"), children_list);
  }
  return dict;
}

/// Export menus matching path \p path_name
///
/// @param path_name
/// @param modes supported modes, see \ref MENU_MODES
/// @param[in,out] list must be allocated
/// @return false if could not find path_name
bool menu_get(char *const path_name, int modes, list_T *list)
{
  vimmenu_T *menu = find_menu(*get_root_menu(path_name), path_name, modes);
  if (!menu) {
    return false;
  }
  for (; menu != NULL; menu = menu->next) {
    dict_T *d = menu_get_recursive(menu, modes);
    if (d && tv_dict_len(d) > 0) {
      tv_list_append_dict(list, d);
    }
    if (*path_name != NUL) {
      // If a (non-empty) path query was given, only the first node in the
      // find_menu() result is relevant.  Else we want all nodes.
      break;
    }
  }
  return true;
}

/// Find menu matching `name` and `modes`.
///
/// @param menu top menu to start looking from
/// @param name path towards the menu
/// @return menu if \p name is null, found menu or NULL
static vimmenu_T *find_menu(vimmenu_T *menu, char *name, int modes)
{
  while (*name) {
    // find the end of one dot-separated name and put a NUL at the dot
    char *p = menu_name_skip(name);
    while (menu != NULL) {
      if (menu_name_equal(name, menu)) {
        // Found menu
        if (*p != NUL && menu->children == NULL) {
          emsg(_(e_notsubmenu));
          return NULL;
        } else if ((menu->modes & modes) == 0x0) {
          emsg(_(e_menu_only_exists_in_another_mode));
          return NULL;
        } else if (*p == NUL) {  // found a full match
          return menu;
        }
        break;
      }
      menu = menu->next;
    }

    if (menu == NULL) {
      semsg(_(e_nomenu), name);
      return NULL;
    }
    // Found a match, search the sub-menu.
    name = p;
    menu = menu->children;
  }
  return menu;
}

/// Show the mapping associated with a menu item or hierarchy in a sub-menu.
static int show_menus(char *const path_name, int modes)
{
  vimmenu_T *menu = *get_root_menu(path_name);
  if (menu != NULL) {
    // First, find the (sub)menu with the given name
    menu = find_menu(menu, path_name, modes);
    if (menu == NULL) {
      return FAIL;
    }
  }
  // When there are no menus at all, the title still needs to be shown.

  // Now we have found the matching menu, and we list the mappings
  // Highlight title
  msg_puts_title(_("\n--- Menus ---"));

  if (menu != NULL) {
    show_menus_recursive(menu->parent, modes, 0);
  }
  return OK;
}

/// Recursively show the mappings associated with the menus under the given one
static void show_menus_recursive(vimmenu_T *menu, int modes, int depth)
{
  if (menu != NULL && (menu->modes & modes) == 0x0) {
    return;
  }

  if (menu != NULL) {
    msg_putchar('\n');
    if (got_int) {              // "q" hit for "--more--"
      return;
    }
    for (int i = 0; i < depth; i++) {
      msg_puts("  ");
    }
    if (menu->priority) {
      msg_outnum(menu->priority);
      msg_puts(" ");
    }
    // Same highlighting as for directories!?
    msg_outtrans(menu->name, HL_ATTR(HLF_D));
  }

  if (menu != NULL && menu->children == NULL) {
    for (int bit = 0; bit < MENU_MODES; bit++) {
      if ((menu->modes & modes & (1 << bit)) != 0) {
        msg_putchar('\n');
        if (got_int) {                  // "q" hit for "--more--"
          return;
        }
        for (int i = 0; i < depth + 2; i++) {
          msg_puts("  ");
        }
        msg_puts(menu_mode_chars[bit]);
        if (menu->noremap[bit] == REMAP_NONE) {
          msg_putchar('*');
        } else if (menu->noremap[bit] == REMAP_SCRIPT) {
          msg_putchar('&');
        } else {
          msg_putchar(' ');
        }
        if (menu->silent[bit]) {
          msg_putchar('s');
        } else {
          msg_putchar(' ');
        }
        if ((menu->modes & menu->enabled & (1 << bit)) == 0) {
          msg_putchar('-');
        } else {
          msg_putchar(' ');
        }
        msg_puts(" ");
        if (*menu->strings[bit] == NUL) {
          msg_puts_attr("<Nop>", HL_ATTR(HLF_8));
        } else {
          msg_outtrans_special(menu->strings[bit], false, 0);
        }
      }
    }
  } else {
    if (menu == NULL) {
      menu = root_menu;
      depth--;
    } else {
      menu = menu->children;
    }

    // recursively show all children.  Skip PopUp[nvoci].
    for (; menu != NULL && !got_int; menu = menu->next) {
      if (!menu_is_hidden(menu->dname)) {
        show_menus_recursive(menu, modes, depth + 1);
      }
    }
  }
}

// Used when expanding menu names.
static vimmenu_T *expand_menu = NULL;
static int expand_modes = 0x0;
static int expand_emenu;                // true for ":emenu" command

// Work out what to complete when doing command line completion of menu names.
char *set_context_in_menu_cmd(expand_T *xp, const char *cmd, char *arg, bool forceit)
  FUNC_ATTR_NONNULL_ALL
{
  char *after_dot;
  char *p;
  char *path_name = NULL;
  bool unmenu;
  vimmenu_T *menu;

  xp->xp_context = EXPAND_UNSUCCESSFUL;

  // Check for priority numbers, enable and disable
  for (p = arg; *p; p++) {
    if (!ascii_isdigit(*p) && *p != '.') {
      break;
    }
  }

  if (!ascii_iswhite(*p)) {
    if (strncmp(arg, "enable", 6) == 0
        && (arg[6] == NUL || ascii_iswhite(arg[6]))) {
      p = arg + 6;
    } else if (strncmp(arg, "disable", 7) == 0
               && (arg[7] == NUL || ascii_iswhite(arg[7]))) {
      p = arg + 7;
    } else {
      p = arg;
    }
  }

  while (*p != NUL && ascii_iswhite(*p)) {
    p++;
  }

  arg = after_dot = p;

  for (; *p && !ascii_iswhite(*p); p++) {
    if ((*p == '\\' || *p == Ctrl_V) && p[1] != NUL) {
      p++;
    } else if (*p == '.') {
      after_dot = p + 1;
    }
  }

  // ":popup" only uses menus, not entries
  int expand_menus = !((*cmd == 't' && cmd[1] == 'e') || *cmd == 'p');
  expand_emenu = (*cmd == 'e');
  if (expand_menus && ascii_iswhite(*p)) {
    return NULL;  // TODO(vim): check for next command?
  }
  if (*p == NUL) {  // Complete the menu name
    // With :unmenu, you only want to match menus for the appropriate mode.
    // With :menu though you might want to add a menu with the same name as
    // one in another mode, so match menus from other modes too.
    expand_modes = get_menu_cmd_modes(cmd, forceit, NULL, &unmenu);
    if (!unmenu) {
      expand_modes = MENU_ALL_MODES;
    }

    menu = root_menu;
    if (after_dot > arg) {
      size_t path_len = (size_t)(after_dot - arg);
      path_name = xmalloc(path_len);
      xstrlcpy(path_name, arg, path_len);
    }
    char *name = path_name;
    while (name != NULL && *name) {
      p = menu_name_skip(name);
      while (menu != NULL) {
        if (menu_name_equal(name, menu)) {
          // Found menu
          if ((*p != NUL && menu->children == NULL)
              || ((menu->modes & expand_modes) == 0x0)) {
            // Menu path continues, but we have reached a leaf.
            // Or menu exists only in another mode.
            xfree(path_name);
            return NULL;
          }
          break;
        }
        menu = menu->next;
      }
      if (menu == NULL) {
        // No menu found with the name we were looking for
        xfree(path_name);
        return NULL;
      }
      name = p;
      menu = menu->children;
    }
    xfree(path_name);

    xp->xp_context = expand_menus ? EXPAND_MENUNAMES : EXPAND_MENUS;
    xp->xp_pattern = after_dot;
    expand_menu = menu;
  } else {                      // We're in the mapping part
    xp->xp_context = EXPAND_NOTHING;
  }
  return NULL;
}

// Function given to ExpandGeneric() to obtain the list of (sub)menus (not
// entries).
char *get_menu_name(expand_T *xp, int idx)
{
  static vimmenu_T *menu = NULL;
  char *str;
  static bool should_advance = false;

  if (idx == 0) {           // first call: start at first item
    menu = expand_menu;
    should_advance = false;
  }

  // Skip PopUp[nvoci].
  while (menu != NULL && (menu_is_hidden(menu->dname)
                          || menu_is_separator(menu->dname)
                          || menu->children == NULL)) {
    menu = menu->next;
  }

  if (menu == NULL) {       // at end of linked list
    return NULL;
  }

  if (menu->modes & expand_modes) {
    if (should_advance) {
      str = menu->en_dname;
    } else {
      str = menu->dname;
      if (menu->en_dname == NULL) {
        should_advance = true;
      }
    }
  } else {
    str = "";
  }

  if (should_advance) {
    // Advance to next menu entry.
    menu = menu->next;
  }

  should_advance = !should_advance;

  return str;
}

// Function given to ExpandGeneric() to obtain the list of menus and menu
// entries.
char *get_menu_names(expand_T *xp, int idx)
{
  static vimmenu_T *menu = NULL;
#define TBUFFER_LEN 256
  static char tbuffer[TBUFFER_LEN];         // hack
  char *str;
  static bool should_advance = false;

  if (idx == 0) {           // first call: start at first item
    menu = expand_menu;
    should_advance = false;
  }

  // Skip Browse-style entries, popup menus and separators.
  while (menu != NULL
         && (menu_is_hidden(menu->dname)
             || (expand_emenu && menu_is_separator(menu->dname))
             || menu->dname[strlen(menu->dname) - 1] == '.')) {
    menu = menu->next;
  }

  if (menu == NULL) {       // at end of linked list
    return NULL;
  }

  if (menu->modes & expand_modes) {
    if (menu->children != NULL) {
      if (should_advance) {
        xstrlcpy(tbuffer, menu->en_dname, TBUFFER_LEN);
      } else {
        xstrlcpy(tbuffer, menu->dname,  TBUFFER_LEN);
        if (menu->en_dname == NULL) {
          should_advance = true;
        }
      }
      // hack on menu separators:  use a 'magic' char for the separator
      // so that '.' in names gets escaped properly
      STRCAT(tbuffer, "\001");
      str = tbuffer;
    } else {
      if (should_advance) {
        str = menu->en_dname;
      } else {
        str = menu->dname;
        if (menu->en_dname == NULL) {
          should_advance = true;
        }
      }
    }
  } else {
    str = "";
  }

  if (should_advance) {
    // Advance to next menu entry.
    menu = menu->next;
  }

  should_advance = !should_advance;

  return str;
}

/// Skip over this element of the menu path and return the start of the next
/// element.  Any \ and ^Vs are removed from the current element.
///
/// @param name may be modified.
/// @return start of the next element
char *menu_name_skip(char *const name)
{
  char *p;

  for (p = name; *p && *p != '.'; MB_PTR_ADV(p)) {
    if (*p == '\\' || *p == Ctrl_V) {
      STRMOVE(p, p + 1);
      if (*p == NUL) {
        break;
      }
    }
  }
  if (*p) {
    *p++ = NUL;
  }
  return p;
}

/// Return true when "name" matches with menu "menu".  The name is compared in
/// two ways: raw menu name and menu name without '&'.  ignore part after a TAB.
static bool menu_name_equal(const char *const name, const vimmenu_T *const menu)
{
  if (menu->en_name != NULL
      && (menu_namecmp(name, menu->en_name)
          || menu_namecmp(name, menu->en_dname))) {
    return true;
  }
  return menu_namecmp(name, menu->name) || menu_namecmp(name, menu->dname);
}

static bool menu_namecmp(const char *const name, const char *const mname)
{
  int i;

  for (i = 0; name[i] != NUL && name[i] != TAB; i++) {
    if (name[i] != mname[i]) {
      break;
    }
  }
  return (name[i] == NUL || name[i] == TAB)
         && (mname[i] == NUL || mname[i] == TAB);
}

/// Returns the \ref MENU_MODES specified by menu command `cmd`.
///  (eg :menu! returns MENU_CMDLINE_MODE | MENU_INSERT_MODE)
///
/// @param[in] cmd      string like "nmenu", "vmenu", etc.
/// @param[in] forceit  bang (!) was given after the command
/// @param[out] noremap If not NULL, the flag it points to is set according
///                     to whether the command is a "nore" command.
/// @param[out] unmenu  If not NULL, the flag it points to is set according
///                     to whether the command is an "unmenu" command.
int get_menu_cmd_modes(const char *cmd, bool forceit, int *noremap, bool *unmenu)
{
  int modes;

  switch (*cmd++) {
  case 'v':                             // vmenu, vunmenu, vnoremenu
    modes = MENU_VISUAL_MODE | MENU_SELECT_MODE;
    break;
  case 'x':                             // xmenu, xunmenu, xnoremenu
    modes = MENU_VISUAL_MODE;
    break;
  case 's':                             // smenu, sunmenu, snoremenu
    modes = MENU_SELECT_MODE;
    break;
  case 'o':                             // omenu
    modes = MENU_OP_PENDING_MODE;
    break;
  case 'i':                             // imenu
    modes = MENU_INSERT_MODE;
    break;
  case 't':
    if (*cmd == 'l') {                  // tlmenu, tlunmenu, tlnoremenu
      modes = MENU_TERMINAL_MODE;
      cmd++;
      break;
    }
    modes = MENU_TIP_MODE;              // tmenu
    break;
  case 'c':                             // cmenu
    modes = MENU_CMDLINE_MODE;
    break;
  case 'a':                             // amenu
    modes = MENU_INSERT_MODE | MENU_CMDLINE_MODE | MENU_NORMAL_MODE
            | MENU_VISUAL_MODE | MENU_SELECT_MODE
            | MENU_OP_PENDING_MODE;
    break;
  case 'n':
    if (*cmd != 'o') {                  // nmenu, not noremenu
      modes = MENU_NORMAL_MODE;
      break;
    }
    FALLTHROUGH;
  default:
    cmd--;
    if (forceit) {
      // menu!!
      modes = MENU_INSERT_MODE | MENU_CMDLINE_MODE;
    } else {
      // menu
      modes = MENU_NORMAL_MODE | MENU_VISUAL_MODE | MENU_SELECT_MODE
              | MENU_OP_PENDING_MODE;
    }
  }

  if (noremap != NULL) {
    *noremap = (*cmd == 'n' ? REMAP_NONE : REMAP_YES);
  }
  if (unmenu != NULL) {
    *unmenu = (*cmd == 'u');
  }
  return modes;
}

/// Return the string representation of the menu modes. Does the opposite
/// of get_menu_cmd_modes().
static char *get_menu_mode_str(int modes)
{
  if ((modes & (MENU_INSERT_MODE | MENU_CMDLINE_MODE | MENU_NORMAL_MODE |
                MENU_VISUAL_MODE | MENU_SELECT_MODE | MENU_OP_PENDING_MODE))
      == (MENU_INSERT_MODE | MENU_CMDLINE_MODE | MENU_NORMAL_MODE |
          MENU_VISUAL_MODE | MENU_SELECT_MODE | MENU_OP_PENDING_MODE)) {
    return "a";
  }
  if ((modes & (MENU_NORMAL_MODE | MENU_VISUAL_MODE | MENU_SELECT_MODE |
                MENU_OP_PENDING_MODE))
      == (MENU_NORMAL_MODE | MENU_VISUAL_MODE | MENU_SELECT_MODE |
          MENU_OP_PENDING_MODE)) {
    return " ";
  }
  if ((modes & (MENU_INSERT_MODE | MENU_CMDLINE_MODE))
      == (MENU_INSERT_MODE | MENU_CMDLINE_MODE)) {
    return "!";
  }
  if ((modes & (MENU_VISUAL_MODE | MENU_SELECT_MODE))
      == (MENU_VISUAL_MODE | MENU_SELECT_MODE)) {
    return "v";
  }
  if (modes & MENU_VISUAL_MODE) {
    return "x";
  }
  if (modes & MENU_SELECT_MODE) {
    return "s";
  }
  if (modes & MENU_OP_PENDING_MODE) {
    return "o";
  }
  if (modes & MENU_INSERT_MODE) {
    return "i";
  }
  if (modes & MENU_TERMINAL_MODE) {
    return "tl";
  }
  if (modes & MENU_CMDLINE_MODE) {
    return "c";
  }
  if (modes & MENU_NORMAL_MODE) {
    return "n";
  }
  if (modes & MENU_TIP_MODE) {
    return "t";
  }

  return "";
}

// Modify a menu name starting with "PopUp" to include the mode character.
// Returns the name in allocated memory.
static char *popup_mode_name(char *name, int idx)
{
  size_t len = strlen(name);
  assert(len >= 4);

  char *mode_chars = menu_mode_chars[idx];
  size_t mode_chars_len = strlen(mode_chars);
  char *p = xstrnsave(name, len + mode_chars_len);
  memmove(p + 5 + mode_chars_len, p + 5, len - 4);
  for (size_t i = 0; i < mode_chars_len; i++) {
    p[5 + i] = menu_mode_chars[idx][i];
  }

  return p;
}

/// Duplicate the menu item text and then process to see if a mnemonic key
/// and/or accelerator text has been identified.
///
/// @param str The menu item text.
/// @param[out] mnemonic If non-NULL, *mnemonic is set to the character after
///             the first '&'.
/// @param[out] actext If non-NULL, *actext is set to the text after the first
///             TAB, but only if a TAB was found. Memory pointed to is newly
///             allocated.
///
/// @return a pointer to allocated memory.
static char *menu_text(const char *str, int *mnemonic, char **actext)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_NONNULL_ARG(1)
{
  char *text;

  // Locate accelerator text, after the first TAB
  char *p = vim_strchr(str, TAB);
  if (p != NULL) {
    if (actext != NULL) {
      *actext = xstrdup(p + 1);
    }
    assert(p >= str);
    text = xmemdupz(str, (size_t)(p - str));
  } else {
    text = xstrdup(str);
  }

  // Find mnemonic characters "&a" and reduce "&&" to "&".
  for (p = text; p != NULL;) {
    p = vim_strchr(p, '&');
    if (p != NULL) {
      if (p[1] == NUL) {            // trailing "&"
        break;
      }
      if (mnemonic != NULL && p[1] != '&') {
        *mnemonic = (uint8_t)p[1];
      }
      STRMOVE(p, p + 1);
      p = p + 1;
    }
  }
  return text;
}

// Return true if "name" can be a menu in the MenuBar.
bool menu_is_menubar(const char *const name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return !menu_is_popup(name)
         && !menu_is_toolbar(name)
         && !menu_is_winbar(name)
         && *name != MNU_HIDDEN_CHAR;
}

// Return true if "name" is a popup menu name.
bool menu_is_popup(const char *const name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return strncmp(name, "PopUp", 5) == 0;
}

// Return true if "name" is a toolbar menu name.
bool menu_is_toolbar(const char *const name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return strncmp(name, "ToolBar", 7) == 0;
}

/// @return  true if the name is a menu separator identifier: Starts and ends
///          with '-'
bool menu_is_separator(char *name)
{
  return name[0] == '-' && name[strlen(name) - 1] == '-';
}

/// True if a popup menu or starts with \ref MNU_HIDDEN_CHAR
///
/// @return true if the menu is hidden
static bool menu_is_hidden(char *name)
{
  return (name[0] == MNU_HIDDEN_CHAR)
         || (menu_is_popup(name) && name[5] != NUL);
}

static int get_menu_mode(void)
{
  if (State & MODE_TERMINAL) {
    return MENU_INDEX_TERMINAL;
  }
  if (VIsual_active) {
    if (VIsual_select) {
      return MENU_INDEX_SELECT;
    }
    return MENU_INDEX_VISUAL;
  }
  if (State & MODE_INSERT) {
    return MENU_INDEX_INSERT;
  }
  if ((State & MODE_CMDLINE) || State == MODE_ASKMORE || State == MODE_HITRETURN) {
    return MENU_INDEX_CMDLINE;
  }
  if (finish_op) {
    return MENU_INDEX_OP_PENDING;
  }
  if (State & MODE_NORMAL) {
    return MENU_INDEX_NORMAL;
  }
  if (State & MODE_LANGMAP) {  // must be a "r" command, like Insert mode
    return MENU_INDEX_INSERT;
  }
  return MENU_INDEX_INVALID;
}

int get_menu_mode_flag(void)
{
  int mode = get_menu_mode();

  if (mode == MENU_INDEX_INVALID) {
    return 0;
  }
  return 1 << mode;
}

/// Display the Special "PopUp" menu as a pop-up at the current mouse
/// position.  The "PopUpn" menu is for Normal mode, "PopUpi" for Insert mode,
/// etc.
void show_popupmenu(void)
{
  int menu_mode = get_menu_mode();
  if (menu_mode == MENU_INDEX_INVALID) {
    return;
  }
  char *mode = menu_mode_chars[menu_mode];
  size_t mode_len = strlen(mode);

  apply_autocmds(EVENT_MENUPOPUP, mode, NULL, false, curbuf);

  vimmenu_T *menu;

  for (menu = root_menu; menu != NULL; menu = menu->next) {
    if (strncmp("PopUp", menu->name, 5) == 0 && strncmp(menu->name + 5, mode, mode_len) == 0) {
      break;
    }
  }

  // Only show a popup when it is defined and has entries
  if (menu == NULL || menu->children == NULL) {
    return;
  }

  pum_show_popupmenu(menu);
}

/// Execute "menu".  Use by ":emenu" and the window toolbar.
/// @param eap  NULL for the window toolbar.
/// @param mode_idx  specify a MENU_INDEX_ value,
///                  use MENU_INDEX_INVALID to depend on the current state
void execute_menu(const exarg_T *eap, vimmenu_T *menu, int mode_idx)
  FUNC_ATTR_NONNULL_ARG(2)
{
  int idx = mode_idx;

  if (idx < 0) {
    // Use the Insert mode entry when returning to Insert mode.
    if (((State & MODE_INSERT) || restart_edit) && current_sctx.sc_sid == 0) {
      idx = MENU_INDEX_INSERT;
    } else if (State & MODE_CMDLINE) {
      idx = MENU_INDEX_CMDLINE;
    } else if (State & MODE_TERMINAL) {
      idx = MENU_INDEX_TERMINAL;
    } else if (get_real_state() & MODE_VISUAL) {
      // Detect real visual mode -- if we are really in visual mode we
      // don't need to do any guesswork to figure out what the selection
      // is. Just execute the visual binding for the menu.
      idx = MENU_INDEX_VISUAL;
    } else if (eap != NULL && eap->addr_count) {
      pos_T tpos;

      idx = MENU_INDEX_VISUAL;

      // GEDDES: This is not perfect - but it is a
      // quick way of detecting whether we are doing this from a
      // selection - see if the range matches up with the visual
      // select start and end.
      if ((curbuf->b_visual.vi_start.lnum == eap->line1)
          && (curbuf->b_visual.vi_end.lnum) == eap->line2) {
        // Set it up for visual mode - equivalent to gv.
        VIsual_mode = curbuf->b_visual.vi_mode;
        tpos = curbuf->b_visual.vi_end;
        curwin->w_cursor = curbuf->b_visual.vi_start;
        curwin->w_curswant = curbuf->b_visual.vi_curswant;
      } else {
        // Set it up for line-wise visual mode
        VIsual_mode = 'V';
        curwin->w_cursor.lnum = eap->line1;
        curwin->w_cursor.col = 1;
        tpos.lnum = eap->line2;
        tpos.col = MAXCOL;
        tpos.coladd = 0;
      }

      // Activate visual mode
      VIsual_active = true;
      VIsual_reselect = true;
      check_cursor(curwin);
      VIsual = curwin->w_cursor;
      curwin->w_cursor = tpos;

      check_cursor(curwin);

      // Adjust the cursor to make sure it is in the correct pos
      // for exclusive mode
      if (*p_sel == 'e' && gchar_cursor() != NUL) {
        curwin->w_cursor.col++;
      }
    }
  }

  if (idx == MENU_INDEX_INVALID || eap == NULL) {
    idx = MENU_INDEX_NORMAL;
  }

  if (menu->strings[idx] != NULL && (menu->modes & (1 << idx))) {
    // When executing a script or function execute the commands right now.
    // Also for the window toolbar
    // Otherwise put them in the typeahead buffer.
    if (eap == NULL || current_sctx.sc_sid != 0) {
      save_state_T save_state;

      ex_normal_busy++;
      if (save_current_state(&save_state)) {
        exec_normal_cmd(menu->strings[idx], menu->noremap[idx],
                        menu->silent[idx]);
      }
      restore_current_state(&save_state);
      ex_normal_busy--;
    } else {
      ins_typebuf(menu->strings[idx], menu->noremap[idx], 0, true,
                  menu->silent[idx]);
    }
  } else if (eap != NULL) {
    char *mode;
    switch (idx) {
    case MENU_INDEX_VISUAL:
      mode = "Visual";
      break;
    case MENU_INDEX_SELECT:
      mode = "Select";
      break;
    case MENU_INDEX_OP_PENDING:
      mode = "Op-pending";
      break;
    case MENU_INDEX_TERMINAL:
      mode = "Terminal";
      break;
    case MENU_INDEX_INSERT:
      mode = "Insert";
      break;
    case MENU_INDEX_CMDLINE:
      mode = "Cmdline";
      break;
    // case MENU_INDEX_TIP: cannot happen
    default:
      mode = "Normal";
    }
    semsg(_("E335: Menu not defined for %s mode"), mode);
  }
}

/// Lookup a menu by the descriptor name e.g. "File.New"
/// Returns NULL if the menu is not found
static vimmenu_T *menu_getbyname(char *name_arg)
  FUNC_ATTR_NONNULL_ALL
{
  char *saved_name = xstrdup(name_arg);
  vimmenu_T *menu = *get_root_menu(saved_name);
  char *name = saved_name;
  bool gave_emsg = false;
  while (*name) {
    // Find in the menu hierarchy
    char *p = menu_name_skip(name);

    while (menu != NULL) {
      if (menu_name_equal(name, menu)) {
        if (*p == NUL && menu->children != NULL) {
          emsg(_("E333: Menu path must lead to a menu item"));
          gave_emsg = true;
          menu = NULL;
        } else if (*p != NUL && menu->children == NULL) {
          emsg(_(e_notsubmenu));
          menu = NULL;
        }
        break;
      }
      menu = menu->next;
    }
    if (menu == NULL || *p == NUL) {
      break;
    }
    menu = menu->children;
    name = p;
  }
  xfree(saved_name);
  if (menu == NULL) {
    if (!gave_emsg) {
      semsg(_("E334: Menu not found: %s"), name_arg);
    }
    return NULL;
  }

  return menu;
}

/// Given a menu descriptor, e.g. "File.New", find it in the menu hierarchy and
/// execute it.
void ex_emenu(exarg_T *eap)
{
  char *arg = eap->arg;
  int mode_idx = MENU_INDEX_INVALID;

  if (arg[0] && ascii_iswhite(arg[1])) {
    switch (arg[0]) {
    case 'n':
      mode_idx = MENU_INDEX_NORMAL; break;
    case 'v':
      mode_idx = MENU_INDEX_VISUAL; break;
    case 's':
      mode_idx = MENU_INDEX_SELECT; break;
    case 'o':
      mode_idx = MENU_INDEX_OP_PENDING; break;
    case 't':
      mode_idx = MENU_INDEX_TERMINAL; break;
    case 'i':
      mode_idx = MENU_INDEX_INSERT; break;
    case 'c':
      mode_idx = MENU_INDEX_CMDLINE; break;
    default:
      semsg(_(e_invarg2), arg);
      return;
    }
    arg = skipwhite(arg + 2);
  }

  vimmenu_T *menu = menu_getbyname(arg);
  if (menu == NULL) {
    return;
  }

  // Found the menu, so execute.
  execute_menu(eap, menu, mode_idx);
}

/// Given a menu descriptor, e.g. "File.New", find it in the menu hierarchy.
vimmenu_T *menu_find(const char *path_name)
{
  vimmenu_T *menu = *get_root_menu(path_name);
  char *saved_name = xstrdup(path_name);
  char *name = saved_name;
  while (*name) {
    // find the end of one dot-separated name and put a NUL at the dot
    char *p = menu_name_skip(name);

    while (menu != NULL) {
      if (menu_name_equal(name, menu)) {
        if (menu->children == NULL) {
          // found a menu item instead of a sub-menu
          if (*p == NUL) {
            emsg(_("E336: Menu path must lead to a sub-menu"));
          } else {
            emsg(_(e_notsubmenu));
          }
          menu = NULL;
          goto theend;
        }
        if (*p == NUL) {  // found a full match
          goto theend;
        }
        break;
      }
      menu = menu->next;
    }
    if (menu == NULL) {  // didn't find it
      break;
    }

    // Found a match, search the sub-menu.
    menu = menu->children;
    name = p;
  }

  if (menu == NULL) {
    emsg(_("E337: Menu not found - check menu names"));
  }
theend:
  xfree(saved_name);
  return menu;
}

// Translation of menu names.  Just a simple lookup table.

typedef struct {
  char *from;            // English name
  char *from_noamp;      // same, without '&'
  char *to;              // translated name
} menutrans_T;

static garray_T menutrans_ga = GA_EMPTY_INIT_VALUE;

#define FREE_MENUTRANS(mt) \
  menutrans_T *_mt = (mt); \
  xfree(_mt->from); \
  xfree(_mt->from_noamp); \
  xfree(_mt->to)

// ":menutrans".
// This function is also defined without the +multi_lang feature, in which
// case the commands are ignored.
void ex_menutranslate(exarg_T *eap)
{
  char *arg = eap->arg;

  if (menutrans_ga.ga_itemsize == 0) {
    ga_init(&menutrans_ga, (int)sizeof(menutrans_T), 5);
  }

  // ":menutrans clear": clear all translations.
  if (strncmp(arg, "clear", 5) == 0 && ends_excmd(*skipwhite(arg + 5))) {
    GA_DEEP_CLEAR(&menutrans_ga, menutrans_T, FREE_MENUTRANS);

    // Delete all "menutrans_" global variables.
    del_menutrans_vars();
  } else {
    // ":menutrans from to": add translation
    char *from = arg;
    arg = menu_skip_part(arg);
    char *to = skipwhite(arg);
    *arg = NUL;
    arg = menu_skip_part(to);
    if (arg == to) {
      emsg(_(e_invarg));
    } else {
      from = xstrdup(from);
      char *from_noamp = menu_text(from, NULL, NULL);
      assert(arg >= to);
      to = xmemdupz(to, (size_t)(arg - to));
      menu_translate_tab_and_shift(from);
      menu_translate_tab_and_shift(to);
      menu_unescape_name(from);
      menu_unescape_name(to);
      menutrans_T *tp = GA_APPEND_VIA_PTR(menutrans_T, &menutrans_ga);
      tp->from = from;
      tp->from_noamp = from_noamp;
      tp->to = to;
    }
  }
}

// Find the character just after one part of a menu name.
static char *menu_skip_part(char *p)
{
  while (*p != NUL && *p != '.' && !ascii_iswhite(*p)) {
    if ((*p == '\\' || *p == Ctrl_V) && p[1] != NUL) {
      p++;
    }
    p++;
  }
  return p;
}

// Lookup part of a menu name in the translations.
// Return a pointer to the translation or NULL if not found.
static char *menutrans_lookup(char *name, int len)
{
  menutrans_T *tp = (menutrans_T *)menutrans_ga.ga_data;

  for (int i = 0; i < menutrans_ga.ga_len; i++) {
    if (STRNICMP(name, tp[i].from, len) == 0 && tp[i].from[len] == NUL) {
      return tp[i].to;
    }
  }

  // Now try again while ignoring '&' characters.
  char c = name[len];
  name[len] = NUL;
  char *dname = menu_text(name, NULL, NULL);
  name[len] = c;
  for (int i = 0; i < menutrans_ga.ga_len; i++) {
    if (STRICMP(dname, tp[i].from_noamp) == 0) {
      xfree(dname);
      return tp[i].to;
    }
  }
  xfree(dname);

  return NULL;
}

// Unescape the name in the translate dictionary table.
static void menu_unescape_name(char *name)
{
  for (char *p = name; *p && *p != '.'; MB_PTR_ADV(p)) {
    if (*p == '\\') {
      STRMOVE(p, p + 1);
    }
  }
}

// Isolate the menu name.
// Skip the menu name, and translate <Tab> into a real TAB.
static char *menu_translate_tab_and_shift(char *arg_start)
{
  char *arg = arg_start;

  while (*arg && !ascii_iswhite(*arg)) {
    if ((*arg == '\\' || *arg == Ctrl_V) && arg[1] != NUL) {
      arg++;
    } else if (STRNICMP(arg, "<TAB>", 5) == 0) {
      *arg = TAB;
      STRMOVE(arg + 1, arg + 5);
    }
    arg++;
  }
  if (*arg != NUL) {
    *arg++ = NUL;
  }
  arg = skipwhite(arg);

  return arg;
}

/// Get the information about a menu item in mode 'which'
static void menuitem_getinfo(const char *menu_name, const vimmenu_T *menu, int modes, dict_T *dict)
  FUNC_ATTR_NONNULL_ALL
{
  if (*menu_name == NUL) {
    // Return all the top-level menus
    list_T *const l = tv_list_alloc(kListLenMayKnow);
    tv_dict_add_list(dict, S_LEN("submenus"), l);
    // get all the children.  Skip PopUp[nvoci].
    for (const vimmenu_T *topmenu = menu; topmenu != NULL; topmenu = topmenu->next) {
      if (!menu_is_hidden(topmenu->dname)) {
        tv_list_append_string(l, topmenu->dname, -1);
      }
    }
    return;
  }

  tv_dict_add_str(dict, S_LEN("name"), menu->name);
  tv_dict_add_str(dict, S_LEN("display"), menu->dname);
  if (menu->actext != NULL) {
    tv_dict_add_str(dict, S_LEN("accel"), menu->actext);
  }
  tv_dict_add_nr(dict, S_LEN("priority"), menu->priority);
  tv_dict_add_str(dict, S_LEN("modes"), get_menu_mode_str(menu->modes));

  char buf[NUMBUFLEN];
  buf[utf_char2bytes(menu->mnemonic, buf)] = NUL;
  tv_dict_add_str(dict, S_LEN("shortcut"), buf);

  if (menu->children == NULL) {  // leaf menu
    int bit;

    // Get the first mode in which the menu is available
    for (bit = 0; (bit < MENU_MODES) && !((1 << bit) & modes); bit++) {}

    if (bit < MENU_MODES) {  // just in case, avoid Coverity warning
      if (menu->strings[bit] != NULL) {
        tv_dict_add_allocated_str(dict, S_LEN("rhs"),
                                  *menu->strings[bit] == NUL
                                  ? xstrdup("<Nop>")
                                  : str2special_save(menu->strings[bit], false, false));
      }
      tv_dict_add_bool(dict, S_LEN("noremenu"), menu->noremap[bit] == REMAP_NONE);
      tv_dict_add_bool(dict, S_LEN("script"), menu->noremap[bit] == REMAP_SCRIPT);
      tv_dict_add_bool(dict, S_LEN("silent"), menu->silent[bit]);
      tv_dict_add_bool(dict, S_LEN("enabled"), (menu->enabled & (1 << bit)) != 0);
    }
  } else {
    // If there are submenus, add all the submenu display names
    list_T *const l = tv_list_alloc(kListLenMayKnow);
    tv_dict_add_list(dict, S_LEN("submenus"), l);
    const vimmenu_T *child = menu->children;
    while (child != NULL) {
      tv_list_append_string(l, child->dname, -1);
      child = child->next;
    }
  }
}

/// "menu_info()" function
/// Return information about a menu (including all the child menus)
void f_menu_info(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_dict_alloc_ret(rettv);
  dict_T *const retdict = rettv->vval.v_dict;

  const char *const menu_name = tv_get_string_chk(&argvars[0]);
  if (menu_name == NULL) {
    return;
  }

  // menu mode
  const char *which;
  if (argvars[1].v_type != VAR_UNKNOWN) {
    which = tv_get_string_chk(&argvars[1]);
  } else {
    which = "";  // Default is modes for "menu"
  }
  if (which == NULL) {
    return;
  }

  const int modes = get_menu_cmd_modes(which, *which == '!', NULL, NULL);

  // Locate the specified menu or menu item
  const vimmenu_T *menu = *get_root_menu(menu_name);
  char *const saved_name = xstrdup(menu_name);
  if (*saved_name != NUL) {
    char *name = saved_name;
    while (*name) {
      // Find in the menu hierarchy
      char *p = menu_name_skip(name);
      while (menu != NULL) {
        if (menu_name_equal(name, menu)) {
          break;
        }
        menu = menu->next;
      }
      if (menu == NULL || *p == NUL) {
        break;
      }
      menu = menu->children;
      name = p;
    }
  }
  xfree(saved_name);

  if (menu == NULL) {  // specified menu not found
    return;
  }

  if (menu->modes & modes) {
    menuitem_getinfo(menu_name, menu, modes, retdict);
  }
}
