/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */
/*
 * normal.c:	Contains the main routine for processing characters in command
 *		mode.  Communicates closely with the code in ops.c to handle
 *		the operators.
 */

#include "vim.h"
#include "normal.h"
#include "buffer.h"
#include "charset.h"
#include "diff.h"
#include "digraph.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_cmds2.h"
#include "ex_docmd.h"
#include "ex_getln.h"
#include "fileio.h"
#include "fold.h"
#include "getchar.h"
#include "main.h"
#include "mark.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "move.h"
#include "ops.h"
#include "option.h"
#include "quickfix.h"
#include "screen.h"
#include "search.h"
#include "spell.h"
#include "syntax.h"
#include "tag.h"
#include "term.h"
#include "ui.h"
#include "undo.h"
#include "window.h"

/*
 * The Visual area is remembered for reselection.
 */
static int resel_VIsual_mode = NUL;             /* 'v', 'V', or Ctrl-V */
static linenr_T resel_VIsual_line_count;        /* number of lines */
static colnr_T resel_VIsual_vcol;               /* nr of cols or end col */
static int VIsual_mode_orig = NUL;              /* type of Visual mode, that user entered */

static int restart_VIsual_select = 0;

static void set_vcount_ca(cmdarg_T *cap, int *set_prevcount);
static int
nv_compare(const void *s1, const void *s2);
static int find_command(int cmdchar);
static void op_colon(oparg_T *oap);
static void op_function(oparg_T *oap);
static void find_start_of_word(pos_T *);
static void find_end_of_word(pos_T *);
static int get_mouse_class(char_u *p);
static void prep_redo_cmd(cmdarg_T *cap);
static void prep_redo(int regname, long, int, int, int, int, int);
static int checkclearop(oparg_T *oap);
static int checkclearopq(oparg_T *oap);
static void clearop(oparg_T *oap);
static void clearopbeep(oparg_T *oap);
static void unshift_special(cmdarg_T *cap);
static void del_from_showcmd(int);

/*
 * nv_*(): functions called to handle Normal and Visual mode commands.
 * n_*(): functions called to handle Normal mode commands.
 * v_*(): functions called to handle Visual mode commands.
 */
static void nv_ignore(cmdarg_T *cap);
static void nv_nop(cmdarg_T *cap);
static void nv_error(cmdarg_T *cap);
static void nv_help(cmdarg_T *cap);
static void nv_addsub(cmdarg_T *cap);
static void nv_page(cmdarg_T *cap);
static void nv_gd(oparg_T *oap, int nchar, int thisblock);
static int nv_screengo(oparg_T *oap, int dir, long dist);
static void nv_mousescroll(cmdarg_T *cap);
static void nv_mouse(cmdarg_T *cap);
static void nv_scroll_line(cmdarg_T *cap);
static void nv_zet(cmdarg_T *cap);
static void nv_exmode(cmdarg_T *cap);
static void nv_colon(cmdarg_T *cap);
static void nv_ctrlg(cmdarg_T *cap);
static void nv_ctrlh(cmdarg_T *cap);
static void nv_clear(cmdarg_T *cap);
static void nv_ctrlo(cmdarg_T *cap);
static void nv_hat(cmdarg_T *cap);
static void nv_Zet(cmdarg_T *cap);
static void nv_ident(cmdarg_T *cap);
static void nv_tagpop(cmdarg_T *cap);
static void nv_scroll(cmdarg_T *cap);
static void nv_right(cmdarg_T *cap);
static void nv_left(cmdarg_T *cap);
static void nv_up(cmdarg_T *cap);
static void nv_down(cmdarg_T *cap);
static void nv_gotofile(cmdarg_T *cap);
static void nv_end(cmdarg_T *cap);
static void nv_dollar(cmdarg_T *cap);
static void nv_search(cmdarg_T *cap);
static void nv_next(cmdarg_T *cap);
static void normal_search(cmdarg_T *cap, int dir, char_u *pat, int opt);
static void nv_csearch(cmdarg_T *cap);
static void nv_brackets(cmdarg_T *cap);
static void nv_percent(cmdarg_T *cap);
static void nv_brace(cmdarg_T *cap);
static void nv_mark(cmdarg_T *cap);
static void nv_findpar(cmdarg_T *cap);
static void nv_undo(cmdarg_T *cap);
static void nv_kundo(cmdarg_T *cap);
static void nv_Replace(cmdarg_T *cap);
static void nv_vreplace(cmdarg_T *cap);
static void v_swap_corners(int cmdchar);
static void nv_replace(cmdarg_T *cap);
static void n_swapchar(cmdarg_T *cap);
static void nv_cursormark(cmdarg_T *cap, int flag, pos_T *pos);
static void v_visop(cmdarg_T *cap);
static void nv_subst(cmdarg_T *cap);
static void nv_abbrev(cmdarg_T *cap);
static void nv_optrans(cmdarg_T *cap);
static void nv_gomark(cmdarg_T *cap);
static void nv_pcmark(cmdarg_T *cap);
static void nv_regname(cmdarg_T *cap);
static void nv_visual(cmdarg_T *cap);
static void n_start_visual_mode(int c);
static void nv_window(cmdarg_T *cap);
static void nv_suspend(cmdarg_T *cap);
static void nv_g_cmd(cmdarg_T *cap);
static void n_opencmd(cmdarg_T *cap);
static void nv_dot(cmdarg_T *cap);
static void nv_redo(cmdarg_T *cap);
static void nv_Undo(cmdarg_T *cap);
static void nv_tilde(cmdarg_T *cap);
static void nv_operator(cmdarg_T *cap);
static void set_op_var(int optype);
static void nv_lineop(cmdarg_T *cap);
static void nv_home(cmdarg_T *cap);
static void nv_pipe(cmdarg_T *cap);
static void nv_bck_word(cmdarg_T *cap);
static void nv_wordcmd(cmdarg_T *cap);
static void nv_beginline(cmdarg_T *cap);
static void adjust_cursor(oparg_T *oap);
static void adjust_for_sel(cmdarg_T *cap);
static int unadjust_for_sel(void);
static void nv_select(cmdarg_T *cap);
static void nv_goto(cmdarg_T *cap);
static void nv_normal(cmdarg_T *cap);
static void nv_esc(cmdarg_T *oap);
static void nv_edit(cmdarg_T *cap);
static void invoke_edit(cmdarg_T *cap, int repl, int cmd, int startln);
static void nv_object(cmdarg_T *cap);
static void nv_record(cmdarg_T *cap);
static void nv_at(cmdarg_T *cap);
static void nv_halfpage(cmdarg_T *cap);
static void nv_join(cmdarg_T *cap);
static void nv_put(cmdarg_T *cap);
static void nv_open(cmdarg_T *cap);
static void nv_cursorhold(cmdarg_T *cap);

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
  short_u cmd_flags;            /* NV_ flags */
  short cmd_arg;                /* value for ca.arg */
} nv_cmds[] =
{
  {NUL,       nv_error,       0,                      0},
  {Ctrl_A,    nv_addsub,      0,                      0},
  {Ctrl_B,    nv_page,        NV_STS,                 BACKWARD},
  {Ctrl_C,    nv_esc,         0,                      TRUE},
  {Ctrl_D,    nv_halfpage,    0,                      0},
  {Ctrl_E,    nv_scroll_line, 0,                      TRUE},
  {Ctrl_F,    nv_page,        NV_STS,                 FORWARD},
  {Ctrl_G,    nv_ctrlg,       0,                      0},
  {Ctrl_H,    nv_ctrlh,       0,                      0},
  {Ctrl_I,    nv_pcmark,      0,                      0},
  {NL,        nv_down,        0,                      FALSE},
  {Ctrl_K,    nv_error,       0,                      0},
  {Ctrl_L,    nv_clear,       0,                      0},
  {Ctrl_M,    nv_down,        0,                      TRUE},
  {Ctrl_N,    nv_down,        NV_STS,                 FALSE},
  {Ctrl_O,    nv_ctrlo,       0,                      0},
  {Ctrl_P,    nv_up,          NV_STS,                 FALSE},
  {Ctrl_Q,    nv_visual,      0,                      FALSE},
  {Ctrl_R,    nv_redo,        0,                      0},
  {Ctrl_S,    nv_ignore,      0,                      0},
  {Ctrl_T,    nv_tagpop,      NV_NCW,                 0},
  {Ctrl_U,    nv_halfpage,    0,                      0},
  {Ctrl_V,    nv_visual,      0,                      FALSE},
  {'V',       nv_visual,      0,                      FALSE},
  {'v',       nv_visual,      0,                      FALSE},
  {Ctrl_W,    nv_window,      0,                      0},
  {Ctrl_X,    nv_addsub,      0,                      0},
  {Ctrl_Y,    nv_scroll_line, 0,                      FALSE},
  {Ctrl_Z,    nv_suspend,     0,                      0},
  {ESC,       nv_esc,         0,                      FALSE},
  {Ctrl_BSL,  nv_normal,      NV_NCH_ALW,             0},
  {Ctrl_RSB,  nv_ident,       NV_NCW,                 0},
  {Ctrl_HAT,  nv_hat,         NV_NCW,                 0},
  {Ctrl__,    nv_error,       0,                      0},
  {' ',       nv_right,       0,                      0},
  {'!',       nv_operator,    0,                      0},
  {'"',       nv_regname,     NV_NCH_NOP|NV_KEEPREG,  0},
  {'#',       nv_ident,       0,                      0},
  {'$',       nv_dollar,      0,                      0},
  {'%',       nv_percent,     0,                      0},
  {'&',       nv_optrans,     0,                      0},
  {'\'',      nv_gomark,      NV_NCH_ALW,             TRUE},
  {'(',       nv_brace,       0,                      BACKWARD},
  {')',       nv_brace,       0,                      FORWARD},
  {'*',       nv_ident,       0,                      0},
  {'+',       nv_down,        0,                      TRUE},
  {',',       nv_csearch,     0,                      TRUE},
  {'-',       nv_up,          0,                      TRUE},
  {'.',       nv_dot,         NV_KEEPREG,             0},
  {'/',       nv_search,      0,                      FALSE},
  {'0',       nv_beginline,   0,                      0},
  {'1',       nv_ignore,      0,                      0},
  {'2',       nv_ignore,      0,                      0},
  {'3',       nv_ignore,      0,                      0},
  {'4',       nv_ignore,      0,                      0},
  {'5',       nv_ignore,      0,                      0},
  {'6',       nv_ignore,      0,                      0},
  {'7',       nv_ignore,      0,                      0},
  {'8',       nv_ignore,      0,                      0},
  {'9',       nv_ignore,      0,                      0},
  {':',       nv_colon,       0,                      0},
  {';',       nv_csearch,     0,                      FALSE},
  {'<',       nv_operator,    NV_RL,                  0},
  {'=',       nv_operator,    0,                      0},
  {'>',       nv_operator,    NV_RL,                  0},
  {'?',       nv_search,      0,                      FALSE},
  {'@',       nv_at,          NV_NCH_NOP,             FALSE},
  {'A',       nv_edit,        0,                      0},
  {'B',       nv_bck_word,    0,                      1},
  {'C',       nv_abbrev,      NV_KEEPREG,             0},
  {'D',       nv_abbrev,      NV_KEEPREG,             0},
  {'E',       nv_wordcmd,     0,                      TRUE},
  {'F',       nv_csearch,     NV_NCH_ALW|NV_LANG,     BACKWARD},
  {'G',       nv_goto,        0,                      TRUE},
  {'H',       nv_scroll,      0,                      0},
  {'I',       nv_edit,        0,                      0},
  {'J',       nv_join,        0,                      0},
  {'K',       nv_ident,       0,                      0},
  {'L',       nv_scroll,      0,                      0},
  {'M',       nv_scroll,      0,                      0},
  {'N',       nv_next,        0,                      SEARCH_REV},
  {'O',       nv_open,        0,                      0},
  {'P',       nv_put,         0,                      0},
  {'Q',       nv_exmode,      NV_NCW,                 0},
  {'R',       nv_Replace,     0,                      FALSE},
  {'S',       nv_subst,       NV_KEEPREG,             0},
  {'T',       nv_csearch,     NV_NCH_ALW|NV_LANG,     BACKWARD},
  {'U',       nv_Undo,        0,                      0},
  {'W',       nv_wordcmd,     0,                      TRUE},
  {'X',       nv_abbrev,      NV_KEEPREG,             0},
  {'Y',       nv_abbrev,      NV_KEEPREG,             0},
  {'Z',       nv_Zet,         NV_NCH_NOP|NV_NCW,      0},
  {'[',       nv_brackets,    NV_NCH_ALW,             BACKWARD},
  {'\\',      nv_error,       0,                      0},
  {']',       nv_brackets,    NV_NCH_ALW,             FORWARD},
  {'^',       nv_beginline,   0,                      BL_WHITE | BL_FIX},
  {'_',       nv_lineop,      0,                      0},
  {'`',       nv_gomark,      NV_NCH_ALW,             FALSE},
  {'a',       nv_edit,        NV_NCH,                 0},
  {'b',       nv_bck_word,    0,                      0},
  {'c',       nv_operator,    0,                      0},
  {'d',       nv_operator,    0,                      0},
  {'e',       nv_wordcmd,     0,                      FALSE},
  {'f',       nv_csearch,     NV_NCH_ALW|NV_LANG,     FORWARD},
  {'g',       nv_g_cmd,       NV_NCH_ALW,             FALSE},
  {'h',       nv_left,        NV_RL,                  0},
  {'i',       nv_edit,        NV_NCH,                 0},
  {'j',       nv_down,        0,                      FALSE},
  {'k',       nv_up,          0,                      FALSE},
  {'l',       nv_right,       NV_RL,                  0},
  {'m',       nv_mark,        NV_NCH_NOP,             0},
  {'n',       nv_next,        0,                      0},
  {'o',       nv_open,        0,                      0},
  {'p',       nv_put,         0,                      0},
  {'q',       nv_record,      NV_NCH,                 0},
  {'r',       nv_replace,     NV_NCH_NOP|NV_LANG,     0},
  {'s',       nv_subst,       NV_KEEPREG,             0},
  {'t',       nv_csearch,     NV_NCH_ALW|NV_LANG,     FORWARD},
  {'u',       nv_undo,        0,                      0},
  {'w',       nv_wordcmd,     0,                      FALSE},
  {'x',       nv_abbrev,      NV_KEEPREG,             0},
  {'y',       nv_operator,    0,                      0},
  {'z',       nv_zet,         NV_NCH_ALW,             0},
  {'{',       nv_findpar,     0,                      BACKWARD},
  {'|',       nv_pipe,        0,                      0},
  {'}',       nv_findpar,     0,                      FORWARD},
  {'~',       nv_tilde,       0,                      0},

  /* pound sign */
  {POUND,     nv_ident,       0,                      0},
  {K_MOUSEUP, nv_mousescroll, 0,                      MSCR_UP},
  {K_MOUSEDOWN, nv_mousescroll, 0,                    MSCR_DOWN},
  {K_MOUSELEFT, nv_mousescroll, 0,                    MSCR_LEFT},
  {K_MOUSERIGHT, nv_mousescroll, 0,                   MSCR_RIGHT},
  {K_LEFTMOUSE, nv_mouse,     0,                      0},
  {K_LEFTMOUSE_NM, nv_mouse,  0,                      0},
  {K_LEFTDRAG, nv_mouse,      0,                      0},
  {K_LEFTRELEASE, nv_mouse,   0,                      0},
  {K_LEFTRELEASE_NM, nv_mouse, 0,                     0},
  {K_MIDDLEMOUSE, nv_mouse,   0,                      0},
  {K_MIDDLEDRAG, nv_mouse,    0,                      0},
  {K_MIDDLERELEASE, nv_mouse, 0,                      0},
  {K_RIGHTMOUSE, nv_mouse,    0,                      0},
  {K_RIGHTDRAG, nv_mouse,     0,                      0},
  {K_RIGHTRELEASE, nv_mouse,  0,                      0},
  {K_X1MOUSE, nv_mouse,       0,                      0},
  {K_X1DRAG, nv_mouse,        0,                      0},
  {K_X1RELEASE, nv_mouse,     0,                      0},
  {K_X2MOUSE, nv_mouse,       0,                      0},
  {K_X2DRAG, nv_mouse,        0,                      0},
  {K_X2RELEASE, nv_mouse,     0,                      0},
  {K_IGNORE,  nv_ignore,      NV_KEEPREG,             0},
  {K_NOP,     nv_nop,         0,                      0},
  {K_INS,     nv_edit,        0,                      0},
  {K_KINS,    nv_edit,        0,                      0},
  {K_BS,      nv_ctrlh,       0,                      0},
  {K_UP,      nv_up,          NV_SSS|NV_STS,          FALSE},
  {K_S_UP,    nv_page,        NV_SS,                  BACKWARD},
  {K_DOWN,    nv_down,        NV_SSS|NV_STS,          FALSE},
  {K_S_DOWN,  nv_page,        NV_SS,                  FORWARD},
  {K_LEFT,    nv_left,        NV_SSS|NV_STS|NV_RL,    0},
  {K_S_LEFT,  nv_bck_word,    NV_SS|NV_RL,            0},
  {K_C_LEFT,  nv_bck_word,    NV_SSS|NV_RL|NV_STS,    1},
  {K_RIGHT,   nv_right,       NV_SSS|NV_STS|NV_RL,    0},
  {K_S_RIGHT, nv_wordcmd,     NV_SS|NV_RL,            FALSE},
  {K_C_RIGHT, nv_wordcmd,     NV_SSS|NV_RL|NV_STS,    TRUE},
  {K_PAGEUP,  nv_page,        NV_SSS|NV_STS,          BACKWARD},
  {K_KPAGEUP, nv_page,        NV_SSS|NV_STS,          BACKWARD},
  {K_PAGEDOWN, nv_page,       NV_SSS|NV_STS,          FORWARD},
  {K_KPAGEDOWN, nv_page,      NV_SSS|NV_STS,          FORWARD},
  {K_END,     nv_end,         NV_SSS|NV_STS,          FALSE},
  {K_KEND,    nv_end,         NV_SSS|NV_STS,          FALSE},
  {K_S_END,   nv_end,         NV_SS,                  FALSE},
  {K_C_END,   nv_end,         NV_SSS|NV_STS,          TRUE},
  {K_HOME,    nv_home,        NV_SSS|NV_STS,          0},
  {K_KHOME,   nv_home,        NV_SSS|NV_STS,          0},
  {K_S_HOME,  nv_home,        NV_SS,                  0},
  {K_C_HOME,  nv_goto,        NV_SSS|NV_STS,          FALSE},
  {K_DEL,     nv_abbrev,      0,                      0},
  {K_KDEL,    nv_abbrev,      0,                      0},
  {K_UNDO,    nv_kundo,       0,                      0},
  {K_HELP,    nv_help,        NV_NCW,                 0},
  {K_F1,      nv_help,        NV_NCW,                 0},
  {K_XF1,     nv_help,        NV_NCW,                 0},
  {K_SELECT,  nv_select,      0,                      0},
  {K_F8,      farsi_fkey,     0,                      0},
  {K_F9,      farsi_fkey,     0,                      0},
  {K_CURSORHOLD, nv_cursorhold, NV_KEEPREG,           0},
};

