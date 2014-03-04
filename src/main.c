/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#define EXTERN
#include "vim.h"
#include "main.h"
#include "blowfish.h"
#include "buffer.h"
#include "charset.h"
#include "diff.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_cmds2.h"
#include "ex_docmd.h"
#include "fileio.h"
#include "fold.h"
#include "getchar.h"
#include "hashtab.h"
#include "if_cscope.h"
#include "mark.h"
#include "mbyte.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "garray.h"
#include "move.h"
#include "normal.h"
#include "ops.h"
#include "option.h"
#include "os_unix.h"
#include "quickfix.h"
#include "screen.h"
#include "syntax.h"
#include "term.h"
#include "ui.h"
#include "version.h"
#include "window.h"
#include "os/os.h"

/* Maximum number of commands from + or -c arguments. */
#define MAX_ARG_CMDS 10

/* values for "window_layout" */
#define WIN_HOR     1       /* "-o" horizontally split windows */
#define WIN_VER     2       /* "-O" vertically split windows */
#define WIN_TABS    3       /* "-p" windows on tab pages */

/* Struct for various parameters passed between main() and other functions. */
typedef struct {
  int argc;
  char        **argv;

  int evim_mode;                        /* started as "evim" */
  char_u      *use_vimrc;               /* vimrc from -u argument */

  int n_commands;                            /* no. of commands from + or -c */
  char_u      *commands[MAX_ARG_CMDS];       /* commands from + or -c arg. */
  char_u cmds_tofree[MAX_ARG_CMDS];          /* commands that need free() */
  int n_pre_commands;                        /* no. of commands from --cmd */
  char_u      *pre_commands[MAX_ARG_CMDS];   /* commands from --cmd argument */

  int edit_type;                        /* type of editing to do */
  char_u      *tagname;                 /* tag from -t argument */
  char_u      *use_ef;                  /* 'errorfile' from -q argument */

  int want_full_screen;
  int stdout_isatty;                    /* is stdout a terminal? */
  char_u      *term;                    /* specified terminal name */
  int ask_for_key;                      /* -x argument */
  int no_swap_file;                     /* "-n" argument used */
  int use_debug_break_level;
  int window_count;                     /* number of windows to use */
  int window_layout;                    /* 0, WIN_HOR, WIN_VER or WIN_TABS */

#if (!defined(UNIX) && !defined(__EMX__)) || defined(ARCHIE)
  int literal;                          /* don't expand file names */
#endif
  int diff_mode;                        /* start with 'diff' set */
} mparm_T;

/* Values for edit_type. */
#define EDIT_NONE   0       /* no edit type yet */
#define EDIT_FILE   1       /* file name argument[s] given, use argument list */
#define EDIT_STDIN  2       /* read file from stdin */
#define EDIT_TAG    3       /* tag name argument given, use tagname */
#define EDIT_QF     4       /* start in quickfix mode */

#if (defined(UNIX) || defined(VMS)) && !defined(NO_VIM_MAIN)
static int file_owned(char *fname);
#endif
static void mainerr(int, char_u *);
#ifndef NO_VIM_MAIN
static void main_msg(char *s);
static void usage(void);
static int get_number_arg(char_u *p, int *idx, int def);
# if defined(HAVE_LOCALE_H) || defined(X_LOCALE)
static void init_locale(void);
# endif
static void parse_command_name(mparm_T *parmp);
static bool parse_char_i(char_u **input, char val);
static bool parse_string(char_u **input, char* val, int len);
static void command_line_scan(mparm_T *parmp);
static void init_params(mparm_T *parmp, int argc, char **argv);
static void init_startuptime(mparm_T *parmp);
static void allocate_generic_buffers(void);
static void check_and_set_isatty(mparm_T *parmp);
static char_u* get_fname(mparm_T *parmp);
static void set_window_layout(mparm_T *parmp);
static void load_plugins(void);
static void handle_quickfix(mparm_T *parmp);
static void handle_tag(char_u *tagname);
static void check_tty(mparm_T *parmp);
static void read_stdin(void);
static void create_windows(mparm_T *parmp);
static void edit_buffers(mparm_T *parmp);
static void exe_pre_commands(mparm_T *parmp);
static void exe_commands(mparm_T *parmp);
static void source_startup_scripts(mparm_T *parmp);
static void main_start_gui(void);
# if defined(HAS_SWAP_EXISTS_ACTION)
static void check_swap_exists_action(void);
# endif
#endif /* NO_VIM_MAIN */


/*
 * Different types of error messages.
 */
static char *(main_errors[]) =
{
  N_("Unknown option argument"),
#define ME_UNKNOWN_OPTION       0
  N_("Too many edit arguments"),
#define ME_TOO_MANY_ARGS        1
  N_("Argument missing after"),
#define ME_ARG_MISSING          2
  N_("Garbage after option argument"),
#define ME_GARBAGE              3
  N_("Too many \"+command\", \"-c command\" or \"--cmd command\" arguments"),
#define ME_EXTRA_CMD            4
  N_("Invalid argument for"),
#define ME_INVALID_ARG          5
};

