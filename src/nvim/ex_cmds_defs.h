#ifndef NVIM_EX_CMDS_DEFS_H
#define NVIM_EX_CMDS_DEFS_H

#include <stdbool.h>
#include <stdint.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/normal.h"
#include "nvim/pos.h"
#include "nvim/regexp_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds_enum.generated.h"
#endif

// When adding an Ex command:
// 1. Add an entry to the table in src/nvim/ex_cmds.lua.  Keep it sorted on the
//    shortest version of the command name that works.  If it doesn't start with
//    a lower case letter, add it at the end.
//
//    Each table entry is a table with the following keys:
//
//      Key     | Description
//      ------- | -------------------------------------------------------------
//      command | Name of the command. Required.
//      enum    | Name of the enum entry. If not set defaults to CMD_{command}.
//      flags   | A set of the flags from below list joined by bitwise or.
//      func    | Name of the function containing the implementation.
//
//    Referenced function should be either non-static one or defined in
//    ex_docmd.c and be coercible to ex_func_T type from below.
//
//    All keys not described in the above table are reserved for future use.
//
// 2. Add a "case: CMD_xxx" in the big switch in ex_docmd.c.
// 3. Add an entry in the index for Ex commands at ":help ex-cmd-index".
// 4. Add documentation in ../doc/xxx.txt.  Add a tag for both the short and
//    long name of the command.

#define EX_RANGE           0x001u  // allow a linespecs
#define EX_BANG            0x002u  // allow a ! after the command name
#define EX_EXTRA           0x004u  // allow extra args after command name
#define EX_XFILE           0x008u  // expand wildcards in extra part
#define EX_NOSPC           0x010u  // no spaces allowed in the extra part
#define EX_DFLALL          0x020u  // default file range is 1,$
#define EX_WHOLEFOLD       0x040u  // extend range to include whole fold also
                                   // when less than two numbers given
#define EX_NEEDARG         0x080u  // argument required
#define EX_TRLBAR          0x100u  // check for trailing vertical bar
#define EX_REGSTR          0x200u  // allow "x for register designation
#define EX_COUNT           0x400u  // allow count in argument, after command
#define EX_NOTRLCOM        0x800u  // no trailing comment allowed
#define EX_ZEROR          0x1000u  // zero line number allowed
#define EX_CTRLV          0x2000u  // do not remove CTRL-V from argument
#define EX_CMDARG         0x4000u  // allow "+command" argument
#define EX_BUFNAME        0x8000u  // accepts buffer name
#define EX_BUFUNL        0x10000u  // accepts unlisted buffer too
#define EX_ARGOPT        0x20000u  // allow "++opt=val" argument
#define EX_SBOXOK        0x40000u  // allowed in the sandbox
#define EX_CMDWIN        0x80000u  // allowed in cmdline window
#define EX_MODIFY       0x100000u  // forbidden in non-'modifiable' buffer
#define EX_FLAGS        0x200000u  // allow flags after count in argument
#define EX_LOCK_OK     0x1000000u  // command can be executed when textlock is
                                   // set; when missing disallows editing another
                                   // buffer when curbuf->b_ro_locked is set
#define EX_KEEPSCRIPT  0x4000000u  // keep sctx of where command was invoked
#define EX_PREVIEW     0x8000000u  // allow incremental command preview
#define EX_FILES (EX_XFILE | EX_EXTRA)  // multiple extra files allowed
#define EX_FILE1 (EX_FILES | EX_NOSPC)  // 1 file, defaults to current file
#define EX_WORD1 (EX_EXTRA | EX_NOSPC)  // one extra word allowed

// values for cmd_addr_type
typedef enum {
  ADDR_LINES,           // buffer line numbers
  ADDR_WINDOWS,         // window number
  ADDR_ARGUMENTS,       // argument number
  ADDR_LOADED_BUFFERS,  // buffer number of loaded buffer
  ADDR_BUFFERS,         // buffer number
  ADDR_TABS,            // tab page number
  ADDR_TABS_RELATIVE,   // Tab page that only relative
  ADDR_QUICKFIX_VALID,  // quickfix list valid entry number
  ADDR_QUICKFIX,        // quickfix list entry number
  ADDR_UNSIGNED,        // positive count or zero, defaults to 1
  ADDR_OTHER,           // something else, use line number for '$', '%', etc.
  ADDR_NONE,  // no range used
} cmd_addr_T;

typedef struct exarg exarg_T;

// behavior for bad character, "++bad=" argument
#define BAD_REPLACE     '?'     // replace it with '?' (default)
#define BAD_KEEP        (-1)    // leave it
#define BAD_DROP        (-2)    // erase it

typedef void (*ex_func_T)(exarg_T *eap);
typedef int (*ex_preview_func_T)(exarg_T *eap, long cmdpreview_ns, handle_T cmdpreview_bufnr);

