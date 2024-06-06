/// @file debugger.c
///
/// Vim script debugger functions

#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/debugger.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/getchar_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/state_defs.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

/// batch mode debugging: don't save and restore typeahead.
static bool debug_greedy = false;

static char *debug_oldval = NULL;  // old and newval for debug expressions
static char *debug_newval = NULL;

/// The list of breakpoints: dbg_breakp.
/// This is a grow-array of structs.
struct debuggy {
  int dbg_nr;                   ///< breakpoint number
  int dbg_type;                 ///< DBG_FUNC or DBG_FILE or DBG_EXPR
  char *dbg_name;               ///< function, expression or file name
  regprog_T *dbg_prog;          ///< regexp program
  linenr_T dbg_lnum;            ///< line number in function or file
  int dbg_forceit;              ///< ! used
  typval_T *dbg_val;            ///< last result of watchexpression
  int dbg_level;                ///< stored nested level for expr
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "debugger.c.generated.h"
#endif

/// Debug mode. Repeatedly get Ex commands, until told to continue normal
/// execution.
void do_debug(char *cmd)
{
  int save_msg_scroll = msg_scroll;
  int save_State = State;
  int save_did_emsg = did_emsg;
  const bool save_cmd_silent = cmd_silent;
  int save_msg_silent = msg_silent;
  int save_emsg_silent = emsg_silent;
  bool save_redir_off = redir_off;
  tasave_T typeaheadbuf;
  bool typeahead_saved = false;
  int save_ignore_script = 0;
  char *cmdline = NULL;
  char *p;
  char *tail = NULL;
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

  State = MODE_NORMAL;
  debug_mode = true;

  if (!debug_did_msg) {
    msg(_("Entering Debug mode.  Type \"cont\" to continue."), 0);
  }
  if (debug_oldval != NULL) {
    smsg(0, _("Oldval = \"%s\""), debug_oldval);
    xfree(debug_oldval);
    debug_oldval = NULL;
  }
  if (debug_newval != NULL) {
    smsg(0, _("Newval = \"%s\""), debug_newval);
    xfree(debug_newval);
    debug_newval = NULL;
  }
  char *sname = estack_sfile(ESTACK_NONE);
  if (sname != NULL) {
    msg(sname, 0);
  }
  xfree(sname);
  if (SOURCING_LNUM != 0) {
    smsg(0, _("line %" PRId64 ": %s"), (int64_t)SOURCING_LNUM, cmd);
  } else {
    smsg(0, _("cmd: %s"), cmd);
  }

  // Repeat getting a command and executing it.
  while (true) {
    msg_scroll = true;
    need_wait_return = false;

    // Save the current typeahead buffer and replace it with an empty one.
    // This makes sure we get input from the user here and don't interfere
    // with the commands being executed.  Reset "ex_normal_busy" to avoid
    // the side effects of using ":normal". Save the stuff buffer and make
    // it empty. Set ignore_script to avoid reading from script input.
    int save_ex_normal_busy = ex_normal_busy;
    ex_normal_busy = 0;
    if (!debug_greedy) {
      save_typeahead(&typeaheadbuf);
      typeahead_saved = true;
      save_ignore_script = ignore_script;
      ignore_script = true;
    }

    // don't debug any function call, e.g. from an expression mapping
    int n = debug_break_level;
    debug_break_level = -1;

    xfree(cmdline);
    cmdline = getcmdline_prompt('>', NULL, 0, EXPAND_NOTHING, NULL,
                                CALLBACK_NONE);

    debug_break_level = n;
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
        case 'c':
          last_cmd = CMD_CONT;
          tail = "ont";
          break;
        case 'n':
          last_cmd = CMD_NEXT;
          tail = "ext";
          break;
        case 's':
          last_cmd = CMD_STEP;
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
        case 'q':
          last_cmd = CMD_QUIT;
          tail = "uit";
          break;
        case 'i':
          last_cmd = CMD_INTERRUPT;
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
        default:
          last_cmd = 0;
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
        // Execute debug command: decide where to break next and return.
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
      do_cmdline(cmdline, getexline, NULL, DOCMD_VERBOSE|DOCMD_EXCRESET);
      debug_break_level = n;
    }
    lines_left = Rows - 1;
  }
  xfree(cmdline);

