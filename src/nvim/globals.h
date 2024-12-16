#pragma once

#include <inttypes.h>
#include <stdbool.h>

#include "nvim/arglist_defs.h"
#include "nvim/ascii_defs.h"
#include "nvim/event/loop.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_eval_defs.h"
#include "nvim/getchar_defs.h"
#include "nvim/iconv_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/menu_defs.h"
#include "nvim/os/os_defs.h"
#include "nvim/runtime_defs.h"
#include "nvim/state_defs.h"
#include "nvim/syntax_defs.h"
#include "nvim/types_defs.h"

#define IOSIZE         (1024 + 1)          // file I/O and sprintf buffer size

#define MSG_BUF_LEN 480                 // length of buffer for small messages
#define MSG_BUF_CLEN  (MSG_BUF_LEN / 6)  // cell length (worst case: utf-8
                                         // takes 6 bytes for one cell)

// FILETYPE_FILE        used for file type detection
// FTPLUGIN_FILE        used for loading filetype plugin files
// INDENT_FILE          used for loading indent files
// FTOFF_FILE           used for file type detection
// FTPLUGOF_FILE        used for loading settings files
// INDOFF_FILE          used for loading indent files

#ifndef FILETYPE_FILE
# define FILETYPE_FILE  "filetype.lua filetype.vim"
#endif

#ifndef FTPLUGIN_FILE
# define FTPLUGIN_FILE  "ftplugin.vim"
#endif

#ifndef INDENT_FILE
# define INDENT_FILE    "indent.vim"
#endif

#ifndef FTOFF_FILE
# define FTOFF_FILE     "ftoff.vim"
#endif

#ifndef FTPLUGOF_FILE
# define FTPLUGOF_FILE  "ftplugof.vim"
#endif

#ifndef INDOFF_FILE
# define INDOFF_FILE    "indoff.vim"
#endif

#define DFLT_ERRORFILE  "errors.err"

#ifndef SYS_VIMRC_FILE
# define SYS_VIMRC_FILE "$VIM/sysinit.vim"
#endif

#ifndef DFLT_HELPFILE
# define DFLT_HELPFILE  "$VIMRUNTIME/doc/help.txt"
#endif

#ifndef SYNTAX_FNAME
# define SYNTAX_FNAME   "$VIMRUNTIME/syntax/%s.vim"
#endif

#ifndef EXRC_FILE
# define EXRC_FILE      ".exrc"
#endif

#ifndef VIMRC_FILE
# define VIMRC_FILE     ".nvimrc"
#endif

#ifndef VIMRC_LUA_FILE
# define VIMRC_LUA_FILE ".nvim.lua"
#endif

EXTERN struct nvim_stats_s {
  int64_t fsync;
  int64_t redraw;
  int16_t log_skip;  // How many logs were tried and skipped before log_init.
} g_stats INIT( = { 0, 0, 0 });

// Values for "starting".
#define NO_SCREEN       2       // no screen updating yet
#define NO_BUFFERS      1       // not all buffers loaded yet
//                      0          not starting anymore

// Number of Rows and Columns in the screen.
// Note: Use default_grid.rows and default_grid.cols to access items in
// default_grid.chars[]. They may have different values when the screen
// wasn't (re)allocated yet after setting Rows or Columns (e.g., when starting
// up).
#define DFLT_COLS       80              // default value for 'columns'
#define DFLT_ROWS       24              // default value for 'lines'
EXTERN int Rows INIT( = DFLT_ROWS);     // nr of rows in the screen
EXTERN int Columns INIT( = DFLT_COLS);  // nr of columns in the screen

// When vgetc() is called, it sets mod_mask to the set of modifiers that are
// held down based on the MOD_MASK_* symbols that are read first.
EXTERN int mod_mask INIT( = 0);  // current key modifiers

// The value of "mod_mask" and the unmodified character in vgetc() after it has
// called vgetorpeek() enough times.
EXTERN int vgetc_mod_mask INIT( = 0);
EXTERN int vgetc_char INIT( = 0);

// Cmdline_row is the row where the command line starts, just below the
// last window.
// When the cmdline gets longer than the available space the screen gets
// scrolled up. After a CTRL-D (show matches), after hitting ':' after
// "hit return", and for the :global command, the command line is
// temporarily moved.  The old position is restored with the next call to
// update_screen().
EXTERN int cmdline_row;

EXTERN bool redraw_cmdline INIT( = false);          // cmdline must be redrawn
EXTERN bool redraw_mode INIT( = false);             // mode must be redrawn
EXTERN bool clear_cmdline INIT( = false);           // cmdline must be cleared
EXTERN bool mode_displayed INIT( = false);          // mode is being displayed
EXTERN int cmdline_star INIT( = 0);                 // cmdline is encrypted
EXTERN bool redrawing_cmdline INIT( = false);       // cmdline is being redrawn
EXTERN bool cmdline_was_last_drawn INIT( = false);  // cmdline was last drawn

