/*
 * VIM - Vi IMproved		by Bram Moolenaar
 *				GUI/Motif support by Robert Webb
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * Code for menus.  Used for the GUI and 'wildmenu'.
 */

#include <string.h>

#include "nvim/vim.h"
#include "nvim/menu.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/eval.h"
#include "nvim/ex_docmd.h"
#include "nvim/getchar.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/keymap.h"
#include "nvim/garray.h"
#include "nvim/strings.h"
#include "nvim/term.h"


#define MENUDEPTH   10          /* maximum depth of menus */


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "menu.c.generated.h"
#endif




/* The character for each menu mode */
static char_u menu_mode_chars[] = {'n', 'v', 's', 'o', 'i', 'c', 't'};

static char_u e_notsubmenu[] = N_(
    "E327: Part of menu-item path is not sub-menu");
static char_u e_othermode[] = N_("E328: Menu only exists in another mode");
static char_u e_nomenu[] = N_("E329: No menu \"%s\"");


/*
 * Do the :menu command and relatives.
 */
void 
ex_menu (
    exarg_T *eap                   /* Ex command arguments */
)
{
  char_u      *menu_path;
  int modes;
  char_u      *map_to;
  int noremap;
  int silent = FALSE;
  int special = FALSE;
  int unmenu;
  char_u      *map_buf;
  char_u      *arg;
  char_u      *p;
  int i;
  int pri_tab[MENUDEPTH + 1];
  int enable = MAYBE;               /* TRUE for "menu enable", FALSE for "menu
                                     * disable */
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
      silent = TRUE;
      arg = skipwhite(arg + 8);
      continue;
    }
    if (STRNCMP(arg, "<special>", 9) == 0) {
      special = TRUE;
      arg = skipwhite(arg + 9);
      continue;
    }
    break;
  }


  /* Locate an optional "icon=filename" argument. */
  if (STRNCMP(arg, "icon=", 5) == 0) {
    arg += 5;
    while (*arg != NUL && *arg != ' ') {
      if (*arg == '\\')
        STRMOVE(arg, arg + 1);
      mb_ptr_adv(arg);
    }
    if (*arg != NUL) {
      *arg++ = NUL;
      arg = skipwhite(arg);
    }
  }

  /*
   * Fill in the priority table.
   */
  for (p = arg; *p; ++p)
    if (!VIM_ISDIGIT(*p) && *p != '.')
      break;
  if (vim_iswhite(*p)) {
    for (i = 0; i < MENUDEPTH && !vim_iswhite(*arg); ++i) {
      pri_tab[i] = getdigits(&arg);
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
  if (STRNCMP(arg, "enable", 6) == 0 && vim_iswhite(arg[6])) {
    enable = TRUE;
    arg = skipwhite(arg + 6);
  } else if (STRNCMP(arg, "disable", 7) == 0 && vim_iswhite(arg[7])) {
    enable = FALSE;
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
  if (*map_to == NUL && !unmenu && enable == MAYBE) {
    show_menus(menu_path, modes);
    goto theend;
  } else if (*map_to != NUL && (unmenu || enable != MAYBE)) {
    EMSG(_(e_trailing));
    goto theend;
  }

  if (enable != MAYBE) {
    /*
     * Change sensitivity of the menu.
     * For the PopUp menu, remove a menu for each mode separately.
     * Careful: menu_nable_recurse() changes menu_path.
     */
    if (STRCMP(menu_path, "*") == 0)            /* meaning: do all menus */
      menu_path = (char_u *)"";

    if (menu_is_popup(menu_path)) {
      for (i = 0; i < MENU_INDEX_TIP; ++i)
        if (modes & (1 << i)) {
          p = popup_mode_name(menu_path, i);
          if (p != NULL) {
            menu_nable_recurse(root_menu, p, MENU_ALL_MODES,
                enable);
            free(p);
          }
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
          if (p != NULL) {
            remove_menu(&root_menu, p, MENU_ALL_MODES, TRUE);
            free(p);
          }
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
    } else if (modes & MENU_TIP_MODE)
      map_buf = NULL;           /* Menu tips are plain text. */
    else
      map_to = replace_termcodes(map_to, &map_buf, FALSE, TRUE, special);
    menuarg.modes = modes;
    menuarg.noremap[0] = noremap;
    menuarg.silent[0] = silent;
    add_menu_path(menu_path, &menuarg, pri_tab, map_to
        );

    /*
     * For the PopUp menu, add a menu for each mode separately.
     */
    if (menu_is_popup(menu_path)) {
      for (i = 0; i < MENU_INDEX_TIP; ++i)
        if (modes & (1 << i)) {
          p = popup_mode_name(menu_path, i);
          if (p != NULL) {
            /* Include all modes, to make ":amenu" work */
            menuarg.modes = modes;
            add_menu_path(p, &menuarg, pri_tab, map_to
                );
            free(p);
          }
        }
    }

    free(map_buf);
  }


theend:
  ;
}

/*
 * Add the menu with the given name to the menu hierarchy
 */
static int 
add_menu_path (
    char_u *menu_path,
    vimmenu_T *menuarg,           /* passes modes, iconfile, iconidx,
                                   icon_builtin, silent[0], noremap[0] */
    int *pri_tab,
    char_u *call_data
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
  int i;
  int c;
  int d;
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
    } else
      en_name = NULL;
    dname = menu_text(name, NULL, NULL);
    if (dname == NULL)
      goto erret;
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
          if (!sys_menu)
            EMSG(_("E330: Menu path must not lead to a sub-menu"));
          goto erret;
        }
        if (*next_name != NUL && menu->children == NULL
            ) {
          if (!sys_menu)
            EMSG(_(e_notsubmenu));
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
      /* separate mnemonic and accelerator text from actual menu name */
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

      /*
       * Add after menu that has lower priority.
       */
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
    free(dname);
    dname = NULL;
    if (pri_tab[pri_idx + 1] != -1)
      ++pri_idx;
  }
  free(path_name);

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

        /* For "amenu", may insert an extra character.
         * Don't do this if adding a tearbar (addtearoff == FALSE).
         * Don't do this for "<Nop>". */
        c = 0;
        d = 0;
        if (amenu && call_data != NULL && *call_data != NUL
            ) {
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
          if (d == 0)
            STRCPY(menu->strings[i] + 1, call_data);
          else {
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
        } else
          menu->strings[i] = p;
        menu->noremap[i] = menuarg->noremap[0];
        menu->silent[i] = menuarg->silent[0];
      }
    }
#if defined(FEAT_TOOLBAR) && !defined(FEAT_GUI_W32) \
    && (defined(FEAT_BEVAL) || defined(FEAT_GUI_GTK))
    /* Need to update the menu tip. */
    if (modes & MENU_TIP_MODE)
      gui_mch_menu_set_tip(menu);
#endif
  }
  return OK;

