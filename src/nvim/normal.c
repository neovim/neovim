// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

//
// normal.c:    Contains the main routine for processing characters in command
//              mode.  Communicates closely with the code in ops.c to handle
//              the operators.
//

#include <assert.h>
#include <inttypes.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>

#include "nvim/log.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/normal.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/farsi.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/keymap.h"
#include "nvim/move.h"
#include "nvim/mouse.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/quickfix.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/spellfile.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/tag.h"
#include "nvim/ui.h"
#include "nvim/mouse.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/state.h"
#include "nvim/event/loop.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"

typedef struct normal_state {
  VimState state;
  linenr_T conceal_old_cursor_line;
  linenr_T conceal_new_cursor_line;
  bool command_finished;
  bool ctrl_w;
  bool need_flushbuf;
  bool conceal_update_lines;
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

/*
 * The Visual area is remembered for reselection.
 */
static int resel_VIsual_mode = NUL;             /* 'v', 'V', or Ctrl-V */
static linenr_T resel_VIsual_line_count;        /* number of lines */
static colnr_T resel_VIsual_vcol;               /* nr of cols or end col */
static int VIsual_mode_orig = NUL;              /* saved Visual mode */

static int restart_VIsual_select = 0;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "normal.c.generated.h"
#endif

static inline void normal_state_init(NormalState *s)
{
  memset(s, 0, sizeof(NormalState));
  s->state.check = normal_check;
  s->state.execute = normal_execute;
}

/*
 * nv_*(): functions called to handle Normal and Visual mode commands.
 * n_*(): functions called to handle Normal mode commands.
 * v_*(): functions called to handle Visual mode commands.
 */

static char *e_noident = N_("E349: No identifier under cursor");

/*
 * Function to be called for a Normal or Visual mode command.
 * The argument is a cmdarg_T.
 */
typedef void (*nv_func_T)(cmdarg_T *cap);

/* Values for cmd_flags. */
#define NV_NCH      0x01          /* may need to get a second char */
#define NV_NCH_NOP  (0x02|NV_NCH) /* get second char when no operator pending */
#define NV_NCH_ALW  (0x04|NV_NCH) /* always get a second char */
#define NV_LANG     0x08        /* second char needs language adjustment */

#define NV_SS       0x10        /* may start selection */
#define NV_SSS      0x20        /* may start selection with shift modifier */
#define NV_STS      0x40        /* may stop selection without shift modif. */
#define NV_RL       0x80        /* 'rightleft' modifies command */
#define NV_KEEPREG  0x100       /* don't clear regname */
#define NV_NCW      0x200       /* not allowed in command-line window */

/*
 * Generally speaking, every Normal mode command should either clear any
 * pending operator (with *clearop*()), or set the motion type variable
 * oap->motion_type.
 *
 * When a cursor motion command is made, it is marked as being a character or
 * line oriented motion.  Then, if an operator is in effect, the operation
 * becomes character or line oriented accordingly.
 */

/*
 * This table contains one entry for every Normal or Visual mode command.
 * The order doesn't matter, init_normal_cmds() will create a sorted index.
 * It is faster when all keys from zero to '~' are present.
 */
static const struct nv_cmd {
  int cmd_char;                 /* (first) command character */
  nv_func_T cmd_func;           /* function for this command */
  uint16_t cmd_flags;           /* NV_ flags */
  short cmd_arg;                /* value for ca.arg */
} nv_cmds[] =
{
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
  { Ctrl_M,    nv_down,        0,                      true },
  { Ctrl_N,    nv_down,        NV_STS,                 false },
  { Ctrl_O,    nv_ctrlo,       0,                      0 },
  { Ctrl_P,    nv_up,          NV_STS,                 false },
  { Ctrl_Q,    nv_visual,      0,                      false },
  { Ctrl_R,    nv_redo,        0,                      0 },
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
  { 'Q',       nv_exmode,      NV_NCW,                 0 },
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
  { K_F8,      farsi_f8,       0,                      0 },
  { K_F9,      farsi_f9,       0,                      0 },
  { K_EVENT,   nv_event,       NV_KEEPREG,             0 },
  { K_COMMAND, nv_colon,       0,                      0 },
};

/* Number of commands in nv_cmds[]. */
#define NV_CMDS_SIZE ARRAY_SIZE(nv_cmds)

/* Sorted index of commands in nv_cmds[]. */
static short nv_cmd_idx[NV_CMDS_SIZE];

/* The highest index for which
 * nv_cmds[idx].cmd_char == nv_cmd_idx[nv_cmds[idx].cmd_char] */
static int nv_max_linear;

/*
 * Compare functions for qsort() below, that checks the command character
 * through the index in nv_cmd_idx[].
 */
static int nv_compare(const void *s1, const void *s2)
{
  int c1, c2;

  /* The commands are sorted on absolute value. */
  c1 = nv_cmds[*(const short *)s1].cmd_char;
  c2 = nv_cmds[*(const short *)s2].cmd_char;
  if (c1 < 0)
    c1 = -c1;
  if (c2 < 0)
    c2 = -c2;
  return c1 - c2;
}

/*
 * Initialize the nv_cmd_idx[] table.
 */
void init_normal_cmds(void)
{
  assert(NV_CMDS_SIZE <= SHRT_MAX);

  /* Fill the index table with a one to one relation. */
  for (short int i = 0; i < (short int)NV_CMDS_SIZE; ++i) {
    nv_cmd_idx[i] = i;
  }

  /* Sort the commands by the command character.  */
  qsort(&nv_cmd_idx, NV_CMDS_SIZE, sizeof(short), nv_compare);

  /* Find the first entry that can't be indexed by the command character. */
  short int i;
  for (i = 0; i < (short int)NV_CMDS_SIZE; ++i) {
    if (i != nv_cmds[nv_cmd_idx[i]].cmd_char) {
      break;
    }
  }
  nv_max_linear = i - 1;
}

/*
 * Search for a command in the commands table.
 * Returns -1 for invalid command.
 */
static int find_command(int cmdchar)
{
  int i;
  int idx;
  int top, bot;
  int c;

  /* A multi-byte character is never a command. */
  if (cmdchar >= 0x100)
    return -1;

  /* We use the absolute value of the character.  Special keys have a
   * negative value, but are sorted on their absolute value. */
  if (cmdchar < 0)
    cmdchar = -cmdchar;

  /* If the character is in the first part: The character is the index into
   * nv_cmd_idx[]. */
  assert(nv_max_linear < (int)NV_CMDS_SIZE);
  if (cmdchar <= nv_max_linear)
    return nv_cmd_idx[cmdchar];

  /* Perform a binary search. */
  bot = nv_max_linear + 1;
  top = NV_CMDS_SIZE - 1;
  idx = -1;
  while (bot <= top) {
    i = (top + bot) / 2;
    c = nv_cmds[nv_cmd_idx[i]].cmd_char;
    if (c < 0)
      c = -c;
    if (cmdchar == c) {
      idx = nv_cmd_idx[i];
      break;
    }
    if (cmdchar > c)
      bot = i + 1;
    else
      top = i - 1;
  }
  return idx;
}

// Normal state entry point. This is called on:
//
// - Startup, In this case the function never returns.
// - The command-line window is opened(`q:`). Returns when `cmdwin_result` != 0.
// - The :visual command is called from :global in ex mode, `:global/PAT/visual`
//   for example. Returns when re-entering ex mode(because ex mode recursion is
//   not allowed)
//
// This used to be called main_loop on main.c
void normal_enter(bool cmdwin, bool noexmode)
{
  NormalState state;
  normal_state_init(&state);
  state.cmdwin = cmdwin;
  state.noexmode = noexmode;
  state.toplevel = (!cmdwin || cmdwin_result == 0) && !noexmode;
  state_enter(&state.state);
}

static void normal_prepare(NormalState *s)
{
  memset(&s->ca, 0, sizeof(s->ca));  // also resets ca.retval
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
  State = NORMAL_BUSY;

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
    redraw_curbuf_later(INVERTED);
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
  return
    // without NV_NCH we never need to check for an additional char
    flags & NV_NCH && (
        // NV_NCH_NOP is set and no operator is pending, get a second char
        ((flags & NV_NCH_NOP) == NV_NCH_NOP && !pending_op)
        // NV_NCH_ALW is set, always get a second char
     || (flags & NV_NCH_ALW) == NV_NCH_ALW
        // 'q' without a pending operator, recording or executing a register,
        // needs to be followed by a second char, examples:
        // - qc => record using register c
        // - q: => open command-line window
     || (cmdchar == 'q' && !pending_op && !Recording && !Exec_reg)
        // 'a' or 'i' after an operator is a text object, examples:
        // - ciw => change inside word
        // - da( => delete parenthesis and everything inside.
        // Also, don't do anything when these keys are received in visual mode
        // so just get another char.
        //
        // TODO(tarruda): Visual state needs to be refactored into a
        // separate state that "inherits" from normal state.
     || ((cmdchar == 'a' || cmdchar == 'i') && (pending_op || VIsual_active)));
}

static bool normal_need_redraw_mode_message(NormalState *s)
{
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
      && !did_wait_return
      && s->oa.op_type == OP_NOP);
}

static void normal_redraw_mode_message(NormalState *s)
{
  int save_State = State;

  // Draw the cursor with the right shape here
  if (restart_edit != 0) {
    State = INSERT;
  }

  // If need to redraw, and there is a "keep_msg", redraw before the
  // delay
  if (must_redraw && keep_msg != NULL && !emsg_on_display) {
    char_u      *kmsg;

    kmsg = keep_msg;
    keep_msg = NULL;
    // showmode() will clear keep_msg, but we want to use it anyway
    update_screen(0);
    // now reset it, otherwise it's put in the history again
    keep_msg = kmsg;
    msg_attr((const char *)kmsg, keep_msg_attr);
    xfree(kmsg);
  }
  setcursor();
  ui_flush();
  if (msg_scroll || emsg_on_display) {
    os_delay(1000L, true);            // wait at least one second
  }
  os_delay(3000L, false);             // wait up to three seconds
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
  bool langmap_active = false;  // using :lmap mappings
  int lang;                     // getting a text character

  no_mapping++;
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
    if (repl) {
      State = REPLACE;                // pretend Replace mode
      ui_cursor_shape();              // show different cursor shape
    }
    if (lang && curbuf->b_p_iminsert == B_IMODE_LMAP) {
      // Allow mappings defined with ":lmap".
      no_mapping--;
      if (repl) {
        State = LREPLACE;
      } else {
        State = LANGMAP;
      }
      langmap_active = true;
    }

    *cp = plain_vgetc();

    if (langmap_active) {
      // Undo the decrement done above
      no_mapping++;
    }
    State = NORMAL_BUSY;
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
      // adjust Hebrew mapped char
      if (p_hkmap && lang && KeyTyped) {
        *cp = hkmap(*cp);
      }
      // adjust Farsi mapped char
      if (p_fkmap && lang && KeyTyped) {
        *cp = fkmap(*cp);
      }
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
      long towait = (p_ttm >= 0 ? p_ttm : p_tm);

      // There is a busy wait here when typing "f<C-\>" and then
      // something different from CTRL-N.  Can't be avoided.
      while ((s->c = vpeekc()) <= 0 && towait > 0L) {
        do_sleep(towait > 50L ? 50L : towait);
        towait -= 50L;
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

    // When getting a text character and the next character is a
    // multi-byte character, it could be a composing character.
    // However, don't wait for it to arrive. Also, do enable mapping,
    // because if it's put back with vungetc() it's too late to apply
    // mapping.
    no_mapping--;
    while (enc_utf8 && lang && (s->c = vpeekc()) > 0
           && (s->c >= 0x100 || MB_BYTE2LEN(vpeekc()) > 1)) {
      s->c = plain_vgetc();
      if (!utf_iscomposing(s->c)) {
        vungetc(s->c);                   /* it wasn't, put it back */
        break;
      } else if (s->ca.ncharC1 == 0) {
        s->ca.ncharC1 = s->c;
      } else {
        s->ca.ncharC2 = s->c;
      }
    }
    no_mapping++;
  }
  no_mapping--;
}

