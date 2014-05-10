int os_call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg);
void shell_free_argv(char **argv);
char ** shell_build_argv(char_u *cmd, char_u *extra_shell_arg);
