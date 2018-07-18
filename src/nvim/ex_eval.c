// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// TODO(ZyX-I): move to eval/executor

/// @file ex_eval.c
///
/// Functions for Ex command line for the +eval feature.
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/ex_eval.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/message.h"
#include "nvim/memory.h"
#include "nvim/regexp.h"
#include "nvim/strings.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_eval.c.generated.h"
#endif

// Exception handling terms:
//
//      :try            ":try" command         ─┐
//          ...         try block               │
//      :catch RE       ":catch" command        │
//          ...         catch clause            ├─ try conditional
//      :finally        ":finally" command      │
//          ...         finally clause          │
//      :endtry         ":endtry" command      ─┘
//
// The try conditional may have any number of catch clauses and at most one
// finally clause.  A ":throw" command can be inside the try block, a catch
// clause, the finally clause, or in a function called or script sourced from
// there or even outside the try conditional.  Try conditionals may be nested.

// Configuration whether an exception is thrown on error or interrupt.  When
// the preprocessor macros below evaluate to FALSE, an error (did_emsg) or
// interrupt (got_int) under an active try conditional terminates the script
// after the non-active finally clauses of all active try conditionals have been
// executed.  Otherwise, errors and/or interrupts are converted into catchable
// exceptions, which terminate the script only if not caught.  For user
// exceptions, only current_exception is set.  (Note: got_int can be set
// asynchronously afterwards by a SIGINT, so current_exception && got_int is not
// a reliant test that the exception currently being thrown is an interrupt
// exception.  Similarly, did_emsg can be set afterwards on an error in an
// (unskipped) conditional command inside an inactive conditional, so
// current_exception && did_emsg is not a reliant test that the exception
// currently being thrown is an error exception.)  -  The macros can be defined
// as expressions checking for a variable that is allowed to be changed during
// execution of a script.

// Values used for the Vim release.
#define THROW_ON_ERROR true
#define THROW_ON_ERROR_TRUE
#define THROW_ON_INTERRUPT true
#define THROW_ON_INTERRUPT_TRUE

// Don't do something after an error, interrupt, or throw, or when
// there is a surrounding conditional and it was not active.
#define CHECK_SKIP \
  (did_emsg \
   || got_int \
   || current_exception \
   || (cstack->cs_idx > 0 \
       && !(cstack->cs_flags[cstack->cs_idx - 1] & CSF_ACTIVE)))

#define discard_pending_return(p) tv_free((typval_T *)(p))

/*
 * When several errors appear in a row, setting "force_abort" is delayed until
 * the failing command returned.  "cause_abort" is set to TRUE meanwhile, in
 * order to indicate that situation.  This is useful when "force_abort" was set
 * during execution of a function call from an expression: the aborting of the
 * expression evaluation is done without producing any error messages, but all
 * error messages on parsing errors during the expression evaluation are given
 * (even if a try conditional is active).
 */
static int cause_abort = FALSE;

/*
 * Return TRUE when immediately aborting on error, or when an interrupt
 * occurred or an exception was thrown but not caught.  Use for ":{range}call"
 * to check whether an aborted function that does not handle a range itself
 * should be called again for the next line in the range.  Also used for
 * cancelling expression evaluation after a function call caused an immediate
 * abort.  Note that the first emsg() call temporarily resets "force_abort"
 * until the throw point for error messages has been reached.  That is, during
 * cancellation of an expression evaluation after an aborting function call or
 * due to a parsing error, aborting() always returns the same value.
 */
int aborting(void)
{
  return (did_emsg && force_abort) || got_int || current_exception;
}

/*
 * The value of "force_abort" is temporarily reset by the first emsg() call
 * during an expression evaluation, and "cause_abort" is used instead.  It might
 * be necessary to restore "force_abort" even before the throw point for the
 * error message has been reached.  update_force_abort() should be called then.
 */
void update_force_abort(void)
{
  if (cause_abort)
    force_abort = TRUE;
}

/*
 * Return TRUE if a command with a subcommand resulting in "retcode" should
 * abort the script processing.  Can be used to suppress an autocommand after
 * execution of a failing subcommand as long as the error message has not been
 * displayed and actually caused the abortion.
 */
int should_abort(int retcode)
{
  return (retcode == FAIL && trylevel != 0 && !emsg_silent) || aborting();
}

/*
 * Return TRUE if a function with the "abort" flag should not be considered
 * ended on an error.  This means that parsing commands is continued in order
 * to find finally clauses to be executed, and that some errors in skipped
 * commands are still reported.
 */
int aborted_in_try(void)
{
  /* This function is only called after an error.  In this case, "force_abort"
   * determines whether searching for finally clauses is necessary. */
  return force_abort;
}

/*
 * cause_errthrow(): Cause a throw of an error exception if appropriate.
 * Return TRUE if the error message should not be displayed by emsg().
 * Sets "ignore", if the emsg() call should be ignored completely.
 *
 * When several messages appear in the same command, the first is usually the
 * most specific one and used as the exception value.  The "severe" flag can be
 * set to TRUE, if a later but severer message should be used instead.
 */
int cause_errthrow(char_u *mesg, int severe, int *ignore)
{
  struct msglist *elem;
  struct msglist **plist;

  /*
   * Do nothing when displaying the interrupt message or reporting an
   * uncaught exception (which has already been discarded then) at the top
   * level.  Also when no exception can be thrown.  The message will be
   * displayed by emsg().
   */
  if (suppress_errthrow)
    return FALSE;

  /*
   * If emsg() has not been called previously, temporarily reset
   * "force_abort" until the throw point for error messages has been
   * reached.  This ensures that aborting() returns the same value for all
   * errors that appear in the same command.  This means particularly that
   * for parsing errors during expression evaluation emsg() will be called
   * multiply, even when the expression is evaluated from a finally clause
   * that was activated due to an aborting error, interrupt, or exception.
   */
  if (!did_emsg) {
    cause_abort = force_abort;
    force_abort = FALSE;
  }

  /*
   * If no try conditional is active and no exception is being thrown and
   * there has not been an error in a try conditional or a throw so far, do
   * nothing (for compatibility of non-EH scripts).  The message will then
   * be displayed by emsg().  When ":silent!" was used and we are not
   * currently throwing an exception, do nothing.  The message text will
   * then be stored to v:errmsg by emsg() without displaying it.
   */
  if (((trylevel == 0 && !cause_abort) || emsg_silent) && !current_exception) {
    return false;
  }

  /*
   * Ignore an interrupt message when inside a try conditional or when an
   * exception is being thrown or when an error in a try conditional or
   * throw has been detected previously.  This is important in order that an
   * interrupt exception is catchable by the innermost try conditional and
   * not replaced by an interrupt message error exception.
   */
  if (mesg == (char_u *)_(e_interr)) {
    *ignore = TRUE;
    return TRUE;
  }

  /*
   * Ensure that all commands in nested function calls and sourced files
   * are aborted immediately.
   */
  cause_abort = TRUE;

  /*
   * When an exception is being thrown, some commands (like conditionals) are
   * not skipped.  Errors in those commands may affect what of the subsequent
   * commands are regarded part of catch and finally clauses.  Catching the
   * exception would then cause execution of commands not intended by the
   * user, who wouldn't even get aware of the problem.  Therefor, discard the
   * exception currently being thrown to prevent it from being caught.  Just
   * execute finally clauses and terminate.
   */
  if (current_exception) {
    // When discarding an interrupt exception, reset got_int to prevent the
    // same interrupt being converted to an exception again and discarding
    // the error exception we are about to throw here.
    if (current_exception->type == ET_INTERRUPT) {
      got_int = false;
    }
    discard_current_exception();
  }

#ifdef THROW_TEST
  if (!THROW_ON_ERROR) {
    /*
     * Print error message immediately without searching for a matching
     * catch clause; just finally clauses are executed before the script
     * is terminated.
     */
    return FALSE;
  } else
#endif
  {
    /*
     * Prepare the throw of an error exception, so that everything will
     * be aborted (except for executing finally clauses), until the error
     * exception is caught; if still uncaught at the top level, the error
     * message will be displayed and the script processing terminated
     * then.  -  This function has no access to the conditional stack.
     * Thus, the actual throw is made after the failing command has
     * returned.  -  Throw only the first of several errors in a row, except
     * a severe error is following.
     */
    if (msg_list != NULL) {
      plist = msg_list;
      while (*plist != NULL)
        plist = &(*plist)->next;

      elem = xmalloc(sizeof(struct msglist));
      elem->msg = vim_strsave(mesg);
      elem->next = NULL;
      elem->throw_msg = NULL;
      *plist = elem;
      if (plist == msg_list || severe) {
        char_u      *tmsg;

        /* Skip the extra "Vim " prefix for message "E458". */
        tmsg = elem->msg;
        if (STRNCMP(tmsg, "Vim E", 5) == 0
            && ascii_isdigit(tmsg[5])
            && ascii_isdigit(tmsg[6])
            && ascii_isdigit(tmsg[7])
            && tmsg[8] == ':'
            && tmsg[9] == ' ')
          (*msg_list)->throw_msg = &tmsg[4];
        else
          (*msg_list)->throw_msg = tmsg;
      }
    }
    return TRUE;
  }
}

