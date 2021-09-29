// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// ex_docmd.c: functions for executing an Ex command line.

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/debugger.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_session.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/func_attr.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/hardcopy.h"
#include "nvim/if_cscope.h"
#include "nvim/keymap.h"
#include "nvim/lua/executor.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/menu.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/shada.h"
#include "nvim/sign.h"
#include "nvim/spell.h"
#include "nvim/spellfile.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/tag.h"
#include "nvim/terminal.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/version.h"
#include "nvim/vim.h"
#include "nvim/window.h"

static int quitmore = 0;
static bool ex_pressedreturn = false;

typedef struct ucmd {
  char_u *uc_name;         // The command name
  uint32_t uc_argt;             // The argument type
  char_u *uc_rep;          // The command's replacement string
  long uc_def;                  // The default value for a range/count
  int uc_compl;                 // completion type
  cmd_addr_T uc_addr_type;      // The command's address type
  sctx_T uc_script_ctx;         // SCTX where the command was defined
  char_u *uc_compl_arg;    // completion argument if any
} ucmd_T;

#define UC_BUFFER       1       // -buffer: local to current buffer

static garray_T ucmds = { 0, 0, sizeof(ucmd_T), 4, NULL };

#define USER_CMD(i) (&((ucmd_T *)(ucmds.ga_data))[i])
#define USER_CMD_GA(gap, i) (&((ucmd_T *)((gap)->ga_data))[i])

// Whether a command index indicates a user command.
#define IS_USER_CMDIDX(idx) ((int)(idx) < 0)

// Struct for storing a line inside a while/for loop
typedef struct {
  char_u *line;            // command line
  linenr_T lnum;                // sourcing_lnum of the line
} wcmd_T;

#define FREE_WCMD(wcmd) xfree((wcmd)->line)

/*
 * Structure used to store info for line position in a while or for loop.
 * This is required, because do_one_cmd() may invoke ex_function(), which
 * reads more lines that may come from the while/for loop.
 */
struct loop_cookie {
  garray_T *lines_gap;               // growarray with line info
  int current_line;                     // last read line from growarray
  int repeating;                        // TRUE when looping a second time
  // When "repeating" is FALSE use "getline" and "cookie" to get lines
  char_u *(*getline)(int, void *, int, bool);
  void *cookie;
};


// Struct to save a few things while debugging.  Used in do_cmdline() only.
struct dbg_stuff {
  int trylevel;
  int force_abort;
  except_T *caught_stack;
  char_u *vv_exception;
  char_u *vv_throwpoint;
  int did_emsg;
  int got_int;
  int need_rethrow;
  int check_cstack;
  except_T *current_exception;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_docmd.c.generated.h"
#endif

#ifndef HAVE_WORKING_LIBINTL
# define ex_language            ex_ni
#endif

/*
 * Declare cmdnames[].
 */
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds_defs.generated.h"
#endif

static char_u dollar_command[2] = { '$', 0 };

static void save_dbg_stuff(struct dbg_stuff *dsp)
{
  dsp->trylevel       = trylevel;             trylevel = 0;
  dsp->force_abort    = force_abort;          force_abort = FALSE;
  dsp->caught_stack   = caught_stack;         caught_stack = NULL;
  dsp->vv_exception   = v_exception(NULL);
  dsp->vv_throwpoint  = v_throwpoint(NULL);

  // Necessary for debugging an inactive ":catch", ":finally", ":endtry".
  dsp->did_emsg       = did_emsg;             did_emsg     = false;
  dsp->got_int        = got_int;              got_int      = false;
  dsp->need_rethrow   = need_rethrow;         need_rethrow = false;
  dsp->check_cstack   = check_cstack;         check_cstack = false;
  dsp->current_exception = current_exception; current_exception = NULL;
}

static void restore_dbg_stuff(struct dbg_stuff *dsp)
{
  suppress_errthrow = false;
  trylevel = dsp->trylevel;
  force_abort = dsp->force_abort;
  caught_stack = dsp->caught_stack;
  (void)v_exception(dsp->vv_exception);
  (void)v_throwpoint(dsp->vv_throwpoint);
  did_emsg = dsp->did_emsg;
  got_int = dsp->got_int;
  need_rethrow = dsp->need_rethrow;
  check_cstack = dsp->check_cstack;
  current_exception = dsp->current_exception;
}

/// Repeatedly get commands for Ex mode, until the ":vi" command is given.
void do_exmode(void)
{
  int save_msg_scroll;
  int prev_msg_row;
  linenr_T prev_line;
  int changedtick;

  exmode_active = true;
  State = NORMAL;

  /* When using ":global /pat/ visual" and then "Q" we return to continue
   * the :global command. */
  if (global_busy) {
    return;
  }

  save_msg_scroll = msg_scroll;
  RedrawingDisabled++;  // don't redisplay the window
  no_wait_return++;  // don't wait for return

  MSG(_("Entering Ex mode.  Type \"visual\" to go to Normal mode."));
  while (exmode_active) {
    // Check for a ":normal" command and no more characters left.
    if (ex_normal_busy > 0 && typebuf.tb_len == 0) {
      exmode_active = false;
      break;
    }
    msg_scroll = true;
    need_wait_return = false;
    ex_pressedreturn = false;
    ex_no_reprint = false;
    changedtick = buf_get_changedtick(curbuf);
    prev_msg_row = msg_row;
    prev_line = curwin->w_cursor.lnum;
    cmdline_row = msg_row;
    do_cmdline(NULL, getexline, NULL, 0);
    lines_left = Rows - 1;

    if ((prev_line != curwin->w_cursor.lnum
         || changedtick != buf_get_changedtick(curbuf)) && !ex_no_reprint) {
      if (curbuf->b_ml.ml_flags & ML_EMPTY) {
        EMSG(_(e_emptybuf));
      } else {
        if (ex_pressedreturn) {
          /* go up one line, to overwrite the ":<CR>" line, so the
           * output doesn't contain empty lines. */
          msg_row = prev_msg_row;
          if (prev_msg_row == Rows - 1) {
            msg_row--;
          }
        }
        msg_col = 0;
        print_line_no_prefix(curwin->w_cursor.lnum, FALSE, FALSE);
        msg_clr_eos();
      }
    } else if (ex_pressedreturn && !ex_no_reprint) {  // must be at EOF
      if (curbuf->b_ml.ml_flags & ML_EMPTY) {
        EMSG(_(e_emptybuf));
      } else {
        EMSG(_("E501: At end-of-file"));
      }
    }
  }

  RedrawingDisabled--;
  no_wait_return--;
  redraw_all_later(NOT_VALID);
  update_screen(NOT_VALID);
  need_wait_return = false;
  msg_scroll = save_msg_scroll;
}

// Print the executed command for when 'verbose' is set.
// When "lnum" is 0 only print the command.
static void msg_verbose_cmd(linenr_T lnum, char_u *cmd)
  FUNC_ATTR_NONNULL_ALL
{
  no_wait_return++;
  verbose_enter_scroll();

  if (lnum == 0) {
    smsg(_("Executing: %s"), cmd);
  } else {
    smsg(_("line %" PRIdLINENR ": %s"), lnum, cmd);
  }
  if (msg_silent == 0) {
    msg_puts("\n");   // don't overwrite this
  }

  verbose_leave_scroll();
  no_wait_return--;
}

/*
 * Execute a simple command line.  Used for translated commands like "*".
 */
int do_cmdline_cmd(const char *cmd)
{
  return do_cmdline((char_u *)cmd, NULL, NULL,
                    DOCMD_NOWAIT|DOCMD_KEYTYPED);
}

/// do_cmdline(): execute one Ex command line
///
/// 1. Execute "cmdline" when it is not NULL.
///    If "cmdline" is NULL, or more lines are needed, fgetline() is used.
/// 2. Split up in parts separated with '|'.
///
/// This function can be called recursively!
///
/// flags:
///   DOCMD_VERBOSE  - The command will be included in the error message.
///   DOCMD_NOWAIT   - Don't call wait_return() and friends.
///   DOCMD_REPEAT   - Repeat execution until fgetline() returns NULL.
///   DOCMD_KEYTYPED - Don't reset KeyTyped.
///   DOCMD_EXCRESET - Reset the exception environment (used for debugging).
///   DOCMD_KEEPLINE - Store first typed line (for repeating with ".").
///   DOCMD_PREVIEW  - During 'inccommand' preview.
///
/// @param cookie  argument for fgetline()
///
/// @return FAIL if cmdline could not be executed, OK otherwise
int do_cmdline(char_u *cmdline, LineGetter fgetline, void *cookie, int flags)
{
  char_u *next_cmdline;            // next cmd to execute
  char_u *cmdline_copy = NULL;     // copy of cmd line
  bool used_getline = false;            // used "fgetline" to obtain command
  static int recursive = 0;             // recursive depth
  bool msg_didout_before_start = false;
  int count = 0;                        // line number count
  int did_inc = FALSE;                  // incremented RedrawingDisabled
  int retval = OK;
  cstack_T cstack = {                   // conditional stack
    .cs_idx = -1,
  };
  garray_T lines_ga;                    // keep lines for ":while"/":for"
  int current_line = 0;                 // active line in lines_ga
  char_u *fname = NULL;               // function or script name
  linenr_T *breakpoint = NULL;          // ptr to breakpoint field in cookie
  int *dbg_tick = NULL;            // ptr to dbg_tick field in cookie
  struct dbg_stuff debug_saved;         // saved things for debug mode
  int initial_trylevel;
  struct msglist **saved_msg_list = NULL;
  struct msglist *private_msg_list;

  // "fgetline" and "cookie" passed to do_one_cmd()
  char_u *(*cmd_getline)(int, void *, int, bool);
  void *cmd_cookie;
  struct loop_cookie cmd_loop_cookie;
  void *real_cookie;
  int getline_is_func;
  static int call_depth = 0;            // recursiveness

  /* For every pair of do_cmdline()/do_one_cmd() calls, use an extra memory
   * location for storing error messages to be converted to an exception.
   * This ensures that the do_errthrow() call in do_one_cmd() does not
   * combine the messages stored by an earlier invocation of do_one_cmd()
   * with the command name of the later one.  This would happen when
   * BufWritePost autocommands are executed after a write error. */
  saved_msg_list = msg_list;
  msg_list = &private_msg_list;
  private_msg_list = NULL;

  // It's possible to create an endless loop with ":execute", catch that
  // here.  The value of 200 allows nested function calls, ":source", etc.
  // Allow 200 or 'maxfuncdepth', whatever is larger.
  if (call_depth >= 200 && call_depth >= p_mfd) {
    EMSG(_("E169: Command too recursive"));
    // When converting to an exception, we do not include the command name
    // since this is not an error of the specific command.
    do_errthrow((cstack_T *)NULL, (char_u *)NULL);
    msg_list = saved_msg_list;
    return FAIL;
  }
  call_depth++;
  start_batch_changes();

  ga_init(&lines_ga, (int)sizeof(wcmd_T), 10);

  real_cookie = getline_cookie(fgetline, cookie);

  // Inside a function use a higher nesting level.
  getline_is_func = getline_equal(fgetline, cookie, get_func_line);
  if (getline_is_func && ex_nesting_level == func_level(real_cookie)) {
    ++ex_nesting_level;
  }

  /* Get the function or script name and the address where the next breakpoint
   * line and the debug tick for a function or script are stored. */
  if (getline_is_func) {
    fname = func_name(real_cookie);
    breakpoint = func_breakpoint(real_cookie);
    dbg_tick = func_dbg_tick(real_cookie);
  } else if (getline_equal(fgetline, cookie, getsourceline)) {
    fname = sourcing_name;
    breakpoint = source_breakpoint(real_cookie);
    dbg_tick = source_dbg_tick(real_cookie);
  }

  /*
   * Initialize "force_abort"  and "suppress_errthrow" at the top level.
   */
  if (!recursive) {
    force_abort = false;
    suppress_errthrow = false;
  }

  // If requested, store and reset the global values controlling the
  // exception handling (used when debugging).  Otherwise clear it to avoid
  // a bogus compiler warning when the optimizer uses inline functions...
  if (flags & DOCMD_EXCRESET) {
    save_dbg_stuff(&debug_saved);
  } else {
    memset(&debug_saved, 0, sizeof(debug_saved));
  }

  initial_trylevel = trylevel;

  current_exception = NULL;
  // "did_emsg" will be set to TRUE when emsg() is used, in which case we
  // cancel the whole command line, and any if/endif or loop.
  // If force_abort is set, we cancel everything.
  did_emsg = false;

  // KeyTyped is only set when calling vgetc().  Reset it here when not
  // calling vgetc() (sourced command lines).
  if (!(flags & DOCMD_KEYTYPED)
      && !getline_equal(fgetline, cookie, getexline)) {
    KeyTyped = false;
  }

  /*
   * Continue executing command lines:
   * - when inside an ":if", ":while" or ":for"
   * - for multiple commands on one line, separated with '|'
   * - when repeating until there are no more lines (for ":source")
   */
  next_cmdline = cmdline;
  do {
    getline_is_func = getline_equal(fgetline, cookie, get_func_line);

    // stop skipping cmds for an error msg after all endif/while/for
    if (next_cmdline == NULL
        && !force_abort
        && cstack.cs_idx < 0
        && !(getline_is_func &&
             func_has_abort(real_cookie))) {
      did_emsg = FALSE;
    }

    /*
     * 1. If repeating a line in a loop, get a line from lines_ga.
     * 2. If no line given: Get an allocated line with fgetline().
     * 3. If a line is given: Make a copy, so we can mess with it.
     */

    // 1. If repeating, get a previous line from lines_ga.
    if (cstack.cs_looplevel > 0 && current_line < lines_ga.ga_len) {
      /* Each '|' separated command is stored separately in lines_ga, to
       * be able to jump to it.  Don't use next_cmdline now. */
      XFREE_CLEAR(cmdline_copy);

      /* Check if a function has returned or, unless it has an unclosed
       * try conditional, aborted. */
      if (getline_is_func) {
        if (do_profiling == PROF_YES) {
          func_line_end(real_cookie);
        }
        if (func_has_ended(real_cookie)) {
          retval = FAIL;
          break;
        }
      } else if (do_profiling == PROF_YES
                 && getline_equal(fgetline, cookie, getsourceline)) {
        script_line_end();
      }

      // Check if a sourced file hit a ":finish" command.
      if (source_finished(fgetline, cookie)) {
        retval = FAIL;
        break;
      }

      // If breakpoints have been added/deleted need to check for it.
      if (breakpoint != NULL && dbg_tick != NULL
          && *dbg_tick != debug_tick) {
        *breakpoint = dbg_find_breakpoint(getline_equal(fgetline, cookie, getsourceline),
                                          fname, sourcing_lnum);
        *dbg_tick = debug_tick;
      }

      next_cmdline = ((wcmd_T *)(lines_ga.ga_data))[current_line].line;
      sourcing_lnum = ((wcmd_T *)(lines_ga.ga_data))[current_line].lnum;

      // Did we encounter a breakpoint?
      if (breakpoint != NULL && *breakpoint != 0
          && *breakpoint <= sourcing_lnum) {
        dbg_breakpoint(fname, sourcing_lnum);
        // Find next breakpoint.
        *breakpoint = dbg_find_breakpoint(getline_equal(fgetline, cookie, getsourceline),
                                          fname, sourcing_lnum);
        *dbg_tick = debug_tick;
      }
      if (do_profiling == PROF_YES) {
        if (getline_is_func) {
          func_line_start(real_cookie);
        } else if (getline_equal(fgetline, cookie, getsourceline)) {
          script_line_start();
        }
      }
    }

    if (cstack.cs_looplevel > 0) {
      /* Inside a while/for loop we need to store the lines and use them
       * again.  Pass a different "fgetline" function to do_one_cmd()
       * below, so that it stores lines in or reads them from
       * "lines_ga".  Makes it possible to define a function inside a
       * while/for loop. */
      cmd_getline = get_loop_line;
      cmd_cookie = (void *)&cmd_loop_cookie;
      cmd_loop_cookie.lines_gap = &lines_ga;
      cmd_loop_cookie.current_line = current_line;
      cmd_loop_cookie.getline = fgetline;
      cmd_loop_cookie.cookie = cookie;
      cmd_loop_cookie.repeating = (current_line < lines_ga.ga_len);
    } else {
      cmd_getline = fgetline;
      cmd_cookie = cookie;
    }

    // 2. If no line given, get an allocated line with fgetline().
    if (next_cmdline == NULL) {
      /*
       * Need to set msg_didout for the first line after an ":if",
       * otherwise the ":if" will be overwritten.
       */
      if (count == 1 && getline_equal(fgetline, cookie, getexline)) {
        msg_didout = true;
      }
      if (fgetline == NULL
          || (next_cmdline = fgetline(':', cookie,
                                      cstack.cs_idx <
                                      0 ? 0 : (cstack.cs_idx + 1) * 2,
                                      true)) == NULL) {
        // Don't call wait_return for aborted command line.  The NULL
        // returned for the end of a sourced file or executed function
        // doesn't do this.
        if (KeyTyped && !(flags & DOCMD_REPEAT)) {
          need_wait_return = false;
        }
        retval = FAIL;
        break;
      }
      used_getline = true;

      /*
       * Keep the first typed line.  Clear it when more lines are typed.
       */
      if (flags & DOCMD_KEEPLINE) {
        xfree(repeat_cmdline);
        if (count == 0) {
          repeat_cmdline = vim_strsave(next_cmdline);
        } else {
          repeat_cmdline = NULL;
        }
      }
    }
    // 3. Make a copy of the command so we can mess with it.
    else if (cmdline_copy == NULL) {
      next_cmdline = vim_strsave(next_cmdline);
    }
    cmdline_copy = next_cmdline;

    /*
     * Save the current line when inside a ":while" or ":for", and when
     * the command looks like a ":while" or ":for", because we may need it
     * later.  When there is a '|' and another command, it is stored
     * separately, because we need to be able to jump back to it from an
     * :endwhile/:endfor.
     */
    if (current_line == lines_ga.ga_len
        && (cstack.cs_looplevel || has_loop_cmd(next_cmdline))) {
      store_loop_line(&lines_ga, next_cmdline);
    }
    did_endif = false;

    if (count++ == 0) {
      /*
       * All output from the commands is put below each other, without
       * waiting for a return. Don't do this when executing commands
       * from a script or when being called recursive (e.g. for ":e
       * +command file").
       */
      if (!(flags & DOCMD_NOWAIT) && !recursive) {
        msg_didout_before_start = msg_didout;
        msg_didany = false;         // no output yet
        msg_start();
        msg_scroll = TRUE;          // put messages below each other
        ++no_wait_return;           // don't wait for return until finished
        ++RedrawingDisabled;
        did_inc = TRUE;
      }
    }

    if ((p_verbose >= 15 && sourcing_name != NULL) || p_verbose >= 16) {
      msg_verbose_cmd(sourcing_lnum, cmdline_copy);
    }

    /*
     * 2. Execute one '|' separated command.
     *    do_one_cmd() will return NULL if there is no trailing '|'.
     *    "cmdline_copy" can change, e.g. for '%' and '#' expansion.
     */
    recursive++;
    next_cmdline = do_one_cmd(&cmdline_copy, flags,
                              &cstack,
                              cmd_getline, cmd_cookie);
    recursive--;

    // Ignore trailing '|'-separated commands in preview-mode ('inccommand').
    if ((State & CMDPREVIEW) && (flags & DOCMD_PREVIEW)) {
      next_cmdline = NULL;
    }

    if (cmd_cookie == (void *)&cmd_loop_cookie) {
      /* Use "current_line" from "cmd_loop_cookie", it may have been
       * incremented when defining a function. */
      current_line = cmd_loop_cookie.current_line;
    }

    if (next_cmdline == NULL) {
      XFREE_CLEAR(cmdline_copy);
      //
      // If the command was typed, remember it for the ':' register.
      // Do this AFTER executing the command to make :@: work.
      //
      if (getline_equal(fgetline, cookie, getexline)
          && new_last_cmdline != NULL) {
        xfree(last_cmdline);
        last_cmdline = new_last_cmdline;
        new_last_cmdline = NULL;
      }
    } else {
      /* need to copy the command after the '|' to cmdline_copy, for the
       * next do_one_cmd() */
      STRMOVE(cmdline_copy, next_cmdline);
      next_cmdline = cmdline_copy;
    }


    // reset did_emsg for a function that is not aborted by an error
    if (did_emsg && !force_abort
        && getline_equal(fgetline, cookie, get_func_line)
        && !func_has_abort(real_cookie)) {
      did_emsg = FALSE;
    }

    if (cstack.cs_looplevel > 0) {
      ++current_line;

      /*
       * An ":endwhile", ":endfor" and ":continue" is handled here.
       * If we were executing commands, jump back to the ":while" or
       * ":for".
       * If we were not executing commands, decrement cs_looplevel.
       */
      if (cstack.cs_lflags & (CSL_HAD_CONT | CSL_HAD_ENDLOOP)) {
        cstack.cs_lflags &= ~(CSL_HAD_CONT | CSL_HAD_ENDLOOP);

        /* Jump back to the matching ":while" or ":for".  Be careful
         * not to use a cs_line[] from an entry that isn't a ":while"
         * or ":for": It would make "current_line" invalid and can
         * cause a crash. */
        if (!did_emsg && !got_int && !current_exception
            && cstack.cs_idx >= 0
            && (cstack.cs_flags[cstack.cs_idx]
                & (CSF_WHILE | CSF_FOR))
            && cstack.cs_line[cstack.cs_idx] >= 0
            && (cstack.cs_flags[cstack.cs_idx] & CSF_ACTIVE)) {
          current_line = cstack.cs_line[cstack.cs_idx];
          // remember we jumped there
          cstack.cs_lflags |= CSL_HAD_LOOP;
          line_breakcheck();                    // check if CTRL-C typed

          /* Check for the next breakpoint at or after the ":while"
           * or ":for". */
          if (breakpoint != NULL) {
            *breakpoint = dbg_find_breakpoint(getline_equal(fgetline, cookie, getsourceline),
                                              fname,
                                              ((wcmd_T *)lines_ga.ga_data)[current_line].lnum-1);
            *dbg_tick = debug_tick;
          }
        } else {
          // can only get here with ":endwhile" or ":endfor"
          if (cstack.cs_idx >= 0) {
            rewind_conditionals(&cstack, cstack.cs_idx - 1,
                                CSF_WHILE | CSF_FOR, &cstack.cs_looplevel);
          }
        }
      }
      /*
       * For a ":while" or ":for" we need to remember the line number.
       */
      else if (cstack.cs_lflags & CSL_HAD_LOOP) {
        cstack.cs_lflags &= ~CSL_HAD_LOOP;
        cstack.cs_line[cstack.cs_idx] = current_line - 1;
      }
    }

    /*
     * When not inside any ":while" loop, clear remembered lines.
     */
    if (cstack.cs_looplevel == 0) {
      if (!GA_EMPTY(&lines_ga)) {
        sourcing_lnum = ((wcmd_T *)lines_ga.ga_data)[lines_ga.ga_len - 1].lnum;
        GA_DEEP_CLEAR(&lines_ga, wcmd_T, FREE_WCMD);
      }
      current_line = 0;
    }

    /*
     * A ":finally" makes did_emsg, got_int and current_exception pending for
     * being restored at the ":endtry".  Reset them here and set the
     * ACTIVE and FINALLY flags, so that the finally clause gets executed.
     * This includes the case where a missing ":endif", ":endwhile" or
     * ":endfor" was detected by the ":finally" itself.
     */
    if (cstack.cs_lflags & CSL_HAD_FINA) {
      cstack.cs_lflags &= ~CSL_HAD_FINA;
      report_make_pending((cstack.cs_pending[cstack.cs_idx]
                           & (CSTP_ERROR | CSTP_INTERRUPT | CSTP_THROW)),
                          current_exception);
      did_emsg = got_int = false;
      current_exception = NULL;
      cstack.cs_flags[cstack.cs_idx] |= CSF_ACTIVE | CSF_FINALLY;
    }

    /* Update global "trylevel" for recursive calls to do_cmdline() from
     * within this loop. */
    trylevel = initial_trylevel + cstack.cs_trylevel;

    // If the outermost try conditional (across function calls and sourced
    // files) is aborted because of an error, an interrupt, or an uncaught
    // exception, cancel everything.  If it is left normally, reset
    // force_abort to get the non-EH compatible abortion behavior for
    // the rest of the script.
    if (trylevel == 0 && !did_emsg && !got_int && !current_exception) {
      force_abort = false;
    }

    // Convert an interrupt to an exception if appropriate.
    (void)do_intthrow(&cstack);
  }
  /*
   * Continue executing command lines when:
   * - no CTRL-C typed, no aborting error, no exception thrown or try
   *   conditionals need to be checked for executing finally clauses or
   *   catching an interrupt exception
   * - didn't get an error message or lines are not typed
   * - there is a command after '|', inside a :if, :while, :for or :try, or
   *   looping for ":source" command or function call.
   */
  while (!((got_int || (did_emsg && force_abort) || current_exception)
           && cstack.cs_trylevel == 0)
         && !(did_emsg
              /* Keep going when inside try/catch, so that the error can be
               * deal with, except when it is a syntax error, it may cause
               * the :endtry to be missed. */
              && (cstack.cs_trylevel == 0 || did_emsg_syntax)
              && used_getline
              && getline_equal(fgetline, cookie, getexline))
         && (next_cmdline != NULL
             || cstack.cs_idx >= 0
             || (flags & DOCMD_REPEAT)));

  xfree(cmdline_copy);
  did_emsg_syntax = false;
  GA_DEEP_CLEAR(&lines_ga, wcmd_T, FREE_WCMD);

  if (cstack.cs_idx >= 0) {
    /*
     * If a sourced file or executed function ran to its end, report the
     * unclosed conditional.
     */
    if (!got_int && !current_exception
        && ((getline_equal(fgetline, cookie, getsourceline)
             && !source_finished(fgetline, cookie))
            || (getline_equal(fgetline, cookie, get_func_line)
                && !func_has_ended(real_cookie)))) {
      if (cstack.cs_flags[cstack.cs_idx] & CSF_TRY) {
        EMSG(_(e_endtry));
      } else if (cstack.cs_flags[cstack.cs_idx] & CSF_WHILE) {
        EMSG(_(e_endwhile));
      } else if (cstack.cs_flags[cstack.cs_idx] & CSF_FOR) {
        EMSG(_(e_endfor));
      } else {
        EMSG(_(e_endif));
      }
    }

    /*
     * Reset "trylevel" in case of a ":finish" or ":return" or a missing
     * ":endtry" in a sourced file or executed function.  If the try
     * conditional is in its finally clause, ignore anything pending.
     * If it is in a catch clause, finish the caught exception.
     * Also cleanup any "cs_forinfo" structures.
     */
    do {
      int idx = cleanup_conditionals(&cstack, 0, TRUE);

      if (idx >= 0) {
        --idx;              // remove try block not in its finally clause
      }
      rewind_conditionals(&cstack, idx, CSF_WHILE | CSF_FOR,
                          &cstack.cs_looplevel);
    } while (cstack.cs_idx >= 0);
    trylevel = initial_trylevel;
  }

  /* If a missing ":endtry", ":endwhile", ":endfor", or ":endif" or a memory
   * lack was reported above and the error message is to be converted to an
   * exception, do this now after rewinding the cstack. */
  do_errthrow(&cstack, getline_equal(fgetline, cookie, get_func_line)
      ? (char_u *)"endfunction" : (char_u *)NULL);

  if (trylevel == 0) {
    // When an exception is being thrown out of the outermost try
    // conditional, discard the uncaught exception, disable the conversion
    // of interrupts or errors to exceptions, and ensure that no more
    // commands are executed.
    if (current_exception) {
      void *p = NULL;
      char_u *saved_sourcing_name;
      int saved_sourcing_lnum;
      struct msglist *messages = NULL;
      struct msglist *next;

      /*
       * If the uncaught exception is a user exception, report it as an
       * error.  If it is an error exception, display the saved error
       * message now.  For an interrupt exception, do nothing; the
       * interrupt message is given elsewhere.
       */
      switch (current_exception->type) {
      case ET_USER:
        vim_snprintf((char *)IObuff, IOSIZE,
                     _("E605: Exception not caught: %s"),
                     current_exception->value);
        p = vim_strsave(IObuff);
        break;
      case ET_ERROR:
        messages = current_exception->messages;
        current_exception->messages = NULL;
        break;
      case ET_INTERRUPT:
        break;
      }

      saved_sourcing_name = sourcing_name;
      saved_sourcing_lnum = sourcing_lnum;
      sourcing_name = current_exception->throw_name;
      sourcing_lnum = current_exception->throw_lnum;
      current_exception->throw_name = NULL;

      discard_current_exception();              // uses IObuff if 'verbose'
      suppress_errthrow = true;
      force_abort = true;
      msg_ext_set_kind("emsg");  // kind=emsg for :throw, exceptions. #9993

      if (messages != NULL) {
        do {
          next = messages->next;
          emsg(messages->msg);
          xfree(messages->msg);
          xfree(messages);
          messages = next;
        } while (messages != NULL);
      } else if (p != NULL) {
        emsg(p);
        xfree(p);
      }
      xfree(sourcing_name);
      sourcing_name = saved_sourcing_name;
      sourcing_lnum = saved_sourcing_lnum;
    } else if (got_int || (did_emsg && force_abort)) {
      // On an interrupt or an aborting error not converted to an exception,
      // disable the conversion of errors to exceptions.  (Interrupts are not
      // converted any more, here.) This enables also the interrupt message
      // when force_abort is set and did_emsg unset in case of an interrupt
      // from a finally clause after an error.
      suppress_errthrow = true;
    }
  }

  // The current cstack will be freed when do_cmdline() returns.  An uncaught
  // exception will have to be rethrown in the previous cstack.  If a function
  // has just returned or a script file was just finished and the previous
  // cstack belongs to the same function or, respectively, script file, it
  // will have to be checked for finally clauses to be executed due to the
  // ":return" or ":finish".  This is done in do_one_cmd().
  if (current_exception) {
    need_rethrow = true;
  }
  if ((getline_equal(fgetline, cookie, getsourceline)
       && ex_nesting_level > source_level(real_cookie))
      || (getline_equal(fgetline, cookie, get_func_line)
          && ex_nesting_level > func_level(real_cookie) + 1)) {
    if (!current_exception) {
      check_cstack = true;
    }
  } else {
    // When leaving a function, reduce nesting level.
    if (getline_equal(fgetline, cookie, get_func_line)) {
      --ex_nesting_level;
    }
    /*
     * Go to debug mode when returning from a function in which we are
     * single-stepping.
     */
    if ((getline_equal(fgetline, cookie, getsourceline)
         || getline_equal(fgetline, cookie, get_func_line))
        && ex_nesting_level + 1 <= debug_break_level) {
      do_debug(getline_equal(fgetline, cookie, getsourceline)
          ? (char_u *)_("End of sourced file")
          : (char_u *)_("End of function"));
    }
  }

  /*
   * Restore the exception environment (done after returning from the
   * debugger).
   */
  if (flags & DOCMD_EXCRESET) {
    restore_dbg_stuff(&debug_saved);
  }

  msg_list = saved_msg_list;

  /*
   * If there was too much output to fit on the command line, ask the user to
   * hit return before redrawing the screen. With the ":global" command we do
   * this only once after the command is finished.
   */
  if (did_inc) {
    --RedrawingDisabled;
    --no_wait_return;
    msg_scroll = FALSE;

    /*
     * When just finished an ":if"-":else" which was typed, no need to
     * wait for hit-return.  Also for an error situation.
     */
    if (retval == FAIL
        || (did_endif && KeyTyped && !did_emsg)) {
      need_wait_return = false;
      msg_didany = false;               // don't wait when restarting edit
    } else if (need_wait_return) {
      /*
       * The msg_start() above clears msg_didout. The wait_return we do
       * here should not overwrite the command that may be shown before
       * doing that.
       */
      msg_didout |= msg_didout_before_start;
      wait_return(FALSE);
    }
  }

  did_endif = false;    // in case do_cmdline used recursively

  call_depth--;
  end_batch_changes();
  return retval;
}

/*
 * Obtain a line when inside a ":while" or ":for" loop.
 */
static char_u *get_loop_line(int c, void *cookie, int indent, bool do_concat)
{
  struct loop_cookie *cp = (struct loop_cookie *)cookie;
  wcmd_T *wp;
  char_u *line;

  if (cp->current_line + 1 >= cp->lines_gap->ga_len) {
    if (cp->repeating) {
      return NULL;              // trying to read past ":endwhile"/":endfor"
    }
    // First time inside the ":while"/":for": get line normally.
    if (cp->getline == NULL) {
      line = getcmdline(c, 0L, indent, do_concat);
    } else {
      line = cp->getline(c, cp->cookie, indent, do_concat);
    }
    if (line != NULL) {
      store_loop_line(cp->lines_gap, line);
      ++cp->current_line;
    }

    return line;
  }

  KeyTyped = false;
  cp->current_line++;
  wp = (wcmd_T *)(cp->lines_gap->ga_data) + cp->current_line;
  sourcing_lnum = wp->lnum;
  return vim_strsave(wp->line);
}

/*
 * Store a line in "gap" so that a ":while" loop can execute it again.
 */
static void store_loop_line(garray_T *gap, char_u *line)
{
  wcmd_T *p = GA_APPEND_VIA_PTR(wcmd_T, gap);
  p->line = vim_strsave(line);
  p->lnum = sourcing_lnum;
}

/// If "fgetline" is get_loop_line(), return TRUE if the getline it uses equals
/// "func".  * Otherwise return TRUE when "fgetline" equals "func".
///
/// @param cookie  argument for fgetline()
int getline_equal(LineGetter fgetline, void *cookie, LineGetter func)
{
  LineGetter gp;
  struct loop_cookie *cp;

  /* When "fgetline" is "get_loop_line()" use the "cookie" to find the
   * function that's originally used to obtain the lines.  This may be
   * nested several levels. */
  gp = fgetline;
  cp = (struct loop_cookie *)cookie;
  while (gp == get_loop_line) {
    gp = cp->getline;
    cp = cp->cookie;
  }
  return gp == func;
}

/// If "fgetline" is get_loop_line(), return the cookie used by the original
/// getline function.  Otherwise return "cookie".
///
/// @param cookie  argument for fgetline()
void *getline_cookie(LineGetter fgetline, void *cookie)
{
  LineGetter gp;
  struct loop_cookie *cp;

  /* When "fgetline" is "get_loop_line()" use the "cookie" to find the
   * cookie that's originally used to obtain the lines.  This may be nested
   * several levels. */
  gp = fgetline;
  cp = (struct loop_cookie *)cookie;
  while (gp == get_loop_line) {
    gp = cp->getline;
    cp = cp->cookie;
  }
  return cp;
}

/*
 * Helper function to apply an offset for buffer commands, i.e. ":bdelete",
 * ":bwipeout", etc.
 * Returns the buffer number.
 */
static int compute_buffer_local_count(int addr_type, int lnum, int offset)
{
  buf_T *buf;
  buf_T *nextbuf;
  int count = offset;

  buf = firstbuf;
  while (buf->b_next != NULL && buf->b_fnum < lnum) {
    buf = buf->b_next;
  }
  while (count != 0) {
    count += (count < 0) ? 1 : -1;
    nextbuf = (offset < 0) ? buf->b_prev : buf->b_next;
    if (nextbuf == NULL) {
      break;
    }
    buf = nextbuf;
    if (addr_type == ADDR_LOADED_BUFFERS) {
      // skip over unloaded buffers
      while (buf->b_ml.ml_mfp == NULL) {
        nextbuf = (offset < 0) ? buf->b_prev : buf->b_next;
        if (nextbuf == NULL) {
          break;
        }
        buf = nextbuf;
      }
    }
  }
  // we might have gone too far, last buffer is not loaded
  if (addr_type == ADDR_LOADED_BUFFERS) {
    while (buf->b_ml.ml_mfp == NULL) {
      nextbuf = (offset >= 0) ? buf->b_prev : buf->b_next;
      if (nextbuf == NULL) {
        break;
      }
      buf = nextbuf;
    }
  }
  return buf->b_fnum;
}

// Return the window number of "win".
// When "win" is NULL return the number of windows.
static int current_win_nr(const win_T *win)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  int nr = 0;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    ++nr;
    if (wp == win) {
      break;
    }
  }
  return nr;
}

static int current_tab_nr(tabpage_T *tab)
{
  int nr = 0;

  FOR_ALL_TABS(tp) {
    ++nr;
    if (tp == tab) {
      break;
    }
  }
  return nr;
}

#define CURRENT_WIN_NR current_win_nr(curwin)
#define LAST_WIN_NR current_win_nr(NULL)
#define CURRENT_TAB_NR current_tab_nr(curtab)
#define LAST_TAB_NR current_tab_nr(NULL)


/// Figure out the address type for ":wincmd".
static void get_wincmd_addr_type(char_u *arg, exarg_T *eap)
{
  switch (*arg) {
  case 'S':
  case Ctrl_S:
  case 's':
  case Ctrl_N:
  case 'n':
  case 'j':
  case Ctrl_J:
  case 'k':
  case Ctrl_K:
  case 'T':
  case Ctrl_R:
  case 'r':
  case 'R':
  case 'K':
  case 'J':
  case '+':
  case '-':
  case Ctrl__:
  case '_':
  case '|':
  case ']':
  case Ctrl_RSB:
  case 'g':
  case Ctrl_G:
  case Ctrl_V:
  case 'v':
  case 'h':
  case Ctrl_H:
  case 'l':
  case Ctrl_L:
  case 'H':
  case 'L':
  case '>':
  case '<':
  case '}':
  case 'f':
  case 'F':
  case Ctrl_F:
  case 'i':
  case Ctrl_I:
  case 'd':
  case Ctrl_D:
    // window size or any count
    eap->addr_type = ADDR_OTHER;  // -V1037
    break;

  case Ctrl_HAT:
  case '^':
    // buffer number
    eap->addr_type = ADDR_BUFFERS;
    break;

  case Ctrl_Q:
  case 'q':
  case Ctrl_C:
  case 'c':
  case Ctrl_O:
  case 'o':
  case Ctrl_W:
  case 'w':
  case 'W':
  case 'x':
  case Ctrl_X:
    // window number
    eap->addr_type = ADDR_WINDOWS;
    break;

  case Ctrl_Z:
  case 'z':
  case 'P':
  case 't':
  case Ctrl_T:
  case 'b':
  case Ctrl_B:
  case 'p':
  case Ctrl_P:
  case '=':
  case CAR:
    // no count
    eap->addr_type = ADDR_NONE;
    break;
  }
}

