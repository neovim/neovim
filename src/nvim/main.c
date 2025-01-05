// Make sure extern symbols are exported on Windows
#ifdef WIN32
# define EXTERN __declspec(dllexport)
#else
# define EXTERN
#endif
#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef ENABLE_ASAN_UBSAN
# include <sanitizer/asan_interface.h>
# ifndef MSWIN
#  include <sanitizer/ubsan_interface.h>
# endif
#endif

#include "auto/config.h"  // IWYU pragma: keep
#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/ui.h"
#include "nvim/arglist.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/channel.h"
#include "nvim/channel_defs.h"
#include "nvim/decoration.h"
#include "nvim/decoration_provider.h"
#include "nvim/diff.h"
#include "nvim/drawline.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/proc.h"
#include "nvim/event/stream.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/extmark.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/hashtab.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/lua/secure.h"
#include "nvim/lua/treesitter.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/server.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/lang.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/signal.h"
#include "nvim/os/stdpaths_defs.h"
#include "nvim/path.h"
#include "nvim/popupmenu.h"
#include "nvim/profile.h"
#include "nvim/quickfix.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/shada.h"
#include "nvim/statusline.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_client.h"
#include "nvim/ui_compositor.h"
#include "nvim/version.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#ifdef MSWIN
# include "nvim/os/os_win_console.h"
# ifndef _UCRT
#  error UCRT is the only supported C runtime on windows
# endif
#endif

#if defined(MSWIN) && !defined(MAKE_LIB)
# include "nvim/mbyte.h"
#endif

// values for "window_layout"
enum {
  WIN_HOR = 1,   // "-o" horizontally split windows
  WIN_VER = 2,   // "-O" vertically split windows
  WIN_TABS = 3,  // "-p" windows on tab pages
};

// Values for edit_type.
enum {
  EDIT_NONE = 0,   // no edit type yet
  EDIT_FILE = 1,   // file name argument[s] given, use argument list
  EDIT_STDIN = 2,  // read file from stdin
  EDIT_TAG = 3,    // tag name argument given, use tagname
  EDIT_QF = 4,     // start in quickfix mode
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "main.c.generated.h"
#endif

Loop main_loop;

static char *argv0 = NULL;

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
  resize_events = multiqueue_new_child(main_loop.events);

  signal_init();
  // mspgack-rpc initialization
  channel_init();
  terminal_init();
  ui_init();
  TIME_MSG("event init");
}

/// @returns false if main_loop could not be closed gracefully
bool event_teardown(void)
{
  if (!main_loop.events) {
    input_stop();
    return true;
  }

  multiqueue_process_events(main_loop.events);
  loop_poll_events(&main_loop, 0);  // Drain thread_events, fast_events.
  input_stop();
  channel_teardown();
  proc_teardown(&main_loop);
  timer_teardown();
  server_teardown();
  signal_teardown();
  terminal_teardown();

  return loop_close(&main_loop, true);
}

/// Performs early initialization.
///
/// Needed for unit tests.
void early_init(mparm_T *paramp)
{
  estack_init();
  cmdline_init();
  eval_init();          // init global variables
  init_path(argv0 ? argv0 : "nvim");
  init_normal_cmds();   // Init the table of Normal mode commands.
  runtime_init();
  highlight_init();

#ifdef MSWIN
  OSVERSIONINFO ovi;
  ovi.dwOSVersionInfoSize = sizeof(ovi);
  // Disable warning about GetVersionExA being deprecated. There doesn't seem to be a convenient
  // replacement that doesn't add a ton of extra code as of writing this.
# ifdef _MSC_VER
#  pragma warning(suppress : 4996)
  GetVersionEx(&ovi);
# else
  GetVersionEx(&ovi);
# endif
  snprintf(windowsVersion, sizeof(windowsVersion), "%d.%d",
           (int)ovi.dwMajorVersion, (int)ovi.dwMinorVersion);
#endif

  TIME_MSG("early init");

  // Setup to use the current locale (for ctype() and many other things).
  // NOTE: Translated messages with encodings other than latin1 will not
  // work until set_init_1() has been called!
  init_locale();

  // tabpage local options (p_ch) must be set before allocating first tabpage.
  set_init_tablocal();

  // Allocate the first tabpage, window and buffer.
  win_alloc_first();
  TIME_MSG("init first window");

  alist_init(&global_alist);    // Init the argument list to empty.
  global_alist.id = 0;

  // Set the default values for the options.
  // First find out the home directory, needed to expand "~" in options.
  init_homedir();               // find real value of $HOME
  set_init_1(paramp != NULL ? paramp->clean : false);
  log_init();
  TIME_MSG("inits 1");

  set_lang_var();               // set v:lang and v:ctype
}

