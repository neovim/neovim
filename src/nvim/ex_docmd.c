// ex_docmd.c: functions for executing an Ex command line.

#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <uv.h>

#include "auto/config.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/ui.h"
#include "nvim/arglist.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/channel.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/debugger.h"
#include "nvim/digraph.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_eval_defs.h"
#include "nvim/ex_getln.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/input.h"
#include "nvim/keycodes.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/msgpack_rpc/server.h"
#include "nvim/normal.h"
#include "nvim/normal_defs.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/shell.h"
#include "nvim/path.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/search.h"
#include "nvim/shada.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/statusline.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/undo_defs.h"
#include "nvim/usercmd.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

static const char e_ambiguous_use_of_user_defined_command[]
  = N_("E464: Ambiguous use of user-defined command");
static const char e_no_call_stack_to_substitute_for_stack[]
  = N_("E489: No call stack to substitute for \"<stack>\"");
static const char e_not_an_editor_command[]
  = N_("E492: Not an editor command");
static const char e_no_autocommand_file_name_to_substitute_for_afile[]
  = N_("E495: No autocommand file name to substitute for \"<afile>\"");
static const char e_no_autocommand_buffer_number_to_substitute_for_abuf[]
  = N_("E496: No autocommand buffer number to substitute for \"<abuf>\"");
static const char e_no_autocommand_match_name_to_substitute_for_amatch[]
  = N_("E497: No autocommand match name to substitute for \"<amatch>\"");
static const char e_no_source_file_name_to_substitute_for_sfile[]
  = N_("E498: No :source file name to substitute for \"<sfile>\"");
static const char e_no_line_number_to_use_for_slnum[]
  = N_("E842: No line number to use for \"<slnum>\"");
static const char e_no_line_number_to_use_for_sflnum[]
  = N_("E961: No line number to use for \"<sflnum>\"");
static const char e_no_script_file_name_to_substitute_for_script[]
  = N_("E1274: No script file name to substitute for \"<script>\"");

static int quitmore = 0;
static bool ex_pressedreturn = false;

// Struct for storing a line inside a while/for loop
typedef struct {
  char *line;            // command line
  linenr_T lnum;                // sourcing_lnum of the line
} wcmd_T;

#define FREE_WCMD(wcmd) xfree((wcmd)->line)

/// Structure used to store info for line position in a while or for loop.
/// This is required, because do_one_cmd() may invoke ex_function(), which
/// reads more lines that may come from the while/for loop.
struct loop_cookie {
  garray_T *lines_gap;               // growarray with line info
  int current_line;                     // last read line from growarray
  int repeating;                        // true when looping a second time
  // When "repeating" is false use "getline" and "cookie" to get lines
  LineGetter lc_getline;
  void *cookie;
};

// Struct to save a few things while debugging.  Used in do_cmdline() only.
struct dbg_stuff {
  int trylevel;
  int force_abort;
  except_T *caught_stack;
  char *vv_exception;
  char *vv_throwpoint;
  int did_emsg;
  int got_int;
  bool did_throw;
  int need_rethrow;
  int check_cstack;
  except_T *current_exception;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_docmd.c.generated.h"
#endif

// Declare cmdnames[].
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds_defs.generated.h"
#endif

static char dollar_command[2] = { '$', 0 };

static void save_dbg_stuff(struct dbg_stuff *dsp)
{
  dsp->trylevel = trylevel;
  trylevel = 0;
  dsp->force_abort = force_abort;
  force_abort = false;
  dsp->caught_stack = caught_stack;
  caught_stack = NULL;
  dsp->vv_exception = v_exception(NULL);
  dsp->vv_throwpoint = v_throwpoint(NULL);

  // Necessary for debugging an inactive ":catch", ":finally", ":endtry".
  dsp->did_emsg = did_emsg;
  did_emsg = false;
  dsp->got_int = got_int;
  got_int = false;
  dsp->did_throw = did_throw;
  did_throw = false;
  dsp->need_rethrow = need_rethrow;
  need_rethrow = false;
  dsp->check_cstack = check_cstack;
  check_cstack = false;
  dsp->current_exception = current_exception;
  current_exception = NULL;
}

static void restore_dbg_stuff(struct dbg_stuff *dsp)
{
  suppress_errthrow = false;
  trylevel = dsp->trylevel;
  force_abort = dsp->force_abort;
  caught_stack = dsp->caught_stack;
  v_exception(dsp->vv_exception);
  v_throwpoint(dsp->vv_throwpoint);
  did_emsg = dsp->did_emsg;
  got_int = dsp->got_int;
  did_throw = dsp->did_throw;
  need_rethrow = dsp->need_rethrow;
  check_cstack = dsp->check_cstack;
  current_exception = dsp->current_exception;
}

/// Check if ffname differs from fnum.
/// fnum is a buffer number. 0 == current buffer, 1-or-more must be a valid buffer ID.
/// ffname is a full path to where a buffer lives on-disk or would live on-disk.
static bool is_other_file(int fnum, char *ffname)
{
  if (fnum != 0) {
    if (fnum == curbuf->b_fnum) {
      return false;
    }

    return true;
  }

  if (ffname == NULL) {
    return true;
  }

  if (*ffname == NUL) {
    return false;
  }

  if (!curbuf->file_id_valid
      && curbuf->b_sfname != NULL
      && *curbuf->b_sfname != NUL) {
    // This occurs with unsaved buffers. In which case `ffname`
    // actually corresponds to curbuf->b_sfname
    return path_fnamecmp(ffname, curbuf->b_sfname) != 0;
  }

  return otherfile(ffname);
}

/// Repeatedly get commands for Ex mode, until the ":vi" command is given.
void do_exmode(void)
{
  exmode_active = true;
  State = MODE_NORMAL;
  may_trigger_modechanged();

  // When using ":global /pat/ visual" and then "Q" we return to continue
  // the :global command.
  if (global_busy) {
    return;
  }

  int save_msg_scroll = msg_scroll;
  RedrawingDisabled++;  // don't redisplay the window
  no_wait_return++;  // don't wait for return

  msg(_("Entering Ex mode.  Type \"visual\" to go to Normal mode."), 0);
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
    varnumber_T changedtick = buf_get_changedtick(curbuf);
    int prev_msg_row = msg_row;
    linenr_T prev_line = curwin->w_cursor.lnum;
    cmdline_row = msg_row;
    do_cmdline(NULL, getexline, NULL, 0);
    lines_left = Rows - 1;

    if ((prev_line != curwin->w_cursor.lnum
         || changedtick != buf_get_changedtick(curbuf)) && !ex_no_reprint) {
      if (curbuf->b_ml.ml_flags & ML_EMPTY) {
        emsg(_(e_empty_buffer));
      } else {
        if (ex_pressedreturn) {
          // Make sure the message overwrites the right line and isn't throttled.
          msg_scroll_flush();
          // go up one line, to overwrite the ":<CR>" line, so the
          // output doesn't contain empty lines.
          msg_row = prev_msg_row;
          if (prev_msg_row == Rows - 1) {
            msg_row--;
          }
        }
        msg_col = 0;
        print_line_no_prefix(curwin->w_cursor.lnum, false, false);
        msg_clr_eos();
      }
    } else if (ex_pressedreturn && !ex_no_reprint) {  // must be at EOF
      if (curbuf->b_ml.ml_flags & ML_EMPTY) {
        emsg(_(e_empty_buffer));
      } else {
        emsg(_("E501: At end-of-file"));
      }
    }
  }

  RedrawingDisabled--;
  no_wait_return--;
  redraw_all_later(UPD_NOT_VALID);
  update_screen();
  need_wait_return = false;
  msg_scroll = save_msg_scroll;
}

/// Print the executed command for when 'verbose' is set.
///
/// @param lnum  if 0, only print the command.
static void msg_verbose_cmd(linenr_T lnum, char *cmd)
  FUNC_ATTR_NONNULL_ALL
{
  no_wait_return++;
  verbose_enter_scroll();

  if (lnum == 0) {
    smsg(0, _("Executing: %s"), cmd);
  } else {
    smsg(0, _("line %" PRIdLINENR ": %s"), lnum, cmd);
  }
  if (msg_silent == 0) {
    msg_puts("\n");   // don't overwrite this
  }

  verbose_leave_scroll();
  no_wait_return--;
}

static int cmdline_call_depth = 0;  ///< recursiveness

/// Start executing an Ex command line.
///
/// @return  FAIL if too recursive, OK otherwise.
static int do_cmdline_start(void)
{
  assert(cmdline_call_depth >= 0);
  // It's possible to create an endless loop with ":execute", catch that
  // here.  The value of 200 allows nested function calls, ":source", etc.
  // Allow 200 or 'maxfuncdepth', whatever is larger.
  if (cmdline_call_depth >= 200 && cmdline_call_depth >= p_mfd) {
    return FAIL;
  }
  cmdline_call_depth++;
  start_batch_changes();
  return OK;
}

/// End executing an Ex command line.
static void do_cmdline_end(void)
{
  cmdline_call_depth--;
  assert(cmdline_call_depth >= 0);
  end_batch_changes();
}