/* Number of commands in nv_cmds[]. */
#define NV_CMDS_SIZE (sizeof(nv_cmds) / sizeof(struct nv_cmd))

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
void init_normal_cmds(void)          {
  int i;

  /* Fill the index table with a one to one relation. */
  for (i = 0; i < (int)NV_CMDS_SIZE; ++i)
    nv_cmd_idx[i] = i;

  /* Sort the commands by the command character.  */
  qsort((void *)&nv_cmd_idx, (size_t)NV_CMDS_SIZE, sizeof(short), nv_compare);

  /* Find the first entry that can't be indexed by the command character. */
  for (i = 0; i < (int)NV_CMDS_SIZE; ++i)
    if (i != nv_cmds[nv_cmd_idx[i]].cmd_char)
      break;
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

/*
 * Execute a command in Normal mode.
 */
void 
normal_cmd (
    oparg_T *oap,
    int toplevel                    /* TRUE when called from main() */
)
{
  cmdarg_T ca;                          /* command arguments */
  int c;
  int ctrl_w = FALSE;                   /* got CTRL-W command */
  int old_col = curwin->w_curswant;
  int need_flushbuf;                    /* need to call out_flush() */
  pos_T old_pos;                        /* cursor position before command */
  int mapped_len;
  static int old_mapped_len = 0;
  int idx;
  int set_prevcount = FALSE;

  vim_memset(&ca, 0, sizeof(ca));       /* also resets ca.retval */
  ca.oap = oap;

  /* Use a count remembered from before entering an operator.  After typing
   * "3d" we return from normal_cmd() and come back here, the "3" is
   * remembered in "opcount". */
  ca.opcount = opcount;


  /*
   * If there is an operator pending, then the command we take this time
   * will terminate it. Finish_op tells us to finish the operation before
   * returning this time (unless the operation was cancelled).
   */
#ifdef CURSOR_SHAPE
  c = finish_op;
#endif
  finish_op = (oap->op_type != OP_NOP);
#ifdef CURSOR_SHAPE
  if (finish_op != c) {
    ui_cursor_shape();                  /* may show different cursor shape */
  }
#endif

  /* When not finishing an operator and no register name typed, reset the
   * count. */
  if (!finish_op && !oap->regname) {
    ca.opcount = 0;
    set_prevcount = TRUE;
  }

  /* Restore counts from before receiving K_CURSORHOLD.  This means after
   * typing "3", handling K_CURSORHOLD and then typing "2" we get "32", not
   * "3 * 2". */
  if (oap->prev_opcount > 0 || oap->prev_count0 > 0) {
    ca.opcount = oap->prev_opcount;
    ca.count0 = oap->prev_count0;
    oap->prev_opcount = 0;
    oap->prev_count0 = 0;
  }

  mapped_len = typebuf_maplen();

  State = NORMAL_BUSY;
#ifdef USE_ON_FLY_SCROLL
  dont_scroll = FALSE;          /* allow scrolling here */
#endif

  /* Set v:count here, when called from main() and not a stuffed
   * command, so that v:count can be used in an expression mapping
   * when there is no count. */
  if (toplevel && stuff_empty())
    set_vcount_ca(&ca, &set_prevcount);

  /*
   * Get the command character from the user.
   */
  c = safe_vgetc();
  LANGMAP_ADJUST(c, TRUE);

  /*
   * If a mapping was started in Visual or Select mode, remember the length
   * of the mapping.  This is used below to not return to Insert mode for as
   * long as the mapping is being executed.
   */
  if (restart_edit == 0)
    old_mapped_len = 0;
  else if (old_mapped_len
           || (VIsual_active && mapped_len == 0 && typebuf_maplen() > 0))
    old_mapped_len = typebuf_maplen();

  if (c == NUL)
    c = K_ZERO;

  /*
   * In Select mode, typed text replaces the selection.
   */
  if (VIsual_active
      && VIsual_select
      && (vim_isprintc(c) || c == NL || c == CAR || c == K_KENTER)) {
    /* Fake a "c"hange command.  When "restart_edit" is set (e.g., because
     * 'insertmode' is set) fake a "d"elete command, Insert mode will
     * restart automatically.
     * Insert the typed character in the typeahead buffer, so that it can
     * be mapped in Insert mode.  Required for ":lmap" to work. */
    ins_char_typebuf(c);
    if (restart_edit != 0)
      c = 'd';
    else
      c = 'c';
    msg_nowait = TRUE;          /* don't delay going to insert mode */
    old_mapped_len = 0;         /* do go to Insert mode */
  }

  need_flushbuf = add_to_showcmd(c);

getcount:
  if (!(VIsual_active && VIsual_select)) {
    /*
     * Handle a count before a command and compute ca.count0.
     * Note that '0' is a command and not the start of a count, but it's
     * part of a count after other digits.
     */
    while (    (c >= '1' && c <= '9')
               || (ca.count0 != 0 &&
                   (c == K_DEL || c == K_KDEL || c == '0'))) {
      if (c == K_DEL || c == K_KDEL) {
        ca.count0 /= 10;
        del_from_showcmd(4);            /* delete the digit and ~@% */
      } else
        ca.count0 = ca.count0 * 10 + (c - '0');
      if (ca.count0 < 0)            /* got too large! */
        ca.count0 = 999999999L;
      /* Set v:count here, when called from main() and not a stuffed
       * command, so that v:count can be used in an expression mapping
       * right after the count. */
      if (toplevel && stuff_empty())
        set_vcount_ca(&ca, &set_prevcount);
      if (ctrl_w) {
        ++no_mapping;
        ++allow_keys;                   /* no mapping for nchar, but keys */
      }
      ++no_zero_mapping;                /* don't map zero here */
      c = plain_vgetc();
      LANGMAP_ADJUST(c, TRUE);
      --no_zero_mapping;
      if (ctrl_w) {
        --no_mapping;
        --allow_keys;
      }
      need_flushbuf |= add_to_showcmd(c);
    }

    /*
     * If we got CTRL-W there may be a/another count
     */
    if (c == Ctrl_W && !ctrl_w && oap->op_type == OP_NOP) {
      ctrl_w = TRUE;
      ca.opcount = ca.count0;           /* remember first count */
      ca.count0 = 0;
      ++no_mapping;
      ++allow_keys;                     /* no mapping for nchar, but keys */
      c = plain_vgetc();                /* get next character */
      LANGMAP_ADJUST(c, TRUE);
      --no_mapping;
      --allow_keys;
      need_flushbuf |= add_to_showcmd(c);
      goto getcount;                    /* jump back */
    }
  }

  if (c == K_CURSORHOLD) {
    /* Save the count values so that ca.opcount and ca.count0 are exactly
     * the same when coming back here after handling K_CURSORHOLD. */
    oap->prev_opcount = ca.opcount;
    oap->prev_count0 = ca.count0;
  } else if (ca.opcount != 0)    {
    /*
     * If we're in the middle of an operator (including after entering a
     * yank buffer with '"') AND we had a count before the operator, then
     * that count overrides the current value of ca.count0.
     * What this means effectively, is that commands like "3dw" get turned
     * into "d3w" which makes things fall into place pretty neatly.
     * If you give a count before AND after the operator, they are
     * multiplied.
     */
    if (ca.count0)
      ca.count0 *= ca.opcount;
    else
      ca.count0 = ca.opcount;
  }

  /*
   * Always remember the count.  It will be set to zero (on the next call,
   * above) when there is no pending operator.
   * When called from main(), save the count for use by the "count" built-in
   * variable.
   */
  ca.opcount = ca.count0;
  ca.count1 = (ca.count0 == 0 ? 1 : ca.count0);

  /*
   * Only set v:count when called from main() and not a stuffed command.
   */
  if (toplevel && stuff_empty())
    set_vcount(ca.count0, ca.count1, set_prevcount);

  /*
   * Find the command character in the table of commands.
   * For CTRL-W we already got nchar when looking for a count.
   */
  if (ctrl_w) {
    ca.nchar = c;
    ca.cmdchar = Ctrl_W;
  } else
    ca.cmdchar = c;
  idx = find_command(ca.cmdchar);
  if (idx < 0) {
    /* Not a known command: beep. */
    clearopbeep(oap);
    goto normal_end;
  }

  if (text_locked() && (nv_cmds[idx].cmd_flags & NV_NCW)) {
    /* This command is not allowed while editing a ccmdline: beep. */
    clearopbeep(oap);
    text_locked_msg();
    goto normal_end;
  }
  if ((nv_cmds[idx].cmd_flags & NV_NCW) && curbuf_locked())
    goto normal_end;

  /*
   * In Visual/Select mode, a few keys are handled in a special way.
   */
  if (VIsual_active) {
    /* when 'keymodel' contains "stopsel" may stop Select/Visual mode */
    if (km_stopsel
        && (nv_cmds[idx].cmd_flags & NV_STS)
        && !(mod_mask & MOD_MASK_SHIFT)) {
      end_visual_mode();
      redraw_curbuf_later(INVERTED);
    }

    /* Keys that work different when 'keymodel' contains "startsel" */
    if (km_startsel) {
      if (nv_cmds[idx].cmd_flags & NV_SS) {
        unshift_special(&ca);
        idx = find_command(ca.cmdchar);
        if (idx < 0) {
          /* Just in case */
          clearopbeep(oap);
          goto normal_end;
        }
      } else if ((nv_cmds[idx].cmd_flags & NV_SSS)
                 && (mod_mask & MOD_MASK_SHIFT)) {
        mod_mask &= ~MOD_MASK_SHIFT;
      }
    }
  }

  if (curwin->w_p_rl && KeyTyped && !KeyStuffed
      && (nv_cmds[idx].cmd_flags & NV_RL)) {
    /* Invert horizontal movements and operations.  Only when typed by the
     * user directly, not when the result of a mapping or "x" translated
     * to "dl". */
    switch (ca.cmdchar) {
    case 'l':       ca.cmdchar = 'h'; break;
    case K_RIGHT:   ca.cmdchar = K_LEFT; break;
    case K_S_RIGHT: ca.cmdchar = K_S_LEFT; break;
    case K_C_RIGHT: ca.cmdchar = K_C_LEFT; break;
    case 'h':       ca.cmdchar = 'l'; break;
    case K_LEFT:    ca.cmdchar = K_RIGHT; break;
    case K_S_LEFT:  ca.cmdchar = K_S_RIGHT; break;
    case K_C_LEFT:  ca.cmdchar = K_C_RIGHT; break;
    case '>':       ca.cmdchar = '<'; break;
    case '<':       ca.cmdchar = '>'; break;
    }
    idx = find_command(ca.cmdchar);
  }

  /*
   * Get an additional character if we need one.
   */
  if ((nv_cmds[idx].cmd_flags & NV_NCH)
      && (((nv_cmds[idx].cmd_flags & NV_NCH_NOP) == NV_NCH_NOP
           && oap->op_type == OP_NOP)
          || (nv_cmds[idx].cmd_flags & NV_NCH_ALW) == NV_NCH_ALW
          || (ca.cmdchar == 'q'
              && oap->op_type == OP_NOP
              && !Recording
              && !Exec_reg)
          || ((ca.cmdchar == 'a' || ca.cmdchar == 'i')
              && (oap->op_type != OP_NOP
                  || VIsual_active
                  )))) {
    int     *cp;
    int repl = FALSE;           /* get character for replace mode */
    int lit = FALSE;            /* get extra character literally */
    int langmap_active = FALSE;            /* using :lmap mappings */
    int lang;                   /* getting a text character */
#ifdef USE_IM_CONTROL
    int save_smd;               /* saved value of p_smd */
#endif

    ++no_mapping;
    ++allow_keys;               /* no mapping for nchar, but allow key codes */
    /* Don't generate a CursorHold event here, most commands can't handle
     * it, e.g., nv_replace(), nv_csearch(). */
    did_cursorhold = TRUE;
    if (ca.cmdchar == 'g') {
      /*
       * For 'g' get the next character now, so that we can check for
       * "gr", "g'" and "g`".
       */
      ca.nchar = plain_vgetc();
      LANGMAP_ADJUST(ca.nchar, TRUE);
      need_flushbuf |= add_to_showcmd(ca.nchar);
      if (ca.nchar == 'r' || ca.nchar == '\'' || ca.nchar == '`'
          || ca.nchar == Ctrl_BSL) {
        cp = &ca.extra_char;            /* need to get a third character */
        if (ca.nchar != 'r')
          lit = TRUE;                           /* get it literally */
        else
          repl = TRUE;                          /* get it in replace mode */
      } else
        cp = NULL;                      /* no third character needed */
    } else   {
      if (ca.cmdchar == 'r')                    /* get it in replace mode */
        repl = TRUE;
      cp = &ca.nchar;
    }
    lang = (repl || (nv_cmds[idx].cmd_flags & NV_LANG));

    /*
     * Get a second or third character.
     */
    if (cp != NULL) {
#ifdef CURSOR_SHAPE
      if (repl) {
        State = REPLACE;                /* pretend Replace mode */
        ui_cursor_shape();              /* show different cursor shape */
      }
#endif
      if (lang && curbuf->b_p_iminsert == B_IMODE_LMAP) {
        /* Allow mappings defined with ":lmap". */
        --no_mapping;
        --allow_keys;
        if (repl)
          State = LREPLACE;
        else
          State = LANGMAP;
        langmap_active = TRUE;
      }
#ifdef USE_IM_CONTROL
      save_smd = p_smd;
      p_smd = FALSE;            /* Don't let the IM code show the mode here */
      if (lang && curbuf->b_p_iminsert == B_IMODE_IM)
        im_set_active(TRUE);
#endif

      *cp = plain_vgetc();

      if (langmap_active) {
        /* Undo the decrement done above */
        ++no_mapping;
        ++allow_keys;
        State = NORMAL_BUSY;
      }
#ifdef USE_IM_CONTROL
      if (lang) {
        if (curbuf->b_p_iminsert != B_IMODE_LMAP)
          im_save_status(&curbuf->b_p_iminsert);
        im_set_active(FALSE);
      }
      p_smd = save_smd;
#endif
#ifdef CURSOR_SHAPE
      State = NORMAL_BUSY;
#endif
      need_flushbuf |= add_to_showcmd(*cp);

      if (!lit) {
        /* Typing CTRL-K gets a digraph. */
        if (*cp == Ctrl_K
            && ((nv_cmds[idx].cmd_flags & NV_LANG)
                || cp == &ca.extra_char)
            && vim_strchr(p_cpo, CPO_DIGRAPH) == NULL) {
          c = get_digraph(FALSE);
          if (c > 0) {
            *cp = c;
            /* Guessing how to update showcmd here... */
            del_from_showcmd(3);
            need_flushbuf |= add_to_showcmd(*cp);
          }
        }

        /* adjust chars > 127, except after "tTfFr" commands */
        LANGMAP_ADJUST(*cp, !lang);
        /* adjust Hebrew mapped char */
        if (p_hkmap && lang && KeyTyped)
          *cp = hkmap(*cp);
        /* adjust Farsi mapped char */
        if (p_fkmap && lang && KeyTyped)
          *cp = fkmap(*cp);
      }

      /*
       * When the next character is CTRL-\ a following CTRL-N means the
       * command is aborted and we go to Normal mode.
       */
      if (cp == &ca.extra_char
          && ca.nchar == Ctrl_BSL
          && (ca.extra_char == Ctrl_N || ca.extra_char == Ctrl_G)) {
        ca.cmdchar = Ctrl_BSL;
        ca.nchar = ca.extra_char;
        idx = find_command(ca.cmdchar);
      } else if ((ca.nchar == 'n' || ca.nchar == 'N') && ca.cmdchar == 'g')
        ca.oap->op_type = get_op_type(*cp, NUL);
      else if (*cp == Ctrl_BSL) {
        long towait = (p_ttm >= 0 ? p_ttm : p_tm);

        /* There is a busy wait here when typing "f<C-\>" and then
         * something different from CTRL-N.  Can't be avoided. */
        while ((c = vpeekc()) <= 0 && towait > 0L) {
          do_sleep(towait > 50L ? 50L : towait);
          towait -= 50L;
        }
        if (c > 0) {
          c = plain_vgetc();
          if (c != Ctrl_N && c != Ctrl_G)
            vungetc(c);
          else {
            ca.cmdchar = Ctrl_BSL;
            ca.nchar = c;
            idx = find_command(ca.cmdchar);
          }
        }
      }

      /* When getting a text character and the next character is a
       * multi-byte character, it could be a composing character.
       * However, don't wait for it to arrive. */
      while (enc_utf8 && lang && (c = vpeekc()) > 0
             && (c >= 0x100 || MB_BYTE2LEN(vpeekc()) > 1)) {
        c = plain_vgetc();
        if (!utf_iscomposing(c)) {
          vungetc(c);                   /* it wasn't, put it back */
          break;
        } else if (ca.ncharC1 == 0)
          ca.ncharC1 = c;
        else
          ca.ncharC2 = c;
      }
    }
    --no_mapping;
    --allow_keys;
  }

  /*
   * Flush the showcmd characters onto the screen so we can see them while
   * the command is being executed.  Only do this when the shown command was
   * actually displayed, otherwise this will slow down a lot when executing
   * mappings.
   */
  if (need_flushbuf)
    out_flush();
  if (ca.cmdchar != K_IGNORE)
    did_cursorhold = FALSE;

  State = NORMAL;

  if (ca.nchar == ESC) {
    clearop(oap);
    if (restart_edit == 0 && goto_im())
      restart_edit = 'a';
    goto normal_end;
  }

  if (ca.cmdchar != K_IGNORE) {
    msg_didout = FALSE;        /* don't scroll screen up for normal command */
    msg_col = 0;
  }

  old_pos = curwin->w_cursor;           /* remember where cursor was */

  /* When 'keymodel' contains "startsel" some keys start Select/Visual
   * mode. */
  if (!VIsual_active && km_startsel) {
    if (nv_cmds[idx].cmd_flags & NV_SS) {
      start_selection();
      unshift_special(&ca);
      idx = find_command(ca.cmdchar);
    } else if ((nv_cmds[idx].cmd_flags & NV_SSS)
               && (mod_mask & MOD_MASK_SHIFT)) {
      start_selection();
      mod_mask &= ~MOD_MASK_SHIFT;
    }
  }

  /*
   * Execute the command!
   * Call the command function found in the commands table.
   */
  ca.arg = nv_cmds[idx].cmd_arg;
  (nv_cmds[idx].cmd_func)(&ca);

  /*
   * If we didn't start or finish an operator, reset oap->regname, unless we
   * need it later.
   */
  if (!finish_op
      && !oap->op_type
      && (idx < 0 || !(nv_cmds[idx].cmd_flags & NV_KEEPREG))) {
    clearop(oap);
    {
      int regname = 0;

      /* Adjust the register according to 'clipboard', so that when
       * "unnamed" is present it becomes '*' or '+' instead of '"'. */
      set_reg_var(regname);
    }
  }

  /* Get the length of mapped chars again after typing a count, second
   * character or "z333<cr>". */
  if (old_mapped_len > 0)
    old_mapped_len = typebuf_maplen();

  /*
   * If an operation is pending, handle it...
   */
  do_pending_operator(&ca, old_col, FALSE);

  /*
   * Wait for a moment when a message is displayed that will be overwritten
   * by the mode message.
   * In Visual mode and with "^O" in Insert mode, a short message will be
   * overwritten by the mode message.  Wait a bit, until a key is hit.
   * In Visual mode, it's more important to keep the Visual area updated
   * than keeping a message (e.g. from a /pat search).
   * Only do this if the command was typed, not from a mapping.
   * Don't wait when emsg_silent is non-zero.
   * Also wait a bit after an error message, e.g. for "^O:".
   * Don't redraw the screen, it would remove the message.
   */
  if (       ((p_smd
               && msg_silent == 0
               && (restart_edit != 0
                   || (VIsual_active
                       && old_pos.lnum == curwin->w_cursor.lnum
                       && old_pos.col == curwin->w_cursor.col)
                   )
               && (clear_cmdline
                   || redraw_cmdline)
               && (msg_didout || (msg_didany && msg_scroll))
               && !msg_nowait
               && KeyTyped)
              || (restart_edit != 0
                  && !VIsual_active
                  && (msg_scroll
                      || emsg_on_display)))
             && oap->regname == 0
             && !(ca.retval & CA_COMMAND_BUSY)
             && stuff_empty()
             && typebuf_typed()
             && emsg_silent == 0
             && !did_wait_return
             && oap->op_type == OP_NOP) {
    int save_State = State;

    /* Draw the cursor with the right shape here */
    if (restart_edit != 0)
      State = INSERT;

    /* If need to redraw, and there is a "keep_msg", redraw before the
     * delay */
    if (must_redraw && keep_msg != NULL && !emsg_on_display) {
      char_u      *kmsg;

      kmsg = keep_msg;
      keep_msg = NULL;
      /* showmode() will clear keep_msg, but we want to use it anyway */
      update_screen(0);
      /* now reset it, otherwise it's put in the history again */
      keep_msg = kmsg;
      msg_attr(kmsg, keep_msg_attr);
      vim_free(kmsg);
    }
    setcursor();
    cursor_on();
    out_flush();
    if (msg_scroll || emsg_on_display)
      ui_delay(1000L, TRUE);            /* wait at least one second */
    ui_delay(3000L, FALSE);             /* wait up to three seconds */
    State = save_State;

    msg_scroll = FALSE;
    emsg_on_display = FALSE;
  }

  /*
   * Finish up after executing a Normal mode command.
   */
normal_end:

  msg_nowait = FALSE;

  /* Reset finish_op, in case it was set */
#ifdef CURSOR_SHAPE
  c = finish_op;
#endif
  finish_op = FALSE;
#ifdef CURSOR_SHAPE
  /* Redraw the cursor with another shape, if we were in Operator-pending
   * mode or did a replace command. */
  if (c || ca.cmdchar == 'r') {
    ui_cursor_shape();                  /* may show different cursor shape */
  }
#endif

  if (oap->op_type == OP_NOP && oap->regname == 0
      && ca.cmdchar != K_CURSORHOLD
      )
    clear_showcmd();

  checkpcmark();                /* check if we moved since setting pcmark */
  vim_free(ca.searchbuf);

  if (has_mbyte)
    mb_adjust_cursor();

  if (curwin->w_p_scb && toplevel) {
    validate_cursor();          /* may need to update w_leftcol */
    do_check_scrollbind(TRUE);
  }

  if (curwin->w_p_crb && toplevel) {
    validate_cursor();          /* may need to update w_leftcol */
    do_check_cursorbind();
  }

  /*
   * May restart edit(), if we got here with CTRL-O in Insert mode (but not
   * if still inside a mapping that started in Visual mode).
   * May switch from Visual to Select mode after CTRL-O command.
   */
  if (       oap->op_type == OP_NOP
             && ((restart_edit != 0 && !VIsual_active && old_mapped_len == 0)
                 || restart_VIsual_select == 1)
             && !(ca.retval & CA_COMMAND_BUSY)
             && stuff_empty()
             && oap->regname == 0) {
    if (restart_VIsual_select == 1) {
      VIsual_select = TRUE;
      showmode();
      restart_VIsual_select = 0;
    }
    if (restart_edit != 0
        && !VIsual_active && old_mapped_len == 0
        )
      (void)edit(restart_edit, FALSE, 1L);
  }

  if (restart_VIsual_select == 2)
    restart_VIsual_select = 1;

  /* Save count before an operator for next time. */
  opcount = ca.opcount;
}

/*
 * Set v:count and v:count1 according to "cap".
 * Set v:prevcount only when "set_prevcount" is TRUE.
 */
static void set_vcount_ca(cmdarg_T *cap, int *set_prevcount)
{
  long count = cap->count0;

  /* multiply with cap->opcount the same way as above */
  if (cap->opcount != 0)
    count = cap->opcount * (count == 0 ? 1 : count);
  set_vcount(count, count == 0 ? 1 : count, *set_prevcount);
  *set_prevcount = FALSE;    /* only set v:prevcount once */
}

/*
 * Handle an operator after visual mode or when the movement is finished
 */
void do_pending_operator(cmdarg_T *cap, int old_col, int gui_yank)
{
  oparg_T     *oap = cap->oap;
  pos_T old_cursor;
  int empty_region_error;
  int restart_edit_save;

  /* The visual area is remembered for redo */
  static int redo_VIsual_mode = NUL;        /* 'v', 'V', or Ctrl-V */
  static linenr_T redo_VIsual_line_count;   /* number of lines */
  static colnr_T redo_VIsual_vcol;          /* number of cols or end column */
  static long redo_VIsual_count;            /* count for Visual operator */
  int include_line_break = FALSE;

  old_cursor = curwin->w_cursor;

  /*
   * If an operation is pending, handle it...
   */
  if ((finish_op
       || VIsual_active
       ) && oap->op_type != OP_NOP) {
    oap->is_VIsual = VIsual_active;
    if (oap->motion_force == 'V')
      oap->motion_type = MLINE;
    else if (oap->motion_force == 'v') {
      /* If the motion was linewise, "inclusive" will not have been set.
       * Use "exclusive" to be consistent.  Makes "dvj" work nice. */
      if (oap->motion_type == MLINE)
        oap->inclusive = FALSE;
      /* If the motion already was characterwise, toggle "inclusive" */
      else if (oap->motion_type == MCHAR)
        oap->inclusive = !oap->inclusive;
      oap->motion_type = MCHAR;
    } else if (oap->motion_force == Ctrl_V)   {
      /* Change line- or characterwise motion into Visual block mode. */
      VIsual_active = TRUE;
      VIsual = oap->start;
      VIsual_mode = Ctrl_V;
      VIsual_select = FALSE;
      VIsual_reselect = FALSE;
    }

    /* Only redo yank when 'y' flag is in 'cpoptions'. */
    /* Never redo "zf" (define fold). */
    if ((vim_strchr(p_cpo, CPO_YANK) != NULL || oap->op_type != OP_YANK)
        && ((!VIsual_active || oap->motion_force)
            /* Also redo Operator-pending Visual mode mappings */
            || (VIsual_active && cap->cmdchar == ':'
                && oap->op_type != OP_COLON))
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
        if (vim_strchr(p_cpo, CPO_REDO) == NULL)
          AppendToRedobuffLit(cap->searchbuf, -1);
        AppendToRedobuff(NL_STR);
      } else if (cap->cmdchar == ':')   {
        /* do_cmdline() has stored the first typed line in
         * "repeat_cmdline".  When several lines are typed repeating
         * won't be possible. */
        if (repeat_cmdline == NULL)
          ResetRedobuff();
        else {
          AppendToRedobuffLit(repeat_cmdline, -1);
          AppendToRedobuff(NL_STR);
          vim_free(repeat_cmdline);
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
        } else   {
          curwin->w_curswant = MAXCOL;
        }
        coladvance(curwin->w_curswant);
      }
      cap->count0 = redo_VIsual_count;
      if (redo_VIsual_count != 0)
        cap->count1 = redo_VIsual_count;
      else
        cap->count1 = 1;
    } else if (VIsual_active)   {
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

      /* In Select mode, a linewise selection is operated upon like a
       * characterwise selection. */
      if (VIsual_select && VIsual_mode == 'V') {
        if (lt(VIsual, curwin->w_cursor)) {
          VIsual.col = 0;
          curwin->w_cursor.col =
            (colnr_T)STRLEN(ml_get(curwin->w_cursor.lnum));
        } else   {
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
      if (VIsual_mode == 'V')
        oap->start.col = 0;
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
          curwin->w_cursor.col = (colnr_T)STRLEN(ml_get_curline());
      }
      oap->end = curwin->w_cursor;
      curwin->w_cursor = oap->start;

      /* w_virtcol may have been updated; if the cursor goes back to its
       * previous position w_virtcol becomes invalid and isn't updated
       * automatically. */
      curwin->w_valid &= ~VALID_VIRTCOL;
    } else   {
      /* Include folded lines completely. */
      if (!VIsual_active && oap->motion_type == MLINE) {
        if (hasFolding(curwin->w_cursor.lnum, &curwin->w_cursor.lnum,
                NULL))
          curwin->w_cursor.col = 0;
        if (hasFolding(oap->start.lnum, NULL, &oap->start.lnum))
          oap->start.col = (colnr_T)STRLEN(ml_get(oap->start.lnum));
      }
      oap->end = oap->start;
      oap->start = curwin->w_cursor;
    }

    oap->line_count = oap->end.lnum - oap->start.lnum + 1;

    /* Set "virtual_op" before resetting VIsual_active. */
    virtual_op = virtual_active();

    if (VIsual_active || redo_VIsual_busy) {
      if (VIsual_mode == Ctrl_V) {      /* block mode */
        colnr_T start, end;

        oap->block_mode = TRUE;

        getvvcol(curwin, &(oap->start),
            &oap->start_vcol, NULL, &oap->end_vcol);
        if (!redo_VIsual_busy) {
          getvvcol(curwin, &(oap->end), &start, NULL, &end);

          if (start < oap->start_vcol)
            oap->start_vcol = start;
          if (end > oap->end_vcol) {
            if (*p_sel == 'e' && start >= 1
                && start - 1 >= oap->end_vcol)
              oap->end_vcol = start - 1;
            else
              oap->end_vcol = end;
          }
        }

        /* if '$' was used, get oap->end_vcol from longest line */
        if (curwin->w_curswant == MAXCOL) {
          curwin->w_cursor.col = MAXCOL;
          oap->end_vcol = 0;
          for (curwin->w_cursor.lnum = oap->start.lnum;
               curwin->w_cursor.lnum <= oap->end.lnum;
               ++curwin->w_cursor.lnum) {
            getvvcol(curwin, &curwin->w_cursor, NULL, NULL, &end);
            if (end > oap->end_vcol)
              oap->end_vcol = end;
          }
        } else if (redo_VIsual_busy)
          oap->end_vcol = oap->start_vcol + redo_VIsual_vcol - 1;
        /*
         * Correct oap->end.col and oap->start.col to be the
         * upper-left and lower-right corner of the block area.
         *
         * (Actually, this does convert column positions into character
         * positions)
         */
        curwin->w_cursor.lnum = oap->end.lnum;
        coladvance(oap->end_vcol);
        oap->end = curwin->w_cursor;

        curwin->w_cursor = oap->start;
        coladvance(oap->start_vcol);
        oap->start = curwin->w_cursor;
      }

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
                                    || cap->nchar == 'N'))
          prep_redo(oap->regname, cap->count0,
              get_op_char(oap->op_type), get_extra_op_char(oap->op_type),
              oap->motion_force, cap->cmdchar, cap->nchar);
        else if (cap->cmdchar != ':')
          prep_redo(oap->regname, 0L, NUL, 'v',
              get_op_char(oap->op_type),
              get_extra_op_char(oap->op_type),
              oap->op_type == OP_REPLACE
              ? cap->nchar : NUL);
        if (!redo_VIsual_busy) {
          redo_VIsual_mode = resel_VIsual_mode;
          redo_VIsual_vcol = resel_VIsual_vcol;
          redo_VIsual_line_count = resel_VIsual_line_count;
          redo_VIsual_count = cap->count0;
        }
      }

      /*
       * oap->inclusive defaults to TRUE.
       * If oap->end is on a NUL (empty line) oap->inclusive becomes
       * FALSE.  This makes "d}P" and "v}dP" work the same.
       */
      if (oap->motion_force == NUL || oap->motion_type == MLINE)
        oap->inclusive = TRUE;
      if (VIsual_mode == 'V')
        oap->motion_type = MLINE;
      else {
        oap->motion_type = MCHAR;
        if (VIsual_mode != Ctrl_V && *ml_get_pos(&(oap->end)) == NUL
            && (include_line_break || !virtual_op)
            ) {
          oap->inclusive = FALSE;
          /* Try to include the newline, unless it's an operator
           * that works on lines only. */
          if (*p_sel != 'o' && !op_on_lines(oap->op_type)) {
            if (oap->end.lnum < curbuf->b_ml.ml_line_count) {
              ++oap->end.lnum;
              oap->end.col = 0;
              oap->end.coladd = 0;
              ++oap->line_count;
            } else   {
              /* Cannot move below the last line, make the op
               * inclusive to tell the operation to include the
               * line break. */
              oap->inclusive = TRUE;
            }
          }
        }
      }

      redo_VIsual_busy = FALSE;

      /*
       * Switch Visual off now, so screen updating does
       * not show inverted text when the screen is redrawn.
       * With OP_YANK and sometimes with OP_COLON and OP_FILTER there is
       * no screen redraw, so it is done here to remove the inverted
       * part.
       */
      if (!gui_yank) {
        VIsual_active = FALSE;
        setmouse();
        mouse_dragging = 0;
        if (mode_displayed)
          clear_cmdline = TRUE;             /* unshow visual mode later */
        else
          clear_showcmd();
        if ((oap->op_type == OP_YANK
             || oap->op_type == OP_COLON
             || oap->op_type == OP_FUNCTION
             || oap->op_type == OP_FILTER)
            && oap->motion_force == NUL)
          redraw_curbuf_later(INVERTED);
      }
    }

    /* Include the trailing byte of a multi-byte char. */
    if (has_mbyte && oap->inclusive) {
      int l;

      l = (*mb_ptr2len)(ml_get_pos(&oap->end));
      if (l > 1)
        oap->end.col += l - 1;
    }
    curwin->w_set_curswant = TRUE;

    /*
     * oap->empty is set when start and end are the same.  The inclusive
     * flag affects this too, unless yanking and the end is on a NUL.
     */
    oap->empty = (oap->motion_type == MCHAR
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
    if (oap->is_VIsual && (oap->empty || !curbuf->b_p_ma
                           || oap->op_type == OP_FOLD
                           ))
      redraw_curbuf_later(INVERTED);

    /*
     * If the end of an operator is in column one while oap->motion_type
     * is MCHAR and oap->inclusive is FALSE, we put op_end after the last
     * character in the previous line. If op_start is on or before the
     * first non-blank in the line, the operator becomes linewise
     * (strange, but that's the way vi does it).
     */
    if (       oap->motion_type == MCHAR
               && oap->inclusive == FALSE
               && !(cap->retval & CA_NO_ADJ_OP_END)
               && oap->end.col == 0
               && (!oap->is_VIsual || *p_sel == 'o')
               && !oap->block_mode
               && oap->line_count > 1) {
      oap->end_adjusted = TRUE;             /* remember that we did this */
      --oap->line_count;
      --oap->end.lnum;
      if (inindent(0))
        oap->motion_type = MLINE;
      else {
        oap->end.col = (colnr_T)STRLEN(ml_get(oap->end.lnum));
        if (oap->end.col) {
          --oap->end.col;
          oap->inclusive = TRUE;
        }
      }
    } else
      oap->end_adjusted = FALSE;

    switch (oap->op_type) {
    case OP_LSHIFT:
    case OP_RSHIFT:
      op_shift(oap, TRUE,
          oap->is_VIsual ? (int)cap->count1 :
          1);
      auto_format(FALSE, TRUE);
      break;

    case OP_JOIN_NS:
    case OP_JOIN:
      if (oap->line_count < 2)
        oap->line_count = 2;
      if (curwin->w_cursor.lnum + oap->line_count - 1 >
          curbuf->b_ml.ml_line_count)
        beep_flush();
      else {
        (void)do_join(oap->line_count, oap->op_type == OP_JOIN, TRUE, TRUE);
        auto_format(FALSE, TRUE);
      }
      break;

    case OP_DELETE:
      VIsual_reselect = FALSE;              /* don't reselect now */
      if (empty_region_error) {
        vim_beep();
        CancelRedo();
      } else   {
        (void)op_delete(oap);
        if (oap->motion_type == MLINE && has_format_option(FO_AUTO))
          u_save_cursor();                  /* cursor line wasn't saved yet */
        auto_format(FALSE, TRUE);
      }
      break;

    case OP_YANK:
      if (empty_region_error) {
        if (!gui_yank) {
          vim_beep();
          CancelRedo();
        }
      } else
        (void)op_yank(oap, FALSE, !gui_yank);
      check_cursor_col();
      break;

    case OP_CHANGE:
      VIsual_reselect = FALSE;              /* don't reselect now */
      if (empty_region_error) {
        vim_beep();
        CancelRedo();
      } else   {
        /* This is a new edit command, not a restart.  Need to
         * remember it to make 'insertmode' work with mappings for
         * Visual mode.  But do this only once and not when typed and
         * 'insertmode' isn't set. */
        if (p_im || !KeyTyped)
          restart_edit_save = restart_edit;
        else
          restart_edit_save = 0;
        restart_edit = 0;
        /* Reset finish_op now, don't want it set inside edit(). */
        finish_op = FALSE;
        if (op_change(oap))             /* will call edit() */
          cap->retval |= CA_COMMAND_BUSY;
        if (restart_edit == 0)
          restart_edit = restart_edit_save;
      }
      break;

    case OP_FILTER:
      if (vim_strchr(p_cpo, CPO_FILTER) != NULL)
        AppendToRedobuff((char_u *)"!\r");          /* use any last used !cmd */
      else
        bangredo = TRUE;            /* do_bang() will put cmd in redo buffer */

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
        vim_beep();
        CancelRedo();
      } else
        op_tilde(oap);
      check_cursor_col();
      break;

    case OP_FORMAT:
      if (*curbuf->b_p_fex != NUL)
        op_formatexpr(oap);             /* use expression */
      else if (*p_fp != NUL)
        op_colon(oap);                  /* use external command */
      else
        op_format(oap, FALSE);          /* use internal function */
      break;

    case OP_FORMAT2:
      op_format(oap, TRUE);             /* use internal function */
      break;

    case OP_FUNCTION:
      op_function(oap);                 /* call 'operatorfunc' */
      break;

    case OP_INSERT:
    case OP_APPEND:
      VIsual_reselect = FALSE;          /* don't reselect now */
      if (empty_region_error) {
        vim_beep();
        CancelRedo();
      } else   {
        /* This is a new edit command, not a restart.  Need to
         * remember it to make 'insertmode' work with mappings for
         * Visual mode.  But do this only once. */
        restart_edit_save = restart_edit;
        restart_edit = 0;

        op_insert(oap, cap->count1);

        /* TODO: when inserting in several lines, should format all
         * the lines. */
        auto_format(FALSE, TRUE);

        if (restart_edit == 0)
          restart_edit = restart_edit_save;
      }
      break;

    case OP_REPLACE:
      VIsual_reselect = FALSE;          /* don't reselect now */
      if (empty_region_error) {
        vim_beep();
        CancelRedo();
      } else
        op_replace(oap, cap->nchar);
      break;

    case OP_FOLD:
      VIsual_reselect = FALSE;          /* don't reselect now */
      foldCreate(oap->start.lnum, oap->end.lnum);
      break;

    case OP_FOLDOPEN:
    case OP_FOLDOPENREC:
    case OP_FOLDCLOSE:
    case OP_FOLDCLOSEREC:
      VIsual_reselect = FALSE;          /* don't reselect now */
      opFoldRange(oap->start.lnum, oap->end.lnum,
          oap->op_type == OP_FOLDOPEN
          || oap->op_type == OP_FOLDOPENREC,
          oap->op_type == OP_FOLDOPENREC
          || oap->op_type == OP_FOLDCLOSEREC,
          oap->is_VIsual);
      break;

    case OP_FOLDDEL:
    case OP_FOLDDELREC:
      VIsual_reselect = FALSE;          /* don't reselect now */
      deleteFold(oap->start.lnum, oap->end.lnum,
          oap->op_type == OP_FOLDDELREC, oap->is_VIsual);
      break;
    default:
      clearopbeep(oap);
    }
    virtual_op = MAYBE;
    if (!gui_yank) {
      /*
       * if 'sol' not set, go back to old column for some commands
       */
      if (!p_sol && oap->motion_type == MLINE && !oap->end_adjusted
          && (oap->op_type == OP_LSHIFT || oap->op_type == OP_RSHIFT
              || oap->op_type == OP_DELETE))
        coladvance(curwin->w_curswant = old_col);
    } else   {
      curwin->w_cursor = old_cursor;
    }
    oap->block_mode = FALSE;
    clearop(oap);
  }
}

