#pragma once

#include <errno.h>
#include <stdbool.h>
#include <stddef.h>  // IWYU pragma: keep

#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/grid_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/message_defs.h"  // IWYU pragma: keep

/// Types of dialogs passed to do_dialog().
enum {
  VIM_GENERIC   = 0,
  VIM_ERROR     = 1,
  VIM_WARNING   = 2,
  VIM_INFO      = 3,
  VIM_QUESTION  = 4,
  VIM_LAST_TYPE = 4,  ///< sentinel value
};

/// Return values for functions like vim_dialogyesno()
enum {
  VIM_YES        = 2,
  VIM_NO         = 3,
  VIM_CANCEL     = 4,
  VIM_ALL        = 5,
  VIM_DISCARDALL = 6,
};

extern MessageHistoryEntry *msg_hist_last;

EXTERN bool msg_ext_need_clear INIT( = false);
/// Set to true to force grouping a set of message chunks into a single `cmdline_show` event.
EXTERN bool msg_ext_skip_flush INIT( = false);
/// Set to true when message should be appended to previous message line.
EXTERN bool msg_ext_append INIT( = false);
/// Set to true when previous message should be overwritten.
EXTERN bool msg_ext_overwrite INIT( = false);
/// Set to true when output of previous command should be cleared.
EXTERN bool msg_may_clear_temp INIT( = true);

EXTERN int msg_listdo_overwrite INIT( = 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message.h.generated.h"
#endif

// Prefer using semsg(), because perror() may send the output to the wrong
// destination and mess up the screen.
#define PERROR(msg) (void)semsg("%s: %s", (msg), strerror(errno))