/*
 * Free a "msg_list" and the messages it contains.
 */
static void free_msglist(struct msglist *l)
{
  struct msglist  *messages, *next;

  messages = l;
  while (messages != NULL) {
    next = messages->next;
    xfree(messages->msg);
    xfree(messages);
    messages = next;
  }
}

/*
 * Free global "*msg_list" and the messages it contains, then set "*msg_list"
 * to NULL.
 */
void free_global_msglist(void)
{
  free_msglist(*msg_list);
  *msg_list = NULL;
}

/*
 * Throw the message specified in the call to cause_errthrow() above as an
 * error exception.  If cstack is NULL, postpone the throw until do_cmdline()
 * has returned (see do_one_cmd()).
 */
void do_errthrow(struct condstack *cstack, char_u *cmdname)
{
  /*
   * Ensure that all commands in nested function calls and sourced files
   * are aborted immediately.
   */
  if (cause_abort) {
    cause_abort = FALSE;
    force_abort = TRUE;
  }

  /* If no exception is to be thrown or the conversion should be done after
   * returning to a previous invocation of do_one_cmd(), do nothing. */
  if (msg_list == NULL || *msg_list == NULL)
    return;

  if (throw_exception(*msg_list, ET_ERROR, cmdname) == FAIL)
    free_msglist(*msg_list);
  else {
    if (cstack != NULL)
      do_throw(cstack);
    else
      need_rethrow = TRUE;
  }
  *msg_list = NULL;
}

/*
 * do_intthrow(): Replace the current exception by an interrupt or interrupt
 * exception if appropriate.  Return TRUE if the current exception is discarded,
 * FALSE otherwise.
 */
int do_intthrow(struct condstack *cstack)
{
  // If no interrupt occurred or no try conditional is active and no exception
  // is being thrown, do nothing (for compatibility of non-EH scripts).
  if (!got_int || (trylevel == 0 && !current_exception)) {
    return false;
  }

#ifdef THROW_TEST  // avoid warning for condition always true
  if (!THROW_ON_INTERRUPT) {
    // The interrupt aborts everything except for executing finally clauses.
    // Discard any user or error or interrupt exception currently being
    // thrown.
    if (current_exception) {
      discard_current_exception();
    }
  } else {
#endif
    // Throw an interrupt exception, so that everything will be aborted
    // (except for executing finally clauses), until the interrupt exception
    // is caught; if still uncaught at the top level, the script processing
    // will be terminated then.  -  If an interrupt exception is already
    // being thrown, do nothing.

    if (current_exception) {
      if (current_exception->type == ET_INTERRUPT) {
        return false;
      }

      // An interrupt exception replaces any user or error exception.
      discard_current_exception();
    }
    if (throw_exception("Vim:Interrupt", ET_INTERRUPT, NULL) != FAIL) {
      do_throw(cstack);
    }
#ifdef THROW_TEST
  }
#endif

  return true;
}

// Get an exception message that is to be stored in current_exception->value.
char_u *get_exception_string(void *value, except_type_T type, char_u *cmdname,
                             int *should_free)
{
  char_u      *ret, *mesg;
  char_u      *p, *val;

  if (type == ET_ERROR) {
    *should_free = true;
    mesg = ((struct msglist *)value)->throw_msg;
    if (cmdname != NULL && *cmdname != NUL) {
      size_t cmdlen = STRLEN(cmdname);
      ret = vim_strnsave((char_u *)"Vim(", 4 + cmdlen + 2 + STRLEN(mesg));
      STRCPY(&ret[4], cmdname);
      STRCPY(&ret[4 + cmdlen], "):");
      val = ret + 4 + cmdlen + 2;
    } else {
      ret = vim_strnsave((char_u *)"Vim:", 4 + STRLEN(mesg));
      val = ret + 4;
    }

    /* msg_add_fname may have been used to prefix the message with a file
     * name in quotes.  In the exception value, put the file name in
     * parentheses and move it to the end. */
    for (p = mesg;; p++) {
      if (*p == NUL
          || (*p == 'E'
              && ascii_isdigit(p[1])
              && (p[2] == ':'
                  || (ascii_isdigit(p[2])
                      && (p[3] == ':'
                          || (ascii_isdigit(p[3])
                              && p[4] == ':')))))) {
        if (*p == NUL || p == mesg) {
          STRCAT(val, mesg);  // 'E123' missing or at beginning
        } else {
          // '"filename" E123: message text'
          if (mesg[0] != '"' || p-2 < &mesg[1]
              || p[-2] != '"' || p[-1] != ' ') {
            // "E123:" is part of the file name.
            continue;
          }

          STRCAT(val, p);
          p[-2] = NUL;
          sprintf((char *)(val + STRLEN(p)), " (%s)", &mesg[1]);
          p[-2] = '"';
        }
        break;
      }
    }
  } else {
    *should_free = FALSE;
    ret = (char_u *) value;
  }

  return ret;
}


// Throw a new exception.  Return FAIL when out of memory or it was tried to
// throw an illegal user exception.  "value" is the exception string for a
// user or interrupt exception, or points to a message list in case of an
// error exception.
static int throw_exception(void *value, except_type_T type, char_u *cmdname)
{
  except_T    *excp;
  int should_free;

  /*
   * Disallow faking Interrupt or error exceptions as user exceptions.  They
   * would be treated differently from real interrupt or error exceptions
   * when no active try block is found, see do_cmdline().
   */
  if (type == ET_USER) {
    if (STRNCMP((char_u *)value, "Vim", 3) == 0
        && (((char_u *)value)[3] == NUL || ((char_u *)value)[3] == ':'
            || ((char_u *)value)[3] == '(')) {
      EMSG(_("E608: Cannot :throw exceptions with 'Vim' prefix"));
      goto fail;
    }
  }

  excp = xmalloc(sizeof(except_T));

  if (type == ET_ERROR)
    /* Store the original message and prefix the exception value with
     * "Vim:" or, if a command name is given, "Vim(cmdname):". */
    excp->messages = (struct msglist *)value;

  excp->value = get_exception_string(value, type, cmdname, &should_free);
  if (excp->value == NULL && should_free)
    goto nomem;

  excp->type = type;
  excp->throw_name = vim_strsave(sourcing_name == NULL
      ? (char_u *)"" : sourcing_name);
  excp->throw_lnum = sourcing_lnum;

  if (p_verbose >= 13 || debug_break_level > 0) {
    int save_msg_silent = msg_silent;

    if (debug_break_level > 0)
      msg_silent = FALSE;               /* display messages */
    else
      verbose_enter();
    ++no_wait_return;
    if (debug_break_level > 0 || *p_vfile == NUL)
      msg_scroll = TRUE;            /* always scroll up, don't overwrite */

    smsg(_("Exception thrown: %s"), excp->value);
    msg_puts("\n");  // don't overwrite this either

    if (debug_break_level > 0 || *p_vfile == NUL)
      cmdline_row = msg_row;
    --no_wait_return;
    if (debug_break_level > 0)
      msg_silent = save_msg_silent;
    else
      verbose_leave();
  }

  current_exception = excp;
  return OK;

nomem:
  xfree(excp);
  suppress_errthrow = TRUE;
  EMSG(_(e_outofmem));
fail:
  current_exception = NULL;
  return FAIL;
}

/*
 * Discard an exception.  "was_finished" is set when the exception has been
 * caught and the catch clause has been ended normally.
 */
static void discard_exception(except_T *excp, int was_finished)
{
  char_u              *saved_IObuff;

  if (excp == NULL) {
    internal_error("discard_exception()");
    return;
  }

  if (p_verbose >= 13 || debug_break_level > 0) {
    int save_msg_silent = msg_silent;

    saved_IObuff = vim_strsave(IObuff);
    if (debug_break_level > 0)
      msg_silent = FALSE;               /* display messages */
    else
      verbose_enter();
    ++no_wait_return;
    if (debug_break_level > 0 || *p_vfile == NUL)
      msg_scroll = TRUE;            /* always scroll up, don't overwrite */
    smsg(was_finished ? _("Exception finished: %s")
                      : _("Exception discarded: %s"),
         excp->value);
    msg_puts("\n");  // don't overwrite this either
    if (debug_break_level > 0 || *p_vfile == NUL) {
      cmdline_row = msg_row;
    }
    no_wait_return--;
    if (debug_break_level > 0) {
      msg_silent = save_msg_silent;
    } else {
      verbose_leave();
    }
    xstrlcpy((char *)IObuff, (const char *)saved_IObuff, IOSIZE);
    xfree(saved_IObuff);
  }
  if (excp->type != ET_INTERRUPT)
    xfree(excp->value);
  if (excp->type == ET_ERROR)
    free_msglist(excp->messages);
  xfree(excp->throw_name);
  xfree(excp);
}

