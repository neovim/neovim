// search.c: code for normal mode searching commands

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cmdhist.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight_defs.h"
#include "nvim/indent_c.h"
#include "nvim/insexpand.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"
#include "nvim/path.h"
#include "nvim/plines.h"
#include "nvim/profile.h"
#include "nvim/regexp.h"
#include "nvim/search.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "search.c.generated.h"
#endif

static const char e_search_hit_top_without_match_for_str[]
  = N_("E384: Search hit TOP without match for: %s");
static const char e_search_hit_bottom_without_match_for_str[]
  = N_("E385: Search hit BOTTOM without match for: %s");

//  This file contains various searching-related routines. These fall into
//  three groups:
//  1. string searches (for /, ?, n, and N)
//  2. character searches within a single line (for f, F, t, T, etc)
//  3. "other" kinds of searches like the '%' command, and 'word' searches.
//
//
//  String searches
//
//  The string search functions are divided into two levels:
//  lowest:  searchit(); uses a pos_T for starting position and found match.
//  Highest: do_search(); uses curwin->w_cursor; calls searchit().
//
//  The last search pattern is remembered for repeating the same search.
//  This pattern is shared between the :g, :s, ? and / commands.
//  This is in search_regcomp().
//
//  The actual string matching is done using a heavily modified version of
//  Henry Spencer's regular expression library.  See regexp.c.
//
//
//
// Two search patterns are remembered: One for the :substitute command and
// one for other searches.  last_idx points to the one that was used the last
// time.

static SearchPattern spats[2] = {
  // Last used search pattern
  [0] = { NULL, 0, true, false, 0, { '/', false, false, 0 }, NULL },
  // Last used substitute pattern
  [1] = { NULL, 0, true, false, 0, { '/', false, false, 0 }, NULL }
};

static int last_idx = 0;        // index in spats[] for RE_LAST

static uint8_t lastc[2] = { NUL, NUL };   // last character searched for
static Direction lastcdir = FORWARD;      // last direction of character search
static bool last_t_cmd = true;            // last search t_cmd
static char lastc_bytes[MAX_SCHAR_SIZE + 1];
static int lastc_bytelen = 1;             // >1 for multi-byte char

// copy of spats[], for keeping the search patterns while executing autocmds
static SearchPattern saved_spats[ARRAY_SIZE(spats)];
static char *saved_mr_pattern = NULL;
static size_t saved_mr_patternlen = 0;
static int saved_spats_last_idx = 0;
static bool saved_spats_no_hlsearch = false;

// allocated copy of pattern used by search_regcomp()
static char *mr_pattern = NULL;
static size_t mr_patternlen = 0;

// Type used by find_pattern_in_path() to remember which included files have
// been searched already.
typedef struct {
  FILE *fp;              // File pointer
  char *name;            // Full name of file
  linenr_T lnum;                // Line we were up to in file
  int matched;                  // Found a match in this file
} SearchedFile;

/// translate search pattern for vim_regcomp()
///
/// pat_save == RE_SEARCH: save pat in spats[RE_SEARCH].pat (normal search cmd)
/// pat_save == RE_SUBST: save pat in spats[RE_SUBST].pat (:substitute command)
/// pat_save == RE_BOTH: save pat in both patterns (:global command)
/// pat_use  == RE_SEARCH: use previous search pattern if "pat" is NULL
/// pat_use  == RE_SUBST: use previous substitute pattern if "pat" is NULL
/// pat_use  == RE_LAST: use last used pattern if "pat" is NULL
/// options & SEARCH_HIS: put search string in history
/// options & SEARCH_KEEP: keep previous search pattern
///
/// @param regmatch  return: pattern and ignore-case flag
///
/// @return          FAIL if failed, OK otherwise.
int search_regcomp(char *pat, size_t patlen, char **used_pat, int pat_save, int pat_use,
                   int options, regmmatch_T *regmatch)
{
  rc_did_emsg = false;
  int magic = magic_isset();

  // If no pattern given, use a previously defined pattern.
  if (pat == NULL || *pat == NUL) {
    int i;
    if (pat_use == RE_LAST) {
      i = last_idx;
    } else {
      i = pat_use;
    }
    if (spats[i].pat == NULL) {         // pattern was never defined
      if (pat_use == RE_SUBST) {
        emsg(_(e_nopresub));
      } else {
        emsg(_(e_noprevre));
      }
      rc_did_emsg = true;
      return FAIL;
    }
    pat = spats[i].pat;
    patlen = spats[i].patlen;
    magic = spats[i].magic;
    no_smartcase = spats[i].no_scs;
  } else if (options & SEARCH_HIS) {      // put new pattern in history
    add_to_history(HIST_SEARCH, pat, patlen, true, NUL);
  }

  if (used_pat) {
    *used_pat = pat;
  }

  xfree(mr_pattern);
  if (curwin->w_p_rl && *curwin->w_p_rlc == 's') {
    mr_pattern = reverse_text(pat);
  } else {
    mr_pattern = xstrnsave(pat, patlen);
  }
  mr_patternlen = patlen;

  // Save the currently used pattern in the appropriate place,
  // unless the pattern should not be remembered.
  if (!(options & SEARCH_KEEP) && (cmdmod.cmod_flags & CMOD_KEEPPATTERNS) == 0) {
    // search or global command
    if (pat_save == RE_SEARCH || pat_save == RE_BOTH) {
      save_re_pat(RE_SEARCH, pat, patlen, magic);
    }
    // substitute or global command
    if (pat_save == RE_SUBST || pat_save == RE_BOTH) {
      save_re_pat(RE_SUBST, pat, patlen, magic);
    }
  }

  regmatch->rmm_ic = ignorecase(pat);
  regmatch->rmm_maxcol = 0;
  regmatch->regprog = vim_regcomp(pat, magic ? RE_MAGIC : 0);
  if (regmatch->regprog == NULL) {
    return FAIL;
  }
  return OK;
}

/// Get search pattern used by search_regcomp().
char *get_search_pat(void)
{
  return mr_pattern;
}

void save_re_pat(int idx, char *pat, size_t patlen, int magic)
{
  if (spats[idx].pat == pat) {
    return;
  }

  free_spat(&spats[idx]);
  spats[idx].pat = xstrnsave(pat, patlen);
  spats[idx].patlen = patlen;
  spats[idx].magic = magic;
  spats[idx].no_scs = no_smartcase;
  spats[idx].timestamp = os_time();
  spats[idx].additional_data = NULL;
  last_idx = idx;
  // If 'hlsearch' set and search pat changed: need redraw.
  if (p_hls) {
    redraw_all_later(UPD_SOME_VALID);
  }
  set_no_hlsearch(false);
}

// Save the search patterns, so they can be restored later.
// Used before/after executing autocommands and user functions.
static int save_level = 0;

void save_search_patterns(void)
{
  if (save_level++ != 0) {
    return;
  }

  for (size_t i = 0; i < ARRAY_SIZE(spats); i++) {
    saved_spats[i] = spats[i];
    if (spats[i].pat != NULL) {
      saved_spats[i].pat = xstrnsave(spats[i].pat, spats[i].patlen);
      saved_spats[i].patlen = spats[i].patlen;
    }
  }
  if (mr_pattern == NULL) {
    saved_mr_pattern = NULL;
    saved_mr_patternlen = 0;
  } else {
    saved_mr_pattern = xstrnsave(mr_pattern, mr_patternlen);
    saved_mr_patternlen = mr_patternlen;
  }
  saved_spats_last_idx = last_idx;
  saved_spats_no_hlsearch = no_hlsearch;
}

void restore_search_patterns(void)
{
  if (--save_level != 0) {
    return;
  }

  for (size_t i = 0; i < ARRAY_SIZE(spats); i++) {
    free_spat(&spats[i]);
    spats[i] = saved_spats[i];
  }
  set_vv_searchforward();
  xfree(mr_pattern);
  mr_pattern = saved_mr_pattern;
  mr_patternlen = saved_mr_patternlen;
  last_idx = saved_spats_last_idx;
  set_no_hlsearch(saved_spats_no_hlsearch);
}

static inline void free_spat(SearchPattern *const spat)
{
  xfree(spat->pat);
  xfree(spat->additional_data);
}

#if defined(EXITFREE)
void free_search_patterns(void)
{
  for (size_t i = 0; i < ARRAY_SIZE(spats); i++) {
    free_spat(&spats[i]);
  }
  CLEAR_FIELD(spats);

  XFREE_CLEAR(mr_pattern);
  mr_patternlen = 0;
}

#endif

// copy of spats[RE_SEARCH], for keeping the search patterns while incremental
// searching
static SearchPattern saved_last_search_spat;
static int did_save_last_search_spat = 0;
static int saved_last_idx = 0;
static bool saved_no_hlsearch = false;
static colnr_T saved_search_match_endcol;
static linenr_T saved_search_match_lines;

/// Save and restore the search pattern for incremental highlight search
/// feature.
///
/// It's similar to but different from save_search_patterns() and
/// restore_search_patterns(), because the search pattern must be restored when
/// cancelling incremental searching even if it's called inside user functions.
void save_last_search_pattern(void)
{
  if (++did_save_last_search_spat != 1) {
    // nested call, nothing to do
    return;
  }

  saved_last_search_spat = spats[RE_SEARCH];
  if (spats[RE_SEARCH].pat != NULL) {
    saved_last_search_spat.pat = xstrnsave(spats[RE_SEARCH].pat, spats[RE_SEARCH].patlen);
    saved_last_search_spat.patlen = spats[RE_SEARCH].patlen;
  }
  saved_last_idx = last_idx;
  saved_no_hlsearch = no_hlsearch;
}

void restore_last_search_pattern(void)
{
  if (--did_save_last_search_spat > 0) {
    // nested call, nothing to do
    return;
  }
  if (did_save_last_search_spat != 0) {
    iemsg("restore_last_search_pattern() called more often than"
          " save_last_search_pattern()");
    return;
  }

  xfree(spats[RE_SEARCH].pat);
  spats[RE_SEARCH] = saved_last_search_spat;
  saved_last_search_spat.pat = NULL;
  saved_last_search_spat.patlen = 0;
  set_vv_searchforward();
  last_idx = saved_last_idx;
  set_no_hlsearch(saved_no_hlsearch);
}

/// Save and restore the incsearch highlighting variables.
/// This is required so that calling searchcount() at does not invalidate the
/// incsearch highlighting.
static void save_incsearch_state(void)
{
  saved_search_match_endcol = search_match_endcol;
  saved_search_match_lines = search_match_lines;
}

static void restore_incsearch_state(void)
{
  search_match_endcol = saved_search_match_endcol;
  search_match_lines = saved_search_match_lines;
}

char *last_search_pattern(void)
{
  return spats[RE_SEARCH].pat;
}

size_t last_search_pattern_len(void)
{
  return spats[RE_SEARCH].patlen;
}

/// Return true when case should be ignored for search pattern "pat".
/// Uses the 'ignorecase' and 'smartcase' options.
int ignorecase(char *pat)
{
  return ignorecase_opt(pat, p_ic, p_scs);
}

/// As ignorecase() put pass the "ic" and "scs" flags.
int ignorecase_opt(char *pat, int ic_in, int scs)
{
  int ic = ic_in;
  if (ic && !no_smartcase && scs
      && !(ctrl_x_mode_not_default()
           && curbuf->b_p_inf)) {
    ic = !pat_has_uppercase(pat);
  }
  no_smartcase = false;

  return ic;
}

/// Returns true if pattern `pat` has an uppercase character.
bool pat_has_uppercase(char *pat)
  FUNC_ATTR_NONNULL_ALL
{
  char *p = pat;
  magic_T magic_val = MAGIC_ON;

  // get the magicness of the pattern
  skip_regexp_ex(pat, NUL, magic_isset(), NULL, NULL, &magic_val);

  while (*p != NUL) {
    const int l = utfc_ptr2len(p);

    if (l > 1) {
      if (mb_isupper(utf_ptr2char(p))) {
        return true;
      }
      p += l;
    } else if (*p == '\\' && magic_val <= MAGIC_ON) {
      if (p[1] == '_' && p[2] != NUL) {  // skip "\_X"
        p += 3;
      } else if (p[1] == '%' && p[2] != NUL) {  // skip "\%X"
        p += 3;
      } else if (p[1] != NUL) {  // skip "\X"
        p += 2;
      } else {
        p += 1;
      }
    } else if ((*p == '%' || *p == '_') && magic_val == MAGIC_ALL) {
      if (p[1] != NUL) {  // skip "_X" and %X
        p += 2;
      } else {
        p++;
      }
    } else if (mb_isupper((uint8_t)(*p))) {
      return true;
    } else {
      p++;
    }
  }
  return false;
}

const char *last_csearch(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return lastc_bytes;
}

int last_csearch_forward(void)
{
  return lastcdir == FORWARD;
}

int last_csearch_until(void)
{
  return last_t_cmd;
}

void set_last_csearch(int c, char *s, int len)
{
  *lastc = (uint8_t)c;
  lastc_bytelen = len;
  if (len) {
    memcpy(lastc_bytes, s, (size_t)len);
  } else {
    CLEAR_FIELD(lastc_bytes);
  }
}

void set_csearch_direction(Direction cdir)
{
  lastcdir = cdir;
}

void set_csearch_until(int t_cmd)
{
  last_t_cmd = t_cmd;
}

char *last_search_pat(void)
{
  return spats[last_idx].pat;
}

// Reset search direction to forward.  For "gd" and "gD" commands.
void reset_search_dir(void)
{
  spats[0].off.dir = '/';
  set_vv_searchforward();
}

// Set the last search pattern.  For ":let @/ =" and ShaDa file.
// Also set the saved search pattern, so that this works in an autocommand.
void set_last_search_pat(const char *s, int idx, int magic, bool setlast)
{
  free_spat(&spats[idx]);
  // An empty string means that nothing should be matched.
  if (*s == NUL) {
    spats[idx].pat = NULL;
    spats[idx].patlen = 0;
  } else {
    spats[idx].patlen = strlen(s);
    spats[idx].pat = xstrnsave(s, spats[idx].patlen);
  }
  spats[idx].timestamp = os_time();
  spats[idx].additional_data = NULL;
  spats[idx].magic = magic;
  spats[idx].no_scs = false;
  spats[idx].off.dir = '/';
  set_vv_searchforward();
  spats[idx].off.line = false;
  spats[idx].off.end = false;
  spats[idx].off.off = 0;
  if (setlast) {
    last_idx = idx;
  }
  if (save_level) {
    free_spat(&saved_spats[idx]);
    saved_spats[idx] = spats[0];
    if (spats[idx].pat == NULL) {
      saved_spats[idx].pat = NULL;
      saved_spats[idx].patlen = 0;
    } else {
      saved_spats[idx].pat = xstrnsave(spats[idx].pat, spats[idx].patlen);
      saved_spats[idx].patlen = spats[idx].patlen;
    }
    saved_spats_last_idx = last_idx;
  }
  // If 'hlsearch' set and search pat changed: need redraw.
  if (p_hls && idx == last_idx && !no_hlsearch) {
    redraw_all_later(UPD_SOME_VALID);
  }
}

// Get a regexp program for the last used search pattern.
// This is used for highlighting all matches in a window.
// Values returned in regmatch->regprog and regmatch->rmm_ic.
void last_pat_prog(regmmatch_T *regmatch)
{
  if (spats[last_idx].pat == NULL) {
    regmatch->regprog = NULL;
    return;
  }
  emsg_off++;           // So it doesn't beep if bad expr
  search_regcomp("", 0, NULL, 0, last_idx, SEARCH_KEEP, regmatch);
  emsg_off--;
}

