//
// normal.c:    Contains the main routine for processing characters in command
//              mode.  Communicates closely with the code in ops.c to handle
//              the operators.
//

#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cmdhist.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/help.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/mapping.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/math.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"
#include "nvim/plines.h"
#include "nvim/profile.h"
#include "nvim/quickfix.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/spell_defs.h"
#include "nvim/spellfile.h"
#include "nvim/spellsuggest.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/statusline.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/tag.h"
#include "nvim/textformat.h"
#include "nvim/textobject.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

typedef struct {
  VimState state;
  bool command_finished;
  bool ctrl_w;
  bool need_flushbuf;
  bool set_prevcount;
  bool previous_got_int;             // `got_int` was true
  bool cmdwin;                       // command-line window normal mode
  bool noexmode;                     // true if the normal mode was pushed from
                                     // ex mode(:global or :visual for example)
  bool toplevel;                     // top-level normal mode
  oparg_T oa;                        // operator arguments
  cmdarg_T ca;                       // command arguments
  int mapped_len;
  int old_mapped_len;
  int idx;
  int c;
  int old_col;
  pos_T old_pos;
} NormalState;

static int VIsual_mode_orig = NUL;              // saved Visual mode

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "normal.c.generated.h"
#endif

static const char e_changelist_is_empty[] = N_("E664: Changelist is empty");
static const char e_cmdline_window_already_open[]
  = N_("E1292: Command-line window is already open");

static inline void normal_state_init(NormalState *s)
{
  memset(s, 0, sizeof(NormalState));
  s->state.check = normal_check;
  s->state.execute = normal_execute;
}

// nv_*(): functions called to handle Normal and Visual mode commands.
// n_*(): functions called to handle Normal mode commands.
// v_*(): functions called to handle Visual mode commands.

static const char *e_noident = N_("E349: No identifier under cursor");

/// Function to be called for a Normal or Visual mode command.
/// The argument is a cmdarg_T.
typedef void (*nv_func_T)(cmdarg_T *cap);

// Values for cmd_flags.
#define NV_NCH      0x01          // may need to get a second char
#define NV_NCH_NOP  (0x02|NV_NCH)  // get second char when no operator pending
#define NV_NCH_ALW  (0x04|NV_NCH)  // always get a second char
#define NV_LANG     0x08        // second char needs language adjustment

#define NV_SS       0x10        // may start selection
#define NV_SSS      0x20        // may start selection with shift modifier
#define NV_STS      0x40        // may stop selection without shift modif.
#define NV_RL       0x80        // 'rightleft' modifies command
#define NV_KEEPREG  0x100       // don't clear regname
#define NV_NCW      0x200       // not allowed in command-line window

// Generally speaking, every Normal mode command should either clear any
// pending operator (with *clearop*()), or set the motion type variable
// oap->motion_type.
//
// When a cursor motion command is made, it is marked as being a character or
// line oriented motion.  Then, if an operator is in effect, the operation
// becomes character or line oriented accordingly.

/// This table contains one entry for every Normal or Visual mode command.
/// The order doesn't matter, init_normal_cmds() will create a sorted index.
/// It is faster when all keys from zero to '~' are present.
static const struct nv_cmd {
  int cmd_char;                 ///< (first) command character
  nv_func_T cmd_func;           ///< function for this command
  uint16_t cmd_flags;           ///< NV_ flags
  int16_t cmd_arg;              ///< value for ca.arg
} nv_cmds[] = {
  { NUL,       nv_error,       0,                      0 },
  { Ctrl_A,    nv_addsub,      0,                      0 },
  { Ctrl_B,    nv_page,        NV_STS,                 BACKWARD },
  { Ctrl_C,    nv_esc,         0,                      true },
  { Ctrl_D,    nv_halfpage,    0,                      0 },
  { Ctrl_E,    nv_scroll_line, 0,                      true },
  { Ctrl_F,    nv_page,        NV_STS,                 FORWARD },
  { Ctrl_G,    nv_ctrlg,       0,                      0 },
  { Ctrl_H,    nv_ctrlh,       0,                      0 },
  { Ctrl_I,    nv_pcmark,      0,                      0 },
  { NL,        nv_down,        0,                      false },
  { Ctrl_K,    nv_error,       0,                      0 },
  { Ctrl_L,    nv_clear,       0,                      0 },
  { CAR,       nv_down,        0,                      true },
  { Ctrl_N,    nv_down,        NV_STS,                 false },
  { Ctrl_O,    nv_ctrlo,       0,                      0 },
  { Ctrl_P,    nv_up,          NV_STS,                 false },
  { Ctrl_Q,    nv_visual,      0,                      false },
  { Ctrl_R,    nv_redo_or_register, 0,                      0 },
  { Ctrl_S,    nv_ignore,      0,                      0 },
  { Ctrl_T,    nv_tagpop,      NV_NCW,                 0 },
  { Ctrl_U,    nv_halfpage,    0,                      0 },
  { Ctrl_V,    nv_visual,      0,                      false },
  { 'V',       nv_visual,      0,                      false },
  { 'v',       nv_visual,      0,                      false },
  { Ctrl_W,    nv_window,      0,                      0 },
  { Ctrl_X,    nv_addsub,      0,                      0 },
  { Ctrl_Y,    nv_scroll_line, 0,                      false },
  { Ctrl_Z,    nv_suspend,     0,                      0 },
  { ESC,       nv_esc,         0,                      false },
  { Ctrl_BSL,  nv_normal,      NV_NCH_ALW,             0 },
  { Ctrl_RSB,  nv_ident,       NV_NCW,                 0 },
  { Ctrl_HAT,  nv_hat,         NV_NCW,                 0 },
  { Ctrl__,    nv_error,       0,                      0 },
  { ' ',       nv_right,       0,                      0 },
  { '!',       nv_operator,    0,                      0 },
  { '"',       nv_regname,     NV_NCH_NOP|NV_KEEPREG,  0 },
  { '#',       nv_ident,       0,                      0 },
  { '$',       nv_dollar,      0,                      0 },
  { '%',       nv_percent,     0,                      0 },
  { '&',       nv_optrans,     0,                      0 },
  { '\'',      nv_gomark,      NV_NCH_ALW,             true },
  { '(',       nv_brace,       0,                      BACKWARD },
  { ')',       nv_brace,       0,                      FORWARD },
  { '*',       nv_ident,       0,                      0 },
  { '+',       nv_down,        0,                      true },
  { ',',       nv_csearch,     0,                      true },
  { '-',       nv_up,          0,                      true },
  { '.',       nv_dot,         NV_KEEPREG,             0 },
  { '/',       nv_search,      0,                      false },
  { '0',       nv_beginline,   0,                      0 },
  { '1',       nv_ignore,      0,                      0 },
  { '2',       nv_ignore,      0,                      0 },
  { '3',       nv_ignore,      0,                      0 },
  { '4',       nv_ignore,      0,                      0 },
  { '5',       nv_ignore,      0,                      0 },
  { '6',       nv_ignore,      0,                      0 },
  { '7',       nv_ignore,      0,                      0 },
  { '8',       nv_ignore,      0,                      0 },
  { '9',       nv_ignore,      0,                      0 },
  { ':',       nv_colon,       0,                      0 },
  { ';',       nv_csearch,     0,                      false },
  { '<',       nv_operator,    NV_RL,                  0 },
  { '=',       nv_operator,    0,                      0 },
  { '>',       nv_operator,    NV_RL,                  0 },
  { '?',       nv_search,      0,                      false },
  { '@',       nv_at,          NV_NCH_NOP,             false },
  { 'A',       nv_edit,        0,                      0 },
  { 'B',       nv_bck_word,    0,                      1 },
  { 'C',       nv_abbrev,      NV_KEEPREG,             0 },
  { 'D',       nv_abbrev,      NV_KEEPREG,             0 },
  { 'E',       nv_wordcmd,     0,                      true },
  { 'F',       nv_csearch,     NV_NCH_ALW|NV_LANG,     BACKWARD },
  { 'G',       nv_goto,        0,                      true },
  { 'H',       nv_scroll,      0,                      0 },
  { 'I',       nv_edit,        0,                      0 },
  { 'J',       nv_join,        0,                      0 },
  { 'K',       nv_ident,       0,                      0 },
  { 'L',       nv_scroll,      0,                      0 },
  { 'M',       nv_scroll,      0,                      0 },
  { 'N',       nv_next,        0,                      SEARCH_REV },
  { 'O',       nv_open,        0,                      0 },
  { 'P',       nv_put,         0,                      0 },
  { 'Q',       nv_regreplay, 0,                      0 },
  { 'R',       nv_Replace,     0,                      false },
  { 'S',       nv_subst,       NV_KEEPREG,             0 },
  { 'T',       nv_csearch,     NV_NCH_ALW|NV_LANG,     BACKWARD },
  { 'U',       nv_Undo,        0,                      0 },
  { 'W',       nv_wordcmd,     0,                      true },
  { 'X',       nv_abbrev,      NV_KEEPREG,             0 },
  { 'Y',       nv_abbrev,      NV_KEEPREG,             0 },
  { 'Z',       nv_Zet,         NV_NCH_NOP|NV_NCW,      0 },
  { '[',       nv_brackets,    NV_NCH_ALW,             BACKWARD },
  { '\\',      nv_error,       0,                      0 },
  { ']',       nv_brackets,    NV_NCH_ALW,             FORWARD },
  { '^',       nv_beginline,   0,                      BL_WHITE | BL_FIX },
  { '_',       nv_lineop,      0,                      0 },
  { '`',       nv_gomark,      NV_NCH_ALW,             false },
  { 'a',       nv_edit,        NV_NCH,                 0 },
  { 'b',       nv_bck_word,    0,                      0 },
  { 'c',       nv_operator,    0,                      0 },
  { 'd',       nv_operator,    0,                      0 },
  { 'e',       nv_wordcmd,     0,                      false },
  { 'f',       nv_csearch,     NV_NCH_ALW|NV_LANG,     FORWARD },
  { 'g',       nv_g_cmd,       NV_NCH_ALW,             false },
  { 'h',       nv_left,        NV_RL,                  0 },
  { 'i',       nv_edit,        NV_NCH,                 0 },
  { 'j',       nv_down,        0,                      false },
  { 'k',       nv_up,          0,                      false },
  { 'l',       nv_right,       NV_RL,                  0 },
  { 'm',       nv_mark,        NV_NCH_NOP,             0 },
  { 'n',       nv_next,        0,                      0 },
  { 'o',       nv_open,        0,                      0 },
  { 'p',       nv_put,         0,                      0 },
  { 'q',       nv_record,      NV_NCH,                 0 },
  { 'r',       nv_replace,     NV_NCH_NOP|NV_LANG,     0 },
  { 's',       nv_subst,       NV_KEEPREG,             0 },
  { 't',       nv_csearch,     NV_NCH_ALW|NV_LANG,     FORWARD },
  { 'u',       nv_undo,        0,                      0 },
  { 'w',       nv_wordcmd,     0,                      false },
  { 'x',       nv_abbrev,      NV_KEEPREG,             0 },
  { 'y',       nv_operator,    0,                      0 },
  { 'z',       nv_zet,         NV_NCH_ALW,             0 },
  { '{',       nv_findpar,     0,                      BACKWARD },
  { '|',       nv_pipe,        0,                      0 },
  { '}',       nv_findpar,     0,                      FORWARD },
  { '~',       nv_tilde,       0,                      0 },

  // pound sign
  { POUND,     nv_ident,       0,                      0 },
  { K_MOUSEUP, nv_mousescroll, 0,                      MSCR_UP },
  { K_MOUSEDOWN, nv_mousescroll, 0,                    MSCR_DOWN },
  { K_MOUSELEFT, nv_mousescroll, 0,                    MSCR_LEFT },
  { K_MOUSERIGHT, nv_mousescroll, 0,                   MSCR_RIGHT },
  { K_LEFTMOUSE, nv_mouse,     0,                      0 },
  { K_LEFTMOUSE_NM, nv_mouse,  0,                      0 },
  { K_LEFTDRAG, nv_mouse,      0,                      0 },
  { K_LEFTRELEASE, nv_mouse,   0,                      0 },
  { K_LEFTRELEASE_NM, nv_mouse, 0,                     0 },
  { K_MOUSEMOVE, nv_mouse,     0,                      0 },
  { K_MIDDLEMOUSE, nv_mouse,   0,                      0 },
  { K_MIDDLEDRAG, nv_mouse,    0,                      0 },
  { K_MIDDLERELEASE, nv_mouse, 0,                      0 },
  { K_RIGHTMOUSE, nv_mouse,    0,                      0 },
  { K_RIGHTDRAG, nv_mouse,     0,                      0 },
  { K_RIGHTRELEASE, nv_mouse,  0,                      0 },
  { K_X1MOUSE, nv_mouse,       0,                      0 },
  { K_X1DRAG, nv_mouse,        0,                      0 },
  { K_X1RELEASE, nv_mouse,     0,                      0 },
  { K_X2MOUSE, nv_mouse,       0,                      0 },
  { K_X2DRAG, nv_mouse,        0,                      0 },
  { K_X2RELEASE, nv_mouse,     0,                      0 },
  { K_IGNORE,  nv_ignore,      NV_KEEPREG,             0 },
  { K_NOP,     nv_nop,         0,                      0 },
  { K_INS,     nv_edit,        0,                      0 },
  { K_KINS,    nv_edit,        0,                      0 },
  { K_BS,      nv_ctrlh,       0,                      0 },
  { K_UP,      nv_up,          NV_SSS|NV_STS,          false },
  { K_S_UP,    nv_page,        NV_SS,                  BACKWARD },
  { K_DOWN,    nv_down,        NV_SSS|NV_STS,          false },
  { K_S_DOWN,  nv_page,        NV_SS,                  FORWARD },
  { K_LEFT,    nv_left,        NV_SSS|NV_STS|NV_RL,    0 },
  { K_S_LEFT,  nv_bck_word,    NV_SS|NV_RL,            0 },
  { K_C_LEFT,  nv_bck_word,    NV_SSS|NV_RL|NV_STS,    1 },
  { K_RIGHT,   nv_right,       NV_SSS|NV_STS|NV_RL,    0 },
  { K_S_RIGHT, nv_wordcmd,     NV_SS|NV_RL,            false },
  { K_C_RIGHT, nv_wordcmd,     NV_SSS|NV_RL|NV_STS,    true },
  { K_PAGEUP,  nv_page,        NV_SSS|NV_STS,          BACKWARD },
  { K_KPAGEUP, nv_page,        NV_SSS|NV_STS,          BACKWARD },
  { K_PAGEDOWN, nv_page,       NV_SSS|NV_STS,          FORWARD },
  { K_KPAGEDOWN, nv_page,      NV_SSS|NV_STS,          FORWARD },
  { K_END,     nv_end,         NV_SSS|NV_STS,          false },
  { K_KEND,    nv_end,         NV_SSS|NV_STS,          false },
  { K_S_END,   nv_end,         NV_SS,                  false },
  { K_C_END,   nv_end,         NV_SSS|NV_STS,          true },
  { K_HOME,    nv_home,        NV_SSS|NV_STS,          0 },
  { K_KHOME,   nv_home,        NV_SSS|NV_STS,          0 },
  { K_S_HOME,  nv_home,        NV_SS,                  0 },
  { K_C_HOME,  nv_goto,        NV_SSS|NV_STS,          false },
  { K_DEL,     nv_abbrev,      0,                      0 },
  { K_KDEL,    nv_abbrev,      0,                      0 },
  { K_UNDO,    nv_kundo,       0,                      0 },
  { K_HELP,    nv_help,        NV_NCW,                 0 },
  { K_F1,      nv_help,        NV_NCW,                 0 },
  { K_XF1,     nv_help,        NV_NCW,                 0 },
  { K_SELECT,  nv_select,      0,                      0 },
  { K_EVENT,   nv_event,       NV_KEEPREG,             0 },
  { K_COMMAND, nv_colon,       0,                      0 },
  { K_LUA, nv_colon,           0,                      0 },
};

// Number of commands in nv_cmds[].
#define NV_CMDS_SIZE ARRAY_SIZE(nv_cmds)

// Sorted index of commands in nv_cmds[].
static int16_t nv_cmd_idx[NV_CMDS_SIZE];

// The highest index for which
// nv_cmds[idx].cmd_char == nv_cmd_idx[nv_cmds[idx].cmd_char]
static int nv_max_linear;

/// Compare functions for qsort() below, that checks the command character
/// through the index in nv_cmd_idx[].
static int nv_compare(const void *s1, const void *s2)
{
  // The commands are sorted on absolute value.
  int c1 = nv_cmds[*(const int16_t *)s1].cmd_char;
  int c2 = nv_cmds[*(const int16_t *)s2].cmd_char;
  if (c1 < 0) {
    c1 = -c1;
  }
  if (c2 < 0) {
    c2 = -c2;
  }
  return c1 == c2 ? 0 : c1 > c2 ? 1 : -1;
}

/// Initialize the nv_cmd_idx[] table.
void init_normal_cmds(void)
{
  assert(NV_CMDS_SIZE <= SHRT_MAX);

  // Fill the index table with a one to one relation.
  for (int16_t i = 0; i < (int16_t)NV_CMDS_SIZE; i++) {
    nv_cmd_idx[i] = i;
  }

  // Sort the commands by the command character.
  qsort(&nv_cmd_idx, NV_CMDS_SIZE, sizeof(int16_t), nv_compare);

  // Find the first entry that can't be indexed by the command character.
  int16_t i;
  for (i = 0; i < (int16_t)NV_CMDS_SIZE; i++) {
    if (i != nv_cmds[nv_cmd_idx[i]].cmd_char) {
      break;
    }
  }
  nv_max_linear = i - 1;
}

/// Search for a command in the commands table.
///
/// @return  -1 for invalid command.
static int find_command(int cmdchar)
{
  // A multi-byte character is never a command.
  if (cmdchar >= 0x100) {
    return -1;
  }

  // We use the absolute value of the character.  Special keys have a
  // negative value, but are sorted on their absolute value.
  if (cmdchar < 0) {
    cmdchar = -cmdchar;
  }

  // If the character is in the first part: The character is the index into
  // nv_cmd_idx[].
  assert(nv_max_linear < (int)NV_CMDS_SIZE);
  if (cmdchar <= nv_max_linear) {
    return nv_cmd_idx[cmdchar];
  }

  // Perform a binary search.
  int bot = nv_max_linear + 1;
  int top = NV_CMDS_SIZE - 1;
  int idx = -1;
  while (bot <= top) {
    int i = (top + bot) / 2;
    int c = nv_cmds[nv_cmd_idx[i]].cmd_char;
    if (c < 0) {
      c = -c;
    }
    if (cmdchar == c) {
      idx = nv_cmd_idx[i];
      break;
    }
    if (cmdchar > c) {
      bot = i + 1;
    } else {
      top = i - 1;
    }
  }
  return idx;
}

/// If currently editing a cmdline or text is locked: beep and give an error
/// message, return true.
static bool check_text_locked(oparg_T *oap)
{
  if (!text_locked()) {
    return false;
  }

  if (oap != NULL) {
    clearopbeep(oap);
  }
  text_locked_msg();
  return true;
}

/// If text is locked, "curbuf->b_ro_locked" or "allbuf_lock" is set:
/// Give an error message, possibly beep and return true.
/// "oap" may be NULL.
bool check_text_or_curbuf_locked(oparg_T *oap)
{
  if (check_text_locked(oap)) {
    return true;
  }

  if (!curbuf_locked()) {
    return false;
  }

  if (oap != NULL) {
    clearop(oap);
  }
  return true;
}

static oparg_T *current_oap = NULL;

/// Check if an operator was started but not finished yet.
/// Includes typing a count or a register name.
bool op_pending(void)
{
  return !(current_oap != NULL
           && !finish_op
           && current_oap->prev_opcount == 0
           && current_oap->prev_count0 == 0
           && current_oap->op_type == OP_NOP
           && current_oap->regname == NUL);
}

/// Normal state entry point. This is called on:
///
/// - Startup, In this case the function never returns.
/// - The command-line window is opened(`q:`). Returns when `cmdwin_result` != 0.
/// - The :visual command is called from :global in ex mode, `:global/PAT/visual`
///   for example. Returns when re-entering ex mode(because ex mode recursion is
///   not allowed)
///
/// This used to be called main_loop() on main.c
void normal_enter(bool cmdwin, bool noexmode)
{
  NormalState state;
  normal_state_init(&state);
  oparg_T *prev_oap = current_oap;
  current_oap = &state.oa;
  state.cmdwin = cmdwin;
  state.noexmode = noexmode;
  state.toplevel = (!cmdwin || cmdwin_result == 0) && !noexmode;
  state_enter(&state.state);
  current_oap = prev_oap;
}

static void normal_prepare(NormalState *s)
{
  CLEAR_FIELD(s->ca);  // also resets s->ca.retval
  s->ca.oap = &s->oa;

  // Use a count remembered from before entering an operator. After typing "3d"
  // we return from normal_cmd() and come back here, the "3" is remembered in
  // "opcount".
  s->ca.opcount = opcount;

  // If there is an operator pending, then the command we take this time will
  // terminate it. Finish_op tells us to finish the operation before returning
  // this time (unless the operation was cancelled).
  int c = finish_op;
  finish_op = (s->oa.op_type != OP_NOP);
  if (finish_op != c) {
    ui_cursor_shape();  // may show different cursor shape
  }
  may_trigger_modechanged();

  // When not finishing an operator and no register name typed, reset the count.
  if (!finish_op && !s->oa.regname) {
    s->ca.opcount = 0;
    s->set_prevcount = true;
  }

  // Restore counts from before receiving K_EVENT.  This means after
  // typing "3", handling K_EVENT and then typing "2" we get "32", not
  // "3 * 2".
  if (s->oa.prev_opcount > 0 || s->oa.prev_count0 > 0) {
    s->ca.opcount = s->oa.prev_opcount;
    s->ca.count0 = s->oa.prev_count0;
    s->oa.prev_opcount = 0;
    s->oa.prev_count0 = 0;
  }

  s->mapped_len = typebuf_maplen();
  State = MODE_NORMAL_BUSY;

  // Set v:count here, when called from main() and not a stuffed command, so
  // that v:count can be used in an expression mapping when there is no count.
  // Do set it for redo
  if (s->toplevel && readbuf1_empty()) {
    set_vcount_ca(&s->ca, &s->set_prevcount);
  }
}

static bool normal_handle_special_visual_command(NormalState *s)
{
  // when 'keymodel' contains "stopsel" may stop Select/Visual mode
  if (km_stopsel
      && (nv_cmds[s->idx].cmd_flags & NV_STS)
      && !(mod_mask & MOD_MASK_SHIFT)) {
    end_visual_mode();
    redraw_curbuf_later(UPD_INVERTED);
  }

  // Keys that work different when 'keymodel' contains "startsel"
  if (km_startsel) {
    if (nv_cmds[s->idx].cmd_flags & NV_SS) {
      unshift_special(&s->ca);
      s->idx = find_command(s->ca.cmdchar);
      if (s->idx < 0) {
        // Just in case
        clearopbeep(&s->oa);
        return true;
      }
    } else if ((nv_cmds[s->idx].cmd_flags & NV_SSS)
               && (mod_mask & MOD_MASK_SHIFT)) {
      mod_mask &= ~MOD_MASK_SHIFT;
    }
  }
  return false;
}

static bool normal_need_additional_char(NormalState *s)
{
  int flags = nv_cmds[s->idx].cmd_flags;
  bool pending_op = s->oa.op_type != OP_NOP;
  int cmdchar = s->ca.cmdchar;
  // without NV_NCH we never need to check for an additional char
  return flags & NV_NCH && (
                            // NV_NCH_NOP is set and no operator is pending, get a second char
                            ((flags & NV_NCH_NOP) == NV_NCH_NOP && !pending_op)
                            // NV_NCH_ALW is set, always get a second char
                            || (flags & NV_NCH_ALW) == NV_NCH_ALW
                            // 'q' without a pending operator, recording or executing a register,
                            // needs to be followed by a second char, examples:
                            // - qc => record using register c
                            // - q: => open command-line window
                            || (cmdchar == 'q'
                                && !pending_op
                                && reg_recording == 0
                                && reg_executing == 0)
                            // 'a' or 'i' after an operator is a text object, examples:
                            // - ciw => change inside word
                            // - da( => delete parenthesis and everything inside.
                            // Also, don't do anything when these keys are received in visual mode
                            // so just get another char.
                            //
                            // TODO(tarruda): Visual state needs to be refactored into a
                            // separate state that "inherits" from normal state.
                            || ((cmdchar == 'a' || cmdchar == 'i')
                                && (pending_op || VIsual_active)));
}

static bool normal_need_redraw_mode_message(NormalState *s)
{
  // In Visual mode and with "^O" in Insert mode, a short message will be
  // overwritten by the mode message.  Wait a bit, until a key is hit.
  // In Visual mode, it's more important to keep the Visual area updated
  // than keeping a message (e.g. from a /pat search).
  // Only do this if the command was typed, not from a mapping.
  // Don't wait when emsg_silent is non-zero.
  // Also wait a bit after an error message, e.g. for "^O:".
  // Don't redraw the screen, it would remove the message.
  return (
          // 'showmode' is set and messages can be printed
          ((p_smd && msg_silent == 0
            // must restart insert mode(ctrl+o or ctrl+l) or we just entered visual
            // mode
            && (restart_edit != 0 || (VIsual_active
                                      && s->old_pos.lnum == curwin->w_cursor.lnum
                                      && s->old_pos.col == curwin->w_cursor.col))
            // command-line must be cleared or redrawn
            && (clear_cmdline || redraw_cmdline)
            // some message was printed or scrolled
            && (msg_didout || (msg_didany && msg_scroll))
            // it is fine to remove the current message
            && !msg_nowait
            // the command was the result of direct user input and not a mapping
            && KeyTyped)
           // must restart insert mode, not in visual mode and error message is
           // being shown
           || (restart_edit != 0 && !VIsual_active && msg_scroll
               && emsg_on_display))
          // no register was used
          && s->oa.regname == 0
          && !(s->ca.retval & CA_COMMAND_BUSY)
          && stuff_empty()
          && typebuf_typed()
          && emsg_silent == 0
          && !in_assert_fails
          && !did_wait_return
          && s->oa.op_type == OP_NOP);
}

static void normal_redraw_mode_message(NormalState *s)
{
  int save_State = State;

  // Draw the cursor with the right shape here
  if (restart_edit != 0) {
    State = MODE_INSERT;
  }

  // If need to redraw, and there is a "keep_msg", redraw before the
  // delay
  if (must_redraw && keep_msg != NULL && !emsg_on_display) {
    char *kmsg;

    kmsg = keep_msg;
    keep_msg = NULL;
    // Showmode() will clear keep_msg, but we want to use it anyway.
    // First update w_topline.
    setcursor();
    update_screen();
    // now reset it, otherwise it's put in the history again
    keep_msg = kmsg;

    kmsg = xstrdup(keep_msg);
    msg(kmsg, keep_msg_attr);
    xfree(kmsg);
  }
  setcursor();
  ui_cursor_shape();                  // show different cursor shape
  ui_flush();
  if (msg_scroll || emsg_on_display) {
    os_delay(1003, true);            // wait at least one second
  }
  os_delay(3003, false);             // wait up to three seconds
  State = save_State;

  msg_scroll = false;
  emsg_on_display = false;
}