/// Execute a simple command line.  Used for translated commands like "*".
int do_cmdline_cmd(const char *cmd)
{
  return do_cmdline((char *)cmd, NULL, NULL, DOCMD_VERBOSE|DOCMD_NOWAIT|DOCMD_KEYTYPED);
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
///
/// @param cookie  argument for fgetline()
///
/// @return FAIL if cmdline could not be executed, OK otherwise
int do_cmdline(char *cmdline, LineGetter fgetline, void *cookie, int flags)
{
  char *next_cmdline;                   // next cmd to execute
  char *cmdline_copy = NULL;            // copy of cmd line
  bool used_getline = false;            // used "fgetline" to obtain command
  static int recursive = 0;             // recursive depth
  bool msg_didout_before_start = false;
  int count = 0;                        // line number count
  bool did_inc = false;                 // incremented RedrawingDisabled
  int block_indent = -1;                // indent for ext_cmdline block event
  int retval = OK;
  cstack_T cstack = {                   // conditional stack
    .cs_idx = -1,
  };
  garray_T lines_ga;                    // keep lines for ":while"/":for"
  int current_line = 0;                 // active line in lines_ga
  char *fname = NULL;                   // function or script name
  linenr_T *breakpoint = NULL;          // ptr to breakpoint field in cookie
  int *dbg_tick = NULL;                 // ptr to dbg_tick field in cookie
  struct dbg_stuff debug_saved;         // saved things for debug mode
  msglist_T *private_msg_list;

  // "fgetline" and "cookie" passed to do_one_cmd()
  char *(*cmd_getline)(int, void *, int, bool);
  void *cmd_cookie;
  struct loop_cookie cmd_loop_cookie;

  // For every pair of do_cmdline()/do_one_cmd() calls, use an extra memory
  // location for storing error messages to be converted to an exception.
  // This ensures that the do_errthrow() call in do_one_cmd() does not
  // combine the messages stored by an earlier invocation of do_one_cmd()
  // with the command name of the later one.  This would happen when
  // BufWritePost autocommands are executed after a write error.
  msglist_T **saved_msg_list = msg_list;
  msg_list = &private_msg_list;
  private_msg_list = NULL;

  if (do_cmdline_start() == FAIL) {
    emsg(_(e_command_too_recursive));
    // When converting to an exception, we do not include the command name
    // since this is not an error of the specific command.
    do_errthrow((cstack_T *)NULL, NULL);
    msg_list = saved_msg_list;
    return FAIL;
  }

  ga_init(&lines_ga, (int)sizeof(wcmd_T), 10);

  void *real_cookie = getline_cookie(fgetline, cookie);

  // Inside a function use a higher nesting level.
  bool getline_is_func = getline_equal(fgetline, cookie, get_func_line);
  if (getline_is_func && ex_nesting_level == func_level(real_cookie)) {
    ex_nesting_level++;
  }

  // Get the function or script name and the address where the next breakpoint
  // line and the debug tick for a function or script are stored.
  if (getline_is_func) {
    fname = func_name(real_cookie);
    breakpoint = func_breakpoint(real_cookie);
    dbg_tick = func_dbg_tick(real_cookie);
  } else if (getline_equal(fgetline, cookie, getsourceline)) {
    fname = SOURCING_NAME;
    breakpoint = source_breakpoint(real_cookie);
    dbg_tick = source_dbg_tick(real_cookie);
  }

  // Initialize "force_abort"  and "suppress_errthrow" at the top level.
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
    CLEAR_FIELD(debug_saved);
  }

  int initial_trylevel = trylevel;

  // "did_throw" will be set to true when an exception is being thrown.
  did_throw = false;
  // "did_emsg" will be set to true when emsg() is used, in which case we
  // cancel the whole command line, and any if/endif or loop.
  // If force_abort is set, we cancel everything.
  did_emsg = false;

  // KeyTyped is only set when calling vgetc().  Reset it here when not
  // calling vgetc() (sourced command lines).
  if (!(flags & DOCMD_KEYTYPED)
      && !getline_equal(fgetline, cookie, getexline)) {
    KeyTyped = false;
  }

  // Continue executing command lines:
  // - when inside an ":if", ":while" or ":for"
  // - for multiple commands on one line, separated with '|'
  // - when repeating until there are no more lines (for ":source")
  next_cmdline = cmdline;
  do {
    getline_is_func = getline_equal(fgetline, cookie, get_func_line);

    // stop skipping cmds for an error msg after all endif/while/for
    if (next_cmdline == NULL
        && !force_abort
        && cstack.cs_idx < 0
        && !(getline_is_func
             && func_has_abort(real_cookie))) {
      did_emsg = false;
    }

    // 1. If repeating a line in a loop, get a line from lines_ga.
    // 2. If no line given: Get an allocated line with fgetline().
    // 3. If a line is given: Make a copy, so we can mess with it.

    // 1. If repeating, get a previous line from lines_ga.
    if (cstack.cs_looplevel > 0 && current_line < lines_ga.ga_len) {
      // Each '|' separated command is stored separately in lines_ga, to
      // be able to jump to it.  Don't use next_cmdline now.
      XFREE_CLEAR(cmdline_copy);

      // Check if a function has returned or, unless it has an unclosed
      // try conditional, aborted.
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
                                          fname, SOURCING_LNUM);
        *dbg_tick = debug_tick;
      }

      next_cmdline = ((wcmd_T *)(lines_ga.ga_data))[current_line].line;
      SOURCING_LNUM = ((wcmd_T *)(lines_ga.ga_data))[current_line].lnum;

      // Did we encounter a breakpoint?
      if (breakpoint != NULL && *breakpoint != 0 && *breakpoint <= SOURCING_LNUM) {
        dbg_breakpoint(fname, SOURCING_LNUM);
        // Find next breakpoint.
        *breakpoint = dbg_find_breakpoint(getline_equal(fgetline, cookie, getsourceline),
                                          fname, SOURCING_LNUM);
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

    // 2. If no line given, get an allocated line with fgetline().
    if (next_cmdline == NULL) {
      int indent = cstack.cs_idx < 0 ? 0 : (cstack.cs_idx + 1) * 2;
      if (count >= 1 && getline_equal(fgetline, cookie, getexline)) {
        if (ui_has(kUICmdline)) {
          ui_ext_cmdline_block_append((size_t)MAX(0, block_indent), last_cmdline);
          block_indent = indent;
        } else if (count == 1) {
          // Need to set msg_didout for the first line after an ":if",
          // otherwise the ":if" will be overwritten.
          msg_didout = true;
        }
      }
      if (fgetline == NULL || (next_cmdline = fgetline(':', cookie, indent, true)) == NULL) {
        // Don't call wait_return() for aborted command line.  The NULL
        // returned for the end of a sourced file or executed function
        // doesn't do this.
        if (KeyTyped && !(flags & DOCMD_REPEAT)) {
          need_wait_return = false;
        }
        retval = FAIL;
        break;
      }
      used_getline = true;

      // Keep the first typed line.  Clear it when more lines are typed.
      if (flags & DOCMD_KEEPLINE) {
        xfree(repeat_cmdline);
        if (count == 0) {
          repeat_cmdline = xstrdup(next_cmdline);
        } else {
          repeat_cmdline = NULL;
        }
      }
    } else if (cmdline_copy == NULL) {
      // 3. Make a copy of the command so we can mess with it.
      next_cmdline = xstrdup(next_cmdline);
    }
    cmdline_copy = next_cmdline;

    int current_line_before = 0;
    // Inside a while/for loop, and when the command looks like a ":while"
    // or ":for", the line is stored, because we may need it later when
    // looping.
    //
    // When there is a '|' and another command, it is stored separately,
    // because we need to be able to jump back to it from an
    // :endwhile/:endfor.
    //
    // Pass a different "fgetline" function to do_one_cmd() below,
    // that it stores lines in or reads them from "lines_ga".  Makes it
    // possible to define a function inside a while/for loop.
    if ((cstack.cs_looplevel > 0 || has_loop_cmd(next_cmdline))) {
      cmd_getline = get_loop_line;
      cmd_cookie = (void *)&cmd_loop_cookie;
      cmd_loop_cookie.lines_gap = &lines_ga;
      cmd_loop_cookie.current_line = current_line;
      cmd_loop_cookie.lc_getline = fgetline;
      cmd_loop_cookie.cookie = cookie;
      cmd_loop_cookie.repeating = (current_line < lines_ga.ga_len);

      // Save the current line when encountering it the first time.
      if (current_line == lines_ga.ga_len) {
        store_loop_line(&lines_ga, next_cmdline);
      }
      current_line_before = current_line;
    } else {
      cmd_getline = fgetline;
      cmd_cookie = cookie;
    }

    did_endif = false;

    if (count++ == 0) {
      // All output from the commands is put below each other, without
      // waiting for a return. Don't do this when executing commands
      // from a script or when being called recursive (e.g. for ":e
      // +command file").
      if (!(flags & DOCMD_NOWAIT) && !recursive) {
        msg_didout_before_start = msg_didout;
        msg_didany = false;         // no output yet
        msg_start();
        msg_scroll = true;          // put messages below each other
        no_wait_return++;           // don't wait for return until finished
        RedrawingDisabled++;
        did_inc = true;
      }
    }

    if ((p_verbose >= 15 && SOURCING_NAME != NULL) || p_verbose >= 16) {
      msg_verbose_cmd(SOURCING_LNUM, cmdline_copy);
    }

    // 2. Execute one '|' separated command.
    //    do_one_cmd() will return NULL if there is no trailing '|'.
    //    "cmdline_copy" can change, e.g. for '%' and '#' expansion.
    recursive++;
    next_cmdline = do_one_cmd(&cmdline_copy, flags, &cstack, cmd_getline, cmd_cookie);
    recursive--;

    if (cmd_cookie == (void *)&cmd_loop_cookie) {
      // Use "current_line" from "cmd_loop_cookie", it may have been
      // incremented when defining a function.
      current_line = cmd_loop_cookie.current_line;
    }

    if (next_cmdline == NULL) {
      XFREE_CLEAR(cmdline_copy);

      // If the command was typed, remember it for the ':' register.
      // Do this AFTER executing the command to make :@: work.
      if (getline_equal(fgetline, cookie, getexline)
          && new_last_cmdline != NULL) {
        xfree(last_cmdline);
        last_cmdline = new_last_cmdline;
        new_last_cmdline = NULL;
      }
    } else {
      // need to copy the command after the '|' to cmdline_copy, for the
      // next do_one_cmd()
      STRMOVE(cmdline_copy, next_cmdline);
      next_cmdline = cmdline_copy;
    }

    // reset did_emsg for a function that is not aborted by an error
    if (did_emsg && !force_abort
        && getline_equal(fgetline, cookie, get_func_line)
        && !func_has_abort(real_cookie)) {
      did_emsg = false;
    }

    if (cstack.cs_looplevel > 0) {
      current_line++;

      // An ":endwhile", ":endfor" and ":continue" is handled here.
      // If we were executing commands, jump back to the ":while" or
      // ":for".
      // If we were not executing commands, decrement cs_looplevel.
      if (cstack.cs_lflags & (CSL_HAD_CONT | CSL_HAD_ENDLOOP)) {
        cstack.cs_lflags &= ~(CSL_HAD_CONT | CSL_HAD_ENDLOOP);

        // Jump back to the matching ":while" or ":for".  Be careful
        // not to use a cs_line[] from an entry that isn't a ":while"
        // or ":for": It would make "current_line" invalid and can
        // cause a crash.
        if (!did_emsg && !got_int && !did_throw
            && cstack.cs_idx >= 0
            && (cstack.cs_flags[cstack.cs_idx]
                & (CSF_WHILE | CSF_FOR))
            && cstack.cs_line[cstack.cs_idx] >= 0
            && (cstack.cs_flags[cstack.cs_idx] & CSF_ACTIVE)) {
          current_line = cstack.cs_line[cstack.cs_idx];
          // remember we jumped there
          cstack.cs_lflags |= CSL_HAD_LOOP;
          line_breakcheck();                    // check if CTRL-C typed

          // Check for the next breakpoint at or after the ":while"
          // or ":for".
          if (breakpoint != NULL && lines_ga.ga_len > current_line) {
            *breakpoint = dbg_find_breakpoint(getline_equal(fgetline, cookie, getsourceline), fname,
                                              ((wcmd_T *)lines_ga.ga_data)[current_line].lnum - 1);
            *dbg_tick = debug_tick;
          }
        } else {
          // can only get here with ":endwhile" or ":endfor"
          if (cstack.cs_idx >= 0) {
            rewind_conditionals(&cstack, cstack.cs_idx - 1,
                                CSF_WHILE | CSF_FOR, &cstack.cs_looplevel);
          }
        }
      } else if (cstack.cs_lflags & CSL_HAD_LOOP) {
        // For a ":while" or ":for" we need to remember the line number.
        cstack.cs_lflags &= ~CSL_HAD_LOOP;
        cstack.cs_line[cstack.cs_idx] = current_line_before;
      }
    }

    // When not inside any ":while" loop, clear remembered lines.
    if (cstack.cs_looplevel == 0) {
      if (!GA_EMPTY(&lines_ga)) {
        SOURCING_LNUM = ((wcmd_T *)lines_ga.ga_data)[lines_ga.ga_len - 1].lnum;
        GA_DEEP_CLEAR(&lines_ga, wcmd_T, FREE_WCMD);
      }
      current_line = 0;
    }

    // A ":finally" makes did_emsg, got_int and did_throw pending for
    // being restored at the ":endtry".  Reset them here and set the
    // ACTIVE and FINALLY flags, so that the finally clause gets executed.
    // This includes the case where a missing ":endif", ":endwhile" or
    // ":endfor" was detected by the ":finally" itself.
    if (cstack.cs_lflags & CSL_HAD_FINA) {
      cstack.cs_lflags &= ~CSL_HAD_FINA;
      report_make_pending((cstack.cs_pending[cstack.cs_idx]
                           & (CSTP_ERROR | CSTP_INTERRUPT | CSTP_THROW)),
                          did_throw ? current_exception : NULL);
      did_emsg = got_int = did_throw = false;
      cstack.cs_flags[cstack.cs_idx] |= CSF_ACTIVE | CSF_FINALLY;
    }

    // Update global "trylevel" for recursive calls to do_cmdline() from
    // within this loop.
    trylevel = initial_trylevel + cstack.cs_trylevel;

    // If the outermost try conditional (across function calls and sourced
    // files) is aborted because of an error, an interrupt, or an uncaught
    // exception, cancel everything.  If it is left normally, reset
    // force_abort to get the non-EH compatible abortion behavior for
    // the rest of the script.
    if (trylevel == 0 && !did_emsg && !got_int && !did_throw) {
      force_abort = false;
    }

    // Convert an interrupt to an exception if appropriate.
    do_intthrow(&cstack);

    // Continue executing command lines when:
    // - no CTRL-C typed, no aborting error, no exception thrown or try
    //   conditionals need to be checked for executing finally clauses or
    //   catching an interrupt exception
    // - didn't get an error message or lines are not typed
    // - there is a command after '|', inside a :if, :while, :for or :try, or
    //   looping for ":source" command or function call.
  } while (!((got_int || (did_emsg && force_abort) || did_throw)
             && cstack.cs_trylevel == 0)
           && !(did_emsg
                // Keep going when inside try/catch, so that the error can be
                // deal with, except when it is a syntax error, it may cause
                // the :endtry to be missed.
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
    // If a sourced file or executed function ran to its end, report the
    // unclosed conditional.
    if (!got_int && !did_throw && !aborting()
        && ((getline_equal(fgetline, cookie, getsourceline)
             && !source_finished(fgetline, cookie))
            || (getline_equal(fgetline, cookie, get_func_line)
                && !func_has_ended(real_cookie)))) {
      if (cstack.cs_flags[cstack.cs_idx] & CSF_TRY) {
        emsg(_(e_endtry));
      } else if (cstack.cs_flags[cstack.cs_idx] & CSF_WHILE) {
        emsg(_(e_endwhile));
      } else if (cstack.cs_flags[cstack.cs_idx] & CSF_FOR) {
        emsg(_(e_endfor));
      } else {
        emsg(_(e_endif));
      }
    }

    // Reset "trylevel" in case of a ":finish" or ":return" or a missing
    // ":endtry" in a sourced file or executed function.  If the try
    // conditional is in its finally clause, ignore anything pending.
    // If it is in a catch clause, finish the caught exception.
    // Also cleanup any "cs_forinfo" structures.
    do {
      int idx = cleanup_conditionals(&cstack, 0, true);

      if (idx >= 0) {
        idx--;              // remove try block not in its finally clause
      }
      rewind_conditionals(&cstack, idx, CSF_WHILE | CSF_FOR,
                          &cstack.cs_looplevel);
    } while (cstack.cs_idx >= 0);
    trylevel = initial_trylevel;
  }

  // If a missing ":endtry", ":endwhile", ":endfor", or ":endif" or a memory
  // lack was reported above and the error message is to be converted to an
  // exception, do this now after rewinding the cstack.
  do_errthrow(&cstack, getline_equal(fgetline, cookie, get_func_line) ? "endfunction" : NULL);

  if (trylevel == 0) {
    // When an exception is being thrown out of the outermost try
    // conditional, discard the uncaught exception, disable the conversion
    // of interrupts or errors to exceptions, and ensure that no more
    // commands are executed.
    if (did_throw) {
      handle_did_throw();
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
  if (did_throw) {
    need_rethrow = true;
  }
  if ((getline_equal(fgetline, cookie, getsourceline)
       && ex_nesting_level > source_level(real_cookie))
      || (getline_equal(fgetline, cookie, get_func_line)
          && ex_nesting_level > func_level(real_cookie) + 1)) {
    if (!did_throw) {
      check_cstack = true;
    }
  } else {
    // When leaving a function, reduce nesting level.
    if (getline_equal(fgetline, cookie, get_func_line)) {
      ex_nesting_level--;
    }
    // Go to debug mode when returning from a function in which we are
    // single-stepping.
    if ((getline_equal(fgetline, cookie, getsourceline)
         || getline_equal(fgetline, cookie, get_func_line))
        && ex_nesting_level + 1 <= debug_break_level) {
      do_debug(getline_equal(fgetline, cookie, getsourceline)
               ? _("End of sourced file")
               : _("End of function"));
    }
  }

  // Restore the exception environment (done after returning from the
  // debugger).
  if (flags & DOCMD_EXCRESET) {
    restore_dbg_stuff(&debug_saved);
  }

  msg_list = saved_msg_list;

  // Cleanup if "cs_emsg_silent_list" remains.
  if (cstack.cs_emsg_silent_list != NULL) {
    eslist_T *temp;
    for (eslist_T *elem = cstack.cs_emsg_silent_list; elem != NULL; elem = temp) {
      temp = elem->next;
      xfree(elem);
    }
  }

  // If there was too much output to fit on the command line, ask the user to
  // hit return before redrawing the screen. With the ":global" command we do
  // this only once after the command is finished.
  if (did_inc) {
    RedrawingDisabled--;
    no_wait_return--;
    msg_scroll = false;

    // When just finished an ":if"-":else" which was typed, no need to
    // wait for hit-return.  Also for an error situation.
    if (retval == FAIL
        || (did_endif && KeyTyped && !did_emsg)) {
      need_wait_return = false;
      msg_didany = false;               // don't wait when restarting edit
    } else if (need_wait_return) {
      // The msg_start() above clears msg_didout. The wait_return() we do
      // here should not overwrite the command that may be shown before
      // doing that.
      msg_didout |= msg_didout_before_start;
      wait_return(false);
    }
  }

  if (block_indent >= 0) {
    ui_ext_cmdline_block_leave();
  }

  did_endif = false;    // in case do_cmdline used recursively

  do_cmdline_end();
  return retval;
}

/// Handle when "did_throw" is set after executing commands.
void handle_did_throw(void)
{
  assert(current_exception != NULL);
  char *p = NULL;
  msglist_T *messages = NULL;

  // If the uncaught exception is a user exception, report it as an
  // error.  If it is an error exception, display the saved error
  // message now.  For an interrupt exception, do nothing; the
  // interrupt message is given elsewhere.
  switch (current_exception->type) {
  case ET_USER:
    vim_snprintf(IObuff, IOSIZE,
                 _("E605: Exception not caught: %s"),
                 current_exception->value);
    p = xstrdup(IObuff);
    break;
  case ET_ERROR:
    messages = current_exception->messages;
    current_exception->messages = NULL;
    break;
  case ET_INTERRUPT:
    break;
  }

  estack_push(ETYPE_EXCEPT, current_exception->throw_name, current_exception->throw_lnum);
  current_exception->throw_name = NULL;

  discard_current_exception();              // uses IObuff if 'verbose'

  // If "silent!" is active the uncaught exception is not fatal.
  if (emsg_silent == 0) {
    suppress_errthrow = true;
    force_abort = true;
  }

  if (messages != NULL) {
    do {
      msglist_T *next = messages->next;
      emsg_multiline(messages->msg, "emsg", HLF_E, messages->multiline);
      xfree(messages->msg);
      xfree(messages->sfile);
      xfree(messages);
      messages = next;
    } while (messages != NULL);
  } else if (p != NULL) {
    emsg(p);
    xfree(p);
  }
  xfree(SOURCING_NAME);
  estack_pop();
}

/// Obtain a line when inside a ":while" or ":for" loop.
static char *get_loop_line(int c, void *cookie, int indent, bool do_concat)
{
  struct loop_cookie *cp = (struct loop_cookie *)cookie;

  if (cp->current_line + 1 >= cp->lines_gap->ga_len) {
    if (cp->repeating) {
      return NULL;              // trying to read past ":endwhile"/":endfor"
    }
    char *line;
    // First time inside the ":while"/":for": get line normally.
    if (cp->lc_getline == NULL) {
      line = getcmdline(c, 0, indent, do_concat);
    } else {
      line = cp->lc_getline(c, cp->cookie, indent, do_concat);
    }
    if (line != NULL) {
      store_loop_line(cp->lines_gap, line);
      cp->current_line++;
    }

    return line;
  }

  KeyTyped = false;
  cp->current_line++;
  wcmd_T *wp = (wcmd_T *)(cp->lines_gap->ga_data) + cp->current_line;
  SOURCING_LNUM = wp->lnum;
  return xstrdup(wp->line);
}

/// Store a line in "gap" so that a ":while" loop can execute it again.
static void store_loop_line(garray_T *gap, char *line)
{
  wcmd_T *p = GA_APPEND_VIA_PTR(wcmd_T, gap);
  p->line = xstrdup(line);
  p->lnum = SOURCING_LNUM;
}

/// If "fgetline" is get_loop_line(), return true if the getline it uses equals
/// "func".  * Otherwise return true when "fgetline" equals "func".
///
/// @param cookie  argument for fgetline()
bool getline_equal(LineGetter fgetline, void *cookie, LineGetter func)
{
  // When "fgetline" is "get_loop_line()" use the "cookie" to find the
  // function that's originally used to obtain the lines.  This may be
  // nested several levels.
  LineGetter gp = fgetline;
  struct loop_cookie *cp = (struct loop_cookie *)cookie;
  while (gp == get_loop_line) {
    gp = cp->lc_getline;
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
  // When "fgetline" is "get_loop_line()" use the "cookie" to find the
  // cookie that's originally used to obtain the lines.  This may be nested
  // several levels.
  LineGetter gp = fgetline;
  struct loop_cookie *cp = (struct loop_cookie *)cookie;
  while (gp == get_loop_line) {
    gp = cp->lc_getline;
    cp = cp->cookie;
  }
  return cp;
}

/// Helper function to apply an offset for buffer commands, i.e. ":bdelete",
/// ":bwipeout", etc.
///
/// @return  the buffer number.
static int compute_buffer_local_count(cmd_addr_T addr_type, linenr_T lnum, int offset)
{
  int count = offset;

  buf_T *buf = firstbuf;
  while (buf->b_next != NULL && buf->b_fnum < lnum) {
    buf = buf->b_next;
  }
  while (count != 0) {
    count += (count < 0) ? 1 : -1;
    buf_T *nextbuf = (offset < 0) ? buf->b_prev : buf->b_next;
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
      buf_T *nextbuf = (offset >= 0) ? buf->b_prev : buf->b_next;
      if (nextbuf == NULL) {
        break;
      }
      buf = nextbuf;
    }
  }
  return buf->b_fnum;
}

/// @return  the window number of "win" or,
///          the number of windows if "win" is NULL
static int current_win_nr(const win_T *win)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  int nr = 0;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    nr++;
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
    nr++;
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
static void get_wincmd_addr_type(const char *arg, exarg_T *eap)
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
    eap->addr_type = ADDR_OTHER;
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
static char *skip_colon_white(const char *p, bool skipleadingwhite)
{
  if (skipleadingwhite) {
    p = skipwhite(p);
  }

  while (*p == ':') {
    p = skipwhite(p + 1);
  }

  return (char *)p;
}

/// Set the addr type for command
///
/// @param p pointer to character after command name in cmdline
void set_cmd_addr_type(exarg_T *eap, char *p)
{
  // ea.addr_type for user commands is set by find_ucmd
  if (IS_USER_CMDIDX(eap->cmdidx)) {
    return;
  }
  if (eap->cmdidx != CMD_SIZE) {
    eap->addr_type = cmdnames[(int)eap->cmdidx].cmd_addr_type;
  } else {
    eap->addr_type = ADDR_LINES;
  }
  // :wincmd range depends on the argument
  if (eap->cmdidx == CMD_wincmd && p != NULL) {
    get_wincmd_addr_type(skipwhite(p), eap);
  }
  // :.cc in quickfix window uses line number
  if ((eap->cmdidx == CMD_cc || eap->cmdidx == CMD_ll) && bt_quickfix(curbuf)) {
    eap->addr_type = ADDR_OTHER;
  }
}

/// Get default range number for command based on its address type
linenr_T get_cmd_default_range(exarg_T *eap)
{
  switch (eap->addr_type) {
  case ADDR_LINES:
  case ADDR_OTHER:
    // Default is the cursor line number.  Avoid using an invalid
    // line number though.
    return MIN(curwin->w_cursor.lnum, curbuf->b_ml.ml_line_count);
    break;
  case ADDR_WINDOWS:
    return CURRENT_WIN_NR;
    break;
  case ADDR_ARGUMENTS:
    return MIN(curwin->w_arg_idx + 1, ARGCOUNT);
    break;
  case ADDR_LOADED_BUFFERS:
  case ADDR_BUFFERS:
    return curbuf->b_fnum;
    break;
  case ADDR_TABS:
    return CURRENT_TAB_NR;
    break;
  case ADDR_TABS_RELATIVE:
  case ADDR_UNSIGNED:
    return 1;
    break;
  case ADDR_QUICKFIX:
    return (linenr_T)qf_get_cur_idx(eap);
    break;
  case ADDR_QUICKFIX_VALID:
    return qf_get_cur_valid_idx(eap);
    break;
  default:
    return 0;
    // Will give an error later if a range is found.
    break;
  }
}

/// Set default command range for -range=% based on the addr type of the command
void set_cmd_dflall_range(exarg_T *eap)
{
  buf_T *buf;

  eap->line1 = 1;
  switch (eap->addr_type) {
  case ADDR_LINES:
  case ADDR_OTHER:
    eap->line2 = curbuf->b_ml.ml_line_count;
    break;
  case ADDR_LOADED_BUFFERS:
    buf = firstbuf;
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
  case ADDR_BUFFERS:
    eap->line1 = firstbuf->b_fnum;
    eap->line2 = lastbuf->b_fnum;
    break;
  case ADDR_WINDOWS:
    eap->line2 = LAST_WIN_NR;
    break;
  case ADDR_TABS:
    eap->line2 = LAST_TAB_NR;
    break;
  case ADDR_TABS_RELATIVE:
    eap->line2 = 1;
    break;
  case ADDR_ARGUMENTS:
    if (ARGCOUNT == 0) {
      eap->line1 = eap->line2 = 0;
    } else {
      eap->line2 = ARGCOUNT;
    }
    break;
  case ADDR_QUICKFIX_VALID:
    eap->line2 = (linenr_T)qf_get_valid_size(eap);
    if (eap->line2 == 0) {
      eap->line2 = 1;
    }
    break;
  case ADDR_NONE:
  case ADDR_UNSIGNED:
  case ADDR_QUICKFIX:
    iemsg(_("INTERNAL: Cannot use EX_DFLALL "
            "with ADDR_NONE, ADDR_UNSIGNED or ADDR_QUICKFIX"));
    break;
  }
}

static void parse_register(exarg_T *eap)
{
  // Accept numbered register only when no count allowed (:put)
  if ((eap->argt & EX_REGSTR)
      && *eap->arg != NUL
      // Do not allow register = for user commands
      && (!IS_USER_CMDIDX(eap->cmdidx) || *eap->arg != '=')
      && !((eap->argt & EX_COUNT) && ascii_isdigit(*eap->arg))) {
    if (valid_yank_reg(*eap->arg, (eap->cmdidx != CMD_put
                                   && !IS_USER_CMDIDX(eap->cmdidx)))) {
      eap->regname = (uint8_t)(*eap->arg++);
      // for '=' register: accept the rest of the line as an expression
      if (eap->arg[-1] == '=' && eap->arg[0] != NUL) {
        if (!eap->skip) {
          set_expr_line(xstrdup(eap->arg));
        }
        eap->arg += strlen(eap->arg);
      }
      eap->arg = skipwhite(eap->arg);
    }
  }
}

// Change line1 and line2 of Ex command to use count
void set_cmd_count(exarg_T *eap, linenr_T count, bool validate)
{
  if (eap->addr_type != ADDR_LINES) {  // e.g. :buffer 2, :sleep 3
    eap->line2 = count;
    if (eap->addr_count == 0) {
      eap->addr_count = 1;
    }
  } else {
    eap->line1 = eap->line2;
    if (eap->line2 >= INT32_MAX - (count - 1)) {
      eap->line2 = INT32_MAX;
    } else {
      eap->line2 += count - 1;
    }
    eap->addr_count++;
    // Be vi compatible: no error message for out of range.
    if (validate && eap->line2 > curbuf->b_ml.ml_line_count) {
      eap->line2 = curbuf->b_ml.ml_line_count;
    }
  }
}

static int parse_count(exarg_T *eap, const char **errormsg, bool validate)
{
  // Check for a count.  When accepting a EX_BUFNAME, don't use "123foo" as a
  // count, it's a buffer name.
  char *p;

  if ((eap->argt & EX_COUNT) && ascii_isdigit(*eap->arg)
      && (!(eap->argt & EX_BUFNAME) || *(p = skipdigits(eap->arg + 1)) == NUL
          || ascii_iswhite(*p))) {
    linenr_T n = getdigits_int32(&eap->arg, false, INT32_MAX);
    eap->arg = skipwhite(eap->arg);

    if (eap->args != NULL) {
      assert(eap->argc > 0 && eap->arg >= eap->args[0]);
      // If eap->arg is still pointing to the first argument, just make eap->args[0] point to the
      // same location. This is needed for usecases like vim.cmd.sleep('10m'). If eap->arg is
      // pointing outside the first argument, shift arguments by 1.
      if (eap->arg < eap->args[0] + eap->arglens[0]) {
        eap->arglens[0] -= (size_t)(eap->arg - eap->args[0]);
        eap->args[0] = eap->arg;
      } else {
        shift_cmd_args(eap);
      }
    }

    if (n <= 0 && (eap->argt & EX_ZEROR) == 0) {
      if (errormsg != NULL) {
        *errormsg = _(e_zerocount);
      }
      return FAIL;
    }
    set_cmd_count(eap, n, validate);
  }

  return OK;
}

/// Check if command is not implemented
bool is_cmd_ni(cmdidx_T cmdidx)
{
  return !IS_USER_CMDIDX(cmdidx) && (cmdnames[cmdidx].cmd_func == ex_ni
                                     || cmdnames[cmdidx].cmd_func == ex_script_ni);
}

/// Parse command line and return information about the first command.
/// If parsing is done successfully, need to free cmod_filter_pat and cmod_filter_regmatch.regprog
/// after calling, usually done using undo_cmdmod() or execute_cmd().
///
/// @param cmdline Command line string
/// @param[out] eap Ex command arguments
/// @param[out] cmdinfo Command parse information
/// @param[out] errormsg Error message, if any
///
/// @return Success or failure
bool parse_cmdline(char *cmdline, exarg_T *eap, CmdParseInfo *cmdinfo, const char **errormsg)
{
  char *after_modifier = NULL;
  bool retval = false;
  // parsing the command modifiers may set ex_pressedreturn
  const bool save_ex_pressedreturn = ex_pressedreturn;
  // parsing the command range may require moving the cursor
  const pos_T save_cursor = curwin->w_cursor;
  // parsing the command range may set the last search pattern
  save_last_search_pattern();

  // Initialize cmdinfo
  CLEAR_POINTER(cmdinfo);

  // Initialize eap
  *eap = (exarg_T){
    .line1 = 1,
    .line2 = 1,
    .cmd = cmdline,
    .cmdlinep = &cmdline,
    .ea_getline = NULL,
    .cookie = NULL,
  };

  // Parse command modifiers
  if (parse_command_modifiers(eap, errormsg, &cmdinfo->cmdmod, false) == FAIL) {
    goto end;
  }
  after_modifier = eap->cmd;

  // Save location after command modifiers
  char *cmd = eap->cmd;
  // Skip ranges to find command name since we need the command to know what kind of range it uses
  eap->cmd = skip_range(eap->cmd, NULL);
  if (*eap->cmd == '*') {
    eap->cmd = skipwhite(eap->cmd + 1);
  }
  char *p = find_ex_command(eap, NULL);
  if (p == NULL) {
    *errormsg = _(e_ambiguous_use_of_user_defined_command);
    goto end;
  }

  // Set command address type and parse command range
  set_cmd_addr_type(eap, p);
  eap->cmd = cmd;
  if (parse_cmd_address(eap, errormsg, true) == FAIL) {
    goto end;
  }

  // Skip colon and whitespace
  eap->cmd = skip_colon_white(eap->cmd, true);
  // Fail if command is a comment or if command doesn't exist
  if (*eap->cmd == NUL || *eap->cmd == '"') {
    goto end;
  }
  // Fail if command is invalid
  if (eap->cmdidx == CMD_SIZE) {
    xstrlcpy(IObuff, _(e_not_an_editor_command), IOSIZE);
    // If the modifier was parsed OK the error must be in the following command
    char *cmdname = after_modifier ? after_modifier : cmdline;
    append_command(cmdname);
    *errormsg = IObuff;
    goto end;
  }

  // Correctly set 'forceit' for commands
  if (*p == '!' && eap->cmdidx != CMD_substitute
      && eap->cmdidx != CMD_smagic && eap->cmdidx != CMD_snomagic) {
    p++;
    eap->forceit = true;
  } else {
    eap->forceit = false;
  }

  // Parse arguments.
  if (!IS_USER_CMDIDX(eap->cmdidx)) {
    eap->argt = cmdnames[(int)eap->cmdidx].cmd_argt;
  }
  // Skip to start of argument.
  // Don't do this for the ":!" command, because ":!! -l" needs the space.
  if (eap->cmdidx == CMD_bang) {
    eap->arg = p;
  } else {
    eap->arg = skipwhite(p);
  }

  // Don't treat ":r! filter" like a bang
  if (eap->cmdidx == CMD_read) {
    if (eap->forceit) {
      eap->forceit = false;                     // :r! filter
    }
  }

  // Check for '|' to separate commands and '"' to start comments.
  // Don't do this for ":read !cmd" and ":write !cmd".
  if ((eap->argt & EX_TRLBAR)) {
    separate_nextcmd(eap);
  }
  // Fail if command doesn't support bang but is used with a bang
  if (!(eap->argt & EX_BANG) && eap->forceit) {
    *errormsg = _(e_nobang);
    goto end;
  }
  // Fail if command doesn't support a range but it is given a range
  if (!(eap->argt & EX_RANGE) && eap->addr_count > 0) {
    *errormsg = _(e_norange);
    goto end;
  }
  // Set default range for command if required
  if ((eap->argt & EX_DFLALL) && eap->addr_count == 0) {
    set_cmd_dflall_range(eap);
  }

  // Parse register and count
  parse_register(eap);
  if (parse_count(eap, errormsg, false) == FAIL) {
    goto end;
  }

  // Remove leading whitespace and colon from next command
  if (eap->nextcmd) {
    eap->nextcmd = skip_colon_white(eap->nextcmd, true);
  }

  // Set the "magic" values (characters that get treated specially)
  if (eap->argt & EX_XFILE) {
    cmdinfo->magic.file = true;
  }
  if (eap->argt & EX_TRLBAR) {
    cmdinfo->magic.bar = true;
  }

  retval = true;
end:
  if (!retval) {
    undo_cmdmod(&cmdinfo->cmdmod);
  }
  ex_pressedreturn = save_ex_pressedreturn;
  curwin->w_cursor = save_cursor;
  restore_last_search_pattern();
  return retval;
}

// Shift Ex-command arguments to the right.
static void shift_cmd_args(exarg_T *eap)
{
  assert(eap->args != NULL && eap->argc > 0);

  char **oldargs = eap->args;
  size_t *oldarglens = eap->arglens;

  eap->argc--;
  eap->args = eap->argc > 0 ? xcalloc(eap->argc, sizeof(char *)) : NULL;
  eap->arglens = eap->argc > 0 ? xcalloc(eap->argc, sizeof(size_t)) : NULL;

  for (size_t i = 0; i < eap->argc; i++) {
    eap->args[i] = oldargs[i + 1];
    eap->arglens[i] = oldarglens[i + 1];
  }

  // If there are no arguments, make eap->arg point to the end of string.
  eap->arg = (eap->argc > 0 ? eap->args[0] : (oldargs[0] + oldarglens[0]));

  xfree(oldargs);
  xfree(oldarglens);
}

static int execute_cmd0(int *retv, exarg_T *eap, const char **errormsg, bool preview)
{
  // If filename expansion is enabled, expand filenames
  if (eap->argt & EX_XFILE) {
    if (expand_filename(eap, eap->cmdlinep, errormsg) == FAIL) {
      return FAIL;
    }
  }

  // Accept buffer name.  Cannot be used at the same time with a buffer
  // number.  Don't do this for a user command.
  if ((eap->argt & EX_BUFNAME) && *eap->arg != NUL && eap->addr_count == 0
      && !IS_USER_CMDIDX(eap->cmdidx)) {
    if (eap->args == NULL) {
      // If argument positions are not specified, search the argument for the buffer name.
      // :bdelete, :bwipeout and :bunload take several arguments, separated by spaces:
      // find next space (skipping over escaped characters).
      // The others take one argument: ignore trailing spaces.
      char *p;

      if (eap->cmdidx == CMD_bdelete || eap->cmdidx == CMD_bwipeout
          || eap->cmdidx == CMD_bunload) {
        p = skiptowhite_esc(eap->arg);
      } else {
        p = eap->arg + strlen(eap->arg);
        while (p > eap->arg && ascii_iswhite(p[-1])) {
          p--;
        }
      }
      eap->line2 = buflist_findpat(eap->arg, p, (eap->argt & EX_BUFUNL) != 0,
                                   false, false);
      eap->addr_count = 1;
      eap->arg = skipwhite(p);
    } else {
      // If argument positions are specified, just use the first argument
      eap->line2 = buflist_findpat(eap->args[0],
                                   eap->args[0] + eap->arglens[0],
                                   (eap->argt & EX_BUFUNL) != 0, false, false);
      eap->addr_count = 1;
      shift_cmd_args(eap);
    }
    if (eap->line2 < 0) {  // failed
      return FAIL;
    }
  }

  // The :try command saves the emsg_silent flag, reset it here when
  // ":silent! try" was used, it should only apply to :try itself.
  if (eap->cmdidx == CMD_try && cmdmod.cmod_did_esilent > 0) {
    emsg_silent -= cmdmod.cmod_did_esilent;
    emsg_silent = MAX(emsg_silent, 0);
    cmdmod.cmod_did_esilent = 0;
  }

  // Execute the command
  if (IS_USER_CMDIDX(eap->cmdidx)) {
    // Execute a user-defined command.
    *retv = do_ucmd(eap, preview);
  } else {
    // Call the function to execute the builtin command or the preview callback.
    eap->errmsg = NULL;
    if (preview) {
      *retv = (cmdnames[eap->cmdidx].cmd_preview_func)(eap, cmdpreview_get_ns(),
                                                       cmdpreview_get_bufnr());
    } else {
      (cmdnames[eap->cmdidx].cmd_func)(eap);
    }
    if (eap->errmsg != NULL) {
      *errormsg = eap->errmsg;
    }
  }

  return OK;
}

/// Execute an Ex command using parsed command line information.
/// Does not do any validation of the Ex command arguments.
///
/// @param eap Ex-command arguments
/// @param cmdinfo Command parse information
/// @param preview Execute command preview callback instead of actual command
int execute_cmd(exarg_T *eap, CmdParseInfo *cmdinfo, bool preview)
{
  int retv = 0;
  if (do_cmdline_start() == FAIL) {
    emsg(_(e_command_too_recursive));
    return retv;
  }

  const char *errormsg = NULL;

  cmdmod_T save_cmdmod = cmdmod;
  cmdmod = cmdinfo->cmdmod;

  // Apply command modifiers
  apply_cmdmod(&cmdmod);

  if (!MODIFIABLE(curbuf) && (eap->argt & EX_MODIFY)
      // allow :put in terminals
      && !(curbuf->terminal && eap->cmdidx == CMD_put)) {
    errormsg = _(e_modifiable);
    goto end;
  }
  if (!IS_USER_CMDIDX(eap->cmdidx)) {
    if (cmdwin_type != 0 && !(eap->argt & EX_CMDWIN)) {
      // Command not allowed in the command line window
      errormsg = _(e_cmdwin);
      goto end;
    }
    if (text_locked() && !(eap->argt & EX_LOCK_OK)) {
      // Command not allowed when text is locked
      errormsg = _(get_text_locked_msg());
      goto end;
    }
  }
  // Disallow editing another buffer when "curbuf->b_ro_locked" is set.
  // Do allow ":checktime" (it is postponed).
  // Do allow ":edit" (check for an argument later).
  // Do allow ":file" with no arguments
  if (!(eap->argt & EX_CMDWIN)
      && eap->cmdidx != CMD_checktime
      && eap->cmdidx != CMD_edit
      && !(eap->cmdidx == CMD_file && *eap->arg == NUL)
      && !IS_USER_CMDIDX(eap->cmdidx)
      && curbuf_locked()) {
    goto end;
  }

  correct_range(eap);

  if (((eap->argt & EX_WHOLEFOLD) || eap->addr_count >= 2) && !global_busy
      && eap->addr_type == ADDR_LINES) {
    // Put the first line at the start of a closed fold, put the last line
    // at the end of a closed fold.
    hasFolding(curwin, eap->line1, &eap->line1, NULL);
    hasFolding(curwin, eap->line2, NULL, &eap->line2);
  }

  // Use first argument as count when possible
  if (parse_count(eap, &errormsg, true) == FAIL) {
    goto end;
  }

  cstack_T cstack = { .cs_idx = -1 };
  eap->cstack = &cstack;

  // Execute the command
  execute_cmd0(&retv, eap, &errormsg, preview);

end:
  if (errormsg != NULL && *errormsg != NUL) {
    emsg(errormsg);
  }

  // Undo command modifiers
  undo_cmdmod(&cmdmod);
  cmdmod = save_cmdmod;

  do_cmdline_end();
  return retv;
}

static void profile_cmd(const exarg_T *eap, cstack_T *cstack, LineGetter fgetline, void *cookie)
{
  // Count this line for profiling if skip is true.
  if (do_profiling == PROF_YES
      && (!eap->skip || cstack->cs_idx == 0
          || (cstack->cs_idx > 0
              && (cstack->cs_flags[cstack->cs_idx - 1] & CSF_ACTIVE)))) {
    bool skip = did_emsg || got_int || did_throw;

    if (eap->cmdidx == CMD_catch) {
      skip = !skip && !(cstack->cs_idx >= 0
                        && (cstack->cs_flags[cstack->cs_idx] & CSF_THROWN)
                        && !(cstack->cs_flags[cstack->cs_idx] & CSF_CAUGHT));
    } else if (eap->cmdidx == CMD_else || eap->cmdidx == CMD_elseif) {
      skip = skip || !(cstack->cs_idx >= 0
                       && !(cstack->cs_flags[cstack->cs_idx]
                            & (CSF_ACTIVE | CSF_TRUE)));
    } else if (eap->cmdidx == CMD_finally) {
      skip = false;
    } else if (eap->cmdidx != CMD_endif
               && eap->cmdidx != CMD_endfor
               && eap->cmdidx != CMD_endtry
               && eap->cmdidx != CMD_endwhile) {
      skip = eap->skip;
    }

    if (!skip) {
      if (getline_equal(fgetline, cookie, get_func_line)) {
        func_line_exec(getline_cookie(fgetline, cookie));
      } else if (getline_equal(fgetline, cookie, getsourceline)) {
        script_line_exec();
      }
    }
  }
}

static bool skip_cmd(const exarg_T *eap)
{
  // Skip the command when it's not going to be executed.
  // The commands like :if, :endif, etc. always need to be executed.
  // Also make an exception for commands that handle a trailing command
  // themselves.
  if (eap->skip) {
    switch (eap->cmdidx) {
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
    case CMD_horizontal:
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
    case CMD_trust:
    case CMD_unlet:
    case CMD_unlockvar:
    case CMD_verbose:
    case CMD_vertical:
    case CMD_wincmd:
      break;

    default:
      return true;
    }
  }
  return false;
}

/// Execute one Ex command.
///
/// If "flags" has DOCMD_VERBOSE, the command will be included in the error
/// message.
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
static char *do_one_cmd(char **cmdlinep, int flags, cstack_T *cstack, LineGetter fgetline,
                        void *cookie)
{
  const char *errormsg = NULL;  // error message
  const int save_reg_executing = reg_executing;
  const bool save_pending_end_reg_executing = pending_end_reg_executing;

  exarg_T ea = {
    .line1 = 1,
    .line2 = 1,
  };
  ex_nesting_level++;

  // When the last file has not been edited :q has to be typed twice.
  if (quitmore
      // avoid that a function call in 'statusline' does this
      && !getline_equal(fgetline, cookie, get_func_line)
      // avoid that an autocommand, e.g. QuitPre, does this
      && !getline_equal(fgetline, cookie, getnextac)) {
    quitmore--;
  }

  // Reset browse, confirm, etc..  They are restored when returning, for
  // recursive calls.
  cmdmod_T save_cmdmod = cmdmod;

  // "#!anything" is handled like a comment.
  if ((*cmdlinep)[0] == '#' && (*cmdlinep)[1] == '!') {
    goto doend;
  }

  // 1. Skip comment lines and leading white space and colons.
  // 2. Handle command modifiers.

  // The "ea" structure holds the arguments that can be used.
  ea.cmd = *cmdlinep;
  ea.cmdlinep = cmdlinep;
  ea.ea_getline = fgetline;
  ea.cookie = cookie;
  ea.cstack = cstack;

  if (parse_command_modifiers(&ea, &errormsg, &cmdmod, false) == FAIL) {
    goto doend;
  }
  apply_cmdmod(&cmdmod);

  char *after_modifier = ea.cmd;

  ea.skip = (did_emsg
             || got_int
             || did_throw
             || (cstack->cs_idx >= 0
                 && !(cstack->cs_flags[cstack->cs_idx] & CSF_ACTIVE)));

  // 3. Skip over the range to find the command. Let "p" point to after it.
  //
  // We need the command to know what kind of range it uses.
  char *cmd = ea.cmd;
  ea.cmd = skip_range(ea.cmd, NULL);
  if (*ea.cmd == '*') {
    ea.cmd = skipwhite(ea.cmd + 1);
  }
  char *p = find_ex_command(&ea, NULL);

  profile_cmd(&ea, cstack, fgetline, cookie);

  if (!exiting) {
    // May go to debug mode.  If this happens and the ">quit" debug command is
    // used, throw an interrupt exception and skip the next command.
    dbg_check_breakpoint(&ea);
  }
  if (!ea.skip && got_int) {
    ea.skip = true;
    do_intthrow(cstack);
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
  set_cmd_addr_type(&ea, p);

  ea.cmd = cmd;
  if (parse_cmd_address(&ea, &errormsg, false) == FAIL) {
    goto doend;
  }

  // 5. Parse the command.

  // Skip ':' and any white space
  ea.cmd = skip_colon_white(ea.cmd, true);

  // If we got a line, but no command, then go to the line.
  // If we find a '|' or '\n' we set ea.nextcmd.
  if (*ea.cmd == NUL || *ea.cmd == '"'
      || (ea.nextcmd = check_nextcmd(ea.cmd)) != NULL) {
    // strange vi behaviour:
    // ":3"     jumps to line 3
    // ":3|..." prints line 3
    // ":|"     prints current line
    if (ea.skip) {  // skip this if inside :if
      goto doend;
    }
    assert(errormsg == NULL);
    errormsg = ex_range_without_command(&ea);
    goto doend;
  }

  // If this looks like an undefined user command and there are CmdUndefined
  // autocommands defined, trigger the matching autocommands.
  if (p != NULL && ea.cmdidx == CMD_SIZE && !ea.skip
      && ASCII_ISUPPER(*ea.cmd)
      && has_event(EVENT_CMDUNDEFINED)) {
    p = ea.cmd;
    while (ASCII_ISALNUM(*p)) {
      p++;
    }
    p = xmemdupz(ea.cmd, (size_t)(p - ea.cmd));
    int ret = apply_autocmds(EVENT_CMDUNDEFINED, p, p, true, NULL);
    xfree(p);
    // If the autocommands did something and didn't cause an error, try
    // finding the command again.
    p = (ret && !aborting()) ? find_ex_command(&ea, NULL) : ea.cmd;
  }

  if (p == NULL) {
    if (!ea.skip) {
      errormsg = _(e_ambiguous_use_of_user_defined_command);
    }
    goto doend;
  }

  // Check for wrong commands.
  if (ea.cmdidx == CMD_SIZE) {
    if (!ea.skip) {
      xstrlcpy(IObuff, _(e_not_an_editor_command), IOSIZE);
      // If the modifier was parsed OK the error must be in the following
      // command
      char *cmdname = after_modifier ? after_modifier : *cmdlinep;
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
  const int ni = is_cmd_ni(ea.cmdidx);

  // Forced commands.
  ea.forceit = *p == '!'
               && ea.cmdidx != CMD_substitute
               && ea.cmdidx != CMD_smagic
               && ea.cmdidx != CMD_snomagic;
  if (ea.forceit) {
    p++;
  }

  // 6. Parse arguments.  Then check for errors.
  if (!IS_USER_CMDIDX(ea.cmdidx)) {
    ea.argt = cmdnames[(int)ea.cmdidx].cmd_argt;
  }

  if (!ea.skip) {
    if (sandbox != 0 && !(ea.argt & EX_SBOXOK)) {
      // Command not allowed in sandbox.
      errormsg = _(e_sandbox);
      goto doend;
    }
    if (!MODIFIABLE(curbuf) && (ea.argt & EX_MODIFY)
        // allow :put in terminals
        && (!curbuf->terminal || ea.cmdidx != CMD_put)) {
      // Command not allowed in non-'modifiable' buffer
      errormsg = _(e_modifiable);
      goto doend;
    }

    if (!IS_USER_CMDIDX(ea.cmdidx)) {
      if (cmdwin_type != 0 && !(ea.argt & EX_CMDWIN)) {
        // Command not allowed in the command line window
        errormsg = _(e_cmdwin);
        goto doend;
      }
      if (text_locked() && !(ea.argt & EX_LOCK_OK)) {
        // Command not allowed when text is locked
        errormsg = _(get_text_locked_msg());
        goto doend;
      }
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
      errormsg = _(e_norange);
      goto doend;
    }
  }

  if (!ni && !(ea.argt & EX_BANG) && ea.forceit) {  // no <!> allowed
    errormsg = _(e_nobang);
    goto doend;
  }

  // Don't complain about the range if it is not used
  // (could happen if line_count is accidentally set to 0).
  if (!ea.skip && !ni && (ea.argt & EX_RANGE)) {
    // If the range is backwards, ask for confirmation and, if given, swap
    // ea.line1 & ea.line2 so it's forwards again.
    // When global command is busy, don't ask, will fail below.
    if (!global_busy && ea.line1 > ea.line2) {
      if (msg_silent == 0) {
        if ((flags & DOCMD_VERBOSE) || exmode_active) {
          errormsg = _("E493: Backwards range given");
          goto doend;
        }
        if (ask_yesno(_("Backwards range given, OK to swap")) != 'y') {
          goto doend;
        }
      }
      linenr_T lnum = ea.line1;
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
    hasFolding(curwin, ea.line1, &ea.line1, NULL);
    hasFolding(curwin, ea.line2, NULL, &ea.line2);
  }

  // For the ":make" and ":grep" commands we insert the 'makeprg'/'grepprg'
  // option here, so things like % get expanded.
  p = replace_makeprg(&ea, p, cmdlinep);
  if (p == NULL) {
    goto doend;
  }

  // Skip to start of argument.
  // Don't do this for the ":!" command, because ":!! -l" needs the space.
  ea.arg = ea.cmdidx == CMD_bang ? p : skipwhite(p);

  // ":file" cannot be run with an argument when "curbuf->b_ro_locked" is set
  if (ea.cmdidx == CMD_file && *ea.arg != NUL && curbuf_locked()) {
    goto doend;
  }

  // Check for "++opt=val" argument.
  // Must be first, allow ":w ++enc=utf8 !cmd"
  if (ea.argt & EX_ARGOPT) {
    while (ea.arg[0] == '+' && ea.arg[1] == '+') {
      if (getargopt(&ea) == FAIL && !ni) {
        errormsg = _(e_invarg);
        goto doend;
      }
    }
  }

  if (ea.cmdidx == CMD_write || ea.cmdidx == CMD_update) {
    if (*ea.arg == '>') {                       // append
      if (*++ea.arg != '>') {                   // typed wrong
        errormsg = _("E494: Use w or w>>");
        goto doend;
      }
      ea.arg = skipwhite(ea.arg + 1);
      ea.append = true;
    } else if (*ea.arg == '!' && ea.cmdidx == CMD_write) {  // :w !filter
      ea.arg++;
      ea.usefilter = true;
    }
  } else if (ea.cmdidx == CMD_read) {
    if (ea.forceit) {
      ea.usefilter = true;                      // :r! filter if ea.forceit
      ea.forceit = false;
    } else if (*ea.arg == '!') {              // :r !filter
      ea.arg++;
      ea.usefilter = true;
    }
  } else if (ea.cmdidx == CMD_lshift || ea.cmdidx == CMD_rshift) {
    ea.amount = 1;
    while (*ea.arg == *ea.cmd) {                // count number of '>' or '<'
      ea.arg++;
      ea.amount++;
    }
    ea.arg = skipwhite(ea.arg);
  }

  // Check for "+command" argument, before checking for next command.
  // Don't do this for ":read !cmd" and ":write !cmd".
  if ((ea.argt & EX_CMDARG) && !ea.usefilter) {
    ea.do_ecmd_cmd = getargcmd(&ea.arg);
  }

  // Check for '|' to separate commands and '"' to start comments.
  // Don't do this for ":read !cmd" and ":write !cmd".
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
    for (char *s = ea.arg; *s; s++) {
      // Remove one backslash before a newline, so that it's possible to
      // pass a newline to the shell and also a newline that is preceded
      // with a backslash.  This makes it impossible to end a shell
      // command in a backslash, but that doesn't appear useful.
      // Halving the number of backslashes is incompatible with previous
      // versions.
      if (*s == '\\' && s[1] == '\n') {
        STRMOVE(s, s + 1);
      } else if (*s == '\n') {
        ea.nextcmd = s + 1;
        *s = NUL;
        break;
      }
    }
  }

  if ((ea.argt & EX_DFLALL) && ea.addr_count == 0) {
    set_cmd_dflall_range(&ea);
  }

  // Parse register and count
  parse_register(&ea);
  if (parse_count(&ea, &errormsg, true) == FAIL) {
    goto doend;
  }

  // Check for flags: 'l', 'p' and '#'.
  if (ea.argt & EX_FLAGS) {
    get_flags(&ea);
  }
  if (!ni && !(ea.argt & EX_EXTRA) && *ea.arg != NUL
      && *ea.arg != '"' && (*ea.arg != '|' || (ea.argt & EX_TRLBAR) == 0)) {
    // no arguments allowed but there is something
    errormsg = ex_errmsg(e_trailing_arg, ea.arg);
    goto doend;
  }

  if (!ni && (ea.argt & EX_NEEDARG) && *ea.arg == NUL) {
    errormsg = _(e_argreq);
    goto doend;
  }

  if (skip_cmd(&ea)) {
    goto doend;
  }

  // 7. Execute the command.
  int retv = 0;
  if (execute_cmd0(&retv, &ea, &errormsg, false) == FAIL) {
    goto doend;
  }

  // If the command just executed called do_cmdline(), any throw or ":return"
  // or ":finish" encountered there must also check the cstack of the still
  // active do_cmdline() that called this do_one_cmd().  Rethrow an uncaught
  // exception, or reanimate a returned function or finished script file and
  // return or finish it again.
  if (need_rethrow) {
    do_throw(cstack);
  } else if (check_cstack) {
    if (source_finished(fgetline, cookie)) {
      do_finish(&ea, true);
    } else if (getline_equal(fgetline, cookie, get_func_line)
               && current_func_returned()) {
      do_return(&ea, true, false, NULL);
    }
  }
  need_rethrow = check_cstack = false;

doend:
  // can happen with zero line number
  if (curwin->w_cursor.lnum == 0) {
    curwin->w_cursor.lnum = 1;
    curwin->w_cursor.col = 0;
  }

  if (errormsg != NULL && *errormsg != NUL && !did_emsg) {
    if (flags & DOCMD_VERBOSE) {
      if (errormsg != IObuff) {
        xstrlcpy(IObuff, errormsg, IOSIZE);
        errormsg = IObuff;
      }
      append_command(*ea.cmdlinep);
    }
    emsg(errormsg);
  }
  do_errthrow(cstack,
              (ea.cmdidx != CMD_SIZE
               && !IS_USER_CMDIDX(ea.cmdidx)) ? cmdnames[(int)ea.cmdidx].cmd_name : NULL);

  undo_cmdmod(&cmdmod);
  cmdmod = save_cmdmod;
  reg_executing = save_reg_executing;
  pending_end_reg_executing = save_pending_end_reg_executing;

  if (ea.nextcmd && *ea.nextcmd == NUL) {       // not really a next command
    ea.nextcmd = NULL;
  }

  ex_nesting_level--;
  xfree(ea.cmdline_tofree);

  return ea.nextcmd;
}

static char ex_error_buf[MSG_BUF_LEN];

/// @return an error message with argument included.
/// Uses a static buffer, only the last error will be kept.
/// "msg" will be translated, caller should use N_().
char *ex_errmsg(const char *const msg, const char *const arg)
  FUNC_ATTR_NONNULL_ALL
{
  vim_snprintf(ex_error_buf, MSG_BUF_LEN, _(msg), arg);
  return ex_error_buf;
}

/// The "+" string used in place of an empty command in Ex mode.
/// This string is used in pointer comparison.
static char exmode_plus[] = "+";

/// Handle a range without a command.
/// Returns an error message on failure.
static char *ex_range_without_command(exarg_T *eap)
{
  char *errormsg = NULL;

  if (*eap->cmd == '|' || (exmode_active && eap->cmd != exmode_plus + 1)) {
    eap->cmdidx = CMD_print;
    eap->argt = EX_RANGE | EX_COUNT | EX_TRLBAR;
    if ((errormsg = invalid_range(eap)) == NULL) {
      correct_range(eap);
      ex_print(eap);
    }
  } else if (eap->addr_count != 0) {
    eap->line2 = MIN(eap->line2, curbuf->b_ml.ml_line_count);

    if (eap->line2 < 0) {
      errormsg = _(e_invrange);
    } else {
      if (eap->line2 == 0) {
        curwin->w_cursor.lnum = 1;
      } else {
        curwin->w_cursor.lnum = eap->line2;
      }
      beginline(BL_SOL | BL_FIX);
    }
  }
  return errormsg;
}

/// Parse and skip over command modifiers:
/// - update eap->cmd
/// - store flags in "cmod".
/// - Set ex_pressedreturn for an empty command line.
///
/// @param skip_only      if false, undo_cmdmod() must be called later to free
///                       any cmod_filter_pat and cmod_filter_regmatch.regprog,
///                       and ex_pressedreturn may be set.
/// @param[out] errormsg  potential error message.
///
/// Call apply_cmdmod() to get the side effects of the modifiers:
/// - Increment "sandbox" for ":sandbox"
/// - set p_verbose for ":verbose"
/// - set msg_silent for ":silent"
/// - set 'eventignore' to "all" for ":noautocmd"
///
/// @return  FAIL when the command is not to be executed.
int parse_command_modifiers(exarg_T *eap, const char **errormsg, cmdmod_T *cmod, bool skip_only)
{
  CLEAR_POINTER(cmod);

  // Repeat until no more command modifiers are found.
  while (true) {
    while (*eap->cmd == ' '
           || *eap->cmd == '\t'
           || *eap->cmd == ':') {
      eap->cmd++;
    }

    // in ex mode, an empty line works like :+
    if (*eap->cmd == NUL && exmode_active
        && getline_equal(eap->ea_getline, eap->cookie, getexline)
        && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
      eap->cmd = exmode_plus;
      if (!skip_only) {
        ex_pressedreturn = true;
      }
    }

    // ignore comment and empty lines
    if (*eap->cmd == '"') {
      // a comment ends at a NL
      eap->nextcmd = vim_strchr(eap->cmd, '\n');
      if (eap->nextcmd != NULL) {
        eap->nextcmd++;
      }
      return FAIL;
    }
    if (*eap->cmd == '\n') {
      eap->nextcmd = eap->cmd + 1;
      return FAIL;
    }
    if (*eap->cmd == NUL) {
      if (!skip_only) {
        ex_pressedreturn = true;
      }
      return FAIL;
    }

    char *p = skip_range(eap->cmd, NULL);
    switch (*p) {
    // When adding an entry, also modify cmdmods[]
    case 'a':
      if (!checkforcmd(&eap->cmd, "aboveleft", 3)) {
        break;
      }
      cmod->cmod_split |= WSP_ABOVE;
      continue;

    case 'b':
      if (checkforcmd(&eap->cmd, "belowright", 3)) {
        cmod->cmod_split |= WSP_BELOW;
        continue;
      }
      if (checkforcmd(&eap->cmd, "browse", 3)) {
        cmod->cmod_flags |= CMOD_BROWSE;
        continue;
      }
      if (!checkforcmd(&eap->cmd, "botright", 2)) {
        break;
      }
      cmod->cmod_split |= WSP_BOT;
      continue;

    case 'c':
      if (!checkforcmd(&eap->cmd, "confirm", 4)) {
        break;
      }
      cmod->cmod_flags |= CMOD_CONFIRM;
      continue;

    case 'k':
      if (checkforcmd(&eap->cmd, "keepmarks", 3)) {
        cmod->cmod_flags |= CMOD_KEEPMARKS;
        continue;
      }
      if (checkforcmd(&eap->cmd, "keepalt", 5)) {
        cmod->cmod_flags |= CMOD_KEEPALT;
        continue;
      }
      if (checkforcmd(&eap->cmd, "keeppatterns", 5)) {
        cmod->cmod_flags |= CMOD_KEEPPATTERNS;
        continue;
      }
      if (!checkforcmd(&eap->cmd, "keepjumps", 5)) {
        break;
      }
      cmod->cmod_flags |= CMOD_KEEPJUMPS;
      continue;

    case 'f': {  // only accept ":filter {pat} cmd"
      char *reg_pat;

      if (!checkforcmd(&p, "filter", 4) || *p == NUL || ends_excmd(*p)) {
        break;
      }
      if (*p == '!') {
        cmod->cmod_filter_force = true;
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
        cmod->cmod_filter_pat = xstrdup(reg_pat);
        cmod->cmod_filter_regmatch.regprog = vim_regcomp(reg_pat, RE_MAGIC);
        if (cmod->cmod_filter_regmatch.regprog == NULL) {
          break;
        }
      }
      eap->cmd = p;
      continue;
    }

    case 'h':
      if (checkforcmd(&eap->cmd, "horizontal", 3)) {
        cmod->cmod_split |= WSP_HOR;
        continue;
      }
      // ":hide" and ":hide | cmd" are not modifiers
      if (p != eap->cmd || !checkforcmd(&p, "hide", 3)
          || *p == NUL || ends_excmd(*p)) {
        break;
      }
      eap->cmd = p;
      cmod->cmod_flags |= CMOD_HIDE;
      continue;

    case 'l':
      if (checkforcmd(&eap->cmd, "lockmarks", 3)) {
        cmod->cmod_flags |= CMOD_LOCKMARKS;
        continue;
      }

      if (!checkforcmd(&eap->cmd, "leftabove", 5)) {
        break;
      }
      cmod->cmod_split |= WSP_ABOVE;
      continue;

    case 'n':
      if (checkforcmd(&eap->cmd, "noautocmd", 3)) {
        cmod->cmod_flags |= CMOD_NOAUTOCMD;
        continue;
      }
      if (!checkforcmd(&eap->cmd, "noswapfile", 3)) {
        break;
      }
      cmod->cmod_flags |= CMOD_NOSWAPFILE;
      continue;

    case 'r':
      if (!checkforcmd(&eap->cmd, "rightbelow", 6)) {
        break;
      }
      cmod->cmod_split |= WSP_BELOW;
      continue;

    case 's':
      if (checkforcmd(&eap->cmd, "sandbox", 3)) {
        cmod->cmod_flags |= CMOD_SANDBOX;
        continue;
      }
      if (!checkforcmd(&eap->cmd, "silent", 3)) {
        break;
      }
      cmod->cmod_flags |= CMOD_SILENT;
      if (*eap->cmd == '!' && !ascii_iswhite(eap->cmd[-1])) {
        // ":silent!", but not "silent !cmd"
        eap->cmd = skipwhite(eap->cmd + 1);
        cmod->cmod_flags |= CMOD_ERRSILENT;
      }
      continue;

    case 't':
      if (checkforcmd(&p, "tab", 3)) {
        if (!skip_only) {
          int tabnr = (int)get_address(eap, &eap->cmd, ADDR_TABS, eap->skip, skip_only,
                                       false, 1, errormsg);
          if (eap->cmd == NULL) {
            return false;
          }

          if (tabnr == MAXLNUM) {
            cmod->cmod_tab = tabpage_index(curtab) + 1;
          } else {
            if (tabnr < 0 || tabnr > LAST_TAB_NR) {
              *errormsg = _(e_invrange);
              return false;
            }
            cmod->cmod_tab = tabnr + 1;
          }
        }
        eap->cmd = p;
        continue;
      }
      if (!checkforcmd(&eap->cmd, "topleft", 2)) {
        break;
      }
      cmod->cmod_split |= WSP_TOP;
      continue;

    case 'u':
      if (!checkforcmd(&eap->cmd, "unsilent", 3)) {
        break;
      }
      cmod->cmod_flags |= CMOD_UNSILENT;
      continue;

    case 'v':
      if (checkforcmd(&eap->cmd, "vertical", 4)) {
        cmod->cmod_split |= WSP_VERT;
        continue;
      }
      if (!checkforcmd(&p, "verbose", 4)) {
        break;
      }
      if (ascii_isdigit(*eap->cmd)) {
        // zero means not set, one is verbose == 0, etc.
        cmod->cmod_verbose = atoi(eap->cmd) + 1;
      } else {
        cmod->cmod_verbose = 2;  // default: verbose == 1
      }
      eap->cmd = p;
      continue;
    }
    break;
  }

  return OK;
}

/// Apply the command modifiers.  Saves current state in "cmdmod", call
/// undo_cmdmod() later.
void apply_cmdmod(cmdmod_T *cmod)
{
  if ((cmod->cmod_flags & CMOD_SANDBOX) && !cmod->cmod_did_sandbox) {
    sandbox++;
    cmod->cmod_did_sandbox = true;
  }
  if (cmod->cmod_verbose > 0) {
    if (cmod->cmod_verbose_save == 0) {
      cmod->cmod_verbose_save = p_verbose + 1;
    }
    p_verbose = cmod->cmod_verbose - 1;
  }

  if ((cmod->cmod_flags & (CMOD_SILENT | CMOD_UNSILENT))
      && cmod->cmod_save_msg_silent == 0) {
    cmod->cmod_save_msg_silent = msg_silent + 1;
    cmod->cmod_save_msg_scroll = msg_scroll;
  }
  if (cmod->cmod_flags & CMOD_SILENT) {
    msg_silent++;
  }
  if (cmod->cmod_flags & CMOD_UNSILENT) {
    msg_silent = 0;
  }

  if (cmod->cmod_flags & CMOD_ERRSILENT) {
    emsg_silent++;
    cmod->cmod_did_esilent++;
  }

  if ((cmod->cmod_flags & CMOD_NOAUTOCMD) && cmod->cmod_save_ei == NULL) {
    // Set 'eventignore' to "all".
    // First save the existing option value for restoring it later.
    cmod->cmod_save_ei = xstrdup(p_ei);
    set_option_direct(kOptEventignore, STATIC_CSTR_AS_OPTVAL("all"), 0, SID_NONE);
  }
}

/// Undo and free contents of "cmod".
void undo_cmdmod(cmdmod_T *cmod)
  FUNC_ATTR_NONNULL_ALL
{
  if (cmod->cmod_verbose_save > 0) {
    p_verbose = cmod->cmod_verbose_save - 1;
    cmod->cmod_verbose_save = 0;
  }

  if (cmod->cmod_did_sandbox) {
    sandbox--;
    cmod->cmod_did_sandbox = false;
  }

  if (cmod->cmod_save_ei != NULL) {
    // Restore 'eventignore' to the value before ":noautocmd".
    set_option_direct(kOptEventignore, CSTR_AS_OPTVAL(cmod->cmod_save_ei), 0, SID_NONE);
    free_string_option(cmod->cmod_save_ei);
    cmod->cmod_save_ei = NULL;
  }

  xfree(cmod->cmod_filter_pat);
  vim_regfree(cmod->cmod_filter_regmatch.regprog);

  if (cmod->cmod_save_msg_silent > 0) {
    // messages could be enabled for a serious error, need to check if the
    // counters don't become negative
    if (!did_emsg || msg_silent > cmod->cmod_save_msg_silent - 1) {
      msg_silent = cmod->cmod_save_msg_silent - 1;
    }
    emsg_silent -= cmod->cmod_did_esilent;
    emsg_silent = MAX(emsg_silent, 0);
    // Restore msg_scroll, it's set by file I/O commands, even when no
    // message is actually displayed.
    msg_scroll = cmod->cmod_save_msg_scroll;

    // "silent reg" or "silent echo x" inside "redir" leaves msg_col
    // somewhere in the line.  Put it back in the first column.
    if (redirecting()) {
      msg_col = 0;
    }

    cmod->cmod_save_msg_silent = 0;
    cmod->cmod_did_esilent = 0;
  }
}

/// Parse the address range, if any, in "eap".
/// May set the last search pattern, unless "silent" is true.
///
/// @return  FAIL and set "errormsg" or return OK.
int parse_cmd_address(exarg_T *eap, const char **errormsg, bool silent)
  FUNC_ATTR_NONNULL_ALL
{
  int address_count = 1;
  linenr_T lnum;
  bool need_check_cursor = false;
  int ret = FAIL;

  // Repeat for all ',' or ';' separated addresses.
  while (true) {
    eap->line1 = eap->line2;
    eap->line2 = get_cmd_default_range(eap);
    eap->cmd = skipwhite(eap->cmd);
    lnum = get_address(eap, &eap->cmd, eap->addr_type, eap->skip, silent,
                       eap->addr_count == 0, address_count++, errormsg);
    if (eap->cmd == NULL) {  // error detected
      goto theend;
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
            *errormsg = _(e_invrange);
            goto theend;
          }
          break;
        case ADDR_TABS_RELATIVE:
        case ADDR_UNSIGNED:
        case ADDR_QUICKFIX:
          *errormsg = _(e_invrange);
          goto theend;
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
          eap->line2 = (linenr_T)qf_get_valid_size(eap);
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
          *errormsg = _(e_invrange);
          goto theend;
        }

        eap->cmd++;
        if (!eap->skip) {
          fmark_T *fm = mark_get_visual(curbuf, '<');
          if (!mark_check(fm, errormsg)) {
            goto theend;
          }
          assert(fm != NULL);
          eap->line1 = fm->mark.lnum;
          fm = mark_get_visual(curbuf, '>');
          if (!mark_check(fm, errormsg)) {
            goto theend;
          }
          assert(fm != NULL);
          eap->line2 = fm->mark.lnum;
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
        // accept zero as address, so 0;/PATTERN/ works correctly
        // (where zero usually means to use the first line).
        // Check the cursor position before returning.
        if (eap->line2 > 0) {
          check_cursor(curwin);
        } else {
          check_cursor_col(curwin);
        }
        need_check_cursor = true;
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
  ret = OK;

theend:
  if (need_check_cursor) {
    check_cursor(curwin);
  }
  return ret;
}

/// Check for an Ex command with optional tail.
/// If there is a match advance "pp" to the argument and return true.
///
/// @param pp   start of command
/// @param cmd  name of command
/// @param len  required length
bool checkforcmd(char **pp, const char *cmd, int len)
{
  int i;

  for (i = 0; cmd[i] != NUL; i++) {
    if ((cmd)[i] != (*pp)[i]) {
      break;
    }
  }
  if (i >= len && !ASCII_ISALPHA((*pp)[i])) {
    *pp = skipwhite(*pp + i);
    return true;
  }
  return false;
}

/// Append "cmd" to the error message in IObuff.
/// Takes care of limiting the length and handling 0xa0, which would be
/// invisible otherwise.
static void append_command(const char *cmd)
{
  size_t len = strlen(IObuff);
  const char *s = cmd;
  char *d;

  if (len > IOSIZE - 100) {
    // Not enough space, truncate and put in "...".
    d = IObuff + IOSIZE - 100;
    d -= utf_head_off(IObuff, d);
    STRCPY(d, "...");
  }
  xstrlcat(IObuff, ": ", IOSIZE);
  d = IObuff + strlen(IObuff);
  while (*s != NUL && d - IObuff + 5 < IOSIZE) {
    if ((uint8_t)s[0] == 0xc2 && (uint8_t)s[1] == 0xa0) {
      s += 2;
      STRCPY(d, "<a0>");
      d += 4;
    } else if (d - IObuff + utfc_ptr2len(s) + 1 >= IOSIZE) {
      break;
    } else {
      mb_copy_char(&s, &d);
    }
  }
  *d = NUL;
}

/// Return true and set "*idx" if "p" points to a one letter command.
/// - The 'k' command can directly be followed by any character.
/// - The 's' command can be followed directly by 'c', 'g', 'i', 'I' or 'r'
///          but :sre[wind] is another command, as are :scr[iptnames],
///          :scs[cope], :sim[alt], :sig[ns] and :sil[ent].
static int one_letter_cmd(const char *p, cmdidx_T *idx)
{
  if (*p == 'k') {
    *idx = CMD_k;
    return true;
  }
  if (p[0] == 's'
      && ((p[1] == 'c'
           && (p[2] == NUL
               || (p[2] != 's' && p[2] != 'r'
                   && (p[3] == NUL
                       || (p[3] != 'i' && p[4] != 'p')))))
          || p[1] == 'g'
          || (p[1] == 'i' && p[2] != 'm' && p[2] != 'l' && p[2] != 'g')
          || p[1] == 'I'
          || (p[1] == 'r' && p[2] != 'e'))) {
    *idx = CMD_substitute;
    return true;
  }
  return false;
}

/// Find an Ex command by its name, either built-in or user.
/// Start of the name can be found at eap->cmd.
/// Sets eap->cmdidx and returns a pointer to char after the command name.
/// "full" is set to true if the whole command name matched.
///
/// @return  NULL for an ambiguous user command.
char *find_ex_command(exarg_T *eap, int *full)
  FUNC_ATTR_NONNULL_ARG(1)
{
  // Isolate the command and search for it in the command table.
  char *p = eap->cmd;
  if (one_letter_cmd(p, &eap->cmdidx)) {
    p++;
  } else {
    while (ASCII_ISALPHA(*p)) {
      p++;
    }
    // for python 3.x support ":py3", ":python3", ":py3file", etc.
    if (eap->cmd[0] == 'p' && eap->cmd[1] == 'y') {
      while (ASCII_ISALNUM(*p)) {
        p++;
      }
    }

    // check for non-alpha command
    if (p == eap->cmd && vim_strchr("@!=><&~#", (uint8_t)(*p)) != NULL) {
      p++;
    }
    int len = (int)(p - eap->cmd);
    // The "d" command can directly be followed by 'l' or 'p' flag.
    if (*eap->cmd == 'd' && (p[-1] == 'l' || p[-1] == 'p')) {
      // Check for ":dl", ":dell", etc. to ":deletel": that's
      // :delete with the 'l' flag.  Same for 'p'.
      int i;
      for (i = 0; i < len; i++) {
        if (eap->cmd[i] != ("delete")[i]) {
          break;
        }
      }
      if (i == len - 1) {
        len--;
        if (p[-1] == 'l') {
          eap->flags |= EXFLAG_LIST;
        } else {
          eap->flags |= EXFLAG_PRINT;
        }
      }
    }

    if (ASCII_ISLOWER(eap->cmd[0])) {
      const int c1 = (uint8_t)eap->cmd[0];
      const int c2 = len == 1 ? NUL : eap->cmd[1];

      if (command_count != CMD_SIZE) {
        iemsg(_("E943: Command table needs to be updated, run 'make'"));
        getout(1);
      }

      // Use a precomputed index for fast look-up in cmdnames[]
      // taking into account the first 2 letters of eap->cmd.
      eap->cmdidx = cmdidxs1[CHAR_ORD_LOW(c1)];
      if (ASCII_ISLOWER(c2)) {
        eap->cmdidx += cmdidxs2[CHAR_ORD_LOW(c1)][CHAR_ORD_LOW(c2)];
      }
    } else if (ASCII_ISUPPER(eap->cmd[0])) {
      eap->cmdidx = CMD_Next;
    } else {
      eap->cmdidx = CMD_bang;
    }
    assert(eap->cmdidx >= 0);

    if (len == 3 && strncmp("def", eap->cmd, 3) == 0) {
      // Make :def an unknown command to avoid confusing behavior. #23149
      eap->cmdidx = CMD_SIZE;
    }

    for (; (int)eap->cmdidx < CMD_SIZE;
         eap->cmdidx = (cmdidx_T)((int)eap->cmdidx + 1)) {
      if (strncmp(cmdnames[(int)eap->cmdidx].cmd_name, eap->cmd,
                  (size_t)len) == 0) {
        if (full != NULL
            && cmdnames[(int)eap->cmdidx].cmd_name[len] == NUL) {
          *full = true;
        }
        break;
      }
    }

    // Look for a user defined command as a last resort.
    if ((eap->cmdidx == CMD_SIZE)
        && *eap->cmd >= 'A' && *eap->cmd <= 'Z') {
      // User defined commands may contain digits.
      while (ASCII_ISALNUM(*p)) {
        p++;
      }
      p = find_ucmd(eap, p, full, NULL, NULL);
    }
    if (p == eap->cmd) {
      eap->cmdidx = CMD_SIZE;
    }
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
  { "horizontal", 3, false },
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

/// @return  length of a command modifier (including optional count) or,
///          zero when it's not a modifier.
int modifier_len(char *cmd)
{
  char *p = cmd;

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

/// @return  > 0 if an Ex command "name" exists or,
///            2 if there is an exact match or,
///            3 if there is an ambiguous match.
int cmd_exists(const char *const name)
{
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

  // Check built-in commands and user defined commands.
  // For ":2match" and ":3match" we need to skip the number.
  exarg_T ea;
  ea.cmd = (char *)((*name == '2' || *name == '3') ? name + 1 : name);
  ea.cmdidx = 0;
  ea.flags = 0;
  int full = false;
  char *p = find_ex_command(&ea, &full);
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

/// "fullcommand" function
void f_fullcommand(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char *name = (char *)tv_get_string(&argvars[0]);

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  while (*name == ':') {
    name++;
  }
  name = skip_range(name, NULL);

  exarg_T ea;
  ea.cmd = (*name == '2' || *name == '3') ? name + 1 : name;
  ea.cmdidx = 0;
  ea.flags = 0;
  char *p = find_ex_command(&ea, NULL);
  if (p == NULL || ea.cmdidx == CMD_SIZE) {
    return;
  }

  rettv->vval.v_string = xstrdup(IS_USER_CMDIDX(ea.cmdidx)
                                 ? get_user_command_name(ea.useridx, ea.cmdidx)
                                 : cmdnames[ea.cmdidx].cmd_name);
}

cmdidx_T excmd_get_cmdidx(const char *cmd, size_t len)
{
  if (len == 3 && strncmp("def", cmd, 3) == 0) {
    // Make :def an unknown command to avoid confusing behavior. #23149
    return CMD_SIZE;
  }

  cmdidx_T idx;

  if (!one_letter_cmd(cmd, &idx)) {
    for (idx = 0; (int)idx < CMD_SIZE; idx = (cmdidx_T)((int)idx + 1)) {
      if (strncmp(cmdnames[(int)idx].cmd_name, cmd, len) == 0) {
        break;
      }
    }
  }

  return idx;
}

uint32_t excmd_get_argt(cmdidx_T idx)
{
  return cmdnames[(int)idx].cmd_argt;
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
char *skip_range(const char *cmd, int *ctx)
{
  while (vim_strchr(" \t0123456789.$%'/?-+,;\\", (uint8_t)(*cmd)) != NULL) {
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
      unsigned delim = (unsigned)(*cmd++);
      while (*cmd != NUL && *cmd != (char)delim) {
        if (*cmd++ == '\\' && *cmd != NUL) {
          cmd++;
        }
      }
      if (*cmd == NUL && ctx != NULL) {
        *ctx = EXPAND_NOTHING;
      }
    }
    if (*cmd != NUL) {
      cmd++;
    }
  }

  // Skip ":" and white space.
  cmd = skip_colon_white(cmd, false);

  return (char *)cmd;
}

static const char *addr_error(cmd_addr_T addr_type)
{
  if (addr_type == ADDR_NONE) {
    return _(e_norange);
  } else {
    return _(e_invrange);
  }
}

/// Gets a single EX address.
///
/// Sets ptr to the next character after the part that was interpreted.
/// Sets ptr to NULL when an error is encountered (stored in `errormsg`).
/// May set the last used search pattern.
///
/// @param skip           only skip the address, don't use it
/// @param silent         no errors or side effects
/// @param to_other_file  flag: may jump to other file
/// @param address_count  1 for first, >1 after comma
/// @param errormsg       Error message, if any
///
/// @return               MAXLNUM when no Ex address was found.
static linenr_T get_address(exarg_T *eap, char **ptr, cmd_addr_T addr_type, bool skip, bool silent,
                            int to_other_file, int address_count, const char **errormsg)
  FUNC_ATTR_NONNULL_ALL
{
  int c;
  int i;
  linenr_T n;
  pos_T pos;
  buf_T *buf;

  char *cmd = skipwhite(*ptr);
  linenr_T lnum = MAXLNUM;
  do {
    switch (*cmd) {
    case '.':                               // '.' - Cursor position
      cmd++;
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
        *errormsg = addr_error(addr_type);
        cmd = NULL;
        goto error;
        break;
      case ADDR_QUICKFIX:
        lnum = (linenr_T)qf_get_cur_idx(eap);
        break;
      case ADDR_QUICKFIX_VALID:
        lnum = qf_get_cur_valid_idx(eap);
        break;
      }
      break;

    case '$':                               // '$' - last line
      cmd++;
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
        *errormsg = addr_error(addr_type);
        cmd = NULL;
        goto error;
        break;
      case ADDR_QUICKFIX:
        lnum = (linenr_T)qf_get_size(eap);
        if (lnum == 0) {
          lnum = 1;
        }
        break;
      case ADDR_QUICKFIX_VALID:
        lnum = (linenr_T)qf_get_valid_size(eap);
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
        *errormsg = addr_error(addr_type);
        cmd = NULL;
        goto error;
      }
      if (skip) {
        cmd++;
      } else {
        // Only accept a mark in another file when it is
        // used by itself: ":'M".
        MarkGet flag = to_other_file && cmd[1] == NUL ? kMarkAll : kMarkBufLocal;
        fmark_T *fm = mark_get(curbuf, curwin, NULL, flag, *cmd);
        cmd++;
        if (fm != NULL && fm->fnum != curbuf->handle) {
          mark_move_to(fm, 0);
          // Jumped to another file.
          lnum = curwin->w_cursor.lnum;
        } else {
          if (!mark_check(fm, errormsg)) {
            cmd = NULL;
            goto error;
          }
          assert(fm != NULL);
          lnum = fm->mark.lnum;
        }
      }
      break;

    case '/':
    case '?':                           // '/' or '?' - search
      c = (uint8_t)(*cmd++);
      if (addr_type != ADDR_LINES) {
        *errormsg = addr_error(addr_type);
        cmd = NULL;
        goto error;
      }
      if (skip) {                       // skip "/pat/"
        cmd = skip_regexp(cmd, c, magic_isset());
        if (*cmd == c) {
          cmd++;
        }
      } else {
        int flags;

        pos = curwin->w_cursor;  // save curwin->w_cursor

        // When '/' or '?' follows another address, start from
        // there.
        if (lnum > 0 && lnum != MAXLNUM) {
          curwin->w_cursor.lnum
            = lnum > curbuf->b_ml.ml_line_count ? curbuf->b_ml.ml_line_count : lnum;
        }

        // Start a forward search at the end of the line (unless
        // before the first line).
        // Start a backward search at the start of the line.
        // This makes sure we never match in the current
        // line, and can match anywhere in the
        // next/previous line.
        curwin->w_cursor.col = (c == '/' && curwin->w_cursor.lnum > 0) ? MAXCOL : 0;
        searchcmdlen = 0;
        flags = silent ? 0 : SEARCH_HIS | SEARCH_MSG;
        if (!do_search(NULL, c, c, cmd, strlen(cmd), 1, flags, NULL)) {
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
      cmd++;
      if (addr_type != ADDR_LINES) {
        *errormsg = addr_error(addr_type);
        cmd = NULL;
        goto error;
      }
      if (*cmd == '&') {
        i = RE_SUBST;
      } else if (*cmd == '?' || *cmd == '/') {
        i = RE_SEARCH;
      } else {
        *errormsg = _(e_backslash);
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
                     "", 0, 1, SEARCH_MSG, i, NULL) != FAIL) {
          lnum = pos.lnum;
        } else {
          cmd = NULL;
          goto error;
        }
      }
      cmd++;
      break;

    default:
      if (ascii_isdigit(*cmd)) {                // absolute line number
        lnum = (linenr_T)getdigits(&cmd, false, 0);
      }
    }

    while (true) {
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
          lnum = (linenr_T)qf_get_cur_idx(eap);
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
        i = (uint8_t)(*cmd++);
      }
      if (!ascii_isdigit(*cmd)) {       // '+' is '+1'
        n = 1;
      } else {
        // "number", "+number" or "-number"
        n = getdigits_int32(&cmd, false, MAXLNUM);
        if (n == MAXLNUM) {
          *errormsg = _(e_line_number_out_of_range);
          cmd = NULL;
          goto error;
        }
      }

      if (addr_type == ADDR_TABS_RELATIVE) {
        *errormsg = _(e_invrange);
        cmd = NULL;
        goto error;
      } else if (addr_type == ADDR_LOADED_BUFFERS || addr_type == ADDR_BUFFERS) {
        lnum = compute_buffer_local_count(addr_type, lnum, (i == '-') ? -1 * n : n);
      } else {
        // Relative line addressing: need to adjust for lines in a
        // closed fold after the first address.
        if (addr_type == ADDR_LINES && (i == '-' || i == '+')
            && address_count >= 2) {
          hasFolding(curwin, lnum, NULL, &lnum);
        }
        if (i == '-') {
          lnum -= n;
        } else {
          if (lnum >= 0 && n >= INT32_MAX - lnum) {
            *errormsg = _(e_line_number_out_of_range);
            cmd = NULL;
            goto error;
          }
          lnum += n;
        }
      }
    }
  } while (*cmd == '/' || *cmd == '?');

error:
  *ptr = cmd;
  return lnum;
}

/// Get flags from an Ex command argument.
static void get_flags(exarg_T *eap)
{
  while (vim_strchr("lp#", (uint8_t)(*eap->arg)) != NULL) {
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
    eap->errmsg = _("E319: The command is not available in this version");
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

/// Check range in Ex command for validity.
///
/// @return  NULL when valid, error message when invalid.
char *invalid_range(exarg_T *eap)
{
  buf_T *buf;
  if (eap->line1 < 0 || eap->line2 < 0 || eap->line1 > eap->line2) {
    return _(e_invrange);
  }

  if (eap->argt & EX_RANGE) {
    switch (eap->addr_type) {
    case ADDR_LINES:
      if (eap->line2 > (curbuf->b_ml.ml_line_count
                        + (eap->cmdidx == CMD_diffget))) {
        return _(e_invrange);
      }
      break;
    case ADDR_ARGUMENTS:
      // add 1 if ARGCOUNT is 0
      if (eap->line2 > ARGCOUNT + (!ARGCOUNT)) {
        return _(e_invrange);
      }
      break;
    case ADDR_BUFFERS:
      // Only a boundary check, not whether the buffers actually
      // exist.
      if (eap->line1 < 1 || eap->line2 > get_highest_fnum()) {
        return _(e_invrange);
      }
      break;
    case ADDR_LOADED_BUFFERS:
      buf = firstbuf;
      while (buf->b_ml.ml_mfp == NULL) {
        if (buf->b_next == NULL) {
          return _(e_invrange);
        }
        buf = buf->b_next;
      }
      if (eap->line1 < buf->b_fnum) {
        return _(e_invrange);
      }
      buf = lastbuf;
      while (buf->b_ml.ml_mfp == NULL) {
        if (buf->b_prev == NULL) {
          return _(e_invrange);
        }
        buf = buf->b_prev;
      }
      if (eap->line2 > buf->b_fnum) {
        return _(e_invrange);
      }
      break;
    case ADDR_WINDOWS:
      if (eap->line2 > LAST_WIN_NR) {
        return _(e_invrange);
      }
      break;
    case ADDR_TABS:
      if (eap->line2 > LAST_TAB_NR) {
        return _(e_invrange);
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
        if (eap->addr_count == 0) {
          return _(e_no_errors);
        }
        return _(e_invrange);
      }
      break;
    case ADDR_QUICKFIX_VALID:
      if ((eap->line2 != 1 && (size_t)eap->line2 > qf_get_valid_size(eap))
          || eap->line2 < 0) {
        return _(e_invrange);
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

/// Correct the range for zero line number, if required.
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

/// For a ":vimgrep" or ":vimgrepadd" command return a pointer past the
/// pattern.  Otherwise return eap->arg.
static char *skip_grep_pat(exarg_T *eap)
{
  char *p = eap->arg;

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

/// For the ":make" and ":grep" commands insert the 'makeprg'/'grepprg' option
/// in the command line, so that things like % get expanded.
char *replace_makeprg(exarg_T *eap, char *arg, char **cmdlinep)
{
  bool isgrep = eap->cmdidx == CMD_grep
                || eap->cmdidx == CMD_lgrep
                || eap->cmdidx == CMD_grepadd
                || eap->cmdidx == CMD_lgrepadd;

  // Don't do it when ":vimgrep" is used for ":grep".
  if ((eap->cmdidx == CMD_make || eap->cmdidx == CMD_lmake || isgrep)
      && !grep_internal(eap->cmdidx)) {
    const char *program = isgrep ? (*curbuf->b_p_gp == NUL ? p_gp : curbuf->b_p_gp)
                                 : (*curbuf->b_p_mp == NUL ? p_mp : curbuf->b_p_mp);

    arg = skipwhite(arg);

    char *new_cmdline;
    // Replace $* by given arguments
    if ((new_cmdline = strrep(program, "$*", arg)) == NULL) {
      // No $* in arg, build "<makeprg> <arg>" instead
      new_cmdline = xmalloc(strlen(program) + strlen(arg) + 2);
      STRCPY(new_cmdline, program);
      strcat(new_cmdline, " ");
      strcat(new_cmdline, arg);
    }

    msg_make(arg);

    // 'eap->cmd' is not set here, because it is not used at CMD_make
    xfree(*cmdlinep);
    *cmdlinep = new_cmdline;
    arg = new_cmdline;
  }
  return arg;
}

/// Expand file name in Ex command argument.
/// When an error is detected, "errormsgp" is set to a non-NULL pointer.
///
/// @return  FAIL for failure, OK otherwise.
int expand_filename(exarg_T *eap, char **cmdlinep, const char **errormsgp)
{
  // Skip a regexp pattern for ":vimgrep[add] pat file..."
  char *p = skip_grep_pat(eap);

  // Decide to expand wildcards *before* replacing '%', '#', etc.  If
  // the file name contains a wildcard it should not cause expanding.
  // (it will be expanded anyway if there is a wildcard before replacing).
  bool has_wildcards = path_has_wildcard(p);
  while (*p != NUL) {
    // Skip over `=expr`, wildcards in it are not expanded.
    if (p[0] == '`' && p[1] == '=') {
      p += 2;
      skip_expr(&p, NULL);
      if (*p == '`') {
        p++;
      }
      continue;
    }
    // Quick check if this cannot be the start of a special string.
    // Also removes backslash before '%', '#' and '<'.
    if (vim_strchr("%#<", (uint8_t)(*p)) == NULL) {
      p++;
      continue;
    }

    // Try to find a match at this position.
    size_t srclen;
    int escaped;
    char *repl = eval_vars(p, eap->arg, &srclen, &(eap->do_ecmd_lnum),
                           errormsgp, &escaped, true);
    if (*errormsgp != NULL) {           // error detected
      return FAIL;
    }
    if (repl == NULL) {                 // no match found
      p += srclen;
      continue;
    }

    // Wildcards won't be expanded below, the replacement is taken
    // literally.  But do expand "~/file", "~user/file" and "$HOME/file".
    if (vim_strchr(repl, '$') != NULL || vim_strchr(repl, '~') != NULL) {
      char *l = repl;

      repl = expand_env_save(repl);
      xfree(l);
    }

    // Need to escape white space et al. with a backslash.
    // Don't do this for:
    // - replacement that already has been escaped: "##"
    // - shell commands (may have to use quotes instead).
    if (!eap->usefilter
        && !escaped
        && eap->cmdidx != CMD_bang
        && eap->cmdidx != CMD_grep
        && eap->cmdidx != CMD_grepadd
        && eap->cmdidx != CMD_lgrep
        && eap->cmdidx != CMD_lgrepadd
        && eap->cmdidx != CMD_lmake
        && eap->cmdidx != CMD_make
        && eap->cmdidx != CMD_terminal
        && !(eap->argt & EX_NOSPC)) {
      char *l;
#ifdef BACKSLASH_IN_FILENAME
      // Don't escape a backslash here, because rem_backslash() doesn't
      // remove it later.
      static char *nobslash = " \t\"|";
# define ESCAPE_CHARS nobslash
#else
# define ESCAPE_CHARS escape_chars
#endif

      for (l = repl; *l; l++) {
        if (vim_strchr(ESCAPE_CHARS, (uint8_t)(*l)) != NULL) {
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
        && strpbrk(repl, "!") != NULL) {
      char *l = vim_strsave_escaped(repl, "!");
      xfree(repl);
      repl = l;
    }

    p = repl_cmdline(eap, p, srclen, repl, cmdlinep);
    xfree(repl);
  }

  // One file argument: Expand wildcards.
  // Don't do this with ":r !command" or ":w !command".
  if ((eap->argt & EX_NOSPC) && !eap->usefilter) {
    // Replace environment variables.
    if (has_wildcards) {
      // May expand environment variables.  This
      // can be done much faster with expand_env() than with
      // something else (e.g., calling a shell).
      // After expanding environment variables, check again
      // if there are still wildcards present.
      if (vim_strchr(eap->arg, '$') != NULL
          || vim_strchr(eap->arg, '~') != NULL) {
        expand_env_esc(eap->arg, NameBuff, MAXPATHL, true, true, NULL);
        has_wildcards = path_has_wildcard(NameBuff);
        p = NameBuff;
      } else {
        p = NULL;
      }
      if (p != NULL) {
        repl_cmdline(eap, eap->arg, strlen(eap->arg), p, cmdlinep);
      }
    }

    // Halve the number of backslashes (this is Vi compatible).
    // For Unix, when wildcards are expanded, this is
    // done by ExpandOne() below.
#ifdef UNIX
    if (!has_wildcards) {
      backslash_halve(eap->arg);
    }
#else
    backslash_halve(eap->arg);
#endif

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
      repl_cmdline(eap, eap->arg, strlen(eap->arg), p, cmdlinep);
      xfree(p);
    }
  }
  return OK;
}

/// Replace part of the command line, keeping eap->cmd, eap->arg, eap->args and
/// eap->nextcmd correct.
/// "src" points to the part that is to be replaced, of length "srclen".
/// "repl" is the replacement string.
///
/// @return  a pointer to the character after the replaced string.
static char *repl_cmdline(exarg_T *eap, char *src, size_t srclen, char *repl, char **cmdlinep)
{
  // The new command line is build in new_cmdline[].
  // First allocate it.
  // Careful: a "+cmd" argument may have been NUL terminated.
  size_t len = strlen(repl);
  size_t i = (size_t)(src - *cmdlinep) + strlen(src + srclen) + len + 3;
  if (eap->nextcmd != NULL) {
    i += strlen(eap->nextcmd);    // add space for next command
  }
  char *new_cmdline = xmalloc(i);
  size_t offset = (size_t)(src - *cmdlinep);

  // Copy the stuff before the expanded part.
  // Copy the expanded stuff.
  // Copy what came after the expanded part.
  // Copy the next commands, if there are any.
  i = offset;   // length of part before match
  memmove(new_cmdline, *cmdlinep, i);

  memmove(new_cmdline + i, repl, len);
  i += len;                             // remember the end of the string
  STRCPY(new_cmdline + i, src + srclen);
  src = new_cmdline + i;                // remember where to continue

  if (eap->nextcmd != NULL) {           // append next command
    i = strlen(new_cmdline) + 1;
    STRCPY(new_cmdline + i, eap->nextcmd);
    eap->nextcmd = new_cmdline + i;
  }
  eap->cmd = new_cmdline + (eap->cmd - *cmdlinep);
  eap->arg = new_cmdline + (eap->arg - *cmdlinep);

  for (size_t j = 0; j < eap->argc; j++) {
    if (offset >= (size_t)(eap->args[j] - *cmdlinep)) {
      // If replaced text is after or in the same position as the argument,
      // the argument's position relative to the beginning of the cmdline stays the same.
      eap->args[j] = new_cmdline + (eap->args[j] - *cmdlinep);
    } else {
      // Otherwise, argument gets shifted alongside the replaced text.
      // The amount of the shift is equal to the difference of the old and new string length.
      eap->args[j] = new_cmdline + ((eap->args[j] - *cmdlinep) + (ptrdiff_t)(len - srclen));
    }
  }

  if (eap->do_ecmd_cmd != NULL && eap->do_ecmd_cmd != dollar_command) {
    eap->do_ecmd_cmd = new_cmdline + (eap->do_ecmd_cmd - *cmdlinep);
  }
  xfree(*cmdlinep);
  *cmdlinep = new_cmdline;

  return src;
}

/// Check for '|' to separate commands and '"' to start comments.
void separate_nextcmd(exarg_T *eap)
{
  char *p = skip_grep_pat(eap);

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
      skip_expr(&p, NULL);
      if (*p == NUL) {  // stop at NUL after CTRL-V
        break;
      }
    } else if (
               // Check for '"': start of comment or '|': next command
               // :@" does not start a comment!
               // :redir @" doesn't either.
               (*p == '"'
                && !(eap->argt & EX_NOTRLCOM)
                && (eap->cmdidx != CMD_at || p != eap->arg)
                && (eap->cmdidx != CMD_redir
                    || p != eap->arg + 1 || p[-1] != '@'))
               || (*p == '|'
                   && eap->cmdidx != CMD_append
                   && eap->cmdidx != CMD_change
                   && eap->cmdidx != CMD_insert)
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

/// get + command from ex argument
static char *getargcmd(char **argp)
{
  char *arg = *argp;
  char *command = NULL;

  if (*arg == '+') {        // +[command]
    arg++;
    if (ascii_isspace(*arg) || *arg == NUL) {
      command = dollar_command;
    } else {
      command = arg;
      arg = skip_cmd_arg(command, true);
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
/// @param rembs  true to halve the number of backslashes
char *skip_cmd_arg(char *p, bool rembs)
{
  while (*p && !ascii_isspace(*p)) {
    if (*p == '\\' && p[1] != NUL) {
      if (rembs) {
        STRMOVE(p, p + 1);
      } else {
        p++;
      }
    }
    MB_PTR_ADV(p);
  }
  return p;
}

int get_bad_opt(const char *p, exarg_T *eap)
  FUNC_ATTR_NONNULL_ALL
{
  if (STRICMP(p, "keep") == 0) {
    eap->bad_char = BAD_KEEP;
  } else if (STRICMP(p, "drop") == 0) {
    eap->bad_char = BAD_DROP;
  } else if (MB_BYTE2LEN((uint8_t)(*p)) == 1 && p[1] == NUL) {
    eap->bad_char = (uint8_t)(*p);
  } else {
    return FAIL;
  }
  return OK;
}

/// Function given to ExpandGeneric() to obtain the list of bad= names.
static char *get_bad_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  // Note: Keep this in sync with get_bad_opt().
  static char *(p_bad_values[]) = {
    "?",
    "keep",
    "drop",
  };

  if (idx < (int)ARRAY_SIZE(p_bad_values)) {
    return p_bad_values[idx];
  }
  return NULL;
}

/// Get "++opt=arg" argument.
///
/// @return  FAIL or OK.
static int getargopt(exarg_T *eap)
{
  char *arg = eap->arg + 2;
  int *pp = NULL;
  int bad_char_idx;

  // Note: Keep this in sync with get_argopt_name.

  // ":edit ++[no]bin[ary] file"
  if (strncmp(arg, "bin", 3) == 0 || strncmp(arg, "nobin", 5) == 0) {
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
  if (strncmp(arg, "edit", 4) == 0) {
    eap->read_edit = true;
    eap->arg = skipwhite(arg + 4);
    return OK;
  }

  // ":write ++p foo/bar/file
  if (strncmp(arg, "p", 1) == 0) {
    eap->mkdir_p = true;
    eap->arg = skipwhite(arg + 1);
    return OK;
  }

  if (strncmp(arg, "ff", 2) == 0) {
    arg += 2;
    pp = &eap->force_ff;
  } else if (strncmp(arg, "fileformat", 10) == 0) {
    arg += 10;
    pp = &eap->force_ff;
  } else if (strncmp(arg, "enc", 3) == 0) {
    if (strncmp(arg, "encoding", 8) == 0) {
      arg += 8;
    } else {
      arg += 3;
    }
    pp = &eap->force_enc;
  } else if (strncmp(arg, "bad", 3) == 0) {
    arg += 3;
    pp = &bad_char_idx;
  }

  if (pp == NULL || *arg != '=') {
    return FAIL;
  }

  arg++;
  *pp = (int)(arg - eap->cmd);
  arg = skip_cmd_arg(arg, false);
  eap->arg = skipwhite(arg);
  *arg = NUL;

  if (pp == &eap->force_ff) {
    if (check_ff_value(eap->cmd + eap->force_ff) == FAIL) {
      return FAIL;
    }
    eap->force_ff = (uint8_t)eap->cmd[eap->force_ff];
  } else if (pp == &eap->force_enc) {
    // Make 'fileencoding' lower case.
    for (char *p = eap->cmd + eap->force_enc; *p != NUL; p++) {
      *p = (char)TOLOWER_ASC(*p);
    }
  } else {
    // Check ++bad= argument.  Must be a single-byte character, "keep" or
    // "drop".
    if (get_bad_opt(eap->cmd + bad_char_idx, eap) == FAIL) {
      return FAIL;
    }
  }

  return OK;
}

/// Function given to ExpandGeneric() to obtain the list of ++opt names.
static char *get_argopt_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  // Note: Keep this in sync with getargopt().
  static char *(p_opt_values[]) = {
    "fileformat=",
    "encoding=",
    "binary",
    "nobinary",
    "bad=",
    "edit",
    "p",
  };

  if (idx < (int)ARRAY_SIZE(p_opt_values)) {
    return p_opt_values[idx];
  }
  return NULL;
}

/// Command-line expansion for ++opt=name.
int expand_argopt(char *pat, expand_T *xp, regmatch_T *rmp, char ***matches, int *numMatches)
{
  if (xp->xp_pattern > xp->xp_line && *(xp->xp_pattern - 1) == '=') {
    CompleteListItemGetter cb = NULL;

    char *name_end = xp->xp_pattern - 1;
    if (name_end - xp->xp_line >= 2
        && strncmp(name_end - 2, "ff", 2) == 0) {
      cb = get_fileformat_name;
    } else if (name_end - xp->xp_line >= 10
               && strncmp(name_end - 10, "fileformat", 10) == 0) {
      cb = get_fileformat_name;
    } else if (name_end - xp->xp_line >= 3
               && strncmp(name_end - 3, "enc", 3) == 0) {
      cb = get_encoding_name;
    } else if (name_end - xp->xp_line >= 8
               && strncmp(name_end - 8, "encoding", 8) == 0) {
      cb = get_encoding_name;
    } else if (name_end - xp->xp_line >= 3
               && strncmp(name_end - 3, "bad", 3) == 0) {
      cb = get_bad_name;
    }

    if (cb != NULL) {
      ExpandGeneric(pat, xp, rmp, matches, numMatches, cb, false);
      return OK;
    }
    return FAIL;
  }

  // Special handling of "ff" which acts as a short form of
  // "fileformat", as "ff" is not a substring of it.
  if (xp->xp_pattern_len == 2
      && strncmp(xp->xp_pattern, "ff", xp->xp_pattern_len) == 0) {
    *matches = xmalloc(sizeof(char *));
    *numMatches = 1;
    (*matches)[0] = xstrdup("fileformat=");
    return OK;
  }

  ExpandGeneric(pat, xp, rmp, matches, numMatches, get_argopt_name, false);
  return OK;
}

/// Handle the argument for a tabpage related ex command.
/// When an error is encountered then eap->errmsg is set.
///
/// @return  a tabpage number.
static int get_tabpage_arg(exarg_T *eap)
{
  int tab_number = 0;
  int unaccept_arg0 = (eap->cmdidx == CMD_tabmove) ? 0 : 1;

  if (eap->arg && *eap->arg != NUL) {
    char *p = eap->arg;
    int relative = 0;  // argument +N/-N means: go to N places to the
                       // right/left relative to the current position.

    if (*p == '-') {
      relative = -1;
      p++;
    } else if (*p == '+') {
      relative = 1;
      p++;
    }

    char *p_save = p;
    tab_number = (int)getdigits(&p, false, tab_number);

    if (relative == 0) {
      if (strcmp(p, "$") == 0) {
        tab_number = LAST_TAB_NR;
      } else if (strcmp(p, "#") == 0) {
        if (valid_tabpage(lastused_tabpage)) {
          tab_number = tabpage_index(lastused_tabpage);
        } else {
          eap->errmsg = ex_errmsg(e_invargval, eap->arg);
          tab_number = 0;
          goto theend;
        }
      } else if (p == p_save || *p_save == '-' || *p != NUL
                 || tab_number > LAST_TAB_NR) {
        // No numbers as argument.
        eap->errmsg = ex_errmsg(e_invarg2, eap->arg);
        goto theend;
      }
    } else {
      if (*p_save == NUL) {
        tab_number = 1;
      } else if (p == p_save || *p_save == '-' || *p != NUL || tab_number == 0) {
        // No numbers as argument.
        eap->errmsg = ex_errmsg(e_invarg2, eap->arg);
        goto theend;
      }
      tab_number = tab_number * relative + tabpage_index(curtab);
      if (!unaccept_arg0 && relative == -1) {
        tab_number--;
      }
    }
    if (tab_number < unaccept_arg0 || tab_number > LAST_TAB_NR) {
      eap->errmsg = ex_errmsg(e_invarg2, eap->arg);
    }
  } else if (eap->addr_count > 0) {
    if (unaccept_arg0 && eap->line2 == 0) {
      eap->errmsg = _(e_invrange);
      tab_number = 0;
    } else {
      tab_number = (int)eap->line2;
      if (!unaccept_arg0) {
        char *cmdp = eap->cmd;
        while (--cmdp > *eap->cmdlinep
               && (ascii_iswhite(*cmdp) || ascii_isdigit(*cmdp))) {}
        if (*cmdp == '-') {
          tab_number--;
          if (tab_number < unaccept_arg0) {
            eap->errmsg = _(e_invrange);
          }
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

static void ex_autocmd(exarg_T *eap)
{
  // Disallow autocommands in secure mode.
  if (secure) {
    secure = 2;
    eap->errmsg = _(e_curdir);
  } else if (eap->cmdidx == CMD_autocmd) {
    do_autocmd(eap, eap->arg, eap->forceit);
  } else {
    do_augroup(eap->arg, eap->forceit);
  }
}

/// ":doautocmd": Apply the automatic commands to the current buffer.
static void ex_doautocmd(exarg_T *eap)
{
  char *arg = eap->arg;
  int call_do_modelines = check_nomodeline(&arg);
  bool did_aucmd;

  do_doautocmd(arg, false, &did_aucmd);
  // Only when there is no <nomodeline>.
  if (call_do_modelines && did_aucmd) {
    do_modelines(0);
  }
}

/// :[N]bunload[!] [N] [bufname] unload buffer
/// :[N]bdelete[!] [N] [bufname] delete buffer from buffer list
/// :[N]bwipeout[!] [N] [bufname] delete buffer really
static void ex_bunload(exarg_T *eap)
{
  eap->errmsg = do_bufdel(eap->cmdidx == CMD_bdelete
                          ? DOBUF_DEL
                          : eap->cmdidx == CMD_bwipeout
                          ? DOBUF_WIPE
                          : DOBUF_UNLOAD,
                          eap->arg, eap->addr_count, (int)eap->line1, (int)eap->line2,
                          eap->forceit);
}

/// :[N]buffer [N]       to buffer N
/// :[N]sbuffer [N]      to buffer N
static void ex_buffer(exarg_T *eap)
{
  do_exbuffer(eap);
}

/// ":buffer" command and alike.
static void do_exbuffer(exarg_T *eap)
{
  if (*eap->arg) {
    eap->errmsg = ex_errmsg(e_trailing_arg, eap->arg);
  } else {
    if (eap->addr_count == 0) {  // default is current buffer
      goto_buffer(eap, DOBUF_CURRENT, FORWARD, 0);
    } else {
      goto_buffer(eap, DOBUF_FIRST, FORWARD, (int)eap->line2);
    }
    if (eap->do_ecmd_cmd != NULL) {
      do_cmdline_cmd(eap->do_ecmd_cmd);
    }
  }
}

/// :[N]bmodified [N]    to next mod. buffer
/// :[N]sbmodified [N]   to next mod. buffer
static void ex_bmodified(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_MOD, FORWARD, (int)eap->line2);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd(eap->do_ecmd_cmd);
  }
}

/// :[N]bnext [N]        to next buffer
/// :[N]sbnext [N]       split and to next buffer
static void ex_bnext(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_CURRENT, FORWARD, (int)eap->line2);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd(eap->do_ecmd_cmd);
  }
}

/// :[N]bNext [N]        to previous buffer
/// :[N]bprevious [N]    to previous buffer
/// :[N]sbNext [N]       split and to previous buffer
/// :[N]sbprevious [N]   split and to previous buffer
static void ex_bprevious(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_CURRENT, BACKWARD, (int)eap->line2);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd(eap->do_ecmd_cmd);
  }
}

/// :brewind             to first buffer
/// :bfirst              to first buffer
/// :sbrewind            split and to first buffer
/// :sbfirst             split and to first buffer
static void ex_brewind(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_FIRST, FORWARD, 0);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd(eap->do_ecmd_cmd);
  }
}

/// :blast               to last buffer
/// :sblast              split and to last buffer
static void ex_blast(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_LAST, BACKWARD, 0);
  if (eap->do_ecmd_cmd != NULL) {
    do_cmdline_cmd(eap->do_ecmd_cmd);
  }
}

int ends_excmd(int c) FUNC_ATTR_CONST
{
  return c == NUL || c == '|' || c == '"' || c == '\n';
}

/// @return  the next command, after the first '|' or '\n' or,
///          NULL if not found.
char *find_nextcmd(const char *p)
{
  while (*p != '|' && *p != '\n') {
    if (*p == NUL) {
      return NULL;
    }
    p++;
  }
  return (char *)p + 1;
}

/// Check if *p is a separator between Ex commands, skipping over white space.
///
/// @return  NULL if it isn't, the following character if it is.
char *check_nextcmd(char *p)
{
  char *s = skipwhite(p);

  if (*s == '|' || *s == '\n') {
    return s + 1;
  }
  return NULL;
}

/// - if there are more files to edit
/// - and this is the last window
/// - and forceit not used
/// - and not repeated twice on a row
///
/// @param   message  when false check only, no messages
///
/// @return  FAIL and give error message if 'message' true, return OK otherwise
static int check_more(bool message, bool forceit)
{
  int n = ARGCOUNT - curwin->w_arg_idx - 1;

  if (!forceit && only_one_window()
      && ARGCOUNT > 1 && !arg_had_last && n > 0 && quitmore == 0) {
    if (message) {
      if ((p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) && curbuf->b_fname != NULL) {
        char buff[DIALOG_MSG_SIZE];

        vim_snprintf(buff, DIALOG_MSG_SIZE,
                     NGETTEXT("%d more file to edit.  Quit anyway?",
                              "%d more files to edit.  Quit anyway?", n), n);
        if (vim_dialog_yesno(VIM_QUESTION, NULL, buff, 1) == VIM_YES) {
          return OK;
        }
        return FAIL;
      }
      semsg(NGETTEXT("E173: %" PRId64 " more file to edit",
                     "E173: %" PRId64 " more files to edit", n), (int64_t)n);
      quitmore = 2;                 // next try to quit is allowed
    }
    return FAIL;
  }
  return OK;
}

/// Function given to ExpandGeneric() to obtain the list of command names.
char *get_command_name(expand_T *xp, int idx)
{
  if (idx >= CMD_SIZE) {
    return expand_user_command_name(idx);
  }
  return cmdnames[idx].cmd_name;
}

static void ex_colorscheme(exarg_T *eap)
{
  if (*eap->arg == NUL) {
    char *expr = xstrdup("g:colors_name");

    emsg_off++;
    char *p = eval_to_string(expr, false, false);
    emsg_off--;
    xfree(expr);

    if (p != NULL) {
      msg(p, 0);
      xfree(p);
    } else {
      msg("default", 0);
    }
  } else if (load_colors(eap->arg) == FAIL) {
    semsg(_("E185: Cannot find color scheme '%s'"), eap->arg);
  }
}

static void ex_highlight(exarg_T *eap)
{
  if (*eap->arg == NUL && eap->cmd[2] == '!') {
    msg(_("Greetings, Vim user!"), 0);
  }
  do_highlight(eap->arg, eap->forceit, false);
}

/// Call this function if we thought we were going to exit, but we won't
/// (because of an error).  May need to restore the terminal mode.
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

/// ":quit": quit current window, quit Vim if the last window is closed.
/// ":{nr}quit": quit window {nr}
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
    linenr_T wnr = eap->line2;

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
    win_close(wp, !buf_hide(wp->w_buffer) || eap->forceit, eap->forceit);
  }
}

/// ":cquit".
static void ex_cquit(exarg_T *eap)
  FUNC_ATTR_NORETURN
{
  // this does not always pass on the exit code to the Manx compiler. why?
  int status = eap->addr_count > 0 ? (int)eap->line2 : EXIT_FAILURE;
  ui_call_error_exit(status);
  getout(status);
}

/// Do preparations for "qall" and "wqall".
/// Returns FAIL when quitting should be aborted.
int before_quit_all(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    cmdwin_result = eap->forceit
                    ? K_XF1  // open_cmdwin() takes care of this
                    : K_XF2;
    return FAIL;
  }

  // Don't quit while editing the command line.
  if (text_locked()) {
    text_locked_msg();
    return FAIL;
  }

  if (before_quit_autocmds(curwin, true, eap->forceit)) {
    return FAIL;
  }

  return OK;
}

/// ":qall": try to quit all windows
static void ex_quit_all(exarg_T *eap)
{
  if (before_quit_all(eap) == FAIL) {
    return;
  }
  exiting = true;
  if (eap->forceit || !check_changed_any(false, false)) {
    getout(0);
  }
  not_exiting();
}

/// ":close": close current window, unless it is the last one
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

/// ":pclose": Close any preview window.
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
  // Never close the autocommand window.
  if (is_aucmd_win(win)) {
    emsg(_(e_autocmd_close));
    return;
  }

  buf_T *buf = win->w_buffer;

  bool need_hide = (bufIsChanged(buf) && buf->b_nwindows <= 1);
  if (need_hide && !buf_hide(buf) && !forceit) {
    if ((p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) && p_write) {
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
    win_close(win, !need_hide && !buf_hide(buf), forceit);
  } else {
    win_close_othertab(win, !need_hide && !buf_hide(buf), tp);
  }
}

/// ":tabclose": close current tab page, unless it is the last one.
/// ":tabclose N": close tab page N.
static void ex_tabclose(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    cmdwin_result = K_IGNORE;
    return;
  }

  if (first_tabpage->tp_next == NULL) {
    emsg(_("E784: Cannot close last tab page"));
    return;
  }

  int tab_number = get_tabpage_arg(eap);
  if (eap->errmsg != NULL) {
    return;
  }

  tabpage_T *tp = find_tabpage(tab_number);
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

/// ":tabonly": close all tab pages except the current one
static void ex_tabonly(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    cmdwin_result = K_IGNORE;
    return;
  }

  if (first_tabpage->tp_next == NULL) {
    msg(_("Already only one tab page"), 0);
    return;
  }

  int tab_number = get_tabpage_arg(eap);
  if (eap->errmsg != NULL) {
    return;
  }

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

/// Close the current tab page.
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

/// Close tab page "tp", which is not the current tab page.
/// Note that autocommands may make "tp" invalid.
/// Also takes care of the tab pages line disappearing when closing the
/// last-but-one tab page.
void tabpage_close_other(tabpage_T *tp, int forceit)
{
  int done = 0;
  char prev_idx[NUMBUFLEN];

  // Limit to 1000 windows, autocommands may add a window while we close
  // one.  OK, so I'm paranoid...
  while (++done < 1000) {
    snprintf(prev_idx, sizeof(prev_idx), "%i", tabpage_index(tp));
    win_T *wp = tp->tp_lastwin;
    ex_win_close(forceit, wp, tp);

    // Autocommands may delete the tab page under our fingers and we may
    // fail to close a window with a modified buffer.
    if (!valid_tabpage(tp) || tp->tp_lastwin == wp) {
      break;
    }
  }
}

/// ":only".
static void ex_only(exarg_T *eap)
{
  win_T *wp;

  if (eap->addr_count > 0) {
    linenr_T wnr = eap->line2;
    for (wp = firstwin; --wnr > 0;) {
      if (wp->w_next == NULL) {
        break;
      }
      wp = wp->w_next;
    }
  } else {
    wp = curwin;
  }
  if (wp != curwin) {
    win_goto(wp);
  }
  close_others(true, eap->forceit);
}

static void ex_hide(exarg_T *eap)
{
  // ":hide" or ":hide | cmd": hide current window
  if (eap->skip) {
    return;
  }

  if (eap->addr_count == 0) {
    win_close(curwin, false, eap->forceit);  // don't free buffer
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
    win_close(win, false, eap->forceit);
  }
}

/// ":stop" and ":suspend": Suspend Vim.
static void ex_stop(exarg_T *eap)
{
  if (!eap->forceit) {
    autowrite_all();
  }
  may_trigger_vim_suspend_resume(true);
  ui_call_suspend();
  ui_flush();
}

/// ":exit", ":xit" and ":wq": Write file and quit the current window.
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
    win_close(curwin, !buf_hide(curwin->w_buffer), eap->forceit);
  }
}

/// ":print", ":list", ":number".
static void ex_print(exarg_T *eap)
{
  if (curbuf->b_ml.ml_flags & ML_EMPTY) {
    emsg(_(e_empty_buffer));
  } else {
    for (; !got_int; os_breakcheck()) {
      print_line(eap->line1,
                 (eap->cmdidx == CMD_number || eap->cmdidx == CMD_pound
                  || (eap->flags & EXFLAG_NR)),
                 eap->cmdidx == CMD_list || (eap->flags & EXFLAG_LIST));
      if (++eap->line1 > eap->line2) {
        break;
      }
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

/// ":preserve".
static void ex_preserve(exarg_T *eap)
{
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

/// Command modifier used in a wrong way.
static void ex_wrongmodifier(exarg_T *eap)
{
  eap->errmsg = _(e_invcmd);
}

/// callback function for 'findfunc'
static Callback ffu_cb;

static Callback *get_findfunc_callback(void)
{
  return *curbuf->b_p_ffu != NUL ? &curbuf->b_ffu_cb : &ffu_cb;
}

/// Call 'findfunc' to obtain a list of file names.
static list_T *call_findfunc(char *pat, BoolVarValue cmdcomplete)
{
  const sctx_T saved_sctx = current_sctx;

  typval_T args[3];
  args[0].v_type = VAR_STRING;
  args[0].vval.v_string = pat;
  args[1].v_type = VAR_BOOL;
  args[1].vval.v_bool = cmdcomplete;
  args[2].v_type = VAR_UNKNOWN;

  // Lock the text to prevent weird things from happening.  Also disallow
  // switching to another window, it should not be needed and may end up in
  // Insert mode in another buffer.
  textlock++;

  sctx_T *ctx = get_option_sctx(kOptFindfunc);
  if (ctx != NULL) {
    current_sctx = *ctx;
  }

  Callback *cb = get_findfunc_callback();
  typval_T rettv;
  int retval = callback_call(cb, 2, args, &rettv);

  current_sctx = saved_sctx;

  textlock--;

  list_T *retlist = NULL;

  if (retval == OK) {
    if (rettv.v_type == VAR_LIST) {
      retlist = tv_list_copy(NULL, rettv.vval.v_list, false, get_copyID());
    } else {
      emsg(_(e_invalid_return_type_from_findfunc));
    }

    tv_clear(&rettv);
  }

  return retlist;
}

/// Find file names matching "pat" using 'findfunc' and return it in "files".
/// Used for expanding the :find, :sfind and :tabfind command argument.
/// Returns OK on success and FAIL otherwise.
int expand_findfunc(char *pat, char ***files, int *numMatches)
{
  *numMatches = 0;
  *files = NULL;

  list_T *l = call_findfunc(pat, kBoolVarTrue);
  if (l == NULL) {
    return FAIL;
  }

  int len = tv_list_len(l);
  if (len == 0) {  // empty List
    return FAIL;
  }

  *files = xmalloc(sizeof(char *) * (size_t)len);

  // Copy all the List items
  int idx = 0;
  TV_LIST_ITER_CONST(l, li, {
    if (TV_LIST_ITEM_TV(li)->v_type == VAR_STRING) {
      (*files)[idx] = xstrdup(TV_LIST_ITEM_TV(li)->vval.v_string);
      idx++;
    }
  });

  *numMatches = idx;
  tv_list_free(l);

  return OK;
}

/// Use 'findfunc' to find file 'findarg'.  The 'count' argument is used to find
/// the n'th matching file.
static char *findfunc_find_file(char *findarg, size_t findarg_len, int count)
{
  char *ret_fname = NULL;

  const char cc = findarg[findarg_len];
  findarg[findarg_len] = NUL;

  list_T *fname_list = call_findfunc(findarg, kBoolVarFalse);
  int fname_count = tv_list_len(fname_list);

  if (fname_count == 0) {
    semsg(_(e_cant_find_file_str_in_path), findarg);
  } else {
    if (count > fname_count) {
      semsg(_(e_no_more_file_str_found_in_path), findarg);
    } else {
      listitem_T *li = tv_list_find(fname_list, count - 1);
      if (li != NULL && TV_LIST_ITEM_TV(li)->v_type == VAR_STRING) {
        ret_fname = xstrdup(TV_LIST_ITEM_TV(li)->vval.v_string);
      }
    }
  }

  if (fname_list != NULL) {
    tv_list_free(fname_list);
  }

  findarg[findarg_len] = cc;

  return ret_fname;
}

/// Process the 'findfunc' option value.
/// Returns NULL on success and an error message on failure.
const char *did_set_findfunc(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  int retval;

  if (args->os_flags & OPT_LOCAL) {
    // buffer-local option set
    retval = option_set_callback_func(buf->b_p_ffu, &buf->b_ffu_cb);
  } else {
    // global option set
    retval = option_set_callback_func(p_ffu, &ffu_cb);
    // when using :set, free the local callback
    if (!(args->os_flags & OPT_GLOBAL)) {
      callback_free(&buf->b_ffu_cb);
    }
  }

  if (retval == FAIL) {
    return e_invarg;
  }

  // If the option value starts with <SID> or s:, then replace that with
  // the script identifier.
  char **varp = (char **)args->os_varp;
  char *name = get_scriptlocal_funcname(*varp);
  if (name != NULL) {
    free_string_option(*varp);
    *varp = name;
  }

  return NULL;
}

void free_findfunc_option(void)
{
  callback_free(&ffu_cb);
}

/// Mark the global 'findfunc' callback with "copyID" so that it is not
/// garbage collected.
bool set_ref_in_findfunc(int copyID)
{
  bool abort = false;
  abort = set_ref_in_callback(&ffu_cb, copyID, NULL, NULL);
  return abort;
}

/// :sview [+command] file       split window with new file, read-only
/// :split [[+command] file]     split window with current or new file
/// :vsplit [[+command] file]    split window vertically with current or new file
/// :new [[+command] file]       split window with no or new file
/// :vnew [[+command] file]      split vertically window with no or new file
/// :sfind [+command] file       split window with file in 'path'
///
/// :tabedit                     open new Tab page with empty window
/// :tabedit [+command] file     open new Tab page and edit "file"
/// :tabnew [[+command] file]    just like :tabedit
/// :tabfind [+command] file     open new Tab page and find "file"
void ex_splitview(exarg_T *eap)
{
  win_T *old_curwin = curwin;
  char *fname = NULL;
  const bool use_tab = eap->cmdidx == CMD_tabedit
                       || eap->cmdidx == CMD_tabfind
                       || eap->cmdidx == CMD_tabnew;

  // A ":split" in the quickfix window works like ":new".  Don't want two
  // quickfix windows.  But it's OK when doing ":tab split".
  if (bt_quickfix(curbuf) && cmdmod.cmod_tab == 0) {
    if (eap->cmdidx == CMD_split) {
      eap->cmdidx = CMD_new;
    }
    if (eap->cmdidx == CMD_vsplit) {
      eap->cmdidx = CMD_vnew;
    }
  }

  if (eap->cmdidx == CMD_sfind || eap->cmdidx == CMD_tabfind) {
    if (*get_findfunc() != NUL) {
      fname = findfunc_find_file(eap->arg, strlen(eap->arg),
                                 eap->addr_count > 0 ? eap->line2 : 1);
    } else {
      char *file_to_find = NULL;
      char *search_ctx = NULL;
      fname = find_file_in_path(eap->arg, strlen(eap->arg), FNAME_MESS, true,
                                curbuf->b_ffname, &file_to_find, &search_ctx);
      xfree(file_to_find);
      vim_findfile_cleanup(search_ctx);
    }
    if (fname == NULL) {
      goto theend;
    }
    eap->arg = fname;
  }

  // Either open new tab page or split the window.
  if (use_tab) {
    if (win_new_tabpage(cmdmod.cmod_tab != 0 ? cmdmod.cmod_tab : eap->addr_count == 0
                        ? 0 : (int)eap->line2 + 1, eap->arg) != FAIL) {
      do_exedit(eap, old_curwin);
      apply_autocmds(EVENT_TABNEWENTERED, NULL, NULL, false, curbuf);

      // set the alternate buffer for the window we came from
      if (curwin != old_curwin
          && win_valid(old_curwin)
          && old_curwin->w_buffer != curbuf
          && (cmdmod.cmod_flags & CMOD_KEEPALT) == 0) {
        old_curwin->w_alt_fnum = curbuf->b_fnum;
      }
    }
  } else if (win_split(eap->addr_count > 0 ? (int)eap->line2 : 0,
                       *eap->cmd == 'v' ? WSP_VERT : 0) != FAIL) {
    // Reset 'scrollbind' when editing another file, but keep it when
    // doing ":split" without arguments.
    if (*eap->arg != NUL) {
      RESET_BINDING(curwin);
    } else {
      do_check_scrollbind(false);
    }
    do_exedit(eap, old_curwin);
  }

theend:
  xfree(fname);
}

/// Open a new tab page.
void tabpage_new(void)
{
  exarg_T ea = {
    .cmdidx = CMD_tabnew,
    .cmd = "tabn",
    .arg = "",
  };
  ex_splitview(&ea);
}

/// :tabnext command
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
      char *p = eap->arg;
      char *p_save = p;
      tab_number = (int)getdigits(&p, false, 0);
      if (p == p_save || *p_save == '-' || *p_save == '+' || *p != NUL
          || tab_number == 0) {
        // No numbers as argument.
        eap->errmsg = ex_errmsg(e_invarg2, eap->arg);
        return;
      }
    } else {
      if (eap->addr_count == 0) {
        tab_number = 1;
      } else {
        tab_number = (int)eap->line2;
        if (tab_number < 1) {
          eap->errmsg = _(e_invrange);
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

/// :tabmove command
static void ex_tabmove(exarg_T *eap)
{
  int tab_number = get_tabpage_arg(eap);
  if (eap->errmsg == NULL) {
    tabpage_move(tab_number);
  }
}

/// :tabs command: List tabs and their contents.
static void ex_tabs(exarg_T *eap)
{
  int tabcount = 1;

  msg_start();
  msg_scroll = true;

  win_T *lastused_win = valid_tabpage(lastused_tabpage)
                        ? lastused_tabpage->tp_curwin
                        : NULL;

  FOR_ALL_TABS(tp) {
    if (got_int) {
      break;
    }

    msg_putchar('\n');
    vim_snprintf(IObuff, IOSIZE, _("Tab page %d"), tabcount++);
    msg_outtrans(IObuff, HLF_T, false);
    os_breakcheck();

    FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
      if (got_int) {
        break;
      } else if (!wp->w_config.focusable) {
        continue;
      }

      msg_putchar('\n');
      msg_putchar(wp == curwin ? '>' : wp == lastused_win ? '#' : ' ');
      msg_putchar(' ');
      msg_putchar(bufIsChanged(wp->w_buffer) ? '+' : ' ');
      msg_putchar(' ');
      if (buf_spname(wp->w_buffer) != NULL) {
        xstrlcpy(IObuff, buf_spname(wp->w_buffer), IOSIZE);
      } else {
        home_replace(wp->w_buffer, wp->w_buffer->b_fname, IObuff, IOSIZE, true);
      }
      msg_outtrans(IObuff, 0, false);
      os_breakcheck();
    }
  }
}

/// ":detach"
///
/// Detaches the current UI.
///
/// ":detach!" with bang (!) detaches all UIs _except_ the current UI.
static void ex_detach(exarg_T *eap)
{
  // come on pooky let's burn this mf down
  if (eap && eap->forceit) {
    emsg("bang (!) not supported yet");
  } else {
    // 1. (TODO) Send "detach" UI-event (notification only).
    // 2. Perform server-side `nvim_ui_detach`.
    // 3. Close server-side channel without self-exit.

    if (!current_ui) {
      emsg("UI not attached");
      return;
    }

    Channel *chan = find_channel(current_ui);
    if (!chan) {
      emsg(e_invchan);
      return;
    }
    chan->detach = true;  // Prevent self-exit on channel-close.

    // Server-side UI detach. Doesn't close the channel.
    Error err2 = ERROR_INIT;
    nvim_ui_detach(chan->id, &err2);
    if (ERROR_SET(&err2)) {
      emsg(err2.msg);  // UI disappeared already?
      api_clear_error(&err2);
      return;
    }

    // Server-side channel close.
    const char *err = NULL;
    bool rv = channel_close(chan->id, kChannelPartAll, &err);
    if (!rv && err) {
      emsg(err);  // UI disappeared already?
      return;
    }
    // XXX: Can't do this, channel_decref() is async...
    // assert(!find_channel(chan->id));

    ILOG("detach current_ui=%" PRId64, chan->id);
  }
}

/// ":mode":
/// If no argument given, get the screen size and redraw.
static void ex_mode(exarg_T *eap)
{
  if (*eap->arg == NUL) {
    must_redraw = UPD_CLEAR;
    ex_redraw(eap);
  } else {
    emsg(_(e_screenmode));
  }
}

/// ":resize".
/// set, increment or decrement current window height
static void ex_resize(exarg_T *eap)
{
  win_T *wp = curwin;

  if (eap->addr_count > 0) {
    int n = (int)eap->line2;
    for (wp = firstwin; wp->w_next != NULL && --n > 0; wp = wp->w_next) {}
  }

  int n = (int)atol(eap->arg);
  if (cmdmod.cmod_split & WSP_VERT) {
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
      n = Rows - 1;
    }
    win_setheight_win(n, wp);
  }
}

/// ":find [+command] <file>" command.
static void ex_find(exarg_T *eap)
{
  if (!check_can_set_curbuf_forceit(eap->forceit)) {
    return;
  }

  char *fname = NULL;
  if (*get_findfunc() != NUL) {
    fname = findfunc_find_file(eap->arg, strlen(eap->arg),
                               eap->addr_count > 0 ? eap->line2 : 1);
  } else {
    char *file_to_find = NULL;
    char *search_ctx = NULL;
    fname = find_file_in_path(eap->arg, strlen(eap->arg), FNAME_MESS, true,
                              curbuf->b_ffname, &file_to_find, &search_ctx);
    if (eap->addr_count > 0) {
      // Repeat finding the file "count" times.  This matters when it appears
      // several times in the path.
      linenr_T count = eap->line2;
      while (fname != NULL && --count > 0) {
        xfree(fname);
        fname = find_file_in_path(NULL, 0, FNAME_MESS, false,
                                  curbuf->b_ffname, &file_to_find, &search_ctx);
      }
    }
    xfree(file_to_find);
    vim_findfile_cleanup(search_ctx);
  }

  if (fname == NULL) {
    return;
  }

  eap->arg = fname;
  do_exedit(eap, NULL);
  xfree(fname);
}

/// ":edit", ":badd", ":balt", ":visual".
static void ex_edit(exarg_T *eap)
{
  char *ffname = eap->cmdidx == CMD_enew ? NULL : eap->arg;

  // Exclude commands which keep the window's current buffer
  if (eap->cmdidx != CMD_badd
      && eap->cmdidx != CMD_balt
      // All other commands must obey 'winfixbuf' / ! rules
      && (is_other_file(0, ffname) && !check_can_set_curbuf_forceit(eap->forceit))) {
    return;
  }

  do_exedit(eap, NULL);
}

/// ":edit <file>" command and alike.
///
/// @param old_curwin  curwin before doing a split or NULL
void do_exedit(exarg_T *eap, win_T *old_curwin)
{
  // ":vi" command ends Ex mode.
  if (exmode_active && (eap->cmdidx == CMD_visual
                        || eap->cmdidx == CMD_view)) {
    exmode_active = false;
    ex_pressedreturn = false;
    if (*eap->arg == NUL) {
      // Special case:  ":global/pat/visual\NLvi-commands"
      if (global_busy) {
        if (eap->nextcmd != NULL) {
          stuffReadbuff(eap->nextcmd);
          eap->nextcmd = NULL;
        }

        const int save_rd = RedrawingDisabled;
        RedrawingDisabled = 0;
        const int save_nwr = no_wait_return;
        no_wait_return = 0;
        need_wait_return = false;
        const int save_ms = msg_scroll;
        msg_scroll = 0;
        redraw_all_later(UPD_NOT_VALID);
        pending_exmode_active = true;

        normal_enter(false, true);

        pending_exmode_active = false;
        RedrawingDisabled = save_rd;
        no_wait_return = save_nwr;
        msg_scroll = save_ms;
      }
      return;
    }
  }

  if ((eap->cmdidx == CMD_new
       || eap->cmdidx == CMD_tabnew
       || eap->cmdidx == CMD_tabedit
       || eap->cmdidx == CMD_vnew) && *eap->arg == NUL) {
    // ":new" or ":tabnew" without argument: edit a new empty buffer
    setpcmark();
    do_ecmd(0, NULL, NULL, eap, ECMD_ONE,
            ECMD_HIDE + (eap->forceit ? ECMD_FORCEIT : 0),
            old_curwin == NULL ? curwin : NULL);
  } else if ((eap->cmdidx != CMD_split && eap->cmdidx != CMD_vsplit)
             || *eap->arg != NUL) {
    // Can't edit another file when "textlock" or "curbuf->b_ro_locked" is set.
    // Only ":edit" or ":script" can bring us here, others are stopped earlier.
    if (*eap->arg != NUL && text_or_buf_locked()) {
      return;
    }
    int n = readonlymode;
    if (eap->cmdidx == CMD_view || eap->cmdidx == CMD_sview) {
      readonlymode = true;
    } else if (eap->cmdidx == CMD_enew) {
      readonlymode = false;  // 'readonly' doesn't make sense
                             // in an empty buffer
    }
    if (eap->cmdidx != CMD_balt && eap->cmdidx != CMD_badd) {
      setpcmark();
    }
    if (do_ecmd(0, eap->cmdidx == CMD_enew ? NULL : eap->arg,
                NULL, eap, eap->do_ecmd_lnum,
                (buf_hide(curbuf) ? ECMD_HIDE : 0)
                + (eap->forceit ? ECMD_FORCEIT : 0)
                // After a split we can use an existing buffer.
                + (old_curwin != NULL ? ECMD_OLDBUF : 0)
                + (eap->cmdidx == CMD_badd ? ECMD_ADDBUF : 0)
                + (eap->cmdidx == CMD_balt ? ECMD_ALTBUF : 0),
                old_curwin == NULL ? curwin : NULL) == FAIL) {
      // Editing the file failed.  If the window was split, close it.
      if (old_curwin != NULL) {
        bool need_hide = (curbufIsChanged() && curbuf->b_nwindows <= 1);
        if (!need_hide || buf_hide(curbuf)) {
          cleanup_T cs;

          // Reset the error/interrupt/exception state here so that
          // aborting() returns false when closing a window.
          enter_cleanup(&cs);
          win_close(curwin, !need_hide && !buf_hide(curbuf), false);

          // Restore the error/interrupt/exception state if not
          // discarded by a new aborting error, interrupt, or
          // uncaught exception.
          leave_cleanup(&cs);
        }
      }
    } else if (readonlymode && curbuf->b_nwindows == 1) {
      // When editing an already visited buffer, 'readonly' won't be set
      // but the previous value is kept.  With ":view" and ":sview" we
      // want the  file to be readonly, except when another window is
      // editing the same buffer.
      curbuf->b_p_ro = true;
    }
    readonlymode = n;
  } else {
    if (eap->do_ecmd_cmd != NULL) {
      do_cmdline_cmd(eap->do_ecmd_cmd);
    }
    int n = curwin->w_arg_idx_invalid;
    check_arg_idx(curwin);
    if (n != curwin->w_arg_idx_invalid) {
      maketitle();
    }
  }

  // if ":split file" worked, set alternate file name in old window to new
  // file
  if (old_curwin != NULL
      && *eap->arg != NUL
      && curwin != old_curwin
      && win_valid(old_curwin)
      && old_curwin->w_buffer != curbuf
      && (cmdmod.cmod_flags & CMOD_KEEPALT) == 0) {
    old_curwin->w_alt_fnum = curbuf->b_fnum;
  }

  ex_no_reprint = true;
}

/// ":gui" and ":gvim" when there is no GUI.
static void ex_nogui(exarg_T *eap)
{
  eap->errmsg = _("E25: Nvim does not have a built-in GUI");
}

static void ex_popup(exarg_T *eap)
{
  pum_make_popup(eap->arg, eap->forceit);
}

static void ex_swapname(exarg_T *eap)
{
  if (curbuf->b_ml.ml_mfp == NULL || curbuf->b_ml.ml_mfp->mf_fname == NULL) {
    msg(_("No swap file"), 0);
  } else {
    msg(curbuf->b_ml.ml_mfp->mf_fname, 0);
  }
}

/// ":syncbind" forces all 'scrollbind' windows to have the same relative
/// offset.
/// (1998-11-02 16:21:01  R. Edward Ralston <eralston@computer.org>)
static void ex_syncbind(exarg_T *eap)
{
  linenr_T vtopline;  // Target topline (including fill)

  linenr_T old_linenr = curwin->w_cursor.lnum;

  setpcmark();

  // determine max (virtual) topline
  if (curwin->w_p_scb) {
    vtopline = get_vtopline(curwin);
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_p_scb && wp->w_buffer) {
        linenr_T y = plines_m_win_fill(wp, 1, wp->w_buffer->b_ml.ml_line_count)
                     - get_scrolloff_value(curwin);
        vtopline = MIN(vtopline, y);
      }
    }
    vtopline = MAX(vtopline, 1);
  } else {
    vtopline = 1;
  }

  // Set all scrollbind windows to the same topline.
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_p_scb) {
      int y = vtopline - get_vtopline(wp);
      if (y > 0) {
        scrollup(wp, y, true);
      } else {
        scrolldown(wp, -y, true);
      }
      wp->w_scbind_pos = vtopline;
      redraw_later(wp, UPD_VALID);
      cursor_correct(wp);
      wp->w_redr_status = true;
    }
  }

  if (curwin->w_p_scb) {
    did_syncbind = true;
    checkpcmark();
    if (old_linenr != curwin->w_cursor.lnum) {
      char ctrl_o[2];

      ctrl_o[0] = Ctrl_O;
      ctrl_o[1] = 0;
      ins_typebuf(ctrl_o, REMAP_NONE, 0, true, false);
    }
  }
}

static void ex_read(exarg_T *eap)
{
  int empty = (curbuf->b_ml.ml_flags & ML_EMPTY);

  if (eap->usefilter) {  // :r!cmd
    do_bang(1, eap, false, false, true);
    return;
  }

  if (u_save(eap->line2, (linenr_T)(eap->line2 + 1)) == FAIL) {
    return;
  }

  int i;
  if (*eap->arg == NUL) {
    if (check_fname() == FAIL) {       // check for no file name
      return;
    }
    i = readfile(curbuf->b_ffname, curbuf->b_fname,
                 eap->line2, 0, (linenr_T)MAXLNUM, eap, 0, false);
  } else {
    if (vim_strchr(p_cpo, CPO_ALTREAD) != NULL) {
      setaltfname(eap->arg, eap->arg, 1);
    }
    i = readfile(eap->arg, NULL,
                 eap->line2, 0, (linenr_T)MAXLNUM, eap, 0, false);
  }
  if (i != OK) {
    if (!aborting()) {
      semsg(_(e_notopen), eap->arg);
    }
  } else {
    if (empty && exmode_active) {
      // Delete the empty line that remains.  Historically ex does
      // this but vi doesn't.
      linenr_T lnum;
      if (eap->line2 == 0) {
        lnum = curbuf->b_ml.ml_line_count;
      } else {
        lnum = 1;
      }
      if (*ml_get(lnum) == NUL && u_savedel(lnum, 1) == OK) {
        ml_delete(lnum, false);
        if (curwin->w_cursor.lnum > 1
            && curwin->w_cursor.lnum >= lnum) {
          curwin->w_cursor.lnum--;
        }
        deleted_lines_mark(lnum, 1);
      }
    }
    redraw_curbuf_later(UPD_VALID);
  }
}

static char *prev_dir = NULL;

#if defined(EXITFREE)
void free_cd_dir(void)
{
  XFREE_CLEAR(prev_dir);
  XFREE_CLEAR(globaldir);
}

#endif

/// Get the previous directory for the given chdir scope.
static char *get_prevdir(CdScope scope)
{
  switch (scope) {
  case kCdScopeTabpage:
    return curtab->tp_prevdir;
    break;
  case kCdScopeWindow:
    return curwin->w_prevdir;
    break;
  default:
    return prev_dir;
  }
}

/// Deal with the side effects of changing the current directory.
///
/// @param scope  Scope of the function call (global, tab or window).
static void post_chdir(CdScope scope, bool trigger_dirchanged)
{
  // Always overwrite the window-local CWD.
  XFREE_CLEAR(curwin->w_localdir);

  // Overwrite the tab-local CWD for :cd, :tcd.
  if (scope >= kCdScopeTabpage) {
    XFREE_CLEAR(curtab->tp_localdir);
  }

  if (scope < kCdScopeGlobal) {
    char *pdir = get_prevdir(scope);
    // If still in global directory, set CWD as the global directory.
    if (globaldir == NULL && pdir != NULL) {
      globaldir = xstrdup(pdir);
    }
  }

  char cwd[MAXPATHL];
  if (os_dirname(cwd, MAXPATHL) != OK) {
    return;
  }
  switch (scope) {
  case kCdScopeGlobal:
    // We are now in the global directory, no need to remember its name.
    XFREE_CLEAR(globaldir);
    break;
  case kCdScopeTabpage:
    curtab->tp_localdir = xstrdup(cwd);
    break;
  case kCdScopeWindow:
    curwin->w_localdir = xstrdup(cwd);
    break;
  case kCdScopeInvalid:
    abort();
  }

  last_chdir_reason = NULL;
  shorten_fnames(true);

  if (trigger_dirchanged) {
    do_autocmd_dirchanged(cwd, scope, kCdCauseManual, false);
  }
}

/// Change directory function used by :cd/:tcd/:lcd Ex commands and the chdir() function.
/// @param new_dir  The directory to change to.
/// @param scope    Scope of the function call (global, tab or window).
/// @return true if the directory is successfully changed.
bool changedir_func(char *new_dir, CdScope scope)
{
  if (new_dir == NULL || allbuf_locked()) {
    return false;
  }

  char *pdir = NULL;
  // ":cd -": Change to previous directory
  if (strcmp(new_dir, "-") == 0) {
    pdir = get_prevdir(scope);
    if (pdir == NULL) {
      emsg(_("E186: No previous directory"));
      return false;
    }
    new_dir = pdir;
  }

  if (os_dirname(NameBuff, MAXPATHL) == OK) {
    pdir = xstrdup(NameBuff);
  } else {
    pdir = NULL;
  }

  // For UNIX ":cd" means: go to home directory.
  // On other systems too if 'cdhome' is set.
#if defined(UNIX)
  if (*new_dir == NUL) {
#else
  if (*new_dir == NUL && p_cdh) {
#endif
    // Use NameBuff for home directory name.
    expand_env("$HOME", NameBuff, MAXPATHL);
    new_dir = NameBuff;
  }

  bool dir_differs = pdir == NULL || pathcmp(pdir, new_dir, -1) != 0;
  if (dir_differs) {
    do_autocmd_dirchanged(new_dir, scope, kCdCauseManual, true);
    if (vim_chdir(new_dir) != 0) {
      emsg(_(e_failed));
      xfree(pdir);
      return false;
    }
  }

  char **pp;
  switch (scope) {
  case kCdScopeTabpage:
    pp = &curtab->tp_prevdir;
    break;
  case kCdScopeWindow:
    pp = &curwin->w_prevdir;
    break;
  default:
    pp = &prev_dir;
  }
  xfree(*pp);
  *pp = pdir;

  post_chdir(scope, dir_differs);

  return true;
}

/// ":cd", ":tcd", ":lcd", ":chdir", "tchdir" and ":lchdir".
void ex_cd(exarg_T *eap)
{
  char *new_dir = eap->arg;
#if !defined(UNIX)
  // for non-UNIX ":cd" means: print current directory unless 'cdhome' is set
  if (*new_dir == NUL && !p_cdh) {
    ex_pwd(NULL);
    return;
  }
#endif

  CdScope scope = kCdScopeGlobal;
  switch (eap->cmdidx) {
  case CMD_tcd:
  case CMD_tchdir:
    scope = kCdScopeTabpage;
    break;
  case CMD_lcd:
  case CMD_lchdir:
    scope = kCdScopeWindow;
    break;
  default:
    break;
  }
  if (changedir_func(new_dir, scope)) {
    // Echo the new current directory if the command was typed.
    if (KeyTyped || p_verbose >= 5) {
      ex_pwd(eap);
    }
  }
}

/// ":pwd".
static void ex_pwd(exarg_T *eap)
{
  if (os_dirname(NameBuff, MAXPATHL) == OK) {
#ifdef BACKSLASH_IN_FILENAME
    slash_adjust(NameBuff);
#endif
    if (p_verbose > 0) {
      char *context = "global";
      if (last_chdir_reason != NULL) {
        context = last_chdir_reason;
      } else if (curwin->w_localdir != NULL) {
        context = "window";
      } else if (curtab->tp_localdir != NULL) {
        context = "tabpage";
      }
      smsg(0, "[%s] %s", context, NameBuff);
    } else {
      msg(NameBuff, 0);
    }
  } else {
    emsg(_("E187: Unknown"));
  }
}

/// ":=".
static void ex_equal(exarg_T *eap)
{
  if (*eap->arg != NUL && *eap->arg != '|') {
    // equivalent to :lua= expr
    ex_lua(eap);
  } else {
    eap->nextcmd = find_nextcmd(eap->arg);
    smsg(0, "%" PRId64, (int64_t)eap->line2);
  }
}

static void ex_sleep(exarg_T *eap)
{
  if (cursor_valid(curwin)) {
    setcursor_mayforce(curwin, true);
  }

  int64_t len = eap->line2;
  switch (*eap->arg) {
  case 'm':
    break;
  case NUL:
    len *= 1000; break;
  default:
    semsg(_(e_invarg2), eap->arg); return;
  }

  // Hide the cursor if invoked with !
  do_sleep(len, eap->forceit);
}

/// Sleep for "msec" milliseconds, but return early on CTRL-C.
///
/// @param hide_cursor  hide the cursor if true
void do_sleep(int64_t msec, bool hide_cursor)
{
  if (hide_cursor) {
    ui_busy_start();
  }

  ui_flush();  // flush before waiting
  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, main_loop.events, msec, got_int);

  // If CTRL-C was typed to interrupt the sleep, drop the CTRL-C from the
  // input buffer, otherwise a following call to input() fails.
  if (got_int) {
    vpeekc();
  }

  if (hide_cursor) {
    ui_busy_stop();
  }
}

/// ":winsize" command (obsolete).
static void ex_winsize(exarg_T *eap)
{
  char *arg = eap->arg;

  if (!ascii_isdigit(*arg)) {
    semsg(_(e_invarg2), arg);
    return;
  }
  int w = getdigits_int(&arg, false, 10);
  arg = skipwhite(arg);
  char *p = arg;
  int h = getdigits_int(&arg, false, 10);
  if (*p != NUL && *arg == NUL) {
    screen_resize(w, h);
  } else {
    emsg(_("E465: :winsize requires two number arguments"));
  }
}

static void ex_wincmd(exarg_T *eap)
{
  int xchar = NUL;
  char *p;

  if (*eap->arg == 'g' || *eap->arg == Ctrl_G) {
    // CTRL-W g and CTRL-W CTRL-G  have an extra command character
    if (eap->arg[1] == NUL) {
      emsg(_(e_invarg));
      return;
    }
    xchar = (uint8_t)eap->arg[1];
    p = eap->arg + 2;
  } else {
    p = eap->arg + 1;
  }

  eap->nextcmd = check_nextcmd(p);
  p = skipwhite(p);
  if (*p != NUL && *p != '"' && eap->nextcmd == NULL) {
    emsg(_(e_invarg));
  } else if (!eap->skip) {
    // Pass flags on for ":vertical wincmd ]".
    postponed_split_flags = cmdmod.cmod_split;
    postponed_split_tab = cmdmod.cmod_tab;
    do_window(*eap->arg, eap->addr_count > 0 ? eap->line2 : 0, xchar);
    postponed_split_flags = 0;
    postponed_split_tab = 0;
  }
}

/// Handle command that work like operators: ":delete", ":yank", ":>" and ":<".
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
    op_yank(&oa, true);
    break;

  default:          // CMD_rshift or CMD_lshift
    if (
        (eap->cmdidx == CMD_rshift) ^ curwin->w_p_rl) {
      oa.op_type = OP_RSHIFT;
    } else {
      oa.op_type = OP_LSHIFT;
    }
    op_shift(&oa, false, eap->amount);
    break;
  }
  virtual_op = kNone;
  ex_may_print(eap);
}

/// ":put".
static void ex_put(exarg_T *eap)
{
  // ":0put" works like ":1put!".
  if (eap->line2 == 0) {
    eap->line2 = 1;
    eap->forceit = true;
  }
  curwin->w_cursor.lnum = eap->line2;
  check_cursor_col(curwin);
  do_put(eap->regname, NULL, eap->forceit ? BACKWARD : FORWARD, 1,
         PUT_LINE|PUT_CURSLINE);
}

/// Handle ":copy" and ":move".
static void ex_copymove(exarg_T *eap)
{
  const char *errormsg = NULL;
  linenr_T n = get_address(eap, &eap->arg, eap->addr_type, false, false, false, 1, &errormsg);
  if (eap->arg == NULL) {  // error detected
    if (errormsg != NULL) {
      emsg(errormsg);
    }
    eap->nextcmd = NULL;
    return;
  }
  get_flags(eap);

  // move or copy lines from 'eap->line1'-'eap->line2' to below line 'n'
  if (n == MAXLNUM || n < 0 || n > curbuf->b_ml.ml_line_count) {
    emsg(_(e_invrange));
    return;
  }

  if (eap->cmdidx == CMD_move) {
    if (do_move(eap->line1, eap->line2, n) == FAIL) {
      return;
    }
  } else {
    ex_copy(eap->line1, eap->line2, n);
  }
  u_clearline(curbuf);
  beginline(BL_SOL | BL_FIX);
  ex_may_print(eap);
}

/// Print the current line if flags were given to the Ex command.
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
  const optmagic_T saved = magic_overruled;

  magic_overruled = eap->cmdidx == CMD_smagic ? OPTION_MAGIC_ON : OPTION_MAGIC_OFF;
  ex_substitute(eap);
  magic_overruled = saved;
}

/// ":smagic" and ":snomagic" preview callback.
static int ex_submagic_preview(exarg_T *eap, int cmdpreview_ns, handle_T cmdpreview_bufnr)
{
  const optmagic_T saved = magic_overruled;

  magic_overruled = eap->cmdidx == CMD_smagic ? OPTION_MAGIC_ON : OPTION_MAGIC_OFF;
  int retv = ex_substitute_preview(eap, cmdpreview_ns, cmdpreview_bufnr);
  magic_overruled = saved;

  return retv;
}

/// ":join".
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
    eap->line2++;
  }
  do_join((size_t)((ssize_t)eap->line2 - eap->line1 + 1), !eap->forceit, true, true, true);
  beginline(BL_WHITE | BL_FIX);
  ex_may_print(eap);
}

/// ":[addr]@r": execute register
static void ex_at(exarg_T *eap)
{
  int prev_len = typebuf.tb_len;

  curwin->w_cursor.lnum = eap->line2;
  check_cursor_col(curwin);

  // Get the register name. No name means use the previous one.
  int c = (uint8_t)(*eap->arg);
  if (c == NUL) {
    c = '@';
  }

  // Put the register in the typeahead buffer with the "silent" flag.
  if (do_execreg(c, true, vim_strchr(p_cpo, CPO_EXECBUF) != NULL, true) == FAIL) {
    beep_flush();
    return;
  }

  const bool save_efr = exec_from_reg;

  exec_from_reg = true;

  // Execute from the typeahead buffer.
  // Continue until the stuff buffer is empty and all added characters
  // have been consumed.
  while (!stuff_empty() || typebuf.tb_len > prev_len) {
    do_cmdline(NULL, getexline, NULL, DOCMD_NOWAIT|DOCMD_VERBOSE);
  }

  exec_from_reg = save_efr;
}

/// ":!".
static void ex_bang(exarg_T *eap)
{
  do_bang(eap->addr_count, eap, eap->forceit, true, true);
}

/// ":undo".
static void ex_undo(exarg_T *eap)
{
  if (eap->addr_count != 1) {
    if (eap->forceit) {
      u_undo_and_forget(1, true);   // :undo!
    } else {
      u_undo(1);                    // :undo
    }
    return;
  }

  linenr_T step = eap->line2;

  if (eap->forceit) {             // undo! 123
    // change number for "undo!" must be lesser than current change number
    if (step >= curbuf->b_u_seq_cur) {
      emsg(_(e_undobang_cannot_redo_or_move_branch));
      return;
    }
    // ensure that target change number is in same branch
    // while also counting the amount of undoes it'd take to reach target
    u_header_T *uhp;
    int count = 0;

    for (uhp = curbuf->b_u_curhead ? curbuf->b_u_curhead : curbuf->b_u_newhead;
         uhp != NULL && uhp->uh_seq > step;
         uhp = uhp->uh_next.ptr, ++count) {}
    if (step != 0 && (uhp == NULL || uhp->uh_seq < step)) {
      emsg(_(e_undobang_cannot_redo_or_move_branch));
      return;
    }
    u_undo_and_forget(count, true);
  } else {                        // :undo 123
    undo_time(step, false, false, true);
  }
}

static void ex_wundo(exarg_T *eap)
{
  uint8_t hash[UNDO_HASH_SIZE];

  u_compute_hash(curbuf, hash);
  u_write_undo(eap->arg, eap->forceit, curbuf, hash);
}

static void ex_rundo(exarg_T *eap)
{
  uint8_t hash[UNDO_HASH_SIZE];

  u_compute_hash(curbuf, hash);
  u_read_undo(eap->arg, hash, NULL);
}

/// ":redo".
static void ex_redo(exarg_T *eap)
{
  u_redo(1);
}

/// ":earlier" and ":later".
static void ex_later(exarg_T *eap)
{
  int count = 0;
  bool sec = false;
  bool file = false;
  char *p = eap->arg;

  if (*p == NUL) {
    count = 1;
  } else if (isdigit((uint8_t)(*p))) {
    count = getdigits_int(&p, false, 0);
    switch (*p) {
    case 's':
      p++; sec = true; break;
    case 'm':
      p++; sec = true; count *= 60; break;
    case 'h':
      p++; sec = true; count *= 60 * 60; break;
    case 'd':
      p++; sec = true; count *= 24 * 60 * 60; break;
    case 'f':
      p++; file = true; break;
    }
  }

  if (*p != NUL) {
    semsg(_(e_invarg2), eap->arg);
  } else {
    undo_time(eap->cmdidx == CMD_earlier ? -count : count,
              sec, file, false);
  }
}

/// ":redir": start/stop redirection.
static void ex_redir(exarg_T *eap)
{
  char *arg = eap->arg;

  if (STRICMP(eap->arg, "END") == 0) {
    close_redir();
  } else {
    if (*arg == '>') {
      arg++;
      char *mode;
      if (*arg == '>') {
        arg++;
        mode = "a";
      } else {
        mode = "w";
      }
      arg = skipwhite(arg);

      close_redir();

      // Expand environment variables and "~/".
      char *fname = expand_env_save(arg);
      if (fname == NULL) {
        return;
      }

      redir_fd = open_exfile(fname, eap->forceit, mode);
      xfree(fname);
    } else if (*arg == '@') {
      // redirect to a register a-z (resp. A-Z for appending)
      close_redir();
      arg++;
      if (valid_yank_reg(*arg, true) && *arg != '_') {
        redir_reg = (uint8_t)(*arg++);
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
            write_reg_contents(redir_reg, "", 0, false);
          }
        }
      }
      if (*arg != NUL) {
        redir_reg = 0;
        semsg(_(e_invarg2), eap->arg);
      }
    } else if (*arg == '=' && arg[1] == '>') {
      bool append;

      // redirect to a variable
      close_redir();
      arg += 2;

      if (*arg == '>') {
        arg++;
        append = true;
      } else {
        append = false;
      }

      if (var_redir_start(skipwhite(arg), append) == OK) {
        redir_vname = true;
      }
    } else {  // TODO(vim): redirect to a buffer
      semsg(_(e_invarg2), eap->arg);
    }
  }

  // Make sure redirection is not off.  Can happen for cmdline completion
  // that indirectly invokes a command to catch its output.
  if (redir_fd != NULL
      || redir_reg || redir_vname) {
    redir_off = false;
  }
}

/// ":redraw": force redraw
static void ex_redraw(exarg_T *eap)
{
  if (cmdpreview) {
    return;  // Ignore :redraw during 'inccommand' preview. #9777
  }
  int r = RedrawingDisabled;
  int p = p_lz;

  RedrawingDisabled = 0;
  p_lz = false;
  validate_cursor(curwin);
  update_topline(curwin);
  if (eap->forceit) {
    redraw_all_later(UPD_NOT_VALID);
    redraw_cmdline = true;
  } else if (VIsual_active) {
    redraw_curbuf_later(UPD_INVERTED);
  }
  update_screen();
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

/// ":redrawstatus": force redraw of status line(s) and window bar(s)
static void ex_redrawstatus(exarg_T *eap)
{
  if (cmdpreview) {
    return;  // Ignore :redrawstatus during 'inccommand' preview. #9777
  }
  int r = RedrawingDisabled;
  int p = p_lz;

  if (eap->forceit) {
    status_redraw_all();
  } else {
    status_redraw_curbuf();
  }

  RedrawingDisabled = 0;
  p_lz = false;
  if (State & MODE_CMDLINE) {
    redraw_statuslines();
  } else {
    if (VIsual_active) {
      redraw_curbuf_later(UPD_INVERTED);
    }
    update_screen();
  }
  RedrawingDisabled = r;
  p_lz = p;
  ui_flush();
}

/// ":redrawtabline": force redraw of the tabline
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
    redir_vname = false;
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
    semsg(_(e_mkdir), name, os_strerror(ret));
    return FAIL;
  }
  return OK;
}

/// Open a file for writing for an Ex command, with some checks.
///
/// @param mode  "w" for create new file or "a" for append
///
/// @return  file descriptor, or NULL on failure.
FILE *open_exfile(char *fname, int forceit, char *mode)
{
#ifdef UNIX
  // with Unix it is possible to open a directory
  if (os_isdir(fname)) {
    semsg(_(e_isadir2), fname);
    return NULL;
  }
#endif
  if (!forceit && *mode != 'a' && os_path_exists(fname)) {
    semsg(_("E189: \"%s\" exists (add ! to override)"), fname);
    return NULL;
  }

  FILE *fd;
  if ((fd = os_fopen(fname, mode)) == NULL) {
    semsg(_("E190: Cannot open \"%s\" for writing"), fname);
  }

  return fd;
}

/// ":mark" and ":k".
static void ex_mark(exarg_T *eap)
{
  if (*eap->arg == NUL) {               // No argument?
    emsg(_(e_argreq));
    return;
  }

  if (eap->arg[1] != NUL) {         // more than one character?
    semsg(_(e_trailing_arg), eap->arg);
    return;
  }

  pos_T pos = curwin->w_cursor;             // save curwin->w_cursor
  curwin->w_cursor.lnum = eap->line2;
  beginline(BL_WHITE | BL_FIX);
  if (setmark(*eap->arg) == FAIL) {   // set mark
    emsg(_("E191: Argument must be a letter or forward/backward quote"));
  }
  curwin->w_cursor = pos;             // restore curwin->w_cursor
}

/// Update w_topline, w_leftcol and the cursor position.
void update_topline_cursor(void)
{
  check_cursor(curwin);               // put cursor on valid line
  update_topline(curwin);
  if (!curwin->w_p_wrap) {
    validate_cursor(curwin);
  }
  update_curswant();
}

/// Save the current State and go to Normal mode.
///
/// @return  true if the typeahead could be saved.
bool save_current_state(save_state_T *sst)
  FUNC_ATTR_NONNULL_ALL
{
  sst->save_msg_scroll = msg_scroll;
  sst->save_restart_edit = restart_edit;
  sst->save_msg_didout = msg_didout;
  sst->save_State = State;
  sst->save_finish_op = finish_op;
  sst->save_opcount = opcount;
  sst->save_reg_executing = reg_executing;
  sst->save_pending_end_reg_executing = pending_end_reg_executing;

  msg_scroll = false;   // no msg scrolling in Normal mode
  restart_edit = 0;     // don't go to Insert mode

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
  finish_op = sst->save_finish_op;
  opcount = sst->save_opcount;
  reg_executing = sst->save_reg_executing;
  pending_end_reg_executing = sst->save_pending_end_reg_executing;

  // don't reset msg_didout now
  msg_didout |= sst->save_msg_didout;

  // Restore the state (needed when called from a function executed for
  // 'indentexpr'). Update the mouse and cursor, they may have changed.
  State = sst->save_State;
  ui_cursor_shape();  // may show different cursor shape
}

bool expr_map_locked(void)
{
  return expr_map_lock > 0 && !(curbuf->b_flags & BF_DUMMY);
}

/// ":normal[!] {commands}": Execute normal mode commands.
static void ex_normal(exarg_T *eap)
{
  if (curbuf->terminal && State & MODE_TERMINAL) {
    emsg("Can't re-enter normal mode from terminal mode");
    return;
  }
  char *arg = NULL;

  if (expr_map_locked()) {
    emsg(_(e_secure));
    return;
  }

  if (ex_normal_busy >= p_mmd) {
    emsg(_("E192: Recursive use of :normal too deep"));
    return;
  }

  // vgetc() expects K_SPECIAL to have been escaped.  Don't do
  // this for the K_SPECIAL leading byte, otherwise special keys will not
  // work.
  {
    int len = 0;

    // Count the number of characters to be escaped.
    int l;
    for (char *p = eap->arg; *p != NUL; p++) {
      for (l = utfc_ptr2len(p) - 1; l > 0; l--) {
        if (*++p == (char)K_SPECIAL) {  // trailbyte K_SPECIAL
          len += 2;
        }
      }
    }
    if (len > 0) {
      arg = xmalloc(strlen(eap->arg) + (size_t)len + 1);
      len = 0;
      for (char *p = eap->arg; *p != NUL; p++) {
        arg[len++] = *p;
        for (l = utfc_ptr2len(p) - 1; l > 0; l--) {
          arg[len++] = *++p;
          if (*p == (char)K_SPECIAL) {
            arg[len++] = (char)KS_SPECIAL;
            arg[len++] = KE_FILLER;
          }
        }
        arg[len] = NUL;
      }
    }
  }

  ex_normal_busy++;
  save_state_T save_state;
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

      exec_normal_cmd((arg != NULL ? arg : eap->arg),
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

/// ":startinsert", ":startreplace" and ":startgreplace"
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
  if (State & MODE_INSERT) {
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

/// ":stopinsert"
static void ex_stopinsert(exarg_T *eap)
{
  restart_edit = 0;
  stop_insert_mode = true;
  clearmode();
}

/// Execute normal mode command "cmd".
/// "remap" can be REMAP_NONE or REMAP_YES.
void exec_normal_cmd(char *cmd, int remap, bool silent)
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
  find_pattern_in_path(NULL, 0, 0, false, false, CHECK_PATH, 1,
                       eap->forceit ? ACTION_SHOW_ALL : ACTION_SHOW,
                       1, (linenr_T)MAXLNUM, eap->forceit);
}

/// ":psearch"
static void ex_psearch(exarg_T *eap)
{
  g_do_tagpreview = (int)p_pvh;
  ex_findpat(eap);
  g_do_tagpreview = 0;
}

static void ex_findpat(exarg_T *eap)
{
  bool whole = true;
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

  int n = 1;
  if (ascii_isdigit(*eap->arg)) {  // get count
    n = getdigits_int(&eap->arg, false, 0);
    eap->arg = skipwhite(eap->arg);
  }
  if (*eap->arg == '/') {   // Match regexp, not just whole words
    whole = false;
    eap->arg++;
    char *p = skip_regexp(eap->arg, '/', magic_isset());
    if (*p) {
      *p++ = NUL;
      p = skipwhite(p);

      // Check for trailing illegal characters.
      if (!ends_excmd(*p)) {
        eap->errmsg = ex_errmsg(e_trailing_arg, p);
      } else {
        eap->nextcmd = check_nextcmd(p);
      }
    }
  }
  if (!eap->skip) {
    find_pattern_in_path(eap->arg, 0, strlen(eap->arg), whole, !eap->forceit,
                         *eap->cmd == 'd' ? FIND_DEFINE : FIND_ANY,
                         n, action, eap->line1, eap->line2, eap->forceit);
  }
}

/// ":ptag", ":ptselect", ":ptjump", ":ptnext", etc.
static void ex_ptag(exarg_T *eap)
{
  g_do_tagpreview = (int)p_pvh;    // will be reset to 0 in ex_tag_cmd()
  ex_tag_cmd(eap, cmdnames[eap->cmdidx].cmd_name + 1);
}

/// ":pedit"
static void ex_pedit(exarg_T *eap)
{
  win_T *curwin_save = curwin;
  prepare_preview_window();

  // Edit the file.
  do_exedit(eap, NULL);

  back_to_current_window(curwin_save);
}

/// ":pbuffer"
static void ex_pbuffer(exarg_T *eap)
{
  win_T *curwin_save = curwin;
  prepare_preview_window();

  // Go to the buffer.
  do_exbuffer(eap);

  back_to_current_window(curwin_save);
}

static void prepare_preview_window(void)
{
  // Open the preview window or popup and make it the current window.
  g_do_tagpreview = (int)p_pvh;
  prepare_tagpreview(true);
}

static void back_to_current_window(win_T *curwin_save)
{
  if (curwin != curwin_save && win_valid(curwin_save)) {
    // Return cursor to where we were
    validate_cursor(curwin);
    redraw_later(curwin, UPD_VALID);
    win_enter(curwin_save, true);
  }
  g_do_tagpreview = 0;
}

/// ":stag", ":stselect" and ":stjump".
static void ex_stag(exarg_T *eap)
{
  postponed_split = -1;
  postponed_split_flags = cmdmod.cmod_split;
  postponed_split_tab = cmdmod.cmod_tab;
  ex_tag_cmd(eap, cmdnames[eap->cmdidx].cmd_name + 1);
  postponed_split_flags = 0;
  postponed_split_tab = 0;
}

/// ":tag", ":tselect", ":tjump", ":tnext", etc.
static void ex_tag(exarg_T *eap)
{
  ex_tag_cmd(eap, cmdnames[eap->cmdidx].cmd_name);
}

static void ex_tag_cmd(exarg_T *eap, const char *name)
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
    cmd = DT_TAG;
    break;
  }

  if (name[0] == 'l') {
    cmd = DT_LTAG;
  }

  do_tag(eap->arg, cmd, eap->addr_count > 0 ? (int)eap->line2 : 1,
         eap->forceit, true);
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
  SPEC_SCRIPT,
  SPEC_AFILE,
  SPEC_ABUF,
  SPEC_AMATCH,
  SPEC_SFLNUM,
  SPEC_SID,
  // SPEC_CLIENT,
};

/// Check "str" for starting with a special cmdline variable.
/// If found return one of the SPEC_ values and set "*usedlen" to the length of
/// the variable.  Otherwise return -1 and "*usedlen" is unchanged.
ssize_t find_cmdline_var(const char *src, size_t *usedlen)
  FUNC_ATTR_NONNULL_ALL
{
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
    [SPEC_SCRIPT] = "<script>",         // script file name
    [SPEC_AFILE] = "<afile>",           // autocommand file name
    [SPEC_ABUF] = "<abuf>",             // autocommand buffer number
    [SPEC_AMATCH] = "<amatch>",         // autocommand match name
    [SPEC_SFLNUM] = "<sflnum>",         // script file line number
    [SPEC_SID] = "<SID>",               // script ID: <SNR>123_
    // [SPEC_CLIENT] = "<client>",
  };

  for (size_t i = 0; i < ARRAY_SIZE(spec_str); i++) {
    size_t len = strlen(spec_str[i]);
    if (strncmp(src, spec_str[i], len) == 0) {
      *usedlen = len;
      assert(i <= SSIZE_MAX);
      return (ssize_t)i;
    }
  }
  return -1;
}

/// Evaluate cmdline variables.
///
/// change "%"       to curbuf->b_ffname
///        "#"       to curwin->w_alt_fnum
///        "<cword>" to word under the cursor
///        "<cWORD>" to WORD under the cursor
///        "<cexpr>" to C-expression under the cursor
///        "<cfile>" to path name under the cursor
///        "<sfile>" to sourced file name
///        "<stack>" to call stack
///        "<script>" to current script name
///        "<slnum>" to sourced file line number
///        "<afile>" to file name for autocommand
///        "<abuf>"  to buffer number for autocommand
///        "<amatch>" to matching name for autocommand
///
/// When an error is detected, "errormsg" is set to a non-NULL pointer (may be
/// "" for error without a message) and NULL is returned.
///
/// @param src             pointer into commandline
/// @param srcstart        beginning of valid memory for src
/// @param usedlen         characters after src that are used
/// @param lnump           line number for :e command, or NULL
/// @param errormsg        pointer to error message
/// @param escaped         return value has escaped white space (can be NULL)
/// @param empty_is_error  empty result is considered an error
///
/// @return          an allocated string if a valid match was found.
///                  Returns NULL if no match was found.  "usedlen" then still contains the
///                  number of characters to skip.
char *eval_vars(char *src, const char *srcstart, size_t *usedlen, linenr_T *lnump,
                const char **errormsg, int *escaped, bool empty_is_error)
{
  char *result;
  char *resultbuf = NULL;
  size_t resultlen;
  int valid = VALID_HEAD | VALID_PATH;  // Assume valid result.
  bool tilde_file = false;
  bool skip_mod = false;
  char strbuf[30];

  *errormsg = NULL;
  if (escaped != NULL) {
    *escaped = false;
  }

  // Check if there is something to do.
  ssize_t spec_idx = find_cmdline_var(src, usedlen);
  if (spec_idx < 0) {   // no match
    *usedlen = 1;
    return NULL;
  }

  // Skip when preceded with a backslash "\%" and "\#".
  // Note: In "\\%" the % is also not recognized!
  if (src > srcstart && src[-1] == '\\') {
    *usedlen = 0;
    STRMOVE(src - 1, src);      // remove backslash
    return NULL;
  }

  // word or WORD under cursor
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
      *errormsg = "";
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
        result = "";
        valid = 0;                  // Must have ":p:h" to be valid
      } else {
        result = curbuf->b_fname;
        tilde_file = strcmp(result, "~") == 0;
      }
      break;

    case SPEC_HASH:             // '#' or "#99": alternate file
      if (src[1] == '#') {          // "##": the argument list
        result = arg_all();
        resultbuf = result;
        *usedlen = 2;
        if (escaped != NULL) {
          *escaped = true;
        }
        skip_mod = true;
        break;
      }
      char *s = src + 1;
      if (*s == '<') {                  // "#<99" uses v:oldfiles.
        s++;
      }
      int i = getdigits_int(&s, false, 0);
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
        result = (char *)tv_list_find_str(get_vim_var_list(VV_OLDFILES), i - 1);
        if (result == NULL) {
          *errormsg = "";
          return NULL;
        }
      } else {
        if (i == 0 && src[1] == '<' && *usedlen > 1) {
          *usedlen = 1;
        }
        buf_T *buf = buflist_findnr(i);
        if (buf == NULL) {
          *errormsg = _("E194: No alternate file name to substitute for '#'");
          return NULL;
        }
        if (lnump != NULL) {
          *lnump = ECMD_LAST;
        }
        if (buf->b_fname == NULL) {
          result = "";
          valid = 0;                        // Must have ":p:h" to be valid
        } else {
          result = buf->b_fname;
          tilde_file = strcmp(result, "~") == 0;
        }
      }
      break;

    case SPEC_CFILE:            // file name under cursor
      result = file_name_at_cursor(FNAME_MESS|FNAME_HYP, 1, NULL);
      if (result == NULL) {
        *errormsg = "";
        return NULL;
      }
      resultbuf = result;                   // remember allocated string
      break;

    case SPEC_AFILE:  // file name for autocommand
      if (autocmd_fname != NULL && !autocmd_fname_full) {
        // Still need to turn the fname into a full path.  It was
        // postponed to avoid a delay when <afile> is not used.
        autocmd_fname_full = true;
        result = FullName_save(autocmd_fname, false);
        // Copy into `autocmd_fname`, don't reassign it. #8165
        xstrlcpy(autocmd_fname, result, MAXPATHL);
        xfree(result);
      }
      result = autocmd_fname;
      if (result == NULL) {
        *errormsg = _(e_no_autocommand_file_name_to_substitute_for_afile);
        return NULL;
      }
      result = path_try_shorten_fname(result);
      break;

    case SPEC_ABUF:             // buffer number for autocommand
      if (autocmd_bufnr <= 0) {
        *errormsg = _(e_no_autocommand_buffer_number_to_substitute_for_abuf);
        return NULL;
      }
      snprintf(strbuf, sizeof(strbuf), "%d", autocmd_bufnr);
      result = strbuf;
      break;

    case SPEC_AMATCH:           // match name for autocommand
      result = autocmd_match;
      if (result == NULL) {
        *errormsg = _(e_no_autocommand_match_name_to_substitute_for_amatch);
        return NULL;
      }
      break;

    case SPEC_SFILE:            // file name for ":so" command
      result = estack_sfile(ESTACK_SFILE);
      if (result == NULL) {
        *errormsg = _(e_no_source_file_name_to_substitute_for_sfile);
        return NULL;
      }
      resultbuf = result;  // remember allocated string
      break;
    case SPEC_STACK:            // call stack
      result = estack_sfile(ESTACK_STACK);
      if (result == NULL) {
        *errormsg = _(e_no_call_stack_to_substitute_for_stack);
        return NULL;
      }
      resultbuf = result;  // remember allocated string
      break;
    case SPEC_SCRIPT:           // script file name
      result = estack_sfile(ESTACK_SCRIPT);
      if (result == NULL) {
        *errormsg = _(e_no_script_file_name_to_substitute_for_script);
        return NULL;
      }
      resultbuf = result;  // remember allocated string
      break;

    case SPEC_SLNUM:            // line in file for ":so" command
      if (SOURCING_NAME == NULL || SOURCING_LNUM == 0) {
        *errormsg = _(e_no_line_number_to_use_for_slnum);
        return NULL;
      }
      snprintf(strbuf, sizeof(strbuf), "%" PRIdLINENR, SOURCING_LNUM);
      result = strbuf;
      break;

    case SPEC_SFLNUM:  // line in script file
      if (current_sctx.sc_lnum + SOURCING_LNUM == 0) {
        *errormsg = _(e_no_line_number_to_use_for_sflnum);
        return NULL;
      }
      snprintf(strbuf, sizeof(strbuf), "%" PRIdLINENR,
               current_sctx.sc_lnum + SOURCING_LNUM);
      result = strbuf;
      break;

    case SPEC_SID:
      if (current_sctx.sc_sid <= 0) {
        *errormsg = _(e_usingsid);
        return NULL;
      }
      snprintf(strbuf, sizeof(strbuf), "<SNR>%" PRIdSCID "_", current_sctx.sc_sid);
      result = strbuf;
      break;

    default:
      // should not happen
      *errormsg = "";
      result = "";    // avoid gcc warning
      break;
    }

    // Length of new string.
    resultlen = strlen(result);
    // Remove the file name extension.
    if (src[*usedlen] == '<') {
      (*usedlen)++;
      char *s;
      if ((s = strrchr(result, '.')) != NULL
          && s >= path_tail(result)) {
        resultlen = (size_t)(s - result);
      }
    } else if (!skip_mod) {
      valid |= modify_fname(src, tilde_file, usedlen, &result,
                            &resultbuf, &resultlen);
      if (result == NULL) {
        *errormsg = "";
        return NULL;
      }
    }
  }

  if (resultlen == 0 || valid != VALID_HEAD + VALID_PATH) {
    if (empty_is_error) {
      if (valid != VALID_HEAD + VALID_PATH) {
        // xgettext:no-c-format
        *errormsg = _("E499: Empty file name for '%' or '#', only works with \":p:h\"");
      } else {
        *errormsg = _("E500: Evaluates to an empty string");
      }
    }
    result = NULL;
  } else {
    result = xmemdupz(result, resultlen);
  }
  xfree(resultbuf);
  return result;
}