static void normal_invert_horizontal(NormalState *s)
{
  switch (s->ca.cmdchar) {
    case 'l':       s->ca.cmdchar = 'h'; break;
    case K_RIGHT:   s->ca.cmdchar = K_LEFT; break;
    case K_S_RIGHT: s->ca.cmdchar = K_S_LEFT; break;
    case K_C_RIGHT: s->ca.cmdchar = K_C_LEFT; break;
    case 'h':       s->ca.cmdchar = 'l'; break;
    case K_LEFT:    s->ca.cmdchar = K_RIGHT; break;
    case K_S_LEFT:  s->ca.cmdchar = K_S_RIGHT; break;
    case K_C_LEFT:  s->ca.cmdchar = K_C_RIGHT; break;
    case '>':       s->ca.cmdchar = '<'; break;
    case '<':       s->ca.cmdchar = '>'; break;
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
  while ((s->c >= '1' && s->c <= '9') || (s->ca.count0 != 0
        && (s->c == K_DEL || s->c == K_KDEL || s->c == '0'))) {
    if (s->c == K_DEL || s->c == K_KDEL) {
      s->ca.count0 /= 10;
      del_from_showcmd(4);            // delete the digit and ~@%
    } else {
      s->ca.count0 = s->ca.count0 * 10 + (s->c - '0');
    }

    if (s->ca.count0 < 0) {
      // got too large!
      s->ca.count0 = 999999999L;
    }

    // Set v:count here, when called from main() and not a stuffed
    // command, so that v:count can be used in an expression mapping
    // right after the count. Do set it for redo.
    if (s->toplevel && readbuf1_empty()) {
      set_vcount_ca(&s->ca, &s->set_prevcount);
    }

    if (s->ctrl_w) {
      no_mapping++;
    }

    ++no_zero_mapping;                // don't map zero here
    s->c = plain_vgetc();
    LANGMAP_ADJUST(s->c, true);
    --no_zero_mapping;
    if (s->ctrl_w) {
      no_mapping--;
    }
    s->need_flushbuf |= add_to_showcmd(s->c);
  }

  // If we got CTRL-W there may be a/another count
  if (s->c == Ctrl_W && !s->ctrl_w && s->oa.op_type == OP_NOP) {
    s->ctrl_w = true;
    s->ca.opcount = s->ca.count0;           // remember first count
    s->ca.count0 = 0;
    no_mapping++;
    s->c = plain_vgetc();                // get next character
    LANGMAP_ADJUST(s->c, true);
    no_mapping--;
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

  // If an operation is pending, handle it...
  do_pending_operator(&s->ca, s->old_col, false);

  // Wait for a moment when a message is displayed that will be overwritten
  // by the mode message.
  // In Visual mode and with "^O" in Insert mode, a short message will be
  // overwritten by the mode message.  Wait a bit, until a key is hit.
  // In Visual mode, it's more important to keep the Visual area updated
  // than keeping a message (e.g. from a /pat search).
  // Only do this if the command was typed, not from a mapping.
  // Don't wait when emsg_silent is non-zero.
  // Also wait a bit after an error message, e.g. for "^O:".
  // Don't redraw the screen, it would remove the message.
  if (normal_need_redraw_mode_message(s)) {
    normal_redraw_mode_message(s);
  }

  // Finish up after executing a Normal mode command.
normal_end:

  msg_nowait = false;

  // Reset finish_op, in case it was set
  s->c = finish_op;
  finish_op = false;
  // Redraw the cursor with another shape, if we were in Operator-pending
  // mode or did a replace command.
  if (s->c || s->ca.cmdchar == 'r') {
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
    validate_cursor();          // may need to update w_leftcol
    do_check_scrollbind(true);
  }

  if (curwin->w_p_crb && s->toplevel) {
    validate_cursor();          // may need to update w_leftcol
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
      showmode();
      restart_VIsual_select = 0;
    }
    if (restart_edit != 0 && !VIsual_active && s->old_mapped_len == 0) {
      (void)edit(restart_edit, false, 1L);
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
  s->ctrl_w = false;                  /* got CTRL-W command */
  s->old_col = curwin->w_curswant;
  s->c = key;

  LANGMAP_ADJUST(s->c, get_real_state() != SELECTMODE);

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
    // Fake a "c"hange command.  When "restart_edit" is set (e.g., because
    // 'insertmode' is set) fake a "d"elete command, Insert mode will
    // restart automatically.
    // Insert the typed character in the typeahead buffer, so that it can
    // be mapped in Insert mode.  Required for ":lmap" to work.
    ins_char_typebuf(s->c);
    if (restart_edit != 0) {
      s->c = 'd';
    } else {
      s->c = 'c';
    }
    msg_nowait = true;          // don't delay going to insert mode
    s->old_mapped_len = 0;      // do go to Insert mode
  }

  s->need_flushbuf = add_to_showcmd(s->c);

  while (normal_get_command_count(s)) continue;

  if (s->c == K_EVENT) {
    // Save the count values so that ca.opcount and ca.count0 are exactly
    // the same when coming back here after handling K_EVENT.
    s->oa.prev_opcount = s->ca.opcount;
    s->oa.prev_count0 = s->ca.count0;
  } else if (s->ca.opcount != 0)  {
    // If we're in the middle of an operator (including after entering a
    // yank buffer with '"') AND we had a count before the operator, then
    // that count overrides the current value of ca.count0.
    // What this means effectively, is that commands like "3dw" get turned
    // into "d3w" which makes things fall into place pretty neatly.
    // If you give a count before AND after the operator, they are
    // multiplied.
    if (s->ca.count0) {
      s->ca.count0 *= s->ca.opcount;
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

  if (text_locked() && (nv_cmds[s->idx].cmd_flags & NV_NCW)) {
    // This command is not allowed while editing a cmdline: beep.
    clearopbeep(&s->oa);
    text_locked_msg();
    s->command_finished = true;
    goto finish;
  }

  if ((nv_cmds[s->idx].cmd_flags & NV_NCW) && curbuf_locked()) {
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

  State = NORMAL;

  if (s->ca.nchar == ESC) {
    clearop(&s->oa);
    if (restart_edit == 0 && goto_im()) {
      restart_edit = 'a';
    }
    s->command_finished = true;
    goto finish;
  }

  if (s->ca.cmdchar != K_IGNORE) {
    msg_didout = false;        // don't scroll screen up for normal command
    msg_col = 0;
  }

  s->old_pos = curwin->w_cursor;           // remember where cursor was

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

    if (need_start_insertmode && goto_im() && !VIsual_active) {
      need_start_insertmode = false;
      stuffReadbuff("i");  // start insert mode next
      // skip the fileinfo message now, because it would be shown
      // after insert mode finishes!
      need_fileinfo = false;
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
      exmode_active = EXMODE_NORMAL;
      State = NORMAL;
    } else if (!global_busy || !exmode_active) {
      if (!quit_more) {
        // flush all buffers
        (void)vgetc();
      }
      got_int = false;
    }
    s->previous_got_int = true;
  } else {
    s->previous_got_int = false;
  }
}

static void normal_check_cursor_moved(NormalState *s)
{
  // Trigger CursorMoved if the cursor moved.
  if (!finish_op && (has_event(EVENT_CURSORMOVED) || curwin->w_p_cole > 0)
      && !equalpos(last_cursormoved, curwin->w_cursor)) {
    if (has_event(EVENT_CURSORMOVED)) {
      apply_autocmds(EVENT_CURSORMOVED, NULL, NULL, false, curbuf);
    }

    if (curwin->w_p_cole > 0) {
      s->conceal_old_cursor_line = last_cursormoved.lnum;
      s->conceal_new_cursor_line = curwin->w_cursor.lnum;
      s->conceal_update_lines = true;
    }

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
  update_topline();
  validate_cursor();

  if (VIsual_active) {
    update_curbuf(INVERTED);  // update inverted part
  } else if (must_redraw) {
    update_screen(0);
  } else if (redraw_cmdline || clear_cmdline) {
    showmode();
  }

  redraw_statuslines();

  if (need_maketitle) {
    maketitle();
  }

  // display message after redraw
  if (keep_msg != NULL) {
    // msg_attr_keep() will set keep_msg to NULL, must free the string here.
    // Don't reset keep_msg, msg_attr_keep() uses it to check for duplicates.
    char *p = (char *)keep_msg;
    msg_attr(p, keep_msg_attr);
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
  showruler(false);

  if (s->conceal_update_lines
      && (s->conceal_old_cursor_line !=
        s->conceal_new_cursor_line
        || conceal_cursor_line(curwin)
        || need_cursor_line_redraw)) {
    if (s->conceal_old_cursor_line !=
        s->conceal_new_cursor_line
        && s->conceal_old_cursor_line <=
        curbuf->b_ml.ml_line_count) {
      update_single_line(curwin, s->conceal_old_cursor_line);
    }

    update_single_line(curwin, s->conceal_new_cursor_line);
    curwin->w_valid &= ~VALID_CROW;
  }

  setcursor();
}

// Function executed before each iteration of normal mode.
// Return:
//   1 if the iteration should continue normally
//   -1 if the iteration should be skipped
//   0 if the main loop must exit
static int normal_check(VimState *state)
{
  NormalState *s = (NormalState *)state;
  normal_check_stuff_buffer(s);
  normal_check_interrupt(s);

  if (!exmode_active) {
    msg_scroll = false;
  }
  quit_more = false;

  // If skip redraw is set (for ":" in wait_return()), don't redraw now.
  // If there is nothing in the stuff_buffer or do_redraw is TRUE,
  // update cursor and redraw.
  if (skip_redraw || exmode_active) {
    skip_redraw = false;
  } else if (do_redraw || stuff_empty()) {
    normal_check_cursor_moved(s);
    normal_check_text_changed(s);

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
      check_scrollbind((linenr_T)0, 0L);
      diff_need_scrollbind = false;
    }

    normal_check_folds(s);
    normal_redraw(s);
    do_redraw = false;

    // Now that we have drawn the first screen all the startup stuff
    // has been done, close any file for startup messages.
    if (time_fd != NULL) {
      TIME_MSG("first screen update");
      TIME_MSG("--- NVIM STARTED ---");
      fclose(time_fd);
      time_fd = NULL;
    }
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
    do_exmode(exmode_active == EXMODE_VIM);
    return -1;
  }

  if (s->cmdwin && cmdwin_result != 0) {
    // command-line window and cmdwin_result is set
    return 0;
  }

  normal_prepare(s);
  return 1;
}

/*
 * Set v:count and v:count1 according to "cap".
 * Set v:prevcount only when "set_prevcount" is true.
 */
static void set_vcount_ca(cmdarg_T *cap, bool *set_prevcount)
{
  long count = cap->count0;

  /* multiply with cap->opcount the same way as above */
  if (cap->opcount != 0)
    count = cap->opcount * (count == 0 ? 1 : count);
  set_vcount(count, count == 0 ? 1 : count, *set_prevcount);
  *set_prevcount = false;    /* only set v:prevcount once */
}

/*
 * Handle an operator after visual mode or when the movement is finished
 */
void do_pending_operator(cmdarg_T *cap, int old_col, bool gui_yank)
{
  oparg_T     *oap = cap->oap;
  pos_T old_cursor;
  bool empty_region_error;
  int restart_edit_save;
  int lbr_saved = curwin->w_p_lbr;


  // The visual area is remembered for redo
  static int redo_VIsual_mode = NUL;        // 'v', 'V', or Ctrl-V
  static linenr_T redo_VIsual_line_count;   // number of lines
  static colnr_T redo_VIsual_vcol;          // number of cols or end column
  static long redo_VIsual_count;            // count for Visual operator
  static int redo_VIsual_arg;               // extra argument
  bool include_line_break = false;

  old_cursor = curwin->w_cursor;

  /*
   * If an operation is pending, handle it...
   */
  if ((finish_op
       || VIsual_active
       ) && oap->op_type != OP_NOP) {
    // Avoid a problem with unwanted linebreaks in block mode
    if (curwin->w_p_lbr) {
      curwin->w_valid &= ~VALID_VIRTCOL;
    }
    curwin->w_p_lbr = false;
    oap->is_VIsual = VIsual_active;
    if (oap->motion_force == 'V') {
      oap->motion_type = kMTLineWise;
    } else if (oap->motion_force == 'v') {
      // If the motion was linewise, "inclusive" will not have been set.
      // Use "exclusive" to be consistent.  Makes "dvj" work nice.
      if (oap->motion_type == kMTLineWise) {
        oap->inclusive = false;
      } else if (oap->motion_type == kMTCharWise) {
        // If the motion already was characterwise, toggle "inclusive"
        oap->inclusive = !oap->inclusive;
      }
      oap->motion_type = kMTCharWise;
    } else if (oap->motion_force == Ctrl_V) {
      // Change line- or characterwise motion into Visual block mode.
      VIsual_active = true;
      VIsual = oap->start;
      VIsual_mode = Ctrl_V;
      VIsual_select = false;
      VIsual_reselect = false;
    }

    /* Only redo yank when 'y' flag is in 'cpoptions'. */
    /* Never redo "zf" (define fold). */
    if ((vim_strchr(p_cpo, CPO_YANK) != NULL || oap->op_type != OP_YANK)
        && ((!VIsual_active || oap->motion_force)
            // Also redo Operator-pending Visual mode mappings.
            || (cap->cmdchar == ':' && oap->op_type != OP_COLON))
        && cap->cmdchar != 'D'
        && oap->op_type != OP_FOLD
        && oap->op_type != OP_FOLDOPEN
        && oap->op_type != OP_FOLDOPENREC
        && oap->op_type != OP_FOLDCLOSE
        && oap->op_type != OP_FOLDCLOSEREC
        && oap->op_type != OP_FOLDDEL
        && oap->op_type != OP_FOLDDELREC
        ) {
      prep_redo(oap->regname, cap->count0,
          get_op_char(oap->op_type), get_extra_op_char(oap->op_type),
          oap->motion_force, cap->cmdchar, cap->nchar);
      if (cap->cmdchar == '/' || cap->cmdchar == '?') {     /* was a search */
        /*
         * If 'cpoptions' does not contain 'r', insert the search
         * pattern to really repeat the same command.
         */
        if (vim_strchr(p_cpo, CPO_REDO) == NULL) {
          AppendToRedobuffLit(cap->searchbuf, -1);
        }
        AppendToRedobuff(NL_STR);
      } else if (cap->cmdchar == ':' || cap->cmdchar == K_COMMAND) {
        // do_cmdline() has stored the first typed line in
        // "repeat_cmdline".  When several lines are typed repeating
        // won't be possible.
        if (repeat_cmdline == NULL) {
          ResetRedobuff();
        } else {
          AppendToRedobuffLit(repeat_cmdline, -1);
          AppendToRedobuff(NL_STR);
          xfree(repeat_cmdline);
          repeat_cmdline = NULL;
        }
      }
    }

    if (redo_VIsual_busy) {
      /* Redo of an operation on a Visual area. Use the same size from
       * redo_VIsual_line_count and redo_VIsual_vcol. */
      oap->start = curwin->w_cursor;
      curwin->w_cursor.lnum += redo_VIsual_line_count - 1;
      if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count)
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      VIsual_mode = redo_VIsual_mode;
      if (redo_VIsual_vcol == MAXCOL || VIsual_mode == 'v') {
        if (VIsual_mode == 'v') {
          if (redo_VIsual_line_count <= 1) {
            validate_virtcol();
            curwin->w_curswant =
              curwin->w_virtcol + redo_VIsual_vcol - 1;
          } else
            curwin->w_curswant = redo_VIsual_vcol;
        } else {
          curwin->w_curswant = MAXCOL;
        }
        coladvance(curwin->w_curswant);
      }
      cap->count0 = redo_VIsual_count;
      cap->count1 = (cap->count0 == 0 ? 1 : cap->count0);
    } else if (VIsual_active) {
      if (!gui_yank) {
        /* Save the current VIsual area for '< and '> marks, and "gv" */
        curbuf->b_visual.vi_start = VIsual;
        curbuf->b_visual.vi_end = curwin->w_cursor;
        curbuf->b_visual.vi_mode = VIsual_mode;
        if (VIsual_mode_orig != NUL) {
          curbuf->b_visual.vi_mode = VIsual_mode_orig;
          VIsual_mode_orig = NUL;
        }
        curbuf->b_visual.vi_curswant = curwin->w_curswant;
        curbuf->b_visual_mode_eval = VIsual_mode;
      }

      // In Select mode, a linewise selection is operated upon like a
      // characterwise selection.
      // Special case: gH<Del> deletes the last line.
      if (VIsual_select && VIsual_mode == 'V'
          && cap->oap->op_type != OP_DELETE) {
        if (lt(VIsual, curwin->w_cursor)) {
          VIsual.col = 0;
          curwin->w_cursor.col =
            (colnr_T)STRLEN(ml_get(curwin->w_cursor.lnum));
        } else {
          curwin->w_cursor.col = 0;
          VIsual.col = (colnr_T)STRLEN(ml_get(VIsual.lnum));
        }
        VIsual_mode = 'v';
      }
      /* If 'selection' is "exclusive", backup one character for
       * charwise selections. */
      else if (VIsual_mode == 'v') {
        include_line_break =
          unadjust_for_sel();
      }

      oap->start = VIsual;
      if (VIsual_mode == 'V') {
        oap->start.col = 0;
        oap->start.coladd = 0;
      }
    }

    /*
     * Set oap->start to the first position of the operated text, oap->end
     * to the end of the operated text.  w_cursor is equal to oap->start.
     */
    if (lt(oap->start, curwin->w_cursor)) {
      /* Include folded lines completely. */
      if (!VIsual_active) {
        if (hasFolding(oap->start.lnum, &oap->start.lnum, NULL))
          oap->start.col = 0;
        if (hasFolding(curwin->w_cursor.lnum, NULL,
                &curwin->w_cursor.lnum))
          curwin->w_cursor.col = (colnr_T)STRLEN(get_cursor_line_ptr());
      }
      oap->end = curwin->w_cursor;
      curwin->w_cursor = oap->start;

      /* w_virtcol may have been updated; if the cursor goes back to its
       * previous position w_virtcol becomes invalid and isn't updated
       * automatically. */
      curwin->w_valid &= ~VALID_VIRTCOL;
    } else {
      // Include folded lines completely.
      if (!VIsual_active && oap->motion_type == kMTLineWise) {
        if (hasFolding(curwin->w_cursor.lnum, &curwin->w_cursor.lnum,
                       NULL)) {
          curwin->w_cursor.col = 0;
        }
        if (hasFolding(oap->start.lnum, NULL, &oap->start.lnum)) {
          oap->start.col = (colnr_T)STRLEN(ml_get(oap->start.lnum));
        }
      }
      oap->end = oap->start;
      oap->start = curwin->w_cursor;
    }

    // Just in case lines were deleted that make the position invalid.
    check_pos(curwin->w_buffer, &oap->end);
    oap->line_count = oap->end.lnum - oap->start.lnum + 1;

    /* Set "virtual_op" before resetting VIsual_active. */
    virtual_op = virtual_active();

    if (VIsual_active || redo_VIsual_busy) {
      get_op_vcol(oap, redo_VIsual_vcol, true);

      if (!redo_VIsual_busy && !gui_yank) {
        /*
         * Prepare to reselect and redo Visual: this is based on the
         * size of the Visual text
         */
        resel_VIsual_mode = VIsual_mode;
        if (curwin->w_curswant == MAXCOL)
          resel_VIsual_vcol = MAXCOL;
        else {
          if (VIsual_mode != Ctrl_V)
            getvvcol(curwin, &(oap->end),
                NULL, NULL, &oap->end_vcol);
          if (VIsual_mode == Ctrl_V || oap->line_count <= 1) {
            if (VIsual_mode != Ctrl_V)
              getvvcol(curwin, &(oap->start),
                  &oap->start_vcol, NULL, NULL);
            resel_VIsual_vcol = oap->end_vcol - oap->start_vcol + 1;
          } else
            resel_VIsual_vcol = oap->end_vcol;
        }
        resel_VIsual_line_count = oap->line_count;
      }

      /* can't redo yank (unless 'y' is in 'cpoptions') and ":" */
      if ((vim_strchr(p_cpo, CPO_YANK) != NULL || oap->op_type != OP_YANK)
          && oap->op_type != OP_COLON
          && oap->op_type != OP_FOLD
          && oap->op_type != OP_FOLDOPEN
          && oap->op_type != OP_FOLDOPENREC
          && oap->op_type != OP_FOLDCLOSE
          && oap->op_type != OP_FOLDCLOSEREC
          && oap->op_type != OP_FOLDDEL
          && oap->op_type != OP_FOLDDELREC
          && oap->motion_force == NUL
          ) {
        /* Prepare for redoing.  Only use the nchar field for "r",
         * otherwise it might be the second char of the operator. */
        if (cap->cmdchar == 'g' && (cap->nchar == 'n'
                                    || cap->nchar == 'N')) {
          prep_redo(oap->regname, cap->count0,
                    get_op_char(oap->op_type), get_extra_op_char(oap->op_type),
                    oap->motion_force, cap->cmdchar, cap->nchar);
        } else if (cap->cmdchar != ':') {
          int nchar = oap->op_type == OP_REPLACE ? cap->nchar : NUL;

          // reverse what nv_replace() did
          if (nchar == REPLACE_CR_NCHAR) {
            nchar = CAR;
          } else if (nchar == REPLACE_NL_NCHAR) {
            nchar = NL;
          }
          prep_redo(oap->regname, 0L, NUL, 'v', get_op_char(oap->op_type),
                    get_extra_op_char(oap->op_type), nchar);
        }
        if (!redo_VIsual_busy) {
          redo_VIsual_mode = resel_VIsual_mode;
          redo_VIsual_vcol = resel_VIsual_vcol;
          redo_VIsual_line_count = resel_VIsual_line_count;
          redo_VIsual_count = cap->count0;
          redo_VIsual_arg = cap->arg;
        }
      }

      // oap->inclusive defaults to true.
      // If oap->end is on a NUL (empty line) oap->inclusive becomes
      // false.  This makes "d}P" and "v}dP" work the same.
      if (oap->motion_force == NUL || oap->motion_type == kMTLineWise) {
        oap->inclusive = true;
      }
      if (VIsual_mode == 'V') {
        oap->motion_type = kMTLineWise;
      } else if (VIsual_mode == 'v') {
        oap->motion_type = kMTCharWise;
        if (*ml_get_pos(&(oap->end)) == NUL
            && (include_line_break || !virtual_op)
            ) {
          oap->inclusive = false;
          // Try to include the newline, unless it's an operator
          // that works on lines only.
          if (*p_sel != 'o'
              && !op_on_lines(oap->op_type)
              && oap->end.lnum < curbuf->b_ml.ml_line_count) {
            oap->end.lnum++;
            oap->end.col = 0;
            oap->end.coladd = 0;
            oap->line_count++;
          }
        }
      }

      redo_VIsual_busy = false;

      /*
       * Switch Visual off now, so screen updating does
       * not show inverted text when the screen is redrawn.
       * With OP_YANK and sometimes with OP_COLON and OP_FILTER there is
       * no screen redraw, so it is done here to remove the inverted
       * part.
       */
      if (!gui_yank) {
        VIsual_active = false;
        setmouse();
        mouse_dragging = 0;
        may_clear_cmdline();
        if ((oap->op_type == OP_YANK
             || oap->op_type == OP_COLON
             || oap->op_type == OP_FUNCTION
             || oap->op_type == OP_FILTER)
            && oap->motion_force == NUL) {
          // Make sure redrawing is correct.
          curwin->w_p_lbr = lbr_saved;
          redraw_curbuf_later(INVERTED);
        }
      }
    }

    /* Include the trailing byte of a multi-byte char. */
    if (has_mbyte && oap->inclusive) {
      int l;

      l = (*mb_ptr2len)(ml_get_pos(&oap->end));
      if (l > 1)
        oap->end.col += l - 1;
    }
    curwin->w_set_curswant = true;

    /*
     * oap->empty is set when start and end are the same.  The inclusive
     * flag affects this too, unless yanking and the end is on a NUL.
     */
    oap->empty = (oap->motion_type != kMTLineWise
                  && (!oap->inclusive
                      || (oap->op_type == OP_YANK
                          && gchar_pos(&oap->end) == NUL))
                  && equalpos(oap->start, oap->end)
                  && !(virtual_op && oap->start.coladd != oap->end.coladd)
                  );
    /*
     * For delete, change and yank, it's an error to operate on an
     * empty region, when 'E' included in 'cpoptions' (Vi compatible).
     */
    empty_region_error = (oap->empty
                          && vim_strchr(p_cpo, CPO_EMPTYREGION) != NULL);

    /* Force a redraw when operating on an empty Visual region, when
     * 'modifiable is off or creating a fold. */
    if (oap->is_VIsual && (oap->empty || !MODIFIABLE(curbuf)
                           || oap->op_type == OP_FOLD
                           )) {
      curwin->w_p_lbr = lbr_saved;
      redraw_curbuf_later(INVERTED);
    }

    /*
     * If the end of an operator is in column one while oap->motion_type
     * is kMTCharWise and oap->inclusive is false, we put op_end after the last
     * character in the previous line. If op_start is on or before the
     * first non-blank in the line, the operator becomes linewise
     * (strange, but that's the way vi does it).
     */
    if (oap->motion_type == kMTCharWise
        && oap->inclusive == false
        && !(cap->retval & CA_NO_ADJ_OP_END)
        && oap->end.col == 0
        && (!oap->is_VIsual || *p_sel == 'o')
        && oap->line_count > 1) {
      oap->end_adjusted = true;  // remember that we did this
      oap->line_count--;
      oap->end.lnum--;
      if (inindent(0)) {
        oap->motion_type = kMTLineWise;
      } else {
        oap->end.col = (colnr_T)STRLEN(ml_get(oap->end.lnum));
        if (oap->end.col) {
          --oap->end.col;
          oap->inclusive = true;
        }
      }
    } else
      oap->end_adjusted = false;

    switch (oap->op_type) {
    case OP_LSHIFT:
    case OP_RSHIFT:
      op_shift(oap, true,
          oap->is_VIsual ? (int)cap->count1 :
          1);
      auto_format(false, true);
      break;

    case OP_JOIN_NS:
    case OP_JOIN:
      if (oap->line_count < 2)
        oap->line_count = 2;
      if (curwin->w_cursor.lnum + oap->line_count - 1 >
          curbuf->b_ml.ml_line_count) {
        beep_flush();
      } else {
        do_join((size_t)oap->line_count, oap->op_type == OP_JOIN,
                true, true, true);
        auto_format(false, true);
      }
      break;

    case OP_DELETE:
      VIsual_reselect = false;              /* don't reselect now */
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        (void)op_delete(oap);
        if (oap->motion_type == kMTLineWise && has_format_option(FO_AUTO)) {
          // cursor line wasn't saved yet
          if (u_save_cursor() == FAIL) {
            break;
          }
        }
        auto_format(false, true);
      }
      break;

    case OP_YANK:
      if (empty_region_error) {
        if (!gui_yank) {
          vim_beep(BO_OPER);
          CancelRedo();
        }
      } else {
        curwin->w_p_lbr = lbr_saved;
        (void)op_yank(oap, !gui_yank);
      }
      check_cursor_col();
      break;

    case OP_CHANGE:
      VIsual_reselect = false;              /* don't reselect now */
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        /* This is a new edit command, not a restart.  Need to
         * remember it to make 'insertmode' work with mappings for
         * Visual mode.  But do this only once and not when typed and
         * 'insertmode' isn't set. */
        if (p_im || !KeyTyped)
          restart_edit_save = restart_edit;
        else
          restart_edit_save = 0;
        restart_edit = 0;

        // Restore linebreak, so that when the user edits it looks as before.
        if (curwin->w_p_lbr != lbr_saved) {
          curwin->w_p_lbr = lbr_saved;
          get_op_vcol(oap, redo_VIsual_mode, false);
        }

        // Reset finish_op now, don't want it set inside edit().
        finish_op = false;
        if (op_change(oap))             /* will call edit() */
          cap->retval |= CA_COMMAND_BUSY;
        if (restart_edit == 0)
          restart_edit = restart_edit_save;
      }
      break;

    case OP_FILTER:
      if (vim_strchr(p_cpo, CPO_FILTER) != NULL) {
        AppendToRedobuff("!\r");  // Use any last used !cmd.
      } else {
        bangredo = true;  // do_bang() will put cmd in redo buffer.
      }
      FALLTHROUGH;

    case OP_INDENT:
    case OP_COLON:

      /*
       * If 'equalprg' is empty, do the indenting internally.
       */
      if (oap->op_type == OP_INDENT && *get_equalprg() == NUL) {
        if (curbuf->b_p_lisp) {
          op_reindent(oap, get_lisp_indent);
          break;
        }
        op_reindent(oap,
            *curbuf->b_p_inde != NUL ? get_expr_indent :
            get_c_indent);
        break;
      }

      op_colon(oap);
      break;

    case OP_TILDE:
    case OP_UPPER:
    case OP_LOWER:
    case OP_ROT13:
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else
        op_tilde(oap);
      check_cursor_col();
      break;

    case OP_FORMAT:
      if (*curbuf->b_p_fex != NUL) {
        op_formatexpr(oap);             // use expression
      } else if (*p_fp != NUL || *curbuf->b_p_fp != NUL) {
        op_colon(oap);                  // use external command
      } else {
        op_format(oap, false);          // use internal function
      }
      break;

    case OP_FORMAT2:
      op_format(oap, true);             /* use internal function */
      break;

    case OP_FUNCTION:
      // Restore linebreak, so that when the user edits it looks as
      // before.
      curwin->w_p_lbr = lbr_saved;
      op_function(oap);                 // call 'operatorfunc'
      break;

    case OP_INSERT:
    case OP_APPEND:
      VIsual_reselect = false;          /* don't reselect now */
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        /* This is a new edit command, not a restart.  Need to
         * remember it to make 'insertmode' work with mappings for
         * Visual mode.  But do this only once. */
        restart_edit_save = restart_edit;
        restart_edit = 0;

        // Restore linebreak, so that when the user edits it looks as before.
        if (curwin->w_p_lbr != lbr_saved) {
          curwin->w_p_lbr = lbr_saved;
          get_op_vcol(oap, redo_VIsual_mode, false);
        }

        op_insert(oap, cap->count1);

        // Reset linebreak, so that formatting works correctly.
        curwin->w_p_lbr = false;

        /* TODO: when inserting in several lines, should format all
         * the lines. */
        auto_format(false, true);

        if (restart_edit == 0) {
          restart_edit = restart_edit_save;
        } else {
          cap->retval |= CA_COMMAND_BUSY;
        }
      }
      break;

    case OP_REPLACE:
      VIsual_reselect = false;          /* don't reselect now */
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        // Restore linebreak, so that when the user edits it looks as before.
        if (curwin->w_p_lbr != lbr_saved) {
          curwin->w_p_lbr = lbr_saved;
          get_op_vcol(oap, redo_VIsual_mode, false);
        }

        op_replace(oap, cap->nchar);
      }
      break;

    case OP_FOLD:
      VIsual_reselect = false;          /* don't reselect now */
      foldCreate(oap->start.lnum, oap->end.lnum);
      break;

    case OP_FOLDOPEN:
    case OP_FOLDOPENREC:
    case OP_FOLDCLOSE:
    case OP_FOLDCLOSEREC:
      VIsual_reselect = false;          /* don't reselect now */
      opFoldRange(oap->start.lnum, oap->end.lnum,
          oap->op_type == OP_FOLDOPEN
          || oap->op_type == OP_FOLDOPENREC,
          oap->op_type == OP_FOLDOPENREC
          || oap->op_type == OP_FOLDCLOSEREC,
          oap->is_VIsual);
      break;

    case OP_FOLDDEL:
    case OP_FOLDDELREC:
      VIsual_reselect = false;          /* don't reselect now */
      deleteFold(oap->start.lnum, oap->end.lnum,
          oap->op_type == OP_FOLDDELREC, oap->is_VIsual);
      break;

    case OP_NR_ADD:
    case OP_NR_SUB:
      if (empty_region_error) {
        vim_beep(BO_OPER);
        CancelRedo();
      } else {
        VIsual_active = true;
        curwin->w_p_lbr = lbr_saved;
        op_addsub(oap, cap->count1, redo_VIsual_arg);
        VIsual_active = false;
      }
      check_cursor_col();
      break;
    default:
      clearopbeep(oap);
    }
    virtual_op = kNone;
    if (!gui_yank) {
      /*
       * if 'sol' not set, go back to old column for some commands
       */
      if (!p_sol && oap->motion_type == kMTLineWise && !oap->end_adjusted
          && (oap->op_type == OP_LSHIFT || oap->op_type == OP_RSHIFT
              || oap->op_type == OP_DELETE)) {
        curwin->w_p_lbr = false;
        coladvance(curwin->w_curswant = old_col);
      }
    } else {
      curwin->w_cursor = old_cursor;
    }
    clearop(oap);
  }
  curwin->w_p_lbr = lbr_saved;
}

/*
 * Handle indent and format operators and visual mode ":".
 */
static void op_colon(oparg_T *oap)
{
  stuffcharReadbuff(':');
  if (oap->is_VIsual) {
    stuffReadbuff("'<,'>");
  } else {
    // Make the range look nice, so it can be repeated.
    if (oap->start.lnum == curwin->w_cursor.lnum) {
      stuffcharReadbuff('.');
    } else {
      stuffnumReadbuff((long)oap->start.lnum);
    }
    if (oap->end.lnum != oap->start.lnum) {
      stuffcharReadbuff(',');
      if (oap->end.lnum == curwin->w_cursor.lnum) {
        stuffcharReadbuff('.');
      } else if (oap->end.lnum == curbuf->b_ml.ml_line_count) {
        stuffcharReadbuff('$');
      } else if (oap->start.lnum == curwin->w_cursor.lnum) {
        stuffReadbuff(".+");
        stuffnumReadbuff(oap->line_count - 1);
      } else {
        stuffnumReadbuff((long)oap->end.lnum);
      }
    }
  }
  if (oap->op_type != OP_COLON) {
    stuffReadbuff("!");
  }
  if (oap->op_type == OP_INDENT) {
    stuffReadbuff((const char *)get_equalprg());
    stuffReadbuff("\n");
  } else if (oap->op_type == OP_FORMAT) {
    if (*curbuf->b_p_fp != NUL) {
      stuffReadbuff((const char *)curbuf->b_p_fp);
    } else if (*p_fp != NUL) {
      stuffReadbuff((const char *)p_fp);
    } else {
      stuffReadbuff("fmt");
    }
    stuffReadbuff("\n']");
  }

  /*
   * do_cmdline() does the rest
   */
}

/*
 * Handle the "g@" operator: call 'operatorfunc'.
 */
static void op_function(oparg_T *oap)
{
  const TriState save_virtual_op = virtual_op;

  if (*p_opfunc == NUL)
    EMSG(_("E774: 'operatorfunc' is empty"));
  else {
    /* Set '[ and '] marks to text to be operated on. */
    curbuf->b_op_start = oap->start;
    curbuf->b_op_end = oap->end;
    if (oap->motion_type != kMTLineWise && !oap->inclusive) {
      // Exclude the end position.
      decl(&curbuf->b_op_end);
    }

    const char_u *const argv[1] = {
      (const char_u *)(((const char *const[]) {
        [kMTBlockWise] = "block",
        [kMTLineWise] = "line",
        [kMTCharWise] = "char",
      })[oap->motion_type]),
    };

    // Reset virtual_op so that 'virtualedit' can be changed in the
    // function.
    virtual_op = kNone;

    (void)call_func_retnr(p_opfunc, 1, argv, false);

    virtual_op = save_virtual_op;
  }
}

// Move the current tab to tab in same column as mouse or to end of the
// tabline if there is no tab there.
static void move_tab_to_mouse(void)
{
  int tabnr = tab_page_click_defs[mouse_col].tabnr;
  if (tabnr <= 0) {
      tabpage_move(9999);
  } else if (tabnr < tabpage_index(curtab)) {
      tabpage_move(tabnr - 1);
  } else {
      tabpage_move(tabnr);
  }
}

/*
 * Do the appropriate action for the current mouse click in the current mode.
 * Not used for Command-line mode.
 *
 * Normal Mode:
 * event	 modi-	position      visual	   change   action
 *		 fier	cursor			   window
 * left press	  -	yes	    end		    yes
 * left press	  C	yes	    end		    yes	    "^]" (2)
 * left press	  S	yes	    end		    yes	    "*" (2)
 * left drag	  -	yes	start if moved	    no
 * left relse	  -	yes	start if moved	    no
 * middle press	  -	yes	 if not active	    no	    put register
 * middle press	  -	yes	 if active	    no	    yank and put
 * right press	  -	yes	start or extend	    yes
 * right press	  S	yes	no change	    yes	    "#" (2)
 * right drag	  -	yes	extend		    no
 * right relse	  -	yes	extend		    no
 *
 * Insert or Replace Mode:
 * event	 modi-	position      visual	   change   action
 *		 fier	cursor			   window
 * left press	  -	yes	(cannot be active)  yes
 * left press	  C	yes	(cannot be active)  yes	    "CTRL-O^]" (2)
 * left press	  S	yes	(cannot be active)  yes	    "CTRL-O*" (2)
 * left drag	  -	yes	start or extend (1) no	    CTRL-O (1)
 * left relse	  -	yes	start or extend (1) no	    CTRL-O (1)
 * middle press	  -	no	(cannot be active)  no	    put register
 * right press	  -	yes	start or extend	    yes	    CTRL-O
 * right press	  S	yes	(cannot be active)  yes	    "CTRL-O#" (2)
 *
 * (1) only if mouse pointer moved since press
 * (2) only if click is in same buffer
 *
 * Return true if start_arrow() should be called for edit mode.
 */
