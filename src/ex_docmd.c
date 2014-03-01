/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * ex_docmd.c: functions for executing an Ex command line.
 */

#include "vim.h"
#include "ex_docmd.h"
#include "blowfish.h"
#include "buffer.h"
#include "charset.h"
#include "diff.h"
#include "digraph.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_cmds2.h"
#include "ex_eval.h"
#include "ex_getln.h"
#include "fileio.h"
#include "fold.h"
#include "getchar.h"
#include "hardcopy.h"
#include "if_cscope.h"
#include "main.h"
#include "mark.h"
#include "mbyte.h"
#include "memline.h"
#include "menu.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "file_search.h"
#include "garray.h"
#include "move.h"
#include "normal.h"
#include "ops.h"
#include "option.h"
#include "os_unix.h"
#include "quickfix.h"
#include "regexp.h"
#include "screen.h"
#include "search.h"
#include "spell.h"
#include "syntax.h"
#include "tag.h"
#include "term.h"
#include "ui.h"
#include "undo.h"
#include "version.h"
#include "window.h"
#include "os/os.h"

static int quitmore = 0;
static int ex_pressedreturn = FALSE;

typedef struct ucmd {
  char_u      *uc_name;         /* The command name */
  long_u uc_argt;               /* The argument type */
  char_u      *uc_rep;          /* The command's replacement string */
  long uc_def;                  /* The default value for a range/count */
  int uc_compl;                 /* completion type */
  scid_T uc_scriptID;           /* SID where the command was defined */
  char_u      *uc_compl_arg;    /* completion argument if any */
} ucmd_T;

#define UC_BUFFER       1       /* -buffer: local to current buffer */

static garray_T ucmds = {0, 0, sizeof(ucmd_T), 4, NULL};

#define USER_CMD(i) (&((ucmd_T *)(ucmds.ga_data))[i])
#define USER_CMD_GA(gap, i) (&((ucmd_T *)((gap)->ga_data))[i])

static void do_ucmd(exarg_T *eap);
static void ex_command(exarg_T *eap);
static void ex_delcommand(exarg_T *eap);
static char_u *get_user_command_name(int idx);


static char_u   *do_one_cmd(char_u **, int, struct condstack *,
                            char_u *(*fgetline)(int, void *, int),
                            void *cookie);
static void append_command(char_u *cmd);
static char_u   *find_command(exarg_T *eap, int *full);

static void ex_abbreviate(exarg_T *eap);
static void ex_map(exarg_T *eap);
static void ex_unmap(exarg_T *eap);
static void ex_mapclear(exarg_T *eap);
static void ex_abclear(exarg_T *eap);
static void ex_autocmd(exarg_T *eap);
static void ex_doautocmd(exarg_T *eap);
static void ex_bunload(exarg_T *eap);
static void ex_buffer(exarg_T *eap);
static void ex_bmodified(exarg_T *eap);
static void ex_bnext(exarg_T *eap);
static void ex_bprevious(exarg_T *eap);
static void ex_brewind(exarg_T *eap);
static void ex_blast(exarg_T *eap);
static char_u   *getargcmd(char_u **);
static char_u   *skip_cmd_arg(char_u *p, int rembs);
static int getargopt(exarg_T *eap);

static int check_more(int, int);
static linenr_T get_address(char_u **, int skip, int to_other_file);
static void get_flags(exarg_T *eap);
#if !defined(FEAT_PERL) \
  || !defined(FEAT_PYTHON) || !defined(FEAT_PYTHON3) \
  || !defined(FEAT_TCL) \
  || !defined(FEAT_RUBY) \
  || !defined(FEAT_LUA) \
  || !defined(FEAT_MZSCHEME)
# define HAVE_EX_SCRIPT_NI
static void ex_script_ni(exarg_T *eap);
#endif
static char_u   *invalid_range(exarg_T *eap);
static void correct_range(exarg_T *eap);
static char_u   *replace_makeprg(exarg_T *eap, char_u *p,
                                 char_u **cmdlinep);
static char_u   *repl_cmdline(exarg_T *eap, char_u *src, int srclen,
                              char_u *repl,
                              char_u **cmdlinep);
static void ex_highlight(exarg_T *eap);
static void ex_colorscheme(exarg_T *eap);
static void ex_quit(exarg_T *eap);
static void ex_cquit(exarg_T *eap);
static void ex_quit_all(exarg_T *eap);
static void ex_close(exarg_T *eap);
static void ex_win_close(int forceit, win_T *win, tabpage_T *tp);
static void ex_only(exarg_T *eap);
static void ex_resize(exarg_T *eap);
static void ex_stag(exarg_T *eap);
static void ex_tabclose(exarg_T *eap);
static void ex_tabonly(exarg_T *eap);
static void ex_tabnext(exarg_T *eap);
static void ex_tabmove(exarg_T *eap);
static void ex_tabs(exarg_T *eap);
static void ex_pclose(exarg_T *eap);
static void ex_ptag(exarg_T *eap);
static void ex_pedit(exarg_T *eap);
static void ex_hide(exarg_T *eap);
static void ex_stop(exarg_T *eap);
static void ex_exit(exarg_T *eap);
static void ex_print(exarg_T *eap);
static void ex_goto(exarg_T *eap);
static void ex_shell(exarg_T *eap);
static void ex_preserve(exarg_T *eap);
static void ex_recover(exarg_T *eap);
static void ex_mode(exarg_T *eap);
static void ex_wrongmodifier(exarg_T *eap);
static void ex_find(exarg_T *eap);
static void ex_open(exarg_T *eap);
static void ex_edit(exarg_T *eap);
# define ex_drop                ex_ni
# define ex_gui                 ex_nogui
static void ex_nogui(exarg_T *eap);
# define ex_tearoff             ex_ni
# define ex_popup               ex_ni
# define ex_simalt              ex_ni
# define gui_mch_find_dialog    ex_ni
# define gui_mch_replace_dialog ex_ni
# define ex_helpfind            ex_ni
# define ex_lua                 ex_script_ni
# define ex_luado               ex_ni
# define ex_luafile             ex_ni
# define ex_mzscheme            ex_script_ni
# define ex_mzfile              ex_ni
# define ex_perl                ex_script_ni
# define ex_perldo              ex_ni
# define ex_python              ex_script_ni
# define ex_pydo                ex_ni
# define ex_pyfile              ex_ni
# define ex_py3                 ex_script_ni
# define ex_py3do               ex_ni
# define ex_py3file             ex_ni
# define ex_tcl                 ex_script_ni
# define ex_tcldo               ex_ni
# define ex_tclfile             ex_ni
# define ex_ruby                ex_script_ni
# define ex_rubydo              ex_ni
# define ex_rubyfile            ex_ni
# define ex_sniff               ex_ni
static void ex_swapname(exarg_T *eap);
static void ex_syncbind(exarg_T *eap);
static void ex_read(exarg_T *eap);
static void ex_pwd(exarg_T *eap);
static void ex_equal(exarg_T *eap);
static void ex_sleep(exarg_T *eap);
static void do_exmap(exarg_T *eap, int isabbrev);
static void ex_winsize(exarg_T *eap);
static void ex_wincmd(exarg_T *eap);
#if defined(FEAT_GUI) || defined(UNIX) || defined(VMS) || defined(MSWIN)
static void ex_winpos(exarg_T *eap);
#else
# define ex_winpos          ex_ni
#endif
static void ex_operators(exarg_T *eap);
static void ex_put(exarg_T *eap);
static void ex_copymove(exarg_T *eap);
static void ex_may_print(exarg_T *eap);
static void ex_submagic(exarg_T *eap);
static void ex_join(exarg_T *eap);
static void ex_at(exarg_T *eap);
static void ex_bang(exarg_T *eap);
static void ex_undo(exarg_T *eap);
static void ex_wundo(exarg_T *eap);
static void ex_rundo(exarg_T *eap);
static void ex_redo(exarg_T *eap);
static void ex_later(exarg_T *eap);
static void ex_redir(exarg_T *eap);
static void ex_redraw(exarg_T *eap);
static void ex_redrawstatus(exarg_T *eap);
static void close_redir(void);
static void ex_mkrc(exarg_T *eap);
static void ex_mark(exarg_T *eap);
static char_u   *uc_fun_cmd(void);
static char_u   *find_ucmd(exarg_T *eap, char_u *p, int *full,
                           expand_T *xp,
                           int *compl);
static void ex_normal(exarg_T *eap);
static void ex_startinsert(exarg_T *eap);
static void ex_stopinsert(exarg_T *eap);
static void ex_checkpath(exarg_T *eap);
static void ex_findpat(exarg_T *eap);
static void ex_psearch(exarg_T *eap);
static void ex_tag(exarg_T *eap);
static void ex_tag_cmd(exarg_T *eap, char_u *name);
static char_u   *arg_all(void);
static int makeopens(FILE *fd, char_u *dirnow);
static int put_view(FILE *fd, win_T *wp, int add_edit, unsigned *flagp,
                    int current_arg_idx);
static void ex_loadview(exarg_T *eap);
static char_u   *get_view_file(int c);
static int did_lcd;             /* whether ":lcd" was produced for a session */
static void ex_viminfo(exarg_T *eap);
static void ex_behave(exarg_T *eap);
static void ex_filetype(exarg_T *eap);
static void ex_setfiletype(exarg_T *eap);
static void ex_digraphs(exarg_T *eap);
static void ex_set(exarg_T *eap);
static void ex_nohlsearch(exarg_T *eap);
static void ex_match(exarg_T *eap);
static void ex_X(exarg_T *eap);
static void ex_fold(exarg_T *eap);
static void ex_foldopen(exarg_T *eap);
static void ex_folddo(exarg_T *eap);
#ifndef HAVE_WORKING_LIBINTL
# define ex_language            ex_ni
#endif
# define ex_sign                ex_ni
# define ex_wsverb              ex_ni
# define ex_nbclose             ex_ni
# define ex_nbkey               ex_ni
# define ex_nbstart             ex_ni




/*
 * Declare cmdnames[].
 */
#define DO_DECLARE_EXCMD
#include "ex_cmds_defs.h"

/*
 * Table used to quickly search for a command, based on its first character.
 */
static cmdidx_T cmdidxs[27] =
{
  CMD_append,
  CMD_buffer,
  CMD_change,
  CMD_delete,
  CMD_edit,
  CMD_file,
  CMD_global,
  CMD_help,
  CMD_insert,
  CMD_join,
  CMD_k,
  CMD_list,
  CMD_move,
  CMD_next,
  CMD_open,
  CMD_print,
  CMD_quit,
  CMD_read,
  CMD_substitute,
  CMD_t,
  CMD_undo,
  CMD_vglobal,
  CMD_write,
  CMD_xit,
  CMD_yank,
  CMD_z,
  CMD_bang
};

static char_u dollar_command[2] = {'$', 0};


/* Struct for storing a line inside a while/for loop */
typedef struct {
  char_u      *line;            /* command line */
  linenr_T lnum;                /* sourcing_lnum of the line */
} wcmd_T;

/*
 * Structure used to store info for line position in a while or for loop.
 * This is required, because do_one_cmd() may invoke ex_function(), which
 * reads more lines that may come from the while/for loop.
 */
struct loop_cookie {
  garray_T    *lines_gap;               /* growarray with line info */
  int current_line;                     /* last read line from growarray */
  int repeating;                        /* TRUE when looping a second time */
  /* When "repeating" is FALSE use "getline" and "cookie" to get lines */
  char_u      *(*getline)(int, void *, int);
  void        *cookie;
};

static char_u   *get_loop_line(int c, void *cookie, int indent);
static int store_loop_line(garray_T *gap, char_u *line);
static void free_cmdlines(garray_T *gap);

/* Struct to save a few things while debugging.  Used in do_cmdline() only. */
struct dbg_stuff {
  int trylevel;
  int force_abort;
  except_T    *caught_stack;
  char_u      *vv_exception;
  char_u      *vv_throwpoint;
  int did_emsg;
  int got_int;
  int did_throw;
  int need_rethrow;
  int check_cstack;
  except_T    *current_exception;
};

static void save_dbg_stuff(struct dbg_stuff *dsp);
static void restore_dbg_stuff(struct dbg_stuff *dsp);

static void save_dbg_stuff(struct dbg_stuff *dsp)
{
  dsp->trylevel       = trylevel;             trylevel = 0;
  dsp->force_abort    = force_abort;          force_abort = FALSE;
  dsp->caught_stack   = caught_stack;         caught_stack = NULL;
  dsp->vv_exception   = v_exception(NULL);
  dsp->vv_throwpoint  = v_throwpoint(NULL);

  /* Necessary for debugging an inactive ":catch", ":finally", ":endtry" */
  dsp->did_emsg       = did_emsg;             did_emsg     = FALSE;
  dsp->got_int        = got_int;              got_int      = FALSE;
  dsp->did_throw      = did_throw;            did_throw    = FALSE;
  dsp->need_rethrow   = need_rethrow;         need_rethrow = FALSE;
  dsp->check_cstack   = check_cstack;         check_cstack = FALSE;
  dsp->current_exception = current_exception; current_exception = NULL;
}

static void restore_dbg_stuff(struct dbg_stuff *dsp)
{
  suppress_errthrow = FALSE;
  trylevel = dsp->trylevel;
  force_abort = dsp->force_abort;
  caught_stack = dsp->caught_stack;
  (void)v_exception(dsp->vv_exception);
  (void)v_throwpoint(dsp->vv_throwpoint);
  did_emsg = dsp->did_emsg;
  got_int = dsp->got_int;
  did_throw = dsp->did_throw;
  need_rethrow = dsp->need_rethrow;
  check_cstack = dsp->check_cstack;
  current_exception = dsp->current_exception;
}


/*
 * do_exmode(): Repeatedly get commands for the "Ex" mode, until the ":vi"
 * command is given.
 */
void 
do_exmode (
    int improved                       /* TRUE for "improved Ex" mode */
)
{
  int save_msg_scroll;
  int prev_msg_row;
  linenr_T prev_line;
  int changedtick;

  if (improved)
    exmode_active = EXMODE_VIM;
  else
    exmode_active = EXMODE_NORMAL;
  State = NORMAL;

  /* When using ":global /pat/ visual" and then "Q" we return to continue
   * the :global command. */
  if (global_busy)
    return;

  save_msg_scroll = msg_scroll;
  ++RedrawingDisabled;              /* don't redisplay the window */
  ++no_wait_return;                 /* don't wait for return */

  MSG(_("Entering Ex mode.  Type \"visual\" to go to Normal mode."));
  while (exmode_active) {
    /* Check for a ":normal" command and no more characters left. */
    if (ex_normal_busy > 0 && typebuf.tb_len == 0) {
      exmode_active = FALSE;
      break;
    }
    msg_scroll = TRUE;
    need_wait_return = FALSE;
    ex_pressedreturn = FALSE;
    ex_no_reprint = FALSE;
    changedtick = curbuf->b_changedtick;
    prev_msg_row = msg_row;
    prev_line = curwin->w_cursor.lnum;
    if (improved) {
      cmdline_row = msg_row;
      do_cmdline(NULL, getexline, NULL, 0);
    } else
      do_cmdline(NULL, getexmodeline, NULL, DOCMD_NOWAIT);
    lines_left = Rows - 1;

    if ((prev_line != curwin->w_cursor.lnum
         || changedtick != curbuf->b_changedtick) && !ex_no_reprint) {
      if (curbuf->b_ml.ml_flags & ML_EMPTY)
        EMSG(_(e_emptybuf));
      else {
        if (ex_pressedreturn) {
          /* go up one line, to overwrite the ":<CR>" line, so the
           * output doesn't contain empty lines. */
          msg_row = prev_msg_row;
          if (prev_msg_row == Rows - 1)
            msg_row--;
        }
        msg_col = 0;
        print_line_no_prefix(curwin->w_cursor.lnum, FALSE, FALSE);
        msg_clr_eos();
      }
    } else if (ex_pressedreturn && !ex_no_reprint)   {  /* must be at EOF */
      if (curbuf->b_ml.ml_flags & ML_EMPTY)
        EMSG(_(e_emptybuf));
      else
        EMSG(_("E501: At end-of-file"));
    }
  }

  --RedrawingDisabled;
  --no_wait_return;
  update_screen(CLEAR);
  need_wait_return = FALSE;
  msg_scroll = save_msg_scroll;
}

/*
 * Execute a simple command line.  Used for translated commands like "*".
 */
int do_cmdline_cmd(char_u *cmd)
{
  return do_cmdline(cmd, NULL, NULL,
      DOCMD_VERBOSE|DOCMD_NOWAIT|DOCMD_KEYTYPED);
}

/*
 * do_cmdline(): execute one Ex command line
 *
 * 1. Execute "cmdline" when it is not NULL.
 *    If "cmdline" is NULL, or more lines are needed, fgetline() is used.
 * 2. Split up in parts separated with '|'.
 *
 * This function can be called recursively!
 *
 * flags:
 * DOCMD_VERBOSE  - The command will be included in the error message.
 * DOCMD_NOWAIT   - Don't call wait_return() and friends.
 * DOCMD_REPEAT   - Repeat execution until fgetline() returns NULL.
 * DOCMD_KEYTYPED - Don't reset KeyTyped.
 * DOCMD_EXCRESET - Reset the exception environment (used for debugging).
 * DOCMD_KEEPLINE - Store first typed line (for repeating with ".").
 *
 * return FAIL if cmdline could not be executed, OK otherwise
 */
int do_cmdline(cmdline, fgetline, cookie, flags)
char_u      *cmdline;
char_u      *(*fgetline)(int, void *, int);
void        *cookie;                    /* argument for fgetline() */
int flags;
{
  char_u      *next_cmdline;            /* next cmd to execute */
  char_u      *cmdline_copy = NULL;     /* copy of cmd line */
  int used_getline = FALSE;             /* used "fgetline" to obtain command */
  static int recursive = 0;             /* recursive depth */
  int msg_didout_before_start = 0;
  int count = 0;                        /* line number count */
  int did_inc = FALSE;                  /* incremented RedrawingDisabled */
  int retval = OK;
  struct condstack cstack;              /* conditional stack */
  garray_T lines_ga;                    /* keep lines for ":while"/":for" */
  int current_line = 0;                 /* active line in lines_ga */
  char_u      *fname = NULL;            /* function or script name */
  linenr_T    *breakpoint = NULL;       /* ptr to breakpoint field in cookie */
  int         *dbg_tick = NULL;         /* ptr to dbg_tick field in cookie */
  struct dbg_stuff debug_saved;         /* saved things for debug mode */
  int initial_trylevel;
  struct msglist      **saved_msg_list = NULL;
  struct msglist      *private_msg_list;

  /* "fgetline" and "cookie" passed to do_one_cmd() */
  char_u      *(*cmd_getline)(int, void *, int);
  void        *cmd_cookie;
  struct loop_cookie cmd_loop_cookie;
  void        *real_cookie;
  int getline_is_func;
  static int call_depth = 0;            /* recursiveness */

  /* For every pair of do_cmdline()/do_one_cmd() calls, use an extra memory
   * location for storing error messages to be converted to an exception.
   * This ensures that the do_errthrow() call in do_one_cmd() does not
   * combine the messages stored by an earlier invocation of do_one_cmd()
   * with the command name of the later one.  This would happen when
   * BufWritePost autocommands are executed after a write error. */
  saved_msg_list = msg_list;
  msg_list = &private_msg_list;
  private_msg_list = NULL;

  /* It's possible to create an endless loop with ":execute", catch that
   * here.  The value of 200 allows nested function calls, ":source", etc. */
  if (call_depth == 200) {
    EMSG(_("E169: Command too recursive"));
    /* When converting to an exception, we do not include the command name
     * since this is not an error of the specific command. */
    do_errthrow((struct condstack *)NULL, (char_u *)NULL);
    msg_list = saved_msg_list;
    return FAIL;
  }
  ++call_depth;

  cstack.cs_idx = -1;
  cstack.cs_looplevel = 0;
  cstack.cs_trylevel = 0;
  cstack.cs_emsg_silent_list = NULL;
  cstack.cs_lflags = 0;
  ga_init2(&lines_ga, (int)sizeof(wcmd_T), 10);

  real_cookie = getline_cookie(fgetline, cookie);

  /* Inside a function use a higher nesting level. */
  getline_is_func = getline_equal(fgetline, cookie, get_func_line);
  if (getline_is_func && ex_nesting_level == func_level(real_cookie))
    ++ex_nesting_level;

  /* Get the function or script name and the address where the next breakpoint
   * line and the debug tick for a function or script are stored. */
  if (getline_is_func) {
    fname = func_name(real_cookie);
    breakpoint = func_breakpoint(real_cookie);
    dbg_tick = func_dbg_tick(real_cookie);
  } else if (getline_equal(fgetline, cookie, getsourceline))   {
    fname = sourcing_name;
    breakpoint = source_breakpoint(real_cookie);
    dbg_tick = source_dbg_tick(real_cookie);
  }

  /*
   * Initialize "force_abort"  and "suppress_errthrow" at the top level.
   */
  if (!recursive) {
    force_abort = FALSE;
    suppress_errthrow = FALSE;
  }

  /*
   * If requested, store and reset the global values controlling the
   * exception handling (used when debugging).  Otherwise clear it to avoid
   * a bogus compiler warning when the optimizer uses inline functions...
   */
  if (flags & DOCMD_EXCRESET)
    save_dbg_stuff(&debug_saved);
  else
    vim_memset(&debug_saved, 0, 1);

  initial_trylevel = trylevel;

  /*
   * "did_throw" will be set to TRUE when an exception is being thrown.
   */
  did_throw = FALSE;
  /*
   * "did_emsg" will be set to TRUE when emsg() is used, in which case we
   * cancel the whole command line, and any if/endif or loop.
   * If force_abort is set, we cancel everything.
   */
  did_emsg = FALSE;

  /*
   * KeyTyped is only set when calling vgetc().  Reset it here when not
   * calling vgetc() (sourced command lines).
   */
  if (!(flags & DOCMD_KEYTYPED)
      && !getline_equal(fgetline, cookie, getexline))
    KeyTyped = FALSE;

  /*
   * Continue executing command lines:
   * - when inside an ":if", ":while" or ":for"
   * - for multiple commands on one line, separated with '|'
   * - when repeating until there are no more lines (for ":source")
   */
  next_cmdline = cmdline;
  do {
    getline_is_func = getline_equal(fgetline, cookie, get_func_line);

    /* stop skipping cmds for an error msg after all endif/while/for */
    if (next_cmdline == NULL
        && !force_abort
        && cstack.cs_idx < 0
        && !(getline_is_func && func_has_abort(real_cookie))
        )
      did_emsg = FALSE;

    /*
     * 1. If repeating a line in a loop, get a line from lines_ga.
     * 2. If no line given: Get an allocated line with fgetline().
     * 3. If a line is given: Make a copy, so we can mess with it.
     */

    /* 1. If repeating, get a previous line from lines_ga. */
    if (cstack.cs_looplevel > 0 && current_line < lines_ga.ga_len) {
      /* Each '|' separated command is stored separately in lines_ga, to
       * be able to jump to it.  Don't use next_cmdline now. */
      vim_free(cmdline_copy);
      cmdline_copy = NULL;

      /* Check if a function has returned or, unless it has an unclosed
       * try conditional, aborted. */
      if (getline_is_func) {
        if (do_profiling == PROF_YES)
          func_line_end(real_cookie);
        if (func_has_ended(real_cookie)) {
          retval = FAIL;
          break;
        }
      } else if (do_profiling == PROF_YES
                 && getline_equal(fgetline, cookie, getsourceline))
        script_line_end();

      /* Check if a sourced file hit a ":finish" command. */
      if (source_finished(fgetline, cookie)) {
        retval = FAIL;
        break;
      }

      /* If breakpoints have been added/deleted need to check for it. */
      if (breakpoint != NULL && dbg_tick != NULL
          && *dbg_tick != debug_tick) {
        *breakpoint = dbg_find_breakpoint(
            getline_equal(fgetline, cookie, getsourceline),
            fname, sourcing_lnum);
        *dbg_tick = debug_tick;
      }

      next_cmdline = ((wcmd_T *)(lines_ga.ga_data))[current_line].line;
      sourcing_lnum = ((wcmd_T *)(lines_ga.ga_data))[current_line].lnum;

      /* Did we encounter a breakpoint? */
      if (breakpoint != NULL && *breakpoint != 0
          && *breakpoint <= sourcing_lnum) {
        dbg_breakpoint(fname, sourcing_lnum);
        /* Find next breakpoint. */
        *breakpoint = dbg_find_breakpoint(
            getline_equal(fgetline, cookie, getsourceline),
            fname, sourcing_lnum);
        *dbg_tick = debug_tick;
      }
      if (do_profiling == PROF_YES) {
        if (getline_is_func)
          func_line_start(real_cookie);
        else if (getline_equal(fgetline, cookie, getsourceline))
          script_line_start();
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
    } else   {
      cmd_getline = fgetline;
      cmd_cookie = cookie;
    }

    /* 2. If no line given, get an allocated line with fgetline(). */
    if (next_cmdline == NULL) {
      /*
       * Need to set msg_didout for the first line after an ":if",
       * otherwise the ":if" will be overwritten.
       */
      if (count == 1 && getline_equal(fgetline, cookie, getexline))
        msg_didout = TRUE;
      if (fgetline == NULL || (next_cmdline = fgetline(':', cookie,
                                   cstack.cs_idx <
                                   0 ? 0 : (cstack.cs_idx + 1) * 2
                                   )) == NULL) {
        /* Don't call wait_return for aborted command line.  The NULL
         * returned for the end of a sourced file or executed function
         * doesn't do this. */
        if (KeyTyped && !(flags & DOCMD_REPEAT))
          need_wait_return = FALSE;
        retval = FAIL;
        break;
      }
      used_getline = TRUE;

      /*
       * Keep the first typed line.  Clear it when more lines are typed.
       */
      if (flags & DOCMD_KEEPLINE) {
        vim_free(repeat_cmdline);
        if (count == 0)
          repeat_cmdline = vim_strsave(next_cmdline);
        else
          repeat_cmdline = NULL;
      }
    }
    /* 3. Make a copy of the command so we can mess with it. */
    else if (cmdline_copy == NULL) {
      next_cmdline = vim_strsave(next_cmdline);
      if (next_cmdline == NULL) {
        EMSG(_(e_outofmem));
        retval = FAIL;
        break;
      }
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
      if (store_loop_line(&lines_ga, next_cmdline) == FAIL) {
        retval = FAIL;
        break;
      }
    }
    did_endif = FALSE;

    if (count++ == 0) {
      /*
       * All output from the commands is put below each other, without
       * waiting for a return. Don't do this when executing commands
       * from a script or when being called recursive (e.g. for ":e
       * +command file").
       */
      if (!(flags & DOCMD_NOWAIT) && !recursive) {
        msg_didout_before_start = msg_didout;
        msg_didany = FALSE;         /* no output yet */
        msg_start();
        msg_scroll = TRUE;          /* put messages below each other */
        ++no_wait_return;           /* don't wait for return until finished */
        ++RedrawingDisabled;
        did_inc = TRUE;
      }
    }

    if (p_verbose >= 15 && sourcing_name != NULL) {
      ++no_wait_return;
      verbose_enter_scroll();

      smsg((char_u *)_("line %ld: %s"),
          (long)sourcing_lnum, cmdline_copy);
      if (msg_silent == 0)
        msg_puts((char_u *)"\n");           /* don't overwrite this */

      verbose_leave_scroll();
      --no_wait_return;
    }

    /*
     * 2. Execute one '|' separated command.
     *    do_one_cmd() will return NULL if there is no trailing '|'.
     *    "cmdline_copy" can change, e.g. for '%' and '#' expansion.
     */
    ++recursive;
    next_cmdline = do_one_cmd(&cmdline_copy, flags & DOCMD_VERBOSE,
        &cstack,
        cmd_getline, cmd_cookie);
    --recursive;

    if (cmd_cookie == (void *)&cmd_loop_cookie)
      /* Use "current_line" from "cmd_loop_cookie", it may have been
       * incremented when defining a function. */
      current_line = cmd_loop_cookie.current_line;

    if (next_cmdline == NULL) {
      vim_free(cmdline_copy);
      cmdline_copy = NULL;
      /*
       * If the command was typed, remember it for the ':' register.
       * Do this AFTER executing the command to make :@: work.
       */
      if (getline_equal(fgetline, cookie, getexline)
          && new_last_cmdline != NULL) {
        vim_free(last_cmdline);
        last_cmdline = new_last_cmdline;
        new_last_cmdline = NULL;
      }
    } else   {
      /* need to copy the command after the '|' to cmdline_copy, for the
       * next do_one_cmd() */
      STRMOVE(cmdline_copy, next_cmdline);
      next_cmdline = cmdline_copy;
    }


    /* reset did_emsg for a function that is not aborted by an error */
    if (did_emsg && !force_abort
        && getline_equal(fgetline, cookie, get_func_line)
        && !func_has_abort(real_cookie))
      did_emsg = FALSE;

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
        if (!did_emsg && !got_int && !did_throw
            && cstack.cs_idx >= 0
            && (cstack.cs_flags[cstack.cs_idx]
                & (CSF_WHILE | CSF_FOR))
            && cstack.cs_line[cstack.cs_idx] >= 0
            && (cstack.cs_flags[cstack.cs_idx] & CSF_ACTIVE)) {
          current_line = cstack.cs_line[cstack.cs_idx];
          /* remember we jumped there */
          cstack.cs_lflags |= CSL_HAD_LOOP;
          line_breakcheck();                    /* check if CTRL-C typed */

          /* Check for the next breakpoint at or after the ":while"
           * or ":for". */
          if (breakpoint != NULL) {
            *breakpoint = dbg_find_breakpoint(
                getline_equal(fgetline, cookie, getsourceline),
                fname,
                ((wcmd_T *)lines_ga.ga_data)[current_line].lnum-1);
            *dbg_tick = debug_tick;
          }
        } else   {
          /* can only get here with ":endwhile" or ":endfor" */
          if (cstack.cs_idx >= 0)
            rewind_conditionals(&cstack, cstack.cs_idx - 1,
                CSF_WHILE | CSF_FOR, &cstack.cs_looplevel);
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
      if (lines_ga.ga_len > 0) {
        sourcing_lnum =
          ((wcmd_T *)lines_ga.ga_data)[lines_ga.ga_len - 1].lnum;
        free_cmdlines(&lines_ga);
      }
      current_line = 0;
    }

    /*
     * A ":finally" makes did_emsg, got_int, and did_throw pending for
     * being restored at the ":endtry".  Reset them here and set the
     * ACTIVE and FINALLY flags, so that the finally clause gets executed.
     * This includes the case where a missing ":endif", ":endwhile" or
     * ":endfor" was detected by the ":finally" itself.
     */
    if (cstack.cs_lflags & CSL_HAD_FINA) {
      cstack.cs_lflags &= ~CSL_HAD_FINA;
      report_make_pending(cstack.cs_pending[cstack.cs_idx]
          & (CSTP_ERROR | CSTP_INTERRUPT | CSTP_THROW),
          did_throw ? (void *)current_exception : NULL);
      did_emsg = got_int = did_throw = FALSE;
      cstack.cs_flags[cstack.cs_idx] |= CSF_ACTIVE | CSF_FINALLY;
    }

    /* Update global "trylevel" for recursive calls to do_cmdline() from
     * within this loop. */
    trylevel = initial_trylevel + cstack.cs_trylevel;

    /*
     * If the outermost try conditional (across function calls and sourced
     * files) is aborted because of an error, an interrupt, or an uncaught
     * exception, cancel everything.  If it is left normally, reset
     * force_abort to get the non-EH compatible abortion behavior for
     * the rest of the script.
     */
    if (trylevel == 0 && !did_emsg && !got_int && !did_throw)
      force_abort = FALSE;

    /* Convert an interrupt to an exception if appropriate. */
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
  while (!((got_int
            || (did_emsg && force_abort) || did_throw
            )
           && cstack.cs_trylevel == 0
           )
         && !(did_emsg
              /* Keep going when inside try/catch, so that the error can be
               * deal with, except when it is a syntax error, it may cause
               * the :endtry to be missed. */
              && (cstack.cs_trylevel == 0 || did_emsg_syntax)
              && used_getline
              && (getline_equal(fgetline, cookie, getexmodeline)
                  || getline_equal(fgetline, cookie, getexline)))
         && (next_cmdline != NULL
             || cstack.cs_idx >= 0
             || (flags & DOCMD_REPEAT)));

  vim_free(cmdline_copy);
  did_emsg_syntax = FALSE;
  free_cmdlines(&lines_ga);
  ga_clear(&lines_ga);

  if (cstack.cs_idx >= 0) {
    /*
     * If a sourced file or executed function ran to its end, report the
     * unclosed conditional.
     */
    if (!got_int && !did_throw
        && ((getline_equal(fgetline, cookie, getsourceline)
             && !source_finished(fgetline, cookie))
            || (getline_equal(fgetline, cookie, get_func_line)
                && !func_has_ended(real_cookie)))) {
      if (cstack.cs_flags[cstack.cs_idx] & CSF_TRY)
        EMSG(_(e_endtry));
      else if (cstack.cs_flags[cstack.cs_idx] & CSF_WHILE)
        EMSG(_(e_endwhile));
      else if (cstack.cs_flags[cstack.cs_idx] & CSF_FOR)
        EMSG(_(e_endfor));
      else
        EMSG(_(e_endif));
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

      if (idx >= 0)
        --idx;              /* remove try block not in its finally clause */
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
    /*
     * When an exception is being thrown out of the outermost try
     * conditional, discard the uncaught exception, disable the conversion
     * of interrupts or errors to exceptions, and ensure that no more
     * commands are executed.
     */
    if (did_throw) {
      void        *p = NULL;
      char_u      *saved_sourcing_name;
      int saved_sourcing_lnum;
      struct msglist      *messages = NULL, *next;

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
      default:
        p = vim_strsave((char_u *)_(e_internal));
      }

      saved_sourcing_name = sourcing_name;
      saved_sourcing_lnum = sourcing_lnum;
      sourcing_name = current_exception->throw_name;
      sourcing_lnum = current_exception->throw_lnum;
      current_exception->throw_name = NULL;

      discard_current_exception();              /* uses IObuff if 'verbose' */
      suppress_errthrow = TRUE;
      force_abort = TRUE;

      if (messages != NULL) {
        do {
          next = messages->next;
          emsg(messages->msg);
          vim_free(messages->msg);
          vim_free(messages);
          messages = next;
        } while (messages != NULL);
      } else if (p != NULL)   {
        emsg(p);
        vim_free(p);
      }
      vim_free(sourcing_name);
      sourcing_name = saved_sourcing_name;
      sourcing_lnum = saved_sourcing_lnum;
    }
    /*
     * On an interrupt or an aborting error not converted to an exception,
     * disable the conversion of errors to exceptions.  (Interrupts are not
     * converted any more, here.) This enables also the interrupt message
     * when force_abort is set and did_emsg unset in case of an interrupt
     * from a finally clause after an error.
     */
    else if (got_int || (did_emsg && force_abort))
      suppress_errthrow = TRUE;
  }

  /*
   * The current cstack will be freed when do_cmdline() returns.  An uncaught
   * exception will have to be rethrown in the previous cstack.  If a function
   * has just returned or a script file was just finished and the previous
   * cstack belongs to the same function or, respectively, script file, it
   * will have to be checked for finally clauses to be executed due to the
   * ":return" or ":finish".  This is done in do_one_cmd().
   */
  if (did_throw)
    need_rethrow = TRUE;
  if ((getline_equal(fgetline, cookie, getsourceline)
       && ex_nesting_level > source_level(real_cookie))
      || (getline_equal(fgetline, cookie, get_func_line)
          && ex_nesting_level > func_level(real_cookie) + 1)) {
    if (!did_throw)
      check_cstack = TRUE;
  } else   {
    /* When leaving a function, reduce nesting level. */
    if (getline_equal(fgetline, cookie, get_func_line))
      --ex_nesting_level;
    /*
     * Go to debug mode when returning from a function in which we are
     * single-stepping.
     */
    if ((getline_equal(fgetline, cookie, getsourceline)
         || getline_equal(fgetline, cookie, get_func_line))
        && ex_nesting_level + 1 <= debug_break_level)
      do_debug(getline_equal(fgetline, cookie, getsourceline)
          ? (char_u *)_("End of sourced file")
          : (char_u *)_("End of function"));
  }

  /*
   * Restore the exception environment (done after returning from the
   * debugger).
   */
  if (flags & DOCMD_EXCRESET)
    restore_dbg_stuff(&debug_saved);

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
        || (did_endif && KeyTyped && !did_emsg)
        ) {
      need_wait_return = FALSE;
      msg_didany = FALSE;               /* don't wait when restarting edit */
    } else if (need_wait_return)   {
      /*
       * The msg_start() above clears msg_didout. The wait_return we do
       * here should not overwrite the command that may be shown before
       * doing that.
       */
      msg_didout |= msg_didout_before_start;
      wait_return(FALSE);
    }
  }

  did_endif = FALSE;    /* in case do_cmdline used recursively */

  --call_depth;
  return retval;
}

