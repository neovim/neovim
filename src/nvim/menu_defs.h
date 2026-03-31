#pragma once

#include <stdbool.h>

/// Indices into vimmenu_T->strings[] and vimmenu_T->noremap[] for each mode
/// \addtogroup MENU_INDEX
/// @{
enum {
  MENU_INDEX_INVALID    = -1,
  MENU_INDEX_NORMAL     = 0,
  MENU_INDEX_VISUAL     = 1,
  MENU_INDEX_SELECT     = 2,
  MENU_INDEX_OP_PENDING = 3,
  MENU_INDEX_INSERT     = 4,
  MENU_INDEX_CMDLINE    = 5,
  MENU_INDEX_TERMINAL   = 6,
  MENU_INDEX_TIP        = 7,
  MENU_MODES            = 8,
};
/// @}

/// Menu modes
/// \addtogroup MENU_MODES
/// @{
enum {
  MENU_NORMAL_MODE     = 1 << MENU_INDEX_NORMAL,
  MENU_VISUAL_MODE     = 1 << MENU_INDEX_VISUAL,
  MENU_SELECT_MODE     = 1 << MENU_INDEX_SELECT,
  MENU_OP_PENDING_MODE = 1 << MENU_INDEX_OP_PENDING,
  MENU_INSERT_MODE     = 1 << MENU_INDEX_INSERT,
  MENU_CMDLINE_MODE    = 1 << MENU_INDEX_CMDLINE,
  MENU_TERMINAL_MODE   = 1 << MENU_INDEX_TERMINAL,
  MENU_TIP_MODE        = 1 << MENU_INDEX_TIP,
  MENU_ALL_MODES       = (1 << MENU_INDEX_TIP) - 1,
};
/// @}
/// note MENU_INDEX_TIP is not a 'real' mode

/// Start a menu name with this to not include it on the main menu bar
#define MNU_HIDDEN_CHAR         ']'

typedef struct VimMenu vimmenu_T;

struct VimMenu {
  int modes;                  ///< Which modes is this menu visible for
  int enabled;                ///< for which modes the menu is enabled
  char *name;                 ///< Name of menu, possibly translated
  char *dname;                ///< Displayed Name ("name" without '&')
  char *en_name;              ///< "name" untranslated, NULL when
                              ///< was not translated
  char *en_dname;             ///< NULL when "dname" untranslated
  int mnemonic;               ///< mnemonic key (after '&')
  char *actext;               ///< accelerator text (after TAB)
  int priority;               ///< Menu order priority
  char *strings[MENU_MODES];  ///< Mapped string for each mode
  int noremap[MENU_MODES];    ///< A \ref REMAP_VALUES flag for each mode
  bool silent[MENU_MODES];    ///< A silent flag for each mode
  vimmenu_T *children;        ///< Children of sub-menu
  vimmenu_T *parent;          ///< Parent of menu
  vimmenu_T *next;            ///< Next item in menu
};
