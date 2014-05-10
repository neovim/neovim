struct tm *os_get_localtime(struct tm *result);
struct tm *os_localtime_r(const time_t *clock, struct tm *result);
void time_init(void);
void os_microdelay(uint64_t microseconds, bool ignoreinput);
void os_delay(uint64_t milliseconds, bool ignoreinput);
