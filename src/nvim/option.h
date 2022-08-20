#ifndef NVIM_OPTION_H
#define NVIM_OPTION_H

#include "nvim/ex_cmds_defs.h"  // for exarg_T

/// Returned by get_option_value().
typedef enum {
  gov_unknown,
  gov_bool,
  gov_number,
  gov_string,
  gov_hidden_bool,
  gov_hidden_number,
  gov_hidden_string,
} getoption_T;

// flags for buf_copy_options()
#define BCO_ENTER       1       // going to enter the buffer
#define BCO_ALWAYS      2       // always copy the options
#define BCO_NOHELP      4       // don't touch the help related options

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "option.h.generated.h"
#endif
#endif  // NVIM_OPTION_H