/// Lowest level search function.
/// Search for 'count'th occurrence of pattern "pat" in direction "dir".
/// Start at position "pos" and return the found position in "pos".
///
/// if (options & SEARCH_MSG) == 0 don't give any messages
/// if (options & SEARCH_MSG) == SEARCH_NFMSG don't give 'notfound' messages
/// if (options & SEARCH_MSG) == SEARCH_MSG give all messages
/// if (options & SEARCH_HIS) put search pattern in history
/// if (options & SEARCH_END) return position at end of match
/// if (options & SEARCH_START) accept match at pos itself
/// if (options & SEARCH_KEEP) keep previous search pattern
/// if (options & SEARCH_FOLD) match only once in a closed fold
/// if (options & SEARCH_PEEK) check for typed char, cancel search
/// if (options & SEARCH_COL) start at pos->col instead of zero
///
/// @param win        window to search in; can be NULL for a buffer without a window!
/// @param end_pos    set to end of the match, unless NULL
/// @param pat_use    which pattern to use when "pat" is empty
/// @param extra_arg  optional extra arguments, can be NULL
///
/// @returns          FAIL (zero) for failure, non-zero for success.
///                   the index of the first matching
///                   subpattern plus one; one if there was none.
int searchit(win_T *win, buf_T *buf, pos_T *pos, pos_T *end_pos, Direction dir, char *pat,
             size_t patlen, int count, int options, int pat_use, searchit_arg_T *extra_arg)
{
  int found;
  linenr_T lnum;                // no init to shut up Apollo cc
  regmmatch_T regmatch;
  char *ptr;
  colnr_T matchcol;
  lpos_T endpos;
  lpos_T matchpos;
  int loop;
  int extra_col;
  int start_char_len;
  bool match_ok;
  int nmatched;
  int submatch = 0;
  bool first_match = true;
  const int called_emsg_before = called_emsg;
  bool break_loop = false;
  linenr_T stop_lnum = 0;  // stop after this line number when != 0
  proftime_T *tm = NULL;   // timeout limit or NULL
  int *timed_out = NULL;   // set when timed out or NULL

  if (extra_arg != NULL) {
    stop_lnum = extra_arg->sa_stop_lnum;
    tm = extra_arg->sa_tm;
    timed_out = &extra_arg->sa_timed_out;
  }

  if (search_regcomp(pat, patlen, NULL, RE_SEARCH, pat_use,
                     (options & (SEARCH_HIS + SEARCH_KEEP)), &regmatch) == FAIL) {
    if ((options & SEARCH_MSG) && !rc_did_emsg) {
      semsg(_("E383: Invalid search string: %s"), mr_pattern);
    }
    return FAIL;
  }

  const bool search_from_match_end = vim_strchr(p_cpo, CPO_SEARCH) != NULL;

  // find the string
  do {  // loop for count
    // When not accepting a match at the start position set "extra_col" to a
    // non-zero value.  Don't do that when starting at MAXCOL, since MAXCOL + 1
    // is zero.
    if (pos->col == MAXCOL) {
      start_char_len = 0;
    } else if (pos->lnum >= 1
               && pos->lnum <= buf->b_ml.ml_line_count
               && pos->col < MAXCOL - 2) {
      // Watch out for the "col" being MAXCOL - 2, used in a closed fold.
      ptr = ml_get_buf(buf, pos->lnum);
      if (ml_get_buf_len(buf, pos->lnum) <= pos->col) {
        start_char_len = 1;
      } else {
        start_char_len = utfc_ptr2len(ptr + pos->col);
      }
    } else {
      start_char_len = 1;
    }
    if (dir == FORWARD) {
      extra_col = (options & SEARCH_START) ? 0 : start_char_len;
    } else {
      extra_col = (options & SEARCH_START) ? start_char_len : 0;
    }

    pos_T start_pos = *pos;           // remember start pos for detecting no match
    found = 0;                  // default: not found
    int at_first_line = true;       // default: start in first line
    if (pos->lnum == 0) {       // correct lnum for when starting in line 0
      pos->lnum = 1;
      pos->col = 0;
      at_first_line = false;        // not in first line now
    }

    // Start searching in current line, unless searching backwards and
    // we're in column 0.
    // If we are searching backwards, in column 0, and not including the
    // current position, gain some efficiency by skipping back a line.
    // Otherwise begin the search in the current line.
    if (dir == BACKWARD && start_pos.col == 0
        && (options & SEARCH_START) == 0) {
      lnum = pos->lnum - 1;
      at_first_line = false;
    } else {
      lnum = pos->lnum;
    }

    for (loop = 0; loop <= 1; loop++) {     // loop twice if 'wrapscan' set
      for (; lnum > 0 && lnum <= buf->b_ml.ml_line_count;
           lnum += dir, at_first_line = false) {
        // Stop after checking "stop_lnum", if it's set.
        if (stop_lnum != 0 && (dir == FORWARD
                               ? lnum > stop_lnum : lnum < stop_lnum)) {
          break;
        }
        // Stop after passing the "tm" time limit.
        if (tm != NULL && profile_passed_limit(*tm)) {
          break;
        }

        // Look for a match somewhere in line "lnum".
        colnr_T col = at_first_line && (options & SEARCH_COL) ? pos->col : 0;
        nmatched = vim_regexec_multi(&regmatch, win, buf,
                                     lnum, col, tm, timed_out);
        // vim_regexec_multi() may clear "regprog"
        if (regmatch.regprog == NULL) {
          break;
        }
        // Abort searching on an error (e.g., out of stack).
        if (called_emsg > called_emsg_before || (timed_out != NULL && *timed_out)) {
          break;
        }
        if (nmatched > 0) {
          // match may actually be in another line when using \zs
          matchpos = regmatch.startpos[0];
          endpos = regmatch.endpos[0];
          submatch = first_submatch(&regmatch);
          // "lnum" may be past end of buffer for "\n\zs".
          if (lnum + matchpos.lnum > buf->b_ml.ml_line_count) {
            ptr = "";
          } else {
            ptr = ml_get_buf(buf, lnum + matchpos.lnum);
          }

          // Forward search in the first line: match should be after
          // the start position. If not, continue at the end of the
          // match (this is vi compatible) or on the next char.
          if (dir == FORWARD && at_first_line) {
            match_ok = true;

            // When the match starts in a next line it's certainly
            // past the start position.
            // When match lands on a NUL the cursor will be put
            // one back afterwards, compare with that position,
            // otherwise "/$" will get stuck on end of line.
            while (matchpos.lnum == 0
                   && (((options & SEARCH_END) && first_match)
                       ? (nmatched == 1
                          && (int)endpos.col - 1
                          < (int)start_pos.col + extra_col)
                       : ((int)matchpos.col
                          - (ptr[matchpos.col] == NUL)
                          < (int)start_pos.col + extra_col))) {
              // If vi-compatible searching, continue at the end
              // of the match, otherwise continue one position
              // forward.
              if (search_from_match_end) {
                if (nmatched > 1) {
                  // end is in next line, thus no match in
                  // this line
                  match_ok = false;
                  break;
                }
                matchcol = endpos.col;
                // for empty match: advance one char
                if (matchcol == matchpos.col && ptr[matchcol] != NUL) {
                  matchcol += utfc_ptr2len(ptr + matchcol);
                }
              } else {
                // Advance "matchcol" to the next character.
                // This uses rmm_matchcol, the actual start of
                // the match, ignoring "\zs".
                matchcol = regmatch.rmm_matchcol;
                if (ptr[matchcol] != NUL) {
                  matchcol += utfc_ptr2len(ptr + matchcol);
                }
              }
              if (matchcol == 0 && (options & SEARCH_START)) {
                break;
              }
              if (ptr[matchcol] == NUL
                  || (nmatched = vim_regexec_multi(&regmatch, win, buf,
                                                   lnum, matchcol, tm,
                                                   timed_out)) == 0) {
                match_ok = false;
                break;
              }
              // vim_regexec_multi() may clear "regprog"
              if (regmatch.regprog == NULL) {
                break;
              }
              matchpos = regmatch.startpos[0];
              endpos = regmatch.endpos[0];
              submatch = first_submatch(&regmatch);

              // This while-loop only works with matchpos.lnum == 0.
              // For bigger values the next line pointer ptr might not be a
              // buffer line.
              if (matchpos.lnum != 0) {
                break;
              }
              // Need to get the line pointer again, a multi-line search may
              // have made it invalid.
              ptr = ml_get_buf(buf, lnum);
            }
            if (!match_ok) {
              continue;
            }
          }
          if (dir == BACKWARD) {
            // Now, if there are multiple matches on this line,
            // we have to get the last one. Or the last one before
            // the cursor, if we're on that line.
            // When putting the new cursor at the end, compare
            // relative to the end of the match.
            match_ok = false;
            while (true) {
              // Remember a position that is before the start
              // position, we use it if it's the last match in
              // the line.  Always accept a position after
              // wrapping around.
              if (loop
                  || ((options & SEARCH_END)
                      ? (lnum + regmatch.endpos[0].lnum
                         < start_pos.lnum
                         || (lnum + regmatch.endpos[0].lnum
                             == start_pos.lnum
                             && (int)regmatch.endpos[0].col - 1
                             < (int)start_pos.col + extra_col))
                      : (lnum + regmatch.startpos[0].lnum
                         < start_pos.lnum
                         || (lnum + regmatch.startpos[0].lnum
                             == start_pos.lnum
                             && (int)regmatch.startpos[0].col
                             < (int)start_pos.col + extra_col)))) {
                match_ok = true;
                matchpos = regmatch.startpos[0];
                endpos = regmatch.endpos[0];
                submatch = first_submatch(&regmatch);
              } else {
                break;
              }

              // We found a valid match, now check if there is
              // another one after it.
              // If vi-compatible searching, continue at the end
              // of the match, otherwise continue one position
              // forward.
              if (search_from_match_end) {
                if (nmatched > 1) {
                  break;
                }
                matchcol = endpos.col;
                // for empty match: advance one char
                if (matchcol == matchpos.col
                    && ptr[matchcol] != NUL) {
                  matchcol += utfc_ptr2len(ptr + matchcol);
                }
              } else {
                // Stop when the match is in a next line.
                if (matchpos.lnum > 0) {
                  break;
                }
                matchcol = matchpos.col;
                if (ptr[matchcol] != NUL) {
                  matchcol += utfc_ptr2len(ptr + matchcol);
                }
              }
              if (ptr[matchcol] == NUL
                  || (nmatched = vim_regexec_multi(&regmatch, win, buf, lnum + matchpos.lnum,
                                                   matchcol, tm, timed_out)) == 0) {
                // If the search timed out, we did find a match
                // but it might be the wrong one, so that's not
                // OK.
                if (tm != NULL && profile_passed_limit(*tm)) {
                  match_ok = false;
                }
                break;
              }
              // vim_regexec_multi() may clear "regprog"
              if (regmatch.regprog == NULL) {
                break;
              }
              // Need to get the line pointer again, a
              // multi-line search may have made it invalid.
              ptr = ml_get_buf(buf, lnum + matchpos.lnum);
            }

            // If there is only a match after the cursor, skip
            // this match.
            if (!match_ok) {
              continue;
            }
          }

          // With the SEARCH_END option move to the last character
          // of the match.  Don't do it for an empty match, end
          // should be same as start then.
          if ((options & SEARCH_END) && !(options & SEARCH_NOOF)
              && !(matchpos.lnum == endpos.lnum
                   && matchpos.col == endpos.col)) {
            // For a match in the first column, set the position
            // on the NUL in the previous line.
            pos->lnum = lnum + endpos.lnum;
            pos->col = endpos.col;
            if (endpos.col == 0) {
              if (pos->lnum > 1) {              // just in case
                pos->lnum--;
                pos->col = ml_get_buf_len(buf, pos->lnum);
              }
            } else {
              pos->col--;
              if (pos->lnum <= buf->b_ml.ml_line_count) {
                ptr = ml_get_buf(buf, pos->lnum);
                pos->col -= utf_head_off(ptr, ptr + pos->col);
              }
            }
            if (end_pos != NULL) {
              end_pos->lnum = lnum + matchpos.lnum;
              end_pos->col = matchpos.col;
            }
          } else {
            pos->lnum = lnum + matchpos.lnum;
            pos->col = matchpos.col;
            if (end_pos != NULL) {
              end_pos->lnum = lnum + endpos.lnum;
              end_pos->col = endpos.col;
            }
          }
          pos->coladd = 0;
          if (end_pos != NULL) {
            end_pos->coladd = 0;
          }
          found = 1;
          first_match = false;

          // Set variables used for 'incsearch' highlighting.
          search_match_lines = endpos.lnum - matchpos.lnum;
          search_match_endcol = endpos.col;
          break;
        }
        line_breakcheck();              // stop if ctrl-C typed
        if (got_int) {
          break;
        }

        // Cancel searching if a character was typed.  Used for
        // 'incsearch'.  Don't check too often, that would slowdown
        // searching too much.
        if ((options & SEARCH_PEEK)
            && ((lnum - pos->lnum) & 0x3f) == 0
            && char_avail()) {
          break_loop = true;
          break;
        }

        if (loop && lnum == start_pos.lnum) {
          break;                    // if second loop, stop where started
        }
      }
      at_first_line = false;

      // vim_regexec_multi() may clear "regprog"
      if (regmatch.regprog == NULL) {
        break;
      }

      // Stop the search if wrapscan isn't set, "stop_lnum" is
      // specified, after an interrupt, after a match and after looping
      // twice.
      if (!p_ws || stop_lnum != 0 || got_int
          || called_emsg > called_emsg_before
          || (timed_out != NULL && *timed_out)
          || break_loop
          || found || loop) {
        break;
      }

      // If 'wrapscan' is set we continue at the other end of the file.
      // If 'shortmess' does not contain 's', we give a message, but
      // only, if we won't show the search stat later anyhow,
      // (so SEARCH_COUNT must be absent).
      // This message is also remembered in keep_msg for when the screen
      // is redrawn. The keep_msg is cleared whenever another message is
      // written.
      lnum = dir == BACKWARD  // start second loop at the other end
             ? buf->b_ml.ml_line_count
             : 1;
      if (!shortmess(SHM_SEARCH)
          && shortmess(SHM_SEARCHCOUNT)
          && (options & SEARCH_MSG)) {
        give_warning(_(dir == BACKWARD ? top_bot_msg : bot_top_msg), true);
      }
      if (extra_arg != NULL) {
        extra_arg->sa_wrapped = true;
      }
    }
    if (got_int || called_emsg > called_emsg_before
        || (timed_out != NULL && *timed_out)
        || break_loop) {
      break;
    }
  } while (--count > 0 && found);   // stop after count matches or no match

  vim_regfree(regmatch.regprog);

  if (!found) {             // did not find it
    if (got_int) {
      emsg(_(e_interr));
    } else if ((options & SEARCH_MSG) == SEARCH_MSG) {
      if (p_ws) {
        semsg(_(e_patnotf2), mr_pattern);
      } else if (lnum == 0) {
        semsg(_(e_search_hit_top_without_match_for_str), mr_pattern);
      } else {
        semsg(_(e_search_hit_bottom_without_match_for_str), mr_pattern);
      }
    }
    return FAIL;
  }

  // A pattern like "\n\zs" may go past the last line.
  if (pos->lnum > buf->b_ml.ml_line_count) {
    pos->lnum = buf->b_ml.ml_line_count;
    pos->col = ml_get_buf_len(buf, pos->lnum);
    if (pos->col > 0) {
      pos->col--;
    }
  }

  return submatch + 1;
}

void set_search_direction(int cdir)
{
  spats[0].off.dir = (char)cdir;
}

static void set_vv_searchforward(void)
{
  set_vim_var_nr(VV_SEARCHFORWARD, spats[0].off.dir == '/');
}

// Return the number of the first subpat that matched.
// Return zero if none of them matched.
static int first_submatch(regmmatch_T *rp)
{
  int submatch;

  for (submatch = 1;; submatch++) {
    if (rp->startpos[submatch].lnum >= 0) {
      break;
    }
    if (submatch == 9) {
      submatch = 0;
      break;
    }
  }
  return submatch;
}

