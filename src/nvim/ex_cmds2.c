// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file ex_cmds2.c
///
/// Some more functions for command line commands

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>
#include <fcntl.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#ifdef HAVE_LOCALE_H
# include <locale.h>
#endif
#include "nvim/ex_cmds2.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/profile.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"
#include "nvim/os/fs_defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"


/// Growarray to store info about already sourced scripts.
/// Also store the dev/ino, so that we don't have to stat() each
/// script when going through the list.
typedef struct scriptitem_S {
  char_u      *sn_name;
  bool file_id_valid;
  FileID file_id;
  bool sn_prof_on;              ///< true when script is/was profiled
  bool sn_pr_force;             ///< forceit: profile functions in this script
  proftime_T sn_pr_child;       ///< time set when going into first child
  int sn_pr_nest;               ///< nesting for sn_pr_child
  // profiling the script as a whole
  int sn_pr_count;              ///< nr of times sourced
  proftime_T sn_pr_total;       ///< time spent in script + children
  proftime_T sn_pr_self;        ///< time spent in script itself
  proftime_T sn_pr_start;       ///< time at script start
  proftime_T sn_pr_children;    ///< time in children after script start
  // profiling the script per line
  garray_T sn_prl_ga;           ///< things stored for every line
  proftime_T sn_prl_start;      ///< start time for current line
  proftime_T sn_prl_children;   ///< time spent in children for this line
  proftime_T sn_prl_wait;       ///< wait start time for current line
  linenr_T sn_prl_idx;          ///< index of line being timed; -1 if none
  int sn_prl_execed;            ///< line being timed was executed
} scriptitem_T;

static garray_T script_items = { 0, 0, sizeof(scriptitem_T), 4, NULL };
#define SCRIPT_ITEM(id) (((scriptitem_T *)script_items.ga_data)[(id) - 1])

// Struct used in sn_prl_ga for every line of a script.
typedef struct sn_prl_S {
  int snp_count;                ///< nr of times line was executed
  proftime_T sn_prl_total;      ///< time spent in a line + children
  proftime_T sn_prl_self;       ///< time spent in a line itself
} sn_prl_T;

/// Structure used to store info for each sourced file.
/// It is shared between do_source() and getsourceline().
/// This is required, because it needs to be handed to do_cmdline() and
/// sourcing can be done recursively.
struct source_cookie {
  FILE *fp;                     ///< opened file for sourcing
  char_u *nextline;             ///< if not NULL: line that was read ahead
  int finished;                 ///< ":finish" used
#if defined(USE_CRNL)
  int fileformat;               ///< EOL_UNKNOWN, EOL_UNIX or EOL_DOS
  bool error;                    ///< true if LF found after CR-LF
#endif
  linenr_T breakpoint;          ///< next line with breakpoint or zero
  char_u *fname;                ///< name of sourced file
  int dbg_tick;                 ///< debug_tick when breakpoint was set
  int level;                    ///< top nesting level of sourced file
  vimconv_T conv;               ///< type of conversion
};

#  define PRL_ITEM(si, idx)     (((sn_prl_T *)(si)->sn_prl_ga.ga_data)[(idx)])

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds2.c.generated.h"
#endif

/// batch mode debugging: don't save and restore typeahead.
static bool debug_greedy = false;

/// Debug mode. Repeatedly get Ex commands, until told to continue normal
/// execution.
void do_debug(char_u *cmd)
{
  int save_msg_scroll = msg_scroll;
  int save_State = State;
  int save_did_emsg = did_emsg;
  const bool save_cmd_silent = cmd_silent;
  int save_msg_silent = msg_silent;
  int save_emsg_silent = emsg_silent;
  int save_redir_off = redir_off;
  tasave_T typeaheadbuf;
  bool typeahead_saved = false;
  int save_ignore_script = 0;
  int save_ex_normal_busy;
  int n;
  char_u      *cmdline = NULL;
  char_u      *p;
  char        *tail = NULL;
  static int last_cmd = 0;
#define CMD_CONT        1
#define CMD_NEXT        2
#define CMD_STEP        3
#define CMD_FINISH      4
#define CMD_QUIT        5
#define CMD_INTERRUPT   6
#define CMD_BACKTRACE   7
#define CMD_FRAME       8
#define CMD_UP          9
#define CMD_DOWN        10


  RedrawingDisabled++;          // don't redisplay the window
  no_wait_return++;             // don't wait for return
  did_emsg = false;             // don't use error from debugged stuff
  cmd_silent = false;           // display commands
  msg_silent = false;           // display messages
  emsg_silent = false;          // display error messages
  redir_off = true;             // don't redirect debug commands

  State = NORMAL;

  if (!debug_did_msg) {
    MSG(_("Entering Debug mode.  Type \"cont\" to continue."));
  }
  if (sourcing_name != NULL) {
    msg(sourcing_name);
  }
  if (sourcing_lnum != 0) {
    smsg(_("line %" PRId64 ": %s"), (int64_t)sourcing_lnum, cmd);
  } else {
    smsg(_("cmd: %s"), cmd);
  }

  // Repeat getting a command and executing it.
  for (;; ) {
    msg_scroll = true;
    need_wait_return = false;
    // Save the current typeahead buffer and replace it with an empty one.
    // This makes sure we get input from the user here and don't interfere
    // with the commands being executed.  Reset "ex_normal_busy" to avoid
    // the side effects of using ":normal". Save the stuff buffer and make
    // it empty. Set ignore_script to avoid reading from script input.
    save_ex_normal_busy = ex_normal_busy;
    ex_normal_busy = 0;
    if (!debug_greedy) {
      save_typeahead(&typeaheadbuf);
      typeahead_saved = true;
      save_ignore_script = ignore_script;
      ignore_script = true;
    }

    xfree(cmdline);
    cmdline = (char_u *)getcmdline_prompt('>', NULL, 0, EXPAND_NOTHING, NULL,
                                          CALLBACK_NONE);

    if (typeahead_saved) {
      restore_typeahead(&typeaheadbuf);
      ignore_script = save_ignore_script;
    }
    ex_normal_busy = save_ex_normal_busy;

    cmdline_row = msg_row;
    msg_starthere();
    if (cmdline != NULL) {
      // If this is a debug command, set "last_cmd".
      // If not, reset "last_cmd".
      // For a blank line use previous command.
      p = skipwhite(cmdline);
      if (*p != NUL) {
        switch (*p) {
        case 'c': last_cmd = CMD_CONT;
          tail = "ont";
          break;
        case 'n': last_cmd = CMD_NEXT;
          tail = "ext";
          break;
        case 's': last_cmd = CMD_STEP;
          tail = "tep";
          break;
        case 'f':
          last_cmd = 0;
          if (p[1] == 'r') {
            last_cmd = CMD_FRAME;
            tail = "rame";
          } else {
            last_cmd = CMD_FINISH;
            tail = "inish";
          }
          break;
        case 'q': last_cmd = CMD_QUIT;
          tail = "uit";
          break;
        case 'i': last_cmd = CMD_INTERRUPT;
          tail = "nterrupt";
          break;
        case 'b':
          last_cmd = CMD_BACKTRACE;
          if (p[1] == 't') {
            tail = "t";
          } else {
            tail = "acktrace";
          }
          break;
        case 'w':
          last_cmd = CMD_BACKTRACE;
          tail = "here";
          break;
        case 'u':
          last_cmd = CMD_UP;
          tail = "p";
          break;
        case 'd':
          last_cmd = CMD_DOWN;
          tail = "own";
          break;
        default: last_cmd = 0;
        }
        if (last_cmd != 0) {
          // Check that the tail matches.
          p++;
          while (*p != NUL && *p == *tail) {
            p++;
            tail++;
          }
          if (ASCII_ISALPHA(*p) && last_cmd != CMD_FRAME) {
            last_cmd = 0;
          }
        }
      }

      if (last_cmd != 0) {
        // Execute debug command: decided where to break next and return.
        switch (last_cmd) {
        case CMD_CONT:
          debug_break_level = -1;
          break;
        case CMD_NEXT:
          debug_break_level = ex_nesting_level;
          break;
        case CMD_STEP:
          debug_break_level = 9999;
          break;
        case CMD_FINISH:
          debug_break_level = ex_nesting_level - 1;
          break;
        case CMD_QUIT:
          got_int = true;
          debug_break_level = -1;
          break;
        case CMD_INTERRUPT:
          got_int = true;
          debug_break_level = 9999;
          // Do not repeat ">interrupt" cmd, continue stepping.
          last_cmd = CMD_STEP;
          break;
        case CMD_BACKTRACE:
          do_showbacktrace(cmd);
          continue;
        case CMD_FRAME:
          if (*p == NUL) {
            do_showbacktrace(cmd);
          } else {
            p = skipwhite(p);
            do_setdebugtracelevel(p);
          }
          continue;
        case CMD_UP:
          debug_backtrace_level++;
          do_checkbacktracelevel();
          continue;
        case CMD_DOWN:
          debug_backtrace_level--;
          do_checkbacktracelevel();
          continue;
        }
        // Going out reset backtrace_level
        debug_backtrace_level = 0;
        break;
      }

      // don't debug this command
      n = debug_break_level;
      debug_break_level = -1;
      (void)do_cmdline(cmdline, getexline, NULL,
                       DOCMD_VERBOSE|DOCMD_EXCRESET);
      debug_break_level = n;
    }
    lines_left = (int)(Rows - 1);
  }
  xfree(cmdline);

  RedrawingDisabled--;
  no_wait_return--;
  redraw_all_later(NOT_VALID);
  need_wait_return = false;
  msg_scroll = save_msg_scroll;
  lines_left = (int)(Rows - 1);
  State = save_State;
  did_emsg = save_did_emsg;
  cmd_silent = save_cmd_silent;
  msg_silent = save_msg_silent;
  emsg_silent = save_emsg_silent;
  redir_off = save_redir_off;

  // Only print the message again when typing a command before coming back here.
  debug_did_msg = true;
}

static int get_maxbacktrace_level(void)
{
  int maxbacktrace = 0;

  if (sourcing_name != NULL) {
    char *p = (char *)sourcing_name;
    char *q;
    while ((q = strstr(p, "..")) != NULL) {
      p = q + 2;
      maxbacktrace++;
    }
  }
  return maxbacktrace;
}

static void do_setdebugtracelevel(char_u *arg)
{
  int level = atoi((char *)arg);
  if (*arg == '+' || level < 0) {
    debug_backtrace_level += level;
  } else {
    debug_backtrace_level = level;
  }

  do_checkbacktracelevel();
}

static void do_checkbacktracelevel(void)
{
  if (debug_backtrace_level < 0) {
    debug_backtrace_level = 0;
    MSG(_("frame is zero"));
  } else {
    int max = get_maxbacktrace_level();
    if (debug_backtrace_level > max) {
      debug_backtrace_level = max;
      smsg(_("frame at highest level: %d"), max);
    }
  }
}

static void do_showbacktrace(char_u *cmd)
{
  if (sourcing_name != NULL) {
    int i = 0;
    int max = get_maxbacktrace_level();
    char *cur = (char *)sourcing_name;
    while (!got_int) {
      char *next = strstr(cur, "..");
      if (next != NULL) {
        *next = NUL;
      }
      if (i == max - debug_backtrace_level) {
        smsg("->%d %s", max - i, cur);
      } else {
        smsg("  %d %s", max - i, cur);
      }
      i++;
      if (next == NULL) {
        break;
      }
      *next = '.';
      cur = next + 2;
    }
  }
  if (sourcing_lnum != 0) {
    smsg(_("line %" PRId64 ": %s"), (int64_t)sourcing_lnum, cmd);
  } else {
    smsg(_("cmd: %s"), cmd);
  }
}


/// ":debug".
void ex_debug(exarg_T *eap)
{
  int debug_break_level_save = debug_break_level;

  debug_break_level = 9999;
  do_cmdline_cmd((char *)eap->arg);
  debug_break_level = debug_break_level_save;
}

static char_u   *debug_breakpoint_name = NULL;
static linenr_T debug_breakpoint_lnum;

/// When debugging or a breakpoint is set on a skipped command, no debug prompt
/// is shown by do_one_cmd().  This situation is indicated by debug_skipped, and
/// debug_skipped_name is then set to the source name in the breakpoint case. If
/// a skipped command decides itself that a debug prompt should be displayed, it
/// can do so by calling dbg_check_skipped().
static int debug_skipped;
static char_u   *debug_skipped_name;

/// Go to debug mode when a breakpoint was encountered or "ex_nesting_level" is
/// at or below the break level.  But only when the line is actually
/// executed.  Return true and set breakpoint_name for skipped commands that
/// decide to execute something themselves.
/// Called from do_one_cmd() before executing a command.
void dbg_check_breakpoint(exarg_T *eap)
{
  char_u      *p;

  debug_skipped = false;
  if (debug_breakpoint_name != NULL) {
    if (!eap->skip) {
      // replace K_SNR with "<SNR>"
      if (debug_breakpoint_name[0] == K_SPECIAL
          && debug_breakpoint_name[1] == KS_EXTRA
          && debug_breakpoint_name[2] == (int)KE_SNR) {
        p = (char_u *)"<SNR>";
      } else {
        p = (char_u *)"";
      }
      smsg(_("Breakpoint in \"%s%s\" line %" PRId64),
           p,
           debug_breakpoint_name + (*p == NUL ? 0 : 3),
           (int64_t)debug_breakpoint_lnum);
      debug_breakpoint_name = NULL;
      do_debug(eap->cmd);
    } else {
      debug_skipped = true;
      debug_skipped_name = debug_breakpoint_name;
      debug_breakpoint_name = NULL;
    }
  } else if (ex_nesting_level <= debug_break_level) {
    if (!eap->skip) {
      do_debug(eap->cmd);
    } else {
      debug_skipped = true;
      debug_skipped_name = NULL;
    }
  }
}

/// Go to debug mode if skipped by dbg_check_breakpoint() because eap->skip was
/// set.
///
/// @return true when the debug mode is entered this time.
bool dbg_check_skipped(exarg_T *eap)
{
  int prev_got_int;

  if (debug_skipped) {
    // Save the value of got_int and reset it.  We don't want a previous
    // interruption cause flushing the input buffer.
    prev_got_int = got_int;
    got_int = false;
    debug_breakpoint_name = debug_skipped_name;
    // eap->skip is true
    eap->skip = false;
    dbg_check_breakpoint(eap);
    eap->skip = true;
    got_int |= prev_got_int;
    return true;
  }
  return false;
}

/// The list of breakpoints: dbg_breakp.
/// This is a grow-array of structs.
struct debuggy {
  int dbg_nr;                   ///< breakpoint number
  int dbg_type;                 ///< DBG_FUNC or DBG_FILE
  char_u *dbg_name;             ///< function or file name
  regprog_T *dbg_prog;          ///< regexp program
  linenr_T dbg_lnum;            ///< line number in function or file
  int dbg_forceit;              ///< ! used
};

static garray_T dbg_breakp = { 0, 0, sizeof(struct debuggy), 4, NULL };
#define BREAKP(idx)             (((struct debuggy *)dbg_breakp.ga_data)[idx])
#define DEBUGGY(gap, idx)       (((struct debuggy *)gap->ga_data)[idx])
static int last_breakp = 0;     // nr of last defined breakpoint

// Profiling uses file and func names similar to breakpoints.
static garray_T prof_ga = { 0, 0, sizeof(struct debuggy), 4, NULL };
#define DBG_FUNC        1
#define DBG_FILE        2


