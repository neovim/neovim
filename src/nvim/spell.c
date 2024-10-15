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

// Use SPELL_COMPRESS_ALWAYS for debugging: compress the word tree after
// adding a word.  Only use it for small word lists!

// Use DEBUG_TRIEWALK to print the changes made in suggest_trie_walk() for a
// specific word.

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/decoration.h"
#include "nvim/decoration_provider.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/hashtab_defs.h"
#include "nvim/highlight_defs.h"
#include "nvim/insexpand.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/runtime.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/spell_defs.h"
#include "nvim/spellfile.h"
#include "nvim/spellsuggest.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/types_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

// Result values.  Lower number is accepted over higher one.
enum {
  SP_BANNED = -1,
  SP_RARE = 0,
  SP_OK = 1,
  SP_LOCAL = 2,
  SP_BAD = 3,
};

// First language that is loaded, start of the linked list of loaded
// languages.
slang_T *first_lang = NULL;

// file used for "zG" and "zW"
char *int_wordlist = NULL;

// Structure to store info for word matching.
typedef struct {
  langp_T *mi_lp;                   // info for language and region

  // pointers to original text to be checked
  char *mi_word;                   // start of word being checked
  char *mi_end;                    // end of matching word so far
  char *mi_fend;                   // next char to be added to mi_fword
  char *mi_cend;                   // char after what was used for
                                   // mi_capflags

  // case-folded text
  char mi_fword[MAXWLEN + 1];           // mi_word case-folded
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
  uint8_t mi_compflags[MAXWLEN];        // flags for compound words used
  int mi_complen;                       // nr of compound words used
  int mi_compextra;                     // nr of COMPOUNDROOT words

  // others
  int mi_result;                        // result so far: SP_BAD, SP_OK, etc.
  int mi_capflags;                      // WF_ONECAP WF_ALLCAP WF_KEEPCAP
  win_T *mi_win;                  // buffer being checked

  // for NOBREAK
  int mi_result2;                       // "mi_result" without following word
  char *mi_end2;                        // "mi_end" without following word
} matchinf_T;

// Structure used for the cookie argument of do_in_runtimepath().
typedef struct {
  char sl_lang[MAXWLEN + 1];            // language name
  slang_T *sl_slang;                    // resulting slang_T struct
  int sl_nobreak;                       // NOBREAK language found
} spelload_T;

#define SY_MAXLEN   30
typedef struct {
  char sy_chars[SY_MAXLEN];               // the sequence of chars
  int sy_len;
} syl_item_T;

spelltab_T spelltab;
bool did_set_spelltab;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "spell.c.generated.h"
#endif

/// mode values for find_word
enum {
  FIND_FOLDWORD     = 0,  ///< find word case-folded
  FIND_KEEPWORD     = 1,  ///< find keep-case word
  FIND_PREFIX       = 2,  ///< find word after prefix
  FIND_COMPOUND     = 3,  ///< find case-folded compound word
  FIND_KEEPCOMPOUND = 4,  ///< find keep-case compound word
};

/// type values for get_char_type
enum {
  CHAR_OTHER = 0,
  CHAR_UPPER = 1,
  CHAR_DIGIT = 2,
};

char *e_format = N_("E759: Format error in spell file");

// Remember what "z?" replaced.
char *repl_from = NULL;
char *repl_to = NULL;