#ifdef MAKE_LIB
int nvim_main(int argc, char **argv);  // silence -Wmissing-prototypes
int nvim_main(int argc, char **argv)
#else
int main(int argc, char **argv)
#endif
{
  argv0 = argv[0];

  if (!appname_is_valid()) {
    fprintf(stderr, "$NVIM_APPNAME must be a name or relative path.\n");
    exit(1);
  }

  if (argc > 1 && STRICMP(argv[1], "-ll") == 0) {
    if (argc == 2) {
      print_mainerr(err_arg_missing, argv[1], NULL);
      exit(1);
    }
    nlua_run_script(argv, argc, 3);
  }

  char *fname = NULL;     // file name from command line
  mparm_T params;         // various parameters passed between
                          // main() and other functions.
  char *cwd = NULL;       // current working dir on startup

  // Many variables are in `params` so that we can pass them around easily.
  // `argc` and `argv` are also copied, so that they can be changed.
  init_params(&params, argc, argv);

  init_startuptime(&params);

  // Need to find "--clean" before actually parsing arguments.
  for (int i = 1; i < params.argc; i++) {
    if (STRICMP(params.argv[i], "--clean") == 0) {
      params.clean = true;
      break;
    }
  }

  event_init();

  early_init(&params);

  set_argv_var(argv, argc);  // set v:argv

  // Check if we have an interactive window.
  check_and_set_isatty(&params);

  // Process the command line arguments.  File names are put in the global
  // argument list "global_alist".
  command_line_scan(&params);

  nlua_init(argv, argc, params.lua_arg0);
  TIME_MSG("init lua interpreter");

  if (embedded_mode) {
    const char *err;
    if (!channel_from_stdio(true, CALLBACK_READER_INIT, &err)) {
      abort();
    }
  }

  if (GARGCOUNT > 0) {
    fname = get_fname(&params, cwd);
  }

  // Recovery mode without a file name: List swap files.
  // In this case, no UI is needed.
  if (recoverymode && fname == NULL) {
    headless_mode = true;
  }

#ifdef MSWIN
  // on windows we use CONIN special file, thus we don't know this yet.
  bool has_term = true;
#else
  bool has_term = (stdin_isatty || stdout_isatty || stderr_isatty);
#endif
  bool use_builtin_ui = (has_term && !headless_mode && !embedded_mode && !silent_mode);

  if (params.remote) {
    remote_request(&params, params.remote, params.server_addr, argc, argv,
                   use_builtin_ui);
  }

  bool remote_ui = (ui_client_channel_id != 0);

  if (use_builtin_ui && !remote_ui) {
    ui_client_forward_stdin = !stdin_isatty;
    uint64_t rv = ui_client_start_server(params.argc, params.argv);
    if (!rv) {
      fprintf(stderr, "Failed to start Nvim server!\n");
      os_exit(1);
    }
    ui_client_channel_id = rv;
  }

  // NORETURN: Start builtin UI client.
  if (ui_client_channel_id) {
    ui_client_run(remote_ui);  // NORETURN
  }
  assert(!ui_client_channel_id && !use_builtin_ui);
  // Nvim server...

  if (!server_init(params.listen_addr)) {
    mainerr(IObuff, NULL, NULL);
  }

  TIME_MSG("expanding arguments");

  if (params.diff_mode && params.window_count == -1) {
    params.window_count = 0;            // open up to 3 windows
  }
  // Don't redraw until much later.
  RedrawingDisabled++;

  setbuf(stdout, NULL);  // NOLINT(bugprone-unsafe-functions)

  full_screen = !silent_mode || exmode_active;

  // Set the default values for the options that use Rows and Columns.
  win_init_size();
  // Set the 'diff' option now, so that it can be checked for in a vimrc
  // file.  There is no buffer yet though.
  if (params.diff_mode) {
    diff_win_options(firstwin, false);
  }

  assert(p_ch >= 0 && Rows >= p_ch && Rows - p_ch <= INT_MAX);
  cmdline_row = Rows - (int)p_ch;
  msg_row = cmdline_row;
  default_grid_alloc();  // allocate screen buffers
  set_init_2(headless_mode);
  TIME_MSG("inits 2");

  msg_scroll = true;
  no_wait_return = true;

  init_highlight(true, false);  // Default highlight groups.
  ui_comp_syn_init();
  TIME_MSG("init highlight");

  // Set the break level after the terminal is initialized.
  debug_break_level = params.use_debug_break_level;

  // Read ex-commands if invoked with "-es".
  if (!stdin_isatty && !params.input_istext && silent_mode && exmode_active) {
    input_start();
  }

  // Wait for UIs to set up Nvim or show early messages
  // and prompts (--cmd, swapfile dialog, …).
  bool use_remote_ui = (embedded_mode && !headless_mode);
  bool listen_and_embed = params.listen_addr != NULL;
  if (use_remote_ui) {
    TIME_MSG("waiting for UI");
    remote_ui_wait_for_attach(!listen_and_embed);
    TIME_MSG("done waiting for UI");
    firstwin->w_prev_height = firstwin->w_height;  // may have changed
  }

  // prepare screen now
  starting = NO_BUFFERS;
  screenclear();
  win_new_screensize();
  TIME_MSG("clear screen");

  // Handle "foo | nvim". EDIT_FILE may be overwritten now. #6299
  if (edit_stdin(&params)) {
    params.edit_type = EDIT_STDIN;
  }

  if (params.scriptin) {
    if (!open_scriptin(params.scriptin)) {
      os_exit(2);
    }
  }
  if (params.scriptout) {
    scriptout = os_fopen(params.scriptout, params.scriptout_append ? APPENDBIN : WRITEBIN);
    if (scriptout == NULL) {
      fprintf(stderr, _("Cannot open for script output: \""));
      fprintf(stderr, "%s\"\n", params.scriptout);
      os_exit(2);
    }
  }

  nlua_init_defaults();

  TIME_MSG("init default mappings & autocommands");

  bool vimrc_none = strequal(params.use_vimrc, "NONE");

  // Reset 'loadplugins' for "-u NONE" before "--cmd" arguments.
  // Allows for setting 'loadplugins' there.
  // For --clean we still want to load plugins.
  p_lpl = vimrc_none ? params.clean : p_lpl;

  // Execute --cmd arguments.
  exe_pre_commands(&params);

  if (!vimrc_none || params.clean) {
    // Sources ftplugin.vim and indent.vim. We do this *before* the user startup scripts to ensure
    // ftplugins run before FileType autocommands defined in the init file (which allows those
    // autocommands to overwrite settings from ftplugins).
    filetype_plugin_enable();
  }

  // Source startup scripts.
  source_startup_scripts(&params);

  // If using the runtime (-u is not NONE), enable syntax & filetype plugins.
  if (!vimrc_none || params.clean) {
    // Sources filetype.lua unless the user explicitly disabled it with :filetype off.
    filetype_maybe_enable();
    // Sources syntax/syntax.vim. We do this *after* the user startup scripts so that users can
    // disable syntax highlighting with `:syntax off` if they wish.
    syn_maybe_enable();
  }

  // Read all the plugin files.
  load_plugins();

  // Decide about window layout for diff mode after reading vimrc.
  set_window_layout(&params);

  // Recovery mode without a file name: List swap files.
  // Uses the 'dir' option, therefore it must be after the initializations.
  if (recoverymode && fname == NULL) {
    recover_names(NULL, true, NULL, 0, NULL);
    os_exit(0);
  }

  // Set some option defaults after reading vimrc files.
  set_init_3();
  TIME_MSG("inits 3");

  // "-n" argument: Disable swap file by setting 'updatecount' to 0.
  // Note that this overrides anything from a vimrc file.
  if (params.no_swap_file) {
    p_uc = 0;
  }

  // XXX: Minimize 'updatetime' for -es/-Es. #7679
  if (silent_mode) {
    p_ut = 1;
  }

  // Read in registers, history etc, from the ShaDa file.
  // This is where v:oldfiles gets filled.
  if (*p_shada != NUL) {
    shada_read_everything(NULL, false, true);
    TIME_MSG("reading ShaDa");
  }
  // It's better to make v:oldfiles an empty list than NULL.
  if (get_vim_var_list(VV_OLDFILES) == NULL) {
    set_vim_var_list(VV_OLDFILES, tv_list_alloc(0));
  }

  // "-q errorfile": Load the error file now.
  // If the error file can't be read, exit before doing anything else.
  handle_quickfix(&params);

  //
  // Start putting things on the screen.
  // Scroll screen down before drawing over it
  // Clear screen now, so file message will not be cleared.
  //
  starting = NO_BUFFERS;
  no_wait_return = false;
  if (!exmode_active) {
    msg_scroll = false;
  }

  // Read file (text, not commands) from stdin if:
  //    - stdin is not a tty
  //    - and -e/-es was not given
  //
  // Do this before starting Raw mode, because it may change things that the
  // writing end of the pipe doesn't like, e.g., in case stdin and stderr
  // are the same terminal: "cat | vim -".
  // Using autocommands here may cause trouble...
  if (params.edit_type == EDIT_STDIN && !recoverymode) {
    read_stdin();
  }

  setmouse();  // may start using the mouse

  redraw_later(curwin, UPD_VALID);

  no_wait_return = true;

  // Create the requested number of windows and edit buffers in them.
  // Also does recovery if "recoverymode" set.
  create_windows(&params);
  TIME_MSG("opening buffers");

  // Clear v:swapcommand
  set_vim_var_string(VV_SWAPCOMMAND, NULL, -1);

  // Ex starts at last line of the file.
  if (exmode_active) {
    curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
  }

  apply_autocmds(EVENT_BUFENTER, NULL, NULL, false, curbuf);
  TIME_MSG("BufEnter autocommands");
  setpcmark();

  // When started with "-q errorfile" jump to first error now.
  if (params.edit_type == EDIT_QF) {
    qf_jump(NULL, 0, 0, false);
    TIME_MSG("jump to first error");
  }

  // If opened more than one window, start editing files in the other
  // windows.
  edit_buffers(&params, cwd);
  xfree(cwd);

  if (params.diff_mode) {
    // set options in each window for "nvim -d".
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (!wp->w_arg_idx_invalid) {
        diff_win_options(wp, true);
      }
    }
  }

  // Shorten any of the filenames, but only when absolute.
  shorten_fnames(false);

  // Need to jump to the tag before executing the '-c command'.
  // Makes "vim -c '/return' -t main" work.
  handle_tag(params.tagname);

  // Execute any "+", "-c" and "-S" arguments.
  if (params.n_commands > 0) {
    exe_commands(&params);
  }

  starting = 0;

  RedrawingDisabled = 0;
  redraw_all_later(UPD_NOT_VALID);
  no_wait_return = false;

  // 'autochdir' has been postponed.
  do_autochdir();

  set_vim_var_nr(VV_VIM_DID_ENTER, 1);
  apply_autocmds(EVENT_VIMENTER, NULL, NULL, false, curbuf);
  TIME_MSG("VimEnter autocommands");
  if (use_remote_ui) {
    do_autocmd_uienter_all();
    TIME_MSG("UIEnter autocommands");
  }

#ifdef MSWIN
  if (use_remote_ui) {
    os_icon_init();
  }
  os_title_save();
#endif

  // Adjust default register name for "unnamed" in 'clipboard'. Can only be
  // done after the clipboard is available and all initial commands that may
  // modify the 'clipboard' setting have run; i.e. just before entering the
  // main loop.
  set_reg_var(get_default_register_name());

  // When a startup script or session file setup for diff'ing and
  // scrollbind, sync the scrollbind now.
  if (curwin->w_p_diff && curwin->w_p_scb) {
    update_topline(curwin);
    check_scrollbind(0, 0);
    TIME_MSG("diff scrollbinding");
  }

  // If ":startinsert" command used, stuff a dummy command to be able to
  // call normal_cmd(), which will then start Insert mode.
  if (restart_edit != 0) {
    stuffcharReadbuff(K_NOP);
  }

  // WORKAROUND(mhi): #3023
  if (cb_flags & (kOptCbFlagUnnamed | kOptCbFlagUnnamedplus)) {
    eval_has_provider("clipboard", false);
  }

  if (params.luaf != NULL) {
    // Like "--cmd", "+", "-c" and "-S", don't truncate messages.
    msg_scroll = true;
    DLOG("executing Lua -l script");
    bool lua_ok = nlua_exec_file(params.luaf);
    TIME_MSG("executing Lua -l script");
    if (msg_didout) {
      msg_putchar('\n');
      msg_didout = false;
    }
    getout(lua_ok ? 0 : 1);
  }

  TIME_MSG("before starting main loop");
  ILOG("starting main loop");

  // Main loop: never returns.
  normal_enter(false, false);

#if defined(MSWIN) && !defined(MAKE_LIB)
  xfree(argv);
#endif
  return 0;
}