/// Highest level string search function.
/// Search for the 'count'th occurrence of pattern 'pat' in direction 'dirc'
///
/// Careful: If spats[0].off.line == true and spats[0].off.off == 0 this
/// makes the movement linewise without moving the match position.
///
/// @param dirc          if 0: use previous dir.
/// @param pat           NULL or empty : use previous string.
/// @param options       if true and
///                      SEARCH_REV   == true : go in reverse of previous dir.
///                      SEARCH_ECHO  == true : echo the search command and handle options
///                      SEARCH_MSG   == true : may give error message
///                      SEARCH_OPT   == true : interpret optional flags
///                      SEARCH_HIS   == true : put search pattern in history
///                      SEARCH_NOOF  == true : don't add offset to position
///                      SEARCH_MARK  == true : set previous context mark
///                      SEARCH_KEEP  == true : keep previous search pattern
///                      SEARCH_START == true : accept match at curpos itself
///                      SEARCH_PEEK  == true : check for typed char, cancel search
/// @param oap           can be NULL
/// @param dirc          '/' or '?'
/// @param search_delim  delimiter for search, e.g. '%' in s%regex%replacement
/// @param sia           optional arguments or NULL
///
/// @return              0 for failure, 1 for found, 2 for found and line offset added.
int do_search(oparg_T *oap, int dirc, int search_delim, char *pat, size_t patlen, int count,
              int options, searchit_arg_T *sia)
{
  char *searchstr;
  size_t searchstrlen;
  int retval;                   // Return value
  char *p;
  int64_t c;
  char *dircp;
  char *strcopy = NULL;
  char *ps;
  char *msgbuf = NULL;
  size_t msgbuflen = 0;
  bool has_offset = false;

  searchcmdlen = 0;

  // A line offset is not remembered, this is vi compatible.
  if (spats[0].off.line && vim_strchr(p_cpo, CPO_LINEOFF) != NULL) {
    spats[0].off.line = false;
    spats[0].off.off = 0;
  }

  // Save the values for when (options & SEARCH_KEEP) is used.
  // (there is no "if ()" around this because gcc wants them initialized)
  SearchOffset old_off = spats[0].off;

  pos_T pos = curwin->w_cursor;  // Position of the last match.
                                 // Start searching at the cursor position.

  // Find out the direction of the search.
  if (dirc == 0) {
    dirc = (uint8_t)spats[0].off.dir;
  } else {
    spats[0].off.dir = (char)dirc;
    set_vv_searchforward();
  }
  if (options & SEARCH_REV) {
    dirc = dirc == '/' ? '?' : '/';
  }

  // If the cursor is in a closed fold, don't find another match in the same
  // fold.
  if (dirc == '/') {
    if (hasFolding(curwin, pos.lnum, NULL, &pos.lnum)) {
      pos.col = MAXCOL - 2;             // avoid overflow when adding 1
    }
  } else {
    if (hasFolding(curwin, pos.lnum, &pos.lnum, NULL)) {
      pos.col = 0;
    }
  }

  // Turn 'hlsearch' highlighting back on.
  if (no_hlsearch && !(options & SEARCH_KEEP)) {
    redraw_all_later(UPD_SOME_VALID);
    set_no_hlsearch(false);
  }

  // Repeat the search when pattern followed by ';', e.g. "/foo/;?bar".
  while (true) {
    bool show_top_bot_msg = false;

    searchstr = pat;
    searchstrlen = patlen;

    dircp = NULL;
    // use previous pattern
    if (pat == NULL || *pat == NUL || *pat == search_delim) {
      if (spats[RE_SEARCH].pat == NULL) {           // no previous pattern
        if (spats[RE_SUBST].pat == NULL) {
          emsg(_(e_noprevre));
          retval = 0;
          goto end_do_search;
        }
        searchstr = spats[RE_SUBST].pat;
        searchstrlen = spats[RE_SUBST].patlen;
      } else {
        // make search_regcomp() use spats[RE_SEARCH].pat
        searchstr = "";
        searchstrlen = 0;
      }
    }

    if (pat != NULL && *pat != NUL) {   // look for (new) offset
      // Find end of regular expression.
      // If there is a matching '/' or '?', toss it.
      ps = strcopy;
      p = skip_regexp_ex(pat, search_delim, magic_isset(), &strcopy, NULL, NULL);
      if (strcopy != ps) {
        size_t len = strlen(strcopy);
        // made a copy of "pat" to change "\?" to "?"
        searchcmdlen += (int)(patlen - len);
        pat = strcopy;
        patlen = len;
        searchstr = strcopy;
        searchstrlen = len;
      }
      if (*p == search_delim) {
        searchstrlen = (size_t)(p - pat);
        dircp = p;              // remember where we put the NUL
        *p++ = NUL;
      }
      spats[0].off.line = false;
      spats[0].off.end = false;
      spats[0].off.off = 0;
      // Check for a line offset or a character offset.
      // For get_address (echo off) we don't check for a character
      // offset, because it is meaningless and the 's' could be a
      // substitute command.
      if (*p == '+' || *p == '-' || ascii_isdigit(*p)) {
        spats[0].off.line = true;
      } else if ((options & SEARCH_OPT)
                 && (*p == 'e' || *p == 's' || *p == 'b')) {
        if (*p == 'e') {  // end
          spats[0].off.end = true;
        }
        p++;
      }
      if (ascii_isdigit(*p) || *p == '+' || *p == '-') {      // got an offset
        // 'nr' or '+nr' or '-nr'
        if (ascii_isdigit(*p) || ascii_isdigit(*(p + 1))) {
          spats[0].off.off = atol(p);
        } else if (*p == '-') {                      // single '-'
          spats[0].off.off = -1;
        } else {  // single '+'
          spats[0].off.off = 1;
        }
        p++;
        while (ascii_isdigit(*p)) {  // skip number
          p++;
        }
      }

      // compute length of search command for get_address()
      searchcmdlen += (int)(p - pat);

      patlen -= (size_t)(p - pat);
      pat = p;                              // put pat after search command
    }

    bool show_search_stats = false;
    if ((options & SEARCH_ECHO) && messaging() && !msg_silent
        && (!cmd_silent || !shortmess(SHM_SEARCHCOUNT))) {
      char off_buf[40];
      size_t off_len = 0;

      // Compute msg_row early.
      msg_start();
      msg_ext_set_kind("search_cmd");

      // Get the offset, so we know how long it is.
      if (!cmd_silent
          && (spats[0].off.line || spats[0].off.end || spats[0].off.off)) {
        off_buf[off_len++] = (char)dirc;
        if (spats[0].off.end) {
          off_buf[off_len++] = 'e';
        } else if (!spats[0].off.line) {
          off_buf[off_len++] = 's';
        }
        if (spats[0].off.off > 0 || spats[0].off.line) {
          off_buf[off_len++] = '+';
        }
        off_buf[off_len] = NUL;
        if (spats[0].off.off != 0 || spats[0].off.line) {
          off_len += (size_t)snprintf(off_buf + off_len, sizeof(off_buf) - off_len,
                                      "%" PRId64, spats[0].off.off);
        }
      }

      size_t plen;
      if (*searchstr == NUL) {
        p = spats[0].pat;
        plen = spats[0].patlen;
      } else {
        p = searchstr;
        plen = searchstrlen;
      }

      size_t msgbufsize;
      if (!shortmess(SHM_SEARCHCOUNT) || cmd_silent) {
        // Reserve enough space for the search pattern + offset +
        // search stat.  Use all the space available, so that the
        // search state is right aligned.  If there is not enough space
        // msg_strtrunc() will shorten in the middle.
        if (ui_has(kUIMessages)) {
          msgbufsize = 0;  // adjusted below
        } else if (msg_scrolled != 0 && !cmd_silent) {
          // Use all the columns.
          msgbufsize = (size_t)((Rows - msg_row) * Columns - 1);
        } else {
          // Use up to 'showcmd' column.
          msgbufsize = (size_t)((Rows - msg_row - 1) * Columns + sc_col - 1);
        }
        if (msgbufsize < plen + off_len + SEARCH_STAT_BUF_LEN + 3) {
          msgbufsize = plen + off_len + SEARCH_STAT_BUF_LEN + 3;
        }
      } else {
        // Reserve enough space for the search pattern + offset.
        msgbufsize = plen + off_len + 3;
      }

      xfree(msgbuf);
      msgbuf = xmalloc(msgbufsize);
      memset(msgbuf, ' ', msgbufsize);
      msgbuflen = msgbufsize - 1;
      msgbuf[msgbuflen] = NUL;

      // do not fill the msgbuf buffer, if cmd_silent is set, leave it
      // empty for the search_stat feature.
      if (!cmd_silent) {
        msgbuf[0] = (char)dirc;
        if (utf_iscomposing_first(utf_ptr2char(p))) {
          // Use a space to draw the composing char on.
          msgbuf[1] = ' ';
          memmove(msgbuf + 2, p, plen);
        } else {
          memmove(msgbuf + 1, p, plen);
        }
        if (off_len > 0) {
          memmove(msgbuf + plen + 1, off_buf, off_len);
        }

        char *trunc = msg_strtrunc(msgbuf, true);
        if (trunc != NULL) {
          xfree(msgbuf);
          msgbuf = trunc;
          msgbuflen = strlen(msgbuf);
        }

        // The search pattern could be shown on the right in rightleft
        // mode, but the 'ruler' and 'showcmd' area use it too, thus
        // it would be blanked out again very soon.  Show it on the
        // left, but do reverse the text.
        if (curwin->w_p_rl && *curwin->w_p_rlc == 's') {
          char *r = reverse_text(trunc != NULL ? trunc : msgbuf);
          xfree(msgbuf);
          msgbuf = r;
          // move reversed text to beginning of buffer
          while (*r == ' ') {
            r++;
          }
          size_t pat_len = (size_t)(msgbuf + msgbuflen - r);
          memmove(msgbuf, r, pat_len);
          // overwrite old text
          if ((size_t)(r - msgbuf) >= pat_len) {
            memset(r, ' ', pat_len);
          } else {
            memset(msgbuf + pat_len, ' ', (size_t)(r - msgbuf));
          }
        }
        msg_outtrans(msgbuf, 0, false);
        msg_clr_eos();
        msg_check();

        gotocmdline(false);
        ui_flush();
        msg_nowait = true;  // don't wait for this message
      }

      if (!shortmess(SHM_SEARCHCOUNT)) {
        show_search_stats = true;
      }
    }

    // If there is a character offset, subtract it from the current
    // position, so we don't get stuck at "?pat?e+2" or "/pat/s-2".
    // Skip this if pos.col is near MAXCOL (closed fold).
    // This is not done for a line offset, because then we would not be vi
    // compatible.
    if (!spats[0].off.line && spats[0].off.off && pos.col < MAXCOL - 2) {
      if (spats[0].off.off > 0) {
        for (c = spats[0].off.off; c; c--) {
          if (decl(&pos) == -1) {
            break;
          }
        }
        if (c) {                        // at start of buffer
          pos.lnum = 0;                 // allow lnum == 0 here
          pos.col = MAXCOL;
        }
      } else {
        for (c = spats[0].off.off; c; c++) {
          if (incl(&pos) == -1) {
            break;
          }
        }
        if (c) {                        // at end of buffer
          pos.lnum = curbuf->b_ml.ml_line_count + 1;
          pos.col = 0;
        }
      }
    }

    c = searchit(curwin, curbuf, &pos, NULL, dirc == '/' ? FORWARD : BACKWARD,
                 searchstr, searchstrlen, count,
                 (spats[0].off.end * SEARCH_END
                  + (options
                     & (SEARCH_KEEP + SEARCH_PEEK + SEARCH_HIS + SEARCH_MSG
                        + SEARCH_START
                        + ((pat != NULL && *pat == ';') ? 0 : SEARCH_NOOF)))),
                 RE_LAST, sia);

    if (dircp != NULL) {
      *dircp = (char)search_delim;  // restore second '/' or '?' for normal_cmd()
    }

    if (!shortmess(SHM_SEARCH)
        && ((dirc == '/' && lt(pos, curwin->w_cursor))
            || (dirc == '?' && lt(curwin->w_cursor, pos)))) {
      show_top_bot_msg = true;
    }

    if (c == FAIL) {
      retval = 0;
      goto end_do_search;
    }
    if (spats[0].off.end && oap != NULL) {
      oap->inclusive = true;        // 'e' includes last character
    }
    retval = 1;                     // pattern found

    if (sia && sia->sa_wrapped) {
      apply_autocmds(EVENT_SEARCHWRAPPED, NULL, NULL, false, NULL);
    }

    // Add character and/or line offset
    if (!(options & SEARCH_NOOF) || (pat != NULL && *pat == ';')) {
      pos_T org_pos = pos;

      if (spats[0].off.line) {  // Add the offset to the line number.
        c = pos.lnum + spats[0].off.off;
        if (c < 1) {
          pos.lnum = 1;
        } else if (c > curbuf->b_ml.ml_line_count) {
          pos.lnum = curbuf->b_ml.ml_line_count;
        } else {
          pos.lnum = (linenr_T)c;
        }
        pos.col = 0;

        retval = 2;                 // pattern found, line offset added
      } else if (pos.col < MAXCOL - 2) {      // just in case
        // to the right, check for end of file
        c = spats[0].off.off;
        if (c > 0) {
          while (c-- > 0) {
            if (incl(&pos) == -1) {
              break;
            }
          }
        } else {  // to the left, check for start of file
          while (c++ < 0) {
            if (decl(&pos) == -1) {
              break;
            }
          }
        }
      }
      if (!equalpos(pos, org_pos)) {
        has_offset = true;
      }
    }

    // Show [1/15] if 'S' is not in 'shortmess'.
    if (show_search_stats) {
      cmdline_search_stat(dirc, &pos, &curwin->w_cursor,
                          show_top_bot_msg, msgbuf, msgbuflen,
                          (count != 1 || has_offset
                           || (!(fdo_flags & kOptFdoFlagSearch)
                               && hasFolding(curwin, curwin->w_cursor.lnum, NULL,
                                             NULL))),
                          SEARCH_STAT_DEF_MAX_COUNT,
                          SEARCH_STAT_DEF_TIMEOUT);
    }

    // The search command can be followed by a ';' to do another search.
    // For example: "/pat/;/foo/+3;?bar"
    // This is like doing another search command, except:
    // - The remembered direction '/' or '?' is from the first search.
    // - When an error happens the cursor isn't moved at all.
    // Don't do this when called by get_address() (it handles ';' itself).
    if (!(options & SEARCH_OPT) || pat == NULL || *pat != ';') {
      break;
    }

    dirc = (uint8_t)(*++pat);
    search_delim = dirc;
    if (dirc != '?' && dirc != '/') {
      retval = 0;
      emsg(_("E386: Expected '?' or '/'  after ';'"));
      goto end_do_search;
    }
    pat++;
    patlen--;
  }

  if (options & SEARCH_MARK) {
    setpcmark();
  }
  curwin->w_cursor = pos;
  curwin->w_set_curswant = true;

end_do_search:
  if ((options & SEARCH_KEEP) || (cmdmod.cmod_flags & CMOD_KEEPPATTERNS)) {
    spats[0].off = old_off;
  }
  xfree(strcopy);
  xfree(msgbuf);

  return retval;
}

// search_for_exact_line(buf, pos, dir, pat)
//
// Search for a line starting with the given pattern (ignoring leading
// white-space), starting from pos and going in direction "dir". "pos" will
// contain the position of the match found.    Blank lines match only if
// ADDING is set.  If p_ic is set then the pattern must be in lowercase.
// Return OK for success, or FAIL if no line found.
int search_for_exact_line(buf_T *buf, pos_T *pos, Direction dir, char *pat)
{
  linenr_T start = 0;

  if (buf->b_ml.ml_line_count == 0) {
    return FAIL;
  }
  while (true) {
    pos->lnum += dir;
    if (pos->lnum < 1) {
      if (p_ws) {
        pos->lnum = buf->b_ml.ml_line_count;
        if (!shortmess(SHM_SEARCH)) {
          give_warning(_(top_bot_msg), true);
        }
      } else {
        pos->lnum = 1;
        break;
      }
    } else if (pos->lnum > buf->b_ml.ml_line_count) {
      if (p_ws) {
        pos->lnum = 1;
        if (!shortmess(SHM_SEARCH)) {
          give_warning(_(bot_top_msg), true);
        }
      } else {
        pos->lnum = 1;
        break;
      }
    }
    if (pos->lnum == start) {
      break;
    }
    if (start == 0) {
      start = pos->lnum;
    }
    char *ptr = ml_get_buf(buf, pos->lnum);
    char *p = skipwhite(ptr);
    pos->col = (colnr_T)(p - ptr);

    // when adding lines the matching line may be empty but it is not
    // ignored because we are interested in the next line -- Acevedo
    if (compl_status_adding() && !compl_status_sol()) {
      if (mb_strcmp_ic((bool)p_ic, p, pat) == 0) {
        return OK;
      }
    } else if (*p != NUL) {  // Ignore empty lines.
      // Expanding lines or words.
      assert(ins_compl_len() >= 0);
      if ((p_ic ? mb_strnicmp(p, pat, (size_t)ins_compl_len())
                : strncmp(p, pat, (size_t)ins_compl_len())) == 0) {
        return OK;
      }
    }
  }
  return FAIL;
}

// Character Searches

/// Search for a character in a line.  If "t_cmd" is false, move to the
/// position of the character, otherwise move to just before the char.
/// Do this "cap->count1" times.
/// Return FAIL or OK.
int searchc(cmdarg_T *cap, bool t_cmd)
  FUNC_ATTR_NONNULL_ALL
{
  int c = cap->nchar;                   // char to search for
  int dir = cap->arg;                   // true for searching forward
  int count = cap->count1;              // repeat count
  bool stop = true;

  if (c != NUL) {       // normal search: remember args for repeat
    if (!KeyStuffed) {      // don't remember when redoing
      *lastc = (uint8_t)c;
      set_csearch_direction(dir);
      set_csearch_until(t_cmd);
      if (cap->nchar_len) {
        lastc_bytelen = cap->nchar_len;
        memcpy(lastc_bytes, cap->nchar_composing, (size_t)cap->nchar_len);
      } else {
        lastc_bytelen = utf_char2bytes(c, lastc_bytes);
      }
    }
  } else {            // repeat previous search
    if (*lastc == NUL && lastc_bytelen <= 1) {
      return FAIL;
    }
    dir = dir  // repeat in opposite direction
          ? -lastcdir
          : lastcdir;
    t_cmd = last_t_cmd;
    c = *lastc;
    // For multi-byte re-use last lastc_bytes[] and lastc_bytelen.

    // Force a move of at least one char, so ";" and "," will move the
    // cursor, even if the cursor is right in front of char we are looking
    // at.
    if (vim_strchr(p_cpo, CPO_SCOLON) == NULL && count == 1 && t_cmd) {
      stop = false;
    }
  }

  cap->oap->inclusive = dir != BACKWARD;

  char *p = get_cursor_line_ptr();
  int col = curwin->w_cursor.col;
  int len = get_cursor_line_len();

  while (count--) {
    while (true) {
      if (dir > 0) {
        col += utfc_ptr2len(p + col);
        if (col >= len) {
          return FAIL;
        }
      } else {
        if (col == 0) {
          return FAIL;
        }
        col -= utf_head_off(p, p + col - 1) + 1;
      }
      if (lastc_bytelen <= 1) {
        if (p[col] == c && stop) {
          break;
        }
      } else if (strncmp(p + col, lastc_bytes, (size_t)lastc_bytelen) == 0 && stop) {
        break;
      }
      stop = true;
    }
  }

  if (t_cmd) {
    // Backup to before the character (possibly double-byte).
    col -= dir;
    if (dir < 0) {
      // Landed on the search char which is lastc_bytelen long.
      col += lastc_bytelen - 1;
    } else {
      // To previous char, which may be multi-byte.
      col -= utf_head_off(p, p + col);
    }
  }
  curwin->w_cursor.col = col;

  return OK;
}

// "Other" Searches

// findmatch - find the matching paren or brace
//
// Improvement over vi: Braces inside quotes are ignored.
pos_T *findmatch(oparg_T *oap, int initc)
{
  return findmatchlimit(oap, initc, 0, 0);
}

// Return true if the character before "linep[col]" equals "ch".
// Return false if "col" is zero.
// Update "*prevcol" to the column of the previous character, unless "prevcol"
// is NULL.
// Handles multibyte string correctly.
static bool check_prevcol(char *linep, int col, int ch, int *prevcol)
{
  col--;
  if (col > 0) {
    col -= utf_head_off(linep, linep + col);
  }
  if (prevcol) {
    *prevcol = col;
  }
  return col >= 0 && (uint8_t)linep[col] == ch;
}

/// Raw string start is found at linep[startpos.col - 1].
///
/// @return  true if the matching end can be found between startpos and endpos.
static bool find_rawstring_end(char *linep, pos_T *startpos, pos_T *endpos)
{
  char *p;
  linenr_T lnum;

  for (p = linep + startpos->col + 1; *p && *p != '('; p++) {}

  size_t delim_len = (size_t)((p - linep) - startpos->col - 1);
  char *delim_copy = xmemdupz(linep + startpos->col + 1, delim_len);
  bool found = false;
  for (lnum = startpos->lnum; lnum <= endpos->lnum; lnum++) {
    char *line = ml_get(lnum);

    for (p = line + (lnum == startpos->lnum ? startpos->col + 1 : 0); *p; p++) {
      if (lnum == endpos->lnum && (colnr_T)(p - line) >= endpos->col) {
        break;
      }
      if (*p == ')'
          && strncmp(delim_copy, p + 1, delim_len) == 0
          && p[delim_len + 1] == '"') {
        found = true;
        break;
      }
    }
    if (found) {
      break;
    }
  }
  xfree(delim_copy);
  return found;
}

