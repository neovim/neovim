#pragma once

#include <stdbool.h>

#include "nvim/api/private/defs.h"

typedef struct {
  String text;
  int hl_id;
} HlMessageChunk;

typedef kvec_t(HlMessageChunk) HlMessage;

/// Message history for `:messages`
typedef struct msg_hist {
  struct msg_hist *next;  ///< Next message.
  char *msg;              ///< Message text.
  const char *kind;       ///< Message kind (for msg_ext)
  int hl_id;               ///< Message highlighting.
  bool multiline;         ///< Multiline message.
  HlMessage multihl;      ///< Multihl message.
} MessageHistoryEntry;
