// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * ex_getln.c: Functions for entering and editing an Ex command line.
 */

#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>

#include "nvim/assert.h"
#include "nvim/log.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/arabic.h"
#include "nvim/ex_getln.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/digraph.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/farsi.h"
#include "nvim/fileio.h"
#include "nvim/func_attr.h"
#include "nvim/getchar.h"
#include "nvim/highlight.h"
#include "nvim/if_cscope.h"
#include "nvim/indent.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/menu.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/memory.h"
#include "nvim/cursor_shape.h"
#include "nvim/keymap.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/mouse.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/state.h"
#include "nvim/syntax.h"
#include "nvim/tag.h"
#include "nvim/window.h"
#include "nvim/ui.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/event/loop.h"
#include "nvim/os/time.h"
#include "nvim/lib/kvec.h"
#include "nvim/api/private/helpers.h"
#include "nvim/highlight_defs.h"
#include "nvim/viml/parser/parser.h"
#include "nvim/viml/parser/expressions.h"

/// Command-line colors: one chunk
///
/// Defines a region which has the same highlighting.
typedef struct {
  int start;  ///< Colored chunk start.
  int end;  ///< Colored chunk end (exclusive, > start).
  int attr;  ///< Highlight attr.
} CmdlineColorChunk;

/// Command-line colors
///
/// Holds data about all colors.
typedef kvec_t(CmdlineColorChunk) CmdlineColors;

/// Command-line coloring
///
/// Holds both what are the colors and what have been colored. Latter is used to
/// suppress unnecessary calls to coloring callbacks.
typedef struct {
  unsigned prompt_id;  ///< ID of the prompt which was colored last.
  char *cmdbuff;  ///< What exactly was colored last time or NULL.
  CmdlineColors colors;  ///< Last colors.
} ColoredCmdline;

/// Keeps track how much state must be sent to external ui.
typedef enum {
  kCmdRedrawNone,
  kCmdRedrawPos,
  kCmdRedrawAll,
} CmdRedraw;

/*
 * Variables shared between getcmdline(), redrawcmdline() and others.
 * These need to be saved when using CTRL-R |, that's why they are in a
 * structure.
 */
struct cmdline_info {
  char_u      *cmdbuff;         // pointer to command line buffer
  int cmdbufflen;               // length of cmdbuff
  int cmdlen;                   // number of chars in command line
  int cmdpos;                   // current cursor position
  int cmdspos;                  // cursor column on screen
  int cmdfirstc;                // ':', '/', '?', '=', '>' or NUL
  int cmdindent;                // number of spaces before cmdline
  char_u      *cmdprompt;       // message in front of cmdline
  int cmdattr;                  // attributes for prompt
  int overstrike;               // Typing mode on the command line.  Shared by
                                // getcmdline() and put_on_cmdline().
  expand_T    *xpc;             // struct being used for expansion, xp_pattern
                                // may point into cmdbuff
  int xp_context;               // type of expansion
  char_u      *xp_arg;          // user-defined expansion arg
  int input_fn;                 // when TRUE Invoked for input() function
  unsigned prompt_id;  ///< Prompt number, used to disable coloring on errors.
  Callback highlight_callback;  ///< Callback used for coloring user input.
  ColoredCmdline last_colors;   ///< Last cmdline colors
  int level;                    // current cmdline level
  struct cmdline_info *prev_ccline;  ///< pointer to saved cmdline state
  char special_char;            ///< last putcmdline char (used for redraws)
  bool special_shift;           ///< shift of last putcmdline char
  CmdRedraw redraw_state;       ///< needed redraw for external cmdline
};
/// Last value of prompt_id, incremented when doing new prompt
static unsigned last_prompt_id = 0;

typedef struct command_line_state {
  VimState state;
  int firstc;
  long count;
  int indent;
  int c;
  int i;
  int j;
  int gotesc;                           // TRUE when <ESC> just typed
  int do_abbr;                          // when TRUE check for abbr.
  char_u *lookfor;                      // string to match
  int hiscnt;                           // current history line in use
  int histype;                          // history type to be used
  pos_T     search_start;               // where 'incsearch' starts searching
  pos_T     save_cursor;
  colnr_T   old_curswant;
  colnr_T   init_curswant;
  colnr_T   old_leftcol;
  colnr_T   init_leftcol;
  linenr_T  old_topline;
  linenr_T  init_topline;
  int       old_topfill;
  int       init_topfill;
  linenr_T  old_botline;
  linenr_T  init_botline;
  pos_T     match_start;
  pos_T     match_end;
  int did_incsearch;
  int incsearch_postponed;
  int did_wild_list;                    // did wild_list() recently
  int wim_index;                        // index in wim_flags[]
  int res;
  int       save_msg_scroll;
  int       save_State;                 // remember State when called
  char_u   *save_p_icm;
  int some_key_typed;                   // one of the keys was typed
  // mouse drag and release events are ignored, unless they are
  // preceded with a mouse down event
  int ignore_drag_release;
  int break_ctrl_c;
  expand_T xpc;
  long *b_im_ptr;
} CommandLineState;

typedef struct cmdline_info CmdlineInfo;

/* The current cmdline_info.  It is initialized in getcmdline() and after that
 * used by other functions.  When invoking getcmdline() recursively it needs
 * to be saved with save_cmdline() and restored with restore_cmdline().
 * TODO: make it local to getcmdline() and pass it around. */
static struct cmdline_info ccline;

static int cmd_showtail;                /* Only show path tail in lists ? */

static int new_cmdpos;          /* position set by set_cmdline_pos() */

/// currently displayed block of context
static Array cmdline_block = ARRAY_DICT_INIT;

/*
 * Type used by call_user_expand_func
 */
typedef void *(*user_expand_func_T)(const char_u *,
                                    int,
                                    const char_u * const *,
                                    bool);

static histentry_T *(history[HIST_COUNT]) = {NULL, NULL, NULL, NULL, NULL};
static int hisidx[HIST_COUNT] = {-1, -1, -1, -1, -1};       /* lastused entry */
static int hisnum[HIST_COUNT] = {0, 0, 0, 0, 0};
/* identifying (unique) number of newest history entry */
static int hislen = 0;                  /* actual length of history tables */

/// Flag for command_line_handle_key to ignore <C-c>
///
/// Used if it was received while processing highlight function in order for
/// user interrupting highlight function to not interrupt command-line.
static bool getln_interrupted_highlight = false;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_getln.c.generated.h"
#endif

static int cmd_hkmap = 0;  // Hebrew mapping during command line
static int cmd_fkmap = 0;  // Farsi mapping during command line

/// Internal entry point for cmdline mode.
///
/// caller must use save_cmdline and restore_cmdline. Best is to use
/// getcmdline or getcmdline_prompt, instead of calling this directly.
static uint8_t *command_line_enter(int firstc, long count, int indent)
{
  // can be invoked recursively, identify each level
  static int cmdline_level = 0;
  cmdline_level++;

  CommandLineState state, *s = &state;
  memset(s, 0, sizeof(CommandLineState));
  s->firstc = firstc;
  s->count = count;
  s->indent = indent;
  s->save_msg_scroll = msg_scroll;
  s->save_State = State;
  s->save_p_icm = vim_strsave(p_icm);
  s->ignore_drag_release = true;
  s->match_start = curwin->w_cursor;
  s->init_curswant = curwin->w_curswant;
  s->init_leftcol = curwin->w_leftcol;
  s->init_topline = curwin->w_topline;
  s->init_topfill = curwin->w_topfill;
  s->init_botline = curwin->w_botline;

  if (s->firstc == -1) {
    s->firstc = NUL;
    s->break_ctrl_c = true;
  }

  // start without Hebrew mapping for a command line
  if (s->firstc == ':' || s->firstc == '=' || s->firstc == '>') {
    cmd_hkmap = 0;
  }

  ccline.prompt_id = last_prompt_id++;
  ccline.level = cmdline_level;
  ccline.overstrike = false;                // always start in insert mode
  clearpos(&s->match_end);
  s->save_cursor = curwin->w_cursor;        // may be restored later
  s->search_start = curwin->w_cursor;
  s->old_curswant = curwin->w_curswant;
  s->old_leftcol = curwin->w_leftcol;
  s->old_topline = curwin->w_topline;
  s->old_topfill = curwin->w_topfill;
  s->old_botline = curwin->w_botline;

  // set some variables for redrawcmd()
  ccline.cmdfirstc = (s->firstc == '@' ? 0 : s->firstc);
  ccline.cmdindent = (s->firstc > 0 ? s->indent : 0);

  // alloc initial ccline.cmdbuff
  alloc_cmdbuff(exmode_active ? 250 : s->indent + 1);
  ccline.cmdlen = ccline.cmdpos = 0;
  ccline.cmdbuff[0] = NUL;

  ccline.last_colors = (ColoredCmdline){ .cmdbuff = NULL,
                                         .colors = KV_INITIAL_VALUE };
  sb_text_start_cmdline();

  // autoindent for :insert and :append
  if (s->firstc <= 0) {
    memset(ccline.cmdbuff, ' ', s->indent);
    ccline.cmdbuff[s->indent] = NUL;
    ccline.cmdpos = s->indent;
    ccline.cmdspos = s->indent;
    ccline.cmdlen = s->indent;
  }

  ExpandInit(&s->xpc);
  ccline.xpc = &s->xpc;

  if (curwin->w_p_rl && *curwin->w_p_rlc == 's'
      && (s->firstc == '/' || s->firstc == '?')) {
    cmdmsg_rl = true;
  } else {
    cmdmsg_rl = false;
  }

  redir_off = true;             // don't redirect the typed command
  if (!cmd_silent) {
    gotocmdline(true);
    redrawcmdprompt();          // draw prompt or indent
    set_cmdspos();
  }
  s->xpc.xp_context = EXPAND_NOTHING;
  s->xpc.xp_backslash = XP_BS_NONE;
#ifndef BACKSLASH_IN_FILENAME
  s->xpc.xp_shell = false;
#endif

  if (ccline.input_fn) {
    s->xpc.xp_context = ccline.xp_context;
    s->xpc.xp_pattern = ccline.cmdbuff;
    s->xpc.xp_arg = ccline.xp_arg;
  }

  // Avoid scrolling when called by a recursive do_cmdline(), e.g. when
  // doing ":@0" when register 0 doesn't contain a CR.
  msg_scroll = false;

  State = CMDLINE;

  if (s->firstc == '/' || s->firstc == '?' || s->firstc == '@') {
    // Use ":lmap" mappings for search pattern and input().
    if (curbuf->b_p_imsearch == B_IMODE_USE_INSERT) {
      s->b_im_ptr = &curbuf->b_p_iminsert;
    } else {
      s->b_im_ptr = &curbuf->b_p_imsearch;
    }

    if (*s->b_im_ptr == B_IMODE_LMAP) {
      State |= LANGMAP;
    }
  }

  setmouse();
  ui_cursor_shape();               // may show different cursor shape

  init_history();
  s->hiscnt = hislen;              // set hiscnt to impossible history value
  s->histype = hist_char2type(s->firstc);
  do_digraph(-1);                       // init digraph typeahead

  // If something above caused an error, reset the flags, we do want to type
  // and execute commands. Display may be messed up a bit.
  if (did_emsg) {
    redrawcmd();
  }

  // redraw the statusline for statuslines that display the current mode
  // using the mode() function.
  if (KeyTyped && msg_scrolled == 0) {
    curwin->w_redr_status = true;
    redraw_statuslines();
  }

  did_emsg = false;
  got_int = false;
  s->state.check = command_line_check;
  s->state.execute = command_line_execute;

  TryState tstate;
  Error err = ERROR_INIT;
  bool tl_ret = true;
  dict_T *dict = get_vim_var_dict(VV_EVENT);
  char firstcbuf[2];
  firstcbuf[0] = firstc > 0 ? firstc : '-';
  firstcbuf[1] = 0;

  if (has_event(EVENT_CMDLINEENTER)) {
    // set v:event to a dictionary with information about the commandline
    tv_dict_add_str(dict, S_LEN("cmdtype"), firstcbuf);
    tv_dict_add_nr(dict, S_LEN("cmdlevel"), ccline.level);
    tv_dict_set_keys_readonly(dict);
    try_enter(&tstate);

    apply_autocmds(EVENT_CMDLINEENTER, (char_u *)firstcbuf, (char_u *)firstcbuf,
                   false, curbuf);
    tv_dict_clear(dict);


    tl_ret = try_leave(&tstate, &err);
    if (!tl_ret && ERROR_SET(&err)) {
      msg_putchar('\n');
      msg_printf_attr(HL_ATTR(HLF_E)|MSG_HIST, (char *)e_autocmd_err, err.msg);
      api_clear_error(&err);
      redrawcmd();
    }
    tl_ret = true;
  }

  state_enter(&s->state);

  if (has_event(EVENT_CMDLINELEAVE)) {
    tv_dict_add_str(dict, S_LEN("cmdtype"), firstcbuf);
    tv_dict_add_nr(dict, S_LEN("cmdlevel"), ccline.level);
    tv_dict_set_keys_readonly(dict);
    // not readonly:
    tv_dict_add_special(dict, S_LEN("abort"),
                        s->gotesc ? kSpecialVarTrue : kSpecialVarFalse);
    try_enter(&tstate);
    apply_autocmds(EVENT_CMDLINELEAVE, (char_u *)firstcbuf, (char_u *)firstcbuf,
                   false, curbuf);
    // error printed below, to avoid redraw issues
    tl_ret = try_leave(&tstate, &err);
    if (tv_dict_get_number(dict, "abort") != 0) {
      s->gotesc = 1;
    }
    tv_dict_clear(dict);
  }

  cmdmsg_rl = false;

  cmd_fkmap = 0;

  ExpandCleanup(&s->xpc);
  ccline.xpc = NULL;

  if (s->did_incsearch) {
    if (s->gotesc) {
      curwin->w_cursor = s->save_cursor;
    } else {
      if (!equalpos(s->save_cursor, s->search_start)) {
        // put the '" mark at the original position
        curwin->w_cursor = s->save_cursor;
        setpcmark();
      }
      curwin->w_cursor = s->search_start;  // -V519
    }
    curwin->w_curswant = s->old_curswant;
    curwin->w_leftcol = s->old_leftcol;
    curwin->w_topline = s->old_topline;
    curwin->w_topfill = s->old_topfill;
    curwin->w_botline = s->old_botline;
    highlight_match = false;
    validate_cursor();          // needed for TAB
    redraw_all_later(SOME_VALID);
  }

  if (ccline.cmdbuff != NULL) {
    // Put line in history buffer (":" and "=" only when it was typed).
    if (s->histype != HIST_INVALID
        && ccline.cmdlen
        && s->firstc != NUL
        && (s->some_key_typed || s->histype == HIST_SEARCH)) {
      add_to_history(s->histype, ccline.cmdbuff, true,
          s->histype == HIST_SEARCH ? s->firstc : NUL);
      if (s->firstc == ':') {
        xfree(new_last_cmdline);
        new_last_cmdline = vim_strsave(ccline.cmdbuff);
      }
    }

    if (s->gotesc) {
      abandon_cmdline();
    }
  }

  // If the screen was shifted up, redraw the whole screen (later).
  // If the line is too long, clear it, so ruler and shown command do
  // not get printed in the middle of it.
  msg_check();
  msg_scroll = s->save_msg_scroll;
  redir_off = false;

  if (!tl_ret && ERROR_SET(&err)) {
    msg_putchar('\n');
    msg_printf_attr(HL_ATTR(HLF_E)|MSG_HIST, (char *)e_autocmd_err, err.msg);
    api_clear_error(&err);
  }

  // When the command line was typed, no need for a wait-return prompt.
  if (s->some_key_typed && tl_ret) {
    need_wait_return = false;
  }

  set_string_option_direct((char_u *)"icm", -1, s->save_p_icm, OPT_FREE,
                           SID_NONE);
  State = s->save_State;
  setmouse();
  ui_cursor_shape();            // may show different cursor shape
  xfree(s->save_p_icm);
  xfree(ccline.last_colors.cmdbuff);
  kv_destroy(ccline.last_colors.colors);

  sb_text_end_cmdline();

  char_u *p = ccline.cmdbuff;

  if (ui_is_external(kUICmdline)) {
    ui_call_cmdline_hide(ccline.level);
  }

  cmdline_level--;
  return p;
}

static int command_line_check(VimState *state)
{
  redir_off = true;        // Don't redirect the typed command.
  // Repeated, because a ":redir" inside
  // completion may switch it on.
  quit_more = false;       // reset after CTRL-D which had a more-prompt

  did_emsg = false;        // There can't really be a reason why an error
                           // that occurs while typing a command should
                           // cause the command not to be executed.

  cursorcmd();             // set the cursor on the right spot
  ui_cursor_shape();
  return 1;
}

static int command_line_execute(VimState *state, int key)
{
  if (key == K_IGNORE || key == K_PASTE) {
    return -1;  // get another key
  }

  CommandLineState *s = (CommandLineState *)state;
  s->c = key;

  if (s->c == K_EVENT || s->c == K_COMMAND) {
    if (s->c == K_EVENT) {
      multiqueue_process_events(main_loop.events);
    } else {
      do_cmdline(NULL, getcmdkeycmd, NULL, DOCMD_NOWAIT);
    }
    redrawcmdline();
    return 1;
  }

  if (KeyTyped) {
    s->some_key_typed = true;
    if (cmd_hkmap) {
      s->c = hkmap(s->c);
    }

    if (cmd_fkmap) {
      s->c = cmdl_fkmap(s->c);
    }

    if (cmdmsg_rl && !KeyStuffed) {
      // Invert horizontal movements and operations.  Only when
      // typed by the user directly, not when the result of a
      // mapping.
      switch (s->c) {
      case K_RIGHT:   s->c = K_LEFT; break;
      case K_S_RIGHT: s->c = K_S_LEFT; break;
      case K_C_RIGHT: s->c = K_C_LEFT; break;
      case K_LEFT:    s->c = K_RIGHT; break;
      case K_S_LEFT:  s->c = K_S_RIGHT; break;
      case K_C_LEFT:  s->c = K_C_RIGHT; break;
      }
    }
  }

  // Ignore got_int when CTRL-C was typed here.
  // Don't ignore it in :global, we really need to break then, e.g., for
  // ":g/pat/normal /pat" (without the <CR>).
  // Don't ignore it for the input() function.
  if ((s->c == Ctrl_C)
      && s->firstc != '@'
      && !s->break_ctrl_c
      && !global_busy) {
    got_int = false;
  }

  // free old command line when finished moving around in the history
  // list
  if (s->lookfor != NULL
      && s->c != K_S_DOWN && s->c != K_S_UP
      && s->c != K_DOWN && s->c != K_UP
      && s->c != K_PAGEDOWN && s->c != K_PAGEUP
      && s->c != K_KPAGEDOWN && s->c != K_KPAGEUP
      && s->c != K_LEFT && s->c != K_RIGHT
      && (s->xpc.xp_numfiles > 0 || (s->c != Ctrl_P && s->c != Ctrl_N))) {
    xfree(s->lookfor);
    s->lookfor = NULL;
  }

  // When there are matching completions to select <S-Tab> works like
  // CTRL-P (unless 'wc' is <S-Tab>).
  if (s->c != p_wc && s->c == K_S_TAB && s->xpc.xp_numfiles > 0) {
    s->c = Ctrl_P;
  }

  // Special translations for 'wildmenu'
  if (s->did_wild_list && p_wmnu) {
    if (s->c == K_LEFT) {
      s->c = Ctrl_P;
    } else if (s->c == K_RIGHT) {
      s->c = Ctrl_N;
    }
  }

  // Hitting CR after "emenu Name.": complete submenu
  if (s->xpc.xp_context == EXPAND_MENUNAMES && p_wmnu
      && ccline.cmdpos > 1
      && ccline.cmdbuff[ccline.cmdpos - 1] == '.'
      && ccline.cmdbuff[ccline.cmdpos - 2] != '\\'
      && (s->c == '\n' || s->c == '\r' || s->c == K_KENTER)) {
    s->c = K_DOWN;
  }

  // free expanded names when finished walking through matches
  if (!(s->c == p_wc && KeyTyped) && s->c != p_wcm
      && s->c != Ctrl_N && s->c != Ctrl_P && s->c != Ctrl_A
      && s->c != Ctrl_L) {
    if (ui_is_external(kUIWildmenu)) {
      ui_call_wildmenu_hide();
    }
    if (s->xpc.xp_numfiles != -1) {
      (void)ExpandOne(&s->xpc, NULL, NULL, 0, WILD_FREE);
    }
    s->did_wild_list = false;
    if (!p_wmnu || (s->c != K_UP && s->c != K_DOWN)) {
      s->xpc.xp_context = EXPAND_NOTHING;
    }
    s->wim_index = 0;
    if (p_wmnu && wild_menu_showing != 0) {
      const bool skt = KeyTyped;
      int old_RedrawingDisabled = RedrawingDisabled;

      if (ccline.input_fn) {
        RedrawingDisabled = 0;
      }

      if (wild_menu_showing == WM_SCROLLED) {
        // Entered command line, move it up
        cmdline_row--;
        redrawcmd();
        wild_menu_showing = 0;
      } else if (save_p_ls != -1) {
        // restore 'laststatus' and 'winminheight'
        p_ls = save_p_ls;
        p_wmh = save_p_wmh;
        last_status(false);
        update_screen(VALID);                 // redraw the screen NOW
        redrawcmd();
        save_p_ls = -1;
        wild_menu_showing = 0;
      } else {
        win_redraw_last_status(topframe);
        wild_menu_showing = 0;  // must be before redraw_statuslines #8385
        redraw_statuslines();
      }
      KeyTyped = skt;
      if (ccline.input_fn) {
        RedrawingDisabled = old_RedrawingDisabled;
      }
    }
  }

  // Special translations for 'wildmenu'
  if (s->xpc.xp_context == EXPAND_MENUNAMES && p_wmnu) {
    // Hitting <Down> after "emenu Name.": complete submenu
    if (s->c == K_DOWN && ccline.cmdpos > 0
        && ccline.cmdbuff[ccline.cmdpos - 1] == '.') {
      s->c = p_wc;
    } else if (s->c == K_UP) {
      // Hitting <Up>: Remove one submenu name in front of the
      // cursor
      int found = false;

      s->j = (int)(s->xpc.xp_pattern - ccline.cmdbuff);
      s->i = 0;
      while (--s->j > 0) {
        // check for start of menu name
        if (ccline.cmdbuff[s->j] == ' '
            && ccline.cmdbuff[s->j - 1] != '\\') {
          s->i = s->j + 1;
          break;
        }

        // check for start of submenu name
        if (ccline.cmdbuff[s->j] == '.'
            && ccline.cmdbuff[s->j - 1] != '\\') {
          if (found) {
            s->i = s->j + 1;
            break;
          } else {
            found = true;
          }
        }
      }
      if (s->i > 0) {
        cmdline_del(s->i);
      }
      s->c = p_wc;
      s->xpc.xp_context = EXPAND_NOTHING;
    }
  }
  if ((s->xpc.xp_context == EXPAND_FILES
       || s->xpc.xp_context == EXPAND_DIRECTORIES
       || s->xpc.xp_context == EXPAND_SHELLCMD) && p_wmnu) {
    char_u upseg[5];

    upseg[0] = PATHSEP;
    upseg[1] = '.';
    upseg[2] = '.';
    upseg[3] = PATHSEP;
    upseg[4] = NUL;

    if (s->c == K_DOWN
        && ccline.cmdpos > 0
        && ccline.cmdbuff[ccline.cmdpos - 1] == PATHSEP
        && (ccline.cmdpos < 3
            || ccline.cmdbuff[ccline.cmdpos - 2] != '.'
            || ccline.cmdbuff[ccline.cmdpos - 3] != '.')) {
      // go down a directory
      s->c = p_wc;
    } else if (STRNCMP(s->xpc.xp_pattern, upseg + 1, 3) == 0
        && s->c == K_DOWN) {
      // If in a direct ancestor, strip off one ../ to go down
      int found = false;

      s->j = ccline.cmdpos;
      s->i = (int)(s->xpc.xp_pattern - ccline.cmdbuff);
      while (--s->j > s->i) {
        s->j -= utf_head_off(ccline.cmdbuff, ccline.cmdbuff + s->j);
        if (vim_ispathsep(ccline.cmdbuff[s->j])) {
          found = true;
          break;
        }
      }
      if (found
          && ccline.cmdbuff[s->j - 1] == '.'
          && ccline.cmdbuff[s->j - 2] == '.'
          && (vim_ispathsep(ccline.cmdbuff[s->j - 3]) || s->j == s->i + 2)) {
        cmdline_del(s->j - 2);
        s->c = p_wc;
      }
    } else if (s->c == K_UP) {
      // go up a directory
      int found = false;

      s->j = ccline.cmdpos - 1;
      s->i = (int)(s->xpc.xp_pattern - ccline.cmdbuff);
      while (--s->j > s->i) {
        s->j -= utf_head_off(ccline.cmdbuff, ccline.cmdbuff + s->j);
        if (vim_ispathsep(ccline.cmdbuff[s->j])
#ifdef BACKSLASH_IN_FILENAME
            && vim_strchr((const char_u *)" *?[{`$%#", ccline.cmdbuff[s->j + 1])
            == NULL
#endif
            ) {
          if (found) {
            s->i = s->j + 1;
            break;
          } else {
            found = true;
          }
        }
      }

      if (!found) {
        s->j = s->i;
      } else if (STRNCMP(ccline.cmdbuff + s->j, upseg, 4) == 0) {
        s->j += 4;
      } else if (STRNCMP(ccline.cmdbuff + s->j, upseg + 1, 3) == 0
               && s->j == s->i) {
        s->j += 3;
      } else {
        s->j = 0;
      }

      if (s->j > 0) {
        // TODO(tarruda): this is only for DOS/Unix systems - need to put in
        // machine-specific stuff here and in upseg init
        cmdline_del(s->j);
        put_on_cmdline(upseg + 1, 3, false);
      } else if (ccline.cmdpos > s->i) {
        cmdline_del(s->i);
      }

      // Now complete in the new directory. Set KeyTyped in case the
      // Up key came from a mapping.
      s->c = p_wc;
      KeyTyped = true;
    }
  }

  // CTRL-\ CTRL-N goes to Normal mode, CTRL-\ CTRL-G goes to Insert
  // mode when 'insertmode' is set, CTRL-\ e prompts for an expression.
  if (s->c == Ctrl_BSL) {
    no_mapping++;
    s->c = plain_vgetc();
    no_mapping--;
    // CTRL-\ e doesn't work when obtaining an expression, unless it
    // is in a mapping.
    if (s->c != Ctrl_N
        && s->c != Ctrl_G
        && (s->c != 'e'
            || (ccline.cmdfirstc == '=' && KeyTyped)
            || cmdline_star > 0)) {
      vungetc(s->c);
      s->c = Ctrl_BSL;
    } else if (s->c == 'e') {
      char_u  *p = NULL;
      int len;

      // Replace the command line with the result of an expression.
      // Need to save and restore the current command line, to be
      // able to enter a new one...
      if (ccline.cmdpos == ccline.cmdlen) {
        new_cmdpos = 99999;           // keep it at the end
      } else {
        new_cmdpos = ccline.cmdpos;
      }

      s->c = get_expr_register();
      if (s->c == '=') {
        // Need to save and restore ccline.  And set "textlock"
        // to avoid nasty things like going to another buffer when
        // evaluating an expression.
        CmdlineInfo save_ccline;
        save_cmdline(&save_ccline);
        textlock++;
        p = get_expr_line();
        textlock--;
        restore_cmdline(&save_ccline);

        if (p != NULL) {
          len = (int)STRLEN(p);
          realloc_cmdbuff(len + 1);
          ccline.cmdlen = len;
          STRCPY(ccline.cmdbuff, p);
          xfree(p);

          // Restore the cursor or use the position set with
          // set_cmdline_pos().
          if (new_cmdpos > ccline.cmdlen) {
            ccline.cmdpos = ccline.cmdlen;
          } else {
            ccline.cmdpos = new_cmdpos;
          }

          KeyTyped = false;                 // Don't do p_wc completion.
          redrawcmd();
          return command_line_changed(s);
        }
      }
      beep_flush();
      got_int = false;                // don't abandon the command line
      did_emsg = false;
      emsg_on_display = false;
      redrawcmd();
      return command_line_not_changed(s);
    } else {
      if (s->c == Ctrl_G && p_im && restart_edit == 0) {
        restart_edit = 'a';
      }
      s->gotesc = true;        // will free ccline.cmdbuff after putting it
                               // in history
      return 0;                // back to Normal mode
    }
  }

  if (s->c == cedit_key || s->c == K_CMDWIN) {
    if (ex_normal_busy == 0 && got_int == false) {
      // Open a window to edit the command line (and history).
      s->c = open_cmdwin();
      s->some_key_typed = true;
    }
  } else {
    s->c = do_digraph(s->c);
  }

  if (s->c == '\n'
      || s->c == '\r'
      || s->c == K_KENTER
      || (s->c == ESC
        && (!KeyTyped || vim_strchr(p_cpo, CPO_ESC) != NULL))) {
    // In Ex mode a backslash escapes a newline.
    if (exmode_active
        && s->c != ESC
        && ccline.cmdpos == ccline.cmdlen
        && ccline.cmdpos > 0
        && ccline.cmdbuff[ccline.cmdpos - 1] == '\\') {
      if (s->c == K_KENTER) {
        s->c = '\n';
      }
    } else {
      s->gotesc = false;         // Might have typed ESC previously, don't
                                 // truncate the cmdline now.
      if (ccheck_abbr(s->c + ABBR_OFF)) {
        return command_line_changed(s);
      }

      if (!cmd_silent) {
        if (!ui_is_external(kUICmdline)) {
          ui_cursor_goto(msg_row, 0);
        }
        ui_flush();
      }
      return 0;
    }
  }

  // Completion for 'wildchar' or 'wildcharm' key.
  // - hitting <ESC> twice means: abandon command line.
  // - wildcard expansion is only done when the 'wildchar' key is really
  //   typed, not when it comes from a macro
  if ((s->c == p_wc && !s->gotesc && KeyTyped) || s->c == p_wcm) {
    if (s->xpc.xp_numfiles > 0) {       // typed p_wc at least twice
      // if 'wildmode' contains "list" may still need to list
      if (s->xpc.xp_numfiles > 1
          && !s->did_wild_list
          && (wim_flags[s->wim_index] & WIM_LIST)) {
        (void)showmatches(&s->xpc, false);
        redrawcmd();
        s->did_wild_list = true;
      }

      if (wim_flags[s->wim_index] & WIM_LONGEST) {
        s->res = nextwild(&s->xpc, WILD_LONGEST, WILD_NO_BEEP,
            s->firstc != '@');
      } else if (wim_flags[s->wim_index] & WIM_FULL) {
        s->res = nextwild(&s->xpc, WILD_NEXT, WILD_NO_BEEP,
            s->firstc != '@');
      } else {
        s->res = OK;                 // don't insert 'wildchar' now
      }
    } else {                    // typed p_wc first time
      s->wim_index = 0;
      s->j = ccline.cmdpos;

      // if 'wildmode' first contains "longest", get longest
      // common part
      if (wim_flags[0] & WIM_LONGEST) {
        s->res = nextwild(&s->xpc, WILD_LONGEST, WILD_NO_BEEP,
            s->firstc != '@');
      } else {
        s->res = nextwild(&s->xpc, WILD_EXPAND_KEEP, WILD_NO_BEEP,
            s->firstc != '@');
      }

      // if interrupted while completing, behave like it failed
      if (got_int) {
        (void)vpeekc();               // remove <C-C> from input stream
        got_int = false;              // don't abandon the command line
        (void)ExpandOne(&s->xpc, NULL, NULL, 0, WILD_FREE);
        s->xpc.xp_context = EXPAND_NOTHING;
        return command_line_changed(s);
      }

      // when more than one match, and 'wildmode' first contains
      // "list", or no change and 'wildmode' contains "longest,list",
      // list all matches
      if (s->res == OK && s->xpc.xp_numfiles > 1) {
        // a "longest" that didn't do anything is skipped (but not
        // "list:longest")
        if (wim_flags[0] == WIM_LONGEST && ccline.cmdpos == s->j) {
          s->wim_index = 1;
        }
        if ((wim_flags[s->wim_index] & WIM_LIST)
            || (p_wmnu && (wim_flags[s->wim_index] & WIM_FULL) != 0)) {
          if (!(wim_flags[0] & WIM_LONGEST)) {
            int p_wmnu_save = p_wmnu;
            p_wmnu = 0;
            // remove match
            nextwild(&s->xpc, WILD_PREV, 0, s->firstc != '@');
            p_wmnu = p_wmnu_save;
          }

          (void)showmatches(&s->xpc, p_wmnu
              && ((wim_flags[s->wim_index] & WIM_LIST) == 0));
          redrawcmd();
          s->did_wild_list = true;

          if (wim_flags[s->wim_index] & WIM_LONGEST) {
            nextwild(&s->xpc, WILD_LONGEST, WILD_NO_BEEP,
                s->firstc != '@');
          } else if (wim_flags[s->wim_index] & WIM_FULL) {
            nextwild(&s->xpc, WILD_NEXT, WILD_NO_BEEP,
                s->firstc != '@');
          }
        } else {
          vim_beep(BO_WILD);
        }
      } else if (s->xpc.xp_numfiles == -1) {
        s->xpc.xp_context = EXPAND_NOTHING;
      }
    }

    if (s->wim_index < 3) {
      ++s->wim_index;
    }

    if (s->c == ESC) {
      s->gotesc = true;
    }

    if (s->res == OK) {
      return command_line_changed(s);
    }
  }

  s->gotesc = false;

  // <S-Tab> goes to last match, in a clumsy way
  if (s->c == K_S_TAB && KeyTyped) {
    if (nextwild(&s->xpc, WILD_EXPAND_KEEP, 0, s->firstc != '@') == OK
        && nextwild(&s->xpc, WILD_PREV, 0, s->firstc != '@') == OK
        && nextwild(&s->xpc, WILD_PREV, 0, s->firstc != '@') == OK) {
      return command_line_changed(s);
    }
  }

  if (s->c == NUL || s->c == K_ZERO)  {
    // NUL is stored as NL
    s->c = NL;
  }

  s->do_abbr = true;             // default: check for abbreviation
  return command_line_handle_key(s);
}

