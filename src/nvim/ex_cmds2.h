#pragma once

#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// flags for check_changed()
enum {
  CCGD_AW      = 1,   ///< do autowrite if buffer was changed
  CCGD_MULTWIN = 2,   ///< check also when several wins for the buf
  CCGD_FORCEIT = 4,   ///< ! used
  CCGD_ALLBUF  = 8,   ///< may write all buffers
  CCGD_EXCMD   = 16,  ///< may suggest using !
};

#include "ex_cmds2.h.generated.h"
