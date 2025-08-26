#pragma once

#include <stdbool.h>

#include "nvim/api/private/defs.h"

typedef struct {
  String text;
  int hl_id;
} HlMessageChunk;

typedef kvec_t(HlMessageChunk) HlMessage;
#define MsgID Union(Integer, String)

#define MSG_KIND_PROGRESS "progress"

typedef struct msg_data {
  Integer percent;        ///< Progress percentage
  String title;           ///< Title for progress message
  String status;          ///< Status for progress message
  DictOf(String, Object) data;  ///< Extra info for 'echo' messages
} MessageData;
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