static void command_line_next_incsearch(CommandLineState *s, bool next_match)
{
  ui_busy_start();
  ui_flush();

  pos_T  t;
  char_u *pat;
  int search_flags = SEARCH_NOOF;


  if (s->firstc == ccline.cmdbuff[0]) {
    pat = last_search_pattern();
  } else {
    pat = ccline.cmdbuff;
  }

  save_last_search_pattern();

  if (next_match) {
    t = s->match_end;
    if (lt(s->match_start, s->match_end)) {
      // start searching at the end of the match
      // not at the beginning of the next column
      (void)decl(&t);
    }
    search_flags += SEARCH_COL;
  } else {
    t = s->match_start;
  }
  if (!p_hls) {
    search_flags += SEARCH_KEEP;
  }
  emsg_off++;
  s->i = searchit(curwin, curbuf, &t,
                  next_match ? FORWARD : BACKWARD,
                  pat, s->count, search_flags,
                  RE_SEARCH, 0, NULL);
  emsg_off--;
  ui_busy_stop();
  if (s->i) {
    s->search_start = s->match_start;
    s->match_end = t;
    s->match_start = t;
    if (!next_match && s->firstc == '/') {
      // move just before the current match, so that
      // when nv_search finishes the cursor will be
      // put back on the match
      s->search_start = t;
      (void)decl(&s->search_start);
    } else if (next_match && s->firstc == '?') {
      // move just after the current match, so that
      // when nv_search finishes the cursor will be
      // put back on the match
      s->search_start = t;
      (void)incl(&s->search_start);
    }
    if (lt(t, s->search_start) && next_match) {
      // wrap around
      s->search_start = t;
      if (s->firstc == '?') {
        (void)incl(&s->search_start);
      } else {
        (void)decl(&s->search_start);
      }
    }

    set_search_match(&s->match_end);
    curwin->w_cursor = s->match_start;
    changed_cline_bef_curs();
    update_topline();
    validate_cursor();
    highlight_match = true;
    s->old_curswant = curwin->w_curswant;
    s->old_leftcol = curwin->w_leftcol;
    s->old_topline = curwin->w_topline;
    s->old_topfill = curwin->w_topfill;
    s->old_botline = curwin->w_botline;
    update_screen(NOT_VALID);
    redrawcmdline();
  } else {
    vim_beep(BO_ERROR);
  }
  restore_last_search_pattern();
  return;
}

static void command_line_next_histidx(CommandLineState *s, bool next_match)
{
  s->j = (int)STRLEN(s->lookfor);
  for (;; ) {
    // one step backwards
    if (!next_match) {
      if (s->hiscnt == hislen) {
        // first time
        s->hiscnt = hisidx[s->histype];
      } else if (s->hiscnt == 0 && hisidx[s->histype] != hislen - 1) {
        s->hiscnt = hislen - 1;
      } else if (s->hiscnt != hisidx[s->histype] + 1) {
        s->hiscnt--;
      } else {
        // at top of list
        s->hiscnt = s->i;
        break;
      }
    } else {          // one step forwards
      // on last entry, clear the line
      if (s->hiscnt == hisidx[s->histype]) {
        s->hiscnt = hislen;
        break;
      }

      // not on a history line, nothing to do
      if (s->hiscnt == hislen) {
        break;
      }

      if (s->hiscnt == hislen - 1) {
        // wrap around
        s->hiscnt = 0;
      } else {
        s->hiscnt++;
      }
    }

    if (s->hiscnt < 0 || history[s->histype][s->hiscnt].hisstr == NULL) {
      s->hiscnt = s->i;
      break;
    }

    if ((s->c != K_UP && s->c != K_DOWN)
        || s->hiscnt == s->i
        || STRNCMP(history[s->histype][s->hiscnt].hisstr,
                   s->lookfor, (size_t)s->j) == 0) {
      break;
    }
  }
}

static int command_line_handle_key(CommandLineState *s)
{
  // Big switch for a typed command line character.
  switch (s->c) {
  case K_BS:
  case Ctrl_H:
  case K_DEL:
  case K_KDEL:
  case Ctrl_W:
    if (cmd_fkmap && s->c == K_BS) {
      s->c = K_DEL;
    }

    if (s->c == K_KDEL) {
      s->c = K_DEL;
    }

    // delete current character is the same as backspace on next
    // character, except at end of line
    if (s->c == K_DEL && ccline.cmdpos != ccline.cmdlen) {
      ++ccline.cmdpos;
    }

    if (has_mbyte && s->c == K_DEL) {
      ccline.cmdpos += mb_off_next(ccline.cmdbuff,
          ccline.cmdbuff + ccline.cmdpos);
    }

    if (ccline.cmdpos > 0) {
      char_u *p;

      s->j = ccline.cmdpos;
      p = ccline.cmdbuff + s->j;
      if (has_mbyte) {
        p = mb_prevptr(ccline.cmdbuff, p);

        if (s->c == Ctrl_W) {
          while (p > ccline.cmdbuff && ascii_isspace(*p)) {
            p = mb_prevptr(ccline.cmdbuff, p);
          }

          s->i = mb_get_class(p);
          while (p > ccline.cmdbuff && mb_get_class(p) == s->i)
            p = mb_prevptr(ccline.cmdbuff, p);

          if (mb_get_class(p) != s->i) {
            p += (*mb_ptr2len)(p);
          }
        }
      } else if (s->c == Ctrl_W)  {
        while (p > ccline.cmdbuff && ascii_isspace(p[-1])) {
          --p;
        }

        s->i = vim_iswordc(p[-1]);
        while (p > ccline.cmdbuff && !ascii_isspace(p[-1])
               && vim_iswordc(p[-1]) == s->i)
          --p;
      } else {
        --p;
      }

      ccline.cmdpos = (int)(p - ccline.cmdbuff);
      ccline.cmdlen -= s->j - ccline.cmdpos;
      s->i = ccline.cmdpos;

      while (s->i < ccline.cmdlen) {
        ccline.cmdbuff[s->i++] = ccline.cmdbuff[s->j++];
      }

      // Truncate at the end, required for multi-byte chars.
      ccline.cmdbuff[ccline.cmdlen] = NUL;
      if (ccline.cmdlen == 0) {
        s->search_start = s->save_cursor;
        // save view settings, so that the screen won't be restored at the
        // wrong position
        s->old_curswant = s->init_curswant;
        s->old_leftcol = s->init_leftcol;
        s->old_topline = s->init_topline;
        s->old_topfill = s->init_topfill;
        s->old_botline = s->init_botline;
      }
      redrawcmd();
    } else if (ccline.cmdlen == 0 && s->c != Ctrl_W
               && ccline.cmdprompt == NULL && s->indent == 0) {
      // In ex and debug mode it doesn't make sense to return.
      if (exmode_active || ccline.cmdfirstc == '>') {
        return command_line_not_changed(s);
      }

      xfree(ccline.cmdbuff);               // no commandline to return
      ccline.cmdbuff = NULL;
      if (!cmd_silent && !ui_is_external(kUICmdline)) {
        if (cmdmsg_rl) {
          msg_col = Columns;
        } else {
          msg_col = 0;
        }
        msg_putchar(' ');                             // delete ':'
      }
      s->search_start = s->save_cursor;
      redraw_cmdline = true;
      return 0;                           // back to cmd mode
    }
    return command_line_changed(s);

  case K_INS:
  case K_KINS:
    // if Farsi mode set, we are in reverse insert mode -
    // Do not change the mode
    if (cmd_fkmap) {
      beep_flush();
    } else {
      ccline.overstrike = !ccline.overstrike;
    }

    ui_cursor_shape();                // may show different cursor shape
    return command_line_not_changed(s);

  case Ctrl_HAT:
    if (map_to_exists_mode("", LANGMAP, false)) {
      // ":lmap" mappings exists, toggle use of mappings.
      State ^= LANGMAP;
      if (s->b_im_ptr != NULL) {
        if (State & LANGMAP) {
          *s->b_im_ptr = B_IMODE_LMAP;
        } else {
          *s->b_im_ptr = B_IMODE_NONE;
        }
      }
    }

    if (s->b_im_ptr != NULL) {
      if (s->b_im_ptr == &curbuf->b_p_iminsert) {
        set_iminsert_global();
      } else {
        set_imsearch_global();
      }
    }
    ui_cursor_shape();                // may show different cursor shape
    // Show/unshow value of 'keymap' in status lines later.
    status_redraw_curbuf();
    return command_line_not_changed(s);

  case Ctrl_U:
    // delete all characters left of the cursor
    s->j = ccline.cmdpos;
    ccline.cmdlen -= s->j;
    s->i = ccline.cmdpos = 0;
    while (s->i < ccline.cmdlen) {
      ccline.cmdbuff[s->i++] = ccline.cmdbuff[s->j++];
    }

    // Truncate at the end, required for multi-byte chars.
    ccline.cmdbuff[ccline.cmdlen] = NUL;
    if (ccline.cmdlen == 0) {
      s->search_start = s->save_cursor;
    }
    redrawcmd();
    return command_line_changed(s);

  case ESC:           // get here if p_wc != ESC or when ESC typed twice
  case Ctrl_C:
    // In exmode it doesn't make sense to return.  Except when
    // ":normal" runs out of characters. Also when highlight callback is active
    // <C-c> should interrupt only it.
    if ((exmode_active && (ex_normal_busy == 0 || typebuf.tb_len > 0))
        || (getln_interrupted_highlight && s->c == Ctrl_C)) {
      getln_interrupted_highlight = false;
      return command_line_not_changed(s);
    }

    s->gotesc = true;                 // will free ccline.cmdbuff after
                                      // putting it in history
    return 0;                         // back to cmd mode

  case Ctrl_R:                        // insert register
    putcmdline('"', true);
    ++no_mapping;
    s->i = s->c = plain_vgetc();      // CTRL-R <char>
    if (s->i == Ctrl_O) {
      s->i = Ctrl_R;                     // CTRL-R CTRL-O == CTRL-R CTRL-R
    }

    if (s->i == Ctrl_R) {
      s->c = plain_vgetc();              // CTRL-R CTRL-R <char>
    }
    --no_mapping;
    // Insert the result of an expression.
    // Need to save the current command line, to be able to enter
    // a new one...
    new_cmdpos = -1;
    if (s->c == '=') {
      if (ccline.cmdfirstc == '='   // can't do this recursively
          || cmdline_star > 0) {    // or when typing a password
        beep_flush();
        s->c = ESC;
      } else {
        CmdlineInfo save_ccline;
        save_cmdline(&save_ccline);
        s->c = get_expr_register();
        restore_cmdline(&save_ccline);
      }
    }

    if (s->c != ESC) {               // use ESC to cancel inserting register
      cmdline_paste(s->c, s->i == Ctrl_R, false);

      // When there was a serious error abort getting the
      // command line.
      if (aborting()) {
        s->gotesc = true;              // will free ccline.cmdbuff after
                                       // putting it in history
        return 0;                      // back to cmd mode
      }
      KeyTyped = false;                // Don't do p_wc completion.
      if (new_cmdpos >= 0) {
        // set_cmdline_pos() was used
        if (new_cmdpos > ccline.cmdlen) {
          ccline.cmdpos = ccline.cmdlen;
        } else {
          ccline.cmdpos = new_cmdpos;
        }
      }
    }
    redrawcmd();
    return command_line_changed(s);

  case Ctrl_D:
    if (showmatches(&s->xpc, false) == EXPAND_NOTHING) {
      break;                  // Use ^D as normal char instead
    }

    wild_menu_showing = WM_LIST;
    redrawcmd();
    return 1;                 // don't do incremental search now

  case K_RIGHT:
  case K_S_RIGHT:
  case K_C_RIGHT:
    do {
      if (ccline.cmdpos >= ccline.cmdlen) {
        break;
      }

      s->i = cmdline_charsize(ccline.cmdpos);
      if (KeyTyped && ccline.cmdspos + s->i >= Columns * Rows) {
        break;
      }

      ccline.cmdspos += s->i;
      if (has_mbyte) {
        ccline.cmdpos += (*mb_ptr2len)(ccline.cmdbuff
                                       + ccline.cmdpos);
      } else {
        ++ccline.cmdpos;
      }
    } while ((s->c == K_S_RIGHT || s->c == K_C_RIGHT
              || (mod_mask & (MOD_MASK_SHIFT|MOD_MASK_CTRL)))
             && ccline.cmdbuff[ccline.cmdpos] != ' ');
    if (has_mbyte) {
      set_cmdspos_cursor();
    }
    return command_line_not_changed(s);

  case K_LEFT:
  case K_S_LEFT:
  case K_C_LEFT:
    if (ccline.cmdpos == 0) {
      return command_line_not_changed(s);
    }
    do {
      ccline.cmdpos--;
      // Move to first byte of possibly multibyte char.
      ccline.cmdpos -= utf_head_off(ccline.cmdbuff,
                                    ccline.cmdbuff + ccline.cmdpos);
      ccline.cmdspos -= cmdline_charsize(ccline.cmdpos);
    } while (ccline.cmdpos > 0
             && (s->c == K_S_LEFT || s->c == K_C_LEFT
                 || (mod_mask & (MOD_MASK_SHIFT|MOD_MASK_CTRL)))
             && ccline.cmdbuff[ccline.cmdpos - 1] != ' ');

    set_cmdspos_cursor();

    return command_line_not_changed(s);

  case K_IGNORE:
    // Ignore mouse event or open_cmdwin() result.
    return command_line_not_changed(s);


  case K_MIDDLEDRAG:
  case K_MIDDLERELEASE:
    return command_line_not_changed(s);                 // Ignore mouse

  case K_MIDDLEMOUSE:
    if (!mouse_has(MOUSE_COMMAND)) {
      return command_line_not_changed(s);                   // Ignore mouse
    }
    cmdline_paste(eval_has_provider("clipboard") ? '*' : 0, true, true);
    redrawcmd();
    return command_line_changed(s);


  case K_LEFTDRAG:
  case K_LEFTRELEASE:
  case K_RIGHTDRAG:
  case K_RIGHTRELEASE:
    // Ignore drag and release events when the button-down wasn't
    // seen before.
    if (s->ignore_drag_release) {
      return command_line_not_changed(s);
    }
    FALLTHROUGH;
  case K_LEFTMOUSE:
  case K_RIGHTMOUSE:
    if (s->c == K_LEFTRELEASE || s->c == K_RIGHTRELEASE) {
      s->ignore_drag_release = true;
    } else {
      s->ignore_drag_release = false;
    }

    if (!mouse_has(MOUSE_COMMAND)) {
      return command_line_not_changed(s);                   // Ignore mouse
    }

    set_cmdspos();
    for (ccline.cmdpos = 0; ccline.cmdpos < ccline.cmdlen;
         ++ccline.cmdpos) {
      s->i = cmdline_charsize(ccline.cmdpos);
      if (mouse_row <= cmdline_row + ccline.cmdspos / Columns
          && mouse_col < ccline.cmdspos % Columns + s->i) {
        break;
      }

      if (has_mbyte) {
        // Count ">" for double-wide char that doesn't fit.
        correct_cmdspos(ccline.cmdpos, s->i);
        ccline.cmdpos += (*mb_ptr2len)(ccline.cmdbuff
                                       + ccline.cmdpos) - 1;
      }
      ccline.cmdspos += s->i;
    }
    return command_line_not_changed(s);

  // Mouse scroll wheel: ignored here
  case K_MOUSEDOWN:
  case K_MOUSEUP:
  case K_MOUSELEFT:
  case K_MOUSERIGHT:
  // Alternate buttons ignored here
  case K_X1MOUSE:
  case K_X1DRAG:
  case K_X1RELEASE:
  case K_X2MOUSE:
  case K_X2DRAG:
  case K_X2RELEASE:
    return command_line_not_changed(s);



  case K_SELECT:          // end of Select mode mapping - ignore
    return command_line_not_changed(s);

  case Ctrl_B:            // begin of command line
  case K_HOME:
  case K_KHOME:
  case K_S_HOME:
  case K_C_HOME:
    ccline.cmdpos = 0;
    set_cmdspos();
    return command_line_not_changed(s);

  case Ctrl_E:            // end of command line
  case K_END:
  case K_KEND:
  case K_S_END:
  case K_C_END:
    ccline.cmdpos = ccline.cmdlen;
    set_cmdspos_cursor();
    return command_line_not_changed(s);

  case Ctrl_A:            // all matches
    if (nextwild(&s->xpc, WILD_ALL, 0, s->firstc != '@') == FAIL)
      break;
    return command_line_changed(s);

  case Ctrl_L:
    if (p_is && !cmd_silent && (s->firstc == '/' || s->firstc == '?')) {
      // Add a character from under the cursor for 'incsearch'
      if (s->did_incsearch) {
        curwin->w_cursor = s->match_end;
        if (!equalpos(curwin->w_cursor, s->search_start)) {
          s->c = gchar_cursor();
          // If 'ignorecase' and 'smartcase' are set and the
          // command line has no uppercase characters, convert
          // the character to lowercase
          if (p_ic && p_scs
              && !pat_has_uppercase(ccline.cmdbuff)) {
            s->c = mb_tolower(s->c);
          }
          if (s->c != NUL) {
            if (s->c == s->firstc
                || vim_strchr((char_u *)(p_magic ? "\\~^$.*[" : "\\^$"), s->c)
                != NULL) {
              // put a backslash before special characters
              stuffcharReadbuff(s->c);
              s->c = '\\';
            }
            break;
          }
        }
      }
      return command_line_not_changed(s);
    }

    // completion: longest common part
    if (nextwild(&s->xpc, WILD_LONGEST, 0, s->firstc != '@') == FAIL) {
      break;
    }
    return command_line_changed(s);

  case Ctrl_N:            // next match
  case Ctrl_P:            // previous match
    if (s->xpc.xp_numfiles > 0) {
      if (nextwild(&s->xpc, (s->c == Ctrl_P) ? WILD_PREV : WILD_NEXT,
              0, s->firstc != '@') == FAIL) {
        break;
      }
      return command_line_not_changed(s);
    }
    FALLTHROUGH;

  case K_UP:
  case K_DOWN:
  case K_S_UP:
  case K_S_DOWN:
  case K_PAGEUP:
  case K_KPAGEUP:
  case K_PAGEDOWN:
  case K_KPAGEDOWN:
    if (s->histype == HIST_INVALID || hislen == 0 || s->firstc == NUL) {
      // no history
      return command_line_not_changed(s);
    }

    s->i = s->hiscnt;

    // save current command string so it can be restored later
    if (s->lookfor == NULL) {
      s->lookfor = vim_strsave(ccline.cmdbuff);
      s->lookfor[ccline.cmdpos] = NUL;
    }

    bool next_match = (s->c == K_DOWN || s->c == K_S_DOWN || s->c == Ctrl_N
                       || s->c == K_PAGEDOWN || s->c == K_KPAGEDOWN);
    command_line_next_histidx(s, next_match);

    if (s->hiscnt != s->i) {
      // jumped to other entry
      char_u      *p;
      int len = 0;
      int old_firstc;

      xfree(ccline.cmdbuff);
      s->xpc.xp_context = EXPAND_NOTHING;
      if (s->hiscnt == hislen) {
        p = s->lookfor;                  // back to the old one
      } else {
        p = history[s->histype][s->hiscnt].hisstr;
      }

      if (s->histype == HIST_SEARCH
          && p != s->lookfor
          && (old_firstc = p[STRLEN(p) + 1]) != s->firstc) {
        // Correct for the separator character used when
        // adding the history entry vs the one used now.
        // First loop: count length.
        // Second loop: copy the characters.
        for (s->i = 0; s->i <= 1; ++s->i) {
          len = 0;
          for (s->j = 0; p[s->j] != NUL; ++s->j) {
            // Replace old sep with new sep, unless it is
            // escaped.
            if (p[s->j] == old_firstc
                && (s->j == 0 || p[s->j - 1] != '\\')) {
              if (s->i > 0) {
                ccline.cmdbuff[len] = s->firstc;
              }
            } else {
              // Escape new sep, unless it is already
              // escaped.
              if (p[s->j] == s->firstc
                  && (s->j == 0 || p[s->j - 1] != '\\')) {
                if (s->i > 0) {
                  ccline.cmdbuff[len] = '\\';
                }
                ++len;
              }

              if (s->i > 0) {
                ccline.cmdbuff[len] = p[s->j];
              }
            }
            ++len;
          }

          if (s->i == 0) {
            alloc_cmdbuff(len);
          }
        }
        ccline.cmdbuff[len] = NUL;
      } else {
        alloc_cmdbuff((int)STRLEN(p));
        STRCPY(ccline.cmdbuff, p);
      }

      ccline.cmdpos = ccline.cmdlen = (int)STRLEN(ccline.cmdbuff);
      redrawcmd();
      return command_line_changed(s);
    }
    beep_flush();
    return command_line_not_changed(s);

  case Ctrl_G:  // next match
  case Ctrl_T:  // previous match
    if (p_is && !cmd_silent && (s->firstc == '/' || s->firstc == '?')) {
      if (ccline.cmdlen != 0) {
        command_line_next_incsearch(s, s->c == Ctrl_G);
      }
      return command_line_not_changed(s);
    }
    break;

  case Ctrl_V:
  case Ctrl_Q:
    s->ignore_drag_release = true;
    putcmdline('^', true);
    s->c = get_literal();                 // get next (two) character(s)
    s->do_abbr = false;                   // don't do abbreviation now
    // may need to remove ^ when composing char was typed
    if (enc_utf8 && utf_iscomposing(s->c) && !cmd_silent) {
      if (ui_is_external(kUICmdline)) {
        // TODO(bfredl): why not make unputcmdline also work with true?
        unputcmdline();
      } else {
        draw_cmdline(ccline.cmdpos, ccline.cmdlen - ccline.cmdpos);
        msg_putchar(' ');
        cursorcmd();
      }
    }
    break;

  case Ctrl_K:
    s->ignore_drag_release = true;
    putcmdline('?', true);
    s->c = get_digraph(true);

    if (s->c != NUL) {
      break;
    }

    redrawcmd();
    return command_line_not_changed(s);

  case Ctrl__:            // CTRL-_: switch language mode
    if (!p_ari) {
      break;
    }
    if (p_altkeymap) {
      cmd_fkmap = !cmd_fkmap;
      if (cmd_fkmap) {
        // in Farsi always in Insert mode
        ccline.overstrike = false;
      }
    } else {
      // Hebrew is default
      cmd_hkmap = !cmd_hkmap;
    }
    return command_line_not_changed(s);

  default:
    // Normal character with no special meaning.  Just set mod_mask
    // to 0x0 so that typing Shift-Space in the GUI doesn't enter
    // the string <S-Space>.  This should only happen after ^V.
    if (!IS_SPECIAL(s->c)) {
      mod_mask = 0x0;
    }
    break;
  }

  // End of switch on command line character.
  // We come here if we have a normal character.
  if (s->do_abbr && (IS_SPECIAL(s->c) || !vim_iswordc(s->c))
      // Add ABBR_OFF for characters above 0x100, this is
      // what check_abbr() expects.
      && (ccheck_abbr((has_mbyte && s->c >= 0x100) ?
          (s->c + ABBR_OFF) : s->c)
        || s->c == Ctrl_RSB)) {
    return command_line_changed(s);
  }

  // put the character in the command line
  if (IS_SPECIAL(s->c) || mod_mask != 0) {
    put_on_cmdline(get_special_key_name(s->c, mod_mask), -1, true);
  } else {
    s->j = utf_char2bytes(s->c, IObuff);
    IObuff[s->j] = NUL;                // exclude composing chars
    put_on_cmdline(IObuff, s->j, true);
  }
  return command_line_changed(s);
}


