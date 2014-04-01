#ifndef NEOVIM_OS_EVENT_H
#define NEOVIM_OS_EVENT_H

#include <stdint.h>
#include <stdbool.h>

typedef enum {
  kEventSignal
} EventType;

typedef struct {
  EventType type;
  void *data;
} Event;

void event_init(void);
bool event_poll(int32_t ms);
void event_push(Event *event);

#endif  // NEOVIM_OS_EVENT_H