erret:
  free(path_name);
  free(dname);

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
    int silent                     /* don't give error messages */
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
#if defined(FEAT_GUI_W32) & defined(FEAT_TEAROFF)
        /*
         * If we are removing all entries for this menu,MENU_ALL_MODES,
         * Then kill any tearoff before we start
         */
        if (*p == NUL && modes == MENU_ALL_MODES) {
          if (IsWindow(menu->tearoff_handle))
            DestroyWindow(menu->tearoff_handle);
        }
#endif
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
#if defined(FEAT_GUI_W32) & defined(FEAT_TEAROFF)
    if ((s_tearoffs) && (menu->children != NULL))     /* there's a tear bar.. */
      child = menu->children->next;       /* don't count tearoff bar */
    else
#endif
    child = menu->children;
    for (; child != NULL; child = child->next)
      menu->modes |= child->modes;
    if (modes & MENU_TIP_MODE) {
      free_menu_string(menu, MENU_INDEX_TIP);
#if defined(FEAT_TOOLBAR) && !defined(FEAT_GUI_W32) \
      && (defined(FEAT_BEVAL) || defined(FEAT_GUI_GTK))
      /* Need to update the menu tip. */
      if (gui.in_use)
        gui_mch_menu_set_tip(menu);
#endif
    }
    if ((menu->modes & MENU_ALL_MODES) == 0) {
      /* The menu item is no longer valid in ANY mode, so delete it */
#if defined(FEAT_GUI_W32) & defined(FEAT_TEAROFF)
      if (s_tearoffs && menu->children != NULL)       /* there's a tear bar.. */
        free_menu(&menu->children);
#endif
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
  free(menu->name);
  free(menu->dname);
  free(menu->en_name);
  free(menu->en_dname);
  free(menu->actext);
  for (i = 0; i < MENU_MODES; i++)
    free_menu_string(menu, i);
  free(menu);

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
    free(menu->strings[idx]);
  menu->strings[idx] = NULL;
}