static int command_line_not_changed(CommandLineState *s)
{
  // Incremental searches for "/" and "?":
  // Enter command_line_not_changed() when a character has been read but the
  // command line did not change. Then we only search and redraw if something
  // changed in the past.
  // Enter command_line_changed() when the command line did change.
  if (!s->incsearch_postponed) {
    return 1;
  }
  return command_line_changed(s);
}

/// Guess that the pattern matches everything.  Only finds specific cases, such
/// as a trailing \|, which can happen while typing a pattern.
static int empty_pattern(char_u *p)
{
  size_t n = STRLEN(p);

  // remove trailing \v and the like
  while (n >= 2 && p[n - 2] == '\\'
         && vim_strchr((char_u *)"mMvVcCZ", p[n - 1]) != NULL) {
    n -= 2;
  }
  return n == 0 || (n >= 2 && p[n - 2] == '\\' && p[n - 1] == '|');
}

static int command_line_changed(CommandLineState *s)
{
  // Trigger CmdlineChanged autocommands.
  if (has_event(EVENT_CMDLINECHANGED)) {
    TryState tstate;
    Error err = ERROR_INIT;
    dict_T *dict = get_vim_var_dict(VV_EVENT);

    char firstcbuf[2];
    firstcbuf[0] = s->firstc > 0 ? s->firstc : '-';
    firstcbuf[1] = 0;

    // set v:event to a dictionary with information about the commandline
    tv_dict_add_str(dict, S_LEN("cmdtype"), firstcbuf);
    tv_dict_add_nr(dict, S_LEN("cmdlevel"), ccline.level);
    tv_dict_set_keys_readonly(dict);
    try_enter(&tstate);

    apply_autocmds(EVENT_CMDLINECHANGED, (char_u *)firstcbuf,
                   (char_u *)firstcbuf, false, curbuf);
    tv_dict_clear(dict);

    bool tl_ret = try_leave(&tstate, &err);
    if (!tl_ret && ERROR_SET(&err)) {
      msg_putchar('\n');
      msg_printf_attr(HL_ATTR(HLF_E)|MSG_HIST, (char *)e_autocmd_err, err.msg);
      api_clear_error(&err);
      redrawcmd();
    }
  }

  // 'incsearch' highlighting.
  if (p_is && !cmd_silent && (s->firstc == '/' || s->firstc == '?')) {
    pos_T end_pos;
    proftime_T tm;

    // if there is a character waiting, search and redraw later
    if (char_avail()) {
      s->incsearch_postponed = true;
      return 1;
    }
    s->incsearch_postponed = false;
    curwin->w_cursor = s->search_start;  // start at old position
    save_last_search_pattern();

    // If there is no command line, don't do anything
    if (ccline.cmdlen == 0) {
      s->i = 0;
      SET_NO_HLSEARCH(true);  // turn off previous highlight
      redraw_all_later(SOME_VALID);
    } else {
      int search_flags = SEARCH_OPT + SEARCH_NOOF + SEARCH_PEEK;
      ui_busy_start();
      ui_flush();
      ++emsg_off;            // So it doesn't beep if bad expr
      // Set the time limit to half a second.
      tm = profile_setlimit(500L);
      if (!p_hls) {
        search_flags += SEARCH_KEEP;
      }
      s->i = do_search(NULL, s->firstc, ccline.cmdbuff, s->count,
                       search_flags,
                       &tm);
      emsg_off--;
      // if interrupted while searching, behave like it failed
      if (got_int) {
        (void)vpeekc();               // remove <C-C> from input stream
        got_int = false;              // don't abandon the command line
        s->i = 0;
      } else if (char_avail()) {
        // cancelled searching because a char was typed
        s->incsearch_postponed = true;
      }
      ui_busy_stop();
    }

    if (s->i != 0) {
      highlight_match = true;   // highlight position
    } else {
      highlight_match = false;  // remove highlight
    }

    // first restore the old curwin values, so the screen is
    // positioned in the same way as the actual search command
    curwin->w_leftcol = s->old_leftcol;
    curwin->w_topline = s->old_topline;
    curwin->w_topfill = s->old_topfill;
    curwin->w_botline = s->old_botline;
    changed_cline_bef_curs();
    update_topline();

    if (s->i != 0) {
      pos_T save_pos = curwin->w_cursor;

      s->match_start = curwin->w_cursor;
      set_search_match(&curwin->w_cursor);
      validate_cursor();
      end_pos = curwin->w_cursor;
      s->match_end = end_pos;
      curwin->w_cursor = save_pos;
    } else {
      end_pos = curwin->w_cursor;         // shutup gcc 4
    }

    // Disable 'hlsearch' highlighting if the pattern matches
    // everything. Avoids a flash when typing "foo\|".
    if (empty_pattern(ccline.cmdbuff)) {
      SET_NO_HLSEARCH(true);
    }

    validate_cursor();
    // May redraw the status line to show the cursor position.
    if (p_ru && curwin->w_status_height > 0) {
      curwin->w_redr_status = true;
    }

    update_screen(SOME_VALID);
    restore_last_search_pattern();

    // Leave it at the end to make CTRL-R CTRL-W work.
    if (s->i != 0) {
      curwin->w_cursor = end_pos;
    }

    msg_starthere();
    redrawcmdline();
    s->did_incsearch = true;
  } else if (s->firstc == ':'
             && current_SID == 0    // only if interactive
             && *p_icm != NUL       // 'inccommand' is set
             && curbuf->b_p_ma      // buffer is modifiable
             && cmdline_star == 0   // not typing a password
             && cmd_can_preview(ccline.cmdbuff)
             && !vpeekc_any()) {
    // Show 'inccommand' preview. It works like this:
    //    1. Do the command.
    //    2. Command implementation detects CMDPREVIEW state, then:
    //       - Update the screen while the effects are in place.
    //       - Immediately undo the effects.
    State |= CMDPREVIEW;
    emsg_silent++;  // Block error reporting as the command may be incomplete
    do_cmdline(ccline.cmdbuff, NULL, NULL, DOCMD_KEEPLINE|DOCMD_NOWAIT);
    emsg_silent--;  // Unblock error reporting

    // Restore the window "view".
    curwin->w_cursor   = s->save_cursor;
    curwin->w_curswant = s->old_curswant;
    curwin->w_leftcol  = s->old_leftcol;
    curwin->w_topline  = s->old_topline;
    curwin->w_topfill  = s->old_topfill;
    curwin->w_botline  = s->old_botline;
    update_topline();

    redrawcmdline();
  } else if (State & CMDPREVIEW) {
    State = (State & ~CMDPREVIEW);
    update_screen(SOME_VALID);  // Clear 'inccommand' preview.
  }

  if (cmdmsg_rl || (p_arshape && !p_tbidi && enc_utf8)) {
    // Always redraw the whole command line to fix shaping and
    // right-left typing.  Not efficient, but it works.
    // Do it only when there are no characters left to read
    // to avoid useless intermediate redraws.
    // if cmdline is external the ui handles shaping, no redraw needed.
    if (!ui_is_external(kUICmdline) && vpeekc() == NUL) {
      redrawcmd();
    }
  }

  return 1;
}

/// Abandon the command line.
static void abandon_cmdline(void)
{
  xfree(ccline.cmdbuff);
  ccline.cmdbuff = NULL;
  if (msg_scrolled == 0) {
    compute_cmdrow();
  }
  MSG("");
  redraw_cmdline = true;
}

/*
 * getcmdline() - accept a command line starting with firstc.
 *
 * firstc == ':'	    get ":" command line.
 * firstc == '/' or '?'	    get search pattern
 * firstc == '='	    get expression
 * firstc == '@'	    get text for input() function
 * firstc == '>'	    get text for debug mode
 * firstc == NUL	    get text for :insert command
 * firstc == -1		    like NUL, and break on CTRL-C
 *
 * The line is collected in ccline.cmdbuff, which is reallocated to fit the
 * command line.
 *
 * Careful: getcmdline() can be called recursively!
 *
 * Return pointer to allocated string if there is a commandline, NULL
 * otherwise.
 */
char_u *
getcmdline (
    int firstc,
    long count,              // only used for incremental search
    int indent               // indent for inside conditionals
)
{
  // Be prepared for situations where cmdline can be invoked recursively.
  // That includes cmd mappings, event handlers, as well as update_screen()
  // (custom status line eval), which all may invoke ":normal :".
  CmdlineInfo save_ccline;
  save_cmdline(&save_ccline);
  char_u *retval = command_line_enter(firstc, count, indent);
  restore_cmdline(&save_ccline);
  return retval;
}

/// Get a command line with a prompt
///
/// This is prepared to be called recursively from getcmdline() (e.g. by
/// f_input() when evaluating an expression from `<C-r>=`).
///
/// @param[in]  firstc  Prompt type: e.g. '@' for input(), '>' for debug.
/// @param[in]  prompt  Prompt string: what is displayed before the user text.
/// @param[in]  attr  Prompt highlighting.
/// @param[in]  xp_context  Type of expansion.
/// @param[in]  xp_arg  User-defined expansion argument.
/// @param[in]  highlight_callback  Callback used for highlighting user input.
///
/// @return [allocated] Command line or NULL.
char *getcmdline_prompt(const char firstc, const char *const prompt,
                        const int attr, const int xp_context,
                        const char *const xp_arg,
                        const Callback highlight_callback)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
{
  const int msg_col_save = msg_col;

  CmdlineInfo save_ccline;
  save_cmdline(&save_ccline);

  ccline.prompt_id = last_prompt_id++;
  ccline.cmdprompt = (char_u *)prompt;
  ccline.cmdattr = attr;
  ccline.xp_context = xp_context;
  ccline.xp_arg = (char_u *)xp_arg;
  ccline.input_fn = (firstc == '@');
  ccline.highlight_callback = highlight_callback;

  int msg_silent_saved = msg_silent;
  msg_silent = 0;

  char *const ret = (char *)command_line_enter(firstc, 1L, 0);

  restore_cmdline(&save_ccline);
  msg_silent = msg_silent_saved;
  // Restore msg_col, the prompt from input() may have changed it.
  // But only if called recursively and the commandline is therefore being
  // restored to an old one; if not, the input() prompt stays on the screen,
  // so we need its modified msg_col left intact.
  if (ccline.cmdbuff != NULL) {
    msg_col = msg_col_save;
  }

  return ret;
}

/*
 * Return TRUE when the text must not be changed and we can't switch to
 * another window or buffer.  Used when editing the command line etc.
 */
int text_locked(void) {
  if (cmdwin_type != 0)
    return TRUE;
  return textlock != 0;
}

/*
 * Give an error message for a command that isn't allowed while the cmdline
 * window is open or editing the cmdline in another way.
 */
void text_locked_msg(void)
{
  EMSG(_(get_text_locked_msg()));
}

char_u * get_text_locked_msg(void) {
  if (cmdwin_type != 0) {
    return e_cmdwin;
  } else {
    return e_secure;
  }
}

/*
 * Check if "curbuf_lock" or "allbuf_lock" is set and return TRUE when it is
 * and give an error message.
 */
int curbuf_locked(void)
{
  if (curbuf_lock > 0) {
    EMSG(_("E788: Not allowed to edit another buffer now"));
    return TRUE;
  }
  return allbuf_locked();
}

/*
 * Check if "allbuf_lock" is set and return TRUE when it is and give an error
 * message.
 */
int allbuf_locked(void)
{
  if (allbuf_lock > 0) {
    EMSG(_("E811: Not allowed to change buffer information now"));
    return TRUE;
  }
  return FALSE;
}

static int cmdline_charsize(int idx)
{
  if (cmdline_star > 0)             /* showing '*', always 1 position */
    return 1;
  return ptr2cells(ccline.cmdbuff + idx);
}

/*
 * Compute the offset of the cursor on the command line for the prompt and
 * indent.
 */
static void set_cmdspos(void)
{
  if (ccline.cmdfirstc != NUL)
    ccline.cmdspos = 1 + ccline.cmdindent;
  else
    ccline.cmdspos = 0 + ccline.cmdindent;
}

/*
 * Compute the screen position for the cursor on the command line.
 */
static void set_cmdspos_cursor(void)
{
  int i, m, c;

  set_cmdspos();
  if (KeyTyped) {
    m = Columns * Rows;
    if (m < 0)          /* overflow, Columns or Rows at weird value */
      m = MAXCOL;
  } else
    m = MAXCOL;
  for (i = 0; i < ccline.cmdlen && i < ccline.cmdpos; ++i) {
    c = cmdline_charsize(i);
    /* Count ">" for double-wide multi-byte char that doesn't fit. */
    if (has_mbyte)
      correct_cmdspos(i, c);
    /* If the cmdline doesn't fit, show cursor on last visible char.
     * Don't move the cursor itself, so we can still append. */
    if ((ccline.cmdspos += c) >= m) {
      ccline.cmdspos -= c;
      break;
    }
    if (has_mbyte)
      i += (*mb_ptr2len)(ccline.cmdbuff + i) - 1;
  }
}

/*
 * Check if the character at "idx", which is "cells" wide, is a multi-byte
 * character that doesn't fit, so that a ">" must be displayed.
 */
static void correct_cmdspos(int idx, int cells)
{
  if (utfc_ptr2len(ccline.cmdbuff + idx) > 1
      && utf_ptr2cells(ccline.cmdbuff + idx) > 1
      && ccline.cmdspos % Columns + cells > Columns) {
    ccline.cmdspos++;
  }
}

/*
 * Get an Ex command line for the ":" command.
 */
char_u *
getexline (
    int c,                          /* normally ':', NUL for ":append" */
    void *cookie,
    int indent                     /* indent for inside conditionals */
)
{
  /* When executing a register, remove ':' that's in front of each line. */
  if (exec_from_reg && vpeekc() == ':')
    (void)vgetc();

  return getcmdline(c, 1L, indent);
}

/*
 * Get an Ex command line for Ex mode.
 * In Ex mode we only use the OS supplied line editing features and no
 * mappings or abbreviations.
 * Returns a string in allocated memory or NULL.
 */
char_u *
getexmodeline (
    int promptc,                    /* normally ':', NUL for ":append" and '?' for
                                   :s prompt */
    void *cookie,
    int indent                     /* indent for inside conditionals */
)
{
  garray_T line_ga;
  char_u      *pend;
  int startcol = 0;
  int c1 = 0;
  int escaped = FALSE;                  /* CTRL-V typed */
  int vcol = 0;
  char_u      *p;
  int prev_char;
  int len;

  /* always start in column 0; write a newline if necessary */
  compute_cmdrow();
  if ((msg_col || msg_didout) && promptc != '?')
    msg_putchar('\n');
  if (promptc == ':') {
    /* indent that is only displayed, not in the line itself */
    if (p_prompt)
      msg_putchar(':');
    while (indent-- > 0)
      msg_putchar(' ');
    startcol = msg_col;
  }

  ga_init(&line_ga, 1, 30);

  /* autoindent for :insert and :append is in the line itself */
  if (promptc <= 0) {
    vcol = indent;
    while (indent >= 8) {
      ga_append(&line_ga, TAB);
      msg_puts("        ");
      indent -= 8;
    }
    while (indent-- > 0) {
      ga_append(&line_ga, ' ');
      msg_putchar(' ');
    }
  }
  no_mapping++;

  /*
   * Get the line, one character at a time.
   */
  got_int = FALSE;
  while (!got_int) {
    ga_grow(&line_ga, 40);

    /* Get one character at a time.  Don't use inchar(), it can't handle
     * special characters. */
    prev_char = c1;

    // Check for a ":normal" command and no more characters left.
    if (ex_normal_busy > 0 && typebuf.tb_len == 0) {
        c1 = '\n';
    } else {
        c1 = vgetc();
    }

    /*
     * Handle line editing.
     * Previously this was left to the system, putting the terminal in
     * cooked mode, but then CTRL-D and CTRL-T can't be used properly.
     */
    if (got_int) {
      msg_putchar('\n');
      break;
    }

    if (!escaped) {
      /* CR typed means "enter", which is NL */
      if (c1 == '\r')
        c1 = '\n';

      if (c1 == BS || c1 == K_BS || c1 == DEL || c1 == K_DEL || c1 == K_KDEL) {
        if (!GA_EMPTY(&line_ga)) {
          p = (char_u *)line_ga.ga_data;
          p[line_ga.ga_len] = NUL;
          len = utf_head_off(p, p + line_ga.ga_len - 1) + 1;
          line_ga.ga_len -= len;
          goto redraw;
        }
        continue;
      }

      if (c1 == Ctrl_U) {
        msg_col = startcol;
        msg_clr_eos();
        line_ga.ga_len = 0;
        goto redraw;
      }

      int num_spaces;
      if (c1 == Ctrl_T) {
        int sw = get_sw_value(curbuf);

        p = (char_u *)line_ga.ga_data;
        p[line_ga.ga_len] = NUL;
        indent = get_indent_str(p, 8, FALSE);
        num_spaces = sw - indent % sw;
add_indent:
        if (num_spaces > 0) {
          ga_grow(&line_ga, num_spaces + 1);
          p = (char_u *)line_ga.ga_data;
          char_u *s = skipwhite(p);

          // Insert spaces after leading whitespaces.
          memmove(s + num_spaces, s, line_ga.ga_len - (s - p) + 1);
          memset(s, ' ', num_spaces);

          line_ga.ga_len += num_spaces;
        }
redraw:
        /* redraw the line */
        msg_col = startcol;
        vcol = 0;
        p = (char_u *)line_ga.ga_data;
        p[line_ga.ga_len] = NUL;
        while (p < (char_u *)line_ga.ga_data + line_ga.ga_len) {
          if (*p == TAB) {
            do {
              msg_putchar(' ');
            } while (++vcol % 8);
            p++;
          } else {
            len = MB_PTR2LEN(p);
            msg_outtrans_len(p, len);
            vcol += ptr2cells(p);
            p += len;
          }
        }
        msg_clr_eos();
        ui_cursor_goto(msg_row, msg_col);
        continue;
      }

      if (c1 == Ctrl_D) {
        /* Delete one shiftwidth. */
        p = (char_u *)line_ga.ga_data;
        if (prev_char == '0' || prev_char == '^') {
          if (prev_char == '^')
            ex_keep_indent = TRUE;
          indent = 0;
          p[--line_ga.ga_len] = NUL;
        } else {
          p[line_ga.ga_len] = NUL;
          indent = get_indent_str(p, 8, FALSE);
          if (indent == 0) {
            continue;
          }
          --indent;
          indent -= indent % get_sw_value(curbuf);
        }

        // reduce the line's indentation
        char_u *from = skipwhite(p);
        char_u *to = from;
        int old_indent;
        while ((old_indent = get_indent_str(p, 8, FALSE)) > indent) {
          *--to = NUL;
        }
        memmove(to, from, line_ga.ga_len - (from - p) + 1);
        line_ga.ga_len -= from - to;

        // Removed to much indentation, fix it before redrawing.
        num_spaces = indent - old_indent;
        goto add_indent;
      }

      if (c1 == Ctrl_V || c1 == Ctrl_Q) {
        escaped = TRUE;
        continue;
      }

      if (IS_SPECIAL(c1)) {
        // Ignore other special key codes
        continue;
      }
    }

    if (IS_SPECIAL(c1)) {
      c1 = '?';
    }
    len = utf_char2bytes(c1, (char_u *)line_ga.ga_data + line_ga.ga_len);
    if (c1 == '\n') {
      msg_putchar('\n');
    } else if (c1 == TAB) {
      // Don't use chartabsize(), 'ts' can be different.
      do {
        msg_putchar(' ');
      } while (++vcol % 8);
    } else {
      msg_outtrans_len(((char_u *)line_ga.ga_data) + line_ga.ga_len, len);
      vcol += char2cells(c1);
    }
    line_ga.ga_len += len;
    escaped = FALSE;

    ui_cursor_goto(msg_row, msg_col);
    pend = (char_u *)(line_ga.ga_data) + line_ga.ga_len;

    /* We are done when a NL is entered, but not when it comes after an
     * odd number of backslashes, that results in a NUL. */
    if (!GA_EMPTY(&line_ga) && pend[-1] == '\n') {
      int bcount = 0;

      while (line_ga.ga_len - 2 >= bcount && pend[-2 - bcount] == '\\')
        ++bcount;

      if (bcount > 0) {
        /* Halve the number of backslashes: "\NL" -> "NUL", "\\NL" ->
         * "\NL", etc. */
        line_ga.ga_len -= (bcount + 1) / 2;
        pend -= (bcount + 1) / 2;
        pend[-1] = '\n';
      }

      if ((bcount & 1) == 0) {
        --line_ga.ga_len;
        --pend;
        *pend = NUL;
        break;
      }
    }
  }

  no_mapping--;

  /* make following messages go to the next line */
  msg_didout = FALSE;
  msg_col = 0;
  if (msg_row < Rows - 1)
    ++msg_row;
  emsg_on_display = FALSE;              /* don't want os_delay() */

  if (got_int)
    ga_clear(&line_ga);

  return (char_u *)line_ga.ga_data;
}