/// Skip colons and trailing whitespace, returning a pointer to the first
/// non-colon, non-whitespace character.
//
/// @param skipleadingwhite Skip leading whitespace too
static char_u *skip_colon_white(const char_u *p, bool skipleadingwhite)
{
  if (skipleadingwhite) {
    p = skipwhite(p);
  }

  while (*p == ':') {
    p = skipwhite(p + 1);
  }

  return (char_u *)p;
}

/// Execute one Ex command.
///
/// If 'sourcing' is TRUE, the command will be included in the error message.
///
/// 1. skip comment lines and leading space
/// 2. handle command modifiers
/// 3. skip over the range to find the command
/// 4. parse the range
/// 5. parse the command
/// 6. parse arguments
/// 7. switch on command name
///
/// Note: "fgetline" can be NULL.
///
/// This function may be called recursively!
///
/// @param cookie  argument for fgetline()
static char_u *do_one_cmd(char_u **cmdlinep, int flags, cstack_T *cstack, LineGetter fgetline,
                          void *cookie)
{
  char_u *p;
  linenr_T lnum;
  long n;
  char_u *errormsg = NULL;  // error message
  char_u *after_modifier = NULL;
  exarg_T ea;
  const int save_msg_scroll = msg_scroll;
  cmdmod_T save_cmdmod;
  const int save_reg_executing = reg_executing;
  char_u *cmd;

  memset(&ea, 0, sizeof(ea));
  ea.line1 = 1;
  ea.line2 = 1;
  ex_nesting_level++;

  // When the last file has not been edited :q has to be typed twice.
  if (quitmore
      // avoid that a function call in 'statusline' does this
      && !getline_equal(fgetline, cookie, get_func_line)
      // avoid that an autocommand, e.g. QuitPre, does this
      && !getline_equal(fgetline, cookie,
                        getnextac)) {
    --quitmore;
  }

  /*
   * Reset browse, confirm, etc..  They are restored when returning, for
   * recursive calls.
   */
  save_cmdmod = cmdmod;

  // "#!anything" is handled like a comment.
  if ((*cmdlinep)[0] == '#' && (*cmdlinep)[1] == '!') {
    goto doend;
  }

  // 1. Skip comment lines and leading white space and colons.
  // 2. Handle command modifiers.

  // The "ea" structure holds the arguments that can be used.
  ea.cmd = *cmdlinep;
  ea.cmdlinep = cmdlinep;
  ea.getline = fgetline;
  ea.cookie = cookie;
  ea.cstack = cstack;

  if (parse_command_modifiers(&ea, &errormsg, false) == FAIL) {
    goto doend;
  }

  after_modifier = ea.cmd;

  ea.skip = (did_emsg
             || got_int
             || current_exception
             || (cstack->cs_idx >= 0
                 && !(cstack->cs_flags[cstack->cs_idx] & CSF_ACTIVE)));

  // 3. Skip over the range to find the command. Let "p" point to after it.
  //
  // We need the command to know what kind of range it uses.
  cmd = ea.cmd;
  ea.cmd = skip_range(ea.cmd, NULL);
  if (*ea.cmd == '*') {
    ea.cmd = skipwhite(ea.cmd + 1);
  }
  p = find_command(&ea, NULL);

  // Count this line for profiling if skip is TRUE.
  if (do_profiling == PROF_YES
      && (!ea.skip || cstack->cs_idx == 0
          || (cstack->cs_idx > 0
              && (cstack->cs_flags[cstack->cs_idx - 1] & CSF_ACTIVE)))) {
    int skip = did_emsg || got_int || current_exception;

    if (ea.cmdidx == CMD_catch) {
      skip = !skip && !(cstack->cs_idx >= 0
                        && (cstack->cs_flags[cstack->cs_idx] & CSF_THROWN)
                        && !(cstack->cs_flags[cstack->cs_idx] & CSF_CAUGHT));
    } else if (ea.cmdidx == CMD_else || ea.cmdidx == CMD_elseif) {
      skip = skip || !(cstack->cs_idx >= 0
                       && !(cstack->cs_flags[cstack->cs_idx]
                            & (CSF_ACTIVE | CSF_TRUE)));
    } else if (ea.cmdidx == CMD_finally) {
      skip = false;
    } else if (ea.cmdidx != CMD_endif
               && ea.cmdidx != CMD_endfor
               && ea.cmdidx != CMD_endtry
               && ea.cmdidx != CMD_endwhile) {
      skip = ea.skip;
    }

    if (!skip) {
      if (getline_equal(fgetline, cookie, get_func_line)) {
        func_line_exec(getline_cookie(fgetline, cookie));
      } else if (getline_equal(fgetline, cookie, getsourceline)) {
        script_line_exec();
      }
    }
  }

  // May go to debug mode.  If this happens and the ">quit" debug command is
  // used, throw an interrupt exception and skip the next command.
  dbg_check_breakpoint(&ea);
  if (!ea.skip && got_int) {
    ea.skip = TRUE;
    (void)do_intthrow(cstack);
  }

  // 4. Parse a range specifier of the form: addr [,addr] [;addr] ..
  //
  // where 'addr' is:
  //
  // %          (entire file)
  // $  [+-NUM]
  // 'x [+-NUM] (where x denotes a currently defined mark)
  // .  [+-NUM]
  // [+-NUM]..
  // NUM
  //
  // The ea.cmd pointer is updated to point to the first character following the
  // range spec. If an initial address is found, but no second, the upper bound
  // is equal to the lower.

  // ea.addr_type for user commands is set by find_ucmd
  if (!IS_USER_CMDIDX(ea.cmdidx)) {
    if (ea.cmdidx != CMD_SIZE) {
      ea.addr_type = cmdnames[(int)ea.cmdidx].cmd_addr_type;
    } else {
      ea.addr_type = ADDR_LINES;
    }
    // :wincmd range depends on the argument
    if (ea.cmdidx == CMD_wincmd && p != NULL) {
      get_wincmd_addr_type(skipwhite(p), &ea);
    }
    // :.cc in quickfix window uses line number
    if ((ea.cmdidx == CMD_cc || ea.cmdidx == CMD_ll) && bt_quickfix(curbuf)) {
      ea.addr_type = ADDR_OTHER;
    }
  }

  ea.cmd = cmd;
  if (parse_cmd_address(&ea, &errormsg, false) == FAIL) {
    goto doend;
  }

  /*
   * 5. Parse the command.
   */

  /*
   * Skip ':' and any white space
   */
  ea.cmd = skip_colon_white(ea.cmd, true);

  /*
   * If we got a line, but no command, then go to the line.
   * If we find a '|' or '\n' we set ea.nextcmd.
   */
  if (*ea.cmd == NUL || *ea.cmd == '"'
      || (ea.nextcmd = check_nextcmd(ea.cmd)) != NULL) {
    // strange vi behaviour:
    // ":3"     jumps to line 3
    // ":3|..." prints line 3
    // ":|"     prints current line
    if (ea.skip) {  // skip this if inside :if
      goto doend;
    }
    if (*ea.cmd == '|' || (exmode_active && ea.line1 != ea.line2)) {
      ea.cmdidx = CMD_print;
      ea.argt = EX_RANGE | EX_COUNT | EX_TRLBAR;
      if ((errormsg = invalid_range(&ea)) == NULL) {
        correct_range(&ea);
        ex_print(&ea);
      }
    } else if (ea.addr_count != 0) {
      if (ea.line2 > curbuf->b_ml.ml_line_count) {
        ea.line2 = curbuf->b_ml.ml_line_count;
      }

      if (ea.line2 < 0) {
        errormsg = (char_u *)_(e_invrange);
      } else {
        if (ea.line2 == 0) {
          curwin->w_cursor.lnum = 1;
        } else {
          curwin->w_cursor.lnum = ea.line2;
        }
        beginline(BL_SOL | BL_FIX);
      }
    }
    goto doend;
  }

  // If this looks like an undefined user command and there are CmdUndefined
  // autocommands defined, trigger the matching autocommands.
  if (p != NULL && ea.cmdidx == CMD_SIZE && !ea.skip
      && ASCII_ISUPPER(*ea.cmd)
      && has_event(EVENT_CMDUNDEFINED)) {
    p = ea.cmd;
    while (ASCII_ISALNUM(*p)) {
      ++p;
    }
    p = vim_strnsave(ea.cmd, p - ea.cmd);
    int ret = apply_autocmds(EVENT_CMDUNDEFINED, p, p, true, NULL);
    xfree(p);
    // If the autocommands did something and didn't cause an error, try
    // finding the command again.
    p = (ret && !aborting()) ? find_command(&ea, NULL) : ea.cmd;
  }

  if (p == NULL) {
    if (!ea.skip) {
      errormsg = (char_u *)_("E464: Ambiguous use of user-defined command");
    }
    goto doend;
  }
  // Check for wrong commands.
  if (ea.cmdidx == CMD_SIZE) {
    if (!ea.skip) {
      STRCPY(IObuff, _("E492: Not an editor command"));
      // If the modifier was parsed OK the error must be in the following
      // command
      char_u *cmdname = after_modifier ? after_modifier : *cmdlinep;
      if (!(flags & DOCMD_VERBOSE)) {
        append_command(cmdname);
      }
      errormsg = IObuff;
      did_emsg_syntax = true;
      verify_command(cmdname);
    }
    goto doend;
  }

  // set when Not Implemented
  const int ni = !IS_USER_CMDIDX(ea.cmdidx)
                 && (cmdnames[ea.cmdidx].cmd_func == ex_ni
                     || cmdnames[ea.cmdidx].cmd_func == ex_script_ni);


  // Forced commands.
  if (*p == '!' && ea.cmdidx != CMD_substitute
      && ea.cmdidx != CMD_smagic && ea.cmdidx != CMD_snomagic) {
    p++;
    ea.forceit = true;
  } else {
    ea.forceit = false;
  }

  // 6. Parse arguments.  Then check for errors.
  if (!IS_USER_CMDIDX(ea.cmdidx)) {
    ea.argt = cmdnames[(int)ea.cmdidx].cmd_argt;
  }

  if (!ea.skip) {
    if (sandbox != 0 && !(ea.argt & EX_SBOXOK)) {
      // Command not allowed in sandbox.
      errormsg = (char_u *)_(e_sandbox);
      goto doend;
    }
    if (!MODIFIABLE(curbuf) && (ea.argt & EX_MODIFY)
        // allow :put in terminals
        && (!curbuf->terminal || ea.cmdidx != CMD_put)) {
      // Command not allowed in non-'modifiable' buffer
      errormsg = (char_u *)_(e_modifiable);
      goto doend;
    }

    if (text_locked() && !(ea.argt & EX_CMDWIN)
        && !IS_USER_CMDIDX(ea.cmdidx)) {
      // Command not allowed when editing the command line.
      errormsg = (char_u *)_(get_text_locked_msg());
      goto doend;
    }

    // Disallow editing another buffer when "curbuf->b_ro_locked" is set.
    // Do allow ":checktime" (it is postponed).
    // Do allow ":edit" (check for an argument later).
    // Do allow ":file" with no arguments (check for an argument later).
    if (!(ea.argt & EX_CMDWIN)
        && ea.cmdidx != CMD_checktime
        && ea.cmdidx != CMD_edit
        && ea.cmdidx != CMD_file
        && !IS_USER_CMDIDX(ea.cmdidx)
        && curbuf_locked()) {
      goto doend;
    }

    if (!ni && !(ea.argt & EX_RANGE) && ea.addr_count > 0) {
      // no range allowed
      errormsg = (char_u *)_(e_norange);
      goto doend;
    }
  }

  if (!ni && !(ea.argt & EX_BANG) && ea.forceit) {  // no <!> allowed
    errormsg = (char_u *)_(e_nobang);
    goto doend;
  }

  /*
   * Don't complain about the range if it is not used
   * (could happen if line_count is accidentally set to 0).
   */
  if (!ea.skip && !ni && (ea.argt & EX_RANGE)) {
    // If the range is backwards, ask for confirmation and, if given, swap
    // ea.line1 & ea.line2 so it's forwards again.
    // When global command is busy, don't ask, will fail below.
    if (!global_busy && ea.line1 > ea.line2) {
      if (msg_silent == 0) {
        if ((flags & DOCMD_VERBOSE) || exmode_active) {
          errormsg = (char_u *)_("E493: Backwards range given");
          goto doend;
        }
        if (ask_yesno(_("Backwards range given, OK to swap"), false) != 'y') {
          goto doend;
        }
      }
      lnum = ea.line1;
      ea.line1 = ea.line2;
      ea.line2 = lnum;
    }
    if ((errormsg = invalid_range(&ea)) != NULL) {
      goto doend;
    }
  }

  if ((ea.addr_type == ADDR_OTHER) && ea.addr_count == 0) {
    // default is 1, not cursor
    ea.line2 = 1;
  }

  correct_range(&ea);

  if (((ea.argt & EX_WHOLEFOLD) || ea.addr_count >= 2) && !global_busy
      && ea.addr_type == ADDR_LINES) {
    // Put the first line at the start of a closed fold, put the last line
    // at the end of a closed fold.
    (void)hasFolding(ea.line1, &ea.line1, NULL);
    (void)hasFolding(ea.line2, NULL, &ea.line2);
  }

  /*
   * For the ":make" and ":grep" commands we insert the 'makeprg'/'grepprg'
   * option here, so things like % get expanded.
   */
  p = replace_makeprg(&ea, p, cmdlinep);
  if (p == NULL) {
    goto doend;
  }

  /*
   * Skip to start of argument.
   * Don't do this for the ":!" command, because ":!! -l" needs the space.
   */
  if (ea.cmdidx == CMD_bang) {
    ea.arg = p;
  } else {
    ea.arg = skipwhite(p);
  }

  // ":file" cannot be run with an argument when "curbuf->b_ro_locked" is set
  if (ea.cmdidx == CMD_file && *ea.arg != NUL && curbuf_locked()) {
    goto doend;
  }

  /*
   * Check for "++opt=val" argument.
   * Must be first, allow ":w ++enc=utf8 !cmd"
   */
  if (ea.argt & EX_ARGOPT) {
    while (ea.arg[0] == '+' && ea.arg[1] == '+') {
      if (getargopt(&ea) == FAIL && !ni) {
        errormsg = (char_u *)_(e_invarg);
        goto doend;
      }
    }
  }

  if (ea.cmdidx == CMD_write || ea.cmdidx == CMD_update) {
    if (*ea.arg == '>') {                       // append
      if (*++ea.arg != '>') {                   // typed wrong
        errormsg = (char_u *)_("E494: Use w or w>>");
        goto doend;
      }
      ea.arg = skipwhite(ea.arg + 1);
      ea.append = TRUE;
    } else if (*ea.arg == '!' && ea.cmdidx == CMD_write) {  // :w !filter
      ++ea.arg;
      ea.usefilter = TRUE;
    }
  }

  if (ea.cmdidx == CMD_read) {
    if (ea.forceit) {
      ea.usefilter = TRUE;                      // :r! filter if ea.forceit
      ea.forceit = FALSE;
    } else if (*ea.arg == '!') {              // :r !filter
      ++ea.arg;
      ea.usefilter = TRUE;
    }
  }

  if (ea.cmdidx == CMD_lshift || ea.cmdidx == CMD_rshift) {
    ea.amount = 1;
    while (*ea.arg == *ea.cmd) {                // count number of '>' or '<'
      ++ea.arg;
      ++ea.amount;
    }
    ea.arg = skipwhite(ea.arg);
  }

  /*
   * Check for "+command" argument, before checking for next command.
   * Don't do this for ":read !cmd" and ":write !cmd".
   */
  if ((ea.argt & EX_CMDARG) && !ea.usefilter) {
    ea.do_ecmd_cmd = getargcmd(&ea.arg);
  }

  /*
   * Check for '|' to separate commands and '"' to start comments.
   * Don't do this for ":read !cmd" and ":write !cmd".
   */
  if ((ea.argt & EX_TRLBAR) && !ea.usefilter) {
    separate_nextcmd(&ea);
  } else if (ea.cmdidx == CMD_bang
             || ea.cmdidx == CMD_terminal
             || ea.cmdidx == CMD_global
             || ea.cmdidx == CMD_vglobal
             || ea.usefilter) {
    // Check for <newline> to end a shell command.
    // Also do this for ":read !cmd", ":write !cmd" and ":global".
    // Any others?
    for (p = ea.arg; *p; p++) {
      // Remove one backslash before a newline, so that it's possible to
      // pass a newline to the shell and also a newline that is preceded
      // with a backslash.  This makes it impossible to end a shell
      // command in a backslash, but that doesn't appear useful.
      // Halving the number of backslashes is incompatible with previous
      // versions.
      if (*p == '\\' && p[1] == '\n') {
        STRMOVE(p, p + 1);
      } else if (*p == '\n') {
        ea.nextcmd = p + 1;
        *p = NUL;
        break;
      }
    }
  }

  if ((ea.argt & EX_DFLALL) && ea.addr_count == 0) {
    buf_T *buf;

    ea.line1 = 1;
    switch (ea.addr_type) {
    case ADDR_LINES:
    case ADDR_OTHER:
      ea.line2 = curbuf->b_ml.ml_line_count;
      break;
    case ADDR_LOADED_BUFFERS:
      buf = firstbuf;
      while (buf->b_next != NULL && buf->b_ml.ml_mfp == NULL) {
        buf = buf->b_next;
      }
      ea.line1 = buf->b_fnum;
      buf = lastbuf;
      while (buf->b_prev != NULL && buf->b_ml.ml_mfp == NULL) {
        buf = buf->b_prev;
      }
      ea.line2 = buf->b_fnum;
      break;
    case ADDR_BUFFERS:
      ea.line1 = firstbuf->b_fnum;
      ea.line2 = lastbuf->b_fnum;
      break;
    case ADDR_WINDOWS:
      ea.line2 = LAST_WIN_NR;
      break;
    case ADDR_TABS:
      ea.line2 = LAST_TAB_NR;
      break;
    case ADDR_TABS_RELATIVE:
      ea.line2 = 1;
      break;
    case ADDR_ARGUMENTS:
      if (ARGCOUNT == 0) {
        ea.line1 = ea.line2 = 0;
      } else {
        ea.line2 = ARGCOUNT;
      }
      break;
    case ADDR_QUICKFIX_VALID:
      ea.line2 = qf_get_valid_size(&ea);
      if (ea.line2 == 0) {
        ea.line2 = 1;
      }
      break;
    case ADDR_NONE:
    case ADDR_UNSIGNED:
    case ADDR_QUICKFIX:
      IEMSG(_("INTERNAL: Cannot use EX_DFLALL "
              "with ADDR_NONE, ADDR_UNSIGNED or ADDR_QUICKFIX"));
      break;
    }
  }

  // accept numbered register only when no count allowed (:put)
  if ((ea.argt & EX_REGSTR)
      && *ea.arg != NUL
      // Do not allow register = for user commands
      && (!IS_USER_CMDIDX(ea.cmdidx) || *ea.arg != '=')
      && !((ea.argt & EX_COUNT) && ascii_isdigit(*ea.arg))) {
    if (valid_yank_reg(*ea.arg, (ea.cmdidx != CMD_put
                                 && !IS_USER_CMDIDX(ea.cmdidx)))) {
      ea.regname = *ea.arg++;
      // for '=' register: accept the rest of the line as an expression
      if (ea.arg[-1] == '=' && ea.arg[0] != NUL) {
        set_expr_line(vim_strsave(ea.arg));
        ea.arg += STRLEN(ea.arg);
      }
      ea.arg = skipwhite(ea.arg);
    }
  }

  //
  // Check for a count.  When accepting a EX_BUFNAME, don't use "123foo" as a
  // count, it's a buffer name.
  ///
  if ((ea.argt & EX_COUNT) && ascii_isdigit(*ea.arg)
      && (!(ea.argt & EX_BUFNAME) || *(p = skipdigits(ea.arg + 1)) == NUL
          || ascii_iswhite(*p))) {
    n = getdigits_long(&ea.arg, false, -1);
    ea.arg = skipwhite(ea.arg);
    if (n <= 0 && !ni && (ea.argt & EX_ZEROR) == 0) {
      errormsg = (char_u *)_(e_zerocount);
      goto doend;
    }
    if (ea.addr_type != ADDR_LINES) {  // e.g. :buffer 2, :sleep 3
      ea.line2 = n;
      if (ea.addr_count == 0) {
        ea.addr_count = 1;
      }
    } else {
      ea.line1 = ea.line2;
      ea.line2 += n - 1;
      ++ea.addr_count;
      // Be vi compatible: no error message for out of range.
      if (ea.line2 > curbuf->b_ml.ml_line_count) {
        ea.line2 = curbuf->b_ml.ml_line_count;
      }
    }
  }

  /*
   * Check for flags: 'l', 'p' and '#'.
   */
  if (ea.argt & EX_FLAGS) {
    get_flags(&ea);
  }
  if (!ni && !(ea.argt & EX_EXTRA) && *ea.arg != NUL
      && *ea.arg != '"' && (*ea.arg != '|' || (ea.argt & EX_TRLBAR) == 0)) {
    // no arguments allowed but there is something
    errormsg = (char_u *)_(e_trailing);
    goto doend;
  }

  if (!ni && (ea.argt & EX_NEEDARG) && *ea.arg == NUL) {
    errormsg = (char_u *)_(e_argreq);
    goto doend;
  }

  /*
   * Skip the command when it's not going to be executed.
   * The commands like :if, :endif, etc. always need to be executed.
   * Also make an exception for commands that handle a trailing command
   * themselves.
   */
  if (ea.skip) {
    switch (ea.cmdidx) {
    // commands that need evaluation
    case CMD_while:
    case CMD_endwhile:
    case CMD_for:
    case CMD_endfor:
    case CMD_if:
    case CMD_elseif:
    case CMD_else:
    case CMD_endif:
    case CMD_try:
    case CMD_catch:
    case CMD_finally:
    case CMD_endtry:
    case CMD_function:
      break;

    // Commands that handle '|' themselves.  Check: A command should
    // either have the EX_TRLBAR flag, appear in this list or appear in
    // the list at ":help :bar".
    case CMD_aboveleft:
    case CMD_and:
    case CMD_belowright:
    case CMD_botright:
    case CMD_browse:
    case CMD_call:
    case CMD_confirm:
    case CMD_const:
    case CMD_delfunction:
    case CMD_djump:
    case CMD_dlist:
    case CMD_dsearch:
    case CMD_dsplit:
    case CMD_echo:
    case CMD_echoerr:
    case CMD_echomsg:
    case CMD_echon:
    case CMD_eval:
    case CMD_execute:
    case CMD_filter:
    case CMD_help:
    case CMD_hide:
    case CMD_ijump:
    case CMD_ilist:
    case CMD_isearch:
    case CMD_isplit:
    case CMD_keepalt:
    case CMD_keepjumps:
    case CMD_keepmarks:
    case CMD_keeppatterns:
    case CMD_leftabove:
    case CMD_let:
    case CMD_lockmarks:
    case CMD_lockvar:
    case CMD_lua:
    case CMD_match:
    case CMD_mzscheme:
    case CMD_noautocmd:
    case CMD_noswapfile:
    case CMD_perl:
    case CMD_psearch:
    case CMD_python:
    case CMD_py3:
    case CMD_python3:
    case CMD_pythonx:
    case CMD_pyx:
    case CMD_return:
    case CMD_rightbelow:
    case CMD_ruby:
    case CMD_silent:
    case CMD_smagic:
    case CMD_snomagic:
    case CMD_substitute:
    case CMD_syntax:
    case CMD_tab:
    case CMD_tcl:
    case CMD_throw:
    case CMD_tilde:
    case CMD_topleft:
    case CMD_unlet:
    case CMD_unlockvar:
    case CMD_verbose:
    case CMD_vertical:
    case CMD_wincmd:
      break;

    default:
      goto doend;
    }
  }

  if (ea.argt & EX_XFILE) {
    if (expand_filename(&ea, cmdlinep, &errormsg) == FAIL) {
      goto doend;
    }
  }

  /*
   * Accept buffer name.  Cannot be used at the same time with a buffer
   * number.  Don't do this for a user command.
   */
  if ((ea.argt & EX_BUFNAME) && *ea.arg != NUL && ea.addr_count == 0
      && !IS_USER_CMDIDX(ea.cmdidx)) {
    /*
     * :bdelete, :bwipeout and :bunload take several arguments, separated
     * by spaces: find next space (skipping over escaped characters).
     * The others take one argument: ignore trailing spaces.
     */
    if (ea.cmdidx == CMD_bdelete || ea.cmdidx == CMD_bwipeout
        || ea.cmdidx == CMD_bunload) {
      p = skiptowhite_esc(ea.arg);
    } else {
      p = ea.arg + STRLEN(ea.arg);
      while (p > ea.arg && ascii_iswhite(p[-1])) {
        --p;
      }
    }
    ea.line2 = buflist_findpat(ea.arg, p, (ea.argt & EX_BUFUNL) != 0,
                               false, false);
    if (ea.line2 < 0) {  // failed
      goto doend;
    }
    ea.addr_count = 1;
    ea.arg = skipwhite(p);
  }

  // The :try command saves the emsg_silent flag, reset it here when
  // ":silent! try" was used, it should only apply to :try itself.
  if (ea.cmdidx == CMD_try && ea.did_esilent > 0) {
    emsg_silent -= ea.did_esilent;
    if (emsg_silent < 0) {
      emsg_silent = 0;
    }
    ea.did_esilent = 0;
  }

  // 7. Execute the command.
  if (IS_USER_CMDIDX(ea.cmdidx)) {
    /*
     * Execute a user-defined command.
     */
    do_ucmd(&ea);
  } else {
    /*
     * Call the function to execute the command.
     */
    ea.errmsg = NULL;
    (cmdnames[ea.cmdidx].cmd_func)(&ea);
    if (ea.errmsg != NULL) {
      errormsg = (char_u *)_(ea.errmsg);
    }
  }

  /*
   * If the command just executed called do_cmdline(), any throw or ":return"
   * or ":finish" encountered there must also check the cstack of the still
   * active do_cmdline() that called this do_one_cmd().  Rethrow an uncaught
   * exception, or reanimate a returned function or finished script file and
   * return or finish it again.
   */
  if (need_rethrow) {
    do_throw(cstack);
  } else if (check_cstack) {
    if (source_finished(fgetline, cookie)) {
      do_finish(&ea, TRUE);
    } else if (getline_equal(fgetline, cookie, get_func_line)
               && current_func_returned()) {
      do_return(&ea, TRUE, FALSE, NULL);
    }
  }
  need_rethrow = check_cstack = FALSE;

doend:
  // can happen with zero line number
  if (curwin->w_cursor.lnum == 0) {
    curwin->w_cursor.lnum = 1;
    curwin->w_cursor.col = 0;
  }

  if (errormsg != NULL && *errormsg != NUL && !did_emsg) {
    if (flags & DOCMD_VERBOSE) {
      if (errormsg != IObuff) {
        STRCPY(IObuff, errormsg);
        errormsg = IObuff;
      }
      append_command(*cmdlinep);
    }
    emsg(errormsg);
  }
  do_errthrow(cstack,
              (ea.cmdidx != CMD_SIZE && !IS_USER_CMDIDX(ea.cmdidx))
      ? cmdnames[(int)ea.cmdidx].cmd_name
      : (char_u *)NULL);

  undo_cmdmod(&ea, save_msg_scroll);
  cmdmod = save_cmdmod;
  reg_executing = save_reg_executing;

  if (ea.did_sandbox) {
    sandbox--;
  }

  if (ea.nextcmd && *ea.nextcmd == NUL) {       // not really a next command
    ea.nextcmd = NULL;
  }

  --ex_nesting_level;

  return ea.nextcmd;
}

// Parse and skip over command modifiers:
// - update eap->cmd
// - store flags in "cmdmod".
// - Set ex_pressedreturn for an empty command line.
// - set msg_silent for ":silent"
// - set 'eventignore' to "all" for ":noautocmd"
// - set p_verbose for ":verbose"
// - Increment "sandbox" for ":sandbox"
// When "skip_only" is true the global variables are not changed, except for
// "cmdmod".
// Return FAIL when the command is not to be executed.
// May set "errormsg" to an error message.
int parse_command_modifiers(exarg_T *eap, char_u **errormsg, bool skip_only)
{
  char_u *p;

  memset(&cmdmod, 0, sizeof(cmdmod));
  eap->verbose_save = -1;
  eap->save_msg_silent = -1;

  // Repeat until no more command modifiers are found.
  for (;; ) {
    while (*eap->cmd == ' '
           || *eap->cmd == '\t'
           || *eap->cmd == ':') {
      eap->cmd++;
    }

    // in ex mode, an empty line works like :+
    if (*eap->cmd == NUL && exmode_active
        && getline_equal(eap->getline, eap->cookie, getexline)
        && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
      eap->cmd = (char_u *)"+";
      if (!skip_only) {
        ex_pressedreturn = true;
      }
    }

    // ignore comment and empty lines
    if (*eap->cmd == '"') {
      return FAIL;
    }
    if (*eap->cmd == NUL) {
      if (!skip_only) {
        ex_pressedreturn = true;
      }
      return FAIL;
    }

    p = skip_range(eap->cmd, NULL);
    switch (*p) {
    // When adding an entry, also modify cmd_exists().
    case 'a':
      if (!checkforcmd(&eap->cmd, "aboveleft", 3)) {
        break;
      }
      cmdmod.split |= WSP_ABOVE;
      continue;

    case 'b':
      if (checkforcmd(&eap->cmd, "belowright", 3)) {
        cmdmod.split |= WSP_BELOW;
        continue;
      }
      if (checkforcmd(&eap->cmd, "browse", 3)) {
        cmdmod.browse = true;
        continue;
      }
      if (!checkforcmd(&eap->cmd, "botright", 2)) {
        break;
      }
      cmdmod.split |= WSP_BOT;
      continue;

    case 'c':
      if (!checkforcmd(&eap->cmd, "confirm", 4)) {
        break;
      }
      cmdmod.confirm = true;
      continue;

    case 'k':
      if (checkforcmd(&eap->cmd, "keepmarks", 3)) {
        cmdmod.keepmarks = true;
        continue;
      }
      if (checkforcmd(&eap->cmd, "keepalt", 5)) {
        cmdmod.keepalt = true;
        continue;
      }
      if (checkforcmd(&eap->cmd, "keeppatterns", 5)) {
        cmdmod.keeppatterns = true;
        continue;
      }
      if (!checkforcmd(&eap->cmd, "keepjumps", 5)) {
        break;
      }
      cmdmod.keepjumps = true;
      continue;

    case 'f': {  // only accept ":filter {pat} cmd"
      char_u *reg_pat;

      if (!checkforcmd(&p, "filter", 4) || *p == NUL || ends_excmd(*p)) {
        break;
      }
      if (*p == '!') {
        cmdmod.filter_force = true;
        p = skipwhite(p + 1);
        if (*p == NUL || ends_excmd(*p)) {
          break;
        }
      }
      if (skip_only) {
        p = skip_vimgrep_pat(p, NULL, NULL);
      } else {
        // NOTE: This puts a NUL after the pattern.
        p = skip_vimgrep_pat(p, &reg_pat, NULL);
      }
      if (p == NULL || *p == NUL) {
        break;
      }
      if (!skip_only) {
        cmdmod.filter_regmatch.regprog = vim_regcomp(reg_pat, RE_MAGIC);
        if (cmdmod.filter_regmatch.regprog == NULL) {
          break;
        }
      }
      eap->cmd = p;
      continue;
    }

    // ":hide" and ":hide | cmd" are not modifiers
    case 'h':
      if (p != eap->cmd || !checkforcmd(&p, "hide", 3)
          || *p == NUL || ends_excmd(*p)) {
        break;
      }
      eap->cmd = p;
      cmdmod.hide = true;
      continue;

    case 'l':
      if (checkforcmd(&eap->cmd, "lockmarks", 3)) {
        cmdmod.lockmarks = true;
        continue;
      }

      if (!checkforcmd(&eap->cmd, "leftabove", 5)) {
        break;
      }
      cmdmod.split |= WSP_ABOVE;
      continue;

    case 'n':
      if (checkforcmd(&eap->cmd, "noautocmd", 3)) {
        if (cmdmod.save_ei == NULL && !skip_only) {
          // Set 'eventignore' to "all". Restore the
          // existing option value later.
          cmdmod.save_ei = vim_strsave(p_ei);
          set_string_option_direct("ei", -1,
                                   (char_u *)"all", OPT_FREE, SID_NONE);
        }
        continue;
      }
      if (!checkforcmd(&eap->cmd, "noswapfile", 3)) {
        break;
      }
      cmdmod.noswapfile = true;
      continue;

    case 'r':
      if (!checkforcmd(&eap->cmd, "rightbelow", 6)) {
        break;
      }
      cmdmod.split |= WSP_BELOW;
      continue;

    case 's':
      if (checkforcmd(&eap->cmd, "sandbox", 3)) {
        if (!skip_only) {
          if (!eap->did_sandbox) {
            sandbox++;
          }
          eap->did_sandbox = true;
        }
        continue;
      }
      if (!checkforcmd(&eap->cmd, "silent", 3)) {
        break;
      }
      if (!skip_only) {
        if (eap->save_msg_silent == -1) {
          eap->save_msg_silent = msg_silent;
        }
        msg_silent++;
      }
      if (*eap->cmd == '!' && !ascii_iswhite(eap->cmd[-1])) {
        // ":silent!", but not "silent !cmd"
        eap->cmd = skipwhite(eap->cmd + 1);
        if (!skip_only) {
          emsg_silent++;
          eap->did_esilent++;
        }
      }
      continue;

    case 't':
      if (checkforcmd(&p, "tab", 3)) {
        if (!skip_only) {
          long tabnr = get_address(eap, &eap->cmd, ADDR_TABS, eap->skip, skip_only, false, 1);

          if (tabnr == MAXLNUM) {
            cmdmod.tab = tabpage_index(curtab) + 1;
          } else {
            if (tabnr < 0 || tabnr > LAST_TAB_NR) {
              *errormsg = (char_u *)_(e_invrange);
              return false;
            }
            cmdmod.tab = tabnr + 1;
          }
        }
        eap->cmd = p;
        continue;
      }
      if (!checkforcmd(&eap->cmd, "topleft", 2)) {
        break;
      }
      cmdmod.split |= WSP_TOP;
      continue;

    case 'u':
      if (!checkforcmd(&eap->cmd, "unsilent", 3)) {
        break;
      }
      if (!skip_only) {
        if (eap->save_msg_silent == -1) {
          eap->save_msg_silent = msg_silent;
        }
        msg_silent = 0;
      }
      continue;

    case 'v':
      if (checkforcmd(&eap->cmd, "vertical", 4)) {
        cmdmod.split |= WSP_VERT;
        continue;
      }
      if (!checkforcmd(&p, "verbose", 4)) {
        break;
      }
      if (!skip_only) {
        if (eap->verbose_save < 0) {
          eap->verbose_save = p_verbose;
        }
        if (ascii_isdigit(*eap->cmd)) {
          p_verbose = atoi((char *)eap->cmd);
        } else {
          p_verbose = 1;
        }
      }
      eap->cmd = p;
      continue;
    }
    break;
  }

  return OK;
}

// Undo and free contents of "cmdmod".
static void undo_cmdmod(const exarg_T *eap, int save_msg_scroll)
  FUNC_ATTR_NONNULL_ALL
{
  if (eap->verbose_save >= 0) {
    p_verbose = eap->verbose_save;
  }

  if (cmdmod.save_ei != NULL) {
    // Restore 'eventignore' to the value before ":noautocmd".
    set_string_option_direct("ei", -1, cmdmod.save_ei, OPT_FREE, SID_NONE);
    free_string_option(cmdmod.save_ei);
  }

  vim_regfree(cmdmod.filter_regmatch.regprog);

  if (eap->save_msg_silent != -1) {
    // messages could be enabled for a serious error, need to check if the
    // counters don't become negative
    if (!did_emsg || msg_silent > eap->save_msg_silent) {
      msg_silent = eap->save_msg_silent;
    }
    emsg_silent -= eap->did_esilent;
    if (emsg_silent < 0) {
      emsg_silent = 0;
    }
    // Restore msg_scroll, it's set by file I/O commands, even when no
    // message is actually displayed.
    msg_scroll = save_msg_scroll;

    // "silent reg" or "silent echo x" inside "redir" leaves msg_col
    // somewhere in the line.  Put it back in the first column.
    if (redirecting()) {
      msg_col = 0;
    }
  }
}