/*
 * Discard the exception currently being thrown.
 */
void discard_current_exception(void)
{
  discard_exception(current_exception, false);
  // Note: all globals manipulated here should be saved/restored in
  // try_enter/try_leave.
  current_exception = NULL;
  need_rethrow = false;
}

/*
 * Put an exception on the caught stack.
 */
static void catch_exception(except_T *excp)
{
  excp->caught = caught_stack;
  caught_stack = excp;
  set_vim_var_string(VV_EXCEPTION, (char *) excp->value, -1);
  if (*excp->throw_name != NUL) {
    if (excp->throw_lnum != 0) {
      vim_snprintf((char *)IObuff, IOSIZE, _("%s, line %" PRId64),
                   excp->throw_name, (int64_t)excp->throw_lnum);
    } else {
      vim_snprintf((char *)IObuff, IOSIZE, "%s", excp->throw_name);
    }
    set_vim_var_string(VV_THROWPOINT, (char *) IObuff, -1);
  } else {
    // throw_name not set on an exception from a command that was typed.
    set_vim_var_string(VV_THROWPOINT, NULL, -1);
  }

  if (p_verbose >= 13 || debug_break_level > 0) {
    int save_msg_silent = msg_silent;

    if (debug_break_level > 0)
      msg_silent = FALSE;               /* display messages */
    else
      verbose_enter();
    ++no_wait_return;
    if (debug_break_level > 0 || *p_vfile == NUL)
      msg_scroll = TRUE;            /* always scroll up, don't overwrite */

    smsg(_("Exception caught: %s"), excp->value);
    msg_puts("\n");  // don't overwrite this either

    if (debug_break_level > 0 || *p_vfile == NUL)
      cmdline_row = msg_row;
    --no_wait_return;
    if (debug_break_level > 0)
      msg_silent = save_msg_silent;
    else
      verbose_leave();
  }
}

/*
 * Remove an exception from the caught stack.
 */
static void finish_exception(except_T *excp)
{
  if (excp != caught_stack) {
    internal_error("finish_exception()");
  }
  caught_stack = caught_stack->caught;
  if (caught_stack != NULL) {
    set_vim_var_string(VV_EXCEPTION, (char *) caught_stack->value, -1);
    if (*caught_stack->throw_name != NUL) {
      if (caught_stack->throw_lnum != 0) {
        vim_snprintf((char *)IObuff, IOSIZE,
                     _("%s, line %" PRId64), caught_stack->throw_name,
                     (int64_t)caught_stack->throw_lnum);
      } else {
        vim_snprintf((char *)IObuff, IOSIZE, "%s",
                     caught_stack->throw_name);
      }
      set_vim_var_string(VV_THROWPOINT, (char *) IObuff, -1);
    } else {
      // throw_name not set on an exception from a command that was
      // typed.
      set_vim_var_string(VV_THROWPOINT, NULL, -1);
    }
  } else {
    set_vim_var_string(VV_EXCEPTION, NULL, -1);
    set_vim_var_string(VV_THROWPOINT, NULL, -1);
  }

  /* Discard the exception, but use the finish message for 'verbose'. */
  discard_exception(excp, TRUE);
}

/*
 * Flags specifying the message displayed by report_pending.
 */
#define RP_MAKE         0
#define RP_RESUME       1
#define RP_DISCARD      2

/*
 * Report information about something pending in a finally clause if required by
 * the 'verbose' option or when debugging.  "action" tells whether something is
 * made pending or something pending is resumed or discarded.  "pending" tells
 * what is pending.  "value" specifies the return value for a pending ":return"
 * or the exception value for a pending exception.
 */
static void report_pending(int action, int pending, void *value)
{
  char *mesg;
  char *s;
  int save_msg_silent;

  assert(value || !(pending & CSTP_THROW));

  switch (action) {
  case RP_MAKE:
    mesg = _("%s made pending");
    break;
  case RP_RESUME:
    mesg = _("%s resumed");
    break;
  /* case RP_DISCARD: */
  default:
    mesg = _("%s discarded");
    break;
  }

  switch (pending) {
  case CSTP_NONE:
    return;

  case CSTP_CONTINUE:
    s = ":continue";
    break;
  case CSTP_BREAK:
    s = ":break";
    break;
  case CSTP_FINISH:
    s = ":finish";
    break;
  case CSTP_RETURN:
    /* ":return" command producing value, allocated */
    s = (char *)get_return_cmd(value);
    break;

  default:
    if (pending & CSTP_THROW) {
      vim_snprintf((char *)IObuff, IOSIZE,
                   mesg, _("Exception"));
      mesg = (char *)concat_str(IObuff, (char_u *)": %s");
      s = (char *)((except_T *)value)->value;
    } else if ((pending & CSTP_ERROR) && (pending & CSTP_INTERRUPT))
      s = _("Error and interrupt");
    else if (pending & CSTP_ERROR)
      s = _("Error");
    else         /* if (pending & CSTP_INTERRUPT) */
      s = _("Interrupt");
  }

  save_msg_silent = msg_silent;
  if (debug_break_level > 0)
    msg_silent = FALSE;         /* display messages */
  ++no_wait_return;
  msg_scroll = TRUE;            /* always scroll up, don't overwrite */
  smsg(mesg, s);
  msg_puts("\n");  // don't overwrite this either
  cmdline_row = msg_row;
  --no_wait_return;
  if (debug_break_level > 0)
    msg_silent = save_msg_silent;

  if (pending == CSTP_RETURN)
    xfree(s);
  else if (pending & CSTP_THROW)
    xfree(mesg);
}

/*
 * If something is made pending in a finally clause, report it if required by
 * the 'verbose' option or when debugging.
 */
void report_make_pending(int pending, void *value)
{
  if (p_verbose >= 14 || debug_break_level > 0) {
    if (debug_break_level <= 0)
      verbose_enter();
    report_pending(RP_MAKE, pending, value);
    if (debug_break_level <= 0)
      verbose_leave();
  }
}

/*
 * If something pending in a finally clause is resumed at the ":endtry", report
 * it if required by the 'verbose' option or when debugging.
 */
void report_resume_pending(int pending, void *value)
{
  if (p_verbose >= 14 || debug_break_level > 0) {
    if (debug_break_level <= 0)
      verbose_enter();
    report_pending(RP_RESUME, pending, value);
    if (debug_break_level <= 0)
      verbose_leave();
  }
}

/*
 * If something pending in a finally clause is discarded, report it if required
 * by the 'verbose' option or when debugging.
 */
void report_discard_pending(int pending, void *value)
{
  if (p_verbose >= 14 || debug_break_level > 0) {
    if (debug_break_level <= 0)
      verbose_enter();
    report_pending(RP_DISCARD, pending, value);
    if (debug_break_level <= 0)
      verbose_leave();
  }
}


/*
 * ":if".
 */
void ex_if(exarg_T *eap)
{
  int skip;
  int result;
  struct condstack    *cstack = eap->cstack;

  if (cstack->cs_idx == CSTACK_LEN - 1)
    eap->errmsg = (char_u *)N_("E579: :if nesting too deep");
  else {
    ++cstack->cs_idx;
    cstack->cs_flags[cstack->cs_idx] = 0;

    skip = CHECK_SKIP;

    bool error;
    result = eval_to_bool(eap->arg, &error, &eap->nextcmd, skip);

    if (!skip && !error) {
      if (result)
        cstack->cs_flags[cstack->cs_idx] = CSF_ACTIVE | CSF_TRUE;
    } else
      /* set TRUE, so this conditional will never get active */
      cstack->cs_flags[cstack->cs_idx] = CSF_TRUE;
  }
}

/*
 * ":endif".
 */
void ex_endif(exarg_T *eap)
{
  did_endif = TRUE;
  if (eap->cstack->cs_idx < 0
      || (eap->cstack->cs_flags[eap->cstack->cs_idx]
          & (CSF_WHILE | CSF_FOR | CSF_TRY)))
    eap->errmsg = (char_u *)N_("E580: :endif without :if");
  else {
    /*
     * When debugging or a breakpoint was encountered, display the debug
     * prompt (if not already done).  This shows the user that an ":endif"
     * is executed when the ":if" or a previous ":elseif" was not TRUE.
     * Handle a ">quit" debug command as if an interrupt had occurred before
     * the ":endif".  That is, throw an interrupt exception if appropriate.
     * Doing this here prevents an exception for a parsing error being
     * discarded by throwing the interrupt exception later on.
     */
    if (!(eap->cstack->cs_flags[eap->cstack->cs_idx] & CSF_TRUE)
        && dbg_check_skipped(eap))
      (void)do_intthrow(eap->cstack);

    --eap->cstack->cs_idx;
  }
}