#ifndef NO_VIM_MAIN     /* skip this for unittests */
  int main(int argc, char **argv)
{
  char_u      *fname = NULL;            /* file name from command line */
  mparm_T params;                       /* various parameters passed between
                                         * main() and other functions. */
  /*
   * Do any system-specific initialisations.  These can NOT use IObuff or
   * NameBuff.  Thus emsg2() cannot be called!
   */
  mch_early_init();

  /* Many variables are in "params" so that we can pass them to invoked
   * functions without a lot of arguments.  "argc" and "argv" are also
   * copied, so that they can be changed. */
  init_params(&params, argc, argv);

#ifdef MEM_PROFILE
  atexit(vim_mem_profile_dump);
#endif

  init_startuptime(&params);

  (void)mb_init();      /* init mb_bytelen_tab[] to ones */
  eval_init();          /* init global variables */

#ifdef __QNXNTO__
  qnx_init();           /* PhAttach() for clipboard, (and gui) */
#endif

  /* Init the table of Normal mode commands. */
  init_normal_cmds();

  /*
   * Allocate space for the generic buffers (needed for set_init_1() and
   * EMSG2()).
   */
  allocate_generic_buffers();

#if defined(HAVE_LOCALE_H) || defined(X_LOCALE)
  /*
   * Setup to use the current locale (for ctype() and many other things).
   * NOTE: Translated messages with encodings other than latin1 will not
   * work until set_init_1() has been called!
   */
  init_locale();
#endif

  /*
   * Check if we have an interactive window.
   * On the Amiga: If there is no window, we open one with a newcli command
   * (needed for :! to * work). mch_check_win() will also handle the -d or
   * -dev argument.
   */
  check_and_set_isatty(&params);

  /*
   * Allocate the first window and buffer.
   * Can't do anything without it, exit when it fails.
   */
  if (win_alloc_first() == FAIL)
    mch_exit(0);

  init_yank();                  /* init yank buffers */

  alist_init(&global_alist);    /* Init the argument list to empty. */

  /*
   * Set the default values for the options.
   * NOTE: Non-latin1 translated messages are working only after this,
   * because this is where "has_mbyte" will be set, which is used by
   * msg_outtrans_len_attr().
   * First find out the home directory, needed to expand "~" in options.
   */
  init_homedir();               /* find real value of $HOME */
  set_init_1();
  TIME_MSG("inits 1");

  set_lang_var();               /* set v:lang and v:ctype */


  /*
   * Figure out the way to work from the command name argv[0].
   * "vimdiff" starts diff mode, "rvim" sets "restricted", etc.
   */
  parse_command_name(&params);

  /*
   * Process the command line arguments.  File names are put in the global
   * argument list "global_alist".
   */
  command_line_scan(&params);

  /*
   * On some systems, when we compile with the GUI, we always use it.  On Mac
   * there is no terminal version, and on Windows we can't fork one off with
   * :gui.
   */

  if (GARGCOUNT > 0)
    fname = get_fname(&params);

  TIME_MSG("expanding arguments");

  if (params.diff_mode && params.window_count == -1)
    params.window_count = 0;            /* open up to 3 windows */

  /* Don't redraw until much later. */
  ++RedrawingDisabled;

  /*
   * When listing swap file names, don't do cursor positioning et. al.
   */
  if (recoverymode && fname == NULL)
    params.want_full_screen = FALSE;

  /*
   * When certain to start the GUI, don't check capabilities of terminal.
   * For GTK we can't be sure, but when started from the desktop it doesn't
   * make sense to try using a terminal.
   */


  /*
   * mch_init() sets up the terminal (window) for use.  This must be
   * done after resetting full_screen, otherwise it may move the cursor
   * (MSDOS).
   * Note that we may use mch_exit() before mch_init()!
   */
  mch_init();
  TIME_MSG("shell init");


  /*
   * Print a warning if stdout is not a terminal.
   */
  check_tty(&params);

  /* This message comes before term inits, but after setting "silent_mode"
   * when the input is not a tty. */
  if (GARGCOUNT > 1 && !silent_mode)
    printf(_("%d files to edit\n"), GARGCOUNT);

  if (params.want_full_screen && !silent_mode) {
    termcapinit(params.term);           /* set terminal name and get terminal
                                           capabilities (will set full_screen) */
    screen_start();             /* don't know where cursor is now */
    TIME_MSG("Termcap init");
  }

  /*
   * Set the default values for the options that use Rows and Columns.
   */
  ui_get_shellsize();           /* inits Rows and Columns */
  win_init_size();
  /* Set the 'diff' option now, so that it can be checked for in a .vimrc
   * file.  There is no buffer yet though. */
  if (params.diff_mode)
    diff_win_options(firstwin, FALSE);

  cmdline_row = Rows - p_ch;
  msg_row = cmdline_row;
  screenalloc(FALSE);           /* allocate screen buffers */
  set_init_2();
  TIME_MSG("inits 2");

  msg_scroll = TRUE;
  no_wait_return = TRUE;

  init_highlight(TRUE, FALSE);   /* set the default highlight groups */
  TIME_MSG("init highlight");

  /* Set the break level after the terminal is initialized. */
  debug_break_level = params.use_debug_break_level;

#endif /* NO_VIM_MAIN */

  /* vim_main2() needs to be produced when FEAT_MZSCHEME is defined even when
   * NO_VIM_MAIN is defined. */

#ifndef NO_VIM_MAIN
  /* Execute --cmd arguments. */
  exe_pre_commands(&params);

  /* Source startup scripts. */
  source_startup_scripts(&params);

  /*
   * Read all the plugin files.
   * Only when compiled with +eval, since most plugins need it.
   */
  load_plugins();

  /* Decide about window layout for diff mode after reading vimrc. */
  set_window_layout(&params);

  /*
   * Recovery mode without a file name: List swap files.
   * This uses the 'dir' option, therefore it must be after the
   * initializations.
   */
  if (recoverymode && fname == NULL) {
    recover_names(NULL, TRUE, 0, NULL);
    mch_exit(0);
  }

  /*
   * Set a few option defaults after reading .vimrc files:
   * 'title' and 'icon', Unix: 'shellpipe' and 'shellredir'.
   */
  set_init_3();
  TIME_MSG("inits 3");

  /*
   * "-n" argument: Disable swap file by setting 'updatecount' to 0.
   * Note that this overrides anything from a vimrc file.
   */
  if (params.no_swap_file)
    p_uc = 0;

  if (curwin->w_p_rl && p_altkeymap) {
    p_hkmap = FALSE;              /* Reset the Hebrew keymap mode */
    curwin->w_p_arab = FALSE;       /* Reset the Arabic keymap mode */
    p_fkmap = TRUE;               /* Set the Farsi keymap mode */
  }

  /*
   * Read in registers, history etc, but not marks, from the viminfo file.
   * This is where v:oldfiles gets filled.
   */
  if (*p_viminfo != NUL) {
    read_viminfo(NULL, VIF_WANT_INFO | VIF_GET_OLDFILES);
    TIME_MSG("reading viminfo");
  }
  /* It's better to make v:oldfiles an empty list than NULL. */
  if (get_vim_var_list(VV_OLDFILES) == NULL)
    set_vim_var_list(VV_OLDFILES, list_alloc());

  /*
   * "-q errorfile": Load the error file now.
   * If the error file can't be read, exit before doing anything else.
   */
  handle_quickfix(&params);

  /*
   * Start putting things on the screen.
   * Scroll screen down before drawing over it
   * Clear screen now, so file message will not be cleared.
   */
  starting = NO_BUFFERS;
  no_wait_return = FALSE;
  if (!exmode_active)
    msg_scroll = FALSE;


  /*
   * If "-" argument given: Read file from stdin.
   * Do this before starting Raw mode, because it may change things that the
   * writing end of the pipe doesn't like, e.g., in case stdin and stderr
   * are the same terminal: "cat | vim -".
   * Using autocommands here may cause trouble...
   */
  if (params.edit_type == EDIT_STDIN && !recoverymode)
    read_stdin();

#if defined(UNIX) || defined(VMS)
  /* When switching screens and something caused a message from a vimrc
   * script, need to output an extra newline on exit. */
  if ((did_emsg || msg_didout) && *T_TI != NUL)
    newline_on_exit = TRUE;
#endif

  /*
   * When done something that is not allowed or error message call
   * wait_return.  This must be done before starttermcap(), because it may
   * switch to another screen. It must be done after settmode(TMODE_RAW),
   * because we want to react on a single key stroke.
   * Call settmode and starttermcap here, so the T_KS and T_TI may be
   * defined by termcapinit and redefined in .exrc.
   */
  settmode(TMODE_RAW);
  TIME_MSG("setting raw mode");

  if (need_wait_return || msg_didany) {
    wait_return(TRUE);
    TIME_MSG("waiting for return");
  }

  starttermcap();             /* start termcap if not done by wait_return() */
  TIME_MSG("start termcap");
  may_req_ambiguous_char_width();

  setmouse();                             /* may start using the mouse */
  if (scroll_region)
    scroll_region_reset();                /* In case Rows changed */
  scroll_start();         /* may scroll the screen to the right position */

  /*
   * Don't clear the screen when starting in Ex mode, unless using the GUI.
   */
  if (exmode_active)
    must_redraw = CLEAR;
  else {
    screenclear();                        /* clear screen */
    TIME_MSG("clearing screen");
  }

  if (params.ask_for_key) {
    (void)blowfish_self_test();
    (void)get_crypt_key(TRUE, TRUE);
    TIME_MSG("getting crypt key");
  }

  no_wait_return = TRUE;

  /*
   * Create the requested number of windows and edit buffers in them.
   * Also does recovery if "recoverymode" set.
   */
  create_windows(&params);
  TIME_MSG("opening buffers");

  /* clear v:swapcommand */
  set_vim_var_string(VV_SWAPCOMMAND, NULL, -1);

  /* Ex starts at last line of the file */
  if (exmode_active)
    curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;

  apply_autocmds(EVENT_BUFENTER, NULL, NULL, FALSE, curbuf);
  TIME_MSG("BufEnter autocommands");
  setpcmark();

  /*
   * When started with "-q errorfile" jump to first error now.
   */
  if (params.edit_type == EDIT_QF) {
    qf_jump(NULL, 0, 0, FALSE);
    TIME_MSG("jump to first error");
  }

  /*
   * If opened more than one window, start editing files in the other
   * windows.
   */
  edit_buffers(&params);

  if (params.diff_mode) {
    win_T   *wp;

    /* set options in each window for "vimdiff". */
    for (wp = firstwin; wp != NULL; wp = wp->w_next)
      diff_win_options(wp, TRUE);
  }

  /*
   * Shorten any of the filenames, but only when absolute.
   */
  shorten_fnames(FALSE);

  /*
   * Need to jump to the tag before executing the '-c command'.
   * Makes "vim -c '/return' -t main" work.
   */
  handle_tag(params.tagname);

  /* Execute any "+", "-c" and "-S" arguments. */
  if (params.n_commands > 0)
    exe_commands(&params);

  RedrawingDisabled = 0;
  redraw_all_later(NOT_VALID);
  no_wait_return = FALSE;
  starting = 0;

  /* Requesting the termresponse is postponed until here, so that a "-c q"
   * argument doesn't make it appear in the shell Vim was started from. */
  may_req_termresponse();

  /* start in insert mode */
  if (p_im)
    need_start_insertmode = TRUE;

  apply_autocmds(EVENT_VIMENTER, NULL, NULL, FALSE, curbuf);
  TIME_MSG("VimEnter autocommands");


  /* When a startup script or session file setup for diff'ing and
   * scrollbind, sync the scrollbind now. */
  if (curwin->w_p_diff && curwin->w_p_scb) {
    update_topline();
    check_scrollbind((linenr_T)0, 0L);
    TIME_MSG("diff scrollbinding");
  }



  /* If ":startinsert" command used, stuff a dummy command to be able to
   * call normal_cmd(), which will then start Insert mode. */
  if (restart_edit != 0)
    stuffcharReadbuff(K_NOP);


  TIME_MSG("before starting main loop");

  /*
   * Call the main command loop.  This never returns.
   */
  main_loop(FALSE, FALSE);

  return 0;
}
#endif /* NO_VIM_MAIN */

/*
 * Main loop: Execute Normal mode commands until exiting Vim.
 * Also used to handle commands in the command-line window, until the window
 * is closed.
 * Also used to handle ":visual" command after ":global": execute Normal mode
 * commands, return when entering Ex mode.  "noexmode" is TRUE then.
 */
