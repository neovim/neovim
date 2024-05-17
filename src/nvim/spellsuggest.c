// spellsuggest.c: functions for spelling suggestions

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/hashtab_defs.h"
#include "nvim/highlight_defs.h"
#include "nvim/input.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/os_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/spell.h"
#include "nvim/spell_defs.h"
#include "nvim/spellfile.h"
#include "nvim/spellsuggest.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"

// Use this to adjust the score after finding suggestions, based on the
// suggested word sounding like the bad word.  This is much faster than doing
// it for every possible suggestion.
// Disadvantage: When "the" is typed as "hte" it sounds quite different ("@"
// vs "ht") and goes down in the list.
// Used when 'spellsuggest' is set to "best".
#define RESCORE(word_score, sound_score) ((3 * (word_score) + (sound_score)) / 4)

// Do the opposite: based on a maximum end score and a known sound score,
// compute the maximum word score that can be used.
#define MAXSCORE(word_score, sound_score) ((4 * (word_score) - (sound_score)) / 3)

// only used for su_badflags
#define WF_MIXCAP   0x20        // mix of upper and lower case: macaRONI

/// Information used when looking for suggestions.
typedef struct {
  garray_T su_ga;                  ///< suggestions, contains "suggest_T"
  int su_maxcount;                 ///< max. number of suggestions displayed
  int su_maxscore;                 ///< maximum score for adding to su_ga
  int su_sfmaxscore;               ///< idem, for when doing soundfold words
  garray_T su_sga;                 ///< like su_ga, sound-folded scoring
  char *su_badptr;                 ///< start of bad word in line
  int su_badlen;                   ///< length of detected bad word in line
  int su_badflags;                 ///< caps flags for bad word
  char su_badword[MAXWLEN];        ///< bad word truncated at su_badlen
  char su_fbadword[MAXWLEN];       ///< su_badword case-folded
  char su_sal_badword[MAXWLEN];    ///< su_badword soundfolded
  hashtab_T su_banned;             ///< table with banned words
  slang_T *su_sallang;             ///< default language for sound folding
} suginfo_T;

/// One word suggestion.  Used in "si_ga".
typedef struct {
  char *st_word;      ///< suggested word, allocated string
  int st_wordlen;     ///< strlen(st_word)
  int st_orglen;      ///< length of replaced text
  int st_score;       ///< lower is better
  int st_altscore;    ///< used when st_score compares equal
  bool st_salscore;   ///< st_score is for soundalike
  bool st_had_bonus;  ///< bonus already included in score
  slang_T *st_slang;  ///< language used for sound folding
} suggest_T;

#define SUG(ga, i) (((suggest_T *)(ga).ga_data)[i])

// True if a word appears in the list of banned words.
#define WAS_BANNED(su, word) (!HASHITEM_EMPTY(hash_find(&(su)->su_banned, word)))

// Number of suggestions kept when cleaning up.  We need to keep more than
// what is displayed, because when rescore_suggestions() is called the score
// may change and wrong suggestions may be removed later.
#define SUG_CLEAN_COUNT(su)    ((su)->su_maxcount < \
                                130 ? 150 : (su)->su_maxcount + 20)

// Threshold for sorting and cleaning up suggestions.  Don't want to keep lots
// of suggestions that are not going to be displayed.
#define SUG_MAX_COUNT(su)       (SUG_CLEAN_COUNT(su) + 50)

// score for various changes
enum {
  SCORE_SPLIT = 149,     // split bad word
  SCORE_SPLIT_NO = 249,  // split bad word with NOSPLITSUGS
  SCORE_ICASE = 52,      // slightly different case
  SCORE_REGION = 200,    // word is for different region
  SCORE_RARE = 180,      // rare word
  SCORE_SWAP = 75,       // swap two characters
  SCORE_SWAP3 = 110,     // swap two characters in three
  SCORE_REP = 65,        // REP replacement
  SCORE_SUBST = 93,      // substitute a character
  SCORE_SIMILAR = 33,    // substitute a similar character
  SCORE_SUBCOMP = 33,    // substitute a composing character
  SCORE_DEL = 94,        // delete a character
  SCORE_DELDUP = 66,     // delete a duplicated character
  SCORE_DELCOMP = 28,    // delete a composing character
  SCORE_INS = 96,        // insert a character
  SCORE_INSDUP = 67,     // insert a duplicate character
  SCORE_INSCOMP = 30,    // insert a composing character
  SCORE_NONWORD = 103,   // change non-word to word char
};

enum {
  SCORE_FILE = 30,      // suggestion from a file
  SCORE_MAXINIT = 350,  // Initial maximum score: higher == slower.
                        // 350 allows for about three changes.
};

enum {
  SCORE_COMMON1 = 30,  // subtracted for words seen before
  SCORE_COMMON2 = 40,  // subtracted for words often seen
  SCORE_COMMON3 = 50,  // subtracted for words very often seen
  SCORE_THRES2 = 10,   // word count threshold for COMMON2
  SCORE_THRES3 = 100,  // word count threshold for COMMON3
};

// When trying changed soundfold words it becomes slow when trying more than
// two changes.  With less than two changes it's slightly faster but we miss a
// few good suggestions.  In rare cases we need to try three of four changes.
enum {
  SCORE_SFMAX1 = 200,  // maximum score for first try
  SCORE_SFMAX2 = 300,  // maximum score for second try
  SCORE_SFMAX3 = 400,  // maximum score for third try
};

#define SCORE_BIG       (SCORE_INS * 3)  // big difference
enum {
  SCORE_MAXMAX = 999999,  // accept any score
  SCORE_LIMITMAX = 350,   // for spell_edit_score_limit()
};

// for spell_edit_score_limit() we need to know the minimum value of
// SCORE_ICASE, SCORE_SWAP, SCORE_DEL, SCORE_SIMILAR and SCORE_INS
#define SCORE_EDIT_MIN  SCORE_SIMILAR

/// For finding suggestions: At each node in the tree these states are tried:
typedef enum {
  STATE_START = 0,  ///< At start of node check for NUL bytes (goodword
                    ///< ends); if badword ends there is a match, otherwise
                    ///< try splitting word.
  STATE_NOPREFIX,   ///< try without prefix
  STATE_SPLITUNDO,  ///< Undo splitting.
  STATE_ENDNUL,     ///< Past NUL bytes at start of the node.
  STATE_PLAIN,      ///< Use each byte of the node.
  STATE_DEL,        ///< Delete a byte from the bad word.
  STATE_INS_PREP,   ///< Prepare for inserting bytes.
  STATE_INS,        ///< Insert a byte in the bad word.
  STATE_SWAP,       ///< Swap two bytes.
  STATE_UNSWAP,     ///< Undo swap two characters.
  STATE_SWAP3,      ///< Swap two characters over three.
  STATE_UNSWAP3,    ///< Undo Swap two characters over three.
  STATE_UNROT3L,    ///< Undo rotate three characters left
  STATE_UNROT3R,    ///< Undo rotate three characters right
  STATE_REP_INI,    ///< Prepare for using REP items.
  STATE_REP,        ///< Use matching REP items from the .aff file.
  STATE_REP_UNDO,   ///< Undo a REP item replacement.
  STATE_FINAL,      ///< End of this node.
} state_T;

/// Struct to keep the state at each level in suggest_try_change().
typedef struct {
  state_T ts_state;          ///< state at this level, STATE_
  int ts_score;              ///< score
  idx_T ts_arridx;           ///< index in tree array, start of node
  int16_t ts_curi;           ///< index in list of child nodes
  uint8_t ts_fidx;           ///< index in fword[], case-folded bad word
  uint8_t ts_fidxtry;        ///< ts_fidx at which bytes may be changed
  uint8_t ts_twordlen;       ///< valid length of tword[]
  uint8_t ts_prefixdepth;    ///< stack depth for end of prefix or
                             ///< PFD_PREFIXTREE or PFD_NOPREFIX
  uint8_t ts_flags;          ///< TSF_ flags
  uint8_t ts_tcharlen;       ///< number of bytes in tword character
  uint8_t ts_tcharidx;       ///< current byte index in tword character
  uint8_t ts_isdiff;         ///< DIFF_ values
  uint8_t ts_fcharstart;     ///< index in fword where badword char started
  uint8_t ts_prewordlen;     ///< length of word in "preword[]"
  uint8_t ts_splitoff;       ///< index in "tword" after last split
  uint8_t ts_splitfidx;      ///< "ts_fidx" at word split
  uint8_t ts_complen;        ///< nr of compound words used
  uint8_t ts_compsplit;      ///< index for "compflags" where word was spit
  uint8_t ts_save_badflags;  ///< su_badflags saved here
  uint8_t ts_delidx;         ///< index in fword for char that was deleted,
                             ///< valid when "ts_flags" has TSF_DIDDEL
} trystate_T;

// values for ts_isdiff
enum {
  DIFF_NONE = 0,    // no different byte (yet)
  DIFF_YES = 1,     // different byte found
  DIFF_INSERT = 2,  // inserting character
};

// values for ts_flags
enum {
  TSF_PREFIXOK = 1,  // already checked that prefix is OK
  TSF_DIDSPLIT = 2,  // tried split at this point
  TSF_DIDDEL = 4,    // did a delete, "ts_delidx" has index
};

// special values ts_prefixdepth
enum {
  PFD_NOPREFIX = 0xff,    // not using prefixes
  PFD_PREFIXTREE = 0xfe,  // walking through the prefix tree
  PFD_NOTSPECIAL = 0xfd,  // highest value that's not special
};

static int spell_suggest_timeout = 5000;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "spellsuggest.c.generated.h"
#endif

/// Returns true when the sequence of flags in "compflags" plus "flag" can
/// possibly form a valid compounded word.  This also checks the COMPOUNDRULE
/// lines if they don't contain wildcards.
static bool can_be_compound(trystate_T *sp, slang_T *slang, uint8_t *compflags, int flag)
{
  // If the flag doesn't appear in sl_compstartflags or sl_compallflags
  // then it can't possibly compound.
  if (!byte_in_str(sp->ts_complen == sp->ts_compsplit
                   ? slang->sl_compstartflags : slang->sl_compallflags, flag)) {
    return false;
  }

  // If there are no wildcards, we can check if the flags collected so far
  // possibly can form a match with COMPOUNDRULE patterns.  This only
  // makes sense when we have two or more words.
  if (slang->sl_comprules != NULL && sp->ts_complen > sp->ts_compsplit) {
    compflags[sp->ts_complen] = (uint8_t)flag;
    compflags[sp->ts_complen + 1] = NUL;
    bool v = match_compoundrule(slang, compflags + sp->ts_compsplit);
    compflags[sp->ts_complen] = NUL;
    return v;
  }

  return true;
}

/// Adjust the score of common words.
///
/// @param split  word was split, less bonus
static int score_wordcount_adj(slang_T *slang, int score, char *word, bool split)
{
  int bonus;
  int newscore;

  hashitem_T *hi = hash_find(&slang->sl_wordcount, word);
  if (HASHITEM_EMPTY(hi)) {
    return score;
  }

  wordcount_T *wc = HI2WC(hi);
  if (wc->wc_count < SCORE_THRES2) {
    bonus = SCORE_COMMON1;
  } else if (wc->wc_count < SCORE_THRES3) {
    bonus = SCORE_COMMON2;
  } else {
    bonus = SCORE_COMMON3;
  }
  if (split) {
    newscore = score - bonus / 2;
  } else {
    newscore = score - bonus;
  }
  if (newscore < 0) {
    return 0;
  }
  return newscore;
}

/// Like captype() but for a KEEPCAP word add ONECAP if the word starts with a
/// capital.  So that make_case_word() can turn WOrd into Word.
/// Add ALLCAP for "WOrD".
static int badword_captype(char *word, char *end)
  FUNC_ATTR_NONNULL_ALL
{
  int flags = captype(word, end);

  if (!(flags & WF_KEEPCAP)) {
    return flags;
  }

  // Count the number of UPPER and lower case letters.
  int l = 0;
  int u = 0;
  bool first = false;
  for (char *p = word; p < end; MB_PTR_ADV(p)) {
    int c = utf_ptr2char(p);
    if (SPELL_ISUPPER(c)) {
      u++;
      if (p == word) {
        first = true;
      }
    } else {
      l++;
    }
  }

  // If there are more UPPER than lower case letters suggest an
  // ALLCAP word.  Otherwise, if the first letter is UPPER then
  // suggest ONECAP.  Exception: "ALl" most likely should be "All",
  // require three upper case letters.
  if (u > l && u > 2) {
    flags |= WF_ALLCAP;
  } else if (first) {
    flags |= WF_ONECAP;
  }

  if (u >= 2 && l >= 2) {     // maCARONI maCAroni
    flags |= WF_MIXCAP;
  }

  return flags;
}

/// Opposite of offset2bytes().
/// "pp" points to the bytes and is advanced over it.
///
/// @return  the offset.
static int bytes2offset(char **pp)
{
  uint8_t *p = (uint8_t *)(*pp);
  int nr;

  int c = *p++;
  if ((c & 0x80) == 0x00) {             // 1 byte
    nr = c - 1;
  } else if ((c & 0xc0) == 0x80) {      // 2 bytes
    nr = (c & 0x3f) - 1;
    nr = nr * 255 + (*p++ - 1);
  } else if ((c & 0xe0) == 0xc0) {      // 3 bytes
    nr = (c & 0x1f) - 1;
    nr = nr * 255 + (*p++ - 1);
    nr = nr * 255 + (*p++ - 1);
  } else {                              // 4 bytes
    nr = (c & 0x0f) - 1;
    nr = nr * 255 + (*p++ - 1);
    nr = nr * 255 + (*p++ - 1);
    nr = nr * 255 + (*p++ - 1);
  }

  *pp = (char *)p;
  return nr;
}

// values for sps_flags
enum {
  SPS_BEST = 1,
  SPS_FAST = 2,
  SPS_DOUBLE = 4,
};

static int sps_flags = SPS_BEST;  ///< flags from 'spellsuggest'
static int sps_limit = 9999;      ///< max nr of suggestions given

/// Check the 'spellsuggest' option.  Return FAIL if it's wrong.
/// Sets "sps_flags" and "sps_limit".
int spell_check_sps(void)
{
  char buf[MAXPATHL];

  sps_flags = 0;
  sps_limit = 9999;

  for (char *p = p_sps; *p != NUL;) {
    copy_option_part(&p, buf, MAXPATHL, ",");

    int f = 0;
    if (ascii_isdigit(*buf)) {
      char *s = buf;
      sps_limit = getdigits_int(&s, true, 0);
      if (*s != NUL && !ascii_isdigit(*s)) {
        f = -1;
      }
      // Note: Keep this in sync with p_sps_values.
    } else if (strcmp(buf, "best") == 0) {
      f = SPS_BEST;
    } else if (strcmp(buf, "fast") == 0) {
      f = SPS_FAST;
    } else if (strcmp(buf, "double") == 0) {
      f = SPS_DOUBLE;
    } else if (strncmp(buf, "expr:", 5) != 0
               && strncmp(buf, "file:", 5) != 0
               && (strncmp(buf, "timeout:", 8) != 0
                   || (!ascii_isdigit(buf[8])
                       && !(buf[8] == '-' && ascii_isdigit(buf[9]))))) {
      f = -1;
    }

    if (f == -1 || (sps_flags != 0 && f != 0)) {
      sps_flags = SPS_BEST;
      sps_limit = 9999;
      return FAIL;
    }
    if (f != 0) {
      sps_flags = f;
    }
  }

  if (sps_flags == 0) {
    sps_flags = SPS_BEST;
  }

  return OK;
}

