#pragma once

#include <stdbool.h>

#include "nvim/types_defs.h"

// Maximum number of commands from + or -c arguments.
#define MAX_ARG_CMDS 10

extern Loop main_loop;

// Struct for various parameters passed between main() and other functions.
typedef struct {
  int argc;
  char **argv;

  char *use_vimrc;                      // vimrc from -u argument
  bool clean;                           // --clean argument

  int n_commands;                       // no. of commands from + or -c
  char *commands[MAX_ARG_CMDS];         // commands from + or -c arg
  char cmds_tofree[MAX_ARG_CMDS];       // commands that need free()
  int n_pre_commands;                   // no. of commands from --cmd
  char *pre_commands[MAX_ARG_CMDS];     // commands from --cmd argument
  char *luaf;                           // Lua script filename from "-l"
  int lua_arg0;                         // Lua script args start index.

  int edit_type;                        // type of editing to do
  char *tagname;                        // tag from -t argument
  char *use_ef;                         // 'errorfile' from -q argument

  bool input_istext;                    // stdin is text, not executable (-E/-Es)

  int no_swap_file;                     // "-n" argument used
  int use_debug_break_level;
  int window_count;                     // number of windows to use
  int window_layout;                    // 0, WIN_HOR, WIN_VER or WIN_TABS

  int diff_mode;                        // start with 'diff' set

  char *listen_addr;                    // --listen {address}
  int remote;                           // --remote-[subcmd] {file1} {file2}
  char *server_addr;                    // --server {address}
  char *scriptin;                       // -s {filename}
  char *scriptout;                      // -w/-W {filename}
  bool scriptout_append;                // append (-w) instead of overwrite (-W)
  bool had_stdin_file;                  // explicit - as a file to edit
} mparm_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "main.h.generated.h"
#endif