EXTERN bool exec_from_reg INIT( = false);         // executing register

// When '$' is included in 'cpoptions' option set:
// When a change command is given that deletes only part of a line, a dollar
// is put at the end of the changed text. dollar_vcol is set to the virtual
// column of this '$'.  -1 is used to indicate no $ is being displayed.
EXTERN colnr_T dollar_vcol INIT( = -1);

// Variables for Insert mode completion.

EXTERN char *edit_submode INIT( = NULL);         // msg for CTRL-X submode
EXTERN char *edit_submode_pre INIT( = NULL);     // prepended to edit_submode
EXTERN char *edit_submode_extra INIT( = NULL);   // appended to edit_submode
EXTERN hlf_T edit_submode_highl;                // highl. method for extra info

// state for putting characters in the message area
EXTERN bool cmdmsg_rl INIT( = false);  // cmdline is drawn right to left
EXTERN int msg_col;
EXTERN int msg_row;
EXTERN int msg_scrolled;  ///< Number of screen lines that messages have scrolled.
// when true don't set need_wait_return in msg_puts_attr()
// when msg_scrolled is non-zero
EXTERN bool msg_scrolled_ign INIT( = false);
// Whether the screen is damaged due to scrolling. Sometimes msg_scrolled
// is reset before the screen is redrawn, so we need to keep track of this.
EXTERN bool msg_did_scroll INIT( = false);

EXTERN char *keep_msg INIT( = NULL);         // msg to be shown after redraw
EXTERN int keep_msg_hl_id INIT( = 0);        // highlight id for keep_msg
EXTERN bool need_fileinfo INIT( = false);    // do fileinfo() after redraw
EXTERN int msg_scroll INIT( = false);        // msg_start() will scroll
EXTERN bool msg_didout INIT( = false);       // msg_outstr() was used in line
EXTERN bool msg_didany INIT( = false);       // msg_outstr() was used at all
EXTERN bool msg_nowait INIT( = false);       // don't wait for this msg
EXTERN int emsg_off INIT( = 0);              // don't display errors for now,
                                             // unless 'debug' is set.
EXTERN bool info_message INIT( = false);     // printing informative message
EXTERN bool msg_hist_off INIT( = false);     // don't add messages to history
EXTERN bool need_clr_eos INIT( = false);     // need to clear text before
                                             // displaying a message.
EXTERN int emsg_skip INIT( = 0);             // don't display errors for
                                             // expression that is skipped
EXTERN bool emsg_severe INIT( = false);      // use message of next of several
                                             //  emsg() calls for throw
// used by assert_fails()
EXTERN char *emsg_assert_fails_msg INIT( = NULL);
EXTERN long emsg_assert_fails_lnum INIT( = 0);
EXTERN char *emsg_assert_fails_context INIT( = NULL);

EXTERN bool did_endif INIT( = false);        // just had ":endif"
EXTERN dict_T vimvardict;                   // Dict with v: variables
EXTERN dict_T globvardict;                  // Dict with g: variables
/// g: value
#define globvarht globvardict.dv_hashtab
EXTERN int did_emsg;                        // incremented by emsg() when a
                                            // message is displayed or thrown
EXTERN bool called_vim_beep;                // set if vim_beep() is called
EXTERN bool did_emsg_syntax;                // did_emsg set because of a
                                            // syntax error
EXTERN int called_emsg;                     // always incremented by emsg()
EXTERN int ex_exitval INIT( = 0);            // exit value for ex mode
EXTERN bool emsg_on_display INIT( = false);  // there is an error message
EXTERN bool rc_did_emsg INIT( = false);      // vim_regcomp() called emsg()

EXTERN int no_wait_return INIT( = 0);         // don't wait for return for now
EXTERN bool need_wait_return INIT( = false);  // need to wait for return later
EXTERN bool did_wait_return INIT( = false);   // wait_return() was used and
                                              // nothing written since then
EXTERN bool need_maketitle INIT( = true);     // call maketitle() soon

EXTERN bool quit_more INIT( = false);        // 'q' hit at "--more--" msg
EXTERN int vgetc_busy INIT( = 0);            // when inside vgetc() then > 0

EXTERN bool didset_vim INIT( = false);         // did set $VIM ourselves
EXTERN bool didset_vimruntime INIT( = false);  // idem for $VIMRUNTIME

/// Lines left before a "more" message.  Ex mode needs to be able to reset this
/// after you type something.
EXTERN int lines_left INIT( = -1);           // lines left for listing
EXTERN bool msg_no_more INIT( = false);      // don't use more prompt, truncate
                                             // messages

