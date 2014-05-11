#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
char **shell_build_argv(char_u *cmd, char_u *extra_shell_opt);
void shell_free_argv(char **argv);
int os_call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg);
#include "func_attr.h"