/*
 * ":else" and ":elseif".
 */
void ex_else(exarg_T *eap)
{
  int skip;
  int result;
  struct condstack    *cstack = eap->cstack;

  skip = CHECK_SKIP;

  if (cstack->cs_idx < 0
      || (cstack->cs_flags[cstack->cs_idx]
          & (CSF_WHILE | CSF_FOR | CSF_TRY))) {
    if (eap->cmdidx == CMD_else) {
      eap->errmsg = (char_u *)N_("E581: :else without :if");
      return;
    }
    eap->errmsg = (char_u *)N_("E582: :elseif without :if");
    skip = TRUE;
  } else if (cstack->cs_flags[cstack->cs_idx] & CSF_ELSE) {
    if (eap->cmdidx == CMD_else) {
      eap->errmsg = (char_u *)N_("E583: multiple :else");
      return;
    }
    eap->errmsg = (char_u *)N_("E584: :elseif after :else");
    skip = TRUE;
  }

  /* if skipping or the ":if" was TRUE, reset ACTIVE, otherwise set it */
  if (skip || cstack->cs_flags[cstack->cs_idx] & CSF_TRUE) {
    if (eap->errmsg == NULL)
      cstack->cs_flags[cstack->cs_idx] = CSF_TRUE;
    skip = TRUE;        /* don't evaluate an ":elseif" */
  } else
    cstack->cs_flags[cstack->cs_idx] = CSF_ACTIVE;

  /*
   * When debugging or a breakpoint was encountered, display the debug prompt
   * (if not already done).  This shows the user that an ":else" or ":elseif"
   * is executed when the ":if" or previous ":elseif" was not TRUE.  Handle
   * a ">quit" debug command as if an interrupt had occurred before the
   * ":else" or ":elseif".  That is, set "skip" and throw an interrupt
   * exception if appropriate.  Doing this here prevents that an exception
   * for a parsing errors is discarded when throwing the interrupt exception
   * later on.
   */
  if (!skip && dbg_check_skipped(eap) && got_int) {
    (void)do_intthrow(cstack);
    skip = TRUE;
  }

  if (eap->cmdidx == CMD_elseif) {
    bool error;
    result = eval_to_bool(eap->arg, &error, &eap->nextcmd, skip);
    /* When throwing error exceptions, we want to throw always the first
     * of several errors in a row.  This is what actually happens when
     * a conditional error was detected above and there is another failure
     * when parsing the expression.  Since the skip flag is set in this
     * case, the parsing error will be ignored by emsg(). */

    if (!skip && !error) {
      if (result)
        cstack->cs_flags[cstack->cs_idx] = CSF_ACTIVE | CSF_TRUE;
      else
        cstack->cs_flags[cstack->cs_idx] = 0;
    } else if (eap->errmsg == NULL)
      /* set TRUE, so this conditional will never get active */
      cstack->cs_flags[cstack->cs_idx] = CSF_TRUE;
  } else
    cstack->cs_flags[cstack->cs_idx] |= CSF_ELSE;
}

/*
 * Handle ":while" and ":for".
 */
void ex_while(exarg_T *eap)
{
  bool error;
  int skip;
  int result;
  struct condstack    *cstack = eap->cstack;

  if (cstack->cs_idx == CSTACK_LEN - 1)
    eap->errmsg = (char_u *)N_("E585: :while/:for nesting too deep");
  else {
    /*
     * The loop flag is set when we have jumped back from the matching
     * ":endwhile" or ":endfor".  When not set, need to initialise this
     * cstack entry.
     */
    if ((cstack->cs_lflags & CSL_HAD_LOOP) == 0) {
      ++cstack->cs_idx;
      ++cstack->cs_looplevel;
      cstack->cs_line[cstack->cs_idx] = -1;
    }
    cstack->cs_flags[cstack->cs_idx] =
      eap->cmdidx == CMD_while ? CSF_WHILE : CSF_FOR;

    skip = CHECK_SKIP;
    if (eap->cmdidx == CMD_while) {
      /*
       * ":while bool-expr"
       */
      result = eval_to_bool(eap->arg, &error, &eap->nextcmd, skip);
    } else {
      void *fi;

      /*
       * ":for var in list-expr"
       */
      if ((cstack->cs_lflags & CSL_HAD_LOOP) != 0) {
        /* Jumping here from a ":continue" or ":endfor": use the
         * previously evaluated list. */
        fi = cstack->cs_forinfo[cstack->cs_idx];
        error = FALSE;
      } else {
        /* Evaluate the argument and get the info in a structure. */
        fi = eval_for_line(eap->arg, &error, &eap->nextcmd, skip);
        cstack->cs_forinfo[cstack->cs_idx] = fi;
      }

      /* use the element at the start of the list and advance */
      if (!error && fi != NULL && !skip)
        result = next_for_item(fi, eap->arg);
      else
        result = FALSE;

      if (!result) {
        free_for_info(fi);
        cstack->cs_forinfo[cstack->cs_idx] = NULL;
      }
    }

    /*
     * If this cstack entry was just initialised and is active, set the
     * loop flag, so do_cmdline() will set the line number in cs_line[].
     * If executing the command a second time, clear the loop flag.
     */
    if (!skip && !error && result) {
      cstack->cs_flags[cstack->cs_idx] |= (CSF_ACTIVE | CSF_TRUE);
      cstack->cs_lflags ^= CSL_HAD_LOOP;
    } else {
      cstack->cs_lflags &= ~CSL_HAD_LOOP;
      /* If the ":while" evaluates to FALSE or ":for" is past the end of
       * the list, show the debug prompt at the ":endwhile"/":endfor" as
       * if there was a ":break" in a ":while"/":for" evaluating to
       * TRUE. */
      if (!skip && !error)
        cstack->cs_flags[cstack->cs_idx] |= CSF_TRUE;
    }
  }
}

/*
 * ":continue"
 */
void ex_continue(exarg_T *eap)
{
  int idx;
  struct condstack    *cstack = eap->cstack;

  if (cstack->cs_looplevel <= 0 || cstack->cs_idx < 0)
    eap->errmsg = (char_u *)N_("E586: :continue without :while or :for");
  else {
    /* Try to find the matching ":while".  This might stop at a try
     * conditional not in its finally clause (which is then to be executed
     * next).  Therefor, inactivate all conditionals except the ":while"
     * itself (if reached). */
    idx = cleanup_conditionals(cstack, CSF_WHILE | CSF_FOR, FALSE);
    assert(idx >= 0);
    if (cstack->cs_flags[idx] & (CSF_WHILE | CSF_FOR)) {
      rewind_conditionals(cstack, idx, CSF_TRY, &cstack->cs_trylevel);

      /*
       * Set CSL_HAD_CONT, so do_cmdline() will jump back to the
       * matching ":while".
       */
      cstack->cs_lflags |= CSL_HAD_CONT;        /* let do_cmdline() handle it */
    } else {
      /* If a try conditional not in its finally clause is reached first,
       * make the ":continue" pending for execution at the ":endtry". */
      cstack->cs_pending[idx] = CSTP_CONTINUE;
      report_make_pending(CSTP_CONTINUE, NULL);
    }
  }
}

/*
 * ":break"
 */
void ex_break(exarg_T *eap)
{
  int idx;
  struct condstack    *cstack = eap->cstack;

  if (cstack->cs_looplevel <= 0 || cstack->cs_idx < 0)
    eap->errmsg = (char_u *)N_("E587: :break without :while or :for");
  else {
    /* Inactivate conditionals until the matching ":while" or a try
     * conditional not in its finally clause (which is then to be
     * executed next) is found.  In the latter case, make the ":break"
     * pending for execution at the ":endtry". */
    idx = cleanup_conditionals(cstack, CSF_WHILE | CSF_FOR, TRUE);
    if (idx >= 0 && !(cstack->cs_flags[idx] & (CSF_WHILE | CSF_FOR))) {
      cstack->cs_pending[idx] = CSTP_BREAK;
      report_make_pending(CSTP_BREAK, NULL);
    }
  }
}

/*
 * ":endwhile" and ":endfor"
 */