/// "z=": Find badly spelled word under or after the cursor.
/// Give suggestions for the properly spelled word.
/// In Visual mode use the highlighted word as the bad word.
/// When "count" is non-zero use that suggestion.
void spell_suggest(int count)
{
  pos_T prev_cursor = curwin->w_cursor;
  char wcopy[MAXWLEN + 2];
  suginfo_T sug;
  suggest_T *stp;
  bool mouse_used;
  int limit;
  int selected = count;
  int badlen = 0;
  int msg_scroll_save = msg_scroll;
  const int wo_spell_save = curwin->w_p_spell;

  if (!curwin->w_p_spell) {
    parse_spelllang(curwin);
    curwin->w_p_spell = true;
  }

  if (*curwin->w_s->b_p_spl == NUL) {
    emsg(_(e_no_spell));
    return;
  }

  if (VIsual_active) {
    // Use the Visually selected text as the bad word.  But reject
    // a multi-line selection.
    if (curwin->w_cursor.lnum != VIsual.lnum) {
      vim_beep(BO_SPELL);
      return;
    }
    badlen = (int)curwin->w_cursor.col - (int)VIsual.col;
    if (badlen < 0) {
      badlen = -badlen;
    } else {
      curwin->w_cursor.col = VIsual.col;
    }
    badlen++;
    end_visual_mode();
    // make sure we don't include the NUL at the end of the line
    if (badlen > get_cursor_line_len() - curwin->w_cursor.col) {
      badlen = get_cursor_line_len() - curwin->w_cursor.col;
    }
    // Find the start of the badly spelled word.
  } else if (spell_move_to(curwin, FORWARD, SMT_ALL, true, NULL) == 0
             || curwin->w_cursor.col > prev_cursor.col) {
    // No bad word or it starts after the cursor: use the word under the
    // cursor.
    curwin->w_cursor = prev_cursor;
    char *line = get_cursor_line_ptr();
    char *p = line + curwin->w_cursor.col;
    // Backup to before start of word.
    while (p > line && spell_iswordp_nmw(p, curwin)) {
      MB_PTR_BACK(line, p);
    }
    // Forward to start of word.
    while (*p != NUL && !spell_iswordp_nmw(p, curwin)) {
      MB_PTR_ADV(p);
    }

    if (!spell_iswordp_nmw(p, curwin)) {                // No word found.
      beep_flush();
      return;
    }
    curwin->w_cursor.col = (colnr_T)(p - line);
  }

  // Get the word and its length.

  // Figure out if the word should be capitalised.
  int need_cap = check_need_cap(curwin, curwin->w_cursor.lnum, curwin->w_cursor.col);

  // Make a copy of current line since autocommands may free the line.
  char *line = xstrnsave(get_cursor_line_ptr(), (size_t)get_cursor_line_len());
  spell_suggest_timeout = 5000;

  // Get the list of suggestions.  Limit to 'lines' - 2 or the number in
  // 'spellsuggest', whatever is smaller.
  if (sps_limit > Rows - 2) {
    limit = Rows - 2;
  } else {
    limit = sps_limit;
  }
  spell_find_suggest(line + curwin->w_cursor.col, badlen, &sug, limit,
                     true, need_cap, true);

  if (GA_EMPTY(&sug.su_ga)) {
    msg(_("Sorry, no suggestions"), 0);
  } else if (count > 0) {
    if (count > sug.su_ga.ga_len) {
      smsg(0, _("Sorry, only %" PRId64 " suggestions"),
           (int64_t)sug.su_ga.ga_len);
    }
  } else {
    // When 'rightleft' is set the list is drawn right-left.
    cmdmsg_rl = curwin->w_p_rl;

    // List the suggestions.
    msg_start();
    msg_row = Rows - 1;         // for when 'cmdheight' > 1
    lines_left = Rows;          // avoid more prompt
    char *fmt = _("Change \"%.*s\" to:");
    if (cmdmsg_rl && strncmp(fmt, "Change", 6) == 0) {
      // And now the rabbit from the high hat: Avoid showing the
      // untranslated message rightleft.
      fmt = ":ot \"%.*s\" egnahC";
    }
    vim_snprintf(IObuff, IOSIZE, fmt, sug.su_badlen, sug.su_badptr);
    msg_puts(IObuff);
    msg_clr_eos();
    msg_putchar('\n');

    msg_scroll = true;
    for (int i = 0; i < sug.su_ga.ga_len; i++) {
      stp = &SUG(sug.su_ga, i);

      // The suggested word may replace only part of the bad word, add
      // the not replaced part.  But only when it's not getting too long.
      xstrlcpy(wcopy, stp->st_word, MAXWLEN + 1);
      int el = sug.su_badlen - stp->st_orglen;
      if (el > 0 && stp->st_wordlen + el <= MAXWLEN) {
        assert(sug.su_badptr != NULL);
        xmemcpyz(wcopy + stp->st_wordlen, sug.su_badptr + stp->st_orglen, (size_t)el);
      }
      vim_snprintf(IObuff, IOSIZE, "%2d", i + 1);
      if (cmdmsg_rl) {
        rl_mirror_ascii(IObuff, NULL);
      }
      msg_puts(IObuff);

      vim_snprintf(IObuff, IOSIZE, " \"%s\"", wcopy);
      msg_puts(IObuff);

      // The word may replace more than "su_badlen".
      if (sug.su_badlen < stp->st_orglen) {
        vim_snprintf(IObuff, IOSIZE, _(" < \"%.*s\""),
                     stp->st_orglen, sug.su_badptr);
        msg_puts(IObuff);
      }

      if (p_verbose > 0) {
        // Add the score.
        if (sps_flags & (SPS_DOUBLE | SPS_BEST)) {
          vim_snprintf(IObuff, IOSIZE, " (%s%d - %d)",
                       stp->st_salscore ? "s " : "",
                       stp->st_score, stp->st_altscore);
        } else {
          vim_snprintf(IObuff, IOSIZE, " (%d)",
                       stp->st_score);
        }
        if (cmdmsg_rl) {
          // Mirror the numbers, but keep the leading space.
          rl_mirror_ascii(IObuff + 1, NULL);
        }
        msg_advance(30);
        msg_puts(IObuff);
      }
      msg_putchar('\n');
    }

    cmdmsg_rl = false;
    msg_col = 0;
    // Ask for choice.
    selected = prompt_for_number(&mouse_used);

    if (ui_has(kUIMessages)) {
      ui_call_msg_clear();
    }

    if (mouse_used) {
      selected -= lines_left;
    }
    lines_left = Rows;                  // avoid more prompt
    // don't delay for 'smd' in normal_cmd()
    msg_scroll = msg_scroll_save;
  }

  if (selected > 0 && selected <= sug.su_ga.ga_len && u_save_cursor() == OK) {
    // Save the from and to text for :spellrepall.
    XFREE_CLEAR(repl_from);
    XFREE_CLEAR(repl_to);

    stp = &SUG(sug.su_ga, selected - 1);
    if (sug.su_badlen > stp->st_orglen) {
      // Replacing less than "su_badlen", append the remainder to
      // repl_to.
      repl_from = xstrnsave(sug.su_badptr, (size_t)sug.su_badlen);
      vim_snprintf(IObuff, IOSIZE, "%s%.*s", stp->st_word,
                   sug.su_badlen - stp->st_orglen,
                   sug.su_badptr + stp->st_orglen);
      repl_to = xstrdup(IObuff);
    } else {
      // Replacing su_badlen or more, use the whole word.
      repl_from = xstrnsave(sug.su_badptr, (size_t)stp->st_orglen);
      repl_to = xstrdup(stp->st_word);
    }

    // Replace the word.
    char *p = xmalloc(strlen(line) - (size_t)stp->st_orglen + (size_t)stp->st_wordlen + 1);
    int c = (int)(sug.su_badptr - line);
    memmove(p, line, (size_t)c);
    STRCPY(p + c, stp->st_word);
    STRCAT(p, sug.su_badptr + stp->st_orglen);

    // For redo we use a change-word command.
    ResetRedobuff();
    AppendToRedobuff("ciw");
    AppendToRedobuffLit(p + c,
                        stp->st_wordlen + sug.su_badlen - stp->st_orglen);
    AppendCharToRedobuff(ESC);

    // "p" may be freed here
    ml_replace(curwin->w_cursor.lnum, p, false);
    curwin->w_cursor.col = c;

    inserted_bytes(curwin->w_cursor.lnum, c, stp->st_orglen, stp->st_wordlen);
  } else {
    curwin->w_cursor = prev_cursor;
  }

  spell_find_cleanup(&sug);
  xfree(line);
  curwin->w_p_spell = wo_spell_save;
}

/// Find spell suggestions for "word".  Return them in the growarray "*gap" as
/// a list of allocated strings.
///
/// @param maxcount  maximum nr of suggestions
/// @param need_cap  'spellcapcheck' matched
void spell_suggest_list(garray_T *gap, char *word, int maxcount, bool need_cap, bool interactive)
{
  suginfo_T sug;

  spell_find_suggest(word, 0, &sug, maxcount, false, need_cap, interactive);

  // Make room in "gap".
  ga_init(gap, sizeof(char *), sug.su_ga.ga_len + 1);
  ga_grow(gap, sug.su_ga.ga_len);
  for (int i = 0; i < sug.su_ga.ga_len; i++) {
    suggest_T *stp = &SUG(sug.su_ga, i);

    // The suggested word may replace only part of "word", add the not
    // replaced part.
    char *wcopy = xmalloc((size_t)stp->st_wordlen + strlen(sug.su_badptr + stp->st_orglen) + 1);
    STRCPY(wcopy, stp->st_word);
    STRCPY(wcopy + stp->st_wordlen, sug.su_badptr + stp->st_orglen);
    ((char **)gap->ga_data)[gap->ga_len++] = wcopy;
  }

  spell_find_cleanup(&sug);
}

/// Find spell suggestions for the word at the start of "badptr".
/// Return the suggestions in "su->su_ga".
/// The maximum number of suggestions is "maxcount".
/// Note: does use info for the current window.
/// This is based on the mechanisms of Aspell, but completely reimplemented.
///
/// @param badlen  length of bad word or 0 if unknown
/// @param banbadword  don't include badword in suggestions
/// @param need_cap  word should start with capital
static void spell_find_suggest(char *badptr, int badlen, suginfo_T *su, int maxcount,
                               bool banbadword, bool need_cap, bool interactive)
{
  hlf_T attr = HLF_COUNT;
  char buf[MAXPATHL];
  bool do_combine = false;
  static bool expr_busy = false;
  bool did_intern = false;

  // Set the info in "*su".
  CLEAR_POINTER(su);
  ga_init(&su->su_ga, (int)sizeof(suggest_T), 10);
  ga_init(&su->su_sga, (int)sizeof(suggest_T), 10);
  if (*badptr == NUL) {
    return;
  }
  hash_init(&su->su_banned);

  su->su_badptr = badptr;
  if (badlen != 0) {
    su->su_badlen = badlen;
  } else {
    size_t tmplen = spell_check(curwin, su->su_badptr, &attr, NULL, false);
    assert(tmplen <= INT_MAX);
    su->su_badlen = (int)tmplen;
  }
  su->su_maxcount = maxcount;
  su->su_maxscore = SCORE_MAXINIT;

  if (su->su_badlen >= MAXWLEN) {
    su->su_badlen = MAXWLEN - 1;        // just in case
  }
  xmemcpyz(su->su_badword, su->su_badptr, (size_t)su->su_badlen);
  spell_casefold(curwin, su->su_badptr, su->su_badlen, su->su_fbadword,
                 MAXWLEN);

  // TODO(vim): make this work if the case-folded text is longer than the
  // original text. Currently an illegal byte causes wrong pointer
  // computations.
  su->su_fbadword[su->su_badlen] = NUL;

  // get caps flags for bad word
  su->su_badflags = badword_captype(su->su_badptr,
                                    su->su_badptr + su->su_badlen);
  if (need_cap) {
    su->su_badflags |= WF_ONECAP;
  }

  // Find the default language for sound folding.  We simply use the first
  // one in 'spelllang' that supports sound folding.  That's good for when
  // using multiple files for one language, it's not that bad when mixing
  // languages (e.g., "pl,en").
  for (int i = 0; i < curbuf->b_s.b_langp.ga_len; i++) {
    langp_T *lp = LANGP_ENTRY(curbuf->b_s.b_langp, i);
    if (lp->lp_sallang != NULL) {
      su->su_sallang = lp->lp_sallang;
      break;
    }
  }

  // Soundfold the bad word with the default sound folding, so that we don't
  // have to do this many times.
  if (su->su_sallang != NULL) {
    spell_soundfold(su->su_sallang, su->su_fbadword, true,
                    su->su_sal_badword);
  }

  // If the word is not capitalised and spell_check() doesn't consider the
  // word to be bad then it might need to be capitalised.  Add a suggestion
  // for that.
  int c = utf_ptr2char(su->su_badptr);
  if (!SPELL_ISUPPER(c) && attr == HLF_COUNT) {
    make_case_word(su->su_badword, buf, WF_ONECAP);
    add_suggestion(su, &su->su_ga, buf, su->su_badlen, SCORE_ICASE,
                   0, true, su->su_sallang, false);
  }

  // Ban the bad word itself.  It may appear in another region.
  if (banbadword) {
    add_banned(su, su->su_badword);
  }

  // Make a copy of 'spellsuggest', because the expression may change it.
  char *sps_copy = xstrdup(p_sps);

  // Loop over the items in 'spellsuggest'.
  for (char *p = sps_copy; *p != NUL;) {
    copy_option_part(&p, buf, MAXPATHL, ",");

    if (strncmp(buf, "expr:", 5) == 0) {
      // Evaluate an expression.  Skip this when called recursively,
      // when using spellsuggest() in the expression.
      if (!expr_busy) {
        expr_busy = true;
        spell_suggest_expr(su, buf + 5);
        expr_busy = false;
      }
    } else if (strncmp(buf, "file:", 5) == 0) {
      // Use list of suggestions in a file.
      spell_suggest_file(su, buf + 5);
    } else if (strncmp(buf, "timeout:", 8) == 0) {
      // Limit the time searching for suggestions.
      spell_suggest_timeout = atoi(buf + 8);
    } else if (!did_intern) {
      // Use internal method once.
      spell_suggest_intern(su, interactive);
      if (sps_flags & SPS_DOUBLE) {
        do_combine = true;
      }
      did_intern = true;
    }
  }

  xfree(sps_copy);

  if (do_combine) {
    // Combine the two list of suggestions.  This must be done last,
    // because sorting changes the order again.
    score_combine(su);
  }
}

/// Find suggestions by evaluating expression "expr".
static void spell_suggest_expr(suginfo_T *su, char *expr)
{
  const char *p;

  // The work is split up in a few parts to avoid having to export
  // suginfo_T.
  // First evaluate the expression and get the resulting list.
  list_T *const list = eval_spell_expr(su->su_badword, expr);
  if (list != NULL) {
    // Loop over the items in the list.
    TV_LIST_ITER(list, li, {
      if (TV_LIST_ITEM_TV(li)->v_type == VAR_LIST) {
        // Get the word and the score from the items.
        int score = get_spellword(TV_LIST_ITEM_TV(li)->vval.v_list, &p);
        if (score >= 0 && score <= su->su_maxscore) {
          add_suggestion(su, &su->su_ga, p, su->su_badlen,
                         score, 0, true, su->su_sallang, false);
        }
      }
    });
    tv_list_unref(list);
  }

  // Remove bogus suggestions, sort and truncate at "maxcount".
  check_suggestions(su, &su->su_ga);
  cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
}

/// Find suggestions in file "fname".  Used for "file:" in 'spellsuggest'.
static void spell_suggest_file(suginfo_T *su, char *fname)
{
  char line[MAXWLEN * 2];
  int len;
  char cword[MAXWLEN];

  // Open the file.
  FILE *fd = os_fopen(fname, "r");
  if (fd == NULL) {
    semsg(_(e_notopen), fname);
    return;
  }

  // Read it line by line.
  while (!vim_fgets(line, MAXWLEN * 2, fd) && !got_int) {
    line_breakcheck();

    char *p = vim_strchr(line, '/');
    if (p == NULL) {
      continue;             // No Tab found, just skip the line.
    }
    *p++ = NUL;
    if (STRICMP(su->su_badword, line) == 0) {
      // Match!  Isolate the good word, until CR or NL.
      for (len = 0; (uint8_t)p[len] >= ' '; len++) {}
      p[len] = NUL;

      // If the suggestion doesn't have specific case duplicate the case
      // of the bad word.
      if (captype(p, NULL) == 0) {
        make_case_word(p, cword, su->su_badflags);
        p = cword;
      }

      add_suggestion(su, &su->su_ga, p, su->su_badlen,
                     SCORE_FILE, 0, true, su->su_sallang, false);
    }
  }

  fclose(fd);

  // Remove bogus suggestions, sort and truncate at "maxcount".
  check_suggestions(su, &su->su_ga);
  cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
}