/// Check matchpairs option for "*initc".
/// If there is a match set "*initc" to the matching character and "*findc" to
/// the opposite character.  Set "*backwards" to the direction.
/// When "switchit" is true swap the direction.
static void find_mps_values(int *initc, int *findc, bool *backwards, bool switchit)
  FUNC_ATTR_NONNULL_ALL
{
  char *ptr = curbuf->b_p_mps;

  while (*ptr != NUL) {
    if (utf_ptr2char(ptr) == *initc) {
      if (switchit) {
        *findc = *initc;
        *initc = utf_ptr2char(ptr + utfc_ptr2len(ptr) + 1);
        *backwards = true;
      } else {
        *findc = utf_ptr2char(ptr + utfc_ptr2len(ptr) + 1);
        *backwards = false;
      }
      return;
    }
    char *prev = ptr;
    ptr += utfc_ptr2len(ptr) + 1;
    if (utf_ptr2char(ptr) == *initc) {
      if (switchit) {
        *findc = *initc;
        *initc = utf_ptr2char(prev);
        *backwards = false;
      } else {
        *findc = utf_ptr2char(prev);
        *backwards = true;
      }
      return;
    }
    ptr += utfc_ptr2len(ptr);
    if (*ptr == ',') {
      ptr++;
    }
  }
}

// findmatchlimit -- find the matching paren or brace, if it exists within
// maxtravel lines of the cursor.  A maxtravel of 0 means search until falling
// off the edge of the file.
//
// "initc" is the character to find a match for.  NUL means to find the
// character at or after the cursor. Special values:
// '*'  look for C-style comment / *
// '/'  look for C-style comment / *, ignoring comment-end
// '#'  look for preprocessor directives
// 'R'  look for raw string start: R"delim(text)delim" (only backwards)
//
// flags: FM_BACKWARD search backwards (when initc is '/', '*' or '#')
//    FM_FORWARD  search forwards (when initc is '/', '*' or '#')
//    FM_BLOCKSTOP  stop at start/end of block ({ or } in column 0)
//    FM_SKIPCOMM skip comments (not implemented yet!)
//
// "oap" is only used to set oap->motion_type for a linewise motion, it can be
// NULL
pos_T *findmatchlimit(oparg_T *oap, int initc, int flags, int64_t maxtravel)
{
  static pos_T pos;                     // current search position
  int findc = 0;                        // matching brace
  int count = 0;                        // cumulative number of braces
  bool backwards = false;               // init for gcc
  bool raw_string = false;              // search for raw string
  bool inquote = false;                 // true when inside quotes
  char *ptr;
  int hash_dir = 0;                     // Direction searched for # things
  int comment_dir = 0;                  // Direction searched for comments
  int traveled = 0;                     // how far we've searched so far
  bool ignore_cend = false;             // ignore comment end
  int match_escaped = 0;                // search for escaped match
  int dir;                              // Direction to search
  int comment_col = MAXCOL;             // start of / / comment
  bool lispcomm = false;                // inside of Lisp-style comment
  bool lisp = curbuf->b_p_lisp;         // engage Lisp-specific hacks ;)

  pos = curwin->w_cursor;
  pos.coladd = 0;
  char *linep = ml_get(pos.lnum);     // pointer to current line

  // vi compatible matching
  bool cpo_match = (vim_strchr(p_cpo, CPO_MATCH) != NULL);
  // don't recognize backslashes
  bool cpo_bsl = (vim_strchr(p_cpo, CPO_MATCHBSL) != NULL);

  // Direction to search when initc is '/', '*' or '#'
  if (flags & FM_BACKWARD) {
    dir = BACKWARD;
  } else if (flags & FM_FORWARD) {
    dir = FORWARD;
  } else {
    dir = 0;
  }

  // if initc given, look in the table for the matching character
  // '/' and '*' are special cases: look for start or end of comment.
  // When '/' is used, we ignore running backwards into a star-slash, for
  // "[*" command, we just want to find any comment.
  if (initc == '/' || initc == '*' || initc == 'R') {
    comment_dir = dir;
    if (initc == '/') {
      ignore_cend = true;
    }
    backwards = (dir == FORWARD) ? false : true;
    raw_string = (initc == 'R');
    initc = NUL;
  } else if (initc != '#' && initc != NUL) {
    find_mps_values(&initc, &findc, &backwards, true);
    if (dir) {
      backwards = (dir == FORWARD) ? false : true;
    }
    if (findc == NUL) {
      return NULL;
    }
  } else {
    // Either initc is '#', or no initc was given and we need to look
    // under the cursor.
    if (initc == '#') {
      hash_dir = dir;
    } else {
      // initc was not given, must look for something to match under
      // or near the cursor.
      // Only check for special things when 'cpo' doesn't have '%'.
      if (!cpo_match) {
        // Are we before or at #if, #else etc.?
        ptr = skipwhite(linep);
        if (*ptr == '#' && pos.col <= (colnr_T)(ptr - linep)) {
          ptr = skipwhite(ptr + 1);
          if (strncmp(ptr, "if", 2) == 0
              || strncmp(ptr, "endif", 5) == 0
              || strncmp(ptr, "el", 2) == 0) {
            hash_dir = 1;
          }
        } else if (linep[pos.col] == '/') {  // Are we on a comment?
          if (linep[pos.col + 1] == '*') {
            comment_dir = FORWARD;
            backwards = false;
            pos.col++;
          } else if (pos.col > 0 && linep[pos.col - 1] == '*') {
            comment_dir = BACKWARD;
            backwards = true;
            pos.col--;
          }
        } else if (linep[pos.col] == '*') {
          if (linep[pos.col + 1] == '/') {
            comment_dir = BACKWARD;
            backwards = true;
          } else if (pos.col > 0 && linep[pos.col - 1] == '/') {
            comment_dir = FORWARD;
            backwards = false;
          }
        }
      }

      // If we are not on a comment or the # at the start of a line, then
      // look for brace anywhere on this line after the cursor.
      if (!hash_dir && !comment_dir) {
        // Find the brace under or after the cursor.
        // If beyond the end of the line, use the last character in
        // the line.
        if (linep[pos.col] == NUL && pos.col) {
          pos.col--;
        }
        while (true) {
          initc = utf_ptr2char(linep + pos.col);
          if (initc == NUL) {
            break;
          }

          find_mps_values(&initc, &findc, &backwards, false);
          if (findc) {
            break;
          }
          pos.col += utfc_ptr2len(linep + pos.col);
        }
        if (!findc) {
          // no brace in the line, maybe use "  #if" then
          if (!cpo_match && *skipwhite(linep) == '#') {
            hash_dir = 1;
          } else {
            return NULL;
          }
        } else if (!cpo_bsl) {
          int bslcnt = 0;

          // Set "match_escaped" if there are an odd number of
          // backslashes.
          for (int col = pos.col; check_prevcol(linep, col, '\\', &col);) {
            bslcnt++;
          }
          match_escaped = (bslcnt & 1);
        }
      }
    }
    if (hash_dir) {
      // Look for matching #if, #else, #elif, or #endif
      if (oap != NULL) {
        oap->motion_type = kMTLineWise;  // Linewise for this case only
      }
      if (initc != '#') {
        ptr = skipwhite(skipwhite(linep) + 1);
        if (strncmp(ptr, "if", 2) == 0 || strncmp(ptr, "el", 2) == 0) {
          hash_dir = 1;
        } else if (strncmp(ptr, "endif", 5) == 0) {
          hash_dir = -1;
        } else {
          return NULL;
        }
      }
      pos.col = 0;
      while (!got_int) {
        if (hash_dir > 0) {
          if (pos.lnum == curbuf->b_ml.ml_line_count) {
            break;
          }
        } else if (pos.lnum == 1) {
          break;
        }
        pos.lnum += hash_dir;
        linep = ml_get(pos.lnum);
        line_breakcheck();              // check for CTRL-C typed
        ptr = skipwhite(linep);
        if (*ptr != '#') {
          continue;
        }
        pos.col = (colnr_T)(ptr - linep);
        ptr = skipwhite(ptr + 1);
        if (hash_dir > 0) {
          if (strncmp(ptr, "if", 2) == 0) {
            count++;
          } else if (strncmp(ptr, "el", 2) == 0) {
            if (count == 0) {
              return &pos;
            }
          } else if (strncmp(ptr, "endif", 5) == 0) {
            if (count == 0) {
              return &pos;
            }
            count--;
          }
        } else {
          if (strncmp(ptr, "if", 2) == 0) {
            if (count == 0) {
              return &pos;
            }
            count--;
          } else if (initc == '#' && strncmp(ptr, "el", 2) == 0) {
            if (count == 0) {
              return &pos;
            }
          } else if (strncmp(ptr, "endif", 5) == 0) {
            count++;
          }
        }
      }
      return NULL;
    }
  }

  // This is just guessing: when 'rightleft' is set, search for a matching
  // paren/brace in the other direction.
  if (curwin->w_p_rl && vim_strchr("()[]{}<>", initc) != NULL) {
    backwards = !backwards;
  }

  int do_quotes = -1;                 // check for quotes in current line
  int at_start;                       // do_quotes value at start position
  TriState start_in_quotes = kNone;   // start position is in quotes
  pos_T match_pos;                    // Where last slash-star was found
  clearpos(&match_pos);

  // backward search: Check if this line contains a single-line comment
  if ((backwards && comment_dir) || lisp) {
    comment_col = check_linecomment(linep);
  }
  if (lisp && comment_col != MAXCOL && pos.col > (colnr_T)comment_col) {
    lispcomm = true;        // find match inside this comment
  }

  while (!got_int) {
    // Go to the next position, forward or backward. We could use
    // inc() and dec() here, but that is much slower
    if (backwards) {
      // char to match is inside of comment, don't search outside
      if (lispcomm && pos.col < (colnr_T)comment_col) {
        break;
      }
      if (pos.col == 0) {               // at start of line, go to prev. one
        if (pos.lnum == 1) {            // start of file
          break;
        }
        pos.lnum--;

        if (maxtravel > 0 && ++traveled > maxtravel) {
          break;
        }

        linep = ml_get(pos.lnum);
        pos.col = ml_get_len(pos.lnum);  // pos.col on trailing NUL
        do_quotes = -1;
        line_breakcheck();

        // Check if this line contains a single-line comment
        if (comment_dir || lisp) {
          comment_col = check_linecomment(linep);
        }
        // skip comment
        if (lisp && comment_col != MAXCOL) {
          pos.col = comment_col;
        }
      } else {
        pos.col--;
        pos.col -= utf_head_off(linep, linep + pos.col);
      }
    } else {                          // forward search
      if (linep[pos.col] == NUL
          // at end of line, go to next one
          // For lisp don't search for match in comment
          || (lisp && comment_col != MAXCOL
              && pos.col == (colnr_T)comment_col)) {
        if (pos.lnum == curbuf->b_ml.ml_line_count          // end of file
            // line is exhausted and comment with it,
            // don't search for match in code
            || lispcomm) {
          break;
        }
        pos.lnum++;

        if (maxtravel && traveled++ > maxtravel) {
          break;
        }

        linep = ml_get(pos.lnum);
        pos.col = 0;
        do_quotes = -1;
        line_breakcheck();
        if (lisp) {         // find comment pos in new line
          comment_col = check_linecomment(linep);
        }
      } else {
        pos.col += utfc_ptr2len(linep + pos.col);
      }
    }

    // If FM_BLOCKSTOP given, stop at a '{' or '}' in column 0.
    if (pos.col == 0 && (flags & FM_BLOCKSTOP)
        && (linep[0] == '{' || linep[0] == '}')) {
      if (linep[0] == findc && count == 0) {  // match!
        return &pos;
      }
      break;  // out of scope
    }

    if (comment_dir) {
      // Note: comments do not nest, and we ignore quotes in them
      // TODO(vim): ignore comment brackets inside strings
      if (comment_dir == FORWARD) {
        if (linep[pos.col] == '*' && linep[pos.col + 1] == '/') {
          pos.col++;
          return &pos;
        }
      } else {    // Searching backwards
        // A comment may contain / * or / /, it may also start or end
        // with / * /. Ignore a / * after / / and after *.
        if (pos.col == 0) {
          continue;
        } else if (raw_string) {
          if (linep[pos.col - 1] == 'R'
              && linep[pos.col] == '"'
              && vim_strchr(linep + pos.col + 1, '(') != NULL) {
            // Possible start of raw string. Now that we have the
            // delimiter we can check if it ends before where we
            // started searching, or before the previously found
            // raw string start.
            if (!find_rawstring_end(linep, &pos,
                                    count > 0 ? &match_pos : &curwin->w_cursor)) {
              count++;
              match_pos = pos;
              match_pos.col--;
            }
            linep = ml_get(pos.lnum);  // may have been released
          }
        } else if (linep[pos.col - 1] == '/'
                   && linep[pos.col] == '*'
                   && (pos.col == 1 || linep[pos.col - 2] != '*')
                   && (int)pos.col < comment_col) {
          count++;
          match_pos = pos;
          match_pos.col--;
        } else if (linep[pos.col - 1] == '*' && linep[pos.col] == '/') {
          if (count > 0) {
            pos = match_pos;
          } else if (pos.col > 1 && linep[pos.col - 2] == '/'
                     && (int)pos.col <= comment_col) {
            pos.col -= 2;
          } else if (ignore_cend) {
            continue;
          } else {
            return NULL;
          }
          return &pos;
        }
      }
      continue;
    }

    // If smart matching ('cpoptions' does not contain '%'), braces inside
    // of quotes are ignored, but only if there is an even number of
    // quotes in the line.
    if (cpo_match) {
      do_quotes = 0;
    } else if (do_quotes == -1) {
      // Count the number of quotes in the line, skipping \" and '"'.
      // Watch out for "\\".
      at_start = do_quotes;
      for (ptr = linep; *ptr; ptr++) {
        if (ptr == linep + pos.col + backwards) {
          at_start = (do_quotes & 1);
        }
        if (*ptr == '"'
            && (ptr == linep || ptr[-1] != '\'' || ptr[1] != '\'')) {
          do_quotes++;
        }
        if (*ptr == '\\' && ptr[1] != NUL) {
          ptr++;
        }
      }
      do_quotes &= 1;               // result is 1 with even number of quotes

      // If we find an uneven count, check current line and previous
      // one for a '\' at the end.
      if (!do_quotes) {
        inquote = false;
        if (ptr[-1] == '\\') {
          do_quotes = 1;
          if (start_in_quotes == kNone) {
            // Do we need to use at_start here?
            inquote = true;
            start_in_quotes = kTrue;
          } else if (backwards) {
            inquote = true;
          }
        }
        if (pos.lnum > 1) {
          ptr = ml_get(pos.lnum - 1);
          if (*ptr && *(ptr + ml_get_len(pos.lnum - 1) - 1) == '\\') {
            do_quotes = 1;
            if (start_in_quotes == kNone) {
              inquote = at_start;
              if (inquote) {
                start_in_quotes = kTrue;
              }
            } else if (!backwards) {
              inquote = true;
            }
          }

          // ml_get() only keeps one line, need to get linep again
          linep = ml_get(pos.lnum);
        }
      }
    }
    if (start_in_quotes == kNone) {
      start_in_quotes = kFalse;
    }

    // If 'smartmatch' is set:
    //   Things inside quotes are ignored by setting 'inquote'.  If we
    //   find a quote without a preceding '\' invert 'inquote'.  At the
    //   end of a line not ending in '\' we reset 'inquote'.
    //
    //   In lines with an uneven number of quotes (without preceding '\')
    //   we do not know which part to ignore. Therefore we only set
    //   inquote if the number of quotes in a line is even, unless this
    //   line or the previous one ends in a '\'.  Complicated, isn't it?
    const int c = utf_ptr2char(linep + pos.col);
    switch (c) {
    case NUL:
      // at end of line without trailing backslash, reset inquote
      if (pos.col == 0 || linep[pos.col - 1] != '\\') {
        inquote = false;
        start_in_quotes = kFalse;
      }
      break;

    case '"':
      // a quote that is preceded with an odd number of backslashes is
      // ignored
      if (do_quotes) {
        int col;

        for (col = pos.col - 1; col >= 0; col--) {
          if (linep[col] != '\\') {
            break;
          }
        }
        if ((((int)pos.col - 1 - col) & 1) == 0) {
          inquote = !inquote;
          start_in_quotes = kFalse;
        }
      }
      break;

    // If smart matching ('cpoptions' does not contain '%'):
    //   Skip things in single quotes: 'x' or '\x'.  Be careful for single
    //   single quotes, eg jon's.  Things like '\233' or '\x3f' are not
    //   skipped, there is never a brace in them.
    //   Ignore this when finding matches for `'.
    case '\'':
      if (!cpo_match && initc != '\'' && findc != '\'') {
        if (backwards) {
          if (pos.col > 1) {
            if (linep[pos.col - 2] == '\'') {
              pos.col -= 2;
              break;
            } else if (linep[pos.col - 2] == '\\'
                       && pos.col > 2 && linep[pos.col - 3] == '\'') {
              pos.col -= 3;
              break;
            }
          }
        } else if (linep[pos.col + 1]) {  // forward search
          if (linep[pos.col + 1] == '\\'
              && linep[pos.col + 2] && linep[pos.col + 3] == '\'') {
            pos.col += 3;
            break;
          } else if (linep[pos.col + 2] == '\'') {
            pos.col += 2;
            break;
          }
        }
      }
      FALLTHROUGH;

    default:
      // For Lisp skip over backslashed (), {} and [].
      // (actually, we skip #\( et al)
      if (curbuf->b_p_lisp
          && vim_strchr("(){}[]", c) != NULL
          && pos.col > 1
          && check_prevcol(linep, pos.col, '\\', NULL)
          && check_prevcol(linep, pos.col - 1, '#', NULL)) {
        break;
      }

      // Check for match outside of quotes, and inside of
      // quotes when the start is also inside of quotes.
      if ((!inquote || start_in_quotes == kTrue)
          && (c == initc || c == findc)) {
        int bslcnt = 0;

        if (!cpo_bsl) {
          for (int col = pos.col; check_prevcol(linep, col, '\\', &col);) {
            bslcnt++;
          }
        }
        // Only accept a match when 'M' is in 'cpo' or when escaping
        // is what we expect.
        if (cpo_bsl || (bslcnt & 1) == match_escaped) {
          if (c == initc) {
            count++;
          } else {
            if (count == 0) {
              return &pos;
            }
            count--;
          }
        }
      }
    }
  }

  if (comment_dir == BACKWARD && count > 0) {
    pos = match_pos;
    return &pos;
  }
  return (pos_T *)NULL;         // never found it
}