bool
do_mouse (
    oparg_T *oap,               /* operator argument, can be NULL */
    int c,                          /* K_LEFTMOUSE, etc */
    int dir,                        /* Direction to 'put' if necessary */
    long count,
    bool fixindent                  /* PUT_FIXINDENT if fixing indent necessary */
)
{
  static bool got_click = false;        /* got a click some time back */

  int which_button;             /* MOUSE_LEFT, _MIDDLE or _RIGHT */
  bool is_click;                /* If false it's a drag or release event */
  bool is_drag;                 /* If true it's a drag event */
  int jump_flags = 0;           /* flags for jump_to_mouse() */
  pos_T start_visual;
  bool moved;                   /* Has cursor moved? */
  bool in_status_line;          /* mouse in status line */
  static bool in_tab_line = false;   /* mouse clicked in tab line */
  bool in_sep_line;             /* mouse in vertical separator line */
  int c1, c2;
  pos_T save_cursor;
  win_T       *old_curwin = curwin;
  static pos_T orig_cursor;
  colnr_T leftcol, rightcol;
  pos_T end_visual;
  long diff;
  int old_active = VIsual_active;
  int old_mode = VIsual_mode;
  int regname;

  save_cursor = curwin->w_cursor;

  for (;; ) {
    which_button = get_mouse_button(KEY2TERMCAP1(c), &is_click, &is_drag);
    if (is_drag) {
      /* If the next character is the same mouse event then use that
       * one. Speeds up dragging the status line. */
      if (vpeekc() != NUL) {
        int nc;
        int save_mouse_row = mouse_row;
        int save_mouse_col = mouse_col;

        /* Need to get the character, peeking doesn't get the actual
         * one. */
        nc = safe_vgetc();
        if (c == nc)
          continue;
        vungetc(nc);
        mouse_row = save_mouse_row;
        mouse_col = save_mouse_col;
      }
    }
    break;
  }


  /*
   * Ignore drag and release events if we didn't get a click.
   */
  if (is_click)
    got_click = true;
  else {
    if (!got_click)                     /* didn't get click, ignore */
      return false;
    if (!is_drag) {                     /* release, reset got_click */
      got_click = false;
      if (in_tab_line) {
        in_tab_line = false;
        return false;
      }
    }
  }


  /*
   * CTRL right mouse button does CTRL-T
   */
  if (is_click && (mod_mask & MOD_MASK_CTRL) && which_button == MOUSE_RIGHT) {
    if (State & INSERT)
      stuffcharReadbuff(Ctrl_O);
    if (count > 1)
      stuffnumReadbuff(count);
    stuffcharReadbuff(Ctrl_T);
    got_click = false;                  /* ignore drag&release now */
    return false;
  }

  /*
   * CTRL only works with left mouse button
   */
  if ((mod_mask & MOD_MASK_CTRL) && which_button != MOUSE_LEFT)
    return false;

  /*
   * When a modifier is down, ignore drag and release events, as well as
   * multiple clicks and the middle mouse button.
   * Accept shift-leftmouse drags when 'mousemodel' is "popup.*".
   */
  if ((mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL | MOD_MASK_ALT
                   | MOD_MASK_META))
      && (!is_click
          || (mod_mask & MOD_MASK_MULTI_CLICK)
          || which_button == MOUSE_MIDDLE)
      && !((mod_mask & (MOD_MASK_SHIFT|MOD_MASK_ALT))
           && mouse_model_popup()
           && which_button == MOUSE_LEFT)
      && !((mod_mask & MOD_MASK_ALT)
           && !mouse_model_popup()
           && which_button == MOUSE_RIGHT)
      )
    return false;

  /*
   * If the button press was used as the movement command for an operator
   * (eg "d<MOUSE>"), or it is the middle button that is held down, ignore
   * drag/release events.
   */
  if (!is_click && which_button == MOUSE_MIDDLE)
    return false;

  if (oap != NULL)
    regname = oap->regname;
  else
    regname = 0;

  /*
   * Middle mouse button does a 'put' of the selected text
   */
  if (which_button == MOUSE_MIDDLE) {
    if (State == NORMAL) {
      /*
       * If an operator was pending, we don't know what the user wanted
       * to do. Go back to normal mode: Clear the operator and beep().
       */
      if (oap != NULL && oap->op_type != OP_NOP) {
        clearopbeep(oap);
        return false;
      }

      /*
       * If visual was active, yank the highlighted text and put it
       * before the mouse pointer position.
       * In Select mode replace the highlighted text with the clipboard.
       */
      if (VIsual_active) {
        if (VIsual_select) {
          stuffcharReadbuff(Ctrl_G);
          stuffReadbuff("\"+p");
        } else {
          stuffcharReadbuff('y');
          stuffcharReadbuff(K_MIDDLEMOUSE);
        }
        return false;
      }
      /*
       * The rest is below jump_to_mouse()
       */
    } else if ((State & INSERT) == 0)
      return false;

    /*
     * Middle click in insert mode doesn't move the mouse, just insert the
     * contents of a register.  '.' register is special, can't insert that
     * with do_put().
     * Also paste at the cursor if the current mode isn't in 'mouse' (only
     * happens for the GUI).
     */
    if ((State & INSERT) || !mouse_has(MOUSE_NORMAL)) {
      if (regname == '.')
        insert_reg(regname, true);
      else {
        if (regname == 0 && eval_has_provider("clipboard")) {
          regname = '*';
        }
        if ((State & REPLACE_FLAG) && !yank_register_mline(regname)) {
          insert_reg(regname, true);
        } else {
          do_put(regname, NULL, BACKWARD, 1L,
                 (fixindent ? PUT_FIXINDENT : 0) | PUT_CURSEND);

          /* Repeat it with CTRL-R CTRL-O r or CTRL-R CTRL-P r */
          AppendCharToRedobuff(Ctrl_R);
          AppendCharToRedobuff(fixindent ? Ctrl_P : Ctrl_O);
          AppendCharToRedobuff(regname == 0 ? '"' : regname);
        }
      }
      return false;
    }
  }

  /* When dragging or button-up stay in the same window. */
  if (!is_click)
    jump_flags |= MOUSE_FOCUS | MOUSE_DID_MOVE;

  start_visual.lnum = 0;

  /* Check for clicking in the tab page line. */
  if (mouse_row == 0 && firstwin->w_winrow > 0) {
    if (is_drag) {
      if (in_tab_line) {
        move_tab_to_mouse();
      }
      return false;
    }

    /* click in a tab selects that tab page */
    if (is_click
        && cmdwin_type == 0
        && mouse_col < Columns) {
      in_tab_line = true;
      c1 = tab_page_click_defs[mouse_col].tabnr;
      switch (tab_page_click_defs[mouse_col].type) {
        case kStlClickDisabled: {
          break;
        }
        case kStlClickTabClose: {
          tabpage_T *tp;

          // Close the current or specified tab page.
          if (c1 == 999) {
            tp = curtab;
          } else {
            tp = find_tabpage(c1);
          }
          if (tp == curtab) {
            if (first_tabpage->tp_next != NULL) {
              tabpage_close(false);
            }
          } else if (tp != NULL) {
            tabpage_close_other(tp, false);
          }
          break;
        }
        case kStlClickTabSwitch: {
          if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK) {
            // double click opens new page
            end_visual_mode();
            tabpage_new();
            tabpage_move(c1 == 0 ? 9999 : c1 - 1);
          } else {
            // Go to specified tab page, or next one if not clicking
            // on a label.
            goto_tabpage(c1);

            // It's like clicking on the status line of a window.
            if (curwin != old_curwin) {
              end_visual_mode();
            }
          }
          break;
        }
        case kStlClickFuncRun: {
          typval_T argv[] = {
            {
              .v_lock = VAR_FIXED,
              .v_type = VAR_NUMBER,
              .vval = {
                .v_number = (varnumber_T) tab_page_click_defs[mouse_col].tabnr
              },
            },
            {
              .v_lock = VAR_FIXED,
              .v_type = VAR_NUMBER,
              .vval = {
                .v_number = (((mod_mask & MOD_MASK_MULTI_CLICK)
                              == MOD_MASK_4CLICK)
                             ? 4
                             : ((mod_mask & MOD_MASK_MULTI_CLICK)
                                == MOD_MASK_3CLICK)
                             ? 3
                             : ((mod_mask & MOD_MASK_MULTI_CLICK)
                                == MOD_MASK_2CLICK)
                             ? 2
                             : 1)
              },
            },
            {
              .v_lock = VAR_FIXED,
              .v_type = VAR_STRING,
              .vval = { .v_string = (char_u *) (which_button == MOUSE_LEFT
                                                ? "l"
                                                : which_button == MOUSE_RIGHT
                                                ? "r"
                                                : which_button == MOUSE_MIDDLE
                                                ? "m"
                                                : "?") },
            },
            {
              .v_lock = VAR_FIXED,
              .v_type = VAR_STRING,
              .vval = {
                .v_string = (char_u[]) {
                  (char_u) (mod_mask & MOD_MASK_SHIFT ? 's' : ' '),
                  (char_u) (mod_mask & MOD_MASK_CTRL ? 'c' : ' '),
                  (char_u) (mod_mask & MOD_MASK_ALT ? 'a' : ' '),
                  (char_u) (mod_mask & MOD_MASK_META ? 'm' : ' '),
                  NUL
                }
              },
            }
          };
          typval_T rettv;
          int doesrange;
          (void)call_func((char_u *)tab_page_click_defs[mouse_col].func,
                          (int)strlen(tab_page_click_defs[mouse_col].func),
                          &rettv, ARRAY_SIZE(argv), argv, NULL,
                          curwin->w_cursor.lnum, curwin->w_cursor.lnum,
                          &doesrange, true, NULL, NULL);
          tv_clear(&rettv);
          break;
        }
      }
    }
    return true;
  } else if (is_drag && in_tab_line) {
    move_tab_to_mouse();
    return false;
  }


  /*
   * When 'mousemodel' is "popup" or "popup_setpos", translate mouse events:
   * right button up   -> pop-up menu
   * shift-left button -> right button
   * alt-left button   -> alt-right button
   */
  if (mouse_model_popup()) {
    if (which_button == MOUSE_RIGHT
        && !(mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL))) {
      /*
       * NOTE: Ignore right button down and drag mouse events.
       * Windows only shows the popup menu on the button up event.
       */
      return false;
    }
    if (which_button == MOUSE_LEFT
        && (mod_mask & (MOD_MASK_SHIFT|MOD_MASK_ALT))) {
      which_button = MOUSE_RIGHT;
      mod_mask &= ~MOD_MASK_SHIFT;
    }
  }

  if ((State & (NORMAL | INSERT))
      && !(mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL))) {
    if (which_button == MOUSE_LEFT) {
      if (is_click) {
        /* stop Visual mode for a left click in a window, but not when
         * on a status line */
        if (VIsual_active)
          jump_flags |= MOUSE_MAY_STOP_VIS;
      } else if (mouse_has(MOUSE_VISUAL))
        jump_flags |= MOUSE_MAY_VIS;
    } else if (which_button == MOUSE_RIGHT) {
      if (is_click && VIsual_active) {
        /*
         * Remember the start and end of visual before moving the
         * cursor.
         */
        if (lt(curwin->w_cursor, VIsual)) {
          start_visual = curwin->w_cursor;
          end_visual = VIsual;
        } else {
          start_visual = VIsual;
          end_visual = curwin->w_cursor;
        }
      }
      jump_flags |= MOUSE_FOCUS;
      if (mouse_has(MOUSE_VISUAL))
        jump_flags |= MOUSE_MAY_VIS;
    }
  }

  /*
   * If an operator is pending, ignore all drags and releases until the
   * next mouse click.
   */
  if (!is_drag && oap != NULL && oap->op_type != OP_NOP) {
    got_click = false;
    oap->motion_type = kMTCharWise;
  }

  /* When releasing the button let jump_to_mouse() know. */
  if (!is_click && !is_drag)
    jump_flags |= MOUSE_RELEASED;

  /*
   * JUMP!
   */
  jump_flags = jump_to_mouse(jump_flags,
      oap == NULL ? NULL : &(oap->inclusive), which_button);
  moved = (jump_flags & CURSOR_MOVED);
  in_status_line = (jump_flags & IN_STATUS_LINE);
  in_sep_line = (jump_flags & IN_SEP_LINE);


  /* When jumping to another window, clear a pending operator.  That's a bit
   * friendlier than beeping and not jumping to that window. */
  if (curwin != old_curwin && oap != NULL && oap->op_type != OP_NOP)
    clearop(oap);

  if (mod_mask == 0
      && !is_drag
      && (jump_flags & (MOUSE_FOLD_CLOSE | MOUSE_FOLD_OPEN))
      && which_button == MOUSE_LEFT) {
    /* open or close a fold at this line */
    if (jump_flags & MOUSE_FOLD_OPEN)
      openFold(curwin->w_cursor.lnum, 1L);
    else
      closeFold(curwin->w_cursor.lnum, 1L);
    /* don't move the cursor if still in the same window */
    if (curwin == old_curwin)
      curwin->w_cursor = save_cursor;
  }


  /* Set global flag that we are extending the Visual area with mouse
   * dragging; temporarily minimize 'scrolloff'. */
  if (VIsual_active && is_drag && p_so) {
    /* In the very first line, allow scrolling one line */
    if (mouse_row == 0)
      mouse_dragging = 2;
    else
      mouse_dragging = 1;
  }

  /* When dragging the mouse above the window, scroll down. */
  if (is_drag && mouse_row < 0 && !in_status_line) {
    scroll_redraw(false, 1L);
    mouse_row = 0;
  }

  if (start_visual.lnum) {              /* right click in visual mode */
    /* When ALT is pressed make Visual mode blockwise. */
    if (mod_mask & MOD_MASK_ALT)
      VIsual_mode = Ctrl_V;

    /*
     * In Visual-block mode, divide the area in four, pick up the corner
     * that is in the quarter that the cursor is in.
     */
    if (VIsual_mode == Ctrl_V) {
      getvcols(curwin, &start_visual, &end_visual, &leftcol, &rightcol);
      if (curwin->w_curswant > (leftcol + rightcol) / 2)
        end_visual.col = leftcol;
      else
        end_visual.col = rightcol;
      if (curwin->w_cursor.lnum >=
          (start_visual.lnum + end_visual.lnum) / 2) {
        end_visual.lnum = start_visual.lnum;
      }

      /* move VIsual to the right column */
      start_visual = curwin->w_cursor;              /* save the cursor pos */
      curwin->w_cursor = end_visual;
      coladvance(end_visual.col);
      VIsual = curwin->w_cursor;
      curwin->w_cursor = start_visual;              /* restore the cursor */
    } else {
      /*
       * If the click is before the start of visual, change the start.
       * If the click is after the end of visual, change the end.  If
       * the click is inside the visual, change the closest side.
       */
      if (lt(curwin->w_cursor, start_visual))
        VIsual = end_visual;
      else if (lt(end_visual, curwin->w_cursor))
        VIsual = start_visual;
      else {
        /* In the same line, compare column number */
        if (end_visual.lnum == start_visual.lnum) {
          if (curwin->w_cursor.col - start_visual.col >
              end_visual.col - curwin->w_cursor.col)
            VIsual = start_visual;
          else
            VIsual = end_visual;
        }
        /* In different lines, compare line number */
        else {
          diff = (curwin->w_cursor.lnum - start_visual.lnum) -
                 (end_visual.lnum - curwin->w_cursor.lnum);

          if (diff > 0)                         /* closest to end */
            VIsual = start_visual;
          else if (diff < 0)            /* closest to start */
            VIsual = end_visual;
          else {                                /* in the middle line */
            if (curwin->w_cursor.col <
                (start_visual.col + end_visual.col) / 2)
              VIsual = end_visual;
            else
              VIsual = start_visual;
          }
        }
      }
    }
  }
  /*
   * If Visual mode started in insert mode, execute "CTRL-O"
   */
  else if ((State & INSERT) && VIsual_active)
    stuffcharReadbuff(Ctrl_O);

  /*
   * Middle mouse click: Put text before cursor.
   */
  if (which_button == MOUSE_MIDDLE) {
    if (regname == 0 && eval_has_provider("clipboard")) {
      regname = '*';
    }
    if (yank_register_mline(regname)) {
      if (mouse_past_bottom)
        dir = FORWARD;
    } else if (mouse_past_eol)
      dir = FORWARD;

    if (fixindent) {
      c1 = (dir == BACKWARD) ? '[' : ']';
      c2 = 'p';
    } else {
      c1 = (dir == FORWARD) ? 'p' : 'P';
      c2 = NUL;
    }
    prep_redo(regname, count, NUL, c1, NUL, c2, NUL);

    /*
     * Remember where the paste started, so in edit() Insstart can be set
     * to this position
     */
    if (restart_edit != 0)
      where_paste_started = curwin->w_cursor;
    do_put(regname, NULL, dir, count,
           (fixindent ? PUT_FIXINDENT : 0)| PUT_CURSEND);
  }
  /*
   * Ctrl-Mouse click or double click in a quickfix window jumps to the
   * error under the mouse pointer.
   */
  else if (((mod_mask & MOD_MASK_CTRL)
            || (mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK)
           && bt_quickfix(curbuf)) {
    if (curwin->w_llist_ref == NULL) {          // quickfix window
      do_cmdline_cmd(".cc");
    } else {                                    // location list window
      do_cmdline_cmd(".ll");
    }
    got_click = false;                  // ignore drag&release now
  }
  /*
   * Ctrl-Mouse click (or double click in a help window) jumps to the tag
   * under the mouse pointer.
   */
  else if ((mod_mask & MOD_MASK_CTRL) || (curbuf->b_help
                                          && (mod_mask &
                                              MOD_MASK_MULTI_CLICK) ==
                                          MOD_MASK_2CLICK)) {
    if (State & INSERT)
      stuffcharReadbuff(Ctrl_O);
    stuffcharReadbuff(Ctrl_RSB);
    got_click = false;                  /* ignore drag&release now */
  }
  /*
   * Shift-Mouse click searches for the next occurrence of the word under
   * the mouse pointer
   */
  else if ((mod_mask & MOD_MASK_SHIFT)) {
    if (State & INSERT
        || (VIsual_active && VIsual_select)
        )
      stuffcharReadbuff(Ctrl_O);
    if (which_button == MOUSE_LEFT)
      stuffcharReadbuff('*');
    else        /* MOUSE_RIGHT */
      stuffcharReadbuff('#');
  }
  /* Handle double clicks, unless on status line */
  else if (in_status_line) {
  } else if (in_sep_line) {
  } else if ((mod_mask & MOD_MASK_MULTI_CLICK) && (State & (NORMAL | INSERT))
             && mouse_has(MOUSE_VISUAL)) {
    if (is_click || !VIsual_active) {
      if (VIsual_active) {
        orig_cursor = VIsual;
      } else {
        VIsual = curwin->w_cursor;
        orig_cursor = VIsual;
        VIsual_active = true;
        VIsual_reselect = true;
        /* start Select mode if 'selectmode' contains "mouse" */
        may_start_select('o');
        setmouse();
      }
      if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK) {
        /* Double click with ALT pressed makes it blockwise. */
        if (mod_mask & MOD_MASK_ALT)
          VIsual_mode = Ctrl_V;
        else
          VIsual_mode = 'v';
      } else if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_3CLICK)
        VIsual_mode = 'V';
      else if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_4CLICK)
        VIsual_mode = Ctrl_V;
    }
    /*
     * A double click selects a word or a block.
     */
    if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK) {
      pos_T       *pos = NULL;
      int gc;

      if (is_click) {
        /* If the character under the cursor (skipping white space) is
         * not a word character, try finding a match and select a (),
         * {}, [], #if/#endif, etc. block. */
        end_visual = curwin->w_cursor;
        while (gc = gchar_pos(&end_visual), ascii_iswhite(gc))
          inc(&end_visual);
        if (oap != NULL) {
          oap->motion_type = kMTCharWise;
        }
        if (oap != NULL
            && VIsual_mode == 'v'
            && !vim_iswordc(gchar_pos(&end_visual))
            && equalpos(curwin->w_cursor, VIsual)
            && (pos = findmatch(oap, NUL)) != NULL) {
          curwin->w_cursor = *pos;
          if (oap->motion_type == kMTLineWise) {
            VIsual_mode = 'V';
          } else if (*p_sel == 'e') {
            if (lt(curwin->w_cursor, VIsual)) {
              VIsual.col++;
            } else {
              curwin->w_cursor.col++;
            }
          }
        }
      }

      if (pos == NULL && (is_click || is_drag)) {
        /* When not found a match or when dragging: extend to include
         * a word. */
        if (lt(curwin->w_cursor, orig_cursor)) {
          find_start_of_word(&curwin->w_cursor);
          find_end_of_word(&VIsual);
        } else {
          find_start_of_word(&VIsual);
          if (*p_sel == 'e' && *get_cursor_pos_ptr() != NUL)
            curwin->w_cursor.col +=
              (*mb_ptr2len)(get_cursor_pos_ptr());
          find_end_of_word(&curwin->w_cursor);
        }
      }
      curwin->w_set_curswant = true;
    }
    if (is_click)
      redraw_curbuf_later(INVERTED);            /* update the inversion */
  } else if (VIsual_active && !old_active) {
    if (mod_mask & MOD_MASK_ALT)
      VIsual_mode = Ctrl_V;
    else
      VIsual_mode = 'v';
  }

  /* If Visual mode changed show it later. */
  if ((!VIsual_active && old_active && mode_displayed)
      || (VIsual_active && p_smd && msg_silent == 0
          && (!old_active || VIsual_mode != old_mode)))
    redraw_cmdline = true;

  return moved;
}

/*
 * Move "pos" back to the start of the word it's in.
 */
static void find_start_of_word(pos_T *pos)
{
  char_u      *line;
  int cclass;
  int col;

  line = ml_get(pos->lnum);
  cclass = get_mouse_class(line + pos->col);

  while (pos->col > 0) {
    col = pos->col - 1;
    col -= utf_head_off(line, line + col);
    if (get_mouse_class(line + col) != cclass) {
      break;
    }
    pos->col = col;
  }
}

/*
 * Move "pos" forward to the end of the word it's in.
 * When 'selection' is "exclusive", the position is just after the word.
 */
static void find_end_of_word(pos_T *pos)
{
  char_u      *line;
  int cclass;
  int col;

  line = ml_get(pos->lnum);
  if (*p_sel == 'e' && pos->col > 0) {
    pos->col--;
    pos->col -= utf_head_off(line, line + pos->col);
  }
  cclass = get_mouse_class(line + pos->col);
  while (line[pos->col] != NUL) {
    col = pos->col + (*mb_ptr2len)(line + pos->col);
    if (get_mouse_class(line + col) != cclass) {
      if (*p_sel == 'e')
        pos->col = col;
      break;
    }
    pos->col = col;
  }
}

/*
 * Get class of a character for selection: same class means same word.
 * 0: blank
 * 1: punctuation groups
 * 2: normal word character
 * >2: multi-byte word character.
 */
static int get_mouse_class(char_u *p)
{
  int c;

  if (has_mbyte && MB_BYTE2LEN(p[0]) > 1)
    return mb_get_class(p);

  c = *p;
  if (c == ' ' || c == '\t')
    return 0;

  if (vim_iswordc(c))
    return 2;

  /*
   * There are a few special cases where we want certain combinations of
   * characters to be considered as a single word.  These are things like
   * "->", "/ *", "*=", "+=", "&=", "<=", ">=", "!=" etc.  Otherwise, each
   * character is in its own class.
   */
  if (c != NUL && vim_strchr((char_u *)"-+*/%<>&|^!=", c) != NULL)
    return 1;
  return c;
}

/*
 * End Visual mode.
 * This function should ALWAYS be called to end Visual mode, except from
 * do_pending_operator().
 */
void end_visual_mode(void)
{

  VIsual_active = false;
  setmouse();
  mouse_dragging = 0;

  /* Save the current VIsual area for '< and '> marks, and "gv" */
  curbuf->b_visual.vi_mode = VIsual_mode;
  curbuf->b_visual.vi_start = VIsual;
  curbuf->b_visual.vi_end = curwin->w_cursor;
  curbuf->b_visual.vi_curswant = curwin->w_curswant;
  curbuf->b_visual_mode_eval = VIsual_mode;
  if (!virtual_active())
    curwin->w_cursor.coladd = 0;

  may_clear_cmdline();

  adjust_cursor_eol();
}

/*
 * Reset VIsual_active and VIsual_reselect.
 */
void reset_VIsual_and_resel(void)
{
  if (VIsual_active) {
    end_visual_mode();
    redraw_curbuf_later(INVERTED);      /* delete the inversion later */
  }
  VIsual_reselect = false;
}

/*
 * Reset VIsual_active and VIsual_reselect if it's set.
 */
void reset_VIsual(void)
{
  if (VIsual_active) {
    end_visual_mode();
    redraw_curbuf_later(INVERTED);      /* delete the inversion later */
    VIsual_reselect = false;
  }
}

// Check for a balloon-eval special item to include when searching for an
// identifier.  When "dir" is BACKWARD "ptr[-1]" must be valid!
// Returns true if the character at "*ptr" should be included.
// "dir" is FORWARD or BACKWARD, the direction of searching.
// "*colp" is in/decremented if "ptr[-dir]" should also be included.
// "bnp" points to a counter for square brackets.
static bool find_is_eval_item(
    const char_u *const ptr,
    int *const colp,
    int *const bnp,
    const int dir)
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

/*
 * Find the identifier under or to the right of the cursor.
 * "find_type" can have one of three values:
 * FIND_IDENT:   find an identifier (keyword)
 * FIND_STRING:  find any non-white string
 * FIND_IDENT + FIND_STRING: find any non-white string, identifier preferred.
 * FIND_EVAL:	 find text useful for C program debugging
 *
 * There are three steps:
 * 1. Search forward for the start of an identifier/string.  Doesn't move if
 *    already on one.
 * 2. Search backward for the start of this identifier/string.
 *    This doesn't match the real Vi but I like it a little better and it
 *    shouldn't bother anyone.
 * 3. Search forward to the end of this identifier/string.
 *    When FIND_IDENT isn't defined, we backup until a blank.
 *
 * Returns the length of the string, or zero if no string is found.
 * If a string is found, a pointer to the string is put in "*string".  This
 * string is not always NUL terminated.
 */
size_t find_ident_under_cursor(char_u **string, int find_type)
{
  return find_ident_at_pos(curwin, curwin->w_cursor.lnum,
      curwin->w_cursor.col, string, find_type);
}

/*
 * Like find_ident_under_cursor(), but for any window and any position.
 * However: Uses 'iskeyword' from the current window!.
 */