void ex_endwhile(exarg_T *eap)
{
  struct condstack    *cstack = eap->cstack;
  int idx;
  char_u              *err;
  int csf;
  int fl;

  if (eap->cmdidx == CMD_endwhile) {
    err = e_while;
    csf = CSF_WHILE;
  } else {
    err = e_for;
    csf = CSF_FOR;
  }

  if (cstack->cs_looplevel <= 0 || cstack->cs_idx < 0)
    eap->errmsg = err;
  else {
    fl =  cstack->cs_flags[cstack->cs_idx];
    if (!(fl & csf)) {
      /* If we are in a ":while" or ":for" but used the wrong endloop
       * command, do not rewind to the next enclosing ":for"/":while". */
      if (fl & CSF_WHILE)
        eap->errmsg = (char_u *)_("E732: Using :endfor with :while");
      else if (fl & CSF_FOR)
        eap->errmsg = (char_u *)_("E733: Using :endwhile with :for");
    }
    if (!(fl & (CSF_WHILE | CSF_FOR))) {
      if (!(fl & CSF_TRY))
        eap->errmsg = e_endif;
      else if (fl & CSF_FINALLY)
        eap->errmsg = e_endtry;
      /* Try to find the matching ":while" and report what's missing. */
      for (idx = cstack->cs_idx; idx > 0; --idx) {
        fl =  cstack->cs_flags[idx];
        if ((fl & CSF_TRY) && !(fl & CSF_FINALLY)) {
          /* Give up at a try conditional not in its finally clause.
           * Ignore the ":endwhile"/":endfor". */
          eap->errmsg = err;
          return;
        }
        if (fl & csf)
          break;
      }
      /* Cleanup and rewind all contained (and unclosed) conditionals. */
      (void)cleanup_conditionals(cstack, CSF_WHILE | CSF_FOR, FALSE);
      rewind_conditionals(cstack, idx, CSF_TRY, &cstack->cs_trylevel);
    }
    /*
     * When debugging or a breakpoint was encountered, display the debug
     * prompt (if not already done).  This shows the user that an
     * ":endwhile"/":endfor" is executed when the ":while" was not TRUE or
     * after a ":break".  Handle a ">quit" debug command as if an
     * interrupt had occurred before the ":endwhile"/":endfor".  That is,
     * throw an interrupt exception if appropriate.  Doing this here
     * prevents that an exception for a parsing error is discarded when
     * throwing the interrupt exception later on.
     */
    else if (cstack->cs_flags[cstack->cs_idx] & CSF_TRUE
             && !(cstack->cs_flags[cstack->cs_idx] & CSF_ACTIVE)
             && dbg_check_skipped(eap))
      (void)do_intthrow(cstack);

    /*
     * Set loop flag, so do_cmdline() will jump back to the matching
     * ":while" or ":for".
     */
    cstack->cs_lflags |= CSL_HAD_ENDLOOP;
  }
}


/*
 * ":throw expr"
 */
void ex_throw(exarg_T *eap)
{
  const char *arg = (const char *)eap->arg;
  char *value;

  if (*arg != NUL && *arg != '|' && *arg != '\n') {
    value = eval_to_string_skip(arg, (const char **)&eap->nextcmd,
                                (bool)eap->skip);
  } else {
    EMSG(_(e_argreq));
    value = NULL;
  }

  // On error or when an exception is thrown during argument evaluation, do
  // not throw.
  if (!eap->skip && value != NULL) {
    if (throw_exception((char_u *)value, ET_USER, NULL) == FAIL) {
      xfree(value);
    } else {
      do_throw(eap->cstack);
    }
  }
}

/*
 * Throw the current exception through the specified cstack.  Common routine
 * for ":throw" (user exception) and error and interrupt exceptions.  Also
 * used for rethrowing an uncaught exception.
 */
void do_throw(struct condstack *cstack)
{
  int idx;
  int inactivate_try = FALSE;

  /*
   * Cleanup and inactivate up to the next surrounding try conditional that
   * is not in its finally clause.  Normally, do not inactivate the try
   * conditional itself, so that its ACTIVE flag can be tested below.  But
   * if a previous error or interrupt has not been converted to an exception,
   * inactivate the try conditional, too, as if the conversion had been done,
   * and reset the did_emsg or got_int flag, so this won't happen again at
   * the next surrounding try conditional.
   */
#ifndef THROW_ON_ERROR_TRUE
  if (did_emsg && !THROW_ON_ERROR) {
    inactivate_try = TRUE;
    did_emsg = FALSE;
  }
#endif
#ifndef THROW_ON_INTERRUPT_TRUE
  if (got_int && !THROW_ON_INTERRUPT) {
    inactivate_try = TRUE;
    got_int = FALSE;
  }
#endif
  idx = cleanup_conditionals(cstack, 0, inactivate_try);
  if (idx >= 0) {
    /*
     * If this try conditional is active and we are before its first
     * ":catch", set THROWN so that the ":catch" commands will check
     * whether the exception matches.  When the exception came from any of
     * the catch clauses, it will be made pending at the ":finally" (if
     * present) and rethrown at the ":endtry".  This will also happen if
     * the try conditional is inactive.  This is the case when we are
     * throwing an exception due to an error or interrupt on the way from
     * a preceding ":continue", ":break", ":return", ":finish", error or
     * interrupt (not converted to an exception) to the finally clause or
     * from a preceding throw of a user or error or interrupt exception to
     * the matching catch clause or the finally clause.
     */
    if (!(cstack->cs_flags[idx] & CSF_CAUGHT)) {
      if (cstack->cs_flags[idx] & CSF_ACTIVE)
        cstack->cs_flags[idx] |= CSF_THROWN;
      else
        /* THROWN may have already been set for a catchable exception
         * that has been discarded.  Ensure it is reset for the new
         * exception. */
        cstack->cs_flags[idx] &= ~CSF_THROWN;
    }
    cstack->cs_flags[idx] &= ~CSF_ACTIVE;
    cstack->cs_exception[idx] = current_exception;
  }
}

/*
 * ":try"
 */
void ex_try(exarg_T *eap)
{
  int skip;
  struct condstack    *cstack = eap->cstack;

  if (cstack->cs_idx == CSTACK_LEN - 1)
    eap->errmsg = (char_u *)N_("E601: :try nesting too deep");
  else {
    ++cstack->cs_idx;
    ++cstack->cs_trylevel;
    cstack->cs_flags[cstack->cs_idx] = CSF_TRY;
    cstack->cs_pending[cstack->cs_idx] = CSTP_NONE;

    skip = CHECK_SKIP;

    if (!skip) {
      /* Set ACTIVE and TRUE.  TRUE means that the corresponding ":catch"
       * commands should check for a match if an exception is thrown and
       * that the finally clause needs to be executed. */
      cstack->cs_flags[cstack->cs_idx] |= CSF_ACTIVE | CSF_TRUE;

      /*
       * ":silent!", even when used in a try conditional, disables
       * displaying of error messages and conversion of errors to
       * exceptions.  When the silent commands again open a try
       * conditional, save "emsg_silent" and reset it so that errors are
       * again converted to exceptions.  The value is restored when that
       * try conditional is left.  If it is left normally, the commands
       * following the ":endtry" are again silent.  If it is left by
       * a ":continue", ":break", ":return", or ":finish", the commands
       * executed next are again silent.  If it is left due to an
       * aborting error, an interrupt, or an exception, restoring
       * "emsg_silent" does not matter since we are already in the
       * aborting state and/or the exception has already been thrown.
       * The effect is then just freeing the memory that was allocated
       * to save the value.
       */
      if (emsg_silent) {
        eslist_T *elem = xmalloc(sizeof(struct eslist_elem));
        elem->saved_emsg_silent = emsg_silent;
        elem->next = cstack->cs_emsg_silent_list;
        cstack->cs_emsg_silent_list = elem;
        cstack->cs_flags[cstack->cs_idx] |= CSF_SILENT;
        emsg_silent = 0;
      }
    }

  }
}

/*
 * ":catch /{pattern}/" and ":catch"
 */