// Parse the address range, if any, in "eap".
// May set the last search pattern, unless "silent" is true.
// Return FAIL and set "errormsg" or return OK.
int parse_cmd_address(exarg_T *eap, char_u **errormsg, bool silent)
  FUNC_ATTR_NONNULL_ALL
{
  int address_count = 1;
  linenr_T lnum;

  // Repeat for all ',' or ';' separated addresses.
  for (;;) {
    eap->line1 = eap->line2;
    switch (eap->addr_type) {
    case ADDR_LINES:
    case ADDR_OTHER:
      // default is current line number
      eap->line2 = curwin->w_cursor.lnum;
      break;
    case ADDR_WINDOWS:
      eap->line2 = CURRENT_WIN_NR;
      break;
    case ADDR_ARGUMENTS:
      eap->line2 = curwin->w_arg_idx + 1;
      if (eap->line2 > ARGCOUNT) {
        eap->line2 = ARGCOUNT;
      }
      break;
    case ADDR_LOADED_BUFFERS:
    case ADDR_BUFFERS:
      eap->line2 = curbuf->b_fnum;
      break;
    case ADDR_TABS:
      eap->line2 = CURRENT_TAB_NR;
      break;
    case ADDR_TABS_RELATIVE:
    case ADDR_UNSIGNED:
      eap->line2 = 1;
      break;
    case ADDR_QUICKFIX:
      eap->line2 = qf_get_cur_idx(eap);
      break;
    case ADDR_QUICKFIX_VALID:
      eap->line2 = qf_get_cur_valid_idx(eap);
      break;
    case ADDR_NONE:
      // Will give an error later if a range is found.
      break;
    }
    eap->cmd = skipwhite(eap->cmd);
    lnum = get_address(eap, &eap->cmd, eap->addr_type, eap->skip, silent,
                       eap->addr_count == 0, address_count++);
    if (eap->cmd == NULL) {  // error detected
      return FAIL;
    }
    if (lnum == MAXLNUM) {
      if (*eap->cmd == '%') {  // '%' - all lines
        eap->cmd++;
        switch (eap->addr_type) {
        case ADDR_LINES:
        case ADDR_OTHER:
          eap->line1 = 1;
          eap->line2 = curbuf->b_ml.ml_line_count;
          break;
        case ADDR_LOADED_BUFFERS: {
          buf_T *buf = firstbuf;

          while (buf->b_next != NULL && buf->b_ml.ml_mfp == NULL) {
            buf = buf->b_next;
          }
          eap->line1 = buf->b_fnum;
          buf = lastbuf;
          while (buf->b_prev != NULL && buf->b_ml.ml_mfp == NULL) {
            buf = buf->b_prev;
          }
          eap->line2 = buf->b_fnum;
          break;
        }
        case ADDR_BUFFERS:
          eap->line1 = firstbuf->b_fnum;
          eap->line2 = lastbuf->b_fnum;
          break;
        case ADDR_WINDOWS:
        case ADDR_TABS:
          if (IS_USER_CMDIDX(eap->cmdidx)) {
            eap->line1 = 1;
            eap->line2 = eap->addr_type == ADDR_WINDOWS
                ? LAST_WIN_NR : LAST_TAB_NR;
          } else {
            // there is no Vim command which uses '%' and
            // ADDR_WINDOWS or ADDR_TABS
            *errormsg = (char_u *)_(e_invrange);
            return FAIL;
          }
          break;
        case ADDR_TABS_RELATIVE:
        case ADDR_UNSIGNED:
        case ADDR_QUICKFIX:
          *errormsg = (char_u *)_(e_invrange);
          return FAIL;
        case ADDR_ARGUMENTS:
          if (ARGCOUNT == 0) {
            eap->line1 = eap->line2 = 0;
          } else {
            eap->line1 = 1;
            eap->line2 = ARGCOUNT;
          }
          break;
        case ADDR_QUICKFIX_VALID:
          eap->line1 = 1;
          eap->line2 = qf_get_valid_size(eap);
          if (eap->line2 == 0) {
            eap->line2 = 1;
          }
          break;
        case ADDR_NONE:
          // Will give an error later if a range is found.
          break;
        }
        eap->addr_count++;
      } else if (*eap->cmd == '*') {
        // '*' - visual area
        if (eap->addr_type != ADDR_LINES) {
          *errormsg = (char_u *)_(e_invrange);
          return FAIL;
        }

        eap->cmd++;
        if (!eap->skip) {
          pos_T *fp = getmark('<', false);
          if (check_mark(fp) == FAIL) {
            return FAIL;
          }
          eap->line1 = fp->lnum;
          fp = getmark('>', false);
          if (check_mark(fp) == FAIL) {
            return FAIL;
          }
          eap->line2 = fp->lnum;
          eap->addr_count++;
        }
      }
    } else {
      eap->line2 = lnum;
    }
    eap->addr_count++;

    if (*eap->cmd == ';') {
      if (!eap->skip) {
        curwin->w_cursor.lnum = eap->line2;
        // Don't leave the cursor on an illegal line or column, but do
        // accept zero as address, so 0;/PATTERN/ works correctly.
        if (eap->line2 > 0) {
          check_cursor();
        }
      }
    } else if (*eap->cmd != ',') {
      break;
    }
    eap->cmd++;
  }

  // One address given: set start and end lines.
  if (eap->addr_count == 1) {
    eap->line1 = eap->line2;
    // ... but only implicit: really no address given
    if (lnum == MAXLNUM) {
      eap->addr_count = 0;
    }
  }
  return OK;
}

/// Check for an Ex command with optional tail.
/// If there is a match advance "pp" to the argument and return TRUE.
///
/// @param pp   start of command
/// @param cmd  name of command
/// @param len  required length
int checkforcmd(char_u **pp, char *cmd, int len)
{
  int i;

  for (i = 0; cmd[i] != NUL; ++i) {
    if (((char_u *)cmd)[i] != (*pp)[i]) {
      break;
    }
  }
  if (i >= len && !isalpha((*pp)[i])) {
    *pp = skipwhite(*pp + i);
    return TRUE;
  }
  return FALSE;
}

/*
 * Append "cmd" to the error message in IObuff.
 * Takes care of limiting the length and handling 0xa0, which would be
 * invisible otherwise.
 */
static void append_command(char_u *cmd)
{
  char_u *s = cmd;
  char_u *d;

  STRCAT(IObuff, ": ");
  d = IObuff + STRLEN(IObuff);
  while (*s != NUL && d - IObuff < IOSIZE - 7) {
    if (s[0] == 0xc2 && s[1] == 0xa0) {
      s += 2;
      STRCPY(d, "<a0>");
      d += 4;
    } else {
      MB_COPY_CHAR(s, d);
    }
  }
  *d = NUL;
}

// Find an Ex command by its name, either built-in or user.
// Start of the name can be found at eap->cmd.
// Sets eap->cmdidx and returns a pointer to char after the command name.
// "full" is set to TRUE if the whole command name matched.
// Returns NULL for an ambiguous user command.
static char_u *find_command(exarg_T *eap, int *full)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int len;
  char_u *p;
  int i;

  /*
   * Isolate the command and search for it in the command table.
   * Exceptions:
   * - the 'k' command can directly be followed by any character.
   * - the 's' command can be followed directly by 'c', 'g', 'i', 'I' or 'r'
   *        but :sre[wind] is another command, as are :scr[iptnames],
   *        :scs[cope], :sim[alt], :sig[ns] and :sil[ent].
   * - the "d" command can directly be followed by 'l' or 'p' flag.
   */
  p = eap->cmd;
  if (*p == 'k') {
    eap->cmdidx = CMD_k;
    ++p;
  } else if (p[0] == 's'
             && ((p[1] == 'c'
                  && (p[2] == NUL
                      || (p[2] != 's' && p[2] != 'r'
                          && (p[3] == NUL
                              || (p[3] != 'i' && p[4] != 'p')))))
                 || p[1] == 'g'
                 || (p[1] == 'i' && p[2] != 'm' && p[2] != 'l' && p[2] != 'g')
                 || p[1] == 'I'
                 || (p[1] == 'r' && p[2] != 'e'))) {
    eap->cmdidx = CMD_substitute;
    ++p;
  } else {
    while (ASCII_ISALPHA(*p)) {
      ++p;
    }
    // for python 3.x support ":py3", ":python3", ":py3file", etc.
    if (eap->cmd[0] == 'p' && eap->cmd[1] == 'y') {
      while (ASCII_ISALNUM(*p)) {
        ++p;
      }
    }

    // check for non-alpha command
    if (p == eap->cmd && vim_strchr((char_u *)"@!=><&~#", *p) != NULL) {
      ++p;
    }
    len = (int)(p - eap->cmd);
    if (*eap->cmd == 'd' && (p[-1] == 'l' || p[-1] == 'p')) {
      /* Check for ":dl", ":dell", etc. to ":deletel": that's
       * :delete with the 'l' flag.  Same for 'p'. */
      for (i = 0; i < len; ++i) {
        if (eap->cmd[i] != ((char_u *)"delete")[i]) {
          break;
        }
      }
      if (i == len - 1) {
        --len;
        if (p[-1] == 'l') {
          eap->flags |= EXFLAG_LIST;
        } else {
          eap->flags |= EXFLAG_PRINT;
        }
      }
    }

    if (ASCII_ISLOWER(eap->cmd[0])) {
      const int c1 = eap->cmd[0];
      const int c2 = len == 1 ? NUL : eap->cmd[1];

      if (command_count != CMD_SIZE) {
        iemsg((char *)_("E943: Command table needs to be updated, run 'make'"));
        getout(1);
      }

      // Use a precomputed index for fast look-up in cmdnames[]
      // taking into account the first 2 letters of eap->cmd.
      eap->cmdidx = cmdidxs1[CharOrdLow(c1)];
      if (ASCII_ISLOWER(c2)) {
        eap->cmdidx += cmdidxs2[CharOrdLow(c1)][CharOrdLow(c2)];
      }
    } else {
      eap->cmdidx = CMD_bang;
    }

    for (; (int)eap->cmdidx < CMD_SIZE;
         eap->cmdidx = (cmdidx_T)((int)eap->cmdidx + 1)) {
      if (STRNCMP(cmdnames[(int)eap->cmdidx].cmd_name, (char *)eap->cmd,
                  (size_t)len) == 0) {
        if (full != NULL
            && cmdnames[(int)eap->cmdidx].cmd_name[len] == NUL) {
          *full = TRUE;
        }
        break;
      }
    }

    // Look for a user defined command as a last resort.
    if ((eap->cmdidx == CMD_SIZE)
        && *eap->cmd >= 'A' && *eap->cmd <= 'Z') {
      // User defined commands may contain digits.
      while (ASCII_ISALNUM(*p)) {
        ++p;
      }
      p = find_ucmd(eap, p, full, NULL, NULL);
    }
    if (p == eap->cmd) {
      eap->cmdidx = CMD_SIZE;
    }
  }

  return p;
}

/// Search for a user command that matches "eap->cmd".
/// Return cmdidx in "eap->cmdidx", flags in "eap->argt", idx in "eap->useridx".
/// Return a pointer to just after the command.
/// Return NULL if there is no matching command.
///
/// @param *p      end of the command (possibly including count)
/// @param full    set to TRUE for a full match
/// @param xp      used for completion, NULL otherwise
/// @param complp  completion flags or NULL
static char_u *find_ucmd(exarg_T *eap, char_u *p, int *full, expand_T *xp, int *complp)
{
  int len = (int)(p - eap->cmd);
  int j, k, matchlen = 0;
  ucmd_T *uc;
  bool found = false;
  bool possible = false;
  char_u *cp, *np;             // Point into typed cmd and test name
  garray_T *gap;
  bool amb_local = false;            // Found ambiguous buffer-local command,
                                     // only full match global is accepted.

  /*
   * Look for buffer-local user commands first, then global ones.
   */
  gap = &curbuf->b_ucmds;
  for (;; ) {
    for (j = 0; j < gap->ga_len; ++j) {
      uc = USER_CMD_GA(gap, j);
      cp = eap->cmd;
      np = uc->uc_name;
      k = 0;
      while (k < len && *np != NUL && *cp++ == *np++) {
        k++;
      }
      if (k == len || (*np == NUL && ascii_isdigit(eap->cmd[k]))) {
        /* If finding a second match, the command is ambiguous.  But
         * not if a buffer-local command wasn't a full match and a
         * global command is a full match. */
        if (k == len && found && *np != NUL) {
          if (gap == &ucmds) {
            return NULL;
          }
          amb_local = true;
        }

        if (!found || (k == len && *np == NUL)) {
          /* If we matched up to a digit, then there could
           * be another command including the digit that we
           * should use instead.
           */
          if (k == len) {
            found = true;
          } else {
            possible = true;
          }

          if (gap == &ucmds) {
            eap->cmdidx = CMD_USER;
          } else {
            eap->cmdidx = CMD_USER_BUF;
          }
          eap->argt = uc->uc_argt;
          eap->useridx = j;
          eap->addr_type = uc->uc_addr_type;

          if (complp != NULL) {
            *complp = uc->uc_compl;
          }
          if (xp != NULL) {
            xp->xp_arg = uc->uc_compl_arg;
            xp->xp_script_ctx = uc->uc_script_ctx;
            xp->xp_script_ctx.sc_lnum += sourcing_lnum;
          }
          /* Do not search for further abbreviations
           * if this is an exact match. */
          matchlen = k;
          if (k == len && *np == NUL) {
            if (full != NULL) {
              *full = TRUE;
            }
            amb_local = false;
            break;
          }
        }
      }
    }

    // Stop if we found a full match or searched all.
    if (j < gap->ga_len || gap == &ucmds) {
      break;
    }
    gap = &ucmds;
  }

  // Only found ambiguous matches.
  if (amb_local) {
    if (xp != NULL) {
      xp->xp_context = EXPAND_UNSUCCESSFUL;
    }
    return NULL;
  }

  /* The match we found may be followed immediately by a number.  Move "p"
   * back to point to it. */
  if (found || possible) {
    return p + (matchlen - len);
  }
  return p;
}

static struct cmdmod {
  char *name;
  int minlen;
  int has_count;            // :123verbose  :3tab
} cmdmods[] = {
  { "aboveleft", 3, false },
  { "belowright", 3, false },
  { "botright", 2, false },
  { "browse", 3, false },
  { "confirm", 4, false },
  { "filter", 4, false },
  { "hide", 3, false },
  { "keepalt", 5, false },
  { "keepjumps", 5, false },
  { "keepmarks", 3, false },
  { "keeppatterns", 5, false },
  { "leftabove", 5, false },
  { "lockmarks", 3, false },
  { "noautocmd", 3, false },
  { "noswapfile", 3, false },
  { "rightbelow", 6, false },
  { "sandbox", 3, false },
  { "silent", 3, false },
  { "tab", 3, true },
  { "topleft", 2, false },
  { "unsilent", 3, false },
  { "verbose", 4, true },
  { "vertical", 4, false },
};

/*
 * Return length of a command modifier (including optional count).
 * Return zero when it's not a modifier.
 */
int modifier_len(char_u *cmd)
{
  char_u *p = cmd;

  if (ascii_isdigit(*cmd)) {
    p = skipwhite(skipdigits(cmd + 1));
  }
  for (int i = 0; i < (int)ARRAY_SIZE(cmdmods); i++) {
    int j;
    for (j = 0; p[j] != NUL; j++) {
      if (p[j] != cmdmods[i].name[j]) {
        break;
      }
    }
    if (j >= cmdmods[i].minlen
        && !ASCII_ISALPHA(p[j])
        && (p == cmd || cmdmods[i].has_count)) {
      return j + (int)(p - cmd);
    }
  }
  return 0;
}

/*
 * Return > 0 if an Ex command "name" exists.
 * Return 2 if there is an exact match.
 * Return 3 if there is an ambiguous match.
 */
int cmd_exists(const char *const name)
{
  exarg_T ea;
  char_u *p;

  // Check command modifiers.
  for (int i = 0; i < (int)ARRAY_SIZE(cmdmods); i++) {
    int j;
    for (j = 0; name[j] != NUL; j++) {
      if (name[j] != cmdmods[i].name[j]) {
        break;
      }
    }
    if (name[j] == NUL && j >= cmdmods[i].minlen) {
      return cmdmods[i].name[j] == NUL ? 2 : 1;
    }
  }

  /* Check built-in commands and user defined commands.
   * For ":2match" and ":3match" we need to skip the number. */
  ea.cmd = (char_u *)((*name == '2' || *name == '3') ? name + 1 : name);
  ea.cmdidx = (cmdidx_T)0;
  int full = false;
  p = find_command(&ea, &full);
  if (p == NULL) {
    return 3;
  }
  if (ascii_isdigit(*name) && ea.cmdidx != CMD_match) {
    return 0;
  }
  if (*skipwhite(p) != NUL) {
    return 0;           // trailing garbage
  }
  return ea.cmdidx == CMD_SIZE ? 0 : (full ? 2 : 1);
}

/// This is all pretty much copied from do_one_cmd(), with all the extra stuff
/// we don't need/want deleted.  Maybe this could be done better if we didn't
/// repeat all this stuff.  The only problem is that they may not stay
/// perfectly compatible with each other, but then the command line syntax
/// probably won't change that much -- webb.
///
/// @param buff  buffer for command string
const char *set_one_cmd_context(expand_T *xp, const char *buff)
{
  size_t len = 0;
  exarg_T ea;
  int context = EXPAND_NOTHING;
  bool forceit = false;
  bool usefilter = false;  // Filter instead of file name.

  ExpandInit(xp);
  xp->xp_pattern = (char_u *)buff;
  xp->xp_context = EXPAND_COMMANDS;  // Default until we get past command
  ea.argt = 0;

  // 2. skip comment lines and leading space, colons or bars
  const char *cmd;
  for (cmd = buff; vim_strchr((const char_u *)" \t:|", *cmd) != NULL; cmd++) {
  }
  xp->xp_pattern = (char_u *)cmd;

  if (*cmd == NUL) {
    return NULL;
  }
  if (*cmd == '"') {        // ignore comment lines
    xp->xp_context = EXPAND_NOTHING;
    return NULL;
  }

  /*
   * 3. parse a range specifier of the form: addr [,addr] [;addr] ..
   */
  cmd = (const char *)skip_range((const char_u *)cmd, &xp->xp_context);

  /*
   * 4. parse command
   */
  xp->xp_pattern = (char_u *)cmd;
  if (*cmd == NUL) {
    return NULL;
  }
  if (*cmd == '"') {
    xp->xp_context = EXPAND_NOTHING;
    return NULL;
  }

  if (*cmd == '|' || *cmd == '\n') {
    return cmd + 1;                     // There's another command
  }
  /*
   * Isolate the command and search for it in the command table.
   * Exceptions:
   * - the 'k' command can directly be followed by any character, but
   *   do accept "keepmarks", "keepalt" and "keepjumps".
   * - the 's' command can be followed directly by 'c', 'g', 'i', 'I' or 'r'
   */
  const char *p;
  if (*cmd == 'k' && cmd[1] != 'e') {
    ea.cmdidx = CMD_k;
    p = cmd + 1;
  } else {
    p = cmd;
    while (ASCII_ISALPHA(*p) || *p == '*') {  // Allow * wild card
      p++;
    }
    // a user command may contain digits
    if (ASCII_ISUPPER(cmd[0])) {
      while (ASCII_ISALNUM(*p) || *p == '*') {
        p++;
      }
    }
    // for python 3.x: ":py3*" commands completion
    if (cmd[0] == 'p' && cmd[1] == 'y' && p == cmd + 2 && *p == '3') {
      p++;
      while (ASCII_ISALPHA(*p) || *p == '*') {
        p++;
      }
    }
    // check for non-alpha command
    if (p == cmd && vim_strchr((const char_u *)"@*!=><&~#", *p) != NULL) {
      p++;
    }
    len = (size_t)(p - cmd);

    if (len == 0) {
      xp->xp_context = EXPAND_UNSUCCESSFUL;
      return NULL;
    }
    for (ea.cmdidx = (cmdidx_T)0; (int)ea.cmdidx < CMD_SIZE;
         ea.cmdidx = (cmdidx_T)((int)ea.cmdidx + 1)) {
      if (STRNCMP(cmdnames[(int)ea.cmdidx].cmd_name, cmd, len) == 0) {
        break;
      }
    }

    if (cmd[0] >= 'A' && cmd[0] <= 'Z') {
      while (ASCII_ISALNUM(*p) || *p == '*') {  // Allow * wild card
        p++;
      }
    }
  }

  //
  // If the cursor is touching the command, and it ends in an alphanumeric
  // character, complete the command name.
  //
  if (*p == NUL && ASCII_ISALNUM(p[-1])) {
    return NULL;
  }

  if (ea.cmdidx == CMD_SIZE) {
    if (*cmd == 's' && vim_strchr((const char_u *)"cgriI", cmd[1]) != NULL) {
      ea.cmdidx = CMD_substitute;
      p = cmd + 1;
    } else if (cmd[0] >= 'A' && cmd[0] <= 'Z') {
      ea.cmd = (char_u *)cmd;
      p = (const char *)find_ucmd(&ea, (char_u *)p, NULL, xp, &context);
      if (p == NULL) {
        ea.cmdidx = CMD_SIZE;  // Ambiguous user command.
      }
    }
  }
  if (ea.cmdidx == CMD_SIZE) {
    // Not still touching the command and it was an illegal one
    xp->xp_context = EXPAND_UNSUCCESSFUL;
    return NULL;
  }

  xp->xp_context = EXPAND_NOTHING;   // Default now that we're past command

  if (*p == '!') {                  // forced commands
    forceit = true;
    p++;
  }

  /*
   * 5. parse arguments
   */
  if (!IS_USER_CMDIDX(ea.cmdidx)) {
    ea.argt = cmdnames[(int)ea.cmdidx].cmd_argt;
  }

  const char *arg = (const char *)skipwhite((const char_u *)p);

  // Skip over ++argopt argument
  if ((ea.argt & EX_ARGOPT) && *arg != NUL && strncmp(arg, "++", 2) == 0) {
    p = arg;
    while (*p && !ascii_isspace(*p)) {
      MB_PTR_ADV(p);
    }
    arg = (const char *)skipwhite((const char_u *)p);
  }

  if (ea.cmdidx == CMD_write || ea.cmdidx == CMD_update) {
    if (*arg == '>') {  // Append.
      if (*++arg == '>') {
        arg++;
      }
      arg = (const char *)skipwhite((const char_u *)arg);
    } else if (*arg == '!' && ea.cmdidx == CMD_write) {  // :w !filter
      arg++;
      usefilter = true;
    }
  }

  if (ea.cmdidx == CMD_read) {
    usefilter = forceit;                        // :r! filter if forced
    if (*arg == '!') {                          // :r !filter
      arg++;
      usefilter = true;
    }
  }

  if (ea.cmdidx == CMD_lshift || ea.cmdidx == CMD_rshift) {
    while (*arg == *cmd) {  // allow any number of '>' or '<'
      arg++;
    }
    arg = (const char *)skipwhite((const char_u *)arg);
  }

  // Does command allow "+command"?
  if ((ea.argt & EX_CMDARG) && !usefilter && *arg == '+') {
    // Check if we're in the +command
    p = arg + 1;
    arg = (const char *)skip_cmd_arg((char_u *)arg, false);

    // Still touching the command after '+'?
    if (*arg == NUL) {
      return p;
    }

    // Skip space(s) after +command to get to the real argument.
    arg = (const char *)skipwhite((const char_u *)arg);
  }

  /*
   * Check for '|' to separate commands and '"' to start comments.
   * Don't do this for ":read !cmd" and ":write !cmd".
   */
  if ((ea.argt & EX_TRLBAR) && !usefilter) {
    p = arg;
    // ":redir @" is not the start of a comment
    if (ea.cmdidx == CMD_redir && p[0] == '@' && p[1] == '"') {
      p += 2;
    }
    while (*p) {
      if (*p == Ctrl_V) {
        if (p[1] != NUL) {
          p++;
        }
      } else if ((*p == '"' && !(ea.argt & EX_NOTRLCOM))
                 || *p == '|'
                 || *p == '\n') {
        if (*(p - 1) != '\\') {
          if (*p == '|' || *p == '\n') {
            return p + 1;
          }
          return NULL;              // It's a comment
        }
      }
      MB_PTR_ADV(p);
    }
  }

  if (!(ea.argt & EX_EXTRA) && *arg != NUL && strchr("|\"", *arg) == NULL) {
    // no arguments allowed but there is something
    return NULL;
  }

  // Find start of last argument (argument just before cursor):
  p = buff;
  xp->xp_pattern = (char_u *)p;
  len = strlen(buff);
  while (*p && p < buff + len) {
    if (*p == ' ' || *p == TAB) {
      // Argument starts after a space.
      xp->xp_pattern = (char_u *)++p;
    } else {
      if (*p == '\\' && *(p + 1) != NUL) {
        p++;        // skip over escaped character
      }
      MB_PTR_ADV(p);
    }
  }

  if (ea.argt & EX_XFILE) {
    int c;
    int in_quote = false;
    const char *bow = NULL;  // Beginning of word.

    /*
     * Allow spaces within back-quotes to count as part of the argument
     * being expanded.
     */
    xp->xp_pattern = skipwhite((const char_u *)arg);
    p = (const char *)xp->xp_pattern;
    while (*p != NUL) {
      c = utf_ptr2char((const char_u *)p);
      if (c == '\\' && p[1] != NUL) {
        p++;
      } else if (c == '`') {
        if (!in_quote) {
          xp->xp_pattern = (char_u *)p;
          bow = p + 1;
        }
        in_quote = !in_quote;
      }
      /* An argument can contain just about everything, except
       * characters that end the command and white space. */
      else if (c == '|'
               || c == '\n'
               || c == '"'
               || ascii_iswhite(c)) {
        len = 0;          // avoid getting stuck when space is in 'isfname'
        while (*p != NUL) {
          c = utf_ptr2char((const char_u *)p);
          if (c == '`' || vim_isfilec_or_wc(c)) {
            break;
          }
          len = (size_t)utfc_ptr2len((const char_u *)p);
          MB_PTR_ADV(p);
        }
        if (in_quote) {
          bow = p;
        } else {
          xp->xp_pattern = (char_u *)p;
        }
        p -= len;
      }
      MB_PTR_ADV(p);
    }

    /*
     * If we are still inside the quotes, and we passed a space, just
     * expand from there.
     */
    if (bow != NULL && in_quote) {
      xp->xp_pattern = (char_u *)bow;
    }
    xp->xp_context = EXPAND_FILES;

    // For a shell command more chars need to be escaped.
    if (usefilter || ea.cmdidx == CMD_bang || ea.cmdidx == CMD_terminal) {
#ifndef BACKSLASH_IN_FILENAME
      xp->xp_shell = TRUE;
#endif
      // When still after the command name expand executables.
      if (xp->xp_pattern == skipwhite((const char_u *)arg)) {
        xp->xp_context = EXPAND_SHELLCMD;
      }
    }

    // Check for environment variable.
    if (*xp->xp_pattern == '$') {
      for (p = (const char *)xp->xp_pattern + 1; *p != NUL; p++) {
        if (!vim_isIDc((uint8_t)(*p))) {
          break;
        }
      }
      if (*p == NUL) {
        xp->xp_context = EXPAND_ENV_VARS;
        xp->xp_pattern++;
        // Avoid that the assignment uses EXPAND_FILES again.
        if (context != EXPAND_USER_DEFINED && context != EXPAND_USER_LIST) {
          context = EXPAND_ENV_VARS;
        }
      }
    }
    // Check for user names.
    if (*xp->xp_pattern == '~') {
      for (p = (const char *)xp->xp_pattern + 1; *p != NUL && *p != '/'; p++) {
      }
      // Complete ~user only if it partially matches a user name.
      // A full match ~user<Tab> will be replaced by user's home
      // directory i.e. something like ~user<Tab> -> /home/user/
      if (*p == NUL && p > (const char *)xp->xp_pattern + 1
          && match_user(xp->xp_pattern + 1) >= 1) {
        xp->xp_context = EXPAND_USER;
        ++xp->xp_pattern;
      }
    }
  }

  /*
   * 6. switch on command name
   */
  switch (ea.cmdidx) {
  case CMD_find:
  case CMD_sfind:
  case CMD_tabfind:
    if (xp->xp_context == EXPAND_FILES) {
      xp->xp_context = EXPAND_FILES_IN_PATH;
    }
    break;
  case CMD_cd:
  case CMD_chdir:
  case CMD_lcd:
  case CMD_lchdir:
  case CMD_tcd:
  case CMD_tchdir:
    if (xp->xp_context == EXPAND_FILES) {
      xp->xp_context = EXPAND_DIRECTORIES;
    }
    break;
  case CMD_help:
    xp->xp_context = EXPAND_HELP;
    xp->xp_pattern = (char_u *)arg;
    break;

  /* Command modifiers: return the argument.
   * Also for commands with an argument that is a command. */
  case CMD_aboveleft:
  case CMD_argdo:
  case CMD_belowright:
  case CMD_botright:
  case CMD_browse:
  case CMD_bufdo:
  case CMD_cdo:
  case CMD_cfdo:
  case CMD_confirm:
  case CMD_debug:
  case CMD_folddoclosed:
  case CMD_folddoopen:
  case CMD_hide:
  case CMD_keepalt:
  case CMD_keepjumps:
  case CMD_keepmarks:
  case CMD_keeppatterns:
  case CMD_ldo:
  case CMD_leftabove:
  case CMD_lfdo:
  case CMD_lockmarks:
  case CMD_noautocmd:
  case CMD_noswapfile:
  case CMD_rightbelow:
  case CMD_sandbox:
  case CMD_silent:
  case CMD_tab:
  case CMD_tabdo:
  case CMD_topleft:
  case CMD_verbose:
  case CMD_vertical:
  case CMD_windo:
    return arg;

  case CMD_filter:
    if (*arg != NUL) {
      arg = (const char *)skip_vimgrep_pat((char_u *)arg, NULL, NULL);
    }
    if (arg == NULL || *arg == NUL) {
      xp->xp_context = EXPAND_NOTHING;
      return NULL;
    }
    return (const char *)skipwhite((const char_u *)arg);

  case CMD_match:
    if (*arg == NUL || !ends_excmd(*arg)) {
      // also complete "None"
      set_context_in_echohl_cmd(xp, arg);
      arg = (const char *)skipwhite(skiptowhite((const char_u *)arg));
      if (*arg != NUL) {
        xp->xp_context = EXPAND_NOTHING;
        arg = (const char *)skip_regexp((char_u *)arg + 1, (uint8_t)(*arg),
                                        p_magic, NULL);
      }
    }
    return (const char *)find_nextcmd((char_u *)arg);

  /*
   * All completion for the +cmdline_compl feature goes here.
   */

  case CMD_command:
    // Check for attributes
    while (*arg == '-') {
      arg++;  // Skip "-".
      p = (const char *)skiptowhite((const char_u *)arg);
      if (*p == NUL) {
        // Cursor is still in the attribute.
        p = strchr(arg, '=');
        if (p == NULL) {
          // No "=", so complete attribute names.
          xp->xp_context = EXPAND_USER_CMD_FLAGS;
          xp->xp_pattern = (char_u *)arg;
          return NULL;
        }

        // For the -complete, -nargs and -addr attributes, we complete
        // their arguments as well.
        if (STRNICMP(arg, "complete", p - arg) == 0) {
          xp->xp_context = EXPAND_USER_COMPLETE;
          xp->xp_pattern = (char_u *)p + 1;
          return NULL;
        } else if (STRNICMP(arg, "nargs", p - arg) == 0) {
          xp->xp_context = EXPAND_USER_NARGS;
          xp->xp_pattern = (char_u *)p + 1;
          return NULL;
        } else if (STRNICMP(arg, "addr", p - arg) == 0) {
          xp->xp_context = EXPAND_USER_ADDR_TYPE;
          xp->xp_pattern = (char_u *)p + 1;
          return NULL;
        }
        return NULL;
      }
      arg = (const char *)skipwhite((char_u *)p);
    }

    // After the attributes comes the new command name.
    p = (const char *)skiptowhite((const char_u *)arg);
    if (*p == NUL) {
      xp->xp_context = EXPAND_USER_COMMANDS;
      xp->xp_pattern = (char_u *)arg;
      break;
    }

    // And finally comes a normal command.
    return (const char *)skipwhite((const char_u *)p);

  case CMD_delcommand:
    xp->xp_context = EXPAND_USER_COMMANDS;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_global:
  case CMD_vglobal: {
    const int delim = (uint8_t)(*arg);  // Get the delimiter.
    if (delim) {
      arg++;  // Skip delimiter if there is one.
    }

    while (arg[0] != NUL && (uint8_t)arg[0] != delim) {
      if (arg[0] == '\\' && arg[1] != NUL) {
        arg++;
      }
      arg++;
    }
    if (arg[0] != NUL) {
      return arg + 1;
    }
    break;
  }
  case CMD_and:
  case CMD_substitute: {
    const int delim = (uint8_t)(*arg);
    if (delim) {
      // Skip "from" part.
      arg++;
      arg = (const char *)skip_regexp((char_u *)arg, delim, p_magic, NULL);
    }
    // Skip "to" part.
    while (arg[0] != NUL && (uint8_t)arg[0] != delim) {
      if (arg[0] == '\\' && arg[1] != NUL) {
        arg++;
      }
      arg++;
    }
    if (arg[0] != NUL) {  // Skip delimiter.
      arg++;
    }
    while (arg[0] && strchr("|\"#", arg[0]) == NULL) {
      arg++;
    }
    if (arg[0] != NUL) {
      return arg;
    }
    break;
  }
  case CMD_isearch:
  case CMD_dsearch:
  case CMD_ilist:
  case CMD_dlist:
  case CMD_ijump:
  case CMD_psearch:
  case CMD_djump:
  case CMD_isplit:
  case CMD_dsplit:
    // Skip count.
    arg = (const char *)skipwhite(skipdigits((const char_u *)arg));
    if (*arg == '/') {  // Match regexp, not just whole words.
      for (++arg; *arg && *arg != '/'; arg++) {
        if (*arg == '\\' && arg[1] != NUL) {
          arg++;
        }
      }
      if (*arg) {
        arg = (const char *)skipwhite((const char_u *)arg + 1);

        // Check for trailing illegal characters.
        if (*arg && strchr("|\"\n", *arg) == NULL) {
          xp->xp_context = EXPAND_NOTHING;
        } else {
          return arg;
        }
      }
    }
    break;
  case CMD_autocmd:
    return (const char *)set_context_in_autocmd(xp, (char_u *)arg, false);

  case CMD_doautocmd:
  case CMD_doautoall:
    return (const char *)set_context_in_autocmd(xp, (char_u *)arg, true);
  case CMD_set:
    set_context_in_set_cmd(xp, (char_u *)arg, 0);
    break;
  case CMD_setglobal:
    set_context_in_set_cmd(xp, (char_u *)arg, OPT_GLOBAL);
    break;
  case CMD_setlocal:
    set_context_in_set_cmd(xp, (char_u *)arg, OPT_LOCAL);
    break;
  case CMD_tag:
  case CMD_stag:
  case CMD_ptag:
  case CMD_ltag:
  case CMD_tselect:
  case CMD_stselect:
  case CMD_ptselect:
  case CMD_tjump:
  case CMD_stjump:
  case CMD_ptjump:
    if (wop_flags & WOP_TAGFILE) {
      xp->xp_context = EXPAND_TAGS_LISTFILES;
    } else {
      xp->xp_context = EXPAND_TAGS;
    }
    xp->xp_pattern = (char_u *)arg;
    break;
  case CMD_augroup:
    xp->xp_context = EXPAND_AUGROUP;
    xp->xp_pattern = (char_u *)arg;
    break;
  case CMD_syntax:
    set_context_in_syntax_cmd(xp, arg);
    break;
  case CMD_const:
  case CMD_let:
  case CMD_if:
  case CMD_elseif:
  case CMD_while:
  case CMD_for:
  case CMD_echo:
  case CMD_echon:
  case CMD_execute:
  case CMD_echomsg:
  case CMD_echoerr:
  case CMD_call:
  case CMD_return:
  case CMD_cexpr:
  case CMD_caddexpr:
  case CMD_cgetexpr:
  case CMD_lexpr:
  case CMD_laddexpr:
  case CMD_lgetexpr:
    set_context_for_expression(xp, (char_u *)arg, ea.cmdidx);
    break;

  case CMD_unlet:
    while ((xp->xp_pattern = (char_u *)strchr(arg, ' ')) != NULL) {
      arg = (const char *)xp->xp_pattern + 1;
    }

    xp->xp_context = EXPAND_USER_VARS;
    xp->xp_pattern = (char_u *)arg;

    if (*xp->xp_pattern == '$') {
      xp->xp_context = EXPAND_ENV_VARS;
      xp->xp_pattern++;
    }

    break;

  case CMD_function:
  case CMD_delfunction:
    xp->xp_context = EXPAND_USER_FUNC;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_echohl:
    set_context_in_echohl_cmd(xp, arg);
    break;
  case CMD_highlight:
    set_context_in_highlight_cmd(xp, arg);
    break;
  case CMD_cscope:
  case CMD_lcscope:
  case CMD_scscope:
    set_context_in_cscope_cmd(xp, arg, ea.cmdidx);
    break;
  case CMD_sign:
    set_context_in_sign_cmd(xp, (char_u *)arg);
    break;
  case CMD_bdelete:
  case CMD_bwipeout:
  case CMD_bunload:
    while ((xp->xp_pattern = (char_u *)strchr(arg, ' ')) != NULL) {
      arg = (const char *)xp->xp_pattern + 1;
    }
    FALLTHROUGH;
  case CMD_buffer:
  case CMD_sbuffer:
  case CMD_checktime:
    xp->xp_context = EXPAND_BUFFERS;
    xp->xp_pattern = (char_u *)arg;
    break;
  case CMD_diffget:
  case CMD_diffput:
    // If current buffer is in diff mode, complete buffer names
    // which are in diff mode, and different than current buffer.
    xp->xp_context = EXPAND_DIFF_BUFFERS;
    xp->xp_pattern = (char_u *)arg;
    break;
  case CMD_USER:
  case CMD_USER_BUF:
    if (context != EXPAND_NOTHING) {
      // EX_XFILE: file names are handled above.
      if (!(ea.argt & EX_XFILE)) {
        if (context == EXPAND_MENUS) {
          return (const char *)set_context_in_menu_cmd(xp, cmd,
                                                       (char_u *)arg, forceit);
        } else if (context == EXPAND_COMMANDS) {
          return arg;
        } else if (context == EXPAND_MAPPINGS) {
          return (const char *)set_context_in_map_cmd(xp, (char_u *)"map", (char_u *)arg, forceit,
                                                      false, false,
                                                      CMD_map);
        }
        // Find start of last argument.
        p = arg;
        while (*p) {
          if (*p == ' ') {
            // argument starts after a space
            arg = p + 1;
          } else if (*p == '\\' && *(p + 1) != NUL) {
            p++;                // skip over escaped character
          }
          MB_PTR_ADV(p);
        }
        xp->xp_pattern = (char_u *)arg;
      }
      xp->xp_context = context;
    }
    break;
  case CMD_map:
  case CMD_noremap:
  case CMD_nmap:
  case CMD_nnoremap:
  case CMD_vmap:
  case CMD_vnoremap:
  case CMD_omap:
  case CMD_onoremap:
  case CMD_imap:
  case CMD_inoremap:
  case CMD_cmap:
  case CMD_cnoremap:
  case CMD_lmap:
  case CMD_lnoremap:
  case CMD_smap:
  case CMD_snoremap:
  case CMD_xmap:
  case CMD_xnoremap:
    return (const char *)set_context_in_map_cmd(xp, (char_u *)cmd, (char_u *)arg, forceit, false,
                                                false, ea.cmdidx);
  case CMD_unmap:
  case CMD_nunmap:
  case CMD_vunmap:
  case CMD_ounmap:
  case CMD_iunmap:
  case CMD_cunmap:
  case CMD_lunmap:
  case CMD_sunmap:
  case CMD_xunmap:
    return (const char *)set_context_in_map_cmd(xp, (char_u *)cmd, (char_u *)arg, forceit, false,
                                                true, ea.cmdidx);
  case CMD_mapclear:
  case CMD_nmapclear:
  case CMD_vmapclear:
  case CMD_omapclear:
  case CMD_imapclear:
  case CMD_cmapclear:
  case CMD_lmapclear:
  case CMD_smapclear:
  case CMD_xmapclear:
    xp->xp_context = EXPAND_MAPCLEAR;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_abbreviate:
  case CMD_noreabbrev:
  case CMD_cabbrev:
  case CMD_cnoreabbrev:
  case CMD_iabbrev:
  case CMD_inoreabbrev:
    return (const char *)set_context_in_map_cmd(xp, (char_u *)cmd, (char_u *)arg, forceit, true,
                                                false, ea.cmdidx);
  case CMD_unabbreviate:
  case CMD_cunabbrev:
  case CMD_iunabbrev:
    return (const char *)set_context_in_map_cmd(xp, (char_u *)cmd, (char_u *)arg, forceit, true,
                                                true, ea.cmdidx);
  case CMD_menu:
  case CMD_noremenu:
  case CMD_unmenu:
  case CMD_amenu:
  case CMD_anoremenu:
  case CMD_aunmenu:
  case CMD_nmenu:
  case CMD_nnoremenu:
  case CMD_nunmenu:
  case CMD_vmenu:
  case CMD_vnoremenu:
  case CMD_vunmenu:
  case CMD_omenu:
  case CMD_onoremenu:
  case CMD_ounmenu:
  case CMD_imenu:
  case CMD_inoremenu:
  case CMD_iunmenu:
  case CMD_cmenu:
  case CMD_cnoremenu:
  case CMD_cunmenu:
  case CMD_tmenu:
  case CMD_tunmenu:
  case CMD_popup:
  case CMD_emenu:
    return (const char *)set_context_in_menu_cmd(xp, cmd, (char_u *)arg, forceit);

  case CMD_colorscheme:
    xp->xp_context = EXPAND_COLORS;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_compiler:
    xp->xp_context = EXPAND_COMPILER;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_ownsyntax:
    xp->xp_context = EXPAND_OWNSYNTAX;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_setfiletype:
    xp->xp_context = EXPAND_FILETYPE;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_packadd:
    xp->xp_context = EXPAND_PACKADD;
    xp->xp_pattern = (char_u *)arg;
    break;

#ifdef HAVE_WORKING_LIBINTL
  case CMD_language:
    p = (const char *)skiptowhite((const char_u *)arg);
    if (*p == NUL) {
      xp->xp_context = EXPAND_LANGUAGE;
      xp->xp_pattern = (char_u *)arg;
    } else {
      if (strncmp(arg, "messages", p - arg) == 0
          || strncmp(arg, "ctype", p - arg) == 0
          || strncmp(arg, "time", p - arg) == 0
          || strncmp(arg, "collate", p - arg) == 0) {
        xp->xp_context = EXPAND_LOCALES;
        xp->xp_pattern = skipwhite((const char_u *)p);
      } else {
        xp->xp_context = EXPAND_NOTHING;
      }
    }
    break;
#endif
  case CMD_profile:
    set_context_in_profile_cmd(xp, arg);
    break;
  case CMD_checkhealth:
    xp->xp_context = EXPAND_CHECKHEALTH;
    xp->xp_pattern = (char_u *)arg;
    break;
  case CMD_behave:
    xp->xp_context = EXPAND_BEHAVE;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_messages:
    xp->xp_context = EXPAND_MESSAGES;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_history:
    xp->xp_context = EXPAND_HISTORY;
    xp->xp_pattern = (char_u *)arg;
    break;
  case CMD_syntime:
    xp->xp_context = EXPAND_SYNTIME;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_argdelete:
    while ((xp->xp_pattern = vim_strchr((const char_u *)arg, ' ')) != NULL) {
      arg = (const char *)(xp->xp_pattern + 1);
    }
    xp->xp_context = EXPAND_ARGLIST;
    xp->xp_pattern = (char_u *)arg;
    break;

  case CMD_lua:
    xp->xp_context = EXPAND_LUA;
    break;

  default:
    break;
  }
  return NULL;
}