size_t find_ident_at_pos(win_T *wp, linenr_T lnum, colnr_T startcol,
                         char_u **string, int find_type)
{
  char_u      *ptr;
  int col = 0;                      /* init to shut up GCC */
  int i;
  int this_class = 0;
  int prev_class;
  int prevcol;
  int bn = 0;                       // bracket nesting

  /*
   * if i == 0: try to find an identifier
   * if i == 1: try to find any non-white string
   */
  ptr = ml_get_buf(wp->w_buffer, lnum, false);
  for (i = (find_type & FIND_IDENT) ? 0 : 1; i < 2; ++i) {
    /*
     * 1. skip to start of identifier/string
     */
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
    // 2. Back up to start of identifier/string.
    //
    // Remember class of character under cursor.
    if ((find_type & FIND_EVAL) && ptr[col] == ']') {
      this_class = mb_get_class((char_u *)"a");
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

    // If we don't want just any old string, or we've found an
    // identifier, stop searching.
    if (this_class > 2) {
      this_class = 2;
    }
    if (!(find_type & FIND_STRING) || this_class == 2) {
      break;
    }
  }

  if (ptr[col] == NUL || (i == 0 && this_class != 2)) {
    // Didn't find an identifier or string.
    if (find_type & FIND_STRING) {
      EMSG(_("E348: No string under cursor"));
    } else {
      EMSG(_(e_noident));
    }
    return 0;
  }
  ptr += col;
  *string = ptr;

  /*
   * 3. Find the end if the identifier/string.
   */
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

/*
 * Prepare for redo of a normal command.
 */
static void prep_redo_cmd(cmdarg_T *cap)
{
  prep_redo(cap->oap->regname, cap->count0,
      NUL, cap->cmdchar, NUL, NUL, cap->nchar);
}

/*
 * Prepare for redo of any command.
 * Note that only the last argument can be a multi-byte char.
 */
static void prep_redo(int regname, long num, int cmd1, int cmd2, int cmd3, int cmd4, int cmd5)
{
  ResetRedobuff();
  if (regname != 0) {   /* yank from specified buffer */
    AppendCharToRedobuff('"');
    AppendCharToRedobuff(regname);
  }
  if (num)
    AppendNumberToRedobuff(num);

  if (cmd1 != NUL)
    AppendCharToRedobuff(cmd1);
  if (cmd2 != NUL)
    AppendCharToRedobuff(cmd2);
  if (cmd3 != NUL)
    AppendCharToRedobuff(cmd3);
  if (cmd4 != NUL)
    AppendCharToRedobuff(cmd4);
  if (cmd5 != NUL)
    AppendCharToRedobuff(cmd5);
}

/*
 * check for operator active and clear it
 *
 * return true if operator was active
 */
static bool checkclearop(oparg_T *oap)
{
  if (oap->op_type == OP_NOP)
    return false;
  clearopbeep(oap);
  return true;
}

/*
 * Check for operator or Visual active.  Clear active operator.
 *
 * Return true if operator or Visual was active.
 */
static bool checkclearopq(oparg_T *oap)
{
  if (oap->op_type == OP_NOP
      && !VIsual_active
      )
    return false;
  clearopbeep(oap);
  return true;
}

static void clearop(oparg_T *oap)
{
  oap->op_type = OP_NOP;
  oap->regname = 0;
  oap->motion_force = NUL;
  oap->use_reg_one = false;
}

static void clearopbeep(oparg_T *oap)
{
  clearop(oap);
  beep_flush();
}

/*
 * Remove the shift modifier from a special key.
 */
static void unshift_special(cmdarg_T *cap)
{
  switch (cap->cmdchar) {
  case K_S_RIGHT: cap->cmdchar = K_RIGHT; break;
  case K_S_LEFT:  cap->cmdchar = K_LEFT; break;
  case K_S_UP:    cap->cmdchar = K_UP; break;
  case K_S_DOWN:  cap->cmdchar = K_DOWN; break;
  case K_S_HOME:  cap->cmdchar = K_HOME; break;
  case K_S_END:   cap->cmdchar = K_END; break;
  }
  cap->cmdchar = simplify_key(cap->cmdchar, &mod_mask);
}

/// If the mode is currently displayed clear the command line or update the
/// command displayed.
static void may_clear_cmdline(void)
{
  if (mode_displayed) {
    // unshow visual mode later
    clear_cmdline = true;
  } else {
    clear_showcmd();
  }
}

// Routines for displaying a partly typed command
# define SHOWCMD_BUFLEN SHOWCMD_COLS + 1 + 30
static char_u showcmd_buf[SHOWCMD_BUFLEN];
static char_u old_showcmd_buf[SHOWCMD_BUFLEN];    /* For push_showcmd() */
static bool showcmd_is_clear = true;
static bool showcmd_visual = false;


void clear_showcmd(void)
{
  if (!p_sc)
    return;

  if (VIsual_active && !char_avail()) {
    int cursor_bot = lt(VIsual, curwin->w_cursor);
    long lines;
    colnr_T leftcol, rightcol;
    linenr_T top, bot;

    /* Show the size of the Visual area. */
    if (cursor_bot) {
      top = VIsual.lnum;
      bot = curwin->w_cursor.lnum;
    } else {
      top = curwin->w_cursor.lnum;
      bot = VIsual.lnum;
    }
    // Include closed folds as a whole.
    (void)hasFolding(top, &top, NULL);
    (void)hasFolding(bot, NULL, &bot);
    lines = bot - top + 1;

    if (VIsual_mode == Ctrl_V) {
      char_u *saved_sbr = p_sbr;

      /* Make 'sbr' empty for a moment to get the correct size. */
      p_sbr = empty_option;
      getvcols(curwin, &curwin->w_cursor, &VIsual, &leftcol, &rightcol);
      p_sbr = saved_sbr;
      sprintf((char *)showcmd_buf, "%" PRId64 "x%" PRId64,
              (int64_t)lines, (int64_t)(rightcol - leftcol + 1));
    } else if (VIsual_mode == 'V' || VIsual.lnum != curwin->w_cursor.lnum)
      sprintf((char *)showcmd_buf, "%" PRId64, (int64_t)lines);
    else {
      char_u  *s, *e;
      int l;
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
        l = (*mb_ptr2len)(s);
        if (l == 0) {
          ++bytes;
          ++chars;
          break;            /* end of line */
        }
        bytes += l;
        ++chars;
        s += l;
      }
      if (bytes == chars)
        sprintf((char *)showcmd_buf, "%d", chars);
      else
        sprintf((char *)showcmd_buf, "%d-%d", chars, bytes);
    }
    showcmd_buf[SHOWCMD_COLS] = NUL;            /* truncate */
    showcmd_visual = true;
  } else {
    showcmd_buf[0] = NUL;
    showcmd_visual = false;

    /* Don't actually display something if there is nothing to clear. */
    if (showcmd_is_clear)
      return;
  }

  display_showcmd();
}

/*
 * Add 'c' to string of shown command chars.
 * Return true if output has been written (and setcursor() has been called).
 */
bool add_to_showcmd(int c)
{
  char_u      *p;
  int i;
  static int ignore[] =
  {
    K_IGNORE,
    K_LEFTMOUSE, K_LEFTDRAG, K_LEFTRELEASE,
    K_MIDDLEMOUSE, K_MIDDLEDRAG, K_MIDDLERELEASE,
    K_RIGHTMOUSE, K_RIGHTDRAG, K_RIGHTRELEASE,
    K_MOUSEDOWN, K_MOUSEUP, K_MOUSELEFT, K_MOUSERIGHT,
    K_X1MOUSE, K_X1DRAG, K_X1RELEASE, K_X2MOUSE, K_X2DRAG, K_X2RELEASE,
    K_EVENT,
    0
  };

  if (!p_sc || msg_silent != 0)
    return false;

  if (showcmd_visual) {
    showcmd_buf[0] = NUL;
    showcmd_visual = false;
  }

  /* Ignore keys that are scrollbar updates and mouse clicks */
  if (IS_SPECIAL(c))
    for (i = 0; ignore[i] != 0; ++i)
      if (ignore[i] == c)
        return false;

  p = transchar(c);
  if (*p == ' ')
    STRCPY(p, "<20>");
  size_t old_len = STRLEN(showcmd_buf);
  size_t extra_len = STRLEN(p);
  if (old_len + extra_len > SHOWCMD_COLS) {
    size_t overflow = old_len + extra_len - SHOWCMD_COLS;
    memmove(showcmd_buf, showcmd_buf + overflow, old_len - overflow + 1);
  }
  STRCAT(showcmd_buf, p);

  if (char_avail())
    return false;

  display_showcmd();

  return true;
}

void add_to_showcmd_c(int c)
{
  if (!add_to_showcmd(c))
    setcursor();
}

/*
 * Delete 'len' characters from the end of the shown command.
 */
static void del_from_showcmd(int len)
{
  int old_len;

  if (!p_sc)
    return;

  old_len = (int)STRLEN(showcmd_buf);
  if (len > old_len)
    len = old_len;
  showcmd_buf[old_len - len] = NUL;

  if (!char_avail())
    display_showcmd();
}

/*
 * push_showcmd() and pop_showcmd() are used when waiting for the user to type
 * something and there is a partial mapping.
 */
void push_showcmd(void)
{
  if (p_sc)
    STRCPY(old_showcmd_buf, showcmd_buf);
}

void pop_showcmd(void)
{
  if (!p_sc)
    return;

  STRCPY(showcmd_buf, old_showcmd_buf);

  display_showcmd();
}

static void display_showcmd(void)
{
  int len;

  len = (int)STRLEN(showcmd_buf);
  if (len == 0) {
    showcmd_is_clear = true;
  } else {
    grid_puts(&default_grid, showcmd_buf, (int)Rows - 1, sc_col, 0);
    showcmd_is_clear = false;
  }

  /*
   * clear the rest of an old message by outputting up to SHOWCMD_COLS
   * spaces
   */
  grid_puts(&default_grid, (char_u *)"          " + len, (int)Rows - 1,
            sc_col + len, 0);

  setcursor();              /* put cursor back where it belongs */
}

/*
 * When "check" is false, prepare for commands that scroll the window.
 * When "check" is true, take care of scroll-binding after the window has
 * scrolled.  Called from normal_cmd() and edit().
 */
void do_check_scrollbind(bool check)
{
  static win_T        *old_curwin = NULL;
  static linenr_T old_topline = 0;
  static int old_topfill = 0;
  static buf_T        *old_buf = NULL;
  static colnr_T old_leftcol = 0;

  if (check && curwin->w_p_scb) {
    /* If a ":syncbind" command was just used, don't scroll, only reset
     * the values. */
    if (did_syncbind)
      did_syncbind = false;
    else if (curwin == old_curwin) {
      /*
       * Synchronize other windows, as necessary according to
       * 'scrollbind'.  Don't do this after an ":edit" command, except
       * when 'diff' is set.
       */
      if ((curwin->w_buffer == old_buf
           || curwin->w_p_diff
           )
          && (curwin->w_topline != old_topline
              || curwin->w_topfill != old_topfill
              || curwin->w_leftcol != old_leftcol)) {
        check_scrollbind(curwin->w_topline - old_topline,
            (long)(curwin->w_leftcol - old_leftcol));
      }
    } else if (vim_strchr(p_sbo, 'j')) { /* jump flag set in 'scrollopt' */
      /*
       * When switching between windows, make sure that the relative
       * vertical offset is valid for the new window.  The relative
       * offset is invalid whenever another 'scrollbind' window has
       * scrolled to a point that would force the current window to
       * scroll past the beginning or end of its buffer.  When the
       * resync is performed, some of the other 'scrollbind' windows may
       * need to jump so that the current window's relative position is
       * visible on-screen.
       */
      check_scrollbind(curwin->w_topline - curwin->w_scbind_pos, 0L);
    }
    curwin->w_scbind_pos = curwin->w_topline;
  }

  old_curwin = curwin;
  old_topline = curwin->w_topline;
  old_topfill = curwin->w_topfill;
  old_buf = curwin->w_buffer;
  old_leftcol = curwin->w_leftcol;
}

/*
 * Synchronize any windows that have "scrollbind" set, based on the
 * number of rows by which the current window has changed
 * (1998-11-02 16:21:01  R. Edward Ralston <eralston@computer.org>)
 */
void check_scrollbind(linenr_T topline_diff, long leftcol_diff)
{
  bool want_ver;
  bool want_hor;
  win_T       *old_curwin = curwin;
  buf_T       *old_curbuf = curbuf;
  int old_VIsual_select = VIsual_select;
  int old_VIsual_active = VIsual_active;
  colnr_T tgt_leftcol = curwin->w_leftcol;
  long topline;
  long y;

  /*
   * check 'scrollopt' string for vertical and horizontal scroll options
   */
  want_ver = (vim_strchr(p_sbo, 'v') && topline_diff != 0);
  want_ver |= old_curwin->w_p_diff;
  want_hor = (vim_strchr(p_sbo, 'h') && (leftcol_diff || topline_diff != 0));

  /*
   * loop through the scrollbound windows and scroll accordingly
   */
  VIsual_select = VIsual_active = 0;
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    curwin = wp;
    curbuf = curwin->w_buffer;
    /* skip original window  and windows with 'noscrollbind' */
    if (curwin == old_curwin || !curwin->w_p_scb) {
      continue;
    }
    /*
     * do the vertical scroll
     */
    if (want_ver) {
      if (old_curwin->w_p_diff && curwin->w_p_diff) {
        diff_set_topline(old_curwin, curwin);
      } else {
        curwin->w_scbind_pos += topline_diff;
        topline = curwin->w_scbind_pos;
        if (topline > curbuf->b_ml.ml_line_count)
          topline = curbuf->b_ml.ml_line_count;
        if (topline < 1)
          topline = 1;

        y = topline - curwin->w_topline;
        if (y > 0)
          scrollup(y, false);
        else
          scrolldown(-y, false);
      }

      redraw_later(VALID);
      cursor_correct();
      curwin->w_redr_status = true;
    }

    /*
     * do the horizontal scroll
     */
    if (want_hor && curwin->w_leftcol != tgt_leftcol) {
      curwin->w_leftcol = tgt_leftcol;
      leftcol_changed();
    }
  }

  /*
   * reset current-window
   */
  VIsual_select = old_VIsual_select;
  VIsual_active = old_VIsual_active;
  curwin = old_curwin;
  curbuf = old_curbuf;
}

/*
 * Command character that's ignored.
 * Used for CTRL-Q and CTRL-S to avoid problems with terminals that use
 * xon/xoff.
 */
static void nv_ignore(cmdarg_T *cap)
{
  cap->retval |= CA_COMMAND_BUSY;       /* don't call edit() now */
}

/*
 * Command character that doesn't do anything, but unlike nv_ignore() does
 * start edit().  Used for "startinsert" executed while starting up.
 */
static void nv_nop(cmdarg_T *cap)
{
}

/*
 * Command character doesn't exist.
 */
static void nv_error(cmdarg_T *cap)
{
  clearopbeep(cap->oap);
}

/*
 * <Help> and <F1> commands.
 */
static void nv_help(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap))
    ex_help(NULL);
}

/*
 * CTRL-A and CTRL-X: Add or subtract from letter or number under cursor.
 */
static void nv_addsub(cmdarg_T *cap)
{
  if (!VIsual_active && cap->oap->op_type == OP_NOP) {
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

/*
 * CTRL-F, CTRL-B, etc: Scroll page up or down.
 */
static void nv_page(cmdarg_T *cap)
{
  if (!checkclearop(cap->oap)) {
    if (mod_mask & MOD_MASK_CTRL) {
      /* <C-PageUp>: tab page back; <C-PageDown>: tab page forward */
      if (cap->arg == BACKWARD)
        goto_tabpage(-(int)cap->count1);
      else
        goto_tabpage((int)cap->count0);
    } else
      (void)onepage(cap->arg, cap->count1);
  }
}

/*
 * Implementation of "gd" and "gD" command.
 */
static void
nv_gd (
    oparg_T *oap,
    int nchar,
    int thisblock                  /* 1 for "1gd" and "1gD" */
)
{
  size_t len;
  char_u *ptr;
  if ((len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0
      || !find_decl(ptr, len, nchar == 'd', thisblock, SEARCH_START)) {
    clearopbeep(oap);
  } else if ((fdo_flags & FDO_SEARCH) && KeyTyped && oap->op_type == OP_NOP) {
    foldOpenCursor();
  }
}

// Return true if line[offset] is not inside a C-style comment or string, false
// otherwise.
static bool is_ident(char_u *line, int offset)
{
  bool incomment = false;
  int instring = 0;
  int prev = 0;

  for (int i = 0; i < offset && line[i] != NUL; i++) {
    if (instring != 0) {
      if (prev != '\\' && line[i] == instring) {
        instring = 0;
      }
    } else if ((line[i] == '"' || line[i] == '\'') && !incomment) {
      instring = line[i];
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

    prev = line[i];
  }

  return incomment == false && instring == 0;
}

/*
 * Search for variable declaration of "ptr[len]".
 * When "locally" is true in the current function ("gd"), otherwise in the
 * current file ("gD").
 * When "thisblock" is true check the {} block scope.
 * Return fail when not found.
 */
bool
find_decl (
    char_u *ptr,
    size_t len,
    bool locally,
    bool thisblock,
    int flags_arg                  // flags passed to searchit()
)
{
  char_u      *pat;
  pos_T old_pos;
  pos_T par_pos;
  pos_T found_pos;
  bool t;
  bool save_p_ws;
  bool save_p_scs;
  bool retval = true;
  bool incll;
  int searchflags = flags_arg;
  bool valid;

  pat = xmalloc(len + 7);

  /* Put "\V" before the pattern to avoid that the special meaning of "."
   * and "~" causes trouble. */
  assert(len <= INT_MAX);
  sprintf((char *)pat, vim_iswordp(ptr) ? "\\V\\<%.*s\\>" : "\\V%.*s",
          (int)len, ptr);
  old_pos = curwin->w_cursor;
  save_p_ws = p_ws;
  save_p_scs = p_scs;
  p_ws = false;         /* don't wrap around end of file now */
  p_scs = false;        /* don't switch ignorecase off now */

  /*
   * With "gD" go to line 1.
   * With "gd" Search back for the start of the current function, then go
   * back until a blank line.  If this fails go to line 1.
   */
  if (!locally || !findpar(&incll, BACKWARD, 1L, '{', false)) {
    setpcmark();                        /* Set in findpar() otherwise */
    curwin->w_cursor.lnum = 1;
    par_pos = curwin->w_cursor;
  } else {
    par_pos = curwin->w_cursor;
    while (curwin->w_cursor.lnum > 1
           && *skipwhite(get_cursor_line_ptr()) != NUL)
      --curwin->w_cursor.lnum;
  }
  curwin->w_cursor.col = 0;

  /* Search forward for the identifier, ignore comment lines. */
  clearpos(&found_pos);
  for (;; ) {
    valid = false;
    t = searchit(curwin, curbuf, &curwin->w_cursor, FORWARD,
        pat, 1L, searchflags, RE_LAST, (linenr_T)0, NULL);
    if (curwin->w_cursor.lnum >= old_pos.lnum)
      t = false;         /* match after start is failure too */

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
      /* If we previously found a valid position, use it. */
      if (found_pos.lnum != 0) {
        curwin->w_cursor = found_pos;
        t = true;
      }
      break;
    }
    if (get_leader_len(get_cursor_line_ptr(), NULL, false, true) > 0) {
      /* Ignore this line, continue at start of next line. */
      ++curwin->w_cursor.lnum;
      curwin->w_cursor.col = 0;
      continue;
    }
    valid = is_ident(get_cursor_line_ptr(), curwin->w_cursor.col);

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
    /* "n" searches forward now */
    reset_search_dir();
  }

  xfree(pat);
  p_ws = save_p_ws;
  p_scs = save_p_scs;

  return retval;
}

/*
 * Move 'dist' lines in direction 'dir', counting lines by *screen*
 * lines rather than lines in the file.
 * 'dist' must be positive.
 *
 * Return true if able to move cursor, false otherwise.
 */
static bool nv_screengo(oparg_T *oap, int dir, long dist)
{
  int linelen = linetabsize(get_cursor_line_ptr());
  bool retval = true;
  bool atend = false;
  int n;
  int col_off1;                 /* margin offset for first screen line */
  int col_off2;                 /* margin offset for wrapped screen line */
  int width1;                   /* text width for first screen line */
  int width2;                   /* test width for wrapped screen line */

  oap->motion_type = kMTCharWise;
  oap->inclusive = (curwin->w_curswant == MAXCOL);

  col_off1 = curwin_col_off();
  col_off2 = col_off1 - curwin_col_off2();
  width1 = curwin->w_grid.Columns - col_off1;
  width2 = curwin->w_grid.Columns - col_off2;

  if (width2 == 0) {
    width2 = 1;  // Avoid divide by zero.
  }

  if (curwin->w_grid.Columns != 0) {
    // Instead of sticking at the last character of the buffer line we
    // try to stick in the last column of the screen.
    if (curwin->w_curswant == MAXCOL) {
      atend = true;
      validate_virtcol();
      if (width1 <= 0)
        curwin->w_curswant = 0;
      else {
        curwin->w_curswant = width1 - 1;
        if (curwin->w_virtcol > curwin->w_curswant)
          curwin->w_curswant += ((curwin->w_virtcol
                                  - curwin->w_curswant -
                                  1) / width2 + 1) * width2;
      }
    } else {
      if (linelen > width1)
        n = ((linelen - width1 - 1) / width2 + 1) * width2 + width1;
      else
        n = width1;
      if (curwin->w_curswant > (colnr_T)n + 1)
        curwin->w_curswant -= ((curwin->w_curswant - n) / width2 + 1)
                              * width2;
    }

    while (dist--) {
      if (dir == BACKWARD) {
        if ((long)curwin->w_curswant >= width2)
          /* move back within line */
          curwin->w_curswant -= width2;
        else {
          /* to previous line */
          if (curwin->w_cursor.lnum == 1) {
            retval = false;
            break;
          }
          --curwin->w_cursor.lnum;
          /* Move to the start of a closed fold.  Don't do that when
           * 'foldopen' contains "all": it will open in a moment. */
          if (!(fdo_flags & FDO_ALL))
            (void)hasFolding(curwin->w_cursor.lnum,
                &curwin->w_cursor.lnum, NULL);
          linelen = linetabsize(get_cursor_line_ptr());
          if (linelen > width1) {
            int w = (((linelen - width1 - 1) / width2) + 1) * width2;
            assert(curwin->w_curswant <= INT_MAX - w);
            curwin->w_curswant += w;
          }
        }
      } else { /* dir == FORWARD */
        if (linelen > width1)
          n = ((linelen - width1 - 1) / width2 + 1) * width2 + width1;
        else
          n = width1;
        if (curwin->w_curswant + width2 < (colnr_T)n)
          /* move forward within line */
          curwin->w_curswant += width2;
        else {
          /* to next line */
          /* Move to the end of a closed fold. */
          (void)hasFolding(curwin->w_cursor.lnum, NULL,
              &curwin->w_cursor.lnum);
          if (curwin->w_cursor.lnum == curbuf->b_ml.ml_line_count) {
            retval = false;
            break;
          }
          curwin->w_cursor.lnum++;
          curwin->w_curswant %= width2;
          linelen = linetabsize(get_cursor_line_ptr());
        }
      }
    }
  }

  if (virtual_active() && atend)
    coladvance(MAXCOL);
  else
    coladvance(curwin->w_curswant);

  if (curwin->w_cursor.col > 0 && curwin->w_p_wrap) {
    /*
     * Check for landing on a character that got split at the end of the
     * last line.  We want to advance a screenline, not end up in the same
     * screenline or move two screenlines.
     */
    validate_virtcol();
    colnr_T virtcol = curwin->w_virtcol;
    if (virtcol > (colnr_T)width1 && *p_sbr != NUL)
        virtcol -= vim_strsize(p_sbr);

    if (virtcol > curwin->w_curswant
        && (curwin->w_curswant < (colnr_T)width1
            ? (curwin->w_curswant > (colnr_T)width1 / 2)
            : ((curwin->w_curswant - width1) % width2
               > (colnr_T)width2 / 2)))
      --curwin->w_cursor.col;
  }

  if (atend)
    curwin->w_curswant = MAXCOL;            /* stick in the last column */

  return retval;
}

/*
 * Mouse scroll wheel: Default action is to scroll three lines, or one page
 * when Shift or Ctrl is used.
 * K_MOUSEUP (cap->arg == 1) or K_MOUSEDOWN (cap->arg == 0) or
 * K_MOUSELEFT (cap->arg == -1) or K_MOUSERIGHT (cap->arg == -2)
 */
static void nv_mousescroll(cmdarg_T *cap)
{
  win_T *old_curwin = curwin;

  if (mouse_row >= 0 && mouse_col >= 0) {
    int row, col;

    row = mouse_row;
    col = mouse_col;

    // find the window at the pointer coordinates
    win_T *const wp = mouse_find_win(&row, &col);
    if (wp == NULL) {
      return;
    }
    curwin = wp;
    curbuf = curwin->w_buffer;
  }

  if (cap->arg == MSCR_UP || cap->arg == MSCR_DOWN) {
    if (mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL)) {
      (void)onepage(cap->arg ? FORWARD : BACKWARD, 1L);
    } else {
      cap->count1 = 3;
      cap->count0 = 3;
      nv_scroll_line(cap);
    }
  } else {
    mouse_scroll_horiz(cap->arg);
  }

  curwin->w_redr_status = true;

  curwin = old_curwin;
  curbuf = curwin->w_buffer;
}

/*
 * Mouse clicks and drags.
 */
static void nv_mouse(cmdarg_T *cap)
{
  (void)do_mouse(cap->oap, cap->cmdchar, BACKWARD, cap->count1, 0);
}

/*
 * Handle CTRL-E and CTRL-Y commands: scroll a line up or down.
 * cap->arg must be true for CTRL-E.
 */
static void nv_scroll_line(cmdarg_T *cap)
{
  if (!checkclearop(cap->oap))
    scroll_redraw(cap->arg, cap->count1);
}

/*
 * Scroll "count" lines up or down, and redraw.
 */
void scroll_redraw(int up, long count)
{
  linenr_T prev_topline = curwin->w_topline;
  int prev_topfill = curwin->w_topfill;
  linenr_T prev_lnum = curwin->w_cursor.lnum;

  if (up)
    scrollup(count, true);
  else
    scrolldown(count, true);
  if (p_so) {
    /* Adjust the cursor position for 'scrolloff'.  Mark w_topline as
     * valid, otherwise the screen jumps back at the end of the file. */
    cursor_correct();
    check_cursor_moved(curwin);
    curwin->w_valid |= VALID_TOPLINE;

    /* If moved back to where we were, at least move the cursor, otherwise
     * we get stuck at one position.  Don't move the cursor up if the
     * first line of the buffer is already on the screen */
    while (curwin->w_topline == prev_topline
           && curwin->w_topfill == prev_topfill
           ) {
      if (up) {
        if (curwin->w_cursor.lnum > prev_lnum
            || cursor_down(1L, false) == false)
          break;
      } else {
        if (curwin->w_cursor.lnum < prev_lnum
            || prev_topline == 1L
            || cursor_up(1L, false) == false)
          break;
      }
      /* Mark w_topline as valid, otherwise the screen jumps back at the
       * end of the file. */
      check_cursor_moved(curwin);
      curwin->w_valid |= VALID_TOPLINE;
    }
  }
  if (curwin->w_cursor.lnum != prev_lnum)
    coladvance(curwin->w_curswant);
  redraw_later(VALID);
}

/*
 * Commands that start with "z".
 */
static void nv_zet(cmdarg_T *cap)
{
  int n;
  colnr_T col;
  int nchar = cap->nchar;
  long old_fdl = curwin->w_p_fdl;
  int old_fen = curwin->w_p_fen;
  bool undo = false;

  assert(p_siso <= INT_MAX);
  int l_p_siso = (int)p_siso;

  if (ascii_isdigit(nchar)) {
    /*
     * "z123{nchar}": edit the count before obtaining {nchar}
     */
    if (checkclearop(cap->oap))
      return;
    n = nchar - '0';
    for (;; ) {
      no_mapping++;
      nchar = plain_vgetc();
      LANGMAP_ADJUST(nchar, true);
      no_mapping--;
      (void)add_to_showcmd(nchar);
      if (nchar == K_DEL || nchar == K_KDEL)
        n /= 10;
      else if (ascii_isdigit(nchar))
        n = n * 10 + (nchar - '0');
      else if (nchar == CAR) {
        win_setheight(n);
        break;
      } else if (nchar == 'l'
                 || nchar == 'h'
                 || nchar == K_LEFT
                 || nchar == K_RIGHT) {
        cap->count1 = n ? n * cap->count1 : cap->count1;
        goto dozet;
      } else {
        clearopbeep(cap->oap);
        break;
      }
    }
    cap->oap->op_type = OP_NOP;
    return;
  }

dozet:
  // "zf" and "zF" are always an operator, "zd", "zo", "zO", "zc"
  // and "zC" only in Visual mode.  "zj" and "zk" are motion
  // commands. */
  if (cap->nchar != 'f' && cap->nchar != 'F'
      && !(VIsual_active && vim_strchr((char_u *)"dcCoO", cap->nchar))
      && cap->nchar != 'j' && cap->nchar != 'k'
      && checkclearop(cap->oap)) {
    return;
  }

  /*
   * For "z+", "z<CR>", "zt", "z.", "zz", "z^", "z-", "zb":
   * If line number given, set cursor.
   */
  if ((vim_strchr((char_u *)"+\r\nt.z^-b", nchar) != NULL)
      && cap->count0
      && cap->count0 != curwin->w_cursor.lnum) {
    setpcmark();
    if (cap->count0 > curbuf->b_ml.ml_line_count)
      curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
    else
      curwin->w_cursor.lnum = cap->count0;
    check_cursor_col();
  }

  switch (nchar) {
  /* "z+", "z<CR>" and "zt": put cursor at top of screen */
  case '+':
    if (cap->count0 == 0) {
      /* No count given: put cursor at the line below screen */
      validate_botline();               /* make sure w_botline is valid */
      if (curwin->w_botline > curbuf->b_ml.ml_line_count)
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      else
        curwin->w_cursor.lnum = curwin->w_botline;
    }
    FALLTHROUGH;
  case NL:
  case CAR:
  case K_KENTER:
    beginline(BL_WHITE | BL_FIX);
    FALLTHROUGH;

  case 't':   scroll_cursor_top(0, true);
    redraw_later(VALID);
    set_fraction(curwin);
    break;

  /* "z." and "zz": put cursor in middle of screen */
  case '.':   beginline(BL_WHITE | BL_FIX);
  FALLTHROUGH;

  case 'z':   scroll_cursor_halfway(true);
    redraw_later(VALID);
    set_fraction(curwin);
    break;

  /* "z^", "z-" and "zb": put cursor at bottom of screen */
  case '^':     /* Strange Vi behavior: <count>z^ finds line at top of window
                 * when <count> is at bottom of window, and puts that one at
                 * bottom of window. */
    if (cap->count0 != 0) {
      scroll_cursor_bot(0, true);
      curwin->w_cursor.lnum = curwin->w_topline;
    } else if (curwin->w_topline == 1)
      curwin->w_cursor.lnum = 1;
    else
      curwin->w_cursor.lnum = curwin->w_topline - 1;
    FALLTHROUGH;
  case '-':
    beginline(BL_WHITE | BL_FIX);
    FALLTHROUGH;

  case 'b':   scroll_cursor_bot(0, true);
    redraw_later(VALID);
    set_fraction(curwin);
    break;

  /* "zH" - scroll screen right half-page */
  case 'H':
    cap->count1 *= curwin->w_grid.Columns / 2;
    FALLTHROUGH;

  /* "zh" - scroll screen to the right */
  case 'h':
  case K_LEFT:
    if (!curwin->w_p_wrap) {
      if ((colnr_T)cap->count1 > curwin->w_leftcol)
        curwin->w_leftcol = 0;
      else
        curwin->w_leftcol -= (colnr_T)cap->count1;
      leftcol_changed();
    }
    break;

  // "zL" - scroll screen left half-page
  case 'L':   cap->count1 *= curwin->w_grid.Columns / 2;
    FALLTHROUGH;

  /* "zl" - scroll screen to the left */
  case 'l':
  case K_RIGHT:
    if (!curwin->w_p_wrap) {
      /* scroll the window left */
      curwin->w_leftcol += (colnr_T)cap->count1;
      leftcol_changed();
    }
    break;

  /* "zs" - scroll screen, cursor at the start */
  case 's':   if (!curwin->w_p_wrap) {
      if (hasFolding(curwin->w_cursor.lnum, NULL, NULL))
        col = 0;                        /* like the cursor is in col 0 */
      else
        getvcol(curwin, &curwin->w_cursor, &col, NULL, NULL);
      if (col > l_p_siso)
        col -= l_p_siso;
      else
        col = 0;
      if (curwin->w_leftcol != col) {
        curwin->w_leftcol = col;
        redraw_later(NOT_VALID);
      }
  }
    break;

  /* "ze" - scroll screen, cursor at the end */
  case 'e':   if (!curwin->w_p_wrap) {
      if (hasFolding(curwin->w_cursor.lnum, NULL, NULL))
        col = 0;                        /* like the cursor is in col 0 */
      else
        getvcol(curwin, &curwin->w_cursor, NULL, NULL, &col);
      n = curwin->w_grid.Columns - curwin_col_off();
      if (col + l_p_siso < n) {
        col = 0;
      } else {
        col = col + l_p_siso - n + 1;
      }
      if (curwin->w_leftcol != col) {
        curwin->w_leftcol = col;
        redraw_later(NOT_VALID);
      }
  }
    break;

  /* "zF": create fold command */
  /* "zf": create fold operator */
  case 'F':
  case 'f':   if (foldManualAllowed(true)) {
      cap->nchar = 'f';
      nv_operator(cap);
      curwin->w_p_fen = true;

      /* "zF" is like "zfzf" */
      if (nchar == 'F' && cap->oap->op_type == OP_FOLD) {
        nv_operator(cap);
        finish_op = true;
      }
  } else
      clearopbeep(cap->oap);
    break;

  /* "zd": delete fold at cursor */
  /* "zD": delete fold at cursor recursively */
  case 'd':
  case 'D':   if (foldManualAllowed(false)) {
      if (VIsual_active)
        nv_operator(cap);
      else
        deleteFold(curwin->w_cursor.lnum,
            curwin->w_cursor.lnum, nchar == 'D', false);
  }
    break;

  /* "zE": erase all folds */
  case 'E':   if (foldmethodIsManual(curwin)) {
      clearFolding(curwin);
      changed_window_setting();
  } else if (foldmethodIsMarker(curwin))
      deleteFold((linenr_T)1, curbuf->b_ml.ml_line_count,
          true, false);
    else
      EMSG(_("E352: Cannot erase folds with current 'foldmethod'"));
    break;

  /* "zn": fold none: reset 'foldenable' */
  case 'n':   curwin->w_p_fen = false;
    break;

  /* "zN": fold Normal: set 'foldenable' */
  case 'N':   curwin->w_p_fen = true;
    break;

  /* "zi": invert folding: toggle 'foldenable' */
  case 'i':   curwin->w_p_fen = !curwin->w_p_fen;
    break;

  /* "za": open closed fold or close open fold at cursor */
  case 'a':   if (hasFolding(curwin->w_cursor.lnum, NULL, NULL))
      openFold(curwin->w_cursor.lnum, cap->count1);
    else {
      closeFold(curwin->w_cursor.lnum, cap->count1);
      curwin->w_p_fen = true;
    }
    break;

  /* "zA": open fold at cursor recursively */
  case 'A':   if (hasFolding(curwin->w_cursor.lnum, NULL, NULL))
      openFoldRecurse(curwin->w_cursor.lnum);
    else {
      closeFoldRecurse(curwin->w_cursor.lnum);
      curwin->w_p_fen = true;
    }
    break;

  /* "zo": open fold at cursor or Visual area */
  case 'o':   if (VIsual_active)
      nv_operator(cap);
    else
      openFold(curwin->w_cursor.lnum, cap->count1);
    break;

  /* "zO": open fold recursively */
  case 'O':   if (VIsual_active)
      nv_operator(cap);
    else
      openFoldRecurse(curwin->w_cursor.lnum);
    break;

  /* "zc": close fold at cursor or Visual area */
  case 'c':   if (VIsual_active)
      nv_operator(cap);
    else
      closeFold(curwin->w_cursor.lnum, cap->count1);
    curwin->w_p_fen = true;
    break;

  /* "zC": close fold recursively */
  case 'C':   if (VIsual_active)
      nv_operator(cap);
    else
      closeFoldRecurse(curwin->w_cursor.lnum);
    curwin->w_p_fen = true;
    break;

  /* "zv": open folds at the cursor */
  case 'v':   foldOpenCursor();
    break;

  /* "zx": re-apply 'foldlevel' and open folds at the cursor */
  case 'x':   curwin->w_p_fen = true;
    curwin->w_foldinvalid = true;               /* recompute folds */
    newFoldLevel();                             /* update right now */
    foldOpenCursor();
    break;

  /* "zX": undo manual opens/closes, re-apply 'foldlevel' */
  case 'X':   curwin->w_p_fen = true;
    curwin->w_foldinvalid = true;               /* recompute folds */
    old_fdl = -1;                               /* force an update */
    break;

  /* "zm": fold more */
  case 'm':
    if (curwin->w_p_fdl > 0) {
      curwin->w_p_fdl -= cap->count1;
      if (curwin->w_p_fdl < 0) {
        curwin->w_p_fdl = 0;
      }
    }
    old_fdl = -1;                       /* force an update */
    curwin->w_p_fen = true;
    break;

  /* "zM": close all folds */
  case 'M':   curwin->w_p_fdl = 0;
    old_fdl = -1;                       /* force an update */
    curwin->w_p_fen = true;
    break;

  /* "zr": reduce folding */
  case 'r':
    curwin->w_p_fdl += cap->count1;
    {
      int d = getDeepestNesting();
      if (curwin->w_p_fdl >= d) {
        curwin->w_p_fdl = d;
      }
    }
    break;

  /* "zR": open all folds */
  case 'R':   curwin->w_p_fdl = getDeepestNesting();
    old_fdl = -1;                       /* force an update */
    break;

  case 'j':     /* "zj" move to next fold downwards */
  case 'k':     /* "zk" move to next fold upwards */
    if (foldMoveTo(true, nchar == 'j' ? FORWARD : BACKWARD,
            cap->count1) == false)
      clearopbeep(cap->oap);
    break;


  case 'u':     // "zug" and "zuw": undo "zg" and "zw"
    no_mapping++;
    nchar = plain_vgetc();
    LANGMAP_ADJUST(nchar, true);
    no_mapping--;
    (void)add_to_showcmd(nchar);
    if (vim_strchr((char_u *)"gGwW", nchar) == NULL) {
      clearopbeep(cap->oap);
      break;
    }
    undo = true;
    FALLTHROUGH;

  case 'g':     /* "zg": add good word to word list */
  case 'w':     /* "zw": add wrong word to word list */
  case 'G':     /* "zG": add good word to temp word list */
  case 'W':     /* "zW": add wrong word to temp word list */
  {
    char_u  *ptr = NULL;
    size_t len;

    if (checkclearop(cap->oap))
      break;
    if (VIsual_active && !get_visual_text(cap, &ptr, &len))
      return;
    if (ptr == NULL) {
      pos_T pos = curwin->w_cursor;

      /* Find bad word under the cursor.  When 'spell' is
       * off this fails and find_ident_under_cursor() is
       * used below. */
      emsg_off++;
      len = spell_move_to(curwin, FORWARD, true, true, NULL);
      emsg_off--;
      if (len != 0 && curwin->w_cursor.col <= pos.col)
        ptr = ml_get_pos(&curwin->w_cursor);
      curwin->w_cursor = pos;
    }

    if (ptr == NULL && (len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0)
      return;
    assert(len <= INT_MAX);
    spell_add_word(ptr, (int)len, nchar == 'w' || nchar == 'W',
                   (nchar == 'G' || nchar == 'W') ? 0 : (int)cap->count1,
                   undo);
  }
  break;

  case '=':     /* "z=": suggestions for a badly spelled word  */
    if (!checkclearop(cap->oap))
      spell_suggest((int)cap->count0);
    break;

  default:    clearopbeep(cap->oap);
  }

  /* Redraw when 'foldenable' changed */
  if (old_fen != curwin->w_p_fen) {
    if (foldmethodIsDiff(curwin) && curwin->w_p_scb) {
      /* Adjust 'foldenable' in diff-synced windows. */
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        if (wp != curwin && foldmethodIsDiff(wp) && wp->w_p_scb) {
          wp->w_p_fen = curwin->w_p_fen;
          changed_window_setting_win(wp);
        }
      }
    }
    changed_window_setting();
  }

  /* Redraw when 'foldlevel' changed. */
  if (old_fdl != curwin->w_p_fdl)
    newFoldLevel();
}



/*
 * "Q" command.
 */
static void nv_exmode(cmdarg_T *cap)
{
  /*
   * Ignore 'Q' in Visual mode, just give a beep.
   */
  if (VIsual_active) {
    vim_beep(BO_EX);
  } else if (!checkclearop(cap->oap)) {
    do_exmode(false);
  }
}

/// Handle a ":" command and <Cmd>.
static void nv_colon(cmdarg_T *cap)
{
  int old_p_im;
  bool cmd_result;
  bool is_cmdkey = cap->cmdchar == K_COMMAND;

  if (VIsual_active && !is_cmdkey) {
    nv_operator(cap);
  } else {
    if (cap->oap->op_type != OP_NOP) {
      // Using ":" as a movement is characterwise exclusive.
      cap->oap->motion_type = kMTCharWise;
      cap->oap->inclusive = false;
    } else if (cap->count0 && !is_cmdkey) {
      // translate "count:" into ":.,.+(count - 1)"
      stuffcharReadbuff('.');
      if (cap->count0 > 1) {
        stuffReadbuff(",.+");
        stuffnumReadbuff(cap->count0 - 1L);
      }
    }

    /* When typing, don't type below an old message */
    if (KeyTyped)
      compute_cmdrow();

    old_p_im = p_im;

    // get a command line and execute it
    cmd_result = do_cmdline(NULL, is_cmdkey ? getcmdkeycmd : getexline, NULL,
                            cap->oap->op_type != OP_NOP ? DOCMD_KEEPLINE : 0);

    /* If 'insertmode' changed, enter or exit Insert mode */
    if (p_im != old_p_im) {
      if (p_im)
        restart_edit = 'i';
      else
        restart_edit = 0;
    }

    if (cmd_result == false)
      /* The Ex command failed, do not execute the operator. */
      clearop(cap->oap);
    else if (cap->oap->op_type != OP_NOP
             && (cap->oap->start.lnum > curbuf->b_ml.ml_line_count
                 || cap->oap->start.col >
                 (colnr_T)STRLEN(ml_get(cap->oap->start.lnum))
                 || did_emsg
                 ))
      /* The start of the operator has become invalid by the Ex command.
       */
      clearopbeep(cap->oap);
  }
}

/*
 * Handle CTRL-G command.
 */
static void nv_ctrlg(cmdarg_T *cap)
{
  if (VIsual_active) {  /* toggle Selection/Visual mode */
    VIsual_select = !VIsual_select;
    showmode();
  } else if (!checkclearop(cap->oap))
    /* print full name if count given or :cd used */
    fileinfo((int)cap->count0, false, true);
}

/*
 * Handle CTRL-H <Backspace> command.
 */
static void nv_ctrlh(cmdarg_T *cap)
{
  if (VIsual_active && VIsual_select) {
    cap->cmdchar = 'x';         /* BS key behaves like 'x' in Select mode */
    v_visop(cap);
  } else
    nv_left(cap);
}

/*
 * CTRL-L: clear screen and redraw.
 */
static void nv_clear(cmdarg_T *cap)
{
  if (!checkclearop(cap->oap)) {
    /* Clear all syntax states to force resyncing. */
    syn_stack_free_all(curwin->w_s);
    redraw_later(CLEAR);
  }
}

/*
 * CTRL-O: In Select mode: switch to Visual mode for one command.
 * Otherwise: Go to older pcmark.
 */
static void nv_ctrlo(cmdarg_T *cap)
{
  if (VIsual_active && VIsual_select) {
    VIsual_select = false;
    showmode();
    restart_VIsual_select = 2;          /* restart Select mode later */
  } else {
    cap->count1 = -cap->count1;
    nv_pcmark(cap);
  }
}

/*
 * CTRL-^ command, short for ":e #"
 */
static void nv_hat(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap))
    (void)buflist_getfile((int)cap->count0, (linenr_T)0,
        GETF_SETMARK|GETF_ALT, false);
}

