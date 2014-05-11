#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
void time_init();
void os_delay(uint64_t milliseconds, _Bool ignoreinput);
void os_microdelay(uint64_t microseconds, _Bool ignoreinput);
struct tm *os_localtime_r(const time_t *clock, struct tm *result);
struct tm *os_get_localtime(struct tm *result);
#include "func_attr.h"