EXTERN int ex_nesting_level INIT( = 0);          // nesting level
EXTERN int debug_break_level INIT( = -1);        // break below this level
EXTERN bool debug_did_msg INIT( = false);        // did "debug mode" message
EXTERN int debug_tick INIT( = 0);                // breakpoint change count
EXTERN int debug_backtrace_level INIT( = 0);     // breakpoint backtrace level

// Values for "do_profiling".
#define PROF_NONE       0       ///< profiling not started
#define PROF_YES        1       ///< profiling busy
#define PROF_PAUSED     2       ///< profiling paused
EXTERN int do_profiling INIT( = PROF_NONE);      ///< PROF_ values

/// Exception currently being thrown.  Used to pass an exception to a different
/// cstack.  Also used for discarding an exception before it is caught or made
/// pending.  Only valid when did_throw is true.
EXTERN except_T *current_exception;

/// An exception is being thrown.  Reset when the exception is caught or as
/// long as it is pending in a finally clause.
EXTERN bool did_throw INIT( = false);

/// Set when a throw that cannot be handled in do_cmdline() must be propagated
/// to the cstack of the previously called do_cmdline().
EXTERN bool need_rethrow INIT( = false);

/// Set when a ":finish" or ":return" that cannot be handled in do_cmdline()
/// must be propagated to the cstack of the previously called do_cmdline().
EXTERN bool check_cstack INIT( = false);

/// Number of nested try conditionals (across function calls and ":source"
/// commands).
EXTERN int trylevel INIT( = 0);

/// When "force_abort" is true, always skip commands after an error message,
/// even after the outermost ":endif", ":endwhile" or ":endfor" or for a
/// function without the "abort" flag.  It is set to true when "trylevel" is
/// non-zero (and ":silent!" was not used) or an exception is being thrown at
/// the time an error is detected.  It is set to false when "trylevel" gets
/// zero again and there was no error or interrupt or throw.
EXTERN bool force_abort INIT( = false);

/// "msg_list" points to a variable in the stack of do_cmdline() which keeps
/// the list of arguments of several emsg() calls, one of which is to be
/// converted to an error exception immediately after the failing command
/// returns.  The message to be used for the exception value is pointed to by
/// the "throw_msg" field of the first element in the list.  It is usually the
/// same as the "msg" field of that element, but can be identical to the "msg"
/// field of a later list element, when the "emsg_severe" flag was set when the
/// emsg() call was made.
EXTERN msglist_T **msg_list INIT( = NULL);

/// When set, don't convert an error to an exception.  Used when displaying the
/// interrupt message or reporting an exception that is still uncaught at the
/// top level (which has already been discarded then).  Also used for the error
/// message when no exception can be thrown.
EXTERN bool suppress_errthrow INIT( = false);

/// The stack of all caught and not finished exceptions.  The exception on the
/// top of the stack is the one got by evaluation of v:exception.  The complete
/// stack of all caught and pending exceptions is embedded in the various
/// cstacks; the pending exceptions, however, are not on the caught stack.
EXTERN except_T *caught_stack INIT( = NULL);

///
/// Garbage collection can only take place when we are sure there are no Lists
/// or Dictionaries being used internally.  This is flagged with
/// "may_garbage_collect" when we are at the toplevel.
/// "want_garbage_collect" is set by the garbagecollect() function, which means
/// we do garbage collection before waiting for a char at the toplevel.
/// "garbage_collect_at_exit" indicates garbagecollect(1) was called.
///
EXTERN bool may_garbage_collect INIT( = false);
EXTERN bool want_garbage_collect INIT( = false);
EXTERN bool garbage_collect_at_exit INIT( = false);

// Special values for current_SID.
#define SID_MODELINE    (-1)      // when using a modeline
#define SID_CMDARG      (-2)      // for "--cmd" argument
#define SID_CARG        (-3)      // for "-c" argument
#define SID_ENV         (-4)      // for sourcing environment variable
#define SID_ERROR       (-5)      // option was reset because of an error
#define SID_NONE        (-6)      // don't set scriptID
#define SID_WINLAYOUT   (-7)      // changing window size
#define SID_LUA         (-8)      // for Lua scripts/chunks
#define SID_API_CLIENT  (-9)      // for API clients
#define SID_STR         (-10)     // for sourcing a string with no script item

// Script CTX being sourced or was sourced to define the current function.
EXTERN sctx_T current_sctx INIT( = { 0, 0, 0 });
// ID of the current channel making a client API call
EXTERN uint64_t current_channel_id INIT( = 0);

EXTERN bool did_source_packages INIT( = false);

// Scope information for the code that indirectly triggered the current
// provider function call
EXTERN struct caller_scope {
  sctx_T script_ctx;
  estack_T es_entry;
  char *autocmd_fname, *autocmd_match;
  bool autocmd_fname_full;
  int autocmd_bufnr;
  void *funccalp;
} provider_caller_scope;
EXTERN int provider_call_nesting INIT( = 0);