// TODO(tarruda): Split into a "normal pending" state that can handle K_EVENT
static void normal_get_additional_char(NormalState *s)
{
  int *cp;
  bool repl = false;            // get character for replace mode
  bool lit = false;             // get extra character literally
  bool lang;                    // getting a text character

  no_mapping++;
  allow_keys++;                 // no mapping for nchar, but allow key codes
  // Don't generate a CursorHold event here, most commands can't handle
  // it, e.g., nv_replace(), nv_csearch().
  did_cursorhold = true;
  if (s->ca.cmdchar == 'g') {
    // For 'g' get the next character now, so that we can check for
    // "gr", "g'" and "g`".
    s->ca.nchar = plain_vgetc();
    LANGMAP_ADJUST(s->ca.nchar, true);
    s->need_flushbuf |= add_to_showcmd(s->ca.nchar);
    if (s->ca.nchar == 'r' || s->ca.nchar == '\'' || s->ca.nchar == '`'
        || s->ca.nchar == Ctrl_BSL) {
      cp = &s->ca.extra_char;            // need to get a third character
      if (s->ca.nchar != 'r') {
        lit = true;                           // get it literally
      } else {
        repl = true;                          // get it in replace mode
      }
    } else {
      cp = NULL;                      // no third character needed
    }
  } else {
    if (s->ca.cmdchar == 'r') {
      // get it in replace mode
      repl = true;
    }
    cp = &s->ca.nchar;
  }
  lang = (repl || (nv_cmds[s->idx].cmd_flags & NV_LANG));

  // Get a second or third character.
  if (cp != NULL) {
    bool langmap_active = false;  // using :lmap mappings
    if (repl) {
      State = MODE_REPLACE;                // pretend Replace mode
      ui_cursor_shape_no_check_conceal();  // show different cursor shape
    }
    if (lang && curbuf->b_p_iminsert == B_IMODE_LMAP) {
      // Allow mappings defined with ":lmap".
      no_mapping--;
      allow_keys--;
      if (repl) {
        State = MODE_LREPLACE;
      } else {
        State = MODE_LANGMAP;
      }
      langmap_active = true;
    }

    *cp = plain_vgetc();

    if (langmap_active) {
      // Undo the decrement done above
      no_mapping++;
      allow_keys++;
    }
    State = MODE_NORMAL_BUSY;
    s->need_flushbuf |= add_to_showcmd(*cp);

    if (!lit) {
      // Typing CTRL-K gets a digraph.
      if (*cp == Ctrl_K && ((nv_cmds[s->idx].cmd_flags & NV_LANG)
                            || cp == &s->ca.extra_char)
          && vim_strchr(p_cpo, CPO_DIGRAPH) == NULL) {
        s->c = get_digraph(false);
        if (s->c > 0) {
          *cp = s->c;
          // Guessing how to update showcmd here...
          del_from_showcmd(3);
          s->need_flushbuf |= add_to_showcmd(*cp);
        }
      }

      // adjust chars > 127, except after "tTfFr" commands
      LANGMAP_ADJUST(*cp, !lang);
    }

    // When the next character is CTRL-\ a following CTRL-N means the
    // command is aborted and we go to Normal mode.
    if (cp == &s->ca.extra_char
        && s->ca.nchar == Ctrl_BSL
        && (s->ca.extra_char == Ctrl_N || s->ca.extra_char == Ctrl_G)) {
      s->ca.cmdchar = Ctrl_BSL;
      s->ca.nchar = s->ca.extra_char;
      s->idx = find_command(s->ca.cmdchar);
    } else if ((s->ca.nchar == 'n' || s->ca.nchar == 'N')
               && s->ca.cmdchar == 'g') {
      s->ca.oap->op_type = get_op_type(*cp, NUL);
    } else if (*cp == Ctrl_BSL) {
      int towait = (p_ttm >= 0 ? (int)p_ttm : (int)p_tm);

      // There is a busy wait here when typing "f<C-\>" and then
      // something different from CTRL-N.  Can't be avoided.
      while ((s->c = vpeekc()) <= 0 && towait > 0) {
        do_sleep(towait > 50 ? 50 : towait);
        towait -= 50;
      }
      if (s->c > 0) {
        s->c = plain_vgetc();
        if (s->c != Ctrl_N && s->c != Ctrl_G) {
          vungetc(s->c);
        } else {
          s->ca.cmdchar = Ctrl_BSL;
          s->ca.nchar = s->c;
          s->idx = find_command(s->ca.cmdchar);
          assert(s->idx >= 0);
        }
      }
    }

    if (lang) {
      // When getting a text character and the next character is a
      // multi-byte character, it could be a composing character.
      // However, don't wait for it to arrive. Also, do enable mapping,
      // because if it's put back with vungetc() it's too late to apply
      // mapping.
      no_mapping--;
      while ((s->c = vpeekc()) > 0
             && (s->c >= 0x100 || MB_BYTE2LEN(vpeekc()) > 1)) {
        s->c = plain_vgetc();
        if (!utf_iscomposing(s->c)) {
          vungetc(s->c);                   // it wasn't, put it back
          break;
        } else if (s->ca.ncharC1 == 0) {
          s->ca.ncharC1 = s->c;
        } else {
          s->ca.ncharC2 = s->c;
        }
      }
      no_mapping++;
      // Vim may be in a different mode when the user types the next key,
      // but when replaying a recording the next key is already in the
      // typeahead buffer, so record an <Ignore> before that to prevent
      // the vpeekc() above from applying wrong mappings when replaying.
      no_u_sync++;
      gotchars_ignore();
      no_u_sync--;
    }
  }
  no_mapping--;
  allow_keys--;
}

static void normal_invert_horizontal(NormalState *s)
{
  switch (s->ca.cmdchar) {
  case 'l':
    s->ca.cmdchar = 'h'; break;
  case K_RIGHT:
    s->ca.cmdchar = K_LEFT; break;
  case K_S_RIGHT:
    s->ca.cmdchar = K_S_LEFT; break;
  case K_C_RIGHT:
    s->ca.cmdchar = K_C_LEFT; break;
  case 'h':
    s->ca.cmdchar = 'l'; break;
  case K_LEFT:
    s->ca.cmdchar = K_RIGHT; break;
  case K_S_LEFT:
    s->ca.cmdchar = K_S_RIGHT; break;
  case K_C_LEFT:
    s->ca.cmdchar = K_C_RIGHT; break;
  case '>':
    s->ca.cmdchar = '<'; break;
  case '<':
    s->ca.cmdchar = '>'; break;
  }
  s->idx = find_command(s->ca.cmdchar);
}

static bool normal_get_command_count(NormalState *s)
{
  if (VIsual_active && VIsual_select) {
    return false;
  }
  // Handle a count before a command and compute ca.count0.
  // Note that '0' is a command and not the start of a count, but it's
  // part of a count after other digits.
  while ((s->c >= '1' && s->c <= '9')
         || (s->ca.count0 != 0 && (s->c == K_DEL || s->c == K_KDEL || s->c == '0'))) {
    if (s->c == K_DEL || s->c == K_KDEL) {
      s->ca.count0 /= 10;
      del_from_showcmd(4);            // delete the digit and ~@%
    } else if (s->ca.count0 > 99999999) {
      s->ca.count0 = 999999999;
    } else {
      s->ca.count0 = s->ca.count0 * 10 + (s->c - '0');
    }

    // Set v:count here, when called from main() and not a stuffed
    // command, so that v:count can be used in an expression mapping
    // right after the count. Do set it for redo.
    if (s->toplevel && readbuf1_empty()) {
      set_vcount_ca(&s->ca, &s->set_prevcount);
    }

    if (s->ctrl_w) {
      no_mapping++;
      allow_keys++;                   // no mapping for nchar, but keys
    }

    no_zero_mapping++;                // don't map zero here
    s->c = plain_vgetc();
    LANGMAP_ADJUST(s->c, true);
    no_zero_mapping--;
    if (s->ctrl_w) {
      no_mapping--;
      allow_keys--;
    }
    s->need_flushbuf |= add_to_showcmd(s->c);
  }

  // If we got CTRL-W there may be a/another count
  if (s->c == Ctrl_W && !s->ctrl_w && s->oa.op_type == OP_NOP) {
    s->ctrl_w = true;
    s->ca.opcount = s->ca.count0;           // remember first count
    s->ca.count0 = 0;
    no_mapping++;
    allow_keys++;                        // no mapping for nchar, but keys
    s->c = plain_vgetc();                // get next character
    LANGMAP_ADJUST(s->c, true);
    no_mapping--;
    allow_keys--;
    s->need_flushbuf |= add_to_showcmd(s->c);
    return true;
  }

  return false;
}

static void normal_finish_command(NormalState *s)
{
  if (s->command_finished) {
    goto normal_end;
  }

  // If we didn't start or finish an operator, reset oap->regname, unless we
  // need it later.
  if (!finish_op
      && !s->oa.op_type
      && (s->idx < 0 || !(nv_cmds[s->idx].cmd_flags & NV_KEEPREG))) {
    clearop(&s->oa);
    set_reg_var(get_default_register_name());
  }

  // Get the length of mapped chars again after typing a count, second
  // character or "z333<cr>".
  if (s->old_mapped_len > 0) {
    s->old_mapped_len = typebuf_maplen();
  }

  // If an operation is pending, handle it.  But not for K_IGNORE or
  // K_MOUSEMOVE.
  if (s->ca.cmdchar != K_IGNORE && s->ca.cmdchar != K_MOUSEMOVE) {
    do_pending_operator(&s->ca, s->old_col, false);
  }

  // Wait for a moment when a message is displayed that will be overwritten
  // by the mode message.
  if (normal_need_redraw_mode_message(s)) {
    normal_redraw_mode_message(s);
  }

  // Finish up after executing a Normal mode command.
normal_end:

  msg_nowait = false;

  if (finish_op) {
    set_reg_var(get_default_register_name());
  }

  const bool prev_finish_op = finish_op;
  if (s->oa.op_type == OP_NOP) {
    // Reset finish_op, in case it was set
    finish_op = false;
    may_trigger_modechanged();
  }
  // Redraw the cursor with another shape, if we were in Operator-pending
  // mode or did a replace command.
  if (prev_finish_op || s->ca.cmdchar == 'r'
      || (s->ca.cmdchar == 'g' && s->ca.nchar == 'r')) {
    ui_cursor_shape();                  // may show different cursor shape
  }

  if (s->oa.op_type == OP_NOP && s->oa.regname == 0
      && s->ca.cmdchar != K_EVENT) {
    clear_showcmd();
  }

  checkpcmark();                // check if we moved since setting pcmark
  xfree(s->ca.searchbuf);

  mb_check_adjust_col(curwin);  // #6203

  if (curwin->w_p_scb && s->toplevel) {
    validate_cursor(curwin);          // may need to update w_leftcol
    do_check_scrollbind(true);
  }

  if (curwin->w_p_crb && s->toplevel) {
    validate_cursor(curwin);          // may need to update w_leftcol
    do_check_cursorbind();
  }

  // May restart edit(), if we got here with CTRL-O in Insert mode (but not
  // if still inside a mapping that started in Visual mode).
  // May switch from Visual to Select mode after CTRL-O command.
  if (s->oa.op_type == OP_NOP
      && ((restart_edit != 0 && !VIsual_active && s->old_mapped_len == 0)
          || restart_VIsual_select == 1)
      && !(s->ca.retval & CA_COMMAND_BUSY)
      && stuff_empty()
      && s->oa.regname == 0) {
    if (restart_VIsual_select == 1) {
      VIsual_select = true;
      VIsual_select_reg = 0;
      may_trigger_modechanged();
      showmode();
      restart_VIsual_select = 0;
    }
    if (restart_edit != 0 && !VIsual_active && s->old_mapped_len == 0) {
      edit(restart_edit, false, 1);
    }
  }

  if (restart_VIsual_select == 2) {
    restart_VIsual_select = 1;
  }

  // Save count before an operator for next time
  opcount = s->ca.opcount;
}

static int normal_execute(VimState *state, int key)
{
  NormalState *s = (NormalState *)state;
  s->command_finished = false;
  s->ctrl_w = false;                  // got CTRL-W command
  s->old_col = curwin->w_curswant;
  s->c = key;

  LANGMAP_ADJUST(s->c, get_real_state() != MODE_SELECT);

  // If a mapping was started in Visual or Select mode, remember the length
  // of the mapping.  This is used below to not return to Insert mode for as
  // long as the mapping is being executed.
  if (restart_edit == 0) {
    s->old_mapped_len = 0;
  } else if (s->old_mapped_len || (VIsual_active && s->mapped_len == 0
                                   && typebuf_maplen() > 0)) {
    s->old_mapped_len = typebuf_maplen();
  }

  if (s->c == NUL) {
    s->c = K_ZERO;
  }

  // In Select mode, typed text replaces the selection.
  if (VIsual_active && VIsual_select && (vim_isprintc(s->c)
                                         || s->c == NL || s->c == CAR || s->c == K_KENTER)) {
    // Fake a "c"hange command.
    // When "restart_edit" is set fake a "d"elete command, Insert mode will restart automatically.
    // Insert the typed character in the typeahead buffer, so that it can
    // be mapped in Insert mode.  Required for ":lmap" to work.
    int len = ins_char_typebuf(vgetc_char, vgetc_mod_mask, true);

    // When recording and gotchars() was called the character will be
    // recorded again, remove the previous recording.
    if (KeyTyped) {
      ungetchars(len);
    }

    if (restart_edit != 0) {
      s->c = 'd';
    } else {
      s->c = 'c';
    }
    msg_nowait = true;          // don't delay going to insert mode
    s->old_mapped_len = 0;      // do go to Insert mode
  }

  s->need_flushbuf = add_to_showcmd(s->c);

  while (normal_get_command_count(s)) {}

  if (s->c == K_EVENT) {
    // Save the count values so that ca.opcount and ca.count0 are exactly
    // the same when coming back here after handling K_EVENT.
    s->oa.prev_opcount = s->ca.opcount;
    s->oa.prev_count0 = s->ca.count0;
  } else if (s->ca.opcount != 0) {
    // If we're in the middle of an operator (including after entering a
    // yank buffer with '"') AND we had a count before the operator, then
    // that count overrides the current value of ca.count0.
    // What this means effectively, is that commands like "3dw" get turned
    // into "d3w" which makes things fall into place pretty neatly.
    // If you give a count before AND after the operator, they are
    // multiplied.
    if (s->ca.count0) {
      if (s->ca.opcount >= 999999999 / s->ca.count0) {
        s->ca.count0 = 999999999;
      } else {
        s->ca.count0 *= s->ca.opcount;
      }
    } else {
      s->ca.count0 = s->ca.opcount;
    }
  }

  // Always remember the count.  It will be set to zero (on the next call,
  // above) when there is no pending operator.
  // When called from main(), save the count for use by the "count" built-in
  // variable.
  s->ca.opcount = s->ca.count0;
  s->ca.count1 = (s->ca.count0 == 0 ? 1 : s->ca.count0);

  // Only set v:count when called from main() and not a stuffed command.
  // Do set it for redo.
  if (s->toplevel && readbuf1_empty()) {
    set_vcount(s->ca.count0, s->ca.count1, s->set_prevcount);
  }

  // Find the command character in the table of commands.
  // For CTRL-W we already got nchar when looking for a count.
  if (s->ctrl_w) {
    s->ca.nchar = s->c;
    s->ca.cmdchar = Ctrl_W;
  } else {
    s->ca.cmdchar = s->c;
  }

  s->idx = find_command(s->ca.cmdchar);

  if (s->idx < 0) {
    // Not a known command: beep.
    clearopbeep(&s->oa);
    s->command_finished = true;
    goto finish;
  }

  if ((nv_cmds[s->idx].cmd_flags & NV_NCW) && check_text_or_curbuf_locked(&s->oa)) {
    // this command is not allowed now
    s->command_finished = true;
    goto finish;
  }

  // In Visual/Select mode, a few keys are handled in a special way.
  if (VIsual_active && normal_handle_special_visual_command(s)) {
    s->command_finished = true;
    goto finish;
  }

  if (curwin->w_p_rl && KeyTyped && !KeyStuffed
      && (nv_cmds[s->idx].cmd_flags & NV_RL)) {
    // Invert horizontal movements and operations.  Only when typed by the
    // user directly, not when the result of a mapping or "x" translated
    // to "dl".
    normal_invert_horizontal(s);
  }

  // Get an additional character if we need one.
  if (normal_need_additional_char(s)) {
    normal_get_additional_char(s);
  }

  // Flush the showcmd characters onto the screen so we can see them while
  // the command is being executed.  Only do this when the shown command was
  // actually displayed, otherwise this will slow down a lot when executing
  // mappings.
  if (s->need_flushbuf) {
    ui_flush();
  }

  if (s->ca.cmdchar != K_IGNORE && s->ca.cmdchar != K_EVENT) {
    did_cursorhold = false;
  }

  State = MODE_NORMAL;

  if (s->ca.nchar == ESC || s->ca.extra_char == ESC) {
    clearop(&s->oa);
    s->command_finished = true;
    goto finish;
  }

  if (s->ca.cmdchar != K_IGNORE) {
    msg_didout = false;        // don't scroll screen up for normal command
    msg_col = 0;
  }

  s->old_pos = curwin->w_cursor;           // remember where the cursor was

  // When 'keymodel' contains "startsel" some keys start Select/Visual
  // mode.
  if (!VIsual_active && km_startsel) {
    if (nv_cmds[s->idx].cmd_flags & NV_SS) {
      start_selection();
      unshift_special(&s->ca);
      s->idx = find_command(s->ca.cmdchar);
      assert(s->idx >= 0);
    } else if ((nv_cmds[s->idx].cmd_flags & NV_SSS)
               && (mod_mask & MOD_MASK_SHIFT)) {
      start_selection();
      mod_mask &= ~MOD_MASK_SHIFT;
    }
  }

  // Execute the command!
  // Call the command function found in the commands table.
  s->ca.arg = nv_cmds[s->idx].cmd_arg;
  (nv_cmds[s->idx].cmd_func)(&s->ca);

finish:
  normal_finish_command(s);
  return 1;
}

static void normal_check_stuff_buffer(NormalState *s)
{
  if (stuff_empty()) {
    did_check_timestamps = false;

    if (need_check_timestamps) {
      check_timestamps(false);
    }

    if (need_wait_return) {
      // if wait_return still needed call it now
      wait_return(false);
    }
  }
}

static void normal_check_interrupt(NormalState *s)
{
  // Reset "got_int" now that we got back to the main loop.  Except when
  // inside a ":g/pat/cmd" command, then the "got_int" needs to abort
  // the ":g" command.
  // For ":g/pat/vi" we reset "got_int" when used once.  When used
  // a second time we go back to Ex mode and abort the ":g" command.
  if (got_int) {
    if (s->noexmode && global_busy && !exmode_active
        && s->previous_got_int) {
      // Typed two CTRL-C in a row: go back to ex mode as if "Q" was
      // used and keep "got_int" set, so that it aborts ":g".
      exmode_active = true;
      State = MODE_NORMAL;
    } else if (!global_busy || !exmode_active) {
      if (!quit_more) {
        // flush all buffers
        vgetc();
      }
      got_int = false;
    }
    s->previous_got_int = true;
  } else {
    s->previous_got_int = false;
  }
}

static void normal_check_window_scrolled(NormalState *s)
{
  if (!finish_op) {
    may_trigger_win_scrolled_resized();
  }
}

static void normal_check_cursor_moved(NormalState *s)
{
  // Trigger CursorMoved if the cursor moved.
  if (!finish_op && has_event(EVENT_CURSORMOVED)
      && (last_cursormoved_win != curwin
          || !equalpos(last_cursormoved, curwin->w_cursor))) {
    apply_autocmds(EVENT_CURSORMOVED, NULL, NULL, false, curbuf);
    last_cursormoved_win = curwin;
    last_cursormoved = curwin->w_cursor;
  }
}

static void normal_check_text_changed(NormalState *s)
{
  // Trigger TextChanged if changedtick differs.
  if (!finish_op && has_event(EVENT_TEXTCHANGED)
      && curbuf->b_last_changedtick != buf_get_changedtick(curbuf)) {
    apply_autocmds(EVENT_TEXTCHANGED, NULL, NULL, false, curbuf);
    curbuf->b_last_changedtick = buf_get_changedtick(curbuf);
  }
}

static void normal_check_buffer_modified(NormalState *s)
{
  // Trigger BufModified if b_modified changed
  if (!finish_op && has_event(EVENT_BUFMODIFIEDSET)
      && curbuf->b_changed_invalid == true) {
    apply_autocmds(EVENT_BUFMODIFIEDSET, NULL, NULL, false, curbuf);
    curbuf->b_changed_invalid = false;
  }
}

/// If nothing is pending and we are going to wait for the user to
/// type a character, trigger SafeState.
static void normal_check_safe_state(NormalState *s)
{
  may_trigger_safestate(!op_pending() && restart_edit == 0);
}

static void normal_check_folds(NormalState *s)
{
  // Include a closed fold completely in the Visual area.
  foldAdjustVisual();

  // When 'foldclose' is set, apply 'foldlevel' to folds that don't
  // contain the cursor.
  // When 'foldopen' is "all", open the fold(s) under the cursor.
  // This may mark the window for redrawing.
  if (hasAnyFolding(curwin) && !char_avail()) {
    foldCheckClose();

    if (fdo_flags & FDO_ALL) {
      foldOpenCursor();
    }
  }
}

static void normal_redraw(NormalState *s)
{
  // Before redrawing, make sure w_topline is correct, and w_leftcol
  // if lines don't wrap, and w_skipcol if lines wrap.
  update_topline(curwin);
  validate_cursor(curwin);

  show_cursor_info_later(false);

  if (must_redraw) {
    update_screen();
  } else {
    redraw_statuslines();
    if (redraw_cmdline || clear_cmdline || redraw_mode) {
      showmode();
    }
  }

  if (need_maketitle) {
    maketitle();
  }

  curbuf->b_last_used = time(NULL);

  // Display message after redraw. If an external message is still visible,
  // it contains the kept message already.
  if (keep_msg != NULL && !msg_ext_is_visible()) {
    char *const p = xstrdup(keep_msg);

    // msg_start() will set keep_msg to NULL, make a copy
    // first.  Don't reset keep_msg, msg_attr_keep() uses it to
    // check for duplicates.  Never put this message in
    // history.
    msg_hist_off = true;
    msg(p, keep_msg_attr);
    msg_hist_off = false;
    xfree(p);
  }

  // show fileinfo after redraw
  if (need_fileinfo && !shortmess(SHM_FILEINFO)) {
    fileinfo(false, true, false);
    need_fileinfo = false;
  }

  emsg_on_display = false;  // can delete error message now
  did_emsg = false;
  msg_didany = false;  // reset lines_left in msg_start()
  may_clear_sb_text();  // clear scroll-back text on next msg

  setcursor();
}

/// Function executed before each iteration of normal mode.
///
/// @return:
///           1 if the iteration should continue normally
///          -1 if the iteration should be skipped
///           0 if the main loop must exit
static int normal_check(VimState *state)
{
  NormalState *s = (NormalState *)state;
  normal_check_stuff_buffer(s);
  normal_check_interrupt(s);

  // At the toplevel there is no exception handling.  Discard any that
  // may be hanging around (e.g. from "interrupt" at the debug prompt).
  if (did_throw && !ex_normal_busy) {
    discard_current_exception();
  }

  if (!exmode_active) {
    msg_scroll = false;
  }
  quit_more = false;

  state_no_longer_safe(NULL);

  // If skip redraw is set (for ":" in wait_return()), don't redraw now.
  // If there is nothing in the stuff_buffer or do_redraw is true,
  // update cursor and redraw.
  if (skip_redraw || exmode_active) {
    skip_redraw = false;
    setcursor();
  } else if (do_redraw || stuff_empty()) {
    // Ensure curwin->w_topline and curwin->w_leftcol are up to date
    // before triggering a WinScrolled autocommand.
    update_topline(curwin);
    validate_cursor(curwin);

    normal_check_cursor_moved(s);
    normal_check_text_changed(s);
    normal_check_window_scrolled(s);
    normal_check_buffer_modified(s);
    normal_check_safe_state(s);

    // Updating diffs from changed() does not always work properly,
    // esp. updating folds.  Do an update just before redrawing if
    // needed.
    if (curtab->tp_diff_update || curtab->tp_diff_invalid) {
      ex_diffupdate(NULL);
      curtab->tp_diff_update = false;
    }

    // Scroll-binding for diff mode may have been postponed until
    // here.  Avoids doing it for every change.
    if (diff_need_scrollbind) {
      check_scrollbind(0, 0);
      diff_need_scrollbind = false;
    }

    normal_check_folds(s);
    normal_redraw(s);
    do_redraw = false;

    // Now that we have drawn the first screen all the startup stuff
    // has been done, close any file for startup messages.
    if (time_fd != NULL) {
      TIME_MSG("first screen update");
      time_finish();
    }
    // After the first screen update may start triggering WinScrolled
    // autocmd events.  Store all the scroll positions and sizes now.
    may_make_initial_scroll_size_snapshot();
  }

  // May perform garbage collection when waiting for a character, but
  // only at the very toplevel.  Otherwise we may be using a List or
  // Dict internally somewhere.
  // "may_garbage_collect" is reset in vgetc() which is invoked through
  // do_exmode() and normal_cmd().
  may_garbage_collect = !s->cmdwin && !s->noexmode;

  // Update w_curswant if w_set_curswant has been set.
  // Postponed until here to avoid computing w_virtcol too often.
  update_curswant();

  if (exmode_active) {
    if (s->noexmode) {
      return 0;
    }
    do_exmode();
    return -1;
  }

  if (s->cmdwin && cmdwin_result != 0) {
    // command-line window and cmdwin_result is set
    return 0;
  }

  normal_prepare(s);
  return 1;
}

/// Set v:count and v:count1 according to "cap".
/// Set v:prevcount only when "set_prevcount" is true.
static void set_vcount_ca(cmdarg_T *cap, bool *set_prevcount)
{
  int64_t count = cap->count0;

  // multiply with cap->opcount the same way as above
  if (cap->opcount != 0) {
    count = cap->opcount * (count == 0 ? 1 : count);
  }
  set_vcount(count, count == 0 ? 1 : count, *set_prevcount);
  *set_prevcount = false;    // only set v:prevcount once
}

/// End Visual mode.
/// This function should ALWAYS be called to end Visual mode, except from
/// do_pending_operator().
void end_visual_mode(void)
{
  VIsual_active = false;
  setmouse();
  mouse_dragging = 0;

  // Save the current VIsual area for '< and '> marks, and "gv"
  curbuf->b_visual.vi_mode = VIsual_mode;
  curbuf->b_visual.vi_start = VIsual;
  curbuf->b_visual.vi_end = curwin->w_cursor;
  curbuf->b_visual.vi_curswant = curwin->w_curswant;
  curbuf->b_visual_mode_eval = VIsual_mode;
  if (!virtual_active(curwin)) {
    curwin->w_cursor.coladd = 0;
  }

  may_clear_cmdline();

  adjust_cursor_eol();
  may_trigger_modechanged();
}