void os_exit(int r)
  FUNC_ATTR_NORETURN
{
  exiting = true;

  if (ui_client_channel_id) {
    ui_client_stop();
    if (r == 0) {
      r = ui_client_exit_status;
    }
  } else {
    ui_flush();
    ui_call_stop();
  }

  if (!event_teardown() && r == 0) {
    r = 1;  // Exit with error if main_loop did not teardown gracefully.
  }
  if (!ui_client_channel_id) {
    ml_close_all(true);  // remove all memfiles
  }
  if (used_stdin) {
    stream_set_blocking(STDIN_FILENO, true);  // normalize stream (#2598)
  }

  ILOG("Nvim exit: %d", r);

#ifdef EXITFREE
  free_all_mem();
#endif

  exit(r);
}

/// Exit properly
void getout(int exitval)
  FUNC_ATTR_NORETURN
{
  assert(!ui_client_channel_id);
  exiting = true;

  // make sure startuptimes have been flushed
  time_finish();

  // On error during Ex mode, exit with a non-zero code.
  // POSIX requires this, although it's not 100% clear from the standard.
  if (exmode_active) {
    exitval += ex_exitval;
  }

  set_vim_var_nr(VV_EXITING, exitval);

  // Invoked all deferred functions in the function stack.
  invoke_all_defer();

  // Optionally print hashtable efficiency.
  hash_debug_results();

  if (v_dying <= 1) {
    const tabpage_T *next_tp;

    // Trigger BufWinLeave for all windows, but only once per buffer.
    for (const tabpage_T *tp = first_tabpage; tp != NULL; tp = next_tp) {
      next_tp = tp->tp_next;
      FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
        if (wp->w_buffer == NULL || !buf_valid(wp->w_buffer)) {
          // Autocmd must have close the buffer already, skip.
          continue;
        }

        buf_T *buf = wp->w_buffer;
        if (buf_get_changedtick(buf) != -1) {
          bufref_T bufref;

          set_bufref(&bufref, buf);
          apply_autocmds(EVENT_BUFWINLEAVE, buf->b_fname, buf->b_fname, false, buf);
          if (bufref_valid(&bufref)) {
            buf_set_changedtick(buf, -1);  // note that we did it already
          }
          // start all over, autocommands may mess up the lists
          next_tp = first_tabpage;
          break;
        }
      }
    }

    // Trigger BufUnload for buffers that are loaded
    FOR_ALL_BUFFERS(buf) {
      if (buf->b_ml.ml_mfp != NULL) {
        bufref_T bufref;
        set_bufref(&bufref, buf);
        apply_autocmds(EVENT_BUFUNLOAD, buf->b_fname, buf->b_fname, false, buf);
        if (!bufref_valid(&bufref)) {
          // Autocmd deleted the buffer.
          break;
        }
      }
    }

    int unblock = 0;
    // deathtrap() blocks autocommands, but we do want to trigger
    // VimLeavePre.
    if (is_autocmd_blocked()) {
      unblock_autocmds();
      unblock++;
    }
    apply_autocmds(EVENT_VIMLEAVEPRE, NULL, NULL, false, curbuf);
    if (unblock) {
      block_autocmds();
    }
  }

  if (
#ifdef EXITFREE
      !entered_free_all_mem &&
#endif
      p_shada && *p_shada != NUL) {
    // Write out the registers, history, marks etc, to the ShaDa file
    shada_write_file(NULL, false);
  }

  if (v_dying <= 1) {
    int unblock = 0;

    // deathtrap() blocks autocommands, but we do want to trigger VimLeave.
    if (is_autocmd_blocked()) {
      unblock_autocmds();
      unblock++;
    }
    apply_autocmds(EVENT_VIMLEAVE, NULL, NULL, false, curbuf);
    if (unblock) {
      block_autocmds();
    }
  }

  profile_dump();

  if (did_emsg) {
    // give the user a chance to read the (error) message
    no_wait_return = false;
    // TODO(justinmk): this may call getout(0), clobbering exitval...
    wait_return(false);
  }

  // Apply 'titleold'.
  if (p_title && *p_titleold != NUL) {
    ui_call_set_title(cstr_as_string(p_titleold));
  }

  if (garbage_collect_at_exit) {
    garbage_collect(false);
  }

#ifdef MSWIN
  // Restore Windows console icon before exiting.
  os_icon_set(NULL, NULL);
  os_title_reset();
#endif

  os_exit(exitval);
}

/// Preserve files, print contents of `errmsg`, and exit 1.
/// @param errmsg  If NULL, this function will not print anything.
///
/// May be called from deadly_signal().
void preserve_exit(const char *errmsg)
  FUNC_ATTR_NORETURN
{
  // 'true' when we are sure to exit, e.g., after a deadly signal
  static bool really_exiting = false;

  // Prevent repeated calls into this method.
  if (really_exiting) {
    if (used_stdin) {
      // normalize stream (#2598)
      stream_set_blocking(STDIN_FILENO, true);
    }
    exit(2);
  }

  really_exiting = true;
  // Ignore SIGHUP while we are already exiting. #9274
  signal_reject_deadly();

  if (ui_client_channel_id) {
    // For TUI: exit alternate screen so that the error messages can be seen.
    ui_client_stop();
  }
  if (errmsg != NULL) {
    fprintf(stderr, "%s\n", errmsg);
  }
  if (ui_client_channel_id) {
    os_exit(1);
  }

  ml_close_notmod();                // close all not-modified buffers

  FOR_ALL_BUFFERS(buf) {
    if (buf->b_ml.ml_mfp != NULL && buf->b_ml.ml_mfp->mf_fname != NULL) {
      if (errmsg != NULL) {
        fprintf(stderr, "Vim: preserving files...\r\n");
      }
      ml_sync_all(false, false, true);  // preserve all swap files
      break;
    }
  }

  ml_close_all(false);              // close all memfiles, without deleting

  if (errmsg != NULL) {
    fprintf(stderr, "Vim: Finished.\r\n");
  }

  getout(1);
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
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (ascii_isdigit(p[*idx])) {
    def = atoi(&(p[*idx]));
    while (ascii_isdigit(p[*idx])) {
      *idx = *idx + 1;
    }
  }
  return def;
}

static uint64_t server_connect(char *server_addr, const char **errmsg)
{
  if (server_addr == NULL) {
    *errmsg = "no address specified";
    return 0;
  }
  CallbackReader on_data = CALLBACK_READER_INIT;
  const char *error = NULL;
  bool is_tcp = strrchr(server_addr, ':') ? true : false;
  // connected to channel
  uint64_t chan = channel_connect(is_tcp, server_addr, true, on_data, 50, &error);
  if (error) {
    *errmsg = error;
    return 0;
  }
  return chan;
}

/// Handle remote subcommands
static void remote_request(mparm_T *params, int remote_args, char *server_addr, int argc,
                           char **argv, bool ui_only)
{
  bool is_ui = strequal(argv[remote_args], "--remote-ui");
  if (ui_only && !is_ui) {
    // TODO(bfredl): this implies always starting the TUI.
    // if we be smart we could delay this past should_exit
    return;
  }

  const char *connect_error = NULL;
  uint64_t chan = server_connect(server_addr, &connect_error);
  Object rvobj = OBJECT_INIT;

  if (is_ui) {
    if (!chan) {
      fprintf(stderr, "Remote ui failed to start: %s\n", connect_error);
      os_exit(1);
    } else if (strequal(server_addr, os_getenv("NVIM"))) {
      fprintf(stderr, "%s", "Cannot attach UI of :terminal child to its parent. ");
      fprintf(stderr, "%s\n", "(Unset $NVIM to skip this check)");
      os_exit(1);
    }

    ui_client_channel_id = chan;
    return;
  }

  Array args = ARRAY_DICT_INIT;
  kv_resize(args, (size_t)(argc - remote_args));
  for (int t_argc = remote_args; t_argc < argc; t_argc++) {
    ADD_C(args, CSTR_AS_OBJ(argv[t_argc]));
  }

  Error err = ERROR_INIT;
  MAXSIZE_TEMP_ARRAY(a, 4);
  ADD_C(a, INTEGER_OBJ((int)chan));
  ADD_C(a, CSTR_AS_OBJ(server_addr));
  ADD_C(a, CSTR_AS_OBJ(connect_error));
  ADD_C(a, ARRAY_OBJ(args));
  String s = STATIC_CSTR_AS_STRING("return vim._cs_remote(...)");
  Object o = nlua_exec(s, a, kRetObject, NULL, &err);
  kv_destroy(args);
  if (ERROR_SET(&err)) {
    fprintf(stderr, "%s\n", err.msg);
    os_exit(2);
  }

  if (o.type == kObjectTypeDict) {
    rvobj.data.dict = o.data.dict;
  } else {
    fprintf(stderr, "vim._cs_remote returned unexpected value\n");
    os_exit(2);
  }

  TriState should_exit = kNone;
  TriState tabbed = kNone;

  for (size_t i = 0; i < rvobj.data.dict.size; i++) {
    if (strequal(rvobj.data.dict.items[i].key.data, "errmsg")) {
      if (rvobj.data.dict.items[i].value.type != kObjectTypeString) {
        fprintf(stderr, "vim._cs_remote returned an unexpected type for 'errmsg'\n");
        os_exit(2);
      }
      fprintf(stderr, "%s\n", rvobj.data.dict.items[i].value.data.string.data);
      os_exit(2);
    } else if (strequal(rvobj.data.dict.items[i].key.data, "result")) {
      if (rvobj.data.dict.items[i].value.type != kObjectTypeString) {
        fprintf(stderr, "vim._cs_remote returned an unexpected type for 'result'\n");
        os_exit(2);
      }
      printf("%s", rvobj.data.dict.items[i].value.data.string.data);
    } else if (strequal(rvobj.data.dict.items[i].key.data, "tabbed")) {
      if (rvobj.data.dict.items[i].value.type != kObjectTypeBoolean) {
        fprintf(stderr, "vim._cs_remote returned an unexpected type for 'tabbed'\n");
        os_exit(2);
      }
      tabbed = rvobj.data.dict.items[i].value.data.boolean ? kTrue : kFalse;
    } else if (strequal(rvobj.data.dict.items[i].key.data, "should_exit")) {
      if (rvobj.data.dict.items[i].value.type != kObjectTypeBoolean) {
        fprintf(stderr, "vim._cs_remote returned an unexpected type for 'should_exit'\n");
        os_exit(2);
      }
      should_exit = rvobj.data.dict.items[i].value.data.boolean ? kTrue : kFalse;
    }
  }
  if (should_exit == kNone || tabbed == kNone) {
    fprintf(stderr, "vim._cs_remote didn't return a value for should_exit or tabbed, bailing\n");
    os_exit(2);
  }
  api_free_object(o);

  if (should_exit == kTrue) {
    os_exit(0);
  }
  if (tabbed == kTrue) {
    params->window_count = argc - remote_args - 1;
    params->window_layout = WIN_TABS;
  }
}

