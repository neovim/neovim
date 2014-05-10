void os_breakcheck(void);
int os_inchar(uint8_t *, int, int32_t, int);
uint32_t input_read(char *buf, uint32_t count);
void input_stop(void);
void input_start(void);
void input_init(void);
bool input_ready(void);
bool os_char_avail(void);
bool os_isatty(int fd);
