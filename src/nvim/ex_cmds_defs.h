#ifndef NVIM_EX_CMDS_DEFS_H
#define NVIM_EX_CMDS_DEFS_H

#include <stdbool.h>
#include <stdint.h>

#include "nvim/pos.h"      // for linenr_T
#include "nvim/normal.h"
#include "nvim/regexp_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds_enum.generated.h"
#endif

/*
 * When adding an Ex command:
 * 1. Add an entry to the table in src/nvim/ex_cmds.lua.  Keep it sorted on the 
 *    shortest version of the command name that works.  If it doesn't start with 
 *    a lower case letter, add it at the end.
 *
 *    Each table entry is a table with the following keys:
 *
 *      Key     | Description
 *      ------- | -------------------------------------------------------------
 *      command | Name of the command. Required.
 *      enum    | Name of the enum entry. If not set defaults to CMD_{command}.
 *      flags   | A set of the flags from below list joined by bitwise or.
 *      func    | Name of the function containing the implementation.
 *
 *    Referenced function should be either non-static one or defined in 
 *    ex_docmd.c and be coercible to ex_func_T type from below.
 *
 *    All keys not described in the above table are reserved for future use.
 *
 * 2. Add a "case: CMD_xxx" in the big switch in ex_docmd.c.
 * 3. Add an entry in the index for Ex commands at ":help ex-cmd-index".
 * 4. Add documentation in ../doc/xxx.txt.  Add a tag for both the short and
 *    long name of the command.
 */

#define RANGE           0x001   /* allow a linespecs */
#define BANG            0x002   /* allow a ! after the command name */
#define EXTRA           0x004   /* allow extra args after command name */
#define XFILE           0x008   /* expand wildcards in extra part */
#define NOSPC           0x010   /* no spaces allowed in the extra part */
#define DFLALL          0x020   /* default file range is 1,$ */
#define WHOLEFOLD       0x040   /* extend range to include whole fold also
                                   when less than two numbers given */
#define NEEDARG         0x080   /* argument required */
#define TRLBAR          0x100   /* check for trailing vertical bar */
#define REGSTR          0x200   /* allow "x for register designation */
#define COUNT           0x400   /* allow count in argument, after command */
#define NOTRLCOM        0x800   /* no trailing comment allowed */
#define ZEROR          0x1000   /* zero line number allowed */
#define USECTRLV       0x2000   /* do not remove CTRL-V from argument */
#define NOTADR         0x4000   /* number before command is not an address */
#define EDITCMD        0x8000   /* allow "+command" argument */
#define BUFNAME       0x10000   /* accepts buffer name */
#define BUFUNL        0x20000   /* accepts unlisted buffer too */
#define ARGOPT        0x40000   /* allow "++opt=val" argument */
#define SBOXOK        0x80000   /* allowed in the sandbox */
#define CMDWIN       0x100000   /* allowed in cmdline window; when missing
                                 * disallows editing another buffer when
                                 * curbuf_lock is set */
#define MODIFY       0x200000   /* forbidden in non-'modifiable' buffer */
#define EXFLAGS      0x400000   /* allow flags after count in argument */
#define FILES   (XFILE | EXTRA) /* multiple extra files allowed */
#define WORD1   (EXTRA | NOSPC) /* one extra word allowed */
#define FILE1   (FILES | NOSPC) /* 1 file allowed, defaults to current file */

// values for cmd_addr_type
#define ADDR_LINES              0
#define ADDR_WINDOWS            1
#define ADDR_ARGUMENTS          2
#define ADDR_LOADED_BUFFERS     3
#define ADDR_BUFFERS            4
#define ADDR_TABS               5
#define ADDR_TABS_RELATIVE      6   // Tab page that only relative
#define ADDR_QUICKFIX           7
#define ADDR_OTHER              99

typedef struct exarg exarg_T;

/* behavior for bad character, "++bad=" argument */
#define BAD_REPLACE     '?'     /* replace it with '?' (default) */
#define BAD_KEEP        -1      /* leave it */
#define BAD_DROP        -2      /* erase it */

typedef void (*ex_func_T)(exarg_T *eap);

typedef char_u *(*LineGetter)(int, void *, int);

/// Structure for command definition.
typedef struct cmdname {
  char_u *cmd_name;    ///< Name of the command.
  ex_func_T cmd_func;  ///< Function with implementation of this command.
  uint32_t cmd_argt;     ///< Relevant flags from the declared above.
  int cmd_addr_type;     ///< Flag for address type
} CommandDefinition;