void 
main_loop (
    int cmdwin,                 /* TRUE when working in the command-line window */
    int noexmode               /* TRUE when return on entering Ex mode */
)
{
  oparg_T oa;                                   /* operator arguments */
  int previous_got_int = FALSE;                 /* "got_int" was TRUE */
  linenr_T conceal_old_cursor_line = 0;
  linenr_T conceal_new_cursor_line = 0;
  int conceal_update_lines = FALSE;


  clear_oparg(&oa);
  while (!cmdwin
      || cmdwin_result == 0
      ) {
    if (stuff_empty()) {
      did_check_timestamps = FALSE;
      if (need_check_timestamps)
        check_timestamps(FALSE);
      if (need_wait_return)             /* if wait_return still needed ... */
        wait_return(FALSE);             /* ... call it now */
      if (need_start_insertmode && goto_im()
          && !VIsual_active
         ) {
        need_start_insertmode = FALSE;
        stuffReadbuff((char_u *)"i");           /* start insert mode next */
        /* skip the fileinfo message now, because it would be shown
         * after insert mode finishes! */
        need_fileinfo = FALSE;
      }
    }

    /* Reset "got_int" now that we got back to the main loop.  Except when
     * inside a ":g/pat/cmd" command, then the "got_int" needs to abort
     * the ":g" command.
     * For ":g/pat/vi" we reset "got_int" when used once.  When used
     * a second time we go back to Ex mode and abort the ":g" command. */
    if (got_int) {
      if (noexmode && global_busy && !exmode_active && previous_got_int) {
        /* Typed two CTRL-C in a row: go back to ex mode as if "Q" was
         * used and keep "got_int" set, so that it aborts ":g". */
        exmode_active = EXMODE_NORMAL;
        State = NORMAL;
      } else if (!global_busy || !exmode_active)   {
        if (!quit_more)
          (void)vgetc();                        /* flush all buffers */
        got_int = FALSE;
      }
      previous_got_int = TRUE;
    } else
      previous_got_int = FALSE;

    if (!exmode_active)
      msg_scroll = FALSE;
    quit_more = FALSE;

    /*
     * If skip redraw is set (for ":" in wait_return()), don't redraw now.
     * If there is nothing in the stuff_buffer or do_redraw is TRUE,
     * update cursor and redraw.
     */
    if (skip_redraw || exmode_active)
      skip_redraw = FALSE;
    else if (do_redraw || stuff_empty()) {
      /* Trigger CursorMoved if the cursor moved. */
      if (!finish_op && (
            has_cursormoved()
            ||
            curwin->w_p_cole > 0
            )
          && !equalpos(last_cursormoved, curwin->w_cursor)) {
        if (has_cursormoved())
          apply_autocmds(EVENT_CURSORMOVED, NULL, NULL,
              FALSE, curbuf);
        if (curwin->w_p_cole > 0) {
          conceal_old_cursor_line = last_cursormoved.lnum;
          conceal_new_cursor_line = curwin->w_cursor.lnum;
          conceal_update_lines = TRUE;
        }
        last_cursormoved = curwin->w_cursor;
      }

      /* Trigger TextChanged if b_changedtick differs. */
      if (!finish_op && has_textchanged()
          && last_changedtick != curbuf->b_changedtick) {
        if (last_changedtick_buf == curbuf)
          apply_autocmds(EVENT_TEXTCHANGED, NULL, NULL,
              FALSE, curbuf);
        last_changedtick_buf = curbuf;
        last_changedtick = curbuf->b_changedtick;
      }

      /* Scroll-binding for diff mode may have been postponed until
       * here.  Avoids doing it for every change. */
      if (diff_need_scrollbind) {
        check_scrollbind((linenr_T)0, 0L);
        diff_need_scrollbind = FALSE;
      }
      /* Include a closed fold completely in the Visual area. */
      foldAdjustVisual();
      /*
       * When 'foldclose' is set, apply 'foldlevel' to folds that don't
       * contain the cursor.
       * When 'foldopen' is "all", open the fold(s) under the cursor.
       * This may mark the window for redrawing.
       */
      if (hasAnyFolding(curwin) && !char_avail()) {
        foldCheckClose();
        if (fdo_flags & FDO_ALL)
          foldOpenCursor();
      }

      /*
       * Before redrawing, make sure w_topline is correct, and w_leftcol
       * if lines don't wrap, and w_skipcol if lines wrap.
       */
      update_topline();
      validate_cursor();

      if (VIsual_active)
        update_curbuf(INVERTED);        /* update inverted part */
      else if (must_redraw)
        update_screen(0);
      else if (redraw_cmdline || clear_cmdline)
        showmode();
      redraw_statuslines();
      if (need_maketitle)
        maketitle();
      /* display message after redraw */
      if (keep_msg != NULL) {
        char_u *p;

        /* msg_attr_keep() will set keep_msg to NULL, must free the
         * string here. */
        p = keep_msg;
        keep_msg = NULL;
        msg_attr(p, keep_msg_attr);
        vim_free(p);
      }
      if (need_fileinfo) {              /* show file info after redraw */
        fileinfo(FALSE, TRUE, FALSE);
        need_fileinfo = FALSE;
      }

      emsg_on_display = FALSE;          /* can delete error message now */
      did_emsg = FALSE;
      msg_didany = FALSE;               /* reset lines_left in msg_start() */
      may_clear_sb_text();              /* clear scroll-back text on next msg */
      showruler(FALSE);

      if (conceal_update_lines
          && (conceal_old_cursor_line != conceal_new_cursor_line
            || conceal_cursor_line(curwin)
            || need_cursor_line_redraw)) {
        if (conceal_old_cursor_line != conceal_new_cursor_line
            && conceal_old_cursor_line
            <= curbuf->b_ml.ml_line_count)
          update_single_line(curwin, conceal_old_cursor_line);
        update_single_line(curwin, conceal_new_cursor_line);
        curwin->w_valid &= ~VALID_CROW;
      }
      setcursor();
      cursor_on();

      do_redraw = FALSE;

#ifdef STARTUPTIME
      /* Now that we have drawn the first screen all the startup stuff
       * has been done, close any file for startup messages. */
      if (time_fd != NULL) {
        TIME_MSG("first screen update");
        TIME_MSG("--- VIM STARTED ---");
        fclose(time_fd);
        time_fd = NULL;
      }
#endif
    }

    /*
     * Update w_curswant if w_set_curswant has been set.
     * Postponed until here to avoid computing w_virtcol too often.
     */
    update_curswant();

    /*
     * May perform garbage collection when waiting for a character, but
     * only at the very toplevel.  Otherwise we may be using a List or
     * Dict internally somewhere.
     * "may_garbage_collect" is reset in vgetc() which is invoked through
     * do_exmode() and normal_cmd().
     */
    may_garbage_collect = (!cmdwin && !noexmode);
    /*
     * If we're invoked as ex, do a round of ex commands.
     * Otherwise, get and execute a normal mode command.
     */
    if (exmode_active) {
      if (noexmode)         /* End of ":global/path/visual" commands */
        return;
      do_exmode(exmode_active == EXMODE_VIM);
    } else
      normal_cmd(&oa, TRUE);
  }
}




/* Exit properly */
void getout(int exitval)
{
  buf_T       *buf;
  win_T       *wp;
  tabpage_T   *tp, *next_tp;

  exiting = TRUE;

  /* When running in Ex mode an error causes us to exit with a non-zero exit
   * code.  POSIX requires this, although it's not 100% clear from the
   * standard. */
  if (exmode_active)
    exitval += ex_exitval;

  /* Position the cursor on the last screen line, below all the text */
  windgoto((int)Rows - 1, 0);

  /* Optionally print hashtable efficiency. */
  hash_debug_results();


  if (get_vim_var_nr(VV_DYING) <= 1) {
    /* Trigger BufWinLeave for all windows, but only once per buffer. */
    for (tp = first_tabpage; tp != NULL; tp = next_tp) {
      next_tp = tp->tp_next;
      for (wp = (tp == curtab)
          ? firstwin : tp->tp_firstwin; wp != NULL; wp = wp->w_next) {
        if (wp->w_buffer == NULL)
          /* Autocmd must have close the buffer already, skip. */
          continue;
        buf = wp->w_buffer;
        if (buf->b_changedtick != -1) {
          apply_autocmds(EVENT_BUFWINLEAVE, buf->b_fname,
              buf->b_fname, FALSE, buf);
          buf->b_changedtick = -1;            /* note that we did it already */
          /* start all over, autocommands may mess up the lists */
          next_tp = first_tabpage;
          break;
        }
      }
    }

    /* Trigger BufUnload for buffers that are loaded */
    for (buf = firstbuf; buf != NULL; buf = buf->b_next)
      if (buf->b_ml.ml_mfp != NULL) {
        apply_autocmds(EVENT_BUFUNLOAD, buf->b_fname, buf->b_fname,
            FALSE, buf);
        if (!buf_valid(buf))            /* autocmd may delete the buffer */
          break;
      }
    apply_autocmds(EVENT_VIMLEAVEPRE, NULL, NULL, FALSE, curbuf);
  }

  if (*p_viminfo != NUL)
    /* Write out the registers, history, marks etc, to the viminfo file */
    write_viminfo(NULL, FALSE);

  if (get_vim_var_nr(VV_DYING) <= 1)
    apply_autocmds(EVENT_VIMLEAVE, NULL, NULL, FALSE, curbuf);

  profile_dump();

  if (did_emsg
     ) {
    /* give the user a chance to read the (error) message */
    no_wait_return = FALSE;
    wait_return(FALSE);
  }

  /* Position the cursor again, the autocommands may have moved it */
  windgoto((int)Rows - 1, 0);

#if defined(USE_ICONV) && defined(DYNAMIC_ICONV)
  iconv_end();
#endif
  cs_end();
  if (garbage_collect_at_exit)
    garbage_collect();

  mch_exit(exitval);
}

#ifndef NO_VIM_MAIN
/*
 * Get a (optional) count for a Vim argument.
 */
static int 
get_number_arg (
    char_u *p,             /* pointer to argument */
    int *idx,           /* index in argument, is incremented */
    int def                    /* default value */
)
{
  if (vim_isdigit(p[*idx])) {
    def = atoi((char *)&(p[*idx]));
    while (vim_isdigit(p[*idx]))
      *idx = *idx + 1;
  }
  return def;
}

#if defined(HAVE_LOCALE_H) || defined(X_LOCALE)
/*
 * Setup to use the current locale (for ctype() and many other things).
 */
static void init_locale(void)                 {
  setlocale(LC_ALL, "");

# if defined(FEAT_FLOAT) && defined(LC_NUMERIC)
  /* Make sure strtod() uses a decimal point, not a comma. */
  setlocale(LC_NUMERIC, "C");
# endif


  {
    int mustfree = FALSE;
    char_u  *p;

    /* expand_env() doesn't work yet, because chartab[] is not initialized
     * yet, call vim_getenv() directly */
    p = vim_getenv((char_u *)"VIMRUNTIME", &mustfree);
    if (p != NULL && *p != NUL) {
      vim_snprintf((char *)NameBuff, MAXPATHL, "%s/lang", p);
      bindtextdomain(VIMPACKAGE, (char *)NameBuff);
    }
    if (mustfree)
      vim_free(p);
    textdomain(VIMPACKAGE);
  }
  TIME_MSG("locale set");
}

#endif

/*
 * Check for: [r][e][g][vi|vim|view][diff][ex[im]]
 * If the executable name starts with "r" we disable shell commands.
 * If the next character is "e" we run in Easy mode.
 * If the next character is "g" we run the GUI version.
 * If the next characters are "view" we start in readonly mode.
 * If the next characters are "diff" or "vimdiff" we start in diff mode.
 * If the next characters are "ex" we start in Ex mode.  If it's followed
 * by "im" use improved Ex mode.
 */
