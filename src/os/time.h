#ifndef NEOVIM_OS_TIME_H
#define NEOVIM_OS_TIME_H

#include <stdint.h>

void time_init(void);
void mch_delay(uint64_t, int);

#endif