/// Parse the arguments of ":profile", ":breakadd" or ":breakdel" and put them
/// in the entry just after the last one in dbg_breakp.  Note that "dbg_name"
/// is allocated.
/// Returns FAIL for failure.
///
/// @param arg
/// @param gap  either &dbg_breakp or &prof_ga
static int dbg_parsearg(char_u *arg, garray_T *gap)
{
  char_u      *p = arg;
  char_u      *q;
  struct debuggy *bp;
  bool here = false;

  ga_grow(gap, 1);

  bp = &DEBUGGY(gap, gap->ga_len);

  // Find "func" or "file".
  if (STRNCMP(p, "func", 4) == 0) {
    bp->dbg_type = DBG_FUNC;
  } else if (STRNCMP(p, "file", 4) == 0) {
    bp->dbg_type = DBG_FILE;
  } else if (gap != &prof_ga && STRNCMP(p, "here", 4) == 0) {
    if (curbuf->b_ffname == NULL) {
      EMSG(_(e_noname));
      return FAIL;
    }
    bp->dbg_type = DBG_FILE;
    here = true;
  } else {
    EMSG2(_(e_invarg2), p);
    return FAIL;
  }
  p = skipwhite(p + 4);

  // Find optional line number.
  if (here) {
    bp->dbg_lnum = curwin->w_cursor.lnum;
  } else if (gap != &prof_ga && ascii_isdigit(*p)) {
    bp->dbg_lnum = getdigits_long(&p);
    p = skipwhite(p);
  } else {
    bp->dbg_lnum = 0;
  }

  // Find the function or file name.  Don't accept a function name with ().
  if ((!here && *p == NUL)
      || (here && *p != NUL)
      || (bp->dbg_type == DBG_FUNC && strstr((char *)p, "()") != NULL)) {
    EMSG2(_(e_invarg2), arg);
    return FAIL;
  }

  if (bp->dbg_type == DBG_FUNC) {
    bp->dbg_name = vim_strsave(p);
  } else if (here) {
    bp->dbg_name = vim_strsave(curbuf->b_ffname);
  } else {
    // Expand the file name in the same way as do_source().  This means
    // doing it twice, so that $DIR/file gets expanded when $DIR is
    // "~/dir".
    q = expand_env_save(p);
    if (q == NULL) {
      return FAIL;
    }
    p = expand_env_save(q);
    xfree(q);
    if (p == NULL) {
      return FAIL;
    }
    if (*p != '*') {
      bp->dbg_name = (char_u *)fix_fname((char *)p);
      xfree(p);
    } else {
      bp->dbg_name = p;
    }
  }

  if (bp->dbg_name == NULL) {
    return FAIL;
  }
  return OK;
}

/// ":breakadd".
void ex_breakadd(exarg_T *eap)
{
  struct debuggy *bp;
  char_u      *pat;
  garray_T    *gap;

  gap = &dbg_breakp;
  if (eap->cmdidx == CMD_profile) {
    gap = &prof_ga;
  }

  if (dbg_parsearg(eap->arg, gap) == OK) {
    bp = &DEBUGGY(gap, gap->ga_len);
    bp->dbg_forceit = eap->forceit;

    pat = file_pat_to_reg_pat(bp->dbg_name, NULL, NULL, false);
    if (pat != NULL) {
      bp->dbg_prog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
      xfree(pat);
    }
    if (pat == NULL || bp->dbg_prog == NULL) {
      xfree(bp->dbg_name);
    } else {
      if (bp->dbg_lnum == 0) {           // default line number is 1
        bp->dbg_lnum = 1;
      }
      if (eap->cmdidx != CMD_profile) {
        DEBUGGY(gap, gap->ga_len).dbg_nr = ++last_breakp;
        debug_tick++;
      }
      gap->ga_len++;
    }
  }
}

/// ":debuggreedy".
void ex_debuggreedy(exarg_T *eap)
{
  if (eap->addr_count == 0 || eap->line2 != 0) {
    debug_greedy = true;
  } else {
    debug_greedy = false;
  }
}

/// ":breakdel" and ":profdel".
void ex_breakdel(exarg_T *eap)
{
  struct debuggy *bp, *bpi;
  int nr;
  int todel = -1;
  bool del_all = false;
  linenr_T best_lnum = 0;
  garray_T    *gap;

  gap = &dbg_breakp;
  if (eap->cmdidx == CMD_profdel) {
    gap = &prof_ga;
  }

  if (ascii_isdigit(*eap->arg)) {
    // ":breakdel {nr}"
    nr = atoi((char *)eap->arg);
    for (int i = 0; i < gap->ga_len; i++) {
      if (DEBUGGY(gap, i).dbg_nr == nr) {
        todel = i;
        break;
      }
    }
  } else if (*eap->arg == '*') {
    todel = 0;
    del_all = true;
  } else {
    // ":breakdel {func|file} [lnum] {name}"
    if (dbg_parsearg(eap->arg, gap) == FAIL) {
      return;
    }
    bp = &DEBUGGY(gap, gap->ga_len);
    for (int i = 0; i < gap->ga_len; i++) {
      bpi = &DEBUGGY(gap, i);
      if (bp->dbg_type == bpi->dbg_type
          && STRCMP(bp->dbg_name, bpi->dbg_name) == 0
          && (bp->dbg_lnum == bpi->dbg_lnum
              || (bp->dbg_lnum == 0
                  && (best_lnum == 0
                      || bpi->dbg_lnum < best_lnum)))) {
        todel = i;
        best_lnum = bpi->dbg_lnum;
      }
    }
    xfree(bp->dbg_name);
  }

  if (todel < 0) {
    EMSG2(_("E161: Breakpoint not found: %s"), eap->arg);
  } else {
    while (!GA_EMPTY(gap)) {
      xfree(DEBUGGY(gap, todel).dbg_name);
      vim_regfree(DEBUGGY(gap, todel).dbg_prog);
      gap->ga_len--;
      if (todel < gap->ga_len) {
        memmove(&DEBUGGY(gap, todel), &DEBUGGY(gap, todel + 1),
                (size_t)(gap->ga_len - todel) * sizeof(struct debuggy));
      }
      if (eap->cmdidx == CMD_breakdel) {
        debug_tick++;
      }
      if (!del_all) {
        break;
      }
    }

    // If all breakpoints were removed clear the array.
    if (GA_EMPTY(gap)) {
      ga_clear(gap);
    }
  }
}

/// ":breaklist".
void ex_breaklist(exarg_T *eap)
{
  struct debuggy *bp;

  if (GA_EMPTY(&dbg_breakp)) {
    MSG(_("No breakpoints defined"));
  } else {
    for (int i = 0; i < dbg_breakp.ga_len; i++) {
      bp = &BREAKP(i);
      if (bp->dbg_type == DBG_FILE) {
        home_replace(NULL, bp->dbg_name, NameBuff, MAXPATHL, true);
      }
      smsg(_("%3d  %s %s  line %" PRId64),
           bp->dbg_nr,
           bp->dbg_type == DBG_FUNC ? "func" : "file",
           bp->dbg_type == DBG_FUNC ? bp->dbg_name : NameBuff,
           (int64_t)bp->dbg_lnum);
    }
  }
}

/// Find a breakpoint for a function or sourced file.
/// Returns line number at which to break; zero when no matching breakpoint.
linenr_T
dbg_find_breakpoint(
    bool file,             // true for a file, false for a function
    char_u *fname,         // file or function name
    linenr_T after         // after this line number
)
{
  return debuggy_find(file, fname, after, &dbg_breakp, NULL);
}

/// @param file     true for a file, false for a function
/// @param fname    file or function name
/// @param fp[out]  forceit
///
/// @returns true if profiling is on for a function or sourced file.
bool has_profiling(bool file, char_u *fname, bool *fp)
{
  return debuggy_find(file, fname, (linenr_T)0, &prof_ga, fp)
         != (linenr_T)0;
}

/// Common code for dbg_find_breakpoint() and has_profiling().
static linenr_T
debuggy_find(
    bool file,            // true for a file, false for a function
    char_u *fname,        // file or function name
    linenr_T after,       // after this line number
    garray_T *gap,        // either &dbg_breakp or &prof_ga
    bool *fp              // if not NULL: return forceit
)
{
  struct debuggy *bp;
  linenr_T lnum = 0;
  char_u      *name = fname;
  int prev_got_int;

  // Return quickly when there are no breakpoints.
  if (GA_EMPTY(gap)) {
    return (linenr_T)0;
  }

  // Replace K_SNR in function name with "<SNR>".
  if (!file && fname[0] == K_SPECIAL) {
    name = xmalloc(STRLEN(fname) + 3);
    STRCPY(name, "<SNR>");
    STRCPY(name + 5, fname + 3);
  }

  for (int i = 0; i < gap->ga_len; i++) {
    // Skip entries that are not useful or are for a line that is beyond
    // an already found breakpoint.
    bp = &DEBUGGY(gap, i);
    if ((bp->dbg_type == DBG_FILE) == file
        && (gap == &prof_ga
            || (bp->dbg_lnum > after && (lnum == 0 || bp->dbg_lnum < lnum)))) {
      // Save the value of got_int and reset it.  We don't want a
      // previous interruption cancel matching, only hitting CTRL-C
      // while matching should abort it.
      prev_got_int = got_int;
      got_int = false;
      if (vim_regexec_prog(&bp->dbg_prog, false, name, (colnr_T)0)) {
        lnum = bp->dbg_lnum;
        if (fp != NULL) {
          *fp = bp->dbg_forceit;
        }
      }
      got_int |= prev_got_int;
    }
  }
  if (name != fname) {
    xfree(name);
  }

  return lnum;
}

/// Called when a breakpoint was encountered.
void dbg_breakpoint(char_u *name, linenr_T lnum)
{
  // We need to check if this line is actually executed in do_one_cmd()
  debug_breakpoint_name = name;
  debug_breakpoint_lnum = lnum;
}

static char_u   *profile_fname = NULL;

/// ":profile cmd args"
void ex_profile(exarg_T *eap)
{
  static proftime_T pause_time;

  char_u      *e;
  int len;

  e = skiptowhite(eap->arg);
  len = (int)(e - eap->arg);
  e = skipwhite(e);

  if (len == 5 && STRNCMP(eap->arg, "start", 5) == 0 && *e != NUL) {
    xfree(profile_fname);
    profile_fname = expand_env_save_opt(e, true);
    do_profiling = PROF_YES;
    profile_set_wait(profile_zero());
    set_vim_var_nr(VV_PROFILING, 1L);
  } else if (do_profiling == PROF_NONE) {
    EMSG(_("E750: First use \":profile start {fname}\""));
  } else if (STRCMP(eap->arg, "stop") == 0) {
    profile_dump();
    do_profiling = PROF_NONE;
    set_vim_var_nr(VV_PROFILING, 0L);
    profile_reset();
  } else if (STRCMP(eap->arg, "pause") == 0) {
    if (do_profiling == PROF_YES) {
      pause_time = profile_start();
    }
    do_profiling = PROF_PAUSED;
  } else if (STRCMP(eap->arg, "continue") == 0) {
    if (do_profiling == PROF_PAUSED) {
      pause_time = profile_end(pause_time);
      profile_set_wait(profile_add(profile_get_wait(), pause_time));
    }
    do_profiling = PROF_YES;
  } else if (STRCMP(eap->arg, "dump") == 0) {
    profile_dump();
  } else {
    // The rest is similar to ":breakadd".
    ex_breakadd(eap);
  }
}

void ex_python(exarg_T *eap)
{
  script_host_execute("python", eap);
}

void ex_pyfile(exarg_T *eap)
{
  script_host_execute_file("python", eap);
}

void ex_pydo(exarg_T *eap)
{
  script_host_do_range("python", eap);
}

void ex_ruby(exarg_T *eap)
{
  script_host_execute("ruby", eap);
}

void ex_rubyfile(exarg_T *eap)
{
  script_host_execute_file("ruby", eap);
}

void ex_rubydo(exarg_T *eap)
{
  script_host_do_range("ruby", eap);
}

void ex_python3(exarg_T *eap)
{
  script_host_execute("python3", eap);
}

void ex_py3file(exarg_T *eap)
{
  script_host_execute_file("python3", eap);
}

void ex_pydo3(exarg_T *eap)
{
  script_host_do_range("python3", eap);
}

// Command line expansion for :profile.
static enum {
  PEXP_SUBCMD,          ///< expand :profile sub-commands
  PEXP_FUNC             ///< expand :profile func {funcname}
} pexpand_what;

static char *pexpand_cmds[] = {
  "continue",
  "dump",
  "file",
  "func",
  "pause",
  "start",
  "stop",
  NULL
};

/// Function given to ExpandGeneric() to obtain the profile command
/// specific expansion.
char_u *get_profile_name(expand_T *xp, int idx)
{
  switch (pexpand_what) {
  case PEXP_SUBCMD:
    return (char_u *)pexpand_cmds[idx];
  // case PEXP_FUNC: TODO
  default:
    return NULL;
  }
}

/// Handle command line completion for :profile command.
void set_context_in_profile_cmd(expand_T *xp, const char *arg)
{
  // Default: expand subcommands.
  xp->xp_context = EXPAND_PROFILE;
  pexpand_what = PEXP_SUBCMD;
  xp->xp_pattern = (char_u *)arg;

  char_u *const end_subcmd = skiptowhite((const char_u *)arg);
  if (*end_subcmd == NUL) {
    return;
  }

  if ((const char *)end_subcmd - arg == 5 && strncmp(arg, "start", 5) == 0) {
    xp->xp_context = EXPAND_FILES;
    xp->xp_pattern = skipwhite((const char_u *)end_subcmd);
    return;
  }

  // TODO(tarruda): expand function names after "func"
  xp->xp_context = EXPAND_NOTHING;
}

/// Dump the profiling info.
void profile_dump(void)
{
  FILE        *fd;

  if (profile_fname != NULL) {
    fd = mch_fopen((char *)profile_fname, "w");
    if (fd == NULL) {
      EMSG2(_(e_notopen), profile_fname);
    } else {
      script_dump_profile(fd);
      func_dump_profile(fd);
      fclose(fd);
    }
  }
}

/// Reset all profiling information.
static void profile_reset(void)
{
  // Reset sourced files.
  for (int id = 1; id <= script_items.ga_len; id++) {
    scriptitem_T *si = &SCRIPT_ITEM(id);
    if (si->sn_prof_on) {
      si->sn_prof_on      = false;
      si->sn_pr_force     = false;
      si->sn_pr_child     = profile_zero();
      si->sn_pr_nest      = 0;
      si->sn_pr_count     = 0;
      si->sn_pr_total     = profile_zero();
      si->sn_pr_self      = profile_zero();
      si->sn_pr_start     = profile_zero();
      si->sn_pr_children  = profile_zero();
      ga_clear(&si->sn_prl_ga);
      si->sn_prl_start    = profile_zero();
      si->sn_prl_children = profile_zero();
      si->sn_prl_wait     = profile_zero();
      si->sn_prl_idx      = -1;
      si->sn_prl_execed   = 0;
    }
  }

  // Reset functions.
  size_t      n  = func_hashtab.ht_used;
  hashitem_T *hi = func_hashtab.ht_array;

  for (; n > (size_t)0; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      n--;
      ufunc_T *uf = HI2UF(hi);
      if (uf->uf_profiling) {
        uf->uf_profiling    = 0;
        uf->uf_tm_count     = 0;
        uf->uf_tm_total     = profile_zero();
        uf->uf_tm_self      = profile_zero();
        uf->uf_tm_children  = profile_zero();

        xfree(uf->uf_tml_count);
        xfree(uf->uf_tml_total);
        xfree(uf->uf_tml_self);
        uf->uf_tml_count    = NULL;
        uf->uf_tml_total    = NULL;
        uf->uf_tml_self     = NULL;

        uf->uf_tml_start    = profile_zero();
        uf->uf_tml_children = profile_zero();
        uf->uf_tml_wait     = profile_zero();
        uf->uf_tml_idx      = -1;
        uf->uf_tml_execed   = 0;
      }
    }
  }

  xfree(profile_fname);
  profile_fname = NULL;
}

/// Start profiling a script.
static void profile_init(scriptitem_T *si)
{
  si->sn_pr_count = 0;
  si->sn_pr_total = profile_zero();
  si->sn_pr_self = profile_zero();

  ga_init(&si->sn_prl_ga, sizeof(sn_prl_T), 100);
  si->sn_prl_idx = -1;
  si->sn_prof_on = true;
  si->sn_pr_nest = 0;
}

/// Save time when starting to invoke another script or function.
void script_prof_save(
    proftime_T  *tm             // place to store wait time
)
{
  scriptitem_T    *si;

  if (current_SID > 0 && current_SID <= script_items.ga_len) {
    si = &SCRIPT_ITEM(current_SID);
    if (si->sn_prof_on && si->sn_pr_nest++ == 0) {
      si->sn_pr_child = profile_start();
    }
  }
  *tm = profile_get_wait();
}