bool cmdline_overstrike(void)
{
  return ccline.overstrike;
}


/// Return true if the cursor is at the end of the cmdline.
bool cmdline_at_end(void)
{
  return (ccline.cmdpos >= ccline.cmdlen);
}

/*
 * Allocate a new command line buffer.
 * Assigns the new buffer to ccline.cmdbuff and ccline.cmdbufflen.
 * Returns the new value of ccline.cmdbuff and ccline.cmdbufflen.
 */
static void alloc_cmdbuff(int len)
{
  /*
   * give some extra space to avoid having to allocate all the time
   */
  if (len < 80)
    len = 100;
  else
    len += 20;

  ccline.cmdbuff = xmalloc(len);
  ccline.cmdbufflen = len;
}

/*
 * Re-allocate the command line to length len + something extra.
 */
static void realloc_cmdbuff(int len)
{
  if (len < ccline.cmdbufflen) {
    return;  // no need to resize
  }

  char_u *p = ccline.cmdbuff;
  alloc_cmdbuff(len);                   /* will get some more */
  /* There isn't always a NUL after the command, but it may need to be
   * there, thus copy up to the NUL and add a NUL. */
  memmove(ccline.cmdbuff, p, (size_t)ccline.cmdlen);
  ccline.cmdbuff[ccline.cmdlen] = NUL;
  xfree(p);

  if (ccline.xpc != NULL
      && ccline.xpc->xp_pattern != NULL
      && ccline.xpc->xp_context != EXPAND_NOTHING
      && ccline.xpc->xp_context != EXPAND_UNSUCCESSFUL) {
    int i = (int)(ccline.xpc->xp_pattern - p);

    /* If xp_pattern points inside the old cmdbuff it needs to be adjusted
     * to point into the newly allocated memory. */
    if (i >= 0 && i <= ccline.cmdlen)
      ccline.xpc->xp_pattern = ccline.cmdbuff + i;
  }
}

static char_u   *arshape_buf = NULL;

# if defined(EXITFREE)
void free_cmdline_buf(void)
{
  xfree(arshape_buf);
}

# endif

enum { MAX_CB_ERRORS = 1 };

/// Color expression cmdline using built-in expressions parser
///
/// @param[in]  colored_ccline  Command-line to color.
/// @param[out]  ret_ccline_colors  What should be colored.
///
/// Always colors the whole cmdline.
static void color_expr_cmdline(const CmdlineInfo *const colored_ccline,
                               ColoredCmdline *const ret_ccline_colors)
  FUNC_ATTR_NONNULL_ALL
{
  ParserLine plines[] = {
    {
      .data = (const char *)colored_ccline->cmdbuff,
      .size = STRLEN(colored_ccline->cmdbuff),
      .allocated = false,
    },
    { NULL, 0, false },
  };
  ParserLine *plines_p = plines;
  ParserHighlight colors;
  kvi_init(colors);
  ParserState pstate;
  viml_parser_init(
      &pstate, parser_simple_get_line, &plines_p, &colors);
  ExprAST east = viml_pexpr_parse(&pstate, kExprFlagsDisallowEOC);
  viml_pexpr_free_ast(east);
  viml_parser_destroy(&pstate);
  kv_resize(ret_ccline_colors->colors, kv_size(colors));
  size_t prev_end = 0;
  for (size_t i = 0 ; i < kv_size(colors) ; i++) {
    const ParserHighlightChunk chunk = kv_A(colors, i);
    if (chunk.start.col != prev_end) {
      kv_push(ret_ccline_colors->colors, ((CmdlineColorChunk) {
        .start = prev_end,
        .end = chunk.start.col,
        .attr = 0,
      }));
    }
    const int id = syn_name2id((const char_u *)chunk.group);
    const int attr = (id == 0 ? 0 : syn_id2attr(id));
    kv_push(ret_ccline_colors->colors, ((CmdlineColorChunk) {
        .start = chunk.start.col,
        .end = chunk.end_col,
        .attr = attr,
    }));
    prev_end = chunk.end_col;
  }
  if (prev_end < (size_t)colored_ccline->cmdlen) {
    kv_push(ret_ccline_colors->colors, ((CmdlineColorChunk) {
      .start = prev_end,
      .end = (size_t)colored_ccline->cmdlen,
      .attr = 0,
    }));
  }
  kvi_destroy(colors);
}

/// Color command-line
///
/// Should use built-in command parser or user-specified one. Currently only the
/// latter is supported.
///
/// @param[in,out]  colored_ccline  Command-line to color. Also holds a cache:
///                                 if ->prompt_id and ->cmdbuff values happen
///                                 to be equal to those from colored_cmdline it
///                                 will just do nothing, assuming that ->colors
///                                 already contains needed data.
///
/// Always colors the whole cmdline.
///
/// @return true if draw_cmdline may proceed, false if it does not need anything
///         to do.
static bool color_cmdline(CmdlineInfo *colored_ccline)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool printed_errmsg = false;

#define PRINT_ERRMSG(...) \
  do { \
    msg_putchar('\n'); \
    msg_printf_attr(HL_ATTR(HLF_E)|MSG_HIST, __VA_ARGS__); \
    printed_errmsg = true; \
  } while (0)
  bool ret = true;

  ColoredCmdline *ccline_colors = &colored_ccline->last_colors;

  // Check whether result of the previous call is still valid.
  if (ccline_colors->prompt_id == colored_ccline->prompt_id
      && ccline_colors->cmdbuff != NULL
      && STRCMP(ccline_colors->cmdbuff, colored_ccline->cmdbuff) == 0) {
    return ret;
  }

  kv_size(ccline_colors->colors) = 0;

  if (colored_ccline->cmdbuff == NULL || *colored_ccline->cmdbuff == NUL) {
    // Nothing to do, exiting.
    xfree(ccline_colors->cmdbuff);
    ccline_colors->cmdbuff = NULL;
    return ret;
  }

  bool arg_allocated = false;
  typval_T arg = {
    .v_type = VAR_STRING,
    .vval.v_string = colored_ccline->cmdbuff,
  };
  typval_T tv = { .v_type = VAR_UNKNOWN };

  static unsigned prev_prompt_id = UINT_MAX;
  static int prev_prompt_errors = 0;
  Callback color_cb = CALLBACK_NONE;
  bool can_free_cb = false;
  TryState tstate;
  Error err = ERROR_INIT;
  const char *err_errmsg = (const char *)e_intern2;
  bool dgc_ret = true;
  bool tl_ret = true;

  if (colored_ccline->prompt_id != prev_prompt_id) {
    prev_prompt_errors = 0;
    prev_prompt_id = colored_ccline->prompt_id;
  } else if (prev_prompt_errors >= MAX_CB_ERRORS) {
    goto color_cmdline_end;
  }
  if (colored_ccline->highlight_callback.type != kCallbackNone) {
    // Currently this should only happen while processing input() prompts.
    assert(colored_ccline->input_fn);
    color_cb = colored_ccline->highlight_callback;
  } else if (colored_ccline->cmdfirstc == ':') {
    try_enter(&tstate);
    err_errmsg = N_(
        "E5408: Unable to get g:Nvim_color_cmdline callback: %s");
    dgc_ret = tv_dict_get_callback(&globvardict, S_LEN("Nvim_color_cmdline"),
                                   &color_cb);
    tl_ret = try_leave(&tstate, &err);
    can_free_cb = true;
  } else if (colored_ccline->cmdfirstc == '=') {
    color_expr_cmdline(colored_ccline, ccline_colors);
  }
  if (!tl_ret || !dgc_ret) {
    goto color_cmdline_error;
  }

  if (color_cb.type == kCallbackNone) {
    goto color_cmdline_end;
  }
  if (colored_ccline->cmdbuff[colored_ccline->cmdlen] != NUL) {
    arg_allocated = true;
    arg.vval.v_string = xmemdupz((const char *)colored_ccline->cmdbuff,
                                 (size_t)colored_ccline->cmdlen);
  }
  // msg_start() called by e.g. :echo may shift command-line to the first column
  // even though msg_silent is here. Two ways to workaround this problem without
  // altering message.c: use full_screen or save and restore msg_col.
  //
  // Saving and restoring full_screen does not work well with :redraw!. Saving
  // and restoring msg_col is neither ideal, but while with full_screen it
  // appears shifted one character to the right and cursor position is no longer
  // correct, with msg_col it just misses leading `:`. Since `redraw!` in
  // callback lags this is least of the user problems.
  //
  // Also using try_enter() because error messages may overwrite typed
  // command-line which is not expected.
  getln_interrupted_highlight = false;
  try_enter(&tstate);
  err_errmsg = N_("E5407: Callback has thrown an exception: %s");
  const int saved_msg_col = msg_col;
  msg_silent++;
  const bool cbcall_ret = callback_call(&color_cb, 1, &arg, &tv);
  msg_silent--;
  msg_col = saved_msg_col;
  if (got_int) {
    getln_interrupted_highlight = true;
  }
  if (!try_leave(&tstate, &err) || !cbcall_ret) {
    goto color_cmdline_error;
  }
  if (tv.v_type != VAR_LIST) {
    PRINT_ERRMSG(_("E5400: Callback should return list"));
    goto color_cmdline_error;
  }
  if (tv.vval.v_list == NULL) {
    goto color_cmdline_end;
  }
  varnumber_T prev_end = 0;
  int i = 0;
  TV_LIST_ITER_CONST(tv.vval.v_list, li, {
    if (TV_LIST_ITEM_TV(li)->v_type != VAR_LIST) {
      PRINT_ERRMSG(_("E5401: List item %i is not a List"), i);
      goto color_cmdline_error;
    }
    const list_T *const l = TV_LIST_ITEM_TV(li)->vval.v_list;
    if (tv_list_len(l) != 3) {
      PRINT_ERRMSG(_("E5402: List item %i has incorrect length: %d /= 3"),
                   i, tv_list_len(l));
      goto color_cmdline_error;
    }
    bool error = false;
    const varnumber_T start = (
        tv_get_number_chk(TV_LIST_ITEM_TV(tv_list_first(l)), &error));
    if (error) {
      goto color_cmdline_error;
    } else if (!(prev_end <= start && start < colored_ccline->cmdlen)) {
      PRINT_ERRMSG(_("E5403: Chunk %i start %" PRIdVARNUMBER " not in range "
                     "[%" PRIdVARNUMBER ", %i)"),
                   i, start, prev_end, colored_ccline->cmdlen);
      goto color_cmdline_error;
    } else if (utf8len_tab_zero[(uint8_t)colored_ccline->cmdbuff[start]] == 0) {
      PRINT_ERRMSG(_("E5405: Chunk %i start %" PRIdVARNUMBER " splits "
                     "multibyte character"), i, start);
      goto color_cmdline_error;
    }
    if (start != prev_end) {
      kv_push(ccline_colors->colors, ((CmdlineColorChunk) {
        .start = prev_end,
        .end = start,
        .attr = 0,
      }));
    }
    const varnumber_T end = tv_get_number_chk(
        TV_LIST_ITEM_TV(TV_LIST_ITEM_NEXT(l, tv_list_first(l))), &error);
    if (error) {
      goto color_cmdline_error;
    } else if (!(start < end && end <= colored_ccline->cmdlen)) {
      PRINT_ERRMSG(_("E5404: Chunk %i end %" PRIdVARNUMBER " not in range "
                     "(%" PRIdVARNUMBER ", %i]"),
                   i, end, start, colored_ccline->cmdlen);
      goto color_cmdline_error;
    } else if (end < colored_ccline->cmdlen
               && (utf8len_tab_zero[(uint8_t)colored_ccline->cmdbuff[end]]
                   == 0)) {
      PRINT_ERRMSG(_("E5406: Chunk %i end %" PRIdVARNUMBER " splits multibyte "
                     "character"), i, end);
      goto color_cmdline_error;
    }
    prev_end = end;
    const char *const group = tv_get_string_chk(
        TV_LIST_ITEM_TV(tv_list_last(l)));
    if (group == NULL) {
      goto color_cmdline_error;
    }
    const int id = syn_name2id((char_u *)group);
    const int attr = (id == 0 ? 0 : syn_id2attr(id));
    kv_push(ccline_colors->colors, ((CmdlineColorChunk) {
      .start = start,
      .end = end,
      .attr = attr,
    }));
    i++;
  });
  if (prev_end < colored_ccline->cmdlen) {
    kv_push(ccline_colors->colors, ((CmdlineColorChunk) {
      .start = prev_end,
      .end = colored_ccline->cmdlen,
      .attr = 0,
    }));
  }
  prev_prompt_errors = 0;
color_cmdline_end:
  assert(!ERROR_SET(&err));
  if (can_free_cb) {
    callback_free(&color_cb);
  }
  xfree(ccline_colors->cmdbuff);
  // Note: errors “output” is cached just as well as regular results.
  ccline_colors->prompt_id = colored_ccline->prompt_id;
  if (arg_allocated) {
    ccline_colors->cmdbuff = (char *)arg.vval.v_string;
  } else {
    ccline_colors->cmdbuff = xmemdupz((const char *)colored_ccline->cmdbuff,
                                      (size_t)colored_ccline->cmdlen);
  }
  tv_clear(&tv);
  return ret;
color_cmdline_error:
  if (ERROR_SET(&err)) {
    PRINT_ERRMSG(_(err_errmsg), err.msg);
    api_clear_error(&err);
  }
  assert(printed_errmsg);
  (void)printed_errmsg;

  prev_prompt_errors++;
  kv_size(ccline_colors->colors) = 0;
  redrawcmdline();
  ret = false;
  goto color_cmdline_end;
#undef PRINT_ERRMSG
}

/*
 * Draw part of the cmdline at the current cursor position.  But draw stars
 * when cmdline_star is TRUE.
 */
static void draw_cmdline(int start, int len)
{
  if (!color_cmdline(&ccline)) {
    return;
  }

  if (ui_is_external(kUICmdline)) {
    ccline.special_char = NUL;
    ccline.redraw_state = kCmdRedrawAll;
    return;
  }

  if (cmdline_star > 0) {
    for (int i = 0; i < len; i++) {
      msg_putchar('*');
      if (has_mbyte) {
        i += (*mb_ptr2len)(ccline.cmdbuff + start + i) - 1;
      }
    }
  } else if (p_arshape && !p_tbidi && enc_utf8 && len > 0) {
    bool do_arabicshape = false;
    int mb_l;
    for (int i = start; i < start + len; i += mb_l) {
      char_u *p = ccline.cmdbuff + i;
      int u8cc[MAX_MCO];
      int u8c = utfc_ptr2char_len(p, u8cc, start + len - i);
      mb_l = utfc_ptr2len_len(p, start + len - i);
      if (arabic_char(u8c)) {
        do_arabicshape = true;
        break;
      }
    }
    if (!do_arabicshape) {
      goto draw_cmdline_no_arabicshape;
    }

    static int buflen = 0;

    // Do arabic shaping into a temporary buffer.  This is very
    // inefficient!
    if (len * 2 + 2 > buflen) {
      // Re-allocate the buffer.  We keep it around to avoid a lot of
      // alloc()/free() calls.
      xfree(arshape_buf);
      buflen = len * 2 + 2;
      arshape_buf = xmalloc(buflen);
    }

    int newlen = 0;
    if (utf_iscomposing(utf_ptr2char(ccline.cmdbuff + start))) {
      // Prepend a space to draw the leading composing char on.
      arshape_buf[0] = ' ';
      newlen = 1;
    }

    int prev_c = 0;
    int prev_c1 = 0;
    for (int i = start; i < start + len; i += mb_l) {
      char_u *p = ccline.cmdbuff + i;
      int u8cc[MAX_MCO];
      int u8c = utfc_ptr2char_len(p, u8cc, start + len - i);
      mb_l = utfc_ptr2len_len(p, start + len - i);
      if (arabic_char(u8c)) {
        int pc;
        int pc1 = 0;
        int nc = 0;
        // Do Arabic shaping.
        if (cmdmsg_rl) {
          // Displaying from right to left.
          pc = prev_c;
          pc1 = prev_c1;
          prev_c1 = u8cc[0];
          if (i + mb_l >= start + len) {
            nc = NUL;
          } else {
            nc = utf_ptr2char(p + mb_l);
          }
        } else {
          // Displaying from left to right.
          if (i + mb_l >= start + len) {
            pc = NUL;
          } else {
            int pcc[MAX_MCO];

            pc = utfc_ptr2char_len(p + mb_l, pcc, start + len - i - mb_l);
            pc1 = pcc[0];
          }
          nc = prev_c;
        }
        prev_c = u8c;

        u8c = arabic_shape(u8c, NULL, &u8cc[0], pc, pc1, nc);

        newlen += utf_char2bytes(u8c, arshape_buf + newlen);
        if (u8cc[0] != 0) {
          newlen += utf_char2bytes(u8cc[0], arshape_buf + newlen);
          if (u8cc[1] != 0) {
            newlen += utf_char2bytes(u8cc[1], arshape_buf + newlen);
          }
        }
      } else {
        prev_c = u8c;
        memmove(arshape_buf + newlen, p, mb_l);
        newlen += mb_l;
      }
    }

    msg_outtrans_len(arshape_buf, newlen);
  } else {
draw_cmdline_no_arabicshape:
    if (kv_size(ccline.last_colors.colors)) {
      for (size_t i = 0; i < kv_size(ccline.last_colors.colors); i++) {
        CmdlineColorChunk chunk = kv_A(ccline.last_colors.colors, i);
        if (chunk.end <= start) {
          continue;
        }
        const int chunk_start = MAX(chunk.start, start);
        msg_outtrans_len_attr(ccline.cmdbuff + chunk_start,
                              chunk.end - chunk_start,
                              chunk.attr);
      }
    } else {
      msg_outtrans_len(ccline.cmdbuff + start, len);
    }
  }
}

static void ui_ext_cmdline_show(CmdlineInfo *line)
{
  Array content = ARRAY_DICT_INIT;
  if (cmdline_star) {
    size_t len = 0;
    for (char_u *p = ccline.cmdbuff; *p; MB_PTR_ADV(p)) {
      len++;
    }
    char *buf = xmallocz(len);
    memset(buf, '*', len);
    Array item = ARRAY_DICT_INIT;
    ADD(item, INTEGER_OBJ(0));
    ADD(item, STRING_OBJ(((String) { .data = buf, .size = len })));
    ADD(content, ARRAY_OBJ(item));
  } else if (kv_size(line->last_colors.colors)) {
    for (size_t i = 0; i < kv_size(line->last_colors.colors); i++) {
      CmdlineColorChunk chunk = kv_A(line->last_colors.colors, i);
      Array item = ARRAY_DICT_INIT;
      ADD(item, INTEGER_OBJ(chunk.attr));

      ADD(item, STRING_OBJ(cbuf_to_string((char *)line->cmdbuff + chunk.start,
                                          chunk.end-chunk.start)));
      ADD(content, ARRAY_OBJ(item));
    }
  } else {
    Array item = ARRAY_DICT_INIT;
    ADD(item, INTEGER_OBJ(0));
    ADD(item, STRING_OBJ(cstr_to_string((char *)(line->cmdbuff))));
    ADD(content, ARRAY_OBJ(item));
  }
  ui_call_cmdline_show(content, line->cmdpos,
                       cchar_to_string((char)line->cmdfirstc),
                       cstr_to_string((char *)(line->cmdprompt)),
                       line->cmdindent,
                       line->level);
  if (line->special_char) {
    ui_call_cmdline_special_char(cchar_to_string((char)(line->special_char)),
                                 line->special_shift,
                                 line->level);
  }
}

void ui_ext_cmdline_block_append(int indent, const char *line)
{
  char *buf = xmallocz(indent + strlen(line));
  memset(buf, ' ', indent);
  memcpy(buf + indent, line, strlen(line));  // -V575

  Array item = ARRAY_DICT_INIT;
  ADD(item, INTEGER_OBJ(0));
  ADD(item, STRING_OBJ(cstr_as_string(buf)));
  Array content = ARRAY_DICT_INIT;
  ADD(content, ARRAY_OBJ(item));
  ADD(cmdline_block, ARRAY_OBJ(content));
  if (cmdline_block.size > 1) {
    ui_call_cmdline_block_append(copy_array(content));
  } else {
    ui_call_cmdline_block_show(copy_array(cmdline_block));
  }
}

void ui_ext_cmdline_block_leave(void)
{
  api_free_array(cmdline_block);
  cmdline_block = (Array)ARRAY_DICT_INIT;
  ui_call_cmdline_block_hide();
}

/// Extra redrawing needed for redraw! and on ui_attach
/// assumes "redrawcmdline()" will already be invoked
void cmdline_screen_cleared(void)
{
  if (!ui_is_external(kUICmdline)) {
    return;
  }

  if (cmdline_block.size) {
    ui_call_cmdline_block_show(copy_array(cmdline_block));
  }

  int prev_level = ccline.level-1;
  CmdlineInfo *line = ccline.prev_ccline;
  while (prev_level > 0 && line) {
    if (line->level == prev_level) {
      // don't redraw a cmdline already shown in the cmdline window
      if (prev_level != cmdwin_level) {
        line->redraw_state = kCmdRedrawAll;
      }
      prev_level--;
    }
    line = line->prev_ccline;
  }
}

/// called by ui_flush, do what redraws neccessary to keep cmdline updated.
void cmdline_ui_flush(void)
{
  if (!ui_is_external(kUICmdline)) {
    return;
  }
  int level = ccline.level;
  CmdlineInfo *line = &ccline;
  while (level > 0 && line) {
    if (line->level == level) {
      if (line->redraw_state == kCmdRedrawAll) {
        ui_ext_cmdline_show(line);
      } else if (line->redraw_state == kCmdRedrawPos) {
        ui_call_cmdline_pos(line->cmdpos, line->level);
      }
      line->redraw_state = kCmdRedrawNone;
      level--;
    }
    line = line->prev_ccline;
  }
}

/*
 * Put a character on the command line.  Shifts the following text to the
 * right when "shift" is TRUE.  Used for CTRL-V, CTRL-K, etc.
 * "c" must be printable (fit in one display cell)!
 */
void putcmdline(int c, int shift)
{
  if (cmd_silent) {
    return;
  }
  if (!ui_is_external(kUICmdline)) {
    msg_no_more = true;
    msg_putchar(c);
    if (shift) {
      draw_cmdline(ccline.cmdpos, ccline.cmdlen - ccline.cmdpos);
    }
    msg_no_more = false;
  } else {
    ccline.special_char = c;
    ccline.special_shift = shift;
    if (ccline.redraw_state != kCmdRedrawAll) {
      ui_call_cmdline_special_char(cchar_to_string((char)(c)), shift,
                                   ccline.level);
    }
  }
  cursorcmd();
  ui_cursor_shape();
}

/// Undo a putcmdline(c, FALSE).
void unputcmdline(void)
{
  if (cmd_silent) {
    return;
  }
  msg_no_more = true;
  if (ccline.cmdlen == ccline.cmdpos && !ui_is_external(kUICmdline)) {
    msg_putchar(' ');
  } else {
    draw_cmdline(ccline.cmdpos, mb_ptr2len(ccline.cmdbuff + ccline.cmdpos));
  }
  msg_no_more = false;
  cursorcmd();
  ui_cursor_shape();
}

/*
 * Put the given string, of the given length, onto the command line.
 * If len is -1, then STRLEN() is used to calculate the length.
 * If 'redraw' is TRUE then the new part of the command line, and the remaining
 * part will be redrawn, otherwise it will not.  If this function is called
 * twice in a row, then 'redraw' should be FALSE and redrawcmd() should be
 * called afterwards.
 */
