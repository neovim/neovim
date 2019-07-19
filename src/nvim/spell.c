// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// spell.c: code for spell checking
//
// See spellfile.c for the Vim spell file format.
//
// The spell checking mechanism uses a tree (aka trie).  Each node in the tree
// has a list of bytes that can appear (siblings).  For each byte there is a
// pointer to the node with the byte that follows in the word (child).
//
// A NUL byte is used where the word may end.  The bytes are sorted, so that
// binary searching can be used and the NUL bytes are at the start.  The
// number of possible bytes is stored before the list of bytes.
//
// The tree uses two arrays: "byts" stores the characters, "idxs" stores
// either the next index or flags.  The tree starts at index 0.  For example,
// to lookup "vi" this sequence is followed:
//      i = 0
//      len = byts[i]
//      n = where "v" appears in byts[i + 1] to byts[i + len]
//      i = idxs[n]
//      len = byts[i]
//      n = where "i" appears in byts[i + 1] to byts[i + len]
//      i = idxs[n]
//      len = byts[i]
//      find that byts[i + 1] is 0, idxs[i + 1] has flags for "vi".
//
// There are two word trees: one with case-folded words and one with words in
// original case.  The second one is only used for keep-case words and is
// usually small.
//
// There is one additional tree for when not all prefixes are applied when
// generating the .spl file.  This tree stores all the possible prefixes, as
// if they were words.  At each word (prefix) end the prefix nr is stored, the
// following word must support this prefix nr.  And the condition nr is
// stored, used to lookup the condition that the word must match with.
//
// Thanks to Olaf Seibert for providing an example implementation of this tree
// and the compression mechanism.
// LZ trie ideas:
//      http://www.irb.hr/hr/home/ristov/papers/RistovLZtrieRevision1.pdf
// More papers: http://www-igm.univ-mlv.fr/~laporte/publi_en.html
//
// Matching involves checking the caps type: Onecap ALLCAP KeepCap.
//
// Why doesn't Vim use aspell/ispell/myspell/etc.?
// See ":help develop-spell".

// Use SPELL_PRINTTREE for debugging: dump the word tree after adding a word.
// Only use it for small word lists!

// Use SPELL_COMPRESS_ALLWAYS for debugging: compress the word tree after
// adding a word.  Only use it for small word lists!

// Use DEBUG_TRIEWALK to print the changes made in suggest_trie_walk() for a
// specific word.

// Use this to adjust the score after finding suggestions, based on the
// suggested word sounding like the bad word.  This is much faster than doing
// it for every possible suggestion.
// Disadvantage: When "the" is typed as "hte" it sounds quite different ("@"
// vs "ht") and goes down in the list.
// Used when 'spellsuggest' is set to "best".
#define RESCORE(word_score, sound_score) ((3 * word_score + sound_score) / 4)

// Do the opposite: based on a maximum end score and a known sound score,
// compute the maximum word score that can be used.
#define MAXSCORE(word_score, sound_score) ((4 * word_score - sound_score) / 3)

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <wctype.h>

/* for offsetof() */
#include <stddef.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/spell.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/fileio.h"
#include "nvim/func_attr.h"
#include "nvim/getchar.h"
#include "nvim/hashtab.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/spellfile.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/undo.h"
#include "nvim/os/os.h"
#include "nvim/os/input.h"

// only used for su_badflags
#define WF_MIXCAP   0x20        // mix of upper and lower case: macaRONI

#define WF_CAPMASK (WF_ONECAP | WF_ALLCAP | WF_KEEPCAP | WF_FIXCAP)

// Result values.  Lower number is accepted over higher one.
#define SP_BANNED       -1
#define SP_RARE         0
#define SP_OK           1
#define SP_LOCAL        2
#define SP_BAD          3

// First language that is loaded, start of the linked list of loaded
// languages.
slang_T *first_lang = NULL;

// file used for "zG" and "zW"
char_u *int_wordlist = NULL;

typedef struct wordcount_S {
  uint16_t wc_count;                // nr of times word was seen
  char_u wc_word[1];                // word, actually longer
} wordcount_T;

#define WC_KEY_OFF   offsetof(wordcount_T, wc_word)
#define HI2WC(hi)    ((wordcount_T *)((hi)->hi_key - WC_KEY_OFF))
#define MAXWORDCOUNT 0xffff

// Information used when looking for suggestions.
typedef struct suginfo_S {
  garray_T su_ga;                   // suggestions, contains "suggest_T"
  int su_maxcount;                  // max. number of suggestions displayed
  int su_maxscore;                  // maximum score for adding to su_ga
  int su_sfmaxscore;                // idem, for when doing soundfold words
  garray_T su_sga;                  // like su_ga, sound-folded scoring
  char_u      *su_badptr;           // start of bad word in line
  int su_badlen;                    // length of detected bad word in line
  int su_badflags;                  // caps flags for bad word
  char_u su_badword[MAXWLEN];       // bad word truncated at su_badlen
  char_u su_fbadword[MAXWLEN];      // su_badword case-folded
  char_u su_sal_badword[MAXWLEN];   // su_badword soundfolded
  hashtab_T su_banned;              // table with banned words
  slang_T     *su_sallang;          // default language for sound folding
} suginfo_T;

// One word suggestion.  Used in "si_ga".
typedef struct {
  char_u      *st_word;         // suggested word, allocated string
  int st_wordlen;               // STRLEN(st_word)
  int st_orglen;                // length of replaced text
  int st_score;                 // lower is better
  int st_altscore;              // used when st_score compares equal
  bool st_salscore;             // st_score is for soundalike
  bool st_had_bonus;            // bonus already included in score
  slang_T     *st_slang;        // language used for sound folding
} suggest_T;

#define SUG(ga, i) (((suggest_T *)(ga).ga_data)[i])

// True if a word appears in the list of banned words.
#define WAS_BANNED(su, word) (!HASHITEM_EMPTY(hash_find(&su->su_banned, word)))

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
// two changes.  With less then two changes it's slightly faster but we miss a
// few good suggestions.  In rare cases we need to try three of four changes.
#define SCORE_SFMAX1    200     // maximum score for first try
#define SCORE_SFMAX2    300     // maximum score for second try
#define SCORE_SFMAX3    400     // maximum score for third try

#define SCORE_BIG       SCORE_INS * 3   // big difference
#define SCORE_MAXMAX    999999          // accept any score
#define SCORE_LIMITMAX  350             // for spell_edit_score_limit()

// for spell_edit_score_limit() we need to know the minimum value of
// SCORE_ICASE, SCORE_SWAP, SCORE_DEL, SCORE_SIMILAR and SCORE_INS
#define SCORE_EDIT_MIN  SCORE_SIMILAR

// Structure to store info for word matching.
typedef struct matchinf_S {
  langp_T     *mi_lp;                   // info for language and region

  // pointers to original text to be checked
  char_u      *mi_word;                 // start of word being checked
  char_u      *mi_end;                  // end of matching word so far
  char_u      *mi_fend;                 // next char to be added to mi_fword
  char_u      *mi_cend;                 // char after what was used for
                                        // mi_capflags

  // case-folded text
  char_u mi_fword[MAXWLEN + 1];         // mi_word case-folded
  int mi_fwordlen;                      // nr of valid bytes in mi_fword

  // for when checking word after a prefix
  int mi_prefarridx;                    // index in sl_pidxs with list of
                                        // affixID/condition
  int mi_prefcnt;                       // number of entries at mi_prefarridx
  int mi_prefixlen;                     // byte length of prefix
  int mi_cprefixlen;                    // byte length of prefix in original
                                        // case

  // for when checking a compound word
  int mi_compoff;                       // start of following word offset
  char_u mi_compflags[MAXWLEN];         // flags for compound words used
  int mi_complen;                       // nr of compound words used
  int mi_compextra;                     // nr of COMPOUNDROOT words

  // others
  int mi_result;                        // result so far: SP_BAD, SP_OK, etc.
  int mi_capflags;                      // WF_ONECAP WF_ALLCAP WF_KEEPCAP
  win_T       *mi_win;                  // buffer being checked

  // for NOBREAK
  int mi_result2;                       // "mi_resul" without following word
  char_u      *mi_end2;                 // "mi_end" without following word
} matchinf_T;

// Structure used for the cookie argument of do_in_runtimepath().
typedef struct spelload_S {
  char_u sl_lang[MAXWLEN + 1];          // language name
  slang_T *sl_slang;                    // resulting slang_T struct
  int sl_nobreak;                       // NOBREAK language found
} spelload_T;

#define SY_MAXLEN   30
typedef struct syl_item_S {
  char_u sy_chars[SY_MAXLEN];               // the sequence of chars
  int sy_len;
} syl_item_T;

spelltab_T spelltab;
int did_set_spelltab;

// structure used to store soundfolded words that add_sound_suggest() has
// handled already.
typedef struct {
  short sft_score;              // lowest score used
  char_u sft_word[1];           // soundfolded word, actually longer
} sftword_T;

typedef struct {
  int badi;
  int goodi;
  int score;
} limitscore_T;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "spell.c.generated.h"
#endif

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

// mode values for find_word
#define FIND_FOLDWORD       0   // find word case-folded
#define FIND_KEEPWORD       1   // find keep-case word
#define FIND_PREFIX         2   // find word after prefix
#define FIND_COMPOUND       3   // find case-folded compound word
#define FIND_KEEPCOMPOUND   4   // find keep-case compound word

char *e_format = N_("E759: Format error in spell file");

// Remember what "z?" replaced.
static char_u *repl_from = NULL;
static char_u *repl_to = NULL;

// Main spell-checking function.
// "ptr" points to a character that could be the start of a word.
// "*attrp" is set to the highlight index for a badly spelled word.  For a
// non-word or when it's OK it remains unchanged.
// This must only be called when 'spelllang' is not empty.
//
// "capcol" is used to check for a Capitalised word after the end of a
// sentence.  If it's zero then perform the check.  Return the column where to
// check next, or -1 when no sentence end was found.  If it's NULL then don't
// worry.
//
// Returns the length of the word in bytes, also when it's OK, so that the
// caller can skip over the word.
size_t spell_check(
    win_T *wp,                // current window
    char_u *ptr,
    hlf_T *attrp,
    int *capcol,              // column to check for Capital
    bool docount              // count good words
)
{
  matchinf_T mi;              // Most things are put in "mi" so that it can
                              // be passed to functions quickly.
  size_t nrlen = 0;              // found a number first
  int c;
  size_t wrongcaplen = 0;
  int lpi;
  bool count_word = docount;

  // A word never starts at a space or a control character. Return quickly
  // then, skipping over the character.
  if (*ptr <= ' ') {
    return 1;
  }

  // Return here when loading language files failed.
  if (GA_EMPTY(&wp->w_s->b_langp)) {
    return 1;
  }

  memset(&mi, 0, sizeof(matchinf_T));

  // A number is always OK.  Also skip hexadecimal numbers 0xFF99 and
  // 0X99FF.  But always do check spelling to find "3GPP" and "11
  // julifeest".
  if (*ptr >= '0' && *ptr <= '9') {
    if (*ptr == '0' && (ptr[1] == 'b' || ptr[1] == 'B')) {
      mi.mi_end = (char_u*) skipbin((char*) ptr + 2);
    } else if (*ptr == '0' && (ptr[1] == 'x' || ptr[1] == 'X')) {
      mi.mi_end = skiphex(ptr + 2);
    } else {
      mi.mi_end = skipdigits(ptr);
    }
    nrlen = (size_t)(mi.mi_end - ptr);
  }

  // Find the normal end of the word (until the next non-word character).
  mi.mi_word = ptr;
  mi.mi_fend = ptr;
  if (spell_iswordp(mi.mi_fend, wp)) {
    do {
      MB_PTR_ADV(mi.mi_fend);
    } while (*mi.mi_fend != NUL && spell_iswordp(mi.mi_fend, wp));

    if (capcol != NULL && *capcol == 0 && wp->w_s->b_cap_prog != NULL) {
      // Check word starting with capital letter.
      c = PTR2CHAR(ptr);
      if (!SPELL_ISUPPER(c)) {
        wrongcaplen = (size_t)(mi.mi_fend - ptr);
      }
    }
  }
  if (capcol != NULL) {
    *capcol = -1;
  }

  // We always use the characters up to the next non-word character,
  // also for bad words.
  mi.mi_end = mi.mi_fend;

  // Check caps type later.
  mi.mi_capflags = 0;
  mi.mi_cend = NULL;
  mi.mi_win = wp;

  // case-fold the word with one non-word character, so that we can check
  // for the word end.
  if (*mi.mi_fend != NUL) {
    MB_PTR_ADV(mi.mi_fend);
  }

  (void)spell_casefold(ptr, (int)(mi.mi_fend - ptr), mi.mi_fword, MAXWLEN + 1);
  mi.mi_fwordlen = (int)STRLEN(mi.mi_fword);

  // The word is bad unless we recognize it.
  mi.mi_result = SP_BAD;
  mi.mi_result2 = SP_BAD;

  // Loop over the languages specified in 'spelllang'.
  // We check them all, because a word may be matched longer in another
  // language.
  for (lpi = 0; lpi < wp->w_s->b_langp.ga_len; ++lpi) {
    mi.mi_lp = LANGP_ENTRY(wp->w_s->b_langp, lpi);

    // If reloading fails the language is still in the list but everything
    // has been cleared.
    if (mi.mi_lp->lp_slang->sl_fidxs == NULL) {
      continue;
    }

    // Check for a matching word in case-folded words.
    find_word(&mi, FIND_FOLDWORD);

    // Check for a matching word in keep-case words.
    find_word(&mi, FIND_KEEPWORD);

    // Check for matching prefixes.
    find_prefix(&mi, FIND_FOLDWORD);

    // For a NOBREAK language, may want to use a word without a following
    // word as a backup.
    if (mi.mi_lp->lp_slang->sl_nobreak && mi.mi_result == SP_BAD
        && mi.mi_result2 != SP_BAD) {
      mi.mi_result = mi.mi_result2;
      mi.mi_end = mi.mi_end2;
    }

    // Count the word in the first language where it's found to be OK.
    if (count_word && mi.mi_result == SP_OK) {
      count_common_word(mi.mi_lp->lp_slang, ptr,
          (int)(mi.mi_end - ptr), 1);
      count_word = false;
    }
  }

  if (mi.mi_result != SP_OK) {
    // If we found a number skip over it.  Allows for "42nd".  Do flag
    // rare and local words, e.g., "3GPP".
    if (nrlen > 0) {
      if (mi.mi_result == SP_BAD || mi.mi_result == SP_BANNED) {
        return nrlen;
      }
    } else if (!spell_iswordp_nmw(ptr, wp)) {
    // When we are at a non-word character there is no error, just
    // skip over the character (try looking for a word after it).
      if (capcol != NULL && wp->w_s->b_cap_prog != NULL) {
        regmatch_T regmatch;

        // Check for end of sentence.
        regmatch.regprog = wp->w_s->b_cap_prog;
        regmatch.rm_ic = false;
        int r = vim_regexec(&regmatch, ptr, 0);
        wp->w_s->b_cap_prog = regmatch.regprog;
        if (r) {
          *capcol = (int)(regmatch.endp[0] - ptr);
        }
      }

      if (has_mbyte) {
        return (size_t)(*mb_ptr2len)(ptr);
      }
      return 1;
    } else if (mi.mi_end == ptr) {
      // Always include at least one character.  Required for when there
      // is a mixup in "midword".
      MB_PTR_ADV(mi.mi_end);
    } else if (mi.mi_result == SP_BAD
               && LANGP_ENTRY(wp->w_s->b_langp, 0)->lp_slang->sl_nobreak) {
      char_u      *p, *fp;
      int save_result = mi.mi_result;

      // First language in 'spelllang' is NOBREAK.  Find first position
      // at which any word would be valid.
      mi.mi_lp = LANGP_ENTRY(wp->w_s->b_langp, 0);
      if (mi.mi_lp->lp_slang->sl_fidxs != NULL) {
        p = mi.mi_word;
        fp = mi.mi_fword;
        for (;;) {
          MB_PTR_ADV(p);
          MB_PTR_ADV(fp);
          if (p >= mi.mi_end) {
            break;
          }
          mi.mi_compoff = (int)(fp - mi.mi_fword);
          find_word(&mi, FIND_COMPOUND);
          if (mi.mi_result != SP_BAD) {
            mi.mi_end = p;
            break;
          }
        }
        mi.mi_result = save_result;
      }
    }

    if (mi.mi_result == SP_BAD || mi.mi_result == SP_BANNED) {
      *attrp = HLF_SPB;
    } else if (mi.mi_result == SP_RARE) {
      *attrp = HLF_SPR;
    } else {
      *attrp = HLF_SPL;
    }
  }

  if (wrongcaplen > 0 && (mi.mi_result == SP_OK || mi.mi_result == SP_RARE)) {
    // Report SpellCap only when the word isn't badly spelled.
    *attrp = HLF_SPC;
    return wrongcaplen;
  }

  return (size_t)(mi.mi_end - ptr);
}

// Check if the word at "mip->mi_word" is in the tree.
// When "mode" is FIND_FOLDWORD check in fold-case word tree.
// When "mode" is FIND_KEEPWORD check in keep-case word tree.
// When "mode" is FIND_PREFIX check for word after prefix in fold-case word
// tree.
//
// For a match mip->mi_result is updated.
static void find_word(matchinf_T *mip, int mode)
{
  int wlen = 0;
  int flen;
  char_u      *ptr;
  slang_T     *slang = mip->mi_lp->lp_slang;
  char_u      *byts;
  idx_T       *idxs;

  if (mode == FIND_KEEPWORD || mode == FIND_KEEPCOMPOUND) {
    // Check for word with matching case in keep-case tree.
    ptr = mip->mi_word;
    flen = 9999;                    // no case folding, always enough bytes
    byts = slang->sl_kbyts;
    idxs = slang->sl_kidxs;

    if (mode == FIND_KEEPCOMPOUND)
      // Skip over the previously found word(s).
      wlen += mip->mi_compoff;
  } else {
    // Check for case-folded in case-folded tree.
    ptr = mip->mi_fword;
    flen = mip->mi_fwordlen;        // available case-folded bytes
    byts = slang->sl_fbyts;
    idxs = slang->sl_fidxs;

    if (mode == FIND_PREFIX) {
      // Skip over the prefix.
      wlen = mip->mi_prefixlen;
      flen -= mip->mi_prefixlen;
    } else if (mode == FIND_COMPOUND) {
      // Skip over the previously found word(s).
      wlen = mip->mi_compoff;
      flen -= mip->mi_compoff;
    }

  }

  if (byts == NULL)
    return;                     // array is empty

  idx_T arridx = 0;
  int endlen[MAXWLEN];              // length at possible word endings
  idx_T endidx[MAXWLEN];            // possible word endings
  int endidxcnt = 0;
  int len;
  int c;

  // Repeat advancing in the tree until:
  // - there is a byte that doesn't match,
  // - we reach the end of the tree,
  // - or we reach the end of the line.
  for (;; ) {
    if (flen <= 0 && *mip->mi_fend != NUL)
      flen = fold_more(mip);

    len = byts[arridx++];

    // If the first possible byte is a zero the word could end here.
    // Remember this index, we first check for the longest word.
    if (byts[arridx] == 0) {
      if (endidxcnt == MAXWLEN) {
        // Must be a corrupted spell file.
        EMSG(_(e_format));
        return;
      }
      endlen[endidxcnt] = wlen;
      endidx[endidxcnt++] = arridx++;
      --len;

      // Skip over the zeros, there can be several flag/region
      // combinations.
      while (len > 0 && byts[arridx] == 0) {
        ++arridx;
        --len;
      }
      if (len == 0)
        break;              // no children, word must end here
    }

    // Stop looking at end of the line.
    if (ptr[wlen] == NUL)
      break;

    // Perform a binary search in the list of accepted bytes.
    c = ptr[wlen];
    if (c == TAB)           // <Tab> is handled like <Space>
      c = ' ';
    idx_T lo = arridx;
    idx_T hi = arridx + len - 1;
    while (lo < hi) {
      idx_T m = (lo + hi) / 2;
      if (byts[m] > c)
        hi = m - 1;
      else if (byts[m] < c)
        lo = m + 1;
      else {
        lo = hi = m;
        break;
      }
    }

    // Stop if there is no matching byte.
    if (hi < lo || byts[lo] != c)
      break;

    // Continue at the child (if there is one).
    arridx = idxs[lo];
    ++wlen;
    --flen;

    // One space in the good word may stand for several spaces in the
    // checked word.
    if (c == ' ') {
      for (;; ) {
        if (flen <= 0 && *mip->mi_fend != NUL)
          flen = fold_more(mip);
        if (ptr[wlen] != ' ' && ptr[wlen] != TAB)
          break;
        ++wlen;
        --flen;
      }
    }
  }

  char_u *p;
  bool word_ends;

  // Verify that one of the possible endings is valid.  Try the longest
  // first.
  while (endidxcnt > 0) {
    --endidxcnt;
    arridx = endidx[endidxcnt];
    wlen = endlen[endidxcnt];

    if (utf_head_off(ptr, ptr + wlen) > 0) {
      continue;             // not at first byte of character
    }
    if (spell_iswordp(ptr + wlen, mip->mi_win)) {
      if (slang->sl_compprog == NULL && !slang->sl_nobreak)
        continue;                   // next char is a word character
      word_ends = false;
    } else
      word_ends = true;
    // The prefix flag is before compound flags.  Once a valid prefix flag
    // has been found we try compound flags.
    bool prefix_found = false;

    if (mode != FIND_KEEPWORD && has_mbyte) {
      // Compute byte length in original word, length may change
      // when folding case.  This can be slow, take a shortcut when the
      // case-folded word is equal to the keep-case word.
      p = mip->mi_word;
      if (STRNCMP(ptr, p, wlen) != 0) {
        for (char_u *s = ptr; s < ptr + wlen; MB_PTR_ADV(s)) {
          MB_PTR_ADV(p);
        }
        wlen = (int)(p - mip->mi_word);
      }
    }

    // Check flags and region.  For FIND_PREFIX check the condition and
    // prefix ID.
    // Repeat this if there are more flags/region alternatives until there
    // is a match.
    for (len = byts[arridx - 1]; len > 0 && byts[arridx] == 0;
         --len, ++arridx) {
      uint32_t flags = idxs[arridx];

      // For the fold-case tree check that the case of the checked word
      // matches with what the word in the tree requires.
      // For keep-case tree the case is always right.  For prefixes we
      // don't bother to check.
      if (mode == FIND_FOLDWORD) {
        if (mip->mi_cend != mip->mi_word + wlen) {
          // mi_capflags was set for a different word length, need
          // to do it again.
          mip->mi_cend = mip->mi_word + wlen;
          mip->mi_capflags = captype(mip->mi_word, mip->mi_cend);
        }

        if (mip->mi_capflags == WF_KEEPCAP
            || !spell_valid_case(mip->mi_capflags, flags))
          continue;
      }
      // When mode is FIND_PREFIX the word must support the prefix:
      // check the prefix ID and the condition.  Do that for the list at
      // mip->mi_prefarridx that find_prefix() filled.
      else if (mode == FIND_PREFIX && !prefix_found) {
        c = valid_word_prefix(mip->mi_prefcnt, mip->mi_prefarridx,
            flags,
            mip->mi_word + mip->mi_cprefixlen, slang,
            false);
        if (c == 0)
          continue;

        // Use the WF_RARE flag for a rare prefix.
        if (c & WF_RAREPFX)
          flags |= WF_RARE;
        prefix_found = true;
      }

      if (slang->sl_nobreak) {
        if ((mode == FIND_COMPOUND || mode == FIND_KEEPCOMPOUND)
            && (flags & WF_BANNED) == 0) {
          // NOBREAK: found a valid following word.  That's all we
          // need to know, so return.
          mip->mi_result = SP_OK;
          break;
        }
      } else if ((mode == FIND_COMPOUND || mode == FIND_KEEPCOMPOUND
                  || !word_ends)) {
        // If there is no compound flag or the word is shorter than
        // COMPOUNDMIN reject it quickly.
        // Makes you wonder why someone puts a compound flag on a word
        // that's too short...  Myspell compatibility requires this
        // anyway.
        if (((unsigned)flags >> 24) == 0
            || wlen - mip->mi_compoff < slang->sl_compminlen)
          continue;
        // For multi-byte chars check character length against
        // COMPOUNDMIN.
        if (has_mbyte
            && slang->sl_compminlen > 0
            && mb_charlen_len(mip->mi_word + mip->mi_compoff,
                wlen - mip->mi_compoff) < slang->sl_compminlen)
          continue;

        // Limit the number of compound words to COMPOUNDWORDMAX if no
        // maximum for syllables is specified.
        if (!word_ends && mip->mi_complen + mip->mi_compextra + 2
            > slang->sl_compmax
            && slang->sl_compsylmax == MAXWLEN)
          continue;

        // Don't allow compounding on a side where an affix was added,
        // unless COMPOUNDPERMITFLAG was used.
        if (mip->mi_complen > 0 && (flags & WF_NOCOMPBEF))
          continue;
        if (!word_ends && (flags & WF_NOCOMPAFT))
          continue;

        // Quickly check if compounding is possible with this flag.
        if (!byte_in_str(mip->mi_complen == 0
                ? slang->sl_compstartflags
                : slang->sl_compallflags,
                ((unsigned)flags >> 24)))
          continue;

        // If there is a match with a CHECKCOMPOUNDPATTERN rule
        // discard the compound word.
        if (match_checkcompoundpattern(ptr, wlen, &slang->sl_comppat))
          continue;

        if (mode == FIND_COMPOUND) {
          int capflags;

          // Need to check the caps type of the appended compound
          // word.
          if (has_mbyte && STRNCMP(ptr, mip->mi_word,
                  mip->mi_compoff) != 0) {
            // case folding may have changed the length
            p = mip->mi_word;
            for (char_u *s = ptr; s < ptr + mip->mi_compoff; MB_PTR_ADV(s)) {
              MB_PTR_ADV(p);
            }
          } else {
            p = mip->mi_word + mip->mi_compoff;
          }
          capflags = captype(p, mip->mi_word + wlen);
          if (capflags == WF_KEEPCAP || (capflags == WF_ALLCAP
                                         && (flags & WF_FIXCAP) != 0))
            continue;

          if (capflags != WF_ALLCAP) {
            // When the character before the word is a word
            // character we do not accept a Onecap word.  We do
            // accept a no-caps word, even when the dictionary
            // word specifies ONECAP.
            MB_PTR_BACK(mip->mi_word, p);
            if (spell_iswordp_nmw(p, mip->mi_win)
                ? capflags == WF_ONECAP
                : (flags & WF_ONECAP) != 0
                && capflags != WF_ONECAP) {
              continue;
            }
          }
        }

        // If the word ends the sequence of compound flags of the
        // words must match with one of the COMPOUNDRULE items and
        // the number of syllables must not be too large.
        mip->mi_compflags[mip->mi_complen] = ((unsigned)flags >> 24);
        mip->mi_compflags[mip->mi_complen + 1] = NUL;
        if (word_ends) {
          char_u fword[MAXWLEN];

          if (slang->sl_compsylmax < MAXWLEN) {
            // "fword" is only needed for checking syllables.
            if (ptr == mip->mi_word)
              (void)spell_casefold(ptr, wlen, fword, MAXWLEN);
            else
              STRLCPY(fword, ptr, endlen[endidxcnt] + 1);
          }
          if (!can_compound(slang, fword, mip->mi_compflags))
            continue;
        } else if (slang->sl_comprules != NULL
                   && !match_compoundrule(slang, mip->mi_compflags))
          // The compound flags collected so far do not match any
          // COMPOUNDRULE, discard the compounded word.
          continue;
      }
      // Check NEEDCOMPOUND: can't use word without compounding.
      else if (flags & WF_NEEDCOMP)
        continue;

      int nobreak_result = SP_OK;

      if (!word_ends) {
        int save_result = mip->mi_result;
        char_u  *save_end = mip->mi_end;
        langp_T *save_lp = mip->mi_lp;

        // Check that a valid word follows.  If there is one and we
        // are compounding, it will set "mi_result", thus we are
        // always finished here.  For NOBREAK we only check that a
        // valid word follows.
        // Recursive!
        if (slang->sl_nobreak)
          mip->mi_result = SP_BAD;

        // Find following word in case-folded tree.
        mip->mi_compoff = endlen[endidxcnt];
        if (has_mbyte && mode == FIND_KEEPWORD) {
          // Compute byte length in case-folded word from "wlen":
          // byte length in keep-case word.  Length may change when
          // folding case.  This can be slow, take a shortcut when
          // the case-folded word is equal to the keep-case word.
          p = mip->mi_fword;
          if (STRNCMP(ptr, p, wlen) != 0) {
            for (char_u *s = ptr; s < ptr + wlen; MB_PTR_ADV(s)) {
              MB_PTR_ADV(p);
            }
            mip->mi_compoff = (int)(p - mip->mi_fword);
          }
        }
#if 0
        c = mip->mi_compoff;
#endif
        ++mip->mi_complen;
        if (flags & WF_COMPROOT)
          ++mip->mi_compextra;

        // For NOBREAK we need to try all NOBREAK languages, at least
        // to find the ".add" file(s).
        for (int lpi = 0; lpi < mip->mi_win->w_s->b_langp.ga_len; ++lpi) {
          if (slang->sl_nobreak) {
            mip->mi_lp = LANGP_ENTRY(mip->mi_win->w_s->b_langp, lpi);
            if (mip->mi_lp->lp_slang->sl_fidxs == NULL
                || !mip->mi_lp->lp_slang->sl_nobreak)
              continue;
          }

          find_word(mip, FIND_COMPOUND);

          // When NOBREAK any word that matches is OK.  Otherwise we
          // need to find the longest match, thus try with keep-case
          // and prefix too.
          if (!slang->sl_nobreak || mip->mi_result == SP_BAD) {
            // Find following word in keep-case tree.
            mip->mi_compoff = wlen;
            find_word(mip, FIND_KEEPCOMPOUND);

#if 0       // Disabled, a prefix must not appear halfway through a compound
            // word, unless the COMPOUNDPERMITFLAG is used, in which case it
            // can't be a postponed prefix.
            if (!slang->sl_nobreak || mip->mi_result == SP_BAD) {
              // Check for following word with prefix.
              mip->mi_compoff = c;
              find_prefix(mip, FIND_COMPOUND);
            }
#endif
          }

          if (!slang->sl_nobreak)
            break;
        }
        --mip->mi_complen;
        if (flags & WF_COMPROOT)
          --mip->mi_compextra;
        mip->mi_lp = save_lp;

        if (slang->sl_nobreak) {
          nobreak_result = mip->mi_result;
          mip->mi_result = save_result;
          mip->mi_end = save_end;
        } else {
          if (mip->mi_result == SP_OK)
            break;
          continue;
        }
      }

      int res = SP_BAD;
      if (flags & WF_BANNED)
        res = SP_BANNED;
      else if (flags & WF_REGION) {
        // Check region.
        if ((mip->mi_lp->lp_region & (flags >> 16)) != 0)
          res = SP_OK;
        else
          res = SP_LOCAL;
      } else if (flags & WF_RARE)
        res = SP_RARE;
      else
        res = SP_OK;

      // Always use the longest match and the best result.  For NOBREAK
      // we separately keep the longest match without a following good
      // word as a fall-back.
      if (nobreak_result == SP_BAD) {
        if (mip->mi_result2 > res) {
          mip->mi_result2 = res;
          mip->mi_end2 = mip->mi_word + wlen;
        } else if (mip->mi_result2 == res
                   && mip->mi_end2 < mip->mi_word + wlen)
          mip->mi_end2 = mip->mi_word + wlen;
      } else if (mip->mi_result > res) {
        mip->mi_result = res;
        mip->mi_end = mip->mi_word + wlen;
      } else if (mip->mi_result == res && mip->mi_end < mip->mi_word + wlen)
        mip->mi_end = mip->mi_word + wlen;

      if (mip->mi_result == SP_OK)
        break;
    }

    if (mip->mi_result == SP_OK)
      break;
  }
}