  RedrawingDisabled--;
  no_wait_return--;
  redraw_all_later(UPD_NOT_VALID);
  need_wait_return = false;
  msg_scroll = save_msg_scroll;
  lines_left = Rows - 1;
  State = save_State;
  debug_mode = false;
  did_emsg = save_did_emsg;
  cmd_silent = save_cmd_silent;
  msg_silent = save_msg_silent;
  emsg_silent = save_emsg_silent;
  redir_off = save_redir_off;

  // Only print the message again when typing a command before coming back here.
  debug_did_msg = true;
}

static int get_maxbacktrace_level(char *sname)
{
  int maxbacktrace = 0;

  if (sname == NULL) {
    return 0;
  }

  char *p = sname;
  char *q;
  while ((q = strstr(p, "..")) != NULL) {
    p = q + 2;
    maxbacktrace++;
  }
  return maxbacktrace;
}

static void do_setdebugtracelevel(char *arg)
{
  int level = atoi(arg);
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
    msg(_("frame is zero"), 0);
  } else {
    char *sname = estack_sfile(ESTACK_NONE);
    int max = get_maxbacktrace_level(sname);

    if (debug_backtrace_level > max) {
      debug_backtrace_level = max;
      smsg(0, _("frame at highest level: %d"), max);
    }
    xfree(sname);
  }
}

static void do_showbacktrace(char *cmd)
{
  char *sname = estack_sfile(ESTACK_NONE);
  int max = get_maxbacktrace_level(sname);
  if (sname != NULL) {
    int i = 0;
    char *cur = sname;
    while (!got_int) {
      char *next = strstr(cur, "..");
      if (next != NULL) {
        *next = NUL;
      }
      if (i == max - debug_backtrace_level) {
        smsg(0, "->%d %s", max - i, cur);
      } else {
        smsg(0, "  %d %s", max - i, cur);
      }
      i++;
      if (next == NULL) {
        break;
      }
      *next = '.';
      cur = next + 2;
    }
    xfree(sname);
  }

  if (SOURCING_LNUM != 0) {
    smsg(0, _("line %" PRId64 ": %s"), (int64_t)SOURCING_LNUM, cmd);
  } else {
    smsg(0, _("cmd: %s"), cmd);
  }
}

/// ":debug".
void ex_debug(exarg_T *eap)
{
  int debug_break_level_save = debug_break_level;

  debug_break_level = 9999;
  do_cmdline_cmd(eap->arg);
  debug_break_level = debug_break_level_save;
}

static char *debug_breakpoint_name = NULL;
static linenr_T debug_breakpoint_lnum;

/// When debugging or a breakpoint is set on a skipped command, no debug prompt
/// is shown by do_one_cmd().  This situation is indicated by debug_skipped, and
/// debug_skipped_name is then set to the source name in the breakpoint case. If
/// a skipped command decides itself that a debug prompt should be displayed, it
/// can do so by calling dbg_check_skipped().
static bool debug_skipped;
static char *debug_skipped_name;