/// Find suggestions for the internal method indicated by "sps_flags".
static void spell_suggest_intern(suginfo_T *su, bool interactive)
{
  // Load the .sug file(s) that are available and not done yet.
  suggest_load_files();

  // 1. Try special cases, such as repeating a word: "the the" -> "the".
  //
  // Set a maximum score to limit the combination of operations that is
  // tried.
  suggest_try_special(su);

  // 2. Try inserting/deleting/swapping/changing a letter, use REP entries
  //    from the .aff file and inserting a space (split the word).
  suggest_try_change(su);

  // For the resulting top-scorers compute the sound-a-like score.
  if (sps_flags & SPS_DOUBLE) {
    score_comp_sal(su);
  }

  // 3. Try finding sound-a-like words.
  if ((sps_flags & SPS_FAST) == 0) {
    if (sps_flags & SPS_BEST) {
      // Adjust the word score for the suggestions found so far for how
      // they sounds like.
      rescore_suggestions(su);
    }

    // While going through the soundfold tree "su_maxscore" is the score
    // for the soundfold word, limits the changes that are being tried,
    // and "su_sfmaxscore" the rescored score, which is set by
    // cleanup_suggestions().
    // First find words with a small edit distance, because this is much
    // faster and often already finds the top-N suggestions.  If we didn't
    // find many suggestions try again with a higher edit distance.
    // "sl_sounddone" is used to avoid doing the same word twice.
    suggest_try_soundalike_prep();
    su->su_maxscore = SCORE_SFMAX1;
    su->su_sfmaxscore = SCORE_MAXINIT * 3;
    suggest_try_soundalike(su);
    if (su->su_ga.ga_len < SUG_CLEAN_COUNT(su)) {
      // We didn't find enough matches, try again, allowing more
      // changes to the soundfold word.
      su->su_maxscore = SCORE_SFMAX2;
      suggest_try_soundalike(su);
      if (su->su_ga.ga_len < SUG_CLEAN_COUNT(su)) {
        // Still didn't find enough matches, try again, allowing even
        // more changes to the soundfold word.
        su->su_maxscore = SCORE_SFMAX3;
        suggest_try_soundalike(su);
      }
    }
    su->su_maxscore = su->su_sfmaxscore;
    suggest_try_soundalike_finish();
  }

  // When CTRL-C was hit while searching do show the results.  Only clear
  // got_int when using a command, not for spellsuggest().
  os_breakcheck();
  if (interactive && got_int) {
    vgetc();
    got_int = false;
  }

  if ((sps_flags & SPS_DOUBLE) == 0 && su->su_ga.ga_len != 0) {
    if (sps_flags & SPS_BEST) {
      // Adjust the word score for how it sounds like.
      rescore_suggestions(su);
    }

    // Remove bogus suggestions, sort and truncate at "maxcount".
    check_suggestions(su, &su->su_ga);
    cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
  }
}

/// Free the info put in "*su" by spell_find_suggest().
static void spell_find_cleanup(suginfo_T *su)
{
#define FREE_SUG_WORD(sug) xfree((sug)->st_word)
  // Free the suggestions.
  GA_DEEP_CLEAR(&su->su_ga, suggest_T, FREE_SUG_WORD);
  GA_DEEP_CLEAR(&su->su_sga, suggest_T, FREE_SUG_WORD);

  // Free the banned words.
  hash_clear_all(&su->su_banned, 0);
}

/// Try finding suggestions by recognizing specific situations.
static void suggest_try_special(suginfo_T *su)
{
  char word[MAXWLEN];

  // Recognize a word that is repeated: "the the".
  char *p = skiptowhite(su->su_fbadword);
  size_t len = (size_t)(p - su->su_fbadword);
  p = skipwhite(p);
  if (strlen(p) == len && strncmp(su->su_fbadword, p, len) == 0) {
    // Include badflags: if the badword is onecap or allcap
    // use that for the goodword too: "The the" -> "The".
    char c = su->su_fbadword[len];
    su->su_fbadword[len] = NUL;
    make_case_word(su->su_fbadword, word, su->su_badflags);
    su->su_fbadword[len] = c;

    // Give a soundalike score of 0, compute the score as if deleting one
    // character.
    add_suggestion(su, &su->su_ga, word, su->su_badlen,
                   RESCORE(SCORE_REP, 0), 0, true, su->su_sallang, false);
  }
}

// Measure how much time is spent in each state.
// Output is dumped in "suggestprof".

#ifdef SUGGEST_PROFILE
proftime_T current;
proftime_T total;
proftime_T times[STATE_FINAL + 1];
long counts[STATE_FINAL + 1];

static void prof_init(void)
{
  for (int i = 0; i <= STATE_FINAL; i++) {
    profile_zero(&times[i]);
    counts[i] = 0;
  }
  profile_start(&current);
  profile_start(&total);
}

/// call before changing state
static void prof_store(state_T state)
{
  profile_end(&current);
  profile_add(&times[state], &current);
  counts[state]++;
  profile_start(&current);
}
# define PROF_STORE(state) prof_store(state);

static void prof_report(char *name)
{
  FILE *fd = fopen("suggestprof", "a");

  profile_end(&total);
  fprintf(fd, "-----------------------\n");
  fprintf(fd, "%s: %s\n", name, profile_msg(&total));
  for (int i = 0; i <= STATE_FINAL; i++) {
    fprintf(fd, "%d: %s ("%" PRId64)\n", i, profile_msg(&times[i]), counts[i]);
  }
  fclose(fd);
}
#else
# define PROF_STORE(state)
#endif

/// Try finding suggestions by adding/removing/swapping letters.
static void suggest_try_change(suginfo_T *su)
{
  char fword[MAXWLEN];            // copy of the bad word, case-folded

  // We make a copy of the case-folded bad word, so that we can modify it
  // to find matches (esp. REP items).  Append some more text, changing
  // chars after the bad word may help.
  STRCPY(fword, su->su_fbadword);
  int n = (int)strlen(fword);
  char *p = su->su_badptr + su->su_badlen;
  spell_casefold(curwin, p, (int)strlen(p), fword + n, MAXWLEN - n);

  // Make sure the resulting text is not longer than the original text.
  n = (int)strlen(su->su_badptr);
  if (n < MAXWLEN) {
    fword[n] = NUL;
  }

  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    langp_T *lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);

    // If reloading a spell file fails it's still in the list but
    // everything has been cleared.
    if (lp->lp_slang->sl_fbyts == NULL) {
      continue;
    }

    // Try it for this language.  Will add possible suggestions.
#ifdef SUGGEST_PROFILE
    prof_init();
#endif
    suggest_trie_walk(su, lp, fword, false);
#ifdef SUGGEST_PROFILE
    prof_report("try_change");
#endif
  }
}

// Check the maximum score, if we go over it we won't try this change.
#define TRY_DEEPER(su, stack, depth, add) \
  ((depth) < MAXWLEN - 1 && (stack)[depth].ts_score + (add) < (su)->su_maxscore)