/// Decides whether text (as opposed to commands) will be read from stdin.
/// @see EDIT_STDIN
static bool edit_stdin(mparm_T *parmp)
{
  bool implicit = !headless_mode
                  && !(embedded_mode && stdin_fd <= 0)
                  && (!exmode_active || parmp->input_istext)
                  && !stdin_isatty
                  && parmp->edit_type <= EDIT_STDIN
                  && parmp->scriptin == NULL;  // `-s -` was not given.
  return parmp->had_stdin_file || implicit;
}

/// Scan the command line arguments.
static void command_line_scan(mparm_T *parmp)
{
  int argc = parmp->argc;
  char **argv = parmp->argv;
  int argv_idx;                         // index in argv[n][]
  bool had_minmin = false;              // found "--" argument
  bool want_argument;                   // option argument with argument
  int n;

  argc--;
  argv++;
  argv_idx = 1;  // active option letter is argv[0][argv_idx]
  while (argc > 0) {
    // "+" or "+{number}" or "+/{pat}" or "+{command}" argument.
    if (argv[0][0] == '+' && !had_minmin) {
      if (parmp->n_commands >= MAX_ARG_CMDS) {
        mainerr(err_extra_cmd, NULL, NULL);
      }
      argv_idx = -1;  // skip to next argument
      if (argv[0][1] == NUL) {
        parmp->commands[parmp->n_commands++] = "$";
      } else {
        parmp->commands[parmp->n_commands++] = &(argv[0][1]);
      }
    } else if (argv[0][0] == '-' && !had_minmin) {
      // Optional argument.

      want_argument = false;
      char c = argv[0][argv_idx++];
      switch (c) {
      case NUL:    // "nvim -"  read from stdin
        if (exmode_active) {
          // "nvim -e -" silent mode
          silent_mode = true;
          parmp->no_swap_file = true;
        } else {
          if (parmp->edit_type > EDIT_STDIN) {
            mainerr(err_too_many_args, argv[0], NULL);
          }
          parmp->had_stdin_file = true;
          parmp->edit_type = EDIT_STDIN;
        }
        argv_idx = -1;  // skip to next argument
        break;
      case '-':    // "--" No more option arguments.
        // "--help" give help message
        // "--version" give version message
        // "--noplugin[s]" skip plugins
        // "--cmd <cmd>" execute cmd before vimrc
        // "--remote" execute commands remotey on a server
        // "--server" name of vim server to send remote commands to
        if (STRICMP(argv[0] + argv_idx, "help") == 0) {
          usage();
          os_exit(0);
        } else if (STRICMP(argv[0] + argv_idx, "version") == 0) {
          version();
          os_exit(0);
        } else if (STRICMP(argv[0] + argv_idx, "api-info") == 0) {
#ifdef MSWIN
          // set stdout to binary to avoid crlf in --api-info output
          _setmode(STDOUT_FILENO, _O_BINARY);
#endif

          String data = api_metadata_raw();
          const ptrdiff_t written_bytes = os_write(STDOUT_FILENO, data.data, data.size, false);
          if (written_bytes < 0) {
            semsg(_("E5420: Failed to write to file: %s"), os_strerror((int)written_bytes));
          }

          os_exit(0);
        } else if (STRICMP(argv[0] + argv_idx, "headless") == 0) {
          headless_mode = true;
        } else if (STRICMP(argv[0] + argv_idx, "embed") == 0) {
          embedded_mode = true;
        } else if (STRNICMP(argv[0] + argv_idx, "listen", 6) == 0) {
          want_argument = true;
          argv_idx += 6;
        } else if (STRNICMP(argv[0] + argv_idx, "literal", 7) == 0) {
          // Do nothing: file args are always literal. #7679
        } else if (STRNICMP(argv[0] + argv_idx, "remote", 6) == 0) {
          parmp->remote = parmp->argc - argc;
        } else if (STRNICMP(argv[0] + argv_idx, "server", 6) == 0) {
          want_argument = true;
          argv_idx += 6;
        } else if (STRNICMP(argv[0] + argv_idx, "noplugin", 8) == 0) {
          p_lpl = false;
        } else if (STRNICMP(argv[0] + argv_idx, "cmd", 3) == 0) {
          want_argument = true;
          argv_idx += 3;
        } else if (STRNICMP(argv[0] + argv_idx, "startuptime", 11) == 0) {
          want_argument = true;
          argv_idx += 11;
        } else if (STRNICMP(argv[0] + argv_idx, "clean", 5) == 0) {
          parmp->use_vimrc = "NONE";
          parmp->clean = true;
          set_option_value_give_err(kOptShadafile, STATIC_CSTR_AS_OPTVAL("NONE"), 0);
        } else if (STRNICMP(argv[0] + argv_idx, "luamod-dev", 9) == 0) {
          nlua_disable_preload = true;
        } else {
          if (argv[0][argv_idx]) {
            mainerr(err_opt_unknown, argv[0], NULL);
          }
          had_minmin = true;
        }
        if (!want_argument) {
          argv_idx = -1;  // skip to next argument
        }
        break;
      case 'A':    // "-A" start in Arabic mode.
        set_option_value_give_err(kOptArabic, BOOLEAN_OPTVAL(true), 0);
        break;
      case 'b':    // "-b" binary mode.
        // Needs to be effective before expanding file names, because
        // for Win32 this makes us edit a shortcut file itself,
        // instead of the file it links to.
        set_options_bin(curbuf->b_p_bin, 1, 0);
        curbuf->b_p_bin = 1;  // Binary file I/O.
        break;

      case 'D':    // "-D" Debugging
        parmp->use_debug_break_level = 9999;
        break;
      case 'd':    // "-d" 'diff'
        parmp->diff_mode = true;
        break;
      case 'e':    // "-e" Ex mode
        exmode_active = true;
        break;
      case 'E':    // "-E" Ex mode
        exmode_active = true;
        parmp->input_istext = true;
        break;
      case 'f':    // "-f"  GUI: run in foreground.
        break;
      case '?':    // "-?" give help message (for MS-Windows)
      case 'h':    // "-h" give help message
        usage();
        os_exit(0);
      case 'H':    // "-H" start in Hebrew mode: rl + keymap=hebrew set.
        set_option_value_give_err(kOptKeymap, STATIC_CSTR_AS_OPTVAL("hebrew"), 0);
        set_option_value_give_err(kOptRightleft, BOOLEAN_OPTVAL(true), 0);
        break;
      case 'M':    // "-M"  no changes or writing of files
        reset_modifiable();
        FALLTHROUGH;
      case 'm':    // "-m"  no writing of files
        p_write = false;
        break;

      case 'N':    // "-N"  Nocompatible
      case 'X':    // "-X"  Do not connect to X server
        // No-op
        break;

      case 'n':    // "-n" no swap file
        parmp->no_swap_file = true;
        break;
      case 'p':    // "-p[N]" open N tab pages
        // default is 0: open window for each file
        parmp->window_count = get_number_arg(argv[0], &argv_idx, 0);
        parmp->window_layout = WIN_TABS;
        break;
      case 'o':    // "-o[N]" open N horizontal split windows
        // default is 0: open window for each file
        parmp->window_count = get_number_arg(argv[0], &argv_idx, 0);
        parmp->window_layout = WIN_HOR;
        break;
      case 'O':    // "-O[N]" open N vertical split windows
        // default is 0: open window for each file
        parmp->window_count = get_number_arg(argv[0], &argv_idx, 0);
        parmp->window_layout = WIN_VER;
        break;
      case 'q':    // "-q" QuickFix mode
        if (parmp->edit_type != EDIT_NONE) {
          mainerr(err_too_many_args, argv[0], NULL);
        }
        parmp->edit_type = EDIT_QF;
        if (argv[0][argv_idx]) {  // "-q{errorfile}"
          parmp->use_ef = argv[0] + argv_idx;
          argv_idx = -1;
        } else if (argc > 1) {    // "-q {errorfile}"
          want_argument = true;
        }
        break;
      case 'R':    // "-R" readonly mode
        readonlymode = true;
        curbuf->b_p_ro = true;
        p_uc = 10000;  // don't update very often
        break;
      case 'r':    // "-r" recovery mode
      case 'L':    // "-L" recovery mode
        recoverymode = 1;
        break;
      case 's':
        if (exmode_active) {    // "-es" silent (batch) Ex-mode
          silent_mode = true;
          parmp->no_swap_file = true;
          if (p_shadafile == NULL || *p_shadafile == NUL) {
            set_option_value_give_err(kOptShadafile, STATIC_CSTR_AS_OPTVAL("NONE"), 0);
          }
        } else {                // "-s {scriptin}" read from script file
          want_argument = true;
        }
        break;
      case 't':    // "-t {tag}" or "-t{tag}" jump to tag
        if (parmp->edit_type != EDIT_NONE) {
          mainerr(err_too_many_args, argv[0], NULL);
        }
        parmp->edit_type = EDIT_TAG;
        if (argv[0][argv_idx]) {  // "-t{tag}"
          parmp->tagname = argv[0] + argv_idx;
          argv_idx = -1;
        } else {  // "-t {tag}"
          want_argument = true;
        }
        break;
      case 'v':
        version();
        os_exit(0);
      case 'V':    // "-V{N}" Verbose level
        // default is 10: a little bit verbose
        p_verbose = get_number_arg(argv[0], &argv_idx, 10);
        if (argv[0][argv_idx] != NUL) {
          set_option_value_give_err(kOptVerbosefile, CSTR_AS_OPTVAL(argv[0] + argv_idx), 0);
          argv_idx = (int)strlen(argv[0]);
        }
        break;
      case 'w':    // "-w{number}" set window height
        // "-w {scriptout}" write to script
        if (ascii_isdigit((argv[0])[argv_idx])) {
          n = get_number_arg(argv[0], &argv_idx, 10);
          set_option_value_give_err(kOptWindow, NUMBER_OPTVAL((OptInt)n), 0);
          break;
        }
        want_argument = true;
        break;

      case 'c':    // "-c{command}" or "-c {command}" exec command
        if (argv[0][argv_idx] != NUL) {
          if (parmp->n_commands >= MAX_ARG_CMDS) {
            mainerr(err_extra_cmd, NULL, NULL);
          }
          parmp->commands[parmp->n_commands++] = argv[0] + argv_idx;
          argv_idx = -1;
          break;
        }
        FALLTHROUGH;
      case 'S':    // "-S {file}" execute Vim script
      case 'i':    // "-i {shada}" use for ShaDa file
      case 'l':    // "-l {file}" Lua mode
      case 'u':    // "-u {vimrc}" vim inits file
      case 'U':    // "-U {gvimrc}" gvim inits file
      case 'W':    // "-W {scriptout}" overwrite
        want_argument = true;
        break;

      default:
        mainerr(err_opt_unknown, argv[0], NULL);
      }

      // Handle option arguments with argument.
      if (want_argument) {
        // Check for garbage immediately after the option letter.
        if (argv[0][argv_idx] != NUL) {
          mainerr(err_opt_garbage, argv[0], NULL);
        }

        argc--;
        if (argc < 1 && c != 'S') {  // -S has an optional argument
          mainerr(err_arg_missing, argv[0], NULL);
        }
        argv++;
        argv_idx = -1;

        switch (c) {
        case 'c':    // "-c {command}" execute command
        case 'S':    // "-S {file}" execute Vim script
          if (parmp->n_commands >= MAX_ARG_CMDS) {
            mainerr(err_extra_cmd, NULL, NULL);
          }
          if (c == 'S') {
            char *a;

            if (argc < 1) {
              // "-S" without argument: use default session file name.
              a = SESSION_FILE;
            } else if (argv[0][0] == '-') {
              // "-S" followed by another option: use default session file.
              a = SESSION_FILE;
              argc++;
              argv--;
            } else {
              a = argv[0];
            }

            size_t s_size = strlen(a) + 9;
            char *s = xmalloc(s_size);
            snprintf(s, s_size, "so %s", a);
            parmp->cmds_tofree[parmp->n_commands] = true;
            parmp->commands[parmp->n_commands++] = s;
          } else {
            parmp->commands[parmp->n_commands++] = argv[0];
          }
          break;

        case '-':
          if (strequal(argv[-1], "--cmd")) {
            // "--cmd {command}" execute command
            if (parmp->n_pre_commands >= MAX_ARG_CMDS) {
              mainerr(err_extra_cmd, NULL, NULL);
            }
            parmp->pre_commands[parmp->n_pre_commands++] = argv[0];
          } else if (strequal(argv[-1], "--listen")) {
            // "--listen {address}"
            parmp->listen_addr = argv[0];
          } else if (strequal(argv[-1], "--server")) {
            // "--server {address}"
            parmp->server_addr = argv[0];
          }
          // "--startuptime <file>" already handled
          break;

        case 'q':    // "-q {errorfile}" QuickFix mode
          parmp->use_ef = argv[0];
          break;

        case 'i':    // "-i {shada}" use for shada
          set_option_value_give_err(kOptShadafile, CSTR_AS_OPTVAL(argv[0]), 0);
          break;

        case 'l':    // "-l" Lua script: args after "-l".
          headless_mode = true;
          silent_mode = true;
          p_verbose = 1;
          parmp->no_swap_file = true;
          parmp->use_vimrc = parmp->use_vimrc ? parmp->use_vimrc : "NONE";
          if (p_shadafile == NULL || *p_shadafile == NUL) {
            set_option_value_give_err(kOptShadafile, STATIC_CSTR_AS_OPTVAL("NONE"), 0);
          }
          parmp->luaf = argv[0];
          argc--;
          if (argc >= 0) {  // Lua args after "-l <file>".
            parmp->lua_arg0 = parmp->argc - argc;
            argc = 0;
          }
          break;

        case 's':    // "-s {scriptin}" read from script file
          if (parmp->scriptin != NULL) {
scripterror:
            vim_snprintf(IObuff, IOSIZE,
                         _("Attempt to open script file again: \"%s %s\"\n"),
                         argv[-1], argv[0]);
            fprintf(stderr, "%s", IObuff);
            os_exit(2);
          }
          parmp->scriptin = argv[0];
          break;

        case 't':    // "-t {tag}"
          parmp->tagname = argv[0];
          break;
        case 'u':    // "-u {vimrc}" vim inits file
          parmp->use_vimrc = argv[0];
          break;
        case 'U':    // "-U {gvimrc}" gvim inits file
          break;

        case 'w':    // "-w {nr}" 'window' value
          // "-w {scriptout}" append to script file
          if (ascii_isdigit(*(argv[0]))) {
            argv_idx = 0;
            n = get_number_arg(argv[0], &argv_idx, 10);
            set_option_value_give_err(kOptWindow, NUMBER_OPTVAL((OptInt)n), 0);
            argv_idx = -1;
            break;
          }
          FALLTHROUGH;
        case 'W':    // "-W {scriptout}" overwrite script file
          if (parmp->scriptout != NULL) {
            goto scripterror;
          }
          parmp->scriptout = argv[0];
          parmp->scriptout_append = (c == 'w');
        }
      }
    } else {  // File name argument.
      argv_idx = -1;  // skip to next argument

      // Check for only one type of editing.
      if (parmp->edit_type > EDIT_STDIN) {
        mainerr(err_too_many_args, argv[0], NULL);
      }
      parmp->edit_type = EDIT_FILE;

      // Add the file to the global argument list.
      ga_grow(&global_alist.al_ga, 1);
      char *p = xstrdup(argv[0]);

      // On Windows expand "~\" or "~/" prefix in file names to profile directory.
#ifdef MSWIN
      if (*p == '~' && (p[1] == '\\' || p[1] == '/')) {
        size_t size = strlen(os_homedir()) + strlen(p);
        char *tilde_expanded = xmalloc(size);
        snprintf(tilde_expanded, size, "%s%s", os_homedir(), p + 1);
        xfree(p);
        p = tilde_expanded;
      }
#endif

      if (parmp->diff_mode && os_isdir(p) && GARGCOUNT > 0
          && !os_isdir(alist_name(&GARGLIST[0]))) {
        char *r = concat_fnames(p, path_tail(alist_name(&GARGLIST[0])), true);
        xfree(p);
        p = r;
      }

#ifdef CASE_INSENSITIVE_FILENAME
      // Make the case of the file name match the actual file.
      path_fix_case(p);
#endif

      int alist_fnum_flag = edit_stdin(parmp)
                            ? 1   // add buffer nr after exp.
                            : 2;  // add buffer number now and use curbuf
      alist_add(&global_alist, p, alist_fnum_flag);
    }

    // If there are no more letters after the current "-", go to next argument.
    // argv_idx is set to -1 when the current argument is to be skipped.
    if (argv_idx <= 0 || argv[0][argv_idx] == NUL) {
      argc--;
      argv++;
      argv_idx = 1;
    }
  }

  if (embedded_mode && (silent_mode || parmp->luaf)) {
    mainerr(_("--embed conflicts with -es/-Es/-l"), NULL, NULL);
  }

  // If there is a "+123" or "-c" command, set v:swapcommand to the first one.
  if (parmp->n_commands > 0) {
    const size_t swcmd_len = strlen(parmp->commands[0]) + 3;
    char *const swcmd = xmalloc(swcmd_len);
    snprintf(swcmd, swcmd_len, ":%s\r", parmp->commands[0]);
    set_vim_var_string(VV_SWAPCOMMAND, swcmd, -1);
    xfree(swcmd);
  }

  TIME_MSG("parsing arguments");
}