EXTERN int t_colors INIT( = 256);                // int value of T_CCO

// Flags to indicate an additional string for highlight name completion.
EXTERN int include_none INIT( = 0);     // when 1 include "None"
EXTERN int include_default INIT( = 0);  // when 1 include "default"
EXTERN int include_link INIT( = 0);     // when 2 include "link" and "clear"

// When highlight_match is true, highlight a match, starting at the cursor
// position.  Search_match_lines is the number of lines after the match (0 for
// a match within one line), search_match_endcol the column number of the
// character just after the match in the last line.
EXTERN bool highlight_match INIT( = false);         // show search match pos
EXTERN linenr_T search_match_lines;                // lines of matched string
EXTERN colnr_T search_match_endcol;                // col nr of match end
EXTERN linenr_T search_first_line INIT( = 0);       // for :{FIRST},{last}s/pat
EXTERN linenr_T search_last_line INIT( = MAXLNUM);  // for :{first},{LAST}s/pat

EXTERN bool no_smartcase INIT( = false);          // don't use 'smartcase' once

EXTERN bool need_check_timestamps INIT( = false);  // need to check file
                                                   // timestamps asap
EXTERN bool did_check_timestamps INIT( = false);   // did check timestamps
                                                   // recently
EXTERN int no_check_timestamps INIT( = 0);         // Don't check timestamps

// Mouse coordinates, set by handle_mouse_event()
EXTERN int mouse_grid;
EXTERN int mouse_row;
EXTERN int mouse_col;
EXTERN bool mouse_past_bottom INIT( = false);  // mouse below last line
EXTERN bool mouse_past_eol INIT( = false);     // mouse right of line
EXTERN int mouse_dragging INIT( = 0);          // extending Visual area with
                                               // mouse dragging

// The root of the menu hierarchy.
EXTERN vimmenu_T *root_menu INIT( = NULL);
// While defining the system menu, sys_menu is true.  This avoids
// overruling of menus that the user already defined.
EXTERN bool sys_menu INIT( = false);

// All windows are linked in a list. firstwin points to the first entry,
// lastwin to the last entry (can be the same as firstwin) and curwin to the
// currently active window.
EXTERN win_T *firstwin;              // first window
EXTERN win_T *lastwin;               // last window
EXTERN win_T *prevwin INIT( = NULL);  // previous window (may equal curwin)
#define ONE_WINDOW (firstwin == lastwin)
#define FOR_ALL_FRAMES(frp, first_frame) \
  for ((frp) = first_frame; (frp) != NULL; (frp) = (frp)->fr_next)

// When using this macro "break" only breaks out of the inner loop. Use "goto"
// to break out of the tabpage loop.
#define FOR_ALL_TAB_WINDOWS(tp, wp) \
  FOR_ALL_TABS(tp) \
  FOR_ALL_WINDOWS_IN_TAB(wp, tp)

#define FOR_ALL_WINDOWS_IN_TAB(wp, tp) \
  for (win_T *wp = ((tp) == curtab) ? firstwin : (tp)->tp_firstwin; \
       wp != NULL; wp = wp->w_next)

EXTERN win_T *curwin;        // currently active window

// The window layout is kept in a tree of frames.  topframe points to the top
// of the tree.
EXTERN frame_T *topframe;      // top of the window frame tree

// Tab pages are alternative topframes.  "first_tabpage" points to the first
// one in the list, "curtab" is the current one. "lastused_tabpage" is the
// last used one.
EXTERN tabpage_T *first_tabpage;
EXTERN tabpage_T *curtab;
EXTERN tabpage_T *lastused_tabpage;
EXTERN bool redraw_tabline INIT( = false);  // need to redraw tabline

// Iterates over all tabs in the tab list
#define FOR_ALL_TABS(tp) for (tabpage_T *(tp) = first_tabpage; (tp) != NULL; (tp) = (tp)->tp_next)

// All buffers are linked in a list. 'firstbuf' points to the first entry,
// 'lastbuf' to the last entry and 'curbuf' to the currently active buffer.
EXTERN buf_T    *firstbuf INIT( = NULL);  // first buffer
EXTERN buf_T *lastbuf INIT( = NULL);   // last buffer
EXTERN buf_T *curbuf INIT( = NULL);    // currently active buffer

// Iterates over all buffers in the buffer list.
#define FOR_ALL_BUFFERS(buf) \
  for (buf_T *buf = firstbuf; buf != NULL; buf = buf->b_next)
#define FOR_ALL_BUFFERS_BACKWARDS(buf) \
  for (buf_T *buf = lastbuf; buf != NULL; buf = buf->b_prev)

// List of files being edited (global argument list).  curwin->w_alist points
// to this when the window is using the global argument list.
EXTERN alist_T global_alist;    // global argument list
EXTERN int max_alist_id INIT( = 0);     ///< the previous argument list id
EXTERN bool arg_had_last INIT( = false);     // accessed last file in
                                             // global_alist

