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
  struct msg_hist *prev;  ///< Previous message.
  HlMessage msg;          ///< Highlighted message.
  const char *kind;       ///< Message kind (for msg_ext)
  bool temp;              ///< Temporary message since last command ("g<")
  bool append;            ///< Message should be appended to previous entry, as opposed
                          ///< to on a new line (|ui-messages|->msg_show->append).
} MessageHistoryEntry;