/// Count time spent in children after invoking another script or function.
void script_prof_restore(proftime_T *tm)
{
  scriptitem_T    *si;

  if (current_SID > 0 && current_SID <= script_items.ga_len) {
    si = &SCRIPT_ITEM(current_SID);
    if (si->sn_prof_on && --si->sn_pr_nest == 0) {
      si->sn_pr_child = profile_end(si->sn_pr_child);
      // don't count wait time
      si->sn_pr_child = profile_sub_wait(*tm, si->sn_pr_child);
      si->sn_pr_children = profile_add(si->sn_pr_children, si->sn_pr_child);
      si->sn_prl_children = profile_add(si->sn_prl_children, si->sn_pr_child);
    }
  }
}

static proftime_T inchar_time;

/// Called when starting to wait for the user to type a character.
void prof_inchar_enter(void)
{
  inchar_time = profile_start();
}

/// Called when finished waiting for the user to type a character.
void prof_inchar_exit(void)
{
  inchar_time = profile_end(inchar_time);
  profile_set_wait(profile_add(profile_get_wait(), inchar_time));
}

/// Dump the profiling results for all scripts in file "fd".
static void script_dump_profile(FILE *fd)
{
  scriptitem_T    *si;
  FILE            *sfd;
  sn_prl_T        *pp;

  for (int id = 1; id <= script_items.ga_len; id++) {
    si = &SCRIPT_ITEM(id);
    if (si->sn_prof_on) {
      fprintf(fd, "SCRIPT  %s\n", si->sn_name);
      if (si->sn_pr_count == 1) {
        fprintf(fd, "Sourced 1 time\n");
      } else {
        fprintf(fd, "Sourced %d times\n", si->sn_pr_count);
      }
      fprintf(fd, "Total time: %s\n", profile_msg(si->sn_pr_total));
      fprintf(fd, " Self time: %s\n", profile_msg(si->sn_pr_self));
      fprintf(fd, "\n");
      fprintf(fd, "count  total (s)   self (s)\n");

      sfd = mch_fopen((char *)si->sn_name, "r");
      if (sfd == NULL) {
        fprintf(fd, "Cannot open file!\n");
      } else {
        // Keep going till the end of file, so that trailing
        // continuation lines are listed.
        for (int i = 0; ; i++) {
          if (vim_fgets(IObuff, IOSIZE, sfd)) {
            break;
          }
          if (i < si->sn_prl_ga.ga_len
              && (pp = &PRL_ITEM(si, i))->snp_count > 0) {
            fprintf(fd, "%5d ", pp->snp_count);
            if (profile_equal(pp->sn_prl_total, pp->sn_prl_self)) {
              fprintf(fd, "           ");
            } else {
              fprintf(fd, "%s ", profile_msg(pp->sn_prl_total));
            }
            fprintf(fd, "%s ", profile_msg(pp->sn_prl_self));
          } else {
            fprintf(fd, "                            ");
          }
          fprintf(fd, "%s", IObuff);
        }
        fclose(sfd);
      }
      fprintf(fd, "\n");
    }
  }
}

/// Return true when a function defined in the current script should be
/// profiled.
bool prof_def_func(void)
{
  if (current_SID > 0) {
    return SCRIPT_ITEM(current_SID).sn_pr_force;
  }
  return false;
}

/// If 'autowrite' option set, try to write the file.
/// Careful: autocommands may make "buf" invalid!
///
/// @return FAIL for failure, OK otherwise
int autowrite(buf_T *buf, int forceit)
{
  int r;
  bufref_T bufref;

  if (!(p_aw || p_awa) || !p_write
      // never autowrite a "nofile" or "nowrite" buffer
      || bt_dontwrite(buf)
      || (!forceit && buf->b_p_ro) || buf->b_ffname == NULL) {
    return FAIL;
  }
  set_bufref(&bufref, buf);
  r = buf_write_all(buf, forceit);

  // Writing may succeed but the buffer still changed, e.g., when there is a
  // conversion error.  We do want to return FAIL then.
  if (bufref_valid(&bufref) && bufIsChanged(buf)) {
    r = FAIL;
  }
  return r;
}

/// Flush all buffers, except the ones that are readonly or are never written.
void autowrite_all(void)
{
  if (!(p_aw || p_awa) || !p_write) {
    return;
  }

  FOR_ALL_BUFFERS(buf) {
    if (bufIsChanged(buf) && !buf->b_p_ro && !bt_dontwrite(buf)) {
      bufref_T bufref;
      set_bufref(&bufref, buf);
      (void)buf_write_all(buf, false);
      // an autocommand may have deleted the buffer
      if (!bufref_valid(&bufref)) {
        buf = firstbuf;
      }
    }
  }
}

/// Return true if buffer was changed and cannot be abandoned.
/// For flags use the CCGD_ values.
bool check_changed(buf_T *buf, int flags)
{
  int forceit = (flags & CCGD_FORCEIT);
  bufref_T bufref;
  set_bufref(&bufref, buf);

  if (!forceit
      && bufIsChanged(buf)
      && ((flags & CCGD_MULTWIN) || buf->b_nwindows <= 1)
      && (!(flags & CCGD_AW) || autowrite(buf, forceit) == FAIL)) {
    if ((p_confirm || cmdmod.confirm) && p_write) {
      int count = 0;

      if (flags & CCGD_ALLBUF) {
        FOR_ALL_BUFFERS(buf2) {
          if (bufIsChanged(buf2) && (buf2->b_ffname != NULL)) {
            count++;
          }
        }
      }
      if (!bufref_valid(&bufref)) {
        // Autocommand deleted buffer, oops!  It's not changed now.
        return false;
      }
      dialog_changed(buf, count > 1);
      if (!bufref_valid(&bufref)) {
        // Autocommand deleted buffer, oops!  It's not changed now.
        return false;
      }
      return bufIsChanged(buf);
    }
    if (flags & CCGD_EXCMD) {
      EMSG(_(e_nowrtmsg));
    } else {
      EMSG(_(e_nowrtmsg_nobang));
    }
    return true;
  }
  return false;
}



/// Ask the user what to do when abandoning a changed buffer.
/// Must check 'write' option first!
///
/// @param buf
/// @param checkall may abandon all changed buffers
void dialog_changed(buf_T *buf, bool checkall)
{
  char_u buff[DIALOG_MSG_SIZE];
  int ret;
  exarg_T ea;

  dialog_msg(buff, _("Save changes to \"%s\"?"), buf->b_fname);
  if (checkall) {
    ret = vim_dialog_yesnoallcancel(VIM_QUESTION, NULL, buff, 1);
  } else {
    ret = vim_dialog_yesnocancel(VIM_QUESTION, NULL, buff, 1);
  }

  // Init ea pseudo-structure, this is needed for the check_overwrite()
  // function.
  ea.append = ea.forceit = false;

  if (ret == VIM_YES) {
    if (buf->b_fname != NULL
        && check_overwrite(&ea,
                           buf,
                           buf->b_fname,
                           buf->b_ffname,
                           false) == OK) {
      // didn't hit Cancel
      (void)buf_write_all(buf, false);
    }
  } else if (ret == VIM_NO) {
    unchanged(buf, true);
  } else if (ret == VIM_ALL) {
    // Write all modified files that can be written.
    // Skip readonly buffers, these need to be confirmed
    // individually.
    FOR_ALL_BUFFERS(buf2) {
      if (bufIsChanged(buf2) && (buf2->b_ffname != NULL) && !buf2->b_p_ro) {
        bufref_T bufref;
        set_bufref(&bufref, buf2);

        if (buf2->b_fname != NULL
            && check_overwrite(&ea, buf2, buf2->b_fname,
                               buf2->b_ffname, false) == OK) {
          // didn't hit Cancel
          (void)buf_write_all(buf2, false);
        }
        // an autocommand may have deleted the buffer
        if (!bufref_valid(&bufref)) {
          buf2 = firstbuf;
        }
      }
    }
  } else if (ret == VIM_DISCARDALL) {
    // mark all buffers as unchanged
    FOR_ALL_BUFFERS(buf2) {
      unchanged(buf2, true);
    }
  }
}

/// Ask the user whether to close the terminal buffer or not.
///
/// @param buf The terminal buffer.
/// @return bool Whether to close the buffer or not.
bool dialog_close_terminal(buf_T *buf)
{
  char_u buff[DIALOG_MSG_SIZE];

  dialog_msg(buff, _("Close \"%s\"?"),
             (buf->b_fname != NULL) ? buf->b_fname : (char_u *)"?");

  int ret = vim_dialog_yesnocancel(VIM_QUESTION, NULL, buff, 1);

  return (ret == VIM_YES) ? true : false;
}

/// Return true if the buffer "buf" can be abandoned, either by making it
/// hidden, autowriting it or unloading it.
bool can_abandon(buf_T *buf, int forceit)
{
  return buf_hide(buf)
         || !bufIsChanged(buf)
         || buf->b_nwindows > 1
         || autowrite(buf, forceit) == OK
         || forceit;
}


/// Add a buffer number to "bufnrs", unless it's already there.
static void add_bufnum(int *bufnrs, int *bufnump, int nr)
{
  int i;

  for (i = 0; i < *bufnump; i++) {
    if (bufnrs[i] == nr) {
      return;
    }
  }
  bufnrs[*bufnump] = nr;
  *bufnump = *bufnump + 1;
}

/// Check if any buffer was changed and cannot be abandoned.
/// That changed buffer becomes the current buffer.
/// When "unload" is true the current buffer is unloaded instead of making it
/// hidden.  This is used for ":q!".
///
/// @param[in] hidden specifies whether to check only hidden buffers.
/// @param[in] unload specifies whether to unload, instead of hide, the buffer.
///
/// @returns          true if any buffer is changed and cannot be abandoned
bool check_changed_any(bool hidden, bool unload)
{
  bool ret = false;
  int save;
  int i;
  int bufnum = 0;
  size_t bufcount = 0;
  int         *bufnrs;

  FOR_ALL_BUFFERS(buf) {
    bufcount++;
  }

  if (bufcount == 0) {
    return false;
  }

  bufnrs = xmalloc(sizeof(*bufnrs) * bufcount);

  // curbuf
  bufnrs[bufnum++] = curbuf->b_fnum;
  // buf in curtab
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer != curbuf) {
      add_bufnum(bufnrs, &bufnum, wp->w_buffer->b_fnum);
    }
  }

  // buf in other tab
  FOR_ALL_TABS(tp) {
    if (tp != curtab) {
      FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
        add_bufnum(bufnrs, &bufnum, wp->w_buffer->b_fnum);
      }
    }
  }

  // any other buf
  FOR_ALL_BUFFERS(buf) {
    add_bufnum(bufnrs, &bufnum, buf->b_fnum);
  }

  buf_T *buf = NULL;
  for (i = 0; i < bufnum; i++) {
    buf = buflist_findnr(bufnrs[i]);
    if (buf == NULL) {
      continue;
    }
    if ((!hidden || buf->b_nwindows == 0) && bufIsChanged(buf)) {
      bufref_T bufref;
      set_bufref(&bufref, buf);

      // Try auto-writing the buffer.  If this fails but the buffer no
      // longer exists it's not changed, that's OK.
      if (check_changed(buf, (p_awa ? CCGD_AW : 0)
                        | CCGD_MULTWIN
                        | CCGD_ALLBUF) && bufref_valid(&bufref)) {
        break;    // didn't save - still changes
      }
    }
  }

  if (i >= bufnum) {
    goto theend;
  }

  ret = true;
  exiting = false;
  // When ":confirm" used, don't give an error message.
  if (!(p_confirm || cmdmod.confirm)) {
    // There must be a wait_return for this message, do_buffer()
    // may cause a redraw.  But wait_return() is a no-op when vgetc()
    // is busy (Quit used from window menu), then make sure we don't
    // cause a scroll up.
    if (vgetc_busy > 0) {
      msg_row = cmdline_row;
      msg_col = 0;
      msg_didout = false;
    }
    if (EMSG2(_("E162: No write since last change for buffer \"%s\""),
              buf_spname(buf) != NULL ? buf_spname(buf) : buf->b_fname)) {
      save = no_wait_return;
      no_wait_return = false;
      wait_return(false);
      no_wait_return = save;
    }
  }

  // Try to find a window that contains the buffer.
  if (buf != curbuf) {
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp->w_buffer == buf) {
        bufref_T bufref;
        set_bufref(&bufref, buf);
        goto_tabpage_win(tp, wp);
        // Paranoia: did autocmds wipe out the buffer with changes?
        if (!bufref_valid(&bufref)) {
          goto theend;
        }
        goto buf_found;
      }
    }
  }
buf_found:

  // Open the changed buffer in the current window.
  if (buf != curbuf) {
    set_curbuf(buf, unload ? DOBUF_UNLOAD : DOBUF_GOTO);
  }

theend:
  xfree(bufnrs);
  return ret;
}

/// Return FAIL if there is no file name, OK if there is one.
/// Give error message for FAIL.
int check_fname(void)
{
  if (curbuf->b_ffname == NULL) {
    EMSG(_(e_noname));
    return FAIL;
  }
  return OK;
}

/// Flush the contents of a buffer, unless it has no file name.
///
/// @return FAIL for failure, OK otherwise
int buf_write_all(buf_T *buf, int forceit)
{
  int retval;
  buf_T       *old_curbuf = curbuf;

  retval = (buf_write(buf, buf->b_ffname, buf->b_fname,
                      (linenr_T)1, buf->b_ml.ml_line_count, NULL,
                      false, forceit, true, false));
  if (curbuf != old_curbuf) {
    msg_source(HL_ATTR(HLF_W));
    MSG(_("Warning: Entered other buffer unexpectedly (check autocommands)"));
  }
  return retval;
}

/// Code to handle the argument list.

#define AL_SET  1
#define AL_ADD  2
#define AL_DEL  3

/// Isolate one argument, taking backticks.
/// Changes the argument in-place, puts a NUL after it.  Backticks remain.
/// Return a pointer to the start of the next argument.
static char_u *do_one_arg(char_u *str)
{
  char_u      *p;
  bool inbacktick;

  inbacktick = false;
  for (p = str; *str; str++) {
    // When the backslash is used for escaping the special meaning of a
    // character we need to keep it until wildcard expansion.
    if (rem_backslash(str)) {
      *p++ = *str++;
      *p++ = *str;
    } else {
      // An item ends at a space not in backticks
      if (!inbacktick && ascii_isspace(*str)) {
        break;
      }
      if (*str == '`') {
        inbacktick ^= true;
      }
      *p++ = *str;
    }
  }
  str = skipwhite(str);
  *p = NUL;

  return str;
}

/// Separate the arguments in "str" and return a list of pointers in the
/// growarray "gap".
static void get_arglist(garray_T *gap, char_u *str, int escaped)
{
  ga_init(gap, (int)sizeof(char_u *), 20);
  while (*str != NUL) {
    GA_APPEND(char_u *, gap, str);

    // If str is escaped, don't handle backslashes or spaces
    if (!escaped) {
      return;
    }

    // Isolate one argument, change it in-place, put a NUL after it.
    str = do_one_arg(str);
  }
}

/// Parse a list of arguments (file names), expand them and return in
/// "fnames[fcountp]".  When "wig" is true, removes files matching 'wildignore'.
///
/// @return FAIL or OK.
int get_arglist_exp(char_u *str, int *fcountp, char_u ***fnamesp, bool wig)
{
  garray_T ga;
  int i;

  get_arglist(&ga, str, true);

  if (wig) {
    i = expand_wildcards(ga.ga_len, (char_u **)ga.ga_data,
                         fcountp, fnamesp, EW_FILE|EW_NOTFOUND);
  } else {
    i = gen_expand_wildcards(ga.ga_len, (char_u **)ga.ga_data,
                             fcountp, fnamesp, EW_FILE|EW_NOTFOUND);
  }

  ga_clear(&ga);
  return i;
}