/// Arguments used for Ex commands.
struct exarg {
  char_u      *arg;             ///< argument of the command
  char_u      *nextcmd;         ///< next command (NULL if none)
  char_u      *cmd;             ///< the name of the command (except for :make)
  char_u      **cmdlinep;       ///< pointer to pointer of allocated cmdline
  cmdidx_T cmdidx;              ///< the index for the command
  uint32_t argt;                ///< flags for the command
  int skip;                     ///< don't execute the command, only parse it
  int forceit;                  ///< TRUE if ! present
  int addr_count;               ///< the number of addresses given
  linenr_T line1;               ///< the first line number
  linenr_T line2;               ///< the second line number or count
  int addr_type;                ///< type of the count/range
  int flags;                    ///< extra flags after count: EXFLAG_
  char_u      *do_ecmd_cmd;     ///< +command arg to be used in edited file
  linenr_T do_ecmd_lnum;        ///< the line number in an edited file
  int append;                   ///< TRUE with ":w >>file" command
  int usefilter;                ///< TRUE with ":w !command" and ":r!command"
  int amount;                   ///< number of '>' or '<' for shift command
  int regname;                  ///< register name (NUL if none)
  int force_bin;                ///< 0, FORCE_BIN or FORCE_NOBIN
  int read_edit;                ///< ++edit argument
  int force_ff;                 ///< ++ff= argument (index in cmd[])
  int force_enc;                ///< ++enc= argument (index in cmd[])
  int bad_char;                 ///< BAD_KEEP, BAD_DROP or replacement byte
  int useridx;                  ///< user command index
  char_u *errmsg;               ///< returned error message
  LineGetter getline;           ///< Function used to get the next line
  void   *cookie;               ///< argument for getline()
  struct condstack *cstack;     ///< condition stack for ":if" etc.
};

#define FORCE_BIN 1             // ":edit ++bin file"
#define FORCE_NOBIN 2           // ":edit ++nobin file"

// Values for "flags"
#define EXFLAG_LIST     0x01    // 'l': list
#define EXFLAG_NR       0x02    // '#': number
#define EXFLAG_PRINT    0x04    // 'p': print

// used for completion on the command line
struct expand {
  int xp_context;               // type of expansion
  char_u *xp_pattern;           // start of item to expand
  size_t xp_pattern_len;        // bytes in xp_pattern before cursor
  char_u *xp_arg;               // completion function
  sctx_T xp_script_ctx;         // SCTX for completion function
  int xp_backslash;             // one of the XP_BS_ values
#ifndef BACKSLASH_IN_FILENAME
  int xp_shell;                 // TRUE for a shell command, more
                                // characters need to be escaped
#endif
  int xp_numfiles;              // number of files found by file name completion
  char_u **xp_files;            // list of files
  char_u *xp_line;              // text being completed
  int xp_col;                   // cursor position in line
};

// values for xp_backslash
#define XP_BS_NONE      0       // nothing special for backslashes
#define XP_BS_ONE       1       // uses one backslash before a space
#define XP_BS_THREE     2       // uses three backslashes before a space

/// Command modifiers ":vertical", ":browse", ":confirm", ":hide", etc. set a
/// flag.  This needs to be saved for recursive commands, put them in a
/// structure for easy manipulation.
typedef struct {
  int split;                   ///< flags for win_split()
  int tab;                     ///< > 0 when ":tab" was used
  bool browse;                 ///< true to invoke file dialog
  bool confirm;                ///< true to invoke yes/no dialog
  bool hide;                   ///< true when ":hide" was used
  bool keepalt;                ///< true when ":keepalt" was used
  bool keepjumps;              ///< true when ":keepjumps" was used
  bool keepmarks;              ///< true when ":keepmarks" was used
  bool keeppatterns;           ///< true when ":keeppatterns" was used
  bool lockmarks;              ///< true when ":lockmarks" was used
  bool noswapfile;             ///< true when ":noswapfile" was used
  char_u *save_ei;             ///< saved value of 'eventignore'
  regmatch_T filter_regmatch;  ///< set by :filter /pat/
  bool filter_force;           ///< set for :filter!
} cmdmod_T;

#endif  // NVIM_EX_CMDS_DEFS_H
