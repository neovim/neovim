#ifndef NVIM_OS_INPUT_H
#define NVIM_OS_INPUT_H

#include <stdint.h>
#include <stdbool.h>

void input_init(void);
bool input_ready(void);
void input_start(void);
void input_stop(void);
uint32_t input_read(char *buf, uint32_t count);
int os_inchar(uint8_t *, int, int32_t, int);
bool os_char_avail(void);
void os_breakcheck(void);

/// Test whether a file descriptor refers to a terminal.
///
/// @param fd File descriptor.
/// @return `true` if file descriptor refers to a terminal.
bool os_isatty(int fd);

#endif  // NVIM_OS_INPUT_H

