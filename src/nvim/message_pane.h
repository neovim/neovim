#ifndef NVIM_MESSAGE_PANE_H
#define NVIM_MESSAGE_PANE_H

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message_pane.h.generated.h"
#endif

#define MAX_MSGPANE_HIST 1000

typedef struct msgpane_entry {
  char_u *msg;
  int attr;
  double timestamp;
} MessagePaneEntry;

#endif  // NVIM_MESSAGE_PANE_H