// Returns true if there is a match between the word ptr[wlen] and
// CHECKCOMPOUNDPATTERN rules, assuming that we will concatenate with another
// word.
// A match means that the first part of CHECKCOMPOUNDPATTERN matches at the
// end of ptr[wlen] and the second part matches after it.
static bool
match_checkcompoundpattern (
    char_u *ptr,
    int wlen,
    garray_T *gap      // &sl_comppat
)
{
  char_u      *p;
  int len;

  for (int i = 0; i + 1 < gap->ga_len; i += 2) {
    p = ((char_u **)gap->ga_data)[i + 1];
    if (STRNCMP(ptr + wlen, p, STRLEN(p)) == 0) {
      // Second part matches at start of following compound word, now
      // check if first part matches at end of previous word.
      p = ((char_u **)gap->ga_data)[i];
      len = (int)STRLEN(p);
      if (len <= wlen && STRNCMP(ptr + wlen - len, p, len) == 0)
        return true;
    }
  }
  return false;
}

// Returns true if "flags" is a valid sequence of compound flags and "word"
// does not have too many syllables.
static bool can_compound(slang_T *slang, char_u *word, char_u *flags)
{
  char_u uflags[MAXWLEN * 2];
  int i;
  char_u      *p;

  if (slang->sl_compprog == NULL)
    return false;
  if (enc_utf8) {
    // Need to convert the single byte flags to utf8 characters.
    p = uflags;
    for (i = 0; flags[i] != NUL; i++) {
      p += utf_char2bytes(flags[i], p);
    }
    *p = NUL;
    p = uflags;
  } else
    p = flags;
  if (!vim_regexec_prog(&slang->sl_compprog, false, p, 0))
    return false;

  // Count the number of syllables.  This may be slow, do it last.  If there
  // are too many syllables AND the number of compound words is above
  // COMPOUNDWORDMAX then compounding is not allowed.
  if (slang->sl_compsylmax < MAXWLEN
      && count_syllables(slang, word) > slang->sl_compsylmax)
    return (int)STRLEN(flags) < slang->sl_compmax;
  return true;
}

// Returns true when the sequence of flags in "compflags" plus "flag" can
// possibly form a valid compounded word.  This also checks the COMPOUNDRULE
// lines if they don't contain wildcards.
static bool can_be_compound(trystate_T *sp, slang_T *slang, char_u *compflags, int flag)
{
  // If the flag doesn't appear in sl_compstartflags or sl_compallflags
  // then it can't possibly compound.
  if (!byte_in_str(sp->ts_complen == sp->ts_compsplit
          ? slang->sl_compstartflags : slang->sl_compallflags, flag))
    return false;

  // If there are no wildcards, we can check if the flags collected so far
  // possibly can form a match with COMPOUNDRULE patterns.  This only
  // makes sense when we have two or more words.
  if (slang->sl_comprules != NULL && sp->ts_complen > sp->ts_compsplit) {
    compflags[sp->ts_complen] = flag;
    compflags[sp->ts_complen + 1] = NUL;
    bool v = match_compoundrule(slang, compflags + sp->ts_compsplit);
    compflags[sp->ts_complen] = NUL;
    return v;
  }

  return true;
}

// Returns true if the compound flags in compflags[] match the start of any
// compound rule.  This is used to stop trying a compound if the flags
// collected so far can't possibly match any compound rule.
// Caller must check that slang->sl_comprules is not NULL.
static bool match_compoundrule(slang_T *slang, char_u *compflags)
{
  char_u      *p;
  int i;
  int c;

  // loop over all the COMPOUNDRULE entries
  for (p = slang->sl_comprules; *p != NUL; ++p) {
    // loop over the flags in the compound word we have made, match
    // them against the current rule entry
    for (i = 0;; ++i) {
      c = compflags[i];
      if (c == NUL)
        // found a rule that matches for the flags we have so far
        return true;
      if (*p == '/' || *p == NUL)
        break;          // end of rule, it's too short
      if (*p == '[') {
        bool match = false;

        // compare against all the flags in []
        ++p;
        while (*p != ']' && *p != NUL)
          if (*p++ == c)
            match = true;
        if (!match)
          break;            // none matches
      } else if (*p != c)
        break;          // flag of word doesn't match flag in pattern
      ++p;
    }

    // Skip to the next "/", where the next pattern starts.
    p = vim_strchr(p, '/');
    if (p == NULL)
      break;
  }

  // Checked all the rules and none of them match the flags, so there
  // can't possibly be a compound starting with these flags.
  return false;
}

// Return non-zero if the prefix indicated by "arridx" matches with the prefix
// ID in "flags" for the word "word".
// The WF_RAREPFX flag is included in the return value for a rare prefix.
static int
valid_word_prefix (
    int totprefcnt,                 // nr of prefix IDs
    int arridx,                     // idx in sl_pidxs[]
    int flags,
    char_u *word,
    slang_T *slang,
    bool cond_req                   // only use prefixes with a condition
)
{
  int prefcnt;
  int pidx;
  int prefid;

  prefid = (unsigned)flags >> 24;
  for (prefcnt = totprefcnt - 1; prefcnt >= 0; --prefcnt) {
    pidx = slang->sl_pidxs[arridx + prefcnt];

    // Check the prefix ID.
    if (prefid != (pidx & 0xff))
      continue;

    // Check if the prefix doesn't combine and the word already has a
    // suffix.
    if ((flags & WF_HAS_AFF) && (pidx & WF_PFX_NC))
      continue;

    // Check the condition, if there is one.  The condition index is
    // stored in the two bytes above the prefix ID byte.
    regprog_T **rp = &slang->sl_prefprog[((unsigned)pidx >> 8) & 0xffff];
    if (*rp != NULL) {
      if (!vim_regexec_prog(rp, false, word, 0)) {
        continue;
      }
    } else if (cond_req)
      continue;

    // It's a match!  Return the WF_ flags.
    return pidx;
  }
  return 0;
}

// Check if the word at "mip->mi_word" has a matching prefix.
// If it does, then check the following word.
//
// If "mode" is "FIND_COMPOUND" then do the same after another word, find a
// prefix in a compound word.
//
// For a match mip->mi_result is updated.
static void find_prefix(matchinf_T *mip, int mode)
{
  idx_T arridx = 0;
  int len;
  int wlen = 0;
  int flen;
  int c;
  char_u      *ptr;
  idx_T lo, hi, m;
  slang_T     *slang = mip->mi_lp->lp_slang;
  char_u      *byts;
  idx_T       *idxs;

  byts = slang->sl_pbyts;
  if (byts == NULL)
    return;                     // array is empty

  // We use the case-folded word here, since prefixes are always
  // case-folded.
  ptr = mip->mi_fword;
  flen = mip->mi_fwordlen;      // available case-folded bytes
  if (mode == FIND_COMPOUND) {
    // Skip over the previously found word(s).
    ptr += mip->mi_compoff;
    flen -= mip->mi_compoff;
  }
  idxs = slang->sl_pidxs;

  // Repeat advancing in the tree until:
  // - there is a byte that doesn't match,
  // - we reach the end of the tree,
  // - or we reach the end of the line.
  for (;; ) {
    if (flen == 0 && *mip->mi_fend != NUL)
      flen = fold_more(mip);

    len = byts[arridx++];

    // If the first possible byte is a zero the prefix could end here.
    // Check if the following word matches and supports the prefix.
    if (byts[arridx] == 0) {
      // There can be several prefixes with different conditions.  We
      // try them all, since we don't know which one will give the
      // longest match.  The word is the same each time, pass the list
      // of possible prefixes to find_word().
      mip->mi_prefarridx = arridx;
      mip->mi_prefcnt = len;
      while (len > 0 && byts[arridx] == 0) {
        ++arridx;
        --len;
      }
      mip->mi_prefcnt -= len;

      // Find the word that comes after the prefix.
      mip->mi_prefixlen = wlen;
      if (mode == FIND_COMPOUND)
        // Skip over the previously found word(s).
        mip->mi_prefixlen += mip->mi_compoff;

      if (has_mbyte) {
        // Case-folded length may differ from original length.
        mip->mi_cprefixlen = nofold_len(mip->mi_fword,
            mip->mi_prefixlen, mip->mi_word);
      } else
        mip->mi_cprefixlen = mip->mi_prefixlen;
      find_word(mip, FIND_PREFIX);


      if (len == 0)
        break;              // no children, word must end here
    }

    // Stop looking at end of the line.
    if (ptr[wlen] == NUL)
      break;

    // Perform a binary search in the list of accepted bytes.
    c = ptr[wlen];
    lo = arridx;
    hi = arridx + len - 1;
    while (lo < hi) {
      m = (lo + hi) / 2;
      if (byts[m] > c)
        hi = m - 1;
      else if (byts[m] < c)
        lo = m + 1;
      else {
        lo = hi = m;
        break;
      }
    }

    // Stop if there is no matching byte.
    if (hi < lo || byts[lo] != c)
      break;

    // Continue at the child (if there is one).
    arridx = idxs[lo];
    ++wlen;
    --flen;
  }
}

// Need to fold at least one more character.  Do until next non-word character
// for efficiency.  Include the non-word character too.
// Return the length of the folded chars in bytes.
static int fold_more(matchinf_T *mip)
{
  int flen;
  char_u      *p;

  p = mip->mi_fend;
  do {
    MB_PTR_ADV(mip->mi_fend);
  } while (*mip->mi_fend != NUL && spell_iswordp(mip->mi_fend, mip->mi_win));

  // Include the non-word character so that we can check for the word end.
  if (*mip->mi_fend != NUL) {
    MB_PTR_ADV(mip->mi_fend);
  }

  (void)spell_casefold(p, (int)(mip->mi_fend - p),
      mip->mi_fword + mip->mi_fwordlen,
      MAXWLEN - mip->mi_fwordlen);
  flen = (int)STRLEN(mip->mi_fword + mip->mi_fwordlen);
  mip->mi_fwordlen += flen;
  return flen;
}

/// Checks case flags for a word. Returns true, if the word has the requested
/// case.
///
/// @param wordflags Flags for the checked word.
/// @param treeflags Flags for the word in the spell tree.
static bool spell_valid_case(int wordflags, int treeflags)
{
  return (wordflags == WF_ALLCAP && (treeflags & WF_FIXCAP) == 0)
         || ((treeflags & (WF_ALLCAP | WF_KEEPCAP)) == 0
             && ((treeflags & WF_ONECAP) == 0
                 || (wordflags & WF_ONECAP) != 0));
}

// Returns true if spell checking is not enabled.
static bool no_spell_checking(win_T *wp)
{
  if (!wp->w_p_spell || *wp->w_s->b_p_spl == NUL
      || GA_EMPTY(&wp->w_s->b_langp)) {
    EMSG(_("E756: Spell checking is not enabled"));
    return true;
  }
  return false;
}

// Moves to the next spell error.
// "curline" is false for "[s", "]s", "[S" and "]S".
// "curline" is true to find word under/after cursor in the same line.
// For Insert mode completion "dir" is BACKWARD and "curline" is true: move
// to after badly spelled word before the cursor.
// Return 0 if not found, length of the badly spelled word otherwise.
size_t
spell_move_to (
    win_T *wp,
    int dir,                  // FORWARD or BACKWARD
    bool allwords,            // true for "[s"/"]s", false for "[S"/"]S"
    bool curline,
    hlf_T *attrp              // return: attributes of bad word or NULL
                              // (only when "dir" is FORWARD)
)
{
  linenr_T lnum;
  pos_T found_pos;
  size_t found_len = 0;
  char_u      *line;
  char_u      *p;
  char_u      *endp;
  hlf_T attr = HLF_COUNT;
  size_t len;
  int has_syntax = syntax_present(wp);
  int col;
  bool can_spell;
  char_u      *buf = NULL;
  size_t buflen = 0;
  int skip = 0;
  int capcol = -1;
  bool found_one = false;
  bool wrapped = false;

  if (no_spell_checking(wp))
    return 0;

  // Start looking for bad word at the start of the line, because we can't
  // start halfway through a word, we don't know where it starts or ends.
  //
  // When searching backwards, we continue in the line to find the last
  // bad word (in the cursor line: before the cursor).
  //
  // We concatenate the start of the next line, so that wrapped words work
  // (e.g. "et<line-break>cetera").  Doesn't work when searching backwards
  // though...
  lnum = wp->w_cursor.lnum;
  clearpos(&found_pos);

  while (!got_int) {
    line = ml_get_buf(wp->w_buffer, lnum, FALSE);

    len = STRLEN(line);
    if (buflen < len + MAXWLEN + 2) {
      xfree(buf);
      buflen = len + MAXWLEN + 2;
      buf = xmalloc(buflen);
    }
    assert(buf && buflen >= len + MAXWLEN + 2);

    // In first line check first word for Capital.
    if (lnum == 1)
      capcol = 0;

    // For checking first word with a capital skip white space.
    if (capcol == 0) {
      capcol = (int)getwhitecols(line);
    } else if (curline && wp == curwin) {
      // For spellbadword(): check if first word needs a capital.
      col = (int)getwhitecols(line);
      if (check_need_cap(lnum, col)) {
        capcol = col;
      }

      // Need to get the line again, may have looked at the previous
      // one.
      line = ml_get_buf(wp->w_buffer, lnum, FALSE);
    }

    // Copy the line into "buf" and append the start of the next line if
    // possible.
    STRCPY(buf, line);
    if (lnum < wp->w_buffer->b_ml.ml_line_count)
      spell_cat_line(buf + STRLEN(buf),
                     ml_get_buf(wp->w_buffer, lnum + 1, FALSE),
                     MAXWLEN);
    p = buf + skip;
    endp = buf + len;
    while (p < endp) {
      // When searching backward don't search after the cursor.  Unless
      // we wrapped around the end of the buffer.
      if (dir == BACKWARD
          && lnum == wp->w_cursor.lnum
          && !wrapped
          && (colnr_T)(p - buf) >= wp->w_cursor.col)
        break;

      // start of word
      attr = HLF_COUNT;
      len = spell_check(wp, p, &attr, &capcol, false);

      if (attr != HLF_COUNT) {
        // We found a bad word.  Check the attribute.
        if (allwords || attr == HLF_SPB) {
          // When searching forward only accept a bad word after
          // the cursor.
          if (dir == BACKWARD
              || lnum != wp->w_cursor.lnum
              || wrapped
              || ((colnr_T)(curline
                            ? p - buf + (ptrdiff_t)len
                            : p - buf) > wp->w_cursor.col)) {
            if (has_syntax) {
              col = (int)(p - buf);
              (void)syn_get_id(wp, lnum, (colnr_T)col,
                  FALSE, &can_spell, FALSE);
              if (!can_spell)
                attr = HLF_COUNT;
            } else
              can_spell = true;

            if (can_spell) {
              found_one = true;
              found_pos.lnum = lnum;
              found_pos.col = (int)(p - buf);
              found_pos.coladd = 0;
              if (dir == FORWARD) {
                // No need to search further.
                wp->w_cursor = found_pos;
                xfree(buf);
                if (attrp != NULL)
                  *attrp = attr;
                return len;
              } else if (curline) {
                // Insert mode completion: put cursor after
                // the bad word.
                assert(len <= INT_MAX);
                found_pos.col += (int)len;
              }
              found_len = len;
            }
          } else
            found_one = true;
        }
      }

      // advance to character after the word
      p += len;
      assert(len <= INT_MAX);
      capcol -= (int)len;
    }

    if (dir == BACKWARD && found_pos.lnum != 0) {
      // Use the last match in the line (before the cursor).
      wp->w_cursor = found_pos;
      xfree(buf);
      return found_len;
    }

    if (curline) {
      break;            // only check cursor line
    }

    // If we are back at the starting line and searched it again there
    // is no match, give up.
    if (lnum == wp->w_cursor.lnum && wrapped) {
      break;
    }

    // Advance to next line.
    if (dir == BACKWARD) {
      if (lnum > 1) {
        lnum--;
      } else if (!p_ws) {
        break;              // at first line and 'nowrapscan'
      } else {
        // Wrap around to the end of the buffer.  May search the
        // starting line again and accept the last match.
        lnum = wp->w_buffer->b_ml.ml_line_count;
        wrapped = true;
        if (!shortmess(SHM_SEARCH))
          give_warning((char_u *)_(top_bot_msg), true);
      }
      capcol = -1;
    } else {
      if (lnum < wp->w_buffer->b_ml.ml_line_count)
        ++lnum;
      else if (!p_ws)
        break;              // at first line and 'nowrapscan'
      else {
        // Wrap around to the start of the buffer.  May search the
        // starting line again and accept the first match.
        lnum = 1;
        wrapped = true;
        if (!shortmess(SHM_SEARCH))
          give_warning((char_u *)_(bot_top_msg), true);
      }

      // If we are back at the starting line and there is no match then
      // give up.
      if (lnum == wp->w_cursor.lnum && !found_one) {
        break;
      }

      // Skip the characters at the start of the next line that were
      // included in a match crossing line boundaries.
      if (attr == HLF_COUNT)
        skip = (int)(p - endp);
      else
        skip = 0;

      // Capcol skips over the inserted space.
      --capcol;

      // But after empty line check first word in next line
      if (*skipwhite(line) == NUL)
        capcol = 0;
    }

    line_breakcheck();
  }

  xfree(buf);
  return 0;
}

// For spell checking: concatenate the start of the following line "line" into
// "buf", blanking-out special characters.  Copy less then "maxlen" bytes.
// Keep the blanks at the start of the next line, this is used in win_line()
// to skip those bytes if the word was OK.
void spell_cat_line(char_u *buf, char_u *line, int maxlen)
{
  char_u      *p;
  int n;

  p = skipwhite(line);
  while (vim_strchr((char_u *)"*#/\"\t", *p) != NULL)
    p = skipwhite(p + 1);

  if (*p != NUL) {
    // Only worth concatenating if there is something else than spaces to
    // concatenate.
    n = (int)(p - line) + 1;
    if (n < maxlen - 1) {
      memset(buf, ' ', n);
      STRLCPY(buf +  n, p, maxlen - n);
    }
  }
}

// Load word list(s) for "lang" from Vim spell file(s).
// "lang" must be the language without the region: e.g., "en".
static void spell_load_lang(char_u *lang)
{
  char_u fname_enc[85];
  int r;
  spelload_T sl;
  int round;

  // Copy the language name to pass it to spell_load_cb() as a cookie.
  // It's truncated when an error is detected.
  STRCPY(sl.sl_lang, lang);
  sl.sl_slang = NULL;
  sl.sl_nobreak = false;

  // We may retry when no spell file is found for the language, an
  // autocommand may load it then.
  for (round = 1; round <= 2; ++round) {
    // Find the first spell file for "lang" in 'runtimepath' and load it.
    vim_snprintf((char *)fname_enc, sizeof(fname_enc) - 5,
                 "spell/%s.%s.spl", lang, spell_enc());
    r = do_in_runtimepath(fname_enc, 0, spell_load_cb, &sl);

    if (r == FAIL && *sl.sl_lang != NUL) {
      // Try loading the ASCII version.
      vim_snprintf((char *)fname_enc, sizeof(fname_enc) - 5,
                   "spell/%s.ascii.spl", lang);
      r = do_in_runtimepath(fname_enc, 0, spell_load_cb, &sl);

      if (r == FAIL && *sl.sl_lang != NUL && round == 1
          && apply_autocmds(EVENT_SPELLFILEMISSING, lang,
              curbuf->b_fname, FALSE, curbuf))
        continue;
      break;
    }
    break;
  }

  if (r == FAIL) {
    if (starting) {
      // Prompt the user at VimEnter if spell files are missing. #3027
      // Plugins aren't loaded yet, so spellfile.vim cannot handle this case.
      char autocmd_buf[128] = { 0 };
      snprintf(autocmd_buf, sizeof(autocmd_buf),
               "autocmd VimEnter * call spellfile#LoadFile('%s')|set spell",
               lang);
      do_cmdline_cmd(autocmd_buf);
    } else {
      smsg(
        _("Warning: Cannot find word list \"%s.%s.spl\" or \"%s.ascii.spl\""),
        lang, spell_enc(), lang);
    }
  } else if (sl.sl_slang != NULL) {
    // At least one file was loaded, now load ALL the additions.
    STRCPY(fname_enc + STRLEN(fname_enc) - 3, "add.spl");
    do_in_runtimepath(fname_enc, DIP_ALL, spell_load_cb, &sl);
  }
}

// Return the encoding used for spell checking: Use 'encoding', except that we
// use "latin1" for "latin9".  And limit to 60 characters (just in case).
char_u *spell_enc(void)
{

  if (STRLEN(p_enc) < 60 && STRCMP(p_enc, "iso-8859-15") != 0)
    return p_enc;
  return (char_u *)"latin1";
}

// Get the name of the .spl file for the internal wordlist into
// "fname[MAXPATHL]".
static void int_wordlist_spl(char_u *fname)
{
  vim_snprintf((char *)fname, MAXPATHL, SPL_FNAME_TMPL,
      int_wordlist, spell_enc());
}

// Allocate a new slang_T for language "lang".  "lang" can be NULL.
// Caller must fill "sl_next".
slang_T *slang_alloc(char_u *lang)
{
  slang_T *lp = xcalloc(1, sizeof(slang_T));

  if (lang != NULL)
    lp->sl_name = vim_strsave(lang);
  ga_init(&lp->sl_rep, sizeof(fromto_T), 10);
  ga_init(&lp->sl_repsal, sizeof(fromto_T), 10);
  lp->sl_compmax = MAXWLEN;
  lp->sl_compsylmax = MAXWLEN;
  hash_init(&lp->sl_wordcount);

  return lp;
}