/// @param str
/// @param what
///         AL_SET: Redefine the argument list to 'str'.
///         AL_ADD: add files in 'str' to the argument list after "after".
///         AL_DEL: remove files in 'str' from the argument list.
/// @param after
///         0 means before first one
///
/// @return FAIL for failure, OK otherwise.
static int do_arglist(char_u *str, int what, int after)
{
  garray_T new_ga;
  int exp_count;
  char_u      **exp_files;
  char_u      *p;
  int match;
  int arg_escaped = true;

  // Set default argument for ":argadd" command.
  if (what == AL_ADD && *str == NUL) {
    if (curbuf->b_ffname == NULL) {
      return FAIL;
    }
    str = curbuf->b_fname;
    arg_escaped = false;
  }

  // Collect all file name arguments in "new_ga".
  get_arglist(&new_ga, str, arg_escaped);

  if (what == AL_DEL) {
    regmatch_T regmatch;
    bool didone;

    // Delete the items: use each item as a regexp and find a match in the
    // argument list.
    regmatch.rm_ic = p_fic;     // ignore case when 'fileignorecase' is set
    for (int i = 0; i < new_ga.ga_len && !got_int; i++) {
      p = ((char_u **)new_ga.ga_data)[i];
      p = file_pat_to_reg_pat(p, NULL, NULL, false);
      if (p == NULL) {
        break;
      }
      regmatch.regprog = vim_regcomp(p, p_magic ? RE_MAGIC : 0);
      if (regmatch.regprog == NULL) {
        xfree(p);
        break;
      }

      didone = false;
      for (match = 0; match < ARGCOUNT; match++) {
        if (vim_regexec(&regmatch, alist_name(&ARGLIST[match]),
                        (colnr_T)0)) {
          didone = true;
          xfree(ARGLIST[match].ae_fname);
          memmove(ARGLIST + match, ARGLIST + match + 1,
                  (size_t)(ARGCOUNT - match - 1) * sizeof(aentry_T));
          ALIST(curwin)->al_ga.ga_len--;
          if (curwin->w_arg_idx > match) {
            curwin->w_arg_idx--;
          }
          match--;
        }
      }

      vim_regfree(regmatch.regprog);
      xfree(p);
      if (!didone) {
        EMSG2(_(e_nomatch2), ((char_u **)new_ga.ga_data)[i]);
      }
    }
    ga_clear(&new_ga);
  } else {
    int i = expand_wildcards(new_ga.ga_len, (char_u **)new_ga.ga_data,
                             &exp_count, &exp_files,
                             EW_DIR|EW_FILE|EW_ADDSLASH|EW_NOTFOUND);
    ga_clear(&new_ga);
    if (i == FAIL || exp_count == 0) {
      EMSG(_(e_nomatch));
      return FAIL;
    }

    if (what == AL_ADD) {
      (void)alist_add_list(exp_count, exp_files, after);
      xfree(exp_files);
    } else {  // what == AL_SET
      alist_set(ALIST(curwin), exp_count, exp_files, false, NULL, 0);
    }
  }

  alist_check_arg_idx();

  return OK;
}

/// Check the validity of the arg_idx for each other window.
static void alist_check_arg_idx(void)
{
  FOR_ALL_TAB_WINDOWS(tp, win) {
    if (win->w_alist == curwin->w_alist) {
      check_arg_idx(win);
    }
  }
}

/// Return true if window "win" is editing the file at the current argument
/// index.
static bool editing_arg_idx(win_T *win)
{
  return !(win->w_arg_idx >= WARGCOUNT(win)
           || (win->w_buffer->b_fnum
               != WARGLIST(win)[win->w_arg_idx].ae_fnum
               && (win->w_buffer->b_ffname == NULL
                   || !(path_full_compare(
                       alist_name(&WARGLIST(win)[win->w_arg_idx]),
                       win->w_buffer->b_ffname, true) & kEqualFiles))));
}

/// Check if window "win" is editing the w_arg_idx file in its argument list.
void check_arg_idx(win_T *win)
{
  if (WARGCOUNT(win) > 1 && !editing_arg_idx(win)) {
    // We are not editing the current entry in the argument list.
    // Set "arg_had_last" if we are editing the last one.
    win->w_arg_idx_invalid = true;
    if (win->w_arg_idx != WARGCOUNT(win) - 1
        && arg_had_last == false
        && ALIST(win) == &global_alist
        && GARGCOUNT > 0
        && win->w_arg_idx < GARGCOUNT
        && (win->w_buffer->b_fnum == GARGLIST[GARGCOUNT - 1].ae_fnum
            || (win->w_buffer->b_ffname != NULL
                && (path_full_compare(alist_name(&GARGLIST[GARGCOUNT - 1]),
                                      win->w_buffer->b_ffname, true)
                    & kEqualFiles)))) {
      arg_had_last = true;
    }
  } else {
    // We are editing the current entry in the argument list.
    // Set "arg_had_last" if it's also the last one
    win->w_arg_idx_invalid = false;
    if (win->w_arg_idx == WARGCOUNT(win) - 1
        && win->w_alist == &global_alist) {
      arg_had_last = true;
    }
  }
}

/// ":args", ":argslocal" and ":argsglobal".
void ex_args(exarg_T *eap)
{
  if (eap->cmdidx != CMD_args) {
    alist_unlink(ALIST(curwin));
    if (eap->cmdidx == CMD_argglobal) {
      ALIST(curwin) = &global_alist;
    } else {     // eap->cmdidx == CMD_arglocal
      alist_new();
    }
  }

  if (*eap->arg != NUL) {
    // ":args file ..": define new argument list, handle like ":next"
    // Also for ":argslocal file .." and ":argsglobal file ..".
    ex_next(eap);
  } else if (eap->cmdidx == CMD_args) {
    // ":args": list arguments.
    if (ARGCOUNT > 0) {
      // Overwrite the command, for a short list there is no scrolling
      // required and no wait_return().
      gotocmdline(true);
      for (int i = 0; i < ARGCOUNT; i++) {
        if (i == curwin->w_arg_idx) {
          msg_putchar('[');
        }
        msg_outtrans(alist_name(&ARGLIST[i]));
        if (i == curwin->w_arg_idx) {
          msg_putchar(']');
        }
        msg_putchar(' ');
      }
    }
  } else if (eap->cmdidx == CMD_arglocal) {
    garray_T        *gap = &curwin->w_alist->al_ga;

    // ":argslocal": make a local copy of the global argument list.
    ga_grow(gap, GARGCOUNT);
    for (int i = 0; i < GARGCOUNT; i++) {
      if (GARGLIST[i].ae_fname != NULL) {
        AARGLIST(curwin->w_alist)[gap->ga_len].ae_fname =
          vim_strsave(GARGLIST[i].ae_fname);
        AARGLIST(curwin->w_alist)[gap->ga_len].ae_fnum =
          GARGLIST[i].ae_fnum;
        gap->ga_len++;
      }
    }
  }
}

/// ":previous", ":sprevious", ":Next" and ":sNext".
void ex_previous(exarg_T *eap)
{
  // If past the last one already, go to the last one.
  if (curwin->w_arg_idx - (int)eap->line2 >= ARGCOUNT) {
    do_argfile(eap, ARGCOUNT - 1);
  } else {
    do_argfile(eap, curwin->w_arg_idx - (int)eap->line2);
  }
}

/// ":rewind", ":first", ":sfirst" and ":srewind".
void ex_rewind(exarg_T *eap)
{
  do_argfile(eap, 0);
}

/// ":last" and ":slast".
void ex_last(exarg_T *eap)
{
  do_argfile(eap, ARGCOUNT - 1);
}

/// ":argument" and ":sargument".
void ex_argument(exarg_T *eap)
{
  int i;

  if (eap->addr_count > 0) {
    i = (int)eap->line2 - 1;
  } else {
    i = curwin->w_arg_idx;
  }
  do_argfile(eap, i);
}

/// Edit file "argn" of the argument lists.
void do_argfile(exarg_T *eap, int argn)
{
  int other;
  char_u      *p;
  int old_arg_idx = curwin->w_arg_idx;

  if (argn < 0 || argn >= ARGCOUNT) {
    if (ARGCOUNT <= 1) {
      EMSG(_("E163: There is only one file to edit"));
    } else if (argn < 0) {
      EMSG(_("E164: Cannot go before first file"));
    } else {
      EMSG(_("E165: Cannot go beyond last file"));
    }
  } else {
    setpcmark();

    // split window or create new tab page first
    if (*eap->cmd == 's' || cmdmod.tab != 0) {
      if (win_split(0, 0) == FAIL) {
        return;
      }
      RESET_BINDING(curwin);
    } else {
      // if 'hidden' set, only check for changed file when re-editing
      // the same buffer
      other = true;
      if (buf_hide(curbuf)) {
        p = (char_u *)fix_fname((char *)alist_name(&ARGLIST[argn]));
        other = otherfile(p);
        xfree(p);
      }
      if ((!buf_hide(curbuf) || !other)
          && check_changed(curbuf, CCGD_AW
                           | (other ? 0 : CCGD_MULTWIN)
                           | (eap->forceit ? CCGD_FORCEIT : 0)
                           | CCGD_EXCMD)) {
        return;
      }
    }

    curwin->w_arg_idx = argn;
    if (argn == ARGCOUNT - 1
        && curwin->w_alist == &global_alist) {
      arg_had_last = true;
    }

    // Edit the file; always use the last known line number.
    // When it fails (e.g. Abort for already edited file) restore the
    // argument index.
    if (do_ecmd(0, alist_name(&ARGLIST[curwin->w_arg_idx]), NULL,
                eap, ECMD_LAST,
                (buf_hide(curwin->w_buffer) ? ECMD_HIDE : 0)
                + (eap->forceit ? ECMD_FORCEIT : 0), curwin) == FAIL) {
      curwin->w_arg_idx = old_arg_idx;
    } else if (eap->cmdidx != CMD_argdo) {
      // like Vi: set the mark where the cursor is in the file.
      setmark('\'');
    }
  }
}

/// ":next", and commands that behave like it.
void ex_next(exarg_T *eap)
{
  int i;

  // check for changed buffer now, if this fails the argument list is not
  // redefined.
  if (buf_hide(curbuf)
      || eap->cmdidx == CMD_snext
      || !check_changed(curbuf, CCGD_AW
                        | (eap->forceit ? CCGD_FORCEIT : 0)
                        | CCGD_EXCMD)) {
    if (*eap->arg != NUL) {                 // redefine file list
      if (do_arglist(eap->arg, AL_SET, 0) == FAIL) {
        return;
      }
      i = 0;
    } else {
      i = curwin->w_arg_idx + (int)eap->line2;
    }
    do_argfile(eap, i);
  }
}

/// ":argedit"
void ex_argedit(exarg_T *eap)
{
  int i = eap->addr_count ? (int)eap->line2 : curwin->w_arg_idx + 1;

  if (do_arglist(eap->arg, AL_ADD, i) == FAIL) {
    return;
  }
  maketitle();

  if (curwin->w_arg_idx == 0 && (curbuf->b_ml.ml_flags & ML_EMPTY)
      && curbuf->b_ffname == NULL) {
    i = 0;
  }
  // Edit the argument.
  if (i < ARGCOUNT) {
    do_argfile(eap, i);
  }
}

/// ":argadd"
void ex_argadd(exarg_T *eap)
{
  do_arglist(eap->arg, AL_ADD,
             eap->addr_count > 0 ? (int)eap->line2 : curwin->w_arg_idx + 1);
  maketitle();
}

/// ":argdelete"
void ex_argdelete(exarg_T *eap)
{
  if (eap->addr_count > 0) {
    // ":1,4argdel": Delete all arguments in the range.
    if (eap->line2 > ARGCOUNT) {
      eap->line2 = ARGCOUNT;
    }
    linenr_T n = eap->line2 - eap->line1 + 1;
    if (*eap->arg != NUL) {
      // Can't have both a range and an argument.
      EMSG(_(e_invarg));
    } else if (n <= 0) {
      // Don't give an error for ":%argdel" if the list is empty.
      if (eap->line1 != 1 || eap->line2 != 0) {
        EMSG(_(e_invrange));
      }
    } else {
      for (linenr_T i = eap->line1; i <= eap->line2; i++) {
        xfree(ARGLIST[i - 1].ae_fname);
      }
      memmove(ARGLIST + eap->line1 - 1, ARGLIST + eap->line2,
              (size_t)(ARGCOUNT - eap->line2) * sizeof(aentry_T));
      ALIST(curwin)->al_ga.ga_len -= (int)n;
      if (curwin->w_arg_idx >= eap->line2) {
        curwin->w_arg_idx -= (int)n;
      } else if (curwin->w_arg_idx > eap->line1) {
        curwin->w_arg_idx = (int)eap->line1;
      }
      if (ARGCOUNT == 0) {
          curwin->w_arg_idx = 0;
      } else if (curwin->w_arg_idx >= ARGCOUNT) {
          curwin->w_arg_idx = ARGCOUNT - 1;
      }
    }
  } else if (*eap->arg == NUL) {
    EMSG(_(e_argreq));
  } else {
    do_arglist(eap->arg, AL_DEL, 0);
  }
  maketitle();
}

