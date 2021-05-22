#ifndef NVIM_OPTION_H
#define NVIM_OPTION_H

#include "nvim/ex_cmds_defs.h"  // for exarg_T

/* flags for buf_copy_options() */
#define BCO_ENTER       1       /* going to enter the buffer */
#define BCO_ALWAYS      2       /* always copy the options */
#define BCO_NOHELP      4       /* don't touch the help related options */

/// Flags for option-setting functions
///
/// When OPT_GLOBAL and OPT_LOCAL are both missing, set both local and global
/// values, get local value.
typedef enum {
  OPT_FREE     = 1,   ///< Free old value if it was allocated.
  OPT_GLOBAL   = 2,   ///< Use global value.
  OPT_LOCAL    = 4,   ///< Use local value.
  OPT_MODELINE = 8,   ///< Option in modeline.
  OPT_WINONLY  = 16,  ///< Only set window-local options.
  OPT_NOWIN    = 32,  ///< Don’t set window-local options.
  OPT_ONECOLUMN = 64,  ///< list options one per line
  OPT_NO_REDRAW = 128,  ///< ignore redraw flags on option
  OPT_SKIPRTP = 256,  ///< "skiprtp" in 'sessionoptions'
} OptionFlags;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "option.h.generated.h"
#endif
#endif  // NVIM_OPTION_H