/// Try finding suggestions by adding/removing/swapping letters.
///
/// This uses a state machine.  At each node in the tree we try various
/// operations.  When trying if an operation works "depth" is increased and the
/// stack[] is used to store info.  This allows combinations, thus insert one
/// character, replace one and delete another.  The number of changes is
/// limited by su->su_maxscore.
///
/// After implementing this I noticed an article by Kemal Oflazer that
/// describes something similar: "Error-tolerant Finite State Recognition with
/// Applications to Morphological Analysis and Spelling Correction" (1996).
/// The implementation in the article is simplified and requires a stack of
/// unknown depth.  The implementation here only needs a stack depth equal to
/// the length of the word.
///
/// This is also used for the sound-folded word, "soundfold" is true then.
/// The mechanism is the same, but we find a match with a sound-folded word
/// that comes from one or more original words.  Each of these words may be
/// added, this is done by add_sound_suggest().
/// Don't use:
///      the prefix tree or the keep-case tree
///      "su->su_badlen"
///      anything to do with upper and lower case
///      anything to do with word or non-word characters ("spell_iswordp()")
///      banned words
///      word flags (rare, region, compounding)
///      word splitting for now
///      "similar_chars()"
///      use "slang->sl_repsal" instead of "lp->lp_replang->sl_rep"
static void suggest_trie_walk(suginfo_T *su, langp_T *lp, char *fword, bool soundfold)
{
  char tword[MAXWLEN];            // good word collected so far
  trystate_T stack[MAXWLEN];
  char preword[MAXWLEN * 3] = { 0 };  // word found with proper case;
  // concatenation of prefix compound
  // words and split word.  NUL terminated
  // when going deeper but not when coming
  // back.
  uint8_t compflags[MAXWLEN];        // compound flags, one for each word
  uint8_t *byts, *fbyts, *pbyts;
  idx_T *idxs, *fidxs, *pidxs;
  int c, c2, c3;
  int n = 0;
  garray_T *gap;
  idx_T arridx;
  int fl = 0;
  int tl;
  int repextra = 0;                 // extra bytes in fword[] from REP item
  slang_T *slang = lp->lp_slang;
  bool goodword_ends;
#ifdef DEBUG_TRIEWALK
  // Stores the name of the change made at each level.
  uint8_t changename[MAXWLEN][80];
#endif
  int breakcheckcount = 1000;

  // Go through the whole case-fold tree, try changes at each node.
  // "tword[]" contains the word collected from nodes in the tree.
  // "fword[]" the word we are trying to match with (initially the bad
  // word).
  int depth = 0;
  trystate_T *sp = &stack[0];
  CLEAR_POINTER(sp);
  sp->ts_curi = 1;

  if (soundfold) {
    // Going through the soundfold tree.
    byts = fbyts = slang->sl_sbyts;
    idxs = fidxs = slang->sl_sidxs;
    pbyts = NULL;
    pidxs = NULL;
    sp->ts_prefixdepth = PFD_NOPREFIX;
    sp->ts_state = STATE_START;
  } else {
    // When there are postponed prefixes we need to use these first.  At
    // the end of the prefix we continue in the case-fold tree.
    fbyts = slang->sl_fbyts;
    fidxs = slang->sl_fidxs;
    pbyts = slang->sl_pbyts;
    pidxs = slang->sl_pidxs;
    if (pbyts != NULL) {
      byts = pbyts;
      idxs = pidxs;
      sp->ts_prefixdepth = PFD_PREFIXTREE;
      sp->ts_state = STATE_NOPREFIX;            // try without prefix first
    } else {
      byts = fbyts;
      idxs = fidxs;
      sp->ts_prefixdepth = PFD_NOPREFIX;
      sp->ts_state = STATE_START;
    }
  }

  // The loop may take an indefinite amount of time. Break out after some
  // time.
  proftime_T time_limit = 0;
  if (spell_suggest_timeout > 0) {
    time_limit = profile_setlimit(spell_suggest_timeout);
  }

  // Loop to find all suggestions.  At each round we either:
  // - For the current state try one operation, advance "ts_curi",
  //   increase "depth".
  // - When a state is done go to the next, set "ts_state".
  // - When all states are tried decrease "depth".
  while (depth >= 0 && !got_int) {
    sp = &stack[depth];
    switch (sp->ts_state) {
    case STATE_START:
    case STATE_NOPREFIX:
      // Start of node: Deal with NUL bytes, which means
      // tword[] may end here.
      arridx = sp->ts_arridx;               // current node in the tree
      int len = byts[arridx];                   // bytes in this node
      arridx += sp->ts_curi;                // index of current byte

      if (sp->ts_prefixdepth == PFD_PREFIXTREE) {
        // Skip over the NUL bytes, we use them later.
        for (n = 0; n < len && byts[arridx + n] == 0; n++) {}
        sp->ts_curi = (int16_t)(sp->ts_curi + n);

        // Always past NUL bytes now.
        n = (int)sp->ts_state;
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_ENDNUL;
        sp->ts_save_badflags = (uint8_t)su->su_badflags;

        // At end of a prefix or at start of prefixtree: check for
        // following word.
        if (depth < MAXWLEN - 1 && (byts[arridx] == 0 || n == STATE_NOPREFIX)) {
          // Set su->su_badflags to the caps type at this position.
          // Use the caps type until here for the prefix itself.
          n = nofold_len(fword, sp->ts_fidx, su->su_badptr);
          int flags = badword_captype(su->su_badptr, su->su_badptr + n);
          su->su_badflags = badword_captype(su->su_badptr + n,
                                            su->su_badptr + su->su_badlen);
#ifdef DEBUG_TRIEWALK
          sprintf(changename[depth], "prefix");  // NOLINT(runtime/printf)
#endif
          go_deeper(stack, depth, 0);
          depth++;
          sp = &stack[depth];
          sp->ts_prefixdepth = (uint8_t)(depth - 1);
          byts = fbyts;
          idxs = fidxs;
          sp->ts_arridx = 0;

          // Move the prefix to preword[] with the right case
          // and make find_keepcap_word() works.
          tword[sp->ts_twordlen] = NUL;
          make_case_word(tword + sp->ts_splitoff,
                         preword + sp->ts_prewordlen, flags);
          sp->ts_prewordlen = (uint8_t)strlen(preword);
          sp->ts_splitoff = sp->ts_twordlen;
        }
        break;
      }

      if (sp->ts_curi > len || byts[arridx] != 0) {
        // Past bytes in node and/or past NUL bytes.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_ENDNUL;
        sp->ts_save_badflags = (uint8_t)su->su_badflags;
        break;
      }

      // End of word in tree.
      sp->ts_curi++;                    // eat one NUL byte

      int flags = (int)idxs[arridx];

      // Skip words with the NOSUGGEST flag.
      if (flags & WF_NOSUGGEST) {
        break;
      }

      bool fword_ends = (fword[sp->ts_fidx] == NUL
                         || (soundfold
                             ? ascii_iswhite(fword[sp->ts_fidx])
                             : !spell_iswordp(fword + sp->ts_fidx, curwin)));
      tword[sp->ts_twordlen] = NUL;

      if (sp->ts_prefixdepth <= PFD_NOTSPECIAL
          && (sp->ts_flags & TSF_PREFIXOK) == 0
          && pbyts != NULL) {
        // There was a prefix before the word.  Check that the prefix
        // can be used with this word.
        // Count the length of the NULs in the prefix.  If there are
        // none this must be the first try without a prefix.
        n = stack[sp->ts_prefixdepth].ts_arridx;
        len = pbyts[n++];
        for (c = 0; c < len && pbyts[n + c] == 0; c++) {}
        if (c > 0) {
          c = valid_word_prefix(c, n, flags,
                                tword + sp->ts_splitoff, slang, false);
          if (c == 0) {
            break;
          }

          // Use the WF_RARE flag for a rare prefix.
          if (c & WF_RAREPFX) {
            flags |= WF_RARE;
          }

          // Tricky: when checking for both prefix and compounding
          // we run into the prefix flag first.
          // Remember that it's OK, so that we accept the prefix
          // when arriving at a compound flag.
          sp->ts_flags |= TSF_PREFIXOK;
        }
      }

      // Check NEEDCOMPOUND: can't use word without compounding.  Do try
      // appending another compound word below.
      if (sp->ts_complen == sp->ts_compsplit && fword_ends
          && (flags & WF_NEEDCOMP)) {
        goodword_ends = false;
      } else {
        goodword_ends = true;
      }

      char *p = NULL;
      bool compound_ok = true;
      if (sp->ts_complen > sp->ts_compsplit) {
        if (slang->sl_nobreak) {
          // There was a word before this word.  When there was no
          // change in this word (it was correct) add the first word
          // as a suggestion.  If this word was corrected too, we
          // need to check if a correct word follows.
          if (sp->ts_fidx - sp->ts_splitfidx
              == sp->ts_twordlen - sp->ts_splitoff
              && strncmp(fword + sp->ts_splitfidx,
                         tword + sp->ts_splitoff,
                         (size_t)(sp->ts_fidx - sp->ts_splitfidx)) == 0) {
            preword[sp->ts_prewordlen] = NUL;
            int newscore = score_wordcount_adj(slang, sp->ts_score,
                                               preword + sp->ts_prewordlen,
                                               sp->ts_prewordlen > 0);
            // Add the suggestion if the score isn't too bad.
            if (newscore <= su->su_maxscore) {
              add_suggestion(su, &su->su_ga, preword,
                             sp->ts_splitfidx - repextra,
                             newscore, 0, false,
                             lp->lp_sallang, false);
            }
            break;
          }
        } else {
          // There was a compound word before this word.  If this
          // word does not support compounding then give up
          // (splitting is tried for the word without compound
          // flag).
          if (((unsigned)flags >> 24) == 0
              || sp->ts_twordlen - sp->ts_splitoff
              < slang->sl_compminlen) {
            break;
          }
          // For multi-byte chars check character length against
          // COMPOUNDMIN.
          if (slang->sl_compminlen > 0
              && mb_charlen(tword + sp->ts_splitoff)
              < slang->sl_compminlen) {
            break;
          }

          compflags[sp->ts_complen] = (uint8_t)((unsigned)flags >> 24);
          compflags[sp->ts_complen + 1] = NUL;
          xmemcpyz(preword + sp->ts_prewordlen,
                   tword + sp->ts_splitoff,
                   (size_t)(sp->ts_twordlen - sp->ts_splitoff));

          // Verify CHECKCOMPOUNDPATTERN  rules.
          if (match_checkcompoundpattern(preword,  sp->ts_prewordlen,
                                         &slang->sl_comppat)) {
            compound_ok = false;
          }

          if (compound_ok) {
            p = preword;
            while (*skiptowhite(p) != NUL) {
              p = skipwhite(skiptowhite(p));
            }
            if (fword_ends && !can_compound(slang, p, compflags + sp->ts_compsplit)) {
              // Compound is not allowed.  But it may still be
              // possible if we add another (short) word.
              compound_ok = false;
            }
          }

          // Get pointer to last char of previous word.
          p = preword + sp->ts_prewordlen;
          MB_PTR_BACK(preword, p);
        }
      }

      // Form the word with proper case in preword.
      // If there is a word from a previous split, append.
      // For the soundfold tree don't change the case, simply append.
      if (soundfold) {
        STRCPY(preword + sp->ts_prewordlen, tword + sp->ts_splitoff);
      } else if (flags & WF_KEEPCAP) {
        // Must find the word in the keep-case tree.
        find_keepcap_word(slang, tword + sp->ts_splitoff, preword + sp->ts_prewordlen);
      } else {
        // Include badflags: If the badword is onecap or allcap
        // use that for the goodword too.  But if the badword is
        // allcap and it's only one char long use onecap.
        c = su->su_badflags;
        if ((c & WF_ALLCAP) && su->su_badlen == utfc_ptr2len(su->su_badptr)) {
          c = WF_ONECAP;
        }
        c |= flags;

        // When appending a compound word after a word character don't
        // use Onecap.
        if (p != NULL && spell_iswordp_nmw(p, curwin)) {
          c &= ~WF_ONECAP;
        }
        make_case_word(tword + sp->ts_splitoff,
                       preword + sp->ts_prewordlen, c);
      }

      if (!soundfold) {
        // Don't use a banned word.  It may appear again as a good
        // word, thus remember it.
        if (flags & WF_BANNED) {
          add_banned(su, preword + sp->ts_prewordlen);
          break;
        }
        if ((sp->ts_complen == sp->ts_compsplit
             && WAS_BANNED(su, preword + sp->ts_prewordlen))
            || WAS_BANNED(su, preword)) {
          if (slang->sl_compprog == NULL) {
            break;
          }
          // the word so far was banned but we may try compounding
          goodword_ends = false;
        }
      }

      int newscore = 0;
      if (!soundfold) {         // soundfold words don't have flags
        if ((flags & WF_REGION)
            && (((unsigned)flags >> 16) & (unsigned)lp->lp_region) == 0) {
          newscore += SCORE_REGION;
        }
        if (flags & WF_RARE) {
          newscore += SCORE_RARE;
        }

        if (!spell_valid_case(su->su_badflags,
                              captype(preword + sp->ts_prewordlen, NULL))) {
          newscore += SCORE_ICASE;
        }
      }

      // TODO(vim): how about splitting in the soundfold tree?
      if (fword_ends
          && goodword_ends
          && sp->ts_fidx >= sp->ts_fidxtry
          && compound_ok) {
        // The badword also ends: add suggestions.
#ifdef DEBUG_TRIEWALK
        if (soundfold && strcmp(preword, "smwrd") == 0) {
          int j;

          // print the stack of changes that brought us here
          smsg(0, "------ %s -------", fword);
          for (j = 0; j < depth; j++) {
            smsg(0, "%s", changename[j]);
          }
        }
#endif
        if (soundfold) {
          // For soundfolded words we need to find the original
          // words, the edit distance and then add them.
          add_sound_suggest(su, preword, sp->ts_score, lp);
        } else if (sp->ts_fidx > 0) {
          // Give a penalty when changing non-word char to word
          // char, e.g., "thes," -> "these".
          p = fword + sp->ts_fidx;
          MB_PTR_BACK(fword, p);
          if (!spell_iswordp(p, curwin) && *preword != NUL) {
            p = preword + strlen(preword);
            MB_PTR_BACK(preword, p);
            if (spell_iswordp(p, curwin)) {
              newscore += SCORE_NONWORD;
            }
          }

          // Give a bonus to words seen before.
          int score = score_wordcount_adj(slang,
                                          sp->ts_score + newscore,
                                          preword + sp->ts_prewordlen,
                                          sp->ts_prewordlen > 0);

          // Add the suggestion if the score isn't too bad.
          if (score <= su->su_maxscore) {
            add_suggestion(su, &su->su_ga, preword,
                           sp->ts_fidx - repextra,
                           score, 0, false, lp->lp_sallang, false);

            if (su->su_badflags & WF_MIXCAP) {
              // We really don't know if the word should be
              // upper or lower case, add both.
              c = captype(preword, NULL);
              if (c == 0 || c == WF_ALLCAP) {
                make_case_word(tword + sp->ts_splitoff,
                               preword + sp->ts_prewordlen,
                               c == 0 ? WF_ALLCAP : 0);

                add_suggestion(su, &su->su_ga, preword,
                               sp->ts_fidx - repextra,
                               score + SCORE_ICASE, 0, false,
                               lp->lp_sallang, false);
              }
            }
          }
        }
      }

      // Try word split and/or compounding.
      if ((sp->ts_fidx >= sp->ts_fidxtry || fword_ends)
          // Don't split in the middle of a character
          && (sp->ts_tcharlen == 0)) {
        bool try_compound;
        int try_split;

        // If past the end of the bad word don't try a split.
        // Otherwise try changing the next word.  E.g., find
        // suggestions for "the the" where the second "the" is
        // different.  It's done like a split.
        // TODO(vim): word split for soundfold words
        try_split = (sp->ts_fidx - repextra < su->su_badlen)
                    && !soundfold;

        // Get here in several situations:
        // 1. The word in the tree ends:
        //    If the word allows compounding try that.  Otherwise try
        //    a split by inserting a space.  For both check that a
        //    valid words starts at fword[sp->ts_fidx].
        //    For NOBREAK do like compounding to be able to check if
        //    the next word is valid.
        // 2. The badword does end, but it was due to a change (e.g.,
        //    a swap).  No need to split, but do check that the
        //    following word is valid.
        // 3. The badword and the word in the tree end.  It may still
        //    be possible to compound another (short) word.
        try_compound = false;
        if (!soundfold
            && !slang->sl_nocompoundsugs
            && slang->sl_compprog != NULL
            && ((unsigned)flags >> 24) != 0
            && sp->ts_twordlen - sp->ts_splitoff
            >= slang->sl_compminlen
            && (slang->sl_compminlen == 0
                || mb_charlen(tword + sp->ts_splitoff)
                >= slang->sl_compminlen)
            && (slang->sl_compsylmax < MAXWLEN
                || sp->ts_complen + 1 - sp->ts_compsplit
                < slang->sl_compmax)
            && (can_be_compound(sp, slang, compflags, (int)((unsigned)flags >> 24)))) {
          try_compound = true;
          compflags[sp->ts_complen] = (uint8_t)((unsigned)flags >> 24);
          compflags[sp->ts_complen + 1] = NUL;
        }

        // For NOBREAK we never try splitting, it won't make any word
        // valid.
        if (slang->sl_nobreak && !slang->sl_nocompoundsugs) {
          try_compound = true;
        } else if (!fword_ends
                   && try_compound
                   && (sp->ts_flags & TSF_DIDSPLIT) == 0) {
          // If we could add a compound word, and it's also possible to
          // split at this point, do the split first and set
          // TSF_DIDSPLIT to avoid doing it again.
          try_compound = false;
          sp->ts_flags |= TSF_DIDSPLIT;
          sp->ts_curi--;                    // do the same NUL again
          compflags[sp->ts_complen] = NUL;
        } else {
          sp->ts_flags &= (uint8_t) ~TSF_DIDSPLIT;
        }

        if (try_split || try_compound) {
          if (!try_compound && (!fword_ends || !goodword_ends)) {
            // If we're going to split need to check that the
            // words so far are valid for compounding.  If there
            // is only one word it must not have the NEEDCOMPOUND
            // flag.
            if (sp->ts_complen == sp->ts_compsplit
                && (flags & WF_NEEDCOMP)) {
              break;
            }
            p = preword;
            while (*skiptowhite(p) != NUL) {
              p = skipwhite(skiptowhite(p));
            }
            if (sp->ts_complen > sp->ts_compsplit
                && !can_compound(slang, p, compflags + sp->ts_compsplit)) {
              break;
            }

            if (slang->sl_nosplitsugs) {
              newscore += SCORE_SPLIT_NO;
            } else {
              newscore += SCORE_SPLIT;
            }

            // Give a bonus to words seen before.
            newscore = score_wordcount_adj(slang, newscore,
                                           preword + sp->ts_prewordlen, true);
          }

          if (TRY_DEEPER(su, stack, depth, newscore)) {
            go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
            if (!try_compound && !fword_ends) {
              sprintf(changename[depth], "%.*s-%s: split",  // NOLINT(runtime/printf)
                      sp->ts_twordlen, tword, fword + sp->ts_fidx);
            } else {
              sprintf(changename[depth], "%.*s-%s: compound",  // NOLINT(runtime/printf)
                      sp->ts_twordlen, tword, fword + sp->ts_fidx);
            }
#endif
            // Save things to be restored at STATE_SPLITUNDO.
            sp->ts_save_badflags = (uint8_t)su->su_badflags;
            PROF_STORE(sp->ts_state)
            sp->ts_state = STATE_SPLITUNDO;

            depth++;
            sp = &stack[depth];

            // Append a space to preword when splitting.
            if (!try_compound && !fword_ends) {
              STRCAT(preword, " ");
            }
            sp->ts_prewordlen = (uint8_t)strlen(preword);
            sp->ts_splitoff = sp->ts_twordlen;
            sp->ts_splitfidx = sp->ts_fidx;

            // If the badword has a non-word character at this
            // position skip it.  That means replacing the
            // non-word character with a space.  Always skip a
            // character when the word ends.  But only when the
            // good word can end.
            if (((!try_compound && !spell_iswordp_nmw(fword
                                                      + sp->ts_fidx,
                                                      curwin))
                 || fword_ends)
                && fword[sp->ts_fidx] != NUL
                && goodword_ends) {
              int l;

              l = utfc_ptr2len(fword + sp->ts_fidx);
              if (fword_ends) {
                // Copy the skipped character to preword.
                memmove(preword + sp->ts_prewordlen, fword + sp->ts_fidx, (size_t)l);
                sp->ts_prewordlen = (uint8_t)(sp->ts_prewordlen + l);
                preword[sp->ts_prewordlen] = NUL;
              } else {
                sp->ts_score -= SCORE_SPLIT - SCORE_SUBST;
              }
              sp->ts_fidx = (uint8_t)(sp->ts_fidx + l);
            }

            // When compounding include compound flag in
            // compflags[] (already set above).  When splitting we
            // may start compounding over again.
            if (try_compound) {
              sp->ts_complen++;
            } else {
              sp->ts_compsplit = sp->ts_complen;
            }
            sp->ts_prefixdepth = PFD_NOPREFIX;

            // set su->su_badflags to the caps type at this
            // position
            n = nofold_len(fword, sp->ts_fidx, su->su_badptr);
            su->su_badflags = badword_captype(su->su_badptr + n,
                                              su->su_badptr + su->su_badlen);

            // Restart at top of the tree.
            sp->ts_arridx = 0;

            // If there are postponed prefixes, try these too.
            if (pbyts != NULL) {
              byts = pbyts;
              idxs = pidxs;
              sp->ts_prefixdepth = PFD_PREFIXTREE;
              PROF_STORE(sp->ts_state)
              sp->ts_state = STATE_NOPREFIX;
            }
          }
        }
      }
      break;

    case STATE_SPLITUNDO:
      // Undo the changes done for word split or compound word.
      su->su_badflags = sp->ts_save_badflags;

      // Continue looking for NUL bytes.
      PROF_STORE(sp->ts_state)
      sp->ts_state = STATE_START;

      // In case we went into the prefix tree.
      byts = fbyts;
      idxs = fidxs;
      break;

    case STATE_ENDNUL:
      // Past the NUL bytes in the node.
      su->su_badflags = sp->ts_save_badflags;
      if (fword[sp->ts_fidx] == NUL
          && sp->ts_tcharlen == 0) {
        // The badword ends, can't use STATE_PLAIN.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_DEL;
        break;
      }
      PROF_STORE(sp->ts_state)
      sp->ts_state = STATE_PLAIN;
      FALLTHROUGH;

    case STATE_PLAIN:
      // Go over all possible bytes at this node, add each to tword[]
      // and use child node.  "ts_curi" is the index.
      arridx = sp->ts_arridx;
      if (sp->ts_curi > byts[arridx]) {
        // Done all bytes at this node, do next state.  When still at
        // already changed bytes skip the other tricks.
        PROF_STORE(sp->ts_state)
        if (sp->ts_fidx >= sp->ts_fidxtry) {
          sp->ts_state = STATE_DEL;
        } else {
          sp->ts_state = STATE_FINAL;
        }
      } else {
        arridx += sp->ts_curi++;
        c = byts[arridx];

        // Normal byte, go one level deeper.  If it's not equal to the
        // byte in the bad word adjust the score.  But don't even try
        // when the byte was already changed.  And don't try when we
        // just deleted this byte, accepting it is always cheaper than
        // delete + substitute.
        if (c == (uint8_t)fword[sp->ts_fidx]
            || (sp->ts_tcharlen > 0
                && sp->ts_isdiff != DIFF_NONE)) {
          newscore = 0;
        } else {
          newscore = SCORE_SUBST;
        }
        if ((newscore == 0
             || (sp->ts_fidx >= sp->ts_fidxtry
                 && ((sp->ts_flags & TSF_DIDDEL) == 0
                     || c != (uint8_t)fword[sp->ts_delidx])))
            && TRY_DEEPER(su, stack, depth, newscore)) {
          go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
          if (newscore > 0) {
            sprintf(changename[depth], "%.*s-%s: subst %c to %c",  // NOLINT(runtime/printf)
                    sp->ts_twordlen, tword, fword + sp->ts_fidx,
                    fword[sp->ts_fidx], c);
          } else {
            sprintf(changename[depth], "%.*s-%s: accept %c",  // NOLINT(runtime/printf)
                    sp->ts_twordlen, tword, fword + sp->ts_fidx,
                    fword[sp->ts_fidx]);
          }
#endif
          depth++;
          sp = &stack[depth];
          if (fword[sp->ts_fidx] != NUL) {
            sp->ts_fidx++;
          }
          tword[sp->ts_twordlen++] = (char)c;
          sp->ts_arridx = idxs[arridx];
          if (newscore == SCORE_SUBST) {
            sp->ts_isdiff = DIFF_YES;
          }
          // Multi-byte characters are a bit complicated to
          // handle: They differ when any of the bytes differ
          // and then their length may also differ.
          if (sp->ts_tcharlen == 0) {
            // First byte.
            sp->ts_tcharidx = 0;
            sp->ts_tcharlen = MB_BYTE2LEN(c);
            sp->ts_fcharstart = (uint8_t)(sp->ts_fidx - 1);
            sp->ts_isdiff = (newscore != 0)
                            ? DIFF_YES : DIFF_NONE;
          } else if (sp->ts_isdiff == DIFF_INSERT && sp->ts_fidx > 0) {
            // When inserting trail bytes don't advance in the
            // bad word.
            sp->ts_fidx--;
          }
          if (++sp->ts_tcharidx == sp->ts_tcharlen) {
            // Last byte of character.
            if (sp->ts_isdiff == DIFF_YES) {
              // Correct ts_fidx for the byte length of the
              // character (we didn't check that before).
              sp->ts_fidx = (uint8_t)(sp->ts_fcharstart
                                      + utfc_ptr2len(fword + sp->ts_fcharstart));

              // For changing a composing character adjust
              // the score from SCORE_SUBST to
              // SCORE_SUBCOMP.
              if (utf_iscomposing(utf_ptr2char(tword + sp->ts_twordlen
                                               - sp->ts_tcharlen))
                  && utf_iscomposing(utf_ptr2char(fword
                                                  + sp->ts_fcharstart))) {
                sp->ts_score -= SCORE_SUBST - SCORE_SUBCOMP;
              } else if (!soundfold
                         && slang->sl_has_map
                         && similar_chars(slang,
                                          utf_ptr2char(tword + sp->ts_twordlen -
                                                       sp->ts_tcharlen),
                                          utf_ptr2char(fword + sp->ts_fcharstart))) {
                // For a similar character adjust score from
                // SCORE_SUBST to SCORE_SIMILAR.
                sp->ts_score -= SCORE_SUBST - SCORE_SIMILAR;
              }
            } else if (sp->ts_isdiff == DIFF_INSERT
                       && sp->ts_twordlen > sp->ts_tcharlen) {
              p = tword + sp->ts_twordlen - sp->ts_tcharlen;
              c = utf_ptr2char(p);
              if (utf_iscomposing(c)) {
                // Inserting a composing char doesn't
                // count that much.
                sp->ts_score -= SCORE_INS - SCORE_INSCOMP;
              } else {
                // If the previous character was the same,
                // thus doubling a character, give a bonus
                // to the score.  Also for the soundfold
                // tree (might seem illogical but does
                // give better scores).
                MB_PTR_BACK(tword, p);
                if (c == utf_ptr2char(p)) {
                  sp->ts_score -= SCORE_INS - SCORE_INSDUP;
                }
              }
            }

            // Starting a new char, reset the length.
            sp->ts_tcharlen = 0;
          }
        }
      }
      break;

    case STATE_DEL:
      // When past the first byte of a multi-byte char don't try
      // delete/insert/swap a character.
      if (sp->ts_tcharlen > 0) {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_FINAL;
        break;
      }
      // Try skipping one character in the bad word (delete it).
      PROF_STORE(sp->ts_state)
      sp->ts_state = STATE_INS_PREP;
      sp->ts_curi = 1;
      if (soundfold && sp->ts_fidx == 0 && fword[sp->ts_fidx] == '*') {
        // Deleting a vowel at the start of a word counts less, see
        // soundalike_score().
        newscore = 2 * SCORE_DEL / 3;
      } else {
        newscore = SCORE_DEL;
      }
      if (fword[sp->ts_fidx] != NUL
          && TRY_DEEPER(su, stack, depth, newscore)) {
        go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
        sprintf(changename[depth], "%.*s-%s: delete %c",  // NOLINT(runtime/printf)
                sp->ts_twordlen, tword, fword + sp->ts_fidx,
                fword[sp->ts_fidx]);
#endif
        depth++;

        // Remember what character we deleted, so that we can avoid
        // inserting it again.
        stack[depth].ts_flags |= TSF_DIDDEL;
        stack[depth].ts_delidx = sp->ts_fidx;

        // Advance over the character in fword[].  Give a bonus to the
        // score if the same character is following "nn" -> "n".  It's
        // a bit illogical for soundfold tree but it does give better
        // results.
        c = utf_ptr2char(fword + sp->ts_fidx);
        stack[depth].ts_fidx =
          (uint8_t)(stack[depth].ts_fidx + utfc_ptr2len(fword + sp->ts_fidx));
        if (utf_iscomposing(c)) {
          stack[depth].ts_score -= SCORE_DEL - SCORE_DELCOMP;
        } else if (c == utf_ptr2char(fword + stack[depth].ts_fidx)) {
          stack[depth].ts_score -= SCORE_DEL - SCORE_DELDUP;
        }

        break;
      }
      FALLTHROUGH;

    case STATE_INS_PREP:
      if (sp->ts_flags & TSF_DIDDEL) {
        // If we just deleted a byte then inserting won't make sense,
        // a substitute is always cheaper.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_SWAP;
        break;
      }

      // skip over NUL bytes
      n = sp->ts_arridx;
      while (true) {
        if (sp->ts_curi > byts[n]) {
          // Only NUL bytes at this node, go to next state.
          PROF_STORE(sp->ts_state)
          sp->ts_state = STATE_SWAP;
          break;
        }
        if (byts[n + sp->ts_curi] != NUL) {
          // Found a byte to insert.
          PROF_STORE(sp->ts_state)
          sp->ts_state = STATE_INS;
          break;
        }
        sp->ts_curi++;
      }
      break;

    case STATE_INS:
      // Insert one byte.  Repeat this for each possible byte at this
      // node.
      n = sp->ts_arridx;
      if (sp->ts_curi > byts[n]) {
        // Done all bytes at this node, go to next state.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_SWAP;
        break;
      }

      // Do one more byte at this node, but:
      // - Skip NUL bytes.
      // - Skip the byte if it's equal to the byte in the word,
      //   accepting that byte is always better.
      n += sp->ts_curi++;

      // break out, if we would be accessing byts buffer out of bounds
      if (byts == slang->sl_fbyts && n >= slang->sl_fbyts_len) {
        got_int = true;
        break;
      }
      c = byts[n];
      if (soundfold && sp->ts_twordlen == 0 && c == '*') {
        // Inserting a vowel at the start of a word counts less,
        // see soundalike_score().
        newscore = 2 * SCORE_INS / 3;
      } else {
        newscore = SCORE_INS;
      }
      if (c != (uint8_t)fword[sp->ts_fidx]
          && TRY_DEEPER(su, stack, depth, newscore)) {
        go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
        sprintf(changename[depth], "%.*s-%s: insert %c",  // NOLINT(runtime/printf)
                sp->ts_twordlen, tword, fword + sp->ts_fidx,
                c);
#endif
        depth++;
        sp = &stack[depth];
        tword[sp->ts_twordlen++] = (char)c;
        sp->ts_arridx = idxs[n];
        fl = MB_BYTE2LEN(c);
        if (fl > 1) {
          // There are following bytes for the same character.
          // We must find all bytes before trying
          // delete/insert/swap/etc.
          sp->ts_tcharlen = (uint8_t)fl;
          sp->ts_tcharidx = 1;
          sp->ts_isdiff = DIFF_INSERT;
        }
        if (fl == 1) {
          // If the previous character was the same, thus doubling a
          // character, give a bonus to the score.  Also for
          // soundfold words (illogical but does give a better
          // score).
          if (sp->ts_twordlen >= 2
              && (uint8_t)tword[sp->ts_twordlen - 2] == c) {
            sp->ts_score -= SCORE_INS - SCORE_INSDUP;
          }
        }
      }
      break;

    case STATE_SWAP:
      // Swap two bytes in the bad word: "12" -> "21".
      // We change "fword" here, it's changed back afterwards at
      // STATE_UNSWAP.
      p = fword + sp->ts_fidx;
      c = (uint8_t)(*p);
      if (c == NUL) {
        // End of word, can't swap or replace.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_FINAL;
        break;
      }

      // Don't swap if the first character is not a word character.
      // SWAP3 etc. also don't make sense then.
      if (!soundfold && !spell_iswordp(p, curwin)) {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
        break;
      }

      n = utf_ptr2len(p);
      c = utf_ptr2char(p);
      if (p[n] == NUL) {
        c2 = NUL;
      } else if (!soundfold && !spell_iswordp(p + n, curwin)) {
        c2 = c;  // don't swap non-word char
      } else {
        c2 = utf_ptr2char(p + n);
      }

      // When the second character is NUL we can't swap.
      if (c2 == NUL) {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
        break;
      }

      // When characters are identical, swap won't do anything.
      // Also get here if the second char is not a word character.
      if (c == c2) {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_SWAP3;
        break;
      }
      if (TRY_DEEPER(su, stack, depth, SCORE_SWAP)) {
        go_deeper(stack, depth, SCORE_SWAP);
#ifdef DEBUG_TRIEWALK
        snprintf(changename[depth], sizeof(changename[0]),
                 "%.*s-%s: swap %c and %c",
                 sp->ts_twordlen, tword, fword + sp->ts_fidx,
                 c, c2);
#endif
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_UNSWAP;
        depth++;
        fl = utf_char2len(c2);
        memmove(p, p + n, (size_t)fl);
        utf_char2bytes(c, p + fl);
        stack[depth].ts_fidxtry = (uint8_t)(sp->ts_fidx + n + fl);
      } else {
        // If this swap doesn't work then SWAP3 won't either.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
      }
      break;

    case STATE_UNSWAP:
      // Undo the STATE_SWAP swap: "21" -> "12".
      p = fword + sp->ts_fidx;
      n = utfc_ptr2len(p);
      c = utf_ptr2char(p + n);
      memmove(p + utfc_ptr2len(p + n), p, (size_t)n);
      utf_char2bytes(c, p);

      FALLTHROUGH;

    case STATE_SWAP3:
      // Swap two bytes, skipping one: "123" -> "321".  We change
      // "fword" here, it's changed back afterwards at STATE_UNSWAP3.
      p = fword + sp->ts_fidx;
      n = utf_ptr2len(p);
      c = utf_ptr2char(p);
      fl = utf_ptr2len(p + n);
      c2 = utf_ptr2char(p + n);
      if (!soundfold && !spell_iswordp(p + n + fl, curwin)) {
        c3 = c;  // don't swap non-word char
      } else {
        c3 = utf_ptr2char(p + n + fl);
      }

      // When characters are identical: "121" then SWAP3 result is
      // identical, ROT3L result is same as SWAP: "211", ROT3L result is
      // same as SWAP on next char: "112".  Thus skip all swapping.
      // Also skip when c3 is NUL.
      // Also get here when the third character is not a word character.
      // Second character may any char: "a.b" -> "b.a"
      if (c == c3 || c3 == NUL) {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
        break;
      }
      if (TRY_DEEPER(su, stack, depth, SCORE_SWAP3)) {
        go_deeper(stack, depth, SCORE_SWAP3);
#ifdef DEBUG_TRIEWALK
        sprintf(changename[depth], "%.*s-%s: swap3 %c and %c",  // NOLINT(runtime/printf)
                sp->ts_twordlen, tword, fword + sp->ts_fidx,
                c, c3);
#endif
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_UNSWAP3;
        depth++;
        tl = utf_char2len(c3);
        memmove(p, p + n + fl, (size_t)tl);
        utf_char2bytes(c2, p + tl);
        utf_char2bytes(c, p + fl + tl);
        stack[depth].ts_fidxtry = (uint8_t)(sp->ts_fidx + n + fl + tl);
      } else {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
      }
      break;

    case STATE_UNSWAP3:
      // Undo STATE_SWAP3: "321" -> "123"
      p = fword + sp->ts_fidx;
      n = utfc_ptr2len(p);
      c2 = utf_ptr2char(p + n);
      fl = utfc_ptr2len(p + n);
      c = utf_ptr2char(p + n + fl);
      tl = utfc_ptr2len(p + n + fl);
      memmove(p + fl + tl, p, (size_t)n);
      utf_char2bytes(c, p);
      utf_char2bytes(c2, p + tl);
      p = p + tl;

      if (!soundfold && !spell_iswordp(p, curwin)) {
        // Middle char is not a word char, skip the rotate.  First and
        // third char were already checked at swap and swap3.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
        break;
      }

      // Rotate three characters left: "123" -> "231".  We change
      // "fword" here, it's changed back afterwards at STATE_UNROT3L.
      if (TRY_DEEPER(su, stack, depth, SCORE_SWAP3)) {
        go_deeper(stack, depth, SCORE_SWAP3);
#ifdef DEBUG_TRIEWALK
        p = fword + sp->ts_fidx;
        sprintf(changename[depth], "%.*s-%s: rotate left %c%c%c",  // NOLINT(runtime/printf)
                sp->ts_twordlen, tword, fword + sp->ts_fidx,
                p[0], p[1], p[2]);
#endif
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_UNROT3L;
        depth++;
        p = fword + sp->ts_fidx;
        n = utf_ptr2len(p);
        c = utf_ptr2char(p);
        fl = utf_ptr2len(p + n);
        fl += utf_ptr2len(p + n + fl);
        memmove(p, p + n, (size_t)fl);
        utf_char2bytes(c, p + fl);
        stack[depth].ts_fidxtry = (uint8_t)(sp->ts_fidx + n + fl);
      } else {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
      }
      break;

    case STATE_UNROT3L:
      // Undo ROT3L: "231" -> "123"
      p = fword + sp->ts_fidx;
      n = utfc_ptr2len(p);
      n += utfc_ptr2len(p + n);
      c = utf_ptr2char(p + n);
      tl = utfc_ptr2len(p + n);
      memmove(p + tl, p, (size_t)n);
      utf_char2bytes(c, p);

      // Rotate three bytes right: "123" -> "312".  We change "fword"
      // here, it's changed back afterwards at STATE_UNROT3R.
      if (TRY_DEEPER(su, stack, depth, SCORE_SWAP3)) {
        go_deeper(stack, depth, SCORE_SWAP3);
#ifdef DEBUG_TRIEWALK
        p = fword + sp->ts_fidx;
        sprintf(changename[depth], "%.*s-%s: rotate right %c%c%c",  // NOLINT(runtime/printf)
                sp->ts_twordlen, tword, fword + sp->ts_fidx,
                p[0], p[1], p[2]);
#endif
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_UNROT3R;
        depth++;
        p = fword + sp->ts_fidx;
        n = utf_ptr2len(p);
        n += utf_ptr2len(p + n);
        c = utf_ptr2char(p + n);
        tl = utf_ptr2len(p + n);
        memmove(p + tl, p, (size_t)n);
        utf_char2bytes(c, p);
        stack[depth].ts_fidxtry = (uint8_t)(sp->ts_fidx + n + tl);
      } else {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
      }
      break;

    case STATE_UNROT3R:
      // Undo ROT3R: "312" -> "123"
      p = fword + sp->ts_fidx;
      c = utf_ptr2char(p);
      tl = utfc_ptr2len(p);
      n = utfc_ptr2len(p + tl);
      n += utfc_ptr2len(p + tl + n);
      memmove(p, p + tl, (size_t)n);
      utf_char2bytes(c, p + n);

      FALLTHROUGH;

    case STATE_REP_INI:
      // Check if matching with REP items from the .aff file would work.
      // Quickly skip if:
      // - there are no REP items and we are not in the soundfold trie
      // - the score is going to be too high anyway
      // - already applied a REP item or swapped here
      if ((lp->lp_replang == NULL && !soundfold)
          || sp->ts_score + SCORE_REP >= su->su_maxscore
          || sp->ts_fidx < sp->ts_fidxtry) {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_FINAL;
        break;
      }

      // Use the first byte to quickly find the first entry that may
      // match.  If the index is -1 there is none.
      if (soundfold) {
        sp->ts_curi = slang->sl_repsal_first[(uint8_t)fword[sp->ts_fidx]];
      } else {
        sp->ts_curi = lp->lp_replang->sl_rep_first[(uint8_t)fword[sp->ts_fidx]];
      }

      if (sp->ts_curi < 0) {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_FINAL;
        break;
      }

      PROF_STORE(sp->ts_state)
      sp->ts_state = STATE_REP;
      FALLTHROUGH;

    case STATE_REP:
      // Try matching with REP items from the .aff file.  For each match
      // replace the characters and check if the resulting word is
      // valid.
      p = fword + sp->ts_fidx;

      if (soundfold) {
        gap = &slang->sl_repsal;
      } else {
        gap = &lp->lp_replang->sl_rep;
      }
      while (sp->ts_curi < gap->ga_len) {
        fromto_T *ftp = (fromto_T *)gap->ga_data + sp->ts_curi++;
        if (*ftp->ft_from != *p) {
          // past possible matching entries
          sp->ts_curi = (int16_t)gap->ga_len;
          break;
        }
        if (strncmp(ftp->ft_from, p, strlen(ftp->ft_from)) == 0
            && TRY_DEEPER(su, stack, depth, SCORE_REP)) {
          go_deeper(stack, depth, SCORE_REP);
#ifdef DEBUG_TRIEWALK
          sprintf(changename[depth], "%.*s-%s: replace %s with %s",  // NOLINT(runtime/printf)
                  sp->ts_twordlen, tword, fword + sp->ts_fidx,
                  ftp->ft_from, ftp->ft_to);
#endif
          // Need to undo this afterwards.
          PROF_STORE(sp->ts_state)
          sp->ts_state = STATE_REP_UNDO;

          // Change the "from" to the "to" string.
          depth++;
          fl = (int)strlen(ftp->ft_from);
          tl = (int)strlen(ftp->ft_to);
          if (fl != tl) {
            STRMOVE(p + tl, p + fl);
            repextra += tl - fl;
          }
          memmove(p, ftp->ft_to, (size_t)tl);
          stack[depth].ts_fidxtry = (uint8_t)(sp->ts_fidx + tl);
          stack[depth].ts_tcharlen = 0;
          break;
        }
      }

      if (sp->ts_curi >= gap->ga_len && sp->ts_state == STATE_REP) {
        // No (more) matches.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_FINAL;
      }

      break;

    case STATE_REP_UNDO:
      // Undo a REP replacement and continue with the next one.
      if (soundfold) {
        gap = &slang->sl_repsal;
      } else {
        gap = &lp->lp_replang->sl_rep;
      }
      fromto_T *ftp = (fromto_T *)gap->ga_data + sp->ts_curi - 1;
      fl = (int)strlen(ftp->ft_from);
      tl = (int)strlen(ftp->ft_to);
      p = fword + sp->ts_fidx;
      if (fl != tl) {
        STRMOVE(p + fl, p + tl);
        repextra -= tl - fl;
      }
      memmove(p, ftp->ft_from, (size_t)fl);
      PROF_STORE(sp->ts_state)
      sp->ts_state = STATE_REP;
      break;

    default:
      // Did all possible states at this level, go up one level.
      depth--;

      if (depth >= 0 && stack[depth].ts_prefixdepth == PFD_PREFIXTREE) {
        // Continue in or go back to the prefix tree.
        byts = pbyts;
        idxs = pidxs;
      }

      // Don't check for CTRL-C too often, it takes time.
      if (--breakcheckcount == 0) {
        os_breakcheck();
        breakcheckcount = 1000;
        if (spell_suggest_timeout > 0 && profile_passed_limit(time_limit)) {
          got_int = true;
        }
      }
    }
  }
}