/*
 * "Z" commands.
 */
static void nv_Zet(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap)) {
    switch (cap->nchar) {
    /* "ZZ": equivalent to ":x". */
    case 'Z':   do_cmdline_cmd("x");
      break;

    /* "ZQ": equivalent to ":q!" (Elvis compatible). */
    case 'Q':   do_cmdline_cmd("q!");
      break;

    default:    clearopbeep(cap->oap);
    }
  }
}

/*
 * Call nv_ident() as if "c1" was used, with "c2" as next character.
 */
void do_nv_ident(int c1, int c2)
{
  oparg_T oa;
  cmdarg_T ca;

  clear_oparg(&oa);
  memset(&ca, 0, sizeof(ca));
  ca.oap = &oa;
  ca.cmdchar = c1;
  ca.nchar = c2;
  nv_ident(&ca);
}

/*
 * Handle the commands that use the word under the cursor.
 * [g] CTRL-]	:ta to current identifier
 * [g] 'K'	run program for current identifier
 * [g] '*'	/ to current identifier or string
 * [g] '#'	? to current identifier or string
 *  g  ']'	:tselect for current identifier
 */
static void nv_ident(cmdarg_T *cap)
{
  char_u      *ptr = NULL;
  char_u      *p;
  size_t n = 0;                 /* init for GCC */
  int cmdchar;
  bool g_cmd;                   /* "g" command */
  bool tag_cmd = false;
  char_u      *aux_ptr;

  if (cap->cmdchar == 'g') {    /* "g*", "g#", "g]" and "gCTRL-]" */
    cmdchar = cap->nchar;
    g_cmd = true;
  } else {
    cmdchar = cap->cmdchar;
    g_cmd = false;
  }

  if (cmdchar == POUND)         /* the pound sign, '#' for English keyboards */
    cmdchar = '#';

  /*
   * The "]", "CTRL-]" and "K" commands accept an argument in Visual mode.
   */
  if (cmdchar == ']' || cmdchar == Ctrl_RSB || cmdchar == 'K') {
    if (VIsual_active && get_visual_text(cap, &ptr, &n) == false)
      return;
    if (checkclearopq(cap->oap))
      return;
  }

  if (ptr == NULL && (n = find_ident_under_cursor(&ptr,
                                                  ((cmdchar == '*'
                                                    || cmdchar == '#')
                                                   ? FIND_IDENT|FIND_STRING
                                                   : FIND_IDENT))) == 0) {
    clearop(cap->oap);
    return;
  }

  /* Allocate buffer to put the command in.  Inserting backslashes can
   * double the length of the word.  p_kp / curbuf->b_p_kp could be added
   * and some numbers. */
  char_u *kp = *curbuf->b_p_kp == NUL ? p_kp : curbuf->b_p_kp;  // 'keywordprg'
  assert(*kp != NUL);  // option.c:do_set() should default to ":help" if empty.
  bool kp_ex = (*kp == ':');  // 'keywordprg' is an ex command
  bool kp_help = (STRCMP(kp, ":he") == 0 || STRCMP(kp, ":help") == 0);
  if (kp_help && *skipwhite(ptr) == NUL) {
    EMSG(_(e_noident));   // found white space only
    return;
  }
  size_t buf_size = n * 2 + 30 + STRLEN(kp);
  char *buf = xmalloc(buf_size);
  buf[0] = NUL;

  switch (cmdchar) {
  case '*':
  case '#':
    /*
     * Put cursor at start of word, makes search skip the word
     * under the cursor.
     * Call setpcmark() first, so "*``" puts the cursor back where
     * it was.
     */
    setpcmark();
    curwin->w_cursor.col = (colnr_T) (ptr - get_cursor_line_ptr());

    if (!g_cmd && vim_iswordp(ptr))
      STRCPY(buf, "\\<");
    no_smartcase = true;                /* don't use 'smartcase' now */
    break;

  case 'K':
    if (kp_help) {
      STRCPY(buf, "he! ");
    } else if (kp_ex) {
      if (cap->count0 != 0) {  // Send the count to the ex command.
        snprintf(buf, buf_size, "%" PRId64, (int64_t)(cap->count0));
      }
      STRCAT(buf, kp);
      STRCAT(buf, " ");
    } else {
      /* An external command will probably use an argument starting
       * with "-" as an option.  To avoid trouble we skip the "-". */
      while (*ptr == '-' && n > 0) {
        ++ptr;
        --n;
      }
      if (n == 0) {
        EMSG(_(e_noident));              /* found dashes only */
        xfree(buf);
        return;
      }

      /* When a count is given, turn it into a range.  Is this
       * really what we want? */
      bool isman = (STRCMP(kp, "man") == 0);
      bool isman_s = (STRCMP(kp, "man -s") == 0);
      if (cap->count0 != 0 && !(isman || isman_s)) {
        snprintf(buf, buf_size, ".,.+%" PRId64, (int64_t)(cap->count0 - 1));
      }

      STRCAT(buf, "! ");
      if (cap->count0 == 0 && isman_s) {
        STRCAT(buf, "man");
      } else {
        STRCAT(buf, kp);
      }
      STRCAT(buf, " ");
      if (cap->count0 != 0 && (isman || isman_s)) {
        snprintf(buf + STRLEN(buf), buf_size - STRLEN(buf), "%" PRId64,
            (int64_t)cap->count0);
        STRCAT(buf, " ");
      }
    }
    break;

  case ']':
    tag_cmd = true;
    if (p_cst)
      STRCPY(buf, "cstag ");
    else
      STRCPY(buf, "ts ");
    break;

  default:
    tag_cmd = true;
    if (curbuf->b_help)
      STRCPY(buf, "he! ");
    else {
      if (g_cmd)
        STRCPY(buf, "tj ");
      else
        snprintf(buf, buf_size, "%" PRId64 "ta ", (int64_t)cap->count0);
    }
  }

  // Now grab the chars in the identifier
  if (cmdchar == 'K' && !kp_help) {
    ptr = vim_strnsave(ptr, n);
    if (kp_ex) {
      // Escape the argument properly for an Ex command
      p = (char_u *)vim_strsave_fnameescape((const char *)ptr, false);
    } else {
      // Escape the argument properly for a shell command
      p = vim_strsave_shellescape(ptr, true, true);
    }
    xfree(ptr);
    char *newbuf = xrealloc(buf, STRLEN(buf) + STRLEN(p) + 1);
    buf = newbuf;
    STRCAT(buf, p);
    xfree(p);
  } else {
    if (cmdchar == '*')
      aux_ptr = (char_u *)(p_magic ? "/.*~[^$\\" : "/^$\\");
    else if (cmdchar == '#')
      aux_ptr = (char_u *)(p_magic ? "/?.*~[^$\\" : "/?^$\\");
    else if (tag_cmd) {
      if (curbuf->b_help)
        /* ":help" handles unescaped argument */
        aux_ptr = (char_u *)"";
      else
        aux_ptr = (char_u *)"\\|\"\n[";
    } else
      aux_ptr = (char_u *)"\\|\"\n*?[";

    p = (char_u *)buf + STRLEN(buf);
    while (n-- > 0) {
      /* put a backslash before \ and some others */
      if (vim_strchr(aux_ptr, *ptr) != NULL)
        *p++ = '\\';
      /* When current byte is a part of multibyte character, copy all
       * bytes of that character. */
      if (has_mbyte) {
        size_t len = (size_t)((*mb_ptr2len)(ptr) - 1);
        for (size_t i = 0; i < len && n > 0; ++i, --n)
          *p++ = *ptr++;
      }
      *p++ = *ptr++;
    }
    *p = NUL;
  }

  /*
   * Execute the command.
   */
  if (cmdchar == '*' || cmdchar == '#') {
    if (!g_cmd && (
          has_mbyte ? vim_iswordp(mb_prevptr(get_cursor_line_ptr(), ptr)) :
          vim_iswordc(ptr[-1])))
      STRCAT(buf, "\\>");
    /* put pattern in search history */
    init_history();
    add_to_history(HIST_SEARCH, (char_u *)buf, true, NUL);
    (void)normal_search(cap, cmdchar == '*' ? '/' : '?', (char_u *)buf, 0);
  } else {
    do_cmdline_cmd(buf);
  }

  xfree(buf);
}

/*
 * Get visually selected text, within one line only.
 * Returns false if more than one line selected.
 */
bool
get_visual_text (
    cmdarg_T *cap,
    char_u **pp,           /* return: start of selected text */
    size_t *lenp           /* return: length of selected text */
)
{
  if (VIsual_mode != 'V')
    unadjust_for_sel();
  if (VIsual.lnum != curwin->w_cursor.lnum) {
    if (cap != NULL)
      clearopbeep(cap->oap);
    return false;
  }
  if (VIsual_mode == 'V') {
    *pp = get_cursor_line_ptr();
    *lenp = STRLEN(*pp);
  } else {
    if (lt(curwin->w_cursor, VIsual)) {
      *pp = ml_get_pos(&curwin->w_cursor);
      *lenp = (size_t)(VIsual.col - curwin->w_cursor.col + 1);
    } else {
      *pp = ml_get_pos(&VIsual);
      *lenp = (size_t)(curwin->w_cursor.col - VIsual.col + 1);
    }
    if (has_mbyte)
      /* Correct the length to include the whole last character. */
      *lenp += (size_t)((*mb_ptr2len)(*pp + (*lenp - 1)) - 1);
  }
  reset_VIsual_and_resel();
  return true;
}

/*
 * CTRL-T: backwards in tag stack
 */
static void nv_tagpop(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap))
    do_tag((char_u *)"", DT_POP, (int)cap->count1, false, true);
}

/*
 * Handle scrolling command 'H', 'L' and 'M'.
 */
static void nv_scroll(cmdarg_T *cap)
{
  int used = 0;
  long n;
  linenr_T lnum;
  int half;

  cap->oap->motion_type = kMTLineWise;
  setpcmark();

  if (cap->cmdchar == 'L') {
    validate_botline();             /* make sure curwin->w_botline is valid */
    curwin->w_cursor.lnum = curwin->w_botline - 1;
    if (cap->count1 - 1 >= curwin->w_cursor.lnum)
      curwin->w_cursor.lnum = 1;
    else {
      if (hasAnyFolding(curwin)) {
        /* Count a fold for one screen line. */
        for (n = cap->count1 - 1; n > 0
             && curwin->w_cursor.lnum > curwin->w_topline; --n) {
          (void)hasFolding(curwin->w_cursor.lnum,
              &curwin->w_cursor.lnum, NULL);
          --curwin->w_cursor.lnum;
        }
      } else
        curwin->w_cursor.lnum -= cap->count1 - 1;
    }
  } else {
    if (cap->cmdchar == 'M') {
      /* Don't count filler lines above the window. */
      used -= diff_check_fill(curwin, curwin->w_topline)
              - curwin->w_topfill;
      validate_botline();  // make sure w_empty_rows is valid
      half = (curwin->w_grid.Rows - curwin->w_empty_rows + 1) / 2;
      for (n = 0; curwin->w_topline + n < curbuf->b_ml.ml_line_count; n++) {
        // Count half he number of filler lines to be "below this
        // line" and half to be "above the next line".
        if (n > 0 && used + diff_check_fill(curwin, curwin->w_topline
                + n) / 2 >= half) {
          --n;
          break;
        }
        used += plines(curwin->w_topline + n);
        if (used >= half)
          break;
        if (hasFolding(curwin->w_topline + n, NULL, &lnum))
          n = lnum - curwin->w_topline;
      }
      if (n > 0 && used > curwin->w_grid.Rows) {
        n--;
      }
    } else {  // (cap->cmdchar == 'H')
      n = cap->count1 - 1;
      if (hasAnyFolding(curwin)) {
        /* Count a fold for one screen line. */
        lnum = curwin->w_topline;
        while (n-- > 0 && lnum < curwin->w_botline - 1) {
          hasFolding(lnum, NULL, &lnum);
          ++lnum;
        }
        n = lnum - curwin->w_topline;
      }
    }
    curwin->w_cursor.lnum = curwin->w_topline + n;
    if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count)
      curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
  }

  // Correct for 'so', except when an operator is pending.
  if (cap->oap->op_type == OP_NOP) {
    cursor_correct();
  }
  beginline(BL_SOL | BL_FIX);
}

/*
 * Cursor right commands.
 */
static void nv_right(cmdarg_T *cap)
{
  long n;
  int PAST_LINE;

  if (mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL)) {
    /* <C-Right> and <S-Right> move a word or WORD right */
    if (mod_mask & MOD_MASK_CTRL)
      cap->arg = true;
    nv_wordcmd(cap);
    return;
  }

  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  PAST_LINE = (VIsual_active && *p_sel != 'o');

  /*
   * In virtual mode, there's no such thing as "PAST_LINE", as lines are
   * (theoretically) infinitely long.
   */
  if (virtual_active())
    PAST_LINE = 0;

  for (n = cap->count1; n > 0; --n) {
    if ((!PAST_LINE && oneright() == false)
        || (PAST_LINE && *get_cursor_pos_ptr() == NUL)
        ) {
      //          <Space> wraps to next line if 'whichwrap' has 's'.
      //              'l' wraps to next line if 'whichwrap' has 'l'.
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
          ++curwin->w_cursor.lnum;
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
    } else if (PAST_LINE) {
      curwin->w_set_curswant = true;
      if (virtual_active())
        oneright();
      else {
        if (has_mbyte)
          curwin->w_cursor.col +=
            (*mb_ptr2len)(get_cursor_pos_ptr());
        else
          ++curwin->w_cursor.col;
      }
    }
  }
  if (n != cap->count1 && (fdo_flags & FDO_HOR) && KeyTyped
      && cap->oap->op_type == OP_NOP)
    foldOpenCursor();
}

/*
 * Cursor left commands.
 *
 * Returns true when operator end should not be adjusted.
 */
static void nv_left(cmdarg_T *cap)
{
  long n;

  if (mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL)) {
    /* <C-Left> and <S-Left> move a word or WORD left */
    if (mod_mask & MOD_MASK_CTRL)
      cap->arg = 1;
    nv_bck_word(cap);
    return;
  }

  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  for (n = cap->count1; n > 0; --n) {
    if (oneleft() == false) {
      /* <BS> and <Del> wrap to previous line if 'whichwrap' has 'b'.
       *		 'h' wraps to previous line if 'whichwrap' has 'h'.
       *	   CURS_LEFT wraps to previous line if 'whichwrap' has '<'.
       */
      if (       (((cap->cmdchar == K_BS
                    || cap->cmdchar == Ctrl_H)
                   && vim_strchr(p_ww, 'b') != NULL)
                  || (cap->cmdchar == 'h'
                      && vim_strchr(p_ww, 'h') != NULL)
                  || (cap->cmdchar == K_LEFT
                      && vim_strchr(p_ww, '<') != NULL))
                 && curwin->w_cursor.lnum > 1) {
        --(curwin->w_cursor.lnum);
        coladvance((colnr_T)MAXCOL);
        curwin->w_set_curswant = true;

        // When the NL before the first char has to be deleted we
        // put the cursor on the NUL after the previous line.
        // This is a very special case, be careful!
        // Don't adjust op_end now, otherwise it won't work.
        if ((cap->oap->op_type == OP_DELETE || cap->oap->op_type == OP_CHANGE)
            && !LINEEMPTY(curwin->w_cursor.lnum)) {
          char_u *cp = get_cursor_pos_ptr();

          if (*cp != NUL) {
            if (has_mbyte) {
              curwin->w_cursor.col += (*mb_ptr2len)(cp);
            } else {
              curwin->w_cursor.col++;
            }
          }
          cap->retval |= CA_NO_ADJ_OP_END;
        }
        continue;
      }
      /* Only beep and flush if not moved at all */
      else if (cap->oap->op_type == OP_NOP && n == cap->count1)
        beep_flush();
      break;
    }
  }
  if (n != cap->count1 && (fdo_flags & FDO_HOR) && KeyTyped
      && cap->oap->op_type == OP_NOP)
    foldOpenCursor();
}

