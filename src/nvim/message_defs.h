#pragma once

#include <stdbool.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/grid_defs.h"
#include "nvim/macros_defs.h"

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