// Free the contents of an slang_T and the structure itself.
void slang_free(slang_T *lp)
{
  xfree(lp->sl_name);
  xfree(lp->sl_fname);
  slang_clear(lp);
  xfree(lp);
}

/// Frees a salitem_T
static void free_salitem(salitem_T *smp) {
  xfree(smp->sm_lead);
  // Don't free sm_oneof and sm_rules, they point into sm_lead.
  xfree(smp->sm_to);
  xfree(smp->sm_lead_w);
  xfree(smp->sm_oneof_w);
  xfree(smp->sm_to_w);
}

/// Frees a fromto_T
static void free_fromto(fromto_T *ftp) {
  xfree(ftp->ft_from);
  xfree(ftp->ft_to);
}

// Clear an slang_T so that the file can be reloaded.
void slang_clear(slang_T *lp)
{
  garray_T    *gap;

  XFREE_CLEAR(lp->sl_fbyts);
  XFREE_CLEAR(lp->sl_kbyts);
  XFREE_CLEAR(lp->sl_pbyts);

  XFREE_CLEAR(lp->sl_fidxs);
  XFREE_CLEAR(lp->sl_kidxs);
  XFREE_CLEAR(lp->sl_pidxs);

  GA_DEEP_CLEAR(&lp->sl_rep, fromto_T, free_fromto);
  GA_DEEP_CLEAR(&lp->sl_repsal, fromto_T, free_fromto);

  gap = &lp->sl_sal;
  if (lp->sl_sofo) {
    // "ga_len" is set to 1 without adding an item for latin1
    GA_DEEP_CLEAR_PTR(gap);
  } else {
    // SAL items: free salitem_T items
    GA_DEEP_CLEAR(gap, salitem_T, free_salitem);
  }

  for (int i = 0; i < lp->sl_prefixcnt; ++i) {
    vim_regfree(lp->sl_prefprog[i]);
  }
  lp->sl_prefixcnt = 0;
  XFREE_CLEAR(lp->sl_prefprog);
  XFREE_CLEAR(lp->sl_info);
  XFREE_CLEAR(lp->sl_midword);

  vim_regfree(lp->sl_compprog);
  lp->sl_compprog = NULL;
  XFREE_CLEAR(lp->sl_comprules);
  XFREE_CLEAR(lp->sl_compstartflags);
  XFREE_CLEAR(lp->sl_compallflags);

  XFREE_CLEAR(lp->sl_syllable);
  ga_clear(&lp->sl_syl_items);

  ga_clear_strings(&lp->sl_comppat);

  hash_clear_all(&lp->sl_wordcount, WC_KEY_OFF);
  hash_init(&lp->sl_wordcount);

  hash_clear_all(&lp->sl_map_hash, 0);

  // Clear info from .sug file.
  slang_clear_sug(lp);

  lp->sl_compmax = MAXWLEN;
  lp->sl_compminlen = 0;
  lp->sl_compsylmax = MAXWLEN;
  lp->sl_regions[0] = NUL;
}

// Clear the info from the .sug file in "lp".
void slang_clear_sug(slang_T *lp)
{
  XFREE_CLEAR(lp->sl_sbyts);
  XFREE_CLEAR(lp->sl_sidxs);
  close_spellbuf(lp->sl_sugbuf);
  lp->sl_sugbuf = NULL;
  lp->sl_sugloaded = false;
  lp->sl_sugtime = 0;
}

// Load one spell file and store the info into a slang_T.
// Invoked through do_in_runtimepath().
static void spell_load_cb(char_u *fname, void *cookie)
{
  spelload_T  *slp = (spelload_T *)cookie;
  slang_T     *slang;

  slang = spell_load_file(fname, slp->sl_lang, NULL, false);
  if (slang != NULL) {
    // When a previously loaded file has NOBREAK also use it for the
    // ".add" files.
    if (slp->sl_nobreak && slang->sl_add)
      slang->sl_nobreak = true;
    else if (slang->sl_nobreak)
      slp->sl_nobreak = true;

    slp->sl_slang = slang;
  }
}

/// Add a word to the hashtable of common words.
/// If it's already there then the counter is increased.
///
/// @param[in]  lp
/// @param[in]  word  added to common words hashtable
/// @param[in]  len  length of word or -1 for NUL terminated
/// @param[in]  count  1 to count once, 10 to init
void count_common_word(slang_T *lp, char_u *word, int len, int count)
{
  hash_T hash;
  hashitem_T  *hi;
  wordcount_T *wc;
  char_u buf[MAXWLEN];
  char_u      *p;

  if (len == -1)
    p = word;
  else {
    STRLCPY(buf, word, len + 1);
    p = buf;
  }

  hash = hash_hash(p);
  const size_t p_len = STRLEN(p);
  hi = hash_lookup(&lp->sl_wordcount, (const char *)p, p_len, hash);
  if (HASHITEM_EMPTY(hi)) {
    wc = xmalloc(sizeof(wordcount_T) + p_len);
    memcpy(wc->wc_word, p, p_len + 1);
    wc->wc_count = count;
    hash_add_item(&lp->sl_wordcount, hi, wc->wc_word, hash);
  } else {
    wc = HI2WC(hi);
    if ((wc->wc_count += count) < (unsigned)count)      // check for overflow
      wc->wc_count = MAXWORDCOUNT;
  }
}

// Adjust the score of common words.
static int
score_wordcount_adj (
    slang_T *slang,
    int score,
    char_u *word,
    bool split                  // word was split, less bonus
)
{
  hashitem_T  *hi;
  wordcount_T *wc;
  int bonus;
  int newscore;

  hi = hash_find(&slang->sl_wordcount, word);
  if (!HASHITEM_EMPTY(hi)) {
    wc = HI2WC(hi);
    if (wc->wc_count < SCORE_THRES2)
      bonus = SCORE_COMMON1;
    else if (wc->wc_count < SCORE_THRES3)
      bonus = SCORE_COMMON2;
    else
      bonus = SCORE_COMMON3;
    if (split)
      newscore = score - bonus / 2;
    else
      newscore = score - bonus;
    if (newscore < 0)
      return 0;
    return newscore;
  }
  return score;
}

// Returns true if byte "n" appears in "str".
// Like strchr() but independent of locale.
bool byte_in_str(char_u *str, int n)
{
  char_u      *p;

  for (p = str; *p != NUL; ++p)
    if (*p == n)
      return true;
  return false;
}

// Truncate "slang->sl_syllable" at the first slash and put the following items
// in "slang->sl_syl_items".
int init_syl_tab(slang_T *slang)
{
  char_u      *p;
  char_u      *s;
  int l;

  ga_init(&slang->sl_syl_items, sizeof(syl_item_T), 4);
  p = vim_strchr(slang->sl_syllable, '/');
  while (p != NULL) {
    *p++ = NUL;
    if (*p == NUL)          // trailing slash
      break;
    s = p;
    p = vim_strchr(p, '/');
    if (p == NULL)
      l = (int)STRLEN(s);
    else
      l = (int)(p - s);
    if (l >= SY_MAXLEN)
      return SP_FORMERROR;

    syl_item_T *syl = GA_APPEND_VIA_PTR(syl_item_T, &slang->sl_syl_items);
    STRLCPY(syl->sy_chars, s, l + 1);
    syl->sy_len = l;
  }
  return OK;
}

// Count the number of syllables in "word".
// When "word" contains spaces the syllables after the last space are counted.
// Returns zero if syllables are not defines.
static int count_syllables(slang_T *slang, char_u *word)
{
  int cnt = 0;
  bool skip = false;
  char_u      *p;
  int len;
  syl_item_T  *syl;
  int c;

  if (slang->sl_syllable == NULL)
    return 0;

  for (p = word; *p != NUL; p += len) {
    // When running into a space reset counter.
    if (*p == ' ') {
      len = 1;
      cnt = 0;
      continue;
    }

    // Find longest match of syllable items.
    len = 0;
    for (int i = 0; i < slang->sl_syl_items.ga_len; ++i) {
      syl = ((syl_item_T *)slang->sl_syl_items.ga_data) + i;
      if (syl->sy_len > len
          && STRNCMP(p, syl->sy_chars, syl->sy_len) == 0)
        len = syl->sy_len;
    }
    if (len != 0) {     // found a match, count syllable
      ++cnt;
      skip = false;
    } else {
      // No recognized syllable item, at least a syllable char then?
      c = utf_ptr2char(p);
      len = (*mb_ptr2len)(p);
      if (vim_strchr(slang->sl_syllable, c) == NULL)
        skip = false;               // No, search for next syllable
      else if (!skip) {
        ++cnt;                      // Yes, count it
        skip = true;                // don't count following syllable chars
      }
    }
  }
  return cnt;
}

// Parse 'spelllang' and set w_s->b_langp accordingly.
// Returns NULL if it's OK, an error message otherwise.
char_u *did_set_spelllang(win_T *wp)
{
  garray_T ga;
  char_u      *splp;
  char_u      *region;
  char_u region_cp[3];
  bool filename;
  int region_mask;
  slang_T     *slang;
  int c;
  char_u lang[MAXWLEN + 1];
  char_u spf_name[MAXPATHL];
  int len;
  char_u      *p;
  int round;
  char_u      *spf;
  char_u      *use_region = NULL;
  bool dont_use_region = false;
  bool nobreak = false;
  langp_T     *lp, *lp2;
  static bool recursive = false;
  char_u      *ret_msg = NULL;
  char_u      *spl_copy;

  bufref_T bufref;
  set_bufref(&bufref, wp->w_buffer);

  // We don't want to do this recursively.  May happen when a language is
  // not available and the SpellFileMissing autocommand opens a new buffer
  // in which 'spell' is set.
  if (recursive)
    return NULL;
  recursive = true;

  ga_init(&ga, sizeof(langp_T), 2);
  clear_midword(wp);

  // Make a copy of 'spelllang', the SpellFileMissing autocommands may change
  // it under our fingers.
  spl_copy = vim_strsave(wp->w_s->b_p_spl);

  wp->w_s->b_cjk = 0;

  // Loop over comma separated language names.
  for (splp = spl_copy; *splp != NUL; ) {
    // Get one language name.
    copy_option_part(&splp, lang, MAXWLEN, ",");
    region = NULL;
    len = (int)STRLEN(lang);

    if (STRCMP(lang, "cjk") == 0) {
      wp->w_s->b_cjk = 1;
      continue;
    }

    // If the name ends in ".spl" use it as the name of the spell file.
    // If there is a region name let "region" point to it and remove it
    // from the name.
    if (len > 4 && fnamecmp(lang + len - 4, ".spl") == 0) {
      filename = true;

      // Locate a region and remove it from the file name.
      p = vim_strchr(path_tail(lang), '_');
      if (p != NULL && ASCII_ISALPHA(p[1]) && ASCII_ISALPHA(p[2])
          && !ASCII_ISALPHA(p[3])) {
        STRLCPY(region_cp, p + 1, 3);
        memmove(p, p + 3, len - (p - lang) - 2);
        region = region_cp;
      } else
        dont_use_region = true;

      // Check if we loaded this language before.
      for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
        if (path_full_compare(lang, slang->sl_fname, false) == kEqualFiles) {
          break;
        }
      }
    } else {
      filename = false;
      if (len > 3 && lang[len - 3] == '_') {
        region = lang + len - 2;
        lang[len - 3] = NUL;
      } else
        dont_use_region = true;

      // Check if we loaded this language before.
      for (slang = first_lang; slang != NULL; slang = slang->sl_next)
        if (STRICMP(lang, slang->sl_name) == 0)
          break;
    }

    if (region != NULL) {
      // If the region differs from what was used before then don't
      // use it for 'spellfile'.
      if (use_region != NULL && STRCMP(region, use_region) != 0)
        dont_use_region = true;
      use_region = region;
    }

    // If not found try loading the language now.
    if (slang == NULL) {
      if (filename)
        (void)spell_load_file(lang, lang, NULL, false);
      else {
        spell_load_lang(lang);
        // SpellFileMissing autocommands may do anything, including
        // destroying the buffer we are using...
        if (!bufref_valid(&bufref)) {
          ret_msg =
            (char_u *)N_("E797: SpellFileMissing autocommand deleted buffer");
          goto theend;
        }
      }
    }

    // Loop over the languages, there can be several files for "lang".
    for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
      if (filename
          ? path_full_compare(lang, slang->sl_fname, false) == kEqualFiles
          : STRICMP(lang, slang->sl_name) == 0) {
        region_mask = REGION_ALL;
        if (!filename && region != NULL) {
          // find region in sl_regions
          c = find_region(slang->sl_regions, region);
          if (c == REGION_ALL) {
            if (slang->sl_add) {
              if (*slang->sl_regions != NUL)
                // This addition file is for other regions.
                region_mask = 0;
            } else
              // This is probably an error.  Give a warning and
              // accept the words anyway.
              smsg(_("Warning: region %s not supported"),
                   region);
          } else
            region_mask = 1 << c;
        }

        if (region_mask != 0) {
          langp_T *p_ = GA_APPEND_VIA_PTR(langp_T, &ga);
          p_->lp_slang = slang;
          p_->lp_region = region_mask;

          use_midword(slang, wp);
          if (slang->sl_nobreak)
            nobreak = true;
        }
      }
    }
  }

  // round 0: load int_wordlist, if possible.
  // round 1: load first name in 'spellfile'.
  // round 2: load second name in 'spellfile.
  // etc.
  spf = curwin->w_s->b_p_spf;
  for (round = 0; round == 0 || *spf != NUL; ++round) {
    if (round == 0) {
      // Internal wordlist, if there is one.
      if (int_wordlist == NULL)
        continue;
      int_wordlist_spl(spf_name);
    } else {
      // One entry in 'spellfile'.
      copy_option_part(&spf, spf_name, MAXPATHL - 5, ",");
      STRCAT(spf_name, ".spl");

      // If it was already found above then skip it.
      for (c = 0; c < ga.ga_len; ++c) {
        p = LANGP_ENTRY(ga, c)->lp_slang->sl_fname;
        if (p != NULL
            && path_full_compare(spf_name, p, false) == kEqualFiles) {
          break;
        }
      }
      if (c < ga.ga_len)
        continue;
    }

    // Check if it was loaded already.
    for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
      if (path_full_compare(spf_name, slang->sl_fname, false) == kEqualFiles) {
        break;
      }
    }
    if (slang == NULL) {
      // Not loaded, try loading it now.  The language name includes the
      // region name, the region is ignored otherwise.  for int_wordlist
      // use an arbitrary name.
      if (round == 0)
        STRCPY(lang, "internal wordlist");
      else {
        STRLCPY(lang, path_tail(spf_name), MAXWLEN + 1);
        p = vim_strchr(lang, '.');
        if (p != NULL)
          *p = NUL;             // truncate at ".encoding.add"
      }
      slang = spell_load_file(spf_name, lang, NULL, true);

      // If one of the languages has NOBREAK we assume the addition
      // files also have this.
      if (slang != NULL && nobreak)
        slang->sl_nobreak = true;
    }
    if (slang != NULL) {
      region_mask = REGION_ALL;
      if (use_region != NULL && !dont_use_region) {
        // find region in sl_regions
        c = find_region(slang->sl_regions, use_region);
        if (c != REGION_ALL)
          region_mask = 1 << c;
        else if (*slang->sl_regions != NUL)
          // This spell file is for other regions.
          region_mask = 0;
      }

      if (region_mask != 0) {
        langp_T *p_ = GA_APPEND_VIA_PTR(langp_T, &ga);
        p_->lp_slang = slang;
        p_->lp_sallang = NULL;
        p_->lp_replang = NULL;
        p_->lp_region = region_mask;

        use_midword(slang, wp);
      }
    }
  }

  // Everything is fine, store the new b_langp value.
  ga_clear(&wp->w_s->b_langp);
  wp->w_s->b_langp = ga;

  // For each language figure out what language to use for sound folding and
  // REP items.  If the language doesn't support it itself use another one
  // with the same name.  E.g. for "en-math" use "en".
  for (int i = 0; i < ga.ga_len; ++i) {
    lp = LANGP_ENTRY(ga, i);

    // sound folding
    if (!GA_EMPTY(&lp->lp_slang->sl_sal))
      // language does sound folding itself
      lp->lp_sallang = lp->lp_slang;
    else
      // find first similar language that does sound folding
      for (int j = 0; j < ga.ga_len; ++j) {
        lp2 = LANGP_ENTRY(ga, j);
        if (!GA_EMPTY(&lp2->lp_slang->sl_sal)
            && STRNCMP(lp->lp_slang->sl_name,
                lp2->lp_slang->sl_name, 2) == 0) {
          lp->lp_sallang = lp2->lp_slang;
          break;
        }
      }

    // REP items
    if (!GA_EMPTY(&lp->lp_slang->sl_rep))
      // language has REP items itself
      lp->lp_replang = lp->lp_slang;
    else
      // find first similar language that has REP items
      for (int j = 0; j < ga.ga_len; ++j) {
        lp2 = LANGP_ENTRY(ga, j);
        if (!GA_EMPTY(&lp2->lp_slang->sl_rep)
            && STRNCMP(lp->lp_slang->sl_name,
                lp2->lp_slang->sl_name, 2) == 0) {
          lp->lp_replang = lp2->lp_slang;
          break;
        }
      }
  }

theend:
  xfree(spl_copy);
  recursive = false;
  redraw_win_later(wp, NOT_VALID);
  return ret_msg;
}

// Clear the midword characters for buffer "buf".
static void clear_midword(win_T *wp)
{
  memset(wp->w_s->b_spell_ismw, 0, 256);
  XFREE_CLEAR(wp->w_s->b_spell_ismw_mb);
}

// Use the "sl_midword" field of language "lp" for buffer "buf".
// They add up to any currently used midword characters.
static void use_midword(slang_T *lp, win_T *wp)
{
  char_u      *p;

  if (lp->sl_midword == NULL)       // there aren't any
    return;

  for (p = lp->sl_midword; *p != NUL; )
    if (has_mbyte) {
      int c, l, n;
      char_u  *bp;

      c = utf_ptr2char(p);
      l = (*mb_ptr2len)(p);
      if (c < 256 && l <= 2)
        wp->w_s->b_spell_ismw[c] = true;
      else if (wp->w_s->b_spell_ismw_mb == NULL)
        // First multi-byte char in "b_spell_ismw_mb".
        wp->w_s->b_spell_ismw_mb = vim_strnsave(p, l);
      else {
        // Append multi-byte chars to "b_spell_ismw_mb".
        n = (int)STRLEN(wp->w_s->b_spell_ismw_mb);
        bp = vim_strnsave(wp->w_s->b_spell_ismw_mb, n + l);
        xfree(wp->w_s->b_spell_ismw_mb);
        wp->w_s->b_spell_ismw_mb = bp;
        STRLCPY(bp + n, p, l + 1);
      }
      p += l;
    } else
      wp->w_s->b_spell_ismw[*p++] = true;
}

// Find the region "region[2]" in "rp" (points to "sl_regions").
// Each region is simply stored as the two characters of its name.
// Returns the index if found (first is 0), REGION_ALL if not found.
static int find_region(char_u *rp, char_u *region)
{
  int i;

  for (i = 0;; i += 2) {
    if (rp[i] == NUL)
      return REGION_ALL;
    if (rp[i] == region[0] && rp[i + 1] == region[1])
      break;
  }
  return i / 2;
}

/// Return case type of word:
/// w word       0
/// Word         WF_ONECAP
/// W WORD       WF_ALLCAP
/// WoRd wOrd    WF_KEEPCAP
///
/// @param[in]  word
/// @param[in]  end  End of word or NULL for NUL delimited string
///
/// @returns  Case type of word
int captype(char_u *word, char_u *end)
{
  char_u      *p;
  int c;
  int firstcap;
  bool allcap;
  bool past_second = false;              // past second word char

  // find first letter
  for (p = word; !spell_iswordp_nmw(p, curwin); MB_PTR_ADV(p)) {
    if (end == NULL ? *p == NUL : p >= end) {
      return 0;             // only non-word characters, illegal word
    }
  }
  if (has_mbyte) {
    c = mb_ptr2char_adv((const char_u **)&p);
  } else {
    c = *p++;
  }
  firstcap = allcap = SPELL_ISUPPER(c);

  // Need to check all letters to find a word with mixed upper/lower.
  // But a word with an upper char only at start is a ONECAP.
  for (; end == NULL ? *p != NUL : p < end; MB_PTR_ADV(p)) {
    if (spell_iswordp_nmw(p, curwin)) {
      c = PTR2CHAR(p);
      if (!SPELL_ISUPPER(c)) {
        // UUl -> KEEPCAP
        if (past_second && allcap) {
          return WF_KEEPCAP;
        }
        allcap = false;
      } else if (!allcap) {
        // UlU -> KEEPCAP
        return WF_KEEPCAP;
      }
      past_second = true;
    }
  }

  if (allcap)
    return WF_ALLCAP;
  if (firstcap)
    return WF_ONECAP;
  return 0;
}

// Like captype() but for a KEEPCAP word add ONECAP if the word starts with a
// capital.  So that make_case_word() can turn WOrd into Word.
// Add ALLCAP for "WOrD".
static int badword_captype(char_u *word, char_u *end)
{
  int flags = captype(word, end);
  int c;
  int l, u;
  bool first;
  char_u      *p;

  if (flags & WF_KEEPCAP) {
    // Count the number of UPPER and lower case letters.
    l = u = 0;
    first = false;
    for (p = word; p < end; MB_PTR_ADV(p)) {
      c = PTR2CHAR(p);
      if (SPELL_ISUPPER(c)) {
        ++u;
        if (p == word)
          first = true;
      } else
        ++l;
    }

    // If there are more UPPER than lower case letters suggest an
    // ALLCAP word.  Otherwise, if the first letter is UPPER then
    // suggest ONECAP.  Exception: "ALl" most likely should be "All",
    // require three upper case letters.
    if (u > l && u > 2)
      flags |= WF_ALLCAP;
    else if (first)
      flags |= WF_ONECAP;

    if (u >= 2 && l >= 2)       // maCARONI maCAroni
      flags |= WF_MIXCAP;
  }
  return flags;
}

// Delete the internal wordlist and its .spl file.
void spell_delete_wordlist(void)
{
  char_u fname[MAXPATHL] = {0};

  if (int_wordlist != NULL) {
    os_remove((char *)int_wordlist);
    int_wordlist_spl(fname);
    os_remove((char *)fname);
    XFREE_CLEAR(int_wordlist);
  }
}

// Free all languages.
void spell_free_all(void)
{
  slang_T     *slang;

  // Go through all buffers and handle 'spelllang'. <VN>
  FOR_ALL_BUFFERS(buf) {
    ga_clear(&buf->b_s.b_langp);
  }

  while (first_lang != NULL) {
    slang = first_lang;
    first_lang = slang->sl_next;
    slang_free(slang);
  }

  spell_delete_wordlist();

  XFREE_CLEAR(repl_to);
  XFREE_CLEAR(repl_from);
}

// Clear all spelling tables and reload them.
// Used after 'encoding' is set and when ":mkspell" was used.
void spell_reload(void)
{
  // Initialize the table for spell_iswordp().
  init_spell_chartab();

  // Unload all allocated memory.
  spell_free_all();

  // Go through all buffers and handle 'spelllang'.
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    // Only load the wordlists when 'spelllang' is set and there is a
    // window for this buffer in which 'spell' is set.
    if (*wp->w_s->b_p_spl != NUL) {
      if (wp->w_p_spell) {
        (void)did_set_spelllang(wp);
        break;
      }
    }
  }
}


// Opposite of offset2bytes().
// "pp" points to the bytes and is advanced over it.
// Returns the offset.
static int bytes2offset(char_u **pp)
{
  char_u *p = *pp;
  int nr;
  int c;

  c = *p++;
  if ((c & 0x80) == 0x00) {             // 1 byte
    nr = c - 1;
  } else if ((c & 0xc0) == 0x80)   {    // 2 bytes
    nr = (c & 0x3f) - 1;
    nr = nr * 255 + (*p++ - 1);
  } else if ((c & 0xe0) == 0xc0)   {    // 3 bytes
    nr = (c & 0x1f) - 1;
    nr = nr * 255 + (*p++ - 1);
    nr = nr * 255 + (*p++ - 1);
  } else {                              // 4 bytes
    nr = (c & 0x0f) - 1;
    nr = nr * 255 + (*p++ - 1);
    nr = nr * 255 + (*p++ - 1);
    nr = nr * 255 + (*p++ - 1);
  }

  *pp = p;
  return nr;
}

// Open a spell buffer.  This is a nameless buffer that is not in the buffer
// list and only contains text lines.  Can use a swapfile to reduce memory
// use.
// Most other fields are invalid!  Esp. watch out for string options being
// NULL and there is no undo info.
buf_T *open_spellbuf(void)
{
  buf_T *buf = xcalloc(1, sizeof(buf_T));

  buf->b_spell = true;
  buf->b_p_swf = true;        // may create a swap file
  if (ml_open(buf) == FAIL) {
    ELOG("Error opening a new memline");
  }
  ml_open_file(buf);          // create swap file now

  return buf;
}

// Close the buffer used for spell info.
void close_spellbuf(buf_T *buf)
{
  if (buf != NULL) {
    ml_close(buf, TRUE);
    xfree(buf);
  }
}

// Init the chartab used for spelling for ASCII.
void clear_spell_chartab(spelltab_T *sp)
{
  int i;

  // Init everything to false.
  memset(sp->st_isw, false, sizeof(sp->st_isw));
  memset(sp->st_isu, false, sizeof(sp->st_isu));

  for (i = 0; i < 256; ++i) {
    sp->st_fold[i] = i;
    sp->st_upper[i] = i;
  }

  // We include digits. A word shouldn't start with a digit, but handling
  // that is done separately.
  for (i = '0'; i <= '9'; ++i)
    sp->st_isw[i] = true;
  for (i = 'A'; i <= 'Z'; ++i) {
    sp->st_isw[i] = true;
    sp->st_isu[i] = true;
    sp->st_fold[i] = i + 0x20;
  }
  for (i = 'a'; i <= 'z'; ++i) {
    sp->st_isw[i] = true;
    sp->st_upper[i] = i - 0x20;
  }
}