EXTERN int ru_col;              // column for ruler
EXTERN int ru_wid;              // 'rulerfmt' width of ruler when non-zero
EXTERN int sc_col;              // column for shown command

// When starting or exiting some things are done differently (e.g. screen
// updating).

// First NO_SCREEN, then NO_BUFFERS, then 0 when startup finished.
EXTERN int starting INIT( = NO_SCREEN);
// true when planning to exit. Might keep running if there is a changed buffer.
EXTERN bool exiting INIT( = false);
// internal value of v:dying
EXTERN int v_dying INIT( = 0);
// is stdin a terminal?
EXTERN bool stdin_isatty INIT( = true);
// is stdout a terminal?
EXTERN bool stdout_isatty INIT( = true);
// is stderr a terminal?
EXTERN bool stderr_isatty INIT( = true);

/// filedesc set by embedder for reading first buffer like `cmd | nvim -`
EXTERN int stdin_fd INIT( = -1);

// true when doing full-screen output, otherwise only writing some messages.
EXTERN bool full_screen INIT( = false);

/// Non-zero when only "safe" commands are allowed
EXTERN int secure INIT( = 0);

/// Non-zero when changing text and jumping to another window or editing another buffer is not
/// allowed.
EXTERN int textlock INIT( = 0);

/// Non-zero when no buffer name can be changed, no buffer can be deleted and
/// current directory can't be changed. Used for SwapExists et al.
EXTERN int allbuf_lock INIT( = 0);

/// Non-zero when evaluating an expression in a "sandbox".  Several things are
/// not allowed then.
EXTERN int sandbox INIT( = 0);

/// Batch-mode: "-es", "-Es", "-l" commandline argument was given.
EXTERN bool silent_mode INIT( = false);

/// Start position of active Visual selection.
EXTERN pos_T VIsual;
/// Whether Visual mode is active.
EXTERN bool VIsual_active INIT( = false);
/// Whether Select mode is active.
EXTERN bool VIsual_select INIT( = false);
/// Register name for Select mode
EXTERN int VIsual_select_reg INIT( = 0);
/// Restart Select mode when next cmd finished
EXTERN int restart_VIsual_select INIT( = 0);
/// Whether to restart the selection after a Select-mode mapping or menu.
EXTERN int VIsual_reselect;
/// Type of Visual mode.
EXTERN int VIsual_mode INIT( = 'v');
/// true when redoing Visual.
EXTERN bool redo_VIsual_busy INIT( = false);

// The Visual area is remembered for reselection.
EXTERN int resel_VIsual_mode INIT( = NUL);       // 'v', 'V', or Ctrl-V
EXTERN linenr_T resel_VIsual_line_count;        // number of lines
EXTERN colnr_T resel_VIsual_vcol;               // nr of cols or end col

/// When pasting text with the middle mouse button in visual mode with
/// restart_edit set, remember where it started so we can set Insstart.
EXTERN pos_T where_paste_started;

// This flag is used to make auto-indent work right on lines where only a
// <RETURN> or <ESC> is typed. It is set when an auto-indent is done, and
// reset when any other editing is done on the line. If an <ESC> or <RETURN>
// is received, and did_ai is true, the line is truncated.
EXTERN bool did_ai INIT( = false);

// Column of first char after autoindent.  0 when no autoindent done.  Used
// when 'backspace' is 0, to avoid backspacing over autoindent.
EXTERN colnr_T ai_col INIT( = 0);

// This is a character which will end a start-middle-end comment when typed as
// the first character on a new line.  It is taken from the last character of
// the "end" comment leader when the COM_AUTO_END flag is given for that
// comment end in 'comments'.  It is only valid when did_ai is true.
EXTERN int end_comment_pending INIT( = NUL);

// This flag is set after a ":syncbind" to let the check_scrollbind() function
// know that it should not attempt to perform scrollbinding due to the scroll
// that was a result of the ":syncbind." (Otherwise, check_scrollbind() will
// undo some of the work done by ":syncbind.")  -ralston
EXTERN bool did_syncbind INIT( = false);

// This flag is set when a smart indent has been performed. When the next typed
// character is a '{' the inserted tab will be deleted again.
EXTERN bool did_si INIT( = false);

// This flag is set after an auto indent. If the next typed character is a '}'
// one indent will be removed.
EXTERN bool can_si INIT( = false);

// This flag is set after an "O" command. If the next typed character is a '{'
// one indent will be removed.
EXTERN bool can_si_back INIT( = false);

EXTERN int old_indent INIT( = 0);  ///< for ^^D command in insert mode

// w_cursor before formatting text.
EXTERN pos_T saved_cursor INIT( = { 0, 0, 0 });

