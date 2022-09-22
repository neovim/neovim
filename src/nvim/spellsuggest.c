// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// spellsuggest.c: functions for spelling suggestions

#include "hunspell/hunspell_wrapper.h"
#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/eval.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/hashtab.h"
#include "nvim/input.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/profile.h"
#include "nvim/screen.h"
#include "nvim/spell.h"
#include "nvim/spell_defs.h"
#include "nvim/spellfile.h"
#include "nvim/spellsuggest.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim.h"

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
typedef struct suginfo_S {
  garray_T su_ga;                  ///< suggestions, contains "suggest_T"
  int su_maxcount;                 ///< max. number of suggestions displayed
  int su_maxscore;                 ///< maximum score for adding to su_ga
  int su_sfmaxscore;               ///< idem, for when doing soundfold words
  garray_T su_sga;                 ///< like su_ga, sound-folded scoring
  char_u *su_badptr;               ///< start of bad word in line
  int su_badlen;                   ///< length of detected bad word in line
  int su_badflags;                 ///< caps flags for bad word
  char_u su_badword[MAXWLEN];      ///< bad word truncated at su_badlen
  char_u su_fbadword[MAXWLEN];     ///< su_badword case-folded
  char_u su_sal_badword[MAXWLEN];  ///< su_badword soundfolded
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
#define SCORE_SPLIT     149     // split bad word
#define SCORE_SPLIT_NO  249     // split bad word with NOSPLITSUGS
#define SCORE_ICASE     52      // slightly different case
#define SCORE_REGION    200     // word is for different region
#define SCORE_RARE      180     // rare word
#define SCORE_SWAP      75      // swap two characters
#define SCORE_SWAP3     110     // swap two characters in three
#define SCORE_REP       65      // REP replacement
#define SCORE_SUBST     93      // substitute a character
#define SCORE_SIMILAR   33      // substitute a similar character
#define SCORE_SUBCOMP   33      // substitute a composing character
#define SCORE_DEL       94      // delete a character
#define SCORE_DELDUP    66      // delete a duplicated character
#define SCORE_DELCOMP   28      // delete a composing character
#define SCORE_INS       96      // insert a character
#define SCORE_INSDUP    67      // insert a duplicate character
#define SCORE_INSCOMP   30      // insert a composing character
#define SCORE_NONWORD   103     // change non-word to word char

#define SCORE_FILE      30      // suggestion from a file
#define SCORE_MAXINIT   350     // Initial maximum score: higher == slower.
                                // 350 allows for about three changes.

#define SCORE_COMMON1   30      // subtracted for words seen before
#define SCORE_COMMON2   40      // subtracted for words often seen
#define SCORE_COMMON3   50      // subtracted for words very often seen
#define SCORE_THRES2    10      // word count threshold for COMMON2
#define SCORE_THRES3    100     // word count threshold for COMMON3

// When trying changed soundfold words it becomes slow when trying more than
// two changes.  With less than two changes it's slightly faster but we miss a
// few good suggestions.  In rare cases we need to try three of four changes.
#define SCORE_SFMAX1    200     // maximum score for first try
#define SCORE_SFMAX2    300     // maximum score for second try
#define SCORE_SFMAX3    400     // maximum score for third try

#define SCORE_BIG       (SCORE_INS * 3)  // big difference
#define SCORE_MAXMAX    999999           // accept any score
#define SCORE_LIMITMAX  350              // for spell_edit_score_limit()

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
typedef struct trystate_S {
  state_T ts_state;         ///< state at this level, STATE_
  int ts_score;             ///< score
  idx_T ts_arridx;          ///< index in tree array, start of node
  int16_t ts_curi;          ///< index in list of child nodes
  char_u ts_fidx;           ///< index in fword[], case-folded bad word
  char_u ts_fidxtry;        ///< ts_fidx at which bytes may be changed
  char_u ts_twordlen;       ///< valid length of tword[]
  char_u ts_prefixdepth;    ///< stack depth for end of prefix or
                            ///< PFD_PREFIXTREE or PFD_NOPREFIX
  char_u ts_flags;          ///< TSF_ flags
  char_u ts_tcharlen;       ///< number of bytes in tword character
  char_u ts_tcharidx;       ///< current byte index in tword character
  char_u ts_isdiff;         ///< DIFF_ values
  char_u ts_fcharstart;     ///< index in fword where badword char started
  char_u ts_prewordlen;     ///< length of word in "preword[]"
  char_u ts_splitoff;       ///< index in "tword" after last split
  char_u ts_splitfidx;      ///< "ts_fidx" at word split
  char_u ts_complen;        ///< nr of compound words used
  char_u ts_compsplit;      ///< index for "compflags" where word was spit
  char_u ts_save_badflags;  ///< su_badflags saved here
  char_u ts_delidx;         ///< index in fword for char that was deleted,
                            ///< valid when "ts_flags" has TSF_DIDDEL
} trystate_T;

// values for ts_isdiff
#define DIFF_NONE       0       // no different byte (yet)
#define DIFF_YES        1       // different byte found
#define DIFF_INSERT     2       // inserting character

// values for ts_flags
#define TSF_PREFIXOK    1       // already checked that prefix is OK
#define TSF_DIDSPLIT    2       // tried split at this point
#define TSF_DIDDEL      4       // did a delete, "ts_delidx" has index

// special values ts_prefixdepth
#define PFD_NOPREFIX    0xff    // not using prefixes
#define PFD_PREFIXTREE  0xfe    // walking through the prefix tree
#define PFD_NOTSPECIAL  0xfd    // highest value that's not special

static long spell_suggest_timeout = 5000;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "spellsuggest.c.generated.h"
#endif

/// Like captype() but for a KEEPCAP word add ONECAP if the word starts with a
/// capital.  So that make_case_word() can turn WOrd into Word.
/// Add ALLCAP for "WOrD".
static int badword_captype(char *word, char *end)
  FUNC_ATTR_NONNULL_ALL
{
  int flags = captype(word, end);
  int c;
  int l, u;
  bool first;
  char *p;

  if (flags & WF_KEEPCAP) {
    // Count the number of UPPER and lower case letters.
    l = u = 0;
    first = false;
    for (p = word; p < end; MB_PTR_ADV(p)) {
      c = utf_ptr2char(p);
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
  }
  return flags;
}

// values for sps_flags
#define SPS_BEST    1
#define SPS_FAST    2
#define SPS_DOUBLE  4

static int sps_flags = SPS_BEST;  ///< flags from 'spellsuggest'
static int sps_limit = 9999;      ///< max nr of suggestions given

/// Check the 'spellsuggest' option.  Return FAIL if it's wrong.
/// Sets "sps_flags" and "sps_limit".
int spell_check_sps(void)
{
  char *p;
  char *s;
  char buf[MAXPATHL];
  int f;

  sps_flags = 0;
  sps_limit = 9999;

  for (p = p_sps; *p != NUL;) {
    copy_option_part(&p, (char *)buf, MAXPATHL, ",");

    f = 0;
    if (ascii_isdigit(*buf)) {
      s = (char *)buf;
      sps_limit = getdigits_int(&s, true, 0);
      if (*s != NUL && !ascii_isdigit(*s)) {
        f = -1;
      }
    } else if (strcmp(buf, "best") == 0) {
      f = SPS_BEST;
    } else if (strcmp(buf, "fast") == 0) {
      f = SPS_FAST;
    } else if (strcmp(buf, "double") == 0) {
      f = SPS_DOUBLE;
    } else if (STRNCMP(buf, "expr:", 5) != 0
               && STRNCMP(buf, "file:", 5) != 0
               && (STRNCMP(buf, "timeout:", 8) != 0
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
  char *line;
  pos_T prev_cursor = curwin->w_cursor;
  char wcopy[MAXWLEN + 2];
  char *p;
  int c;
  suginfo_T sug;
  suggest_T *stp;
  int mouse_used;
  int need_cap;
  int limit;
  int selected = count;
  int badlen = 0;
  int msg_scroll_save = msg_scroll;
  const int wo_spell_save = curwin->w_p_spell;

  if (!curwin->w_p_spell) {
    did_set_spelllang(curwin);
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
    // Find the start of the badly spelled word.
  } else if (spell_move_to(curwin, FORWARD, true, true, NULL) == 0
             || curwin->w_cursor.col > prev_cursor.col) {
    // No bad word or it starts after the cursor: use the word under the
    // cursor.
    curwin->w_cursor = prev_cursor;
    line = get_cursor_line_ptr();
    p = line + curwin->w_cursor.col;
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
  need_cap = check_need_cap(curwin->w_cursor.lnum, curwin->w_cursor.col);

  // Make a copy of current line since autocommands may free the line.
  line = xstrdup(get_cursor_line_ptr());
  spell_suggest_timeout = 5000;

  // Get the list of suggestions.  Limit to 'lines' - 2 or the number in
  // 'spellsuggest', whatever is smaller.
  if (sps_limit > Rows - 2) {
    limit = Rows - 2;
  } else {
    limit = sps_limit;
  }
  spell_find_suggest((char_u *)line + curwin->w_cursor.col, badlen, &sug, limit,
                     true, need_cap, true);

  if (GA_EMPTY(&sug.su_ga)) {
    msg(_("Sorry, no suggestions"));
  } else if (count > 0) {
    if (count > sug.su_ga.ga_len) {
      smsg(_("Sorry, only %" PRId64 " suggestions"),
           (int64_t)sug.su_ga.ga_len);
    }
  } else {
    // When 'rightleft' is set the list is drawn right-left.
    cmdmsg_rl = curwin->w_p_rl;
    if (cmdmsg_rl) {
      msg_col = Columns - 1;
    }

    // List the suggestions.
    msg_start();
    msg_row = Rows - 1;         // for when 'cmdheight' > 1
    lines_left = Rows;          // avoid more prompt
    vim_snprintf((char *)IObuff, IOSIZE, _("Change \"%.*s\" to:"),
                 sug.su_badlen, sug.su_badptr);
    if (cmdmsg_rl && STRNCMP(IObuff, "Change", 6) == 0) {
      // And now the rabbit from the high hat: Avoid showing the
      // untranslated message rightleft.
      vim_snprintf((char *)IObuff, IOSIZE, ":ot \"%.*s\" egnahC",
                   sug.su_badlen, sug.su_badptr);
    }
    msg_puts((const char *)IObuff);
    msg_clr_eos();
    msg_putchar('\n');

    msg_scroll = true;
    for (int i = 0; i < sug.su_ga.ga_len; i++) {
      stp = &SUG(sug.su_ga, i);

      // The suggested word may replace only part of the bad word, add
      // the not replaced part.  But only when it's not getting too long.
      STRLCPY(wcopy, stp->st_word, MAXWLEN + 1);
      int el = sug.su_badlen - stp->st_orglen;
      if (el > 0 && stp->st_wordlen + el <= MAXWLEN) {
        STRLCPY(wcopy + stp->st_wordlen, sug.su_badptr + stp->st_orglen, el + 1);
      }
      vim_snprintf((char *)IObuff, IOSIZE, "%2d", i + 1);
      if (cmdmsg_rl) {
        rl_mirror((char_u *)IObuff);
      }
      msg_puts((const char *)IObuff);

      vim_snprintf((char *)IObuff, IOSIZE, " \"%s\"", wcopy);
      msg_puts((const char *)IObuff);

      // The word may replace more than "su_badlen".
      if (sug.su_badlen < stp->st_orglen) {
        vim_snprintf((char *)IObuff, IOSIZE, _(" < \"%.*s\""),
                     stp->st_orglen, sug.su_badptr);
        msg_puts((const char *)IObuff);
      }

      if (p_verbose > 0) {
        // Add the score.
        if (sps_flags & (SPS_DOUBLE | SPS_BEST)) {
          vim_snprintf((char *)IObuff, IOSIZE, " (%s%d - %d)",
                       stp->st_salscore ? "s " : "",
                       stp->st_score, stp->st_altscore);
        } else {
          vim_snprintf((char *)IObuff, IOSIZE, " (%d)",
                       stp->st_score);
        }
        if (cmdmsg_rl) {
          // Mirror the numbers, but keep the leading space.
          rl_mirror((char_u *)IObuff + 1);
        }
        msg_advance(30);
        msg_puts((const char *)IObuff);
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
      repl_from = xstrnsave((char *)sug.su_badptr, (size_t)sug.su_badlen);
      vim_snprintf((char *)IObuff, IOSIZE, "%s%.*s", stp->st_word,
                   sug.su_badlen - stp->st_orglen,
                   sug.su_badptr + stp->st_orglen);
      repl_to = xstrdup((char *)IObuff);
    } else {
      // Replacing su_badlen or more, use the whole word.
      repl_from = xstrnsave((char *)sug.su_badptr, (size_t)stp->st_orglen);
      repl_to = xstrdup(stp->st_word);
    }

    // Replace the word.
    p = xmalloc(STRLEN(line) - (size_t)stp->st_orglen + (size_t)stp->st_wordlen + 1);
    c = (int)(sug.su_badptr - (char_u *)line);
    memmove(p, line, (size_t)c);
    STRCPY(p + c, stp->st_word);
    STRCAT(p, sug.su_badptr + stp->st_orglen);

    // For redo we use a change-word command.
    ResetRedobuff();
    AppendToRedobuff("ciw");
    AppendToRedobuffLit((char *)p + c,
                        stp->st_wordlen + sug.su_badlen - stp->st_orglen);
    AppendCharToRedobuff(ESC);

    // "p" may be freed here
    ml_replace(curwin->w_cursor.lnum, (char *)p, false);
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
void spell_suggest_list(garray_T *gap, char_u *word, int maxcount, bool need_cap, bool interactive)
{
  suginfo_T sug;
  suggest_T *stp;
  char_u *wcopy;

  spell_find_suggest(word, 0, &sug, maxcount, false, need_cap, interactive);

  // Make room in "gap".
  ga_init(gap, sizeof(char_u *), sug.su_ga.ga_len + 1);
  ga_grow(gap, sug.su_ga.ga_len);
  for (int i = 0; i < sug.su_ga.ga_len; i++) {
    stp = &SUG(sug.su_ga, i);

    // The suggested word may replace only part of "word", add the not
    // replaced part.
    wcopy = xmalloc((size_t)stp->st_wordlen + STRLEN(sug.su_badptr + stp->st_orglen) + 1);
    STRCPY(wcopy, stp->st_word);
    STRCPY(wcopy + stp->st_wordlen, sug.su_badptr + stp->st_orglen);
    ((char_u **)gap->ga_data)[gap->ga_len++] = wcopy;
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
static void spell_find_suggest(char_u *badptr, int badlen, suginfo_T *su, int maxcount,
                               bool banbadword, bool need_cap, bool interactive)
{
  hlf_T attr = HLF_COUNT;
  char_u buf[MAXPATHL];
  char *p;
  char *sps_copy;
  static bool expr_busy = false;
  int c;
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
    size_t tmplen = spell_check(curwin, (char *)su->su_badptr, &attr, NULL, false);
    assert(tmplen <= INT_MAX);
    su->su_badlen = (int)tmplen;
  }
  su->su_maxcount = maxcount;
  su->su_maxscore = SCORE_MAXINIT;

  if (su->su_badlen >= MAXWLEN) {
    su->su_badlen = MAXWLEN - 1;        // just in case
  }
  STRLCPY(su->su_badword, su->su_badptr, su->su_badlen + 1);
  (void)spell_casefold(curwin, (char *)su->su_badptr, su->su_badlen, (char *)su->su_fbadword,
                       MAXWLEN);

  // TODO(vim): make this work if the case-folded text is longer than the
  // original text. Currently an illegal byte causes wrong pointer
  // computations.
  su->su_fbadword[su->su_badlen] = NUL;

  // get caps flags for bad word
  su->su_badflags = badword_captype((char *)su->su_badptr,
                                    (char *)(su->su_badptr + su->su_badlen));
  if (need_cap) {
    su->su_badflags |= WF_ONECAP;
  }

  // If the word is not capitalised and spell_check() doesn't consider the
  // word to be bad then it might need to be capitalised.  Add a suggestion
  // for that.
  c = utf_ptr2char((char *)su->su_badptr);
  if (!SPELL_ISUPPER(c) && attr == HLF_COUNT) {
    make_case_word(su->su_badword, buf, WF_ONECAP);
    add_suggestion(su, &su->su_ga, (char *)buf, su->su_badlen, SCORE_ICASE,
                   0, true, false);
  }

  // Ban the bad word itself.  It may appear in another region.
  if (banbadword) {
    add_banned(su, su->su_badword);
  }

  // Make a copy of 'spellsuggest', because the expression may change it.
  sps_copy = xstrdup(p_sps);

  // Loop over the items in 'spellsuggest'.
  for (p = sps_copy; *p != NUL;) {
    copy_option_part(&p, (char *)buf, MAXPATHL, ",");

    if (STRNCMP(buf, "expr:", 5) == 0) {
      // Evaluate an expression.  Skip this when called recursively,
      // when using spellsuggest() in the expression.
      if (!expr_busy) {
        expr_busy = true;
        spell_suggest_expr(su, buf + 5);
        expr_busy = false;
      }
    } else if (STRNCMP(buf, "file:", 5) == 0) {
      // Use list of suggestions in a file.
      spell_suggest_file(su, buf + 5);
    } else if (STRNCMP(buf, "timeout:", 8) == 0) {
      // Limit the time searching for suggestions.
      spell_suggest_timeout = atol((char *)buf + 8);
    } else if (!did_intern) {
      // Use internal method once.
      spell_suggest_intern(su, interactive);
      did_intern = true;
    }
  }

  xfree(sps_copy);
}

/// Find suggestions by evaluating expression "expr".
static void spell_suggest_expr(suginfo_T *su, char_u *expr)
{
  int score;
  const char *p;

  // The work is split up in a few parts to avoid having to export
  // suginfo_T.
  // First evaluate the expression and get the resulting list.
  list_T *const list = eval_spell_expr((char *)su->su_badword, (char *)expr);
  if (list != NULL) {
    // Loop over the items in the list.
    TV_LIST_ITER(list, li, {
      if (TV_LIST_ITEM_TV(li)->v_type == VAR_LIST) {
        // Get the word and the score from the items.
        score = get_spellword(TV_LIST_ITEM_TV(li)->vval.v_list, &p);
        if (score >= 0 && score <= su->su_maxscore) {
          add_suggestion(su, &su->su_ga, p, su->su_badlen,
                         score, 0, true, false);
        }
      }
    });
    tv_list_unref(list);
  }

  // Remove bogus suggestions, sort and truncate at "maxcount".
  check_suggestions(su, &su->su_ga);
  (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
}

/// Find suggestions in file "fname".  Used for "file:" in 'spellsuggest'.
static void spell_suggest_file(suginfo_T *su, char_u *fname)
{
  FILE *fd;
  char line[MAXWLEN * 2];
  char *p;
  int len;
  char_u cword[MAXWLEN];

  // Open the file.
  fd = os_fopen((char *)fname, "r");
  if (fd == NULL) {
    semsg(_(e_notopen), fname);
    return;
  }

  // Read it line by line.
  while (!vim_fgets((char_u *)line, MAXWLEN * 2, fd) && !got_int) {
    line_breakcheck();

    p = vim_strchr(line, '/');
    if (p == NULL) {
      continue;             // No Tab found, just skip the line.
    }
    *p++ = NUL;
    if (STRICMP(su->su_badword, line) == 0) {
      // Match!  Isolate the good word, until CR or NL.
      for (len = 0; p[len] >= ' '; len++) {}
      p[len] = NUL;

      // If the suggestion doesn't have specific case duplicate the case
      // of the bad word.
      if (captype(p, NULL) == 0) {
        make_case_word((char_u *)p, cword, su->su_badflags);
        p = (char *)cword;
      }

      add_suggestion(su, &su->su_ga, (char *)p, su->su_badlen,
                     SCORE_FILE, 0, true, false);
    }
  }

  fclose(fd);

  // Remove bogus suggestions, sort and truncate at "maxcount".
  check_suggestions(su, &su->su_ga);
  (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
}

/// Find suggestions for the internal method indicated by "sps_flags".
static void spell_suggest_intern(suginfo_T *su, bool interactive)
{
  for (int i = 0; i < curbuf->b_s.b_langp.ga_len; i++) {
    langp_T *lp = LANGP_ENTRY(curbuf->b_s.b_langp, i);
    if (lp->lp_slang != NULL && lp->lp_slang->sl_hunspell != NULL) {
      char **suggestions = NULL;
      size_t nsuggs =
        hunspell_suggest(lp->lp_slang->sl_hunspell, (const char *)su->su_badptr,
                         (size_t)su->su_badlen, &suggestions);

      for (size_t j = 0; j < nsuggs; j++) {
        add_suggestion(su, &su->su_ga, suggestions[j], su->su_badlen,
                       SCORE_FILE + (int)j, 0, true, false);
      }

      if (nsuggs > 0) {
        xfree(suggestions);
      }
    }
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

// Check the maximum score, if we go over it we won't try this change.
#define TRY_DEEPER(su, stack, depth, add) \
  ((depth) < MAXWLEN - 1 && (stack)[depth].ts_score + (add) < (su)->su_maxscore)

/// For the goodword in "stp" compute the soundalike score compared to the
/// badword.
///
/// @param badsound  sound-folded badword
static int stp_sal_score(suggest_T *stp, suginfo_T *su, slang_T *slang, char_u *badsound)
{
  char_u *p;
  char_u *pbad;
  char_u *pgood;
  char_u badsound2[MAXWLEN];
  char_u fword[MAXWLEN];
  char_u goodsound[MAXWLEN];
  char_u goodword[MAXWLEN];
  int lendiff;

  lendiff = su->su_badlen - stp->st_orglen;
  if (lendiff >= 0) {
    pbad = badsound;
  } else {
    // soundfold the bad word with more characters following
    (void)spell_casefold(curwin, su->su_badptr, stp->st_orglen, fword, MAXWLEN);

    // When joining two words the sound often changes a lot.  E.g., "t he"
    // sounds like "t h" while "the" sounds like "@".  Avoid that by
    // removing the space.  Don't do it when the good word also contains a
    // space.
    if (ascii_iswhite(su->su_badptr[su->su_badlen])
        && *skiptowhite(stp->st_word) == NUL) {
      for (p = fword; *(p = (char_u *)skiptowhite((char *)p)) != NUL;) {
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
    STRLCPY(goodword + stp->st_wordlen,
            su->su_badptr + su->su_badlen - lendiff, lendiff + 1);
    pgood = goodword;
  } else {
    pgood = (char_u *)stp->st_word;
  }

  // Sound-fold the word and compute the score for the difference.
  spell_soundfold(slang, pgood, false, goodsound);

  return soundalike_score((char *)goodsound, (char *)pbad);
}

/// structure used to store soundfolded words that add_sound_suggest() has
/// handled already.
typedef struct {
  int16_t sft_score;   ///< lowest score used
  char_u sft_word[1];  ///< soundfolded word, actually longer
} sftword_T;

#define HIKEY2SFT(p)  ((sftword_T *)((p) - (dumsft.sft_word - (char_u *)&dumsft)))
#define HI2SFT(hi)     HIKEY2SFT((hi)->hi_key)

/// Adds a suggestion to the list of suggestions.
/// For a suggestion that is already in the list the lowest score is remembered.
///
/// @param gap  either su_ga or su_sga
/// @param badlenarg  len of bad word replaced with "goodword"
/// @param had_bonus  value for st_had_bonus
/// @param maxsf  su_maxscore applies to soundfold score, su_sfmaxscore to the total score.
static void add_suggestion(suginfo_T *su, garray_T *gap, const char *goodword, int badlenarg,
                           int score, int altscore, bool had_bonus, bool maxsf)
{
  int goodlen;                  // len of goodword changed
  int badlen;                   // len of bad word changed
  suggest_T *stp;
  suggest_T new_sug;

  // Minimize "badlen" for consistency.  Avoids that changing "the the" to
  // "thee the" is added next to changing the first "the" the "thee".
  const char *pgood = goodword + strlen(goodword);
  char_u *pbad = su->su_badptr + badlenarg;
  for (;;) {
    goodlen = (int)(pgood - goodword);
    badlen = (int)(pbad - su->su_badptr);
    if (goodlen <= 0 || badlen <= 0) {
      break;
    }
    MB_PTR_BACK(goodword, pgood);
    MB_PTR_BACK(su->su_badptr, pbad);
    if (utf_ptr2char((char *)pgood) != utf_ptr2char((char *)pbad)) {
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
    stp = &SUG(*gap, 0);
    for (i = gap->ga_len; --i >= 0; stp++) {
      if (stp->st_wordlen == goodlen
          && stp->st_orglen == badlen
          && STRNCMP(stp->st_word, goodword, goodlen) == 0) {
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
    stp = GA_APPEND_VIA_PTR(suggest_T, gap);
    stp->st_word = xstrnsave(goodword, (size_t)goodlen);
    stp->st_wordlen = goodlen;
    stp->st_score = score;
    stp->st_altscore = altscore;
    stp->st_had_bonus = had_bonus;
    stp->st_orglen = badlen;

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
  suggest_T *stp;
  char_u longword[MAXWLEN + 1];
  int len;
  hlf_T attr;

  if (gap->ga_len == 0) {
    return;
  }
  stp = &SUG(*gap, 0);
  for (int i = gap->ga_len - 1; i >= 0; i--) {
    // Need to append what follows to check for "the the".
    STRLCPY(longword, stp[i].st_word, MAXWLEN + 1);
    len = stp[i].st_wordlen;
    STRLCPY(longword + len, su->su_badptr + stp[i].st_orglen,
            MAXWLEN - len + 1);
    attr = HLF_COUNT;
    (void)spell_check(curwin, longword, &attr, NULL, false);
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
static void add_banned(suginfo_T *su, char_u *word)
{
  char_u *s;
  hash_T hash;
  hashitem_T *hi;

  hash = hash_hash(word);
  const size_t word_len = STRLEN(word);
  hi = hash_lookup(&su->su_banned, (const char *)word, word_len, hash);
  if (HASHITEM_EMPTY(hi)) {
    s = xmemdupz(word, word_len);
    hash_add_item(&su->su_banned, hi, s, hash);
  }
}

/// Recompute the score for one suggestion if sound-folding is possible.
static void rescore_one(suginfo_T *su, suggest_T *stp)
{
  slang_T *slang = stp->st_slang;
  char_u sal_badword[MAXWLEN];
  char_u *p;

  // Only rescore suggestions that have no sal score yet and do have a
  // language.
  if (slang != NULL && !GA_EMPTY(&slang->sl_sal) && !stp->st_had_bonus) {
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
  int n = p1->st_score - p2->st_score;

  if (n == 0) {
    n = p1->st_altscore - p2->st_altscore;
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
  if (gap->ga_len > 0) {
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
  int goodlen;
  int badlen;
  int n;
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

  goodlen = (int)strlen(goodsound);
  badlen = (int)strlen(badsound);

  // Return quickly if the lengths are too different to be fixed by two
  // changes.
  n = goodlen - badlen;
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

typedef struct {
  int badi;
  int goodi;
  int score;
} limitscore_T;