/// Reset VIsual_active and VIsual_reselect.
void reset_VIsual_and_resel(void)
{
  if (VIsual_active) {
    end_visual_mode();
    redraw_curbuf_later(UPD_INVERTED);  // delete the inversion later
  }
  VIsual_reselect = false;
}

/// Reset VIsual_active and VIsual_reselect if it's set.
void reset_VIsual(void)
{
  if (VIsual_active) {
    end_visual_mode();
    redraw_curbuf_later(UPD_INVERTED);  // delete the inversion later
    VIsual_reselect = false;
  }
}

void restore_visual_mode(void)
{
  if (VIsual_mode_orig != NUL) {
    curbuf->b_visual.vi_mode = VIsual_mode_orig;
    VIsual_mode_orig = NUL;
  }
}

/// Check for a balloon-eval special item to include when searching for an
/// identifier.  When "dir" is BACKWARD "ptr[-1]" must be valid!
///
/// @return  true if the character at "*ptr" should be included.
///
/// @param dir    the direction of searching, is either FORWARD or BACKWARD
/// @param *colp  is in/decremented if "ptr[-dir]" should also be included.
/// @param bnp    points to a counter for square brackets.
static bool find_is_eval_item(const char *const ptr, int *const colp, int *const bnp, const int dir)
{
  // Accept everything inside [].
  if ((*ptr == ']' && dir == BACKWARD) || (*ptr == '[' && dir == FORWARD)) {
    *bnp += 1;
  }
  if (*bnp > 0) {
    if ((*ptr == '[' && dir == BACKWARD) || (*ptr == ']' && dir == FORWARD)) {
      *bnp -= 1;
    }
    return true;
  }

  // skip over "s.var"
  if (*ptr == '.') {
    return true;
  }

  // two-character item: s->var
  if (ptr[dir == BACKWARD ? 0 : 1] == '>'
      && ptr[dir == BACKWARD ? -1 : 0] == '-') {
    *colp += dir;
    return true;
  }
  return false;
}

/// Find the identifier under or to the right of the cursor.
/// "find_type" can have one of three values:
/// FIND_IDENT:   find an identifier (keyword)
/// FIND_STRING:  find any non-white text
/// FIND_IDENT + FIND_STRING: find any non-white text, identifier preferred.
/// FIND_EVAL:  find text useful for C program debugging
///
/// There are three steps:
/// 1. Search forward for the start of an identifier/text.  Doesn't move if
///    already on one.
/// 2. Search backward for the start of this identifier/text.
///    This doesn't match the real Vi but I like it a little better and it
///    shouldn't bother anyone.
/// 3. Search forward to the end of this identifier/text.
///    When FIND_IDENT isn't defined, we backup until a blank.
///
/// @return  the length of the text, or zero if no text is found.
///
/// If text is found, a pointer to the text is put in "*text".  This
/// points into the current buffer line and is not always NUL terminated.
size_t find_ident_under_cursor(char **text, int find_type)
  FUNC_ATTR_NONNULL_ARG(1)
{
  return find_ident_at_pos(curwin, curwin->w_cursor.lnum,
                           curwin->w_cursor.col, text, NULL, find_type);
}

/// Like find_ident_under_cursor(), but for any window and any position.
/// However: Uses 'iskeyword' from the current window!.
///
/// @param textcol  column where "text" starts, can be NULL
size_t find_ident_at_pos(win_T *wp, linenr_T lnum, colnr_T startcol, char **text, int *textcol,
                         int find_type)
  FUNC_ATTR_NONNULL_ARG(1, 4)
{
  int col = 0;         // init to shut up GCC
  int i;
  int this_class = 0;
  int prev_class;
  int prevcol;
  int bn = 0;                       // bracket nesting

  // if i == 0: try to find an identifier
  // if i == 1: try to find any non-white text
  char *ptr = ml_get_buf(wp->w_buffer, lnum);
  for (i = (find_type & FIND_IDENT) ? 0 : 1; i < 2; i++) {
    // 1. skip to start of identifier/text
    col = startcol;
    while (ptr[col] != NUL) {
      // Stop at a ']' to evaluate "a[x]".
      if ((find_type & FIND_EVAL) && ptr[col] == ']') {
        break;
      }
      this_class = mb_get_class(ptr + col);
      if (this_class != 0 && (i == 1 || this_class != 1)) {
        break;
      }
      col += utfc_ptr2len(ptr + col);
    }

    // When starting on a ']' count it, so that we include the '['.
    bn = ptr[col] == ']';

    //
    // 2. Back up to start of identifier/text.
    //
    // Remember class of character under cursor.
    if ((find_type & FIND_EVAL) && ptr[col] == ']') {
      this_class = mb_get_class("a");
    } else {
      this_class = mb_get_class(ptr + col);
    }
    while (col > 0 && this_class != 0) {
      prevcol = col - 1 - utf_head_off(ptr, ptr + col - 1);
      prev_class = mb_get_class(ptr + prevcol);
      if (this_class != prev_class
          && (i == 0
              || prev_class == 0
              || (find_type & FIND_IDENT))
          && (!(find_type & FIND_EVAL)
              || prevcol == 0
              || !find_is_eval_item(ptr + prevcol, &prevcol, &bn, BACKWARD))) {
        break;
      }
      col = prevcol;
    }

    // If we don't want just any old text, or we've found an
    // identifier, stop searching.
    if (this_class > 2) {
      this_class = 2;
    }
    if (!(find_type & FIND_STRING) || this_class == 2) {
      break;
    }
  }

  if (ptr[col] == NUL || (i == 0 && this_class != 2)) {
    // Didn't find an identifier or text.
    if (find_type & FIND_STRING) {
      emsg(_("E348: No string under cursor"));
    } else {
      emsg(_(e_noident));
    }
    return 0;
  }
  ptr += col;
  *text = ptr;
  if (textcol != NULL) {
    *textcol = col;
  }

  // 3. Find the end if the identifier/text.
  bn = 0;
  startcol -= col;
  col = 0;
  // Search for point of changing multibyte character class.
  this_class = mb_get_class(ptr);
  while (ptr[col] != NUL
         && ((i == 0
              ? mb_get_class(ptr + col) == this_class
              : mb_get_class(ptr + col) != 0)
             || ((find_type & FIND_EVAL)
                 && col <= (int)startcol
                 && find_is_eval_item(ptr + col, &col, &bn, FORWARD)))) {
    col += utfc_ptr2len(ptr + col);
  }

  assert(col >= 0);
  return (size_t)col;
}

/// Prepare for redo of a normal command.
static void prep_redo_cmd(cmdarg_T *cap)
{
  prep_redo(cap->oap->regname, cap->count0,
            NUL, cap->cmdchar, NUL, NUL, cap->nchar);
}

/// Prepare for redo of any command.
/// Note that only the last argument can be a multi-byte char.
void prep_redo(int regname, int num, int cmd1, int cmd2, int cmd3, int cmd4, int cmd5)
{
  prep_redo_num2(regname, num, cmd1, cmd2, 0, cmd3, cmd4, cmd5);
}

/// Prepare for redo of any command with extra count after "cmd2".
void prep_redo_num2(int regname, int num1, int cmd1, int cmd2, int num2, int cmd3, int cmd4,
                    int cmd5)
{
  ResetRedobuff();
  if (regname != 0) {   // yank from specified buffer
    AppendCharToRedobuff('"');
    AppendCharToRedobuff(regname);
  }
  if (num1 != 0) {
    AppendNumberToRedobuff(num1);
  }
  if (cmd1 != NUL) {
    AppendCharToRedobuff(cmd1);
  }
  if (cmd2 != NUL) {
    AppendCharToRedobuff(cmd2);
  }
  if (num2 != 0) {
    AppendNumberToRedobuff(num2);
  }
  if (cmd3 != NUL) {
    AppendCharToRedobuff(cmd3);
  }
  if (cmd4 != NUL) {
    AppendCharToRedobuff(cmd4);
  }
  if (cmd5 != NUL) {
    AppendCharToRedobuff(cmd5);
  }
}

/// Check for operator active and clear it.
///
/// Beep and return true if an operator was active.
static bool checkclearop(oparg_T *oap)
{
  if (oap->op_type == OP_NOP) {
    return false;
  }
  clearopbeep(oap);
  return true;
}

/// Check for operator or Visual active.  Clear active operator.
///
/// Beep and return true if an operator or Visual was active.
static bool checkclearopq(oparg_T *oap)
{
  if (oap->op_type == OP_NOP && !VIsual_active) {
    return false;
  }
  clearopbeep(oap);
  return true;
}

void clearop(oparg_T *oap)
{
  oap->op_type = OP_NOP;
  oap->regname = 0;
  oap->motion_force = NUL;
  oap->use_reg_one = false;
  motion_force = NUL;
}

void clearopbeep(oparg_T *oap)
{
  clearop(oap);
  beep_flush();
}

/// Remove the shift modifier from a special key.
static void unshift_special(cmdarg_T *cap)
{
  switch (cap->cmdchar) {
  case K_S_RIGHT:
    cap->cmdchar = K_RIGHT; break;
  case K_S_LEFT:
    cap->cmdchar = K_LEFT; break;
  case K_S_UP:
    cap->cmdchar = K_UP; break;
  case K_S_DOWN:
    cap->cmdchar = K_DOWN; break;
  case K_S_HOME:
    cap->cmdchar = K_HOME; break;
  case K_S_END:
    cap->cmdchar = K_END; break;
  }
  cap->cmdchar = simplify_key(cap->cmdchar, &mod_mask);
}

/// If the mode is currently displayed clear the command line or update the
/// command displayed.
void may_clear_cmdline(void)
{
  if (mode_displayed) {
    // unshow visual mode later
    clear_cmdline = true;
  } else {
    clear_showcmd();
  }
}

// Routines for displaying a partly typed command
static char old_showcmd_buf[SHOWCMD_BUFLEN];    // For push_showcmd()
static bool showcmd_is_clear = true;
static bool showcmd_visual = false;

void clear_showcmd(void)
{
  if (!p_sc) {
    return;
  }

  if (VIsual_active && !char_avail()) {
    bool cursor_bot = lt(VIsual, curwin->w_cursor);
    int lines;
    colnr_T leftcol, rightcol;
    linenr_T top, bot;

    // Show the size of the Visual area.
    if (cursor_bot) {
      top = VIsual.lnum;
      bot = curwin->w_cursor.lnum;
    } else {
      top = curwin->w_cursor.lnum;
      bot = VIsual.lnum;
    }
    // Include closed folds as a whole.
    hasFolding(curwin, top, &top, NULL);
    hasFolding(curwin, bot, NULL, &bot);
    lines = bot - top + 1;

    if (VIsual_mode == Ctrl_V) {
      char *const saved_sbr = p_sbr;
      char *const saved_w_sbr = curwin->w_p_sbr;

      // Make 'sbr' empty for a moment to get the correct size.
      p_sbr = empty_string_option;
      curwin->w_p_sbr = empty_string_option;
      getvcols(curwin, &curwin->w_cursor, &VIsual, &leftcol, &rightcol);
      p_sbr = saved_sbr;
      curwin->w_p_sbr = saved_w_sbr;
      snprintf(showcmd_buf, SHOWCMD_BUFLEN, "%" PRId64 "x%" PRId64,
               (int64_t)lines, (int64_t)rightcol - leftcol + 1);
    } else if (VIsual_mode == 'V' || VIsual.lnum != curwin->w_cursor.lnum) {
      snprintf(showcmd_buf, SHOWCMD_BUFLEN, "%" PRId64, (int64_t)lines);
    } else {
      char *s, *e;
      int bytes = 0;
      int chars = 0;

      if (cursor_bot) {
        s = ml_get_pos(&VIsual);
        e = get_cursor_pos_ptr();
      } else {
        s = get_cursor_pos_ptr();
        e = ml_get_pos(&VIsual);
      }
      while ((*p_sel != 'e') ? s <= e : s < e) {
        int l = utfc_ptr2len(s);
        if (l == 0) {
          bytes++;
          chars++;
          break;            // end of line
        }
        bytes += l;
        chars++;
        s += l;
      }
      if (bytes == chars) {
        snprintf(showcmd_buf, SHOWCMD_BUFLEN, "%d", chars);
      } else {
        snprintf(showcmd_buf, SHOWCMD_BUFLEN, "%d-%d", chars, bytes);
      }
    }
    int limit = ui_has(kUIMessages) ? SHOWCMD_BUFLEN - 1 : SHOWCMD_COLS;
    showcmd_buf[limit] = NUL;  // truncate
    showcmd_visual = true;
  } else {
    showcmd_buf[0] = NUL;
    showcmd_visual = false;

    // Don't actually display something if there is nothing to clear.
    if (showcmd_is_clear) {
      return;
    }
  }

  display_showcmd();
}

/// Add 'c' to string of shown command chars.
///
/// @return  true if output has been written (and setcursor() has been called).
bool add_to_showcmd(int c)
{
  static int ignore[] = {
    K_IGNORE,
    K_LEFTMOUSE, K_LEFTDRAG, K_LEFTRELEASE, K_MOUSEMOVE,
    K_MIDDLEMOUSE, K_MIDDLEDRAG, K_MIDDLERELEASE,
    K_RIGHTMOUSE, K_RIGHTDRAG, K_RIGHTRELEASE,
    K_MOUSEDOWN, K_MOUSEUP, K_MOUSELEFT, K_MOUSERIGHT,
    K_X1MOUSE, K_X1DRAG, K_X1RELEASE, K_X2MOUSE, K_X2DRAG, K_X2RELEASE,
    K_EVENT,
    0
  };

  if (!p_sc || msg_silent != 0) {
    return false;
  }

  if (showcmd_visual) {
    showcmd_buf[0] = NUL;
    showcmd_visual = false;
  }

  // Ignore keys that are scrollbar updates and mouse clicks
  if (IS_SPECIAL(c)) {
    for (int i = 0; ignore[i] != 0; i++) {
      if (ignore[i] == c) {
        return false;
      }
    }
  }

  char *p;
  char mbyte_buf[MB_MAXCHAR + 1];
  if (c <= 0x7f || !vim_isprintc(c)) {
    p = transchar(c);
    if (*p == ' ') {
      STRCPY(p, "<20>");
    }
  } else {
    mbyte_buf[utf_char2bytes(c, mbyte_buf)] = NUL;
    p = mbyte_buf;
  }
  size_t old_len = strlen(showcmd_buf);
  size_t extra_len = strlen(p);
  size_t limit = ui_has(kUIMessages) ? SHOWCMD_BUFLEN - 1 : SHOWCMD_COLS;
  if (old_len + extra_len > limit) {
    size_t overflow = old_len + extra_len - limit;
    memmove(showcmd_buf, showcmd_buf + overflow, old_len - overflow + 1);
  }
  STRCAT(showcmd_buf, p);

  if (char_avail()) {
    return false;
  }

  display_showcmd();

  return true;
}

void add_to_showcmd_c(int c)
{
  add_to_showcmd(c);
  setcursor();
}

/// Delete 'len' characters from the end of the shown command.
static void del_from_showcmd(int len)
{
  if (!p_sc) {
    return;
  }

  int old_len = (int)strlen(showcmd_buf);
  if (len > old_len) {
    len = old_len;
  }
  showcmd_buf[old_len - len] = NUL;

  if (!char_avail()) {
    display_showcmd();
  }
}

/// push_showcmd() and pop_showcmd() are used when waiting for the user to type
/// something and there is a partial mapping.
void push_showcmd(void)
{
  if (p_sc) {
    STRCPY(old_showcmd_buf, showcmd_buf);
  }
}

void pop_showcmd(void)
{
  if (!p_sc) {
    return;
  }

  STRCPY(showcmd_buf, old_showcmd_buf);

  display_showcmd();
}

static void display_showcmd(void)
{
  showcmd_is_clear = (showcmd_buf[0] == NUL);

  if (*p_sloc == 's') {
    if (showcmd_is_clear) {
      curwin->w_redr_status = true;
    } else {
      win_redr_status(curwin);
      setcursor();  // put cursor back where it belongs
    }
    return;
  }
  if (*p_sloc == 't') {
    if (showcmd_is_clear) {
      redraw_tabline = true;
    } else {
      draw_tabline();
      setcursor();  // put cursor back where it belongs
    }
    return;
  }
  // 'showcmdloc' is "last" or empty

  if (ui_has(kUIMessages)) {
    MAXSIZE_TEMP_ARRAY(content, 1);
    MAXSIZE_TEMP_ARRAY(chunk, 2);
    if (!showcmd_is_clear) {
      // placeholder for future highlight support
      ADD_C(chunk, INTEGER_OBJ(0));
      ADD_C(chunk, CSTR_AS_OBJ(showcmd_buf));
      ADD_C(content, ARRAY_OBJ(chunk));
    }
    ui_call_msg_showcmd(content);
    return;
  }
  if (p_ch == 0) {
    return;
  }

  msg_grid_validate();
  int showcmd_row = Rows - 1;
  grid_line_start(&msg_grid_adj, showcmd_row);

  int len = 0;
  if (!showcmd_is_clear) {
    len = grid_line_puts(sc_col, showcmd_buf, -1, HL_ATTR(HLF_MSG));
  }

  // clear the rest of an old message by outputting up to SHOWCMD_COLS spaces
  grid_line_puts(sc_col + len, (char *)"          " + len, -1, HL_ATTR(HLF_MSG));

  grid_line_flush();
}

/// When "check" is false, prepare for commands that scroll the window.
/// When "check" is true, take care of scroll-binding after the window has
/// scrolled.  Called from normal_cmd() and edit().
void do_check_scrollbind(bool check)
{
  static win_T *old_curwin = NULL;
  static linenr_T old_topline = 0;
  static int old_topfill = 0;
  static buf_T *old_buf = NULL;
  static colnr_T old_leftcol = 0;

  if (check && curwin->w_p_scb) {
    // If a ":syncbind" command was just used, don't scroll, only reset
    // the values.
    if (did_syncbind) {
      did_syncbind = false;
    } else if (curwin == old_curwin) {
      // Synchronize other windows, as necessary according to
      // 'scrollbind'.  Don't do this after an ":edit" command, except
      // when 'diff' is set.
      if ((curwin->w_buffer == old_buf
           || curwin->w_p_diff
           )
          && (curwin->w_topline != old_topline
              || curwin->w_topfill != old_topfill
              || curwin->w_leftcol != old_leftcol)) {
        check_scrollbind(curwin->w_topline - old_topline, curwin->w_leftcol - old_leftcol);
      }
    } else if (vim_strchr(p_sbo, 'j')) {  // jump flag set in 'scrollopt'
      // When switching between windows, make sure that the relative
      // vertical offset is valid for the new window.  The relative
      // offset is invalid whenever another 'scrollbind' window has
      // scrolled to a point that would force the current window to
      // scroll past the beginning or end of its buffer.  When the
      // resync is performed, some of the other 'scrollbind' windows may
      // need to jump so that the current window's relative position is
      // visible on-screen.
      check_scrollbind(curwin->w_topline - (linenr_T)curwin->w_scbind_pos, 0);
    }
    curwin->w_scbind_pos = curwin->w_topline;
  }

  old_curwin = curwin;
  old_topline = curwin->w_topline;
  old_topfill = curwin->w_topfill;
  old_buf = curwin->w_buffer;
  old_leftcol = curwin->w_leftcol;
}

/// Synchronize any windows that have "scrollbind" set, based on the
/// number of rows by which the current window has changed
/// (1998-11-02 16:21:01  R. Edward Ralston <eralston@computer.org>)
void check_scrollbind(linenr_T topline_diff, int leftcol_diff)
{
  win_T *old_curwin = curwin;
  buf_T *old_curbuf = curbuf;
  int old_VIsual_select = VIsual_select;
  int old_VIsual_active = VIsual_active;
  colnr_T tgt_leftcol = curwin->w_leftcol;
  linenr_T topline;
  linenr_T y;

  // check 'scrollopt' string for vertical and horizontal scroll options
  bool want_ver = (vim_strchr(p_sbo, 'v') && topline_diff != 0);
  want_ver |= old_curwin->w_p_diff;
  bool want_hor = (vim_strchr(p_sbo, 'h') && (leftcol_diff || topline_diff != 0));

  // loop through the scrollbound windows and scroll accordingly
  VIsual_select = VIsual_active = 0;
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    curwin = wp;
    curbuf = curwin->w_buffer;
    // skip original window and windows with 'noscrollbind'
    if (curwin == old_curwin || !curwin->w_p_scb) {
      continue;
    }

    // do the vertical scroll
    if (want_ver) {
      if (old_curwin->w_p_diff && curwin->w_p_diff) {
        diff_set_topline(old_curwin, curwin);
      } else {
        curwin->w_scbind_pos += topline_diff;
        topline = (linenr_T)curwin->w_scbind_pos;
        if (topline > curbuf->b_ml.ml_line_count) {
          topline = curbuf->b_ml.ml_line_count;
        }
        if (topline < 1) {
          topline = 1;
        }

        y = topline - curwin->w_topline;
        if (y > 0) {
          scrollup(curwin, y, false);
        } else {
          scrolldown(curwin, -y, false);
        }
      }

      redraw_later(curwin, UPD_VALID);
      cursor_correct(curwin);
      curwin->w_redr_status = true;
    }

    // do the horizontal scroll
    if (want_hor) {
      set_leftcol(tgt_leftcol);
    }
  }

  // reset current-window
  VIsual_select = old_VIsual_select;
  VIsual_active = old_VIsual_active;
  curwin = old_curwin;
  curbuf = old_curbuf;
}

/// Command character that's ignored.
/// Used for CTRL-Q and CTRL-S to avoid problems with terminals that use
/// xon/xoff.
static void nv_ignore(cmdarg_T *cap)
{
  cap->retval |= CA_COMMAND_BUSY;       // don't call edit() now
}

/// Command character that doesn't do anything, but unlike nv_ignore() does
/// start edit().  Used for "startinsert" executed while starting up.
static void nv_nop(cmdarg_T *cap)
{
}

/// Command character doesn't exist.
static void nv_error(cmdarg_T *cap)
{
  clearopbeep(cap->oap);
}

/// <Help> and <F1> commands.
static void nv_help(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap)) {
    ex_help(NULL);
  }
}

/// CTRL-A and CTRL-X: Add or subtract from letter or number under cursor.
static void nv_addsub(cmdarg_T *cap)
{
  if (bt_prompt(curbuf) && !prompt_curpos_editable()) {
    clearopbeep(cap->oap);
  } else if (!VIsual_active && cap->oap->op_type == OP_NOP) {
    prep_redo_cmd(cap);
    cap->oap->op_type = cap->cmdchar == Ctrl_A ? OP_NR_ADD : OP_NR_SUB;
    op_addsub(cap->oap, cap->count1, cap->arg);
    cap->oap->op_type = OP_NOP;
  } else if (VIsual_active) {
    nv_operator(cap);
  } else {
    clearop(cap->oap);
  }
}

/// CTRL-F, CTRL-B, etc: Scroll page up or down.
static void nv_page(cmdarg_T *cap)
{
  if (checkclearop(cap->oap)) {
    return;
  }

  if (mod_mask & MOD_MASK_CTRL) {
    // <C-PageUp>: tab page back; <C-PageDown>: tab page forward
    if (cap->arg == BACKWARD) {
      goto_tabpage(-cap->count1);
    } else {
      goto_tabpage(cap->count0);
    }
  } else {
    pagescroll(cap->arg, cap->count1, false);
  }
}

