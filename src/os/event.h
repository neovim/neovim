#ifndef NEOVIM_OS_EVENT_H
#define NEOVIM_OS_EVENT_H

#include <stdint.h>
#include <stdbool.h>

#include "os/event_defs.h"
#include "os/job_defs.h"

void event_init(void);
bool event_poll(int32_t ms);
bool event_is_pending(void);
void event_push(Event event);
void event_process(void);

#endif  // NEOVIM_OS_EVENT_H

