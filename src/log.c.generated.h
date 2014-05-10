static FILE *open_log_file(void);
static bool do_log_to_file(FILE *log_file, int log_level,
                           const char *func_name, int line_num,
                           const char* fmt, ...);
static bool v_do_log_to_file(FILE *log_file, int log_level,
                             const char *func_name, int line_num,
                             const char* fmt, va_list args);