/// Go one level deeper in the tree.
static void go_deeper(trystate_T *stack, int depth, int score_add)
{
  stack[depth + 1] = stack[depth];
  stack[depth + 1].ts_state = STATE_START;
  stack[depth + 1].ts_score = stack[depth].ts_score + score_add;
  stack[depth + 1].ts_curi = 1;         // start just after length byte
  stack[depth + 1].ts_flags = 0;
}

/// "fword" is a good word with case folded.  Find the matching keep-case
/// words and put it in "kword".
/// Theoretically there could be several keep-case words that result in the
/// same case-folded word, but we only find one...
static void find_keepcap_word(slang_T *slang, char *fword, char *kword)
{
  char uword[MAXWLEN];                // "fword" in upper-case
  idx_T tryidx;

  // The following arrays are used at each depth in the tree.
  idx_T arridx[MAXWLEN];
  int round[MAXWLEN];
  int fwordidx[MAXWLEN];
  int uwordidx[MAXWLEN];
  int kwordlen[MAXWLEN];

  int l;
  char *p;
  uint8_t *byts = slang->sl_kbyts;      // array with bytes of the words
  idx_T *idxs = slang->sl_kidxs;      // array with indexes

  if (byts == NULL) {
    // array is empty: "cannot happen"
    *kword = NUL;
    return;
  }

  // Make an all-cap version of "fword".
  allcap_copy(fword, uword);

  // Each character needs to be tried both case-folded and upper-case.
  // All this gets very complicated if we keep in mind that changing case
  // may change the byte length of a multi-byte character...
  int depth = 0;
  arridx[0] = 0;
  round[0] = 0;
  fwordidx[0] = 0;
  uwordidx[0] = 0;
  kwordlen[0] = 0;
  while (depth >= 0) {
    if (fword[fwordidx[depth]] == NUL) {
      // We are at the end of "fword".  If the tree allows a word to end
      // here we have found a match.
      if (byts[arridx[depth] + 1] == 0) {
        kword[kwordlen[depth]] = NUL;
        return;
      }

      // kword is getting too long, continue one level up
      depth--;
    } else if (++round[depth] > 2) {
      // tried both fold-case and upper-case character, continue one
      // level up
      depth--;
    } else {
      // round[depth] == 1: Try using the folded-case character.
      // round[depth] == 2: Try using the upper-case character.
      int flen = utf_ptr2len(fword + fwordidx[depth]);
      int ulen = utf_ptr2len(uword + uwordidx[depth]);
      if (round[depth] == 1) {
        p = fword + fwordidx[depth];
        l = flen;
      } else {
        p = uword + uwordidx[depth];
        l = ulen;
      }

      for (tryidx = arridx[depth]; l > 0; l--) {
        // Perform a binary search in the list of accepted bytes.
        int len = byts[tryidx++];
        int c = (uint8_t)(*p++);
        idx_T lo = tryidx;
        idx_T hi = tryidx + len - 1;
        while (lo < hi) {
          idx_T m = (lo + hi) / 2;
          if (byts[m] > c) {
            hi = m - 1;
          } else if (byts[m] < c) {
            lo = m + 1;
          } else {
            lo = hi = m;
            break;
          }
        }

        // Stop if there is no matching byte.
        if (hi < lo || byts[lo] != c) {
          break;
        }

        // Continue at the child (if there is one).
        tryidx = idxs[lo];
      }

      if (l == 0) {
        // Found the matching char.  Copy it to "kword" and go a
        // level deeper.
        if (round[depth] == 1) {
          strncpy(kword + kwordlen[depth],  // NOLINT(runtime/printf)
                  fword + fwordidx[depth],
                  (size_t)flen);
          kwordlen[depth + 1] = kwordlen[depth] + flen;
        } else {
          strncpy(kword + kwordlen[depth],  // NOLINT(runtime/printf)
                  uword + uwordidx[depth],
                  (size_t)ulen);
          kwordlen[depth + 1] = kwordlen[depth] + ulen;
        }
        fwordidx[depth + 1] = fwordidx[depth] + flen;
        uwordidx[depth + 1] = uwordidx[depth] + ulen;

        depth++;
        arridx[depth] = tryidx;
        round[depth] = 0;
      }
    }
  }

  // Didn't find it: "cannot happen".
  *kword = NUL;
}

