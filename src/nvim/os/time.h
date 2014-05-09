#ifndef NVIM_OS_TIME_H
#define NVIM_OS_TIME_H

#include <stdint.h>
#include <stdbool.h>

void time_init(void);

void os_delay(uint64_t milliseconds, bool ignoreinput);

void os_microdelay(uint64_t microseconds, bool ignoreinput);

struct tm *os_localtime_r(const time_t *clock, struct tm *result);

struct tm *os_get_localtime(struct tm *result);

#endif  // NVIM_OS_TIME_H