/// ":argdo", ":windo", ":bufdo", ":tabdo", ":cdo", ":ldo", ":cfdo" and ":lfdo"
void ex_listdo(exarg_T *eap)
{
  int i;
  win_T       *wp;
  tabpage_T   *tp;
  int next_fnum = 0;
  char_u      *save_ei = NULL;
  char_u      *p_shm_save;

  if (eap->cmdidx != CMD_windo && eap->cmdidx != CMD_tabdo) {
    // Don't do syntax HL autocommands.  Skipping the syntax file is a
    // great speed improvement.
    save_ei = au_event_disable(",Syntax");
  }

  if (eap->cmdidx == CMD_windo
      || eap->cmdidx == CMD_tabdo
      || buf_hide(curbuf)
      || !check_changed(curbuf, CCGD_AW
                        | (eap->forceit ? CCGD_FORCEIT : 0)
                        | CCGD_EXCMD)) {
    i = 0;
    // start at the eap->line1 argument/window/buffer
    wp = firstwin;
    tp = first_tabpage;
    switch (eap->cmdidx) {
    case CMD_windo:
      for (; wp != NULL && i + 1 < eap->line1; wp = wp->w_next) {
        i++;
      }
      break;
    case CMD_tabdo:
      for (; tp != NULL && i + 1 < eap->line1; tp = tp->tp_next) {
        i++;
      }
      break;
    case CMD_argdo:
      i = (int)eap->line1 - 1;
      break;
    default:
      break;
    }

    buf_T *buf = curbuf;
    size_t qf_size = 0;

    // set pcmark now
    if (eap->cmdidx == CMD_bufdo) {
      // Advance to the first listed buffer after "eap->line1".
      for (buf = firstbuf;
           buf != NULL && (buf->b_fnum < eap->line1 || !buf->b_p_bl);
           buf = buf->b_next) {
        if (buf->b_fnum > eap->line2) {
          buf = NULL;
          break;
        }
      }
      if (buf != NULL) {
        goto_buffer(eap, DOBUF_FIRST, FORWARD, buf->b_fnum);
      }
    } else if (eap->cmdidx == CMD_cdo || eap->cmdidx == CMD_ldo
               || eap->cmdidx == CMD_cfdo || eap->cmdidx == CMD_lfdo) {
      qf_size = qf_get_size(eap);
      assert(eap->line1 >= 0);
      if (qf_size == 0 || (size_t)eap->line1 > qf_size) {
        buf = NULL;
      } else {
        ex_cc(eap);

        buf = curbuf;
        i = (int)eap->line1 - 1;
        if (eap->addr_count <= 0) {
          // Default to all quickfix/location list entries.
          assert(qf_size < MAXLNUM);
          eap->line2 = (linenr_T)qf_size;
        }
      }
    } else {
      setpcmark();
    }
    listcmd_busy = true;            // avoids setting pcmark below

    while (!got_int && buf != NULL) {
      if (eap->cmdidx == CMD_argdo) {
        // go to argument "i"
        if (i == ARGCOUNT) {
          break;
        }
        // Don't call do_argfile() when already there, it will try
        // reloading the file.
        if (curwin->w_arg_idx != i || !editing_arg_idx(curwin)) {
          // Clear 'shm' to avoid that the file message overwrites
          // any output from the command.
          p_shm_save = vim_strsave(p_shm);
          set_option_value("shm", 0L, "", 0);
          do_argfile(eap, i);
          set_option_value("shm", 0L, (char *)p_shm_save, 0);
          xfree(p_shm_save);
        }
        if (curwin->w_arg_idx != i) {
          break;
        }
      } else if (eap->cmdidx == CMD_windo) {
        // go to window "wp"
        if (!win_valid(wp)) {
          break;
        }
        assert(wp);
        win_goto(wp);
        if (curwin != wp) {
          break;    // something must be wrong
        }
        wp = curwin->w_next;
      } else if (eap->cmdidx == CMD_tabdo) {
        // go to window "tp"
        if (!valid_tabpage(tp)) {
          break;
        }
        assert(tp);
        goto_tabpage_tp(tp, true, true);
        tp = tp->tp_next;
      } else if (eap->cmdidx == CMD_bufdo) {
        // Remember the number of the next listed buffer, in case
        // ":bwipe" is used or autocommands do something strange.
        next_fnum = -1;
        for (buf_T *bp = curbuf->b_next; bp != NULL; bp = bp->b_next) {
          if (bp->b_p_bl) {
            next_fnum = bp->b_fnum;
            break;
          }
        }
      }

      i++;
      // execute the command
      do_cmdline(eap->arg, eap->getline, eap->cookie,
                 DOCMD_VERBOSE + DOCMD_NOWAIT);

      if (eap->cmdidx == CMD_bufdo) {
        // Done?
        if (next_fnum < 0 || next_fnum > eap->line2) {
          break;
        }

        // Check if the buffer still exists.
        bool buf_still_exists = false;
        FOR_ALL_BUFFERS(bp) {
          if (bp->b_fnum == next_fnum) {
            buf_still_exists = true;
            break;
          }
        }
        if (!buf_still_exists) {
          break;
        }

        // Go to the next buffer.  Clear 'shm' to avoid that the file
        // message overwrites any output from the command.
        p_shm_save = vim_strsave(p_shm);
        set_option_value("shm", 0L, "", 0);
        goto_buffer(eap, DOBUF_FIRST, FORWARD, next_fnum);
        set_option_value("shm", 0L, (char *)p_shm_save, 0);
        xfree(p_shm_save);

        // If autocommands took us elsewhere, quit here.
        if (curbuf->b_fnum != next_fnum) {
          break;
        }
      }

      if (eap->cmdidx == CMD_cdo || eap->cmdidx == CMD_ldo
          || eap->cmdidx == CMD_cfdo || eap->cmdidx == CMD_lfdo) {
        assert(i >= 0);
        if ((size_t)i >= qf_size || i >= eap->line2) {
          break;
        }

        size_t qf_idx = qf_get_cur_idx(eap);

        ex_cnext(eap);

        // If jumping to the next quickfix entry fails, quit here.
        if (qf_get_cur_idx(eap) == qf_idx) {
          break;
        }
      }

      if (eap->cmdidx == CMD_windo) {
        validate_cursor();              // cursor may have moved
        // required when 'scrollbind' has been set
        if (curwin->w_p_scb) {
          do_check_scrollbind(true);
        }
      }
      if (eap->cmdidx == CMD_windo || eap->cmdidx == CMD_tabdo) {
        if (i + 1 > eap->line2) {
          break;
        }
      }
      if (eap->cmdidx == CMD_argdo && i >= eap->line2) {
        break;
      }
    }
    listcmd_busy = false;
  }

  if (save_ei != NULL) {
    au_event_restore(save_ei);
    apply_autocmds(EVENT_SYNTAX, curbuf->b_p_syn,
                   curbuf->b_fname, true, curbuf);
  }
}

/// Add files[count] to the arglist of the current window after arg "after".
/// The file names in files[count] must have been allocated and are taken over.
/// Files[] itself is not taken over.
///
/// @param after: where to add: 0 = before first one
///
/// @return index of first added argument
static int alist_add_list(int count, char_u **files, int after)
{
  int old_argcount = ARGCOUNT;
  ga_grow(&ALIST(curwin)->al_ga, count);
  {
    if (after < 0) {
      after = 0;
    }
    if (after > ARGCOUNT) {
      after = ARGCOUNT;
    }
    if (after < ARGCOUNT) {
      memmove(&(ARGLIST[after + count]), &(ARGLIST[after]),
              (size_t)(ARGCOUNT - after) * sizeof(aentry_T));
    }
    for (int i = 0; i < count; i++) {
      ARGLIST[after + i].ae_fname = files[i];
      ARGLIST[after + i].ae_fnum = buflist_add(files[i], BLN_LISTED);
    }
    ALIST(curwin)->al_ga.ga_len += count;
    if (old_argcount > 0 && curwin->w_arg_idx >= after) {
      curwin->w_arg_idx += count;
    }
    return after;
  }
}

// Function given to ExpandGeneric() to obtain the possible arguments of the
// argedit and argdelete commands.
char_u *get_arglist_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx >= ARGCOUNT) {
    return NULL;
  }
  return alist_name(&ARGLIST[idx]);
}

/// ":compiler[!] {name}"
void ex_compiler(exarg_T *eap)
{
  char_u      *buf;
  char_u      *old_cur_comp = NULL;
  char_u      *p;

  if (*eap->arg == NUL) {
    // List all compiler scripts.
    do_cmdline_cmd("echo globpath(&rtp, 'compiler/*.vim')");  // NOLINT
  } else {
    size_t bufsize = STRLEN(eap->arg) + 14;
    buf = xmalloc(bufsize);
    if (eap->forceit) {
      // ":compiler! {name}" sets global options
      do_cmdline_cmd("command -nargs=* CompilerSet set <args>");
    } else {
      // ":compiler! {name}" sets local options.
      // To remain backwards compatible "current_compiler" is always
      // used.  A user's compiler plugin may set it, the distributed
      // plugin will then skip the settings.  Afterwards set
      // "b:current_compiler" and restore "current_compiler".
      // Explicitly prepend "g:" to make it work in a function.
      old_cur_comp = get_var_value("g:current_compiler");
      if (old_cur_comp != NULL) {
        old_cur_comp = vim_strsave(old_cur_comp);
      }
      do_cmdline_cmd("command -nargs=* CompilerSet setlocal <args>");
    }
    do_unlet(S_LEN("g:current_compiler"), true);
    do_unlet(S_LEN("b:current_compiler"), true);

    snprintf((char *)buf, bufsize, "compiler/%s.vim", eap->arg);
    if (source_runtime(buf, DIP_ALL) == FAIL) {
      EMSG2(_("E666: compiler not supported: %s"), eap->arg);
    }
    xfree(buf);

    do_cmdline_cmd(":delcommand CompilerSet");

    // Set "b:current_compiler" from "current_compiler".
    p = get_var_value("g:current_compiler");
    if (p != NULL) {
      set_internal_string_var((char_u *)"b:current_compiler", p);
    }

    // Restore "current_compiler" for ":compiler {name}".
    if (!eap->forceit) {
      if (old_cur_comp != NULL) {
        set_internal_string_var((char_u *)"g:current_compiler",
                                old_cur_comp);
        xfree(old_cur_comp);
      } else {
        do_unlet(S_LEN("g:current_compiler"), true);
      }
    }
  }
}

/// ":runtime [what] {name}"
void ex_runtime(exarg_T *eap)
{
  char_u *arg = eap->arg;
  char_u *p = skiptowhite(arg);
  ptrdiff_t len = p - arg;
  int flags = eap->forceit ? DIP_ALL : 0;

  if (STRNCMP(arg, "START", len) == 0) {
    flags += DIP_START + DIP_NORTP;
    arg = skipwhite(arg + len);
  } else if (STRNCMP(arg, "OPT", len) == 0) {
    flags += DIP_OPT + DIP_NORTP;
    arg = skipwhite(arg + len);
  } else if (STRNCMP(arg, "PACK", len) == 0) {
    flags += DIP_START + DIP_OPT + DIP_NORTP;
    arg = skipwhite(arg + len);
  } else if (STRNCMP(arg, "ALL", len) == 0) {
    flags += DIP_START + DIP_OPT;
    arg = skipwhite(arg + len);
  }

  source_runtime(arg, flags);
}


static void source_callback(char_u *fname, void *cookie)
{
  (void)do_source(fname, false, DOSO_NONE);
}

/// Find the file "name" in all directories in "path" and invoke
/// "callback(fname, cookie)".
/// "name" can contain wildcards.
/// When "flags" has DIP_ALL: source all files, otherwise only the first one.
/// When "flags" has DIP_DIR: find directories instead of files.
/// When "flags" has DIP_ERR: give an error message if there is no match.
///
/// return FAIL when no file could be sourced, OK otherwise.
int do_in_path(char_u *path, char_u *name, int flags,
               DoInRuntimepathCB callback, void *cookie)
{
  char_u      *tail;
  int num_files;
  char_u      **files;
  int i;
  bool did_one = false;

  // Make a copy of 'runtimepath'.  Invoking the callback may change the
  // value.
  char_u *rtp_copy = vim_strsave(path);
  char_u *buf = xmallocz(MAXPATHL);
  {
    if (p_verbose > 1 && name != NULL) {
      verbose_enter();
      smsg(_("Searching for \"%s\" in \"%s\""),
           (char *)name, (char *)path);
      verbose_leave();
    }

    // Loop over all entries in 'runtimepath'.
    char_u *rtp = rtp_copy;
    while (*rtp != NUL && ((flags & DIP_ALL) || !did_one)) {
      // Copy the path from 'runtimepath' to buf[].
      copy_option_part(&rtp, buf, MAXPATHL, ",");
      size_t buflen = STRLEN(buf);

      // Skip after or non-after directories.
      if (flags & (DIP_NOAFTER | DIP_AFTER)) {
        bool is_after = buflen >= 5
          && STRCMP(buf + buflen - 5, "after") == 0;

        if ((is_after && (flags & DIP_NOAFTER))
            || (!is_after && (flags & DIP_AFTER))) {
          continue;
        }
      }

      if (name == NULL) {
        (*callback)(buf, (void *)&cookie);
        if (!did_one) {
          did_one = (cookie == NULL);
        }
      } else if (buflen + STRLEN(name) + 2 < MAXPATHL) {
        add_pathsep((char *)buf);
        tail = buf + STRLEN(buf);

        // Loop over all patterns in "name"
        char_u *np = name;
        while (*np != NUL && ((flags & DIP_ALL) || !did_one)) {
          // Append the pattern from "name" to buf[].
          assert(MAXPATHL >= (tail - buf));
          copy_option_part(&np, tail, (size_t)(MAXPATHL - (tail - buf)),
                           "\t ");

          if (p_verbose > 2) {
            verbose_enter();
            smsg(_("Searching for \"%s\""), buf);
            verbose_leave();
          }

          // Expand wildcards, invoke the callback for each match.
          if (gen_expand_wildcards(1, &buf, &num_files, &files,
                                   (flags & DIP_DIR) ? EW_DIR
                                                     : EW_FILE) == OK) {
            for (i = 0; i < num_files; i++) {
              (*callback)(files[i], cookie);
              did_one = true;
              if (!(flags & DIP_ALL)) {
                break;
              }
            }
            FreeWild(num_files, files);
          }
        }
      }
    }
  }
  xfree(buf);
  xfree(rtp_copy);
  if (!did_one && name != NULL) {
    char *basepath = path == p_rtp ? "runtimepath" : "packpath";

    if (flags & DIP_ERR) {
      EMSG3(_(e_dirnotf), basepath, name);
    } else if (p_verbose > 0) {
      verbose_enter();
      smsg(_("not found in '%s': \"%s\""), basepath, name);
      verbose_leave();
    }
  }


  return did_one ? OK : FAIL;
}

/// Find "name" in "path".  When found, invoke the callback function for
/// it: callback(fname, "cookie")
/// When "flags" has DIP_ALL repeat for all matches, otherwise only the first
/// one is used.
/// Returns OK when at least one match found, FAIL otherwise.
/// If "name" is NULL calls callback for each entry in "path". Cookie is
/// passed by reference in this case, setting it to NULL indicates that callback
/// has done its job.
int do_in_path_and_pp(char_u *path, char_u *name, int flags,
                      DoInRuntimepathCB callback, void *cookie)
{
  int done = FAIL;

  if ((flags & DIP_NORTP) == 0) {
    done = do_in_path(path, name, flags, callback, cookie);
  }

  if ((done == FAIL || (flags & DIP_ALL)) && (flags & DIP_START)) {
    char *start_dir = "pack/*/start/*/%s";  // NOLINT
    size_t len = STRLEN(start_dir) + STRLEN(name);
    char_u *s = xmallocz(len);

    vim_snprintf((char *)s, len, start_dir, name);
    done = do_in_path(p_pp, s, flags, callback, cookie);

    xfree(s);
  }

  if ((done == FAIL || (flags & DIP_ALL)) && (flags & DIP_OPT)) {
    char *opt_dir = "pack/*/opt/*/%s";  // NOLINT
    size_t len = STRLEN(opt_dir) + STRLEN(name);
    char_u *s = xmallocz(len);

    vim_snprintf((char *)s, len, opt_dir, name);
    done = do_in_path(p_pp, s, flags, callback, cookie);

    xfree(s);
  }

  return done;
}

/// Just like do_in_path_and_pp(), using 'runtimepath' for "path".
int do_in_runtimepath(char_u *name, int flags, DoInRuntimepathCB callback,
                      void *cookie)
{
  return do_in_path_and_pp(p_rtp, name, flags, callback, cookie);
}

/// Source the file "name" from all directories in 'runtimepath'.
/// "name" can contain wildcards.
/// When "flags" has DIP_ALL: source all files, otherwise only the first one.
///
/// return FAIL when no file could be sourced, OK otherwise.
int source_runtime(char_u *name, int flags)
{
  return source_in_path(p_rtp, name, flags);
}

/// Just like source_runtime(), but use "path" instead of 'runtimepath'.
int source_in_path(char_u *path, char_u *name, int flags)
{
  return do_in_path_and_pp(path, name, flags, source_callback, NULL);
}

// Expand wildcards in "pat" and invoke do_source() for each match.
static void source_all_matches(char_u *pat)
{
  int num_files;
  char_u **files;

  if (gen_expand_wildcards(1, &pat, &num_files, &files, EW_FILE) == OK) {
    for (int i = 0; i < num_files; i++) {
      (void)do_source(files[i], false, DOSO_NONE);
    }
    FreeWild(num_files, files);
  }
}

