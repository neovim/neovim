#ifndef NVIM_MAIN_H
#define NVIM_MAIN_H

#include "nvim/normal.h"
#include "nvim/event/loop.h"

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
  char_u cmds_tofree[MAX_ARG_CMDS];     // commands that need free()
  int n_pre_commands;                   // no. of commands from --cmd
  char *pre_commands[MAX_ARG_CMDS];     // commands from --cmd argument

  int edit_type;                        // type of editing to do
  char_u *tagname;                      // tag from -t argument
  char_u *use_ef;                       // 'errorfile' from -q argument

  bool input_isatty;                    // stdin is a terminal
  bool output_isatty;                   // stdout is a terminal
  bool err_isatty;                      // stderr is a terminal
  bool input_neverscript;               // never treat stdin as script (-E/-Es)
  int no_swap_file;                     // "-n" argument used
  int use_debug_break_level;
  int window_count;                     // number of windows to use
  int window_layout;                    // 0, WIN_HOR, WIN_VER or WIN_TABS

  int diff_mode;                        // start with 'diff' set

  char *listen_addr;                    // --listen {address}
} mparm_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "main.h.generated.h"
#endif
#endif  // NVIM_MAIN_H