/// Main spell-checking function.
/// "ptr" points to a character that could be the start of a word.
/// "*attrp" is set to the highlight index for a badly spelled word.  For a
/// non-word or when it's OK it remains unchanged.
/// This must only be called when 'spelllang' is not empty.
///
/// "capcol" is used to check for a Capitalised word after the end of a
/// sentence.  If it's zero then perform the check.  Return the column where to
/// check next, or -1 when no sentence end was found.  If it's NULL then don't
/// worry.
///
/// @param wp  current window
/// @param capcol  column to check for Capital
/// @param docount  count good words
///
/// @return  the length of the word in bytes, also when it's OK, so that the
/// caller can skip over the word.
size_t spell_check(win_T *wp, char *ptr, hlf_T *attrp, int *capcol, bool docount)
{
  // A word never starts at a space or a control character. Return quickly
  // then, skipping over the character.
  if ((uint8_t)(*ptr) <= ' ') {
    return 1;
  }

  // Return here when loading language files failed.
  if (GA_EMPTY(&wp->w_s->b_langp)) {
    return 1;
  }

  size_t nrlen = 0;              // found a number first
  size_t wrongcaplen = 0;
  bool count_word = docount;
  bool use_camel_case = (wp->w_s->b_p_spo_flags & SPO_CAMEL) != 0;
  bool is_camel_case = false;

  matchinf_T mi;  // Most things are put in "mi" so that it can be passed to functions quickly.
  CLEAR_FIELD(mi);

  // A number is always OK.  Also skip hexadecimal numbers 0xFF99 and
  // 0X99FF.  But always do check spelling to find "3GPP" and "11
  // julifeest".
  if (*ptr >= '0' && *ptr <= '9') {
    if (*ptr == '0' && (ptr[1] == 'b' || ptr[1] == 'B')) {
      mi.mi_end = (char *)skipbin(ptr + 2);
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
    if (use_camel_case) {
      mi.mi_fend = advance_camelcase_word(ptr, wp, &is_camel_case);
    } else {
      do {
        MB_PTR_ADV(mi.mi_fend);
      } while (*mi.mi_fend != NUL && spell_iswordp(mi.mi_fend, wp));
    }

    if (capcol != NULL && *capcol == 0 && wp->w_s->b_cap_prog != NULL) {
      // Check word starting with capital letter.
      int c = utf_ptr2char(ptr);
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

  spell_casefold(wp, ptr, (int)(mi.mi_fend - ptr), mi.mi_fword,
                 MAXWLEN + 1);
  mi.mi_fwordlen = (int)strlen(mi.mi_fword);

  if (is_camel_case && mi.mi_fwordlen > 0) {
    // introduce a fake word end space into the folded word.
    mi.mi_fword[mi.mi_fwordlen - 1] = ' ';
  }

  // The word is bad unless we recognize it.
  mi.mi_result = SP_BAD;
  mi.mi_result2 = SP_BAD;

  // Loop over the languages specified in 'spelllang'.
  // We check them all, because a word may be matched longer in another
  // language.
  for (int lpi = 0; lpi < wp->w_s->b_langp.ga_len; lpi++) {
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
        bool r = vim_regexec(&regmatch, ptr, 0);
        wp->w_s->b_cap_prog = regmatch.regprog;
        if (r) {
          *capcol = (int)(regmatch.endp[0] - ptr);
        }
      }

      return (size_t)(utfc_ptr2len(ptr));
    } else if (mi.mi_end == ptr) {
      // Always include at least one character.  Required for when there
      // is a mixup in "midword".
      MB_PTR_ADV(mi.mi_end);
    } else if (mi.mi_result == SP_BAD
               && LANGP_ENTRY(wp->w_s->b_langp, 0)->lp_slang->sl_nobreak) {
      char *p;
      int save_result = mi.mi_result;

      // First language in 'spelllang' is NOBREAK.  Find first position
      // at which any word would be valid.
      mi.mi_lp = LANGP_ENTRY(wp->w_s->b_langp, 0);
      if (mi.mi_lp->lp_slang->sl_fidxs != NULL) {
        p = mi.mi_word;
        char *fp = mi.mi_fword;
        while (true) {
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

/// Determine the type of character "c".
static int get_char_type(int c)
{
  if (ascii_isdigit(c)) {
    return CHAR_DIGIT;
  }
  if (SPELL_ISUPPER(c)) {
    return CHAR_UPPER;
  }
  return CHAR_OTHER;
}

/// Returns a pointer to the end of the word starting at "str".
/// Supports camelCase words.
static char *advance_camelcase_word(char *str, win_T *wp, bool *is_camel_case)
{
  char *end = str;

  *is_camel_case = false;

  if (*str == NUL) {
    return str;
  }

  int c = utf_ptr2char(end);
  MB_PTR_ADV(end);
  // We need at most the types of the type of the last two chars.
  int last_last_type = -1;
  int last_type = get_char_type(c);

  while (*end != NUL && spell_iswordp(end, wp)) {
    c = utf_ptr2char(end);
    int this_type = get_char_type(c);

    if (last_last_type == CHAR_UPPER && last_type == CHAR_UPPER
        && this_type == CHAR_OTHER) {
      // Handle the following cases:
      // UpperUpperLower
      *is_camel_case = true;
      // Back up by one char.
      MB_PTR_BACK(str, end);
      break;
    } else if ((this_type == CHAR_UPPER && last_type == CHAR_OTHER)
               || (this_type != last_type
                   && (this_type == CHAR_DIGIT || last_type == CHAR_DIGIT))) {
      // Handle the following cases:
      // LowerUpper LowerDigit UpperDigit DigitUpper DigitLower
      *is_camel_case = true;
      break;
    }

    last_last_type = last_type;
    last_type = this_type;

    MB_PTR_ADV(end);
  }

  return end;
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
  char *ptr;
  slang_T *slang = mip->mi_lp->lp_slang;
  uint8_t *byts;
  idx_T *idxs;

  if (mode == FIND_KEEPWORD || mode == FIND_KEEPCOMPOUND) {
    // Check for word with matching case in keep-case tree.
    ptr = mip->mi_word;
    flen = 9999;                    // no case folding, always enough bytes
    byts = slang->sl_kbyts;
    idxs = slang->sl_kidxs;

    if (mode == FIND_KEEPCOMPOUND) {
      // Skip over the previously found word(s).
      wlen += mip->mi_compoff;
    }
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

  if (byts == NULL) {
    return;                     // array is empty
  }
  idx_T arridx = 0;
  int endlen[MAXWLEN];              // length at possible word endings
  idx_T endidx[MAXWLEN];            // possible word endings
  int endidxcnt = 0;

  // Repeat advancing in the tree until:
  // - there is a byte that doesn't match,
  // - we reach the end of the tree,
  // - or we reach the end of the line.
  while (true) {
    if (flen <= 0 && *mip->mi_fend != NUL) {
      flen = fold_more(mip);
    }

    int len = byts[arridx++];

    // If the first possible byte is a zero the word could end here.
    // Remember this index, we first check for the longest word.
    if (byts[arridx] == 0) {
      if (endidxcnt == MAXWLEN) {
        // Must be a corrupted spell file.
        emsg(_(e_format));
        return;
      }
      endlen[endidxcnt] = wlen;
      endidx[endidxcnt++] = arridx++;
      len--;

      // Skip over the zeros, there can be several flag/region
      // combinations.
      while (len > 0 && byts[arridx] == 0) {
        arridx++;
        len--;
      }
      if (len == 0) {
        break;              // no children, word must end here
      }
    }

    // Stop looking at end of the line.
    if (ptr[wlen] == NUL) {
      break;
    }

    // Perform a binary search in the list of accepted bytes.
    int c = (uint8_t)ptr[wlen];
    if (c == TAB) {         // <Tab> is handled like <Space>
      c = ' ';
    }
    idx_T lo = arridx;
    idx_T hi = arridx + len - 1;
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
    arridx = idxs[lo];
    wlen++;
    flen--;

    // One space in the good word may stand for several spaces in the
    // checked word.
    if (c == ' ') {
      while (true) {
        if (flen <= 0 && *mip->mi_fend != NUL) {
          flen = fold_more(mip);
        }
        if (ptr[wlen] != ' ' && ptr[wlen] != TAB) {
          break;
        }
        wlen++;
        flen--;
      }
    }
  }

  // Verify that one of the possible endings is valid.  Try the longest
  // first.
  while (endidxcnt > 0) {
    endidxcnt--;
    arridx = endidx[endidxcnt];
    wlen = endlen[endidxcnt];

    if (utf_head_off(ptr, ptr + wlen) > 0) {
      continue;             // not at first byte of character
    }
    bool word_ends;
    if (spell_iswordp(ptr + wlen, mip->mi_win)) {
      if (slang->sl_compprog == NULL && !slang->sl_nobreak) {
        continue;                   // next char is a word character
      }
      word_ends = false;
    } else {
      word_ends = true;
    }
    // The prefix flag is before compound flags.  Once a valid prefix flag
    // has been found we try compound flags.
    bool prefix_found = false;

    if (mode != FIND_KEEPWORD) {
      // Compute byte length in original word, length may change
      // when folding case.  This can be slow, take a shortcut when the
      // case-folded word is equal to the keep-case word.
      char *p = mip->mi_word;
      if (strncmp(ptr, p, (size_t)wlen) != 0) {
        for (char *s = ptr; s < ptr + wlen; MB_PTR_ADV(s)) {
          MB_PTR_ADV(p);
        }
        wlen = (int)(p - mip->mi_word);
      }
    }

    // Check flags and region.  For FIND_PREFIX check the condition and
    // prefix ID.
    // Repeat this if there are more flags/region alternatives until there
    // is a match.
    for (int len = byts[arridx - 1]; len > 0 && byts[arridx] == 0; len--, arridx++) {
      uint32_t flags = (uint32_t)idxs[arridx];

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
            || !spell_valid_case(mip->mi_capflags, (int)flags)) {
          continue;
        }
      } else if (mode == FIND_PREFIX && !prefix_found) {
        // When mode is FIND_PREFIX the word must support the prefix:
        // check the prefix ID and the condition.  Do that for the list at
        // mip->mi_prefarridx that find_prefix() filled.
        int c = valid_word_prefix(mip->mi_prefcnt, mip->mi_prefarridx,
                                  (int)flags,
                                  mip->mi_word + mip->mi_cprefixlen, slang,
                                  false);
        if (c == 0) {
          continue;
        }

        // Use the WF_RARE flag for a rare prefix.
        if (c & WF_RAREPFX) {
          flags |= WF_RARE;
        }
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
            || wlen - mip->mi_compoff < slang->sl_compminlen) {
          continue;
        }
        // For multi-byte chars check character length against
        // COMPOUNDMIN.
        if (slang->sl_compminlen > 0
            && mb_charlen_len(mip->mi_word + mip->mi_compoff,
                              wlen - mip->mi_compoff) < slang->sl_compminlen) {
          continue;
        }

        // Limit the number of compound words to COMPOUNDWORDMAX if no
        // maximum for syllables is specified.
        if (!word_ends && mip->mi_complen + mip->mi_compextra + 2
            > slang->sl_compmax
            && slang->sl_compsylmax == MAXWLEN) {
          continue;
        }

        // Don't allow compounding on a side where an affix was added,
        // unless COMPOUNDPERMITFLAG was used.
        if (mip->mi_complen > 0 && (flags & WF_NOCOMPBEF)) {
          continue;
        }
        if (!word_ends && (flags & WF_NOCOMPAFT)) {
          continue;
        }

        // Quickly check if compounding is possible with this flag.
        if (!byte_in_str(mip->mi_complen ==
                         0 ? slang->sl_compstartflags : slang->sl_compallflags,
                         (int)((unsigned)flags >> 24))) {
          continue;
        }

        // If there is a match with a CHECKCOMPOUNDPATTERN rule
        // discard the compound word.
        if (match_checkcompoundpattern(ptr, wlen, &slang->sl_comppat)) {
          continue;
        }

        if (mode == FIND_COMPOUND) {
          int capflags;
          char *p;

          // Need to check the caps type of the appended compound
          // word.
          if (strncmp(ptr, mip->mi_word, (size_t)mip->mi_compoff) != 0) {
            // case folding may have changed the length
            p = mip->mi_word;
            for (char *s = ptr; s < ptr + mip->mi_compoff; MB_PTR_ADV(s)) {
              MB_PTR_ADV(p);
            }
          } else {
            p = mip->mi_word + mip->mi_compoff;
          }
          capflags = captype(p, mip->mi_word + wlen);
          if (capflags == WF_KEEPCAP || (capflags == WF_ALLCAP
                                         && (flags & WF_FIXCAP) != 0)) {
            continue;
          }

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
        mip->mi_compflags[mip->mi_complen] = (uint8_t)((unsigned)flags >> 24);
        mip->mi_compflags[mip->mi_complen + 1] = NUL;
        if (word_ends) {
          char fword[MAXWLEN] = { 0 };

          if (slang->sl_compsylmax < MAXWLEN) {
            // "fword" is only needed for checking syllables.
            if (ptr == mip->mi_word) {
              spell_casefold(mip->mi_win, ptr, wlen, fword, MAXWLEN);
            } else {
              xmemcpyz(fword, ptr, (size_t)endlen[endidxcnt]);
            }
          }
          if (!can_compound(slang, fword, mip->mi_compflags)) {
            continue;
          }
        } else if (slang->sl_comprules != NULL
                   && !match_compoundrule(slang, mip->mi_compflags)) {
          // The compound flags collected so far do not match any
          // COMPOUNDRULE, discard the compounded word.
          continue;
        }
      } else if (flags & WF_NEEDCOMP) {
        // skip if word is only valid in a compound
        continue;
      }

      int nobreak_result = SP_OK;

      if (!word_ends) {
        int save_result = mip->mi_result;
        char *save_end = mip->mi_end;
        langp_T *save_lp = mip->mi_lp;

        // Check that a valid word follows.  If there is one and we
        // are compounding, it will set "mi_result", thus we are
        // always finished here.  For NOBREAK we only check that a
        // valid word follows.
        // Recursive!
        if (slang->sl_nobreak) {
          mip->mi_result = SP_BAD;
        }

        // Find following word in case-folded tree.
        mip->mi_compoff = endlen[endidxcnt];
        if (mode == FIND_KEEPWORD) {
          // Compute byte length in case-folded word from "wlen":
          // byte length in keep-case word.  Length may change when
          // folding case.  This can be slow, take a shortcut when
          // the case-folded word is equal to the keep-case word.
          char *p = mip->mi_fword;
          if (strncmp(ptr, p, (size_t)wlen) != 0) {
            for (char *s = ptr; s < ptr + wlen; MB_PTR_ADV(s)) {
              MB_PTR_ADV(p);
            }
            mip->mi_compoff = (int)(p - mip->mi_fword);
          }
        }
        mip->mi_complen++;
        if (flags & WF_COMPROOT) {
          mip->mi_compextra++;
        }

        // For NOBREAK we need to try all NOBREAK languages, at least
        // to find the ".add" file(s).
        for (int lpi = 0; lpi < mip->mi_win->w_s->b_langp.ga_len; lpi++) {
          if (slang->sl_nobreak) {
            mip->mi_lp = LANGP_ENTRY(mip->mi_win->w_s->b_langp, lpi);
            if (mip->mi_lp->lp_slang->sl_fidxs == NULL
                || !mip->mi_lp->lp_slang->sl_nobreak) {
              continue;
            }
          }

          find_word(mip, FIND_COMPOUND);

          // When NOBREAK any word that matches is OK.  Otherwise we
          // need to find the longest match, thus try with keep-case
          // and prefix too.
          if (!slang->sl_nobreak || mip->mi_result == SP_BAD) {
            // Find following word in keep-case tree.
            mip->mi_compoff = wlen;
            find_word(mip, FIND_KEEPCOMPOUND);
          }

          if (!slang->sl_nobreak) {
            break;
          }
        }
        mip->mi_complen--;
        if (flags & WF_COMPROOT) {
          mip->mi_compextra--;
        }
        mip->mi_lp = save_lp;

        if (slang->sl_nobreak) {
          nobreak_result = mip->mi_result;
          mip->mi_result = save_result;
          mip->mi_end = save_end;
        } else {
          if (mip->mi_result == SP_OK) {
            break;
          }
          continue;
        }
      }

      int res = SP_BAD;
      if (flags & WF_BANNED) {
        res = SP_BANNED;
      } else if (flags & WF_REGION) {
        // Check region.
        if (((unsigned)mip->mi_lp->lp_region & (flags >> 16)) != 0) {
          res = SP_OK;
        } else {
          res = SP_LOCAL;
        }
      } else if (flags & WF_RARE) {
        res = SP_RARE;
      } else {
        res = SP_OK;
      }

      // Always use the longest match and the best result.  For NOBREAK
      // we separately keep the longest match without a following good
      // word as a fall-back.
      if (nobreak_result == SP_BAD) {
        if (mip->mi_result2 > res) {
          mip->mi_result2 = res;
          mip->mi_end2 = mip->mi_word + wlen;
        } else if (mip->mi_result2 == res
                   && mip->mi_end2 < mip->mi_word + wlen) {
          mip->mi_end2 = mip->mi_word + wlen;
        }
      } else if (mip->mi_result > res) {
        mip->mi_result = res;
        mip->mi_end = mip->mi_word + wlen;
      } else if (mip->mi_result == res && mip->mi_end < mip->mi_word + wlen) {
        mip->mi_end = mip->mi_word + wlen;
      }

      if (mip->mi_result == SP_OK) {
        break;
      }
    }

    if (mip->mi_result == SP_OK) {
      break;
    }
  }
}

/// Returns true if there is a match between the word ptr[wlen] and
/// CHECKCOMPOUNDPATTERN rules, assuming that we will concatenate with another
/// word.
/// A match means that the first part of CHECKCOMPOUNDPATTERN matches at the
/// end of ptr[wlen] and the second part matches after it.
///
/// @param gap  &sl_comppat
bool match_checkcompoundpattern(char *ptr, int wlen, garray_T *gap)
{
  for (int i = 0; i + 1 < gap->ga_len; i += 2) {
    char *p = ((char **)gap->ga_data)[i + 1];
    if (strncmp(ptr + wlen, p, strlen(p)) == 0) {
      // Second part matches at start of following compound word, now
      // check if first part matches at end of previous word.
      p = ((char **)gap->ga_data)[i];
      int len = (int)strlen(p);
      if (len <= wlen && strncmp(ptr + wlen - len, p, (size_t)len) == 0) {
        return true;
      }
    }
  }
  return false;
}

/// @return  true if "flags" is a valid sequence of compound flags and "word"
///          does not have too many syllables.
bool can_compound(slang_T *slang, const char *word, const uint8_t *flags)
  FUNC_ATTR_NONNULL_ALL
{
  char uflags[MAXWLEN * 2] = { 0 };

  if (slang->sl_compprog == NULL) {
    return false;
  }
  // Need to convert the single byte flags to utf8 characters.
  char *p = uflags;
  for (int i = 0; flags[i] != NUL; i++) {
    p += utf_char2bytes(flags[i], p);
  }
  *p = NUL;
  p = uflags;
  if (!vim_regexec_prog(&slang->sl_compprog, false, p, 0)) {
    return false;
  }

  // Count the number of syllables.  This may be slow, do it last.  If there
  // are too many syllables AND the number of compound words is above
  // COMPOUNDWORDMAX then compounding is not allowed.
  if (slang->sl_compsylmax < MAXWLEN
      && count_syllables(slang, word) > slang->sl_compsylmax) {
    return (int)strlen((char *)flags) < slang->sl_compmax;
  }
  return true;
}

// Returns true if the compound flags in compflags[] match the start of any
// compound rule.  This is used to stop trying a compound if the flags
// collected so far can't possibly match any compound rule.
// Caller must check that slang->sl_comprules is not NULL.
bool match_compoundrule(slang_T *slang, const uint8_t *compflags)
{
  // loop over all the COMPOUNDRULE entries
  for (char *p = (char *)slang->sl_comprules; *p != NUL; p++) {
    // loop over the flags in the compound word we have made, match
    // them against the current rule entry
    for (int i = 0;; i++) {
      int c = compflags[i];
      if (c == NUL) {
        // found a rule that matches for the flags we have so far
        return true;
      }
      if (*p == '/' || *p == NUL) {
        break;          // end of rule, it's too short
      }
      if (*p == '[') {
        bool match = false;

        // compare against all the flags in []
        p++;
        while (*p != ']' && *p != NUL) {
          if ((uint8_t)(*p++) == c) {
            match = true;
          }
        }
        if (!match) {
          break;            // none matches
        }
      } else if ((uint8_t)(*p) != c) {
        break;          // flag of word doesn't match flag in pattern
      }
      p++;
    }

    // Skip to the next "/", where the next pattern starts.
    p = vim_strchr(p, '/');
    if (p == NULL) {
      break;
    }
  }

  // Checked all the rules and none of them match the flags, so there
  // can't possibly be a compound starting with these flags.
  return false;
}

/// Return non-zero if the prefix indicated by "arridx" matches with the prefix
/// ID in "flags" for the word "word".
/// The WF_RAREPFX flag is included in the return value for a rare prefix.
///
/// @param totprefcnt  nr of prefix IDs
/// @param arridx  idx in sl_pidxs[]
/// @param cond_req  only use prefixes with a condition
int valid_word_prefix(int totprefcnt, int arridx, int flags, char *word, slang_T *slang,
                      bool cond_req)
{
  int prefid = (int)((unsigned)flags >> 24);
  for (int prefcnt = totprefcnt - 1; prefcnt >= 0; prefcnt--) {
    int pidx = slang->sl_pidxs[arridx + prefcnt];

    // Check the prefix ID.
    if (prefid != (pidx & 0xff)) {
      continue;
    }

    // Check if the prefix doesn't combine and the word already has a
    // suffix.
    if ((flags & WF_HAS_AFF) && (pidx & WF_PFX_NC)) {
      continue;
    }

    // Check the condition, if there is one.  The condition index is
    // stored in the two bytes above the prefix ID byte.
    regprog_T **rp = &slang->sl_prefprog[((unsigned)pidx >> 8) & 0xffff];
    if (*rp != NULL) {
      if (!vim_regexec_prog(rp, false, word, 0)) {
        continue;
      }
    } else if (cond_req) {
      continue;
    }

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
  int wlen = 0;
  slang_T *slang = mip->mi_lp->lp_slang;

  uint8_t *byts = slang->sl_pbyts;
  if (byts == NULL) {
    return;                     // array is empty
  }
  // We use the case-folded word here, since prefixes are always
  // case-folded.
  char *ptr = mip->mi_fword;
  int flen = mip->mi_fwordlen;      // available case-folded bytes
  if (mode == FIND_COMPOUND) {
    // Skip over the previously found word(s).
    ptr += mip->mi_compoff;
    flen -= mip->mi_compoff;
  }
  idx_T *idxs = slang->sl_pidxs;

  // Repeat advancing in the tree until:
  // - there is a byte that doesn't match,
  // - we reach the end of the tree,
  // - or we reach the end of the line.
  while (true) {
    if (flen == 0 && *mip->mi_fend != NUL) {
      flen = fold_more(mip);
    }

    int len = byts[arridx++];

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
        arridx++;
        len--;
      }
      mip->mi_prefcnt -= len;

      // Find the word that comes after the prefix.
      mip->mi_prefixlen = wlen;
      if (mode == FIND_COMPOUND) {
        // Skip over the previously found word(s).
        mip->mi_prefixlen += mip->mi_compoff;
      }

      // Case-folded length may differ from original length.
      mip->mi_cprefixlen = nofold_len(mip->mi_fword, mip->mi_prefixlen,
                                      mip->mi_word);
      find_word(mip, FIND_PREFIX);

      if (len == 0) {
        break;              // no children, word must end here
      }
    }

    // Stop looking at end of the line.
    if (ptr[wlen] == NUL) {
      break;
    }

    // Perform a binary search in the list of accepted bytes.
    int c = (uint8_t)ptr[wlen];
    idx_T lo = arridx;
    idx_T hi = arridx + len - 1;
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
    arridx = idxs[lo];
    wlen++;
    flen--;
  }
}

// Need to fold at least one more character.  Do until next non-word character
// for efficiency.  Include the non-word character too.
// Return the length of the folded chars in bytes.
static int fold_more(matchinf_T *mip)
{
  char *p = mip->mi_fend;
  do {
    MB_PTR_ADV(mip->mi_fend);
  } while (*mip->mi_fend != NUL && spell_iswordp(mip->mi_fend, mip->mi_win));

  // Include the non-word character so that we can check for the word end.
  if (*mip->mi_fend != NUL) {
    MB_PTR_ADV(mip->mi_fend);
  }

  spell_casefold(mip->mi_win, p, (int)(mip->mi_fend - p),
                 mip->mi_fword + mip->mi_fwordlen,
                 MAXWLEN - mip->mi_fwordlen);
  int flen = (int)strlen(mip->mi_fword + mip->mi_fwordlen);
  mip->mi_fwordlen += flen;
  return flen;
}

/// Checks case flags for a word. Returns true, if the word has the requested
/// case.
///
/// @param wordflags Flags for the checked word.
/// @param treeflags Flags for the word in the spell tree.
bool spell_valid_case(int wordflags, int treeflags)
{
  return (wordflags == WF_ALLCAP && (treeflags & WF_FIXCAP) == 0)
         || ((treeflags & (WF_ALLCAP | WF_KEEPCAP)) == 0
             && ((treeflags & WF_ONECAP) == 0
                 || (wordflags & WF_ONECAP) != 0));
}

/// Return true if spell checking is enabled for "wp".
bool spell_check_window(win_T *wp)
{
  return wp->w_p_spell
         && *wp->w_s->b_p_spl != NUL
         && wp->w_s->b_langp.ga_len > 0
         && *(char **)(wp->w_s->b_langp.ga_data) != NULL;
}

/// Return true and give an error if spell checking is not enabled.
bool no_spell_checking(win_T *wp)
{
  if (!wp->w_p_spell || *wp->w_s->b_p_spl == NUL || GA_EMPTY(&wp->w_s->b_langp)) {
    emsg(_(e_no_spell));
    return true;
  }
  return false;
}

static void decor_spell_nav_start(win_T *wp)
{
  decor_state = (DecorState){ 0 };
  decor_redraw_reset(wp, &decor_state);
}

static TriState decor_spell_nav_col(win_T *wp, linenr_T lnum, linenr_T *decor_lnum, int col)
{
  if (*decor_lnum != lnum) {
    decor_providers_invoke_spell(wp, lnum - 1, col, lnum - 1, -1);
    decor_redraw_line(wp, lnum - 1, &decor_state);
    *decor_lnum = lnum;
  }
  decor_redraw_col(wp, col, 0, false, &decor_state);
  return decor_state.spell;
}

static inline bool can_syn_spell(win_T *wp, linenr_T lnum, int col)
{
  bool can_spell;
  syn_get_id(wp, lnum, col, false, &can_spell, false);
  return can_spell;
}

/// Moves to the next spell error.
/// "curline" is false for "[s", "]s", "[S" and "]S".
/// "curline" is true to find word under/after cursor in the same line.
/// For Insert mode completion "dir" is BACKWARD and "curline" is true: move
/// to after badly spelled word before the cursor.
///
/// @param dir  FORWARD or BACKWARD
/// @param behaviour  Behaviour of the function
/// @param attrp  return: attributes of bad word or NULL (only when "dir" is FORWARD)
///
/// @return  0 if not found, length of the badly spelled word otherwise.
size_t spell_move_to(win_T *wp, int dir, smt_T behaviour, bool curline, hlf_T *attrp)
{
  if (no_spell_checking(wp)) {
    return 0;
  }

  pos_T found_pos;
  size_t found_len = 0;
  hlf_T attr = HLF_COUNT;
  bool has_syntax = syntax_present(wp);
  char *buf = NULL;
  size_t buflen = 0;
  int skip = 0;
  colnr_T capcol = -1;
  bool found_one = false;
  bool wrapped = false;

  size_t ret = 0;

  // Start looking for bad word at the start of the line, because we can't
  // start halfway through a word, we don't know where it starts or ends.
  //
  // When searching backwards, we continue in the line to find the last
  // bad word (in the cursor line: before the cursor).
  //
  // We concatenate the start of the next line, so that wrapped words work
  // (e.g. "et<line-break>cetera").  Doesn't work when searching backwards
  // though...
  linenr_T lnum = wp->w_cursor.lnum;
  clearpos(&found_pos);

  // Ephemeral extmarks are currently stored in the global decor_state.
  // When looking for spell errors, we need to:
  //  - temporarily reset decor_state
  //  - run the _on_spell_nav decor callback for each line we look at
  //  - detect if any spell marks are present
  //  - restore decor_state to the value saved here.
  // TODO(lewis6991): un-globalize decor_state and allow ephemeral marks to be stored into a
  // temporary DecorState.
  DecorState saved_decor_start = decor_state;
  linenr_T decor_lnum = -1;
  decor_spell_nav_start(wp);

  while (!got_int) {
    char *line = ml_get_buf(wp->w_buffer, lnum);

    size_t len = (size_t)ml_get_buf_len(wp->w_buffer, lnum);
    if (buflen < len + MAXWLEN + 2) {
      xfree(buf);
      buflen = len + MAXWLEN + 2;
      buf = xmalloc(buflen);
    }
    assert(buf && buflen >= len + MAXWLEN + 2);

    // In first line check first word for Capital.
    if (lnum == 1) {
      capcol = 0;
    }

    // For checking first word with a capital skip white space.
    if (capcol == 0) {
      capcol = (colnr_T)getwhitecols(line);
    } else if (curline && wp == curwin) {
      // For spellbadword(): check if first word needs a capital.
      colnr_T col = (colnr_T)getwhitecols(line);
      if (check_need_cap(curwin, lnum, col)) {
        capcol = col;
      }

      // Need to get the line again, may have looked at the previous
      // one.
      line = ml_get_buf(wp->w_buffer, lnum);
    }

    // Copy the line into "buf" and append the start of the next line if
    // possible.  Note: this ml_get_buf() may make "line" invalid, check
    // for empty line first.
    bool empty_line = *skipwhite(line) == NUL;
    STRCPY(buf, line);
    if (lnum < wp->w_buffer->b_ml.ml_line_count) {
      spell_cat_line(buf + strlen(buf),
                     ml_get_buf(wp->w_buffer, lnum + 1),
                     MAXWLEN);
    }
    char *p = buf + skip;
    char *endp = buf + len;
    while (p < endp) {
      // When searching backward don't search after the cursor.  Unless
      // we wrapped around the end of the buffer.
      if (dir == BACKWARD
          && lnum == wp->w_cursor.lnum
          && !wrapped
          && (colnr_T)(p - buf) >= wp->w_cursor.col) {
        break;
      }

      // start of word
      attr = HLF_COUNT;
      len = spell_check(wp, p, &attr, &capcol, false);

      if (attr != HLF_COUNT) {
        // We found a bad word.  Check the attribute.
        if (behaviour == SMT_ALL
            || (behaviour == SMT_BAD && attr == HLF_SPB)
            || (behaviour == SMT_RARE && attr == HLF_SPR)) {
          // When searching forward only accept a bad word after
          // the cursor.
          if (dir == BACKWARD
              || lnum != wp->w_cursor.lnum
              || wrapped
              || ((colnr_T)(curline
                            ? p - buf + (ptrdiff_t)len
                            : p - buf) > wp->w_cursor.col)) {
            colnr_T col = (colnr_T)(p - buf);

            bool no_plain_buffer = (wp->w_s->b_p_spo_flags & SPO_NPBUFFER) != 0;
            bool can_spell = !no_plain_buffer;
            switch (decor_spell_nav_col(wp, lnum, &decor_lnum, col)) {
            case kTrue:
              can_spell = true; break;
            case kFalse:
              can_spell = false; break;
            case kNone:
              if (has_syntax) {
                can_spell = can_syn_spell(wp, lnum, col);
              }
            }

            if (!can_spell) {
              attr = HLF_COUNT;
            }

            if (can_spell) {
              found_one = true;
              found_pos = (pos_T) {
                .lnum = lnum,
                .col = col,
                .coladd = 0
              };
              if (dir == FORWARD) {
                // No need to search further.
                wp->w_cursor = found_pos;
                if (attrp != NULL) {
                  *attrp = attr;
                }
                ret = len;
                goto theend;
              } else if (curline) {
                // Insert mode completion: put cursor after
                // the bad word.
                assert(len <= INT_MAX);
                found_pos.col += (int)len;
              }
              found_len = len;
            }
          } else {
            found_one = true;
          }
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
      ret = found_len;
      goto theend;
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
        if (!shortmess(SHM_SEARCH)) {
          give_warning(_(top_bot_msg), true);
        }
      }
      capcol = -1;
    } else {
      if (lnum < wp->w_buffer->b_ml.ml_line_count) {
        lnum++;
      } else if (!p_ws) {
        break;              // at first line and 'nowrapscan'
      } else {
        // Wrap around to the start of the buffer.  May search the
        // starting line again and accept the first match.
        lnum = 1;
        wrapped = true;
        if (!shortmess(SHM_SEARCH)) {
          give_warning(_(bot_top_msg), true);
        }
      }

      // If we are back at the starting line and there is no match then
      // give up.
      if (lnum == wp->w_cursor.lnum && !found_one) {
        break;
      }

      // Skip the characters at the start of the next line that were
      // included in a match crossing line boundaries.
      if (attr == HLF_COUNT) {
        skip = (int)(p - endp);
      } else {
        skip = 0;
      }

      // Capcol skips over the inserted space.
      capcol--;

      // But after empty line check first word in next line
      if (empty_line) {
        capcol = 0;
      }
    }

    line_breakcheck();
  }

theend:
  decor_state_free(&decor_state);
  decor_state = saved_decor_start;
  xfree(buf);
  return ret;
}

// For spell checking: concatenate the start of the following line "line" into
// "buf", blanking-out special characters.  Copy less than "maxlen" bytes.
// Keep the blanks at the start of the next line, this is used in win_line()
// to skip those bytes if the word was OK.
void spell_cat_line(char *buf, char *line, int maxlen)
{
  char *p = skipwhite(line);
  while (vim_strchr("*#/\"\t", (uint8_t)(*p)) != NULL) {
    p = skipwhite(p + 1);
  }

  if (*p == NUL) {
    return;
  }

  // Only worth concatenating if there is something else than spaces to
  // concatenate.
  int n = (int)(p - line) + 1;
  if (n < maxlen - 1) {
    memset(buf, ' ', (size_t)n);
    xstrlcpy(buf + n, p, (size_t)(maxlen - n));
  }
}

// Load word list(s) for "lang" from Vim spell file(s).
// "lang" must be the language without the region: e.g., "en".
static void spell_load_lang(char *lang)
{
  char fname_enc[85];
  int r;
  spelload_T sl;

  // Copy the language name to pass it to spell_load_cb() as a cookie.
  // It's truncated when an error is detected.
  STRCPY(sl.sl_lang, lang);
  sl.sl_slang = NULL;
  sl.sl_nobreak = false;

  // Disallow deleting the current buffer.  Autocommands can do weird things
  // and cause "lang" to be freed.
  curbuf->b_locked++;

  // We may retry when no spell file is found for the language, an
  // autocommand may load it then.
  for (int round = 1; round <= 2; round++) {
    // Find the first spell file for "lang" in 'runtimepath' and load it.
    vim_snprintf(fname_enc, sizeof(fname_enc) - 5,
                 "spell/%s.%s.spl", lang, spell_enc());
    r = do_in_runtimepath(fname_enc, 0, spell_load_cb, &sl);

    if (r == FAIL && *sl.sl_lang != NUL) {
      // Try loading the ASCII version.
      vim_snprintf(fname_enc, sizeof(fname_enc) - 5,
                   "spell/%s.ascii.spl", lang);
      r = do_in_runtimepath(fname_enc, 0, spell_load_cb, &sl);

      if (r == FAIL && *sl.sl_lang != NUL && round == 1
          && apply_autocmds(EVENT_SPELLFILEMISSING, lang,
                            curbuf->b_fname, false, curbuf)) {
        continue;
      }
      break;
    }
    break;
  }

  if (r == FAIL) {
    if (starting) {
      // Prompt the user at VimEnter if spell files are missing. #3027
      // Plugins aren't loaded yet, so spellfile.vim cannot handle this case.
      char autocmd_buf[512] = { 0 };
      snprintf(autocmd_buf, sizeof(autocmd_buf),
               "autocmd VimEnter * call spellfile#LoadFile('%s')|set spell",
               lang);
      do_cmdline_cmd(autocmd_buf);
    } else {
      smsg(0, _("Warning: Cannot find word list \"%s.%s.spl\" or \"%s.ascii.spl\""),
           lang, spell_enc(), lang);
    }
  } else if (sl.sl_slang != NULL) {
    // At least one file was loaded, now load ALL the additions.
    STRCPY(fname_enc + strlen(fname_enc) - 3, "add.spl");
    do_in_runtimepath(fname_enc, DIP_ALL, spell_load_cb, &sl);
  }

  curbuf->b_locked--;
}

// Return the encoding used for spell checking: Use 'encoding', except that we
// use "latin1" for "latin9".  And limit to 60 characters (just in case).
char *spell_enc(void)
{
  if (strlen(p_enc) < 60 && strcmp(p_enc, "iso-8859-15") != 0) {
    return p_enc;
  }
  return "latin1";
}

// Get the name of the .spl file for the internal wordlist into
// "fname[MAXPATHL]".
static void int_wordlist_spl(char *fname)
{
  vim_snprintf(fname, MAXPATHL, SPL_FNAME_TMPL,
               int_wordlist, spell_enc());
}

/// Allocate a new slang_T for language "lang".  "lang" can be NULL.
/// Caller must fill "sl_next".
slang_T *slang_alloc(char *lang)
  FUNC_ATTR_NONNULL_RET
{
  slang_T *lp = xcalloc(1, sizeof(slang_T));

  if (lang != NULL) {
    lp->sl_name = xstrdup(lang);
  }
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
static void free_salitem(salitem_T *smp)
{
  xfree(smp->sm_lead);
  // Don't free sm_oneof and sm_rules, they point into sm_lead.
  xfree(smp->sm_to);
  xfree(smp->sm_lead_w);
  xfree(smp->sm_oneof_w);
  xfree(smp->sm_to_w);
}

/// Frees a fromto_T
static void free_fromto(fromto_T *ftp)
{
  xfree(ftp->ft_from);
  xfree(ftp->ft_to);
}

// Clear an slang_T so that the file can be reloaded.
void slang_clear(slang_T *lp)
{
  garray_T *gap;

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

  for (int i = 0; i < lp->sl_prefixcnt; i++) {
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
static bool spell_load_cb(int num_fnames, char **fnames, bool all, void *cookie)
{
  spelload_T *slp = (spelload_T *)cookie;
  for (int i = 0; i < num_fnames; i++) {
    slang_T *slang = spell_load_file(fnames[i], slp->sl_lang, NULL, false);

    if (slang == NULL) {
      continue;
    }

    // When a previously loaded file has NOBREAK also use it for the
    // ".add" files.
    if (slp->sl_nobreak && slang->sl_add) {
      slang->sl_nobreak = true;
    } else if (slang->sl_nobreak) {
      slp->sl_nobreak = true;
    }

    slp->sl_slang = slang;

    if (!all) {
      break;
    }
  }

  return num_fnames > 0;
}

/// Add a word to the hashtable of common words.
/// If it's already there then the counter is increased.
///
/// @param[in]  lp
/// @param[in]  word  added to common words hashtable
/// @param[in]  len  length of word or -1 for NUL terminated
/// @param[in]  count  1 to count once, 10 to init
void count_common_word(slang_T *lp, char *word, int len, uint8_t count)
{
  char buf[MAXWLEN];
  char *p;

  if (len == -1) {
    p = word;
  } else if (len >= MAXWLEN) {
    return;
  } else {
    xmemcpyz(buf, word, (size_t)len);
    p = buf;
  }

  hash_T hash = hash_hash(p);
  const size_t p_len = strlen(p);
  hashitem_T *hi = hash_lookup(&lp->sl_wordcount, p, p_len, hash);
  if (HASHITEM_EMPTY(hi)) {
    wordcount_T *wc = xmalloc(offsetof(wordcount_T, wc_word) + p_len + 1);
    memcpy(wc->wc_word, p, p_len + 1);
    wc->wc_count = count;
    hash_add_item(&lp->sl_wordcount, hi, wc->wc_word, hash);
  } else {
    wordcount_T *wc = HI2WC(hi);
    wc->wc_count = (uint16_t)(wc->wc_count + count);
    if (wc->wc_count < count) {    // check for overflow
      wc->wc_count = MAXWORDCOUNT;
    }
  }
}

// Returns true if byte "n" appears in "str".
// Like strchr() but independent of locale.
bool byte_in_str(uint8_t *str, int n)
{
  for (uint8_t *p = str; *p != NUL; p++) {
    if (*p == n) {
      return true;
    }
  }
  return false;
}

// Truncate "slang->sl_syllable" at the first slash and put the following items
// in "slang->sl_syl_items".
int init_syl_tab(slang_T *slang)
{
  ga_init(&slang->sl_syl_items, sizeof(syl_item_T), 4);
  char *p = vim_strchr(slang->sl_syllable, '/');
  while (p != NULL) {
    *p++ = NUL;
    if (*p == NUL) {        // trailing slash
      break;
    }
    char *s = p;
    p = vim_strchr(p, '/');
    int l;
    if (p == NULL) {
      l = (int)strlen(s);
    } else {
      l = (int)(p - s);
    }
    if (l >= SY_MAXLEN) {
      return SP_FORMERROR;
    }

    syl_item_T *syl = GA_APPEND_VIA_PTR(syl_item_T, &slang->sl_syl_items);
    xmemcpyz(syl->sy_chars, s, (size_t)l);
    syl->sy_len = l;
  }
  return OK;
}

// Count the number of syllables in "word".
// When "word" contains spaces the syllables after the last space are counted.
// Returns zero if syllables are not defines.
static int count_syllables(slang_T *slang, const char *word)
  FUNC_ATTR_NONNULL_ALL
{
  if (slang->sl_syllable == NULL) {
    return 0;
  }

  int cnt = 0;
  bool skip = false;
  int len;

  for (const char *p = word; *p != NUL; p += len) {
    // When running into a space reset counter.
    if (*p == ' ') {
      len = 1;
      cnt = 0;
      continue;
    }

    // Find longest match of syllable items.
    len = 0;
    for (int i = 0; i < slang->sl_syl_items.ga_len; i++) {
      syl_item_T *syl = ((syl_item_T *)slang->sl_syl_items.ga_data) + i;
      if (syl->sy_len > len
          && strncmp(p, syl->sy_chars, (size_t)syl->sy_len) == 0) {
        len = syl->sy_len;
      }
    }
    if (len != 0) {     // found a match, count syllable
      cnt++;
      skip = false;
    } else {
      // No recognized syllable item, at least a syllable char then?
      int c = utf_ptr2char(p);
      len = utfc_ptr2len(p);
      if (vim_strchr(slang->sl_syllable, c) == NULL) {
        skip = false;               // No, search for next syllable
      } else if (!skip) {
        cnt++;                      // Yes, count it
        skip = true;                // don't count following syllable chars
      }
    }
  }
  return cnt;
}

/// Parse 'spelllang' and set w_s->b_langp accordingly.
/// @return  NULL if it's OK, an untranslated error message otherwise.
char *parse_spelllang(win_T *wp)
{
  char region_cp[3];
  char lang[MAXWLEN + 1];
  char spf_name[MAXPATHL];
  char *use_region = NULL;
  bool dont_use_region = false;
  bool nobreak = false;
  static bool recursive = false;
  char *ret_msg = NULL;

  bufref_T bufref;
  set_bufref(&bufref, wp->w_buffer);

  // We don't want to do this recursively.  May happen when a language is
  // not available and the SpellFileMissing autocommand opens a new buffer
  // in which 'spell' is set.
  if (recursive) {
    return NULL;
  }
  recursive = true;

  garray_T ga;
  ga_init(&ga, sizeof(langp_T), 2);
  clear_midword(wp);

  // Make a copy of 'spelllang', the SpellFileMissing autocommands may change
  // it under our fingers.
  char *spl_copy = xstrdup(wp->w_s->b_p_spl);

  wp->w_s->b_cjk = 0;

  // Loop over comma separated language names.
  for (char *splp = spl_copy; *splp != NUL;) {
    // Get one language name.
    copy_option_part(&splp, lang, MAXWLEN, ",");
    char *region = NULL;
    int len = (int)strlen(lang);

    if (!valid_spelllang(lang)) {
      continue;
    }

    if (strcmp(lang, "cjk") == 0) {
      wp->w_s->b_cjk = 1;
      continue;
    }

    slang_T *slang;
    bool filename;
    // If the name ends in ".spl" use it as the name of the spell file.
    // If there is a region name let "region" point to it and remove it
    // from the name.
    if (len > 4 && path_fnamecmp(lang + len - 4, ".spl") == 0) {
      filename = true;

      // Locate a region and remove it from the file name.
      char *p = vim_strchr(path_tail(lang), '_');
      if (p != NULL && ASCII_ISALPHA(p[1]) && ASCII_ISALPHA(p[2])
          && !ASCII_ISALPHA(p[3])) {
        xstrlcpy(region_cp, p + 1, 3);
        memmove(p, p + 3, (size_t)(len - (p - lang) - 2));
        region = region_cp;
      } else {
        dont_use_region = true;
      }

      // Check if we loaded this language before.
      for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
        if (path_full_compare(lang, slang->sl_fname, false, true)
            == kEqualFiles) {
          break;
        }
      }
    } else {
      filename = false;
      if (len > 3 && lang[len - 3] == '_') {
        region = lang + len - 2;
        lang[len - 3] = NUL;
      } else {
        dont_use_region = true;
      }

      // Check if we loaded this language before.
      for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
        if (STRICMP(lang, slang->sl_name) == 0) {
          break;
        }
      }
    }

    if (region != NULL) {
      // If the region differs from what was used before then don't
      // use it for 'spellfile'.
      if (use_region != NULL && strcmp(region, use_region) != 0) {
        dont_use_region = true;
      }
      use_region = region;
    }

    // If not found try loading the language now.
    if (slang == NULL) {
      if (filename) {
        spell_load_file(lang, lang, NULL, false);
      } else {
        spell_load_lang(lang);
        // SpellFileMissing autocommands may do anything, including
        // destroying the buffer we are using or closing the window.
        if (!bufref_valid(&bufref) || !win_valid_any_tab(wp)) {
          ret_msg = N_("E797: SpellFileMissing autocommand deleted buffer");
          goto theend;
        }
      }
    }

    // Loop over the languages, there can be several files for "lang".
    for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
      if (filename
          ? path_full_compare(lang, slang->sl_fname, false, true) == kEqualFiles
          : STRICMP(lang, slang->sl_name) == 0) {
        int region_mask = REGION_ALL;
        if (!filename && region != NULL) {
          // find region in sl_regions
          int c = find_region(slang->sl_regions, region);
          if (c == REGION_ALL) {
            if (slang->sl_add) {
              if (*slang->sl_regions != NUL) {
                // This addition file is for other regions.
                region_mask = 0;
              }
            } else {
              // This is probably an error.  Give a warning and
              // accept the words anyway.
              smsg(0, _("Warning: region %s not supported"),
                   region);
            }
          } else {
            region_mask = 1 << c;
          }
        }

        if (region_mask != 0) {
          langp_T *p_ = GA_APPEND_VIA_PTR(langp_T, &ga);
          p_->lp_slang = slang;
          p_->lp_region = region_mask;

          use_midword(slang, wp);
          if (slang->sl_nobreak) {
            nobreak = true;
          }
        }
      }
    }
  }

  // round 0: load int_wordlist, if possible.
  // round 1: load first name in 'spellfile'.
  // round 2: load second name in 'spellfile.
  // etc.
  char *spf = curwin->w_s->b_p_spf;
  for (int round = 0; round == 0 || *spf != NUL; round++) {
    if (round == 0) {
      // Internal wordlist, if there is one.
      if (int_wordlist == NULL) {
        continue;
      }
      int_wordlist_spl(spf_name);
    } else {
      // One entry in 'spellfile'.
      copy_option_part(&spf, spf_name, MAXPATHL - 4, ",");
      strcat(spf_name, ".spl");
      int c;

      // If it was already found above then skip it.
      for (c = 0; c < ga.ga_len; c++) {
        char *p = LANGP_ENTRY(ga, c)->lp_slang->sl_fname;
        if (p != NULL
            && path_full_compare(spf_name, p, false, true) == kEqualFiles) {
          break;
        }
      }
      if (c < ga.ga_len) {
        continue;
      }
    }

    slang_T *slang;

    // Check if it was loaded already.
    for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
      if (path_full_compare(spf_name, slang->sl_fname, false, true)
          == kEqualFiles) {
        break;
      }
    }
    if (slang == NULL) {
      // Not loaded, try loading it now.  The language name includes the
      // region name, the region is ignored otherwise.  for int_wordlist
      // use an arbitrary name.
      if (round == 0) {
        STRCPY(lang, "internal wordlist");
      } else {
        xstrlcpy(lang, path_tail(spf_name), MAXWLEN + 1);
        char *p = vim_strchr(lang, '.');
        if (p != NULL) {
          *p = NUL;             // truncate at ".encoding.add"
        }
      }
      slang = spell_load_file(spf_name, lang, NULL, true);

      // If one of the languages has NOBREAK we assume the addition
      // files also have this.
      if (slang != NULL && nobreak) {
        slang->sl_nobreak = true;
      }
    }
    if (slang != NULL) {
      int region_mask = REGION_ALL;
      if (use_region != NULL && !dont_use_region) {
        // find region in sl_regions
        int c = find_region(slang->sl_regions, use_region);
        if (c != REGION_ALL) {
          region_mask = 1 << c;
        } else if (*slang->sl_regions != NUL) {
          // This spell file is for other regions.
          region_mask = 0;
        }
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
  for (int i = 0; i < ga.ga_len; i++) {
    langp_T *lp = LANGP_ENTRY(ga, i);

    // sound folding
    if (!GA_EMPTY(&lp->lp_slang->sl_sal)) {
      // language does sound folding itself
      lp->lp_sallang = lp->lp_slang;
    } else {
      // find first similar language that does sound folding
      for (int j = 0; j < ga.ga_len; j++) {
        langp_T *lp2 = LANGP_ENTRY(ga, j);
        if (!GA_EMPTY(&lp2->lp_slang->sl_sal)
            && strncmp(lp->lp_slang->sl_name,
                       lp2->lp_slang->sl_name, 2) == 0) {
          lp->lp_sallang = lp2->lp_slang;
          break;
        }
      }
    }

    // REP items
    if (!GA_EMPTY(&lp->lp_slang->sl_rep)) {
      // language has REP items itself
      lp->lp_replang = lp->lp_slang;
    } else {
      // find first similar language that has REP items
      for (int j = 0; j < ga.ga_len; j++) {
        langp_T *lp2 = LANGP_ENTRY(ga, j);
        if (!GA_EMPTY(&lp2->lp_slang->sl_rep)
            && strncmp(lp->lp_slang->sl_name,
                       lp2->lp_slang->sl_name, 2) == 0) {
          lp->lp_replang = lp2->lp_slang;
          break;
        }
      }
    }
  }
  redraw_later(wp, UPD_NOT_VALID);

theend:
  xfree(spl_copy);
  recursive = false;
  return ret_msg;
}

// Clear the midword characters for buffer "buf".
static void clear_midword(win_T *wp)
{
  CLEAR_FIELD(wp->w_s->b_spell_ismw);
  XFREE_CLEAR(wp->w_s->b_spell_ismw_mb);
}

/// Use the "sl_midword" field of language "lp" for buffer "buf".
/// They add up to any currently used midword characters.
static void use_midword(slang_T *lp, win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  if (lp->sl_midword == NULL) {  // there aren't any
    return;
  }

  for (char *p = lp->sl_midword; *p != NUL;) {
    const int c = utf_ptr2char(p);
    const int l = utfc_ptr2len(p);
    if (c < 256 && l <= 2) {
      wp->w_s->b_spell_ismw[c] = true;
    } else if (wp->w_s->b_spell_ismw_mb == NULL) {
      // First multi-byte char in "b_spell_ismw_mb".
      wp->w_s->b_spell_ismw_mb = xmemdupz(p, (size_t)l);
    } else {
      // Append multi-byte chars to "b_spell_ismw_mb".
      const int n = (int)strlen(wp->w_s->b_spell_ismw_mb);
      char *bp = xstrnsave(wp->w_s->b_spell_ismw_mb, (size_t)n + (size_t)l);
      xfree(wp->w_s->b_spell_ismw_mb);
      wp->w_s->b_spell_ismw_mb = bp;
      xmemcpyz(bp + n, p, (size_t)l);
    }
    p += l;
  }
}

// Find the region "region[2]" in "rp" (points to "sl_regions").
// Each region is simply stored as the two characters of its name.
// Returns the index if found (first is 0), REGION_ALL if not found.
static int find_region(const char *rp, const char *region)
{
  int i;

  for (i = 0;; i += 2) {
    if (rp[i] == NUL) {
      return REGION_ALL;
    }
    if (rp[i] == region[0] && rp[i + 1] == region[1]) {
      break;
    }
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
int captype(const char *word, const char *end)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const char *p;

  // find first letter
  for (p = word; !spell_iswordp_nmw(p, curwin); MB_PTR_ADV(p)) {
    if (end == NULL ? *p == NUL : p >= end) {
      return 0;             // only non-word characters, illegal word
    }
  }
  int c = mb_ptr2char_adv(&p);
  bool allcap;
  bool firstcap = allcap = SPELL_ISUPPER(c);
  bool past_second = false;              // past second word char

  // Need to check all letters to find a word with mixed upper/lower.
  // But a word with an upper char only at start is a ONECAP.
  for (; end == NULL ? *p != NUL : p < end; MB_PTR_ADV(p)) {
    if (spell_iswordp_nmw(p, curwin)) {
      c = utf_ptr2char(p);
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

  if (allcap) {
    return WF_ALLCAP;
  }
  if (firstcap) {
    return WF_ONECAP;
  }
  return 0;
}

// Delete the internal wordlist and its .spl file.
void spell_delete_wordlist(void)
{
  if (int_wordlist == NULL) {
    return;
  }

  char fname[MAXPATHL] = { 0 };
  os_remove(int_wordlist);
  int_wordlist_spl(fname);
  os_remove(fname);
  XFREE_CLEAR(int_wordlist);
}

// Free all languages.
void spell_free_all(void)
{
  // Go through all buffers and handle 'spelllang'. <VN>
  FOR_ALL_BUFFERS(buf) {
    ga_clear(&buf->b_s.b_langp);
  }

  while (first_lang != NULL) {
    slang_T *slang = first_lang;
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
        parse_spelllang(wp);
        break;
      }
    }
  }
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
  if (buf == NULL) {
    return;
  }

  ml_close(buf, true);
  xfree(buf);
}

// Init the chartab used for spelling for ASCII.
void clear_spell_chartab(spelltab_T *sp)
{
  // Init everything to false (zero).
  CLEAR_FIELD(sp->st_isw);
  CLEAR_FIELD(sp->st_isu);

  for (int i = 0; i < 256; i++) {
    sp->st_fold[i] = (uint8_t)i;
    sp->st_upper[i] = (uint8_t)i;
  }

  // We include digits. A word shouldn't start with a digit, but handling
  // that is done separately.
  for (int i = '0'; i <= '9'; i++) {
    sp->st_isw[i] = true;
  }
  for (int i = 'A'; i <= 'Z'; i++) {
    sp->st_isw[i] = true;
    sp->st_isu[i] = true;
    sp->st_fold[i] = (uint8_t)(i + 0x20);
  }
  for (int i = 'a'; i <= 'z'; i++) {
    sp->st_isw[i] = true;
    sp->st_upper[i] = (uint8_t)(i - 0x20);
  }
}

// Init the chartab used for spelling. Called once while starting up.
// The default is to use isalpha(), but the spell file should define the word
// characters to make it possible that 'encoding' differs from the current
// locale.  For utf-8 we don't use isalpha() but our own functions.
void init_spell_chartab(void)
{
  did_set_spelltab = false;
  clear_spell_chartab(&spelltab);
  for (int i = 128; i < 256; i++) {
    int f = utf_fold(i);
    int u = mb_toupper(i);

    spelltab.st_isu[i] = mb_isupper(i);
    spelltab.st_isw[i] = spelltab.st_isu[i] || mb_islower(i);
    // The folded/upper-cased value is different between latin1 and
    // utf8 for 0xb5, causing E763 for no good reason.  Use the latin1
    // value for utf-8 to avoid this.
    spelltab.st_fold[i] = (f < 256) ? (uint8_t)f : (uint8_t)i;
    spelltab.st_upper[i] = (u < 256) ? (uint8_t)u : (uint8_t)i;
  }
}

/// Returns true if "p" points to a word character.
/// As a special case we see "midword" characters as word character when it is
/// followed by a word character.  This finds they'there but not 'they there'.
/// Thus this only works properly when past the first character of the word.
///
/// @param wp Buffer used.
bool spell_iswordp(const char *p, const win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  const int l = utfc_ptr2len(p);
  const char *s = p;
  if (l == 1) {
    // be quick for ASCII
    if (wp->w_s->b_spell_ismw[(uint8_t)(*p)]) {
      s = p + 1;                      // skip a mid-word character
    }
  } else {
    int c = utf_ptr2char(p);
    if (c < 256
        ? wp->w_s->b_spell_ismw[c]
        : (wp->w_s->b_spell_ismw_mb != NULL
           && vim_strchr(wp->w_s->b_spell_ismw_mb, c) != NULL)) {
      s = p + l;
    }
  }

  int c = utf_ptr2char(s);
  if (c > 255) {
    return spell_mb_isword_class(mb_get_class(s), wp);
  }
  return spelltab.st_isw[c];
}

// Returns true if "p" points to a word character.
// Unlike spell_iswordp() this doesn't check for "midword" characters.
bool spell_iswordp_nmw(const char *p, win_T *wp)
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
static bool spell_mb_isword_class(int cl, const win_T *wp)
  FUNC_ATTR_PURE FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (wp->w_s->b_cjk) {
    // East Asian characters are not considered word characters.
    return cl == 2 || cl == 0x2800;
  }
  return cl >= 2 && cl != 0x2070 && cl != 0x2080 && cl != 3;
}

// Returns true if "p" points to a word character.
// Wide version of spell_iswordp().
static bool spell_iswordp_w(const int *p, const win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  const int *s;

  if (*p <
      256 ? wp->w_s->b_spell_ismw[*p] : (wp->w_s->b_spell_ismw_mb != NULL
                                         && vim_strchr(wp->w_s->b_spell_ismw_mb,
                                                       *p) != NULL)) {
    s = p + 1;
  } else {
    s = p;
  }

  if (*s > 255) {
    return spell_mb_isword_class(utf_class(*s), wp);
  }
  return spelltab.st_isw[*s];
}

// Case-fold "str[len]" into "buf[buflen]".  The result is NUL terminated.
// Uses the character definitions from the .spl file.
// When using a multi-byte 'encoding' the length may change!
// Returns FAIL when something wrong.
int spell_casefold(const win_T *wp, const char *str, int len, char *buf, int buflen)
  FUNC_ATTR_NONNULL_ALL
{
  if (len >= buflen) {
    buf[0] = NUL;
    return FAIL;                // result will not fit
  }

  int outi = 0;

  // Fold one character at a time.
  for (const char *p = str; p < str + len;) {
    if (outi + MB_MAXBYTES > buflen) {
      buf[outi] = NUL;
      return FAIL;
    }
    int c = mb_cptr2char_adv(&p);

    // Exception: greek capital sigma 0x03A3 folds to 0x03C3, except
    // when it is the last character in a word, then it folds to
    // 0x03C2.
    if (c == 0x03a3 || c == 0x03c2) {
      if (p == str + len || !spell_iswordp(p, wp)) {
        c = 0x03c2;
      } else {
        c = 0x03c3;
      }
    } else {
      c = SPELL_TOFOLD(c);
    }

    outi += utf_char2bytes(c, buf + outi);
  }
  buf[outi] = NUL;

  return OK;
}

// Check if the word at line "lnum" column "col" is required to start with a
// capital.  This uses 'spellcapcheck' of the buffer in window "wp".
bool check_need_cap(win_T *wp, linenr_T lnum, colnr_T col)
{
  if (wp->w_s->b_cap_prog == NULL) {
    return false;
  }

  bool need_cap = false;
  char *line = col ? ml_get_buf(wp->w_buffer, lnum) : NULL;
  char *line_copy = NULL;
  colnr_T endcol = 0;
  if (col == 0 || getwhitecols(line) >= col) {
    // At start of line, check if previous line is empty or sentence
    // ends there.
    if (lnum == 1) {
      need_cap = true;
    } else {
      line = ml_get_buf(wp->w_buffer, lnum - 1);
      if (*skipwhite(line) == NUL) {
        need_cap = true;
      } else {
        // Append a space in place of the line break.
        line_copy = concat_str(line, " ");
        line = line_copy;
        endcol = (colnr_T)strlen(line);
      }
    }
  } else {
    endcol = col;
  }

  if (endcol > 0) {
    // Check if sentence ends before the bad word.
    regmatch_T regmatch = {
      .regprog = wp->w_s->b_cap_prog,
      .rm_ic = false
    };
    char *p = line + endcol;
    while (true) {
      MB_PTR_BACK(line, p);
      if (p == line || spell_iswordp_nmw(p, wp)) {
        break;
      }
      if (vim_regexec(&regmatch, p, 0)
          && regmatch.endp[0] == line + endcol) {
        need_cap = true;
        break;
      }
    }
    wp->w_s->b_cap_prog = regmatch.regprog;
  }

  xfree(line_copy);

  return need_cap;
}

// ":spellrepall"
void ex_spellrepall(exarg_T *eap)
{
  pos_T pos = curwin->w_cursor;
  bool save_ws = p_ws;
  linenr_T prev_lnum = 0;

  if (repl_from == NULL || repl_to == NULL) {
    emsg(_("E752: No previous spell replacement"));
    return;
  }
  const size_t repl_from_len = strlen(repl_from);
  const size_t repl_to_len = strlen(repl_to);
  const int addlen = (int)(repl_to_len - repl_from_len);

  const size_t frompatsize = repl_from_len + 7;
  char *frompat = xmalloc(frompatsize);
  size_t frompatlen = (size_t)snprintf(frompat, frompatsize, "\\V\\<%s\\>", repl_from);
  p_ws = false;

  sub_nsubs = 0;
  sub_nlines = 0;
  curwin->w_cursor.lnum = 0;
  while (!got_int) {
    if (do_search(NULL, '/', '/', frompat, frompatlen, 1, SEARCH_KEEP, NULL) == 0
        || u_save_cursor() == FAIL) {
      break;
    }

    // Only replace when the right word isn't there yet.  This happens
    // when changing "etc" to "etc.".
    char *line = get_cursor_line_ptr();
    if (addlen <= 0
        || strncmp(line + curwin->w_cursor.col, repl_to, repl_to_len) != 0) {
      char *p = xmalloc((size_t)get_cursor_line_len() + (size_t)addlen + 1);
      memmove(p, line, (size_t)curwin->w_cursor.col);
      STRCPY(p + curwin->w_cursor.col, repl_to);
      strcat(p, line + curwin->w_cursor.col + repl_from_len);
      ml_replace(curwin->w_cursor.lnum, p, false);
      inserted_bytes(curwin->w_cursor.lnum, curwin->w_cursor.col,
                     (int)repl_from_len, (int)repl_to_len);

      if (curwin->w_cursor.lnum != prev_lnum) {
        sub_nlines++;
        prev_lnum = curwin->w_cursor.lnum;
      }
      sub_nsubs++;
    }
    curwin->w_cursor.col += (colnr_T)repl_to_len;
  }

  p_ws = save_ws;
  curwin->w_cursor = pos;
  xfree(frompat);

  if (sub_nsubs == 0) {
    semsg(_("E753: Not found: %s"), repl_from);
  } else {
    do_sub_msg(false);
  }
}

/// Make a copy of "word", with the first letter upper or lower cased, to
/// "wcopy[MAXWLEN]".  "word" must not be empty.
/// The result is NUL terminated.
///
/// @param[in]  word  source string to copy
/// @param[in,out]  wcopy  copied string, with case of first letter changed
/// @param[in]  upper  True to upper case, otherwise lower case
void onecap_copy(const char *word, char *wcopy, bool upper)
{
  const char *p = word;
  int c = mb_cptr2char_adv(&p);
  if (upper) {
    c = SPELL_TOUPPER(c);
  } else {
    c = SPELL_TOFOLD(c);
  }
  int l = utf_char2bytes(c, wcopy);
  xstrlcpy(wcopy + l, p, (size_t)(MAXWLEN - l));
}

// Make a copy of "word" with all the letters upper cased into
// "wcopy[MAXWLEN]".  The result is NUL terminated.
void allcap_copy(const char *word, char *wcopy)
{
  char *d = wcopy;
  for (const char *s = word; *s != NUL;) {
    int c = mb_cptr2char_adv(&s);

    if (c == 0xdf) {
      c = 'S';
      if (d - wcopy >= MAXWLEN - 1) {
        break;
      }
      *d++ = (char)c;
    } else {
      c = SPELL_TOUPPER(c);
    }

    if (d - wcopy >= MAXWLEN - MB_MAXBYTES) {
      break;
    }
    d += utf_char2bytes(c, d);
  }
  *d = NUL;
}

// Case-folding may change the number of bytes: Count nr of chars in
// fword[flen] and return the byte length of that many chars in "word".
int nofold_len(char *fword, int flen, char *word)
{
  char *p;
  int i = 0;

  for (p = fword; p < fword + flen; MB_PTR_ADV(p)) {
    i++;
  }
  for (p = word; i > 0; MB_PTR_ADV(p)) {
    i--;
  }
  return (int)(p - word);
}

// Copy "fword" to "cword", fixing case according to "flags".
void make_case_word(char *fword, char *cword, int flags)
{
  if (flags & WF_ALLCAP) {
    // Make it all upper-case
    allcap_copy(fword, cword);
  } else if (flags & WF_ONECAP) {
    // Make the first letter upper-case
    onecap_copy(fword, cword, true);
  } else {
    // Use goodword as-is.
    STRCPY(cword, fword);
  }
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
        char sound[MAXWLEN];
        spell_soundfold(lp->lp_slang, (char *)word, false, sound);
        return xstrdup(sound);
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
void spell_soundfold(slang_T *slang, char *inword, bool folded, char *res)
{
  if (slang->sl_sofo) {
    // SOFOFROM and SOFOTO used
    spell_soundfold_sofo(slang, inword, res);
  } else {
    char fword[MAXWLEN];
    char *word;
    // SAL items used.  Requires the word to be case-folded.
    if (folded) {
      word = inword;
    } else {
      spell_casefold(curwin, inword, (int)strlen(inword), fword, MAXWLEN);
      word = fword;
    }

    spell_soundfold_wsal(slang, word, res);
  }
}

// Perform sound folding of "inword" into "res" according to SOFOFROM and
// SOFOTO lines.
static void spell_soundfold_sofo(slang_T *slang, const char *inword, char *res)
{
  int ri = 0;

  int prevc = 0;

  // The sl_sal_first[] table contains the translation for chars up to
  // 255, sl_sal the rest.
  for (const char *s = inword; *s != NUL;) {
    int c = mb_cptr2char_adv(&s);
    if (utf_class(c) == 0) {
      c = ' ';
    } else if (c < 256) {
      c = slang->sl_sal_first[c];
    } else {
      int *ip = ((int **)slang->sl_sal.ga_data)[c & 0xff];
      if (ip == NULL) {               // empty list, can't match
        c = NUL;
      } else {
        while (true) {                // find "c" in the list
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
    }

    if (c != NUL && c != prevc) {
      ri += utf_char2bytes(c, res + ri);
      if (ri + MB_MAXBYTES > MAXWLEN) {
        break;
      }
      prevc = c;
    }
  }

  res[ri] = NUL;
}

// Turn "inword" into its sound-a-like equivalent in "res[MAXWLEN]".
// Multi-byte version of spell_soundfold().
static void spell_soundfold_wsal(slang_T *slang, const char *inword, char *res)
{
  int word[MAXWLEN] = { 0 };
  bool did_white = false;

  // Convert the multi-byte string to a wide-character string.
  // Remove accents, if wanted.  We actually remove all non-word characters.
  // But keep white space.
  int wordlen = 0;
  for (const char *s = inword; *s != NUL;) {
    const char *t = s;
    int c = mb_cptr2char_adv(&s);
    if (slang->sl_rem_accents) {
      if (utf_class(c) == 0) {
        if (did_white) {
          continue;
        }
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

  salitem_T *smp = (salitem_T *)slang->sl_sal.ga_data;
  int wres[MAXWLEN] = { 0 };
  int k = 0;
  int p0 = -333;
  int c;
  // This algorithm comes from Aspell phonet.cpp.
  // Converted from C++ to C.  Added support for multi-byte chars.
  // Changed to keep spaces.
  int i = 0;
  int reslen = 0;
  int z = 0;
  while ((c = word[i]) != NUL) {
    // Start with the first rule that has the character in the word.
    int n = slang->sl_sal_first[c & 0xff];
    int z0 = 0;

    if (n >= 0) {
      int *ws;
      // Check all rules for the same index byte.
      // If c is 0x300 need extra check for the end of the array, as
      // (c & 0xff) is NUL.
      for (; ((ws = smp[n].sm_lead_w)[0] & 0xff) == (c & 0xff)
           && ws[0] != NUL; n++) {
        // Quickly skip entries that don't match the word.  Most
        // entries are less than three chars, optimize for that.
        if (c != ws[0]) {
          continue;
        }
        k = smp[n].sm_leadlen;
        if (k > 1) {
          if (word[i + 1] != ws[1]) {
            continue;
          }
          if (k > 2) {
            int j;
            for (j = 2; j < k; j++) {
              if (word[i + j] != ws[j]) {
                break;
              }
            }
            if (j < k) {
              continue;
            }
          }
        }

        int *pf;
        if ((pf = smp[n].sm_oneof_w) != NULL) {
          // Check for match with one of the chars in "sm_oneof".
          while (*pf != NUL && *pf != word[i + k]) {
            pf++;
          }
          if (*pf == NUL) {
            continue;
          }
          k++;
        }
        char *s = smp[n].sm_rules;
        int pri = 5;            // default priority

        p0 = (uint8_t)(*s);
        int k0 = k;
        while (*s == '-' && k > 1) {
          k--;
          s++;
        }
        if (*s == '<') {
          s++;
        }
        if (ascii_isdigit(*s)) {
          // determine priority
          pri = (uint8_t)(*s) - '0';
          s++;
        }
        if (*s == '^' && *(s + 1) == '^') {
          s++;
        }

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
          int c0 = word[i + k - 1];
          int n0 = slang->sl_sal_first[c0 & 0xff];

          if (slang->sl_followup && k > 1 && n0 >= 0
              && p0 != '-' && word[i + k] != NUL) {
            // Test follow-up rule for "word[i + k]"; loop over
            // all entries with the same index byte.
            for (; ((ws = smp[n0].sm_lead_w)[0] & 0xff)
                 == (c0 & 0xff); n0++) {
              // Quickly skip entries that don't match the word.
              if (c0 != ws[0]) {
                continue;
              }
              k0 = smp[n0].sm_leadlen;
              if (k0 > 1) {
                if (word[i + k] != ws[1]) {
                  continue;
                }
                if (k0 > 2) {
                  pf = word + i + k + 1;
                  int j;
                  for (j = 2; j < k0; j++) {
                    if (*pf++ != ws[j]) {
                      break;
                    }
                  }
                  if (j < k0) {
                    continue;
                  }
                }
              }
              k0 += k - 1;

              if ((pf = smp[n0].sm_oneof_w) != NULL) {
                // Check for match with one of the chars in
                // "sm_oneof".
                while (*pf != NUL && *pf != word[i + k0]) {
                  pf++;
                }
                if (*pf == NUL) {
                  continue;
                }
                k0++;
              }

              p0 = 5;
              s = smp[n0].sm_rules;
              while (*s == '-') {
                // "k0" gets NOT reduced because
                // "if (k0 == k)"
                s++;
              }
              if (*s == '<') {
                s++;
              }
              if (ascii_isdigit(*s)) {
                p0 = (uint8_t)(*s) - '0';
                s++;
              }

              if (*s == NUL
                  // *s == '^' cuts
                  || (*s == '$'
                      && !spell_iswordp_w(word + i + k0,
                                          curwin))) {
                if (k0 == k) {
                  // this is just a piece of the string
                  continue;
                }

                if (p0 < pri) {
                  // priority too low
                  continue;
                }
                // rule fits; stop search
                break;
              }
            }

            if (p0 >= pri && (smp[n0].sm_lead_w[0] & 0xff)
                == (c0 & 0xff)) {
              continue;
            }
          }

          // replace string
          ws = smp[n].sm_to_w;
          s = smp[n].sm_rules;
          p0 = (vim_strchr(s, '<') != NULL) ? 1 : 0;
          if (p0 == 1 && z == 0) {
            // rule with '<' is used
            if (reslen > 0 && ws != NULL && *ws != NUL
                && (wres[reslen - 1] == c
                    || wres[reslen - 1] == *ws)) {
              reslen--;
            }
            z0 = 1;
            z = 1;
            k0 = 0;
            if (ws != NULL) {
              while (*ws != NUL && word[i + k0] != NUL) {
                word[i + k0] = *ws;
                k0++;
                ws++;
              }
            }
            if (k > k0) {
              memmove(word + i + k0, word + i + k, sizeof(int) * (size_t)(wordlen - (i + k) + 1));
            }

            // new "actual letter"
            c = word[i];
          } else {
            // no '<' rule used
            i += k - 1;
            z = 0;
            if (ws != NULL) {
              while (*ws != NUL && ws[1] != NUL
                     && reslen < MAXWLEN) {
                if (reslen == 0 || wres[reslen - 1] != *ws) {
                  wres[reslen++] = *ws;
                }
                ws++;
              }
            }
            // new "actual letter"
            if (ws == NULL) {
              c = NUL;
            } else {
              c = *ws;
            }
            if (strstr(s, "^^") != NULL) {
              if (c != NUL) {
                wres[reslen++] = c;
              }
              memmove(word, word + i + 1, sizeof(int) * (size_t)(wordlen - (i + 1) + 1));
              i = 0;
              z0 = 1;
            }
          }
          break;
        }
      }
    } else if (ascii_iswhite(c)) {
      c = ' ';
      k = 1;
    }

    if (z0 == 0) {
      if (k && !p0 && reslen < MAXWLEN && c != NUL
          && (!slang->sl_collapse || reslen == 0
              || wres[reslen - 1] != c)) {
        // condense only double letters
        wres[reslen++] = c;
      }

      i++;
      z = 0;
      k = 0;
    }
  }

  // Convert wide characters in "wres" to a multi-byte string in "res".
  int l = 0;
  for (int n = 0; n < reslen; n++) {
    l += utf_char2bytes(wres[n], res + l);
    if (l + MB_MAXBYTES > MAXWLEN) {
      break;
    }
  }
  res[l] = NUL;
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
    msg_puts(lp->lp_slang->sl_fname);
    msg_putchar('\n');
    const char *const p = lp->lp_slang->sl_info;
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
  if (no_spell_checking(curwin)) {
    return;
  }
  OptVal spl = get_option_value(kOptSpelllang, OPT_LOCAL);

  // Create a new empty buffer in a new window.
  do_cmdline_cmd("new");

  // enable spelling locally in the new window
  set_option_value_give_err(kOptSpell, BOOLEAN_OPTVAL(true), OPT_LOCAL);
  set_option_value_give_err(kOptSpelllang, spl, OPT_LOCAL);
  optval_free(spl);

  if (!buf_is_empty(curbuf)) {
    return;
  }

  spell_dump_compl(NULL, 0, NULL, eap->forceit ? DUMPFLAG_COUNT : 0);

  // Delete the empty line that we started with.
  if (curbuf->b_ml.ml_line_count > 1) {
    ml_delete(curbuf->b_ml.ml_line_count, false);
  }
  redraw_later(curwin, UPD_NOT_VALID);
}

/// Go through all possible words and:
/// 1. When "pat" is NULL: dump a list of all words in the current buffer.
///      "ic" and "dir" are not used.
/// 2. When "pat" is not NULL: add matching words to insert mode completion.
///
/// @param pat  leading part of the word
/// @param ic  ignore case
/// @param dir  direction for adding matches
/// @param dumpflags_arg  DUMPFLAG_*
void spell_dump_compl(char *pat, int ic, Direction *dir, int dumpflags_arg)
{
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  char word[MAXWLEN];
  linenr_T lnum = 0;
  char *region_names = NULL;         // region names being used
  bool do_region = true;                    // dump region names and numbers
  int dumpflags = dumpflags_arg;

  // When ignoring case or when the pattern starts with capital pass this on
  // to dump_word().
  if (pat != NULL) {
    if (ic) {
      dumpflags |= DUMPFLAG_ICASE;
    } else {
      int n = captype(pat, NULL);
      if (n == WF_ONECAP) {
        dumpflags |= DUMPFLAG_ONECAP;
      } else if (n == WF_ALLCAP
                 && (int)strlen(pat) > utfc_ptr2len(pat)) {
        dumpflags |= DUMPFLAG_ALLCAP;
      }
    }
  }

  // Find out if we can support regions: All languages must support the same
  // regions or none at all.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    langp_T *lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    char *p = lp->lp_slang->sl_regions;
    if (p[0] != 0) {
      if (region_names == NULL) {           // first language with regions
        region_names = p;
      } else if (strcmp(region_names, p) != 0) {
        do_region = false;                  // region names are different
        break;
      }
    }
  }

  if (do_region && region_names != NULL && pat == NULL) {
    vim_snprintf(IObuff, IOSIZE, "/regions=%s", region_names);
    ml_append(lnum++, IObuff, 0, false);
  } else {
    do_region = false;
  }

  // Loop over all files loaded for the entries in 'spelllang'.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    langp_T *lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang_T *slang = lp->lp_slang;
    if (slang->sl_fbyts == NULL) {          // reloading failed
      continue;
    }

    if (pat == NULL) {
      vim_snprintf(IObuff, IOSIZE, "# file: %s", slang->sl_fname);
      ml_append(lnum++, IObuff, 0, false);
    }

    int patlen;
    // When matching with a pattern and there are no prefixes only use
    // parts of the tree that match "pat".
    if (pat != NULL && slang->sl_pbyts == NULL) {
      patlen = (int)strlen(pat);
    } else {
      patlen = -1;
    }

    // round 1: case-folded tree
    // round 2: keep-case tree
    for (int round = 1; round <= 2; round++) {
      uint8_t *byts;
      idx_T *idxs;
      if (round == 1) {
        dumpflags &= ~DUMPFLAG_KEEPCASE;
        byts = slang->sl_fbyts;
        idxs = slang->sl_fidxs;
      } else {
        dumpflags |= DUMPFLAG_KEEPCASE;
        byts = slang->sl_kbyts;
        idxs = slang->sl_kidxs;
      }
      if (byts == NULL) {
        continue;                       // array is empty
      }
      int depth = 0;
      arridx[0] = 0;
      curi[0] = 1;
      while (depth >= 0 && !got_int
             && (pat == NULL || !ins_compl_interrupted())) {
        if (curi[depth] > byts[arridx[depth]]) {
          // Done all bytes at this node, go up one level.
          depth--;
          line_breakcheck();
          ins_compl_check_keys(50, false);
        } else {
          // Do one more byte at this node.
          int n = arridx[depth] + curi[depth];
          curi[depth]++;
          int c = byts[n];
          if (c == 0 || depth >= MAXWLEN - 1) {
            // End of word or reached maximum length, deal with the
            // word.
            // Don't use keep-case words in the fold-case tree,
            // they will appear in the keep-case tree.
            // Only use the word when the region matches.
            int flags = (int)idxs[n];
            if ((round == 2 || (flags & WF_KEEPCAP) == 0)
                && (flags & WF_NEEDCOMP) == 0
                && (do_region
                    || (flags & WF_REGION) == 0
                    || (((unsigned)flags >> 16)
                        & (unsigned)lp->lp_region) != 0)) {
              word[depth] = NUL;
              if (!do_region) {
                flags &= ~WF_REGION;
              }

              // Dump the basic word if there is no prefix or
              // when it's the first one.
              c = (int)((unsigned)flags >> 24);
              if (c == 0 || curi[depth] == 2) {
                dump_word(slang, word, pat, dir, dumpflags, flags, lnum);
                if (pat == NULL) {
                  lnum++;
                }
              }

              // Apply the prefix, if there is one.
              if (c != 0) {
                lnum = dump_prefixes(slang, word, pat, dir,
                                     dumpflags, flags, lnum);
              }
            }
          } else {
            // Normal char, go one level deeper.
            word[depth++] = (char)c;
            arridx[depth] = idxs[n];
            curi[depth] = 1;

            // Check if this character matches with the pattern.
            // If not skip the whole tree below it.
            // Always ignore case here, dump_word() will check
            // proper case later.  This isn't exactly right when
            // length changes for multi-byte characters with
            // ignore case...
            assert(depth >= 0);
            if (depth <= patlen
                && mb_strnicmp(word, pat, (size_t)depth) != 0) {
              depth--;
            }
          }
        }
      }
    }
  }
}

/// Dumps one word: apply case modifications and append a line to the buffer.
/// When "lnum" is zero add insert mode completion.
static void dump_word(slang_T *slang, char *word, char *pat, Direction *dir, int dumpflags,
                      int wordflags, linenr_T lnum)
{
  bool keepcap = false;
  char *p;
  char cword[MAXWLEN];
  char badword[MAXWLEN + 10];
  int flags = wordflags;

  if (dumpflags & DUMPFLAG_ONECAP) {
    flags |= WF_ONECAP;
  }
  if (dumpflags & DUMPFLAG_ALLCAP) {
    flags |= WF_ALLCAP;
  }

  if ((dumpflags & DUMPFLAG_KEEPCASE) == 0 && (flags & WF_CAPMASK) != 0) {
    // Need to fix case according to "flags".
    make_case_word(word, cword, flags);
    p = cword;
  } else {
    p = word;
    if ((dumpflags & DUMPFLAG_KEEPCASE)
        && ((captype(word, NULL) & WF_KEEPCAP) == 0
            || (flags & WF_FIXCAP) != 0)) {
      keepcap = true;
    }
  }
  char *tw = p;

  if (pat == NULL) {
    // Add flags and regions after a slash.
    if ((flags & (WF_BANNED | WF_RARE | WF_REGION)) || keepcap) {
      STRCPY(badword, p);
      strcat(badword, "/");
      if (keepcap) {
        strcat(badword, "=");
      }
      if (flags & WF_BANNED) {
        strcat(badword, "!");
      } else if (flags & WF_RARE) {
        strcat(badword, "?");
      }
      if (flags & WF_REGION) {
        for (int i = 0; i < 7; i++) {
          if (flags & (0x10000 << i)) {
            const size_t badword_len = strlen(badword);
            snprintf(badword + badword_len,
                     sizeof(badword) - badword_len,
                     "%d", i + 1);
          }
        }
      }
      p = badword;
    }

    if (dumpflags & DUMPFLAG_COUNT) {
      hashitem_T *hi;

      // Include the word count for ":spelldump!".
      hi = hash_find(&slang->sl_wordcount, tw);
      if (!HASHITEM_EMPTY(hi)) {
        vim_snprintf(IObuff, IOSIZE, "%s\t%d",
                     tw, HI2WC(hi)->wc_count);
        p = IObuff;
      }
    }

    ml_append(lnum, p, 0, false);
  } else if (((dumpflags & DUMPFLAG_ICASE)
              ? mb_strnicmp(p, pat, strlen(pat)) == 0
              : strncmp(p, pat, strlen(pat)) == 0)
             && ins_compl_add_infercase(p, (int)strlen(p),
                                        p_ic, NULL, *dir, false) == OK) {
    // if dir was BACKWARD then honor it just once
    *dir = FORWARD;
  }
}

/// For ":spelldump": Find matching prefixes for "word".  Prepend each to
/// "word" and append a line to the buffer.
/// When "lnum" is zero add insert mode completion.
///
/// @param word  case-folded word
/// @param flags  flags with prefix ID
///
/// @return  the updated line number.
static linenr_T dump_prefixes(slang_T *slang, char *word, char *pat, Direction *dir, int dumpflags,
                              int flags, linenr_T startlnum)
{
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  char prefix[MAXWLEN];
  char word_up[MAXWLEN];
  bool has_word_up = false;
  linenr_T lnum = startlnum;

  // If the word starts with a lower-case letter make the word with an
  // upper-case letter in word_up[].
  int c = utf_ptr2char(word);
  if (SPELL_TOUPPER(c) != c) {
    onecap_copy(word, word_up, true);
    has_word_up = true;
  }

  uint8_t *byts = slang->sl_pbyts;
  idx_T *idxs = slang->sl_pidxs;
  if (byts != NULL) {           // array not is empty
    // Loop over all prefixes, building them byte-by-byte in prefix[].
    // When at the end of a prefix check that it supports "flags".
    int depth = 0;
    arridx[0] = 0;
    curi[0] = 1;
    while (depth >= 0 && !got_int) {
      int n = arridx[depth];
      int len = byts[n];
      if (curi[depth] > len) {
        // Done all bytes at this node, go up one level.
        depth--;
        line_breakcheck();
      } else {
        // Do one more byte at this node.
        n += curi[depth];
        curi[depth]++;
        c = byts[n];
        if (c == 0) {
          // End of prefix, find out how many IDs there are.
          int i;
          for (i = 1; i < len; i++) {
            if (byts[n + i] != 0) {
              break;
            }
          }
          curi[depth] += i - 1;

          c = valid_word_prefix(i, n, flags, word, slang, false);
          if (c != 0) {
            xstrlcpy(prefix + depth, word, (size_t)(MAXWLEN - depth));
            dump_word(slang, prefix, pat, dir, dumpflags,
                      (c & WF_RAREPFX) ? (flags | WF_RARE) : flags, lnum);
            if (lnum != 0) {
              lnum++;
            }
          }

          // Check for prefix that matches the word when the
          // first letter is upper-case, but only if the prefix has
          // a condition.
          if (has_word_up) {
            c = valid_word_prefix(i, n, flags, word_up, slang, true);
            if (c != 0) {
              xstrlcpy(prefix + depth, word_up, (size_t)(MAXWLEN - depth));
              dump_word(slang, prefix, pat, dir, dumpflags,
                        (c & WF_RAREPFX) ? (flags | WF_RARE) : flags, lnum);
              if (lnum != 0) {
                lnum++;
              }
            }
          }
        } else {
          // Normal char, go one level deeper.
          prefix[depth++] = (char)c;
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
char *spell_to_word_end(char *start, win_T *win)
{
  char *p = start;

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
  if (no_spell_checking(curwin)) {
    return startcol;
  }

  char *line = get_cursor_line_ptr();
  char *p;

  // Find a word character before "startcol".
  for (p = line + startcol; p > line;) {
    MB_PTR_BACK(line, p);
    if (spell_iswordp_nmw(p, curwin)) {
      break;
    }
  }

  int col = 0;

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
  spell_expand_need_cap = check_need_cap(curwin, curwin->w_cursor.lnum, col);
}

// Get list of spelling suggestions.
// Used for Insert mode completion CTRL-X ?.
// Returns the number of matches.  The matches are in "matchp[]", array of
// allocated strings.
int expand_spelling(linenr_T lnum, char *pat, char ***matchp)
{
  garray_T ga;

  spell_suggest_list(&ga, pat, 100, spell_expand_need_cap, true);
  *matchp = ga.ga_data;
  return ga.ga_len;
}

/// @return  true if "val" is a valid 'spelllang' value.
bool valid_spelllang(const char *val)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return valid_name(val, ".-_,@");
}

/// @return  true if "val" is a valid 'spellfile' value.
bool valid_spellfile(const char *val)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  char spf_name[MAXPATHL];
  char *spf = (char *)val;
  while (*spf != NUL) {
    size_t l = copy_option_part(&spf, spf_name, MAXPATHL, ",");
    if (l >= MAXPATHL - 4 || l < 4 || strcmp(spf_name + l - 4, ".add") != 0) {
      return false;
    }
    for (char *s = spf_name; *s != NUL; s++) {
      if (!vim_is_fname_char((uint8_t)(*s))) {
        return false;
      }
    }
  }
  return true;
}

const char *did_set_spell_option(void)
{
  const char *errmsg = NULL;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == curbuf && wp->w_p_spell) {
      errmsg = parse_spelllang(wp);
      break;
    }
  }
  return errmsg;
}

/// Set curbuf->b_cap_prog to the regexp program for 'spellcapcheck'.
/// Return error message when failed, NULL when OK.
const char *compile_cap_prog(synblock_T *synblock)
  FUNC_ATTR_NONNULL_ALL
{
  regprog_T *rp = synblock->b_cap_prog;

  if (synblock->b_p_spc == NULL || *synblock->b_p_spc == NUL) {
    synblock->b_cap_prog = NULL;
  } else {
    // Prepend a ^ so that we only match at one column
    char *re = concat_str("^", synblock->b_p_spc);
    synblock->b_cap_prog = vim_regcomp(re, RE_MAGIC);
    xfree(re);
    if (synblock->b_cap_prog == NULL) {
      synblock->b_cap_prog = rp;         // restore the previous program
      return e_invarg;
    }
  }

  vim_regfree(rp);
  return NULL;
}
