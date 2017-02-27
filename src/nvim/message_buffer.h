#ifndef NVIM_MESSAGE_BUFFER_H
#define NVIM_MESSAGE_BUFFER_H

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message_buffer.h.generated.h"
#endif

#define MAX_MSGBUF_HIST 1000

typedef struct msgbuf_entry {
  char_u *msg;
  int attr;
  double timestamp;
} MessagePaneEntry;

#endif  // NVIM_MESSAGE_BUFFER_H