/// Add the package directory to 'runtimepath'
static int add_pack_dir_to_rtp(char_u *fname)
{
  char_u *p4, *p3, *p2, *p1, *p;
  char_u *buf = NULL;
  char *afterdir = NULL;
  int retval = FAIL;

  p4 = p3 = p2 = p1 = get_past_head(fname);
  for (p = p1; *p; MB_PTR_ADV(p)) {
    if (vim_ispathsep_nocolon(*p)) {
      p4 = p3; p3 = p2; p2 = p1; p1 = p;
    }
  }

  // now we have:
  // rtp/pack/name/start/name
  //    p4   p3   p2   p1
  //
  // find the part up to "pack" in 'runtimepath'
  p4++;  // append pathsep in order to expand symlink
  char_u c = *p4;
  *p4 = NUL;
  char *const ffname = fix_fname((char *)fname);
  *p4 = c;

  if (ffname == NULL) {
    return FAIL;
  }

  // Find "ffname" in "p_rtp", ignoring '/' vs '\' differences
  // Also stop at the first "after" directory
  size_t fname_len = strlen(ffname);
  buf = try_malloc(MAXPATHL);
  if (buf == NULL) {
    goto theend;
  }
  const char *insp = NULL;
  const char *after_insp = NULL;
  for (const char *entry = (const char *)p_rtp; *entry != NUL; ) {
    const char *cur_entry = entry;

    copy_option_part((char_u **)&entry, buf, MAXPATHL, ",");
    if (insp == NULL) {
      add_pathsep((char *)buf);
      char *const rtp_ffname = fix_fname((char *)buf);
      if (rtp_ffname == NULL) {
        goto theend;
      }
      bool match = path_fnamencmp(rtp_ffname, ffname, fname_len) == 0;
      xfree(rtp_ffname);
      if (match) {
        // Insert "ffname" after this entry (and comma).
        insp = entry;
      }
    }

    if ((p = (char_u *)strstr((char *)buf, "after")) != NULL
        && p > buf
        && vim_ispathsep(p[-1])
        && (vim_ispathsep(p[5]) || p[5] == NUL || p[5] == ',')) {
      if (insp == NULL) {
        // Did not find "ffname" before the first "after" directory,
        // insert it before this entry.
        insp = cur_entry;
      }
      after_insp = cur_entry;
      break;
    }
  }

  if (insp == NULL) {
    // Both "fname" and "after" not found, append at the end.
    insp = (const char *)p_rtp + STRLEN(p_rtp);
  }

  // check if rtp/pack/name/start/name/after exists
  afterdir = concat_fnames((char *)fname, "after", true);
  size_t afterlen = 0;
  if (os_isdir((char_u *)afterdir)) {
    afterlen = strlen(afterdir) + 1;  // add one for comma
  }

  const size_t oldlen = STRLEN(p_rtp);
  const size_t addlen = STRLEN(fname) + 1;  // add one for comma
  const size_t new_rtp_capacity = oldlen + addlen + afterlen + 1;
  // add one for NUL ------------------------------------------^
  char *const new_rtp = try_malloc(new_rtp_capacity);
  if (new_rtp == NULL) {
    goto theend;
  }

  // We now have 'rtp' parts: {keep}{keep_after}{rest}.
  // Create new_rtp, first: {keep},{fname}
  size_t keep = (size_t)(insp - (const char *)p_rtp);
  memmove(new_rtp, p_rtp, keep);
  size_t new_rtp_len = keep;
  if (*insp == NUL) {
    new_rtp[new_rtp_len++] = ',';  // add comma before
  }
  memmove(new_rtp + new_rtp_len, fname, addlen - 1);
  new_rtp_len += addlen - 1;
  if (*insp != NUL) {
    new_rtp[new_rtp_len++] = ',';  // add comma after
  }

  if (afterlen > 0 && after_insp != NULL) {
    size_t keep_after = (size_t)(after_insp - (const char *)p_rtp);

    // Add to new_rtp: {keep},{fname}{keep_after},{afterdir}
    memmove(new_rtp + new_rtp_len, p_rtp + keep, keep_after - keep);
    new_rtp_len += keep_after - keep;
    memmove(new_rtp + new_rtp_len, afterdir, afterlen - 1);
    new_rtp_len += afterlen - 1;
    new_rtp[new_rtp_len++] = ',';
    keep = keep_after;
  }

  if (p_rtp[keep] != NUL) {
    // Append rest: {keep},{fname}{keep_after},{afterdir}{rest}
    memmove(new_rtp + new_rtp_len, p_rtp + keep, oldlen - keep + 1);
  } else {
    new_rtp[new_rtp_len] = NUL;
  }

  if (afterlen > 0 && after_insp == NULL) {
    // Append afterdir when "after" was not found:
    // {keep},{fname}{rest},{afterdir}
    xstrlcat(new_rtp, ",", new_rtp_capacity);
    xstrlcat(new_rtp, afterdir, new_rtp_capacity);
  }

  set_option_value("rtp", 0L, new_rtp, 0);
  xfree(new_rtp);
  retval = OK;

theend:
  xfree(buf);
  xfree(ffname);
  xfree(afterdir);
  return retval;
}

/// Load scripts in "plugin" and "ftdetect" directories of the package.
static int load_pack_plugin(char_u *fname)
{
  static const char *plugpat = "%s/plugin/**/*.vim";  // NOLINT
  static const char *ftpat = "%s/ftdetect/*.vim";  // NOLINT

  int retval = FAIL;
  char *const ffname = fix_fname((char *)fname);
  size_t len = strlen(ffname) + STRLEN(ftpat);
  char_u *pat = try_malloc(len + 1);
  if (pat == NULL) {
    goto theend;
  }
  vim_snprintf((char *)pat, len, plugpat, ffname);
  source_all_matches(pat);

  char_u *cmd = vim_strsave((char_u *)"g:did_load_filetypes");

  // If runtime/filetype.vim wasn't loaded yet, the scripts will be
  // found when it loads.
  if (eval_to_number(cmd) > 0) {
    do_cmdline_cmd("augroup filetypedetect");
    vim_snprintf((char *)pat, len, ftpat, ffname);
    source_all_matches(pat);
    do_cmdline_cmd("augroup END");
  }
  xfree(cmd);
  xfree(pat);
  retval = OK;

theend:
  xfree(ffname);

  return retval;
}

// used for "cookie" of add_pack_plugin()
static int APP_ADD_DIR;
static int APP_LOAD;
static int APP_BOTH;

static void add_pack_plugin(char_u *fname, void *cookie)
{
  if (cookie != &APP_LOAD) {
    char *buf = xmalloc(MAXPATHL);
    bool found = false;

    const char *p = (const char *)p_rtp;
    while (*p != NUL) {
      copy_option_part((char_u **)&p, (char_u *)buf, MAXPATHL, ",");
      if (path_fnamecmp(buf, (char *)fname) == 0) {
        found = true;
        break;
      }
    }
    xfree(buf);
    if (!found) {
      // directory is not yet in 'runtimepath', add it
      if (add_pack_dir_to_rtp(fname) == FAIL) {
        return;
      }
    }
  }

  if (cookie != &APP_ADD_DIR) {
    load_pack_plugin(fname);
  }
}