/// Implementation of "gd" and "gD" command.
///
/// @param thisblock  1 for "1gd" and "1gD"
static void nv_gd(oparg_T *oap, int nchar, int thisblock)
{
  size_t len;
  char *ptr;
  if ((len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0
      || !find_decl(ptr, len, nchar == 'd', thisblock, SEARCH_START)) {
    clearopbeep(oap);
    return;
  }

  if ((fdo_flags & FDO_SEARCH) && KeyTyped && oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
  // clear any search statistics
  if (messaging() && !msg_silent && !shortmess(SHM_SEARCHCOUNT)) {
    clear_cmdline = true;
  }
}

/// @return true if line[offset] is not inside a C-style comment or string,
///         false otherwise.
static bool is_ident(const char *line, int offset)
{
  bool incomment = false;
  int instring = 0;
  int prev = 0;

  for (int i = 0; i < offset && line[i] != NUL; i++) {
    if (instring != 0) {
      if (prev != '\\' && (uint8_t)line[i] == instring) {
        instring = 0;
      }
    } else if ((line[i] == '"' || line[i] == '\'') && !incomment) {
      instring = (uint8_t)line[i];
    } else {
      if (incomment) {
        if (prev == '*' && line[i] == '/') {
          incomment = false;
        }
      } else if (prev == '/' && line[i] == '*') {
        incomment = true;
      } else if (prev == '/' && line[i] == '/') {
        return false;
      }
    }

    prev = (uint8_t)line[i];
  }

  return incomment == false && instring == 0;
}

/// Search for variable declaration of "ptr[len]".
/// When "locally" is true in the current function ("gd"), otherwise in the
/// current file ("gD").
///
/// @param thisblock  when true check the {} block scope.
/// @param flags_arg  flags passed to searchit()
///
/// @return           fail when not found.
bool find_decl(char *ptr, size_t len, bool locally, bool thisblock, int flags_arg)
{
  pos_T par_pos;
  pos_T found_pos;
  bool t;
  bool retval = true;
  bool incll;
  int searchflags = flags_arg;

  size_t patsize = len + 7;
  char *pat = xmalloc(patsize);

  // Put "\V" before the pattern to avoid that the special meaning of "."
  // and "~" causes trouble.
  assert(patsize <= INT_MAX);
  size_t patlen = (size_t)snprintf(pat, patsize,
                                   vim_iswordp(ptr) ? "\\V\\<%.*s\\>" : "\\V%.*s",
                                   (int)len, ptr);
  pos_T old_pos = curwin->w_cursor;
  bool save_p_ws = p_ws;
  bool save_p_scs = p_scs;
  p_ws = false;         // don't wrap around end of file now
  p_scs = false;        // don't switch ignorecase off now

  // With "gD" go to line 1.
  // With "gd" Search back for the start of the current function, then go
  // back until a blank line.  If this fails go to line 1.
  if (!locally || !findpar(&incll, BACKWARD, 1, '{', false)) {
    setpcmark();                        // Set in findpar() otherwise
    curwin->w_cursor.lnum = 1;
    par_pos = curwin->w_cursor;
  } else {
    par_pos = curwin->w_cursor;
    while (curwin->w_cursor.lnum > 1
           && *skipwhite(get_cursor_line_ptr()) != NUL) {
      curwin->w_cursor.lnum--;
    }
  }
  curwin->w_cursor.col = 0;

  // Search forward for the identifier, ignore comment lines.
  clearpos(&found_pos);
  while (true) {
    t = searchit(curwin, curbuf, &curwin->w_cursor, NULL, FORWARD,
                 pat, patlen, 1, searchflags, RE_LAST, NULL);
    if (curwin->w_cursor.lnum >= old_pos.lnum) {
      t = false;         // match after start is failure too
    }

    if (thisblock && t != false) {
      const int64_t maxtravel = old_pos.lnum - curwin->w_cursor.lnum + 1;
      const pos_T *pos = findmatchlimit(NULL, '}', FM_FORWARD, maxtravel);

      // Check that the block the match is in doesn't end before the
      // position where we started the search from.
      if (pos != NULL && pos->lnum < old_pos.lnum) {
        // There can't be a useful match before the end of this block.
        // Skip to the end
        curwin->w_cursor = *pos;
        continue;
      }
    }

    if (t == false) {
      // If we previously found a valid position, use it.
      if (found_pos.lnum != 0) {
        curwin->w_cursor = found_pos;
        t = true;
      }
      break;
    }
    if (get_leader_len(get_cursor_line_ptr(), NULL, false, true) > 0) {
      // Ignore this line, continue at start of next line.
      curwin->w_cursor.lnum++;
      curwin->w_cursor.col = 0;
      continue;
    }
    bool valid = is_ident(get_cursor_line_ptr(), curwin->w_cursor.col);

    // If the current position is not a valid identifier and a previous match is
    // present, favor that one instead.
    if (!valid && found_pos.lnum != 0) {
      curwin->w_cursor = found_pos;
      break;
    }
    // global search: use first match found
    if (valid && !locally) {
      break;
    }
    if (valid && curwin->w_cursor.lnum >= par_pos.lnum) {
      // If we previously found a valid position, use it.
      if (found_pos.lnum != 0) {
        curwin->w_cursor = found_pos;
      }
      break;
    }

    // For finding a local variable and the match is before the "{" or
    // inside a comment, continue searching.  For K&R style function
    // declarations this skips the function header without types.
    if (!valid) {
      clearpos(&found_pos);
    } else {
      found_pos = curwin->w_cursor;
    }
    // Remove SEARCH_START from flags to avoid getting stuck at one position.
    searchflags &= ~SEARCH_START;
  }

  if (t == false) {
    retval = false;
    curwin->w_cursor = old_pos;
  } else {
    curwin->w_set_curswant = true;
    // "n" searches forward now
    reset_search_dir();
  }

  xfree(pat);
  p_ws = save_p_ws;
  p_scs = save_p_scs;

  return retval;
}

/// Move 'dist' lines in direction 'dir', counting lines by *screen*
/// lines rather than lines in the file.
/// 'dist' must be positive.
///
/// @return  true if able to move cursor, false otherwise.
bool nv_screengo(oparg_T *oap, int dir, int dist)
{
  int linelen = linetabsize(curwin, curwin->w_cursor.lnum);
  bool retval = true;
  bool atend = false;
  int col_off1;                 // margin offset for first screen line
  int col_off2;                 // margin offset for wrapped screen line
  int width1;                   // text width for first screen line
  int width2;                   // text width for wrapped screen line

  oap->motion_type = kMTCharWise;
  oap->inclusive = (curwin->w_curswant == MAXCOL);

  col_off1 = win_col_off(curwin);
  col_off2 = col_off1 - win_col_off2(curwin);
  width1 = curwin->w_width_inner - col_off1;
  width2 = curwin->w_width_inner - col_off2;

  if (width2 == 0) {
    width2 = 1;  // Avoid divide by zero.
  }

  if (curwin->w_width_inner != 0) {
    int n;
    // Instead of sticking at the last character of the buffer line we
    // try to stick in the last column of the screen.
    if (curwin->w_curswant == MAXCOL) {
      atend = true;
      validate_virtcol(curwin);
      if (width1 <= 0) {
        curwin->w_curswant = 0;
      } else {
        curwin->w_curswant = width1 - 1;
        if (curwin->w_virtcol > curwin->w_curswant) {
          curwin->w_curswant += ((curwin->w_virtcol
                                  - curwin->w_curswant -
                                  1) / width2 + 1) * width2;
        }
      }
    } else {
      if (linelen > width1) {
        n = ((linelen - width1 - 1) / width2 + 1) * width2 + width1;
      } else {
        n = width1;
      }
      if (curwin->w_curswant >= n) {
        curwin->w_curswant = n - 1;
      }
    }

    while (dist--) {
      if (dir == BACKWARD) {
        if (curwin->w_curswant >= width1
            && !hasFolding(curwin, curwin->w_cursor.lnum, NULL, NULL)) {
          // Move back within the line. This can give a negative value
          // for w_curswant if width1 < width2 (with cpoptions+=n),
          // which will get clipped to column 0.
          curwin->w_curswant -= width2;
        } else {
          // to previous line
          if (curwin->w_cursor.lnum <= 1) {
            retval = false;
            break;
          }
          cursor_up_inner(curwin, 1);

          linelen = linetabsize(curwin, curwin->w_cursor.lnum);
          if (linelen > width1) {
            int w = (((linelen - width1 - 1) / width2) + 1) * width2;
            assert(curwin->w_curswant <= INT_MAX - w);
            curwin->w_curswant += w;
          }
        }
      } else {  // dir == FORWARD
        if (linelen > width1) {
          n = ((linelen - width1 - 1) / width2 + 1) * width2 + width1;
        } else {
          n = width1;
        }
        if (curwin->w_curswant + width2 < (colnr_T)n
            && !hasFolding(curwin, curwin->w_cursor.lnum, NULL, NULL)) {
          // move forward within line
          curwin->w_curswant += width2;
        } else {
          // to next line
          if (curwin->w_cursor.lnum >= curwin->w_buffer->b_ml.ml_line_count) {
            retval = false;
            break;
          }
          cursor_down_inner(curwin, 1);
          curwin->w_curswant %= width2;

          // Check if the cursor has moved below the number display
          // when width1 < width2 (with cpoptions+=n). Subtract width2
          // to get a negative value for w_curswant, which will get
          // clipped to column 0.
          if (curwin->w_curswant >= width1) {
            curwin->w_curswant -= width2;
          }
          linelen = linetabsize(curwin, curwin->w_cursor.lnum);
        }
      }
    }
  }

  if (virtual_active(curwin) && atend) {
    coladvance(curwin, MAXCOL);
  } else {
    coladvance(curwin, curwin->w_curswant);
  }

  if (curwin->w_cursor.col > 0 && curwin->w_p_wrap) {
    // Check for landing on a character that got split at the end of the
    // last line.  We want to advance a screenline, not end up in the same
    // screenline or move two screenlines.
    validate_virtcol(curwin);
    colnr_T virtcol = curwin->w_virtcol;
    if (virtcol > (colnr_T)width1 && *get_showbreak_value(curwin) != NUL) {
      virtcol -= vim_strsize(get_showbreak_value(curwin));
    }

    int c = utf_ptr2char(get_cursor_pos_ptr());
    if (dir == FORWARD && virtcol < curwin->w_curswant
        && (curwin->w_curswant <= (colnr_T)width1)
        && !vim_isprintc(c) && c > 255) {
      oneright();
    }

    if (virtcol > curwin->w_curswant
        && (curwin->w_curswant < (colnr_T)width1
            ? (curwin->w_curswant > (colnr_T)width1 / 2)
            : ((curwin->w_curswant - width1) % width2
               > (colnr_T)width2 / 2))) {
      curwin->w_cursor.col--;
    }
  }

  if (atend) {
    curwin->w_curswant = MAXCOL;            // stick in the last column
  }
  adjust_skipcol();

  return retval;
}

/// Handle CTRL-E and CTRL-Y commands: scroll a line up or down.
/// cap->arg must be true for CTRL-E.
void nv_scroll_line(cmdarg_T *cap)
{
  if (!checkclearop(cap->oap)) {
    scroll_redraw(cap->arg, cap->count1);
  }
}

/// Get the count specified after a 'z' command. Only the 'z<CR>', 'zl', 'zh',
/// 'z<Left>', and 'z<Right>' commands accept a count after 'z'.
/// @return  true to process the 'z' command and false to skip it.
static bool nv_z_get_count(cmdarg_T *cap, int *nchar_arg)
{
  int nchar = *nchar_arg;

  // "z123{nchar}": edit the count before obtaining {nchar}
  if (checkclearop(cap->oap)) {
    return false;
  }
  int n = nchar - '0';

  while (true) {
    no_mapping++;
    allow_keys++;         // no mapping for nchar, but allow key codes
    nchar = plain_vgetc();
    LANGMAP_ADJUST(nchar, true);
    no_mapping--;
    allow_keys--;
    add_to_showcmd(nchar);

    if (nchar == K_DEL || nchar == K_KDEL) {
      n /= 10;
    } else if (ascii_isdigit(nchar)) {
      if (vim_append_digit_int(&n, nchar - '0') == FAIL) {
        clearopbeep(cap->oap);
        break;
      }
    } else if (nchar == CAR) {
      win_setheight(n);
      break;
    } else if (nchar == 'l'
               || nchar == 'h'
               || nchar == K_LEFT
               || nchar == K_RIGHT) {
      cap->count1 = n ? n * cap->count1 : cap->count1;
      *nchar_arg = nchar;
      return true;
    } else {
      clearopbeep(cap->oap);
      break;
    }
  }
  cap->oap->op_type = OP_NOP;
  return false;
}

/// "zug" and "zuw": undo "zg" and "zw"
/// "zg": add good word to word list
/// "zw": add wrong word to word list
/// "zG": add good word to temp word list
/// "zW": add wrong word to temp word list
static int nv_zg_zw(cmdarg_T *cap, int nchar)
{
  bool undo = false;

  if (nchar == 'u') {
    no_mapping++;
    allow_keys++;               // no mapping for nchar, but allow key codes
    nchar = plain_vgetc();
    LANGMAP_ADJUST(nchar, true);
    no_mapping--;
    allow_keys--;
    add_to_showcmd(nchar);

    if (vim_strchr("gGwW", nchar) == NULL) {
      clearopbeep(cap->oap);
      return OK;
    }
    undo = true;
  }

  if (checkclearop(cap->oap)) {
    return OK;
  }
  char *ptr = NULL;
  size_t len;
  if (VIsual_active && !get_visual_text(cap, &ptr, &len)) {
    return FAIL;
  }
  if (ptr == NULL) {
    pos_T pos = curwin->w_cursor;

    // Find bad word under the cursor.  When 'spell' is
    // off this fails and find_ident_under_cursor() is
    // used below.
    emsg_off++;
    len = spell_move_to(curwin, FORWARD, SMT_ALL, true, NULL);
    emsg_off--;
    if (len != 0 && curwin->w_cursor.col <= pos.col) {
      ptr = ml_get_pos(&curwin->w_cursor);
    }
    curwin->w_cursor = pos;
  }

  if (ptr == NULL && (len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0) {
    return FAIL;
  }
  assert(len <= INT_MAX);
  spell_add_word(ptr, (int)len,
                 nchar == 'w' || nchar == 'W' ? SPELL_ADD_BAD : SPELL_ADD_GOOD,
                 (nchar == 'G' || nchar == 'W') ? 0 : cap->count1,
                 undo);

  return OK;
}

/// Commands that start with "z".
static void nv_zet(cmdarg_T *cap)
{
  colnr_T col;
  int nchar = cap->nchar;
  int old_fdl = (int)curwin->w_p_fdl;
  int old_fen = curwin->w_p_fen;

  int siso = get_sidescrolloff_value(curwin);

  if (ascii_isdigit(nchar) && !nv_z_get_count(cap, &nchar)) {
    return;
  }

  // "zf" and "zF" are always an operator, "zd", "zo", "zO", "zc"
  // and "zC" only in Visual mode.  "zj" and "zk" are motion
  // commands.
  if (cap->nchar != 'f' && cap->nchar != 'F'
      && !(VIsual_active && vim_strchr("dcCoO", cap->nchar))
      && cap->nchar != 'j' && cap->nchar != 'k'
      && checkclearop(cap->oap)) {
    return;
  }

  // For "z+", "z<CR>", "zt", "z.", "zz", "z^", "z-", "zb":
  // If line number given, set cursor.
  if ((vim_strchr("+\r\nt.z^-b", nchar) != NULL)
      && cap->count0
      && cap->count0 != curwin->w_cursor.lnum) {
    setpcmark();
    if (cap->count0 > curbuf->b_ml.ml_line_count) {
      curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
    } else {
      curwin->w_cursor.lnum = cap->count0;
    }
    check_cursor_col(curwin);
  }

  switch (nchar) {
  // "z+", "z<CR>" and "zt": put cursor at top of screen
  case '+':
    if (cap->count0 == 0) {
      // No count given: put cursor at the line below screen
      validate_botline(curwin);               // make sure w_botline is valid
      if (curwin->w_botline > curbuf->b_ml.ml_line_count) {
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      } else {
        curwin->w_cursor.lnum = curwin->w_botline;
      }
    }
    FALLTHROUGH;
  case NL:
  case CAR:
  case K_KENTER:
    beginline(BL_WHITE | BL_FIX);
    FALLTHROUGH;

  case 't':
    scroll_cursor_top(curwin, 0, true);
    redraw_later(curwin, UPD_VALID);
    set_fraction(curwin);
    break;

  // "z." and "zz": put cursor in middle of screen
  case '.':
    beginline(BL_WHITE | BL_FIX);
    FALLTHROUGH;

  case 'z':
    scroll_cursor_halfway(curwin, true, false);
    redraw_later(curwin, UPD_VALID);
    set_fraction(curwin);
    break;

  // "z^", "z-" and "zb": put cursor at bottom of screen
  case '^':     // Strange Vi behavior: <count>z^ finds line at top of window
                // when <count> is at bottom of window, and puts that one at
                // bottom of window.
    if (cap->count0 != 0) {
      scroll_cursor_bot(curwin, 0, true);
      curwin->w_cursor.lnum = curwin->w_topline;
    } else if (curwin->w_topline == 1) {
      curwin->w_cursor.lnum = 1;
    } else {
      curwin->w_cursor.lnum = curwin->w_topline - 1;
    }
    FALLTHROUGH;
  case '-':
    beginline(BL_WHITE | BL_FIX);
    FALLTHROUGH;

  case 'b':
    scroll_cursor_bot(curwin, 0, true);
    redraw_later(curwin, UPD_VALID);
    set_fraction(curwin);
    break;

  // "zH" - scroll screen right half-page
  case 'H':
    cap->count1 *= curwin->w_width_inner / 2;
    FALLTHROUGH;

  // "zh" - scroll screen to the right
  case 'h':
  case K_LEFT:
    if (!curwin->w_p_wrap) {
      set_leftcol((colnr_T)cap->count1 > curwin->w_leftcol
                  ? 0 : curwin->w_leftcol - (colnr_T)cap->count1);
    }
    break;

  // "zL" - scroll window left half-page
  case 'L':
    cap->count1 *= curwin->w_width_inner / 2;
    FALLTHROUGH;

  // "zl" - scroll window to the left if not wrapping
  case 'l':
  case K_RIGHT:
    if (!curwin->w_p_wrap) {
      set_leftcol(curwin->w_leftcol + (colnr_T)cap->count1);
    }
    break;

  // "zs" - scroll screen, cursor at the start
  case 's':
    if (!curwin->w_p_wrap) {
      if (hasFolding(curwin, curwin->w_cursor.lnum, NULL, NULL)) {
        col = 0;                        // like the cursor is in col 0
      } else {
        getvcol(curwin, &curwin->w_cursor, &col, NULL, NULL);
      }
      if (col > siso) {
        col -= siso;
      } else {
        col = 0;
      }
      if (curwin->w_leftcol != col) {
        curwin->w_leftcol = col;
        redraw_later(curwin, UPD_NOT_VALID);
      }
    }
    break;

  // "ze" - scroll screen, cursor at the end
  case 'e':
    if (!curwin->w_p_wrap) {
      if (hasFolding(curwin, curwin->w_cursor.lnum, NULL, NULL)) {
        col = 0;                        // like the cursor is in col 0
      } else {
        getvcol(curwin, &curwin->w_cursor, NULL, NULL, &col);
      }
      int n = curwin->w_width_inner - win_col_off(curwin);
      if (col + siso < n) {
        col = 0;
      } else {
        col = col + siso - n + 1;
      }
      if (curwin->w_leftcol != col) {
        curwin->w_leftcol = col;
        redraw_later(curwin, UPD_NOT_VALID);
      }
    }
    break;

  // "zp", "zP" in block mode put without addind trailing spaces
  case 'P':
  case 'p':
    nv_put(cap);
    break;
  // "zy" Yank without trailing spaces
  case 'y':
    nv_operator(cap);
    break;

  // "zF": create fold command
  // "zf": create fold operator
  case 'F':
  case 'f':
    if (foldManualAllowed(true)) {
      cap->nchar = 'f';
      nv_operator(cap);
      curwin->w_p_fen = true;

      // "zF" is like "zfzf"
      if (nchar == 'F' && cap->oap->op_type == OP_FOLD) {
        nv_operator(cap);
        finish_op = true;
      }
    } else {
      clearopbeep(cap->oap);
    }
    break;

  // "zd": delete fold at cursor
  // "zD": delete fold at cursor recursively
  case 'd':
  case 'D':
    if (foldManualAllowed(false)) {
      if (VIsual_active) {
        nv_operator(cap);
      } else {
        deleteFold(curwin, curwin->w_cursor.lnum,
                   curwin->w_cursor.lnum, nchar == 'D', false);
      }
    }
    break;

  // "zE": erase all folds
  case 'E':
    if (foldmethodIsManual(curwin)) {
      clearFolding(curwin);
      changed_window_setting(curwin);
    } else if (foldmethodIsMarker(curwin)) {
      deleteFold(curwin, 1, curbuf->b_ml.ml_line_count, true, false);
    } else {
      emsg(_("E352: Cannot erase folds with current 'foldmethod'"));
    }
    break;

  // "zn": fold none: reset 'foldenable'
  case 'n':
    curwin->w_p_fen = false;
    break;

  // "zN": fold Normal: set 'foldenable'
  case 'N':
    curwin->w_p_fen = true;
    break;

  // "zi": invert folding: toggle 'foldenable'
  case 'i':
    curwin->w_p_fen = !curwin->w_p_fen;
    break;

  // "za": open closed fold or close open fold at cursor
  case 'a':
    if (hasFolding(curwin, curwin->w_cursor.lnum, NULL, NULL)) {
      openFold(curwin->w_cursor, cap->count1);
    } else {
      closeFold(curwin->w_cursor, cap->count1);
      curwin->w_p_fen = true;
    }
    break;

  // "zA": open fold at cursor recursively
  case 'A':
    if (hasFolding(curwin, curwin->w_cursor.lnum, NULL, NULL)) {
      openFoldRecurse(curwin->w_cursor);
    } else {
      closeFoldRecurse(curwin->w_cursor);
      curwin->w_p_fen = true;
    }
    break;

  // "zo": open fold at cursor or Visual area
  case 'o':
    if (VIsual_active) {
      nv_operator(cap);
    } else {
      openFold(curwin->w_cursor, cap->count1);
    }
    break;

  // "zO": open fold recursively
  case 'O':
    if (VIsual_active) {
      nv_operator(cap);
    } else {
      openFoldRecurse(curwin->w_cursor);
    }
    break;

  // "zc": close fold at cursor or Visual area
  case 'c':
    if (VIsual_active) {
      nv_operator(cap);
    } else {
      closeFold(curwin->w_cursor, cap->count1);
    }
    curwin->w_p_fen = true;
    break;

  // "zC": close fold recursively
  case 'C':
    if (VIsual_active) {
      nv_operator(cap);
    } else {
      closeFoldRecurse(curwin->w_cursor);
    }
    curwin->w_p_fen = true;
    break;

  // "zv": open folds at the cursor
  case 'v':
    foldOpenCursor();
    break;

  // "zx": re-apply 'foldlevel' and open folds at the cursor
  case 'x':
    curwin->w_p_fen = true;
    curwin->w_foldinvalid = true;               // recompute folds
    newFoldLevel();                             // update right now
    foldOpenCursor();
    break;

  // "zX": undo manual opens/closes, re-apply 'foldlevel'
  case 'X':
    curwin->w_p_fen = true;
    curwin->w_foldinvalid = true;               // recompute folds
    old_fdl = -1;                               // force an update
    break;

  // "zm": fold more
  case 'm':
    if (curwin->w_p_fdl > 0) {
      curwin->w_p_fdl -= cap->count1;
      if (curwin->w_p_fdl < 0) {
        curwin->w_p_fdl = 0;
      }
    }
    old_fdl = -1;                       // force an update
    curwin->w_p_fen = true;
    break;

  // "zM": close all folds
  case 'M':
    curwin->w_p_fdl = 0;
    old_fdl = -1;                       // force an update
    curwin->w_p_fen = true;
    break;

  // "zr": reduce folding
  case 'r':
    curwin->w_p_fdl += cap->count1;
    {
      int d = getDeepestNesting(curwin);
      if (curwin->w_p_fdl >= d) {
        curwin->w_p_fdl = d;
      }
    }
    break;

  case 'R':     //  "zR": open all folds
    curwin->w_p_fdl = getDeepestNesting(curwin);
    old_fdl = -1;                       // force an update
    break;

  case 'j':     // "zj" move to next fold downwards
  case 'k':     // "zk" move to next fold upwards
    if (foldMoveTo(true, nchar == 'j' ? FORWARD : BACKWARD,
                   cap->count1) == false) {
      clearopbeep(cap->oap);
    }
    break;

  case 'u':     // "zug" and "zuw": undo "zg" and "zw"
  case 'g':     // "zg": add good word to word list
  case 'w':     // "zw": add wrong word to word list
  case 'G':     // "zG": add good word to temp word list
  case 'W':     // "zW": add wrong word to temp word list
    if (nv_zg_zw(cap, nchar) == FAIL) {
      return;
    }
    break;

  case '=':     // "z=": suggestions for a badly spelled word
    if (!checkclearop(cap->oap)) {
      spell_suggest(cap->count0);
    }
    break;

  default:
    clearopbeep(cap->oap);
  }

  // Redraw when 'foldenable' changed
  if (old_fen != curwin->w_p_fen) {
    if (foldmethodIsDiff(curwin) && curwin->w_p_scb) {
      // Adjust 'foldenable' in diff-synced windows.
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        if (wp != curwin && foldmethodIsDiff(wp) && wp->w_p_scb) {
          wp->w_p_fen = curwin->w_p_fen;
          changed_window_setting(wp);
        }
      }
    }
    changed_window_setting(curwin);
  }

  // Redraw when 'foldlevel' changed.
  if (old_fdl != curwin->w_p_fdl) {
    newFoldLevel();
  }
}

/// "Q" command.
static void nv_regreplay(cmdarg_T *cap)
{
  if (checkclearop(cap->oap)) {
    return;
  }

  while (cap->count1-- && !got_int) {
    if (do_execreg(reg_recorded, false, false, false) == false) {
      clearopbeep(cap->oap);
      break;
    }
    line_breakcheck();
  }
}

/// Handle a ":" command and <Cmd> or Lua mappings.
static void nv_colon(cmdarg_T *cap)
{
  bool cmd_result;
  bool is_cmdkey = cap->cmdchar == K_COMMAND;
  bool is_lua = cap->cmdchar == K_LUA;

  if (VIsual_active && !is_cmdkey && !is_lua) {
    nv_operator(cap);
    return;
  }

  if (cap->oap->op_type != OP_NOP) {
    // Using ":" as a movement is charwise exclusive.
    cap->oap->motion_type = kMTCharWise;
    cap->oap->inclusive = false;
  } else if (cap->count0 && !is_cmdkey && !is_lua) {
    // translate "count:" into ":.,.+(count - 1)"
    stuffcharReadbuff('.');
    if (cap->count0 > 1) {
      stuffReadbuff(",.+");
      stuffnumReadbuff(cap->count0 - 1);
    }
  }

  // When typing, don't type below an old message
  if (KeyTyped) {
    compute_cmdrow();
  }

  if (is_lua) {
    cmd_result = map_execute_lua(true);
  } else {
    // get a command line and execute it
    cmd_result = do_cmdline(NULL, is_cmdkey ? getcmdkeycmd : getexline, NULL,
                            cap->oap->op_type != OP_NOP ? DOCMD_KEEPLINE : 0);
  }

  if (cmd_result == false) {
    // The Ex command failed, do not execute the operator.
    clearop(cap->oap);
  } else if (cap->oap->op_type != OP_NOP
             && (cap->oap->start.lnum > curbuf->b_ml.ml_line_count
                 || cap->oap->start.col > ml_get_len(cap->oap->start.lnum)
                 || did_emsg)) {
    // The start of the operator has become invalid by the Ex command.
    clearopbeep(cap->oap);
  }
}

/// Handle CTRL-G command.
static void nv_ctrlg(cmdarg_T *cap)
{
  if (VIsual_active) {  // toggle Selection/Visual mode
    VIsual_select = !VIsual_select;
    may_trigger_modechanged();
    showmode();
  } else if (!checkclearop(cap->oap)) {
    // print full name if count given or :cd used
    fileinfo(cap->count0, false, true);
  }
}

/// Handle CTRL-H <Backspace> command.
static void nv_ctrlh(cmdarg_T *cap)
{
  if (VIsual_active && VIsual_select) {
    cap->cmdchar = 'x';         // BS key behaves like 'x' in Select mode
    v_visop(cap);
  } else {
    nv_left(cap);
  }
}

/// CTRL-L: clear screen and redraw.
static void nv_clear(cmdarg_T *cap)
{
  if (checkclearop(cap->oap)) {
    return;
  }

  // Clear all syntax states to force resyncing.
  syn_stack_free_all(curwin->w_s);
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    wp->w_s->b_syn_slow = false;
  }
  redraw_later(curwin, UPD_CLEAR);
}

/// CTRL-O: In Select mode: switch to Visual mode for one command.
/// Otherwise: Go to older pcmark.
static void nv_ctrlo(cmdarg_T *cap)
{
  if (VIsual_active && VIsual_select) {
    VIsual_select = false;
    may_trigger_modechanged();
    showmode();
    restart_VIsual_select = 2;          // restart Select mode later
  } else {
    cap->count1 = -cap->count1;
    nv_pcmark(cap);
  }
}

/// CTRL-^ command, short for ":e #".  Works even when the alternate buffer is
/// not named.
static void nv_hat(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap)) {
    buflist_getfile(cap->count0, 0,
                    GETF_SETMARK|GETF_ALT, false);
  }
}

/// "Z" commands.
static void nv_Zet(cmdarg_T *cap)
{
  if (checkclearopq(cap->oap)) {
    return;
  }

  switch (cap->nchar) {
  // "ZZ": equivalent to ":x".
  case 'Z':
    do_cmdline_cmd("x");
    break;

  // "ZQ": equivalent to ":q!" (Elvis compatible).
  case 'Q':
    do_cmdline_cmd("q!");
    break;

  default:
    clearopbeep(cap->oap);
  }
}

/// Call nv_ident() as if "c1" was used, with "c2" as next character.
void do_nv_ident(int c1, int c2)
{
  oparg_T oa;
  cmdarg_T ca;

  clear_oparg(&oa);
  CLEAR_FIELD(ca);
  ca.oap = &oa;
  ca.cmdchar = c1;
  ca.nchar = c2;
  nv_ident(&ca);
}

