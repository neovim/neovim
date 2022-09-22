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

#include <assert.h>               // for assert
#include <inttypes.h>             // for uint32_t, uint16_t, uint8_t
#include <limits.h>               // for INT_MAX
#include <stdbool.h>              // for false, true, bool
#include <stddef.h>               // for NULL, size_t, ptrdiff_t
#include <stdio.h>                // for snprintf
#include <string.h>               // for memmove, strstr, memcpy, memset
#include <wctype.h>

#include "hunspell/hunspell_wrapper.h"
#include "nvim/ascii.h"           // for NUL, ascii_isdigit, ascii_iswhite
#include "nvim/autocmd.h"         // for apply_autocmds
#include "nvim/buffer.h"          // for bufref_valid, set_bufref, buf_is_empty
#include "nvim/buffer_defs.h"     // for win_T, synblock_T, buf_T, w_p_...
#include "nvim/change.h"          // for changed_bytes
#include "nvim/charset.h"         // for skipwhite, getwhitecols, skipbin
#include "nvim/cursor.h"          // for get_cursor_line_ptr
#include "nvim/decoration.h"
#include "nvim/drawscreen.h"      // for NOT_VALID, redraw_later
#include "nvim/eval/typval.h"     // for semsg
#include "nvim/ex_cmds.h"         // for do_sub_msg
#include "nvim/ex_cmds_defs.h"    // for exarg_T
#include "nvim/ex_docmd.h"        // for do_cmdline_cmd
#include "nvim/garray.h"          // for garray_T, GA_EMPTY, GA_APPEND_...
#include "nvim/gettext.h"         // for _, N_
#include "nvim/hashtab.h"         // for hash_clear_all, hash_init, has...
#include "nvim/highlight_defs.h"  // for HLF_COUNT, hlf_T, HLF_SPB, HLF...
#include "nvim/insexpand.h"       // for ins_compl_add_infercase, ins_c...
#include "nvim/log.h"             // for ELOG
#include "nvim/macros.h"          // for MB_PTR_ADV, MB_PTR_BACK, ASCII...
#include "nvim/mark.h"            // for clearpos
#include "nvim/mbyte.h"           // for utf_ptr2char, utf_char2bytes
#include "nvim/memline.h"         // for ml_append, ml_get_buf, ml_close
#include "nvim/memline_defs.h"    // for memline_T
#include "nvim/memory.h"          // for xfree, xmalloc, xcalloc, xstrdup
#include "nvim/message.h"         // for emsg, msg_puts, give_warning
#include "nvim/option.h"          // for copy_option_part, set_option_v...
#include "nvim/option_defs.h"     // for p_ws, OPT_LOCAL, p_enc, SHM_SE...
#include "nvim/os/fs.h"           // for os_remove
#include "nvim/os/input.h"        // for line_breakcheck
#include "nvim/os/os_defs.h"      // for MAXPATHL
#include "nvim/path.h"            // for path_full_compare, path_tail...
#include "nvim/pos.h"             // for pos_T, colnr_T, linenr_T
#include "nvim/regexp.h"          // for vim_regfree, vim_regexec, vim_...
#include "nvim/regexp_defs.h"     // for regmatch_T, regprog_T
#include "nvim/runtime.h"         // for DIP_ALL, do_in_runtimepath
#include "nvim/search.h"          // for SEARCH_KEEP, for do_search
#include "nvim/spell.h"           // for FUNC_ATTR_NONNULL_ALL, FUNC_AT...
#include "nvim/spell_defs.h"      // for slang_T, langp_T, MAXWLEN, sal...
#include "nvim/spellsuggest.h"    // for spell_suggest_list
#include "nvim/strings.h"         // for vim_strchr, vim_snprintf, conc...
#include "nvim/syntax.h"          // for syn_get_id, syntax_present
#include "nvim/types.h"           // for char_u
#include "nvim/undo.h"            // for u_save_cursor
#include "nvim/vim.h"             // for curwin, strlen, STRLCPY, STRNCMP

// First language that is loaded, start of the linked list of loaded
// languages.
slang_T *first_lang = NULL;

// file used for "zG" and "zW"
char_u *int_wordlist = NULL;

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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "spell.c.generated.h"
#endif