/// Add all packages in the "start" directory to 'runtimepath'.
void add_pack_start_dirs(void)
{
  do_in_path(p_pp, (char_u *)"pack/*/start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_pack_plugin, &APP_ADD_DIR);
}

/// Load plugins from all packages in the "start" directory.
void load_start_packages(void)
{
  did_source_packages = true;
  do_in_path(p_pp, (char_u *)"pack/*/start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_pack_plugin, &APP_LOAD);
}

// ":packloadall"
// Find plugins in the package directories and source them.
void ex_packloadall(exarg_T *eap)
{
  if (!did_source_packages || eap->forceit) {
    // First do a round to add all directories to 'runtimepath', then load
    // the plugins. This allows for plugins to use an autoload directory
    // of another plugin.
    add_pack_start_dirs();
    load_start_packages();
  }
}

/// ":packadd[!] {name}"
void ex_packadd(exarg_T *eap)
{
  static const char *plugpat = "pack/*/%s/%s";    // NOLINT
  int res = OK;

  // Round 1: use "start", round 2: use "opt".
  for (int round = 1; round <= 2; round++) {
    // Only look under "start" when loading packages wasn't done yet.
    if (round == 1 && did_source_packages) {
      continue;
    }

    const size_t len = STRLEN(plugpat) + STRLEN(eap->arg) + 5;
    char *pat = xmallocz(len);
    vim_snprintf(pat, len, plugpat, round == 1 ? "start" : "opt", eap->arg);
    // The first round don't give a "not found" error, in the second round
    // only when nothing was found in the first round.
    res = do_in_path(p_pp, (char_u *)pat,
                     DIP_ALL + DIP_DIR
                     + (round == 2 && res == FAIL ? DIP_ERR : 0),
                     add_pack_plugin, eap->forceit ? &APP_ADD_DIR : &APP_BOTH);
    xfree(pat);
  }
}

/// ":options"
void ex_options(exarg_T *eap)
{
  vim_setenv("OPTWIN_CMD", cmdmod.tab ? "tab" : "");
  cmd_source((char_u *)SYS_OPTWIN_FILE, NULL);
}

// Detect Python 3 or 2, and initialize 'pyxversion'.
void init_pyxversion(void)
{
  if (p_pyx == 0) {
    if (!eval_has_provider("python3")) {
      p_pyx = 3;
    } else if (!eval_has_provider("python")) {
      p_pyx = 2;
    }
  }
}

// Does a file contain one of the following strings at the beginning of any
// line?
// "#!(any string)python2"  => returns 2
// "#!(any string)python3"  => returns 3
// "# requires python 2.x"  => returns 2
// "# requires python 3.x"  => returns 3
// otherwise return 0.
static int requires_py_version(char_u *filename)
{
  FILE      *file;
  int       requires_py_version = 0;
  int       i, lines;

  lines = (int)p_mls;
  if (lines < 0) {
    lines = 5;
  }

  file = mch_fopen((char *)filename, "r");
  if (file != NULL) {
    for (i = 0; i < lines; i++) {
      if (vim_fgets(IObuff, IOSIZE, file)) {
        break;
      }
      if (i == 0 && IObuff[0] == '#' && IObuff[1] == '!') {
        // Check shebang.
        if (strstr((char *)IObuff + 2, "python2") != NULL) {
          requires_py_version = 2;
          break;
        }
        if (strstr((char *)IObuff + 2, "python3") != NULL) {
          requires_py_version = 3;
          break;
        }
      }
      IObuff[21] = '\0';
      if (STRCMP("# requires python 2.x", IObuff) == 0) {
        requires_py_version = 2;
        break;
      }
      if (STRCMP("# requires python 3.x", IObuff) == 0) {
        requires_py_version = 3;
        break;
      }
    }
    fclose(file);
  }
  return requires_py_version;
}


// Source a python file using the requested python version.
static void source_pyx_file(exarg_T *eap, char_u *fname)
{
  exarg_T ex;
  long int v = requires_py_version(fname);

  init_pyxversion();
  if (v == 0) {
    // user didn't choose a preference, 'pyx' is used
    v = p_pyx;
  }

  // now source, if required python version is not supported show
  // unobtrusive message.
  if (eap == NULL) {
    memset(&ex, 0, sizeof(ex));
  } else {
    ex = *eap;
  }
  ex.arg = fname;
  ex.cmd = (char_u *)(v == 2 ? "pyfile" : "pyfile3");

  if (v == 2) {
    ex_pyfile(&ex);
  } else {
    ex_py3file(&ex);
  }
}

// ":pyxfile {fname}"
void ex_pyxfile(exarg_T *eap)
{
  source_pyx_file(eap, eap->arg);
}

// ":pyx"
void ex_pyx(exarg_T *eap)
{
  init_pyxversion();
  if (p_pyx == 2) {
    ex_python(eap);
  } else {
    ex_python3(eap);
  }
}

// ":pyxdo"
void ex_pyxdo(exarg_T *eap)
{
  init_pyxversion();
  if (p_pyx == 2) {
    ex_pydo(eap);
  } else {
    ex_pydo3(eap);
  }
}

/// ":source {fname}"
void ex_source(exarg_T *eap)
{
  cmd_source(eap->arg, eap);
}

static void cmd_source(char_u *fname, exarg_T *eap)
{
  if (*fname == NUL) {
    EMSG(_(e_argreq));
  } else if (eap != NULL && eap->forceit) {
    // ":source!": read Normal mode commands
    // Need to execute the commands directly.  This is required at least
    // for:
    // - ":g" command busy
    // - after ":argdo", ":windo" or ":bufdo"
    // - another command follows
    // - inside a loop
    openscript(fname, global_busy || listcmd_busy || eap->nextcmd != NULL
               || eap->cstack->cs_idx >= 0);

    // ":source" read ex commands
  } else if (do_source(fname, false, DOSO_NONE) == FAIL) {
    EMSG2(_(e_notopen), fname);
  }
}

/// ":source" and associated commands.
///
/// @return address holding the next breakpoint line for a source cookie
linenr_T *source_breakpoint(void *cookie)
{
  return &((struct source_cookie *)cookie)->breakpoint;
}

/// Return the address holding the debug tick for a source cookie.
int *source_dbg_tick(void *cookie)
{
  return &((struct source_cookie *)cookie)->dbg_tick;
}

/// Return the nesting level for a source cookie.
int source_level(void *cookie)
{
  return ((struct source_cookie *)cookie)->level;
}

/// Special function to open a file without handle inheritance.
/// If possible the handle is closed on exec().
static FILE *fopen_noinh_readbin(char *filename)
{
#ifdef WIN32
  int fd_tmp = os_open(filename, O_RDONLY | O_BINARY | O_NOINHERIT, 0);
#else
  int fd_tmp = os_open(filename, O_RDONLY, 0);
#endif

  if (fd_tmp < 0) {
    return NULL;
  }

  (void)os_set_cloexec(fd_tmp);

  return fdopen(fd_tmp, READBIN);
}


/// Read the file "fname" and execute its lines as EX commands.
///
/// This function may be called recursively!
///
/// @param fname
/// @param check_other  check for .vimrc and _vimrc
/// @param is_vimrc     DOSO_ value
///
/// @return FAIL if file could not be opened, OK otherwise
int do_source(char_u *fname, int check_other, int is_vimrc)
{
  struct source_cookie cookie;
  char_u                  *save_sourcing_name;
  linenr_T save_sourcing_lnum;
  char_u                  *p;
  char_u                  *fname_exp;
  char_u                  *firstline = NULL;
  int retval = FAIL;
  scid_T save_current_SID;
  static scid_T last_current_SID = 0;
  void                    *save_funccalp;
  int save_debug_break_level = debug_break_level;
  scriptitem_T            *si = NULL;
  proftime_T wait_start;

  p = expand_env_save(fname);
  if (p == NULL) {
    return retval;
  }
  fname_exp = (char_u *)fix_fname((char *)p);
  xfree(p);
  if (fname_exp == NULL) {
    return retval;
  }
  if (os_isdir(fname_exp)) {
    smsg(_("Cannot source a directory: \"%s\""), fname);
    goto theend;
  }

  // Apply SourceCmd autocommands, they should get the file and source it.
  if (has_autocmd(EVENT_SOURCECMD, fname_exp, NULL)
      && apply_autocmds(EVENT_SOURCECMD, fname_exp, fname_exp,
                        false, curbuf)) {
    retval = aborting() ? FAIL : OK;
    goto theend;
  }

  // Apply SourcePre autocommands, they may get the file.
  apply_autocmds(EVENT_SOURCEPRE, fname_exp, fname_exp, false, curbuf);

  cookie.fp = fopen_noinh_readbin((char *)fname_exp);
  if (cookie.fp == NULL && check_other) {
    // Try again, replacing file name ".vimrc" by "_vimrc" or vice versa,
    // and ".exrc" by "_exrc" or vice versa.
    p = path_tail(fname_exp);
    if ((*p == '.' || *p == '_')
        && (STRICMP(p + 1, "nvimrc") == 0 || STRICMP(p + 1, "exrc") == 0)) {
      *p = (*p == '_') ? '.' : '_';
      cookie.fp = fopen_noinh_readbin((char *)fname_exp);
    }
  }

  if (cookie.fp == NULL) {
    if (p_verbose > 0) {
      verbose_enter();
      if (sourcing_name == NULL) {
        smsg(_("could not source \"%s\""), fname);
      } else {
        smsg(_("line %" PRId64 ": could not source \"%s\""),
             (int64_t)sourcing_lnum, fname);
      }
      verbose_leave();
    }
    goto theend;
  }

  // The file exists.
  // - In verbose mode, give a message.
  // - For a vimrc file, may want to call vimrc_found().
  if (p_verbose > 1) {
    verbose_enter();
    if (sourcing_name == NULL) {
      smsg(_("sourcing \"%s\""), fname);
    } else {
      smsg(_("line %" PRId64 ": sourcing \"%s\""),
           (int64_t)sourcing_lnum, fname);
    }
    verbose_leave();
  }
  if (is_vimrc == DOSO_VIMRC) {
    vimrc_found(fname_exp, (char_u *)"MYVIMRC");
  } else if (is_vimrc == DOSO_GVIMRC) {
    vimrc_found(fname_exp, (char_u *)"MYGVIMRC");
  }

#ifdef USE_CRNL
  // If no automatic file format: Set default to CR-NL.
  if (*p_ffs == NUL) {
    cookie.fileformat = EOL_DOS;
  } else {
    cookie.fileformat = EOL_UNKNOWN;
  }
  cookie.error = false;
#endif

  cookie.nextline = NULL;
  cookie.finished = false;

  // Check if this script has a breakpoint.
  cookie.breakpoint = dbg_find_breakpoint(true, fname_exp, (linenr_T)0);
  cookie.fname = fname_exp;
  cookie.dbg_tick = debug_tick;

  cookie.level = ex_nesting_level;

  // Keep the sourcing name/lnum, for recursive calls.
  save_sourcing_name = sourcing_name;
  sourcing_name = fname_exp;
  save_sourcing_lnum = sourcing_lnum;
  sourcing_lnum = 0;

  // start measuring script load time if --startuptime was passed and
  // time_fd was successfully opened afterwards.
  proftime_T rel_time;
  proftime_T start_time;
  FILE * const l_time_fd = time_fd;
  if (l_time_fd != NULL) {
    time_push(&rel_time, &start_time);
  }

  const int l_do_profiling = do_profiling;
  if (l_do_profiling == PROF_YES) {
    prof_child_enter(&wait_start);    // entering a child now
  }

  // Don't use local function variables, if called from a function.
  // Also starts profiling timer for nested script.
  save_funccalp = save_funccal();

  // Check if this script was sourced before to finds its SID.
  // If it's new, generate a new SID.
  save_current_SID = current_SID;
  FileID file_id;
  bool file_id_ok = os_fileid((char *)fname_exp, &file_id);
  assert(script_items.ga_len >= 0);
  for (current_SID = script_items.ga_len; current_SID > 0; current_SID--) {
    si = &SCRIPT_ITEM(current_SID);
    // Compare dev/ino when possible, it catches symbolic links.
    // Also compare file names, the inode may change when the file was edited.
    bool file_id_equal = file_id_ok && si->file_id_valid
                         && os_fileid_equal(&(si->file_id), &file_id);
    if (si->sn_name != NULL
        && (file_id_equal || fnamecmp(si->sn_name, fname_exp) == 0)) {
      break;
    }
  }
  if (current_SID == 0) {
    current_SID = ++last_current_SID;
    ga_grow(&script_items, (int)(current_SID - script_items.ga_len));
    while (script_items.ga_len < current_SID) {
      script_items.ga_len++;
      SCRIPT_ITEM(script_items.ga_len).sn_name = NULL;
      SCRIPT_ITEM(script_items.ga_len).sn_prof_on = false;
    }
    si = &SCRIPT_ITEM(current_SID);
    si->sn_name = fname_exp;
    fname_exp = NULL;
    if (file_id_ok) {
      si->file_id_valid = true;
      si->file_id = file_id;
    } else {
      si->file_id_valid = false;
    }

    // Allocate the local script variables to use for this script.
    new_script_vars(current_SID);
  }

  if (l_do_profiling == PROF_YES) {
    bool forceit;

    // Check if we do profiling for this script.
    if (!si->sn_prof_on && has_profiling(true, si->sn_name, &forceit)) {
      profile_init(si);
      si->sn_pr_force = forceit;
    }
    if (si->sn_prof_on) {
      si->sn_pr_count++;
      si->sn_pr_start = profile_start();
      si->sn_pr_children = profile_zero();
    }
  }

  cookie.conv.vc_type = CONV_NONE;              // no conversion

  // Read the first line so we can check for a UTF-8 BOM.
  firstline = getsourceline(0, (void *)&cookie, 0);
  if (firstline != NULL && STRLEN(firstline) >= 3 && firstline[0] == 0xef
      && firstline[1] == 0xbb && firstline[2] == 0xbf) {
    // Found BOM; setup conversion, skip over BOM and recode the line.
    convert_setup(&cookie.conv, (char_u *)"utf-8", p_enc);
    p = string_convert(&cookie.conv, firstline + 3, NULL);
    if (p == NULL) {
      p = vim_strsave(firstline + 3);
    }
    xfree(firstline);
    firstline = p;
  }

  // Call do_cmdline, which will call getsourceline() to get the lines.
  do_cmdline(firstline, getsourceline, (void *)&cookie,
             DOCMD_VERBOSE|DOCMD_NOWAIT|DOCMD_REPEAT);
  retval = OK;

  if (l_do_profiling == PROF_YES) {
    // Get "si" again, "script_items" may have been reallocated.
    si = &SCRIPT_ITEM(current_SID);
    if (si->sn_prof_on) {
      si->sn_pr_start = profile_end(si->sn_pr_start);
      si->sn_pr_start = profile_sub_wait(wait_start, si->sn_pr_start);
      si->sn_pr_total = profile_add(si->sn_pr_total, si->sn_pr_start);
      si->sn_pr_self = profile_self(si->sn_pr_self, si->sn_pr_start,
                                    si->sn_pr_children);
    }
  }

  if (got_int) {
    EMSG(_(e_interr));
  }
  sourcing_name = save_sourcing_name;
  sourcing_lnum = save_sourcing_lnum;
  if (p_verbose > 1) {
    verbose_enter();
    smsg(_("finished sourcing %s"), fname);
    if (sourcing_name != NULL) {
      smsg(_("continuing in %s"), sourcing_name);
    }
    verbose_leave();
  }

  if (l_time_fd != NULL) {
    vim_snprintf((char *)IObuff, IOSIZE, "sourcing %s", fname);
    time_msg((char *)IObuff, &start_time);
    time_pop(rel_time);
  }

  // After a "finish" in debug mode, need to break at first command of next
  // sourced file.
  if (save_debug_break_level > ex_nesting_level
      && debug_break_level == ex_nesting_level) {
    debug_break_level++;
  }

  current_SID = save_current_SID;
  restore_funccal(save_funccalp);
  if (l_do_profiling == PROF_YES) {
    prof_child_exit(&wait_start);    // leaving a child now
  }
  fclose(cookie.fp);
  xfree(cookie.nextline);
  xfree(firstline);
  convert_setup(&cookie.conv, NULL, NULL);

theend:
  xfree(fname_exp);
  return retval;
}


/// ":scriptnames"
void ex_scriptnames(exarg_T *eap)
{
  if (eap->addr_count > 0) {
    // :script {scriptId}: edit the script
    if (eap->line2 < 1 || eap->line2 > script_items.ga_len) {
      EMSG(_(e_invarg));
    } else {
      eap->arg = SCRIPT_ITEM(eap->line2).sn_name;
      do_exedit(eap, NULL);
    }
    return;
  }

  for (int i = 1; i <= script_items.ga_len && !got_int; i++) {
    if (SCRIPT_ITEM(i).sn_name != NULL) {
      home_replace(NULL, SCRIPT_ITEM(i).sn_name,
                   NameBuff, MAXPATHL, true);
      smsg("%3d: %s", i, NameBuff);
    }
  }
}

# if defined(BACKSLASH_IN_FILENAME)
/// Fix slashes in the list of script names for 'shellslash'.
void scriptnames_slash_adjust(void)
{
  for (int i = 1; i <= script_items.ga_len; i++) {
    if (SCRIPT_ITEM(i).sn_name != NULL) {
      slash_adjust(SCRIPT_ITEM(i).sn_name);
    }
  }
}

# endif

/// Get a pointer to a script name.  Used for ":verbose set".
char_u *get_scriptname(LastSet last_set, bool *should_free)
{
  *should_free = false;

  switch (last_set.script_id) {
    case SID_MODELINE:
      return (char_u *)_("modeline");
    case SID_CMDARG:
      return (char_u *)_("--cmd argument");
    case SID_CARG:
      return (char_u *)_("-c argument");
    case SID_ENV:
      return (char_u *)_("environment variable");
    case SID_ERROR:
      return (char_u *)_("error handler");
    case SID_LUA:
      return (char_u *)_("Lua");
    case SID_API_CLIENT:
      vim_snprintf((char *)IObuff, IOSIZE,
                   _("API client (channel id %" PRIu64 ")"),
                   last_set.channel_id);
      return IObuff;
    default:
      *should_free = true;
      return home_replace_save(NULL, SCRIPT_ITEM(last_set.script_id).sn_name);
  }
}

# if defined(EXITFREE)
void free_scriptnames(void)
{
  profile_reset();

# define FREE_SCRIPTNAME(item) xfree((item)->sn_name)
  GA_DEEP_CLEAR(&script_items, scriptitem_T, FREE_SCRIPTNAME);
}
# endif


/// Get one full line from a sourced file.
/// Called by do_cmdline() when it's called from do_source().
///
/// @return pointer to the line in allocated memory, or NULL for end-of-file or
///         some error.
char_u *getsourceline(int c, void *cookie, int indent)
{
  struct source_cookie *sp = (struct source_cookie *)cookie;
  char_u *line;
  char_u *p;

  // If breakpoints have been added/deleted need to check for it.
  if (sp->dbg_tick < debug_tick) {
    sp->breakpoint = dbg_find_breakpoint(true, sp->fname, sourcing_lnum);
    sp->dbg_tick = debug_tick;
  }
  if (do_profiling == PROF_YES) {
    script_line_end();
  }
  // Get current line.  If there is a read-ahead line, use it, otherwise get
  // one now.
  if (sp->finished) {
    line = NULL;
  } else if (sp->nextline == NULL) {
    line = get_one_sourceline(sp);
  } else {
    line = sp->nextline;
    sp->nextline = NULL;
    sourcing_lnum++;
  }
  if (line != NULL && do_profiling == PROF_YES) {
    script_line_start();
  }

  // Only concatenate lines starting with a \ when 'cpoptions' doesn't
  // contain the 'C' flag.
  if (line != NULL && (vim_strchr(p_cpo, CPO_CONCAT) == NULL)) {
    // compensate for the one line read-ahead
    sourcing_lnum--;

    // Get the next line and concatenate it when it starts with a
    // backslash. We always need to read the next line, keep it in
    // sp->nextline.
    sp->nextline = get_one_sourceline(sp);
    if (sp->nextline != NULL && *(p = skipwhite(sp->nextline)) == '\\') {
      garray_T ga;

      ga_init(&ga, (int)sizeof(char_u), 400);
      ga_concat(&ga, line);
      ga_concat(&ga, p + 1);
      for (;; ) {
        xfree(sp->nextline);
        sp->nextline = get_one_sourceline(sp);
        if (sp->nextline == NULL) {
          break;
        }
        p = skipwhite(sp->nextline);
        if (*p != '\\') {
          break;
        }
        // Adjust the growsize to the current length to speed up
        // concatenating many lines.
        if (ga.ga_len > 400) {
          ga_set_growsize(&ga, (ga.ga_len > 8000) ? 8000 : ga.ga_len);
        }
        ga_concat(&ga, p + 1);
      }
      ga_append(&ga, NUL);
      xfree(line);
      line = ga.ga_data;
    }
  }

  if (line != NULL && sp->conv.vc_type != CONV_NONE) {
    char_u  *s;

    // Convert the encoding of the script line.
    s = string_convert(&sp->conv, line, NULL);
    if (s != NULL) {
      xfree(line);
      line = s;
    }
  }

  // Did we encounter a breakpoint?
  if (sp->breakpoint != 0 && sp->breakpoint <= sourcing_lnum) {
    dbg_breakpoint(sp->fname, sourcing_lnum);
    // Find next breakpoint.
    sp->breakpoint = dbg_find_breakpoint(true, sp->fname, sourcing_lnum);
    sp->dbg_tick = debug_tick;
  }

  return line;
}

static char_u *get_one_sourceline(struct source_cookie *sp)
{
  garray_T ga;
  int len;
  int c;
  char_u              *buf;
#ifdef USE_CRNL
  int has_cr;                           // CR-LF found
#endif
  bool have_read = false;

  // use a growarray to store the sourced line
  ga_init(&ga, 1, 250);

  // Loop until there is a finished line (or end-of-file).
  sourcing_lnum++;
  for (;; ) {
    // make room to read at least 120 (more) characters
    ga_grow(&ga, 120);
    buf = (char_u *)ga.ga_data;

retry:
    errno = 0;
    if (fgets((char *)buf + ga.ga_len, ga.ga_maxlen - ga.ga_len,
              sp->fp) == NULL) {
      if (errno == EINTR) {
        goto retry;
      }

      break;
    }
    len = ga.ga_len + (int)STRLEN(buf + ga.ga_len);
#ifdef USE_CRNL
    // Ignore a trailing CTRL-Z, when in Dos mode. Only recognize the
    // CTRL-Z by its own, or after a NL.
    if ((len == 1 || (len >= 2 && buf[len - 2] == '\n'))
        && sp->fileformat == EOL_DOS
        && buf[len - 1] == Ctrl_Z) {
      buf[len - 1] = NUL;
      break;
    }
#endif

    have_read = true;
    ga.ga_len = len;

    // If the line was longer than the buffer, read more.
    if (ga.ga_maxlen - ga.ga_len == 1 && buf[len - 1] != '\n') {
      continue;
    }

    if (len >= 1 && buf[len - 1] == '\n') {     // remove trailing NL
#ifdef USE_CRNL
      has_cr = (len >= 2 && buf[len - 2] == '\r');
      if (sp->fileformat == EOL_UNKNOWN) {
        if (has_cr) {
          sp->fileformat = EOL_DOS;
        } else {
          sp->fileformat = EOL_UNIX;
        }
      }

      if (sp->fileformat == EOL_DOS) {
        if (has_cr) {               // replace trailing CR
          buf[len - 2] = '\n';
          len--;
          ga.ga_len--;
        } else {          // lines like ":map xx yy^M" will have failed
          if (!sp->error) {
            msg_source(HL_ATTR(HLF_W));
            EMSG(_("W15: Warning: Wrong line separator, ^M may be missing"));
          }
          sp->error = true;
          sp->fileformat = EOL_UNIX;
        }
      }
#endif
      // The '\n' is escaped if there is an odd number of ^V's just
      // before it, first set "c" just before the 'V's and then check
      // len&c parities (is faster than ((len-c)%2 == 0)) -- Acevedo
      for (c = len - 2; c >= 0 && buf[c] == Ctrl_V; c--) {}
      if ((len & 1) != (c & 1)) {       // escaped NL, read more
        sourcing_lnum++;
        continue;
      }

      buf[len - 1] = NUL;               // remove the NL
    }

    // Check for ^C here now and then, so recursive :so can be broken.
    line_breakcheck();
    break;
  }

  if (have_read) {
    return (char_u *)ga.ga_data;
  }

  xfree(ga.ga_data);
  return NULL;
}

/// Called when starting to read a script line.
/// "sourcing_lnum" must be correct!
/// When skipping lines it may not actually be executed, but we won't find out
/// until later and we need to store the time now.
void script_line_start(void)
{
  scriptitem_T    *si;
  sn_prl_T        *pp;

  if (current_SID <= 0 || current_SID > script_items.ga_len) {
    return;
  }
  si = &SCRIPT_ITEM(current_SID);
  if (si->sn_prof_on && sourcing_lnum >= 1) {
    // Grow the array before starting the timer, so that the time spent
    // here isn't counted.
    (void)ga_grow(&si->sn_prl_ga,
                  (int)(sourcing_lnum - si->sn_prl_ga.ga_len));
    si->sn_prl_idx = sourcing_lnum - 1;
    while (si->sn_prl_ga.ga_len <= si->sn_prl_idx
           && si->sn_prl_ga.ga_len < si->sn_prl_ga.ga_maxlen) {
      // Zero counters for a line that was not used before.
      pp = &PRL_ITEM(si, si->sn_prl_ga.ga_len);
      pp->snp_count = 0;
      pp->sn_prl_total = profile_zero();
      pp->sn_prl_self = profile_zero();
      si->sn_prl_ga.ga_len++;
    }
    si->sn_prl_execed = false;
    si->sn_prl_start = profile_start();
    si->sn_prl_children = profile_zero();
    si->sn_prl_wait = profile_get_wait();
  }
}

/// Called when actually executing a function line.
void script_line_exec(void)
{
  scriptitem_T    *si;

  if (current_SID <= 0 || current_SID > script_items.ga_len) {
    return;
  }
  si = &SCRIPT_ITEM(current_SID);
  if (si->sn_prof_on && si->sn_prl_idx >= 0) {
    si->sn_prl_execed = true;
  }
}

/// Called when done with a function line.
void script_line_end(void)
{
  scriptitem_T    *si;
  sn_prl_T        *pp;

  if (current_SID <= 0 || current_SID > script_items.ga_len) {
    return;
  }
  si = &SCRIPT_ITEM(current_SID);
  if (si->sn_prof_on && si->sn_prl_idx >= 0
      && si->sn_prl_idx < si->sn_prl_ga.ga_len) {
    if (si->sn_prl_execed) {
      pp = &PRL_ITEM(si, si->sn_prl_idx);
      pp->snp_count++;
      si->sn_prl_start = profile_end(si->sn_prl_start);
      si->sn_prl_start = profile_sub_wait(si->sn_prl_wait, si->sn_prl_start);
      pp->sn_prl_total = profile_add(pp->sn_prl_total, si->sn_prl_start);
      pp->sn_prl_self = profile_self(pp->sn_prl_self, si->sn_prl_start,
                                     si->sn_prl_children);
    }
    si->sn_prl_idx = -1;
  }
}

/// ":scriptencoding": Set encoding conversion for a sourced script.
/// Without the multi-byte feature it's simply ignored.
void ex_scriptencoding(exarg_T *eap)
{
  struct source_cookie        *sp;
  char_u                      *name;

  if (!getline_equal(eap->getline, eap->cookie, getsourceline)) {
    EMSG(_("E167: :scriptencoding used outside of a sourced file"));
    return;
  }

  if (*eap->arg != NUL) {
    name = enc_canonize(eap->arg);
  } else {
    name = eap->arg;
  }

  // Setup for conversion from the specified encoding to 'encoding'.
  sp = (struct source_cookie *)getline_cookie(eap->getline, eap->cookie);
  convert_setup(&sp->conv, name, p_enc);

  if (name != eap->arg) {
    xfree(name);
  }
}

/// ":finish": Mark a sourced file as finished.
void ex_finish(exarg_T *eap)
{
  if (getline_equal(eap->getline, eap->cookie, getsourceline)) {
    do_finish(eap, false);
  } else {
    EMSG(_("E168: :finish used outside of a sourced file"));
  }
}

/// Mark a sourced file as finished.  Possibly makes the ":finish" pending.
/// Also called for a pending finish at the ":endtry" or after returning from
/// an extra do_cmdline().  "reanimate" is used in the latter case.
void do_finish(exarg_T *eap, int reanimate)
{
  int idx;

  if (reanimate) {
    ((struct source_cookie *)getline_cookie(eap->getline,
                                            eap->cookie))->finished = false;
  }

  // Cleanup (and inactivate) conditionals, but stop when a try conditional
  // not in its finally clause (which then is to be executed next) is found.
  // In this case, make the ":finish" pending for execution at the ":endtry".
  // Otherwise, finish normally.
  idx = cleanup_conditionals(eap->cstack, 0, true);
  if (idx >= 0) {
    eap->cstack->cs_pending[idx] = CSTP_FINISH;
    report_make_pending(CSTP_FINISH, NULL);
  } else {
    ((struct source_cookie *)getline_cookie(eap->getline,
                                            eap->cookie))->finished = true;
  }
}


/// Return true when a sourced file had the ":finish" command: Don't give error
/// message for missing ":endif".
/// Return false when not sourcing a file.
bool source_finished(LineGetter fgetline, void *cookie)
{
  return getline_equal(fgetline, cookie, getsourceline)
         && ((struct source_cookie *)getline_cookie(
             fgetline, cookie))->finished;
}

/// ":checktime [buffer]"
void ex_checktime(exarg_T *eap)
{
  buf_T       *buf;
  int save_no_check_timestamps = no_check_timestamps;

  no_check_timestamps = 0;
  if (eap->addr_count == 0) {    // default is all buffers
    check_timestamps(false);
  } else {
    buf = buflist_findnr((int)eap->line2);
    if (buf != NULL) {           // cannot happen?
      (void)buf_check_timestamp(buf, false);
    }
  }
  no_check_timestamps = save_no_check_timestamps;
}

#if defined(HAVE_LOCALE_H)
# define HAVE_GET_LOCALE_VAL

static char *get_locale_val(int what)
{
  // Obtain the locale value from the libraries.
  char *loc = setlocale(what, NULL);

  return loc;
}
#endif

// Return true when "lang" starts with a valid language name.
// Rejects NULL, empty string, "C", "C.UTF-8" and others.
static bool is_valid_mess_lang(char *lang)
{
  return lang != NULL && ASCII_ISALPHA(lang[0]) && ASCII_ISALPHA(lang[1]);
}

/// Obtain the current messages language.  Used to set the default for
/// 'helplang'.  May return NULL or an empty string.
char *get_mess_lang(void)
{
  char *p;

# ifdef HAVE_GET_LOCALE_VAL
#  if defined(LC_MESSAGES)
  p = get_locale_val(LC_MESSAGES);
#  else
  // This is necessary for Win32, where LC_MESSAGES is not defined and $LANG
  // may be set to the LCID number.  LC_COLLATE is the best guess, LC_TIME
  // and LC_MONETARY may be set differently for a Japanese working in the
  // US.
  p = get_locale_val(LC_COLLATE);
#  endif
# else
  p = os_getenv("LC_ALL");
  if (!is_valid_mess_lang(p)) {
    p = os_getenv("LC_MESSAGES");
    if (!is_valid_mess_lang(p)) {
      p = os_getenv("LANG");
    }
  }
# endif
  return is_valid_mess_lang(p) ? p : NULL;
}

// Complicated #if; matches with where get_mess_env() is used below.
#ifdef HAVE_WORKING_LIBINTL
/// Get the language used for messages from the environment.
static char_u *get_mess_env(void)
{
  char_u      *p;

  p = (char_u *)os_getenv("LC_ALL");
  if (p == NULL) {
    p = (char_u *)os_getenv("LC_MESSAGES");
    if (p == NULL) {
      p = (char_u *)os_getenv("LANG");
      if (p != NULL && ascii_isdigit(*p)) {
        p = NULL;                       // ignore something like "1043"
      }
# ifdef HAVE_GET_LOCALE_VAL
      if (p == NULL) {
        p = (char_u *)get_locale_val(LC_CTYPE);
      }
# endif
    }
  }
  return p;
}

#endif


/// Set the "v:lang" variable according to the current locale setting.
/// Also do "v:lc_time"and "v:ctype".
void set_lang_var(void)
{
  const char *loc;

# ifdef HAVE_GET_LOCALE_VAL
  loc = get_locale_val(LC_CTYPE);
# else
  // setlocale() not supported: use the default value
  loc = "C";
# endif
  set_vim_var_string(VV_CTYPE, loc, -1);

  // When LC_MESSAGES isn't defined use the value from $LC_MESSAGES, fall
  // back to LC_CTYPE if it's empty.
# ifdef HAVE_WORKING_LIBINTL
  loc = (char *)get_mess_env();
# elif defined(LC_MESSAGES)
  loc = get_locale_val(LC_MESSAGES);
# else
  // In Windows LC_MESSAGES is not defined fallback to LC_CTYPE
  loc = get_locale_val(LC_CTYPE);
# endif
  set_vim_var_string(VV_LANG, loc, -1);

# ifdef HAVE_GET_LOCALE_VAL
  loc = get_locale_val(LC_TIME);
# endif
  set_vim_var_string(VV_LC_TIME, loc, -1);
}

#ifdef HAVE_WORKING_LIBINTL
///
/// ":language":  Set the language (locale).
///
/// @param eap
///
void ex_language(exarg_T *eap)
{
  char        *loc;
  char_u      *p;
  char_u      *name;
  int what = LC_ALL;
  char        *whatstr = "";
#ifdef LC_MESSAGES
# define VIM_LC_MESSAGES LC_MESSAGES
#else
# define VIM_LC_MESSAGES 6789
#endif

  name = eap->arg;

  // Check for "messages {name}", "ctype {name}" or "time {name}" argument.
  // Allow abbreviation, but require at least 3 characters to avoid
  // confusion with a two letter language name "me" or "ct".
  p = skiptowhite(eap->arg);
  if ((*p == NUL || ascii_iswhite(*p)) && p - eap->arg >= 3) {
    if (STRNICMP(eap->arg, "messages", p - eap->arg) == 0) {
      what = VIM_LC_MESSAGES;
      name = skipwhite(p);
      whatstr = "messages ";
    } else if (STRNICMP(eap->arg, "ctype", p - eap->arg) == 0) {
      what = LC_CTYPE;
      name = skipwhite(p);
      whatstr = "ctype ";
    } else if (STRNICMP(eap->arg, "time", p - eap->arg) == 0) {
      what = LC_TIME;
      name = skipwhite(p);
      whatstr = "time ";
    }
  }

  if (*name == NUL) {
#ifdef HAVE_WORKING_LIBINTL
    if (what == VIM_LC_MESSAGES) {
      p = get_mess_env();
    } else {
#endif
      p = (char_u *)setlocale(what, NULL);
#ifdef HAVE_WORKING_LIBINTL
    }
#endif
    if (p == NULL || *p == NUL) {
      p = (char_u *)"Unknown";
    }
    smsg(_("Current %slanguage: \"%s\""), whatstr, p);
  } else {
#ifndef LC_MESSAGES
    if (what == VIM_LC_MESSAGES) {
      loc = "";
    } else {
#endif
      loc = setlocale(what, (char *)name);
#ifdef LC_NUMERIC
      // Make sure strtod() uses a decimal point, not a comma.
      setlocale(LC_NUMERIC, "C");
#endif
#ifndef LC_MESSAGES
    }
#endif
    if (loc == NULL) {
      EMSG2(_("E197: Cannot set language to \"%s\""), name);
    } else {
#ifdef HAVE_NL_MSG_CAT_CNTR
      // Need to do this for GNU gettext, otherwise cached translations
      // will be used again.
      extern int _nl_msg_cat_cntr;

      _nl_msg_cat_cntr++;
#endif
      // Reset $LC_ALL, otherwise it would overrule everything.
      vim_setenv("LC_ALL", "");

      if (what != LC_TIME) {
        // Tell gettext() what to translate to.  It apparently doesn't
        // use the currently effective locale.
        if (what == LC_ALL) {
          vim_setenv("LANG", (char *)name);

          // Clear $LANGUAGE because GNU gettext uses it.
          vim_setenv("LANGUAGE", "");
        }
        if (what != LC_CTYPE) {
          vim_setenv("LC_MESSAGES", (char *)name);
          set_helplang_default((char *)name);
        }
      }

      // Set v:lang, v:lc_time and v:ctype to the final result.
      set_lang_var();
      maketitle();
    }
  }
}


static char_u **locales = NULL;       // Array of all available locales

#ifndef WIN32
static bool did_init_locales = false;

/// Return an array of strings for all available locales + NULL for the
/// last element.  Return NULL in case of error.
static char_u **find_locales(void)
{
  garray_T locales_ga;
  char_u      *loc;
  char *saveptr = NULL;

  // Find all available locales by running command "locale -a".  If this
  // doesn't work we won't have completion.
  char_u *locale_a = get_cmd_output((char_u *)"locale -a", NULL,
                                    kShellOptSilent, NULL);
  if (locale_a == NULL) {
    return NULL;
  }
  ga_init(&locales_ga, sizeof(char_u *), 20);

  // Transform locale_a string where each locale is separated by "\n"
  // into an array of locale strings.
  loc = (char_u *)os_strtok((char *)locale_a, "\n", &saveptr);

  while (loc != NULL) {
    loc = vim_strsave(loc);
    GA_APPEND(char_u *, &locales_ga, loc);
    loc = (char_u *)os_strtok(NULL, "\n", &saveptr);
  }
  xfree(locale_a);
  // Guarantee that .ga_data is NULL terminated
  ga_grow(&locales_ga, 1);
  ((char_u **)locales_ga.ga_data)[locales_ga.ga_len] = NULL;
  return (char_u **)locales_ga.ga_data;
}
#endif

/// Lazy initialization of all available locales.
static void init_locales(void)
{
#ifndef WIN32
  if (!did_init_locales) {
    did_init_locales = true;
    locales = find_locales();
  }
#endif
}

#  if defined(EXITFREE)
void free_locales(void)
{
  int i;
  if (locales != NULL) {
    for (i = 0; locales[i] != NULL; i++) {
      xfree(locales[i]);
    }
    xfree(locales);
    locales = NULL;
  }
}

#  endif

/// Function given to ExpandGeneric() to obtain the possible arguments of the
/// ":language" command.
char_u *get_lang_arg(expand_T *xp, int idx)
{
  if (idx == 0) {
    return (char_u *)"messages";
  }
  if (idx == 1) {
    return (char_u *)"ctype";
  }
  if (idx == 2) {
    return (char_u *)"time";
  }

  init_locales();
  if (locales == NULL) {
    return NULL;
  }
  return locales[idx - 3];
}

/// Function given to ExpandGeneric() to obtain the available locales.
char_u *get_locales(expand_T *xp, int idx)
{
  init_locales();
  if (locales == NULL) {
    return NULL;
  }
  return locales[idx];
}

#endif


static void script_host_execute(char *name, exarg_T *eap)
{
  size_t len;
  char *const script = script_get(eap, &len);

  if (script != NULL) {
    list_T *const args = tv_list_alloc(3);
    // script
    tv_list_append_allocated_string(args, script);
    // current range
    tv_list_append_number(args, (int)eap->line1);
    tv_list_append_number(args, (int)eap->line2);

    (void)eval_call_provider(name, "execute", args);
  }
}

static void script_host_execute_file(char *name, exarg_T *eap)
{
  uint8_t buffer[MAXPATHL];
  vim_FullName((char *)eap->arg, (char *)buffer, sizeof(buffer), false);

  list_T *args = tv_list_alloc(3);
  // filename
  tv_list_append_string(args, (const char *)buffer, -1);
  // current range
  tv_list_append_number(args, (int)eap->line1);
  tv_list_append_number(args, (int)eap->line2);
  (void)eval_call_provider(name, "execute_file", args);
}

static void script_host_do_range(char *name, exarg_T *eap)
{
  list_T *args = tv_list_alloc(3);
  tv_list_append_number(args, (int)eap->line1);
  tv_list_append_number(args, (int)eap->line2);
  tv_list_append_string(args, (const char *)eap->arg, -1);
  (void)eval_call_provider(name, "do_range", args);
}

/// ":drop"
/// Opens the first argument in a window.  When there are two or more arguments
/// the argument list is redefined.
void ex_drop(exarg_T   *eap)
{
  bool split = false;
  buf_T *buf;

  // Check if the first argument is already being edited in a window.  If
  // so, jump to that window.
  // We would actually need to check all arguments, but that's complicated
  // and mostly only one file is dropped.
  // This also ignores wildcards, since it is very unlikely the user is
  // editing a file name with a wildcard character.
  do_arglist(eap->arg, AL_SET, 0);

  // Expanding wildcards may result in an empty argument list.  E.g. when
  // editing "foo.pyc" and ".pyc" is in 'wildignore'.  Assume that we
  // already did an error message for this.
  if (ARGCOUNT == 0) {
    return;
  }

  if (cmdmod.tab) {
    // ":tab drop file ...": open a tab for each argument that isn't
    // edited in a window yet.  It's like ":tab all" but without closing
    // windows or tabs.
    ex_all(eap);
  } else {
    // ":drop file ...": Edit the first argument.  Jump to an existing
    // window if possible, edit in current window if the current buffer
    // can be abandoned, otherwise open a new window.
    buf = buflist_findnr(ARGLIST[0].ae_fnum);

    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp->w_buffer == buf) {
        goto_tabpage_win(tp, wp);
        curwin->w_arg_idx = 0;
        return;
      }
    }

    // Check whether the current buffer is changed. If so, we will need
    // to split the current window or data could be lost.
    // Skip the check if the 'hidden' option is set, as in this case the
    // buffer won't be lost.
    if (!buf_hide(curbuf)) {
      emsg_off++;
      split = check_changed(curbuf, CCGD_AW | CCGD_EXCMD);
      emsg_off--;
    }

    // Fake a ":sfirst" or ":first" command edit the first argument.
    if (split) {
      eap->cmdidx = CMD_sfirst;
      eap->cmd[0] = 's';
    } else {
      eap->cmdidx = CMD_first;
    }
    ex_rewind(eap);
  }
}
