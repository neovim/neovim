#ifndef NEOVIM_OS_EVENT_H
#define NEOVIM_OS_EVENT_H

#include <stdint.h>
#include <stdbool.h>

#include "os/event_defs.h"
#include "os/job_defs.h"

void event_init(void);
bool event_poll(int32_t ms);
void event_push(Event event);

#endif  // NEOVIM_OS_EVENT_H