/// Expand the <sfile> string in "arg".
///
/// @return  an allocated string, or NULL for any error.
char *expand_sfile(char *arg)
{
  char *result = xstrdup(arg);

  for (char *p = result; *p;) {
    if (strncmp(p, "<sfile>", 7) != 0) {
      p++;
    } else {
      // replace "<sfile>" with the sourced file name, and do ":" stuff
      size_t srclen;
      const char *errormsg;
      char *repl = eval_vars(p, result, &srclen, NULL, &errormsg, NULL, true);
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
      size_t len = strlen(result) - srclen + strlen(repl) + 1;
      char *newres = xmalloc(len);
      memmove(newres, result, (size_t)(p - result));
      STRCPY(newres + (p - result), repl);
      len = strlen(newres);
      strcat(newres, p + srclen);
      xfree(repl);
      xfree(result);
      result = newres;
      p = newres + len;                 // continue after the match
    }
  }

  return result;
}

/// ":rshada" and ":wshada".
static void ex_shada(exarg_T *eap)
{
  char *save_shada = p_shada;
  if (*p_shada == NUL) {
    p_shada = "'100";
  }
  if (eap->cmdidx == CMD_rviminfo || eap->cmdidx == CMD_rshada) {
    shada_read_everything(eap->arg, eap->forceit, false);
  } else {
    shada_write_file(eap->arg, eap->forceit);
  }
  p_shada = save_shada;
}

