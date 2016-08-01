#define EXTERN
#include <assert.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>

#include <msgpack.h>

#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/diff.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/hashtab.h"
#include "nvim/iconv.h"
#include "nvim/if_cscope.h"
#ifdef HAVE_LOCALE_H
# include <locale.h>
#endif
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/garray.h"
#include "nvim/log.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/mouse.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/profile.h"
#include "nvim/quickfix.h"
#include "nvim/screen.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/version.h"
#include "nvim/window.h"
#include "nvim/shada.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/event/loop.h"
#include "nvim/os/signal.h"
#include "nvim/event/process.h"
#include "nvim/msgpack_rpc/defs.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/msgpack_rpc/server.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/handle.h"

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

  char *use_vimrc;                           // vimrc from -u argument

  int n_commands;                            /* no. of commands from + or -c */
  char *commands[MAX_ARG_CMDS];              // commands from + or -c arg
  char_u cmds_tofree[MAX_ARG_CMDS];          /* commands that need free() */
  int n_pre_commands;                        /* no. of commands from --cmd */
  char *pre_commands[MAX_ARG_CMDS];          // commands from --cmd argument

  int edit_type;                        /* type of editing to do */
  char_u      *tagname;                 /* tag from -t argument */
  char_u      *use_ef;                  /* 'errorfile' from -q argument */

  int want_full_screen;
  bool input_isatty;                    // stdin is a terminal
  bool output_isatty;                   // stdout is a terminal
  bool err_isatty;                      // stderr is a terminal
  bool headless;                        // Dont try to start an user interface
                                        // or read/write to stdio(unless
                                        // embedding)
  int no_swap_file;                     /* "-n" argument used */
  int use_debug_break_level;
  int window_count;                     /* number of windows to use */
  int window_layout;                    /* 0, WIN_HOR, WIN_VER or WIN_TABS */

#if !defined(UNIX)
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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "main.c.generated.h"
#endif

Loop main_loop;

static char *argv0;

// Error messages
static const char *err_arg_missing = N_("Argument missing after");
static const char *err_opt_garbage = N_("Garbage after option argument");
static const char *err_opt_unknown = N_("Unknown option argument");
static const char *err_too_many_args = N_("Too many edit arguments");
static const char *err_extra_cmd =
  N_("Too many \"+command\", \"-c command\" or \"--cmd command\" arguments");


void event_init(void)
{
  loop_init(&main_loop, NULL);
  // early msgpack-rpc initialization
  msgpack_rpc_init_method_table();
  msgpack_rpc_helpers_init();
  // Initialize input events
  input_init();
  // Timer to wake the event loop if a timeout argument is passed to
  // `event_poll`
  // Signals
  signal_init();
  // finish mspgack-rpc initialization
  channel_init();
  server_init();
  terminal_init();
}

void event_teardown(void)
{
  if (!main_loop.events) {
    return;
  }

  queue_process_events(main_loop.events);
  input_stop();
  channel_teardown();
  process_teardown(&main_loop);
  timer_teardown();
  server_teardown();
  signal_teardown();
  terminal_teardown();

  loop_close(&main_loop);
}

/// Performs early initialization.
///
/// Needed for unit tests. Must be called after `time_init()`.
void early_init(void)
{
  log_init();
  fs_init();
  handle_init();

  (void)mb_init();      // init mb_bytelen_tab[] to ones
  eval_init();          // init global variables

  // Init the table of Normal mode commands.
  init_normal_cmds();

#if defined(HAVE_LOCALE_H)
  // Setup to use the current locale (for ctype() and many other things).
  // NOTE: Translated messages with encodings other than latin1 will not
  // work until set_init_1() has been called!
  init_locale();
#endif

  // Allocate the first window and buffer.
  // Can't do anything without it, exit when it fails.
  if (!win_alloc_first()) {
    mch_exit(0);
  }

  init_yank();                  // init yank buffers

  alist_init(&global_alist);    // Init the argument list to empty.
  global_alist.id = 0;

  // Set the default values for the options.
  // NOTE: Non-latin1 translated messages are working only after this,
  // because this is where "has_mbyte" will be set, which is used by
  // msg_outtrans_len_attr().
  // First find out the home directory, needed to expand "~" in options.
  init_homedir();               // find real value of $HOME
  set_init_1();
  TIME_MSG("inits 1");

  set_lang_var();               // set v:lang and v:ctype
}

