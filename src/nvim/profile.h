#ifndef NVIM_PROFILE_H
#define NVIM_PROFILE_H

#include <stdint.h>
#include <time.h>

#include "nvim/ex_cmds_defs.h"
#include "nvim/runtime.h"

#define TIME_MSG(s) do { \
  if (time_fd != NULL) time_msg(s, NULL); \
} while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "profile.h.generated.h"
#endif

#endif  // NVIM_PROFILE_H