/// Check if line[] contains a / / comment.
/// @returns MAXCOL if not, otherwise return the column.
int check_linecomment(const char *line)
{
  const char *p = line;  // scan from start
  // skip Lispish one-line comments
  if (curbuf->b_p_lisp) {
    if (vim_strchr(p, ';') != NULL) {   // there may be comments
      bool in_str = false;       // inside of string

      while ((p = strpbrk(p, "\";")) != NULL) {
        if (*p == '"') {
          if (in_str) {
            if (*(p - 1) != '\\') {             // skip escaped quote
              in_str = false;
            }
          } else if (p == line || ((p - line) >= 2
                                   // skip #\" form
                                   && *(p - 1) != '\\' && *(p - 2) != '#')) {
            in_str = true;
          }
        } else if (!in_str && ((p - line) < 2
                               || (*(p - 1) != '\\' && *(p - 2) != '#'))
                   && !is_pos_in_string(line, (colnr_T)(p - line))) {
          break;                // found!
        }
        p++;
      }
    } else {
      p = NULL;
    }
  } else {
    while ((p = vim_strchr(p, '/')) != NULL) {
      // Accept a double /, unless it's preceded with * and followed by *,
      // because * / / * is an end and start of a C comment.  Only
      // accept the position if it is not inside a string.
      if (p[1] == '/' && (p == line || p[-1] != '*' || p[2] != '*')
          && !is_pos_in_string(line, (colnr_T)(p - line))) {
        break;
      }
      p++;
    }
  }

  if (p == NULL) {
    return MAXCOL;
  }
  return (int)(p - line);
}

/// Move cursor briefly to character matching the one under the cursor.
/// Used for Insert mode and "r" command.
/// Show the match only if it is visible on the screen.
/// If there isn't a match, then beep.
///
/// @param c  char to show match for
void showmatch(int c)
{
  pos_T *lpos;
  colnr_T vcol;
  OptInt *so = curwin->w_p_so >= 0 ? &curwin->w_p_so : &p_so;
  OptInt *siso = curwin->w_p_siso >= 0 ? &curwin->w_p_siso : &p_siso;
  char *p;

  // Only show match for chars in the 'matchpairs' option.
  // 'matchpairs' is "x:y,x:y"
  for (p = curbuf->b_p_mps; *p != NUL; p++) {
    if (utf_ptr2char(p) == c && (curwin->w_p_rl ^ p_ri)) {
      break;
    }
    p += utfc_ptr2len(p) + 1;
    if (utf_ptr2char(p) == c && !(curwin->w_p_rl ^ p_ri)) {
      break;
    }
    p += utfc_ptr2len(p);
    if (*p == NUL) {
      return;
    }
  }
  if (*p == NUL) {
    return;
  }

  if ((lpos = findmatch(NULL, NUL)) == NULL) {  // no match, so beep
    vim_beep(kOptBoFlagShowmatch);
    return;
  }

  if (lpos->lnum < curwin->w_topline || lpos->lnum >= curwin->w_botline) {
    return;
  }

  if (!curwin->w_p_wrap) {
    getvcol(curwin, lpos, NULL, &vcol, NULL);
  }

  bool col_visible = curwin->w_p_wrap
                     || (vcol >= curwin->w_leftcol
                         && vcol < curwin->w_leftcol + curwin->w_width_inner);
  if (!col_visible) {
    return;
  }

  pos_T mpos = *lpos;  // save the pos, update_screen() may change it
  pos_T save_cursor = curwin->w_cursor;
  OptInt save_so = *so;
  OptInt save_siso = *siso;
  // Handle "$" in 'cpo': If the ')' is typed on top of the "$",
  // stop displaying the "$".
  if (dollar_vcol >= 0 && dollar_vcol == curwin->w_virtcol) {
    dollar_vcol = -1;
  }
  curwin->w_virtcol++;              // do display ')' just before "$"

  colnr_T save_dollar_vcol = dollar_vcol;
  int save_state = State;
  State = MODE_SHOWMATCH;
  ui_cursor_shape();                // may show different cursor shape
  curwin->w_cursor = mpos;          // move to matching char
  *so = 0;                          // don't use 'scrolloff' here
  *siso = 0;                        // don't use 'sidescrolloff' here
  show_cursor_info_later(false);
  update_screen();                  // show the new char
  setcursor();
  ui_flush();
  // Restore dollar_vcol(), because setcursor() may call curs_rows()
  // which resets it if the matching position is in a previous line
  // and has a higher column number.
  dollar_vcol = save_dollar_vcol;

  // brief pause, unless 'm' is present in 'cpo' and a character is
  // available.
  if (vim_strchr(p_cpo, CPO_SHOWMATCH) != NULL) {
    os_delay((uint64_t)p_mat * 100 + 8, true);
  } else if (!char_avail()) {
    os_delay((uint64_t)p_mat * 100 + 9, false);
  }
  curwin->w_cursor = save_cursor;           // restore cursor position
  *so = save_so;
  *siso = save_siso;
  State = save_state;
  ui_cursor_shape();                // may show different cursor shape
}

/// Find next search match under cursor, cursor at end.
/// Used while an operator is pending, and in Visual mode.
///
/// @param forward  true for forward, false for backward
int current_search(int count, bool forward)
{
  bool old_p_ws = p_ws;
  pos_T save_VIsual = VIsual;

  // Correct cursor when 'selection' is exclusive
  if (VIsual_active && *p_sel == 'e' && lt(VIsual, curwin->w_cursor)) {
    dec_cursor();
  }

  // When searching forward and the cursor is at the start of the Visual
  // area, skip the first search backward, otherwise it doesn't move.
  const bool skip_first_backward = forward && VIsual_active
                                   && lt(curwin->w_cursor, VIsual);

  pos_T pos = curwin->w_cursor;       // position after the pattern
  pos_T orig_pos = curwin->w_cursor;  // position of the cursor at beginning
  if (VIsual_active) {
    // Searching further will extend the match.
    if (forward) {
      incl(&pos);
    } else {
      decl(&pos);
    }
  }

  // Is the pattern is zero-width?, this time, don't care about the direction
  int zero_width = is_zero_width(spats[last_idx].pat, spats[last_idx].patlen,
                                 true, &curwin->w_cursor, FORWARD);
  if (zero_width == -1) {
    return FAIL;  // pattern not found
  }

  pos_T end_pos;  // end position of the pattern match
  int result;     // result of various function calls

  // The trick is to first search backwards and then search forward again,
  // so that a match at the current cursor position will be correctly
  // captured.  When "forward" is false do it the other way around.
  for (int i = 0; i < 2; i++) {
    int dir;
    if (forward) {
      if (i == 0 && skip_first_backward) {
        continue;
      }
      dir = i;
    } else {
      dir = !i;
    }

    int flags = 0;

    if (!dir && !zero_width) {
      flags = SEARCH_END;
    }
    end_pos = pos;

    // wrapping should not occur in the first round
    if (i == 0) {
      p_ws = false;
    }

    result = searchit(curwin, curbuf, &pos, &end_pos,
                      (dir ? FORWARD : BACKWARD),
                      spats[last_idx].pat, spats[last_idx].patlen, i ? count : 1,
                      SEARCH_KEEP | flags, RE_SEARCH, NULL);

    p_ws = old_p_ws;

    // First search may fail, but then start searching from the
    // beginning of the file (cursor might be on the search match)
    // except when Visual mode is active, so that extending the visual
    // selection works.
    if (i == 1 && !result) {  // not found, abort
      curwin->w_cursor = orig_pos;
      if (VIsual_active) {
        VIsual = save_VIsual;
      }
      return FAIL;
    } else if (i == 0 && !result) {
      if (forward) {  // try again from start of buffer
        clearpos(&pos);
      } else {  // try again from end of buffer
                // searching backwards, so set pos to last line and col
        pos.lnum = curwin->w_buffer->b_ml.ml_line_count;
        pos.col = ml_get_len(curwin->w_buffer->b_ml.ml_line_count);
      }
    }
  }

  pos_T start_pos = pos;

  if (!VIsual_active) {
    VIsual = start_pos;
  }

  // put the cursor after the match
  curwin->w_cursor = end_pos;
  if (lt(VIsual, end_pos) && forward) {
    if (skip_first_backward) {
      // put the cursor on the start of the match
      curwin->w_cursor = pos;
    } else {
      // put the cursor on last character of match
      dec_cursor();
    }
  } else if (VIsual_active && lt(curwin->w_cursor, VIsual) && forward) {
    curwin->w_cursor = pos;   // put the cursor on the start of the match
  }
  VIsual_active = true;
  VIsual_mode = 'v';

  if (*p_sel == 'e') {
    // Correction for exclusive selection depends on the direction.
    if (forward && ltoreq(VIsual, curwin->w_cursor)) {
      inc_cursor();
    } else if (!forward && ltoreq(curwin->w_cursor, VIsual)) {
      inc(&VIsual);
    }
  }

  if (fdo_flags & kOptFdoFlagSearch && KeyTyped) {
    foldOpenCursor();
  }

  may_start_select('c');
  setmouse();
  redraw_curbuf_later(UPD_INVERTED);
  showmode();

  return OK;
}

/// Check if the pattern is zero-width.
/// If move is true, check from the beginning of the buffer,
/// else from position "cur".
/// "direction" is FORWARD or BACKWARD.
/// Returns true, false or -1 for failure.
static int is_zero_width(char *pattern, size_t patternlen, bool move, pos_T *cur,
                         Direction direction)
{
  regmmatch_T regmatch;
  int result = -1;
  pos_T pos;
  const int called_emsg_before = called_emsg;
  int flag = 0;

  if (pattern == NULL) {
    pattern = spats[last_idx].pat;
    patternlen = spats[last_idx].patlen;
  }

  if (search_regcomp(pattern, patternlen, NULL, RE_SEARCH, RE_SEARCH,
                     SEARCH_KEEP, &regmatch) == FAIL) {
    return -1;
  }

  // init startcol correctly
  regmatch.startpos[0].col = -1;
  // move to match
  if (move) {
    clearpos(&pos);
  } else {
    pos = *cur;
    // accept a match at the cursor position
    flag = SEARCH_START;
  }
  if (searchit(curwin, curbuf, &pos, NULL, direction, pattern, patternlen, 1,
               SEARCH_KEEP + flag, RE_SEARCH, NULL) != FAIL) {
    int nmatched = 0;
    // Zero-width pattern should match somewhere, then we can check if
    // start and end are in the same position.
    do {
      regmatch.startpos[0].col++;
      nmatched = vim_regexec_multi(&regmatch, curwin, curbuf,
                                   pos.lnum, regmatch.startpos[0].col,
                                   NULL, NULL);
      if (nmatched != 0) {
        break;
      }
    } while (regmatch.regprog != NULL
             && direction == FORWARD
             ? regmatch.startpos[0].col < pos.col
             : regmatch.startpos[0].col > pos.col);

    if (called_emsg == called_emsg_before) {
      result = (nmatched != 0
                && regmatch.startpos[0].lnum == regmatch.endpos[0].lnum
                && regmatch.startpos[0].col == regmatch.endpos[0].col);
    }
  }

  vim_regfree(regmatch.regprog);
  return result;
}

/// @return  true if line 'lnum' is empty or has white chars only.
bool linewhite(linenr_T lnum)
{
  char *p = skipwhite(ml_get(lnum));
  return *p == NUL;
}

/// Add the search count "[3/19]" to "msgbuf".
/// See update_search_stat() for other arguments.
static void cmdline_search_stat(int dirc, pos_T *pos, pos_T *cursor_pos, bool show_top_bot_msg,
                                char *msgbuf, size_t msgbuflen, bool recompute, int maxcount,
                                int timeout)
{
  searchstat_T stat;

  update_search_stat(dirc, pos, cursor_pos, &stat, recompute, maxcount,
                     timeout);
  if (stat.cur <= 0) {
    return;
  }

  char t[SEARCH_STAT_BUF_LEN];
  size_t len;

  if (curwin->w_p_rl && *curwin->w_p_rlc == 's') {
    if (stat.incomplete == 1) {
      len = (size_t)vim_snprintf(t, SEARCH_STAT_BUF_LEN, "[?/??]");
    } else if (stat.cnt > maxcount && stat.cur > maxcount) {
      len = (size_t)vim_snprintf(t, SEARCH_STAT_BUF_LEN, "[>%d/>%d]",
                                 maxcount, maxcount);
    } else if (stat.cnt > maxcount) {
      len = (size_t)vim_snprintf(t, SEARCH_STAT_BUF_LEN, "[>%d/%d]",
                                 maxcount, stat.cur);
    } else {
      len = (size_t)vim_snprintf(t, SEARCH_STAT_BUF_LEN, "[%d/%d]",
                                 stat.cnt, stat.cur);
    }
  } else {
    if (stat.incomplete == 1) {
      len = (size_t)vim_snprintf(t, SEARCH_STAT_BUF_LEN, "[?/??]");
    } else if (stat.cnt > maxcount && stat.cur > maxcount) {
      len = (size_t)vim_snprintf(t, SEARCH_STAT_BUF_LEN, "[>%d/>%d]",
                                 maxcount, maxcount);
    } else if (stat.cnt > maxcount) {
      len = (size_t)vim_snprintf(t, SEARCH_STAT_BUF_LEN, "[%d/>%d]",
                                 stat.cur, maxcount);
    } else {
      len = (size_t)vim_snprintf(t, SEARCH_STAT_BUF_LEN, "[%d/%d]",
                                 stat.cur, stat.cnt);
    }
  }

  if (show_top_bot_msg && len + 2 < SEARCH_STAT_BUF_LEN) {
    memmove(t + 2, t, len);
    t[0] = 'W';
    t[1] = ' ';
    len += 2;
  }

  if (len > msgbuflen) {
    len = msgbuflen;
  }
  memmove(msgbuf + msgbuflen - len, t, len);

  if (dirc == '?' && stat.cur == maxcount + 1) {
    stat.cur = -1;
  }

  // keep the message even after redraw, but don't put in history
  msg_hist_off = true;
  msg_ext_set_kind("search_count");
  give_warning(msgbuf, false);
  msg_hist_off = false;
}

// Add the search count information to "stat".
// "stat" must not be NULL.
// When "recompute" is true always recompute the numbers.
// dirc == 0: don't find the next/previous match (only set the result to "stat")
// dirc == '/': find the next match
// dirc == '?': find the previous match
static void update_search_stat(int dirc, pos_T *pos, pos_T *cursor_pos, searchstat_T *stat,
                               bool recompute, int maxcount, int timeout)
{
  int save_ws = p_ws;
  bool wraparound = false;
  pos_T p = (*pos);
  static pos_T lastpos = { 0, 0, 0 };
  static int cur = 0;
  static int cnt = 0;
  static bool exact_match = false;
  static int incomplete = 0;
  static int last_maxcount = SEARCH_STAT_DEF_MAX_COUNT;
  static int chgtick = 0;
  static char *lastpat = NULL;
  static buf_T *lbuf = NULL;

  CLEAR_POINTER(stat);

  if (dirc == 0 && !recompute && !EMPTY_POS(lastpos)) {
    stat->cur = cur;
    stat->cnt = cnt;
    stat->exact_match = exact_match;
    stat->incomplete = incomplete;
    stat->last_maxcount = last_maxcount;
    return;
  }
  last_maxcount = maxcount;
  wraparound = ((dirc == '?' && lt(lastpos, p))
                || (dirc == '/' && lt(p, lastpos)));

  // If anything relevant changed the count has to be recomputed.
  // STRNICMP ignores case, but we should not ignore case.
  // Unfortunately, there is no STRNICMP function.
  // XXX: above comment should be "no MB_STRCMP function" ?
  if (!(chgtick == buf_get_changedtick(curbuf)
        && lastpat != NULL  // suppress clang/NULL passed as nonnull parameter
        && STRNICMP(lastpat, spats[last_idx].pat, strlen(lastpat)) == 0
        && strlen(lastpat) == strlen(spats[last_idx].pat)
        && equalpos(lastpos, *cursor_pos)
        && lbuf == curbuf)
      || wraparound || cur < 0 || (maxcount > 0 && cur > maxcount)
      || recompute) {
    cur = 0;
    cnt = 0;
    exact_match = false;
    incomplete = 0;
    clearpos(&lastpos);
    lbuf = curbuf;
  }

  // when searching backwards and having jumped to the first occurrence,
  // cur must remain greater than 1
  if (equalpos(lastpos, *cursor_pos) && !wraparound
      && (dirc == 0 || dirc == '/' ? cur < cnt : cur > 1)) {
    cur += dirc == 0 ? 0 : dirc == '/' ? 1 : -1;
  } else {
    proftime_T start;
    bool done_search = false;
    pos_T endpos = { 0, 0, 0 };
    p_ws = false;
    if (timeout > 0) {
      start = profile_setlimit(timeout);
    }
    while (!got_int && searchit(curwin, curbuf, &lastpos, &endpos,
                                FORWARD, NULL, 0, 1, SEARCH_KEEP, RE_LAST,
                                NULL) != FAIL) {
      done_search = true;
      // Stop after passing the time limit.
      if (timeout > 0 && profile_passed_limit(start)) {
        incomplete = 1;
        break;
      }
      cnt++;
      if (ltoreq(lastpos, p)) {
        cur = cnt;
        if (lt(p, endpos)) {
          exact_match = true;
        }
      }
      fast_breakcheck();
      if (maxcount > 0 && cnt > maxcount) {
        incomplete = 2;    // max count exceeded
        break;
      }
    }
    if (got_int) {
      cur = -1;  // abort
    }
    if (done_search) {
      xfree(lastpat);
      lastpat = xstrdup(spats[last_idx].pat);
      chgtick = (int)buf_get_changedtick(curbuf);
      lbuf = curbuf;
      lastpos = p;
    }
  }
  stat->cur = cur;
  stat->cnt = cnt;
  stat->exact_match = exact_match;
  stat->incomplete = incomplete;
  stat->last_maxcount = last_maxcount;
  p_ws = save_ws;
}

