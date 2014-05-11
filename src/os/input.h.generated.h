#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
void input_init();
_Bool input_ready();
void input_start();
void input_stop();
uint32_t input_read(char *buf, uint32_t count);
int os_inchar(uint8_t *buf, int maxlen, int32_t ms, int tb_change_cnt);
_Bool os_char_avail();
void os_breakcheck();
_Bool os_isatty(int fd);
#include "func_attr.h"