// Many variables are in "params" so that we can pass them to invoked
// functions without a lot of arguments.  "argc" and "argv" are also
// copied, so that they can be changed.
static void init_params(mparm_T *paramp, int argc, char **argv)
{
  CLEAR_POINTER(paramp);
  paramp->argc = argc;
  paramp->argv = argv;
  paramp->use_debug_break_level = -1;
  paramp->window_count = -1;
  paramp->listen_addr = NULL;
  paramp->server_addr = NULL;
  paramp->remote = 0;
  paramp->luaf = NULL;
  paramp->lua_arg0 = -1;
}

/// Initialize global startuptime file if "--startuptime" passed as an argument.
static void init_startuptime(mparm_T *paramp)
{
  bool is_embed = false;
  for (int i = 1; i < paramp->argc - 1; i++) {
    if (STRICMP(paramp->argv[i], "--embed") == 0) {
      is_embed = true;
      break;
    }
  }
  for (int i = 1; i < paramp->argc - 1; i++) {
    if (STRICMP(paramp->argv[i], "--startuptime") == 0) {
      time_init(paramp->argv[i + 1], is_embed ? "Embedded" : "Primary (or UI client)");
      time_start("--- NVIM STARTING ---");
      break;
    }
  }
}

static void check_and_set_isatty(mparm_T *paramp)
{
  stdin_isatty = os_isatty(STDIN_FILENO);
  stdout_isatty = os_isatty(STDOUT_FILENO);
  stderr_isatty = os_isatty(STDERR_FILENO);
  TIME_MSG("window checked");
}