/// Skip a range specifier of the form: addr [,addr] [;addr] ..
///
/// Backslashed delimiters after / or ? will be skipped, and commands will
/// not be expanded between /'s and ?'s or after "'".
///
/// Also skip white space and ":" characters.
///
/// @param ctx  pointer to xp_context or NULL
///
/// @return the "cmd" pointer advanced to beyond the range.
char_u *skip_range(const char_u *cmd, int *ctx)
{
  unsigned delim;

  while (vim_strchr((char_u *)" \t0123456789.$%'/?-+,;\\", *cmd) != NULL) {
    if (*cmd == '\\') {
      if (cmd[1] == '?' || cmd[1] == '/' || cmd[1] == '&') {
        cmd++;
      } else {
        break;
      }
    } else if (*cmd == '\'') {
      if (*++cmd == NUL && ctx != NULL) {
        *ctx = EXPAND_NOTHING;
      }
    } else if (*cmd == '/' || *cmd == '?') {
      delim = *cmd++;
      while (*cmd != NUL && *cmd != delim) {
        if (*cmd++ == '\\' && *cmd != NUL) {
          ++cmd;
        }
      }
      if (*cmd == NUL && ctx != NULL) {
        *ctx = EXPAND_NOTHING;
      }
    }
    if (*cmd != NUL) {
      ++cmd;
    }
  }

  // Skip ":" and white space.
  cmd = skip_colon_white(cmd, false);

  return (char_u *)cmd;
}

static void addr_error(cmd_addr_T addr_type)
{
  if (addr_type == ADDR_NONE) {
    EMSG(_(e_norange));
  } else {
    EMSG(_(e_invrange));
  }
}

/// Get a single EX address
///
/// Set ptr to the next character after the part that was interpreted.
/// Set ptr to NULL when an error is encountered.
/// This may set the last used search pattern.
///
/// @param skip           only skip the address, don't use it
/// @param silent         no errors or side effects
/// @param to_other_file  flag: may jump to other file
/// @param address_count  1 for first, >1 after comma
///
/// @return               MAXLNUM when no Ex address was found.
static linenr_T get_address(exarg_T *eap, char_u **ptr, cmd_addr_T addr_type, int skip, bool silent,
                            int to_other_file, int address_count)
  FUNC_ATTR_NONNULL_ALL
{
  int c;
  int i;
  long n;
  char_u *cmd;
  pos_T pos;
  pos_T *fp;
  linenr_T lnum;
  buf_T *buf;

  cmd = skipwhite(*ptr);
  lnum = MAXLNUM;
  do {
    switch (*cmd) {
    case '.':                               // '.' - Cursor position
      ++cmd;
      switch (addr_type) {
      case ADDR_LINES:
      case ADDR_OTHER:
        lnum = curwin->w_cursor.lnum;
        break;
      case ADDR_WINDOWS:
        lnum = CURRENT_WIN_NR;
        break;
      case ADDR_ARGUMENTS:
        lnum = curwin->w_arg_idx + 1;
        break;
      case ADDR_LOADED_BUFFERS:
      case ADDR_BUFFERS:
        lnum = curbuf->b_fnum;
        break;
      case ADDR_TABS:
        lnum = CURRENT_TAB_NR;
        break;
      case ADDR_NONE:
      case ADDR_TABS_RELATIVE:
      case ADDR_UNSIGNED:
        addr_error(addr_type);
        cmd = NULL;
        goto error;
        break;
      case ADDR_QUICKFIX:
        lnum = qf_get_cur_idx(eap);
        break;
      case ADDR_QUICKFIX_VALID:
        lnum = qf_get_cur_valid_idx(eap);
        break;
      }
      break;

    case '$':                               // '$' - last line
      ++cmd;
      switch (addr_type) {
      case ADDR_LINES:
      case ADDR_OTHER:
        lnum = curbuf->b_ml.ml_line_count;
        break;
      case ADDR_WINDOWS:
        lnum = LAST_WIN_NR;
        break;
      case ADDR_ARGUMENTS:
        lnum = ARGCOUNT;
        break;
      case ADDR_LOADED_BUFFERS:
        buf = lastbuf;
        while (buf->b_ml.ml_mfp == NULL) {
          if (buf->b_prev == NULL) {
            break;
          }
          buf = buf->b_prev;
        }
        lnum = buf->b_fnum;
        break;
      case ADDR_BUFFERS:
        lnum = lastbuf->b_fnum;
        break;
      case ADDR_TABS:
        lnum = LAST_TAB_NR;
        break;
      case ADDR_NONE:
      case ADDR_TABS_RELATIVE:
      case ADDR_UNSIGNED:
        addr_error(addr_type);
        cmd = NULL;
        goto error;
        break;
      case ADDR_QUICKFIX:
        lnum = qf_get_size(eap);
        if (lnum == 0) {
          lnum = 1;
        }
        break;
      case ADDR_QUICKFIX_VALID:
        lnum = qf_get_valid_size(eap);
        if (lnum == 0) {
          lnum = 1;
        }
        break;
      }
      break;

    case '\'':                              // ''' - mark
      if (*++cmd == NUL) {
        cmd = NULL;
        goto error;
      }
      if (addr_type != ADDR_LINES) {
        addr_error(addr_type);
        cmd = NULL;
        goto error;
      }
      if (skip) {
        ++cmd;
      } else {
        /* Only accept a mark in another file when it is
         * used by itself: ":'M". */
        fp = getmark(*cmd, to_other_file && cmd[1] == NUL);
        ++cmd;
        if (fp == (pos_T *)-1) {
          // Jumped to another file.
          lnum = curwin->w_cursor.lnum;
        } else {
          if (check_mark(fp) == FAIL) {
            cmd = NULL;
            goto error;
          }
          lnum = fp->lnum;
        }
      }
      break;

    case '/':
    case '?':                           // '/' or '?' - search
      c = *cmd++;
      if (addr_type != ADDR_LINES) {
        addr_error(addr_type);
        cmd = NULL;
        goto error;
      }
      if (skip) {                       // skip "/pat/"
        cmd = skip_regexp(cmd, c, p_magic, NULL);
        if (*cmd == c) {
          ++cmd;
        }
      } else {
        int flags;

        pos = curwin->w_cursor;  // save curwin->w_cursor

        // When '/' or '?' follows another address, start from
        // there.
        if (lnum != MAXLNUM) {
          curwin->w_cursor.lnum = lnum;
        }

        // Start a forward search at the end of the line (unless
        // before the first line).
        // Start a backward search at the start of the line.
        // This makes sure we never match in the current
        // line, and can match anywhere in the
        // next/previous line.
        if (c == '/' && curwin->w_cursor.lnum > 0) {
          curwin->w_cursor.col = MAXCOL;
        } else {
          curwin->w_cursor.col = 0;
        }
        searchcmdlen = 0;
        flags = silent ? 0 : SEARCH_HIS | SEARCH_MSG;
        if (!do_search(NULL, c, c, cmd, 1L, flags, NULL)) {
          curwin->w_cursor = pos;
          cmd = NULL;
          goto error;
        }
        lnum = curwin->w_cursor.lnum;
        curwin->w_cursor = pos;
        // adjust command string pointer
        cmd += searchcmdlen;
      }
      break;

    case '\\':                      // "\?", "\/" or "\&", repeat search
      ++cmd;
      if (addr_type != ADDR_LINES) {
        addr_error(addr_type);
        cmd = NULL;
        goto error;
      }
      if (*cmd == '&') {
        i = RE_SUBST;
      } else if (*cmd == '?' || *cmd == '/') {
        i = RE_SEARCH;
      } else {
        EMSG(_(e_backslash));
        cmd = NULL;
        goto error;
      }

      if (!skip) {
        // When search follows another address, start from there.
        pos.lnum = (lnum != MAXLNUM) ? lnum : curwin->w_cursor.lnum;
        // Start the search just like for the above do_search().
        pos.col = (*cmd != '?') ? MAXCOL : 0;
        pos.coladd = 0;
        if (searchit(curwin, curbuf, &pos, NULL,
                     *cmd == '?' ? BACKWARD : FORWARD,
                     (char_u *)"", 1L, SEARCH_MSG, i, NULL) != FAIL) {
          lnum = pos.lnum;
        } else {
          cmd = NULL;
          goto error;
        }
      }
      ++cmd;
      break;

    default:
      if (ascii_isdigit(*cmd)) {                // absolute line number
        lnum = getdigits_long(&cmd, false, 0);
      }
    }

    for (;; ) {
      cmd = skipwhite(cmd);
      if (*cmd != '-' && *cmd != '+' && !ascii_isdigit(*cmd)) {
        break;
      }

      if (lnum == MAXLNUM) {
        switch (addr_type) {
        case ADDR_LINES:
        case ADDR_OTHER:
          // "+1" is same as ".+1"
          lnum = curwin->w_cursor.lnum;
          break;
        case ADDR_WINDOWS:
          lnum = CURRENT_WIN_NR;
          break;
        case ADDR_ARGUMENTS:
          lnum = curwin->w_arg_idx + 1;
          break;
        case ADDR_LOADED_BUFFERS:
        case ADDR_BUFFERS:
          lnum = curbuf->b_fnum;
          break;
        case ADDR_TABS:
          lnum = CURRENT_TAB_NR;
          break;
        case ADDR_TABS_RELATIVE:
          lnum = 1;
          break;
        case ADDR_QUICKFIX:
          lnum = qf_get_cur_idx(eap);
          break;
        case ADDR_QUICKFIX_VALID:
          lnum = qf_get_cur_valid_idx(eap);
          break;
        case ADDR_NONE:
        case ADDR_UNSIGNED:
          lnum = 0;
          break;
        }
      }

      if (ascii_isdigit(*cmd)) {
        i = '+';                        // "number" is same as "+number"
      } else {
        i = *cmd++;
      }
      if (!ascii_isdigit(*cmd)) {       // '+' is '+1', but '+0' is not '+1'
        n = 1;
      } else {
        n = getdigits(&cmd, true, 0);
      }

      if (addr_type == ADDR_TABS_RELATIVE) {
        EMSG(_(e_invrange));
        cmd = NULL;
        goto error;
      } else if (addr_type == ADDR_LOADED_BUFFERS || addr_type == ADDR_BUFFERS) {
        lnum = compute_buffer_local_count(addr_type, lnum, (i == '-') ? -1 * n : n);
      } else {
        // Relative line addressing, need to adjust for folded lines
        // now, but only do it after the first address.
        if (addr_type == ADDR_LINES && (i == '-' || i == '+')
            && address_count >= 2) {
          (void)hasFolding(lnum, NULL, &lnum);
        }
        if (i == '-') {
          lnum -= n;
        } else {
          lnum += n;
        }
      }
    }
  } while (*cmd == '/' || *cmd == '?');

error:
  *ptr = cmd;
  return lnum;
}

/*
 * Get flags from an Ex command argument.
 */
static void get_flags(exarg_T *eap)
{
  while (vim_strchr((char_u *)"lp#", *eap->arg) != NULL) {
    if (*eap->arg == 'l') {
      eap->flags |= EXFLAG_LIST;
    } else if (*eap->arg == 'p') {
      eap->flags |= EXFLAG_PRINT;
    } else {
      eap->flags |= EXFLAG_NR;
    }
    eap->arg = skipwhite(eap->arg + 1);
  }
}

/// Stub function for command which is Not Implemented. NI!
void ex_ni(exarg_T *eap)
{
  if (!eap->skip) {
    eap->errmsg = (char_u *)N_("E319: The command is not available in this version");
  }
}

/// Stub function for script command which is Not Implemented. NI!
/// Skips over ":perl <<EOF" constructs.
static void ex_script_ni(exarg_T *eap)
{
  if (!eap->skip) {
    ex_ni(eap);
  } else {
    size_t len;
    xfree(script_get(eap, &len));
  }
}

/*
 * Check range in Ex command for validity.
 * Return NULL when valid, error message when invalid.
 */
static char_u *invalid_range(exarg_T *eap)
{
  buf_T *buf;
  if (eap->line1 < 0 || eap->line2 < 0 || eap->line1 > eap->line2) {
    return (char_u *)_(e_invrange);
  }

  if (eap->argt & EX_RANGE) {
    switch (eap->addr_type) {
    case ADDR_LINES:
      if (eap->line2 > (curbuf->b_ml.ml_line_count
                        + (eap->cmdidx == CMD_diffget))) {
        return (char_u *)_(e_invrange);
      }
      break;
    case ADDR_ARGUMENTS:
      // add 1 if ARGCOUNT is 0
      if (eap->line2 > ARGCOUNT + (!ARGCOUNT)) {
        return (char_u *)_(e_invrange);
      }
      break;
    case ADDR_BUFFERS:
      if (eap->line1 < firstbuf->b_fnum
          || eap->line2 > lastbuf->b_fnum) {
        return (char_u *)_(e_invrange);
      }
      break;
    case ADDR_LOADED_BUFFERS:
      buf = firstbuf;
      while (buf->b_ml.ml_mfp == NULL) {
        if (buf->b_next == NULL) {
          return (char_u *)_(e_invrange);
        }
        buf = buf->b_next;
      }
      if (eap->line1 < buf->b_fnum) {
        return (char_u *)_(e_invrange);
      }
      buf = lastbuf;
      while (buf->b_ml.ml_mfp == NULL) {
        if (buf->b_prev == NULL) {
          return (char_u *)_(e_invrange);
        }
        buf = buf->b_prev;
      }
      if (eap->line2 > buf->b_fnum) {
        return (char_u *)_(e_invrange);
      }
      break;
    case ADDR_WINDOWS:
      if (eap->line2 > LAST_WIN_NR) {
        return (char_u *)_(e_invrange);
      }
      break;
    case ADDR_TABS:
      if (eap->line2 > LAST_TAB_NR) {
        return (char_u *)_(e_invrange);
      }
      break;
    case ADDR_TABS_RELATIVE:
    case ADDR_OTHER:
      // Any range is OK.
      break;
    case ADDR_QUICKFIX:
      assert(eap->line2 >= 0);
      // No error for value that is too big, will use the last entry.
      if (eap->line2 <= 0) {
        return (char_u *)_(e_invrange);
      }
      break;
    case ADDR_QUICKFIX_VALID:
      if ((eap->line2 != 1 && (size_t)eap->line2 > qf_get_valid_size(eap))
          || eap->line2 < 0) {
        return (char_u *)_(e_invrange);
      }
      break;
    case ADDR_UNSIGNED:
    case ADDR_NONE:
      // Will give an error elsewhere.
      break;
    }
  }
  return NULL;
}

/*
 * Correct the range for zero line number, if required.
 */
static void correct_range(exarg_T *eap)
{
  if (!(eap->argt & EX_ZEROR)) {  // zero in range not allowed
    if (eap->line1 == 0) {
      eap->line1 = 1;
    }
    if (eap->line2 == 0) {
      eap->line2 = 1;
    }
  }
}


/*
 * For a ":vimgrep" or ":vimgrepadd" command return a pointer past the
 * pattern.  Otherwise return eap->arg.
 */
static char_u *skip_grep_pat(exarg_T *eap)
{
  char_u *p = eap->arg;

  if (*p != NUL && (eap->cmdidx == CMD_vimgrep || eap->cmdidx == CMD_lvimgrep
                    || eap->cmdidx == CMD_vimgrepadd
                    || eap->cmdidx == CMD_lvimgrepadd
                    || grep_internal(eap->cmdidx))) {
    p = skip_vimgrep_pat(p, NULL, NULL);
    if (p == NULL) {
      p = eap->arg;
    }
  }
  return p;
}

/*
 * For the ":make" and ":grep" commands insert the 'makeprg'/'grepprg' option
 * in the command line, so that things like % get expanded.
 */
static char_u *replace_makeprg(exarg_T *eap, char_u *p, char_u **cmdlinep)
{
  char_u *new_cmdline;
  char_u *program;
  char_u *pos;
  char_u *ptr;
  int len;
  int i;

  /*
   * Don't do it when ":vimgrep" is used for ":grep".
   */
  if ((eap->cmdidx == CMD_make || eap->cmdidx == CMD_lmake
       || eap->cmdidx == CMD_grep || eap->cmdidx == CMD_lgrep
       || eap->cmdidx == CMD_grepadd
       || eap->cmdidx == CMD_lgrepadd)
      && !grep_internal(eap->cmdidx)) {
    if (eap->cmdidx == CMD_grep || eap->cmdidx == CMD_lgrep
        || eap->cmdidx == CMD_grepadd || eap->cmdidx == CMD_lgrepadd) {
      if (*curbuf->b_p_gp == NUL) {
        program = p_gp;
      } else {
        program = curbuf->b_p_gp;
      }
    } else {
      if (*curbuf->b_p_mp == NUL) {
        program = p_mp;
      } else {
        program = curbuf->b_p_mp;
      }
    }

    p = skipwhite(p);

    if ((pos = (char_u *)strstr((char *)program, "$*")) != NULL) {
      // replace $* by given arguments
      i = 1;
      while ((pos = (char_u *)strstr((char *)pos + 2, "$*")) != NULL) {
        ++i;
      }
      len = (int)STRLEN(p);
      new_cmdline = xmalloc(STRLEN(program) + i * (len - 2) + 1);
      ptr = new_cmdline;
      while ((pos = (char_u *)strstr((char *)program, "$*")) != NULL) {
        i = (int)(pos - program);
        memcpy(ptr, program, i);
        STRCPY(ptr += i, p);
        ptr += len;
        program = pos + 2;
      }
      STRCPY(ptr, program);
    } else {
      new_cmdline = xmalloc(STRLEN(program) + STRLEN(p) + 2);
      STRCPY(new_cmdline, program);
      STRCAT(new_cmdline, " ");
      STRCAT(new_cmdline, p);
    }
    msg_make(p);

    // 'eap->cmd' is not set here, because it is not used at CMD_make
    xfree(*cmdlinep);
    *cmdlinep = new_cmdline;
    p = new_cmdline;
  }
  return p;
}

// Expand file name in Ex command argument.
// When an error is detected, "errormsgp" is set to a non-NULL pointer.
// Return FAIL for failure, OK otherwise.
int expand_filename(exarg_T *eap, char_u **cmdlinep, char_u **errormsgp)
{
  int has_wildcards;            // need to expand wildcards
  char_u *repl;
  size_t srclen;
  char_u *p;
  int escaped;

  // Skip a regexp pattern for ":vimgrep[add] pat file..."
  p = skip_grep_pat(eap);

  /*
   * Decide to expand wildcards *before* replacing '%', '#', etc.  If
   * the file name contains a wildcard it should not cause expanding.
   * (it will be expanded anyway if there is a wildcard before replacing).
   */
  has_wildcards = path_has_wildcard(p);
  while (*p != NUL) {
    // Skip over `=expr`, wildcards in it are not expanded.
    if (p[0] == '`' && p[1] == '=') {
      p += 2;
      (void)skip_expr(&p);
      if (*p == '`') {
        ++p;
      }
      continue;
    }
    /*
     * Quick check if this cannot be the start of a special string.
     * Also removes backslash before '%', '#' and '<'.
     */
    if (vim_strchr((char_u *)"%#<", *p) == NULL) {
      ++p;
      continue;
    }

    /*
     * Try to find a match at this position.
     */
    repl = eval_vars(p, eap->arg, &srclen, &(eap->do_ecmd_lnum),
                     errormsgp, &escaped);
    if (*errormsgp != NULL) {           // error detected
      return FAIL;
    }
    if (repl == NULL) {                 // no match found
      p += srclen;
      continue;
    }

    /* Wildcards won't be expanded below, the replacement is taken
     * literally.  But do expand "~/file", "~user/file" and "$HOME/file". */
    if (vim_strchr(repl, '$') != NULL || vim_strchr(repl, '~') != NULL) {
      char_u *l = repl;

      repl = expand_env_save(repl);
      xfree(l);
    }

    /* Need to escape white space et al. with a backslash.
     * Don't do this for:
     * - replacement that already has been escaped: "##"
     * - shell commands (may have to use quotes instead).
     */
    if (!eap->usefilter
        && !escaped
        && eap->cmdidx != CMD_bang
        && eap->cmdidx != CMD_grep
        && eap->cmdidx != CMD_grepadd
        && eap->cmdidx != CMD_hardcopy
        && eap->cmdidx != CMD_lgrep
        && eap->cmdidx != CMD_lgrepadd
        && eap->cmdidx != CMD_lmake
        && eap->cmdidx != CMD_make
        && eap->cmdidx != CMD_terminal
        && !(eap->argt & EX_NOSPC)) {
      char_u *l;
#ifdef BACKSLASH_IN_FILENAME
      /* Don't escape a backslash here, because rem_backslash() doesn't
       * remove it later. */
      static char_u *nobslash = (char_u *)" \t\"|";
# define ESCAPE_CHARS nobslash
#else
# define ESCAPE_CHARS escape_chars
#endif

      for (l = repl; *l; ++l) {
        if (vim_strchr(ESCAPE_CHARS, *l) != NULL) {
          l = vim_strsave_escaped(repl, ESCAPE_CHARS);
          xfree(repl);
          repl = l;
          break;
        }
      }
    }

    // For a shell command a '!' must be escaped.
    if ((eap->usefilter
         || eap->cmdidx == CMD_bang
         || eap->cmdidx == CMD_terminal)
        && vim_strpbrk(repl, (char_u *)"!") != NULL) {
      char_u *l;

      l = vim_strsave_escaped(repl, (char_u *)"!");
      xfree(repl);
      repl = l;
    }

    p = repl_cmdline(eap, p, srclen, repl, cmdlinep);
    xfree(repl);
  }

  /*
   * One file argument: Expand wildcards.
   * Don't do this with ":r !command" or ":w !command".
   */
  if ((eap->argt & EX_NOSPC) && !eap->usefilter) {
    // Replace environment variables.
    if (has_wildcards) {
      /*
       * May expand environment variables.  This
       * can be done much faster with expand_env() than with
       * something else (e.g., calling a shell).
       * After expanding environment variables, check again
       * if there are still wildcards present.
       */
      if (vim_strchr(eap->arg, '$') != NULL
          || vim_strchr(eap->arg, '~') != NULL) {
        expand_env_esc(eap->arg, NameBuff, MAXPATHL, true, true, NULL);
        has_wildcards = path_has_wildcard(NameBuff);
        p = NameBuff;
      } else {
        p = NULL;
      }
      if (p != NULL) {
        (void)repl_cmdline(eap, eap->arg, STRLEN(eap->arg), p, cmdlinep);
      }
    }

    /*
     * Halve the number of backslashes (this is Vi compatible).
     * For Unix, when wildcards are expanded, this is
     * done by ExpandOne() below.
     */
#ifdef UNIX
    if (!has_wildcards)
#endif
    backslash_halve(eap->arg);

    if (has_wildcards) {
      expand_T xpc;
      int options = WILD_LIST_NOTFOUND | WILD_NOERROR | WILD_ADD_SLASH;

      ExpandInit(&xpc);
      xpc.xp_context = EXPAND_FILES;
      if (p_wic) {
        options += WILD_ICASE;
      }
      p = ExpandOne(&xpc, eap->arg, NULL, options, WILD_EXPAND_FREE);
      if (p == NULL) {
        return FAIL;
      }
      (void)repl_cmdline(eap, eap->arg, STRLEN(eap->arg), p, cmdlinep);
      xfree(p);
    }
  }
  return OK;
}

/*
 * Replace part of the command line, keeping eap->cmd, eap->arg and
 * eap->nextcmd correct.
 * "src" points to the part that is to be replaced, of length "srclen".
 * "repl" is the replacement string.
 * Returns a pointer to the character after the replaced string.
 */
static char_u *repl_cmdline(exarg_T *eap, char_u *src, size_t srclen, char_u *repl,
                            char_u **cmdlinep)
{
  /*
   * The new command line is build in new_cmdline[].
   * First allocate it.
   * Careful: a "+cmd" argument may have been NUL terminated.
   */
  size_t len = STRLEN(repl);
  size_t i = (size_t)(src - *cmdlinep) + STRLEN(src + srclen) + len + 3;
  if (eap->nextcmd != NULL) {
    i += STRLEN(eap->nextcmd);    // add space for next command
  }
  char_u *new_cmdline = xmalloc(i);

  /*
   * Copy the stuff before the expanded part.
   * Copy the expanded stuff.
   * Copy what came after the expanded part.
   * Copy the next commands, if there are any.
   */
  i = (size_t)(src - *cmdlinep);   // length of part before match
  memmove(new_cmdline, *cmdlinep, i);

  memmove(new_cmdline + i, repl, len);
  i += len;                             // remember the end of the string
  STRCPY(new_cmdline + i, src + srclen);
  src = new_cmdline + i;                // remember where to continue

  if (eap->nextcmd != NULL) {           // append next command
    i = STRLEN(new_cmdline) + 1;
    STRCPY(new_cmdline + i, eap->nextcmd);
    eap->nextcmd = new_cmdline + i;
  }
  eap->cmd = new_cmdline + (eap->cmd - *cmdlinep);
  eap->arg = new_cmdline + (eap->arg - *cmdlinep);
  if (eap->do_ecmd_cmd != NULL && eap->do_ecmd_cmd != dollar_command) {
    eap->do_ecmd_cmd = new_cmdline + (eap->do_ecmd_cmd - *cmdlinep);
  }
  xfree(*cmdlinep);
  *cmdlinep = new_cmdline;

  return src;
}

/*
 * Check for '|' to separate commands and '"' to start comments.
 */
void separate_nextcmd(exarg_T *eap)
{
  char_u *p;

  p = skip_grep_pat(eap);

  for (; *p; MB_PTR_ADV(p)) {
    if (*p == Ctrl_V) {
      if (eap->argt & (EX_CTRLV | EX_XFILE)) {
        p++;  // skip CTRL-V and next char
      } else {
        // remove CTRL-V and skip next char
        STRMOVE(p, p + 1);
      }
      if (*p == NUL) {  // stop at NUL after CTRL-V
        break;
      }
    } else if (p[0] == '`' && p[1] == '=' && (eap->argt & EX_XFILE)) {
      // Skip over `=expr` when wildcards are expanded.
      p += 2;
      (void)skip_expr(&p);
      if (*p == NUL) {  // stop at NUL after CTRL-V
        break;
      }
    } else if (
               // Check for '"': start of comment or '|': next command */
               // :@" does not start a comment!
               // :redir @" doesn't either.
               (*p == '"'
                && !(eap->argt & EX_NOTRLCOM)
                && (eap->cmdidx != CMD_at || p != eap->arg)
                && (eap->cmdidx != CMD_redir
                    || p != eap->arg + 1 || p[-1] != '@'))
               || *p == '|'
               || *p == '\n') {
      // We remove the '\' before the '|', unless EX_CTRLV is used
      // AND 'b' is present in 'cpoptions'.
      if ((vim_strchr(p_cpo, CPO_BAR) == NULL
           || !(eap->argt & EX_CTRLV)) && *(p - 1) == '\\') {
        STRMOVE(p - 1, p);  // remove the '\'
        p--;
      } else {
        eap->nextcmd = check_nextcmd(p);
        *p = NUL;
        break;
      }
    }
  }

  if (!(eap->argt & EX_NOTRLCOM)) {  // remove trailing spaces
    del_trailing_spaces(eap->arg);
  }
}

/*
 * get + command from ex argument
 */
static char_u *getargcmd(char_u **argp)
{
  char_u *arg = *argp;
  char_u *command = NULL;

  if (*arg == '+') {        // +[command]
    ++arg;
    if (ascii_isspace(*arg) || *arg == '\0') {
      command = dollar_command;
    } else {
      command = arg;
      arg = skip_cmd_arg(command, TRUE);
      if (*arg != NUL) {
        *arg++ = NUL;                   // terminate command with NUL
      }
    }

    arg = skipwhite(arg);       // skip over spaces
    *argp = arg;
  }
  return command;
}

/// Find end of "+command" argument.  Skip over "\ " and "\\".
///
/// @param rembs  TRUE to halve the number of backslashes
static char_u *skip_cmd_arg(char_u *p, int rembs)
{
  while (*p && !ascii_isspace(*p)) {
    if (*p == '\\' && p[1] != NUL) {
      if (rembs) {
        STRMOVE(p, p + 1);
      } else {
        ++p;
      }
    }
    MB_PTR_ADV(p);
  }
  return p;
}

int get_bad_opt(const char_u *p, exarg_T *eap)
  FUNC_ATTR_NONNULL_ALL
{
  if (STRICMP(p, "keep") == 0) {
    eap->bad_char = BAD_KEEP;
  } else if (STRICMP(p, "drop") == 0) {
    eap->bad_char = BAD_DROP;
  } else if (MB_BYTE2LEN(*p) == 1 && p[1] == NUL) {
    eap->bad_char = *p;
  } else {
    return FAIL;
  }
  return OK;
}

/*
 * Get "++opt=arg" argument.
 * Return FAIL or OK.
 */
static int getargopt(exarg_T *eap)
{
  char_u *arg = eap->arg + 2;
  int *pp = NULL;
  int bad_char_idx;
  char_u *p;

  // ":edit ++[no]bin[ary] file"
  if (STRNCMP(arg, "bin", 3) == 0 || STRNCMP(arg, "nobin", 5) == 0) {
    if (*arg == 'n') {
      arg += 2;
      eap->force_bin = FORCE_NOBIN;
    } else {
      eap->force_bin = FORCE_BIN;
    }
    if (!checkforcmd(&arg, "binary", 3)) {
      return FAIL;
    }
    eap->arg = skipwhite(arg);
    return OK;
  }

  // ":read ++edit file"
  if (STRNCMP(arg, "edit", 4) == 0) {
    eap->read_edit = TRUE;
    eap->arg = skipwhite(arg + 4);
    return OK;
  }

  if (STRNCMP(arg, "ff", 2) == 0) {
    arg += 2;
    pp = &eap->force_ff;
  } else if (STRNCMP(arg, "fileformat", 10) == 0) {
    arg += 10;
    pp = &eap->force_ff;
  } else if (STRNCMP(arg, "enc", 3) == 0) {
    if (STRNCMP(arg, "encoding", 8) == 0) {
      arg += 8;
    } else {
      arg += 3;
    }
    pp = &eap->force_enc;
  } else if (STRNCMP(arg, "bad", 3) == 0) {
    arg += 3;
    pp = &bad_char_idx;
  }

  if (pp == NULL || *arg != '=') {
    return FAIL;
  }

  ++arg;
  *pp = (int)(arg - eap->cmd);
  arg = skip_cmd_arg(arg, FALSE);
  eap->arg = skipwhite(arg);
  *arg = NUL;

  if (pp == &eap->force_ff) {
    if (check_ff_value(eap->cmd + eap->force_ff) == FAIL) {
      return FAIL;
    }
    eap->force_ff = eap->cmd[eap->force_ff];
  } else if (pp == &eap->force_enc) {
    // Make 'fileencoding' lower case.
    for (p = eap->cmd + eap->force_enc; *p != NUL; ++p) {
      *p = TOLOWER_ASC(*p);
    }
  } else {
    /* Check ++bad= argument.  Must be a single-byte character, "keep" or
     * "drop". */
    if (get_bad_opt(eap->cmd + bad_char_idx, eap) == FAIL) {
      return FAIL;
    }
  }

  return OK;
}

/// Handle the argument for a tabpage related ex command.
/// Returns a tabpage number.
/// When an error is encountered then eap->errmsg is set.
static int get_tabpage_arg(exarg_T *eap)
{
  int tab_number = 0;
  int unaccept_arg0 = (eap->cmdidx == CMD_tabmove) ? 0 : 1;

  if (eap->arg && *eap->arg != NUL) {
    char_u *p = eap->arg;
    char_u *p_save;
    int relative = 0;  // argument +N/-N means: go to N places to the
                       // right/left relative to the current position.

    if (*p == '-') {
      relative = -1;
      p++;
    } else if (*p == '+') {
      relative = 1;
      p++;
    }

    p_save = p;
    tab_number = getdigits(&p, false, tab_number);

    if (relative == 0) {
      if (STRCMP(p, "$") == 0) {
        tab_number = LAST_TAB_NR;
      } else if (STRCMP(p, "#") == 0) {
        tab_number = tabpage_index(lastused_tabpage);
      } else if (p == p_save || *p_save == '-' || *p != NUL
                 || tab_number > LAST_TAB_NR) {
        // No numbers as argument.
        eap->errmsg = e_invarg;
        goto theend;
      }
    } else {
      if (*p_save == NUL) {
        tab_number = 1;
      } else if (p == p_save || *p_save == '-' || *p != NUL || tab_number == 0) {
        // No numbers as argument.
        eap->errmsg = e_invarg;
        goto theend;
      }
      tab_number = tab_number * relative + tabpage_index(curtab);
      if (!unaccept_arg0 && relative == -1) {
        --tab_number;
      }
    }
    if (tab_number < unaccept_arg0 || tab_number > LAST_TAB_NR) {
      eap->errmsg = e_invarg;
    }
  } else if (eap->addr_count > 0) {
    if (unaccept_arg0 && eap->line2 == 0) {
      eap->errmsg = e_invrange;
      tab_number = 0;
    } else {
      tab_number = eap->line2;
      if (!unaccept_arg0 && *skipwhite(*eap->cmdlinep) == '-') {
        tab_number--;
        if (tab_number < unaccept_arg0) {
          eap->errmsg = e_invarg;
        }
      }
    }
  } else {
    switch (eap->cmdidx) {
    case CMD_tabnext:
      tab_number = tabpage_index(curtab) + 1;
      if (tab_number > LAST_TAB_NR) {
        tab_number = 1;
      }
      break;
    case CMD_tabmove:
      tab_number = LAST_TAB_NR;
      break;
    default:
      tab_number = tabpage_index(curtab);
    }
  }

theend:
  return tab_number;
}

/*
 * ":abbreviate" and friends.
 */
static void ex_abbreviate(exarg_T *eap)
{
  do_exmap(eap, TRUE);          // almost the same as mapping
}

/*
 * ":map" and friends.
 */
static void ex_map(exarg_T *eap)
{
  /*
   * If we are sourcing .exrc or .vimrc in current directory we
   * print the mappings for security reasons.
   */
  if (secure) {
    secure = 2;
    msg_outtrans(eap->cmd);
    msg_putchar('\n');
  }
  do_exmap(eap, FALSE);
}

/*
 * ":unmap" and friends.
 */
static void ex_unmap(exarg_T *eap)
{
  do_exmap(eap, FALSE);
}