/*
 * Cursor up commands.
 * cap->arg is true for "-": Move cursor to first non-blank.
 */
static void nv_up(cmdarg_T *cap)
{
  if (mod_mask & MOD_MASK_SHIFT) {
    /* <S-Up> is page up */
    cap->arg = BACKWARD;
    nv_page(cap);
  } else {
    cap->oap->motion_type = kMTLineWise;
    if (cursor_up(cap->count1, cap->oap->op_type == OP_NOP) == false) {
      clearopbeep(cap->oap);
    } else if (cap->arg) {
      beginline(BL_WHITE | BL_FIX);
    }
  }
}

/*
 * Cursor down commands.
 * cap->arg is true for CR and "+": Move cursor to first non-blank.
 */
static void nv_down(cmdarg_T *cap)
{
  if (mod_mask & MOD_MASK_SHIFT) {
    /* <S-Down> is page down */
    cap->arg = FORWARD;
    nv_page(cap);
  } else if (bt_quickfix(curbuf) && cap->cmdchar == CAR) {
    // In a quickfix window a <CR> jumps to the error under the cursor.
    if (curwin->w_llist_ref == NULL) {
      do_cmdline_cmd(".cc");  // quickfix window
    } else {
      do_cmdline_cmd(".ll");  // location list window
    }
  } else {
    // In the cmdline window a <CR> executes the command.
    if (cmdwin_type != 0 && cap->cmdchar == CAR) {
      cmdwin_result = CAR;
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

/*
 * Grab the file name under the cursor and edit it.
 */
static void nv_gotofile(cmdarg_T *cap)
{
  char_u      *ptr;
  linenr_T lnum = -1;

  if (text_locked()) {
    clearopbeep(cap->oap);
    text_locked_msg();
    return;
  }
  if (curbuf_locked()) {
    clearop(cap->oap);
    return;
  }

  ptr = grab_file_name(cap->count1, &lnum);

  if (ptr != NULL) {
    // do autowrite if necessary
    if (curbufIsChanged() && curbuf->b_nwindows <= 1 && !buf_hide(curbuf)) {
      (void)autowrite(curbuf, false);
    }
    setpcmark();
    if (do_ecmd(0, ptr, NULL, NULL, ECMD_LAST,
                buf_hide(curbuf) ? ECMD_HIDE : 0, curwin) == OK
        && cap->nchar == 'F' && lnum >= 0) {
      curwin->w_cursor.lnum = lnum;
      check_cursor_lnum();
      beginline(BL_SOL | BL_FIX);
    }
    xfree(ptr);
  } else
    clearop(cap->oap);
}

/*
 * <End> command: to end of current line or last line.
 */
static void nv_end(cmdarg_T *cap)
{
  if (cap->arg || (mod_mask & MOD_MASK_CTRL)) { /* CTRL-END = goto last line */
    cap->arg = true;
    nv_goto(cap);
    cap->count1 = 1;                    /* to end of current line */
  }
  nv_dollar(cap);
}

/*
 * Handle the "$" command.
 */
static void nv_dollar(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = true;
  /* In virtual mode when off the edge of a line and an operator
   * is pending (whew!) keep the cursor where it is.
   * Otherwise, send it to the end of the line. */
  if (!virtual_active() || gchar_cursor() != NUL
      || cap->oap->op_type == OP_NOP)
    curwin->w_curswant = MAXCOL;        /* so we stay at the end */
  if (cursor_down(cap->count1 - 1,
          cap->oap->op_type == OP_NOP) == false)
    clearopbeep(cap->oap);
  else if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP)
    foldOpenCursor();
}

/*
 * Implementation of '?' and '/' commands.
 * If cap->arg is true don't set PC mark.
 */
static void nv_search(cmdarg_T *cap)
{
  oparg_T     *oap = cap->oap;
  pos_T save_cursor = curwin->w_cursor;

  if (cap->cmdchar == '?' && cap->oap->op_type == OP_ROT13) {
    /* Translate "g??" to "g?g?" */
    cap->cmdchar = 'g';
    cap->nchar = '?';
    nv_operator(cap);
    return;
  }

  // When using 'incsearch' the cursor may be moved to set a different search
  // start position.
  cap->searchbuf = getcmdline(cap->cmdchar, cap->count1, 0);

  if (cap->searchbuf == NULL) {
    clearop(oap);
    return;
  }

  (void)normal_search(cap, cap->cmdchar, cap->searchbuf,
                      (cap->arg || !equalpos(save_cursor, curwin->w_cursor))
                      ? 0 : SEARCH_MARK);
}

/*
 * Handle "N" and "n" commands.
 * cap->arg is SEARCH_REV for "N", 0 for "n".
 */
static void nv_next(cmdarg_T *cap)
{
  pos_T old = curwin->w_cursor;
  int i = normal_search(cap, 0, NULL, SEARCH_MARK | cap->arg);

  if (i == 1 && equalpos(old, curwin->w_cursor)) {
    // Avoid getting stuck on the current cursor position, which can happen when
    // an offset is given and the cursor is on the last char in the buffer:
    // Repeat with count + 1.
    cap->count1 += 1;
    (void)normal_search(cap, 0, NULL, SEARCH_MARK | cap->arg);
    cap->count1 -= 1;
  }
}

/*
 * Search for "pat" in direction "dir" ('/' or '?', 0 for repeat).
 * Uses only cap->count1 and cap->oap from "cap".
 * Return 0 for failure, 1 for found, 2 for found and line offset added.
 */
static int normal_search(
    cmdarg_T *cap,
    int dir,
    char_u *pat,
    int opt                        /* extra flags for do_search() */
)
{
  int i;

  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  cap->oap->use_reg_one = true;
  curwin->w_set_curswant = true;

  i = do_search(cap->oap, dir, pat, cap->count1,
                opt | SEARCH_OPT | SEARCH_ECHO | SEARCH_MSG, NULL);
  if (i == 0) {
    clearop(cap->oap);
  } else {
    if (i == 2) {
      cap->oap->motion_type = kMTLineWise;
    }
    curwin->w_cursor.coladd = 0;
    if (cap->oap->op_type == OP_NOP && (fdo_flags & FDO_SEARCH) && KeyTyped)
      foldOpenCursor();
  }

  /* "/$" will put the cursor after the end of the line, may need to
   * correct that here */
  check_cursor();
  return i;
}

/*
 * Character search commands.
 * cap->arg is BACKWARD for 'F' and 'T', FORWARD for 'f' and 't', true for
 * ',' and false for ';'.
 * cap->nchar is NUL for ',' and ';' (repeat the search)
 */
static void nv_csearch(cmdarg_T *cap)
{
  bool t_cmd;

  if (cap->cmdchar == 't' || cap->cmdchar == 'T')
    t_cmd = true;
  else
    t_cmd = false;

  cap->oap->motion_type = kMTCharWise;
  if (IS_SPECIAL(cap->nchar) || searchc(cap, t_cmd) == false) {
    clearopbeep(cap->oap);
  } else {
    curwin->w_set_curswant = true;
    /* Include a Tab for "tx" and for "dfx". */
    if (gchar_cursor() == TAB && virtual_active() && cap->arg == FORWARD
        && (t_cmd || cap->oap->op_type != OP_NOP)) {
      colnr_T scol, ecol;

      getvcol(curwin, &curwin->w_cursor, &scol, NULL, &ecol);
      curwin->w_cursor.coladd = ecol - scol;
    } else
      curwin->w_cursor.coladd = 0;
    adjust_for_sel(cap);
    if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP)
      foldOpenCursor();
  }
}

/*
 * "[" and "]" commands.
 * cap->arg is BACKWARD for "[" and FORWARD for "]".
 */
static void nv_brackets(cmdarg_T *cap)
{
  pos_T new_pos = INIT_POS_T(0, 0, 0);
  pos_T prev_pos;
  pos_T       *pos = NULL;          /* init for GCC */
  pos_T old_pos;                    /* cursor position before command */
  int flag;
  long n;
  int findc;
  int c;

  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  old_pos = curwin->w_cursor;
  curwin->w_cursor.coladd = 0;              /* TODO: don't do this for an error. */

  /*
   * "[f" or "]f" : Edit file under the cursor (same as "gf")
   */
  if (cap->nchar == 'f')
    nv_gotofile(cap);
  else
  /*
   * Find the occurrence(s) of the identifier or define under cursor
   * in current and included files or jump to the first occurrence.
   *
   *			search	     list	    jump
   *		      fwd   bwd    fwd	 bwd	 fwd	bwd
   * identifier     "]i"  "[i"   "]I"  "[I"	"]^I"  "[^I"
   * define	      "]d"  "[d"   "]D"  "[D"	"]^D"  "[^D"
   */
  if (vim_strchr((char_u *)
          "iI\011dD\004",
          cap->nchar) != NULL) {
    char_u  *ptr;
    size_t len;

    if ((len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0)
      clearop(cap->oap);
    else {
      find_pattern_in_path(ptr, 0, len, true,
                           cap->count0 == 0 ? !isupper(cap->nchar) : false,
                           (((cap->nchar & 0xf) == ('d' & 0xf))
                            ? FIND_DEFINE
                            : FIND_ANY),
                           cap->count1,
                           (isupper(cap->nchar) ? ACTION_SHOW_ALL :
                            islower(cap->nchar) ? ACTION_SHOW :
                            ACTION_GOTO),
                           (cap->cmdchar == ']'
                            ? curwin->w_cursor.lnum + 1
                            : (linenr_T)1),
                           MAXLNUM);
      curwin->w_set_curswant = true;
    }
  } else
  /*
   * "[{", "[(", "]}" or "])": go to Nth unclosed '{', '(', '}' or ')'
   * "[#", "]#": go to start/end of Nth innermost #if..#endif construct.
   * "[/", "[*", "]/", "]*": go to Nth comment start/end.
   * "[m" or "]m" search for prev/next start of (Java) method.
   * "[M" or "]M" search for prev/next end of (Java) method.
   */
  if (  (cap->cmdchar == '['
         && vim_strchr((char_u *)"{(*/#mM", cap->nchar) != NULL)
        || (cap->cmdchar == ']'
            && vim_strchr((char_u *)"})*/#mM", cap->nchar) != NULL)) {
    if (cap->nchar == '*')
      cap->nchar = '/';
    prev_pos.lnum = 0;
    if (cap->nchar == 'm' || cap->nchar == 'M') {
      if (cap->cmdchar == '[')
        findc = '{';
      else
        findc = '}';
      n = 9999;
    } else {
      findc = cap->nchar;
      n = cap->count1;
    }
    for (; n > 0; --n) {
      if ((pos = findmatchlimit(cap->oap, findc,
               (cap->cmdchar == '[') ? FM_BACKWARD : FM_FORWARD, 0)) == NULL) {
        if (new_pos.lnum == 0) {        /* nothing found */
          if (cap->nchar != 'm' && cap->nchar != 'M')
            clearopbeep(cap->oap);
        } else
          pos = &new_pos;               /* use last one found */
        break;
      }
      prev_pos = new_pos;
      curwin->w_cursor = *pos;
      new_pos = *pos;
    }
    curwin->w_cursor = old_pos;

    /*
     * Handle "[m", "]m", "[M" and "[M".  The findmatchlimit() only
     * brought us to the match for "[m" and "]M" when inside a method.
     * Try finding the '{' or '}' we want to be at.
     * Also repeat for the given count.
     */
    if (cap->nchar == 'm' || cap->nchar == 'M') {
      /* norm is true for "]M" and "[m" */
      int norm = ((findc == '{') == (cap->nchar == 'm'));

      n = cap->count1;
      /* found a match: we were inside a method */
      if (prev_pos.lnum != 0) {
        pos = &prev_pos;
        curwin->w_cursor = prev_pos;
        if (norm)
          --n;
      } else
        pos = NULL;
      while (n > 0) {
        for (;; ) {
          if ((findc == '{' ? dec_cursor() : inc_cursor()) < 0) {
            /* if not found anything, that's an error */
            if (pos == NULL)
              clearopbeep(cap->oap);
            n = 0;
            break;
          }
          c = gchar_cursor();
          if (c == '{' || c == '}') {
            /* Must have found end/start of class: use it.
             * Or found the place to be at. */
            if ((c == findc && norm) || (n == 1 && !norm)) {
              new_pos = curwin->w_cursor;
              pos = &new_pos;
              n = 0;
            }
            /* if no match found at all, we started outside of the
             * class and we're inside now.  Just go on. */
            else if (new_pos.lnum == 0) {
              new_pos = curwin->w_cursor;
              pos = &new_pos;
            }
            /* found start/end of other method: go to match */
            else if ((pos = findmatchlimit(cap->oap, findc,
                          (cap->cmdchar == '[') ? FM_BACKWARD : FM_FORWARD,
                          0)) == NULL)
              n = 0;
            else
              curwin->w_cursor = *pos;
            break;
          }
        }
        --n;
      }
      curwin->w_cursor = old_pos;
      if (pos == NULL && new_pos.lnum != 0)
        clearopbeep(cap->oap);
    }
    if (pos != NULL) {
      setpcmark();
      curwin->w_cursor = *pos;
      curwin->w_set_curswant = true;
      if ((fdo_flags & FDO_BLOCK) && KeyTyped
          && cap->oap->op_type == OP_NOP)
        foldOpenCursor();
    }
  }
  /*
   * "[[", "[]", "]]" and "][": move to start or end of function
   */
  else if (cap->nchar == '[' || cap->nchar == ']') {
    if (cap->nchar == cap->cmdchar)                 /* "]]" or "[[" */
      flag = '{';
    else
      flag = '}';                   /* "][" or "[]" */

    curwin->w_set_curswant = true;
    /*
     * Imitate strange Vi behaviour: When using "]]" with an operator
     * we also stop at '}'.
     */
    if (!findpar(&cap->oap->inclusive, cap->arg, cap->count1, flag,
            (cap->oap->op_type != OP_NOP
             && cap->arg == FORWARD && flag == '{')))
      clearopbeep(cap->oap);
    else {
      if (cap->oap->op_type == OP_NOP)
        beginline(BL_WHITE | BL_FIX);
      if ((fdo_flags & FDO_BLOCK) && KeyTyped && cap->oap->op_type == OP_NOP)
        foldOpenCursor();
    }
  }
  /*
   * "[p", "[P", "]P" and "]p": put with indent adjustment
   */
  else if (cap->nchar == 'p' || cap->nchar == 'P') {
    if (!checkclearop(cap->oap)) {
      int dir = (cap->cmdchar == ']' && cap->nchar == 'p') ? FORWARD : BACKWARD;
      int regname = cap->oap->regname;
      int was_visual = VIsual_active;
      linenr_T line_count = curbuf->b_ml.ml_line_count;
      pos_T start, end;

      if (VIsual_active) {
        start = ltoreq(VIsual, curwin->w_cursor) ? VIsual : curwin->w_cursor;
        end = equalpos(start, VIsual) ? curwin->w_cursor : VIsual;
        curwin->w_cursor = (dir == BACKWARD ? start : end);
      }
      prep_redo_cmd(cap);
      do_put(regname, NULL, dir, cap->count1, PUT_FIXINDENT);
      if (was_visual) {
        VIsual = start;
        curwin->w_cursor = end;
        if (dir == BACKWARD) {
          /* adjust lines */
          VIsual.lnum += curbuf->b_ml.ml_line_count - line_count;
          curwin->w_cursor.lnum += curbuf->b_ml.ml_line_count - line_count;
        }

        VIsual_active = true;
        if (VIsual_mode == 'V') {
          /* delete visually selected lines */
          cap->cmdchar = 'd';
          cap->nchar = NUL;
          cap->oap->regname = regname;
          nv_operator(cap);
          do_pending_operator(cap, 0, false);
        }
        if (VIsual_active) {
          end_visual_mode();
          redraw_later(SOME_VALID);
        }
      }
    }
  }
  /*
   * "['", "[`", "]'" and "]`": jump to next mark
   */
  else if (cap->nchar == '\'' || cap->nchar == '`') {
    pos = &curwin->w_cursor;
    for (n = cap->count1; n > 0; --n) {
      prev_pos = *pos;
      pos = getnextmark(pos, cap->cmdchar == '[' ? BACKWARD : FORWARD,
          cap->nchar == '\'');
      if (pos == NULL)
        break;
    }
    if (pos == NULL)
      pos = &prev_pos;
    nv_cursormark(cap, cap->nchar == '\'', pos);
  }
  /*
   * [ or ] followed by a middle mouse click: put selected text with
   * indent adjustment.  Any other button just does as usual.
   */
  else if (cap->nchar >= K_RIGHTRELEASE && cap->nchar <= K_LEFTMOUSE) {
    (void)do_mouse(cap->oap, cap->nchar,
        (cap->cmdchar == ']') ? FORWARD : BACKWARD,
        cap->count1, PUT_FIXINDENT);
  }
  /*
   * "[z" and "]z": move to start or end of open fold.
   */
  else if (cap->nchar == 'z') {
    if (foldMoveTo(false, cap->cmdchar == ']' ? FORWARD : BACKWARD,
            cap->count1) == false)
      clearopbeep(cap->oap);
  }
  /*
   * "[c" and "]c": move to next or previous diff-change.
   */
  else if (cap->nchar == 'c') {
    if (diff_move_to(cap->cmdchar == ']' ? FORWARD : BACKWARD,
            cap->count1) == false)
      clearopbeep(cap->oap);
  }
  /*
   * "[s", "[S", "]s" and "]S": move to next spell error.
   */
  else if (cap->nchar == 's' || cap->nchar == 'S') {
    setpcmark();
    for (n = 0; n < cap->count1; ++n)
      if (spell_move_to(curwin, cap->cmdchar == ']' ? FORWARD : BACKWARD,
                        cap->nchar == 's', false, NULL) == 0) {
        clearopbeep(cap->oap);
        break;
      } else {
        curwin->w_set_curswant = true;
      }
    if (cap->oap->op_type == OP_NOP && (fdo_flags & FDO_SEARCH) && KeyTyped)
      foldOpenCursor();
  }
  /* Not a valid cap->nchar. */
  else
    clearopbeep(cap->oap);
}

/*
 * Handle Normal mode "%" command.
 */
static void nv_percent(cmdarg_T *cap)
{
  pos_T       *pos;
  linenr_T lnum = curwin->w_cursor.lnum;

  cap->oap->inclusive = true;
  if (cap->count0) {  // {cnt}% : goto {cnt} percentage in file
    if (cap->count0 > 100) {
      clearopbeep(cap->oap);
    } else {
      cap->oap->motion_type = kMTLineWise;
      setpcmark();
      /* Round up, so CTRL-G will give same value.  Watch out for a
       * large line count, the line number must not go negative! */
      if (curbuf->b_ml.ml_line_count > 1000000)
        curwin->w_cursor.lnum = (curbuf->b_ml.ml_line_count + 99L)
                                / 100L * cap->count0;
      else
        curwin->w_cursor.lnum = (curbuf->b_ml.ml_line_count *
                                 cap->count0 + 99L) / 100L;
      if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count)
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      beginline(BL_SOL | BL_FIX);
    }
  } else {  // "%" : go to matching paren
    cap->oap->motion_type = kMTCharWise;
    cap->oap->use_reg_one = true;
    if ((pos = findmatch(cap->oap, NUL)) == NULL)
      clearopbeep(cap->oap);
    else {
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
      && KeyTyped)
    foldOpenCursor();
}

/*
 * Handle "(" and ")" commands.
 * cap->arg is BACKWARD for "(" and FORWARD for ")".
 */
static void nv_brace(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->use_reg_one = true;
  /* The motion used to be inclusive for "(", but that is not what Vi does. */
  cap->oap->inclusive = false;
  curwin->w_set_curswant = true;

  if (findsent(cap->arg, cap->count1) == false)
    clearopbeep(cap->oap);
  else {
    /* Don't leave the cursor on the NUL past end of line. */
    adjust_cursor(cap->oap);
    curwin->w_cursor.coladd = 0;
    if ((fdo_flags & FDO_BLOCK) && KeyTyped && cap->oap->op_type == OP_NOP)
      foldOpenCursor();
  }
}

/*
 * "m" command: Mark a position.
 */
static void nv_mark(cmdarg_T *cap)
{
  if (!checkclearop(cap->oap)) {
    if (setmark(cap->nchar) == false)
      clearopbeep(cap->oap);
  }
}

/*
 * "{" and "}" commands.
 * cmd->arg is BACKWARD for "{" and FORWARD for "}".
 */
static void nv_findpar(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  cap->oap->use_reg_one = true;
  curwin->w_set_curswant = true;
  if (!findpar(&cap->oap->inclusive, cap->arg, cap->count1, NUL, false))
    clearopbeep(cap->oap);
  else {
    curwin->w_cursor.coladd = 0;
    if ((fdo_flags & FDO_BLOCK) && KeyTyped && cap->oap->op_type == OP_NOP)
      foldOpenCursor();
  }
}

/*
 * "u" command: Undo or make lower case.
 */
static void nv_undo(cmdarg_T *cap)
{
  if (cap->oap->op_type == OP_LOWER
      || VIsual_active
      ) {
    /* translate "<Visual>u" to "<Visual>gu" and "guu" to "gugu" */
    cap->cmdchar = 'g';
    cap->nchar = 'u';
    nv_operator(cap);
  } else
    nv_kundo(cap);
}

/*
 * <Undo> command.
 */
static void nv_kundo(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap)) {
    u_undo((int)cap->count1);
    curwin->w_set_curswant = true;
  }
}

/*
 * Handle the "r" command.
 */