/// Compute the sound-a-like score for suggestions in su->su_ga and add them to
/// su->su_sga.
static void score_comp_sal(suginfo_T *su)
{
  char badsound[MAXWLEN];

  ga_grow(&su->su_sga, su->su_ga.ga_len);

  // Use the sound-folding of the first language that supports it.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    langp_T *lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    if (!GA_EMPTY(&lp->lp_slang->sl_sal)) {
      // soundfold the bad word
      spell_soundfold(lp->lp_slang, su->su_fbadword, true, badsound);

      for (int i = 0; i < su->su_ga.ga_len; i++) {
        suggest_T *stp = &SUG(su->su_ga, i);

        // Case-fold the suggested word, sound-fold it and compute the
        // sound-a-like score.
        int score = stp_sal_score(stp, su, lp->lp_slang, badsound);
        if (score < SCORE_MAXMAX) {
          // Add the suggestion.
          suggest_T *sstp = &SUG(su->su_sga, su->su_sga.ga_len);
          sstp->st_word = xstrdup(stp->st_word);
          sstp->st_wordlen = stp->st_wordlen;
          sstp->st_score = score;
          sstp->st_altscore = 0;
          sstp->st_orglen = stp->st_orglen;
          su->su_sga.ga_len++;
        }
      }
      break;
    }
  }
}

/// Combine the list of suggestions in su->su_ga and su->su_sga.
/// They are entwined.
static void score_combine(suginfo_T *su)
{
  garray_T ga;
  char *p;
  char badsound[MAXWLEN];
  slang_T *slang = NULL;

  // Add the alternate score to su_ga.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    langp_T *lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    if (!GA_EMPTY(&lp->lp_slang->sl_sal)) {
      // soundfold the bad word
      slang = lp->lp_slang;
      spell_soundfold(slang, su->su_fbadword, true, badsound);

      for (int i = 0; i < su->su_ga.ga_len; i++) {
        suggest_T *stp = &SUG(su->su_ga, i);
        stp->st_altscore = stp_sal_score(stp, su, slang, badsound);
        if (stp->st_altscore == SCORE_MAXMAX) {
          stp->st_score = (stp->st_score * 3 + SCORE_BIG) / 4;
        } else {
          stp->st_score = (stp->st_score * 3 + stp->st_altscore) / 4;
        }
        stp->st_salscore = false;
      }
      break;
    }
  }

  if (slang == NULL) {  // Using "double" without sound folding.
    cleanup_suggestions(&su->su_ga, su->su_maxscore,
                        su->su_maxcount);
    return;
  }

  // Add the alternate score to su_sga.
  for (int i = 0; i < su->su_sga.ga_len; i++) {
    suggest_T *stp = &SUG(su->su_sga, i);
    stp->st_altscore = spell_edit_score(slang, su->su_badword, stp->st_word);
    if (stp->st_score == SCORE_MAXMAX) {
      stp->st_score = (SCORE_BIG * 7 + stp->st_altscore) / 8;
    } else {
      stp->st_score = (stp->st_score * 7 + stp->st_altscore) / 8;
    }
    stp->st_salscore = true;
  }

  // Remove bad suggestions, sort the suggestions and truncate at "maxcount"
  // for both lists.
  check_suggestions(su, &su->su_ga);
  cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
  check_suggestions(su, &su->su_sga);
  cleanup_suggestions(&su->su_sga, su->su_maxscore, su->su_maxcount);

  ga_init(&ga, (int)sizeof(suginfo_T), 1);
  ga_grow(&ga, su->su_ga.ga_len + su->su_sga.ga_len);

  suggest_T *stp = &SUG(ga, 0);
  for (int i = 0; i < su->su_ga.ga_len || i < su->su_sga.ga_len; i++) {
    // round 1: get a suggestion from su_ga
    // round 2: get a suggestion from su_sga
    for (int round = 1; round <= 2; round++) {
      garray_T *gap = round == 1 ? &su->su_ga : &su->su_sga;
      if (i < gap->ga_len) {
        // Don't add a word if it's already there.
        p = SUG(*gap, i).st_word;
        int j;
        for (j = 0; j < ga.ga_len; j++) {
          if (strcmp(stp[j].st_word, p) == 0) {
            break;
          }
        }
        if (j == ga.ga_len) {
          stp[ga.ga_len++] = SUG(*gap, i);
        } else {
          xfree(p);
        }
      }
    }
  }

  ga_clear(&su->su_ga);
  ga_clear(&su->su_sga);

  // Truncate the list to the number of suggestions that will be displayed.
  if (ga.ga_len > su->su_maxcount) {
    for (int i = su->su_maxcount; i < ga.ga_len; i++) {
      xfree(stp[i].st_word);
    }
    ga.ga_len = su->su_maxcount;
  }

  su->su_ga = ga;
}

/// For the goodword in "stp" compute the soundalike score compared to the
/// badword.
///
/// @param badsound  sound-folded badword
static int stp_sal_score(suggest_T *stp, suginfo_T *su, slang_T *slang, char *badsound)
{
  char *pbad;
  char *pgood;
  char badsound2[MAXWLEN];
  char fword[MAXWLEN];
  char goodsound[MAXWLEN];
  char goodword[MAXWLEN];

  int lendiff = su->su_badlen - stp->st_orglen;
  if (lendiff >= 0) {
    pbad = badsound;
  } else {
    // soundfold the bad word with more characters following
    spell_casefold(curwin, su->su_badptr, stp->st_orglen, fword, MAXWLEN);

    // When joining two words the sound often changes a lot.  E.g., "t he"
    // sounds like "t h" while "the" sounds like "@".  Avoid that by
    // removing the space.  Don't do it when the good word also contains a
    // space.
    if (ascii_iswhite(su->su_badptr[su->su_badlen])
        && *skiptowhite(stp->st_word) == NUL) {
      for (char *p = fword; *(p = skiptowhite(p)) != NUL;) {
        STRMOVE(p, p + 1);
      }
    }

    spell_soundfold(slang, fword, true, badsound2);
    pbad = badsound2;
  }

  if (lendiff > 0 && stp->st_wordlen + lendiff < MAXWLEN) {
    // Add part of the bad word to the good word, so that we soundfold
    // what replaces the bad word.
    STRCPY(goodword, stp->st_word);
    xmemcpyz(goodword + stp->st_wordlen,
             su->su_badptr + su->su_badlen - lendiff, (size_t)lendiff);
    pgood = goodword;
  } else {
    pgood = stp->st_word;
  }

  // Sound-fold the word and compute the score for the difference.
  spell_soundfold(slang, pgood, false, goodsound);

  return soundalike_score(goodsound, pbad);
}

/// structure used to store soundfolded words that add_sound_suggest() has
/// handled already.
typedef struct {
  int16_t sft_score;   ///< lowest score used
  uint8_t sft_word[];   ///< soundfolded word
} sftword_T;

static sftword_T dumsft;
#define HIKEY2SFT(p)  ((sftword_T *)((p) - (dumsft.sft_word - (uint8_t *)&dumsft)))
#define HI2SFT(hi)     HIKEY2SFT((hi)->hi_key)

/// Prepare for calling suggest_try_soundalike().
static void suggest_try_soundalike_prep(void)
{
  // Do this for all languages that support sound folding and for which a
  // .sug file has been loaded.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    langp_T *lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang_T *slang = lp->lp_slang;
    if (!GA_EMPTY(&slang->sl_sal) && slang->sl_sbyts != NULL) {
      // prepare the hashtable used by add_sound_suggest()
      hash_init(&slang->sl_sounddone);
    }
  }
}

/// Find suggestions by comparing the word in a sound-a-like form.
/// Note: This doesn't support postponed prefixes.
static void suggest_try_soundalike(suginfo_T *su)
{
  char salword[MAXWLEN];

  // Do this for all languages that support sound folding and for which a
  // .sug file has been loaded.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    langp_T *lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang_T *slang = lp->lp_slang;
    if (!GA_EMPTY(&slang->sl_sal) && slang->sl_sbyts != NULL) {
      // soundfold the bad word
      spell_soundfold(slang, su->su_fbadword, true, salword);

      // try all kinds of inserts/deletes/swaps/etc.
      // TODO(vim): also soundfold the next words, so that we can try joining
      // and splitting
#ifdef SUGGEST_PROFILE
      prof_init();
#endif
      suggest_trie_walk(su, lp, salword, true);
#ifdef SUGGEST_PROFILE
      prof_report("soundalike");
#endif
    }
  }
}

/// Finish up after calling suggest_try_soundalike().
static void suggest_try_soundalike_finish(void)
{
  // Do this for all languages that support sound folding and for which a
  // .sug file has been loaded.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    langp_T *lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang_T *slang = lp->lp_slang;
    if (!GA_EMPTY(&slang->sl_sal) && slang->sl_sbyts != NULL) {
      // Free the info about handled words.
      int todo = (int)slang->sl_sounddone.ht_used;
      for (hashitem_T *hi = slang->sl_sounddone.ht_array; todo > 0; hi++) {
        if (!HASHITEM_EMPTY(hi)) {
          xfree(HI2SFT(hi));
          todo--;
        }
      }

      // Clear the hashtable, it may also be used by another region.
      hash_clear(&slang->sl_sounddone);
      hash_init(&slang->sl_sounddone);
    }
  }
}