// Sets v:progname and v:progpath. Also modifies $PATH on Windows.
static void init_path(const char *exename)
  FUNC_ATTR_NONNULL_ALL
{
  char exepath[MAXPATHL] = { 0 };
  size_t exepathlen = MAXPATHL;
  // Make v:progpath absolute.
  if (os_exepath(exepath, &exepathlen) != 0) {
    // Fall back to argv[0]. Missing procfs? #6734
    path_guess_exepath(exename, exepath, sizeof(exepath));
  }
  set_vim_var_string(VV_PROGPATH, exepath, -1);
  set_vim_var_string(VV_PROGNAME, path_tail(exename), -1);

#ifdef MSWIN
  // Append the process start directory to $PATH, so that ":!foo" finds tools
  // shipped with Windows package. This also mimics SearchPath().
  os_setenv_append_path(exepath);
#endif
}

/// Get filename from command line, if any.
static char *get_fname(mparm_T *parmp, char *cwd)
{
  return alist_name(&GARGLIST[0]);
}

// Decide about window layout for diff mode after reading vimrc.
static void set_window_layout(mparm_T *paramp)
{
  if (paramp->diff_mode && paramp->window_layout == 0) {
    if (diffopt_horizontal()) {
      paramp->window_layout = WIN_HOR;             // use horizontal split
    } else {
      paramp->window_layout = WIN_VER;             // use vertical split
    }
  }
}

// "-q errorfile": Load the error file now.
// If the error file can't be read, exit before doing anything else.
static void handle_quickfix(mparm_T *paramp)
{
  if (paramp->edit_type == EDIT_QF) {
    if (paramp->use_ef != NULL) {
      set_option_direct(kOptErrorfile, CSTR_AS_OPTVAL(paramp->use_ef), 0, SID_CARG);
    }
    vim_snprintf(IObuff, IOSIZE, "cfile %s", p_ef);
    if (qf_init(NULL, p_ef, p_efm, true, IObuff, p_menc) < 0) {
      msg_putchar('\n');
      os_exit(3);
    }
    TIME_MSG("reading errorfile");
  }
}

// Need to jump to the tag before executing the '-c command'.
// Makes "vim -c '/return' -t main" work.
static void handle_tag(char *tagname)
{
  if (tagname != NULL) {
    swap_exists_did_quit = false;

    vim_snprintf(IObuff, IOSIZE, "ta %s", tagname);
    do_cmdline_cmd(IObuff);
    TIME_MSG("jumping to tag");

    // If the user doesn't want to edit the file then we quit here.
    if (swap_exists_did_quit) {
      ui_call_error_exit(1);
      getout(1);
    }
  }
}

/// Read text from stdin.
static void read_stdin(void)
{
  // When getting the ATTENTION prompt here, use a dialog.
  swap_exists_action = SEA_DIALOG;
  no_wait_return = true;
  bool save_msg_didany = msg_didany;
  set_buflisted(true);
  // Create memfile and read from stdin.
  open_buffer(true, NULL, 0);
  if (buf_is_empty(curbuf) && curbuf->b_next != NULL) {
    // stdin was empty, go to buffer 2 (e.g. "echo file1 | xargs nvim"). #8561
    do_cmdline_cmd("silent! bnext");
    // Delete the empty stdin buffer.
    do_cmdline_cmd("bwipeout 1");
  }
  no_wait_return = false;
  msg_didany = save_msg_didany;
  TIME_MSG("reading stdin");
  check_swap_exists_action();
}

// Create the requested number of windows and edit buffers in them.
// Also does recovery if "recoverymode" set.
static void create_windows(mparm_T *parmp)
{
  // Create the number of windows that was requested.
  if (parmp->window_count == -1) {      // was not set
    parmp->window_count = 1;
  }
  if (parmp->window_count == 0) {
    parmp->window_count = GARGCOUNT;
  }
  if (parmp->window_count > 1) {
    // Don't change the windows if there was a command in vimrc that
    // already split some windows
    if (parmp->window_layout == 0) {
      parmp->window_layout = WIN_HOR;
    }
    if (parmp->window_layout == WIN_TABS) {
      parmp->window_count = make_tabpages(parmp->window_count);
      TIME_MSG("making tab pages");
    } else if (firstwin->w_next == NULL) {
      parmp->window_count = make_windows(parmp->window_count,
                                         parmp->window_layout == WIN_VER);
      TIME_MSG("making windows");
    } else {
      parmp->window_count = win_count();
    }
  } else {
    parmp->window_count = 1;
  }

  if (recoverymode) {                   // do recover
    msg_scroll = true;                  // scroll message up
    ml_recover(true);
    if (curbuf->b_ml.ml_mfp == NULL) {   // failed
      getout(1);
    }
    do_modelines(0);                    // do modelines
  } else {
    int done = 0;
    // Open a buffer for windows that don't have one yet.
    // Commands in the vimrc might have loaded a file or split the window.
    // Watch out for autocommands that delete a window.
    //
    // Don't execute Win/Buf Enter/Leave autocommands here
    autocmd_no_enter++;
    autocmd_no_leave++;
    bool dorewind = true;
    while (done++ < 1000) {
      if (dorewind) {
        if (parmp->window_layout == WIN_TABS) {
          goto_tabpage(1);
        } else {
          curwin = firstwin;
        }
      } else if (parmp->window_layout == WIN_TABS) {
        if (curtab->tp_next == NULL) {
          break;
        }
        goto_tabpage(0);
      } else {
        if (curwin->w_next == NULL) {
          break;
        }
        curwin = curwin->w_next;
      }
      dorewind = false;
      curbuf = curwin->w_buffer;
      if (curbuf->b_ml.ml_mfp == NULL) {
        // Set 'foldlevel' to 'foldlevelstart' if it's not negative..
        if (p_fdls >= 0) {
          curwin->w_p_fdl = p_fdls;
        }
        // When getting the ATTENTION prompt here, use a dialog.
        swap_exists_action = SEA_DIALOG;
        set_buflisted(true);

        // create memfile, read file
        open_buffer(false, NULL, 0);

        if (swap_exists_action == SEA_QUIT) {
          if (got_int || only_one_window()) {
            // abort selected or quit and only one window
            did_emsg = false;               // avoid hit-enter prompt
            ui_call_error_exit(1);
            getout(1);
          }
          // We can't close the window, it would disturb what
          // happens next.  Clear the file name and set the arg
          // index to -1 to delete it later.
          setfname(curbuf, NULL, NULL, false);
          curwin->w_arg_idx = -1;
          swap_exists_action = SEA_NONE;
        } else {
          handle_swap_exists(NULL);
        }
        dorewind = true;                        // start again
      }
      os_breakcheck();
      if (got_int) {
        vgetc();          // only break the file loading, not the rest
        break;
      }
    }
    if (parmp->window_layout == WIN_TABS) {
      goto_tabpage(1);
    } else {
      curwin = firstwin;
    }
    curbuf = curwin->w_buffer;
    autocmd_no_enter--;
    autocmd_no_leave--;
  }
}