// Stuff for insert mode.
EXTERN pos_T Insstart;                  // This is where the latest
                                        // insert/append mode started.

// This is where the latest insert/append mode started. In contrast to
// Insstart, this won't be reset by certain keys and is needed for
// op_insert(), to detect correctly where inserting by the user started.
EXTERN pos_T Insstart_orig;

// Stuff for MODE_VREPLACE state.
EXTERN linenr_T orig_line_count INIT( = 0);       // Line count when "gR" started
EXTERN int vr_lines_changed INIT( = 0);      // #Lines changed by "gR" so far

// increase around internal delete/replace
EXTERN int inhibit_delete_count INIT( = 0);

// These flags are set based upon 'fileencoding'.
// The characters are internally stored as UTF-8
// to avoid trouble with NUL bytes.
#define DBCS_JPN       932     // japan
#define DBCS_JPNU      9932    // euc-jp
#define DBCS_KOR       949     // korea
#define DBCS_KORU      9949    // euc-kr
#define DBCS_CHS       936     // chinese
#define DBCS_CHSU      9936    // euc-cn
#define DBCS_CHT       950     // taiwan
#define DBCS_CHTU      9950    // euc-tw
#define DBCS_2BYTE     1       // 2byte-
#define DBCS_DEBUG     (-1)

/// Encoding used when 'fencs' is set to "default"
EXTERN char *fenc_default INIT( = NULL);

/// "State" is the main state of Vim.
/// There are other variables that modify the state:
///    Visual_mode:    When State is MODE_NORMAL or MODE_INSERT.
///    finish_op  :    When State is MODE_NORMAL, after typing the operator and
///                    before typing the motion command.
///    motion_force:   Last motion_force from do_pending_operator()
///    debug_mode:     Debug mode
EXTERN int State INIT( = MODE_NORMAL);

EXTERN bool debug_mode INIT( = false);
EXTERN bool finish_op INIT( = false);    // true while an operator is pending
EXTERN int opcount INIT( = 0);           // count for pending operator
EXTERN int motion_force INIT( = 0);      // motion force for pending operator

// Ex Mode (Q) state
EXTERN bool exmode_active INIT( = false);  // true if Ex mode is active

/// Flag set when normal_check() should return 0 when entering Ex mode.
EXTERN bool pending_exmode_active INIT( = false);

EXTERN bool ex_no_reprint INIT( = false);   // No need to print after z or p.

// 'inccommand' command preview state
EXTERN bool cmdpreview INIT( = false);

EXTERN int reg_recording INIT( = 0);     // register for recording  or zero
EXTERN int reg_executing INIT( = 0);     // register being executed or zero
// Flag set when peeking a character and found the end of executed register
EXTERN bool pending_end_reg_executing INIT( = false);
EXTERN int reg_recorded INIT( = 0);      // last recorded register or zero

EXTERN int no_mapping INIT( = 0);        // currently no mapping allowed
EXTERN int no_zero_mapping INIT( = 0);   // mapping zero not allowed
EXTERN int allow_keys INIT( = 0);        // allow key codes when no_mapping is set
EXTERN int no_u_sync INIT( = 0);         // Don't call u_sync()
EXTERN int u_sync_once INIT( = 0);       // Call u_sync() once when evaluating
                                         // an expression.

EXTERN bool force_restart_edit INIT( = false);  // force restart_edit after
                                                // ex_normal returns
EXTERN int restart_edit INIT( = 0);      // call edit when next cmd finished
EXTERN bool arrow_used;                  // Normally false, set to true after
                                         // hitting cursor key in insert mode.
                                         // Used by vgetorpeek() to decide when
                                         // to call u_sync()
EXTERN bool ins_at_eol INIT( = false);   // put cursor after eol when
                                         // restarting edit after CTRL-O

EXTERN bool no_abbr INIT( = true);       // true when no abbreviations loaded

EXTERN int mapped_ctrl_c INIT( = 0);  // Modes where CTRL-C is mapped.
EXTERN bool ctrl_c_interrupts INIT( = true);  // CTRL-C sets got_int

EXTERN cmdmod_T cmdmod;                 // Ex command modifiers

EXTERN int msg_silent INIT( = 0);         // don't print messages
EXTERN int emsg_silent INIT( = 0);        // don't print error messages
EXTERN bool emsg_noredir INIT( = false);  // don't redirect error messages
EXTERN bool cmd_silent INIT( = false);    // don't echo the command line

EXTERN bool in_assert_fails INIT( = false);  // assert_fails() active

// Values for swap_exists_action: what to do when swap file already exists
#define SEA_NONE        0       // don't use dialog
#define SEA_DIALOG      1       // use dialog when possible
#define SEA_QUIT        2       // quit editing the file
#define SEA_RECOVER     3       // recover the file
#define SEA_READONLY    4       // no dialog, mark buffer as read-only