void put_on_cmdline(char_u *str, int len, int redraw)
{
  int i;
  int m;
  int c;

  if (len < 0)
    len = (int)STRLEN(str);

  realloc_cmdbuff(ccline.cmdlen + len + 1);

  if (!ccline.overstrike) {
    memmove(ccline.cmdbuff + ccline.cmdpos + len,
        ccline.cmdbuff + ccline.cmdpos,
        (size_t)(ccline.cmdlen - ccline.cmdpos));
    ccline.cmdlen += len;
  } else {
    if (has_mbyte) {
      /* Count nr of characters in the new string. */
      m = 0;
      for (i = 0; i < len; i += (*mb_ptr2len)(str + i))
        ++m;
      /* Count nr of bytes in cmdline that are overwritten by these
       * characters. */
      for (i = ccline.cmdpos; i < ccline.cmdlen && m > 0;
           i += (*mb_ptr2len)(ccline.cmdbuff + i))
        --m;
      if (i < ccline.cmdlen) {
        memmove(ccline.cmdbuff + ccline.cmdpos + len,
            ccline.cmdbuff + i, (size_t)(ccline.cmdlen - i));
        ccline.cmdlen += ccline.cmdpos + len - i;
      } else
        ccline.cmdlen = ccline.cmdpos + len;
    } else if (ccline.cmdpos + len > ccline.cmdlen)
      ccline.cmdlen = ccline.cmdpos + len;
  }
  memmove(ccline.cmdbuff + ccline.cmdpos, str, (size_t)len);
  ccline.cmdbuff[ccline.cmdlen] = NUL;

  if (enc_utf8) {
    /* When the inserted text starts with a composing character,
     * backup to the character before it.  There could be two of them.
     */
    i = 0;
    c = utf_ptr2char(ccline.cmdbuff + ccline.cmdpos);
    while (ccline.cmdpos > 0 && utf_iscomposing(c)) {
      i = utf_head_off(ccline.cmdbuff, ccline.cmdbuff + ccline.cmdpos - 1) + 1;
      ccline.cmdpos -= i;
      len += i;
      c = utf_ptr2char(ccline.cmdbuff + ccline.cmdpos);
    }
    if (i == 0 && ccline.cmdpos > 0 && arabic_maycombine(c)) {
      // Check the previous character for Arabic combining pair.
      i = utf_head_off(ccline.cmdbuff, ccline.cmdbuff + ccline.cmdpos - 1) + 1;
      if (arabic_combine(utf_ptr2char(ccline.cmdbuff + ccline.cmdpos - i), c)) {
        ccline.cmdpos -= i;
        len += i;
      } else
        i = 0;
    }
    if (i != 0) {
      /* Also backup the cursor position. */
      i = ptr2cells(ccline.cmdbuff + ccline.cmdpos);
      ccline.cmdspos -= i;
      msg_col -= i;
      if (msg_col < 0) {
        msg_col += Columns;
        --msg_row;
      }
    }
  }

  if (redraw && !cmd_silent) {
    msg_no_more = TRUE;
    i = cmdline_row;
    cursorcmd();
    draw_cmdline(ccline.cmdpos, ccline.cmdlen - ccline.cmdpos);
    /* Avoid clearing the rest of the line too often. */
    if (cmdline_row != i || ccline.overstrike)
      msg_clr_eos();
    msg_no_more = FALSE;
  }
  /*
   * If we are in Farsi command mode, the character input must be in
   * Insert mode. So do not advance the cmdpos.
   */
  if (!cmd_fkmap) {
    if (KeyTyped) {
      m = Columns * Rows;
      if (m < 0)              /* overflow, Columns or Rows at weird value */
        m = MAXCOL;
    } else
      m = MAXCOL;
    for (i = 0; i < len; ++i) {
      c = cmdline_charsize(ccline.cmdpos);
      /* count ">" for a double-wide char that doesn't fit. */
      if (has_mbyte)
        correct_cmdspos(ccline.cmdpos, c);
      /* Stop cursor at the end of the screen, but do increment the
       * insert position, so that entering a very long command
       * works, even though you can't see it. */
      if (ccline.cmdspos + c < m)
        ccline.cmdspos += c;
      if (has_mbyte) {
        c = (*mb_ptr2len)(ccline.cmdbuff + ccline.cmdpos) - 1;
        if (c > len - i - 1)
          c = len - i - 1;
        ccline.cmdpos += c;
        i += c;
      }
      ++ccline.cmdpos;
    }
  }

  if (redraw)
    msg_check();
}

/*
 * Save ccline, because obtaining the "=" register may execute "normal :cmd"
 * and overwrite it.  But get_cmdline_str() may need it, thus make it
 * available globally in prev_ccline.
 */
static void save_cmdline(struct cmdline_info *ccp)
{
  *ccp = ccline;
  ccline.prev_ccline = ccp;
  ccline.cmdbuff = NULL;
  ccline.cmdprompt = NULL;
  ccline.xpc = NULL;
  ccline.special_char = NUL;
  ccline.level = 0;
}

/*
 * Restore ccline after it has been saved with save_cmdline().
 */
static void restore_cmdline(struct cmdline_info *ccp)
{
  ccline = *ccp;
}

/*
 * Save the command line into allocated memory.  Returns a pointer to be
 * passed to restore_cmdline_alloc() later.
 */
char_u *save_cmdline_alloc(void)
{
  struct cmdline_info *p = xmalloc(sizeof(struct cmdline_info));
  save_cmdline(p);
  return (char_u *)p;
}

/*
 * Restore the command line from the return value of save_cmdline_alloc().
 */
void restore_cmdline_alloc(char_u *p)
{
  restore_cmdline((struct cmdline_info *)p);
  xfree(p);
}

/// Paste a yank register into the command line.
/// Used by CTRL-R command in command-line mode.
/// insert_reg() can't be used here, because special characters from the
/// register contents will be interpreted as commands.
///
/// @param regname   Register name.
/// @param literally Insert text literally instead of "as typed".
/// @param remcr     When true, remove trailing CR.
///
/// @returns FAIL for failure, OK otherwise
static bool cmdline_paste(int regname, bool literally, bool remcr)
{
  char_u              *arg;
  char_u              *p;
  bool allocated;
  struct cmdline_info save_ccline;

  /* check for valid regname; also accept special characters for CTRL-R in
   * the command line */
  if (regname != Ctrl_F && regname != Ctrl_P && regname != Ctrl_W
      && regname != Ctrl_A && regname != Ctrl_L
      && !valid_yank_reg(regname, false)) {
    return FAIL;
  }

  /* A register containing CTRL-R can cause an endless loop.  Allow using
   * CTRL-C to break the loop. */
  line_breakcheck();
  if (got_int)
    return FAIL;


  /* Need to save and restore ccline.  And set "textlock" to avoid nasty
   * things like going to another buffer when evaluating an expression. */
  save_cmdline(&save_ccline);
  textlock++;
  const bool i = get_spec_reg(regname, &arg, &allocated, true);
  textlock--;
  restore_cmdline(&save_ccline);

  if (i) {
    /* Got the value of a special register in "arg". */
    if (arg == NULL)
      return FAIL;

    /* When 'incsearch' is set and CTRL-R CTRL-W used: skip the duplicate
     * part of the word. */
    p = arg;
    if (p_is && regname == Ctrl_W) {
      char_u  *w;
      int len;

      /* Locate start of last word in the cmd buffer. */
      for (w = ccline.cmdbuff + ccline.cmdpos; w > ccline.cmdbuff; ) {
        len = utf_head_off(ccline.cmdbuff, w - 1) + 1;
        if (!vim_iswordc(utf_ptr2char(w - len))) {
          break;
        }
        w -= len;
      }
      len = (int)((ccline.cmdbuff + ccline.cmdpos) - w);
      if (p_ic ? STRNICMP(w, arg, len) == 0 : STRNCMP(w, arg, len) == 0)
        p += len;
    }

    cmdline_paste_str(p, literally);
    if (allocated)
      xfree(arg);
    return OK;
  }

  return cmdline_paste_reg(regname, literally, remcr);
}

/*
 * Put a string on the command line.
 * When "literally" is TRUE, insert literally.
 * When "literally" is FALSE, insert as typed, but don't leave the command
 * line.
 */
void cmdline_paste_str(char_u *s, int literally)
{
  int c, cv;

  if (literally)
    put_on_cmdline(s, -1, TRUE);
  else
    while (*s != NUL) {
      cv = *s;
      if (cv == Ctrl_V && s[1]) {
        s++;
      }
      if (has_mbyte) {
        c = mb_cptr2char_adv((const char_u **)&s);
      } else {
        c = *s++;
      }
      if (cv == Ctrl_V || c == ESC || c == Ctrl_C
          || c == CAR || c == NL || c == Ctrl_L
          || (c == Ctrl_BSL && *s == Ctrl_N)) {
        stuffcharReadbuff(Ctrl_V);
      }
      stuffcharReadbuff(c);
    }
}

/*
 * Delete characters on the command line, from "from" to the current
 * position.
 */
static void cmdline_del(int from)
{
  memmove(ccline.cmdbuff + from, ccline.cmdbuff + ccline.cmdpos,
      (size_t)(ccline.cmdlen - ccline.cmdpos + 1));
  ccline.cmdlen -= ccline.cmdpos - from;
  ccline.cmdpos = from;
}

// This function is called when the screen size changes and with incremental
// search and in other situations where the command line may have been
// overwritten.
void redrawcmdline(void)
{
  if (cmd_silent)
    return;
  need_wait_return = FALSE;
  compute_cmdrow();
  redrawcmd();
  cursorcmd();
  ui_cursor_shape();
}

static void redrawcmdprompt(void)
{
  int i;

  if (cmd_silent)
    return;
  if (ui_is_external(kUICmdline)) {
    ccline.redraw_state = kCmdRedrawAll;
    return;
  }
  if (ccline.cmdfirstc != NUL) {
    msg_putchar(ccline.cmdfirstc);
  }
  if (ccline.cmdprompt != NULL) {
    msg_puts_attr((const char *)ccline.cmdprompt, ccline.cmdattr);
    ccline.cmdindent = msg_col + (msg_row - cmdline_row) * Columns;
    // do the reverse of set_cmdspos()
    if (ccline.cmdfirstc != NUL) {
      ccline.cmdindent--;
    }
  } else {
    for (i = ccline.cmdindent; i > 0; i--) {
      msg_putchar(' ');
    }
  }
}

/*
 * Redraw what is currently on the command line.
 */
void redrawcmd(void)
{
  if (cmd_silent)
    return;

  if (ui_is_external(kUICmdline)) {
    draw_cmdline(0, ccline.cmdlen);
    return;
  }

  /* when 'incsearch' is set there may be no command line while redrawing */
  if (ccline.cmdbuff == NULL) {
    ui_cursor_goto(cmdline_row, 0);
    msg_clr_eos();
    return;
  }

  msg_start();
  redrawcmdprompt();

  /* Don't use more prompt, truncate the cmdline if it doesn't fit. */
  msg_no_more = TRUE;
  draw_cmdline(0, ccline.cmdlen);
  msg_clr_eos();
  msg_no_more = FALSE;

  set_cmdspos_cursor();

  /*
   * An emsg() before may have set msg_scroll. This is used in normal mode,
   * in cmdline mode we can reset them now.
   */
  msg_scroll = FALSE;           /* next message overwrites cmdline */

  /* Typing ':' at the more prompt may set skip_redraw.  We don't want this
   * in cmdline mode */
  skip_redraw = FALSE;
}

void compute_cmdrow(void)
{
  if (exmode_active || msg_scrolled != 0)
    cmdline_row = Rows - 1;
  else
    cmdline_row = lastwin->w_winrow + lastwin->w_height
                  + lastwin->w_status_height;
}

static void cursorcmd(void)
{
  if (cmd_silent)
    return;

  if (ui_is_external(kUICmdline)) {
    if (ccline.redraw_state < kCmdRedrawPos) {
      ccline.redraw_state = kCmdRedrawPos;
    }
    setcursor();
    return;
  }

  if (cmdmsg_rl) {
    msg_row = cmdline_row  + (ccline.cmdspos / (int)(Columns - 1));
    msg_col = (int)Columns - (ccline.cmdspos % (int)(Columns - 1)) - 1;
    if (msg_row <= 0)
      msg_row = Rows - 1;
  } else {
    msg_row = cmdline_row + (ccline.cmdspos / (int)Columns);
    msg_col = ccline.cmdspos % (int)Columns;
    if (msg_row >= Rows)
      msg_row = Rows - 1;
  }

  ui_cursor_goto(msg_row, msg_col);
}

void gotocmdline(int clr)
{
  if (ui_is_external(kUICmdline)) {
    return;
  }
  msg_start();
  if (cmdmsg_rl)
    msg_col = Columns - 1;
  else
    msg_col = 0;            /* always start in column 0 */
  if (clr)                  /* clear the bottom line(s) */
    msg_clr_eos();          /* will reset clear_cmdline */
  ui_cursor_goto(cmdline_row, 0);
}

/*
 * Check the word in front of the cursor for an abbreviation.
 * Called when the non-id character "c" has been entered.
 * When an abbreviation is recognized it is removed from the text with
 * backspaces and the replacement string is inserted, followed by "c".
 */
static int ccheck_abbr(int c)
{
  int spos = 0;

  if (p_paste || no_abbr) {         // no abbreviations or in paste mode
    return false;
  }

  // Do not consider '<,'> be part of the mapping, skip leading whitespace.
  // Actually accepts any mark.
  while (ascii_iswhite(ccline.cmdbuff[spos]) && spos < ccline.cmdlen) {
    spos++;
  }
  if (ccline.cmdlen - spos > 5
      && ccline.cmdbuff[spos] == '\''
      && ccline.cmdbuff[spos + 2] == ','
      && ccline.cmdbuff[spos + 3] == '\'') {
    spos += 5;
  } else {
    // check abbreviation from the beginning of the commandline
    spos = 0;
  }

  return check_abbr(c, ccline.cmdbuff, ccline.cmdpos, spos);
}

static int sort_func_compare(const void *s1, const void *s2)
{
  char_u *p1 = *(char_u **)s1;
  char_u *p2 = *(char_u **)s2;

  if (*p1 != '<' && *p2 == '<') return -1;
  if (*p1 == '<' && *p2 != '<') return 1;
  return STRCMP(p1, p2);
}

/*
 * Return FAIL if this is not an appropriate context in which to do
 * completion of anything, return OK if it is (even if there are no matches).
 * For the caller, this means that the character is just passed through like a
 * normal character (instead of being expanded).  This allows :s/^I^D etc.
 */
static int 
nextwild (
    expand_T *xp,
    int type,
    int options,                    /* extra options for ExpandOne() */
    int escape                     /* if TRUE, escape the returned matches */
)
{
  int i, j;
  char_u      *p1;
  char_u      *p2;
  int difflen;

  if (xp->xp_numfiles == -1) {
    set_expand_context(xp);
    cmd_showtail = expand_showtail(xp);
  }

  if (xp->xp_context == EXPAND_UNSUCCESSFUL) {
    beep_flush();
    return OK;      /* Something illegal on command line */
  }
  if (xp->xp_context == EXPAND_NOTHING) {
    /* Caller can use the character as a normal char instead */
    return FAIL;
  }

  if (!ui_is_external(kUIWildmenu)) {
    MSG_PUTS("...");  // show that we are busy
    ui_flush();
  }

  i = (int)(xp->xp_pattern - ccline.cmdbuff);
  xp->xp_pattern_len = ccline.cmdpos - i;

  if (type == WILD_NEXT || type == WILD_PREV) {
    // Get next/previous match for a previous expanded pattern.
    p2 = ExpandOne(xp, NULL, NULL, 0, type);
  } else {
    // Translate string into pattern and expand it.
    p1 = addstar(xp->xp_pattern, xp->xp_pattern_len, xp->xp_context);
    const int use_options = (
        options
        | WILD_HOME_REPLACE
        | WILD_ADD_SLASH
        | WILD_SILENT
        | (escape ? WILD_ESCAPE : 0)
        | (p_wic ? WILD_ICASE : 0));
    p2 = ExpandOne(xp, p1, vim_strnsave(&ccline.cmdbuff[i], xp->xp_pattern_len),
                   use_options, type);
    xfree(p1);
    // Longest match: make sure it is not shorter, happens with :help.
    if (p2 != NULL && type == WILD_LONGEST) {
      for (j = 0; j < xp->xp_pattern_len; j++) {
        if (ccline.cmdbuff[i + j] == '*'
            || ccline.cmdbuff[i + j] == '?') {
          break;
        }
      }
      if ((int)STRLEN(p2) < j) {
        xfree(p2);
        p2 = NULL;
      }
    }
  }

  if (p2 != NULL && !got_int) {
    difflen = (int)STRLEN(p2) - xp->xp_pattern_len;
    if (ccline.cmdlen + difflen + 4 > ccline.cmdbufflen) {
      realloc_cmdbuff(ccline.cmdlen + difflen + 4);
      xp->xp_pattern = ccline.cmdbuff + i;
    }
    memmove(&ccline.cmdbuff[ccline.cmdpos + difflen],
        &ccline.cmdbuff[ccline.cmdpos],
        (size_t)(ccline.cmdlen - ccline.cmdpos + 1));
    memmove(&ccline.cmdbuff[i], p2, STRLEN(p2));
    ccline.cmdlen += difflen;
    ccline.cmdpos += difflen;
  }
  xfree(p2);

  redrawcmd();
  cursorcmd();

  /* When expanding a ":map" command and no matches are found, assume that
   * the key is supposed to be inserted literally */
  if (xp->xp_context == EXPAND_MAPPINGS && p2 == NULL)
    return FAIL;

  if (xp->xp_numfiles <= 0 && p2 == NULL)
    beep_flush();
  else if (xp->xp_numfiles == 1)
    /* free expanded pattern */
    (void)ExpandOne(xp, NULL, NULL, 0, WILD_FREE);

  return OK;
}

/*
 * Do wildcard expansion on the string 'str'.
 * Chars that should not be expanded must be preceded with a backslash.
 * Return a pointer to allocated memory containing the new string.
 * Return NULL for failure.
 *
 * "orig" is the originally expanded string, copied to allocated memory.  It
 * should either be kept in orig_save or freed.  When "mode" is WILD_NEXT or
 * WILD_PREV "orig" should be NULL.
 *
 * Results are cached in xp->xp_files and xp->xp_numfiles, except when "mode"
 * is WILD_EXPAND_FREE or WILD_ALL.
 *
 * mode = WILD_FREE:	    just free previously expanded matches
 * mode = WILD_EXPAND_FREE: normal expansion, do not keep matches
 * mode = WILD_EXPAND_KEEP: normal expansion, keep matches
 * mode = WILD_NEXT:	    use next match in multiple match, wrap to first
 * mode = WILD_PREV:	    use previous match in multiple match, wrap to first
 * mode = WILD_ALL:	    return all matches concatenated
 * mode = WILD_LONGEST:	    return longest matched part
 * mode = WILD_ALL_KEEP:    get all matches, keep matches
 *
 * options = WILD_LIST_NOTFOUND:    list entries without a match
 * options = WILD_HOME_REPLACE:	    do home_replace() for buffer names
 * options = WILD_USE_NL:	    Use '\n' for WILD_ALL
 * options = WILD_NO_BEEP:	    Don't beep for multiple matches
 * options = WILD_ADD_SLASH:	    add a slash after directory names
 * options = WILD_KEEP_ALL:	    don't remove 'wildignore' entries
 * options = WILD_SILENT:	    don't print warning messages
 * options = WILD_ESCAPE:	    put backslash before special chars
 * options = WILD_ICASE:	    ignore case for files
 *
 * The variables xp->xp_context and xp->xp_backslash must have been set!
 */
char_u *
ExpandOne (
    expand_T *xp,
    char_u *str,
    char_u *orig,          /* allocated copy of original of expanded string */
    int options,
    int mode
)
{
  char_u      *ss = NULL;
  static int findex;
  static char_u *orig_save = NULL;      /* kept value of orig */
  int orig_saved = FALSE;
  int i;
  int non_suf_match;                    /* number without matching suffix */

  /*
   * first handle the case of using an old match
   */
  if (mode == WILD_NEXT || mode == WILD_PREV) {
    if (xp->xp_numfiles > 0) {
      if (mode == WILD_PREV) {
        if (findex == -1)
          findex = xp->xp_numfiles;
        --findex;
      } else        /* mode == WILD_NEXT */
        ++findex;

      /*
       * When wrapping around, return the original string, set findex to
       * -1.
       */
      if (findex < 0) {
        if (orig_save == NULL)
          findex = xp->xp_numfiles - 1;
        else
          findex = -1;
      }
      if (findex >= xp->xp_numfiles) {
        if (orig_save == NULL)
          findex = 0;
        else
          findex = -1;
      }
      if (p_wmnu) {
        if (ui_is_external(kUIWildmenu)) {
          ui_call_wildmenu_select(findex);
        } else {
          win_redr_status_matches(xp, xp->xp_numfiles, xp->xp_files,
                                  findex, cmd_showtail);
        }
      }
      if (findex == -1) {
        return vim_strsave(orig_save);
      }
      return vim_strsave(xp->xp_files[findex]);
    } else
      return NULL;
  }

  /* free old names */
  if (xp->xp_numfiles != -1 && mode != WILD_ALL && mode != WILD_LONGEST) {
    FreeWild(xp->xp_numfiles, xp->xp_files);
    xp->xp_numfiles = -1;
    xfree(orig_save);
    orig_save = NULL;
  }
  findex = 0;

  if (mode == WILD_FREE)        /* only release file name */
    return NULL;

  if (xp->xp_numfiles == -1) {
    xfree(orig_save);
    orig_save = orig;
    orig_saved = TRUE;

    /*
     * Do the expansion.
     */
    if (ExpandFromContext(xp, str, &xp->xp_numfiles, &xp->xp_files,
            options) == FAIL) {
#ifdef FNAME_ILLEGAL
      /* Illegal file name has been silently skipped.  But when there
       * are wildcards, the real problem is that there was no match,
       * causing the pattern to be added, which has illegal characters.
       */
      if (!(options & WILD_SILENT) && (options & WILD_LIST_NOTFOUND))
        EMSG2(_(e_nomatch2), str);
#endif
    } else if (xp->xp_numfiles == 0) {
      if (!(options & WILD_SILENT))
        EMSG2(_(e_nomatch2), str);
    } else {
      /* Escape the matches for use on the command line. */
      ExpandEscape(xp, str, xp->xp_numfiles, xp->xp_files, options);

      /*
       * Check for matching suffixes in file names.
       */
      if (mode != WILD_ALL && mode != WILD_ALL_KEEP
          && mode != WILD_LONGEST) {
        if (xp->xp_numfiles)
          non_suf_match = xp->xp_numfiles;
        else
          non_suf_match = 1;
        if ((xp->xp_context == EXPAND_FILES
             || xp->xp_context == EXPAND_DIRECTORIES)
            && xp->xp_numfiles > 1) {
          /*
           * More than one match; check suffix.
           * The files will have been sorted on matching suffix in
           * expand_wildcards, only need to check the first two.
           */
          non_suf_match = 0;
          for (i = 0; i < 2; ++i)
            if (match_suffix(xp->xp_files[i]))
              ++non_suf_match;
        }
        if (non_suf_match != 1) {
          /* Can we ever get here unless it's while expanding
           * interactively?  If not, we can get rid of this all
           * together. Don't really want to wait for this message
           * (and possibly have to hit return to continue!).
           */
          if (!(options & WILD_SILENT))
            EMSG(_(e_toomany));
          else if (!(options & WILD_NO_BEEP))
            beep_flush();
        }
        if (!(non_suf_match != 1 && mode == WILD_EXPAND_FREE))
          ss = vim_strsave(xp->xp_files[0]);
      }
    }
  }

  // Find longest common part
  if (mode == WILD_LONGEST && xp->xp_numfiles > 0) {
    size_t len = 0;

    for (size_t mb_len; xp->xp_files[0][len]; len += mb_len) {
      mb_len = utfc_ptr2len(&xp->xp_files[0][len]);
      int c0 = utf_ptr2char(&xp->xp_files[0][len]);
      for (i = 1; i < xp->xp_numfiles; i++) {
        int ci = utf_ptr2char(&xp->xp_files[i][len]);

        if (p_fic && (xp->xp_context == EXPAND_DIRECTORIES
                      || xp->xp_context == EXPAND_FILES
                      || xp->xp_context == EXPAND_SHELLCMD
                      || xp->xp_context == EXPAND_BUFFERS)) {
          if (mb_tolower(c0) != mb_tolower(ci)) {
            break;
          }
        } else if (c0 != ci) {
          break;
        }
      }
      if (i < xp->xp_numfiles) {
        if (!(options & WILD_NO_BEEP)) {
          vim_beep(BO_WILD);
        }
        break;
      }
    }

    ss = (char_u *)xstrndup((char *)xp->xp_files[0], len);
    findex = -1;  // next p_wc gets first one
  }

  // Concatenate all matching names
  // TODO(philix): use xstpcpy instead of strcat in a loop (ExpandOne)
  if (mode == WILD_ALL && xp->xp_numfiles > 0) {
    size_t len = 0;
    for (i = 0; i < xp->xp_numfiles; ++i)
      len += STRLEN(xp->xp_files[i]) + 1;
    ss = xmalloc(len);
    *ss = NUL;
    for (i = 0; i < xp->xp_numfiles; ++i) {
      STRCAT(ss, xp->xp_files[i]);
      if (i != xp->xp_numfiles - 1)
        STRCAT(ss, (options & WILD_USE_NL) ? "\n" : " ");
    }
  }

  if (mode == WILD_EXPAND_FREE || mode == WILD_ALL)
    ExpandCleanup(xp);

  /* Free "orig" if it wasn't stored in "orig_save". */
  if (!orig_saved)
    xfree(orig);

  return ss;
}

/*
 * Prepare an expand structure for use.
 */
void ExpandInit(expand_T *xp)
{
  xp->xp_pattern = NULL;
  xp->xp_pattern_len = 0;
  xp->xp_backslash = XP_BS_NONE;
#ifndef BACKSLASH_IN_FILENAME
  xp->xp_shell = FALSE;
#endif
  xp->xp_numfiles = -1;
  xp->xp_files = NULL;
  xp->xp_arg = NULL;
  xp->xp_line = NULL;
}

/*
 * Cleanup an expand structure after use.
 */
void ExpandCleanup(expand_T *xp)
{
  if (xp->xp_numfiles >= 0) {
    FreeWild(xp->xp_numfiles, xp->xp_files);
    xp->xp_numfiles = -1;
  }
}