// mode values for find_word
#define FIND_FOLDWORD       0   // find word case-folded
#define FIND_KEEPWORD       1   // find keep-case word
#define FIND_PREFIX         2   // find word after prefix
#define FIND_COMPOUND       3   // find case-folded compound word
#define FIND_KEEPCOMPOUND   4   // find keep-case compound word

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
size_t spell_check(win_T *wp, const char *ptr, hlf_T *attrp, int *capcol, bool docount)
{
  size_t wrongcaplen = 0;
  const char *end = ptr;
  bool count_word = docount;
  bool use_camel_case = (wp->w_s->b_p_spo_flags & SPO_CAMEL) != 0;
  bool camel_case = false;

  // A word never starts at a space or a control character. Return quickly
  // then, skipping over the character.
  if (*ptr <= ' ') {
    return 1;
  }

  // Return here when loading language files failed.
  if (GA_EMPTY(&wp->w_s->b_langp)) {
    return 1;
  }

  // Find the normal end of the word (until the next non-word character).
  if (spell_iswordp(end, wp)) {
    bool this_upper = false;  // init for gcc

    if (use_camel_case) {
      int c = utf_ptr2char(end);
      this_upper = SPELL_ISUPPER(c);
    }

    do {
      MB_PTR_ADV(end);
      if (use_camel_case) {
        const bool prev_upper = this_upper;
        int c = utf_ptr2char(end);
        this_upper = SPELL_ISUPPER(c);
        camel_case = !prev_upper && this_upper;
      }
    } while (*end != NUL && spell_iswordp(end, wp)
             && !camel_case);

    if (capcol != NULL && *capcol == 0 && wp->w_s->b_cap_prog != NULL) {
      // Check word starting with capital letter.
      int c = utf_ptr2char((char *)ptr);
      if (!SPELL_ISUPPER(c)) {
        wrongcaplen = (size_t)(end - ptr);
      }
    }
  }
  if (capcol != NULL) {
    *capcol = -1;
  }

  // TODO(vigoux): I think that this is not necessary anymore, and we only check the exact word
  // length
  // if (camel_case && mi.mi_fwordlen > 0) {
  //   // introduce a fake word end space into the folded word.
  //   mi.mi_fword[mi.mi_fwordlen - 1] = ' ';
  // }

  // The word is bad unless we recognize it.
  enum {
    SP_BANNED,
    SP_RARE,
    SP_OK,
    SP_LOCAL,
    SP_BAD,
  } result = SP_BAD;

  // Loop over the languages specified in 'spelllang'.
  // We check them all, because a word may be matched longer in another
  // language.
  if (end != ptr) {
    for (int lpi = 0; lpi < wp->w_s->b_langp.ga_len; lpi++) {
      langp_T *lp = LANGP_ENTRY(wp->w_s->b_langp, lpi);

      // If reloading fails the language is still in the list but everything
      // has been cleared.
      if (lp->lp_slang->sl_hunspell != NULL) {
        size_t wlen = (size_t)(end - ptr);
        int spell_flags = 0;
        if (hunspell_spell_flags(lp->lp_slang->sl_hunspell, (char *)ptr,
                                 wlen, &spell_flags)) {
          result =
            (spell_flags & HSPELL_FORBIDDEN) ? SP_BANNED :
            (spell_flags & HSPELL_WARN) ? SP_RARE : SP_OK;
        } else {
          result = SP_BAD;
        }

        if (result == SP_OK && count_word) {
          count_common_word(lp->lp_slang, (char_u *)ptr, (int)wlen, 1);
          count_word = false;
        }
      }
    }
  }

  if (result != SP_OK) {
    if (!spell_iswordp_nmw(ptr, wp)) {
      // When we are at a non-word character there is no error, just
      // skip over the character (try looking for a word after it).
      if (capcol != NULL && wp->w_s->b_cap_prog != NULL) {
        regmatch_T regmatch;

        // Check for end of sentence.
        regmatch.regprog = wp->w_s->b_cap_prog;
        regmatch.rm_ic = false;
        int r = vim_regexec(&regmatch, (char *)ptr, 0);
        wp->w_s->b_cap_prog = regmatch.regprog;
        if (r) {
          *capcol = (int)(regmatch.endp[0] - (char *)ptr);
        }
      }

      return (size_t)(utfc_ptr2len((char *)ptr));
    } else if (end == ptr) {
      // Always include at least one character.  Required for when there
      // is a mixup in "midword".
      MB_PTR_ADV(end);
    }

    if (result == SP_BAD || result == SP_BANNED) {
      *attrp = HLF_SPB;
    } else if (result == SP_RARE) {
      *attrp = HLF_SPR;
    } else {
      *attrp = HLF_SPL;
    }
  }

  if (wrongcaplen > 0 && (result == SP_OK || result == SP_RARE) && spell_iswordp_nmw(ptr, wp)) {
    // Report SpellCap only when the word isn't badly spelled and actually starts with a letter.
    *attrp = HLF_SPC;
    return wrongcaplen;
  }

  return (size_t)(end - ptr);
}

/// Returns true if there is a match between the word ptr[wlen] and
/// CHECKCOMPOUNDPATTERN rules, assuming that we will concatenate with another
/// word.
/// A match means that the first part of CHECKCOMPOUNDPATTERN matches at the
/// end of ptr[wlen] and the second part matches after it.
///
/// @param gap  &sl_comppat
bool match_checkcompoundpattern(char_u *ptr, int wlen, garray_T *gap)
{
  for (int i = 0; i + 1 < gap->ga_len; i += 2) {
    char_u *p = ((char_u **)gap->ga_data)[i + 1];
    if (STRNCMP(ptr + wlen, p, STRLEN(p)) == 0) {
      // Second part matches at start of following compound word, now
      // check if first part matches at end of previous word.
      p = ((char_u **)gap->ga_data)[i];
      int len = (int)STRLEN(p);
      if (len <= wlen && STRNCMP(ptr + wlen - len, p, len) == 0) {
        return true;
      }
    }
  }
  return false;
}

// Returns true if "flags" is a valid sequence of compound flags and "word"
// does not have too many syllables.
bool can_compound(slang_T *slang, const char_u *word, const char_u *flags)
  FUNC_ATTR_NONNULL_ALL
{
  char_u uflags[MAXWLEN * 2] = { 0 };

  if (slang->sl_compprog == NULL) {
    return false;
  }
  // Need to convert the single byte flags to utf8 characters.
  char_u *p = uflags;
  for (int i = 0; flags[i] != NUL; i++) {
    p += utf_char2bytes(flags[i], (char *)p);
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
    return (int)STRLEN(flags) < slang->sl_compmax;
  }
  return true;
}

