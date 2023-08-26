#ifndef NVIM_PROFILE_H
#define NVIM_PROFILE_H

#include <stdint.h>
#include <time.h>

#include "nvim/cmdexpand_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/runtime.h"

#define TIME_MSG(s) do { \
  DLOG("%s", s); \
} while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "profile.h.generated.h"
#endif

#endif  // NVIM_PROFILE_H
