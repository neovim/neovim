#ifndef NEOVIM_OS_IO_H
#define NEOVIM_OS_IO_H

#include <stdint.h>

typedef enum {
  POLL_NONE,
  POLL_INPUT,
  POLL_SIGNAL,
  POLL_EOF
} poll_result_t;

void io_start(void);
void io_stop(void);
poll_result_t io_poll(int32_t ms);
uint32_t io_read(char *buf, uint32_t count);
int io_consume_signal(void);

#endif