void ExpandEscape(expand_T *xp, char_u *str, int numfiles, char_u **files, int options)
{
  int i;
  char_u      *p;

  /*
   * May change home directory back to "~"
   */
  if (options & WILD_HOME_REPLACE)
    tilde_replace(str, numfiles, files);

  if (options & WILD_ESCAPE) {
    if (xp->xp_context == EXPAND_FILES
        || xp->xp_context == EXPAND_FILES_IN_PATH
        || xp->xp_context == EXPAND_SHELLCMD
        || xp->xp_context == EXPAND_BUFFERS
        || xp->xp_context == EXPAND_DIRECTORIES) {
      /*
       * Insert a backslash into a file name before a space, \, %, #
       * and wildmatch characters, except '~'.
       */
      for (i = 0; i < numfiles; ++i) {
        /* for ":set path=" we need to escape spaces twice */
        if (xp->xp_backslash == XP_BS_THREE) {
          p = vim_strsave_escaped(files[i], (char_u *)" ");
          xfree(files[i]);
          files[i] = p;
#if defined(BACKSLASH_IN_FILENAME)
          p = vim_strsave_escaped(files[i], (char_u *)" ");
          xfree(files[i]);
          files[i] = p;
#endif
        }
#ifdef BACKSLASH_IN_FILENAME
        p = (char_u *)vim_strsave_fnameescape((const char *)files[i], false);
#else
        p = (char_u *)vim_strsave_fnameescape((const char *)files[i],
                                              xp->xp_shell);
#endif
        xfree(files[i]);
        files[i] = p;

        /* If 'str' starts with "\~", replace "~" at start of
         * files[i] with "\~". */
        if (str[0] == '\\' && str[1] == '~' && files[i][0] == '~')
          escape_fname(&files[i]);
      }
      xp->xp_backslash = XP_BS_NONE;

      /* If the first file starts with a '+' escape it.  Otherwise it
       * could be seen as "+cmd". */
      if (*files[0] == '+')
        escape_fname(&files[0]);
    } else if (xp->xp_context == EXPAND_TAGS) {
      /*
       * Insert a backslash before characters in a tag name that
       * would terminate the ":tag" command.
       */
      for (i = 0; i < numfiles; ++i) {
        p = vim_strsave_escaped(files[i], (char_u *)"\\|\"");
        xfree(files[i]);
        files[i] = p;
      }
    }
  }
}

/// Escape special characters in a file name for use as a command argument
///
/// @param[in]  fname  File name to escape.
/// @param[in]  shell  What to escape for: if false, escapes for VimL command,
///                    if true then it escapes for a shell command.
///
/// @return [allocated] escaped file name.
char *vim_strsave_fnameescape(const char *const fname, const bool shell)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
#ifdef BACKSLASH_IN_FILENAME
#define PATH_ESC_CHARS " \t\n*?[{`%#'\"|!<"
  char_u buf[sizeof(PATH_ESC_CHARS)];
  int j = 0;

  // Don't escape '[', '{' and '!' if they are in 'isfname'.
  for (const char *s = PATH_ESC_CHARS; *s != NUL; s++) {
    if ((*s != '[' && *s != '{' && *s != '!') || !vim_isfilec(*s)) {
      buf[j++] = *s;
    }
  }
  buf[j] = NUL;
  char *p = (char *)vim_strsave_escaped((const char_u *)fname,
                                        (const char_u *)buf);
#else
#define PATH_ESC_CHARS ((char_u *)" \t\n*?[{`$\\%#'\"|!<")
#define SHELL_ESC_CHARS ((char_u *)" \t\n*?[{`$\\%#'\"|!<>();&")
  char *p = (char *)vim_strsave_escaped(
      (const char_u *)fname, (shell ? SHELL_ESC_CHARS : PATH_ESC_CHARS));
  if (shell && csh_like_shell()) {
    // For csh and similar shells need to put two backslashes before '!'.
    // One is taken by Vim, one by the shell.
    char *s = (char *)vim_strsave_escaped((const char_u *)p,
                                          (const char_u *)"!");
    xfree(p);
    p = s;
  }
#endif

  // '>' and '+' are special at the start of some commands, e.g. ":edit" and
  // ":write".  "cd -" has a special meaning.
  if (*p == '>' || *p == '+' || (*p == '-' && p[1] == NUL)) {
    escape_fname((char_u **)&p);
  }

  return p;
}

/*
 * Put a backslash before the file name in "pp", which is in allocated memory.
 */
static void escape_fname(char_u **pp)
{
  char_u *p = xmalloc(STRLEN(*pp) + 2);
  p[0] = '\\';
  STRCPY(p + 1, *pp);
  xfree(*pp);
  *pp = p;
}

/*
 * For each file name in files[num_files]:
 * If 'orig_pat' starts with "~/", replace the home directory with "~".
 */
void tilde_replace(char_u *orig_pat, int num_files, char_u **files)
{
  int i;
  char_u  *p;

  if (orig_pat[0] == '~' && vim_ispathsep(orig_pat[1])) {
    for (i = 0; i < num_files; ++i) {
      p = home_replace_save(NULL, files[i]);
      xfree(files[i]);
      files[i] = p;
    }
  }
}

/*
 * Show all matches for completion on the command line.
 * Returns EXPAND_NOTHING when the character that triggered expansion should
 * be inserted like a normal character.
 */
static int showmatches(expand_T *xp, int wildmenu)
{
#define L_SHOWFILE(m) (showtail ? sm_gettail(files_found[m]) : files_found[m])
  int num_files;
  char_u      **files_found;
  int i, j, k;
  int maxlen;
  int lines;
  int columns;
  char_u      *p;
  int lastlen;
  int attr;
  int showtail;

  if (xp->xp_numfiles == -1) {
    set_expand_context(xp);
    i = expand_cmdline(xp, ccline.cmdbuff, ccline.cmdpos,
        &num_files, &files_found);
    showtail = expand_showtail(xp);
    if (i != EXPAND_OK)
      return i;

  } else {
    num_files = xp->xp_numfiles;
    files_found = xp->xp_files;
    showtail = cmd_showtail;
  }

  if (ui_is_external(kUIWildmenu)) {
    Array args = ARRAY_DICT_INIT;
    for (i = 0; i < num_files; i++) {
      ADD(args, STRING_OBJ(cstr_to_string((char *)files_found[i])));
    }
    ui_call_wildmenu_show(args);
    return EXPAND_OK;
  }

  if (!wildmenu) {
    msg_didany = FALSE;                 /* lines_left will be set */
    msg_start();                        /* prepare for paging */
    msg_putchar('\n');
    ui_flush();
    cmdline_row = msg_row;
    msg_didany = FALSE;                 /* lines_left will be set again */
    msg_start();                        /* prepare for paging */
  }

  if (got_int) {
    got_int = false;            // only int. the completion, not the cmd line
  } else if (wildmenu) {
    win_redr_status_matches(xp, num_files, files_found, -1, showtail);
  } else {
    // find the length of the longest file name
    maxlen = 0;
    for (i = 0; i < num_files; ++i) {
      if (!showtail && (xp->xp_context == EXPAND_FILES
                        || xp->xp_context == EXPAND_SHELLCMD
                        || xp->xp_context == EXPAND_BUFFERS)) {
        home_replace(NULL, files_found[i], NameBuff, MAXPATHL, TRUE);
        j = vim_strsize(NameBuff);
      } else
        j = vim_strsize(L_SHOWFILE(i));
      if (j > maxlen)
        maxlen = j;
    }

    if (xp->xp_context == EXPAND_TAGS_LISTFILES)
      lines = num_files;
    else {
      /* compute the number of columns and lines for the listing */
      maxlen += 2;          /* two spaces between file names */
      columns = ((int)Columns + 2) / maxlen;
      if (columns < 1)
        columns = 1;
      lines = (num_files + columns - 1) / columns;
    }

    attr = HL_ATTR(HLF_D);      // find out highlighting for directories

    if (xp->xp_context == EXPAND_TAGS_LISTFILES) {
      MSG_PUTS_ATTR(_("tagname"), HL_ATTR(HLF_T));
      msg_clr_eos();
      msg_advance(maxlen - 3);
      MSG_PUTS_ATTR(_(" kind file\n"), HL_ATTR(HLF_T));
    }

    /* list the files line by line */
    for (i = 0; i < lines; ++i) {
      lastlen = 999;
      for (k = i; k < num_files; k += lines) {
        if (xp->xp_context == EXPAND_TAGS_LISTFILES) {
          msg_outtrans_attr(files_found[k], HL_ATTR(HLF_D));
          p = files_found[k] + STRLEN(files_found[k]) + 1;
          msg_advance(maxlen + 1);
          msg_puts((const char *)p);
          msg_advance(maxlen + 3);
          msg_puts_long_attr(p + 2, HL_ATTR(HLF_D));
          break;
        }
        for (j = maxlen - lastlen; --j >= 0; )
          msg_putchar(' ');
        if (xp->xp_context == EXPAND_FILES
            || xp->xp_context == EXPAND_SHELLCMD
            || xp->xp_context == EXPAND_BUFFERS) {
          /* highlight directories */
          if (xp->xp_numfiles != -1) {
            char_u  *halved_slash;
            char_u  *exp_path;

            /* Expansion was done before and special characters
             * were escaped, need to halve backslashes.  Also
             * $HOME has been replaced with ~/. */
            exp_path = expand_env_save_opt(files_found[k], TRUE);
            halved_slash = backslash_halve_save(
                exp_path != NULL ? exp_path : files_found[k]);
            j = os_isdir(halved_slash);
            xfree(exp_path);
            xfree(halved_slash);
          } else
            /* Expansion was done here, file names are literal. */
            j = os_isdir(files_found[k]);
          if (showtail)
            p = L_SHOWFILE(k);
          else {
            home_replace(NULL, files_found[k], NameBuff, MAXPATHL,
                TRUE);
            p = NameBuff;
          }
        } else {
          j = FALSE;
          p = L_SHOWFILE(k);
        }
        lastlen = msg_outtrans_attr(p, j ? attr : 0);
      }
      if (msg_col > 0) {        /* when not wrapped around */
        msg_clr_eos();
        msg_putchar('\n');
      }
      ui_flush();                          /* show one line at a time */
      if (got_int) {
        got_int = FALSE;
        break;
      }
    }

    /*
     * we redraw the command below the lines that we have just listed
     * This is a bit tricky, but it saves a lot of screen updating.
     */
    cmdline_row = msg_row;      /* will put it back later */
  }

  if (xp->xp_numfiles == -1)
    FreeWild(num_files, files_found);

  return EXPAND_OK;
}

/*
 * Private path_tail for showmatches() (and win_redr_status_matches()):
 * Find tail of file name path, but ignore trailing "/".
 */
char_u *sm_gettail(char_u *s)
{
  char_u      *p;
  char_u      *t = s;
  int had_sep = FALSE;

  for (p = s; *p != NUL; ) {
    if (vim_ispathsep(*p)
#ifdef BACKSLASH_IN_FILENAME
        && !rem_backslash(p)
#endif
        )
      had_sep = TRUE;
    else if (had_sep) {
      t = p;
      had_sep = FALSE;
    }
    MB_PTR_ADV(p);
  }
  return t;
}

/*
 * Return TRUE if we only need to show the tail of completion matches.
 * When not completing file names or there is a wildcard in the path FALSE is
 * returned.
 */
static int expand_showtail(expand_T *xp)
{
  char_u      *s;
  char_u      *end;

  /* When not completing file names a "/" may mean something different. */
  if (xp->xp_context != EXPAND_FILES
      && xp->xp_context != EXPAND_SHELLCMD
      && xp->xp_context != EXPAND_DIRECTORIES)
    return FALSE;

  end = path_tail(xp->xp_pattern);
  if (end == xp->xp_pattern)            /* there is no path separator */
    return FALSE;

  for (s = xp->xp_pattern; s < end; s++) {
    /* Skip escaped wildcards.  Only when the backslash is not a path
    * separator, on DOS the '*' "path\*\file" must not be skipped. */
    if (rem_backslash(s))
      ++s;
    else if (vim_strchr((char_u *)"*?[", *s) != NULL)
      return FALSE;
  }
  return TRUE;
}

/*
 * Prepare a string for expansion.
 * When expanding file names: The string will be used with expand_wildcards().
 * Copy "fname[len]" into allocated memory and add a '*' at the end.
 * When expanding other names: The string will be used with regcomp().  Copy
 * the name into allocated memory and prepend "^".
 */
char_u *
addstar (
    char_u *fname,
    int len,
    int context                    /* EXPAND_FILES etc. */
)
  FUNC_ATTR_NONNULL_RET
{
  char_u      *retval;
  int i, j;
  int new_len;
  char_u      *tail;
  int ends_in_star;

  if (context != EXPAND_FILES
      && context != EXPAND_FILES_IN_PATH
      && context != EXPAND_SHELLCMD
      && context != EXPAND_DIRECTORIES) {
    /*
     * Matching will be done internally (on something other than files).
     * So we convert the file-matching-type wildcards into our kind for
     * use with vim_regcomp().  First work out how long it will be:
     */

    // For help tags the translation is done in find_help_tags().
    // For a tag pattern starting with "/" no translation is needed.
    if (context == EXPAND_HELP
        || context == EXPAND_CHECKHEALTH
        || context == EXPAND_COLORS
        || context == EXPAND_COMPILER
        || context == EXPAND_OWNSYNTAX
        || context == EXPAND_FILETYPE
        || context == EXPAND_PACKADD
        || ((context == EXPAND_TAGS_LISTFILES || context == EXPAND_TAGS)
            && fname[0] == '/')) {
      retval = vim_strnsave(fname, len);
    } else {
      new_len = len + 2;                // +2 for '^' at start, NUL at end
      for (i = 0; i < len; i++) {
        if (fname[i] == '*' || fname[i] == '~')
          new_len++;                    /* '*' needs to be replaced by ".*"
                                           '~' needs to be replaced by "\~" */

        /* Buffer names are like file names.  "." should be literal */
        if (context == EXPAND_BUFFERS && fname[i] == '.')
          new_len++;                    /* "." becomes "\." */

        /* Custom expansion takes care of special things, match
         * backslashes literally (perhaps also for other types?) */
        if ((context == EXPAND_USER_DEFINED
             || context == EXPAND_USER_LIST) && fname[i] == '\\')
          new_len++;                    /* '\' becomes "\\" */
      }
      retval = xmalloc(new_len);
      {
        retval[0] = '^';
        j = 1;
        for (i = 0; i < len; i++, j++) {
          /* Skip backslash.  But why?  At least keep it for custom
           * expansion. */
          if (context != EXPAND_USER_DEFINED
              && context != EXPAND_USER_LIST
              && fname[i] == '\\'
              && ++i == len)
            break;

          switch (fname[i]) {
          case '*':   retval[j++] = '.';
            break;
          case '~':   retval[j++] = '\\';
            break;
          case '?':   retval[j] = '.';
            continue;
          case '.':   if (context == EXPAND_BUFFERS)
              retval[j++] = '\\';
            break;
          case '\\':  if (context == EXPAND_USER_DEFINED
                          || context == EXPAND_USER_LIST)
              retval[j++] = '\\';
            break;
          }
          retval[j] = fname[i];
        }
        retval[j] = NUL;
      }
    }
  } else {
    retval = xmalloc(len + 4);
    STRLCPY(retval, fname, len + 1);

    /*
     * Don't add a star to *, ~, ~user, $var or `cmd`.
     * * would become **, which walks the whole tree.
     * ~ would be at the start of the file name, but not the tail.
     * $ could be anywhere in the tail.
     * ` could be anywhere in the file name.
     * When the name ends in '$' don't add a star, remove the '$'.
     */
    tail = path_tail(retval);
    ends_in_star = (len > 0 && retval[len - 1] == '*');
#ifndef BACKSLASH_IN_FILENAME
    for (i = len - 2; i >= 0; --i) {
      if (retval[i] != '\\')
        break;
      ends_in_star = !ends_in_star;
    }
#endif
    if ((*retval != '~' || tail != retval)
        && !ends_in_star
        && vim_strchr(tail, '$') == NULL
        && vim_strchr(retval, '`') == NULL)
      retval[len++] = '*';
    else if (len > 0 && retval[len - 1] == '$')
      --len;
    retval[len] = NUL;
  }
  return retval;
}

/*
 * Must parse the command line so far to work out what context we are in.
 * Completion can then be done based on that context.
 * This routine sets the variables:
 *  xp->xp_pattern	    The start of the pattern to be expanded within
 *				the command line (ends at the cursor).
 *  xp->xp_context	    The type of thing to expand.  Will be one of:
 *
 *  EXPAND_UNSUCCESSFUL	    Used sometimes when there is something illegal on
 *			    the command line, like an unknown command.	Caller
 *			    should beep.
 *  EXPAND_NOTHING	    Unrecognised context for completion, use char like
 *			    a normal char, rather than for completion.	eg
 *			    :s/^I/
 *  EXPAND_COMMANDS	    Cursor is still touching the command, so complete
 *			    it.
 *  EXPAND_BUFFERS	    Complete file names for :buf and :sbuf commands.
 *  EXPAND_FILES	    After command with XFILE set, or after setting
 *			    with P_EXPAND set.	eg :e ^I, :w>>^I
 *  EXPAND_DIRECTORIES	    In some cases this is used instead of the latter
 *			    when we know only directories are of interest.  eg
 *			    :set dir=^I
 *  EXPAND_SHELLCMD	    After ":!cmd", ":r !cmd"  or ":w !cmd".
 *  EXPAND_SETTINGS	    Complete variable names.  eg :set d^I
 *  EXPAND_BOOL_SETTINGS    Complete boolean variables only,  eg :set no^I
 *  EXPAND_TAGS		    Complete tags from the files in p_tags.  eg :ta a^I
 *  EXPAND_TAGS_LISTFILES   As above, but list filenames on ^D, after :tselect
 *  EXPAND_HELP		    Complete tags from the file 'helpfile'/tags
 *  EXPAND_EVENTS	    Complete event names
 *  EXPAND_SYNTAX	    Complete :syntax command arguments
 *  EXPAND_HIGHLIGHT	    Complete highlight (syntax) group names
 *  EXPAND_AUGROUP	    Complete autocommand group names
 *  EXPAND_USER_VARS	    Complete user defined variable names, eg :unlet a^I
 *  EXPAND_MAPPINGS	    Complete mapping and abbreviation names,
 *			      eg :unmap a^I , :cunab x^I
 *  EXPAND_FUNCTIONS	    Complete internal or user defined function names,
 *			      eg :call sub^I
 *  EXPAND_USER_FUNC	    Complete user defined function names, eg :delf F^I
 *  EXPAND_EXPRESSION	    Complete internal or user defined function/variable
 *			    names in expressions, eg :while s^I
 *  EXPAND_ENV_VARS	    Complete environment variable names
 *  EXPAND_USER		    Complete user names
 */
static void set_expand_context(expand_T *xp)
{
  /* only expansion for ':', '>' and '=' command-lines */
  if (ccline.cmdfirstc != ':'
      && ccline.cmdfirstc != '>' && ccline.cmdfirstc != '='
      && !ccline.input_fn
      ) {
    xp->xp_context = EXPAND_NOTHING;
    return;
  }
  set_cmd_context(xp, ccline.cmdbuff, ccline.cmdlen, ccline.cmdpos, true);
}

void 
set_cmd_context (
    expand_T *xp,
    char_u *str,           // start of command line
    int len,               // length of command line (excl. NUL)
    int col,               // position of cursor
    int use_ccline         // use ccline for info
)
{
  int old_char = NUL;

  /*
   * Avoid a UMR warning from Purify, only save the character if it has been
   * written before.
   */
  if (col < len)
    old_char = str[col];
  str[col] = NUL;
  const char *nextcomm = (const char *)str;

  if (use_ccline && ccline.cmdfirstc == '=') {
    // pass CMD_SIZE because there is no real command
    set_context_for_expression(xp, str, CMD_SIZE);
  } else if (use_ccline && ccline.input_fn) {
    xp->xp_context = ccline.xp_context;
    xp->xp_pattern = ccline.cmdbuff;
    xp->xp_arg = ccline.xp_arg;
  } else {
    while (nextcomm != NULL) {
      nextcomm = set_one_cmd_context(xp, nextcomm);
    }
  }

  /* Store the string here so that call_user_expand_func() can get to them
   * easily. */
  xp->xp_line = str;
  xp->xp_col = col;

  str[col] = old_char;
}

/*
 * Expand the command line "str" from context "xp".
 * "xp" must have been set by set_cmd_context().
 * xp->xp_pattern points into "str", to where the text that is to be expanded
 * starts.
 * Returns EXPAND_UNSUCCESSFUL when there is something illegal before the
 * cursor.
 * Returns EXPAND_NOTHING when there is nothing to expand, might insert the
 * key that triggered expansion literally.
 * Returns EXPAND_OK otherwise.
 */
int 
expand_cmdline (
    expand_T *xp,
    char_u *str,               /* start of command line */
    int col,                        /* position of cursor */
    int *matchcount,        /* return: nr of matches */
    char_u ***matches         /* return: array of pointers to matches */
)
{
  char_u      *file_str = NULL;
  int options = WILD_ADD_SLASH|WILD_SILENT;

  if (xp->xp_context == EXPAND_UNSUCCESSFUL) {
    beep_flush();
    return EXPAND_UNSUCCESSFUL;      /* Something illegal on command line */
  }
  if (xp->xp_context == EXPAND_NOTHING) {
    /* Caller can use the character as a normal char instead */
    return EXPAND_NOTHING;
  }

  /* add star to file name, or convert to regexp if not exp. files. */
  xp->xp_pattern_len = (int)(str + col - xp->xp_pattern);
  file_str = addstar(xp->xp_pattern, xp->xp_pattern_len, xp->xp_context);

  if (p_wic)
    options += WILD_ICASE;

  /* find all files that match the description */
  if (ExpandFromContext(xp, file_str, matchcount, matches, options) == FAIL) {
    *matchcount = 0;
    *matches = NULL;
  }
  xfree(file_str);

  return EXPAND_OK;
}

// Cleanup matches for help tags:
// Remove "@ab" if the top of 'helplang' is "ab" and the language of the first
// tag matches it.  Otherwise remove "@en" if "en" is the only language.
static void cleanup_help_tags(int num_file, char_u **file)
{
  char_u buf[4];
  char_u *p = buf;

  if (p_hlg[0] != NUL && (p_hlg[0] != 'e' || p_hlg[1] != 'n')) {
    *p++ = '@';
    *p++ = p_hlg[0];
    *p++ = p_hlg[1];
  }
  *p = NUL;

  for (int i = 0; i < num_file; i++) {
    int len = (int)STRLEN(file[i]) - 3;
    if (len <= 0) {
      continue;
    }
    if (STRCMP(file[i] + len, "@en") == 0) {
      // Sorting on priority means the same item in another language may
      // be anywhere.  Search all items for a match up to the "@en".
      int j;
      for (j = 0; j < num_file; j++) {
        if (j != i
            && (int)STRLEN(file[j]) == len + 3
            && STRNCMP(file[i], file[j], len + 1) == 0) {
          break;
        }
      }
      if (j == num_file) {
        // item only exists with @en, remove it
        file[i][len] = NUL;
      }
    }
  }

  if (*buf != NUL) {
    for (int i = 0; i < num_file; i++) {
      int len = (int)STRLEN(file[i]) - 3;
      if (len <= 0) {
        continue;
      }
      if (STRCMP(file[i] + len, buf) == 0) {
        // remove the default language
        file[i][len] = NUL;
      }
    }
  }
}

typedef char_u *(*ExpandFunc)(expand_T *, int);

/*
 * Do the expansion based on xp->xp_context and "pat".
 */