/// 'K' normal-mode command. Get the command to lookup the keyword under the
/// cursor.
static size_t nv_K_getcmd(cmdarg_T *cap, char *kp, bool kp_help, bool kp_ex, char **ptr_arg,
                          size_t n, char *buf, size_t bufsize, size_t *buflen)
{
  if (kp_help) {
    // in the help buffer
    STRCPY(buf, "he! ");
    *buflen = STRLEN_LITERAL("he! ");
    return n;
  }

  if (kp_ex) {
    *buflen = 0;
    // 'keywordprg' is an ex command
    if (cap->count0 != 0) {  // Send the count to the ex command.
      *buflen = (size_t)snprintf(buf, bufsize, "%" PRId64, (int64_t)(cap->count0));
    }
    *buflen += (size_t)snprintf(buf + *buflen, bufsize - *buflen, "%s ", kp);
    return n;
  }

  char *ptr = *ptr_arg;

  // An external command will probably use an argument starting
  // with "-" as an option.  To avoid trouble we skip the "-".
  while (*ptr == '-' && n > 0) {
    ptr++;
    n--;
  }
  if (n == 0) {
    // found dashes only
    emsg(_(e_noident));
    xfree(buf);
    *ptr_arg = ptr;
    return 0;
  }

  // When a count is given, turn it into a range.  Is this
  // really what we want?
  bool isman = (strcmp(kp, "man") == 0);
  bool isman_s = (strcmp(kp, "man -s") == 0);
  if (cap->count0 != 0 && !(isman || isman_s)) {
    *buflen = (size_t)snprintf(buf, bufsize, ".,.+%" PRId64, (int64_t)(cap->count0 - 1));
  }

  do_cmdline_cmd("tabnew");
  *buflen += (size_t)snprintf(buf + *buflen, bufsize - *buflen, "terminal ");
  if (cap->count0 == 0 && isman_s) {
    *buflen += (size_t)snprintf(buf + *buflen, bufsize - *buflen, "man ");
  } else {
    *buflen += (size_t)snprintf(buf + *buflen, bufsize - *buflen, "%s ", kp);
  }
  if (cap->count0 != 0 && (isman || isman_s)) {
    *buflen += (size_t)snprintf(buf + *buflen, bufsize - *buflen,
                                "%" PRId64 " ", (int64_t)cap->count0);
  }

  *ptr_arg = ptr;
  return n;
}

/// Handle the commands that use the word under the cursor.
/// [g] CTRL-]   :ta to current identifier
/// [g] 'K'      run program for current identifier
/// [g] '*'      / to current identifier or string
/// [g] '#'      ? to current identifier or string
///  g  ']'      :tselect for current identifier
static void nv_ident(cmdarg_T *cap)
{
  char *ptr = NULL;
  char *p;
  size_t n = 0;                 // init for GCC
  int cmdchar;
  bool g_cmd;                   // "g" command
  bool tag_cmd = false;

  if (cap->cmdchar == 'g') {    // "g*", "g#", "g]" and "gCTRL-]"
    cmdchar = cap->nchar;
    g_cmd = true;
  } else {
    cmdchar = cap->cmdchar;
    g_cmd = false;
  }

  if (cmdchar == POUND) {       // the pound sign, '#' for English keyboards
    cmdchar = '#';
  }

  // The "]", "CTRL-]" and "K" commands accept an argument in Visual mode.
  if (cmdchar == ']' || cmdchar == Ctrl_RSB || cmdchar == 'K') {
    if (VIsual_active && get_visual_text(cap, &ptr, &n) == false) {
      return;
    }
    if (checkclearopq(cap->oap)) {
      return;
    }
  }

  if (ptr == NULL && (n = find_ident_under_cursor(&ptr,
                                                  ((cmdchar == '*'
                                                    || cmdchar == '#')
                                                   ? FIND_IDENT|FIND_STRING
                                                   : FIND_IDENT))) == 0) {
    clearop(cap->oap);
    return;
  }

  // Allocate buffer to put the command in.  Inserting backslashes can
  // double the length of the word.  p_kp / curbuf->b_p_kp could be added
  // and some numbers.
  char *kp = *curbuf->b_p_kp == NUL ? p_kp : curbuf->b_p_kp;  // 'keywordprg'
  bool kp_help = (*kp == NUL || strcmp(kp, ":he") == 0 || strcmp(kp, ":help") == 0);
  if (kp_help && *skipwhite(ptr) == NUL) {
    emsg(_(e_noident));   // found white space only
    return;
  }
  bool kp_ex = (*kp == ':');  // 'keywordprg' is an ex command
  size_t bufsize = n * 2 + 30 + strlen(kp);
  char *buf = xmalloc(bufsize);
  buf[0] = NUL;
  size_t buflen = 0;

  switch (cmdchar) {
  case '*':
  case '#':
    // Put cursor at start of word, makes search skip the word
    // under the cursor.
    // Call setpcmark() first, so "*``" puts the cursor back where
    // it was.
    setpcmark();
    curwin->w_cursor.col = (colnr_T)(ptr - get_cursor_line_ptr());

    if (!g_cmd && vim_iswordp(ptr)) {
      STRCPY(buf, "\\<");
      buflen = STRLEN_LITERAL("\\<");
    }
    no_smartcase = true;                // don't use 'smartcase' now
    break;

  case 'K':
    n = nv_K_getcmd(cap, kp, kp_help, kp_ex, &ptr, n, buf, bufsize, &buflen);
    if (n == 0) {
      return;
    }
    break;

  case ']':
    tag_cmd = true;
    STRCPY(buf, "ts ");
    buflen = STRLEN_LITERAL("ts ");
    break;

  default:
    tag_cmd = true;
    if (curbuf->b_help) {
      STRCPY(buf, "he! ");
      buflen = STRLEN_LITERAL("he! ");
    } else {
      if (g_cmd) {
        STRCPY(buf, "tj ");
        buflen = STRLEN_LITERAL("tj ");
      } else if (cap->count0 == 0) {
        STRCPY(buf, "ta ");
        buflen = STRLEN_LITERAL("ta ");
      } else {
        buflen = (size_t)snprintf(buf, bufsize, ":%" PRId64 "ta ", (int64_t)cap->count0);
      }
    }
  }

  // Now grab the chars in the identifier
  if (cmdchar == 'K' && !kp_help) {
    ptr = xstrnsave(ptr, n);
    if (kp_ex) {
      // Escape the argument properly for an Ex command
      p = vim_strsave_fnameescape(ptr, VSE_NONE);
    } else {
      // Escape the argument properly for a shell command
      p = vim_strsave_shellescape(ptr, true, true);
    }
    xfree(ptr);
    size_t plen = strlen(p);
    char *newbuf = xrealloc(buf, buflen + plen + 1);
    buf = newbuf;
    STRCPY(buf + buflen, p);
    buflen += plen;
    xfree(p);
  } else {
    char *aux_ptr;
    if (cmdchar == '*') {
      aux_ptr = (magic_isset() ? "/.*~[^$\\" : "/^$\\");
    } else if (cmdchar == '#') {
      aux_ptr = (magic_isset() ? "/?.*~[^$\\" : "/?^$\\");
    } else if (tag_cmd) {
      if (curbuf->b_help) {
        // ":help" handles unescaped argument
        aux_ptr = "";
      } else {
        aux_ptr = "\\|\"\n[";
      }
    } else {
      aux_ptr = "\\|\"\n*?[";
    }

    p = buf + buflen;
    while (n-- > 0) {
      // put a backslash before \ and some others
      if (vim_strchr(aux_ptr, (uint8_t)(*ptr)) != NULL) {
        *p++ = '\\';
      }

      // When current byte is a part of multibyte character, copy all
      // bytes of that character.
      const size_t len = (size_t)(utfc_ptr2len(ptr) - 1);
      for (size_t i = 0; i < len && n > 0; i++, n--) {
        *p++ = *ptr++;
      }
      *p++ = *ptr++;
    }
    *p = NUL;
    buflen = (size_t)(p - buf);
  }

  // Execute the command.
  if (cmdchar == '*' || cmdchar == '#') {
    if (!g_cmd && vim_iswordp(mb_prevptr(get_cursor_line_ptr(), ptr))) {
      STRCPY(buf + buflen, "\\>");
      buflen += STRLEN_LITERAL("\\>");
    }

    // put pattern in search history
    init_history();
    add_to_history(HIST_SEARCH, buf, buflen, true, NUL);

    normal_search(cap, cmdchar == '*' ? '/' : '?', buf, buflen, 0, NULL);
  } else {
    g_tag_at_cursor = true;
    do_cmdline_cmd(buf);
    g_tag_at_cursor = false;

    if (cmdchar == 'K' && !kp_ex && !kp_help) {
      // Start insert mode in terminal buffer
      restart_edit = 'i';

      add_map("<esc>", "<Cmd>bdelete!<CR>", MODE_TERMINAL, true);
    }
  }

  xfree(buf);
}

/// Get visually selected text, within one line only.
///
/// @param pp    return: start of selected text
/// @param lenp  return: length of selected text
///
/// @return      false if more than one line selected.
bool get_visual_text(cmdarg_T *cap, char **pp, size_t *lenp)
{
  if (VIsual_mode != 'V') {
    unadjust_for_sel();
  }
  if (VIsual.lnum != curwin->w_cursor.lnum) {
    if (cap != NULL) {
      clearopbeep(cap->oap);
    }
    return false;
  }
  if (VIsual_mode == 'V') {
    *pp = get_cursor_line_ptr();
    *lenp = (size_t)get_cursor_line_len();
  } else {
    if (lt(curwin->w_cursor, VIsual)) {
      *pp = ml_get_pos(&curwin->w_cursor);
      *lenp = (size_t)VIsual.col - (size_t)curwin->w_cursor.col + 1;
    } else {
      *pp = ml_get_pos(&VIsual);
      *lenp = (size_t)curwin->w_cursor.col - (size_t)VIsual.col + 1;
    }
    if (**pp == NUL) {
      *lenp = 0;
    }
    if (*lenp > 0) {
      // Correct the length to include all bytes of the last character.
      *lenp += (size_t)(utfc_ptr2len(*pp + (*lenp - 1)) - 1);
    }
  }
  reset_VIsual_and_resel();
  return true;
}

/// CTRL-T: backwards in tag stack
static void nv_tagpop(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap)) {
    do_tag("", DT_POP, cap->count1, false, true);
  }
}

/// Handle scrolling command 'H', 'L' and 'M'.
static void nv_scroll(cmdarg_T *cap)
{
  int n;
  linenr_T lnum;

  cap->oap->motion_type = kMTLineWise;
  setpcmark();

  if (cap->cmdchar == 'L') {
    validate_botline(curwin);          // make sure curwin->w_botline is valid
    curwin->w_cursor.lnum = curwin->w_botline - 1;
    if (cap->count1 - 1 >= curwin->w_cursor.lnum) {
      curwin->w_cursor.lnum = 1;
    } else {
      if (hasAnyFolding(curwin)) {
        // Count a fold for one screen line.
        for (n = cap->count1 - 1; n > 0
             && curwin->w_cursor.lnum > curwin->w_topline; n--) {
          hasFolding(curwin, curwin->w_cursor.lnum,
                     &curwin->w_cursor.lnum, NULL);
          if (curwin->w_cursor.lnum > curwin->w_topline) {
            curwin->w_cursor.lnum--;
          }
        }
      } else {
        curwin->w_cursor.lnum -= cap->count1 - 1;
      }
    }
  } else {
    if (cap->cmdchar == 'M') {
      int used = 0;
      // Don't count filler lines above the window.
      used -= win_get_fill(curwin, curwin->w_topline)
              - curwin->w_topfill;
      validate_botline(curwin);  // make sure w_empty_rows is valid
      int half = (curwin->w_height_inner - curwin->w_empty_rows + 1) / 2;
      for (n = 0; curwin->w_topline + n < curbuf->b_ml.ml_line_count; n++) {
        // Count half the number of filler lines to be "below this
        // line" and half to be "above the next line".
        if (n > 0 && used + win_get_fill(curwin, curwin->w_topline + n) / 2 >= half) {
          n--;
          break;
        }
        used += plines_win(curwin, curwin->w_topline + n, true);
        if (used >= half) {
          break;
        }
        if (hasFolding(curwin, curwin->w_topline + n, NULL, &lnum)) {
          n = lnum - curwin->w_topline;
        }
      }
      if (n > 0 && used > curwin->w_height_inner) {
        n--;
      }
    } else {  // (cap->cmdchar == 'H')
      n = cap->count1 - 1;
      if (hasAnyFolding(curwin)) {
        // Count a fold for one screen line.
        lnum = curwin->w_topline;
        while (n-- > 0 && lnum < curwin->w_botline - 1) {
          hasFolding(curwin, lnum, NULL, &lnum);
          lnum++;
        }
        n = lnum - curwin->w_topline;
      }
    }
    curwin->w_cursor.lnum = curwin->w_topline + n;
    if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
      curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
    }
  }

  // Correct for 'so', except when an operator is pending.
  if (cap->oap->op_type == OP_NOP) {
    cursor_correct(curwin);
  }
  beginline(BL_SOL | BL_FIX);
}

/// Cursor right commands.
static void nv_right(cmdarg_T *cap)
{
  int n;

  if (mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL)) {
    // <C-Right> and <S-Right> move a word or WORD right
    if (mod_mask & MOD_MASK_CTRL) {
      cap->arg = true;
    }
    nv_wordcmd(cap);
    return;
  }

  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  bool past_line = (VIsual_active && *p_sel != 'o');

  // In virtual edit mode, there's no such thing as "past_line", as lines
  // are (theoretically) infinitely long.
  if (virtual_active(curwin)) {
    past_line = false;
  }

  for (n = cap->count1; n > 0; n--) {
    if ((!past_line && oneright() == false)
        || (past_line && *get_cursor_pos_ptr() == NUL)) {
      //    <Space> wraps to next line if 'whichwrap' has 's'.
      //        'l' wraps to next line if 'whichwrap' has 'l'.
      // CURS_RIGHT wraps to next line if 'whichwrap' has '>'.
      if (((cap->cmdchar == ' ' && vim_strchr(p_ww, 's') != NULL)
           || (cap->cmdchar == 'l' && vim_strchr(p_ww, 'l') != NULL)
           || (cap->cmdchar == K_RIGHT && vim_strchr(p_ww, '>') != NULL))
          && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
        // When deleting we also count the NL as a character.
        // Set cap->oap->inclusive when last char in the line is
        // included, move to next line after that
        if (cap->oap->op_type != OP_NOP
            && !cap->oap->inclusive
            && !LINEEMPTY(curwin->w_cursor.lnum)) {
          cap->oap->inclusive = true;
        } else {
          curwin->w_cursor.lnum++;
          curwin->w_cursor.col = 0;
          curwin->w_cursor.coladd = 0;
          curwin->w_set_curswant = true;
          cap->oap->inclusive = false;
        }
        continue;
      }
      if (cap->oap->op_type == OP_NOP) {
        // Only beep and flush if not moved at all
        if (n == cap->count1) {
          beep_flush();
        }
      } else {
        if (!LINEEMPTY(curwin->w_cursor.lnum)) {
          cap->oap->inclusive = true;
        }
      }
      break;
    } else if (past_line) {
      curwin->w_set_curswant = true;
      if (virtual_active(curwin)) {
        oneright();
      } else {
        curwin->w_cursor.col += utfc_ptr2len(get_cursor_pos_ptr());
      }
    }
  }
  if (n != cap->count1 && (fdo_flags & FDO_HOR) && KeyTyped
      && cap->oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
}

/// Cursor left commands.
///
/// @return  true when operator end should not be adjusted.
static void nv_left(cmdarg_T *cap)
{
  int n;

  if (mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL)) {
    // <C-Left> and <S-Left> move a word or WORD left
    if (mod_mask & MOD_MASK_CTRL) {
      cap->arg = 1;
    }
    nv_bck_word(cap);
    return;
  }

  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  for (n = cap->count1; n > 0; n--) {
    if (oneleft() == false) {
      // <BS> and <Del> wrap to previous line if 'whichwrap' has 'b'.
      //                 'h' wraps to previous line if 'whichwrap' has 'h'.
      //           CURS_LEFT wraps to previous line if 'whichwrap' has '<'.
      if ((((cap->cmdchar == K_BS || cap->cmdchar == Ctrl_H)
            && vim_strchr(p_ww, 'b') != NULL)
           || (cap->cmdchar == 'h' && vim_strchr(p_ww, 'h') != NULL)
           || (cap->cmdchar == K_LEFT && vim_strchr(p_ww, '<') != NULL))
          && curwin->w_cursor.lnum > 1) {
        curwin->w_cursor.lnum--;
        coladvance(curwin, MAXCOL);
        curwin->w_set_curswant = true;

        // When the NL before the first char has to be deleted we
        // put the cursor on the NUL after the previous line.
        // This is a very special case, be careful!
        // Don't adjust op_end now, otherwise it won't work.
        if ((cap->oap->op_type == OP_DELETE || cap->oap->op_type == OP_CHANGE)
            && !LINEEMPTY(curwin->w_cursor.lnum)) {
          char *cp = get_cursor_pos_ptr();

          if (*cp != NUL) {
            curwin->w_cursor.col += utfc_ptr2len(cp);
          }
          cap->retval |= CA_NO_ADJ_OP_END;
        }
        continue;
      } else if (cap->oap->op_type == OP_NOP && n == cap->count1) {
        // Only beep and flush if not moved at all
        beep_flush();
      }
      break;
    }
  }
  if (n != cap->count1 && (fdo_flags & FDO_HOR) && KeyTyped
      && cap->oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
}

/// Cursor up commands.
/// cap->arg is true for "-": Move cursor to first non-blank.
static void nv_up(cmdarg_T *cap)
{
  if (mod_mask & MOD_MASK_SHIFT) {
    // <S-Up> is page up
    cap->arg = BACKWARD;
    nv_page(cap);
    return;
  }

  cap->oap->motion_type = kMTLineWise;
  if (cursor_up(cap->count1, cap->oap->op_type == OP_NOP) == false) {
    clearopbeep(cap->oap);
  } else if (cap->arg) {
    beginline(BL_WHITE | BL_FIX);
  }
}

/// Cursor down commands.
/// cap->arg is true for CR and "+": Move cursor to first non-blank.
static void nv_down(cmdarg_T *cap)
{
  if (mod_mask & MOD_MASK_SHIFT) {
    // <S-Down> is page down
    cap->arg = FORWARD;
    nv_page(cap);
  } else if (bt_quickfix(curbuf) && cap->cmdchar == CAR) {
    // Quickfix window only: view the result under the cursor.
    qf_view_result(false);
  } else {
    // In the cmdline window a <CR> executes the command.
    if (cmdwin_type != 0 && cap->cmdchar == CAR) {
      cmdwin_result = CAR;
    } else if (bt_prompt(curbuf) && cap->cmdchar == CAR
               && curwin->w_cursor.lnum == curbuf->b_ml.ml_line_count) {
      // In a prompt buffer a <CR> in the last line invokes the callback.
      invoke_prompt_callback();
      if (restart_edit == 0) {
        restart_edit = 'a';
      }
    } else {
      cap->oap->motion_type = kMTLineWise;
      if (cursor_down(cap->count1, cap->oap->op_type == OP_NOP) == false) {
        clearopbeep(cap->oap);
      } else if (cap->arg) {
        beginline(BL_WHITE | BL_FIX);
      }
    }
  }
}

/// Grab the file name under the cursor and edit it.
static void nv_gotofile(cmdarg_T *cap)
{
  linenr_T lnum = -1;

  if (check_text_or_curbuf_locked(cap->oap)) {
    return;
  }

  if (!check_can_set_curbuf_disabled()) {
    return;
  }

  char *ptr = grab_file_name(cap->count1, &lnum);

  if (ptr != NULL) {
    // do autowrite if necessary
    if (curbufIsChanged() && curbuf->b_nwindows <= 1 && !buf_hide(curbuf)) {
      autowrite(curbuf, false);
    }
    setpcmark();
    if (do_ecmd(0, ptr, NULL, NULL, ECMD_LAST,
                buf_hide(curbuf) ? ECMD_HIDE : 0, curwin) == OK
        && cap->nchar == 'F' && lnum >= 0) {
      curwin->w_cursor.lnum = lnum;
      check_cursor_lnum(curwin);
      beginline(BL_SOL | BL_FIX);
    }
    xfree(ptr);
  } else {
    clearop(cap->oap);
  }
}

/// <End> command: to end of current line or last line.
static void nv_end(cmdarg_T *cap)
{
  if (cap->arg || (mod_mask & MOD_MASK_CTRL)) {  // CTRL-END = goto last line
    cap->arg = true;
    nv_goto(cap);
    cap->count1 = 1;                    // to end of current line
  }
  nv_dollar(cap);
}

/// Handle the "$" command.
static void nv_dollar(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = true;
  // In virtual mode when off the edge of a line and an operator
  // is pending (whew!) keep the cursor where it is.
  // Otherwise, send it to the end of the line.
  if (!virtual_active(curwin) || gchar_cursor() != NUL
      || cap->oap->op_type == OP_NOP) {
    curwin->w_curswant = MAXCOL;        // so we stay at the end
  }
  if (cursor_down(cap->count1 - 1,
                  cap->oap->op_type == OP_NOP) == false) {
    clearopbeep(cap->oap);
  } else if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
}

/// Implementation of '?' and '/' commands.
/// If cap->arg is true don't set PC mark.
static void nv_search(cmdarg_T *cap)
{
  oparg_T *oap = cap->oap;
  pos_T save_cursor = curwin->w_cursor;

  if (cap->cmdchar == '?' && cap->oap->op_type == OP_ROT13) {
    // Translate "g??" to "g?g?"
    cap->cmdchar = 'g';
    cap->nchar = '?';
    nv_operator(cap);
    return;
  }

  // When using 'incsearch' the cursor may be moved to set a different search
  // start position.
  cap->searchbuf = getcmdline(cap->cmdchar, cap->count1, 0, true);

  if (cap->searchbuf == NULL) {
    clearop(oap);
    return;
  }

  normal_search(cap, cap->cmdchar, cap->searchbuf, strlen(cap->searchbuf),
                (cap->arg || !equalpos(save_cursor, curwin->w_cursor))
                ? 0 : SEARCH_MARK, NULL);
}

/// Handle "N" and "n" commands.
/// cap->arg is SEARCH_REV for "N", 0 for "n".
static void nv_next(cmdarg_T *cap)
{
  pos_T old = curwin->w_cursor;
  int wrapped = false;
  int i = normal_search(cap, 0, NULL, 0, SEARCH_MARK | cap->arg, &wrapped);

  if (i == 1 && !wrapped && equalpos(old, curwin->w_cursor)) {
    // Avoid getting stuck on the current cursor position, which can happen when
    // an offset is given and the cursor is on the last char in the buffer:
    // Repeat with count + 1.
    cap->count1 += 1;
    normal_search(cap, 0, NULL, 0, SEARCH_MARK | cap->arg, NULL);
    cap->count1 -= 1;
  }
}

/// Search for "pat" in direction "dir" ('/' or '?', 0 for repeat).
/// Uses only cap->count1 and cap->oap from "cap".
///
/// @param opt  extra flags for do_search()
///
/// @return 0 for failure, 1 for found, 2 for found and line offset added.
static int normal_search(cmdarg_T *cap, int dir, char *pat, size_t patlen, int opt, int *wrapped)
{
  searchit_arg_T sia;

  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  cap->oap->use_reg_one = true;
  curwin->w_set_curswant = true;

  CLEAR_FIELD(sia);
  int i = do_search(cap->oap, dir, dir, pat, patlen, cap->count1,
                    opt | SEARCH_OPT | SEARCH_ECHO | SEARCH_MSG, &sia);
  if (wrapped != NULL) {
    *wrapped = sia.sa_wrapped;
  }
  if (i == 0) {
    clearop(cap->oap);
  } else {
    if (i == 2) {
      cap->oap->motion_type = kMTLineWise;
    }
    curwin->w_cursor.coladd = 0;
    if (cap->oap->op_type == OP_NOP && (fdo_flags & FDO_SEARCH) && KeyTyped) {
      foldOpenCursor();
    }
  }

  // "/$" will put the cursor after the end of the line, may need to
  // correct that here
  check_cursor(curwin);

  return i;
}

/// Character search commands.
/// cap->arg is BACKWARD for 'F' and 'T', FORWARD for 'f' and 't', true for
/// ',' and false for ';'.
/// cap->nchar is NUL for ',' and ';' (repeat the search)
static void nv_csearch(cmdarg_T *cap)
{
  bool t_cmd;

  if (cap->cmdchar == 't' || cap->cmdchar == 'T') {
    t_cmd = true;
  } else {
    t_cmd = false;
  }

  cap->oap->motion_type = kMTCharWise;
  if (IS_SPECIAL(cap->nchar) || searchc(cap, t_cmd) == false) {
    clearopbeep(cap->oap);
    return;
  }

  curwin->w_set_curswant = true;
  // Include a Tab for "tx" and for "dfx".
  if (gchar_cursor() == TAB && virtual_active(curwin) && cap->arg == FORWARD
      && (t_cmd || cap->oap->op_type != OP_NOP)) {
    colnr_T scol, ecol;

    getvcol(curwin, &curwin->w_cursor, &scol, NULL, &ecol);
    curwin->w_cursor.coladd = ecol - scol;
  } else {
    curwin->w_cursor.coladd = 0;
  }
  adjust_for_sel(cap);
  if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
}