/// A match with a soundfolded word is found.  Add the good word(s) that
/// produce this soundfolded word.
///
/// @param score  soundfold score
static void add_sound_suggest(suginfo_T *su, char *goodword, int score, langp_T *lp)
{
  slang_T *slang = lp->lp_slang;    // language for sound folding
  char theword[MAXWLEN];
  int i;
  int wlen;
  uint8_t *byts;
  int wc;
  int goodscore;
  sftword_T *sft;

  // It's very well possible that the same soundfold word is found several
  // times with different scores.  Since the following is quite slow only do
  // the words that have a better score than before.  Use a hashtable to
  // remember the words that have been done.
  hash_T hash = hash_hash(goodword);
  const size_t goodword_len = strlen(goodword);
  hashitem_T *hi = hash_lookup(&slang->sl_sounddone, goodword, goodword_len, hash);
  if (HASHITEM_EMPTY(hi)) {
    sft = xmalloc(offsetof(sftword_T, sft_word) + goodword_len + 1);
    sft->sft_score = (int16_t)score;
    memcpy(sft->sft_word, goodword, goodword_len + 1);
    hash_add_item(&slang->sl_sounddone, hi, (char *)sft->sft_word, hash);
  } else {
    sft = HI2SFT(hi);
    if (score >= sft->sft_score) {
      return;
    }
    sft->sft_score = (int16_t)score;
  }

  // Find the word nr in the soundfold tree.
  int sfwordnr = soundfold_find(slang, goodword);
  if (sfwordnr < 0) {
    internal_error("add_sound_suggest()");
    return;
  }

  // Go over the list of good words that produce this soundfold word
  char *nrline = ml_get_buf(slang->sl_sugbuf, (linenr_T)sfwordnr + 1);
  int orgnr = 0;
  while (*nrline != NUL) {
    // The wordnr was stored in a minimal nr of bytes as an offset to the
    // previous wordnr.
    orgnr += bytes2offset(&nrline);

    byts = slang->sl_fbyts;
    idx_T *idxs = slang->sl_fidxs;

    // Lookup the word "orgnr" one of the two tries.
    int n = 0;
    int wordcount = 0;
    for (wlen = 0; wlen < MAXWLEN - 3; wlen++) {
      i = 1;
      if (wordcount == orgnr && byts[n + 1] == NUL) {
        break;          // found end of word
      }
      if (byts[n + 1] == NUL) {
        wordcount++;
      }

      // skip over the NUL bytes
      for (; byts[n + i] == NUL; i++) {
        if (i > byts[n]) {              // safety check
          STRCPY(theword + wlen, "BAD");
          wlen += 3;
          goto badword;
        }
      }

      // One of the siblings must have the word.
      for (; i < byts[n]; i++) {
        wc = idxs[idxs[n + i]];         // nr of words under this byte
        if (wordcount + wc > orgnr) {
          break;
        }
        wordcount += wc;
      }

      theword[wlen] = (char)byts[n + i];
      n = idxs[n + i];
    }
badword:
    theword[wlen] = NUL;

    // Go over the possible flags and regions.
    for (; i <= byts[n] && byts[n + i] == NUL; i++) {
      char cword[MAXWLEN];
      char *p;
      int flags = (int)idxs[n + i];

      // Skip words with the NOSUGGEST flag
      if (flags & WF_NOSUGGEST) {
        continue;
      }

      if (flags & WF_KEEPCAP) {
        // Must find the word in the keep-case tree.
        find_keepcap_word(slang, theword, cword);
        p = cword;
      } else {
        flags |= su->su_badflags;
        if ((flags & WF_CAPMASK) != 0) {
          // Need to fix case according to "flags".
          make_case_word(theword, cword, flags);
          p = cword;
        } else {
          p = theword;
        }
      }

      // Add the suggestion.
      if (sps_flags & SPS_DOUBLE) {
        // Add the suggestion if the score isn't too bad.
        if (score <= su->su_maxscore) {
          add_suggestion(su, &su->su_sga, p, su->su_badlen,
                         score, 0, false, slang, false);
        }
      } else {
        // Add a penalty for words in another region.
        if ((flags & WF_REGION)
            && (((unsigned)flags >> 16) & (unsigned)lp->lp_region) == 0) {
          goodscore = SCORE_REGION;
        } else {
          goodscore = 0;
        }

        // Add a small penalty for changing the first letter from
        // lower to upper case.  Helps for "tath" -> "Kath", which is
        // less common than "tath" -> "path".  Don't do it when the
        // letter is the same, that has already been counted.
        int gc = utf_ptr2char(p);
        if (SPELL_ISUPPER(gc)) {
          int bc = utf_ptr2char(su->su_badword);
          if (!SPELL_ISUPPER(bc)
              && SPELL_TOFOLD(bc) != SPELL_TOFOLD(gc)) {
            goodscore += SCORE_ICASE / 2;
          }
        }

        // Compute the score for the good word.  This only does letter
        // insert/delete/swap/replace.  REP items are not considered,
        // which may make the score a bit higher.
        // Use a limit for the score to make it work faster.  Use
        // MAXSCORE(), because RESCORE() will change the score.
        // If the limit is very high then the iterative method is
        // inefficient, using an array is quicker.
        int limit = MAXSCORE(su->su_sfmaxscore - goodscore, score);
        if (limit > SCORE_LIMITMAX) {
          goodscore += spell_edit_score(slang, su->su_badword, p);
        } else {
          goodscore += spell_edit_score_limit(slang, su->su_badword, p, limit);
        }

        // When going over the limit don't bother to do the rest.
        if (goodscore < SCORE_MAXMAX) {
          // Give a bonus to words seen before.
          goodscore = score_wordcount_adj(slang, goodscore, p, false);

          // Add the suggestion if the score isn't too bad.
          goodscore = RESCORE(goodscore, score);
          if (goodscore <= su->su_sfmaxscore) {
            add_suggestion(su, &su->su_ga, p, su->su_badlen,
                           goodscore, score, true, slang, true);
          }
        }
      }
    }
  }
}

/// Find word "word" in fold-case tree for "slang" and return the word number.
static int soundfold_find(slang_T *slang, char *word)
{
  idx_T arridx = 0;
  int wlen = 0;
  uint8_t *ptr = (uint8_t *)word;
  int wordnr = 0;

  uint8_t *byts = slang->sl_sbyts;
  idx_T *idxs = slang->sl_sidxs;

  while (true) {
    // First byte is the number of possible bytes.
    int len = byts[arridx++];

    // If the first possible byte is a zero the word could end here.
    // If the word ends we found the word.  If not skip the NUL bytes.
    int c = ptr[wlen];
    if (byts[arridx] == NUL) {
      if (c == NUL) {
        break;
      }

      // Skip over the zeros, there can be several.
      while (len > 0 && byts[arridx] == NUL) {
        arridx++;
        len--;
      }
      if (len == 0) {
        return -1;            // no children, word should have ended here
      }
      wordnr++;
    }

    // If the word ends we didn't find it.
    if (c == NUL) {
      return -1;
    }

    // Perform a binary search in the list of accepted bytes.
    if (c == TAB) {         // <Tab> is handled like <Space>
      c = ' ';
    }
    while (byts[arridx] < c) {
      // The word count is in the first idxs[] entry of the child.
      wordnr += idxs[idxs[arridx]];
      arridx++;
      if (--len == 0) {         // end of the bytes, didn't find it
        return -1;
      }
    }
    if (byts[arridx] != c) {    // didn't find the byte
      return -1;
    }

    // Continue at the child (if there is one).
    arridx = idxs[arridx];
    wlen++;

    // One space in the good word may stand for several spaces in the
    // checked word.
    if (c == ' ') {
      while (ptr[wlen] == ' ' || ptr[wlen] == TAB) {
        wlen++;
      }
    }
  }

  return wordnr;
}

/// Returns true if "c1" and "c2" are similar characters according to the MAP
/// lines in the .aff file.
static bool similar_chars(slang_T *slang, int c1, int c2)
{
  int m1, m2;
  char buf[MB_MAXCHAR + 1];

  if (c1 >= 256) {
    buf[utf_char2bytes(c1, buf)] = 0;
    hashitem_T *hi = hash_find(&slang->sl_map_hash, buf);
    if (HASHITEM_EMPTY(hi)) {
      m1 = 0;
    } else {
      m1 = utf_ptr2char(hi->hi_key + strlen(hi->hi_key) + 1);
    }
  } else {
    m1 = slang->sl_map_array[c1];
  }
  if (m1 == 0) {
    return false;
  }

  if (c2 >= 256) {
    buf[utf_char2bytes(c2, buf)] = 0;
    hashitem_T *hi = hash_find(&slang->sl_map_hash, buf);
    if (HASHITEM_EMPTY(hi)) {
      m2 = 0;
    } else {
      m2 = utf_ptr2char(hi->hi_key + strlen(hi->hi_key) + 1);
    }
  } else {
    m2 = slang->sl_map_array[c2];
  }

  return m1 == m2;
}

/// Adds a suggestion to the list of suggestions.
/// For a suggestion that is already in the list the lowest score is remembered.
///
/// @param gap  either su_ga or su_sga
/// @param badlenarg  len of bad word replaced with "goodword"
/// @param had_bonus  value for st_had_bonus
/// @param slang  language for sound folding
/// @param maxsf  su_maxscore applies to soundfold score, su_sfmaxscore to the total score.
static void add_suggestion(suginfo_T *su, garray_T *gap, const char *goodword, int badlenarg,
                           int score, int altscore, bool had_bonus, slang_T *slang, bool maxsf)
{
  int goodlen;                  // len of goodword changed
  int badlen;                   // len of bad word changed
  suggest_T new_sug;

  // Minimize "badlen" for consistency.  Avoids that changing "the the" to
  // "thee the" is added next to changing the first "the" the "thee".
  const char *pgood = goodword + strlen(goodword);
  char *pbad = su->su_badptr + badlenarg;
  while (true) {
    goodlen = (int)(pgood - goodword);
    badlen = (int)(pbad - su->su_badptr);
    if (goodlen <= 0 || badlen <= 0) {
      break;
    }
    MB_PTR_BACK(goodword, pgood);
    MB_PTR_BACK(su->su_badptr, pbad);
    if (utf_ptr2char(pgood) != utf_ptr2char(pbad)) {
      break;
    }
  }

  if (badlen == 0 && goodlen == 0) {
    // goodword doesn't change anything; may happen for "the the" changing
    // the first "the" to itself.
    return;
  }

  int i;
  if (GA_EMPTY(gap)) {
    i = -1;
  } else {
    // Check if the word is already there.  Also check the length that is
    // being replaced "thes," -> "these" is a different suggestion from
    // "thes" -> "these".
    suggest_T *stp = &SUG(*gap, 0);
    for (i = gap->ga_len; --i >= 0; stp++) {
      if (stp->st_wordlen == goodlen
          && stp->st_orglen == badlen
          && strncmp(stp->st_word, goodword, (size_t)goodlen) == 0) {
        // Found it.  Remember the word with the lowest score.
        if (stp->st_slang == NULL) {
          stp->st_slang = slang;
        }

        new_sug.st_score = score;
        new_sug.st_altscore = altscore;
        new_sug.st_had_bonus = had_bonus;

        if (stp->st_had_bonus != had_bonus) {
          // Only one of the two had the soundalike score computed.
          // Need to do that for the other one now, otherwise the
          // scores can't be compared.  This happens because
          // suggest_try_change() doesn't compute the soundalike
          // word to keep it fast, while some special methods set
          // the soundalike score to zero.
          if (had_bonus) {
            rescore_one(su, stp);
          } else {
            new_sug.st_word = stp->st_word;
            new_sug.st_wordlen = stp->st_wordlen;
            new_sug.st_slang = stp->st_slang;
            new_sug.st_orglen = badlen;
            rescore_one(su, &new_sug);
          }
        }

        if (stp->st_score > new_sug.st_score) {
          stp->st_score = new_sug.st_score;
          stp->st_altscore = new_sug.st_altscore;
          stp->st_had_bonus = new_sug.st_had_bonus;
        }
        break;
      }
    }
  }

  if (i < 0) {
    // Add a suggestion.
    suggest_T *stp = GA_APPEND_VIA_PTR(suggest_T, gap);
    stp->st_word = xmemdupz(goodword, (size_t)goodlen);
    stp->st_wordlen = goodlen;
    stp->st_score = score;
    stp->st_altscore = altscore;
    stp->st_had_bonus = had_bonus;
    stp->st_orglen = badlen;
    stp->st_slang = slang;

    // If we have too many suggestions now, sort the list and keep
    // the best suggestions.
    if (gap->ga_len > SUG_MAX_COUNT(su)) {
      if (maxsf) {
        su->su_sfmaxscore = cleanup_suggestions(gap,
                                                su->su_sfmaxscore, SUG_CLEAN_COUNT(su));
      } else {
        su->su_maxscore = cleanup_suggestions(gap,
                                              su->su_maxscore, SUG_CLEAN_COUNT(su));
      }
    }
  }
}

/// Suggestions may in fact be flagged as errors.  Esp. for banned words and
/// for split words, such as "the the".  Remove these from the list here.
///
/// @param gap  either su_ga or su_sga
static void check_suggestions(suginfo_T *su, garray_T *gap)
{
  char longword[MAXWLEN + 1];

  if (gap->ga_len == 0) {
    return;
  }
  suggest_T *stp = &SUG(*gap, 0);
  for (int i = gap->ga_len - 1; i >= 0; i--) {
    // Need to append what follows to check for "the the".
    xstrlcpy(longword, stp[i].st_word, MAXWLEN + 1);
    int len = stp[i].st_wordlen;
    xstrlcpy(longword + len, su->su_badptr + stp[i].st_orglen, MAXWLEN + 1 - (size_t)len);
    hlf_T attr = HLF_COUNT;
    spell_check(curwin, longword, &attr, NULL, false);
    if (attr != HLF_COUNT) {
      // Remove this entry.
      xfree(stp[i].st_word);
      gap->ga_len--;
      if (i < gap->ga_len) {
        memmove(stp + i, stp + i + 1, sizeof(suggest_T) * (size_t)(gap->ga_len - i));
      }
    }
  }
}

/// Add a word to be banned.
static void add_banned(suginfo_T *su, char *word)
{
  hash_T hash = hash_hash(word);
  const size_t word_len = strlen(word);
  hashitem_T *hi = hash_lookup(&su->su_banned, word, word_len, hash);
  if (!HASHITEM_EMPTY(hi)) {  // already present
    return;
  }
  char *s = xmemdupz(word, word_len);
  hash_add_item(&su->su_banned, hi, s, hash);
}

/// Recompute the score for all suggestions if sound-folding is possible.  This
/// is slow, thus only done for the final results.
static void rescore_suggestions(suginfo_T *su)
{
  if (su->su_sallang != NULL) {
    for (int i = 0; i < su->su_ga.ga_len; i++) {
      rescore_one(su, &SUG(su->su_ga, i));
    }
  }
}

/// Recompute the score for one suggestion if sound-folding is possible.
static void rescore_one(suginfo_T *su, suggest_T *stp)
{
  slang_T *slang = stp->st_slang;
  char sal_badword[MAXWLEN];

  // Only rescore suggestions that have no sal score yet and do have a
  // language.
  if (slang != NULL && !GA_EMPTY(&slang->sl_sal) && !stp->st_had_bonus) {
    char *p;
    if (slang == su->su_sallang) {
      p = su->su_sal_badword;
    } else {
      spell_soundfold(slang, su->su_fbadword, true, sal_badword);
      p = sal_badword;
    }

    stp->st_altscore = stp_sal_score(stp, su, slang, p);
    if (stp->st_altscore == SCORE_MAXMAX) {
      stp->st_altscore = SCORE_BIG;
    }
    stp->st_score = RESCORE(stp->st_score, stp->st_altscore);
    stp->st_had_bonus = true;
  }
}