static int 
ExpandFromContext (
    expand_T *xp,
    char_u *pat,
    int *num_file,
    char_u ***file,
    int options              /* EW_ flags */
)
{
  regmatch_T regmatch;
  int ret;
  int flags;

  flags = EW_DIR;       /* include directories */
  if (options & WILD_LIST_NOTFOUND)
    flags |= EW_NOTFOUND;
  if (options & WILD_ADD_SLASH)
    flags |= EW_ADDSLASH;
  if (options & WILD_KEEP_ALL)
    flags |= EW_KEEPALL;
  if (options & WILD_SILENT)
    flags |= EW_SILENT;
  if (options & WILD_ALLLINKS) {
    flags |= EW_ALLLINKS;
  }

  if (xp->xp_context == EXPAND_FILES
      || xp->xp_context == EXPAND_DIRECTORIES
      || xp->xp_context == EXPAND_FILES_IN_PATH) {
    /*
     * Expand file or directory names.
     */
    int free_pat = FALSE;
    int i;

    /* for ":set path=" and ":set tags=" halve backslashes for escaped
     * space */
    if (xp->xp_backslash != XP_BS_NONE) {
      free_pat = TRUE;
      pat = vim_strsave(pat);
      for (i = 0; pat[i]; ++i)
        if (pat[i] == '\\') {
          if (xp->xp_backslash == XP_BS_THREE
              && pat[i + 1] == '\\'
              && pat[i + 2] == '\\'
              && pat[i + 3] == ' ')
            STRMOVE(pat + i, pat + i + 3);
          if (xp->xp_backslash == XP_BS_ONE
              && pat[i + 1] == ' ')
            STRMOVE(pat + i, pat + i + 1);
        }
    }

    if (xp->xp_context == EXPAND_FILES)
      flags |= EW_FILE;
    else if (xp->xp_context == EXPAND_FILES_IN_PATH)
      flags |= (EW_FILE | EW_PATH);
    else
      flags = (flags | EW_DIR) & ~EW_FILE;
    if (options & WILD_ICASE)
      flags |= EW_ICASE;

    /* Expand wildcards, supporting %:h and the like. */
    ret = expand_wildcards_eval(&pat, num_file, file, flags);
    if (free_pat)
      xfree(pat);
    return ret;
  }

  *file = (char_u **)"";
  *num_file = 0;
  if (xp->xp_context == EXPAND_HELP) {
    /* With an empty argument we would get all the help tags, which is
     * very slow.  Get matches for "help" instead. */
    if (find_help_tags(*pat == NUL ? (char_u *)"help" : pat,
                       num_file, file, false) == OK) {
      cleanup_help_tags(*num_file, *file);
      return OK;
    }
    return FAIL;
  }

  if (xp->xp_context == EXPAND_SHELLCMD) {
    *file = NULL;
    expand_shellcmd(pat, num_file, file, flags);
    return OK;
  }
  if (xp->xp_context == EXPAND_OLD_SETTING) {
    ExpandOldSetting(num_file, file);
    return OK;
  }
  if (xp->xp_context == EXPAND_BUFFERS)
    return ExpandBufnames(pat, num_file, file, options);
  if (xp->xp_context == EXPAND_TAGS
      || xp->xp_context == EXPAND_TAGS_LISTFILES)
    return expand_tags(xp->xp_context == EXPAND_TAGS, pat, num_file, file);
  if (xp->xp_context == EXPAND_COLORS) {
    char *directories[] = { "colors", NULL };
    return ExpandRTDir(pat, DIP_START + DIP_OPT, num_file, file, directories);
  }
  if (xp->xp_context == EXPAND_COMPILER) {
    char *directories[] = { "compiler", NULL };
    return ExpandRTDir(pat, 0, num_file, file, directories);
  }
  if (xp->xp_context == EXPAND_OWNSYNTAX) {
    char *directories[] = { "syntax", NULL };
    return ExpandRTDir(pat, 0, num_file, file, directories);
  }
  if (xp->xp_context == EXPAND_FILETYPE) {
    char *directories[] = { "syntax", "indent", "ftplugin", NULL };
    return ExpandRTDir(pat, 0, num_file, file, directories);
  }
  if (xp->xp_context == EXPAND_CHECKHEALTH) {
    char *directories[] = { "autoload/health", NULL };
    return ExpandRTDir(pat, 0, num_file, file, directories);
  }
  if (xp->xp_context == EXPAND_USER_LIST) {
    return ExpandUserList(xp, num_file, file);
  }
  if (xp->xp_context == EXPAND_PACKADD) {
    return ExpandPackAddDir(pat, num_file, file);
  }

  regmatch.regprog = vim_regcomp(pat, p_magic ? RE_MAGIC : 0);
  if (regmatch.regprog == NULL)
    return FAIL;

  /* set ignore-case according to p_ic, p_scs and pat */
  regmatch.rm_ic = ignorecase(pat);

  if (xp->xp_context == EXPAND_SETTINGS
      || xp->xp_context == EXPAND_BOOL_SETTINGS)
    ret = ExpandSettings(xp, &regmatch, num_file, file);
  else if (xp->xp_context == EXPAND_MAPPINGS)
    ret = ExpandMappings(&regmatch, num_file, file);
  else if (xp->xp_context == EXPAND_USER_DEFINED)
    ret = ExpandUserDefined(xp, &regmatch, num_file, file);
  else {
    static struct expgen {
      int context;
      ExpandFunc func;
      int ic;
      int escaped;
    } tab[] = {
      { EXPAND_COMMANDS, get_command_name, false, true },
      { EXPAND_BEHAVE, get_behave_arg, true, true },
      { EXPAND_MAPCLEAR, get_mapclear_arg, true, true },
      { EXPAND_MESSAGES, get_messages_arg, true, true },
      { EXPAND_HISTORY, get_history_arg, true, true },
      { EXPAND_USER_COMMANDS, get_user_commands, false, true },
      { EXPAND_USER_ADDR_TYPE, get_user_cmd_addr_type, false, true },
      { EXPAND_USER_CMD_FLAGS, get_user_cmd_flags, false, true },
      { EXPAND_USER_NARGS, get_user_cmd_nargs, false, true },
      { EXPAND_USER_COMPLETE, get_user_cmd_complete, false, true },
      { EXPAND_USER_VARS, get_user_var_name, false, true },
      { EXPAND_FUNCTIONS, get_function_name, false, true },
      { EXPAND_USER_FUNC, get_user_func_name, false, true },
      { EXPAND_EXPRESSION, get_expr_name, false, true },
      { EXPAND_MENUS, get_menu_name, false, true },
      { EXPAND_MENUNAMES, get_menu_names, false, true },
      { EXPAND_SYNTAX, get_syntax_name, true, true },
      { EXPAND_SYNTIME, get_syntime_arg, true, true },
      { EXPAND_HIGHLIGHT, (ExpandFunc)get_highlight_name, true, true },
      { EXPAND_EVENTS, get_event_name, true, true },
      { EXPAND_AUGROUP, get_augroup_name, true, true },
      { EXPAND_CSCOPE, get_cscope_name, true, true },
      { EXPAND_SIGN, get_sign_name, true, true },
      { EXPAND_PROFILE, get_profile_name, true, true },
#ifdef HAVE_WORKING_LIBINTL
      { EXPAND_LANGUAGE, get_lang_arg, true, false },
      { EXPAND_LOCALES, get_locales, true, false },
#endif
      { EXPAND_ENV_VARS, get_env_name, true, true },
      { EXPAND_USER, get_users, true, false },
      { EXPAND_ARGLIST, get_arglist_name, true, false },
    };
    int i;

    /*
     * Find a context in the table and call the ExpandGeneric() with the
     * right function to do the expansion.
     */
    ret = FAIL;
    for (i = 0; i < (int)ARRAY_SIZE(tab); ++i)
      if (xp->xp_context == tab[i].context) {
        if (tab[i].ic) {
          regmatch.rm_ic = TRUE;
        }
        ExpandGeneric(xp, &regmatch, num_file, file, tab[i].func,
                      tab[i].escaped);
        ret = OK;
        break;
      }
  }

  vim_regfree(regmatch.regprog);

  return ret;
}

/*
 * Expand a list of names.
 *
 * Generic function for command line completion.  It calls a function to
 * obtain strings, one by one.	The strings are matched against a regexp
 * program.  Matching strings are copied into an array, which is returned.
 */
void ExpandGeneric(
    expand_T    *xp,
    regmatch_T  *regmatch,
    int         *num_file,
    char_u      ***file,
    CompleteListItemGetter func, /* returns a string from the list */
    int escaped
    )
{
  int i;
  int count = 0;
  char_u      *str;

  // count the number of matching names
  for (i = 0;; ++i) {
    str = (*func)(xp, i);
    if (str == NULL) // end of list
      break;
    if (*str == NUL) // skip empty strings
      continue;
    if (vim_regexec(regmatch, str, (colnr_T)0)) {
      ++count;
    }
  }
  if (count == 0)
    return;
  *num_file = count;
  *file = (char_u **)xmalloc(count * sizeof(char_u *));

  // copy the matching names into allocated memory
  count = 0;
  for (i = 0;; i++) {
    str = (*func)(xp, i);
    if (str == NULL) {  // End of list.
      break;
    }
    if (*str == NUL) {  // Skip empty strings.
      continue;
    }
    if (vim_regexec(regmatch, str, (colnr_T)0)) {
      if (escaped) {
        str = vim_strsave_escaped(str, (char_u *)" \t\\.");
      } else {
        str = vim_strsave(str);
      }
      (*file)[count++] = str;
      if (func == get_menu_names) {
        // Test for separator added by get_menu_names().
        str += STRLEN(str) - 1;
        if (*str == '\001') {
          *str = '.';
        }
      }
    }
  }

  /* Sort the results.  Keep menu's in the specified order. */
  if (xp->xp_context != EXPAND_MENUNAMES && xp->xp_context != EXPAND_MENUS) {
    if (xp->xp_context == EXPAND_EXPRESSION
        || xp->xp_context == EXPAND_FUNCTIONS
        || xp->xp_context == EXPAND_USER_FUNC)
      /* <SNR> functions should be sorted to the end. */
      qsort((void *)*file, (size_t)*num_file, sizeof(char_u *),
          sort_func_compare);
    else
      sort_strings(*file, *num_file);
  }

  /* Reset the variables used for special highlight names expansion, so that
   * they don't show up when getting normal highlight names by ID. */
  reset_expand_highlight();
}

/// Complete a shell command.
///
/// @param      filepat  is a pattern to match with command names.
/// @param[out] num_file is pointer to number of matches.
/// @param[out] file     is pointer to array of pointers to matches.
///                      *file will either be set to NULL or point to
///                      allocated memory.
/// @param      flagsarg is a combination of EW_* flags.
static void expand_shellcmd(char_u *filepat, int *num_file, char_u ***file,
                            int flagsarg)
  FUNC_ATTR_NONNULL_ALL
{
  char_u      *pat;
  int i;
  char_u      *path;
  garray_T ga;
  char_u *buf = xmalloc(MAXPATHL);
  size_t l;
  char_u      *s, *e;
  int flags = flagsarg;
  int ret;
  bool did_curdir = false;

  /* for ":set path=" and ":set tags=" halve backslashes for escaped
   * space */
  pat = vim_strsave(filepat);
  for (i = 0; pat[i]; ++i)
    if (pat[i] == '\\' && pat[i + 1] == ' ')
      STRMOVE(pat + i, pat + i + 1);

  flags |= EW_FILE | EW_EXEC | EW_SHELLCMD;

  bool mustfree = false;  // Track memory allocation for *path.
  // For an absolute name we don't use $PATH.
  if (path_is_absolute(pat)) {
    path = (char_u *)" ";
  } else if (pat[0] == '.' && (vim_ispathsep(pat[1])
                               || (pat[1] == '.'
                                   && vim_ispathsep(pat[2])))) {
    path = (char_u *)".";
  } else {
    path = (char_u *)vim_getenv("PATH");
    if (path == NULL) {
      path = (char_u *)"";
    } else {
      mustfree = true;
    }
  }

  /*
   * Go over all directories in $PATH.  Expand matches in that directory and
   * collect them in "ga". When "." is not in $PATH also expaned for the
   * current directory, to find "subdir/cmd".
   */
  ga_init(&ga, (int)sizeof(char *), 10);
  for (s = path; ; s = e) {
    if (*s == NUL) {
      if (did_curdir) {
        break;
      }
      // Find directories in the current directory, path is empty.
      did_curdir = true;
    } else if (*s == '.') {
      did_curdir = true;
    }

    if (*s == ' ') {
      s++;              // Skip space used for absolute path name.
    }

    e = vim_strchr(s, ':');
    if (e == NULL)
      e = s + STRLEN(s);

    l = e - s;
    if (l > MAXPATHL - 5)
      break;
    STRLCPY(buf, s, l + 1);
    add_pathsep((char *)buf);
    l = STRLEN(buf);
    STRLCPY(buf + l, pat, MAXPATHL - l);

    /* Expand matches in one directory of $PATH. */
    ret = expand_wildcards(1, &buf, num_file, file, flags);
    if (ret == OK) {
      ga_grow(&ga, *num_file);
      {
        for (i = 0; i < *num_file; ++i) {
          s = (*file)[i];
          if (STRLEN(s) > l) {
            /* Remove the path again. */
            STRMOVE(s, s + l);
            ((char_u **)ga.ga_data)[ga.ga_len++] = s;
          } else
            xfree(s);
        }
        xfree(*file);
      }
    }
    if (*e != NUL)
      ++e;
  }
  *file = ga.ga_data;
  *num_file = ga.ga_len;

  xfree(buf);
  xfree(pat);
  if (mustfree) {
    xfree(path);
  }
}

/// Call "user_expand_func()" to invoke a user defined Vim script function and
/// return the result (either a string or a List).
static void * call_user_expand_func(user_expand_func_T user_expand_func,
                                    expand_T *xp, int *num_file, char_u ***file)
{
  int keep = 0;
  char_u num[50];
  char_u      *args[3];
  int save_current_SID = current_SID;
  void        *ret;
  struct cmdline_info save_ccline;

  if (xp->xp_arg == NULL || xp->xp_arg[0] == '\0' || xp->xp_line == NULL)
    return NULL;
  *num_file = 0;
  *file = NULL;

  if (ccline.cmdbuff != NULL) {
    keep = ccline.cmdbuff[ccline.cmdlen];
    ccline.cmdbuff[ccline.cmdlen] = 0;
  }

  args[0] = vim_strnsave(xp->xp_pattern, xp->xp_pattern_len);
  args[1] = xp->xp_line;
  sprintf((char *)num, "%d", xp->xp_col);
  args[2] = num;

  /* Save the cmdline, we don't know what the function may do. */
  save_ccline = ccline;
  ccline.cmdbuff = NULL;
  ccline.cmdprompt = NULL;
  current_SID = xp->xp_scriptID;

  ret = user_expand_func(xp->xp_arg,
                         3,
                         (const char_u * const *)args,
                         false);

  ccline = save_ccline;
  current_SID = save_current_SID;
  if (ccline.cmdbuff != NULL)
    ccline.cmdbuff[ccline.cmdlen] = keep;

  xfree(args[0]);
  return ret;
}

/*
 * Expand names with a function defined by the user.
 */
static int ExpandUserDefined(expand_T *xp, regmatch_T *regmatch, int *num_file, char_u ***file)
{
  char_u   *e;
  garray_T  ga;

  char_u *const retstr = call_user_expand_func(
      (user_expand_func_T)call_func_retstr, xp, num_file, file);

  if (retstr == NULL) {
    return FAIL;
  }

  ga_init(&ga, (int)sizeof(char *), 3);
  for (char_u *s = retstr; *s != NUL; s = e) {
    e = vim_strchr(s, '\n');
    if (e == NULL)
      e = s + STRLEN(s);
    const int keep = *e;
    *e = NUL;

    const bool skip = xp->xp_pattern[0]
        && vim_regexec(regmatch, s, (colnr_T)0) == 0;
    *e = keep;
    if (!skip) {
      GA_APPEND(char_u *, &ga, vim_strnsave(s, (int)(e - s)));
    }

    if (*e != NUL) {
      e++;
    }
  }
  xfree(retstr);
  *file = ga.ga_data;
  *num_file = ga.ga_len;
  return OK;
}

/*
 * Expand names with a list returned by a function defined by the user.
 */
static int ExpandUserList(expand_T *xp, int *num_file, char_u ***file)
{
  list_T *const retlist = call_user_expand_func(
      (user_expand_func_T)call_func_retlist, xp, num_file, file);
  if (retlist == NULL) {
    return FAIL;
  }

  garray_T ga;
  ga_init(&ga, (int)sizeof(char *), 3);
  // Loop over the items in the list.
  TV_LIST_ITER_CONST(retlist, li, {
    if (TV_LIST_ITEM_TV(li)->v_type != VAR_STRING
        || TV_LIST_ITEM_TV(li)->vval.v_string == NULL) {
      continue;  // Skip non-string items and empty strings.
    }

    GA_APPEND(char *, &ga, xstrdup(
        (const char *)TV_LIST_ITEM_TV(li)->vval.v_string));
  });
  tv_list_unref(retlist);

  *file = ga.ga_data;
  *num_file = ga.ga_len;
  return OK;
}

/// Expand color scheme, compiler or filetype names.
/// Search from 'runtimepath':
///   'runtimepath'/{dirnames}/{pat}.vim
/// When "flags" has DIP_START: search also from 'start' of 'packpath':
///   'packpath'/pack/ * /start/ * /{dirnames}/{pat}.vim
/// When "flags" has DIP_OPT: search also from 'opt' of 'packpath':
///   'packpath'/pack/ * /opt/ * /{dirnames}/{pat}.vim
/// "dirnames" is an array with one or more directory names.
static int ExpandRTDir(char_u *pat, int flags, int *num_file, char_u ***file,
                       char *dirnames[])
{
  *num_file = 0;
  *file = NULL;
  size_t pat_len = STRLEN(pat);

  garray_T ga;
  ga_init(&ga, (int)sizeof(char *), 10);

  for (int i = 0; dirnames[i] != NULL; i++) {
    size_t size = STRLEN(dirnames[i]) + pat_len + 7;
    char_u *s = xmalloc(size);
    snprintf((char *)s, size, "%s/%s*.vim", dirnames[i], pat);
    globpath(p_rtp, s, &ga, 0);
    xfree(s);
  }

  if (flags & DIP_START) {
    for (int i = 0; dirnames[i] != NULL; i++) {
      size_t size = STRLEN(dirnames[i]) + pat_len + 22;
      char_u *s = xmalloc(size);
      snprintf((char *)s, size, "pack/*/start/*/%s/%s*.vim", dirnames[i], pat);  // NOLINT
      globpath(p_pp, s, &ga, 0);
      xfree(s);
    }
  }

  if (flags & DIP_OPT) {
    for (int i = 0; dirnames[i] != NULL; i++) {
      size_t size = STRLEN(dirnames[i]) + pat_len + 20;
      char_u *s = xmalloc(size);
      snprintf((char *)s, size, "pack/*/opt/*/%s/%s*.vim", dirnames[i], pat);  // NOLINT
      globpath(p_pp, s, &ga, 0);
      xfree(s);
    }
  }

  for (int i = 0; i < ga.ga_len; i++) {
    char_u *match = ((char_u **)ga.ga_data)[i];
    char_u *s = match;
    char_u *e = s + STRLEN(s);
    if (e - s > 4 && STRNICMP(e - 4, ".vim", 4) == 0) {
      e -= 4;
      for (s = e; s > match; MB_PTR_BACK(match, s)) {
        if (vim_ispathsep(*s)) {
          break;
        }
      }
      s++;
      *e = NUL;
      memmove(match, s, e - s + 1);
    }
  }

  if (GA_EMPTY(&ga))
    return FAIL;

  /* Sort and remove duplicates which can happen when specifying multiple
   * directories in dirnames. */
  ga_remove_duplicate_strings(&ga);

  *file = ga.ga_data;
  *num_file = ga.ga_len;
  return OK;
}

/// Expand loadplugin names:
/// 'packpath'/pack/ * /opt/{pat}
static int ExpandPackAddDir(char_u *pat, int *num_file, char_u ***file)
{
  garray_T ga;

  *num_file = 0;
  *file = NULL;
  size_t pat_len = STRLEN(pat);
  ga_init(&ga, (int)sizeof(char *), 10);

  size_t buflen = pat_len + 26;
  char_u *s = xmalloc(buflen);
  snprintf((char *)s, buflen, "pack/*/opt/%s*", pat);  // NOLINT
  globpath(p_pp, s, &ga, 0);
  xfree(s);

  for (int i = 0; i < ga.ga_len; i++) {
    char_u *match = ((char_u **)ga.ga_data)[i];
    s = path_tail(match);
    char_u *e = s + STRLEN(s);
    memmove(match, s, e - s + 1);
  }

  if (GA_EMPTY(&ga)) {
    return FAIL;
  }

  // Sort and remove duplicates which can happen when specifying multiple
  // directories in dirnames.
  ga_remove_duplicate_strings(&ga);

  *file = ga.ga_data;
  *num_file = ga.ga_len;
  return OK;
}


/// Expand `file` for all comma-separated directories in `path`.
/// Adds matches to `ga`.
void globpath(char_u *path, char_u *file, garray_T *ga, int expand_options)
{
  expand_T xpc;
  ExpandInit(&xpc);
  xpc.xp_context = EXPAND_FILES;

  char_u *buf = xmalloc(MAXPATHL);

  // Loop over all entries in {path}.
  while (*path != NUL) {
    // Copy one item of the path to buf[] and concatenate the file name.
    copy_option_part(&path, buf, MAXPATHL, ",");
    if (STRLEN(buf) + STRLEN(file) + 2 < MAXPATHL) {
      add_pathsep((char *)buf);
      STRCAT(buf, file);  // NOLINT

      char_u **p;
      int num_p = 0;
      (void)ExpandFromContext(&xpc, buf, &num_p, &p,
                              WILD_SILENT | expand_options);
      if (num_p > 0) {
        ExpandEscape(&xpc, buf, num_p, p, WILD_SILENT | expand_options);

        // Concatenate new results to previous ones.
        ga_grow(ga, num_p);
        for (int i = 0; i < num_p; i++) {
          ((char_u **)ga->ga_data)[ga->ga_len] = vim_strsave(p[i]);
          ga->ga_len++;
        }

        FreeWild(num_p, p);
      }
    }
  }

  xfree(buf);
}



/*********************************
*  Command line history stuff	 *
*********************************/

/// Translate a history character to the associated type number
static HistoryType hist_char2type(const int c)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (c) {
    case ':': {
      return HIST_CMD;
    }
    case '=': {
      return HIST_EXPR;
    }
    case '@': {
      return HIST_INPUT;
    }
    case '>': {
      return HIST_DEBUG;
    }
    case NUL:
    case '/':
    case '?': {
      return HIST_SEARCH;
    }
    default: {
      return HIST_INVALID;
    }
  }
  // Silence -Wreturn-type
  return 0;
}

/*
 * Table of history names.
 * These names are used in :history and various hist...() functions.
 * It is sufficient to give the significant prefix of a history name.
 */

static char *(history_names[]) =
{
  "cmd",
  "search",
  "expr",
  "input",
  "debug",
  NULL
};

/*
 * Function given to ExpandGeneric() to obtain the possible first
 * arguments of the ":history command.
 */
static char_u *get_history_arg(expand_T *xp, int idx)
{
  static char_u compl[2] = { NUL, NUL };
  char *short_names = ":=@>?/";
  int short_names_count = (int)STRLEN(short_names);
  int history_name_count = ARRAY_SIZE(history_names) - 1;

  if (idx < short_names_count) {
    compl[0] = (char_u)short_names[idx];
    return compl;
  }
  if (idx < short_names_count + history_name_count)
    return (char_u *)history_names[idx - short_names_count];
  if (idx == short_names_count + history_name_count)
    return (char_u *)"all";
  return NULL;
}

/// Initialize command line history.
/// Also used to re-allocate history tables when size changes.
void init_history(void)
{
  assert(p_hi >= 0 && p_hi <= INT_MAX);
  int newlen = (int)p_hi;
  int oldlen = hislen;

  // If history tables size changed, reallocate them.
  // Tables are circular arrays (current position marked by hisidx[type]).
  // On copying them to the new arrays, we take the chance to reorder them.
  if (newlen != oldlen) {
    for (int type = 0; type < HIST_COUNT; type++) {
      histentry_T *temp = newlen ? xmalloc(newlen * sizeof(*temp)) : NULL;

      int j = hisidx[type];
      if (j >= 0) {
        // old array gets partitioned this way:
        // [0       , i1     ) --> newest entries to be deleted
        // [i1      , i1 + l1) --> newest entries to be copied
        // [i1 + l1 , i2     ) --> oldest entries to be deleted
        // [i2      , i2 + l2) --> oldest entries to be copied
        int l1 = MIN(j + 1, newlen);             // how many newest to copy
        int l2 = MIN(newlen, oldlen) - l1;       // how many oldest to copy
        int i1 = j + 1 - l1;                     // copy newest from here
        int i2 = MAX(l1, oldlen - newlen + l1);  // copy oldest from here

        // copy as much entries as they fit to new table, reordering them
        if (newlen) {
          // copy oldest entries
          memcpy(&temp[0], &history[type][i2], (size_t)l2 * sizeof(*temp));
          // copy newest entries
          memcpy(&temp[l2], &history[type][i1], (size_t)l1 * sizeof(*temp));
        }

        // delete entries that don't fit in newlen, if any
        for (int i = 0; i < i1; i++) {
          hist_free_entry(history[type] + i);
        }
        for (int i = i1 + l1; i < i2; i++) {
          hist_free_entry(history[type] + i);
        }
      }

      // clear remaining space, if any
      int l3 = j < 0 ? 0 : MIN(newlen, oldlen);  // number of copied entries
      if (newlen) {
        memset(temp + l3, 0, (size_t)(newlen - l3) * sizeof(*temp));
      }

      hisidx[type] = l3 - 1;
      xfree(history[type]);
      history[type] = temp;
    }
    hislen = newlen;
  }
}

static inline void hist_free_entry(histentry_T *hisptr)
  FUNC_ATTR_NONNULL_ALL
{
  xfree(hisptr->hisstr);
  tv_list_unref(hisptr->additional_elements);
  clear_hist_entry(hisptr);
}

static inline void clear_hist_entry(histentry_T *hisptr)
  FUNC_ATTR_NONNULL_ALL
{
  memset(hisptr, 0, sizeof(*hisptr));
}

/*
 * Check if command line 'str' is already in history.
 * If 'move_to_front' is TRUE, matching entry is moved to end of history.
 */
static int 
in_history (
    int type,
    char_u *str,
    int move_to_front,              // Move the entry to the front if it exists
    int sep
)
{
  int i;
  int last_i = -1;
  char_u  *p;

  if (hisidx[type] < 0)
    return FALSE;
  i = hisidx[type];
  do {
    if (history[type][i].hisstr == NULL)
      return FALSE;

    /* For search history, check that the separator character matches as
     * well. */
    p = history[type][i].hisstr;
    if (STRCMP(str, p) == 0
        && (type != HIST_SEARCH || sep == p[STRLEN(p) + 1])) {
      if (!move_to_front)
        return TRUE;
      last_i = i;
      break;
    }
    if (--i < 0)
      i = hislen - 1;
  } while (i != hisidx[type]);

  if (last_i >= 0) {
    list_T *const list = history[type][i].additional_elements;
    str = history[type][i].hisstr;
    while (i != hisidx[type]) {
      if (++i >= hislen)
        i = 0;
      history[type][last_i] = history[type][i];
      last_i = i;
    }
    tv_list_unref(list);
    history[type][i].hisnum = ++hisnum[type];
    history[type][i].hisstr = str;
    history[type][i].timestamp = os_time();
    history[type][i].additional_elements = NULL;
    return true;
  }
  return false;
}

/// Convert history name to its HIST_ equivalent
///
/// Names are taken from the table above. When `name` is empty returns currently
/// active history or HIST_DEFAULT, depending on `return_default` argument.
///
/// @param[in]  name            Converted name.
/// @param[in]  len             Name length.
/// @param[in]  return_default  Determines whether HIST_DEFAULT should be
///                             returned or value based on `ccline.cmdfirstc`.
///
/// @return Any value from HistoryType enum, including HIST_INVALID. May not
///         return HIST_DEFAULT unless return_default is true.
HistoryType get_histtype(const char *const name, const size_t len,
                         const bool return_default)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // No argument: use current history.
  if (len == 0) {
    return return_default ? HIST_DEFAULT : hist_char2type(ccline.cmdfirstc);
  }

  for (HistoryType i = 0; history_names[i] != NULL; i++) {
    if (STRNICMP(name, history_names[i], len) == 0) {
      return i;
    }
  }

  if (vim_strchr((char_u *)":=@>?/", name[0]) != NULL && len == 1) {
    return hist_char2type(name[0]);
  }

  return HIST_INVALID;
}