/*
 * Obtain a line when inside a ":while" or ":for" loop.
 */
static char_u *get_loop_line(int c, void *cookie, int indent)
{
  struct loop_cookie  *cp = (struct loop_cookie *)cookie;
  wcmd_T              *wp;
  char_u              *line;

  if (cp->current_line + 1 >= cp->lines_gap->ga_len) {
    if (cp->repeating)
      return NULL;              /* trying to read past ":endwhile"/":endfor" */

    /* First time inside the ":while"/":for": get line normally. */
    if (cp->getline == NULL)
      line = getcmdline(c, 0L, indent);
    else
      line = cp->getline(c, cp->cookie, indent);
    if (line != NULL && store_loop_line(cp->lines_gap, line) == OK)
      ++cp->current_line;

    return line;
  }

  KeyTyped = FALSE;
  ++cp->current_line;
  wp = (wcmd_T *)(cp->lines_gap->ga_data) + cp->current_line;
  sourcing_lnum = wp->lnum;
  return vim_strsave(wp->line);
}

/*
 * Store a line in "gap" so that a ":while" loop can execute it again.
 */
static int store_loop_line(garray_T *gap, char_u *line)
{
  if (ga_grow(gap, 1) == FAIL)
    return FAIL;
  ((wcmd_T *)(gap->ga_data))[gap->ga_len].line = vim_strsave(line);
  ((wcmd_T *)(gap->ga_data))[gap->ga_len].lnum = sourcing_lnum;
  ++gap->ga_len;
  return OK;
}

/*
 * Free the lines stored for a ":while" or ":for" loop.
 */
static void free_cmdlines(garray_T *gap)
{
  while (gap->ga_len > 0) {
    vim_free(((wcmd_T *)(gap->ga_data))[gap->ga_len - 1].line);
    --gap->ga_len;
  }
}

/*
 * If "fgetline" is get_loop_line(), return TRUE if the getline it uses equals
 * "func".  * Otherwise return TRUE when "fgetline" equals "func".
 */
int getline_equal(fgetline, cookie, func)
char_u      *(*fgetline)(int, void *, int);
void        *cookie;             /* argument for fgetline() */
char_u      *(*func)(int, void *, int);
{
  char_u              *(*gp)(int, void *, int);
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

/*
 * If "fgetline" is get_loop_line(), return the cookie used by the original
 * getline function.  Otherwise return "cookie".
 */
void * getline_cookie(fgetline, cookie)
char_u      *(*fgetline)(int, void *, int);
void        *cookie;                    /* argument for fgetline() */
{
  char_u              *(*gp)(int, void *, int);
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
 * Execute one Ex command.
 *
 * If 'sourcing' is TRUE, the command will be included in the error message.
 *
 * 1. skip comment lines and leading space
 * 2. handle command modifiers
 * 3. parse range
 * 4. parse command
 * 5. parse arguments
 * 6. switch on command name
 *
 * Note: "fgetline" can be NULL.
 *
 * This function may be called recursively!
 */
static char_u * do_one_cmd(cmdlinep, sourcing,
    cstack,
    fgetline, cookie)
char_u              **cmdlinep;
int sourcing;
struct condstack    *cstack;
char_u              *(*fgetline)(int, void *, int);
void                *cookie;                    /*argument for fgetline() */
{
  char_u              *p;
  linenr_T lnum;
  long n;
  char_u              *errormsg = NULL;         /* error message */
  exarg_T ea;                                   /* Ex command arguments */
  long verbose_save = -1;
  int save_msg_scroll = msg_scroll;
  int save_msg_silent = -1;
  int did_esilent = 0;
#ifdef HAVE_SANDBOX
  int did_sandbox = FALSE;
#endif
  cmdmod_T save_cmdmod;
  int ni;                                       /* set when Not Implemented */

  vim_memset(&ea, 0, sizeof(ea));
  ea.line1 = 1;
  ea.line2 = 1;
  ++ex_nesting_level;

  /* When the last file has not been edited :q has to be typed twice. */
  if (quitmore
      /* avoid that a function call in 'statusline' does this */
      && !getline_equal(fgetline, cookie, get_func_line)
      /* avoid that an autocommand, e.g. QuitPre, does this */
      && !getline_equal(fgetline, cookie, getnextac)
      )
    --quitmore;

  /*
   * Reset browse, confirm, etc..  They are restored when returning, for
   * recursive calls.
   */
  save_cmdmod = cmdmod;
  vim_memset(&cmdmod, 0, sizeof(cmdmod));

  /* "#!anything" is handled like a comment. */
  if ((*cmdlinep)[0] == '#' && (*cmdlinep)[1] == '!')
    goto doend;

  /*
   * Repeat until no more command modifiers are found.
   */
  ea.cmd = *cmdlinep;
  for (;; ) {
    /*
     * 1. skip comment lines and leading white space and colons
     */
    while (*ea.cmd == ' ' || *ea.cmd == '\t' || *ea.cmd == ':')
      ++ea.cmd;

    /* in ex mode, an empty line works like :+ */
    if (*ea.cmd == NUL && exmode_active
        && (getline_equal(fgetline, cookie, getexmodeline)
            || getline_equal(fgetline, cookie, getexline))
        && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
      ea.cmd = (char_u *)"+";
      ex_pressedreturn = TRUE;
    }

    /* ignore comment and empty lines */
    if (*ea.cmd == '"')
      goto doend;
    if (*ea.cmd == NUL) {
      ex_pressedreturn = TRUE;
      goto doend;
    }

    /*
     * 2. handle command modifiers.
     */
    p = ea.cmd;
    if (VIM_ISDIGIT(*ea.cmd))
      p = skipwhite(skipdigits(ea.cmd));
    switch (*p) {
    /* When adding an entry, also modify cmd_exists(). */
    case 'a':   if (!checkforcmd(&ea.cmd, "aboveleft", 3))
        break;
      cmdmod.split |= WSP_ABOVE;
      continue;

    case 'b':   if (checkforcmd(&ea.cmd, "belowright", 3)) {
        cmdmod.split |= WSP_BELOW;
        continue;
    }
      if (checkforcmd(&ea.cmd, "browse", 3)) {
        continue;
      }
      if (!checkforcmd(&ea.cmd, "botright", 2))
        break;
      cmdmod.split |= WSP_BOT;
      continue;

    case 'c':   if (!checkforcmd(&ea.cmd, "confirm", 4))
        break;
      cmdmod.confirm = TRUE;
      continue;

    case 'k':   if (checkforcmd(&ea.cmd, "keepmarks", 3)) {
        cmdmod.keepmarks = TRUE;
        continue;
    }
      if (checkforcmd(&ea.cmd, "keepalt", 5)) {
        cmdmod.keepalt = TRUE;
        continue;
      }
      if (checkforcmd(&ea.cmd, "keeppatterns", 5)) {
        cmdmod.keeppatterns = TRUE;
        continue;
      }
      if (!checkforcmd(&ea.cmd, "keepjumps", 5))
        break;
      cmdmod.keepjumps = TRUE;
      continue;

    /* ":hide" and ":hide | cmd" are not modifiers */
    case 'h':   if (p != ea.cmd || !checkforcmd(&p, "hide", 3)
                    || *p == NUL || ends_excmd(*p))
        break;
      ea.cmd = p;
      cmdmod.hide = TRUE;
      continue;

    case 'l':   if (checkforcmd(&ea.cmd, "lockmarks", 3)) {
        cmdmod.lockmarks = TRUE;
        continue;
    }

      if (!checkforcmd(&ea.cmd, "leftabove", 5))
        break;
      cmdmod.split |= WSP_ABOVE;
      continue;

    case 'n':   if (!checkforcmd(&ea.cmd, "noautocmd", 3))
        break;
      if (cmdmod.save_ei == NULL) {
        /* Set 'eventignore' to "all". Restore the
         * existing option value later. */
        cmdmod.save_ei = vim_strsave(p_ei);
        set_string_option_direct((char_u *)"ei", -1,
            (char_u *)"all", OPT_FREE, SID_NONE);
      }
      continue;

    case 'r':   if (!checkforcmd(&ea.cmd, "rightbelow", 6))
        break;
      cmdmod.split |= WSP_BELOW;
      continue;

    case 's':   if (checkforcmd(&ea.cmd, "sandbox", 3)) {
#ifdef HAVE_SANDBOX
        if (!did_sandbox)
          ++sandbox;
        did_sandbox = TRUE;
#endif
        continue;
    }
      if (!checkforcmd(&ea.cmd, "silent", 3))
        break;
      if (save_msg_silent == -1)
        save_msg_silent = msg_silent;
      ++msg_silent;
      if (*ea.cmd == '!' && !vim_iswhite(ea.cmd[-1])) {
        /* ":silent!", but not "silent !cmd" */
        ea.cmd = skipwhite(ea.cmd + 1);
        ++emsg_silent;
        ++did_esilent;
      }
      continue;

    case 't':   if (checkforcmd(&p, "tab", 3)) {
        if (vim_isdigit(*ea.cmd))
          cmdmod.tab = atoi((char *)ea.cmd) + 1;
        else
          cmdmod.tab = tabpage_index(curtab) + 1;
        ea.cmd = p;
        continue;
    }
      if (!checkforcmd(&ea.cmd, "topleft", 2))
        break;
      cmdmod.split |= WSP_TOP;
      continue;

    case 'u':   if (!checkforcmd(&ea.cmd, "unsilent", 3))
        break;
      if (save_msg_silent == -1)
        save_msg_silent = msg_silent;
      msg_silent = 0;
      continue;

    case 'v':   if (checkforcmd(&ea.cmd, "vertical", 4)) {
        cmdmod.split |= WSP_VERT;
        continue;
    }
      if (!checkforcmd(&p, "verbose", 4))
        break;
      if (verbose_save < 0)
        verbose_save = p_verbose;
      if (vim_isdigit(*ea.cmd))
        p_verbose = atoi((char *)ea.cmd);
      else
        p_verbose = 1;
      ea.cmd = p;
      continue;
    }
    break;
  }

  ea.skip = did_emsg || got_int || did_throw || (cstack->cs_idx >= 0
                                                 && !(cstack->cs_flags[cstack->
                                                                       cs_idx]
                                                      & CSF_ACTIVE));

  /* Count this line for profiling if ea.skip is FALSE. */
  if (do_profiling == PROF_YES && !ea.skip) {
    if (getline_equal(fgetline, cookie, get_func_line))
      func_line_exec(getline_cookie(fgetline, cookie));
    else if (getline_equal(fgetline, cookie, getsourceline))
      script_line_exec();
  }

  /* May go to debug mode.  If this happens and the ">quit" debug command is
   * used, throw an interrupt exception and skip the next command. */
  dbg_check_breakpoint(&ea);
  if (!ea.skip && got_int) {
    ea.skip = TRUE;
    (void)do_intthrow(cstack);
  }

  /*
   * 3. parse a range specifier of the form: addr [,addr] [;addr] ..
   *
   * where 'addr' is:
   *
   * %	      (entire file)
   * $  [+-NUM]
   * 'x [+-NUM] (where x denotes a currently defined mark)
   * .  [+-NUM]
   * [+-NUM]..
   * NUM
   *
   * The ea.cmd pointer is updated to point to the first character following the
   * range spec. If an initial address is found, but no second, the upper bound
   * is equal to the lower.
   */

  /* repeat for all ',' or ';' separated addresses */
  for (;; ) {
    ea.line1 = ea.line2;
    ea.line2 = curwin->w_cursor.lnum;       /* default is current line number */
    ea.cmd = skipwhite(ea.cmd);
    lnum = get_address(&ea.cmd, ea.skip, ea.addr_count == 0);
    if (ea.cmd == NULL)                     /* error detected */
      goto doend;
    if (lnum == MAXLNUM) {
      if (*ea.cmd == '%') {                 /* '%' - all lines */
        ++ea.cmd;
        ea.line1 = 1;
        ea.line2 = curbuf->b_ml.ml_line_count;
        ++ea.addr_count;
      }
      /* '*' - visual area */
      else if (*ea.cmd == '*' && vim_strchr(p_cpo, CPO_STAR) == NULL) {
        pos_T       *fp;

        ++ea.cmd;
        if (!ea.skip) {
          fp = getmark('<', FALSE);
          if (check_mark(fp) == FAIL)
            goto doend;
          ea.line1 = fp->lnum;
          fp = getmark('>', FALSE);
          if (check_mark(fp) == FAIL)
            goto doend;
          ea.line2 = fp->lnum;
          ++ea.addr_count;
        }
      }
    } else
      ea.line2 = lnum;
    ea.addr_count++;

    if (*ea.cmd == ';') {
      if (!ea.skip)
        curwin->w_cursor.lnum = ea.line2;
    } else if (*ea.cmd != ',')
      break;
    ++ea.cmd;
  }

  /* One address given: set start and end lines */
  if (ea.addr_count == 1) {
    ea.line1 = ea.line2;
    /* ... but only implicit: really no address given */
    if (lnum == MAXLNUM)
      ea.addr_count = 0;
  }

  /* Don't leave the cursor on an illegal line (caused by ';') */
  check_cursor_lnum();

  /*
   * 4. parse command
   */

  /*
   * Skip ':' and any white space
   */
  ea.cmd = skipwhite(ea.cmd);
  while (*ea.cmd == ':')
    ea.cmd = skipwhite(ea.cmd + 1);

  /*
   * If we got a line, but no command, then go to the line.
   * If we find a '|' or '\n' we set ea.nextcmd.
   */
  if (*ea.cmd == NUL || *ea.cmd == '"' ||
      (ea.nextcmd = check_nextcmd(ea.cmd)) != NULL) {
    /*
     * strange vi behaviour:
     * ":3"		jumps to line 3
     * ":3|..."	prints line 3
     * ":|"		prints current line
     */
    if (ea.skip)            /* skip this if inside :if */
      goto doend;
    if (*ea.cmd == '|' || (exmode_active && ea.line1 != ea.line2)) {
      ea.cmdidx = CMD_print;
      ea.argt = RANGE+COUNT+TRLBAR;
      if ((errormsg = invalid_range(&ea)) == NULL) {
        correct_range(&ea);
        ex_print(&ea);
      }
    } else if (ea.addr_count != 0)   {
      if (ea.line2 > curbuf->b_ml.ml_line_count) {
        /* With '-' in 'cpoptions' a line number past the file is an
         * error, otherwise put it at the end of the file. */
        if (vim_strchr(p_cpo, CPO_MINUS) != NULL)
          ea.line2 = -1;
        else
          ea.line2 = curbuf->b_ml.ml_line_count;
      }

      if (ea.line2 < 0)
        errormsg = (char_u *)_(e_invrange);
      else {
        if (ea.line2 == 0)
          curwin->w_cursor.lnum = 1;
        else
          curwin->w_cursor.lnum = ea.line2;
        beginline(BL_SOL | BL_FIX);
      }
    }
    goto doend;
  }

  /* Find the command and let "p" point to after it. */
  p = find_command(&ea, NULL);

  if (p == NULL) {
    if (!ea.skip)
      errormsg = (char_u *)_("E464: Ambiguous use of user-defined command");
    goto doend;
  }
  /* Check for wrong commands. */
  if (*p == '!' && ea.cmd[1] == 0151 && ea.cmd[0] == 78) {
    errormsg = uc_fun_cmd();
    goto doend;
  }
  if (ea.cmdidx == CMD_SIZE) {
    if (!ea.skip) {
      STRCPY(IObuff, _("E492: Not an editor command"));
      if (!sourcing)
        append_command(*cmdlinep);
      errormsg = IObuff;
      did_emsg_syntax = TRUE;
    }
    goto doend;
  }

  ni = (
    !USER_CMDIDX(ea.cmdidx) &&
    (cmdnames[ea.cmdidx].cmd_func == ex_ni
#ifdef HAVE_EX_SCRIPT_NI
     || cmdnames[ea.cmdidx].cmd_func == ex_script_ni
#endif
    ));


  /* forced commands */
  if (*p == '!' && ea.cmdidx != CMD_substitute
      && ea.cmdidx != CMD_smagic && ea.cmdidx != CMD_snomagic) {
    ++p;
    ea.forceit = TRUE;
  } else
    ea.forceit = FALSE;

  /*
   * 5. parse arguments
   */
  if (!USER_CMDIDX(ea.cmdidx))
    ea.argt = (long)cmdnames[(int)ea.cmdidx].cmd_argt;

  if (!ea.skip) {
#ifdef HAVE_SANDBOX
    if (sandbox != 0 && !(ea.argt & SBOXOK)) {
      /* Command not allowed in sandbox. */
      errormsg = (char_u *)_(e_sandbox);
      goto doend;
    }
#endif
    if (!curbuf->b_p_ma && (ea.argt & MODIFY)) {
      /* Command not allowed in non-'modifiable' buffer */
      errormsg = (char_u *)_(e_modifiable);
      goto doend;
    }

    if (text_locked() && !(ea.argt & CMDWIN)
        && !USER_CMDIDX(ea.cmdidx)
        ) {
      /* Command not allowed when editing the command line. */
      if (cmdwin_type != 0)
        errormsg = (char_u *)_(e_cmdwin);
      else
        errormsg = (char_u *)_(e_secure);
      goto doend;
    }
    /* Disallow editing another buffer when "curbuf_lock" is set.
     * Do allow ":edit" (check for argument later).
     * Do allow ":checktime" (it's postponed). */
    if (!(ea.argt & CMDWIN)
        && ea.cmdidx != CMD_edit
        && ea.cmdidx != CMD_checktime
        && !USER_CMDIDX(ea.cmdidx)
        && curbuf_locked())
      goto doend;

    if (!ni && !(ea.argt & RANGE) && ea.addr_count > 0) {
      /* no range allowed */
      errormsg = (char_u *)_(e_norange);
      goto doend;
    }
  }

  if (!ni && !(ea.argt & BANG) && ea.forceit) { /* no <!> allowed */
    errormsg = (char_u *)_(e_nobang);
    goto doend;
  }

  /*
   * Don't complain about the range if it is not used
   * (could happen if line_count is accidentally set to 0).
   */
  if (!ea.skip && !ni) {
    /*
     * If the range is backwards, ask for confirmation and, if given, swap
     * ea.line1 & ea.line2 so it's forwards again.
     * When global command is busy, don't ask, will fail below.
     */
    if (!global_busy && ea.line1 > ea.line2) {
      if (msg_silent == 0) {
        if (sourcing || exmode_active) {
          errormsg = (char_u *)_("E493: Backwards range given");
          goto doend;
        }
        if (ask_yesno((char_u *)
                _("Backwards range given, OK to swap"), FALSE) != 'y')
          goto doend;
      }
      lnum = ea.line1;
      ea.line1 = ea.line2;
      ea.line2 = lnum;
    }
    if ((errormsg = invalid_range(&ea)) != NULL)
      goto doend;
  }

  if ((ea.argt & NOTADR) && ea.addr_count == 0)   /* default is 1, not cursor */
    ea.line2 = 1;

  correct_range(&ea);

  if (((ea.argt & WHOLEFOLD) || ea.addr_count >= 2) && !global_busy) {
    /* Put the first line at the start of a closed fold, put the last line
     * at the end of a closed fold. */
    (void)hasFolding(ea.line1, &ea.line1, NULL);
    (void)hasFolding(ea.line2, NULL, &ea.line2);
  }

  /*
   * For the ":make" and ":grep" commands we insert the 'makeprg'/'grepprg'
   * option here, so things like % get expanded.
   */
  p = replace_makeprg(&ea, p, cmdlinep);
  if (p == NULL)
    goto doend;

  /*
   * Skip to start of argument.
   * Don't do this for the ":!" command, because ":!! -l" needs the space.
   */
  if (ea.cmdidx == CMD_bang)
    ea.arg = p;
  else
    ea.arg = skipwhite(p);

  /*
   * Check for "++opt=val" argument.
   * Must be first, allow ":w ++enc=utf8 !cmd"
   */
  if (ea.argt & ARGOPT)
    while (ea.arg[0] == '+' && ea.arg[1] == '+')
      if (getargopt(&ea) == FAIL && !ni) {
        errormsg = (char_u *)_(e_invarg);
        goto doend;
      }

  if (ea.cmdidx == CMD_write || ea.cmdidx == CMD_update) {
    if (*ea.arg == '>') {                       /* append */
      if (*++ea.arg != '>') {                   /* typed wrong */
        errormsg = (char_u *)_("E494: Use w or w>>");
        goto doend;
      }
      ea.arg = skipwhite(ea.arg + 1);
      ea.append = TRUE;
    } else if (*ea.arg == '!' && ea.cmdidx == CMD_write)   { /* :w !filter */
      ++ea.arg;
      ea.usefilter = TRUE;
    }
  }

  if (ea.cmdidx == CMD_read) {
    if (ea.forceit) {
      ea.usefilter = TRUE;                      /* :r! filter if ea.forceit */
      ea.forceit = FALSE;
    } else if (*ea.arg == '!')   {              /* :r !filter */
      ++ea.arg;
      ea.usefilter = TRUE;
    }
  }

  if (ea.cmdidx == CMD_lshift || ea.cmdidx == CMD_rshift) {
    ea.amount = 1;
    while (*ea.arg == *ea.cmd) {                /* count number of '>' or '<' */
      ++ea.arg;
      ++ea.amount;
    }
    ea.arg = skipwhite(ea.arg);
  }

  /*
   * Check for "+command" argument, before checking for next command.
   * Don't do this for ":read !cmd" and ":write !cmd".
   */
  if ((ea.argt & EDITCMD) && !ea.usefilter)
    ea.do_ecmd_cmd = getargcmd(&ea.arg);

  /*
   * Check for '|' to separate commands and '"' to start comments.
   * Don't do this for ":read !cmd" and ":write !cmd".
   */
  if ((ea.argt & TRLBAR) && !ea.usefilter)
    separate_nextcmd(&ea);

  /*
   * Check for <newline> to end a shell command.
   * Also do this for ":read !cmd", ":write !cmd" and ":global".
   * Any others?
   */
  else if (ea.cmdidx == CMD_bang
           || ea.cmdidx == CMD_global
           || ea.cmdidx == CMD_vglobal
           || ea.usefilter) {
    for (p = ea.arg; *p; ++p) {
      /* Remove one backslash before a newline, so that it's possible to
       * pass a newline to the shell and also a newline that is preceded
       * with a backslash.  This makes it impossible to end a shell
       * command in a backslash, but that doesn't appear useful.
       * Halving the number of backslashes is incompatible with previous
       * versions. */
      if (*p == '\\' && p[1] == '\n')
        STRMOVE(p, p + 1);
      else if (*p == '\n') {
        ea.nextcmd = p + 1;
        *p = NUL;
        break;
      }
    }
  }

  if ((ea.argt & DFLALL) && ea.addr_count == 0) {
    ea.line1 = 1;
    ea.line2 = curbuf->b_ml.ml_line_count;
  }

  /* accept numbered register only when no count allowed (:put) */
  if (       (ea.argt & REGSTR)
             && *ea.arg != NUL
             /* Do not allow register = for user commands */
             && (!USER_CMDIDX(ea.cmdidx) || *ea.arg != '=')
             && !((ea.argt & COUNT) && VIM_ISDIGIT(*ea.arg))) {
    /* check these explicitly for a more specific error message */
    if (*ea.arg == '*' || *ea.arg == '+') {
      errormsg = (char_u *)_(e_invalidreg);
      goto doend;
    }
    if (
      valid_yank_reg(*ea.arg, (ea.cmdidx != CMD_put
                               && USER_CMDIDX(ea.cmdidx)))
      ) {
      ea.regname = *ea.arg++;
      /* for '=' register: accept the rest of the line as an expression */
      if (ea.arg[-1] == '=' && ea.arg[0] != NUL) {
        set_expr_line(vim_strsave(ea.arg));
        ea.arg += STRLEN(ea.arg);
      }
      ea.arg = skipwhite(ea.arg);
    }
  }

  /*
   * Check for a count.  When accepting a BUFNAME, don't use "123foo" as a
   * count, it's a buffer name.
   */
  if ((ea.argt & COUNT) && VIM_ISDIGIT(*ea.arg)
      && (!(ea.argt & BUFNAME) || *(p = skipdigits(ea.arg)) == NUL
          || vim_iswhite(*p))) {
    n = getdigits(&ea.arg);
    ea.arg = skipwhite(ea.arg);
    if (n <= 0 && !ni && (ea.argt & ZEROR) == 0) {
      errormsg = (char_u *)_(e_zerocount);
      goto doend;
    }
    if (ea.argt & NOTADR) {     /* e.g. :buffer 2, :sleep 3 */
      ea.line2 = n;
      if (ea.addr_count == 0)
        ea.addr_count = 1;
    } else   {
      ea.line1 = ea.line2;
      ea.line2 += n - 1;
      ++ea.addr_count;
      /*
       * Be vi compatible: no error message for out of range.
       */
      if (ea.line2 > curbuf->b_ml.ml_line_count)
        ea.line2 = curbuf->b_ml.ml_line_count;
    }
  }

  /*
   * Check for flags: 'l', 'p' and '#'.
   */
  if (ea.argt & EXFLAGS)
    get_flags(&ea);
  /* no arguments allowed */
  if (!ni && !(ea.argt & EXTRA) && *ea.arg != NUL
      && *ea.arg != '"' && (*ea.arg != '|' || (ea.argt & TRLBAR) == 0)) {
    errormsg = (char_u *)_(e_trailing);
    goto doend;
  }

  if (!ni && (ea.argt & NEEDARG) && *ea.arg == NUL) {
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
    /* commands that need evaluation */
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

    /* Commands that handle '|' themselves.  Check: A command should
     * either have the TRLBAR flag, appear in this list or appear in
     * the list at ":help :bar". */
    case CMD_aboveleft:
    case CMD_and:
    case CMD_belowright:
    case CMD_botright:
    case CMD_browse:
    case CMD_call:
    case CMD_confirm:
    case CMD_delfunction:
    case CMD_djump:
    case CMD_dlist:
    case CMD_dsearch:
    case CMD_dsplit:
    case CMD_echo:
    case CMD_echoerr:
    case CMD_echomsg:
    case CMD_echon:
    case CMD_execute:
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
    case CMD_lua:
    case CMD_match:
    case CMD_mzscheme:
    case CMD_perl:
    case CMD_psearch:
    case CMD_python:
    case CMD_py3:
    case CMD_python3:
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
    case CMD_verbose:
    case CMD_vertical:
    case CMD_wincmd:
      break;

    default:            goto doend;
    }
  }

  if (ea.argt & XFILE) {
    if (expand_filename(&ea, cmdlinep, &errormsg) == FAIL)
      goto doend;
  }

  /*
   * Accept buffer name.  Cannot be used at the same time with a buffer
   * number.  Don't do this for a user command.
   */
  if ((ea.argt & BUFNAME) && *ea.arg != NUL && ea.addr_count == 0
      && !USER_CMDIDX(ea.cmdidx)
      ) {
    /*
     * :bdelete, :bwipeout and :bunload take several arguments, separated
     * by spaces: find next space (skipping over escaped characters).
     * The others take one argument: ignore trailing spaces.
     */
    if (ea.cmdidx == CMD_bdelete || ea.cmdidx == CMD_bwipeout
        || ea.cmdidx == CMD_bunload)
      p = skiptowhite_esc(ea.arg);
    else {
      p = ea.arg + STRLEN(ea.arg);
      while (p > ea.arg && vim_iswhite(p[-1]))
        --p;
    }
    ea.line2 = buflist_findpat(ea.arg, p, (ea.argt & BUFUNL) != 0,
        FALSE, FALSE);
    if (ea.line2 < 0)               /* failed */
      goto doend;
    ea.addr_count = 1;
    ea.arg = skipwhite(p);
  }

  /*
   * 6. switch on command name
   *
   * The "ea" structure holds the arguments that can be used.
   */
  ea.cmdlinep = cmdlinep;
  ea.getline = fgetline;
  ea.cookie = cookie;
  ea.cstack = cstack;

  if (USER_CMDIDX(ea.cmdidx)) {
    /*
     * Execute a user-defined command.
     */
    do_ucmd(&ea);
  } else   {
    /*
     * Call the function to execute the command.
     */
    ea.errmsg = NULL;
    (cmdnames[ea.cmdidx].cmd_func)(&ea);
    if (ea.errmsg != NULL)
      errormsg = (char_u *)_(ea.errmsg);
  }

  /*
   * If the command just executed called do_cmdline(), any throw or ":return"
   * or ":finish" encountered there must also check the cstack of the still
   * active do_cmdline() that called this do_one_cmd().  Rethrow an uncaught
   * exception, or reanimate a returned function or finished script file and
   * return or finish it again.
   */
  if (need_rethrow)
    do_throw(cstack);
  else if (check_cstack) {
    if (source_finished(fgetline, cookie))
      do_finish(&ea, TRUE);
    else if (getline_equal(fgetline, cookie, get_func_line)
             && current_func_returned())
      do_return(&ea, TRUE, FALSE, NULL);
  }
  need_rethrow = check_cstack = FALSE;

doend:
  if (curwin->w_cursor.lnum == 0)       /* can happen with zero line number */
    curwin->w_cursor.lnum = 1;

  if (errormsg != NULL && *errormsg != NUL && !did_emsg) {
    if (sourcing) {
      if (errormsg != IObuff) {
        STRCPY(IObuff, errormsg);
        errormsg = IObuff;
      }
      append_command(*cmdlinep);
    }
    emsg(errormsg);
  }
  do_errthrow(cstack,
      (ea.cmdidx != CMD_SIZE
       && !USER_CMDIDX(ea.cmdidx)
      ) ? cmdnames[(int)ea.cmdidx].cmd_name : (char_u *)NULL);

  if (verbose_save >= 0)
    p_verbose = verbose_save;
  if (cmdmod.save_ei != NULL) {
    /* Restore 'eventignore' to the value before ":noautocmd". */
    set_string_option_direct((char_u *)"ei", -1, cmdmod.save_ei,
        OPT_FREE, SID_NONE);
    free_string_option(cmdmod.save_ei);
  }

  cmdmod = save_cmdmod;

  if (save_msg_silent != -1) {
    /* messages could be enabled for a serious error, need to check if the
     * counters don't become negative */
    if (!did_emsg || msg_silent > save_msg_silent)
      msg_silent = save_msg_silent;
    emsg_silent -= did_esilent;
    if (emsg_silent < 0)
      emsg_silent = 0;
    /* Restore msg_scroll, it's set by file I/O commands, even when no
     * message is actually displayed. */
    msg_scroll = save_msg_scroll;

    /* "silent reg" or "silent echo x" inside "redir" leaves msg_col
     * somewhere in the line.  Put it back in the first column. */
    if (redirecting())
      msg_col = 0;
  }

#ifdef HAVE_SANDBOX
  if (did_sandbox)
    --sandbox;
#endif

  if (ea.nextcmd && *ea.nextcmd == NUL)         /* not really a next command */
    ea.nextcmd = NULL;

  --ex_nesting_level;

  return ea.nextcmd;
}

/*
 * Check for an Ex command with optional tail.
 * If there is a match advance "pp" to the argument and return TRUE.
 */
int 
checkforcmd (
    char_u **pp,               /* start of command */
    char *cmd,               /* name of command */
    int len                        /* required length */
)
{
  int i;

  for (i = 0; cmd[i] != NUL; ++i)
    if (((char_u *)cmd)[i] != (*pp)[i])
      break;
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
    if (
      enc_utf8 ? (s[0] == 0xc2 && s[1] == 0xa0) :
      *s == 0xa0) {
      s +=
        enc_utf8 ? 2 :
        1;
      STRCPY(d, "<a0>");
      d += 4;
    } else
      MB_COPY_CHAR(s, d);
  }
  *d = NUL;
}

