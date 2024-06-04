// ex_getln.c: Functions for entering and editing an Ex command line.

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/arabic.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cmdhist.h"
#include "nvim/cursor.h"
#include "nvim/digraph.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/extmark.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/mapping.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/path.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/undo_defs.h"
#include "nvim/usercmd.h"
#include "nvim/vim_defs.h"
#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/parser.h"
#include "nvim/viml/parser/parser_defs.h"
#include "nvim/window.h"

/// Last value of prompt_id, incremented when doing new prompt
static unsigned last_prompt_id = 0;

// Struct to store the viewstate during 'incsearch' highlighting and 'inccommand' preview.
typedef struct {
  colnr_T vs_curswant;
  colnr_T vs_leftcol;
  colnr_T vs_skipcol;
  linenr_T vs_topline;
  int vs_topfill;
  linenr_T vs_botline;
  int vs_empty_rows;
} viewstate_T;

// Struct to store the state of 'incsearch' highlighting.
typedef struct {
  pos_T search_start;   // where 'incsearch' starts searching
  pos_T save_cursor;
  viewstate_T init_viewstate;
  viewstate_T old_viewstate;
  pos_T match_start;
  pos_T match_end;
  bool did_incsearch;
  bool incsearch_postponed;
  optmagic_T magic_overruled_save;
} incsearch_state_T;

typedef struct {
  VimState state;
  int firstc;
  int count;
  int indent;
  int c;
  bool gotesc;                          // true when <ESC> just typed
  int do_abbr;                          // when true check for abbr.
  char *lookfor;                        // string to match
  int hiscnt;                           // current history line in use
  int save_hiscnt;                      // history line before attempting
                                        // to jump to next match
  int histype;                          // history type to be used
  incsearch_state_T is_state;
  int did_wild_list;                    // did wild_list() recently
  int wim_index;                        // index in wim_flags[]
  int save_msg_scroll;
  int save_State;                 // remember State when called
  char *save_p_icm;
  int some_key_typed;                   // one of the keys was typed
  // mouse drag and release events are ignored, unless they are
  // preceded with a mouse down event
  int ignore_drag_release;
  int break_ctrl_c;
  expand_T xpc;
  OptInt *b_im_ptr;
  buf_T *b_im_ptr_buf;  ///< buffer where b_im_ptr is valid
} CommandLineState;

typedef struct {
  u_header_T *save_b_u_oldhead;
  u_header_T *save_b_u_newhead;
  u_header_T *save_b_u_curhead;
  int save_b_u_numhead;
  bool save_b_u_synced;
  int save_b_u_seq_last;
  int save_b_u_save_nr_last;
  int save_b_u_seq_cur;
  time_t save_b_u_time_cur;
  int save_b_u_save_nr_cur;
  char *save_b_u_line_ptr;
  linenr_T save_b_u_line_lnum;
  colnr_T save_b_u_line_colnr;
} CpUndoInfo;

typedef struct {
  buf_T *buf;
  OptInt save_b_p_ul;
  int save_b_changed;
  pos_T save_b_op_start;
  pos_T save_b_op_end;
  varnumber_T save_changedtick;
  CpUndoInfo undo_info;
} CpBufInfo;

typedef struct {
  win_T *win;
  pos_T save_w_cursor;
  viewstate_T save_viewstate;
  int save_w_p_cul;
  int save_w_p_cuc;
} CpWinInfo;

typedef struct {
  kvec_t(CpWinInfo) win_info;
  kvec_t(CpBufInfo) buf_info;
  bool save_hls;
  cmdmod_T save_cmdmod;
  garray_T save_view;
} CpInfo;

/// Return value when handling keys in command-line mode.
enum {
  CMDLINE_NOT_CHANGED = 1,
  CMDLINE_CHANGED     = 2,
  GOTO_NORMAL_MODE    = 3,
  PROCESS_NEXT_KEY    = 4,
};

/// The current cmdline_info.  It is initialized in getcmdline() and after that
/// used by other functions.  When invoking getcmdline() recursively it needs
/// to be saved with save_cmdline() and restored with restore_cmdline().
static CmdlineInfo ccline;

static int new_cmdpos;          // position set by set_cmdline_pos()

/// currently displayed block of context
static Array cmdline_block = ARRAY_DICT_INIT;

/// Flag for command_line_handle_key to ignore <C-c>
///
/// Used if it was received while processing highlight function in order for
/// user interrupting highlight function to not interrupt command-line.
static bool getln_interrupted_highlight = false;

static int cedit_key = -1;  ///< key value of 'cedit' option

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_getln.c.generated.h"
#endif

static handle_T cmdpreview_bufnr = 0;
static int cmdpreview_ns = 0;

static const char e_active_window_or_buffer_changed_or_deleted[]
  = N_("E199: Active window or buffer changed or deleted");

static void save_viewstate(win_T *wp, viewstate_T *vs)
  FUNC_ATTR_NONNULL_ALL
{
  vs->vs_curswant = wp->w_curswant;
  vs->vs_leftcol = wp->w_leftcol;
  vs->vs_skipcol = wp->w_skipcol;
  vs->vs_topline = wp->w_topline;
  vs->vs_topfill = wp->w_topfill;
  vs->vs_botline = wp->w_botline;
  vs->vs_empty_rows = wp->w_empty_rows;
}

static void restore_viewstate(win_T *wp, viewstate_T *vs)
  FUNC_ATTR_NONNULL_ALL
{
  wp->w_curswant = vs->vs_curswant;
  wp->w_leftcol = vs->vs_leftcol;
  wp->w_skipcol = vs->vs_skipcol;
  wp->w_topline = vs->vs_topline;
  wp->w_topfill = vs->vs_topfill;
  wp->w_botline = vs->vs_botline;
  wp->w_empty_rows = vs->vs_empty_rows;
}

static void init_incsearch_state(incsearch_state_T *s)
{
  s->match_start = curwin->w_cursor;
  s->did_incsearch = false;
  s->incsearch_postponed = false;
  s->magic_overruled_save = magic_overruled;
  clearpos(&s->match_end);
  s->save_cursor = curwin->w_cursor;  // may be restored later
  s->search_start = curwin->w_cursor;
  save_viewstate(curwin, &s->init_viewstate);
  save_viewstate(curwin, &s->old_viewstate);
}

// Return true when 'incsearch' highlighting is to be done.
// Sets search_first_line and search_last_line to the address range.
static bool do_incsearch_highlighting(int firstc, int *search_delim, incsearch_state_T *s,
                                      int *skiplen, int *patlen)
  FUNC_ATTR_NONNULL_ALL
{
  char *p;
  bool delim_optional = false;
  const char *dummy;
  bool retval = false;
  magic_T magic = 0;

  *skiplen = 0;
  *patlen = ccline.cmdlen;

  if (!p_is || cmd_silent) {
    return false;
  }

  // by default search all lines
  search_first_line = 0;
  search_last_line = MAXLNUM;

  if (firstc == '/' || firstc == '?') {
    *search_delim = firstc;
    return true;
  }
  if (firstc != ':') {
    return false;
  }

  emsg_off++;
  exarg_T ea = {
    .line1 = 1,
    .line2 = 1,
    .cmd = ccline.cmdbuff,
    .addr_type = ADDR_LINES,
  };

  cmdmod_T dummy_cmdmod;
  parse_command_modifiers(&ea, &dummy, &dummy_cmdmod, true);

  char *cmd = skip_range(ea.cmd, NULL);
  if (vim_strchr("sgvl", (uint8_t)(*cmd)) == NULL) {
    goto theend;
  }

  // Skip over "substitute" to find the pattern separator.
  for (p = cmd; ASCII_ISALPHA(*p); p++) {}
  if (*skipwhite(p) == NUL) {
    goto theend;
  }

  if (strncmp(cmd, "substitute", (size_t)(p - cmd)) == 0
      || strncmp(cmd, "smagic", (size_t)(p - cmd)) == 0
      || strncmp(cmd, "snomagic", (size_t)MAX(p - cmd, 3)) == 0
      || strncmp(cmd, "vglobal", (size_t)(p - cmd)) == 0) {
    if (*cmd == 's' && cmd[1] == 'm') {
      magic_overruled = OPTION_MAGIC_ON;
    } else if (*cmd == 's' && cmd[1] == 'n') {
      magic_overruled = OPTION_MAGIC_OFF;
    }
  } else if (strncmp(cmd, "sort", (size_t)MAX(p - cmd, 3)) == 0) {
    // skip over ! and flags
    if (*p == '!') {
      p = skipwhite(p + 1);
    }
    while (ASCII_ISALPHA(*(p = skipwhite(p)))) {
      p++;
    }
    if (*p == NUL) {
      goto theend;
    }
  } else if (strncmp(cmd, "vimgrep", (size_t)MAX(p - cmd, 3)) == 0
             || strncmp(cmd, "vimgrepadd", (size_t)MAX(p - cmd, 8)) == 0
             || strncmp(cmd, "lvimgrep", (size_t)MAX(p - cmd, 2)) == 0
             || strncmp(cmd, "lvimgrepadd", (size_t)MAX(p - cmd, 9)) == 0
             || strncmp(cmd, "global", (size_t)(p - cmd)) == 0) {
    // skip over "!/".
    if (*p == '!') {
      p++;
      if (*skipwhite(p) == NUL) {
        goto theend;
      }
    }
    if (*cmd != 'g') {
      delim_optional = true;
    }
  } else {
    goto theend;
  }

  p = skipwhite(p);
  int delim = (delim_optional && vim_isIDc((uint8_t)(*p))) ? ' ' : *p++;
  *search_delim = delim;
  char *end = skip_regexp_ex(p, delim, magic_isset(), NULL, NULL, &magic);

  bool use_last_pat = end == p && *end == delim;
  if (end == p && !use_last_pat) {
    goto theend;
  }

  // Don't do 'hlsearch' highlighting if the pattern matches everything.
  if (!use_last_pat) {
    char c = *end;
    *end = NUL;
    bool empty = empty_pattern_magic(p, strlen(p), magic);
    *end = c;
    if (empty) {
      goto theend;
    }
  }

  // found a non-empty pattern or //
  *skiplen = (int)(p - ccline.cmdbuff);
  *patlen = (int)(end - p);

  // parse the address range
  pos_T save_cursor = curwin->w_cursor;
  curwin->w_cursor = s->search_start;
  parse_cmd_address(&ea, &dummy, true);
  if (ea.addr_count > 0) {
    // Allow for reverse match.
    if (ea.line2 < ea.line1) {
      search_first_line = ea.line2;
      search_last_line = ea.line1;
    } else {
      search_first_line = ea.line1;
      search_last_line = ea.line2;
    }
  } else if (cmd[0] == 's' && cmd[1] != 'o') {
    // :s defaults to the current line
    search_first_line = curwin->w_cursor.lnum;
    search_last_line = curwin->w_cursor.lnum;
  }

  curwin->w_cursor = save_cursor;
  retval = true;
theend:
  emsg_off--;
  return retval;
}

// May do 'incsearch' highlighting if desired.
static void may_do_incsearch_highlighting(int firstc, int count, incsearch_state_T *s)
{
  pos_T end_pos;
  int skiplen, patlen;
  int search_delim;

  // Parsing range may already set the last search pattern.
  // NOTE: must call restore_last_search_pattern() before returning!
  save_last_search_pattern();

  if (!do_incsearch_highlighting(firstc, &search_delim, s, &skiplen,
                                 &patlen)) {
    restore_last_search_pattern();
    finish_incsearch_highlighting(false, s, true);
    return;
  }

  // if there is a character waiting, search and redraw later
  if (char_avail()) {
    restore_last_search_pattern();
    s->incsearch_postponed = true;
    return;
  }
  s->incsearch_postponed = false;

  if (search_first_line == 0) {
    // start at the original cursor position
    curwin->w_cursor = s->search_start;
  } else if (search_first_line > curbuf->b_ml.ml_line_count) {
    // start after the last line
    curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
    curwin->w_cursor.col = MAXCOL;
  } else {
    // start at the first line in the range
    curwin->w_cursor.lnum = search_first_line;
    curwin->w_cursor.col = 0;
  }
  int found;  // do_search() result

  // Use the previous pattern for ":s//".
  char next_char = ccline.cmdbuff[skiplen + patlen];
  bool use_last_pat = patlen == 0 && skiplen > 0
                      && ccline.cmdbuff[skiplen - 1] == next_char;

  // If there is no pattern, don't do anything.
  if (patlen == 0 && !use_last_pat) {
    found = 0;
    set_no_hlsearch(true);  // turn off previous highlight
    redraw_all_later(UPD_SOME_VALID);
  } else {
    int search_flags = SEARCH_OPT + SEARCH_NOOF + SEARCH_PEEK;
    ui_busy_start();
    ui_flush();
    emsg_off++;            // So it doesn't beep if bad expr
    // Set the time limit to half a second.
    proftime_T tm = profile_setlimit(500);
    if (!p_hls) {
      search_flags += SEARCH_KEEP;
    }
    if (search_first_line != 0) {
      search_flags += SEARCH_START;
    }
    ccline.cmdbuff[skiplen + patlen] = NUL;
    searchit_arg_T sia = {
      .sa_tm = &tm,
    };
    found = do_search(NULL, firstc == ':' ? '/' : firstc, search_delim,
                      ccline.cmdbuff + skiplen, (size_t)patlen, count,
                      search_flags, &sia);
    ccline.cmdbuff[skiplen + patlen] = next_char;
    emsg_off--;
    if (curwin->w_cursor.lnum < search_first_line
        || curwin->w_cursor.lnum > search_last_line) {
      // match outside of address range
      found = 0;
      curwin->w_cursor = s->search_start;
    }

    // if interrupted while searching, behave like it failed
    if (got_int) {
      vpeekc();               // remove <C-C> from input stream
      got_int = false;              // don't abandon the command line
      found = 0;
    } else if (char_avail()) {
      // cancelled searching because a char was typed
      s->incsearch_postponed = true;
    }
    ui_busy_stop();
  }

  if (found != 0) {
    highlight_match = true;   // highlight position
  } else {
    highlight_match = false;  // remove highlight
  }

  // first restore the old curwin values, so the screen is
  // positioned in the same way as the actual search command
  restore_viewstate(curwin, &s->old_viewstate);
  changed_cline_bef_curs(curwin);
  update_topline(curwin);

  if (found != 0) {
    pos_T save_pos = curwin->w_cursor;

    s->match_start = curwin->w_cursor;
    set_search_match(&curwin->w_cursor);
    validate_cursor(curwin);
    end_pos = curwin->w_cursor;
    s->match_end = end_pos;
    curwin->w_cursor = save_pos;
  } else {
    end_pos = curwin->w_cursor;         // shutup gcc 4
  }

  // Disable 'hlsearch' highlighting if the pattern matches
  // everything. Avoids a flash when typing "foo\|".
  if (!use_last_pat) {
    next_char = ccline.cmdbuff[skiplen + patlen];
    ccline.cmdbuff[skiplen + patlen] = NUL;
    if (empty_pattern(ccline.cmdbuff + skiplen, search_delim) && !no_hlsearch) {
      redraw_all_later(UPD_SOME_VALID);
      set_no_hlsearch(true);
    }
    ccline.cmdbuff[skiplen + patlen] = next_char;
  }

  validate_cursor(curwin);

  // May redraw the status line to show the cursor position.
  if (p_ru && (curwin->w_status_height > 0 || global_stl_height() > 0)) {
    curwin->w_redr_status = true;
  }

  redraw_later(curwin, UPD_SOME_VALID);
  update_screen();
  highlight_match = false;
  restore_last_search_pattern();

  // Leave it at the end to make CTRL-R CTRL-W work.  But not when beyond the
  // end of the pattern, e.g. for ":s/pat/".
  if (ccline.cmdbuff[skiplen + patlen] != NUL) {
    curwin->w_cursor = s->search_start;
  } else if (found != 0) {
    curwin->w_cursor = end_pos;
  }

  msg_starthere();
  redrawcmdline();
  s->did_incsearch = true;
}

// When CTRL-L typed: add character from the match to the pattern.
// May set "*c" to the added character.
// Return OK when calling command_line_not_changed.
static int may_add_char_to_search(int firstc, int *c, incsearch_state_T *s)
  FUNC_ATTR_NONNULL_ALL
{
  int skiplen, patlen;
  int search_delim;

  // Parsing range may already set the last search pattern.
  // NOTE: must call restore_last_search_pattern() before returning!
  save_last_search_pattern();

  // Add a character from under the cursor for 'incsearch'
  if (!do_incsearch_highlighting(firstc, &search_delim, s, &skiplen,
                                 &patlen)) {
    restore_last_search_pattern();
    return FAIL;
  }
  restore_last_search_pattern();

  if (s->did_incsearch) {
    curwin->w_cursor = s->match_end;
    *c = gchar_cursor();
    if (*c != NUL) {
      // If 'ignorecase' and 'smartcase' are set and the
      // command line has no uppercase characters, convert
      // the character to lowercase
      if (p_ic && p_scs
          && !pat_has_uppercase(ccline.cmdbuff + skiplen)) {
        *c = mb_tolower(*c);
      }
      if (*c == search_delim
          || vim_strchr((magic_isset() ? "\\~^$.*[" : "\\^$"), *c) != NULL) {
        // put a backslash before special characters
        stuffcharReadbuff(*c);
        *c = '\\';
      }
      return FAIL;
    }
  }
  return OK;
}

