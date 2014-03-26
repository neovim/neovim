#ifndef NEOVIM_OS_EVENT_H
#define NEOVIM_OS_EVENT_H

#include <stdint.h>

typedef enum {
  kEventNone,
  kEventInput,
  kEventEof
} EventType;

void event_init(void);
EventType event_poll(int32_t ms);

#endif