static int last_maptick = -1;           /* last seen maptick */

/*
 * Add the given string to the given history.  If the string is already in the
 * history then it is moved to the front.  "histype" may be one of he HIST_
 * values.
 */
void 
add_to_history (
    int histype,
    char_u *new_entry,
    int in_map,                     /* consider maptick when inside a mapping */
    int sep                        /* separator character used (search hist) */
)
{
  histentry_T *hisptr;
  int len;

  if (hislen == 0 || histype == HIST_INVALID) {  // no history
    return;
  }
  assert(histype != HIST_DEFAULT);

  if (cmdmod.keeppatterns && histype == HIST_SEARCH)
    return;

  /*
   * Searches inside the same mapping overwrite each other, so that only
   * the last line is kept.  Be careful not to remove a line that was moved
   * down, only lines that were added.
   */
  if (histype == HIST_SEARCH && in_map) {
    if (maptick == last_maptick && hisidx[HIST_SEARCH] >= 0) {
      // Current line is from the same mapping, remove it
      hisptr = &history[HIST_SEARCH][hisidx[HIST_SEARCH]];
      hist_free_entry(hisptr);
      --hisnum[histype];
      if (--hisidx[HIST_SEARCH] < 0)
        hisidx[HIST_SEARCH] = hislen - 1;
    }
    last_maptick = -1;
  }
  if (!in_history(histype, new_entry, true, sep)) {
    if (++hisidx[histype] == hislen)
      hisidx[histype] = 0;
    hisptr = &history[histype][hisidx[histype]];
    hist_free_entry(hisptr);

    /* Store the separator after the NUL of the string. */
    len = (int)STRLEN(new_entry);
    hisptr->hisstr = vim_strnsave(new_entry, len + 2);
    hisptr->timestamp = os_time();
    hisptr->additional_elements = NULL;
    hisptr->hisstr[len + 1] = sep;

    hisptr->hisnum = ++hisnum[histype];
    if (histype == HIST_SEARCH && in_map)
      last_maptick = maptick;
  }
}


/*
 * Get identifier of newest history entry.
 * "histype" may be one of the HIST_ values.
 */
int get_history_idx(int histype)
{
  if (hislen == 0 || histype < 0 || histype >= HIST_COUNT
      || hisidx[histype] < 0)
    return -1;

  return history[histype][hisidx[histype]].hisnum;
}


/*
 * Get pointer to the command line info to use. cmdline_paste() may clear
 * ccline and put the previous value in prev_ccline.
 */
static struct cmdline_info *get_ccline_ptr(void)
{
  if ((State & CMDLINE) == 0) {
    return NULL;
  } else if (ccline.cmdbuff != NULL) {
    return &ccline;
  } else if (ccline.prev_ccline && ccline.prev_ccline->cmdbuff != NULL) {
    return ccline.prev_ccline;
  } else {
    return NULL;
  }
}

/*
 * Get the current command line in allocated memory.
 * Only works when the command line is being edited.
 * Returns NULL when something is wrong.
 */
char_u *get_cmdline_str(void)
{
  if (cmdline_star > 0) {
    return NULL;
  }
  struct cmdline_info *p = get_ccline_ptr();

  if (p == NULL)
    return NULL;
  return vim_strnsave(p->cmdbuff, p->cmdlen);
}

/*
 * Get the current command line position, counted in bytes.
 * Zero is the first position.
 * Only works when the command line is being edited.
 * Returns -1 when something is wrong.
 */
int get_cmdline_pos(void)
{
  struct cmdline_info *p = get_ccline_ptr();

  if (p == NULL)
    return -1;
  return p->cmdpos;
}

/*
 * Set the command line byte position to "pos".  Zero is the first position.
 * Only works when the command line is being edited.
 * Returns 1 when failed, 0 when OK.
 */
int set_cmdline_pos(int pos)
{
  struct cmdline_info *p = get_ccline_ptr();

  if (p == NULL)
    return 1;

  /* The position is not set directly but after CTRL-\ e or CTRL-R = has
   * changed the command line. */
  if (pos < 0)
    new_cmdpos = 0;
  else
    new_cmdpos = pos;
  return 0;
}

/*
 * Get the current command-line type.
 * Returns ':' or '/' or '?' or '@' or '>' or '-'
 * Only works when the command line is being edited.
 * Returns NUL when something is wrong.
 */
int get_cmdline_type(void)
{
  struct cmdline_info *p = get_ccline_ptr();

  if (p == NULL)
    return NUL;
  if (p->cmdfirstc == NUL)
    return (p->input_fn) ? '@' : '-';
  return p->cmdfirstc;
}

/*
 * Calculate history index from a number:
 *   num > 0: seen as identifying number of a history entry
 *   num < 0: relative position in history wrt newest entry
 * "histype" may be one of the HIST_ values.
 */
static int calc_hist_idx(int histype, int num)
{
  int i;
  histentry_T *hist;
  int wrapped = FALSE;

  if (hislen == 0 || histype < 0 || histype >= HIST_COUNT
      || (i = hisidx[histype]) < 0 || num == 0)
    return -1;

  hist = history[histype];
  if (num > 0) {
    while (hist[i].hisnum > num)
      if (--i < 0) {
        if (wrapped)
          break;
        i += hislen;
        wrapped = TRUE;
      }
    if (hist[i].hisnum == num && hist[i].hisstr != NULL)
      return i;
  } else if (-num <= hislen)   {
    i += num + 1;
    if (i < 0)
      i += hislen;
    if (hist[i].hisstr != NULL)
      return i;
  }
  return -1;
}

/*
 * Get a history entry by its index.
 * "histype" may be one of the HIST_ values.
 */
char_u *get_history_entry(int histype, int idx)
{
  idx = calc_hist_idx(histype, idx);
  if (idx >= 0)
    return history[histype][idx].hisstr;
  else
    return (char_u *)"";
}

/// Clear all entries in a history
///
/// @param[in]  histype  One of the HIST_ values.
///
/// @return OK if there was something to clean and histype was one of HIST_
///         values, FAIL otherwise.
int clr_history(const int histype)
{
  if (hislen != 0 && histype >= 0 && histype < HIST_COUNT) {
    histentry_T *hisptr = history[histype];
    for (int i = hislen; i--; hisptr++) {
      hist_free_entry(hisptr);
    }
    hisidx[histype] = -1;  // mark history as cleared
    hisnum[histype] = 0;   // reset identifier counter
    return OK;
  }
  return FAIL;
}

/*
 * Remove all entries matching {str} from a history.
 * "histype" may be one of the HIST_ values.
 */
int del_history_entry(int histype, char_u *str)
{
  regmatch_T regmatch;
  histentry_T *hisptr;
  int idx;
  int i;
  int last;
  bool found = false;

  regmatch.regprog = NULL;
  regmatch.rm_ic = FALSE;       /* always match case */
  if (hislen != 0
      && histype >= 0
      && histype < HIST_COUNT
      && *str != NUL
      && (idx = hisidx[histype]) >= 0
      && (regmatch.regprog = vim_regcomp(str, RE_MAGIC + RE_STRING))
      != NULL) {
    i = last = idx;
    do {
      hisptr = &history[histype][i];
      if (hisptr->hisstr == NULL)
        break;
      if (vim_regexec(&regmatch, hisptr->hisstr, (colnr_T)0)) {
        found = true;
        hist_free_entry(hisptr);
      } else {
        if (i != last) {
          history[histype][last] = *hisptr;
          clear_hist_entry(hisptr);
        }
        if (--last < 0)
          last += hislen;
      }
      if (--i < 0)
        i += hislen;
    } while (i != idx);
    if (history[histype][idx].hisstr == NULL)
      hisidx[histype] = -1;
  }
  vim_regfree(regmatch.regprog);
  return found;
}

/*
 * Remove an indexed entry from a history.
 * "histype" may be one of the HIST_ values.
 */
int del_history_idx(int histype, int idx)
{
  int i, j;

  i = calc_hist_idx(histype, idx);
  if (i < 0)
    return FALSE;
  idx = hisidx[histype];
  hist_free_entry(&history[histype][i]);

  /* When deleting the last added search string in a mapping, reset
   * last_maptick, so that the last added search string isn't deleted again.
   */
  if (histype == HIST_SEARCH && maptick == last_maptick && i == idx)
    last_maptick = -1;

  while (i != idx) {
    j = (i + 1) % hislen;
    history[histype][i] = history[histype][j];
    i = j;
  }
  clear_hist_entry(&history[histype][idx]);
  if (--i < 0) {
    i += hislen;
  }
  hisidx[histype] = i;
  return TRUE;
}

/// Get indices that specify a range within a list (not a range of text lines
/// in a buffer!) from a string.  Used for ":history" and ":clist".
///
/// @param str string to parse range from
/// @param num1 from
/// @param num2 to
///
/// @return OK if parsed successfully, otherwise FAIL.
int get_list_range(char_u **str, int *num1, int *num2)
{
  int len;
  int first = false;
  varnumber_T num;

  *str = skipwhite(*str);
  if (**str == '-' || ascii_isdigit(**str)) {  // parse "from" part of range
    vim_str2nr(*str, NULL, &len, 0, &num, NULL, 0);
    *str += len;
    *num1 = (int)num;
    first = true;
  }
  *str = skipwhite(*str);
  if (**str == ',') {                   // parse "to" part of range
    *str = skipwhite(*str + 1);
    vim_str2nr(*str, NULL, &len, 0, &num, NULL, 0);
    if (len > 0) {
      *num2 = (int)num;
      *str = skipwhite(*str + len);
    } else if (!first) {                  // no number given at all
      return FAIL;
    }
  } else if (first) {                     // only one number given
    *num2 = *num1;
  }
  return OK;
}

/*
 * :history command - print a history
 */
void ex_history(exarg_T *eap)
{
  histentry_T *hist;
  int histype1 = HIST_CMD;
  int histype2 = HIST_CMD;
  int hisidx1 = 1;
  int hisidx2 = -1;
  int idx;
  int i, j, k;
  char_u      *end;
  char_u      *arg = eap->arg;

  if (hislen == 0) {
    MSG(_("'history' option is zero"));
    return;
  }

  if (!(ascii_isdigit(*arg) || *arg == '-' || *arg == ',')) {
    end = arg;
    while (ASCII_ISALPHA(*end)
           || vim_strchr((char_u *)":=@>/?", *end) != NULL)
      end++;
    histype1 = get_histtype((const char *)arg, end - arg, false);
    if (histype1 == HIST_INVALID) {
      if (STRNICMP(arg, "all", end - arg) == 0) {
        histype1 = 0;
        histype2 = HIST_COUNT-1;
      } else {
        EMSG(_(e_trailing));
        return;
      }
    } else
      histype2 = histype1;
  } else {
    end = arg;
  }
  if (!get_list_range(&end, &hisidx1, &hisidx2) || *end != NUL) {
    EMSG(_(e_trailing));
    return;
  }

  for (; !got_int && histype1 <= histype2; ++histype1) {
    STRCPY(IObuff, "\n      #  ");
    assert(history_names[histype1] != NULL);
    STRCAT(STRCAT(IObuff, history_names[histype1]), " history");
    MSG_PUTS_TITLE(IObuff);
    idx = hisidx[histype1];
    hist = history[histype1];
    j = hisidx1;
    k = hisidx2;
    if (j < 0)
      j = (-j > hislen) ? 0 : hist[(hislen+j+idx+1) % hislen].hisnum;
    if (k < 0)
      k = (-k > hislen) ? 0 : hist[(hislen+k+idx+1) % hislen].hisnum;
    if (idx >= 0 && j <= k)
      for (i = idx + 1; !got_int; ++i) {
        if (i == hislen)
          i = 0;
        if (hist[i].hisstr != NULL
            && hist[i].hisnum >= j && hist[i].hisnum <= k) {
          msg_putchar('\n');
          sprintf((char *)IObuff, "%c%6d  ", i == idx ? '>' : ' ',
              hist[i].hisnum);
          if (vim_strsize(hist[i].hisstr) > (int)Columns - 10)
            trunc_string(hist[i].hisstr, IObuff + STRLEN(IObuff),
                (int)Columns - 10, IOSIZE - (int)STRLEN(IObuff));
          else
            STRCAT(IObuff, hist[i].hisstr);
          msg_outtrans(IObuff);
          ui_flush();
        }
        if (i == idx)
          break;
      }
  }
}

/// Translate a history type number to the associated character
int hist_type2char(int type)
  FUNC_ATTR_CONST
{
  switch (type) {
    case HIST_CMD: {
      return ':';
    }
    case HIST_SEARCH: {
      return '/';
    }
    case HIST_EXPR: {
      return '=';
    }
    case HIST_INPUT: {
      return '@';
    }
    case HIST_DEBUG: {
      return '>';
    }
    default: {
      assert(false);
    }
  }
  return NUL;
}

/*
 * Write a character at the current cursor+offset position.
 * It is directly written into the command buffer block.
 */
void cmd_pchar(int c, int offset)
{
  if (ccline.cmdpos + offset >= ccline.cmdlen || ccline.cmdpos + offset < 0) {
    EMSG(_("E198: cmd_pchar beyond the command length"));
    return;
  }
  ccline.cmdbuff[ccline.cmdpos + offset] = (char_u)c;
  ccline.cmdbuff[ccline.cmdlen] = NUL;
}

int cmd_gchar(int offset)
{
  if (ccline.cmdpos + offset >= ccline.cmdlen || ccline.cmdpos + offset < 0) {
    /*  EMSG(_("cmd_gchar beyond the command length")); */
    return NUL;
  }
  return (int)ccline.cmdbuff[ccline.cmdpos + offset];
}

/*
 * Open a window on the current command line and history.  Allow editing in
 * the window.  Returns when the window is closed.
 * Returns:
 *	CR	 if the command is to be executed
 *	Ctrl_C	 if it is to be abandoned
 *	K_IGNORE if editing continues
 */
static int open_cmdwin(void)
{
  struct cmdline_info save_ccline;
  bufref_T            old_curbuf;
  bufref_T            bufref;
  win_T               *old_curwin = curwin;
  win_T               *wp;
  int i;
  linenr_T lnum;
  garray_T winsizes;
  char_u typestr[2];
  int save_restart_edit = restart_edit;
  int save_State = State;
  int save_exmode = exmode_active;
  int save_cmdmsg_rl = cmdmsg_rl;

  /* Can't do this recursively.  Can't do it when typing a password. */
  if (cmdwin_type != 0
      || cmdline_star > 0
      ) {
    beep_flush();
    return K_IGNORE;
  }

  set_bufref(&old_curbuf, curbuf);

  /* Save current window sizes. */
  win_size_save(&winsizes);

  /* Don't execute autocommands while creating the window. */
  block_autocmds();
  /* don't use a new tab page */
  cmdmod.tab = 0;
  cmdmod.noswapfile = 1;

  /* Create a window for the command-line buffer. */
  if (win_split((int)p_cwh, WSP_BOT) == FAIL) {
    beep_flush();
    unblock_autocmds();
    return K_IGNORE;
  }
  cmdwin_type = get_cmdline_type();
  cmdwin_level = ccline.level;

  // Create empty command-line buffer.
  buf_open_scratch(0, "[Command Line]");
  // Command-line buffer has bufhidden=wipe, unlike a true "scratch" buffer.
  set_option_value("bh", 0L, "wipe", OPT_LOCAL);
  curwin->w_p_rl = cmdmsg_rl;
  cmdmsg_rl = false;
  curbuf->b_p_ma = true;
  curwin->w_p_fen = false;

  // Do execute autocommands for setting the filetype (load syntax).
  unblock_autocmds();
  // But don't allow switching to another buffer.
  curbuf_lock++;

  /* Showing the prompt may have set need_wait_return, reset it. */
  need_wait_return = FALSE;

  const int histtype = hist_char2type(cmdwin_type);
  if (histtype == HIST_CMD || histtype == HIST_DEBUG) {
    if (p_wc == TAB) {
      add_map((char_u *)"<buffer> <Tab> <C-X><C-V>", INSERT);
      add_map((char_u *)"<buffer> <Tab> a<C-X><C-V>", NORMAL);
    }
    set_option_value("ft", 0L, "vim", OPT_LOCAL);
  }
  curbuf_lock--;

  /* Reset 'textwidth' after setting 'filetype' (the Vim filetype plugin
   * sets 'textwidth' to 78). */
  curbuf->b_p_tw = 0;

  /* Fill the buffer with the history. */
  init_history();
  if (hislen > 0 && histtype != HIST_INVALID) {
    i = hisidx[histtype];
    if (i >= 0) {
      lnum = 0;
      do {
        if (++i == hislen)
          i = 0;
        if (history[histtype][i].hisstr != NULL)
          ml_append(lnum++, history[histtype][i].hisstr,
              (colnr_T)0, FALSE);
      } while (i != hisidx[histtype]);
    }
  }

  /* Replace the empty last line with the current command-line and put the
   * cursor there. */
  ml_replace(curbuf->b_ml.ml_line_count, ccline.cmdbuff, true);
  curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
  curwin->w_cursor.col = ccline.cmdpos;
  changed_line_abv_curs();
  invalidate_botline();
  if (ui_is_external(kUICmdline)) {
    ccline.redraw_state = kCmdRedrawNone;
    ui_call_cmdline_hide(ccline.level);
  }
  redraw_later(SOME_VALID);

  // Save the command line info, can be used recursively.
  save_cmdline(&save_ccline);

  /* No Ex mode here! */
  exmode_active = 0;

  State = NORMAL;
  setmouse();

  /* Trigger CmdwinEnter autocommands. */
  typestr[0] = cmdwin_type;
  typestr[1] = NUL;
  apply_autocmds(EVENT_CMDWINENTER, typestr, typestr, FALSE, curbuf);
  if (restart_edit != 0)        /* autocmd with ":startinsert" */
    stuffcharReadbuff(K_NOP);

  i = RedrawingDisabled;
  RedrawingDisabled = 0;
  int save_count = save_batch_count();

  /*
   * Call the main loop until <CR> or CTRL-C is typed.
   */
  cmdwin_result = 0;
  normal_enter(true, false);

  RedrawingDisabled = i;
  restore_batch_count(save_count);

  const bool save_KeyTyped = KeyTyped;

  /* Trigger CmdwinLeave autocommands. */
  apply_autocmds(EVENT_CMDWINLEAVE, typestr, typestr, FALSE, curbuf);

  /* Restore KeyTyped in case it is modified by autocommands */
  KeyTyped = save_KeyTyped;

  // Restore the command line info.
  restore_cmdline(&save_ccline);
  cmdwin_type = 0;
  cmdwin_level = 0;

  exmode_active = save_exmode;

  /* Safety check: The old window or buffer was deleted: It's a bug when
   * this happens! */
  if (!win_valid(old_curwin) || !bufref_valid(&old_curbuf)) {
    cmdwin_result = Ctrl_C;
    EMSG(_("E199: Active window or buffer deleted"));
  } else {
    /* autocmds may abort script processing */
    if (aborting() && cmdwin_result != K_IGNORE)
      cmdwin_result = Ctrl_C;
    /* Set the new command line from the cmdline buffer. */
    xfree(ccline.cmdbuff);
    if (cmdwin_result == K_XF1 || cmdwin_result == K_XF2) {  // :qa[!] typed
      const char *p = (cmdwin_result == K_XF2) ? "qa" : "qa!";

      if (histtype == HIST_CMD) {
        // Execute the command directly.
        ccline.cmdbuff = (char_u *)xstrdup(p);
        cmdwin_result = CAR;
      } else {
        // First need to cancel what we were doing.
        ccline.cmdbuff = NULL;
        stuffcharReadbuff(':');
        stuffReadbuff(p);
        stuffcharReadbuff(CAR);
      }
    } else if (cmdwin_result == Ctrl_C) {
      /* :q or :close, don't execute any command
       * and don't modify the cmd window. */
      ccline.cmdbuff = NULL;
    } else
      ccline.cmdbuff = vim_strsave(get_cursor_line_ptr());
    if (ccline.cmdbuff == NULL) {
      ccline.cmdbuff = vim_strsave((char_u *)"");
      ccline.cmdlen = 0;
      ccline.cmdbufflen = 1;
      ccline.cmdpos = 0;
      cmdwin_result = Ctrl_C;
    } else {
      ccline.cmdlen = (int)STRLEN(ccline.cmdbuff);
      ccline.cmdbufflen = ccline.cmdlen + 1;
      ccline.cmdpos = curwin->w_cursor.col;
      if (ccline.cmdpos > ccline.cmdlen)
        ccline.cmdpos = ccline.cmdlen;
      if (cmdwin_result == K_IGNORE) {
        set_cmdspos_cursor();
        redrawcmd();
      }
    }

    /* Don't execute autocommands while deleting the window. */
    block_autocmds();
    // Avoid command-line window first character being concealed
    curwin->w_p_cole = 0;
    wp = curwin;
    set_bufref(&bufref, curbuf);
    win_goto(old_curwin);
    win_close(wp, true);

    // win_close() may have already wiped the buffer when 'bh' is
    // set to 'wipe'.
    if (bufref_valid(&bufref)) {
      close_buffer(NULL, bufref.br_buf, DOBUF_WIPE, false);
    }

    /* Restore window sizes. */
    win_size_restore(&winsizes);

    unblock_autocmds();
  }

  ga_clear(&winsizes);
  restart_edit = save_restart_edit;
  cmdmsg_rl = save_cmdmsg_rl;

  State = save_State;
  setmouse();

  return cmdwin_result;
}

/// Get script string
///
/// Used for commands which accept either `:command script` or
///
///     :command << endmarker
///       script
///     endmarker
///
/// @param  eap  Command being run.
/// @param[out]  lenp  Location where length of resulting string is saved. Will
///                    be set to zero when skipping.
///
/// @return [allocated] NULL or script. Does not show any error messages.
///                     NULL is returned when skipping and on error.
char *script_get(exarg_T *const eap, size_t *const lenp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
{
  const char *const cmd = (const char *)eap->arg;

  if (cmd[0] != '<' || cmd[1] != '<' || eap->getline == NULL) {
    *lenp = STRLEN(eap->arg);
    return eap->skip ? NULL : xmemdupz(eap->arg, *lenp);
  }

  garray_T ga = { .ga_data = NULL, .ga_len = 0 };
  if (!eap->skip) {
    ga_init(&ga, 1, 0x400);
  }

  const char *const end_pattern = (
      cmd[2] != NUL
      ? (const char *)skipwhite((const char_u *)cmd + 2)
      : ".");
  for (;;) {
    char *const theline = (char *)eap->getline(
        eap->cstack->cs_looplevel > 0 ? -1 :
        NUL, eap->cookie, 0);

    if (theline == NULL || strcmp(end_pattern, theline) == 0) {
      xfree(theline);
      break;
    }

    if (!eap->skip) {
      ga_concat(&ga, (const char_u *)theline);
      ga_append(&ga, '\n');
    }
    xfree(theline);
  }
  *lenp = (size_t)ga.ga_len;  // Set length without trailing NUL.
  if (!eap->skip) {
    ga_append(&ga, NUL);
  }

  return (char *)ga.ga_data;
}

/// Iterate over history items
///
/// @warning No history-editing functions must be run while iteration is in
///          progress.
///
/// @param[in]   iter          Pointer to the last history entry.
/// @param[in]   history_type  Type of the history (HIST_*). Ignored if iter
///                            parameter is not NULL.
/// @param[in]   zero          If true then zero (but not free) returned items.
///
///                            @warning When using this parameter user is
///                                     responsible for calling clr_history()
///                                     itself after iteration is over. If
///                                     clr_history() is not called behaviour is
///                                     undefined. No functions that work with
///                                     history must be called during iteration
///                                     in this case.
/// @param[out]  hist          Next history entry.
///
/// @return Pointer used in next iteration or NULL to indicate that iteration
///         was finished.
const void *hist_iter(const void *const iter, const uint8_t history_type,
                      const bool zero, histentry_T *const hist)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(4)
{
  *hist = (histentry_T) {
    .hisstr = NULL
  };
  if (hisidx[history_type] == -1) {
    return NULL;
  }
  histentry_T *const hstart = &(history[history_type][0]);
  histentry_T *const hlast = (
      &(history[history_type][hisidx[history_type]]));
  const histentry_T *const hend = &(history[history_type][hislen - 1]);
  histentry_T *hiter;
  if (iter == NULL) {
    histentry_T *hfirst = hlast;
    do {
      hfirst++;
      if (hfirst > hend) {
        hfirst = hstart;
      }
      if (hfirst->hisstr != NULL) {
        break;
      }
    } while (hfirst != hlast);
    hiter = hfirst;
  } else {
    hiter = (histentry_T *) iter;
  }
  if (hiter == NULL) {
    return NULL;
  }
  *hist = *hiter;
  if (zero) {
    memset(hiter, 0, sizeof(*hiter));
  }
  if (hiter == hlast) {
    return NULL;
  }
  hiter++;
  return (const void *) ((hiter > hend) ? hstart : hiter);
}

/// Get array of history items
///
/// @param[in]   history_type  Type of the history to get array for.
/// @param[out]  new_hisidx    Location where last index in the new array should
///                            be saved.
/// @param[out]  new_hisnum    Location where last history number in the new
///                            history should be saved.
///
/// @return Pointer to the array or NULL.
histentry_T *hist_get_array(const uint8_t history_type, int **const new_hisidx,
                            int **const new_hisnum)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  init_history();
  *new_hisidx = &(hisidx[history_type]);
  *new_hisnum = &(hisnum[history_type]);
  return history[history_type];
}

static void set_search_match(pos_T *t)
{
  // First move cursor to end of match, then to the start.  This
  // moves the whole match onto the screen when 'nowrap' is set.
  t->lnum += search_match_lines;
  t->col = search_match_endcol;
  if (t->lnum > curbuf->b_ml.ml_line_count) {
    t->lnum = curbuf->b_ml.ml_line_count;
    coladvance((colnr_T)MAXCOL);
  }
}
