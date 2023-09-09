#ifndef NVIM_EX_GETLN_H
#define NVIM_EX_GETLN_H

#include <stdbool.h>

#include "klib/kvec.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/types.h"

struct cmdline_info;

/// Command-line colors: one chunk
///
/// Defines a region which has the same highlighting.
typedef struct {
  int start;  ///< Colored chunk start.
  int end;  ///< Colored chunk end (exclusive, > start).
  int attr;  ///< Highlight attr.
} CmdlineColorChunk;

/// Command-line colors
///
/// Holds data about all colors.
typedef kvec_t(CmdlineColorChunk) CmdlineColors;

/// Command-line coloring
///
/// Holds both what are the colors and what have been colored. Latter is used to
/// suppress unnecessary calls to coloring callbacks.
typedef struct {
  unsigned prompt_id;  ///< ID of the prompt which was colored last.
  char *cmdbuff;  ///< What exactly was colored last time or NULL.
  CmdlineColors colors;  ///< Last colors.
} ColoredCmdline;

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
  int cmdattr;                  ///< attributes for prompt
  int overstrike;               ///< Typing mode on the command line.  Shared by
                                ///< getcmdline() and put_on_cmdline().
  expand_T *xpc;                ///< struct being used for expansion, xp_pattern
                                ///< may point into cmdbuff
  int xp_context;               ///< type of expansion
  char *xp_arg;                 ///< user-defined expansion arg
  int input_fn;                 ///< when true Invoked for input() function
  unsigned prompt_id;           ///< Prompt number, used to disable coloring on errors.
  Callback highlight_callback;  ///< Callback used for coloring user input.
  ColoredCmdline last_colors;   ///< Last cmdline colors
  int level;                    ///< current cmdline level
  CmdlineInfo *prev_ccline;     ///< pointer to saved cmdline state
  char special_char;            ///< last putcmdline char (used for redraws)
  bool special_shift;           ///< shift of last putcmdline char
  CmdRedraw redraw_state;       ///< needed redraw for external cmdline
};

/// flags used by vim_strsave_fnameescape()
enum {
  VSE_NONE   = 0,
  VSE_SHELL  = 1,  ///< escape for a shell command
  VSE_BUFFER = 2,  ///< escape for a ":buffer" command
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_getln.h.generated.h"
#endif
#endif  // NVIM_EX_GETLN_H