static void nv_replace(cmdarg_T *cap)
{
  char_u      *ptr;
  int had_ctrl_v;
  long n;

  if (checkclearop(cap->oap))
    return;

  /* get another character */
  if (cap->nchar == Ctrl_V) {
    had_ctrl_v = Ctrl_V;
    cap->nchar = get_literal();
    /* Don't redo a multibyte character with CTRL-V. */
    if (cap->nchar > DEL)
      had_ctrl_v = NUL;
  } else
    had_ctrl_v = NUL;

  /* Abort if the character is a special key. */
  if (IS_SPECIAL(cap->nchar)) {
    clearopbeep(cap->oap);
    return;
  }

  /* Visual mode "r" */
  if (VIsual_active) {
    if (got_int)
      reset_VIsual();
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

  /* Break tabs, etc. */
  if (virtual_active()) {
    if (u_save_cursor() == false)
      return;
    if (gchar_cursor() == NUL) {
      /* Add extra space and put the cursor on the first one. */
      coladvance_force((colnr_T)(getviscol() + cap->count1));
      assert(cap->count1 <= INT_MAX);
      curwin->w_cursor.col -= (colnr_T)cap->count1;
    } else if (gchar_cursor() == TAB)
      coladvance_force(getviscol());
  }

  /* Abort if not enough characters to replace. */
  ptr = get_cursor_pos_ptr();
  if (STRLEN(ptr) < (unsigned)cap->count1
      || (has_mbyte && mb_charlen(ptr) < cap->count1)
      ) {
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

  /* save line for undo */
  if (u_save_cursor() == false)
    return;

  if (had_ctrl_v != Ctrl_V && (cap->nchar == '\r' || cap->nchar == '\n')) {
    /*
     * Replace character(s) by a single newline.
     * Strange vi behaviour: Only one newline is inserted.
     * Delete the characters here.
     * Insert the newline with an insert command, takes care of
     * autoindent.	The insert command depends on being on the last
     * character of a line or not.
     */
    (void)del_chars(cap->count1, false);        /* delete the characters */
    stuffcharReadbuff('\r');
    stuffcharReadbuff(ESC);

    /* Give 'r' to edit(), to get the redo command right. */
    invoke_edit(cap, true, 'r', false);
  } else {
    prep_redo(cap->oap->regname, cap->count1,
        NUL, 'r', NUL, had_ctrl_v, cap->nchar);

    curbuf->b_op_start = curwin->w_cursor;
    if (has_mbyte) {
      int old_State = State;

      if (cap->ncharC1 != 0)
        AppendCharToRedobuff(cap->ncharC1);
      if (cap->ncharC2 != 0)
        AppendCharToRedobuff(cap->ncharC2);

      /* This is slow, but it handles replacing a single-byte with a
       * multi-byte and the other way around.  Also handles adding
       * composing characters for utf-8. */
      for (n = cap->count1; n > 0; --n) {
        State = REPLACE;
        if (cap->nchar == Ctrl_E || cap->nchar == Ctrl_Y) {
          int c = ins_copychar(curwin->w_cursor.lnum
              + (cap->nchar == Ctrl_Y ? -1 : 1));
          if (c != NUL)
            ins_char(c);
          else
            /* will be decremented further down */
            ++curwin->w_cursor.col;
        } else
          ins_char(cap->nchar);
        State = old_State;
        if (cap->ncharC1 != 0)
          ins_char(cap->ncharC1);
        if (cap->ncharC2 != 0)
          ins_char(cap->ncharC2);
      }
    } else {
      /*
       * Replace the characters within one line.
       */
      for (n = cap->count1; n > 0; --n) {
        /*
         * Get ptr again, because u_save and/or showmatch() will have
         * released the line.  At the same time we let know that the
         * line will be changed.
         */
        ptr = ml_get_buf(curbuf, curwin->w_cursor.lnum, true);
        if (cap->nchar == Ctrl_E || cap->nchar == Ctrl_Y) {
          int c = ins_copychar(curwin->w_cursor.lnum
                               + (cap->nchar == Ctrl_Y ? -1 : 1));
          if (c != NUL) {
            assert(c >= 0 && c <= UCHAR_MAX);
            ptr[curwin->w_cursor.col] = (char_u)c;
          }
        } else {
          assert(cap->nchar >= 0 && cap->nchar <= UCHAR_MAX);
          ptr[curwin->w_cursor.col] = (char_u)cap->nchar;
        }
        if (p_sm && msg_silent == 0)
          showmatch(cap->nchar);
        ++curwin->w_cursor.col;
      }

      /* mark the buffer as changed and prepare for displaying */
      changed_bytes(curwin->w_cursor.lnum,
          (colnr_T)(curwin->w_cursor.col - cap->count1));
    }
    --curwin->w_cursor.col;         /* cursor on the last replaced char */
    /* if the character on the left of the current cursor is a multi-byte
     * character, move two characters left */
    if (has_mbyte)
      mb_adjust_cursor();
    curbuf->b_op_end = curwin->w_cursor;
    curwin->w_set_curswant = true;
    set_last_insert(cap->nchar);
  }

  foldUpdateAfterInsert();
}

/*
 * 'o': Exchange start and end of Visual area.
 * 'O': same, but in block mode exchange left and right corners.
 */
static void v_swap_corners(int cmdchar)
{
  pos_T old_cursor;
  colnr_T left, right;

  if (cmdchar == 'O' && VIsual_mode == Ctrl_V) {
    old_cursor = curwin->w_cursor;
    getvcols(curwin, &old_cursor, &VIsual, &left, &right);
    curwin->w_cursor.lnum = VIsual.lnum;
    coladvance(left);
    VIsual = curwin->w_cursor;

    curwin->w_cursor.lnum = old_cursor.lnum;
    curwin->w_curswant = right;
    /* 'selection "exclusive" and cursor at right-bottom corner: move it
     * right one column */
    if (old_cursor.lnum >= VIsual.lnum && *p_sel == 'e')
      ++curwin->w_curswant;
    coladvance(curwin->w_curswant);
    if (curwin->w_cursor.col == old_cursor.col
        && (!virtual_active()
            || curwin->w_cursor.coladd == old_cursor.coladd)
        ) {
      curwin->w_cursor.lnum = VIsual.lnum;
      if (old_cursor.lnum <= VIsual.lnum && *p_sel == 'e')
        ++right;
      coladvance(right);
      VIsual = curwin->w_cursor;

      curwin->w_cursor.lnum = old_cursor.lnum;
      coladvance(left);
      curwin->w_curswant = left;
    }
  } else {
    old_cursor = curwin->w_cursor;
    curwin->w_cursor = VIsual;
    VIsual = old_cursor;
    curwin->w_set_curswant = true;
  }
}

/*
 * "R" (cap->arg is false) and "gR" (cap->arg is true).
 */
static void nv_Replace(cmdarg_T *cap)
{
  if (VIsual_active) {          /* "R" is replace lines */
    cap->cmdchar = 'c';
    cap->nchar = NUL;
    VIsual_mode_orig = VIsual_mode;     /* remember original area for gv */
    VIsual_mode = 'V';
    nv_operator(cap);
  } else if (!checkclearopq(cap->oap)) {
    if (!MODIFIABLE(curbuf)) {
      EMSG(_(e_modifiable));
    } else {
      if (virtual_active())
        coladvance(getviscol());
      invoke_edit(cap, false, cap->arg ? 'V' : 'R', false);
    }
  }
}

/*
 * "gr".
 */
static void nv_vreplace(cmdarg_T *cap)
{
  if (VIsual_active) {
    cap->cmdchar = 'r';
    cap->nchar = cap->extra_char;
    nv_replace(cap);            /* Do same as "r" in Visual mode for now */
  } else if (!checkclearopq(cap->oap)) {
    if (!MODIFIABLE(curbuf)) {
      EMSG(_(e_modifiable));
    } else {
      if (cap->extra_char == Ctrl_V)            /* get another character */
        cap->extra_char = get_literal();
      stuffcharReadbuff(cap->extra_char);
      stuffcharReadbuff(ESC);
      if (virtual_active())
        coladvance(getviscol());
      invoke_edit(cap, true, 'v', false);
    }
  }
}

/*
 * Swap case for "~" command, when it does not work like an operator.
 */
static void n_swapchar(cmdarg_T *cap)
{
  long n;
  pos_T startpos;
  int did_change = 0;

  if (checkclearopq(cap->oap)) {
    return;
  }

  if (LINEEMPTY(curwin->w_cursor.lnum) && vim_strchr(p_ww, '~') == NULL) {
    clearopbeep(cap->oap);
    return;
  }

  prep_redo_cmd(cap);

  if (u_save_cursor() == false)
    return;

  startpos = curwin->w_cursor;
  for (n = cap->count1; n > 0; --n) {
    did_change |= swapchar(cap->oap->op_type, &curwin->w_cursor);
    inc_cursor();
    if (gchar_cursor() == NUL) {
      if (vim_strchr(p_ww, '~') != NULL
          && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
        ++curwin->w_cursor.lnum;
        curwin->w_cursor.col = 0;
        if (n > 1) {
          if (u_savesub(curwin->w_cursor.lnum) == false)
            break;
          u_clearline();
        }
      } else
        break;
    }
  }


  check_cursor();
  curwin->w_set_curswant = true;
  if (did_change) {
    changed_lines(startpos.lnum, startpos.col, curwin->w_cursor.lnum + 1,
                  0L, true);
    curbuf->b_op_start = startpos;
    curbuf->b_op_end = curwin->w_cursor;
    if (curbuf->b_op_end.col > 0)
      --curbuf->b_op_end.col;
  }
}

/*
 * Move cursor to mark.
 */
static void nv_cursormark(cmdarg_T *cap, int flag, pos_T *pos)
{
  if (check_mark(pos) == false)
    clearop(cap->oap);
  else {
    if (cap->cmdchar == '\''
        || cap->cmdchar == '`'
        || cap->cmdchar == '['
        || cap->cmdchar == ']')
      setpcmark();
    curwin->w_cursor = *pos;
    if (flag)
      beginline(BL_WHITE | BL_FIX);
    else
      check_cursor();
  }
  cap->oap->motion_type = flag ? kMTLineWise : kMTCharWise;
  if (cap->cmdchar == '`') {
    cap->oap->use_reg_one = true;
  }
  cap->oap->inclusive = false;  // ignored if not kMTCharWise
  curwin->w_set_curswant = true;
}

/*
 * Handle commands that are operators in Visual mode.
 */
static void v_visop(cmdarg_T *cap)
{
  static char_u trans[] = "YyDdCcxdXdAAIIrr";

  /* Uppercase means linewise, except in block mode, then "D" deletes till
   * the end of the line, and "C" replaces till EOL */
  if (isupper(cap->cmdchar)) {
    if (VIsual_mode != Ctrl_V) {
      VIsual_mode_orig = VIsual_mode;
      VIsual_mode = 'V';
    } else if (cap->cmdchar == 'C' || cap->cmdchar == 'D')
      curwin->w_curswant = MAXCOL;
  }
  cap->cmdchar = *(vim_strchr(trans, cap->cmdchar) + 1);
  nv_operator(cap);
}

/*
 * "s" and "S" commands.
 */
static void nv_subst(cmdarg_T *cap)
{
  if (VIsual_active) {  /* "vs" and "vS" are the same as "vc" */
    if (cap->cmdchar == 'S') {
      VIsual_mode_orig = VIsual_mode;
      VIsual_mode = 'V';
    }
    cap->cmdchar = 'c';
    nv_operator(cap);
  } else
    nv_optrans(cap);
}

/*
 * Abbreviated commands.
 */
static void nv_abbrev(cmdarg_T *cap)
{
  if (cap->cmdchar == K_DEL || cap->cmdchar == K_KDEL)
    cap->cmdchar = 'x';                 /* DEL key behaves like 'x' */

  /* in Visual mode these commands are operators */
  if (VIsual_active)
    v_visop(cap);
  else
    nv_optrans(cap);
}

/*
 * Translate a command into another command.
 */
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

/*
 * "'" and "`" commands.  Also for "g'" and "g`".
 * cap->arg is true for "'" and "g'".
 */
static void nv_gomark(cmdarg_T *cap)
{
  pos_T       *pos;
  int c;
  pos_T old_cursor = curwin->w_cursor;
  const bool old_KeyTyped = KeyTyped;       // getting file may reset it

  if (cap->cmdchar == 'g')
    c = cap->extra_char;
  else
    c = cap->nchar;
  pos = getmark(c, (cap->oap->op_type == OP_NOP));
  if (pos == (pos_T *)-1) {         /* jumped to other file */
    if (cap->arg) {
      check_cursor_lnum();
      beginline(BL_WHITE | BL_FIX);
    } else
      check_cursor();
  } else
    nv_cursormark(cap, cap->arg, pos);

  // May need to clear the coladd that a mark includes.
  if (!virtual_active()) {
    curwin->w_cursor.coladd = 0;
  }
  check_cursor_col();
  if (cap->oap->op_type == OP_NOP
      && pos != NULL
      && (pos == (pos_T *)-1 || !equalpos(old_cursor, *pos))
      && (fdo_flags & FDO_MARK)
      && old_KeyTyped) {
    foldOpenCursor();
  }
}

/*
 * Handle CTRL-O, CTRL-I, "g;" and "g," commands.
 */
static void nv_pcmark(cmdarg_T *cap)
{
  pos_T       *pos;
  linenr_T lnum = curwin->w_cursor.lnum;
  const bool old_KeyTyped = KeyTyped;       // getting file may reset it

  if (!checkclearopq(cap->oap)) {
    if (cap->cmdchar == 'g')
      pos = movechangelist((int)cap->count1);
    else
      pos = movemark((int)cap->count1);
    if (pos == (pos_T *)-1) {           /* jump to other file */
      curwin->w_set_curswant = true;
      check_cursor();
    } else if (pos != NULL)                 /* can jump */
      nv_cursormark(cap, false, pos);
    else if (cap->cmdchar == 'g') {
      if (curbuf->b_changelistlen == 0)
        EMSG(_("E664: changelist is empty"));
      else if (cap->count1 < 0)
        EMSG(_("E662: At start of changelist"));
      else
        EMSG(_("E663: At end of changelist"));
    } else
      clearopbeep(cap->oap);
    if (cap->oap->op_type == OP_NOP
        && (pos == (pos_T *)-1 || lnum != curwin->w_cursor.lnum)
        && (fdo_flags & FDO_MARK)
        && old_KeyTyped)
      foldOpenCursor();
  }
}

/*
 * Handle '"' command.
 */
static void nv_regname(cmdarg_T *cap)
{
  if (checkclearop(cap->oap))
    return;
  if (cap->nchar == '=')
    cap->nchar = get_expr_register();
  if (cap->nchar != NUL && valid_yank_reg(cap->nchar, false)) {
    cap->oap->regname = cap->nchar;
    cap->opcount = cap->count0;         /* remember count before '"' */
    set_reg_var(cap->oap->regname);
  } else
    clearopbeep(cap->oap);
}

/*
 * Handle "v", "V" and "CTRL-V" commands.
 * Also for "gh", "gH" and "g^H" commands: Always start Select mode, cap->arg
 * is true.
 * Handle CTRL-Q just like CTRL-V.
 */
static void nv_visual(cmdarg_T *cap)
{
  if (cap->cmdchar == Ctrl_Q)
    cap->cmdchar = Ctrl_V;

  /* 'v', 'V' and CTRL-V can be used while an operator is pending to make it
   * characterwise, linewise, or blockwise. */
  if (cap->oap->op_type != OP_NOP) {
    cap->oap->motion_force = cap->cmdchar;
    finish_op = false;          /* operator doesn't finish now but later */
    return;
  }

  VIsual_select = cap->arg;
  if (VIsual_active) {      /* change Visual mode */
    if (VIsual_mode == cap->cmdchar)        /* stop visual mode */
      end_visual_mode();
    else {                                  /* toggle char/block mode */
                                            /*	   or char/line mode */
      VIsual_mode = cap->cmdchar;
      showmode();
    }
    redraw_curbuf_later(INVERTED);          // update the inversion
  } else {                // start Visual mode
    if (cap->count0 > 0 && resel_VIsual_mode != NUL) {
      /* use previously selected part */
      VIsual = curwin->w_cursor;

      VIsual_active = true;
      VIsual_reselect = true;
      if (!cap->arg)
        /* start Select mode when 'selectmode' contains "cmd" */
        may_start_select('c');
      setmouse();
      if (p_smd && msg_silent == 0)
        redraw_cmdline = true;              /* show visual mode later */
      /*
       * For V and ^V, we multiply the number of lines even if there
       * was only one -- webb
       */
      if (resel_VIsual_mode != 'v' || resel_VIsual_line_count > 1) {
        curwin->w_cursor.lnum +=
          resel_VIsual_line_count * cap->count0 - 1;
        if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count)
          curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      }
      VIsual_mode = resel_VIsual_mode;
      if (VIsual_mode == 'v') {
        if (resel_VIsual_line_count <= 1) {
          validate_virtcol();
          assert(cap->count0 >= INT_MIN && cap->count0 <= INT_MAX);
          curwin->w_curswant = (curwin->w_virtcol
                                + resel_VIsual_vcol * (int)cap->count0 - 1);
        } else
          curwin->w_curswant = resel_VIsual_vcol;
        coladvance(curwin->w_curswant);
      }
      if (resel_VIsual_vcol == MAXCOL) {
        curwin->w_curswant = MAXCOL;
        coladvance((colnr_T)MAXCOL);
      } else if (VIsual_mode == Ctrl_V) {
        validate_virtcol();
        assert(cap->count0 >= INT_MIN && cap->count0 <= INT_MAX);
        curwin->w_curswant = (curwin->w_virtcol
                              + resel_VIsual_vcol * (int)cap->count0 - 1);
        coladvance(curwin->w_curswant);
      } else
        curwin->w_set_curswant = true;
      redraw_curbuf_later(INVERTED);            /* show the inversion */
    } else {
      if (!cap->arg)
        /* start Select mode when 'selectmode' contains "cmd" */
        may_start_select('c');
      n_start_visual_mode(cap->cmdchar);
      if (VIsual_mode != 'V' && *p_sel == 'e')
        ++cap->count1;          /* include one more char */
      if (cap->count0 > 0 && --cap->count1 > 0) {
        /* With a count select that many characters or lines. */
        if (VIsual_mode == 'v' || VIsual_mode == Ctrl_V)
          nv_right(cap);
        else if (VIsual_mode == 'V')
          nv_down(cap);
      }
    }
  }
}

/*
 * Start selection for Shift-movement keys.
 */
void start_selection(void)
{
  /* if 'selectmode' contains "key", start Select mode */
  may_start_select('k');
  n_start_visual_mode('v');
}

/*
 * Start Select mode, if "c" is in 'selectmode' and not in a mapping or menu.
 */
void may_start_select(int c)
{
  VIsual_select = (stuff_empty() && typebuf_typed()
                   && (vim_strchr(p_slm, c) != NULL));
}

/*
 * Start Visual mode "c".
 * Should set VIsual_select before calling this.
 */
static void n_start_visual_mode(int c)
{
  // Check for redraw before changing the state.
  conceal_check_cursor_line();

  VIsual_mode = c;
  VIsual_active = true;
  VIsual_reselect = true;
  /* Corner case: the 0 position in a tab may change when going into
   * virtualedit.  Recalculate curwin->w_cursor to avoid bad hilighting.
   */
  if (c == Ctrl_V && (ve_flags & VE_BLOCK) && gchar_cursor() == TAB) {
    validate_virtcol();
    coladvance(curwin->w_virtcol);
  }
  VIsual = curwin->w_cursor;

  foldAdjustVisual();

  setmouse();
  // Check for redraw after changing the state.
  conceal_check_cursor_line();

  if (p_smd && msg_silent == 0)
    redraw_cmdline = true;      /* show visual mode later */

  /* Only need to redraw this line, unless still need to redraw an old
   * Visual area (when 'lazyredraw' is set). */
  if (curwin->w_redr_type < INVERTED) {
    curwin->w_old_cursor_lnum = curwin->w_cursor.lnum;
    curwin->w_old_visual_lnum = curwin->w_cursor.lnum;
  }
}


/*
 * CTRL-W: Window commands
 */
static void nv_window(cmdarg_T *cap)
{
  if (!checkclearop(cap->oap))
    do_window(cap->nchar, cap->count0, NUL);     /* everything is in window.c */
}

/*
 * CTRL-Z: Suspend
 */
static void nv_suspend(cmdarg_T *cap)
{
  clearop(cap->oap);
  if (VIsual_active)
    end_visual_mode();                  /* stop Visual mode */
  do_cmdline_cmd("st");
}

/*
 * Commands starting with "g".
 */
static void nv_g_cmd(cmdarg_T *cap)
{
  oparg_T     *oap = cap->oap;
  pos_T tpos;
  int i;
  bool flag = false;

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

  /*
   * "gv": Reselect the previous Visual area.  If Visual already active,
   *	     exchange previous and current Visual area.
   */
  case 'v':
    if (checkclearop(oap))
      break;

    if (       curbuf->b_visual.vi_start.lnum == 0
               || curbuf->b_visual.vi_start.lnum > curbuf->b_ml.ml_line_count
               || curbuf->b_visual.vi_end.lnum == 0)
      beep_flush();
    else {
      /* set w_cursor to the start of the Visual area, tpos to the end */
      if (VIsual_active) {
        i = VIsual_mode;
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

      /* Set Visual to the start and w_cursor to the end of the Visual
       * area.  Make sure they are on an existing character. */
      check_cursor();
      VIsual = curwin->w_cursor;
      curwin->w_cursor = tpos;
      check_cursor();
      update_topline();
      /*
       * When called from normal "g" command: start Select mode when
       * 'selectmode' contains "cmd".  When called for K_SELECT, always
       * start Select mode.
       */
      if (cap->arg)
        VIsual_select = true;
      else
        may_start_select('c');
      setmouse();
      redraw_curbuf_later(INVERTED);
      showmode();
    }
    break;
  /*
   * "gV": Don't reselect the previous Visual area after a Select mode
   *	     mapping of menu.
   */
  case 'V':
    VIsual_reselect = false;
    break;

  /*
   * "gh":  start Select mode.
   * "gH":  start Select line mode.
   * "g^H": start Select block mode.
   */
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

  /* "gn", "gN" visually select next/previous search match
   * "gn" selects next match
   * "gN" selects previous match
   */
  case 'N':
  case 'n':
    if (!current_search(cap->count1, cap->nchar == 'n'))
      clearopbeep(oap);
    break;

  /*
   * "gj" and "gk" two new funny movement keys -- up and down
   * movement based on *screen* line rather than *file* line.
   */
  case 'j':
  case K_DOWN:
    /* with 'nowrap' it works just like the normal "j" command; also when
     * in a closed fold */
    if (!curwin->w_p_wrap
        || hasFolding(curwin->w_cursor.lnum, NULL, NULL)
        ) {
      oap->motion_type = kMTLineWise;
      i = cursor_down(cap->count1, oap->op_type == OP_NOP);
    } else
      i = nv_screengo(oap, FORWARD, cap->count1);
    if (!i)
      clearopbeep(oap);
    break;

  case 'k':
  case K_UP:
    /* with 'nowrap' it works just like the normal "k" command; also when
     * in a closed fold */
    if (!curwin->w_p_wrap
        || hasFolding(curwin->w_cursor.lnum, NULL, NULL)
        ) {
      oap->motion_type = kMTLineWise;
      i = cursor_up(cap->count1, oap->op_type == OP_NOP);
    } else
      i = nv_screengo(oap, BACKWARD, cap->count1);
    if (!i)
      clearopbeep(oap);
    break;

  /*
   * "gJ": join two lines without inserting a space.
   */
  case 'J':
    nv_join(cap);
    break;

  /*
   * "g0", "g^" and "g$": Like "0", "^" and "$" but for screen lines.
   * "gm": middle of "g0" and "g$".
   */
  case '^':
    flag = true;
    FALLTHROUGH;

  case '0':
  case 'm':
  case K_HOME:
  case K_KHOME:
    oap->motion_type = kMTCharWise;
    oap->inclusive = false;
    if (curwin->w_p_wrap
        && curwin->w_grid.Columns != 0
        ) {
      int width1 = curwin->w_grid.Columns - curwin_col_off();
      int width2 = width1 + curwin_col_off2();

      validate_virtcol();
      i = 0;
      if (curwin->w_virtcol >= (colnr_T)width1 && width2 > 0)
        i = (curwin->w_virtcol - width1) / width2 * width2 + width1;
    } else
      i = curwin->w_leftcol;
    /* Go to the middle of the screen line.  When 'number' or
     * 'relativenumber' is on and lines are wrapping the middle can be more
     * to the left. */
    if (cap->nchar == 'm') {
      i += (curwin->w_grid.Columns - curwin_col_off()
            + ((curwin->w_p_wrap && i > 0)
               ? curwin_col_off2() : 0)) / 2;
    }
    coladvance((colnr_T)i);
    if (flag) {
      do
        i = gchar_cursor();
      while (ascii_iswhite(i) && oneright());
    }
    curwin->w_set_curswant = true;
    break;

  case '_':
    /* "g_": to the last non-blank character in the line or <count> lines
     * downward. */
    cap->oap->motion_type = kMTCharWise;
    cap->oap->inclusive = true;
    curwin->w_curswant = MAXCOL;
    if (cursor_down(cap->count1 - 1,
            cap->oap->op_type == OP_NOP) == false)
      clearopbeep(cap->oap);
    else {
      char_u  *ptr = get_cursor_line_ptr();

      /* In Visual mode we may end up after the line. */
      if (curwin->w_cursor.col > 0 && ptr[curwin->w_cursor.col] == NUL)
        --curwin->w_cursor.col;

      /* Decrease the cursor column until it's on a non-blank. */
      while (curwin->w_cursor.col > 0
             && ascii_iswhite(ptr[curwin->w_cursor.col]))
        --curwin->w_cursor.col;
      curwin->w_set_curswant = true;
      adjust_for_sel(cap);
    }
    break;

  case '$':
  case K_END:
  case K_KEND:
  {
    int col_off = curwin_col_off();

    oap->motion_type = kMTCharWise;
    oap->inclusive = true;
    if (curwin->w_p_wrap
        && curwin->w_grid.Columns != 0
        ) {
      curwin->w_curswant = MAXCOL;              /* so we stay at the end */
      if (cap->count1 == 1) {
        int width1 = curwin->w_grid.Columns - col_off;
        int width2 = width1 + curwin_col_off2();

        validate_virtcol();
        i = width1 - 1;
        if (curwin->w_virtcol >= (colnr_T)width1)
          i += ((curwin->w_virtcol - width1) / width2 + 1)
               * width2;
        coladvance((colnr_T)i);

        /* Make sure we stick in this column. */
        validate_virtcol();
        curwin->w_curswant = curwin->w_virtcol;
        curwin->w_set_curswant = false;
        if (curwin->w_cursor.col > 0 && curwin->w_p_wrap) {
          /*
           * Check for landing on a character that got split at
           * the end of the line.  We do not want to advance to
           * the next screen line.
           */
          if (curwin->w_virtcol > (colnr_T)i)
            --curwin->w_cursor.col;
        }
      } else if (nv_screengo(oap, FORWARD, cap->count1 - 1) == false)
        clearopbeep(oap);
    } else {
      i = curwin->w_leftcol + curwin->w_grid.Columns - col_off - 1;
      coladvance((colnr_T)i);

      /* Make sure we stick in this column. */
      validate_virtcol();
      curwin->w_curswant = curwin->w_virtcol;
      curwin->w_set_curswant = false;
    }
  }
  break;

  /*
   * "g*" and "g#", like "*" and "#" but without using "\<" and "\>"
   */
  case '*':
  case '#':
#if POUND != '#'
  case POUND:           /* pound sign (sometimes equal to '#') */
#endif
  case Ctrl_RSB:                /* :tag or :tselect for current identifier */
  case ']':                     /* :tselect for current identifier */
    nv_ident(cap);
    break;

  /*
   * ge and gE: go back to end of word
   */
  case 'e':
  case 'E':
    oap->motion_type = kMTCharWise;
    curwin->w_set_curswant = true;
    oap->inclusive = true;
    if (bckend_word(cap->count1, cap->nchar == 'E', false) == false)
      clearopbeep(oap);
    break;

  // "g CTRL-G": display info about cursor position
  case Ctrl_G:
    cursor_pos_info(NULL);
    break;

  // "gi": start Insert at the last position.
  case 'i':
    if (curbuf->b_last_insert.mark.lnum != 0) {
      curwin->w_cursor = curbuf->b_last_insert.mark;
      check_cursor_lnum();
      i = (int)STRLEN(get_cursor_line_ptr());
      if (curwin->w_cursor.col > (colnr_T)i) {
        if (virtual_active())
          curwin->w_cursor.coladd += curwin->w_cursor.col - i;
        curwin->w_cursor.col = i;
      }
    }
    cap->cmdchar = 'i';
    nv_edit(cap);
    break;

  /*
   * "gI": Start insert in column 1.
   */
  case 'I':
    beginline(0);
    if (!checkclearopq(oap))
      invoke_edit(cap, false, 'g', false);
    break;

  /*
   * "gf": goto file, edit file under cursor
   * "]f" and "[f": can also be used.
   */
  case 'f':
  case 'F':
    nv_gotofile(cap);
    break;

  /* "g'm" and "g`m": jump to mark without setting pcmark */
  case '\'':
    cap->arg = true;
    FALLTHROUGH;
  case '`':
    nv_gomark(cap);
    break;

  /*
   * "gs": Goto sleep.
   */
  case 's':
    do_sleep(cap->count1 * 1000L);
    break;

  /*
   * "ga": Display the ascii value of the character under the
   * cursor.	It is displayed in decimal, hex, and octal. -- webb
   */
  case 'a':
    do_ascii(NULL);
    break;

  /*
   * "g8": Display the bytes used for the UTF-8 character under the
   * cursor.	It is displayed in hex.
   * "8g8" finds illegal byte sequence.
   */
  case '8':
    if (cap->count0 == 8)
      utf_find_illegal();
    else
      show_utf8();
    break;
  // "g<": show scrollback text
  case '<':
    show_sb_text();
    break;

  /*
   * "gg": Goto the first line in file.  With a count it goes to
   * that line number like for "G". -- webb
   */
  case 'g':
    cap->arg = false;
    nv_goto(cap);
    break;

  /*
   *	 Two-character operators:
   *	 "gq"	    Format text
   *	 "gw"	    Format text and keep cursor position
   *	 "g~"	    Toggle the case of the text.
   *	 "gu"	    Change text to lower case.
   *	 "gU"	    Change text to upper case.
   *   "g?"	    rot13 encoding
   *   "g@"	    call 'operatorfunc'
   */
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

  /*
   * "gd": Find first occurrence of pattern under the cursor in the
   *	 current function
   * "gD": idem, but in the current file.
   */
  case 'd':
  case 'D':
    nv_gd(oap, cap->nchar, (int)cap->count0);
    break;

  /*
   * g<*Mouse> : <C-*mouse>
   */
  case K_MIDDLEMOUSE:
  case K_MIDDLEDRAG:
  case K_MIDDLERELEASE:
  case K_LEFTMOUSE:
  case K_LEFTDRAG:
  case K_LEFTRELEASE:
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
    (void)do_mouse(oap, cap->nchar, BACKWARD, cap->count1, 0);
    break;

  case K_IGNORE:
    break;

  /*
   * "gP" and "gp": same as "P" and "p" but leave cursor just after new text
   */
  case 'p':
  case 'P':
    nv_put(cap);
    break;

  /* "go": goto byte count from start of buffer */
  case 'o':
    goto_byte(cap->count0);
    break;

  /* "gQ": improved Ex mode */
  case 'Q':
    if (text_locked()) {
      clearopbeep(cap->oap);
      text_locked_msg();
      break;
    }

    if (!checkclearopq(oap))
      do_exmode(true);
    break;

  case ',':
    nv_pcmark(cap);
    break;

  case ';':
    cap->count1 = -cap->count1;
    nv_pcmark(cap);
    break;

  case 't':
    if (!checkclearop(oap))
      goto_tabpage((int)cap->count0);
    break;
  case 'T':
    if (!checkclearop(oap))
      goto_tabpage(-(int)cap->count1);
    break;

  case '+':
  case '-':   /* "g+" and "g-": undo or redo along the timeline */
    if (!checkclearopq(oap))
      undo_time(cap->nchar == '-' ? -cap->count1 : cap->count1,
          false, false, false);
    break;

  default:
    clearopbeep(oap);
    break;
  }
}

/*
 * Handle "o" and "O" commands.
 */
static void n_opencmd(cmdarg_T *cap)
{
  linenr_T oldline = curwin->w_cursor.lnum;

  if (!checkclearopq(cap->oap)) {
    if (cap->cmdchar == 'O')
      /* Open above the first line of a folded sequence of lines */
      (void)hasFolding(curwin->w_cursor.lnum,
          &curwin->w_cursor.lnum, NULL);
    else
      /* Open below the last line of a folded sequence of lines */
      (void)hasFolding(curwin->w_cursor.lnum,
          NULL, &curwin->w_cursor.lnum);
    if (u_save((linenr_T)(curwin->w_cursor.lnum -
                          (cap->cmdchar == 'O' ? 1 : 0)),
            (linenr_T)(curwin->w_cursor.lnum +
                       (cap->cmdchar == 'o' ? 1 : 0))
            )
        && open_line(cap->cmdchar == 'O' ? BACKWARD : FORWARD,
                     has_format_option(FO_OPEN_COMS)
                     ? OPENLINE_DO_COM : 0,
                     0)) {
      if (curwin->w_p_cole > 0 && oldline != curwin->w_cursor.lnum) {
        update_single_line(curwin, oldline);
      }
      if (curwin->w_p_cul) {
        // force redraw of cursorline
        curwin->w_valid &= ~VALID_CROW;
      }
      invoke_edit(cap, false, cap->cmdchar, true);
    }
  }
}

/*
 * "." command: redo last change.
 */
static void nv_dot(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap)) {
    /*
     * If "restart_edit" is true, the last but one command is repeated
     * instead of the last command (inserting text). This is used for
     * CTRL-O <.> in insert mode.
     */
    if (start_redo(cap->count0, restart_edit != 0 && !arrow_used) == false)
      clearopbeep(cap->oap);
  }
}