static void parse_command_name(mparm_T *parmp)
{
  char_u      *initstr;

  initstr = gettail((char_u *)parmp->argv[0]);


  set_vim_var_string(VV_PROGNAME, initstr, -1);

  if (parse_string(&initstr, "editor", 6))
    return;

  if (parse_char_i(&initstr, 'r'))
    restricted = TRUE;

  if (parse_char_i(&initstr, 'e'))
    parmp->evim_mode = TRUE;

  /* "gvim" starts the GUI.  Also accept "Gvim" for MS-Windows. */
  if (parse_char_i(&initstr, 'g'))
    main_start_gui();

  if (parse_string(&initstr, "view", 4)) {
    readonlymode = TRUE;
    curbuf->b_p_ro = TRUE;
    p_uc = 10000;                       /* don't update very often */
  } else {
    parse_string(&initstr, "vim", 3);   /* consume "vim" if it's there */
  }

  /* Catch "[r][g]vimdiff" and "[r][g]viewdiff". */
  if (parse_string(&initstr, "diff", 4))
    parmp->diff_mode = TRUE;

  if (parse_string(&initstr, "ex", 2)) {
    if (parse_string(&initstr, "im", 2))
      exmode_active = EXMODE_VIM;
    else
      exmode_active = EXMODE_NORMAL;
    change_compatible(TRUE);            /* set 'compatible' */
  }
}

static bool parse_char_i(char_u **input, char val)
{
  if (TOLOWER_ASC(**input) == val) {
    *input += 1;  /* or (*input)++ WITH parens */
    return true;
  }
  return false;
}

static bool parse_string(input, val, len)
  char_u      **input;
  char        *val;
  int len;
{
  if (STRNICMP(*input, val, len) == 0) {
    *input += len;
    return true;
  }
  return false;
}

/*
 * Scan the command line arguments.
 */
static void command_line_scan(mparm_T *parmp)
{
  int argc = parmp->argc;
  char        **argv = parmp->argv;
  int argv_idx;                         /* index in argv[n][] */
  int had_minmin = FALSE;               /* found "--" argument */
  int want_argument;                    /* option argument with argument */
  int c;
  char_u      *p = NULL;
  long n;

  --argc;
  ++argv;
  argv_idx = 1;             /* active option letter is argv[0][argv_idx] */
  while (argc > 0) {
    /*
     * "+" or "+{number}" or "+/{pat}" or "+{command}" argument.
     */
    if (argv[0][0] == '+' && !had_minmin) {
      if (parmp->n_commands >= MAX_ARG_CMDS)
        mainerr(ME_EXTRA_CMD, NULL);
      argv_idx = -1;                /* skip to next argument */
      if (argv[0][1] == NUL)
        parmp->commands[parmp->n_commands++] = (char_u *)"$";
      else
        parmp->commands[parmp->n_commands++] = (char_u *)&(argv[0][1]);
    }
    /*
     * Optional argument.
     */
    else if (argv[0][0] == '-' && !had_minmin) {
      want_argument = FALSE;
      c = argv[0][argv_idx++];
      switch (c) {
        case NUL:                 /* "vim -"  read from stdin */
          /* "ex -" silent mode */
          if (exmode_active)
            silent_mode = TRUE;
          else {
            if (parmp->edit_type != EDIT_NONE)
              mainerr(ME_TOO_MANY_ARGS, (char_u *)argv[0]);
            parmp->edit_type = EDIT_STDIN;
            read_cmd_fd = 2;              /* read from stderr instead of stdin */
          }
          argv_idx = -1;                  /* skip to next argument */
          break;

        case '-':                 /* "--" don't take any more option arguments */
          /* "--help" give help message */
          /* "--version" give version message */
          /* "--literal" take files literally */
          /* "--nofork" don't fork */
          /* "--noplugin[s]" skip plugins */
          /* "--cmd <cmd>" execute cmd before vimrc */
          if (STRICMP(argv[0] + argv_idx, "help") == 0)
            usage();
          else if (STRICMP(argv[0] + argv_idx, "version") == 0) {
            Columns = 80;                 /* need to init Columns */
            info_message = TRUE;           /* use mch_msg(), not mch_errmsg() */
            list_version();
            msg_putchar('\n');
            msg_didout = FALSE;
            mch_exit(0);
          } else if (STRNICMP(argv[0] + argv_idx, "literal", 7) == 0)   {
#if (!defined(UNIX) && !defined(__EMX__)) || defined(ARCHIE)
            parmp->literal = TRUE;
#endif
          } else if (STRNICMP(argv[0] + argv_idx, "nofork", 6) == 0)   {
          } else if (STRNICMP(argv[0] + argv_idx, "noplugin", 8) == 0)
            p_lpl = FALSE;
          else if (STRNICMP(argv[0] + argv_idx, "cmd", 3) == 0) {
            want_argument = TRUE;
            argv_idx += 3;
          } else if (STRNICMP(argv[0] + argv_idx, "startuptime", 11) == 0)   {
            want_argument = TRUE;
            argv_idx += 11;
          } else   {
            if (argv[0][argv_idx])
              mainerr(ME_UNKNOWN_OPTION, (char_u *)argv[0]);
            had_minmin = TRUE;
          }
          if (!want_argument)
            argv_idx = -1;                /* skip to next argument */
          break;

        case 'A':                 /* "-A" start in Arabic mode */
          set_option_value((char_u *)"arabic", 1L, NULL, 0);
          break;

        case 'b':                 /* "-b" binary mode */
          /* Needs to be effective before expanding file names, because
           * for Win32 this makes us edit a shortcut file itself,
           * instead of the file it links to. */
          set_options_bin(curbuf->b_p_bin, 1, 0);
          curbuf->b_p_bin = 1;                /* binary file I/O */
          break;

        case 'C':                 /* "-C"  Compatible */
          change_compatible(TRUE);
          break;

        case 'e':                 /* "-e" Ex mode */
          exmode_active = EXMODE_NORMAL;
          break;

        case 'E':                 /* "-E" Improved Ex mode */
          exmode_active = EXMODE_VIM;
          break;

        case 'f':                 /* "-f"  GUI: run in foreground.  Amiga: open
                                     window directly, not with newcli */
          break;

        case 'g':                 /* "-g" start GUI */
          main_start_gui();
          break;

        case 'F':                 /* "-F" start in Farsi mode: rl + fkmap set */
          p_fkmap = TRUE;
          set_option_value((char_u *)"rl", 1L, NULL, 0);
          break;

        case 'h':                 /* "-h" give help message */
          usage();
          break;

        case 'H':                 /* "-H" start in Hebrew mode: rl + hkmap set */
          p_hkmap = TRUE;
          set_option_value((char_u *)"rl", 1L, NULL, 0);
          break;

        case 'l':                 /* "-l" lisp mode, 'lisp' and 'showmatch' on */
          set_option_value((char_u *)"lisp", 1L, NULL, 0);
          p_sm = TRUE;
          break;

        case 'M':                 /* "-M"  no changes or writing of files */
          reset_modifiable();
          /* FALLTHROUGH */

        case 'm':                 /* "-m"  no writing of files */
          p_write = FALSE;
          break;

        case 'y':                 /* "-y"  easy mode */
          parmp->evim_mode = TRUE;
          break;

        case 'N':                 /* "-N"  Nocompatible */
          change_compatible(FALSE);
          break;

        case 'n':                 /* "-n" no swap file */
          parmp->no_swap_file = TRUE;
          break;

        case 'p':                 /* "-p[N]" open N tab pages */
#ifdef TARGET_API_MAC_OSX
          /* For some reason on MacOS X, an argument like:
             -psn_0_10223617 is passed in when invoke from Finder
             or with the 'open' command */
          if (argv[0][argv_idx] == 's') {
            argv_idx = -1;           /* bypass full -psn */
            main_start_gui();
            break;
          }
#endif
          /* default is 0: open window for each file */
          parmp->window_count = get_number_arg((char_u *)argv[0],
              &argv_idx, 0);
          parmp->window_layout = WIN_TABS;
          break;

        case 'o':                 /* "-o[N]" open N horizontal split windows */
          /* default is 0: open window for each file */
          parmp->window_count = get_number_arg((char_u *)argv[0],
              &argv_idx, 0);
          parmp->window_layout = WIN_HOR;
          break;

        case 'O':                 /* "-O[N]" open N vertical split windows */
          /* default is 0: open window for each file */
          parmp->window_count = get_number_arg((char_u *)argv[0],
              &argv_idx, 0);
          parmp->window_layout = WIN_VER;
          break;

        case 'q':                 /* "-q" QuickFix mode */
          if (parmp->edit_type != EDIT_NONE)
            mainerr(ME_TOO_MANY_ARGS, (char_u *)argv[0]);
          parmp->edit_type = EDIT_QF;
          if (argv[0][argv_idx]) {                /* "-q{errorfile}" */
            parmp->use_ef = (char_u *)argv[0] + argv_idx;
            argv_idx = -1;
          } else if (argc > 1)                    /* "-q {errorfile}" */
            want_argument = TRUE;
          break;

        case 'R':                 /* "-R" readonly mode */
          readonlymode = TRUE;
          curbuf->b_p_ro = TRUE;
          p_uc = 10000;                           /* don't update very often */
          break;

        case 'r':                 /* "-r" recovery mode */
        case 'L':                 /* "-L" recovery mode */
          recoverymode = 1;
          break;

        case 's':
          if (exmode_active)              /* "-s" silent (batch) mode */
            silent_mode = TRUE;
          else                    /* "-s {scriptin}" read from script file */
            want_argument = TRUE;
          break;

        case 't':                 /* "-t {tag}" or "-t{tag}" jump to tag */
          if (parmp->edit_type != EDIT_NONE)
            mainerr(ME_TOO_MANY_ARGS, (char_u *)argv[0]);
          parmp->edit_type = EDIT_TAG;
          if (argv[0][argv_idx]) {                /* "-t{tag}" */
            parmp->tagname = (char_u *)argv[0] + argv_idx;
            argv_idx = -1;
          } else                                  /* "-t {tag}" */
            want_argument = TRUE;
          break;

        case 'D':                 /* "-D"		Debugging */
          parmp->use_debug_break_level = 9999;
          break;
        case 'd':                 /* "-d"		'diff' */
          parmp->diff_mode = TRUE;
          break;
        case 'V':                 /* "-V{N}"	Verbose level */
          /* default is 10: a little bit verbose */
          p_verbose = get_number_arg((char_u *)argv[0], &argv_idx, 10);
          if (argv[0][argv_idx] != NUL) {
            set_option_value((char_u *)"verbosefile", 0L,
                (char_u *)argv[0] + argv_idx, 0);
            argv_idx = (int)STRLEN(argv[0]);
          }
          break;

        case 'v':                 /* "-v"  Vi-mode (as if called "vi") */
          exmode_active = 0;
          break;

        case 'w':                 /* "-w{number}"	set window height */
          /* "-w {scriptout}"	write to script */
          if (vim_isdigit(((char_u *)argv[0])[argv_idx])) {
            n = get_number_arg((char_u *)argv[0], &argv_idx, 10);
            set_option_value((char_u *)"window", n, NULL, 0);
            break;
          }
          want_argument = TRUE;
          break;

        case 'x':                 /* "-x"  encrypted reading/writing of files */
          parmp->ask_for_key = TRUE;
          break;

        case 'X':                 /* "-X"  don't connect to X server */
          break;

        case 'Z':                 /* "-Z"  restricted mode */
          restricted = TRUE;
          break;

        case 'c':                 /* "-c{command}" or "-c {command}" execute
                                     command */
          if (argv[0][argv_idx] != NUL) {
            if (parmp->n_commands >= MAX_ARG_CMDS)
              mainerr(ME_EXTRA_CMD, NULL);
            parmp->commands[parmp->n_commands++] = (char_u *)argv[0]
              + argv_idx;
            argv_idx = -1;
            break;
          }
          /*FALLTHROUGH*/
        case 'S':                 /* "-S {file}" execute Vim script */
        case 'i':                 /* "-i {viminfo}" use for viminfo */
        case 'T':                 /* "-T {terminal}" terminal name */
        case 'u':                 /* "-u {vimrc}" vim inits file */
        case 'U':                 /* "-U {gvimrc}" gvim inits file */
        case 'W':                 /* "-W {scriptout}" overwrite */
          want_argument = TRUE;
          break;

        default:
          mainerr(ME_UNKNOWN_OPTION, (char_u *)argv[0]);
      }

      /*
       * Handle option arguments with argument.
       */
      if (want_argument) {
        /*
         * Check for garbage immediately after the option letter.
         */
        if (argv[0][argv_idx] != NUL)
          mainerr(ME_GARBAGE, (char_u *)argv[0]);

        --argc;
        if (argc < 1 && c != 'S')          /* -S has an optional argument */
          mainerr_arg_missing((char_u *)argv[0]);
        ++argv;
        argv_idx = -1;

        switch (c) {
          case 'c':               /* "-c {command}" execute command */
          case 'S':               /* "-S {file}" execute Vim script */
            if (parmp->n_commands >= MAX_ARG_CMDS)
              mainerr(ME_EXTRA_CMD, NULL);
            if (c == 'S') {
              char    *a;

              if (argc < 1)
                /* "-S" without argument: use default session file
                 * name. */
                a = SESSION_FILE;
              else if (argv[0][0] == '-') {
                /* "-S" followed by another option: use default
                 * session file name. */
                a = SESSION_FILE;
                ++argc;
                --argv;
              } else
                a = argv[0];
              p = alloc((unsigned)(STRLEN(a) + 4));
              if (p == NULL)
                mch_exit(2);
              sprintf((char *)p, "so %s", a);
              parmp->cmds_tofree[parmp->n_commands] = TRUE;
              parmp->commands[parmp->n_commands++] = p;
            } else
              parmp->commands[parmp->n_commands++] =
                (char_u *)argv[0];
            break;

          case '-':
            if (argv[-1][2] == 'c') {
              /* "--cmd {command}" execute command */
              if (parmp->n_pre_commands >= MAX_ARG_CMDS)
                mainerr(ME_EXTRA_CMD, NULL);
              parmp->pre_commands[parmp->n_pre_commands++] =
                (char_u *)argv[0];
            }
            /* "--startuptime <file>" already handled */
            break;

            /*	case 'd':   -d {device} is handled in mch_check_win() for the
             *		    Amiga */

          case 'q':               /* "-q {errorfile}" QuickFix mode */
            parmp->use_ef = (char_u *)argv[0];
            break;

          case 'i':               /* "-i {viminfo}" use for viminfo */
            use_viminfo = (char_u *)argv[0];
            break;

          case 's':               /* "-s {scriptin}" read from script file */
            if (scriptin[0] != NULL) {
scripterror:
              mch_errmsg(_("Attempt to open script file again: \""));
              mch_errmsg(argv[-1]);
              mch_errmsg(" ");
              mch_errmsg(argv[0]);
              mch_errmsg("\"\n");
              mch_exit(2);
            }
            if ((scriptin[0] = mch_fopen(argv[0], READBIN)) == NULL) {
              mch_errmsg(_("Cannot open for reading: \""));
              mch_errmsg(argv[0]);
              mch_errmsg("\"\n");
              mch_exit(2);
            }
            if (save_typebuf() == FAIL)
              mch_exit(2);                /* out of memory */
            break;

          case 't':               /* "-t {tag}" */
            parmp->tagname = (char_u *)argv[0];
            break;

          case 'T':               /* "-T {terminal}" terminal name */
            /*
             * The -T term argument is always available and when
             * HAVE_TERMLIB is supported it overrides the environment
             * variable TERM.
             */
            parmp->term = (char_u *)argv[0];
            break;

          case 'u':               /* "-u {vimrc}" vim inits file */
            parmp->use_vimrc = (char_u *)argv[0];
            break;

          case 'U':               /* "-U {gvimrc}" gvim inits file */
            break;

          case 'w':               /* "-w {nr}" 'window' value */
            /* "-w {scriptout}" append to script file */
            if (vim_isdigit(*((char_u *)argv[0]))) {
              argv_idx = 0;
              n = get_number_arg((char_u *)argv[0], &argv_idx, 10);
              set_option_value((char_u *)"window", n, NULL, 0);
              argv_idx = -1;
              break;
            }
            /*FALLTHROUGH*/
          case 'W':               /* "-W {scriptout}" overwrite script file */
            if (scriptout != NULL)
              goto scripterror;
            if ((scriptout = mch_fopen(argv[0],
                    c == 'w' ? APPENDBIN : WRITEBIN)) == NULL) {
              mch_errmsg(_("Cannot open for script output: \""));
              mch_errmsg(argv[0]);
              mch_errmsg("\"\n");
              mch_exit(2);
            }
            break;

        }
      }
    }
    /*
     * File name argument.
     */
    else {
      argv_idx = -1;                /* skip to next argument */

      /* Check for only one type of editing. */
      if (parmp->edit_type != EDIT_NONE && parmp->edit_type != EDIT_FILE)
        mainerr(ME_TOO_MANY_ARGS, (char_u *)argv[0]);
      parmp->edit_type = EDIT_FILE;


      /* Add the file to the global argument list. */
      if (ga_grow(&global_alist.al_ga, 1) == FAIL
          || (p = vim_strsave((char_u *)argv[0])) == NULL)
        mch_exit(2);
      if (parmp->diff_mode && mch_isdir(p) && GARGCOUNT > 0
          && !mch_isdir(alist_name(&GARGLIST[0]))) {
        char_u      *r;

        r = concat_fnames(p, gettail(alist_name(&GARGLIST[0])), TRUE);
        if (r != NULL) {
          vim_free(p);
          p = r;
        }
      }

#ifdef USE_FNAME_CASE
      /* Make the case of the file name match the actual file. */
      fname_case(p, 0);
#endif

      alist_add(&global_alist, p,
#if (!defined(UNIX) && !defined(__EMX__)) || defined(ARCHIE)
          parmp->literal ? 2 : 0                /* add buffer nr after exp. */
#else
          2                     /* add buffer number now and use curbuf */
#endif
          );

    }

    /*
     * If there are no more letters after the current "-", go to next
     * argument.  argv_idx is set to -1 when the current argument is to be
     * skipped.
     */
    if (argv_idx <= 0 || argv[0][argv_idx] == NUL) {
      --argc;
      ++argv;
      argv_idx = 1;
    }
  }

  /* If there is a "+123" or "-c" command, set v:swapcommand to the first
   * one. */
  if (parmp->n_commands > 0) {
    p = alloc((unsigned)STRLEN(parmp->commands[0]) + 3);
    if (p != NULL) {
      sprintf((char *)p, ":%s\r", parmp->commands[0]);
      set_vim_var_string(VV_SWAPCOMMAND, p, -1);
      vim_free(p);
    }
  }
  TIME_MSG("parsing arguments");
}

