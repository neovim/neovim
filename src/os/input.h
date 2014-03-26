#ifndef NEOVIM_OS_INPUT_H
#define NEOVIM_OS_INPUT_H

#include <stdint.h>
#include <stdbool.h>

#include "os/event.h"
#include "types.h"

void input_init(void);
EventType input_check(void);
void input_start(void);
void input_stop(void);
uint32_t input_read(char *buf, uint32_t count);
int mch_inchar(char_u *, int, long, int);
bool mch_char_avail(void);
void mch_breakcheck(void);

#endif