/*
 * CTRL-R: undo undo
 */
static void nv_redo(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap)) {
    u_redo((int)cap->count1);
    curwin->w_set_curswant = true;
  }
}

/*
 * Handle "U" command.
 */
static void nv_Undo(cmdarg_T *cap)
{
  /* In Visual mode and typing "gUU" triggers an operator */
  if (cap->oap->op_type == OP_UPPER
      || VIsual_active
      ) {
    /* translate "gUU" to "gUgU" */
    cap->cmdchar = 'g';
    cap->nchar = 'U';
    nv_operator(cap);
  } else if (!checkclearopq(cap->oap)) {
    u_undoline();
    curwin->w_set_curswant = true;
  }
}

/*
 * '~' command: If tilde is not an operator and Visual is off: swap case of a
 * single character.
 */
static void nv_tilde(cmdarg_T *cap)
{
  if (!p_to
      && !VIsual_active
      && cap->oap->op_type != OP_TILDE)
    n_swapchar(cap);
  else
    nv_operator(cap);
}

/*
 * Handle an operator command.
 * The actual work is done by do_pending_operator().
 */
static void nv_operator(cmdarg_T *cap)
{
  int op_type;

  op_type = get_op_type(cap->cmdchar, cap->nchar);

  if (op_type == cap->oap->op_type)         /* double operator works on lines */
    nv_lineop(cap);
  else if (!checkclearop(cap->oap)) {
    cap->oap->start = curwin->w_cursor;
    cap->oap->op_type = op_type;
    set_op_var(op_type);
  }
}

/*
 * Set v:operator to the characters for "optype".
 */
static void set_op_var(int optype)
{
  if (optype == OP_NOP) {
    set_vim_var_string(VV_OP, NULL, 0);
  } else {
    char opchars[3];
    int opchar0 = get_op_char(optype);
    assert(opchar0 >= 0 && opchar0 <= UCHAR_MAX);
    opchars[0] = (char) opchar0;

    int opchar1 = get_extra_op_char(optype);
    assert(opchar1 >= 0 && opchar1 <= UCHAR_MAX);
    opchars[1] = (char) opchar1;

    opchars[2] = NUL;
    set_vim_var_string(VV_OP, opchars, -1);
  }
}

/*
 * Handle linewise operator "dd", "yy", etc.
 *
 * "_" is is a strange motion command that helps make operators more logical.
 * It is actually implemented, but not documented in the real Vi.  This motion
 * command actually refers to "the current line".  Commands like "dd" and "yy"
 * are really an alternate form of "d_" and "y_".  It does accept a count, so
 * "d3_" works to delete 3 lines.
 */
static void nv_lineop(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTLineWise;
  if (cursor_down(cap->count1 - 1L, cap->oap->op_type == OP_NOP) == false) {
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

/*
 * <Home> command.
 */
static void nv_home(cmdarg_T *cap)
{
  /* CTRL-HOME is like "gg" */
  if (mod_mask & MOD_MASK_CTRL)
    nv_goto(cap);
  else {
    cap->count0 = 1;
    nv_pipe(cap);
  }
  ins_at_eol = false;       /* Don't move cursor past eol (only necessary in a
                               one-character line). */
}

/*
 * "|" command.
 */
static void nv_pipe(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  beginline(0);
  if (cap->count0 > 0) {
    coladvance((colnr_T)(cap->count0 - 1));
    curwin->w_curswant = (colnr_T)(cap->count0 - 1);
  } else
    curwin->w_curswant = 0;
  /* keep curswant at the column where we wanted to go, not where
   * we ended; differs if line is too short */
  curwin->w_set_curswant = false;
}

/*
 * Handle back-word command "b" and "B".
 * cap->arg is 1 for "B"
 */
static void nv_bck_word(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  curwin->w_set_curswant = true;
  if (bck_word(cap->count1, cap->arg, false) == false)
    clearopbeep(cap->oap);
  else if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP)
    foldOpenCursor();
}

/*
 * Handle word motion commands "e", "E", "w" and "W".
 * cap->arg is true for "E" and "W".
 */
static void nv_wordcmd(cmdarg_T *cap)
{
  int n;
  bool word_end;
  bool flag = false;
  pos_T startpos = curwin->w_cursor;

  /*
   * Set inclusive for the "E" and "e" command.
   */
  if (cap->cmdchar == 'e' || cap->cmdchar == 'E')
    word_end = true;
  else
    word_end = false;
  cap->oap->inclusive = word_end;

  /*
   * "cw" and "cW" are a special case.
   */
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
  if (word_end)
    n = end_word(cap->count1, cap->arg, flag, false);
  else
    n = fwd_word(cap->count1, cap->arg, cap->oap->op_type != OP_NOP);

  /* Don't leave the cursor on the NUL past the end of line. Unless we
   * didn't move it forward. */
  if (lt(startpos, curwin->w_cursor))
    adjust_cursor(cap->oap);

  if (n == false && cap->oap->op_type == OP_NOP)
    clearopbeep(cap->oap);
  else {
    adjust_for_sel(cap);
    if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP)
      foldOpenCursor();
  }
}

/*
 * Used after a movement command: If the cursor ends up on the NUL after the
 * end of the line, may move it back to the last character and make the motion
 * inclusive.
 */
static void adjust_cursor(oparg_T *oap)
{
  /* The cursor cannot remain on the NUL when:
   * - the column is > 0
   * - not in Visual mode or 'selection' is "o"
   * - 'virtualedit' is not "all" and not "onemore".
   */
  if (curwin->w_cursor.col > 0 && gchar_cursor() == NUL
      && (!VIsual_active || *p_sel == 'o')
      && !virtual_active() && (ve_flags & VE_ONEMORE) == 0
      ) {
    --curwin->w_cursor.col;
    /* prevent cursor from moving on the trail byte */
    if (has_mbyte)
      mb_adjust_cursor();
    oap->inclusive = true;
  }
}

/*
 * "0" and "^" commands.
 * cap->arg is the argument for beginline().
 */
static void nv_beginline(cmdarg_T *cap)
{
  cap->oap->motion_type = kMTCharWise;
  cap->oap->inclusive = false;
  beginline(cap->arg);
  if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP)
    foldOpenCursor();
  ins_at_eol = false;       /* Don't move cursor past eol (only necessary in a
                               one-character line). */
}

/*
 * In exclusive Visual mode, may include the last character.
 */
static void adjust_for_sel(cmdarg_T *cap)
{
  if (VIsual_active && cap->oap->inclusive && *p_sel == 'e'
      && gchar_cursor() != NUL && lt(VIsual, curwin->w_cursor)) {
    if (has_mbyte)
      inc_cursor();
    else
      ++curwin->w_cursor.col;
    cap->oap->inclusive = false;
  }
}

/*
 * Exclude last character at end of Visual area for 'selection' == "exclusive".
 * Should check VIsual_mode before calling this.
 * Returns true when backed up to the previous line.
 */
static bool unadjust_for_sel(void)
{
  pos_T       *pp;

  if (*p_sel == 'e' && !equalpos(VIsual, curwin->w_cursor)) {
    if (lt(VIsual, curwin->w_cursor))
      pp = &curwin->w_cursor;
    else
      pp = &VIsual;
    if (pp->coladd > 0) {
      pp->coladd--;
    } else if (pp->col > 0) {
      pp->col--;
      mark_mb_adjustpos(curbuf, pp);
    } else if (pp->lnum > 1) {
      --pp->lnum;
      pp->col = (colnr_T)STRLEN(ml_get(pp->lnum));
      return true;
    }
  }
  return false;
}

/*
 * SELECT key in Normal or Visual mode: end of Select mode mapping.
 */
static void nv_select(cmdarg_T *cap)
{
  if (VIsual_active)
    VIsual_select = true;
  else if (VIsual_reselect) {
    cap->nchar = 'v';               /* fake "gv" command */
    cap->arg = true;
    nv_g_cmd(cap);
  }
}


/*
 * "G", "gg", CTRL-END, CTRL-HOME.
 * cap->arg is true for "G".
 */
static void nv_goto(cmdarg_T *cap)
{
  linenr_T lnum;

  if (cap->arg)
    lnum = curbuf->b_ml.ml_line_count;
  else
    lnum = 1L;
  cap->oap->motion_type = kMTLineWise;
  setpcmark();

  /* When a count is given, use it instead of the default lnum */
  if (cap->count0 != 0)
    lnum = cap->count0;
  if (lnum < 1L)
    lnum = 1L;
  else if (lnum > curbuf->b_ml.ml_line_count)
    lnum = curbuf->b_ml.ml_line_count;
  curwin->w_cursor.lnum = lnum;
  beginline(BL_SOL | BL_FIX);
  if ((fdo_flags & FDO_JUMP) && KeyTyped && cap->oap->op_type == OP_NOP)
    foldOpenCursor();
}

/*
 * CTRL-\ in Normal mode.
 */
static void nv_normal(cmdarg_T *cap)
{
  if (cap->nchar == Ctrl_N || cap->nchar == Ctrl_G) {
    clearop(cap->oap);
    if (restart_edit != 0 && mode_displayed)
      clear_cmdline = true;                     /* unshow mode later */
    restart_edit = 0;
    if (cmdwin_type != 0)
      cmdwin_result = Ctrl_C;
    if (VIsual_active) {
      end_visual_mode();                /* stop Visual */
      redraw_curbuf_later(INVERTED);
    }
    /* CTRL-\ CTRL-G restarts Insert mode when 'insertmode' is set. */
    if (cap->nchar == Ctrl_G && p_im)
      restart_edit = 'a';
  } else
    clearopbeep(cap->oap);
}

/*
 * ESC in Normal mode: beep, but don't flush buffers.
 * Don't even beep if we are canceling a command.
 */
static void nv_esc(cmdarg_T *cap)
{
  int no_reason;

  no_reason = (cap->oap->op_type == OP_NOP
               && cap->opcount == 0
               && cap->count0 == 0
               && cap->oap->regname == 0
               && !p_im);

  if (cap->arg) {               /* true for CTRL-C */
    if (restart_edit == 0
        && cmdwin_type == 0
        && !VIsual_active
        && no_reason) {
      MSG(_("Type  :qa!  and press <Enter> to abandon all changes"
            " and exit Nvim"));
    }

    /* Don't reset "restart_edit" when 'insertmode' is set, it won't be
     * set again below when halfway through a mapping. */
    if (!p_im)
      restart_edit = 0;
    if (cmdwin_type != 0) {
      cmdwin_result = K_IGNORE;
      got_int = false;          /* don't stop executing autocommands et al. */
      return;
    }
  }

  if (VIsual_active) {
    end_visual_mode();          /* stop Visual */
    check_cursor_col();         /* make sure cursor is not beyond EOL */
    curwin->w_set_curswant = true;
    redraw_curbuf_later(INVERTED);
  } else if (no_reason) {
    vim_beep(BO_ESC);
  }
  clearop(cap->oap);

  /* A CTRL-C is often used at the start of a menu.  When 'insertmode' is
   * set return to Insert mode afterwards. */
  if (restart_edit == 0 && goto_im()
      && ex_normal_busy == 0
      )
    restart_edit = 'a';
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
  } else if (!curbuf->b_p_ma && !p_im && !curbuf->terminal) {
    // Only give this error when 'insertmode' is off.
    EMSG(_(e_modifiable));
    clearop(cap->oap);
  } else if (!checkclearopq(cap->oap)) {
    switch (cap->cmdchar) {
    case 'A':           /* "A"ppend after the line */
      curwin->w_set_curswant = true;
      if (ve_flags == VE_ALL) {
        int save_State = State;

        /* Pretend Insert mode here to allow the cursor on the
         * character past the end of the line */
        State = INSERT;
        coladvance((colnr_T)MAXCOL);
        State = save_State;
      } else
        curwin->w_cursor.col += (colnr_T)STRLEN(get_cursor_pos_ptr());
      break;

    case 'I':           /* "I"nsert before the first non-blank */
      beginline(BL_WHITE);
      break;

    case 'a':           /* "a"ppend is like "i"nsert on the next character. */
      /* increment coladd when in virtual space, increment the
       * column otherwise, also to append after an unprintable char */
      if (virtual_active()
          && (curwin->w_cursor.coladd > 0
              || *get_cursor_pos_ptr() == NUL
              || *get_cursor_pos_ptr() == TAB))
        curwin->w_cursor.coladd++;
      else if (*get_cursor_pos_ptr() != NUL)
        inc_cursor();
      break;
    }

    if (curwin->w_cursor.coladd && cap->cmdchar != 'A') {
      int save_State = State;

      /* Pretend Insert mode here to allow the cursor on the
       * character past the end of the line */
      State = INSERT;
      coladvance(getviscol());
      State = save_State;
    }

    invoke_edit(cap, false, cap->cmdchar, false);
  }
}

/*
 * Invoke edit() and take care of "restart_edit" and the return value.
 */
static void
invoke_edit (
    cmdarg_T *cap,
    int repl,                       /* "r" or "gr" command */
    int cmd,
    int startln
)
{
  int restart_edit_save = 0;

  /* Complicated: When the user types "a<C-O>a" we don't want to do Insert
   * mode recursively.  But when doing "a<C-O>." or "a<C-O>rx" we do allow
   * it. */
  if (repl || !stuff_empty())
    restart_edit_save = restart_edit;
  else
    restart_edit_save = 0;

  /* Always reset "restart_edit", this is not a restarted edit. */
  restart_edit = 0;

  if (edit(cmd, startln, cap->count1))
    cap->retval |= CA_COMMAND_BUSY;

  if (restart_edit == 0)
    restart_edit = restart_edit_save;
}

/*
 * "a" or "i" while an operator is pending or in Visual mode: object motion.
 */
static void nv_object(cmdarg_T *cap)
{
  bool flag;
  bool include;
  char_u      *mps_save;

  if (cap->cmdchar == 'i')
    include = false;        /* "ix" = inner object: exclude white space */
  else
    include = true;         /* "ax" = an object: include white space */

  /* Make sure (), [], {} and <> are in 'matchpairs' */
  mps_save = curbuf->b_p_mps;
  curbuf->b_p_mps = (char_u *)"(:),{:},[:],<:>";

  switch (cap->nchar) {
  case 'w':       /* "aw" = a word */
    flag = current_word(cap->oap, cap->count1, include, false);
    break;
  case 'W':       /* "aW" = a WORD */
    flag = current_word(cap->oap, cap->count1, include, true);
    break;
  case 'b':       /* "ab" = a braces block */
  case '(':
  case ')':
    flag = current_block(cap->oap, cap->count1, include, '(', ')');
    break;
  case 'B':       /* "aB" = a Brackets block */
  case '{':
  case '}':
    flag = current_block(cap->oap, cap->count1, include, '{', '}');
    break;
  case '[':       /* "a[" = a [] block */
  case ']':
    flag = current_block(cap->oap, cap->count1, include, '[', ']');
    break;
  case '<':       /* "a<" = a <> block */
  case '>':
    flag = current_block(cap->oap, cap->count1, include, '<', '>');
    break;
  case 't':       /* "at" = a tag block (xml and html) */
    // Do not adjust oap->end in do_pending_operator()
    // otherwise there are different results for 'dit'
    // (note leading whitespace in last line):
    // 1) <b>      2) <b>
    //    foobar      foobar
    //    </b>            </b>
    cap->retval |= CA_NO_ADJ_OP_END;
    flag = current_tagblock(cap->oap, cap->count1, include);
    break;
  case 'p':       /* "ap" = a paragraph */
    flag = current_par(cap->oap, cap->count1, include, 'p');
    break;
  case 's':       /* "as" = a sentence */
    flag = current_sent(cap->oap, cap->count1, include);
    break;
  case '"':       /* "a"" = a double quoted string */
  case '\'':       /* "a'" = a single quoted string */
  case '`':       /* "a`" = a backtick quoted string */
    flag = current_quote(cap->oap, cap->count1, include,
        cap->nchar);
    break;
  default:
    flag = false;
    break;
  }

  curbuf->b_p_mps = mps_save;
  if (!flag)
    clearopbeep(cap->oap);
  adjust_cursor_col();
  curwin->w_set_curswant = true;
}

/*
 * "q" command: Start/stop recording.
 * "q:", "q/", "q?": edit command-line in command-line window.
 */
static void nv_record(cmdarg_T *cap)
{
  if (cap->oap->op_type == OP_FORMAT) {
    /* "gqq" is the same as "gqgq": format line */
    cap->cmdchar = 'g';
    cap->nchar = 'q';
    nv_operator(cap);
  } else if (!checkclearop(cap->oap)) {
    if (cap->nchar == ':' || cap->nchar == '/' || cap->nchar == '?') {
      stuffcharReadbuff(cap->nchar);
      stuffcharReadbuff(K_CMDWIN);
    } else {
      // (stop) recording into a named register, unless executing a
      // register.
      if (!Exec_reg && do_record(cap->nchar) == FAIL) {
        clearopbeep(cap->oap);
      }
    }
  }
}

/*
 * Handle the "@r" command.
 */
static void nv_at(cmdarg_T *cap)
{
  if (checkclearop(cap->oap))
    return;
  if (cap->nchar == '=') {
    if (get_expr_register() == NUL)
      return;
  }
  while (cap->count1-- && !got_int) {
    if (do_execreg(cap->nchar, false, false, false) == false) {
      clearopbeep(cap->oap);
      break;
    }
    line_breakcheck();
  }
}

/*
 * Handle the CTRL-U and CTRL-D commands.
 */
static void nv_halfpage(cmdarg_T *cap)
{
  if ((cap->cmdchar == Ctrl_U && curwin->w_cursor.lnum == 1)
      || (cap->cmdchar == Ctrl_D
          && curwin->w_cursor.lnum == curbuf->b_ml.ml_line_count))
    clearopbeep(cap->oap);
  else if (!checkclearop(cap->oap))
    halfpage(cap->cmdchar == Ctrl_D, cap->count0);
}

/*
 * Handle "J" or "gJ" command.
 */
static void nv_join(cmdarg_T *cap)
{
  if (VIsual_active) {  // join the visual lines
    nv_operator(cap);
  } else if (!checkclearop(cap->oap)) {
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
}

/*
 * "P", "gP", "p" and "gp" commands.
 */
static void nv_put(cmdarg_T *cap)
{
  int regname = 0;
  yankreg_T *savereg = NULL;
  bool empty = false;
  bool was_visual = false;
  int dir;
  int flags = 0;

  if (cap->oap->op_type != OP_NOP) {
    /* "dp" is ":diffput" */
    if (cap->oap->op_type == OP_DELETE && cap->cmdchar == 'p') {
      clearop(cap->oap);
      assert(cap->opcount >= 0);
      nv_diffgetput(true, (size_t)cap->opcount);
    } else
      clearopbeep(cap->oap);
  } else {
    dir = (cap->cmdchar == 'P'
           || (cap->cmdchar == 'g' && cap->nchar == 'P'))
          ? BACKWARD : FORWARD;
    prep_redo_cmd(cap);
    if (cap->cmdchar == 'g')
      flags |= PUT_CURSEND;

    if (VIsual_active) {
      /* Putting in Visual mode: The put text replaces the selected
       * text.  First delete the selected text, then put the new text.
       * Need to save and restore the registers that the delete
       * overwrites if the old contents is being put.
       */
      was_visual = true;
      regname = cap->oap->regname;
      // '+' and '*' could be the same selection
      bool clipoverwrite = (regname == '+' || regname == '*')
          && (cb_flags & CB_UNNAMEDMASK);
      if (regname == 0 || regname == '"' || clipoverwrite
          || ascii_isdigit(regname) || regname == '-') {
        // The delete might overwrite the register we want to put, save it first
        savereg = copy_register(regname);
      }

      // To place the cursor correctly after a blockwise put, and to leave the
      // text in the correct position when putting over a selection with
      // 'virtualedit' and past the end of the line, we use the 'c' operator in
      // do_put(), which requires the visual selection to still be active.
      if (!VIsual_active || VIsual_mode == 'V' || regname != '.') {
        // Now delete the selected text.
        cap->cmdchar = 'd';
        cap->nchar = NUL;
        cap->oap->regname = NUL;
        nv_operator(cap);
        do_pending_operator(cap, 0, false);
        empty = (curbuf->b_ml.ml_flags & ML_EMPTY);

        // delete PUT_LINE_BACKWARD;
        cap->oap->regname = regname;
      }

      /* When deleted a linewise Visual area, put the register as
       * lines to avoid it joined with the next line.  When deletion was
       * characterwise, split a line when putting lines. */
      if (VIsual_mode == 'V')
        flags |= PUT_LINE;
      else if (VIsual_mode == 'v')
        flags |= PUT_LINE_SPLIT;
      if (VIsual_mode == Ctrl_V && dir == FORWARD)
        flags |= PUT_LINE_FORWARD;
      dir = BACKWARD;
      if ((VIsual_mode != 'V'
           && curwin->w_cursor.col < curbuf->b_op_start.col)
          || (VIsual_mode == 'V'
              && curwin->w_cursor.lnum < curbuf->b_op_start.lnum))
        /* cursor is at the end of the line or end of file, put
         * forward. */
        dir = FORWARD;
      /* May have been reset in do_put(). */
      VIsual_active = true;
    }
    do_put(cap->oap->regname, savereg, dir, cap->count1, flags);

    // If a register was saved, free it
    if (savereg != NULL) {
      free_register(savereg);
      xfree(savereg);
    }

    /* What to reselect with "gv"?  Selecting the just put text seems to
     * be the most useful, since the original text was removed. */
    if (was_visual) {
      curbuf->b_visual.vi_start = curbuf->b_op_start;
      curbuf->b_visual.vi_end = curbuf->b_op_end;
      // need to adjust cursor position
      if (*p_sel == 'e') {
        inc(&curbuf->b_visual.vi_end);
      }
    }

    /* When all lines were selected and deleted do_put() leaves an empty
     * line that needs to be deleted now. */
    if (empty && *ml_get(curbuf->b_ml.ml_line_count) == NUL) {
      ml_delete(curbuf->b_ml.ml_line_count, true);

      /* If the cursor was in that line, move it to the end of the last
       * line. */
      if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
        coladvance((colnr_T)MAXCOL);
      }
    }
    auto_format(false, true);
  }
}

/*
 * "o" and "O" commands.
 */
static void nv_open(cmdarg_T *cap)
{
  /* "do" is ":diffget" */
  if (cap->oap->op_type == OP_DELETE && cap->cmdchar == 'o') {
    clearop(cap->oap);
    assert(cap->opcount >= 0);
    nv_diffgetput(false, (size_t)cap->opcount);
  } else if (VIsual_active) /* switch start and end of visual */
    v_swap_corners(cap->cmdchar);
  else
    n_opencmd(cap);
}

// Calculate start/end virtual columns for operating in block mode.
static void get_op_vcol(
    oparg_T *oap,
    colnr_T redo_VIsual_vcol,
    bool initial  // when true: adjust position for 'selectmode'
)
{
  colnr_T start;
  colnr_T end;

  if (VIsual_mode != Ctrl_V
      || (!initial && oap->end.col < curwin->w_grid.Columns)) {
    return;
  }

  oap->motion_type = kMTBlockWise;

  // prevent from moving onto a trail byte
  if (has_mbyte) {
    mark_mb_adjustpos(curwin->w_buffer, &oap->end);
  }

  getvvcol(curwin, &(oap->start), &oap->start_vcol, NULL, &oap->end_vcol);
  if (!redo_VIsual_busy) {
    getvvcol(curwin, &(oap->end), &start, NULL, &end);

    if (start < oap->start_vcol) {
      oap->start_vcol = start;
    }
    if (end > oap->end_vcol) {
      if (initial && *p_sel == 'e'
          && start >= 1
          && start - 1 >= oap->end_vcol) {
        oap->end_vcol = start - 1;
      } else {
        oap->end_vcol = end;
      }
    }
  }

  // if '$' was used, get oap->end_vcol from longest line
  if (curwin->w_curswant == MAXCOL) {
    curwin->w_cursor.col = MAXCOL;
    oap->end_vcol = 0;
    for (curwin->w_cursor.lnum = oap->start.lnum;
         curwin->w_cursor.lnum <= oap->end.lnum; ++curwin->w_cursor.lnum) {
      getvvcol(curwin, &curwin->w_cursor, NULL, NULL, &end);
      if (end > oap->end_vcol) {
        oap->end_vcol = end;
      }
    }
  } else if (redo_VIsual_busy) {
    oap->end_vcol = oap->start_vcol + redo_VIsual_vcol - 1;
  }

  // Correct oap->end.col and oap->start.col to be the
  // upper-left and lower-right corner of the block area.
  //
  // (Actually, this does convert column positions into character
  // positions)
  curwin->w_cursor.lnum = oap->end.lnum;
  coladvance(oap->end_vcol);
  oap->end = curwin->w_cursor;

  curwin->w_cursor = oap->start;
  coladvance(oap->start_vcol);
  oap->start = curwin->w_cursor;
}

// Handle an arbitrary event in normal mode
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
  multiqueue_process_events(main_loop.events);
  cap->retval |= CA_COMMAND_BUSY;       // don't call edit() now
  finish_op = false;
}

/*
 * Return TRUE when 'mousemodel' is set to "popup" or "popup_setpos".
 */
static int mouse_model_popup(void)
{
  return p_mousem[0] == 'p';
}

void normal_cmd(oparg_T *oap, bool toplevel)
{
  NormalState s;
  normal_state_init(&s);
  s.toplevel = toplevel;
  s.oa = *oap;
  normal_prepare(&s);
  (void)normal_execute(&s.state, safe_vgetc());
  *oap = s.oa;
}