/*
 * ":mapclear" and friends.
 */
static void ex_mapclear(exarg_T *eap)
{
  map_clear_mode(eap->cmd, eap->arg, eap->forceit, false);
}

/*
 * ":abclear" and friends.
 */
static void ex_abclear(exarg_T *eap)
{
  map_clear_mode(eap->cmd, eap->arg, true, true);
}

static void ex_autocmd(exarg_T *eap)
{
  // Disallow autocommands from .exrc and .vimrc in current
  // directory for security reasons.
  if (secure) {
    secure = 2;
    eap->errmsg = e_curdir;
  } else if (eap->cmdidx == CMD_autocmd) {
    do_autocmd(eap->arg, eap->forceit);
  } else {
    do_augroup(eap->arg, eap->forceit);
  }
}

/*
 * ":doautocmd": Apply the automatic commands to the current buffer.
 */
static void ex_doautocmd(exarg_T *eap)
{
  char_u *arg = eap->arg;
  int call_do_modelines = check_nomodeline(&arg);
  bool did_aucmd;

  (void)do_doautocmd(arg, false, &did_aucmd);
  // Only when there is no <nomodeline>.
  if (call_do_modelines && did_aucmd) {
    do_modelines(0);
  }
}

/*
 * :[N]bunload[!] [N] [bufname] unload buffer
 * :[N]bdelete[!] [N] [bufname] delete buffer from buffer list
 * :[N]bwipeout[!] [N] [bufname] delete buffer really
 */
static void ex_bunload(exarg_T *eap)
{
  eap->errmsg = do_bufdel(eap->cmdidx == CMD_bdelete ? DOBUF_DEL
                                                     : eap->cmdidx == CMD_bwipeout ? DOBUF_WIPE
                                                                                   : DOBUF_UNLOAD,
                          eap->arg,
                          eap->addr_count, (int)eap->line1, (int)eap->line2, eap->forceit);
}

/*
 * :[N]buffer [N]       to buffer N
 * :[N]sbuffer [N]      to buffer N
 */
static void ex_buffer(exarg_T *eap)
{
  if (*eap->arg) {
    eap->errmsg = e_trailing;
  } else {
    if (eap->addr_count == 0) {  // default is current buffer
      goto_buffer(eap, DOBUF_CURRENT, FORWARD, 0);
    } else {
      goto_buffer(eap, DOBUF_FIRST, FORWARD, (int)eap->line2);
    }
    if (eap->do_ecmd_cmd != NULL) {
      do_cmdline_cmd((char *)eap->do_ecmd_cmd);
    }
  }
}

/*
 * :[N]bmodified [N]    to next mod. buffer
 * :[N]sbmodified [N]   to next mod. buffer
 */
static void ex_bmodified(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_MOD, FORWARD, (int)eap->line2);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd((char *)eap->do_ecmd_cmd);
  }
}

/*
 * :[N]bnext [N]        to next buffer
 * :[N]sbnext [N]       split and to next buffer
 */
static void ex_bnext(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_CURRENT, FORWARD, (int)eap->line2);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd((char *)eap->do_ecmd_cmd);
  }
}

/*
 * :[N]bNext [N]        to previous buffer
 * :[N]bprevious [N]    to previous buffer
 * :[N]sbNext [N]       split and to previous buffer
 * :[N]sbprevious [N]   split and to previous buffer
 */
static void ex_bprevious(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_CURRENT, BACKWARD, (int)eap->line2);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd((char *)eap->do_ecmd_cmd);
  }
}

/*
 * :brewind             to first buffer
 * :bfirst              to first buffer
 * :sbrewind            split and to first buffer
 * :sbfirst             split and to first buffer
 */
static void ex_brewind(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_FIRST, FORWARD, 0);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd((char *)eap->do_ecmd_cmd);
  }
}

/*
 * :blast               to last buffer
 * :sblast              split and to last buffer
 */
static void ex_blast(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_LAST, BACKWARD, 0);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd((char *)eap->do_ecmd_cmd);
  }
}

int ends_excmd(int c) FUNC_ATTR_CONST
{
  return c == NUL || c == '|' || c == '"' || c == '\n';
}

/*
 * Return the next command, after the first '|' or '\n'.
 * Return NULL if not found.
 */
char_u *find_nextcmd(const char_u *p)
{
  while (*p != '|' && *p != '\n') {
    if (*p == NUL) {
      return NULL;
    }
    p++;
  }
  return (char_u *)p + 1;
}

/// Check if *p is a separator between Ex commands, skipping over white space.
/// Return NULL if it isn't, the following character if it is.
char_u *check_nextcmd(char_u *p)
{
  char_u *s = skipwhite(p);

  if (*s == '|' || *s == '\n') {
    return (s + 1);
  } else {
    return NULL;
  }
}

/// - if there are more files to edit
/// - and this is the last window
/// - and forceit not used
/// - and not repeated twice on a row
/// @return  FAIL and give error message if 'message' TRUE, return OK otherwise
///
/// @param   message  when FALSE check only, no messages
static int check_more(int message, bool forceit)
{
  int n = ARGCOUNT - curwin->w_arg_idx - 1;

  if (!forceit && only_one_window()
      && ARGCOUNT > 1 && !arg_had_last && n > 0 && quitmore == 0) {
    if (message) {
      if ((p_confirm || cmdmod.confirm) && curbuf->b_fname != NULL) {
        char_u buff[DIALOG_MSG_SIZE];

        if (n == 1) {
          STRLCPY(buff, _("1 more file to edit.  Quit anyway?"),
                  DIALOG_MSG_SIZE);
        } else {
          vim_snprintf((char *)buff, DIALOG_MSG_SIZE,
                       _("%d more files to edit.  Quit anyway?"), n);
        }
        if (vim_dialog_yesno(VIM_QUESTION, NULL, buff, 1) == VIM_YES) {
          return OK;
        }
        return FAIL;
      }
      if (n == 1) {
        EMSG(_("E173: 1 more file to edit"));
      } else {
        EMSGN(_("E173: %" PRId64 " more files to edit"), n);
      }
      quitmore = 2;                 // next try to quit is allowed
    }
    return FAIL;
  }
  return OK;
}

/*
 * Function given to ExpandGeneric() to obtain the list of command names.
 */
char_u *get_command_name(expand_T *xp, int idx)
{
  if (idx >= CMD_SIZE) {
    return get_user_command_name(idx);
  }
  return cmdnames[idx].cmd_name;
}

static int uc_add_command(char_u *name, size_t name_len, char_u *rep, uint32_t argt, long def,
                          int flags, int compl, char_u *compl_arg, cmd_addr_T addr_type, bool force)
  FUNC_ATTR_NONNULL_ARG(1, 3)
{
  ucmd_T *cmd = NULL;
  int i;
  int cmp = 1;
  char_u *rep_buf = NULL;
  garray_T *gap;

  replace_termcodes(rep, STRLEN(rep), &rep_buf, false, false, true,
                    CPO_TO_CPO_FLAGS);
  if (rep_buf == NULL) {
    // Can't replace termcodes - try using the string as is
    rep_buf = vim_strsave(rep);
  }

  // get address of growarray: global or in curbuf
  if (flags & UC_BUFFER) {
    gap = &curbuf->b_ucmds;
    if (gap->ga_itemsize == 0) {
      ga_init(gap, (int)sizeof(ucmd_T), 4);
    }
  } else {
    gap = &ucmds;
  }

  // Search for the command in the already defined commands.
  for (i = 0; i < gap->ga_len; ++i) {
    size_t len;

    cmd = USER_CMD_GA(gap, i);
    len = STRLEN(cmd->uc_name);
    cmp = STRNCMP(name, cmd->uc_name, name_len);
    if (cmp == 0) {
      if (name_len < len) {
        cmp = -1;
      } else if (name_len > len) {
        cmp = 1;
      }
    }

    if (cmp == 0) {
      // Command can be replaced with "command!" and when sourcing the
      // same script again, but only once.
      if (!force
          && (cmd->uc_script_ctx.sc_sid != current_sctx.sc_sid
              || cmd->uc_script_ctx.sc_seq == current_sctx.sc_seq)) {
        EMSG2(_("E174: Command already exists: add ! to replace it: %s"),
              name);
        goto fail;
      }

      XFREE_CLEAR(cmd->uc_rep);
      XFREE_CLEAR(cmd->uc_compl_arg);
      break;
    }

    // Stop as soon as we pass the name to add
    if (cmp < 0) {
      break;
    }
  }

  // Extend the array unless we're replacing an existing command
  if (cmp != 0) {
    ga_grow(gap, 1);

    char_u *const p = vim_strnsave(name, name_len);

    cmd = USER_CMD_GA(gap, i);
    memmove(cmd + 1, cmd, (gap->ga_len - i) * sizeof(ucmd_T));

    ++gap->ga_len;

    cmd->uc_name = p;
  }

  cmd->uc_rep = rep_buf;
  cmd->uc_argt = argt;
  cmd->uc_def = def;
  cmd->uc_compl = compl;
  cmd->uc_script_ctx = current_sctx;
  cmd->uc_script_ctx.sc_lnum += sourcing_lnum;
  cmd->uc_compl_arg = compl_arg;
  cmd->uc_addr_type = addr_type;

  return OK;

fail:
  xfree(rep_buf);
  xfree(compl_arg);
  return FAIL;
}


static struct {
  cmd_addr_T expand;
  char *name;
  char *shortname;
} addr_type_complete[] =
{
  { ADDR_ARGUMENTS, "arguments", "arg" },
  { ADDR_LINES, "lines", "line" },
  { ADDR_LOADED_BUFFERS, "loaded_buffers", "load" },
  { ADDR_TABS, "tabs", "tab" },
  { ADDR_BUFFERS, "buffers", "buf" },
  { ADDR_WINDOWS, "windows", "win" },
  { ADDR_QUICKFIX, "quickfix", "qf" },
  { ADDR_OTHER, "other", "?" },
  { ADDR_NONE, NULL, NULL }
};

/*
 * List of names for completion for ":command" with the EXPAND_ flag.
 * Must be alphabetical for completion.
 */
static const char *command_complete[] =
{
  [EXPAND_ARGLIST] = "arglist",
  [EXPAND_AUGROUP] = "augroup",
  [EXPAND_BEHAVE] = "behave",
  [EXPAND_BUFFERS] = "buffer",
  [EXPAND_CHECKHEALTH] = "checkhealth",
  [EXPAND_COLORS] = "color",
  [EXPAND_COMMANDS] = "command",
  [EXPAND_COMPILER] = "compiler",
  [EXPAND_CSCOPE] = "cscope",
  [EXPAND_USER_DEFINED] = "custom",
  [EXPAND_USER_LIST] = "customlist",
  [EXPAND_DIFF_BUFFERS] = "diff_buffer",
  [EXPAND_DIRECTORIES] = "dir",
  [EXPAND_ENV_VARS] = "environment",
  [EXPAND_EVENTS] = "event",
  [EXPAND_EXPRESSION] = "expression",
  [EXPAND_FILES] = "file",
  [EXPAND_FILES_IN_PATH] = "file_in_path",
  [EXPAND_FILETYPE] = "filetype",
  [EXPAND_FUNCTIONS] = "function",
  [EXPAND_HELP] = "help",
  [EXPAND_HIGHLIGHT] = "highlight",
  [EXPAND_HISTORY] = "history",
#ifdef HAVE_WORKING_LIBINTL
  [EXPAND_LOCALES] = "locale",
#endif
  [EXPAND_LUA] = "lua",
  [EXPAND_MAPCLEAR] = "mapclear",
  [EXPAND_MAPPINGS] = "mapping",
  [EXPAND_MENUS] = "menu",
  [EXPAND_MESSAGES] = "messages",
  [EXPAND_OWNSYNTAX] = "syntax",
  [EXPAND_SYNTIME] = "syntime",
  [EXPAND_SETTINGS] = "option",
  [EXPAND_PACKADD] = "packadd",
  [EXPAND_SHELLCMD] = "shellcmd",
  [EXPAND_SIGN] = "sign",
  [EXPAND_TAGS] = "tag",
  [EXPAND_TAGS_LISTFILES] = "tag_listfiles",
  [EXPAND_USER] = "user",
  [EXPAND_USER_VARS] = "var",
};

static char *get_command_complete(int arg)
{
  if (arg >= (int)(ARRAY_SIZE(command_complete))) {
    return NULL;
  } else {
    return (char *)command_complete[arg];
  }
}

static void uc_list(char_u *name, size_t name_len)
{
  int i, j;
  bool found = false;
  ucmd_T *cmd;
  uint32_t a;

  // In cmdwin, the alternative buffer should be used.
  garray_T *gap = (cmdwin_type != 0 && get_cmdline_type() == NUL)
    ? &prevwin->w_buffer->b_ucmds
    : &curbuf->b_ucmds;
  for (;; ) {
    for (i = 0; i < gap->ga_len; ++i) {
      cmd = USER_CMD_GA(gap, i);
      a = cmd->uc_argt;

      // Skip commands which don't match the requested prefix and
      // commands filtered out.
      if (STRNCMP(name, cmd->uc_name, name_len) != 0
          || message_filtered(cmd->uc_name)) {
        continue;
      }

      // Put out the title first time
      if (!found) {
        MSG_PUTS_TITLE(_("\n    Name              Args Address "
                         "Complete    Definition"));
      }
      found = true;
      msg_putchar('\n');
      if (got_int) {
        break;
      }

      // Special cases
      int len = 4;
      if (a & EX_BANG) {
        msg_putchar('!');
        len--;
      }
      if (a & EX_REGSTR) {
        msg_putchar('"');
        len--;
      }
      if (gap != &ucmds) {
        msg_putchar('b');
        len--;
      }
      if (a & EX_TRLBAR) {
        msg_putchar('|');
        len--;
      }
      while (len-- > 0) {
        msg_putchar(' ');
      }

      msg_outtrans_attr(cmd->uc_name, HL_ATTR(HLF_D));
      len = (int)STRLEN(cmd->uc_name) + 4;

      do {
        msg_putchar(' ');
        len++;
      } while (len < 22);

      // "over" is how much longer the name is than the column width for
      // the name, we'll try to align what comes after.
      const int over = len - 22;
      len = 0;

      // Arguments
      switch (a & (EX_EXTRA | EX_NOSPC | EX_NEEDARG)) {
      case 0:
        IObuff[len++] = '0';
        break;
      case (EX_EXTRA):
        IObuff[len++] = '*';
        break;
      case (EX_EXTRA | EX_NOSPC):
        IObuff[len++] = '?';
        break;
      case (EX_EXTRA | EX_NEEDARG):
        IObuff[len++] = '+';
        break;
      case (EX_EXTRA | EX_NOSPC | EX_NEEDARG):
        IObuff[len++] = '1';
        break;
      }

      do {
        IObuff[len++] = ' ';
      } while (len < 5 - over);

      // Address / Range
      if (a & (EX_RANGE | EX_COUNT)) {
        if (a & EX_COUNT) {
          // -count=N
          snprintf((char *)IObuff + len, IOSIZE, "%" PRId64 "c",
                   (int64_t)cmd->uc_def);
          len += (int)STRLEN(IObuff + len);
        } else if (a & EX_DFLALL) {
          IObuff[len++] = '%';
        } else if (cmd->uc_def >= 0) {
          // -range=N
          snprintf((char *)IObuff + len, IOSIZE, "%" PRId64 "",
                   (int64_t)cmd->uc_def);
          len += (int)STRLEN(IObuff + len);
        } else {
          IObuff[len++] = '.';
        }
      }

      do {
        IObuff[len++] = ' ';
      } while (len < 8 - over);

      // Address Type
      for (j = 0; addr_type_complete[j].expand != ADDR_NONE; j++) {
        if (addr_type_complete[j].expand != ADDR_LINES
            && addr_type_complete[j].expand == cmd->uc_addr_type) {
          STRCPY(IObuff + len, addr_type_complete[j].shortname);
          len += (int)STRLEN(IObuff + len);
          break;
        }
      }

      do {
        IObuff[len++] = ' ';
      } while (len < 13 - over);

      // Completion
      char *cmd_compl = get_command_complete(cmd->uc_compl);
      if (cmd_compl != NULL) {
        STRCPY(IObuff + len, get_command_complete(cmd->uc_compl));
        len += (int)STRLEN(IObuff + len);
      }

      do {
        IObuff[len++] = ' ';
      } while (len < 25 - over);

      IObuff[len] = '\0';
      msg_outtrans(IObuff);

      msg_outtrans_special(cmd->uc_rep, false,
                           name_len == 0 ? Columns - 47 : 0);
      if (p_verbose > 0) {
        last_set_msg(cmd->uc_script_ctx);
      }
      line_breakcheck();
      if (got_int) {
        break;
      }
    }
    if (gap == &ucmds || i < gap->ga_len) {
      break;
    }
    gap = &ucmds;
  }

  if (!found) {
    MSG(_("No user-defined commands found"));
  }
}

static int uc_scan_attr(char_u *attr, size_t len, uint32_t *argt, long *def, int *flags,
                        int *complp, char_u **compl_arg, cmd_addr_T *addr_type_arg)
  FUNC_ATTR_NONNULL_ALL
{
  char_u *p;

  if (len == 0) {
    EMSG(_("E175: No attribute specified"));
    return FAIL;
  }

  // First, try the simple attributes (no arguments)
  if (STRNICMP(attr, "bang", len) == 0) {
    *argt |= EX_BANG;
  } else if (STRNICMP(attr, "buffer", len) == 0) {
    *flags |= UC_BUFFER;
  } else if (STRNICMP(attr, "register", len) == 0) {
    *argt |= EX_REGSTR;
  } else if (STRNICMP(attr, "bar", len) == 0) {
    *argt |= EX_TRLBAR;
  } else {
    int i;
    char_u *val = NULL;
    size_t vallen = 0;
    size_t attrlen = len;

    // Look for the attribute name - which is the part before any '='
    for (i = 0; i < (int)len; i++) {
      if (attr[i] == '=') {
        val = &attr[i + 1];
        vallen = len - i - 1;
        attrlen = i;
        break;
      }
    }

    if (STRNICMP(attr, "nargs", attrlen) == 0) {
      if (vallen == 1) {
        if (*val == '0') {
          // Do nothing - this is the default;
        } else if (*val == '1') {
          *argt |= (EX_EXTRA | EX_NOSPC | EX_NEEDARG);
        } else if (*val == '*') {
          *argt |= EX_EXTRA;
        } else if (*val == '?') {
          *argt |= (EX_EXTRA | EX_NOSPC);
        } else if (*val == '+') {
          *argt |= (EX_EXTRA | EX_NEEDARG);
        } else {
          goto wrong_nargs;
        }
      } else {
wrong_nargs:
        EMSG(_("E176: Invalid number of arguments"));
        return FAIL;
      }
    } else if (STRNICMP(attr, "range", attrlen) == 0) {
      *argt |= EX_RANGE;
      if (vallen == 1 && *val == '%') {
        *argt |= EX_DFLALL;
      } else if (val != NULL) {
        p = val;
        if (*def >= 0) {
two_count:
          EMSG(_("E177: Count cannot be specified twice"));
          return FAIL;
        }

        *def = getdigits_long(&p, true, 0);
        *argt |= EX_ZEROR;

        if (p != val + vallen || vallen == 0) {
invalid_count:
          EMSG(_("E178: Invalid default value for count"));
          return FAIL;
        }
      }
      // default for -range is using buffer lines
      if (*addr_type_arg == ADDR_NONE) {
        *addr_type_arg = ADDR_LINES;
      }
    } else if (STRNICMP(attr, "count", attrlen) == 0) {
      *argt |= (EX_COUNT | EX_ZEROR | EX_RANGE);
      // default for -count is using any number
      if (*addr_type_arg == ADDR_NONE) {
        *addr_type_arg = ADDR_OTHER;
      }

      if (val != NULL) {
        p = val;
        if (*def >= 0) {
          goto two_count;
        }

        *def = getdigits_long(&p, true, 0);

        if (p != val + vallen) {
          goto invalid_count;
        }
      }

      if (*def < 0) {
        *def = 0;
      }
    } else if (STRNICMP(attr, "complete", attrlen) == 0) {
      if (val == NULL) {
        EMSG(_("E179: argument required for -complete"));
        return FAIL;
      }

      if (parse_compl_arg(val, (int)vallen, complp, argt, compl_arg)
          == FAIL) {
        return FAIL;
      }
    } else if (STRNICMP(attr, "addr", attrlen) == 0) {
      *argt |= EX_RANGE;
      if (val == NULL) {
        EMSG(_("E179: argument required for -addr"));
        return FAIL;
      }
      if (parse_addr_type_arg(val, (int)vallen, addr_type_arg) == FAIL) {
        return FAIL;
      }
      if (*addr_type_arg != ADDR_LINES) {
        *argt |= EX_ZEROR;
      }
    } else {
      char_u ch = attr[len];
      attr[len] = '\0';
      EMSG2(_("E181: Invalid attribute: %s"), attr);
      attr[len] = ch;
      return FAIL;
    }
  }

  return OK;
}

static char e_complete_used_without_nargs[] = N_("E1208: -complete used without -nargs");

/*
 * ":command ..."
 */
static void ex_command(exarg_T *eap)
{
  char_u *name;
  char_u *end;
  char_u *p;
  uint32_t argt = 0;
  long def = -1;
  int flags = 0;
  int compl = EXPAND_NOTHING;
  char_u *compl_arg = NULL;
  cmd_addr_T addr_type_arg = ADDR_NONE;
  int has_attr = (eap->arg[0] == '-');
  int name_len;

  p = eap->arg;

  // Check for attributes
  while (*p == '-') {
    ++p;
    end = skiptowhite(p);
    if (uc_scan_attr(p, end - p, &argt, &def, &flags, &compl, &compl_arg,
                     &addr_type_arg) == FAIL) {
      return;
    }
    p = skipwhite(end);
  }

  // Get the name (if any) and skip to the following argument.
  name = p;
  if (ASCII_ISALPHA(*p)) {
    while (ASCII_ISALNUM(*p)) {
      p++;
    }
  }
  if (!ends_excmd(*p) && !ascii_iswhite(*p)) {
    EMSG(_("E182: Invalid command name"));
    return;
  }
  end = p;
  name_len = (int)(end - name);

  // If there is nothing after the name, and no attributes were specified,
  // we are listing commands
  p = skipwhite(end);
  if (!has_attr && ends_excmd(*p)) {
    uc_list(name, end - name);
  } else if (!ASCII_ISUPPER(*name)) {
    EMSG(_("E183: User defined commands must start with an uppercase letter"));
  } else if (name_len <= 4 && STRNCMP(name, "Next", name_len) == 0) {
    EMSG(_("E841: Reserved name, cannot be used for user defined command"));
  } else if (compl > 0 && (argt & EX_EXTRA) == 0) {
    EMSG(_(e_complete_used_without_nargs));
  } else {
    uc_add_command(name, end - name, p, argt, def, flags, compl, compl_arg,
                   addr_type_arg, eap->forceit);
  }
}

/*
 * ":comclear"
 * Clear all user commands, global and for current buffer.
 */
void ex_comclear(exarg_T *eap)
{
  uc_clear(&ucmds);
  uc_clear(&curbuf->b_ucmds);
}

static void free_ucmd(ucmd_T * cmd) {
  xfree(cmd->uc_name);
  xfree(cmd->uc_rep);
  xfree(cmd->uc_compl_arg);
}

/*
 * Clear all user commands for "gap".
 */
void uc_clear(garray_T *gap)
{
  GA_DEEP_CLEAR(gap, ucmd_T, free_ucmd);
}

static void ex_delcommand(exarg_T *eap)
{
  int i = 0;
  ucmd_T *cmd = NULL;
  int cmp = -1;
  garray_T *gap;

  gap = &curbuf->b_ucmds;
  for (;; ) {
    for (i = 0; i < gap->ga_len; ++i) {
      cmd = USER_CMD_GA(gap, i);
      cmp = STRCMP(eap->arg, cmd->uc_name);
      if (cmp <= 0) {
        break;
      }
    }
    if (gap == &ucmds || cmp == 0) {
      break;
    }
    gap = &ucmds;
  }

  if (cmp != 0) {
    EMSG2(_("E184: No such user-defined command: %s"), eap->arg);
    return;
  }

  xfree(cmd->uc_name);
  xfree(cmd->uc_rep);
  xfree(cmd->uc_compl_arg);

  --gap->ga_len;

  if (i < gap->ga_len) {
    memmove(cmd, cmd + 1, (gap->ga_len - i) * sizeof(ucmd_T));
  }
}

/*
 * split and quote args for <f-args>
 */
static char_u *uc_split_args(char_u *arg, size_t *lenp)
{
  char_u *buf;
  char_u *p;
  char_u *q;
  int len;

  // Precalculate length
  p = arg;
  len = 2;   // Initial and final quotes

  while (*p) {
    if (p[0] == '\\' && p[1] == '\\') {
      len += 2;
      p += 2;
    } else if (p[0] == '\\' && ascii_iswhite(p[1])) {
      len += 1;
      p += 2;
    } else if (*p == '\\' || *p == '"') {
      len += 2;
      p += 1;
    } else if (ascii_iswhite(*p)) {
      p = skipwhite(p);
      if (*p == NUL) {
        break;
      }
      len += 3;       // ","
    } else {
      const int charlen = utfc_ptr2len(p);

      len += charlen;
      p += charlen;
    }
  }

  buf = xmalloc(len + 1);

  p = arg;
  q = buf;
  *q++ = '"';
  while (*p) {
    if (p[0] == '\\' && p[1] == '\\') {
      *q++ = '\\';
      *q++ = '\\';
      p += 2;
    } else if (p[0] == '\\' && ascii_iswhite(p[1])) {
      *q++ = p[1];
      p += 2;
    } else if (*p == '\\' || *p == '"') {
      *q++ = '\\';
      *q++ = *p++;
    } else if (ascii_iswhite(*p)) {
      p = skipwhite(p);
      if (*p == NUL) {
        break;
      }
      *q++ = '"';
      *q++ = ',';
      *q++ = '"';
    } else {
      MB_COPY_CHAR(p, q);
    }
  }
  *q++ = '"';
  *q = 0;

  *lenp = len;
  return buf;
}

static size_t add_cmd_modifier(char_u *buf, char *mod_str, bool *multi_mods)
{
  size_t result = STRLEN(mod_str);
  if (*multi_mods) {
    result++;
  }

  if (buf != NULL) {
    if (*multi_mods) {
      STRCAT(buf, " ");
    }
    STRCAT(buf, mod_str);
  }

  *multi_mods = true;
  return result;
}

/// Check for a <> code in a user command.
///
/// @param code       points to the '<'.  "len" the length of the <> (inclusive).
/// @param buf        is where the result is to be added.
/// @param cmd        the user command we're expanding
/// @param eap        ex arguments
/// @param split_buf  points to a buffer used for splitting, caller should free it.
/// @param split_len  is the length of what "split_buf" contains.
///
/// @return           the length of the replacement, which has been added to "buf".
///                   Return -1 if there was no match, and only the "<" has been copied.
static size_t uc_check_code(char_u *code, size_t len, char_u *buf, ucmd_T *cmd, exarg_T *eap,
                            char_u **split_buf, size_t *split_len)
{
  size_t result = 0;
  char_u *p = code + 1;
  size_t l = len - 2;
  int quote = 0;
  enum {
    ct_ARGS,
    ct_BANG,
    ct_COUNT,
    ct_LINE1,
    ct_LINE2,
    ct_RANGE,
    ct_MODS,
    ct_REGISTER,
    ct_LT,
    ct_NONE
  } type = ct_NONE;

  if ((vim_strchr((char_u *)"qQfF", *p) != NULL) && p[1] == '-') {
    quote = (*p == 'q' || *p == 'Q') ? 1 : 2;
    p += 2;
    l -= 2;
  }

  l++;
  if (l <= 1) {
    type = ct_NONE;
  } else if (STRNICMP(p, "args>", l) == 0) {
    type = ct_ARGS;
  } else if (STRNICMP(p, "bang>", l) == 0) {
    type = ct_BANG;
  } else if (STRNICMP(p, "count>", l) == 0) {
    type = ct_COUNT;
  } else if (STRNICMP(p, "line1>", l) == 0) {
    type = ct_LINE1;
  } else if (STRNICMP(p, "line2>", l) == 0) {
    type = ct_LINE2;
  } else if (STRNICMP(p, "range>", l) == 0) {
    type = ct_RANGE;
  } else if (STRNICMP(p, "lt>", l) == 0) {
    type = ct_LT;
  } else if (STRNICMP(p, "reg>", l) == 0 || STRNICMP(p, "register>", l) == 0) {
    type = ct_REGISTER;
  } else if (STRNICMP(p, "mods>", l) == 0) {
    type = ct_MODS;
  }

  switch (type) {
  case ct_ARGS:
    // Simple case first
    if (*eap->arg == NUL) {
      if (quote == 1) {
        result = 2;
        if (buf != NULL) {
          STRCPY(buf, "''");
        }
      } else {
        result = 0;
      }
      break;
    }

    /* When specified there is a single argument don't split it.
     * Works for ":Cmd %" when % is "a b c". */
    if ((eap->argt & EX_NOSPC) && quote == 2) {
      quote = 1;
    }

    switch (quote) {
    case 0:     // No quoting, no splitting
      result = STRLEN(eap->arg);
      if (buf != NULL) {
        STRCPY(buf, eap->arg);
      }
      break;
    case 1:     // Quote, but don't split
      result = STRLEN(eap->arg) + 2;
      for (p = eap->arg; *p; p++) {
        if (*p == '\\' || *p == '"') {
          result++;
        }
      }

      if (buf != NULL) {
        *buf++ = '"';
        for (p = eap->arg; *p; p++) {
          if (*p == '\\' || *p == '"') {
            *buf++ = '\\';
          }
          *buf++ = *p;
        }
        *buf = '"';
      }

      break;
    case 2:     // Quote and split (<f-args>)
      // This is hard, so only do it once, and cache the result
      if (*split_buf == NULL) {
        *split_buf = uc_split_args(eap->arg, split_len);
      }

      result = *split_len;
      if (buf != NULL && result != 0) {
        STRCPY(buf, *split_buf);
      }

      break;
    }
    break;

  case ct_BANG:
    result = eap->forceit ? 1 : 0;
    if (quote) {
      result += 2;
    }
    if (buf != NULL) {
      if (quote) {
        *buf++ = '"';
      }
      if (eap->forceit) {
        *buf++ = '!';
      }
      if (quote) {
        *buf = '"';
      }
    }
    break;

  case ct_LINE1:
  case ct_LINE2:
  case ct_RANGE:
  case ct_COUNT: {
    char num_buf[20];
    long num = (type == ct_LINE1) ? eap->line1 :
               (type == ct_LINE2) ? eap->line2 :
               (type == ct_RANGE) ? eap->addr_count :
               (eap->addr_count > 0) ? eap->line2 : cmd->uc_def;
    size_t num_len;

    sprintf(num_buf, "%" PRId64, (int64_t)num);
    num_len = STRLEN(num_buf);
    result = num_len;

    if (quote) {
      result += 2;
    }

    if (buf != NULL) {
      if (quote) {
        *buf++ = '"';
      }
      STRCPY(buf, num_buf);
      buf += num_len;
      if (quote) {
        *buf = '"';
      }
    }

    break;
  }

  case ct_MODS: {
    result = quote ? 2 : 0;
    if (buf != NULL) {
      if (quote) {
        *buf++ = '"';
      }
      *buf = '\0';
    }

    bool multi_mods = false;

    // :aboveleft and :leftabove
    if (cmdmod.split & WSP_ABOVE) {
      result += add_cmd_modifier(buf, "aboveleft", &multi_mods);
    }
    // :belowright and :rightbelow
    if (cmdmod.split & WSP_BELOW) {
      result += add_cmd_modifier(buf, "belowright", &multi_mods);
    }
    // :botright
    if (cmdmod.split & WSP_BOT) {
      result += add_cmd_modifier(buf, "botright", &multi_mods);
    }

    typedef struct {
      bool *set;
      char *name;
    } mod_entry_T;
    static mod_entry_T mod_entries[] = {
      { &cmdmod.browse, "browse" },
      { &cmdmod.confirm, "confirm" },
      { &cmdmod.hide, "hide" },
      { &cmdmod.keepalt, "keepalt" },
      { &cmdmod.keepjumps, "keepjumps" },
      { &cmdmod.keepmarks, "keepmarks" },
      { &cmdmod.keeppatterns, "keeppatterns" },
      { &cmdmod.lockmarks, "lockmarks" },
      { &cmdmod.noswapfile, "noswapfile" }
    };
    // the modifiers that are simple flags
    for (size_t i = 0; i < ARRAY_SIZE(mod_entries); i++) {
      if (*mod_entries[i].set) {
        result += add_cmd_modifier(buf, mod_entries[i].name, &multi_mods);
      }
    }

    // TODO(vim): How to support :noautocmd?
    // TODO(vim): How to support :sandbox?

    // :silent
    if (msg_silent > 0) {
      result += add_cmd_modifier(buf, emsg_silent > 0 ? "silent!" : "silent",
                                 &multi_mods);
    }
    // :tab
    if (cmdmod.tab > 0) {
      result += add_cmd_modifier(buf, "tab", &multi_mods);
    }
    // :topleft
    if (cmdmod.split & WSP_TOP) {
      result += add_cmd_modifier(buf, "topleft", &multi_mods);
    }

    // TODO(vim): How to support :unsilent?

    // :verbose
    if (p_verbose > 0) {
      result += add_cmd_modifier(buf, "verbose", &multi_mods);
    }
    // :vertical
    if (cmdmod.split & WSP_VERT) {
      result += add_cmd_modifier(buf, "vertical", &multi_mods);
    }
    if (quote && buf != NULL) {
      buf += result - 2;
      *buf = '"';
    }
    break;
  }

  case ct_REGISTER:
    result = eap->regname ? 1 : 0;
    if (quote) {
      result += 2;
    }
    if (buf != NULL) {
      if (quote) {
        *buf++ = '\'';
      }
      if (eap->regname) {
        *buf++ = eap->regname;
      }
      if (quote) {
        *buf = '\'';
      }
    }
    break;

  case ct_LT:
    result = 1;
    if (buf != NULL) {
      *buf = '<';
    }
    break;

  default:
    // Not recognized: just copy the '<' and return -1.
    result = (size_t)-1;
    if (buf != NULL) {
      *buf = '<';
    }
    break;
  }

  return result;
}

static void do_ucmd(exarg_T *eap)
{
  char_u *buf;
  char_u *p;
  char_u *q;

  char_u *start;
  char_u *end = NULL;
  char_u *ksp;
  size_t len, totlen;

  size_t split_len = 0;
  char_u *split_buf = NULL;
  ucmd_T *cmd;
  const sctx_T save_current_sctx = current_sctx;

  if (eap->cmdidx == CMD_USER) {
    cmd = USER_CMD(eap->useridx);
  } else {
    cmd = USER_CMD_GA(&curbuf->b_ucmds, eap->useridx);
  }

  /*
   * Replace <> in the command by the arguments.
   * First round: "buf" is NULL, compute length, allocate "buf".
   * Second round: copy result into "buf".
   */
  buf = NULL;
  for (;; ) {
    p = cmd->uc_rep;        // source
    q = buf;                // destination
    totlen = 0;

    for (;; ) {
      start = vim_strchr(p, '<');
      if (start != NULL) {
        end = vim_strchr(start + 1, '>');
      }
      if (buf != NULL) {
        for (ksp = p; *ksp != NUL && *ksp != K_SPECIAL; ksp++) {
        }
        if (*ksp == K_SPECIAL
            && (start == NULL || ksp < start || end == NULL)
            && (ksp[1] == KS_SPECIAL && ksp[2] == KE_FILLER)) {
          // K_SPECIAL has been put in the buffer as K_SPECIAL
          // KS_SPECIAL KE_FILLER, like for mappings, but
          // do_cmdline() doesn't handle that, so convert it back.
          // Also change K_SPECIAL KS_EXTRA KE_CSI into CSI.
          len = ksp - p;
          if (len > 0) {
            memmove(q, p, len);
            q += len;
          }
          *q++ = K_SPECIAL;
          p = ksp + 3;
          continue;
        }
      }

      // break if there no <item> is found
      if (start == NULL || end == NULL) {
        break;
      }

      // Include the '>'
      ++end;

      // Take everything up to the '<'
      len = start - p;
      if (buf == NULL) {
        totlen += len;
      } else {
        memmove(q, p, len);
        q += len;
      }

      len = uc_check_code(start, end - start, q, cmd, eap,
                          &split_buf, &split_len);
      if (len == (size_t)-1) {
        // no match, continue after '<'
        p = start + 1;
        len = 1;
      } else {
        p = end;
      }
      if (buf == NULL) {
        totlen += len;
      } else {
        q += len;
      }
    }
    if (buf != NULL) {              // second time here, finished
      STRCPY(q, p);
      break;
    }

    totlen += STRLEN(p);            // Add on the trailing characters
    buf = xmalloc(totlen + 1);
  }

  current_sctx.sc_sid = cmd->uc_script_ctx.sc_sid;
  (void)do_cmdline(buf, eap->getline, eap->cookie,
                   DOCMD_VERBOSE|DOCMD_NOWAIT|DOCMD_KEYTYPED);
  current_sctx = save_current_sctx;
  xfree(buf);
  xfree(split_buf);
}

static char_u *get_user_command_name(int idx)
{
  return get_user_commands(NULL, idx - CMD_SIZE);
}
/*
 * Function given to ExpandGeneric() to obtain the list of user address type names.
 */
char_u *get_user_cmd_addr_type(expand_T *xp, int idx)
{
  return (char_u *)addr_type_complete[idx].name;
}

/*
 * Function given to ExpandGeneric() to obtain the list of user command names.
 */
char_u *get_user_commands(expand_T *xp FUNC_ATTR_UNUSED, int idx)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // In cmdwin, the alternative buffer should be used.
  const buf_T *const buf = (cmdwin_type != 0 && get_cmdline_type() == NUL)
    ? prevwin->w_buffer
    : curbuf;

  if (idx < buf->b_ucmds.ga_len) {
    return USER_CMD_GA(&buf->b_ucmds, idx)->uc_name;
  }
  idx -= buf->b_ucmds.ga_len;
  if (idx < ucmds.ga_len) {
    return USER_CMD(idx)->uc_name;
  }
  return NULL;
}

/*
 * Function given to ExpandGeneric() to obtain the list of user command
 * attributes.
 */