/// If opened more than one window, start editing files in the other
/// windows. make_windows() has already opened the windows.
static void edit_buffers(mparm_T *parmp, char *cwd)
{
  int arg_idx;                          // index in argument list
  bool advance = true;
  win_T *win;
  char *p_shm_save = NULL;

  // Don't execute Win/Buf Enter/Leave autocommands here
  autocmd_no_enter++;
  autocmd_no_leave++;

  // When w_arg_idx is -1 remove the window (see create_windows()).
  if (curwin->w_arg_idx == -1) {
    win_close(curwin, true, false);
    advance = false;
  }

  arg_idx = 1;
  for (int i = 1; i < parmp->window_count; i++) {
    if (cwd != NULL) {
      os_chdir(cwd);
    }
    // When w_arg_idx is -1 remove the window (see create_windows()).
    if (curwin->w_arg_idx == -1) {
      arg_idx++;
      win_close(curwin, true, false);
      advance = false;
      continue;
    }

    if (advance) {
      if (parmp->window_layout == WIN_TABS) {
        if (curtab->tp_next == NULL) {          // just checking
          break;
        }
        goto_tabpage(0);
        // Temporarily reset 'shm' option to not print fileinfo when
        // loading the other buffers. This would overwrite the already
        // existing fileinfo for the first tab.
        if (i == 1) {
          char buf[100];

          p_shm_save = xstrdup(p_shm);
          snprintf(buf, sizeof(buf), "F%s", p_shm);
          set_option_value_give_err(kOptShortmess, CSTR_AS_OPTVAL(buf), 0);
        }
      } else {
        if (curwin->w_next == NULL) {           // just checking
          break;
        }
        win_enter(curwin->w_next, false);
      }
    }
    advance = true;

    // Only open the file if there is no file in this window yet (that can
    // happen when vimrc contains ":sall").
    if (curbuf == firstwin->w_buffer || curbuf->b_ffname == NULL) {
      curwin->w_arg_idx = arg_idx;
      // Edit file from arg list, if there is one.  When "Quit" selected
      // at the ATTENTION prompt close the window.
      swap_exists_did_quit = false;
      do_ecmd(0, arg_idx < GARGCOUNT
              ? alist_name(&GARGLIST[arg_idx])
              : NULL, NULL, NULL, ECMD_LASTL, ECMD_HIDE, curwin);
      if (swap_exists_did_quit) {
        // abort or quit selected
        if (got_int || only_one_window()) {
          // abort selected and only one window
          did_emsg = false;             // avoid hit-enter prompt
          ui_call_error_exit(1);
          getout(1);
        }
        win_close(curwin, true, false);
        advance = false;
      }
      if (arg_idx == GARGCOUNT - 1) {
        arg_had_last = true;
      }
      arg_idx++;
    }
    os_breakcheck();
    if (got_int) {
      vgetc();            // only break the file loading, not the rest
      break;
    }
  }

  if (p_shm_save != NULL) {
    set_option_value_give_err(kOptShortmess, CSTR_AS_OPTVAL(p_shm_save), 0);
    xfree(p_shm_save);
  }

  if (parmp->window_layout == WIN_TABS) {
    goto_tabpage(1);
  }
  autocmd_no_enter--;

  // make the first window the current window
  win = firstwin;
  // Avoid making a preview window the current window.
  while (win->w_p_pvw) {
    win = win->w_next;
    if (win == NULL) {
      win = firstwin;
      break;
    }
  }
  win_enter(win, false);

  autocmd_no_leave--;
  TIME_MSG("editing files in windows");
  if (parmp->window_count > 1 && parmp->window_layout != WIN_TABS) {
    win_equal(curwin, false, 'b');      // adjust heights
  }
}

// Execute the commands from --cmd arguments "cmds[cnt]".
static void exe_pre_commands(mparm_T *parmp)
{
  char **cmds = parmp->pre_commands;
  int cnt = parmp->n_pre_commands;

  if (cnt <= 0) {
    return;
  }

  curwin->w_cursor.lnum = 0;     // just in case..
  estack_push(ETYPE_ARGS, _("pre-vimrc command line"), 0);
  current_sctx.sc_sid = SID_CMDARG;
  for (int i = 0; i < cnt; i++) {
    do_cmdline_cmd(cmds[i]);
  }
  estack_pop();
  current_sctx.sc_sid = 0;
  TIME_MSG("--cmd commands");
}

// Execute "+", "-c" and "-S" arguments.
static void exe_commands(mparm_T *parmp)
{
  // We start commands on line 0, make "vim +/pat file" match a
  // pattern on line 1.  But don't move the cursor when an autocommand
  // with g`" was used.
  msg_scroll = true;
  if (parmp->tagname == NULL && curwin->w_cursor.lnum <= 1) {
    curwin->w_cursor.lnum = 0;
  }
  estack_push(ETYPE_ARGS, "command line", 0);
  current_sctx.sc_sid = SID_CARG;
  current_sctx.sc_seq = 0;
  for (int i = 0; i < parmp->n_commands; i++) {
    do_cmdline_cmd(parmp->commands[i]);
    if (parmp->cmds_tofree[i]) {
      xfree(parmp->commands[i]);
    }
  }
  estack_pop();
  current_sctx.sc_sid = 0;
  if (curwin->w_cursor.lnum == 0) {
    curwin->w_cursor.lnum = 1;
  }

  if (!exmode_active) {
    msg_scroll = false;
  }

  // When started with "-q errorfile" jump to first error again.
  if (parmp->edit_type == EDIT_QF) {
    qf_jump(NULL, 0, 0, false);
  }
  TIME_MSG("executing command arguments");
}

/// Source system-wide vimrc if built with one defined
///
/// Does one of the following things, stops after whichever succeeds:
///
/// 1. Source system vimrc file from $XDG_CONFIG_DIRS/nvim/sysinit.vim
/// 2. Source system vimrc file from $VIM
static void do_system_initialization(void)
{
  char *const config_dirs = stdpaths_get_xdg_var(kXDGConfigDirs);
  if (config_dirs != NULL) {
    const void *iter = NULL;
    const char path_tail[] = {
      'n', 'v', 'i', 'm', PATHSEP,
      's', 'y', 's', 'i', 'n', 'i', 't', '.', 'v', 'i', 'm', NUL
    };
    do {
      const char *dir;
      size_t dir_len;
      iter = vim_env_iter(':', config_dirs, iter, &dir, &dir_len);
      if (dir == NULL || dir_len == 0) {
        break;
      }
      char *vimrc = xmalloc(dir_len + sizeof(path_tail) + 1);
      memcpy(vimrc, dir, dir_len);
      if (vimrc[dir_len - 1] != PATHSEP) {
        vimrc[dir_len] = PATHSEP;
        dir_len += 1;
      }
      memcpy(vimrc + dir_len, path_tail, sizeof(path_tail));
      if (do_source(vimrc, false, DOSO_NONE, NULL) != FAIL) {
        xfree(vimrc);
        xfree(config_dirs);
        return;
      }
      xfree(vimrc);
    } while (iter != NULL);
    xfree(config_dirs);
  }

#ifdef SYS_VIMRC_FILE
  // Get system wide defaults, if the file name is defined.
  do_source(SYS_VIMRC_FILE, false, DOSO_NONE, NULL);
#endif
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
  if (execute_env("VIMINIT") == OK) {
    do_exrc = p_exrc;
    return do_exrc;
  }

  char *init_lua_path = stdpaths_user_conf_subpath("init.lua");
  char *user_vimrc = stdpaths_user_conf_subpath("init.vim");

  // init.lua
  if (os_path_exists(init_lua_path)
      && do_source(init_lua_path, true, DOSO_VIMRC, NULL)) {
    if (os_path_exists(user_vimrc)) {
      semsg(_("E5422: Conflicting configs: \"%s\" \"%s\""), init_lua_path,
            user_vimrc);
    }

    xfree(user_vimrc);
    xfree(init_lua_path);
    do_exrc = p_exrc;
    return do_exrc;
  }
  xfree(init_lua_path);

  // init.vim
  if (do_source(user_vimrc, true, DOSO_VIMRC, NULL) != FAIL) {
    do_exrc = p_exrc;
    if (do_exrc) {
      do_exrc = (path_full_compare(VIMRC_FILE, user_vimrc, false, true) != kEqualFiles);
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
      iter = vim_env_iter(':', config_dirs, iter, &dir, &dir_len);
      if (dir == NULL || dir_len == 0) {
        break;
      }
      const char path_tail[] = { 'n', 'v', 'i', 'm', PATHSEP,
                                 'i', 'n', 'i', 't', '.', 'v', 'i', 'm', NUL };
      char *vimrc = xmalloc(dir_len + sizeof(path_tail) + 1);
      memmove(vimrc, dir, dir_len);
      vimrc[dir_len] = PATHSEP;
      memmove(vimrc + dir_len + 1, path_tail, sizeof(path_tail));
      if (do_source(vimrc, true, DOSO_VIMRC, NULL) != FAIL) {
        do_exrc = p_exrc;
        if (do_exrc) {
          do_exrc = (path_full_compare(VIMRC_FILE, vimrc, false, true) != kEqualFiles);
        }
        xfree(vimrc);
        xfree(config_dirs);
        return do_exrc;
      }
      xfree(vimrc);
    } while (iter != NULL);
    xfree(config_dirs);
  }

  if (execute_env("EXINIT") == OK) {
    do_exrc = p_exrc;
    return do_exrc;
  }
  return do_exrc;
}