void ex_catch(exarg_T *eap)
{
  int idx = 0;
  int give_up = FALSE;
  int skip = FALSE;
  int caught = FALSE;
  char_u      *end;
  char_u save_char = 0;
  char_u      *save_cpo;
  regmatch_T regmatch;
  int prev_got_int;
  struct condstack    *cstack = eap->cstack;
  char_u      *pat;

  if (cstack->cs_trylevel <= 0 || cstack->cs_idx < 0) {
    eap->errmsg = (char_u *)N_("E603: :catch without :try");
    give_up = TRUE;
  } else {
    if (!(cstack->cs_flags[cstack->cs_idx] & CSF_TRY)) {
      /* Report what's missing if the matching ":try" is not in its
       * finally clause. */
      eap->errmsg = get_end_emsg(cstack);
      skip = TRUE;
    }
    for (idx = cstack->cs_idx; idx > 0; --idx)
      if (cstack->cs_flags[idx] & CSF_TRY)
        break;
    if (cstack->cs_flags[idx] & CSF_FINALLY) {
      /* Give up for a ":catch" after ":finally" and ignore it.
       * Just parse. */
      eap->errmsg = (char_u *)N_("E604: :catch after :finally");
      give_up = TRUE;
    } else
      rewind_conditionals(cstack, idx, CSF_WHILE | CSF_FOR,
          &cstack->cs_looplevel);
  }

  if (ends_excmd(*eap->arg)) {  /* no argument, catch all errors */
    pat = (char_u *)".*";
    end = NULL;
    eap->nextcmd = find_nextcmd(eap->arg);
  } else {
    pat = eap->arg + 1;
    end = skip_regexp(pat, *eap->arg, TRUE, NULL);
  }

  if (!give_up) {
    /*
     * Don't do something when no exception has been thrown or when the
     * corresponding try block never got active (because of an inactive
     * surrounding conditional or after an error or interrupt or throw).
     */
    if (!current_exception || !(cstack->cs_flags[idx] & CSF_TRUE)) {
      skip = true;
    }

    /*
     * Check for a match only if an exception is thrown but not caught by
     * a previous ":catch".  An exception that has replaced a discarded
     * exception is not checked (THROWN is not set then).
     */
    if (!skip && (cstack->cs_flags[idx] & CSF_THROWN)
        && !(cstack->cs_flags[idx] & CSF_CAUGHT)) {
      if (end != NULL && *end != NUL && !ends_excmd(*skipwhite(end + 1))) {
        EMSG(_(e_trailing));
        return;
      }

      /* When debugging or a breakpoint was encountered, display the
       * debug prompt (if not already done) before checking for a match.
       * This is a helpful hint for the user when the regular expression
       * matching fails.  Handle a ">quit" debug command as if an
       * interrupt had occurred before the ":catch".  That is, discard
       * the original exception, replace it by an interrupt exception,
       * and don't catch it in this try block. */
      if (!dbg_check_skipped(eap) || !do_intthrow(cstack)) {
        /* Terminate the pattern and avoid the 'l' flag in 'cpoptions'
         * while compiling it. */
        if (end != NULL) {
          save_char = *end;
          *end = NUL;
        }
        save_cpo  = p_cpo;
        p_cpo = (char_u *)"";
        // Disable error messages, it will make current exception
        // invalid
        emsg_off++;
        regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
        emsg_off--;
        regmatch.rm_ic = false;
        if (end != NULL) {
          *end = save_char;
        }
        p_cpo = save_cpo;
        if (regmatch.regprog == NULL) {
          EMSG2(_(e_invarg2), pat);
        } else {
          //
          // Save the value of got_int and reset it.  We don't want
          // a previous interruption cancel matching, only hitting
          // CTRL-C while matching should abort it.
          //
          prev_got_int = got_int;
          got_int = FALSE;
          caught = vim_regexec_nl(&regmatch, current_exception->value,
              (colnr_T)0);
          got_int |= prev_got_int;
          vim_regfree(regmatch.regprog);
        }
      }
    }

    if (caught) {
      /* Make this ":catch" clause active and reset did_emsg and got_int.
       * Put the exception on the caught stack. */
      cstack->cs_flags[idx] |= CSF_ACTIVE | CSF_CAUGHT;
      did_emsg = got_int = false;
      catch_exception((except_T *)cstack->cs_exception[idx]);
      /* It's mandatory that the current exception is stored in the cstack
       * so that it can be discarded at the next ":catch", ":finally", or
       * ":endtry" or when the catch clause is left by a ":continue",
       * ":break", ":return", ":finish", error, interrupt, or another
       * exception. */
      if (cstack->cs_exception[cstack->cs_idx] != current_exception) {
        internal_error("ex_catch()");
      }
      // Discarding current_exceptions happens based on what is stored in
      // cstack->cs_exception, *all* calls to discard_current_exception() are
      // (and must be) guarded by current_exception check.
      current_exception = NULL;
    } else {
      /*
       * If there is a preceding catch clause and it caught the exception,
       * finish the exception now.  This happens also after errors except
       * when this ":catch" was after the ":finally" or not within
       * a ":try".  Make the try conditional inactive so that the
       * following catch clauses are skipped.  On an error or interrupt
       * after the preceding try block or catch clause was left by
       * a ":continue", ":break", ":return", or ":finish", discard the
       * pending action.
       */
      cleanup_conditionals(cstack, CSF_TRY, TRUE);
    }
  }

  if (end != NULL)
    eap->nextcmd = find_nextcmd(end);
}

/*
 * ":finally"
 */
void ex_finally(exarg_T *eap)
{
  int idx;
  int skip = FALSE;
  int pending = CSTP_NONE;
  struct condstack    *cstack = eap->cstack;

  if (cstack->cs_trylevel <= 0 || cstack->cs_idx < 0)
    eap->errmsg = (char_u *)N_("E606: :finally without :try");
  else {
    if (!(cstack->cs_flags[cstack->cs_idx] & CSF_TRY)) {
      eap->errmsg = get_end_emsg(cstack);
      for (idx = cstack->cs_idx - 1; idx > 0; --idx)
        if (cstack->cs_flags[idx] & CSF_TRY)
          break;
      /* Make this error pending, so that the commands in the following
       * finally clause can be executed.  This overrules also a pending
       * ":continue", ":break", ":return", or ":finish". */
      pending = CSTP_ERROR;
    } else
      idx = cstack->cs_idx;

    if (cstack->cs_flags[idx] & CSF_FINALLY) {
      /* Give up for a multiple ":finally" and ignore it. */
      eap->errmsg = (char_u *)N_("E607: multiple :finally");
      return;
    }
    rewind_conditionals(cstack, idx, CSF_WHILE | CSF_FOR,
        &cstack->cs_looplevel);

    /*
     * Don't do something when the corresponding try block never got active
     * (because of an inactive surrounding conditional or after an error or
     * interrupt or throw) or for a ":finally" without ":try" or a multiple
     * ":finally".  After every other error (did_emsg or the conditional
     * errors detected above) or after an interrupt (got_int) or an
     * exception (current_exception), the finally clause must be executed.
     */
    skip = !(cstack->cs_flags[cstack->cs_idx] & CSF_TRUE);

    if (!skip) {
      /* When debugging or a breakpoint was encountered, display the
       * debug prompt (if not already done).  The user then knows that the
       * finally clause is executed. */
      if (dbg_check_skipped(eap)) {
        /* Handle a ">quit" debug command as if an interrupt had
         * occurred before the ":finally".  That is, discard the
         * original exception and replace it by an interrupt
         * exception. */
        (void)do_intthrow(cstack);
      }

      /*
       * If there is a preceding catch clause and it caught the exception,
       * finish the exception now.  This happens also after errors except
       * when this is a multiple ":finally" or one not within a ":try".
       * After an error or interrupt, this also discards a pending
       * ":continue", ":break", ":finish", or ":return" from the preceding
       * try block or catch clause.
       */
      cleanup_conditionals(cstack, CSF_TRY, FALSE);

      /*
       * Make did_emsg, got_int, current_exception pending.  If set, they
       * overrule a pending ":continue", ":break", ":return", or ":finish".
       * Then we have particularly to discard a pending return value (as done
       * by the call to cleanup_conditionals() above when did_emsg or
       * got_int is set).  The pending values are restored by the
       * ":endtry", except if there is a new error, interrupt, exception,
       * ":continue", ":break", ":return", or ":finish" in the following
       * finally clause.  A missing ":endwhile", ":endfor" or ":endif"
       * detected here is treated as if did_emsg and current_exception had
       * already been set, respectively in case that the error is not
       * converted to an exception, current_exception had already been unset.
       * We must not set did_emsg here since that would suppress the
       * error message.
       */
      if (pending == CSTP_ERROR || did_emsg || got_int || current_exception) {
        if (cstack->cs_pending[cstack->cs_idx] == CSTP_RETURN) {
          report_discard_pending(CSTP_RETURN,
              cstack->cs_rettv[cstack->cs_idx]);
          discard_pending_return(cstack->cs_rettv[cstack->cs_idx]);
        }
        if (pending == CSTP_ERROR && !did_emsg) {
          pending |= (THROW_ON_ERROR ? CSTP_THROW : 0);
        } else {
          pending |= (current_exception ? CSTP_THROW : 0);
        }
        pending |= did_emsg  ? CSTP_ERROR     : 0;
        pending |= got_int   ? CSTP_INTERRUPT : 0;
        assert(pending >= CHAR_MIN && pending <= CHAR_MAX);
        cstack->cs_pending[cstack->cs_idx] = (char)pending;

        /* It's mandatory that the current exception is stored in the
         * cstack so that it can be rethrown at the ":endtry" or be
         * discarded if the finally clause is left by a ":continue",
         * ":break", ":return", ":finish", error, interrupt, or another
         * exception.  When emsg() is called for a missing ":endif" or
         * a missing ":endwhile"/":endfor" detected here, the
         * exception will be discarded. */
        if (current_exception
            && cstack->cs_exception[cstack->cs_idx] != current_exception) {
          internal_error("ex_finally()");
        }
      }

      /*
       * Set CSL_HAD_FINA, so do_cmdline() will reset did_emsg,
       * got_int, and current_exception and make the finally clause active.
       * This will happen after emsg() has been called for a missing
       * ":endif" or a missing ":endwhile"/":endfor" detected here, so
       * that the following finally clause will be executed even then.
       */
      cstack->cs_lflags |= CSL_HAD_FINA;
    }
  }
}