/// Make a dialog message in "buff[DIALOG_MSG_SIZE]".
/// "format" must contain "%s".
void dialog_msg(char *buff, char *format, char *fname)
{
  if (fname == NULL) {
    fname = _("Untitled");
  }
  vim_snprintf(buff, DIALOG_MSG_SIZE, format, fname);
}

static TriState filetype_detect = kNone;
static TriState filetype_plugin = kNone;
static TriState filetype_indent = kNone;

/// ":filetype [plugin] [indent] {on,off,detect}"
/// on: Load the filetype.vim file to install autocommands for file types.
/// off: Load the ftoff.vim file to remove all autocommands for file types.
/// plugin on: load filetype.vim and ftplugin.vim
/// plugin off: load ftplugof.vim
/// indent on: load filetype.vim and indent.vim
/// indent off: load indoff.vim
static void ex_filetype(exarg_T *eap)
{
  if (*eap->arg == NUL) {
    // Print current status.
    smsg(0, "filetype detection:%s  plugin:%s  indent:%s",
         filetype_detect == kTrue ? "ON" : "OFF",
         filetype_plugin == kTrue ? (filetype_detect == kTrue ? "ON" : "(on)") : "OFF",
         filetype_indent == kTrue ? (filetype_detect == kTrue ? "ON" : "(on)") : "OFF");
    return;
  }

  char *arg = eap->arg;
  bool plugin = false;
  bool indent = false;

  // Accept "plugin" and "indent" in any order.
  while (true) {
    if (strncmp(arg, "plugin", 6) == 0) {
      plugin = true;
      arg = skipwhite(arg + 6);
      continue;
    }
    if (strncmp(arg, "indent", 6) == 0) {
      indent = true;
      arg = skipwhite(arg + 6);
      continue;
    }
    break;
  }
  if (strcmp(arg, "on") == 0 || strcmp(arg, "detect") == 0) {
    if (*arg == 'o' || filetype_detect != kTrue) {
      source_runtime(FILETYPE_FILE, DIP_ALL);
      filetype_detect = kTrue;
      if (plugin) {
        source_runtime(FTPLUGIN_FILE, DIP_ALL);
        filetype_plugin = kTrue;
      }
      if (indent) {
        source_runtime(INDENT_FILE, DIP_ALL);
        filetype_indent = kTrue;
      }
    }
    if (*arg == 'd') {
      do_doautocmd("filetypedetect BufRead", true, NULL);
      do_modelines(0);
    }
  } else if (strcmp(arg, "off") == 0) {
    if (plugin || indent) {
      if (plugin) {
        source_runtime(FTPLUGOF_FILE, DIP_ALL);
        filetype_plugin = kFalse;
      }
      if (indent) {
        source_runtime(INDOFF_FILE, DIP_ALL);
        filetype_indent = kFalse;
      }
    } else {
      source_runtime(FTOFF_FILE, DIP_ALL);
      filetype_detect = kFalse;
    }
  } else {
    semsg(_(e_invarg2), arg);
  }
}