/*
 * Show the mapping associated with a menu item or hierarchy in a sub-menu.
 */
static int show_menus(char_u *path_name, int modes)
{
  char_u      *p;
  char_u      *name;
  vimmenu_T   *menu;
  vimmenu_T   *parent = NULL;

  menu = root_menu;
  name = path_name = vim_strsave(path_name);

  /* First, find the (sub)menu with the given name */
  while (*name) {
    p = menu_name_skip(name);
    while (menu != NULL) {
      if (menu_name_equal(name, menu)) {
        /* Found menu */
        if (*p != NUL && menu->children == NULL) {
          EMSG(_(e_notsubmenu));
          free(path_name);
          return FAIL;
        } else if ((menu->modes & modes) == 0x0) {
          EMSG(_(e_othermode));
          free(path_name);
          return FAIL;
        }
        break;
      }
      menu = menu->next;
    }
    if (menu == NULL) {
      EMSG2(_(e_nomenu), name);
      free(path_name);
      return FAIL;
    }
    name = p;
    parent = menu;
    menu = menu->children;
  }
  free(path_name);

  /* Now we have found the matching menu, and we list the mappings */
  /* Highlight title */
  MSG_PUTS_TITLE(_("\n--- Menus ---"));

  show_menus_recursive(parent, modes, 0);
  return OK;
}

/*
 * Recursively show the mappings associated with the menus under the given one
 */
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
    /* Same highlighting as for directories!? */
    msg_outtrans_attr(menu->name, hl_attr(HLF_D));
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
        if (*menu->strings[bit] == NUL)
          msg_puts_attr((char_u *)"<Nop>", hl_attr(HLF_8));
        else
          msg_outtrans_special(menu->strings[bit], FALSE);
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
    if (!VIM_ISDIGIT(*p) && *p != '.')
      break;

  if (!vim_iswhite(*p)) {
    if (STRNCMP(arg, "enable", 6) == 0
        && (arg[6] == NUL ||  vim_iswhite(arg[6])))
      p = arg + 6;
    else if (STRNCMP(arg, "disable", 7) == 0
             && (arg[7] == NUL || vim_iswhite(arg[7])))
      p = arg + 7;
    else
      p = arg;
  }

  while (*p != NUL && vim_iswhite(*p))
    ++p;

  arg = after_dot = p;

  for (; *p && !vim_iswhite(*p); ++p) {
    if ((*p == '\\' || *p == Ctrl_V) && p[1] != NUL)
      p++;
    else if (*p == '.')
      after_dot = p + 1;
  }

  /* ":tearoff" and ":popup" only use menus, not entries */
  expand_menus = !((*cmd == 't' && cmd[1] == 'e') || *cmd == 'p');
  expand_emenu = (*cmd == 'e');
  if (expand_menus && vim_iswhite(*p))
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
    if (after_dot != arg) {
      path_name = xmalloc(after_dot - arg);
      STRLCPY(path_name, arg, after_dot - arg);
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
            free(path_name);
            return NULL;
          }
          break;
        }
        menu = menu->next;
      }
      if (menu == NULL) {
        /* No menu found with the name we were looking for */
        free(path_name);
        return NULL;
      }
      name = p;
      menu = menu->children;
    }
    free(path_name);

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
                          || menu_is_tearoff(menu->dname)
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
                || menu_is_tearoff(menu->dname)
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

/*
 * Skip over this element of the menu path and return the start of the next
 * element.  Any \ and ^Vs are removed from the current element.
 * "name" may be modified.
 */
