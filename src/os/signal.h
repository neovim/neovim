#ifndef NEOVIM_OS_SIGNAL_H
#define NEOVIM_OS_SIGNAL_H

#include "os/event.h"

void signal_init(void);
void signal_stop(void);
void signal_accept_deadly(void);
void signal_reject_deadly(void);
void signal_handle(Event *event);

#endif