static void finish_incsearch_highlighting(bool gotesc, incsearch_state_T *s,
                                          bool call_update_screen)
{
  if (!s->did_incsearch) {
    return;
  }

  s->did_incsearch = false;
  if (gotesc) {
    curwin->w_cursor = s->save_cursor;
  } else {
    if (!equalpos(s->save_cursor, s->search_start)) {
      // put the '" mark at the original position
      curwin->w_cursor = s->save_cursor;
      setpcmark();
    }
    curwin->w_cursor = s->search_start;
  }
  restore_viewstate(curwin, &s->old_viewstate);
  highlight_match = false;

  // by default search all lines
  search_first_line = 0;
  search_last_line = MAXLNUM;

  magic_overruled = s->magic_overruled_save;

  validate_cursor(curwin);          // needed for TAB
  status_redraw_all();
  redraw_all_later(UPD_SOME_VALID);
  if (call_update_screen) {
    update_screen();
  }
}

/// Initialize the current command-line info.
static void init_ccline(int firstc, int indent)
{
  ccline.overstrike = false;                // always start in insert mode

  assert(indent >= 0);

  // set some variables for redrawcmd()
  ccline.cmdfirstc = (firstc == '@' ? 0 : firstc);
  ccline.cmdindent = (firstc > 0 ? indent : 0);

  // alloc initial ccline.cmdbuff
  alloc_cmdbuff(indent + 50);
  ccline.cmdlen = ccline.cmdpos = 0;
  ccline.cmdbuff[0] = NUL;

  ccline.last_colors = (ColoredCmdline){ .cmdbuff = NULL,
                                         .colors = KV_INITIAL_VALUE };
  sb_text_start_cmdline();

  // autoindent for :insert and :append
  if (firstc <= 0) {
    memset(ccline.cmdbuff, ' ', (size_t)indent);
    ccline.cmdbuff[indent] = NUL;
    ccline.cmdpos = indent;
    ccline.cmdspos = indent;
    ccline.cmdlen = indent;
  }
}