char_u *get_user_cmd_flags(expand_T *xp, int idx)
{
  static char *user_cmd_flags[] = { "addr",   "bang",     "bar",
                                    "buffer", "complete", "count",
                                    "nargs",  "range",    "register" };

  if (idx >= (int)ARRAY_SIZE(user_cmd_flags)) {
    return NULL;
  }
  return (char_u *)user_cmd_flags[idx];
}

/*
 * Function given to ExpandGeneric() to obtain the list of values for -nargs.
 */
char_u *get_user_cmd_nargs(expand_T *xp, int idx)
{
  static char *user_cmd_nargs[] = { "0", "1", "*", "?", "+" };

  if (idx >= (int)ARRAY_SIZE(user_cmd_nargs)) {
    return NULL;
  }
  return (char_u *)user_cmd_nargs[idx];
}

/*
 * Function given to ExpandGeneric() to obtain the list of values for -complete.
 */
char_u *get_user_cmd_complete(expand_T *xp, int idx)
{
  if (idx >= (int)ARRAY_SIZE(command_complete)) {
    return NULL;
  }
  char *cmd_compl = get_command_complete(idx);
  if (cmd_compl == NULL) {
    return (char_u *)"";
  } else {
    return (char_u *)cmd_compl;
  }
}

/*
 * Parse address type argument
 */
int parse_addr_type_arg(char_u *value, int vallen, cmd_addr_T *addr_type_arg)
  FUNC_ATTR_NONNULL_ALL
{
  int i, a, b;

  for (i = 0; addr_type_complete[i].expand != ADDR_NONE; i++) {
    a = (int)STRLEN(addr_type_complete[i].name) == vallen;
    b = STRNCMP(value, addr_type_complete[i].name, vallen) == 0;
    if (a && b) {
      *addr_type_arg = addr_type_complete[i].expand;
      break;
    }
  }

  if (addr_type_complete[i].expand == ADDR_NONE) {
    char_u *err = value;

    for (i = 0; err[i] != NUL && !ascii_iswhite(err[i]); i++) {}
    err[i] = NUL;
    EMSG2(_("E180: Invalid address type value: %s"), err);
    return FAIL;
  }

  return OK;
}

/*
 * Parse a completion argument "value[vallen]".
 * The detected completion goes in "*complp", argument type in "*argt".
 * When there is an argument, for function and user defined completion, it's
 * copied to allocated memory and stored in "*compl_arg".
 * Returns FAIL if something is wrong.
 */
int parse_compl_arg(const char_u *value, int vallen, int *complp, uint32_t *argt,
                    char_u **compl_arg)
  FUNC_ATTR_NONNULL_ALL
{
  const char_u *arg = NULL;
  size_t arglen = 0;
  int i;
  int valend = vallen;

  // Look for any argument part - which is the part after any ','
  for (i = 0; i < vallen; ++i) {
    if (value[i] == ',') {
      arg = &value[i + 1];
      arglen = vallen - i - 1;
      valend = i;
      break;
    }
  }

  for (i = 0; i < (int)ARRAY_SIZE(command_complete); i++) {
    if (get_command_complete(i) == NULL) {
      continue;
    }
    if ((int)STRLEN(command_complete[i]) == valend
        && STRNCMP(value, command_complete[i], valend) == 0) {
      *complp = i;
      if (i == EXPAND_BUFFERS) {
        *argt |= EX_BUFNAME;
      } else if (i == EXPAND_DIRECTORIES || i == EXPAND_FILES) {
        *argt |= EX_XFILE;
      }
      break;
    }
  }

  if (i == (int)ARRAY_SIZE(command_complete)) {
    EMSG2(_("E180: Invalid complete value: %s"), value);
    return FAIL;
  }

  if (*complp != EXPAND_USER_DEFINED && *complp != EXPAND_USER_LIST
      && arg != NULL) {
    EMSG(_("E468: Completion argument only allowed for custom completion"));
    return FAIL;
  }

  if ((*complp == EXPAND_USER_DEFINED || *complp == EXPAND_USER_LIST)
      && arg == NULL) {
    EMSG(_("E467: Custom completion requires a function argument"));
    return FAIL;
  }

  if (arg != NULL) {
    *compl_arg = vim_strnsave(arg, arglen);
  }
  return OK;
}

int cmdcomplete_str_to_type(const char *complete_str)
{
  for (int i = 0; i < (int)(ARRAY_SIZE(command_complete)); i++) {
    char *cmd_compl = get_command_complete(i);
    if (cmd_compl == NULL) {
      continue;
    }
    if (strcmp(complete_str, command_complete[i]) == 0) {
      return i;
    }
  }

  return EXPAND_NOTHING;
}

static void ex_colorscheme(exarg_T *eap)
{
  if (*eap->arg == NUL) {
    char_u *expr = vim_strsave((char_u *)"g:colors_name");
    char_u *p = NULL;

    emsg_off++;
    p = eval_to_string(expr, NULL, false);
    emsg_off--;
    xfree(expr);

    if (p != NULL) {
      MSG(p);
      xfree(p);
    } else {
      MSG("default");
    }
  } else if (load_colors(eap->arg) == FAIL) {
    EMSG2(_("E185: Cannot find color scheme '%s'"), eap->arg);
  }
}

static void ex_highlight(exarg_T *eap)
{
  if (*eap->arg == NUL && eap->cmd[2] == '!') {
    MSG(_("Greetings, Vim user!"));
  }
  do_highlight((const char *)eap->arg, eap->forceit, false);
}


/*
 * Call this function if we thought we were going to exit, but we won't
 * (because of an error).  May need to restore the terminal mode.
 */
void not_exiting(void)
{
  exiting = false;
}

bool before_quit_autocmds(win_T *wp, bool quit_all, bool forceit)
{
  apply_autocmds(EVENT_QUITPRE, NULL, NULL, false, wp->w_buffer);

  // Bail out when autocommands closed the window.
  // Refuse to quit when the buffer in the last window is being closed (can
  // only happen in autocommands).
  if (!win_valid(wp)
      || curbuf_locked()
      || (wp->w_buffer->b_nwindows == 1 && wp->w_buffer->b_locked > 0)) {
    return true;
  }

  if (quit_all
      || (check_more(false, forceit) == OK && only_one_window())) {
    apply_autocmds(EVENT_EXITPRE, NULL, NULL, false, curbuf);
    // Refuse to quit when locked or when the window was closed or the
    // buffer in the last window is being closed (can only happen in
    // autocommands).
    if (!win_valid(wp)
        || curbuf_locked()
        || (curbuf->b_nwindows == 1 && curbuf->b_locked > 0)) {
      return true;
    }
  }

  return false;
}

// ":quit": quit current window, quit Vim if the last window is closed.
// ":{nr}quit": quit window {nr}
static void ex_quit(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    cmdwin_result = Ctrl_C;
    return;
  }
  // Don't quit while editing the command line.
  if (text_locked()) {
    text_locked_msg();
    return;
  }

  win_T *wp;

  if (eap->addr_count > 0) {
    int wnr = eap->line2;

    for (wp = firstwin; wp->w_next != NULL; wp = wp->w_next) {
      if (--wnr <= 0) {
        break;
      }
    }
  } else {
    wp = curwin;
  }

  // Refuse to quit when locked.
  if (curbuf_locked()) {
    return;
  }

  // Trigger QuitPre and maybe ExitPre
  if (before_quit_autocmds(wp, false, eap->forceit)) {
    return;
  }

  // If there is only one relevant window we will exit.
  if (check_more(false, eap->forceit) == OK && only_one_window()) {
    exiting = true;
  }
  if ((!buf_hide(wp->w_buffer)
       && check_changed(wp->w_buffer, (p_awa ? CCGD_AW : 0)
                        | (eap->forceit ? CCGD_FORCEIT : 0)
                        | CCGD_EXCMD))
      || check_more(true, eap->forceit) == FAIL
      || (only_one_window() && check_changed_any(eap->forceit, true))) {
    not_exiting();
  } else {
    // quit last window
    // Note: only_one_window() returns true, even so a help window is
    // still open. In that case only quit, if no address has been
    // specified. Example:
    // :h|wincmd w|1q     - don't quit
    // :h|wincmd w|q      - quit
    if (only_one_window() && (ONE_WINDOW || eap->addr_count == 0)) {
      getout(0);
    }
    not_exiting();
    // close window; may free buffer
    win_close(wp, !buf_hide(wp->w_buffer) || eap->forceit);
  }
}

/// ":cquit".
static void ex_cquit(exarg_T *eap)
{
  // this does not always pass on the exit code to the Manx compiler. why?
  getout(eap->addr_count > 0 ? (int)eap->line2 : EXIT_FAILURE);
}

/// ":qall": try to quit all windows
static void ex_quit_all(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    if (eap->forceit) {
      cmdwin_result = K_XF1;            // open_cmdwin() takes care of this
    } else {
      cmdwin_result = K_XF2;
    }
    return;
  }

  // Don't quit while editing the command line.
  if (text_locked()) {
    text_locked_msg();
    return;
  }

  if (before_quit_autocmds(curwin, true, eap->forceit)) {
    return;
  }

  exiting = true;
  if (eap->forceit || !check_changed_any(false, false)) {
    getout(0);
  }
  not_exiting();
}

/*
 * ":close": close current window, unless it is the last one
 */
static void ex_close(exarg_T *eap)
{
  win_T *win = NULL;
  int winnr = 0;
  if (cmdwin_type != 0) {
    cmdwin_result = Ctrl_C;
  } else if (!text_locked() && !curbuf_locked()) {
    if (eap->addr_count == 0) {
      ex_win_close(eap->forceit, curwin, NULL);
    } else {
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        winnr++;
        if (winnr == eap->line2) {
          win = wp;
          break;
        }
      }
      if (win == NULL) {
        win = lastwin;
      }
      ex_win_close(eap->forceit, win, NULL);
    }
  }
}

/*
 * ":pclose": Close any preview window.
 */
static void ex_pclose(exarg_T *eap)
{
  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    if (win->w_p_pvw) {
      ex_win_close(eap->forceit, win, NULL);
      break;
    }
  }
}

/// Close window "win" and take care of handling closing the last window for a
/// modified buffer.
///
/// @param tp  NULL or the tab page "win" is in
void ex_win_close(int forceit, win_T *win, tabpage_T *tp)
{
  int need_hide;
  buf_T *buf = win->w_buffer;

  // Never close the autocommand window.
  if (win == aucmd_win) {
    EMSG(_(e_autocmd_close));
    return;
  }

  need_hide = (bufIsChanged(buf) && buf->b_nwindows <= 1);
  if (need_hide && !buf_hide(buf) && !forceit) {
    if ((p_confirm || cmdmod.confirm) && p_write) {
      bufref_T bufref;
      set_bufref(&bufref, buf);
      dialog_changed(buf, false);
      if (bufref_valid(&bufref) && bufIsChanged(buf)) {
        return;
      }
      need_hide = false;
    } else {
      no_write_message();
      return;
    }
  }


  // free buffer when not hiding it or when it's a scratch buffer
  if (tp == NULL) {
    win_close(win, !need_hide && !buf_hide(buf));
  } else {
    win_close_othertab(win, !need_hide && !buf_hide(buf), tp);
  }
}

/*
 * ":tabclose": close current tab page, unless it is the last one.
 * ":tabclose N": close tab page N.
 */
static void ex_tabclose(exarg_T *eap)
{
  tabpage_T *tp;

  if (cmdwin_type != 0) {
    cmdwin_result = K_IGNORE;
  } else if (first_tabpage->tp_next == NULL) {
    EMSG(_("E784: Cannot close last tab page"));
  } else {
    int tab_number = get_tabpage_arg(eap);
    if (eap->errmsg == NULL) {
      tp = find_tabpage(tab_number);
      if (tp == NULL) {
        beep_flush();
        return;
      }
      if (tp != curtab) {
        tabpage_close_other(tp, eap->forceit);
        return;
      } else if (!text_locked() && !curbuf_locked()) {
        tabpage_close(eap->forceit);
      }
    }
  }
}

/// ":tabonly": close all tab pages except the current one
static void ex_tabonly(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    cmdwin_result = K_IGNORE;
  } else if (first_tabpage->tp_next == NULL) {
    MSG(_("Already only one tab page"));
  } else {
    int tab_number = get_tabpage_arg(eap);
    if (eap->errmsg == NULL) {
      goto_tabpage(tab_number);
      // Repeat this up to a 1000 times, because autocommands may
      // mess up the lists.
      for (int done = 0; done < 1000; done++) {
        FOR_ALL_TABS(tp) {
          if (tp->tp_topframe != topframe) {
            tabpage_close_other(tp, eap->forceit);
            // if we failed to close it quit
            if (valid_tabpage(tp)) {
              done = 1000;
            }
            // start over, "tp" is now invalid
            break;
          }
        }
        assert(first_tabpage);
        if (first_tabpage->tp_next == NULL) {
          break;
        }
      }
    }
  }
}

/*
 * Close the current tab page.
 */
void tabpage_close(int forceit)
{
  // First close all the windows but the current one.  If that worked then
  // close the last window in this tab, that will close it.
  while (curwin->w_floating) {
    ex_win_close(forceit, curwin, NULL);
  }
  if (!ONE_WINDOW) {
    close_others(true, forceit);
  }
  if (ONE_WINDOW) {
    ex_win_close(forceit, curwin, NULL);
  }
}

/*
 * Close tab page "tp", which is not the current tab page.
 * Note that autocommands may make "tp" invalid.
 * Also takes care of the tab pages line disappearing when closing the
 * last-but-one tab page.
 */
void tabpage_close_other(tabpage_T *tp, int forceit)
{
  int done = 0;
  win_T *wp;
  int h = tabline_height();
  char_u prev_idx[NUMBUFLEN];

  /* Limit to 1000 windows, autocommands may add a window while we close
   * one.  OK, so I'm paranoid... */
  while (++done < 1000) {
    snprintf((char *)prev_idx, sizeof(prev_idx), "%i", tabpage_index(tp));
    wp = tp->tp_lastwin;
    ex_win_close(forceit, wp, tp);

    /* Autocommands may delete the tab page under our fingers and we may
     * fail to close a window with a modified buffer. */
    if (!valid_tabpage(tp) || tp->tp_firstwin == wp) {
      break;
    }
  }

  redraw_tabline = true;
  if (h != tabline_height()) {
    shell_new_rows();
  }
}

/*
 * ":only".
 */
static void ex_only(exarg_T *eap)
{
  win_T *wp;
  int wnr;

  if (eap->addr_count > 0) {
    wnr = eap->line2;
    for (wp = firstwin; --wnr > 0;) {
      if (wp->w_next == NULL) {
        break;
      } else {
        wp = wp->w_next;
      }
    }
  } else {
    wp = curwin;
  }
  if (wp != curwin) {
    win_goto(wp);
  }
  close_others(TRUE, eap->forceit);
}

/*
 * ":all" and ":sall".
 * Also used for ":tab drop file ..." after setting the argument list.
 */
void ex_all(exarg_T *eap)
{
  if (eap->addr_count == 0) {
    eap->line2 = 9999;
  }
  do_arg_all((int)eap->line2, eap->forceit, eap->cmdidx == CMD_drop);
}

static void ex_hide(exarg_T *eap)
{
  // ":hide" or ":hide | cmd": hide current window
  if (!eap->skip) {
    if (eap->addr_count == 0) {
      win_close(curwin, false);  // don't free buffer
    } else {
      int winnr = 0;
      win_T *win = NULL;

      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        winnr++;
        if (winnr == eap->line2) {
          win = wp;
          break;
        }
      }
      if (win == NULL) {
        win = lastwin;
      }
      win_close(win, false);
    }
  }
}

/// ":stop" and ":suspend": Suspend Vim.
static void ex_stop(exarg_T *eap)
{
  if (!eap->forceit) {
    autowrite_all();
  }
  apply_autocmds(EVENT_VIMSUSPEND, NULL, NULL, false, NULL);

  // TODO(bfredl): the TUI should do this on suspend
  ui_cursor_goto(Rows - 1, 0);
  ui_call_grid_scroll(1, 0, Rows, 0, Columns, 1, 0);
  ui_flush();
  ui_call_suspend();  // call machine specific function

  ui_flush();
  maketitle();
  resettitle();  // force updating the title
  ui_refresh();  // may have resized window
  apply_autocmds(EVENT_VIMRESUME, NULL, NULL, false, NULL);
}

// ":exit", ":xit" and ":wq": Write file and quit the current window.
static void ex_exit(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    cmdwin_result = Ctrl_C;
    return;
  }
  // Don't quit while editing the command line.
  if (text_locked()) {
    text_locked_msg();
    return;
  }

  // we plan to exit if there is only one relevant window
  if (check_more(false, eap->forceit) == OK && only_one_window()) {
    exiting = true;
  }
  // Write the buffer for ":wq" or when it was changed.
  // Trigger QuitPre and ExitPre.
  // Check if we can exit now, after autocommands have changed things.
  if (((eap->cmdidx == CMD_wq || curbufIsChanged()) && do_write(eap) == FAIL)
      || before_quit_autocmds(curwin, false, eap->forceit)
      || check_more(true, eap->forceit) == FAIL
      || (only_one_window() && check_changed_any(eap->forceit, false))) {
    not_exiting();
  } else {
    if (only_one_window()) {
      // quit last window, exit Vim
      getout(0);
    }
    not_exiting();
    // Quit current window, may free the buffer.
    win_close(curwin, !buf_hide(curwin->w_buffer));
  }
}

/*
 * ":print", ":list", ":number".
 */
static void ex_print(exarg_T *eap)
{
  if (curbuf->b_ml.ml_flags & ML_EMPTY) {
    EMSG(_(e_emptybuf));
  } else {
    for (; !got_int; os_breakcheck()) {
      print_line(eap->line1,
                 (eap->cmdidx == CMD_number || eap->cmdidx == CMD_pound
                  || (eap->flags & EXFLAG_NR)),
                 eap->cmdidx == CMD_list || (eap->flags & EXFLAG_LIST));
      if (++eap->line1 > eap->line2) {
        break;
      }
      ui_flush();                  // show one line at a time
    }
    setpcmark();
    // put cursor at last line
    curwin->w_cursor.lnum = eap->line2;
    beginline(BL_SOL | BL_FIX);
  }

  ex_no_reprint = true;
}

static void ex_goto(exarg_T *eap)
{
  goto_byte(eap->line2);
}

/*
 * Clear an argument list: free all file names and reset it to zero entries.
 */
void alist_clear(alist_T *al)
{
#define FREE_AENTRY_FNAME(arg) xfree(arg->ae_fname)
  GA_DEEP_CLEAR(&al->al_ga, aentry_T, FREE_AENTRY_FNAME);
}

/*
 * Init an argument list.
 */
void alist_init(alist_T *al)
{
  ga_init(&al->al_ga, (int)sizeof(aentry_T), 5);
}


/*
 * Remove a reference from an argument list.
 * Ignored when the argument list is the global one.
 * If the argument list is no longer used by any window, free it.
 */
void alist_unlink(alist_T *al)
{
  if (al != &global_alist && --al->al_refcount <= 0) {
    alist_clear(al);
    xfree(al);
  }
}

/*
 * Create a new argument list and use it for the current window.
 */
void alist_new(void)
{
  curwin->w_alist = xmalloc(sizeof(*curwin->w_alist));
  curwin->w_alist->al_refcount = 1;
  curwin->w_alist->id = ++max_alist_id;
  alist_init(curwin->w_alist);
}

#if !defined(UNIX)
/*
 * Expand the file names in the global argument list.
 * If "fnum_list" is not NULL, use "fnum_list[fnum_len]" as a list of buffer
 * numbers to be re-used.
 */
void alist_expand(int *fnum_list, int fnum_len)
{
  char_u **old_arg_files;
  int old_arg_count;
  char_u **new_arg_files;
  int new_arg_file_count;
  char_u *save_p_su = p_su;
  int i;

  /* Don't use 'suffixes' here.  This should work like the shell did the
   * expansion.  Also, the vimrc file isn't read yet, thus the user
   * can't set the options. */
  p_su = empty_option;
  old_arg_files = xmalloc(sizeof(*old_arg_files) * GARGCOUNT);
  for (i = 0; i < GARGCOUNT; ++i) {
    old_arg_files[i] = vim_strsave(GARGLIST[i].ae_fname);
  }
  old_arg_count = GARGCOUNT;
  if (expand_wildcards(old_arg_count, old_arg_files,
                       &new_arg_file_count, &new_arg_files,
                       EW_FILE|EW_NOTFOUND|EW_ADDSLASH|EW_NOERROR) == OK
      && new_arg_file_count > 0) {
    alist_set(&global_alist, new_arg_file_count, new_arg_files,
              TRUE, fnum_list, fnum_len);
    FreeWild(old_arg_count, old_arg_files);
  }
  p_su = save_p_su;
}
#endif

/*
 * Set the argument list for the current window.
 * Takes over the allocated files[] and the allocated fnames in it.
 */
void alist_set(alist_T *al, int count, char_u **files, int use_curbuf, int *fnum_list, int fnum_len)
{
  int i;
  static int recursive = 0;

  if (recursive) {
    EMSG(_(e_au_recursive));
    return;
  }
  recursive++;

  alist_clear(al);
  ga_grow(&al->al_ga, count);
  {
    for (i = 0; i < count; ++i) {
      if (got_int) {
        /* When adding many buffers this can take a long time.  Allow
         * interrupting here. */
        while (i < count) {
          xfree(files[i++]);
        }
        break;
      }

      /* May set buffer name of a buffer previously used for the
       * argument list, so that it's re-used by alist_add. */
      if (fnum_list != NULL && i < fnum_len) {
        buf_set_name(fnum_list[i], files[i]);
      }

      alist_add(al, files[i], use_curbuf ? 2 : 1);
      os_breakcheck();
    }
    xfree(files);
  }

  if (al == &global_alist) {
    arg_had_last = false;
  }
  recursive--;
}

/// Add file "fname" to argument list "al".
/// "fname" must have been allocated and "al" must have been checked for room.
///
/// @param set_fnum  1: set buffer number; 2: re-use curbuf
void alist_add(alist_T *al, char_u *fname, int set_fnum)
{
  if (fname == NULL) {          // don't add NULL file names
    return;
  }
#ifdef BACKSLASH_IN_FILENAME
  slash_adjust(fname);
#endif
  AARGLIST(al)[al->al_ga.ga_len].ae_fname = fname;
  if (set_fnum > 0) {
    AARGLIST(al)[al->al_ga.ga_len].ae_fnum =
      buflist_add(fname, BLN_LISTED | (set_fnum == 2 ? BLN_CURBUF : 0));
  }
  ++al->al_ga.ga_len;
}

#if defined(BACKSLASH_IN_FILENAME)
/*
 * Adjust slashes in file names.  Called after 'shellslash' was set.
 */
void alist_slash_adjust(void)
{
  for (int i = 0; i < GARGCOUNT; ++i) {
    if (GARGLIST[i].ae_fname != NULL) {
      slash_adjust(GARGLIST[i].ae_fname);
    }
  }

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_alist != &global_alist) {
      for (int i = 0; i < WARGCOUNT(wp); ++i) {
        if (WARGLIST(wp)[i].ae_fname != NULL) {
          slash_adjust(WARGLIST(wp)[i].ae_fname);
        }
      }
    }
  }
}

#endif

/// ":preserve".
static void ex_preserve(exarg_T *eap)
{
  curbuf->b_flags |= BF_PRESERVED;
  ml_preserve(curbuf, true, true);
}

/// ":recover".
static void ex_recover(exarg_T *eap)
{
  // Set recoverymode right away to avoid the ATTENTION prompt.
  recoverymode = true;
  if (!check_changed(curbuf, (p_awa ? CCGD_AW : 0)
                     | CCGD_MULTWIN
                     | (eap->forceit ? CCGD_FORCEIT : 0)
                     | CCGD_EXCMD)

      && (*eap->arg == NUL
          || setfname(curbuf, eap->arg, NULL, true) == OK)) {
    ml_recover(true);
  }
  recoverymode = false;
}

/*
 * Command modifier used in a wrong way.
 */
static void ex_wrongmodifier(exarg_T *eap)
{
  eap->errmsg = e_invcmd;
}

/*
 * :sview [+command] file       split window with new file, read-only
 * :split [[+command] file]     split window with current or new file
 * :vsplit [[+command] file]    split window vertically with current or new file
 * :new [[+command] file]       split window with no or new file
 * :vnew [[+command] file]      split vertically window with no or new file
 * :sfind [+command] file       split window with file in 'path'
 *
 * :tabedit                     open new Tab page with empty window
 * :tabedit [+command] file     open new Tab page and edit "file"
 * :tabnew [[+command] file]    just like :tabedit
 * :tabfind [+command] file     open new Tab page and find "file"
 */
void ex_splitview(exarg_T *eap)
{
  win_T *old_curwin = curwin;
  char_u *fname = NULL;
  const bool use_tab = eap->cmdidx == CMD_tabedit
                       || eap->cmdidx == CMD_tabfind
                       || eap->cmdidx == CMD_tabnew;

  /* A ":split" in the quickfix window works like ":new".  Don't want two
   * quickfix windows.  But it's OK when doing ":tab split". */
  if (bt_quickfix(curbuf) && cmdmod.tab == 0) {
    if (eap->cmdidx == CMD_split) {
      eap->cmdidx = CMD_new;
    }
    if (eap->cmdidx == CMD_vsplit) {
      eap->cmdidx = CMD_vnew;
    }
  }

  if (eap->cmdidx == CMD_sfind || eap->cmdidx == CMD_tabfind) {
    fname = find_file_in_path(eap->arg, STRLEN(eap->arg),
                              FNAME_MESS, TRUE, curbuf->b_ffname);
    if (fname == NULL) {
      goto theend;
    }
    eap->arg = fname;
  }

  /*
   * Either open new tab page or split the window.
   */
  if (use_tab) {
    if (win_new_tabpage(cmdmod.tab != 0 ? cmdmod.tab : eap->addr_count == 0
                        ? 0 : (int)eap->line2 + 1, eap->arg) != FAIL) {
      do_exedit(eap, old_curwin);
      apply_autocmds(EVENT_TABNEWENTERED, NULL, NULL, false, curbuf);

      // set the alternate buffer for the window we came from
      if (curwin != old_curwin
          && win_valid(old_curwin)
          && old_curwin->w_buffer != curbuf
          && !cmdmod.keepalt) {
        old_curwin->w_alt_fnum = curbuf->b_fnum;
      }
    }
  } else if (win_split(eap->addr_count > 0 ? (int)eap->line2 : 0,
                       *eap->cmd == 'v' ? WSP_VERT : 0) != FAIL) {
    /* Reset 'scrollbind' when editing another file, but keep it when
     * doing ":split" without arguments. */
    if (*eap->arg != NUL
        ) {
      RESET_BINDING(curwin);
    } else {
      do_check_scrollbind(false);
    }
    do_exedit(eap, old_curwin);
  }


theend:
  xfree(fname);
}

/*
 * Open a new tab page.
 */
void tabpage_new(void)
{
  exarg_T ea;

  memset(&ea, 0, sizeof(ea));
  ea.cmdidx = CMD_tabnew;
  ea.cmd = (char_u *)"tabn";
  ea.arg = (char_u *)"";
  ex_splitview(&ea);
}

/*
 * :tabnext command
 */
static void ex_tabnext(exarg_T *eap)
{
  int tab_number;

  switch (eap->cmdidx) {
  case CMD_tabfirst:
  case CMD_tabrewind:
    goto_tabpage(1);
    break;
  case CMD_tablast:
    goto_tabpage(9999);
    break;
  case CMD_tabprevious:
  case CMD_tabNext:
    if (eap->arg && *eap->arg != NUL) {
      char_u *p = eap->arg;
      char_u *p_save = p;
      tab_number = getdigits(&p, false, 0);
      if (p == p_save || *p_save == '-' || *p_save == '+' || *p != NUL
          || tab_number == 0) {
        // No numbers as argument.
        eap->errmsg = e_invarg;
        return;
      }
    } else {
      if (eap->addr_count == 0) {
        tab_number = 1;
      } else {
        tab_number = eap->line2;
        if (tab_number < 1) {
          eap->errmsg = e_invrange;
          return;
        }
      }
    }
    goto_tabpage(-tab_number);
    break;
  default:       // CMD_tabnext
    tab_number = get_tabpage_arg(eap);
    if (eap->errmsg == NULL) {
      goto_tabpage(tab_number);
    }
    break;
  }
}

/*
 * :tabmove command
 */
static void ex_tabmove(exarg_T *eap)
{
  int tab_number = get_tabpage_arg(eap);
  if (eap->errmsg == NULL) {
    tabpage_move(tab_number);
  }
}

/*
 * :tabs command: List tabs and their contents.
 */
static void ex_tabs(exarg_T *eap)
{
  int tabcount = 1;

  msg_start();
  msg_scroll = TRUE;

  win_T *lastused_win = valid_tabpage(lastused_tabpage)
    ? lastused_tabpage->tp_curwin
    : NULL;

  FOR_ALL_TABS(tp) {
    if (got_int) {
      break;
    }

    msg_putchar('\n');
    vim_snprintf((char *)IObuff, IOSIZE, _("Tab page %d"), tabcount++);
    msg_outtrans_attr(IObuff, HL_ATTR(HLF_T));
    ui_flush();            // output one line at a time
    os_breakcheck();

    FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
      if (got_int) {
        break;
      }

      msg_putchar('\n');
      msg_putchar(wp == curwin ? '>' : wp == lastused_win ? '#' : ' ');
      msg_putchar(' ');
      msg_putchar(bufIsChanged(wp->w_buffer) ? '+' : ' ');
      msg_putchar(' ');
      if (buf_spname(wp->w_buffer) != NULL) {
        STRLCPY(IObuff, buf_spname(wp->w_buffer), IOSIZE);
      } else {
        home_replace(wp->w_buffer, wp->w_buffer->b_fname, IObuff, IOSIZE, true);
      }
      msg_outtrans(IObuff);
      ui_flush();                  // output one line at a time
      os_breakcheck();
    }
  }
}


/*
 * ":mode":
 * If no argument given, get the screen size and redraw.
 */
static void ex_mode(exarg_T *eap)
{
  if (*eap->arg == NUL) {
    must_redraw = CLEAR;
    ex_redraw(eap);
  } else {
    EMSG(_(e_screenmode));
  }
}

/*
 * ":resize".
 * set, increment or decrement current window height
 */
static void ex_resize(exarg_T *eap)
{
  int n;
  win_T *wp = curwin;

  if (eap->addr_count > 0) {
    n = eap->line2;
    for (wp = firstwin; wp->w_next != NULL && --n > 0; wp = wp->w_next) {
      ;
    }
  }

  n = atol((char *)eap->arg);
  if (cmdmod.split & WSP_VERT) {
    if (*eap->arg == '-' || *eap->arg == '+') {
      n += wp->w_width;
    } else if (n == 0 && eap->arg[0] == NUL) {  // default is very wide
      n = Columns;
    }
    win_setwidth_win(n, wp);
  } else {
    if (*eap->arg == '-' || *eap->arg == '+') {
      n += wp->w_height;
    } else if (n == 0 && eap->arg[0] == NUL) {  // default is very high
      n = Rows-1;
    }
    win_setheight_win(n, wp);
  }
}

/*
 * ":find [+command] <file>" command.
 */
static void ex_find(exarg_T *eap)
{
  char_u *fname;
  int count;

  fname = find_file_in_path(eap->arg, STRLEN(eap->arg),
                            FNAME_MESS, TRUE, curbuf->b_ffname);
  if (eap->addr_count > 0) {
    /* Repeat finding the file "count" times.  This matters when it
     * appears several times in the path. */
    count = eap->line2;
    while (fname != NULL && --count > 0) {
      xfree(fname);
      fname = find_file_in_path(NULL, 0, FNAME_MESS, FALSE, curbuf->b_ffname);
    }
  }

  if (fname != NULL) {
    eap->arg = fname;
    do_exedit(eap, NULL);
    xfree(fname);
  }
}

/// ":edit", ":badd", ":balt", ":visual".
static void ex_edit(exarg_T *eap)
{
  do_exedit(eap, NULL);
}

/// ":edit <file>" command and alikes.
///
/// @param old_curwin  curwin before doing a split or NULL
void do_exedit(exarg_T *eap, win_T *old_curwin)
{
  int n;
  int need_hide;

  /*
   * ":vi" command ends Ex mode.
   */
  if (exmode_active && (eap->cmdidx == CMD_visual
                        || eap->cmdidx == CMD_view)) {
    exmode_active = false;
    ex_pressedreturn = false;
    if (*eap->arg == NUL) {
      // Special case:  ":global/pat/visual\NLvi-commands"
      if (global_busy) {
        int rd = RedrawingDisabled;
        int nwr = no_wait_return;
        int ms = msg_scroll;

        if (eap->nextcmd != NULL) {
          stuffReadbuff((const char *)eap->nextcmd);
          eap->nextcmd = NULL;
        }

        RedrawingDisabled = 0;
        no_wait_return = 0;
        need_wait_return = false;
        msg_scroll = 0;
        redraw_all_later(NOT_VALID);

        normal_enter(false, true);

        RedrawingDisabled = rd;
        no_wait_return = nwr;
        msg_scroll = ms;
      }
      return;
    }
  }

  if ((eap->cmdidx == CMD_new
       || eap->cmdidx == CMD_tabnew
       || eap->cmdidx == CMD_tabedit
       || eap->cmdidx == CMD_vnew
       ) && *eap->arg == NUL) {
    // ":new" or ":tabnew" without argument: edit an new empty buffer
    setpcmark();
    (void)do_ecmd(0, NULL, NULL, eap, ECMD_ONE,
                  ECMD_HIDE + (eap->forceit ? ECMD_FORCEIT : 0),
                  old_curwin == NULL ? curwin : NULL);
  } else if ((eap->cmdidx != CMD_split && eap->cmdidx != CMD_vsplit)
             || *eap->arg != NUL) {
    // Can't edit another file when "curbuf->b_ro_lockec" is set.  Only ":edit"
    // can bring us here, others are stopped earlier.
    if (*eap->arg != NUL && curbuf_locked()) {
      return;
    }
    n = readonlymode;
    if (eap->cmdidx == CMD_view || eap->cmdidx == CMD_sview) {
      readonlymode = true;
    } else if (eap->cmdidx == CMD_enew) {
      readonlymode = false;  // 'readonly' doesn't make sense
                             // in an empty buffer
    }
    if (eap->cmdidx != CMD_balt && eap->cmdidx != CMD_badd) {
      setpcmark();
    }
    if (do_ecmd(0, (eap->cmdidx == CMD_enew ? NULL : eap->arg),
                NULL, eap, eap->do_ecmd_lnum,
                (buf_hide(curbuf) ? ECMD_HIDE : 0)
                + (eap->forceit ? ECMD_FORCEIT : 0)
                // After a split we can use an existing buffer.
                + (old_curwin != NULL ? ECMD_OLDBUF : 0)
                + (eap->cmdidx == CMD_badd ? ECMD_ADDBUF : 0)
                + (eap->cmdidx == CMD_balt ? ECMD_ALTBUF : 0)
                , old_curwin == NULL ? curwin : NULL) == FAIL) {
      // Editing the file failed.  If the window was split, close it.
      if (old_curwin != NULL) {
        need_hide = (curbufIsChanged() && curbuf->b_nwindows <= 1);
        if (!need_hide || buf_hide(curbuf)) {
          cleanup_T cs;

          /* Reset the error/interrupt/exception state here so that
           * aborting() returns FALSE when closing a window. */
          enter_cleanup(&cs);
          win_close(curwin, !need_hide && !buf_hide(curbuf));

          /* Restore the error/interrupt/exception state if not
           * discarded by a new aborting error, interrupt, or
           * uncaught exception. */
          leave_cleanup(&cs);
        }
      }
    } else if (readonlymode && curbuf->b_nwindows == 1) {
      /* When editing an already visited buffer, 'readonly' won't be set
       * but the previous value is kept.  With ":view" and ":sview" we
       * want the  file to be readonly, except when another window is
       * editing the same buffer. */
      curbuf->b_p_ro = TRUE;
    }
    readonlymode = n;
  } else {
    if (eap->do_ecmd_cmd != NULL) {
      do_cmdline_cmd((char *)eap->do_ecmd_cmd);
    }
    n = curwin->w_arg_idx_invalid;
    check_arg_idx(curwin);
    if (n != curwin->w_arg_idx_invalid) {
      maketitle();
    }
  }

  /*
   * if ":split file" worked, set alternate file name in old window to new
   * file
   */
  if (old_curwin != NULL
      && *eap->arg != NUL
      && curwin != old_curwin
      && win_valid(old_curwin)
      && old_curwin->w_buffer != curbuf
      && !cmdmod.keepalt) {
    old_curwin->w_alt_fnum = curbuf->b_fnum;
  }

  ex_no_reprint = true;
}

/// ":gui" and ":gvim" when there is no GUI.
static void ex_nogui(exarg_T *eap)
{
  eap->errmsg = (char_u *)N_("E25: Nvim does not have a built-in GUI");
}



static void ex_swapname(exarg_T *eap)
{
  if (curbuf->b_ml.ml_mfp == NULL || curbuf->b_ml.ml_mfp->mf_fname == NULL) {
    MSG(_("No swap file"));
  } else {
    msg(curbuf->b_ml.ml_mfp->mf_fname);
  }
}

/*
 * ":syncbind" forces all 'scrollbind' windows to have the same relative
 * offset.
 * (1998-11-02 16:21:01  R. Edward Ralston <eralston@computer.org>)
 */
static void ex_syncbind(exarg_T *eap)
{
  win_T *save_curwin = curwin;
  buf_T *save_curbuf = curbuf;
  long topline;
  long y;
  linenr_T old_linenr = curwin->w_cursor.lnum;

  setpcmark();

  /*
   * determine max topline
   */
  if (curwin->w_p_scb) {
    topline = curwin->w_topline;
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_p_scb && wp->w_buffer) {
        y = wp->w_buffer->b_ml.ml_line_count - get_scrolloff_value(curwin);
        if (topline > y) {
          topline = y;
        }
      }
    }
    if (topline < 1) {
      topline = 1;
    }
  } else {
    topline = 1;
  }


  /*
   * Set all scrollbind windows to the same topline.
   */
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    curwin = wp;
    if (curwin->w_p_scb) {
      curbuf = curwin->w_buffer;
      y = topline - curwin->w_topline;
      if (y > 0) {
        scrollup(y, TRUE);
      } else {
        scrolldown(-y, TRUE);
      }
      curwin->w_scbind_pos = topline;
      redraw_later(curwin, VALID);
      cursor_correct();
      curwin->w_redr_status = TRUE;
    }
  }
  curwin = save_curwin;
  curbuf = save_curbuf;
  if (curwin->w_p_scb) {
    did_syncbind = true;
    checkpcmark();
    if (old_linenr != curwin->w_cursor.lnum) {
      char_u ctrl_o[2];

      ctrl_o[0] = Ctrl_O;
      ctrl_o[1] = 0;
      ins_typebuf(ctrl_o, REMAP_NONE, 0, true, false);
    }
  }
}