/*
 * ":endtry"
 */
void ex_endtry(exarg_T *eap)
{
  int idx;
  int skip;
  int rethrow = FALSE;
  int pending = CSTP_NONE;
  void        *rettv = NULL;
  struct condstack    *cstack = eap->cstack;

  if (cstack->cs_trylevel <= 0 || cstack->cs_idx < 0) {
    eap->errmsg = (char_u *)N_("E602: :endtry without :try");
  } else {
    // Don't do something after an error, interrupt or throw in the try
    // block, catch clause, or finally clause preceding this ":endtry" or
    // when an error or interrupt occurred after a ":continue", ":break",
    // ":return", or ":finish" in a try block or catch clause preceding this
    // ":endtry" or when the try block never got active (because of an
    // inactive surrounding conditional or after an error or interrupt or
    // throw) or when there is a surrounding conditional and it has been
    // made inactive by a ":continue", ":break", ":return", or ":finish" in
    // the finally clause.  The latter case need not be tested since then
    // anything pending has already been discarded.
    skip = (did_emsg || got_int || current_exception
            || !(cstack->cs_flags[cstack->cs_idx] & CSF_TRUE));

    if (!(cstack->cs_flags[cstack->cs_idx] & CSF_TRY)) {
      eap->errmsg = get_end_emsg(cstack);
      /* Find the matching ":try" and report what's missing. */
      idx = cstack->cs_idx;
      do
        --idx;
      while (idx > 0 && !(cstack->cs_flags[idx] & CSF_TRY));
      rewind_conditionals(cstack, idx, CSF_WHILE | CSF_FOR,
          &cstack->cs_looplevel);
      skip = TRUE;

      /*
       * If an exception is being thrown, discard it to prevent it from
       * being rethrown at the end of this function.  It would be
       * discarded by the error message, anyway.  Resets current_exception.
       * This does not affect the script termination due to the error
       * since "trylevel" is decremented after emsg() has been called.
       */
      if (current_exception) {
        discard_current_exception();
      }
    } else {
      idx = cstack->cs_idx;

      /*
       * If we stopped with the exception currently being thrown at this
       * try conditional since we didn't know that it doesn't have
       * a finally clause, we need to rethrow it after closing the try
       * conditional.
       */
      if (current_exception
          && (cstack->cs_flags[idx] & CSF_TRUE)
          && !(cstack->cs_flags[idx] & CSF_FINALLY)) {
        rethrow = true;
      }
    }

    /* If there was no finally clause, show the user when debugging or
     * a breakpoint was encountered that the end of the try conditional has
     * been reached: display the debug prompt (if not already done).  Do
     * this on normal control flow or when an exception was thrown, but not
     * on an interrupt or error not converted to an exception or when
     * a ":break", ":continue", ":return", or ":finish" is pending.  These
     * actions are carried out immediately.
     */
    if ((rethrow || (!skip
                     && !(cstack->cs_flags[idx] & CSF_FINALLY)
                     && !cstack->cs_pending[idx]))
        && dbg_check_skipped(eap)) {
      /* Handle a ">quit" debug command as if an interrupt had occurred
       * before the ":endtry".  That is, throw an interrupt exception and
       * set "skip" and "rethrow". */
      if (got_int) {
        skip = TRUE;
        (void)do_intthrow(cstack);
        // The do_intthrow() call may have reset current_exception or
        // cstack->cs_pending[idx].
        rethrow = false;
        if (current_exception && !(cstack->cs_flags[idx] & CSF_FINALLY)) {
          rethrow = true;
        }
      }
    }

    /*
     * If a ":return" is pending, we need to resume it after closing the
     * try conditional; remember the return value.  If there was a finally
     * clause making an exception pending, we need to rethrow it.  Make it
     * the exception currently being thrown.
     */
    if (!skip) {
      pending = cstack->cs_pending[idx];
      cstack->cs_pending[idx] = CSTP_NONE;
      if (pending == CSTP_RETURN)
        rettv = cstack->cs_rettv[idx];
      else if (pending & CSTP_THROW)
        current_exception = cstack->cs_exception[idx];
    }

    /*
     * Discard anything pending on an error, interrupt, or throw in the
     * finally clause.  If there was no ":finally", discard a pending
     * ":continue", ":break", ":return", or ":finish" if an error or
     * interrupt occurred afterwards, but before the ":endtry" was reached.
     * If an exception was caught by the last of the catch clauses and there
     * was no finally clause, finish the exception now.  This happens also
     * after errors except when this ":endtry" is not within a ":try".
     * Restore "emsg_silent" if it has been reset by this try conditional.
     */
    (void)cleanup_conditionals(cstack, CSF_TRY | CSF_SILENT, TRUE);

    --cstack->cs_idx;
    --cstack->cs_trylevel;

    if (!skip) {
      report_resume_pending(pending,
          (pending == CSTP_RETURN) ? rettv :
          (pending & CSTP_THROW) ? (void *)current_exception : NULL);
      switch (pending) {
      case CSTP_NONE:
        break;

      /* Reactivate a pending ":continue", ":break", ":return",
       * ":finish" from the try block or a catch clause of this try
       * conditional.  This is skipped, if there was an error in an
       * (unskipped) conditional command or an interrupt afterwards
       * or if the finally clause is present and executed a new error,
       * interrupt, throw, ":continue", ":break", ":return", or
       * ":finish". */
      case CSTP_CONTINUE:
        ex_continue(eap);
        break;
      case CSTP_BREAK:
        ex_break(eap);
        break;
      case CSTP_RETURN:
        do_return(eap, FALSE, FALSE, rettv);
        break;
      case CSTP_FINISH:
        do_finish(eap, FALSE);
        break;

      // When the finally clause was entered due to an error,
      // interrupt or throw (as opposed to a ":continue", ":break",
      // ":return", or ":finish"), restore the pending values of
      // did_emsg, got_int, and current_exception.  This is skipped, if there
      // was a new error, interrupt, throw, ":continue", ":break",
      // ":return", or ":finish".  in the finally clause.
      default:
        if (pending & CSTP_ERROR) {
          did_emsg = true;
        }
        if (pending & CSTP_INTERRUPT) {
          got_int = true;
        }
        if (pending & CSTP_THROW) {
          rethrow = true;
        }
        break;
      }
    }

    if (rethrow) {
      // Rethrow the current exception (within this cstack).
      do_throw(cstack);
    }
  }
}

/*
 * enter_cleanup() and leave_cleanup()
 *
 * Functions to be called before/after invoking a sequence of autocommands for
 * cleanup for a failed command.  (Failure means here that a call to emsg()
 * has been made, an interrupt occurred, or there is an uncaught exception
 * from a previous autocommand execution of the same command.)
 *
 * Call enter_cleanup() with a pointer to a cleanup_T and pass the same
 * pointer to leave_cleanup().  The cleanup_T structure stores the pending
 * error/interrupt/exception state.
 */

/*
 * This function works a bit like ex_finally() except that there was not
 * actually an extra try block around the part that failed and an error or
 * interrupt has not (yet) been converted to an exception.  This function
 * saves the error/interrupt/ exception state and prepares for the call to
 * do_cmdline() that is going to be made for the cleanup autocommand
 * execution.
 */
void enter_cleanup(cleanup_T *csp)
{
  int pending = CSTP_NONE;

  /*
   * Postpone did_emsg, got_int, current_exception.  The pending values will be
   * restored by leave_cleanup() except if there was an aborting error,
   * interrupt, or uncaught exception after this function ends.
   */
  if (did_emsg || got_int || current_exception || need_rethrow) {
    csp->pending = (did_emsg ? CSTP_ERROR : 0)
                   | (got_int ? CSTP_INTERRUPT : 0)
                   | (current_exception ? CSTP_THROW : 0)
                   | (need_rethrow ? CSTP_THROW : 0);

    /* If we are currently throwing an exception, save it as well.  On an error
     * not yet converted to an exception, update "force_abort" and reset
     * "cause_abort" (as do_errthrow() would do).  This is needed for the
     * do_cmdline() call that is going to be made for autocommand execution.  We
     * need not save *msg_list because there is an extra instance for every call
     * of do_cmdline(), anyway.
     */
    if (current_exception || need_rethrow) {
      csp->exception = current_exception;
    } else {
      csp->exception = NULL;
      if (did_emsg) {
        force_abort |= cause_abort;
        cause_abort = FALSE;
      }
    }
    did_emsg = got_int = need_rethrow = false;
    current_exception = NULL;

    /* Report if required by the 'verbose' option or when debugging.  */
    report_make_pending(pending, csp->exception);
  } else {
    csp->pending = CSTP_NONE;
    csp->exception = NULL;
  }
}