/// Internal entry point for cmdline mode.
///
/// @param count  only used for incremental search
/// @param indent  indent for inside conditionals
/// @param clear_ccline  clear ccline first
static uint8_t *command_line_enter(int firstc, int count, int indent, bool clear_ccline)
{
  // can be invoked recursively, identify each level
  static int cmdline_level = 0;
  cmdline_level++;

  bool save_cmdpreview = cmdpreview;
  cmdpreview = false;
  CommandLineState state = {
    .firstc = firstc,
    .count = count,
    .indent = indent,
    .save_msg_scroll = msg_scroll,
    .save_State = State,
    .ignore_drag_release = true,
  };
  CommandLineState *s = &state;
  s->save_p_icm = xstrdup(p_icm);
  init_incsearch_state(&s->is_state);
  CmdlineInfo save_ccline;
  bool did_save_ccline = false;

  if (ccline.cmdbuff != NULL) {
    // Currently ccline can never be in use if clear_ccline is false.
    // Some changes will be needed if this is no longer the case.
    assert(clear_ccline);
    // Being called recursively.  Since ccline is global, we need to save
    // the current buffer and restore it when returning.
    save_cmdline(&save_ccline);
    did_save_ccline = true;
  } else if (clear_ccline) {
    CLEAR_FIELD(ccline);
  }

  if (s->firstc == -1) {
    s->firstc = NUL;
    s->break_ctrl_c = true;
  }

  init_ccline(s->firstc, s->indent);
  ccline.prompt_id = last_prompt_id++;
  ccline.level = cmdline_level;

  if (cmdline_level == 50) {
    // Somehow got into a loop recursively calling getcmdline(), bail out.
    emsg(_(e_command_too_recursive));
    goto theend;
  }

  ExpandInit(&s->xpc);
  ccline.xpc = &s->xpc;

  cmdmsg_rl = (curwin->w_p_rl && *curwin->w_p_rlc == 's'
               && (s->firstc == '/' || s->firstc == '?'));

  msg_grid_validate();

  redir_off = true;             // don't redirect the typed command
  if (!cmd_silent) {
    gotocmdline(true);
    redrawcmdprompt();          // draw prompt or indent
    ccline.cmdspos = cmd_startcol();
    if (!msg_scroll) {
      msg_ext_clear(false);
    }
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

  State = MODE_CMDLINE;

  if (s->firstc == '/' || s->firstc == '?' || s->firstc == '@') {
    // Use ":lmap" mappings for search pattern and input().
    if (curbuf->b_p_imsearch == B_IMODE_USE_INSERT) {
      s->b_im_ptr = &curbuf->b_p_iminsert;
    } else {
      s->b_im_ptr = &curbuf->b_p_imsearch;
    }
    s->b_im_ptr_buf = curbuf;
    if (*s->b_im_ptr == B_IMODE_LMAP) {
      State |= MODE_LANGMAP;
    }
  }

  setmouse();
  setcursor();

  TryState tstate;
  Error err = ERROR_INIT;
  bool tl_ret = true;
  char firstcbuf[2];
  firstcbuf[0] = (char)(firstc > 0 ? firstc : '-');
  firstcbuf[1] = 0;

  if (has_event(EVENT_CMDLINEENTER)) {
    save_v_event_T save_v_event;
    dict_T *dict = get_v_event(&save_v_event);

    // set v:event to a dictionary with information about the commandline
    tv_dict_add_str(dict, S_LEN("cmdtype"), firstcbuf);
    tv_dict_add_nr(dict, S_LEN("cmdlevel"), ccline.level);
    tv_dict_set_keys_readonly(dict);
    try_enter(&tstate);

    apply_autocmds(EVENT_CMDLINEENTER, firstcbuf, firstcbuf, false, curbuf);
    restore_v_event(dict, &save_v_event);

    tl_ret = try_leave(&tstate, &err);
    if (!tl_ret && ERROR_SET(&err)) {
      msg_putchar('\n');
      msg_scroll = true;
      msg_puts_attr(err.msg, HL_ATTR(HLF_E)|MSG_HIST);
      api_clear_error(&err);
      redrawcmd();
    }
    tl_ret = true;
  }
  may_trigger_modechanged();

  init_history();
  s->hiscnt = get_hislen();  // set hiscnt to impossible history value
  s->histype = hist_char2type(s->firstc);
  do_digraph(-1);                       // init digraph typeahead

  // If something above caused an error, reset the flags, we do want to type
  // and execute commands. Display may be messed up a bit.
  if (did_emsg) {
    redrawcmd();
  }

  // Redraw the statusline in case it uses the current mode using the mode()
  // function.
  if (!cmd_silent && !exmode_active) {
    bool found_one = false;

    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (*p_stl != NUL || *wp->w_p_stl != NUL || *p_wbr != NUL || *wp->w_p_wbr != NUL) {
        wp->w_redr_status = true;
        found_one = true;
      }
    }

    if (*p_tal != NUL) {
      redraw_tabline = true;
      found_one = true;
    }

    if (found_one) {
      redraw_statuslines();
    }
  }

  did_emsg = false;
  got_int = false;
  s->state.check = command_line_check;
  s->state.execute = command_line_execute;

  state_enter(&s->state);

  if (has_event(EVENT_CMDLINELEAVE)) {
    save_v_event_T save_v_event;
    dict_T *dict = get_v_event(&save_v_event);

    tv_dict_add_str(dict, S_LEN("cmdtype"), firstcbuf);
    tv_dict_add_nr(dict, S_LEN("cmdlevel"), ccline.level);
    tv_dict_set_keys_readonly(dict);
    // not readonly:
    tv_dict_add_bool(dict, S_LEN("abort"),
                     s->gotesc ? kBoolVarTrue : kBoolVarFalse);
    try_enter(&tstate);
    apply_autocmds(EVENT_CMDLINELEAVE, firstcbuf, firstcbuf, false, curbuf);
    // error printed below, to avoid redraw issues
    tl_ret = try_leave(&tstate, &err);
    if (tv_dict_get_number(dict, "abort") != 0) {
      s->gotesc = true;
    }
    restore_v_event(dict, &save_v_event);
  }

  cmdmsg_rl = false;

  // We could have reached here without having a chance to clean up wild menu
  // if certain special keys like <Esc> or <C-\> were used as wildchar. Make
  // sure to still clean up to avoid memory corruption.
  if (cmdline_pum_active()) {
    cmdline_pum_remove();
  }
  wildmenu_cleanup(&ccline);
  s->did_wild_list = false;
  s->wim_index = 0;

  ExpandCleanup(&s->xpc);
  ccline.xpc = NULL;

  finish_incsearch_highlighting(s->gotesc, &s->is_state, false);

  if (ccline.cmdbuff != NULL) {
    // Put line in history buffer (":" and "=" only when it was typed).
    if (s->histype != HIST_INVALID
        && ccline.cmdlen
        && s->firstc != NUL
        && (s->some_key_typed || s->histype == HIST_SEARCH)) {
      size_t cmdbufflen = strlen(ccline.cmdbuff);
      add_to_history(s->histype, ccline.cmdbuff, cmdbufflen, true,
                     s->histype == HIST_SEARCH ? s->firstc : NUL);
      if (s->firstc == ':') {
        xfree(new_last_cmdline);
        new_last_cmdline = xstrnsave(ccline.cmdbuff, cmdbufflen);
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
  if (p_ch == 0 && !ui_has(kUIMessages)) {
    set_must_redraw(UPD_VALID);
  }
  msg_scroll = s->save_msg_scroll;
  redir_off = false;

  if (!tl_ret && ERROR_SET(&err)) {
    msg_putchar('\n');
    emsg(err.msg);
    did_emsg = false;
    api_clear_error(&err);
  }

  // When the command line was typed, no need for a wait-return prompt.
  if (s->some_key_typed && tl_ret) {
    need_wait_return = false;
  }

  set_option_direct(kOptInccommand, CSTR_AS_OPTVAL(s->save_p_icm), 0, SID_NONE);
  State = s->save_State;
  if (cmdpreview != save_cmdpreview) {
    cmdpreview = save_cmdpreview;  // restore preview state
    redraw_all_later(UPD_SOME_VALID);
  }
  may_trigger_modechanged();
  setmouse();
  sb_text_end_cmdline();

theend:
  xfree(s->save_p_icm);
  xfree(ccline.last_colors.cmdbuff);
  kv_destroy(ccline.last_colors.colors);

  char *p = ccline.cmdbuff;

  if (ui_has(kUICmdline)) {
    ui_call_cmdline_hide(ccline.level);
    msg_ext_clear_later();
  }
  if (!cmd_silent) {
    status_redraw_all();  // redraw to show mode change
  }

  cmdline_level--;

  if (did_save_ccline) {
    restore_cmdline(&save_ccline);
  } else {
    ccline.cmdbuff = NULL;
  }

  return (uint8_t *)p;
}

static int command_line_check(VimState *state)
{
  CommandLineState *s = (CommandLineState *)state;

  redir_off = true;        // Don't redirect the typed command.
  // Repeated, because a ":redir" inside
  // completion may switch it on.
  quit_more = false;       // reset after CTRL-D which had a more-prompt

  did_emsg = false;        // There can't really be a reason why an error
                           // that occurs while typing a command should
                           // cause the command not to be executed.

  // Trigger SafeState if nothing is pending.
  may_trigger_safestate(s->xpc.xp_numfiles <= 0);

  cursorcmd();             // set the cursor on the right spot
  ui_cursor_shape();
  return 1;
}

/// Handle CTRL-\ pressed in Command-line mode:
/// - CTRL-\ CTRL-N or CTRL-\ CTRL-G goes to Normal mode.
/// - CTRL-\ e prompts for an expression.
static int command_line_handle_ctrl_bsl(CommandLineState *s)
{
  no_mapping++;
  allow_keys++;
  s->c = plain_vgetc();
  no_mapping--;
  allow_keys--;

  // CTRL-\ e doesn't work when obtaining an expression, unless it
  // is in a mapping.
  if (s->c != Ctrl_N
      && s->c != Ctrl_G
      && (s->c != 'e'
          || (ccline.cmdfirstc == '=' && KeyTyped)
          || cmdline_star > 0)) {
    vungetc(s->c);
    return PROCESS_NEXT_KEY;
  }

  if (s->c == 'e') {
    // Replace the command line with the result of an expression.
    // This will call getcmdline() recursively in get_expr_register().
    if (ccline.cmdpos == ccline.cmdlen) {
      new_cmdpos = 99999;           // keep it at the end
    } else {
      new_cmdpos = ccline.cmdpos;
    }

    s->c = get_expr_register();
    if (s->c == '=') {
      // Evaluate the expression.  Set "textlock" to avoid nasty things
      // like going to another buffer.
      textlock++;
      char *p = get_expr_line();
      textlock--;

      if (p != NULL) {
        int len = (int)strlen(p);
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
        return CMDLINE_CHANGED;
      }
    }
    beep_flush();
    got_int = false;                // don't abandon the command line
    did_emsg = false;
    emsg_on_display = false;
    redrawcmd();
    return CMDLINE_NOT_CHANGED;
  }

  s->gotesc = true;  // will free ccline.cmdbuff after putting it in history
  return GOTO_NORMAL_MODE;
}

/// Completion for 'wildchar' or 'wildcharm' key.
/// - hitting <ESC> twice means: abandon command line.
/// - wildcard expansion is only done when the 'wildchar' key is really
///   typed, not when it comes from a macro
/// @return  CMDLINE_CHANGED if command line is changed or CMDLINE_NOT_CHANGED.
static int command_line_wildchar_complete(CommandLineState *s)
{
  int res;
  int options = WILD_NO_BEEP;
  if (wim_flags[s->wim_index] & WIM_BUFLASTUSED) {
    options |= WILD_BUFLASTUSED;
  }
  if (s->xpc.xp_numfiles > 0) {       // typed p_wc at least twice
    // if 'wildmode' contains "list" may still need to list
    if (s->xpc.xp_numfiles > 1
        && !s->did_wild_list
        && ((wim_flags[s->wim_index] & WIM_LIST)
            || (p_wmnu && (wim_flags[s->wim_index] & WIM_FULL) != 0))) {
      showmatches(&s->xpc, p_wmnu && ((wim_flags[s->wim_index] & WIM_LIST) == 0));
      redrawcmd();
      s->did_wild_list = true;
    }

    if (wim_flags[s->wim_index] & WIM_LONGEST) {
      res = nextwild(&s->xpc, WILD_LONGEST, options, s->firstc != '@');
    } else if (wim_flags[s->wim_index] & WIM_FULL) {
      res = nextwild(&s->xpc, WILD_NEXT, options, s->firstc != '@');
    } else {
      res = OK;                 // don't insert 'wildchar' now
    }
  } else {                    // typed p_wc first time
    s->wim_index = 0;
    int j = ccline.cmdpos;

    // if 'wildmode' first contains "longest", get longest
    // common part
    if (wim_flags[0] & WIM_LONGEST) {
      res = nextwild(&s->xpc, WILD_LONGEST, options, s->firstc != '@');
    } else {
      res = nextwild(&s->xpc, WILD_EXPAND_KEEP, options, s->firstc != '@');
    }

    // if interrupted while completing, behave like it failed
    if (got_int) {
      vpeekc();               // remove <C-C> from input stream
      got_int = false;              // don't abandon the command line
      ExpandOne(&s->xpc, NULL, NULL, 0, WILD_FREE);
      s->xpc.xp_context = EXPAND_NOTHING;
      return CMDLINE_CHANGED;
    }

    // when more than one match, and 'wildmode' first contains
    // "list", or no change and 'wildmode' contains "longest,list",
    // list all matches
    if (res == OK && s->xpc.xp_numfiles > 1) {
      // a "longest" that didn't do anything is skipped (but not
      // "list:longest")
      if (wim_flags[0] == WIM_LONGEST && ccline.cmdpos == j) {
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

        showmatches(&s->xpc, p_wmnu && ((wim_flags[s->wim_index] & WIM_LIST) == 0));
        redrawcmd();
        s->did_wild_list = true;

        if (wim_flags[s->wim_index] & WIM_LONGEST) {
          nextwild(&s->xpc, WILD_LONGEST, options, s->firstc != '@');
        } else if (wim_flags[s->wim_index] & WIM_FULL) {
          nextwild(&s->xpc, WILD_NEXT, options, s->firstc != '@');
        }
      } else {
        vim_beep(BO_WILD);
      }
    } else if (s->xpc.xp_numfiles == -1) {
      s->xpc.xp_context = EXPAND_NOTHING;
    }
  }

  if (s->wim_index < 3) {
    s->wim_index++;
  }

  if (s->c == ESC) {
    s->gotesc = true;
  }

  return (res == OK) ? CMDLINE_CHANGED : CMDLINE_NOT_CHANGED;
}

static void command_line_end_wildmenu(CommandLineState *s)
{
  if (cmdline_pum_active()) {
    cmdline_pum_remove();
  }
  if (s->xpc.xp_numfiles != -1) {
    ExpandOne(&s->xpc, NULL, NULL, 0, WILD_FREE);
  }
  s->did_wild_list = false;
  if (!p_wmnu || (s->c != K_UP && s->c != K_DOWN)) {
    s->xpc.xp_context = EXPAND_NOTHING;
  }
  s->wim_index = 0;
  wildmenu_cleanup(&ccline);
}

static int command_line_execute(VimState *state, int key)
{
  if (key == K_IGNORE || key == K_NOP) {
    return -1;  // get another key
  }

  disptick_T display_tick_saved = display_tick;
  CommandLineState *s = (CommandLineState *)state;
  s->c = key;

  if (s->c == K_EVENT || s->c == K_COMMAND || s->c == K_LUA) {
    if (s->c == K_EVENT) {
      state_handle_k_event();
    } else if (s->c == K_COMMAND) {
      do_cmdline(NULL, getcmdkeycmd, NULL, DOCMD_NOWAIT);
    } else {
      map_execute_lua(false);
    }
    // Re-apply 'incsearch' highlighting in case it was cleared.
    if (display_tick > display_tick_saved && s->is_state.did_incsearch) {
      may_do_incsearch_highlighting(s->firstc, s->count, &s->is_state);
    }

    // nvim_select_popupmenu_item() can be called from the handling of
    // K_EVENT, K_COMMAND, or K_LUA.
    if (pum_want.active) {
      if (cmdline_pum_active()) {
        nextwild(&s->xpc, WILD_PUM_WANT, 0, s->firstc != '@');
        if (pum_want.finish) {
          nextwild(&s->xpc, WILD_APPLY, WILD_NO_BEEP, s->firstc != '@');
          command_line_end_wildmenu(s);
        }
      }
      pum_want.active = false;
    }

    if (!cmdline_was_last_drawn) {
      redrawcmdline();
    }
    return 1;
  }

  if (KeyTyped) {
    s->some_key_typed = true;

    if (cmdmsg_rl && !KeyStuffed) {
      // Invert horizontal movements and operations.  Only when
      // typed by the user directly, not when the result of a
      // mapping.
      switch (s->c) {
      case K_RIGHT:
        s->c = K_LEFT; break;
      case K_S_RIGHT:
        s->c = K_S_LEFT; break;
      case K_C_RIGHT:
        s->c = K_C_LEFT; break;
      case K_LEFT:
        s->c = K_RIGHT; break;
      case K_S_LEFT:
        s->c = K_S_RIGHT; break;
      case K_C_LEFT:
        s->c = K_C_RIGHT; break;
      }
    }
  }

  // Ignore got_int when CTRL-C was typed here.
  // Don't ignore it in :global, we really need to break then, e.g., for
  // ":g/pat/normal /pat" (without the <CR>).
  // Don't ignore it for the input() function.
  if ((s->c == Ctrl_C)
      && s->firstc != '@'
      // do clear got_int in Ex mode to avoid infinite Ctrl-C loop
      && (!s->break_ctrl_c || exmode_active)
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
    XFREE_CLEAR(s->lookfor);
  }

  // When there are matching completions to select <S-Tab> works like
  // CTRL-P (unless 'wc' is <S-Tab>).
  if (s->c != p_wc && s->c == K_S_TAB && s->xpc.xp_numfiles > 0) {
    s->c = Ctrl_P;
  }

  if (p_wmnu) {
    s->c = wildmenu_translate_key(&ccline, s->c, &s->xpc, s->did_wild_list);
  }

  int wild_type = 0;
  const bool key_is_wc = (s->c == p_wc && KeyTyped) || s->c == p_wcm;
  if ((cmdline_pum_active() || s->did_wild_list) && !key_is_wc) {
    // Ctrl-Y: Accept the current selection and close the popup menu.
    // Ctrl-E: cancel the cmdline popup menu and return the original text.
    if (s->c == Ctrl_E || s->c == Ctrl_Y) {
      wild_type = (s->c == Ctrl_E) ? WILD_CANCEL : WILD_APPLY;
      nextwild(&s->xpc, wild_type, WILD_NO_BEEP, s->firstc != '@');
    }
  }

  // The wildmenu is cleared if the pressed key is not used for
  // navigating the wild menu (i.e. the key is not 'wildchar' or
  // 'wildcharm' or Ctrl-N or Ctrl-P or Ctrl-A or Ctrl-L).
  // If the popup menu is displayed, then PageDown and PageUp keys are
  // also used to navigate the menu.
  bool end_wildmenu = (!key_is_wc && s->c != Ctrl_Z
                       && s->c != Ctrl_N && s->c != Ctrl_P && s->c != Ctrl_A
                       && s->c != Ctrl_L);
  end_wildmenu = end_wildmenu && (!cmdline_pum_active()
                                  || (s->c != K_PAGEDOWN && s->c != K_PAGEUP
                                      && s->c != K_KPAGEDOWN && s->c != K_KPAGEUP));

  // free expanded names when finished walking through matches
  if (end_wildmenu) {
    command_line_end_wildmenu(s);
  }

  if (p_wmnu) {
    s->c = wildmenu_process_key(&ccline, s->c, &s->xpc);
  }

  // CTRL-\ CTRL-N or CTRL-\ CTRL-G goes to Normal mode,
  // CTRL-\ e prompts for an expression.
  if (s->c == Ctrl_BSL) {
    switch (command_line_handle_ctrl_bsl(s)) {
    case CMDLINE_CHANGED:
      return command_line_changed(s);
    case CMDLINE_NOT_CHANGED:
      return command_line_not_changed(s);
    case GOTO_NORMAL_MODE:
      return 0;                   // back to cmd mode
    default:
      s->c = Ctrl_BSL;            // backslash key not processed by
                                  // command_line_handle_ctrl_bsl()
    }
  }

  if (s->c == cedit_key || s->c == K_CMDWIN) {
    // TODO(vim): why is ex_normal_busy checked here?
    if ((s->c == K_CMDWIN || ex_normal_busy == 0)
        && got_int == false) {
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
        if (!ui_has(kUICmdline)) {
          msg_cursor_goto(msg_row, 0);
        }
        ui_flush();
      }
      return 0;
    }
  }

  // Completion for 'wildchar' or 'wildcharm' key.
  if ((s->c == p_wc && !s->gotesc && KeyTyped) || s->c == p_wcm || s->c == Ctrl_Z) {
    if (command_line_wildchar_complete(s) == CMDLINE_CHANGED) {
      return command_line_changed(s);
    }
  }

  s->gotesc = false;

  // <S-Tab> goes to last match, in a clumsy way
  if (s->c == K_S_TAB && KeyTyped) {
    if (nextwild(&s->xpc, WILD_EXPAND_KEEP, 0, s->firstc != '@') == OK) {
      if (s->xpc.xp_numfiles > 1
          && ((!s->did_wild_list && (wim_flags[s->wim_index] & WIM_LIST)) || p_wmnu)) {
        // Trigger the popup menu when wildoptions=pum
        showmatches(&s->xpc, p_wmnu && ((wim_flags[s->wim_index] & WIM_LIST) == 0));
      }
      nextwild(&s->xpc, WILD_PREV, 0, s->firstc != '@');
      nextwild(&s->xpc, WILD_PREV, 0, s->firstc != '@');
      return command_line_changed(s);
    }
  }

  if (s->c == NUL || s->c == K_ZERO) {
    // NUL is stored as NL
    s->c = NL;
  }

  s->do_abbr = true;             // default: check for abbreviation

  // If already used to cancel/accept wildmenu, don't process the key further.
  if (wild_type == WILD_CANCEL || wild_type == WILD_APPLY) {
    return command_line_not_changed(s);
  }

  return command_line_handle_key(s);
}

// May adjust 'incsearch' highlighting for typing CTRL-G and CTRL-T, go to next
// or previous match.
// Returns FAIL when calling command_line_not_changed.
static int may_do_command_line_next_incsearch(int firstc, int count, incsearch_state_T *s,
                                              bool next_match)
  FUNC_ATTR_NONNULL_ALL
{
  int skiplen, patlen, search_delim;

  // Parsing range may already set the last search pattern.
  // NOTE: must call restore_last_search_pattern() before returning!
  save_last_search_pattern();

  if (!do_incsearch_highlighting(firstc, &search_delim, s, &skiplen,
                                 &patlen)) {
    restore_last_search_pattern();
    return OK;
  }
  if (patlen == 0 && ccline.cmdbuff[skiplen] == NUL) {
    restore_last_search_pattern();
    return FAIL;
  }

  ui_busy_start();
  ui_flush();

  pos_T t;
  char *pat;
  int search_flags = SEARCH_NOOF;

  if (search_delim == ccline.cmdbuff[skiplen]) {
    pat = last_search_pattern();
    if (pat == NULL) {
      restore_last_search_pattern();
      return FAIL;
    }
    skiplen = 0;
    patlen = (int)strlen(pat);
  } else {
    pat = ccline.cmdbuff + skiplen;
  }

  if (next_match) {
    t = s->match_end;
    if (lt(s->match_start, s->match_end)) {
      // start searching at the end of the match
      // not at the beginning of the next column
      decl(&t);
    }
    search_flags += SEARCH_COL;
  } else {
    t = s->match_start;
  }
  if (!p_hls) {
    search_flags += SEARCH_KEEP;
  }
  emsg_off++;
  char save = pat[patlen];
  pat[patlen] = NUL;
  int found = searchit(curwin, curbuf, &t, NULL,
                       next_match ? FORWARD : BACKWARD,
                       pat, (size_t)patlen, count, search_flags,
                       RE_SEARCH, NULL);
  emsg_off--;
  pat[patlen] = save;
  ui_busy_stop();
  if (found) {
    s->search_start = s->match_start;
    s->match_end = t;
    s->match_start = t;
    if (!next_match && firstc != '?') {
      // move just before the current match, so that
      // when nv_search finishes the cursor will be
      // put back on the match
      s->search_start = t;
      decl(&s->search_start);
    } else if (next_match && firstc == '?') {
      // move just after the current match, so that
      // when nv_search finishes the cursor will be
      // put back on the match
      s->search_start = t;
      incl(&s->search_start);
    }
    if (lt(t, s->search_start) && next_match) {
      // wrap around
      s->search_start = t;
      if (firstc == '?') {
        incl(&s->search_start);
      } else {
        decl(&s->search_start);
      }
    }

    set_search_match(&s->match_end);
    curwin->w_cursor = s->match_start;
    changed_cline_bef_curs(curwin);
    update_topline(curwin);
    validate_cursor(curwin);
    highlight_match = true;
    save_viewstate(curwin, &s->old_viewstate);
    redraw_later(curwin, UPD_NOT_VALID);
    update_screen();
    highlight_match = false;
    redrawcmdline();
    curwin->w_cursor = s->match_end;
  } else {
    vim_beep(BO_ERROR);
  }
  restore_last_search_pattern();
  return FAIL;
}

/// Handle backspace, delete and CTRL-W keys in the command-line mode.
static int command_line_erase_chars(CommandLineState *s)
{
  if (s->c == K_KDEL) {
    s->c = K_DEL;
  }

  // Delete current character is the same as backspace on next
  // character, except at end of line
  if (s->c == K_DEL && ccline.cmdpos != ccline.cmdlen) {
    ccline.cmdpos++;
  }
  if (s->c == K_DEL) {
    ccline.cmdpos += mb_off_next(ccline.cmdbuff, ccline.cmdbuff + ccline.cmdpos);
  }

  if (ccline.cmdpos > 0) {
    int j = ccline.cmdpos;
    char *p = mb_prevptr(ccline.cmdbuff, ccline.cmdbuff + j);

    if (s->c == Ctrl_W) {
      while (p > ccline.cmdbuff && ascii_isspace(*p)) {
        p = mb_prevptr(ccline.cmdbuff, p);
      }

      int i = mb_get_class(p);
      while (p > ccline.cmdbuff && mb_get_class(p) == i) {
        p = mb_prevptr(ccline.cmdbuff, p);
      }

      if (mb_get_class(p) != i) {
        p += utfc_ptr2len(p);
      }
    }

    ccline.cmdpos = (int)(p - ccline.cmdbuff);
    ccline.cmdlen -= j - ccline.cmdpos;
    int i = ccline.cmdpos;

    while (i < ccline.cmdlen) {
      ccline.cmdbuff[i++] = ccline.cmdbuff[j++];
    }

    // Truncate at the end, required for multi-byte chars.
    ccline.cmdbuff[ccline.cmdlen] = NUL;
    if (ccline.cmdlen == 0) {
      s->is_state.search_start = s->is_state.save_cursor;
      // save view settings, so that the screen won't be restored at the
      // wrong position
      s->is_state.old_viewstate = s->is_state.init_viewstate;
    }
    redrawcmd();
  } else if (ccline.cmdlen == 0 && s->c != Ctrl_W
             && ccline.cmdprompt == NULL && s->indent == 0) {
    // In ex and debug mode it doesn't make sense to return.
    if (exmode_active || ccline.cmdfirstc == '>') {
      return CMDLINE_NOT_CHANGED;
    }

    XFREE_CLEAR(ccline.cmdbuff);        // no commandline to return
    if (!cmd_silent && !ui_has(kUICmdline)) {
      msg_col = 0;
      msg_putchar(' ');                             // delete ':'
    }
    s->is_state.search_start = s->is_state.save_cursor;
    redraw_cmdline = true;
    return GOTO_NORMAL_MODE;
  }
  return CMDLINE_CHANGED;
}

/// Handle the CTRL-^ key in the command-line mode and toggle the use of the
/// language :lmap mappings and/or Input Method.
static void command_line_toggle_langmap(CommandLineState *s)
{
  OptInt *b_im_ptr = buf_valid(s->b_im_ptr_buf) ? s->b_im_ptr : NULL;
  if (map_to_exists_mode("", MODE_LANGMAP, false)) {
    // ":lmap" mappings exists, toggle use of mappings.
    State ^= MODE_LANGMAP;
    if (b_im_ptr != NULL) {
      if (State & MODE_LANGMAP) {
        *b_im_ptr = B_IMODE_LMAP;
      } else {
        *b_im_ptr = B_IMODE_NONE;
      }
    }
  }

  if (b_im_ptr != NULL) {
    if (b_im_ptr == &curbuf->b_p_iminsert) {
      set_iminsert_global(curbuf);
    } else {
      set_imsearch_global(curbuf);
    }
  }
  ui_cursor_shape();                // may show different cursor shape
  // Show/unshow value of 'keymap' in status lines later.
  status_redraw_curbuf();
}

/// Handle the CTRL-R key in the command-line mode and insert the contents of a
/// numbered or named register.
static int command_line_insert_reg(CommandLineState *s)
{
  const int save_new_cmdpos = new_cmdpos;

  putcmdline('"', true);
  no_mapping++;
  allow_keys++;
  int i = s->c = plain_vgetc();      // CTRL-R <char>
  if (i == Ctrl_O) {
    i = Ctrl_R;                      // CTRL-R CTRL-O == CTRL-R CTRL-R
  }

  if (i == Ctrl_R) {
    s->c = plain_vgetc();              // CTRL-R CTRL-R <char>
  }
  no_mapping--;
  allow_keys--;
  // Insert the result of an expression.
  new_cmdpos = -1;
  if (s->c == '=') {
    if (ccline.cmdfirstc == '='   // can't do this recursively
        || cmdline_star > 0) {    // or when typing a password
      beep_flush();
      s->c = ESC;
    } else {
      s->c = get_expr_register();
    }
  }

  bool literally = false;
  if (s->c != ESC) {               // use ESC to cancel inserting register
    literally = i == Ctrl_R || is_literal_register(s->c);
    cmdline_paste(s->c, literally, false);

    // When there was a serious error abort getting the
    // command line.
    if (aborting()) {
      s->gotesc = true;              // will free ccline.cmdbuff after
                                     // putting it in history
      return GOTO_NORMAL_MODE;
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
  new_cmdpos = save_new_cmdpos;

  // remove the double quote
  ccline.special_char = NUL;
  redrawcmd();

  // With "literally": the command line has already changed.
  // Else: the text has been stuffed, but the command line didn't change yet.
  return literally ? CMDLINE_CHANGED : CMDLINE_NOT_CHANGED;
}

/// Handle the Left and Right mouse clicks in the command-line mode.
static void command_line_left_right_mouse(CommandLineState *s)
{
  if (s->c == K_LEFTRELEASE || s->c == K_RIGHTRELEASE) {
    s->ignore_drag_release = true;
  } else {
    s->ignore_drag_release = false;
  }

  ccline.cmdspos = cmd_startcol();
  for (ccline.cmdpos = 0; ccline.cmdpos < ccline.cmdlen;
       ccline.cmdpos++) {
    int cells = cmdline_charsize(ccline.cmdpos);
    if (mouse_row <= cmdline_row + ccline.cmdspos / Columns
        && mouse_col < ccline.cmdspos % Columns + cells) {
      break;
    }

    // Count ">" for double-wide char that doesn't fit.
    correct_screencol(ccline.cmdpos, cells, &ccline.cmdspos);
    ccline.cmdpos += utfc_ptr2len(ccline.cmdbuff + ccline.cmdpos) - 1;
    ccline.cmdspos += cells;
  }
}

static void command_line_next_histidx(CommandLineState *s, bool next_match)
{
  int j = (int)strlen(s->lookfor);
  while (true) {
    // one step backwards
    if (!next_match) {
      if (s->hiscnt == get_hislen()) {
        // first time
        s->hiscnt = *get_hisidx(s->histype);
      } else if (s->hiscnt == 0 && *get_hisidx(s->histype) != get_hislen() - 1) {
        s->hiscnt = get_hislen() - 1;
      } else if (s->hiscnt != *get_hisidx(s->histype) + 1) {
        s->hiscnt--;
      } else {
        // at top of list
        s->hiscnt = s->save_hiscnt;
        break;
      }
    } else {          // one step forwards
      // on last entry, clear the line
      if (s->hiscnt == *get_hisidx(s->histype)) {
        s->hiscnt = get_hislen();
        break;
      }

      // not on a history line, nothing to do
      if (s->hiscnt == get_hislen()) {
        break;
      }

      if (s->hiscnt == get_hislen() - 1) {
        // wrap around
        s->hiscnt = 0;
      } else {
        s->hiscnt++;
      }
    }

    if (s->hiscnt < 0 || get_histentry(s->histype)[s->hiscnt].hisstr == NULL) {
      s->hiscnt = s->save_hiscnt;
      break;
    }

    if ((s->c != K_UP && s->c != K_DOWN)
        || s->hiscnt == s->save_hiscnt
        || strncmp(get_histentry(s->histype)[s->hiscnt].hisstr,
                   s->lookfor, (size_t)j) == 0) {
      break;
    }
  }
}

/// Handle the Up, Down, Page Up, Page down, CTRL-N and CTRL-P key in the
/// command-line mode.
static int command_line_browse_history(CommandLineState *s)
{
  if (s->histype == HIST_INVALID || get_hislen() == 0 || s->firstc == NUL) {
    // no history
    return CMDLINE_NOT_CHANGED;
  }

  s->save_hiscnt = s->hiscnt;

  // save current command string so it can be restored later
  if (s->lookfor == NULL) {
    s->lookfor = xstrdup(ccline.cmdbuff);
    s->lookfor[ccline.cmdpos] = NUL;
  }

  bool next_match = (s->c == K_DOWN || s->c == K_S_DOWN || s->c == Ctrl_N
                     || s->c == K_PAGEDOWN || s->c == K_KPAGEDOWN);
  command_line_next_histidx(s, next_match);

  if (s->hiscnt != s->save_hiscnt) {
    // jumped to other entry
    char *p;
    int old_firstc;

    XFREE_CLEAR(ccline.cmdbuff);
    s->xpc.xp_context = EXPAND_NOTHING;
    if (s->hiscnt == get_hislen()) {
      p = s->lookfor;                  // back to the old one
    } else {
      p = get_histentry(s->histype)[s->hiscnt].hisstr;
    }

    if (s->histype == HIST_SEARCH
        && p != s->lookfor
        && (old_firstc = (uint8_t)p[strlen(p) + 1]) != s->firstc) {
      int len = 0;
      // Correct for the separator character used when
      // adding the history entry vs the one used now.
      // First loop: count length.
      // Second loop: copy the characters.
      for (int i = 0; i <= 1; i++) {
        len = 0;
        for (int j = 0; p[j] != NUL; j++) {
          // Replace old sep with new sep, unless it is
          // escaped.
          if (p[j] == old_firstc
              && (j == 0 || p[j - 1] != '\\')) {
            if (i > 0) {
              ccline.cmdbuff[len] = (char)s->firstc;
            }
          } else {
            // Escape new sep, unless it is already
            // escaped.
            if (p[j] == s->firstc
                && (j == 0 || p[j - 1] != '\\')) {
              if (i > 0) {
                ccline.cmdbuff[len] = '\\';
              }
              len++;
            }

            if (i > 0) {
              ccline.cmdbuff[len] = p[j];
            }
          }
          len++;
        }

        if (i == 0) {
          alloc_cmdbuff(len);
        }
      }
      ccline.cmdbuff[len] = NUL;
    } else {
      alloc_cmdbuff((int)strlen(p));
      STRCPY(ccline.cmdbuff, p);
    }

    ccline.cmdpos = ccline.cmdlen = (int)strlen(ccline.cmdbuff);
    redrawcmd();
    return CMDLINE_CHANGED;
  }
  beep_flush();
  return CMDLINE_NOT_CHANGED;
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
    switch (command_line_erase_chars(s)) {
    case CMDLINE_NOT_CHANGED:
      return command_line_not_changed(s);
    case GOTO_NORMAL_MODE:
      return 0;  // back to cmd mode
    default:
      return command_line_changed(s);
    }

  case K_INS:
  case K_KINS:
    ccline.overstrike = !ccline.overstrike;
    ui_cursor_shape();                // may show different cursor shape
    may_trigger_modechanged();
    status_redraw_curbuf();
    redraw_statuslines();
    return command_line_not_changed(s);

  case Ctrl_HAT:
    command_line_toggle_langmap(s);
    return command_line_not_changed(s);

  case Ctrl_U: {
    // delete all characters left of the cursor
    int j = ccline.cmdpos;
    ccline.cmdlen -= j;
    int i = ccline.cmdpos = 0;
    while (i < ccline.cmdlen) {
      ccline.cmdbuff[i++] = ccline.cmdbuff[j++];
    }

    // Truncate at the end, required for multi-byte chars.
    ccline.cmdbuff[ccline.cmdlen] = NUL;
    if (ccline.cmdlen == 0) {
      s->is_state.search_start = s->is_state.save_cursor;
    }
    redrawcmd();
    return command_line_changed(s);
  }

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
    switch (command_line_insert_reg(s)) {
    case GOTO_NORMAL_MODE:
      return 0;  // back to cmd mode
    case CMDLINE_CHANGED:
      return command_line_changed(s);
    default:
      return command_line_not_changed(s);
    }

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

      int cells = cmdline_charsize(ccline.cmdpos);
      if (KeyTyped && ccline.cmdspos + cells >= Columns * Rows) {
        break;
      }

      ccline.cmdspos += cells;
      ccline.cmdpos += utfc_ptr2len(ccline.cmdbuff + ccline.cmdpos);
    } while ((s->c == K_S_RIGHT || s->c == K_C_RIGHT
              || (mod_mask & (MOD_MASK_SHIFT|MOD_MASK_CTRL)))
             && ccline.cmdbuff[ccline.cmdpos] != ' ');
    ccline.cmdspos = cmd_screencol(ccline.cmdpos);
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

    ccline.cmdspos = cmd_screencol(ccline.cmdpos);
    if (ccline.special_char != NUL) {
      putcmdline(ccline.special_char, ccline.special_shift);
    }

    return command_line_not_changed(s);

  case K_IGNORE:
    // Ignore mouse event or open_cmdwin() result.
    return command_line_not_changed(s);

  case K_MIDDLEDRAG:
  case K_MIDDLERELEASE:
    return command_line_not_changed(s);                 // Ignore mouse

  case K_MIDDLEMOUSE:
    cmdline_paste(eval_has_provider("clipboard", false) ? '*' : 0, true, true);
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
    command_line_left_right_mouse(s);
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
  case K_MOUSEMOVE:
    return command_line_not_changed(s);

  case K_SELECT:          // end of Select mode mapping - ignore
    return command_line_not_changed(s);

  case Ctrl_B:            // begin of command line
  case K_HOME:
  case K_KHOME:
  case K_S_HOME:
  case K_C_HOME:
    ccline.cmdpos = 0;
    ccline.cmdspos = cmd_startcol();
    return command_line_not_changed(s);

  case Ctrl_E:            // end of command line
  case K_END:
  case K_KEND:
  case K_S_END:
  case K_C_END:
    ccline.cmdpos = ccline.cmdlen;
    ccline.cmdspos = cmd_screencol(ccline.cmdpos);
    return command_line_not_changed(s);

  case Ctrl_A:            // all matches
    if (cmdline_pum_active()) {
      // As Ctrl-A completes all the matches, close the popup
      // menu (if present)
      cmdline_pum_cleanup(&ccline);
    }

    if (nextwild(&s->xpc, WILD_ALL, 0, s->firstc != '@') == FAIL) {
      break;
    }
    s->xpc.xp_context = EXPAND_NOTHING;
    s->did_wild_list = false;
    return command_line_changed(s);

  case Ctrl_L:
    if (may_add_char_to_search(s->firstc, &s->c, &s->is_state) == OK) {
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
      const int wild_type = (s->c == Ctrl_P) ? WILD_PREV : WILD_NEXT;
      if (nextwild(&s->xpc, wild_type, 0, s->firstc != '@') == FAIL) {
        break;
      }
      return command_line_changed(s);
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
    if (cmdline_pum_active()
        && (s->c == K_PAGEUP || s->c == K_PAGEDOWN
            || s->c == K_KPAGEUP || s->c == K_KPAGEDOWN)) {
      // If the popup menu is displayed, then PageUp and PageDown
      // are used to scroll the menu.
      const int wild_type =
        (s->c == K_PAGEDOWN || s->c == K_KPAGEDOWN) ? WILD_PAGEDOWN : WILD_PAGEUP;
      if (nextwild(&s->xpc, wild_type, 0, s->firstc != '@') == FAIL) {
        break;
      }
      return command_line_changed(s);
    } else {
      switch (command_line_browse_history(s)) {
      case CMDLINE_CHANGED:
        return command_line_changed(s);
      case GOTO_NORMAL_MODE:
        return 0;
      default:
        return command_line_not_changed(s);
      }
    }

  case Ctrl_G:  // next match
  case Ctrl_T:  // previous match
    if (may_do_command_line_next_incsearch(s->firstc, s->count, &s->is_state,
                                           s->c == Ctrl_G) == FAIL) {
      return command_line_not_changed(s);
    }
    break;

  case Ctrl_V:
  case Ctrl_Q:
    s->ignore_drag_release = true;
    putcmdline('^', true);

    // Get next (two) characters.
    // Do not include modifiers into the key for CTRL-SHIFT-V.
    s->c = get_literal(mod_mask & MOD_MASK_SHIFT);

    s->do_abbr = false;                   // don't do abbreviation now
    ccline.special_char = NUL;
    // may need to remove ^ when composing char was typed
    if (utf_iscomposing(s->c) && !cmd_silent) {
      if (ui_has(kUICmdline)) {
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
    ccline.special_char = NUL;

    if (s->c != NUL) {
      break;
    }

    redrawcmd();
    return command_line_not_changed(s);

  case Ctrl__:            // CTRL-_: switch language mode
    if (!p_ari) {
      break;
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
      && (ccheck_abbr((s->c >= 0x100) ? (s->c + ABBR_OFF) : s->c)
          || s->c == Ctrl_RSB)) {
    return command_line_changed(s);
  }

  // put the character in the command line
  if (IS_SPECIAL(s->c) || mod_mask != 0) {
    put_on_cmdline(get_special_key_name(s->c, mod_mask), -1, true);
  } else {
    int j = utf_char2bytes(s->c, IObuff);
    IObuff[j] = NUL;                // exclude composing chars
    put_on_cmdline(IObuff, j, true);
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
  if (!s->is_state.incsearch_postponed) {
    return 1;
  }
  return command_line_changed(s);
}

/// Guess that the pattern matches everything.  Only finds specific cases, such
/// as a trailing \|, which can happen while typing a pattern.
static bool empty_pattern(char *p, int delim)
{
  size_t n = strlen(p);
  magic_T magic_val = MAGIC_ON;

  if (n > 0) {
    skip_regexp_ex(p, delim, magic_isset(), NULL, NULL, &magic_val);
  } else {
    return true;
  }

  return empty_pattern_magic(p, n, magic_val);
}

static bool empty_pattern_magic(char *p, size_t len, magic_T magic_val)
{
  // remove trailing \v and the like
  while (len >= 2 && p[len - 2] == '\\'
         && vim_strchr("mMvVcCZ", (uint8_t)p[len - 1]) != NULL) {
    len -= 2;
  }

  // true, if the pattern is empty, or the pattern ends with \| and magic is
  // set (or it ends with '|' and very magic is set)
  return len == 0 || (len > 1
                      && ((p[len - 2] == '\\'
                           && p[len - 1] == '|' && magic_val == MAGIC_ON)
                          || (p[len - 2] != '\\'
                              && p[len - 1] == '|' && magic_val == MAGIC_ALL)));
}

handle_T cmdpreview_get_bufnr(void)
{
  return cmdpreview_bufnr;
}

int cmdpreview_get_ns(void)
{
  return cmdpreview_ns;
}

/// Sets up command preview buffer.
///
/// @return Pointer to command preview buffer if succeeded, NULL if failed.
static buf_T *cmdpreview_open_buf(void)
{
  buf_T *cmdpreview_buf = cmdpreview_bufnr ? buflist_findnr(cmdpreview_bufnr) : NULL;

  // If preview buffer doesn't exist, open one.
  if (cmdpreview_buf == NULL) {
    Error err = ERROR_INIT;
    handle_T bufnr = nvim_create_buf(false, true, &err);

    if (ERROR_SET(&err)) {
      return NULL;
    }

    cmdpreview_buf = buflist_findnr(bufnr);
  }

  // Preview buffer cannot preview itself!
  if (cmdpreview_buf == curbuf) {
    return NULL;
  }

  // Rename preview buffer.
  aco_save_T aco;
  aucmd_prepbuf(&aco, cmdpreview_buf);
  int retv = rename_buffer("[Preview]");
  aucmd_restbuf(&aco);

  if (retv == FAIL) {
    return NULL;
  }

  // Temporarily switch to preview buffer to set it up for previewing.
  aucmd_prepbuf(&aco, cmdpreview_buf);
  buf_clear();
  curbuf->b_p_ma = true;
  curbuf->b_p_ul = -1;
  curbuf->b_p_tw = 0;  // Reset 'textwidth' (was set by ftplugin)
  aucmd_restbuf(&aco);
  cmdpreview_bufnr = cmdpreview_buf->handle;

  return cmdpreview_buf;
}

/// Open command preview window if it's not already open.
/// Returns to original window after opening command preview window.
///
/// @param cmdpreview_buf Pointer to command preview buffer
///
/// @return Pointer to command preview window if succeeded, NULL if failed.
static win_T *cmdpreview_open_win(buf_T *cmdpreview_buf)
  FUNC_ATTR_NONNULL_ALL
{
  win_T *save_curwin = curwin;

  // Open preview window.
  if (win_split((int)p_cwh, WSP_BOT) == FAIL) {
    return NULL;
  }

  win_T *preview_win = curwin;
  Error err = ERROR_INIT;

  // Switch to preview buffer
  try_start();
  int result = do_buffer(DOBUF_GOTO, DOBUF_FIRST, FORWARD, cmdpreview_buf->handle, 0);
  if (try_end(&err) || result == FAIL) {
    api_clear_error(&err);
    return NULL;
  }

  curwin->w_p_cul = false;
  curwin->w_p_cuc = false;
  curwin->w_p_spell = false;
  curwin->w_p_fen = false;

  win_enter(save_curwin, false);
  return preview_win;
}

/// Closes any open command preview windows.
static void cmdpreview_close_win(void)
{
  buf_T *buf = cmdpreview_bufnr ? buflist_findnr(cmdpreview_bufnr) : NULL;
  if (buf != NULL) {
    close_windows(buf, false);
  }
}

/// Save the undo state of a buffer for command preview.
static void cmdpreview_save_undo(CpUndoInfo *cp_undoinfo, buf_T *buf)
  FUNC_ATTR_NONNULL_ALL
{
  cp_undoinfo->save_b_u_synced = buf->b_u_synced;
  cp_undoinfo->save_b_u_oldhead = buf->b_u_oldhead;
  cp_undoinfo->save_b_u_newhead = buf->b_u_newhead;
  cp_undoinfo->save_b_u_curhead = buf->b_u_curhead;
  cp_undoinfo->save_b_u_numhead = buf->b_u_numhead;
  cp_undoinfo->save_b_u_seq_last = buf->b_u_seq_last;
  cp_undoinfo->save_b_u_save_nr_last = buf->b_u_save_nr_last;
  cp_undoinfo->save_b_u_seq_cur = buf->b_u_seq_cur;
  cp_undoinfo->save_b_u_time_cur = buf->b_u_time_cur;
  cp_undoinfo->save_b_u_save_nr_cur = buf->b_u_save_nr_cur;
  cp_undoinfo->save_b_u_line_ptr = buf->b_u_line_ptr;
  cp_undoinfo->save_b_u_line_lnum = buf->b_u_line_lnum;
  cp_undoinfo->save_b_u_line_colnr = buf->b_u_line_colnr;
}

/// Restore the undo state of a buffer for command preview.
static void cmdpreview_restore_undo(const CpUndoInfo *cp_undoinfo, buf_T *buf)
{
  buf->b_u_oldhead = cp_undoinfo->save_b_u_oldhead;
  buf->b_u_newhead = cp_undoinfo->save_b_u_newhead;
  buf->b_u_curhead = cp_undoinfo->save_b_u_curhead;
  buf->b_u_numhead = cp_undoinfo->save_b_u_numhead;
  buf->b_u_seq_last = cp_undoinfo->save_b_u_seq_last;
  buf->b_u_save_nr_last = cp_undoinfo->save_b_u_save_nr_last;
  buf->b_u_seq_cur = cp_undoinfo->save_b_u_seq_cur;
  buf->b_u_time_cur = cp_undoinfo->save_b_u_time_cur;
  buf->b_u_save_nr_cur = cp_undoinfo->save_b_u_save_nr_cur;
  buf->b_u_line_ptr = cp_undoinfo->save_b_u_line_ptr;
  buf->b_u_line_lnum = cp_undoinfo->save_b_u_line_lnum;
  buf->b_u_line_colnr = cp_undoinfo->save_b_u_line_colnr;
  if (buf->b_u_curhead == NULL) {
    buf->b_u_synced = cp_undoinfo->save_b_u_synced;
  }
}

/// Save current state and prepare windows and buffers for command preview.
static void cmdpreview_prepare(CpInfo *cpinfo)
  FUNC_ATTR_NONNULL_ALL
{
  Set(ptr_t) saved_bufs = SET_INIT;

  kv_init(cpinfo->buf_info);
  kv_init(cpinfo->win_info);

  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    buf_T *buf = win->w_buffer;

    // Don't save state of command preview buffer or preview window.
    if (buf->handle == cmdpreview_bufnr) {
      continue;
    }

    if (!set_has(ptr_t, &saved_bufs, buf)) {
      CpBufInfo cp_bufinfo;
      cp_bufinfo.buf = buf;
      cp_bufinfo.save_b_p_ul = buf->b_p_ul;
      cp_bufinfo.save_b_changed = buf->b_changed;
      cp_bufinfo.save_b_op_start = buf->b_op_start;
      cp_bufinfo.save_b_op_end = buf->b_op_end;
      cp_bufinfo.save_changedtick = buf_get_changedtick(buf);
      cmdpreview_save_undo(&cp_bufinfo.undo_info, buf);
      kv_push(cpinfo->buf_info, cp_bufinfo);
      set_put(ptr_t, &saved_bufs, buf);

      u_clearall(buf);
      buf->b_p_ul = INT_MAX;  // Make sure we can undo all changes
    }

    CpWinInfo cp_wininfo;
    cp_wininfo.win = win;

    // Save window cursor position and viewstate
    cp_wininfo.save_w_cursor = win->w_cursor;
    save_viewstate(win, &cp_wininfo.save_viewstate);

    // Save 'cursorline' and 'cursorcolumn'
    cp_wininfo.save_w_p_cul = win->w_p_cul;
    cp_wininfo.save_w_p_cuc = win->w_p_cuc;

    kv_push(cpinfo->win_info, cp_wininfo);

    win->w_p_cul = false;       // Disable 'cursorline' so it doesn't mess up the highlights
    win->w_p_cuc = false;       // Disable 'cursorcolumn' so it doesn't mess up the highlights
  }

  set_destroy(ptr_t, &saved_bufs);

  cpinfo->save_hls = p_hls;
  cpinfo->save_cmdmod = cmdmod;
  win_size_save(&cpinfo->save_view);
  save_search_patterns();

  p_hls = false;                 // Don't show search highlighting during live substitution
  cmdmod.cmod_split = 0;         // Disable :leftabove/botright modifiers
  cmdmod.cmod_tab = 0;           // Disable :tab modifier
  cmdmod.cmod_flags |= CMOD_NOSWAPFILE;  // Disable swap for preview buffer

  u_sync(true);
}

/// Restore the state of buffers and windows for command preview.
static void cmdpreview_restore_state(CpInfo *cpinfo)
  FUNC_ATTR_NONNULL_ALL
{
  for (size_t i = 0; i < cpinfo->buf_info.size; i++) {
    CpBufInfo cp_bufinfo = cpinfo->buf_info.items[i];
    buf_T *buf = cp_bufinfo.buf;

    buf->b_changed = cp_bufinfo.save_b_changed;

    // Clear preview highlights.
    extmark_clear(buf, (uint32_t)cmdpreview_ns, 0, 0, MAXLNUM, MAXCOL);

    if (buf->b_u_seq_cur != cp_bufinfo.undo_info.save_b_u_seq_cur) {
      int count = 0;

      // Calculate how many undo steps are necessary to restore earlier state.
      for (u_header_T *uhp = buf->b_u_curhead ? buf->b_u_curhead : buf->b_u_newhead;
           uhp != NULL;
           uhp = uhp->uh_next.ptr, ++count) {}

      aco_save_T aco;
      aucmd_prepbuf(&aco, buf);
      // Ensure all the entries will be undone
      if (curbuf->b_u_synced == false) {
        u_sync(true);
      }
      // Undo invisibly. This also moves the cursor!
      if (!u_undo_and_forget(count, false)) {
        abort();
      }
      aucmd_restbuf(&aco);
    }

    u_blockfree(buf);
    cmdpreview_restore_undo(&cp_bufinfo.undo_info, buf);

    buf->b_op_start = cp_bufinfo.save_b_op_start;
    buf->b_op_end = cp_bufinfo.save_b_op_end;

    if (cp_bufinfo.save_changedtick != buf_get_changedtick(buf)) {
      buf_set_changedtick(buf, cp_bufinfo.save_changedtick);
    }

    buf->b_p_ul = cp_bufinfo.save_b_p_ul;        // Restore 'undolevels'
  }

  for (size_t i = 0; i < cpinfo->win_info.size; i++) {
    CpWinInfo cp_wininfo = cpinfo->win_info.items[i];
    win_T *win = cp_wininfo.win;

    // Restore window cursor position and viewstate
    win->w_cursor = cp_wininfo.save_w_cursor;
    restore_viewstate(win, &cp_wininfo.save_viewstate);

    // Restore 'cursorline' and 'cursorcolumn'
    win->w_p_cul = cp_wininfo.save_w_p_cul;
    win->w_p_cuc = cp_wininfo.save_w_p_cuc;

    update_topline(win);
  }

  cmdmod = cpinfo->save_cmdmod;                // Restore cmdmod
  p_hls = cpinfo->save_hls;                    // Restore 'hlsearch'
  restore_search_patterns();           // Restore search patterns
  win_size_restore(&cpinfo->save_view);        // Restore window sizes

  ga_clear(&cpinfo->save_view);
  kv_destroy(cpinfo->win_info);
  kv_destroy(cpinfo->buf_info);
}

/// Show 'inccommand' preview if command is previewable. It works like this:
///    1. Store current undo information so we can revert to current state later.
///    2. Execute the preview callback with the parsed command, preview buffer number and preview
///       namespace number as arguments. The preview callback sets the highlight and does the
///       changes required for the preview if needed.
///    3. Preview callback returns 0, 1 or 2. 0 means no preview is shown. 1 means preview is shown
///       but preview window doesn't need to be opened. 2 means preview is shown and preview window
///       needs to be opened if inccommand=split.
///    4. Use the return value of the preview callback to determine whether to
///       open the preview window or not and open preview window if needed.
///    5. If the return value of the preview callback is not 0, update the screen while the effects
///       of the preview are still in place.
///    6. Revert all changes made by the preview callback.
///
/// @return whether preview is shown or not.
static bool cmdpreview_may_show(CommandLineState *s)
{
  // Parse the command line and return if it fails.
  exarg_T ea;
  CmdParseInfo cmdinfo;
  // Copy the command line so we can modify it.
  int cmdpreview_type = 0;
  char *cmdline = xstrdup(ccline.cmdbuff);
  const char *errormsg = NULL;
  emsg_off++;  // Block errors when parsing the command line, and don't update v:errmsg
  if (!parse_cmdline(cmdline, &ea, &cmdinfo, &errormsg)) {
    emsg_off--;
    goto end;
  }
  emsg_off--;

  // Check if command is previewable, if not, don't attempt to show preview
  if (!(ea.argt & EX_PREVIEW)) {
    undo_cmdmod(&cmdinfo.cmdmod);
    goto end;
  }

  // Flush now: external cmdline may itself wish to update the screen which is
  // currently disallowed during cmdpreview(no longer needed in case that changes).
  cmdline_ui_flush();

  // Swap invalid command range if needed
  if ((ea.argt & EX_RANGE) && ea.line1 > ea.line2) {
    linenr_T lnum = ea.line1;
    ea.line1 = ea.line2;
    ea.line2 = lnum;
  }

  CpInfo cpinfo;
  bool icm_split = *p_icm == 's';  // inccommand=split
  buf_T *cmdpreview_buf = NULL;
  win_T *cmdpreview_win = NULL;

  emsg_silent++;                 // Block error reporting as the command may be incomplete,
                                 // but still update v:errmsg
  msg_silent++;                  // Block messages, namely ones that prompt
  block_autocmds();              // Block events

  // Save current state and prepare for command preview.
  cmdpreview_prepare(&cpinfo);

  // Open preview buffer if inccommand=split.
  if (icm_split && (cmdpreview_buf = cmdpreview_open_buf()) == NULL) {
    // Failed to create preview buffer, so disable preview.
    set_option_direct(kOptInccommand, STATIC_CSTR_AS_OPTVAL("nosplit"), 0, SID_NONE);
    icm_split = false;
  }
  // Setup preview namespace if it's not already set.
  if (!cmdpreview_ns) {
    cmdpreview_ns = (int)nvim_create_namespace((String)STRING_INIT);
  }

  // Set cmdpreview state.
  cmdpreview = true;

  // Execute the preview callback and use its return value to determine whether to show preview or
  // open the preview window. The preview callback also handles doing the changes and highlights for
  // the preview.
  Error err = ERROR_INIT;
  try_start();
  cmdpreview_type = execute_cmd(&ea, &cmdinfo, true);
  if (try_end(&err)) {
    api_clear_error(&err);
    cmdpreview_type = 0;
  }

  // If inccommand=split and preview callback returns 2, open preview window.
  if (icm_split && cmdpreview_type == 2
      && (cmdpreview_win = cmdpreview_open_win(cmdpreview_buf)) == NULL) {
    // If there's not enough room to open the preview window, just preview without the window.
    cmdpreview_type = 1;
  }

  // If preview callback return value is nonzero, update screen now.
  if (cmdpreview_type != 0) {
    int save_rd = RedrawingDisabled;
    RedrawingDisabled = 0;
    update_screen();
    RedrawingDisabled = save_rd;
  }

  // Close preview window if it's open.
  if (icm_split && cmdpreview_type == 2 && cmdpreview_win != NULL) {
    cmdpreview_close_win();
  }

  // Restore state.
  cmdpreview_restore_state(&cpinfo);

  unblock_autocmds();                  // Unblock events
  msg_silent--;                        // Unblock messages
  emsg_silent--;                       // Unblock error reporting
  redrawcmdline();
end:
  xfree(cmdline);
  return cmdpreview_type != 0;
}

/// Trigger CmdlineChanged autocommands.
static void do_autocmd_cmdlinechanged(int firstc)
{
  if (has_event(EVENT_CMDLINECHANGED)) {
    TryState tstate;
    Error err = ERROR_INIT;
    save_v_event_T save_v_event;
    dict_T *dict = get_v_event(&save_v_event);

    char firstcbuf[2];
    firstcbuf[0] = (char)firstc;
    firstcbuf[1] = 0;

    // set v:event to a dictionary with information about the commandline
    tv_dict_add_str(dict, S_LEN("cmdtype"), firstcbuf);
    tv_dict_add_nr(dict, S_LEN("cmdlevel"), ccline.level);
    tv_dict_set_keys_readonly(dict);
    try_enter(&tstate);

    apply_autocmds(EVENT_CMDLINECHANGED, firstcbuf, firstcbuf, false, curbuf);
    restore_v_event(dict, &save_v_event);

    bool tl_ret = try_leave(&tstate, &err);
    if (!tl_ret && ERROR_SET(&err)) {
      msg_putchar('\n');
      msg_scroll = true;
      msg_puts_attr(err.msg, HL_ATTR(HLF_E)|MSG_HIST);
      api_clear_error(&err);
      redrawcmd();
    }
  }
}

static int command_line_changed(CommandLineState *s)
{
  // Trigger CmdlineChanged autocommands.
  do_autocmd_cmdlinechanged(s->firstc > 0 ? s->firstc : '-');

  const bool prev_cmdpreview = cmdpreview;
  if (s->firstc == ':'
      && current_sctx.sc_sid == 0    // only if interactive
      && *p_icm != NUL       // 'inccommand' is set
      && !exmode_active      // not in ex mode
      && curbuf->b_p_ma      // buffer is modifiable
      && cmdline_star == 0   // not typing a password
      && !vpeekc_any()
      && cmdpreview_may_show(s)) {
    // 'inccommand' preview has been shown.
  } else {
    cmdpreview = false;
    if (prev_cmdpreview) {
      // TODO(bfredl): add an immediate redraw flag for cmdline mode which will trigger
      // at next wait-for-input
      update_screen();  // Clear 'inccommand' preview.
    }
    if (s->xpc.xp_context == EXPAND_NOTHING && (KeyTyped || vpeekc() == NUL)) {
      may_do_incsearch_highlighting(s->firstc, s->count, &s->is_state);
    }
  }

  if (p_arshape && !p_tbidi) {
    // Always redraw the whole command line to fix shaping and
    // right-left typing.  Not efficient, but it works.
    // Do it only when there are no characters left to read
    // to avoid useless intermediate redraws.
    // if cmdline is external the ui handles shaping, no redraw needed.
    if (!ui_has(kUICmdline) && vpeekc() == NUL) {
      redrawcmd();
    }
  }

  return 1;
}

/// Abandon the command line.
static void abandon_cmdline(void)
{
  XFREE_CLEAR(ccline.cmdbuff);
  ccline.redraw_state = kCmdRedrawNone;
  if (msg_scrolled == 0) {
    compute_cmdrow();
  }
  msg("", 0);
  redraw_cmdline = true;
}

/// getcmdline() - accept a command line starting with firstc.
///
/// firstc == ':'            get ":" command line.
/// firstc == '/' or '?'     get search pattern
/// firstc == '='            get expression
/// firstc == '@'            get text for input() function
/// firstc == '>'            get text for debug mode
/// firstc == NUL            get text for :insert command
/// firstc == -1             like NUL, and break on CTRL-C
///
/// The line is collected in ccline.cmdbuff, which is reallocated to fit the
/// command line.
///
/// Careful: getcmdline() can be called recursively!
///
/// Return pointer to allocated string if there is a commandline, NULL
/// otherwise.
///
/// @param count  only used for incremental search
/// @param indent  indent for inside conditionals
char *getcmdline(int firstc, int count, int indent, bool do_concat FUNC_ATTR_UNUSED)
{
  return (char *)command_line_enter(firstc, count, indent, true);
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
char *getcmdline_prompt(const int firstc, const char *const prompt, const int attr,
                        const int xp_context, const char *const xp_arg,
                        const Callback highlight_callback)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
{
  const int msg_col_save = msg_col;

  CmdlineInfo save_ccline;
  bool did_save_ccline = false;
  if (ccline.cmdbuff != NULL) {
    // Save the values of the current cmdline and restore them below.
    save_cmdline(&save_ccline);
    did_save_ccline = true;
  } else {
    CLEAR_FIELD(ccline);
  }
  ccline.prompt_id = last_prompt_id++;
  ccline.cmdprompt = (char *)prompt;
  ccline.cmdattr = attr;
  ccline.xp_context = xp_context;
  ccline.xp_arg = (char *)xp_arg;
  ccline.input_fn = (firstc == '@');
  ccline.highlight_callback = highlight_callback;

  int msg_silent_saved = msg_silent;
  msg_silent = 0;

  char *const ret = (char *)command_line_enter(firstc, 1, 0, false);

  if (did_save_ccline) {
    restore_cmdline(&save_ccline);
  }
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

/// Read the 'wildmode' option, fill wim_flags[].
int check_opt_wim(void)
{
  uint8_t new_wim_flags[4];
  int i;
  int idx = 0;

  for (i = 0; i < 4; i++) {
    new_wim_flags[i] = 0;
  }

  for (char *p = p_wim; *p; p++) {
    // Note: Keep this in sync with p_wim_values.
    for (i = 0; ASCII_ISALPHA(p[i]); i++) {}
    if (p[i] != NUL && p[i] != ',' && p[i] != ':') {
      return FAIL;
    }
    if (i == 7 && strncmp(p, "longest", 7) == 0) {
      new_wim_flags[idx] |= WIM_LONGEST;
    } else if (i == 4 && strncmp(p, "full", 4) == 0) {
      new_wim_flags[idx] |= WIM_FULL;
    } else if (i == 4 && strncmp(p, "list", 4) == 0) {
      new_wim_flags[idx] |= WIM_LIST;
    } else if (i == 8 && strncmp(p, "lastused", 8) == 0) {
      new_wim_flags[idx] |= WIM_BUFLASTUSED;
    } else {
      return FAIL;
    }
    p += i;
    if (*p == NUL) {
      break;
    }
    if (*p == ',') {
      if (idx == 3) {
        return FAIL;
      }
      idx++;
    }
  }

  // fill remaining entries with last flag
  while (idx < 3) {
    new_wim_flags[idx + 1] = new_wim_flags[idx];
    idx++;
  }

  // only when there are no errors, wim_flags[] is changed
  for (i = 0; i < 4; i++) {
    wim_flags[i] = new_wim_flags[i];
  }
  return OK;
}

/// Return true when the text must not be changed and we can't switch to
/// another window or buffer.  True when editing the command line etc.
bool text_locked(void)
{
  if (cmdwin_type != 0) {
    return true;
  }
  if (expr_map_locked()) {
    return true;
  }
  return textlock != 0;
}

// Give an error message for a command that isn't allowed while the cmdline
// window is open or editing the cmdline in another way.
void text_locked_msg(void)
{
  emsg(_(get_text_locked_msg()));
}

const char *get_text_locked_msg(void)
{
  if (cmdwin_type != 0) {
    return e_cmdwin;
  } else {
    return e_textlock;
  }
}

/// Check for text, window or buffer locked.
/// Give an error message and return true if something is locked.
bool text_or_buf_locked(void)
{
  if (text_locked()) {
    text_locked_msg();
    return true;
  }
  return curbuf_locked();
}

/// Check if "curbuf->b_ro_locked" or "allbuf_lock" is set and
/// return true when it is and give an error message.
bool curbuf_locked(void)
{
  if (curbuf->b_ro_locked > 0) {
    emsg(_(e_cannot_edit_other_buf));
    return true;
  }
  return allbuf_locked();
}

// Check if "allbuf_lock" is set and return true when it is and give an error
// message.
bool allbuf_locked(void)
{
  if (allbuf_lock > 0) {
    emsg(_("E811: Not allowed to change buffer information now"));
    return true;
  }
  return false;
}

static int cmdline_charsize(int idx)
{
  if (cmdline_star > 0) {           // showing '*', always 1 position
    return 1;
  }
  return ptr2cells(ccline.cmdbuff + idx);
}

/// Compute the offset of the cursor on the command line for the prompt and
/// indent.
static int cmd_startcol(void)
{
  return ccline.cmdindent + ((ccline.cmdfirstc != NUL) ? 1 : 0);
}

/// Compute the column position for a byte position on the command line.
int cmd_screencol(int bytepos)
{
  int m;  // maximum column

  int col = cmd_startcol();
  if (KeyTyped) {
    m = Columns * Rows;
    if (m < 0) {        // overflow, Columns or Rows at weird value
      m = MAXCOL;
    }
  } else {
    m = MAXCOL;
  }

  for (int i = 0; i < ccline.cmdlen && i < bytepos;
       i += utfc_ptr2len(ccline.cmdbuff + i)) {
    int c = cmdline_charsize(i);
    // Count ">" for double-wide multi-byte char that doesn't fit.
    correct_screencol(i, c, &col);

    // If the cmdline doesn't fit, show cursor on last visible char.
    // Don't move the cursor itself, so we can still append.
    if ((col += c) >= m) {
      col -= c;
      break;
    }
  }
  return col;
}

/// Check if the character at "idx", which is "cells" wide, is a multi-byte
/// character that doesn't fit, so that a ">" must be displayed.
static void correct_screencol(int idx, int cells, int *col)
{
  if (utfc_ptr2len(ccline.cmdbuff + idx) > 1
      && utf_ptr2cells(ccline.cmdbuff + idx) > 1
      && (*col) % Columns + cells > Columns) {
    (*col)++;
  }
}

/// Get an Ex command line for the ":" command.
///
/// @param c  normally ':', NUL for ":append"
/// @param indent  indent for inside conditionals
char *getexline(int c, void *cookie, int indent, bool do_concat)
{
  // When executing a register, remove ':' that's in front of each line.
  if (exec_from_reg && vpeekc() == ':') {
    vgetc();
  }

  return getcmdline(c, 1, indent, do_concat);
}

bool cmdline_overstrike(void)
  FUNC_ATTR_PURE
{
  return ccline.overstrike;
}

/// Return true if the cursor is at the end of the cmdline.
bool cmdline_at_end(void)
  FUNC_ATTR_PURE
{
  return (ccline.cmdpos >= ccline.cmdlen);
}

// Allocate a new command line buffer.
// Assigns the new buffer to ccline.cmdbuff and ccline.cmdbufflen.
static void alloc_cmdbuff(int len)
{
  // give some extra space to avoid having to allocate all the time
  if (len < 80) {
    len = 100;
  } else {
    len += 20;
  }

  ccline.cmdbuff = xmalloc((size_t)len);
  ccline.cmdbufflen = len;
}

/// Re-allocate the command line to length len + something extra.
void realloc_cmdbuff(int len)
{
  if (len < ccline.cmdbufflen) {
    return;  // no need to resize
  }

  char *p = ccline.cmdbuff;
  alloc_cmdbuff(len);                   // will get some more
  // There isn't always a NUL after the command, but it may need to be
  // there, thus copy up to the NUL and add a NUL.
  memmove(ccline.cmdbuff, p, (size_t)ccline.cmdlen);
  ccline.cmdbuff[ccline.cmdlen] = NUL;
  xfree(p);

  if (ccline.xpc != NULL
      && ccline.xpc->xp_pattern != NULL
      && ccline.xpc->xp_context != EXPAND_NOTHING
      && ccline.xpc->xp_context != EXPAND_UNSUCCESSFUL) {
    int i = (int)(ccline.xpc->xp_pattern - p);

    // If xp_pattern points inside the old cmdbuff it needs to be adjusted
    // to point into the newly allocated memory.
    if (i >= 0 && i <= ccline.cmdlen) {
      ccline.xpc->xp_pattern = ccline.cmdbuff + i;
    }
  }
}

enum { MAX_CB_ERRORS = 1, };

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
  ParserLine parser_lines[] = {
    {
      .data = colored_ccline->cmdbuff,
      .size = strlen(colored_ccline->cmdbuff),
      .allocated = false,
    },
    { NULL, 0, false },
  };
  ParserLine *plines_p = parser_lines;
  ParserHighlight colors;
  kvi_init(colors);
  ParserState pstate;
  viml_parser_init(&pstate, parser_simple_get_line, &plines_p, &colors);
  ExprAST east = viml_pexpr_parse(&pstate, kExprFlagsDisallowEOC);
  viml_pexpr_free_ast(east);
  viml_parser_destroy(&pstate);
  kv_resize(ret_ccline_colors->colors, kv_size(colors));
  size_t prev_end = 0;
  for (size_t i = 0; i < kv_size(colors); i++) {
    const ParserHighlightChunk chunk = kv_A(colors, i);
    assert(chunk.start.col < INT_MAX);
    assert(chunk.end_col < INT_MAX);
    if (chunk.start.col != prev_end) {
      kv_push(ret_ccline_colors->colors, ((CmdlineColorChunk) {
        .start = (int)prev_end,
        .end = (int)chunk.start.col,
        .attr = 0,
      }));
    }
    const int id = syn_name2id(chunk.group);
    const int attr = (id == 0 ? 0 : syn_id2attr(id));
    kv_push(ret_ccline_colors->colors, ((CmdlineColorChunk) {
      .start = (int)chunk.start.col,
      .end = (int)chunk.end_col,
      .attr = attr,
    }));
    prev_end = chunk.end_col;
  }
  if (prev_end < (size_t)colored_ccline->cmdlen) {
    kv_push(ret_ccline_colors->colors, ((CmdlineColorChunk) {
      .start = (int)prev_end,
      .end = colored_ccline->cmdlen,
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
      && strcmp(ccline_colors->cmdbuff, colored_ccline->cmdbuff) == 0) {
    return ret;
  }

  kv_size(ccline_colors->colors) = 0;

  if (colored_ccline->cmdbuff == NULL || *colored_ccline->cmdbuff == NUL) {
    // Nothing to do, exiting.
    XFREE_CLEAR(ccline_colors->cmdbuff);
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
  const char *err_errmsg = e_intern2;
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
    err_errmsg = N_("E5408: Unable to get g:Nvim_color_cmdline callback: %s");
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
    arg.vval.v_string = xmemdupz(colored_ccline->cmdbuff, (size_t)colored_ccline->cmdlen);
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
    PRINT_ERRMSG("%s", _("E5400: Callback should return list"));
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
        .start = (int)prev_end,
        .end = (int)start,
        .attr = 0,
      }));
    }
    const varnumber_T end =
      tv_get_number_chk(TV_LIST_ITEM_TV(TV_LIST_ITEM_NEXT(l, tv_list_first(l))), &error);
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
    const char *const group = tv_get_string_chk(TV_LIST_ITEM_TV(tv_list_last(l)));
    if (group == NULL) {
      goto color_cmdline_error;
    }
    const int id = syn_name2id(group);
    const int attr = (id == 0 ? 0 : syn_id2attr(id));
    kv_push(ccline_colors->colors, ((CmdlineColorChunk) {
      .start = (int)start,
      .end = (int)end,
      .attr = attr,
    }));
    i++;
  });
  if (prev_end < colored_ccline->cmdlen) {
    kv_push(ccline_colors->colors, ((CmdlineColorChunk) {
      .start = (int)prev_end,
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
    ccline_colors->cmdbuff = arg.vval.v_string;
  } else {
    ccline_colors->cmdbuff = xmemdupz(colored_ccline->cmdbuff, (size_t)colored_ccline->cmdlen);
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

// Draw part of the cmdline at the current cursor position.  But draw stars
// when cmdline_star is true.
static void draw_cmdline(int start, int len)
{
  if (!color_cmdline(&ccline)) {
    return;
  }

  if (ui_has(kUICmdline)) {
    ccline.special_char = NUL;
    ccline.redraw_state = kCmdRedrawAll;
    return;
  }

  if (cmdline_star > 0) {
    for (int i = 0; i < len; i++) {
      msg_putchar('*');
      i += utfc_ptr2len(ccline.cmdbuff + start + i) - 1;
    }
  } else {
    if (kv_size(ccline.last_colors.colors)) {
      for (size_t i = 0; i < kv_size(ccline.last_colors.colors); i++) {
        CmdlineColorChunk chunk = kv_A(ccline.last_colors.colors, i);
        if (chunk.end <= start) {
          continue;
        }
        const int chunk_start = MAX(chunk.start, start);
        msg_outtrans_len(ccline.cmdbuff + chunk_start, chunk.end - chunk_start, chunk.attr);
      }
    } else {
      msg_outtrans_len(ccline.cmdbuff + start, len, 0);
    }
  }
}

static void ui_ext_cmdline_show(CmdlineInfo *line)
{
  Arena arena = ARENA_EMPTY;
  Array content;
  if (cmdline_star) {
    content = arena_array(&arena, 1);
    size_t len = 0;
    for (char *p = ccline.cmdbuff; *p; MB_PTR_ADV(p)) {
      len++;
    }
    char *buf = arena_alloc(&arena, len, false);
    memset(buf, '*', len);
    Array item = arena_array(&arena, 2);
    ADD_C(item, INTEGER_OBJ(0));
    ADD_C(item, STRING_OBJ(cbuf_as_string(buf, len)));
    ADD_C(content, ARRAY_OBJ(item));
  } else if (kv_size(line->last_colors.colors)) {
    content = arena_array(&arena, kv_size(line->last_colors.colors));
    for (size_t i = 0; i < kv_size(line->last_colors.colors); i++) {
      CmdlineColorChunk chunk = kv_A(line->last_colors.colors, i);
      Array item = arena_array(&arena, 2);
      ADD_C(item, INTEGER_OBJ(chunk.attr));

      assert(chunk.end >= chunk.start);
      ADD_C(item, STRING_OBJ(cbuf_as_string(line->cmdbuff + chunk.start,
                                            (size_t)(chunk.end - chunk.start))));
      ADD_C(content, ARRAY_OBJ(item));
    }
  } else {
    Array item = arena_array(&arena, 2);
    ADD_C(item, INTEGER_OBJ(0));
    ADD_C(item, CSTR_AS_OBJ(line->cmdbuff));
    content = arena_array(&arena, 1);
    ADD_C(content, ARRAY_OBJ(item));
  }
  char charbuf[2] = { (char)line->cmdfirstc, 0 };
  ui_call_cmdline_show(content, line->cmdpos,
                       cstr_as_string(charbuf),
                       cstr_as_string((line->cmdprompt)),
                       line->cmdindent,
                       line->level);
  if (line->special_char) {
    charbuf[0] = line->special_char;
    ui_call_cmdline_special_char(cstr_as_string(charbuf),
                                 line->special_shift,
                                 line->level);
  }
  arena_mem_free(arena_finish(&arena));
}

void ui_ext_cmdline_block_append(size_t indent, const char *line)
{
  char *buf = xmallocz(indent + strlen(line));
  memset(buf, ' ', indent);
  memcpy(buf + indent, line, strlen(line));

  Array item = ARRAY_DICT_INIT;
  ADD(item, INTEGER_OBJ(0));
  ADD(item, CSTR_AS_OBJ(buf));
  Array content = ARRAY_DICT_INIT;
  ADD(content, ARRAY_OBJ(item));
  ADD(cmdline_block, ARRAY_OBJ(content));
  if (cmdline_block.size > 1) {
    ui_call_cmdline_block_append(content);
  } else {
    ui_call_cmdline_block_show(cmdline_block);
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
  if (!ui_has(kUICmdline)) {
    return;
  }

  if (cmdline_block.size) {
    ui_call_cmdline_block_show(cmdline_block);
  }

  int prev_level = ccline.level - 1;
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

/// called by ui_flush, do what redraws necessary to keep cmdline updated.
void cmdline_ui_flush(void)
{
  if (!ui_has(kUICmdline)) {
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

// Put a character on the command line.  Shifts the following text to the
// right when "shift" is true.  Used for CTRL-V, CTRL-K, etc.
// "c" must be printable (fit in one display cell)!
void putcmdline(char c, bool shift)
{
  if (cmd_silent) {
    return;
  }
  if (!ui_has(kUICmdline)) {
    msg_no_more = true;
    msg_putchar(c);
    if (shift) {
      draw_cmdline(ccline.cmdpos, ccline.cmdlen - ccline.cmdpos);
    }
    msg_no_more = false;
  } else if (ccline.redraw_state != kCmdRedrawAll) {
    char charbuf[2] = { c, 0 };
    ui_call_cmdline_special_char(cstr_as_string(charbuf), shift,
                                 ccline.level);
  }
  cursorcmd();
  ccline.special_char = c;
  ccline.special_shift = shift;
  ui_cursor_shape();
}

/// Undo a putcmdline(c, false).
void unputcmdline(void)
{
  if (cmd_silent) {
    return;
  }
  msg_no_more = true;
  if (ccline.cmdlen == ccline.cmdpos && !ui_has(kUICmdline)) {
    msg_putchar(' ');
  } else {
    draw_cmdline(ccline.cmdpos, utfc_ptr2len(ccline.cmdbuff + ccline.cmdpos));
  }
  msg_no_more = false;
  cursorcmd();
  ccline.special_char = NUL;
  ui_cursor_shape();
}

// Put the given string, of the given length, onto the command line.
// If len is -1, then strlen() is used to calculate the length.
// If 'redraw' is true then the new part of the command line, and the remaining
// part will be redrawn, otherwise it will not.  If this function is called
// twice in a row, then 'redraw' should be false and redrawcmd() should be
// called afterwards.
void put_on_cmdline(const char *str, int len, bool redraw)
{
  int i;
  int m;
  int c;

  if (len < 0) {
    len = (int)strlen(str);
  }

  realloc_cmdbuff(ccline.cmdlen + len + 1);

  if (!ccline.overstrike) {
    memmove(ccline.cmdbuff + ccline.cmdpos + len,
            ccline.cmdbuff + ccline.cmdpos,
            (size_t)(ccline.cmdlen - ccline.cmdpos));
    ccline.cmdlen += len;
  } else {
    // Count nr of characters in the new string.
    m = 0;
    for (i = 0; i < len; i += utfc_ptr2len(str + i)) {
      m++;
    }
    // Count nr of bytes in cmdline that are overwritten by these
    // characters.
    for (i = ccline.cmdpos; i < ccline.cmdlen && m > 0;
         i += utfc_ptr2len(ccline.cmdbuff + i)) {
      m--;
    }
    if (i < ccline.cmdlen) {
      memmove(ccline.cmdbuff + ccline.cmdpos + len,
              ccline.cmdbuff + i, (size_t)(ccline.cmdlen - i));
      ccline.cmdlen += ccline.cmdpos + len - i;
    } else {
      ccline.cmdlen = ccline.cmdpos + len;
    }
  }
  memmove(ccline.cmdbuff + ccline.cmdpos, str, (size_t)len);
  ccline.cmdbuff[ccline.cmdlen] = NUL;

  {
    // When the inserted text starts with a composing character,
    // backup to the character before it.  There could be two of them.
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
      } else {
        i = 0;
      }
    }
    if (i != 0) {
      // Also backup the cursor position.
      i = ptr2cells(ccline.cmdbuff + ccline.cmdpos);
      ccline.cmdspos -= i;
      msg_col -= i;
      if (msg_col < 0) {
        msg_col += Columns;
        msg_row--;
      }
    }
  }

  if (redraw && !cmd_silent) {
    msg_no_more = true;
    i = cmdline_row;
    cursorcmd();
    draw_cmdline(ccline.cmdpos, ccline.cmdlen - ccline.cmdpos);
    // Avoid clearing the rest of the line too often.
    if (cmdline_row != i || ccline.overstrike) {
      msg_clr_eos();
    }
    msg_no_more = false;
  }
  if (KeyTyped) {
    m = Columns * Rows;
    if (m < 0) {            // overflow, Columns or Rows at weird value
      m = MAXCOL;
    }
  } else {
    m = MAXCOL;
  }
  for (i = 0; i < len; i++) {
    c = cmdline_charsize(ccline.cmdpos);
    // count ">" for a double-wide char that doesn't fit.
    correct_screencol(ccline.cmdpos, c, &ccline.cmdspos);
    // Stop cursor at the end of the screen, but do increment the
    // insert position, so that entering a very long command
    // works, even though you can't see it.
    if (ccline.cmdspos + c < m) {
      ccline.cmdspos += c;
    }
    c = utfc_ptr2len(ccline.cmdbuff + ccline.cmdpos) - 1;
    if (c > len - i - 1) {
      c = len - i - 1;
    }
    ccline.cmdpos += c;
    i += c;
    ccline.cmdpos++;
  }

  if (redraw) {
    msg_check();
  }
}

/// Save ccline, because obtaining the "=" register may execute "normal :cmd"
/// and overwrite it.
static void save_cmdline(CmdlineInfo *ccp)
{
  *ccp = ccline;
  CLEAR_FIELD(ccline);
  ccline.prev_ccline = ccp;
  ccline.cmdbuff = NULL;  // signal that ccline is not in use
}

/// Restore ccline after it has been saved with save_cmdline().
static void restore_cmdline(CmdlineInfo *ccp)
  FUNC_ATTR_NONNULL_ALL
{
  ccline = *ccp;
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
  char *arg;
  bool allocated;

  // check for valid regname; also accept special characters for CTRL-R in
  // the command line
  if (regname != Ctrl_F && regname != Ctrl_P && regname != Ctrl_W
      && regname != Ctrl_A && regname != Ctrl_L
      && !valid_yank_reg(regname, false)) {
    return FAIL;
  }

  // A register containing CTRL-R can cause an endless loop.  Allow using
  // CTRL-C to break the loop.
  line_breakcheck();
  if (got_int) {
    return FAIL;
  }

  // Need to  set "textlock" to avoid nasty things like going to another
  // buffer when evaluating an expression.
  textlock++;
  const bool i = get_spec_reg(regname, &arg, &allocated, true);
  textlock--;

  if (i) {
    // Got the value of a special register in "arg".
    if (arg == NULL) {
      return FAIL;
    }

    // When 'incsearch' is set and CTRL-R CTRL-W used: skip the duplicate
    // part of the word.
    char *p = arg;
    if (p_is && regname == Ctrl_W) {
      char *w;
      int len;

      // Locate start of last word in the cmd buffer.
      for (w = ccline.cmdbuff + ccline.cmdpos; w > ccline.cmdbuff;) {
        len = utf_head_off(ccline.cmdbuff, w - 1) + 1;
        if (!vim_iswordc(utf_ptr2char(w - len))) {
          break;
        }
        w -= len;
      }
      len = (int)((ccline.cmdbuff + ccline.cmdpos) - w);
      if (p_ic ? STRNICMP(w, arg, len) == 0 : strncmp(w, arg, (size_t)len) == 0) {
        p += len;
      }
    }

    cmdline_paste_str(p, literally);
    if (allocated) {
      xfree(arg);
    }
    return OK;
  }

  return cmdline_paste_reg(regname, literally, remcr);
}

// Put a string on the command line.
// When "literally" is true, insert literally.
// When "literally" is false, insert as typed, but don't leave the command
// line.
void cmdline_paste_str(const char *s, bool literally)
{
  if (literally) {
    put_on_cmdline(s, -1, true);
  } else {
    while (*s != NUL) {
      int cv = (uint8_t)(*s);
      if (cv == Ctrl_V && s[1]) {
        s++;
      }
      int c = mb_cptr2char_adv(&s);
      if (cv == Ctrl_V || c == ESC || c == Ctrl_C
          || c == CAR || c == NL || c == Ctrl_L
          || (c == Ctrl_BSL && *s == Ctrl_N)) {
        stuffcharReadbuff(Ctrl_V);
      }
      stuffcharReadbuff(c);
    }
  }
}

// This function is called when the screen size changes and with incremental
// search and in other situations where the command line may have been
// overwritten.
void redrawcmdline(void)
{
  if (cmd_silent) {
    return;
  }
  need_wait_return = false;
  compute_cmdrow();
  redrawcmd();
  cursorcmd();
  ui_cursor_shape();
}

static void redrawcmdprompt(void)
{
  if (cmd_silent) {
    return;
  }
  if (ui_has(kUICmdline)) {
    ccline.redraw_state = kCmdRedrawAll;
    return;
  }
  if (ccline.cmdfirstc != NUL) {
    msg_putchar(ccline.cmdfirstc);
  }
  if (ccline.cmdprompt != NULL) {
    msg_puts_attr(ccline.cmdprompt, ccline.cmdattr);
    ccline.cmdindent = msg_col + (msg_row - cmdline_row) * Columns;
    // do the reverse of cmd_startcol()
    if (ccline.cmdfirstc != NUL) {
      ccline.cmdindent--;
    }
  } else {
    for (int i = ccline.cmdindent; i > 0; i--) {
      msg_putchar(' ');
    }
  }
}

// Redraw what is currently on the command line.
void redrawcmd(void)
{
  if (cmd_silent) {
    return;
  }

  if (ui_has(kUICmdline)) {
    draw_cmdline(0, ccline.cmdlen);
    return;
  }

  // when 'incsearch' is set there may be no command line while redrawing
  if (ccline.cmdbuff == NULL) {
    msg_cursor_goto(cmdline_row, 0);
    msg_clr_eos();
    return;
  }

  redrawing_cmdline = true;

  sb_text_restart_cmdline();
  msg_start();
  redrawcmdprompt();

  // Don't use more prompt, truncate the cmdline if it doesn't fit.
  msg_no_more = true;
  draw_cmdline(0, ccline.cmdlen);
  msg_clr_eos();
  msg_no_more = false;

  ccline.cmdspos = cmd_screencol(ccline.cmdpos);

  if (ccline.special_char != NUL) {
    putcmdline(ccline.special_char, ccline.special_shift);
  }

  // An emsg() before may have set msg_scroll. This is used in normal mode,
  // in cmdline mode we can reset them now.
  msg_scroll = false;           // next message overwrites cmdline

  // Typing ':' at the more prompt may set skip_redraw.  We don't want this
  // in cmdline mode.
  skip_redraw = false;

  redrawing_cmdline = false;
}

void compute_cmdrow(void)
{
  if (exmode_active || msg_scrolled != 0) {
    cmdline_row = Rows - 1;
  } else {
    win_T *wp = lastwin_nofloating();
    cmdline_row = wp->w_winrow + wp->w_height
                  + wp->w_hsep_height + wp->w_status_height + global_stl_height();
  }
  if (cmdline_row == Rows && p_ch > 0) {
    cmdline_row--;
  }
  lines_left = cmdline_row;
}

void cursorcmd(void)
{
  if (cmd_silent) {
    return;
  }

  if (ui_has(kUICmdline)) {
    if (ccline.redraw_state < kCmdRedrawPos) {
      ccline.redraw_state = kCmdRedrawPos;
    }
    return;
  }

  msg_row = cmdline_row + (ccline.cmdspos / Columns);
  msg_col = ccline.cmdspos % Columns;
  if (msg_row >= Rows) {
    msg_row = Rows - 1;
  }

  msg_cursor_goto(msg_row, msg_col);
}

void gotocmdline(bool clr)
{
  if (ui_has(kUICmdline)) {
    return;
  }
  msg_start();
  msg_col = 0;  // always start in column 0
  if (clr) {  // clear the bottom line(s)
    msg_clr_eos();  // will reset clear_cmdline
  }
  msg_cursor_goto(cmdline_row, 0);
}

// Check the word in front of the cursor for an abbreviation.
// Called when the non-id character "c" has been entered.
// When an abbreviation is recognized it is removed from the text with
// backspaces and the replacement string is inserted, followed by "c".
static int ccheck_abbr(int c)
{
  int spos = 0;

  if (p_paste || no_abbr) {         // no abbreviations or in paste mode
    return false;
  }

  // Do not consider '<,'> be part of the mapping, skip leading whitespace.
  // Actually accepts any mark.
  while (spos < ccline.cmdlen && ascii_iswhite(ccline.cmdbuff[spos])) {
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

/// Escape special characters in "fname", depending on "what":
///
/// @param[in]  fname  File name to escape.
/// @param[in]  what   What to escape for:
/// - VSE_NONE: for when used as a file name argument after a Vim command.
/// - VSE_SHELL: for a shell command.
/// - VSE_BUFFER: for the ":buffer" command.
///
/// @return [allocated] escaped file name.
char *vim_strsave_fnameescape(const char *const fname, const int what)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
#ifdef BACKSLASH_IN_FILENAME
# define PATH_ESC_CHARS " \t\n*?[{`%#'\"|!<"
# define BUFFER_ESC_CHARS (" \t\n*?[`%#'\"|!<")
  char buf[sizeof(PATH_ESC_CHARS)];
  int j = 0;

  // Don't escape '[', '{' and '!' if they are in 'isfname' and for the
  // ":buffer" command.
  for (const char *p = what == VSE_BUFFER ? BUFFER_ESC_CHARS : PATH_ESC_CHARS;
       *p != NUL; p++) {
    if ((*p != '[' && *p != '{' && *p != '!') || !vim_isfilec((uint8_t)(*p))) {
      buf[j++] = *p;
    }
  }
  buf[j] = NUL;
  char *p = vim_strsave_escaped(fname, buf);
#else
# define PATH_ESC_CHARS " \t\n*?[{`$\\%#'\"|!<"
# define SHELL_ESC_CHARS " \t\n*?[{`$\\%#'\"|!<>();&"
# define BUFFER_ESC_CHARS " \t\n*?[`$\\%#'\"|!<"
  char *p = vim_strsave_escaped(fname,
                                what == VSE_SHELL ? SHELL_ESC_CHARS : what ==
                                VSE_BUFFER ? BUFFER_ESC_CHARS : PATH_ESC_CHARS);
  if (what == VSE_SHELL && csh_like_shell()) {
    // For csh and similar shells need to put two backslashes before '!'.
    // One is taken by Vim, one by the shell.
    char *s = vim_strsave_escaped(p, "!");
    xfree(p);
    p = s;
  }
#endif

  // '>' and '+' are special at the start of some commands, e.g. ":edit" and
  // ":write".  "cd -" has a special meaning.
  if (*p == '>' || *p == '+' || (*p == '-' && p[1] == NUL)) {
    escape_fname(&p);
  }

  return p;
}

/// Put a backslash before the file name in "pp", which is in allocated memory.
void escape_fname(char **pp)
{
  char *p = xmalloc(strlen(*pp) + 2);
  p[0] = '\\';
  STRCPY(p + 1, *pp);
  xfree(*pp);
  *pp = p;
}

/// For each file name in files[num_files]:
/// If 'orig_pat' starts with "~/", replace the home directory with "~".
void tilde_replace(char *orig_pat, int num_files, char **files)
{
  if (orig_pat[0] == '~' && vim_ispathsep(orig_pat[1])) {
    for (int i = 0; i < num_files; i++) {
      char *p = home_replace_save(NULL, files[i]);
      xfree(files[i]);
      files[i] = p;
    }
  }
}

/// Get a pointer to the current command line info.
CmdlineInfo *get_cmdline_info(void)
{
  return &ccline;
}

unsigned get_cmdline_last_prompt_id(void)
{
  return last_prompt_id;
}

/// Get pointer to the command line info to use. save_cmdline() may clear
/// ccline and put the previous value in ccline.prev_ccline.
static CmdlineInfo *get_ccline_ptr(void)
{
  if ((State & MODE_CMDLINE) == 0) {
    return NULL;
  } else if (ccline.cmdbuff != NULL) {
    return &ccline;
  } else if (ccline.prev_ccline && ccline.prev_ccline->cmdbuff != NULL) {
    return ccline.prev_ccline;
  } else {
    return NULL;
  }
}

/// Get the current command-line type.
/// Returns ':' or '/' or '?' or '@' or '>' or '-'
/// Only works when the command line is being edited.
/// Returns NUL when something is wrong.
static int get_cmdline_type(void)
{
  CmdlineInfo *p = get_ccline_ptr();

  if (p == NULL) {
    return NUL;
  }
  if (p->cmdfirstc == NUL) {
    return (p->input_fn) ? '@' : '-';
  }
  return p->cmdfirstc;
}

/// Get the current command line in allocated memory.
/// Only works when the command line is being edited.
///
/// @return  NULL when something is wrong.
static char *get_cmdline_str(void)
{
  if (cmdline_star > 0) {
    return NULL;
  }
  CmdlineInfo *p = get_ccline_ptr();

  if (p == NULL) {
    return NULL;
  }
  return xstrnsave(p->cmdbuff, (size_t)p->cmdlen);
}

/// Get the current command-line completion type.
static char *get_cmdline_completion(void)
{
  if (cmdline_star > 0) {
    return NULL;
  }
  CmdlineInfo *p = get_ccline_ptr();

  if (p == NULL || p->xpc == NULL) {
    return NULL;
  }

  set_expand_context(p->xpc);
  if (p->xpc->xp_context == EXPAND_UNSUCCESSFUL) {
    return NULL;
  }

  char *cmd_compl = get_user_cmd_complete(p->xpc, p->xpc->xp_context);
  if (cmd_compl == NULL) {
    return NULL;
  }

  if (p->xpc->xp_context == EXPAND_USER_LIST
      || p->xpc->xp_context == EXPAND_USER_DEFINED) {
    size_t buflen = strlen(cmd_compl) + strlen(p->xpc->xp_arg) + 2;
    char *buffer = xmalloc(buflen);
    snprintf(buffer, buflen, "%s,%s", cmd_compl, p->xpc->xp_arg);
    return buffer;
  }

  return xstrdup(cmd_compl);
}

/// "getcmdcompltype()" function
void f_getcmdcompltype(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = get_cmdline_completion();
}

/// "getcmdline()" function
void f_getcmdline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = get_cmdline_str();
}

/// "getcmdpos()" function
void f_getcmdpos(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  CmdlineInfo *p = get_ccline_ptr();
  rettv->vval.v_number = p != NULL ? p->cmdpos + 1 : 0;
}

/// "getcmdscreenpos()" function
void f_getcmdscreenpos(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  CmdlineInfo *p = get_ccline_ptr();
  rettv->vval.v_number = p != NULL ? p->cmdspos + 1 : 0;
}

/// "getcmdtype()" function
void f_getcmdtype(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = xmallocz(1);
  rettv->vval.v_string[0] = (char)get_cmdline_type();
}

/// Set the command line str to "str".
/// @return  1 when failed, 0 when OK.
static int set_cmdline_str(const char *str, int pos)
{
  CmdlineInfo *p = get_ccline_ptr();

  if (p == NULL) {
    return 1;
  }

  int len = (int)strlen(str);
  realloc_cmdbuff(len + 1);
  p->cmdlen = len;
  STRCPY(p->cmdbuff, str);

  p->cmdpos = pos < 0 || pos > p->cmdlen ? p->cmdlen : pos;
  new_cmdpos = p->cmdpos;

  redrawcmd();

  // Trigger CmdlineChanged autocommands.
  do_autocmd_cmdlinechanged(get_cmdline_type());

  return 0;
}

/// Set the command line byte position to "pos".  Zero is the first position.
/// Only works when the command line is being edited.
/// @return  1 when failed, 0 when OK.
static int set_cmdline_pos(int pos)
{
  CmdlineInfo *p = get_ccline_ptr();

  if (p == NULL) {
    return 1;
  }

  // The position is not set directly but after CTRL-\ e or CTRL-R = has
  // changed the command line.
  if (pos < 0) {
    new_cmdpos = 0;
  } else {
    new_cmdpos = pos;
  }
  return 0;
}

/// "setcmdline()" function
void f_setcmdline(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (tv_check_for_string_arg(argvars, 0) == FAIL
      || tv_check_for_opt_number_arg(argvars, 1) == FAIL) {
    return;
  }

  int pos = -1;
  if (argvars[1].v_type != VAR_UNKNOWN) {
    bool error = false;

    pos = (int)tv_get_number_chk(&argvars[1], &error) - 1;
    if (error) {
      return;
    }
    if (pos < 0) {
      emsg(_(e_positive));
      return;
    }
  }

  // Use tv_get_string() to handle a NULL string like an empty string.
  rettv->vval.v_number = set_cmdline_str(tv_get_string(&argvars[0]), pos);
}

/// "setcmdpos()" function
void f_setcmdpos(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const int pos = (int)tv_get_number(&argvars[0]) - 1;

  if (pos >= 0) {
    rettv->vval.v_number = set_cmdline_pos(pos);
  }
}

/// Return the first character of the current command line.
int get_cmdline_firstc(void)
{
  return ccline.cmdfirstc;
}

/// Get indices that specify a range within a list (not a range of text lines
/// in a buffer!) from a string.  Used for ":history" and ":clist".
///
/// @param str string to parse range from
/// @param num1 from
/// @param num2 to
///
/// @return OK if parsed successfully, otherwise FAIL.
int get_list_range(char **str, int *num1, int *num2)
{
  int len;
  bool first = false;
  varnumber_T num;

  *str = skipwhite((*str));
  if (**str == '-' || ascii_isdigit(**str)) {  // parse "from" part of range
    vim_str2nr(*str, NULL, &len, 0, &num, NULL, 0, false, NULL);
    *str += len;
    // overflow
    if (num > INT_MAX) {
      return FAIL;
    }

    *num1 = (int)num;
    first = true;
  }
  *str = skipwhite((*str));
  if (**str == ',') {                   // parse "to" part of range
    *str = skipwhite((*str) + 1);
    vim_str2nr(*str, NULL, &len, 0, &num, NULL, 0, false, NULL);
    if (len > 0) {
      *str = skipwhite((*str) + len);
      // overflow
      if (num > INT_MAX) {
        return FAIL;
      }

      *num2 = (int)num;
    } else if (!first) {                  // no number given at all
      return FAIL;
    }
  } else if (first) {                     // only one number given
    *num2 = *num1;
  }
  return OK;
}

void cmdline_init(void)
{
  CLEAR_FIELD(ccline);
}

/// Check value of 'cedit' and set cedit_key.
/// Returns NULL if value is OK, error message otherwise.
const char *did_set_cedit(optset_T *args)
{
  if (*p_cedit == NUL) {
    cedit_key = -1;
  } else {
    int n = string_to_key(p_cedit);
    if (vim_isprintc(n)) {
      return e_invarg;
    }
    cedit_key = n;
  }
  return NULL;
}

/// Open a window on the current command line and history.  Allow editing in
/// the window.  Returns when the window is closed.
/// Returns:
///     CR       if the command is to be executed
///     Ctrl_C   if it is to be abandoned
///     K_IGNORE if editing continues
static int open_cmdwin(void)
{
  bufref_T old_curbuf;
  bufref_T bufref;
  win_T *old_curwin = curwin;
  int i;
  garray_T winsizes;
  char typestr[2];
  int save_restart_edit = restart_edit;
  int save_State = State;
  bool save_exmode = exmode_active;
  bool save_cmdmsg_rl = cmdmsg_rl;

  // Can't do this when text or buffer is locked.
  // Can't do this recursively.  Can't do it when typing a password.
  if (text_or_buf_locked() || cmdwin_type != 0 || cmdline_star > 0) {
    beep_flush();
    return K_IGNORE;
  }

  set_bufref(&old_curbuf, curbuf);

  // Save current window sizes.
  win_size_save(&winsizes);

  // When using completion in Insert mode with <C-R>=<C-F> one can open the
  // command line window, but we don't want the popup menu then.
  pum_undisplay(true);

  // don't use a new tab page
  cmdmod.cmod_tab = 0;
  cmdmod.cmod_flags |= CMOD_NOSWAPFILE;

  // Create a window for the command-line buffer.
  if (win_split((int)p_cwh, WSP_BOT) == FAIL) {
    beep_flush();
    ga_clear(&winsizes);
    return K_IGNORE;
  }
  // win_split() autocommands may have messed with the old window or buffer.
  // Treat it as abandoning this command-line.
  if (!win_valid(old_curwin) || curwin == old_curwin || !bufref_valid(&old_curbuf)
      || old_curwin->w_buffer != old_curbuf.br_buf) {
    beep_flush();
    ga_clear(&winsizes);
    return Ctrl_C;
  }
  // Don't let quitting the More prompt make this fail.
  got_int = false;

  // Set "cmdwin_..." variables before any autocommands may mess things up.
  cmdwin_type = get_cmdline_type();
  cmdwin_level = ccline.level;
  cmdwin_win = curwin;
  cmdwin_old_curwin = old_curwin;

  // Create empty command-line buffer.  Be especially cautious of BufLeave
  // autocommands from do_ecmd(), as cmdwin restrictions do not apply to them!
  const int newbuf_status = buf_open_scratch(0, NULL);
  const bool cmdwin_valid = win_valid(cmdwin_win);
  if (newbuf_status == FAIL || !cmdwin_valid || curwin != cmdwin_win || !win_valid(old_curwin)
      || !bufref_valid(&old_curbuf) || old_curwin->w_buffer != old_curbuf.br_buf) {
    if (newbuf_status == OK) {
      set_bufref(&bufref, curbuf);
    }
    if (cmdwin_valid && !last_window(cmdwin_win)) {
      win_close(cmdwin_win, true, false);
    }
    // win_close() autocommands may have already deleted the buffer.
    if (newbuf_status == OK && bufref_valid(&bufref) && bufref.br_buf != curbuf) {
      close_buffer(NULL, bufref.br_buf, DOBUF_WIPE, false, false);
    }

    cmdwin_type = 0;
    cmdwin_level = 0;
    cmdwin_win = NULL;
    cmdwin_old_curwin = NULL;
    beep_flush();
    ga_clear(&winsizes);
    return Ctrl_C;
  }
  cmdwin_buf = curbuf;

  // Command-line buffer has bufhidden=wipe, unlike a true "scratch" buffer.
  set_option_value_give_err(kOptBufhidden, STATIC_CSTR_AS_OPTVAL("wipe"), OPT_LOCAL);
  curbuf->b_p_ma = true;
  curwin->w_p_fen = false;
  curwin->w_p_rl = cmdmsg_rl;
  cmdmsg_rl = false;

  // Don't allow switching to another buffer.
  curbuf->b_ro_locked++;

  // Showing the prompt may have set need_wait_return, reset it.
  need_wait_return = false;

  const int histtype = hist_char2type(cmdwin_type);
  if (histtype == HIST_CMD || histtype == HIST_DEBUG) {
    if (p_wc == TAB) {
      add_map("<Tab>", "<C-X><C-V>", MODE_INSERT, true);
      add_map("<Tab>", "a<C-X><C-V>", MODE_NORMAL, true);
    }
    set_option_value_give_err(kOptFiletype, STATIC_CSTR_AS_OPTVAL("vim"), OPT_LOCAL);
  }
  curbuf->b_ro_locked--;

  // Reset 'textwidth' after setting 'filetype' (the Vim filetype plugin
  // sets 'textwidth' to 78).
  curbuf->b_p_tw = 0;

  // Fill the buffer with the history.
  init_history();
  if (get_hislen() > 0 && histtype != HIST_INVALID) {
    i = *get_hisidx(histtype);
    if (i >= 0) {
      linenr_T lnum = 0;
      do {
        if (++i == get_hislen()) {
          i = 0;
        }
        if (get_histentry(histtype)[i].hisstr != NULL) {
          ml_append(lnum++, get_histentry(histtype)[i].hisstr, 0, false);
        }
      } while (i != *get_hisidx(histtype));
    }
  }

  // Replace the empty last line with the current command-line and put the
  // cursor there.
  ml_replace(curbuf->b_ml.ml_line_count, ccline.cmdbuff, true);
  curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
  curwin->w_cursor.col = ccline.cmdpos;
  changed_line_abv_curs();
  invalidate_botline(curwin);
  if (ui_has(kUICmdline)) {
    ccline.redraw_state = kCmdRedrawNone;
    ui_call_cmdline_hide(ccline.level);
  }
  redraw_later(curwin, UPD_SOME_VALID);

  // No Ex mode here!
  exmode_active = false;

  State = MODE_NORMAL;
  setmouse();

  // Reset here so it can be set by a CmdWinEnter autocommand.
  cmdwin_result = 0;

  // Trigger CmdwinEnter autocommands.
  typestr[0] = (char)cmdwin_type;
  typestr[1] = NUL;
  apply_autocmds(EVENT_CMDWINENTER, typestr, typestr, false, curbuf);
  if (restart_edit != 0) {  // autocmd with ":startinsert"
    stuffcharReadbuff(K_NOP);
  }

  i = RedrawingDisabled;
  RedrawingDisabled = 0;
  int save_count = save_batch_count();

  // Call the main loop until <CR> or CTRL-C is typed.
  normal_enter(true, false);

  RedrawingDisabled = i;
  restore_batch_count(save_count);

  const bool save_KeyTyped = KeyTyped;

  // Trigger CmdwinLeave autocommands.
  apply_autocmds(EVENT_CMDWINLEAVE, typestr, typestr, false, curbuf);

  // Restore KeyTyped in case it is modified by autocommands
  KeyTyped = save_KeyTyped;

  cmdwin_type = 0;
  cmdwin_level = 0;
  cmdwin_buf = NULL;
  cmdwin_win = NULL;
  cmdwin_old_curwin = NULL;

  exmode_active = save_exmode;

  // Safety check: The old window or buffer was changed or deleted: It's a bug
  // when this happens!
  if (!win_valid(old_curwin) || !bufref_valid(&old_curbuf)
      || old_curwin->w_buffer != old_curbuf.br_buf) {
    cmdwin_result = Ctrl_C;
    emsg(_(e_active_window_or_buffer_changed_or_deleted));
  } else {
    win_T *wp;
    // autocmds may abort script processing
    if (aborting() && cmdwin_result != K_IGNORE) {
      cmdwin_result = Ctrl_C;
    }
    // Set the new command line from the cmdline buffer.
    xfree(ccline.cmdbuff);
    if (cmdwin_result == K_XF1 || cmdwin_result == K_XF2) {  // :qa[!] typed
      const char *p = (cmdwin_result == K_XF2) ? "qa" : "qa!";

      if (histtype == HIST_CMD) {
        // Execute the command directly.
        ccline.cmdbuff = xstrdup(p);
        cmdwin_result = CAR;
      } else {
        // First need to cancel what we were doing.
        ccline.cmdbuff = NULL;
        stuffcharReadbuff(':');
        stuffReadbuff(p);
        stuffcharReadbuff(CAR);
      }
    } else if (cmdwin_result == Ctrl_C) {
      // :q or :close, don't execute any command
      // and don't modify the cmd window.
      ccline.cmdbuff = NULL;
    } else {
      ccline.cmdbuff = xstrdup(get_cursor_line_ptr());
    }
    if (ccline.cmdbuff == NULL) {
      ccline.cmdbuff = xstrdup("");
      ccline.cmdlen = 0;
      ccline.cmdbufflen = 1;
      ccline.cmdpos = 0;
      cmdwin_result = Ctrl_C;
    } else {
      ccline.cmdlen = (int)strlen(ccline.cmdbuff);
      ccline.cmdbufflen = ccline.cmdlen + 1;
      ccline.cmdpos = curwin->w_cursor.col;
      // If the cursor is on the last character, it probably should be after it.
      if (ccline.cmdpos == ccline.cmdlen - 1 || ccline.cmdpos > ccline.cmdlen) {
        ccline.cmdpos = ccline.cmdlen;
      }
      if (cmdwin_result == K_IGNORE) {
        ccline.cmdspos = cmd_screencol(ccline.cmdpos);
        redrawcmd();
      }
    }

    // Avoid command-line window first character being concealed.
    curwin->w_p_cole = 0;
    // First go back to the original window.
    wp = curwin;
    set_bufref(&bufref, curbuf);
    skip_win_fix_cursor = true;
    win_goto(old_curwin);

    // win_goto() may trigger an autocommand that already closes the
    // cmdline window.
    if (win_valid(wp) && wp != curwin) {
      win_close(wp, true, false);
    }

    // win_close() may have already wiped the buffer when 'bh' is
    // set to 'wipe', autocommands may have closed other windows
    if (bufref_valid(&bufref) && bufref.br_buf != curbuf) {
      close_buffer(NULL, bufref.br_buf, DOBUF_WIPE, false, false);
    }

    // Restore window sizes.
    win_size_restore(&winsizes);
    skip_win_fix_cursor = false;
  }

  ga_clear(&winsizes);
  restart_edit = save_restart_edit;
  cmdmsg_rl = save_cmdmsg_rl;

  State = save_State;
  may_trigger_modechanged();
  setmouse();
  setcursor();

  return cmdwin_result;
}

/// @return true if in the cmdwin, not editing the command line.
bool is_in_cmdwin(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return cmdwin_type != 0 && get_cmdline_type() == NUL;
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
  char *cmd = eap->arg;

  if (cmd[0] != '<' || cmd[1] != '<' || eap->ea_getline == NULL) {
    *lenp = strlen(eap->arg);
    return eap->skip ? NULL : xmemdupz(eap->arg, *lenp);
  }
  cmd += 2;

  garray_T ga = { .ga_data = NULL, .ga_len = 0 };

  list_T *const l = heredoc_get(eap, cmd, true);
  if (l == NULL) {
    return NULL;
  }

  if (!eap->skip) {
    ga_init(&ga, 1, 0x400);
  }

  TV_LIST_ITER_CONST(l, li, {
    if (!eap->skip) {
      ga_concat(&ga, tv_get_string(TV_LIST_ITEM_TV(li)));
      ga_append(&ga, '\n');
    }
  });
  *lenp = (size_t)ga.ga_len;  // Set length without trailing NUL.
  if (!eap->skip) {
    ga_append(&ga, NUL);
  }

  tv_list_free(l);
  return (char *)ga.ga_data;
}

static void set_search_match(pos_T *t)
{
  // First move cursor to end of match, then to the start.  This
  // moves the whole match onto the screen when 'nowrap' is set.
  t->lnum += search_match_lines;
  t->col = search_match_endcol;
  if (t->lnum > curbuf->b_ml.ml_line_count) {
    t->lnum = curbuf->b_ml.ml_line_count;
    coladvance(curwin, MAXCOL);
  }
}