static void ex_read(exarg_T *eap)
{
  int i;
  int empty = (curbuf->b_ml.ml_flags & ML_EMPTY);
  linenr_T lnum;

  if (eap->usefilter) {  // :r!cmd
    do_bang(1, eap, false, false, true);
  } else {
    if (u_save(eap->line2, (linenr_T)(eap->line2 + 1)) == FAIL) {
      return;
    }

    if (*eap->arg == NUL) {
      if (check_fname() == FAIL) {       // check for no file name
        return;
      }
      i = readfile(curbuf->b_ffname, curbuf->b_fname,
                   eap->line2, (linenr_T)0, (linenr_T)MAXLNUM, eap, 0);
    } else {
      if (vim_strchr(p_cpo, CPO_ALTREAD) != NULL) {
        (void)setaltfname(eap->arg, eap->arg, (linenr_T)1);
      }
      i = readfile(eap->arg, NULL,
                   eap->line2, (linenr_T)0, (linenr_T)MAXLNUM, eap, 0);
    }
    if (i != OK) {
      if (!aborting()) {
        EMSG2(_(e_notopen), eap->arg);
      }
    } else {
      if (empty && exmode_active) {
        /* Delete the empty line that remains.  Historically ex does
         * this but vi doesn't. */
        if (eap->line2 == 0) {
          lnum = curbuf->b_ml.ml_line_count;
        } else {
          lnum = 1;
        }
        if (*ml_get(lnum) == NUL && u_savedel(lnum, 1L) == OK) {
          ml_delete(lnum, false);
          if (curwin->w_cursor.lnum > 1
              && curwin->w_cursor.lnum >= lnum) {
            curwin->w_cursor.lnum--;
          }
          deleted_lines_mark(lnum, 1L);
        }
      }
      redraw_curbuf_later(VALID);
    }
  }
}

static char_u *prev_dir = NULL;

#if defined(EXITFREE)
void free_cd_dir(void)
{
  XFREE_CLEAR(prev_dir);
  XFREE_CLEAR(globaldir);
}

#endif

/// Deal with the side effects of changing the current directory.
///
/// @param scope  Scope of the function call (global, tab or window).
void post_chdir(CdScope scope, bool trigger_dirchanged)
{
  // Always overwrite the window-local CWD.
  XFREE_CLEAR(curwin->w_localdir);

  // Overwrite the tab-local CWD for :cd, :tcd.
  if (scope >= kCdScopeTab) {
    XFREE_CLEAR(curtab->tp_localdir);
  }

  if (scope < kCdScopeGlobal) {
    // If still in global directory, set CWD as the global directory.
    if (globaldir == NULL && prev_dir != NULL) {
      globaldir = vim_strsave(prev_dir);
    }
  }

  char cwd[MAXPATHL];
  if (os_dirname((char_u *)cwd, MAXPATHL) != OK) {
    return;
  }
  switch (scope) {
  case kCdScopeGlobal:
    // We are now in the global directory, no need to remember its name.
    XFREE_CLEAR(globaldir);
    break;
  case kCdScopeTab:
    curtab->tp_localdir = (char_u *)xstrdup(cwd);
    break;
  case kCdScopeWindow:
    curwin->w_localdir = (char_u *)xstrdup(cwd);
    break;
  case kCdScopeInvalid:
    abort();
  }

  shorten_fnames(true);

  if (trigger_dirchanged) {
    do_autocmd_dirchanged(cwd, scope, false);
  }
}

/// `:cd`, `:tcd`, `:lcd`, `:chdir`, `:tchdir` and `:lchdir`.
void ex_cd(exarg_T *eap)
{
  char_u *new_dir;
  char_u *tofree;

  new_dir = eap->arg;
#if !defined(UNIX)
  // for non-UNIX ":cd" means: print current directory
  if (*new_dir == NUL) {
    ex_pwd(NULL);
  } else
#endif
  {
    if (allbuf_locked()) {
      return;
    }

    // ":cd -": Change to previous directory
    if (STRCMP(new_dir, "-") == 0) {
      if (prev_dir == NULL) {
        EMSG(_("E186: No previous directory"));
        return;
      }
      new_dir = prev_dir;
    }

    // Save current directory for next ":cd -"
    tofree = prev_dir;
    if (os_dirname(NameBuff, MAXPATHL) == OK) {
      prev_dir = vim_strsave(NameBuff);
    } else {
      prev_dir = NULL;
    }

#if defined(UNIX)
    // On Unix ":cd" means: go to home directory.
    if (*new_dir == NUL) {
      // Use NameBuff for home directory name.
      expand_env((char_u *)"$HOME", NameBuff, MAXPATHL);
      new_dir = NameBuff;
    }
#endif
    CdScope scope = kCdScopeGlobal;  // Depends on command invoked

    switch (eap->cmdidx) {
    case CMD_tcd:
    case CMD_tchdir:
      scope = kCdScopeTab;
      break;
    case CMD_lcd:
    case CMD_lchdir:
      scope = kCdScopeWindow;
      break;
    default:
      break;
    }

    if (vim_chdir(new_dir)) {
      EMSG(_(e_failed));
    } else {
      post_chdir(scope, true);
      // Echo the new current directory if the command was typed.
      if (KeyTyped || p_verbose >= 5) {
        ex_pwd(eap);
      }
    }

    xfree(tofree);
  }
}

/*
 * ":pwd".
 */
static void ex_pwd(exarg_T *eap)
{
  if (os_dirname(NameBuff, MAXPATHL) == OK) {
#ifdef BACKSLASH_IN_FILENAME
    slash_adjust(NameBuff);
#endif
    msg(NameBuff);
  } else {
    EMSG(_("E187: Unknown"));
  }
}

/*
 * ":=".
 */
static void ex_equal(exarg_T *eap)
{
  smsg("%" PRId64, (int64_t)eap->line2);
  ex_may_print(eap);
}

static void ex_sleep(exarg_T *eap)
{
  int n;
  long len;

  if (cursor_valid()) {
    n = curwin->w_winrow + curwin->w_wrow - msg_scrolled;
    if (n >= 0) {
      ui_cursor_goto(n, curwin->w_wincol + curwin->w_wcol);
    }
  }

  len = eap->line2;
  switch (*eap->arg) {
  case 'm':
    break;
  case NUL:
    len *= 1000L; break;
  default:
    EMSG2(_(e_invarg2), eap->arg); return;
  }
  do_sleep(len);
}

/*
 * Sleep for "msec" milliseconds, but keep checking for a CTRL-C every second.
 */
void do_sleep(long msec)
{
  ui_flush();  // flush before waiting
  for (long left = msec; !got_int && left > 0; left -= 1000L) {
    int next = left > 1000l ? 1000 : (int)left;
    LOOP_PROCESS_EVENTS_UNTIL(&main_loop, main_loop.events, (int)next, got_int);
    os_breakcheck();
  }

  // If CTRL-C was typed to interrupt the sleep, drop the CTRL-C from the
  // input buffer, otherwise a following call to input() fails.
  if (got_int) {
    (void)vpeekc();
  }
}

static void do_exmap(exarg_T *eap, int isabbrev)
{
  int mode;
  char_u *cmdp;

  cmdp = eap->cmd;
  mode = get_map_mode(&cmdp, eap->forceit || isabbrev);

  switch (do_map((*cmdp == 'n') ? 2 : (*cmdp == 'u'),
                 eap->arg, mode, isabbrev)) {
  case 1:
    EMSG(_(e_invarg));
    break;
  case 2:
    EMSG(isabbrev ? _(e_noabbr) : _(e_nomap));
    break;
  }
}

/*
 * ":winsize" command (obsolete).
 */
static void ex_winsize(exarg_T *eap)
{
  char_u *arg = eap->arg;

  if (!ascii_isdigit(*arg)) {
    EMSG2(_(e_invarg2), arg);
    return;
  }
  int w = getdigits_int(&arg, false, 10);
  arg = skipwhite(arg);
  char_u *p = arg;
  int h = getdigits_int(&arg, false, 10);
  if (*p != NUL && *arg == NUL) {
    screen_resize(w, h);
  } else {
    EMSG(_("E465: :winsize requires two number arguments"));
  }
}

static void ex_wincmd(exarg_T *eap)
{
  int xchar = NUL;
  char_u *p;

  if (*eap->arg == 'g' || *eap->arg == Ctrl_G) {
    // CTRL-W g and CTRL-W CTRL-G  have an extra command character
    if (eap->arg[1] == NUL) {
      EMSG(_(e_invarg));
      return;
    }
    xchar = eap->arg[1];
    p = eap->arg + 2;
  } else {
    p = eap->arg + 1;
  }

  eap->nextcmd = check_nextcmd(p);
  p = skipwhite(p);
  if (*p != NUL && *p != '"' && eap->nextcmd == NULL) {
    EMSG(_(e_invarg));
  } else if (!eap->skip) {
    // Pass flags on for ":vertical wincmd ]".
    postponed_split_flags = cmdmod.split;
    postponed_split_tab = cmdmod.tab;
    do_window(*eap->arg, eap->addr_count > 0 ? eap->line2 : 0L, xchar);
    postponed_split_flags = 0;
    postponed_split_tab = 0;
  }
}

/*
 * Handle command that work like operators: ":delete", ":yank", ":>" and ":<".
 */
static void ex_operators(exarg_T *eap)
{
  oparg_T oa;

  clear_oparg(&oa);
  oa.regname = eap->regname;
  oa.start.lnum = eap->line1;
  oa.end.lnum = eap->line2;
  oa.line_count = eap->line2 - eap->line1 + 1;
  oa.motion_type = kMTLineWise;
  virtual_op = kFalse;
  if (eap->cmdidx != CMD_yank) {  // position cursor for undo
    setpcmark();
    curwin->w_cursor.lnum = eap->line1;
    beginline(BL_SOL | BL_FIX);
  }

  if (VIsual_active) {
    end_visual_mode();
  }

  switch (eap->cmdidx) {
  case CMD_delete:
    oa.op_type = OP_DELETE;
    op_delete(&oa);
    break;

  case CMD_yank:
    oa.op_type = OP_YANK;
    (void)op_yank(&oa, true, false);
    break;

  default:          // CMD_rshift or CMD_lshift
    if (
        (eap->cmdidx == CMD_rshift) ^ curwin->w_p_rl
        ) {
      oa.op_type = OP_RSHIFT;
    } else {
      oa.op_type = OP_LSHIFT;
    }
    op_shift(&oa, FALSE, eap->amount);
    break;
  }
  virtual_op = kNone;
  ex_may_print(eap);
}

/*
 * ":put".
 */
static void ex_put(exarg_T *eap)
{
  // ":0put" works like ":1put!".
  if (eap->line2 == 0) {
    eap->line2 = 1;
    eap->forceit = TRUE;
  }
  curwin->w_cursor.lnum = eap->line2;
  do_put(eap->regname, NULL, eap->forceit ? BACKWARD : FORWARD, 1,
         PUT_LINE|PUT_CURSLINE);
}

/*
 * Handle ":copy" and ":move".
 */
static void ex_copymove(exarg_T *eap)
{
  long n = get_address(eap, &eap->arg, eap->addr_type, false, false, false, 1);
  if (eap->arg == NULL) {  // error detected
    eap->nextcmd = NULL;
    return;
  }
  get_flags(eap);

  /*
   * move or copy lines from 'eap->line1'-'eap->line2' to below line 'n'
   */
  if (n == MAXLNUM || n < 0 || n > curbuf->b_ml.ml_line_count) {
    EMSG(_(e_invrange));
    return;
  }

  if (eap->cmdidx == CMD_move) {
    if (do_move(eap->line1, eap->line2, n) == FAIL) {
      return;
    }
  } else {
    ex_copy(eap->line1, eap->line2, n);
  }
  u_clearline();
  beginline(BL_SOL | BL_FIX);
  ex_may_print(eap);
}

/*
 * Print the current line if flags were given to the Ex command.
 */
void ex_may_print(exarg_T *eap)
{
  if (eap->flags != 0) {
    print_line(curwin->w_cursor.lnum, (eap->flags & EXFLAG_NR),
               (eap->flags & EXFLAG_LIST));
    ex_no_reprint = true;
  }
}

/// ":smagic" and ":snomagic".
static void ex_submagic(exarg_T *eap)
{
  int magic_save = p_magic;

  p_magic = (eap->cmdidx == CMD_smagic);
  ex_substitute(eap);
  p_magic = magic_save;
}

/*
 * ":join".
 */
static void ex_join(exarg_T *eap)
{
  curwin->w_cursor.lnum = eap->line1;
  if (eap->line1 == eap->line2) {
    if (eap->addr_count >= 2) {     // :2,2join does nothing
      return;
    }
    if (eap->line2 == curbuf->b_ml.ml_line_count) {
      beep_flush();
      return;
    }
    ++eap->line2;
  }
  do_join(eap->line2 - eap->line1 + 1, !eap->forceit, TRUE, TRUE, true);
  beginline(BL_WHITE | BL_FIX);
  ex_may_print(eap);
}

/*
 * ":[addr]@r": execute register
 */
static void ex_at(exarg_T *eap)
{
  int prev_len = typebuf.tb_len;

  curwin->w_cursor.lnum = eap->line2;
  check_cursor_col();

  // Get the register name. No name means use the previous one.
  int c = *eap->arg;
  if (c == NUL) {
    c = '@';
  }

  // Put the register in the typeahead buffer with the "silent" flag.
  if (do_execreg(c, TRUE, vim_strchr(p_cpo, CPO_EXECBUF) != NULL, TRUE)
      == FAIL) {
    beep_flush();
  } else {
    bool save_efr = exec_from_reg;

    exec_from_reg = true;

    /*
     * Execute from the typeahead buffer.
     * Continue until the stuff buffer is empty and all added characters
     * have been consumed.
     */
    while (!stuff_empty() || typebuf.tb_len > prev_len) {
      (void)do_cmdline(NULL, getexline, NULL, DOCMD_NOWAIT|DOCMD_VERBOSE);
    }

    exec_from_reg = save_efr;
  }
}

/*
 * ":!".
 */
static void ex_bang(exarg_T *eap)
{
  do_bang(eap->addr_count, eap, eap->forceit, true, true);
}

/*
 * ":undo".
 */
static void ex_undo(exarg_T *eap)
{
  if (eap->addr_count == 1) {       // :undo 123
    undo_time(eap->line2, false, false, true);
  } else {
    u_undo(1);
  }
}

static void ex_wundo(exarg_T *eap)
{
  char_u hash[UNDO_HASH_SIZE];

  u_compute_hash(curbuf, hash);
  u_write_undo((char *)eap->arg, eap->forceit, curbuf, hash);
}

static void ex_rundo(exarg_T *eap)
{
  char_u hash[UNDO_HASH_SIZE];

  u_compute_hash(curbuf, hash);
  u_read_undo((char *)eap->arg, hash, NULL);
}

/// ":redo".
static void ex_redo(exarg_T *eap)
{
  u_redo(1);
}

/// ":earlier" and ":later".
static void ex_later(exarg_T *eap)
{
  long count = 0;
  bool sec = false;
  bool file = false;
  char_u *p = eap->arg;

  if (*p == NUL) {
    count = 1;
  } else if (isdigit(*p)) {
    count = getdigits_long(&p, false, 0);
    switch (*p) {
    case 's':
      ++p; sec = true; break;
    case 'm':
      ++p; sec = true; count *= 60; break;
    case 'h':
      ++p; sec = true; count *= 60 * 60; break;
    case 'd':
      ++p; sec = true; count *= 24 * 60 * 60; break;
    case 'f':
      ++p; file = true; break;
    }
  }

  if (*p != NUL) {
    EMSG2(_(e_invarg2), eap->arg);
  } else {
    undo_time(eap->cmdidx == CMD_earlier ? -count : count,
              sec, file, false);
  }
}

/*
 * ":redir": start/stop redirection.
 */
static void ex_redir(exarg_T *eap)
{
  char *mode;
  char_u *fname;
  char_u *arg = eap->arg;

  if (STRICMP(eap->arg, "END") == 0) {
    close_redir();
  } else {
    if (*arg == '>') {
      ++arg;
      if (*arg == '>') {
        ++arg;
        mode = "a";
      } else {
        mode = "w";
      }
      arg = skipwhite(arg);

      close_redir();

      // Expand environment variables and "~/".
      fname = expand_env_save(arg);
      if (fname == NULL) {
        return;
      }

      redir_fd = open_exfile(fname, eap->forceit, mode);
      xfree(fname);
    } else if (*arg == '@') {
      // redirect to a register a-z (resp. A-Z for appending)
      close_redir();
      ++arg;
      if (valid_yank_reg(*arg, true) && *arg != '_') {
        redir_reg = *arg++;
        if (*arg == '>' && arg[1] == '>') {        // append
          arg += 2;
        } else {
          // Can use both "@a" and "@a>".
          if (*arg == '>') {
            arg++;
          }
          // Make register empty when not using @A-@Z and the
          // command is valid.
          if (*arg == NUL && !isupper(redir_reg)) {
            write_reg_contents(redir_reg, (char_u *)"", 0, false);
          }
        }
      }
      if (*arg != NUL) {
        redir_reg = 0;
        EMSG2(_(e_invarg2), eap->arg);
      }
    } else if (*arg == '=' && arg[1] == '>') {
      int append;

      // redirect to a variable
      close_redir();
      arg += 2;

      if (*arg == '>') {
        ++arg;
        append = TRUE;
      } else {
        append = FALSE;
      }

      if (var_redir_start(skipwhite(arg), append) == OK) {
        redir_vname = 1;
      }
    }
    // TODO: redirect to a buffer
    else {
      EMSG2(_(e_invarg2), eap->arg);
    }
  }

  /* Make sure redirection is not off.  Can happen for cmdline completion
   * that indirectly invokes a command to catch its output. */
  if (redir_fd != NULL
      || redir_reg || redir_vname) {
    redir_off = false;
  }
}

/// ":redraw": force redraw
static void ex_redraw(exarg_T *eap)
{
  if (State & CMDPREVIEW) {
    return;  // Ignore :redraw during 'inccommand' preview. #9777
  }
  int r = RedrawingDisabled;
  int p = p_lz;

  RedrawingDisabled = 0;
  p_lz = FALSE;
  validate_cursor();
  update_topline(curwin);
  if (eap->forceit) {
    redraw_all_later(NOT_VALID);
  }
  update_screen(eap->forceit ? NOT_VALID
                             : VIsual_active ? INVERTED : 0);
  if (need_maketitle) {
    maketitle();
  }
  RedrawingDisabled = r;
  p_lz = p;

  // Reset msg_didout, so that a message that's there is overwritten.
  msg_didout = false;
  msg_col = 0;

  // No need to wait after an intentional redraw.
  need_wait_return = false;

  ui_flush();
}

/// ":redrawstatus": force redraw of status line(s)
static void ex_redrawstatus(exarg_T *eap)
{
  if (State & CMDPREVIEW) {
    return;  // Ignore :redrawstatus during 'inccommand' preview. #9777
  }
  int r = RedrawingDisabled;
  int p = p_lz;

  RedrawingDisabled = 0;
  p_lz = FALSE;
  if (eap->forceit) {
    status_redraw_all();
  } else {
    status_redraw_curbuf();
  }
  update_screen(VIsual_active ? INVERTED :
                0);
  RedrawingDisabled = r;
  p_lz = p;
  ui_flush();
}

// ":redrawtabline": force redraw of the tabline
static void ex_redrawtabline(exarg_T *eap FUNC_ATTR_UNUSED)
{
  const int r = RedrawingDisabled;
  const int p = p_lz;

  RedrawingDisabled = 0;
  p_lz = false;

  draw_tabline();

  RedrawingDisabled = r;
  p_lz = p;
  ui_flush();
}

static void close_redir(void)
{
  if (redir_fd != NULL) {
    fclose(redir_fd);
    redir_fd = NULL;
  }
  redir_reg = 0;
  if (redir_vname) {
    var_redir_stop();
    redir_vname = 0;
  }
}

/// Try creating a directory, give error message on failure
///
/// @param[in]  name  Directory to create.
/// @param[in]  prot  Directory permissions.
///
/// @return OK in case of success, FAIL otherwise.
int vim_mkdir_emsg(const char *const name, const int prot)
  FUNC_ATTR_NONNULL_ALL
{
  int ret;
  if ((ret = os_mkdir(name, prot)) != 0) {
    EMSG3(_(e_mkdir), name, os_strerror(ret));
    return FAIL;
  }
  return OK;
}

/// Open a file for writing for an Ex command, with some checks.
///
/// @param mode  "w" for create new file or "a" for append
///
/// @return  file descriptor, or NULL on failure.
FILE *open_exfile(char_u *fname, int forceit, char *mode)
{
  FILE *fd;

#ifdef UNIX
  // with Unix it is possible to open a directory
  if (os_isdir(fname)) {
    EMSG2(_(e_isadir2), fname);
    return NULL;
  }
#endif
  if (!forceit && *mode != 'a' && os_path_exists(fname)) {
    EMSG2(_("E189: \"%s\" exists (add ! to override)"), fname);
    return NULL;
  }

  if ((fd = os_fopen((char *)fname, mode)) == NULL) {
    EMSG2(_("E190: Cannot open \"%s\" for writing"), fname);
  }

  return fd;
}

/*
 * ":mark" and ":k".
 */
static void ex_mark(exarg_T *eap)
{
  pos_T pos;

  if (*eap->arg == NUL) {               // No argument?
    EMSG(_(e_argreq));
  } else if (eap->arg[1] != NUL) {         // more than one character?
    EMSG(_(e_trailing));
  } else {
    pos = curwin->w_cursor;             // save curwin->w_cursor
    curwin->w_cursor.lnum = eap->line2;
    beginline(BL_WHITE | BL_FIX);
    if (setmark(*eap->arg) == FAIL) {   // set mark
      EMSG(_("E191: Argument must be a letter or forward/backward quote"));
    }
    curwin->w_cursor = pos;             // restore curwin->w_cursor
  }
}

/*
 * Update w_topline, w_leftcol and the cursor position.
 */
void update_topline_cursor(void)
{
  check_cursor();               // put cursor on valid line
  update_topline(curwin);
  if (!curwin->w_p_wrap) {
    validate_cursor();
  }
  update_curswant();
}

// Save the current State and go to Normal mode.
// Return true if the typeahead could be saved.
bool save_current_state(save_state_T *sst)
  FUNC_ATTR_NONNULL_ALL
{
  sst->save_msg_scroll = msg_scroll;
  sst->save_restart_edit = restart_edit;
  sst->save_msg_didout = msg_didout;
  sst->save_State = State;
  sst->save_insertmode = p_im;
  sst->save_finish_op = finish_op;
  sst->save_opcount = opcount;
  sst->save_reg_executing = reg_executing;

  msg_scroll = false;   // no msg scrolling in Normal mode
  restart_edit = 0;     // don't go to Insert mode
  p_im = false;         // don't use 'insertmode

  // Save the current typeahead.  This is required to allow using ":normal"
  // from an event handler and makes sure we don't hang when the argument
  // ends with half a command.
  save_typeahead(&sst->tabuf);
  return sst->tabuf.typebuf_valid;
}

void restore_current_state(save_state_T *sst)
  FUNC_ATTR_NONNULL_ALL
{
  // Restore the previous typeahead.
  restore_typeahead(&sst->tabuf);

  msg_scroll = sst->save_msg_scroll;
  if (force_restart_edit) {
    force_restart_edit = false;
  } else {
    // Some function (terminal_enter()) was aware of ex_normal and decided to
    // override the value of restart_edit anyway.
    restart_edit = sst->save_restart_edit;
  }
  p_im = sst->save_insertmode;
  finish_op = sst->save_finish_op;
  opcount = sst->save_opcount;
  reg_executing = sst->save_reg_executing;

  // don't reset msg_didout now
  msg_didout |= sst->save_msg_didout;

  // Restore the state (needed when called from a function executed for
  // 'indentexpr'). Update the mouse and cursor, they may have changed.
  State = sst->save_State;
  ui_cursor_shape();  // may show different cursor shape
}

/*
 * ":normal[!] {commands}": Execute normal mode commands.
 */
static void ex_normal(exarg_T *eap)
{
  if (curbuf->terminal && State & TERM_FOCUS) {
    EMSG("Can't re-enter normal mode from terminal mode");
    return;
  }
  save_state_T save_state;
  char_u *arg = NULL;
  int l;
  char_u *p;

  if (ex_normal_lock > 0) {
    EMSG(_(e_secure));
    return;
  }
  if (ex_normal_busy >= p_mmd) {
    EMSG(_("E192: Recursive use of :normal too deep"));
    return;
  }

  // vgetc() expects a CSI and K_SPECIAL to have been escaped.  Don't do
  // this for the K_SPECIAL leading byte, otherwise special keys will not
  // work.
  {
    int len = 0;

    // Count the number of characters to be escaped.
    for (p = eap->arg; *p != NUL; ++p) {
      for (l = (*mb_ptr2len)(p) - 1; l > 0; --l) {
        if (*++p == K_SPECIAL             // trailbyte K_SPECIAL or CSI
            ) {
          len += 2;
        }
      }
    }
    if (len > 0) {
      arg = xmalloc(STRLEN(eap->arg) + len + 1);
      len = 0;
      for (p = eap->arg; *p != NUL; ++p) {
        arg[len++] = *p;
        for (l = (*mb_ptr2len)(p) - 1; l > 0; --l) {
          arg[len++] = *++p;
          if (*p == K_SPECIAL) {
            arg[len++] = KS_SPECIAL;
            arg[len++] = KE_FILLER;
          }
        }
        arg[len] = NUL;
      }
    }
  }

  ex_normal_busy++;
  if (save_current_state(&save_state)) {
    // Repeat the :normal command for each line in the range.  When no
    // range given, execute it just once, without positioning the cursor
    // first.
    do {
      if (eap->addr_count != 0) {
        curwin->w_cursor.lnum = eap->line1++;
        curwin->w_cursor.col = 0;
        check_cursor_moved(curwin);
      }

      exec_normal_cmd(arg != NULL ? arg : eap->arg,
                      eap->forceit ? REMAP_NONE : REMAP_YES, false);
    } while (eap->addr_count > 0 && eap->line1 <= eap->line2 && !got_int);
  }

  // Might not return to the main loop when in an event handler.
  update_topline_cursor();

  restore_current_state(&save_state);

  ex_normal_busy--;

  setmouse();
  ui_cursor_shape();  // may show different cursor shape
  xfree(arg);
}

/*
 * ":startinsert", ":startreplace" and ":startgreplace"
 */
static void ex_startinsert(exarg_T *eap)
{
  if (eap->forceit) {
    // cursor line can be zero on startup
    if (!curwin->w_cursor.lnum) {
      curwin->w_cursor.lnum = 1;
    }
    set_cursor_for_append_to_line();
  }

  // Ignore the command when already in Insert mode.  Inserting an
  // expression register that invokes a function can do this.
  if (State & INSERT) {
    return;
  }

  if (eap->cmdidx == CMD_startinsert) {
    restart_edit = 'a';
  } else if (eap->cmdidx == CMD_startreplace) {
    restart_edit = 'R';
  } else {
    restart_edit = 'V';
  }

  if (!eap->forceit) {
    if (eap->cmdidx == CMD_startinsert) {
      restart_edit = 'i';
    }
    curwin->w_curswant = 0;  // avoid MAXCOL
  }

  if (VIsual_active) {
    showmode();
  }
}

/*
 * ":stopinsert"
 */
static void ex_stopinsert(exarg_T *eap)
{
  restart_edit = 0;
  stop_insert_mode = true;
  clearmode();
}

/*
 * Execute normal mode command "cmd".
 * "remap" can be REMAP_NONE or REMAP_YES.
 */
void exec_normal_cmd(char_u *cmd, int remap, bool silent)
{
  // Stuff the argument into the typeahead buffer.
  ins_typebuf(cmd, remap, 0, true, silent);
  exec_normal(false);
}

/// Execute normal_cmd() until there is no typeahead left.
///
/// @param was_typed whether or not something was typed
void exec_normal(bool was_typed)
{
  oparg_T oa;

  clear_oparg(&oa);
  finish_op = false;
  while ((!stuff_empty()
          || ((was_typed || !typebuf_typed())
              && typebuf.tb_len > 0))
         && !got_int) {
    update_topline_cursor();
    normal_cmd(&oa, true);      // execute a Normal mode cmd
  }
}

static void ex_checkpath(exarg_T *eap)
{
  find_pattern_in_path(NULL, 0, 0, false, false, CHECK_PATH, 1L,
                       eap->forceit ? ACTION_SHOW_ALL : ACTION_SHOW,
                       (linenr_T)1, (linenr_T)MAXLNUM);
}

/*
 * ":psearch"
 */
static void ex_psearch(exarg_T *eap)
{
  g_do_tagpreview = p_pvh;
  ex_findpat(eap);
  g_do_tagpreview = 0;
}

static void ex_findpat(exarg_T *eap)
{
  bool whole = true;
  long n;
  char_u *p;
  int action;

  switch (cmdnames[eap->cmdidx].cmd_name[2]) {
  case 'e':             // ":psearch", ":isearch" and ":dsearch"
    if (cmdnames[eap->cmdidx].cmd_name[0] == 'p') {
      action = ACTION_GOTO;
    } else {
      action = ACTION_SHOW;
    }
    break;
  case 'i':             // ":ilist" and ":dlist"
    action = ACTION_SHOW_ALL;
    break;
  case 'u':             // ":ijump" and ":djump"
    action = ACTION_GOTO;
    break;
  default:              // ":isplit" and ":dsplit"
    action = ACTION_SPLIT;
    break;
  }

  n = 1;
  if (ascii_isdigit(*eap->arg)) {  // get count
    n = getdigits_long(&eap->arg, false, 0);
    eap->arg = skipwhite(eap->arg);
  }
  if (*eap->arg == '/') {   // Match regexp, not just whole words
    whole = false;
    eap->arg++;
    p = skip_regexp(eap->arg, '/', p_magic, NULL);
    if (*p) {
      *p++ = NUL;
      p = skipwhite(p);

      // Check for trailing illegal characters.
      if (!ends_excmd(*p)) {
        eap->errmsg = e_trailing;
      } else {
        eap->nextcmd = check_nextcmd(p);
      }
    }
  }
  if (!eap->skip) {
    find_pattern_in_path(eap->arg, 0, STRLEN(eap->arg), whole, !eap->forceit,
                         *eap->cmd == 'd' ?  FIND_DEFINE : FIND_ANY,
                         n, action, eap->line1, eap->line2);
  }
}


/*
 * ":ptag", ":ptselect", ":ptjump", ":ptnext", etc.
 */
static void ex_ptag(exarg_T *eap)
{
  g_do_tagpreview = p_pvh;    // will be reset to 0 in ex_tag_cmd()
  ex_tag_cmd(eap, cmdnames[eap->cmdidx].cmd_name + 1);
}

/*
 * ":pedit"
 */
static void ex_pedit(exarg_T *eap)
{
  win_T *curwin_save = curwin;

  // Open the preview window or popup and make it the current window.
  g_do_tagpreview = p_pvh;
  prepare_tagpreview(true);

  // Edit the file.
  do_exedit(eap, NULL);

  if (curwin != curwin_save && win_valid(curwin_save)) {
    // Return cursor to where we were
    validate_cursor();
    redraw_later(curwin, VALID);
    win_enter(curwin_save, true);
  }
  g_do_tagpreview = 0;
}

/*
 * ":stag", ":stselect" and ":stjump".
 */
static void ex_stag(exarg_T *eap)
{
  postponed_split = -1;
  postponed_split_flags = cmdmod.split;
  postponed_split_tab = cmdmod.tab;
  ex_tag_cmd(eap, cmdnames[eap->cmdidx].cmd_name + 1);
  postponed_split_flags = 0;
  postponed_split_tab = 0;
}

/*
 * ":tag", ":tselect", ":tjump", ":tnext", etc.
 */
static void ex_tag(exarg_T *eap)
{
  ex_tag_cmd(eap, cmdnames[eap->cmdidx].cmd_name);
}

static void ex_tag_cmd(exarg_T *eap, char_u *name)
{
  int cmd;

  switch (name[1]) {
  case 'j':
    cmd = DT_JUMP;              // ":tjump"
    break;
  case 's':
    cmd = DT_SELECT;            // ":tselect"
    break;
  case 'p':                             // ":tprevious"
  case 'N':
    cmd = DT_PREV;              // ":tNext"
    break;
  case 'n':
    cmd = DT_NEXT;              // ":tnext"
    break;
  case 'o':
    cmd = DT_POP;               // ":pop"
    break;
  case 'f':                             // ":tfirst"
  case 'r':
    cmd = DT_FIRST;             // ":trewind"
    break;
  case 'l':
    cmd = DT_LAST;              // ":tlast"
    break;
  default:                              // ":tag"
    if (p_cst && *eap->arg != NUL) {
      ex_cstag(eap);
      return;
    }
    cmd = DT_TAG;
    break;
  }

  if (name[0] == 'l') {
    cmd = DT_LTAG;
  }

  do_tag(eap->arg, cmd, eap->addr_count > 0 ? (int)eap->line2 : 1,
         eap->forceit, TRUE);
}

enum {
  SPEC_PERC = 0,
  SPEC_HASH,
  SPEC_CWORD,
  SPEC_CCWORD,
  SPEC_CEXPR,
  SPEC_CFILE,
  SPEC_SFILE,
  SPEC_SLNUM,
  SPEC_STACK,
  SPEC_AFILE,
  SPEC_ABUF,
  SPEC_AMATCH,
  SPEC_SFLNUM,
  SPEC_SID,
  // SPEC_CLIENT,
};

/*
 * Check "str" for starting with a special cmdline variable.
 * If found return one of the SPEC_ values and set "*usedlen" to the length of
 * the variable.  Otherwise return -1 and "*usedlen" is unchanged.
 */
ssize_t find_cmdline_var(const char_u *src, size_t *usedlen)
  FUNC_ATTR_NONNULL_ALL
{
  size_t len;
  static char *(spec_str[]) = {
    [SPEC_PERC] = "%",
    [SPEC_HASH] = "#",
    [SPEC_CWORD] = "<cword>",           // cursor word
    [SPEC_CCWORD] = "<cWORD>",          // cursor WORD
    [SPEC_CEXPR] = "<cexpr>",           // expr under cursor
    [SPEC_CFILE] = "<cfile>",           // cursor path name
    [SPEC_SFILE] = "<sfile>",           // ":so" file name
    [SPEC_SLNUM] = "<slnum>",           // ":so" file line number
    [SPEC_STACK] = "<stack>",           // call stack
    [SPEC_AFILE] = "<afile>",           // autocommand file name
    [SPEC_ABUF] = "<abuf>",             // autocommand buffer number
    [SPEC_AMATCH] = "<amatch>",         // autocommand match name
    [SPEC_SFLNUM] = "<sflnum>",         // script file line number
    [SPEC_SID] = "<SID>",               // script ID: <SNR>123_
    // [SPEC_CLIENT] = "<client>",
  };

  for (size_t i = 0; i < ARRAY_SIZE(spec_str); ++i) {
    len = STRLEN(spec_str[i]);
    if (STRNCMP(src, spec_str[i], len) == 0) {
      *usedlen = len;
      assert(i <= SSIZE_MAX);
      return (ssize_t)i;
    }
  }
  return -1;
}