/*
 * Many variables are in "params" so that we can pass them to invoked
 * functions without a lot of arguments.  "argc" and "argv" are also
 * copied, so that they can be changed. */
static void init_params(mparm_T *paramp, int argc, char **argv)
{
  vim_memset(paramp, 0, sizeof(*paramp));
  paramp->argc = argc;
  paramp->argv = argv;
  paramp->want_full_screen = TRUE;
  paramp->use_debug_break_level = -1;
  paramp->window_count = -1;
}

/*
 * Initialize global startuptime file if "--startuptime" passed as an argument.
 */
static void init_startuptime(mparm_T *paramp)
{
#ifdef STARTUPTIME
  int i;
  for (i = 1; i < paramp->argc; ++i) {
    if (STRICMP(paramp->argv[i], "--startuptime") == 0 && i + 1 < paramp->argc) {
      time_fd = mch_fopen(paramp->argv[i + 1], "a");
      TIME_MSG("--- VIM STARTING ---");
      break;
    }
  }
#endif
  starttime = time(NULL);
}

/*
 * Allocate space for the generic buffers (needed for set_init_1() and
 * EMSG2()).
 */
static void allocate_generic_buffers(void)
{
  if ((IObuff = alloc(IOSIZE)) == NULL
      || (NameBuff = alloc(MAXPATHL)) == NULL)
    mch_exit(0);
  TIME_MSG("Allocated generic buffers");
}

/*
 * Check if we have an interactive window.
 * On the Amiga: If there is no window, we open one with a newcli command
 * (needed for :! to * work). mch_check_win() will also handle the -d or
 * -dev argument.
 */
