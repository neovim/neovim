#pragma once

#include <stdint.h>  // IWYU pragma: keep
#include <time.h>

#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/runtime_defs.h"  // IWYU pragma: keep

#define TIME_MSG(s) do { \
  if (time_fd != NULL) time_msg(s, NULL); \
} while (0)

#include "profile.h.generated.h"
