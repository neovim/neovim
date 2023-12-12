#pragma once

#include <errno.h>
#include <stdbool.h>
#include <stdio.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/grid_defs.h"
#include "nvim/macros_defs.h"

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

enum { MSG_HIST = 0x1000, };  ///< special attribute addition: Put message in history

typedef struct {
  String text;
  int attr;
} HlMessageChunk;

typedef kvec_t(HlMessageChunk) HlMessage;

/// Message history for `:messages`
typedef struct msg_hist {
  struct msg_hist *next;  ///< Next message.
  char *msg;              ///< Message text.
  const char *kind;       ///< Message kind (for msg_ext)
  int attr;               ///< Message highlighting.
  bool multiline;         ///< Multiline message.
  HlMessage multiattr;    ///< multiattr message.
} MessageHistoryEntry;

// Prefer using semsg(), because perror() may send the output to the wrong
// destination and mess up the screen.
#define PERROR(msg) (void)semsg("%s: %s", (msg), strerror(errno))

#ifndef MSWIN
/// Headless (no UI) error message handler.
# define os_errmsg(str)        fprintf(stderr, "%s", (str))
/// Headless (no UI) message handler.
# define os_msg(str)           printf("%s", (str))
#endif