// NOTE: These possible could be removed and changed so that
// Callback could take a "command" style string, and simply
// execute that (instead of it being a function).
//
// But it's still a bit weird to do that.
//
// Another option would be that we just make a callback reference to
// "execute($INPUT)" or something like that, so whatever the user
// sends in via autocmds is just executed via this.
//
// However, that would probably have some performance cost (probably
// very marginal, but still some cost either way).
typedef enum {
  CALLABLE_NONE,
  CALLABLE_EX,
  CALLABLE_CB,
} AucmdExecutableType;

typedef struct aucmd_executable_t AucmdExecutable;
struct aucmd_executable_t {
  AucmdExecutableType type;
  union {
    char *cmd;
    Callback cb;
  } callable;
};

#define AUCMD_EXECUTABLE_INIT { .type = CALLABLE_NONE }

typedef char *(*LineGetter)(int, void *, int, bool);

/// Structure for command definition.
typedef struct cmdname {
  char *cmd_name;                         ///< Name of the command.
  ex_func_T cmd_func;                     ///< Function with implementation of this command.
  ex_preview_func_T cmd_preview_func;     ///< Preview callback function of this command.
  uint32_t cmd_argt;                      ///< Relevant flags from the declared above.
  cmd_addr_T cmd_addr_type;               ///< Flag for address type.
} CommandDefinition;

// A list used for saving values of "emsg_silent".  Used by ex_try() to save the
// value of "emsg_silent" if it was non-zero.  When this is done, the CSF_SILENT
// flag below is set.
typedef struct eslist_elem eslist_T;
struct eslist_elem {
  int saved_emsg_silent;  // saved value of "emsg_silent"
  eslist_T *next;         // next element on the list
};

// For conditional commands a stack is kept of nested conditionals.
// When cs_idx < 0, there is no conditional command.
enum {
  CSTACK_LEN = 50,
};

typedef struct {
  int cs_flags[CSTACK_LEN];         // CSF_ flags
  char cs_pending[CSTACK_LEN];      // CSTP_: what's pending in ":finally"
  union {
    void *csp_rv[CSTACK_LEN];       // return typeval for pending return
    void *csp_ex[CSTACK_LEN];       // exception for pending throw
  } cs_pend;
  void *cs_forinfo[CSTACK_LEN];     // info used by ":for"
  int cs_line[CSTACK_LEN];          // line nr of ":while"/":for" line
  int cs_idx;                       // current entry, or -1 if none
  int cs_looplevel;                 // nr of nested ":while"s and ":for"s
  int cs_trylevel;                  // nr of nested ":try"s
  eslist_T *cs_emsg_silent_list;    // saved values of "emsg_silent"
  int cs_lflags;                    // loop flags: CSL_ flags
} cstack_T;
#define cs_rettv       cs_pend.csp_rv
#define cs_exception   cs_pend.csp_ex

// Flags for the cs_lflags item in cstack_T.
enum {
  CSL_HAD_LOOP = 1,  // just found ":while" or ":for"
  CSL_HAD_ENDLOOP = 2,  // just found ":endwhile" or ":endfor"
  CSL_HAD_CONT = 4,  // just found ":continue"
  CSL_HAD_FINA = 8,  // just found ":finally"
};

/// Arguments used for Ex commands.
struct exarg {
  char *arg;                    ///< argument of the command
  char **args;                  ///< starting position of command arguments
  size_t *arglens;              ///< length of command arguments
  size_t argc;                  ///< number of command arguments
  char *nextcmd;                ///< next command (NULL if none)
  char *cmd;                    ///< the name of the command (except for :make)
  char **cmdlinep;              ///< pointer to pointer of allocated cmdline
  char *cmdline_tofree;         ///< free later
  cmdidx_T cmdidx;              ///< the index for the command
  uint32_t argt;                ///< flags for the command
  int skip;                     ///< don't execute the command, only parse it
  int forceit;                  ///< true if ! present
  int addr_count;               ///< the number of addresses given
  linenr_T line1;               ///< the first line number
  linenr_T line2;               ///< the second line number or count
  cmd_addr_T addr_type;         ///< type of the count/range
  int flags;                    ///< extra flags after count: EXFLAG_
  char *do_ecmd_cmd;            ///< +command arg to be used in edited file
  linenr_T do_ecmd_lnum;        ///< the line number in an edited file
  int append;                   ///< true with ":w >>file" command
  int usefilter;                ///< true with ":w !command" and ":r!command"
  int amount;                   ///< number of '>' or '<' for shift command
  int regname;                  ///< register name (NUL if none)
  int force_bin;                ///< 0, FORCE_BIN or FORCE_NOBIN
  int read_edit;                ///< ++edit argument
  int mkdir_p;                  ///< ++p argument
  int force_ff;                 ///< ++ff= argument (first char of argument)
  int force_enc;                ///< ++enc= argument (index in cmd[])
  int bad_char;                 ///< BAD_KEEP, BAD_DROP or replacement byte
  int useridx;                  ///< user command index
  char *errmsg;                 ///< returned error message
  LineGetter getline;           ///< Function used to get the next line
  void *cookie;                 ///< argument for getline()
  cstack_T *cstack;             ///< condition stack for ":if" etc.
};