// Init the chartab used for spelling. Called once while starting up.
// The default is to use isalpha(), but the spell file should define the word
// characters to make it possible that 'encoding' differs from the current
// locale.  For utf-8 we don't use isalpha() but our own functions.
void init_spell_chartab(void)
{
  int i;

  did_set_spelltab = false;
  clear_spell_chartab(&spelltab);
  for (i = 128; i < 256; i++) {
    int f = utf_fold(i);
    int u = mb_toupper(i);

    spelltab.st_isu[i] = mb_isupper(i);
    spelltab.st_isw[i] = spelltab.st_isu[i] || mb_islower(i);
    // The folded/upper-cased value is different between latin1 and
    // utf8 for 0xb5, causing E763 for no good reason.  Use the latin1
    // value for utf-8 to avoid this.
    spelltab.st_fold[i] = (f < 256) ? f : i;
    spelltab.st_upper[i] = (u < 256) ? u : i;
  }
}

/// Returns true if "p" points to a word character.
/// As a special case we see "midword" characters as word character when it is
/// followed by a word character.  This finds they'there but not 'they there'.
/// Thus this only works properly when past the first character of the word.
///
/// @param wp Buffer used.
static bool spell_iswordp(char_u *p, win_T *wp)
{
  char_u *s;
  int l;
  int c;

  if (has_mbyte) {
    l = MB_PTR2LEN(p);
    s = p;
    if (l == 1) {
      // be quick for ASCII
      if (wp->w_s->b_spell_ismw[*p])
        s = p + 1;                      // skip a mid-word character
    } else {
      c = utf_ptr2char(p);
      if (c < 256 ? wp->w_s->b_spell_ismw[c]
          : (wp->w_s->b_spell_ismw_mb != NULL
             && vim_strchr(wp->w_s->b_spell_ismw_mb, c) != NULL)) {
        s = p + l;
      }
    }

    c = utf_ptr2char(s);
    if (c > 255) {
      return spell_mb_isword_class(mb_get_class(s), wp);
    }
    return spelltab.st_isw[c];
  }

  return spelltab.st_isw[wp->w_s->b_spell_ismw[*p] ? p[1] : p[0]];
}

// Returns true if "p" points to a word character.
// Unlike spell_iswordp() this doesn't check for "midword" characters.
bool spell_iswordp_nmw(const char_u *p, win_T *wp)
{
  int c = utf_ptr2char(p);
  if (c > 255) {
    return spell_mb_isword_class(mb_get_class(p), wp);
  }
  return spelltab.st_isw[c];
}

// Returns true if word class indicates a word character.
// Only for characters above 255.
// Unicode subscript and superscript are not considered word characters.
// See also utf_class() in mbyte.c.
static bool spell_mb_isword_class(int cl, win_T *wp)
{
  if (wp->w_s->b_cjk)
    // East Asian characters are not considered word characters.
    return cl == 2 || cl == 0x2800;
  return cl >= 2 && cl != 0x2070 && cl != 0x2080 && cl != 3;
}

// Returns true if "p" points to a word character.
// Wide version of spell_iswordp().
static bool spell_iswordp_w(int *p, win_T *wp)
{
  int *s;

  if (*p < 256 ? wp->w_s->b_spell_ismw[*p]
      : (wp->w_s->b_spell_ismw_mb != NULL
         && vim_strchr(wp->w_s->b_spell_ismw_mb, *p) != NULL))
    s = p + 1;
  else
    s = p;

  if (*s > 255) {
    return spell_mb_isword_class(utf_class(*s), wp);
  }
  return spelltab.st_isw[*s];
}

// Case-fold "str[len]" into "buf[buflen]".  The result is NUL terminated.
// Uses the character definitions from the .spl file.
// When using a multi-byte 'encoding' the length may change!
// Returns FAIL when something wrong.
int spell_casefold(char_u *str, int len, char_u *buf, int buflen)
{
  int i;

  if (len >= buflen) {
    buf[0] = NUL;
    return FAIL;                // result will not fit
  }

  if (has_mbyte) {
    int outi = 0;
    char_u  *p;
    int c;

    // Fold one character at a time.
    for (p = str; p < str + len; ) {
      if (outi + MB_MAXBYTES > buflen) {
        buf[outi] = NUL;
        return FAIL;
      }
      c = mb_cptr2char_adv((const char_u **)&p);
      outi += utf_char2bytes(SPELL_TOFOLD(c), buf + outi);
    }
    buf[outi] = NUL;
  } else {
    // Be quick for non-multibyte encodings.
    for (i = 0; i < len; ++i)
      buf[i] = spelltab.st_fold[str[i]];
    buf[i] = NUL;
  }

  return OK;
}

// values for sps_flags
#define SPS_BEST    1
#define SPS_FAST    2
#define SPS_DOUBLE  4

static int sps_flags = SPS_BEST;        // flags from 'spellsuggest'
static int sps_limit = 9999;            // max nr of suggestions given

// Check the 'spellsuggest' option.  Return FAIL if it's wrong.
// Sets "sps_flags" and "sps_limit".
int spell_check_sps(void)
{
  char_u      *p;
  char_u      *s;
  char_u buf[MAXPATHL];
  int f;

  sps_flags = 0;
  sps_limit = 9999;

  for (p = p_sps; *p != NUL; ) {
    copy_option_part(&p, buf, MAXPATHL, ",");

    f = 0;
    if (ascii_isdigit(*buf)) {
      s = buf;
      sps_limit = getdigits_int(&s);
      if (*s != NUL && !ascii_isdigit(*s))
        f = -1;
    } else if (STRCMP(buf, "best") == 0)
      f = SPS_BEST;
    else if (STRCMP(buf, "fast") == 0)
      f = SPS_FAST;
    else if (STRCMP(buf, "double") == 0)
      f = SPS_DOUBLE;
    else if (STRNCMP(buf, "expr:", 5) != 0
             && STRNCMP(buf, "file:", 5) != 0)
      f = -1;

    if (f == -1 || (sps_flags != 0 && f != 0)) {
      sps_flags = SPS_BEST;
      sps_limit = 9999;
      return FAIL;
    }
    if (f != 0)
      sps_flags = f;
  }

  if (sps_flags == 0)
    sps_flags = SPS_BEST;

  return OK;
}

// "z=": Find badly spelled word under or after the cursor.
// Give suggestions for the properly spelled word.
// In Visual mode use the highlighted word as the bad word.
// When "count" is non-zero use that suggestion.
void spell_suggest(int count)
{
  char_u      *line;
  pos_T prev_cursor = curwin->w_cursor;
  char_u wcopy[MAXWLEN + 2];
  char_u      *p;
  int c;
  suginfo_T sug;
  suggest_T   *stp;
  int mouse_used;
  int need_cap;
  int limit;
  int selected = count;
  int badlen = 0;
  int msg_scroll_save = msg_scroll;

  if (no_spell_checking(curwin))
    return;

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
  } else
  // Find the start of the badly spelled word.
  if (spell_move_to(curwin, FORWARD, true, true, NULL) == 0
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
  line = vim_strsave(get_cursor_line_ptr());

  // Get the list of suggestions.  Limit to 'lines' - 2 or the number in
  // 'spellsuggest', whatever is smaller.
  if (sps_limit > (int)Rows - 2)
    limit = (int)Rows - 2;
  else
    limit = sps_limit;
  spell_find_suggest(line + curwin->w_cursor.col, badlen, &sug, limit,
      true, need_cap, true);

  if (GA_EMPTY(&sug.su_ga))
    MSG(_("Sorry, no suggestions"));
  else if (count > 0) {
    if (count > sug.su_ga.ga_len)
      smsg(_("Sorry, only %" PRId64 " suggestions"),
           (int64_t)sug.su_ga.ga_len);
  } else {
    XFREE_CLEAR(repl_from);
    XFREE_CLEAR(repl_to);

    // When 'rightleft' is set the list is drawn right-left.
    cmdmsg_rl = curwin->w_p_rl;
    if (cmdmsg_rl)
      msg_col = Columns - 1;

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

    msg_scroll = TRUE;
    for (int i = 0; i < sug.su_ga.ga_len; ++i) {
      stp = &SUG(sug.su_ga, i);

      // The suggested word may replace only part of the bad word, add
      // the not replaced part.
      STRLCPY(wcopy, stp->st_word, MAXWLEN + 1);
      if (sug.su_badlen > stp->st_orglen)
        STRLCPY(wcopy + stp->st_wordlen,
            sug.su_badptr + stp->st_orglen,
            sug.su_badlen - stp->st_orglen + 1);
      vim_snprintf((char *)IObuff, IOSIZE, "%2d", i + 1);
      if (cmdmsg_rl) {
        rl_mirror(IObuff);
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
        if (sps_flags & (SPS_DOUBLE | SPS_BEST))
          vim_snprintf((char *)IObuff, IOSIZE, " (%s%d - %d)",
              stp->st_salscore ? "s " : "",
              stp->st_score, stp->st_altscore);
        else
          vim_snprintf((char *)IObuff, IOSIZE, " (%d)",
              stp->st_score);
        if (cmdmsg_rl)
          // Mirror the numbers, but keep the leading space.
          rl_mirror(IObuff + 1);
        msg_advance(30);
        msg_puts((const char *)IObuff);
      }
      msg_putchar('\n');
    }

    cmdmsg_rl = FALSE;
    msg_col = 0;
    // Ask for choice.
    selected = prompt_for_number(&mouse_used);
    if (mouse_used)
      selected -= lines_left;
    lines_left = Rows;                  // avoid more prompt
    // don't delay for 'smd' in normal_cmd()
    msg_scroll = msg_scroll_save;
  }

  if (selected > 0 && selected <= sug.su_ga.ga_len && u_save_cursor() == OK) {
    // Save the from and to text for :spellrepall.
    stp = &SUG(sug.su_ga, selected - 1);
    if (sug.su_badlen > stp->st_orglen) {
      // Replacing less than "su_badlen", append the remainder to
      // repl_to.
      repl_from = vim_strnsave(sug.su_badptr, sug.su_badlen);
      vim_snprintf((char *)IObuff, IOSIZE, "%s%.*s", stp->st_word,
          sug.su_badlen - stp->st_orglen,
          sug.su_badptr + stp->st_orglen);
      repl_to = vim_strsave(IObuff);
    } else {
      // Replacing su_badlen or more, use the whole word.
      repl_from = vim_strnsave(sug.su_badptr, stp->st_orglen);
      repl_to = vim_strsave(stp->st_word);
    }

    // Replace the word.
    p = xmalloc(STRLEN(line) - stp->st_orglen + stp->st_wordlen + 1);
    c = (int)(sug.su_badptr - line);
    memmove(p, line, c);
    STRCPY(p + c, stp->st_word);
    STRCAT(p, sug.su_badptr + stp->st_orglen);
    ml_replace(curwin->w_cursor.lnum, p, false);
    curwin->w_cursor.col = c;

    // For redo we use a change-word command.
    ResetRedobuff();
    AppendToRedobuff("ciw");
    AppendToRedobuffLit(p + c,
        stp->st_wordlen + sug.su_badlen - stp->st_orglen);
    AppendCharToRedobuff(ESC);

    // After this "p" may be invalid.
    changed_bytes(curwin->w_cursor.lnum, c);
  } else
    curwin->w_cursor = prev_cursor;

  spell_find_cleanup(&sug);
  xfree(line);
}

// Check if the word at line "lnum" column "col" is required to start with a
// capital.  This uses 'spellcapcheck' of the current buffer.
static bool check_need_cap(linenr_T lnum, colnr_T col)
{
  bool need_cap = false;
  char_u      *line;
  char_u      *line_copy = NULL;
  char_u      *p;
  colnr_T endcol;
  regmatch_T regmatch;

  if (curwin->w_s->b_cap_prog == NULL)
    return false;

  line = get_cursor_line_ptr();
  endcol = 0;
  if (getwhitecols(line) >= (int)col) {
    // At start of line, check if previous line is empty or sentence
    // ends there.
    if (lnum == 1)
      need_cap = true;
    else {
      line = ml_get(lnum - 1);
      if (*skipwhite(line) == NUL)
        need_cap = true;
      else {
        // Append a space in place of the line break.
        line_copy = concat_str(line, (char_u *)" ");
        line = line_copy;
        endcol = (colnr_T)STRLEN(line);
      }
    }
  } else {
    endcol = col;
  }

  if (endcol > 0) {
    // Check if sentence ends before the bad word.
    regmatch.regprog = curwin->w_s->b_cap_prog;
    regmatch.rm_ic = FALSE;
    p = line + endcol;
    for (;; ) {
      MB_PTR_BACK(line, p);
      if (p == line || spell_iswordp_nmw(p, curwin)) {
        break;
      }
      if (vim_regexec(&regmatch, p, 0)
          && regmatch.endp[0] == line + endcol) {
        need_cap = true;
        break;
      }
    }
    curwin->w_s->b_cap_prog = regmatch.regprog;
  }

  xfree(line_copy);

  return need_cap;
}


// ":spellrepall"
void ex_spellrepall(exarg_T *eap)
{
  pos_T pos = curwin->w_cursor;
  char_u      *frompat;
  int addlen;
  char_u      *line;
  char_u      *p;
  bool save_ws = p_ws;
  linenr_T prev_lnum = 0;

  if (repl_from == NULL || repl_to == NULL) {
    EMSG(_("E752: No previous spell replacement"));
    return;
  }
  addlen = (int)(STRLEN(repl_to) - STRLEN(repl_from));

  frompat = xmalloc(STRLEN(repl_from) + 7);
  sprintf((char *)frompat, "\\V\\<%s\\>", repl_from);
  p_ws = false;

  sub_nsubs = 0;
  sub_nlines = 0;
  curwin->w_cursor.lnum = 0;
  while (!got_int) {
    if (do_search(NULL, '/', frompat, 1L, SEARCH_KEEP, NULL, NULL) == 0
        || u_save_cursor() == FAIL) {
      break;
    }

    // Only replace when the right word isn't there yet.  This happens
    // when changing "etc" to "etc.".
    line = get_cursor_line_ptr();
    if (addlen <= 0 || STRNCMP(line + curwin->w_cursor.col,
            repl_to, STRLEN(repl_to)) != 0) {
      p = xmalloc(STRLEN(line) + addlen + 1);
      memmove(p, line, curwin->w_cursor.col);
      STRCPY(p + curwin->w_cursor.col, repl_to);
      STRCAT(p, line + curwin->w_cursor.col + STRLEN(repl_from));
      ml_replace(curwin->w_cursor.lnum, p, false);
      changed_bytes(curwin->w_cursor.lnum, curwin->w_cursor.col);

      if (curwin->w_cursor.lnum != prev_lnum) {
        ++sub_nlines;
        prev_lnum = curwin->w_cursor.lnum;
      }
      ++sub_nsubs;
    }
    curwin->w_cursor.col += (colnr_T)STRLEN(repl_to);
  }

  p_ws = save_ws;
  curwin->w_cursor = pos;
  xfree(frompat);

  if (sub_nsubs == 0)
    EMSG2(_("E753: Not found: %s"), repl_from);
  else
    do_sub_msg(false);
}

// Find spell suggestions for "word".  Return them in the growarray "*gap" as
// a list of allocated strings.
void
spell_suggest_list (
    garray_T *gap,
    char_u *word,
    int maxcount,                   // maximum nr of suggestions
    bool need_cap,                  // 'spellcapcheck' matched
    bool interactive
)
{
  suginfo_T sug;
  suggest_T   *stp;
  char_u      *wcopy;

  spell_find_suggest(word, 0, &sug, maxcount, false, need_cap, interactive);

  // Make room in "gap".
  ga_init(gap, sizeof(char_u *), sug.su_ga.ga_len + 1);
  ga_grow(gap, sug.su_ga.ga_len);
  for (int i = 0; i < sug.su_ga.ga_len; ++i) {
    stp = &SUG(sug.su_ga, i);

    // The suggested word may replace only part of "word", add the not
    // replaced part.
    wcopy = xmalloc(stp->st_wordlen
                    + STRLEN(sug.su_badptr + stp->st_orglen) + 1);
    STRCPY(wcopy, stp->st_word);
    STRCPY(wcopy + stp->st_wordlen, sug.su_badptr + stp->st_orglen);
    ((char_u **)gap->ga_data)[gap->ga_len++] = wcopy;
  }

  spell_find_cleanup(&sug);
}

// Find spell suggestions for the word at the start of "badptr".
// Return the suggestions in "su->su_ga".
// The maximum number of suggestions is "maxcount".
// Note: does use info for the current window.
// This is based on the mechanisms of Aspell, but completely reimplemented.
static void
spell_find_suggest (
    char_u *badptr,
    int badlen,                     // length of bad word or 0 if unknown
    suginfo_T *su,
    int maxcount,
    bool banbadword,                 // don't include badword in suggestions
    bool need_cap,                  // word should start with capital
    bool interactive
)
{
  hlf_T attr = HLF_COUNT;
  char_u buf[MAXPATHL];
  char_u      *p;
  bool do_combine = false;
  char_u      *sps_copy;
  static bool expr_busy = false;
  int c;
  langp_T     *lp;

  // Set the info in "*su".
  memset(su, 0, sizeof(suginfo_T));
  ga_init(&su->su_ga, (int)sizeof(suggest_T), 10);
  ga_init(&su->su_sga, (int)sizeof(suggest_T), 10);
  if (*badptr == NUL)
    return;
  hash_init(&su->su_banned);

  su->su_badptr = badptr;
  if (badlen != 0)
    su->su_badlen = badlen;
  else {
    size_t tmplen = spell_check(curwin, su->su_badptr, &attr, NULL, false);
    assert(tmplen <= INT_MAX);
    su->su_badlen = (int)tmplen;
  }
  su->su_maxcount = maxcount;
  su->su_maxscore = SCORE_MAXINIT;

  if (su->su_badlen >= MAXWLEN)
    su->su_badlen = MAXWLEN - 1;        // just in case
  STRLCPY(su->su_badword, su->su_badptr, su->su_badlen + 1);
  (void)spell_casefold(su->su_badptr, su->su_badlen, su->su_fbadword, MAXWLEN);

  // TODO(vim): make this work if the case-folded text is longer than the
  // original text. Currently an illegal byte causes wrong pointer
  // computations.
  su->su_fbadword[su->su_badlen] = NUL;

  // get caps flags for bad word
  su->su_badflags = badword_captype(su->su_badptr,
      su->su_badptr + su->su_badlen);
  if (need_cap)
    su->su_badflags |= WF_ONECAP;

  // Find the default language for sound folding.  We simply use the first
  // one in 'spelllang' that supports sound folding.  That's good for when
  // using multiple files for one language, it's not that bad when mixing
  // languages (e.g., "pl,en").
  for (int i = 0; i < curbuf->b_s.b_langp.ga_len; ++i) {
    lp = LANGP_ENTRY(curbuf->b_s.b_langp, i);
    if (lp->lp_sallang != NULL) {
      su->su_sallang = lp->lp_sallang;
      break;
    }
  }

  // Soundfold the bad word with the default sound folding, so that we don't
  // have to do this many times.
  if (su->su_sallang != NULL)
    spell_soundfold(su->su_sallang, su->su_fbadword, true,
        su->su_sal_badword);

  // If the word is not capitalised and spell_check() doesn't consider the
  // word to be bad then it might need to be capitalised.  Add a suggestion
  // for that.
  c = PTR2CHAR(su->su_badptr);
  if (!SPELL_ISUPPER(c) && attr == HLF_COUNT) {
    make_case_word(su->su_badword, buf, WF_ONECAP);
    add_suggestion(su, &su->su_ga, buf, su->su_badlen, SCORE_ICASE,
        0, true, su->su_sallang, false);
  }

  // Ban the bad word itself.  It may appear in another region.
  if (banbadword)
    add_banned(su, su->su_badword);

  // Make a copy of 'spellsuggest', because the expression may change it.
  sps_copy = vim_strsave(p_sps);

  // Loop over the items in 'spellsuggest'.
  for (p = sps_copy; *p != NUL; ) {
    copy_option_part(&p, buf, MAXPATHL, ",");

    if (STRNCMP(buf, "expr:", 5) == 0) {
      // Evaluate an expression.  Skip this when called recursively,
      // when using spellsuggest() in the expression.
      if (!expr_busy) {
        expr_busy = true;
        spell_suggest_expr(su, buf + 5);
        expr_busy = false;
      }
    } else if (STRNCMP(buf, "file:", 5) == 0)
      // Use list of suggestions in a file.
      spell_suggest_file(su, buf + 5);
    else {
      // Use internal method.
      spell_suggest_intern(su, interactive);
      if (sps_flags & SPS_DOUBLE)
        do_combine = true;
    }
  }

  xfree(sps_copy);

  if (do_combine)
    // Combine the two list of suggestions.  This must be done last,
    // because sorting changes the order again.
    score_combine(su);
}

// Find suggestions by evaluating expression "expr".
static void spell_suggest_expr(suginfo_T *su, char_u *expr)
{
  int score;
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
        score = get_spellword(TV_LIST_ITEM_TV(li)->vval.v_list, &p);
        if (score >= 0 && score <= su->su_maxscore) {
          add_suggestion(su, &su->su_ga, (const char_u *)p, su->su_badlen,
                         score, 0, true, su->su_sallang, false);
        }
      }
    });
    tv_list_unref(list);
  }

  // Remove bogus suggestions, sort and truncate at "maxcount".
  check_suggestions(su, &su->su_ga);
  (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
}