/*
 * See comment above enter_cleanup() for how this function is used.
 *
 * This function is a bit like ex_endtry() except that there was not actually
 * an extra try block around the part that failed and an error or interrupt
 * had not (yet) been converted to an exception when the cleanup autocommand
 * sequence was invoked.
 *
 * This function has to be called with the address of the cleanup_T structure
 * filled by enter_cleanup() as an argument; it restores the error/interrupt/
 * exception state saved by that function - except there was an aborting
 * error, an interrupt or an uncaught exception during execution of the
 * cleanup autocommands.  In the latter case, the saved error/interrupt/
 * exception state is discarded.
 */
void leave_cleanup(cleanup_T *csp)
{
  int pending = csp->pending;

  if (pending == CSTP_NONE)     /* nothing to do */
    return;

  /* If there was an aborting error, an interrupt, or an uncaught exception
   * after the corresponding call to enter_cleanup(), discard what has been
   * made pending by it.  Report this to the user if required by the
   * 'verbose' option or when debugging. */
  if (aborting() || need_rethrow) {
    if (pending & CSTP_THROW)
      /* Cancel the pending exception (includes report). */
      discard_exception(csp->exception, FALSE);
    else
      report_discard_pending(pending, NULL);

    /* If an error was about to be converted to an exception when
     * enter_cleanup() was called, free the message list. */
    if (msg_list != NULL)
      free_global_msglist();
  }
  /*
   * If there was no new error, interrupt, or throw between the calls
   * to enter_cleanup() and leave_cleanup(), restore the pending
   * error/interrupt/exception state.
   */
  else {
    /*
     * If there was an exception being thrown when enter_cleanup() was
     * called, we need to rethrow it.  Make it the exception currently
     * being thrown.
     */
    if (pending & CSTP_THROW)
      current_exception = csp->exception;

    /*
     * If an error was about to be converted to an exception when
     * enter_cleanup() was called, let "cause_abort" take the part of
     * "force_abort" (as done by cause_errthrow()).
     */
    else if (pending & CSTP_ERROR) {
      cause_abort = force_abort;
      force_abort = FALSE;
    }

    // Restore the pending values of did_emsg, got_int, and current_exception.
    if (pending & CSTP_ERROR) {
      did_emsg = true;
    }
    if (pending & CSTP_INTERRUPT) {
      got_int = true;
    }
    if (pending & CSTP_THROW) {
      need_rethrow = true;  // current_exception will be set by do_one_cmd()
    }

    // Report if required by the 'verbose' option or when debugging.
    report_resume_pending(
        pending, ((pending & CSTP_THROW) ? (void *)current_exception : NULL));
  }
}


/*
 * Make conditionals inactive and discard what's pending in finally clauses
 * until the conditional type searched for or a try conditional not in its
 * finally clause is reached.  If this is in an active catch clause, finish
 * the caught exception.
 * Return the cstack index where the search stopped.
 * Values used for "searched_cond" are (CSF_WHILE | CSF_FOR) or CSF_TRY or 0,
 * the latter meaning the innermost try conditional not in its finally clause.
 * "inclusive" tells whether the conditional searched for should be made
 * inactive itself (a try conditional not in its finally clause possibly find
 * before is always made inactive).  If "inclusive" is TRUE and
 * "searched_cond" is CSF_TRY|CSF_SILENT, the saved former value of
 * "emsg_silent", if reset when the try conditional finally reached was
 * entered, is restored (used by ex_endtry()).  This is normally done only
 * when such a try conditional is left.
 */
int cleanup_conditionals(struct condstack *cstack, int searched_cond, int inclusive)
{
  int idx;
  int stop = FALSE;

  for (idx = cstack->cs_idx; idx >= 0; --idx) {
    if (cstack->cs_flags[idx] & CSF_TRY) {
      /*
       * Discard anything pending in a finally clause and continue the
       * search.  There may also be a pending ":continue", ":break",
       * ":return", or ":finish" before the finally clause.  We must not
       * discard it, unless an error or interrupt occurred afterwards.
       */
      if (did_emsg || got_int || (cstack->cs_flags[idx] & CSF_FINALLY)) {
        switch (cstack->cs_pending[idx]) {
        case CSTP_NONE:
          break;

        case CSTP_CONTINUE:
        case CSTP_BREAK:
        case CSTP_FINISH:
          report_discard_pending(cstack->cs_pending[idx], NULL);
          cstack->cs_pending[idx] = CSTP_NONE;
          break;

        case CSTP_RETURN:
          report_discard_pending(CSTP_RETURN,
              cstack->cs_rettv[idx]);
          discard_pending_return(cstack->cs_rettv[idx]);
          cstack->cs_pending[idx] = CSTP_NONE;
          break;

        default:
          if (cstack->cs_flags[idx] & CSF_FINALLY) {
            if (cstack->cs_pending[idx] & CSTP_THROW) {
              /* Cancel the pending exception.  This is in the
               * finally clause, so that the stack of the
               * caught exceptions is not involved. */
              discard_exception((except_T *)
                  cstack->cs_exception[idx],
                  FALSE);
            } else
              report_discard_pending(cstack->cs_pending[idx],
                  NULL);
            cstack->cs_pending[idx] = CSTP_NONE;
          }
          break;
        }
      }

      /*
       * Stop at a try conditional not in its finally clause.  If this try
       * conditional is in an active catch clause, finish the caught
       * exception.
       */
      if (!(cstack->cs_flags[idx] & CSF_FINALLY)) {
        if ((cstack->cs_flags[idx] & CSF_ACTIVE)
            && (cstack->cs_flags[idx] & CSF_CAUGHT))
          finish_exception((except_T *)cstack->cs_exception[idx]);
        /* Stop at this try conditional - except the try block never
         * got active (because of an inactive surrounding conditional
         * or when the ":try" appeared after an error or interrupt or
         * throw). */
        if (cstack->cs_flags[idx] & CSF_TRUE) {
          if (searched_cond == 0 && !inclusive)
            break;
          stop = TRUE;
        }
      }
    }

    /* Stop on the searched conditional type (even when the surrounding
     * conditional is not active or something has been made pending).
     * If "inclusive" is TRUE and "searched_cond" is CSF_TRY|CSF_SILENT,
     * check first whether "emsg_silent" needs to be restored. */
    if (cstack->cs_flags[idx] & searched_cond) {
      if (!inclusive)
        break;
      stop = TRUE;
    }
    cstack->cs_flags[idx] &= ~CSF_ACTIVE;
    if (stop && searched_cond != (CSF_TRY | CSF_SILENT))
      break;

    /*
     * When leaving a try conditional that reset "emsg_silent" on its
     * entry after saving the original value, restore that value here and
     * free the memory used to store it.
     */
    if ((cstack->cs_flags[idx] & CSF_TRY)
        && (cstack->cs_flags[idx] & CSF_SILENT)) {
      eslist_T    *elem;

      elem = cstack->cs_emsg_silent_list;
      cstack->cs_emsg_silent_list = elem->next;
      emsg_silent = elem->saved_emsg_silent;
      xfree(elem);
      cstack->cs_flags[idx] &= ~CSF_SILENT;
    }
    if (stop)
      break;
  }
  return idx;
}

/*
 * Return an appropriate error message for a missing endwhile/endfor/endif.
 */
static char_u *get_end_emsg(struct condstack *cstack)
{
  if (cstack->cs_flags[cstack->cs_idx] & CSF_WHILE)
    return e_endwhile;
  if (cstack->cs_flags[cstack->cs_idx] & CSF_FOR)
    return e_endfor;
  return e_endif;
}


/*
 * Rewind conditionals until index "idx" is reached.  "cond_type" and
 * "cond_level" specify a conditional type and the address of a level variable
 * which is to be decremented with each skipped conditional of the specified
 * type.
 * Also free "for info" structures where needed.
 */
void rewind_conditionals(struct condstack *cstack, int idx, int cond_type, int *cond_level)
{
  while (cstack->cs_idx > idx) {
    if (cstack->cs_flags[cstack->cs_idx] & cond_type)
      --*cond_level;
    if (cstack->cs_flags[cstack->cs_idx] & CSF_FOR)
      free_for_info(cstack->cs_forinfo[cstack->cs_idx]);
    --cstack->cs_idx;
  }
}

/*
 * ":endfunction" when not after a ":function"
 */
void ex_endfunction(exarg_T *eap)
{
  EMSG(_("E193: :endfunction not inside a function"));
}

/*
 * Return TRUE if the string "p" looks like a ":while" or ":for" command.
 */
int has_loop_cmd(char_u *p)
{
  int len;

  /* skip modifiers, white space and ':' */
  for (;; ) {
    while (*p == ' ' || *p == '\t' || *p == ':')
      ++p;
    len = modifier_len(p);
    if (len == 0)
      break;
    p += len;
  }
  if ((p[0] == 'w' && p[1] == 'h')
      || (p[0] == 'f' && p[1] == 'o' && p[2] == 'r'))
    return TRUE;
  return FALSE;
}

