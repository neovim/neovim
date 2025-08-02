#pragma once

#include <stdbool.h>

#include "klib/kvec.h"
#include "nvim/cmdexpand_defs.h"

/// Keeps track how much state must be sent to external ui.
typedef enum {
  kCmdRedrawNone,
  kCmdRedrawPos,
  kCmdRedrawAll,
} CmdRedraw;

/// Variables shared between getcmdline(), redrawcmdline() and others.
/// These need to be saved when using CTRL-R |, that's why they are in a
/// structure.
typedef struct cmdline_info CmdlineInfo;
struct cmdline_info {
  char *cmdbuff;                ///< pointer to command line buffer
  int cmdbufflen;               ///< length of cmdbuff
  int cmdlen;                   ///< number of chars in command line
  int cmdpos;                   ///< current cursor position
  int cmdspos;                  ///< cursor column on screen
  int cmdfirstc;                ///< ':', '/', '?', '=', '>' or NUL
  int cmdindent;                ///< number of spaces before cmdline
  char *cmdprompt;              ///< message in front of cmdline
  int hl_id;                    ///< highlight id for prompt
  int overstrike;               ///< Typing mode on the command line.  Shared by
                                ///< getcmdline() and put_on_cmdline().
  expand_T *xpc;                ///< struct being used for expansion, xp_pattern
                                ///< may point into cmdbuff
  int xp_context;               ///< type of expansion
  char *xp_arg;                 ///< user-defined expansion arg
  int input_fn;                 ///< when true Invoked for input() function
  unsigned prompt_id;           ///< Prompt number, used to disable coloring on errors.
  int level;                    ///< current cmdline level
  CmdlineInfo *prev_ccline;     ///< pointer to saved cmdline state
  char special_char;            ///< last putcmdline char (used for redraws)
  bool special_shift;           ///< shift of last putcmdline char
  CmdRedraw redraw_state;       ///< needed redraw for external cmdline
  bool one_key;                 ///< return after one key press for button prompt
  bool *mouse_used;             ///< mouse clicked in prompt
};