// "searchcount()" function
void f_searchcount(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  pos_T pos = curwin->w_cursor;
  char *pattern = NULL;
  int maxcount = SEARCH_STAT_DEF_MAX_COUNT;
  int timeout = SEARCH_STAT_DEF_TIMEOUT;
  bool recompute = true;
  searchstat_T stat;

  tv_dict_alloc_ret(rettv);

  if (shortmess(SHM_SEARCHCOUNT)) {  // 'shortmess' contains 'S' flag
    recompute = true;
  }

  if (argvars[0].v_type != VAR_UNKNOWN) {
    dict_T *dict;
    dictitem_T *di;
    bool error = false;

    if (tv_check_for_nonnull_dict_arg(argvars, 0) == FAIL) {
      return;
    }
    dict = argvars[0].vval.v_dict;
    di = tv_dict_find(dict, "timeout", -1);
    if (di != NULL) {
      timeout = (int)tv_get_number_chk(&di->di_tv, &error);
      if (error) {
        return;
      }
    }
    di = tv_dict_find(dict, "maxcount", -1);
    if (di != NULL) {
      maxcount = (int)tv_get_number_chk(&di->di_tv, &error);
      if (error) {
        return;
      }
    }
    di = tv_dict_find(dict, "recompute", -1);
    if (di != NULL) {
      recompute = tv_get_number_chk(&di->di_tv, &error);
      if (error) {
        return;
      }
    }
    di = tv_dict_find(dict, "pattern", -1);
    if (di != NULL) {
      pattern = (char *)tv_get_string_chk(&di->di_tv);
      if (pattern == NULL) {
        return;
      }
    }
    di = tv_dict_find(dict, "pos", -1);
    if (di != NULL) {
      if (di->di_tv.v_type != VAR_LIST) {
        semsg(_(e_invarg2), "pos");
        return;
      }
      if (tv_list_len(di->di_tv.vval.v_list) != 3) {
        semsg(_(e_invarg2), "List format should be [lnum, col, off]");
        return;
      }
      listitem_T *li = tv_list_find(di->di_tv.vval.v_list, 0);
      if (li != NULL) {
        pos.lnum = (linenr_T)tv_get_number_chk(TV_LIST_ITEM_TV(li), &error);
        if (error) {
          return;
        }
      }
      li = tv_list_find(di->di_tv.vval.v_list, 1);
      if (li != NULL) {
        pos.col = (colnr_T)tv_get_number_chk(TV_LIST_ITEM_TV(li), &error) - 1;
        if (error) {
          return;
        }
      }
      li = tv_list_find(di->di_tv.vval.v_list, 2);
      if (li != NULL) {
        pos.coladd = (colnr_T)tv_get_number_chk(TV_LIST_ITEM_TV(li), &error);
        if (error) {
          return;
        }
      }
    }
  }

  save_last_search_pattern();
  save_incsearch_state();
  if (pattern != NULL) {
    if (*pattern == NUL) {
      goto the_end;
    }
    xfree(spats[last_idx].pat);
    spats[last_idx].patlen = strlen(pattern);
    spats[last_idx].pat = xstrnsave(pattern, spats[last_idx].patlen);
  }
  if (spats[last_idx].pat == NULL || *spats[last_idx].pat == NUL) {
    goto the_end;  // the previous pattern was never defined
  }

  update_search_stat(0, &pos, &pos, &stat, recompute, maxcount, timeout);

  tv_dict_add_nr(rettv->vval.v_dict, S_LEN("current"), stat.cur);
  tv_dict_add_nr(rettv->vval.v_dict, S_LEN("total"), stat.cnt);
  tv_dict_add_nr(rettv->vval.v_dict, S_LEN("exact_match"), stat.exact_match);
  tv_dict_add_nr(rettv->vval.v_dict, S_LEN("incomplete"), stat.incomplete);
  tv_dict_add_nr(rettv->vval.v_dict, S_LEN("maxcount"), stat.last_maxcount);

the_end:
  restore_last_search_pattern();
  restore_incsearch_state();
}

/// Fuzzy string matching
///
/// Ported from the lib_fts library authored by Forrest Smith.
/// https://github.com/forrestthewoods/lib_fts/tree/master/code
///
/// The following blog describes the fuzzy matching algorithm:
/// https://www.forrestthewoods.com/blog/reverse_engineering_sublime_texts_fuzzy_match/
///
/// Each matching string is assigned a score. The following factors are checked:
///   - Matched letter
///   - Unmatched letter
///   - Consecutively matched letters
///   - Proximity to start
///   - Letter following a separator (space, underscore)
///   - Uppercase letter following lowercase (aka CamelCase)
///
/// Matched letters are good. Unmatched letters are bad. Matching near the start
/// is good. Matching the first letter in the middle of a phrase is good.
/// Matching the uppercase letters in camel case entries is good.
///
/// The score assigned for each factor is explained below.
/// File paths are different from file names. File extensions may be ignorable.
/// Single words care about consecutive matches but not separators or camel
/// case.
///   Score starts at 100
///   Matched letter: +0 points
///   Unmatched letter: -1 point
///   Consecutive match bonus: +15 points
///   First letter bonus: +15 points
///   Separator bonus: +30 points
///   Camel case bonus: +30 points
///   Unmatched leading letter: -5 points (max: -15)
///
/// There is some nuance to this. Scores don’t have an intrinsic meaning. The
/// score range isn’t 0 to 100. It’s roughly [50, 150]. Longer words have a
/// lower minimum score due to unmatched letter penalty. Longer search patterns
/// have a higher maximum score due to match bonuses.
///
/// Separator and camel case bonus is worth a LOT. Consecutive matches are worth
/// quite a bit.
///
/// There is a penalty if you DON’T match the first three letters. Which
/// effectively rewards matching near the start. However there’s no difference
/// in matching between the middle and end.
///
/// There is not an explicit bonus for an exact match. Unmatched letters receive
/// a penalty. So shorter strings and closer matches are worth more.
typedef struct {
  int idx;  ///< used for stable sort
  listitem_T *item;
  int score;
  list_T *lmatchpos;
} fuzzyItem_T;

/// bonus for adjacent matches; this is higher than SEPARATOR_BONUS so that
/// matching a whole word is preferred.
#define SEQUENTIAL_BONUS 40
/// bonus if match occurs after a path separator
#define PATH_SEPARATOR_BONUS 30
/// bonus if match occurs after a word separator
#define WORD_SEPARATOR_BONUS 25
/// bonus if match is uppercase and prev is lower
#define CAMEL_BONUS 30
/// bonus if the first letter is matched
#define FIRST_LETTER_BONUS 15
/// bonus if exact match
#define EXACT_MATCH_BONUS 100
/// bonus if case match when no ignorecase
#define CASE_MATCH_BONUS 25
/// penalty applied for every letter in str before the first match
#define LEADING_LETTER_PENALTY (-5)
/// maximum penalty for leading letters
#define MAX_LEADING_LETTER_PENALTY (-15)
/// penalty for every letter that doesn't match
#define UNMATCHED_LETTER_PENALTY (-1)
/// penalty for gap in matching positions (-2 * k)
#define GAP_PENALTY (-2)
/// Score for a string that doesn't fuzzy match the pattern
#define SCORE_NONE (-9999)

#define FUZZY_MATCH_RECURSION_LIMIT 10

/// Compute a score for a fuzzy matched string. The matching character locations
/// are in "matches".
static int fuzzy_match_compute_score(const char *const fuzpat, const char *const str,
                                     const int strSz, const uint32_t *const matches,
                                     const int numMatches)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  assert(numMatches > 0);  // suppress clang "result of operation is garbage"
  const char *p = str;
  uint32_t sidx = 0;
  bool is_exact_match = true;
  const char *const orig_fuzpat = fuzpat - numMatches;
  const char *curpat = orig_fuzpat;
  int pat_idx = 0;
  // Track consecutive camel case matches
  int consecutive_camel = 0;

  // Initialize score
  int score = 100;

  // Apply leading letter penalty
  int penalty = LEADING_LETTER_PENALTY * (int)matches[0];
  if (penalty < MAX_LEADING_LETTER_PENALTY) {
    penalty = MAX_LEADING_LETTER_PENALTY;
  }
  score += penalty;

  // Apply unmatched penalty
  const int unmatched = strSz - numMatches;
  score += UNMATCHED_LETTER_PENALTY * unmatched;

  // Apply ordering bonuses
  for (int i = 0; i < numMatches; i++) {
    const uint32_t currIdx = matches[i];
    bool is_camel = false;

    if (i > 0) {
      const uint32_t prevIdx = matches[i - 1];

      // Sequential
      if (currIdx == prevIdx + 1) {
        score += SEQUENTIAL_BONUS;
      } else {
        score += GAP_PENALTY * (int)(currIdx - prevIdx);
        // Reset consecutive camel count on gap
        consecutive_camel = 0;
      }
    }

    int curr;
    // Check for bonuses based on neighbor character value
    if (currIdx > 0) {
      // Camel case
      int neighbor = ' ';

      while (sidx < currIdx) {
        neighbor = utf_ptr2char(p);
        MB_PTR_ADV(p);
        sidx++;
      }
      curr = utf_ptr2char(p);

      // Enhanced camel case scoring
      if (mb_islower(neighbor) && mb_isupper(curr)) {
        score += CAMEL_BONUS * 2;  // Double the camel case bonus
        is_camel = true;
        consecutive_camel++;
        // Additional bonus for consecutive camel
        if (consecutive_camel > 1) {
          score += CAMEL_BONUS;
        }
      } else {
        consecutive_camel = 0;
      }

      // Bonus if the match follows a separator character
      if (neighbor == '/' || neighbor == '\\') {
        score += PATH_SEPARATOR_BONUS;
      } else if (neighbor == ' ' || neighbor == '_') {
        score += WORD_SEPARATOR_BONUS;
      }
    } else {
      // First letter
      score += FIRST_LETTER_BONUS;
      curr = utf_ptr2char(p);
    }

    // Case matching bonus
    if (mb_isalpha(curr)) {
      while (pat_idx < i && *curpat) {
        MB_PTR_ADV(curpat);
        pat_idx++;
      }

      if (curr == utf_ptr2char(curpat)) {
        score += CASE_MATCH_BONUS;
        // Extra bonus for exact case match in camel
        if (is_camel) {
          score += CASE_MATCH_BONUS / 2;
        }
      }
    }

    // Check exact match condition
    if (currIdx != (uint32_t)i) {
      is_exact_match = false;
    }
  }

  // Boost score for exact matches
  if (is_exact_match && numMatches == strSz) {
    score += EXACT_MATCH_BONUS;
  }

  return score;
}

/// Perform a recursive search for fuzzy matching "fuzpat" in "str".
/// @return the number of matching characters.
static int fuzzy_match_recursive(const char *fuzpat, const char *str, uint32_t strIdx,
                                 int *const outScore, const char *const strBegin, const int strLen,
                                 const uint32_t *const srcMatches, uint32_t *const matches,
                                 const int maxMatches, int nextMatch, int *const recursionCount)
  FUNC_ATTR_NONNULL_ARG(1, 2, 4, 5, 8, 11) FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Recursion params
  bool recursiveMatch = false;
  uint32_t bestRecursiveMatches[MAX_FUZZY_MATCHES];
  int bestRecursiveScore = 0;

  // Count recursions
  (*recursionCount)++;
  if (*recursionCount >= FUZZY_MATCH_RECURSION_LIMIT) {
    return 0;
  }

  // Detect end of strings
  if (*fuzpat == NUL || *str == NUL) {
    return 0;
  }

  // Loop through fuzpat and str looking for a match
  bool first_match = true;
  while (*fuzpat != NUL && *str != NUL) {
    const int c1 = utf_ptr2char(fuzpat);
    const int c2 = utf_ptr2char(str);

    // Found match
    if (mb_tolower(c1) == mb_tolower(c2)) {
      // Supplied matches buffer was too short
      if (nextMatch >= maxMatches) {
        return 0;
      }

      int recursiveScore = 0;
      uint32_t recursiveMatches[MAX_FUZZY_MATCHES];
      CLEAR_FIELD(recursiveMatches);

      // "Copy-on-Write" srcMatches into matches
      if (first_match && srcMatches != NULL) {
        memcpy(matches, srcMatches, (size_t)nextMatch * sizeof(srcMatches[0]));
        first_match = false;
      }

      // Recursive call that "skips" this match
      const char *const next_char = str + utfc_ptr2len(str);
      if (fuzzy_match_recursive(fuzpat, next_char, strIdx + 1, &recursiveScore, strBegin, strLen,
                                matches, recursiveMatches,
                                sizeof(recursiveMatches) / sizeof(recursiveMatches[0]), nextMatch,
                                recursionCount)) {
        // Pick best recursive score
        if (!recursiveMatch || recursiveScore > bestRecursiveScore) {
          memcpy(bestRecursiveMatches, recursiveMatches,
                 MAX_FUZZY_MATCHES * sizeof(recursiveMatches[0]));
          bestRecursiveScore = recursiveScore;
        }
        recursiveMatch = true;
      }

      // Advance
      matches[nextMatch++] = strIdx;
      MB_PTR_ADV(fuzpat);
    }
    MB_PTR_ADV(str);
    strIdx++;
  }

  // Determine if full fuzpat was matched
  const bool matched = *fuzpat == NUL;

  // Calculate score
  if (matched) {
    *outScore = fuzzy_match_compute_score(fuzpat, strBegin, strLen, matches, nextMatch);
  }

  // Return best result
  if (recursiveMatch && (!matched || bestRecursiveScore > *outScore)) {
    // Recursive score is better than "this"
    memcpy(matches, bestRecursiveMatches, (size_t)maxMatches * sizeof(matches[0]));
    *outScore = bestRecursiveScore;
    return nextMatch;
  } else if (matched) {
    return nextMatch;  // "this" score is better than recursive
  }

  return 0;  // no match
}

/// fuzzy_match()
///
/// Performs exhaustive search via recursion to find all possible matches and
/// match with highest score.
/// Scores values have no intrinsic meaning.  Possible score range is not
/// normalized and varies with pattern.
/// Recursion is limited internally (default=10) to prevent degenerate cases
/// (pat_arg="aaaaaa" str="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa").
/// Patterns are limited to MAX_FUZZY_MATCHES characters.
///
/// @return true if "pat_arg" matches "str". Also returns the match score in
/// "outScore" and the matching character positions in "matches".
bool fuzzy_match(char *const str, const char *const pat_arg, const bool matchseq,
                 int *const outScore, uint32_t *const matches, const int maxMatches)
  FUNC_ATTR_NONNULL_ALL
{
  const int len = mb_charlen(str);
  bool complete = false;
  int numMatches = 0;

  *outScore = 0;

  char *const save_pat = xstrdup(pat_arg);
  char *pat = save_pat;
  char *p = pat;

  // Try matching each word in "pat_arg" in "str"
  while (true) {
    if (matchseq) {
      complete = true;
    } else {
      // Extract one word from the pattern (separated by space)
      p = skipwhite(p);
      if (*p == NUL) {
        break;
      }
      pat = p;
      while (*p != NUL && !ascii_iswhite(utf_ptr2char(p))) {
        MB_PTR_ADV(p);
      }
      if (*p == NUL) {  // processed all the words
        complete = true;
      }
      *p = NUL;
    }

    int score = 0;
    int recursionCount = 0;
    const int matchCount
      = fuzzy_match_recursive(pat, str, 0, &score, str, len, NULL,
                              matches + numMatches,
                              maxMatches - numMatches, 0, &recursionCount);
    if (matchCount == 0) {
      numMatches = 0;
      break;
    }

    // Accumulate the match score and the number of matches
    *outScore += score;
    numMatches += matchCount;

    if (complete) {
      break;
    }

    // try matching the next word
    p++;
  }

  xfree(save_pat);
  return numMatches != 0;
}

/// Sort the fuzzy matches in the descending order of the match score.
/// For items with same score, retain the order using the index (stable sort)
static int fuzzy_match_item_compare(const void *const s1, const void *const s2)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  const int v1 = ((const fuzzyItem_T *)s1)->score;
  const int v2 = ((const fuzzyItem_T *)s2)->score;
  const int idx1 = ((const fuzzyItem_T *)s1)->idx;
  const int idx2 = ((const fuzzyItem_T *)s2)->idx;

  if (v1 == v2) {
    return idx1 == idx2 ? 0 : idx1 > idx2 ? 1 : -1;
  }
  return v1 > v2 ? -1 : 1;
}