// Returns true if the compound flags in compflags[] match the start of any
// compound rule.  This is used to stop trying a compound if the flags
// collected so far can't possibly match any compound rule.
// Caller must check that slang->sl_comprules is not NULL.
bool match_compoundrule(slang_T *slang, char_u *compflags)
{
  // loop over all the COMPOUNDRULE entries
  for (char_u *p = slang->sl_comprules; *p != NUL; p++) {
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
          if (*p++ == c) {
            match = true;
          }
        }
        if (!match) {
          break;            // none matches
        }
      } else if (*p != c) {
        break;          // flag of word doesn't match flag in pattern
      }
      p++;
    }

    // Skip to the next "/", where the next pattern starts.
    p = (char_u *)vim_strchr((char *)p, '/');
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
int valid_word_prefix(int totprefcnt, int arridx, int flags, char_u *word, slang_T *slang,
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

// Returns true if spell checking is not enabled.
bool no_spell_checking(win_T *wp)
{
  if (!wp->w_p_spell || *wp->w_s->b_p_spl == NUL
      || GA_EMPTY(&wp->w_s->b_langp)) {
    emsg(_(e_no_spell));
    return true;
  }
  return false;
}

static void decor_spell_nav_start(win_T *wp)
{
  decor_state = (DecorState){ 0 };
  decor_redraw_reset(wp->w_buffer, &decor_state);
}

static bool decor_spell_nav_col(win_T *wp, linenr_T lnum, linenr_T *decor_lnum, int col,
                                char **decor_error)
{
  if (*decor_lnum != lnum) {
    decor_providers_invoke_spell(wp, lnum - 1, col, lnum - 1, -1, decor_error);
    decor_redraw_line(wp->w_buffer, lnum - 1, &decor_state);
    *decor_lnum = lnum;
  }
  decor_redraw_col(wp->w_buffer, col, col, false, &decor_state);
  return decor_state.spell;
}

/// Moves to the next spell error.
/// "curline" is false for "[s", "]s", "[S" and "]S".
/// "curline" is true to find word under/after cursor in the same line.
/// For Insert mode completion "dir" is BACKWARD and "curline" is true: move
/// to after badly spelled word before the cursor.
///
/// @param dir  FORWARD or BACKWARD
/// @param allwords  true for "[s"/"]s", false for "[S"/"]S"
/// @param attrp  return: attributes of bad word or NULL (only when "dir" is FORWARD)
///
/// @return  0 if not found, length of the badly spelled word otherwise.
size_t spell_move_to(win_T *wp, int dir, bool allwords, bool curline, hlf_T *attrp)
{
  pos_T found_pos;
  size_t found_len = 0;
  hlf_T attr = HLF_COUNT;
  size_t len;
  int has_syntax = syntax_present(wp);
  colnr_T col;
  char_u *buf = NULL;
  size_t buflen = 0;
  int skip = 0;
  colnr_T capcol = -1;
  bool found_one = false;
  bool wrapped = false;

  if (no_spell_checking(wp)) {
    return 0;
  }

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

  char *decor_error = NULL;
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
    char_u *line = (char_u *)ml_get_buf(wp->w_buffer, lnum, false);

    len = STRLEN(line);
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
      capcol = (colnr_T)getwhitecols((char *)line);
    } else if (curline && wp == curwin) {
      // For spellbadword(): check if first word needs a capital.
      col = (colnr_T)getwhitecols((char *)line);
      if (check_need_cap(lnum, col)) {
        capcol = col;
      }

      // Need to get the line again, may have looked at the previous
      // one.
      line = (char_u *)ml_get_buf(wp->w_buffer, lnum, false);
    }

    // Copy the line into "buf" and append the start of the next line if
    // possible.  Note: this ml_get_buf() may make "line" invalid, check
    // for empty line first.
    bool empty_line = *skipwhite((const char *)line) == NUL;
    STRCPY(buf, line);
    if (lnum < wp->w_buffer->b_ml.ml_line_count) {
      spell_cat_line(buf + STRLEN(buf),
                     (char_u *)ml_get_buf(wp->w_buffer, lnum + 1, false),
                     MAXWLEN);
    }
    char_u *p = buf + skip;
    char_u *endp = buf + len;
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
      len = spell_check(wp, (char *)p, &attr, &capcol, false);

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
            col = (colnr_T)(p - buf);

            bool can_spell = decor_spell_nav_col(wp, lnum, &decor_lnum, col, &decor_error);

            if (!can_spell) {
              if (has_syntax) {
                (void)syn_get_id(wp, lnum, col, false, &can_spell, false);
              } else {
                can_spell = (wp->w_s->b_p_spo_flags & SPO_NPBUFFER) == 0;
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
  xfree(decor_error);
  decor_state = saved_decor_start;
  xfree(buf);
  return ret;
}

// For spell checking: concatenate the start of the following line "line" into
// "buf", blanking-out special characters.  Copy less than "maxlen" bytes.
// Keep the blanks at the start of the next line, this is used in win_line()
// to skip those bytes if the word was OK.
void spell_cat_line(char_u *buf, char_u *line, int maxlen)
{
  char_u *p = (char_u *)skipwhite((char *)line);
  while (vim_strchr("*#/\"\t", *p) != NULL) {
    p = (char_u *)skipwhite((char *)p + 1);
  }

  if (*p != NUL) {
    // Only worth concatenating if there is something else than spaces to
    // concatenate.
    int n = (int)(p - line) + 1;
    if (n < maxlen - 1) {
      memset(buf, ' ', (size_t)n);
      STRLCPY(buf + n, p, maxlen - n);
    }
  }
}

static void spell_hunspell_cb(char *path, void *ud)
{
  spelload_T *sl = (spelload_T *)ud;

  char *aff_path = xstrdup(path);
  STRCPY(aff_path + STRLEN(path) - 3, "aff");

  hunspell_T *h = hunspell_create(aff_path, path);
  if (h != NULL) {
    sl->sl_slang = slang_alloc((char *)sl->sl_lang);
    sl->sl_slang->sl_hunspell = h;
    sl->sl_slang->sl_fname = xstrdup(path);
  }

  xfree(aff_path);
}

static void spell_hunspell_add_cb(char *path, void *ud)
{
  spelload_T *sl = (spelload_T *)ud;
  if (sl->sl_slang->sl_hunspell != NULL) {
    DLOG("Adding %s", path);
    hunspell_add_dic(sl->sl_slang->sl_hunspell, path);
  }
}

// Load word list(s) for "lang" from Vim spell file(s).
// "lang" must be the language without the region: e.g., "en".
static slang_T *spell_load_lang(win_T *wp, char *lang)
{
  char fname_enc[85];
  int r;
  spelload_T sl;

  // Copy the language name to pass it to spell_load_cb() as a cookie.
  // It's truncated when an error is detected.
  STRCPY(sl.sl_lang, lang);
  sl.sl_slang = NULL;
  sl.sl_nobreak = false;

  // We may retry when no spell file is found for the language, an
  // autocommand may load it then.
  for (int round = 1; round <= 2; round++) {
    // Find the first spell file for "lang" in 'runtimepath' and load it.
    vim_snprintf((char *)fname_enc, sizeof(fname_enc) - 5, "spell/%s.dic", lang);
    r = do_in_runtimepath((char *)fname_enc, 0, spell_hunspell_cb, &sl);

    if (r == FAIL && *sl.sl_lang != NUL && round == 1
        && apply_autocmds(EVENT_SPELLFILEMISSING, (char *)lang,
                          curbuf->b_fname, false, curbuf)) {
      continue;
    }
    break;
  }

  if (r == FAIL) {
    if (starting) {
      // Prompt the user at VimEnter if spell files are missing. #3027
      // Plugins aren't loaded yet, so spellfile.vim cannot handle this case.
      // TODO(vigoux): convert to lua
      char autocmd_buf[512] = { 0 };
      snprintf(autocmd_buf, sizeof(autocmd_buf),
               "autocmd VimEnter * call spellfile#LoadFile('%s')|set spell",
               lang);
      do_cmdline_cmd(autocmd_buf);
    } else {
      smsg(_("Warning: Cannot find word list \"%s.dic\""), lang);
    }
  } else if (sl.sl_slang != NULL) {
    // At least one file was loaded, now load ALL the additions.
    // TODO(vigoux): probably not right and we'll have to load the .add files
    STRCPY(fname_enc + STRLEN(fname_enc) - 3, "add");
    do_in_runtimepath((char *)fname_enc, DIP_ALL, spell_hunspell_add_cb, &sl);
    sl.sl_slang->sl_next = first_lang;
    first_lang = sl.sl_slang;
  }

  return sl.sl_slang;
}

// Return the encoding used for spell checking: Use 'encoding', except that we
// use "latin1" for "latin9".  And limit to 60 characters (just in case).
char_u *spell_enc(void)
{
  if (STRLEN(p_enc) < 60 && strcmp(p_enc, "iso-8859-15") != 0) {
    return (char_u *)p_enc;
  }
  return (char_u *)"latin1";
}

// Get the name of the .spl file for the internal wordlist into
// "fname[MAXPATHL]".
static void int_wordlist_spl(char_u *fname)
{
  vim_snprintf((char *)fname, MAXPATHL, SPL_FNAME_TMPL,
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

  hunspell_destroy(lp->sl_hunspell);
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

/// Add a word to the hashtable of common words.
/// If it's already there then the counter is increased.
///
/// @param[in]  lp
/// @param[in]  word  added to common words hashtable
/// @param[in]  len  length of word or -1 for NUL terminated
/// @param[in]  count  1 to count once, 10 to init
void count_common_word(slang_T *lp, char_u *word, int len, uint8_t count)
{
  char_u buf[MAXWLEN];
  char_u *p;

  if (len == -1) {
    p = word;
  } else if (len >= MAXWLEN) {
    return;
  } else {
    STRLCPY(buf, word, len + 1);
    p = buf;
  }

  wordcount_T *wc;
  hash_T hash = hash_hash(p);
  const size_t p_len = STRLEN(p);
  hashitem_T *hi = hash_lookup(&lp->sl_wordcount, (const char *)p, p_len, hash);
  if (HASHITEM_EMPTY(hi)) {
    wc = xmalloc(sizeof(wordcount_T) + p_len);
    memcpy(wc->wc_word, p, p_len + 1);
    wc->wc_count = count;
    hash_add_item(&lp->sl_wordcount, hi, wc->wc_word, hash);
  } else {
    wc = HI2WC(hi);
    wc->wc_count = (uint16_t)(wc->wc_count + count);
    if (wc->wc_count < count) {    // check for overflow
      wc->wc_count = MAXWORDCOUNT;
    }
  }
}

// Returns true if byte "n" appears in "str".
// Like strchr() but independent of locale.
bool byte_in_str(char_u *str, int n)
{
  for (char_u *p = str; *p != NUL; p++) {
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
  char_u *p = (char_u *)vim_strchr((char *)slang->sl_syllable, '/');
  while (p != NULL) {
    *p++ = NUL;
    if (*p == NUL) {        // trailing slash
      break;
    }
    char_u *s = p;
    p = (char_u *)vim_strchr((char *)p, '/');
    int l;
    if (p == NULL) {
      l = (int)STRLEN(s);
    } else {
      l = (int)(p - s);
    }
    if (l >= SY_MAXLEN) {
      return SP_FORMERROR;
    }

    syl_item_T *syl = GA_APPEND_VIA_PTR(syl_item_T, &slang->sl_syl_items);
    STRLCPY(syl->sy_chars, s, l + 1);
    syl->sy_len = l;
  }
  return OK;
}

// Count the number of syllables in "word".
// When "word" contains spaces the syllables after the last space are counted.
// Returns zero if syllables are not defines.
static int count_syllables(slang_T *slang, const char_u *word)
  FUNC_ATTR_NONNULL_ALL
{
  int cnt = 0;
  bool skip = false;
  int len;

  if (slang->sl_syllable == NULL) {
    return 0;
  }

  for (const char_u *p = word; *p != NUL; p += len) {
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
          && STRNCMP(p, syl->sy_chars, syl->sy_len) == 0) {
        len = syl->sy_len;
      }
    }
    if (len != 0) {     // found a match, count syllable
      cnt++;
      skip = false;
    } else {
      // No recognized syllable item, at least a syllable char then?
      int c = utf_ptr2char((char *)p);
      len = utfc_ptr2len((char *)p);
      if (vim_strchr((char *)slang->sl_syllable, c) == NULL) {
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
char *did_set_spelllang(win_T *wp)
{
  garray_T ga;
  char *splp;
  char *region;
  int region_mask;
  slang_T *slang;
  int c;
  char lang[MAXWLEN + 1];
  char spf_name[MAXPATHL];
  int len;
  char *p;
  int round;
  char *spf;
  char *use_region = NULL;
  bool dont_use_region = false;
  bool nobreak = false;
  static bool recursive = false;
  char *ret_msg = NULL;
  char *spl_copy;

  bufref_T bufref;
  set_bufref(&bufref, wp->w_buffer);

  // We don't want to do this recursively.  May happen when a language is
  // not available and the SpellFileMissing autocommand opens a new buffer
  // in which 'spell' is set.
  if (recursive) {
    return NULL;
  }
  recursive = true;

  ga_init(&ga, sizeof(langp_T), 2);
  clear_midword(wp);

  // Make a copy of 'spelllang', the SpellFileMissing autocommands may change
  // it under our fingers.
  spl_copy = xstrdup(wp->w_s->b_p_spl);

  wp->w_s->b_cjk = 0;

  // Loop over comma separated language names.
  for (splp = spl_copy; *splp != NUL;) {
    // Get one language name.
    copy_option_part(&splp, (char *)lang, MAXWLEN, ",");
    region = NULL;
    len = (int)strlen(lang);

    if (!valid_spelllang((char *)lang)) {
      continue;
    }

    if (strcmp(lang, "cjk") == 0) {
      wp->w_s->b_cjk = 1;
      continue;
    }

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
      (void)spell_load_lang(wp, lang);
      // SpellFileMissing autocommands may do anything, including
      // destroying the buffer we are using...
      if (!bufref_valid(&bufref)) {
        ret_msg = N_("E797: SpellFileMissing autocommand deleted buffer");
        goto theend;
      }
    }

    // Loop over the languages, there can be several files for "lang".
    for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
      if (STRICMP(lang, slang->sl_name) == 0) {
        region_mask = REGION_ALL;
        if (region != NULL) {
          // find region in sl_regions
          c = find_region(slang->sl_regions, (char_u *)region);
          if (c == REGION_ALL) {
            if (slang->sl_add) {
              if (*slang->sl_regions != NUL) {
                // This addition file is for other regions.
                region_mask = 0;
              }
            } else {
              // This is probably an error.  Give a warning and
              // accept the words anyway.
              smsg(_("Warning: region %s not supported"),
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
  spf = curwin->w_s->b_p_spf;
  for (round = 0; round == 0 || *spf != NUL; round++) {
    if (round == 0) {
      // Internal wordlist, if there is one.
      if (int_wordlist == NULL) {
        continue;
      }
      int_wordlist_spl((char_u *)spf_name);
    } else {
      // One entry in 'spellfile'.
      copy_option_part(&spf, (char *)spf_name, MAXPATHL - 5, ",");
      STRCAT(spf_name, ".spl");

      // If it was already found above then skip it.
      for (c = 0; c < ga.ga_len; c++) {
        p = LANGP_ENTRY(ga, c)->lp_slang->sl_fname;
        if (p != NULL
            && path_full_compare((char *)spf_name, p, false, true) == kEqualFiles) {
          break;
        }
      }
      if (c < ga.ga_len) {
        continue;
      }
    }

    // Check if it was loaded already.
    for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
      if (path_full_compare((char *)spf_name, slang->sl_fname, false, true)
          == kEqualFiles) {
        break;
      }
    }
    // Not loaded, try loading it now.  The language name includes the
    // region name, the region is ignored otherwise.
    // Ignore int_wordlist
    if (slang == NULL && round != 0) {
      STRLCPY(lang, path_tail((char *)spf_name), MAXWLEN + 1);
      p = vim_strchr((char *)lang, '.');
      if (p != NULL) {
        *p = NUL;             // truncate at ".encoding.add"
      }
      slang = spell_load_lang(wp, (char *)lang);

      // If one of the languages has NOBREAK we assume the addition
      // files also have this.
      if (slang != NULL && nobreak) {
        slang->sl_nobreak = true;
      }
    }
    if (slang != NULL) {
      region_mask = REGION_ALL;
      if (use_region != NULL && !dont_use_region) {
        // find region in sl_regions
        c = find_region(slang->sl_regions, (char_u *)use_region);
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
        p_->lp_region = region_mask;

        use_midword(slang, wp);
      }
    }
  }

  // Everything is fine, store the new b_langp value.
  ga_clear(&wp->w_s->b_langp);
  wp->w_s->b_langp = ga;

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

  for (char *p = (char *)lp->sl_midword; *p != NUL;) {
    const int c = utf_ptr2char(p);
    const int l = utfc_ptr2len(p);
    if (c < 256 && l <= 2) {
      wp->w_s->b_spell_ismw[c] = true;
    } else if (wp->w_s->b_spell_ismw_mb == NULL) {
      // First multi-byte char in "b_spell_ismw_mb".
      wp->w_s->b_spell_ismw_mb = xstrnsave(p, (size_t)l);
    } else {
      // Append multi-byte chars to "b_spell_ismw_mb".
      const int n = (int)strlen(wp->w_s->b_spell_ismw_mb);
      char *bp = xstrnsave(wp->w_s->b_spell_ismw_mb, (size_t)n + (size_t)l);
      xfree(wp->w_s->b_spell_ismw_mb);
      wp->w_s->b_spell_ismw_mb = bp;
      STRLCPY(bp + n, p, l + 1);
    }
    p += l;
  }
}

// Find the region "region[2]" in "rp" (points to "sl_regions").
// Each region is simply stored as the two characters of its name.
// Returns the index if found (first is 0), REGION_ALL if not found.
static int find_region(char_u *rp, char_u *region)
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
int captype(char *word, char *end)
  FUNC_ATTR_NONNULL_ARG(1)
{
  char *p;

  // find first letter
  for (p = word; !spell_iswordp_nmw(p, curwin); MB_PTR_ADV(p)) {
    if (end == NULL ? *p == NUL : p >= end) {
      return 0;             // only non-word characters, illegal word
    }
  }
  int c = mb_ptr2char_adv((const char_u **)&p);
  bool allcap;
  bool firstcap = allcap = SPELL_ISUPPER(c);
  bool past_second = false;              // past second word char

  // Need to check all letters to find a word with mixed upper/lower.
  // But a word with an upper char only at start is a ONECAP.
  for (; end == NULL ? *p != NUL : p < end; MB_PTR_ADV(p)) {
    if (spell_iswordp_nmw(p, curwin)) {
      c = utf_ptr2char((char *)p);
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
  if (int_wordlist != NULL) {
    char_u fname[MAXPATHL] = { 0 };
    os_remove((char *)int_wordlist);
    int_wordlist_spl(fname);
    os_remove((char *)fname);
    XFREE_CLEAR(int_wordlist);
  }
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
        (void)did_set_spelllang(wp);
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
  if (buf != NULL) {
    ml_close(buf, true);
    xfree(buf);
  }
}

// Init the chartab used for spelling for ASCII.
void clear_spell_chartab(spelltab_T *sp)
{
  // Init everything to false (zero).
  CLEAR_FIELD(sp->st_isw);
  CLEAR_FIELD(sp->st_isu);

  for (int i = 0; i < 256; i++) {
    sp->st_fold[i] = (char_u)i;
    sp->st_upper[i] = (char_u)i;
  }

  // We include digits. A word shouldn't start with a digit, but handling
  // that is done separately.
  for (int i = '0'; i <= '9'; i++) {
    sp->st_isw[i] = true;
  }
  for (int i = 'A'; i <= 'Z'; i++) {
    sp->st_isw[i] = true;
    sp->st_isu[i] = true;
    sp->st_fold[i] = (char_u)(i + 0x20);
  }
  for (int i = 'a'; i <= 'z'; i++) {
    sp->st_isw[i] = true;
    sp->st_upper[i] = (char_u)(i - 0x20);
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
    spelltab.st_fold[i] = (f < 256) ? (char_u)f : (char_u)i;
    spelltab.st_upper[i] = (u < 256) ? (char_u)u : (char_u)i;
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
  int c = utf_ptr2char(p);

  for (int lpi = 0; lpi < wp->w_s->b_langp.ga_len; lpi++) {
    langp_T *lp = LANGP_ENTRY(wp->w_s->b_langp, lpi);

    if (lp->lp_slang->sl_hunspell != NULL) {
      // TODO(vigoux): correctly handle multibyte characters here
      if (hunspell_is_wordchar(lp->lp_slang->sl_hunspell, p)) {
        return true;
      }
    }
  }
  // TODO(vigoux): that's certainly not right, use uft_class functions
  return mb_isalpha(c);
}

// Returns true if "p" points to a word character.
// Unlike spell_iswordp() this doesn't check for "midword" characters.
bool spell_iswordp_nmw(const char *p, win_T *wp)
{
  int c = utf_ptr2char(p);
  // TODO: use utf_class
  return mb_isalpha(c);
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
int spell_casefold(const win_T *wp, char *str, int len, char *buf, int buflen)
  FUNC_ATTR_NONNULL_ALL
{
  if (len >= buflen) {
    buf[0] = NUL;
    return FAIL;                // result will not fit
  }

  int outi = 0;

  // Fold one character at a time.
  for (char *p = str; p < str + len;) {
    if (outi + MB_MAXBYTES > buflen) {
      buf[outi] = NUL;
      return FAIL;
    }
    int c = mb_cptr2char_adv((const char_u **)&p);

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
// capital.  This uses 'spellcapcheck' of the current buffer.
bool check_need_cap(linenr_T lnum, colnr_T col)
{
  bool need_cap = false;

  if (curwin->w_s->b_cap_prog == NULL) {
    return false;
  }

  char *line = get_cursor_line_ptr();
  char *line_copy = NULL;
  colnr_T endcol = 0;
  if (getwhitecols(line) >= (int)col) {
    // At start of line, check if previous line is empty or sentence
    // ends there.
    if (lnum == 1) {
      need_cap = true;
    } else {
      line = ml_get(lnum - 1);
      if (*skipwhite(line) == NUL) {
        need_cap = true;
      } else {
        // Append a space in place of the line break.
        line_copy = concat_str(line, " ");
        line = line_copy;
        endcol = (colnr_T)STRLEN(line);
      }
    }
  } else {
    endcol = col;
  }

  if (endcol > 0) {
    // Check if sentence ends before the bad word.
    regmatch_T regmatch = {
      .regprog = curwin->w_s->b_cap_prog,
      .rm_ic = false
    };
    char *p = line + endcol;
    for (;;) {
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
  bool save_ws = p_ws;
  linenr_T prev_lnum = 0;

  if (repl_from == NULL || repl_to == NULL) {
    emsg(_("E752: No previous spell replacement"));
    return;
  }
  int addlen = (int)(strlen(repl_to) - strlen(repl_from));

  size_t frompatlen = strlen(repl_from) + 7;
  char_u *frompat = xmalloc(frompatlen);
  snprintf((char *)frompat, frompatlen, "\\V\\<%s\\>", repl_from);
  p_ws = false;

  sub_nsubs = 0;
  sub_nlines = 0;
  curwin->w_cursor.lnum = 0;
  while (!got_int) {
    if (do_search(NULL, '/', '/', frompat, 1L, SEARCH_KEEP, NULL) == 0
        || u_save_cursor() == FAIL) {
      break;
    }

    // Only replace when the right word isn't there yet.  This happens
    // when changing "etc" to "etc.".
    char_u *line = (char_u *)get_cursor_line_ptr();
    if (addlen <= 0 || STRNCMP(line + curwin->w_cursor.col,
                               repl_to, strlen(repl_to)) != 0) {
      char_u *p = xmalloc(STRLEN(line) + (size_t)addlen + 1);
      memmove(p, line, (size_t)curwin->w_cursor.col);
      STRCPY(p + curwin->w_cursor.col, repl_to);
      STRCAT(p, line + curwin->w_cursor.col + strlen(repl_from));
      ml_replace(curwin->w_cursor.lnum, (char *)p, false);
      changed_bytes(curwin->w_cursor.lnum, curwin->w_cursor.col);

      if (curwin->w_cursor.lnum != prev_lnum) {
        sub_nlines++;
        prev_lnum = curwin->w_cursor.lnum;
      }
      sub_nsubs++;
    }
    curwin->w_cursor.col += (colnr_T)strlen(repl_to);
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
void onecap_copy(char_u *word, char_u *wcopy, bool upper)
{
  char_u *p = word;
  int c = mb_cptr2char_adv((const char_u **)&p);
  if (upper) {
    c = SPELL_TOUPPER(c);
  } else {
    c = SPELL_TOFOLD(c);
  }
  int l = utf_char2bytes(c, (char *)wcopy);
  STRLCPY(wcopy + l, p, MAXWLEN - l);
}

// Make a copy of "word" with all the letters upper cased into
// "wcopy[MAXWLEN]".  The result is NUL terminated.
void allcap_copy(char_u *word, char_u *wcopy)
{
  char_u *d = wcopy;
  for (char_u *s = word; *s != NUL;) {
    int c = mb_cptr2char_adv((const char_u **)&s);

    if (c == 0xdf) {
      c = 'S';
      if (d - wcopy >= MAXWLEN - 1) {
        break;
      }
      *d++ = (char_u)c;
    } else {
      c = SPELL_TOUPPER(c);
    }

    if (d - wcopy >= MAXWLEN - MB_MAXBYTES) {
      break;
    }
    d += utf_char2bytes(c, (char *)d);
  }
  *d = NUL;
}

// Case-folding may change the number of bytes: Count nr of chars in
// fword[flen] and return the byte length of that many chars in "word".
int nofold_len(char_u *fword, int flen, char_u *word)
{
  char_u *p;
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
void make_case_word(char_u *fword, char_u *cword, int flags)
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
      (void)spell_casefold(curwin, inword, (int)STRLEN(inword), fword, MAXWLEN);
      word = fword;
    }

    spell_soundfold_wsal(slang, word, res);
  }
}

// Perform sound folding of "inword" into "res" according to SOFOFROM and
// SOFOTO lines.
static void spell_soundfold_sofo(slang_T *slang, char_u *inword, char_u *res)
{
  int ri = 0;

  int prevc = 0;

  // The sl_sal_first[] table contains the translation for chars up to
  // 255, sl_sal the rest.
  for (char_u *s = inword; *s != NUL;) {
    int c = mb_cptr2char_adv((const char_u **)&s);
    if (utf_class(c) == 0) {
      c = ' ';
    } else if (c < 256) {
      c = slang->sl_sal_first[c];
    } else {
      int *ip = ((int **)slang->sl_sal.ga_data)[c & 0xff];
      if (ip == NULL) {               // empty list, can't match
        c = NUL;
      } else {
        for (;;) {                   // find "c" in the list
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
      ri += utf_char2bytes(c, (char *)res + ri);
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
static void spell_soundfold_wsal(slang_T *slang, char_u *inword, char_u *res)
{
  salitem_T *smp = (salitem_T *)slang->sl_sal.ga_data;
  int word[MAXWLEN] = { 0 };
  int wres[MAXWLEN] = { 0 };
  int *ws;
  int *pf;
  int j, z;
  int reslen;
  int k = 0;
  int z0;
  int k0;
  int n0;
  int pri;
  int p0 = -333;
  int c0;
  bool did_white = false;

  // Convert the multi-byte string to a wide-character string.
  // Remove accents, if wanted.  We actually remove all non-word characters.
  // But keep white space.
  int wordlen = 0;
  for (const char_u *s = inword; *s != NUL;) {
    const char_u *t = s;
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

  int c;
  // This algorithm comes from Aspell phonet.cpp.
  // Converted from C++ to C.  Added support for multi-byte chars.
  // Changed to keep spaces.
  int i = reslen = z = 0;
  while ((c = word[i]) != NUL) {
    // Start with the first rule that has the character in the word.
    int n = slang->sl_sal_first[c & 0xff];
    z0 = 0;

    if (n >= 0) {
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
        char_u *s = smp[n].sm_rules;
        pri = 5;            // default priority

        p0 = *s;
        k0 = k;
        while (*s == '-' && k > 1) {
          k--;
          s++;
        }
        if (*s == '<') {
          s++;
        }
        if (ascii_isdigit(*s)) {
          // determine priority
          pri = *s - '0';
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
          c0 = word[i + k - 1];
          n0 = slang->sl_sal_first[c0 & 0xff];

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
                p0 = *s - '0';
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
          p0 = (vim_strchr((char *)s, '<') != NULL) ? 1 : 0;
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
            if (strstr((char *)s, "^^") != NULL) {
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
    l += utf_char2bytes(wres[n], (char *)res + l);
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
  if (no_spell_checking(curwin)) {
    return;
  }
  char *spl;
  long dummy;
  (void)get_option_value("spl", &dummy, &spl, OPT_LOCAL);

  // Create a new empty buffer in a new window.
  do_cmdline_cmd("new");

  // enable spelling locally in the new window
  set_option_value_give_err("spell", true, "", OPT_LOCAL);
  set_option_value_give_err("spl",  dummy, spl, OPT_LOCAL);
  xfree(spl);

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
  langp_T *lp;
  slang_T *slang;
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  char word[MAXWLEN];
  int c;
  char *byts;
  idx_T *idxs;
  linenr_T lnum = 0;
  int depth;
  int n;
  int flags;
  char *region_names = NULL;         // region names being used
  bool do_region = true;                    // dump region names and numbers
  char *p;
  int dumpflags = dumpflags_arg;
  int patlen;

  // When ignoring case or when the pattern starts with capital pass this on
  // to dump_word().
  if (pat != NULL) {
    if (ic) {
      dumpflags |= DUMPFLAG_ICASE;
    } else {
      n = captype(pat, NULL);
      if (n == WF_ONECAP) {
        dumpflags |= DUMPFLAG_ONECAP;
      } else if (n == WF_ALLCAP
                 && (int)STRLEN(pat) > utfc_ptr2len(pat)) {
        dumpflags |= DUMPFLAG_ALLCAP;
      }
    }
  }

  // Find out if we can support regions: All languages must support the same
  // regions or none at all.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    p = (char *)lp->lp_slang->sl_regions;
    if (p != 0) {
      if (region_names == NULL) {           // first language with regions
        region_names = p;
      } else if (strcmp(region_names, p) != 0) {
        do_region = false;                  // region names are different
        break;
      }
    }
  }

  if (do_region && region_names != NULL) {
    if (pat == NULL) {
      vim_snprintf((char *)IObuff, IOSIZE, "/regions=%s", region_names);
      ml_append(lnum++, (char *)IObuff, (colnr_T)0, false);
    }
  } else {
    do_region = false;
  }

  // Loop over all files loaded for the entries in 'spelllang'.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (slang->sl_fbyts == NULL) {          // reloading failed
      continue;
    }

    if (pat == NULL) {
      vim_snprintf((char *)IObuff, IOSIZE, "# file: %s", slang->sl_fname);
      ml_append(lnum++, (char *)IObuff, (colnr_T)0, false);
    }

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
      if (round == 1) {
        dumpflags &= ~DUMPFLAG_KEEPCASE;
        byts = (char *)slang->sl_fbyts;
        idxs = slang->sl_fidxs;
      } else {
        dumpflags |= DUMPFLAG_KEEPCASE;
        byts = (char *)slang->sl_kbyts;
        idxs = slang->sl_kidxs;
      }
      if (byts == NULL) {
        continue;                       // array is empty
      }
      depth = 0;
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
          n = arridx[depth] + curi[depth];
          curi[depth]++;
          c = (uint8_t)byts[n];
          if (c == 0 || depth >= MAXWLEN - 1) {
            // End of word or reached maximum length, deal with the
            // word.
            // Don't use keep-case words in the fold-case tree,
            // they will appear in the keep-case tree.
            // Only use the word when the region matches.
            flags = (int)idxs[n];
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
                dump_word(slang, (char_u *)word, (char_u *)pat, dir,
                          dumpflags, flags, lnum);
                if (pat == NULL) {
                  lnum++;
                }
              }

              // Apply the prefix, if there is one.
              if (c != 0) {
                lnum = dump_prefixes(slang, (char_u *)word, (char_u *)pat, dir,
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
                && mb_strnicmp((char *)word, pat, (size_t)depth) != 0) {
              depth--;
            }
          }
        }
      }
    }
  }
}

// Dumps one word: apply case modifications and append a line to the buffer.
// When "lnum" is zero add insert mode completion.
static void dump_word(slang_T *slang, char_u *word, char_u *pat, Direction *dir, int dumpflags,
                      int wordflags, linenr_T lnum)
{
  bool keepcap = false;
  char_u *p;
  char_u cword[MAXWLEN];
  char_u badword[MAXWLEN + 10];
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
  char_u *tw = p;

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
        for (int i = 0; i < 7; i++) {
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
      hashitem_T *hi;

      // Include the word count for ":spelldump!".
      hi = hash_find(&slang->sl_wordcount, (char *)tw);
      if (!HASHITEM_EMPTY(hi)) {
        vim_snprintf((char *)IObuff, IOSIZE, "%s\t%d",
                     tw, HI2WC(hi)->wc_count);
        p = (char_u *)IObuff;
      }
    }

    ml_append(lnum, (char *)p, (colnr_T)0, false);
  } else if (((dumpflags & DUMPFLAG_ICASE)
              ? mb_strnicmp((char *)p, (char *)pat, STRLEN(pat)) == 0
              : STRNCMP(p, pat, STRLEN(pat)) == 0)
             && ins_compl_add_infercase(p, (int)STRLEN(p),
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
static linenr_T dump_prefixes(slang_T *slang, char_u *word, char_u *pat, Direction *dir,
                              int dumpflags, int flags, linenr_T startlnum)
{
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  char_u prefix[MAXWLEN];
  char_u word_up[MAXWLEN];
  bool has_word_up = false;
  linenr_T lnum = startlnum;

  // If the word starts with a lower-case letter make the word with an
  // upper-case letter in word_up[].
  int c = utf_ptr2char((char *)word);
  if (SPELL_TOUPPER(c) != c) {
    onecap_copy(word, word_up, true);
    has_word_up = true;
  }

  char_u *byts = slang->sl_pbyts;
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
            STRLCPY(prefix + depth, word, MAXWLEN - depth);
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
            c = valid_word_prefix(i, n, flags, word_up, slang,
                                  true);
            if (c != 0) {
              STRLCPY(prefix + depth, word_up, MAXWLEN - depth);
              dump_word(slang, prefix, pat, dir, dumpflags,
                        (c & WF_RAREPFX) ? (flags | WF_RARE) : flags, lnum);
              if (lnum != 0) {
                lnum++;
              }
            }
          }
        } else {
          // Normal char, go one level deeper.
          prefix[depth++] = (char_u)c;
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
  char_u *p = start;

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

  char_u *line = (char_u *)get_cursor_line_ptr();
  char_u *p;

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
  spell_expand_need_cap = check_need_cap(curwin->w_cursor.lnum, col);
}

// Get list of spelling suggestions.
// Used for Insert mode completion CTRL-X ?.
// Returns the number of matches.  The matches are in "matchp[]", array of
// allocated strings.
int expand_spelling(linenr_T lnum, char_u *pat, char ***matchp)
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
  for (const char_u *s = (char_u *)val; *s != NUL; s++) {
    if (!vim_isfilec(*s) && *s != ',' && *s != ' ') {
      return false;
    }
  }
  return true;
}

char *did_set_spell_option(bool is_spellfile)
{
  char *errmsg = NULL;

  if (is_spellfile) {
    int l = (int)strlen(curwin->w_s->b_p_spf);
    if (l > 0
        && (l < 4 || strcmp(curwin->w_s->b_p_spf + l - 4, ".add") != 0)) {
      errmsg = e_invarg;
    }
  }

  if (errmsg == NULL) {
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_buffer == curbuf && wp->w_p_spell) {
        errmsg = did_set_spelllang(wp);
        break;
      }
    }
  }

  return errmsg;
}

/// Set curbuf->b_cap_prog to the regexp program for 'spellcapcheck'.
/// Return error message when failed, NULL when OK.
char *compile_cap_prog(synblock_T *synblock)
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