EXTERN int swap_exists_action INIT( = SEA_NONE);  ///< For dialog when swap file already exists.
EXTERN bool swap_exists_did_quit INIT( = false);  ///< Selected "quit" at the dialog.

EXTERN char IObuff[IOSIZE];                 ///< Buffer for sprintf, I/O, etc.
EXTERN char NameBuff[MAXPATHL];             ///< Buffer for expanding file names
EXTERN char msg_buf[MSG_BUF_LEN];           ///< Small buffer for messages
EXTERN char os_buf[                         ///< Buffer for the os/ layer
#if MAXPATHL > IOSIZE
                                            MAXPATHL
#else
                                            IOSIZE
#endif
];

// When non-zero, postpone redrawing.
EXTERN int RedrawingDisabled INIT( = 0);

EXTERN bool readonlymode INIT( = false);      // Set to true for "view"
EXTERN bool recoverymode INIT( = false);      // Set to true for "-r" option

// typeahead buffer
EXTERN typebuf_T typebuf INIT( = { NULL, NULL, 0, 0, 0, 0, 0, 0, 0 });

/// Flag used to indicate that vgetorpeek() returned a char like Esc when the
/// :normal argument was exhausted.
EXTERN bool typebuf_was_empty INIT( = false);

EXTERN int ex_normal_busy INIT( = 0);      // recursiveness of ex_normal()
EXTERN int expr_map_lock INIT( = 0);       // running expr mapping, prevent use of ex_normal() and text changes
EXTERN bool ignore_script INIT( = false);  // ignore script input
EXTERN bool stop_insert_mode;              // for ":stopinsert"
EXTERN bool KeyTyped;                      // true if user typed current char
EXTERN int KeyStuffed;                     // true if current char from stuffbuf
EXTERN int maptick INIT( = 0);             // tick for each non-mapped char

EXTERN int must_redraw INIT( = 0);           // type of redraw necessary
EXTERN bool skip_redraw INIT( = false);      // skip redraw once
EXTERN bool do_redraw INIT( = false);        // extra redraw once
EXTERN bool must_redraw_pum INIT( = false);  // redraw pum. NB: must_redraw
                                             // should also be set.

EXTERN bool need_highlight_changed INIT( = true);

EXTERN FILE *scriptout INIT( = NULL);  ///< Write input to this file ("nvim -w").

// Note that even when handling SIGINT, volatile is not necessary because the
// callback is not called directly from the signal handlers.
EXTERN bool got_int INIT( = false);          // set to true when interrupt signal occurred
EXTERN bool bangredo INIT( = false);         // set to true with ! command
EXTERN int searchcmdlen;                    // length of previous search cmd
EXTERN int reg_do_extmatch INIT( = 0);       // Used when compiling regexp:
                                             // REX_SET to allow \z\(...\),
                                             // REX_USE to allow \z\1 et al.
// Used by vim_regexec(): strings for \z\1...\z\9
EXTERN reg_extmatch_T *re_extmatch_in INIT( = NULL);
// Set by vim_regexec() to store \z\(...\) matches
EXTERN reg_extmatch_T *re_extmatch_out INIT( = NULL);

EXTERN bool did_outofmem_msg INIT( = false);  ///< set after out of memory msg
EXTERN bool did_swapwrite_msg INIT( = false);  ///< set after swap write error msg
EXTERN int global_busy INIT( = 0);           ///< set when :global is executing
EXTERN bool listcmd_busy INIT( = false);     ///< set when :argdo, :windo or :bufdo is executing
EXTERN bool need_start_insertmode INIT( = false);  ///< start insert mode soon

#define MODE_MAX_LENGTH 4       // max mode length returned in get_mode(),
                                // including the terminating NUL

EXTERN char last_mode[MODE_MAX_LENGTH] INIT( = "n");
EXTERN char *last_cmdline INIT( = NULL);        // last command line (for ":)
EXTERN char *repeat_cmdline INIT( = NULL);      // command line for "."
EXTERN char *new_last_cmdline INIT( = NULL);    // new value for last_cmdline

EXTERN int postponed_split INIT( = 0);        // for CTRL-W CTRL-] command
EXTERN int postponed_split_flags INIT( = 0);  // args for win_split()
EXTERN int postponed_split_tab INIT( = 0);    // cmdmod.cmod_tab
EXTERN int g_do_tagpreview INIT( = 0);  // for tag preview commands:
                                        // height of preview window
EXTERN bool g_tag_at_cursor INIT( = false);  // whether the tag command comes
                                             // from the command line (0) or was
                                             // invoked as a normal command (1)

EXTERN int replace_offset INIT( = 0);        // offset for replace_push()

EXTERN char *escape_chars INIT( = " \t\\\"|");  // need backslash in cmd line

EXTERN bool keep_help_flag INIT( = false);  // doing :ta from help file