#ifdef MAKE_LIB
int nvim_main(int argc, char **argv)
#else
int main(int argc, char **argv)
#endif
{
  argv0 = (char *)path_tail((char_u *)argv[0]);

  char_u *fname = NULL;   // file name from command line
  mparm_T params;         // various parameters passed between
                          // main() and other functions.
  char_u *cwd = NULL;     // current workding dir on startup
  time_init();

  /* Many variables are in "params" so that we can pass them to invoked
   * functions without a lot of arguments.  "argc" and "argv" are also
   * copied, so that they can be changed. */
  init_params(&params, argc, argv);

  init_startuptime(&params);

  early_init();

  // Check if we have an interactive window.
  check_and_set_isatty(&params);

  // Get the name with which Nvim was invoked, with and without path.
  set_vim_var_string(VV_PROGPATH, argv[0], -1);
  set_vim_var_string(VV_PROGNAME, (char *) path_tail((char_u *) argv[0]), -1);

  event_init();
  /*
   * Process the command line arguments.  File names are put in the global
   * argument list "global_alist".
   */
  command_line_scan(&params);

  if (GARGCOUNT > 0) {
    fname = get_fname(&params, cwd);
  }

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

  setbuf(stdout, NULL);

  /* This message comes before term inits, but after setting "silent_mode"
   * when the input is not a tty. */
  if (GARGCOUNT > 1 && !silent_mode)
    printf(_("%d files to edit\n"), GARGCOUNT);

  full_screen = true;
  check_tty(&params);

  /*
   * Set the default values for the options that use Rows and Columns.
   */
  win_init_size();
  // Set the 'diff' option now, so that it can be checked for in a vimrc
  // file.  There is no buffer yet though.
  if (params.diff_mode)
    diff_win_options(firstwin, FALSE);

  assert(p_ch >= 0 && Rows >= p_ch && Rows - p_ch <= INT_MAX);
  cmdline_row = (int)(Rows - p_ch);
  msg_row = cmdline_row;
  screenalloc(false);           /* allocate screen buffers */
  set_init_2();
  TIME_MSG("inits 2");

  msg_scroll = TRUE;
  no_wait_return = TRUE;

  init_highlight(TRUE, FALSE);   /* set the default highlight groups */
  TIME_MSG("init highlight");

  /* Set the break level after the terminal is initialized. */
  debug_break_level = params.use_debug_break_level;

  bool reading_input = !params.headless && (params.input_isatty
      || params.output_isatty || params.err_isatty);

  if (reading_input) {
    // One of the startup commands (arguments, sourced scripts or plugins) may
    // prompt the user, so start reading from a tty now.
    int fd = fileno(stdin);
    if (!params.input_isatty || params.edit_type == EDIT_STDIN) {
      // Use stderr or stdout since stdin is not a tty and/or could be used to
      // read the "-" file (eg: cat file | nvim -)
      fd = params.err_isatty ? fileno(stderr) : fileno(stdout);
    }
    input_start(fd);
  }

  // open terminals when opening files that start with term://
#define PROTO "term://"
  do_cmdline_cmd("autocmd BufReadCmd " PROTO "* nested "
                 ":call termopen( "
                 // Capture the command string
                 "matchstr(expand(\"<amatch>\"), "
                 "'\\c\\m" PROTO "\\%(.\\{-}//\\%(\\d\\+:\\)\\?\\)\\?\\zs.*'), "
                 // capture the working directory
                 "{'cwd': get(matchlist(expand(\"<amatch>\"), "
                 "'\\c\\m" PROTO "\\(.\\{-}\\)//'), 1, '')})");
#undef PROTO

  /* Execute --cmd arguments. */
  exe_pre_commands(&params);

  /* Source startup scripts. */
  source_startup_scripts(&params);

  // If using the runtime (-u is not NONE), enable syntax & filetype plugins.
  if (params.use_vimrc == NULL || strcmp(params.use_vimrc, "NONE") != 0) {
    // Does ":filetype plugin indent on".
    filetype_maybe_enable();
    // Sources syntax/syntax.vim, which calls `:filetype on`.
    syn_maybe_on();
  }

  /*
   * Read all the plugin files.
   * Only when compiled with +eval, since most plugins need it.
   */
  load_plugins();

  // Decide about window layout for diff mode after reading vimrc.
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

  // Set a few option defaults after reading vimrc files:
  // 'title' and 'icon', Unix: 'shellpipe' and 'shellredir'.
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
   * Read in registers, history etc, from the ShaDa file.
   * This is where v:oldfiles gets filled.
   */
  if (*p_shada != NUL) {
    shada_read_everything(NULL, false, true);
    TIME_MSG("reading ShaDa");
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


  if (reading_input && (need_wait_return || msg_didany)) {
    // Since at this point there's no UI instance running yet, error messages
    // would have been printed to stdout. Before starting (which can result in
    // a alternate screen buffer being shown) we need confirmation that the
    // user has seen the messages and that is done with a call to wait_return.
    TIME_MSG("waiting for return");
    wait_return(TRUE);
  }

  if (!params.headless) {
    // Stop reading from input stream, the UI layer will take over now.
    input_stop();
    ui_builtin_start();
  }

  setmouse();  // may start using the mouse
  ui_reset_scroll_region();  // In case Rows changed

  // Don't clear the screen when starting in Ex mode, unless using the GUI.
  if (exmode_active)
    must_redraw = CLEAR;
  else {
    screenclear();                        /* clear screen */
    TIME_MSG("clearing screen");
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

  // If opened more than one window, start editing files in the other
  // windows.
  edit_buffers(&params, cwd);
  xfree(cwd);

  if (params.diff_mode) {
    /* set options in each window for "nvim -d". */
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      diff_win_options(wp, TRUE);
    }
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

  // 'autochdir' has been postponed.
  do_autochdir();

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

  // WORKAROUND(mhi): #3023
  if (cb_flags & CB_UNNAMEDMASK) {
    (void)eval_has_provider("clipboard");
  }

  TIME_MSG("before starting main loop");
  ILOG("Starting Neovim main loop.");

  /*
   * Call the main command loop.  This never returns.
   */
  normal_enter(false, false);

  return 0;
}

/* Exit properly */
void getout(int exitval)
{
  tabpage_T   *tp, *next_tp;

  exiting = TRUE;

  /* When running in Ex mode an error causes us to exit with a non-zero exit
   * code.  POSIX requires this, although it's not 100% clear from the
   * standard. */
  if (exmode_active)
    exitval += ex_exitval;

  /* Position the cursor on the last screen line, below all the text */
  ui_cursor_goto((int)Rows - 1, 0);

  /* Optionally print hashtable efficiency. */
  hash_debug_results();

  if (get_vim_var_nr(VV_DYING) <= 1) {
    /* Trigger BufWinLeave for all windows, but only once per buffer. */
    for (tp = first_tabpage; tp != NULL; tp = next_tp) {
      next_tp = tp->tp_next;
      FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
        if (wp->w_buffer == NULL) {
          /* Autocmd must have close the buffer already, skip. */
          continue;
        }

        buf_T *buf = wp->w_buffer;
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
    FOR_ALL_BUFFERS(buf) {
      if (buf->b_ml.ml_mfp != NULL) {
        apply_autocmds(EVENT_BUFUNLOAD, buf->b_fname, buf->b_fname,
            FALSE, buf);
        if (!buf_valid(buf))            /* autocmd may delete the buffer */
          break;
      }
    }
    apply_autocmds(EVENT_VIMLEAVEPRE, NULL, NULL, FALSE, curbuf);
  }

  if (p_shada && *p_shada != NUL) {
    // Write out the registers, history, marks etc, to the ShaDa file
    shada_write_file(NULL, false);
  }

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
  ui_cursor_goto((int)Rows - 1, 0);

#if defined(USE_ICONV) && defined(DYNAMIC_ICONV)
  iconv_end();
#endif
  cs_end();
  if (garbage_collect_at_exit)
    garbage_collect();

  mch_exit(exitval);
}

/// Gets the integer value of a numeric command line argument if given,
/// such as '-o10'.
///
/// @param[in] p         pointer to argument
/// @param[in, out] idx  pointer to index in argument, is incremented
/// @param[in] def       default value
///
/// @return def unmodified if:
///   - argument isn't given
///   - argument is non-numeric
///
/// @return argument's numeric value otherwise
static int get_number_arg(const char *p, int *idx, int def)
{
  if (ascii_isdigit(p[*idx])) {
    def = atoi(&(p[*idx]));
    while (ascii_isdigit(p[*idx])) {
      *idx = *idx + 1;
    }
  }
  return def;
}

#if defined(HAVE_LOCALE_H)
/*
 * Setup to use the current locale (for ctype() and many other things).
 */
static void init_locale(void)
{
  setlocale(LC_ALL, "");

# ifdef LC_NUMERIC
  /* Make sure strtod() uses a decimal point, not a comma. */
  setlocale(LC_NUMERIC, "C");
# endif

# ifdef LOCALE_INSTALL_DIR    // gnu/linux standard: $prefix/share/locale
  bindtextdomain(PROJECT_NAME, LOCALE_INSTALL_DIR);
# else                        // old vim style: $runtime/lang
  {
    char_u  *p;

    // expand_env() doesn't work yet, because g_chartab[] is not
    // initialized yet, call vim_getenv() directly
    p = (char_u *)vim_getenv("VIMRUNTIME");
    if (p != NULL && *p != NUL) {
      vim_snprintf((char *)NameBuff, MAXPATHL, "%s/lang", p);
      bindtextdomain(PROJECT_NAME, (char *)NameBuff);
    }
    xfree(p);
  }
# endif
  textdomain(PROJECT_NAME);
  TIME_MSG("locale set");
}
#endif


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
        mainerr(err_extra_cmd, NULL);
      argv_idx = -1;                /* skip to next argument */
      if (argv[0][1] == NUL)
        parmp->commands[parmp->n_commands++] = "$";
      else
        parmp->commands[parmp->n_commands++] = &(argv[0][1]);
    }
    /*
     * Optional argument.
     */
    else if (argv[0][0] == '-' && !had_minmin) {
      want_argument = FALSE;
      c = argv[0][argv_idx++];
      switch (c) {
        case NUL:                 /* "vim -"  read from stdin */
          if (exmode_active) {
            // "ex -" silent mode
            silent_mode = TRUE;
          } else {
            if (parmp->edit_type != EDIT_NONE) {
              mainerr(err_too_many_args, argv[0]);
            }
            parmp->edit_type = EDIT_STDIN;
          }
          argv_idx = -1;                  /* skip to next argument */
          break;

        case '-':                 /* "--" don't take any more option arguments */
          /* "--help" give help message */
          /* "--version" give version message */
          /* "--literal" take files literally */
          /* "--noplugin[s]" skip plugins */
          /* "--cmd <cmd>" execute cmd before vimrc */
          if (STRICMP(argv[0] + argv_idx, "help") == 0) {
            usage();
            mch_exit(0);
          } else if (STRICMP(argv[0] + argv_idx, "version") == 0) {
            version();
            mch_exit(0);
          } else if (STRICMP(argv[0] + argv_idx, "api-info") == 0) {
            msgpack_sbuffer* b = msgpack_sbuffer_new();
            msgpack_packer* p = msgpack_packer_new(b, msgpack_sbuffer_write);
            Object md = DICTIONARY_OBJ(api_metadata());
            msgpack_rpc_from_object(md, p);

            for (size_t i = 0; i < b->size; i++) {
              putchar(b->data[i]);
            }

            msgpack_packer_free(p);
            mch_exit(0);
          } else if (STRICMP(argv[0] + argv_idx, "headless") == 0) {
            parmp->headless = true;
          } else if (STRICMP(argv[0] + argv_idx, "embed") == 0) {
            embedded_mode = true;
            parmp->headless = true;
            channel_from_stdio();
          } else if (STRNICMP(argv[0] + argv_idx, "literal", 7) == 0) {
#if !defined(UNIX)
            parmp->literal = TRUE;
#endif
          } else if (STRNICMP(argv[0] + argv_idx, "noplugin", 8) == 0)
            p_lpl = FALSE;
          else if (STRNICMP(argv[0] + argv_idx, "cmd", 3) == 0) {
            want_argument = TRUE;
            argv_idx += 3;
          } else if (STRNICMP(argv[0] + argv_idx, "startuptime", 11) == 0) {
            want_argument = TRUE;
            argv_idx += 11;
          } else {
            if (argv[0][argv_idx])
              mainerr(err_opt_unknown, argv[0]);
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

        case 'e':                 /* "-e" Ex mode */
          exmode_active = EXMODE_NORMAL;
          break;

        case 'E':                 /* "-E" Improved Ex mode */
          exmode_active = EXMODE_VIM;
          break;

        case 'f':                 /* "-f"  GUI: run in foreground. */
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
          mch_exit(0);

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

        case 'N':                 /* "-N"  Nocompatible */
          /* No-op */
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
          parmp->window_count = get_number_arg(argv[0], &argv_idx, 0);
          parmp->window_layout = WIN_TABS;
          break;

        case 'o':                 /* "-o[N]" open N horizontal split windows */
          /* default is 0: open window for each file */
          parmp->window_count = get_number_arg(argv[0], &argv_idx, 0);
          parmp->window_layout = WIN_HOR;
          break;

        case 'O':                 /* "-O[N]" open N vertical split windows */
          /* default is 0: open window for each file */
          parmp->window_count = get_number_arg(argv[0], &argv_idx, 0);
          parmp->window_layout = WIN_VER;
          break;

        case 'q':                 /* "-q" QuickFix mode */
          if (parmp->edit_type != EDIT_NONE)
            mainerr(err_too_many_args, argv[0]);
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
            mainerr(err_too_many_args, argv[0]);
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
        case 'v':
          version();
          mch_exit(0);
        case 'V':                 /* "-V{N}"	Verbose level */
          /* default is 10: a little bit verbose */
          p_verbose = get_number_arg(argv[0], &argv_idx, 10);
          if (argv[0][argv_idx] != NUL) {
            set_option_value((char_u *)"verbosefile", 0L,
                (char_u *)argv[0] + argv_idx, 0);
            argv_idx = (int)STRLEN(argv[0]);
          }
          break;

        case 'w':                 /* "-w{number}"	set window height */
          /* "-w {scriptout}"	write to script */
          if (ascii_isdigit(((char_u *)argv[0])[argv_idx])) {
            n = get_number_arg(argv[0], &argv_idx, 10);
            set_option_value((char_u *)"window", n, NULL, 0);
            break;
          }
          want_argument = TRUE;
          break;

        case 'Z':                 /* "-Z"  restricted mode */
          restricted = TRUE;
          break;

        case 'c':                 /* "-c{command}" or "-c {command}" execute
                                     command */
          if (argv[0][argv_idx] != NUL) {
            if (parmp->n_commands >= MAX_ARG_CMDS)
              mainerr(err_extra_cmd, NULL);
            parmp->commands[parmp->n_commands++] = argv[0]
              + argv_idx;
            argv_idx = -1;
            break;
          }
          /*FALLTHROUGH*/
        case 'S':                 /* "-S {file}" execute Vim script */
        case 'i':                 /* "-i {shada}" use for ShaDa file */
        case 'u':                 /* "-u {vimrc}" vim inits file */
        case 'U':                 /* "-U {gvimrc}" gvim inits file */
        case 'W':                 /* "-W {scriptout}" overwrite */
          want_argument = TRUE;
          break;

        default:
          mainerr(err_opt_unknown, argv[0]);
      }

      /*
       * Handle option arguments with argument.
       */
      if (want_argument) {
        /*
         * Check for garbage immediately after the option letter.
         */
        if (argv[0][argv_idx] != NUL)
          mainerr(err_opt_garbage, argv[0]);

        --argc;
        if (argc < 1 && c != 'S')          /* -S has an optional argument */
          mainerr(err_arg_missing, argv[0]);
        ++argv;
        argv_idx = -1;

        switch (c) {
          case 'c':               /* "-c {command}" execute command */
          case 'S':               /* "-S {file}" execute Vim script */
            if (parmp->n_commands >= MAX_ARG_CMDS)
              mainerr(err_extra_cmd, NULL);
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
              } else {
                a = argv[0];
              }
              char *s = xmalloc(STRLEN(a) + 4);
              sprintf(s, "so %s", a);
              parmp->cmds_tofree[parmp->n_commands] = TRUE;
              parmp->commands[parmp->n_commands++] = s;
            } else {
              parmp->commands[parmp->n_commands++] = argv[0];
            }
            break;

          case '-':
            if (argv[-1][2] == 'c') {
              /* "--cmd {command}" execute command */
              if (parmp->n_pre_commands >= MAX_ARG_CMDS)
                mainerr(err_extra_cmd, NULL);
              parmp->pre_commands[parmp->n_pre_commands++] = argv[0];
            }
            /* "--startuptime <file>" already handled */
            break;

          case 'q':               /* "-q {errorfile}" QuickFix mode */
            parmp->use_ef = (char_u *)argv[0];
            break;

          case 'i':               /* "-i {shada}" use for shada */
            used_shada_file = argv[0];
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
            save_typebuf();
            break;

          case 't':               /* "-t {tag}" */
            parmp->tagname = (char_u *)argv[0];
            break;

          case 'u':               /* "-u {vimrc}" vim inits file */
            parmp->use_vimrc = argv[0];
            break;

          case 'U':               /* "-U {gvimrc}" gvim inits file */
            break;

          case 'w':               /* "-w {nr}" 'window' value */
            /* "-w {scriptout}" append to script file */
            if (ascii_isdigit(*((char_u *)argv[0]))) {
              argv_idx = 0;
              n = get_number_arg(argv[0], &argv_idx, 10);
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
        mainerr(err_too_many_args, argv[0]);
      parmp->edit_type = EDIT_FILE;

      /* Add the file to the global argument list. */
      ga_grow(&global_alist.al_ga, 1);
      p = vim_strsave((char_u *)argv[0]);

      if (parmp->diff_mode && os_isdir(p) && GARGCOUNT > 0
          && !os_isdir(alist_name(&GARGLIST[0]))) {
        char_u      *r;

        r = (char_u *)concat_fnames((char *)p, (char *)path_tail(alist_name(&GARGLIST[0])), TRUE);
        xfree(p);
        p = r;
      }

#ifdef USE_FNAME_CASE
      // Make the case of the file name match the actual file.
      path_fix_case(p);
#endif

      alist_add(&global_alist, p,
#if !defined(UNIX)
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
    const size_t swcmd_len = STRLEN(parmp->commands[0]) + 3;
    char *const swcmd = xmalloc(swcmd_len);
    snprintf(swcmd, swcmd_len, ":%s\r", parmp->commands[0]);
    set_vim_var_string(VV_SWAPCOMMAND, swcmd, -1);
    xfree(swcmd);
  }
  TIME_MSG("parsing arguments");
}

/*
 * Many variables are in "params" so that we can pass them to invoked
 * functions without a lot of arguments.  "argc" and "argv" are also
 * copied, so that they can be changed. */
static void init_params(mparm_T *paramp, int argc, char **argv)
{
  memset(paramp, 0, sizeof(*paramp));
  paramp->argc = argc;
  paramp->argv = argv;
  paramp->headless = false;
  paramp->want_full_screen = true;
  paramp->use_debug_break_level = -1;
  paramp->window_count = -1;
}

/*
 * Initialize global startuptime file if "--startuptime" passed as an argument.
 */
static void init_startuptime(mparm_T *paramp)
{
  for (int i = 1; i < paramp->argc; i++) {
    if (STRICMP(paramp->argv[i], "--startuptime") == 0 && i + 1 < paramp->argc) {
      time_fd = mch_fopen(paramp->argv[i + 1], "a");
      time_start("--- NVIM STARTING ---");
      break;
    }
  }

  starttime = time(NULL);
}

static void check_and_set_isatty(mparm_T *paramp)
{
  paramp->input_isatty = os_isatty(fileno(stdin));
  paramp->output_isatty = os_isatty(fileno(stdout));
  paramp->err_isatty = os_isatty(fileno(stderr));
  TIME_MSG("window checked");
}
/*
 * Get filename from command line, given that there is one.
 */
static char_u *get_fname(mparm_T *parmp, char_u *cwd)
{
#if !defined(UNIX)
  /*
   * Expand wildcards in file names.
   */
  if (!parmp->literal) {
    cwd = xmalloc(MAXPATHL);
    if (cwd != NULL) {
      os_dirname(cwd, MAXPATHL);
    }
    // Temporarily add '(' and ')' to 'isfname'.  These are valid
    // filename characters but are excluded from 'isfname' to make
    // "gf" work on a file name in parenthesis (e.g.: see vim.h).
    do_cmdline_cmd(":set isf+=(,)");
    alist_expand(NULL, 0);
    do_cmdline_cmd(":set isf&");
    if (cwd != NULL) {
      os_chdir((char *)cwd);
    }
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
    source_runtime((char_u *)"plugin/**/*.vim", DIP_ALL);  // NOLINT
    TIME_MSG("loading plugins");

    ex_packloadall(NULL);
    TIME_MSG("loading packages");
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
      ui_putc('\n');
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
    swap_exists_did_quit = FALSE;

    vim_snprintf((char *)IObuff, IOSIZE, "ta %s", tagname);
    do_cmdline_cmd((char *)IObuff);
    TIME_MSG("jumping to tag");

    /* If the user doesn't want to edit the file then we quit here. */
    if (swap_exists_did_quit)
      getout(1);
  }
}

// Print a warning if stdout is not a terminal.
// When starting in Ex mode and commands come from a file, set Silent mode.
static void check_tty(mparm_T *parmp)
{
  if (parmp->headless) {
    return;
  }

  // is active input a terminal?
  if (exmode_active) {
    if (!parmp->input_isatty) {
      silent_mode = true;
    }
  } else if (parmp->want_full_screen && (!parmp->err_isatty
        && (!parmp->output_isatty || !parmp->input_isatty))) {

    if (!parmp->output_isatty) {
      mch_errmsg(_("Vim: Warning: Output is not to a terminal\n"));
    }

    if (!parmp->input_isatty) {
      mch_errmsg(_("Vim: Warning: Input is not from a terminal\n"));
    }

    ui_flush();

    if (scriptin[0] == NULL) {
      os_delay(2000L, true);
    }

    TIME_MSG("Warning delay");
  }
}

/*
 * Read text from stdin.
 */
static void read_stdin(void)
{
  int i;

  /* When getting the ATTENTION prompt here, use a dialog */
  swap_exists_action = SEA_DIALOG;
  no_wait_return = TRUE;
  i = msg_didany;
  set_buflisted(TRUE);
  (void)open_buffer(TRUE, NULL, 0);     /* create memfile and read file */
  no_wait_return = FALSE;
  msg_didany = i;
  TIME_MSG("reading stdin");
  check_swap_exists_action();
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
    // Don't change the windows if there was a command in vimrc that
    // already split some windows
    if (parmp->window_layout == 0)
      parmp->window_layout = WIN_HOR;
    if (parmp->window_layout == WIN_TABS) {
      parmp->window_count = make_tabpages(parmp->window_count);
      TIME_MSG("making tab pages");
    } else if (firstwin->w_next == NULL) {
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
  } else {
    // Open a buffer for windows that don't have one yet.
    // Commands in the vimrc might have loaded a file or split the window.
    // Watch out for autocommands that delete a window.
    //
    // Don't execute Win/Buf Enter/Leave autocommands here
    ++autocmd_no_enter;
    ++autocmd_no_leave;
    dorewind = TRUE;
    while (done++ < 1000) {
      if (dorewind) {
        if (parmp->window_layout == WIN_TABS)
          goto_tabpage(1);
        else
          curwin = firstwin;
      } else if (parmp->window_layout == WIN_TABS) {
        if (curtab->tp_next == NULL)
          break;
        goto_tabpage(0);
      } else {
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
        /* When getting the ATTENTION prompt here, use a dialog */
        swap_exists_action = SEA_DIALOG;
        set_buflisted(TRUE);

        /* create memfile, read file */
        (void)open_buffer(FALSE, NULL, 0);

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
        dorewind = TRUE;                        /* start again */
      }
      os_breakcheck();
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

/// If opened more than one window, start editing files in the other
/// windows. make_windows() has already opened the windows.
static void edit_buffers(mparm_T *parmp, char_u *cwd)
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
    if (cwd != NULL) {
      os_chdir((char *)cwd);
    }
    // When w_arg_idx is -1 remove the window (see create_windows()).
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
      } else {
        if (curwin->w_next == NULL)             /* just checking */
          break;
        win_enter(curwin->w_next, false);
      }
    }
    advance = TRUE;

    // Only open the file if there is no file in this window yet (that can
    // happen when vimrc contains ":sall").
    if (curbuf == firstwin->w_buffer || curbuf->b_ffname == NULL) {
      curwin->w_arg_idx = arg_idx;
      /* Edit file from arg list, if there is one.  When "Quit" selected
       * at the ATTENTION prompt close the window. */
      swap_exists_did_quit = FALSE;
      (void)do_ecmd(0, arg_idx < GARGCOUNT
          ? alist_name(&GARGLIST[arg_idx]) : NULL,
          NULL, NULL, ECMD_LASTL, ECMD_HIDE, curwin);
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
      if (arg_idx == GARGCOUNT - 1)
        arg_had_last = TRUE;
      ++arg_idx;
    }
    os_breakcheck();
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
  win_enter(win, false);

  --autocmd_no_leave;
  TIME_MSG("editing files in windows");
  if (parmp->window_count > 1 && parmp->window_layout != WIN_TABS)
    win_equal(curwin, false, 'b');      /* adjust heights */
}

/*
 * Execute the commands from --cmd arguments "cmds[cnt]".
 */
static void exe_pre_commands(mparm_T *parmp)
{
  char **cmds = parmp->pre_commands;
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
      xfree(parmp->commands[i]);
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

/// Source vimrc or do other user initialization
///
/// Does one of the following things, stops after whichever succeeds:
///
/// 1. Execution of VIMINIT environment variable.
/// 2. Sourcing user vimrc file ($XDG_CONFIG_HOME/nvim/init.vim).
/// 3. Sourcing other vimrc files ($XDG_CONFIG_DIRS[1]/nvim/init.vim, …).
/// 4. Execution of EXINIT environment variable.
///
/// @return True if it is needed to attempt to source exrc file according to
///         'exrc' option definition.
static bool do_user_initialization(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool do_exrc = p_exrc;
  if (process_env("VIMINIT", true) == OK) {
    do_exrc = p_exrc;
    return do_exrc;
  }
  char_u *user_vimrc = (char_u *)stdpaths_user_conf_subpath("init.vim");
  if (do_source(user_vimrc, true, DOSO_VIMRC) != FAIL) {
    do_exrc = p_exrc;
    if (do_exrc) {
      do_exrc = (path_full_compare((char_u *)VIMRC_FILE, user_vimrc, false)
                 != kEqualFiles);
    }
    xfree(user_vimrc);
    return do_exrc;
  }
  xfree(user_vimrc);
  char *const config_dirs = stdpaths_get_xdg_var(kXDGConfigDirs);
  if (config_dirs != NULL) {
    const void *iter = NULL;
    do {
      const char *dir;
      size_t dir_len;
      iter = vim_colon_env_iter(config_dirs, iter, &dir, &dir_len);
      if (dir == NULL || dir_len == 0) {
        break;
      }
      const char path_tail[] = { 'n', 'v', 'i', 'm', PATHSEP,
                                 'i', 'n', 'i', 't', '.', 'v', 'i', 'm', NUL };
      char *vimrc = xmalloc(dir_len + sizeof(path_tail) + 1);
      memmove(vimrc, dir, dir_len);
      vimrc[dir_len] = PATHSEP;
      memmove(vimrc + dir_len + 1, path_tail, sizeof(path_tail));
      if (do_source((char_u *) vimrc, true, DOSO_VIMRC) != FAIL) {
        do_exrc = p_exrc;
        if (do_exrc) {
          do_exrc = (path_full_compare((char_u *)VIMRC_FILE, (char_u *)vimrc,
                                      false) != kEqualFiles);
        }
        xfree(vimrc);
        xfree(config_dirs);
        return do_exrc;
      }
      xfree(vimrc);
    } while (iter != NULL);
    xfree(config_dirs);
  }
  if (process_env("EXINIT", false) == OK) {
    do_exrc = p_exrc;
    return do_exrc;
  }
  return do_exrc;
}

/// Source startup scripts
static void source_startup_scripts(const mparm_T *const parmp)
  FUNC_ATTR_NONNULL_ALL
{
  // If -u argument given, use only the initializations from that file and
  // nothing else.
  if (parmp->use_vimrc != NULL) {
    if (strcmp(parmp->use_vimrc, "NONE") == 0
        || strcmp(parmp->use_vimrc, "NORC") == 0) {
      if (parmp->use_vimrc[2] == 'N')
        p_lpl = false;  // don't load plugins either
    } else {
      if (do_source((char_u *)parmp->use_vimrc, FALSE, DOSO_NONE) != OK)
        EMSG2(_("E282: Cannot read from \"%s\""), parmp->use_vimrc);
    }
  } else if (!silent_mode) {
#ifdef SYS_VIMRC_FILE
    // Get system wide defaults, if the file name is defined.
    (void) do_source((char_u *)SYS_VIMRC_FILE, false, DOSO_NONE);
#endif

    if (do_user_initialization()) {
      // Read initialization commands from ".vimrc" or ".exrc" in current
      // directory.  This is only done if the 'exrc' option is set.
      // Because of security reasons we disallow shell and write commands
      // now, except for unix if the file is owned by the user or 'secure'
      // option has been reset in environment of global "exrc" or "vimrc".
      // Only do this if VIMRC_FILE is not the same as vimrc file sourced in
      // do_user_initialization.
#if defined(UNIX)
      // If vimrc file is not owned by user, set 'secure' mode.
      if (!file_owned(VIMRC_FILE))
#endif
        secure = p_secure;

      if (do_source((char_u *)VIMRC_FILE, true, DOSO_VIMRC) == FAIL) {
#if defined(UNIX)
        // if ".exrc" is not owned by user set 'secure' mode
        if (!file_owned(EXRC_FILE)) {
          secure = p_secure;
        } else {
          secure = 0;
        }
#endif
        (void)do_source((char_u *)EXRC_FILE, false, DOSO_NONE);
      }
    }
    if (secure == 2) {
      need_wait_return = true;
    }
    secure = 0;
  }
  did_source_startup_scripts = true;
  TIME_MSG("sourcing vimrc file(s)");
}

/*
 * Setup to start using the GUI.  Exit with an error when not available.
 */
static void main_start_gui(void)
{
  mch_errmsg(_(e_nogvim));
  mch_errmsg("\n");
  mch_exit(2);
}


/// Get an environment variable, and execute it as Ex commands.
///
/// @param env         environment variable to execute
/// @param is_viminit  when true, called for VIMINIT
///
/// @return FAIL if the environment variable was not executed,
///         OK otherwise.
static int process_env(char *env, bool is_viminit)
{
  const char *initstr = os_getenv(env);
  if (initstr != NULL) {
    if (is_viminit) {
      vimrc_found(NULL, NULL);
    }
    char_u *save_sourcing_name = sourcing_name;
    linenr_T save_sourcing_lnum = sourcing_lnum;
    sourcing_name = (char_u *)env;
    sourcing_lnum = 0;
    scid_T save_sid = current_SID;
    current_SID = SID_ENV;
    do_cmdline_cmd((char *)initstr);
    sourcing_name = save_sourcing_name;
    sourcing_lnum = save_sourcing_lnum;
    current_SID = save_sid;;
    return OK;
  }
  return FAIL;
}

#ifdef UNIX
/// Checks if user owns file.
/// Use both uv_fs_stat() and uv_fs_lstat() through os_fileinfo() and
/// os_fileinfo_link() respectively for extra security.
static bool file_owned(const char *fname)
{
  uid_t uid = getuid();
  FileInfo file_info;
  bool file_owned = os_fileinfo(fname, &file_info)
                    && file_info.stat.st_uid == uid;
  bool link_owned = os_fileinfo_link(fname, &file_info)
                    && file_info.stat.st_uid == uid;
  return file_owned && link_owned;
}
#endif

/// Prints the following then exits:
/// - An error message `errstr`
/// - A string `str` if not null
///
/// @param errstr  string containing an error message
/// @param str     string to append to the primary error message, or NULL
static void mainerr(const char *errstr, const char *str)
{
  signal_stop();              // kill us with CTRL-C here, if you like

  mch_errmsg(argv0);
  mch_errmsg(": ");
  mch_errmsg(_(errstr));
  if (str != NULL) {
    mch_errmsg(": \"");
    mch_errmsg(str);
    mch_errmsg("\"");
  }
  mch_errmsg(_("\nMore info with \""));
  mch_errmsg(argv0);
  mch_errmsg(" -h\"\n");

  mch_exit(1);
}

/// Prints version information for "nvim -v" or "nvim --version".
static void version(void)
{
  info_message = TRUE;  // use mch_msg(), not mch_errmsg()
  list_version();
  msg_putchar('\n');
  msg_didout = FALSE;
}

/// Prints help message for "nvim -h" or "nvim --help".
static void usage(void)
{
  signal_stop();              // kill us with CTRL-C here, if you like

  mch_msg(_("Usage:\n"));
  mch_msg(_("  nvim [arguments] [file ...]      Edit specified file(s)\n"));
  mch_msg(_("  nvim [arguments] -               Read text from stdin\n"));
  mch_msg(_("  nvim [arguments] -t <tag>        Edit file where tag is defined\n"));
  mch_msg(_("  nvim [arguments] -q [errorfile]  Edit file with first error\n"));
  mch_msg(_("\nArguments:\n"));
  mch_msg(_("  --                    Only file names after this\n"));
#if !defined(UNIX)
  mch_msg(_("  --literal             Don't expand wildcards\n"));
#endif
  mch_msg(_("  -e                    Ex mode\n"));
  mch_msg(_("  -E                    Improved Ex mode\n"));
  mch_msg(_("  -s                    Silent (batch) mode (only for ex mode)\n"));
  mch_msg(_("  -d                    Diff mode\n"));
  mch_msg(_("  -R                    Read-only mode\n"));
  mch_msg(_("  -Z                    Restricted mode\n"));
  mch_msg(_("  -m                    Modifications (writing files) not allowed\n"));
  mch_msg(_("  -M                    Modifications in text not allowed\n"));
  mch_msg(_("  -b                    Binary mode\n"));
  mch_msg(_("  -l                    Lisp mode\n"));
  mch_msg(_("  -A                    Arabic mode\n"));
  mch_msg(_("  -F                    Farsi mode\n"));
  mch_msg(_("  -H                    Hebrew mode\n"));
  mch_msg(_("  -V[N][file]           Be verbose [level N][log messages to file]\n"));
  mch_msg(_("  -D                    Debugging mode\n"));
  mch_msg(_("  -n                    No swap file, use memory only\n"));
  mch_msg(_("  -r, -L                List swap files and exit\n"));
  mch_msg(_("  -r <file>             Recover crashed session\n"));
  mch_msg(_("  -u <vimrc>            Use <vimrc> instead of the default\n"));
  mch_msg(_("  -i <shada>            Use <shada> instead of the default\n"));
  mch_msg(_("  --noplugin            Don't load plugin scripts\n"));
  mch_msg(_("  -o[N]                 Open N windows (default: one for each file)\n"));
  mch_msg(_("  -O[N]                 Like -o but split vertically\n"));
  mch_msg(_("  -p[N]                 Open N tab pages (default: one for each file)\n"));
  mch_msg(_("  +                     Start at end of file\n"));
  mch_msg(_("  +<linenum>            Start at line <linenum>\n"));
  mch_msg(_("  +/<pattern>           Start at first occurrence of <pattern>\n"));
  mch_msg(_("  --cmd <command>       Execute <command> before loading any vimrc\n"));
  mch_msg(_("  -c <command>          Execute <command> after loading the first file\n"));
  mch_msg(_("  -S <session>          Source <session> after loading the first file\n"));
  mch_msg(_("  -s <scriptin>         Read Normal mode commands from <scriptin>\n"));
  mch_msg(_("  -w <scriptout>        Append all typed characters to <scriptout>\n"));
  mch_msg(_("  -W <scriptout>        Write all typed characters to <scriptout>\n"));
  mch_msg(_("  --startuptime <file>  Write startup timing messages to <file>\n"));
  mch_msg(_("  --api-info            Dump API metadata serialized to msgpack and exit\n"));
  mch_msg(_("  --embed               Use stdin/stdout as a msgpack-rpc channel\n"));
  mch_msg(_("  --headless            Don't start a user interface\n"));
  mch_msg(_("  -v, --version         Print version information and exit\n"));
  mch_msg(_("  -h, --help            Print this help message and exit\n"));
}


/*
 * Check the result of the ATTENTION dialog:
 * When "Quit" selected, exit Vim.
 * When "Recover" selected, recover the file.
 */
static void check_swap_exists_action(void)
{
  if (swap_exists_action == SEA_QUIT)
    getout(1);
  handle_swap_exists(NULL);
}