/// Go to debug mode when a breakpoint was encountered or "ex_nesting_level" is
/// at or below the break level.  But only when the line is actually
/// executed.  Return true and set breakpoint_name for skipped commands that
/// decide to execute something themselves.
/// Called from do_one_cmd() before executing a command.
void dbg_check_breakpoint(exarg_T *eap)
{
  debug_skipped = false;
  if (debug_breakpoint_name != NULL) {
    if (!eap->skip) {
      char *p;
      // replace K_SNR with "<SNR>"
      if ((uint8_t)debug_breakpoint_name[0] == K_SPECIAL
          && (uint8_t)debug_breakpoint_name[1] == KS_EXTRA
          && debug_breakpoint_name[2] == KE_SNR) {
        p = "<SNR>";
      } else {
        p = "";
      }
      smsg(0, _("Breakpoint in \"%s%s\" line %" PRId64),
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
  if (!debug_skipped) {
    return false;
  }

  // Save the value of got_int and reset it.  We don't want a previous
  // interruption cause flushing the input buffer.
  bool prev_got_int = got_int;
  got_int = false;
  debug_breakpoint_name = debug_skipped_name;
  // eap->skip is true
  eap->skip = false;
  dbg_check_breakpoint(eap);
  eap->skip = true;
  got_int |= prev_got_int;
  return true;
}

static garray_T dbg_breakp = { 0, 0, sizeof(struct debuggy), 4, NULL };
#define BREAKP(idx)             (((struct debuggy *)dbg_breakp.ga_data)[idx])
#define DEBUGGY(gap, idx)       (((struct debuggy *)(gap)->ga_data)[idx])
static int last_breakp = 0;     // nr of last defined breakpoint
static bool has_expr_breakpoint = false;

// Profiling uses file and func names similar to breakpoints.
static garray_T prof_ga = { 0, 0, sizeof(struct debuggy), 4, NULL };
#define DBG_FUNC        1
#define DBG_FILE        2
#define DBG_EXPR        3

/// Evaluate the "bp->dbg_name" expression and return the result.
/// Disables error messages.
static typval_T *eval_expr_no_emsg(struct debuggy *const bp)
  FUNC_ATTR_NONNULL_ALL
{
  // Disable error messages, a bad expression would make Vim unusable.
  emsg_off++;
  typval_T *const tv = eval_expr(bp->dbg_name, NULL);
  emsg_off--;
  return tv;
}

/// Parse the arguments of ":profile", ":breakadd" or ":breakdel" and put them
/// in the entry just after the last one in dbg_breakp.  Note that "dbg_name"
/// is allocated.
/// Returns FAIL for failure.
///
/// @param arg
/// @param gap  either &dbg_breakp or &prof_ga
static int dbg_parsearg(char *arg, garray_T *gap)
{
  char *p = arg;
  bool here = false;

  ga_grow(gap, 1);

  struct debuggy *bp = &DEBUGGY(gap, gap->ga_len);

  // Find "func" or "file".
  if (strncmp(p, S_LEN("func")) == 0) {
    bp->dbg_type = DBG_FUNC;
  } else if (strncmp(p, S_LEN("file")) == 0) {
    bp->dbg_type = DBG_FILE;
  } else if (gap != &prof_ga && strncmp(p, S_LEN("here")) == 0) {
    if (curbuf->b_ffname == NULL) {
      emsg(_(e_noname));
      return FAIL;
    }
    bp->dbg_type = DBG_FILE;
    here = true;
  } else if (gap != &prof_ga && strncmp(p, S_LEN("expr")) == 0) {
    bp->dbg_type = DBG_EXPR;
  } else {
    semsg(_(e_invarg2), p);
    return FAIL;
  }
  p = skipwhite(p + 4);

  // Find optional line number.
  if (here) {
    bp->dbg_lnum = curwin->w_cursor.lnum;
  } else if (gap != &prof_ga && ascii_isdigit(*p)) {
    bp->dbg_lnum = getdigits_int32(&p, true, 0);
    p = skipwhite(p);
  } else {
    bp->dbg_lnum = 0;
  }

  // Find the function or file name.  Don't accept a function name with ().
  if ((!here && *p == NUL)
      || (here && *p != NUL)
      || (bp->dbg_type == DBG_FUNC && strstr(p, "()") != NULL)) {
    semsg(_(e_invarg2), arg);
    return FAIL;
  }

  if (bp->dbg_type == DBG_FUNC) {
    bp->dbg_name = xstrdup(strncmp(p, S_LEN("g:")) == 0 ? p + 2 : p);
  } else if (here) {
    bp->dbg_name = xstrdup(curbuf->b_ffname);
  } else if (bp->dbg_type == DBG_EXPR) {
    bp->dbg_name = xstrdup(p);
    bp->dbg_val = eval_expr_no_emsg(bp);
  } else {
    // Expand the file name in the same way as do_source().  This means
    // doing it twice, so that $DIR/file gets expanded when $DIR is
    // "~/dir".
    char *q = expand_env_save(p);
    if (q == NULL) {
      return FAIL;
    }
    p = expand_env_save(q);
    xfree(q);
    if (p == NULL) {
      return FAIL;
    }
    if (*p != '*') {
      bp->dbg_name = fix_fname(p);
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

/// ":breakadd".  Also used for ":profile".
void ex_breakadd(exarg_T *eap)
{
  garray_T *gap = &dbg_breakp;
  if (eap->cmdidx == CMD_profile) {
    gap = &prof_ga;
  }

  if (dbg_parsearg(eap->arg, gap) != OK) {
    return;
  }

  struct debuggy *bp = &DEBUGGY(gap, gap->ga_len);
  bp->dbg_forceit = eap->forceit;

  if (bp->dbg_type != DBG_EXPR) {
    char *pat = file_pat_to_reg_pat(bp->dbg_name, NULL, NULL, false);
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
  } else {
    // DBG_EXPR
    DEBUGGY(gap, gap->ga_len++).dbg_nr = ++last_breakp;
    debug_tick++;
    if (gap == &dbg_breakp) {
      has_expr_breakpoint = true;
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

static void update_has_expr_breakpoint(void)
{
  has_expr_breakpoint = false;
  for (int i = 0; i < dbg_breakp.ga_len; i++) {
    if (BREAKP(i).dbg_type == DBG_EXPR) {
      has_expr_breakpoint = true;
      break;
    }
  }
}

/// ":breakdel" and ":profdel".
void ex_breakdel(exarg_T *eap)
{
  int todel = -1;
  bool del_all = false;
  linenr_T best_lnum = 0;
  garray_T *gap = &dbg_breakp;

  if (eap->cmdidx == CMD_profdel) {
    gap = &prof_ga;
  }

  if (ascii_isdigit(*eap->arg)) {
    // ":breakdel {nr}"
    int nr = atoi(eap->arg);
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
    // ":breakdel {func|file|expr} [lnum] {name}"
    if (dbg_parsearg(eap->arg, gap) == FAIL) {
      return;
    }
    struct debuggy *bp = &DEBUGGY(gap, gap->ga_len);
    for (int i = 0; i < gap->ga_len; i++) {
      struct debuggy *bpi = &DEBUGGY(gap, i);
      if (bp->dbg_type == bpi->dbg_type
          && strcmp(bp->dbg_name, bpi->dbg_name) == 0
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
    semsg(_("E161: Breakpoint not found: %s"), eap->arg);
    return;
  }

  while (!GA_EMPTY(gap)) {
    xfree(DEBUGGY(gap, todel).dbg_name);
    if (DEBUGGY(gap, todel).dbg_type == DBG_EXPR
        && DEBUGGY(gap, todel).dbg_val != NULL) {
      tv_free(DEBUGGY(gap, todel).dbg_val);
    }
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
  if (gap == &dbg_breakp) {
    update_has_expr_breakpoint();
  }
}

/// ":breaklist".
void ex_breaklist(exarg_T *eap)
{
  if (GA_EMPTY(&dbg_breakp)) {
    msg(_("No breakpoints defined"), 0);
    return;
  }

  for (int i = 0; i < dbg_breakp.ga_len; i++) {
    struct debuggy *bp = &BREAKP(i);
    if (bp->dbg_type == DBG_FILE) {
      home_replace(NULL, bp->dbg_name, NameBuff, MAXPATHL, true);
    }
    if (bp->dbg_type != DBG_EXPR) {
      smsg(0, _("%3d  %s %s  line %" PRId64),
           bp->dbg_nr,
           bp->dbg_type == DBG_FUNC ? "func" : "file",
           bp->dbg_type == DBG_FUNC ? bp->dbg_name : NameBuff,
           (int64_t)bp->dbg_lnum);
    } else {
      smsg(0, _("%3d  expr %s"), bp->dbg_nr, bp->dbg_name);
    }
  }
}

/// Find a breakpoint for a function or sourced file.
/// Returns line number at which to break; zero when no matching breakpoint.
///
/// @param file  true for a file, false for a function
/// @param fname  file or function name
/// @param after  after this line number
linenr_T dbg_find_breakpoint(bool file, char *fname, linenr_T after)
{
  return debuggy_find(file, fname, after, &dbg_breakp, NULL);
}

/// @param file     true for a file, false for a function
/// @param fname    file or function name
/// @param fp[out]  forceit
///
/// @returns true if profiling is on for a function or sourced file.
bool has_profiling(bool file, char *fname, bool *fp)
{
  return debuggy_find(file, fname, 0, &prof_ga, fp)
         != 0;
}

/// Common code for dbg_find_breakpoint() and has_profiling().
///
/// @param file  true for a file, false for a function
/// @param fname  file or function name
/// @param after  after this line number
/// @param gap  either &dbg_breakp or &prof_ga
/// @param fp  if not NULL: return forceit
static linenr_T debuggy_find(bool file, char *fname, linenr_T after, garray_T *gap, bool *fp)
{
  struct debuggy *bp;
  linenr_T lnum = 0;
  char *name = fname;

  // Return quickly when there are no breakpoints.
  if (GA_EMPTY(gap)) {
    return 0;
  }

  // Replace K_SNR in function name with "<SNR>".
  if (!file && (uint8_t)fname[0] == K_SPECIAL) {
    name = xmalloc(strlen(fname) + 3);
    STRCPY(name, "<SNR>");
    STRCPY(name + 5, fname + 3);
  }

  for (int i = 0; i < gap->ga_len; i++) {
    // Skip entries that are not useful or are for a line that is beyond
    // an already found breakpoint.
    bp = &DEBUGGY(gap, i);
    if ((bp->dbg_type == DBG_FILE) == file
        && bp->dbg_type != DBG_EXPR
        && (gap == &prof_ga
            || (bp->dbg_lnum > after && (lnum == 0 || bp->dbg_lnum < lnum)))) {
      // Save the value of got_int and reset it.  We don't want a
      // previous interruption cancel matching, only hitting CTRL-C
      // while matching should abort it.
      bool prev_got_int = got_int;
      got_int = false;
      if (vim_regexec_prog(&bp->dbg_prog, false, name, 0)) {
        lnum = bp->dbg_lnum;
        if (fp != NULL) {
          *fp = bp->dbg_forceit;
        }
      }
      got_int |= prev_got_int;
    } else if (bp->dbg_type == DBG_EXPR) {
      bool line = false;

      typval_T *const tv = eval_expr_no_emsg(bp);
      if (tv != NULL) {
        if (bp->dbg_val == NULL) {
          debug_oldval = typval_tostring(NULL, true);
          bp->dbg_val = tv;
          debug_newval = typval_tostring(bp->dbg_val, true);
          line = true;
        } else {
          if (typval_compare(tv, bp->dbg_val, EXPR_IS, false) == OK
              && tv->vval.v_number == false) {
            line = true;
            debug_oldval = typval_tostring(bp->dbg_val, true);
            // Need to evaluate again, typval_compare() overwrites "tv".
            typval_T *const v = eval_expr_no_emsg(bp);
            debug_newval = typval_tostring(v, true);
            tv_free(bp->dbg_val);
            bp->dbg_val = v;
          }
          tv_free(tv);
        }
      } else if (bp->dbg_val != NULL) {
        debug_oldval = typval_tostring(bp->dbg_val, true);
        debug_newval = typval_tostring(NULL, true);
        tv_free(bp->dbg_val);
        bp->dbg_val = NULL;
        line = true;
      }

      if (line) {
        lnum = after > 0 ? after : 1;
        break;
      }
    }
  }
  if (name != fname) {
    xfree(name);
  }

  return lnum;
}

/// Called when a breakpoint was encountered.
void dbg_breakpoint(char *name, linenr_T lnum)
{
  // We need to check if this line is actually executed in do_one_cmd()
  debug_breakpoint_name = name;
  debug_breakpoint_lnum = lnum;
}