/// "[{", "[(", "]}" or "])": go to Nth unclosed '{', '(', '}' or ')'
/// "[#", "]#": go to start/end of Nth innermost #if..#endif construct.
/// "[/", "[*", "]/", "]*": go to Nth comment start/end.
/// "[m" or "]m" search for prev/next start of (Java) method.
/// "[M" or "]M" search for prev/next end of (Java) method.
static void nv_bracket_block(cmdarg_T *cap, const pos_T *old_pos)
{
  pos_T new_pos = { 0, 0, 0 };
  pos_T *pos = NULL;  // init for GCC
  pos_T prev_pos;
  int n;
  int findc;

  if (cap->nchar == '*') {
    cap->nchar = '/';
  }
  prev_pos.lnum = 0;
  if (cap->nchar == 'm' || cap->nchar == 'M') {
    if (cap->cmdchar == '[') {
      findc = '{';
    } else {
      findc = '}';
    }
    n = 9999;
  } else {
    findc = cap->nchar;
    n = cap->count1;
  }
  for (; n > 0; n--) {
    if ((pos = findmatchlimit(cap->oap, findc,
                              (cap->cmdchar == '[') ? FM_BACKWARD : FM_FORWARD, 0)) == NULL) {
      if (new_pos.lnum == 0) {        // nothing found
        if (cap->nchar != 'm' && cap->nchar != 'M') {
          clearopbeep(cap->oap);
        }
      } else {
        pos = &new_pos;               // use last one found
      }
      break;
    }
    prev_pos = new_pos;
    curwin->w_cursor = *pos;
    new_pos = *pos;
  }
  curwin->w_cursor = *old_pos;

  // Handle "[m", "]m", "[M" and "[M".  The findmatchlimit() only
  // brought us to the match for "[m" and "]M" when inside a method.
  // Try finding the '{' or '}' we want to be at.
  // Also repeat for the given count.
  if (cap->nchar == 'm' || cap->nchar == 'M') {
    int c;
    // norm is true for "]M" and "[m"
    bool norm = ((findc == '{') == (cap->nchar == 'm'));

    n = cap->count1;
    // found a match: we were inside a method
    if (prev_pos.lnum != 0) {
      pos = &prev_pos;
      curwin->w_cursor = prev_pos;
      if (norm) {
        n--;
      }
    } else {
      pos = NULL;
    }
    while (n > 0) {
      while (true) {
        if ((findc == '{' ? dec_cursor() : inc_cursor()) < 0) {
          // if not found anything, that's an error
          if (pos == NULL) {
            clearopbeep(cap->oap);
          }
          n = 0;
          break;
        }
        c = gchar_cursor();
        if (c == '{' || c == '}') {
          // Must have found end/start of class: use it.
          // Or found the place to be at.
          if ((c == findc && norm) || (n == 1 && !norm)) {
            new_pos = curwin->w_cursor;
            pos = &new_pos;
            n = 0;
          } else if (new_pos.lnum == 0) {
            // if no match found at all, we started outside of the
            // class and we're inside now.  Just go on.
            new_pos = curwin->w_cursor;
            pos = &new_pos;
          } else if ((pos = findmatchlimit(cap->oap, findc,
                                           (cap->cmdchar == '[') ? FM_BACKWARD : FM_FORWARD,
                                           0)) == NULL) {
            // found start/end of other method: go to match
            n = 0;
          } else {
            curwin->w_cursor = *pos;
          }
          break;
        }
      }
      n--;
    }
    curwin->w_cursor = *old_pos;
    if (pos == NULL && new_pos.lnum != 0) {
      clearopbeep(cap->oap);
    }
  }
  if (pos != NULL) {
    setpcmark();
    curwin->w_cursor = *pos;
    curwin->w_set_curswant = true;
    if ((fdo_flags & FDO_BLOCK) && KeyTyped
        && cap->oap->op_type == OP_NOP) {
      foldOpenCursor();
    }
  }
}

/// "[" and "]" commands.
/// cap->arg is BACKWARD for "[" and FORWARD for "]".
static void nv_brackets(cmdarg_T *cap)
{
  int flag;
  int n;

  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  pos_T old_pos = curwin->w_cursor;         // cursor position before command
  curwin->w_cursor.coladd = 0;              // TODO(Unknown): don't do this for an error.

  // "[f" or "]f" : Edit file under the cursor (same as "gf")
  if (cap->nchar == 'f') {
    nv_gotofile(cap);
  } else if (vim_strchr("iI\011dD\004", cap->nchar) != NULL) {
    // Find the occurrence(s) of the identifier or define under cursor
    // in current and included files or jump to the first occurrence.
    //
    //                    search       list           jump
    //                  fwd   bwd    fwd   bwd     fwd    bwd
    // identifier       "]i"  "[i"   "]I"  "[I"   "]^I"  "[^I"
    // define           "]d"  "[d"   "]D"  "[D"   "]^D"  "[^D"
    char *ptr;
    size_t len;

    if ((len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0) {
      clearop(cap->oap);
    } else {
      // Make a copy, if the line was changed it will be freed.
      ptr = xmemdupz(ptr, len);
      find_pattern_in_path(ptr, 0, len, true,
                           cap->count0 == 0 ? !isupper(cap->nchar) : false,
                           (((cap->nchar & 0xf) == ('d' & 0xf))
                            ? FIND_DEFINE
                            : FIND_ANY),
                           cap->count1,
                           (isupper(cap->nchar) ? ACTION_SHOW_ALL
                                                : islower(cap->nchar) ? ACTION_SHOW
                                                                      : ACTION_GOTO),
                           (cap->cmdchar == ']'
                            ? curwin->w_cursor.lnum + 1
                            : 1),
                           MAXLNUM,
                           false);
      xfree(ptr);
      curwin->w_set_curswant = true;
    }
  } else if ((cap->cmdchar == '[' && vim_strchr("{(*/#mM", cap->nchar) != NULL)
             || (cap->cmdchar == ']' && vim_strchr("})*/#mM", cap->nchar) != NULL)) {
    // "[{", "[(", "]}" or "])": go to Nth unclosed '{', '(', '}' or ')'
    // "[#", "]#": go to start/end of Nth innermost #if..#endif construct.
    // "[/", "[*", "]/", "]*": go to Nth comment start/end.
    // "[m" or "]m" search for prev/next start of (Java) method.
    // "[M" or "]M" search for prev/next end of (Java) method.
    nv_bracket_block(cap, &old_pos);
  } else if (cap->nchar == '[' || cap->nchar == ']') {
    // "[[", "[]", "]]" and "][": move to start or end of function
    if (cap->nchar == cap->cmdchar) {               // "]]" or "[["
      flag = '{';
    } else {
      flag = '}';                   // "][" or "[]"
    }
    curwin->w_set_curswant = true;
    // Imitate strange Vi behaviour: When using "]]" with an operator we also stop at '}'.
    if (!findpar(&cap->oap->inclusive, cap->arg, cap->count1, flag,
                 (cap->oap->op_type != OP_NOP
                  && cap->arg == FORWARD && flag == '{'))) {
      clearopbeep(cap->oap);
    } else {
      if (cap->oap->op_type == OP_NOP) {
        beginline(BL_WHITE | BL_FIX);
      }
      if ((fdo_flags & FDO_BLOCK) && KeyTyped && cap->oap->op_type == OP_NOP) {
        foldOpenCursor();
      }
    }
  } else if (cap->nchar == 'p' || cap->nchar == 'P') {
    // "[p", "[P", "]P" and "]p": put with indent adjustment
    nv_put_opt(cap, true);
  } else if (cap->nchar == '\'' || cap->nchar == '`') {
    // "['", "[`", "]'" and "]`": jump to next mark
    fmark_T *fm = pos_to_mark(curbuf, NULL, curwin->w_cursor);
    assert(fm != NULL);
    fmark_T *prev_fm;
    for (n = cap->count1; n > 0; n--) {
      prev_fm = fm;
      fm = getnextmark(&fm->mark, cap->cmdchar == '[' ? BACKWARD : FORWARD,
                       cap->nchar == '\'');
      if (fm == NULL) {
        break;
      }
    }
    if (fm == NULL) {
      fm = prev_fm;
    }
    MarkMove flags = kMarkContext;
    flags |= cap->nchar == '\'' ? kMarkBeginLine : 0;
    nv_mark_move_to(cap, flags, fm);
  } else if (cap->nchar >= K_RIGHTRELEASE && cap->nchar <= K_LEFTMOUSE) {
    // [ or ] followed by a middle mouse click: put selected text with
    // indent adjustment.  Any other button just does as usual.
    do_mouse(cap->oap, cap->nchar,
             (cap->cmdchar == ']') ? FORWARD : BACKWARD,
             cap->count1, PUT_FIXINDENT);
  } else if (cap->nchar == 'z') {
    // "[z" and "]z": move to start or end of open fold.
    if (foldMoveTo(false, cap->cmdchar == ']' ? FORWARD : BACKWARD,
                   cap->count1) == false) {
      clearopbeep(cap->oap);
    }
  } else if (cap->nchar == 'c') {
    // "[c" and "]c": move to next or previous diff-change.
    if (diff_move_to(cap->cmdchar == ']' ? FORWARD : BACKWARD,
                     cap->count1) == false) {
      clearopbeep(cap->oap);
    }
  } else if (cap->nchar == 'r' || cap->nchar == 's' || cap->nchar == 'S') {
    // "[r", "[s", "[S", "]r", "]s" and "]S": move to next spell error.
    setpcmark();
    for (n = 0; n < cap->count1; n++) {
      if (spell_move_to(curwin, cap->cmdchar == ']' ? FORWARD : BACKWARD,
                        cap->nchar == 's'
                        ? SMT_ALL
                        : cap->nchar == 'r' ? SMT_RARE : SMT_BAD,
                        false, NULL) == 0) {
        clearopbeep(cap->oap);
        break;
      }
      curwin->w_set_curswant = true;
    }
    if (cap->oap->op_type == OP_NOP && (fdo_flags & FDO_SEARCH) && KeyTyped) {
      foldOpenCursor();
    }
  } else {
    // Not a valid cap->nchar.
    clearopbeep(cap->oap);
  }
}

/// Handle Normal mode "%" command.
static void nv_percent(cmdarg_T *cap)
{
  linenr_T lnum = curwin->w_cursor.lnum;

  cap->oap->inclusive = true;
  if (cap->count0) {  // {cnt}% : goto {cnt} percentage in file
    if (cap->count0 > 100) {
      clearopbeep(cap->oap);
    } else {
      cap->oap->motion_type = kMTLineWise;
      setpcmark();
      // Round up, so 'normal 100%' always jumps at the line line.
      // Beyond 21474836 lines, (ml_line_count * 100 + 99) would
      // overflow on 32-bits, so use a formula with less accuracy
      // to avoid overflows.
      if (curbuf->b_ml.ml_line_count >= 21474836) {
        curwin->w_cursor.lnum = (curbuf->b_ml.ml_line_count + 99)
                                / 100 * cap->count0;
      } else {
        curwin->w_cursor.lnum = (curbuf->b_ml.ml_line_count *
                                 cap->count0 + 99) / 100;
      }
      if (curwin->w_cursor.lnum < 1) {
        curwin->w_cursor.lnum = 1;
      }
      if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      }
      beginline(BL_SOL | BL_FIX);
    }
  } else {  // "%" : go to matching paren
    pos_T *pos;
    cap->oap->motion_type = kMTCharWise;
    cap->oap->use_reg_one = true;
    if ((pos = findmatch(cap->oap, NUL)) == NULL) {
      clearopbeep(cap->oap);
    } else {
      setpcmark();
      curwin->w_cursor = *pos;
      curwin->w_set_curswant = true;
      curwin->w_cursor.coladd = 0;
      adjust_for_sel(cap);
    }
  }
  if (cap->oap->op_type == OP_NOP
      && lnum != curwin->w_cursor.lnum
      && (fdo_flags & FDO_PERCENT)
      && KeyTyped) {
    foldOpenCursor();
  }
}