// Read initialization commands from ".nvim.lua", ".nvimrc", or ".exrc" in
// current directory.  This is only done if the 'exrc' option is set.
// Only do this if VIMRC_FILE is not the same as vimrc file sourced in
// do_user_initialization.
static void do_exrc_initialization(void)
{
  char *str;

  if (os_path_exists(VIMRC_LUA_FILE)) {
    str = nlua_read_secure(VIMRC_LUA_FILE);
    if (str != NULL) {
      Error err = ERROR_INIT;
      nlua_exec(cstr_as_string(str), (Array)ARRAY_DICT_INIT, kRetNilBool, NULL, &err);
      xfree(str);
      if (ERROR_SET(&err)) {
        semsg("Error detected while processing %s:", VIMRC_LUA_FILE);
        semsg_multiline(err.msg);
        api_clear_error(&err);
      }
    }
  } else if (os_path_exists(VIMRC_FILE)) {
    str = nlua_read_secure(VIMRC_FILE);
    if (str != NULL) {
      do_source_str(str, VIMRC_FILE);
      xfree(str);
    }
  } else if (os_path_exists(EXRC_FILE)) {
    str = nlua_read_secure(EXRC_FILE);
    if (str != NULL) {
      do_source_str(str, EXRC_FILE);
      xfree(str);
    }
  }
}

/// Source startup scripts
static void source_startup_scripts(const mparm_T *const parmp)
  FUNC_ATTR_NONNULL_ALL
{
  // If -u given, use only the initializations from that file and nothing else.
  if (parmp->use_vimrc != NULL) {
    if (strequal(parmp->use_vimrc, "NONE") || strequal(parmp->use_vimrc, "NORC")) {
      // Do nothing.
    } else {
      if (do_source(parmp->use_vimrc, false, DOSO_NONE, NULL) != OK) {
        semsg(_("E282: Cannot read from \"%s\""), parmp->use_vimrc);
      }
    }
  } else if (!silent_mode) {
    do_system_initialization();

    if (do_user_initialization()) {
      do_exrc_initialization();
    }
  }
  TIME_MSG("sourcing vimrc file(s)");
}

/// Get an environment variable, and execute it as Ex commands.
///
/// @param env         environment variable to execute
///
/// @return FAIL if the environment variable was not executed,
///         OK otherwise.
static int execute_env(char *env)
  FUNC_ATTR_NONNULL_ALL
{
  const char *initstr = os_getenv(env);
  if (initstr == NULL) {
    return FAIL;
  }

  estack_push(ETYPE_ENV, env, 0);
  const sctx_T save_current_sctx = current_sctx;
  current_sctx.sc_sid = SID_ENV;
  current_sctx.sc_seq = 0;
  current_sctx.sc_lnum = 0;
  do_cmdline_cmd(initstr);

  estack_pop();
  current_sctx = save_current_sctx;
  return OK;
}

/// Prints a message of the form "{msg1}: {msg2}: {msg3}", then exits with code 1.
///
/// @param msg1  error message
/// @param msg2  extra message, or NULL
/// @param msg3  extra message, or NULL
static void mainerr(const char *msg1, const char *msg2, const char *msg3)
  FUNC_ATTR_NORETURN
{
  print_mainerr(msg1, msg2, msg3);
  os_exit(1);
}

static void print_mainerr(const char *msg1, const char *msg2, const char *msg3)
{
  char *prgname = path_tail(argv0);

  signal_stop();              // kill us with CTRL-C here, if you like

  fprintf(stderr, "%s: %s", prgname, _(msg1));
  if (msg2 != NULL) {
    fprintf(stderr, ": \"%s\"", msg2);
  }
  if (msg3 != NULL) {
    fprintf(stderr, ": \"%s\"", msg3);
  }
  fprintf(stderr, _("\nMore info with \""));
  fprintf(stderr, "%s -h\"\n", prgname);
}

/// Prints version information for "nvim -v" or "nvim --version".
static void version(void)
{
  // TODO(bfred): not like this?
  nlua_init(NULL, 0, -1);
  info_message = true;  // use stdout, not stderr
  list_version();
  msg_putchar('\n');
  msg_didout = false;
}

/// Prints help message for "nvim -h" or "nvim --help".
static void usage(void)
{
  signal_stop();              // kill us with CTRL-C here, if you like

  printf(_("Usage:\n"));
  printf(_("  nvim [options] [file ...]\n"));
  printf(_("\nOptions:\n"));
  printf(_("  --cmd <cmd>           Execute <cmd> before any config\n"));
  printf(_("  +<cmd>, -c <cmd>      Execute <cmd> after config and first file\n"));
  printf(_("  -l <script> [args...] Execute Lua <script> (with optional args)\n"));
  printf(_("  -S <session>          Source <session> after loading the first file\n"));
  printf(_("  -s <scriptin>         Read Normal mode commands from <scriptin>\n"));
  printf(_("  -u <config>           Use this config file\n"));
  printf("\n");
  printf(_("  -d                    Diff mode\n"));
  printf(_("  -es, -Es              Silent (batch) mode\n"));
  printf(_("  -h, --help            Print this help message\n"));
  printf(_("  -i <shada>            Use this shada file\n"));
  printf(_("  -n                    No swap file, use memory only\n"));
  printf(_("  -o[N]                 Open N windows (default: one per file)\n"));
  printf(_("  -O[N]                 Open N vertical windows (default: one per file)\n"));
  printf(_("  -p[N]                 Open N tab pages (default: one per file)\n"));
  printf(_("  -R                    Read-only (view) mode\n"));
  printf(_("  -v, --version         Print version information\n"));
  printf(_("  -V[N][file]           Verbose [level][file]\n"));
  printf("\n");
  printf(_("  --                    Only file names after this\n"));
  printf(_("  --api-info            Write msgpack-encoded API metadata to stdout\n"));
  printf(_("  --clean               \"Factory defaults\" (skip user config and plugins, shada)\n"));
  printf(_("  --embed               Use stdin/stdout as a msgpack-rpc channel\n"));
  printf(_("  --headless            Don't start a user interface\n"));
  printf(_("  --listen <address>    Serve RPC API from this address\n"));
  printf(_("  --remote[-subcommand] Execute commands remotely on a server\n"));
  printf(_("  --server <address>    Connect to this Nvim server\n"));
  printf(_("  --startuptime <file>  Write startup timing messages to <file>\n"));
  printf(_("\nSee \":help startup-options\" for all options.\n"));
}

// Check the result of the ATTENTION dialog:
// When "Quit" selected, exit Vim.
// When "Recover" selected, recover the file.
static void check_swap_exists_action(void)
{
  if (swap_exists_action == SEA_QUIT) {
    ui_call_error_exit(1);
    getout(1);
  }
  handle_swap_exists(NULL);
}

#ifdef ENABLE_ASAN_UBSAN
const char *__ubsan_default_options(void)
{
  return "print_stacktrace=1";
}

const char *__asan_default_options(void)
{
  return "handle_abort=1,handle_sigill=1";
}
#endif
