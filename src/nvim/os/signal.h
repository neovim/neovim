#ifndef NVIM_OS_SIGNAL_H
#define NVIM_OS_SIGNAL_H

#include "nvim/os/event_defs.h"

void signal_init(void);
void signal_stop(void);
void signal_accept_deadly(void);
void signal_reject_deadly(void);
void signal_handle(Event event);

#endif  // NVIM_OS_SIGNAL_H