char_u *menu_name_skip(char_u *name)
{
  char_u  *p;

  for (p = name; *p && *p != '.'; mb_ptr_adv(p)) {
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
static int menu_name_equal(char_u *name, vimmenu_T *menu)
{
  if (menu->en_name != NULL
      && (menu_namecmp(name, menu->en_name)
          || menu_namecmp(name, menu->en_dname)))
    return TRUE;
  return menu_namecmp(name, menu->name) || menu_namecmp(name, menu->dname);
}

static int menu_namecmp(char_u *name, char_u *mname)
{
  int i;

  for (i = 0; name[i] != NUL && name[i] != TAB; ++i)
    if (name[i] != mname[i])
      break;
  return (name[i] == NUL || name[i] == TAB)
         && (mname[i] == NUL || mname[i] == TAB);
}

/*
 * Return the modes specified by the given menu command (eg :menu! returns
 * MENU_CMDLINE_MODE | MENU_INSERT_MODE).
 * If "noremap" is not NULL, then the flag it points to is set according to
 * whether the command is a "nore" command.
 * If "unmenu" is not NULL, then the flag it points to is set according to
 * whether the command is an "unmenu" command.
 */
static int 
get_menu_cmd_modes (
    char_u *cmd,
    int forceit,                /* Was there a "!" after the command? */
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
  /* FALLTHROUGH */
  default:
    --cmd;
    if (forceit)                        /* menu!! */
      modes = MENU_INSERT_MODE | MENU_CMDLINE_MODE;
    else                                /* menu */
      modes = MENU_NORMAL_MODE | MENU_VISUAL_MODE | MENU_SELECT_MODE
              | MENU_OP_PENDING_MODE;
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
  char_u      *p;
  int len = (int)STRLEN(name);

  p = vim_strnsave(name, len + 1);
  memmove(p + 6, p + 5, (size_t)(len - 4));
  p[5] = menu_mode_chars[idx];

  return p;
}


/*
 * Duplicate the menu item text and then process to see if a mnemonic key
 * and/or accelerator text has been identified.
 * Returns a pointer to allocated memory, or NULL for failure.
 * If mnemonic != NULL, *mnemonic is set to the character after the first '&'.
 * If actext != NULL, *actext is set to the text after the first TAB.
 */
static char_u *menu_text(char_u *str, int *mnemonic, char_u **actext)
{
  char_u      *p;
  char_u      *text;

  /* Locate accelerator text, after the first TAB */
  p = vim_strchr(str, TAB);
  if (p != NULL) {
    if (actext != NULL)
      *actext = vim_strsave(p + 1);
    text = vim_strnsave(str, (int)(p - str));
  } else
    text = vim_strsave(str);

  /* Find mnemonic characters "&a" and reduce "&&" to "&". */
  for (p = text; p != NULL; ) {
    p = vim_strchr(p, '&');
    if (p != NULL) {
      if (p[1] == NUL)              /* trailing "&" */
        break;
      if (mnemonic != NULL && p[1] != '&')
#if !defined(__MVS__) || defined(MOTIF390_MNEMONIC_FIXED)
        *mnemonic = p[1];
#else
      {
        /*
         * Well there is a bug in the Motif libraries on OS390 Unix.
         * The mnemonic keys needs to be converted to ASCII values
         * first.
         * This behavior has been seen in 2.8 and 2.9.
         */
        char c = p[1];
        __etoa_l(&c, 1);
        *mnemonic = c;
      }
#endif
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

/*
 * Return TRUE if the menu is hidden:  Starts with ']'
 */
static int menu_is_hidden(char_u *name)
{
  return (name[0] == ']') || (menu_is_popup(name) && name[5] != NUL);
}

/*
 * Return TRUE if the menu is the tearoff menu.
 */
static int menu_is_tearoff(char_u *name)
{
  return FALSE;
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
  free(saved_name);
  if (menu == NULL) {
    EMSG2(_("E334: Menu not found: %s"), eap->arg);
    return;
  }

  /* Found the menu, so execute.
   * Use the Insert mode entry when returning to Insert mode. */
  if (restart_edit
      && !current_SID
      ) {
    mode = (char_u *)"Insert";
    idx = MENU_INDEX_INSERT;
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

  if (idx != MENU_INDEX_INVALID && menu->strings[idx] != NULL) {
    /* When executing a script or function execute the commands right now.
     * Otherwise put them in the typeahead buffer. */
    if (current_SID != 0)
      exec_normal_cmd(menu->strings[idx], menu->noremap[idx],
          menu->silent[idx]);
    else
      ins_typebuf(menu->strings[idx], menu->noremap[idx], 0,
          TRUE, menu->silent[idx]);
  } else
    EMSG2(_("E335: Menu not defined for %s mode"), mode);
}

#if defined(FEAT_GUI_MSWIN) \
  || defined(FEAT_GUI_GTK) \
  || defined(FEAT_BEVAL_TIP) || defined(PROTO)
/*
 * Given a menu descriptor, e.g. "File.New", find it in the menu hierarchy.
 */
vimmenu_T *gui_find_menu(char_u *path_name)
{
  vimmenu_T   *menu = NULL;
  char_u      *name;
  char_u      *saved_name;
  char_u      *p;

  menu = root_menu;

  saved_name = vim_strsave(path_name);

  name = saved_name;
  while (*name) {
    /* find the end of one dot-separated name and put a NUL at the dot */
    p = menu_name_skip(name);

    while (menu != NULL) {
      if (menu_name_equal(name, menu)) {
        if (menu->children == NULL) {
          /* found a menu item instead of a sub-menu */
          if (*p == NUL)
            EMSG(_("E336: Menu path must lead to a sub-menu"));
          else
            EMSG(_(e_notsubmenu));
          menu = NULL;
          goto theend;
        }
        if (*p == NUL)              /* found a full match */
          goto theend;
        break;
      }
      menu = menu->next;
    }
    if (menu == NULL)           /* didn't find it */
      break;

    /* Found a match, search the sub-menu. */
    menu = menu->children;
    name = p;
  }

  if (menu == NULL)
    EMSG(_("E337: Menu not found - check menu names"));
theend:
  free(saved_name);
  return menu;
}
#endif

/*
 * Translation of menu names.  Just a simple lookup table.
 */

typedef struct {
  char_u      *from;            /* English name */
  char_u      *from_noamp;      /* same, without '&' */
  char_u      *to;              /* translated name */
} menutrans_T;

static garray_T menutrans_ga = {0, 0, 0, 0, NULL};

/*
 * ":menutrans".
 * This function is also defined without the +multi_lang feature, in which
 * case the commands are ignored.
 */
void ex_menutranslate(exarg_T *eap)
{
  char_u              *arg = eap->arg;
  menutrans_T         *tp;
  char_u              *from, *from_noamp, *to;

  if (menutrans_ga.ga_itemsize == 0)
    ga_init(&menutrans_ga, (int)sizeof(menutrans_T), 5);

  /*
   * ":menutrans clear": clear all translations.
   */
  if (STRNCMP(arg, "clear", 5) == 0 && ends_excmd(*skipwhite(arg + 5))) {
    tp = (menutrans_T *)menutrans_ga.ga_data;
    for (int i = 0; i < menutrans_ga.ga_len; ++i) {
      free(tp[i].from);
      free(tp[i].from_noamp);
      free(tp[i].to);
    }
    ga_clear(&menutrans_ga);
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
      ga_grow(&menutrans_ga, 1);
      tp = (menutrans_T *)menutrans_ga.ga_data;
      from = vim_strsave(from);
      from_noamp = menu_text(from, NULL, NULL);
      to = vim_strnsave(to, (int)(arg - to));
      if (from_noamp != NULL) {
        menu_translate_tab_and_shift(from);
        menu_translate_tab_and_shift(to);
        menu_unescape_name(from);
        menu_unescape_name(to);
        tp[menutrans_ga.ga_len].from = from;
        tp[menutrans_ga.ga_len].from_noamp = from_noamp;
        tp[menutrans_ga.ga_len].to = to;
        ++menutrans_ga.ga_len;
      } else {
        free(from);
        free(from_noamp);
        free(to);
      }
    }
  }
}

/*
 * Find the character just after one part of a menu name.
 */
static char_u *menu_skip_part(char_u *p)
{
  while (*p != NUL && *p != '.' && !vim_iswhite(*p)) {
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

  for (int i = 0; i < menutrans_ga.ga_len; ++i) {
    if (STRNCMP(name, tp[i].from, len) == 0 && tp[i].from[len] == NUL) {
      return tp[i].to;
    }
  }

  /* Now try again while ignoring '&' characters. */
  char c = name[len];
  name[len] = NUL;
  dname = menu_text(name, NULL, NULL);
  name[len] = c;
  if (dname != NULL) {
    for (int i = 0; i < menutrans_ga.ga_len; ++i) {
      if (STRCMP(dname, tp[i].from_noamp) == 0) {
        free(dname);
        return tp[i].to;
      }
    }
    free(dname);
  }

  return NULL;
}

/*
 * Unescape the name in the translate dictionary table.
 */
static void menu_unescape_name(char_u *name)
{
  char_u  *p;

  for (p = name; *p && *p != '.'; mb_ptr_adv(p))
    if (*p == '\\')
      STRMOVE(p, p + 1);
}

/*
 * Isolate the menu name.
 * Skip the menu name, and translate <Tab> into a real TAB.
 */
static char_u *menu_translate_tab_and_shift(char_u *arg_start)
{
  char_u      *arg = arg_start;

  while (*arg && !vim_iswhite(*arg)) {
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