// Find suggestions in file "fname".  Used for "file:" in 'spellsuggest'.
static void spell_suggest_file(suginfo_T *su, char_u *fname)
{
  FILE        *fd;
  char_u line[MAXWLEN * 2];
  char_u      *p;
  int len;
  char_u cword[MAXWLEN];

  // Open the file.
  fd = mch_fopen((char *)fname, "r");
  if (fd == NULL) {
    EMSG2(_(e_notopen), fname);
    return;
  }

  // Read it line by line.
  while (!vim_fgets(line, MAXWLEN * 2, fd) && !got_int) {
    line_breakcheck();

    p = vim_strchr(line, '/');
    if (p == NULL)
      continue;             // No Tab found, just skip the line.
    *p++ = NUL;
    if (STRICMP(su->su_badword, line) == 0) {
      // Match!  Isolate the good word, until CR or NL.
      for (len = 0; p[len] >= ' '; ++len)
        ;
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
  (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
}

// Find suggestions for the internal method indicated by "sps_flags".
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
  if (sps_flags & SPS_DOUBLE)
    score_comp_sal(su);

  // 3. Try finding sound-a-like words.
  if ((sps_flags & SPS_FAST) == 0) {
    if (sps_flags & SPS_BEST)
      // Adjust the word score for the suggestions found so far for how
      // they sounds like.
      rescore_suggestions(su);

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
    (void)vgetc();
    got_int = FALSE;
  }

  if ((sps_flags & SPS_DOUBLE) == 0 && su->su_ga.ga_len != 0) {
    if (sps_flags & SPS_BEST)
      // Adjust the word score for how it sounds like.
      rescore_suggestions(su);

    // Remove bogus suggestions, sort and truncate at "maxcount".
    check_suggestions(su, &su->su_ga);
    (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
  }
}

// Free the info put in "*su" by spell_find_suggest().
static void spell_find_cleanup(suginfo_T *su)
{
# define FREE_SUG_WORD(sug) xfree(sug->st_word)
  // Free the suggestions.
  GA_DEEP_CLEAR(&su->su_ga, suggest_T, FREE_SUG_WORD);
  GA_DEEP_CLEAR(&su->su_sga, suggest_T, FREE_SUG_WORD);

  // Free the banned words.
  hash_clear_all(&su->su_banned, 0);
}

/// Make a copy of "word", with the first letter upper or lower cased, to
/// "wcopy[MAXWLEN]".  "word" must not be empty.
/// The result is NUL terminated.
///
/// @param[in]  word  source string to copy
/// @param[in,out]  wcopy  copied string, with case of first letter changed
/// @param[in]  upper  True to upper case, otherwise lower case
void onecap_copy(char_u *word, char_u *wcopy, bool upper)
{
  char_u      *p;
  int c;
  int l;

  p = word;
  if (has_mbyte) {
    c = mb_cptr2char_adv((const char_u **)&p);
  } else {
    c = *p++;
  }
  if (upper) {
    c = SPELL_TOUPPER(c);
  } else {
    c = SPELL_TOFOLD(c);
  }
  l = utf_char2bytes(c, wcopy);
  STRLCPY(wcopy + l, p, MAXWLEN - l);
}

// Make a copy of "word" with all the letters upper cased into
// "wcopy[MAXWLEN]".  The result is NUL terminated.
static void allcap_copy(char_u *word, char_u *wcopy)
{
  char_u      *s;
  char_u      *d;
  int c;

  d = wcopy;
  for (s = word; *s != NUL; ) {
    if (has_mbyte) {
      c = mb_cptr2char_adv((const char_u **)&s);
    } else {
      c = *s++;
    }

    if (c == 0xdf) {
      c = 'S';
      if (d - wcopy >= MAXWLEN - 1)
        break;
      *d++ = c;
    } else
      c = SPELL_TOUPPER(c);

    if (d - wcopy >= MAXWLEN - MB_MAXBYTES) {
      break;
    }
    d += utf_char2bytes(c, d);
  }
  *d = NUL;
}

// Try finding suggestions by recognizing specific situations.
static void suggest_try_special(suginfo_T *su)
{
  char_u      *p;
  size_t len;
  int c;
  char_u word[MAXWLEN];

  // Recognize a word that is repeated: "the the".
  p = skiptowhite(su->su_fbadword);
  len = p - su->su_fbadword;
  p = skipwhite(p);
  if (STRLEN(p) == len && STRNCMP(su->su_fbadword, p, len) == 0) {
    // Include badflags: if the badword is onecap or allcap
    // use that for the goodword too: "The the" -> "The".
    c = su->su_fbadword[len];
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

  static void
prof_init(void)
{
  for (int i = 0; i <= STATE_FINAL; i++) {
    profile_zero(&times[i]);
    counts[i] = 0;
  }
  profile_start(&current);
  profile_start(&total);
}

// call before changing state
  static void
prof_store(state_T state)
{
  profile_end(&current);
  profile_add(&times[state], &current);
  counts[state]++;
  profile_start(&current);
}
# define PROF_STORE(state) prof_store(state);

  static void
prof_report(char *name)
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

// Try finding suggestions by adding/removing/swapping letters.

static void suggest_try_change(suginfo_T *su)
{
  char_u fword[MAXWLEN];            // copy of the bad word, case-folded
  int n;
  char_u      *p;
  langp_T     *lp;

  // We make a copy of the case-folded bad word, so that we can modify it
  // to find matches (esp. REP items).  Append some more text, changing
  // chars after the bad word may help.
  STRCPY(fword, su->su_fbadword);
  n = (int)STRLEN(fword);
  p = su->su_badptr + su->su_badlen;
  (void)spell_casefold(p, (int)STRLEN(p), fword + n, MAXWLEN - n);

  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);

    // If reloading a spell file fails it's still in the list but
    // everything has been cleared.
    if (lp->lp_slang->sl_fbyts == NULL)
      continue;

    // Try it for this language.  Will add possible suggestions.
    //
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
  (stack[depth].ts_score + (add) < su->su_maxscore)

// Try finding suggestions by adding/removing/swapping letters.
//
// This uses a state machine.  At each node in the tree we try various
// operations.  When trying if an operation works "depth" is increased and the
// stack[] is used to store info.  This allows combinations, thus insert one
// character, replace one and delete another.  The number of changes is
// limited by su->su_maxscore.
//
// After implementing this I noticed an article by Kemal Oflazer that
// describes something similar: "Error-tolerant Finite State Recognition with
// Applications to Morphological Analysis and Spelling Correction" (1996).
// The implementation in the article is simplified and requires a stack of
// unknown depth.  The implementation here only needs a stack depth equal to
// the length of the word.
//
// This is also used for the sound-folded word, "soundfold" is true then.
// The mechanism is the same, but we find a match with a sound-folded word
// that comes from one or more original words.  Each of these words may be
// added, this is done by add_sound_suggest().
// Don't use:
//      the prefix tree or the keep-case tree
//      "su->su_badlen"
//      anything to do with upper and lower case
//      anything to do with word or non-word characters ("spell_iswordp()")
//      banned words
//      word flags (rare, region, compounding)
//      word splitting for now
//      "similar_chars()"
//      use "slang->sl_repsal" instead of "lp->lp_replang->sl_rep"
static void suggest_trie_walk(suginfo_T *su, langp_T *lp, char_u *fword, bool soundfold)
{
  char_u tword[MAXWLEN];            // good word collected so far
  trystate_T stack[MAXWLEN];
  char_u preword[MAXWLEN * 3];      // word found with proper case;
                                    // concatenation of prefix compound
                                    // words and split word.  NUL terminated
                                    // when going deeper but not when coming
                                    // back.
  char_u compflags[MAXWLEN];        // compound flags, one for each word
  trystate_T  *sp;
  int newscore;
  int score;
  char_u      *byts, *fbyts, *pbyts;
  idx_T       *idxs, *fidxs, *pidxs;
  int depth;
  int c, c2, c3;
  int n = 0;
  int flags;
  garray_T    *gap;
  idx_T arridx;
  int len;
  char_u      *p;
  fromto_T    *ftp;
  int fl = 0, tl;
  int repextra = 0;                 // extra bytes in fword[] from REP item
  slang_T     *slang = lp->lp_slang;
  int fword_ends;
  bool goodword_ends;
#ifdef DEBUG_TRIEWALK
  // Stores the name of the change made at each level.
  char_u changename[MAXWLEN][80];
#endif
  int breakcheckcount = 1000;
  bool compound_ok;

  // Go through the whole case-fold tree, try changes at each node.
  // "tword[]" contains the word collected from nodes in the tree.
  // "fword[]" the word we are trying to match with (initially the bad
  // word).
  depth = 0;
  sp = &stack[0];
  memset(sp, 0, sizeof(trystate_T));  // -V512
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
      len = byts[arridx];                   // bytes in this node
      arridx += sp->ts_curi;                // index of current byte

      if (sp->ts_prefixdepth == PFD_PREFIXTREE) {
        // Skip over the NUL bytes, we use them later.
        for (n = 0; n < len && byts[arridx + n] == 0; ++n)
          ;
        sp->ts_curi += n;

        // Always past NUL bytes now.
        n = (int)sp->ts_state;
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_ENDNUL;
        sp->ts_save_badflags = su->su_badflags;

        // At end of a prefix or at start of prefixtree: check for
        // following word.
        if (byts[arridx] == 0 || n == (int)STATE_NOPREFIX) {
          // Set su->su_badflags to the caps type at this position.
          // Use the caps type until here for the prefix itself.
          if (has_mbyte)
            n = nofold_len(fword, sp->ts_fidx, su->su_badptr);
          else
            n = sp->ts_fidx;
          flags = badword_captype(su->su_badptr, su->su_badptr + n);
          su->su_badflags = badword_captype(su->su_badptr + n,
              su->su_badptr + su->su_badlen);
#ifdef DEBUG_TRIEWALK
          sprintf(changename[depth], "prefix");
#endif
          go_deeper(stack, depth, 0);
          ++depth;
          sp = &stack[depth];
          sp->ts_prefixdepth = depth - 1;
          byts = fbyts;
          idxs = fidxs;
          sp->ts_arridx = 0;

          // Move the prefix to preword[] with the right case
          // and make find_keepcap_word() works.
          tword[sp->ts_twordlen] = NUL;
          make_case_word(tword + sp->ts_splitoff,
              preword + sp->ts_prewordlen, flags);
          sp->ts_prewordlen = (char_u)STRLEN(preword);
          sp->ts_splitoff = sp->ts_twordlen;
        }
        break;
      }

      if (sp->ts_curi > len || byts[arridx] != 0) {
        // Past bytes in node and/or past NUL bytes.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_ENDNUL;
        sp->ts_save_badflags = su->su_badflags;
        break;
      }

      // End of word in tree.
      ++sp->ts_curi;                    // eat one NUL byte

      flags = (int)idxs[arridx];

      // Skip words with the NOSUGGEST flag.
      if (flags & WF_NOSUGGEST)
        break;

      fword_ends = (fword[sp->ts_fidx] == NUL
                    || (soundfold
                        ? ascii_iswhite(fword[sp->ts_fidx])
                        : !spell_iswordp(fword + sp->ts_fidx, curwin)));
      tword[sp->ts_twordlen] = NUL;

      if (sp->ts_prefixdepth <= PFD_NOTSPECIAL
          && (sp->ts_flags & TSF_PREFIXOK) == 0) {
        // There was a prefix before the word.  Check that the prefix
        // can be used with this word.
        // Count the length of the NULs in the prefix.  If there are
        // none this must be the first try without a prefix.
        n = stack[sp->ts_prefixdepth].ts_arridx;
        len = pbyts[n++];
        for (c = 0; c < len && pbyts[n + c] == 0; ++c)
          ;
        if (c > 0) {
          c = valid_word_prefix(c, n, flags,
              tword + sp->ts_splitoff, slang, false);
          if (c == 0)
            break;

          // Use the WF_RARE flag for a rare prefix.
          if (c & WF_RAREPFX)
            flags |= WF_RARE;

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
          && (flags & WF_NEEDCOMP))
        goodword_ends = false;
      else
        goodword_ends = true;

      p = NULL;
      compound_ok = true;
      if (sp->ts_complen > sp->ts_compsplit) {
        if (slang->sl_nobreak) {
          // There was a word before this word.  When there was no
          // change in this word (it was correct) add the first word
          // as a suggestion.  If this word was corrected too, we
          // need to check if a correct word follows.
          if (sp->ts_fidx - sp->ts_splitfidx
              == sp->ts_twordlen - sp->ts_splitoff
              && STRNCMP(fword + sp->ts_splitfidx,
                  tword + sp->ts_splitoff,
                  sp->ts_fidx - sp->ts_splitfidx) == 0) {
            preword[sp->ts_prewordlen] = NUL;
            newscore = score_wordcount_adj(slang, sp->ts_score,
                preword + sp->ts_prewordlen,
                sp->ts_prewordlen > 0);
            // Add the suggestion if the score isn't too bad.
            if (newscore <= su->su_maxscore)
              add_suggestion(su, &su->su_ga, preword,
                  sp->ts_splitfidx - repextra,
                  newscore, 0, false,
                  lp->lp_sallang, false);
            break;
          }
        } else {
          // There was a compound word before this word.  If this
          // word does not support compounding then give up
          // (splitting is tried for the word without compound
          // flag).
          if (((unsigned)flags >> 24) == 0
              || sp->ts_twordlen - sp->ts_splitoff
              < slang->sl_compminlen)
            break;
          // For multi-byte chars check character length against
          // COMPOUNDMIN.
          if (has_mbyte
              && slang->sl_compminlen > 0
              && mb_charlen(tword + sp->ts_splitoff)
              < slang->sl_compminlen)
            break;

          compflags[sp->ts_complen] = ((unsigned)flags >> 24);
          compflags[sp->ts_complen + 1] = NUL;
          STRLCPY(preword + sp->ts_prewordlen,
              tword + sp->ts_splitoff,
              sp->ts_twordlen - sp->ts_splitoff + 1);

          // Verify CHECKCOMPOUNDPATTERN  rules.
          if (match_checkcompoundpattern(preword,  sp->ts_prewordlen,
                  &slang->sl_comppat))
            compound_ok = false;

          if (compound_ok) {
            p = preword;
            while (*skiptowhite(p) != NUL)
              p = skipwhite(skiptowhite(p));
            if (fword_ends && !can_compound(slang, p,
                    compflags + sp->ts_compsplit))
              // Compound is not allowed.  But it may still be
              // possible if we add another (short) word.
              compound_ok = false;
          }

          // Get pointer to last char of previous word.
          p = preword + sp->ts_prewordlen;
          MB_PTR_BACK(preword, p);
        }
      }

      // Form the word with proper case in preword.
      // If there is a word from a previous split, append.
      // For the soundfold tree don't change the case, simply append.
      if (soundfold)
        STRCPY(preword + sp->ts_prewordlen, tword + sp->ts_splitoff);
      else if (flags & WF_KEEPCAP)
        // Must find the word in the keep-case tree.
        find_keepcap_word(slang, tword + sp->ts_splitoff,
            preword + sp->ts_prewordlen);
      else {
        // Include badflags: If the badword is onecap or allcap
        // use that for the goodword too.  But if the badword is
        // allcap and it's only one char long use onecap.
        c = su->su_badflags;
        if ((c & WF_ALLCAP)
            && su->su_badlen == (*mb_ptr2len)(su->su_badptr)
            )
          c = WF_ONECAP;
        c |= flags;

        // When appending a compound word after a word character don't
        // use Onecap.
        if (p != NULL && spell_iswordp_nmw(p, curwin))
          c &= ~WF_ONECAP;
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
          if (slang->sl_compprog == NULL)
            break;
          // the word so far was banned but we may try compounding
          goodword_ends = false;
        }
      }

      newscore = 0;
      if (!soundfold) {         // soundfold words don't have flags
        if ((flags & WF_REGION)
            && (((unsigned)flags >> 16) & lp->lp_region) == 0)
          newscore += SCORE_REGION;
        if (flags & WF_RARE)
          newscore += SCORE_RARE;

        if (!spell_valid_case(su->su_badflags,
                captype(preword + sp->ts_prewordlen, NULL)))
          newscore += SCORE_ICASE;
      }

      // TODO: how about splitting in the soundfold tree?
      if (fword_ends
          && goodword_ends
          && sp->ts_fidx >= sp->ts_fidxtry
          && compound_ok) {
        // The badword also ends: add suggestions.
#ifdef DEBUG_TRIEWALK
        if (soundfold && STRCMP(preword, "smwrd") == 0) {
          int j;

          // print the stack of changes that brought us here
          smsg("------ %s -------", fword);
          for (j = 0; j < depth; ++j)
            smsg("%s", changename[j]);
        }
#endif
        if (soundfold) {
          // For soundfolded words we need to find the original
          // words, the edit distance and then add them.
          add_sound_suggest(su, preword, sp->ts_score, lp);
        } else if (sp->ts_fidx > 0)   {
          // Give a penalty when changing non-word char to word
          // char, e.g., "thes," -> "these".
          p = fword + sp->ts_fidx;
          MB_PTR_BACK(fword, p);
          if (!spell_iswordp(p, curwin)) {
            p = preword + STRLEN(preword);
            MB_PTR_BACK(preword, p);
            if (spell_iswordp(p, curwin)) {
              newscore += SCORE_NONWORD;
            }
          }

          // Give a bonus to words seen before.
          score = score_wordcount_adj(slang,
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
          && (!has_mbyte || sp->ts_tcharlen == 0)
          ) {
        bool try_compound;
        int try_split;

        // If past the end of the bad word don't try a split.
        // Otherwise try changing the next word.  E.g., find
        // suggestions for "the the" where the second "the" is
        // different.  It's done like a split.
        // TODO: word split for soundfold words
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
            && (!has_mbyte
                || slang->sl_compminlen == 0
                || mb_charlen(tword + sp->ts_splitoff)
                >= slang->sl_compminlen)
            && (slang->sl_compsylmax < MAXWLEN
                || sp->ts_complen + 1 - sp->ts_compsplit
                < slang->sl_compmax)
            && (can_be_compound(sp, slang,
                    compflags, ((unsigned)flags >> 24)))) {
          try_compound = true;
          compflags[sp->ts_complen] = ((unsigned)flags >> 24);
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
          --sp->ts_curi;                    // do the same NUL again
          compflags[sp->ts_complen] = NUL;
        } else {
          sp->ts_flags &= ~TSF_DIDSPLIT;
        }

        if (try_split || try_compound) {
          if (!try_compound && (!fword_ends || !goodword_ends)) {
            // If we're going to split need to check that the
            // words so far are valid for compounding.  If there
            // is only one word it must not have the NEEDCOMPOUND
            // flag.
            if (sp->ts_complen == sp->ts_compsplit
                && (flags & WF_NEEDCOMP))
              break;
            p = preword;
            while (*skiptowhite(p) != NUL)
              p = skipwhite(skiptowhite(p));
            if (sp->ts_complen > sp->ts_compsplit
                && !can_compound(slang, p,
                    compflags + sp->ts_compsplit))
              break;

            if (slang->sl_nosplitsugs)
              newscore += SCORE_SPLIT_NO;
            else
              newscore += SCORE_SPLIT;

            // Give a bonus to words seen before.
            newscore = score_wordcount_adj(slang, newscore,
                preword + sp->ts_prewordlen, true);
          }

          if (TRY_DEEPER(su, stack, depth, newscore)) {
            go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
            if (!try_compound && !fword_ends)
              sprintf(changename[depth], "%.*s-%s: split",
                  sp->ts_twordlen, tword, fword + sp->ts_fidx);
            else
              sprintf(changename[depth], "%.*s-%s: compound",
                  sp->ts_twordlen, tword, fword + sp->ts_fidx);
#endif
            // Save things to be restored at STATE_SPLITUNDO.
            sp->ts_save_badflags = su->su_badflags;
            PROF_STORE(sp->ts_state)
            sp->ts_state = STATE_SPLITUNDO;

            ++depth;
            sp = &stack[depth];

            // Append a space to preword when splitting.
            if (!try_compound && !fword_ends)
              STRCAT(preword, " ");
            sp->ts_prewordlen = (char_u)STRLEN(preword);
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

              l = MB_PTR2LEN(fword + sp->ts_fidx);
              if (fword_ends) {
                // Copy the skipped character to preword.
                memmove(preword + sp->ts_prewordlen,
                    fword + sp->ts_fidx, l);
                sp->ts_prewordlen += l;
                preword[sp->ts_prewordlen] = NUL;
              } else
                sp->ts_score -= SCORE_SPLIT - SCORE_SUBST;
              sp->ts_fidx += l;
            }

            // When compounding include compound flag in
            // compflags[] (already set above).  When splitting we
            // may start compounding over again.
            if (try_compound)
              ++sp->ts_complen;
            else
              sp->ts_compsplit = sp->ts_complen;
            sp->ts_prefixdepth = PFD_NOPREFIX;

            // set su->su_badflags to the caps type at this
            // position
            if (has_mbyte)
              n = nofold_len(fword, sp->ts_fidx, su->su_badptr);
            else
              n = sp->ts_fidx;
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
          && sp->ts_tcharlen == 0
          ) {
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
        if (c == fword[sp->ts_fidx]
            || (sp->ts_tcharlen > 0 && sp->ts_isdiff != DIFF_NONE)
            )
          newscore = 0;
        else
          newscore = SCORE_SUBST;
        if ((newscore == 0
             || (sp->ts_fidx >= sp->ts_fidxtry
                 && ((sp->ts_flags & TSF_DIDDEL) == 0
                     || c != fword[sp->ts_delidx])))
            && TRY_DEEPER(su, stack, depth, newscore)) {
          go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
          if (newscore > 0)
            sprintf(changename[depth], "%.*s-%s: subst %c to %c",
                sp->ts_twordlen, tword, fword + sp->ts_fidx,
                fword[sp->ts_fidx], c);
          else
            sprintf(changename[depth], "%.*s-%s: accept %c",
                sp->ts_twordlen, tword, fword + sp->ts_fidx,
                fword[sp->ts_fidx]);
#endif
          ++depth;
          sp = &stack[depth];
          ++sp->ts_fidx;
          tword[sp->ts_twordlen++] = c;
          sp->ts_arridx = idxs[arridx];
          if (newscore == SCORE_SUBST)
            sp->ts_isdiff = DIFF_YES;
          if (has_mbyte) {
            // Multi-byte characters are a bit complicated to
            // handle: They differ when any of the bytes differ
            // and then their length may also differ.
            if (sp->ts_tcharlen == 0) {
              // First byte.
              sp->ts_tcharidx = 0;
              sp->ts_tcharlen = MB_BYTE2LEN(c);
              sp->ts_fcharstart = sp->ts_fidx - 1;
              sp->ts_isdiff = (newscore != 0)
                              ? DIFF_YES : DIFF_NONE;
            } else if (sp->ts_isdiff == DIFF_INSERT)
              // When inserting trail bytes don't advance in the
              // bad word.
              --sp->ts_fidx;
            if (++sp->ts_tcharidx == sp->ts_tcharlen) {
              // Last byte of character.
              if (sp->ts_isdiff == DIFF_YES) {
                // Correct ts_fidx for the byte length of the
                // character (we didn't check that before).
                sp->ts_fidx = sp->ts_fcharstart
                              + MB_PTR2LEN(fword + sp->ts_fcharstart);

                // For changing a composing character adjust
                // the score from SCORE_SUBST to
                // SCORE_SUBCOMP.
                if (enc_utf8
                    && utf_iscomposing(utf_ptr2char(tword + sp->ts_twordlen
                                                    - sp->ts_tcharlen))
                    && utf_iscomposing(utf_ptr2char(fword
                                                    + sp->ts_fcharstart))) {
                  sp->ts_score -= SCORE_SUBST - SCORE_SUBCOMP;
                } else if (
                    !soundfold
                    && slang->sl_has_map
                    && similar_chars(
                        slang,
                        utf_ptr2char(tword + sp->ts_twordlen - sp->ts_tcharlen),
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
          } else {
            // If we found a similar char adjust the score.
            // We do this after calling go_deeper() because
            // it's slow.
            if (newscore != 0
                && !soundfold
                && slang->sl_has_map
                && similar_chars(slang,
                    c, fword[sp->ts_fidx - 1]))
              sp->ts_score -= SCORE_SUBST - SCORE_SIMILAR;
          }
        }
      }
      break;

    case STATE_DEL:
      // When past the first byte of a multi-byte char don't try
      // delete/insert/swap a character.
      if (has_mbyte && sp->ts_tcharlen > 0) {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_FINAL;
        break;
      }
      // Try skipping one character in the bad word (delete it).
      PROF_STORE(sp->ts_state)
      sp->ts_state = STATE_INS_PREP;
      sp->ts_curi = 1;
      if (soundfold && sp->ts_fidx == 0 && fword[sp->ts_fidx] == '*')
        // Deleting a vowel at the start of a word counts less, see
        // soundalike_score().
        newscore = 2 * SCORE_DEL / 3;
      else
        newscore = SCORE_DEL;
      if (fword[sp->ts_fidx] != NUL
          && TRY_DEEPER(su, stack, depth, newscore)) {
        go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
        sprintf(changename[depth], "%.*s-%s: delete %c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            fword[sp->ts_fidx]);
#endif
        ++depth;

        // Remember what character we deleted, so that we can avoid
        // inserting it again.
        stack[depth].ts_flags |= TSF_DIDDEL;
        stack[depth].ts_delidx = sp->ts_fidx;

        // Advance over the character in fword[].  Give a bonus to the
        // score if the same character is following "nn" -> "n".  It's
        // a bit illogical for soundfold tree but it does give better
        // results.
        c = utf_ptr2char(fword + sp->ts_fidx);
        stack[depth].ts_fidx += MB_PTR2LEN(fword + sp->ts_fidx);
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
      for (;; ) {
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
        ++sp->ts_curi;
      }
      break;

      FALLTHROUGH;

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
      c = byts[n];
      if (soundfold && sp->ts_twordlen == 0 && c == '*')
        // Inserting a vowel at the start of a word counts less,
        // see soundalike_score().
        newscore = 2 * SCORE_INS / 3;
      else
        newscore = SCORE_INS;
      if (c != fword[sp->ts_fidx]
          && TRY_DEEPER(su, stack, depth, newscore)) {
        go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
        sprintf(changename[depth], "%.*s-%s: insert %c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            c);
#endif
        ++depth;
        sp = &stack[depth];
        tword[sp->ts_twordlen++] = c;
        sp->ts_arridx = idxs[n];
        if (has_mbyte) {
          fl = MB_BYTE2LEN(c);
          if (fl > 1) {
            // There are following bytes for the same character.
            // We must find all bytes before trying
            // delete/insert/swap/etc.
            sp->ts_tcharlen = fl;
            sp->ts_tcharidx = 1;
            sp->ts_isdiff = DIFF_INSERT;
          }
        } else
          fl = 1;
        if (fl == 1) {
          // If the previous character was the same, thus doubling a
          // character, give a bonus to the score.  Also for
          // soundfold words (illogical but does give a better
          // score).
          if (sp->ts_twordlen >= 2
              && tword[sp->ts_twordlen - 2] == c)
            sp->ts_score -= SCORE_INS - SCORE_INSDUP;
        }
      }
      break;

    case STATE_SWAP:
      // Swap two bytes in the bad word: "12" -> "21".
      // We change "fword" here, it's changed back afterwards at
      // STATE_UNSWAP.
      p = fword + sp->ts_fidx;
      c = *p;
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

      n = MB_CPTR2LEN(p);
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
      if (c2 != NUL && TRY_DEEPER(su, stack, depth, SCORE_SWAP)) {
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
        fl = mb_char2len(c2);
        memmove(p, p + n, fl);
        utf_char2bytes(c, p + fl);
        stack[depth].ts_fidxtry = sp->ts_fidx + n + fl;
      } else {
        // If this swap doesn't work then SWAP3 won't either.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
      }
      break;

    case STATE_UNSWAP:
      // Undo the STATE_SWAP swap: "21" -> "12".
      p = fword + sp->ts_fidx;
      n = MB_PTR2LEN(p);
      c = utf_ptr2char(p + n);
      memmove(p + MB_PTR2LEN(p + n), p, n);
      utf_char2bytes(c, p);

      FALLTHROUGH;

    case STATE_SWAP3:
      // Swap two bytes, skipping one: "123" -> "321".  We change
      // "fword" here, it's changed back afterwards at STATE_UNSWAP3.
      p = fword + sp->ts_fidx;
      n = MB_CPTR2LEN(p);
      c = utf_ptr2char(p);
      fl = MB_CPTR2LEN(p + n);
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
        sprintf(changename[depth], "%.*s-%s: swap3 %c and %c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            c, c3);
#endif
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_UNSWAP3;
        depth++;
        tl = mb_char2len(c3);
        memmove(p, p + n + fl, tl);
        utf_char2bytes(c2, p + tl);
        utf_char2bytes(c, p + fl + tl);
        stack[depth].ts_fidxtry = sp->ts_fidx + n + fl + tl;
      } else {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
      }
      break;

    case STATE_UNSWAP3:
      // Undo STATE_SWAP3: "321" -> "123"
      p = fword + sp->ts_fidx;
      n = MB_PTR2LEN(p);
      c2 = utf_ptr2char(p + n);
      fl = MB_PTR2LEN(p + n);
      c = utf_ptr2char(p + n + fl);
      tl = MB_PTR2LEN(p + n + fl);
      memmove(p + fl + tl, p, n);
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
        sprintf(changename[depth], "%.*s-%s: rotate left %c%c%c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            p[0], p[1], p[2]);
#endif
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_UNROT3L;
        ++depth;
        p = fword + sp->ts_fidx;
        n = MB_CPTR2LEN(p);
        c = utf_ptr2char(p);
        fl = MB_CPTR2LEN(p + n);
        fl += MB_CPTR2LEN(p + n + fl);
        memmove(p, p + n, fl);
        utf_char2bytes(c, p + fl);
        stack[depth].ts_fidxtry = sp->ts_fidx + n + fl;
      } else {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
      }
      break;

    case STATE_UNROT3L:
      // Undo ROT3L: "231" -> "123"
      p = fword + sp->ts_fidx;
      n = MB_PTR2LEN(p);
      n += MB_PTR2LEN(p + n);
      c = utf_ptr2char(p + n);
      tl = MB_PTR2LEN(p + n);
      memmove(p + tl, p, n);
      utf_char2bytes(c, p);

      // Rotate three bytes right: "123" -> "312".  We change "fword"
      // here, it's changed back afterwards at STATE_UNROT3R.
      if (TRY_DEEPER(su, stack, depth, SCORE_SWAP3)) {
        go_deeper(stack, depth, SCORE_SWAP3);
#ifdef DEBUG_TRIEWALK
        p = fword + sp->ts_fidx;
        sprintf(changename[depth], "%.*s-%s: rotate right %c%c%c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            p[0], p[1], p[2]);
#endif
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_UNROT3R;
        ++depth;
        p = fword + sp->ts_fidx;
        n = MB_CPTR2LEN(p);
        n += MB_CPTR2LEN(p + n);
        c = utf_ptr2char(p + n);
        tl = MB_CPTR2LEN(p + n);
        memmove(p + tl, p, n);
        utf_char2bytes(c, p);
        stack[depth].ts_fidxtry = sp->ts_fidx + n + tl;
      } else {
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_REP_INI;
      }
      break;

    case STATE_UNROT3R:
      // Undo ROT3R: "312" -> "123"
      p = fword + sp->ts_fidx;
      c = utf_ptr2char(p);
      tl = MB_PTR2LEN(p);
      n = MB_PTR2LEN(p + tl);
      n += MB_PTR2LEN(p + tl + n);
      memmove(p, p + tl, n);
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
      if (soundfold)
        sp->ts_curi = slang->sl_repsal_first[fword[sp->ts_fidx]];
      else
        sp->ts_curi = lp->lp_replang->sl_rep_first[fword[sp->ts_fidx]];

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

      if (soundfold)
        gap = &slang->sl_repsal;
      else
        gap = &lp->lp_replang->sl_rep;
      while (sp->ts_curi < gap->ga_len) {
        ftp = (fromto_T *)gap->ga_data + sp->ts_curi++;
        if (*ftp->ft_from != *p) {
          // past possible matching entries
          sp->ts_curi = gap->ga_len;
          break;
        }
        if (STRNCMP(ftp->ft_from, p, STRLEN(ftp->ft_from)) == 0
            && TRY_DEEPER(su, stack, depth, SCORE_REP)) {
          go_deeper(stack, depth, SCORE_REP);
#ifdef DEBUG_TRIEWALK
          sprintf(changename[depth], "%.*s-%s: replace %s with %s",
              sp->ts_twordlen, tword, fword + sp->ts_fidx,
              ftp->ft_from, ftp->ft_to);
#endif
          // Need to undo this afterwards.
          PROF_STORE(sp->ts_state)
          sp->ts_state = STATE_REP_UNDO;

          // Change the "from" to the "to" string.
          ++depth;
          fl = (int)STRLEN(ftp->ft_from);
          tl = (int)STRLEN(ftp->ft_to);
          if (fl != tl) {
            STRMOVE(p + tl, p + fl);
            repextra += tl - fl;
          }
          memmove(p, ftp->ft_to, tl);
          stack[depth].ts_fidxtry = sp->ts_fidx + tl;
          stack[depth].ts_tcharlen = 0;
          break;
        }
      }

      if (sp->ts_curi >= gap->ga_len && sp->ts_state == STATE_REP)
        // No (more) matches.
        PROF_STORE(sp->ts_state)
        sp->ts_state = STATE_FINAL;

      break;

    case STATE_REP_UNDO:
      // Undo a REP replacement and continue with the next one.
      if (soundfold)
        gap = &slang->sl_repsal;
      else
        gap = &lp->lp_replang->sl_rep;
      ftp = (fromto_T *)gap->ga_data + sp->ts_curi - 1;
      fl = (int)STRLEN(ftp->ft_from);
      tl = (int)STRLEN(ftp->ft_to);
      p = fword + sp->ts_fidx;
      if (fl != tl) {
        STRMOVE(p + fl, p + tl);
        repextra -= tl - fl;
      }
      memmove(p, ftp->ft_from, fl);
      PROF_STORE(sp->ts_state)
      sp->ts_state = STATE_REP;
      break;

    default:
      // Did all possible states at this level, go up one level.
      --depth;

      if (depth >= 0 && stack[depth].ts_prefixdepth == PFD_PREFIXTREE) {
        // Continue in or go back to the prefix tree.
        byts = pbyts;
        idxs = pidxs;
      }

      // Don't check for CTRL-C too often, it takes time.
      if (--breakcheckcount == 0) {
        os_breakcheck();
        breakcheckcount = 1000;
      }
    }
  }
}


// Go one level deeper in the tree.
static void go_deeper(trystate_T *stack, int depth, int score_add)
{
  stack[depth + 1] = stack[depth];
  stack[depth + 1].ts_state = STATE_START;
  stack[depth + 1].ts_score = stack[depth].ts_score + score_add;
  stack[depth + 1].ts_curi = 1;         // start just after length byte
  stack[depth + 1].ts_flags = 0;
}

// Case-folding may change the number of bytes: Count nr of chars in
// fword[flen] and return the byte length of that many chars in "word".
static int nofold_len(char_u *fword, int flen, char_u *word)
{
  char_u      *p;
  int i = 0;

  for (p = fword; p < fword + flen; MB_PTR_ADV(p)) {
    i++;
  }
  for (p = word; i > 0; MB_PTR_ADV(p)) {
    i--;
  }
  return (int)(p - word);
}

// "fword" is a good word with case folded.  Find the matching keep-case
// words and put it in "kword".
// Theoretically there could be several keep-case words that result in the
// same case-folded word, but we only find one...
static void find_keepcap_word(slang_T *slang, char_u *fword, char_u *kword)
{
  char_u uword[MAXWLEN];                // "fword" in upper-case
  int depth;
  idx_T tryidx;

  // The following arrays are used at each depth in the tree.
  idx_T arridx[MAXWLEN];
  int round[MAXWLEN];
  int fwordidx[MAXWLEN];
  int uwordidx[MAXWLEN];
  int kwordlen[MAXWLEN];

  int flen, ulen;
  int l;
  int len;
  int c;
  idx_T lo, hi, m;
  char_u      *p;
  char_u      *byts = slang->sl_kbyts;      // array with bytes of the words
  idx_T       *idxs = slang->sl_kidxs;      // array with indexes

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
  depth = 0;
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
      --depth;
    } else if (++round[depth] > 2)   {
      // tried both fold-case and upper-case character, continue one
      // level up
      --depth;
    } else {
      // round[depth] == 1: Try using the folded-case character.
      // round[depth] == 2: Try using the upper-case character.
      if (has_mbyte) {
        flen = MB_CPTR2LEN(fword + fwordidx[depth]);
        ulen = MB_CPTR2LEN(uword + uwordidx[depth]);
      } else {
        ulen = flen = 1;
      }
      if (round[depth] == 1) {
        p = fword + fwordidx[depth];
        l = flen;
      } else {
        p = uword + uwordidx[depth];
        l = ulen;
      }

      for (tryidx = arridx[depth]; l > 0; --l) {
        // Perform a binary search in the list of accepted bytes.
        len = byts[tryidx++];
        c = *p++;
        lo = tryidx;
        hi = tryidx + len - 1;
        while (lo < hi) {
          m = (lo + hi) / 2;
          if (byts[m] > c)
            hi = m - 1;
          else if (byts[m] < c)
            lo = m + 1;
          else {
            lo = hi = m;
            break;
          }
        }

        // Stop if there is no matching byte.
        if (hi < lo || byts[lo] != c)
          break;

        // Continue at the child (if there is one).
        tryidx = idxs[lo];
      }

      if (l == 0) {
        // Found the matching char.  Copy it to "kword" and go a
        // level deeper.
        if (round[depth] == 1) {
          STRNCPY(kword + kwordlen[depth], fword + fwordidx[depth],
              flen);
          kwordlen[depth + 1] = kwordlen[depth] + flen;
        } else {
          STRNCPY(kword + kwordlen[depth], uword + uwordidx[depth],
              ulen);
          kwordlen[depth + 1] = kwordlen[depth] + ulen;
        }
        fwordidx[depth + 1] = fwordidx[depth] + flen;
        uwordidx[depth + 1] = uwordidx[depth] + ulen;

        ++depth;
        arridx[depth] = tryidx;
        round[depth] = 0;
      }
    }
  }

  // Didn't find it: "cannot happen".
  *kword = NUL;
}

// Compute the sound-a-like score for suggestions in su->su_ga and add them to
// su->su_sga.
static void score_comp_sal(suginfo_T *su)
{
  langp_T     *lp;
  char_u badsound[MAXWLEN];
  int i;
  suggest_T   *stp;
  suggest_T   *sstp;
  int score;

  ga_grow(&su->su_sga, su->su_ga.ga_len);

  // Use the sound-folding of the first language that supports it.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    if (!GA_EMPTY(&lp->lp_slang->sl_sal)) {
      // soundfold the bad word
      spell_soundfold(lp->lp_slang, su->su_fbadword, true, badsound);

      for (i = 0; i < su->su_ga.ga_len; ++i) {
        stp = &SUG(su->su_ga, i);

        // Case-fold the suggested word, sound-fold it and compute the
        // sound-a-like score.
        score = stp_sal_score(stp, su, lp->lp_slang, badsound);
        if (score < SCORE_MAXMAX) {
          // Add the suggestion.
          sstp = &SUG(su->su_sga, su->su_sga.ga_len);
          sstp->st_word = vim_strsave(stp->st_word);
          sstp->st_wordlen = stp->st_wordlen;
          sstp->st_score = score;
          sstp->st_altscore = 0;
          sstp->st_orglen = stp->st_orglen;
          ++su->su_sga.ga_len;
        }
      }
      break;
    }
  }
}

// Combine the list of suggestions in su->su_ga and su->su_sga.
// They are entwined.
static void score_combine(suginfo_T *su)
{
  garray_T ga;
  garray_T    *gap;
  langp_T     *lp;
  suggest_T   *stp;
  char_u      *p;
  char_u badsound[MAXWLEN];
  int round;
  slang_T     *slang = NULL;

  // Add the alternate score to su_ga.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    if (!GA_EMPTY(&lp->lp_slang->sl_sal)) {
      // soundfold the bad word
      slang = lp->lp_slang;
      spell_soundfold(slang, su->su_fbadword, true, badsound);

      for (int i = 0; i < su->su_ga.ga_len; ++i) {
        stp = &SUG(su->su_ga, i);
        stp->st_altscore = stp_sal_score(stp, su, slang, badsound);
        if (stp->st_altscore == SCORE_MAXMAX)
          stp->st_score = (stp->st_score * 3 + SCORE_BIG) / 4;
        else
          stp->st_score = (stp->st_score * 3
                           + stp->st_altscore) / 4;
        stp->st_salscore = false;
      }
      break;
    }
  }

  if (slang == NULL) {  // Using "double" without sound folding.
    (void)cleanup_suggestions(&su->su_ga, su->su_maxscore,
        su->su_maxcount);
    return;
  }

  // Add the alternate score to su_sga.
  for (int i = 0; i < su->su_sga.ga_len; ++i) {
    stp = &SUG(su->su_sga, i);
    stp->st_altscore = spell_edit_score(slang,
        su->su_badword, stp->st_word);
    if (stp->st_score == SCORE_MAXMAX)
      stp->st_score = (SCORE_BIG * 7 + stp->st_altscore) / 8;
    else
      stp->st_score = (stp->st_score * 7 + stp->st_altscore) / 8;
    stp->st_salscore = true;
  }

  // Remove bad suggestions, sort the suggestions and truncate at "maxcount"
  // for both lists.
  check_suggestions(su, &su->su_ga);
  (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
  check_suggestions(su, &su->su_sga);
  (void)cleanup_suggestions(&su->su_sga, su->su_maxscore, su->su_maxcount);

  ga_init(&ga, (int)sizeof(suginfo_T), 1);
  ga_grow(&ga, su->su_ga.ga_len + su->su_sga.ga_len);

  stp = &SUG(ga, 0);
  for (int i = 0; i < su->su_ga.ga_len || i < su->su_sga.ga_len; ++i) {
    // round 1: get a suggestion from su_ga
    // round 2: get a suggestion from su_sga
    for (round = 1; round <= 2; ++round) {
      gap = round == 1 ? &su->su_ga : &su->su_sga;
      if (i < gap->ga_len) {
        // Don't add a word if it's already there.
        p = SUG(*gap, i).st_word;
        int j;
        for (j = 0; j < ga.ga_len; ++j)
          if (STRCMP(stp[j].st_word, p) == 0)
            break;
        if (j == ga.ga_len)
          stp[ga.ga_len++] = SUG(*gap, i);
        else
          xfree(p);
      }
    }
  }

  ga_clear(&su->su_ga);
  ga_clear(&su->su_sga);

  // Truncate the list to the number of suggestions that will be displayed.
  if (ga.ga_len > su->su_maxcount) {
    for (int i = su->su_maxcount; i < ga.ga_len; ++i) {
      xfree(stp[i].st_word);
    }
    ga.ga_len = su->su_maxcount;
  }

  su->su_ga = ga;
}

// For the goodword in "stp" compute the soundalike score compared to the
// badword.
static int
stp_sal_score (
    suggest_T *stp,
    suginfo_T *su,
    slang_T *slang,
    char_u *badsound          // sound-folded badword
)
{
  char_u      *p;
  char_u      *pbad;
  char_u      *pgood;
  char_u badsound2[MAXWLEN];
  char_u fword[MAXWLEN];
  char_u goodsound[MAXWLEN];
  char_u goodword[MAXWLEN];
  int lendiff;

  lendiff = su->su_badlen - stp->st_orglen;
  if (lendiff >= 0)
    pbad = badsound;
  else {
    // soundfold the bad word with more characters following
    (void)spell_casefold(su->su_badptr, stp->st_orglen, fword, MAXWLEN);

    // When joining two words the sound often changes a lot.  E.g., "t he"
    // sounds like "t h" while "the" sounds like "@".  Avoid that by
    // removing the space.  Don't do it when the good word also contains a
    // space.
    if (ascii_iswhite(su->su_badptr[su->su_badlen])
        && *skiptowhite(stp->st_word) == NUL)
      for (p = fword; *(p = skiptowhite(p)) != NUL; )
        STRMOVE(p, p + 1);

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
  } else
    pgood = stp->st_word;

  // Sound-fold the word and compute the score for the difference.
  spell_soundfold(slang, pgood, false, goodsound);

  return soundalike_score(goodsound, pbad);
}

static sftword_T dumsft;
#define HIKEY2SFT(p)  ((sftword_T *)(p - (dumsft.sft_word - (char_u *)&dumsft)))
#define HI2SFT(hi)     HIKEY2SFT((hi)->hi_key)

// Prepare for calling suggest_try_soundalike().
static void suggest_try_soundalike_prep(void)
{
  langp_T     *lp;
  slang_T     *slang;

  // Do this for all languages that support sound folding and for which a
  // .sug file has been loaded.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (!GA_EMPTY(&slang->sl_sal) && slang->sl_sbyts != NULL)
      // prepare the hashtable used by add_sound_suggest()
      hash_init(&slang->sl_sounddone);
  }
}

// Find suggestions by comparing the word in a sound-a-like form.
// Note: This doesn't support postponed prefixes.
static void suggest_try_soundalike(suginfo_T *su)
{
  char_u salword[MAXWLEN];
  langp_T     *lp;
  slang_T     *slang;

  // Do this for all languages that support sound folding and for which a
  // .sug file has been loaded.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (!GA_EMPTY(&slang->sl_sal) && slang->sl_sbyts != NULL) {
      // soundfold the bad word
      spell_soundfold(slang, su->su_fbadword, true, salword);

      // try all kinds of inserts/deletes/swaps/etc.
      // TODO: also soundfold the next words, so that we can try joining
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

// Finish up after calling suggest_try_soundalike().
static void suggest_try_soundalike_finish(void)
{
  langp_T     *lp;
  slang_T     *slang;
  int todo;
  hashitem_T  *hi;

  // Do this for all languages that support sound folding and for which a
  // .sug file has been loaded.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (!GA_EMPTY(&slang->sl_sal) && slang->sl_sbyts != NULL) {
      // Free the info about handled words.
      todo = (int)slang->sl_sounddone.ht_used;
      for (hi = slang->sl_sounddone.ht_array; todo > 0; ++hi)
        if (!HASHITEM_EMPTY(hi)) {
          xfree(HI2SFT(hi));
          --todo;
        }

      // Clear the hashtable, it may also be used by another region.
      hash_clear(&slang->sl_sounddone);
      hash_init(&slang->sl_sounddone);
    }
  }
}

// A match with a soundfolded word is found.  Add the good word(s) that
// produce this soundfolded word.
static void
add_sound_suggest (
    suginfo_T *su,
    char_u *goodword,
    int score,                      // soundfold score
    langp_T *lp
)
{
  slang_T     *slang = lp->lp_slang;    // language for sound folding
  int sfwordnr;
  char_u      *nrline;
  int orgnr;
  char_u theword[MAXWLEN];
  int i;
  int wlen;
  char_u      *byts;
  idx_T       *idxs;
  int n;
  int wordcount;
  int wc;
  int goodscore;
  hash_T hash;
  hashitem_T  *hi;
  sftword_T   *sft;
  int bc, gc;
  int limit;

  // It's very well possible that the same soundfold word is found several
  // times with different scores.  Since the following is quite slow only do
  // the words that have a better score than before.  Use a hashtable to
  // remember the words that have been done.
  hash = hash_hash(goodword);
  const size_t goodword_len = STRLEN(goodword);
  hi = hash_lookup(&slang->sl_sounddone, (const char *)goodword, goodword_len,
                   hash);
  if (HASHITEM_EMPTY(hi)) {
    sft = xmalloc(sizeof(sftword_T) + goodword_len);
    sft->sft_score = score;
    memcpy(sft->sft_word, goodword, goodword_len + 1);
    hash_add_item(&slang->sl_sounddone, hi, sft->sft_word, hash);
  } else {
    sft = HI2SFT(hi);
    if (score >= sft->sft_score)
      return;
    sft->sft_score = score;
  }

  // Find the word nr in the soundfold tree.
  sfwordnr = soundfold_find(slang, goodword);
  if (sfwordnr < 0) {
    internal_error("add_sound_suggest()");
    return;
  }

  // Go over the list of good words that produce this soundfold word
  nrline = ml_get_buf(slang->sl_sugbuf, (linenr_T)sfwordnr + 1, false);
  orgnr = 0;
  while (*nrline != NUL) {
    // The wordnr was stored in a minimal nr of bytes as an offset to the
    // previous wordnr.
    orgnr += bytes2offset(&nrline);

    byts = slang->sl_fbyts;
    idxs = slang->sl_fidxs;

    // Lookup the word "orgnr" one of the two tries.
    n = 0;
    wordcount = 0;
    for (wlen = 0; wlen < MAXWLEN - 3; ++wlen) {
      i = 1;
      if (wordcount == orgnr && byts[n + 1] == NUL)
        break;          // found end of word

      if (byts[n + 1] == NUL)
        ++wordcount;

      // skip over the NUL bytes
      for (; byts[n + i] == NUL; ++i)
        if (i > byts[n]) {              // safety check
          STRCPY(theword + wlen, "BAD");
          wlen += 3;
          goto badword;
        }

      // One of the siblings must have the word.
      for (; i < byts[n]; ++i) {
        wc = idxs[idxs[n + i]];         // nr of words under this byte
        if (wordcount + wc > orgnr)
          break;
        wordcount += wc;
      }

      theword[wlen] = byts[n + i];
      n = idxs[n + i];
    }
badword:
    theword[wlen] = NUL;

    // Go over the possible flags and regions.
    for (; i <= byts[n] && byts[n + i] == NUL; ++i) {
      char_u cword[MAXWLEN];
      char_u      *p;
      int flags = (int)idxs[n + i];

      // Skip words with the NOSUGGEST flag
      if (flags & WF_NOSUGGEST)
        continue;

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
        } else
          p = theword;
      }

      // Add the suggestion.
      if (sps_flags & SPS_DOUBLE) {
        // Add the suggestion if the score isn't too bad.
        if (score <= su->su_maxscore)
          add_suggestion(su, &su->su_sga, p, su->su_badlen,
              score, 0, false, slang, false);
      } else {
        // Add a penalty for words in another region.
        if ((flags & WF_REGION)
            && (((unsigned)flags >> 16) & lp->lp_region) == 0)
          goodscore = SCORE_REGION;
        else
          goodscore = 0;

        // Add a small penalty for changing the first letter from
        // lower to upper case.  Helps for "tath" -> "Kath", which is
        // less common than "tath" -> "path".  Don't do it when the
        // letter is the same, that has already been counted.
        gc = PTR2CHAR(p);
        if (SPELL_ISUPPER(gc)) {
          bc = PTR2CHAR(su->su_badword);
          if (!SPELL_ISUPPER(bc)
              && SPELL_TOFOLD(bc) != SPELL_TOFOLD(gc))
            goodscore += SCORE_ICASE / 2;
        }

        // Compute the score for the good word.  This only does letter
        // insert/delete/swap/replace.  REP items are not considered,
        // which may make the score a bit higher.
        // Use a limit for the score to make it work faster.  Use
        // MAXSCORE(), because RESCORE() will change the score.
        // If the limit is very high then the iterative method is
        // inefficient, using an array is quicker.
        limit = MAXSCORE(su->su_sfmaxscore - goodscore, score);
        if (limit > SCORE_LIMITMAX)
          goodscore += spell_edit_score(slang, su->su_badword, p);
        else
          goodscore += spell_edit_score_limit(slang, su->su_badword,
              p, limit);

        // When going over the limit don't bother to do the rest.
        if (goodscore < SCORE_MAXMAX) {
          // Give a bonus to words seen before.
          goodscore = score_wordcount_adj(slang, goodscore, p, false);

          // Add the suggestion if the score isn't too bad.
          goodscore = RESCORE(goodscore, score);
          if (goodscore <= su->su_sfmaxscore)
            add_suggestion(su, &su->su_ga, p, su->su_badlen,
                goodscore, score, true, slang, true);
        }
      }
    }
  }
}

// Find word "word" in fold-case tree for "slang" and return the word number.
static int soundfold_find(slang_T *slang, char_u *word)
{
  idx_T arridx = 0;
  int len;
  int wlen = 0;
  int c;
  char_u      *ptr = word;
  char_u      *byts;
  idx_T       *idxs;
  int wordnr = 0;

  byts = slang->sl_sbyts;
  idxs = slang->sl_sidxs;

  for (;; ) {
    // First byte is the number of possible bytes.
    len = byts[arridx++];

    // If the first possible byte is a zero the word could end here.
    // If the word ends we found the word.  If not skip the NUL bytes.
    c = ptr[wlen];
    if (byts[arridx] == NUL) {
      if (c == NUL)
        break;

      // Skip over the zeros, there can be several.
      while (len > 0 && byts[arridx] == NUL) {
        ++arridx;
        --len;
      }
      if (len == 0)
        return -1;            // no children, word should have ended here
      ++wordnr;
    }

    // If the word ends we didn't find it.
    if (c == NUL)
      return -1;

    // Perform a binary search in the list of accepted bytes.
    if (c == TAB)           // <Tab> is handled like <Space>
      c = ' ';
    while (byts[arridx] < c) {
      // The word count is in the first idxs[] entry of the child.
      wordnr += idxs[idxs[arridx]];
      ++arridx;
      if (--len == 0)           // end of the bytes, didn't find it
        return -1;
    }
    if (byts[arridx] != c)      // didn't find the byte
      return -1;

    // Continue at the child (if there is one).
    arridx = idxs[arridx];
    ++wlen;

    // One space in the good word may stand for several spaces in the
    // checked word.
    if (c == ' ')
      while (ptr[wlen] == ' ' || ptr[wlen] == TAB)
        ++wlen;
  }

  return wordnr;
}

// Copy "fword" to "cword", fixing case according to "flags".
static void make_case_word(char_u *fword, char_u *cword, int flags)
{
  if (flags & WF_ALLCAP)
    // Make it all upper-case
    allcap_copy(fword, cword);
  else if (flags & WF_ONECAP)
    // Make the first letter upper-case
    onecap_copy(fword, cword, true);
  else
    // Use goodword as-is.
    STRCPY(cword, fword);
}

// Returns true if "c1" and "c2" are similar characters according to the MAP
// lines in the .aff file.
static bool similar_chars(slang_T *slang, int c1, int c2)
{
  int m1, m2;
  char_u buf[MB_MAXBYTES + 1];
  hashitem_T  *hi;

  if (c1 >= 256) {
    buf[utf_char2bytes(c1, buf)] = 0;
    hi = hash_find(&slang->sl_map_hash, buf);
    if (HASHITEM_EMPTY(hi)) {
      m1 = 0;
    } else {
      m1 = utf_ptr2char(hi->hi_key + STRLEN(hi->hi_key) + 1);
    }
  } else {
    m1 = slang->sl_map_array[c1];
  }
  if (m1 == 0) {
    return false;
  }

  if (c2 >= 256) {
    buf[utf_char2bytes(c2, buf)] = 0;
    hi = hash_find(&slang->sl_map_hash, buf);
    if (HASHITEM_EMPTY(hi)) {
      m2 = 0;
    } else {
      m2 = utf_ptr2char(hi->hi_key + STRLEN(hi->hi_key) + 1);
    }
  } else {
    m2 = slang->sl_map_array[c2];
  }

  return m1 == m2;
}

// Adds a suggestion to the list of suggestions.
// For a suggestion that is already in the list the lowest score is remembered.
static void
add_suggestion (
    suginfo_T *su,
    garray_T *gap,              // either su_ga or su_sga
    const char_u *goodword,
    int badlenarg,              // len of bad word replaced with "goodword"
    int score,
    int altscore,
    bool had_bonus,             // value for st_had_bonus
    slang_T *slang,             // language for sound folding
    bool maxsf                  // su_maxscore applies to soundfold score,
                                // su_sfmaxscore to the total score.
)
{
  int goodlen;                  // len of goodword changed
  int badlen;                   // len of bad word changed
  suggest_T   *stp;
  suggest_T new_sug;

  // Minimize "badlen" for consistency.  Avoids that changing "the the" to
  // "thee the" is added next to changing the first "the" the "thee".
  const char_u *pgood = goodword + STRLEN(goodword);
  char_u *pbad = su->su_badptr + badlenarg;
  for (;; ) {
    goodlen = (int)(pgood - goodword);
    badlen = (int)(pbad - su->su_badptr);
    if (goodlen <= 0 || badlen <= 0)
      break;
    MB_PTR_BACK(goodword, pgood);
    MB_PTR_BACK(su->su_badptr, pbad);
    if (utf_ptr2char(pgood) != utf_ptr2char(pbad)) {
      break;
    }
  }

  if (badlen == 0 && goodlen == 0)
    // goodword doesn't change anything; may happen for "the the" changing
    // the first "the" to itself.
    return;

  int i;
  if (GA_EMPTY(gap)) {
    i = -1;
  } else {
    // Check if the word is already there.  Also check the length that is
    // being replaced "thes," -> "these" is a different suggestion from
    // "thes" -> "these".
    stp = &SUG(*gap, 0);
    for (i = gap->ga_len; --i >= 0; ++stp) {
      if (stp->st_wordlen == goodlen
          && stp->st_orglen == badlen
          && STRNCMP(stp->st_word, goodword, goodlen) == 0) {
        // Found it.  Remember the word with the lowest score.
        if (stp->st_slang == NULL)
          stp->st_slang = slang;

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
          if (had_bonus)
            rescore_one(su, stp);
          else {
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
    stp->st_word = vim_strnsave(goodword, goodlen);
    stp->st_wordlen = goodlen;
    stp->st_score = score;
    stp->st_altscore = altscore;
    stp->st_had_bonus = had_bonus;
    stp->st_orglen = badlen;
    stp->st_slang = slang;

    // If we have too many suggestions now, sort the list and keep
    // the best suggestions.
    if (gap->ga_len > SUG_MAX_COUNT(su)) {
      if (maxsf)
        su->su_sfmaxscore = cleanup_suggestions(gap,
            su->su_sfmaxscore, SUG_CLEAN_COUNT(su));
      else
        su->su_maxscore = cleanup_suggestions(gap,
            su->su_maxscore, SUG_CLEAN_COUNT(su));
    }
  }
}

// Suggestions may in fact be flagged as errors.  Esp. for banned words and
// for split words, such as "the the".  Remove these from the list here.
static void
check_suggestions (
    suginfo_T *su,
    garray_T *gap                   // either su_ga or su_sga
)
{
  suggest_T   *stp;
  char_u longword[MAXWLEN + 1];
  int len;
  hlf_T attr;

  stp = &SUG(*gap, 0);
  for (int i = gap->ga_len - 1; i >= 0; --i) {
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
      --gap->ga_len;
      if (i < gap->ga_len)
        memmove(stp + i, stp + i + 1,
            sizeof(suggest_T) * (gap->ga_len - i));
    }
  }
}


// Add a word to be banned.
static void add_banned(suginfo_T *su, char_u *word)
{
  char_u      *s;
  hash_T hash;
  hashitem_T  *hi;

  hash = hash_hash(word);
  const size_t word_len = STRLEN(word);
  hi = hash_lookup(&su->su_banned, (const char *)word, word_len, hash);
  if (HASHITEM_EMPTY(hi)) {
    s = xmemdupz(word, word_len);
    hash_add_item(&su->su_banned, hi, s, hash);
  }
}

// Recompute the score for all suggestions if sound-folding is possible.  This
// is slow, thus only done for the final results.
static void rescore_suggestions(suginfo_T *su)
{
  if (su->su_sallang != NULL) {
    for (int i = 0; i < su->su_ga.ga_len; ++i) {
      rescore_one(su, &SUG(su->su_ga, i));
    }
  }
}

// Recompute the score for one suggestion if sound-folding is possible.
static void rescore_one(suginfo_T *su, suggest_T *stp)
{
  slang_T     *slang = stp->st_slang;
  char_u sal_badword[MAXWLEN];
  char_u      *p;

  // Only rescore suggestions that have no sal score yet and do have a
  // language.
  if (slang != NULL && !GA_EMPTY(&slang->sl_sal) && !stp->st_had_bonus) {
    if (slang == su->su_sallang)
      p = su->su_sal_badword;
    else {
      spell_soundfold(slang, su->su_fbadword, true, sal_badword);
      p = sal_badword;
    }

    stp->st_altscore = stp_sal_score(stp, su, slang, p);
    if (stp->st_altscore == SCORE_MAXMAX)
      stp->st_altscore = SCORE_BIG;
    stp->st_score = RESCORE(stp->st_score, stp->st_altscore);
    stp->st_had_bonus = true;
  }
}


// Function given to qsort() to sort the suggestions on st_score.
// First on "st_score", then "st_altscore" then alphabetically.
static int sug_compare(const void *s1, const void *s2)
{
  suggest_T   *p1 = (suggest_T *)s1;
  suggest_T   *p2 = (suggest_T *)s2;
  int n = p1->st_score - p2->st_score;

  if (n == 0) {
    n = p1->st_altscore - p2->st_altscore;
    if (n == 0)
      n = STRICMP(p1->st_word, p2->st_word);
  }
  return n;
}

// Cleanup the suggestions:
// - Sort on score.
// - Remove words that won't be displayed.
// Returns the maximum score in the list or "maxscore" unmodified.
static int
cleanup_suggestions (
    garray_T *gap,
    int maxscore,
    int keep                       // nr of suggestions to keep
)
{
  suggest_T   *stp = &SUG(*gap, 0);

  // Sort the list.
  qsort(gap->ga_data, (size_t)gap->ga_len, sizeof(suggest_T), sug_compare);

  // Truncate the list to the number of suggestions that will be displayed.
  if (gap->ga_len > keep) {
    for (int i = keep; i < gap->ga_len; ++i) {
      xfree(stp[i].st_word);
    }
    gap->ga_len = keep;
    return stp[keep - 1].st_score;
  }
  return maxscore;
}

/// Soundfold a string, for soundfold()
///
/// @param[in]  word  Word to soundfold.
///
/// @return [allocated] soundfolded string or NULL in case of error. May return
///                     copy of the input string if soundfolding is not
///                     supported by any of the languages in &spellang.
char *eval_soundfold(const char *const word)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  if (curwin->w_p_spell && *curwin->w_s->b_p_spl != NUL) {
    // Use the sound-folding of the first language that supports it.
    for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
      langp_T *const lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
      if (!GA_EMPTY(&lp->lp_slang->sl_sal)) {
        // soundfold the word
        char_u sound[MAXWLEN];
        spell_soundfold(lp->lp_slang, (char_u *)word, false, sound);
        return xstrdup((const char *)sound);
      }
    }
  }

  // No language with sound folding, return word as-is.
  return xstrdup(word);
}

/// Turn "inword" into its sound-a-like equivalent in "res[MAXWLEN]".
///
/// There are many ways to turn a word into a sound-a-like representation.  The
/// oldest is Soundex (1918!).   A nice overview can be found in "Approximate
/// swedish name matching - survey and test of different algorithms" by Klas
/// Erikson.
///
/// We support two methods:
/// 1. SOFOFROM/SOFOTO do a simple character mapping.
/// 2. SAL items define a more advanced sound-folding (and much slower).
///
/// @param[in]  slang
/// @param[in]  inword  word to soundfold
/// @param[in]  folded  whether inword is already case-folded
/// @param[in,out]  res  destination for soundfolded word
void spell_soundfold(slang_T *slang, char_u *inword, bool folded, char_u *res)
{
  char_u fword[MAXWLEN];
  char_u      *word;

  if (slang->sl_sofo)
    // SOFOFROM and SOFOTO used
    spell_soundfold_sofo(slang, inword, res);
  else {
    // SAL items used.  Requires the word to be case-folded.
    if (folded)
      word = inword;
    else {
      (void)spell_casefold(inword, (int)STRLEN(inword), fword, MAXWLEN);
      word = fword;
    }

    if (has_mbyte)
      spell_soundfold_wsal(slang, word, res);
    else
      spell_soundfold_sal(slang, word, res);
  }
}

// Perform sound folding of "inword" into "res" according to SOFOFROM and
// SOFOTO lines.
static void spell_soundfold_sofo(slang_T *slang, char_u *inword, char_u *res)
{
  char_u      *s;
  int ri = 0;
  int c;

  if (has_mbyte) {
    int prevc = 0;
    int     *ip;

    // The sl_sal_first[] table contains the translation for chars up to
    // 255, sl_sal the rest.
    for (s = inword; *s != NUL; ) {
      c = mb_cptr2char_adv((const char_u **)&s);
      if (enc_utf8 ? utf_class(c) == 0 : ascii_iswhite(c)) {
        c = ' ';
      } else if (c < 256) {
        c = slang->sl_sal_first[c];
      } else {
        ip = ((int **)slang->sl_sal.ga_data)[c & 0xff];
        if (ip == NULL)                 // empty list, can't match
          c = NUL;
        else
          for (;; ) {                   // find "c" in the list
            if (*ip == 0) {             // not found
              c = NUL;
              break;
            }
            if (*ip == c) {             // match!
              c = ip[1];
              break;
            }
            ip += 2;
          }
      }

      if (c != NUL && c != prevc) {
        ri += utf_char2bytes(c, res + ri);
        if (ri + MB_MAXBYTES > MAXWLEN) {
          break;
        }
        prevc = c;
      }
    }
  } else {
    // The sl_sal_first[] table contains the translation.
    for (s = inword; (c = *s) != NUL; ++s) {
      if (ascii_iswhite(c))
        c = ' ';
      else
        c = slang->sl_sal_first[c];
      if (c != NUL && (ri == 0 || res[ri - 1] != c))
        res[ri++] = c;
    }
  }

  res[ri] = NUL;
}

static void spell_soundfold_sal(slang_T *slang, char_u *inword, char_u *res)
{
  salitem_T   *smp;
  char_u word[MAXWLEN];
  char_u      *s = inword;
  char_u      *t;
  char_u      *pf;
  int i, j, z;
  int reslen;
  int n, k = 0;
  int z0;
  int k0;
  int n0;
  int c;
  int pri;
  int p0 = -333;
  int c0;

  // Remove accents, if wanted.  We actually remove all non-word characters.
  // But keep white space.  We need a copy, the word may be changed here.
  if (slang->sl_rem_accents) {
    t = word;
    while (*s != NUL) {
      if (ascii_iswhite(*s)) {
        *t++ = ' ';
        s = skipwhite(s);
      } else {
        if (spell_iswordp_nmw(s, curwin))
          *t++ = *s;
        ++s;
      }
    }
    *t = NUL;
  } else
    STRLCPY(word, s, MAXWLEN);

  smp = (salitem_T *)slang->sl_sal.ga_data;

  // This comes from Aspell phonet.cpp.  Converted from C++ to C.
  // Changed to keep spaces.
  i = reslen = z = 0;
  while ((c = word[i]) != NUL) {
    // Start with the first rule that has the character in the word.
    n = slang->sl_sal_first[c];
    z0 = 0;

    if (n >= 0) {
      // check all rules for the same letter
      for (; (s = smp[n].sm_lead)[0] == c; ++n) {
        // Quickly skip entries that don't match the word.  Most
        // entries are less then three chars, optimize for that.
        k = smp[n].sm_leadlen;
        if (k > 1) {
          if (word[i + 1] != s[1])
            continue;
          if (k > 2) {
            for (j = 2; j < k; ++j)
              if (word[i + j] != s[j])
                break;
            if (j < k)
              continue;
          }
        }

        if ((pf = smp[n].sm_oneof) != NULL) {
          // Check for match with one of the chars in "sm_oneof".
          while (*pf != NUL && *pf != word[i + k])
            ++pf;
          if (*pf == NUL)
            continue;
          ++k;
        }
        s = smp[n].sm_rules;
        pri = 5;            // default priority

        p0 = *s;
        k0 = k;
        while (*s == '-' && k > 1) {
          k--;
          s++;
        }
        if (*s == '<')
          s++;
        if (ascii_isdigit(*s)) {
          // determine priority
          pri = *s - '0';
          s++;
        }
        if (*s == '^' && *(s + 1) == '^')
          s++;

        if (*s == NUL
            || (*s == '^'
                && (i == 0 || !(word[i - 1] == ' '
                                || spell_iswordp(word + i - 1, curwin)))
                && (*(s + 1) != '$'
                    || (!spell_iswordp(word + i + k0, curwin))))
            || (*s == '$' && i > 0
                && spell_iswordp(word + i - 1, curwin)
                && (!spell_iswordp(word + i + k0, curwin)))) {
          // search for followup rules, if:
          // followup and k > 1  and  NO '-' in searchstring
          c0 = word[i + k - 1];
          n0 = slang->sl_sal_first[c0];

          if (slang->sl_followup && k > 1 && n0 >= 0
              && p0 != '-' && word[i + k] != NUL) {
            // test follow-up rule for "word[i + k]"
            for (; (s = smp[n0].sm_lead)[0] == c0; ++n0) {
              // Quickly skip entries that don't match the word.
              k0 = smp[n0].sm_leadlen;
              if (k0 > 1) {
                if (word[i + k] != s[1])
                  continue;
                if (k0 > 2) {
                  pf = word + i + k + 1;
                  for (j = 2; j < k0; ++j)
                    if (*pf++ != s[j])
                      break;
                  if (j < k0)
                    continue;
                }
              }
              k0 += k - 1;

              if ((pf = smp[n0].sm_oneof) != NULL) {
                // Check for match with one of the chars in
                // "sm_oneof".
                while (*pf != NUL && *pf != word[i + k0])
                  ++pf;
                if (*pf == NUL)
                  continue;
                ++k0;
              }

              p0 = 5;
              s = smp[n0].sm_rules;
              while (*s == '-') {
                // "k0" gets NOT reduced because
                // "if (k0 == k)"
                s++;
              }
              if (*s == '<')
                s++;
              if (ascii_isdigit(*s)) {
                p0 = *s - '0';
                s++;
              }

              if (*s == NUL
                  // *s == '^' cuts
                  || (*s == '$'
                      && !spell_iswordp(word + i + k0,
                          curwin))) {
                if (k0 == k)
                  // this is just a piece of the string
                  continue;

                if (p0 < pri)
                  // priority too low
                  continue;
                // rule fits; stop search
                break;
              }
            }

            if (p0 >= pri && smp[n0].sm_lead[0] == c0)
              continue;
          }

          // replace string
          s = smp[n].sm_to;
          if (s == NULL)
            s = (char_u *)"";
          pf = smp[n].sm_rules;
          p0 = (vim_strchr(pf, '<') != NULL) ? 1 : 0;
          if (p0 == 1 && z == 0) {
            // rule with '<' is used
            if (reslen > 0 && *s != NUL && (res[reslen - 1] == c
                                            || res[reslen - 1] == *s))
              reslen--;
            z0 = 1;
            z = 1;
            k0 = 0;
            while (*s != NUL && word[i + k0] != NUL) {
              word[i + k0] = *s;
              k0++;
              s++;
            }
            if (k > k0)
              STRMOVE(word + i + k0, word + i + k);

            // new "actual letter"
            c = word[i];
          } else {
            // no '<' rule used
            i += k - 1;
            z = 0;
            while (*s != NUL && s[1] != NUL && reslen < MAXWLEN) {
              if (reslen == 0 || res[reslen - 1] != *s)
                res[reslen++] = *s;
              s++;
            }
            // new "actual letter"
            c = *s;
            if (strstr((char *)pf, "^^") != NULL) {
              if (c != NUL)
                res[reslen++] = c;
              STRMOVE(word, word + i + 1);
              i = 0;
              z0 = 1;
            }
          }
          break;
        }
      }
    } else if (ascii_iswhite(c))   {
      c = ' ';
      k = 1;
    }

    if (z0 == 0) {
      if (k && !p0 && reslen < MAXWLEN && c != NUL
          && (!slang->sl_collapse || reslen == 0
              || res[reslen - 1] != c))
        // condense only double letters
        res[reslen++] = c;

      i++;
      z = 0;
      k = 0;
    }
  }

  res[reslen] = NUL;
}

// Turn "inword" into its sound-a-like equivalent in "res[MAXWLEN]".
// Multi-byte version of spell_soundfold().
static void spell_soundfold_wsal(slang_T *slang, char_u *inword, char_u *res)
{
  salitem_T   *smp = (salitem_T *)slang->sl_sal.ga_data;
  int word[MAXWLEN];
  int wres[MAXWLEN];
  int l;
  int         *ws;
  int         *pf;
  int i, j, z;
  int reslen;
  int n, k = 0;
  int z0;
  int k0;
  int n0;
  int c;
  int pri;
  int p0 = -333;
  int c0;
  bool did_white = false;
  int wordlen;


  // Convert the multi-byte string to a wide-character string.
  // Remove accents, if wanted.  We actually remove all non-word characters.
  // But keep white space.
  wordlen = 0;
  for (const char_u *s = inword; *s != NUL; ) {
    const char_u *t = s;
    c = mb_cptr2char_adv((const char_u **)&s);
    if (slang->sl_rem_accents) {
      if (enc_utf8 ? utf_class(c) == 0 : ascii_iswhite(c)) {
        if (did_white)
          continue;
        c = ' ';
        did_white = true;
      } else {
        did_white = false;
        if (!spell_iswordp_nmw(t, curwin)) {
          continue;
        }
      }
    }
    word[wordlen++] = c;
  }
  word[wordlen] = NUL;

  // This algorithm comes from Aspell phonet.cpp.
  // Converted from C++ to C.  Added support for multi-byte chars.
  // Changed to keep spaces.
  i = reslen = z = 0;
  while ((c = word[i]) != NUL) {
    // Start with the first rule that has the character in the word.
    n = slang->sl_sal_first[c & 0xff];
    z0 = 0;

    if (n >= 0) {
      // Check all rules for the same index byte.
      // If c is 0x300 need extra check for the end of the array, as
      // (c & 0xff) is NUL.
      for (; ((ws = smp[n].sm_lead_w)[0] & 0xff) == (c & 0xff)
           && ws[0] != NUL; ++n) {
        // Quickly skip entries that don't match the word.  Most
        // entries are less then three chars, optimize for that.
        if (c != ws[0])
          continue;
        k = smp[n].sm_leadlen;
        if (k > 1) {
          if (word[i + 1] != ws[1])
            continue;
          if (k > 2) {
            for (j = 2; j < k; ++j)
              if (word[i + j] != ws[j])
                break;
            if (j < k)
              continue;
          }
        }

        if ((pf = smp[n].sm_oneof_w) != NULL) {
          // Check for match with one of the chars in "sm_oneof".
          while (*pf != NUL && *pf != word[i + k])
            ++pf;
          if (*pf == NUL)
            continue;
          ++k;
        }
        char_u *s = smp[n].sm_rules;
        pri = 5;            // default priority

        p0 = *s;
        k0 = k;
        while (*s == '-' && k > 1) {
          k--;
          s++;
        }
        if (*s == '<')
          s++;
        if (ascii_isdigit(*s)) {
          // determine priority
          pri = *s - '0';
          s++;
        }
        if (*s == '^' && *(s + 1) == '^')
          s++;

        if (*s == NUL
            || (*s == '^'
                && (i == 0 || !(word[i - 1] == ' '
                                || spell_iswordp_w(word + i - 1, curwin)))
                && (*(s + 1) != '$'
                    || (!spell_iswordp_w(word + i + k0, curwin))))
            || (*s == '$' && i > 0
                && spell_iswordp_w(word + i - 1, curwin)
                && (!spell_iswordp_w(word + i + k0, curwin)))) {
          // search for followup rules, if:
          // followup and k > 1  and  NO '-' in searchstring
          c0 = word[i + k - 1];
          n0 = slang->sl_sal_first[c0 & 0xff];

          if (slang->sl_followup && k > 1 && n0 >= 0
              && p0 != '-' && word[i + k] != NUL) {
            // Test follow-up rule for "word[i + k]"; loop over
            // all entries with the same index byte.
            for (; ((ws = smp[n0].sm_lead_w)[0] & 0xff)
                 == (c0 & 0xff); ++n0) {
              // Quickly skip entries that don't match the word.
              if (c0 != ws[0])
                continue;
              k0 = smp[n0].sm_leadlen;
              if (k0 > 1) {
                if (word[i + k] != ws[1])
                  continue;
                if (k0 > 2) {
                  pf = word + i + k + 1;
                  for (j = 2; j < k0; ++j)
                    if (*pf++ != ws[j])
                      break;
                  if (j < k0)
                    continue;
                }
              }
              k0 += k - 1;

              if ((pf = smp[n0].sm_oneof_w) != NULL) {
                // Check for match with one of the chars in
                // "sm_oneof".
                while (*pf != NUL && *pf != word[i + k0])
                  ++pf;
                if (*pf == NUL)
                  continue;
                ++k0;
              }

              p0 = 5;
              s = smp[n0].sm_rules;
              while (*s == '-') {
                // "k0" gets NOT reduced because
                // "if (k0 == k)"
                s++;
              }
              if (*s == '<')
                s++;
              if (ascii_isdigit(*s)) {
                p0 = *s - '0';
                s++;
              }

              if (*s == NUL
                  // *s == '^' cuts
                  || (*s == '$'
                      && !spell_iswordp_w(word + i + k0,
                          curwin))) {
                if (k0 == k)
                  // this is just a piece of the string
                  continue;

                if (p0 < pri)
                  // priority too low
                  continue;
                // rule fits; stop search
                break;
              }
            }

            if (p0 >= pri && (smp[n0].sm_lead_w[0] & 0xff)
                == (c0 & 0xff))
              continue;
          }

          // replace string
          ws = smp[n].sm_to_w;
          s = smp[n].sm_rules;
          p0 = (vim_strchr(s, '<') != NULL) ? 1 : 0;
          if (p0 == 1 && z == 0) {
            // rule with '<' is used
            if (reslen > 0 && ws != NULL && *ws != NUL
                && (wres[reslen - 1] == c
                    || wres[reslen - 1] == *ws))
              reslen--;
            z0 = 1;
            z = 1;
            k0 = 0;
            if (ws != NULL)
              while (*ws != NUL && word[i + k0] != NUL) {
                word[i + k0] = *ws;
                k0++;
                ws++;
              }
            if (k > k0)
              memmove(word + i + k0, word + i + k,
                  sizeof(int) * (wordlen - (i + k) + 1));

            // new "actual letter"
            c = word[i];
          } else {
            // no '<' rule used
            i += k - 1;
            z = 0;
            if (ws != NULL)
              while (*ws != NUL && ws[1] != NUL
                     && reslen < MAXWLEN) {
                if (reslen == 0 || wres[reslen - 1] != *ws)
                  wres[reslen++] = *ws;
                ws++;
              }
            // new "actual letter"
            if (ws == NULL)
              c = NUL;
            else
              c = *ws;
            if (strstr((char *)s, "^^") != NULL) {
              if (c != NUL)
                wres[reslen++] = c;
              memmove(word, word + i + 1,
                  sizeof(int) * (wordlen - (i + 1) + 1));
              i = 0;
              z0 = 1;
            }
          }
          break;
        }
      }
    } else if (ascii_iswhite(c))   {
      c = ' ';
      k = 1;
    }

    if (z0 == 0) {
      if (k && !p0 && reslen < MAXWLEN && c != NUL
          && (!slang->sl_collapse || reslen == 0
              || wres[reslen - 1] != c))
        // condense only double letters
        wres[reslen++] = c;

      i++;
      z = 0;
      k = 0;
    }
  }

  // Convert wide characters in "wres" to a multi-byte string in "res".
  l = 0;
  for (n = 0; n < reslen; n++) {
    l += utf_char2bytes(wres[n], res + l);
    if (l + MB_MAXBYTES > MAXWLEN) {
      break;
    }
  }
  res[l] = NUL;
}

// Compute a score for two sound-a-like words.
// This permits up to two inserts/deletes/swaps/etc. to keep things fast.
// Instead of a generic loop we write out the code.  That keeps it fast by
// avoiding checks that will not be possible.
static int
soundalike_score (
    char_u *goodstart,         // sound-folded good word
    char_u *badstart          // sound-folded bad word
)
{
  char_u      *goodsound = goodstart;
  char_u      *badsound = badstart;
  int goodlen;
  int badlen;
  int n;
  char_u      *pl, *ps;
  char_u      *pl2, *ps2;
  int score = 0;

  // Adding/inserting "*" at the start (word starts with vowel) shouldn't be
  // counted so much, vowels in the middle of the word aren't counted at all.
  if ((*badsound == '*' || *goodsound == '*') && *badsound != *goodsound) {
    if ((badsound[0] == NUL && goodsound[1] == NUL)
        || (goodsound[0] == NUL && badsound[1] == NUL))
      // changing word with vowel to word without a sound
      return SCORE_DEL;
    if (badsound[0] == NUL || goodsound[0] == NUL)
      // more than two changes
      return SCORE_MAXMAX;

    if (badsound[1] == goodsound[1]
        || (badsound[1] != NUL
            && goodsound[1] != NUL
            && badsound[2] == goodsound[2])) {
      // handle like a substitute
    } else {
      score = 2 * SCORE_DEL / 3;
      if (*badsound == '*')
        ++badsound;
      else
        ++goodsound;
    }
  }

  goodlen = (int)STRLEN(goodsound);
  badlen = (int)STRLEN(badsound);

  // Return quickly if the lengths are too different to be fixed by two
  // changes.
  n = goodlen - badlen;
  if (n < -2 || n > 2)
    return SCORE_MAXMAX;

  if (n > 0) {
    pl = goodsound;         // goodsound is longest
    ps = badsound;
  } else {
    pl = badsound;          // badsound is longest
    ps = goodsound;
  }

  // Skip over the identical part.
  while (*pl == *ps && *pl != NUL) {
    ++pl;
    ++ps;
  }

  switch (n) {
  case -2:
  case 2:
    // Must delete two characters from "pl".
    ++pl;               // first delete
    while (*pl == *ps) {
      ++pl;
      ++ps;
    }
    // strings must be equal after second delete
    if (STRCMP(pl + 1, ps) == 0)
      return score + SCORE_DEL * 2;

    // Failed to compare.
    break;

  case -1:
  case 1:
    // Minimal one delete from "pl" required.

    // 1: delete
    pl2 = pl + 1;
    ps2 = ps;
    while (*pl2 == *ps2) {
      if (*pl2 == NUL)                  // reached the end
        return score + SCORE_DEL;
      ++pl2;
      ++ps2;
    }

    // 2: delete then swap, then rest must be equal
    if (pl2[0] == ps2[1] && pl2[1] == ps2[0]
        && STRCMP(pl2 + 2, ps2 + 2) == 0)
      return score + SCORE_DEL + SCORE_SWAP;

    // 3: delete then substitute, then the rest must be equal
    if (STRCMP(pl2 + 1, ps2 + 1) == 0)
      return score + SCORE_DEL + SCORE_SUBST;

    // 4: first swap then delete
    if (pl[0] == ps[1] && pl[1] == ps[0]) {
      pl2 = pl + 2;                 // swap, skip two chars
      ps2 = ps + 2;
      while (*pl2 == *ps2) {
        ++pl2;
        ++ps2;
      }
      // delete a char and then strings must be equal
      if (STRCMP(pl2 + 1, ps2) == 0)
        return score + SCORE_SWAP + SCORE_DEL;
    }

    // 5: first substitute then delete
    pl2 = pl + 1;                   // substitute, skip one char
    ps2 = ps + 1;
    while (*pl2 == *ps2) {
      ++pl2;
      ++ps2;
    }
    // delete a char and then strings must be equal
    if (STRCMP(pl2 + 1, ps2) == 0)
      return score + SCORE_SUBST + SCORE_DEL;

    // Failed to compare.
    break;

  case 0:
    // Lengths are equal, thus changes must result in same length: An
    // insert is only possible in combination with a delete.
    // 1: check if for identical strings
    if (*pl == NUL)
      return score;

    // 2: swap
    if (pl[0] == ps[1] && pl[1] == ps[0]) {
      pl2 = pl + 2;                 // swap, skip two chars
      ps2 = ps + 2;
      while (*pl2 == *ps2) {
        if (*pl2 == NUL)                // reached the end
          return score + SCORE_SWAP;
        ++pl2;
        ++ps2;
      }
      // 3: swap and swap again
      if (pl2[0] == ps2[1] && pl2[1] == ps2[0]
          && STRCMP(pl2 + 2, ps2 + 2) == 0)
        return score + SCORE_SWAP + SCORE_SWAP;

      // 4: swap and substitute
      if (STRCMP(pl2 + 1, ps2 + 1) == 0)
        return score + SCORE_SWAP + SCORE_SUBST;
    }

    // 5: substitute
    pl2 = pl + 1;
    ps2 = ps + 1;
    while (*pl2 == *ps2) {
      if (*pl2 == NUL)                  // reached the end
        return score + SCORE_SUBST;
      ++pl2;
      ++ps2;
    }

    // 6: substitute and swap
    if (pl2[0] == ps2[1] && pl2[1] == ps2[0]
        && STRCMP(pl2 + 2, ps2 + 2) == 0)
      return score + SCORE_SUBST + SCORE_SWAP;

    // 7: substitute and substitute
    if (STRCMP(pl2 + 1, ps2 + 1) == 0)
      return score + SCORE_SUBST + SCORE_SUBST;

    // 8: insert then delete
    pl2 = pl;
    ps2 = ps + 1;
    while (*pl2 == *ps2) {
      ++pl2;
      ++ps2;
    }
    if (STRCMP(pl2 + 1, ps2) == 0)
      return score + SCORE_INS + SCORE_DEL;

    // 9: delete then insert
    pl2 = pl + 1;
    ps2 = ps;
    while (*pl2 == *ps2) {
      ++pl2;
      ++ps2;
    }
    if (STRCMP(pl2, ps2 + 1) == 0)
      return score + SCORE_INS + SCORE_DEL;

    // Failed to compare.
    break;
  }

  return SCORE_MAXMAX;
}

// Compute the "edit distance" to turn "badword" into "goodword".  The less
// deletes/inserts/substitutes/swaps are required the lower the score.
//
// The algorithm is described by Du and Chang, 1992.
// The implementation of the algorithm comes from Aspell editdist.cpp,
// edit_distance().  It has been converted from C++ to C and modified to
// support multi-byte characters.
static int spell_edit_score(slang_T *slang, char_u *badword, char_u *goodword)
{
  int *cnt;
  int j, i;
  int t;
  int bc, gc;
  int pbc, pgc;
  int wbadword[MAXWLEN];
  int wgoodword[MAXWLEN];
  const bool l_has_mbyte = has_mbyte;

  // Lengths with NUL.
  int badlen;
  int goodlen;
  if (l_has_mbyte) {
    // Get the characters from the multi-byte strings and put them in an
    // int array for easy access.
    badlen = 0;
    for (const char_u *p = badword; *p != NUL; ) {
      wbadword[badlen++] = mb_cptr2char_adv(&p);
    }
    wbadword[badlen++] = 0;
    goodlen = 0;
    for (const char_u *p = goodword; *p != NUL; ) {
      wgoodword[goodlen++] = mb_cptr2char_adv(&p);
    }
    wgoodword[goodlen++] = 0;
  } else {
    badlen = (int)STRLEN(badword) + 1;
    goodlen = (int)STRLEN(goodword) + 1;
  }

  // We use "cnt" as an array: CNT(badword_idx, goodword_idx).
#define CNT(a, b)   cnt[(a) + (b) * (badlen + 1)]
  cnt = xmalloc(sizeof(int) * (badlen + 1) * (goodlen + 1));

  CNT(0, 0) = 0;
  for (j = 1; j <= goodlen; ++j)
    CNT(0, j) = CNT(0, j - 1) + SCORE_INS;

  for (i = 1; i <= badlen; ++i) {
    CNT(i, 0) = CNT(i - 1, 0) + SCORE_DEL;
    for (j = 1; j <= goodlen; ++j) {
      if (l_has_mbyte) {
        bc = wbadword[i - 1];
        gc = wgoodword[j - 1];
      } else {
        bc = badword[i - 1];
        gc = goodword[j - 1];
      }
      if (bc == gc)
        CNT(i, j) = CNT(i - 1, j - 1);
      else {
        // Use a better score when there is only a case difference.
        if (SPELL_TOFOLD(bc) == SPELL_TOFOLD(gc))
          CNT(i, j) = SCORE_ICASE + CNT(i - 1, j - 1);
        else {
          // For a similar character use SCORE_SIMILAR.
          if (slang != NULL
              && slang->sl_has_map
              && similar_chars(slang, gc, bc))
            CNT(i, j) = SCORE_SIMILAR + CNT(i - 1, j - 1);
          else
            CNT(i, j) = SCORE_SUBST + CNT(i - 1, j - 1);
        }

        if (i > 1 && j > 1) {
          if (l_has_mbyte) {
            pbc = wbadword[i - 2];
            pgc = wgoodword[j - 2];
          } else {
            pbc = badword[i - 2];
            pgc = goodword[j - 2];
          }
          if (bc == pgc && pbc == gc) {
            t = SCORE_SWAP + CNT(i - 2, j - 2);
            if (t < CNT(i, j))
              CNT(i, j) = t;
          }
        }
        t = SCORE_DEL + CNT(i - 1, j);
        if (t < CNT(i, j))
          CNT(i, j) = t;
        t = SCORE_INS + CNT(i, j - 1);
        if (t < CNT(i, j))
          CNT(i, j) = t;
      }
    }
  }

  i = CNT(badlen - 1, goodlen - 1);
  xfree(cnt);
  return i;
}

// Like spell_edit_score(), but with a limit on the score to make it faster.
// May return SCORE_MAXMAX when the score is higher than "limit".
//
// This uses a stack for the edits still to be tried.
// The idea comes from Aspell leditdist.cpp.  Rewritten in C and added support
// for multi-byte characters.
static int spell_edit_score_limit(slang_T *slang, char_u *badword, char_u *goodword, int limit)
{
  limitscore_T stack[10];               // allow for over 3 * 2 edits
  int stackidx;
  int bi, gi;
  int bi2, gi2;
  int bc, gc;
  int score;
  int score_off;
  int minscore;
  int round;

  // Multi-byte characters require a bit more work, use a different function
  // to avoid testing "has_mbyte" quite often.
  if (has_mbyte)
    return spell_edit_score_limit_w(slang, badword, goodword, limit);

  // The idea is to go from start to end over the words.  So long as
  // characters are equal just continue, this always gives the lowest score.
  // When there is a difference try several alternatives.  Each alternative
  // increases "score" for the edit distance.  Some of the alternatives are
  // pushed unto a stack and tried later, some are tried right away.  At the
  // end of the word the score for one alternative is known.  The lowest
  // possible score is stored in "minscore".
  stackidx = 0;
  bi = 0;
  gi = 0;
  score = 0;
  minscore = limit + 1;

  for (;; ) {
    // Skip over an equal part, score remains the same.
    for (;; ) {
      bc = badword[bi];
      gc = goodword[gi];
      if (bc != gc)             // stop at a char that's different
        break;
      if (bc == NUL) {          // both words end
        if (score < minscore)
          minscore = score;
        goto pop;               // do next alternative
      }
      ++bi;
      ++gi;
    }

    if (gc == NUL) {      // goodword ends, delete badword chars
      do {
        if ((score += SCORE_DEL) >= minscore)
          goto pop;                 // do next alternative
      } while (badword[++bi] != NUL);
      minscore = score;
    } else if (bc == NUL)   { // badword ends, insert badword chars
      do {
        if ((score += SCORE_INS) >= minscore)
          goto pop;                 // do next alternative
      } while (goodword[++gi] != NUL);
      minscore = score;
    } else {                  // both words continue
      // If not close to the limit, perform a change.  Only try changes
      // that may lead to a lower score than "minscore".
      // round 0: try deleting a char from badword
      // round 1: try inserting a char in badword
      for (round = 0; round <= 1; ++round) {
        score_off = score + (round == 0 ? SCORE_DEL : SCORE_INS);
        if (score_off < minscore) {
          if (score_off + SCORE_EDIT_MIN >= minscore) {
            // Near the limit, rest of the words must match.  We
            // can check that right now, no need to push an item
            // onto the stack.
            bi2 = bi + 1 - round;
            gi2 = gi + round;
            while (goodword[gi2] == badword[bi2]) {
              if (goodword[gi2] == NUL) {
                minscore = score_off;
                break;
              }
              ++bi2;
              ++gi2;
            }
          } else {
            // try deleting/inserting a character later
            stack[stackidx].badi = bi + 1 - round;
            stack[stackidx].goodi = gi + round;
            stack[stackidx].score = score_off;
            ++stackidx;
          }
        }
      }

      if (score + SCORE_SWAP < minscore) {
        // If swapping two characters makes a match then the
        // substitution is more expensive, thus there is no need to
        // try both.
        if (gc == badword[bi + 1] && bc == goodword[gi + 1]) {
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
      if (SPELL_TOFOLD(bc) == SPELL_TOFOLD(gc))
        score += SCORE_ICASE;
      else {
        // For a similar character use SCORE_SIMILAR.
        if (slang != NULL
            && slang->sl_has_map
            && similar_chars(slang, gc, bc))
          score += SCORE_SIMILAR;
        else
          score += SCORE_SUBST;
      }

      if (score < minscore) {
        // Do the substitution.
        ++gi;
        ++bi;
        continue;
      }
    }
pop:
    // Get here to try the next alternative, pop it from the stack.
    if (stackidx == 0)                  // stack is empty, finished
      break;

    // pop an item from the stack
    --stackidx;
    gi = stack[stackidx].goodi;
    bi = stack[stackidx].badi;
    score = stack[stackidx].score;
  }

  // When the score goes over "limit" it may actually be much higher.
  // Return a very large number to avoid going below the limit when giving a
  // bonus.
  if (minscore > limit)
    return SCORE_MAXMAX;
  return minscore;
}

// Multi-byte version of spell_edit_score_limit().
// Keep it in sync with the above!
static int spell_edit_score_limit_w(slang_T *slang, char_u *badword, char_u *goodword, int limit)
{
  limitscore_T stack[10];               // allow for over 3 * 2 edits
  int stackidx;
  int bi, gi;
  int bi2, gi2;
  int bc, gc;
  int score;
  int score_off;
  int minscore;
  int round;
  int wbadword[MAXWLEN];
  int wgoodword[MAXWLEN];

  // Get the characters from the multi-byte strings and put them in an
  // int array for easy access.
  bi = 0;
  for (const char_u *p = badword; *p != NUL; ) {
    wbadword[bi++] = mb_cptr2char_adv(&p);
  }
  wbadword[bi++] = 0;
  gi = 0;
  for (const char_u *p = goodword; *p != NUL; ) {
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
  stackidx = 0;
  bi = 0;
  gi = 0;
  score = 0;
  minscore = limit + 1;

  for (;; ) {
    // Skip over an equal part, score remains the same.
    for (;; ) {
      bc = wbadword[bi];
      gc = wgoodword[gi];

      if (bc != gc)             // stop at a char that's different
        break;
      if (bc == NUL) {          // both words end
        if (score < minscore)
          minscore = score;
        goto pop;               // do next alternative
      }
      ++bi;
      ++gi;
    }

    if (gc == NUL) {      // goodword ends, delete badword chars
      do {
        if ((score += SCORE_DEL) >= minscore)
          goto pop;                 // do next alternative
      } while (wbadword[++bi] != NUL);
      minscore = score;
    } else if (bc == NUL)   { // badword ends, insert badword chars
      do {
        if ((score += SCORE_INS) >= minscore)
          goto pop;                 // do next alternative
      } while (wgoodword[++gi] != NUL);
      minscore = score;
    } else {                  // both words continue
      // If not close to the limit, perform a change.  Only try changes
      // that may lead to a lower score than "minscore".
      // round 0: try deleting a char from badword
      // round 1: try inserting a char in badword
      for (round = 0; round <= 1; ++round) {
        score_off = score + (round == 0 ? SCORE_DEL : SCORE_INS);
        if (score_off < minscore) {
          if (score_off + SCORE_EDIT_MIN >= minscore) {
            // Near the limit, rest of the words must match.  We
            // can check that right now, no need to push an item
            // onto the stack.
            bi2 = bi + 1 - round;
            gi2 = gi + round;
            while (wgoodword[gi2] == wbadword[bi2]) {
              if (wgoodword[gi2] == NUL) {
                minscore = score_off;
                break;
              }
              ++bi2;
              ++gi2;
            }
          } else {
            // try deleting a character from badword later
            stack[stackidx].badi = bi + 1 - round;
            stack[stackidx].goodi = gi + round;
            stack[stackidx].score = score_off;
            ++stackidx;
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
      if (SPELL_TOFOLD(bc) == SPELL_TOFOLD(gc))
        score += SCORE_ICASE;
      else {
        // For a similar character use SCORE_SIMILAR.
        if (slang != NULL
            && slang->sl_has_map
            && similar_chars(slang, gc, bc))
          score += SCORE_SIMILAR;
        else
          score += SCORE_SUBST;
      }

      if (score < minscore) {
        // Do the substitution.
        ++gi;
        ++bi;
        continue;
      }
    }
pop:
    // Get here to try the next alternative, pop it from the stack.
    if (stackidx == 0)                  // stack is empty, finished
      break;

    // pop an item from the stack
    --stackidx;
    gi = stack[stackidx].goodi;
    bi = stack[stackidx].badi;
    score = stack[stackidx].score;
  }

  // When the score goes over "limit" it may actually be much higher.
  // Return a very large number to avoid going below the limit when giving a
  // bonus.
  if (minscore > limit)
    return SCORE_MAXMAX;
  return minscore;
}

// ":spellinfo"
void ex_spellinfo(exarg_T *eap)
{
  if (no_spell_checking(curwin)) {
    return;
  }

  msg_start();
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len && !got_int; lpi++) {
    langp_T *const lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    msg_puts("file: ");
    msg_puts((const char *)lp->lp_slang->sl_fname);
    msg_putchar('\n');
    const char *const p = (const char *)lp->lp_slang->sl_info;
    if (p != NULL) {
      msg_puts(p);
      msg_putchar('\n');
    }
  }
  msg_end();
}

#define DUMPFLAG_KEEPCASE   1   // round 2: keep-case tree
#define DUMPFLAG_COUNT      2   // include word count
#define DUMPFLAG_ICASE      4   // ignore case when finding matches
#define DUMPFLAG_ONECAP     8   // pattern starts with capital
#define DUMPFLAG_ALLCAP     16  // pattern is all capitals

// ":spelldump"
void ex_spelldump(exarg_T *eap)
{
  char_u  *spl;
  long dummy;

  if (no_spell_checking(curwin)) {
    return;
  }
  get_option_value((char_u *)"spl", &dummy, &spl, OPT_LOCAL);

  // Create a new empty buffer in a new window.
  do_cmdline_cmd("new");

  // enable spelling locally in the new window
  set_option_value("spell", true, "", OPT_LOCAL);
  set_option_value("spl",  dummy, (char *)spl, OPT_LOCAL);
  xfree(spl);

  if (!BUFEMPTY()) {
    return;
  }

  spell_dump_compl(NULL, 0, NULL, eap->forceit ? DUMPFLAG_COUNT : 0);

  // Delete the empty line that we started with.
  if (curbuf->b_ml.ml_line_count > 1) {
    ml_delete(curbuf->b_ml.ml_line_count, false);
  }
  redraw_later(NOT_VALID);
}

// Go through all possible words and:
// 1. When "pat" is NULL: dump a list of all words in the current buffer.
//      "ic" and "dir" are not used.
// 2. When "pat" is not NULL: add matching words to insert mode completion.
void
spell_dump_compl (
    char_u *pat,           // leading part of the word
    int ic,                     // ignore case
    int *dir,           // direction for adding matches
    int dumpflags_arg              // DUMPFLAG_*
)
{
  langp_T     *lp;
  slang_T     *slang;
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  char_u word[MAXWLEN];
  int c;
  char_u      *byts;
  idx_T       *idxs;
  linenr_T lnum = 0;
  int round;
  int depth;
  int n;
  int flags;
  char_u      *region_names = NULL;         // region names being used
  bool do_region = true;                    // dump region names and numbers
  char_u      *p;
  int dumpflags = dumpflags_arg;
  int patlen;

  // When ignoring case or when the pattern starts with capital pass this on
  // to dump_word().
  if (pat != NULL) {
    if (ic)
      dumpflags |= DUMPFLAG_ICASE;
    else {
      n = captype(pat, NULL);
      if (n == WF_ONECAP)
        dumpflags |= DUMPFLAG_ONECAP;
      else if (n == WF_ALLCAP
               && (int)STRLEN(pat) > mb_ptr2len(pat)
               )
        dumpflags |= DUMPFLAG_ALLCAP;
    }
  }

  // Find out if we can support regions: All languages must support the same
  // regions or none at all.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    p = lp->lp_slang->sl_regions;
    if (p[0] != 0) {
      if (region_names == NULL)             // first language with regions
        region_names = p;
      else if (STRCMP(region_names, p) != 0) {
        do_region = false;                  // region names are different
        break;
      }
    }
  }

  if (do_region && region_names != NULL) {
    if (pat == NULL) {
      vim_snprintf((char *)IObuff, IOSIZE, "/regions=%s", region_names);
      ml_append(lnum++, IObuff, (colnr_T)0, false);
    }
  } else
    do_region = false;

  // Loop over all files loaded for the entries in 'spelllang'.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (slang->sl_fbyts == NULL)            // reloading failed
      continue;

    if (pat == NULL) {
      vim_snprintf((char *)IObuff, IOSIZE, "# file: %s", slang->sl_fname);
      ml_append(lnum++, IObuff, (colnr_T)0, false);
    }

    // When matching with a pattern and there are no prefixes only use
    // parts of the tree that match "pat".
    if (pat != NULL && slang->sl_pbyts == NULL)
      patlen = (int)STRLEN(pat);
    else
      patlen = -1;

    // round 1: case-folded tree
    // round 2: keep-case tree
    for (round = 1; round <= 2; ++round) {
      if (round == 1) {
        dumpflags &= ~DUMPFLAG_KEEPCASE;
        byts = slang->sl_fbyts;
        idxs = slang->sl_fidxs;
      } else {
        dumpflags |= DUMPFLAG_KEEPCASE;
        byts = slang->sl_kbyts;
        idxs = slang->sl_kidxs;
      }
      if (byts == NULL)
        continue;                       // array is empty

      depth = 0;
      arridx[0] = 0;
      curi[0] = 1;
      while (depth >= 0 && !got_int
             && (pat == NULL || !compl_interrupted)) {
        if (curi[depth] > byts[arridx[depth]]) {
          // Done all bytes at this node, go up one level.
          --depth;
          line_breakcheck();
          ins_compl_check_keys(50, false);
        } else {
          // Do one more byte at this node.
          n = arridx[depth] + curi[depth];
          ++curi[depth];
          c = byts[n];
          if (c == 0) {
            // End of word, deal with the word.
            // Don't use keep-case words in the fold-case tree,
            // they will appear in the keep-case tree.
            // Only use the word when the region matches.
            flags = (int)idxs[n];
            if ((round == 2 || (flags & WF_KEEPCAP) == 0)
                && (flags & WF_NEEDCOMP) == 0
                && (do_region
                    || (flags & WF_REGION) == 0
                    || (((unsigned)flags >> 16)
                        & lp->lp_region) != 0)) {
              word[depth] = NUL;
              if (!do_region)
                flags &= ~WF_REGION;

              // Dump the basic word if there is no prefix or
              // when it's the first one.
              c = (unsigned)flags >> 24;
              if (c == 0 || curi[depth] == 2) {
                dump_word(slang, word, pat, dir,
                    dumpflags, flags, lnum);
                if (pat == NULL)
                  ++lnum;
              }

              // Apply the prefix, if there is one.
              if (c != 0)
                lnum = dump_prefixes(slang, word, pat, dir,
                    dumpflags, flags, lnum);
            }
          } else {
            // Normal char, go one level deeper.
            word[depth++] = c;
            arridx[depth] = idxs[n];
            curi[depth] = 1;

            // Check if this characters matches with the pattern.
            // If not skip the whole tree below it.
            // Always ignore case here, dump_word() will check
            // proper case later.  This isn't exactly right when
            // length changes for multi-byte characters with
            // ignore case...
            assert(depth >= 0);
            if (depth <= patlen
                && mb_strnicmp(word, pat, (size_t)depth) != 0)
              --depth;
          }
        }
      }
    }
  }
}

// Dumps one word: apply case modifications and append a line to the buffer.
// When "lnum" is zero add insert mode completion.
static void dump_word(slang_T *slang, char_u *word, char_u *pat, int *dir, int dumpflags, int wordflags, linenr_T lnum)
{
  bool keepcap = false;
  char_u      *p;
  char_u      *tw;
  char_u cword[MAXWLEN];
  char_u badword[MAXWLEN + 10];
  int i;
  int flags = wordflags;

  if (dumpflags & DUMPFLAG_ONECAP)
    flags |= WF_ONECAP;
  if (dumpflags & DUMPFLAG_ALLCAP)
    flags |= WF_ALLCAP;

  if ((dumpflags & DUMPFLAG_KEEPCASE) == 0 && (flags & WF_CAPMASK) != 0) {
    // Need to fix case according to "flags".
    make_case_word(word, cword, flags);
    p = cword;
  } else {
    p = word;
    if ((dumpflags & DUMPFLAG_KEEPCASE)
        && ((captype(word, NULL) & WF_KEEPCAP) == 0
            || (flags & WF_FIXCAP) != 0))
      keepcap = true;
  }
  tw = p;

  if (pat == NULL) {
    // Add flags and regions after a slash.
    if ((flags & (WF_BANNED | WF_RARE | WF_REGION)) || keepcap) {
      STRCPY(badword, p);
      STRCAT(badword, "/");
      if (keepcap) {
        STRCAT(badword, "=");
      }
      if (flags & WF_BANNED) {
        STRCAT(badword, "!");
      } else if (flags & WF_RARE) {
        STRCAT(badword, "?");
      }
      if (flags & WF_REGION) {
        for (i = 0; i < 7; i++) {
          if (flags & (0x10000 << i)) {
            const size_t badword_len = STRLEN(badword);
            snprintf((char *)badword + badword_len,
                     sizeof(badword) - badword_len,
                     "%d", i + 1);
          }
        }
      }
      p = badword;
    }

    if (dumpflags & DUMPFLAG_COUNT) {
      hashitem_T  *hi;

      // Include the word count for ":spelldump!".
      hi = hash_find(&slang->sl_wordcount, tw);
      if (!HASHITEM_EMPTY(hi)) {
        vim_snprintf((char *)IObuff, IOSIZE, "%s\t%d",
            tw, HI2WC(hi)->wc_count);
        p = IObuff;
      }
    }

    ml_append(lnum, p, (colnr_T)0, false);
  } else if (((dumpflags & DUMPFLAG_ICASE)
              ? mb_strnicmp(p, pat, STRLEN(pat)) == 0
              : STRNCMP(p, pat, STRLEN(pat)) == 0)
             && ins_compl_add_infercase(p, (int)STRLEN(p),
                                        p_ic, NULL, *dir, 0) == OK) {
    // if dir was BACKWARD then honor it just once
    *dir = FORWARD;
  }
}

// For ":spelldump": Find matching prefixes for "word".  Prepend each to
// "word" and append a line to the buffer.
// When "lnum" is zero add insert mode completion.
// Return the updated line number.
static linenr_T
dump_prefixes (
    slang_T *slang,
    char_u *word,          // case-folded word
    char_u *pat,
    int *dir,
    int dumpflags,
    int flags,                  // flags with prefix ID
    linenr_T startlnum
)
{
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  char_u prefix[MAXWLEN];
  char_u word_up[MAXWLEN];
  bool has_word_up = false;
  int c;
  char_u      *byts;
  idx_T       *idxs;
  linenr_T lnum = startlnum;
  int depth;
  int n;
  int len;
  int i;

  // If the word starts with a lower-case letter make the word with an
  // upper-case letter in word_up[].
  c = PTR2CHAR(word);
  if (SPELL_TOUPPER(c) != c) {
    onecap_copy(word, word_up, true);
    has_word_up = true;
  }

  byts = slang->sl_pbyts;
  idxs = slang->sl_pidxs;
  if (byts != NULL) {           // array not is empty
    // Loop over all prefixes, building them byte-by-byte in prefix[].
    // When at the end of a prefix check that it supports "flags".
    depth = 0;
    arridx[0] = 0;
    curi[0] = 1;
    while (depth >= 0 && !got_int) {
      n = arridx[depth];
      len = byts[n];
      if (curi[depth] > len) {
        // Done all bytes at this node, go up one level.
        --depth;
        line_breakcheck();
      } else {
        // Do one more byte at this node.
        n += curi[depth];
        ++curi[depth];
        c = byts[n];
        if (c == 0) {
          // End of prefix, find out how many IDs there are.
          for (i = 1; i < len; ++i)
            if (byts[n + i] != 0)
              break;
          curi[depth] += i - 1;

          c = valid_word_prefix(i, n, flags, word, slang, false);
          if (c != 0) {
            STRLCPY(prefix + depth, word, MAXWLEN - depth);
            dump_word(slang, prefix, pat, dir, dumpflags,
                (c & WF_RAREPFX) ? (flags | WF_RARE)
                : flags, lnum);
            if (lnum != 0)
              ++lnum;
          }

          // Check for prefix that matches the word when the
          // first letter is upper-case, but only if the prefix has
          // a condition.
          if (has_word_up) {
            c = valid_word_prefix(i, n, flags, word_up, slang,
                true);
            if (c != 0) {
              STRLCPY(prefix + depth, word_up, MAXWLEN - depth);
              dump_word(slang, prefix, pat, dir, dumpflags,
                  (c & WF_RAREPFX) ? (flags | WF_RARE)
                  : flags, lnum);
              if (lnum != 0)
                ++lnum;
            }
          }
        } else {
          // Normal char, go one level deeper.
          prefix[depth++] = c;
          arridx[depth] = idxs[n];
          curi[depth] = 1;
        }
      }
    }
  }

  return lnum;
}

// Move "p" to the end of word "start".
// Uses the spell-checking word characters.
char_u *spell_to_word_end(char_u *start, win_T *win)
{
  char_u  *p = start;

  while (*p != NUL && spell_iswordp(p, win)) {
    MB_PTR_ADV(p);
  }
  return p;
}

// For Insert mode completion CTRL-X s:
// Find start of the word in front of column "startcol".
// We don't check if it is badly spelled, with completion we can only change
// the word in front of the cursor.
// Returns the column number of the word.
int spell_word_start(int startcol)
{
  char_u      *line;
  char_u      *p;
  int col = 0;

  if (no_spell_checking(curwin)) {
    return startcol;
  }

  // Find a word character before "startcol".
  line = get_cursor_line_ptr();
  for (p = line + startcol; p > line; ) {
    MB_PTR_BACK(line, p);
    if (spell_iswordp_nmw(p, curwin)) {
      break;
    }
  }

  // Go back to start of the word.
  while (p > line) {
    col = (int)(p - line);
    MB_PTR_BACK(line, p);
    if (!spell_iswordp(p, curwin)) {
      break;
    }
    col = 0;
  }

  return col;
}

// Need to check for 'spellcapcheck' now, the word is removed before
// expand_spelling() is called.  Therefore the ugly global variable.
static bool spell_expand_need_cap;

void spell_expand_check_cap(colnr_T col)
{
  spell_expand_need_cap = check_need_cap(curwin->w_cursor.lnum, col);
}

// Get list of spelling suggestions.
// Used for Insert mode completion CTRL-X ?.
// Returns the number of matches.  The matches are in "matchp[]", array of
// allocated strings.
int expand_spelling(linenr_T lnum, char_u *pat, char_u ***matchp)
{
  garray_T ga;

  spell_suggest_list(&ga, pat, 100, spell_expand_need_cap, true);
  *matchp = ga.ga_data;
  return ga.ga_len;
}