static void check_and_set_isatty(mparm_T *paramp)
{
  paramp->stdout_isatty = (mch_check_win(paramp->argc, paramp->argv) != FAIL);
  TIME_MSG("window checked");
}

/*
 * Get filename from command line, given that there is one.
 */
static char_u *get_fname(mparm_T *parmp)
{
#if (!defined(UNIX) && !defined(__EMX__)) || defined(ARCHIE)
  /*
   * Expand wildcards in file names.
   */
  if (!parmp->literal) {
    /* Temporarily add '(' and ')' to 'isfname'.  These are valid
     * filename characters but are excluded from 'isfname' to make
     * "gf" work on a file name in parenthesis (e.g.: see vim.h). */
    do_cmdline_cmd((char_u *)":set isf+=(,)");
    alist_expand(NULL, 0);
    do_cmdline_cmd((char_u *)":set isf&");
  }
#endif
  return alist_name(&GARGLIST[0]);
}

/*
 * Decide about window layout for diff mode after reading vimrc.
 */
static void set_window_layout(mparm_T *paramp)
{
  if (paramp->diff_mode && paramp->window_layout == 0) {
    if (diffopt_horizontal())
      paramp->window_layout = WIN_HOR;             /* use horizontal split */
    else
      paramp->window_layout = WIN_VER;             /* use vertical split */
  }
}

/*
 * Read all the plugin files.
 * Only when compiled with +eval, since most plugins need it.
 */
static void load_plugins(void)
{
  if (p_lpl) {
    source_runtime((char_u *)"plugin/**/*.vim", TRUE);
    TIME_MSG("loading plugins");
  }
}

/*
 * "-q errorfile": Load the error file now.
 * If the error file can't be read, exit before doing anything else.
 */
static void handle_quickfix(mparm_T *paramp)
{
  if (paramp->edit_type == EDIT_QF) {
    if (paramp->use_ef != NULL)
      set_string_option_direct((char_u *)"ef", -1,
          paramp->use_ef, OPT_FREE, SID_CARG);
    vim_snprintf((char *)IObuff, IOSIZE, "cfile %s", p_ef);
    if (qf_init(NULL, p_ef, p_efm, TRUE, IObuff) < 0) {
      out_char('\n');
      mch_exit(3);
    }
    TIME_MSG("reading errorfile");
  }
}

/*
 * Need to jump to the tag before executing the '-c command'.
 * Makes "vim -c '/return' -t main" work.
 */
static void handle_tag(char_u *tagname)
{
  if (tagname != NULL) {
#if defined(HAS_SWAP_EXISTS_ACTION)
    swap_exists_did_quit = FALSE;
#endif

    vim_snprintf((char *)IObuff, IOSIZE, "ta %s", tagname);
    do_cmdline_cmd(IObuff);
    TIME_MSG("jumping to tag");

#if defined(HAS_SWAP_EXISTS_ACTION)
    /* If the user doesn't want to edit the file then we quit here. */
    if (swap_exists_did_quit)
      getout(1);
#endif
  }
}

/*
 * Print a warning if stdout is not a terminal.
 * When starting in Ex mode and commands come from a file, set Silent mode.
 */
static void check_tty(mparm_T *parmp)
{
  int input_isatty;                     /* is active input a terminal? */

  input_isatty = mch_input_isatty();
  if (exmode_active) {
    if (!input_isatty)
      silent_mode = TRUE;
  } else if (parmp->want_full_screen && (!parmp->stdout_isatty || !input_isatty)
      ) {
    if (!parmp->stdout_isatty)
      mch_errmsg(_("Vim: Warning: Output is not to a terminal\n"));
    if (!input_isatty)
      mch_errmsg(_("Vim: Warning: Input is not from a terminal\n"));
    out_flush();
    if (scriptin[0] == NULL)
      ui_delay(2000L, TRUE);
    TIME_MSG("Warning delay");
  }
}

/*
 * Read text from stdin.
 */
static void read_stdin(void)                 {
  int i;

#if defined(HAS_SWAP_EXISTS_ACTION)
  /* When getting the ATTENTION prompt here, use a dialog */
  swap_exists_action = SEA_DIALOG;
#endif
  no_wait_return = TRUE;
  i = msg_didany;
  set_buflisted(TRUE);
  (void)open_buffer(TRUE, NULL, 0);     /* create memfile and read file */
  no_wait_return = FALSE;
  msg_didany = i;
  TIME_MSG("reading stdin");
#if defined(HAS_SWAP_EXISTS_ACTION)
  check_swap_exists_action();
#endif
  /*
   * Close stdin and dup it from stderr.  Required for GPM to work
   * properly, and for running external commands.
   * Is there any other system that cannot do this?
   */
  close(0);
  ignored = dup(2);
}

/*
 * Create the requested number of windows and edit buffers in them.
 * Also does recovery if "recoverymode" set.
 */
static void create_windows(mparm_T *parmp)
{
  int dorewind;
  int done = 0;

  /*
   * Create the number of windows that was requested.
   */
  if (parmp->window_count == -1)        /* was not set */
    parmp->window_count = 1;
  if (parmp->window_count == 0)
    parmp->window_count = GARGCOUNT;
  if (parmp->window_count > 1) {
    /* Don't change the windows if there was a command in .vimrc that
     * already split some windows */
    if (parmp->window_layout == 0)
      parmp->window_layout = WIN_HOR;
    if (parmp->window_layout == WIN_TABS) {
      parmp->window_count = make_tabpages(parmp->window_count);
      TIME_MSG("making tab pages");
    } else if (firstwin->w_next == NULL)   {
      parmp->window_count = make_windows(parmp->window_count,
          parmp->window_layout == WIN_VER);
      TIME_MSG("making windows");
    } else
      parmp->window_count = win_count();
  } else
    parmp->window_count = 1;

  if (recoverymode) {                   /* do recover */
    msg_scroll = TRUE;                  /* scroll message up */
    ml_recover();
    if (curbuf->b_ml.ml_mfp == NULL)     /* failed */
      getout(1);
    do_modelines(0);                    /* do modelines */
  } else   {
    /*
     * Open a buffer for windows that don't have one yet.
     * Commands in the .vimrc might have loaded a file or split the window.
     * Watch out for autocommands that delete a window.
     */
    /*
     * Don't execute Win/Buf Enter/Leave autocommands here
     */
    ++autocmd_no_enter;
    ++autocmd_no_leave;
    dorewind = TRUE;
    while (done++ < 1000) {
      if (dorewind) {
        if (parmp->window_layout == WIN_TABS)
          goto_tabpage(1);
        else
          curwin = firstwin;
      } else if (parmp->window_layout == WIN_TABS)   {
        if (curtab->tp_next == NULL)
          break;
        goto_tabpage(0);
      } else   {
        if (curwin->w_next == NULL)
          break;
        curwin = curwin->w_next;
      }
      dorewind = FALSE;
      curbuf = curwin->w_buffer;
      if (curbuf->b_ml.ml_mfp == NULL) {
        /* Set 'foldlevel' to 'foldlevelstart' if it's not negative. */
        if (p_fdls >= 0)
          curwin->w_p_fdl = p_fdls;
#if defined(HAS_SWAP_EXISTS_ACTION)
        /* When getting the ATTENTION prompt here, use a dialog */
        swap_exists_action = SEA_DIALOG;
#endif
        set_buflisted(TRUE);

        /* create memfile, read file */
        (void)open_buffer(FALSE, NULL, 0);

#if defined(HAS_SWAP_EXISTS_ACTION)
        if (swap_exists_action == SEA_QUIT) {
          if (got_int || only_one_window()) {
            /* abort selected or quit and only one window */
            did_emsg = FALSE;               /* avoid hit-enter prompt */
            getout(1);
          }
          /* We can't close the window, it would disturb what
           * happens next.  Clear the file name and set the arg
           * index to -1 to delete it later. */
          setfname(curbuf, NULL, NULL, FALSE);
          curwin->w_arg_idx = -1;
          swap_exists_action = SEA_NONE;
        } else
          handle_swap_exists(NULL);
#endif
        dorewind = TRUE;                        /* start again */
      }
      ui_breakcheck();
      if (got_int) {
        (void)vgetc();          /* only break the file loading, not the rest */
        break;
      }
    }
    if (parmp->window_layout == WIN_TABS)
      goto_tabpage(1);
    else
      curwin = firstwin;
    curbuf = curwin->w_buffer;
    --autocmd_no_enter;
    --autocmd_no_leave;
  }
}

/*
 * If opened more than one window, start editing files in the other
 * windows.  make_windows() has already opened the windows.
 */
