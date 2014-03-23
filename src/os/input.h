#ifndef NEOVIM_OS_INPUT_H
#define NEOVIM_OS_INPUT_H

#include <stdbool.h>

#include "types.h"

int mch_inchar(char_u *, int, long, int);
bool mch_char_avail(void);
void mch_breakcheck(void);

#endif