/// Fuzzy search the string "str" in a list of "items" and return the matching
/// strings in "fmatchlist".
/// If "matchseq" is true, then for multi-word search strings, match all the
/// words in sequence.
/// If "items" is a list of strings, then search for "str" in the list.
/// If "items" is a list of dicts, then either use "key" to lookup the string
/// for each item or use "item_cb" Funcref function to get the string.
/// If "retmatchpos" is true, then return a list of positions where "str"
/// matches for each item.
static void fuzzy_match_in_list(list_T *const l, char *const str, const bool matchseq,
                                const char *const key, Callback *const item_cb,
                                const bool retmatchpos, list_T *const fmatchlist,
                                const int max_matches)
  FUNC_ATTR_NONNULL_ARG(2, 5, 7)
{
  int len = tv_list_len(l);
  if (len == 0) {
    return;
  }
  if (max_matches > 0 && len > max_matches) {
    len = max_matches;
  }

  fuzzyItem_T *const items = xcalloc((size_t)len, sizeof(fuzzyItem_T));
  int match_count = 0;
  uint32_t matches[MAX_FUZZY_MATCHES];

  // For all the string items in items, get the fuzzy matching score
  TV_LIST_ITER(l, li, {
    if (max_matches > 0 && match_count >= max_matches) {
      break;
    }

    char *itemstr = NULL;
    typval_T rettv;
    rettv.v_type = VAR_UNKNOWN;
    const typval_T *const tv = TV_LIST_ITEM_TV(li);
    if (tv->v_type == VAR_STRING) {  // list of strings
      itemstr = tv->vval.v_string;
    } else if (tv->v_type == VAR_DICT && (key != NULL || item_cb->type != kCallbackNone)) {
      // For a dict, either use the specified key to lookup the string or
      // use the specified callback function to get the string.
      if (key != NULL) {
        itemstr = tv_dict_get_string(tv->vval.v_dict, key, false);
      } else {
        typval_T argv[2];

        // Invoke the supplied callback (if any) to get the dict item
        tv->vval.v_dict->dv_refcount++;
        argv[0].v_type = VAR_DICT;
        argv[0].vval.v_dict = tv->vval.v_dict;
        argv[1].v_type = VAR_UNKNOWN;
        if (callback_call(item_cb, 1, argv, &rettv)) {
          if (rettv.v_type == VAR_STRING) {
            itemstr = rettv.vval.v_string;
          }
        }
        tv_dict_unref(tv->vval.v_dict);
      }
    }

    int score;
    if (itemstr != NULL && fuzzy_match(itemstr, str, matchseq, &score, matches,
                                       MAX_FUZZY_MATCHES)) {
      items[match_count].idx = (int)match_count;
      items[match_count].item = li;
      items[match_count].score = score;

      // Copy the list of matching positions in itemstr to a list, if
      // "retmatchpos" is set.
      if (retmatchpos) {
        items[match_count].lmatchpos = tv_list_alloc(kListLenMayKnow);
        int j = 0;
        const char *p = str;
        while (*p != NUL) {
          if (!ascii_iswhite(utf_ptr2char(p)) || matchseq) {
            tv_list_append_number(items[match_count].lmatchpos, matches[j]);
            j++;
          }
          MB_PTR_ADV(p);
        }
      }
      match_count++;
    }
    tv_clear(&rettv);
  });

  if (match_count > 0) {
    // Sort the list by the descending order of the match score
    qsort(items, (size_t)match_count, sizeof(fuzzyItem_T), fuzzy_match_item_compare);

    // For matchfuzzy(), return a list of matched strings.
    //          ['str1', 'str2', 'str3']
    // For matchfuzzypos(), return a list with three items.
    // The first item is a list of matched strings. The second item
    // is a list of lists where each list item is a list of matched
    // character positions. The third item is a list of matching scores.
    //      [['str1', 'str2', 'str3'], [[1, 3], [1, 3], [1, 3]]]
    list_T *retlist;
    if (retmatchpos) {
      const listitem_T *const li = tv_list_find(fmatchlist, 0);
      assert(li != NULL && TV_LIST_ITEM_TV(li)->vval.v_list != NULL);
      retlist = TV_LIST_ITEM_TV(li)->vval.v_list;
    } else {
      retlist = fmatchlist;
    }

    // Copy the matching strings with a valid score to the return list
    for (int i = 0; i < match_count; i++) {
      if (items[i].score == SCORE_NONE) {
        break;
      }
      tv_list_append_tv(retlist, TV_LIST_ITEM_TV(items[i].item));
    }

    // next copy the list of matching positions
    if (retmatchpos) {
      const listitem_T *li = tv_list_find(fmatchlist, -2);
      assert(li != NULL && TV_LIST_ITEM_TV(li)->vval.v_list != NULL);
      retlist = TV_LIST_ITEM_TV(li)->vval.v_list;

      for (int i = 0; i < match_count; i++) {
        if (items[i].score == SCORE_NONE) {
          break;
        }
        tv_list_append_list(retlist, items[i].lmatchpos);
      }

      // copy the matching scores
      li = tv_list_find(fmatchlist, -1);
      assert(li != NULL && TV_LIST_ITEM_TV(li)->vval.v_list != NULL);
      retlist = TV_LIST_ITEM_TV(li)->vval.v_list;
      for (int i = 0; i < match_count; i++) {
        if (items[i].score == SCORE_NONE) {
          break;
        }
        tv_list_append_number(retlist, items[i].score);
      }
    }
  }
  xfree(items);
}

/// Do fuzzy matching. Returns the list of matched strings in "rettv".
/// If "retmatchpos" is true, also returns the matching character positions.
static void do_fuzzymatch(const typval_T *const argvars, typval_T *const rettv,
                          const bool retmatchpos)
  FUNC_ATTR_NONNULL_ALL
{
  // validate and get the arguments
  if (argvars[0].v_type != VAR_LIST || argvars[0].vval.v_list == NULL) {
    semsg(_(e_listarg), retmatchpos ? "matchfuzzypos()" : "matchfuzzy()");
    return;
  }
  if (argvars[1].v_type != VAR_STRING || argvars[1].vval.v_string == NULL) {
    semsg(_(e_invarg2), tv_get_string(&argvars[1]));
    return;
  }

  Callback cb = CALLBACK_NONE;
  const char *key = NULL;
  bool matchseq = false;
  int max_matches = 0;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    if (tv_check_for_nonnull_dict_arg(argvars, 2) == FAIL) {
      return;
    }

    // To search a dict, either a callback function or a key can be
    // specified.
    dict_T *const d = argvars[2].vval.v_dict;
    const dictitem_T *di;
    if ((di = tv_dict_find(d, "key", -1)) != NULL) {
      if (di->di_tv.v_type != VAR_STRING || di->di_tv.vval.v_string == NULL
          || *di->di_tv.vval.v_string == NUL) {
        semsg(_(e_invarg2), tv_get_string(&di->di_tv));
        return;
      }
      key = tv_get_string(&di->di_tv);
    } else if (!tv_dict_get_callback(d, "text_cb", -1, &cb)) {
      semsg(_(e_invargval), "text_cb");
      return;
    }

    if ((di = tv_dict_find(d, "limit", -1)) != NULL) {
      if (di->di_tv.v_type != VAR_NUMBER) {
        semsg(_(e_invarg2), tv_get_string(&di->di_tv));
        return;
      }
      max_matches = (int)tv_get_number_chk(&di->di_tv, NULL);
    }

    if (tv_dict_find(d, "matchseq", -1) != NULL) {
      matchseq = true;
    }
  }

  // get the fuzzy matches
  tv_list_alloc_ret(rettv, retmatchpos ? 3 : kListLenUnknown);
  if (retmatchpos) {
    // For matchfuzzypos(), a list with three items are returned. First
    // item is a list of matching strings, the second item is a list of
    // lists with matching positions within each string and the third item
    // is the list of scores of the matches.
    tv_list_append_list(rettv->vval.v_list, tv_list_alloc(kListLenUnknown));
    tv_list_append_list(rettv->vval.v_list, tv_list_alloc(kListLenUnknown));
    tv_list_append_list(rettv->vval.v_list, tv_list_alloc(kListLenUnknown));
  }

  fuzzy_match_in_list(argvars[0].vval.v_list,
                      (char *)tv_get_string(&argvars[1]), matchseq, key,
                      &cb, retmatchpos, rettv->vval.v_list, max_matches);
  callback_free(&cb);
}

/// "matchfuzzy()" function
void f_matchfuzzy(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  do_fuzzymatch(argvars, rettv, false);
}

/// "matchfuzzypos()" function
void f_matchfuzzypos(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  do_fuzzymatch(argvars, rettv, true);
}

/// Same as fuzzy_match_item_compare() except for use with a string match
static int fuzzy_match_str_compare(const void *const s1, const void *const s2)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  const int v1 = ((fuzmatch_str_T *)s1)->score;
  const int v2 = ((fuzmatch_str_T *)s2)->score;
  const int idx1 = ((fuzmatch_str_T *)s1)->idx;
  const int idx2 = ((fuzmatch_str_T *)s2)->idx;

  if (v1 == v2) {
    return idx1 == idx2 ? 0 : idx1 > idx2 ? 1 : -1;
  } else {
    return v1 > v2 ? -1 : 1;
  }
}

/// Sort fuzzy matches by score
static void fuzzy_match_str_sort(fuzmatch_str_T *const fm, const int sz)
  FUNC_ATTR_NONNULL_ALL
{
  // Sort the list by the descending order of the match score
  qsort(fm, (size_t)sz, sizeof(fuzmatch_str_T), fuzzy_match_str_compare);
}

/// Same as fuzzy_match_item_compare() except for use with a function name
/// string match. <SNR> functions should be sorted to the end.
static int fuzzy_match_func_compare(const void *const s1, const void *const s2)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  const int v1 = ((fuzmatch_str_T *)s1)->score;
  const int v2 = ((fuzmatch_str_T *)s2)->score;
  const int idx1 = ((fuzmatch_str_T *)s1)->idx;
  const int idx2 = ((fuzmatch_str_T *)s2)->idx;
  const char *const str1 = ((fuzmatch_str_T *)s1)->str;
  const char *const str2 = ((fuzmatch_str_T *)s2)->str;

  if (*str1 != '<' && *str2 == '<') {
    return -1;
  }
  if (*str1 == '<' && *str2 != '<') {
    return 1;
  }
  if (v1 == v2) {
    return idx1 == idx2 ? 0 : idx1 > idx2 ? 1 : -1;
  }
  return v1 > v2 ? -1 : 1;
}

/// Sort fuzzy matches of function names by score.
/// <SNR> functions should be sorted to the end.
static void fuzzy_match_func_sort(fuzmatch_str_T *const fm, const int sz)
  FUNC_ATTR_NONNULL_ALL
{
  // Sort the list by the descending order of the match score
  qsort(fm, (size_t)sz, sizeof(fuzmatch_str_T), fuzzy_match_func_compare);
}

/// Fuzzy match "pat" in "str".
/// @returns 0 if there is no match. Otherwise, returns the match score.
int fuzzy_match_str(char *const str, const char *const pat)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (str == NULL || pat == NULL) {
    return 0;
  }

  int score = 0;
  uint32_t matchpos[MAX_FUZZY_MATCHES];
  fuzzy_match(str, pat, true, &score, matchpos, sizeof(matchpos) / sizeof(matchpos[0]));

  return score;
}

/// Fuzzy match the position of string "pat" in string "str".
/// @returns a dynamic array of matching positions. If there is no match, returns NULL.
garray_T *fuzzy_match_str_with_pos(char *const str, const char *const pat)
{
  if (str == NULL || pat == NULL) {
    return NULL;
  }

  garray_T *match_positions = xmalloc(sizeof(garray_T));
  ga_init(match_positions, sizeof(uint32_t), 10);

  unsigned matches[MAX_FUZZY_MATCHES];
  int score = 0;
  if (!fuzzy_match(str, pat, false, &score, matches, MAX_FUZZY_MATCHES)
      || score == 0) {
    ga_clear(match_positions);
    xfree(match_positions);
    return NULL;
  }

  int j = 0;
  for (const char *p = pat; *p != NUL; MB_PTR_ADV(p)) {
    if (!ascii_iswhite(utf_ptr2char(p))) {
      GA_APPEND(uint32_t, match_positions, matches[j]);
      j++;
    }
  }

  return match_positions;
}

/// Copy a list of fuzzy matches into a string list after sorting the matches by
/// the fuzzy score. Frees the memory allocated for "fuzmatch".
void fuzzymatches_to_strmatches(fuzmatch_str_T *const fuzmatch, char ***const matches,
                                const int count, const bool funcsort)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (count <= 0) {
    return;
  }

  *matches = xmalloc((size_t)count * sizeof(char *));

  // Sort the list by the descending order of the match score
  if (funcsort) {
    fuzzy_match_func_sort(fuzmatch, count);
  } else {
    fuzzy_match_str_sort(fuzmatch, count);
  }

  for (int i = 0; i < count; i++) {
    (*matches)[i] = fuzmatch[i].str;
  }
  xfree(fuzmatch);
}

/// Free a list of fuzzy string matches.
void fuzmatch_str_free(fuzmatch_str_T *const fuzmatch, int count)
{
  if (count <= 0 || fuzmatch == NULL) {
    return;
  }
  while (count--) {
    xfree(fuzmatch[count].str);
  }
  xfree(fuzmatch);
}

/// Get line "lnum" and copy it into "buf[LSIZE]".
/// The copy is made because the regexp may make the line invalid when using a
/// mark.
static char *get_line_and_copy(linenr_T lnum, char *buf)
{
  char *line = ml_get(lnum);
  xstrlcpy(buf, line, LSIZE);
  return buf;
}