#define FORCE_BIN 1             // ":edit ++bin file"
#define FORCE_NOBIN 2           // ":edit ++nobin file"

// Values for "flags"
#define EXFLAG_LIST     0x01    // 'l': list
#define EXFLAG_NR       0x02    // '#': number
#define EXFLAG_PRINT    0x04    // 'p': print

typedef enum {
  XP_PREFIX_NONE,  ///< prefix not used
  XP_PREFIX_NO,    ///< "no" prefix for bool option
  XP_PREFIX_INV,   ///< "inv" prefix for bool option
} xp_prefix_T;

// used for completion on the command line
struct expand {
  char *xp_pattern;             // start of item to expand
  int xp_context;               // type of expansion
  size_t xp_pattern_len;        // bytes in xp_pattern before cursor
  xp_prefix_T xp_prefix;
  char *xp_arg;                 // completion function
  LuaRef xp_luaref;             // Ref to Lua completion function
  sctx_T xp_script_ctx;         // SCTX for completion function
  int xp_backslash;             // one of the XP_BS_ values
#ifndef BACKSLASH_IN_FILENAME
  int xp_shell;                 // true for a shell command, more
                                // characters need to be escaped
#endif
  int xp_numfiles;              // number of files found by file name completion
  int xp_col;                   // cursor position in line
  int xp_selected;              // selected index in completion
  char **xp_files;              // list of files
  char *xp_line;                // text being completed
#define EXPAND_BUF_LEN 256
  char xp_buf[EXPAND_BUF_LEN];  // buffer for returned match
};

// values for xp_backslash
#define XP_BS_NONE      0       // nothing special for backslashes
#define XP_BS_ONE       1       // uses one backslash before a space
#define XP_BS_THREE     2       // uses three backslashes before a space

enum {
  CMOD_SANDBOX      = 0x0001,  ///< ":sandbox"
  CMOD_SILENT       = 0x0002,  ///< ":silent"
  CMOD_ERRSILENT    = 0x0004,  ///< ":silent!"
  CMOD_UNSILENT     = 0x0008,  ///< ":unsilent"
  CMOD_NOAUTOCMD    = 0x0010,  ///< ":noautocmd"
  CMOD_HIDE         = 0x0020,  ///< ":hide"
  CMOD_BROWSE       = 0x0040,  ///< ":browse" - invoke file dialog
  CMOD_CONFIRM      = 0x0080,  ///< ":confirm" - invoke yes/no dialog
  CMOD_KEEPALT      = 0x0100,  ///< ":keepalt"
  CMOD_KEEPMARKS    = 0x0200,  ///< ":keepmarks"
  CMOD_KEEPJUMPS    = 0x0400,  ///< ":keepjumps"
  CMOD_LOCKMARKS    = 0x0800,  ///< ":lockmarks"
  CMOD_KEEPPATTERNS = 0x1000,  ///< ":keeppatterns"
  CMOD_NOSWAPFILE   = 0x2000,  ///< ":noswapfile"
};

/// Command modifiers ":vertical", ":browse", ":confirm", ":hide", etc. set a
/// flag.  This needs to be saved for recursive commands, put them in a
/// structure for easy manipulation.
typedef struct {
  int cmod_flags;  ///< CMOD_ flags

  int cmod_split;  ///< flags for win_split()
  int cmod_tab;  ///< > 0 when ":tab" was used
  char *cmod_filter_pat;
  regmatch_T cmod_filter_regmatch;  ///< set by :filter /pat/
  bool cmod_filter_force;  ///< set for :filter!

  int cmod_verbose;  ///< 0 if not set, > 0 to set 'verbose' to cmod_verbose - 1

  // values for undo_cmdmod()
  char *cmod_save_ei;  ///< saved value of 'eventignore'
  int cmod_did_sandbox;  ///< set when "sandbox" was incremented
  long cmod_verbose_save;  ///< if 'verbose' was set: value of p_verbose plus one
  int cmod_save_msg_silent;  ///< if non-zero: saved value of msg_silent + 1
  int cmod_save_msg_scroll;  ///< for restoring msg_scroll
  int cmod_did_esilent;  ///< incremented when emsg_silent is
} cmdmod_T;

/// Stores command modifier info used by `nvim_parse_cmd`
typedef struct {
  cmdmod_T cmdmod;
  struct {
    bool file;
    bool bar;
  } magic;
} CmdParseInfo;

#endif  // NVIM_EX_CMDS_DEFS_H
