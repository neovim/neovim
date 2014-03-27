#ifndef NEOVIM_OS_TIME_H
#define NEOVIM_OS_TIME_H

#include <stdint.h>
#include <stdbool.h>

void time_init(void);
void os_delay(uint64_t ms, bool ignoreinput);

#endif  // NEOVIM_OS_TIME_H