/*
 * Find an Ex command by its name, either built-in or user.
 * Start of the name can be found at eap->cmd.
 * Returns pointer to char after the command name.
 * "full" is set to TRUE if the whole command name matched.
 * Returns NULL for an ambiguous user command.
 */
static char_u *find_command(exarg_T *eap, int *full)
{
  int len;
  char_u      *p;
  int i;

  /*
   * Isolate the command and search for it in the command table.
   * Exceptions:
   * - the 'k' command can directly be followed by any character.
   * - the 's' command can be followed directly by 'c', 'g', 'i', 'I' or 'r'
   *	    but :sre[wind] is another command, as are :scrip[tnames],
   *	    :scs[cope], :sim[alt], :sig[ns] and :sil[ent].
   * - the "d" command can directly be followed by 'l' or 'p' flag.
   */
  p = eap->cmd;
  if (*p == 'k') {
    eap->cmdidx = CMD_k;
    ++p;
  } else if (p[0] == 's'
             && ((p[1] == 'c' && p[2] != 's' && p[2] != 'r'
                  && p[3] != 'i' && p[4] != 'p')
                 || p[1] == 'g'
                 || (p[1] == 'i' && p[2] != 'm' && p[2] != 'l' && p[2] != 'g')
                 || p[1] == 'I'
                 || (p[1] == 'r' && p[2] != 'e'))) {
    eap->cmdidx = CMD_substitute;
    ++p;
  } else   {
    while (ASCII_ISALPHA(*p))
      ++p;
    /* for python 3.x support ":py3", ":python3", ":py3file", etc. */
    if (eap->cmd[0] == 'p' && eap->cmd[1] == 'y')
      while (ASCII_ISALNUM(*p))
        ++p;

    /* check for non-alpha command */
    if (p == eap->cmd && vim_strchr((char_u *)"@*!=><&~#", *p) != NULL)
      ++p;
    len = (int)(p - eap->cmd);
    if (*eap->cmd == 'd' && (p[-1] == 'l' || p[-1] == 'p')) {
      /* Check for ":dl", ":dell", etc. to ":deletel": that's
       * :delete with the 'l' flag.  Same for 'p'. */
      for (i = 0; i < len; ++i)
        if (eap->cmd[i] != ((char_u *)"delete")[i])
          break;
      if (i == len - 1) {
        --len;
        if (p[-1] == 'l')
          eap->flags |= EXFLAG_LIST;
        else
          eap->flags |= EXFLAG_PRINT;
      }
    }

    if (ASCII_ISLOWER(*eap->cmd))
      eap->cmdidx = cmdidxs[CharOrdLow(*eap->cmd)];
    else
      eap->cmdidx = cmdidxs[26];

    for (; (int)eap->cmdidx < (int)CMD_SIZE;
         eap->cmdidx = (cmdidx_T)((int)eap->cmdidx + 1))
      if (STRNCMP(cmdnames[(int)eap->cmdidx].cmd_name, (char *)eap->cmd,
              (size_t)len) == 0) {
        if (full != NULL
            && cmdnames[(int)eap->cmdidx].cmd_name[len] == NUL)
          *full = TRUE;
        break;
      }

    /* Look for a user defined command as a last resort.  Let ":Print" be
     * overruled by a user defined command. */
    if ((eap->cmdidx == CMD_SIZE || eap->cmdidx == CMD_Print)
        && *eap->cmd >= 'A' && *eap->cmd <= 'Z') {
      /* User defined commands may contain digits. */
      while (ASCII_ISALNUM(*p))
        ++p;
      p = find_ucmd(eap, p, full, NULL, NULL);
    }
    if (p == eap->cmd)
      eap->cmdidx = CMD_SIZE;
  }

  return p;
}

/*
 * Search for a user command that matches "eap->cmd".
 * Return cmdidx in "eap->cmdidx", flags in "eap->argt", idx in "eap->useridx".
 * Return a pointer to just after the command.
 * Return NULL if there is no matching command.
 */
static char_u *
find_ucmd (
    exarg_T *eap,
    char_u *p,         /* end of the command (possibly including count) */
    int *full,      /* set to TRUE for a full match */
    expand_T *xp,        /* used for completion, NULL otherwise */
    int *compl     /* completion flags or NULL */
)
{
  int len = (int)(p - eap->cmd);
  int j, k, matchlen = 0;
  ucmd_T      *uc;
  int found = FALSE;
  int possible = FALSE;
  char_u      *cp, *np;             /* Point into typed cmd and test name */
  garray_T    *gap;
  int amb_local = FALSE;            /* Found ambiguous buffer-local command,
                                       only full match global is accepted. */

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
      while (k < len && *np != NUL && *cp++ == *np++)
        k++;
      if (k == len || (*np == NUL && vim_isdigit(eap->cmd[k]))) {
        /* If finding a second match, the command is ambiguous.  But
         * not if a buffer-local command wasn't a full match and a
         * global command is a full match. */
        if (k == len && found && *np != NUL) {
          if (gap == &ucmds)
            return NULL;
          amb_local = TRUE;
        }

        if (!found || (k == len && *np == NUL)) {
          /* If we matched up to a digit, then there could
           * be another command including the digit that we
           * should use instead.
           */
          if (k == len)
            found = TRUE;
          else
            possible = TRUE;

          if (gap == &ucmds)
            eap->cmdidx = CMD_USER;
          else
            eap->cmdidx = CMD_USER_BUF;
          eap->argt = (long)uc->uc_argt;
          eap->useridx = j;

          if (compl != NULL)
            *compl = uc->uc_compl;
          if (xp != NULL) {
            xp->xp_arg = uc->uc_compl_arg;
            xp->xp_scriptID = uc->uc_scriptID;
          }
          /* Do not search for further abbreviations
           * if this is an exact match. */
          matchlen = k;
          if (k == len && *np == NUL) {
            if (full != NULL)
              *full = TRUE;
            amb_local = FALSE;
            break;
          }
        }
      }
    }

    /* Stop if we found a full match or searched all. */
    if (j < gap->ga_len || gap == &ucmds)
      break;
    gap = &ucmds;
  }

  /* Only found ambiguous matches. */
  if (amb_local) {
    if (xp != NULL)
      xp->xp_context = EXPAND_UNSUCCESSFUL;
    return NULL;
  }

  /* The match we found may be followed immediately by a number.  Move "p"
   * back to point to it. */
  if (found || possible)
    return p + (matchlen - len);
  return p;
}

static struct cmdmod {
  char        *name;
  int minlen;
  int has_count;            /* :123verbose  :3tab */
} cmdmods[] = {
  {"aboveleft", 3, FALSE},
  {"belowright", 3, FALSE},
  {"botright", 2, FALSE},
  {"browse", 3, FALSE},
  {"confirm", 4, FALSE},
  {"hide", 3, FALSE},
  {"keepalt", 5, FALSE},
  {"keepjumps", 5, FALSE},
  {"keepmarks", 3, FALSE},
  {"keeppatterns", 5, FALSE},
  {"leftabove", 5, FALSE},
  {"lockmarks", 3, FALSE},
  {"noautocmd", 3, FALSE},
  {"rightbelow", 6, FALSE},
  {"sandbox", 3, FALSE},
  {"silent", 3, FALSE},
  {"tab", 3, TRUE},
  {"topleft", 2, FALSE},
  {"unsilent", 3, FALSE},
  {"verbose", 4, TRUE},
  {"vertical", 4, FALSE},
};

/*
 * Return length of a command modifier (including optional count).
 * Return zero when it's not a modifier.
 */
int modifier_len(char_u *cmd)
{
  int i, j;
  char_u      *p = cmd;

  if (VIM_ISDIGIT(*cmd))
    p = skipwhite(skipdigits(cmd));
  for (i = 0; i < (int)(sizeof(cmdmods) / sizeof(struct cmdmod)); ++i) {
    for (j = 0; p[j] != NUL; ++j)
      if (p[j] != cmdmods[i].name[j])
        break;
    if (!ASCII_ISALPHA(p[j]) && j >= cmdmods[i].minlen
        && (p == cmd || cmdmods[i].has_count))
      return j + (int)(p - cmd);
  }
  return 0;
}

/*
 * Return > 0 if an Ex command "name" exists.
 * Return 2 if there is an exact match.
 * Return 3 if there is an ambiguous match.
 */
int cmd_exists(char_u *name)
{
  exarg_T ea;
  int full = FALSE;
  int i;
  int j;
  char_u      *p;

  /* Check command modifiers. */
  for (i = 0; i < (int)(sizeof(cmdmods) / sizeof(struct cmdmod)); ++i) {
    for (j = 0; name[j] != NUL; ++j)
      if (name[j] != cmdmods[i].name[j])
        break;
    if (name[j] == NUL && j >= cmdmods[i].minlen)
      return cmdmods[i].name[j] == NUL ? 2 : 1;
  }

  /* Check built-in commands and user defined commands.
   * For ":2match" and ":3match" we need to skip the number. */
  ea.cmd = (*name == '2' || *name == '3') ? name + 1 : name;
  ea.cmdidx = (cmdidx_T)0;
  p = find_command(&ea, &full);
  if (p == NULL)
    return 3;
  if (vim_isdigit(*name) && ea.cmdidx != CMD_match)
    return 0;
  if (*skipwhite(p) != NUL)
    return 0;           /* trailing garbage */
  return ea.cmdidx == CMD_SIZE ? 0 : (full ? 2 : 1);
}

/*
 * This is all pretty much copied from do_one_cmd(), with all the extra stuff
 * we don't need/want deleted.	Maybe this could be done better if we didn't
 * repeat all this stuff.  The only problem is that they may not stay
 * perfectly compatible with each other, but then the command line syntax
 * probably won't change that much -- webb.
 */
