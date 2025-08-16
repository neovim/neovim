#pragma once

#include <stdbool.h>

#include "nvim/api/private/defs.h"

typedef struct {
  String text;
  int hl_id;
} HlMessageChunk;

typedef kvec_t(HlMessageChunk) HlMessage;
typedef int64_t MsgID;

#define MSG_KIND_PROGRESS "progress"

typedef struct msg_ext_data {
  Integer percent;         ///< Progress percentage
  String title;            ///< Title for progress message
  String status;           ///< Status for progress message
} MessageExtData;
/// Message history for `:messages`
typedef struct msg_hist {
  MsgID message_id;           ///< Indentifier of the message
  struct msg_hist *next;      ///< Next message.
  struct msg_hist *prev;      ///< Previous message.
  HlMessage msg;              ///< Highlighted message.
  const char *kind;           ///< Message kind (for msg_ext)
  bool temp;                  ///< Temporary message since last command ("g<")
  bool append;                ///< Message should be appended to previous entry, as opposed
                              ///< to on a new line (|ui-messages|->msg_show->append).
  MessageExtData ext_data;    ///< Additional data for special messages
} MessageHistoryEntry;