/// Evaluate cmdline variables.
///
/// change '%'       to curbuf->b_ffname
///        '#'       to curwin->w_alt_fnum
///        '<cword>' to word under the cursor
///        '<cWORD>' to WORD under the cursor
///        '<cexpr>' to C-expression under the cursor
///        '<cfile>' to path name under the cursor
///        '<sfile>' to sourced file name
///        '<slnum>' to sourced file line number
///        '<afile>' to file name for autocommand
///        '<abuf>'  to buffer number for autocommand
///        '<amatch>' to matching name for autocommand
///
/// When an error is detected, "errormsg" is set to a non-NULL pointer (may be
/// "" for error without a message) and NULL is returned.
///
/// @param src       pointer into commandline
/// @param srcstart  beginning of valid memory for src
/// @param usedlen   characters after src that are used
/// @param lnump     line number for :e command, or NULL
/// @param errormsg  pointer to error message
/// @param escaped   return value has escaped white space (can be NULL)
///
/// @return          an allocated string if a valid match was found.
///                  Returns NULL if no match was found.  "usedlen" then still contains the
///                  number of characters to skip.
char_u *eval_vars(char_u *src, char_u *srcstart, size_t *usedlen, linenr_T *lnump,
                  char_u **errormsg, int *escaped)
{
  int i;
  char_u *s;
  char_u *result;
  char_u *resultbuf = NULL;
  size_t resultlen;
  buf_T *buf;
  int valid = VALID_HEAD | VALID_PATH;  // Assume valid result.
  bool tilde_file = false;
  bool skip_mod = false;
  char strbuf[30];

  *errormsg = NULL;
  if (escaped != NULL) {
    *escaped = FALSE;
  }

  /*
   * Check if there is something to do.
   */
  ssize_t spec_idx = find_cmdline_var(src, usedlen);
  if (spec_idx < 0) {   // no match
    *usedlen = 1;
    return NULL;
  }

  /*
   * Skip when preceded with a backslash "\%" and "\#".
   * Note: In "\\%" the % is also not recognized!
   */
  if (src > srcstart && src[-1] == '\\') {
    *usedlen = 0;
    STRMOVE(src - 1, src);      // remove backslash
    return NULL;
  }

  /*
   * word or WORD under cursor
   */
  if (spec_idx == SPEC_CWORD
      || spec_idx == SPEC_CCWORD
      || spec_idx == SPEC_CEXPR) {
    resultlen = find_ident_under_cursor(&result,
                                        spec_idx == SPEC_CWORD
        ? (FIND_IDENT | FIND_STRING)
        : (spec_idx == SPEC_CEXPR
           ? (FIND_IDENT | FIND_STRING | FIND_EVAL)
           : FIND_STRING));
    if (resultlen == 0) {
      *errormsg = (char_u *)"";
      return NULL;
    }
    //
    // '#': Alternate file name
    // '%': Current file name
    //        File name under the cursor
    //        File name for autocommand
    //    and following modifiers
    //
  } else {
    switch (spec_idx) {
    case SPEC_PERC:             // '%': current file
      if (curbuf->b_fname == NULL) {
        result = (char_u *)"";
        valid = 0;                  // Must have ":p:h" to be valid
      } else {
        result = curbuf->b_fname;
        tilde_file = STRCMP(result, "~") == 0;
      }
      break;

    case SPEC_HASH:             // '#' or "#99": alternate file
      if (src[1] == '#') {          // "##": the argument list
        result = arg_all();
        resultbuf = result;
        *usedlen = 2;
        if (escaped != NULL) {
          *escaped = TRUE;
        }
        skip_mod = true;
        break;
      }
      s = src + 1;
      if (*s == '<') {                  // "#<99" uses v:oldfiles.
        s++;
      }
      i = getdigits_int(&s, false, 0);
      if (s == src + 2 && src[1] == '-') {
        // just a minus sign, don't skip over it
        s--;
      }
      *usedlen = (size_t)(s - src);           // length of what we expand

      if (src[1] == '<' && i != 0) {
        if (*usedlen < 2) {
          // Should we give an error message for #<text?
          *usedlen = 1;
          return NULL;
        }
        result = (char_u *)tv_list_find_str(get_vim_var_list(VV_OLDFILES),
                                            i - 1);
        if (result == NULL) {
          *errormsg = (char_u *)"";
          return NULL;
        }
      } else {
        if (i == 0 && src[1] == '<' && *usedlen > 1) {
          *usedlen = 1;
        }
        buf = buflist_findnr(i);
        if (buf == NULL) {
          *errormsg = (char_u *)_("E194: No alternate file name to substitute for '#'");
          return NULL;
        }
        if (lnump != NULL) {
          *lnump = ECMD_LAST;
        }
        if (buf->b_fname == NULL) {
          result = (char_u *)"";
          valid = 0;                        // Must have ":p:h" to be valid
        } else {
          result = buf->b_fname;
          tilde_file = STRCMP(result, "~") == 0;
        }
      }
      break;

    case SPEC_CFILE:            // file name under cursor
      result = file_name_at_cursor(FNAME_MESS|FNAME_HYP, 1L, NULL);
      if (result == NULL) {
        *errormsg = (char_u *)"";
        return NULL;
      }
      resultbuf = result;                   // remember allocated string
      break;

    case SPEC_AFILE:  // file name for autocommand
      if (autocmd_fname != NULL
          && !path_is_absolute(autocmd_fname)
          // For CmdlineEnter and related events, <afile> is not a path! #9348
          && !strequal("/", (char *)autocmd_fname)) {
        // Still need to turn the fname into a full path.  It was
        // postponed to avoid a delay when <afile> is not used.
        result = (char_u *)FullName_save((char *)autocmd_fname, false);
        // Copy into `autocmd_fname`, don't reassign it. #8165
        xstrlcpy((char *)autocmd_fname, (char *)result, MAXPATHL);
        xfree(result);
      }
      result = autocmd_fname;
      if (result == NULL) {
        *errormsg = (char_u *)_("E495: no autocommand file name to substitute for \"<afile>\"");
        return NULL;
      }
      result = path_try_shorten_fname(result);
      break;

    case SPEC_ABUF:             // buffer number for autocommand
      if (autocmd_bufnr <= 0) {
        *errormsg = (char_u *)_("E496: no autocommand buffer number to substitute for \"<abuf>\"");
        return NULL;
      }
      snprintf(strbuf, sizeof(strbuf), "%d", autocmd_bufnr);
      result = (char_u *)strbuf;
      break;

    case SPEC_AMATCH:           // match name for autocommand
      result = autocmd_match;
      if (result == NULL) {
        *errormsg = (char_u *)_("E497: no autocommand match name to substitute for \"<amatch>\"");
        return NULL;
      }
      break;

    case SPEC_SFILE:            // file name for ":so" command
      result = sourcing_name;
      if (result == NULL) {
        *errormsg = (char_u *)_("E498: no :source file name to substitute for \"<sfile>\"");
        return NULL;
      }
      break;

    case SPEC_SLNUM:            // line in file for ":so" command
      if (sourcing_name == NULL || sourcing_lnum == 0) {
        *errormsg = (char_u *)_("E842: no line number to use for \"<slnum>\"");
        return NULL;
      }
      snprintf(strbuf, sizeof(strbuf), "%" PRIdLINENR, sourcing_lnum);
      result = (char_u *)strbuf;
      break;

    case SPEC_SFLNUM:  // line in script file
      if (current_sctx.sc_lnum + sourcing_lnum == 0) {
        *errormsg = (char_u *)_("E961: no line number to use for \"<sflnum>\"");
        return NULL;
      }
      snprintf((char *)strbuf, sizeof(strbuf), "%" PRIdLINENR,
               current_sctx.sc_lnum + sourcing_lnum);
      result = (char_u *)strbuf;
      break;

    case SPEC_SID:
      if (current_sctx.sc_sid <= 0) {
        *errormsg = (char_u *)_(e_usingsid);
        return NULL;
      }
      snprintf(strbuf, sizeof(strbuf), "<SNR>%" PRIdSCID "_",
               current_sctx.sc_sid);
      result = (char_u *)strbuf;
      break;

    default:
      // should not happen
      *errormsg = (char_u *)"";
      result = (char_u *)"";    // avoid gcc warning
      break;
    }

    // Length of new string.
    resultlen = STRLEN(result);
    // Remove the file name extension.
    if (src[*usedlen] == '<') {
      (*usedlen)++;
      if ((s = STRRCHR(result, '.')) != NULL && s >= path_tail(result)) {
        resultlen = (size_t)(s - result);
      }
    } else if (!skip_mod) {
      valid |= modify_fname(src, tilde_file, usedlen, &result,
                            &resultbuf, &resultlen);
      if (result == NULL) {
        *errormsg = (char_u *)"";
        return NULL;
      }
    }
  }

  if (resultlen == 0 || valid != VALID_HEAD + VALID_PATH) {
    if (valid != VALID_HEAD + VALID_PATH) {
      // xgettext:no-c-format
      *errormsg = (char_u *)_("E499: Empty file name for '%' or '#', only works with \":p:h\"");
    } else {
      *errormsg = (char_u *)_("E500: Evaluates to an empty string");
    }
    result = NULL;
  } else {
    result = vim_strnsave(result, resultlen);
  }
  xfree(resultbuf);
  return result;
}

/*
 * Concatenate all files in the argument list, separated by spaces, and return
 * it in one allocated string.
 * Spaces and backslashes in the file names are escaped with a backslash.
 */
static char_u *arg_all(void)
{
  int len;
  int idx;
  char_u *retval = NULL;
  char_u *p;

  /*
   * Do this loop two times:
   * first time: compute the total length
   * second time: concatenate the names
   */
  for (;; ) {
    len = 0;
    for (idx = 0; idx < ARGCOUNT; ++idx) {
      p = alist_name(&ARGLIST[idx]);
      if (p == NULL) {
        continue;
      }
      if (len > 0) {
        // insert a space in between names
        if (retval != NULL) {
          retval[len] = ' ';
        }
        ++len;
      }
      for (; *p != NUL; p++) {
        if (*p == ' '
#ifndef BACKSLASH_IN_FILENAME
            || *p == '\\'
#endif
            || *p == '`') {
          // insert a backslash
          if (retval != NULL) {
            retval[len] = '\\';
          }
          len++;
        }
        if (retval != NULL) {
          retval[len] = *p;
        }
        len++;
      }
    }

    // second time: break here
    if (retval != NULL) {
      retval[len] = NUL;
      break;
    }

    // allocate memory
    retval = xmalloc(len + 1);
  }

  return retval;
}

/*
 * Expand the <sfile> string in "arg".
 *
 * Returns an allocated string, or NULL for any error.
 */
char_u *expand_sfile(char_u *arg)
{
  char_u *errormsg;
  size_t len;
  char_u *result;
  char_u *newres;
  char_u *repl;
  size_t srclen;
  char_u *p;

  result = vim_strsave(arg);

  for (p = result; *p; ) {
    if (STRNCMP(p, "<sfile>", 7) != 0) {
      ++p;
    } else {
      // replace "<sfile>" with the sourced file name, and do ":" stuff
      repl = eval_vars(p, result, &srclen, NULL, &errormsg, NULL);
      if (errormsg != NULL) {
        if (*errormsg) {
          emsg(errormsg);
        }
        xfree(result);
        return NULL;
      }
      if (repl == NULL) {               // no match (cannot happen)
        p += srclen;
        continue;
      }
      len = STRLEN(result) - srclen + STRLEN(repl) + 1;
      newres = xmalloc(len);
      memmove(newres, result, (size_t)(p - result));
      STRCPY(newres + (p - result), repl);
      len = STRLEN(newres);
      STRCAT(newres, p + srclen);
      xfree(repl);
      xfree(result);
      result = newres;
      p = newres + len;                 // continue after the match
    }
  }

  return result;
}

/*
 * ":rshada" and ":wshada".
 */
static void ex_shada(exarg_T *eap)
{
  char_u *save_shada;

  save_shada = p_shada;
  if (*p_shada == NUL) {
    p_shada = (char_u *)"'100";
  }
  if (eap->cmdidx == CMD_rviminfo || eap->cmdidx == CMD_rshada) {
    (void)shada_read_everything((char *)eap->arg, eap->forceit, false);
  } else {
    shada_write_file((char *)eap->arg, eap->forceit);
  }
  p_shada = save_shada;
}

/*
 * Make a dialog message in "buff[DIALOG_MSG_SIZE]".
 * "format" must contain "%s".
 */
void dialog_msg(char_u *buff, char *format, char_u *fname)
{
  if (fname == NULL) {
    fname = (char_u *)_("Untitled");
  }
  vim_snprintf((char *)buff, DIALOG_MSG_SIZE, format, fname);
}

/*
 * ":behave {mswin,xterm}"
 */
static void ex_behave(exarg_T *eap)
{
  if (STRCMP(eap->arg, "mswin") == 0) {
    set_option_value("selection", 0L, "exclusive", 0);
    set_option_value("selectmode", 0L, "mouse,key", 0);
    set_option_value("mousemodel", 0L, "popup", 0);
    set_option_value("keymodel", 0L, "startsel,stopsel", 0);
  } else if (STRCMP(eap->arg, "xterm") == 0) {
    set_option_value("selection", 0L, "inclusive", 0);
    set_option_value("selectmode", 0L, "", 0);
    set_option_value("mousemodel", 0L, "extend", 0);
    set_option_value("keymodel", 0L, "", 0);
  } else {
    EMSG2(_(e_invarg2), eap->arg);
  }
}

/*
 * Function given to ExpandGeneric() to obtain the possible arguments of the
 * ":behave {mswin,xterm}" command.
 */
char_u *get_behave_arg(expand_T *xp, int idx)
{
  if (idx == 0) {
    return (char_u *)"mswin";
  }
  if (idx == 1) {
    return (char_u *)"xterm";
  }
  return NULL;
}

// Function given to ExpandGeneric() to obtain the possible arguments of the
// ":messages {clear}" command.
char_u *get_messages_arg(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx == 0) {
    return (char_u *)"clear";
  }
  return NULL;
}

char_u *get_mapclear_arg(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx == 0) {
    return (char_u *)"<buffer>";
  }
  return NULL;
}

static TriState filetype_detect = kNone;
static TriState filetype_plugin = kNone;
static TriState filetype_indent = kNone;

/*
 * ":filetype [plugin] [indent] {on,off,detect}"
 * on: Load the filetype.vim file to install autocommands for file types.
 * off: Load the ftoff.vim file to remove all autocommands for file types.
 * plugin on: load filetype.vim and ftplugin.vim
 * plugin off: load ftplugof.vim
 * indent on: load filetype.vim and indent.vim
 * indent off: load indoff.vim
 */
static void ex_filetype(exarg_T *eap)
{
  char_u *arg = eap->arg;
  bool plugin = false;
  bool indent = false;

  if (*eap->arg == NUL) {
    // Print current status.
    smsg("filetype detection:%s  plugin:%s  indent:%s",
         filetype_detect == kTrue ? "ON" : "OFF",
         filetype_plugin == kTrue ? (filetype_detect == kTrue ? "ON" : "(on)") : "OFF",   // NOLINT(whitespace/line_length)
         filetype_indent == kTrue ? (filetype_detect == kTrue ? "ON" : "(on)") : "OFF");  // NOLINT(whitespace/line_length)
    return;
  }

  // Accept "plugin" and "indent" in any order.
  for (;; ) {
    if (STRNCMP(arg, "plugin", 6) == 0) {
      plugin = true;
      arg = skipwhite(arg + 6);
      continue;
    }
    if (STRNCMP(arg, "indent", 6) == 0) {
      indent = true;
      arg = skipwhite(arg + 6);
      continue;
    }
    break;
  }
  if (STRCMP(arg, "on") == 0 || STRCMP(arg, "detect") == 0) {
    if (*arg == 'o' || !filetype_detect) {
      source_runtime((char_u *)FILETYPE_FILE, DIP_ALL);
      filetype_detect = kTrue;
      if (plugin) {
        source_runtime((char_u *)FTPLUGIN_FILE, DIP_ALL);
        filetype_plugin = kTrue;
      }
      if (indent) {
        source_runtime((char_u *)INDENT_FILE, DIP_ALL);
        filetype_indent = kTrue;
      }
    }
    if (*arg == 'd') {
      (void)do_doautocmd((char_u *)"filetypedetect BufRead", true, NULL);
      do_modelines(0);
    }
  } else if (STRCMP(arg, "off") == 0) {
    if (plugin || indent) {
      if (plugin) {
        source_runtime((char_u *)FTPLUGOF_FILE, DIP_ALL);
        filetype_plugin = kFalse;
      }
      if (indent) {
        source_runtime((char_u *)INDOFF_FILE, DIP_ALL);
        filetype_indent = kFalse;
      }
    } else {
      source_runtime((char_u *)FTOFF_FILE, DIP_ALL);
      filetype_detect = kFalse;
    }
  } else {
    EMSG2(_(e_invarg2), arg);
  }
}

/// Set all :filetype options ON if user did not explicitly set any to OFF.
void filetype_maybe_enable(void)
{
  if (filetype_detect == kNone) {
    source_runtime((char_u *)FILETYPE_FILE, true);
    filetype_detect = kTrue;
  }
  if (filetype_plugin == kNone) {
    source_runtime((char_u *)FTPLUGIN_FILE, true);
    filetype_plugin = kTrue;
  }
  if (filetype_indent == kNone) {
    source_runtime((char_u *)INDENT_FILE, true);
    filetype_indent = kTrue;
  }
}

/// ":setfiletype [FALLBACK] {name}"
static void ex_setfiletype(exarg_T *eap)
{
  if (!did_filetype) {
    char_u *arg = eap->arg;

    if (STRNCMP(arg, "FALLBACK ", 9) == 0) {
      arg += 9;
    }

    set_option_value("filetype", 0L, (char *)arg, OPT_LOCAL);
    if (arg != eap->arg) {
      did_filetype = false;
    }
  }
}

static void ex_digraphs(exarg_T *eap)
{
  if (*eap->arg != NUL) {
    putdigraph(eap->arg);
  } else {
    listdigraphs(eap->forceit);
  }
}

static void ex_set(exarg_T *eap)
{
  int flags = 0;

  if (eap->cmdidx == CMD_setlocal) {
    flags = OPT_LOCAL;
  } else if (eap->cmdidx == CMD_setglobal) {
    flags = OPT_GLOBAL;
  }
  (void)do_set(eap->arg, flags);
}

void set_no_hlsearch(bool flag)
{
  no_hlsearch = flag;
  set_vim_var_nr(VV_HLSEARCH, !no_hlsearch && p_hls);
}

/*
 * ":nohlsearch"
 */
static void ex_nohlsearch(exarg_T *eap)
{
  set_no_hlsearch(true);
  redraw_all_later(SOME_VALID);
}

// ":[N]match {group} {pattern}"
// Sets nextcmd to the start of the next command, if any.  Also called when
// skipping commands to find the next command.
static void ex_match(exarg_T *eap)
{
  char_u *p;
  char_u *g = NULL;
  char_u *end;
  int c;
  int id;

  if (eap->line2 <= 3) {
    id = eap->line2;
  } else {
    EMSG(e_invcmd);
    return;
  }

  // First clear any old pattern.
  if (!eap->skip) {
    match_delete(curwin, id, false);
  }

  if (ends_excmd(*eap->arg)) {
    end = eap->arg;
  } else if ((STRNICMP(eap->arg, "none", 4) == 0
              && (ascii_iswhite(eap->arg[4]) || ends_excmd(eap->arg[4])))) {
    end = eap->arg + 4;
  } else {
    p = skiptowhite(eap->arg);
    if (!eap->skip) {
      g = vim_strnsave(eap->arg, p - eap->arg);
    }
    p = skipwhite(p);
    if (*p == NUL) {
      // There must be two arguments.
      xfree(g);
      EMSG2(_(e_invarg2), eap->arg);
      return;
    }
    end = skip_regexp(p + 1, *p, true, NULL);
    if (!eap->skip) {
      if (*end != NUL && !ends_excmd(*skipwhite(end + 1))) {
        xfree(g);
        eap->errmsg = e_trailing;
        return;
      }
      if (*end != *p) {
        xfree(g);
        EMSG2(_(e_invarg2), p);
        return;
      }

      c = *end;
      *end = NUL;
      match_add(curwin, (const char *)g, (const char *)p + 1, 10, id,
                NULL, NULL);
      xfree(g);
      *end = c;
    }
  }
  eap->nextcmd = find_nextcmd(end);
}

static void ex_fold(exarg_T *eap)
{
  if (foldManualAllowed(true)) {
    pos_T start = { eap->line1, 1, 0 };
    pos_T end = { eap->line2, 1, 0 };
    foldCreate(curwin, start, end);
  }
}

static void ex_foldopen(exarg_T *eap)
{
  pos_T start = { eap->line1, 1, 0 };
  pos_T end = { eap->line2, 1, 0 };
  opFoldRange(start, end, eap->cmdidx == CMD_foldopen, eap->forceit, false);
}

static void ex_folddo(exarg_T *eap)
{
  // First set the marks for all lines closed/open.
  for (linenr_T lnum = eap->line1; lnum <= eap->line2; ++lnum) {
    if (hasFolding(lnum, NULL, NULL) == (eap->cmdidx == CMD_folddoclosed)) {
      ml_setmarked(lnum);
    }
  }

  global_exe(eap->arg);  // Execute the command on the marked lines.
  ml_clearmarked();      // clear rest of the marks
}

// Returns true if the supplied Ex cmdidx is for a location list command
// instead of a quickfix command.
bool is_loclist_cmd(int cmdidx)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (cmdidx < 0 || cmdidx >= CMD_SIZE) {
    return false;
  }
  return cmdnames[cmdidx].cmd_name[0] == 'l';
}

bool get_pressedreturn(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return ex_pressedreturn;
}

void set_pressedreturn(bool val)
{
  ex_pressedreturn = val;
}

static void ex_terminal(exarg_T *eap)
{
  char ex_cmd[1024];

  if (*eap->arg != NUL) {  // Run {cmd} in 'shell'.
    char *name = (char *)vim_strsave_escaped(eap->arg, (char_u *)"\"\\");
    snprintf(ex_cmd, sizeof(ex_cmd),
             ":enew%s | call termopen(\"%s\")",
             eap->forceit ? "!" : "", name);
    xfree(name);
  } else {  // No {cmd}: run the job with tokenized 'shell'.
    if (*p_sh == NUL) {
      EMSG(_(e_shellempty));
      return;
    }

    char **argv = shell_build_argv(NULL, NULL);
    char **p = argv;
    char tempstring[512];
    char shell_argv[512] = { 0 };

    while (*p != NULL) {
      snprintf(tempstring, sizeof(tempstring), ",\"%s\"", *p);
      xstrlcat(shell_argv, tempstring, sizeof(shell_argv));
      p++;
    }
    shell_free_argv(argv);

    snprintf(ex_cmd, sizeof(ex_cmd),
             ":enew%s | call termopen([%s])",
             eap->forceit ? "!" : "", shell_argv + 1);
  }

  do_cmdline_cmd(ex_cmd);
}

/// Checks if `cmd` is "previewable" (i.e. supported by 'inccommand').
///
/// @param[in] cmd Commandline to check. May start with a range or modifier.
///
/// @return true if `cmd` is previewable
bool cmd_can_preview(char_u *cmd)
{
  if (cmd == NULL) {
    return false;
  }

  // Ignore additional colons at the start...
  cmd = skip_colon_white(cmd, true);

  // Ignore any leading modifiers (:keeppatterns, :verbose, etc.)
  for (int len = modifier_len(cmd); len != 0; len = modifier_len(cmd)) {
    cmd += len;
    cmd = skip_colon_white(cmd, true);
  }

  exarg_T ea;
  memset(&ea, 0, sizeof(ea));
  // parse the command line
  ea.cmd = skip_range(cmd, NULL);
  if (*ea.cmd == '*') {
    ea.cmd = skipwhite(ea.cmd + 1);
  }
  char_u *end = find_command(&ea, NULL);

  switch (ea.cmdidx) {
  case CMD_substitute:
  case CMD_smagic:
  case CMD_snomagic:
    // Only preview once the pattern delimiter has been typed
    if (*end && !ASCII_ISALNUM(*end)) {
      return true;
    }
    break;
  default:
    break;
  }

  return false;
}

/// Gets a map of maps describing user-commands defined for buffer `buf` or
/// defined globally if `buf` is NULL.
///
/// @param buf  Buffer to inspect, or NULL to get global commands.
///
/// @return Map of maps describing commands
Dictionary commands_array(buf_T *buf)
{
  Dictionary rv = ARRAY_DICT_INIT;
  char str[20];
  garray_T *gap = (buf == NULL) ? &ucmds : &buf->b_ucmds;

  for (int i = 0; i < gap->ga_len; i++) {
    char arg[2] = { 0, 0 };
    Dictionary d = ARRAY_DICT_INIT;
    ucmd_T *cmd = USER_CMD_GA(gap, i);

    PUT(d, "name", STRING_OBJ(cstr_to_string((char *)cmd->uc_name)));
    PUT(d, "definition", STRING_OBJ(cstr_to_string((char *)cmd->uc_rep)));
    PUT(d, "script_id", INTEGER_OBJ(cmd->uc_script_ctx.sc_sid));
    PUT(d, "bang", BOOLEAN_OBJ(!!(cmd->uc_argt & EX_BANG)));
    PUT(d, "bar", BOOLEAN_OBJ(!!(cmd->uc_argt & EX_TRLBAR)));
    PUT(d, "register", BOOLEAN_OBJ(!!(cmd->uc_argt & EX_REGSTR)));

    switch (cmd->uc_argt & (EX_EXTRA | EX_NOSPC | EX_NEEDARG)) {
    case 0:
      arg[0] = '0'; break;
    case (EX_EXTRA):
      arg[0] = '*'; break;
    case (EX_EXTRA | EX_NOSPC):
      arg[0] = '?'; break;
    case (EX_EXTRA | EX_NEEDARG):
      arg[0] = '+'; break;
    case (EX_EXTRA | EX_NOSPC | EX_NEEDARG):
      arg[0] = '1'; break;
    }
    PUT(d, "nargs", STRING_OBJ(cstr_to_string(arg)));

    char *cmd_compl = get_command_complete(cmd->uc_compl);
    PUT(d, "complete", (cmd_compl == NULL
                        ? NIL : STRING_OBJ(cstr_to_string(cmd_compl))));
    PUT(d, "complete_arg", cmd->uc_compl_arg == NULL
        ? NIL : STRING_OBJ(cstr_to_string((char *)cmd->uc_compl_arg)));

    Object obj = NIL;
    if (cmd->uc_argt & EX_COUNT) {
      if (cmd->uc_def >= 0) {
        snprintf(str, sizeof(str), "%" PRId64, (int64_t)cmd->uc_def);
        obj = STRING_OBJ(cstr_to_string(str));    // -count=N
      } else {
        obj = STRING_OBJ(cstr_to_string("0"));    // -count
      }
    }
    PUT(d, "count", obj);

    obj = NIL;
    if (cmd->uc_argt & EX_RANGE) {
      if (cmd->uc_argt & EX_DFLALL) {
        obj = STRING_OBJ(cstr_to_string("%"));    // -range=%
      } else if (cmd->uc_def >= 0) {
        snprintf(str, sizeof(str), "%" PRId64, (int64_t)cmd->uc_def);
        obj = STRING_OBJ(cstr_to_string(str));    // -range=N
      } else {
        obj = STRING_OBJ(cstr_to_string("."));    // -range
      }
    }
    PUT(d, "range", obj);

    obj = NIL;
    for (int j = 0; addr_type_complete[j].expand != ADDR_NONE; j++) {
      if (addr_type_complete[j].expand != ADDR_LINES
          && addr_type_complete[j].expand == cmd->uc_addr_type) {
        obj = STRING_OBJ(cstr_to_string(addr_type_complete[j].name));
        break;
      }
    }
    PUT(d, "addr", obj);

    PUT(rv, (char *)cmd->uc_name, DICTIONARY_OBJ(d));
  }
  return rv;
}

void verify_command(char_u *cmd)
{
  if (strcmp("smile", (char *)cmd)) {
    return;  // acceptable non-existing command
  }
  MSG(" #xxn`          #xnxx`        ,+x@##@Mz;`        .xxx"
      "xxxxxxnz+,      znnnnnnnnnnnnnnnn.");
  MSG(" n###z          x####`      :x##########W+`      ,###"
      "##########M;    W################.");
  MSG(" n####;         x####`    `z##############W:     ,###"
      "#############   W################.");
  MSG(" n####W.        x####`   ,W#################+    ,###"
      "##############  W################.");
  MSG(" n#####n        x####`   @###################    ,###"
      "##############i W################.");
  MSG(" n######i       x####`  .#########@W@########*   ,###"
      "##############W`W################.");
  MSG(" n######@.      x####`  x######W*.  `;n#######:  ,###"
      "#x,,,,:*M######iW###@:,,,,,,,,,,,`");
  MSG(" n#######n      x####` *######+`       :M#####M  ,###"
      "#n      `x#####xW###@`");
  MSG(" n########*     x####``@####@;          `x#####i ,###"
      "#n       ,#####@W###@`");
  MSG(" n########@     x####`*#####i            `M####M ,###"
      "#n        x#########@`");
  MSG(" n#########     x####`M####z              :#####:,###"
      "#n        z#########@`");
  MSG(" n#########*    x####,#####.               n####+,###"
      "#n        n#########@`");
  MSG(" n####@####@,   x####i####x                ;####x,###"
      "#n       `W#####@####+++++++++++i");
  MSG(" n####*#####M`  x#########*                `####@,###"
      "#n       i#####MW###############W");
  MSG(" n####.######+  x####z####;                 W####,###"
      "#n      i@######W###############W");
  MSG(" n####.`W#####: x####n####:                 M####:###"
      "#@nnnnnW#######,W###############W");
  MSG(" n####. :#####M`x####z####;                 W####,###"
      "##############z W###############W");
  MSG(" n####.  #######x#########*                `####W,###"
      "#############W` W###############W");
  MSG(" n####.  `M#####W####i####x                ;####x,###"
      "############W,  W####+**********i");
  MSG(" n####.   ,##########,#####.               n####+,###"
      "###########n.   W###@`");
  MSG(" n####.    ##########`M####z              :#####:,###"
      "########Wz:     W###@`");
  MSG(" n####.    x#########`*#####i            `M####M ,###"
      "#x.....`        W###@`");
  MSG(" n####.    ,@########``@####@;          `x#####i ,###"
      "#n              W###@`");
  MSG(" n####.     *########` *#####@+`       ,M#####M  ,###"
      "#n              W###@`");
  MSG(" n####.      x#######`  x######W*.  `;n######@:  ,###"
      "#n              W###@,,,,,,,,,,,,`");
  MSG(" n####.      .@######`  .#########@W@########*   ,###"
      "#n              W################,");
  MSG(" n####.       i######`   @###################    ,###"
      "#n              W################,");
  MSG(" n####.        n#####`   ,W#################+    ,###"
      "#n              W################,");
  MSG(" n####.        .@####`    .n##############W;     ,###"
      "#n              W################,");
  MSG(" n####.         i####`      :x##########W+`      ,###"
      "#n              W################,");
  MSG(" +nnnn`          +nnn`        ,+x@##@Mz;`        .nnn"
      "n+              zxxxxxxxxxxxxxxxx.");
  MSG(" ");
  MSG("                                                     "
      "                              ,+M@#Mi");
  MSG("                                 "
      "                                                .z########");
  MSG("                                 "
      "                                               i@#########i");
  MSG("                                 "
      "                                             `############W`");
  MSG("                                 "
      "                                            `n#############i");
  MSG("                                 "
      "                                           `n##############n");
  MSG("     ``                          "
      "                                           z###############@`");
  MSG("    `W@z,                        "
      "                                          ##################,");
  MSG("    *#####`                      "
      "                                         i############@x@###i");
  MSG("    ######M.                     "
      "                                        :#############n`,W##+");
  MSG("    +######@:                    "
      "                                       .W#########M@##+  *##z");
  MSG("    :#######@:                   "
      "                                      `x########@#x###*  ,##n");
  MSG("    `@#######@;                  "
      "                                      z#########M*@nW#i  .##x");
  MSG("     z########@i                 "
      "                                     *###########WM#@#,  `##x");
  MSG("     i##########+                "
      "                                    ;###########*n###@   `##x");
  MSG("     `@#MM#######x,              "
      "                                   ,@#########zM,`z##M   `@#x");
  MSG("      n##M#W#######n.            "
      "   `.:i*+#zzzz##+i:.`             ,W#########Wii,`n@#@` n@##n");
  MSG("      ;###@#x#######n         `,i"
      "#nW@#####@@WWW@@####@Mzi.        ,W##########@z.. ;zM#+i####z");
  MSG("       x####nz########    .;#x@##"
      "@Wn#*;,.`      ``,:*#x@##M+,    ;@########xz@WM+#` `n@#######");
  MSG("       ,@####M########xi#@##@Mzi,"
      "`                     .+x###Mi:n##########Mz```.:i  *@######*");
  MSG("        *#####W#########ix+:`    "
      "                         :n#############z:       `*.`M######i");
  MSG("        i#W##nW@+@##@#M@;        "
      "                           ;W@@##########W,        i`x@#####,");
  MSG("        `@@n@Wn#@iMW*#*:         "
      "                            `iz#z@######x.           M######`");
  MSG("         z##zM###x`*, .`         "
      "                                 `iW#####W;:`        +#####M");
  MSG("         ,###nn##n`              "
      "                                  ,#####x;`        ,;@######");
  MSG("          x###xz#.               "
      "                                    in###+        `:######@.");
  MSG("          ;####n+                "
      "                                    `Mnx##xi`   , zM#######");
  MSG("          `W####+                "
      "i.                                   `.+x###@#. :n,z######:");
  MSG("           z####@`              ;"
      "#:                                     .ii@###@;.*M*z####@`");
  MSG("           i####M         `   `i@"
      "#,           ::                           +#n##@+@##W####n");
  MSG("           :####x    ,i. ##xzM###"
      "@`     i.   .@@,                           .z####x#######*");
  MSG("           ,###W;   i##Wz########"
      "#     :##   z##n                           ,@########x###:");
  MSG("            n##n   `W###########M"
      "`;n,  i#x  ,###@i                           *W########W#@`");
  MSG("           .@##+  `x###########@."
      " z#+ .M#W``x#####n`                         `;#######@z#x");
  MSG("           n###z :W############@ "
      " z#*  @##xM#######@n;                        `########nW+");
  MSG("          ;####nW##############W "
      ":@#* `@#############*                        :########z@i`");
  MSG("          M##################### "
      "M##:  @#############@:                       *W########M#");
  MSG("         ;#####################i."
      "##x`  W#############W,                       :n########zx");
  MSG("         x####################@.`"
      "x;    @#############z.                       .@########W#");
  MSG("        ,######################` "
      "      W###############x*,`                    W######zM#i");
  MSG("        #######################: "
      "      z##################@x+*#zzi            `@#########.");
  MSG("        W########W#z#M#########; "
      "      *##########################z            :@#######@`");
  MSG("       `@#######x`;#z ,x#######; "
      "      z###########M###xnM@########*            :M######@");
  MSG("       i########, x#@`  z######; "
      "      *##########i *#@`  `+########+`            n######.");
  MSG("       n#######@` M##,  `W#####. "
      "      *#########z  ###;    z########M:           :W####n");
  MSG("       M#######M  n##.   x####x  "
      "      `x########:  z##+    M#########@;           .n###+");
  MSG("       W#######@` :#W   `@####:  "
      "       `@######W   i###   ;###########@.            n##n");
  MSG("       W########z` ,,  .x####z   "
      "        @######@`  `W#;  `W############*            *###;");
  MSG("      `@#########Mi,:*n@####W`   "
      "        W#######*   ..  `n#############i            i###x");
  MSG("      .#####################z    "
      "       `@#######@*`    .x############n:`            ;####.");
  MSG("      :####################x`,,` "
      "       `W#########@x#+#@#############i              ,####:");
  MSG("      ;###################x#@###x"
      "i`      *############################:              `####i");
  MSG("      i##################+#######"
      "#M,      x##########################@`               W###i");
  MSG("      *################@; @######"
      "##@,     .W#########################@                x###:");
  MSG("      .+M#############z.  M######"
      "###x      ,W########################@`               ####.");
  MSG("      *M*;z@########x:    :W#####"
      "##i        .M########################i               i###:");
  MSG("      *##@z;#@####x:        :z###"
      "@i          `########################x               .###;");
  MSG("      *#####n;#@##            ;##"
      "*             ,x#####################@`               W##*");
  MSG("      *#######n;*            :M##"
      "W*,             *W####################`               n##z");
  MSG("      i########@.         ,*n####"
      "###M*`           `###################M                *##M");
  MSG("      i########n        `z#####@@"
      "#####Wi            ,M################;                ,##@`");
  MSG("      ;WMWW@###*       .x##@ni.``"
      ".:+zW##z`           `n##############z                  @##,");
  MSG("      .*++*i;;;.      .M#@+`     "
      "     .##n            `x############x`                  n##i");
  MSG("      :########*      x#W,       "
      "       *#+            *###########M`                   +##+");
  MSG("      ,#########     :#@:        "
      "        ##:           #nzzzzzzzzzz.                    :##x");
  MSG("      .#####Wz+`     ##+         "
      "        `MM`          .znnnnnnnnn.                     `@#@`");
  MSG("      `@@ni;*nMz`    @W`         "
      "         :#+           .x#######n                       x##,");
  MSG("       i;z@#####,   .#*          "
      "          z#:           ;;;*zW##;                       ###i");
  MSG("       z########:   :#;          "
      "          `Wx          +###Wni;n.                       ;##z");
  MSG("       n########W:  .#*          "
      "           ,#,        ;#######@+                        `@#M");
  MSG("      .###########n;.MM          "
      "            n*        ;iM#######*                        x#@`");
  MSG("      :#############@;;          "
      "            .n`      ,#W*iW#####W`                       +##,");
  MSG("      ,##############.           "
      "             ix.    `x###M;#######                       ,##i");
  MSG("      .#############@`           "
      "              x@n**#W######z;M###@.                       W##");
  MSG("      .##############W:          "
      "              .x############@*;zW#;                       z#x");
  MSG("      ,###############@;         "
      "               `##############@n*;.                       i#@");
  MSG("      ,#################i        "
      "                 :n##############W`                       .##,");
  MSG("      ,###################`      "
      "                   .+W##########W,                        `##i");
  MSG("      :###################@zi,`  "
      "                      ;zM@@@WMn*`                          @#z");
  MSG("      :#######################@x+"
      "*i;;:i#M,                 ``                               M#W");
  MSG("      ;##########################"
      "######@x.                                                  n##,");
  MSG("      i#####################@W@@@"
      "@Wxz*:`                                                    *##+");
  MSG("      *######################+```"
      "                                                           :##M");
  MSG("      ########################M; "
      "                                                           `@##,");
  MSG("      z#########################x"
      ",                                                           z###");
  MSG("      n##########################"
      "#n:                                                         ;##W`");
  MSG("      x##########################"
      "###Mz#++##*                                                 `W##i");
  MSG("      M##########################"
      "##########@`                                                 ###x");
  MSG("      W##########################"
      "###########`                                                 .###,");
  MSG("      @##########################"
      "##########M                                                   n##z");
  MSG("      @##################z*i@WMMM"
      "x#x@#####,.                                                   :##@.");
  MSG("     `#####################@xi`  "
      "   `::,*                                                       x##+");
  MSG("     .#####################@#M.  "
      "                                                               ;##@`");
  MSG("     ,#####################:.    "
      "                                                                M##i");
  MSG("     ;###################ni`     "
      "                                                                i##M");
  MSG("     *#################W#`       "
      "                                                                `W##,");
  MSG("     z#################@Wx+.     "
      "                                                                 +###");
  MSG("     x######################z.   "
      "                                                                 .@#@`");
  MSG("    `@#######################@;  "
      "                                                                  z##;");
  MSG("    :##########################: "
      "                                                                  :##z");
  MSG("    +#########################W# "
      "                                                                   M#W");
  MSG("    W################@n+*i;:,`                                "
      "                                      +##,");
  MSG("   :##################WMxz+,                                  "
      "                                      ,##i");
  MSG("   n#######################W..,                               "
      "                                       W##");
  MSG("  +#########################WW@+. .:.                         "
      "                                       z#x");
  MSG(" `@#############################@@###:                        "
      "                                       *#W");
  MSG(" #################################Wz:                         "
      "                                       :#@");
  MSG(",@###############################i                            "
      "                                       .##");
  MSG("n@@@@@@@#########################+                            "
      "                                       `##");
  MSG("`      `.:.`.,:iii;;;;;;;;iii;;;:`       `.``                 "
      "                                       `nW");
}
