#ifndef NVIM_MENU_H
#define NVIM_MENU_H

#include <stdbool.h> // for bool

#include "nvim/types.h" // for char_u and expand_T
#include "nvim/ex_cmds_defs.h" // for exarg_T

/// @}
/// note MENU_INDEX_TIP is not a 'real' mode

/// Menu modes
/// \addtogroup MENU_MODES
/// @{
#define MENU_NORMAL_MODE        (1 << MENU_INDEX_NORMAL)
#define MENU_VISUAL_MODE        (1 << MENU_INDEX_VISUAL)
#define MENU_SELECT_MODE        (1 << MENU_INDEX_SELECT)
#define MENU_OP_PENDING_MODE    (1 << MENU_INDEX_OP_PENDING)
#define MENU_INSERT_MODE        (1 << MENU_INDEX_INSERT)
#define MENU_CMDLINE_MODE       (1 << MENU_INDEX_CMDLINE)
#define MENU_TIP_MODE           (1 << MENU_INDEX_TIP)
#define MENU_ALL_MODES          ((1 << MENU_INDEX_TIP) - 1)
/// @}

/// Start a menu name with this to not include it on the main menu bar
#define MNU_HIDDEN_CHAR         ']'

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "menu.h.generated.h"
#endif
#endif  // NVIM_MENU_H