/// Handle "(" and ")" commands.
/// cap->arg is BACKWARD for "(" and FORWARD for ")".
static void nv_brace(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->use_reg_one = true;
  // The motion used to be inclusive for "(", but that is not what Vi does.
  cap->oap->inclusive = false;
  curwin->w_set_curswant = true;

  if (findsent(cap->arg, cap->count1) == FAIL) {
    clearopbeep(cap->oap);
    return;
  }

  // Don't leave the cursor on the NUL past end of line.
  adjust_cursor(cap->oap);
  curwin->w_cursor.coladd = 0;
  if ((fdo_flags & FDO_BLOCK) && KeyTyped && cap->oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
}

/// "m" command: Mark a position.
static void nv_mark(cmdarg_T *cap)
{
  if (checkclearop(cap->oap)) {
    return;
  }

  if (setmark(cap->nchar) == false) {
    clearopbeep(cap->oap);
  }
}

/// "{" and "}" commands.
/// cmd->arg is BACKWARD for "{" and FORWARD for "}".
static void nv_findpar(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  cap->oap->use_reg_one = true;
  curwin->w_set_curswant = true;
  if (!findpar(&cap->oap->inclusive, cap->arg, cap->count1, NUL, false)) {
    clearopbeep(cap->oap);
    return;
  }

  curwin->w_cursor.coladd = 0;
  if ((fdo_flags & FDO_BLOCK) && KeyTyped && cap->oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
}

/// "u" command: Undo or make lower case.
static void nv_undo(cmdarg_T *cap)
{
  if (cap->oap->op_type == OP_LOWER
      || VIsual_active) {
    // translate "<Visual>u" to "<Visual>gu" and "guu" to "gugu"
    cap->cmdchar = 'g';
    cap->nchar = 'u';
    nv_operator(cap);
  } else {
    nv_kundo(cap);
  }
}

/// <Undo> command.
static void nv_kundo(cmdarg_T *cap)
{
  if (checkclearopq(cap->oap)) {
    return;
  }

  if (bt_prompt(curbuf)) {
    clearopbeep(cap->oap);
    return;
  }
  u_undo(cap->count1);
  curwin->w_set_curswant = true;
}

/// Handle the "r" command.
static void nv_replace(cmdarg_T *cap)
{
  int had_ctrl_v;

  if (checkclearop(cap->oap)) {
    return;
  }
  if (bt_prompt(curbuf) && !prompt_curpos_editable()) {
    clearopbeep(cap->oap);
    return;
  }

  // get another character
  if (cap->nchar == Ctrl_V || cap->nchar == Ctrl_Q) {
    had_ctrl_v = Ctrl_V;
    cap->nchar = get_literal(false);
    // Don't redo a multibyte character with CTRL-V.
    if (cap->nchar > DEL) {
      had_ctrl_v = NUL;
    }
  } else {
    had_ctrl_v = NUL;
  }

  // Abort if the character is a special key.
  if (IS_SPECIAL(cap->nchar)) {
    clearopbeep(cap->oap);
    return;
  }

  // Visual mode "r"
  if (VIsual_active) {
    if (got_int) {
      got_int = false;
    }
    if (had_ctrl_v) {
      // Use a special (negative) number to make a difference between a
      // literal CR or NL and a line break.
      if (cap->nchar == CAR) {
        cap->nchar = REPLACE_CR_NCHAR;
      } else if (cap->nchar == NL) {
        cap->nchar = REPLACE_NL_NCHAR;
      }
    }
    nv_operator(cap);
    return;
  }

  // Break tabs, etc.
  if (virtual_active(curwin)) {
    if (u_save_cursor() == false) {
      return;
    }
    if (gchar_cursor() == NUL) {
      // Add extra space and put the cursor on the first one.
      coladvance_force((colnr_T)(getviscol() + cap->count1));
      assert(cap->count1 <= INT_MAX);
      curwin->w_cursor.col -= (colnr_T)cap->count1;
    } else if (gchar_cursor() == TAB) {
      coladvance_force(getviscol());
    }
  }

  // Abort if not enough characters to replace.
  if ((size_t)get_cursor_pos_len() < (unsigned)cap->count1
      || (mb_charlen(get_cursor_pos_ptr()) < cap->count1)) {
    clearopbeep(cap->oap);
    return;
  }

  // Replacing with a TAB is done by edit() when it is complicated because
  // 'expandtab' or 'smarttab' is set.  CTRL-V TAB inserts a literal TAB.
  // Other characters are done below to avoid problems with things like
  // CTRL-V 048 (for edit() this would be R CTRL-V 0 ESC).
  if (had_ctrl_v != Ctrl_V && cap->nchar == '\t' && (curbuf->b_p_et || p_sta)) {
    stuffnumReadbuff(cap->count1);
    stuffcharReadbuff('R');
    stuffcharReadbuff('\t');
    stuffcharReadbuff(ESC);
    return;
  }

  // save line for undo
  if (u_save_cursor() == false) {
    return;
  }

  if (had_ctrl_v != Ctrl_V && (cap->nchar == '\r' || cap->nchar == '\n')) {
    // Replace character(s) by a single newline.
    // Strange vi behaviour: Only one newline is inserted.
    // Delete the characters here.
    // Insert the newline with an insert command, takes care of
    // autoindent.      The insert command depends on being on the last
    // character of a line or not.
    del_chars(cap->count1, false);        // delete the characters
    stuffcharReadbuff('\r');
    stuffcharReadbuff(ESC);

    // Give 'r' to edit(), to get the redo command right.
    invoke_edit(cap, true, 'r', false);
  } else {
    prep_redo(cap->oap->regname, cap->count1,
              NUL, 'r', NUL, had_ctrl_v, cap->nchar);

    curbuf->b_op_start = curwin->w_cursor;
    const int old_State = State;

    if (cap->ncharC1 != 0) {
      AppendCharToRedobuff(cap->ncharC1);
    }
    if (cap->ncharC2 != 0) {
      AppendCharToRedobuff(cap->ncharC2);
    }

    // This is slow, but it handles replacing a single-byte with a
    // multi-byte and the other way around.  Also handles adding
    // composing characters for utf-8.
    for (int n = cap->count1; n > 0; n--) {
      State = MODE_REPLACE;
      if (cap->nchar == Ctrl_E || cap->nchar == Ctrl_Y) {
        int c = ins_copychar(curwin->w_cursor.lnum
                             + (cap->nchar == Ctrl_Y ? -1 : 1));
        if (c != NUL) {
          ins_char(c);
        } else {
          // will be decremented further down
          curwin->w_cursor.col++;
        }
      } else {
        ins_char(cap->nchar);
      }
      State = old_State;
      if (cap->ncharC1 != 0) {
        ins_char(cap->ncharC1);
      }
      if (cap->ncharC2 != 0) {
        ins_char(cap->ncharC2);
      }
    }
    curwin->w_cursor.col--;         // cursor on the last replaced char
    // if the character on the left of the current cursor is a multi-byte
    // character, move two characters left
    mb_adjust_cursor();
    curbuf->b_op_end = curwin->w_cursor;
    curwin->w_set_curswant = true;
    set_last_insert(cap->nchar);
  }

  foldUpdateAfterInsert();
}

/// 'o': Exchange start and end of Visual area.
/// 'O': same, but in block mode exchange left and right corners.
static void v_swap_corners(int cmdchar)
{
  colnr_T left, right;

  if (cmdchar == 'O' && VIsual_mode == Ctrl_V) {
    pos_T old_cursor = curwin->w_cursor;
    getvcols(curwin, &old_cursor, &VIsual, &left, &right);
    curwin->w_cursor.lnum = VIsual.lnum;
    coladvance(curwin, left);
    VIsual = curwin->w_cursor;

    curwin->w_cursor.lnum = old_cursor.lnum;
    curwin->w_curswant = right;
    // 'selection "exclusive" and cursor at right-bottom corner: move it
    // right one column
    if (old_cursor.lnum >= VIsual.lnum && *p_sel == 'e') {
      curwin->w_curswant++;
    }
    coladvance(curwin, curwin->w_curswant);
    if (curwin->w_cursor.col == old_cursor.col
        && (!virtual_active(curwin)
            || curwin->w_cursor.coladd ==
            old_cursor.coladd)) {
      curwin->w_cursor.lnum = VIsual.lnum;
      if (old_cursor.lnum <= VIsual.lnum && *p_sel == 'e') {
        right++;
      }
      coladvance(curwin, right);
      VIsual = curwin->w_cursor;

      curwin->w_cursor.lnum = old_cursor.lnum;
      coladvance(curwin, left);
      curwin->w_curswant = left;
    }
  } else {
    pos_T old_cursor = curwin->w_cursor;
    curwin->w_cursor = VIsual;
    VIsual = old_cursor;
    curwin->w_set_curswant = true;
  }
}

/// "R" (cap->arg is false) and "gR" (cap->arg is true).
static void nv_Replace(cmdarg_T *cap)
{
  if (VIsual_active) {          // "R" is replace lines
    cap->cmdchar = 'c';
    cap->nchar = NUL;
    VIsual_mode_orig = VIsual_mode;     // remember original area for gv
    VIsual_mode = 'V';
    nv_operator(cap);
    return;
  }

  if (checkclearopq(cap->oap)) {
    return;
  }

  if (!MODIFIABLE(curbuf)) {
    emsg(_(e_modifiable));
  } else {
    if (virtual_active(curwin)) {
      coladvance(curwin, getviscol());
    }
    invoke_edit(cap, false, cap->arg ? 'V' : 'R', false);
  }
}

/// "gr".
static void nv_vreplace(cmdarg_T *cap)
{
  if (VIsual_active) {
    cap->cmdchar = 'r';
    cap->nchar = cap->extra_char;
    nv_replace(cap);            // Do same as "r" in Visual mode for now
    return;
  }

  if (checkclearopq(cap->oap)) {
    return;
  }

  if (!MODIFIABLE(curbuf)) {
    emsg(_(e_modifiable));
  } else {
    if (cap->extra_char == Ctrl_V || cap->extra_char == Ctrl_Q) {
      // get another character
      cap->extra_char = get_literal(false);
    }
    if (cap->extra_char < ' ') {
      // Prefix a control character with CTRL-V to avoid it being used as
      // a command.
      stuffcharReadbuff(Ctrl_V);
    }
    stuffcharReadbuff(cap->extra_char);
    stuffcharReadbuff(ESC);
    if (virtual_active(curwin)) {
      coladvance(curwin, getviscol());
    }
    invoke_edit(cap, true, 'v', false);
  }
}

/// Swap case for "~" command, when it does not work like an operator.
static void n_swapchar(cmdarg_T *cap)
{
  bool did_change = false;

  if (checkclearopq(cap->oap)) {
    return;
  }

  if (LINEEMPTY(curwin->w_cursor.lnum) && vim_strchr(p_ww, '~') == NULL) {
    clearopbeep(cap->oap);
    return;
  }

  prep_redo_cmd(cap);

  if (u_save_cursor() == false) {
    return;
  }

  pos_T startpos = curwin->w_cursor;
  for (int n = cap->count1; n > 0; n--) {
    did_change |= swapchar(cap->oap->op_type, &curwin->w_cursor);
    inc_cursor();
    if (gchar_cursor() == NUL) {
      if (vim_strchr(p_ww, '~') != NULL
          && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
        curwin->w_cursor.lnum++;
        curwin->w_cursor.col = 0;
        if (n > 1) {
          if (u_savesub(curwin->w_cursor.lnum) == false) {
            break;
          }
          u_clearline(curbuf);
        }
      } else {
        break;
      }
    }
  }

  check_cursor(curwin);
  curwin->w_set_curswant = true;
  if (did_change) {
    changed_lines(curbuf, startpos.lnum, startpos.col, curwin->w_cursor.lnum + 1,
                  0, true);
    curbuf->b_op_start = startpos;
    curbuf->b_op_end = curwin->w_cursor;
    if (curbuf->b_op_end.col > 0) {
      curbuf->b_op_end.col--;
    }
  }
}

/// Move the cursor to the mark position
///
/// Wrapper to mark_move_to() that also handles normal mode command arguments.
/// @note  It will switch the buffer if neccesarry, move the cursor and set the
/// view depending on the given flags.
/// @param cap  command line arguments
/// @param flags for mark_move_to()
/// @param mark  mark
/// @return  The result of calling mark_move_to()
static MarkMoveRes nv_mark_move_to(cmdarg_T *cap, MarkMove flags, fmark_T *fm)
{
  MarkMoveRes res = mark_move_to(fm, flags);
  if (res & kMarkMoveFailed) {
    clearop(cap->oap);
  }
  cap->oap->motion_type = flags & kMarkBeginLine ? kMTLineWise : kMTCharWise;
  if (cap->cmdchar == '`') {
    cap->oap->use_reg_one = true;
  }
  cap->oap->inclusive = false;  // ignored if not kMTCharWise
  curwin->w_set_curswant = true;
  return res;
}

/// Handle commands that are operators in Visual mode.
static void v_visop(cmdarg_T *cap)
{
  static char trans[] = "YyDdCcxdXdAAIIrr";

  // Uppercase means linewise, except in block mode, then "D" deletes till
  // the end of the line, and "C" replaces till EOL
  if (isupper(cap->cmdchar)) {
    if (VIsual_mode != Ctrl_V) {
      VIsual_mode_orig = VIsual_mode;
      VIsual_mode = 'V';
    } else if (cap->cmdchar == 'C' || cap->cmdchar == 'D') {
      curwin->w_curswant = MAXCOL;
    }
  }
  cap->cmdchar = (uint8_t)(*(vim_strchr(trans, cap->cmdchar) + 1));
  nv_operator(cap);
}

/// "s" and "S" commands.
static void nv_subst(cmdarg_T *cap)
{
  if (bt_prompt(curbuf) && !prompt_curpos_editable()) {
    clearopbeep(cap->oap);
    return;
  }
  if (VIsual_active) {  // "vs" and "vS" are the same as "vc"
    if (cap->cmdchar == 'S') {
      VIsual_mode_orig = VIsual_mode;
      VIsual_mode = 'V';
    }
    cap->cmdchar = 'c';
    nv_operator(cap);
  } else {
    nv_optrans(cap);
  }
}

/// Abbreviated commands.
static void nv_abbrev(cmdarg_T *cap)
{
  if (cap->cmdchar == K_DEL || cap->cmdchar == K_KDEL) {
    cap->cmdchar = 'x';                 // DEL key behaves like 'x'
  }
  // in Visual mode these commands are operators
  if (VIsual_active) {
    v_visop(cap);
  } else {
    nv_optrans(cap);
  }
}

/// Translate a command into another command.
static void nv_optrans(cmdarg_T *cap)
{
  static const char *(ar[]) = { "dl", "dh", "d$", "c$", "cl", "cc", "yy",
                                ":s\r" };
  static const char *str = "xXDCsSY&";

  if (!checkclearopq(cap->oap)) {
    if (cap->count0) {
      stuffnumReadbuff(cap->count0);
    }
    stuffReadbuff(ar[strchr(str, (char)cap->cmdchar) - str]);
  }
  cap->opcount = 0;
}

/// "'" and "`" commands.  Also for "g'" and "g`".
/// cap->arg is true for "'" and "g'".
static void nv_gomark(cmdarg_T *cap)
{
  int name;
  MarkMove flags = jop_flags & JOP_VIEW ? kMarkSetView : 0;  // flags for moving to the mark
  if (cap->oap->op_type != OP_NOP) {
    // When there is a pending operator, do not restore the view as this is usually unexpected.
    flags = 0;
  }
  MarkMoveRes move_res = 0;  // Result from moving to the mark
  const bool old_KeyTyped = KeyTyped;  // getting file may reset it

  if (cap->cmdchar == 'g') {
    name = cap->extra_char;
    flags |= KMarkNoContext;
  } else {
    name = cap->nchar;
    flags |= kMarkContext;
  }
  flags |= cap->arg ? kMarkBeginLine : 0;
  flags |= cap->count0 ? kMarkSetView : 0;

  fmark_T *fm = mark_get(curbuf, curwin, NULL, kMarkAll, name);
  move_res = nv_mark_move_to(cap, flags, fm);

  // May need to clear the coladd that a mark includes.
  if (!virtual_active(curwin)) {
    curwin->w_cursor.coladd = 0;
  }

  if (cap->oap->op_type == OP_NOP
      && move_res & kMarkMoveSuccess
      && (move_res & kMarkSwitchedBuf || move_res & kMarkChangedCursor)
      && (fdo_flags & FDO_MARK)
      && old_KeyTyped) {
    foldOpenCursor();
  }
}

/// Handle CTRL-O, CTRL-I, "g;", "g,", and "CTRL-Tab" commands.
/// Movement in the jumplist and changelist.
static void nv_pcmark(cmdarg_T *cap)
{
  fmark_T *fm = NULL;
  MarkMove flags = jop_flags & JOP_VIEW ? kMarkSetView : 0;  // flags for moving to the mark
  MarkMoveRes move_res = 0;  // Result from moving to the mark
  const bool old_KeyTyped = KeyTyped;  // getting file may reset it.

  if (checkclearopq(cap->oap)) {
    return;
  }

  if (cap->cmdchar == TAB && mod_mask == MOD_MASK_CTRL) {
    if (!goto_tabpage_lastused()) {
      clearopbeep(cap->oap);
    }
    return;
  }

  if (cap->cmdchar == 'g') {
    fm = get_changelist(curbuf, curwin, cap->count1);
  } else {
    fm = get_jumplist(curwin, cap->count1);
    flags |= KMarkNoContext | kMarkJumpList;
  }
  // Changelist and jumplist have their own error messages. Therefore avoid
  // calling nv_mark_move_to() when not found to avoid incorrect error
  // messages.
  if (fm != NULL) {
    move_res = nv_mark_move_to(cap, flags, fm);
  } else if (cap->cmdchar == 'g') {
    if (curbuf->b_changelistlen == 0) {
      emsg(_(e_changelist_is_empty));
    } else if (cap->count1 < 0) {
      emsg(_("E662: At start of changelist"));
    } else {
      emsg(_("E663: At end of changelist"));
    }
  } else {
    clearopbeep(cap->oap);
  }
  if (cap->oap->op_type == OP_NOP
      && (move_res & kMarkSwitchedBuf || move_res & kMarkChangedLine)
      && (fdo_flags & FDO_MARK)
      && old_KeyTyped) {
    foldOpenCursor();
  }
}

/// Handle '"' command.
static void nv_regname(cmdarg_T *cap)
{
  if (checkclearop(cap->oap)) {
    return;
  }
  if (cap->nchar == '=') {
    cap->nchar = get_expr_register();
  }
  if (cap->nchar != NUL && valid_yank_reg(cap->nchar, false)) {
    cap->oap->regname = cap->nchar;
    cap->opcount = cap->count0;         // remember count before '"'
    set_reg_var(cap->oap->regname);
  } else {
    clearopbeep(cap->oap);
  }
}

/// Handle "v", "V" and "CTRL-V" commands.
/// Also for "gh", "gH" and "g^H" commands: Always start Select mode, cap->arg
/// is true.
/// Handle CTRL-Q just like CTRL-V.
static void nv_visual(cmdarg_T *cap)
{
  if (cap->cmdchar == Ctrl_Q) {
    cap->cmdchar = Ctrl_V;
  }

  // 'v', 'V' and CTRL-V can be used while an operator is pending to make it
  // charwise, linewise, or blockwise.
  if (cap->oap->op_type != OP_NOP) {
    motion_force = cap->oap->motion_force = cap->cmdchar;
    finish_op = false;          // operator doesn't finish now but later
    return;
  }

  VIsual_select = cap->arg;
  if (VIsual_active) {      // change Visual mode
    if (VIsual_mode == cap->cmdchar) {      // stop visual mode
      end_visual_mode();
    } else {                                  // toggle char/block mode
                                              //           or char/line mode
      VIsual_mode = cap->cmdchar;
      showmode();
      may_trigger_modechanged();
    }
    redraw_curbuf_later(UPD_INVERTED);  // update the inversion
  } else {                // start Visual mode
    if (cap->count0 > 0 && resel_VIsual_mode != NUL) {
      // use previously selected part
      VIsual = curwin->w_cursor;

      VIsual_active = true;
      VIsual_reselect = true;
      if (!cap->arg) {
        // start Select mode when 'selectmode' contains "cmd"
        may_start_select('c');
      }
      setmouse();
      if (p_smd && msg_silent == 0) {
        redraw_cmdline = true;              // show visual mode later
      }
      // For V and ^V, we multiply the number of lines even if there
      // was only one -- webb
      if (resel_VIsual_mode != 'v' || resel_VIsual_line_count > 1) {
        curwin->w_cursor.lnum += resel_VIsual_line_count * cap->count0 - 1;
        check_cursor(curwin);
      }
      VIsual_mode = resel_VIsual_mode;
      if (VIsual_mode == 'v') {
        if (resel_VIsual_line_count <= 1) {
          update_curswant_force();
          assert(cap->count0 >= INT_MIN && cap->count0 <= INT_MAX);
          curwin->w_curswant += resel_VIsual_vcol * cap->count0;
          if (*p_sel != 'e') {
            curwin->w_curswant--;
          }
        } else {
          curwin->w_curswant = resel_VIsual_vcol;
        }
        coladvance(curwin, curwin->w_curswant);
      }
      if (resel_VIsual_vcol == MAXCOL) {
        curwin->w_curswant = MAXCOL;
        coladvance(curwin, MAXCOL);
      } else if (VIsual_mode == Ctrl_V) {
        // Update curswant on the original line, that is where "col" is valid.
        linenr_T lnum = curwin->w_cursor.lnum;
        curwin->w_cursor.lnum = VIsual.lnum;
        update_curswant_force();
        assert(cap->count0 >= INT_MIN && cap->count0 <= INT_MAX);
        curwin->w_curswant += resel_VIsual_vcol * cap->count0 - 1;
        curwin->w_cursor.lnum = lnum;
        coladvance(curwin, curwin->w_curswant);
      } else {
        curwin->w_set_curswant = true;
      }
      redraw_curbuf_later(UPD_INVERTED);  // show the inversion
    } else {
      if (!cap->arg) {
        // start Select mode when 'selectmode' contains "cmd"
        may_start_select('c');
      }
      n_start_visual_mode(cap->cmdchar);
      if (VIsual_mode != 'V' && *p_sel == 'e') {
        cap->count1++;          // include one more char
      }
      if (cap->count0 > 0 && --cap->count1 > 0) {
        // With a count select that many characters or lines.
        if (VIsual_mode == 'v' || VIsual_mode == Ctrl_V) {
          nv_right(cap);
        } else if (VIsual_mode == 'V') {
          nv_down(cap);
        }
      }
    }
  }
}

/// Start selection for Shift-movement keys.
void start_selection(void)
{
  // if 'selectmode' contains "key", start Select mode
  may_start_select('k');
  n_start_visual_mode('v');
}

/// Start Select mode, if "c" is in 'selectmode' and not in a mapping or menu.
/// When "c" is 'o' (checking for "mouse") then also when mapped.
void may_start_select(int c)
{
  VIsual_select = (c == 'o' || (stuff_empty() && typebuf_typed()))
                  && vim_strchr(p_slm, c) != NULL;
}

/// Start Visual mode "c".
/// Should set VIsual_select before calling this.
static void n_start_visual_mode(int c)
{
  VIsual_mode = c;
  VIsual_active = true;
  VIsual_reselect = true;
  // Corner case: the 0 position in a tab may change when going into
  // virtualedit.  Recalculate curwin->w_cursor to avoid bad highlighting.
  //
  if (c == Ctrl_V && (get_ve_flags(curwin) & VE_BLOCK) && gchar_cursor() == TAB) {
    validate_virtcol(curwin);
    coladvance(curwin, curwin->w_virtcol);
  }
  VIsual = curwin->w_cursor;

  foldAdjustVisual();

  may_trigger_modechanged();
  setmouse();
  // Check for redraw after changing the state.
  conceal_check_cursor_line();

  if (p_smd && msg_silent == 0) {
    redraw_cmdline = true;      // show visual mode later
  }
  // Only need to redraw this line, unless still need to redraw an old
  // Visual area (when 'lazyredraw' is set).
  if (curwin->w_redr_type < UPD_INVERTED) {
    curwin->w_old_cursor_lnum = curwin->w_cursor.lnum;
    curwin->w_old_visual_lnum = curwin->w_cursor.lnum;
  }
  redraw_curbuf_later(UPD_VALID);
}

/// CTRL-W: Window commands
static void nv_window(cmdarg_T *cap)
{
  if (cap->nchar == ':') {
    // "CTRL-W :" is the same as typing ":"; useful in a terminal window
    cap->cmdchar = ':';
    cap->nchar = NUL;
    nv_colon(cap);
  } else if (!checkclearop(cap->oap)) {
    do_window(cap->nchar, cap->count0, NUL);  // everything is in window.c
  }
}

/// CTRL-Z: Suspend
static void nv_suspend(cmdarg_T *cap)
{
  clearop(cap->oap);
  if (VIsual_active) {
    end_visual_mode();                  // stop Visual mode
  }
  do_cmdline_cmd("st");
}

/// "gv": Reselect the previous Visual area.  If Visual already active,
///       exchange previous and current Visual area.
static void nv_gv_cmd(cmdarg_T *cap)
{
  if (checkclearop(cap->oap)) {
    return;
  }

  if (curbuf->b_visual.vi_start.lnum == 0
      || curbuf->b_visual.vi_start.lnum > curbuf->b_ml.ml_line_count
      || curbuf->b_visual.vi_end.lnum == 0) {
    beep_flush();
    return;
  }

  pos_T tpos;
  // set w_cursor to the start of the Visual area, tpos to the end
  if (VIsual_active) {
    int i = VIsual_mode;
    VIsual_mode = curbuf->b_visual.vi_mode;
    curbuf->b_visual.vi_mode = i;
    curbuf->b_visual_mode_eval = i;
    i = curwin->w_curswant;
    curwin->w_curswant = curbuf->b_visual.vi_curswant;
    curbuf->b_visual.vi_curswant = i;

    tpos = curbuf->b_visual.vi_end;
    curbuf->b_visual.vi_end = curwin->w_cursor;
    curwin->w_cursor = curbuf->b_visual.vi_start;
    curbuf->b_visual.vi_start = VIsual;
  } else {
    VIsual_mode = curbuf->b_visual.vi_mode;
    curwin->w_curswant = curbuf->b_visual.vi_curswant;
    tpos = curbuf->b_visual.vi_end;
    curwin->w_cursor = curbuf->b_visual.vi_start;
  }

  VIsual_active = true;
  VIsual_reselect = true;

  // Set Visual to the start and w_cursor to the end of the Visual
  // area.  Make sure they are on an existing character.
  check_cursor(curwin);
  VIsual = curwin->w_cursor;
  curwin->w_cursor = tpos;
  check_cursor(curwin);
  update_topline(curwin);

  // When called from normal "g" command: start Select mode when
  // 'selectmode' contains "cmd".  When called for K_SELECT, always
  // start Select mode.
  if (cap->arg) {
    VIsual_select = true;
    VIsual_select_reg = 0;
  } else {
    may_start_select('c');
  }
  setmouse();
  redraw_curbuf_later(UPD_INVERTED);
  showmode();
}

/// "g0", "g^" : Like "0" and "^" but for screen lines.
/// "gm": middle of "g0" and "g$".
void nv_g_home_m_cmd(cmdarg_T *cap)
{
  int i;
  const bool flag = cap->nchar == '^';

  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  if (curwin->w_p_wrap && curwin->w_width_inner != 0) {
    int width1 = curwin->w_width_inner - win_col_off(curwin);
    int width2 = width1 + win_col_off2(curwin);

    validate_virtcol(curwin);
    i = 0;
    if (curwin->w_virtcol >= (colnr_T)width1 && width2 > 0) {
      i = (curwin->w_virtcol - width1) / width2 * width2 + width1;
    }

    // When ending up below 'smoothscroll' marker, move just beyond it so
    // that skipcol is not adjusted later.
    if (curwin->w_skipcol > 0 && curwin->w_cursor.lnum == curwin->w_topline) {
      int overlap = sms_marker_overlap(curwin, -1);
      if (overlap > 0 && i == curwin->w_skipcol) {
        i += overlap;
      }
    }
  } else {
    i = curwin->w_leftcol;
  }
  // Go to the middle of the screen line.  When 'number' or
  // 'relativenumber' is on and lines are wrapping the middle can be more
  // to the left.
  if (cap->nchar == 'm') {
    i += (curwin->w_width_inner - win_col_off(curwin)
          + ((curwin->w_p_wrap && i > 0) ? win_col_off2(curwin) : 0)) / 2;
  }
  coladvance(curwin, (colnr_T)i);
  if (flag) {
    do {
      i = gchar_cursor();
    } while (ascii_iswhite(i) && oneright() == OK);
    curwin->w_valid &= ~VALID_WCOL;
  }
  curwin->w_set_curswant = true;
  adjust_skipcol();
}

/// "g_": to the last non-blank character in the line or <count> lines downward.
static void nv_g_underscore_cmd(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = true;
  curwin->w_curswant = MAXCOL;
  if (cursor_down(cap->count1 - 1, cap->oap->op_type == OP_NOP) == false) {
    clearopbeep(cap->oap);
    return;
  }

  char *ptr = get_cursor_line_ptr();

  // In Visual mode we may end up after the line.
  if (curwin->w_cursor.col > 0 && ptr[curwin->w_cursor.col] == NUL) {
    curwin->w_cursor.col--;
  }

  // Decrease the cursor column until it's on a non-blank.
  while (curwin->w_cursor.col > 0 && ascii_iswhite(ptr[curwin->w_cursor.col])) {
    curwin->w_cursor.col--;
  }
  curwin->w_set_curswant = true;
  adjust_for_sel(cap);
}

/// "g$" : Like "$" but for screen lines.
static void nv_g_dollar_cmd(cmdarg_T *cap)
{
  oparg_T *oap = cap->oap;
  int i;
  int col_off = win_col_off(curwin);
  const bool flag = cap->nchar == K_END || cap->nchar == K_KEND;

  oap->motion_type = kMTCharWise;
  oap->inclusive = true;
  if (curwin->w_p_wrap && curwin->w_width_inner != 0) {
    curwin->w_curswant = MAXCOL;              // so we stay at the end
    if (cap->count1 == 1) {
      int width1 = curwin->w_width_inner - col_off;
      int width2 = width1 + win_col_off2(curwin);

      validate_virtcol(curwin);
      i = width1 - 1;
      if (curwin->w_virtcol >= (colnr_T)width1) {
        i += ((curwin->w_virtcol - width1) / width2 + 1) * width2;
      }
      coladvance(curwin, (colnr_T)i);

      // Make sure we stick in this column.
      update_curswant_force();
      if (curwin->w_cursor.col > 0 && curwin->w_p_wrap) {
        // Check for landing on a character that got split at
        // the end of the line.  We do not want to advance to
        // the next screen line.
        if (curwin->w_virtcol > (colnr_T)i) {
          curwin->w_cursor.col--;
        }
      }
    } else if (nv_screengo(oap, FORWARD, cap->count1 - 1) == false) {
      clearopbeep(oap);
    }
  } else {
    if (cap->count1 > 1) {
      // if it fails, let the cursor still move to the last char
      cursor_down(cap->count1 - 1, false);
    }
    i = curwin->w_leftcol + curwin->w_width_inner - col_off - 1;
    coladvance(curwin, (colnr_T)i);

    // if the character doesn't fit move one back
    if (curwin->w_cursor.col > 0 && utf_ptr2cells(get_cursor_pos_ptr()) > 1) {
      colnr_T vcol;

      getvvcol(curwin, &curwin->w_cursor, NULL, NULL, &vcol);
      if (vcol >= curwin->w_leftcol + curwin->w_width_inner - col_off) {
        curwin->w_cursor.col--;
      }
    }

    // Make sure we stick in this column.
    update_curswant_force();
  }
  if (flag) {
    do {
      i = gchar_cursor();
    } while (ascii_iswhite(i) && oneleft() == OK);
    curwin->w_valid &= ~VALID_WCOL;
  }
}

/// "gi": start Insert at the last position.
static void nv_gi_cmd(cmdarg_T *cap)
{
  if (curbuf->b_last_insert.mark.lnum != 0) {
    curwin->w_cursor = curbuf->b_last_insert.mark;
    check_cursor_lnum(curwin);
    int i = (int)get_cursor_line_len();
    if (curwin->w_cursor.col > (colnr_T)i) {
      if (virtual_active(curwin)) {
        curwin->w_cursor.coladd += curwin->w_cursor.col - i;
      }
      curwin->w_cursor.col = i;
    }
  }
  cap->cmdchar = 'i';
  nv_edit(cap);
}

/// Commands starting with "g".
static void nv_g_cmd(cmdarg_T *cap)
{
  oparg_T *oap = cap->oap;
  int i;

  switch (cap->nchar) {
  // "g^A/g^X": Sequentially increment visually selected region.
  case Ctrl_A:
  case Ctrl_X:
    if (VIsual_active) {
      cap->arg = true;
      cap->cmdchar = cap->nchar;
      cap->nchar = NUL;
      nv_addsub(cap);
    } else {
      clearopbeep(oap);
    }
    break;

  // "gR": Enter virtual replace mode.
  case 'R':
    cap->arg = true;
    nv_Replace(cap);
    break;

  case 'r':
    nv_vreplace(cap);
    break;

  case '&':
    do_cmdline_cmd("%s//~/&");
    break;

  // "gv": Reselect the previous Visual area.  If Visual already active,
  //       exchange previous and current Visual area.
  case 'v':
    nv_gv_cmd(cap);
    break;
  // "gV": Don't reselect the previous Visual area after a Select mode mapping of menu.
  case 'V':
    VIsual_reselect = false;
    break;

  // "gh":  start Select mode.
  // "gH":  start Select line mode.
  // "g^H": start Select block mode.
  case K_BS:
    cap->nchar = Ctrl_H;
    FALLTHROUGH;
  case 'h':
  case 'H':
  case Ctrl_H:
    cap->cmdchar = cap->nchar + ('v' - 'h');
    cap->arg = true;
    nv_visual(cap);
    break;

  // "gn", "gN" visually select next/previous search match
  // "gn" selects next match
  // "gN" selects previous match
  case 'N':
  case 'n':
    if (!current_search(cap->count1, cap->nchar == 'n')) {
      clearopbeep(oap);
    }
    break;

  // "gj" and "gk" two new funny movement keys -- up and down
  // movement based on *screen* line rather than *file* line.
  case 'j':
  case K_DOWN:
    // with 'nowrap' it works just like the normal "j" command.
    if (!curwin->w_p_wrap) {
      oap->motion_type = kMTLineWise;
      i = cursor_down(cap->count1, oap->op_type == OP_NOP);
    } else {
      i = nv_screengo(oap, FORWARD, cap->count1);
    }
    if (!i) {
      clearopbeep(oap);
    }
    break;

  case 'k':
  case K_UP:
    // with 'nowrap' it works just like the normal "k" command.
    if (!curwin->w_p_wrap) {
      oap->motion_type = kMTLineWise;
      i = cursor_up(cap->count1, oap->op_type == OP_NOP);
    } else {
      i = nv_screengo(oap, BACKWARD, cap->count1);
    }
    if (!i) {
      clearopbeep(oap);
    }
    break;

  // "gJ": join two lines without inserting a space.
  case 'J':
    nv_join(cap);
    break;

  // "g0", "g^" : Like "0" and "^" but for screen lines.
  // "gm": middle of "g0" and "g$".
  case '^':
  case '0':
  case 'm':
  case K_HOME:
  case K_KHOME:
    nv_g_home_m_cmd(cap);
    break;

  case 'M':
    oap->motion_type = kMTCharWise;
    oap->inclusive = false;
    i = linetabsize(curwin, curwin->w_cursor.lnum);
    if (cap->count0 > 0 && cap->count0 <= 100) {
      coladvance(curwin, (colnr_T)(i * cap->count0 / 100));
    } else {
      coladvance(curwin, (colnr_T)(i / 2));
    }
    curwin->w_set_curswant = true;
    break;

  // "g_": to the last non-blank character in the line or <count> lines downward.
  case '_':
    nv_g_underscore_cmd(cap);
    break;

  // "g$" : Like "$" but for screen lines.
  case '$':
  case K_END:
  case K_KEND:
    nv_g_dollar_cmd(cap);
    break;

  // "g*" and "g#", like "*" and "#" but without using "\<" and "\>"
  case '*':
  case '#':
#if POUND != '#'
  case POUND:           // pound sign (sometimes equal to '#')
#endif
  case Ctrl_RSB:                // :tag or :tselect for current identifier
  case ']':                     // :tselect for current identifier
    nv_ident(cap);
    break;

  // ge and gE: go back to end of word
  case 'e':
  case 'E':
    oap->motion_type = kMTCharWise;
    curwin->w_set_curswant = true;
    oap->inclusive = true;
    if (bckend_word(cap->count1, cap->nchar == 'E', false) == false) {
      clearopbeep(oap);
    }
    break;

  // "g CTRL-G": display info about cursor position
  case Ctrl_G:
    cursor_pos_info(NULL);
    break;

  // "gi": start Insert at the last position.
  case 'i':
    nv_gi_cmd(cap);
    break;

  // "gI": Start insert in column 1.
  case 'I':
    beginline(0);
    if (!checkclearopq(oap)) {
      invoke_edit(cap, false, 'g', false);
    }
    break;

  // "gf": goto file, edit file under cursor
  // "]f" and "[f": can also be used.
  case 'f':
  case 'F':
    nv_gotofile(cap);
    break;

  // "g'm" and "g`m": jump to mark without setting pcmark
  case '\'':
    cap->arg = true;
    FALLTHROUGH;
  case '`':
    nv_gomark(cap);
    break;

  // "gs": Goto sleep.
  case 's':
    do_sleep(cap->count1 * 1000);
    break;

  // "ga": Display the ascii value of the character under the
  // cursor.    It is displayed in decimal, hex, and octal. -- webb
  case 'a':
    do_ascii(NULL);
    break;

  // "g8": Display the bytes used for the UTF-8 character under the
  // cursor.    It is displayed in hex.
  // "8g8" finds illegal byte sequence.
  case '8':
    if (cap->count0 == 8) {
      utf_find_illegal();
    } else {
      show_utf8();
    }
    break;
  // "g<": show scrollback text
  case '<':
    show_sb_text();
    break;

  // "gg": Goto the first line in file.  With a count it goes to
  // that line number like for "G". -- webb
  case 'g':
    cap->arg = false;
    nv_goto(cap);
    break;

  //  Two-character operators:
  //  "gq"       Format text
  //  "gw"       Format text and keep cursor position
  //  "g~"       Toggle the case of the text.
  //  "gu"       Change text to lower case.
  //  "gU"       Change text to upper case.
  //  "g?"       rot13 encoding
  //  "g@"       call 'operatorfunc'
  case 'q':
  case 'w':
    oap->cursor_start = curwin->w_cursor;
    FALLTHROUGH;
  case '~':
  case 'u':
  case 'U':
  case '?':
  case '@':
    nv_operator(cap);
    break;

  // "gd": Find first occurrence of pattern under the cursor in the current function
  // "gD": idem, but in the current file.
  case 'd':
  case 'D':
    nv_gd(oap, cap->nchar, cap->count0);
    break;

  // g<*Mouse> : <C-*mouse>
  case K_MIDDLEMOUSE:
  case K_MIDDLEDRAG:
  case K_MIDDLERELEASE:
  case K_LEFTMOUSE:
  case K_LEFTDRAG:
  case K_LEFTRELEASE:
  case K_MOUSEMOVE:
  case K_RIGHTMOUSE:
  case K_RIGHTDRAG:
  case K_RIGHTRELEASE:
  case K_X1MOUSE:
  case K_X1DRAG:
  case K_X1RELEASE:
  case K_X2MOUSE:
  case K_X2DRAG:
  case K_X2RELEASE:
    mod_mask = MOD_MASK_CTRL;
    do_mouse(oap, cap->nchar, BACKWARD, cap->count1, 0);
    break;

  case K_IGNORE:
    break;

  // "gP" and "gp": same as "P" and "p" but leave cursor just after new text
  case 'p':
  case 'P':
    nv_put(cap);
    break;

  // "go": goto byte count from start of buffer
  case 'o':
    goto_byte(cap->count0);
    break;

  // "gQ": improved Ex mode
  case 'Q':
    if (!check_text_locked(cap->oap) && !checkclearopq(oap)) {
      do_exmode();
    }
    break;

  case ',':
    nv_pcmark(cap);
    break;

  case ';':
    cap->count1 = -cap->count1;
    nv_pcmark(cap);
    break;

  case 't':
    if (!checkclearop(oap)) {
      goto_tabpage(cap->count0);
    }
    break;
  case 'T':
    if (!checkclearop(oap)) {
      goto_tabpage(-cap->count1);
    }
    break;

  case TAB:
    if (!checkclearop(oap) && !goto_tabpage_lastused()) {
      clearopbeep(oap);
    }
    break;

  case '+':
  case '-':   // "g+" and "g-": undo or redo along the timeline
    if (!checkclearopq(oap)) {
      undo_time(cap->nchar == '-' ? -cap->count1 : cap->count1,
                false, false, false);
    }
    break;

  default:
    clearopbeep(oap);
    break;
  }
}

/// Handle "o" and "O" commands.
static void n_opencmd(cmdarg_T *cap)
{
  if (checkclearopq(cap->oap)) {
    return;
  }

  if (cap->cmdchar == 'O') {
    // Open above the first line of a folded sequence of lines
    hasFolding(curwin, curwin->w_cursor.lnum,
               &curwin->w_cursor.lnum, NULL);
  } else {
    // Open below the last line of a folded sequence of lines
    hasFolding(curwin, curwin->w_cursor.lnum,
               NULL, &curwin->w_cursor.lnum);
  }
  // trigger TextChangedI for the 'o/O' command
  curbuf->b_last_changedtick_i = buf_get_changedtick(curbuf);
  if (u_save(curwin->w_cursor.lnum - (cap->cmdchar == 'O' ? 1 : 0),
             curwin->w_cursor.lnum + (cap->cmdchar == 'o' ? 1 : 0))
      && open_line(cap->cmdchar == 'O' ? BACKWARD : FORWARD,
                   has_format_option(FO_OPEN_COMS) ? OPENLINE_DO_COM : 0,
                   0, NULL)) {
    if (win_cursorline_standout(curwin)) {
      // force redraw of cursorline
      curwin->w_valid &= ~VALID_CROW;
    }
    invoke_edit(cap, false, cap->cmdchar, true);
  }
}

/// "." command: redo last change.
static void nv_dot(cmdarg_T *cap)
{
  if (checkclearopq(cap->oap)) {
    return;
  }

  // If "restart_edit" is true, the last but one command is repeated
  // instead of the last command (inserting text). This is used for
  // CTRL-O <.> in insert mode.
  if (start_redo(cap->count0, restart_edit != 0 && !arrow_used) == false) {
    clearopbeep(cap->oap);
  }
}

/// CTRL-R: undo undo or specify register in select mode
static void nv_redo_or_register(cmdarg_T *cap)
{
  if (VIsual_select && VIsual_active) {
    // Get register name
    no_mapping++;
    int reg = plain_vgetc();
    LANGMAP_ADJUST(reg, true);
    no_mapping--;

    if (reg == '"') {
      // the unnamed register is 0
      reg = 0;
    }

    VIsual_select_reg = valid_yank_reg(reg, true) ? reg : 0;
    return;
  }

  if (checkclearopq(cap->oap)) {
    return;
  }

  u_redo(cap->count1);
  curwin->w_set_curswant = true;
}

/// Handle "U" command.
static void nv_Undo(cmdarg_T *cap)
{
  // In Visual mode and typing "gUU" triggers an operator
  if (cap->oap->op_type == OP_UPPER || VIsual_active) {
    // translate "gUU" to "gUgU"
    cap->cmdchar = 'g';
    cap->nchar = 'U';
    nv_operator(cap);
    return;
  }

  if (checkclearopq(cap->oap)) {
    return;
  }

  u_undoline();
  curwin->w_set_curswant = true;
}

/// '~' command: If tilde is not an operator and Visual is off: swap case of a
/// single character.
static void nv_tilde(cmdarg_T *cap)
{
  if (!p_to && !VIsual_active && cap->oap->op_type != OP_TILDE) {
    if (bt_prompt(curbuf) && !prompt_curpos_editable()) {
      clearopbeep(cap->oap);
      return;
    }
    n_swapchar(cap);
  } else {
    nv_operator(cap);
  }
}

/// Handle an operator command.
/// The actual work is done by do_pending_operator().
static void nv_operator(cmdarg_T *cap)
{
  int op_type = get_op_type(cap->cmdchar, cap->nchar);

  if (bt_prompt(curbuf) && op_is_change(op_type)
      && !prompt_curpos_editable()) {
    clearopbeep(cap->oap);
    return;
  }

  if (op_type == cap->oap->op_type) {       // double operator works on lines
    nv_lineop(cap);
  } else if (!checkclearop(cap->oap)) {
    cap->oap->start = curwin->w_cursor;
    cap->oap->op_type = op_type;
    set_op_var(op_type);
  }
}

/// Set v:operator to the characters for "optype".
static void set_op_var(int optype)
{
  if (optype == OP_NOP) {
    set_vim_var_string(VV_OP, NULL, 0);
  } else {
    char opchars[3];
    int opchar0 = get_op_char(optype);
    assert(opchar0 >= 0 && opchar0 <= UCHAR_MAX);
    opchars[0] = (char)opchar0;

    int opchar1 = get_extra_op_char(optype);
    assert(opchar1 >= 0 && opchar1 <= UCHAR_MAX);
    opchars[1] = (char)opchar1;

    opchars[2] = NUL;
    set_vim_var_string(VV_OP, opchars, -1);
  }
}

/// Handle linewise operator "dd", "yy", etc.
///
/// "_" is is a strange motion command that helps make operators more logical.
/// It is actually implemented, but not documented in the real Vi.  This motion
/// command actually refers to "the current line".  Commands like "dd" and "yy"
/// are really an alternate form of "d_" and "y_".  It does accept a count, so
/// "d3_" works to delete 3 lines.
static void nv_lineop(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTLineWise;
  if (cursor_down(cap->count1 - 1, cap->oap->op_type == OP_NOP) == false) {
    clearopbeep(cap->oap);
  } else if ((cap->oap->op_type == OP_DELETE
              // only with linewise motions
              && cap->oap->motion_force != 'v'
              && cap->oap->motion_force != Ctrl_V)
             || cap->oap->op_type == OP_LSHIFT
             || cap->oap->op_type == OP_RSHIFT) {
    beginline(BL_SOL | BL_FIX);
  } else if (cap->oap->op_type != OP_YANK) {  // 'Y' does not move cursor
    beginline(BL_WHITE | BL_FIX);
  }
}

/// <Home> command.
static void nv_home(cmdarg_T *cap)
{
  // CTRL-HOME is like "gg"
  if (mod_mask & MOD_MASK_CTRL) {
    nv_goto(cap);
  } else {
    cap->count0 = 1;
    nv_pipe(cap);
  }
  ins_at_eol = false;       // Don't move cursor past eol (only necessary in a
                            // one-character line).
}

/// "|" command.
static void nv_pipe(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  beginline(0);
  if (cap->count0 > 0) {
    coladvance(curwin, (colnr_T)(cap->count0 - 1));
    curwin->w_curswant = (colnr_T)(cap->count0 - 1);
  } else {
    curwin->w_curswant = 0;
  }
  // keep curswant at the column where we wanted to go, not where
  // we ended; differs if line is too short
  curwin->w_set_curswant = false;
}

/// Handle back-word command "b" and "B".
/// cap->arg is 1 for "B"
static void nv_bck_word(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  curwin->w_set_curswant = true;
  if (bck_word(cap->count1, cap->arg, false) == false) {
    clearopbeep(cap->oap);
  } else if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
}

/// Handle word motion commands "e", "E", "w" and "W".
/// cap->arg is true for "E" and "W".
static void nv_wordcmd(cmdarg_T *cap)
{
  int n;
  bool word_end;
  bool flag = false;
  pos_T startpos = curwin->w_cursor;

  // Set inclusive for the "E" and "e" command.
  if (cap->cmdchar == 'e' || cap->cmdchar == 'E') {
    word_end = true;
  } else {
    word_end = false;
  }
  cap->oap->inclusive = word_end;

  // "cw" and "cW" are a special case.
  if (!word_end && cap->oap->op_type == OP_CHANGE) {
    n = gchar_cursor();
    if (n != NUL && !ascii_iswhite(n)) {
      // This is a little strange.  To match what the real Vi does, we
      // effectively map "cw" to "ce", and "cW" to "cE", provided that we are
      // not on a space or a TAB.  This seems impolite at first, but it's
      // really more what we mean when we say "cw".
      //
      // Another strangeness: When standing on the end of a word "ce" will
      // change until the end of the next word, but "cw" will change only one
      // character!  This is done by setting "flag".
      if (vim_strchr(p_cpo, CPO_CHANGEW) != NULL) {
        cap->oap->inclusive = true;
        word_end = true;
      }
      flag = true;
    }
  }

  cap->oap->motion_type = kMTCharWise;
  curwin->w_set_curswant = true;
  if (word_end) {
    n = end_word(cap->count1, cap->arg, flag, false);
  } else {
    n = fwd_word(cap->count1, cap->arg, cap->oap->op_type != OP_NOP);
  }

  // Don't leave the cursor on the NUL past the end of line. Unless we
  // didn't move it forward.
  if (lt(startpos, curwin->w_cursor)) {
    adjust_cursor(cap->oap);
  }

  if (n == false && cap->oap->op_type == OP_NOP) {
    clearopbeep(cap->oap);
  } else {
    adjust_for_sel(cap);
    if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP) {
      foldOpenCursor();
    }
  }
}

/// Used after a movement command: If the cursor ends up on the NUL after the
/// end of the line, may move it back to the last character and make the motion
/// inclusive.
static void adjust_cursor(oparg_T *oap)
{
  // The cursor cannot remain on the NUL when:
  // - the column is > 0
  // - not in Visual mode or 'selection' is "o"
  // - 'virtualedit' is not "all" and not "onemore".
  if (curwin->w_cursor.col > 0 && gchar_cursor() == NUL
      && (!VIsual_active || *p_sel == 'o')
      && !virtual_active(curwin)
      && (get_ve_flags(curwin) & VE_ONEMORE) == 0) {
    curwin->w_cursor.col--;
    // prevent cursor from moving on the trail byte
    mb_adjust_cursor();
    oap->inclusive = true;
  }
}

/// "0" and "^" commands.
/// cap->arg is the argument for beginline().
static void nv_beginline(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  beginline(cap->arg);
  if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
  ins_at_eol = false;       // Don't move cursor past eol (only necessary in a
                            // one-character line).
}

/// In exclusive Visual mode, may include the last character.
static void adjust_for_sel(cmdarg_T *cap)
{
  if (VIsual_active && cap->oap->inclusive && *p_sel == 'e'
      && gchar_cursor() != NUL && lt(VIsual, curwin->w_cursor)) {
    inc_cursor();
    cap->oap->inclusive = false;
  }
}

/// Exclude last character at end of Visual area for 'selection' == "exclusive".
/// Should check VIsual_mode before calling this.
///
/// @return  true when backed up to the previous line.
bool unadjust_for_sel(void)
{
  if (*p_sel == 'e' && !equalpos(VIsual, curwin->w_cursor)) {
    pos_T *pp;
    if (lt(VIsual, curwin->w_cursor)) {
      pp = &curwin->w_cursor;
    } else {
      pp = &VIsual;
    }
    if (pp->coladd > 0) {
      pp->coladd--;
    } else if (pp->col > 0) {
      pp->col--;
      mark_mb_adjustpos(curbuf, pp);
    } else if (pp->lnum > 1) {
      pp->lnum--;
      pp->col = ml_get_len(pp->lnum);
      return true;
    }
  }
  return false;
}

/// SELECT key in Normal or Visual mode: end of Select mode mapping.
static void nv_select(cmdarg_T *cap)
{
  if (VIsual_active) {
    VIsual_select = true;
    VIsual_select_reg = 0;
  } else if (VIsual_reselect) {
    cap->nchar = 'v';               // fake "gv" command
    cap->arg = true;
    nv_g_cmd(cap);
  }
}

/// "G", "gg", CTRL-END, CTRL-HOME.
/// cap->arg is true for "G".
static void nv_goto(cmdarg_T *cap)
{
  linenr_T lnum;

  if (cap->arg) {
    lnum = curbuf->b_ml.ml_line_count;
  } else {
    lnum = 1;
  }
  cap->oap->motion_type = kMTLineWise;
  setpcmark();

  // When a count is given, use it instead of the default lnum
  if (cap->count0 != 0) {
    lnum = cap->count0;
  }
  if (lnum < 1) {
    lnum = 1;
  } else if (lnum > curbuf->b_ml.ml_line_count) {
    lnum = curbuf->b_ml.ml_line_count;
  }
  curwin->w_cursor.lnum = lnum;
  beginline(BL_SOL | BL_FIX);
  if ((fdo_flags & FDO_JUMP) && KeyTyped && cap->oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
}

/// CTRL-\ in Normal mode.
static void nv_normal(cmdarg_T *cap)
{
  if (cap->nchar == Ctrl_N || cap->nchar == Ctrl_G) {
    clearop(cap->oap);
    if (restart_edit != 0 && mode_displayed) {
      clear_cmdline = true;                     // unshow mode later
    }
    restart_edit = 0;
    if (cmdwin_type != 0) {
      cmdwin_result = Ctrl_C;
    }
    if (VIsual_active) {
      end_visual_mode();                // stop Visual
      redraw_curbuf_later(UPD_INVERTED);
    }
  } else {
    clearopbeep(cap->oap);
  }
}

/// ESC in Normal mode: beep, but don't flush buffers.
/// Don't even beep if we are canceling a command.
static void nv_esc(cmdarg_T *cap)
{
  bool no_reason = (cap->oap->op_type == OP_NOP
                    && cap->opcount == 0
                    && cap->count0 == 0
                    && cap->oap->regname == 0);

  if (cap->arg) {               // true for CTRL-C
    if (restart_edit == 0 && cmdwin_type == 0 && !VIsual_active && no_reason) {
      if (anyBufIsChanged()) {
        msg(_("Type  :qa!  and press <Enter> to abandon all changes"
              " and exit Nvim"), 0);
      } else {
        msg(_("Type  :qa  and press <Enter> to exit Nvim"), 0);
      }
    }

    if (restart_edit != 0) {
      redraw_mode = true;  // remove "-- (insert) --"
    }

    restart_edit = 0;

    if (cmdwin_type != 0) {
      cmdwin_result = K_IGNORE;
      got_int = false;          // don't stop executing autocommands et al.
      return;
    }
  } else if (cmdwin_type != 0 && ex_normal_busy && typebuf_was_empty) {
    // When :normal runs out of characters while in the command line window
    // vgetorpeek() will repeatedly return ESC.  Exit the cmdline window to
    // break the loop.
    cmdwin_result = K_IGNORE;
    return;
  }

  if (VIsual_active) {
    end_visual_mode();          // stop Visual
    check_cursor_col(curwin);         // make sure cursor is not beyond EOL
    curwin->w_set_curswant = true;
    redraw_curbuf_later(UPD_INVERTED);
  } else if (no_reason) {
    vim_beep(BO_ESC);
  }
  clearop(cap->oap);
}

/// Move the cursor for the "A" command.
void set_cursor_for_append_to_line(void)
{
  curwin->w_set_curswant = true;
  if (get_ve_flags(curwin) == VE_ALL) {
    const int save_State = State;
    // Pretend Insert mode here to allow the cursor on the
    // character past the end of the line
    State = MODE_INSERT;
    coladvance(curwin, MAXCOL);
    State = save_State;
  } else {
    curwin->w_cursor.col += (colnr_T)strlen(get_cursor_pos_ptr());
  }
}

/// Handle "A", "a", "I", "i" and <Insert> commands.
static void nv_edit(cmdarg_T *cap)
{
  // <Insert> is equal to "i"
  if (cap->cmdchar == K_INS || cap->cmdchar == K_KINS) {
    cap->cmdchar = 'i';
  }

  // in Visual mode "A" and "I" are an operator
  if (VIsual_active && (cap->cmdchar == 'A' || cap->cmdchar == 'I')) {
    v_visop(cap);
    // in Visual mode and after an operator "a" and "i" are for text objects
  } else if ((cap->cmdchar == 'a' || cap->cmdchar == 'i')
             && (cap->oap->op_type != OP_NOP || VIsual_active)) {
    nv_object(cap);
  } else if (!curbuf->b_p_ma && !curbuf->terminal) {
    emsg(_(e_modifiable));
    clearop(cap->oap);
  } else if (!checkclearopq(cap->oap)) {
    switch (cap->cmdchar) {
    case 'A':           // "A"ppend after the line
      set_cursor_for_append_to_line();
      break;

    case 'I':           // "I"nsert before the first non-blank
      beginline(BL_WHITE);
      break;

    case 'a':           // "a"ppend is like "i"nsert on the next character.
      // increment coladd when in virtual space, increment the
      // column otherwise, also to append after an unprintable char
      if (virtual_active(curwin)
          && (curwin->w_cursor.coladd > 0
              || *get_cursor_pos_ptr() == NUL
              || *get_cursor_pos_ptr() == TAB)) {
        curwin->w_cursor.coladd++;
      } else if (*get_cursor_pos_ptr() != NUL) {
        inc_cursor();
      }
      break;
    }

    if (curwin->w_cursor.coladd && cap->cmdchar != 'A') {
      int save_State = State;

      // Pretend Insert mode here to allow the cursor on the
      // character past the end of the line
      State = MODE_INSERT;
      coladvance(curwin, getviscol());
      State = save_State;
    }

    invoke_edit(cap, false, cap->cmdchar, false);
  }
}

/// Invoke edit() and take care of "restart_edit" and the return value.
///
/// @param repl  "r" or "gr" command
static void invoke_edit(cmdarg_T *cap, int repl, int cmd, int startln)
{
  int restart_edit_save = 0;

  // Complicated: When the user types "a<C-O>a" we don't want to do Insert
  // mode recursively.  But when doing "a<C-O>." or "a<C-O>rx" we do allow
  // it.
  if (repl || !stuff_empty()) {
    restart_edit_save = restart_edit;
  } else {
    restart_edit_save = 0;
  }

  // Always reset "restart_edit", this is not a restarted edit.
  restart_edit = 0;

  // Reset Changedtick_i, so that TextChangedI will only be triggered for stuff
  // from insert mode, for 'o/O' this has already been done in n_opencmd
  if (cap->cmdchar != 'O' && cap->cmdchar != 'o') {
    curbuf->b_last_changedtick_i = buf_get_changedtick(curbuf);
  }
  if (edit(cmd, startln, cap->count1)) {
    cap->retval |= CA_COMMAND_BUSY;
  }

  if (restart_edit == 0) {
    restart_edit = restart_edit_save;
  }
}

/// "a" or "i" while an operator is pending or in Visual mode: object motion.
static void nv_object(cmdarg_T *cap)
{
  bool flag;
  bool include;

  if (cap->cmdchar == 'i') {
    include = false;        // "ix" = inner object: exclude white space
  } else {
    include = true;         // "ax" = an object: include white space
  }
  // Make sure (), [], {} and <> are in 'matchpairs'
  char *mps_save = curbuf->b_p_mps;
  curbuf->b_p_mps = "(:),{:},[:],<:>";

  switch (cap->nchar) {
  case 'w':       // "aw" = a word
    flag = current_word(cap->oap, cap->count1, include, false);
    break;
  case 'W':       // "aW" = a WORD
    flag = current_word(cap->oap, cap->count1, include, true);
    break;
  case 'b':       // "ab" = a braces block
  case '(':
  case ')':
    flag = current_block(cap->oap, cap->count1, include, '(', ')');
    break;
  case 'B':       // "aB" = a Brackets block
  case '{':
  case '}':
    flag = current_block(cap->oap, cap->count1, include, '{', '}');
    break;
  case '[':       // "a[" = a [] block
  case ']':
    flag = current_block(cap->oap, cap->count1, include, '[', ']');
    break;
  case '<':       // "a<" = a <> block
  case '>':
    flag = current_block(cap->oap, cap->count1, include, '<', '>');
    break;
  case 't':       // "at" = a tag block (xml and html)
    // Do not adjust oap->end in do_pending_operator()
    // otherwise there are different results for 'dit'
    // (note leading whitespace in last line):
    // 1) <b>      2) <b>
    //    foobar      foobar
    //    </b>            </b>
    cap->retval |= CA_NO_ADJ_OP_END;
    flag = current_tagblock(cap->oap, cap->count1, include);
    break;
  case 'p':       // "ap" = a paragraph
    flag = current_par(cap->oap, cap->count1, include, 'p');
    break;
  case 's':       // "as" = a sentence
    flag = current_sent(cap->oap, cap->count1, include);
    break;
  case '"':       // "a"" = a double quoted string
  case '\'':       // "a'" = a single quoted string
  case '`':       // "a`" = a backtick quoted string
    flag = current_quote(cap->oap, cap->count1, include,
                         cap->nchar);
    break;
  default:
    flag = false;
    break;
  }

  curbuf->b_p_mps = mps_save;
  if (!flag) {
    clearopbeep(cap->oap);
  }
  adjust_cursor_col();
  curwin->w_set_curswant = true;
}

/// "q" command: Start/stop recording.
/// "q:", "q/", "q?": edit command-line in command-line window.
static void nv_record(cmdarg_T *cap)
{
  if (cap->oap->op_type == OP_FORMAT) {
    // "gqq" is the same as "gqgq": format line
    cap->cmdchar = 'g';
    cap->nchar = 'q';
    nv_operator(cap);
    return;
  }

  if (checkclearop(cap->oap)) {
    return;
  }

  if (cap->nchar == ':' || cap->nchar == '/' || cap->nchar == '?') {
    if (cmdwin_type != 0) {
      emsg(_(e_cmdline_window_already_open));
      return;
    }
    stuffcharReadbuff(cap->nchar);
    stuffcharReadbuff(K_CMDWIN);
  } else {
    // (stop) recording into a named register, unless executing a
    // register.
    if (reg_executing == 0 && do_record(cap->nchar) == FAIL) {
      clearopbeep(cap->oap);
    }
  }
}

/// Handle the "@r" command.
static void nv_at(cmdarg_T *cap)
{
  if (checkclearop(cap->oap)) {
    return;
  }
  if (cap->nchar == '=') {
    if (get_expr_register() == NUL) {
      return;
    }
  }
  while (cap->count1-- && !got_int) {
    if (do_execreg(cap->nchar, false, false, false) == false) {
      clearopbeep(cap->oap);
      break;
    }
    line_breakcheck();
  }
}

/// Handle the CTRL-U and CTRL-D commands.
static void nv_halfpage(cmdarg_T *cap)
{
  if (!checkclearop(cap->oap)) {
    pagescroll(cap->cmdchar == Ctrl_D ? FORWARD : BACKWARD, cap->count0, true);
  }
}

/// Handle "J" or "gJ" command.
static void nv_join(cmdarg_T *cap)
{
  if (VIsual_active) {  // join the visual lines
    nv_operator(cap);
    return;
  }

  if (checkclearop(cap->oap)) {
    return;
  }

  if (cap->count0 <= 1) {
    cap->count0 = 2;  // default for join is two lines!
  }
  if (curwin->w_cursor.lnum + cap->count0 - 1 >
      curbuf->b_ml.ml_line_count) {
    // can't join when on the last line
    if (cap->count0 <= 2) {
      clearopbeep(cap->oap);
      return;
    }
    cap->count0 = curbuf->b_ml.ml_line_count - curwin->w_cursor.lnum + 1;
  }

  prep_redo(cap->oap->regname, cap->count0,
            NUL, cap->cmdchar, NUL, NUL, cap->nchar);
  do_join((size_t)cap->count0, cap->nchar == NUL, true, true, true);
}

/// "P", "gP", "p" and "gp" commands.
static void nv_put(cmdarg_T *cap)
{
  nv_put_opt(cap, false);
}

/// "P", "gP", "p" and "gp" commands.
///
/// @param fix_indent  true for "[p", "[P", "]p" and "]P".
static void nv_put_opt(cmdarg_T *cap, bool fix_indent)
{
  yankreg_T *savereg = NULL;
  bool empty = false;
  bool was_visual = false;
  int dir;
  int flags = 0;
  const int save_fen = curwin->w_p_fen;

  if (cap->oap->op_type != OP_NOP) {
    // "dp" is ":diffput"
    if (cap->oap->op_type == OP_DELETE && cap->cmdchar == 'p') {
      clearop(cap->oap);
      assert(cap->opcount >= 0);
      nv_diffgetput(true, (size_t)cap->opcount);
    } else {
      clearopbeep(cap->oap);
    }
    return;
  }

  if (bt_prompt(curbuf) && !prompt_curpos_editable()) {
    clearopbeep(cap->oap);
    return;
  }

  if (fix_indent) {
    dir = (cap->cmdchar == ']' && cap->nchar == 'p')
          ? FORWARD : BACKWARD;
    flags |= PUT_FIXINDENT;
  } else {
    dir = (cap->cmdchar == 'P'
           || ((cap->cmdchar == 'g' || cap->cmdchar == 'z')
               && cap->nchar == 'P')) ? BACKWARD : FORWARD;
  }
  prep_redo_cmd(cap);
  if (cap->cmdchar == 'g') {
    flags |= PUT_CURSEND;
  } else if (cap->cmdchar == 'z') {
    flags |= PUT_BLOCK_INNER;
  }

  if (VIsual_active) {
    // Putting in Visual mode: The put text replaces the selected
    // text.  First delete the selected text, then put the new text.
    // Need to save and restore the registers that the delete
    // overwrites if the old contents is being put.
    was_visual = true;
    int regname = cap->oap->regname;
    bool keep_registers = cap->cmdchar == 'P';
    // '+' and '*' could be the same selection
    bool clipoverwrite = (regname == '+' || regname == '*') && (cb_flags & CB_UNNAMEDMASK);
    if (regname == 0 || regname == '"' || clipoverwrite
        || ascii_isdigit(regname) || regname == '-') {
      // The delete might overwrite the register we want to put, save it first
      savereg = copy_register(regname);
    }

    // Temporarily disable folding, as deleting a fold marker may cause
    // the cursor to be included in a fold.
    curwin->w_p_fen = false;

    // To place the cursor correctly after a blockwise put, and to leave the
    // text in the correct position when putting over a selection with
    // 'virtualedit' and past the end of the line, we use the 'c' operator in
    // do_put(), which requires the visual selection to still be active.
    if (!VIsual_active || VIsual_mode == 'V' || regname != '.') {
      // Now delete the selected text. Avoid messages here.
      cap->cmdchar = 'd';
      cap->nchar = NUL;
      cap->oap->regname = keep_registers ? '_' : NUL;
      msg_silent++;
      nv_operator(cap);
      do_pending_operator(cap, 0, false);
      empty = (curbuf->b_ml.ml_flags & ML_EMPTY);
      msg_silent--;

      // delete PUT_LINE_BACKWARD;
      cap->oap->regname = regname;
    }

    // When deleted a linewise Visual area, put the register as
    // lines to avoid it joined with the next line.  When deletion was
    // charwise, split a line when putting lines.
    if (VIsual_mode == 'V') {
      flags |= PUT_LINE;
    } else if (VIsual_mode == 'v') {
      flags |= PUT_LINE_SPLIT;
    }
    if (VIsual_mode == Ctrl_V && dir == FORWARD) {
      flags |= PUT_LINE_FORWARD;
    }
    dir = BACKWARD;
    if ((VIsual_mode != 'V'
         && curwin->w_cursor.col < curbuf->b_op_start.col)
        || (VIsual_mode == 'V'
            && curwin->w_cursor.lnum < curbuf->b_op_start.lnum)) {
      // cursor is at the end of the line or end of file, put
      // forward.
      dir = FORWARD;
    }
    // May have been reset in do_put().
    VIsual_active = true;
  }
  do_put(cap->oap->regname, savereg, dir, cap->count1, flags);

  // If a register was saved, free it
  if (savereg != NULL) {
    free_register(savereg);
    xfree(savereg);
  }

  if (was_visual) {
    if (save_fen) {
      curwin->w_p_fen = true;
    }
    // What to reselect with "gv"?  Selecting the just put text seems to
    // be the most useful, since the original text was removed.
    curbuf->b_visual.vi_start = curbuf->b_op_start;
    curbuf->b_visual.vi_end = curbuf->b_op_end;
    // need to adjust cursor position
    if (*p_sel == 'e') {
      inc(&curbuf->b_visual.vi_end);
    }
  }

  // When all lines were selected and deleted do_put() leaves an empty
  // line that needs to be deleted now.
  if (empty && *ml_get(curbuf->b_ml.ml_line_count) == NUL) {
    ml_delete(curbuf->b_ml.ml_line_count, true);
    deleted_lines(curbuf->b_ml.ml_line_count + 1, 1);

    // If the cursor was in that line, move it to the end of the last
    // line.
    if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
      curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      coladvance(curwin, MAXCOL);
    }
  }
  auto_format(false, true);
}

/// "o" and "O" commands.
static void nv_open(cmdarg_T *cap)
{
  // "do" is ":diffget"
  if (cap->oap->op_type == OP_DELETE && cap->cmdchar == 'o') {
    clearop(cap->oap);
    assert(cap->opcount >= 0);
    nv_diffgetput(false, (size_t)cap->opcount);
  } else if (VIsual_active) {
    // switch start and end of visual/
    v_swap_corners(cap->cmdchar);
  } else if (bt_prompt(curbuf)) {
    clearopbeep(cap->oap);
  } else {
    n_opencmd(cap);
  }
}

/// Handle an arbitrary event in normal mode
static void nv_event(cmdarg_T *cap)
{
  // Garbage collection should have been executed before blocking for events in
  // the `os_inchar` in `state_enter`, but we also disable it here in case the
  // `os_inchar` branch was not executed (!multiqueue_empty(loop.events), which
  // could have `may_garbage_collect` set to true in `normal_check`).
  //
  // That is because here we may run code that calls `os_inchar`
  // later(`f_confirm` or `get_keystroke` for example), but in these cases it is
  // not safe to perform garbage collection because there could be unreferenced
  // lists or dicts being used.
  may_garbage_collect = false;
  bool may_restart = (restart_edit != 0 || restart_VIsual_select != 0);
  state_handle_k_event();
  finish_op = false;
  if (may_restart) {
    // Tricky: if restart_edit was set before the handler we are in ctrl-o mode,
    // but if not, the event should be allowed to trigger :startinsert.
    cap->retval |= CA_COMMAND_BUSY;  // don't call edit() or restart Select now
  }
}

void normal_cmd(oparg_T *oap, bool toplevel)
{
  NormalState s;
  normal_state_init(&s);
  s.toplevel = toplevel;
  s.oa = *oap;
  normal_prepare(&s);
  normal_execute(&s.state, safe_vgetc());
  *oap = s.oa;
}
