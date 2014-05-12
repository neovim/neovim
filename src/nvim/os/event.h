#ifndef NVIM_OS_EVENT_H
#define NVIM_OS_EVENT_H

#include <stdint.h>
#include <stdbool.h>

#include "nvim/os/event_defs.h"
#include "nvim/os/job_defs.h"

void event_init(void);
void event_teardown(void);
bool event_poll(int32_t ms);
bool event_is_pending(void);
void event_push(Event event);
void event_process(void);

#endif  // NVIM_OS_EVENT_H