/// Find identifiers or defines in included files.
/// If p_ic && compl_status_sol() then ptr must be in lowercase.
///
/// @param ptr            pointer to search pattern
/// @param dir            direction of expansion
/// @param len            length of search pattern
/// @param whole          match whole words only
/// @param skip_comments  don't match inside comments
/// @param type           Type of search; are we looking for a type? a macro?
/// @param action         What to do when we find it
/// @param start_lnum     first line to start searching
/// @param end_lnum       last line for searching
/// @param forceit        If true, always switch to the found path
void find_pattern_in_path(char *ptr, Direction dir, size_t len, bool whole, bool skip_comments,
                          int type, int count, int action, linenr_T start_lnum, linenr_T end_lnum,
                          int forceit)
{
  SearchedFile *files;                  // Stack of included files
  SearchedFile *bigger;                 // When we need more space
  int max_path_depth = 50;
  int match_count = 1;

  char *new_fname;
  char *curr_fname = curbuf->b_fname;
  char *prev_fname = NULL;
  int depth_displayed;                  // For type==CHECK_PATH
  char *p;
  bool define_matched;
  regmatch_T regmatch;
  regmatch_T incl_regmatch;
  regmatch_T def_regmatch;
  bool matched = false;
  bool did_show = false;
  bool found = false;
  int i;
  char *already = NULL;
  char *startp = NULL;
  win_T *curwin_save = NULL;
  const int l_g_do_tagpreview = g_do_tagpreview;

  regmatch.regprog = NULL;
  incl_regmatch.regprog = NULL;
  def_regmatch.regprog = NULL;

  char *file_line = xmalloc(LSIZE);

  if (type != CHECK_PATH && type != FIND_DEFINE
      // when CONT_SOL is set compare "ptr" with the beginning of the
      // line is faster than quote_meta/regcomp/regexec "ptr" -- Acevedo
      && !compl_status_sol()) {
    size_t patsize = len + 5;
    char *pat = xmalloc(patsize);
    assert(len <= INT_MAX);
    snprintf(pat, patsize, whole ? "\\<%.*s\\>" : "%.*s", (int)len, ptr);
    // ignore case according to p_ic, p_scs and pat
    regmatch.rm_ic = ignorecase(pat);
    regmatch.regprog = vim_regcomp(pat, magic_isset() ? RE_MAGIC : 0);
    xfree(pat);
    if (regmatch.regprog == NULL) {
      goto fpip_end;
    }
  }
  char *inc_opt = (*curbuf->b_p_inc == NUL) ? p_inc : curbuf->b_p_inc;
  if (*inc_opt != NUL) {
    incl_regmatch.regprog = vim_regcomp(inc_opt, magic_isset() ? RE_MAGIC : 0);
    if (incl_regmatch.regprog == NULL) {
      goto fpip_end;
    }
    incl_regmatch.rm_ic = false;        // don't ignore case in incl. pat.
  }
  if (type == FIND_DEFINE && (*curbuf->b_p_def != NUL || *p_def != NUL)) {
    def_regmatch.regprog = vim_regcomp(*curbuf->b_p_def == NUL ? p_def : curbuf->b_p_def,
                                       magic_isset() ? RE_MAGIC : 0);
    if (def_regmatch.regprog == NULL) {
      goto fpip_end;
    }
    def_regmatch.rm_ic = false;         // don't ignore case in define pat.
  }
  files = xcalloc((size_t)max_path_depth, sizeof(SearchedFile));
  int old_files = max_path_depth;
  int depth = depth_displayed = -1;

  end_lnum = MIN(end_lnum, curbuf->b_ml.ml_line_count);
  linenr_T lnum = MIN(start_lnum, end_lnum);  // do at least one line
  char *line = get_line_and_copy(lnum, file_line);

  while (true) {
    if (incl_regmatch.regprog != NULL
        && vim_regexec(&incl_regmatch, line, 0)) {
      char *p_fname = (curr_fname == curbuf->b_fname)
                      ? curbuf->b_ffname : curr_fname;

      if (inc_opt != NULL && strstr(inc_opt, "\\zs") != NULL) {
        // Use text from '\zs' to '\ze' (or end) of 'include'.
        new_fname = find_file_name_in_path(incl_regmatch.startp[0],
                                           (size_t)(incl_regmatch.endp[0]
                                                    - incl_regmatch.startp[0]),
                                           FNAME_EXP|FNAME_INCL|FNAME_REL,
                                           1, p_fname);
      } else {
        // Use text after match with 'include'.
        new_fname = file_name_in_line(incl_regmatch.endp[0], 0,
                                      FNAME_EXP|FNAME_INCL|FNAME_REL, 1, p_fname,
                                      NULL);
      }
      bool already_searched = false;
      if (new_fname != NULL) {
        // Check whether we have already searched in this file
        for (i = 0;; i++) {
          if (i == depth + 1) {
            i = old_files;
          }
          if (i == max_path_depth) {
            break;
          }
          if (path_full_compare(new_fname, files[i].name, true,
                                true) & kEqualFiles) {
            if (type != CHECK_PATH
                && action == ACTION_SHOW_ALL && files[i].matched) {
              msg_putchar('\n');  // cursor below last one
              if (!got_int) {  // don't display if 'q' typed at "--more--" message
                msg_home_replace(new_fname);
                msg_puts(_(" (includes previously listed match)"));
                prev_fname = NULL;
              }
            }
            XFREE_CLEAR(new_fname);
            already_searched = true;
            break;
          }
        }
      }

      if (type == CHECK_PATH && (action == ACTION_SHOW_ALL
                                 || (new_fname == NULL && !already_searched))) {
        if (did_show) {
          msg_putchar('\n');  // cursor below last one
        } else {
          gotocmdline(true);  // cursor at status line
          msg_puts_title(_("--- Included files "));
          if (action != ACTION_SHOW_ALL) {
            msg_puts_title(_("not found "));
          }
          msg_puts_title(_("in path ---\n"));
        }
        did_show = true;
        while (depth_displayed < depth && !got_int) {
          depth_displayed++;
          for (i = 0; i < depth_displayed; i++) {
            msg_puts("  ");
          }
          msg_home_replace(files[depth_displayed].name);
          msg_puts(" -->\n");
        }
        if (!got_int) {                     // don't display if 'q' typed
                                            // for "--more--" message
          for (i = 0; i <= depth_displayed; i++) {
            msg_puts("  ");
          }
          if (new_fname != NULL) {
            // using "new_fname" is more reliable, e.g., when
            // 'includeexpr' is set.
            msg_outtrans(new_fname, HLF_D, false);
          } else {
            // Isolate the file name.
            // Include the surrounding "" or <> if present.
            if (inc_opt != NULL
                && strstr(inc_opt, "\\zs") != NULL) {
              // pattern contains \zs, use the match
              p = incl_regmatch.startp[0];
              i = (int)(incl_regmatch.endp[0]
                        - incl_regmatch.startp[0]);
            } else {
              // find the file name after the end of the match
              for (p = incl_regmatch.endp[0];
                   *p && !vim_isfilec((uint8_t)(*p)); p++) {}
              for (i = 0; vim_isfilec((uint8_t)p[i]); i++) {}
            }

            if (i == 0) {
              // Nothing found, use the rest of the line.
              p = incl_regmatch.endp[0];
              i = (int)strlen(p);
            } else if (p > line) {
              // Avoid checking before the start of the line, can
              // happen if \zs appears in the regexp.
              if (p[-1] == '"' || p[-1] == '<') {
                p--;
                i++;
              }
              if (p[i] == '"' || p[i] == '>') {
                i++;
              }
            }
            char save_char = p[i];
            p[i] = NUL;
            msg_outtrans(p, HLF_D, false);
            p[i] = save_char;
          }

          if (new_fname == NULL && action == ACTION_SHOW_ALL) {
            if (already_searched) {
              msg_puts(_("  (Already listed)"));
            } else {
              msg_puts(_("  NOT FOUND"));
            }
          }
        }
      }

      if (new_fname != NULL) {
        // Push the new file onto the file stack
        if (depth + 1 == old_files) {
          bigger = xmalloc((size_t)max_path_depth * 2 * sizeof(SearchedFile));
          for (i = 0; i <= depth; i++) {
            bigger[i] = files[i];
          }
          for (i = depth + 1; i < old_files + max_path_depth; i++) {
            bigger[i].fp = NULL;
            bigger[i].name = NULL;
            bigger[i].lnum = 0;
            bigger[i].matched = false;
          }
          for (i = old_files; i < max_path_depth; i++) {
            bigger[i + max_path_depth] = files[i];
          }
          old_files += max_path_depth;
          max_path_depth *= 2;
          xfree(files);
          files = bigger;
        }
        if ((files[depth + 1].fp = os_fopen(new_fname, "r")) == NULL) {
          xfree(new_fname);
        } else {
          if (++depth == old_files) {
            // Something wrong. We will forget one of our already visited files
            // now.
            xfree(files[old_files].name);
            old_files++;
          }
          files[depth].name = curr_fname = new_fname;
          files[depth].lnum = 0;
          files[depth].matched = false;
          if (action == ACTION_EXPAND) {
            msg_hist_off = true;                // reset in msg_trunc()
            vim_snprintf(IObuff, IOSIZE,
                         _("Scanning included file: %s"),
                         new_fname);
            msg_trunc(IObuff, true, HLF_R);
          } else if (p_verbose >= 5) {
            verbose_enter();
            smsg(0, _("Searching included file %s"), new_fname);
            verbose_leave();
          }
        }
      }
    } else {
      // Check if the line is a define (type == FIND_DEFINE)
      p = line;
search_line:
      define_matched = false;
      if (def_regmatch.regprog != NULL
          && vim_regexec(&def_regmatch, line, 0)) {
        // Pattern must be first identifier after 'define', so skip
        // to that position before checking for match of pattern.  Also
        // don't let it match beyond the end of this identifier.
        p = def_regmatch.endp[0];
        while (*p && !vim_iswordc((uint8_t)(*p))) {
          p++;
        }
        define_matched = true;
      }

      // Look for a match.  Don't do this if we are looking for a
      // define and this line didn't match define_prog above.
      if (def_regmatch.regprog == NULL || define_matched) {
        if (define_matched || compl_status_sol()) {
          // compare the first "len" chars from "ptr"
          startp = skipwhite(p);
          if (p_ic) {
            matched = !mb_strnicmp(startp, ptr, len);
          } else {
            matched = !strncmp(startp, ptr, len);
          }
          if (matched && define_matched && whole
              && vim_iswordc((uint8_t)startp[len])) {
            matched = false;
          }
        } else if (regmatch.regprog != NULL
                   && vim_regexec(&regmatch, line, (colnr_T)(p - line))) {
          matched = true;
          startp = regmatch.startp[0];
          // Check if the line is not a comment line (unless we are
          // looking for a define).  A line starting with "# define"
          // is not considered to be a comment line.
          if (skip_comments) {
            if ((*line != '#'
                 || strncmp(skipwhite(line + 1), "define", 6) != 0)
                && get_leader_len(line, NULL, false, true)) {
              matched = false;
            }

            // Also check for a "/ *" or "/ /" before the match.
            // Skips lines like "int backwards;  / * normal index
            // * /" when looking for "normal".
            // Note: Doesn't skip "/ *" in comments.
            p = skipwhite(line);
            if (matched
                || (p[0] == '/' && p[1] == '*') || p[0] == '*') {
              for (p = line; *p && p < startp; p++) {
                if (matched
                    && p[0] == '/'
                    && (p[1] == '*' || p[1] == '/')) {
                  matched = false;
                  // After "//" all text is comment
                  if (p[1] == '/') {
                    break;
                  }
                  p++;
                } else if (!matched && p[0] == '*' && p[1] == '/') {
                  // Can find match after "* /".
                  matched = true;
                  p++;
                }
              }
            }
          }
        }
      }
    }
    if (matched) {
      if (action == ACTION_EXPAND) {
        bool cont_s_ipos = false;

        if (depth == -1 && lnum == curwin->w_cursor.lnum) {
          break;
        }
        found = true;
        char *aux = p = startp;
        if (compl_status_adding()) {
          p += ins_compl_len();
          if (vim_iswordp(p)) {
            goto exit_matched;
          }
          p = find_word_start(p);
        }
        p = find_word_end(p);
        i = (int)(p - aux);

        if (compl_status_adding() && i == ins_compl_len()) {
          // IOSIZE > compl_length, so the strncpy works
          strncpy(IObuff, aux, (size_t)i);  // NOLINT(runtime/printf)

          // Get the next line: when "depth" < 0  from the current
          // buffer, otherwise from the included file.  Jump to
          // exit_matched when past the last line.
          if (depth < 0) {
            if (lnum >= end_lnum) {
              goto exit_matched;
            }
            line = get_line_and_copy(++lnum, file_line);
          } else if (vim_fgets(line = file_line,
                               LSIZE, files[depth].fp)) {
            goto exit_matched;
          }

          // we read a line, set "already" to check this "line" later
          // if depth >= 0 we'll increase files[depth].lnum far
          // below  -- Acevedo
          already = aux = p = skipwhite(line);
          p = find_word_start(p);
          p = find_word_end(p);
          if (p > aux) {
            if (*aux != ')' && IObuff[i - 1] != TAB) {
              if (IObuff[i - 1] != ' ') {
                IObuff[i++] = ' ';
              }
              // IObuf =~ "\(\k\|\i\).* ", thus i >= 2
              if (p_js
                  && (IObuff[i - 2] == '.'
                      || IObuff[i - 2] == '?'
                      || IObuff[i - 2] == '!')) {
                IObuff[i++] = ' ';
              }
            }
            // copy as much as possible of the new word
            if (p - aux >= IOSIZE - i) {
              p = aux + IOSIZE - i - 1;
            }
            strncpy(IObuff + i, aux, (size_t)(p - aux));  // NOLINT(runtime/printf)
            i += (int)(p - aux);
            cont_s_ipos = true;
          }
          IObuff[i] = NUL;
          aux = IObuff;

          if (i == ins_compl_len()) {
            goto exit_matched;
          }
        }

        const int add_r = ins_compl_add_infercase(aux, i, p_ic,
                                                  curr_fname == curbuf->b_fname
                                                  ? NULL : curr_fname,
                                                  dir, cont_s_ipos);
        if (add_r == OK) {
          // if dir was BACKWARD then honor it just once
          dir = FORWARD;
        } else if (add_r == FAIL) {
          break;
        }
      } else if (action == ACTION_SHOW_ALL) {
        found = true;
        if (!did_show) {
          gotocmdline(true);                    // cursor at status line
        }
        if (curr_fname != prev_fname) {
          if (did_show) {
            msg_putchar('\n');                  // cursor below last one
          }
          if (!got_int) {             // don't display if 'q' typed
                                      // at "--more--" message
            msg_home_replace(curr_fname);
          }
          prev_fname = curr_fname;
        }
        did_show = true;
        if (!got_int) {
          show_pat_in_path(line, type, true, action,
                           (depth == -1) ? NULL : files[depth].fp,
                           (depth == -1) ? &lnum : &files[depth].lnum,
                           match_count++);
        }

        // Set matched flag for this file and all the ones that
        // include it
        for (i = 0; i <= depth; i++) {
          files[i].matched = true;
        }
      } else if (--count <= 0) {
        found = true;
        if (depth == -1 && lnum == curwin->w_cursor.lnum
            && l_g_do_tagpreview == 0) {
          emsg(_("E387: Match is on current line"));
        } else if (action == ACTION_SHOW) {
          show_pat_in_path(line, type, did_show, action,
                           (depth == -1) ? NULL : files[depth].fp,
                           (depth == -1) ? &lnum : &files[depth].lnum, 1);
          did_show = true;
        } else {
          // ":psearch" uses the preview window
          if (l_g_do_tagpreview != 0) {
            curwin_save = curwin;
            prepare_tagpreview(true);
          }
          if (action == ACTION_SPLIT) {
            if (win_split(0, 0) == FAIL) {
              break;
            }
            RESET_BINDING(curwin);
          }
          if (depth == -1) {
            // match in current file
            if (l_g_do_tagpreview != 0) {
              if (!win_valid(curwin_save)) {
                break;
              }
              if (!GETFILE_SUCCESS(getfile(curwin_save->w_buffer->b_fnum, NULL,
                                           NULL, true, lnum, forceit))) {
                break;    // failed to jump to file
              }
            } else {
              setpcmark();
            }
            curwin->w_cursor.lnum = lnum;
            check_cursor(curwin);
          } else {
            if (!GETFILE_SUCCESS(getfile(0, files[depth].name, NULL, true,
                                         files[depth].lnum, forceit))) {
              break;    // failed to jump to file
            }
            // autocommands may have changed the lnum, we don't
            // want that here
            curwin->w_cursor.lnum = files[depth].lnum;
          }
        }
        if (action != ACTION_SHOW) {
          curwin->w_cursor.col = (colnr_T)(startp - line);
          curwin->w_set_curswant = true;
        }

        if (l_g_do_tagpreview != 0
            && curwin != curwin_save && win_valid(curwin_save)) {
          // Return cursor to where we were
          validate_cursor(curwin);
          redraw_later(curwin, UPD_VALID);
          win_enter(curwin_save, true);
        }
        break;
      }
exit_matched:
      matched = false;
      // look for other matches in the rest of the line if we
      // are not at the end of it already
      if (def_regmatch.regprog == NULL
          && action == ACTION_EXPAND
          && !compl_status_sol()
          && *startp != NUL
          && *(startp + utfc_ptr2len(startp)) != NUL) {
        goto search_line;
      }
    }
    line_breakcheck();
    if (action == ACTION_EXPAND) {
      ins_compl_check_keys(30, false);
    }
    if (got_int || ins_compl_interrupted()) {
      break;
    }

    // Read the next line.  When reading an included file and encountering
    // end-of-file, close the file and continue in the file that included
    // it.
    while (depth >= 0 && !already
           && vim_fgets(line = file_line, LSIZE, files[depth].fp)) {
      fclose(files[depth].fp);
      old_files--;
      files[old_files].name = files[depth].name;
      files[old_files].matched = files[depth].matched;
      depth--;
      curr_fname = (depth == -1) ? curbuf->b_fname
                                 : files[depth].name;
      depth_displayed = MIN(depth_displayed, depth);
    }
    if (depth >= 0) {           // we could read the line
      files[depth].lnum++;
      // Remove any CR and LF from the line.
      i = (int)strlen(line);
      if (i > 0 && line[i - 1] == '\n') {
        line[--i] = NUL;
      }
      if (i > 0 && line[i - 1] == '\r') {
        line[--i] = NUL;
      }
    } else if (!already) {
      if (++lnum > end_lnum) {
        break;
      }
      line = get_line_and_copy(lnum, file_line);
    }
    already = NULL;
  }
  // End of big while (true) loop.

  // Close any files that are still open.
  for (i = 0; i <= depth; i++) {
    fclose(files[i].fp);
    xfree(files[i].name);
  }
  for (i = old_files; i < max_path_depth; i++) {
    xfree(files[i].name);
  }
  xfree(files);

  if (type == CHECK_PATH) {
    if (!did_show) {
      if (action != ACTION_SHOW_ALL) {
        msg(_("All included files were found"), 0);
      } else {
        msg(_("No included files"), 0);
      }
    }
  } else if (!found
             && action != ACTION_EXPAND) {
    if (got_int || ins_compl_interrupted()) {
      emsg(_(e_interr));
    } else if (type == FIND_DEFINE) {
      emsg(_("E388: Couldn't find definition"));
    } else {
      emsg(_("E389: Couldn't find pattern"));
    }
  }
  if (action == ACTION_SHOW || action == ACTION_SHOW_ALL) {
    msg_end();
  }

fpip_end:
  xfree(file_line);
  vim_regfree(regmatch.regprog);
  vim_regfree(incl_regmatch.regprog);
  vim_regfree(def_regmatch.regprog);
}

static void show_pat_in_path(char *line, int type, bool did_show, int action, FILE *fp,
                             linenr_T *lnum, int count)
  FUNC_ATTR_NONNULL_ARG(1, 6)
{
  if (did_show) {
    msg_putchar('\n');          // cursor below last one
  } else if (!msg_silent) {
    gotocmdline(true);          // cursor at status line
  }
  if (got_int) {                // 'q' typed at "--more--" message
    return;
  }
  size_t linelen = strlen(line);
  while (true) {
    char *p = line + linelen - 1;
    if (fp != NULL) {
      // We used fgets(), so get rid of newline at end
      if (p >= line && *p == '\n') {
        p--;
      }
      if (p >= line && *p == '\r') {
        p--;
      }
      *(p + 1) = NUL;
    }
    if (action == ACTION_SHOW_ALL) {
      snprintf(IObuff, IOSIZE, "%3d: ", count);  // Show match nr.
      msg_puts(IObuff);
      snprintf(IObuff, IOSIZE, "%4" PRIdLINENR, *lnum);  // Show line nr.
      // Highlight line numbers.
      msg_puts_hl(IObuff, HLF_N, false);
      msg_puts(" ");
    }
    msg_prt_line(line, false);

    // Definition continues until line that doesn't end with '\'
    if (got_int || type != FIND_DEFINE || p < line || *p != '\\') {
      break;
    }

    if (fp != NULL) {
      if (vim_fgets(line, LSIZE, fp)) {     // end of file
        break;
      }
      linelen = strlen(line);
      (*lnum)++;
    } else {
      if (++*lnum > curbuf->b_ml.ml_line_count) {
        break;
      }
      line = ml_get(*lnum);
      linelen = (size_t)ml_get_len(*lnum);
    }
    msg_putchar('\n');
  }
}

/// Get last search pattern
void get_search_pattern(SearchPattern *const pat)
{
  memcpy(pat, &(spats[0]), sizeof(spats[0]));
}

/// Get last substitute pattern
void get_substitute_pattern(SearchPattern *const pat)
{
  memcpy(pat, &(spats[1]), sizeof(spats[1]));
  CLEAR_FIELD(pat->off);
}

/// Set last search pattern
void set_search_pattern(const SearchPattern pat)
{
  free_spat(&spats[0]);
  memcpy(&(spats[0]), &pat, sizeof(spats[0]));
  set_vv_searchforward();
}

/// Set last substitute pattern
void set_substitute_pattern(const SearchPattern pat)
{
  free_spat(&spats[1]);
  memcpy(&(spats[1]), &pat, sizeof(spats[1]));
  CLEAR_FIELD(spats[1].off);
}

/// Set last used search pattern
///
/// @param[in]  is_substitute_pattern  If true set substitute pattern as last
///                                    used. Otherwise sets search pattern.
void set_last_used_pattern(const bool is_substitute_pattern)
{
  last_idx = (is_substitute_pattern ? 1 : 0);
}

/// Returns true if search pattern was the last used one
bool search_was_last_used(void)
{
  return last_idx == 0;
}