/// Function given to qsort() to sort the suggestions on st_score.
/// First on "st_score", then "st_altscore" then alphabetically.
static int sug_compare(const void *s1, const void *s2)
{
  suggest_T *p1 = (suggest_T *)s1;
  suggest_T *p2 = (suggest_T *)s2;
  int n = p1->st_score == p2->st_score ? 0 : p1->st_score > p2->st_score ? 1 : -1;

  if (n == 0) {
    n = p1->st_altscore == p2->st_altscore ? 0 : p1->st_altscore > p2->st_altscore ? 1 : -1;
    if (n == 0) {
      n = STRICMP(p1->st_word, p2->st_word);
    }
  }
  return n;
}

/// Cleanup the suggestions:
/// - Sort on score.
/// - Remove words that won't be displayed.
///
/// @param keep  nr of suggestions to keep
///
/// @return  the maximum score in the list or "maxscore" unmodified.
static int cleanup_suggestions(garray_T *gap, int maxscore, int keep)
  FUNC_ATTR_NONNULL_ALL
{
  if (gap->ga_len <= 0) {
    return maxscore;
  }

  // Sort the list.
  qsort(gap->ga_data, (size_t)gap->ga_len, sizeof(suggest_T), sug_compare);

  // Truncate the list to the number of suggestions that will be displayed.
  if (gap->ga_len > keep) {
    suggest_T *const stp = &SUG(*gap, 0);

    for (int i = keep; i < gap->ga_len; i++) {
      xfree(stp[i].st_word);
    }
    gap->ga_len = keep;
    if (keep >= 1) {
      return stp[keep - 1].st_score;
    }
  }
  return maxscore;
}

/// Compute a score for two sound-a-like words.
/// This permits up to two inserts/deletes/swaps/etc. to keep things fast.
/// Instead of a generic loop we write out the code.  That keeps it fast by
/// avoiding checks that will not be possible.
///
/// @param goodstart  sound-folded good word
/// @param badstart  sound-folded bad word
static int soundalike_score(char *goodstart, char *badstart)
{
  char *goodsound = goodstart;
  char *badsound = badstart;
  char *pl, *ps;
  char *pl2, *ps2;
  int score = 0;

  // Adding/inserting "*" at the start (word starts with vowel) shouldn't be
  // counted so much, vowels in the middle of the word aren't counted at all.
  if ((*badsound == '*' || *goodsound == '*') && *badsound != *goodsound) {
    if ((badsound[0] == NUL && goodsound[1] == NUL)
        || (goodsound[0] == NUL && badsound[1] == NUL)) {
      // changing word with vowel to word without a sound
      return SCORE_DEL;
    }
    if (badsound[0] == NUL || goodsound[0] == NUL) {
      // more than two changes
      return SCORE_MAXMAX;
    }

    if (badsound[1] == goodsound[1]
        || (badsound[1] != NUL
            && goodsound[1] != NUL
            && badsound[2] == goodsound[2])) {
      // handle like a substitute
    } else {
      score = 2 * SCORE_DEL / 3;
      if (*badsound == '*') {
        badsound++;
      } else {
        goodsound++;
      }
    }
  }

  int goodlen = (int)strlen(goodsound);
  int badlen = (int)strlen(badsound);

  // Return quickly if the lengths are too different to be fixed by two
  // changes.
  int n = goodlen - badlen;
  if (n < -2 || n > 2) {
    return SCORE_MAXMAX;
  }

  if (n > 0) {
    pl = goodsound;         // goodsound is longest
    ps = badsound;
  } else {
    pl = badsound;          // badsound is longest
    ps = goodsound;
  }

  // Skip over the identical part.
  while (*pl == *ps && *pl != NUL) {
    pl++;
    ps++;
  }

  switch (n) {
  case -2:
  case 2:
    // Must delete two characters from "pl".
    pl++;               // first delete
    while (*pl == *ps) {
      pl++;
      ps++;
    }
    // strings must be equal after second delete
    if (strcmp(pl + 1, ps) == 0) {
      return score + SCORE_DEL * 2;
    }

    // Failed to compare.
    break;

  case -1:
  case 1:
    // Minimal one delete from "pl" required.

    // 1: delete
    pl2 = pl + 1;
    ps2 = ps;
    while (*pl2 == *ps2) {
      if (*pl2 == NUL) {                // reached the end
        return score + SCORE_DEL;
      }
      pl2++;
      ps2++;
    }

    // 2: delete then swap, then rest must be equal
    if (pl2[0] == ps2[1] && pl2[1] == ps2[0]
        && strcmp(pl2 + 2, ps2 + 2) == 0) {
      return score + SCORE_DEL + SCORE_SWAP;
    }

    // 3: delete then substitute, then the rest must be equal
    if (strcmp(pl2 + 1, ps2 + 1) == 0) {
      return score + SCORE_DEL + SCORE_SUBST;
    }

    // 4: first swap then delete
    if (pl[0] == ps[1] && pl[1] == ps[0]) {
      pl2 = pl + 2;                 // swap, skip two chars
      ps2 = ps + 2;
      while (*pl2 == *ps2) {
        pl2++;
        ps2++;
      }
      // delete a char and then strings must be equal
      if (strcmp(pl2 + 1, ps2) == 0) {
        return score + SCORE_SWAP + SCORE_DEL;
      }
    }

    // 5: first substitute then delete
    pl2 = pl + 1;                   // substitute, skip one char
    ps2 = ps + 1;
    while (*pl2 == *ps2) {
      pl2++;
      ps2++;
    }
    // delete a char and then strings must be equal
    if (strcmp(pl2 + 1, ps2) == 0) {
      return score + SCORE_SUBST + SCORE_DEL;
    }

    // Failed to compare.
    break;

  case 0:
    // Lengths are equal, thus changes must result in same length: An
    // insert is only possible in combination with a delete.
    // 1: check if for identical strings
    if (*pl == NUL) {
      return score;
    }

    // 2: swap
    if (pl[0] == ps[1] && pl[1] == ps[0]) {
      pl2 = pl + 2;                 // swap, skip two chars
      ps2 = ps + 2;
      while (*pl2 == *ps2) {
        if (*pl2 == NUL) {              // reached the end
          return score + SCORE_SWAP;
        }
        pl2++;
        ps2++;
      }
      // 3: swap and swap again
      if (pl2[0] == ps2[1] && pl2[1] == ps2[0]
          && strcmp(pl2 + 2, ps2 + 2) == 0) {
        return score + SCORE_SWAP + SCORE_SWAP;
      }

      // 4: swap and substitute
      if (strcmp(pl2 + 1, ps2 + 1) == 0) {
        return score + SCORE_SWAP + SCORE_SUBST;
      }
    }

    // 5: substitute
    pl2 = pl + 1;
    ps2 = ps + 1;
    while (*pl2 == *ps2) {
      if (*pl2 == NUL) {                // reached the end
        return score + SCORE_SUBST;
      }
      pl2++;
      ps2++;
    }

    // 6: substitute and swap
    if (pl2[0] == ps2[1] && pl2[1] == ps2[0]
        && strcmp(pl2 + 2, ps2 + 2) == 0) {
      return score + SCORE_SUBST + SCORE_SWAP;
    }

    // 7: substitute and substitute
    if (strcmp(pl2 + 1, ps2 + 1) == 0) {
      return score + SCORE_SUBST + SCORE_SUBST;
    }

    // 8: insert then delete
    pl2 = pl;
    ps2 = ps + 1;
    while (*pl2 == *ps2) {
      pl2++;
      ps2++;
    }
    if (strcmp(pl2 + 1, ps2) == 0) {
      return score + SCORE_INS + SCORE_DEL;
    }

    // 9: delete then insert
    pl2 = pl + 1;
    ps2 = ps;
    while (*pl2 == *ps2) {
      pl2++;
      ps2++;
    }
    if (strcmp(pl2, ps2 + 1) == 0) {
      return score + SCORE_INS + SCORE_DEL;
    }

    // Failed to compare.
    break;
  }

  return SCORE_MAXMAX;
}

/// Compute the "edit distance" to turn "badword" into "goodword".  The less
/// deletes/inserts/substitutes/swaps are required the lower the score.
///
/// The algorithm is described by Du and Chang, 1992.
/// The implementation of the algorithm comes from Aspell editdist.cpp,
/// edit_distance().  It has been converted from C++ to C and modified to
/// support multi-byte characters.
static int spell_edit_score(slang_T *slang, const char *badword, const char *goodword)
{
  int wbadword[MAXWLEN];
  int wgoodword[MAXWLEN];

  // Lengths with NUL.
  int badlen;
  int goodlen;
  {
    // Get the characters from the multi-byte strings and put them in an
    // int array for easy access.
    badlen = 0;
    for (const char *p = badword; *p != NUL;) {
      wbadword[badlen++] = mb_cptr2char_adv(&p);
    }
    wbadword[badlen++] = 0;
    goodlen = 0;
    for (const char *p = goodword; *p != NUL;) {
      wgoodword[goodlen++] = mb_cptr2char_adv(&p);
    }
    wgoodword[goodlen++] = 0;
  }

  // We use "cnt" as an array: CNT(badword_idx, goodword_idx).
#define CNT(a, b)   cnt[(a) + (b) * (badlen + 1)]
  int *cnt = xmalloc(sizeof(int) * ((size_t)badlen + 1) * ((size_t)goodlen + 1));

  CNT(0, 0) = 0;
  for (int j = 1; j <= goodlen; j++) {
    CNT(0, j) = CNT(0, j - 1) + SCORE_INS;
  }

  for (int i = 1; i <= badlen; i++) {
    CNT(i, 0) = CNT(i - 1, 0) + SCORE_DEL;
    for (int j = 1; j <= goodlen; j++) {
      int bc = wbadword[i - 1];
      int gc = wgoodword[j - 1];
      if (bc == gc) {
        CNT(i, j) = CNT(i - 1, j - 1);
      } else {
        // Use a better score when there is only a case difference.
        if (SPELL_TOFOLD(bc) == SPELL_TOFOLD(gc)) {
          CNT(i, j) = SCORE_ICASE + CNT(i - 1, j - 1);
        } else {
          // For a similar character use SCORE_SIMILAR.
          if (slang != NULL
              && slang->sl_has_map
              && similar_chars(slang, gc, bc)) {
            CNT(i, j) = SCORE_SIMILAR + CNT(i - 1, j - 1);
          } else {
            CNT(i, j) = SCORE_SUBST + CNT(i - 1, j - 1);
          }
        }

        if (i > 1 && j > 1) {
          int pbc = wbadword[i - 2];
          int pgc = wgoodword[j - 2];
          if (bc == pgc && pbc == gc) {
            int t = SCORE_SWAP + CNT(i - 2, j - 2);
            if (t < CNT(i, j)) {
              CNT(i, j) = t;
            }
          }
        }
        int t = SCORE_DEL + CNT(i - 1, j);
        if (t < CNT(i, j)) {
          CNT(i, j) = t;
        }
        t = SCORE_INS + CNT(i, j - 1);
        if (t < CNT(i, j)) {
          CNT(i, j) = t;
        }
      }
    }
  }

  int i = CNT(badlen - 1, goodlen - 1);
  xfree(cnt);
  return i;
}

typedef struct {
  int badi;
  int goodi;
  int score;
} limitscore_T;

/// Like spell_edit_score(), but with a limit on the score to make it faster.
/// May return SCORE_MAXMAX when the score is higher than "limit".
///
/// This uses a stack for the edits still to be tried.
/// The idea comes from Aspell leditdist.cpp.  Rewritten in C and added support
/// for multi-byte characters.
static int spell_edit_score_limit(slang_T *slang, char *badword, char *goodword, int limit)
{
  return spell_edit_score_limit_w(slang, badword, goodword, limit);
}

/// Multi-byte version of spell_edit_score_limit().
/// Keep it in sync with the above!
static int spell_edit_score_limit_w(slang_T *slang, const char *badword, const char *goodword,
                                    int limit)
{
  limitscore_T stack[10];               // allow for over 3 * 2 edits
  int bc, gc;
  int score_off;
  int wbadword[MAXWLEN];
  int wgoodword[MAXWLEN];

  // Get the characters from the multi-byte strings and put them in an
  // int array for easy access.
  int bi = 0;
  for (const char *p = badword; *p != NUL;) {
    wbadword[bi++] = mb_cptr2char_adv(&p);
  }
  wbadword[bi++] = 0;
  int gi = 0;
  for (const char *p = goodword; *p != NUL;) {
    wgoodword[gi++] = mb_cptr2char_adv(&p);
  }
  wgoodword[gi++] = 0;

  // The idea is to go from start to end over the words.  So long as
  // characters are equal just continue, this always gives the lowest score.
  // When there is a difference try several alternatives.  Each alternative
  // increases "score" for the edit distance.  Some of the alternatives are
  // pushed unto a stack and tried later, some are tried right away.  At the
  // end of the word the score for one alternative is known.  The lowest
  // possible score is stored in "minscore".
  int stackidx = 0;
  bi = 0;
  gi = 0;
  int score = 0;
  int minscore = limit + 1;

  while (true) {
    // Skip over an equal part, score remains the same.
    while (true) {
      bc = wbadword[bi];
      gc = wgoodword[gi];

      if (bc != gc) {           // stop at a char that's different
        break;
      }
      if (bc == NUL) {          // both words end
        if (score < minscore) {
          minscore = score;
        }
        goto pop;               // do next alternative
      }
      bi++;
      gi++;
    }

    if (gc == NUL) {      // goodword ends, delete badword chars
      do {
        if ((score += SCORE_DEL) >= minscore) {
          goto pop;                 // do next alternative
        }
      } while (wbadword[++bi] != NUL);
      minscore = score;
    } else if (bc == NUL) {   // badword ends, insert badword chars
      do {
        if ((score += SCORE_INS) >= minscore) {
          goto pop;                 // do next alternative
        }
      } while (wgoodword[++gi] != NUL);
      minscore = score;
    } else {                  // both words continue
      // If not close to the limit, perform a change.  Only try changes
      // that may lead to a lower score than "minscore".
      // round 0: try deleting a char from badword
      // round 1: try inserting a char in badword
      for (int round = 0; round <= 1; round++) {
        score_off = score + (round == 0 ? SCORE_DEL : SCORE_INS);
        if (score_off < minscore) {
          if (score_off + SCORE_EDIT_MIN >= minscore) {
            // Near the limit, rest of the words must match.  We
            // can check that right now, no need to push an item
            // onto the stack.
            int bi2 = bi + 1 - round;
            int gi2 = gi + round;
            while (wgoodword[gi2] == wbadword[bi2]) {
              if (wgoodword[gi2] == NUL) {
                minscore = score_off;
                break;
              }
              bi2++;
              gi2++;
            }
          } else {
            // try deleting a character from badword later
            stack[stackidx].badi = bi + 1 - round;
            stack[stackidx].goodi = gi + round;
            stack[stackidx].score = score_off;
            stackidx++;
          }
        }
      }

      if (score + SCORE_SWAP < minscore) {
        // If swapping two characters makes a match then the
        // substitution is more expensive, thus there is no need to
        // try both.
        if (gc == wbadword[bi + 1] && bc == wgoodword[gi + 1]) {
          // Swap two characters, that is: skip them.
          gi += 2;
          bi += 2;
          score += SCORE_SWAP;
          continue;
        }
      }

      // Substitute one character for another which is the same
      // thing as deleting a character from both goodword and badword.
      // Use a better score when there is only a case difference.
      if (SPELL_TOFOLD(bc) == SPELL_TOFOLD(gc)) {
        score += SCORE_ICASE;
      } else {
        // For a similar character use SCORE_SIMILAR.
        if (slang != NULL
            && slang->sl_has_map
            && similar_chars(slang, gc, bc)) {
          score += SCORE_SIMILAR;
        } else {
          score += SCORE_SUBST;
        }
      }

      if (score < minscore) {
        // Do the substitution.
        gi++;
        bi++;
        continue;
      }
    }
pop:
    // Get here to try the next alternative, pop it from the stack.
    if (stackidx == 0) {                // stack is empty, finished
      break;
    }

    // pop an item from the stack
    stackidx--;
    gi = stack[stackidx].goodi;
    bi = stack[stackidx].badi;
    score = stack[stackidx].score;
  }

  // When the score goes over "limit" it may actually be much higher.
  // Return a very large number to avoid going below the limit when giving a
  // bonus.
  if (minscore > limit) {
    return SCORE_MAXMAX;
  }
  return minscore;
}
