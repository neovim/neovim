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
} OptionFlags;

// WV_ and BV_ values get typecasted to this for the "indir" field
typedef enum {
  PV_NONE = 0,
  PV_MAXVAL = 0xffff      // to avoid warnings for value out of range
} idopt_T;

typedef struct vimoption {
  char        *fullname;        // full option name
  char        *shortname;       // permissible abbreviation
  uint32_t flags;               // see below
  char_u      *var;             // global option: pointer to variable;
                                // window-local option: VAR_WIN;
                                // buffer-local option: global value
  idopt_T indir;                // global option: PV_NONE;
                                // local option: indirect option index
  char_u      *def_val[2];      // default values for variable (vi and vim)
  LastSet last_set;             // script in which the option was last set
# define SCTX_INIT , { 0, 0, 0 }
} vimoption_T;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "option.h.generated.h"
#endif
#endif  // NVIM_OPTION_H