static void edit_buffers(mparm_T *parmp)
{
  int arg_idx;                          /* index in argument list */
  int i;
  int advance = TRUE;
  win_T       *win;

  /*
   * Don't execute Win/Buf Enter/Leave autocommands here
   */
  ++autocmd_no_enter;
  ++autocmd_no_leave;

  /* When w_arg_idx is -1 remove the window (see create_windows()). */
  if (curwin->w_arg_idx == -1) {
    win_close(curwin, TRUE);
    advance = FALSE;
  }

  arg_idx = 1;
  for (i = 1; i < parmp->window_count; ++i) {
    /* When w_arg_idx is -1 remove the window (see create_windows()). */
    if (curwin->w_arg_idx == -1) {
      ++arg_idx;
      win_close(curwin, TRUE);
      advance = FALSE;
      continue;
    }

    if (advance) {
      if (parmp->window_layout == WIN_TABS) {
        if (curtab->tp_next == NULL)            /* just checking */
          break;
        goto_tabpage(0);
      } else   {
        if (curwin->w_next == NULL)             /* just checking */
          break;
        win_enter(curwin->w_next, FALSE);
      }
    }
    advance = TRUE;

    /* Only open the file if there is no file in this window yet (that can
     * happen when .vimrc contains ":sall"). */
    if (curbuf == firstwin->w_buffer || curbuf->b_ffname == NULL) {
      curwin->w_arg_idx = arg_idx;
      /* Edit file from arg list, if there is one.  When "Quit" selected
       * at the ATTENTION prompt close the window. */
# ifdef HAS_SWAP_EXISTS_ACTION
      swap_exists_did_quit = FALSE;
# endif
      (void)do_ecmd(0, arg_idx < GARGCOUNT
          ? alist_name(&GARGLIST[arg_idx]) : NULL,
          NULL, NULL, ECMD_LASTL, ECMD_HIDE, curwin);
# ifdef HAS_SWAP_EXISTS_ACTION
      if (swap_exists_did_quit) {
        /* abort or quit selected */
        if (got_int || only_one_window()) {
          /* abort selected and only one window */
          did_emsg = FALSE;             /* avoid hit-enter prompt */
          getout(1);
        }
        win_close(curwin, TRUE);
        advance = FALSE;
      }
# endif
      if (arg_idx == GARGCOUNT - 1)
        arg_had_last = TRUE;
      ++arg_idx;
    }
    ui_breakcheck();
    if (got_int) {
      (void)vgetc();            /* only break the file loading, not the rest */
      break;
    }
  }

  if (parmp->window_layout == WIN_TABS)
    goto_tabpage(1);
  --autocmd_no_enter;

  /* make the first window the current window */
  win = firstwin;
  /* Avoid making a preview window the current window. */
  while (win->w_p_pvw) {
    win = win->w_next;
    if (win == NULL) {
      win = firstwin;
      break;
    }
  }
  win_enter(win, FALSE);

  --autocmd_no_leave;
  TIME_MSG("editing files in windows");
  if (parmp->window_count > 1 && parmp->window_layout != WIN_TABS)
    win_equal(curwin, FALSE, 'b');      /* adjust heights */
}

/*
 * Execute the commands from --cmd arguments "cmds[cnt]".
 */
static void exe_pre_commands(mparm_T *parmp)
{
  char_u      **cmds = parmp->pre_commands;
  int cnt = parmp->n_pre_commands;
  int i;

  if (cnt > 0) {
    curwin->w_cursor.lnum = 0;     /* just in case.. */
    sourcing_name = (char_u *)_("pre-vimrc command line");
    current_SID = SID_CMDARG;
    for (i = 0; i < cnt; ++i)
      do_cmdline_cmd(cmds[i]);
    sourcing_name = NULL;
    current_SID = 0;
    TIME_MSG("--cmd commands");
  }
}

/*
 * Execute "+", "-c" and "-S" arguments.
 */
static void exe_commands(mparm_T *parmp)
{
  int i;

  /*
   * We start commands on line 0, make "vim +/pat file" match a
   * pattern on line 1.  But don't move the cursor when an autocommand
   * with g`" was used.
   */
  msg_scroll = TRUE;
  if (parmp->tagname == NULL && curwin->w_cursor.lnum <= 1)
    curwin->w_cursor.lnum = 0;
  sourcing_name = (char_u *)"command line";
  current_SID = SID_CARG;
  for (i = 0; i < parmp->n_commands; ++i) {
    do_cmdline_cmd(parmp->commands[i]);
    if (parmp->cmds_tofree[i])
      vim_free(parmp->commands[i]);
  }
  sourcing_name = NULL;
  current_SID = 0;
  if (curwin->w_cursor.lnum == 0)
    curwin->w_cursor.lnum = 1;

  if (!exmode_active)
    msg_scroll = FALSE;

  /* When started with "-q errorfile" jump to first error again. */
  if (parmp->edit_type == EDIT_QF)
    qf_jump(NULL, 0, 0, FALSE);
  TIME_MSG("executing command arguments");
}

/*
 * Source startup scripts.
 */
static void source_startup_scripts(mparm_T *parmp)
{
  int i;

  /*
   * For "evim" source evim.vim first of all, so that the user can overrule
   * any things he doesn't like.
   */
  if (parmp->evim_mode) {
    (void)do_source((char_u *)EVIM_FILE, FALSE, DOSO_NONE);
    TIME_MSG("source evim file");
  }

  /*
   * If -u argument given, use only the initializations from that file and
   * nothing else.
   */
  if (parmp->use_vimrc != NULL) {
    if (STRCMP(parmp->use_vimrc, "NONE") == 0
        || STRCMP(parmp->use_vimrc, "NORC") == 0) {
      if (parmp->use_vimrc[2] == 'N')
        p_lpl = FALSE;                      /* don't load plugins either */
    } else   {
      if (do_source(parmp->use_vimrc, FALSE, DOSO_NONE) != OK)
        EMSG2(_("E282: Cannot read from \"%s\""), parmp->use_vimrc);
    }
  } else if (!silent_mode)   {

    /*
     * Get system wide defaults, if the file name is defined.
     */
#ifdef SYS_VIMRC_FILE
    (void)do_source((char_u *)SYS_VIMRC_FILE, FALSE, DOSO_NONE);
#endif

    /*
     * Try to read initialization commands from the following places:
     * - environment variable VIMINIT
     * - user vimrc file (s:.vimrc for Amiga, ~/.vimrc otherwise)
     * - second user vimrc file ($VIM/.vimrc for Dos)
     * - environment variable EXINIT
     * - user exrc file (s:.exrc for Amiga, ~/.exrc otherwise)
     * - second user exrc file ($VIM/.exrc for Dos)
     * The first that exists is used, the rest is ignored.
     */
    if (process_env((char_u *)"VIMINIT", TRUE) != OK) {
      if (do_source((char_u *)USR_VIMRC_FILE, TRUE, DOSO_VIMRC) == FAIL
#ifdef USR_VIMRC_FILE2
          && do_source((char_u *)USR_VIMRC_FILE2, TRUE,
            DOSO_VIMRC) == FAIL
#endif
#ifdef USR_VIMRC_FILE3
          && do_source((char_u *)USR_VIMRC_FILE3, TRUE,
            DOSO_VIMRC) == FAIL
#endif
#ifdef USR_VIMRC_FILE4
          && do_source((char_u *)USR_VIMRC_FILE4, TRUE,
            DOSO_VIMRC) == FAIL
#endif
          && process_env((char_u *)"EXINIT", FALSE) == FAIL
          && do_source((char_u *)USR_EXRC_FILE, FALSE, DOSO_NONE) == FAIL) {
#ifdef USR_EXRC_FILE2
        (void)do_source((char_u *)USR_EXRC_FILE2, FALSE, DOSO_NONE);
#endif
      }
    }

    /*
     * Read initialization commands from ".vimrc" or ".exrc" in current
     * directory.  This is only done if the 'exrc' option is set.
     * Because of security reasons we disallow shell and write commands
     * now, except for unix if the file is owned by the user or 'secure'
     * option has been reset in environment of global ".exrc" or ".vimrc".
     * Only do this if VIMRC_FILE is not the same as USR_VIMRC_FILE or
     * SYS_VIMRC_FILE.
     */
    if (p_exrc) {
#if defined(UNIX) || defined(VMS)
      /* If ".vimrc" file is not owned by user, set 'secure' mode. */
      if (!file_owned(VIMRC_FILE))
#endif
        secure = p_secure;

      i = FAIL;
      if (fullpathcmp((char_u *)USR_VIMRC_FILE,
            (char_u *)VIMRC_FILE, FALSE) != FPC_SAME
#ifdef USR_VIMRC_FILE2
          && fullpathcmp((char_u *)USR_VIMRC_FILE2,
            (char_u *)VIMRC_FILE, FALSE) != FPC_SAME
#endif
#ifdef USR_VIMRC_FILE3
          && fullpathcmp((char_u *)USR_VIMRC_FILE3,
            (char_u *)VIMRC_FILE, FALSE) != FPC_SAME
#endif
#ifdef SYS_VIMRC_FILE
          && fullpathcmp((char_u *)SYS_VIMRC_FILE,
            (char_u *)VIMRC_FILE, FALSE) != FPC_SAME
#endif
         )
        i = do_source((char_u *)VIMRC_FILE, TRUE, DOSO_VIMRC);

      if (i == FAIL) {
#if defined(UNIX) || defined(VMS)
        /* if ".exrc" is not owned by user set 'secure' mode */
        if (!file_owned(EXRC_FILE))
          secure = p_secure;
        else
          secure = 0;
#endif
        if (       fullpathcmp((char_u *)USR_EXRC_FILE,
              (char_u *)EXRC_FILE, FALSE) != FPC_SAME
#ifdef USR_EXRC_FILE2
            && fullpathcmp((char_u *)USR_EXRC_FILE2,
              (char_u *)EXRC_FILE, FALSE) != FPC_SAME
#endif
           )
          (void)do_source((char_u *)EXRC_FILE, FALSE, DOSO_NONE);
      }
    }
    if (secure == 2)
      need_wait_return = TRUE;
    secure = 0;
  }
  TIME_MSG("sourcing vimrc file(s)");
}

/*
 * Setup to start using the GUI.  Exit with an error when not available.
 */
static void main_start_gui(void)                 {
  mch_errmsg(_(e_nogvim));
  mch_errmsg("\n");
  mch_exit(2);
}

#endif /* NO_VIM_MAIN */

/*
 * Get an environment variable, and execute it as Ex commands.
 * Returns FAIL if the environment variable was not executed, OK otherwise.
 */
int 
process_env (
    char_u *env,
    int is_viminit             /* when TRUE, called for VIMINIT */
)
{
  char_u      *initstr;
  char_u      *save_sourcing_name;
  linenr_T save_sourcing_lnum;
  scid_T save_sid;

  if ((initstr = mch_getenv(env)) != NULL && *initstr != NUL) {
    if (is_viminit)
      vimrc_found(NULL, NULL);
    save_sourcing_name = sourcing_name;
    save_sourcing_lnum = sourcing_lnum;
    sourcing_name = env;
    sourcing_lnum = 0;
    save_sid = current_SID;
    current_SID = SID_ENV;
    do_cmdline_cmd(initstr);
    sourcing_name = save_sourcing_name;
    sourcing_lnum = save_sourcing_lnum;
    current_SID = save_sid;;
    return OK;
  }
  return FAIL;
}