/*
 * Handle indent and format operators and visual mode ":".
 */
static void op_colon(oparg_T *oap)
{
  stuffcharReadbuff(':');
  if (oap->is_VIsual)
    stuffReadbuff((char_u *)"'<,'>");
  else {
    /*
     * Make the range look nice, so it can be repeated.
     */
    if (oap->start.lnum == curwin->w_cursor.lnum)
      stuffcharReadbuff('.');
    else
      stuffnumReadbuff((long)oap->start.lnum);
    if (oap->end.lnum != oap->start.lnum) {
      stuffcharReadbuff(',');
      if (oap->end.lnum == curwin->w_cursor.lnum)
        stuffcharReadbuff('.');
      else if (oap->end.lnum == curbuf->b_ml.ml_line_count)
        stuffcharReadbuff('$');
      else if (oap->start.lnum == curwin->w_cursor.lnum) {
        stuffReadbuff((char_u *)".+");
        stuffnumReadbuff((long)oap->line_count - 1);
      } else
        stuffnumReadbuff((long)oap->end.lnum);
    }
  }
  if (oap->op_type != OP_COLON)
    stuffReadbuff((char_u *)"!");
  if (oap->op_type == OP_INDENT) {
    stuffReadbuff(get_equalprg());
    stuffReadbuff((char_u *)"\n");
  } else if (oap->op_type == OP_FORMAT)   {
    if (*p_fp == NUL)
      stuffReadbuff((char_u *)"fmt");
    else
      stuffReadbuff(p_fp);
    stuffReadbuff((char_u *)"\n']");
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
  char_u      *(argv[1]);
  int save_virtual_op = virtual_op;

  if (*p_opfunc == NUL)
    EMSG(_("E774: 'operatorfunc' is empty"));
  else {
    /* Set '[ and '] marks to text to be operated on. */
    curbuf->b_op_start = oap->start;
    curbuf->b_op_end = oap->end;
    if (oap->motion_type != MLINE && !oap->inclusive)
      /* Exclude the end position. */
      decl(&curbuf->b_op_end);

    if (oap->block_mode)
      argv[0] = (char_u *)"block";
    else if (oap->motion_type == MLINE)
      argv[0] = (char_u *)"line";
    else
      argv[0] = (char_u *)"char";

    /* Reset virtual_op so that 'virtualedit' can be changed in the
     * function. */
    virtual_op = MAYBE;

    (void)call_func_retnr(p_opfunc, 1, argv, FALSE);

    virtual_op = save_virtual_op;
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
 * Return TRUE if start_arrow() should be called for edit mode.
 */
int 
do_mouse (
    oparg_T *oap,               /* operator argument, can be NULL */
    int c,                          /* K_LEFTMOUSE, etc */
    int dir,                        /* Direction to 'put' if necessary */
    long count,
    int fixindent                  /* PUT_FIXINDENT if fixing indent necessary */
)
{
  static int do_always = FALSE;         /* ignore 'mouse' setting next time */
  static int got_click = FALSE;         /* got a click some time back */

  int which_button;             /* MOUSE_LEFT, _MIDDLE or _RIGHT */
  int is_click;                 /* If FALSE it's a drag or release event */
  int is_drag;                  /* If TRUE it's a drag event */
  int jump_flags = 0;           /* flags for jump_to_mouse() */
  pos_T start_visual;
  int moved;                    /* Has cursor moved? */
  int in_status_line;           /* mouse in status line */
  static int in_tab_line = FALSE;    /* mouse clicked in tab line */
  int in_sep_line;              /* mouse in vertical separator line */
  int c1, c2;
  pos_T save_cursor;
  win_T       *old_curwin = curwin;
  static pos_T orig_cursor;
  colnr_T leftcol, rightcol;
  pos_T end_visual;
  int diff;
  int old_active = VIsual_active;
  int old_mode = VIsual_mode;
  int regname;

  save_cursor = curwin->w_cursor;

  /*
   * When GUI is active, always recognize mouse events, otherwise:
   * - Ignore mouse event in normal mode if 'mouse' doesn't include 'n'.
   * - Ignore mouse event in visual mode if 'mouse' doesn't include 'v'.
   * - For command line and insert mode 'mouse' is checked before calling
   *	 do_mouse().
   */
  if (do_always)
    do_always = FALSE;
  else {
    if (VIsual_active) {
      if (!mouse_has(MOUSE_VISUAL))
        return FALSE;
    } else if (State == NORMAL && !mouse_has(MOUSE_NORMAL))
      return FALSE;
  }

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
    got_click = TRUE;
  else {
    if (!got_click)                     /* didn't get click, ignore */
      return FALSE;
    if (!is_drag) {                     /* release, reset got_click */
      got_click = FALSE;
      if (in_tab_line) {
        in_tab_line = FALSE;
        return FALSE;
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
    got_click = FALSE;                  /* ignore drag&release now */
    return FALSE;
  }

  /*
   * CTRL only works with left mouse button
   */
  if ((mod_mask & MOD_MASK_CTRL) && which_button != MOUSE_LEFT)
    return FALSE;

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
    return FALSE;

  /*
   * If the button press was used as the movement command for an operator
   * (eg "d<MOUSE>"), or it is the middle button that is held down, ignore
   * drag/release events.
   */
  if (!is_click && which_button == MOUSE_MIDDLE)
    return FALSE;

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
        return FALSE;
      }

      /*
       * If visual was active, yank the highlighted text and put it
       * before the mouse pointer position.
       * In Select mode replace the highlighted text with the clipboard.
       */
      if (VIsual_active) {
        if (VIsual_select) {
          stuffcharReadbuff(Ctrl_G);
          stuffReadbuff((char_u *)"\"+p");
        } else   {
          stuffcharReadbuff('y');
          stuffcharReadbuff(K_MIDDLEMOUSE);
        }
        do_always = TRUE;               /* ignore 'mouse' setting next time */
        return FALSE;
      }
      /*
       * The rest is below jump_to_mouse()
       */
    } else if ((State & INSERT) == 0)
      return FALSE;

    /*
     * Middle click in insert mode doesn't move the mouse, just insert the
     * contents of a register.  '.' register is special, can't insert that
     * with do_put().
     * Also paste at the cursor if the current mode isn't in 'mouse' (only
     * happens for the GUI).
     */
    if ((State & INSERT) || !mouse_has(MOUSE_NORMAL)) {
      if (regname == '.')
        insert_reg(regname, TRUE);
      else {
        if ((State & REPLACE_FLAG) && !yank_register_mline(regname))
          insert_reg(regname, TRUE);
        else {
          do_put(regname, BACKWARD, 1L, fixindent | PUT_CURSEND);

          /* Repeat it with CTRL-R CTRL-O r or CTRL-R CTRL-P r */
          AppendCharToRedobuff(Ctrl_R);
          AppendCharToRedobuff(fixindent ? Ctrl_P : Ctrl_O);
          AppendCharToRedobuff(regname == 0 ? '"' : regname);
        }
      }
      return FALSE;
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
        c1 = TabPageIdxs[mouse_col];
        tabpage_move(c1 <= 0 ? 9999 : c1 - 1);
      }
      return FALSE;
    }

    /* click in a tab selects that tab page */
    if (is_click
        && cmdwin_type == 0
        && mouse_col < Columns) {
      in_tab_line = TRUE;
      c1 = TabPageIdxs[mouse_col];
      if (c1 >= 0) {
        if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK) {
          /* double click opens new page */
          end_visual_mode();
          tabpage_new();
          tabpage_move(c1 == 0 ? 9999 : c1 - 1);
        } else   {
          /* Go to specified tab page, or next one if not clicking
           * on a label. */
          goto_tabpage(c1);

          /* It's like clicking on the status line of a window. */
          if (curwin != old_curwin)
            end_visual_mode();
        }
      } else if (c1 < 0)   {
        tabpage_T       *tp;

        /* Close the current or specified tab page. */
        if (c1 == -999)
          tp = curtab;
        else
          tp = find_tabpage(-c1);
        if (tp == curtab) {
          if (first_tabpage->tp_next != NULL)
            tabpage_close(FALSE);
        } else if (tp != NULL)
          tabpage_close_other(tp, FALSE);
      }
    }
    return TRUE;
  } else if (is_drag && in_tab_line)   {
    c1 = TabPageIdxs[mouse_col];
    tabpage_move(c1 <= 0 ? 9999 : c1 - 1);
    return FALSE;
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
#if defined(FEAT_GUI_MOTIF) || defined(FEAT_GUI_GTK) \
      || defined(FEAT_GUI_PHOTON) || defined(FEAT_GUI_MAC)
      if (!is_click)
        return FALSE;
#endif
#if defined(FEAT_GUI_MOTIF) || defined(FEAT_GUI_GTK) \
      || defined(FEAT_GUI_ATHENA) || defined(FEAT_GUI_MSWIN) \
      || defined(FEAT_GUI_MAC) || defined(FEAT_GUI_PHOTON)
      if (gui.in_use) {
        jump_flags = 0;
        if (STRCMP(p_mousem, "popup_setpos") == 0) {
          /* First set the cursor position before showing the popup
           * menu. */
          if (VIsual_active) {
            pos_T m_pos;

            /*
             * set MOUSE_MAY_STOP_VIS if we are outside the
             * selection or the current window (might have false
             * negative here)
             */
            if (mouse_row < W_WINROW(curwin)
                || mouse_row
                > (W_WINROW(curwin) + curwin->w_height))
              jump_flags = MOUSE_MAY_STOP_VIS;
            else if (get_fpos_of_mouse(&m_pos) != IN_BUFFER)
              jump_flags = MOUSE_MAY_STOP_VIS;
            else {
              if ((lt(curwin->w_cursor, VIsual)
                   && (lt(m_pos, curwin->w_cursor)
                       || lt(VIsual, m_pos)))
                  || (lt(VIsual, curwin->w_cursor)
                      && (lt(m_pos, VIsual)
                          || lt(curwin->w_cursor, m_pos)))) {
                jump_flags = MOUSE_MAY_STOP_VIS;
              } else if (VIsual_mode == Ctrl_V)   {
                getvcols(curwin, &curwin->w_cursor, &VIsual,
                    &leftcol, &rightcol);
                getvcol(curwin, &m_pos, NULL, &m_pos.col, NULL);
                if (m_pos.col < leftcol || m_pos.col > rightcol)
                  jump_flags = MOUSE_MAY_STOP_VIS;
              }
            }
          } else
            jump_flags = MOUSE_MAY_STOP_VIS;
        }
        if (jump_flags) {
          jump_flags = jump_to_mouse(jump_flags, NULL, which_button);
          update_curbuf(
              VIsual_active ? INVERTED :
              VALID);
          setcursor();
          out_flush();              /* Update before showing popup menu */
        }
        gui_show_popupmenu();
        return (jump_flags & CURSOR_MOVED) != 0;
      } else
        return FALSE;
#else
      return FALSE;
#endif
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
    } else if (which_button == MOUSE_RIGHT)   {
      if (is_click && VIsual_active) {
        /*
         * Remember the start and end of visual before moving the
         * cursor.
         */
        if (lt(curwin->w_cursor, VIsual)) {
          start_visual = curwin->w_cursor;
          end_visual = VIsual;
        } else   {
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
    got_click = FALSE;
    oap->motion_type = MCHAR;
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
    scroll_redraw(FALSE, 1L);
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
      if (curwin->w_cursor.lnum <
          (start_visual.lnum + end_visual.lnum) / 2)
        end_visual.lnum = end_visual.lnum;
      else
        end_visual.lnum = start_visual.lnum;

      /* move VIsual to the right column */
      start_visual = curwin->w_cursor;              /* save the cursor pos */
      curwin->w_cursor = end_visual;
      coladvance(end_visual.col);
      VIsual = curwin->w_cursor;
      curwin->w_cursor = start_visual;              /* restore the cursor */
    } else   {
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
    if (yank_register_mline(regname)) {
      if (mouse_past_bottom)
        dir = FORWARD;
    } else if (mouse_past_eol)
      dir = FORWARD;

    if (fixindent) {
      c1 = (dir == BACKWARD) ? '[' : ']';
      c2 = 'p';
    } else   {
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
    do_put(regname, dir, count, fixindent | PUT_CURSEND);
  }
  /*
   * Ctrl-Mouse click or double click in a quickfix window jumps to the
   * error under the mouse pointer.
   */
  else if (((mod_mask & MOD_MASK_CTRL)
            || (mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK)
           && bt_quickfix(curbuf)) {
    if (State & INSERT)
      stuffcharReadbuff(Ctrl_O);
    if (curwin->w_llist_ref == NULL)            /* quickfix window */
      stuffReadbuff((char_u *)":.cc\n");
    else                                        /* location list window */
      stuffReadbuff((char_u *)":.ll\n");
    got_click = FALSE;                  /* ignore drag&release now */
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
    got_click = FALSE;                  /* ignore drag&release now */
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
  } else if (in_sep_line)   {
  } else if ((mod_mask & MOD_MASK_MULTI_CLICK) && (State & (NORMAL | INSERT))
             && mouse_has(MOUSE_VISUAL)) {
    if (is_click || !VIsual_active) {
      if (VIsual_active)
        orig_cursor = VIsual;
      else {
        check_visual_highlight();
        VIsual = curwin->w_cursor;
        orig_cursor = VIsual;
        VIsual_active = TRUE;
        VIsual_reselect = TRUE;
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
        while (gc = gchar_pos(&end_visual), vim_iswhite(gc))
          inc(&end_visual);
        if (oap != NULL)
          oap->motion_type = MCHAR;
        if (oap != NULL
            && VIsual_mode == 'v'
            && !vim_iswordc(gchar_pos(&end_visual))
            && equalpos(curwin->w_cursor, VIsual)
            && (pos = findmatch(oap, NUL)) != NULL) {
          curwin->w_cursor = *pos;
          if (oap->motion_type == MLINE)
            VIsual_mode = 'V';
          else if (*p_sel == 'e') {
            if (lt(curwin->w_cursor, VIsual))
              ++VIsual.col;
            else
              ++curwin->w_cursor.col;
          }
        }
      }

      if (pos == NULL && (is_click || is_drag)) {
        /* When not found a match or when dragging: extend to include
         * a word. */
        if (lt(curwin->w_cursor, orig_cursor)) {
          find_start_of_word(&curwin->w_cursor);
          find_end_of_word(&VIsual);
        } else   {
          find_start_of_word(&VIsual);
          if (*p_sel == 'e' && *ml_get_cursor() != NUL)
            curwin->w_cursor.col +=
              (*mb_ptr2len)(ml_get_cursor());
          find_end_of_word(&curwin->w_cursor);
        }
      }
      curwin->w_set_curswant = TRUE;
    }
    if (is_click)
      redraw_curbuf_later(INVERTED);            /* update the inversion */
  } else if (VIsual_active && !old_active)   {
    if (mod_mask & MOD_MASK_ALT)
      VIsual_mode = Ctrl_V;
    else
      VIsual_mode = 'v';
  }

  /* If Visual mode changed show it later. */
  if ((!VIsual_active && old_active && mode_displayed)
      || (VIsual_active && p_smd && msg_silent == 0
          && (!old_active || VIsual_mode != old_mode)))
    redraw_cmdline = TRUE;

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
    col -= (*mb_head_off)(line, line + col);
    if (get_mouse_class(line + col) != cclass)
      break;
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
    --pos->col;
    pos->col -= (*mb_head_off)(line, line + pos->col);
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
 * Check if  highlighting for visual mode is possible, give a warning message
 * if not.
 */
void check_visual_highlight(void)          {
  static int did_check = FALSE;

  if (full_screen) {
    if (!did_check && hl_attr(HLF_V) == 0)
      MSG(_("Warning: terminal cannot highlight"));
    did_check = TRUE;
  }
}

/*
 * End Visual mode.
 * This function should ALWAYS be called to end Visual mode, except from
 * do_pending_operator().
 */
void end_visual_mode(void)          {

  VIsual_active = FALSE;
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

  if (mode_displayed)
    clear_cmdline = TRUE;               /* unshow visual mode later */
  else
    clear_showcmd();

  adjust_cursor_eol();
}

/*
 * Reset VIsual_active and VIsual_reselect.
 */
void reset_VIsual_and_resel(void)          {
  if (VIsual_active) {
    end_visual_mode();
    redraw_curbuf_later(INVERTED);      /* delete the inversion later */
  }
  VIsual_reselect = FALSE;
}

/*
 * Reset VIsual_active and VIsual_reselect if it's set.
 */
void reset_VIsual(void)          {
  if (VIsual_active) {
    end_visual_mode();
    redraw_curbuf_later(INVERTED);      /* delete the inversion later */
    VIsual_reselect = FALSE;
  }
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
int find_ident_under_cursor(char_u **string, int find_type)
{
  return find_ident_at_pos(curwin, curwin->w_cursor.lnum,
      curwin->w_cursor.col, string, find_type);
}

/*
 * Like find_ident_under_cursor(), but for any window and any position.
 * However: Uses 'iskeyword' from the current window!.
 */
int find_ident_at_pos(win_T *wp, linenr_T lnum, colnr_T startcol, char_u **string, int find_type)
{
  char_u      *ptr;
  int col = 0;                      /* init to shut up GCC */
  int i;
  int this_class = 0;
  int prev_class;
  int prevcol;

  /*
   * if i == 0: try to find an identifier
   * if i == 1: try to find any non-white string
   */
  ptr = ml_get_buf(wp->w_buffer, lnum, FALSE);
  for (i = (find_type & FIND_IDENT) ? 0 : 1; i < 2; ++i) {
    /*
     * 1. skip to start of identifier/string
     */
    col = startcol;
    if (has_mbyte) {
      while (ptr[col] != NUL) {
        this_class = mb_get_class(ptr + col);
        if (this_class != 0 && (i == 1 || this_class != 1))
          break;
        col += (*mb_ptr2len)(ptr + col);
      }
    } else
      while (ptr[col] != NUL
             && (i == 0 ? !vim_iswordc(ptr[col]) : vim_iswhite(ptr[col]))
             )
        ++col;


    /*
     * 2. Back up to start of identifier/string.
     */
    if (has_mbyte) {
      /* Remember class of character under cursor. */
      this_class = mb_get_class(ptr + col);
      while (col > 0 && this_class != 0) {
        prevcol = col - 1 - (*mb_head_off)(ptr, ptr + col - 1);
        prev_class = mb_get_class(ptr + prevcol);
        if (this_class != prev_class
            && (i == 0
                || prev_class == 0
                || (find_type & FIND_IDENT))
            )
          break;
        col = prevcol;
      }

      /* If we don't want just any old string, or we've found an
       * identifier, stop searching. */
      if (this_class > 2)
        this_class = 2;
      if (!(find_type & FIND_STRING) || this_class == 2)
        break;
    } else   {
      while (col > 0
             && ((i == 0
                  ? vim_iswordc(ptr[col - 1])
                  : (!vim_iswhite(ptr[col - 1])
                     && (!(find_type & FIND_IDENT)
                         || !vim_iswordc(ptr[col - 1]))))
                 ))
        --col;

      /* If we don't want just any old string, or we've found an
       * identifier, stop searching. */
      if (!(find_type & FIND_STRING) || vim_iswordc(ptr[col]))
        break;
    }
  }

  if (ptr[col] == NUL || (i == 0 && (
                            has_mbyte ? this_class != 2 :
                            !vim_iswordc(ptr[col])))) {
    /*
     * didn't find an identifier or string
     */
    if (find_type & FIND_STRING)
      EMSG(_("E348: No string under cursor"));
    else
      EMSG(_(e_noident));
    return 0;
  }
  ptr += col;
  *string = ptr;

  /*
   * 3. Find the end if the identifier/string.
   */
  col = 0;
  if (has_mbyte) {
    /* Search for point of changing multibyte character class. */
    this_class = mb_get_class(ptr);
    while (ptr[col] != NUL
           && ((i == 0 ? mb_get_class(ptr + col) == this_class
                : mb_get_class(ptr + col) != 0)
               ))
      col += (*mb_ptr2len)(ptr + col);
  } else
    while ((i == 0 ? vim_iswordc(ptr[col])
            : (ptr[col] != NUL && !vim_iswhite(ptr[col])))
           ) {
      ++col;
    }

  return col;
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
 * return TRUE if operator was active
 */
static int checkclearop(oparg_T *oap)
{
  if (oap->op_type == OP_NOP)
    return FALSE;
  clearopbeep(oap);
  return TRUE;
}

/*
 * Check for operator or Visual active.  Clear active operator.
 *
 * Return TRUE if operator or Visual was active.
 */
static int checkclearopq(oparg_T *oap)
{
  if (oap->op_type == OP_NOP
      && !VIsual_active
      )
    return FALSE;
  clearopbeep(oap);
  return TRUE;
}

static void clearop(oparg_T *oap)
{
  oap->op_type = OP_NOP;
  oap->regname = 0;
  oap->motion_force = NUL;
  oap->use_reg_one = FALSE;
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

/*
 * Routines for displaying a partly typed command
 */

# define SHOWCMD_BUFLEN SHOWCMD_COLS + 1 + 30
static char_u showcmd_buf[SHOWCMD_BUFLEN];
static char_u old_showcmd_buf[SHOWCMD_BUFLEN];    /* For push_showcmd() */
static int showcmd_is_clear = TRUE;
static int showcmd_visual = FALSE;

static void display_showcmd(void);

void clear_showcmd(void)          {
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
    } else   {
      top = curwin->w_cursor.lnum;
      bot = VIsual.lnum;
    }
    /* Include closed folds as a whole. */
    hasFolding(top, &top, NULL);
    hasFolding(bot, NULL, &bot);
    lines = bot - top + 1;

    if (VIsual_mode == Ctrl_V) {
      char_u *saved_sbr = p_sbr;

      /* Make 'sbr' empty for a moment to get the correct size. */
      p_sbr = empty_option;
      getvcols(curwin, &curwin->w_cursor, &VIsual, &leftcol, &rightcol);
      p_sbr = saved_sbr;
      sprintf((char *)showcmd_buf, "%ldx%ld", lines,
          (long)(rightcol - leftcol + 1));
    } else if (VIsual_mode == 'V' || VIsual.lnum != curwin->w_cursor.lnum)
      sprintf((char *)showcmd_buf, "%ld", lines);
    else {
      char_u  *s, *e;
      int l;
      int bytes = 0;
      int chars = 0;

      if (cursor_bot) {
        s = ml_get_pos(&VIsual);
        e = ml_get_cursor();
      } else   {
        s = ml_get_cursor();
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
    showcmd_visual = TRUE;
  } else   {
    showcmd_buf[0] = NUL;
    showcmd_visual = FALSE;

    /* Don't actually display something if there is nothing to clear. */
    if (showcmd_is_clear)
      return;
  }

  display_showcmd();
}

/*
 * Add 'c' to string of shown command chars.
 * Return TRUE if output has been written (and setcursor() has been called).
 */
int add_to_showcmd(int c)
{
  char_u      *p;
  int old_len;
  int extra_len;
  int overflow;
  int i;
  static int ignore[] =
  {
    K_IGNORE,
    K_LEFTMOUSE, K_LEFTDRAG, K_LEFTRELEASE,
    K_MIDDLEMOUSE, K_MIDDLEDRAG, K_MIDDLERELEASE,
    K_RIGHTMOUSE, K_RIGHTDRAG, K_RIGHTRELEASE,
    K_MOUSEDOWN, K_MOUSEUP, K_MOUSELEFT, K_MOUSERIGHT,
    K_X1MOUSE, K_X1DRAG, K_X1RELEASE, K_X2MOUSE, K_X2DRAG, K_X2RELEASE,
    K_CURSORHOLD,
    0
  };

  if (!p_sc || msg_silent != 0)
    return FALSE;

  if (showcmd_visual) {
    showcmd_buf[0] = NUL;
    showcmd_visual = FALSE;
  }

  /* Ignore keys that are scrollbar updates and mouse clicks */
  if (IS_SPECIAL(c))
    for (i = 0; ignore[i] != 0; ++i)
      if (ignore[i] == c)
        return FALSE;

  p = transchar(c);
  if (*p == ' ')
    STRCPY(p, "<20>");
  old_len = (int)STRLEN(showcmd_buf);
  extra_len = (int)STRLEN(p);
  overflow = old_len + extra_len - SHOWCMD_COLS;
  if (overflow > 0)
    mch_memmove(showcmd_buf, showcmd_buf + overflow,
        old_len - overflow + 1);
  STRCAT(showcmd_buf, p);

  if (char_avail())
    return FALSE;

  display_showcmd();

  return TRUE;
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
void push_showcmd(void)          {
  if (p_sc)
    STRCPY(old_showcmd_buf, showcmd_buf);
}

void pop_showcmd(void)          {
  if (!p_sc)
    return;

  STRCPY(showcmd_buf, old_showcmd_buf);

  display_showcmd();
}

static void display_showcmd(void)                 {
  int len;

  cursor_off();

  len = (int)STRLEN(showcmd_buf);
  if (len == 0)
    showcmd_is_clear = TRUE;
  else {
    screen_puts(showcmd_buf, (int)Rows - 1, sc_col, 0);
    showcmd_is_clear = FALSE;
  }

  /*
   * clear the rest of an old message by outputting up to SHOWCMD_COLS
   * spaces
   */
  screen_puts((char_u *)"          " + len, (int)Rows - 1, sc_col + len, 0);

  setcursor();              /* put cursor back where it belongs */
}

/*
 * When "check" is FALSE, prepare for commands that scroll the window.
 * When "check" is TRUE, take care of scroll-binding after the window has
 * scrolled.  Called from normal_cmd() and edit().
 */
void do_check_scrollbind(int check)
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
      did_syncbind = FALSE;
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
    } else if (vim_strchr(p_sbo, 'j'))   { /* jump flag set in 'scrollopt' */
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
  int want_ver;
  int want_hor;
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
  for (curwin = firstwin; curwin; curwin = curwin->w_next) {
    curbuf = curwin->w_buffer;
    /* skip original window  and windows with 'noscrollbind' */
    if (curwin != old_curwin && curwin->w_p_scb) {
      /*
       * do the vertical scroll
       */
      if (want_ver) {
        if (old_curwin->w_p_diff && curwin->w_p_diff) {
          diff_set_topline(old_curwin, curwin);
        } else   {
          curwin->w_scbind_pos += topline_diff;
          topline = curwin->w_scbind_pos;
          if (topline > curbuf->b_ml.ml_line_count)
            topline = curbuf->b_ml.ml_line_count;
          if (topline < 1)
            topline = 1;

          y = topline - curwin->w_topline;
          if (y > 0)
            scrollup(y, FALSE);
          else
            scrolldown(-y, FALSE);
        }

        redraw_later(VALID);
        cursor_correct();
        curwin->w_redr_status = TRUE;
      }

      /*
       * do the horizontal scroll
       */
      if (want_hor && curwin->w_leftcol != tgt_leftcol) {
        curwin->w_leftcol = tgt_leftcol;
        leftcol_changed();
      }
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
  if (!checkclearopq(cap->oap)
      && do_addsub((int)cap->cmdchar, cap->count1) == OK)
    prep_redo_cmd(cap);
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
  int len;
  char_u      *ptr;

  if ((len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0
      || find_decl(ptr, len, nchar == 'd', thisblock, 0) == FAIL)
    clearopbeep(oap);
  else if ((fdo_flags & FDO_SEARCH) && KeyTyped && oap->op_type == OP_NOP)
    foldOpenCursor();
}

/*
 * Search for variable declaration of "ptr[len]".
 * When "locally" is TRUE in the current function ("gd"), otherwise in the
 * current file ("gD").
 * When "thisblock" is TRUE check the {} block scope.
 * Return FAIL when not found.
 */
int 
find_decl (
    char_u *ptr,
    int len,
    int locally,
    int thisblock,
    int searchflags                /* flags passed to searchit() */
)
{
  char_u      *pat;
  pos_T old_pos;
  pos_T par_pos;
  pos_T found_pos;
  int t;
  int save_p_ws;
  int save_p_scs;
  int retval = OK;
  int incll;

  if ((pat = alloc(len + 7)) == NULL)
    return FAIL;

  /* Put "\V" before the pattern to avoid that the special meaning of "."
   * and "~" causes trouble. */
  sprintf((char *)pat, vim_iswordp(ptr) ? "\\V\\<%.*s\\>" : "\\V%.*s",
      len, ptr);
  old_pos = curwin->w_cursor;
  save_p_ws = p_ws;
  save_p_scs = p_scs;
  p_ws = FALSE;         /* don't wrap around end of file now */
  p_scs = FALSE;        /* don't switch ignorecase off now */

  /*
   * With "gD" go to line 1.
   * With "gd" Search back for the start of the current function, then go
   * back until a blank line.  If this fails go to line 1.
   */
  if (!locally || !findpar(&incll, BACKWARD, 1L, '{', FALSE)) {
    setpcmark();                        /* Set in findpar() otherwise */
    curwin->w_cursor.lnum = 1;
    par_pos = curwin->w_cursor;
  } else   {
    par_pos = curwin->w_cursor;
    while (curwin->w_cursor.lnum > 1 && *skipwhite(ml_get_curline()) != NUL)
      --curwin->w_cursor.lnum;
  }
  curwin->w_cursor.col = 0;

  /* Search forward for the identifier, ignore comment lines. */
  clearpos(&found_pos);
  for (;; ) {
    t = searchit(curwin, curbuf, &curwin->w_cursor, FORWARD,
        pat, 1L, searchflags, RE_LAST, (linenr_T)0, NULL);
    if (curwin->w_cursor.lnum >= old_pos.lnum)
      t = FAIL;         /* match after start is failure too */

    if (thisblock && t != FAIL) {
      pos_T       *pos;

      /* Check that the block the match is in doesn't end before the
       * position where we started the search from. */
      if ((pos = findmatchlimit(NULL, '}', FM_FORWARD,
               (int)(old_pos.lnum - curwin->w_cursor.lnum + 1))) != NULL
          && pos->lnum < old_pos.lnum)
        continue;
    }

    if (t == FAIL) {
      /* If we previously found a valid position, use it. */
      if (found_pos.lnum != 0) {
        curwin->w_cursor = found_pos;
        t = OK;
      }
      break;
    }
    if (get_leader_len(ml_get_curline(), NULL, FALSE, TRUE) > 0) {
      /* Ignore this line, continue at start of next line. */
      ++curwin->w_cursor.lnum;
      curwin->w_cursor.col = 0;
      continue;
    }
    if (!locally)       /* global search: use first match found */
      break;
    if (curwin->w_cursor.lnum >= par_pos.lnum) {
      /* If we previously found a valid position, use it. */
      if (found_pos.lnum != 0)
        curwin->w_cursor = found_pos;
      break;
    }

    /* For finding a local variable and the match is before the "{" search
     * to find a later match.  For K&R style function declarations this
     * skips the function header without types. */
    found_pos = curwin->w_cursor;
  }

  if (t == FAIL) {
    retval = FAIL;
    curwin->w_cursor = old_pos;
  } else   {
    curwin->w_set_curswant = TRUE;
    /* "n" searches forward now */
    reset_search_dir();
  }

  vim_free(pat);
  p_ws = save_p_ws;
  p_scs = save_p_scs;

  return retval;
}

/*
 * Move 'dist' lines in direction 'dir', counting lines by *screen*
 * lines rather than lines in the file.
 * 'dist' must be positive.
 *
 * Return OK if able to move cursor, FAIL otherwise.
 */
static int nv_screengo(oparg_T *oap, int dir, long dist)
{
  int linelen = linetabsize(ml_get_curline());
  int retval = OK;
  int atend = FALSE;
  int n;
  int col_off1;                 /* margin offset for first screen line */
  int col_off2;                 /* margin offset for wrapped screen line */
  int width1;                   /* text width for first screen line */
  int width2;                   /* test width for wrapped screen line */

  oap->motion_type = MCHAR;
  oap->inclusive = (curwin->w_curswant == MAXCOL);

  col_off1 = curwin_col_off();
  col_off2 = col_off1 - curwin_col_off2();
  width1 = W_WIDTH(curwin) - col_off1;
  width2 = W_WIDTH(curwin) - col_off2;

  if (curwin->w_width != 0) {
    /*
     * Instead of sticking at the last character of the buffer line we
     * try to stick in the last column of the screen.
     */
    if (curwin->w_curswant == MAXCOL) {
      atend = TRUE;
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
    } else   {
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
            retval = FAIL;
            break;
          }
          --curwin->w_cursor.lnum;
          /* Move to the start of a closed fold.  Don't do that when
           * 'foldopen' contains "all": it will open in a moment. */
          if (!(fdo_flags & FDO_ALL))
            (void)hasFolding(curwin->w_cursor.lnum,
                &curwin->w_cursor.lnum, NULL);
          linelen = linetabsize(ml_get_curline());
          if (linelen > width1)
            curwin->w_curswant += (((linelen - width1 - 1) / width2)
                                   + 1) * width2;
        }
      } else   { /* dir == FORWARD */
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
            retval = FAIL;
            break;
          }
          curwin->w_cursor.lnum++;
          curwin->w_curswant %= width2;
          linelen = linetabsize(ml_get_curline());
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
    if (curwin->w_virtcol > curwin->w_curswant
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

    /* find the window at the pointer coordinates */
    curwin = mouse_find_win(&row, &col);
    curbuf = curwin->w_buffer;
  }

  if (cap->arg == MSCR_UP || cap->arg == MSCR_DOWN) {
    if (mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL)) {
      (void)onepage(cap->arg ? FORWARD : BACKWARD, 1L);
    } else   {
      cap->count1 = 3;
      cap->count0 = 3;
      nv_scroll_line(cap);
    }
  }

  curwin->w_redr_status = TRUE;

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
 * cap->arg must be TRUE for CTRL-E.
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
    scrollup(count, TRUE);
  else
    scrolldown(count, TRUE);
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
            || cursor_down(1L, FALSE) == FAIL)
          break;
      } else   {
        if (curwin->w_cursor.lnum < prev_lnum
            || prev_topline == 1L
            || cursor_up(1L, FALSE) == FAIL)
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
  long n;
  colnr_T col;
  int nchar = cap->nchar;
  long old_fdl = curwin->w_p_fdl;
  int old_fen = curwin->w_p_fen;
  int undo = FALSE;

  if (VIM_ISDIGIT(nchar)) {
    /*
     * "z123{nchar}": edit the count before obtaining {nchar}
     */
    if (checkclearop(cap->oap))
      return;
    n = nchar - '0';
    for (;; ) {
#ifdef USE_ON_FLY_SCROLL
      dont_scroll = TRUE;               /* disallow scrolling here */
#endif
      ++no_mapping;
      ++allow_keys;         /* no mapping for nchar, but allow key codes */
      nchar = plain_vgetc();
      LANGMAP_ADJUST(nchar, TRUE);
      --no_mapping;
      --allow_keys;
      (void)add_to_showcmd(nchar);
      if (nchar == K_DEL || nchar == K_KDEL)
        n /= 10;
      else if (VIM_ISDIGIT(nchar))
        n = n * 10 + (nchar - '0');
      else if (nchar == CAR) {
        win_setheight((int)n);
        break;
      } else if (nchar == 'l'
                 || nchar == 'h'
                 || nchar == K_LEFT
                 || nchar == K_RIGHT) {
        cap->count1 = n ? n * cap->count1 : cap->count1;
        goto dozet;
      } else   {
        clearopbeep(cap->oap);
        break;
      }
    }
    cap->oap->op_type = OP_NOP;
    return;
  }

dozet:
  if (
    /* "zf" and "zF" are always an operator, "zd", "zo", "zO", "zc"
     * and "zC" only in Visual mode.  "zj" and "zk" are motion
     * commands. */
    cap->nchar != 'f' && cap->nchar != 'F'
    && !(VIsual_active && vim_strchr((char_u *)"dcCoO", cap->nchar))
    && cap->nchar != 'j' && cap->nchar != 'k'
    &&
    checkclearop(cap->oap))
    return;

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
  /* FALLTHROUGH */
  case NL:
  case CAR:
  case K_KENTER:
    beginline(BL_WHITE | BL_FIX);
  /* FALLTHROUGH */

  case 't':   scroll_cursor_top(0, TRUE);
    redraw_later(VALID);
    break;

  /* "z." and "zz": put cursor in middle of screen */
  case '.':   beginline(BL_WHITE | BL_FIX);
  /* FALLTHROUGH */

  case 'z':   scroll_cursor_halfway(TRUE);
    redraw_later(VALID);
    break;

  /* "z^", "z-" and "zb": put cursor at bottom of screen */
  case '^':     /* Strange Vi behavior: <count>z^ finds line at top of window
                 * when <count> is at bottom of window, and puts that one at
                 * bottom of window. */
    if (cap->count0 != 0) {
      scroll_cursor_bot(0, TRUE);
      curwin->w_cursor.lnum = curwin->w_topline;
    } else if (curwin->w_topline == 1)
      curwin->w_cursor.lnum = 1;
    else
      curwin->w_cursor.lnum = curwin->w_topline - 1;
  /* FALLTHROUGH */
  case '-':
    beginline(BL_WHITE | BL_FIX);
  /* FALLTHROUGH */

  case 'b':   scroll_cursor_bot(0, TRUE);
    redraw_later(VALID);
    break;

  /* "zH" - scroll screen right half-page */
  case 'H':
    cap->count1 *= W_WIDTH(curwin) / 2;
  /* FALLTHROUGH */

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

  /* "zL" - scroll screen left half-page */
  case 'L':   cap->count1 *= W_WIDTH(curwin) / 2;
  /* FALLTHROUGH */

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
      if ((long)col > p_siso)
        col -= p_siso;
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
      n = W_WIDTH(curwin) - curwin_col_off();
      if ((long)col + p_siso < n)
        col = 0;
      else
        col = col + p_siso - n + 1;
      if (curwin->w_leftcol != col) {
        curwin->w_leftcol = col;
        redraw_later(NOT_VALID);
      }
  }
    break;

  /* "zF": create fold command */
  /* "zf": create fold operator */
  case 'F':
  case 'f':   if (foldManualAllowed(TRUE)) {
      cap->nchar = 'f';
      nv_operator(cap);
      curwin->w_p_fen = TRUE;

      /* "zF" is like "zfzf" */
      if (nchar == 'F' && cap->oap->op_type == OP_FOLD) {
        nv_operator(cap);
        finish_op = TRUE;
      }
  } else
      clearopbeep(cap->oap);
    break;

  /* "zd": delete fold at cursor */
  /* "zD": delete fold at cursor recursively */
  case 'd':
  case 'D':   if (foldManualAllowed(FALSE)) {
      if (VIsual_active)
        nv_operator(cap);
      else
        deleteFold(curwin->w_cursor.lnum,
            curwin->w_cursor.lnum, nchar == 'D', FALSE);
  }
    break;

  /* "zE": erase all folds */
  case 'E':   if (foldmethodIsManual(curwin)) {
      clearFolding(curwin);
      changed_window_setting();
  } else if (foldmethodIsMarker(curwin))
      deleteFold((linenr_T)1, curbuf->b_ml.ml_line_count,
          TRUE, FALSE);
    else
      EMSG(_("E352: Cannot erase folds with current 'foldmethod'"));
    break;

  /* "zn": fold none: reset 'foldenable' */
  case 'n':   curwin->w_p_fen = FALSE;
    break;

  /* "zN": fold Normal: set 'foldenable' */
  case 'N':   curwin->w_p_fen = TRUE;
    break;

  /* "zi": invert folding: toggle 'foldenable' */
  case 'i':   curwin->w_p_fen = !curwin->w_p_fen;
    break;

  /* "za": open closed fold or close open fold at cursor */
  case 'a':   if (hasFolding(curwin->w_cursor.lnum, NULL, NULL))
      openFold(curwin->w_cursor.lnum, cap->count1);
    else {
      closeFold(curwin->w_cursor.lnum, cap->count1);
      curwin->w_p_fen = TRUE;
    }
    break;

  /* "zA": open fold at cursor recursively */
  case 'A':   if (hasFolding(curwin->w_cursor.lnum, NULL, NULL))
      openFoldRecurse(curwin->w_cursor.lnum);
    else {
      closeFoldRecurse(curwin->w_cursor.lnum);
      curwin->w_p_fen = TRUE;
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
    curwin->w_p_fen = TRUE;
    break;

  /* "zC": close fold recursively */
  case 'C':   if (VIsual_active)
      nv_operator(cap);
    else
      closeFoldRecurse(curwin->w_cursor.lnum);
    curwin->w_p_fen = TRUE;
    break;

  /* "zv": open folds at the cursor */
  case 'v':   foldOpenCursor();
    break;

  /* "zx": re-apply 'foldlevel' and open folds at the cursor */
  case 'x':   curwin->w_p_fen = TRUE;
    curwin->w_foldinvalid = TRUE;               /* recompute folds */
    newFoldLevel();                             /* update right now */
    foldOpenCursor();
    break;

  /* "zX": undo manual opens/closes, re-apply 'foldlevel' */
  case 'X':   curwin->w_p_fen = TRUE;
    curwin->w_foldinvalid = TRUE;               /* recompute folds */
    old_fdl = -1;                               /* force an update */
    break;

  /* "zm": fold more */
  case 'm':   if (curwin->w_p_fdl > 0)
      --curwin->w_p_fdl;
    old_fdl = -1;                       /* force an update */
    curwin->w_p_fen = TRUE;
    break;

  /* "zM": close all folds */
  case 'M':   curwin->w_p_fdl = 0;
    old_fdl = -1;                       /* force an update */
    curwin->w_p_fen = TRUE;
    break;

  /* "zr": reduce folding */
  case 'r':   ++curwin->w_p_fdl;
    break;

  /* "zR": open all folds */
  case 'R':   curwin->w_p_fdl = getDeepestNesting();
    old_fdl = -1;                       /* force an update */
    break;

  case 'j':     /* "zj" move to next fold downwards */
  case 'k':     /* "zk" move to next fold upwards */
    if (foldMoveTo(TRUE, nchar == 'j' ? FORWARD : BACKWARD,
            cap->count1) == FAIL)
      clearopbeep(cap->oap);
    break;


  case 'u':     /* "zug" and "zuw": undo "zg" and "zw" */
    ++no_mapping;
    ++allow_keys;               /* no mapping for nchar, but allow key codes */
    nchar = plain_vgetc();
    LANGMAP_ADJUST(nchar, TRUE);
    --no_mapping;
    --allow_keys;
    (void)add_to_showcmd(nchar);
    if (vim_strchr((char_u *)"gGwW", nchar) == NULL) {
      clearopbeep(cap->oap);
      break;
    }
    undo = TRUE;
  /*FALLTHROUGH*/

  case 'g':     /* "zg": add good word to word list */
  case 'w':     /* "zw": add wrong word to word list */
  case 'G':     /* "zG": add good word to temp word list */
  case 'W':     /* "zW": add wrong word to temp word list */
  {
    char_u  *ptr = NULL;
    int len;

    if (checkclearop(cap->oap))
      break;
    if (VIsual_active && get_visual_text(cap, &ptr, &len)
        == FAIL)
      return;
    if (ptr == NULL) {
      pos_T pos = curwin->w_cursor;

      /* Find bad word under the cursor.  When 'spell' is
       * off this fails and find_ident_under_cursor() is
       * used below. */
      emsg_off++;
      len = spell_move_to(curwin, FORWARD, TRUE, TRUE, NULL);
      emsg_off--;
      if (len != 0 && curwin->w_cursor.col <= pos.col)
        ptr = ml_get_pos(&curwin->w_cursor);
      curwin->w_cursor = pos;
    }

    if (ptr == NULL && (len = find_ident_under_cursor(&ptr,
                            FIND_IDENT)) == 0)
      return;
    spell_add_word(ptr, len, nchar == 'w' || nchar == 'W',
        (nchar == 'G' || nchar == 'W')
        ? 0 : (int)cap->count1,
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
    win_T       *wp;

    if (foldmethodIsDiff(curwin) && curwin->w_p_scb) {
      /* Adjust 'foldenable' in diff-synced windows. */
      FOR_ALL_WINDOWS(wp)
      {
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
  if (VIsual_active)
    vim_beep();
  else if (!checkclearop(cap->oap))
    do_exmode(FALSE);
}

/*
 * Handle a ":" command.
 */
static void nv_colon(cmdarg_T *cap)
{
  int old_p_im;
  int cmd_result;

  if (VIsual_active)
    nv_operator(cap);
  else {
    if (cap->oap->op_type != OP_NOP) {
      /* Using ":" as a movement is characterwise exclusive. */
      cap->oap->motion_type = MCHAR;
      cap->oap->inclusive = FALSE;
    } else if (cap->count0)   {
      /* translate "count:" into ":.,.+(count - 1)" */
      stuffcharReadbuff('.');
      if (cap->count0 > 1) {
        stuffReadbuff((char_u *)",.+");
        stuffnumReadbuff((long)cap->count0 - 1L);
      }
    }

    /* When typing, don't type below an old message */
    if (KeyTyped)
      compute_cmdrow();

    old_p_im = p_im;

    /* get a command line and execute it */
    cmd_result = do_cmdline(NULL, getexline, NULL,
        cap->oap->op_type != OP_NOP ? DOCMD_KEEPLINE : 0);

    /* If 'insertmode' changed, enter or exit Insert mode */
    if (p_im != old_p_im) {
      if (p_im)
        restart_edit = 'i';
      else
        restart_edit = 0;
    }

    if (cmd_result == FAIL)
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
    fileinfo((int)cap->count0, FALSE, TRUE);
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
    VIsual_select = FALSE;
    showmode();
    restart_VIsual_select = 2;          /* restart Select mode later */
  } else   {
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
        GETF_SETMARK|GETF_ALT, FALSE);
}

/*
 * "Z" commands.
 */
static void nv_Zet(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap)) {
    switch (cap->nchar) {
    /* "ZZ": equivalent to ":x". */
    case 'Z':   do_cmdline_cmd((char_u *)"x");
      break;

    /* "ZQ": equivalent to ":q!" (Elvis compatible). */
    case 'Q':   do_cmdline_cmd((char_u *)"q!");
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
  vim_memset(&ca, 0, sizeof(ca));
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
  char_u      *buf;
  char_u      *newbuf;
  char_u      *p;
  char_u      *kp;              /* value of 'keywordprg' */
  int kp_help;                  /* 'keywordprg' is ":help" */
  int n = 0;                    /* init for GCC */
  int cmdchar;
  int g_cmd;                    /* "g" command */
  int tag_cmd = FALSE;
  char_u      *aux_ptr;
  int isman;
  int isman_s;

  if (cap->cmdchar == 'g') {    /* "g*", "g#", "g]" and "gCTRL-]" */
    cmdchar = cap->nchar;
    g_cmd = TRUE;
  } else   {
    cmdchar = cap->cmdchar;
    g_cmd = FALSE;
  }

  if (cmdchar == POUND)         /* the pound sign, '#' for English keyboards */
    cmdchar = '#';

  /*
   * The "]", "CTRL-]" and "K" commands accept an argument in Visual mode.
   */
  if (cmdchar == ']' || cmdchar == Ctrl_RSB || cmdchar == 'K') {
    if (VIsual_active && get_visual_text(cap, &ptr, &n) == FAIL)
      return;
    if (checkclearopq(cap->oap))
      return;
  }

  if (ptr == NULL && (n = find_ident_under_cursor(&ptr,
                          (cmdchar == '*' || cmdchar == '#')
                          ? FIND_IDENT|FIND_STRING : FIND_IDENT)) == 0) {
    clearop(cap->oap);
    return;
  }

  /* Allocate buffer to put the command in.  Inserting backslashes can
   * double the length of the word.  p_kp / curbuf->b_p_kp could be added
   * and some numbers. */
  kp = (*curbuf->b_p_kp == NUL ? p_kp : curbuf->b_p_kp);
  kp_help = (*kp == NUL || STRCMP(kp, ":he") == 0
             || STRCMP(kp, ":help") == 0);
  buf = alloc((unsigned)(n * 2 + 30 + STRLEN(kp)));
  if (buf == NULL)
    return;
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
    curwin->w_cursor.col = (colnr_T) (ptr - ml_get_curline());

    if (!g_cmd && vim_iswordp(ptr))
      STRCPY(buf, "\\<");
    no_smartcase = TRUE;                /* don't use 'smartcase' now */
    break;

  case 'K':
    if (kp_help)
      STRCPY(buf, "he! ");
    else {
      /* An external command will probably use an argument starting
       * with "-" as an option.  To avoid trouble we skip the "-". */
      while (*ptr == '-' && n > 0) {
        ++ptr;
        --n;
      }
      if (n == 0) {
        EMSG(_(e_noident));              /* found dashes only */
        vim_free(buf);
        return;
      }

      /* When a count is given, turn it into a range.  Is this
       * really what we want? */
      isman = (STRCMP(kp, "man") == 0);
      isman_s = (STRCMP(kp, "man -s") == 0);
      if (cap->count0 != 0 && !(isman || isman_s))
        sprintf((char *)buf, ".,.+%ld", cap->count0 - 1);

      STRCAT(buf, "! ");
      if (cap->count0 == 0 && isman_s)
        STRCAT(buf, "man");
      else
        STRCAT(buf, kp);
      STRCAT(buf, " ");
      if (cap->count0 != 0 && (isman || isman_s)) {
        sprintf((char *)buf + STRLEN(buf), "%ld", cap->count0);
        STRCAT(buf, " ");
      }
    }
    break;

  case ']':
    tag_cmd = TRUE;
    if (p_cst)
      STRCPY(buf, "cstag ");
    else
      STRCPY(buf, "ts ");
    break;

  default:
    tag_cmd = TRUE;
    if (curbuf->b_help)
      STRCPY(buf, "he! ");
    else {
      if (g_cmd)
        STRCPY(buf, "tj ");
      else
        sprintf((char *)buf, "%ldta ", cap->count0);
    }
  }

  /*
   * Now grab the chars in the identifier
   */
  if (cmdchar == 'K' && !kp_help) {
    /* Escape the argument properly for a shell command */
    ptr = vim_strnsave(ptr, n);
    p = vim_strsave_shellescape(ptr, TRUE);
    vim_free(ptr);
    if (p == NULL) {
      vim_free(buf);
      return;
    }
    newbuf = (char_u *)vim_realloc(buf, STRLEN(buf) + STRLEN(p) + 1);
    if (newbuf == NULL) {
      vim_free(buf);
      vim_free(p);
      return;
    }
    buf = newbuf;
    STRCAT(buf, p);
    vim_free(p);
  } else   {
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

    p = buf + STRLEN(buf);
    while (n-- > 0) {
      /* put a backslash before \ and some others */
      if (vim_strchr(aux_ptr, *ptr) != NULL)
        *p++ = '\\';
      /* When current byte is a part of multibyte character, copy all
       * bytes of that character. */
      if (has_mbyte) {
        int i;
        int len = (*mb_ptr2len)(ptr) - 1;

        for (i = 0; i < len && n >= 1; ++i, --n)
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
          has_mbyte ? vim_iswordp(mb_prevptr(ml_get_curline(), ptr)) :
          vim_iswordc(ptr[-1])))
      STRCAT(buf, "\\>");
    /* put pattern in search history */
    init_history();
    add_to_history(HIST_SEARCH, buf, TRUE, NUL);
    normal_search(cap, cmdchar == '*' ? '/' : '?', buf, 0);
  } else
    do_cmdline_cmd(buf);

  vim_free(buf);
}

/*
 * Get visually selected text, within one line only.
 * Returns FAIL if more than one line selected.
 */
int 
get_visual_text (
    cmdarg_T *cap,
    char_u **pp,           /* return: start of selected text */
    int *lenp          /* return: length of selected text */
)
{
  if (VIsual_mode != 'V')
    unadjust_for_sel();
  if (VIsual.lnum != curwin->w_cursor.lnum) {
    if (cap != NULL)
      clearopbeep(cap->oap);
    return FAIL;
  }
  if (VIsual_mode == 'V') {
    *pp = ml_get_curline();
    *lenp = (int)STRLEN(*pp);
  } else   {
    if (lt(curwin->w_cursor, VIsual)) {
      *pp = ml_get_pos(&curwin->w_cursor);
      *lenp = VIsual.col - curwin->w_cursor.col + 1;
    } else   {
      *pp = ml_get_pos(&VIsual);
      *lenp = curwin->w_cursor.col - VIsual.col + 1;
    }
    if (has_mbyte)
      /* Correct the length to include the whole last character. */
      *lenp += (*mb_ptr2len)(*pp + (*lenp - 1)) - 1;
  }
  reset_VIsual_and_resel();
  return OK;
}

/*
 * CTRL-T: backwards in tag stack
 */
static void nv_tagpop(cmdarg_T *cap)
{
  if (!checkclearopq(cap->oap))
    do_tag((char_u *)"", DT_POP, (int)cap->count1, FALSE, TRUE);
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

  cap->oap->motion_type = MLINE;
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
  } else   {
    if (cap->cmdchar == 'M') {
      /* Don't count filler lines above the window. */
      used -= diff_check_fill(curwin, curwin->w_topline)
              - curwin->w_topfill;
      validate_botline();           /* make sure w_empty_rows is valid */
      half = (curwin->w_height - curwin->w_empty_rows + 1) / 2;
      for (n = 0; curwin->w_topline + n < curbuf->b_ml.ml_line_count; ++n) {
        /* Count half he number of filler lines to be "below this
         * line" and half to be "above the next line". */
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
      if (n > 0 && used > curwin->w_height)
        --n;
    } else   { /* (cap->cmdchar == 'H') */
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

  cursor_correct();     /* correct for 'so' */
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
      cap->arg = TRUE;
    nv_wordcmd(cap);
    return;
  }

  cap->oap->motion_type = MCHAR;
  cap->oap->inclusive = FALSE;
  PAST_LINE = (VIsual_active && *p_sel != 'o');

  /*
   * In virtual mode, there's no such thing as "PAST_LINE", as lines are
   * (theoretically) infinitely long.
   */
  if (virtual_active())
    PAST_LINE = 0;

  for (n = cap->count1; n > 0; --n) {
    if ((!PAST_LINE && oneright() == FAIL)
        || (PAST_LINE && *ml_get_cursor() == NUL)
        ) {
      /*
       *	  <Space> wraps to next line if 'whichwrap' has 's'.
       *	      'l' wraps to next line if 'whichwrap' has 'l'.
       * CURS_RIGHT wraps to next line if 'whichwrap' has '>'.
       */
      if (       ((cap->cmdchar == ' '
                   && vim_strchr(p_ww, 's') != NULL)
                  || (cap->cmdchar == 'l'
                      && vim_strchr(p_ww, 'l') != NULL)
                  || (cap->cmdchar == K_RIGHT
                      && vim_strchr(p_ww, '>') != NULL))
                 && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
        /* When deleting we also count the NL as a character.
         * Set cap->oap->inclusive when last char in the line is
         * included, move to next line after that */
        if (       cap->oap->op_type != OP_NOP
                   && !cap->oap->inclusive
                   && !lineempty(curwin->w_cursor.lnum))
          cap->oap->inclusive = TRUE;
        else {
          ++curwin->w_cursor.lnum;
          curwin->w_cursor.col = 0;
          curwin->w_cursor.coladd = 0;
          curwin->w_set_curswant = TRUE;
          cap->oap->inclusive = FALSE;
        }
        continue;
      }
      if (cap->oap->op_type == OP_NOP) {
        /* Only beep and flush if not moved at all */
        if (n == cap->count1)
          beep_flush();
      } else   {
        if (!lineempty(curwin->w_cursor.lnum))
          cap->oap->inclusive = TRUE;
      }
      break;
    } else if (PAST_LINE)   {
      curwin->w_set_curswant = TRUE;
      if (virtual_active())
        oneright();
      else {
        if (has_mbyte)
          curwin->w_cursor.col +=
            (*mb_ptr2len)(ml_get_cursor());
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
 * Returns TRUE when operator end should not be adjusted.
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

  cap->oap->motion_type = MCHAR;
  cap->oap->inclusive = FALSE;
  for (n = cap->count1; n > 0; --n) {
    if (oneleft() == FAIL) {
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
        curwin->w_set_curswant = TRUE;

        /* When the NL before the first char has to be deleted we
         * put the cursor on the NUL after the previous line.
         * This is a very special case, be careful!
         * Don't adjust op_end now, otherwise it won't work. */
        if (       (cap->oap->op_type == OP_DELETE
                    || cap->oap->op_type == OP_CHANGE)
                   && !lineempty(curwin->w_cursor.lnum)) {
          if (*ml_get_cursor() != NUL)
            ++curwin->w_cursor.col;
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
 * cap->arg is TRUE for "-": Move cursor to first non-blank.
 */
static void nv_up(cmdarg_T *cap)
{
  if (mod_mask & MOD_MASK_SHIFT) {
    /* <S-Up> is page up */
    cap->arg = BACKWARD;
    nv_page(cap);
  } else   {
    cap->oap->motion_type = MLINE;
    if (cursor_up(cap->count1, cap->oap->op_type == OP_NOP) == FAIL)
      clearopbeep(cap->oap);
    else if (cap->arg)
      beginline(BL_WHITE | BL_FIX);
  }
}

/*
 * Cursor down commands.
 * cap->arg is TRUE for CR and "+": Move cursor to first non-blank.
 */
static void nv_down(cmdarg_T *cap)
{
  if (mod_mask & MOD_MASK_SHIFT) {
    /* <S-Down> is page down */
    cap->arg = FORWARD;
    nv_page(cap);
  } else
  /* In a quickfix window a <CR> jumps to the error under the cursor. */
  if (bt_quickfix(curbuf) && cap->cmdchar == CAR)
    if (curwin->w_llist_ref == NULL)
      do_cmdline_cmd((char_u *)".cc");          /* quickfix window */
    else
      do_cmdline_cmd((char_u *)".ll");          /* location list window */
  else {
    /* In the cmdline window a <CR> executes the command. */
    if (cmdwin_type != 0 && cap->cmdchar == CAR)
      cmdwin_result = CAR;
    else {
      cap->oap->motion_type = MLINE;
      if (cursor_down(cap->count1, cap->oap->op_type == OP_NOP) == FAIL)
        clearopbeep(cap->oap);
      else if (cap->arg)
        beginline(BL_WHITE | BL_FIX);
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
    /* do autowrite if necessary */
    if (curbufIsChanged() && curbuf->b_nwindows <= 1 && !P_HID(curbuf))
      autowrite(curbuf, FALSE);
    setpcmark();
    (void)do_ecmd(0, ptr, NULL, NULL, ECMD_LAST,
        P_HID(curbuf) ? ECMD_HIDE : 0, curwin);
    if (cap->nchar == 'F' && lnum >= 0) {
      curwin->w_cursor.lnum = lnum;
      check_cursor_lnum();
      beginline(BL_SOL | BL_FIX);
    }
    vim_free(ptr);
  } else
    clearop(cap->oap);
}

/*
 * <End> command: to end of current line or last line.
 */
static void nv_end(cmdarg_T *cap)
{
  if (cap->arg || (mod_mask & MOD_MASK_CTRL)) { /* CTRL-END = goto last line */
    cap->arg = TRUE;
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
  cap->oap->motion_type = MCHAR;
  cap->oap->inclusive = TRUE;
  /* In virtual mode when off the edge of a line and an operator
   * is pending (whew!) keep the cursor where it is.
   * Otherwise, send it to the end of the line. */
  if (!virtual_active() || gchar_cursor() != NUL
      || cap->oap->op_type == OP_NOP)
    curwin->w_curswant = MAXCOL;        /* so we stay at the end */
  if (cursor_down((long)(cap->count1 - 1),
          cap->oap->op_type == OP_NOP) == FAIL)
    clearopbeep(cap->oap);
  else if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP)
    foldOpenCursor();
}

/*
 * Implementation of '?' and '/' commands.
 * If cap->arg is TRUE don't set PC mark.
 */
static void nv_search(cmdarg_T *cap)
{
  oparg_T     *oap = cap->oap;

  if (cap->cmdchar == '?' && cap->oap->op_type == OP_ROT13) {
    /* Translate "g??" to "g?g?" */
    cap->cmdchar = 'g';
    cap->nchar = '?';
    nv_operator(cap);
    return;
  }

  cap->searchbuf = getcmdline(cap->cmdchar, cap->count1, 0);

  if (cap->searchbuf == NULL) {
    clearop(oap);
    return;
  }

  normal_search(cap, cap->cmdchar, cap->searchbuf,
      (cap->arg ? 0 : SEARCH_MARK));
}

/*
 * Handle "N" and "n" commands.
 * cap->arg is SEARCH_REV for "N", 0 for "n".
 */
static void nv_next(cmdarg_T *cap)
{
  normal_search(cap, 0, NULL, SEARCH_MARK | cap->arg);
}

/*
 * Search for "pat" in direction "dir" ('/' or '?', 0 for repeat).
 * Uses only cap->count1 and cap->oap from "cap".
 */
static void 
normal_search (
    cmdarg_T *cap,
    int dir,
    char_u *pat,
    int opt                        /* extra flags for do_search() */
)
{
  int i;

  cap->oap->motion_type = MCHAR;
  cap->oap->inclusive = FALSE;
  cap->oap->use_reg_one = TRUE;
  curwin->w_set_curswant = TRUE;

  i = do_search(cap->oap, dir, pat, cap->count1,
      opt | SEARCH_OPT | SEARCH_ECHO | SEARCH_MSG, NULL);
  if (i == 0)
    clearop(cap->oap);
  else {
    if (i == 2)
      cap->oap->motion_type = MLINE;
    curwin->w_cursor.coladd = 0;
    if (cap->oap->op_type == OP_NOP && (fdo_flags & FDO_SEARCH) && KeyTyped)
      foldOpenCursor();
  }

  /* "/$" will put the cursor after the end of the line, may need to
   * correct that here */
  check_cursor();
}

/*
 * Character search commands.
 * cap->arg is BACKWARD for 'F' and 'T', FORWARD for 'f' and 't', TRUE for
 * ',' and FALSE for ';'.
 * cap->nchar is NUL for ',' and ';' (repeat the search)
 */
static void nv_csearch(cmdarg_T *cap)
{
  int t_cmd;

  if (cap->cmdchar == 't' || cap->cmdchar == 'T')
    t_cmd = TRUE;
  else
    t_cmd = FALSE;

  cap->oap->motion_type = MCHAR;
  if (IS_SPECIAL(cap->nchar) || searchc(cap, t_cmd) == FAIL)
    clearopbeep(cap->oap);
  else {
    curwin->w_set_curswant = TRUE;
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

  cap->oap->motion_type = MCHAR;
  cap->oap->inclusive = FALSE;
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
    int len;

    if ((len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0)
      clearop(cap->oap);
    else {
      find_pattern_in_path(ptr, 0, len, TRUE,
          cap->count0 == 0 ? !isupper(cap->nchar) : FALSE,
          ((cap->nchar & 0xf) == ('d' & 0xf)) ?  FIND_DEFINE : FIND_ANY,
          cap->count1,
          isupper(cap->nchar) ? ACTION_SHOW_ALL :
          islower(cap->nchar) ? ACTION_SHOW : ACTION_GOTO,
          cap->cmdchar == ']' ? curwin->w_cursor.lnum + 1 : (linenr_T)1,
          (linenr_T)MAXLNUM);
      curwin->w_set_curswant = TRUE;
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
    } else   {
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
      /* norm is TRUE for "]M" and "[m" */
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
      curwin->w_set_curswant = TRUE;
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

    curwin->w_set_curswant = TRUE;
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
      prep_redo_cmd(cap);
      do_put(cap->oap->regname,
          (cap->cmdchar == ']' && cap->nchar == 'p') ? FORWARD : BACKWARD,
          cap->count1, PUT_FIXINDENT);
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
    if (foldMoveTo(FALSE, cap->cmdchar == ']' ? FORWARD : BACKWARD,
            cap->count1) == FAIL)
      clearopbeep(cap->oap);
  }
  /*
   * "[c" and "]c": move to next or previous diff-change.
   */
  else if (cap->nchar == 'c') {
    if (diff_move_to(cap->cmdchar == ']' ? FORWARD : BACKWARD,
            cap->count1) == FAIL)
      clearopbeep(cap->oap);
  }
  /*
   * "[s", "[S", "]s" and "]S": move to next spell error.
   */
  else if (cap->nchar == 's' || cap->nchar == 'S') {
    setpcmark();
    for (n = 0; n < cap->count1; ++n)
      if (spell_move_to(curwin, cap->cmdchar == ']' ? FORWARD : BACKWARD,
              cap->nchar == 's' ? TRUE : FALSE, FALSE, NULL) == 0) {
        clearopbeep(cap->oap);
        break;
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

  cap->oap->inclusive = TRUE;
  if (cap->count0) {        /* {cnt}% : goto {cnt} percentage in file */
    if (cap->count0 > 100)
      clearopbeep(cap->oap);
    else {
      cap->oap->motion_type = MLINE;
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
  } else   {                /* "%" : go to matching paren */
    cap->oap->motion_type = MCHAR;
    cap->oap->use_reg_one = TRUE;
    if ((pos = findmatch(cap->oap, NUL)) == NULL)
      clearopbeep(cap->oap);
    else {
      setpcmark();
      curwin->w_cursor = *pos;
      curwin->w_set_curswant = TRUE;
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
  cap->oap->motion_type = MCHAR;
  cap->oap->use_reg_one = TRUE;
  /* The motion used to be inclusive for "(", but that is not what Vi does. */
  cap->oap->inclusive = FALSE;
  curwin->w_set_curswant = TRUE;

  if (findsent(cap->arg, cap->count1) == FAIL)
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
    if (setmark(cap->nchar) == FAIL)
      clearopbeep(cap->oap);
  }
}

/*
 * "{" and "}" commands.
 * cmd->arg is BACKWARD for "{" and FORWARD for "}".
 */
static void nv_findpar(cmdarg_T *cap)
{
  cap->oap->motion_type = MCHAR;
  cap->oap->inclusive = FALSE;
  cap->oap->use_reg_one = TRUE;
  curwin->w_set_curswant = TRUE;
  if (!findpar(&cap->oap->inclusive, cap->arg, cap->count1, NUL, FALSE))
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
    curwin->w_set_curswant = TRUE;
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
      if (cap->nchar == '\r')
        cap->nchar = -1;
      else if (cap->nchar == '\n')
        cap->nchar = -2;
    }
    nv_operator(cap);
    return;
  }

  /* Break tabs, etc. */
  if (virtual_active()) {
    if (u_save_cursor() == FAIL)
      return;
    if (gchar_cursor() == NUL) {
      /* Add extra space and put the cursor on the first one. */
      coladvance_force((colnr_T)(getviscol() + cap->count1));
      curwin->w_cursor.col -= cap->count1;
    } else if (gchar_cursor() == TAB)
      coladvance_force(getviscol());
  }

  /* Abort if not enough characters to replace. */
  ptr = ml_get_cursor();
  if (STRLEN(ptr) < (unsigned)cap->count1
      || (has_mbyte && mb_charlen(ptr) < cap->count1)
      ) {
    clearopbeep(cap->oap);
    return;
  }

  /*
   * Replacing with a TAB is done by edit() when it is complicated because
   * 'expandtab' or 'smarttab' is set.  CTRL-V TAB inserts a literal TAB.
   * Other characters are done below to avoid problems with things like
   * CTRL-V 048 (for edit() this would be R CTRL-V 0 ESC).
   */
  if (had_ctrl_v != Ctrl_V && cap->nchar == '\t' &&
      (curbuf->b_p_et || p_sta)) {
    stuffnumReadbuff(cap->count1);
    stuffcharReadbuff('R');
    stuffcharReadbuff('\t');
    stuffcharReadbuff(ESC);
    return;
  }

  /* save line for undo */
  if (u_save_cursor() == FAIL)
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
    (void)del_chars(cap->count1, FALSE);        /* delete the characters */
    stuffcharReadbuff('\r');
    stuffcharReadbuff(ESC);

    /* Give 'r' to edit(), to get the redo command right. */
    invoke_edit(cap, TRUE, 'r', FALSE);
  } else   {
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
    } else   {
      /*
       * Replace the characters within one line.
       */
      for (n = cap->count1; n > 0; --n) {
        /*
         * Get ptr again, because u_save and/or showmatch() will have
         * released the line.  At the same time we let know that the
         * line will be changed.
         */
        ptr = ml_get_buf(curbuf, curwin->w_cursor.lnum, TRUE);
        if (cap->nchar == Ctrl_E || cap->nchar == Ctrl_Y) {
          int c = ins_copychar(curwin->w_cursor.lnum
              + (cap->nchar == Ctrl_Y ? -1 : 1));
          if (c != NUL)
            ptr[curwin->w_cursor.col] = c;
        } else
          ptr[curwin->w_cursor.col] = cap->nchar;
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
    curwin->w_set_curswant = TRUE;
    set_last_insert(cap->nchar);
  }
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
  } else   {
    old_cursor = curwin->w_cursor;
    curwin->w_cursor = VIsual;
    VIsual = old_cursor;
    curwin->w_set_curswant = TRUE;
  }
}

/*
 * "R" (cap->arg is FALSE) and "gR" (cap->arg is TRUE).
 */
static void nv_Replace(cmdarg_T *cap)
{
  if (VIsual_active) {          /* "R" is replace lines */
    cap->cmdchar = 'c';
    cap->nchar = NUL;
    VIsual_mode_orig = VIsual_mode;     /* remember original area for gv */
    VIsual_mode = 'V';
    nv_operator(cap);
  } else if (!checkclearopq(cap->oap))    {
    if (!curbuf->b_p_ma)
      EMSG(_(e_modifiable));
    else {
      if (virtual_active())
        coladvance(getviscol());
      invoke_edit(cap, FALSE, cap->arg ? 'V' : 'R', FALSE);
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
  } else if (!checkclearopq(cap->oap))    {
    if (!curbuf->b_p_ma)
      EMSG(_(e_modifiable));
    else {
      if (cap->extra_char == Ctrl_V)            /* get another character */
        cap->extra_char = get_literal();
      stuffcharReadbuff(cap->extra_char);
      stuffcharReadbuff(ESC);
      if (virtual_active())
        coladvance(getviscol());
      invoke_edit(cap, TRUE, 'v', FALSE);
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

  if (checkclearopq(cap->oap))
    return;

  if (lineempty(curwin->w_cursor.lnum) && vim_strchr(p_ww, '~') == NULL) {
    clearopbeep(cap->oap);
    return;
  }

  prep_redo_cmd(cap);

  if (u_save_cursor() == FAIL)
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
          if (u_savesub(curwin->w_cursor.lnum) == FAIL)
            break;
          u_clearline();
        }
      } else
        break;
    }
  }


  check_cursor();
  curwin->w_set_curswant = TRUE;
  if (did_change) {
    changed_lines(startpos.lnum, startpos.col, curwin->w_cursor.lnum + 1,
        0L);
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
  if (check_mark(pos) == FAIL)
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
  cap->oap->motion_type = flag ? MLINE : MCHAR;
  if (cap->cmdchar == '`')
    cap->oap->use_reg_one = TRUE;
  cap->oap->inclusive = FALSE;                  /* ignored if not MCHAR */
  curwin->w_set_curswant = TRUE;
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
  static char_u *(ar[8]) = {(char_u *)"dl", (char_u *)"dh",
                            (char_u *)"d$", (char_u *)"c$",
                            (char_u *)"cl", (char_u *)"cc",
                            (char_u *)"yy", (char_u *)":s\r"};
  static char_u *str = (char_u *)"xXDCsSY&";

  if (!checkclearopq(cap->oap)) {
    /* In Vi "2D" doesn't delete the next line.  Can't translate it
     * either, because "2." should also not use the count. */
    if (cap->cmdchar == 'D' && vim_strchr(p_cpo, CPO_HASH) != NULL) {
      cap->oap->start = curwin->w_cursor;
      cap->oap->op_type = OP_DELETE;
      set_op_var(OP_DELETE);
      cap->count1 = 1;
      nv_dollar(cap);
      finish_op = TRUE;
      ResetRedobuff();
      AppendCharToRedobuff('D');
    } else   {
      if (cap->count0)
        stuffnumReadbuff(cap->count0);
      stuffReadbuff(ar[(int)(vim_strchr(str, cap->cmdchar) - str)]);
    }
  }
  cap->opcount = 0;
}

/*
 * "'" and "`" commands.  Also for "g'" and "g`".
 * cap->arg is TRUE for "'" and "g'".
 */
static void nv_gomark(cmdarg_T *cap)
{
  pos_T       *pos;
  int c;
  pos_T old_cursor = curwin->w_cursor;
  int old_KeyTyped = KeyTyped;              /* getting file may reset it */

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

  /* May need to clear the coladd that a mark includes. */
  if (!virtual_active())
    curwin->w_cursor.coladd = 0;
  if (cap->oap->op_type == OP_NOP
      && pos != NULL
      && (pos == (pos_T *)-1 || !equalpos(old_cursor, *pos))
      && (fdo_flags & FDO_MARK)
      && old_KeyTyped)
    foldOpenCursor();
}

/*
 * Handle CTRL-O, CTRL-I, "g;" and "g," commands.
 */
static void nv_pcmark(cmdarg_T *cap)
{
  pos_T       *pos;
  linenr_T lnum = curwin->w_cursor.lnum;
  int old_KeyTyped = KeyTyped;              /* getting file may reset it */

  if (!checkclearopq(cap->oap)) {
    if (cap->cmdchar == 'g')
      pos = movechangelist((int)cap->count1);
    else
      pos = movemark((int)cap->count1);
    if (pos == (pos_T *)-1) {           /* jump to other file */
      curwin->w_set_curswant = TRUE;
      check_cursor();
    } else if (pos != NULL)                 /* can jump */
      nv_cursormark(cap, FALSE, pos);
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
  if (cap->nchar != NUL && valid_yank_reg(cap->nchar, FALSE)) {
    cap->oap->regname = cap->nchar;
    cap->opcount = cap->count0;         /* remember count before '"' */
    set_reg_var(cap->oap->regname);
  } else
    clearopbeep(cap->oap);
}

/*
 * Handle "v", "V" and "CTRL-V" commands.
 * Also for "gh", "gH" and "g^H" commands: Always start Select mode, cap->arg
 * is TRUE.
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
    finish_op = FALSE;          /* operator doesn't finish now but later */
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
    redraw_curbuf_later(INVERTED);          /* update the inversion */
  } else   {                /* start Visual mode */
    check_visual_highlight();
    if (cap->count0 > 0 && resel_VIsual_mode != NUL) {
      /* use previously selected part */
      VIsual = curwin->w_cursor;

      VIsual_active = TRUE;
      VIsual_reselect = TRUE;
      if (!cap->arg)
        /* start Select mode when 'selectmode' contains "cmd" */
        may_start_select('c');
      setmouse();
      if (p_smd && msg_silent == 0)
        redraw_cmdline = TRUE;              /* show visual mode later */
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
          curwin->w_curswant = curwin->w_virtcol
                               + resel_VIsual_vcol * cap->count0 - 1;
        } else
          curwin->w_curswant = resel_VIsual_vcol;
        coladvance(curwin->w_curswant);
      }
      if (resel_VIsual_vcol == MAXCOL) {
        curwin->w_curswant = MAXCOL;
        coladvance((colnr_T)MAXCOL);
      } else if (VIsual_mode == Ctrl_V)   {
        validate_virtcol();
        curwin->w_curswant = curwin->w_virtcol
                             + resel_VIsual_vcol * cap->count0 - 1;
        coladvance(curwin->w_curswant);
      } else
        curwin->w_set_curswant = TRUE;
      redraw_curbuf_later(INVERTED);            /* show the inversion */
    } else   {
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
void start_selection(void)          {
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
  /* Check for redraw before changing the state. */
  conceal_check_cursur_line();

  VIsual_mode = c;
  VIsual_active = TRUE;
  VIsual_reselect = TRUE;
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
  /* Check for redraw after changing the state. */
  conceal_check_cursur_line();

  if (p_smd && msg_silent == 0)
    redraw_cmdline = TRUE;      /* show visual mode later */

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
  do_cmdline_cmd((char_u *)"st");
}

/*
 * Commands starting with "g".
 */
static void nv_g_cmd(cmdarg_T *cap)
{
  oparg_T     *oap = cap->oap;
  pos_T tpos;
  int i;
  int flag = FALSE;

  switch (cap->nchar) {
#ifdef MEM_PROFILE
  /*
   * "g^A": dump log of used memory.
   */
  case Ctrl_A:
    vim_mem_profile_dump();
    break;
#endif

  /*
   * "gR": Enter virtual replace mode.
   */
  case 'R':
    cap->arg = TRUE;
    nv_Replace(cap);
    break;

  case 'r':
    nv_vreplace(cap);
    break;

  case '&':
    do_cmdline_cmd((char_u *)"%s//~/&");
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
      } else   {
        VIsual_mode = curbuf->b_visual.vi_mode;
        curwin->w_curswant = curbuf->b_visual.vi_curswant;
        tpos = curbuf->b_visual.vi_end;
        curwin->w_cursor = curbuf->b_visual.vi_start;
      }

      VIsual_active = TRUE;
      VIsual_reselect = TRUE;

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
        VIsual_select = TRUE;
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
    VIsual_reselect = FALSE;
    break;

  /*
   * "gh":  start Select mode.
   * "gH":  start Select line mode.
   * "g^H": start Select block mode.
   */
  case K_BS:
    cap->nchar = Ctrl_H;
  /* FALLTHROUGH */
  case 'h':
  case 'H':
  case Ctrl_H:
    cap->cmdchar = cap->nchar + ('v' - 'h');
    cap->arg = TRUE;
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
      oap->motion_type = MLINE;
      i = cursor_down(cap->count1, oap->op_type == OP_NOP);
    } else
      i = nv_screengo(oap, FORWARD, cap->count1);
    if (i == FAIL)
      clearopbeep(oap);
    break;

  case 'k':
  case K_UP:
    /* with 'nowrap' it works just like the normal "k" command; also when
     * in a closed fold */
    if (!curwin->w_p_wrap
        || hasFolding(curwin->w_cursor.lnum, NULL, NULL)
        ) {
      oap->motion_type = MLINE;
      i = cursor_up(cap->count1, oap->op_type == OP_NOP);
    } else
      i = nv_screengo(oap, BACKWARD, cap->count1);
    if (i == FAIL)
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
    flag = TRUE;
  /* FALLTHROUGH */

  case '0':
  case 'm':
  case K_HOME:
  case K_KHOME:
    oap->motion_type = MCHAR;
    oap->inclusive = FALSE;
    if (curwin->w_p_wrap
        && curwin->w_width != 0
        ) {
      int width1 = W_WIDTH(curwin) - curwin_col_off();
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
    if (cap->nchar == 'm')
      i += (W_WIDTH(curwin) - curwin_col_off()
            + ((curwin->w_p_wrap && i > 0)
               ? curwin_col_off2() : 0)) / 2;
    coladvance((colnr_T)i);
    if (flag) {
      do
        i = gchar_cursor();
      while (vim_iswhite(i) && oneright() == OK);
    }
    curwin->w_set_curswant = TRUE;
    break;

  case '_':
    /* "g_": to the last non-blank character in the line or <count> lines
     * downward. */
    cap->oap->motion_type = MCHAR;
    cap->oap->inclusive = TRUE;
    curwin->w_curswant = MAXCOL;
    if (cursor_down((long)(cap->count1 - 1),
            cap->oap->op_type == OP_NOP) == FAIL)
      clearopbeep(cap->oap);
    else {
      char_u  *ptr = ml_get_curline();

      /* In Visual mode we may end up after the line. */
      if (curwin->w_cursor.col > 0 && ptr[curwin->w_cursor.col] == NUL)
        --curwin->w_cursor.col;

      /* Decrease the cursor column until it's on a non-blank. */
      while (curwin->w_cursor.col > 0
             && vim_iswhite(ptr[curwin->w_cursor.col]))
        --curwin->w_cursor.col;
      curwin->w_set_curswant = TRUE;
      adjust_for_sel(cap);
    }
    break;

  case '$':
  case K_END:
  case K_KEND:
  {
    int col_off = curwin_col_off();

    oap->motion_type = MCHAR;
    oap->inclusive = TRUE;
    if (curwin->w_p_wrap
        && curwin->w_width != 0
        ) {
      curwin->w_curswant = MAXCOL;              /* so we stay at the end */
      if (cap->count1 == 1) {
        int width1 = W_WIDTH(curwin) - col_off;
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
        curwin->w_set_curswant = FALSE;
        if (curwin->w_cursor.col > 0 && curwin->w_p_wrap) {
          /*
           * Check for landing on a character that got split at
           * the end of the line.  We do not want to advance to
           * the next screen line.
           */
          if (curwin->w_virtcol > (colnr_T)i)
            --curwin->w_cursor.col;
        }
      } else if (nv_screengo(oap, FORWARD, cap->count1 - 1) == FAIL)
        clearopbeep(oap);
    } else   {
      i = curwin->w_leftcol + W_WIDTH(curwin) - col_off - 1;
      coladvance((colnr_T)i);

      /* Make sure we stick in this column. */
      validate_virtcol();
      curwin->w_curswant = curwin->w_virtcol;
      curwin->w_set_curswant = FALSE;
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
    oap->motion_type = MCHAR;
    curwin->w_set_curswant = TRUE;
    oap->inclusive = TRUE;
    if (bckend_word(cap->count1, cap->nchar == 'E', FALSE) == FAIL)
      clearopbeep(oap);
    break;

  /*
   * "g CTRL-G": display info about cursor position
   */
  case Ctrl_G:
    cursor_pos_info();
    break;

  /*
   * "gi": start Insert at the last position.
   */
  case 'i':
    if (curbuf->b_last_insert.lnum != 0) {
      curwin->w_cursor = curbuf->b_last_insert;
      check_cursor_lnum();
      i = (int)STRLEN(ml_get_curline());
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
      invoke_edit(cap, FALSE, 'g', FALSE);
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
    cap->arg = TRUE;
  /*FALLTHROUGH*/
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

  case '<':
    show_sb_text();
    break;

  /*
   * "gg": Goto the first line in file.  With a count it goes to
   * that line number like for "G". -- webb
   */
  case 'g':
    cap->arg = FALSE;
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
  /*FALLTHROUGH*/
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
      do_exmode(TRUE);
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
          FALSE, FALSE, FALSE);
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
            ) == OK
        && open_line(cap->cmdchar == 'O' ? BACKWARD : FORWARD,
            has_format_option(FO_OPEN_COMS) ? OPENLINE_DO_COM :
            0, 0)) {
      if (curwin->w_p_cole > 0 && oldline != curwin->w_cursor.lnum)
        update_single_line(curwin, oldline);
      /* When '#' is in 'cpoptions' ignore the count. */
      if (vim_strchr(p_cpo, CPO_HASH) != NULL)
        cap->count1 = 1;
      invoke_edit(cap, FALSE, cap->cmdchar, TRUE);
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
     * If "restart_edit" is TRUE, the last but one command is repeated
     * instead of the last command (inserting text). This is used for
     * CTRL-O <.> in insert mode.
     */
    if (start_redo(cap->count0, restart_edit != 0 && !arrow_used) == FAIL)
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
    curwin->w_set_curswant = TRUE;
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
  } else if (!checkclearopq(cap->oap))   {
    u_undoline();
    curwin->w_set_curswant = TRUE;
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
  char_u opchars[3];

  if (optype == OP_NOP)
    set_vim_var_string(VV_OP, NULL, 0);
  else {
    opchars[0] = get_op_char(optype);
    opchars[1] = get_extra_op_char(optype);
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
  cap->oap->motion_type = MLINE;
  if (cursor_down(cap->count1 - 1L, cap->oap->op_type == OP_NOP) == FAIL)
    clearopbeep(cap->oap);
  else if (  (cap->oap->op_type == OP_DELETE   /* only with linewise motions */
              && cap->oap->motion_force != 'v'
              && cap->oap->motion_force != Ctrl_V)
             || cap->oap->op_type == OP_LSHIFT
             || cap->oap->op_type == OP_RSHIFT)
    beginline(BL_SOL | BL_FIX);
  else if (cap->oap->op_type != OP_YANK)        /* 'Y' does not move cursor */
    beginline(BL_WHITE | BL_FIX);
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
  ins_at_eol = FALSE;       /* Don't move cursor past eol (only necessary in a
                               one-character line). */
}

/*
 * "|" command.
 */
static void nv_pipe(cmdarg_T *cap)
{
  cap->oap->motion_type = MCHAR;
  cap->oap->inclusive = FALSE;
  beginline(0);
  if (cap->count0 > 0) {
    coladvance((colnr_T)(cap->count0 - 1));
    curwin->w_curswant = (colnr_T)(cap->count0 - 1);
  } else
    curwin->w_curswant = 0;
  /* keep curswant at the column where we wanted to go, not where
   * we ended; differs if line is too short */
  curwin->w_set_curswant = FALSE;
}

/*
 * Handle back-word command "b" and "B".
 * cap->arg is 1 for "B"
 */
static void nv_bck_word(cmdarg_T *cap)
{
  cap->oap->motion_type = MCHAR;
  cap->oap->inclusive = FALSE;
  curwin->w_set_curswant = TRUE;
  if (bck_word(cap->count1, cap->arg, FALSE) == FAIL)
    clearopbeep(cap->oap);
  else if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP)
    foldOpenCursor();
}

/*
 * Handle word motion commands "e", "E", "w" and "W".
 * cap->arg is TRUE for "E" and "W".
 */
static void nv_wordcmd(cmdarg_T *cap)
{
  int n;
  int word_end;
  int flag = FALSE;
  pos_T startpos = curwin->w_cursor;

  /*
   * Set inclusive for the "E" and "e" command.
   */
  if (cap->cmdchar == 'e' || cap->cmdchar == 'E')
    word_end = TRUE;
  else
    word_end = FALSE;
  cap->oap->inclusive = word_end;

  /*
   * "cw" and "cW" are a special case.
   */
  if (!word_end && cap->oap->op_type == OP_CHANGE) {
    n = gchar_cursor();
    if (n != NUL) {                     /* not an empty line */
      if (vim_iswhite(n)) {
        /*
         * Reproduce a funny Vi behaviour: "cw" on a blank only
         * changes one character, not all blanks until the start of
         * the next word.  Only do this when the 'w' flag is included
         * in 'cpoptions'.
         */
        if (cap->count1 == 1 && vim_strchr(p_cpo, CPO_CW) != NULL) {
          cap->oap->inclusive = TRUE;
          cap->oap->motion_type = MCHAR;
          return;
        }
      } else   {
        /*
         * This is a little strange. To match what the real Vi does,
         * we effectively map 'cw' to 'ce', and 'cW' to 'cE', provided
         * that we are not on a space or a TAB.  This seems impolite
         * at first, but it's really more what we mean when we say
         * 'cw'.
         * Another strangeness: When standing on the end of a word
         * "ce" will change until the end of the next word, but "cw"
         * will change only one character! This is done by setting
         * flag.
         */
        cap->oap->inclusive = TRUE;
        word_end = TRUE;
        flag = TRUE;
      }
    }
  }

  cap->oap->motion_type = MCHAR;
  curwin->w_set_curswant = TRUE;
  if (word_end)
    n = end_word(cap->count1, cap->arg, flag, FALSE);
  else
    n = fwd_word(cap->count1, cap->arg, cap->oap->op_type != OP_NOP);

  /* Don't leave the cursor on the NUL past the end of line. Unless we
   * didn't move it forward. */
  if (lt(startpos, curwin->w_cursor))
    adjust_cursor(cap->oap);

  if (n == FAIL && cap->oap->op_type == OP_NOP)
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
    oap->inclusive = TRUE;
  }
}

/*
 * "0" and "^" commands.
 * cap->arg is the argument for beginline().
 */
static void nv_beginline(cmdarg_T *cap)
{
  cap->oap->motion_type = MCHAR;
  cap->oap->inclusive = FALSE;
  beginline(cap->arg);
  if ((fdo_flags & FDO_HOR) && KeyTyped && cap->oap->op_type == OP_NOP)
    foldOpenCursor();
  ins_at_eol = FALSE;       /* Don't move cursor past eol (only necessary in a
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
    cap->oap->inclusive = FALSE;
  }
}

/*
 * Exclude last character at end of Visual area for 'selection' == "exclusive".
 * Should check VIsual_mode before calling this.
 * Returns TRUE when backed up to the previous line.
 */
static int unadjust_for_sel(void)                {
  pos_T       *pp;

  if (*p_sel == 'e' && !equalpos(VIsual, curwin->w_cursor)) {
    if (lt(VIsual, curwin->w_cursor))
      pp = &curwin->w_cursor;
    else
      pp = &VIsual;
    if (pp->coladd > 0)
      --pp->coladd;
    else if (pp->col > 0)      {
      --pp->col;
      mb_adjustpos(curbuf, pp);
    } else if (pp->lnum > 1)   {
      --pp->lnum;
      pp->col = (colnr_T)STRLEN(ml_get(pp->lnum));
      return TRUE;
    }
  }
  return FALSE;
}

/*
 * SELECT key in Normal or Visual mode: end of Select mode mapping.
 */
static void nv_select(cmdarg_T *cap)
{
  if (VIsual_active)
    VIsual_select = TRUE;
  else if (VIsual_reselect) {
    cap->nchar = 'v';               /* fake "gv" command */
    cap->arg = TRUE;
    nv_g_cmd(cap);
  }
}


/*
 * "G", "gg", CTRL-END, CTRL-HOME.
 * cap->arg is TRUE for "G".
 */
static void nv_goto(cmdarg_T *cap)
{
  linenr_T lnum;

  if (cap->arg)
    lnum = curbuf->b_ml.ml_line_count;
  else
    lnum = 1L;
  cap->oap->motion_type = MLINE;
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
      clear_cmdline = TRUE;                     /* unshow mode later */
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

  if (cap->arg) {               /* TRUE for CTRL-C */
    if (restart_edit == 0
        && cmdwin_type == 0
        && !VIsual_active
        && no_reason)
      MSG(_("Type  :quit<Enter>  to exit Vim"));

    /* Don't reset "restart_edit" when 'insertmode' is set, it won't be
     * set again below when halfway a mapping. */
    if (!p_im)
      restart_edit = 0;
    if (cmdwin_type != 0) {
      cmdwin_result = K_IGNORE;
      got_int = FALSE;          /* don't stop executing autocommands et al. */
      return;
    }
  }

  if (VIsual_active) {
    end_visual_mode();          /* stop Visual */
    check_cursor_col();         /* make sure cursor is not beyond EOL */
    curwin->w_set_curswant = TRUE;
    redraw_curbuf_later(INVERTED);
  } else if (no_reason)
    vim_beep();
  clearop(cap->oap);

  /* A CTRL-C is often used at the start of a menu.  When 'insertmode' is
   * set return to Insert mode afterwards. */
  if (restart_edit == 0 && goto_im()
      && ex_normal_busy == 0
      )
    restart_edit = 'a';
}

/*
 * Handle "A", "a", "I", "i" and <Insert> commands.
 */
static void nv_edit(cmdarg_T *cap)
{
  /* <Insert> is equal to "i" */
  if (cap->cmdchar == K_INS || cap->cmdchar == K_KINS)
    cap->cmdchar = 'i';

  /* in Visual mode "A" and "I" are an operator */
  if (VIsual_active && (cap->cmdchar == 'A' || cap->cmdchar == 'I'))
    v_visop(cap);

  /* in Visual mode and after an operator "a" and "i" are for text objects */
  else if ((cap->cmdchar == 'a' || cap->cmdchar == 'i')
           && (cap->oap->op_type != OP_NOP
               || VIsual_active
               )) {
    nv_object(cap);
  } else if (!curbuf->b_p_ma && !p_im)   {
    /* Only give this error when 'insertmode' is off. */
    EMSG(_(e_modifiable));
    clearop(cap->oap);
  } else if (!checkclearopq(cap->oap))   {
    switch (cap->cmdchar) {
    case 'A':           /* "A"ppend after the line */
      curwin->w_set_curswant = TRUE;
      if (ve_flags == VE_ALL) {
        int save_State = State;

        /* Pretend Insert mode here to allow the cursor on the
         * character past the end of the line */
        State = INSERT;
        coladvance((colnr_T)MAXCOL);
        State = save_State;
      } else
        curwin->w_cursor.col += (colnr_T)STRLEN(ml_get_cursor());
      break;

    case 'I':           /* "I"nsert before the first non-blank */
      if (vim_strchr(p_cpo, CPO_INSEND) == NULL)
        beginline(BL_WHITE);
      else
        beginline(BL_WHITE|BL_FIX);
      break;

    case 'a':           /* "a"ppend is like "i"nsert on the next character. */
      /* increment coladd when in virtual space, increment the
       * column otherwise, also to append after an unprintable char */
      if (virtual_active()
          && (curwin->w_cursor.coladd > 0
              || *ml_get_cursor() == NUL
              || *ml_get_cursor() == TAB))
        curwin->w_cursor.coladd++;
      else if (*ml_get_cursor() != NUL)
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

    invoke_edit(cap, FALSE, cap->cmdchar, FALSE);
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
  int flag;
  int include;
  char_u      *mps_save;

  if (cap->cmdchar == 'i')
    include = FALSE;        /* "ix" = inner object: exclude white space */
  else
    include = TRUE;         /* "ax" = an object: include white space */

  /* Make sure (), [], {} and <> are in 'matchpairs' */
  mps_save = curbuf->b_p_mps;
  curbuf->b_p_mps = (char_u *)"(:),{:},[:],<:>";

  switch (cap->nchar) {
  case 'w':       /* "aw" = a word */
    flag = current_word(cap->oap, cap->count1, include, FALSE);
    break;
  case 'W':       /* "aW" = a WORD */
    flag = current_word(cap->oap, cap->count1, include, TRUE);
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
    flag = FAIL;
    break;
  }

  curbuf->b_p_mps = mps_save;
  if (flag == FAIL)
    clearopbeep(cap->oap);
  adjust_cursor_col();
  curwin->w_set_curswant = TRUE;
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
  } else if (!checkclearop(cap->oap))   {
    if (cap->nchar == ':' || cap->nchar == '/' || cap->nchar == '?') {
      stuffcharReadbuff(cap->nchar);
      stuffcharReadbuff(K_CMDWIN);
    } else
    /* (stop) recording into a named register, unless executing a
     * register */
    if (!Exec_reg && do_record(cap->nchar) == FAIL)
      clearopbeep(cap->oap);
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
    if (do_execreg(cap->nchar, FALSE, FALSE, FALSE) == FAIL) {
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
  if (VIsual_active)    /* join the visual lines */
    nv_operator(cap);
  else if (!checkclearop(cap->oap))  {
    if (cap->count0 <= 1)
      cap->count0 = 2;              /* default for join is two lines! */
    if (curwin->w_cursor.lnum + cap->count0 - 1 >
        curbuf->b_ml.ml_line_count)
      clearopbeep(cap->oap);        /* beyond last line */
    else {
      prep_redo(cap->oap->regname, cap->count0,
          NUL, cap->cmdchar, NUL, NUL, cap->nchar);
      (void)do_join(cap->count0, cap->nchar == NUL, TRUE, TRUE);
    }
  }
}

/*
 * "P", "gP", "p" and "gp" commands.
 */
static void nv_put(cmdarg_T *cap)
{
  int regname = 0;
  void        *reg1 = NULL, *reg2 = NULL;
  int empty = FALSE;
  int was_visual = FALSE;
  int dir;
  int flags = 0;

  if (cap->oap->op_type != OP_NOP) {
    /* "dp" is ":diffput" */
    if (cap->oap->op_type == OP_DELETE && cap->cmdchar == 'p') {
      clearop(cap->oap);
      nv_diffgetput(TRUE);
    } else
      clearopbeep(cap->oap);
  } else   {
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
      was_visual = TRUE;
      regname = cap->oap->regname;
      if (regname == 0 || regname == '"'
          || VIM_ISDIGIT(regname) || regname == '-'

          ) {
        /* The delete is going to overwrite the register we want to
         * put, save it first. */
        reg1 = get_register(regname, TRUE);
      }

      /* Now delete the selected text. */
      cap->cmdchar = 'd';
      cap->nchar = NUL;
      cap->oap->regname = NUL;
      nv_operator(cap);
      do_pending_operator(cap, 0, FALSE);
      empty = (curbuf->b_ml.ml_flags & ML_EMPTY);

      /* delete PUT_LINE_BACKWARD; */
      cap->oap->regname = regname;

      if (reg1 != NULL) {
        /* Delete probably changed the register we want to put, save
         * it first. Then put back what was there before the delete. */
        reg2 = get_register(regname, FALSE);
        put_register(regname, reg1);
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
      VIsual_active = TRUE;
    }
    do_put(cap->oap->regname, dir, cap->count1, flags);

    /* If a register was saved, put it back now. */
    if (reg2 != NULL)
      put_register(regname, reg2);

    /* What to reselect with "gv"?  Selecting the just put text seems to
     * be the most useful, since the original text was removed. */
    if (was_visual) {
      curbuf->b_visual.vi_start = curbuf->b_op_start;
      curbuf->b_visual.vi_end = curbuf->b_op_end;
    }

    /* When all lines were selected and deleted do_put() leaves an empty
     * line that needs to be deleted now. */
    if (empty && *ml_get(curbuf->b_ml.ml_line_count) == NUL) {
      ml_delete(curbuf->b_ml.ml_line_count, TRUE);

      /* If the cursor was in that line, move it to the end of the last
       * line. */
      if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
        curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
        coladvance((colnr_T)MAXCOL);
      }
    }
    auto_format(FALSE, TRUE);
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
    nv_diffgetput(FALSE);
  } else if (VIsual_active) /* switch start and end of visual */
    v_swap_corners(cap->cmdchar);
  else
    n_opencmd(cap);
}




/*
 * Trigger CursorHold event.
 * When waiting for a character for 'updatetime' K_CURSORHOLD is put in the
 * input buffer.  "did_cursorhold" is set to avoid retriggering.
 */
static void nv_cursorhold(cmdarg_T *cap)
{
  apply_autocmds(EVENT_CURSORHOLD, NULL, NULL, FALSE, curbuf);
  did_cursorhold = TRUE;
  cap->retval |= CA_COMMAND_BUSY;       /* don't call edit() now */
}
