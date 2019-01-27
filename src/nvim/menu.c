// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * Code for menus.  Used for the GUI and 'wildmenu'.
 * GUI/Motif support by Robert Webb
 */

#include <assert.h>
#include <inttypes.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/menu.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/eval.h"
#include "nvim/ex_docmd.h"
#include "nvim/getchar.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/keymap.h"
#include "nvim/garray.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/eval/typval.h"

#define MENUDEPTH   10          /* maximum depth of menus */


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "menu.c.generated.h"
#endif




/// The character for each menu mode
static char_u menu_mode_chars[] = { 'n', 'v', 's', 'o', 'i', 'c', 't' };

static char_u e_notsubmenu[] = N_(
    "E327: Part of menu-item path is not sub-menu");
static char_u e_othermode[] = N_("E328: Menu only exists in another mode");
static char_u e_nomenu[] = N_("E329: No menu \"%s\"");


/// Do the :menu command and relatives.
/// @param eap Ex command arguments
void
ex_menu(exarg_T *eap)
{
  char_u      *menu_path;
  int modes;
  char_u      *map_to;            // command mapped to the menu entry
  int noremap;
  bool silent = false;
  int unmenu;
  char_u      *map_buf;
  char_u      *arg;
  char_u      *p;
  int i;
  long pri_tab[MENUDEPTH + 1];
  TriState enable = kNone;        // kTrue for "menu enable",
                                  // kFalse for "menu disable
  vimmenu_T menuarg;

  modes = get_menu_cmd_modes(eap->cmd, eap->forceit, &noremap, &unmenu);
  arg = eap->arg;

  for (;; ) {
    if (STRNCMP(arg, "<script>", 8) == 0) {
      noremap = REMAP_SCRIPT;
      arg = skipwhite(arg + 8);
      continue;
    }
    if (STRNCMP(arg, "<silent>", 8) == 0) {
      silent = true;
      arg = skipwhite(arg + 8);
      continue;
    }
    if (STRNCMP(arg, "<special>", 9) == 0) {
      // Ignore obsolete "<special>" modifier.
      arg = skipwhite(arg + 9);
      continue;
    }
    break;
  }


  // Locate an optional "icon=filename" argument
  // TODO(nvim): Currently this is only parsed. Should expose it to UIs.
  if (STRNCMP(arg, "icon=", 5) == 0) {
    arg += 5;
    while (*arg != NUL && *arg != ' ') {
      if (*arg == '\\')
        STRMOVE(arg, arg + 1);
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
    for (i = 0; i < MENUDEPTH && !ascii_iswhite(*arg); ++i) {
      pri_tab[i] = getdigits_long(&arg);
      if (pri_tab[i] == 0)
        pri_tab[i] = 500;
      if (*arg == '.')
        ++arg;
    }
    arg = skipwhite(arg);
  } else if (eap->addr_count && eap->line2 != 0) {
    pri_tab[0] = eap->line2;
    i = 1;
  } else
    i = 0;
  while (i < MENUDEPTH)
    pri_tab[i++] = 500;
  pri_tab[MENUDEPTH] = -1;              /* mark end of the table */

  /*
   * Check for "disable" or "enable" argument.
   */
  if (STRNCMP(arg, "enable", 6) == 0 && ascii_iswhite(arg[6])) {
    enable = kTrue;
    arg = skipwhite(arg + 6);
  } else if (STRNCMP(arg, "disable", 7) == 0 && ascii_iswhite(arg[7])) {
    enable = kFalse;
    arg = skipwhite(arg + 7);
  }

  /*
   * If there is no argument, display all menus.
   */
  if (*arg == NUL) {
    show_menus(arg, modes);
    return;
  }


  menu_path = arg;
  if (*menu_path == '.') {
    EMSG2(_(e_invarg2), menu_path);
    goto theend;
  }

  map_to = menu_translate_tab_and_shift(arg);

  /*
   * If there is only a menu name, display menus with that name.
   */
  if (*map_to == NUL && !unmenu && enable == kNone) {
    show_menus(menu_path, modes);
    goto theend;
  } else if (*map_to != NUL && (unmenu || enable != kNone)) {
    EMSG(_(e_trailing));
    goto theend;
  }

  if (enable != kNone) {
    // Change sensitivity of the menu.
    // For the PopUp menu, remove a menu for each mode separately.
    // Careful: menu_nable_recurse() changes menu_path.
    if (STRCMP(menu_path, "*") == 0) {          // meaning: do all menus
      menu_path = (char_u *)"";
    }

    if (menu_is_popup(menu_path)) {
      for (i = 0; i < MENU_INDEX_TIP; ++i)
        if (modes & (1 << i)) {
          p = popup_mode_name(menu_path, i);
          menu_nable_recurse(root_menu, p, MENU_ALL_MODES, enable);
          xfree(p);
        }
    }
    menu_nable_recurse(root_menu, menu_path, modes, enable);
  } else if (unmenu) {
    /*
     * Delete menu(s).
     */
    if (STRCMP(menu_path, "*") == 0)            /* meaning: remove all menus */
      menu_path = (char_u *)"";

    /*
     * For the PopUp menu, remove a menu for each mode separately.
     */
    if (menu_is_popup(menu_path)) {
      for (i = 0; i < MENU_INDEX_TIP; ++i)
        if (modes & (1 << i)) {
          p = popup_mode_name(menu_path, i);
          remove_menu(&root_menu, p, MENU_ALL_MODES, TRUE);
          xfree(p);
        }
    }

    /* Careful: remove_menu() changes menu_path */
    remove_menu(&root_menu, menu_path, modes, FALSE);
  } else {
    /*
     * Add menu(s).
     * Replace special key codes.
     */
    if (STRICMP(map_to, "<nop>") == 0) {        /* "<Nop>" means nothing */
      map_to = (char_u *)"";
      map_buf = NULL;
    } else if (modes & MENU_TIP_MODE) {
      map_buf = NULL;  // Menu tips are plain text.
    } else {
      map_to = replace_termcodes(map_to, STRLEN(map_to), &map_buf, false, true,
                                 true, CPO_TO_CPO_FLAGS);
    }
    menuarg.modes = modes;
    menuarg.noremap[0] = noremap;
    menuarg.silent[0] = silent;
    add_menu_path(menu_path, &menuarg, pri_tab, map_to);

    /*
     * For the PopUp menu, add a menu for each mode separately.
     */
    if (menu_is_popup(menu_path)) {
      for (i = 0; i < MENU_INDEX_TIP; ++i)
        if (modes & (1 << i)) {
          p = popup_mode_name(menu_path, i);
          // Include all modes, to make ":amenu" work
          menuarg.modes = modes;
          add_menu_path(p, &menuarg, pri_tab, map_to);
          xfree(p);
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
static int
add_menu_path(
    const char_u *const menu_path,
    vimmenu_T *menuarg,
    const long *const pri_tab,
    const char_u *const call_data
)
{
  char_u      *path_name;
  int modes = menuarg->modes;
  vimmenu_T   **menup;
  vimmenu_T   *menu = NULL;
  vimmenu_T   *parent;
  vimmenu_T   **lower_pri;
  char_u      *p;
  char_u      *name;
  char_u      *dname;
  char_u      *next_name;
  char_u c;
  char_u d;
  int i;
  int pri_idx = 0;
  int old_modes = 0;
  int amenu;
  char_u      *en_name;
  char_u      *map_to = NULL;

  /* Make a copy so we can stuff around with it, since it could be const */
  path_name = vim_strsave(menu_path);
  menup = &root_menu;
  parent = NULL;
  name = path_name;
  while (*name) {
    /* Get name of this element in the menu hierarchy, and the simplified
     * name (without mnemonic and accelerator text). */
    next_name = menu_name_skip(name);
    map_to = menutrans_lookup(name, (int)STRLEN(name));
    if (map_to != NULL) {
      en_name = name;
      name = map_to;
    } else {
      en_name = NULL;
    }
    dname = menu_text(name, NULL, NULL);
    if (*dname == NUL) {
      /* Only a mnemonic or accelerator is not valid. */
      EMSG(_("E792: Empty menu name"));
      goto erret;
    }

    /* See if it's already there */
    lower_pri = menup;
    menu = *menup;
    while (menu != NULL) {
      if (menu_name_equal(name, menu) || menu_name_equal(dname, menu)) {
        if (*next_name == NUL && menu->children != NULL) {
          if (!sys_menu) {
            EMSG(_("E330: Menu path must not lead to a sub-menu"));
          }
          goto erret;
        }
        if (*next_name != NUL && menu->children == NULL) {
          if (!sys_menu) {
            EMSG(_(e_notsubmenu));
          }
          goto erret;
        }
        break;
      }
      menup = &menu->next;

      /* Count menus, to find where this one needs to be inserted.
       * Ignore menus that are not in the menubar (PopUp and Toolbar) */
      if (parent != NULL || menu_is_menubar(menu->name)) {
        if (menu->priority <= pri_tab[pri_idx]) {
          lower_pri = menup;
        }
      }
      menu = menu->next;
    }

    if (menu == NULL) {
      if (*next_name == NUL && parent == NULL) {
        EMSG(_("E331: Must not add menu items directly to menu bar"));
        goto erret;
      }

      if (menu_is_separator(dname) && *next_name != NUL) {
        EMSG(_("E332: Separator cannot be part of a menu path"));
        goto erret;
      }

      /* Not already there, so lets add it */
      menu = xcalloc(1, sizeof(vimmenu_T));

      menu->modes = modes;
      menu->enabled = MENU_ALL_MODES;
      menu->name = vim_strsave(name);
      // separate mnemonic and accelerator text from actual menu name
      menu->dname = menu_text(name, &menu->mnemonic, &menu->actext);
      if (en_name != NULL) {
        menu->en_name = vim_strsave(en_name);
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

      /*
       * If this menu option was previously only available in other
       * modes, then make sure it's available for this one now
       * Also enable a menu when it's created or changed.
       */
      {
        menu->modes |= modes;
        menu->enabled |= modes;
      }
    }


    menup = &menu->children;
    parent = menu;
    name = next_name;
    xfree(dname);
    dname = NULL;
    if (pri_tab[pri_idx + 1] != -1) {
      pri_idx++;
    }
  }
  xfree(path_name);

  /*
   * Only add system menu items which have not been defined yet.
   * First check if this was an ":amenu".
   */
  amenu = ((modes & (MENU_NORMAL_MODE | MENU_INSERT_MODE)) ==
           (MENU_NORMAL_MODE | MENU_INSERT_MODE));
  if (sys_menu)
    modes &= ~old_modes;

  if (menu != NULL && modes) {
    p = (call_data == NULL) ? NULL : vim_strsave(call_data);

    /* loop over all modes, may add more than one */
    for (i = 0; i < MENU_MODES; ++i) {
      if (modes & (1 << i)) {
        /* free any old menu */
        free_menu_string(menu, i);

        // For "amenu", may insert an extra character.
        // Don't do this for "<Nop>".
        c = 0;
        d = 0;
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
          menu->strings[i] = xmalloc(STRLEN(call_data) + 5 );
          menu->strings[i][0] = c;
          if (d == 0) {
            STRCPY(menu->strings[i] + 1, call_data);
          } else {
            menu->strings[i][1] = d;
            STRCPY(menu->strings[i] + 2, call_data);
          }
          if (c == Ctrl_C) {
            int len = (int)STRLEN(menu->strings[i]);

            /* Append CTRL-\ CTRL-G to obey 'insertmode'. */
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

  /* Delete any empty submenu we added before discovering the error.  Repeat
   * for higher levels. */
  while (parent != NULL && parent->children == NULL) {
    if (parent->parent == NULL)
      menup = &root_menu;
    else
      menup = &parent->parent->children;
    for (; *menup != NULL && *menup != parent; menup = &((*menup)->next))
      ;
    if (*menup == NULL)     /* safety check */
      break;
    parent = parent->parent;
    free_menu(menup);
  }
  return FAIL;
}

/*
 * Set the (sub)menu with the given name to enabled or disabled.
 * Called recursively.
 */
static int menu_nable_recurse(vimmenu_T *menu, char_u *name, int modes, int enable)
{
  char_u      *p;

  if (menu == NULL)
    return OK;                  /* Got to bottom of hierarchy */

  /* Get name of this element in the menu hierarchy */
  p = menu_name_skip(name);

  /* Find the menu */
  while (menu != NULL) {
    if (*name == NUL || *name == '*' || menu_name_equal(name, menu)) {
      if (*p != NUL) {
        if (menu->children == NULL) {
          EMSG(_(e_notsubmenu));
          return FAIL;
        }
        if (menu_nable_recurse(menu->children, p, modes, enable)
            == FAIL)
          return FAIL;
      } else if (enable)
        menu->enabled |= modes;
      else
        menu->enabled &= ~modes;

      /*
       * When name is empty, we are doing all menu items for the given
       * modes, so keep looping, otherwise we are just doing the named
       * menu item (which has been found) so break here.
       */
      if (*name != NUL && *name != '*')
        break;
    }
    menu = menu->next;
  }
  if (*name != NUL && *name != '*' && menu == NULL) {
    EMSG2(_(e_nomenu), name);
    return FAIL;
  }


  return OK;
}

/*
 * Remove the (sub)menu with the given name from the menu hierarchy
 * Called recursively.
 */
static int 
remove_menu (
    vimmenu_T **menup,
    char_u *name,
    int modes,
    bool silent                     /* don't give error messages */
)
{
  vimmenu_T   *menu;
  vimmenu_T   *child;
  char_u      *p;

  if (*menup == NULL)
    return OK;                  /* Got to bottom of hierarchy */

  /* Get name of this element in the menu hierarchy */
  p = menu_name_skip(name);

  /* Find the menu */
  while ((menu = *menup) != NULL) {
    if (*name == NUL || menu_name_equal(name, menu)) {
      if (*p != NUL && menu->children == NULL) {
        if (!silent)
          EMSG(_(e_notsubmenu));
        return FAIL;
      }
      if ((menu->modes & modes) != 0x0) {
        if (remove_menu(&menu->children, p, modes, silent) == FAIL)
          return FAIL;
      } else if (*name != NUL) {
        if (!silent)
          EMSG(_(e_othermode));
        return FAIL;
      }

      /*
       * When name is empty, we are removing all menu items for the given
       * modes, so keep looping, otherwise we are just removing the named
       * menu item (which has been found) so break here.
       */
      if (*name != NUL)
        break;

      /* Remove the menu item for the given mode[s].  If the menu item
       * is no longer valid in ANY mode, delete it */
      menu->modes &= ~modes;
      if (modes & MENU_TIP_MODE)
        free_menu_string(menu, MENU_INDEX_TIP);
      if ((menu->modes & MENU_ALL_MODES) == 0)
        free_menu(menup);
      else
        menup = &menu->next;
    } else
      menup = &menu->next;
  }
  if (*name != NUL) {
    if (menu == NULL) {
      if (!silent)
        EMSG2(_(e_nomenu), name);
      return FAIL;
    }


    /* Recalculate modes for menu based on the new updated children */
    menu->modes &= ~modes;
    child = menu->children;
    for (; child != NULL; child = child->next)
      menu->modes |= child->modes;
    if (modes & MENU_TIP_MODE) {
      free_menu_string(menu, MENU_INDEX_TIP);
    }
    if ((menu->modes & MENU_ALL_MODES) == 0) {
      /* The menu item is no longer valid in ANY mode, so delete it */
      *menup = menu;
      free_menu(menup);
    }
  }

  return OK;
}

/*
 * Free the given menu structure and remove it from the linked list.
 */
static void free_menu(vimmenu_T **menup)
{
  int i;
  vimmenu_T   *menu;

  menu = *menup;


  /* Don't change *menup until after calling gui_mch_destroy_menu(). The
   * MacOS code needs the original structure to properly delete the menu. */
  *menup = menu->next;
  xfree(menu->name);
  xfree(menu->dname);
  xfree(menu->en_name);
  xfree(menu->en_dname);
  xfree(menu->actext);
  for (i = 0; i < MENU_MODES; i++)
    free_menu_string(menu, i);
  xfree(menu);

}

/*
 * Free the menu->string with the given index.
 */
static void free_menu_string(vimmenu_T *menu, int idx)
{
  int count = 0;
  int i;

  for (i = 0; i < MENU_MODES; i++)
    if (menu->strings[i] == menu->strings[idx])
      count++;
  if (count == 1)
    xfree(menu->strings[idx]);
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
  dict_T *dict;

  if (!menu || (menu->modes & modes) == 0x0) {
    return NULL;
  }

  dict = tv_dict_alloc();
  tv_dict_add_str(dict, S_LEN("name"), (char *)menu->dname);
  tv_dict_add_nr(dict, S_LEN("priority"), (int)menu->priority);
  tv_dict_add_nr(dict, S_LEN("hidden"), menu_is_hidden(menu->dname));

  if (menu->mnemonic) {
    char buf[MB_MAXCHAR + 1] = { 0 };  // > max value of utf8_char2bytes
    utf_char2bytes(menu->mnemonic, (char_u *)buf);
    tv_dict_add_str(dict, S_LEN("shortcut"), buf);
  }

  if (menu->actext) {
    tv_dict_add_str(dict, S_LEN("actext"), (char *)menu->actext);
  }

  if (menu->modes & MENU_TIP_MODE && menu->strings[MENU_INDEX_TIP]) {
    tv_dict_add_str(dict, S_LEN("tooltip"),
                    (char *)menu->strings[MENU_INDEX_TIP]);
  }

  if (!menu->children) {
    // leaf menu
    dict_T *commands = tv_dict_alloc();
    tv_dict_add_dict(dict, S_LEN("mappings"), commands);

    for (int bit = 0; bit < MENU_MODES; bit++) {
      if ((menu->modes & modes & (1 << bit)) != 0) {
        dict_T *impl = tv_dict_alloc();
        tv_dict_add_allocated_str(impl, S_LEN("rhs"),
                                  str2special_save((char *)menu->strings[bit],
                                                   false, false));
        tv_dict_add_nr(impl, S_LEN("silent"), menu->silent[bit]);
        tv_dict_add_nr(impl, S_LEN("enabled"),
                       (menu->enabled & (1 << bit)) ? 1 : 0);
        tv_dict_add_nr(impl, S_LEN("noremap"),
                       (menu->noremap[bit] & REMAP_NONE) ? 1 : 0);
        tv_dict_add_nr(impl, S_LEN("sid"),
                       (menu->noremap[bit] & REMAP_SCRIPT) ? 1 : 0);
        tv_dict_add_dict(commands, (char *)&menu_mode_chars[bit], 1, impl);
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
bool menu_get(char_u *const path_name, int modes, list_T *list)
{
  vimmenu_T *menu = find_menu(root_menu, path_name, modes);
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
static vimmenu_T *find_menu(vimmenu_T *menu, char_u *name, int modes)
{
  char_u *p;

  while (*name) {
    // find the end of one dot-separated name and put a NUL at the dot
    p = menu_name_skip(name);
    while (menu != NULL) {
      if (menu_name_equal(name, menu)) {
        // Found menu
        if (*p != NUL && menu->children == NULL) {
          if (*p != NUL) {
            EMSG(_(e_notsubmenu));
            return NULL;
          } else if ((menu->modes & modes) == 0x0) {
            EMSG(_(e_othermode));
            return NULL;
          }
        }
        if (*p == NUL) {  // found a full match
          return menu;
        }
        break;
      }
      menu = menu->next;
    }

    if (menu == NULL) {
      EMSG2(_(e_nomenu), name);
      return NULL;
    }
    // Found a match, search the sub-menu.
    name = p;
    menu = menu->children;
  }
  return menu;
}

/// Show the mapping associated with a menu item or hierarchy in a sub-menu.
static int show_menus(char_u *const path_name, int modes)
{
  vimmenu_T   *menu;

  // First, find the (sub)menu with the given name
  menu = find_menu(root_menu, path_name, modes);
  if (!menu) {
    return FAIL;
  }

  /* Now we have found the matching menu, and we list the mappings */
  /* Highlight title */
  MSG_PUTS_TITLE(_("\n--- Menus ---"));

  show_menus_recursive(menu->parent, modes, 0);
  return OK;
}

/// Recursively show the mappings associated with the menus under the given one
static void show_menus_recursive(vimmenu_T *menu, int modes, int depth)
{
  int i;
  int bit;

  if (menu != NULL && (menu->modes & modes) == 0x0)
    return;

  if (menu != NULL) {
    msg_putchar('\n');
    if (got_int)                /* "q" hit for "--more--" */
      return;
    for (i = 0; i < depth; i++)
      MSG_PUTS("  ");
    if (menu->priority) {
      msg_outnum((long)menu->priority);
      MSG_PUTS(" ");
    }
    // Same highlighting as for directories!?
    msg_outtrans_attr(menu->name, HL_ATTR(HLF_D));
  }

  if (menu != NULL && menu->children == NULL) {
    for (bit = 0; bit < MENU_MODES; bit++)
      if ((menu->modes & modes & (1 << bit)) != 0) {
        msg_putchar('\n');
        if (got_int)                    /* "q" hit for "--more--" */
          return;
        for (i = 0; i < depth + 2; i++)
          MSG_PUTS("  ");
        msg_putchar(menu_mode_chars[bit]);
        if (menu->noremap[bit] == REMAP_NONE)
          msg_putchar('*');
        else if (menu->noremap[bit] == REMAP_SCRIPT)
          msg_putchar('&');
        else
          msg_putchar(' ');
        if (menu->silent[bit])
          msg_putchar('s');
        else
          msg_putchar(' ');
        if ((menu->modes & menu->enabled & (1 << bit)) == 0)
          msg_putchar('-');
        else
          msg_putchar(' ');
        MSG_PUTS(" ");
        if (*menu->strings[bit] == NUL) {
          msg_puts_attr("<Nop>", HL_ATTR(HLF_8));
        } else {
          msg_outtrans_special(menu->strings[bit], false);
        }
      }
  } else {
    if (menu == NULL) {
      menu = root_menu;
      depth--;
    } else
      menu = menu->children;

    /* recursively show all children.  Skip PopUp[nvoci]. */
    for (; menu != NULL && !got_int; menu = menu->next)
      if (!menu_is_hidden(menu->dname))
        show_menus_recursive(menu, modes, depth + 1);
  }
}


/*
 * Used when expanding menu names.
 */
static vimmenu_T        *expand_menu = NULL;
static int expand_modes = 0x0;
static int expand_emenu;                /* TRUE for ":emenu" command */

/*
 * Work out what to complete when doing command line completion of menu names.
 */
char_u *set_context_in_menu_cmd(expand_T *xp, char_u *cmd, char_u *arg, int forceit)
{
  char_u      *after_dot;
  char_u      *p;
  char_u      *path_name = NULL;
  char_u      *name;
  int unmenu;
  vimmenu_T   *menu;
  int expand_menus;

  xp->xp_context = EXPAND_UNSUCCESSFUL;


  /* Check for priority numbers, enable and disable */
  for (p = arg; *p; ++p)
    if (!ascii_isdigit(*p) && *p != '.')
      break;

  if (!ascii_iswhite(*p)) {
    if (STRNCMP(arg, "enable", 6) == 0
        && (arg[6] == NUL ||  ascii_iswhite(arg[6])))
      p = arg + 6;
    else if (STRNCMP(arg, "disable", 7) == 0
             && (arg[7] == NUL || ascii_iswhite(arg[7])))
      p = arg + 7;
    else
      p = arg;
  }

  while (*p != NUL && ascii_iswhite(*p))
    ++p;

  arg = after_dot = p;

  for (; *p && !ascii_iswhite(*p); ++p) {
    if ((*p == '\\' || *p == Ctrl_V) && p[1] != NUL)
      p++;
    else if (*p == '.')
      after_dot = p + 1;
  }

  // ":popup" only uses menues, not entries
  expand_menus = !((*cmd == 't' && cmd[1] == 'e') || *cmd == 'p');
  expand_emenu = (*cmd == 'e');
  if (expand_menus && ascii_iswhite(*p))
    return NULL;        /* TODO: check for next command? */
  if (*p == NUL) {              /* Complete the menu name */
    /*
     * With :unmenu, you only want to match menus for the appropriate mode.
     * With :menu though you might want to add a menu with the same name as
     * one in another mode, so match menus from other modes too.
     */
    expand_modes = get_menu_cmd_modes(cmd, forceit, NULL, &unmenu);
    if (!unmenu)
      expand_modes = MENU_ALL_MODES;

    menu = root_menu;
    if (after_dot > arg) {
      size_t path_len = (size_t) (after_dot - arg);
      path_name = xmalloc(path_len);
      STRLCPY(path_name, arg, path_len);
    }
    name = path_name;
    while (name != NULL && *name) {
      p = menu_name_skip(name);
      while (menu != NULL) {
        if (menu_name_equal(name, menu)) {
          /* Found menu */
          if ((*p != NUL && menu->children == NULL)
              || ((menu->modes & expand_modes) == 0x0)) {
            /*
             * Menu path continues, but we have reached a leaf.
             * Or menu exists only in another mode.
             */
            xfree(path_name);
            return NULL;
          }
          break;
        }
        menu = menu->next;
      }
      if (menu == NULL) {
        /* No menu found with the name we were looking for */
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
  } else                        /* We're in the mapping part */
    xp->xp_context = EXPAND_NOTHING;
  return NULL;
}

/*
 * Function given to ExpandGeneric() to obtain the list of (sub)menus (not
 * entries).
 */
char_u *get_menu_name(expand_T *xp, int idx)
{
  static vimmenu_T    *menu = NULL;
  char_u              *str;
  static int should_advance = FALSE;

  if (idx == 0) {           /* first call: start at first item */
    menu = expand_menu;
    should_advance = FALSE;
  }

  /* Skip PopUp[nvoci]. */
  while (menu != NULL && (menu_is_hidden(menu->dname)
                          || menu_is_separator(menu->dname)
                          || menu->children == NULL))
    menu = menu->next;

  if (menu == NULL)         /* at end of linked list */
    return NULL;

  if (menu->modes & expand_modes)
    if (should_advance)
      str = menu->en_dname;
    else {
      str = menu->dname;
      if (menu->en_dname == NULL)
        should_advance = TRUE;
    }
  else
    str = (char_u *)"";

  if (should_advance)
    /* Advance to next menu entry. */
    menu = menu->next;

  should_advance = !should_advance;

  return str;
}

/*
 * Function given to ExpandGeneric() to obtain the list of menus and menu
 * entries.
 */
char_u *get_menu_names(expand_T *xp, int idx)
{
  static vimmenu_T    *menu = NULL;
#define TBUFFER_LEN 256
  static char_u tbuffer[TBUFFER_LEN];         /*hack*/
  char_u              *str;
  static int should_advance = FALSE;

  if (idx == 0) {           /* first call: start at first item */
    menu = expand_menu;
    should_advance = FALSE;
  }

  /* Skip Browse-style entries, popup menus and separators. */
  while (menu != NULL
         && (   menu_is_hidden(menu->dname)
                || (expand_emenu && menu_is_separator(menu->dname))
                || menu->dname[STRLEN(menu->dname) - 1] == '.'
                ))
    menu = menu->next;

  if (menu == NULL)         /* at end of linked list */
    return NULL;

  if (menu->modes & expand_modes) {
    if (menu->children != NULL) {
      if (should_advance)
        STRLCPY(tbuffer, menu->en_dname, TBUFFER_LEN - 1);
      else {
        STRLCPY(tbuffer, menu->dname,  TBUFFER_LEN - 1);
        if (menu->en_dname == NULL)
          should_advance = TRUE;
      }
      /* hack on menu separators:  use a 'magic' char for the separator
       * so that '.' in names gets escaped properly */
      STRCAT(tbuffer, "\001");
      str = tbuffer;
    } else {
      if (should_advance)
        str = menu->en_dname;
      else {
        str = menu->dname;
        if (menu->en_dname == NULL)
          should_advance = TRUE;
      }
    }
  } else
    str = (char_u *)"";

  if (should_advance)
    /* Advance to next menu entry. */
    menu = menu->next;

  should_advance = !should_advance;

  return str;
}


/// Skip over this element of the menu path and return the start of the next
/// element.  Any \ and ^Vs are removed from the current element.
///
/// @param name may be modified.
/// @return start of the next element
char_u *menu_name_skip(char_u *const name)
{
  char_u  *p;

  for (p = name; *p && *p != '.'; MB_PTR_ADV(p)) {
    if (*p == '\\' || *p == Ctrl_V) {
      STRMOVE(p, p + 1);
      if (*p == NUL)
        break;
    }
  }
  if (*p)
    *p++ = NUL;
  return p;
}

/*
 * Return TRUE when "name" matches with menu "menu".  The name is compared in
 * two ways: raw menu name and menu name without '&'.  ignore part after a TAB.
 */
static bool menu_name_equal(const char_u *const name, vimmenu_T *const menu)
{
  if (menu->en_name != NULL
      && (menu_namecmp(name, menu->en_name)
          || menu_namecmp(name, menu->en_dname)))
    return true;
  return menu_namecmp(name, menu->name) || menu_namecmp(name, menu->dname);
}

static bool menu_namecmp(const char_u *const name, const char_u *const mname)
{
  int i;

  for (i = 0; name[i] != NUL && name[i] != TAB; ++i)
    if (name[i] != mname[i])
      break;
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
int
get_menu_cmd_modes(
    const char_u * cmd,
    bool forceit,
    int *noremap,
    int *unmenu
)
{
  int modes;

  switch (*cmd++) {
  case 'v':                             /* vmenu, vunmenu, vnoremenu */
    modes = MENU_VISUAL_MODE | MENU_SELECT_MODE;
    break;
  case 'x':                             /* xmenu, xunmenu, xnoremenu */
    modes = MENU_VISUAL_MODE;
    break;
  case 's':                             /* smenu, sunmenu, snoremenu */
    modes = MENU_SELECT_MODE;
    break;
  case 'o':                             /* omenu */
    modes = MENU_OP_PENDING_MODE;
    break;
  case 'i':                             /* imenu */
    modes = MENU_INSERT_MODE;
    break;
  case 't':
    modes = MENU_TIP_MODE;              /* tmenu */
    break;
  case 'c':                             /* cmenu */
    modes = MENU_CMDLINE_MODE;
    break;
  case 'a':                             /* amenu */
    modes = MENU_INSERT_MODE | MENU_CMDLINE_MODE | MENU_NORMAL_MODE
            | MENU_VISUAL_MODE | MENU_SELECT_MODE
            | MENU_OP_PENDING_MODE;
    break;
  case 'n':
    if (*cmd != 'o') {                  /* nmenu, not noremenu */
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

  if (noremap != NULL)
    *noremap = (*cmd == 'n' ? REMAP_NONE : REMAP_YES);
  if (unmenu != NULL)
    *unmenu = (*cmd == 'u');
  return modes;
}

/*
 * Modify a menu name starting with "PopUp" to include the mode character.
 * Returns the name in allocated memory.
 */
static char_u *popup_mode_name(char_u *name, int idx)
{
  size_t len = STRLEN(name);
  assert(len >= 4);

  char_u *p = vim_strnsave(name, len + 1);
  memmove(p + 6, p + 5, len - 4);
  p[5] = menu_mode_chars[idx];

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
static char_u *menu_text(const char_u *str, int *mnemonic, char_u **actext)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_NONNULL_ARG(1)
{
  char_u      *p;
  char_u      *text;

  /* Locate accelerator text, after the first TAB */
  p = vim_strchr(str, TAB);
  if (p != NULL) {
    if (actext != NULL)
      *actext = vim_strsave(p + 1);
    assert(p >= str);
    text = vim_strnsave(str, (size_t)(p - str));
  } else
    text = vim_strsave(str);

  /* Find mnemonic characters "&a" and reduce "&&" to "&". */
  for (p = text; p != NULL; ) {
    p = vim_strchr(p, '&');
    if (p != NULL) {
      if (p[1] == NUL)              /* trailing "&" */
        break;
      if (mnemonic != NULL && p[1] != '&')
        *mnemonic = p[1];
      STRMOVE(p, p + 1);
      p = p + 1;
    }
  }
  return text;
}

/*
 * Return TRUE if "name" can be a menu in the MenuBar.
 */
int menu_is_menubar(char_u *name)
{
  return !menu_is_popup(name)
         && !menu_is_toolbar(name)
         && *name != MNU_HIDDEN_CHAR;
}

/*
 * Return TRUE if "name" is a popup menu name.
 */
int menu_is_popup(char_u *name)
{
  return STRNCMP(name, "PopUp", 5) == 0;
}


/*
 * Return TRUE if "name" is a toolbar menu name.
 */
int menu_is_toolbar(char_u *name)
{
  return STRNCMP(name, "ToolBar", 7) == 0;
}

/*
 * Return TRUE if the name is a menu separator identifier: Starts and ends
 * with '-'
 */
int menu_is_separator(char_u *name)
{
  return name[0] == '-' && name[STRLEN(name) - 1] == '-';
}


/// True if a popup menu or starts with \ref MNU_HIDDEN_CHAR
///
/// @return true if the menu is hidden
static int menu_is_hidden(char_u *name)
{
  return (name[0] == MNU_HIDDEN_CHAR)
          || (menu_is_popup(name) && name[5] != NUL);
}

/*
 * Given a menu descriptor, e.g. "File.New", find it in the menu hierarchy and
 * execute it.
 */
void ex_emenu(exarg_T *eap)
{
  vimmenu_T   *menu;
  char_u      *name;
  char_u      *saved_name;
  char_u      *p;
  int idx;
  char_u      *mode;

  saved_name = vim_strsave(eap->arg);

  menu = root_menu;
  name = saved_name;
  while (*name) {
    /* Find in the menu hierarchy */
    p = menu_name_skip(name);

    while (menu != NULL) {
      if (menu_name_equal(name, menu)) {
        if (*p == NUL && menu->children != NULL) {
          EMSG(_("E333: Menu path must lead to a menu item"));
          menu = NULL;
        } else if (*p != NUL && menu->children == NULL) {
          EMSG(_(e_notsubmenu));
          menu = NULL;
        }
        break;
      }
      menu = menu->next;
    }
    if (menu == NULL || *p == NUL)
      break;
    menu = menu->children;
    name = p;
  }
  xfree(saved_name);
  if (menu == NULL) {
    EMSG2(_("E334: Menu not found: %s"), eap->arg);
    return;
  }

  /* Found the menu, so execute.
   * Use the Insert mode entry when returning to Insert mode. */
  if (((State & INSERT) || restart_edit) && !current_SID) {
    mode = (char_u *)"Insert";
    idx = MENU_INDEX_INSERT;
  } else if (State & CMDLINE) {
      mode = (char_u *)"Command";
      idx = MENU_INDEX_CMDLINE;
  } else if (get_real_state() & VISUAL) {
    /* Detect real visual mode -- if we are really in visual mode we
     * don't need to do any guesswork to figure out what the selection
     * is. Just execute the visual binding for the menu. */
    mode = (char_u *)"Visual";
    idx = MENU_INDEX_VISUAL;
  } else if (eap->addr_count) {
    pos_T tpos;

    mode = (char_u *)"Visual";
    idx = MENU_INDEX_VISUAL;

    /* GEDDES: This is not perfect - but it is a
     * quick way of detecting whether we are doing this from a
     * selection - see if the range matches up with the visual
     * select start and end.  */
    if ((curbuf->b_visual.vi_start.lnum == eap->line1)
        && (curbuf->b_visual.vi_end.lnum) == eap->line2) {
      /* Set it up for visual mode - equivalent to gv.  */
      VIsual_mode = curbuf->b_visual.vi_mode;
      tpos = curbuf->b_visual.vi_end;
      curwin->w_cursor = curbuf->b_visual.vi_start;
      curwin->w_curswant = curbuf->b_visual.vi_curswant;
    } else {
      /* Set it up for line-wise visual mode */
      VIsual_mode = 'V';
      curwin->w_cursor.lnum = eap->line1;
      curwin->w_cursor.col = 1;
      tpos.lnum = eap->line2;
      tpos.col = MAXCOL;
      tpos.coladd = 0;
    }

    /* Activate visual mode */
    VIsual_active = TRUE;
    VIsual_reselect = TRUE;
    check_cursor();
    VIsual = curwin->w_cursor;
    curwin->w_cursor = tpos;

    check_cursor();

    /* Adjust the cursor to make sure it is in the correct pos
     * for exclusive mode */
    if (*p_sel == 'e' && gchar_cursor() != NUL)
      ++curwin->w_cursor.col;
  } else {
    mode = (char_u *)"Normal";
    idx = MENU_INDEX_NORMAL;
  }

  assert(idx != MENU_INDEX_INVALID);
  if (menu->strings[idx] != NULL) {
    // When executing a script or function execute the commands right now.
    // Otherwise put them in the typeahead buffer.
    if (current_SID != 0) {
      exec_normal_cmd(menu->strings[idx], menu->noremap[idx],
                      menu->silent[idx]);
    } else {
      ins_typebuf(menu->strings[idx], menu->noremap[idx], 0, true,
                  menu->silent[idx]);
    }
  } else {
    EMSG2(_("E335: Menu not defined for %s mode"), mode);
  }
}

/*
 * Translation of menu names.  Just a simple lookup table.
 */

typedef struct {
  char_u      *from;            /* English name */
  char_u      *from_noamp;      /* same, without '&' */
  char_u      *to;              /* translated name */
} menutrans_T;

static garray_T menutrans_ga = GA_EMPTY_INIT_VALUE;

#define FREE_MENUTRANS(mt) \
  menutrans_T* _mt = (mt); \
  xfree(_mt->from); \
  xfree(_mt->from_noamp); \
  xfree(_mt->to)

/*
 * ":menutrans".
 * This function is also defined without the +multi_lang feature, in which
 * case the commands are ignored.
 */
void ex_menutranslate(exarg_T *eap)
{
  char_u              *arg = eap->arg;
  char_u              *from, *from_noamp, *to;

  if (menutrans_ga.ga_itemsize == 0)
    ga_init(&menutrans_ga, (int)sizeof(menutrans_T), 5);

  /*
   * ":menutrans clear": clear all translations.
   */
  if (STRNCMP(arg, "clear", 5) == 0 && ends_excmd(*skipwhite(arg + 5))) {
    GA_DEEP_CLEAR(&menutrans_ga, menutrans_T, FREE_MENUTRANS);

    /* Delete all "menutrans_" global variables. */
    del_menutrans_vars();
  } else {
    /* ":menutrans from to": add translation */
    from = arg;
    arg = menu_skip_part(arg);
    to = skipwhite(arg);
    *arg = NUL;
    arg = menu_skip_part(to);
    if (arg == to)
      EMSG(_(e_invarg));
    else {
      from = vim_strsave(from);
      from_noamp = menu_text(from, NULL, NULL);
      assert(arg >= to);
      to = vim_strnsave(to, (size_t)(arg - to));
      menu_translate_tab_and_shift(from);
      menu_translate_tab_and_shift(to);
      menu_unescape_name(from);
      menu_unescape_name(to);
      menutrans_T* tp = GA_APPEND_VIA_PTR(menutrans_T, &menutrans_ga);
      tp->from = from;
      tp->from_noamp = from_noamp;
      tp->to = to;
    }
  }
}

/*
 * Find the character just after one part of a menu name.
 */
static char_u *menu_skip_part(char_u *p)
{
  while (*p != NUL && *p != '.' && !ascii_iswhite(*p)) {
    if ((*p == '\\' || *p == Ctrl_V) && p[1] != NUL)
      ++p;
    ++p;
  }
  return p;
}

/*
 * Lookup part of a menu name in the translations.
 * Return a pointer to the translation or NULL if not found.
 */
static char_u *menutrans_lookup(char_u *name, int len)
{
  menutrans_T         *tp = (menutrans_T *)menutrans_ga.ga_data;
  char_u              *dname;

  for (int i = 0; i < menutrans_ga.ga_len; i++) {
    if (STRNICMP(name, tp[i].from, len) == 0 && tp[i].from[len] == NUL) {
      return tp[i].to;
    }
  }

  /* Now try again while ignoring '&' characters. */
  char_u c = name[len];
  name[len] = NUL;
  dname = menu_text(name, NULL, NULL);
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

/*
 * Unescape the name in the translate dictionary table.
 */
static void menu_unescape_name(char_u *name)
{
  char_u  *p;

  for (p = name; *p && *p != '.'; MB_PTR_ADV(p)) {
    if (*p == '\\') {
      STRMOVE(p, p + 1);
    }
  }
}

/*
 * Isolate the menu name.
 * Skip the menu name, and translate <Tab> into a real TAB.
 */
static char_u *menu_translate_tab_and_shift(char_u *arg_start)
{
  char_u      *arg = arg_start;

  while (*arg && !ascii_iswhite(*arg)) {
    if ((*arg == '\\' || *arg == Ctrl_V) && arg[1] != NUL)
      arg++;
    else if (STRNICMP(arg, "<TAB>", 5) == 0) {
      *arg = TAB;
      STRMOVE(arg + 1, arg + 5);
    }
    arg++;
  }
  if (*arg != NUL)
    *arg++ = NUL;
  arg = skipwhite(arg);

  return arg;
}