char_u *
set_one_cmd_context (
    expand_T *xp,
    char_u *buff          /* buffer for command string */
)
{
  char_u              *p;
  char_u              *cmd, *arg;
  int len = 0;
  exarg_T ea;
  int                 compl = EXPAND_NOTHING;
  int delim;
  int forceit = FALSE;
  int usefilter = FALSE;                    /* filter instead of file name */

  ExpandInit(xp);
  xp->xp_pattern = buff;
  xp->xp_context = EXPAND_COMMANDS;     /* Default until we get past command */
  ea.argt = 0;

  /*
   * 2. skip comment lines and leading space, colons or bars
   */
  for (cmd = buff; vim_strchr((char_u *)" \t:|", *cmd) != NULL; cmd++)
    ;
  xp->xp_pattern = cmd;

  if (*cmd == NUL)
    return NULL;
  if (*cmd == '"') {        /* ignore comment lines */
    xp->xp_context = EXPAND_NOTHING;
    return NULL;
  }

  /*
   * 3. parse a range specifier of the form: addr [,addr] [;addr] ..
   */
  cmd = skip_range(cmd, &xp->xp_context);

  /*
   * 4. parse command
   */
  xp->xp_pattern = cmd;
  if (*cmd == NUL)
    return NULL;
  if (*cmd == '"') {
    xp->xp_context = EXPAND_NOTHING;
    return NULL;
  }

  if (*cmd == '|' || *cmd == '\n')
    return cmd + 1;                     /* There's another command */

  /*
   * Isolate the command and search for it in the command table.
   * Exceptions:
   * - the 'k' command can directly be followed by any character, but
   *   do accept "keepmarks", "keepalt" and "keepjumps".
   * - the 's' command can be followed directly by 'c', 'g', 'i', 'I' or 'r'
   */
  if (*cmd == 'k' && cmd[1] != 'e') {
    ea.cmdidx = CMD_k;
    p = cmd + 1;
  } else   {
    p = cmd;
    while (ASCII_ISALPHA(*p) || *p == '*')        /* Allow * wild card */
      ++p;
    /* check for non-alpha command */
    if (p == cmd && vim_strchr((char_u *)"@*!=><&~#", *p) != NULL)
      ++p;
    /* for python 3.x: ":py3*" commands completion */
    if (cmd[0] == 'p' && cmd[1] == 'y' && p == cmd + 2 && *p == '3') {
      ++p;
      while (ASCII_ISALPHA(*p) || *p == '*')
        ++p;
    }
    len = (int)(p - cmd);

    if (len == 0) {
      xp->xp_context = EXPAND_UNSUCCESSFUL;
      return NULL;
    }
    for (ea.cmdidx = (cmdidx_T)0; (int)ea.cmdidx < (int)CMD_SIZE;
         ea.cmdidx = (cmdidx_T)((int)ea.cmdidx + 1))
      if (STRNCMP(cmdnames[(int)ea.cmdidx].cmd_name, cmd,
              (size_t)len) == 0)
        break;

    if (cmd[0] >= 'A' && cmd[0] <= 'Z')
      while (ASCII_ISALNUM(*p) || *p == '*')            /* Allow * wild card */
        ++p;
  }

  /*
   * If the cursor is touching the command, and it ends in an alpha-numeric
   * character, complete the command name.
   */
  if (*p == NUL && ASCII_ISALNUM(p[-1]))
    return NULL;

  if (ea.cmdidx == CMD_SIZE) {
    if (*cmd == 's' && vim_strchr((char_u *)"cgriI", cmd[1]) != NULL) {
      ea.cmdidx = CMD_substitute;
      p = cmd + 1;
    } else if (cmd[0] >= 'A' && cmd[0] <= 'Z')   {
      ea.cmd = cmd;
      p = find_ucmd(&ea, p, NULL, xp,
          &compl
          );
      if (p == NULL)
        ea.cmdidx = CMD_SIZE;           /* ambiguous user command */
    }
  }
  if (ea.cmdidx == CMD_SIZE) {
    /* Not still touching the command and it was an illegal one */
    xp->xp_context = EXPAND_UNSUCCESSFUL;
    return NULL;
  }

  xp->xp_context = EXPAND_NOTHING;   /* Default now that we're past command */

  if (*p == '!') {                  /* forced commands */
    forceit = TRUE;
    ++p;
  }

  /*
   * 5. parse arguments
   */
  if (!USER_CMDIDX(ea.cmdidx))
    ea.argt = (long)cmdnames[(int)ea.cmdidx].cmd_argt;

  arg = skipwhite(p);

  if (ea.cmdidx == CMD_write || ea.cmdidx == CMD_update) {
    if (*arg == '>') {                          /* append */
      if (*++arg == '>')
        ++arg;
      arg = skipwhite(arg);
    } else if (*arg == '!' && ea.cmdidx == CMD_write)   { /* :w !filter */
      ++arg;
      usefilter = TRUE;
    }
  }

  if (ea.cmdidx == CMD_read) {
    usefilter = forceit;                        /* :r! filter if forced */
    if (*arg == '!') {                          /* :r !filter */
      ++arg;
      usefilter = TRUE;
    }
  }

  if (ea.cmdidx == CMD_lshift || ea.cmdidx == CMD_rshift) {
    while (*arg == *cmd)            /* allow any number of '>' or '<' */
      ++arg;
    arg = skipwhite(arg);
  }

  /* Does command allow "+command"? */
  if ((ea.argt & EDITCMD) && !usefilter && *arg == '+') {
    /* Check if we're in the +command */
    p = arg + 1;
    arg = skip_cmd_arg(arg, FALSE);

    /* Still touching the command after '+'? */
    if (*arg == NUL)
      return p;

    /* Skip space(s) after +command to get to the real argument */
    arg = skipwhite(arg);
  }

  /*
   * Check for '|' to separate commands and '"' to start comments.
   * Don't do this for ":read !cmd" and ":write !cmd".
   */
  if ((ea.argt & TRLBAR) && !usefilter) {
    p = arg;
    /* ":redir @" is not the start of a comment */
    if (ea.cmdidx == CMD_redir && p[0] == '@' && p[1] == '"')
      p += 2;
    while (*p) {
      if (*p == Ctrl_V) {
        if (p[1] != NUL)
          ++p;
      } else if ( (*p == '"' && !(ea.argt & NOTRLCOM))
                  || *p == '|' || *p == '\n') {
        if (*(p - 1) != '\\') {
          if (*p == '|' || *p == '\n')
            return p + 1;
          return NULL;              /* It's a comment */
        }
      }
      mb_ptr_adv(p);
    }
  }

  /* no arguments allowed */
  if (!(ea.argt & EXTRA) && *arg != NUL &&
      vim_strchr((char_u *)"|\"", *arg) == NULL)
    return NULL;

  /* Find start of last argument (argument just before cursor): */
  p = buff;
  xp->xp_pattern = p;
  len = (int)STRLEN(buff);
  while (*p && p < buff + len) {
    if (*p == ' ' || *p == TAB) {
      /* argument starts after a space */
      xp->xp_pattern = ++p;
    } else   {
      if (*p == '\\' && *(p + 1) != NUL)
        ++p;         /* skip over escaped character */
      mb_ptr_adv(p);
    }
  }

  if (ea.argt & XFILE) {
    int c;
    int in_quote = FALSE;
    char_u  *bow = NULL;        /* Beginning of word */

    /*
     * Allow spaces within back-quotes to count as part of the argument
     * being expanded.
     */
    xp->xp_pattern = skipwhite(arg);
    p = xp->xp_pattern;
    while (*p != NUL) {
      if (has_mbyte)
        c = mb_ptr2char(p);
      else
        c = *p;
      if (c == '\\' && p[1] != NUL)
        ++p;
      else if (c == '`') {
        if (!in_quote) {
          xp->xp_pattern = p;
          bow = p + 1;
        }
        in_quote = !in_quote;
      }
      /* An argument can contain just about everything, except
       * characters that end the command and white space. */
      else if (c == '|' || c == '\n' || c == '"' || (vim_iswhite(c)
#ifdef SPACE_IN_FILENAME
                                                     && (!(ea.argt & NOSPC) ||
                                                         usefilter)
#endif
                                                     )) {
        len = 0;          /* avoid getting stuck when space is in 'isfname' */
        while (*p != NUL) {
          if (has_mbyte)
            c = mb_ptr2char(p);
          else
            c = *p;
          if (c == '`' || vim_isfilec_or_wc(c))
            break;
          if (has_mbyte)
            len = (*mb_ptr2len)(p);
          else
            len = 1;
          mb_ptr_adv(p);
        }
        if (in_quote)
          bow = p;
        else
          xp->xp_pattern = p;
        p -= len;
      }
      mb_ptr_adv(p);
    }

    /*
     * If we are still inside the quotes, and we passed a space, just
     * expand from there.
     */
    if (bow != NULL && in_quote)
      xp->xp_pattern = bow;
    xp->xp_context = EXPAND_FILES;

    /* For a shell command more chars need to be escaped. */
    if (usefilter || ea.cmdidx == CMD_bang) {
#ifndef BACKSLASH_IN_FILENAME
      xp->xp_shell = TRUE;
#endif
      /* When still after the command name expand executables. */
      if (xp->xp_pattern == skipwhite(arg))
        xp->xp_context = EXPAND_SHELLCMD;
    }

    /* Check for environment variable */
    if (*xp->xp_pattern == '$'
        ) {
      for (p = xp->xp_pattern + 1; *p != NUL; ++p)
        if (!vim_isIDc(*p))
          break;
      if (*p == NUL) {
        xp->xp_context = EXPAND_ENV_VARS;
        ++xp->xp_pattern;
        /* Avoid that the assignment uses EXPAND_FILES again. */
        if (compl != EXPAND_USER_DEFINED && compl != EXPAND_USER_LIST)
          compl = EXPAND_ENV_VARS;
      }
    }
    /* Check for user names */
    if (*xp->xp_pattern == '~') {
      for (p = xp->xp_pattern + 1; *p != NUL && *p != '/'; ++p)
        ;
      /* Complete ~user only if it partially matches a user name.
       * A full match ~user<Tab> will be replaced by user's home
       * directory i.e. something like ~user<Tab> -> /home/user/ */
      if (*p == NUL && p > xp->xp_pattern + 1
          && match_user(xp->xp_pattern + 1) == 1) {
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
    if (xp->xp_context == EXPAND_FILES)
      xp->xp_context = EXPAND_FILES_IN_PATH;
    break;
  case CMD_cd:
  case CMD_chdir:
  case CMD_lcd:
  case CMD_lchdir:
    if (xp->xp_context == EXPAND_FILES)
      xp->xp_context = EXPAND_DIRECTORIES;
    break;
  case CMD_help:
    xp->xp_context = EXPAND_HELP;
    xp->xp_pattern = arg;
    break;

  /* Command modifiers: return the argument.
   * Also for commands with an argument that is a command. */
  case CMD_aboveleft:
  case CMD_argdo:
  case CMD_belowright:
  case CMD_botright:
  case CMD_browse:
  case CMD_bufdo:
  case CMD_confirm:
  case CMD_debug:
  case CMD_folddoclosed:
  case CMD_folddoopen:
  case CMD_hide:
  case CMD_keepalt:
  case CMD_keepjumps:
  case CMD_keepmarks:
  case CMD_keeppatterns:
  case CMD_leftabove:
  case CMD_lockmarks:
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

  case CMD_match:
    if (*arg == NUL || !ends_excmd(*arg)) {
      /* also complete "None" */
      set_context_in_echohl_cmd(xp, arg);
      arg = skipwhite(skiptowhite(arg));
      if (*arg != NUL) {
        xp->xp_context = EXPAND_NOTHING;
        arg = skip_regexp(arg + 1, *arg, p_magic, NULL);
      }
    }
    return find_nextcmd(arg);

  /*
   * All completion for the +cmdline_compl feature goes here.
   */

  case CMD_command:
    /* Check for attributes */
    while (*arg == '-') {
      arg++;                /* Skip "-" */
      p = skiptowhite(arg);
      if (*p == NUL) {
        /* Cursor is still in the attribute */
        p = vim_strchr(arg, '=');
        if (p == NULL) {
          /* No "=", so complete attribute names */
          xp->xp_context = EXPAND_USER_CMD_FLAGS;
          xp->xp_pattern = arg;
          return NULL;
        }

        /* For the -complete and -nargs attributes, we complete
         * their arguments as well.
         */
        if (STRNICMP(arg, "complete", p - arg) == 0) {
          xp->xp_context = EXPAND_USER_COMPLETE;
          xp->xp_pattern = p + 1;
          return NULL;
        } else if (STRNICMP(arg, "nargs", p - arg) == 0)   {
          xp->xp_context = EXPAND_USER_NARGS;
          xp->xp_pattern = p + 1;
          return NULL;
        }
        return NULL;
      }
      arg = skipwhite(p);
    }

    /* After the attributes comes the new command name */
    p = skiptowhite(arg);
    if (*p == NUL) {
      xp->xp_context = EXPAND_USER_COMMANDS;
      xp->xp_pattern = arg;
      break;
    }

    /* And finally comes a normal command */
    return skipwhite(p);

  case CMD_delcommand:
    xp->xp_context = EXPAND_USER_COMMANDS;
    xp->xp_pattern = arg;
    break;

  case CMD_global:
  case CMD_vglobal:
    delim = *arg;                   /* get the delimiter */
    if (delim)
      ++arg;                        /* skip delimiter if there is one */

    while (arg[0] != NUL && arg[0] != delim) {
      if (arg[0] == '\\' && arg[1] != NUL)
        ++arg;
      ++arg;
    }
    if (arg[0] != NUL)
      return arg + 1;
    break;
  case CMD_and:
  case CMD_substitute:
    delim = *arg;
    if (delim) {
      /* skip "from" part */
      ++arg;
      arg = skip_regexp(arg, delim, p_magic, NULL);
    }
    /* skip "to" part */
    while (arg[0] != NUL && arg[0] != delim) {
      if (arg[0] == '\\' && arg[1] != NUL)
        ++arg;
      ++arg;
    }
    if (arg[0] != NUL)          /* skip delimiter */
      ++arg;
    while (arg[0] && vim_strchr((char_u *)"|\"#", arg[0]) == NULL)
      ++arg;
    if (arg[0] != NUL)
      return arg;
    break;
  case CMD_isearch:
  case CMD_dsearch:
  case CMD_ilist:
  case CMD_dlist:
  case CMD_ijump:
  case CMD_psearch:
  case CMD_djump:
  case CMD_isplit:
  case CMD_dsplit:
    arg = skipwhite(skipdigits(arg));               /* skip count */
    if (*arg == '/') {          /* Match regexp, not just whole words */
      for (++arg; *arg && *arg != '/'; arg++)
        if (*arg == '\\' && arg[1] != NUL)
          arg++;
      if (*arg) {
        arg = skipwhite(arg + 1);

        /* Check for trailing illegal characters */
        if (*arg && vim_strchr((char_u *)"|\"\n", *arg) == NULL)
          xp->xp_context = EXPAND_NOTHING;
        else
          return arg;
      }
    }
    break;
  case CMD_autocmd:
    return set_context_in_autocmd(xp, arg, FALSE);

  case CMD_doautocmd:
  case CMD_doautoall:
    return set_context_in_autocmd(xp, arg, TRUE);
  case CMD_set:
    set_context_in_set_cmd(xp, arg, 0);
    break;
  case CMD_setglobal:
    set_context_in_set_cmd(xp, arg, OPT_GLOBAL);
    break;
  case CMD_setlocal:
    set_context_in_set_cmd(xp, arg, OPT_LOCAL);
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
    if (*p_wop != NUL)
      xp->xp_context = EXPAND_TAGS_LISTFILES;
    else
      xp->xp_context = EXPAND_TAGS;
    xp->xp_pattern = arg;
    break;
  case CMD_augroup:
    xp->xp_context = EXPAND_AUGROUP;
    xp->xp_pattern = arg;
    break;
  case CMD_syntax:
    set_context_in_syntax_cmd(xp, arg);
    break;
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
    set_context_for_expression(xp, arg, ea.cmdidx);
    break;

  case CMD_unlet:
    while ((xp->xp_pattern = vim_strchr(arg, ' ')) != NULL)
      arg = xp->xp_pattern + 1;
    xp->xp_context = EXPAND_USER_VARS;
    xp->xp_pattern = arg;
    break;

  case CMD_function:
  case CMD_delfunction:
    xp->xp_context = EXPAND_USER_FUNC;
    xp->xp_pattern = arg;
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
  case CMD_bdelete:
  case CMD_bwipeout:
  case CMD_bunload:
    while ((xp->xp_pattern = vim_strchr(arg, ' ')) != NULL)
      arg = xp->xp_pattern + 1;
  /*FALLTHROUGH*/
  case CMD_buffer:
  case CMD_sbuffer:
  case CMD_checktime:
    xp->xp_context = EXPAND_BUFFERS;
    xp->xp_pattern = arg;
    break;
  case CMD_USER:
  case CMD_USER_BUF:
    if (compl != EXPAND_NOTHING) {
      /* XFILE: file names are handled above */
      if (!(ea.argt & XFILE)) {
        if (compl == EXPAND_MENUS)
          return set_context_in_menu_cmd(xp, cmd, arg, forceit);
        if (compl == EXPAND_COMMANDS)
          return arg;
        if (compl == EXPAND_MAPPINGS)
          return set_context_in_map_cmd(xp, (char_u *)"map",
              arg, forceit, FALSE, FALSE, CMD_map);
        /* Find start of last argument. */
        p = arg;
        while (*p) {
          if (*p == ' ')
            /* argument starts after a space */
            arg = p + 1;
          else if (*p == '\\' && *(p + 1) != NUL)
            ++p;                 /* skip over escaped character */
          mb_ptr_adv(p);
        }
        xp->xp_pattern = arg;
      }
      xp->xp_context = compl;
    }
    break;
  case CMD_map:       case CMD_noremap:
  case CMD_nmap:      case CMD_nnoremap:
  case CMD_vmap:      case CMD_vnoremap:
  case CMD_omap:      case CMD_onoremap:
  case CMD_imap:      case CMD_inoremap:
  case CMD_cmap:      case CMD_cnoremap:
  case CMD_lmap:      case CMD_lnoremap:
  case CMD_smap:      case CMD_snoremap:
  case CMD_xmap:      case CMD_xnoremap:
    return set_context_in_map_cmd(xp, cmd, arg, forceit,
        FALSE, FALSE, ea.cmdidx);
  case CMD_unmap:
  case CMD_nunmap:
  case CMD_vunmap:
  case CMD_ounmap:
  case CMD_iunmap:
  case CMD_cunmap:
  case CMD_lunmap:
  case CMD_sunmap:
  case CMD_xunmap:
    return set_context_in_map_cmd(xp, cmd, arg, forceit,
        FALSE, TRUE, ea.cmdidx);
  case CMD_abbreviate:    case CMD_noreabbrev:
  case CMD_cabbrev:       case CMD_cnoreabbrev:
  case CMD_iabbrev:       case CMD_inoreabbrev:
    return set_context_in_map_cmd(xp, cmd, arg, forceit,
        TRUE, FALSE, ea.cmdidx);
  case CMD_unabbreviate:
  case CMD_cunabbrev:
  case CMD_iunabbrev:
    return set_context_in_map_cmd(xp, cmd, arg, forceit,
        TRUE, TRUE, ea.cmdidx);
  case CMD_menu:      case CMD_noremenu:      case CMD_unmenu:
  case CMD_amenu:     case CMD_anoremenu:     case CMD_aunmenu:
  case CMD_nmenu:     case CMD_nnoremenu:     case CMD_nunmenu:
  case CMD_vmenu:     case CMD_vnoremenu:     case CMD_vunmenu:
  case CMD_omenu:     case CMD_onoremenu:     case CMD_ounmenu:
  case CMD_imenu:     case CMD_inoremenu:     case CMD_iunmenu:
  case CMD_cmenu:     case CMD_cnoremenu:     case CMD_cunmenu:
  case CMD_tmenu:                             case CMD_tunmenu:
  case CMD_popup:     case CMD_tearoff:       case CMD_emenu:
    return set_context_in_menu_cmd(xp, cmd, arg, forceit);

  case CMD_colorscheme:
    xp->xp_context = EXPAND_COLORS;
    xp->xp_pattern = arg;
    break;

  case CMD_compiler:
    xp->xp_context = EXPAND_COMPILER;
    xp->xp_pattern = arg;
    break;

  case CMD_ownsyntax:
    xp->xp_context = EXPAND_OWNSYNTAX;
    xp->xp_pattern = arg;
    break;

  case CMD_setfiletype:
    xp->xp_context = EXPAND_FILETYPE;
    xp->xp_pattern = arg;
    break;

#ifdef HAVE_WORKING_LIBINTL
  case CMD_language:
    p = skiptowhite(arg);
    if (*p == NUL) {
      xp->xp_context = EXPAND_LANGUAGE;
      xp->xp_pattern = arg;
    } else   {
      if ( STRNCMP(arg, "messages", p - arg) == 0
           || STRNCMP(arg, "ctype", p - arg) == 0
           || STRNCMP(arg, "time", p - arg) == 0) {
        xp->xp_context = EXPAND_LOCALES;
        xp->xp_pattern = skipwhite(p);
      } else
        xp->xp_context = EXPAND_NOTHING;
    }
    break;
#endif
  case CMD_profile:
    set_context_in_profile_cmd(xp, arg);
    break;
  case CMD_behave:
    xp->xp_context = EXPAND_BEHAVE;
    xp->xp_pattern = arg;
    break;

  case CMD_history:
    xp->xp_context = EXPAND_HISTORY;
    xp->xp_pattern = arg;
    break;
  case CMD_syntime:
    xp->xp_context = EXPAND_SYNTIME;
    xp->xp_pattern = arg;
    break;


  default:
    break;
  }
  return NULL;
}

/*
 * skip a range specifier of the form: addr [,addr] [;addr] ..
 *
 * Backslashed delimiters after / or ? will be skipped, and commands will
 * not be expanded between /'s and ?'s or after "'".
 *
 * Also skip white space and ":" characters.
 * Returns the "cmd" pointer advanced to beyond the range.
 */
char_u *
skip_range (
    char_u *cmd,
    int *ctx       /* pointer to xp_context or NULL */
)
{
  unsigned delim;

  while (vim_strchr((char_u *)" \t0123456789.$%'/?-+,;", *cmd) != NULL) {
    if (*cmd == '\'') {
      if (*++cmd == NUL && ctx != NULL)
        *ctx = EXPAND_NOTHING;
    } else if (*cmd == '/' || *cmd == '?')   {
      delim = *cmd++;
      while (*cmd != NUL && *cmd != delim)
        if (*cmd++ == '\\' && *cmd != NUL)
          ++cmd;
      if (*cmd == NUL && ctx != NULL)
        *ctx = EXPAND_NOTHING;
    }
    if (*cmd != NUL)
      ++cmd;
  }

  /* Skip ":" and white space. */
  while (*cmd == ':')
    cmd = skipwhite(cmd + 1);

  return cmd;
}

/*
 * get a single EX address
 *
 * Set ptr to the next character after the part that was interpreted.
 * Set ptr to NULL when an error is encountered.
 *
 * Return MAXLNUM when no Ex address was found.
 */
static linenr_T 
get_address (
    char_u **ptr,
    int skip,                   /* only skip the address, don't use it */
    int to_other_file              /* flag: may jump to other file */
)
{
  int c;
  int i;
  long n;
  char_u      *cmd;
  pos_T pos;
  pos_T       *fp;
  linenr_T lnum;

  cmd = skipwhite(*ptr);
  lnum = MAXLNUM;
  do {
    switch (*cmd) {
    case '.':                               /* '.' - Cursor position */
      ++cmd;
      lnum = curwin->w_cursor.lnum;
      break;

    case '$':                               /* '$' - last line */
      ++cmd;
      lnum = curbuf->b_ml.ml_line_count;
      break;

    case '\'':                              /* ''' - mark */
      if (*++cmd == NUL) {
        cmd = NULL;
        goto error;
      }
      if (skip)
        ++cmd;
      else {
        /* Only accept a mark in another file when it is
         * used by itself: ":'M". */
        fp = getmark(*cmd, to_other_file && cmd[1] == NUL);
        ++cmd;
        if (fp == (pos_T *)-1)
          /* Jumped to another file. */
          lnum = curwin->w_cursor.lnum;
        else {
          if (check_mark(fp) == FAIL) {
            cmd = NULL;
            goto error;
          }
          lnum = fp->lnum;
        }
      }
      break;

    case '/':
    case '?':                           /* '/' or '?' - search */
      c = *cmd++;
      if (skip) {                       /* skip "/pat/" */
        cmd = skip_regexp(cmd, c, (int)p_magic, NULL);
        if (*cmd == c)
          ++cmd;
      } else   {
        pos = curwin->w_cursor;                     /* save curwin->w_cursor */
        /*
         * When '/' or '?' follows another address, start
         * from there.
         */
        if (lnum != MAXLNUM)
          curwin->w_cursor.lnum = lnum;
        /*
         * Start a forward search at the end of the line.
         * Start a backward search at the start of the line.
         * This makes sure we never match in the current
         * line, and can match anywhere in the
         * next/previous line.
         */
        if (c == '/')
          curwin->w_cursor.col = MAXCOL;
        else
          curwin->w_cursor.col = 0;
        searchcmdlen = 0;
        if (!do_search(NULL, c, cmd, 1L,
                SEARCH_HIS | SEARCH_MSG, NULL)) {
          curwin->w_cursor = pos;
          cmd = NULL;
          goto error;
        }
        lnum = curwin->w_cursor.lnum;
        curwin->w_cursor = pos;
        /* adjust command string pointer */
        cmd += searchcmdlen;
      }
      break;

    case '\\':                      /* "\?", "\/" or "\&", repeat search */
      ++cmd;
      if (*cmd == '&')
        i = RE_SUBST;
      else if (*cmd == '?' || *cmd == '/')
        i = RE_SEARCH;
      else {
        EMSG(_(e_backslash));
        cmd = NULL;
        goto error;
      }

      if (!skip) {
        /*
         * When search follows another address, start from
         * there.
         */
        if (lnum != MAXLNUM)
          pos.lnum = lnum;
        else
          pos.lnum = curwin->w_cursor.lnum;

        /*
         * Start the search just like for the above
         * do_search().
         */
        if (*cmd != '?')
          pos.col = MAXCOL;
        else
          pos.col = 0;
        if (searchit(curwin, curbuf, &pos,
                *cmd == '?' ? BACKWARD : FORWARD,
                (char_u *)"", 1L, SEARCH_MSG,
                i, (linenr_T)0, NULL) != FAIL)
          lnum = pos.lnum;
        else {
          cmd = NULL;
          goto error;
        }
      }
      ++cmd;
      break;

    default:
      if (VIM_ISDIGIT(*cmd))                    /* absolute line number */
        lnum = getdigits(&cmd);
    }

    for (;; ) {
      cmd = skipwhite(cmd);
      if (*cmd != '-' && *cmd != '+' && !VIM_ISDIGIT(*cmd))
        break;

      if (lnum == MAXLNUM)
        lnum = curwin->w_cursor.lnum;           /* "+1" is same as ".+1" */
      if (VIM_ISDIGIT(*cmd))
        i = '+';                        /* "number" is same as "+number" */
      else
        i = *cmd++;
      if (!VIM_ISDIGIT(*cmd))           /* '+' is '+1', but '+0' is not '+1' */
        n = 1;
      else
        n = getdigits(&cmd);
      if (i == '-')
        lnum -= n;
      else
        lnum += n;
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
    if (*eap->arg == 'l')
      eap->flags |= EXFLAG_LIST;
    else if (*eap->arg == 'p')
      eap->flags |= EXFLAG_PRINT;
    else
      eap->flags |= EXFLAG_NR;
    eap->arg = skipwhite(eap->arg + 1);
  }
}

/*
 * Function called for command which is Not Implemented.  NI!
 */
void ex_ni(exarg_T *eap)
{
  if (!eap->skip)
    eap->errmsg = (char_u *)N_(
        "E319: Sorry, the command is not available in this version");
}

#ifdef HAVE_EX_SCRIPT_NI
/*
 * Function called for script command which is Not Implemented.  NI!
 * Skips over ":perl <<EOF" constructs.
 */
static void ex_script_ni(exarg_T *eap)
{
  if (!eap->skip)
    ex_ni(eap);
  else
    vim_free(script_get(eap, eap->arg));
}
#endif

/*
 * Check range in Ex command for validity.
 * Return NULL when valid, error message when invalid.
 */
static char_u *invalid_range(exarg_T *eap)
{
  if (       eap->line1 < 0
             || eap->line2 < 0
             || eap->line1 > eap->line2
             || ((eap->argt & RANGE)
                 && !(eap->argt & NOTADR)
                 && eap->line2 > curbuf->b_ml.ml_line_count
                 + (eap->cmdidx == CMD_diffget)
                 ))
    return (char_u *)_(e_invrange);
  return NULL;
}

/*
 * Correct the range for zero line number, if required.
 */
static void correct_range(exarg_T *eap)
{
  if (!(eap->argt & ZEROR)) {       /* zero in range not allowed */
    if (eap->line1 == 0)
      eap->line1 = 1;
    if (eap->line2 == 0)
      eap->line2 = 1;
  }
}

static char_u   *skip_grep_pat(exarg_T *eap);

/*
 * For a ":vimgrep" or ":vimgrepadd" command return a pointer past the
 * pattern.  Otherwise return eap->arg.
 */
static char_u *skip_grep_pat(exarg_T *eap)
{
  char_u      *p = eap->arg;

  if (*p != NUL && (eap->cmdidx == CMD_vimgrep || eap->cmdidx == CMD_lvimgrep
                    || eap->cmdidx == CMD_vimgrepadd
                    || eap->cmdidx == CMD_lvimgrepadd
                    || grep_internal(eap->cmdidx))) {
    p = skip_vimgrep_pat(p, NULL, NULL);
    if (p == NULL)
      p = eap->arg;
  }
  return p;
}

/*
 * For the ":make" and ":grep" commands insert the 'makeprg'/'grepprg' option
 * in the command line, so that things like % get expanded.
 */
static char_u *replace_makeprg(exarg_T *eap, char_u *p, char_u **cmdlinep)
{
  char_u      *new_cmdline;
  char_u      *program;
  char_u      *pos;
  char_u      *ptr;
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
      if (*curbuf->b_p_gp == NUL)
        program = p_gp;
      else
        program = curbuf->b_p_gp;
    } else   {
      if (*curbuf->b_p_mp == NUL)
        program = p_mp;
      else
        program = curbuf->b_p_mp;
    }

    p = skipwhite(p);

    if ((pos = (char_u *)strstr((char *)program, "$*")) != NULL) {
      /* replace $* by given arguments */
      i = 1;
      while ((pos = (char_u *)strstr((char *)pos + 2, "$*")) != NULL)
        ++i;
      len = (int)STRLEN(p);
      new_cmdline = alloc((int)(STRLEN(program) + i * (len - 2) + 1));
      if (new_cmdline == NULL)
        return NULL;                            /* out of memory */
      ptr = new_cmdline;
      while ((pos = (char_u *)strstr((char *)program, "$*")) != NULL) {
        i = (int)(pos - program);
        STRNCPY(ptr, program, i);
        STRCPY(ptr += i, p);
        ptr += len;
        program = pos + 2;
      }
      STRCPY(ptr, program);
    } else   {
      new_cmdline = alloc((int)(STRLEN(program) + STRLEN(p) + 2));
      if (new_cmdline == NULL)
        return NULL;                            /* out of memory */
      STRCPY(new_cmdline, program);
      STRCAT(new_cmdline, " ");
      STRCAT(new_cmdline, p);
    }
    msg_make(p);

    /* 'eap->cmd' is not set here, because it is not used at CMD_make */
    vim_free(*cmdlinep);
    *cmdlinep = new_cmdline;
    p = new_cmdline;
  }
  return p;
}

/*
 * Expand file name in Ex command argument.
 * Return FAIL for failure, OK otherwise.
 */
int expand_filename(exarg_T *eap, char_u **cmdlinep, char_u **errormsgp)
{
  int has_wildcards;            /* need to expand wildcards */
  char_u      *repl;
  int srclen;
  char_u      *p;
  int n;
  int escaped;

  /* Skip a regexp pattern for ":vimgrep[add] pat file..." */
  p = skip_grep_pat(eap);

  /*
   * Decide to expand wildcards *before* replacing '%', '#', etc.  If
   * the file name contains a wildcard it should not cause expanding.
   * (it will be expanded anyway if there is a wildcard before replacing).
   */
  has_wildcards = mch_has_wildcard(p);
  while (*p != NUL) {
    /* Skip over `=expr`, wildcards in it are not expanded. */
    if (p[0] == '`' && p[1] == '=') {
      p += 2;
      (void)skip_expr(&p);
      if (*p == '`')
        ++p;
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
    if (*errormsgp != NULL)             /* error detected */
      return FAIL;
    if (repl == NULL) {                 /* no match found */
      p += srclen;
      continue;
    }

    /* Wildcards won't be expanded below, the replacement is taken
     * literally.  But do expand "~/file", "~user/file" and "$HOME/file". */
    if (vim_strchr(repl, '$') != NULL || vim_strchr(repl, '~') != NULL) {
      char_u *l = repl;

      repl = expand_env_save(repl);
      vim_free(l);
    }

    /* Need to escape white space et al. with a backslash.
     * Don't do this for:
     * - replacement that already has been escaped: "##"
     * - shell commands (may have to use quotes instead).
     * - non-unix systems when there is a single argument (spaces don't
     *   separate arguments then).
     */
    if (!eap->usefilter
        && !escaped
        && eap->cmdidx != CMD_bang
        && eap->cmdidx != CMD_make
        && eap->cmdidx != CMD_lmake
        && eap->cmdidx != CMD_grep
        && eap->cmdidx != CMD_lgrep
        && eap->cmdidx != CMD_grepadd
        && eap->cmdidx != CMD_lgrepadd
#ifndef UNIX
        && !(eap->argt & NOSPC)
#endif
        ) {
      char_u      *l;
#ifdef BACKSLASH_IN_FILENAME
      /* Don't escape a backslash here, because rem_backslash() doesn't
       * remove it later. */
      static char_u *nobslash = (char_u *)" \t\"|";
# define ESCAPE_CHARS nobslash
#else
# define ESCAPE_CHARS escape_chars
#endif

      for (l = repl; *l; ++l)
        if (vim_strchr(ESCAPE_CHARS, *l) != NULL) {
          l = vim_strsave_escaped(repl, ESCAPE_CHARS);
          if (l != NULL) {
            vim_free(repl);
            repl = l;
          }
          break;
        }
    }

    /* For a shell command a '!' must be escaped. */
    if ((eap->usefilter || eap->cmdidx == CMD_bang)
        && vim_strpbrk(repl, (char_u *)"!&;()<>") != NULL) {
      char_u      *l;

      l = vim_strsave_escaped(repl, (char_u *)"!&;()<>");
      if (l != NULL) {
        vim_free(repl);
        repl = l;
        /* For a sh-like shell escape "!" another time. */
        if (strstr((char *)p_sh, "sh") != NULL) {
          l = vim_strsave_escaped(repl, (char_u *)"!");
          if (l != NULL) {
            vim_free(repl);
            repl = l;
          }
        }
      }
    }

    p = repl_cmdline(eap, p, srclen, repl, cmdlinep);
    vim_free(repl);
    if (p == NULL)
      return FAIL;
  }

  /*
   * One file argument: Expand wildcards.
   * Don't do this with ":r !command" or ":w !command".
   */
  if ((eap->argt & NOSPC) && !eap->usefilter) {
    /*
     * May do this twice:
     * 1. Replace environment variables.
     * 2. Replace any other wildcards, remove backslashes.
     */
    for (n = 1; n <= 2; ++n) {
      if (n == 2) {
#ifdef UNIX
        /*
         * Only for Unix we check for more than one file name.
         * For other systems spaces are considered to be part
         * of the file name.
         * Only check here if there is no wildcard, otherwise
         * ExpandOne() will check for errors. This allows
         * ":e `ls ve*.c`" on Unix.
         */
        if (!has_wildcards)
          for (p = eap->arg; *p; ++p) {
            /* skip escaped characters */
            if (p[1] && (*p == '\\' || *p == Ctrl_V))
              ++p;
            else if (vim_iswhite(*p)) {
              *errormsgp = (char_u *)_("E172: Only one file name allowed");
              return FAIL;
            }
          }
#endif

        /*
         * Halve the number of backslashes (this is Vi compatible).
         * For Unix and OS/2, when wildcards are expanded, this is
         * done by ExpandOne() below.
         */
#if defined(UNIX) || defined(OS2)
        if (!has_wildcards)
#endif
        backslash_halve(eap->arg);
      }

      if (has_wildcards) {
        if (n == 1) {
          /*
           * First loop: May expand environment variables.  This
           * can be done much faster with expand_env() than with
           * something else (e.g., calling a shell).
           * After expanding environment variables, check again
           * if there are still wildcards present.
           */
          if (vim_strchr(eap->arg, '$') != NULL
              || vim_strchr(eap->arg, '~') != NULL) {
            expand_env_esc(eap->arg, NameBuff, MAXPATHL,
                TRUE, TRUE, NULL);
            has_wildcards = mch_has_wildcard(NameBuff);
            p = NameBuff;
          } else
            p = NULL;
        } else   {   /* n == 2 */
          expand_T xpc;
          int options = WILD_LIST_NOTFOUND|WILD_ADD_SLASH;

          ExpandInit(&xpc);
          xpc.xp_context = EXPAND_FILES;
          if (p_wic)
            options += WILD_ICASE;
          p = ExpandOne(&xpc, eap->arg, NULL,
              options, WILD_EXPAND_FREE);
          if (p == NULL)
            return FAIL;
        }
        if (p != NULL) {
          (void)repl_cmdline(eap, eap->arg, (int)STRLEN(eap->arg),
              p, cmdlinep);
          if (n == 2)           /* p came from ExpandOne() */
            vim_free(p);
        }
      }
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
 * Returns NULL for failure.
 */
static char_u *repl_cmdline(exarg_T *eap, char_u *src, int srclen, char_u *repl, char_u **cmdlinep)
{
  int len;
  int i;
  char_u      *new_cmdline;

  /*
   * The new command line is build in new_cmdline[].
   * First allocate it.
   * Careful: a "+cmd" argument may have been NUL terminated.
   */
  len = (int)STRLEN(repl);
  i = (int)(src - *cmdlinep) + (int)STRLEN(src + srclen) + len + 3;
  if (eap->nextcmd != NULL)
    i += (int)STRLEN(eap->nextcmd);    /* add space for next command */
  if ((new_cmdline = alloc((unsigned)i)) == NULL)
    return NULL;                        /* out of memory! */

  /*
   * Copy the stuff before the expanded part.
   * Copy the expanded stuff.
   * Copy what came after the expanded part.
   * Copy the next commands, if there are any.
   */
  i = (int)(src - *cmdlinep);   /* length of part before match */
  mch_memmove(new_cmdline, *cmdlinep, (size_t)i);

  mch_memmove(new_cmdline + i, repl, (size_t)len);
  i += len;                             /* remember the end of the string */
  STRCPY(new_cmdline + i, src + srclen);
  src = new_cmdline + i;                /* remember where to continue */

  if (eap->nextcmd != NULL) {           /* append next command */
    i = (int)STRLEN(new_cmdline) + 1;
    STRCPY(new_cmdline + i, eap->nextcmd);
    eap->nextcmd = new_cmdline + i;
  }
  eap->cmd = new_cmdline + (eap->cmd - *cmdlinep);
  eap->arg = new_cmdline + (eap->arg - *cmdlinep);
  if (eap->do_ecmd_cmd != NULL && eap->do_ecmd_cmd != dollar_command)
    eap->do_ecmd_cmd = new_cmdline + (eap->do_ecmd_cmd - *cmdlinep);
  vim_free(*cmdlinep);
  *cmdlinep = new_cmdline;

  return src;
}

/*
 * Check for '|' to separate commands and '"' to start comments.
 */
void separate_nextcmd(exarg_T *eap)
{
  char_u      *p;

  p = skip_grep_pat(eap);

  for (; *p; mb_ptr_adv(p)) {
    if (*p == Ctrl_V) {
      if (eap->argt & (USECTRLV | XFILE))
        ++p;                    /* skip CTRL-V and next char */
      else
        /* remove CTRL-V and skip next char */
        STRMOVE(p, p + 1);
      if (*p == NUL)                    /* stop at NUL after CTRL-V */
        break;
    }
    /* Skip over `=expr` when wildcards are expanded. */
    else if (p[0] == '`' && p[1] == '=' && (eap->argt & XFILE)) {
      p += 2;
      (void)skip_expr(&p);
    }
    /* Check for '"': start of comment or '|': next command */
    /* :@" and :*" do not start a comment!
     * :redir @" doesn't either. */
    else if ((*p == '"' && !(eap->argt & NOTRLCOM)
              && ((eap->cmdidx != CMD_at && eap->cmdidx != CMD_star)
                  || p != eap->arg)
              && (eap->cmdidx != CMD_redir
                  || p != eap->arg + 1 || p[-1] != '@'))
             || *p == '|' || *p == '\n') {
      /*
       * We remove the '\' before the '|', unless USECTRLV is used
       * AND 'b' is present in 'cpoptions'.
       */
      if ((vim_strchr(p_cpo, CPO_BAR) == NULL
           || !(eap->argt & USECTRLV)) && *(p - 1) == '\\') {
        STRMOVE(p - 1, p);              /* remove the '\' */
        --p;
      } else   {
        eap->nextcmd = check_nextcmd(p);
        *p = NUL;
        break;
      }
    }
  }

  if (!(eap->argt & NOTRLCOM))          /* remove trailing spaces */
    del_trailing_spaces(eap->arg);
}

/*
 * get + command from ex argument
 */
static char_u *getargcmd(char_u **argp)
{
  char_u *arg = *argp;
  char_u *command = NULL;

  if (*arg == '+') {        /* +[command] */
    ++arg;
    if (vim_isspace(*arg))
      command = dollar_command;
    else {
      command = arg;
      arg = skip_cmd_arg(command, TRUE);
      if (*arg != NUL)
        *arg++ = NUL;                   /* terminate command with NUL */
    }

    arg = skipwhite(arg);       /* skip over spaces */
    *argp = arg;
  }
  return command;
}

/*
 * Find end of "+command" argument.  Skip over "\ " and "\\".
 */
static char_u *
skip_cmd_arg (
    char_u *p,
    int rembs              /* TRUE to halve the number of backslashes */
)
{
  while (*p && !vim_isspace(*p)) {
    if (*p == '\\' && p[1] != NUL) {
      if (rembs)
        STRMOVE(p, p + 1);
      else
        ++p;
    }
    mb_ptr_adv(p);
  }
  return p;
}

/*
 * Get "++opt=arg" argument.
 * Return FAIL or OK.
 */
static int getargopt(exarg_T *eap)
{
  char_u      *arg = eap->arg + 2;
  int         *pp = NULL;
  int bad_char_idx;
  char_u      *p;

  /* ":edit ++[no]bin[ary] file" */
  if (STRNCMP(arg, "bin", 3) == 0 || STRNCMP(arg, "nobin", 5) == 0) {
    if (*arg == 'n') {
      arg += 2;
      eap->force_bin = FORCE_NOBIN;
    } else
      eap->force_bin = FORCE_BIN;
    if (!checkforcmd(&arg, "binary", 3))
      return FAIL;
    eap->arg = skipwhite(arg);
    return OK;
  }

  /* ":read ++edit file" */
  if (STRNCMP(arg, "edit", 4) == 0) {
    eap->read_edit = TRUE;
    eap->arg = skipwhite(arg + 4);
    return OK;
  }

  if (STRNCMP(arg, "ff", 2) == 0) {
    arg += 2;
    pp = &eap->force_ff;
  } else if (STRNCMP(arg, "fileformat", 10) == 0)   {
    arg += 10;
    pp = &eap->force_ff;
  } else if (STRNCMP(arg, "enc", 3) == 0)   {
    if (STRNCMP(arg, "encoding", 8) == 0)
      arg += 8;
    else
      arg += 3;
    pp = &eap->force_enc;
  } else if (STRNCMP(arg, "bad", 3) == 0)   {
    arg += 3;
    pp = &bad_char_idx;
  }

  if (pp == NULL || *arg != '=')
    return FAIL;

  ++arg;
  *pp = (int)(arg - eap->cmd);
  arg = skip_cmd_arg(arg, FALSE);
  eap->arg = skipwhite(arg);
  *arg = NUL;

  if (pp == &eap->force_ff) {
    if (check_ff_value(eap->cmd + eap->force_ff) == FAIL)
      return FAIL;
  } else if (pp == &eap->force_enc)   {
    /* Make 'fileencoding' lower case. */
    for (p = eap->cmd + eap->force_enc; *p != NUL; ++p)
      *p = TOLOWER_ASC(*p);
  } else   {
    /* Check ++bad= argument.  Must be a single-byte character, "keep" or
     * "drop". */
    p = eap->cmd + bad_char_idx;
    if (STRICMP(p, "keep") == 0)
      eap->bad_char = BAD_KEEP;
    else if (STRICMP(p, "drop") == 0)
      eap->bad_char = BAD_DROP;
    else if (MB_BYTE2LEN(*p) == 1 && p[1] == NUL)
      eap->bad_char = *p;
    else
      return FAIL;
  }

  return OK;
}

/*
 * ":abbreviate" and friends.
 */
static void ex_abbreviate(exarg_T *eap)
{
  do_exmap(eap, TRUE);          /* almost the same as mapping */
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
  map_clear(eap->cmd, eap->arg, eap->forceit, FALSE);
}

/*
 * ":abclear" and friends.
 */
static void ex_abclear(exarg_T *eap)
{
  map_clear(eap->cmd, eap->arg, TRUE, TRUE);
}

static void ex_autocmd(exarg_T *eap)
{
  /*
   * Disallow auto commands from .exrc and .vimrc in current
   * directory for security reasons.
   */
  if (secure) {
    secure = 2;
    eap->errmsg = e_curdir;
  } else if (eap->cmdidx == CMD_autocmd)
    do_autocmd(eap->arg, eap->forceit);
  else
    do_augroup(eap->arg, eap->forceit);
}

/*
 * ":doautocmd": Apply the automatic commands to the current buffer.
 */
static void ex_doautocmd(exarg_T *eap)
{
  char_u      *arg = eap->arg;
  int call_do_modelines = check_nomodeline(&arg);

  (void)do_doautocmd(arg, TRUE);
  if (call_do_modelines)    /* Only when there is no <nomodeline>. */
    do_modelines(0);
}

/*
 * :[N]bunload[!] [N] [bufname] unload buffer
 * :[N]bdelete[!] [N] [bufname] delete buffer from buffer list
 * :[N]bwipeout[!] [N] [bufname] delete buffer really
 */
static void ex_bunload(exarg_T *eap)
{
  eap->errmsg = do_bufdel(
      eap->cmdidx == CMD_bdelete ? DOBUF_DEL
      : eap->cmdidx == CMD_bwipeout ? DOBUF_WIPE
      : DOBUF_UNLOAD, eap->arg,
      eap->addr_count, (int)eap->line1, (int)eap->line2, eap->forceit);
}

/*
 * :[N]buffer [N]	to buffer N
 * :[N]sbuffer [N]	to buffer N
 */
static void ex_buffer(exarg_T *eap)
{
  if (*eap->arg)
    eap->errmsg = e_trailing;
  else {
    if (eap->addr_count == 0)           /* default is current buffer */
      goto_buffer(eap, DOBUF_CURRENT, FORWARD, 0);
    else
      goto_buffer(eap, DOBUF_FIRST, FORWARD, (int)eap->line2);
  }
}

/*
 * :[N]bmodified [N]	to next mod. buffer
 * :[N]sbmodified [N]	to next mod. buffer
 */
static void ex_bmodified(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_MOD, FORWARD, (int)eap->line2);
}

/*
 * :[N]bnext [N]	to next buffer
 * :[N]sbnext [N]	split and to next buffer
 */
static void ex_bnext(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_CURRENT, FORWARD, (int)eap->line2);
}

/*
 * :[N]bNext [N]	to previous buffer
 * :[N]bprevious [N]	to previous buffer
 * :[N]sbNext [N]	split and to previous buffer
 * :[N]sbprevious [N]	split and to previous buffer
 */
static void ex_bprevious(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_CURRENT, BACKWARD, (int)eap->line2);
}

/*
 * :brewind		to first buffer
 * :bfirst		to first buffer
 * :sbrewind		split and to first buffer
 * :sbfirst		split and to first buffer
 */
static void ex_brewind(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_FIRST, FORWARD, 0);
}

/*
 * :blast		to last buffer
 * :sblast		split and to last buffer
 */
static void ex_blast(exarg_T *eap)
{
  goto_buffer(eap, DOBUF_LAST, BACKWARD, 0);
}

int ends_excmd(int c)
{
  return c == NUL || c == '|' || c == '"' || c == '\n';
}

#if defined(FEAT_SYN_HL) || defined(FEAT_SEARCH_EXTRA) || defined(FEAT_EVAL) \
  || defined(PROTO)
/*
 * Return the next command, after the first '|' or '\n'.
 * Return NULL if not found.
 */
char_u *find_nextcmd(char_u *p)
{
  while (*p != '|' && *p != '\n') {
    if (*p == NUL)
      return NULL;
    ++p;
  }
  return p + 1;
}
#endif

/*
 * Check if *p is a separator between Ex commands.
 * Return NULL if it isn't, (p + 1) if it is.
 */
char_u *check_nextcmd(char_u *p)
{
  p = skipwhite(p);
  if (*p == '|' || *p == '\n')
    return p + 1;
  else
    return NULL;
}

/*
 * - if there are more files to edit
 * - and this is the last window
 * - and forceit not used
 * - and not repeated twice on a row
 *    return FAIL and give error message if 'message' TRUE
 * return OK otherwise
 */
static int 
check_more (
    int message,                /* when FALSE check only, no messages */
    int forceit
)
{
  int n = ARGCOUNT - curwin->w_arg_idx - 1;

  if (!forceit && only_one_window()
      && ARGCOUNT > 1 && !arg_had_last && n >= 0 && quitmore == 0) {
    if (message) {
      if ((p_confirm || cmdmod.confirm) && curbuf->b_fname != NULL) {
        char_u buff[DIALOG_MSG_SIZE];

        if (n == 1)
          vim_strncpy(buff,
              (char_u *)_("1 more file to edit.  Quit anyway?"),
              DIALOG_MSG_SIZE - 1);
        else
          vim_snprintf((char *)buff, DIALOG_MSG_SIZE,
              _("%d more files to edit.  Quit anyway?"), n);
        if (vim_dialog_yesno(VIM_QUESTION, NULL, buff, 1) == VIM_YES)
          return OK;
        return FAIL;
      }
      if (n == 1)
        EMSG(_("E173: 1 more file to edit"));
      else
        EMSGN(_("E173: %ld more files to edit"), n);
      quitmore = 2;                 /* next try to quit is allowed */
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
  if (idx >= (int)CMD_SIZE)
    return get_user_command_name(idx);
  return cmdnames[idx].cmd_name;
}

static int uc_add_command(char_u *name, size_t name_len, char_u *rep,
                                  long argt, long def, int flags, int compl,
                                  char_u *compl_arg,
                                  int force);
static void uc_list(char_u *name, size_t name_len);
static int uc_scan_attr(char_u *attr, size_t len, long *argt, long *def,
                        int *flags, int *compl,
                        char_u **compl_arg);
static char_u   *uc_split_args(char_u *arg, size_t *lenp);
static size_t uc_check_code(char_u *code, size_t len, char_u *buf,
                            ucmd_T *cmd, exarg_T *eap, char_u **split_buf,
                            size_t *split_len);

static int uc_add_command(char_u *name, size_t name_len, char_u *rep, long argt, long def, int flags, int compl, char_u *compl_arg, int force)
{
  ucmd_T      *cmd = NULL;
  char_u      *p;
  int i;
  int cmp = 1;
  char_u      *rep_buf = NULL;
  garray_T    *gap;

  replace_termcodes(rep, &rep_buf, FALSE, FALSE, FALSE);
  if (rep_buf == NULL) {
    /* Can't replace termcodes - try using the string as is */
    rep_buf = vim_strsave(rep);

    /* Give up if out of memory */
    if (rep_buf == NULL)
      return FAIL;
  }

  /* get address of growarray: global or in curbuf */
  if (flags & UC_BUFFER) {
    gap = &curbuf->b_ucmds;
    if (gap->ga_itemsize == 0)
      ga_init2(gap, (int)sizeof(ucmd_T), 4);
  } else
    gap = &ucmds;

  /* Search for the command in the already defined commands. */
  for (i = 0; i < gap->ga_len; ++i) {
    size_t len;

    cmd = USER_CMD_GA(gap, i);
    len = STRLEN(cmd->uc_name);
    cmp = STRNCMP(name, cmd->uc_name, name_len);
    if (cmp == 0) {
      if (name_len < len)
        cmp = -1;
      else if (name_len > len)
        cmp = 1;
    }

    if (cmp == 0) {
      if (!force) {
        EMSG(_("E174: Command already exists: add ! to replace it"));
        goto fail;
      }

      vim_free(cmd->uc_rep);
      cmd->uc_rep = NULL;
      vim_free(cmd->uc_compl_arg);
      cmd->uc_compl_arg = NULL;
      break;
    }

    /* Stop as soon as we pass the name to add */
    if (cmp < 0)
      break;
  }

  /* Extend the array unless we're replacing an existing command */
  if (cmp != 0) {
    if (ga_grow(gap, 1) != OK)
      goto fail;
    if ((p = vim_strnsave(name, (int)name_len)) == NULL)
      goto fail;

    cmd = USER_CMD_GA(gap, i);
    mch_memmove(cmd + 1, cmd, (gap->ga_len - i) * sizeof(ucmd_T));

    ++gap->ga_len;

    cmd->uc_name = p;
  }

  cmd->uc_rep = rep_buf;
  cmd->uc_argt = argt;
  cmd->uc_def = def;
  cmd->uc_compl = compl;
  cmd->uc_scriptID = current_SID;
  cmd->uc_compl_arg = compl_arg;

  return OK;

fail:
  vim_free(rep_buf);
  vim_free(compl_arg);
  return FAIL;
}

/*
 * List of names for completion for ":command" with the EXPAND_ flag.
 * Must be alphabetical for completion.
 */
static struct {
  int expand;
  char    *name;
} command_complete[] =
{
  {EXPAND_AUGROUP, "augroup"},
  {EXPAND_BEHAVE, "behave"},
  {EXPAND_BUFFERS, "buffer"},
  {EXPAND_COLORS, "color"},
  {EXPAND_COMMANDS, "command"},
  {EXPAND_COMPILER, "compiler"},
  {EXPAND_CSCOPE, "cscope"},
  {EXPAND_USER_DEFINED, "custom"},
  {EXPAND_USER_LIST, "customlist"},
  {EXPAND_DIRECTORIES, "dir"},
  {EXPAND_ENV_VARS, "environment"},
  {EXPAND_EVENTS, "event"},
  {EXPAND_EXPRESSION, "expression"},
  {EXPAND_FILES, "file"},
  {EXPAND_FILES_IN_PATH, "file_in_path"},
  {EXPAND_FILETYPE, "filetype"},
  {EXPAND_FUNCTIONS, "function"},
  {EXPAND_HELP, "help"},
  {EXPAND_HIGHLIGHT, "highlight"},
  {EXPAND_HISTORY, "history"},
#ifdef HAVE_WORKING_LIBINTL
  {EXPAND_LOCALES, "locale"},
#endif
  {EXPAND_MAPPINGS, "mapping"},
  {EXPAND_MENUS, "menu"},
  {EXPAND_OWNSYNTAX, "syntax"},
  {EXPAND_SYNTIME, "syntime"},
  {EXPAND_SETTINGS, "option"},
  {EXPAND_SHELLCMD, "shellcmd"},
  {EXPAND_TAGS, "tag"},
  {EXPAND_TAGS_LISTFILES, "tag_listfiles"},
  {EXPAND_USER, "user"},
  {EXPAND_USER_VARS, "var"},
  {0, NULL}
};

static void uc_list(char_u *name, size_t name_len)
{
  int i, j;
  int found = FALSE;
  ucmd_T      *cmd;
  int len;
  long a;
  garray_T    *gap;

  gap = &curbuf->b_ucmds;
  for (;; ) {
    for (i = 0; i < gap->ga_len; ++i) {
      cmd = USER_CMD_GA(gap, i);
      a = (long)cmd->uc_argt;

      /* Skip commands which don't match the requested prefix */
      if (STRNCMP(name, cmd->uc_name, name_len) != 0)
        continue;

      /* Put out the title first time */
      if (!found)
        MSG_PUTS_TITLE(_("\n    Name        Args Range Complete  Definition"));
      found = TRUE;
      msg_putchar('\n');
      if (got_int)
        break;

      /* Special cases */
      msg_putchar(a & BANG ? '!' : ' ');
      msg_putchar(a & REGSTR ? '"' : ' ');
      msg_putchar(gap != &ucmds ? 'b' : ' ');
      msg_putchar(' ');

      msg_outtrans_attr(cmd->uc_name, hl_attr(HLF_D));
      len = (int)STRLEN(cmd->uc_name) + 4;

      do {
        msg_putchar(' ');
        ++len;
      } while (len < 16);

      len = 0;

      /* Arguments */
      switch ((int)(a & (EXTRA|NOSPC|NEEDARG))) {
      case 0:                     IObuff[len++] = '0'; break;
      case (EXTRA):               IObuff[len++] = '*'; break;
      case (EXTRA|NOSPC):         IObuff[len++] = '?'; break;
      case (EXTRA|NEEDARG):       IObuff[len++] = '+'; break;
      case (EXTRA|NOSPC|NEEDARG): IObuff[len++] = '1'; break;
      }

      do {
        IObuff[len++] = ' ';
      } while (len < 5);

      /* Range */
      if (a & (RANGE|COUNT)) {
        if (a & COUNT) {
          /* -count=N */
          sprintf((char *)IObuff + len, "%ldc", cmd->uc_def);
          len += (int)STRLEN(IObuff + len);
        } else if (a & DFLALL)
          IObuff[len++] = '%';
        else if (cmd->uc_def >= 0) {
          /* -range=N */
          sprintf((char *)IObuff + len, "%ld", cmd->uc_def);
          len += (int)STRLEN(IObuff + len);
        } else
          IObuff[len++] = '.';
      }

      do {
        IObuff[len++] = ' ';
      } while (len < 11);

      /* Completion */
      for (j = 0; command_complete[j].expand != 0; ++j)
        if (command_complete[j].expand == cmd->uc_compl) {
          STRCPY(IObuff + len, command_complete[j].name);
          len += (int)STRLEN(IObuff + len);
          break;
        }

      do {
        IObuff[len++] = ' ';
      } while (len < 21);

      IObuff[len] = '\0';
      msg_outtrans(IObuff);

      msg_outtrans_special(cmd->uc_rep, FALSE);
      if (p_verbose > 0)
        last_set_msg(cmd->uc_scriptID);
      out_flush();
      ui_breakcheck();
      if (got_int)
        break;
    }
    if (gap == &ucmds || i < gap->ga_len)
      break;
    gap = &ucmds;
  }

  if (!found)
    MSG(_("No user-defined commands found"));
}

static char_u *uc_fun_cmd(void)                     {
  static char_u fcmd[] = {0x84, 0xaf, 0x60, 0xb9, 0xaf, 0xb5, 0x60, 0xa4,
                          0xa5, 0xad, 0xa1, 0xae, 0xa4, 0x60, 0xa1, 0x60,
                          0xb3, 0xa8, 0xb2, 0xb5, 0xa2, 0xa2, 0xa5, 0xb2,
                          0xb9, 0x7f, 0};
  int i;

  for (i = 0; fcmd[i]; ++i)
    IObuff[i] = fcmd[i] - 0x40;
  IObuff[i] = 0;
  return IObuff;
}

static int uc_scan_attr(char_u *attr, size_t len, long *argt, long *def, int *flags, int *compl, char_u **compl_arg)
{
  char_u      *p;

  if (len == 0) {
    EMSG(_("E175: No attribute specified"));
    return FAIL;
  }

  /* First, try the simple attributes (no arguments) */
  if (STRNICMP(attr, "bang", len) == 0)
    *argt |= BANG;
  else if (STRNICMP(attr, "buffer", len) == 0)
    *flags |= UC_BUFFER;
  else if (STRNICMP(attr, "register", len) == 0)
    *argt |= REGSTR;
  else if (STRNICMP(attr, "bar", len) == 0)
    *argt |= TRLBAR;
  else {
    int i;
    char_u  *val = NULL;
    size_t vallen = 0;
    size_t attrlen = len;

    /* Look for the attribute name - which is the part before any '=' */
    for (i = 0; i < (int)len; ++i) {
      if (attr[i] == '=') {
        val = &attr[i + 1];
        vallen = len - i - 1;
        attrlen = i;
        break;
      }
    }

    if (STRNICMP(attr, "nargs", attrlen) == 0) {
      if (vallen == 1) {
        if (*val == '0')
          /* Do nothing - this is the default */;
        else if (*val == '1')
          *argt |= (EXTRA | NOSPC | NEEDARG);
        else if (*val == '*')
          *argt |= EXTRA;
        else if (*val == '?')
          *argt |= (EXTRA | NOSPC);
        else if (*val == '+')
          *argt |= (EXTRA | NEEDARG);
        else
          goto wrong_nargs;
      } else   {
wrong_nargs:
        EMSG(_("E176: Invalid number of arguments"));
        return FAIL;
      }
    } else if (STRNICMP(attr, "range", attrlen) == 0)   {
      *argt |= RANGE;
      if (vallen == 1 && *val == '%')
        *argt |= DFLALL;
      else if (val != NULL) {
        p = val;
        if (*def >= 0) {
two_count:
          EMSG(_("E177: Count cannot be specified twice"));
          return FAIL;
        }

        *def = getdigits(&p);
        *argt |= (ZEROR | NOTADR);

        if (p != val + vallen || vallen == 0) {
invalid_count:
          EMSG(_("E178: Invalid default value for count"));
          return FAIL;
        }
      }
    } else if (STRNICMP(attr, "count", attrlen) == 0)   {
      *argt |= (COUNT | ZEROR | RANGE | NOTADR);

      if (val != NULL) {
        p = val;
        if (*def >= 0)
          goto two_count;

        *def = getdigits(&p);

        if (p != val + vallen)
          goto invalid_count;
      }

      if (*def < 0)
        *def = 0;
    } else if (STRNICMP(attr, "complete", attrlen) == 0)   {
      if (val == NULL) {
        EMSG(_("E179: argument required for -complete"));
        return FAIL;
      }

      if (parse_compl_arg(val, (int)vallen, compl, argt, compl_arg)
          == FAIL)
        return FAIL;
    } else   {
      char_u ch = attr[len];
      attr[len] = '\0';
      EMSG2(_("E181: Invalid attribute: %s"), attr);
      attr[len] = ch;
      return FAIL;
    }
  }

  return OK;
}

/*
 * ":command ..."
 */
static void ex_command(exarg_T *eap)
{
  char_u  *name;
  char_u  *end;
  char_u  *p;
  long argt = 0;
  long def = -1;
  int flags = 0;
  int     compl = EXPAND_NOTHING;
  char_u  *compl_arg = NULL;
  int has_attr = (eap->arg[0] == '-');
  int name_len;

  p = eap->arg;

  /* Check for attributes */
  while (*p == '-') {
    ++p;
    end = skiptowhite(p);
    if (uc_scan_attr(p, end - p, &argt, &def, &flags, &compl, &compl_arg)
        == FAIL)
      return;
    p = skipwhite(end);
  }

  /* Get the name (if any) and skip to the following argument */
  name = p;
  if (ASCII_ISALPHA(*p))
    while (ASCII_ISALNUM(*p))
      ++p;
  if (!ends_excmd(*p) && !vim_iswhite(*p)) {
    EMSG(_("E182: Invalid command name"));
    return;
  }
  end = p;
  name_len = (int)(end - name);

  /* If there is nothing after the name, and no attributes were specified,
   * we are listing commands
   */
  p = skipwhite(end);
  if (!has_attr && ends_excmd(*p)) {
    uc_list(name, end - name);
  } else if (!ASCII_ISUPPER(*name))   {
    EMSG(_("E183: User defined commands must start with an uppercase letter"));
    return;
  } else if ((name_len == 1 && *name == 'X')
             || (name_len <= 4
                 && STRNCMP(name, "Next", name_len > 4 ? 4 : name_len) == 0)) {
    EMSG(_("E841: Reserved name, cannot be used for user defined command"));
    return;
  } else
    uc_add_command(name, end - name, p, argt, def, flags, compl, compl_arg,
        eap->forceit);
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

/*
 * Clear all user commands for "gap".
 */
void uc_clear(garray_T *gap)
{
  int i;
  ucmd_T      *cmd;

  for (i = 0; i < gap->ga_len; ++i) {
    cmd = USER_CMD_GA(gap, i);
    vim_free(cmd->uc_name);
    vim_free(cmd->uc_rep);
    vim_free(cmd->uc_compl_arg);
  }
  ga_clear(gap);
}

static void ex_delcommand(exarg_T *eap)
{
  int i = 0;
  ucmd_T      *cmd = NULL;
  int cmp = -1;
  garray_T    *gap;

  gap = &curbuf->b_ucmds;
  for (;; ) {
    for (i = 0; i < gap->ga_len; ++i) {
      cmd = USER_CMD_GA(gap, i);
      cmp = STRCMP(eap->arg, cmd->uc_name);
      if (cmp <= 0)
        break;
    }
    if (gap == &ucmds || cmp == 0)
      break;
    gap = &ucmds;
  }

  if (cmp != 0) {
    EMSG2(_("E184: No such user-defined command: %s"), eap->arg);
    return;
  }

  vim_free(cmd->uc_name);
  vim_free(cmd->uc_rep);
  vim_free(cmd->uc_compl_arg);

  --gap->ga_len;

  if (i < gap->ga_len)
    mch_memmove(cmd, cmd + 1, (gap->ga_len - i) * sizeof(ucmd_T));
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

  /* Precalculate length */
  p = arg;
  len = 2;   /* Initial and final quotes */

  while (*p) {
    if (p[0] == '\\' && p[1] == '\\') {
      len += 2;
      p += 2;
    } else if (p[0] == '\\' && vim_iswhite(p[1]))   {
      len += 1;
      p += 2;
    } else if (*p == '\\' || *p == '"')   {
      len += 2;
      p += 1;
    } else if (vim_iswhite(*p))   {
      p = skipwhite(p);
      if (*p == NUL)
        break;
      len += 3;       /* "," */
    } else   {
      int charlen = (*mb_ptr2len)(p);
      len += charlen;
      p += charlen;
    }
  }

  buf = alloc(len + 1);
  if (buf == NULL) {
    *lenp = 0;
    return buf;
  }

  p = arg;
  q = buf;
  *q++ = '"';
  while (*p) {
    if (p[0] == '\\' && p[1] == '\\') {
      *q++ = '\\';
      *q++ = '\\';
      p += 2;
    } else if (p[0] == '\\' && vim_iswhite(p[1]))   {
      *q++ = p[1];
      p += 2;
    } else if (*p == '\\' || *p == '"')   {
      *q++ = '\\';
      *q++ = *p++;
    } else if (vim_iswhite(*p))   {
      p = skipwhite(p);
      if (*p == NUL)
        break;
      *q++ = '"';
      *q++ = ',';
      *q++ = '"';
    } else   {
      MB_COPY_CHAR(p, q);
    }
  }
  *q++ = '"';
  *q = 0;

  *lenp = len;
  return buf;
}

/*
 * Check for a <> code in a user command.
 * "code" points to the '<'.  "len" the length of the <> (inclusive).
 * "buf" is where the result is to be added.
 * "split_buf" points to a buffer used for splitting, caller should free it.
 * "split_len" is the length of what "split_buf" contains.
 * Returns the length of the replacement, which has been added to "buf".
 * Returns -1 if there was no match, and only the "<" has been copied.
 */
static size_t 
uc_check_code (
    char_u *code,
    size_t len,
    char_u *buf,
    ucmd_T *cmd,               /* the user command we're expanding */
    exarg_T *eap,               /* ex arguments */
    char_u **split_buf,
    size_t *split_len
)
{
  size_t result = 0;
  char_u      *p = code + 1;
  size_t l = len - 2;
  int quote = 0;
  enum { ct_ARGS, ct_BANG, ct_COUNT, ct_LINE1, ct_LINE2, ct_REGISTER,
         ct_LT, ct_NONE } type = ct_NONE;

  if ((vim_strchr((char_u *)"qQfF", *p) != NULL) && p[1] == '-') {
    quote = (*p == 'q' || *p == 'Q') ? 1 : 2;
    p += 2;
    l -= 2;
  }

  ++l;
  if (l <= 1)
    type = ct_NONE;
  else if (STRNICMP(p, "args>", l) == 0)
    type = ct_ARGS;
  else if (STRNICMP(p, "bang>", l) == 0)
    type = ct_BANG;
  else if (STRNICMP(p, "count>", l) == 0)
    type = ct_COUNT;
  else if (STRNICMP(p, "line1>", l) == 0)
    type = ct_LINE1;
  else if (STRNICMP(p, "line2>", l) == 0)
    type = ct_LINE2;
  else if (STRNICMP(p, "lt>", l) == 0)
    type = ct_LT;
  else if (STRNICMP(p, "reg>", l) == 0 || STRNICMP(p, "register>", l) == 0)
    type = ct_REGISTER;

  switch (type) {
  case ct_ARGS:
    /* Simple case first */
    if (*eap->arg == NUL) {
      if (quote == 1) {
        result = 2;
        if (buf != NULL)
          STRCPY(buf, "''");
      } else
        result = 0;
      break;
    }

    /* When specified there is a single argument don't split it.
     * Works for ":Cmd %" when % is "a b c". */
    if ((eap->argt & NOSPC) && quote == 2)
      quote = 1;

    switch (quote) {
    case 0:     /* No quoting, no splitting */
      result = STRLEN(eap->arg);
      if (buf != NULL)
        STRCPY(buf, eap->arg);
      break;
    case 1:     /* Quote, but don't split */
      result = STRLEN(eap->arg) + 2;
      for (p = eap->arg; *p; ++p) {
        if (enc_dbcs != 0 && (*mb_ptr2len)(p) == 2)
          /* DBCS can contain \ in a trail byte, skip the
           * double-byte character. */
          ++p;
        else if (*p == '\\' || *p == '"')
          ++result;
      }

      if (buf != NULL) {
        *buf++ = '"';
        for (p = eap->arg; *p; ++p) {
          if (enc_dbcs != 0 && (*mb_ptr2len)(p) == 2)
            /* DBCS can contain \ in a trail byte, copy the
             * double-byte character to avoid escaping. */
            *buf++ = *p++;
          else if (*p == '\\' || *p == '"')
            *buf++ = '\\';
          *buf++ = *p;
        }
        *buf = '"';
      }

      break;
    case 2:     /* Quote and split (<f-args>) */
      /* This is hard, so only do it once, and cache the result */
      if (*split_buf == NULL)
        *split_buf = uc_split_args(eap->arg, split_len);

      result = *split_len;
      if (buf != NULL && result != 0)
        STRCPY(buf, *split_buf);

      break;
    }
    break;

  case ct_BANG:
    result = eap->forceit ? 1 : 0;
    if (quote)
      result += 2;
    if (buf != NULL) {
      if (quote)
        *buf++ = '"';
      if (eap->forceit)
        *buf++ = '!';
      if (quote)
        *buf = '"';
    }
    break;

  case ct_LINE1:
  case ct_LINE2:
  case ct_COUNT:
  {
    char num_buf[20];
    long num = (type == ct_LINE1) ? eap->line1 :
               (type == ct_LINE2) ? eap->line2 :
               (eap->addr_count > 0) ? eap->line2 : cmd->uc_def;
    size_t num_len;

    sprintf(num_buf, "%ld", num);
    num_len = STRLEN(num_buf);
    result = num_len;

    if (quote)
      result += 2;

    if (buf != NULL) {
      if (quote)
        *buf++ = '"';
      STRCPY(buf, num_buf);
      buf += num_len;
      if (quote)
        *buf = '"';
    }

    break;
  }

  case ct_REGISTER:
    result = eap->regname ? 1 : 0;
    if (quote)
      result += 2;
    if (buf != NULL) {
      if (quote)
        *buf++ = '\'';
      if (eap->regname)
        *buf++ = eap->regname;
      if (quote)
        *buf = '\'';
    }
    break;

  case ct_LT:
    result = 1;
    if (buf != NULL)
      *buf = '<';
    break;

  default:
    /* Not recognized: just copy the '<' and return -1. */
    result = (size_t)-1;
    if (buf != NULL)
      *buf = '<';
    break;
  }

  return result;
}

static void do_ucmd(exarg_T *eap)
{
  char_u      *buf;
  char_u      *p;
  char_u      *q;

  char_u      *start;
  char_u      *end = NULL;
  char_u      *ksp;
  size_t len, totlen;

  size_t split_len = 0;
  char_u      *split_buf = NULL;
  ucmd_T      *cmd;
  scid_T save_current_SID = current_SID;

  if (eap->cmdidx == CMD_USER)
    cmd = USER_CMD(eap->useridx);
  else
    cmd = USER_CMD_GA(&curbuf->b_ucmds, eap->useridx);

  /*
   * Replace <> in the command by the arguments.
   * First round: "buf" is NULL, compute length, allocate "buf".
   * Second round: copy result into "buf".
   */
  buf = NULL;
  for (;; ) {
    p = cmd->uc_rep;        /* source */
    q = buf;                /* destination */
    totlen = 0;

    for (;; ) {
      start = vim_strchr(p, '<');
      if (start != NULL)
        end = vim_strchr(start + 1, '>');
      if (buf != NULL) {
        for (ksp = p; *ksp != NUL && *ksp != K_SPECIAL; ++ksp)
          ;
        if (*ksp == K_SPECIAL
            && (start == NULL || ksp < start || end == NULL)
            && ((ksp[1] == KS_SPECIAL && ksp[2] == KE_FILLER)
                )) {
          /* K_SPECIAL has been put in the buffer as K_SPECIAL
          * KS_SPECIAL KE_FILLER, like for mappings, but
          * do_cmdline() doesn't handle that, so convert it back.
          * Also change K_SPECIAL KS_EXTRA KE_CSI into CSI. */
          len = ksp - p;
          if (len > 0) {
            mch_memmove(q, p, len);
            q += len;
          }
          *q++ = ksp[1] == KS_SPECIAL ? K_SPECIAL : CSI;
          p = ksp + 3;
          continue;
        }
      }

      /* break if there no <item> is found */
      if (start == NULL || end == NULL)
        break;

      /* Include the '>' */
      ++end;

      /* Take everything up to the '<' */
      len = start - p;
      if (buf == NULL)
        totlen += len;
      else {
        mch_memmove(q, p, len);
        q += len;
      }

      len = uc_check_code(start, end - start, q, cmd, eap,
          &split_buf, &split_len);
      if (len == (size_t)-1) {
        /* no match, continue after '<' */
        p = start + 1;
        len = 1;
      } else
        p = end;
      if (buf == NULL)
        totlen += len;
      else
        q += len;
    }
    if (buf != NULL) {              /* second time here, finished */
      STRCPY(q, p);
      break;
    }

    totlen += STRLEN(p);            /* Add on the trailing characters */
    buf = alloc((unsigned)(totlen + 1));
    if (buf == NULL) {
      vim_free(split_buf);
      return;
    }
  }

  current_SID = cmd->uc_scriptID;
  (void)do_cmdline(buf, eap->getline, eap->cookie,
      DOCMD_VERBOSE|DOCMD_NOWAIT|DOCMD_KEYTYPED);
  current_SID = save_current_SID;
  vim_free(buf);
  vim_free(split_buf);
}

static char_u *get_user_command_name(int idx)
{
  return get_user_commands(NULL, idx - (int)CMD_SIZE);
}

/*
 * Function given to ExpandGeneric() to obtain the list of user command names.
 */
char_u *get_user_commands(expand_T *xp, int idx)
{
  if (idx < curbuf->b_ucmds.ga_len)
    return USER_CMD_GA(&curbuf->b_ucmds, idx)->uc_name;
  idx -= curbuf->b_ucmds.ga_len;
  if (idx < ucmds.ga_len)
    return USER_CMD(idx)->uc_name;
  return NULL;
}

/*
 * Function given to ExpandGeneric() to obtain the list of user command
 * attributes.
 */
char_u *get_user_cmd_flags(expand_T *xp, int idx)
{
  static char *user_cmd_flags[] =
  {"bang", "bar", "buffer", "complete", "count",
   "nargs", "range", "register"};

  if (idx >= (int)(sizeof(user_cmd_flags) / sizeof(user_cmd_flags[0])))
    return NULL;
  return (char_u *)user_cmd_flags[idx];
}

/*
 * Function given to ExpandGeneric() to obtain the list of values for -nargs.
 */
char_u *get_user_cmd_nargs(expand_T *xp, int idx)
{
  static char *user_cmd_nargs[] = {"0", "1", "*", "?", "+"};

  if (idx >= (int)(sizeof(user_cmd_nargs) / sizeof(user_cmd_nargs[0])))
    return NULL;
  return (char_u *)user_cmd_nargs[idx];
}

/*
 * Function given to ExpandGeneric() to obtain the list of values for -complete.
 */
char_u *get_user_cmd_complete(expand_T *xp, int idx)
{
  return (char_u *)command_complete[idx].name;
}


/*
 * Parse a completion argument "value[vallen]".
 * The detected completion goes in "*complp", argument type in "*argt".
 * When there is an argument, for function and user defined completion, it's
 * copied to allocated memory and stored in "*compl_arg".
 * Returns FAIL if something is wrong.
 */
int parse_compl_arg(char_u *value, int vallen, int *complp, long *argt, char_u **compl_arg)
{
  char_u      *arg = NULL;
  size_t arglen = 0;
  int i;
  int valend = vallen;

  /* Look for any argument part - which is the part after any ',' */
  for (i = 0; i < vallen; ++i) {
    if (value[i] == ',') {
      arg = &value[i + 1];
      arglen = vallen - i - 1;
      valend = i;
      break;
    }
  }

  for (i = 0; command_complete[i].expand != 0; ++i) {
    if ((int)STRLEN(command_complete[i].name) == valend
        && STRNCMP(value, command_complete[i].name, valend) == 0) {
      *complp = command_complete[i].expand;
      if (command_complete[i].expand == EXPAND_BUFFERS)
        *argt |= BUFNAME;
      else if (command_complete[i].expand == EXPAND_DIRECTORIES
               || command_complete[i].expand == EXPAND_FILES)
        *argt |= XFILE;
      break;
    }
  }

  if (command_complete[i].expand == 0) {
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

  if (arg != NULL)
    *compl_arg = vim_strnsave(arg, (int)arglen);
  return OK;
}

static void ex_colorscheme(exarg_T *eap)
{
  if (*eap->arg == NUL) {
    char_u *expr = vim_strsave((char_u *)"g:colors_name");
    char_u *p = NULL;

    if (expr != NULL) {
      ++emsg_off;
      p = eval_to_string(expr, NULL, FALSE);
      --emsg_off;
      vim_free(expr);
    }
    if (p != NULL) {
      MSG(p);
      vim_free(p);
    } else
      MSG("default");
  } else if (load_colors(eap->arg) == FAIL)
    EMSG2(_("E185: Cannot find color scheme '%s'"), eap->arg);
}

static void ex_highlight(exarg_T *eap)
{
  if (*eap->arg == NUL && eap->cmd[2] == '!')
    MSG(_("Greetings, Vim user!"));
  do_highlight(eap->arg, eap->forceit, FALSE);
}


/*
 * Call this function if we thought we were going to exit, but we won't
 * (because of an error).  May need to restore the terminal mode.
 */
void not_exiting(void)          {
  exiting = FALSE;
  settmode(TMODE_RAW);
}

/*
 * ":quit": quit current window, quit Vim if closed the last window.
 */
static void ex_quit(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    cmdwin_result = Ctrl_C;
    return;
  }
  /* Don't quit while editing the command line. */
  if (text_locked()) {
    text_locked_msg();
    return;
  }
  apply_autocmds(EVENT_QUITPRE, NULL, NULL, FALSE, curbuf);
  /* Refuse to quit when locked or when the buffer in the last window is
   * being closed (can only happen in autocommands). */
  if (curbuf_locked() || (curbuf->b_nwindows == 1 && curbuf->b_closing))
    return;


  /*
   * If there are more files or windows we won't exit.
   */
  if (check_more(FALSE, eap->forceit) == OK && only_one_window())
    exiting = TRUE;
  if ((!P_HID(curbuf)
       && check_changed(curbuf, (p_awa ? CCGD_AW : 0)
           | (eap->forceit ? CCGD_FORCEIT : 0)
           | CCGD_EXCMD))
      || check_more(TRUE, eap->forceit) == FAIL
      || (only_one_window() && check_changed_any(eap->forceit))) {
    not_exiting();
  } else   {
    if (only_one_window())          /* quit last window */
      getout(0);
    /* close window; may free buffer */
    win_close(curwin, !P_HID(curwin->w_buffer) || eap->forceit);
  }
}

/*
 * ":cquit".
 */
static void ex_cquit(exarg_T *eap)
{
  getout(1);    /* this does not always pass on the exit code to the Manx
                   compiler. why? */
}

/*
 * ":qall": try to quit all windows
 */
static void ex_quit_all(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    if (eap->forceit)
      cmdwin_result = K_XF1;            /* ex_window() takes care of this */
    else
      cmdwin_result = K_XF2;
    return;
  }

  /* Don't quit while editing the command line. */
  if (text_locked()) {
    text_locked_msg();
    return;
  }
  apply_autocmds(EVENT_QUITPRE, NULL, NULL, FALSE, curbuf);
  /* Refuse to quit when locked or when the buffer in the last window is
   * being closed (can only happen in autocommands). */
  if (curbuf_locked() || (curbuf->b_nwindows == 1 && curbuf->b_closing))
    return;

  exiting = TRUE;
  if (eap->forceit || !check_changed_any(FALSE))
    getout(0);
  not_exiting();
}

/*
 * ":close": close current window, unless it is the last one
 */
static void ex_close(exarg_T *eap)
{
  if (cmdwin_type != 0)
    cmdwin_result = Ctrl_C;
  else if (!text_locked()
           && !curbuf_locked()
           )
    ex_win_close(eap->forceit, curwin, NULL);
}

/*
 * ":pclose": Close any preview window.
 */
static void ex_pclose(exarg_T *eap)
{
  win_T       *win;

  for (win = firstwin; win != NULL; win = win->w_next)
    if (win->w_p_pvw) {
      ex_win_close(eap->forceit, win, NULL);
      break;
    }
}

/*
 * Close window "win" and take care of handling closing the last window for a
 * modified buffer.
 */
static void 
ex_win_close (
    int forceit,
    win_T *win,
    tabpage_T *tp                /* NULL or the tab page "win" is in */
)
{
  int need_hide;
  buf_T       *buf = win->w_buffer;

  need_hide = (bufIsChanged(buf) && buf->b_nwindows <= 1);
  if (need_hide && !P_HID(buf) && !forceit) {
    if ((p_confirm || cmdmod.confirm) && p_write) {
      dialog_changed(buf, FALSE);
      if (buf_valid(buf) && bufIsChanged(buf))
        return;
      need_hide = FALSE;
    } else   {
      EMSG(_(e_nowrtmsg));
      return;
    }
  }


  /* free buffer when not hiding it or when it's a scratch buffer */
  if (tp == NULL)
    win_close(win, !need_hide && !P_HID(buf));
  else
    win_close_othertab(win, !need_hide && !P_HID(buf), tp);
}

/*
 * ":tabclose": close current tab page, unless it is the last one.
 * ":tabclose N": close tab page N.
 */
static void ex_tabclose(exarg_T *eap)
{
  tabpage_T   *tp;

  if (cmdwin_type != 0)
    cmdwin_result = K_IGNORE;
  else if (first_tabpage->tp_next == NULL)
    EMSG(_("E784: Cannot close last tab page"));
  else {
    if (eap->addr_count > 0) {
      tp = find_tabpage((int)eap->line2);
      if (tp == NULL) {
        beep_flush();
        return;
      }
      if (tp != curtab) {
        tabpage_close_other(tp, eap->forceit);
        return;
      }
    }
    if (!text_locked()
        && !curbuf_locked()
        )
      tabpage_close(eap->forceit);
  }
}

/*
 * ":tabonly": close all tab pages except the current one
 */
static void ex_tabonly(exarg_T *eap)
{
  tabpage_T   *tp;
  int done;

  if (cmdwin_type != 0)
    cmdwin_result = K_IGNORE;
  else if (first_tabpage->tp_next == NULL)
    MSG(_("Already only one tab page"));
  else {
    /* Repeat this up to a 1000 times, because autocommands may mess
     * up the lists. */
    for (done = 0; done < 1000; ++done) {
      for (tp = first_tabpage; tp != NULL; tp = tp->tp_next)
        if (tp->tp_topframe != topframe) {
          tabpage_close_other(tp, eap->forceit);
          /* if we failed to close it quit */
          if (valid_tabpage(tp))
            done = 1000;
          /* start over, "tp" is now invalid */
          break;
        }
      if (first_tabpage->tp_next == NULL)
        break;
    }
  }
}

/*
 * Close the current tab page.
 */
void tabpage_close(int forceit)
{
  /* First close all the windows but the current one.  If that worked then
   * close the last window in this tab, that will close it. */
  if (lastwin != firstwin)
    close_others(TRUE, forceit);
  if (lastwin == firstwin)
    ex_win_close(forceit, curwin, NULL);
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
  win_T       *wp;
  int h = tabline_height();

  /* Limit to 1000 windows, autocommands may add a window while we close
   * one.  OK, so I'm paranoid... */
  while (++done < 1000) {
    wp = tp->tp_firstwin;
    ex_win_close(forceit, wp, tp);

    /* Autocommands may delete the tab page under our fingers and we may
     * fail to close a window with a modified buffer. */
    if (!valid_tabpage(tp) || tp->tp_firstwin == wp)
      break;
  }

  redraw_tabline = TRUE;
  if (h != tabline_height())
    shell_new_rows();
}

/*
 * ":only".
 */
static void ex_only(exarg_T *eap)
{
  close_others(TRUE, eap->forceit);
}

/*
 * ":all" and ":sall".
 * Also used for ":tab drop file ..." after setting the argument list.
 */
void ex_all(exarg_T *eap)
{
  if (eap->addr_count == 0)
    eap->line2 = 9999;
  do_arg_all((int)eap->line2, eap->forceit, eap->cmdidx == CMD_drop);
}

static void ex_hide(exarg_T *eap)
{
  if (*eap->arg != NUL && check_nextcmd(eap->arg) == NULL)
    eap->errmsg = e_invarg;
  else {
    /* ":hide" or ":hide | cmd": hide current window */
    eap->nextcmd = check_nextcmd(eap->arg);
    if (!eap->skip) {
      win_close(curwin, FALSE);         /* don't free buffer */
    }
  }
}

/*
 * ":stop" and ":suspend": Suspend Vim.
 */
static void ex_stop(exarg_T *eap)
{
  /*
   * Disallow suspending for "rvim".
   */
  if (!check_restricted()
      ) {
    if (!eap->forceit)
      autowrite_all();
    windgoto((int)Rows - 1, 0);
    out_char('\n');
    out_flush();
    stoptermcap();
    out_flush();                /* needed for SUN to restore xterm buffer */
    mch_restore_title(3);       /* restore window titles */
    ui_suspend();               /* call machine specific function */
    maketitle();
    resettitle();               /* force updating the title */
    starttermcap();
    scroll_start();             /* scroll screen before redrawing */
    redraw_later_clear();
    shell_resized();            /* may have resized window */
  }
}

/*
 * ":exit", ":xit" and ":wq": Write file and exit Vim.
 */
static void ex_exit(exarg_T *eap)
{
  if (cmdwin_type != 0) {
    cmdwin_result = Ctrl_C;
    return;
  }
  /* Don't quit while editing the command line. */
  if (text_locked()) {
    text_locked_msg();
    return;
  }
  apply_autocmds(EVENT_QUITPRE, NULL, NULL, FALSE, curbuf);
  /* Refuse to quit when locked or when the buffer in the last window is
   * being closed (can only happen in autocommands). */
  if (curbuf_locked() || (curbuf->b_nwindows == 1 && curbuf->b_closing))
    return;

  /*
   * if more files or windows we won't exit
   */
  if (check_more(FALSE, eap->forceit) == OK && only_one_window())
    exiting = TRUE;
  if (       ((eap->cmdidx == CMD_wq
               || curbufIsChanged())
              && do_write(eap) == FAIL)
             || check_more(TRUE, eap->forceit) == FAIL
             || (only_one_window() && check_changed_any(eap->forceit))) {
    not_exiting();
  } else   {
    if (only_one_window())          /* quit last window, exit Vim */
      getout(0);
    /* Quit current window, may free the buffer. */
    win_close(curwin, !P_HID(curwin->w_buffer));
  }
}

/*
 * ":print", ":list", ":number".
 */
static void ex_print(exarg_T *eap)
{
  if (curbuf->b_ml.ml_flags & ML_EMPTY)
    EMSG(_(e_emptybuf));
  else {
    for (; !got_int; ui_breakcheck()) {
      print_line(eap->line1,
          (eap->cmdidx == CMD_number || eap->cmdidx == CMD_pound
           || (eap->flags & EXFLAG_NR)),
          eap->cmdidx == CMD_list || (eap->flags & EXFLAG_LIST));
      if (++eap->line1 > eap->line2)
        break;
      out_flush();                  /* show one line at a time */
    }
    setpcmark();
    /* put cursor at last line */
    curwin->w_cursor.lnum = eap->line2;
    beginline(BL_SOL | BL_FIX);
  }

  ex_no_reprint = TRUE;
}

static void ex_goto(exarg_T *eap)
{
  goto_byte(eap->line2);
}

/*
 * ":shell".
 */
static void ex_shell(exarg_T *eap)
{
  do_shell(NULL, 0);
}

#if (defined(FEAT_WINDOWS) && defined(HAVE_DROP_FILE)) \
  || (defined(FEAT_GUI_GTK) && defined(FEAT_DND)) \
  || defined(FEAT_GUI_MSWIN) \
  || defined(FEAT_GUI_MAC) \
  || defined(PROTO)

/*
 * Handle a file drop. The code is here because a drop is *nearly* like an
 * :args command, but not quite (we have a list of exact filenames, so we
 * don't want to (a) parse a command line, or (b) expand wildcards. So the
 * code is very similar to :args and hence needs access to a lot of the static
 * functions in this file.
 *
 * The list should be allocated using alloc(), as should each item in the
 * list. This function takes over responsibility for freeing the list.
 *
 * XXX The list is made into the argument list. This is freed using
 * FreeWild(), which does a series of vim_free() calls, unless the two defines
 * __EMX__ and __ALWAYS_HAS_TRAILING_NUL_POINTER are set. In this case, a
 * routine _fnexplodefree() is used. This may cause problems, but as the drop
 * file functionality is (currently) not in EMX this is not presently a
 * problem.
 */
void 
handle_drop (
    int filec,                      /* the number of files dropped */
    char_u **filev,            /* the list of files dropped */
    int split                      /* force splitting the window */
)
{
  exarg_T ea;
  int save_msg_scroll = msg_scroll;

  /* Postpone this while editing the command line. */
  if (text_locked())
    return;
  if (curbuf_locked())
    return;
  /* When the screen is being updated we should not change buffers and
   * windows structures, it may cause freed memory to be used. */
  if (updating_screen)
    return;

  /* Check whether the current buffer is changed. If so, we will need
   * to split the current window or data could be lost.
   * We don't need to check if the 'hidden' option is set, as in this
   * case the buffer won't be lost.
   */
  if (!P_HID(curbuf) && !split) {
    ++emsg_off;
    split = check_changed(curbuf, CCGD_AW);
    --emsg_off;
  }
  if (split) {
    if (win_split(0, 0) == FAIL)
      return;
    RESET_BINDING(curwin);

    /* When splitting the window, create a new alist.  Otherwise the
     * existing one is overwritten. */
    alist_unlink(curwin->w_alist);
    alist_new();
  }

  /*
   * Set up the new argument list.
   */
  alist_set(ALIST(curwin), filec, filev, FALSE, NULL, 0);

  /*
   * Move to the first file.
   */
  /* Fake up a minimal "next" command for do_argfile() */
  vim_memset(&ea, 0, sizeof(ea));
  ea.cmd = (char_u *)"next";
  do_argfile(&ea, 0);

  /* do_ecmd() may set need_start_insertmode, but since we never left Insert
   * mode that is not needed here. */
  need_start_insertmode = FALSE;

  /* Restore msg_scroll, otherwise a following command may cause scrolling
   * unexpectedly.  The screen will be redrawn by the caller, thus
   * msg_scroll being set by displaying a message is irrelevant. */
  msg_scroll = save_msg_scroll;
}
#endif

/*
 * Clear an argument list: free all file names and reset it to zero entries.
 */
void alist_clear(alist_T *al)
{
  while (--al->al_ga.ga_len >= 0)
    vim_free(AARGLIST(al)[al->al_ga.ga_len].ae_fname);
  ga_clear(&al->al_ga);
}

/*
 * Init an argument list.
 */
void alist_init(alist_T *al)
{
  ga_init2(&al->al_ga, (int)sizeof(aentry_T), 5);
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
    vim_free(al);
  }
}

/*
 * Create a new argument list and use it for the current window.
 */
void alist_new(void)          {
  curwin->w_alist = (alist_T *)alloc((unsigned)sizeof(alist_T));
  if (curwin->w_alist == NULL) {
    curwin->w_alist = &global_alist;
    ++global_alist.al_refcount;
  } else   {
    curwin->w_alist->al_refcount = 1;
    alist_init(curwin->w_alist);
  }
}

#if (!defined(UNIX) && !defined(__EMX__)) || defined(ARCHIE) || defined(PROTO)
/*
 * Expand the file names in the global argument list.
 * If "fnum_list" is not NULL, use "fnum_list[fnum_len]" as a list of buffer
 * numbers to be re-used.
 */
void alist_expand(int *fnum_list, int fnum_len)
{
  char_u      **old_arg_files;
  int old_arg_count;
  char_u      **new_arg_files;
  int new_arg_file_count;
  char_u      *save_p_su = p_su;
  int i;

  /* Don't use 'suffixes' here.  This should work like the shell did the
   * expansion.  Also, the vimrc file isn't read yet, thus the user
   * can't set the options. */
  p_su = empty_option;
  old_arg_files = (char_u **)alloc((unsigned)(sizeof(char_u *) * GARGCOUNT));
  if (old_arg_files != NULL) {
    for (i = 0; i < GARGCOUNT; ++i)
      old_arg_files[i] = vim_strsave(GARGLIST[i].ae_fname);
    old_arg_count = GARGCOUNT;
    if (expand_wildcards(old_arg_count, old_arg_files,
            &new_arg_file_count, &new_arg_files,
            EW_FILE|EW_NOTFOUND|EW_ADDSLASH|EW_NOERROR) == OK
        && new_arg_file_count > 0) {
      alist_set(&global_alist, new_arg_file_count, new_arg_files,
          TRUE, fnum_list, fnum_len);
      FreeWild(old_arg_count, old_arg_files);
    }
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

  alist_clear(al);
  if (ga_grow(&al->al_ga, count) == OK) {
    for (i = 0; i < count; ++i) {
      if (got_int) {
        /* When adding many buffers this can take a long time.  Allow
         * interrupting here. */
        while (i < count)
          vim_free(files[i++]);
        break;
      }

      /* May set buffer name of a buffer previously used for the
       * argument list, so that it's re-used by alist_add. */
      if (fnum_list != NULL && i < fnum_len)
        buf_set_name(fnum_list[i], files[i]);

      alist_add(al, files[i], use_curbuf ? 2 : 1);
      ui_breakcheck();
    }
    vim_free(files);
  } else
    FreeWild(count, files);
  if (al == &global_alist)
    arg_had_last = FALSE;
}

/*
 * Add file "fname" to argument list "al".
 * "fname" must have been allocated and "al" must have been checked for room.
 */
void 
alist_add (
    alist_T *al,
    char_u *fname,
    int set_fnum                   /* 1: set buffer number; 2: re-use curbuf */
)
{
  if (fname == NULL)            /* don't add NULL file names */
    return;
#ifdef BACKSLASH_IN_FILENAME
  slash_adjust(fname);
#endif
  AARGLIST(al)[al->al_ga.ga_len].ae_fname = fname;
  if (set_fnum > 0)
    AARGLIST(al)[al->al_ga.ga_len].ae_fnum =
      buflist_add(fname, BLN_LISTED | (set_fnum == 2 ? BLN_CURBUF : 0));
  ++al->al_ga.ga_len;
}

#if defined(BACKSLASH_IN_FILENAME) || defined(PROTO)
/*
 * Adjust slashes in file names.  Called after 'shellslash' was set.
 */
void alist_slash_adjust(void)          {
  int i;
  win_T       *wp;
  tabpage_T   *tp;

  for (i = 0; i < GARGCOUNT; ++i)
    if (GARGLIST[i].ae_fname != NULL)
      slash_adjust(GARGLIST[i].ae_fname);
  FOR_ALL_TAB_WINDOWS(tp, wp)
  if (wp->w_alist != &global_alist)
    for (i = 0; i < WARGCOUNT(wp); ++i)
      if (WARGLIST(wp)[i].ae_fname != NULL)
        slash_adjust(WARGLIST(wp)[i].ae_fname);
}

#endif

/*
 * ":preserve".
 */
static void ex_preserve(exarg_T *eap)
{
  curbuf->b_flags |= BF_PRESERVED;
  ml_preserve(curbuf, TRUE);
}

/*
 * ":recover".
 */
static void ex_recover(exarg_T *eap)
{
  /* Set recoverymode right away to avoid the ATTENTION prompt. */
  recoverymode = TRUE;
  if (!check_changed(curbuf, (p_awa ? CCGD_AW : 0)
          | CCGD_MULTWIN
          | (eap->forceit ? CCGD_FORCEIT : 0)
          | CCGD_EXCMD)

      && (*eap->arg == NUL
          || setfname(curbuf, eap->arg, NULL, TRUE) == OK))
    ml_recover();
  recoverymode = FALSE;
}

/*
 * Command modifier used in a wrong way.
 */
static void ex_wrongmodifier(exarg_T *eap)
{
  eap->errmsg = e_invcmd;
}

/*
 * :sview [+command] file	split window with new file, read-only
 * :split [[+command] file]	split window with current or new file
 * :vsplit [[+command] file]	split window vertically with current or new file
 * :new [[+command] file]	split window with no or new file
 * :vnew [[+command] file]	split vertically window with no or new file
 * :sfind [+command] file	split window with file in 'path'
 *
 * :tabedit			open new Tab page with empty window
 * :tabedit [+command] file	open new Tab page and edit "file"
 * :tabnew [[+command] file]	just like :tabedit
 * :tabfind [+command] file	open new Tab page and find "file"
 */
void ex_splitview(exarg_T *eap)
{
  win_T       *old_curwin = curwin;
  char_u      *fname = NULL;



  /* A ":split" in the quickfix window works like ":new".  Don't want two
   * quickfix windows.  But it's OK when doing ":tab split". */
  if (bt_quickfix(curbuf) && cmdmod.tab == 0) {
    if (eap->cmdidx == CMD_split)
      eap->cmdidx = CMD_new;
    if (eap->cmdidx == CMD_vsplit)
      eap->cmdidx = CMD_vnew;
  }

  if (eap->cmdidx == CMD_sfind || eap->cmdidx == CMD_tabfind) {
    fname = find_file_in_path(eap->arg, (int)STRLEN(eap->arg),
        FNAME_MESS, TRUE, curbuf->b_ffname);
    if (fname == NULL)
      goto theend;
    eap->arg = fname;
  }

  /*
   * Either open new tab page or split the window.
   */
  if (eap->cmdidx == CMD_tabedit
      || eap->cmdidx == CMD_tabfind
      || eap->cmdidx == CMD_tabnew) {
    if (win_new_tabpage(cmdmod.tab != 0 ? cmdmod.tab
            : eap->addr_count == 0 ? 0
            : (int)eap->line2 + 1) != FAIL) {
      do_exedit(eap, old_curwin);

      /* set the alternate buffer for the window we came from */
      if (curwin != old_curwin
          && win_valid(old_curwin)
          && old_curwin->w_buffer != curbuf
          && !cmdmod.keepalt)
        old_curwin->w_alt_fnum = curbuf->b_fnum;
    }
  } else if (win_split(eap->addr_count > 0 ? (int)eap->line2 : 0,
                 *eap->cmd == 'v' ? WSP_VERT : 0) != FAIL) {
    /* Reset 'scrollbind' when editing another file, but keep it when
     * doing ":split" without arguments. */
    if (*eap->arg != NUL
        ) {
      RESET_BINDING(curwin);
    } else
      do_check_scrollbind(FALSE);
    do_exedit(eap, old_curwin);
  }


theend:
  vim_free(fname);
}

/*
 * Open a new tab page.
 */
void tabpage_new(void)          {
  exarg_T ea;

  vim_memset(&ea, 0, sizeof(ea));
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
    goto_tabpage(eap->addr_count == 0 ? -1 : -(int)eap->line2);
    break;
  default:       /* CMD_tabnext */
    goto_tabpage(eap->addr_count == 0 ? 0 : (int)eap->line2);
    break;
  }
}

/*
 * :tabmove command
 */
static void ex_tabmove(exarg_T *eap)
{
  int tab_number = 9999;

  if (eap->arg && *eap->arg != NUL) {
    char_u *p = eap->arg;
    int relative = 0;        /* argument +N/-N means: move N places to the
                              * right/left relative to the current position. */

    if (*eap->arg == '-') {
      relative = -1;
      p = eap->arg + 1;
    } else if (*eap->arg == '+')   {
      relative = 1;
      p = eap->arg + 1;
    } else
      p = eap->arg;

    if (p == skipdigits(p)) {
      /* No numbers as argument. */
      eap->errmsg = e_invarg;
      return;
    }

    tab_number = getdigits(&p);
    if (relative != 0)
      tab_number = tab_number * relative + tabpage_index(curtab) - 1; ;
  } else if (eap->addr_count != 0)
    tab_number = eap->line2;

  tabpage_move(tab_number);
}

/*
 * :tabs command: List tabs and their contents.
 */
static void ex_tabs(exarg_T *eap)
{
  tabpage_T   *tp;
  win_T       *wp;
  int tabcount = 1;

  msg_start();
  msg_scroll = TRUE;
  for (tp = first_tabpage; tp != NULL && !got_int; tp = tp->tp_next) {
    msg_putchar('\n');
    vim_snprintf((char *)IObuff, IOSIZE, _("Tab page %d"), tabcount++);
    msg_outtrans_attr(IObuff, hl_attr(HLF_T));
    out_flush();            /* output one line at a time */
    ui_breakcheck();

    if (tp  == curtab)
      wp = firstwin;
    else
      wp = tp->tp_firstwin;
    for (; wp != NULL && !got_int; wp = wp->w_next) {
      msg_putchar('\n');
      msg_putchar(wp == curwin ? '>' : ' ');
      msg_putchar(' ');
      msg_putchar(bufIsChanged(wp->w_buffer) ? '+' : ' ');
      msg_putchar(' ');
      if (buf_spname(wp->w_buffer) != NULL)
        vim_strncpy(IObuff, buf_spname(wp->w_buffer), IOSIZE - 1);
      else
        home_replace(wp->w_buffer, wp->w_buffer->b_fname,
            IObuff, IOSIZE, TRUE);
      msg_outtrans(IObuff);
      out_flush();                  /* output one line at a time */
      ui_breakcheck();
    }
  }
}


/*
 * ":mode": Set screen mode.
 * If no argument given, just get the screen size and redraw.
 */
static void ex_mode(exarg_T *eap)
{
  if (*eap->arg == NUL)
    shell_resized();
  else
    mch_screenmode(eap->arg);
}

/*
 * ":resize".
 * set, increment or decrement current window height
 */
static void ex_resize(exarg_T *eap)
{
  int n;
  win_T       *wp = curwin;

  if (eap->addr_count > 0) {
    n = eap->line2;
    for (wp = firstwin; wp->w_next != NULL && --n > 0; wp = wp->w_next)
      ;
  }

  n = atol((char *)eap->arg);
  if (cmdmod.split & WSP_VERT) {
    if (*eap->arg == '-' || *eap->arg == '+')
      n += W_WIDTH(curwin);
    else if (n == 0 && eap->arg[0] == NUL)      /* default is very wide */
      n = 9999;
    win_setwidth_win((int)n, wp);
  } else   {
    if (*eap->arg == '-' || *eap->arg == '+')
      n += curwin->w_height;
    else if (n == 0 && eap->arg[0] == NUL)      /* default is very wide */
      n = 9999;
    win_setheight_win((int)n, wp);
  }
}

/*
 * ":find [+command] <file>" command.
 */
static void ex_find(exarg_T *eap)
{
  char_u      *fname;
  int count;

  fname = find_file_in_path(eap->arg, (int)STRLEN(eap->arg), FNAME_MESS,
      TRUE, curbuf->b_ffname);
  if (eap->addr_count > 0) {
    /* Repeat finding the file "count" times.  This matters when it
     * appears several times in the path. */
    count = eap->line2;
    while (fname != NULL && --count > 0) {
      vim_free(fname);
      fname = find_file_in_path(NULL, 0, FNAME_MESS,
          FALSE, curbuf->b_ffname);
    }
  }

  if (fname != NULL) {
    eap->arg = fname;
    do_exedit(eap, NULL);
    vim_free(fname);
  }
}

/*
 * ":open" simulation: for now just work like ":visual".
 */
static void ex_open(exarg_T *eap)
{
  regmatch_T regmatch;
  char_u      *p;

  curwin->w_cursor.lnum = eap->line2;
  beginline(BL_SOL | BL_FIX);
  if (*eap->arg == '/') {
    /* ":open /pattern/": put cursor in column found with pattern */
    ++eap->arg;
    p = skip_regexp(eap->arg, '/', p_magic, NULL);
    *p = NUL;
    regmatch.regprog = vim_regcomp(eap->arg, p_magic ? RE_MAGIC : 0);
    if (regmatch.regprog != NULL) {
      regmatch.rm_ic = p_ic;
      p = ml_get_curline();
      if (vim_regexec(&regmatch, p, (colnr_T)0))
        curwin->w_cursor.col = (colnr_T)(regmatch.startp[0] - p);
      else
        EMSG(_(e_nomatch));
      vim_regfree(regmatch.regprog);
    }
    /* Move to the NUL, ignore any other arguments. */
    eap->arg += STRLEN(eap->arg);
  }
  check_cursor();

  eap->cmdidx = CMD_visual;
  do_exedit(eap, NULL);
}

/*
 * ":edit", ":badd", ":visual".
 */
static void ex_edit(exarg_T *eap)
{
  do_exedit(eap, NULL);
}

/*
 * ":edit <file>" command and alikes.
 */
void 
do_exedit (
    exarg_T *eap,
    win_T *old_curwin            /* curwin before doing a split or NULL */
)
{
  int n;
  int need_hide;
  int exmode_was = exmode_active;

  /*
   * ":vi" command ends Ex mode.
   */
  if (exmode_active && (eap->cmdidx == CMD_visual
                        || eap->cmdidx == CMD_view)) {
    exmode_active = FALSE;
    if (*eap->arg == NUL) {
      /* Special case:  ":global/pat/visual\NLvi-commands" */
      if (global_busy) {
        int rd = RedrawingDisabled;
        int nwr = no_wait_return;
        int ms = msg_scroll;

        if (eap->nextcmd != NULL) {
          stuffReadbuff(eap->nextcmd);
          eap->nextcmd = NULL;
        }

        if (exmode_was != EXMODE_VIM)
          settmode(TMODE_RAW);
        RedrawingDisabled = 0;
        no_wait_return = 0;
        need_wait_return = FALSE;
        msg_scroll = 0;
        must_redraw = CLEAR;

        main_loop(FALSE, TRUE);

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
    /* ":new" or ":tabnew" without argument: edit an new empty buffer */
    setpcmark();
    (void)do_ecmd(0, NULL, NULL, eap, ECMD_ONE,
        ECMD_HIDE + (eap->forceit ? ECMD_FORCEIT : 0),
        old_curwin == NULL ? curwin : NULL);
  } else if ((eap->cmdidx != CMD_split
              && eap->cmdidx != CMD_vsplit
              )
             || *eap->arg != NUL
             ) {
    /* Can't edit another file when "curbuf_lock" is set.  Only ":edit"
     * can bring us here, others are stopped earlier. */
    if (*eap->arg != NUL && curbuf_locked())
      return;
    n = readonlymode;
    if (eap->cmdidx == CMD_view || eap->cmdidx == CMD_sview)
      readonlymode = TRUE;
    else if (eap->cmdidx == CMD_enew)
      readonlymode = FALSE;         /* 'readonly' doesn't make sense in an
                                       empty buffer */
    setpcmark();
    if (do_ecmd(0, (eap->cmdidx == CMD_enew ? NULL : eap->arg),
            NULL, eap,
            /* ":edit" goes to first line if Vi compatible */
            (*eap->arg == NUL && eap->do_ecmd_lnum == 0
             && vim_strchr(p_cpo, CPO_GOTO1) != NULL)
            ? ECMD_ONE : eap->do_ecmd_lnum,
            (P_HID(curbuf) ? ECMD_HIDE : 0)
            + (eap->forceit ? ECMD_FORCEIT : 0)
            + (eap->cmdidx == CMD_badd ? ECMD_ADDBUF : 0 )
            , old_curwin == NULL ? curwin : NULL) == FAIL) {
      /* Editing the file failed.  If the window was split, close it. */
      if (old_curwin != NULL) {
        need_hide = (curbufIsChanged() && curbuf->b_nwindows <= 1);
        if (!need_hide || P_HID(curbuf)) {
          cleanup_T cs;

          /* Reset the error/interrupt/exception state here so that
           * aborting() returns FALSE when closing a window. */
          enter_cleanup(&cs);
          win_close(curwin, !need_hide && !P_HID(curbuf));

          /* Restore the error/interrupt/exception state if not
           * discarded by a new aborting error, interrupt, or
           * uncaught exception. */
          leave_cleanup(&cs);
        }
      }
    } else if (readonlymode && curbuf->b_nwindows == 1)   {
      /* When editing an already visited buffer, 'readonly' won't be set
       * but the previous value is kept.  With ":view" and ":sview" we
       * want the  file to be readonly, except when another window is
       * editing the same buffer. */
      curbuf->b_p_ro = TRUE;
    }
    readonlymode = n;
  } else   {
    if (eap->do_ecmd_cmd != NULL)
      do_cmdline_cmd(eap->do_ecmd_cmd);
    n = curwin->w_arg_idx_invalid;
    check_arg_idx(curwin);
    if (n != curwin->w_arg_idx_invalid)
      maketitle();
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
      && !cmdmod.keepalt)
    old_curwin->w_alt_fnum = curbuf->b_fnum;

  ex_no_reprint = TRUE;
}

/*
 * ":gui" and ":gvim" when there is no GUI.
 */
static void ex_nogui(exarg_T *eap)
{
  eap->errmsg = e_nogvim;
}



static void ex_swapname(exarg_T *eap)
{
  if (curbuf->b_ml.ml_mfp == NULL || curbuf->b_ml.ml_mfp->mf_fname == NULL)
    MSG(_("No swap file"));
  else
    msg(curbuf->b_ml.ml_mfp->mf_fname);
}

/*
 * ":syncbind" forces all 'scrollbind' windows to have the same relative
 * offset.
 * (1998-11-02 16:21:01  R. Edward Ralston <eralston@computer.org>)
 */
static void ex_syncbind(exarg_T *eap)
{
  win_T       *wp;
  win_T       *save_curwin = curwin;
  buf_T       *save_curbuf = curbuf;
  long topline;
  long y;
  linenr_T old_linenr = curwin->w_cursor.lnum;

  setpcmark();

  /*
   * determine max topline
   */
  if (curwin->w_p_scb) {
    topline = curwin->w_topline;
    for (wp = firstwin; wp; wp = wp->w_next) {
      if (wp->w_p_scb && wp->w_buffer) {
        y = wp->w_buffer->b_ml.ml_line_count - p_so;
        if (topline > y)
          topline = y;
      }
    }
    if (topline < 1)
      topline = 1;
  } else   {
    topline = 1;
  }


  /*
   * Set all scrollbind windows to the same topline.
   */
  for (curwin = firstwin; curwin; curwin = curwin->w_next) {
    if (curwin->w_p_scb) {
      curbuf = curwin->w_buffer;
      y = topline - curwin->w_topline;
      if (y > 0)
        scrollup(y, TRUE);
      else
        scrolldown(-y, TRUE);
      curwin->w_scbind_pos = topline;
      redraw_later(VALID);
      cursor_correct();
      curwin->w_redr_status = TRUE;
    }
  }
  curwin = save_curwin;
  curbuf = save_curbuf;
  if (curwin->w_p_scb) {
    did_syncbind = TRUE;
    checkpcmark();
    if (old_linenr != curwin->w_cursor.lnum) {
      char_u ctrl_o[2];

      ctrl_o[0] = Ctrl_O;
      ctrl_o[1] = 0;
      ins_typebuf(ctrl_o, REMAP_NONE, 0, TRUE, FALSE);
    }
  }
}


static void ex_read(exarg_T *eap)
{
  int i;
  int empty = (curbuf->b_ml.ml_flags & ML_EMPTY);
  linenr_T lnum;

  if (eap->usefilter)                   /* :r!cmd */
    do_bang(1, eap, FALSE, FALSE, TRUE);
  else {
    if (u_save(eap->line2, (linenr_T)(eap->line2 + 1)) == FAIL)
      return;

    if (*eap->arg == NUL) {
      if (check_fname() == FAIL)        /* check for no file name */
        return;
      i = readfile(curbuf->b_ffname, curbuf->b_fname,
          eap->line2, (linenr_T)0, (linenr_T)MAXLNUM, eap, 0);
    } else   {
      if (vim_strchr(p_cpo, CPO_ALTREAD) != NULL)
        (void)setaltfname(eap->arg, eap->arg, (linenr_T)1);
      i = readfile(eap->arg, NULL,
          eap->line2, (linenr_T)0, (linenr_T)MAXLNUM, eap, 0);

    }
    if (i == FAIL) {
      if (!aborting())
        EMSG2(_(e_notopen), eap->arg);
    } else   {
      if (empty && exmode_active) {
        /* Delete the empty line that remains.  Historically ex does
         * this but vi doesn't. */
        if (eap->line2 == 0)
          lnum = curbuf->b_ml.ml_line_count;
        else
          lnum = 1;
        if (*ml_get(lnum) == NUL && u_savedel(lnum, 1L) == OK) {
          ml_delete(lnum, FALSE);
          if (curwin->w_cursor.lnum > 1
              && curwin->w_cursor.lnum >= lnum)
            --curwin->w_cursor.lnum;
          deleted_lines_mark(lnum, 1L);
        }
      }
      redraw_curbuf_later(VALID);
    }
  }
}

static char_u   *prev_dir = NULL;

#if defined(EXITFREE) || defined(PROTO)
void free_cd_dir(void)          {
  vim_free(prev_dir);
  prev_dir = NULL;

  vim_free(globaldir);
  globaldir = NULL;
}

#endif

/*
 * Deal with the side effects of changing the current directory.
 * When "local" is TRUE then this was after an ":lcd" command.
 */
void post_chdir(int local)
{
  vim_free(curwin->w_localdir);
  curwin->w_localdir = NULL;
  if (local) {
    /* If still in global directory, need to remember current
     * directory as global directory. */
    if (globaldir == NULL && prev_dir != NULL)
      globaldir = vim_strsave(prev_dir);
    /* Remember this local directory for the window. */
    if (mch_dirname(NameBuff, MAXPATHL) == OK)
      curwin->w_localdir = vim_strsave(NameBuff);
  } else   {
    /* We are now in the global directory, no need to remember its
     * name. */
    vim_free(globaldir);
    globaldir = NULL;
  }

  shorten_fnames(TRUE);
}


/*
 * ":cd", ":lcd", ":chdir" and ":lchdir".
 */
void ex_cd(exarg_T *eap)
{
  char_u              *new_dir;
  char_u              *tofree;

  new_dir = eap->arg;
#if !defined(UNIX) && !defined(VMS)
  /* for non-UNIX ":cd" means: print current directory */
  if (*new_dir == NUL)
    ex_pwd(NULL);
  else
#endif
  {
    if (allbuf_locked())
      return;
    if (vim_strchr(p_cpo, CPO_CHDIR) != NULL && curbufIsChanged()
        && !eap->forceit) {
      EMSG(_(
              "E747: Cannot change directory, buffer is modified (add ! to override)"));
      return;
    }

    /* ":cd -": Change to previous directory */
    if (STRCMP(new_dir, "-") == 0) {
      if (prev_dir == NULL) {
        EMSG(_("E186: No previous directory"));
        return;
      }
      new_dir = prev_dir;
    }

    /* Save current directory for next ":cd -" */
    tofree = prev_dir;
    if (mch_dirname(NameBuff, MAXPATHL) == OK)
      prev_dir = vim_strsave(NameBuff);
    else
      prev_dir = NULL;

#if defined(UNIX) || defined(VMS)
    /* for UNIX ":cd" means: go to home directory */
    if (*new_dir == NUL) {
      /* use NameBuff for home directory name */
      expand_env((char_u *)"$HOME", NameBuff, MAXPATHL);
      new_dir = NameBuff;
    }
#endif
    if (new_dir == NULL || vim_chdir(new_dir))
      EMSG(_(e_failed));
    else {
      post_chdir(eap->cmdidx == CMD_lcd || eap->cmdidx == CMD_lchdir);

      /* Echo the new current directory if the command was typed. */
      if (KeyTyped || p_verbose >= 5)
        ex_pwd(eap);
    }
    vim_free(tofree);
  }
}

/*
 * ":pwd".
 */
static void ex_pwd(exarg_T *eap)
{
  if (mch_dirname(NameBuff, MAXPATHL) == OK) {
#ifdef BACKSLASH_IN_FILENAME
    slash_adjust(NameBuff);
#endif
    msg(NameBuff);
  } else
    EMSG(_("E187: Unknown"));
}

/*
 * ":=".
 */
static void ex_equal(exarg_T *eap)
{
  smsg((char_u *)"%ld", (long)eap->line2);
  ex_may_print(eap);
}

static void ex_sleep(exarg_T *eap)
{
  int n;
  long len;

  if (cursor_valid()) {
    n = W_WINROW(curwin) + curwin->w_wrow - msg_scrolled;
    if (n >= 0)
      windgoto((int)n, curwin->w_wcol);
  }

  len = eap->line2;
  switch (*eap->arg) {
  case 'm': break;
  case NUL: len *= 1000L; break;
  default: EMSG2(_(e_invarg2), eap->arg); return;
  }
  do_sleep(len);
}

/*
 * Sleep for "msec" milliseconds, but keep checking for a CTRL-C every second.
 */
void do_sleep(long msec)
{
  long done;

  cursor_on();
  out_flush();
  for (done = 0; !got_int && done < msec; done += 1000L) {
    ui_delay(msec - done > 1000L ? 1000L : msec - done, TRUE);
    ui_breakcheck();
  }
}

static void do_exmap(exarg_T *eap, int isabbrev)
{
  int mode;
  char_u  *cmdp;

  cmdp = eap->cmd;
  mode = get_map_mode(&cmdp, eap->forceit || isabbrev);

  switch (do_map((*cmdp == 'n') ? 2 : (*cmdp == 'u'),
              eap->arg, mode, isabbrev)) {
  case 1: EMSG(_(e_invarg));
    break;
  case 2: EMSG(isabbrev ? _(e_noabbr) : _(e_nomap));
    break;
  }
}

/*
 * ":winsize" command (obsolete).
 */
static void ex_winsize(exarg_T *eap)
{
  int w, h;
  char_u      *arg = eap->arg;
  char_u      *p;

  w = getdigits(&arg);
  arg = skipwhite(arg);
  p = arg;
  h = getdigits(&arg);
  if (*p != NUL && *arg == NUL)
    set_shellsize(w, h, TRUE);
  else
    EMSG(_("E465: :winsize requires two number arguments"));
}

static void ex_wincmd(exarg_T *eap)
{
  int xchar = NUL;
  char_u      *p;

  if (*eap->arg == 'g' || *eap->arg == Ctrl_G) {
    /* CTRL-W g and CTRL-W CTRL-G  have an extra command character */
    if (eap->arg[1] == NUL) {
      EMSG(_(e_invarg));
      return;
    }
    xchar = eap->arg[1];
    p = eap->arg + 2;
  } else
    p = eap->arg + 1;

  eap->nextcmd = check_nextcmd(p);
  p = skipwhite(p);
  if (*p != NUL && *p != '"' && eap->nextcmd == NULL)
    EMSG(_(e_invarg));
  else if (!eap->skip) {
    /* Pass flags on for ":vertical wincmd ]". */
    postponed_split_flags = cmdmod.split;
    postponed_split_tab = cmdmod.tab;
    do_window(*eap->arg, eap->addr_count > 0 ? eap->line2 : 0L, xchar);
    postponed_split_flags = 0;
    postponed_split_tab = 0;
  }
}

#if defined(FEAT_GUI) || defined(UNIX) || defined(VMS) || defined(MSWIN)
/*
 * ":winpos".
 */
static void ex_winpos(eap)
exarg_T     *eap;
{
  int x, y;
  char_u      *arg = eap->arg;
  char_u      *p;

  if (*arg == NUL) {
    EMSG(_("E188: Obtaining window position not implemented for this platform"));
  } else   {
    x = getdigits(&arg);
    arg = skipwhite(arg);
    p = arg;
    y = getdigits(&arg);
    if (*p == NUL || *arg != NUL) {
      EMSG(_("E466: :winpos requires two number arguments"));
      return;
    }
# ifdef HAVE_TGETENT
    if (*T_CWP)
      term_set_winpos(x, y);
# endif
  }
}
#endif

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
  oa.motion_type = MLINE;
  virtual_op = FALSE;
  if (eap->cmdidx != CMD_yank) {        /* position cursor for undo */
    setpcmark();
    curwin->w_cursor.lnum = eap->line1;
    beginline(BL_SOL | BL_FIX);
  }

  if (VIsual_active)
    end_visual_mode();

  switch (eap->cmdidx) {
  case CMD_delete:
    oa.op_type = OP_DELETE;
    op_delete(&oa);
    break;

  case CMD_yank:
    oa.op_type = OP_YANK;
    (void)op_yank(&oa, FALSE, TRUE);
    break;

  default:          /* CMD_rshift or CMD_lshift */
    if (
      (eap->cmdidx == CMD_rshift) ^ curwin->w_p_rl
      )
      oa.op_type = OP_RSHIFT;
    else
      oa.op_type = OP_LSHIFT;
    op_shift(&oa, FALSE, eap->amount);
    break;
  }
  virtual_op = MAYBE;
  ex_may_print(eap);
}

/*
 * ":put".
 */
static void ex_put(exarg_T *eap)
{
  /* ":0put" works like ":1put!". */
  if (eap->line2 == 0) {
    eap->line2 = 1;
    eap->forceit = TRUE;
  }
  curwin->w_cursor.lnum = eap->line2;
  do_put(eap->regname, eap->forceit ? BACKWARD : FORWARD, 1L,
      PUT_LINE|PUT_CURSLINE);
}

/*
 * Handle ":copy" and ":move".
 */
static void ex_copymove(exarg_T *eap)
{
  long n;

  n = get_address(&eap->arg, FALSE, FALSE);
  if (eap->arg == NULL) {           /* error detected */
    eap->nextcmd = NULL;
    return;
  }
  get_flags(eap);

  /*
   * move or copy lines from 'eap->line1'-'eap->line2' to below line 'n'
   */
  if (n == MAXLNUM || n < 0 || n > curbuf->b_ml.ml_line_count) {
    EMSG(_(e_invaddr));
    return;
  }

  if (eap->cmdidx == CMD_move) {
    if (do_move(eap->line1, eap->line2, n) == FAIL)
      return;
  } else
    ex_copy(eap->line1, eap->line2, n);
  u_clearline();
  beginline(BL_SOL | BL_FIX);
  ex_may_print(eap);
}

/*
 * Print the current line if flags were given to the Ex command.
 */
static void ex_may_print(exarg_T *eap)
{
  if (eap->flags != 0) {
    print_line(curwin->w_cursor.lnum, (eap->flags & EXFLAG_NR),
        (eap->flags & EXFLAG_LIST));
    ex_no_reprint = TRUE;
  }
}

/*
 * ":smagic" and ":snomagic".
 */
static void ex_submagic(exarg_T *eap)
{
  int magic_save = p_magic;

  p_magic = (eap->cmdidx == CMD_smagic);
  do_sub(eap);
  p_magic = magic_save;
}

/*
 * ":join".
 */
static void ex_join(exarg_T *eap)
{
  curwin->w_cursor.lnum = eap->line1;
  if (eap->line1 == eap->line2) {
    if (eap->addr_count >= 2)       /* :2,2join does nothing */
      return;
    if (eap->line2 == curbuf->b_ml.ml_line_count) {
      beep_flush();
      return;
    }
    ++eap->line2;
  }
  (void)do_join(eap->line2 - eap->line1 + 1, !eap->forceit, TRUE, TRUE);
  beginline(BL_WHITE | BL_FIX);
  ex_may_print(eap);
}

/*
 * ":[addr]@r" or ":[addr]*r": execute register
 */
static void ex_at(exarg_T *eap)
{
  int c;
  int prev_len = typebuf.tb_len;

  curwin->w_cursor.lnum = eap->line2;

#ifdef USE_ON_FLY_SCROLL
  dont_scroll = TRUE;           /* disallow scrolling here */
#endif

  /* get the register name.  No name means to use the previous one */
  c = *eap->arg;
  if (c == NUL || (c == '*' && *eap->cmd == '*'))
    c = '@';
  /* Put the register in the typeahead buffer with the "silent" flag. */
  if (do_execreg(c, TRUE, vim_strchr(p_cpo, CPO_EXECBUF) != NULL, TRUE)
      == FAIL) {
    beep_flush();
  } else   {
    int save_efr = exec_from_reg;

    exec_from_reg = TRUE;

    /*
     * Execute from the typeahead buffer.
     * Continue until the stuff buffer is empty and all added characters
     * have been consumed.
     */
    while (!stuff_empty() || typebuf.tb_len > prev_len)
      (void)do_cmdline(NULL, getexline, NULL, DOCMD_NOWAIT|DOCMD_VERBOSE);

    exec_from_reg = save_efr;
  }
}

/*
 * ":!".
 */
static void ex_bang(exarg_T *eap)
{
  do_bang(eap->addr_count, eap, eap->forceit, TRUE, TRUE);
}

/*
 * ":undo".
 */
static void ex_undo(exarg_T *eap)
{
  if (eap->addr_count == 1)         /* :undo 123 */
    undo_time(eap->line2, FALSE, FALSE, TRUE);
  else
    u_undo(1);
}

static void ex_wundo(exarg_T *eap)
{
  char_u hash[UNDO_HASH_SIZE];

  u_compute_hash(hash);
  u_write_undo(eap->arg, eap->forceit, curbuf, hash);
}

static void ex_rundo(exarg_T *eap)
{
  char_u hash[UNDO_HASH_SIZE];

  u_compute_hash(hash);
  u_read_undo(eap->arg, hash, NULL);
}

/*
 * ":redo".
 */
static void ex_redo(exarg_T *eap)
{
  u_redo(1);
}

/*
 * ":earlier" and ":later".
 */
static void ex_later(exarg_T *eap)
{
  long count = 0;
  int sec = FALSE;
  int file = FALSE;
  char_u      *p = eap->arg;

  if (*p == NUL)
    count = 1;
  else if (isdigit(*p)) {
    count = getdigits(&p);
    switch (*p) {
    case 's': ++p; sec = TRUE; break;
    case 'm': ++p; sec = TRUE; count *= 60; break;
    case 'h': ++p; sec = TRUE; count *= 60 * 60; break;
    case 'd': ++p; sec = TRUE; count *= 24 * 60 * 60; break;
    case 'f': ++p; file = TRUE; break;
    }
  }

  if (*p != NUL)
    EMSG2(_(e_invarg2), eap->arg);
  else
    undo_time(eap->cmdidx == CMD_earlier ? -count : count,
        sec, file, FALSE);
}

/*
 * ":redir": start/stop redirection.
 */
static void ex_redir(exarg_T *eap)
{
  char        *mode;
  char_u      *fname;
  char_u      *arg = eap->arg;

  if (STRICMP(eap->arg, "END") == 0)
    close_redir();
  else {
    if (*arg == '>') {
      ++arg;
      if (*arg == '>') {
        ++arg;
        mode = "a";
      } else
        mode = "w";
      arg = skipwhite(arg);

      close_redir();

      /* Expand environment variables and "~/". */
      fname = expand_env_save(arg);
      if (fname == NULL)
        return;

      redir_fd = open_exfile(fname, eap->forceit, mode);
      vim_free(fname);
    } else if (*arg == '@')   {
      /* redirect to a register a-z (resp. A-Z for appending) */
      close_redir();
      ++arg;
      if (ASCII_ISALPHA(*arg)
          || *arg == '"') {
        redir_reg = *arg++;
        if (*arg == '>' && arg[1] == '>')          /* append */
          arg += 2;
        else {
          /* Can use both "@a" and "@a>". */
          if (*arg == '>')
            arg++;
          /* Make register empty when not using @A-@Z and the
           * command is valid. */
          if (*arg == NUL && !isupper(redir_reg))
            write_reg_contents(redir_reg, (char_u *)"", -1, FALSE);
        }
      }
      if (*arg != NUL) {
        redir_reg = 0;
        EMSG2(_(e_invarg2), eap->arg);
      }
    } else if (*arg == '=' && arg[1] == '>')   {
      int append;

      /* redirect to a variable */
      close_redir();
      arg += 2;

      if (*arg == '>') {
        ++arg;
        append = TRUE;
      } else
        append = FALSE;

      if (var_redir_start(skipwhite(arg), append) == OK)
        redir_vname = 1;
    }
    /* TODO: redirect to a buffer */
    else
      EMSG2(_(e_invarg2), eap->arg);
  }

  /* Make sure redirection is not off.  Can happen for cmdline completion
   * that indirectly invokes a command to catch its output. */
  if (redir_fd != NULL
      || redir_reg || redir_vname
      )
    redir_off = FALSE;
}

/*
 * ":redraw": force redraw
 */
static void ex_redraw(exarg_T *eap)
{
  int r = RedrawingDisabled;
  int p = p_lz;

  RedrawingDisabled = 0;
  p_lz = FALSE;
  update_topline();
  update_screen(eap->forceit ? CLEAR :
      VIsual_active ? INVERTED :
      0);
  if (need_maketitle)
    maketitle();
  RedrawingDisabled = r;
  p_lz = p;

  /* Reset msg_didout, so that a message that's there is overwritten. */
  msg_didout = FALSE;
  msg_col = 0;

  /* No need to wait after an intentional redraw. */
  need_wait_return = FALSE;

  out_flush();
}

/*
 * ":redrawstatus": force redraw of status line(s)
 */
static void ex_redrawstatus(exarg_T *eap)
{
  int r = RedrawingDisabled;
  int p = p_lz;

  RedrawingDisabled = 0;
  p_lz = FALSE;
  if (eap->forceit)
    status_redraw_all();
  else
    status_redraw_curbuf();
  update_screen(
      VIsual_active ? INVERTED :
      0);
  RedrawingDisabled = r;
  p_lz = p;
  out_flush();
}

static void close_redir(void)                 {
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

#if defined(FEAT_SESSION) && defined(USE_CRNL)
# define MKSESSION_NL
static int mksession_nl = FALSE;    /* use NL only in put_eol() */
#endif

/*
 * ":mkexrc", ":mkvimrc", ":mkview" and ":mksession".
 */
static void ex_mkrc(exarg_T *eap)
{
  FILE        *fd;
  int failed = FALSE;
  char_u      *fname;
  int view_session = FALSE;
  int using_vdir = FALSE;               /* using 'viewdir'? */
  char_u      *viewFile = NULL;
  unsigned    *flagp;

  if (eap->cmdidx == CMD_mksession || eap->cmdidx == CMD_mkview) {
    view_session = TRUE;
  }

  /* Use the short file name until ":lcd" is used.  We also don't use the
   * short file name when 'acd' is set, that is checked later. */
  did_lcd = FALSE;

  /* ":mkview" or ":mkview 9": generate file name with 'viewdir' */
  if (eap->cmdidx == CMD_mkview
      && (*eap->arg == NUL
          || (vim_isdigit(*eap->arg) && eap->arg[1] == NUL))) {
    eap->forceit = TRUE;
    fname = get_view_file(*eap->arg);
    if (fname == NULL)
      return;
    viewFile = fname;
    using_vdir = TRUE;
  } else if (*eap->arg != NUL)
    fname = eap->arg;
  else if (eap->cmdidx == CMD_mkvimrc)
    fname = (char_u *)VIMRC_FILE;
  else if (eap->cmdidx == CMD_mksession)
    fname = (char_u *)SESSION_FILE;
  else
    fname = (char_u *)EXRC_FILE;


#if defined(FEAT_SESSION) && defined(vim_mkdir)
  /* When using 'viewdir' may have to create the directory. */
  if (using_vdir && !mch_isdir(p_vdir))
    vim_mkdir_emsg(p_vdir, 0755);
#endif

  fd = open_exfile(fname, eap->forceit, WRITEBIN);
  if (fd != NULL) {
    if (eap->cmdidx == CMD_mkview)
      flagp = &vop_flags;
    else
      flagp = &ssop_flags;

#ifdef MKSESSION_NL
    /* "unix" in 'sessionoptions': use NL line separator */
    if (view_session && (*flagp & SSOP_UNIX))
      mksession_nl = TRUE;
#endif

    /* Write the version command for :mkvimrc */
    if (eap->cmdidx == CMD_mkvimrc)
      (void)put_line(fd, "version 6.0");

    if (eap->cmdidx == CMD_mksession) {
      if (put_line(fd, "let SessionLoad = 1") == FAIL)
        failed = TRUE;
    }

    if (eap->cmdidx != CMD_mkview) {
      /* Write setting 'compatible' first, because it has side effects.
       * For that same reason only do it when needed. */
      if (p_cp)
        (void)put_line(fd, "if !&cp | set cp | endif");
      else
        (void)put_line(fd, "if &cp | set nocp | endif");
    }

    if (!view_session
        || (eap->cmdidx == CMD_mksession
            && (*flagp & SSOP_OPTIONS)))
      failed |= (makemap(fd, NULL) == FAIL
                 || makeset(fd, OPT_GLOBAL, FALSE) == FAIL);

    if (!failed && view_session) {
      if (put_line(fd,
              "let s:so_save = &so | let s:siso_save = &siso | set so=0 siso=0")
          == FAIL)
        failed = TRUE;
      if (eap->cmdidx == CMD_mksession) {
        char_u *dirnow;          /* current directory */

        dirnow = alloc(MAXPATHL);
        if (dirnow == NULL)
          failed = TRUE;
        else {
          /*
           * Change to session file's dir.
           */
          if (mch_dirname(dirnow, MAXPATHL) == FAIL
              || mch_chdir((char *)dirnow) != 0)
            *dirnow = NUL;
          if (*dirnow != NUL && (ssop_flags & SSOP_SESDIR)) {
            if (vim_chdirfile(fname) == OK)
              shorten_fnames(TRUE);
          } else if (*dirnow != NUL
                     && (ssop_flags & SSOP_CURDIR) && globaldir != NULL) {
            if (mch_chdir((char *)globaldir) == 0)
              shorten_fnames(TRUE);
          }

          failed |= (makeopens(fd, dirnow) == FAIL);

          /* restore original dir */
          if (*dirnow != NUL && ((ssop_flags & SSOP_SESDIR)
                                 || ((ssop_flags & SSOP_CURDIR) && globaldir !=
                                     NULL))) {
            if (mch_chdir((char *)dirnow) != 0)
              EMSG(_(e_prev_dir));
            shorten_fnames(TRUE);
          }
          vim_free(dirnow);
        }
      } else   {
        failed |= (put_view(fd, curwin, !using_vdir, flagp,
                       -1) == FAIL);
      }
      if (put_line(fd, "let &so = s:so_save | let &siso = s:siso_save")
          == FAIL)
        failed = TRUE;
      if (put_line(fd, "doautoall SessionLoadPost") == FAIL)
        failed = TRUE;
      if (eap->cmdidx == CMD_mksession) {
        if (put_line(fd, "unlet SessionLoad") == FAIL)
          failed = TRUE;
      }
    }
    if (put_line(fd, "\" vim: set ft=vim :") == FAIL)
      failed = TRUE;

    failed |= fclose(fd);

    if (failed)
      EMSG(_(e_write));
    else if (eap->cmdidx == CMD_mksession) {
      /* successful session write - set this_session var */
      char_u      *tbuf;

      tbuf = alloc(MAXPATHL);
      if (tbuf != NULL) {
        if (vim_FullName(fname, tbuf, MAXPATHL, FALSE) == OK)
          set_vim_var_string(VV_THIS_SESSION, tbuf, -1);
        vim_free(tbuf);
      }
    }
#ifdef MKSESSION_NL
    mksession_nl = FALSE;
#endif
  }

  vim_free(viewFile);
}

#if ((defined(FEAT_SESSION) || defined(FEAT_EVAL)) && defined(vim_mkdir)) \
  || defined(PROTO)
int vim_mkdir_emsg(char_u *name, int prot)
{
  if (vim_mkdir(name, prot) != 0) {
    EMSG2(_("E739: Cannot create directory: %s"), name);
    return FAIL;
  }
  return OK;
}
#endif

/*
 * Open a file for writing for an Ex command, with some checks.
 * Return file descriptor, or NULL on failure.
 */
FILE *
open_exfile (
    char_u *fname,
    int forceit,
    char *mode          /* "w" for create new file or "a" for append */
)
{
  FILE        *fd;

#ifdef UNIX
  /* with Unix it is possible to open a directory */
  if (mch_isdir(fname)) {
    EMSG2(_(e_isadir2), fname);
    return NULL;
  }
#endif
  if (!forceit && *mode != 'a' && vim_fexists(fname)) {
    EMSG2(_("E189: \"%s\" exists (add ! to override)"), fname);
    return NULL;
  }

  if ((fd = mch_fopen((char *)fname, mode)) == NULL)
    EMSG2(_("E190: Cannot open \"%s\" for writing"), fname);

  return fd;
}

/*
 * ":mark" and ":k".
 */
static void ex_mark(exarg_T *eap)
{
  pos_T pos;

  if (*eap->arg == NUL)                 /* No argument? */
    EMSG(_(e_argreq));
  else if (eap->arg[1] != NUL)          /* more than one character? */
    EMSG(_(e_trailing));
  else {
    pos = curwin->w_cursor;             /* save curwin->w_cursor */
    curwin->w_cursor.lnum = eap->line2;
    beginline(BL_WHITE | BL_FIX);
    if (setmark(*eap->arg) == FAIL)     /* set mark */
      EMSG(_("E191: Argument must be a letter or forward/backward quote"));
    curwin->w_cursor = pos;             /* restore curwin->w_cursor */
  }
}

/*
 * Update w_topline, w_leftcol and the cursor position.
 */
void update_topline_cursor(void)          {
  check_cursor();               /* put cursor on valid line */
  update_topline();
  if (!curwin->w_p_wrap)
    validate_cursor();
  update_curswant();
}

/*
 * ":normal[!] {commands}": Execute normal mode commands.
 */
static void ex_normal(exarg_T *eap)
{
  int save_msg_scroll = msg_scroll;
  int save_restart_edit = restart_edit;
  int save_msg_didout = msg_didout;
  int save_State = State;
  tasave_T tabuf;
  int save_insertmode = p_im;
  int save_finish_op = finish_op;
  int save_opcount = opcount;
  char_u      *arg = NULL;
  int l;
  char_u      *p;

  if (ex_normal_lock > 0) {
    EMSG(_(e_secure));
    return;
  }
  if (ex_normal_busy >= p_mmd) {
    EMSG(_("E192: Recursive use of :normal too deep"));
    return;
  }
  ++ex_normal_busy;

  msg_scroll = FALSE;       /* no msg scrolling in Normal mode */
  restart_edit = 0;         /* don't go to Insert mode */
  p_im = FALSE;             /* don't use 'insertmode' */

  /*
   * vgetc() expects a CSI and K_SPECIAL to have been escaped.  Don't do
   * this for the K_SPECIAL leading byte, otherwise special keys will not
   * work.
   */
  if (has_mbyte) {
    int len = 0;

    /* Count the number of characters to be escaped. */
    for (p = eap->arg; *p != NUL; ++p) {
      for (l = (*mb_ptr2len)(p) - 1; l > 0; --l)
        if (*++p == K_SPECIAL             /* trailbyte K_SPECIAL or CSI */
            )
          len += 2;
    }
    if (len > 0) {
      arg = alloc((unsigned)(STRLEN(eap->arg) + len + 1));
      if (arg != NULL) {
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
  }

  /*
   * Save the current typeahead.  This is required to allow using ":normal"
   * from an event handler and makes sure we don't hang when the argument
   * ends with half a command.
   */
  save_typeahead(&tabuf);
  if (tabuf.typebuf_valid) {
    /*
     * Repeat the :normal command for each line in the range.  When no
     * range given, execute it just once, without positioning the cursor
     * first.
     */
    do {
      if (eap->addr_count != 0) {
        curwin->w_cursor.lnum = eap->line1++;
        curwin->w_cursor.col = 0;
      }

      exec_normal_cmd(
          arg != NULL ? arg :
          eap->arg, eap->forceit ? REMAP_NONE : REMAP_YES, FALSE);
    } while (eap->addr_count > 0 && eap->line1 <= eap->line2 && !got_int);
  }

  /* Might not return to the main loop when in an event handler. */
  update_topline_cursor();

  /* Restore the previous typeahead. */
  restore_typeahead(&tabuf);

  --ex_normal_busy;
  msg_scroll = save_msg_scroll;
  restart_edit = save_restart_edit;
  p_im = save_insertmode;
  finish_op = save_finish_op;
  opcount = save_opcount;
  msg_didout |= save_msg_didout;        /* don't reset msg_didout now */

  /* Restore the state (needed when called from a function executed for
   * 'indentexpr'). */
  State = save_State;
  vim_free(arg);
}

/*
 * ":startinsert", ":startreplace" and ":startgreplace"
 */
static void ex_startinsert(exarg_T *eap)
{
  if (eap->forceit) {
    coladvance((colnr_T)MAXCOL);
    curwin->w_curswant = MAXCOL;
    curwin->w_set_curswant = FALSE;
  }

  /* Ignore the command when already in Insert mode.  Inserting an
   * expression register that invokes a function can do this. */
  if (State & INSERT)
    return;

  if (eap->cmdidx == CMD_startinsert)
    restart_edit = 'a';
  else if (eap->cmdidx == CMD_startreplace)
    restart_edit = 'R';
  else
    restart_edit = 'V';

  if (!eap->forceit) {
    if (eap->cmdidx == CMD_startinsert)
      restart_edit = 'i';
    curwin->w_curswant = 0;         /* avoid MAXCOL */
  }
}

/*
 * ":stopinsert"
 */
static void ex_stopinsert(exarg_T *eap)
{
  restart_edit = 0;
  stop_insert_mode = TRUE;
}

/*
 * Execute normal mode command "cmd".
 * "remap" can be REMAP_NONE or REMAP_YES.
 */
void exec_normal_cmd(char_u *cmd, int remap, int silent)
{
  oparg_T oa;

  /*
   * Stuff the argument into the typeahead buffer.
   * Execute normal_cmd() until there is no typeahead left.
   */
  clear_oparg(&oa);
  finish_op = FALSE;
  ins_typebuf(cmd, remap, 0, TRUE, silent);
  while ((!stuff_empty() || (!typebuf_typed() && typebuf.tb_len > 0))
         && !got_int) {
    update_topline_cursor();
    normal_cmd(&oa, TRUE);      /* execute a Normal mode cmd */
  }
}

static void ex_checkpath(exarg_T *eap)
{
  find_pattern_in_path(NULL, 0, 0, FALSE, FALSE, CHECK_PATH, 1L,
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
  int whole = TRUE;
  long n;
  char_u      *p;
  int action;

  switch (cmdnames[eap->cmdidx].cmd_name[2]) {
  case 'e':             /* ":psearch", ":isearch" and ":dsearch" */
    if (cmdnames[eap->cmdidx].cmd_name[0] == 'p')
      action = ACTION_GOTO;
    else
      action = ACTION_SHOW;
    break;
  case 'i':             /* ":ilist" and ":dlist" */
    action = ACTION_SHOW_ALL;
    break;
  case 'u':             /* ":ijump" and ":djump" */
    action = ACTION_GOTO;
    break;
  default:              /* ":isplit" and ":dsplit" */
    action = ACTION_SPLIT;
    break;
  }

  n = 1;
  if (vim_isdigit(*eap->arg)) { /* get count */
    n = getdigits(&eap->arg);
    eap->arg = skipwhite(eap->arg);
  }
  if (*eap->arg == '/') {   /* Match regexp, not just whole words */
    whole = FALSE;
    ++eap->arg;
    p = skip_regexp(eap->arg, '/', p_magic, NULL);
    if (*p) {
      *p++ = NUL;
      p = skipwhite(p);

      /* Check for trailing illegal characters */
      if (!ends_excmd(*p))
        eap->errmsg = e_trailing;
      else
        eap->nextcmd = check_nextcmd(p);
    }
  }
  if (!eap->skip)
    find_pattern_in_path(eap->arg, 0, (int)STRLEN(eap->arg),
        whole, !eap->forceit,
        *eap->cmd == 'd' ?  FIND_DEFINE : FIND_ANY,
        n, action, eap->line1, eap->line2);
}


/*
 * ":ptag", ":ptselect", ":ptjump", ":ptnext", etc.
 */
static void ex_ptag(exarg_T *eap)
{
  g_do_tagpreview = p_pvh;    /* will be reset to 0 in ex_tag_cmd() */
  ex_tag_cmd(eap, cmdnames[eap->cmdidx].cmd_name + 1);
}

/*
 * ":pedit"
 */
static void ex_pedit(exarg_T *eap)
{
  win_T       *curwin_save = curwin;

  g_do_tagpreview = p_pvh;
  prepare_tagpreview(TRUE);
  keep_help_flag = curwin_save->w_buffer->b_help;
  do_exedit(eap, NULL);
  keep_help_flag = FALSE;
  if (curwin != curwin_save && win_valid(curwin_save)) {
    /* Return cursor to where we were */
    validate_cursor();
    redraw_later(VALID);
    win_enter(curwin_save, TRUE);
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
  case 'j': cmd = DT_JUMP;              /* ":tjump" */
    break;
  case 's': cmd = DT_SELECT;            /* ":tselect" */
    break;
  case 'p': cmd = DT_PREV;              /* ":tprevious" */
    break;
  case 'N': cmd = DT_PREV;              /* ":tNext" */
    break;
  case 'n': cmd = DT_NEXT;              /* ":tnext" */
    break;
  case 'o': cmd = DT_POP;               /* ":pop" */
    break;
  case 'f':                             /* ":tfirst" */
  case 'r': cmd = DT_FIRST;             /* ":trewind" */
    break;
  case 'l': cmd = DT_LAST;              /* ":tlast" */
    break;
  default:                              /* ":tag" */
    if (p_cst && *eap->arg != NUL) {
      do_cstag(eap);
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

/*
 * Check "str" for starting with a special cmdline variable.
 * If found return one of the SPEC_ values and set "*usedlen" to the length of
 * the variable.  Otherwise return -1 and "*usedlen" is unchanged.
 */
int find_cmdline_var(char_u *src, int *usedlen)
{
  int len;
  int i;
  static char *(spec_str[]) = {
    "%",
#define SPEC_PERC   0
    "#",
#define SPEC_HASH   1
    "<cword>",                          /* cursor word */
#define SPEC_CWORD  2
    "<cWORD>",                          /* cursor WORD */
#define SPEC_CCWORD 3
    "<cfile>",                          /* cursor path name */
#define SPEC_CFILE  4
    "<sfile>",                          /* ":so" file name */
#define SPEC_SFILE  5
    "<slnum>",                          /* ":so" file line number */
#define SPEC_SLNUM  6
    "<afile>",                          /* autocommand file name */
# define SPEC_AFILE 7
    "<abuf>",                           /* autocommand buffer number */
# define SPEC_ABUF  8
    "<amatch>",                         /* autocommand match name */
# define SPEC_AMATCH 9
  };

  for (i = 0; i < (int)(sizeof(spec_str) / sizeof(char *)); ++i) {
    len = (int)STRLEN(spec_str[i]);
    if (STRNCMP(src, spec_str[i], len) == 0) {
      *usedlen = len;
      return i;
    }
  }
  return -1;
}

/*
 * Evaluate cmdline variables.
 *
 * change '%'	    to curbuf->b_ffname
 *	  '#'	    to curwin->w_altfile
 *	  '<cword>' to word under the cursor
 *	  '<cWORD>' to WORD under the cursor
 *	  '<cfile>' to path name under the cursor
 *	  '<sfile>' to sourced file name
 *	  '<slnum>' to sourced file line number
 *	  '<afile>' to file name for autocommand
 *	  '<abuf>'  to buffer number for autocommand
 *	  '<amatch>' to matching name for autocommand
 *
 * When an error is detected, "errormsg" is set to a non-NULL pointer (may be
 * "" for error without a message) and NULL is returned.
 * Returns an allocated string if a valid match was found.
 * Returns NULL if no match was found.	"usedlen" then still contains the
 * number of characters to skip.
 */
char_u *
eval_vars (
    char_u *src,               /* pointer into commandline */
    char_u *srcstart,          /* beginning of valid memory for src */
    int *usedlen,           /* characters after src that are used */
    linenr_T *lnump,             /* line number for :e command, or NULL */
    char_u **errormsg,         /* pointer to error message */
    int *escaped           /* return value has escaped white space (can
                                 * be NULL) */
)
{
  int i;
  char_u      *s;
  char_u      *result;
  char_u      *resultbuf = NULL;
  int resultlen;
  buf_T       *buf;
  int valid = VALID_HEAD + VALID_PATH;              /* assume valid result */
  int spec_idx;
  int skip_mod = FALSE;
  char_u strbuf[30];

  *errormsg = NULL;
  if (escaped != NULL)
    *escaped = FALSE;

  /*
   * Check if there is something to do.
   */
  spec_idx = find_cmdline_var(src, usedlen);
  if (spec_idx < 0) {   /* no match */
    *usedlen = 1;
    return NULL;
  }

  /*
   * Skip when preceded with a backslash "\%" and "\#".
   * Note: In "\\%" the % is also not recognized!
   */
  if (src > srcstart && src[-1] == '\\') {
    *usedlen = 0;
    STRMOVE(src - 1, src);      /* remove backslash */
    return NULL;
  }

  /*
   * word or WORD under cursor
   */
  if (spec_idx == SPEC_CWORD || spec_idx == SPEC_CCWORD) {
    resultlen = find_ident_under_cursor(&result, spec_idx == SPEC_CWORD ?
        (FIND_IDENT|FIND_STRING) : FIND_STRING);
    if (resultlen == 0) {
      *errormsg = (char_u *)"";
      return NULL;
    }
  }
  /*
   * '#': Alternate file name
   * '%': Current file name
   *	    File name under the cursor
   *	    File name for autocommand
   *	and following modifiers
   */
  else {
    switch (spec_idx) {
    case SPEC_PERC:             /* '%': current file */
      if (curbuf->b_fname == NULL) {
        result = (char_u *)"";
        valid = 0;                  /* Must have ":p:h" to be valid */
      } else
        result = curbuf->b_fname;
      break;

    case SPEC_HASH:             /* '#' or "#99": alternate file */
      if (src[1] == '#') {          /* "##": the argument list */
        result = arg_all();
        resultbuf = result;
        *usedlen = 2;
        if (escaped != NULL)
          *escaped = TRUE;
        skip_mod = TRUE;
        break;
      }
      s = src + 1;
      if (*s == '<')                    /* "#<99" uses v:oldfiles */
        ++s;
      i = (int)getdigits(&s);
      *usedlen = (int)(s - src);           /* length of what we expand */

      if (src[1] == '<') {
        if (*usedlen < 2) {
          /* Should we give an error message for #<text? */
          *usedlen = 1;
          return NULL;
        }
        result = list_find_str(get_vim_var_list(VV_OLDFILES),
            (long)i);
        if (result == NULL) {
          *errormsg = (char_u *)"";
          return NULL;
        }
      } else   {
        buf = buflist_findnr(i);
        if (buf == NULL) {
          *errormsg = (char_u *)_(
              "E194: No alternate file name to substitute for '#'");
          return NULL;
        }
        if (lnump != NULL)
          *lnump = ECMD_LAST;
        if (buf->b_fname == NULL) {
          result = (char_u *)"";
          valid = 0;                        /* Must have ":p:h" to be valid */
        } else
          result = buf->b_fname;
      }
      break;

    case SPEC_CFILE:            /* file name under cursor */
      result = file_name_at_cursor(FNAME_MESS|FNAME_HYP, 1L, NULL);
      if (result == NULL) {
        *errormsg = (char_u *)"";
        return NULL;
      }
      resultbuf = result;                   /* remember allocated string */
      break;

    case SPEC_AFILE:            /* file name for autocommand */
      result = autocmd_fname;
      if (result != NULL && !autocmd_fname_full) {
        /* Still need to turn the fname into a full path.  It is
         * postponed to avoid a delay when <afile> is not used. */
        autocmd_fname_full = TRUE;
        result = FullName_save(autocmd_fname, FALSE);
        vim_free(autocmd_fname);
        autocmd_fname = result;
      }
      if (result == NULL) {
        *errormsg = (char_u *)_(
            "E495: no autocommand file name to substitute for \"<afile>\"");
        return NULL;
      }
      result = shorten_fname1(result);
      break;

    case SPEC_ABUF:             /* buffer number for autocommand */
      if (autocmd_bufnr <= 0) {
        *errormsg = (char_u *)_(
            "E496: no autocommand buffer number to substitute for \"<abuf>\"");
        return NULL;
      }
      sprintf((char *)strbuf, "%d", autocmd_bufnr);
      result = strbuf;
      break;

    case SPEC_AMATCH:           /* match name for autocommand */
      result = autocmd_match;
      if (result == NULL) {
        *errormsg = (char_u *)_(
            "E497: no autocommand match name to substitute for \"<amatch>\"");
        return NULL;
      }
      break;

    case SPEC_SFILE:            /* file name for ":so" command */
      result = sourcing_name;
      if (result == NULL) {
        *errormsg = (char_u *)_(
            "E498: no :source file name to substitute for \"<sfile>\"");
        return NULL;
      }
      break;
    case SPEC_SLNUM:            /* line in file for ":so" command */
      if (sourcing_name == NULL || sourcing_lnum == 0) {
        *errormsg = (char_u *)_("E842: no line number to use for \"<slnum>\"");
        return NULL;
      }
      sprintf((char *)strbuf, "%ld", (long)sourcing_lnum);
      result = strbuf;
      break;
    }

    resultlen = (int)STRLEN(result);            /* length of new string */
    if (src[*usedlen] == '<') {         /* remove the file name extension */
      ++*usedlen;
      if ((s = vim_strrchr(result, '.')) != NULL && s >= gettail(result))
        resultlen = (int)(s - result);
    } else if (!skip_mod)   {
      valid |= modify_fname(src, usedlen, &result, &resultbuf,
          &resultlen);
      if (result == NULL) {
        *errormsg = (char_u *)"";
        return NULL;
      }
    }
  }

  if (resultlen == 0 || valid != VALID_HEAD + VALID_PATH) {
    if (valid != VALID_HEAD + VALID_PATH)
      /* xgettext:no-c-format */
      *errormsg = (char_u *)_(
          "E499: Empty file name for '%' or '#', only works with \":p:h\"");
    else
      *errormsg = (char_u *)_("E500: Evaluates to an empty string");
    result = NULL;
  } else
    result = vim_strnsave(result, resultlen);
  vim_free(resultbuf);
  return result;
}

/*
 * Concatenate all files in the argument list, separated by spaces, and return
 * it in one allocated string.
 * Spaces and backslashes in the file names are escaped with a backslash.
 * Returns NULL when out of memory.
 */
static char_u *arg_all(void)                     {
  int len;
  int idx;
  char_u      *retval = NULL;
  char_u      *p;

  /*
   * Do this loop two times:
   * first time: compute the total length
   * second time: concatenate the names
   */
  for (;; ) {
    len = 0;
    for (idx = 0; idx < ARGCOUNT; ++idx) {
      p = alist_name(&ARGLIST[idx]);
      if (p != NULL) {
        if (len > 0) {
          /* insert a space in between names */
          if (retval != NULL)
            retval[len] = ' ';
          ++len;
        }
        for (; *p != NUL; ++p) {
          if (*p == ' ' || *p == '\\') {
            /* insert a backslash */
            if (retval != NULL)
              retval[len] = '\\';
            ++len;
          }
          if (retval != NULL)
            retval[len] = *p;
          ++len;
        }
      }
    }

    /* second time: break here */
    if (retval != NULL) {
      retval[len] = NUL;
      break;
    }

    /* allocate memory */
    retval = alloc((unsigned)len + 1);
    if (retval == NULL)
      break;
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
  char_u      *errormsg;
  int len;
  char_u      *result;
  char_u      *newres;
  char_u      *repl;
  int srclen;
  char_u      *p;

  result = vim_strsave(arg);
  if (result == NULL)
    return NULL;

  for (p = result; *p; ) {
    if (STRNCMP(p, "<sfile>", 7) != 0)
      ++p;
    else {
      /* replace "<sfile>" with the sourced file name, and do ":" stuff */
      repl = eval_vars(p, result, &srclen, NULL, &errormsg, NULL);
      if (errormsg != NULL) {
        if (*errormsg)
          emsg(errormsg);
        vim_free(result);
        return NULL;
      }
      if (repl == NULL) {               /* no match (cannot happen) */
        p += srclen;
        continue;
      }
      len = (int)STRLEN(result) - srclen + (int)STRLEN(repl) + 1;
      newres = alloc(len);
      if (newres == NULL) {
        vim_free(repl);
        vim_free(result);
        return NULL;
      }
      mch_memmove(newres, result, (size_t)(p - result));
      STRCPY(newres + (p - result), repl);
      len = (int)STRLEN(newres);
      STRCAT(newres, p + srclen);
      vim_free(repl);
      vim_free(result);
      result = newres;
      p = newres + len;                 /* continue after the match */
    }
  }

  return result;
}

static int ses_winsizes(FILE *fd, int restore_size, win_T *tab_firstwin);
static int ses_win_rec(FILE *fd, frame_T *fr);
static frame_T *ses_skipframe(frame_T *fr);
static int ses_do_frame(frame_T *fr);
static int ses_do_win(win_T *wp);
static int ses_arglist(FILE *fd, char *cmd, garray_T *gap, int fullname,
                       unsigned *flagp);
static int ses_put_fname(FILE *fd, char_u *name, unsigned *flagp);
static int ses_fname(FILE *fd, buf_T *buf, unsigned *flagp);

/*
 * Write openfile commands for the current buffers to an .exrc file.
 * Return FAIL on error, OK otherwise.
 */
static int 
makeopens (
    FILE *fd,
    char_u *dirnow            /* Current directory name */
)
{
  buf_T       *buf;
  int only_save_windows = TRUE;
  int nr;
  int cnr = 1;
  int restore_size = TRUE;
  win_T       *wp;
  char_u      *sname;
  win_T       *edited_win = NULL;
  int tabnr;
  win_T       *tab_firstwin;
  frame_T     *tab_topframe;
  int cur_arg_idx = 0;
  int next_arg_idx = 0;

  if (ssop_flags & SSOP_BUFFERS)
    only_save_windows = FALSE;                  /* Save ALL buffers */

  /*
   * Begin by setting the this_session variable, and then other
   * sessionable variables.
   */
  if (put_line(fd, "let v:this_session=expand(\"<sfile>:p\")") == FAIL)
    return FAIL;
  if (ssop_flags & SSOP_GLOBALS)
    if (store_session_globals(fd) == FAIL)
      return FAIL;

  /*
   * Close all windows but one.
   */
  if (put_line(fd, "silent only") == FAIL)
    return FAIL;

  /*
   * Now a :cd command to the session directory or the current directory
   */
  if (ssop_flags & SSOP_SESDIR) {
    if (put_line(fd, "exe \"cd \" . escape(expand(\"<sfile>:p:h\"), ' ')")
        == FAIL)
      return FAIL;
  } else if (ssop_flags & SSOP_CURDIR)   {
    sname = home_replace_save(NULL, globaldir != NULL ? globaldir : dirnow);
    if (sname == NULL
        || fputs("cd ", fd) < 0
        || ses_put_fname(fd, sname, &ssop_flags) == FAIL
        || put_eol(fd) == FAIL) {
      vim_free(sname);
      return FAIL;
    }
    vim_free(sname);
  }

  /*
   * If there is an empty, unnamed buffer we will wipe it out later.
   * Remember the buffer number.
   */
  if (put_line(fd,
          "if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''")
      ==
      FAIL)
    return FAIL;
  if (put_line(fd, "  let s:wipebuf = bufnr('%')") == FAIL)
    return FAIL;
  if (put_line(fd, "endif") == FAIL)
    return FAIL;

  /*
   * Now save the current files, current buffer first.
   */
  if (put_line(fd, "set shortmess=aoO") == FAIL)
    return FAIL;

  /* Now put the other buffers into the buffer list */
  for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
    if (!(only_save_windows && buf->b_nwindows == 0)
        && !(buf->b_help && !(ssop_flags & SSOP_HELP))
        && buf->b_fname != NULL
        && buf->b_p_bl) {
      if (fprintf(fd, "badd +%ld ", buf->b_wininfo == NULL ? 1L
              : buf->b_wininfo->wi_fpos.lnum) < 0
          || ses_fname(fd, buf, &ssop_flags) == FAIL)
        return FAIL;
    }
  }

  /* the global argument list */
  if (ses_arglist(fd, "args", &global_alist.al_ga,
          !(ssop_flags & SSOP_CURDIR), &ssop_flags) == FAIL)
    return FAIL;

  if (ssop_flags & SSOP_RESIZE) {
    /* Note: after the restore we still check it worked!*/
    if (fprintf(fd, "set lines=%ld columns=%ld", Rows, Columns) < 0
        || put_eol(fd) == FAIL)
      return FAIL;
  }


  /*
   * May repeat putting Windows for each tab, when "tabpages" is in
   * 'sessionoptions'.
   * Don't use goto_tabpage(), it may change directory and trigger
   * autocommands.
   */
  tab_firstwin = firstwin;      /* first window in tab page "tabnr" */
  tab_topframe = topframe;
  for (tabnr = 1;; ++tabnr) {
    int need_tabnew = FALSE;

    if ((ssop_flags & SSOP_TABPAGES)) {
      tabpage_T *tp = find_tabpage(tabnr);

      if (tp == NULL)
        break;                  /* done all tab pages */
      if (tp == curtab) {
        tab_firstwin = firstwin;
        tab_topframe = topframe;
      } else   {
        tab_firstwin = tp->tp_firstwin;
        tab_topframe = tp->tp_topframe;
      }
      if (tabnr > 1)
        need_tabnew = TRUE;
    }

    /*
     * Before creating the window layout, try loading one file.  If this
     * is aborted we don't end up with a number of useless windows.
     * This may have side effects! (e.g., compressed or network file).
     */
    for (wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (ses_do_win(wp)
          && wp->w_buffer->b_ffname != NULL
          && !wp->w_buffer->b_help
          && !bt_nofile(wp->w_buffer)
          ) {
        if (fputs(need_tabnew ? "tabedit " : "edit ", fd) < 0
            || ses_fname(fd, wp->w_buffer, &ssop_flags) == FAIL)
          return FAIL;
        need_tabnew = FALSE;
        if (!wp->w_arg_idx_invalid)
          edited_win = wp;
        break;
      }
    }

    /* If no file got edited create an empty tab page. */
    if (need_tabnew && put_line(fd, "tabnew") == FAIL)
      return FAIL;

    /*
     * Save current window layout.
     */
    if (put_line(fd, "set splitbelow splitright") == FAIL)
      return FAIL;
    if (ses_win_rec(fd, tab_topframe) == FAIL)
      return FAIL;
    if (!p_sb && put_line(fd, "set nosplitbelow") == FAIL)
      return FAIL;
    if (!p_spr && put_line(fd, "set nosplitright") == FAIL)
      return FAIL;

    /*
     * Check if window sizes can be restored (no windows omitted).
     * Remember the window number of the current window after restoring.
     */
    nr = 0;
    for (wp = tab_firstwin; wp != NULL; wp = W_NEXT(wp)) {
      if (ses_do_win(wp))
        ++nr;
      else
        restore_size = FALSE;
      if (curwin == wp)
        cnr = nr;
    }

    /* Go to the first window. */
    if (put_line(fd, "wincmd t") == FAIL)
      return FAIL;

    /*
     * If more than one window, see if sizes can be restored.
     * First set 'winheight' and 'winwidth' to 1 to avoid the windows being
     * resized when moving between windows.
     * Do this before restoring the view, so that the topline and the
     * cursor can be set.  This is done again below.
     */
    if (put_line(fd, "set winheight=1 winwidth=1") == FAIL)
      return FAIL;
    if (nr > 1 && ses_winsizes(fd, restore_size, tab_firstwin) == FAIL)
      return FAIL;

    /*
     * Restore the view of the window (options, file, cursor, etc.).
     */
    for (wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (!ses_do_win(wp))
        continue;
      if (put_view(fd, wp, wp != edited_win, &ssop_flags,
              cur_arg_idx) == FAIL)
        return FAIL;
      if (nr > 1 && put_line(fd, "wincmd w") == FAIL)
        return FAIL;
      next_arg_idx = wp->w_arg_idx;
    }

    /* The argument index in the first tab page is zero, need to set it in
     * each window.  For further tab pages it's the window where we do
     * "tabedit". */
    cur_arg_idx = next_arg_idx;

    /*
     * Restore cursor to the current window if it's not the first one.
     */
    if (cnr > 1 && (fprintf(fd, "%dwincmd w", cnr) < 0
                    || put_eol(fd) == FAIL))
      return FAIL;

    /*
     * Restore window sizes again after jumping around in windows, because
     * the current window has a minimum size while others may not.
     */
    if (nr > 1 && ses_winsizes(fd, restore_size, tab_firstwin) == FAIL)
      return FAIL;

    /* Don't continue in another tab page when doing only the current one
     * or when at the last tab page. */
    if (!(ssop_flags & SSOP_TABPAGES))
      break;
  }

  if (ssop_flags & SSOP_TABPAGES) {
    if (fprintf(fd, "tabnext %d", tabpage_index(curtab)) < 0
        || put_eol(fd) == FAIL)
      return FAIL;
  }

  /*
   * Wipe out an empty unnamed buffer we started in.
   */
  if (put_line(fd, "if exists('s:wipebuf')") == FAIL)
    return FAIL;
  if (put_line(fd, "  silent exe 'bwipe ' . s:wipebuf") == FAIL)
    return FAIL;
  if (put_line(fd, "endif") == FAIL)
    return FAIL;
  if (put_line(fd, "unlet! s:wipebuf") == FAIL)
    return FAIL;

  /* Re-apply 'winheight', 'winwidth' and 'shortmess'. */
  if (fprintf(fd, "set winheight=%ld winwidth=%ld shortmess=%s",
          p_wh, p_wiw, p_shm) < 0 || put_eol(fd) == FAIL)
    return FAIL;

  /*
   * Lastly, execute the x.vim file if it exists.
   */
  if (put_line(fd, "let s:sx = expand(\"<sfile>:p:r\").\"x.vim\"") == FAIL
      || put_line(fd, "if file_readable(s:sx)") == FAIL
      || put_line(fd, "  exe \"source \" . fnameescape(s:sx)") == FAIL
      || put_line(fd, "endif") == FAIL)
    return FAIL;

  return OK;
}

static int ses_winsizes(FILE *fd, int restore_size, win_T *tab_firstwin)
{
  int n = 0;
  win_T       *wp;

  if (restore_size && (ssop_flags & SSOP_WINSIZE)) {
    for (wp = tab_firstwin; wp != NULL; wp = wp->w_next) {
      if (!ses_do_win(wp))
        continue;
      ++n;

      /* restore height when not full height */
      if (wp->w_height + wp->w_status_height < topframe->fr_height
          && (fprintf(fd,
                  "exe '%dresize ' . ((&lines * %ld + %ld) / %ld)",
                  n, (long)wp->w_height, Rows / 2, Rows) < 0
              || put_eol(fd) == FAIL))
        return FAIL;

      /* restore width when not full width */
      if (wp->w_width < Columns && (fprintf(fd,
                                        "exe 'vert %dresize ' . ((&columns * %ld + %ld) / %ld)",
                                        n, (long)wp->w_width, Columns / 2,
                                        Columns) < 0
                                    || put_eol(fd) == FAIL))
        return FAIL;
    }
  } else   {
    /* Just equalise window sizes */
    if (put_line(fd, "wincmd =") == FAIL)
      return FAIL;
  }
  return OK;
}

/*
 * Write commands to "fd" to recursively create windows for frame "fr",
 * horizontally and vertically split.
 * After the commands the last window in the frame is the current window.
 * Returns FAIL when writing the commands to "fd" fails.
 */
static int ses_win_rec(FILE *fd, frame_T *fr)
{
  frame_T     *frc;
  int count = 0;

  if (fr->fr_layout != FR_LEAF) {
    /* Find first frame that's not skipped and then create a window for
     * each following one (first frame is already there). */
    frc = ses_skipframe(fr->fr_child);
    if (frc != NULL)
      while ((frc = ses_skipframe(frc->fr_next)) != NULL) {
        /* Make window as big as possible so that we have lots of room
         * to split. */
        if (put_line(fd, "wincmd _ | wincmd |") == FAIL
            || put_line(fd, fr->fr_layout == FR_COL
                ? "split" : "vsplit") == FAIL)
          return FAIL;
        ++count;
      }

    /* Go back to the first window. */
    if (count > 0 && (fprintf(fd, fr->fr_layout == FR_COL
                          ? "%dwincmd k" : "%dwincmd h", count) < 0
                      || put_eol(fd) == FAIL))
      return FAIL;

    /* Recursively create frames/windows in each window of this column or
     * row. */
    frc = ses_skipframe(fr->fr_child);
    while (frc != NULL) {
      ses_win_rec(fd, frc);
      frc = ses_skipframe(frc->fr_next);
      /* Go to next window. */
      if (frc != NULL && put_line(fd, "wincmd w") == FAIL)
        return FAIL;
    }
  }
  return OK;
}

/*
 * Skip frames that don't contain windows we want to save in the Session.
 * Returns NULL when there none.
 */
static frame_T *ses_skipframe(frame_T *fr)
{
  frame_T     *frc;

  for (frc = fr; frc != NULL; frc = frc->fr_next)
    if (ses_do_frame(frc))
      break;
  return frc;
}

/*
 * Return TRUE if frame "fr" has a window somewhere that we want to save in
 * the Session.
 */
static int ses_do_frame(frame_T *fr)
{
  frame_T     *frc;

  if (fr->fr_layout == FR_LEAF)
    return ses_do_win(fr->fr_win);
  for (frc = fr->fr_child; frc != NULL; frc = frc->fr_next)
    if (ses_do_frame(frc))
      return TRUE;
  return FALSE;
}

/*
 * Return non-zero if window "wp" is to be stored in the Session.
 */
static int ses_do_win(win_T *wp)
{
  if (wp->w_buffer->b_fname == NULL
      /* When 'buftype' is "nofile" can't restore the window contents. */
      || bt_nofile(wp->w_buffer)
      )
    return ssop_flags & SSOP_BLANK;
  if (wp->w_buffer->b_help)
    return ssop_flags & SSOP_HELP;
  return TRUE;
}

/*
 * Write commands to "fd" to restore the view of a window.
 * Caller must make sure 'scrolloff' is zero.
 */
static int 
put_view (
    FILE *fd,
    win_T *wp,
    int add_edit,                   /* add ":edit" command to view */
    unsigned *flagp,             /* vop_flags or ssop_flags */
    int current_arg_idx             /* current argument index of the window, use
                                  * -1 if unknown */
)
{
  win_T       *save_curwin;
  int f;
  int do_cursor;
  int did_next = FALSE;

  /* Always restore cursor position for ":mksession".  For ":mkview" only
   * when 'viewoptions' contains "cursor". */
  do_cursor = (flagp == &ssop_flags || *flagp & SSOP_CURSOR);

  /*
   * Local argument list.
   */
  if (wp->w_alist == &global_alist) {
    if (put_line(fd, "argglobal") == FAIL)
      return FAIL;
  } else   {
    if (ses_arglist(fd, "arglocal", &wp->w_alist->al_ga,
            flagp == &vop_flags
            || !(*flagp & SSOP_CURDIR)
            || wp->w_localdir != NULL, flagp) == FAIL)
      return FAIL;
  }

  /* Only when part of a session: restore the argument index.  Some
   * arguments may have been deleted, check if the index is valid. */
  if (wp->w_arg_idx != current_arg_idx && wp->w_arg_idx < WARGCOUNT(wp)
      && flagp == &ssop_flags) {
    if (fprintf(fd, "%ldargu", (long)wp->w_arg_idx + 1) < 0
        || put_eol(fd) == FAIL)
      return FAIL;
    did_next = TRUE;
  }

  /* Edit the file.  Skip this when ":next" already did it. */
  if (add_edit && (!did_next || wp->w_arg_idx_invalid)) {
    /*
     * Load the file.
     */
    if (wp->w_buffer->b_ffname != NULL
        && !bt_nofile(wp->w_buffer)
        ) {
      /*
       * Editing a file in this buffer: use ":edit file".
       * This may have side effects! (e.g., compressed or network file).
       */
      if (fputs("edit ", fd) < 0
          || ses_fname(fd, wp->w_buffer, flagp) == FAIL)
        return FAIL;
    } else   {
      /* No file in this buffer, just make it empty. */
      if (put_line(fd, "enew") == FAIL)
        return FAIL;
      if (wp->w_buffer->b_ffname != NULL) {
        /* The buffer does have a name, but it's not a file name. */
        if (fputs("file ", fd) < 0
            || ses_fname(fd, wp->w_buffer, flagp) == FAIL)
          return FAIL;
      }
      do_cursor = FALSE;
    }
  }

  /*
   * Local mappings and abbreviations.
   */
  if ((*flagp & (SSOP_OPTIONS | SSOP_LOCALOPTIONS))
      && makemap(fd, wp->w_buffer) == FAIL)
    return FAIL;

  /*
   * Local options.  Need to go to the window temporarily.
   * Store only local values when using ":mkview" and when ":mksession" is
   * used and 'sessionoptions' doesn't include "options".
   * Some folding options are always stored when "folds" is included,
   * otherwise the folds would not be restored correctly.
   */
  save_curwin = curwin;
  curwin = wp;
  curbuf = curwin->w_buffer;
  if (*flagp & (SSOP_OPTIONS | SSOP_LOCALOPTIONS))
    f = makeset(fd, OPT_LOCAL,
        flagp == &vop_flags || !(*flagp & SSOP_OPTIONS));
  else if (*flagp & SSOP_FOLDS)
    f = makefoldset(fd);
  else
    f = OK;
  curwin = save_curwin;
  curbuf = curwin->w_buffer;
  if (f == FAIL)
    return FAIL;

  /*
   * Save Folds when 'buftype' is empty and for help files.
   */
  if ((*flagp & SSOP_FOLDS)
      && wp->w_buffer->b_ffname != NULL
      && (*wp->w_buffer->b_p_bt == NUL || wp->w_buffer->b_help)
      ) {
    if (put_folds(fd, wp) == FAIL)
      return FAIL;
  }

  /*
   * Set the cursor after creating folds, since that moves the cursor.
   */
  if (do_cursor) {

    /* Restore the cursor line in the file and relatively in the
     * window.  Don't use "G", it changes the jumplist. */
    if (fprintf(fd, "let s:l = %ld - ((%ld * winheight(0) + %ld) / %ld)",
            (long)wp->w_cursor.lnum,
            (long)(wp->w_cursor.lnum - wp->w_topline),
            (long)wp->w_height / 2, (long)wp->w_height) < 0
        || put_eol(fd) == FAIL
        || put_line(fd, "if s:l < 1 | let s:l = 1 | endif") == FAIL
        || put_line(fd, "exe s:l") == FAIL
        || put_line(fd, "normal! zt") == FAIL
        || fprintf(fd, "%ld", (long)wp->w_cursor.lnum) < 0
        || put_eol(fd) == FAIL)
      return FAIL;
    /* Restore the cursor column and left offset when not wrapping. */
    if (wp->w_cursor.col == 0) {
      if (put_line(fd, "normal! 0") == FAIL)
        return FAIL;
    } else   {
      if (!wp->w_p_wrap && wp->w_leftcol > 0 && wp->w_width > 0) {
        if (fprintf(fd,
                "let s:c = %ld - ((%ld * winwidth(0) + %ld) / %ld)",
                (long)wp->w_virtcol + 1,
                (long)(wp->w_virtcol - wp->w_leftcol),
                (long)wp->w_width / 2, (long)wp->w_width) < 0
            || put_eol(fd) == FAIL
            || put_line(fd, "if s:c > 0") == FAIL
            || fprintf(fd,
                "  exe 'normal! ' . s:c . '|zs' . %ld . '|'",
                (long)wp->w_virtcol + 1) < 0
            || put_eol(fd) == FAIL
            || put_line(fd, "else") == FAIL
            || fprintf(fd, "  normal! 0%d|", wp->w_virtcol + 1) < 0
            || put_eol(fd) == FAIL
            || put_line(fd, "endif") == FAIL)
          return FAIL;
      } else   {
        if (fprintf(fd, "normal! 0%d|", wp->w_virtcol + 1) < 0
            || put_eol(fd) == FAIL)
          return FAIL;
      }
    }
  }

  /*
   * Local directory.
   */
  if (wp->w_localdir != NULL) {
    if (fputs("lcd ", fd) < 0
        || ses_put_fname(fd, wp->w_localdir, flagp) == FAIL
        || put_eol(fd) == FAIL)
      return FAIL;
    did_lcd = TRUE;
  }

  return OK;
}

/*
 * Write an argument list to the session file.
 * Returns FAIL if writing fails.
 */
static int 
ses_arglist (
    FILE *fd,
    char *cmd,
    garray_T *gap,
    int fullname,                   /* TRUE: use full path name */
    unsigned *flagp
)
{
  int i;
  char_u      *buf = NULL;
  char_u      *s;

  if (gap->ga_len == 0)
    return put_line(fd, "silent! argdel *");
  if (fputs(cmd, fd) < 0)
    return FAIL;
  for (i = 0; i < gap->ga_len; ++i) {
    /* NULL file names are skipped (only happens when out of memory). */
    s = alist_name(&((aentry_T *)gap->ga_data)[i]);
    if (s != NULL) {
      if (fullname) {
        buf = alloc(MAXPATHL);
        if (buf != NULL) {
          (void)vim_FullName(s, buf, MAXPATHL, FALSE);
          s = buf;
        }
      }
      if (fputs(" ", fd) < 0 || ses_put_fname(fd, s, flagp) == FAIL) {
        vim_free(buf);
        return FAIL;
      }
      vim_free(buf);
    }
  }
  return put_eol(fd);
}

/*
 * Write a buffer name to the session file.
 * Also ends the line.
 * Returns FAIL if writing fails.
 */
static int ses_fname(FILE *fd, buf_T *buf, unsigned *flagp)
{
  char_u      *name;

  /* Use the short file name if the current directory is known at the time
   * the session file will be sourced.
   * Don't do this for ":mkview", we don't know the current directory.
   * Don't do this after ":lcd", we don't keep track of what the current
   * directory is. */
  if (buf->b_sfname != NULL
      && flagp == &ssop_flags
      && (ssop_flags & (SSOP_CURDIR | SSOP_SESDIR))
      && !p_acd
      && !did_lcd)
    name = buf->b_sfname;
  else
    name = buf->b_ffname;
  if (ses_put_fname(fd, name, flagp) == FAIL || put_eol(fd) == FAIL)
    return FAIL;
  return OK;
}

/*
 * Write a file name to the session file.
 * Takes care of the "slash" option in 'sessionoptions' and escapes special
 * characters.
 * Returns FAIL if writing fails or out of memory.
 */
static int ses_put_fname(FILE *fd, char_u *name, unsigned *flagp)
{
  char_u      *sname;
  char_u      *p;
  int retval = OK;

  sname = home_replace_save(NULL, name);
  if (sname == NULL)
    return FAIL;

  if (*flagp & SSOP_SLASH) {
    /* change all backslashes to forward slashes */
    for (p = sname; *p != NUL; mb_ptr_adv(p))
      if (*p == '\\')
        *p = '/';
  }

  /* escape special characters */
  p = vim_strsave_fnameescape(sname, FALSE);
  vim_free(sname);
  if (p == NULL)
    return FAIL;

  /* write the result */
  if (fputs((char *)p, fd) < 0)
    retval = FAIL;

  vim_free(p);
  return retval;
}

/*
 * ":loadview [nr]"
 */
static void ex_loadview(exarg_T *eap)
{
  char_u      *fname;

  fname = get_view_file(*eap->arg);
  if (fname != NULL) {
    do_source(fname, FALSE, DOSO_NONE);
    vim_free(fname);
  }
}

/*
 * Get the name of the view file for the current buffer.
 */
static char_u *get_view_file(int c)
{
  int len = 0;
  char_u      *p, *s;
  char_u      *retval;
  char_u      *sname;

  if (curbuf->b_ffname == NULL) {
    EMSG(_(e_noname));
    return NULL;
  }
  sname = home_replace_save(NULL, curbuf->b_ffname);
  if (sname == NULL)
    return NULL;

  /*
   * We want a file name without separators, because we're not going to make
   * a directory.
   * "normal" path separator	-> "=+"
   * "="			-> "=="
   * ":" path separator	-> "=-"
   */
  for (p = sname; *p; ++p)
    if (*p == '=' || vim_ispathsep(*p))
      ++len;
  retval = alloc((unsigned)(STRLEN(sname) + len + STRLEN(p_vdir) + 9));
  if (retval != NULL) {
    STRCPY(retval, p_vdir);
    add_pathsep(retval);
    s = retval + STRLEN(retval);
    for (p = sname; *p; ++p) {
      if (*p == '=') {
        *s++ = '=';
        *s++ = '=';
      } else if (vim_ispathsep(*p))   {
        *s++ = '=';
#if defined(BACKSLASH_IN_FILENAME) || defined(AMIGA) || defined(VMS)
        if (*p == ':')
          *s++ = '-';
        else
#endif
        *s++ = '+';
      } else
        *s++ = *p;
    }
    *s++ = '=';
    *s++ = c;
    STRCPY(s, ".vim");
  }

  vim_free(sname);
  return retval;
}


/*
 * Write end-of-line character(s) for ":mkexrc", ":mkvimrc" and ":mksession".
 * Return FAIL for a write error.
 */
int put_eol(FILE *fd)
{
  if (
#ifdef USE_CRNL
    (
# ifdef MKSESSION_NL
      !mksession_nl &&
# endif
      (putc('\r', fd) < 0)) ||
#endif
    (putc('\n', fd) < 0))
    return FAIL;
  return OK;
}

/*
 * Write a line to "fd".
 * Return FAIL for a write error.
 */
int put_line(FILE *fd, char *s)
{
  if (fputs(s, fd) < 0 || put_eol(fd) == FAIL)
    return FAIL;
  return OK;
}

/*
 * ":rviminfo" and ":wviminfo".
 */
static void ex_viminfo(exarg_T *eap)
{
  char_u      *save_viminfo;

  save_viminfo = p_viminfo;
  if (*p_viminfo == NUL)
    p_viminfo = (char_u *)"'100";
  if (eap->cmdidx == CMD_rviminfo) {
    if (read_viminfo(eap->arg, VIF_WANT_INFO | VIF_WANT_MARKS
            | (eap->forceit ? VIF_FORCEIT : 0)) == FAIL)
      EMSG(_("E195: Cannot open viminfo file for reading"));
  } else
    write_viminfo(eap->arg, eap->forceit);
  p_viminfo = save_viminfo;
}

/*
 * Make a dialog message in "buff[DIALOG_MSG_SIZE]".
 * "format" must contain "%s".
 */
void dialog_msg(char_u *buff, char *format, char_u *fname)
{
  if (fname == NULL)
    fname = (char_u *)_("Untitled");
  vim_snprintf((char *)buff, DIALOG_MSG_SIZE, format, fname);
}

/*
 * ":behave {mswin,xterm}"
 */
static void ex_behave(exarg_T *eap)
{
  if (STRCMP(eap->arg, "mswin") == 0) {
    set_option_value((char_u *)"selection", 0L, (char_u *)"exclusive", 0);
    set_option_value((char_u *)"selectmode", 0L, (char_u *)"mouse,key", 0);
    set_option_value((char_u *)"mousemodel", 0L, (char_u *)"popup", 0);
    set_option_value((char_u *)"keymodel", 0L,
        (char_u *)"startsel,stopsel", 0);
  } else if (STRCMP(eap->arg, "xterm") == 0)   {
    set_option_value((char_u *)"selection", 0L, (char_u *)"inclusive", 0);
    set_option_value((char_u *)"selectmode", 0L, (char_u *)"", 0);
    set_option_value((char_u *)"mousemodel", 0L, (char_u *)"extend", 0);
    set_option_value((char_u *)"keymodel", 0L, (char_u *)"", 0);
  } else
    EMSG2(_(e_invarg2), eap->arg);
}

/*
 * Function given to ExpandGeneric() to obtain the possible arguments of the
 * ":behave {mswin,xterm}" command.
 */
char_u *get_behave_arg(expand_T *xp, int idx)
{
  if (idx == 0)
    return (char_u *)"mswin";
  if (idx == 1)
    return (char_u *)"xterm";
  return NULL;
}

static int filetype_detect = FALSE;
static int filetype_plugin = FALSE;
static int filetype_indent = FALSE;

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
  char_u      *arg = eap->arg;
  int plugin = FALSE;
  int indent = FALSE;

  if (*eap->arg == NUL) {
    /* Print current status. */
    smsg((char_u *)"filetype detection:%s  plugin:%s  indent:%s",
        filetype_detect ? "ON" : "OFF",
        filetype_plugin ? (filetype_detect ? "ON" : "(on)") : "OFF",
        filetype_indent ? (filetype_detect ? "ON" : "(on)") : "OFF");
    return;
  }

  /* Accept "plugin" and "indent" in any order. */
  for (;; ) {
    if (STRNCMP(arg, "plugin", 6) == 0) {
      plugin = TRUE;
      arg = skipwhite(arg + 6);
      continue;
    }
    if (STRNCMP(arg, "indent", 6) == 0) {
      indent = TRUE;
      arg = skipwhite(arg + 6);
      continue;
    }
    break;
  }
  if (STRCMP(arg, "on") == 0 || STRCMP(arg, "detect") == 0) {
    if (*arg == 'o' || !filetype_detect) {
      source_runtime((char_u *)FILETYPE_FILE, TRUE);
      filetype_detect = TRUE;
      if (plugin) {
        source_runtime((char_u *)FTPLUGIN_FILE, TRUE);
        filetype_plugin = TRUE;
      }
      if (indent) {
        source_runtime((char_u *)INDENT_FILE, TRUE);
        filetype_indent = TRUE;
      }
    }
    if (*arg == 'd') {
      (void)do_doautocmd((char_u *)"filetypedetect BufRead", TRUE);
      do_modelines(0);
    }
  } else if (STRCMP(arg, "off") == 0)   {
    if (plugin || indent) {
      if (plugin) {
        source_runtime((char_u *)FTPLUGOF_FILE, TRUE);
        filetype_plugin = FALSE;
      }
      if (indent) {
        source_runtime((char_u *)INDOFF_FILE, TRUE);
        filetype_indent = FALSE;
      }
    } else   {
      source_runtime((char_u *)FTOFF_FILE, TRUE);
      filetype_detect = FALSE;
    }
  } else
    EMSG2(_(e_invarg2), arg);
}

/*
 * ":setfiletype {name}"
 */
static void ex_setfiletype(exarg_T *eap)
{
  if (!did_filetype)
    set_option_value((char_u *)"filetype", 0L, eap->arg, OPT_LOCAL);
}

static void ex_digraphs(exarg_T *eap)
{
  if (*eap->arg != NUL)
    putdigraph(eap->arg);
  else
    listdigraphs();
}

static void ex_set(exarg_T *eap)
{
  int flags = 0;

  if (eap->cmdidx == CMD_setlocal)
    flags = OPT_LOCAL;
  else if (eap->cmdidx == CMD_setglobal)
    flags = OPT_GLOBAL;
  (void)do_set(eap->arg, flags);
}

/*
 * ":nohlsearch"
 */
static void ex_nohlsearch(exarg_T *eap)
{
  SET_NO_HLSEARCH(TRUE);
  redraw_all_later(SOME_VALID);
}

/*
 * ":[N]match {group} {pattern}"
 * Sets nextcmd to the start of the next command, if any.  Also called when
 * skipping commands to find the next command.
 */
static void ex_match(exarg_T *eap)
{
  char_u      *p;
  char_u      *g = NULL;
  char_u      *end;
  int c;
  int id;

  if (eap->line2 <= 3)
    id = eap->line2;
  else {
    EMSG(e_invcmd);
    return;
  }

  /* First clear any old pattern. */
  if (!eap->skip)
    match_delete(curwin, id, FALSE);

  if (ends_excmd(*eap->arg))
    end = eap->arg;
  else if ((STRNICMP(eap->arg, "none", 4) == 0
            && (vim_iswhite(eap->arg[4]) || ends_excmd(eap->arg[4]))))
    end = eap->arg + 4;
  else {
    p = skiptowhite(eap->arg);
    if (!eap->skip)
      g = vim_strnsave(eap->arg, (int)(p - eap->arg));
    p = skipwhite(p);
    if (*p == NUL) {
      /* There must be two arguments. */
      EMSG2(_(e_invarg2), eap->arg);
      return;
    }
    end = skip_regexp(p + 1, *p, TRUE, NULL);
    if (!eap->skip) {
      if (*end != NUL && !ends_excmd(*skipwhite(end + 1))) {
        eap->errmsg = e_trailing;
        return;
      }
      if (*end != *p) {
        EMSG2(_(e_invarg2), p);
        return;
      }

      c = *end;
      *end = NUL;
      match_add(curwin, g, p + 1, 10, id);
      vim_free(g);
      *end = c;
    }
  }
  eap->nextcmd = find_nextcmd(end);
}

/*
 * ":X": Get crypt key
 */
static void ex_X(exarg_T *eap)
{
  if (get_crypt_method(curbuf) == 0 || blowfish_self_test() == OK)
    (void)get_crypt_key(TRUE, TRUE);
}

static void ex_fold(exarg_T *eap)
{
  if (foldManualAllowed(TRUE))
    foldCreate(eap->line1, eap->line2);
}

static void ex_foldopen(exarg_T *eap)
{
  opFoldRange(eap->line1, eap->line2, eap->cmdidx == CMD_foldopen,
      eap->forceit, FALSE);
}

static void ex_folddo(exarg_T *eap)
{
  linenr_T lnum;

  /* First set the marks for all lines closed/open. */
  for (lnum = eap->line1; lnum <= eap->line2; ++lnum)
    if (hasFolding(lnum, NULL, NULL) == (eap->cmdidx == CMD_folddoclosed))
      ml_setmarked(lnum);

  /* Execute the command on the marked lines. */
  global_exe(eap->arg);
  ml_clearmarked();        /* clear rest of the marks */
}