#if (defined(UNIX) || defined(VMS)) && !defined(NO_VIM_MAIN)
/*
 * Return TRUE if we are certain the user owns the file "fname".
 * Used for ".vimrc" and ".exrc".
 * Use both stat() and lstat() for extra security.
 */
static int file_owned(char *fname)
{
  struct stat s;
# ifdef UNIX
  uid_t uid = getuid();
# else   /* VMS */
  uid_t uid = ((getgid() << 16) | getuid());
# endif

  return !(mch_stat(fname, &s) != 0 || s.st_uid != uid
# ifdef HAVE_LSTAT
      || mch_lstat(fname, &s) != 0 || s.st_uid != uid
# endif
      );
}
#endif

/*
 * Give an error message main_errors["n"] and exit.
 */
static void 
mainerr (
    int n,                  /* one of the ME_ defines */
    char_u *str       /* extra argument or NULL */
)
{
#if defined(UNIX) || defined(__EMX__) || defined(VMS)
  reset_signals();              /* kill us with CTRL-C here, if you like */
#endif

  mch_errmsg(longVersion);
  mch_errmsg("\n");
  mch_errmsg(_(main_errors[n]));
  if (str != NULL) {
    mch_errmsg(": \"");
    mch_errmsg((char *)str);
    mch_errmsg("\"");
  }
  mch_errmsg(_("\nMore info with: \"vim -h\"\n"));

  mch_exit(1);
}

void mainerr_arg_missing(char_u *str)
{
  mainerr(ME_ARG_MISSING, str);
}

#ifndef NO_VIM_MAIN
/*
 * print a message with three spaces prepended and '\n' appended.
 */
static void main_msg(char *s)
{
  mch_msg("   ");
  mch_msg(s);
  mch_msg("\n");
}

/*
 * Print messages for "vim -h" or "vim --help" and exit.
 */
static void usage(void)                 {
  int i;
  static char *(use[]) =
  {
    N_("[file ..]       edit specified file(s)"),
    N_("-               read text from stdin"),
    N_("-t tag          edit file where tag is defined"),
    N_("-q [errorfile]  edit file with first error")
  };

#if defined(UNIX) || defined(__EMX__) || defined(VMS)
  reset_signals();              /* kill us with CTRL-C here, if you like */
#endif

  mch_msg(longVersion);
  mch_msg(_("\n\nusage:"));
  for (i = 0;; ++i) {
    mch_msg(_(" vim [arguments] "));
    mch_msg(_(use[i]));
    if (i == (sizeof(use) / sizeof(char_u *)) - 1)
      break;
    mch_msg(_("\n   or:"));
  }

  mch_msg(_("\n\nArguments:\n"));
  main_msg(_("--\t\t\tOnly file names after this"));
#if (!defined(UNIX) && !defined(__EMX__)) || defined(ARCHIE)
  main_msg(_("--literal\t\tDon't expand wildcards"));
#endif
#ifdef FEAT_OLE
  main_msg(_("-register\t\tRegister this gvim for OLE"));
  main_msg(_("-unregister\t\tUnregister gvim for OLE"));
#endif
  main_msg(_("-v\t\t\tVi mode (like \"vi\")"));
  main_msg(_("-e\t\t\tEx mode (like \"ex\")"));
  main_msg(_("-E\t\t\tImproved Ex mode"));
  main_msg(_("-s\t\t\tSilent (batch) mode (only for \"ex\")"));
  main_msg(_("-d\t\t\tDiff mode (like \"vimdiff\")"));
  main_msg(_("-y\t\t\tEasy mode (like \"evim\", modeless)"));
  main_msg(_("-R\t\t\tReadonly mode (like \"view\")"));
  main_msg(_("-Z\t\t\tRestricted mode (like \"rvim\")"));
  main_msg(_("-m\t\t\tModifications (writing files) not allowed"));
  main_msg(_("-M\t\t\tModifications in text not allowed"));
  main_msg(_("-b\t\t\tBinary mode"));
  main_msg(_("-l\t\t\tLisp mode"));
  main_msg(_("-C\t\t\tCompatible with Vi: 'compatible'"));
  main_msg(_("-N\t\t\tNot fully Vi compatible: 'nocompatible'"));
  main_msg(_("-V[N][fname]\t\tBe verbose [level N] [log messages to fname]"));
  main_msg(_("-D\t\t\tDebugging mode"));
  main_msg(_("-n\t\t\tNo swap file, use memory only"));
  main_msg(_("-r\t\t\tList swap files and exit"));
  main_msg(_("-r (with file name)\tRecover crashed session"));
  main_msg(_("-L\t\t\tSame as -r"));
  main_msg(_("-A\t\t\tstart in Arabic mode"));
  main_msg(_("-H\t\t\tStart in Hebrew mode"));
  main_msg(_("-F\t\t\tStart in Farsi mode"));
  main_msg(_("-T <terminal>\tSet terminal type to <terminal>"));
  main_msg(_("-u <vimrc>\t\tUse <vimrc> instead of any .vimrc"));
  main_msg(_("--noplugin\t\tDon't load plugin scripts"));
  main_msg(_("-p[N]\t\tOpen N tab pages (default: one for each file)"));
  main_msg(_("-o[N]\t\tOpen N windows (default: one for each file)"));
  main_msg(_("-O[N]\t\tLike -o but split vertically"));
  main_msg(_("+\t\t\tStart at end of file"));
  main_msg(_("+<lnum>\t\tStart at line <lnum>"));
  main_msg(_("--cmd <command>\tExecute <command> before loading any vimrc file"));
  main_msg(_("-c <command>\t\tExecute <command> after loading the first file"));
  main_msg(_(
        "-S <session>\t\tSource file <session> after loading the first file"));
  main_msg(_("-s <scriptin>\tRead Normal mode commands from file <scriptin>"));
  main_msg(_("-w <scriptout>\tAppend all typed commands to file <scriptout>"));
  main_msg(_("-W <scriptout>\tWrite all typed commands to file <scriptout>"));
  main_msg(_("-x\t\t\tEdit encrypted files"));
#ifdef STARTUPTIME
  main_msg(_("--startuptime <file>\tWrite startup timing messages to <file>"));
#endif
  main_msg(_("-i <viminfo>\t\tUse <viminfo> instead of .viminfo"));
  main_msg(_("-h  or  --help\tPrint Help (this message) and exit"));
  main_msg(_("--version\t\tPrint version information and exit"));


  mch_exit(0);
}

#if defined(HAS_SWAP_EXISTS_ACTION)
/*
 * Check the result of the ATTENTION dialog:
 * When "Quit" selected, exit Vim.
 * When "Recover" selected, recover the file.
 */
static void check_swap_exists_action(void)                 {
  if (swap_exists_action == SEA_QUIT)
    getout(1);
  handle_swap_exists(NULL);
}

#endif

#endif

#if defined(STARTUPTIME) || defined(PROTO)
static void time_diff(struct timeval *then, struct timeval *now);

static struct timeval prev_timeval;


/*
 * Save the previous time before doing something that could nest.
 * set "*tv_rel" to the time elapsed so far.
 */
void time_push(void *tv_rel, void *tv_start)
{
  *((struct timeval *)tv_rel) = prev_timeval;
  gettimeofday(&prev_timeval, NULL);
  ((struct timeval *)tv_rel)->tv_usec = prev_timeval.tv_usec
    - ((struct timeval *)tv_rel)->tv_usec;
  ((struct timeval *)tv_rel)->tv_sec = prev_timeval.tv_sec
    - ((struct timeval *)tv_rel)->tv_sec;
  if (((struct timeval *)tv_rel)->tv_usec < 0) {
    ((struct timeval *)tv_rel)->tv_usec += 1000000;
    --((struct timeval *)tv_rel)->tv_sec;
  }
  *(struct timeval *)tv_start = prev_timeval;
}

/*
 * Compute the previous time after doing something that could nest.
 * Subtract "*tp" from prev_timeval;
 * Note: The arguments are (void *) to avoid trouble with systems that don't
 * have struct timeval.
 */
void 
time_pop (
    void *tp        /* actually (struct timeval *) */
)
{
  prev_timeval.tv_usec -= ((struct timeval *)tp)->tv_usec;
  prev_timeval.tv_sec -= ((struct timeval *)tp)->tv_sec;
  if (prev_timeval.tv_usec < 0) {
    prev_timeval.tv_usec += 1000000;
    --prev_timeval.tv_sec;
  }
}

static void time_diff(struct timeval *then, struct timeval *now)
{
  long usec;
  long msec;

  usec = now->tv_usec - then->tv_usec;
  msec = (now->tv_sec - then->tv_sec) * 1000L + usec / 1000L,
       usec = usec % 1000L;
  fprintf(time_fd, "%03ld.%03ld", msec, usec >= 0 ? usec : usec + 1000L);
}

void 
time_msg (
    char *mesg,
    void *tv_start      /* only for do_source: start time; actually
                                 (struct timeval *) */
)
{
  static struct timeval start;
  struct timeval now;

  if (time_fd != NULL) {
    if (strstr(mesg, "STARTING") != NULL) {
      gettimeofday(&start, NULL);
      prev_timeval = start;
      fprintf(time_fd, "\n\ntimes in msec\n");
      fprintf(time_fd, " clock   self+sourced   self:  sourced script\n");
      fprintf(time_fd, " clock   elapsed:              other lines\n\n");
    }
    gettimeofday(&now, NULL);
    time_diff(&start, &now);
    if (((struct timeval *)tv_start) != NULL) {
      fprintf(time_fd, "  ");
      time_diff(((struct timeval *)tv_start), &now);
    }
    fprintf(time_fd, "  ");
    time_diff(&prev_timeval, &now);
    prev_timeval = now;
    fprintf(time_fd, ": %s\n", mesg);
  }
}

#endif



/*
 * When FEAT_FKMAP is defined, also compile the Farsi source code.
 */
# include "farsi.c"

/*
 * When FEAT_ARABIC is defined, also compile the Arabic source code.
 */
# include "arabic.c"
