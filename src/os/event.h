#ifndef NEOVIM_OS_EVENT_H
#define NEOVIM_OS_EVENT_H

#include <stdint.h>
#include <stdbool.h>

void event_init(void);
bool event_poll(int32_t ms);

#endif  // NEOVIM_OS_EVENT_H

