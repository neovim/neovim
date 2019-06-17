// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * syntax.c: code for syntax highlighting
 */

#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/api/private/helpers.h"
#include "nvim/syntax.h"
#include "nvim/charset.h"
#include "nvim/cursor_shape.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/hashtab.h"
#include "nvim/highlight.h"
#include "nvim/indent_c.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/keymap.h"
#include "nvim/garray.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/macros.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/sign.h"
#include "nvim/strings.h"
#include "nvim/syntax_defs.h"
#include "nvim/terminal.h"
#include "nvim/ui.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/buffer.h"

static bool did_syntax_onoff = false;

/// Structure that stores information about a highlight group.
/// The ID of a highlight group is also called group ID.  It is the index in
/// the highlight_ga array PLUS ONE.
struct hl_group {
  char_u      *sg_name;         ///< highlight group name
  char_u      *sg_name_u;       ///< uppercase of sg_name
  bool sg_cleared;              ///< "hi clear" was used
  int sg_attr;                  ///< Screen attr @see ATTR_ENTRY
  int sg_link;                  ///< link to this highlight group ID
  int sg_set;                   ///< combination of flags in \ref SG_SET
  sctx_T sg_script_ctx;         ///< script in which the group was last set
  // for terminal UIs
  int sg_cterm;                 ///< "cterm=" highlighting attr
                                ///< (combination of \ref HlAttrFlags)
  int sg_cterm_fg;              ///< terminal fg color number + 1
  int sg_cterm_bg;              ///< terminal bg color number + 1
  bool sg_cterm_bold;           ///< bold attr was set for light color
  // for RGB UIs
  int sg_gui;                   ///< "gui=" highlighting attributes
                                ///< (combination of \ref HlAttrFlags)
  RgbValue sg_rgb_fg;           ///< RGB foreground color
  RgbValue sg_rgb_bg;           ///< RGB background color
  RgbValue sg_rgb_sp;           ///< RGB special color
  uint8_t *sg_rgb_fg_name;      ///< RGB foreground color name
  uint8_t *sg_rgb_bg_name;      ///< RGB background color name
  uint8_t *sg_rgb_sp_name;      ///< RGB special color name

  int sg_blend;                 ///< blend level (0-100 inclusive), -1 if unset
};

/// \addtogroup SG_SET
/// @{
#define SG_CTERM        2       // cterm has been set
#define SG_GUI          4       // gui has been set
#define SG_LINK         8       // link has been set
/// @}

// builtin |highlight-groups|
static garray_T highlight_ga = GA_EMPTY_INIT_VALUE;

static inline struct hl_group * HL_TABLE(void)
{
  return ((struct hl_group *)((highlight_ga.ga_data)));
}

#define MAX_HL_ID       20000   /* maximum value for a highlight ID. */

/* different types of offsets that are possible */
#define SPO_MS_OFF      0       /* match  start offset */
#define SPO_ME_OFF      1       /* match  end	offset */
#define SPO_HS_OFF      2       /* highl. start offset */
#define SPO_HE_OFF      3       /* highl. end	offset */
#define SPO_RS_OFF      4       /* region start offset */
#define SPO_RE_OFF      5       /* region end	offset */
#define SPO_LC_OFF      6       /* leading context offset */
#define SPO_COUNT       7

/* Flags to indicate an additional string for highlight name completion. */
static int include_none = 0;    /* when 1 include "nvim/None" */
static int include_default = 0; /* when 1 include "nvim/default" */
static int include_link = 0;    /* when 2 include "nvim/link" and "clear" */

/// The "term", "cterm" and "gui" arguments can be any combination of the
/// following names, separated by commas (but no spaces!).
static char *(hl_name_table[]) =
{ "bold", "standout", "underline", "undercurl",
  "italic", "reverse", "inverse", "strikethrough", "nocombine", "NONE" };
static int hl_attr_table[] =
{ HL_BOLD, HL_STANDOUT, HL_UNDERLINE, HL_UNDERCURL, HL_ITALIC, HL_INVERSE,
  HL_INVERSE, HL_STRIKETHROUGH, HL_NOCOMBINE, 0 };

// The patterns that are being searched for are stored in a syn_pattern.
// A match item consists of one pattern.
// A start/end item consists of n start patterns and m end patterns.
// A start/skip/end item consists of n start patterns, one skip pattern and m
// end patterns.
// For the latter two, the patterns are always consecutive: start-skip-end.
//
// A character offset can be given for the matched text (_m_start and _m_end)
// and for the actually highlighted text (_h_start and _h_end).
//
// Note that ordering of members is optimized to reduce padding.
typedef struct syn_pattern {
  char sp_type;                         // see SPTYPE_ defines below
  bool sp_syncing;                      // this item used for syncing
  int16_t sp_syn_match_id;              // highlight group ID of pattern
  int16_t sp_off_flags;                 // see below
  int sp_offsets[SPO_COUNT];            // offsets
  int sp_flags;                         // see HL_ defines below
  int sp_cchar;                         // conceal substitute character
  int sp_ic;                            // ignore-case flag for sp_prog
  int sp_sync_idx;                      // sync item index (syncing only)
  int sp_line_id;                       // ID of last line where tried
  int sp_startcol;                      // next match in sp_line_id line
  int16_t *sp_cont_list;                // cont. group IDs, if non-zero
  int16_t *sp_next_list;                // next group IDs, if non-zero
  struct sp_syn sp_syn;                 // struct passed to in_id_list()
  char_u *sp_pattern;                   // regexp to match, pattern
  regprog_T *sp_prog;                   // regexp to match, program
  syn_time_T sp_time;
} synpat_T;


typedef struct syn_cluster_S {
  char_u *scl_name;         // syntax cluster name
  char_u *scl_name_u;       // uppercase of scl_name
  int16_t *scl_list;        // IDs in this syntax cluster
} syn_cluster_T;

/*
 * For the current state we need to remember more than just the idx.
 * When si_m_endpos.lnum is 0, the items other than si_idx are unknown.
 * (The end positions have the column number of the next char)
 */
typedef struct state_item {
  int si_idx;                           // index of syntax pattern or
                                        // KEYWORD_IDX
  int si_id;                            // highlight group ID for keywords
  int si_trans_id;                      // idem, transparency removed
  int si_m_lnum;                        // lnum of the match
  int si_m_startcol;                    // starting column of the match
  lpos_T si_m_endpos;                   // just after end posn of the match
  lpos_T si_h_startpos;                 // start position of the highlighting
  lpos_T si_h_endpos;                   // end position of the highlighting
  lpos_T si_eoe_pos;                    // end position of end pattern
  int si_end_idx;                       // group ID for end pattern or zero
  int si_ends;                          // if match ends before si_m_endpos
  int si_attr;                          // attributes in this state
  long si_flags;                        // HL_HAS_EOL flag in this state, and
                                        // HL_SKIP* for si_next_list
  int si_seqnr;                         // sequence number
  int si_cchar;                         // substitution character for conceal
  int16_t *si_cont_list;                // list of contained groups
  int16_t *si_next_list;                // nextgroup IDs after this item ends
  reg_extmatch_T *si_extmatch;          // \z(...\) matches from start
                                        // pattern
} stateitem_T;

/*
 * Struct to reduce the number of arguments to get_syn_options(), it's used
 * very often.
 */
typedef struct {
  int flags;                   // flags for contained and transparent
  bool keyword;                // true for ":syn keyword"
  int *sync_idx;               // syntax item for "grouphere" argument, NULL
                               // if not allowed
  bool has_cont_list;          // true if "cont_list" can be used
  int16_t *cont_list;          // group IDs for "contains" argument
  int16_t *cont_in_list;       // group IDs for "containedin" argument
  int16_t *next_list;          // group IDs for "nextgroup" argument
} syn_opt_arg_T;

typedef struct {
  proftime_T total;
  int count;
  int match;
  proftime_T slowest;
  proftime_T average;
  int id;
  char_u      *pattern;
} time_entry_T;

struct name_list {
  int flag;
  char        *name;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "syntax.c.generated.h"
#endif

static char *(spo_name_tab[SPO_COUNT]) =
{"ms=", "me=", "hs=", "he=", "rs=", "re=", "lc="};

/* The sp_off_flags are computed like this:
 * offset from the start of the matched text: (1 << SPO_XX_OFF)
 * offset from the end	 of the matched text: (1 << (SPO_XX_OFF + SPO_COUNT))
 * When both are present, only one is used.
 */

#define SPTYPE_MATCH    1       /* match keyword with this group ID */
#define SPTYPE_START    2       /* match a regexp, start of item */
#define SPTYPE_END      3       /* match a regexp, end of item */
#define SPTYPE_SKIP     4       /* match a regexp, skip within item */


#define SYN_ITEMS(buf)  ((synpat_T *)((buf)->b_syn_patterns.ga_data))

#define NONE_IDX        -2      /* value of sp_sync_idx for "NONE" */

/*
 * Flags for b_syn_sync_flags:
 */
#define SF_CCOMMENT     0x01    /* sync on a C-style comment */
#define SF_MATCH        0x02    /* sync by matching a pattern */

#define SYN_STATE_P(ssp)    ((bufstate_T *)((ssp)->ga_data))

#define MAXKEYWLEN      80          /* maximum length of a keyword */

/*
 * The attributes of the syntax item that has been recognized.
 */
static int current_attr = 0;        /* attr of current syntax word */
static int current_id = 0;          /* ID of current char for syn_get_id() */
static int current_trans_id = 0;    /* idem, transparency removed */
static int current_flags = 0;
static int current_seqnr = 0;
static int current_sub_char = 0;

/*
 * Methods of combining two clusters
 */
#define CLUSTER_REPLACE     1   /* replace first list with second */
#define CLUSTER_ADD         2   /* add second list to first */
#define CLUSTER_SUBTRACT    3   /* subtract second list from first */

#define SYN_CLSTR(buf)  ((syn_cluster_T *)((buf)->b_syn_clusters.ga_data))

/*
 * Syntax group IDs have different types:
 *     0 - 19999  normal syntax groups
 * 20000 - 20999  ALLBUT indicator (current_syn_inc_tag added)
 * 21000 - 21999  TOP indicator (current_syn_inc_tag added)
 * 22000 - 22999  CONTAINED indicator (current_syn_inc_tag added)
 * 23000 - 32767  cluster IDs (subtract SYNID_CLUSTER for the cluster ID)
 */
#define SYNID_ALLBUT    MAX_HL_ID   /* syntax group ID for contains=ALLBUT */
#define SYNID_TOP       21000       /* syntax group ID for contains=TOP */
#define SYNID_CONTAINED 22000       /* syntax group ID for contains=CONTAINED */
#define SYNID_CLUSTER   23000       /* first syntax group ID for clusters */

#define MAX_SYN_INC_TAG 999         /* maximum before the above overflow */
#define MAX_CLUSTER_ID  (32767 - SYNID_CLUSTER)

/*
 * Annoying Hack(TM):  ":syn include" needs this pointer to pass to
 * expand_filename().  Most of the other syntax commands don't need it, so
 * instead of passing it to them, we stow it here.
 */
static char_u **syn_cmdlinep;

/*
 * Another Annoying Hack(TM):  To prevent rules from other ":syn include"'d
 * files from leaking into ALLBUT lists, we assign a unique ID to the
 * rules in each ":syn include"'d file.
 */
static int current_syn_inc_tag = 0;
static int running_syn_inc_tag = 0;

/*
 * In a hashtable item "hi_key" points to "keyword" in a keyentry.
 * This avoids adding a pointer to the hashtable item.
 * KE2HIKEY() converts a var pointer to a hashitem key pointer.
 * HIKEY2KE() converts a hashitem key pointer to a var pointer.
 * HI2KE() converts a hashitem pointer to a var pointer.
 */
static keyentry_T dumkey;
#define KE2HIKEY(kp)  ((kp)->keyword)
#define HIKEY2KE(p)   ((keyentry_T *)((p) - (dumkey.keyword - (char_u *)&dumkey)))
#define HI2KE(hi)      HIKEY2KE((hi)->hi_key)

// -V:HI2KE:782

/*
 * To reduce the time spent in keepend(), remember at which level in the state
 * stack the first item with "keepend" is present.  When "-1", there is no
 * "keepend" on the stack.
 */
static int keepend_level = -1;

static char msg_no_items[] = N_("No Syntax items defined for this buffer");

// value of si_idx for keywords
#define KEYWORD_IDX     -1
// valid of si_cont_list for containing all but contained groups
#define ID_LIST_ALL     (int16_t *)-1

static int next_seqnr = 1;              /* value to use for si_seqnr */

/*
 * The next possible match in the current line for any pattern is remembered,
 * to avoid having to try for a match in each column.
 * If next_match_idx == -1, not tried (in this line) yet.
 * If next_match_col == MAXCOL, no match found in this line.
 * (All end positions have the column of the char after the end)
 */
static int next_match_col;              /* column for start of next match */
static lpos_T next_match_m_endpos;      /* position for end of next match */
static lpos_T next_match_h_startpos;  /* pos. for highl. start of next match */
static lpos_T next_match_h_endpos;      /* pos. for highl. end of next match */
static int next_match_idx;              /* index of matched item */
static long next_match_flags;           /* flags for next match */
static lpos_T next_match_eos_pos;       /* end of start pattn (start region) */
static lpos_T next_match_eoe_pos;       /* pos. for end of end pattern */
static int next_match_end_idx;          /* ID of group for end pattn or zero */
static reg_extmatch_T *next_match_extmatch = NULL;

/*
 * A state stack is an array of integers or stateitem_T, stored in a
 * garray_T.  A state stack is invalid if its itemsize entry is zero.
 */
#define INVALID_STATE(ssp)  ((ssp)->ga_itemsize == 0)
#define VALID_STATE(ssp)    ((ssp)->ga_itemsize != 0)

/*
 * The current state (within the line) of the recognition engine.
 * When current_state.ga_itemsize is 0 the current state is invalid.
 */
static win_T    *syn_win;               // current window for highlighting
static buf_T    *syn_buf;               // current buffer for highlighting
static synblock_T *syn_block;           // current buffer for highlighting
static proftime_T *syn_tm;              // timeout limit
static linenr_T current_lnum = 0;       // lnum of current state
static colnr_T current_col = 0;         // column of current state
static int current_state_stored = 0;    // TRUE if stored current state
                                        // after setting current_finished
static int current_finished = 0;        // current line has been finished
static garray_T current_state           // current stack of state_items
  = GA_EMPTY_INIT_VALUE;
static int16_t *current_next_list = NULL;   // when non-zero, nextgroup list
static int current_next_flags = 0;          // flags for current_next_list
static int current_line_id = 0;             // unique number for current line

#define CUR_STATE(idx)  ((stateitem_T *)(current_state.ga_data))[idx]

static int syn_time_on = FALSE;
# define IF_SYN_TIME(p) (p)

// Set the timeout used for syntax highlighting.
// Use NULL to reset, no timeout.
void syn_set_timeout(proftime_T *tm)
{
  syn_tm = tm;
}

/*
 * Start the syntax recognition for a line.  This function is normally called
 * from the screen updating, once for each displayed line.
 * The buffer is remembered in syn_buf, because get_syntax_attr() doesn't get
 * it.	Careful: curbuf and curwin are likely to point to another buffer and
 * window.
 */
void syntax_start(win_T *wp, linenr_T lnum)
{
  synstate_T  *p;
  synstate_T  *last_valid = NULL;
  synstate_T  *last_min_valid = NULL;
  synstate_T  *sp, *prev = NULL;
  linenr_T parsed_lnum;
  linenr_T first_stored;
  int dist;
  static int changedtick = 0;           /* remember the last change ID */

  current_sub_char = NUL;

  /*
   * After switching buffers, invalidate current_state.
   * Also do this when a change was made, the current state may be invalid
   * then.
   */
  if (syn_block != wp->w_s
      || syn_buf != wp->w_buffer
      || changedtick != buf_get_changedtick(syn_buf)) {
    invalidate_current_state();
    syn_buf = wp->w_buffer;
    syn_block = wp->w_s;
  }
  changedtick = buf_get_changedtick(syn_buf);
  syn_win = wp;

  /*
   * Allocate syntax stack when needed.
   */
  syn_stack_alloc();
  if (syn_block->b_sst_array == NULL)
    return;             /* out of memory */
  syn_block->b_sst_lasttick = display_tick;

  /*
   * If the state of the end of the previous line is useful, store it.
   */
  if (VALID_STATE(&current_state)
      && current_lnum < lnum
      && current_lnum < syn_buf->b_ml.ml_line_count) {
    (void)syn_finish_line(false);
    if (!current_state_stored) {
      ++current_lnum;
      (void)store_current_state();
    }

    /*
     * If the current_lnum is now the same as "lnum", keep the current
     * state (this happens very often!).  Otherwise invalidate
     * current_state and figure it out below.
     */
    if (current_lnum != lnum)
      invalidate_current_state();
  } else
    invalidate_current_state();

  /*
   * Try to synchronize from a saved state in b_sst_array[].
   * Only do this if lnum is not before and not to far beyond a saved state.
   */
  if (INVALID_STATE(&current_state) && syn_block->b_sst_array != NULL) {
    /* Find last valid saved state before start_lnum. */
    for (p = syn_block->b_sst_first; p != NULL; p = p->sst_next) {
      if (p->sst_lnum > lnum) {
        break;
      }
      if (p->sst_change_lnum == 0) {
        last_valid = p;
        if (p->sst_lnum >= lnum - syn_block->b_syn_sync_minlines)
          last_min_valid = p;
      }
    }
    if (last_min_valid != NULL)
      load_current_state(last_min_valid);
  }

  /*
   * If "lnum" is before or far beyond a line with a saved state, need to
   * re-synchronize.
   */
  if (INVALID_STATE(&current_state)) {
    syn_sync(wp, lnum, last_valid);
    if (current_lnum == 1)
      /* First line is always valid, no matter "minlines". */
      first_stored = 1;
    else
      /* Need to parse "minlines" lines before state can be considered
       * valid to store. */
      first_stored = current_lnum + syn_block->b_syn_sync_minlines;
  } else
    first_stored = current_lnum;

  /*
   * Advance from the sync point or saved state until the current line.
   * Save some entries for syncing with later on.
   */
  if (syn_block->b_sst_len <= Rows)
    dist = 999999;
  else
    dist = syn_buf->b_ml.ml_line_count / (syn_block->b_sst_len - Rows) + 1;
  while (current_lnum < lnum) {
    syn_start_line();
    (void)syn_finish_line(false);
    current_lnum++;

    /* If we parsed at least "minlines" lines or started at a valid
     * state, the current state is considered valid. */
    if (current_lnum >= first_stored) {
      /* Check if the saved state entry is for the current line and is
       * equal to the current state.  If so, then validate all saved
       * states that depended on a change before the parsed line. */
      if (prev == NULL)
        prev = syn_stack_find_entry(current_lnum - 1);
      if (prev == NULL)
        sp = syn_block->b_sst_first;
      else
        sp = prev;
      while (sp != NULL && sp->sst_lnum < current_lnum)
        sp = sp->sst_next;
      if (sp != NULL
          && sp->sst_lnum == current_lnum
          && syn_stack_equal(sp)) {
        parsed_lnum = current_lnum;
        prev = sp;
        while (sp != NULL && sp->sst_change_lnum <= parsed_lnum) {
          if (sp->sst_lnum <= lnum)
            /* valid state before desired line, use this one */
            prev = sp;
          else if (sp->sst_change_lnum == 0)
            /* past saved states depending on change, break here. */
            break;
          sp->sst_change_lnum = 0;
          sp = sp->sst_next;
        }
        load_current_state(prev);
      }
      /* Store the state at this line when it's the first one, the line
       * where we start parsing, or some distance from the previously
       * saved state.  But only when parsed at least 'minlines'. */
      else if (prev == NULL
               || current_lnum == lnum
               || current_lnum >= prev->sst_lnum + dist)
        prev = store_current_state();
    }

    /* This can take a long time: break when CTRL-C pressed.  The current
     * state will be wrong then. */
    line_breakcheck();
    if (got_int) {
      current_lnum = lnum;
      break;
    }
  }

  syn_start_line();
}

/*
 * We cannot simply discard growarrays full of state_items or buf_states; we
 * have to manually release their extmatch pointers first.
 */
static void clear_syn_state(synstate_T *p)
{
  if (p->sst_stacksize > SST_FIX_STATES) {
#   define UNREF_BUFSTATE_EXTMATCH(bs) unref_extmatch((bs)->bs_extmatch)
    GA_DEEP_CLEAR(&(p->sst_union.sst_ga), bufstate_T, UNREF_BUFSTATE_EXTMATCH);
  } else {
    for (int i = 0; i < p->sst_stacksize; i++) {
      unref_extmatch(p->sst_union.sst_stack[i].bs_extmatch);
    }
  }
}

/*
 * Cleanup the current_state stack.
 */
static void clear_current_state(void)
{
# define UNREF_STATEITEM_EXTMATCH(si) unref_extmatch((si)->si_extmatch)
  GA_DEEP_CLEAR(&current_state, stateitem_T, UNREF_STATEITEM_EXTMATCH);
}

/*
 * Try to find a synchronisation point for line "lnum".
 *
 * This sets current_lnum and the current state.  One of three methods is
 * used:
 * 1. Search backwards for the end of a C-comment.
 * 2. Search backwards for given sync patterns.
 * 3. Simply start on a given number of lines above "lnum".
 */
static void syn_sync(win_T *wp, linenr_T start_lnum, synstate_T *last_valid)
{
  buf_T       *curbuf_save;
  win_T       *curwin_save;
  pos_T cursor_save;
  int idx;
  linenr_T lnum;
  linenr_T end_lnum;
  linenr_T break_lnum;
  bool had_sync_point;
  stateitem_T *cur_si;
  synpat_T    *spp;
  char_u      *line;
  int found_flags = 0;
  int found_match_idx = 0;
  linenr_T found_current_lnum = 0;
  int found_current_col= 0;
  lpos_T found_m_endpos;
  colnr_T prev_current_col;

  /*
   * Clear any current state that might be hanging around.
   */
  invalidate_current_state();

  /*
   * Start at least "minlines" back.  Default starting point for parsing is
   * there.
   * Start further back, to avoid that scrolling backwards will result in
   * resyncing for every line.  Now it resyncs only one out of N lines,
   * where N is minlines * 1.5, or minlines * 2 if minlines is small.
   * Watch out for overflow when minlines is MAXLNUM.
   */
  if (syn_block->b_syn_sync_minlines > start_lnum)
    start_lnum = 1;
  else {
    if (syn_block->b_syn_sync_minlines == 1)
      lnum = 1;
    else if (syn_block->b_syn_sync_minlines < 10)
      lnum = syn_block->b_syn_sync_minlines * 2;
    else
      lnum = syn_block->b_syn_sync_minlines * 3 / 2;
    if (syn_block->b_syn_sync_maxlines != 0
        && lnum > syn_block->b_syn_sync_maxlines)
      lnum = syn_block->b_syn_sync_maxlines;
    if (lnum >= start_lnum)
      start_lnum = 1;
    else
      start_lnum -= lnum;
  }
  current_lnum = start_lnum;

  /*
   * 1. Search backwards for the end of a C-style comment.
   */
  if (syn_block->b_syn_sync_flags & SF_CCOMMENT) {
    /* Need to make syn_buf the current buffer for a moment, to be able to
     * use find_start_comment(). */
    curwin_save = curwin;
    curwin = wp;
    curbuf_save = curbuf;
    curbuf = syn_buf;

    /*
     * Skip lines that end in a backslash.
     */
    for (; start_lnum > 1; --start_lnum) {
      line = ml_get(start_lnum - 1);
      if (*line == NUL || *(line + STRLEN(line) - 1) != '\\')
        break;
    }
    current_lnum = start_lnum;

    /* set cursor to start of search */
    cursor_save = wp->w_cursor;
    wp->w_cursor.lnum = start_lnum;
    wp->w_cursor.col = 0;

    /*
     * If the line is inside a comment, need to find the syntax item that
     * defines the comment.
     * Restrict the search for the end of a comment to b_syn_sync_maxlines.
     */
    if (find_start_comment((int)syn_block->b_syn_sync_maxlines) != NULL) {
      for (idx = syn_block->b_syn_patterns.ga_len; --idx >= 0; )
        if (SYN_ITEMS(syn_block)[idx].sp_syn.id
            == syn_block->b_syn_sync_id
            && SYN_ITEMS(syn_block)[idx].sp_type == SPTYPE_START) {
          validate_current_state();
          push_current_state(idx);
          update_si_attr(current_state.ga_len - 1);
          break;
        }
    }

    /* restore cursor and buffer */
    wp->w_cursor = cursor_save;
    curwin = curwin_save;
    curbuf = curbuf_save;
  }
  /*
   * 2. Search backwards for given sync patterns.
   */
  else if (syn_block->b_syn_sync_flags & SF_MATCH) {
    if (syn_block->b_syn_sync_maxlines != 0
        && start_lnum > syn_block->b_syn_sync_maxlines)
      break_lnum = start_lnum - syn_block->b_syn_sync_maxlines;
    else
      break_lnum = 0;

    found_m_endpos.lnum = 0;
    found_m_endpos.col = 0;
    end_lnum = start_lnum;
    lnum = start_lnum;
    while (--lnum > break_lnum) {
      /* This can take a long time: break when CTRL-C pressed. */
      line_breakcheck();
      if (got_int) {
        invalidate_current_state();
        current_lnum = start_lnum;
        break;
      }

      /* Check if we have run into a valid saved state stack now. */
      if (last_valid != NULL && lnum == last_valid->sst_lnum) {
        load_current_state(last_valid);
        break;
      }

      /*
       * Check if the previous line has the line-continuation pattern.
       */
      if (lnum > 1 && syn_match_linecont(lnum - 1))
        continue;

      /*
       * Start with nothing on the state stack
       */
      validate_current_state();

      for (current_lnum = lnum; current_lnum < end_lnum; ++current_lnum) {
        syn_start_line();
        for (;; ) {
          had_sync_point = syn_finish_line(true);
          // When a sync point has been found, remember where, and
          // continue to look for another one, further on in the line.
          if (had_sync_point && current_state.ga_len) {
            cur_si = &CUR_STATE(current_state.ga_len - 1);
            if (cur_si->si_m_endpos.lnum > start_lnum) {
              /* ignore match that goes to after where started */
              current_lnum = end_lnum;
              break;
            }
            if (cur_si->si_idx < 0) {
              /* Cannot happen? */
              found_flags = 0;
              found_match_idx = KEYWORD_IDX;
            } else {
              spp = &(SYN_ITEMS(syn_block)[cur_si->si_idx]);
              found_flags = spp->sp_flags;
              found_match_idx = spp->sp_sync_idx;
            }
            found_current_lnum = current_lnum;
            found_current_col = current_col;
            found_m_endpos = cur_si->si_m_endpos;
            /*
             * Continue after the match (be aware of a zero-length
             * match).
             */
            if (found_m_endpos.lnum > current_lnum) {
              current_lnum = found_m_endpos.lnum;
              current_col = found_m_endpos.col;
              if (current_lnum >= end_lnum)
                break;
            } else if (found_m_endpos.col > current_col)
              current_col = found_m_endpos.col;
            else
              ++current_col;

            /* syn_current_attr() will have skipped the check for
             * an item that ends here, need to do that now.  Be
             * careful not to go past the NUL. */
            prev_current_col = current_col;
            if (syn_getcurline()[current_col] != NUL)
              ++current_col;
            check_state_ends();
            current_col = prev_current_col;
          } else
            break;
        }
      }

      /*
       * If a sync point was encountered, break here.
       */
      if (found_flags) {
        /*
         * Put the item that was specified by the sync point on the
         * state stack.  If there was no item specified, make the
         * state stack empty.
         */
        clear_current_state();
        if (found_match_idx >= 0) {
          push_current_state(found_match_idx);
          update_si_attr(current_state.ga_len - 1);
        }

        /*
         * When using "grouphere", continue from the sync point
         * match, until the end of the line.  Parsing starts at
         * the next line.
         * For "groupthere" the parsing starts at start_lnum.
         */
        if (found_flags & HL_SYNC_HERE) {
          if (!GA_EMPTY(&current_state)) {
            cur_si = &CUR_STATE(current_state.ga_len - 1);
            cur_si->si_h_startpos.lnum = found_current_lnum;
            cur_si->si_h_startpos.col = found_current_col;
            update_si_end(cur_si, (int)current_col, TRUE);
            check_keepend();
          }
          current_col = found_m_endpos.col;
          current_lnum = found_m_endpos.lnum;
          (void)syn_finish_line(false);
          current_lnum++;
        } else {
          current_lnum = start_lnum;
        }

        break;
      }

      end_lnum = lnum;
      invalidate_current_state();
    }

    /* Ran into start of the file or exceeded maximum number of lines */
    if (lnum <= break_lnum) {
      invalidate_current_state();
      current_lnum = break_lnum + 1;
    }
  }

  validate_current_state();
}

static void save_chartab(char_u *chartab)
{
  if (syn_block->b_syn_isk != empty_option) {
    memmove(chartab, syn_buf->b_chartab, (size_t)32);
    memmove(syn_buf->b_chartab, syn_win->w_s->b_syn_chartab, (size_t)32);
  }
}

static void restore_chartab(char_u *chartab)
{
  if (syn_win->w_s->b_syn_isk != empty_option) {
    memmove(syn_buf->b_chartab, chartab, (size_t)32);
  }
}

/*
 * Return TRUE if the line-continuation pattern matches in line "lnum".
 */
static int syn_match_linecont(linenr_T lnum)
{
  if (syn_block->b_syn_linecont_prog != NULL) {
    regmmatch_T regmatch;
    // chartab array for syn iskeyword
    char_u buf_chartab[32];
    save_chartab(buf_chartab);

    regmatch.rmm_ic = syn_block->b_syn_linecont_ic;
    regmatch.regprog = syn_block->b_syn_linecont_prog;
    int r = syn_regexec(&regmatch, lnum, (colnr_T)0,
                        IF_SYN_TIME(&syn_block->b_syn_linecont_time));
    syn_block->b_syn_linecont_prog = regmatch.regprog;

    restore_chartab(buf_chartab);
    return r;
  }
  return FALSE;
}

/*
 * Prepare the current state for the start of a line.
 */
static void syn_start_line(void)
{
  current_finished = FALSE;
  current_col = 0;

  /*
   * Need to update the end of a start/skip/end that continues from the
   * previous line and regions that have "keepend".
   */
  if (!GA_EMPTY(&current_state)) {
    syn_update_ends(TRUE);
    check_state_ends();
  }

  next_match_idx = -1;
  current_line_id++;
  next_seqnr = 1;
}

/*
 * Check for items in the stack that need their end updated.
 * When "startofline" is TRUE the last item is always updated.
 * When "startofline" is FALSE the item with "keepend" is forcefully updated.
 */
static void syn_update_ends(int startofline)
{
  stateitem_T *cur_si;
  int seen_keepend;

  if (startofline) {
    /* Check for a match carried over from a previous line with a
     * contained region.  The match ends as soon as the region ends. */
    for (int i = 0; i < current_state.ga_len; ++i) {
      cur_si = &CUR_STATE(i);
      if (cur_si->si_idx >= 0
          && (SYN_ITEMS(syn_block)[cur_si->si_idx]).sp_type
          == SPTYPE_MATCH
          && cur_si->si_m_endpos.lnum < current_lnum) {
        cur_si->si_flags |= HL_MATCHCONT;
        cur_si->si_m_endpos.lnum = 0;
        cur_si->si_m_endpos.col = 0;
        cur_si->si_h_endpos = cur_si->si_m_endpos;
        cur_si->si_ends = TRUE;
      }
    }
  }

  /*
   * Need to update the end of a start/skip/end that continues from the
   * previous line.  And regions that have "keepend", because they may
   * influence contained items.  If we've just removed "extend"
   * (startofline == 0) then we should update ends of normal regions
   * contained inside "keepend" because "extend" could have extended
   * these "keepend" regions as well as contained normal regions.
   * Then check for items ending in column 0.
   */
  int i = current_state.ga_len - 1;
  if (keepend_level >= 0)
    for (; i > keepend_level; --i)
      if (CUR_STATE(i).si_flags & HL_EXTEND)
        break;

  seen_keepend = FALSE;
  for (; i < current_state.ga_len; ++i) {
    cur_si = &CUR_STATE(i);
    if ((cur_si->si_flags & HL_KEEPEND)
        || (seen_keepend && !startofline)
        || (i == current_state.ga_len - 1 && startofline)) {
      cur_si->si_h_startpos.col = 0;            /* start highl. in col 0 */
      cur_si->si_h_startpos.lnum = current_lnum;

      if (!(cur_si->si_flags & HL_MATCHCONT))
        update_si_end(cur_si, (int)current_col, !startofline);

      if (!startofline && (cur_si->si_flags & HL_KEEPEND))
        seen_keepend = TRUE;
    }
  }
  check_keepend();
}

/****************************************
 * Handling of the state stack cache.
 */

/*
 * EXPLANATION OF THE SYNTAX STATE STACK CACHE
 *
 * To speed up syntax highlighting, the state stack for the start of some
 * lines is cached.  These entries can be used to start parsing at that point.
 *
 * The stack is kept in b_sst_array[] for each buffer.  There is a list of
 * valid entries.  b_sst_first points to the first one, then follow sst_next.
 * The entries are sorted on line number.  The first entry is often for line 2
 * (line 1 always starts with an empty stack).
 * There is also a list for free entries.  This construction is used to avoid
 * having to allocate and free memory blocks too often.
 *
 * When making changes to the buffer, this is logged in b_mod_*.  When calling
 * update_screen() to update the display, it will call
 * syn_stack_apply_changes() for each displayed buffer to adjust the cached
 * entries.  The entries which are inside the changed area are removed,
 * because they must be recomputed.  Entries below the changed have their line
 * number adjusted for deleted/inserted lines, and have their sst_change_lnum
 * set to indicate that a check must be made if the changed lines would change
 * the cached entry.
 *
 * When later displaying lines, an entry is stored for each line.  Displayed
 * lines are likely to be displayed again, in which case the state at the
 * start of the line is needed.
 * For not displayed lines, an entry is stored for every so many lines.  These
 * entries will be used e.g., when scrolling backwards.  The distance between
 * entries depends on the number of lines in the buffer.  For small buffers
 * the distance is fixed at SST_DIST, for large buffers there is a fixed
 * number of entries SST_MAX_ENTRIES, and the distance is computed.
 */

static void syn_stack_free_block(synblock_T *block)
{
  synstate_T  *p;

  if (block->b_sst_array != NULL) {
    for (p = block->b_sst_first; p != NULL; p = p->sst_next) {
      clear_syn_state(p);
    }
    XFREE_CLEAR(block->b_sst_array);
    block->b_sst_first = NULL;
    block->b_sst_len = 0;
  }
}
/*
 * Free b_sst_array[] for buffer "buf".
 * Used when syntax items changed to force resyncing everywhere.
 */
void syn_stack_free_all(synblock_T *block)
{
  syn_stack_free_block(block);

  /* When using "syntax" fold method, must update all folds. */
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_s == block && foldmethodIsSyntax(wp)) {
      foldUpdateAll(wp);
    }
  }
}

/*
 * Allocate the syntax state stack for syn_buf when needed.
 * If the number of entries in b_sst_array[] is much too big or a bit too
 * small, reallocate it.
 * Also used to allocate b_sst_array[] for the first time.
 */
static void syn_stack_alloc(void)
{
  long len;
  synstate_T  *to, *from;
  synstate_T  *sstp;

  len = syn_buf->b_ml.ml_line_count / SST_DIST + Rows * 2;
  if (len < SST_MIN_ENTRIES)
    len = SST_MIN_ENTRIES;
  else if (len > SST_MAX_ENTRIES)
    len = SST_MAX_ENTRIES;
  if (syn_block->b_sst_len > len * 2 || syn_block->b_sst_len < len) {
    /* Allocate 50% too much, to avoid reallocating too often. */
    len = syn_buf->b_ml.ml_line_count;
    len = (len + len / 2) / SST_DIST + Rows * 2;
    if (len < SST_MIN_ENTRIES)
      len = SST_MIN_ENTRIES;
    else if (len > SST_MAX_ENTRIES)
      len = SST_MAX_ENTRIES;

    if (syn_block->b_sst_array != NULL) {
      /* When shrinking the array, cleanup the existing stack.
       * Make sure that all valid entries fit in the new array. */
      while (syn_block->b_sst_len - syn_block->b_sst_freecount + 2 > len
             && syn_stack_cleanup())
        ;
      if (len < syn_block->b_sst_len - syn_block->b_sst_freecount + 2)
        len = syn_block->b_sst_len - syn_block->b_sst_freecount + 2;
    }

    assert(len >= 0);
    sstp = xcalloc(len, sizeof(synstate_T));

    to = sstp - 1;
    if (syn_block->b_sst_array != NULL) {
      /* Move the states from the old array to the new one. */
      for (from = syn_block->b_sst_first; from != NULL;
           from = from->sst_next) {
        ++to;
        *to = *from;
        to->sst_next = to + 1;
      }
    }
    if (to != sstp - 1) {
      to->sst_next = NULL;
      syn_block->b_sst_first = sstp;
      syn_block->b_sst_freecount = len - (int)(to - sstp) - 1;
    } else {
      syn_block->b_sst_first = NULL;
      syn_block->b_sst_freecount = len;
    }

    /* Create the list of free entries. */
    syn_block->b_sst_firstfree = to + 1;
    while (++to < sstp + len)
      to->sst_next = to + 1;
    (sstp + len - 1)->sst_next = NULL;

    xfree(syn_block->b_sst_array);
    syn_block->b_sst_array = sstp;
    syn_block->b_sst_len = len;
  }
}

/*
 * Check for changes in a buffer to affect stored syntax states.  Uses the
 * b_mod_* fields.
 * Called from update_screen(), before screen is being updated, once for each
 * displayed buffer.
 */
void syn_stack_apply_changes(buf_T *buf)
{
  syn_stack_apply_changes_block(&buf->b_s, buf);

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if ((wp->w_buffer == buf) && (wp->w_s != &buf->b_s)) {
      syn_stack_apply_changes_block(wp->w_s, buf);
    }
  }
}

static void syn_stack_apply_changes_block(synblock_T *block, buf_T *buf)
{
  synstate_T  *p, *prev, *np;
  linenr_T n;

  prev = NULL;
  for (p = block->b_sst_first; p != NULL; ) {
    if (p->sst_lnum + block->b_syn_sync_linebreaks > buf->b_mod_top) {
      n = p->sst_lnum + buf->b_mod_xlines;
      if (n <= buf->b_mod_bot) {
        /* this state is inside the changed area, remove it */
        np = p->sst_next;
        if (prev == NULL)
          block->b_sst_first = np;
        else
          prev->sst_next = np;
        syn_stack_free_entry(block, p);
        p = np;
        continue;
      }
      /* This state is below the changed area.  Remember the line
       * that needs to be parsed before this entry can be made valid
       * again. */
      if (p->sst_change_lnum != 0 && p->sst_change_lnum > buf->b_mod_top) {
        if (p->sst_change_lnum + buf->b_mod_xlines > buf->b_mod_top)
          p->sst_change_lnum += buf->b_mod_xlines;
        else
          p->sst_change_lnum = buf->b_mod_top;
      }
      if (p->sst_change_lnum == 0
          || p->sst_change_lnum < buf->b_mod_bot)
        p->sst_change_lnum = buf->b_mod_bot;

      p->sst_lnum = n;
    }
    prev = p;
    p = p->sst_next;
  }
}

/*
 * Reduce the number of entries in the state stack for syn_buf.
 * Returns TRUE if at least one entry was freed.
 */
static int syn_stack_cleanup(void)
{
  synstate_T  *p, *prev;
  disptick_T tick;
  int above;
  int dist;
  int retval = FALSE;

  if (syn_block->b_sst_first == NULL) {
    return retval;
  }

  /* Compute normal distance between non-displayed entries. */
  if (syn_block->b_sst_len <= Rows)
    dist = 999999;
  else
    dist = syn_buf->b_ml.ml_line_count / (syn_block->b_sst_len - Rows) + 1;

  /*
   * Go through the list to find the "tick" for the oldest entry that can
   * be removed.  Set "above" when the "tick" for the oldest entry is above
   * "b_sst_lasttick" (the display tick wraps around).
   */
  tick = syn_block->b_sst_lasttick;
  above = FALSE;
  prev = syn_block->b_sst_first;
  for (p = prev->sst_next; p != NULL; prev = p, p = p->sst_next) {
    if (prev->sst_lnum + dist > p->sst_lnum) {
      if (p->sst_tick > syn_block->b_sst_lasttick) {
        if (!above || p->sst_tick < tick)
          tick = p->sst_tick;
        above = TRUE;
      } else if (!above && p->sst_tick < tick)
        tick = p->sst_tick;
    }
  }

  /*
   * Go through the list to make the entries for the oldest tick at an
   * interval of several lines.
   */
  prev = syn_block->b_sst_first;
  for (p = prev->sst_next; p != NULL; prev = p, p = p->sst_next) {
    if (p->sst_tick == tick && prev->sst_lnum + dist > p->sst_lnum) {
      /* Move this entry from used list to free list */
      prev->sst_next = p->sst_next;
      syn_stack_free_entry(syn_block, p);
      p = prev;
      retval = TRUE;
    }
  }
  return retval;
}

/*
 * Free the allocated memory for a syn_state item.
 * Move the entry into the free list.
 */
static void syn_stack_free_entry(synblock_T *block, synstate_T *p)
{
  clear_syn_state(p);
  p->sst_next = block->b_sst_firstfree;
  block->b_sst_firstfree = p;
  ++block->b_sst_freecount;
}

/*
 * Find an entry in the list of state stacks at or before "lnum".
 * Returns NULL when there is no entry or the first entry is after "lnum".
 */
static synstate_T *syn_stack_find_entry(linenr_T lnum)
{
  synstate_T  *p, *prev;

  prev = NULL;
  for (p = syn_block->b_sst_first; p != NULL; prev = p, p = p->sst_next) {
    if (p->sst_lnum == lnum)
      return p;
    if (p->sst_lnum > lnum)
      break;
  }
  return prev;
}

/*
 * Try saving the current state in b_sst_array[].
 * The current state must be valid for the start of the current_lnum line!
 */
static synstate_T *store_current_state(void)
{
  int i;
  synstate_T  *p;
  bufstate_T  *bp;
  stateitem_T *cur_si;
  synstate_T  *sp = syn_stack_find_entry(current_lnum);

  /*
   * If the current state contains a start or end pattern that continues
   * from the previous line, we can't use it.  Don't store it then.
   */
  for (i = current_state.ga_len - 1; i >= 0; --i) {
    cur_si = &CUR_STATE(i);
    if (cur_si->si_h_startpos.lnum >= current_lnum
        || cur_si->si_m_endpos.lnum >= current_lnum
        || cur_si->si_h_endpos.lnum >= current_lnum
        || (cur_si->si_end_idx
            && cur_si->si_eoe_pos.lnum >= current_lnum))
      break;
  }
  if (i >= 0) {
    if (sp != NULL) {
      /* find "sp" in the list and remove it */
      if (syn_block->b_sst_first == sp)
        /* it's the first entry */
        syn_block->b_sst_first = sp->sst_next;
      else {
        /* find the entry just before this one to adjust sst_next */
        for (p = syn_block->b_sst_first; p != NULL; p = p->sst_next)
          if (p->sst_next == sp)
            break;
        if (p != NULL)          /* just in case */
          p->sst_next = sp->sst_next;
      }
      syn_stack_free_entry(syn_block, sp);
      sp = NULL;
    }
  } else if (sp == NULL || sp->sst_lnum != current_lnum)   {
    /*
     * Add a new entry
     */
    /* If no free items, cleanup the array first. */
    if (syn_block->b_sst_freecount == 0) {
      (void)syn_stack_cleanup();
      /* "sp" may have been moved to the freelist now */
      sp = syn_stack_find_entry(current_lnum);
    }
    /* Still no free items?  Must be a strange problem... */
    if (syn_block->b_sst_freecount == 0)
      sp = NULL;
    else {
      /* Take the first item from the free list and put it in the used
       * list, after *sp */
      p = syn_block->b_sst_firstfree;
      syn_block->b_sst_firstfree = p->sst_next;
      --syn_block->b_sst_freecount;
      if (sp == NULL) {
        /* Insert in front of the list */
        p->sst_next = syn_block->b_sst_first;
        syn_block->b_sst_first = p;
      } else {
        /* insert in list after *sp */
        p->sst_next = sp->sst_next;
        sp->sst_next = p;
      }
      sp = p;
      sp->sst_stacksize = 0;
      sp->sst_lnum = current_lnum;
    }
  }
  if (sp != NULL) {
    /* When overwriting an existing state stack, clear it first */
    clear_syn_state(sp);
    sp->sst_stacksize = current_state.ga_len;
    if (current_state.ga_len > SST_FIX_STATES) {
      /* Need to clear it, might be something remaining from when the
       * length was less than SST_FIX_STATES. */
      ga_init(&sp->sst_union.sst_ga, (int)sizeof(bufstate_T), 1);
      ga_grow(&sp->sst_union.sst_ga, current_state.ga_len);
      sp->sst_union.sst_ga.ga_len = current_state.ga_len;
      bp = SYN_STATE_P(&(sp->sst_union.sst_ga));
    } else
      bp = sp->sst_union.sst_stack;
    for (i = 0; i < sp->sst_stacksize; ++i) {
      bp[i].bs_idx = CUR_STATE(i).si_idx;
      bp[i].bs_flags = CUR_STATE(i).si_flags;
      bp[i].bs_seqnr = CUR_STATE(i).si_seqnr;
      bp[i].bs_cchar = CUR_STATE(i).si_cchar;
      bp[i].bs_extmatch = ref_extmatch(CUR_STATE(i).si_extmatch);
    }
    sp->sst_next_flags = current_next_flags;
    sp->sst_next_list = current_next_list;
    sp->sst_tick = display_tick;
    sp->sst_change_lnum = 0;
  }
  current_state_stored = TRUE;
  return sp;
}

/*
 * Copy a state stack from "from" in b_sst_array[] to current_state;
 */
static void load_current_state(synstate_T *from)
{
  int i;
  bufstate_T  *bp;

  clear_current_state();
  validate_current_state();
  keepend_level = -1;
  if (from->sst_stacksize) {
    ga_grow(&current_state, from->sst_stacksize);
    if (from->sst_stacksize > SST_FIX_STATES)
      bp = SYN_STATE_P(&(from->sst_union.sst_ga));
    else
      bp = from->sst_union.sst_stack;
    for (i = 0; i < from->sst_stacksize; ++i) {
      CUR_STATE(i).si_idx = bp[i].bs_idx;
      CUR_STATE(i).si_flags = bp[i].bs_flags;
      CUR_STATE(i).si_seqnr = bp[i].bs_seqnr;
      CUR_STATE(i).si_cchar = bp[i].bs_cchar;
      CUR_STATE(i).si_extmatch = ref_extmatch(bp[i].bs_extmatch);
      if (keepend_level < 0 && (CUR_STATE(i).si_flags & HL_KEEPEND))
        keepend_level = i;
      CUR_STATE(i).si_ends = FALSE;
      CUR_STATE(i).si_m_lnum = 0;
      if (CUR_STATE(i).si_idx >= 0)
        CUR_STATE(i).si_next_list =
          (SYN_ITEMS(syn_block)[CUR_STATE(i).si_idx]).sp_next_list;
      else
        CUR_STATE(i).si_next_list = NULL;
      update_si_attr(i);
    }
    current_state.ga_len = from->sst_stacksize;
  }
  current_next_list = from->sst_next_list;
  current_next_flags = from->sst_next_flags;
  current_lnum = from->sst_lnum;
}

/*
 * Compare saved state stack "*sp" with the current state.
 * Return TRUE when they are equal.
 */
static int syn_stack_equal(synstate_T *sp)
{
  bufstate_T  *bp;
  reg_extmatch_T      *six, *bsx;

  /* First a quick check if the stacks have the same size end nextlist. */
  if (sp->sst_stacksize != current_state.ga_len
      || sp->sst_next_list != current_next_list) {
    return FALSE;
  }

  /* Need to compare all states on both stacks. */
  if (sp->sst_stacksize > SST_FIX_STATES)
    bp = SYN_STATE_P(&(sp->sst_union.sst_ga));
  else
    bp = sp->sst_union.sst_stack;

  int i;
  for (i = current_state.ga_len; --i >= 0; ) {
    /* If the item has another index the state is different. */
    if (bp[i].bs_idx != CUR_STATE(i).si_idx)
      break;
    if (bp[i].bs_extmatch == CUR_STATE(i).si_extmatch) {
      continue;
    }
    /* When the extmatch pointers are different, the strings in
     * them can still be the same.  Check if the extmatch
     * references are equal. */
    bsx = bp[i].bs_extmatch;
    six = CUR_STATE(i).si_extmatch;
    /* If one of the extmatch pointers is NULL the states are
     * different. */
    if (bsx == NULL || six == NULL)
      break;
    int j;
    for (j = 0; j < NSUBEXP; ++j) {
      /* Check each referenced match string. They must all be
       * equal. */
      if (bsx->matches[j] != six->matches[j]) {
        /* If the pointer is different it can still be the
         * same text.  Compare the strings, ignore case when
         * the start item has the sp_ic flag set. */
        if (bsx->matches[j] == NULL || six->matches[j] == NULL) {
          break;
        }
        if (mb_strcmp_ic((SYN_ITEMS(syn_block)[CUR_STATE(i).si_idx]).sp_ic,
                         (const char *)bsx->matches[j],
                         (const char *)six->matches[j]) != 0) {
          break;
        }
      }
    }
    if (j != NSUBEXP)
      break;
  }
  if (i < 0)
    return TRUE;

  return FALSE;
}

/*
 * We stop parsing syntax above line "lnum".  If the stored state at or below
 * this line depended on a change before it, it now depends on the line below
 * the last parsed line.
 * The window looks like this:
 *	    line which changed
 *	    displayed line
 *	    displayed line
 * lnum ->  line below window
 */
void syntax_end_parsing(linenr_T lnum)
{
  synstate_T  *sp;

  sp = syn_stack_find_entry(lnum);
  if (sp != NULL && sp->sst_lnum < lnum)
    sp = sp->sst_next;

  if (sp != NULL && sp->sst_change_lnum != 0)
    sp->sst_change_lnum = lnum;
}

/*
 * End of handling of the state stack.
 ****************************************/

static void invalidate_current_state(void)
{
  clear_current_state();
  current_state.ga_itemsize = 0;        /* mark current_state invalid */
  current_next_list = NULL;
  keepend_level = -1;
}

static void validate_current_state(void)
{
  current_state.ga_itemsize = sizeof(stateitem_T);
  ga_set_growsize(&current_state, 3);
}

/*
 * Return TRUE if the syntax at start of lnum changed since last time.
 * This will only be called just after get_syntax_attr() for the previous
 * line, to check if the next line needs to be redrawn too.
 */
int syntax_check_changed(linenr_T lnum)
{
  int retval = TRUE;
  synstate_T  *sp;

  /*
   * Check the state stack when:
   * - lnum is just below the previously syntaxed line.
   * - lnum is not before the lines with saved states.
   * - lnum is not past the lines with saved states.
   * - lnum is at or before the last changed line.
   */
  if (VALID_STATE(&current_state) && lnum == current_lnum + 1) {
    sp = syn_stack_find_entry(lnum);
    if (sp != NULL && sp->sst_lnum == lnum) {
      /*
       * finish the previous line (needed when not all of the line was
       * drawn)
       */
      (void)syn_finish_line(false);

      /*
       * Compare the current state with the previously saved state of
       * the line.
       */
      if (syn_stack_equal(sp))
        retval = FALSE;

      /*
       * Store the current state in b_sst_array[] for later use.
       */
      ++current_lnum;
      (void)store_current_state();
    }
  }

  return retval;
}

/*
 * Finish the current line.
 * This doesn't return any attributes, it only gets the state at the end of
 * the line.  It can start anywhere in the line, as long as the current state
 * is valid.
 */
static bool
syn_finish_line(
    const bool syncing            // called for syncing
)
{
  while (!current_finished) {
    (void)syn_current_attr(syncing, false, NULL, false);

    // When syncing, and found some item, need to check the item.
    if (syncing && current_state.ga_len) {
      // Check for match with sync item.
      const stateitem_T *const cur_si = &CUR_STATE(current_state.ga_len - 1);
      if (cur_si->si_idx >= 0
          && (SYN_ITEMS(syn_block)[cur_si->si_idx].sp_flags
              & (HL_SYNC_HERE|HL_SYNC_THERE))) {
        return true;
      }

      // syn_current_attr() will have skipped the check for an item
      // that ends here, need to do that now.  Be careful not to go
      // past the NUL.
      const colnr_T prev_current_col = current_col;
      if (syn_getcurline()[current_col] != NUL) {
        current_col++;
      }
      check_state_ends();
      current_col = prev_current_col;
    }
    current_col++;
  }
  return false;
}

/*
 * Return highlight attributes for next character.
 * Must first call syntax_start() once for the line.
 * "col" is normally 0 for the first use in a line, and increments by one each
 * time.  It's allowed to skip characters and to stop before the end of the
 * line.  But only a "col" after a previously used column is allowed.
 * When "can_spell" is not NULL set it to TRUE when spell-checking should be
 * done.
 */
int
get_syntax_attr(
    const colnr_T col,
    bool *const can_spell,
    const bool keep_state           // keep state of char at "col"
)
{
  int attr = 0;

  if (can_spell != NULL)
    /* Default: Only do spelling when there is no @Spell cluster or when
     * ":syn spell toplevel" was used. */
    *can_spell = syn_block->b_syn_spell == SYNSPL_DEFAULT
                 ? (syn_block->b_spell_cluster_id == 0)
                 : (syn_block->b_syn_spell == SYNSPL_TOP);

  /* check for out of memory situation */
  if (syn_block->b_sst_array == NULL)
    return 0;

  /* After 'synmaxcol' the attribute is always zero. */
  if (syn_buf->b_p_smc > 0 && col >= (colnr_T)syn_buf->b_p_smc) {
    clear_current_state();
    current_id = 0;
    current_trans_id = 0;
    current_flags = 0;
    current_seqnr = 0;
    return 0;
  }

  /* Make sure current_state is valid */
  if (INVALID_STATE(&current_state))
    validate_current_state();

  /*
   * Skip from the current column to "col", get the attributes for "col".
   */
  while (current_col <= col) {
    attr = syn_current_attr(false, true, can_spell,
                            current_col == col ? keep_state : false);
    current_col++;
  }

  return attr;
}

/*
 * Get syntax attributes for current_lnum, current_col.
 */
static int syn_current_attr(
    const bool syncing,                   // When true: called for syncing
    const bool displaying,                // result will be displayed
    bool *const can_spell,                // return: do spell checking
    const bool keep_state                 // keep syntax stack afterwards
)
{
  lpos_T endpos;                // was: char_u *endp;
  lpos_T hl_startpos;           // was: int hl_startcol;
  lpos_T hl_endpos;
  lpos_T eos_pos;               // end-of-start match (start region)
  lpos_T eoe_pos;               // end-of-end pattern
  int end_idx;                  // group ID for end pattern
  stateitem_T *cur_si, *sip = NULL;
  int startcol;
  int endcol;
  long flags;
  int cchar;
  int16_t *next_list;
  bool found_match;                         // found usable match
  static bool try_next_column = false;      // must try in next col
  regmmatch_T regmatch;
  lpos_T pos;
  reg_extmatch_T *cur_extmatch = NULL;
  char_u      buf_chartab[32];  // chartab array for syn iskeyword
  char_u      *line;            // current line.  NOTE: becomes invalid after
                                // looking for a pattern match!

  // variables for zero-width matches that have a "nextgroup" argument
  bool keep_next_list;
  bool zero_width_next_list = false;
  garray_T zero_width_next_ga;

  /*
   * No character, no attributes!  Past end of line?
   * Do try matching with an empty line (could be the start of a region).
   */
  line = syn_getcurline();
  if (line[current_col] == NUL && current_col != 0) {
    /*
     * If we found a match after the last column, use it.
     */
    if (next_match_idx >= 0 && next_match_col >= (int)current_col
        && next_match_col != MAXCOL) {
      (void)push_next_match();
    }

    current_finished = TRUE;
    current_state_stored = FALSE;
    return 0;
  }

  /* if the current or next character is NUL, we will finish the line now */
  if (line[current_col] == NUL || line[current_col + 1] == NUL) {
    current_finished = TRUE;
    current_state_stored = FALSE;
  }

  /*
   * When in the previous column there was a match but it could not be used
   * (empty match or already matched in this column) need to try again in
   * the next column.
   */
  if (try_next_column) {
    next_match_idx = -1;
    try_next_column = false;
  }

  // Only check for keywords when not syncing and there are some.
  const bool do_keywords = !syncing
      && (syn_block->b_keywtab.ht_used > 0
          || syn_block->b_keywtab_ic.ht_used > 0);

  /* Init the list of zero-width matches with a nextlist.  This is used to
   * avoid matching the same item in the same position twice. */
  ga_init(&zero_width_next_ga, (int)sizeof(int), 10);

  // use syntax iskeyword option
  save_chartab(buf_chartab);

  /*
   * Repeat matching keywords and patterns, to find contained items at the
   * same column.  This stops when there are no extra matches at the current
   * column.
   */
  do {
    found_match = false;
    keep_next_list = false;
    int syn_id = 0;

    /*
     * 1. Check for a current state.
     *    Only when there is no current state, or if the current state may
     *    contain other things, we need to check for keywords and patterns.
     *    Always need to check for contained items if some item has the
     *    "containedin" argument (takes extra time!).
     */
    if (current_state.ga_len)
      cur_si = &CUR_STATE(current_state.ga_len - 1);
    else
      cur_si = NULL;

    if (syn_block->b_syn_containedin || cur_si == NULL
        || cur_si->si_cont_list != NULL) {
      /*
       * 2. Check for keywords, if on a keyword char after a non-keyword
       *	  char.  Don't do this when syncing.
       */
      if (do_keywords) {
        line = syn_getcurline();
        const char_u *cur_pos = line + current_col;
        if (vim_iswordp_buf(cur_pos, syn_buf)
            && (current_col == 0 || !vim_iswordp_buf(
                cur_pos - 1 - utf_head_off(line, cur_pos - 1), syn_buf))) {
          syn_id = check_keyword_id(line, (int)current_col, &endcol, &flags,
                                    &next_list, cur_si, &cchar);
          if (syn_id != 0) {
            push_current_state(KEYWORD_IDX);
            {
              cur_si = &CUR_STATE(current_state.ga_len - 1);
              cur_si->si_m_startcol = current_col;
              cur_si->si_h_startpos.lnum = current_lnum;
              cur_si->si_h_startpos.col = 0;            /* starts right away */
              cur_si->si_m_endpos.lnum = current_lnum;
              cur_si->si_m_endpos.col = endcol;
              cur_si->si_h_endpos.lnum = current_lnum;
              cur_si->si_h_endpos.col = endcol;
              cur_si->si_ends = TRUE;
              cur_si->si_end_idx = 0;
              cur_si->si_flags = flags;
              cur_si->si_seqnr = next_seqnr++;
              cur_si->si_cchar = cchar;
              if (current_state.ga_len > 1)
                cur_si->si_flags |=
                  CUR_STATE(current_state.ga_len - 2).si_flags
                  & HL_CONCEAL;
              cur_si->si_id = syn_id;
              cur_si->si_trans_id = syn_id;
              if (flags & HL_TRANSP) {
                if (current_state.ga_len < 2) {
                  cur_si->si_attr = 0;
                  cur_si->si_trans_id = 0;
                } else {
                  cur_si->si_attr = CUR_STATE(
                      current_state.ga_len - 2).si_attr;
                  cur_si->si_trans_id = CUR_STATE(
                      current_state.ga_len - 2).si_trans_id;
                }
              } else {
                cur_si->si_attr = syn_id2attr(syn_id);
              }
              cur_si->si_cont_list = NULL;
              cur_si->si_next_list = next_list;
              check_keepend();
            }
          }
        }
      }

      /*
       * 3. Check for patterns (only if no keyword found).
       */
      if (syn_id == 0 && syn_block->b_syn_patterns.ga_len) {
        /*
         * If we didn't check for a match yet, or we are past it, check
         * for any match with a pattern.
         */
        if (next_match_idx < 0 || next_match_col < (int)current_col) {
          /*
           * Check all relevant patterns for a match at this
           * position.  This is complicated, because matching with a
           * pattern takes quite a bit of time, thus we want to
           * avoid doing it when it's not needed.
           */
          next_match_idx = 0;                   /* no match in this line yet */
          next_match_col = MAXCOL;
          for (int idx = syn_block->b_syn_patterns.ga_len; --idx >= 0; ) {
            synpat_T *const spp = &(SYN_ITEMS(syn_block)[idx]);
            if (       spp->sp_syncing == syncing
                       && (displaying || !(spp->sp_flags & HL_DISPLAY))
                       && (spp->sp_type == SPTYPE_MATCH
                           || spp->sp_type == SPTYPE_START)
                       && (current_next_list != NULL
                           ? in_id_list(NULL, current_next_list,
                               &spp->sp_syn, 0)
                           : (cur_si == NULL
                              ? !(spp->sp_flags & HL_CONTAINED)
                              : in_id_list(cur_si,
                                  cur_si->si_cont_list, &spp->sp_syn,
                                  spp->sp_flags & HL_CONTAINED)))) {
              /* If we already tried matching in this line, and
               * there isn't a match before next_match_col, skip
               * this item. */
              if (spp->sp_line_id == current_line_id
                  && spp->sp_startcol >= next_match_col)
                continue;
              spp->sp_line_id = current_line_id;

              colnr_T lc_col = current_col - spp->sp_offsets[SPO_LC_OFF];
              if (lc_col < 0) {
                lc_col = 0;
              }

              regmatch.rmm_ic = spp->sp_ic;
              regmatch.regprog = spp->sp_prog;
              int r = syn_regexec(&regmatch, current_lnum, lc_col,
                                  IF_SYN_TIME(&spp->sp_time));
              spp->sp_prog = regmatch.regprog;
              if (!r) {
                /* no match in this line, try another one */
                spp->sp_startcol = MAXCOL;
                continue;
              }

              /*
               * Compute the first column of the match.
               */
              syn_add_start_off(&pos, &regmatch,
                  spp, SPO_MS_OFF, -1);
              if (pos.lnum > current_lnum) {
                /* must have used end of match in a next line,
                 * we can't handle that */
                spp->sp_startcol = MAXCOL;
                continue;
              }
              startcol = pos.col;

              /* remember the next column where this pattern
               * matches in the current line */
              spp->sp_startcol = startcol;

              /*
               * If a previously found match starts at a lower
               * column number, don't use this one.
               */
              if (startcol >= next_match_col)
                continue;

              /*
               * If we matched this pattern at this position
               * before, skip it.  Must retry in the next
               * column, because it may match from there.
               */
              if (did_match_already(idx, &zero_width_next_ga)) {
                try_next_column = true;
                continue;
              }

              endpos.lnum = regmatch.endpos[0].lnum;
              endpos.col = regmatch.endpos[0].col;

              /* Compute the highlight start. */
              syn_add_start_off(&hl_startpos, &regmatch,
                  spp, SPO_HS_OFF, -1);

              /* Compute the region start. */
              /* Default is to use the end of the match. */
              syn_add_end_off(&eos_pos, &regmatch,
                  spp, SPO_RS_OFF, 0);

              /*
               * Grab the external submatches before they get
               * overwritten.  Reference count doesn't change.
               */
              unref_extmatch(cur_extmatch);
              cur_extmatch = re_extmatch_out;
              re_extmatch_out = NULL;

              flags = 0;
              eoe_pos.lnum = 0;                 /* avoid warning */
              eoe_pos.col = 0;
              end_idx = 0;
              hl_endpos.lnum = 0;

              /*
               * For a "oneline" the end must be found in the
               * same line too.  Search for it after the end of
               * the match with the start pattern.  Set the
               * resulting end positions at the same time.
               */
              if (spp->sp_type == SPTYPE_START
                  && (spp->sp_flags & HL_ONELINE)) {
                lpos_T startpos;

                startpos = endpos;
                find_endpos(idx, &startpos, &endpos, &hl_endpos,
                    &flags, &eoe_pos, &end_idx, cur_extmatch);
                if (endpos.lnum == 0)
                  continue;                         /* not found */
              }
              /*
               * For a "match" the size must be > 0 after the
               * end offset needs has been added.  Except when
               * syncing.
               */
              else if (spp->sp_type == SPTYPE_MATCH) {
                syn_add_end_off(&hl_endpos, &regmatch, spp,
                    SPO_HE_OFF, 0);
                syn_add_end_off(&endpos, &regmatch, spp,
                    SPO_ME_OFF, 0);
                if (endpos.lnum == current_lnum
                    && (int)endpos.col + syncing < startcol) {
                  /*
                   * If an empty string is matched, may need
                   * to try matching again at next column.
                   */
                  if (regmatch.startpos[0].col == regmatch.endpos[0].col) {
                    try_next_column = true;
                  }
                  continue;
                }
              }

              /*
               * keep the best match so far in next_match_*
               */
              /* Highlighting must start after startpos and end
               * before endpos. */
              if (hl_startpos.lnum == current_lnum
                  && (int)hl_startpos.col < startcol)
                hl_startpos.col = startcol;
              limit_pos_zero(&hl_endpos, &endpos);

              next_match_idx = idx;
              next_match_col = startcol;
              next_match_m_endpos = endpos;
              next_match_h_endpos = hl_endpos;
              next_match_h_startpos = hl_startpos;
              next_match_flags = flags;
              next_match_eos_pos = eos_pos;
              next_match_eoe_pos = eoe_pos;
              next_match_end_idx = end_idx;
              unref_extmatch(next_match_extmatch);
              next_match_extmatch = cur_extmatch;
              cur_extmatch = NULL;
            }
          }
        }

        /*
         * If we found a match at the current column, use it.
         */
        if (next_match_idx >= 0 && next_match_col == (int)current_col) {
          synpat_T    *lspp;

          /* When a zero-width item matched which has a nextgroup,
           * don't push the item but set nextgroup. */
          lspp = &(SYN_ITEMS(syn_block)[next_match_idx]);
          if (next_match_m_endpos.lnum == current_lnum
              && next_match_m_endpos.col == current_col
              && lspp->sp_next_list != NULL) {
            current_next_list = lspp->sp_next_list;
            current_next_flags = lspp->sp_flags;
            keep_next_list = true;
            zero_width_next_list = true;

            /* Add the index to a list, so that we can check
             * later that we don't match it again (and cause an
             * endless loop). */
            GA_APPEND(int, &zero_width_next_ga, next_match_idx);
            next_match_idx = -1;
          } else {
            cur_si = push_next_match();
          }
          found_match = true;
        }
      }
    }

    /*
     * Handle searching for nextgroup match.
     */
    if (current_next_list != NULL && !keep_next_list) {
      /*
       * If a nextgroup was not found, continue looking for one if:
       * - this is an empty line and the "skipempty" option was given
       * - we are on white space and the "skipwhite" option was given
       */
      if (!found_match) {
        line = syn_getcurline();
        if (((current_next_flags & HL_SKIPWHITE)
             && ascii_iswhite(line[current_col]))
            || ((current_next_flags & HL_SKIPEMPTY)
                && *line == NUL))
          break;
      }

      /*
       * If a nextgroup was found: Use it, and continue looking for
       * contained matches.
       * If a nextgroup was not found: Continue looking for a normal
       * match.
       * When did set current_next_list for a zero-width item and no
       * match was found don't loop (would get stuck).
       */
      current_next_list = NULL;
      next_match_idx = -1;
      if (!zero_width_next_list) {
        found_match = true;
      }
    }

  } while (found_match);

  restore_chartab(buf_chartab);

  /*
   * Use attributes from the current state, if within its highlighting.
   * If not, use attributes from the current-but-one state, etc.
   */
  current_attr = 0;
  current_id = 0;
  current_trans_id = 0;
  current_flags = 0;
  current_seqnr = 0;
  if (cur_si != NULL) {
    for (int idx = current_state.ga_len - 1; idx >= 0; --idx) {
      sip = &CUR_STATE(idx);
      if ((current_lnum > sip->si_h_startpos.lnum
           || (current_lnum == sip->si_h_startpos.lnum
               && current_col >= sip->si_h_startpos.col))
          && (sip->si_h_endpos.lnum == 0
              || current_lnum < sip->si_h_endpos.lnum
              || (current_lnum == sip->si_h_endpos.lnum
                  && current_col < sip->si_h_endpos.col))) {
        current_attr = sip->si_attr;
        current_id = sip->si_id;
        current_trans_id = sip->si_trans_id;
        current_flags = sip->si_flags;
        current_seqnr = sip->si_seqnr;
        current_sub_char = sip->si_cchar;
        break;
      }
    }

    if (can_spell != NULL) {
      struct sp_syn sps;

      /*
       * set "can_spell" to TRUE if spell checking is supposed to be
       * done in the current item.
       */
      if (syn_block->b_spell_cluster_id == 0) {
        /* There is no @Spell cluster: Do spelling for items without
         * @NoSpell cluster. */
        if (syn_block->b_nospell_cluster_id == 0
            || current_trans_id == 0)
          *can_spell = (syn_block->b_syn_spell != SYNSPL_NOTOP);
        else {
          sps.inc_tag = 0;
          sps.id = syn_block->b_nospell_cluster_id;
          sps.cont_in_list = NULL;
          *can_spell = !in_id_list(sip, sip->si_cont_list, &sps, 0);
        }
      } else {
        /* The @Spell cluster is defined: Do spelling in items with
         * the @Spell cluster.  But not when @NoSpell is also there.
         * At the toplevel only spell check when ":syn spell toplevel"
         * was used. */
        if (current_trans_id == 0)
          *can_spell = (syn_block->b_syn_spell == SYNSPL_TOP);
        else {
          sps.inc_tag = 0;
          sps.id = syn_block->b_spell_cluster_id;
          sps.cont_in_list = NULL;
          *can_spell = in_id_list(sip, sip->si_cont_list, &sps, 0);

          if (syn_block->b_nospell_cluster_id != 0) {
            sps.id = syn_block->b_nospell_cluster_id;
            if (in_id_list(sip, sip->si_cont_list, &sps, 0))
              *can_spell = false;
          }
        }
      }
    }


    /*
     * Check for end of current state (and the states before it) at the
     * next column.  Don't do this for syncing, because we would miss a
     * single character match.
     * First check if the current state ends at the current column.  It
     * may be for an empty match and a containing item might end in the
     * current column.
     */
    if (!syncing && !keep_state) {
      check_state_ends();
      if (!GA_EMPTY(&current_state)
          && syn_getcurline()[current_col] != NUL) {
        ++current_col;
        check_state_ends();
        --current_col;
      }
    }
  } else if (can_spell != NULL)
    /* Default: Only do spelling when there is no @Spell cluster or when
     * ":syn spell toplevel" was used. */
    *can_spell = syn_block->b_syn_spell == SYNSPL_DEFAULT
                 ? (syn_block->b_spell_cluster_id == 0)
                 : (syn_block->b_syn_spell == SYNSPL_TOP);

  /* nextgroup ends at end of line, unless "skipnl" or "skipempty" present */
  if (current_next_list != NULL
      && (line = syn_getcurline())[current_col] != NUL
      && line[current_col + 1] == NUL
      && !(current_next_flags & (HL_SKIPNL | HL_SKIPEMPTY))) {
    current_next_list = NULL;
  }

  if (!GA_EMPTY(&zero_width_next_ga))
    ga_clear(&zero_width_next_ga);

  /* No longer need external matches.  But keep next_match_extmatch. */
  unref_extmatch(re_extmatch_out);
  re_extmatch_out = NULL;
  unref_extmatch(cur_extmatch);

  return current_attr;
}


/*
 * Check if we already matched pattern "idx" at the current column.
 */
static int did_match_already(int idx, garray_T *gap)
{
  for (int i = current_state.ga_len; --i >= 0; ) {
    if (CUR_STATE(i).si_m_startcol == (int)current_col
        && CUR_STATE(i).si_m_lnum == (int)current_lnum
        && CUR_STATE(i).si_idx == idx) {
      return TRUE;
    }
  }

  /* Zero-width matches with a nextgroup argument are not put on the syntax
   * stack, and can only be matched once anyway. */
  for (int i = gap->ga_len; --i >= 0; ) {
    if (((int *)(gap->ga_data))[i] == idx) {
      return TRUE;
    }
  }

  return FALSE;
}

/*
 * Push the next match onto the stack.
 */
static stateitem_T *push_next_match(void)
{
  stateitem_T *cur_si;
  synpat_T *spp;
  int save_flags;

  spp = &(SYN_ITEMS(syn_block)[next_match_idx]);

  /*
   * Push the item in current_state stack;
   */
  push_current_state(next_match_idx);
  {
    /*
     * If it's a start-skip-end type that crosses lines, figure out how
     * much it continues in this line.  Otherwise just fill in the length.
     */
    cur_si = &CUR_STATE(current_state.ga_len - 1);
    cur_si->si_h_startpos = next_match_h_startpos;
    cur_si->si_m_startcol = current_col;
    cur_si->si_m_lnum = current_lnum;
    cur_si->si_flags = spp->sp_flags;
    cur_si->si_seqnr = next_seqnr++;
    cur_si->si_cchar = spp->sp_cchar;
    if (current_state.ga_len > 1)
      cur_si->si_flags |=
        CUR_STATE(current_state.ga_len - 2).si_flags & HL_CONCEAL;
    cur_si->si_next_list = spp->sp_next_list;
    cur_si->si_extmatch = ref_extmatch(next_match_extmatch);
    if (spp->sp_type == SPTYPE_START && !(spp->sp_flags & HL_ONELINE)) {
      /* Try to find the end pattern in the current line */
      update_si_end(cur_si, (int)(next_match_m_endpos.col), TRUE);
      check_keepend();
    } else {
      cur_si->si_m_endpos = next_match_m_endpos;
      cur_si->si_h_endpos = next_match_h_endpos;
      cur_si->si_ends = TRUE;
      cur_si->si_flags |= next_match_flags;
      cur_si->si_eoe_pos = next_match_eoe_pos;
      cur_si->si_end_idx = next_match_end_idx;
    }
    if (keepend_level < 0 && (cur_si->si_flags & HL_KEEPEND))
      keepend_level = current_state.ga_len - 1;
    check_keepend();
    update_si_attr(current_state.ga_len - 1);

    save_flags = cur_si->si_flags & (HL_CONCEAL | HL_CONCEALENDS);
    /*
     * If the start pattern has another highlight group, push another item
     * on the stack for the start pattern.
     */
    if (spp->sp_type == SPTYPE_START && spp->sp_syn_match_id != 0) {
      push_current_state(next_match_idx);
      cur_si = &CUR_STATE(current_state.ga_len - 1);
      cur_si->si_h_startpos = next_match_h_startpos;
      cur_si->si_m_startcol = current_col;
      cur_si->si_m_lnum = current_lnum;
      cur_si->si_m_endpos = next_match_eos_pos;
      cur_si->si_h_endpos = next_match_eos_pos;
      cur_si->si_ends = TRUE;
      cur_si->si_end_idx = 0;
      cur_si->si_flags = HL_MATCH;
      cur_si->si_seqnr = next_seqnr++;
      cur_si->si_flags |= save_flags;
      if (cur_si->si_flags & HL_CONCEALENDS)
        cur_si->si_flags |= HL_CONCEAL;
      cur_si->si_next_list = NULL;
      check_keepend();
      update_si_attr(current_state.ga_len - 1);
    }
  }

  next_match_idx = -1;          /* try other match next time */

  return cur_si;
}

/*
 * Check for end of current state (and the states before it).
 */
static void check_state_ends(void)
{
  stateitem_T *cur_si;
  int had_extend;

  cur_si = &CUR_STATE(current_state.ga_len - 1);
  for (;; ) {
    if (cur_si->si_ends
        && (cur_si->si_m_endpos.lnum < current_lnum
            || (cur_si->si_m_endpos.lnum == current_lnum
                && cur_si->si_m_endpos.col <= current_col))) {
      /*
       * If there is an end pattern group ID, highlight the end pattern
       * now.  No need to pop the current item from the stack.
       * Only do this if the end pattern continues beyond the current
       * position.
       */
      if (cur_si->si_end_idx
          && (cur_si->si_eoe_pos.lnum > current_lnum
              || (cur_si->si_eoe_pos.lnum == current_lnum
                  && cur_si->si_eoe_pos.col > current_col))) {
        cur_si->si_idx = cur_si->si_end_idx;
        cur_si->si_end_idx = 0;
        cur_si->si_m_endpos = cur_si->si_eoe_pos;
        cur_si->si_h_endpos = cur_si->si_eoe_pos;
        cur_si->si_flags |= HL_MATCH;
        cur_si->si_seqnr = next_seqnr++;
        if (cur_si->si_flags & HL_CONCEALENDS)
          cur_si->si_flags |= HL_CONCEAL;
        update_si_attr(current_state.ga_len - 1);

        /* nextgroup= should not match in the end pattern */
        current_next_list = NULL;

        /* what matches next may be different now, clear it */
        next_match_idx = 0;
        next_match_col = MAXCOL;
        break;
      } else {
        /* handle next_list, unless at end of line and no "skipnl" or
         * "skipempty" */
        current_next_list = cur_si->si_next_list;
        current_next_flags = cur_si->si_flags;
        if (!(current_next_flags & (HL_SKIPNL | HL_SKIPEMPTY))
            && syn_getcurline()[current_col] == NUL)
          current_next_list = NULL;

        /* When the ended item has "extend", another item with
         * "keepend" now needs to check for its end. */
        had_extend = (cur_si->si_flags & HL_EXTEND);

        pop_current_state();

        if (GA_EMPTY(&current_state))
          break;

        if (had_extend && keepend_level >= 0) {
          syn_update_ends(FALSE);
          if (GA_EMPTY(&current_state))
            break;
        }

        cur_si = &CUR_STATE(current_state.ga_len - 1);

        /*
         * Only for a region the search for the end continues after
         * the end of the contained item.  If the contained match
         * included the end-of-line, break here, the region continues.
         * Don't do this when:
         * - "keepend" is used for the contained item
         * - not at the end of the line (could be end="x$"me=e-1).
         * - "excludenl" is used (HL_HAS_EOL won't be set)
         */
        if (cur_si->si_idx >= 0
            && SYN_ITEMS(syn_block)[cur_si->si_idx].sp_type
            == SPTYPE_START
            && !(cur_si->si_flags & (HL_MATCH | HL_KEEPEND))) {
          update_si_end(cur_si, (int)current_col, TRUE);
          check_keepend();
          if ((current_next_flags & HL_HAS_EOL)
              && keepend_level < 0
              && syn_getcurline()[current_col] == NUL)
            break;
        }
      }
    } else
      break;
  }
}

/*
 * Update an entry in the current_state stack for a match or region.  This
 * fills in si_attr, si_next_list and si_cont_list.
 */
static void update_si_attr(int idx)
{
  stateitem_T *sip = &CUR_STATE(idx);
  synpat_T    *spp;

  /* This should not happen... */
  if (sip->si_idx < 0)
    return;

  spp = &(SYN_ITEMS(syn_block)[sip->si_idx]);
  if (sip->si_flags & HL_MATCH)
    sip->si_id = spp->sp_syn_match_id;
  else
    sip->si_id = spp->sp_syn.id;
  sip->si_attr = syn_id2attr(sip->si_id);
  sip->si_trans_id = sip->si_id;
  if (sip->si_flags & HL_MATCH)
    sip->si_cont_list = NULL;
  else
    sip->si_cont_list = spp->sp_cont_list;

  /*
   * For transparent items, take attr from outer item.
   * Also take cont_list, if there is none.
   * Don't do this for the matchgroup of a start or end pattern.
   */
  if ((spp->sp_flags & HL_TRANSP) && !(sip->si_flags & HL_MATCH)) {
    if (idx == 0) {
      sip->si_attr = 0;
      sip->si_trans_id = 0;
      if (sip->si_cont_list == NULL)
        sip->si_cont_list = ID_LIST_ALL;
    } else {
      sip->si_attr = CUR_STATE(idx - 1).si_attr;
      sip->si_trans_id = CUR_STATE(idx - 1).si_trans_id;
      sip->si_h_startpos = CUR_STATE(idx - 1).si_h_startpos;
      sip->si_h_endpos = CUR_STATE(idx - 1).si_h_endpos;
      if (sip->si_cont_list == NULL) {
        sip->si_flags |= HL_TRANS_CONT;
        sip->si_cont_list = CUR_STATE(idx - 1).si_cont_list;
      }
    }
  }
}

/*
 * Check the current stack for patterns with "keepend" flag.
 * Propagate the match-end to contained items, until a "skipend" item is found.
 */
static void check_keepend(void)
{
  int i;
  lpos_T maxpos;
  lpos_T maxpos_h;
  stateitem_T *sip;

  /*
   * This check can consume a lot of time; only do it from the level where
   * there really is a keepend.
   */
  if (keepend_level < 0)
    return;

  /*
   * Find the last index of an "extend" item.  "keepend" items before that
   * won't do anything.  If there is no "extend" item "i" will be
   * "keepend_level" and all "keepend" items will work normally.
   */
  for (i = current_state.ga_len - 1; i > keepend_level; --i)
    if (CUR_STATE(i).si_flags & HL_EXTEND)
      break;

  maxpos.lnum = 0;
  maxpos.col = 0;
  maxpos_h.lnum = 0;
  maxpos_h.col = 0;
  for (; i < current_state.ga_len; ++i) {
    sip = &CUR_STATE(i);
    if (maxpos.lnum != 0) {
      limit_pos_zero(&sip->si_m_endpos, &maxpos);
      limit_pos_zero(&sip->si_h_endpos, &maxpos_h);
      limit_pos_zero(&sip->si_eoe_pos, &maxpos);
      sip->si_ends = TRUE;
    }
    if (sip->si_ends && (sip->si_flags & HL_KEEPEND)) {
      if (maxpos.lnum == 0
          || maxpos.lnum > sip->si_m_endpos.lnum
          || (maxpos.lnum == sip->si_m_endpos.lnum
              && maxpos.col > sip->si_m_endpos.col))
        maxpos = sip->si_m_endpos;
      if (maxpos_h.lnum == 0
          || maxpos_h.lnum > sip->si_h_endpos.lnum
          || (maxpos_h.lnum == sip->si_h_endpos.lnum
              && maxpos_h.col > sip->si_h_endpos.col))
        maxpos_h = sip->si_h_endpos;
    }
  }
}

/*
 * Update an entry in the current_state stack for a start-skip-end pattern.
 * This finds the end of the current item, if it's in the current line.
 *
 * Return the flags for the matched END.
 */
static void
update_si_end(
    stateitem_T *sip,
    int startcol,               /* where to start searching for the end */
    int force                  /* when TRUE overrule a previous end */
)
{
  lpos_T startpos;
  lpos_T endpos;
  lpos_T hl_endpos;
  lpos_T end_endpos;
  int end_idx;

  /* return quickly for a keyword */
  if (sip->si_idx < 0)
    return;

  /* Don't update when it's already done.  Can be a match of an end pattern
   * that started in a previous line.  Watch out: can also be a "keepend"
   * from a containing item. */
  if (!force && sip->si_m_endpos.lnum >= current_lnum)
    return;

  /*
   * We need to find the end of the region.  It may continue in the next
   * line.
   */
  end_idx = 0;
  startpos.lnum = current_lnum;
  startpos.col = startcol;
  find_endpos(sip->si_idx, &startpos, &endpos, &hl_endpos,
      &(sip->si_flags), &end_endpos, &end_idx, sip->si_extmatch);

  if (endpos.lnum == 0) {
    /* No end pattern matched. */
    if (SYN_ITEMS(syn_block)[sip->si_idx].sp_flags & HL_ONELINE) {
      /* a "oneline" never continues in the next line */
      sip->si_ends = TRUE;
      sip->si_m_endpos.lnum = current_lnum;
      sip->si_m_endpos.col = (colnr_T)STRLEN(syn_getcurline());
    } else {
      /* continues in the next line */
      sip->si_ends = FALSE;
      sip->si_m_endpos.lnum = 0;
    }
    sip->si_h_endpos = sip->si_m_endpos;
  } else {
    /* match within this line */
    sip->si_m_endpos = endpos;
    sip->si_h_endpos = hl_endpos;
    sip->si_eoe_pos = end_endpos;
    sip->si_ends = TRUE;
    sip->si_end_idx = end_idx;
  }
}

/*
 * Add a new state to the current state stack.
 * It is cleared and the index set to "idx".
 */
static void push_current_state(int idx)
{
  stateitem_T *p = GA_APPEND_VIA_PTR(stateitem_T, &current_state);
  memset(p, 0, sizeof(*p));
  p->si_idx = idx;
}

/*
 * Remove a state from the current_state stack.
 */
static void pop_current_state(void)
{
  if (!GA_EMPTY(&current_state)) {
    unref_extmatch(CUR_STATE(current_state.ga_len - 1).si_extmatch);
    --current_state.ga_len;
  }
  /* after the end of a pattern, try matching a keyword or pattern */
  next_match_idx = -1;

  /* if first state with "keepend" is popped, reset keepend_level */
  if (keepend_level >= current_state.ga_len)
    keepend_level = -1;
}

/*
 * Find the end of a start/skip/end syntax region after "startpos".
 * Only checks one line.
 * Also handles a match item that continued from a previous line.
 * If not found, the syntax item continues in the next line.  m_endpos->lnum
 * will be 0.
 * If found, the end of the region and the end of the highlighting is
 * computed.
 */
static void
find_endpos(
    int idx,                    // index of the pattern
    lpos_T *startpos,           // where to start looking for an END match
    lpos_T *m_endpos,           // return: end of match
    lpos_T *hl_endpos,          // return: end of highlighting
    long *flagsp,               // return: flags of matching END
    lpos_T *end_endpos,         // return: end of end pattern match
    int *end_idx,               // return: group ID for end pat. match, or 0
    reg_extmatch_T *start_ext   // submatches from the start pattern
)
{
  colnr_T matchcol;
  synpat_T    *spp, *spp_skip;
  int start_idx;
  int best_idx;
  regmmatch_T regmatch;
  regmmatch_T best_regmatch;        /* startpos/endpos of best match */
  lpos_T pos;
  char_u      *line;
  int had_match = false;
  char_u buf_chartab[32];  // chartab array for syn option iskeyword

  /* just in case we are invoked for a keyword */
  if (idx < 0)
    return;

  /*
   * Check for being called with a START pattern.
   * Can happen with a match that continues to the next line, because it
   * contained a region.
   */
  spp = &(SYN_ITEMS(syn_block)[idx]);
  if (spp->sp_type != SPTYPE_START) {
    *hl_endpos = *startpos;
    return;
  }

  /*
   * Find the SKIP or first END pattern after the last START pattern.
   */
  for (;; ) {
    spp = &(SYN_ITEMS(syn_block)[idx]);
    if (spp->sp_type != SPTYPE_START)
      break;
    ++idx;
  }

  /*
   *	Lookup the SKIP pattern (if present)
   */
  if (spp->sp_type == SPTYPE_SKIP) {
    spp_skip = spp;
    ++idx;
  } else
    spp_skip = NULL;

  /* Setup external matches for syn_regexec(). */
  unref_extmatch(re_extmatch_in);
  re_extmatch_in = ref_extmatch(start_ext);

  matchcol = startpos->col;     // start looking for a match at sstart
  start_idx = idx;              // remember the first END pattern.
  best_regmatch.startpos[0].col = 0;            // avoid compiler warning

  // use syntax iskeyword option
  save_chartab(buf_chartab);

  for (;; ) {
    /*
     * Find end pattern that matches first after "matchcol".
     */
    best_idx = -1;
    for (idx = start_idx; idx < syn_block->b_syn_patterns.ga_len; ++idx) {
      int lc_col = matchcol;

      spp = &(SYN_ITEMS(syn_block)[idx]);
      if (spp->sp_type != SPTYPE_END)           /* past last END pattern */
        break;
      lc_col -= spp->sp_offsets[SPO_LC_OFF];
      if (lc_col < 0)
        lc_col = 0;

      regmatch.rmm_ic = spp->sp_ic;
      regmatch.regprog = spp->sp_prog;
      int r = syn_regexec(&regmatch, startpos->lnum, lc_col,
                          IF_SYN_TIME(&spp->sp_time));
      spp->sp_prog = regmatch.regprog;
      if (r) {
        if (best_idx == -1 || regmatch.startpos[0].col
            < best_regmatch.startpos[0].col) {
          best_idx = idx;
          best_regmatch.startpos[0] = regmatch.startpos[0];
          best_regmatch.endpos[0] = regmatch.endpos[0];
        }
      }
    }

    /*
     * If all end patterns have been tried, and there is no match, the
     * item continues until end-of-line.
     */
    if (best_idx == -1)
      break;

    /*
     * If the skip pattern matches before the end pattern,
     * continue searching after the skip pattern.
     */
    if (spp_skip != NULL) {
      int lc_col = matchcol - spp_skip->sp_offsets[SPO_LC_OFF];

      if (lc_col < 0)
        lc_col = 0;
      regmatch.rmm_ic = spp_skip->sp_ic;
      regmatch.regprog = spp_skip->sp_prog;
      int r = syn_regexec(&regmatch, startpos->lnum, lc_col,
                          IF_SYN_TIME(&spp_skip->sp_time));
      spp_skip->sp_prog = regmatch.regprog;
      if (r && regmatch.startpos[0].col <= best_regmatch.startpos[0].col) {
        // Add offset to skip pattern match
        syn_add_end_off(&pos, &regmatch, spp_skip, SPO_ME_OFF, 1);

        // If the skip pattern goes on to the next line, there is no
        // match with an end pattern in this line.
        if (pos.lnum > startpos->lnum) {
          break;
        }

        line = ml_get_buf(syn_buf, startpos->lnum, false);
        int line_len = (int)STRLEN(line);

        // take care of an empty match or negative offset
        if (pos.col <= matchcol) {
          matchcol++;
        } else if (pos.col <= regmatch.endpos[0].col) {
          matchcol = pos.col;
        } else {
          // Be careful not to jump over the NUL at the end-of-line
          for (matchcol = regmatch.endpos[0].col;
               matchcol < line_len && matchcol < pos.col;
               matchcol++) {
          }
        }

        // if the skip pattern includes end-of-line, break here
        if (matchcol >= line_len) {
          break;
        }

        continue;  // start with first end pattern again
      }
    }

    /*
     * Match from start pattern to end pattern.
     * Correct for match and highlight offset of end pattern.
     */
    spp = &(SYN_ITEMS(syn_block)[best_idx]);
    syn_add_end_off(m_endpos, &best_regmatch, spp, SPO_ME_OFF, 1);
    /* can't end before the start */
    if (m_endpos->lnum == startpos->lnum && m_endpos->col < startpos->col)
      m_endpos->col = startpos->col;

    syn_add_end_off(end_endpos, &best_regmatch, spp, SPO_HE_OFF, 1);
    /* can't end before the start */
    if (end_endpos->lnum == startpos->lnum
        && end_endpos->col < startpos->col)
      end_endpos->col = startpos->col;
    /* can't end after the match */
    limit_pos(end_endpos, m_endpos);

    /*
     * If the end group is highlighted differently, adjust the pointers.
     */
    if (spp->sp_syn_match_id != spp->sp_syn.id && spp->sp_syn_match_id != 0) {
      *end_idx = best_idx;
      if (spp->sp_off_flags & (1 << (SPO_RE_OFF + SPO_COUNT))) {
        hl_endpos->lnum = best_regmatch.endpos[0].lnum;
        hl_endpos->col = best_regmatch.endpos[0].col;
      } else {
        hl_endpos->lnum = best_regmatch.startpos[0].lnum;
        hl_endpos->col = best_regmatch.startpos[0].col;
      }
      hl_endpos->col += spp->sp_offsets[SPO_RE_OFF];

      /* can't end before the start */
      if (hl_endpos->lnum == startpos->lnum
          && hl_endpos->col < startpos->col)
        hl_endpos->col = startpos->col;
      limit_pos(hl_endpos, m_endpos);

      /* now the match ends where the highlighting ends, it is turned
       * into the matchgroup for the end */
      *m_endpos = *hl_endpos;
    } else {
      *end_idx = 0;
      *hl_endpos = *end_endpos;
    }

    *flagsp = spp->sp_flags;

    had_match = TRUE;
    break;
  }

  /* no match for an END pattern in this line */
  if (!had_match)
    m_endpos->lnum = 0;

  restore_chartab(buf_chartab);

  /* Remove external matches. */
  unref_extmatch(re_extmatch_in);
  re_extmatch_in = NULL;
}

/*
 * Limit "pos" not to be after "limit".
 */
static void limit_pos(lpos_T *pos, lpos_T *limit)
{
  if (pos->lnum > limit->lnum)
    *pos = *limit;
  else if (pos->lnum == limit->lnum && pos->col > limit->col)
    pos->col = limit->col;
}

/*
 * Limit "pos" not to be after "limit", unless pos->lnum is zero.
 */
static void limit_pos_zero(lpos_T *pos, lpos_T *limit)
{
  if (pos->lnum == 0)
    *pos = *limit;
  else
    limit_pos(pos, limit);
}

/*
 * Add offset to matched text for end of match or highlight.
 */
static void
syn_add_end_off(
    lpos_T *result,           // returned position
    regmmatch_T *regmatch,    // start/end of match
    synpat_T *spp,            // matched pattern
    int idx,                  // index of offset
    int extra                 // extra chars for offset to start
)
{
  int col;
  int off;
  char_u      *base;
  char_u      *p;

  if (spp->sp_off_flags & (1 << idx)) {
    result->lnum = regmatch->startpos[0].lnum;
    col = regmatch->startpos[0].col;
    off = spp->sp_offsets[idx] + extra;
  } else {
    result->lnum = regmatch->endpos[0].lnum;
    col = regmatch->endpos[0].col;
    off = spp->sp_offsets[idx];
  }
  /* Don't go past the end of the line.  Matters for "rs=e+2" when there
   * is a matchgroup. Watch out for match with last NL in the buffer. */
  if (result->lnum > syn_buf->b_ml.ml_line_count)
    col = 0;
  else if (off != 0) {
    base = ml_get_buf(syn_buf, result->lnum, FALSE);
    p = base + col;
    if (off > 0) {
      while (off-- > 0 && *p != NUL) {
        MB_PTR_ADV(p);
      }
    } else {
      while (off++ < 0 && base < p) {
        MB_PTR_BACK(base, p);
      }
    }
    col = (int)(p - base);
  }
  result->col = col;
}

/*
 * Add offset to matched text for start of match or highlight.
 * Avoid resulting column to become negative.
 */
static void
syn_add_start_off(
    lpos_T *result,           // returned position
    regmmatch_T *regmatch,    // start/end of match
    synpat_T *spp,
    int idx,
    int extra                 // extra chars for offset to end
)
{
  int col;
  int off;
  char_u      *base;
  char_u      *p;

  if (spp->sp_off_flags & (1 << (idx + SPO_COUNT))) {
    result->lnum = regmatch->endpos[0].lnum;
    col = regmatch->endpos[0].col;
    off = spp->sp_offsets[idx] + extra;
  } else {
    result->lnum = regmatch->startpos[0].lnum;
    col = regmatch->startpos[0].col;
    off = spp->sp_offsets[idx];
  }
  if (result->lnum > syn_buf->b_ml.ml_line_count) {
    /* a "\n" at the end of the pattern may take us below the last line */
    result->lnum = syn_buf->b_ml.ml_line_count;
    col = (int)STRLEN(ml_get_buf(syn_buf, result->lnum, FALSE));
  }
  if (off != 0) {
    base = ml_get_buf(syn_buf, result->lnum, FALSE);
    p = base + col;
    if (off > 0) {
      while (off-- && *p != NUL) {
        MB_PTR_ADV(p);
      }
    } else {
      while (off++ && base < p) {
        MB_PTR_BACK(base, p);
      }
    }
    col = (int)(p - base);
  }
  result->col = col;
}

/*
 * Get current line in syntax buffer.
 */
static char_u *syn_getcurline(void)
{
  return ml_get_buf(syn_buf, current_lnum, FALSE);
}

/*
 * Call vim_regexec() to find a match with "rmp" in "syn_buf".
 * Returns TRUE when there is a match.
 */
static int syn_regexec(regmmatch_T *rmp, linenr_T lnum, colnr_T col, syn_time_T *st)
{
  int r;
  int timed_out = 0;
  proftime_T pt;
  const int l_syn_time_on = syn_time_on;

  if (l_syn_time_on) {
    pt = profile_start();
  }

  if (rmp->regprog == NULL) {
    // This can happen if a previous call to vim_regexec_multi() tried to
    // use the NFA engine, which resulted in NFA_TOO_EXPENSIVE, and
    // compiling the pattern with the other engine fails.
    return false;
  }

  rmp->rmm_maxcol = syn_buf->b_p_smc;
  r = vim_regexec_multi(rmp, syn_win, syn_buf, lnum, col,
                        syn_tm, &timed_out);

  if (l_syn_time_on) {
    pt = profile_end(pt);
    st->total = profile_add(st->total, pt);
    if (profile_cmp(pt, st->slowest) < 0) {
      st->slowest = pt;
    }
    ++st->count;
    if (r > 0)
      ++st->match;
  }
  if (timed_out && !syn_win->w_s->b_syn_slow) {
    syn_win->w_s->b_syn_slow = true;
    MSG(_("'redrawtime' exceeded, syntax highlighting disabled"));
  }

  if (r > 0) {
    rmp->startpos[0].lnum += lnum;
    rmp->endpos[0].lnum += lnum;
    return TRUE;
  }
  return FALSE;
}

/*
 * Check one position in a line for a matching keyword.
 * The caller must check if a keyword can start at startcol.
 * Return its ID if found, 0 otherwise.
 */
static int check_keyword_id(
    char_u *const line,
    const int startcol,           // position in line to check for keyword
    int *const endcolp,           // return: character after found keyword
    long *const flagsp,           // return: flags of matching keyword
    int16_t **const next_listp,   // return: next_list of matching keyword
    stateitem_T *const cur_si,    // item at the top of the stack
    int *const ccharp             // conceal substitution char
)
{
  // Find first character after the keyword.  First character was already
  // checked.
  char_u *const kwp = line + startcol;
  int kwlen = 0;
  do {
    if (has_mbyte) {
      kwlen += (*mb_ptr2len)(kwp + kwlen);
    } else {
      kwlen++;
    }
  } while (vim_iswordp_buf(kwp + kwlen, syn_buf));

  if (kwlen > MAXKEYWLEN) {
    return 0;
  }

  // Must make a copy of the keyword, so we can add a NUL and make it
  // lowercase.
  char_u keyword[MAXKEYWLEN + 1];         // assume max. keyword len is 80
  STRLCPY(keyword, kwp, kwlen + 1);

  keyentry_T *kp = NULL;

  // matching case
  if (syn_block->b_keywtab.ht_used != 0) {
    kp = match_keyword(keyword, &syn_block->b_keywtab, cur_si);
  }

  // ignoring case
  if (kp == NULL && syn_block->b_keywtab_ic.ht_used != 0) {
    str_foldcase(kwp, kwlen, keyword, MAXKEYWLEN + 1);
    kp = match_keyword(keyword, &syn_block->b_keywtab_ic, cur_si);
  }

  if (kp != NULL) {
    *endcolp = startcol + kwlen;
    *flagsp = kp->flags;
    *next_listp = kp->next_list;
    *ccharp = kp->k_char;
    return kp->k_syn.id;
  }

  return 0;
}

/// Find keywords that match.  There can be several with different
/// attributes.
/// When current_next_list is non-zero accept only that group, otherwise:
///  Accept a not-contained keyword at toplevel.
///  Accept a keyword at other levels only if it is in the contains list.
static keyentry_T *match_keyword(char_u *keyword, hashtab_T *ht,
                                 stateitem_T *cur_si)
{
  hashitem_T *hi = hash_find(ht, keyword);
  if (!HASHITEM_EMPTY(hi))
    for (keyentry_T *kp = HI2KE(hi); kp != NULL; kp = kp->ke_next) {
      if (current_next_list != 0
          ? in_id_list(NULL, current_next_list, &kp->k_syn, 0)
          : (cur_si == NULL
            ? !(kp->flags & HL_CONTAINED)
            : in_id_list(cur_si, cur_si->si_cont_list,
                         &kp->k_syn, kp->flags & HL_CONTAINED))) {
        return kp;
      }
    }
  return NULL;
}

/*
 * Handle ":syntax conceal" command.
 */
static void syn_cmd_conceal(exarg_T *eap, int syncing)
{
  char_u      *arg = eap->arg;
  char_u      *next;

  eap->nextcmd = find_nextcmd(arg);
  if (eap->skip)
    return;

  next = skiptowhite(arg);
  if (*arg == NUL) {
    if (curwin->w_s->b_syn_conceal) {
      MSG(_("syntax conceal on"));
    } else {
      MSG(_("syntax conceal off"));
    }
  } else if (STRNICMP(arg, "on", 2) == 0 && next - arg == 2) {
    curwin->w_s->b_syn_conceal = true;
  } else if (STRNICMP(arg, "off", 3) == 0 && next - arg == 3) {
    curwin->w_s->b_syn_conceal = false;
  } else {
    EMSG2(_("E390: Illegal argument: %s"), arg);
  }
}

/*
 * Handle ":syntax case" command.
 */
static void syn_cmd_case(exarg_T *eap, int syncing)
{
  char_u      *arg = eap->arg;
  char_u      *next;

  eap->nextcmd = find_nextcmd(arg);
  if (eap->skip)
    return;

  next = skiptowhite(arg);
  if (*arg == NUL) {
    if (curwin->w_s->b_syn_ic) {
      MSG(_("syntax case ignore"));
    } else {
      MSG(_("syntax case match"));
    }
  } else if (STRNICMP(arg, "match", 5) == 0 && next - arg == 5) {
    curwin->w_s->b_syn_ic = false;
  } else if (STRNICMP(arg, "ignore", 6) == 0 && next - arg == 6) {
    curwin->w_s->b_syn_ic = true;
  } else {
    EMSG2(_("E390: Illegal argument: %s"), arg);
  }
}

/*
 * Handle ":syntax spell" command.
 */
static void syn_cmd_spell(exarg_T *eap, int syncing)
{
  char_u      *arg = eap->arg;
  char_u      *next;

  eap->nextcmd = find_nextcmd(arg);
  if (eap->skip)
    return;

  next = skiptowhite(arg);
  if (*arg == NUL) {
    if (curwin->w_s->b_syn_spell == SYNSPL_TOP) {
      MSG(_("syntax spell toplevel"));
    } else if (curwin->w_s->b_syn_spell == SYNSPL_NOTOP) {
      MSG(_("syntax spell notoplevel"));
    } else {
      MSG(_("syntax spell default"));
    }
  } else if (STRNICMP(arg, "toplevel", 8) == 0 && next - arg == 8) {
    curwin->w_s->b_syn_spell = SYNSPL_TOP;
  } else if (STRNICMP(arg, "notoplevel", 10) == 0 && next - arg == 10) {
    curwin->w_s->b_syn_spell = SYNSPL_NOTOP;
  } else if (STRNICMP(arg, "default", 7) == 0 && next - arg == 7) {
    curwin->w_s->b_syn_spell = SYNSPL_DEFAULT;
  } else {
    EMSG2(_("E390: Illegal argument: %s"), arg);
    return;
  }

  // assume spell checking changed, force a redraw
  redraw_win_later(curwin, NOT_VALID);
}

/// Handle ":syntax iskeyword" command.
static void syn_cmd_iskeyword(exarg_T *eap, int syncing)
{
  char_u *arg = eap->arg;
  char_u save_chartab[32];
  char_u *save_isk;

  if (eap->skip) {
    return;
  }

  arg = skipwhite(arg);
  if (*arg == NUL) {
    MSG_PUTS("\n");
    if (curwin->w_s->b_syn_isk != empty_option) {
      MSG_PUTS(_("syntax iskeyword "));
      msg_outtrans(curwin->w_s->b_syn_isk);
    } else {
      msg_outtrans((char_u *)_("syntax iskeyword not set"));
    }
  } else {
    if (STRNICMP(arg, "clear", 5) == 0) {
      memmove(curwin->w_s->b_syn_chartab, curbuf->b_chartab, (size_t)32);
      clear_string_option(&curwin->w_s->b_syn_isk);
    } else {
      memmove(save_chartab, curbuf->b_chartab, (size_t)32);
      save_isk = curbuf->b_p_isk;
      curbuf->b_p_isk = vim_strsave(arg);

      buf_init_chartab(curbuf, false);
      memmove(curwin->w_s->b_syn_chartab, curbuf->b_chartab, (size_t)32);
      memmove(curbuf->b_chartab, save_chartab, (size_t)32);
      clear_string_option(&curwin->w_s->b_syn_isk);
      curwin->w_s->b_syn_isk = curbuf->b_p_isk;
      curbuf->b_p_isk = save_isk;
    }
  }
  redraw_win_later(curwin, NOT_VALID);
}

/*
 * Clear all syntax info for one buffer.
 */
void syntax_clear(synblock_T *block)
{
  block->b_syn_error = false;           // clear previous error
  block->b_syn_slow = false;            // clear previous timeout
  block->b_syn_ic = false;              // Use case, by default
  block->b_syn_spell = SYNSPL_DEFAULT;  // default spell checking
  block->b_syn_containedin = false;
  block->b_syn_conceal = false;

  /* free the keywords */
  clear_keywtab(&block->b_keywtab);
  clear_keywtab(&block->b_keywtab_ic);

  /* free the syntax patterns */
  for (int i = block->b_syn_patterns.ga_len; --i >= 0; ) {
    syn_clear_pattern(block, i);
  }
  ga_clear(&block->b_syn_patterns);

  /* free the syntax clusters */
  for (int i = block->b_syn_clusters.ga_len; --i >= 0; ) {
    syn_clear_cluster(block, i);
  }
  ga_clear(&block->b_syn_clusters);
  block->b_spell_cluster_id = 0;
  block->b_nospell_cluster_id = 0;

  block->b_syn_sync_flags = 0;
  block->b_syn_sync_minlines = 0;
  block->b_syn_sync_maxlines = 0;
  block->b_syn_sync_linebreaks = 0;

  vim_regfree(block->b_syn_linecont_prog);
  block->b_syn_linecont_prog = NULL;
  XFREE_CLEAR(block->b_syn_linecont_pat);
  block->b_syn_folditems = 0;
  clear_string_option(&block->b_syn_isk);

  /* free the stored states */
  syn_stack_free_all(block);
  invalidate_current_state();

  /* Reset the counter for ":syn include" */
  running_syn_inc_tag = 0;
}

/*
 * Get rid of ownsyntax for window "wp".
 */
void reset_synblock(win_T *wp)
{
  if (wp->w_s != &wp->w_buffer->b_s) {
    syntax_clear(wp->w_s);
    xfree(wp->w_s);
    wp->w_s = &wp->w_buffer->b_s;
  }
}

/*
 * Clear syncing info for one buffer.
 */
static void syntax_sync_clear(void)
{
  /* free the syntax patterns */
  for (int i = curwin->w_s->b_syn_patterns.ga_len; --i >= 0; ) {
    if (SYN_ITEMS(curwin->w_s)[i].sp_syncing) {
      syn_remove_pattern(curwin->w_s, i);
    }
  }

  curwin->w_s->b_syn_sync_flags = 0;
  curwin->w_s->b_syn_sync_minlines = 0;
  curwin->w_s->b_syn_sync_maxlines = 0;
  curwin->w_s->b_syn_sync_linebreaks = 0;

  vim_regfree(curwin->w_s->b_syn_linecont_prog);
  curwin->w_s->b_syn_linecont_prog = NULL;
  XFREE_CLEAR(curwin->w_s->b_syn_linecont_pat);
  clear_string_option(&curwin->w_s->b_syn_isk);

  syn_stack_free_all(curwin->w_s);              /* Need to recompute all syntax. */
}

/*
 * Remove one pattern from the buffer's pattern list.
 */
static void syn_remove_pattern(synblock_T *block, int idx)
{
  synpat_T    *spp;

  spp = &(SYN_ITEMS(block)[idx]);
  if (spp->sp_flags & HL_FOLD)
    --block->b_syn_folditems;
  syn_clear_pattern(block, idx);
  memmove(spp, spp + 1,
      sizeof(synpat_T) * (block->b_syn_patterns.ga_len - idx - 1));
  --block->b_syn_patterns.ga_len;
}

/*
 * Clear and free one syntax pattern.  When clearing all, must be called from
 * last to first!
 */
static void syn_clear_pattern(synblock_T *block, int i)
{
  xfree(SYN_ITEMS(block)[i].sp_pattern);
  vim_regfree(SYN_ITEMS(block)[i].sp_prog);
  /* Only free sp_cont_list and sp_next_list of first start pattern */
  if (i == 0 || SYN_ITEMS(block)[i - 1].sp_type != SPTYPE_START) {
    xfree(SYN_ITEMS(block)[i].sp_cont_list);
    xfree(SYN_ITEMS(block)[i].sp_next_list);
    xfree(SYN_ITEMS(block)[i].sp_syn.cont_in_list);
  }
}

/*
 * Clear and free one syntax cluster.
 */
static void syn_clear_cluster(synblock_T *block, int i)
{
  xfree(SYN_CLSTR(block)[i].scl_name);
  xfree(SYN_CLSTR(block)[i].scl_name_u);
  xfree(SYN_CLSTR(block)[i].scl_list);
}

/*
 * Handle ":syntax clear" command.
 */
static void syn_cmd_clear(exarg_T *eap, int syncing)
{
  char_u      *arg = eap->arg;
  char_u      *arg_end;
  int id;

  eap->nextcmd = find_nextcmd(arg);
  if (eap->skip)
    return;

  /*
   * We have to disable this within ":syn include @group filename",
   * because otherwise @group would get deleted.
   * Only required for Vim 5.x syntax files, 6.0 ones don't contain ":syn
   * clear".
   */
  if (curwin->w_s->b_syn_topgrp != 0)
    return;

  if (ends_excmd(*arg)) {
    /*
     * No argument: Clear all syntax items.
     */
    if (syncing)
      syntax_sync_clear();
    else {
      syntax_clear(curwin->w_s);
      if (curwin->w_s == &curwin->w_buffer->b_s) {
        do_unlet(S_LEN("b:current_syntax"), true);
      }
      do_unlet(S_LEN("w:current_syntax"), true);
    }
  } else {
    /*
     * Clear the group IDs that are in the argument.
     */
    while (!ends_excmd(*arg)) {
      arg_end = skiptowhite(arg);
      if (*arg == '@') {
        id = syn_scl_namen2id(arg + 1, (int)(arg_end - arg - 1));
        if (id == 0) {
          EMSG2(_("E391: No such syntax cluster: %s"), arg);
          break;
        } else {
          // We can't physically delete a cluster without changing
          // the IDs of other clusters, so we do the next best thing
          // and make it empty.
          int scl_id = id - SYNID_CLUSTER;

          XFREE_CLEAR(SYN_CLSTR(curwin->w_s)[scl_id].scl_list);
        }
      } else {
        id = syn_namen2id(arg, (int)(arg_end - arg));
        if (id == 0) {
          EMSG2(_(e_nogroup), arg);
          break;
        } else
          syn_clear_one(id, syncing);
      }
      arg = skipwhite(arg_end);
    }
  }
  redraw_curbuf_later(SOME_VALID);
  syn_stack_free_all(curwin->w_s);              /* Need to recompute all syntax. */
}

/*
 * Clear one syntax group for the current buffer.
 */
static void syn_clear_one(const int id, const bool syncing)
{
  synpat_T    *spp;

  /* Clear keywords only when not ":syn sync clear group-name" */
  if (!syncing) {
    syn_clear_keyword(id, &curwin->w_s->b_keywtab);
    syn_clear_keyword(id, &curwin->w_s->b_keywtab_ic);
  }

  /* clear the patterns for "id" */
  for (int idx = curwin->w_s->b_syn_patterns.ga_len; --idx >= 0; ) {
    spp = &(SYN_ITEMS(curwin->w_s)[idx]);
    if (spp->sp_syn.id != id || spp->sp_syncing != syncing)
      continue;
    syn_remove_pattern(curwin->w_s, idx);
  }
}

/*
 * Handle ":syntax on" command.
 */
static void syn_cmd_on(exarg_T *eap, int syncing)
{
  syn_cmd_onoff(eap, "syntax");
}

/*
 * Handle ":syntax enable" command.
 */
static void syn_cmd_enable(exarg_T *eap, int syncing)
{
  set_internal_string_var((char_u *)"syntax_cmd", (char_u *)"enable");
  syn_cmd_onoff(eap, "syntax");
  do_unlet(S_LEN("g:syntax_cmd"), true);
}

/*
 * Handle ":syntax reset" command.
 * It actually resets highlighting, not syntax.
 */
static void syn_cmd_reset(exarg_T *eap, int syncing)
{
  eap->nextcmd = check_nextcmd(eap->arg);
  if (!eap->skip) {
    set_internal_string_var((char_u *)"syntax_cmd", (char_u *)"reset");
    do_cmdline_cmd("runtime! syntax/syncolor.vim");
    do_unlet(S_LEN("g:syntax_cmd"), true);
  }
}

/*
 * Handle ":syntax manual" command.
 */
static void syn_cmd_manual(exarg_T *eap, int syncing)
{
  syn_cmd_onoff(eap, "manual");
}

/*
 * Handle ":syntax off" command.
 */
static void syn_cmd_off(exarg_T *eap, int syncing)
{
  syn_cmd_onoff(eap, "nosyntax");
}

static void syn_cmd_onoff(exarg_T *eap, char *name)
  FUNC_ATTR_NONNULL_ALL
{
  eap->nextcmd = check_nextcmd(eap->arg);
  if (!eap->skip) {
    did_syntax_onoff = true;
    char buf[100];
    memcpy(buf, "so ", 4);
    vim_snprintf(buf + 3, sizeof(buf) - 3, SYNTAX_FNAME, name);
    do_cmdline_cmd(buf);
  }
}

void syn_maybe_on(void)
{
  if (!did_syntax_onoff) {
    exarg_T ea;
    ea.arg = (char_u *)"";
    ea.skip = false;
    syn_cmd_onoff(&ea, "syntax");
  }
}

/*
 * Handle ":syntax [list]" command: list current syntax words.
 */
static void
syn_cmd_list(
    exarg_T *eap,
    int syncing                        /* when TRUE: list syncing items */
)
{
  char_u      *arg = eap->arg;
  char_u      *arg_end;

  eap->nextcmd = find_nextcmd(arg);
  if (eap->skip)
    return;

  if (!syntax_present(curwin)) {
    MSG(_(msg_no_items));
    return;
  }

  if (syncing) {
    if (curwin->w_s->b_syn_sync_flags & SF_CCOMMENT) {
      MSG_PUTS(_("syncing on C-style comments"));
      syn_lines_msg();
      syn_match_msg();
      return;
    } else if (!(curwin->w_s->b_syn_sync_flags & SF_MATCH))   {
      if (curwin->w_s->b_syn_sync_minlines == 0)
        MSG_PUTS(_("no syncing"));
      else {
        MSG_PUTS(_("syncing starts "));
        msg_outnum(curwin->w_s->b_syn_sync_minlines);
        MSG_PUTS(_(" lines before top line"));
        syn_match_msg();
      }
      return;
    }
    MSG_PUTS_TITLE(_("\n--- Syntax sync items ---"));
    if (curwin->w_s->b_syn_sync_minlines > 0
        || curwin->w_s->b_syn_sync_maxlines > 0
        || curwin->w_s->b_syn_sync_linebreaks > 0) {
      MSG_PUTS(_("\nsyncing on items"));
      syn_lines_msg();
      syn_match_msg();
    }
  } else
    MSG_PUTS_TITLE(_("\n--- Syntax items ---"));
  if (ends_excmd(*arg)) {
    /*
     * No argument: List all group IDs and all syntax clusters.
     */
    for (int id = 1; id <= highlight_ga.ga_len && !got_int; id++) {
      syn_list_one(id, syncing, false);
    }
    for (int id = 0; id < curwin->w_s->b_syn_clusters.ga_len && !got_int; ++id) {
      syn_list_cluster(id);
    }
  } else {
    /*
     * List the group IDs and syntax clusters that are in the argument.
     */
    while (!ends_excmd(*arg) && !got_int) {
      arg_end = skiptowhite(arg);
      if (*arg == '@') {
        int id = syn_scl_namen2id(arg + 1, (int)(arg_end - arg - 1));
        if (id == 0)
          EMSG2(_("E392: No such syntax cluster: %s"), arg);
        else
          syn_list_cluster(id - SYNID_CLUSTER);
      } else {
        int id = syn_namen2id(arg, (int)(arg_end - arg));
        if (id == 0) {
          EMSG2(_(e_nogroup), arg);
        } else {
          syn_list_one(id, syncing, true);
        }
      }
      arg = skipwhite(arg_end);
    }
  }
  eap->nextcmd = check_nextcmd(arg);
}

static void syn_lines_msg(void)
{
  if (curwin->w_s->b_syn_sync_maxlines > 0
      || curwin->w_s->b_syn_sync_minlines > 0) {
    MSG_PUTS("; ");
    if (curwin->w_s->b_syn_sync_minlines > 0) {
      MSG_PUTS(_("minimal "));
      msg_outnum(curwin->w_s->b_syn_sync_minlines);
      if (curwin->w_s->b_syn_sync_maxlines)
        MSG_PUTS(", ");
    }
    if (curwin->w_s->b_syn_sync_maxlines > 0) {
      MSG_PUTS(_("maximal "));
      msg_outnum(curwin->w_s->b_syn_sync_maxlines);
    }
    MSG_PUTS(_(" lines before top line"));
  }
}

static void syn_match_msg(void)
{
  if (curwin->w_s->b_syn_sync_linebreaks > 0) {
    MSG_PUTS(_("; match "));
    msg_outnum(curwin->w_s->b_syn_sync_linebreaks);
    MSG_PUTS(_(" line breaks"));
  }
}

static int last_matchgroup;


/*
 * List one syntax item, for ":syntax" or "syntax list syntax_name".
 */
static void
syn_list_one(
    const int id,
    const bool syncing,                 // when true: list syncing items
    const bool link_only                // when true; list link-only too
)
{
  bool did_header = false;
  static struct name_list namelist1[] =
  {
    {HL_DISPLAY, "display"},
    {HL_CONTAINED, "contained"},
    {HL_ONELINE, "oneline"},
    {HL_KEEPEND, "keepend"},
    {HL_EXTEND, "extend"},
    {HL_EXCLUDENL, "excludenl"},
    {HL_TRANSP, "transparent"},
    {HL_FOLD, "fold"},
    {HL_CONCEAL, "conceal"},
    {HL_CONCEALENDS, "concealends"},
    {0, NULL}
  };
  static struct name_list namelist2[] =
  {
    {HL_SKIPWHITE, "skipwhite"},
    {HL_SKIPNL, "skipnl"},
    {HL_SKIPEMPTY, "skipempty"},
    {0, NULL}
  };

  const int attr = HL_ATTR(HLF_D);      // highlight like directories

  // list the keywords for "id"
  if (!syncing) {
    did_header = syn_list_keywords(id, &curwin->w_s->b_keywtab, false, attr);
    did_header = syn_list_keywords(id, &curwin->w_s->b_keywtab_ic,
                                   did_header, attr);
  }

  // list the patterns for "id"
  for (int idx = 0;
       idx < curwin->w_s->b_syn_patterns.ga_len && !got_int;
       idx++) {
    const synpat_T *const spp = &(SYN_ITEMS(curwin->w_s)[idx]);
    if (spp->sp_syn.id != id || spp->sp_syncing != syncing) {
      continue;
    }

    (void)syn_list_header(did_header, 0, id, true);
    did_header = true;
    last_matchgroup = 0;
    if (spp->sp_type == SPTYPE_MATCH) {
      put_pattern("match", ' ', spp, attr);
      msg_putchar(' ');
    } else if (spp->sp_type == SPTYPE_START)   {
      while (SYN_ITEMS(curwin->w_s)[idx].sp_type == SPTYPE_START)
        put_pattern("start", '=', &SYN_ITEMS(curwin->w_s)[idx++], attr);
      if (SYN_ITEMS(curwin->w_s)[idx].sp_type == SPTYPE_SKIP)
        put_pattern("skip", '=', &SYN_ITEMS(curwin->w_s)[idx++], attr);
      while (idx < curwin->w_s->b_syn_patterns.ga_len
             && SYN_ITEMS(curwin->w_s)[idx].sp_type == SPTYPE_END)
        put_pattern("end", '=', &SYN_ITEMS(curwin->w_s)[idx++], attr);
      --idx;
      msg_putchar(' ');
    }
    syn_list_flags(namelist1, spp->sp_flags, attr);

    if (spp->sp_cont_list != NULL) {
      put_id_list("contains", spp->sp_cont_list, attr);
    }

    if (spp->sp_syn.cont_in_list != NULL) {
      put_id_list("containedin", spp->sp_syn.cont_in_list, attr);
    }

    if (spp->sp_next_list != NULL) {
      put_id_list("nextgroup", spp->sp_next_list, attr);
      syn_list_flags(namelist2, spp->sp_flags, attr);
    }
    if (spp->sp_flags & (HL_SYNC_HERE|HL_SYNC_THERE)) {
      if (spp->sp_flags & HL_SYNC_HERE) {
        msg_puts_attr("grouphere", attr);
      } else {
        msg_puts_attr("groupthere", attr);
      }
      msg_putchar(' ');
      if (spp->sp_sync_idx >= 0)
        msg_outtrans(HL_TABLE()[SYN_ITEMS(curwin->w_s)
                                [spp->sp_sync_idx].sp_syn.id - 1].sg_name);
      else
        MSG_PUTS("NONE");
      msg_putchar(' ');
    }
  }

  /* list the link, if there is one */
  if (HL_TABLE()[id - 1].sg_link && (did_header || link_only) && !got_int) {
    (void)syn_list_header(did_header, 0, id, true);
    msg_puts_attr("links to", attr);
    msg_putchar(' ');
    msg_outtrans(HL_TABLE()[HL_TABLE()[id - 1].sg_link - 1].sg_name);
  }
}

static void syn_list_flags(struct name_list *nlist, int flags, int attr)
{
  int i;

  for (i = 0; nlist[i].flag != 0; ++i)
    if (flags & nlist[i].flag) {
      msg_puts_attr(nlist[i].name, attr);
      msg_putchar(' ');
    }
}

/*
 * List one syntax cluster, for ":syntax" or "syntax list syntax_name".
 */
static void syn_list_cluster(int id)
{
  int endcol = 15;

  /* slight hack:  roughly duplicate the guts of syn_list_header() */
  msg_putchar('\n');
  msg_outtrans(SYN_CLSTR(curwin->w_s)[id].scl_name);

  if (msg_col >= endcol)        /* output at least one space */
    endcol = msg_col + 1;
  if (Columns <= endcol)        /* avoid hang for tiny window */
    endcol = Columns - 1;

  msg_advance(endcol);
  if (SYN_CLSTR(curwin->w_s)[id].scl_list != NULL) {
    put_id_list("cluster", SYN_CLSTR(curwin->w_s)[id].scl_list, HL_ATTR(HLF_D));
  } else {
    msg_puts_attr("cluster", HL_ATTR(HLF_D));
    msg_puts("=NONE");
  }
}

static void put_id_list(const char *const name,
                        const int16_t *const list,
                        const int attr)
{
  msg_puts_attr(name, attr);
  msg_putchar('=');
  for (const int16_t *p = list; *p; p++) {
    if (*p >= SYNID_ALLBUT && *p < SYNID_TOP) {
      if (p[1]) {
        msg_puts("ALLBUT");
      } else {
        msg_puts("ALL");
      }
    } else if (*p >= SYNID_TOP && *p < SYNID_CONTAINED)   {
      msg_puts("TOP");
    } else if (*p >= SYNID_CONTAINED && *p < SYNID_CLUSTER)   {
      msg_puts("CONTAINED");
    } else if (*p >= SYNID_CLUSTER)   {
      int scl_id = *p - SYNID_CLUSTER;

      msg_putchar('@');
      msg_outtrans(SYN_CLSTR(curwin->w_s)[scl_id].scl_name);
    } else
      msg_outtrans(HL_TABLE()[*p - 1].sg_name);
    if (p[1])
      msg_putchar(',');
  }
  msg_putchar(' ');
}

static void put_pattern(const char *const s, const int c,
                        const synpat_T *const spp, const int attr)
{
  static const char *const sepchars = "/+=-#@\"|'^&";
  int i;

  /* May have to write "matchgroup=group" */
  if (last_matchgroup != spp->sp_syn_match_id) {
    last_matchgroup = spp->sp_syn_match_id;
    msg_puts_attr("matchgroup", attr);
    msg_putchar('=');
    if (last_matchgroup == 0)
      msg_outtrans((char_u *)"NONE");
    else
      msg_outtrans(HL_TABLE()[last_matchgroup - 1].sg_name);
    msg_putchar(' ');
  }

  // Output the name of the pattern and an '=' or ' '.
  msg_puts_attr(s, attr);
  msg_putchar(c);

  /* output the pattern, in between a char that is not in the pattern */
  for (i = 0; vim_strchr(spp->sp_pattern, sepchars[i]) != NULL; )
    if (sepchars[++i] == NUL) {
      i = 0;            /* no good char found, just use the first one */
      break;
    }
  msg_putchar(sepchars[i]);
  msg_outtrans(spp->sp_pattern);
  msg_putchar(sepchars[i]);

  // output any pattern options
  bool first = true;
  for (i = 0; i < SPO_COUNT; i++) {
    const int mask = (1 << i);
    if (!(spp->sp_off_flags & (mask + (mask << SPO_COUNT)))) {
      continue;
    }
    if (!first) {
      msg_putchar(',');  // Separate with commas.
    }
    msg_puts(spo_name_tab[i]);
    const long n = spp->sp_offsets[i];
    if (i != SPO_LC_OFF) {
      if (spp->sp_off_flags & mask)
        msg_putchar('s');
      else
        msg_putchar('e');
      if (n > 0)
        msg_putchar('+');
    }
    if (n || i == SPO_LC_OFF) {
      msg_outnum(n);
    }
    first = false;
  }
  msg_putchar(' ');
}

// List or clear the keywords for one syntax group.
// Return true if the header has been printed.
static bool syn_list_keywords(
    const int id,
    const hashtab_T *const ht,
    bool did_header,                        // header has already been printed
    const int attr
)
{
  int prev_contained = 0;
  const int16_t *prev_next_list = NULL;
  const int16_t *prev_cont_in_list = NULL;
  int prev_skipnl = 0;
  int prev_skipwhite = 0;
  int prev_skipempty = 0;

  // Unfortunately, this list of keywords is not sorted on alphabet but on
  // hash value...
  size_t todo = ht->ht_used;
  for (const hashitem_T *hi = ht->ht_array; todo > 0 && !got_int; hi++) {
    if (HASHITEM_EMPTY(hi)) {
      continue;
    }
    todo--;
    for (keyentry_T *kp = HI2KE(hi); kp != NULL && !got_int; kp = kp->ke_next) {
      if (kp->k_syn.id == id) {
        int outlen = 0;
        bool force_newline = false;
        if (prev_contained != (kp->flags & HL_CONTAINED)
            || prev_skipnl != (kp->flags & HL_SKIPNL)
            || prev_skipwhite != (kp->flags & HL_SKIPWHITE)
            || prev_skipempty != (kp->flags & HL_SKIPEMPTY)
            || prev_cont_in_list != kp->k_syn.cont_in_list
            || prev_next_list != kp->next_list) {
            force_newline = true;
        } else {
          outlen = (int)STRLEN(kp->keyword);
        }
        // output "contained" and "nextgroup" on each line
        if (syn_list_header(did_header, outlen, id, force_newline)) {
          prev_contained = 0;
          prev_next_list = NULL;
          prev_cont_in_list = NULL;
          prev_skipnl = 0;
          prev_skipwhite = 0;
          prev_skipempty = 0;
        }
        did_header = true;
        if (prev_contained != (kp->flags & HL_CONTAINED)) {
          msg_puts_attr("contained", attr);
          msg_putchar(' ');
          prev_contained = (kp->flags & HL_CONTAINED);
        }
        if (kp->k_syn.cont_in_list != prev_cont_in_list) {
          put_id_list("containedin", kp->k_syn.cont_in_list, attr);
          msg_putchar(' ');
          prev_cont_in_list = kp->k_syn.cont_in_list;
        }
        if (kp->next_list != prev_next_list) {
          put_id_list("nextgroup", kp->next_list, attr);
          msg_putchar(' ');
          prev_next_list = kp->next_list;
          if (kp->flags & HL_SKIPNL) {
            msg_puts_attr("skipnl", attr);
            msg_putchar(' ');
            prev_skipnl = (kp->flags & HL_SKIPNL);
          }
          if (kp->flags & HL_SKIPWHITE) {
            msg_puts_attr("skipwhite", attr);
            msg_putchar(' ');
            prev_skipwhite = (kp->flags & HL_SKIPWHITE);
          }
          if (kp->flags & HL_SKIPEMPTY) {
            msg_puts_attr("skipempty", attr);
            msg_putchar(' ');
            prev_skipempty = (kp->flags & HL_SKIPEMPTY);
          }
        }
        msg_outtrans(kp->keyword);
      }
    }
  }

  return did_header;
}

static void syn_clear_keyword(int id, hashtab_T *ht)
{
  hashitem_T  *hi;
  keyentry_T  *kp;
  keyentry_T  *kp_prev;
  keyentry_T  *kp_next;
  int todo;

  hash_lock(ht);
  todo = (int)ht->ht_used;
  for (hi = ht->ht_array; todo > 0; ++hi) {
    if (HASHITEM_EMPTY(hi)) {
      continue;
    }
    --todo;
    kp_prev = NULL;
    for (kp = HI2KE(hi); kp != NULL; ) {
      if (kp->k_syn.id == id) {
        kp_next = kp->ke_next;
        if (kp_prev == NULL) {
          if (kp_next == NULL)
            hash_remove(ht, hi);
          else
            hi->hi_key = KE2HIKEY(kp_next);
        } else
          kp_prev->ke_next = kp_next;
        xfree(kp->next_list);
        xfree(kp->k_syn.cont_in_list);
        xfree(kp);
        kp = kp_next;
      } else {
        kp_prev = kp;
        kp = kp->ke_next;
      }
    }
  }
  hash_unlock(ht);
}

/*
 * Clear a whole keyword table.
 */
static void clear_keywtab(hashtab_T *ht)
{
  hashitem_T  *hi;
  int todo;
  keyentry_T  *kp;
  keyentry_T  *kp_next;

  todo = (int)ht->ht_used;
  for (hi = ht->ht_array; todo > 0; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      --todo;
      for (kp = HI2KE(hi); kp != NULL; kp = kp_next) {
        kp_next = kp->ke_next;
        xfree(kp->next_list);
        xfree(kp->k_syn.cont_in_list);
        xfree(kp);
      }
    }
  }
  hash_clear(ht);
  hash_init(ht);
}

/// Add a keyword to the list of keywords.
///
/// @param name name of keyword
/// @param id group ID for this keyword
/// @param flags flags for this keyword
/// @param cont_in_list containedin for this keyword
/// @param next_list nextgroup for this keyword
static void add_keyword(char_u *const name,
                        const int id,
                        const int flags,
                        int16_t *const cont_in_list,
                        int16_t *const next_list,
                        const int conceal_char)
{
  char_u name_folded[MAXKEYWLEN + 1];
  const char_u *const name_ic = (curwin->w_s->b_syn_ic)
      ? str_foldcase(name, (int)STRLEN(name), name_folded, sizeof(name_folded))
      : name;

  keyentry_T *const kp = xmalloc(sizeof(keyentry_T) + STRLEN(name_ic));
  STRCPY(kp->keyword, name_ic);
  kp->k_syn.id = id;
  kp->k_syn.inc_tag = current_syn_inc_tag;
  kp->flags = flags;
  kp->k_char = conceal_char;
  kp->k_syn.cont_in_list = copy_id_list(cont_in_list);
  if (cont_in_list != NULL) {
    curwin->w_s->b_syn_containedin = TRUE;
  }
  kp->next_list = copy_id_list(next_list);

  const hash_T hash = hash_hash(kp->keyword);
  hashtab_T *const ht = (curwin->w_s->b_syn_ic)
      ? &curwin->w_s->b_keywtab_ic
      : &curwin->w_s->b_keywtab;
  hashitem_T *const hi = hash_lookup(ht, (const char *)kp->keyword,
                                     STRLEN(kp->keyword), hash);

  // even though it looks like only the kp->keyword member is
  // being used here, vim uses some pointer trickery to get the orignal
  // struct again later by using knowledge of the offset of the keyword
  // field in the struct. See the definition of the HI2KE macro.
  if (HASHITEM_EMPTY(hi)) {
    // new keyword, add to hashtable
    kp->ke_next = NULL;
    hash_add_item(ht, hi, kp->keyword, hash);
  } else {
    // keyword already exists, prepend to list
    kp->ke_next = HI2KE(hi);
    hi->hi_key = KE2HIKEY(kp);
  }
}

/*
 * Get the start and end of the group name argument.
 * Return a pointer to the first argument.
 * Return NULL if the end of the command was found instead of further args.
 */
static char_u *
get_group_name (
    char_u *arg,               /* start of the argument */
    char_u **name_end         /* pointer to end of the name */
)
{
  char_u      *rest;

  *name_end = skiptowhite(arg);
  rest = skipwhite(*name_end);

  /*
   * Check if there are enough arguments.  The first argument may be a
   * pattern, where '|' is allowed, so only check for NUL.
   */
  if (ends_excmd(*arg) || *rest == NUL)
    return NULL;
  return rest;
}

/*
 * Check for syntax command option arguments.
 * This can be called at any place in the list of arguments, and just picks
 * out the arguments that are known.  Can be called several times in a row to
 * collect all options in between other arguments.
 * Return a pointer to the next argument (which isn't an option).
 * Return NULL for any error;
 */
static char_u *
get_syn_options(
    char_u *arg,            // next argument to be checked
    syn_opt_arg_T *opt,     // various things
    int *conceal_char,
    int skip                // TRUE if skipping over command
)
{
  char_u      *gname_start, *gname;
  int syn_id;
  int len = 0;
  char        *p;
  int fidx;
  static const struct flag {
    char    *name;
    int argtype;
    int flags;
  } flagtab[] = { {"cCoOnNtTaAiInNeEdD",      0,      HL_CONTAINED},
                  {"oOnNeElLiInNeE",          0,      HL_ONELINE},
                  {"kKeEeEpPeEnNdD",          0,      HL_KEEPEND},
                  {"eExXtTeEnNdD",            0,      HL_EXTEND},
                  {"eExXcClLuUdDeEnNlL",      0,      HL_EXCLUDENL},
                  {"tTrRaAnNsSpPaArReEnNtT",  0,      HL_TRANSP},
                  {"sSkKiIpPnNlL",            0,      HL_SKIPNL},
                  {"sSkKiIpPwWhHiItTeE",      0,      HL_SKIPWHITE},
                  {"sSkKiIpPeEmMpPtTyY",      0,      HL_SKIPEMPTY},
                  {"gGrRoOuUpPhHeErReE",      0,      HL_SYNC_HERE},
                  {"gGrRoOuUpPtThHeErReE",    0,      HL_SYNC_THERE},
                  {"dDiIsSpPlLaAyY",          0,      HL_DISPLAY},
                  {"fFoOlLdD",                0,      HL_FOLD},
                  {"cCoOnNcCeEaAlL",          0,      HL_CONCEAL},
                  {"cCoOnNcCeEaAlLeEnNdDsS",  0,      HL_CONCEALENDS},
                  {"cCcChHaArR",              11,     0},
                  {"cCoOnNtTaAiInNsS",        1,      0},
                  {"cCoOnNtTaAiInNeEdDiInN",  2,      0},
                  {"nNeExXtTgGrRoOuUpP",      3,      0},};
  static const char *const first_letters = "cCoOkKeEtTsSgGdDfFnN";

  if (arg == NULL)              /* already detected error */
    return NULL;

  if (curwin->w_s->b_syn_conceal)
    opt->flags |= HL_CONCEAL;

  for (;; ) {
    /*
     * This is used very often when a large number of keywords is defined.
     * Need to skip quickly when no option name is found.
     * Also avoid tolower(), it's slow.
     */
    if (strchr(first_letters, *arg) == NULL)
      break;

    for (fidx = ARRAY_SIZE(flagtab); --fidx >= 0; ) {
      p = flagtab[fidx].name;
      int i;
      for (i = 0, len = 0; p[i] != NUL; i += 2, ++len) {
        if (arg[len] != p[i] && arg[len] != p[i + 1])
          break;
      }
      if (p[i] == NUL && (ascii_iswhite(arg[len])
                          || (flagtab[fidx].argtype > 0
                              ? arg[len] == '='
                              : ends_excmd(arg[len])))) {
        if (opt->keyword
            && (flagtab[fidx].flags == HL_DISPLAY
                || flagtab[fidx].flags == HL_FOLD
                || flagtab[fidx].flags == HL_EXTEND))
          /* treat "display", "fold" and "extend" as a keyword */
          fidx = -1;
        break;
      }
    }
    if (fidx < 0)           /* no match found */
      break;

    if (flagtab[fidx].argtype == 1) {
      if (!opt->has_cont_list) {
        EMSG(_("E395: contains argument not accepted here"));
        return NULL;
      }
      if (get_id_list(&arg, 8, &opt->cont_list, skip) == FAIL) {
        return NULL;
      }
    } else if (flagtab[fidx].argtype == 2)   {
      if (get_id_list(&arg, 11, &opt->cont_in_list, skip) == FAIL) {
        return NULL;
      }
    } else if (flagtab[fidx].argtype == 3)   {
      if (get_id_list(&arg, 9, &opt->next_list, skip) == FAIL) {
        return NULL;
      }
    } else if (flagtab[fidx].argtype == 11 && arg[5] == '=')   {
      // cchar=?
      *conceal_char = utf_ptr2char(arg + 6);
      arg += mb_ptr2len(arg + 6) - 1;
      if (!vim_isprintc_strict(*conceal_char)) {
        EMSG(_("E844: invalid cchar value"));
        return NULL;
      }
      arg = skipwhite(arg + 7);
    } else {
      opt->flags |= flagtab[fidx].flags;
      arg = skipwhite(arg + len);

      if (flagtab[fidx].flags == HL_SYNC_HERE
          || flagtab[fidx].flags == HL_SYNC_THERE) {
        if (opt->sync_idx == NULL) {
          EMSG(_("E393: group[t]here not accepted here"));
          return NULL;
        }
        gname_start = arg;
        arg = skiptowhite(arg);
        if (gname_start == arg)
          return NULL;
        gname = vim_strnsave(gname_start, (int)(arg - gname_start));
        if (STRCMP(gname, "NONE") == 0)
          *opt->sync_idx = NONE_IDX;
        else {
          syn_id = syn_name2id(gname);
          int i;
          for (i = curwin->w_s->b_syn_patterns.ga_len; --i >= 0; )
            if (SYN_ITEMS(curwin->w_s)[i].sp_syn.id == syn_id
                && SYN_ITEMS(curwin->w_s)[i].sp_type == SPTYPE_START) {
              *opt->sync_idx = i;
              break;
            }
          if (i < 0) {
            EMSG2(_("E394: Didn't find region item for %s"), gname);
            xfree(gname);
            return NULL;
          }
        }

        xfree(gname);
        arg = skipwhite(arg);
      } else if (flagtab[fidx].flags == HL_FOLD
                 && foldmethodIsSyntax(curwin))
        /* Need to update folds later. */
        foldUpdateAll(curwin);
    }
  }

  return arg;
}

/*
 * Adjustments to syntax item when declared in a ":syn include"'d file.
 * Set the contained flag, and if the item is not already contained, add it
 * to the specified top-level group, if any.
 */
static void syn_incl_toplevel(int id, int *flagsp)
{
  if ((*flagsp & HL_CONTAINED) || curwin->w_s->b_syn_topgrp == 0)
    return;
  *flagsp |= HL_CONTAINED;
  if (curwin->w_s->b_syn_topgrp >= SYNID_CLUSTER) {
    // We have to alloc this, because syn_combine_list() will free it.
    int16_t *grp_list = xmalloc(2 * sizeof(*grp_list));
    int tlg_id = curwin->w_s->b_syn_topgrp - SYNID_CLUSTER;

    grp_list[0] = id;
    grp_list[1] = 0;
    syn_combine_list(&SYN_CLSTR(curwin->w_s)[tlg_id].scl_list, &grp_list,
        CLUSTER_ADD);
  }
}

/*
 * Handle ":syntax include [@{group-name}] filename" command.
 */
static void syn_cmd_include(exarg_T *eap, int syncing)
{
  char_u      *arg = eap->arg;
  int sgl_id = 1;
  char_u      *group_name_end;
  char_u      *rest;
  char_u      *errormsg = NULL;
  int prev_toplvl_grp;
  int prev_syn_inc_tag;
  int source = FALSE;

  eap->nextcmd = find_nextcmd(arg);
  if (eap->skip)
    return;

  if (arg[0] == '@') {
    ++arg;
    rest = get_group_name(arg, &group_name_end);
    if (rest == NULL) {
      EMSG((char_u *)_("E397: Filename required"));
      return;
    }
    sgl_id = syn_check_cluster(arg, (int)(group_name_end - arg));
    if (sgl_id == 0)
      return;
    /* separate_nextcmd() and expand_filename() depend on this */
    eap->arg = rest;
  }

  /*
   * Everything that's left, up to the next command, should be the
   * filename to include.
   */
  eap->argt |= (XFILE | NOSPC);
  separate_nextcmd(eap);
  if (*eap->arg == '<' || *eap->arg == '$' || path_is_absolute(eap->arg)) {
    // For an absolute path, "$VIM/..." or "<sfile>.." we ":source" the
    // file.  Need to expand the file name first.  In other cases
    // ":runtime!" is used.
    source = true;
    if (expand_filename(eap, syn_cmdlinep, &errormsg) == FAIL) {
      if (errormsg != NULL)
        EMSG(errormsg);
      return;
    }
  }

  /*
   * Save and restore the existing top-level grouplist id and ":syn
   * include" tag around the actual inclusion.
   */
  if (running_syn_inc_tag >= MAX_SYN_INC_TAG) {
    EMSG((char_u *)_("E847: Too many syntax includes"));
    return;
  }
  prev_syn_inc_tag = current_syn_inc_tag;
  current_syn_inc_tag = ++running_syn_inc_tag;
  prev_toplvl_grp = curwin->w_s->b_syn_topgrp;
  curwin->w_s->b_syn_topgrp = sgl_id;
  if (source ? do_source(eap->arg, false, DOSO_NONE) == FAIL
             : source_runtime(eap->arg, DIP_ALL) == FAIL) {
    EMSG2(_(e_notopen), eap->arg);
  }
  curwin->w_s->b_syn_topgrp = prev_toplvl_grp;
  current_syn_inc_tag = prev_syn_inc_tag;
}

/*
 * Handle ":syntax keyword {group-name} [{option}] keyword .." command.
 */
static void syn_cmd_keyword(exarg_T *eap, int syncing)
{
  char_u      *arg = eap->arg;
  char_u      *group_name_end;
  int syn_id;
  char_u      *rest;
  char_u      *keyword_copy = NULL;
  char_u      *p;
  char_u      *kw;
  syn_opt_arg_T syn_opt_arg;
  int cnt;
  int conceal_char = NUL;

  rest = get_group_name(arg, &group_name_end);

  if (rest != NULL) {
    if (eap->skip) {
      syn_id = -1;
    } else {
      syn_id = syn_check_group(arg, (int)(group_name_end - arg));
    }
    if (syn_id != 0) {
      // Allocate a buffer, for removing backslashes in the keyword.
      keyword_copy = xmalloc(STRLEN(rest) + 1);
    }
    if (keyword_copy != NULL) {
      syn_opt_arg.flags = 0;
      syn_opt_arg.keyword = true;
      syn_opt_arg.sync_idx = NULL;
      syn_opt_arg.has_cont_list = false;
      syn_opt_arg.cont_in_list = NULL;
      syn_opt_arg.next_list = NULL;

      // The options given apply to ALL keywords, so all options must be
      // found before keywords can be created.
      // 1: collect the options and copy the keywords to keyword_copy.
      cnt = 0;
      p = keyword_copy;
      for (; rest != NULL && !ends_excmd(*rest); rest = skipwhite(rest)) {
        rest = get_syn_options(rest, &syn_opt_arg, &conceal_char, eap->skip);
        if (rest == NULL || ends_excmd(*rest)) {
          break;
        }
        // Copy the keyword, removing backslashes, and add a NUL.
        while (*rest != NUL && !ascii_iswhite(*rest)) {
          if (*rest == '\\' && rest[1] != NUL) {
            rest++;
          }
          *p++ = *rest++;
        }
        *p++ = NUL;
        cnt++;
      }

      if (!eap->skip) {
        // Adjust flags for use of ":syn include".
        syn_incl_toplevel(syn_id, &syn_opt_arg.flags);

        // 2: Add an entry for each keyword.
        for (kw = keyword_copy; --cnt >= 0; kw += STRLEN(kw) + 1) {
          for (p = vim_strchr(kw, '[');; ) {
            if (p != NULL) {
              *p = NUL;
            }
            add_keyword(kw, syn_id, syn_opt_arg.flags,
                        syn_opt_arg.cont_in_list,
                        syn_opt_arg.next_list, conceal_char);
            if (p == NULL) {
              break;
            }
            if (p[1] == NUL) {
              emsgf(_("E789: Missing ']': %s"), kw);
              goto error;
            }
            if (p[1] == ']') {
              if (p[2] != NUL) {
                emsgf(_("E890: trailing char after ']': %s]%s"),
                      kw, &p[2]);
                goto error;
              }
              kw = p + 1;
              break;   // skip over the "]"
            }
            const int l = (*mb_ptr2len)(p + 1);

            memmove(p, p + 1, l);
            p += l;
          }
        }
      }

error:
      xfree(keyword_copy);
      xfree(syn_opt_arg.cont_in_list);
      xfree(syn_opt_arg.next_list);
    }
  }

  if (rest != NULL)
    eap->nextcmd = check_nextcmd(rest);
  else
    EMSG2(_(e_invarg2), arg);

  redraw_curbuf_later(SOME_VALID);
  syn_stack_free_all(curwin->w_s);              /* Need to recompute all syntax. */
}

/*
 * Handle ":syntax match {name} [{options}] {pattern} [{options}]".
 *
 * Also ":syntax sync match {name} [[grouphere | groupthere] {group-name}] .."
 */
static void
syn_cmd_match(
    exarg_T *eap,
    int syncing                        /* TRUE for ":syntax sync match .. " */
)
{
  char_u      *arg = eap->arg;
  char_u      *group_name_end;
  char_u      *rest;
  synpat_T item;                /* the item found in the line */
  int syn_id;
  syn_opt_arg_T syn_opt_arg;
  int sync_idx = 0;
  int conceal_char = NUL;

  /* Isolate the group name, check for validity */
  rest = get_group_name(arg, &group_name_end);

  /* Get options before the pattern */
  syn_opt_arg.flags = 0;
  syn_opt_arg.keyword = false;
  syn_opt_arg.sync_idx = syncing ? &sync_idx : NULL;
  syn_opt_arg.has_cont_list = true;
  syn_opt_arg.cont_list = NULL;
  syn_opt_arg.cont_in_list = NULL;
  syn_opt_arg.next_list = NULL;
  rest = get_syn_options(rest, &syn_opt_arg, &conceal_char, eap->skip);

  /* get the pattern. */
  init_syn_patterns();
  memset(&item, 0, sizeof(item));
  rest = get_syn_pattern(rest, &item);
  if (vim_regcomp_had_eol() && !(syn_opt_arg.flags & HL_EXCLUDENL)) {
    syn_opt_arg.flags |= HL_HAS_EOL;
  }

  // Get options after the pattern
  rest = get_syn_options(rest, &syn_opt_arg, &conceal_char, eap->skip);

  if (rest != NULL) {           /* all arguments are valid */
    /*
     * Check for trailing command and illegal trailing arguments.
     */
    eap->nextcmd = check_nextcmd(rest);
    if (!ends_excmd(*rest) || eap->skip)
      rest = NULL;
    else {
      if ((syn_id = syn_check_group(arg, (int)(group_name_end - arg))) != 0) {
        syn_incl_toplevel(syn_id, &syn_opt_arg.flags);
        /*
         * Store the pattern in the syn_items list
         */
        synpat_T *spp = GA_APPEND_VIA_PTR(synpat_T,
                                          &curwin->w_s->b_syn_patterns);
        *spp = item;
        spp->sp_syncing = syncing;
        spp->sp_type = SPTYPE_MATCH;
        spp->sp_syn.id = syn_id;
        spp->sp_syn.inc_tag = current_syn_inc_tag;
        spp->sp_flags = syn_opt_arg.flags;
        spp->sp_sync_idx = sync_idx;
        spp->sp_cont_list = syn_opt_arg.cont_list;
        spp->sp_syn.cont_in_list = syn_opt_arg.cont_in_list;
        spp->sp_cchar = conceal_char;
        if (syn_opt_arg.cont_in_list != NULL)
          curwin->w_s->b_syn_containedin = TRUE;
        spp->sp_next_list = syn_opt_arg.next_list;

        /* remember that we found a match for syncing on */
        if (syn_opt_arg.flags & (HL_SYNC_HERE|HL_SYNC_THERE))
          curwin->w_s->b_syn_sync_flags |= SF_MATCH;
        if (syn_opt_arg.flags & HL_FOLD)
          ++curwin->w_s->b_syn_folditems;

        redraw_curbuf_later(SOME_VALID);
        syn_stack_free_all(curwin->w_s);          /* Need to recompute all syntax. */
        return;           /* don't free the progs and patterns now */
      }
    }
  }

  /*
   * Something failed, free the allocated memory.
   */
  vim_regfree(item.sp_prog);
  xfree(item.sp_pattern);
  xfree(syn_opt_arg.cont_list);
  xfree(syn_opt_arg.cont_in_list);
  xfree(syn_opt_arg.next_list);

  if (rest == NULL)
    EMSG2(_(e_invarg2), arg);
}

/*
 * Handle ":syntax region {group-name} [matchgroup={group-name}]
 *		start {start} .. [skip {skip}] end {end} .. [{options}]".
 */
static void
syn_cmd_region(
    exarg_T *eap,
    int syncing                        /* TRUE for ":syntax sync region .." */
)
{
  char_u              *arg = eap->arg;
  char_u              *group_name_end;
  char_u              *rest;                    /* next arg, NULL on error */
  char_u              *key_end;
  char_u              *key = NULL;
  char_u              *p;
  int item;
#define ITEM_START          0
#define ITEM_SKIP           1
#define ITEM_END            2
#define ITEM_MATCHGROUP     3
  struct pat_ptr {
    synpat_T        *pp_synp;                   /* pointer to syn_pattern */
    int pp_matchgroup_id;                       /* matchgroup ID */
    struct pat_ptr  *pp_next;                   /* pointer to next pat_ptr */
  }                   *(pat_ptrs[3]);
  /* patterns found in the line */
  struct pat_ptr      *ppp;
  struct pat_ptr      *ppp_next;
  int pat_count = 0;                            /* nr of syn_patterns found */
  int syn_id;
  int matchgroup_id = 0;
  int not_enough = FALSE;                       /* not enough arguments */
  int illegal = FALSE;                          /* illegal arguments */
  int success = FALSE;
  syn_opt_arg_T syn_opt_arg;
  int conceal_char = NUL;

  /* Isolate the group name, check for validity */
  rest = get_group_name(arg, &group_name_end);

  pat_ptrs[0] = NULL;
  pat_ptrs[1] = NULL;
  pat_ptrs[2] = NULL;

  init_syn_patterns();

  syn_opt_arg.flags = 0;
  syn_opt_arg.keyword = false;
  syn_opt_arg.sync_idx = NULL;
  syn_opt_arg.has_cont_list = true;
  syn_opt_arg.cont_list = NULL;
  syn_opt_arg.cont_in_list = NULL;
  syn_opt_arg.next_list = NULL;

  // get the options, patterns and matchgroup.
  while (rest != NULL && !ends_excmd(*rest)) {
    // Check for option arguments
    rest = get_syn_options(rest, &syn_opt_arg, &conceal_char, eap->skip);
    if (rest == NULL || ends_excmd(*rest)) {
      break;
    }

    /* must be a pattern or matchgroup then */
    key_end = rest;
    while (*key_end && !ascii_iswhite(*key_end) && *key_end != '=')
      ++key_end;
    xfree(key);
    key = vim_strnsave_up(rest, (int)(key_end - rest));
    if (STRCMP(key, "MATCHGROUP") == 0) {
      item = ITEM_MATCHGROUP;
    } else if (STRCMP(key, "START") == 0) {
      item = ITEM_START;
    } else if (STRCMP(key, "END") == 0) {
      item = ITEM_END;
    } else if (STRCMP(key, "SKIP") == 0) {
      if (pat_ptrs[ITEM_SKIP] != NULL) {  // One skip pattern allowed.
        illegal = true;
        break;
      }
      item = ITEM_SKIP;
    } else {
      break;
    }
    rest = skipwhite(key_end);
    if (*rest != '=') {
      rest = NULL;
      EMSG2(_("E398: Missing '=': %s"), arg);
      break;
    }
    rest = skipwhite(rest + 1);
    if (*rest == NUL) {
      not_enough = TRUE;
      break;
    }

    if (item == ITEM_MATCHGROUP) {
      p = skiptowhite(rest);
      if ((p - rest == 4 && STRNCMP(rest, "NONE", 4) == 0) || eap->skip)
        matchgroup_id = 0;
      else {
        matchgroup_id = syn_check_group(rest, (int)(p - rest));
        if (matchgroup_id == 0) {
          illegal = TRUE;
          break;
        }
      }
      rest = skipwhite(p);
    } else {
      /*
       * Allocate room for a syn_pattern, and link it in the list of
       * syn_patterns for this item, at the start (because the list is
       * used from end to start).
       */
      ppp = xmalloc(sizeof(struct pat_ptr));
      ppp->pp_next = pat_ptrs[item];
      pat_ptrs[item] = ppp;
      ppp->pp_synp = xcalloc(1, sizeof(synpat_T));

      // Get the syntax pattern and the following offset(s).

      // Enable the appropriate \z specials.
      if (item == ITEM_START) {
        reg_do_extmatch = REX_SET;
      } else {
        assert(item == ITEM_SKIP || item == ITEM_END);
        reg_do_extmatch = REX_USE;
      }
      rest = get_syn_pattern(rest, ppp->pp_synp);
      reg_do_extmatch = 0;
      if (item == ITEM_END && vim_regcomp_had_eol()
          && !(syn_opt_arg.flags & HL_EXCLUDENL)) {
        ppp->pp_synp->sp_flags |= HL_HAS_EOL;
      }
      ppp->pp_matchgroup_id = matchgroup_id;
      pat_count++;
    }
  }
  xfree(key);
  if (illegal || not_enough)
    rest = NULL;

  // Must have a "start" and "end" pattern.
  if (rest != NULL && (pat_ptrs[ITEM_START] == NULL
                       || pat_ptrs[ITEM_END] == NULL)) {
    not_enough = true;
    rest = NULL;
  }

  if (rest != NULL) {
    /*
     * Check for trailing garbage or command.
     * If OK, add the item.
     */
    eap->nextcmd = check_nextcmd(rest);
    if (!ends_excmd(*rest) || eap->skip)
      rest = NULL;
    else {
      ga_grow(&(curwin->w_s->b_syn_patterns), pat_count);
      if ((syn_id = syn_check_group(arg, (int)(group_name_end - arg))) != 0) {
        syn_incl_toplevel(syn_id, &syn_opt_arg.flags);
        /*
         * Store the start/skip/end in the syn_items list
         */
        int idx = curwin->w_s->b_syn_patterns.ga_len;
        for (item = ITEM_START; item <= ITEM_END; ++item) {
          for (ppp = pat_ptrs[item]; ppp != NULL; ppp = ppp->pp_next) {
            SYN_ITEMS(curwin->w_s)[idx] = *(ppp->pp_synp);
            SYN_ITEMS(curwin->w_s)[idx].sp_syncing = syncing;
            SYN_ITEMS(curwin->w_s)[idx].sp_type =
              (item == ITEM_START) ? SPTYPE_START :
              (item == ITEM_SKIP) ? SPTYPE_SKIP : SPTYPE_END;
            SYN_ITEMS(curwin->w_s)[idx].sp_flags |= syn_opt_arg.flags;
            SYN_ITEMS(curwin->w_s)[idx].sp_syn.id = syn_id;
            SYN_ITEMS(curwin->w_s)[idx].sp_syn.inc_tag =
              current_syn_inc_tag;
            SYN_ITEMS(curwin->w_s)[idx].sp_syn_match_id =
              ppp->pp_matchgroup_id;
            SYN_ITEMS(curwin->w_s)[idx].sp_cchar = conceal_char;
            if (item == ITEM_START) {
              SYN_ITEMS(curwin->w_s)[idx].sp_cont_list =
                syn_opt_arg.cont_list;
              SYN_ITEMS(curwin->w_s)[idx].sp_syn.cont_in_list =
                syn_opt_arg.cont_in_list;
              if (syn_opt_arg.cont_in_list != NULL)
                curwin->w_s->b_syn_containedin = TRUE;
              SYN_ITEMS(curwin->w_s)[idx].sp_next_list =
                syn_opt_arg.next_list;
            }
            ++curwin->w_s->b_syn_patterns.ga_len;
            ++idx;
            if (syn_opt_arg.flags & HL_FOLD)
              ++curwin->w_s->b_syn_folditems;
          }
        }

        redraw_curbuf_later(SOME_VALID);
        syn_stack_free_all(curwin->w_s);          /* Need to recompute all syntax. */
        success = TRUE;               /* don't free the progs and patterns now */
      }
    }
  }

  /*
   * Free the allocated memory.
   */
  for (item = ITEM_START; item <= ITEM_END; ++item)
    for (ppp = pat_ptrs[item]; ppp != NULL; ppp = ppp_next) {
      if (!success && ppp->pp_synp != NULL) {
        vim_regfree(ppp->pp_synp->sp_prog);
        xfree(ppp->pp_synp->sp_pattern);
      }
      xfree(ppp->pp_synp);
      ppp_next = ppp->pp_next;
      xfree(ppp);
    }

  if (!success) {
    xfree(syn_opt_arg.cont_list);
    xfree(syn_opt_arg.cont_in_list);
    xfree(syn_opt_arg.next_list);
    if (not_enough)
      EMSG2(_("E399: Not enough arguments: syntax region %s"), arg);
    else if (illegal || rest == NULL)
      EMSG2(_(e_invarg2), arg);
  }
}

// A simple syntax group ID comparison function suitable for use in qsort()
static int syn_compare_stub(const void *const v1, const void *const v2)
{
  const int16_t *const s1 = v1;
  const int16_t *const s2 = v2;

  return *s1 > *s2 ? 1 : *s1 < *s2 ? -1 : 0;
}

// Combines lists of syntax clusters.
// *clstr1 and *clstr2 must both be allocated memory; they will be consumed.
static void syn_combine_list(int16_t **const clstr1, int16_t **const clstr2,
                             const int list_op)
{
  size_t count1 = 0;
  size_t count2 = 0;
  const int16_t *g1;
  const int16_t *g2;
  int16_t *clstr = NULL;

  /*
   * Handle degenerate cases.
   */
  if (*clstr2 == NULL)
    return;
  if (*clstr1 == NULL || list_op == CLUSTER_REPLACE) {
    if (list_op == CLUSTER_REPLACE)
      xfree(*clstr1);
    if (list_op == CLUSTER_REPLACE || list_op == CLUSTER_ADD)
      *clstr1 = *clstr2;
    else
      xfree(*clstr2);
    return;
  }

  for (g1 = *clstr1; *g1; g1++) {
    count1++;
  }
  for (g2 = *clstr2; *g2; g2++) {
    count2++;
  }

  // For speed purposes, sort both lists.
  qsort(*clstr1, count1, sizeof(**clstr1), syn_compare_stub);
  qsort(*clstr2, count2, sizeof(**clstr2), syn_compare_stub);

  // We proceed in two passes; in round 1, we count the elements to place
  // in the new list, and in round 2, we allocate and populate the new
  // list.  For speed, we use a mergesort-like method, adding the smaller
  // of the current elements in each list to the new list.
  for (int round = 1; round <= 2; round++) {
    g1 = *clstr1;
    g2 = *clstr2;
    int count = 0;

    /*
     * First, loop through the lists until one of them is empty.
     */
    while (*g1 && *g2) {
      /*
       * We always want to add from the first list.
       */
      if (*g1 < *g2) {
        if (round == 2)
          clstr[count] = *g1;
        count++;
        g1++;
        continue;
      }
      /*
       * We only want to add from the second list if we're adding the
       * lists.
       */
      if (list_op == CLUSTER_ADD) {
        if (round == 2)
          clstr[count] = *g2;
        count++;
      }
      if (*g1 == *g2)
        g1++;
      g2++;
    }

    /*
     * Now add the leftovers from whichever list didn't get finished
     * first.  As before, we only want to add from the second list if
     * we're adding the lists.
     */
    for (; *g1; g1++, count++)
      if (round == 2)
        clstr[count] = *g1;
    if (list_op == CLUSTER_ADD)
      for (; *g2; g2++, count++)
        if (round == 2)
          clstr[count] = *g2;

    if (round == 1) {
      /*
       * If the group ended up empty, we don't need to allocate any
       * space for it.
       */
      if (count == 0) {
        clstr = NULL;
        break;
      }
      clstr = xmalloc((count + 1) * sizeof(*clstr));
      clstr[count] = 0;
    }
  }

  /*
   * Finally, put the new list in place.
   */
  xfree(*clstr1);
  xfree(*clstr2);
  *clstr1 = clstr;
}

// Lookup a syntax cluster name and return its ID.
// If it is not found, 0 is returned.
static int syn_scl_name2id(char_u *name)
{
  // Avoid using stricmp() too much, it's slow on some systems
  char_u *name_u = vim_strsave_up(name);
  int i;
  for (i = curwin->w_s->b_syn_clusters.ga_len; --i >= 0; ) {
    if (SYN_CLSTR(curwin->w_s)[i].scl_name_u != NULL
        && STRCMP(name_u, SYN_CLSTR(curwin->w_s)[i].scl_name_u) == 0) {
      break;
    }
  }
  xfree(name_u);
  return i < 0 ? 0 : i + SYNID_CLUSTER;
}

/*
 * Like syn_scl_name2id(), but take a pointer + length argument.
 */
static int syn_scl_namen2id(char_u *linep, int len)
{
  char_u *name = vim_strnsave(linep, len);
  int id = syn_scl_name2id(name);
  xfree(name);

  return id;
}

// Find syntax cluster name in the table and return its ID.
// The argument is a pointer to the name and the length of the name.
// If it doesn't exist yet, a new entry is created.
// Return 0 for failure.
static int syn_check_cluster(char_u *pp, int len)
{
  int id;
  char_u      *name;

  name = vim_strnsave(pp, len);

  id = syn_scl_name2id(name);
  if (id == 0)                          /* doesn't exist yet */
    id = syn_add_cluster(name);
  else
    xfree(name);
  return id;
}

// Add new syntax cluster and return its ID.
// "name" must be an allocated string, it will be consumed.
// Return 0 for failure.
static int syn_add_cluster(char_u *name)
{
  /*
   * First call for this growarray: init growing array.
   */
  if (curwin->w_s->b_syn_clusters.ga_data == NULL) {
    curwin->w_s->b_syn_clusters.ga_itemsize = sizeof(syn_cluster_T);
    ga_set_growsize(&curwin->w_s->b_syn_clusters, 10);
  }

  int len = curwin->w_s->b_syn_clusters.ga_len;
  if (len >= MAX_CLUSTER_ID) {
    EMSG((char_u *)_("E848: Too many syntax clusters"));
    xfree(name);
    return 0;
  }

  syn_cluster_T *scp = GA_APPEND_VIA_PTR(syn_cluster_T,
                                         &curwin->w_s->b_syn_clusters);
  memset(scp, 0, sizeof(*scp));
  scp->scl_name = name;
  scp->scl_name_u = vim_strsave_up(name);
  scp->scl_list = NULL;

  if (STRICMP(name, "Spell") == 0)
    curwin->w_s->b_spell_cluster_id = len + SYNID_CLUSTER;
  if (STRICMP(name, "NoSpell") == 0)
    curwin->w_s->b_nospell_cluster_id = len + SYNID_CLUSTER;

  return len + SYNID_CLUSTER;
}

/*
 * Handle ":syntax cluster {cluster-name} [contains={groupname},..]
 *		[add={groupname},..] [remove={groupname},..]".
 */
static void syn_cmd_cluster(exarg_T *eap, int syncing)
{
  char_u      *arg = eap->arg;
  char_u      *group_name_end;
  char_u      *rest;
  bool got_clstr = false;
  int opt_len;
  int list_op;

  eap->nextcmd = find_nextcmd(arg);
  if (eap->skip)
    return;

  rest = get_group_name(arg, &group_name_end);

  if (rest != NULL) {
    int scl_id = syn_check_cluster(arg, (int)(group_name_end - arg));
    if (scl_id == 0) {
      return;
    }
    scl_id -= SYNID_CLUSTER;

    for (;; ) {
      if (STRNICMP(rest, "add", 3) == 0
          && (ascii_iswhite(rest[3]) || rest[3] == '=')) {
        opt_len = 3;
        list_op = CLUSTER_ADD;
      } else if (STRNICMP(rest, "remove", 6) == 0
                 && (ascii_iswhite(rest[6]) || rest[6] == '=')) {
        opt_len = 6;
        list_op = CLUSTER_SUBTRACT;
      } else if (STRNICMP(rest, "contains", 8) == 0
                 && (ascii_iswhite(rest[8]) || rest[8] == '=')) {
        opt_len = 8;
        list_op = CLUSTER_REPLACE;
      } else
        break;

      int16_t *clstr_list = NULL;
      if (get_id_list(&rest, opt_len, &clstr_list, eap->skip) == FAIL) {
        EMSG2(_(e_invarg2), rest);
        break;
      }
      if (scl_id >= 0) {
        syn_combine_list(&SYN_CLSTR(curwin->w_s)[scl_id].scl_list,
                         &clstr_list, list_op);
      } else {
        xfree(clstr_list);
      }
      got_clstr = true;
    }

    if (got_clstr) {
      redraw_curbuf_later(SOME_VALID);
      syn_stack_free_all(curwin->w_s);          /* Need to recompute all. */
    }
  }

  if (!got_clstr)
    EMSG(_("E400: No cluster specified"));
  if (rest == NULL || !ends_excmd(*rest))
    EMSG2(_(e_invarg2), arg);
}

/*
 * On first call for current buffer: Init growing array.
 */
static void init_syn_patterns(void)
{
  curwin->w_s->b_syn_patterns.ga_itemsize = sizeof(synpat_T);
  ga_set_growsize(&curwin->w_s->b_syn_patterns, 10);
}

/*
 * Get one pattern for a ":syntax match" or ":syntax region" command.
 * Stores the pattern and program in a synpat_T.
 * Returns a pointer to the next argument, or NULL in case of an error.
 */
static char_u *get_syn_pattern(char_u *arg, synpat_T *ci)
{
  char_u      *end;
  int         *p;
  int idx;
  char_u      *cpo_save;

  // need at least three chars
  if (arg == NULL || arg[0] == NUL || arg[1] == NUL || arg[2] == NUL) {
    return NULL;
  }

  end = skip_regexp(arg + 1, *arg, TRUE, NULL);
  if (*end != *arg) {                       /* end delimiter not found */
    EMSG2(_("E401: Pattern delimiter not found: %s"), arg);
    return NULL;
  }
  /* store the pattern and compiled regexp program */
  ci->sp_pattern = vim_strnsave(arg + 1, (int)(end - arg - 1));

  /* Make 'cpoptions' empty, to avoid the 'l' flag */
  cpo_save = p_cpo;
  p_cpo = (char_u *)"";
  ci->sp_prog = vim_regcomp(ci->sp_pattern, RE_MAGIC);
  p_cpo = cpo_save;

  if (ci->sp_prog == NULL)
    return NULL;
  ci->sp_ic = curwin->w_s->b_syn_ic;
  syn_clear_time(&ci->sp_time);

  /*
   * Check for a match, highlight or region offset.
   */
  ++end;
  do {
    for (idx = SPO_COUNT; --idx >= 0; )
      if (STRNCMP(end, spo_name_tab[idx], 3) == 0)
        break;
    if (idx >= 0) {
      p = &(ci->sp_offsets[idx]);
      if (idx != SPO_LC_OFF)
        switch (end[3]) {
        case 's':   break;
        case 'b':   break;
        case 'e':   idx += SPO_COUNT; break;
        default:    idx = -1; break;
        }
      if (idx >= 0) {
        ci->sp_off_flags |= (1 << idx);
        if (idx == SPO_LC_OFF) {            /* lc=99 */
          end += 3;
          *p = getdigits_int(&end, true, 0);

          /* "lc=" offset automatically sets "ms=" offset */
          if (!(ci->sp_off_flags & (1 << SPO_MS_OFF))) {
            ci->sp_off_flags |= (1 << SPO_MS_OFF);
            ci->sp_offsets[SPO_MS_OFF] = *p;
          }
        } else {                          /* yy=x+99 */
          end += 4;
          if (*end == '+') {
            end++;
            *p = getdigits_int(&end, true, 0);    // positive offset
          } else if (*end == '-')   {
            end++;
            *p = -getdigits_int(&end, true, 0);   // negative offset
          }
        }
        if (*end != ',')
          break;
        ++end;
      }
    }
  } while (idx >= 0);

  if (!ends_excmd(*end) && !ascii_iswhite(*end)) {
    EMSG2(_("E402: Garbage after pattern: %s"), arg);
    return NULL;
  }
  return skipwhite(end);
}

/*
 * Handle ":syntax sync .." command.
 */
static void syn_cmd_sync(exarg_T *eap, int syncing)
{
  char_u      *arg_start = eap->arg;
  char_u      *arg_end;
  char_u      *key = NULL;
  char_u      *next_arg;
  int illegal = FALSE;
  int finished = FALSE;
  long n;
  char_u      *cpo_save;

  if (ends_excmd(*arg_start)) {
    syn_cmd_list(eap, TRUE);
    return;
  }

  while (!ends_excmd(*arg_start)) {
    arg_end = skiptowhite(arg_start);
    next_arg = skipwhite(arg_end);
    xfree(key);
    key = vim_strnsave_up(arg_start, (int)(arg_end - arg_start));
    if (STRCMP(key, "CCOMMENT") == 0) {
      if (!eap->skip)
        curwin->w_s->b_syn_sync_flags |= SF_CCOMMENT;
      if (!ends_excmd(*next_arg)) {
        arg_end = skiptowhite(next_arg);
        if (!eap->skip)
          curwin->w_s->b_syn_sync_id = syn_check_group(next_arg,
              (int)(arg_end - next_arg));
        next_arg = skipwhite(arg_end);
      } else if (!eap->skip)
        curwin->w_s->b_syn_sync_id = syn_name2id((char_u *)"Comment");
    } else if (  STRNCMP(key, "LINES", 5) == 0
                 || STRNCMP(key, "MINLINES", 8) == 0
                 || STRNCMP(key, "MAXLINES", 8) == 0
                 || STRNCMP(key, "LINEBREAKS", 10) == 0) {
      if (key[4] == 'S')
        arg_end = key + 6;
      else if (key[0] == 'L')
        arg_end = key + 11;
      else
        arg_end = key + 9;
      if (arg_end[-1] != '=' || !ascii_isdigit(*arg_end)) {
        illegal = TRUE;
        break;
      }
      n = getdigits_long(&arg_end, false, 0);
      if (!eap->skip) {
        if (key[4] == 'B')
          curwin->w_s->b_syn_sync_linebreaks = n;
        else if (key[1] == 'A')
          curwin->w_s->b_syn_sync_maxlines = n;
        else
          curwin->w_s->b_syn_sync_minlines = n;
      }
    } else if (STRCMP(key, "FROMSTART") == 0)   {
      if (!eap->skip) {
        curwin->w_s->b_syn_sync_minlines = MAXLNUM;
        curwin->w_s->b_syn_sync_maxlines = 0;
      }
    } else if (STRCMP(key, "LINECONT") == 0)   {
      if (*next_arg == NUL) {  // missing pattern
        illegal = true;
        break;
      }
      if (curwin->w_s->b_syn_linecont_pat != NULL) {
        EMSG(_("E403: syntax sync: line continuations pattern specified twice"));
        finished = TRUE;
        break;
      }
      arg_end = skip_regexp(next_arg + 1, *next_arg, TRUE, NULL);
      if (*arg_end != *next_arg) {          /* end delimiter not found */
        illegal = TRUE;
        break;
      }

      if (!eap->skip) {
        /* store the pattern and compiled regexp program */
        curwin->w_s->b_syn_linecont_pat =
          vim_strnsave(next_arg + 1, (int)(arg_end - next_arg - 1));
        curwin->w_s->b_syn_linecont_ic = curwin->w_s->b_syn_ic;

        /* Make 'cpoptions' empty, to avoid the 'l' flag */
        cpo_save = p_cpo;
        p_cpo = (char_u *)"";
        curwin->w_s->b_syn_linecont_prog =
          vim_regcomp(curwin->w_s->b_syn_linecont_pat, RE_MAGIC);
        p_cpo = cpo_save;
        syn_clear_time(&curwin->w_s->b_syn_linecont_time);

        if (curwin->w_s->b_syn_linecont_prog == NULL) {
          XFREE_CLEAR(curwin->w_s->b_syn_linecont_pat);
          finished = true;
          break;
        }
      }
      next_arg = skipwhite(arg_end + 1);
    } else {
      eap->arg = next_arg;
      if (STRCMP(key, "MATCH") == 0)
        syn_cmd_match(eap, TRUE);
      else if (STRCMP(key, "REGION") == 0)
        syn_cmd_region(eap, TRUE);
      else if (STRCMP(key, "CLEAR") == 0)
        syn_cmd_clear(eap, TRUE);
      else
        illegal = TRUE;
      finished = TRUE;
      break;
    }
    arg_start = next_arg;
  }
  xfree(key);
  if (illegal)
    EMSG2(_("E404: Illegal arguments: %s"), arg_start);
  else if (!finished) {
    eap->nextcmd = check_nextcmd(arg_start);
    redraw_curbuf_later(SOME_VALID);
    syn_stack_free_all(curwin->w_s);            /* Need to recompute all syntax. */
  }
}

/*
 * Convert a line of highlight group names into a list of group ID numbers.
 * "arg" should point to the "contains" or "nextgroup" keyword.
 * "arg" is advanced to after the last group name.
 * Careful: the argument is modified (NULs added).
 * returns FAIL for some error, OK for success.
 */
static int
get_id_list(
    char_u **const arg,
    const int keylen,       // length of keyword
    int16_t **const list,   // where to store the resulting list, if not
                            // NULL, the list is silently skipped!
    const bool skip
)
{
  char_u      *p = NULL;
  char_u      *end;
  int total_count = 0;
  int16_t *retval = NULL;
  regmatch_T regmatch;
  int id;
  bool failed = false;

  // We parse the list twice:
  // round == 1: count the number of items, allocate the array.
  // round == 2: fill the array with the items.
  // In round 1 new groups may be added, causing the number of items to
  // grow when a regexp is used.  In that case round 1 is done once again.
  for (int round = 1; round <= 2; round++) {
    // skip "contains"
    p = skipwhite(*arg + keylen);
    if (*p != '=') {
      EMSG2(_("E405: Missing equal sign: %s"), *arg);
      break;
    }
    p = skipwhite(p + 1);
    if (ends_excmd(*p)) {
      EMSG2(_("E406: Empty argument: %s"), *arg);
      break;
    }

    // parse the arguments after "contains"
    int count = 0;
    do {
      for (end = p; *end && !ascii_iswhite(*end) && *end != ','; end++) {
      }
      char_u *const name = xmalloc((int)(end - p + 3));   // leave room for "^$"
      STRLCPY(name + 1, p, end - p + 1);
      if (       STRCMP(name + 1, "ALLBUT") == 0
                 || STRCMP(name + 1, "ALL") == 0
                 || STRCMP(name + 1, "TOP") == 0
                 || STRCMP(name + 1, "CONTAINED") == 0) {
        if (TOUPPER_ASC(**arg) != 'C') {
          EMSG2(_("E407: %s not allowed here"), name + 1);
          failed = true;
          xfree(name);
          break;
        }
        if (count != 0) {
          EMSG2(_("E408: %s must be first in contains list"),
                name + 1);
          failed = true;
          xfree(name);
          break;
        }
        if (name[1] == 'A')
          id = SYNID_ALLBUT;
        else if (name[1] == 'T')
          id = SYNID_TOP;
        else
          id = SYNID_CONTAINED;
        id += current_syn_inc_tag;
      } else if (name[1] == '@')   {
        if (skip) {
          id = -1;
        } else {
          id = syn_check_cluster(name + 2, (int)(end - p - 1));
        }
      } else {
        /*
         * Handle full group name.
         */
        if (vim_strpbrk(name + 1, (char_u *)"\\.*^$~[") == NULL) {
          id = syn_check_group(name + 1, (int)(end - p));
        } else {
          // Handle match of regexp with group names.
          *name = '^';
          STRCAT(name, "$");
          regmatch.regprog = vim_regcomp(name, RE_MAGIC);
          if (regmatch.regprog == NULL) {
            failed = true;
            xfree(name);
            break;
          }

          regmatch.rm_ic = TRUE;
          id = 0;
          for (int i = highlight_ga.ga_len; --i >= 0; ) {
            if (vim_regexec(&regmatch, HL_TABLE()[i].sg_name, (colnr_T)0)) {
              if (round == 2) {
                // Got more items than expected; can happen
                // when adding items that match:
                // "contains=a.*b,axb".
                // Go back to first round.
                if (count >= total_count) {
                  xfree(retval);
                  round = 1;
                } else {
                  retval[count] = i + 1;  // -V522
                }
              }
              count++;
              id = -1;  // Remember that we found one.
            }
          }
          vim_regfree(regmatch.regprog);
        }
      }
      xfree(name);
      if (id == 0) {
        EMSG2(_("E409: Unknown group name: %s"), p);
        failed = true;
        break;
      }
      if (id > 0) {
        if (round == 2) {
          // Got more items than expected, go back to first round.
          if (count >= total_count) {
            xfree(retval);
            round = 1;
          } else {
            retval[count] = id;
          }
        }
        ++count;
      }
      p = skipwhite(end);
      if (*p != ',')
        break;
      p = skipwhite(p + 1);             /* skip comma in between arguments */
    } while (!ends_excmd(*p));
    if (failed)
      break;
    if (round == 1) {
      retval = xmalloc((count + 1) * sizeof(*retval));
      retval[count] = 0;            // zero means end of the list
      total_count = count;
    }
  }

  *arg = p;
  if (failed || retval == NULL) {
    xfree(retval);
    return FAIL;
  }

  if (*list == NULL)
    *list = retval;
  else
    xfree(retval);           /* list already found, don't overwrite it */

  return OK;
}

/*
 * Make a copy of an ID list.
 */
static int16_t *copy_id_list(const int16_t *const list)
{
  if (list == NULL) {
    return NULL;
  }

  int count;
  for (count = 0; list[count]; count++) {
  }
  const size_t len = (count + 1) * sizeof(int16_t);
  int16_t *const retval = xmalloc(len);
  memmove(retval, list, len);

  return retval;
}

/*
 * Check if syntax group "ssp" is in the ID list "list" of "cur_si".
 * "cur_si" can be NULL if not checking the "containedin" list.
 * Used to check if a syntax item is in the "contains" or "nextgroup" list of
 * the current item.
 * This function is called very often, keep it fast!!
 */
static int
in_id_list(
    stateitem_T *cur_si,    // current item or NULL
    int16_t *list,          // id list
    struct sp_syn *ssp,     // group id and ":syn include" tag of group
    int contained           // group id is contained
)
{
  int retval;
  int16_t *scl_list;
  int16_t item;
  int16_t id = ssp->id;
  static int depth = 0;
  int r;

  /* If ssp has a "containedin" list and "cur_si" is in it, return TRUE. */
  if (cur_si != NULL && ssp->cont_in_list != NULL
      && !(cur_si->si_flags & HL_MATCH)) {
    /* Ignore transparent items without a contains argument.  Double check
     * that we don't go back past the first one. */
    while ((cur_si->si_flags & HL_TRANS_CONT)
           && cur_si > (stateitem_T *)(current_state.ga_data))
      --cur_si;
    /* cur_si->si_idx is -1 for keywords, these never contain anything. */
    if (cur_si->si_idx >= 0 && in_id_list(NULL, ssp->cont_in_list,
            &(SYN_ITEMS(syn_block)[cur_si->si_idx].sp_syn),
            SYN_ITEMS(syn_block)[cur_si->si_idx].sp_flags & HL_CONTAINED))
      return TRUE;
  }

  if (list == NULL)
    return FALSE;

  /*
   * If list is ID_LIST_ALL, we are in a transparent item that isn't
   * inside anything.  Only allow not-contained groups.
   */
  if (list == ID_LIST_ALL)
    return !contained;

  /*
   * If the first item is "ALLBUT", return TRUE if "id" is NOT in the
   * contains list.  We also require that "id" is at the same ":syn include"
   * level as the list.
   */
  item = *list;
  if (item >= SYNID_ALLBUT && item < SYNID_CLUSTER) {
    if (item < SYNID_TOP) {
      /* ALL or ALLBUT: accept all groups in the same file */
      if (item - SYNID_ALLBUT != ssp->inc_tag)
        return FALSE;
    } else if (item < SYNID_CONTAINED)   {
      /* TOP: accept all not-contained groups in the same file */
      if (item - SYNID_TOP != ssp->inc_tag || contained)
        return FALSE;
    } else {
      /* CONTAINED: accept all contained groups in the same file */
      if (item - SYNID_CONTAINED != ssp->inc_tag || !contained)
        return FALSE;
    }
    item = *++list;
    retval = FALSE;
  } else
    retval = TRUE;

  /*
   * Return "retval" if id is in the contains list.
   */
  while (item != 0) {
    if (item == id)
      return retval;
    if (item >= SYNID_CLUSTER) {
      scl_list = SYN_CLSTR(syn_block)[item - SYNID_CLUSTER].scl_list;
      /* restrict recursiveness to 30 to avoid an endless loop for a
       * cluster that includes itself (indirectly) */
      if (scl_list != NULL && depth < 30) {
        ++depth;
        r = in_id_list(NULL, scl_list, ssp, contained);
        --depth;
        if (r)
          return retval;
      }
    }
    item = *++list;
  }
  return !retval;
}

struct subcommand {
  char    *name;                                /* subcommand name */
  void    (*func)(exarg_T *, int);              /* function to call */
};

static struct subcommand subcommands[] =
{
  { "case",      syn_cmd_case },
  { "clear",     syn_cmd_clear },
  { "cluster",   syn_cmd_cluster },
  { "conceal",   syn_cmd_conceal },
  { "enable",    syn_cmd_enable },
  { "include",   syn_cmd_include },
  { "iskeyword", syn_cmd_iskeyword },
  { "keyword",   syn_cmd_keyword },
  { "list",      syn_cmd_list },
  { "manual",    syn_cmd_manual },
  { "match",     syn_cmd_match },
  { "on",        syn_cmd_on },
  { "off",       syn_cmd_off },
  { "region",    syn_cmd_region },
  { "reset",     syn_cmd_reset },
  { "spell",     syn_cmd_spell },
  { "sync",      syn_cmd_sync },
  { "",          syn_cmd_list },
  { NULL, NULL }
};

/*
 * ":syntax".
 * This searches the subcommands[] table for the subcommand name, and calls a
 * syntax_subcommand() function to do the rest.
 */
void ex_syntax(exarg_T *eap)
{
  char_u      *arg = eap->arg;
  char_u      *subcmd_end;
  char_u      *subcmd_name;
  int i;

  syn_cmdlinep = eap->cmdlinep;

  /* isolate subcommand name */
  for (subcmd_end = arg; ASCII_ISALPHA(*subcmd_end); ++subcmd_end)
    ;
  subcmd_name = vim_strnsave(arg, (int)(subcmd_end - arg));
  if (eap->skip)              /* skip error messages for all subcommands */
    ++emsg_skip;
  for (i = 0;; ++i) {
    if (subcommands[i].name == NULL) {
      EMSG2(_("E410: Invalid :syntax subcommand: %s"), subcmd_name);
      break;
    }
    if (STRCMP(subcmd_name, (char_u *)subcommands[i].name) == 0) {
      eap->arg = skipwhite(subcmd_end);
      (subcommands[i].func)(eap, FALSE);
      break;
    }
  }
  xfree(subcmd_name);
  if (eap->skip)
    --emsg_skip;
}

void ex_ownsyntax(exarg_T *eap)
{
  char_u      *old_value;
  char_u      *new_value;

  if (curwin->w_s == &curwin->w_buffer->b_s) {
    curwin->w_s = xmalloc(sizeof(synblock_T));
    memset(curwin->w_s, 0, sizeof(synblock_T));
    hash_init(&curwin->w_s->b_keywtab);
    hash_init(&curwin->w_s->b_keywtab_ic);
    // TODO: Keep the spell checking as it was. NOLINT(readability/todo)
    curwin->w_p_spell = false;  // No spell checking
    clear_string_option(&curwin->w_s->b_p_spc);
    clear_string_option(&curwin->w_s->b_p_spf);
    clear_string_option(&curwin->w_s->b_p_spl);
    clear_string_option(&curwin->w_s->b_syn_isk);
  }

  // Save value of b:current_syntax.
  old_value = get_var_value("b:current_syntax");
  if (old_value != NULL) {
    old_value = vim_strsave(old_value);
  }

  /* Apply the "syntax" autocommand event, this finds and loads the syntax
   * file. */
  apply_autocmds(EVENT_SYNTAX, eap->arg, curbuf->b_fname, TRUE, curbuf);

  // Move value of b:current_syntax to w:current_syntax.
  new_value = get_var_value("b:current_syntax");
  if (new_value != NULL) {
    set_internal_string_var((char_u *)"w:current_syntax", new_value);
  }

  // Restore value of b:current_syntax.
  if (old_value == NULL) {
    do_unlet(S_LEN("b:current_syntax"), true);
  } else {
    set_internal_string_var((char_u *)"b:current_syntax", old_value);
    xfree(old_value);
  }
}

bool syntax_present(win_T *win)
{
  return win->w_s->b_syn_patterns.ga_len != 0
         || win->w_s->b_syn_clusters.ga_len != 0
         || win->w_s->b_keywtab.ht_used > 0
         || win->w_s->b_keywtab_ic.ht_used > 0;
}


static enum {
  EXP_SUBCMD,       // expand ":syn" sub-commands
  EXP_CASE,         // expand ":syn case" arguments
  EXP_SPELL,        // expand ":syn spell" arguments
  EXP_SYNC          // expand ":syn sync" arguments
} expand_what;

/*
 * Reset include_link, include_default, include_none to 0.
 * Called when we are done expanding.
 */
void reset_expand_highlight(void)
{
  include_link = include_default = include_none = 0;
}

/*
 * Handle command line completion for :match and :echohl command: Add "None"
 * as highlight group.
 */
void set_context_in_echohl_cmd(expand_T *xp, const char *arg)
{
  xp->xp_context = EXPAND_HIGHLIGHT;
  xp->xp_pattern = (char_u *)arg;
  include_none = 1;
}

/*
 * Handle command line completion for :syntax command.
 */
void set_context_in_syntax_cmd(expand_T *xp, const char *arg)
{
  // Default: expand subcommands.
  xp->xp_context = EXPAND_SYNTAX;
  expand_what = EXP_SUBCMD;
  xp->xp_pattern = (char_u *)arg;
  include_link = 0;
  include_default = 0;

  /* (part of) subcommand already typed */
  if (*arg != NUL) {
    const char *p = (const char *)skiptowhite((const char_u *)arg);
    if (*p != NUL) {  // Past first word.
      xp->xp_pattern = skipwhite((const char_u *)p);
      if (*skiptowhite(xp->xp_pattern) != NUL) {
        xp->xp_context = EXPAND_NOTHING;
      } else if (STRNICMP(arg, "case", p - arg) == 0) {
        expand_what = EXP_CASE;
      } else if (STRNICMP(arg, "spell", p - arg) == 0) {
        expand_what = EXP_SPELL;
      } else if (STRNICMP(arg, "sync", p - arg) == 0) {
        expand_what = EXP_SYNC;
      } else if (STRNICMP(arg, "keyword", p - arg) == 0
                 || STRNICMP(arg, "region", p - arg) == 0
                 || STRNICMP(arg, "match", p - arg) == 0
                 || STRNICMP(arg, "list", p - arg) == 0) {
        xp->xp_context = EXPAND_HIGHLIGHT;
      } else {
        xp->xp_context = EXPAND_NOTHING;
      }
    }
  }
}

/*
 * Function given to ExpandGeneric() to obtain the list syntax names for
 * expansion.
 */
char_u *get_syntax_name(expand_T *xp, int idx)
{
  switch (expand_what) {
    case EXP_SUBCMD:
        return (char_u *)subcommands[idx].name;
    case EXP_CASE: {
        static char *case_args[] = { "match", "ignore", NULL };
        return (char_u *)case_args[idx];
    }
    case EXP_SPELL: {
        static char *spell_args[] =
        { "toplevel", "notoplevel", "default", NULL };
        return (char_u *)spell_args[idx];
    }
    case EXP_SYNC: {
        static char *sync_args[] =
        { "ccomment", "clear", "fromstart",
         "linebreaks=", "linecont", "lines=", "match",
         "maxlines=", "minlines=", "region", NULL };
        return (char_u *)sync_args[idx];
    }
  }
  return NULL;
}


// Function called for expression evaluation: get syntax ID at file position.
int syn_get_id(
    win_T *wp,
    long lnum,
    colnr_T col,
    int trans,      // remove transparency
    bool *spellp,   // return: can do spell checking
    int keep_state  // keep state of char at "col"
)
{
  // When the position is not after the current position and in the same
  // line of the same buffer, need to restart parsing.
  if (wp->w_buffer != syn_buf || lnum != current_lnum || col < current_col) {
    syntax_start(wp, lnum);
  } else if (col > current_col) {
      // next_match may not be correct when moving around, e.g. with the
      // "skip" expression in searchpair()
      next_match_idx = -1;
  }

  (void)get_syntax_attr(col, spellp, keep_state);

  return trans ? current_trans_id : current_id;
}

/*
 * Get extra information about the syntax item.  Must be called right after
 * get_syntax_attr().
 * Stores the current item sequence nr in "*seqnrp".
 * Returns the current flags.
 */
int get_syntax_info(int *seqnrp)
{
  *seqnrp = current_seqnr;
  return current_flags;
}


/// Get the sequence number of the concealed file position.
///
/// @return seqnr if the file position is concealed, 0 otherwise.
int syn_get_concealed_id(win_T *wp, linenr_T lnum, colnr_T col)
{
  int seqnr;
  int syntax_flags;

  (void)syn_get_id(wp, lnum, col, false, NULL, false);
  syntax_flags = get_syntax_info(&seqnr);

  if (syntax_flags & HL_CONCEAL) {
    return seqnr;
  }
  return 0;
}

/*
 * Return conceal substitution character
 */
int syn_get_sub_char(void)
{
  return current_sub_char;
}

/*
 * Return the syntax ID at position "i" in the current stack.
 * The caller must have called syn_get_id() before to fill the stack.
 * Returns -1 when "i" is out of range.
 */
int syn_get_stack_item(int i)
{
  if (i >= current_state.ga_len) {
    /* Need to invalidate the state, because we didn't properly finish it
     * for the last character, "keep_state" was TRUE. */
    invalidate_current_state();
    current_col = MAXCOL;
    return -1;
  }
  return CUR_STATE(i).si_id;
}

/*
 * Function called to get folding level for line "lnum" in window "wp".
 */
int syn_get_foldlevel(win_T *wp, long lnum)
{
  int level = 0;

  // Return quickly when there are no fold items at all.
  if (wp->w_s->b_syn_folditems != 0
      && !wp->w_s->b_syn_error
      && !wp->w_s->b_syn_slow) {
    syntax_start(wp, lnum);

    for (int i = 0; i < current_state.ga_len; ++i) {
      if (CUR_STATE(i).si_flags & HL_FOLD) {
        ++level;
      }
    }
  }
  if (level > wp->w_p_fdn) {
    level = wp->w_p_fdn;
    if (level < 0)
      level = 0;
  }
  return level;
}

/*
 * ":syntime".
 */
void ex_syntime(exarg_T *eap)
{
  if (STRCMP(eap->arg, "on") == 0)
    syn_time_on = TRUE;
  else if (STRCMP(eap->arg, "off") == 0)
    syn_time_on = FALSE;
  else if (STRCMP(eap->arg, "clear") == 0)
    syntime_clear();
  else if (STRCMP(eap->arg, "report") == 0)
    syntime_report();
  else
    EMSG2(_(e_invarg2), eap->arg);
}

static void syn_clear_time(syn_time_T *st)
{
  st->total = profile_zero();
  st->slowest = profile_zero();
  st->count = 0;
  st->match = 0;
}

/*
 * Clear the syntax timing for the current buffer.
 */
static void syntime_clear(void)
{
  synpat_T    *spp;

  if (!syntax_present(curwin)) {
    MSG(_(msg_no_items));
    return;
  }
  for (int idx = 0; idx < curwin->w_s->b_syn_patterns.ga_len; ++idx) {
    spp = &(SYN_ITEMS(curwin->w_s)[idx]);
    syn_clear_time(&spp->sp_time);
  }
}

/*
 * Function given to ExpandGeneric() to obtain the possible arguments of the
 * ":syntime {on,off,clear,report}" command.
 */
char_u *get_syntime_arg(expand_T *xp, int idx)
{
  switch (idx) {
  case 0: return (char_u *)"on";
  case 1: return (char_u *)"off";
  case 2: return (char_u *)"clear";
  case 3: return (char_u *)"report";
  }
  return NULL;
}

static int syn_compare_syntime(const void *v1, const void *v2)
{
  const time_entry_T  *s1 = v1;
  const time_entry_T  *s2 = v2;

  return profile_cmp(s1->total, s2->total);
}

/*
 * Clear the syntax timing for the current buffer.
 */
static void syntime_report(void)
{
  if (!syntax_present(curwin)) {
    MSG(_(msg_no_items));
    return;
  }

  garray_T ga;
  ga_init(&ga, sizeof(time_entry_T), 50);

  proftime_T total_total = profile_zero();
  int total_count = 0;
  time_entry_T *p;
  for (int idx = 0; idx < curwin->w_s->b_syn_patterns.ga_len; ++idx) {
    synpat_T *spp = &(SYN_ITEMS(curwin->w_s)[idx]);
    if (spp->sp_time.count > 0) {
      p = GA_APPEND_VIA_PTR(time_entry_T, &ga);
      p->total = spp->sp_time.total;
      total_total = profile_add(total_total, spp->sp_time.total);
      p->count = spp->sp_time.count;
      p->match = spp->sp_time.match;
      total_count += spp->sp_time.count;
      p->slowest = spp->sp_time.slowest;
      proftime_T tm = profile_divide(spp->sp_time.total, spp->sp_time.count);
      p->average = tm;
      p->id = spp->sp_syn.id;
      p->pattern = spp->sp_pattern;
    }
  }

  // Sort on total time. Skip if there are no items to avoid passing NULL
  // pointer to qsort().
  if (ga.ga_len > 1) {
    qsort(ga.ga_data, (size_t)ga.ga_len, sizeof(time_entry_T),
          syn_compare_syntime);
  }

  MSG_PUTS_TITLE(_(
          "  TOTAL      COUNT  MATCH   SLOWEST     AVERAGE   NAME               PATTERN"));
  MSG_PUTS("\n");
  for (int idx = 0; idx < ga.ga_len && !got_int; ++idx) {
    p = ((time_entry_T *)ga.ga_data) + idx;

    MSG_PUTS(profile_msg(p->total));
    MSG_PUTS(" ");     /* make sure there is always a separating space */
    msg_advance(13);
    msg_outnum(p->count);
    MSG_PUTS(" ");
    msg_advance(20);
    msg_outnum(p->match);
    MSG_PUTS(" ");
    msg_advance(26);
    MSG_PUTS(profile_msg(p->slowest));
    MSG_PUTS(" ");
    msg_advance(38);
    MSG_PUTS(profile_msg(p->average));
    MSG_PUTS(" ");
    msg_advance(50);
    msg_outtrans(HL_TABLE()[p->id - 1].sg_name);
    MSG_PUTS(" ");

    msg_advance(69);
    int len;
    if (Columns < 80)
      len = 20;       /* will wrap anyway */
    else
      len = Columns - 70;
    if (len > (int)STRLEN(p->pattern))
      len = (int)STRLEN(p->pattern);
    msg_outtrans_len(p->pattern, len);
    MSG_PUTS("\n");
  }
  ga_clear(&ga);
  if (!got_int) {
    MSG_PUTS("\n");
    MSG_PUTS(profile_msg(total_total));
    msg_advance(13);
    msg_outnum(total_count);
    MSG_PUTS("\n");
  }
}

/**************************************
*  Highlighting stuff		      *
**************************************/

// The default highlight groups.  These are compiled-in for fast startup and
// they still work when the runtime files can't be found.
//
// When making changes here, also change runtime/colors/default.vim!

static const char *highlight_init_both[] = {
  "Conceal "
      "ctermbg=DarkGrey ctermfg=LightGrey guibg=DarkGrey guifg=LightGrey",
  "Cursor       guibg=fg guifg=bg",
  "lCursor      guibg=fg guifg=bg",
  "DiffText     cterm=bold ctermbg=Red gui=bold guibg=Red",
  "ErrorMsg     ctermbg=DarkRed ctermfg=White guibg=Red guifg=White",
  "IncSearch    cterm=reverse gui=reverse",
  "ModeMsg      cterm=bold gui=bold",
  "NonText      ctermfg=Blue gui=bold guifg=Blue",
  "PmenuSbar    ctermbg=Grey guibg=Grey",
  "StatusLine   cterm=reverse,bold gui=reverse,bold",
  "StatusLineNC cterm=reverse gui=reverse",
  "TabLineFill  cterm=reverse gui=reverse",
  "TabLineSel   cterm=bold gui=bold",
  "TermCursor   cterm=reverse gui=reverse",
  "VertSplit    cterm=reverse gui=reverse",
  "WildMenu     ctermbg=Yellow ctermfg=Black guibg=Yellow guifg=Black",
  "default link EndOfBuffer NonText",
  "default link QuickFixLine Search",
  "default link Substitute Search",
  "default link Whitespace NonText",
  "default link MsgSeparator StatusLine",
  "default link NormalFloat Pmenu",
  "RedrawDebugNormal cterm=reverse gui=reverse",
  "RedrawDebugClear ctermbg=Yellow guibg=Yellow",
  "RedrawDebugComposed ctermbg=Green guibg=Green",
  "RedrawDebugRecompose ctermbg=Red guibg=Red",
  NULL
};

// Default colors only used with a light background.
static const char *highlight_init_light[] = {
  "ColorColumn  ctermbg=LightRed guibg=LightRed",
  "CursorColumn ctermbg=LightGrey guibg=Grey90",
  "CursorLine   cterm=underline guibg=Grey90",
  "CursorLineNr ctermfg=Brown gui=bold guifg=Brown",
  "DiffAdd      ctermbg=LightBlue guibg=LightBlue",
  "DiffChange   ctermbg=LightMagenta guibg=LightMagenta",
  "DiffDelete   ctermfg=Blue ctermbg=LightCyan gui=bold guifg=Blue guibg=LightCyan",
  "Directory    ctermfg=DarkBlue guifg=Blue",
  "FoldColumn   ctermbg=Grey ctermfg=DarkBlue guibg=Grey guifg=DarkBlue",
  "Folded       ctermbg=Grey ctermfg=DarkBlue guibg=LightGrey guifg=DarkBlue",
  "LineNr       ctermfg=Brown guifg=Brown",
  "MatchParen   ctermbg=Cyan guibg=Cyan",
  "MoreMsg      ctermfg=DarkGreen gui=bold guifg=SeaGreen",
  "Pmenu        ctermbg=LightMagenta ctermfg=Black guibg=LightMagenta",
  "PmenuSel     ctermbg=LightGrey ctermfg=Black guibg=Grey",
  "PmenuThumb   ctermbg=Black guibg=Black",
  "Question     ctermfg=DarkGreen gui=bold guifg=SeaGreen",
  "Search       ctermbg=Yellow ctermfg=NONE guibg=Yellow guifg=NONE",
  "SignColumn   ctermbg=Grey ctermfg=DarkBlue guibg=Grey guifg=DarkBlue",
  "SpecialKey   ctermfg=DarkBlue guifg=Blue",
  "SpellBad     ctermbg=LightRed guisp=Red gui=undercurl",
  "SpellCap     ctermbg=LightBlue guisp=Blue gui=undercurl",
  "SpellLocal   ctermbg=Cyan guisp=DarkCyan gui=undercurl",
  "SpellRare    ctermbg=LightMagenta guisp=Magenta gui=undercurl",
  "TabLine      cterm=underline ctermfg=black ctermbg=LightGrey gui=underline guibg=LightGrey",
  "Title        ctermfg=DarkMagenta gui=bold guifg=Magenta",
  "Visual       guibg=LightGrey",
  "WarningMsg   ctermfg=DarkRed guifg=Red",
  "Normal       gui=NONE",
  NULL
};

// Default colors only used with a dark background.
static const char *highlight_init_dark[] = {
  "ColorColumn  ctermbg=DarkRed guibg=DarkRed",
  "CursorColumn ctermbg=DarkGrey guibg=Grey40",
  "CursorLine   cterm=underline guibg=Grey40",
  "CursorLineNr ctermfg=Yellow gui=bold guifg=Yellow",
  "DiffAdd      ctermbg=DarkBlue guibg=DarkBlue",
  "DiffChange   ctermbg=DarkMagenta guibg=DarkMagenta",
  "DiffDelete   ctermfg=Blue ctermbg=DarkCyan gui=bold guifg=Blue guibg=DarkCyan",
  "Directory    ctermfg=LightCyan guifg=Cyan",
  "FoldColumn   ctermbg=DarkGrey ctermfg=Cyan guibg=Grey guifg=Cyan",
  "Folded       ctermbg=DarkGrey ctermfg=Cyan guibg=DarkGrey guifg=Cyan",
  "LineNr       ctermfg=Yellow guifg=Yellow",
  "MatchParen   ctermbg=DarkCyan guibg=DarkCyan",
  "MoreMsg      ctermfg=LightGreen gui=bold guifg=SeaGreen",
  "Pmenu        ctermbg=Magenta ctermfg=Black guibg=Magenta",
  "PmenuSel     ctermbg=Black ctermfg=DarkGrey guibg=DarkGrey",
  "PmenuThumb   ctermbg=White guibg=White",
  "Question     ctermfg=LightGreen gui=bold guifg=Green",
  "Search       ctermbg=Yellow ctermfg=Black guibg=Yellow guifg=Black",
  "SignColumn   ctermbg=DarkGrey ctermfg=Cyan guibg=Grey guifg=Cyan",
  "SpecialKey   ctermfg=LightBlue guifg=Cyan",
  "SpellBad     ctermbg=Red guisp=Red gui=undercurl",
  "SpellCap     ctermbg=Blue guisp=Blue gui=undercurl",
  "SpellLocal   ctermbg=Cyan guisp=Cyan gui=undercurl",
  "SpellRare    ctermbg=Magenta guisp=Magenta gui=undercurl",
  "TabLine      cterm=underline ctermfg=white ctermbg=DarkGrey gui=underline guibg=DarkGrey",
  "Title        ctermfg=LightMagenta gui=bold guifg=Magenta",
  "Visual       guibg=DarkGrey",
  "WarningMsg   ctermfg=LightRed guifg=Red",
  "Normal       gui=NONE",
  NULL
};

const char *const highlight_init_cmdline[] = {
  // XXX When modifying a list modify it in both valid and invalid halfs.
  // TODO(ZyX-I): merge valid and invalid groups via a macros.

  // NvimInternalError should appear only when highlighter has a bug.
  "NvimInternalError ctermfg=Red ctermbg=Red guifg=Red guibg=Red",

  // Highlight groups (links) used by parser:

  "default link NvimAssignment Operator",
  "default link NvimPlainAssignment NvimAssignment",
  "default link NvimAugmentedAssignment NvimAssignment",
  "default link NvimAssignmentWithAddition NvimAugmentedAssignment",
  "default link NvimAssignmentWithSubtraction NvimAugmentedAssignment",
  "default link NvimAssignmentWithConcatenation NvimAugmentedAssignment",

  "default link NvimOperator Operator",

  "default link NvimUnaryOperator NvimOperator",
  "default link NvimUnaryPlus NvimUnaryOperator",
  "default link NvimUnaryMinus NvimUnaryOperator",
  "default link NvimNot NvimUnaryOperator",

  "default link NvimBinaryOperator NvimOperator",
  "default link NvimComparison NvimBinaryOperator",
  "default link NvimComparisonModifier NvimComparison",
  "default link NvimBinaryPlus NvimBinaryOperator",
  "default link NvimBinaryMinus NvimBinaryOperator",
  "default link NvimConcat NvimBinaryOperator",
  "default link NvimConcatOrSubscript NvimConcat",
  "default link NvimOr NvimBinaryOperator",
  "default link NvimAnd NvimBinaryOperator",
  "default link NvimMultiplication NvimBinaryOperator",
  "default link NvimDivision NvimBinaryOperator",
  "default link NvimMod NvimBinaryOperator",

  "default link NvimTernary NvimOperator",
  "default link NvimTernaryColon NvimTernary",

  "default link NvimParenthesis Delimiter",
  "default link NvimLambda NvimParenthesis",
  "default link NvimNestingParenthesis NvimParenthesis",
  "default link NvimCallingParenthesis NvimParenthesis",

  "default link NvimSubscript NvimParenthesis",
  "default link NvimSubscriptBracket NvimSubscript",
  "default link NvimSubscriptColon NvimSubscript",
  "default link NvimCurly NvimSubscript",

  "default link NvimContainer NvimParenthesis",
  "default link NvimDict NvimContainer",
  "default link NvimList NvimContainer",

  "default link NvimIdentifier Identifier",
  "default link NvimIdentifierScope NvimIdentifier",
  "default link NvimIdentifierScopeDelimiter NvimIdentifier",
  "default link NvimIdentifierName NvimIdentifier",
  "default link NvimIdentifierKey NvimIdentifier",

  "default link NvimColon Delimiter",
  "default link NvimComma Delimiter",
  "default link NvimArrow Delimiter",

  "default link NvimRegister SpecialChar",
  "default link NvimNumber Number",
  "default link NvimFloat NvimNumber",
  "default link NvimNumberPrefix Type",

  "default link NvimOptionSigil Type",
  "default link NvimOptionName NvimIdentifier",
  "default link NvimOptionScope NvimIdentifierScope",
  "default link NvimOptionScopeDelimiter NvimIdentifierScopeDelimiter",

  "default link NvimEnvironmentSigil NvimOptionSigil",
  "default link NvimEnvironmentName NvimIdentifier",

  "default link NvimString String",
  "default link NvimStringBody NvimString",
  "default link NvimStringQuote NvimString",
  "default link NvimStringSpecial SpecialChar",

  "default link NvimSingleQuote NvimStringQuote",
  "default link NvimSingleQuotedBody NvimStringBody",
  "default link NvimSingleQuotedQuote NvimStringSpecial",

  "default link NvimDoubleQuote NvimStringQuote",
  "default link NvimDoubleQuotedBody NvimStringBody",
  "default link NvimDoubleQuotedEscape NvimStringSpecial",

  "default link NvimFigureBrace NvimInternalError",
  "default link NvimSingleQuotedUnknownEscape NvimInternalError",

  "default link NvimSpacing Normal",

  // NvimInvalid groups:

  "default link NvimInvalidSingleQuotedUnknownEscape NvimInternalError",

  "default link NvimInvalid Error",

  "default link NvimInvalidAssignment NvimInvalid",
  "default link NvimInvalidPlainAssignment NvimInvalidAssignment",
  "default link NvimInvalidAugmentedAssignment NvimInvalidAssignment",
  "default link NvimInvalidAssignmentWithAddition "
      "NvimInvalidAugmentedAssignment",
  "default link NvimInvalidAssignmentWithSubtraction "
      "NvimInvalidAugmentedAssignment",
  "default link NvimInvalidAssignmentWithConcatenation "
      "NvimInvalidAugmentedAssignment",

  "default link NvimInvalidOperator NvimInvalid",

  "default link NvimInvalidUnaryOperator NvimInvalidOperator",
  "default link NvimInvalidUnaryPlus NvimInvalidUnaryOperator",
  "default link NvimInvalidUnaryMinus NvimInvalidUnaryOperator",
  "default link NvimInvalidNot NvimInvalidUnaryOperator",

  "default link NvimInvalidBinaryOperator NvimInvalidOperator",
  "default link NvimInvalidComparison NvimInvalidBinaryOperator",
  "default link NvimInvalidComparisonModifier NvimInvalidComparison",
  "default link NvimInvalidBinaryPlus NvimInvalidBinaryOperator",
  "default link NvimInvalidBinaryMinus NvimInvalidBinaryOperator",
  "default link NvimInvalidConcat NvimInvalidBinaryOperator",
  "default link NvimInvalidConcatOrSubscript NvimInvalidConcat",
  "default link NvimInvalidOr NvimInvalidBinaryOperator",
  "default link NvimInvalidAnd NvimInvalidBinaryOperator",
  "default link NvimInvalidMultiplication NvimInvalidBinaryOperator",
  "default link NvimInvalidDivision NvimInvalidBinaryOperator",
  "default link NvimInvalidMod NvimInvalidBinaryOperator",

  "default link NvimInvalidTernary NvimInvalidOperator",
  "default link NvimInvalidTernaryColon NvimInvalidTernary",

  "default link NvimInvalidDelimiter NvimInvalid",

  "default link NvimInvalidParenthesis NvimInvalidDelimiter",
  "default link NvimInvalidLambda NvimInvalidParenthesis",
  "default link NvimInvalidNestingParenthesis NvimInvalidParenthesis",
  "default link NvimInvalidCallingParenthesis NvimInvalidParenthesis",

  "default link NvimInvalidSubscript NvimInvalidParenthesis",
  "default link NvimInvalidSubscriptBracket NvimInvalidSubscript",
  "default link NvimInvalidSubscriptColon NvimInvalidSubscript",
  "default link NvimInvalidCurly NvimInvalidSubscript",

  "default link NvimInvalidContainer NvimInvalidParenthesis",
  "default link NvimInvalidDict NvimInvalidContainer",
  "default link NvimInvalidList NvimInvalidContainer",

  "default link NvimInvalidValue NvimInvalid",

  "default link NvimInvalidIdentifier NvimInvalidValue",
  "default link NvimInvalidIdentifierScope NvimInvalidIdentifier",
  "default link NvimInvalidIdentifierScopeDelimiter NvimInvalidIdentifier",
  "default link NvimInvalidIdentifierName NvimInvalidIdentifier",
  "default link NvimInvalidIdentifierKey NvimInvalidIdentifier",

  "default link NvimInvalidColon NvimInvalidDelimiter",
  "default link NvimInvalidComma NvimInvalidDelimiter",
  "default link NvimInvalidArrow NvimInvalidDelimiter",

  "default link NvimInvalidRegister NvimInvalidValue",
  "default link NvimInvalidNumber NvimInvalidValue",
  "default link NvimInvalidFloat NvimInvalidNumber",
  "default link NvimInvalidNumberPrefix NvimInvalidNumber",

  "default link NvimInvalidOptionSigil NvimInvalidIdentifier",
  "default link NvimInvalidOptionName NvimInvalidIdentifier",
  "default link NvimInvalidOptionScope NvimInvalidIdentifierScope",
  "default link NvimInvalidOptionScopeDelimiter "
      "NvimInvalidIdentifierScopeDelimiter",

  "default link NvimInvalidEnvironmentSigil NvimInvalidOptionSigil",
  "default link NvimInvalidEnvironmentName NvimInvalidIdentifier",

  // Invalid string bodies and specials are still highlighted as valid ones to
  // minimize the red area.
  "default link NvimInvalidString NvimInvalidValue",
  "default link NvimInvalidStringBody NvimStringBody",
  "default link NvimInvalidStringQuote NvimInvalidString",
  "default link NvimInvalidStringSpecial NvimStringSpecial",

  "default link NvimInvalidSingleQuote NvimInvalidStringQuote",
  "default link NvimInvalidSingleQuotedBody NvimInvalidStringBody",
  "default link NvimInvalidSingleQuotedQuote NvimInvalidStringSpecial",

  "default link NvimInvalidDoubleQuote NvimInvalidStringQuote",
  "default link NvimInvalidDoubleQuotedBody NvimInvalidStringBody",
  "default link NvimInvalidDoubleQuotedEscape NvimInvalidStringSpecial",
  "default link NvimInvalidDoubleQuotedUnknownEscape NvimInvalidValue",

  "default link NvimInvalidFigureBrace NvimInvalidDelimiter",

  "default link NvimInvalidSpacing ErrorMsg",

  // Not actually invalid, but we highlight user that he is doing something
  // wrong.
  "default link NvimDoubleQuotedUnknownEscape NvimInvalidValue",
  NULL,
};

/// Create default links for Nvim* highlight groups used for cmdline coloring
void syn_init_cmdline_highlight(bool reset, bool init)
{
  for (size_t i = 0 ; highlight_init_cmdline[i] != NULL ; i++) {
    do_highlight(highlight_init_cmdline[i], reset, init);
  }
}

/// Load colors from a file if "g:colors_name" is set, otherwise load builtin
/// colors
///
/// @param both include groups where 'bg' doesn't matter
/// @param reset clear groups first
void init_highlight(bool both, bool reset)
{
  static int had_both = false;

  // Try finding the color scheme file.  Used when a color file was loaded
  // and 'background' or 't_Co' is changed.
  char_u *p = get_var_value("g:colors_name");
  if (p != NULL) {
    // Value of g:colors_name could be freed in load_colors() and make
    // p invalid, so copy it.
    char_u *copy_p = vim_strsave(p);
    bool okay = load_colors(copy_p);
    xfree(copy_p);
    if (okay) {
        return;
    }
  }

  /*
   * Didn't use a color file, use the compiled-in colors.
   */
  if (both) {
    had_both = true;
    const char *const *const pp = highlight_init_both;
    for (size_t i = 0; pp[i] != NULL; i++) {
      do_highlight(pp[i], reset, true);
    }
  } else if (!had_both) {
    // Don't do anything before the call with both == TRUE from main().
    // Not everything has been setup then, and that call will overrule
    // everything anyway.
    return;
  }

  const char *const *const pp = ((*p_bg == 'l')
                                 ? highlight_init_light
                                 : highlight_init_dark);
  for (size_t i = 0; pp[i] != NULL; i++) {
    do_highlight(pp[i], reset, true);
  }

  /* Reverse looks ugly, but grey may not work for 8 colors.  Thus let it
   * depend on the number of colors available.
   * With 8 colors brown is equal to yellow, need to use black for Search fg
   * to avoid Statement highlighted text disappears.
   * Clear the attributes, needed when changing the t_Co value. */
  if (t_colors > 8) {
    do_highlight(
        (*p_bg == 'l'
         ? "Visual cterm=NONE ctermbg=LightGrey"
         : "Visual cterm=NONE ctermbg=DarkGrey"), false, true);
  } else {
    do_highlight("Visual cterm=reverse ctermbg=NONE", false, true);
    if (*p_bg == 'l') {
      do_highlight("Search ctermfg=black", false, true);
    }
  }

  /*
   * If syntax highlighting is enabled load the highlighting for it.
   */
  if (get_var_value("g:syntax_on") != NULL) {
    static int recursive = 0;

    if (recursive >= 5) {
      EMSG(_("E679: recursive loop loading syncolor.vim"));
    } else {
      recursive++;
      (void)source_runtime((char_u *)"syntax/syncolor.vim", DIP_ALL);
      recursive--;
    }
  }
  syn_init_cmdline_highlight(false, false);
}

/*
 * Load color file "name".
 * Return OK for success, FAIL for failure.
 */
int load_colors(char_u *name)
{
  char_u      *buf;
  int retval = FAIL;
  static int recursive = false;

  // When being called recursively, this is probably because setting
  // 'background' caused the highlighting to be reloaded.  This means it is
  // working, thus we should return OK.
  if (recursive) {
    return OK;
  }

  recursive = true;
  size_t buflen = STRLEN(name) + 12;
  buf = xmalloc(buflen);
  apply_autocmds(EVENT_COLORSCHEMEPRE, name, curbuf->b_fname, false, curbuf);
  snprintf((char *)buf, buflen, "colors/%s.vim", name);
  retval = source_runtime(buf, DIP_START + DIP_OPT);
  xfree(buf);
  apply_autocmds(EVENT_COLORSCHEME, name, curbuf->b_fname, FALSE, curbuf);

  recursive = false;

  return retval;
}

static char *(color_names[28]) = {
  "Black", "DarkBlue", "DarkGreen", "DarkCyan",
  "DarkRed", "DarkMagenta", "Brown", "DarkYellow",
  "Gray", "Grey", "LightGray", "LightGrey",
  "DarkGray", "DarkGrey",
  "Blue", "LightBlue", "Green", "LightGreen",
  "Cyan", "LightCyan", "Red", "LightRed", "Magenta",
  "LightMagenta", "Yellow", "LightYellow", "White", "NONE" };
  // indices:
  // 0, 1, 2, 3,
  // 4, 5, 6, 7,
  // 8, 9, 10, 11,
  // 12, 13,
  // 14, 15, 16, 17,
  // 18, 19, 20, 21, 22,
  // 23, 24, 25, 26, 27
static int color_numbers_16[28] = { 0, 1, 2, 3,
  4, 5, 6, 6,
  7, 7, 7, 7,
  8, 8,
  9, 9, 10, 10,
  11, 11, 12, 12, 13,
  13, 14, 14, 15, -1 };
// for xterm with 88 colors...
static int color_numbers_88[28] = { 0, 4, 2, 6,
  1, 5, 32, 72,
  84, 84, 7, 7,
  82, 82,
  12, 43, 10, 61,
  14, 63, 9, 74, 13,
  75, 11, 78, 15, -1 };
// for xterm with 256 colors...
static int color_numbers_256[28] = { 0, 4, 2, 6,
  1, 5, 130, 130,
  248, 248, 7, 7,
  242, 242,
  12, 81, 10, 121,
  14, 159, 9, 224, 13,
  225, 11, 229, 15, -1 };
// for terminals with less than 16 colors...
static int color_numbers_8[28] = { 0, 4, 2, 6,
  1, 5, 3, 3,
  7, 7, 7, 7,
  0+8, 0+8,
  4+8, 4+8, 2+8, 2+8,
  6+8, 6+8, 1+8, 1+8, 5+8,
  5+8, 3+8, 3+8, 7+8, -1 };

// Lookup the "cterm" value to be used for color with index "idx" in
// color_names[].
// "boldp" will be set to TRUE or FALSE for a foreground color when using 8
// colors, otherwise it will be unchanged.
int lookup_color(const int idx, const bool foreground, TriState *const boldp)
{
  int color = color_numbers_16[idx];

  // Use the _16 table to check if it's a valid color name.
  if (color < 0) {
    return -1;
  }

  if (t_colors == 8) {
    // t_Co is 8: use the 8 colors table
    color = color_numbers_8[idx];
    if (foreground) {
      // set/reset bold attribute to get light foreground
      // colors (on some terminals, e.g. "linux")
      if (color & 8) {
        *boldp = kTrue;
      } else {
        *boldp = kFalse;
      }
    }
    color &= 7;   // truncate to 8 colors
  } else if (t_colors == 16) {
    color = color_numbers_8[idx];
  } else if (t_colors == 88) {
    color = color_numbers_88[idx];
  } else if (t_colors >= 256) {
    color = color_numbers_256[idx];
  }
  return color;
}


/// Handle ":highlight" command
///
/// When using ":highlight clear" this is called recursively for each group with
/// forceit and init being both true.
///
/// @param[in]  line  Command arguments.
/// @param[in]  forceit  True when bang is given, allows to link group even if
///                      it has its own settings.
/// @param[in]  init  True when initializing.
void do_highlight(const char *line, const bool forceit, const bool init)
  FUNC_ATTR_NONNULL_ALL
{
  const char *name_end;
  const char *linep;
  const char *key_start;
  const char *arg_start;
  long i;
  int off;
  int len;
  int attr;
  int id;
  int idx;
  struct hl_group item_before;
  bool did_change = false;
  bool dodefault = false;
  bool doclear = false;
  bool dolink = false;
  bool error = false;
  int color;
  bool is_normal_group = false;   // "Normal" group
  bool did_highlight_changed = false;

  // If no argument, list current highlighting.
  if (ends_excmd((uint8_t)(*line))) {
    for (i = 1; i <= highlight_ga.ga_len && !got_int; i++) {
      // TODO(brammool): only call when the group has attributes set
      highlight_list_one(i);
    }
    return;
  }

  // Isolate the name.
  name_end = (const char *)skiptowhite((const char_u *)line);
  linep = (const char *)skipwhite((const char_u *)name_end);

  // Check for "default" argument.
  if (strncmp(line, "default", name_end - line) == 0) {
    dodefault = true;
    line = linep;
    name_end = (const char *)skiptowhite((const char_u *)line);
    linep = (const char *)skipwhite((const char_u *)name_end);
  }

  // Check for "clear" or "link" argument.
  if (strncmp(line, "clear", name_end - line) == 0) {
    doclear = true;
  } else if (strncmp(line, "link", name_end - line) == 0) {
    dolink = true;
  }

  // ":highlight {group-name}": list highlighting for one group.
  if (!doclear && !dolink && ends_excmd((uint8_t)(*linep))) {
    id = syn_namen2id((const char_u *)line, (int)(name_end - line));
    if (id == 0) {
      emsgf(_("E411: highlight group not found: %s"), line);
    } else {
      highlight_list_one(id);
    }
    return;
  }

  // Handle ":highlight link {from} {to}" command.
  if (dolink) {
    const char *from_start = linep;
    const char *from_end;
    const char *to_start;
    const char *to_end;
    int from_id;
    int to_id;

    from_end = (const char *)skiptowhite((const char_u *)from_start);
    to_start = (const char *)skipwhite((const char_u *)from_end);
    to_end   = (const char *)skiptowhite((const char_u *)to_start);

    if (ends_excmd((uint8_t)(*from_start))
        || ends_excmd((uint8_t)(*to_start))) {
      emsgf(_("E412: Not enough arguments: \":highlight link %s\""),
            from_start);
      return;
    }

    if (!ends_excmd(*skipwhite((const char_u *)to_end))) {
      emsgf(_("E413: Too many arguments: \":highlight link %s\""), from_start);
      return;
    }

    from_id = syn_check_group((const char_u *)from_start,
                              (int)(from_end - from_start));
    if (strncmp(to_start, "NONE", 4) == 0) {
      to_id = 0;
    } else {
      to_id = syn_check_group((const char_u *)to_start,
                              (int)(to_end - to_start));
    }

    if (from_id > 0 && (!init || HL_TABLE()[from_id - 1].sg_set == 0)) {
      // Don't allow a link when there already is some highlighting
      // for the group, unless '!' is used
      if (to_id > 0 && !forceit && !init
          && hl_has_settings(from_id - 1, dodefault)) {
        if (sourcing_name == NULL && !dodefault) {
          EMSG(_("E414: group has settings, highlight link ignored"));
        }
      } else if (HL_TABLE()[from_id - 1].sg_link != to_id
                 || HL_TABLE()[from_id - 1].sg_script_ctx.sc_sid
                 != current_sctx.sc_sid
                 || HL_TABLE()[from_id - 1].sg_cleared) {
        if (!init) {
          HL_TABLE()[from_id - 1].sg_set |= SG_LINK;
        }
        HL_TABLE()[from_id - 1].sg_link = to_id;
        HL_TABLE()[from_id - 1].sg_script_ctx = current_sctx;
        HL_TABLE()[from_id - 1].sg_script_ctx.sc_lnum += sourcing_lnum;
        HL_TABLE()[from_id - 1].sg_cleared = false;
        redraw_all_later(SOME_VALID);

        // Only call highlight changed() once after multiple changes
        need_highlight_changed = true;
      }
    }

    return;
  }

  if (doclear) {
    // ":highlight clear [group]" command.
    line = linep;
    if (ends_excmd((uint8_t)(*line))) {
      do_unlet(S_LEN("colors_name"), true);
      restore_cterm_colors();

      // Clear all default highlight groups and load the defaults.
      for (int j = 0; j < highlight_ga.ga_len; j++) {
        highlight_clear(j);
      }
      init_highlight(true, true);
      highlight_changed();
      redraw_all_later(NOT_VALID);
      return;
    }
    name_end = (const char *)skiptowhite((const char_u *)line);
    linep = (const char *)skipwhite((const char_u *)name_end);
  }

  // Find the group name in the table.  If it does not exist yet, add it.
  id = syn_check_group((const char_u *)line, (int)(name_end - line));
  if (id == 0) {  // Failed (out of memory).
    return;
  }
  idx = id - 1;  // Index is ID minus one.

  // Return if "default" was used and the group already has settings
  if (dodefault && hl_has_settings(idx, true)) {
    return;
  }

  // Make a copy so we can check if any attribute actually changed
  item_before = HL_TABLE()[idx];
  is_normal_group = (STRCMP(HL_TABLE()[idx].sg_name_u, "NORMAL") == 0);

  // Clear the highlighting for ":hi clear {group}" and ":hi clear".
  if (doclear || (forceit && init)) {
    highlight_clear(idx);
    if (!doclear) {
      HL_TABLE()[idx].sg_set = 0;
    }
  }

  char *key = NULL;
  char *arg = NULL;
  if (!doclear) {
    while (!ends_excmd((uint8_t)(*linep))) {
      key_start = linep;
      if (*linep == '=') {
        emsgf(_("E415: unexpected equal sign: %s"), key_start);
        error = true;
        break;
      }

      // Isolate the key ("term", "ctermfg", "ctermbg", "font", "guifg",
      // "guibg" or "guisp").
      while (*linep && !ascii_iswhite(*linep) && *linep != '=') {
        linep++;
      }
      xfree(key);
      key = (char *)vim_strnsave_up((const char_u *)key_start,
                                    (int)(linep - key_start));
      linep = (const char *)skipwhite((const char_u *)linep);

      if (strcmp(key, "NONE") == 0) {
        if (!init || HL_TABLE()[idx].sg_set == 0) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_CTERM+SG_GUI;
          }
          highlight_clear(idx);
        }
        continue;
      }

      // Check for the equal sign.
      if (*linep != '=') {
        emsgf(_("E416: missing equal sign: %s"), key_start);
        error = true;
        break;
      }
      linep++;

      // Isolate the argument.
      linep = (const char *)skipwhite((const char_u *)linep);
      if (*linep == '\'') {  // guifg='color name'
        arg_start = ++linep;
        linep = strchr(linep, '\'');
        if (linep == NULL) {
          emsgf(_(e_invarg2), key_start);
          error = true;
          break;
        }
      } else {
        arg_start = linep;
        linep = (const char *)skiptowhite((const char_u *)linep);
      }
      if (linep == arg_start) {
        emsgf(_("E417: missing argument: %s"), key_start);
        error = true;
        break;
      }
      xfree(arg);
      arg = xstrndup(arg_start, (size_t)(linep - arg_start));

      if (*linep == '\'') {
        linep++;
      }

      // Store the argument.
      if (strcmp(key, "TERM") == 0
          || strcmp(key, "CTERM") == 0
          || strcmp(key, "GUI") == 0) {
        attr = 0;
        off = 0;
        while (arg[off] != NUL) {
          for (i = ARRAY_SIZE(hl_attr_table); --i >= 0; ) {
            len = (int)STRLEN(hl_name_table[i]);
            if (STRNICMP(arg + off, hl_name_table[i], len) == 0) {
              attr |= hl_attr_table[i];
              off += len;
              break;
            }
          }
          if (i < 0) {
            emsgf(_("E418: Illegal value: %s"), arg);
            error = true;
            break;
          }
          if (arg[off] == ',') {  // Another one follows.
            off++;
          }
        }
        if (error) {
          break;
        }
        if (*key == 'C')   {
          if (!init || !(HL_TABLE()[idx].sg_set & SG_CTERM)) {
            if (!init) {
              HL_TABLE()[idx].sg_set |= SG_CTERM;
            }
            HL_TABLE()[idx].sg_cterm = attr;
            HL_TABLE()[idx].sg_cterm_bold = false;
          }
        } else if (*key == 'G') {
          if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
            if (!init) {
              HL_TABLE()[idx].sg_set |= SG_GUI;
            }
            HL_TABLE()[idx].sg_gui = attr;
          }
        }
      } else if (STRCMP(key, "FONT") == 0)   {
        // in non-GUI fonts are simply ignored
      } else if (STRCMP(key, "CTERMFG") == 0 || STRCMP(key, "CTERMBG") == 0) {
        if (!init || !(HL_TABLE()[idx].sg_set & SG_CTERM)) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_CTERM;
          }

          /* When setting the foreground color, and previously the "bold"
           * flag was set for a light color, reset it now */
          if (key[5] == 'F' && HL_TABLE()[idx].sg_cterm_bold) {
            HL_TABLE()[idx].sg_cterm &= ~HL_BOLD;
            HL_TABLE()[idx].sg_cterm_bold = false;
          }

          if (ascii_isdigit(*arg)) {
            color = atoi((char *)arg);
          } else if (STRICMP(arg, "fg") == 0) {
            if (cterm_normal_fg_color) {
              color = cterm_normal_fg_color - 1;
            } else {
              EMSG(_("E419: FG color unknown"));
              error = true;
              break;
            }
          } else if (STRICMP(arg, "bg") == 0)   {
            if (cterm_normal_bg_color > 0)
              color = cterm_normal_bg_color - 1;
            else {
              EMSG(_("E420: BG color unknown"));
              error = true;
              break;
            }
          } else {
            // Reduce calls to STRICMP a bit, it can be slow.
            off = TOUPPER_ASC(*arg);
            for (i = ARRAY_SIZE(color_names); --i >= 0; ) {
              if (off == color_names[i][0]
                  && STRICMP(arg + 1, color_names[i] + 1) == 0) {
                break;
              }
            }
            if (i < 0) {
              emsgf(_("E421: Color name or number not recognized: %s"),
                    key_start);
              error = true;
              break;
            }

            TriState bold = kNone;
            color = lookup_color(i, key[5] == 'F', &bold);

            // set/reset bold attribute to get light foreground
            // colors (on some terminals, e.g. "linux")
            if (bold == kTrue) {
              HL_TABLE()[idx].sg_cterm |= HL_BOLD;
              HL_TABLE()[idx].sg_cterm_bold = true;
            } else if (bold == kFalse) {
              HL_TABLE()[idx].sg_cterm &= ~HL_BOLD;
            }
          }
          // Add one to the argument, to avoid zero.  Zero is used for
          // "NONE", then "color" is -1.
          if (key[5] == 'F') {
            HL_TABLE()[idx].sg_cterm_fg = color + 1;
            if (is_normal_group) {
              cterm_normal_fg_color = color + 1;
            }
          } else {
            HL_TABLE()[idx].sg_cterm_bg = color + 1;
            if (is_normal_group) {
              cterm_normal_bg_color = color + 1;
              if (!ui_rgb_attached()) {
                if (color >= 0) {
                  int dark = -1;

                  if (t_colors < 16) {
                    dark = (color == 0 || color == 4);
                  } else if (color < 16) {
                    // Limit the heuristic to the standard 16 colors
                    dark = (color < 7 || color == 8);
                  }
                  // Set the 'background' option if the value is
                  // wrong.
                  if (dark != -1
                      && dark != (*p_bg == 'd')
                      && !option_was_set("bg")) {
                    set_option_value("bg", 0L, (dark ? "dark" : "light"), 0);
                    reset_option_was_set("bg");
                  }
                }
              }
            }
          }
        }
      } else if (strcmp(key, "GUIFG") == 0)   {
        char_u **const namep = &HL_TABLE()[idx].sg_rgb_fg_name;

        if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_GUI;
          }

          if (*namep == NULL || STRCMP(*namep, arg) != 0) {
            xfree(*namep);
            if (strcmp(arg, "NONE") != 0) {
              *namep = (char_u *)xstrdup(arg);
              HL_TABLE()[idx].sg_rgb_fg = name_to_color((char_u *)arg);
            } else {
              *namep = NULL;
              HL_TABLE()[idx].sg_rgb_fg = -1;
            }
            did_change = true;
          }
        }

        if (is_normal_group) {
          normal_fg = HL_TABLE()[idx].sg_rgb_fg;
        }
      } else if (STRCMP(key, "GUIBG") == 0)   {
        char_u **const namep = &HL_TABLE()[idx].sg_rgb_bg_name;

        if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_GUI;
          }

          if (*namep == NULL || STRCMP(*namep, arg) != 0) {
            xfree(*namep);
            if (STRCMP(arg, "NONE") != 0) {
              *namep = (char_u *)xstrdup(arg);
              HL_TABLE()[idx].sg_rgb_bg = name_to_color((char_u *)arg);
            } else {
              *namep = NULL;
              HL_TABLE()[idx].sg_rgb_bg = -1;
            }
            did_change = true;
          }
        }

        if (is_normal_group) {
          normal_bg = HL_TABLE()[idx].sg_rgb_bg;
        }
      } else if (strcmp(key, "GUISP") == 0)   {
        char_u **const namep = &HL_TABLE()[idx].sg_rgb_sp_name;

        if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_GUI;
          }

          if (*namep == NULL || STRCMP(*namep, arg) != 0) {
            xfree(*namep);
            if (strcmp(arg, "NONE") != 0) {
              *namep = (char_u *)xstrdup(arg);
              HL_TABLE()[idx].sg_rgb_sp = name_to_color((char_u *)arg);
            } else {
              *namep = NULL;
              HL_TABLE()[idx].sg_rgb_sp = -1;
            }
            did_change = true;
          }
        }

        if (is_normal_group) {
          normal_sp = HL_TABLE()[idx].sg_rgb_sp;
        }
      } else if (strcmp(key, "START") == 0 || strcmp(key, "STOP") == 0)   {
        // Ignored for now
      } else if (strcmp(key, "BLEND") == 0)   {
        if (strcmp(arg, "NONE") != 0) {
          HL_TABLE()[idx].sg_blend = strtol(arg, NULL, 10);
        } else {
          HL_TABLE()[idx].sg_blend = -1;
        }
      } else {
        emsgf(_("E423: Illegal argument: %s"), key_start);
        error = true;
        break;
      }
      HL_TABLE()[idx].sg_cleared = false;

      // When highlighting has been given for a group, don't link it.
      if (!init || !(HL_TABLE()[idx].sg_set & SG_LINK)) {
        HL_TABLE()[idx].sg_link = 0;
      }

      // Continue with next argument.
      linep = (const char *)skipwhite((const char_u *)linep);
    }
  }

  // If there is an error, and it's a new entry, remove it from the table.
  if (error && idx == highlight_ga.ga_len) {
    syn_unadd_group();
  } else {
    if (!error && is_normal_group) {
      // Need to update all groups, because they might be using "bg" and/or
      // "fg", which have been changed now.
      highlight_attr_set_all();

      if (!ui_has(kUILinegrid) && starting == 0) {
        // Older UIs assume that we clear the screen after normal group is
        // changed
        ui_refresh();
      } else {
        // TUI and newer UIs will repaint the screen themselves. NOT_VALID
        // redraw below will still handle usages of guibg=fg etc.
        ui_default_colors_set();
      }
      did_highlight_changed = true;
      redraw_all_later(NOT_VALID);
    } else {
      set_hl_attr(idx);
    }
    HL_TABLE()[idx].sg_script_ctx = current_sctx;
    HL_TABLE()[idx].sg_script_ctx.sc_lnum += sourcing_lnum;
  }
  xfree(key);
  xfree(arg);

  // Only call highlight_changed() once, after a sequence of highlight
  // commands, and only if an attribute actually changed
  if ((did_change
       || memcmp(&HL_TABLE()[idx], &item_before, sizeof(item_before)) != 0)
      && !did_highlight_changed) {
    // Do not trigger a redraw when highlighting is changed while
    // redrawing.  This may happen when evaluating 'statusline' changes the
    // StatusLine group.
    if (!updating_screen) {
      redraw_all_later(NOT_VALID);
    }
    need_highlight_changed = true;
  }
}

#if defined(EXITFREE)
void free_highlight(void)
{
  for (int i = 0; i < highlight_ga.ga_len; ++i) {
    highlight_clear(i);
    xfree(HL_TABLE()[i].sg_name);
    xfree(HL_TABLE()[i].sg_name_u);
  }
  ga_clear(&highlight_ga);
}

#endif

/*
 * Reset the cterm colors to what they were before Vim was started, if
 * possible.  Otherwise reset them to zero.
 */
void restore_cterm_colors(void)
{
  normal_fg = -1;
  normal_bg = -1;
  normal_sp = -1;
  cterm_normal_fg_color = 0;
  cterm_normal_bg_color = 0;
}

/*
 * Return TRUE if highlight group "idx" has any settings.
 * When "check_link" is TRUE also check for an existing link.
 */
static int hl_has_settings(int idx, int check_link)
{
  return HL_TABLE()[idx].sg_attr != 0
         || HL_TABLE()[idx].sg_cterm_fg != 0
         || HL_TABLE()[idx].sg_cterm_bg != 0
         || HL_TABLE()[idx].sg_rgb_fg_name != NULL
         || HL_TABLE()[idx].sg_rgb_bg_name != NULL
         || HL_TABLE()[idx].sg_rgb_sp_name != NULL
         || (check_link && (HL_TABLE()[idx].sg_set & SG_LINK));
}

/*
 * Clear highlighting for one group.
 */
static void highlight_clear(int idx)
{
  HL_TABLE()[idx].sg_cleared = true;

  HL_TABLE()[idx].sg_attr = 0;
  HL_TABLE()[idx].sg_cterm = 0;
  HL_TABLE()[idx].sg_cterm_bold = false;
  HL_TABLE()[idx].sg_cterm_fg = 0;
  HL_TABLE()[idx].sg_cterm_bg = 0;
  HL_TABLE()[idx].sg_gui = 0;
  HL_TABLE()[idx].sg_rgb_fg = -1;
  HL_TABLE()[idx].sg_rgb_bg = -1;
  HL_TABLE()[idx].sg_rgb_sp = -1;
  XFREE_CLEAR(HL_TABLE()[idx].sg_rgb_fg_name);
  XFREE_CLEAR(HL_TABLE()[idx].sg_rgb_bg_name);
  XFREE_CLEAR(HL_TABLE()[idx].sg_rgb_sp_name);
  HL_TABLE()[idx].sg_blend = -1;
  // Clear the script ID only when there is no link, since that is not
  // cleared.
  if (HL_TABLE()[idx].sg_link == 0) {
    HL_TABLE()[idx].sg_script_ctx.sc_sid = 0;
    HL_TABLE()[idx].sg_script_ctx.sc_lnum = 0;
  }
}


/// \addtogroup LIST_XXX
/// @{
#define LIST_ATTR   1
#define LIST_STRING 2
#define LIST_INT    3
/// @}

static void highlight_list_one(const int id)
{
  struct hl_group *const sgp = &HL_TABLE()[id - 1];  // index is ID minus one
  bool didh = false;

  if (message_filtered(sgp->sg_name)) {
    return;
  }

  didh = highlight_list_arg(id, didh, LIST_ATTR,
      sgp->sg_cterm, NULL, "cterm");
  didh = highlight_list_arg(id, didh, LIST_INT,
      sgp->sg_cterm_fg, NULL, "ctermfg");
  didh = highlight_list_arg(id, didh, LIST_INT,
      sgp->sg_cterm_bg, NULL, "ctermbg");

  didh = highlight_list_arg(id, didh, LIST_ATTR,
      sgp->sg_gui, NULL, "gui");
  didh = highlight_list_arg(id, didh, LIST_STRING,
      0, sgp->sg_rgb_fg_name, "guifg");
  didh = highlight_list_arg(id, didh, LIST_STRING,
      0, sgp->sg_rgb_bg_name, "guibg");
  didh = highlight_list_arg(id, didh, LIST_STRING,
                            0, sgp->sg_rgb_sp_name, "guisp");

  didh = highlight_list_arg(id, didh, LIST_INT,
                            sgp->sg_blend+1, NULL, "blend");

  if (sgp->sg_link && !got_int) {
    (void)syn_list_header(didh, 0, id, true);
    didh = true;
    msg_puts_attr("links to", HL_ATTR(HLF_D));
    msg_putchar(' ');
    msg_outtrans(HL_TABLE()[HL_TABLE()[id - 1].sg_link - 1].sg_name);
  }

  if (!didh)
    highlight_list_arg(id, didh, LIST_STRING, 0, (char_u *)"cleared", "");
  if (p_verbose > 0) {
    last_set_msg(sgp->sg_script_ctx);
  }
}

/// Outputs a highlight when doing ":hi MyHighlight"
///
/// @param type one of \ref LIST_XXX
/// @param iarg integer argument used if \p type == LIST_INT
/// @param sarg string used if \p type == LIST_STRING
static bool highlight_list_arg(
    const int id, bool didh, const int type, int iarg,
    char_u *const sarg, const char *const name)
{
  char_u buf[100];

  if (got_int) {
    return false;
  }
  if (type == LIST_STRING ? (sarg != NULL) : (iarg != 0)) {
    char_u *ts = buf;
    if (type == LIST_INT) {
      snprintf((char *)buf, sizeof(buf), "%d", iarg - 1);
    } else if (type == LIST_STRING) {
      ts = sarg;
    } else {    // type == LIST_ATTR
      buf[0] = NUL;
      for (int i = 0; hl_attr_table[i] != 0; i++) {
        if (iarg & hl_attr_table[i]) {
          if (buf[0] != NUL)
            xstrlcat((char *)buf, ",", 100);
          xstrlcat((char *)buf, hl_name_table[i], 100);
          iarg &= ~hl_attr_table[i];                /* don't want "inverse" */
        }
      }
    }

    (void)syn_list_header(didh, (int)(vim_strsize(ts) + STRLEN(name) + 1), id,
                          false);
    didh = true;
    if (!got_int) {
      if (*name != NUL) {
        MSG_PUTS_ATTR(name, HL_ATTR(HLF_D));
        MSG_PUTS_ATTR("=", HL_ATTR(HLF_D));
      }
      msg_outtrans(ts);
    }
  }
  return didh;
}

/// Check whether highlight group has attribute
///
/// @param[in]  id  Highlight group to check.
/// @param[in]  flag  Attribute to check.
/// @param[in]  modec  'g' for GUI, 'c' for term.
///
/// @return "1" if highlight group has attribute, NULL otherwise.
const char *highlight_has_attr(const int id, const int flag, const int modec)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  int attr;

  if (id <= 0 || id > highlight_ga.ga_len) {
    return NULL;
  }

  if (modec == 'g') {
    attr = HL_TABLE()[id - 1].sg_gui;
  } else {
    attr = HL_TABLE()[id - 1].sg_cterm;
  }

  return (attr & flag) ? "1" : NULL;
}

/// Return color name of the given highlight group
///
/// @param[in]  id  Highlight group to work with.
/// @param[in]  what  What to return: one of "font", "fg", "bg", "sp", "fg#",
///                   "bg#" or "sp#".
/// @param[in]  modec  'g' for GUI, 'c' for cterm and 't' for term.
///
/// @return color name, possibly in a static buffer. Buffer will be overwritten
///         on next highlight_color() call. May return NULL.
const char *highlight_color(const int id, const char *const what,
                            const int modec)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  static char name[20];
  int n;
  bool fg = false;
  bool sp = false;
  bool font = false;

  if (id <= 0 || id > highlight_ga.ga_len) {
    return NULL;
  }

  if (TOLOWER_ASC(what[0]) == 'f' && TOLOWER_ASC(what[1]) == 'g') {
    fg = true;
  } else if (TOLOWER_ASC(what[0]) == 'f' && TOLOWER_ASC(what[1]) == 'o'
             && TOLOWER_ASC(what[2]) == 'n' && TOLOWER_ASC(what[3]) == 't') {
    font = true;
  } else if (TOLOWER_ASC(what[0]) == 's' && TOLOWER_ASC(what[1]) == 'p') {
    sp = true;
  } else if (!(TOLOWER_ASC(what[0]) == 'b' && TOLOWER_ASC(what[1]) == 'g')) {
    return NULL;
  }
  if (modec == 'g') {
    if (what[2] == '#' && ui_rgb_attached()) {
      if (fg) {
          n = HL_TABLE()[id - 1].sg_rgb_fg;
      } else if (sp) {
          n = HL_TABLE()[id - 1].sg_rgb_sp;
      } else {
          n = HL_TABLE()[id - 1].sg_rgb_bg;
      }
      if (n < 0 || n > 0xffffff) {
        return NULL;
      }
      snprintf(name, sizeof(name), "#%06x", n);
      return name;
    }
    if (fg) {
      return (const char *)HL_TABLE()[id - 1].sg_rgb_fg_name;
    }
    if (sp) {
      return (const char *)HL_TABLE()[id - 1].sg_rgb_sp_name;
    }
    return (const char *)HL_TABLE()[id - 1].sg_rgb_bg_name;
  }
  if (font || sp) {
    return NULL;
  }
  if (modec == 'c') {
    if (fg) {
      n = HL_TABLE()[id - 1].sg_cterm_fg - 1;
    } else {
      n = HL_TABLE()[id - 1].sg_cterm_bg - 1;
    }
    if (n < 0) {
      return NULL;
    }
    snprintf(name, sizeof(name), "%d", n);
    return name;
  }
  // term doesn't have color.
  return NULL;
}

/// Output the syntax list header.
///
/// @param did_header did header already
/// @param outlen length of string that comes
/// @param id highlight group id
/// @param force_newline always start a new line
/// @return true when started a new line.
static bool syn_list_header(const bool did_header, const int outlen,
                            const int id, bool force_newline)
{
  int endcol = 19;
  bool newline = true;
  bool adjust = true;

  if (!did_header) {
    msg_putchar('\n');
    if (got_int) {
      return true;
    }
    msg_outtrans(HL_TABLE()[id - 1].sg_name);
    endcol = 15;
  } else if ((ui_has(kUIMessages) || msg_silent) && !force_newline) {
    msg_putchar(' ');
    adjust = false;
  } else if (msg_col + outlen + 1 >= Columns || force_newline)   {
    msg_putchar('\n');
    if (got_int) {
      return true;
    }
  } else {
    if (msg_col >= endcol) {    // wrap around is like starting a new line
      newline = false;
    }
  }

  if (adjust) {
    if (msg_col >= endcol) {
      // output at least one space
      endcol = msg_col + 1;
    }

    msg_advance(endcol);
  }

  /* Show "xxx" with the attributes. */
  if (!did_header) {
    msg_puts_attr("xxx", syn_id2attr(id));
    msg_putchar(' ');
  }

  return newline;
}

/// Set the attribute numbers for a highlight group.
/// Called after one of the attributes has changed.
/// @param idx corrected highlight index
static void set_hl_attr(int idx)
{
  HlAttrs at_en = HLATTRS_INIT;
  struct hl_group     *sgp = HL_TABLE() + idx;

  at_en.cterm_ae_attr = sgp->sg_cterm;
  at_en.cterm_fg_color = sgp->sg_cterm_fg;
  at_en.cterm_bg_color = sgp->sg_cterm_bg;
  at_en.rgb_ae_attr = sgp->sg_gui;
  // FIXME(tarruda): The "unset value" for rgb is -1, but since hlgroup is
  // initialized with 0(by garray functions), check for sg_rgb_{f,b}g_name
  // before setting attr_entry->{f,g}g_color to a other than -1
  at_en.rgb_fg_color = sgp->sg_rgb_fg_name ? sgp->sg_rgb_fg : -1;
  at_en.rgb_bg_color = sgp->sg_rgb_bg_name ? sgp->sg_rgb_bg : -1;
  at_en.rgb_sp_color = sgp->sg_rgb_sp_name ? sgp->sg_rgb_sp : -1;
  at_en.hl_blend = sgp->sg_blend;

  sgp->sg_attr = hl_get_syn_attr(idx+1, at_en);

  // a cursor style uses this syn_id, make sure its atribute is updated.
  if (cursor_mode_uses_syn_id(idx+1)) {
    ui_mode_info_set();
  }
}

/// Lookup a highlight group name and return its ID.
///
/// @param highlight name e.g. 'Cursor', 'Normal'
/// @return the highlight id, else 0 if \p name does not exist
int syn_name2id(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  int i;
  char_u name_u[200];

  /* Avoid using stricmp() too much, it's slow on some systems */
  /* Avoid alloc()/free(), these are slow too.  ID names over 200 chars
   * don't deserve to be found! */
  STRLCPY(name_u, name, 200);
  vim_strup(name_u);
  for (i = highlight_ga.ga_len; --i >= 0; )
    if (HL_TABLE()[i].sg_name_u != NULL
        && STRCMP(name_u, HL_TABLE()[i].sg_name_u) == 0)
      break;
  return i + 1;
}

/// Lookup a highlight group name and return its attributes.
/// Return zero if not found.
int syn_name2attr(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  int id = syn_name2id(name);

  if (id != 0) {
    return syn_id2attr(id);
  }
  return 0;
}

/*
 * Return TRUE if highlight group "name" exists.
 */
int highlight_exists(const char_u *name)
{
  return syn_name2id(name) > 0;
}

/*
 * Return the name of highlight group "id".
 * When not a valid ID return an empty string.
 */
char_u *syn_id2name(int id)
{
  if (id <= 0 || id > highlight_ga.ga_len)
    return (char_u *)"";
  return HL_TABLE()[id - 1].sg_name;
}

/*
 * Like syn_name2id(), but take a pointer + length argument.
 */
int syn_namen2id(const char_u *linep, int len)
{
  char_u *name = vim_strnsave(linep, len);
  int id = syn_name2id(name);
  xfree(name);

  return id;
}

/// Find highlight group name in the table and return its ID.
/// If it doesn't exist yet, a new entry is created.
///
/// @param pp Highlight group name
/// @param len length of \p pp
///
/// @return 0 for failure else the id of the group
int syn_check_group(const char_u *pp, int len)
{
  char_u  *name = vim_strnsave(pp, len);
  int id = syn_name2id(name);
  if (id == 0) {  // doesn't exist yet
    id = syn_add_group(name);
  } else {
    xfree(name);
  }
  return id;
}

/// Add new highlight group and return its ID.
///
/// @param name must be an allocated string, it will be consumed.
/// @return 0 for failure, else the allocated group id
/// @see syn_check_group syn_unadd_group
static int syn_add_group(char_u *name)
{
  char_u      *p;

  /* Check that the name is ASCII letters, digits and underscore. */
  for (p = name; *p != NUL; ++p) {
    if (!vim_isprintc(*p)) {
      EMSG(_("E669: Unprintable character in group name"));
      xfree(name);
      return 0;
    } else if (!ASCII_ISALNUM(*p) && *p != '_')   {
      /* This is an error, but since there previously was no check only
       * give a warning. */
      msg_source(HL_ATTR(HLF_W));
      MSG(_("W18: Invalid character in group name"));
      break;
    }
  }

  /*
   * First call for this growarray: init growing array.
   */
  if (highlight_ga.ga_data == NULL) {
    highlight_ga.ga_itemsize = sizeof(struct hl_group);
    ga_set_growsize(&highlight_ga, 10);
  }

  if (highlight_ga.ga_len >= MAX_HL_ID) {
    EMSG(_("E849: Too many highlight and syntax groups"));
    xfree(name);
    return 0;
  }

  // Append another syntax_highlight entry.
  struct hl_group* hlgp = GA_APPEND_VIA_PTR(struct hl_group, &highlight_ga);
  memset(hlgp, 0, sizeof(*hlgp));
  hlgp->sg_name = name;
  hlgp->sg_rgb_bg = -1;
  hlgp->sg_rgb_fg = -1;
  hlgp->sg_rgb_sp = -1;
  hlgp->sg_blend = -1;
  hlgp->sg_name_u = vim_strsave_up(name);

  return highlight_ga.ga_len;               /* ID is index plus one */
}

/// When, just after calling syn_add_group(), an error is discovered, this
/// function deletes the new name.
static void syn_unadd_group(void)
{
  highlight_ga.ga_len--;
  xfree(HL_TABLE()[highlight_ga.ga_len].sg_name);
  xfree(HL_TABLE()[highlight_ga.ga_len].sg_name_u);
}


/// Translate a group ID to highlight attributes.
/// @see syn_attr2entry
int syn_id2attr(int hl_id)
{
  struct hl_group     *sgp;

  hl_id = syn_get_final_id(hl_id);
  sgp = &HL_TABLE()[hl_id - 1];             /* index is ID minus one */
  return sgp->sg_attr;
}


/*
 * Translate a group ID to the final group ID (following links).
 */
int syn_get_final_id(int hl_id)
{
  int count;
  struct hl_group     *sgp;

  if (hl_id > highlight_ga.ga_len || hl_id < 1)
    return 0;                           /* Can be called from eval!! */

  /*
   * Follow links until there is no more.
   * Look out for loops!  Break after 100 links.
   */
  for (count = 100; --count >= 0; ) {
    sgp = &HL_TABLE()[hl_id - 1];           /* index is ID minus one */
    if (sgp->sg_link == 0 || sgp->sg_link > highlight_ga.ga_len)
      break;
    hl_id = sgp->sg_link;
  }

  return hl_id;
}

/// Refresh the color attributes of all highlight groups.
void highlight_attr_set_all(void)
{
  for (int idx = 0; idx < highlight_ga.ga_len; idx++) {
    struct hl_group *sgp = &HL_TABLE()[idx];
    if (sgp->sg_rgb_bg_name != NULL) {
      sgp->sg_rgb_bg = name_to_color(sgp->sg_rgb_bg_name);
    }
    if (sgp->sg_rgb_fg_name != NULL) {
      sgp->sg_rgb_fg = name_to_color(sgp->sg_rgb_fg_name);
    }
    if (sgp->sg_rgb_sp_name != NULL) {
      sgp->sg_rgb_sp = name_to_color(sgp->sg_rgb_sp_name);
    }
    set_hl_attr(idx);
  }
}

// Apply difference between User[1-9] and HLF_S to HLF_SNC.
static void combine_stl_hlt(int id, int id_S, int id_alt, int hlcnt, int i,
                            int hlf, int *table)
  FUNC_ATTR_NONNULL_ALL
{
  struct hl_group *const hlt = HL_TABLE();

  if (id_alt == 0) {
    memset(&hlt[hlcnt + i], 0, sizeof(struct hl_group));
    hlt[hlcnt + i].sg_cterm = highlight_attr[hlf];
    hlt[hlcnt + i].sg_gui = highlight_attr[hlf];
  } else {
    memmove(&hlt[hlcnt + i], &hlt[id_alt - 1], sizeof(struct hl_group));
  }
  hlt[hlcnt + i].sg_link = 0;

  hlt[hlcnt + i].sg_cterm ^= hlt[id - 1].sg_cterm ^ hlt[id_S - 1].sg_cterm;
  if (hlt[id - 1].sg_cterm_fg != hlt[id_S - 1].sg_cterm_fg) {
    hlt[hlcnt + i].sg_cterm_fg = hlt[id - 1].sg_cterm_fg;
  }
  if (hlt[id - 1].sg_cterm_bg != hlt[id_S - 1].sg_cterm_bg) {
    hlt[hlcnt + i].sg_cterm_bg = hlt[id - 1].sg_cterm_bg;
  }
  hlt[hlcnt + i].sg_gui ^= hlt[id - 1].sg_gui ^ hlt[id_S - 1].sg_gui;
  if (hlt[id - 1].sg_rgb_fg != hlt[id_S - 1].sg_rgb_fg) {
    hlt[hlcnt + i].sg_rgb_fg = hlt[id - 1].sg_rgb_fg;
  }
  if (hlt[id - 1].sg_rgb_bg != hlt[id_S - 1].sg_rgb_bg) {
    hlt[hlcnt + i].sg_rgb_bg = hlt[id - 1].sg_rgb_bg;
  }
  if (hlt[id - 1].sg_rgb_sp != hlt[id_S - 1].sg_rgb_sp) {
    hlt[hlcnt + i].sg_rgb_sp = hlt[id - 1].sg_rgb_sp;
  }
  highlight_ga.ga_len = hlcnt + i + 1;
  set_hl_attr(hlcnt + i);  // At long last we can apply
  table[i] = syn_id2attr(hlcnt + i + 1);
}

/// Translate highlight groups into attributes in highlight_attr[] and set up
/// the user highlights User1..9. A set of corresponding highlights to use on
/// top of HLF_SNC is computed.  Called only when nvim starts and upon first
/// screen redraw after any :highlight command.
void highlight_changed(void)
{
  int id;
  char_u userhl[30];  // use 30 to avoid compiler warning
  int id_S = -1;
  int id_SNC = 0;
  int hlcnt;

  need_highlight_changed = FALSE;

  /// Translate builtin highlight groups into attributes for quick lookup.
  for (int hlf = 0; hlf < (int)HLF_COUNT; hlf++) {
    id = syn_check_group((char_u *)hlf_names[hlf], STRLEN(hlf_names[hlf]));
    if (id == 0) {
      abort();
    }
    int final_id = syn_get_final_id(id);
    if (hlf == (int)HLF_SNC) {
      id_SNC = final_id;
    } else if (hlf == (int)HLF_S) {
      id_S = final_id;
    }

    highlight_attr[hlf] = hl_get_ui_attr(hlf, final_id,
                                         hlf == (int)HLF_INACTIVE);

    if (highlight_attr[hlf] != highlight_attr_last[hlf]) {
      if (hlf == HLF_MSG) {
        clear_cmdline = true;
      }
      ui_call_hl_group_set(cstr_as_string((char *)hlf_names[hlf]),
                           highlight_attr[hlf]);
      highlight_attr_last[hlf] = highlight_attr[hlf];
    }
  }

  //
  // Setup the user highlights
  //
  // Temporarily utilize 10 more hl entries:
  // 9 for User1-User9 combined with StatusLineNC
  // 1 for StatusLine default
  // Must to be in there simultaneously in case of table overflows in
  // get_attr_entry()
  ga_grow(&highlight_ga, 10);
  hlcnt = highlight_ga.ga_len;
  if (id_S == -1) {
    // Make sure id_S is always valid to simplify code below. Use the last entry
    memset(&HL_TABLE()[hlcnt + 9], 0, sizeof(struct hl_group));
    id_S = hlcnt + 10;
  }
  for (int i = 0; i < 9; i++) {
    sprintf((char *)userhl, "User%d", i + 1);
    id = syn_name2id(userhl);
    if (id == 0) {
      highlight_user[i] = 0;
      highlight_stlnc[i] = 0;
    } else {
      highlight_user[i] = syn_id2attr(id);
      combine_stl_hlt(id, id_S, id_SNC, hlcnt, i, HLF_SNC, highlight_stlnc);
    }
  }
  highlight_ga.ga_len = hlcnt;
}


/*
 * Handle command line completion for :highlight command.
 */
void set_context_in_highlight_cmd(expand_T *xp, const char *arg)
{
  // Default: expand group names.
  xp->xp_context = EXPAND_HIGHLIGHT;
  xp->xp_pattern = (char_u *)arg;
  include_link = 2;
  include_default = 1;

  /* (part of) subcommand already typed */
  if (*arg != NUL) {
    const char *p = (const char *)skiptowhite((const char_u *)arg);
    if (*p != NUL) {  // Past "default" or group name.
      include_default = 0;
      if (strncmp("default", arg, p - arg) == 0) {
        arg = (const char *)skipwhite((const char_u *)p);
        xp->xp_pattern = (char_u *)arg;
        p = (const char *)skiptowhite((const char_u *)arg);
      }
      if (*p != NUL) {                          /* past group name */
        include_link = 0;
        if (arg[1] == 'i' && arg[0] == 'N') {
          highlight_list();
        }
        if (strncmp("link", arg, p - arg) == 0
            || strncmp("clear", arg, p - arg) == 0) {
          xp->xp_pattern = skipwhite((const char_u *)p);
          p = (const char *)skiptowhite(xp->xp_pattern);
          if (*p != NUL) {  // Past first group name.
            xp->xp_pattern = skipwhite((const char_u *)p);
            p = (const char *)skiptowhite(xp->xp_pattern);
          }
        }
        if (*p != NUL) {  // Past group name(s).
          xp->xp_context = EXPAND_NOTHING;
        }
      }
    }
  }
}

/*
 * List highlighting matches in a nice way.
 */
static void highlight_list(void)
{
  int i;

  for (i = 10; --i >= 0; ) {
    highlight_list_two(i, HL_ATTR(HLF_D));
  }
  for (i = 40; --i >= 0; ) {
    highlight_list_two(99, 0);
  }
}

static void highlight_list_two(int cnt, int attr)
{
  msg_puts_attr(&("N \bI \b!  \b"[cnt / 11]), attr);
  msg_clr_eos();
  ui_flush();
  os_delay(cnt == 99 ? 40L : (long)cnt * 50L, false);
}


/// Function given to ExpandGeneric() to obtain the list of group names.
const char *get_highlight_name(expand_T *const xp, int idx)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return get_highlight_name_ext(xp, idx, true);
}


/// Obtain a highlight group name.
/// When "skip_cleared" is TRUE don't return a cleared entry.
const char *get_highlight_name_ext(expand_T *xp, int idx, int skip_cleared)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (idx < 0) {
    return NULL;
  }

  // Items are never removed from the table, skip the ones that were cleared.
  if (skip_cleared && idx < highlight_ga.ga_len && HL_TABLE()[idx].sg_cleared) {
    return "";
  }

  if (idx == highlight_ga.ga_len && include_none != 0) {
    return "none";
  } else if (idx == highlight_ga.ga_len + include_none
             && include_default != 0) {
    return "default";
  } else if (idx == highlight_ga.ga_len + include_none + include_default
             && include_link != 0) {
    return "link";
  } else if (idx == highlight_ga.ga_len + include_none + include_default + 1
             && include_link != 0) {
    return "clear";
  } else if (idx >= highlight_ga.ga_len) {
    return NULL;
  }
  return (const char *)HL_TABLE()[idx].sg_name;
}

color_name_table_T color_name_table[] = {
  // Colors from rgb.txt
  { "AliceBlue", RGB_(0xf0, 0xf8, 0xff) },
  { "AntiqueWhite", RGB_(0xfa, 0xeb, 0xd7) },
  { "AntiqueWhite1", RGB_(0xff, 0xef, 0xdb) },
  { "AntiqueWhite2", RGB_(0xee, 0xdf, 0xcc) },
  { "AntiqueWhite3", RGB_(0xcd, 0xc0, 0xb0) },
  { "AntiqueWhite4", RGB_(0x8b, 0x83, 0x78) },
  { "Aqua", RGB_(0x00, 0xff, 0xff) },
  { "Aquamarine", RGB_(0x7f, 0xff, 0xd4) },
  { "Aquamarine1", RGB_(0x7f, 0xff, 0xd4) },
  { "Aquamarine2", RGB_(0x76, 0xee, 0xc6) },
  { "Aquamarine3", RGB_(0x66, 0xcd, 0xaa) },
  { "Aquamarine4", RGB_(0x45, 0x8b, 0x74) },
  { "Azure", RGB_(0xf0, 0xff, 0xff) },
  { "Azure1", RGB_(0xf0, 0xff, 0xff) },
  { "Azure2", RGB_(0xe0, 0xee, 0xee) },
  { "Azure3", RGB_(0xc1, 0xcd, 0xcd) },
  { "Azure4", RGB_(0x83, 0x8b, 0x8b) },
  { "Beige", RGB_(0xf5, 0xf5, 0xdc) },
  { "Bisque", RGB_(0xff, 0xe4, 0xc4) },
  { "Bisque1", RGB_(0xff, 0xe4, 0xc4) },
  { "Bisque2", RGB_(0xee, 0xd5, 0xb7) },
  { "Bisque3", RGB_(0xcd, 0xb7, 0x9e) },
  { "Bisque4", RGB_(0x8b, 0x7d, 0x6b) },
  { "Black", RGB_(0x00, 0x00, 0x00) },
  { "BlanchedAlmond", RGB_(0xff, 0xeb, 0xcd) },
  { "Blue", RGB_(0x00, 0x00, 0xff) },
  { "Blue1", RGB_(0x0, 0x0, 0xff) },
  { "Blue2", RGB_(0x0, 0x0, 0xee) },
  { "Blue3", RGB_(0x0, 0x0, 0xcd) },
  { "Blue4", RGB_(0x0, 0x0, 0x8b) },
  { "BlueViolet", RGB_(0x8a, 0x2b, 0xe2) },
  { "Brown", RGB_(0xa5, 0x2a, 0x2a) },
  { "Brown1", RGB_(0xff, 0x40, 0x40) },
  { "Brown2", RGB_(0xee, 0x3b, 0x3b) },
  { "Brown3", RGB_(0xcd, 0x33, 0x33) },
  { "Brown4", RGB_(0x8b, 0x23, 0x23) },
  { "BurlyWood", RGB_(0xde, 0xb8, 0x87) },
  { "Burlywood1", RGB_(0xff, 0xd3, 0x9b) },
  { "Burlywood2", RGB_(0xee, 0xc5, 0x91) },
  { "Burlywood3", RGB_(0xcd, 0xaa, 0x7d) },
  { "Burlywood4", RGB_(0x8b, 0x73, 0x55) },
  { "CadetBlue", RGB_(0x5f, 0x9e, 0xa0) },
  { "CadetBlue1", RGB_(0x98, 0xf5, 0xff) },
  { "CadetBlue2", RGB_(0x8e, 0xe5, 0xee) },
  { "CadetBlue3", RGB_(0x7a, 0xc5, 0xcd) },
  { "CadetBlue4", RGB_(0x53, 0x86, 0x8b) },
  { "ChartReuse", RGB_(0x7f, 0xff, 0x00) },
  { "Chartreuse1", RGB_(0x7f, 0xff, 0x0) },
  { "Chartreuse2", RGB_(0x76, 0xee, 0x0) },
  { "Chartreuse3", RGB_(0x66, 0xcd, 0x0) },
  { "Chartreuse4", RGB_(0x45, 0x8b, 0x0) },
  { "Chocolate", RGB_(0xd2, 0x69, 0x1e) },
  { "Chocolate1", RGB_(0xff, 0x7f, 0x24) },
  { "Chocolate2", RGB_(0xee, 0x76, 0x21) },
  { "Chocolate3", RGB_(0xcd, 0x66, 0x1d) },
  { "Chocolate4", RGB_(0x8b, 0x45, 0x13) },
  { "Coral", RGB_(0xff, 0x7f, 0x50) },
  { "Coral1", RGB_(0xff, 0x72, 0x56) },
  { "Coral2", RGB_(0xee, 0x6a, 0x50) },
  { "Coral3", RGB_(0xcd, 0x5b, 0x45) },
  { "Coral4", RGB_(0x8b, 0x3e, 0x2f) },
  { "CornFlowerBlue", RGB_(0x64, 0x95, 0xed) },
  { "Cornsilk", RGB_(0xff, 0xf8, 0xdc) },
  { "Cornsilk1", RGB_(0xff, 0xf8, 0xdc) },
  { "Cornsilk2", RGB_(0xee, 0xe8, 0xcd) },
  { "Cornsilk3", RGB_(0xcd, 0xc8, 0xb1) },
  { "Cornsilk4", RGB_(0x8b, 0x88, 0x78) },
  { "Crimson", RGB_(0xdc, 0x14, 0x3c) },
  { "Cyan", RGB_(0x00, 0xff, 0xff) },
  { "Cyan1", RGB_(0x0, 0xff, 0xff) },
  { "Cyan2", RGB_(0x0, 0xee, 0xee) },
  { "Cyan3", RGB_(0x0, 0xcd, 0xcd) },
  { "Cyan4", RGB_(0x0, 0x8b, 0x8b) },
  { "DarkBlue", RGB_(0x00, 0x00, 0x8b) },
  { "DarkCyan", RGB_(0x00, 0x8b, 0x8b) },
  { "DarkGoldenRod", RGB_(0xb8, 0x86, 0x0b) },
  { "DarkGoldenrod1", RGB_(0xff, 0xb9, 0xf) },
  { "DarkGoldenrod2", RGB_(0xee, 0xad, 0xe) },
  { "DarkGoldenrod3", RGB_(0xcd, 0x95, 0xc) },
  { "DarkGoldenrod4", RGB_(0x8b, 0x65, 0x8) },
  { "DarkGray", RGB_(0xa9, 0xa9, 0xa9) },
  { "DarkGreen", RGB_(0x00, 0x64, 0x00) },
  { "DarkGrey", RGB_(0xa9, 0xa9, 0xa9) },
  { "DarkKhaki", RGB_(0xbd, 0xb7, 0x6b) },
  { "DarkMagenta", RGB_(0x8b, 0x00, 0x8b) },
  { "DarkOliveGreen", RGB_(0x55, 0x6b, 0x2f) },
  { "DarkOliveGreen1", RGB_(0xca, 0xff, 0x70) },
  { "DarkOliveGreen2", RGB_(0xbc, 0xee, 0x68) },
  { "DarkOliveGreen3", RGB_(0xa2, 0xcd, 0x5a) },
  { "DarkOliveGreen4", RGB_(0x6e, 0x8b, 0x3d) },
  { "DarkOrange", RGB_(0xff, 0x8c, 0x00) },
  { "DarkOrange1", RGB_(0xff, 0x7f, 0x0) },
  { "DarkOrange2", RGB_(0xee, 0x76, 0x0) },
  { "DarkOrange3", RGB_(0xcd, 0x66, 0x0) },
  { "DarkOrange4", RGB_(0x8b, 0x45, 0x0) },
  { "DarkOrchid", RGB_(0x99, 0x32, 0xcc) },
  { "DarkOrchid1", RGB_(0xbf, 0x3e, 0xff) },
  { "DarkOrchid2", RGB_(0xb2, 0x3a, 0xee) },
  { "DarkOrchid3", RGB_(0x9a, 0x32, 0xcd) },
  { "DarkOrchid4", RGB_(0x68, 0x22, 0x8b) },
  { "DarkRed", RGB_(0x8b, 0x00, 0x00) },
  { "DarkSalmon", RGB_(0xe9, 0x96, 0x7a) },
  { "DarkSeaGreen", RGB_(0x8f, 0xbc, 0x8f) },
  { "DarkSeaGreen1", RGB_(0xc1, 0xff, 0xc1) },
  { "DarkSeaGreen2", RGB_(0xb4, 0xee, 0xb4) },
  { "DarkSeaGreen3", RGB_(0x9b, 0xcd, 0x9b) },
  { "DarkSeaGreen4", RGB_(0x69, 0x8b, 0x69) },
  { "DarkSlateBlue", RGB_(0x48, 0x3d, 0x8b) },
  { "DarkSlateGray", RGB_(0x2f, 0x4f, 0x4f) },
  { "DarkSlateGray1", RGB_(0x97, 0xff, 0xff) },
  { "DarkSlateGray2", RGB_(0x8d, 0xee, 0xee) },
  { "DarkSlateGray3", RGB_(0x79, 0xcd, 0xcd) },
  { "DarkSlateGray4", RGB_(0x52, 0x8b, 0x8b) },
  { "DarkSlateGrey", RGB_(0x2f, 0x4f, 0x4f) },
  { "DarkTurquoise", RGB_(0x00, 0xce, 0xd1) },
  { "DarkViolet", RGB_(0x94, 0x00, 0xd3) },
  { "DarkYellow", RGB_(0xbb, 0xbb, 0x00) },
  { "DeepPink", RGB_(0xff, 0x14, 0x93) },
  { "DeepPink1", RGB_(0xff, 0x14, 0x93) },
  { "DeepPink2", RGB_(0xee, 0x12, 0x89) },
  { "DeepPink3", RGB_(0xcd, 0x10, 0x76) },
  { "DeepPink4", RGB_(0x8b, 0xa, 0x50) },
  { "DeepSkyBlue", RGB_(0x00, 0xbf, 0xff) },
  { "DeepSkyBlue1", RGB_(0x0, 0xbf, 0xff) },
  { "DeepSkyBlue2", RGB_(0x0, 0xb2, 0xee) },
  { "DeepSkyBlue3", RGB_(0x0, 0x9a, 0xcd) },
  { "DeepSkyBlue4", RGB_(0x0, 0x68, 0x8b) },
  { "DimGray", RGB_(0x69, 0x69, 0x69) },
  { "DimGrey", RGB_(0x69, 0x69, 0x69) },
  { "DodgerBlue", RGB_(0x1e, 0x90, 0xff) },
  { "DodgerBlue1", RGB_(0x1e, 0x90, 0xff) },
  { "DodgerBlue2", RGB_(0x1c, 0x86, 0xee) },
  { "DodgerBlue3", RGB_(0x18, 0x74, 0xcd) },
  { "DodgerBlue4", RGB_(0x10, 0x4e, 0x8b) },
  { "Firebrick", RGB_(0xb2, 0x22, 0x22) },
  { "Firebrick1", RGB_(0xff, 0x30, 0x30) },
  { "Firebrick2", RGB_(0xee, 0x2c, 0x2c) },
  { "Firebrick3", RGB_(0xcd, 0x26, 0x26) },
  { "Firebrick4", RGB_(0x8b, 0x1a, 0x1a) },
  { "FloralWhite", RGB_(0xff, 0xfa, 0xf0) },
  { "ForestGreen", RGB_(0x22, 0x8b, 0x22) },
  { "Fuchsia", RGB_(0xff, 0x00, 0xff) },
  { "Gainsboro", RGB_(0xdc, 0xdc, 0xdc) },
  { "GhostWhite", RGB_(0xf8, 0xf8, 0xff) },
  { "Gold", RGB_(0xff, 0xd7, 0x00) },
  { "Gold1", RGB_(0xff, 0xd7, 0x0) },
  { "Gold2", RGB_(0xee, 0xc9, 0x0) },
  { "Gold3", RGB_(0xcd, 0xad, 0x0) },
  { "Gold4", RGB_(0x8b, 0x75, 0x0) },
  { "GoldenRod", RGB_(0xda, 0xa5, 0x20) },
  { "Goldenrod1", RGB_(0xff, 0xc1, 0x25) },
  { "Goldenrod2", RGB_(0xee, 0xb4, 0x22) },
  { "Goldenrod3", RGB_(0xcd, 0x9b, 0x1d) },
  { "Goldenrod4", RGB_(0x8b, 0x69, 0x14) },
  { "Gray", RGB_(0x80, 0x80, 0x80) },
  { "Gray0", RGB_(0x0, 0x0, 0x0) },
  { "Gray1", RGB_(0x3, 0x3, 0x3) },
  { "Gray10", RGB_(0x1a, 0x1a, 0x1a) },
  { "Gray100", RGB_(0xff, 0xff, 0xff) },
  { "Gray11", RGB_(0x1c, 0x1c, 0x1c) },
  { "Gray12", RGB_(0x1f, 0x1f, 0x1f) },
  { "Gray13", RGB_(0x21, 0x21, 0x21) },
  { "Gray14", RGB_(0x24, 0x24, 0x24) },
  { "Gray15", RGB_(0x26, 0x26, 0x26) },
  { "Gray16", RGB_(0x29, 0x29, 0x29) },
  { "Gray17", RGB_(0x2b, 0x2b, 0x2b) },
  { "Gray18", RGB_(0x2e, 0x2e, 0x2e) },
  { "Gray19", RGB_(0x30, 0x30, 0x30) },
  { "Gray2", RGB_(0x5, 0x5, 0x5) },
  { "Gray20", RGB_(0x33, 0x33, 0x33) },
  { "Gray21", RGB_(0x36, 0x36, 0x36) },
  { "Gray22", RGB_(0x38, 0x38, 0x38) },
  { "Gray23", RGB_(0x3b, 0x3b, 0x3b) },
  { "Gray24", RGB_(0x3d, 0x3d, 0x3d) },
  { "Gray25", RGB_(0x40, 0x40, 0x40) },
  { "Gray26", RGB_(0x42, 0x42, 0x42) },
  { "Gray27", RGB_(0x45, 0x45, 0x45) },
  { "Gray28", RGB_(0x47, 0x47, 0x47) },
  { "Gray29", RGB_(0x4a, 0x4a, 0x4a) },
  { "Gray3", RGB_(0x8, 0x8, 0x8) },
  { "Gray30", RGB_(0x4d, 0x4d, 0x4d) },
  { "Gray31", RGB_(0x4f, 0x4f, 0x4f) },
  { "Gray32", RGB_(0x52, 0x52, 0x52) },
  { "Gray33", RGB_(0x54, 0x54, 0x54) },
  { "Gray34", RGB_(0x57, 0x57, 0x57) },
  { "Gray35", RGB_(0x59, 0x59, 0x59) },
  { "Gray36", RGB_(0x5c, 0x5c, 0x5c) },
  { "Gray37", RGB_(0x5e, 0x5e, 0x5e) },
  { "Gray38", RGB_(0x61, 0x61, 0x61) },
  { "Gray39", RGB_(0x63, 0x63, 0x63) },
  { "Gray4", RGB_(0xa, 0xa, 0xa) },
  { "Gray40", RGB_(0x66, 0x66, 0x66) },
  { "Gray41", RGB_(0x69, 0x69, 0x69) },
  { "Gray42", RGB_(0x6b, 0x6b, 0x6b) },
  { "Gray43", RGB_(0x6e, 0x6e, 0x6e) },
  { "Gray44", RGB_(0x70, 0x70, 0x70) },
  { "Gray45", RGB_(0x73, 0x73, 0x73) },
  { "Gray46", RGB_(0x75, 0x75, 0x75) },
  { "Gray47", RGB_(0x78, 0x78, 0x78) },
  { "Gray48", RGB_(0x7a, 0x7a, 0x7a) },
  { "Gray49", RGB_(0x7d, 0x7d, 0x7d) },
  { "Gray5", RGB_(0xd, 0xd, 0xd) },
  { "Gray50", RGB_(0x7f, 0x7f, 0x7f) },
  { "Gray51", RGB_(0x82, 0x82, 0x82) },
  { "Gray52", RGB_(0x85, 0x85, 0x85) },
  { "Gray53", RGB_(0x87, 0x87, 0x87) },
  { "Gray54", RGB_(0x8a, 0x8a, 0x8a) },
  { "Gray55", RGB_(0x8c, 0x8c, 0x8c) },
  { "Gray56", RGB_(0x8f, 0x8f, 0x8f) },
  { "Gray57", RGB_(0x91, 0x91, 0x91) },
  { "Gray58", RGB_(0x94, 0x94, 0x94) },
  { "Gray59", RGB_(0x96, 0x96, 0x96) },
  { "Gray6", RGB_(0xf, 0xf, 0xf) },
  { "Gray60", RGB_(0x99, 0x99, 0x99) },
  { "Gray61", RGB_(0x9c, 0x9c, 0x9c) },
  { "Gray62", RGB_(0x9e, 0x9e, 0x9e) },
  { "Gray63", RGB_(0xa1, 0xa1, 0xa1) },
  { "Gray64", RGB_(0xa3, 0xa3, 0xa3) },
  { "Gray65", RGB_(0xa6, 0xa6, 0xa6) },
  { "Gray66", RGB_(0xa8, 0xa8, 0xa8) },
  { "Gray67", RGB_(0xab, 0xab, 0xab) },
  { "Gray68", RGB_(0xad, 0xad, 0xad) },
  { "Gray69", RGB_(0xb0, 0xb0, 0xb0) },
  { "Gray7", RGB_(0x12, 0x12, 0x12) },
  { "Gray70", RGB_(0xb3, 0xb3, 0xb3) },
  { "Gray71", RGB_(0xb5, 0xb5, 0xb5) },
  { "Gray72", RGB_(0xb8, 0xb8, 0xb8) },
  { "Gray73", RGB_(0xba, 0xba, 0xba) },
  { "Gray74", RGB_(0xbd, 0xbd, 0xbd) },
  { "Gray75", RGB_(0xbf, 0xbf, 0xbf) },
  { "Gray76", RGB_(0xc2, 0xc2, 0xc2) },
  { "Gray77", RGB_(0xc4, 0xc4, 0xc4) },
  { "Gray78", RGB_(0xc7, 0xc7, 0xc7) },
  { "Gray79", RGB_(0xc9, 0xc9, 0xc9) },
  { "Gray8", RGB_(0x14, 0x14, 0x14) },
  { "Gray80", RGB_(0xcc, 0xcc, 0xcc) },
  { "Gray81", RGB_(0xcf, 0xcf, 0xcf) },
  { "Gray82", RGB_(0xd1, 0xd1, 0xd1) },
  { "Gray83", RGB_(0xd4, 0xd4, 0xd4) },
  { "Gray84", RGB_(0xd6, 0xd6, 0xd6) },
  { "Gray85", RGB_(0xd9, 0xd9, 0xd9) },
  { "Gray86", RGB_(0xdb, 0xdb, 0xdb) },
  { "Gray87", RGB_(0xde, 0xde, 0xde) },
  { "Gray88", RGB_(0xe0, 0xe0, 0xe0) },
  { "Gray89", RGB_(0xe3, 0xe3, 0xe3) },
  { "Gray9", RGB_(0x17, 0x17, 0x17) },
  { "Gray90", RGB_(0xe5, 0xe5, 0xe5) },
  { "Gray91", RGB_(0xe8, 0xe8, 0xe8) },
  { "Gray92", RGB_(0xeb, 0xeb, 0xeb) },
  { "Gray93", RGB_(0xed, 0xed, 0xed) },
  { "Gray94", RGB_(0xf0, 0xf0, 0xf0) },
  { "Gray95", RGB_(0xf2, 0xf2, 0xf2) },
  { "Gray96", RGB_(0xf5, 0xf5, 0xf5) },
  { "Gray97", RGB_(0xf7, 0xf7, 0xf7) },
  { "Gray98", RGB_(0xfa, 0xfa, 0xfa) },
  { "Gray99", RGB_(0xfc, 0xfc, 0xfc) },
  { "Green", RGB_(0x00, 0x80, 0x00) },
  { "Green1", RGB_(0x0, 0xff, 0x0) },
  { "Green2", RGB_(0x0, 0xee, 0x0) },
  { "Green3", RGB_(0x0, 0xcd, 0x0) },
  { "Green4", RGB_(0x0, 0x8b, 0x0) },
  { "GreenYellow", RGB_(0xad, 0xff, 0x2f) },
  { "Grey", RGB_(0x80, 0x80, 0x80) },
  { "Grey0", RGB_(0x0, 0x0, 0x0) },
  { "Grey1", RGB_(0x3, 0x3, 0x3) },
  { "Grey10", RGB_(0x1a, 0x1a, 0x1a) },
  { "Grey100", RGB_(0xff, 0xff, 0xff) },
  { "Grey11", RGB_(0x1c, 0x1c, 0x1c) },
  { "Grey12", RGB_(0x1f, 0x1f, 0x1f) },
  { "Grey13", RGB_(0x21, 0x21, 0x21) },
  { "Grey14", RGB_(0x24, 0x24, 0x24) },
  { "Grey15", RGB_(0x26, 0x26, 0x26) },
  { "Grey16", RGB_(0x29, 0x29, 0x29) },
  { "Grey17", RGB_(0x2b, 0x2b, 0x2b) },
  { "Grey18", RGB_(0x2e, 0x2e, 0x2e) },
  { "Grey19", RGB_(0x30, 0x30, 0x30) },
  { "Grey2", RGB_(0x5, 0x5, 0x5) },
  { "Grey20", RGB_(0x33, 0x33, 0x33) },
  { "Grey21", RGB_(0x36, 0x36, 0x36) },
  { "Grey22", RGB_(0x38, 0x38, 0x38) },
  { "Grey23", RGB_(0x3b, 0x3b, 0x3b) },
  { "Grey24", RGB_(0x3d, 0x3d, 0x3d) },
  { "Grey25", RGB_(0x40, 0x40, 0x40) },
  { "Grey26", RGB_(0x42, 0x42, 0x42) },
  { "Grey27", RGB_(0x45, 0x45, 0x45) },
  { "Grey28", RGB_(0x47, 0x47, 0x47) },
  { "Grey29", RGB_(0x4a, 0x4a, 0x4a) },
  { "Grey3", RGB_(0x8, 0x8, 0x8) },
  { "Grey30", RGB_(0x4d, 0x4d, 0x4d) },
  { "Grey31", RGB_(0x4f, 0x4f, 0x4f) },
  { "Grey32", RGB_(0x52, 0x52, 0x52) },
  { "Grey33", RGB_(0x54, 0x54, 0x54) },
  { "Grey34", RGB_(0x57, 0x57, 0x57) },
  { "Grey35", RGB_(0x59, 0x59, 0x59) },
  { "Grey36", RGB_(0x5c, 0x5c, 0x5c) },
  { "Grey37", RGB_(0x5e, 0x5e, 0x5e) },
  { "Grey38", RGB_(0x61, 0x61, 0x61) },
  { "Grey39", RGB_(0x63, 0x63, 0x63) },
  { "Grey4", RGB_(0xa, 0xa, 0xa) },
  { "Grey40", RGB_(0x66, 0x66, 0x66) },
  { "Grey41", RGB_(0x69, 0x69, 0x69) },
  { "Grey42", RGB_(0x6b, 0x6b, 0x6b) },
  { "Grey43", RGB_(0x6e, 0x6e, 0x6e) },
  { "Grey44", RGB_(0x70, 0x70, 0x70) },
  { "Grey45", RGB_(0x73, 0x73, 0x73) },
  { "Grey46", RGB_(0x75, 0x75, 0x75) },
  { "Grey47", RGB_(0x78, 0x78, 0x78) },
  { "Grey48", RGB_(0x7a, 0x7a, 0x7a) },
  { "Grey49", RGB_(0x7d, 0x7d, 0x7d) },
  { "Grey5", RGB_(0xd, 0xd, 0xd) },
  { "Grey50", RGB_(0x7f, 0x7f, 0x7f) },
  { "Grey51", RGB_(0x82, 0x82, 0x82) },
  { "Grey52", RGB_(0x85, 0x85, 0x85) },
  { "Grey53", RGB_(0x87, 0x87, 0x87) },
  { "Grey54", RGB_(0x8a, 0x8a, 0x8a) },
  { "Grey55", RGB_(0x8c, 0x8c, 0x8c) },
  { "Grey56", RGB_(0x8f, 0x8f, 0x8f) },
  { "Grey57", RGB_(0x91, 0x91, 0x91) },
  { "Grey58", RGB_(0x94, 0x94, 0x94) },
  { "Grey59", RGB_(0x96, 0x96, 0x96) },
  { "Grey6", RGB_(0xf, 0xf, 0xf) },
  { "Grey60", RGB_(0x99, 0x99, 0x99) },
  { "Grey61", RGB_(0x9c, 0x9c, 0x9c) },
  { "Grey62", RGB_(0x9e, 0x9e, 0x9e) },
  { "Grey63", RGB_(0xa1, 0xa1, 0xa1) },
  { "Grey64", RGB_(0xa3, 0xa3, 0xa3) },
  { "Grey65", RGB_(0xa6, 0xa6, 0xa6) },
  { "Grey66", RGB_(0xa8, 0xa8, 0xa8) },
  { "Grey67", RGB_(0xab, 0xab, 0xab) },
  { "Grey68", RGB_(0xad, 0xad, 0xad) },
  { "Grey69", RGB_(0xb0, 0xb0, 0xb0) },
  { "Grey7", RGB_(0x12, 0x12, 0x12) },
  { "Grey70", RGB_(0xb3, 0xb3, 0xb3) },
  { "Grey71", RGB_(0xb5, 0xb5, 0xb5) },
  { "Grey72", RGB_(0xb8, 0xb8, 0xb8) },
  { "Grey73", RGB_(0xba, 0xba, 0xba) },
  { "Grey74", RGB_(0xbd, 0xbd, 0xbd) },
  { "Grey75", RGB_(0xbf, 0xbf, 0xbf) },
  { "Grey76", RGB_(0xc2, 0xc2, 0xc2) },
  { "Grey77", RGB_(0xc4, 0xc4, 0xc4) },
  { "Grey78", RGB_(0xc7, 0xc7, 0xc7) },
  { "Grey79", RGB_(0xc9, 0xc9, 0xc9) },
  { "Grey8", RGB_(0x14, 0x14, 0x14) },
  { "Grey80", RGB_(0xcc, 0xcc, 0xcc) },
  { "Grey81", RGB_(0xcf, 0xcf, 0xcf) },
  { "Grey82", RGB_(0xd1, 0xd1, 0xd1) },
  { "Grey83", RGB_(0xd4, 0xd4, 0xd4) },
  { "Grey84", RGB_(0xd6, 0xd6, 0xd6) },
  { "Grey85", RGB_(0xd9, 0xd9, 0xd9) },
  { "Grey86", RGB_(0xdb, 0xdb, 0xdb) },
  { "Grey87", RGB_(0xde, 0xde, 0xde) },
  { "Grey88", RGB_(0xe0, 0xe0, 0xe0) },
  { "Grey89", RGB_(0xe3, 0xe3, 0xe3) },
  { "Grey9", RGB_(0x17, 0x17, 0x17) },
  { "Grey90", RGB_(0xe5, 0xe5, 0xe5) },
  { "Grey91", RGB_(0xe8, 0xe8, 0xe8) },
  { "Grey92", RGB_(0xeb, 0xeb, 0xeb) },
  { "Grey93", RGB_(0xed, 0xed, 0xed) },
  { "Grey94", RGB_(0xf0, 0xf0, 0xf0) },
  { "Grey95", RGB_(0xf2, 0xf2, 0xf2) },
  { "Grey96", RGB_(0xf5, 0xf5, 0xf5) },
  { "Grey97", RGB_(0xf7, 0xf7, 0xf7) },
  { "Grey98", RGB_(0xfa, 0xfa, 0xfa) },
  { "Grey99", RGB_(0xfc, 0xfc, 0xfc) },
  { "Honeydew", RGB_(0xf0, 0xff, 0xf0) },
  { "Honeydew1", RGB_(0xf0, 0xff, 0xf0) },
  { "Honeydew2", RGB_(0xe0, 0xee, 0xe0) },
  { "Honeydew3", RGB_(0xc1, 0xcd, 0xc1) },
  { "Honeydew4", RGB_(0x83, 0x8b, 0x83) },
  { "HotPink", RGB_(0xff, 0x69, 0xb4) },
  { "HotPink1", RGB_(0xff, 0x6e, 0xb4) },
  { "HotPink2", RGB_(0xee, 0x6a, 0xa7) },
  { "HotPink3", RGB_(0xcd, 0x60, 0x90) },
  { "HotPink4", RGB_(0x8b, 0x3a, 0x62) },
  { "IndianRed", RGB_(0xcd, 0x5c, 0x5c) },
  { "IndianRed1", RGB_(0xff, 0x6a, 0x6a) },
  { "IndianRed2", RGB_(0xee, 0x63, 0x63) },
  { "IndianRed3", RGB_(0xcd, 0x55, 0x55) },
  { "IndianRed4", RGB_(0x8b, 0x3a, 0x3a) },
  { "Indigo", RGB_(0x4b, 0x00, 0x82) },
  { "Ivory", RGB_(0xff, 0xff, 0xf0) },
  { "Ivory1", RGB_(0xff, 0xff, 0xf0) },
  { "Ivory2", RGB_(0xee, 0xee, 0xe0) },
  { "Ivory3", RGB_(0xcd, 0xcd, 0xc1) },
  { "Ivory4", RGB_(0x8b, 0x8b, 0x83) },
  { "Khaki", RGB_(0xf0, 0xe6, 0x8c) },
  { "Khaki1", RGB_(0xff, 0xf6, 0x8f) },
  { "Khaki2", RGB_(0xee, 0xe6, 0x85) },
  { "Khaki3", RGB_(0xcd, 0xc6, 0x73) },
  { "Khaki4", RGB_(0x8b, 0x86, 0x4e) },
  { "Lavender", RGB_(0xe6, 0xe6, 0xfa) },
  { "LavenderBlush", RGB_(0xff, 0xf0, 0xf5) },
  { "LavenderBlush1", RGB_(0xff, 0xf0, 0xf5) },
  { "LavenderBlush2", RGB_(0xee, 0xe0, 0xe5) },
  { "LavenderBlush3", RGB_(0xcd, 0xc1, 0xc5) },
  { "LavenderBlush4", RGB_(0x8b, 0x83, 0x86) },
  { "LawnGreen", RGB_(0x7c, 0xfc, 0x00) },
  { "LemonChiffon", RGB_(0xff, 0xfa, 0xcd) },
  { "LemonChiffon1", RGB_(0xff, 0xfa, 0xcd) },
  { "LemonChiffon2", RGB_(0xee, 0xe9, 0xbf) },
  { "LemonChiffon3", RGB_(0xcd, 0xc9, 0xa5) },
  { "LemonChiffon4", RGB_(0x8b, 0x89, 0x70) },
  { "LightBlue", RGB_(0xad, 0xd8, 0xe6) },
  { "LightBlue1", RGB_(0xbf, 0xef, 0xff) },
  { "LightBlue2", RGB_(0xb2, 0xdf, 0xee) },
  { "LightBlue3", RGB_(0x9a, 0xc0, 0xcd) },
  { "LightBlue4", RGB_(0x68, 0x83, 0x8b) },
  { "LightCoral", RGB_(0xf0, 0x80, 0x80) },
  { "LightCyan", RGB_(0xe0, 0xff, 0xff) },
  { "LightCyan1", RGB_(0xe0, 0xff, 0xff) },
  { "LightCyan2", RGB_(0xd1, 0xee, 0xee) },
  { "LightCyan3", RGB_(0xb4, 0xcd, 0xcd) },
  { "LightCyan4", RGB_(0x7a, 0x8b, 0x8b) },
  { "LightGoldenrod", RGB_(0xee, 0xdd, 0x82) },
  { "LightGoldenrod1", RGB_(0xff, 0xec, 0x8b) },
  { "LightGoldenrod2", RGB_(0xee, 0xdc, 0x82) },
  { "LightGoldenrod3", RGB_(0xcd, 0xbe, 0x70) },
  { "LightGoldenrod4", RGB_(0x8b, 0x81, 0x4c) },
  { "LightGoldenRodYellow", RGB_(0xfa, 0xfa, 0xd2) },
  { "LightGray", RGB_(0xd3, 0xd3, 0xd3) },
  { "LightGreen", RGB_(0x90, 0xee, 0x90) },
  { "LightGrey", RGB_(0xd3, 0xd3, 0xd3) },
  { "LightMagenta", RGB_(0xff, 0xbb, 0xff) },
  { "LightPink", RGB_(0xff, 0xb6, 0xc1) },
  { "LightPink1", RGB_(0xff, 0xae, 0xb9) },
  { "LightPink2", RGB_(0xee, 0xa2, 0xad) },
  { "LightPink3", RGB_(0xcd, 0x8c, 0x95) },
  { "LightPink4", RGB_(0x8b, 0x5f, 0x65) },
  { "LightRed", RGB_(0xff, 0xbb, 0xbb) },
  { "LightSalmon", RGB_(0xff, 0xa0, 0x7a) },
  { "LightSalmon1", RGB_(0xff, 0xa0, 0x7a) },
  { "LightSalmon2", RGB_(0xee, 0x95, 0x72) },
  { "LightSalmon3", RGB_(0xcd, 0x81, 0x62) },
  { "LightSalmon4", RGB_(0x8b, 0x57, 0x42) },
  { "LightSeaGreen", RGB_(0x20, 0xb2, 0xaa) },
  { "LightSkyBlue", RGB_(0x87, 0xce, 0xfa) },
  { "LightSkyBlue1", RGB_(0xb0, 0xe2, 0xff) },
  { "LightSkyBlue2", RGB_(0xa4, 0xd3, 0xee) },
  { "LightSkyBlue3", RGB_(0x8d, 0xb6, 0xcd) },
  { "LightSkyBlue4", RGB_(0x60, 0x7b, 0x8b) },
  { "LightSlateBlue", RGB_(0x84, 0x70, 0xff) },
  { "LightSlateGray", RGB_(0x77, 0x88, 0x99) },
  { "LightSlateGrey", RGB_(0x77, 0x88, 0x99) },
  { "LightSteelBlue", RGB_(0xb0, 0xc4, 0xde) },
  { "LightSteelBlue1", RGB_(0xca, 0xe1, 0xff) },
  { "LightSteelBlue2", RGB_(0xbc, 0xd2, 0xee) },
  { "LightSteelBlue3", RGB_(0xa2, 0xb5, 0xcd) },
  { "LightSteelBlue4", RGB_(0x6e, 0x7b, 0x8b) },
  { "LightYellow", RGB_(0xff, 0xff, 0xe0) },
  { "LightYellow1", RGB_(0xff, 0xff, 0xe0) },
  { "LightYellow2", RGB_(0xee, 0xee, 0xd1) },
  { "LightYellow3", RGB_(0xcd, 0xcd, 0xb4) },
  { "LightYellow4", RGB_(0x8b, 0x8b, 0x7a) },
  { "Lime", RGB_(0x00, 0xff, 0x00) },
  { "LimeGreen", RGB_(0x32, 0xcd, 0x32) },
  { "Linen", RGB_(0xfa, 0xf0, 0xe6) },
  { "Magenta", RGB_(0xff, 0x00, 0xff) },
  { "Magenta1", RGB_(0xff, 0x0, 0xff) },
  { "Magenta2", RGB_(0xee, 0x0, 0xee) },
  { "Magenta3", RGB_(0xcd, 0x0, 0xcd) },
  { "Magenta4", RGB_(0x8b, 0x0, 0x8b) },
  { "Maroon", RGB_(0x80, 0x00, 0x00) },
  { "Maroon1", RGB_(0xff, 0x34, 0xb3) },
  { "Maroon2", RGB_(0xee, 0x30, 0xa7) },
  { "Maroon3", RGB_(0xcd, 0x29, 0x90) },
  { "Maroon4", RGB_(0x8b, 0x1c, 0x62) },
  { "MediumAquamarine", RGB_(0x66, 0xcd, 0xaa) },
  { "MediumBlue", RGB_(0x00, 0x00, 0xcd) },
  { "MediumOrchid", RGB_(0xba, 0x55, 0xd3) },
  { "MediumOrchid1", RGB_(0xe0, 0x66, 0xff) },
  { "MediumOrchid2", RGB_(0xd1, 0x5f, 0xee) },
  { "MediumOrchid3", RGB_(0xb4, 0x52, 0xcd) },
  { "MediumOrchid4", RGB_(0x7a, 0x37, 0x8b) },
  { "MediumPurple", RGB_(0x93, 0x70, 0xdb) },
  { "MediumPurple1", RGB_(0xab, 0x82, 0xff) },
  { "MediumPurple2", RGB_(0x9f, 0x79, 0xee) },
  { "MediumPurple3", RGB_(0x89, 0x68, 0xcd) },
  { "MediumPurple4", RGB_(0x5d, 0x47, 0x8b) },
  { "MediumSeaGreen", RGB_(0x3c, 0xb3, 0x71) },
  { "MediumSlateBlue", RGB_(0x7b, 0x68, 0xee) },
  { "MediumSpringGreen", RGB_(0x00, 0xfa, 0x9a) },
  { "MediumTurquoise", RGB_(0x48, 0xd1, 0xcc) },
  { "MediumVioletRed", RGB_(0xc7, 0x15, 0x85) },
  { "MidnightBlue", RGB_(0x19, 0x19, 0x70) },
  { "MintCream", RGB_(0xf5, 0xff, 0xfa) },
  { "MistyRose", RGB_(0xff, 0xe4, 0xe1) },
  { "MistyRose1", RGB_(0xff, 0xe4, 0xe1) },
  { "MistyRose2", RGB_(0xee, 0xd5, 0xd2) },
  { "MistyRose3", RGB_(0xcd, 0xb7, 0xb5) },
  { "MistyRose4", RGB_(0x8b, 0x7d, 0x7b) },
  { "Moccasin", RGB_(0xff, 0xe4, 0xb5) },
  { "NavajoWhite", RGB_(0xff, 0xde, 0xad) },
  { "NavajoWhite1", RGB_(0xff, 0xde, 0xad) },
  { "NavajoWhite2", RGB_(0xee, 0xcf, 0xa1) },
  { "NavajoWhite3", RGB_(0xcd, 0xb3, 0x8b) },
  { "NavajoWhite4", RGB_(0x8b, 0x79, 0x5e) },
  { "Navy", RGB_(0x00, 0x00, 0x80) },
  { "NavyBlue", RGB_(0x0, 0x0, 0x80) },
  { "OldLace", RGB_(0xfd, 0xf5, 0xe6) },
  { "Olive", RGB_(0x80, 0x80, 0x00) },
  { "OliveDrab", RGB_(0x6b, 0x8e, 0x23) },
  { "OliveDrab1", RGB_(0xc0, 0xff, 0x3e) },
  { "OliveDrab2", RGB_(0xb3, 0xee, 0x3a) },
  { "OliveDrab3", RGB_(0x9a, 0xcd, 0x32) },
  { "OliveDrab4", RGB_(0x69, 0x8b, 0x22) },
  { "Orange", RGB_(0xff, 0xa5, 0x00) },
  { "Orange1", RGB_(0xff, 0xa5, 0x0) },
  { "Orange2", RGB_(0xee, 0x9a, 0x0) },
  { "Orange3", RGB_(0xcd, 0x85, 0x0) },
  { "Orange4", RGB_(0x8b, 0x5a, 0x0) },
  { "OrangeRed", RGB_(0xff, 0x45, 0x00) },
  { "OrangeRed1", RGB_(0xff, 0x45, 0x0) },
  { "OrangeRed2", RGB_(0xee, 0x40, 0x0) },
  { "OrangeRed3", RGB_(0xcd, 0x37, 0x0) },
  { "OrangeRed4", RGB_(0x8b, 0x25, 0x0) },
  { "Orchid", RGB_(0xda, 0x70, 0xd6) },
  { "Orchid1", RGB_(0xff, 0x83, 0xfa) },
  { "Orchid2", RGB_(0xee, 0x7a, 0xe9) },
  { "Orchid3", RGB_(0xcd, 0x69, 0xc9) },
  { "Orchid4", RGB_(0x8b, 0x47, 0x89) },
  { "PaleGoldenRod", RGB_(0xee, 0xe8, 0xaa) },
  { "PaleGreen", RGB_(0x98, 0xfb, 0x98) },
  { "PaleGreen1", RGB_(0x9a, 0xff, 0x9a) },
  { "PaleGreen2", RGB_(0x90, 0xee, 0x90) },
  { "PaleGreen3", RGB_(0x7c, 0xcd, 0x7c) },
  { "PaleGreen4", RGB_(0x54, 0x8b, 0x54) },
  { "PaleTurquoise", RGB_(0xaf, 0xee, 0xee) },
  { "PaleTurquoise1", RGB_(0xbb, 0xff, 0xff) },
  { "PaleTurquoise2", RGB_(0xae, 0xee, 0xee) },
  { "PaleTurquoise3", RGB_(0x96, 0xcd, 0xcd) },
  { "PaleTurquoise4", RGB_(0x66, 0x8b, 0x8b) },
  { "PaleVioletRed", RGB_(0xdb, 0x70, 0x93) },
  { "PaleVioletRed1", RGB_(0xff, 0x82, 0xab) },
  { "PaleVioletRed2", RGB_(0xee, 0x79, 0x9f) },
  { "PaleVioletRed3", RGB_(0xcd, 0x68, 0x89) },
  { "PaleVioletRed4", RGB_(0x8b, 0x47, 0x5d) },
  { "PapayaWhip", RGB_(0xff, 0xef, 0xd5) },
  { "PeachPuff", RGB_(0xff, 0xda, 0xb9) },
  { "PeachPuff1", RGB_(0xff, 0xda, 0xb9) },
  { "PeachPuff2", RGB_(0xee, 0xcb, 0xad) },
  { "PeachPuff3", RGB_(0xcd, 0xaf, 0x95) },
  { "PeachPuff4", RGB_(0x8b, 0x77, 0x65) },
  { "Peru", RGB_(0xcd, 0x85, 0x3f) },
  { "Pink", RGB_(0xff, 0xc0, 0xcb) },
  { "Pink1", RGB_(0xff, 0xb5, 0xc5) },
  { "Pink2", RGB_(0xee, 0xa9, 0xb8) },
  { "Pink3", RGB_(0xcd, 0x91, 0x9e) },
  { "Pink4", RGB_(0x8b, 0x63, 0x6c) },
  { "Plum", RGB_(0xdd, 0xa0, 0xdd) },
  { "Plum1", RGB_(0xff, 0xbb, 0xff) },
  { "Plum2", RGB_(0xee, 0xae, 0xee) },
  { "Plum3", RGB_(0xcd, 0x96, 0xcd) },
  { "Plum4", RGB_(0x8b, 0x66, 0x8b) },
  { "PowderBlue", RGB_(0xb0, 0xe0, 0xe6) },
  { "Purple", RGB_(0x80, 0x00, 0x80) },
  { "Purple1", RGB_(0x9b, 0x30, 0xff) },
  { "Purple2", RGB_(0x91, 0x2c, 0xee) },
  { "Purple3", RGB_(0x7d, 0x26, 0xcd) },
  { "Purple4", RGB_(0x55, 0x1a, 0x8b) },
  { "RebeccaPurple", RGB_(0x66, 0x33, 0x99) },
  { "Red", RGB_(0xff, 0x00, 0x00) },
  { "Red1", RGB_(0xff, 0x0, 0x0) },
  { "Red2", RGB_(0xee, 0x0, 0x0) },
  { "Red3", RGB_(0xcd, 0x0, 0x0) },
  { "Red4", RGB_(0x8b, 0x0, 0x0) },
  { "RosyBrown", RGB_(0xbc, 0x8f, 0x8f) },
  { "RosyBrown1", RGB_(0xff, 0xc1, 0xc1) },
  { "RosyBrown2", RGB_(0xee, 0xb4, 0xb4) },
  { "RosyBrown3", RGB_(0xcd, 0x9b, 0x9b) },
  { "RosyBrown4", RGB_(0x8b, 0x69, 0x69) },
  { "RoyalBlue", RGB_(0x41, 0x69, 0xe1) },
  { "RoyalBlue1", RGB_(0x48, 0x76, 0xff) },
  { "RoyalBlue2", RGB_(0x43, 0x6e, 0xee) },
  { "RoyalBlue3", RGB_(0x3a, 0x5f, 0xcd) },
  { "RoyalBlue4", RGB_(0x27, 0x40, 0x8b) },
  { "SaddleBrown", RGB_(0x8b, 0x45, 0x13) },
  { "Salmon", RGB_(0xfa, 0x80, 0x72) },
  { "Salmon1", RGB_(0xff, 0x8c, 0x69) },
  { "Salmon2", RGB_(0xee, 0x82, 0x62) },
  { "Salmon3", RGB_(0xcd, 0x70, 0x54) },
  { "Salmon4", RGB_(0x8b, 0x4c, 0x39) },
  { "SandyBrown", RGB_(0xf4, 0xa4, 0x60) },
  { "SeaGreen", RGB_(0x2e, 0x8b, 0x57) },
  { "SeaGreen1", RGB_(0x54, 0xff, 0x9f) },
  { "SeaGreen2", RGB_(0x4e, 0xee, 0x94) },
  { "SeaGreen3", RGB_(0x43, 0xcd, 0x80) },
  { "SeaGreen4", RGB_(0x2e, 0x8b, 0x57) },
  { "SeaShell", RGB_(0xff, 0xf5, 0xee) },
  { "Seashell1", RGB_(0xff, 0xf5, 0xee) },
  { "Seashell2", RGB_(0xee, 0xe5, 0xde) },
  { "Seashell3", RGB_(0xcd, 0xc5, 0xbf) },
  { "Seashell4", RGB_(0x8b, 0x86, 0x82) },
  { "Sienna", RGB_(0xa0, 0x52, 0x2d) },
  { "Sienna1", RGB_(0xff, 0x82, 0x47) },
  { "Sienna2", RGB_(0xee, 0x79, 0x42) },
  { "Sienna3", RGB_(0xcd, 0x68, 0x39) },
  { "Sienna4", RGB_(0x8b, 0x47, 0x26) },
  { "Silver", RGB_(0xc0, 0xc0, 0xc0) },
  { "SkyBlue", RGB_(0x87, 0xce, 0xeb) },
  { "SkyBlue1", RGB_(0x87, 0xce, 0xff) },
  { "SkyBlue2", RGB_(0x7e, 0xc0, 0xee) },
  { "SkyBlue3", RGB_(0x6c, 0xa6, 0xcd) },
  { "SkyBlue4", RGB_(0x4a, 0x70, 0x8b) },
  { "SlateBlue", RGB_(0x6a, 0x5a, 0xcd) },
  { "SlateBlue1", RGB_(0x83, 0x6f, 0xff) },
  { "SlateBlue2", RGB_(0x7a, 0x67, 0xee) },
  { "SlateBlue3", RGB_(0x69, 0x59, 0xcd) },
  { "SlateBlue4", RGB_(0x47, 0x3c, 0x8b) },
  { "SlateGray", RGB_(0x70, 0x80, 0x90) },
  { "SlateGray1", RGB_(0xc6, 0xe2, 0xff) },
  { "SlateGray2", RGB_(0xb9, 0xd3, 0xee) },
  { "SlateGray3", RGB_(0x9f, 0xb6, 0xcd) },
  { "SlateGray4", RGB_(0x6c, 0x7b, 0x8b) },
  { "SlateGrey", RGB_(0x70, 0x80, 0x90) },
  { "Snow", RGB_(0xff, 0xfa, 0xfa) },
  { "Snow1", RGB_(0xff, 0xfa, 0xfa) },
  { "Snow2", RGB_(0xee, 0xe9, 0xe9) },
  { "Snow3", RGB_(0xcd, 0xc9, 0xc9) },
  { "Snow4", RGB_(0x8b, 0x89, 0x89) },
  { "SpringGreen", RGB_(0x00, 0xff, 0x7f) },
  { "SpringGreen1", RGB_(0x0, 0xff, 0x7f) },
  { "SpringGreen2", RGB_(0x0, 0xee, 0x76) },
  { "SpringGreen3", RGB_(0x0, 0xcd, 0x66) },
  { "SpringGreen4", RGB_(0x0, 0x8b, 0x45) },
  { "SteelBlue", RGB_(0x46, 0x82, 0xb4) },
  { "SteelBlue1", RGB_(0x63, 0xb8, 0xff) },
  { "SteelBlue2", RGB_(0x5c, 0xac, 0xee) },
  { "SteelBlue3", RGB_(0x4f, 0x94, 0xcd) },
  { "SteelBlue4", RGB_(0x36, 0x64, 0x8b) },
  { "Tan", RGB_(0xd2, 0xb4, 0x8c) },
  { "Tan1", RGB_(0xff, 0xa5, 0x4f) },
  { "Tan2", RGB_(0xee, 0x9a, 0x49) },
  { "Tan3", RGB_(0xcd, 0x85, 0x3f) },
  { "Tan4", RGB_(0x8b, 0x5a, 0x2b) },
  { "Teal", RGB_(0x00, 0x80, 0x80) },
  { "Thistle", RGB_(0xd8, 0xbf, 0xd8) },
  { "Thistle1", RGB_(0xff, 0xe1, 0xff) },
  { "Thistle2", RGB_(0xee, 0xd2, 0xee) },
  { "Thistle3", RGB_(0xcd, 0xb5, 0xcd) },
  { "Thistle4", RGB_(0x8b, 0x7b, 0x8b) },
  { "Tomato", RGB_(0xff, 0x63, 0x47) },
  { "Tomato1", RGB_(0xff, 0x63, 0x47) },
  { "Tomato2", RGB_(0xee, 0x5c, 0x42) },
  { "Tomato3", RGB_(0xcd, 0x4f, 0x39) },
  { "Tomato4", RGB_(0x8b, 0x36, 0x26) },
  { "Turquoise", RGB_(0x40, 0xe0, 0xd0) },
  { "Turquoise1", RGB_(0x0, 0xf5, 0xff) },
  { "Turquoise2", RGB_(0x0, 0xe5, 0xee) },
  { "Turquoise3", RGB_(0x0, 0xc5, 0xcd) },
  { "Turquoise4", RGB_(0x0, 0x86, 0x8b) },
  { "Violet", RGB_(0xee, 0x82, 0xee) },
  { "VioletRed", RGB_(0xd0, 0x20, 0x90) },
  { "VioletRed1", RGB_(0xff, 0x3e, 0x96) },
  { "VioletRed2", RGB_(0xee, 0x3a, 0x8c) },
  { "VioletRed3", RGB_(0xcd, 0x32, 0x78) },
  { "VioletRed4", RGB_(0x8b, 0x22, 0x52) },
  { "WebGray", RGB_(0x80, 0x80, 0x80) },
  { "WebGreen", RGB_(0x0, 0x80, 0x0) },
  { "WebGrey", RGB_(0x80, 0x80, 0x80) },
  { "WebMaroon", RGB_(0x80, 0x0, 0x0) },
  { "WebPurple", RGB_(0x80, 0x0, 0x80) },
  { "Wheat", RGB_(0xf5, 0xde, 0xb3) },
  { "Wheat1", RGB_(0xff, 0xe7, 0xba) },
  { "Wheat2", RGB_(0xee, 0xd8, 0xae) },
  { "Wheat3", RGB_(0xcd, 0xba, 0x96) },
  { "Wheat4", RGB_(0x8b, 0x7e, 0x66) },
  { "White", RGB_(0xff, 0xff, 0xff) },
  { "WhiteSmoke", RGB_(0xf5, 0xf5, 0xf5) },
  { "X11Gray", RGB_(0xbe, 0xbe, 0xbe) },
  { "X11Green", RGB_(0x0, 0xff, 0x0) },
  { "X11Grey", RGB_(0xbe, 0xbe, 0xbe) },
  { "X11Maroon", RGB_(0xb0, 0x30, 0x60) },
  { "X11Purple", RGB_(0xa0, 0x20, 0xf0) },
  { "Yellow", RGB_(0xff, 0xff, 0x00) },
  { "Yellow1", RGB_(0xff, 0xff, 0x0) },
  { "Yellow2", RGB_(0xee, 0xee, 0x0) },
  { "Yellow3", RGB_(0xcd, 0xcd, 0x0) },
  { "Yellow4", RGB_(0x8b, 0x8b, 0x0) },
  { "YellowGreen", RGB_(0x9a, 0xcd, 0x32) },
  { NULL, 0 },
};


/// Translate to RgbValue if \p name is an hex value (e.g. #XXXXXX),
/// else look into color_name_table to translate a color name to  its
/// hex value
///
/// @param[in] name string value to convert to RGB
/// return the hex value or -1 if could not find a correct value
RgbValue name_to_color(const char_u *name)
{

  if (name[0] == '#' && isxdigit(name[1]) && isxdigit(name[2])
      && isxdigit(name[3]) && isxdigit(name[4]) && isxdigit(name[5])
      && isxdigit(name[6]) && name[7] == NUL) {
    // rgb hex string
    return strtol((char *)(name + 1), NULL, 16);
  } else if (!STRICMP(name, "bg") || !STRICMP(name, "background")) {
    return normal_bg;
  } else if (!STRICMP(name, "fg") || !STRICMP(name, "foreground")) {
    return normal_fg;
  }

  for (int i = 0; color_name_table[i].name != NULL; i++) {
    if (!STRICMP(name, color_name_table[i].name)) {
      return color_name_table[i].color;
    }
  }

  return -1;
}


/**************************************
*  End of Highlighting stuff	      *
**************************************/