/// Source ftplugin.vim and indent.vim to create the necessary FileType
/// autocommands. We do this separately from filetype.vim so that these
/// autocommands will always fire first (and thus can be overridden) while still
/// allowing general filetype detection to be disabled in the user's init file.
void filetype_plugin_enable(void)
{
  if (filetype_plugin == kNone) {
    source_runtime(FTPLUGIN_FILE, DIP_ALL);
    filetype_plugin = kTrue;
  }
  if (filetype_indent == kNone) {
    source_runtime(INDENT_FILE, DIP_ALL);
    filetype_indent = kTrue;
  }
}

/// Enable filetype detection if the user did not explicitly disable it.
void filetype_maybe_enable(void)
{
  if (filetype_detect == kNone) {
    // Normally .vim files are sourced before .lua files when both are
    // supported, but we reverse the order here because we want the Lua
    // autocommand to be defined first so that it runs first
    source_runtime(FILETYPE_FILE, DIP_ALL);
    filetype_detect = kTrue;
  }
}

/// ":setfiletype [FALLBACK] {name}"
static void ex_setfiletype(exarg_T *eap)
{
  if (curbuf->b_did_filetype) {
    return;
  }

  char *arg = eap->arg;
  if (strncmp(arg, "FALLBACK ", 9) == 0) {
    arg += 9;
  }

  set_option_value_give_err(kOptFiletype, CSTR_AS_OPTVAL(arg), OPT_LOCAL);
  if (arg != eap->arg) {
    curbuf->b_did_filetype = false;
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

void set_no_hlsearch(bool flag)
{
  no_hlsearch = flag;
  set_vim_var_nr(VV_HLSEARCH, !no_hlsearch && p_hls);
}

/// ":nohlsearch"
static void ex_nohlsearch(exarg_T *eap)
{
  set_no_hlsearch(true);
  redraw_all_later(UPD_SOME_VALID);
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
  for (linenr_T lnum = eap->line1; lnum <= eap->line2; lnum++) {
    if (hasFolding(curwin, lnum, NULL, NULL) == (eap->cmdidx == CMD_folddoclosed)) {
      ml_setmarked(lnum);
    }
  }

  global_exe(eap->arg);  // Execute the command on the marked lines.
  ml_clearmarked();      // clear rest of the marks
}

/// @return  true if the supplied Ex cmdidx is for a location list command
///          instead of a quickfix command.
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

/// ":checkhealth [plugins]"
static void ex_checkhealth(exarg_T *eap)
{
  Error err = ERROR_INIT;
  MAXSIZE_TEMP_ARRAY(args, 2);

  char mods[1024];
  size_t mods_len = 0;
  mods[0] = NUL;

  if (cmdmod.cmod_tab > 0 || cmdmod.cmod_split != 0) {
    bool multi_mods = false;
    mods_len = add_win_cmd_modifiers(mods, &cmdmod, &multi_mods);
    assert(mods_len < sizeof(mods));
  }
  ADD_C(args, STRING_OBJ(((String){ .data = mods, .size = mods_len })));
  ADD_C(args, CSTR_AS_OBJ(eap->arg));

  NLUA_EXEC_STATIC("vim.health._check(...)", args, kRetNilBool, NULL, &err);
  if (!ERROR_SET(&err)) {
    return;
  }

  const char *vimruntime_env = os_getenv("VIMRUNTIME");
  if (vimruntime_env == NULL) {
    emsg(_("E5009: $VIMRUNTIME is empty or unset"));
  } else {
    bool rtp_ok = NULL != strstr(p_rtp, vimruntime_env);
    if (rtp_ok) {
      semsg(_("E5009: Invalid $VIMRUNTIME: %s"), vimruntime_env);
    } else {
      emsg(_("E5009: Invalid 'runtimepath'"));
    }
  }
  semsg_multiline("emsg", err.msg);
  api_clear_error(&err);
}

static void ex_terminal(exarg_T *eap)
{
  char ex_cmd[1024];
  size_t len = 0;

  if (cmdmod.cmod_tab > 0 || cmdmod.cmod_split != 0) {
    bool multi_mods = false;
    // ex_cmd must be a null-terminated string before passing to add_win_cmd_modifiers
    ex_cmd[0] = NUL;
    len = add_win_cmd_modifiers(ex_cmd, &cmdmod, &multi_mods);
    assert(len < sizeof(ex_cmd));
    int result = snprintf(ex_cmd + len, sizeof(ex_cmd) - len, " new");
    assert(result > 0);
    len += (size_t)result;
  } else {
    int result = snprintf(ex_cmd, sizeof(ex_cmd), "enew%s", eap->forceit ? "!" : "");
    assert(result > 0);
    len += (size_t)result;
  }

  assert(len < sizeof(ex_cmd));

  if (*eap->arg != NUL) {  // Run {cmd} in 'shell'.
    char *name = vim_strsave_escaped(eap->arg, "\"\\");
    snprintf(ex_cmd + len, sizeof(ex_cmd) - len,
             " | call jobstart(\"%s\",{'term':v:true})", name);
    xfree(name);
  } else {  // No {cmd}: run the job with tokenized 'shell'.
    if (*p_sh == NUL) {
      emsg(_(e_shellempty));
      return;
    }

    char **argv = shell_build_argv(NULL, NULL);
    char **p = argv;
    char tempstring[512];
    char shell_argv[512] = { 0 };

    while (*p != NULL) {
      char *escaped = vim_strsave_escaped(*p, "\"\\");
      snprintf(tempstring, sizeof(tempstring), ",\"%s\"", escaped);
      xfree(escaped);
      xstrlcat(shell_argv, tempstring, sizeof(shell_argv));
      p++;
    }
    shell_free_argv(argv);

    snprintf(ex_cmd + len, sizeof(ex_cmd) - len,
             " | call jobstart([%s], {'term':v:true})", shell_argv + 1);
  }

  do_cmdline_cmd(ex_cmd);
}

/// ":fclose"
static void ex_fclose(exarg_T *eap)
{
  win_float_remove(eap->forceit, eap->line1);
}

void verify_command(char *cmd)
{
  if (strcmp("smile", cmd) != 0) {
    return;  // acceptable non-existing command
  }
  int a = HLF_E;
  msg(" #xxn`          #xnxx`        ,+x@##@Mz;`        .xxx"
      "xxxxxxnz+,      znnnnnnnnnnnnnnnn.", a);
  msg(" n###z          x####`      :x##########W+`      ,###"
      "##########M;    W################.", a);
  msg(" n####;         x####`    `z##############W:     ,###"
      "#############   W################.", a);
  msg(" n####W.        x####`   ,W#################+    ,###"
      "##############  W################.", a);
  msg(" n#####n        x####`   @###################    ,###"
      "##############i W################.", a);
  msg(" n######i       x####`  .#########@W@########*   ,###"
      "##############W`W################.", a);
  msg(" n######@.      x####`  x######W*.  `;n#######:  ,###"
      "#x,,,,:*M######iW###@:,,,,,,,,,,,`", a);
  msg(" n#######n      x####` *######+`       :M#####M  ,###"
      "#n      `x#####xW###@`", a);
  msg(" n########*     x####``@####@;          `x#####i ,###"
      "#n       ,#####@W###@`", a);
  msg(" n########@     x####`*#####i            `M####M ,###"
      "#n        x#########@`", a);
  msg(" n#########     x####`M####z              :#####:,###"
      "#n        z#########@`", a);
  msg(" n#########*    x####,#####.               n####+,###"
      "#n        n#########@`", a);
  msg(" n####@####@,   x####i####x                ;####x,###"
      "#n       `W#####@####+++++++++++i", a);
  msg(" n####*#####M`  x#########*                `####@,###"
      "#n       i#####MW###############W", a);
  msg(" n####.######+  x####z####;                 W####,###"
      "#n      i@######W###############W", a);
  msg(" n####.`W#####: x####n####:                 M####:###"
      "#@nnnnnW#######,W###############W", a);
  msg(" n####. :#####M`x####z####;                 W####,###"
      "##############z W###############W", a);
  msg(" n####.  #######x#########*                `####W,###"
      "#############W` W###############W", a);
  msg(" n####.  `M#####W####i####x                ;####x,###"
      "############W,  W####+**********i", a);
  msg(" n####.   ,##########,#####.               n####+,###"
      "###########n.   W###@`", a);
  msg(" n####.    ##########`M####z              :#####:,###"
      "########Wz:     W###@`", a);
  msg(" n####.    x#########`*#####i            `M####M ,###"
      "#x.....`        W###@`", a);
  msg(" n####.    ,@########``@####@;          `x#####i ,###"
      "#n              W###@`", a);
  msg(" n####.     *########` *#####@+`       ,M#####M  ,###"
      "#n              W###@`", a);
  msg(" n####.      x#######`  x######W*.  `;n######@:  ,###"
      "#n              W###@,,,,,,,,,,,,`", a);
  msg(" n####.      .@######`  .#########@W@########*   ,###"
      "#n              W################,", a);
  msg(" n####.       i######`   @###################    ,###"
      "#n              W################,", a);
  msg(" n####.        n#####`   ,W#################+    ,###"
      "#n              W################,", a);
  msg(" n####.        .@####`    .n##############W;     ,###"
      "#n              W################,", a);
  msg(" n####.         i####`      :x##########W+`      ,###"
      "#n              W################,", a);
  msg(" +nnnn`          +nnn`        ,+x@##@Mz;`        .nnn"
      "n+              zxxxxxxxxxxxxxxxx.", a);
  msg(" ", a);
  msg("                                                     "
      "                              ,+M@#Mi", a);
  msg("                                 "
      "                                                .z########", a);
  msg("                                 "
      "                                               i@#########i", a);
  msg("                                 "
      "                                             `############W`", a);
  msg("                                 "
      "                                            `n#############i", a);
  msg("                                 "
      "                                           `n##############n", a);
  msg("     ``                          "
      "                                           z###############@`", a);
  msg("    `W@z,                        "
      "                                          ##################,", a);
  msg("    *#####`                      "
      "                                         i############@x@###i", a);
  msg("    ######M.                     "
      "                                        :#############n`,W##+", a);
  msg("    +######@:                    "
      "                                       .W#########M@##+  *##z", a);
  msg("    :#######@:                   "
      "                                      `x########@#x###*  ,##n", a);
  msg("    `@#######@;                  "
      "                                      z#########M*@nW#i  .##x", a);
  msg("     z########@i                 "
      "                                     *###########WM#@#,  `##x", a);
  msg("     i##########+                "
      "                                    ;###########*n###@   `##x", a);
  msg("     `@#MM#######x,              "
      "                                   ,@#########zM,`z##M   `@#x", a);
  msg("      n##M#W#######n.            "
      "   `.:i*+#zzzz##+i:.`             ,W#########Wii,`n@#@` n@##n", a);
  msg("      ;###@#x#######n         `,i"
      "#nW@#####@@WWW@@####@Mzi.        ,W##########@z.. ;zM#+i####z", a);
  msg("       x####nz########    .;#x@##"
      "@Wn#*;,.`      ``,:*#x@##M+,    ;@########xz@WM+#` `n@#######", a);
  msg("       ,@####M########xi#@##@Mzi,"
      "`                     .+x###Mi:n##########Mz```.:i  *@######*", a);
  msg("        *#####W#########ix+:`    "
      "                         :n#############z:       `*.`M######i", a);
  msg("        i#W##nW@+@##@#M@;        "
      "                           ;W@@##########W,        i`x@#####,", a);
  msg("        `@@n@Wn#@iMW*#*:         "
      "                            `iz#z@######x.           M######`", a);
  msg("         z##zM###x`*, .`         "
      "                                 `iW#####W;:`        +#####M", a);
  msg("         ,###nn##n`              "
      "                                  ,#####x;`        ,;@######", a);
  msg("          x###xz#.               "
      "                                    in###+        `:######@.", a);
  msg("          ;####n+                "
      "                                    `Mnx##xi`   , zM#######", a);
  msg("          `W####+                "
      "i.                                   `.+x###@#. :n,z######:", a);
  msg("           z####@`              ;"
      "#:                                     .ii@###@;.*M*z####@`", a);
  msg("           i####M         `   `i@"
      "#,           ::                           +#n##@+@##W####n", a);
  msg("           :####x    ,i. ##xzM###"
      "@`     i.   .@@,                           .z####x#######*", a);
  msg("           ,###W;   i##Wz########"
      "#     :##   z##n                           ,@########x###:", a);
  msg("            n##n   `W###########M"
      "`;n,  i#x  ,###@i                           *W########W#@`", a);
  msg("           .@##+  `x###########@."
      " z#+ .M#W``x#####n`                         `;#######@z#x", a);
  msg("           n###z :W############@ "
      " z#*  @##xM#######@n;                        `########nW+", a);
  msg("          ;####nW##############W "
      ":@#* `@#############*                        :########z@i`", a);
  msg("          M##################### "
      "M##:  @#############@:                       *W########M#", a);
  msg("         ;#####################i."
      "##x`  W#############W,                       :n########zx", a);
  msg("         x####################@.`"
      "x;    @#############z.                       .@########W#", a);
  msg("        ,######################` "
      "      W###############x*,`                    W######zM#i", a);
  msg("        #######################: "
      "      z##################@x+*#zzi            `@#########.", a);
  msg("        W########W#z#M#########; "
      "      *##########################z            :@#######@`", a);
  msg("       `@#######x`;#z ,x#######; "
      "      z###########M###xnM@########*            :M######@", a);
  msg("       i########, x#@`  z######; "
      "      *##########i *#@`  `+########+`            n######.", a);
  msg("       n#######@` M##,  `W#####. "
      "      *#########z  ###;    z########M:           :W####n", a);
  msg("       M#######M  n##.   x####x  "
      "      `x########:  z##+    M#########@;           .n###+", a);
  msg("       W#######@` :#W   `@####:  "
      "       `@######W   i###   ;###########@.            n##n", a);
  msg("       W########z` ,,  .x####z   "
      "        @######@`  `W#;  `W############*            *###;", a);
  msg("      `@#########Mi,:*n@####W`   "
      "        W#######*   ..  `n#############i            i###x", a);
  msg("      .#####################z    "
      "       `@#######@*`    .x############n:`            ;####.", a);
  msg("      :####################x`,,` "
      "       `W#########@x#+#@#############i              ,####:", a);
  msg("      ;###################x#@###x"
      "i`      *############################:              `####i", a);
  msg("      i##################+#######"
      "#M,      x##########################@`               W###i", a);
  msg("      *################@; @######"
      "##@,     .W#########################@                x###:", a);
  msg("      .+M#############z.  M######"
      "###x      ,W########################@`               ####.", a);
  msg("      *M*;z@########x:    :W#####"
      "##i        .M########################i               i###:", a);
  msg("      *##@z;#@####x:        :z###"
      "@i          `########################x               .###;", a);
  msg("      *#####n;#@##            ;##"
      "*             ,x#####################@`               W##*", a);
  msg("      *#######n;*            :M##"
      "W*,             *W####################`               n##z", a);
  msg("      i########@.         ,*n####"
      "###M*`           `###################M                *##M", a);
  msg("      i########n        `z#####@@"
      "#####Wi            ,M################;                ,##@`", a);
  msg("      ;WMWW@###*       .x##@ni.``"
      ".:+zW##z`           `n##############z                  @##,", a);
  msg("      .*++*i;;;.      .M#@+`     "
      "     .##n            `x############x`                  n##i", a);
  msg("      :########*      x#W,       "
      "       *#+            *###########M`                   +##+", a);
  msg("      ,#########     :#@:        "
      "        ##:           #nzzzzzzzzzz.                    :##x", a);
  msg("      .#####Wz+`     ##+         "
      "        `MM`          .znnnnnnnnn.                     `@#@`", a);
  msg("      `@@ni;*nMz`    @W`         "
      "         :#+           .x#######n                       x##,", a);
  msg("       i;z@#####,   .#*          "
      "          z#:           ;;;*zW##;                       ###i", a);
  msg("       z########:   :#;          "
      "          `Wx          +###Wni;n.                       ;##z", a);
  msg("       n########W:  .#*          "
      "           ,#,        ;#######@+                        `@#M", a);
  msg("      .###########n;.MM          "
      "            n*        ;iM#######*                        x#@`", a);
  msg("      :#############@;;          "
      "            .n`      ,#W*iW#####W`                       +##,", a);
  msg("      ,##############.           "
      "             ix.    `x###M;#######                       ,##i", a);
  msg("      .#############@`           "
      "              x@n**#W######z;M###@.                       W##", a);
  msg("      .##############W:          "
      "              .x############@*;zW#;                       z#x", a);
  msg("      ,###############@;         "
      "               `##############@n*;.                       i#@", a);
  msg("      ,#################i        "
      "                 :n##############W`                       .##,", a);
  msg("      ,###################`      "
      "                   .+W##########W,                        `##i", a);
  msg("      :###################@zi,`  "
      "                      ;zM@@@WMn*`                          @#z", a);
  msg("      :#######################@x+"
      "*i;;:i#M,                 ``                               M#W", a);
  msg("      ;##########################"
      "######@x.                                                  n##,", a);
  msg("      i#####################@W@@@"
      "@Wxz*:`                                                    *##+", a);
  msg("      *######################+```"
      "                                                           :##M", a);
  msg("      ########################M; "
      "                                                           `@##,", a);
  msg("      z#########################x"
      ",                                                           z###", a);
  msg("      n##########################"
      "#n:                                                         ;##W`", a);
  msg("      x##########################"
      "###Mz#++##*                                                 `W##i", a);
  msg("      M##########################"
      "##########@`                                                 ###x", a);
  msg("      W##########################"
      "###########`                                                 .###,", a);
  msg("      @##########################"
      "##########M                                                   n##z", a);
  msg("      @##################z*i@WMMM"
      "x#x@#####,.                                                   :##@.", a);
  msg("     `#####################@xi`  "
      "   `::,*                                                       x##+", a);
  msg("     .#####################@#M.  "
      "                                                               ;##@`", a);
  msg("     ,#####################:.    "
      "                                                                M##i", a);
  msg("     ;###################ni`     "
      "                                                                i##M", a);
  msg("     *#################W#`       "
      "                                                                `W##,", a);
  msg("     z#################@Wx+.     "
      "                                                                 +###", a);
  msg("     x######################z.   "
      "                                                                 .@#@`", a);
  msg("    `@#######################@;  "
      "                                                                  z##;", a);
  msg("    :##########################: "
      "                                                                  :##z", a);
  msg("    +#########################W# "
      "                                                                   M#W", a);
  msg("    W################@n+*i;:,`                                "
      "                                      +##,", a);
  msg("   :##################WMxz+,                                  "
      "                                      ,##i", a);
  msg("   n#######################W..,                               "
      "                                       W##", a);
  msg("  +#########################WW@+. .:.                         "
      "                                       z#x", a);
  msg(" `@#############################@@###:                        "
      "                                       *#W", a);
  msg(" #################################Wz:                         "
      "                                       :#@", a);
  msg(",@###############################i                            "
      "                                       .##", a);
  msg("n@@@@@@@#########################+                            "
      "                                       `##", a);
  msg("`      `.:.`.,:iii;;;;;;;;iii;;;:`       `.``                 "
      "                                       `nW", a);
}

/// Get argt of command with id
uint32_t get_cmd_argt(cmdidx_T cmdidx)
{
  return cmdnames[(int)cmdidx].cmd_argt;
}
