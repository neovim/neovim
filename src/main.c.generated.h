#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int get_number_arg(char_u *p, int *idx, int def);
static void init_locale(void);
static void parse_command_name(mparm_T *parmp);
static _Bool parse_char_i(char_u **input, char val);
static _Bool parse_string(char_u **input, char *val, int len);
static void command_line_scan(mparm_T *parmp);
static void init_params(mparm_T *paramp, int argc, char **argv);
static void init_startuptime(mparm_T *paramp);
static void allocate_generic_buffers(void);
static void check_and_set_isatty(mparm_T *paramp);
static char_u *get_fname(mparm_T *parmp);
static void set_window_layout(mparm_T *paramp);
static void load_plugins(void);
static void handle_quickfix(mparm_T *paramp);
static void handle_tag(char_u *tagname);
static void check_tty(mparm_T *parmp);
static void read_stdin(void);
static void create_windows(mparm_T *parmp);
static void edit_buffers(mparm_T *parmp);
static void exe_pre_commands(mparm_T *parmp);
static void exe_commands(mparm_T *parmp);
static void source_startup_scripts(mparm_T *parmp);
static void main_start_gui(void);
static int file_owned(char *fname);
static void mainerr(int n, char_u *str);
static void main_msg(char *s);
static void usage(void);
static void check_swap_exists_action(void);
static void time_diff(struct timeval *then, struct timeval *now);
#include "func_attr.h"