EXTERN bool redir_off INIT( = false);        // no redirection for a moment
EXTERN FILE *redir_fd INIT( = NULL);         // message redirection file
EXTERN int redir_reg INIT( = 0);             // message redirection register
EXTERN bool redir_vname INIT( = false);      // message redirection variable
EXTERN garray_T *capture_ga INIT( = NULL);   // captured output for execute()

EXTERN uint8_t langmap_mapchar[256];     // mapping for language keys

EXTERN int save_p_ls INIT( = -1);        // Save 'laststatus' setting
EXTERN int save_p_wmh INIT( = -1);       // Save 'winminheight' setting
EXTERN int wild_menu_showing INIT( = 0);
enum {
  WM_SHOWN = 1,     ///< wildmenu showing
  WM_SCROLLED = 2,  ///< wildmenu showing with scroll
  WM_LIST = 3,      ///< cmdline CTRL-D
};

// When a window has a local directory, the absolute path of the global
// current directory is stored here (in allocated memory).  If the current
// directory is not a local directory, globaldir is NULL.
EXTERN char *globaldir INIT( = NULL);

EXTERN char *last_chdir_reason INIT( = NULL);

// Whether 'keymodel' contains "stopsel" and "startsel".
EXTERN bool km_stopsel INIT( = false);
EXTERN bool km_startsel INIT( = false);

EXTERN int cmdwin_type INIT( = 0);    ///< type of cmdline window or 0
EXTERN int cmdwin_result INIT( = 0);  ///< result of cmdline window or 0
EXTERN int cmdwin_level INIT( = 0);   ///< cmdline recursion level
EXTERN buf_T *cmdwin_buf INIT( = NULL);  ///< buffer of cmdline window or NULL
EXTERN win_T *cmdwin_win INIT( = NULL);  ///< window of cmdline window or NULL
EXTERN win_T *cmdwin_old_curwin INIT( = NULL);  ///< curwin before opening cmdline window or NULL

EXTERN char no_lines_msg[] INIT( = N_("--No lines in buffer--"));

// When ":global" is used to number of substitutions and changed lines is
// accumulated until it's finished.
// Also used for ":spellrepall".
EXTERN int sub_nsubs;        // total number of substitutions
EXTERN linenr_T sub_nlines;  // total number of lines changed

// table to store parsed 'wildmode'
EXTERN uint8_t wim_flags[4];

// whether titlestring and iconstring contains statusline syntax
#define STL_IN_ICON    1
#define STL_IN_TITLE   2
EXTERN int stl_syntax INIT( = 0);

// don't use 'hlsearch' temporarily
EXTERN bool no_hlsearch INIT( = false);

EXTERN bool typebuf_was_filled INIT( = false);     // received text from client
                                                   // or from feedkeys()

#ifdef BACKSLASH_IN_FILENAME
EXTERN char psepc INIT( = '\\');            // normal path separator character
EXTERN char psepcN INIT( = '/');            // abnormal path separator character
EXTERN char pseps[2] INIT( = { '\\', 0 });  // normal path separator string
#endif

// Set to kTrue when an operator is being executed with virtual editing
// kNone when no operator is being executed, kFalse otherwise.
EXTERN TriState virtual_op INIT( = kNone);

// Display tick, incremented for each call to update_screen()
EXTERN disptick_T display_tick INIT( = 0);

// Line in which spell checking wasn't highlighted because it touched the
// cursor position in Insert mode.
EXTERN linenr_T spell_redraw_lnum INIT( = 0);

EXTERN FILE *time_fd INIT( = NULL);  // Where to write --startuptime report.

// Some compilers warn for not using a return value, but in some situations we
// can't do anything useful with the value.  Assign to this variable to avoid
// the warning.
EXTERN int vim_ignored;

// stdio is an RPC channel (--embed).
EXTERN bool embedded_mode INIT( = false);
// Do not start UI (--headless, -l) nor read/write to stdio (unless embedding).
EXTERN bool headless_mode INIT( = false);

/// Only filled for Win32.
EXTERN char windowsVersion[20] INIT( = { 0 });

/// While executing a regexp and set to OPTION_MAGIC_ON or OPTION_MAGIC_OFF this
/// overrules p_magic.  Otherwise set to OPTION_MAGIC_NOT_SET.
EXTERN optmagic_T magic_overruled INIT( = OPTION_MAGIC_NOT_SET);

/// Skip win_fix_cursor() call for 'splitkeep' when cmdwin is closed.
EXTERN bool skip_win_fix_cursor INIT( = false);
/// Skip win_fix_scroll() call for 'splitkeep' when closing tab page.
EXTERN bool skip_win_fix_scroll INIT( = false);
/// Skip update_topline() call while executing win_fix_scroll().
EXTERN bool skip_update_topline INIT( = false);
