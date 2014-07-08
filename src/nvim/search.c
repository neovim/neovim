/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */
/*
 * search.c: code for normal mode searching commands
 */

#include <string.h>

#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/search.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_getln.h"
#include "nvim/farsi.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/func_attr.h"
#include "nvim/getchar.h"
#include "nvim/indent.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/path.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/term.h"
#include "nvim/ui.h"
#include "nvim/window.h"


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "search.c.generated.h"
#endif
/*
 * This file contains various searching-related routines. These fall into
 * three groups:
 * 1. string searches (for /, ?, n, and N)
 * 2. character searches within a single line (for f, F, t, T, etc)
 * 3. "other" kinds of searches like the '%' command, and 'word' searches.
 */

/*
 * String searches
 *
 * The string search functions are divided into two levels:
 * lowest:  searchit(); uses a pos_T for starting position and found match.
 * Highest: do_search(); uses curwin->w_cursor; calls searchit().
 *
 * The last search pattern is remembered for repeating the same search.
 * This pattern is shared between the :g, :s, ? and / commands.
 * This is in search_regcomp().
 *
 * The actual string matching is done using a heavily modified version of
 * Henry Spencer's regular expression library.  See regexp.c.
 */

/* The offset for a search command is store in a soff struct */
/* Note: only spats[0].off is really used */
struct soffset {
  int dir;                      /* search direction, '/' or '?' */
  int line;                     /* search has line offset */
  int end;                      /* search set cursor at end */
  long off;                     /* line or char offset */
};

/* A search pattern and its attributes are stored in a spat struct */
struct spat {
  char_u          *pat;         /* the pattern (in allocated memory) or NULL */
  int magic;                    /* magicness of the pattern */
  int no_scs;                   /* no smartcase for this pattern */
  struct soffset off;
};

/*
 * Two search patterns are remembered: One for the :substitute command and
 * one for other searches.  last_idx points to the one that was used the last
 * time.
 */
static struct spat spats[2] =
{
  {NULL, TRUE, FALSE, {'/', 0, 0, 0L}},         /* last used search pat */
  {NULL, TRUE, FALSE, {'/', 0, 0, 0L}}          /* last used substitute pat */
};

static int last_idx = 0;        /* index in spats[] for RE_LAST */

/* copy of spats[], for keeping the search patterns while executing autocmds */
static struct spat saved_spats[2];
static int saved_last_idx = 0;
static int saved_no_hlsearch = 0;

static char_u       *mr_pattern = NULL; /* pattern used by search_regcomp() */
static int mr_pattern_alloced = FALSE;          /* mr_pattern was allocated */

/*
 * Type used by find_pattern_in_path() to remember which included files have
 * been searched already.
 */
typedef struct SearchedFile {
  FILE        *fp;              /* File pointer */
  char_u      *name;            /* Full name of file */
  linenr_T lnum;                /* Line we were up to in file */
  int matched;                  /* Found a match in this file */
} SearchedFile;

/*
 * translate search pattern for vim_regcomp()
 *
 * pat_save == RE_SEARCH: save pat in spats[RE_SEARCH].pat (normal search cmd)
 * pat_save == RE_SUBST: save pat in spats[RE_SUBST].pat (:substitute command)
 * pat_save == RE_BOTH: save pat in both patterns (:global command)
 * pat_use  == RE_SEARCH: use previous search pattern if "pat" is NULL
 * pat_use  == RE_SUBST: use previous substitute pattern if "pat" is NULL
 * pat_use  == RE_LAST: use last used pattern if "pat" is NULL
 * options & SEARCH_HIS: put search string in history
 * options & SEARCH_KEEP: keep previous search pattern
 *
 * returns FAIL if failed, OK otherwise.
 */
int 
search_regcomp (
    char_u *pat,
    int pat_save,
    int pat_use,
    int options,
    regmmatch_T *regmatch          /* return: pattern and ignore-case flag */
)
{
  int magic;
  int i;

  rc_did_emsg = FALSE;
  magic = p_magic;

  /*
   * If no pattern given, use a previously defined pattern.
   */
  if (pat == NULL || *pat == NUL) {
    if (pat_use == RE_LAST)
      i = last_idx;
    else
      i = pat_use;
    if (spats[i].pat == NULL) {         /* pattern was never defined */
      if (pat_use == RE_SUBST)
        EMSG(_(e_nopresub));
      else
        EMSG(_(e_noprevre));
      rc_did_emsg = TRUE;
      return FAIL;
    }
    pat = spats[i].pat;
    magic = spats[i].magic;
    no_smartcase = spats[i].no_scs;
  } else if (options & SEARCH_HIS)      /* put new pattern in history */
    add_to_history(HIST_SEARCH, pat, TRUE, NUL);

  if (mr_pattern_alloced) {
    free(mr_pattern);
    mr_pattern_alloced = FALSE;
  }

  if (curwin->w_p_rl && *curwin->w_p_rlc == 's') {
    mr_pattern = reverse_text(pat);
    mr_pattern_alloced = TRUE;
  } else
    mr_pattern = pat;

  /*
   * Save the currently used pattern in the appropriate place,
   * unless the pattern should not be remembered.
   */
  if (!(options & SEARCH_KEEP) && !cmdmod.keeppatterns) {
    /* search or global command */
    if (pat_save == RE_SEARCH || pat_save == RE_BOTH)
      save_re_pat(RE_SEARCH, pat, magic);
    /* substitute or global command */
    if (pat_save == RE_SUBST || pat_save == RE_BOTH)
      save_re_pat(RE_SUBST, pat, magic);
  }

  regmatch->rmm_ic = ignorecase(pat);
  regmatch->rmm_maxcol = 0;
  regmatch->regprog = vim_regcomp(pat, magic ? RE_MAGIC : 0);
  if (regmatch->regprog == NULL)
    return FAIL;
  return OK;
}

/*
 * Get search pattern used by search_regcomp().
 */
char_u *get_search_pat(void)
{
  return mr_pattern;
}

/*
 * Reverse text into allocated memory.
 * Returns the allocated string.
 *
 * TODO(philix): move reverse_text() to strings.c
 */
char_u *reverse_text(char_u *s) FUNC_ATTR_NONNULL_RET
{
  /*
   * Reverse the pattern.
   */
  size_t len = STRLEN(s);
  char_u *rev = xmalloc(len + 1);
  size_t rev_i = len;
  for (size_t s_i = 0; s_i < len; ++s_i) {
    if (has_mbyte) {
      int mb_len = (*mb_ptr2len)(s + s_i);
      rev_i -= mb_len;
      memmove(rev + rev_i, s + s_i, mb_len);
      s_i += mb_len - 1;
    } else
      rev[--rev_i] = s[s_i];
  }
  rev[len] = NUL;

  return rev;
}

static void save_re_pat(int idx, char_u *pat, int magic)
{
  if (spats[idx].pat != pat) {
    free(spats[idx].pat);
    spats[idx].pat = vim_strsave(pat);
    spats[idx].magic = magic;
    spats[idx].no_scs = no_smartcase;
    last_idx = idx;
    /* If 'hlsearch' set and search pat changed: need redraw. */
    if (p_hls)
      redraw_all_later(SOME_VALID);
    SET_NO_HLSEARCH(FALSE);
  }
}

/*
 * Save the search patterns, so they can be restored later.
 * Used before/after executing autocommands and user functions.
 */
static int save_level = 0;

void save_search_patterns(void)
{
  if (save_level++ == 0) {
    saved_spats[0] = spats[0];
    if (spats[0].pat != NULL)
      saved_spats[0].pat = vim_strsave(spats[0].pat);
    saved_spats[1] = spats[1];
    if (spats[1].pat != NULL)
      saved_spats[1].pat = vim_strsave(spats[1].pat);
    saved_last_idx = last_idx;
    saved_no_hlsearch = no_hlsearch;
  }
}

void restore_search_patterns(void)
{
  if (--save_level == 0) {
    free(spats[0].pat);
    spats[0] = saved_spats[0];
    set_vv_searchforward();
    free(spats[1].pat);
    spats[1] = saved_spats[1];
    last_idx = saved_last_idx;
    SET_NO_HLSEARCH(saved_no_hlsearch);
  }
}

#if defined(EXITFREE) || defined(PROTO)
void free_search_patterns(void)
{
  free(spats[0].pat);
  free(spats[1].pat);

  if (mr_pattern_alloced) {
    free(mr_pattern);
    mr_pattern_alloced = FALSE;
    mr_pattern = NULL;
  }
}

#endif

/*
 * Return TRUE when case should be ignored for search pattern "pat".
 * Uses the 'ignorecase' and 'smartcase' options.
 */
int ignorecase(char_u *pat)
{
  int ic = p_ic;

  if (ic && !no_smartcase && p_scs
      && !(ctrl_x_mode && curbuf->b_p_inf)
      )
    ic = !pat_has_uppercase(pat);
  no_smartcase = FALSE;

  return ic;
}

/*
 * Return TRUE if patter "pat" has an uppercase character.
 */
int pat_has_uppercase(char_u *pat)
{
  char_u *p = pat;

  while (*p != NUL) {
    int l;

    if (has_mbyte && (l = (*mb_ptr2len)(p)) > 1) {
      if (enc_utf8 && utf_isupper(utf_ptr2char(p)))
        return TRUE;
      p += l;
    } else if (*p == '\\') {
      if (p[1] == '_' && p[2] != NUL)        /* skip "\_X" */
        p += 3;
      else if (p[1] == '%' && p[2] != NUL)        /* skip "\%X" */
        p += 3;
      else if (p[1] != NUL)        /* skip "\X" */
        p += 2;
      else
        p += 1;
    } else if (vim_isupper(*p))
      return TRUE;
    else
      ++p;
  }
  return FALSE;
}

char_u *last_search_pat(void)
{
  return spats[last_idx].pat;
}

/*
 * Reset search direction to forward.  For "gd" and "gD" commands.
 */
void reset_search_dir(void)
{
  spats[0].off.dir = '/';
  set_vv_searchforward();
}

/*
 * Set the last search pattern.  For ":let @/ =" and viminfo.
 * Also set the saved search pattern, so that this works in an autocommand.
 */
void set_last_search_pat(const char_u *s, int idx, int magic, int setlast)
{
  free(spats[idx].pat);
  /* An empty string means that nothing should be matched. */
  if (*s == NUL)
    spats[idx].pat = NULL;
  else
    spats[idx].pat = (char_u *) xstrdup((char *) s);
  spats[idx].magic = magic;
  spats[idx].no_scs = FALSE;
  spats[idx].off.dir = '/';
  set_vv_searchforward();
  spats[idx].off.line = FALSE;
  spats[idx].off.end = FALSE;
  spats[idx].off.off = 0;
  if (setlast)
    last_idx = idx;
  if (save_level) {
    free(saved_spats[idx].pat);
    saved_spats[idx] = spats[0];
    if (spats[idx].pat == NULL)
      saved_spats[idx].pat = NULL;
    else
      saved_spats[idx].pat = vim_strsave(spats[idx].pat);
    saved_last_idx = last_idx;
  }
  /* If 'hlsearch' set and search pat changed: need redraw. */
  if (p_hls && idx == last_idx && !no_hlsearch)
    redraw_all_later(SOME_VALID);
}

/*
 * Get a regexp program for the last used search pattern.
 * This is used for highlighting all matches in a window.
 * Values returned in regmatch->regprog and regmatch->rmm_ic.
 */
void last_pat_prog(regmmatch_T *regmatch)
{
  if (spats[last_idx].pat == NULL) {
    regmatch->regprog = NULL;
    return;
  }
  ++emsg_off;           /* So it doesn't beep if bad expr */
  (void)search_regcomp((char_u *)"", 0, last_idx, SEARCH_KEEP, regmatch);
  --emsg_off;
}

/*
 * lowest level search function.
 * Search for 'count'th occurrence of pattern 'pat' in direction 'dir'.
 * Start at position 'pos' and return the found position in 'pos'.
 *
 * if (options & SEARCH_MSG) == 0 don't give any messages
 * if (options & SEARCH_MSG) == SEARCH_NFMSG don't give 'notfound' messages
 * if (options & SEARCH_MSG) == SEARCH_MSG give all messages
 * if (options & SEARCH_HIS) put search pattern in history
 * if (options & SEARCH_END) return position at end of match
 * if (options & SEARCH_START) accept match at pos itself
 * if (options & SEARCH_KEEP) keep previous search pattern
 * if (options & SEARCH_FOLD) match only once in a closed fold
 * if (options & SEARCH_PEEK) check for typed char, cancel search
 *
 * Return FAIL (zero) for failure, non-zero for success.
 * Returns the index of the first matching
 * subpattern plus one; one if there was none.
 */
int searchit(
    win_T       *win,               /* window to search in, can be NULL for a
                                       buffer without a window! */
    buf_T       *buf,
    pos_T       *pos,
    int dir,
    char_u      *pat,
    long count,
    int options,
    int pat_use,                    /* which pattern to use when "pat" is empty */
    linenr_T stop_lnum,             /* stop after this line number when != 0 */
    proftime_T  *tm          /* timeout limit or NULL */
)
{
  int found;
  linenr_T lnum;                /* no init to shut up Apollo cc */
  regmmatch_T regmatch;
  char_u      *ptr;
  colnr_T matchcol;
  lpos_T endpos;
  lpos_T matchpos;
  int loop;
  pos_T start_pos;
  int at_first_line;
  int extra_col;
  int match_ok;
  long nmatched;
  int submatch = 0;
  int save_called_emsg = called_emsg;
  int break_loop = FALSE;

  if (search_regcomp(pat, RE_SEARCH, pat_use,
          (options & (SEARCH_HIS + SEARCH_KEEP)), &regmatch) == FAIL) {
    if ((options & SEARCH_MSG) && !rc_did_emsg)
      EMSG2(_("E383: Invalid search string: %s"), mr_pattern);
    return FAIL;
  }

  /* When not accepting a match at the start position set "extra_col" to a
   * non-zero value.  Don't do that when starting at MAXCOL, since MAXCOL +
   * 1 is zero. */
  if ((options & SEARCH_START) || pos->col == MAXCOL)
    extra_col = 0;
  /* Watch out for the "col" being MAXCOL - 2, used in a closed fold. */
  else if (dir != BACKWARD && has_mbyte
           && pos->lnum >= 1 && pos->lnum <= buf->b_ml.ml_line_count
           && pos->col < MAXCOL - 2) {
    ptr = ml_get_buf(buf, pos->lnum, FALSE) + pos->col;
    if (*ptr == NUL)
      extra_col = 1;
    else
      extra_col = (*mb_ptr2len)(ptr);
  } else
    extra_col = 1;

  /*
   * find the string
   */
  called_emsg = FALSE;
  do {  /* loop for count */
    start_pos = *pos;           /* remember start pos for detecting no match */
    found = 0;                  /* default: not found */
    at_first_line = TRUE;       /* default: start in first line */
    if (pos->lnum == 0) {       /* correct lnum for when starting in line 0 */
      pos->lnum = 1;
      pos->col = 0;
      at_first_line = FALSE;        /* not in first line now */
    }

    /*
     * Start searching in current line, unless searching backwards and
     * we're in column 0.
     * If we are searching backwards, in column 0, and not including the
     * current position, gain some efficiency by skipping back a line.
     * Otherwise begin the search in the current line.
     */
    if (dir == BACKWARD && start_pos.col == 0
        && (options & SEARCH_START) == 0) {
      lnum = pos->lnum - 1;
      at_first_line = FALSE;
    } else
      lnum = pos->lnum;

    for (loop = 0; loop <= 1; ++loop) {     /* loop twice if 'wrapscan' set */
      for (; lnum > 0 && lnum <= buf->b_ml.ml_line_count;
           lnum += dir, at_first_line = FALSE) {
        /* Stop after checking "stop_lnum", if it's set. */
        if (stop_lnum != 0 && (dir == FORWARD
                               ? lnum > stop_lnum : lnum < stop_lnum))
          break;
        /* Stop after passing the "tm" time limit. */
        if (tm != NULL && profile_passed_limit(tm))
          break;

        /*
         * Look for a match somewhere in line "lnum".
         */
        nmatched = vim_regexec_multi(&regmatch, win, buf,
            lnum, (colnr_T)0,
            tm
            );
        /* Abort searching on an error (e.g., out of stack). */
        if (called_emsg)
          break;
        if (nmatched > 0) {
          /* match may actually be in another line when using \zs */
          matchpos = regmatch.startpos[0];
          endpos = regmatch.endpos[0];
          submatch = first_submatch(&regmatch);
          /* "lnum" may be past end of buffer for "\n\zs". */
          if (lnum + matchpos.lnum > buf->b_ml.ml_line_count)
            ptr = (char_u *)"";
          else
            ptr = ml_get_buf(buf, lnum + matchpos.lnum, FALSE);

          /*
           * Forward search in the first line: match should be after
           * the start position. If not, continue at the end of the
           * match (this is vi compatible) or on the next char.
           */
          if (dir == FORWARD && at_first_line) {
            match_ok = TRUE;
            /*
             * When the match starts in a next line it's certainly
             * past the start position.
             * When match lands on a NUL the cursor will be put
             * one back afterwards, compare with that position,
             * otherwise "/$" will get stuck on end of line.
             */
            while (matchpos.lnum == 0
                   && ((options & SEARCH_END)
                       ?  (nmatched == 1
                           && (int)endpos.col - 1
                           < (int)start_pos.col + extra_col)
                       : ((int)matchpos.col
                          - (ptr[matchpos.col] == NUL)
                          < (int)start_pos.col + extra_col))) {
              /*
               * If vi-compatible searching, continue at the end
               * of the match, otherwise continue one position
               * forward.
               */
              if (vim_strchr(p_cpo, CPO_SEARCH) != NULL) {
                if (nmatched > 1) {
                  /* end is in next line, thus no match in
                   * this line */
                  match_ok = FALSE;
                  break;
                }
                matchcol = endpos.col;
                /* for empty match: advance one char */
                if (matchcol == matchpos.col
                    && ptr[matchcol] != NUL) {
                  if (has_mbyte)
                    matchcol +=
                      (*mb_ptr2len)(ptr + matchcol);
                  else
                    ++matchcol;
                }
              } else {
                matchcol = matchpos.col;
                if (ptr[matchcol] != NUL) {
                  if (has_mbyte)
                    matchcol += (*mb_ptr2len)(ptr
                                              + matchcol);
                  else
                    ++matchcol;
                }
              }
              if (matchcol == 0 && (options & SEARCH_START))
                break;
              if (ptr[matchcol] == NUL
                  || (nmatched = vim_regexec_multi(&regmatch,
                          win, buf, lnum + matchpos.lnum,
                          matchcol,
                          tm
                          )) == 0) {
                match_ok = FALSE;
                break;
              }
              matchpos = regmatch.startpos[0];
              endpos = regmatch.endpos[0];
              submatch = first_submatch(&regmatch);

              /* Need to get the line pointer again, a
               * multi-line search may have made it invalid. */
              ptr = ml_get_buf(buf, lnum + matchpos.lnum, FALSE);
            }
            if (!match_ok)
              continue;
          }
          if (dir == BACKWARD) {
            /*
             * Now, if there are multiple matches on this line,
             * we have to get the last one. Or the last one before
             * the cursor, if we're on that line.
             * When putting the new cursor at the end, compare
             * relative to the end of the match.
             */
            match_ok = FALSE;
            for (;; ) {
              /* Remember a position that is before the start
               * position, we use it if it's the last match in
               * the line.  Always accept a position after
               * wrapping around. */
              if (loop
                  || ((options & SEARCH_END)
                      ? (lnum + regmatch.endpos[0].lnum
                         < start_pos.lnum
                         || (lnum + regmatch.endpos[0].lnum
                             == start_pos.lnum
                             && (int)regmatch.endpos[0].col - 1
                             + extra_col
                             <= (int)start_pos.col))
                      : (lnum + regmatch.startpos[0].lnum
                         < start_pos.lnum
                         || (lnum + regmatch.startpos[0].lnum
                             == start_pos.lnum
                             && (int)regmatch.startpos[0].col
                             + extra_col
                             <= (int)start_pos.col)))) {
                match_ok = TRUE;
                matchpos = regmatch.startpos[0];
                endpos = regmatch.endpos[0];
                submatch = first_submatch(&regmatch);
              } else
                break;

              /*
               * We found a valid match, now check if there is
               * another one after it.
               * If vi-compatible searching, continue at the end
               * of the match, otherwise continue one position
               * forward.
               */
              if (vim_strchr(p_cpo, CPO_SEARCH) != NULL) {
                if (nmatched > 1)
                  break;
                matchcol = endpos.col;
                /* for empty match: advance one char */
                if (matchcol == matchpos.col
                    && ptr[matchcol] != NUL) {
                  if (has_mbyte)
                    matchcol +=
                      (*mb_ptr2len)(ptr + matchcol);
                  else
                    ++matchcol;
                }
              } else {
                /* Stop when the match is in a next line. */
                if (matchpos.lnum > 0)
                  break;
                matchcol = matchpos.col;
                if (ptr[matchcol] != NUL) {
                  if (has_mbyte)
                    matchcol +=
                      (*mb_ptr2len)(ptr + matchcol);
                  else
                    ++matchcol;
                }
              }
              if (ptr[matchcol] == NUL
                  || (nmatched = vim_regexec_multi(&regmatch,
                          win, buf, lnum + matchpos.lnum,
                          matchcol,
                          tm
                          )) == 0)
                break;

              /* Need to get the line pointer again, a
               * multi-line search may have made it invalid. */
              ptr = ml_get_buf(buf, lnum + matchpos.lnum, FALSE);
            }

            /*
             * If there is only a match after the cursor, skip
             * this match.
             */
            if (!match_ok)
              continue;
          }

          /* With the SEARCH_END option move to the last character
           * of the match.  Don't do it for an empty match, end
           * should be same as start then. */
          if ((options & SEARCH_END) && !(options & SEARCH_NOOF)
              && !(matchpos.lnum == endpos.lnum
                   && matchpos.col == endpos.col)) {
            /* For a match in the first column, set the position
             * on the NUL in the previous line. */
            pos->lnum = lnum + endpos.lnum;
            pos->col = endpos.col;
            if (endpos.col == 0) {
              if (pos->lnum > 1) {              /* just in case */
                --pos->lnum;
                pos->col = (colnr_T)STRLEN(ml_get_buf(buf,
                        pos->lnum, FALSE));
              }
            } else {
              --pos->col;
              if (has_mbyte
                  && pos->lnum <= buf->b_ml.ml_line_count) {
                ptr = ml_get_buf(buf, pos->lnum, FALSE);
                pos->col -= (*mb_head_off)(ptr, ptr + pos->col);
              }
            }
          } else {
            pos->lnum = lnum + matchpos.lnum;
            pos->col = matchpos.col;
          }
          pos->coladd = 0;
          found = 1;

          /* Set variables used for 'incsearch' highlighting. */
          search_match_lines = endpos.lnum - matchpos.lnum;
          search_match_endcol = endpos.col;
          break;
        }
        line_breakcheck();              /* stop if ctrl-C typed */
        if (got_int)
          break;

        /* Cancel searching if a character was typed.  Used for
         * 'incsearch'.  Don't check too often, that would slowdown
         * searching too much. */
        if ((options & SEARCH_PEEK)
            && ((lnum - pos->lnum) & 0x3f) == 0
            && char_avail()) {
          break_loop = TRUE;
          break;
        }

        if (loop && lnum == start_pos.lnum)
          break;                    /* if second loop, stop where started */
      }
      at_first_line = FALSE;

      /*
       * Stop the search if wrapscan isn't set, "stop_lnum" is
       * specified, after an interrupt, after a match and after looping
       * twice.
       */
      if (!p_ws || stop_lnum != 0 || got_int || called_emsg
          || break_loop
          || found || loop)
        break;

      /*
       * If 'wrapscan' is set we continue at the other end of the file.
       * If 'shortmess' does not contain 's', we give a message.
       * This message is also remembered in keep_msg for when the screen
       * is redrawn. The keep_msg is cleared whenever another message is
       * written.
       */
      if (dir == BACKWARD)          /* start second loop at the other end */
        lnum = buf->b_ml.ml_line_count;
      else
        lnum = 1;
      if (!shortmess(SHM_SEARCH) && (options & SEARCH_MSG))
        give_warning((char_u *)_(dir == BACKWARD
                ? top_bot_msg : bot_top_msg), true);
    }
    if (got_int || called_emsg
        || break_loop
        )
      break;
  } while (--count > 0 && found);   /* stop after count matches or no match */

  vim_regfree(regmatch.regprog);

  called_emsg |= save_called_emsg;

  if (!found) {             /* did not find it */
    if (got_int)
      EMSG(_(e_interr));
    else if ((options & SEARCH_MSG) == SEARCH_MSG) {
      if (p_ws)
        EMSG2(_(e_patnotf2), mr_pattern);
      else if (lnum == 0)
        EMSG2(_("E384: search hit TOP without match for: %s"),
            mr_pattern);
      else
        EMSG2(_("E385: search hit BOTTOM without match for: %s"),
            mr_pattern);
    }
    return FAIL;
  }

  /* A pattern like "\n\zs" may go past the last line. */
  if (pos->lnum > buf->b_ml.ml_line_count) {
    pos->lnum = buf->b_ml.ml_line_count;
    pos->col = (int)STRLEN(ml_get_buf(buf, pos->lnum, FALSE));
    if (pos->col > 0)
      --pos->col;
  }

  return submatch + 1;
}

void set_search_direction(int cdir)
{
  spats[0].off.dir = cdir;
}

static void set_vv_searchforward(void)
{
  set_vim_var_nr(VV_SEARCHFORWARD, (long)(spats[0].off.dir == '/'));
}

/*
 * Return the number of the first subpat that matched.
 */
static int first_submatch(regmmatch_T *rp)
{
  int submatch;

  for (submatch = 1;; ++submatch) {
    if (rp->startpos[submatch].lnum >= 0)
      break;
    if (submatch == 9) {
      submatch = 0;
      break;
    }
  }
  return submatch;
}

/*
 * Highest level string search function.
 * Search for the 'count'th occurrence of pattern 'pat' in direction 'dirc'
 *		  If 'dirc' is 0: use previous dir.
 *    If 'pat' is NULL or empty : use previous string.
 *    If 'options & SEARCH_REV' : go in reverse of previous dir.
 *    If 'options & SEARCH_ECHO': echo the search command and handle options
 *    If 'options & SEARCH_MSG' : may give error message
 *    If 'options & SEARCH_OPT' : interpret optional flags
 *    If 'options & SEARCH_HIS' : put search pattern in history
 *    If 'options & SEARCH_NOOF': don't add offset to position
 *    If 'options & SEARCH_MARK': set previous context mark
 *    If 'options & SEARCH_KEEP': keep previous search pattern
 *    If 'options & SEARCH_START': accept match at curpos itself
 *    If 'options & SEARCH_PEEK': check for typed char, cancel search
 *
 * Careful: If spats[0].off.line == TRUE and spats[0].off.off == 0 this
 * makes the movement linewise without moving the match position.
 *
 * return 0 for failure, 1 for found, 2 for found and line offset added
 */
int do_search(
    oparg_T         *oap,           /* can be NULL */
    int dirc,                       /* '/' or '?' */
    char_u          *pat,
    long count,
    int options,
    proftime_T      *tm             /* timeout limit or NULL */
)
{
  pos_T pos;                    /* position of the last match */
  char_u          *searchstr;
  struct soffset old_off;
  int retval;                   /* Return value */
  char_u          *p;
  long c;
  char_u          *dircp;
  char_u          *strcopy = NULL;
  char_u          *ps;

  /*
   * A line offset is not remembered, this is vi compatible.
   */
  if (spats[0].off.line && vim_strchr(p_cpo, CPO_LINEOFF) != NULL) {
    spats[0].off.line = FALSE;
    spats[0].off.off = 0;
  }

  /*
   * Save the values for when (options & SEARCH_KEEP) is used.
   * (there is no "if ()" around this because gcc wants them initialized)
   */
  old_off = spats[0].off;

  pos = curwin->w_cursor;       /* start searching at the cursor position */

  /*
   * Find out the direction of the search.
   */
  if (dirc == 0)
    dirc = spats[0].off.dir;
  else {
    spats[0].off.dir = dirc;
    set_vv_searchforward();
  }
  if (options & SEARCH_REV) {
    if (dirc == '/')
      dirc = '?';
    else
      dirc = '/';
  }

  /* If the cursor is in a closed fold, don't find another match in the same
   * fold. */
  if (dirc == '/') {
    if (hasFolding(pos.lnum, NULL, &pos.lnum))
      pos.col = MAXCOL - 2;             /* avoid overflow when adding 1 */
  } else {
    if (hasFolding(pos.lnum, &pos.lnum, NULL))
      pos.col = 0;
  }

  /*
   * Turn 'hlsearch' highlighting back on.
   */
  if (no_hlsearch && !(options & SEARCH_KEEP)) {
    redraw_all_later(SOME_VALID);
    SET_NO_HLSEARCH(FALSE);
  }

  /*
   * Repeat the search when pattern followed by ';', e.g. "/foo/;?bar".
   */
  for (;; ) {
    searchstr = pat;
    dircp = NULL;
    /* use previous pattern */
    if (pat == NULL || *pat == NUL || *pat == dirc) {
      if (spats[RE_SEARCH].pat == NULL) {           /* no previous pattern */
        pat = spats[RE_SUBST].pat;
        if (pat == NULL) {
          EMSG(_(e_noprevre));
          retval = 0;
          goto end_do_search;
        }
        searchstr = pat;
      } else {
        /* make search_regcomp() use spats[RE_SEARCH].pat */
        searchstr = (char_u *)"";
      }
    }

    if (pat != NULL && *pat != NUL) {   /* look for (new) offset */
      /*
       * Find end of regular expression.
       * If there is a matching '/' or '?', toss it.
       */
      ps = strcopy;
      p = skip_regexp(pat, dirc, (int)p_magic, &strcopy);
      if (strcopy != ps) {
        /* made a copy of "pat" to change "\?" to "?" */
        searchcmdlen += (int)(STRLEN(pat) - STRLEN(strcopy));
        pat = strcopy;
        searchstr = strcopy;
      }
      if (*p == dirc) {
        dircp = p;              /* remember where we put the NUL */
        *p++ = NUL;
      }
      spats[0].off.line = FALSE;
      spats[0].off.end = FALSE;
      spats[0].off.off = 0;
      /*
       * Check for a line offset or a character offset.
       * For get_address (echo off) we don't check for a character
       * offset, because it is meaningless and the 's' could be a
       * substitute command.
       */
      if (*p == '+' || *p == '-' || VIM_ISDIGIT(*p))
        spats[0].off.line = TRUE;
      else if ((options & SEARCH_OPT) &&
               (*p == 'e' || *p == 's' || *p == 'b')) {
        if (*p == 'e')                  /* end */
          spats[0].off.end = SEARCH_END;
        ++p;
      }
      if (VIM_ISDIGIT(*p) || *p == '+' || *p == '-') {      /* got an offset */
        /* 'nr' or '+nr' or '-nr' */
        if (VIM_ISDIGIT(*p) || VIM_ISDIGIT(*(p + 1)))
          spats[0].off.off = atol((char *)p);
        else if (*p == '-')                 /* single '-' */
          spats[0].off.off = -1;
        else                                /* single '+' */
          spats[0].off.off = 1;
        ++p;
        while (VIM_ISDIGIT(*p))             /* skip number */
          ++p;
      }

      /* compute length of search command for get_address() */
      searchcmdlen += (int)(p - pat);

      pat = p;                              /* put pat after search command */
    }

    if ((options & SEARCH_ECHO) && messaging()
        && !cmd_silent && msg_silent == 0) {
      char_u      *msgbuf;
      char_u      *trunc;

      if (*searchstr == NUL)
        p = spats[last_idx].pat;
      else
        p = searchstr;
      msgbuf = xmalloc(STRLEN(p) + 40);
      {
        msgbuf[0] = dirc;
        if (enc_utf8 && utf_iscomposing(utf_ptr2char(p))) {
          /* Use a space to draw the composing char on. */
          msgbuf[1] = ' ';
          STRCPY(msgbuf + 2, p);
        } else
          STRCPY(msgbuf + 1, p);
        if (spats[0].off.line || spats[0].off.end || spats[0].off.off) {
          p = msgbuf + STRLEN(msgbuf);
          *p++ = dirc;
          if (spats[0].off.end)
            *p++ = 'e';
          else if (!spats[0].off.line)
            *p++ = 's';
          if (spats[0].off.off > 0 || spats[0].off.line)
            *p++ = '+';
          if (spats[0].off.off != 0 || spats[0].off.line)
            sprintf((char *)p, "%" PRId64, (int64_t)spats[0].off.off);
          else
            *p = NUL;
        }

        msg_start();
        trunc = msg_strtrunc(msgbuf, FALSE);

        /* The search pattern could be shown on the right in rightleft
         * mode, but the 'ruler' and 'showcmd' area use it too, thus
         * it would be blanked out again very soon.  Show it on the
         * left, but do reverse the text. */
        if (curwin->w_p_rl && *curwin->w_p_rlc == 's') {
          char_u *r = reverse_text(trunc != NULL ? trunc : msgbuf);
          free(trunc);
          trunc = r;
        }
        if (trunc != NULL) {
          msg_outtrans(trunc);
          free(trunc);
        } else
          msg_outtrans(msgbuf);
        msg_clr_eos();
        msg_check();
        free(msgbuf);

        gotocmdline(FALSE);
        out_flush();
        msg_nowait = TRUE;                  /* don't wait for this message */
      }
    }

    /*
     * If there is a character offset, subtract it from the current
     * position, so we don't get stuck at "?pat?e+2" or "/pat/s-2".
     * Skip this if pos.col is near MAXCOL (closed fold).
     * This is not done for a line offset, because then we would not be vi
     * compatible.
     */
    if (!spats[0].off.line && spats[0].off.off && pos.col < MAXCOL - 2) {
      if (spats[0].off.off > 0) {
        for (c = spats[0].off.off; c; --c)
          if (decl(&pos) == -1)
            break;
        if (c) {                        /* at start of buffer */
          pos.lnum = 0;                 /* allow lnum == 0 here */
          pos.col = MAXCOL;
        }
      } else {
        for (c = spats[0].off.off; c; ++c)
          if (incl(&pos) == -1)
            break;
        if (c) {                        /* at end of buffer */
          pos.lnum = curbuf->b_ml.ml_line_count + 1;
          pos.col = 0;
        }
      }
    }

    if (p_altkeymap && curwin->w_p_rl)
      lrFswap(searchstr,0);

    c = searchit(curwin, curbuf, &pos, dirc == '/' ? FORWARD : BACKWARD,
        searchstr, count, spats[0].off.end + (options &
                                              (SEARCH_KEEP + SEARCH_PEEK +
                                               SEARCH_HIS
                                               + SEARCH_MSG + SEARCH_START
                                               + ((pat != NULL && *pat ==
                                                   ';') ? 0 : SEARCH_NOOF))),
        RE_LAST, (linenr_T)0, tm);

    if (dircp != NULL)
      *dircp = dirc;            /* restore second '/' or '?' for normal_cmd() */
    if (c == FAIL) {
      retval = 0;
      goto end_do_search;
    }
    if (spats[0].off.end && oap != NULL)
      oap->inclusive = TRUE;        /* 'e' includes last character */

    retval = 1;                     /* pattern found */

    /*
     * Add character and/or line offset
     */
    if (!(options & SEARCH_NOOF) || (pat != NULL && *pat == ';')) {
      if (spats[0].off.line) {          /* Add the offset to the line number. */
        c = pos.lnum + spats[0].off.off;
        if (c < 1)
          pos.lnum = 1;
        else if (c > curbuf->b_ml.ml_line_count)
          pos.lnum = curbuf->b_ml.ml_line_count;
        else
          pos.lnum = c;
        pos.col = 0;

        retval = 2;                 /* pattern found, line offset added */
      } else if (pos.col < MAXCOL - 2) {      /* just in case */
        /* to the right, check for end of file */
        c = spats[0].off.off;
        if (c > 0) {
          while (c-- > 0)
            if (incl(&pos) == -1)
              break;
        }
        /* to the left, check for start of file */
        else {
          while (c++ < 0)
            if (decl(&pos) == -1)
              break;
        }
      }
    }

    /*
     * The search command can be followed by a ';' to do another search.
     * For example: "/pat/;/foo/+3;?bar"
     * This is like doing another search command, except:
     * - The remembered direction '/' or '?' is from the first search.
     * - When an error happens the cursor isn't moved at all.
     * Don't do this when called by get_address() (it handles ';' itself).
     */
    if (!(options & SEARCH_OPT) || pat == NULL || *pat != ';')
      break;

    dirc = *++pat;
    if (dirc != '?' && dirc != '/') {
      retval = 0;
      EMSG(_("E386: Expected '?' or '/'  after ';'"));
      goto end_do_search;
    }
    ++pat;
  }

  if (options & SEARCH_MARK)
    setpcmark();
  curwin->w_cursor = pos;
  curwin->w_set_curswant = TRUE;

end_do_search:
  if ((options & SEARCH_KEEP) || cmdmod.keeppatterns)
    spats[0].off = old_off;
  free(strcopy);

  return retval;
}

/*
 * search_for_exact_line(buf, pos, dir, pat)
 *
 * Search for a line starting with the given pattern (ignoring leading
 * white-space), starting from pos and going in direction dir.	pos will
 * contain the position of the match found.    Blank lines match only if
 * ADDING is set.  if p_ic is set then the pattern must be in lowercase.
 * Return OK for success, or FAIL if no line found.
 */
int search_for_exact_line(buf_T *buf, pos_T *pos, int dir, char_u *pat)
{
  linenr_T start = 0;
  char_u      *ptr;
  char_u      *p;

  if (buf->b_ml.ml_line_count == 0)
    return FAIL;
  for (;; ) {
    pos->lnum += dir;
    if (pos->lnum < 1) {
      if (p_ws) {
        pos->lnum = buf->b_ml.ml_line_count;
        if (!shortmess(SHM_SEARCH))
          give_warning((char_u *)_(top_bot_msg), true);
      } else {
        pos->lnum = 1;
        break;
      }
    } else if (pos->lnum > buf->b_ml.ml_line_count) {
      if (p_ws) {
        pos->lnum = 1;
        if (!shortmess(SHM_SEARCH))
          give_warning((char_u *)_(bot_top_msg), true);
      } else {
        pos->lnum = 1;
        break;
      }
    }
    if (pos->lnum == start)
      break;
    if (start == 0)
      start = pos->lnum;
    ptr = ml_get_buf(buf, pos->lnum, FALSE);
    p = skipwhite(ptr);
    pos->col = (colnr_T) (p - ptr);

    /* when adding lines the matching line may be empty but it is not
     * ignored because we are interested in the next line -- Acevedo */
    if ((compl_cont_status & CONT_ADDING)
        && !(compl_cont_status & CONT_SOL)) {
      if ((p_ic ? MB_STRICMP(p, pat) : STRCMP(p, pat)) == 0)
        return OK;
    } else if (*p != NUL) {   /* ignore empty lines */
      /* expanding lines or words */
      if ((p_ic ? MB_STRNICMP(p, pat, compl_length)
           : STRNCMP(p, pat, compl_length)) == 0)
        return OK;
    }
  }
  return FAIL;
}

/*
 * Character Searches
 */

/*
 * Search for a character in a line.  If "t_cmd" is FALSE, move to the
 * position of the character, otherwise move to just before the char.
 * Do this "cap->count1" times.
 * Return FAIL or OK.
 */
int searchc(cmdarg_T *cap, int t_cmd)
{
  int c = cap->nchar;                   /* char to search for */
  int dir = cap->arg;                   /* TRUE for searching forward */
  long count = cap->count1;                     /* repeat count */
  static int lastc = NUL;               /* last character searched for */
  static int lastcdir;                  /* last direction of character search */
  static int last_t_cmd;                /* last search t_cmd */
  int col;
  char_u              *p;
  int len;
  int stop = TRUE;
  static char_u bytes[MB_MAXBYTES + 1];
  static int bytelen = 1;               /* >1 for multi-byte char */

  if (c != NUL) {       /* normal search: remember args for repeat */
    if (!KeyStuffed) {      /* don't remember when redoing */
      lastc = c;
      lastcdir = dir;
      last_t_cmd = t_cmd;
      bytelen = (*mb_char2bytes)(c, bytes);
      if (cap->ncharC1 != 0) {
        bytelen += (*mb_char2bytes)(cap->ncharC1, bytes + bytelen);
        if (cap->ncharC2 != 0)
          bytelen += (*mb_char2bytes)(cap->ncharC2, bytes + bytelen);
      }
    }
  } else {            /* repeat previous search */
    if (lastc == NUL)
      return FAIL;
    if (dir)            /* repeat in opposite direction */
      dir = -lastcdir;
    else
      dir = lastcdir;
    t_cmd = last_t_cmd;
    c = lastc;
    /* For multi-byte re-use last bytes[] and bytelen. */

    /* Force a move of at least one char, so ";" and "," will move the
     * cursor, even if the cursor is right in front of char we are looking
     * at. */
    if (vim_strchr(p_cpo, CPO_SCOLON) == NULL && count == 1 && t_cmd)
      stop = FALSE;
  }

  if (dir == BACKWARD)
    cap->oap->inclusive = FALSE;
  else
    cap->oap->inclusive = TRUE;

  p = get_cursor_line_ptr();
  col = curwin->w_cursor.col;
  len = (int)STRLEN(p);

  while (count--) {
    if (has_mbyte) {
      for (;; ) {
        if (dir > 0) {
          col += (*mb_ptr2len)(p + col);
          if (col >= len)
            return FAIL;
        } else {
          if (col == 0)
            return FAIL;
          col -= (*mb_head_off)(p, p + col - 1) + 1;
        }
        if (bytelen == 1) {
          if (p[col] == c && stop)
            break;
        } else {
          if (memcmp(p + col, bytes, bytelen) == 0 && stop)
            break;
        }
        stop = TRUE;
      }
    } else {
      for (;; ) {
        if ((col += dir) < 0 || col >= len)
          return FAIL;
        if (p[col] == c && stop)
          break;
        stop = TRUE;
      }
    }
  }

  if (t_cmd) {
    /* backup to before the character (possibly double-byte) */
    col -= dir;
    if (has_mbyte) {
      if (dir < 0)
        /* Landed on the search char which is bytelen long */
        col += bytelen - 1;
      else
        /* To previous char, which may be multi-byte. */
        col -= (*mb_head_off)(p, p + col);
    }
  }
  curwin->w_cursor.col = col;

  return OK;
}

/*
 * "Other" Searches
 */

/*
 * findmatch - find the matching paren or brace
 *
 * Improvement over vi: Braces inside quotes are ignored.
 */
pos_T *findmatch(oparg_T *oap, int initc)
{
  return findmatchlimit(oap, initc, 0, 0);
}

/*
 * Return TRUE if the character before "linep[col]" equals "ch".
 * Return FALSE if "col" is zero.
 * Update "*prevcol" to the column of the previous character, unless "prevcol"
 * is NULL.
 * Handles multibyte string correctly.
 */
static int check_prevcol(char_u *linep, int col, int ch, int *prevcol)
{
  --col;
  if (col > 0 && has_mbyte)
    col -= (*mb_head_off)(linep, linep + col);
  if (prevcol)
    *prevcol = col;
  return (col >= 0 && linep[col] == ch) ? TRUE : FALSE;
}

/*
 * findmatchlimit -- find the matching paren or brace, if it exists within
 * maxtravel lines of here.  A maxtravel of 0 means search until falling off
 * the edge of the file.
 *
 * "initc" is the character to find a match for.  NUL means to find the
 * character at or after the cursor.
 *
 * flags: FM_BACKWARD	search backwards (when initc is '/', '*' or '#')
 *	  FM_FORWARD	search forwards (when initc is '/', '*' or '#')
 *	  FM_BLOCKSTOP	stop at start/end of block ({ or } in column 0)
 *	  FM_SKIPCOMM	skip comments (not implemented yet!)
 *
 * "oap" is only used to set oap->motion_type for a linewise motion, it be
 * NULL
 */

pos_T *findmatchlimit(oparg_T *oap, int initc, int flags, int maxtravel)
{
  static pos_T pos;                     /* current search position */
  int findc = 0;                        /* matching brace */
  int c;
  int count = 0;                        /* cumulative number of braces */
  int backwards = FALSE;                /* init for gcc */
  int inquote = FALSE;                  /* TRUE when inside quotes */
  char_u      *linep;                   /* pointer to current line */
  char_u      *ptr;
  int do_quotes;                        /* check for quotes in current line */
  int at_start;                         /* do_quotes value at start position */
  int hash_dir = 0;                     /* Direction searched for # things */
  int comment_dir = 0;                  /* Direction searched for comments */
  pos_T match_pos;                      /* Where last slash-star was found */
  int start_in_quotes;                  /* start position is in quotes */
  int traveled = 0;                     /* how far we've searched so far */
  int ignore_cend = FALSE;              /* ignore comment end */
  int cpo_match;                        /* vi compatible matching */
  int cpo_bsl;                          /* don't recognize backslashes */
  int match_escaped = 0;                /* search for escaped match */
  int dir;                              /* Direction to search */
  int comment_col = MAXCOL;             /* start of / / comment */
  int lispcomm = FALSE;                 /* inside of Lisp-style comment */
  int lisp = curbuf->b_p_lisp;           /* engage Lisp-specific hacks ;) */

  pos = curwin->w_cursor;
  pos.coladd = 0;
  linep = ml_get(pos.lnum);

  cpo_match = (vim_strchr(p_cpo, CPO_MATCH) != NULL);
  cpo_bsl = (vim_strchr(p_cpo, CPO_MATCHBSL) != NULL);

  /* Direction to search when initc is '/', '*' or '#' */
  if (flags & FM_BACKWARD)
    dir = BACKWARD;
  else if (flags & FM_FORWARD)
    dir = FORWARD;
  else
    dir = 0;

  /*
   * if initc given, look in the table for the matching character
   * '/' and '*' are special cases: look for start or end of comment.
   * When '/' is used, we ignore running backwards into a star-slash, for
   * "[*" command, we just want to find any comment.
   */
  if (initc == '/' || initc == '*') {
    comment_dir = dir;
    if (initc == '/')
      ignore_cend = TRUE;
    backwards = (dir == FORWARD) ? FALSE : TRUE;
    initc = NUL;
  } else if (initc != '#' && initc != NUL) {
    find_mps_values(&initc, &findc, &backwards, TRUE);
    if (findc == NUL)
      return NULL;
  }
  /*
   * Either initc is '#', or no initc was given and we need to look under the
   * cursor.
   */
  else {
    if (initc == '#') {
      hash_dir = dir;
    } else {
      /*
       * initc was not given, must look for something to match under
       * or near the cursor.
       * Only check for special things when 'cpo' doesn't have '%'.
       */
      if (!cpo_match) {
        /* Are we before or at #if, #else etc.? */
        ptr = skipwhite(linep);
        if (*ptr == '#' && pos.col <= (colnr_T)(ptr - linep)) {
          ptr = skipwhite(ptr + 1);
          if (   STRNCMP(ptr, "if", 2) == 0
                 || STRNCMP(ptr, "endif", 5) == 0
                 || STRNCMP(ptr, "el", 2) == 0)
            hash_dir = 1;
        }
        /* Are we on a comment? */
        else if (linep[pos.col] == '/') {
          if (linep[pos.col + 1] == '*') {
            comment_dir = FORWARD;
            backwards = FALSE;
            pos.col++;
          } else if (pos.col > 0 && linep[pos.col - 1] == '*') {
            comment_dir = BACKWARD;
            backwards = TRUE;
            pos.col--;
          }
        } else if (linep[pos.col] == '*') {
          if (linep[pos.col + 1] == '/') {
            comment_dir = BACKWARD;
            backwards = TRUE;
          } else if (pos.col > 0 && linep[pos.col - 1] == '/') {
            comment_dir = FORWARD;
            backwards = FALSE;
          }
        }
      }

      /*
       * If we are not on a comment or the # at the start of a line, then
       * look for brace anywhere on this line after the cursor.
       */
      if (!hash_dir && !comment_dir) {
        /*
         * Find the brace under or after the cursor.
         * If beyond the end of the line, use the last character in
         * the line.
         */
        if (linep[pos.col] == NUL && pos.col)
          --pos.col;
        for (;; ) {
          initc = PTR2CHAR(linep + pos.col);
          if (initc == NUL)
            break;

          find_mps_values(&initc, &findc, &backwards, FALSE);
          if (findc)
            break;
          pos.col += MB_PTR2LEN(linep + pos.col);
        }
        if (!findc) {
          /* no brace in the line, maybe use "  #if" then */
          if (!cpo_match && *skipwhite(linep) == '#')
            hash_dir = 1;
          else
            return NULL;
        } else if (!cpo_bsl) {
          int col, bslcnt = 0;

          /* Set "match_escaped" if there are an odd number of
           * backslashes. */
          for (col = pos.col; check_prevcol(linep, col, '\\', &col); )
            bslcnt++;
          match_escaped = (bslcnt & 1);
        }
      }
    }
    if (hash_dir) {
      /*
       * Look for matching #if, #else, #elif, or #endif
       */
      if (oap != NULL)
        oap->motion_type = MLINE;           /* Linewise for this case only */
      if (initc != '#') {
        ptr = skipwhite(skipwhite(linep) + 1);
        if (STRNCMP(ptr, "if", 2) == 0 || STRNCMP(ptr, "el", 2) == 0)
          hash_dir = 1;
        else if (STRNCMP(ptr, "endif", 5) == 0)
          hash_dir = -1;
        else
          return NULL;
      }
      pos.col = 0;
      while (!got_int) {
        if (hash_dir > 0) {
          if (pos.lnum == curbuf->b_ml.ml_line_count)
            break;
        } else if (pos.lnum == 1)
          break;
        pos.lnum += hash_dir;
        linep = ml_get(pos.lnum);
        line_breakcheck();              /* check for CTRL-C typed */
        ptr = skipwhite(linep);
        if (*ptr != '#')
          continue;
        pos.col = (colnr_T) (ptr - linep);
        ptr = skipwhite(ptr + 1);
        if (hash_dir > 0) {
          if (STRNCMP(ptr, "if", 2) == 0)
            count++;
          else if (STRNCMP(ptr, "el", 2) == 0) {
            if (count == 0)
              return &pos;
          } else if (STRNCMP(ptr, "endif", 5) == 0) {
            if (count == 0)
              return &pos;
            count--;
          }
        } else {
          if (STRNCMP(ptr, "if", 2) == 0) {
            if (count == 0)
              return &pos;
            count--;
          } else if (initc == '#' && STRNCMP(ptr, "el", 2) == 0) {
            if (count == 0)
              return &pos;
          } else if (STRNCMP(ptr, "endif", 5) == 0)
            count++;
        }
      }
      return NULL;
    }
  }

  /* This is just guessing: when 'rightleft' is set, search for a matching
   * paren/brace in the other direction. */
  if (curwin->w_p_rl && vim_strchr((char_u *)"()[]{}<>", initc) != NULL)
    backwards = !backwards;

  do_quotes = -1;
  start_in_quotes = MAYBE;
  clearpos(&match_pos);

  /* backward search: Check if this line contains a single-line comment */
  if ((backwards && comment_dir)
      || lisp
      )
    comment_col = check_linecomment(linep);
  if (lisp && comment_col != MAXCOL && pos.col > (colnr_T)comment_col)
    lispcomm = TRUE;        /* find match inside this comment */
  while (!got_int) {
    /*
     * Go to the next position, forward or backward. We could use
     * inc() and dec() here, but that is much slower
     */
    if (backwards) {
      /* char to match is inside of comment, don't search outside */
      if (lispcomm && pos.col < (colnr_T)comment_col)
        break;
      if (pos.col == 0) {               /* at start of line, go to prev. one */
        if (pos.lnum == 1)              /* start of file */
          break;
        --pos.lnum;

        if (maxtravel > 0 && ++traveled > maxtravel)
          break;

        linep = ml_get(pos.lnum);
        pos.col = (colnr_T)STRLEN(linep);         /* pos.col on trailing NUL */
        do_quotes = -1;
        line_breakcheck();

        /* Check if this line contains a single-line comment */
        if (comment_dir
            || lisp
            )
          comment_col = check_linecomment(linep);
        /* skip comment */
        if (lisp && comment_col != MAXCOL)
          pos.col = comment_col;
      } else {
        --pos.col;
        if (has_mbyte)
          pos.col -= (*mb_head_off)(linep, linep + pos.col);
      }
    } else {                          /* forward search */
      if (linep[pos.col] == NUL
          /* at end of line, go to next one */
          /* don't search for match in comment */
          || (lisp && comment_col != MAXCOL
              && pos.col == (colnr_T)comment_col)
          ) {
        if (pos.lnum == curbuf->b_ml.ml_line_count          /* end of file */
            /* line is exhausted and comment with it,
             * don't search for match in code */
            || lispcomm
            )
          break;
        ++pos.lnum;

        if (maxtravel && traveled++ > maxtravel)
          break;

        linep = ml_get(pos.lnum);
        pos.col = 0;
        do_quotes = -1;
        line_breakcheck();
        if (lisp)           /* find comment pos in new line */
          comment_col = check_linecomment(linep);
      } else {
        if (has_mbyte)
          pos.col += (*mb_ptr2len)(linep + pos.col);
        else
          ++pos.col;
      }
    }

    /*
     * If FM_BLOCKSTOP given, stop at a '{' or '}' in column 0.
     */
    if (pos.col == 0 && (flags & FM_BLOCKSTOP) &&
        (linep[0] == '{' || linep[0] == '}')) {
      if (linep[0] == findc && count == 0)              /* match! */
        return &pos;
      break;                                            /* out of scope */
    }

    if (comment_dir) {
      /* Note: comments do not nest, and we ignore quotes in them */
      /* TODO: ignore comment brackets inside strings */
      if (comment_dir == FORWARD) {
        if (linep[pos.col] == '*' && linep[pos.col + 1] == '/') {
          pos.col++;
          return &pos;
        }
      } else {    /* Searching backwards */
        /*
         * A comment may contain / * or / /, it may also start or end
         * with / * /.	Ignore a / * after / /.
         */
        if (pos.col == 0)
          continue;
        else if (  linep[pos.col - 1] == '/'
                   && linep[pos.col] == '*'
                   && (int)pos.col < comment_col) {
          count++;
          match_pos = pos;
          match_pos.col--;
        } else if (linep[pos.col - 1] == '*' && linep[pos.col] == '/') {
          if (count > 0)
            pos = match_pos;
          else if (pos.col > 1 && linep[pos.col - 2] == '/'
                   && (int)pos.col <= comment_col)
            pos.col -= 2;
          else if (ignore_cend)
            continue;
          else
            return NULL;
          return &pos;
        }
      }
      continue;
    }

    /*
     * If smart matching ('cpoptions' does not contain '%'), braces inside
     * of quotes are ignored, but only if there is an even number of
     * quotes in the line.
     */
    if (cpo_match)
      do_quotes = 0;
    else if (do_quotes == -1) {
      /*
       * Count the number of quotes in the line, skipping \" and '"'.
       * Watch out for "\\".
       */
      at_start = do_quotes;
      for (ptr = linep; *ptr; ++ptr) {
        if (ptr == linep + pos.col + backwards)
          at_start = (do_quotes & 1);
        if (*ptr == '"'
            && (ptr == linep || ptr[-1] != '\'' || ptr[1] != '\''))
          ++do_quotes;
        if (*ptr == '\\' && ptr[1] != NUL)
          ++ptr;
      }
      do_quotes &= 1;               /* result is 1 with even number of quotes */

      /*
       * If we find an uneven count, check current line and previous
       * one for a '\' at the end.
       */
      if (!do_quotes) {
        inquote = FALSE;
        if (ptr[-1] == '\\') {
          do_quotes = 1;
          if (start_in_quotes == MAYBE) {
            /* Do we need to use at_start here? */
            inquote = TRUE;
            start_in_quotes = TRUE;
          } else if (backwards)
            inquote = TRUE;
        }
        if (pos.lnum > 1) {
          ptr = ml_get(pos.lnum - 1);
          if (*ptr && *(ptr + STRLEN(ptr) - 1) == '\\') {
            do_quotes = 1;
            if (start_in_quotes == MAYBE) {
              inquote = at_start;
              if (inquote)
                start_in_quotes = TRUE;
            } else if (!backwards)
              inquote = TRUE;
          }

          /* ml_get() only keeps one line, need to get linep again */
          linep = ml_get(pos.lnum);
        }
      }
    }
    if (start_in_quotes == MAYBE)
      start_in_quotes = FALSE;

    /*
     * If 'smartmatch' is set:
     *   Things inside quotes are ignored by setting 'inquote'.  If we
     *   find a quote without a preceding '\' invert 'inquote'.  At the
     *   end of a line not ending in '\' we reset 'inquote'.
     *
     *   In lines with an uneven number of quotes (without preceding '\')
     *   we do not know which part to ignore. Therefore we only set
     *   inquote if the number of quotes in a line is even, unless this
     *   line or the previous one ends in a '\'.  Complicated, isn't it?
     */
    c = PTR2CHAR(linep + pos.col);
    switch (c) {
    case NUL:
      /* at end of line without trailing backslash, reset inquote */
      if (pos.col == 0 || linep[pos.col - 1] != '\\') {
        inquote = FALSE;
        start_in_quotes = FALSE;
      }
      break;

    case '"':
      /* a quote that is preceded with an odd number of backslashes is
       * ignored */
      if (do_quotes) {
        int col;

        for (col = pos.col - 1; col >= 0; --col)
          if (linep[col] != '\\')
            break;
        if ((((int)pos.col - 1 - col) & 1) == 0) {
          inquote = !inquote;
          start_in_quotes = FALSE;
        }
      }
      break;

    /*
     * If smart matching ('cpoptions' does not contain '%'):
     *   Skip things in single quotes: 'x' or '\x'.  Be careful for single
     *   single quotes, eg jon's.  Things like '\233' or '\x3f' are not
     *   skipped, there is never a brace in them.
     *   Ignore this when finding matches for `'.
     */
    case '\'':
      if (!cpo_match && initc != '\'' && findc != '\'') {
        if (backwards) {
          if (pos.col > 1) {
            if (linep[pos.col - 2] == '\'') {
              pos.col -= 2;
              break;
            } else if (linep[pos.col - 2] == '\\' &&
                       pos.col > 2 && linep[pos.col - 3] == '\'') {
              pos.col -= 3;
              break;
            }
          }
        } else if (linep[pos.col + 1]) {      /* forward search */
          if (linep[pos.col + 1] == '\\' &&
              linep[pos.col + 2] && linep[pos.col + 3] == '\'') {
            pos.col += 3;
            break;
          } else if (linep[pos.col + 2] == '\'') {
            pos.col += 2;
            break;
          }
        }
      }
    /* FALLTHROUGH */

    default:
      /*
       * For Lisp skip over backslashed (), {} and [].
       * (actually, we skip #\( et al)
       */
      if (curbuf->b_p_lisp
          && vim_strchr((char_u *)"(){}[]", c) != NULL
          && pos.col > 1
          && check_prevcol(linep, pos.col, '\\', NULL)
          && check_prevcol(linep, pos.col - 1, '#', NULL))
        break;

      /* Check for match outside of quotes, and inside of
       * quotes when the start is also inside of quotes. */
      if ((!inquote || start_in_quotes == TRUE)
          && (c == initc || c == findc)) {
        int col, bslcnt = 0;

        if (!cpo_bsl) {
          for (col = pos.col; check_prevcol(linep, col, '\\', &col); )
            bslcnt++;
        }
        /* Only accept a match when 'M' is in 'cpo' or when escaping
         * is what we expect. */
        if (cpo_bsl || (bslcnt & 1) == match_escaped) {
          if (c == initc)
            count++;
          else {
            if (count == 0)
              return &pos;
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
  return (pos_T *)NULL;         /* never found it */
}

/*
 * Check if line[] contains a / / comment.
 * Return MAXCOL if not, otherwise return the column.
 * TODO: skip strings.
 */
static int check_linecomment(char_u *line)
{
  char_u  *p;

  p = line;
  /* skip Lispish one-line comments */
  if (curbuf->b_p_lisp) {
    if (vim_strchr(p, ';') != NULL) {   /* there may be comments */
      int in_str = FALSE;       /* inside of string */

      p = line;                 /* scan from start */
      while ((p = vim_strpbrk(p, (char_u *)"\";")) != NULL) {
        if (*p == '"') {
          if (in_str) {
            if (*(p - 1) != '\\')             /* skip escaped quote */
              in_str = FALSE;
          } else if (p == line || ((p - line) >= 2
                                   /* skip #\" form */
                                   && *(p - 1) != '\\' && *(p - 2) != '#'))
            in_str = TRUE;
        } else if (!in_str && ((p - line) < 2
                               || (*(p - 1) != '\\' && *(p - 2) != '#')))
          break;                /* found! */
        ++p;
      }
    } else
      p = NULL;
  } else
    while ((p = vim_strchr(p, '/')) != NULL) {
      /* accept a double /, unless it's preceded with * and followed by *,
       * because * / / * is an end and start of a C comment */
      if (p[1] == '/' && (p == line || p[-1] != '*' || p[2] != '*'))
        break;
      ++p;
    }

  if (p == NULL)
    return MAXCOL;
  return (int)(p - line);
}

/*
 * Move cursor briefly to character matching the one under the cursor.
 * Used for Insert mode and "r" command.
 * Show the match only if it is visible on the screen.
 * If there isn't a match, then beep.
 */
void 
showmatch (
    int c                      /* char to show match for */
)
{
  pos_T       *lpos, save_cursor;
  pos_T mpos;
  colnr_T vcol;
  long save_so;
  long save_siso;
  int save_state;
  colnr_T save_dollar_vcol;
  char_u      *p;

  /*
   * Only show match for chars in the 'matchpairs' option.
   */
  /* 'matchpairs' is "x:y,x:y" */
  for (p = curbuf->b_p_mps; *p != NUL; ++p) {
    if (PTR2CHAR(p) == c && (curwin->w_p_rl ^ p_ri))
      break;
    p += MB_PTR2LEN(p) + 1;
    if (PTR2CHAR(p) == c
        && !(curwin->w_p_rl ^ p_ri)
        )
      break;
    p += MB_PTR2LEN(p);
    if (*p == NUL)
      return;
  }

  if ((lpos = findmatch(NULL, NUL)) == NULL)        /* no match, so beep */
    vim_beep();
  else if (lpos->lnum >= curwin->w_topline && lpos->lnum < curwin->w_botline) {
    if (!curwin->w_p_wrap)
      getvcol(curwin, lpos, NULL, &vcol, NULL);
    if (curwin->w_p_wrap || (vcol >= curwin->w_leftcol
                             && vcol < curwin->w_leftcol + curwin->w_width)) {
      mpos = *lpos;          /* save the pos, update_screen() may change it */
      save_cursor = curwin->w_cursor;
      save_so = p_so;
      save_siso = p_siso;
      /* Handle "$" in 'cpo': If the ')' is typed on top of the "$",
       * stop displaying the "$". */
      if (dollar_vcol >= 0 && dollar_vcol == curwin->w_virtcol)
        dollar_vcol = -1;
      ++curwin->w_virtcol;              /* do display ')' just before "$" */
      update_screen(VALID);             /* show the new char first */

      save_dollar_vcol = dollar_vcol;
      save_state = State;
      State = SHOWMATCH;
      ui_cursor_shape();                /* may show different cursor shape */
      curwin->w_cursor = mpos;          /* move to matching char */
      p_so = 0;                         /* don't use 'scrolloff' here */
      p_siso = 0;                       /* don't use 'sidescrolloff' here */
      showruler(FALSE);
      setcursor();
      cursor_on();                      /* make sure that the cursor is shown */
      out_flush();
      /* Restore dollar_vcol(), because setcursor() may call curs_rows()
       * which resets it if the matching position is in a previous line
       * and has a higher column number. */
      dollar_vcol = save_dollar_vcol;

      /*
       * brief pause, unless 'm' is present in 'cpo' and a character is
       * available.
       */
      if (vim_strchr(p_cpo, CPO_SHOWMATCH) != NULL)
        ui_delay(p_mat * 100L, true);
      else if (!char_avail())
        ui_delay(p_mat * 100L, false);
      curwin->w_cursor = save_cursor;           /* restore cursor position */
      p_so = save_so;
      p_siso = save_siso;
      State = save_state;
      ui_cursor_shape();                /* may show different cursor shape */
    }
  }
}

/*
 * findsent(dir, count) - Find the start of the next sentence in direction
 * "dir" Sentences are supposed to end in ".", "!" or "?" followed by white
 * space or a line break. Also stop at an empty line.
 * Return OK if the next sentence was found.
 */
int findsent(int dir, long count)
{
  pos_T pos, tpos;
  int c;
  int         (*func)(pos_T *);
  int startlnum;
  int noskip = FALSE;               /* do not skip blanks */
  int cpo_J;
  int found_dot;

  pos = curwin->w_cursor;
  if (dir == FORWARD)
    func = incl;
  else
    func = decl;

  while (count--) {
    /*
     * if on an empty line, skip up to a non-empty line
     */
    if (gchar_pos(&pos) == NUL) {
      do
        if ((*func)(&pos) == -1)
          break;
      while (gchar_pos(&pos) == NUL);
      if (dir == FORWARD)
        goto found;
    }
    /*
     * if on the start of a paragraph or a section and searching forward,
     * go to the next line
     */
    else if (dir == FORWARD && pos.col == 0 &&
             startPS(pos.lnum, NUL, FALSE)) {
      if (pos.lnum == curbuf->b_ml.ml_line_count)
        return FAIL;
      ++pos.lnum;
      goto found;
    } else if (dir == BACKWARD)
      decl(&pos);

    /* go back to the previous non-blank char */
    found_dot = FALSE;
    while ((c = gchar_pos(&pos)) == ' ' || c == '\t' ||
           (dir == BACKWARD && vim_strchr((char_u *)".!?)]\"'", c) != NULL)) {
      if (vim_strchr((char_u *)".!?", c) != NULL) {
        /* Only skip over a '.', '!' and '?' once. */
        if (found_dot)
          break;
        found_dot = TRUE;
      }
      if (decl(&pos) == -1)
        break;
      /* when going forward: Stop in front of empty line */
      if (lineempty(pos.lnum) && dir == FORWARD) {
        incl(&pos);
        goto found;
      }
    }

    /* remember the line where the search started */
    startlnum = pos.lnum;
    cpo_J = vim_strchr(p_cpo, CPO_ENDOFSENT) != NULL;

    for (;; ) {                 /* find end of sentence */
      c = gchar_pos(&pos);
      if (c == NUL || (pos.col == 0 && startPS(pos.lnum, NUL, FALSE))) {
        if (dir == BACKWARD && pos.lnum != startlnum)
          ++pos.lnum;
        break;
      }
      if (c == '.' || c == '!' || c == '?') {
        tpos = pos;
        do
          if ((c = inc(&tpos)) == -1)
            break;
        while (vim_strchr((char_u *)")]\"'", c = gchar_pos(&tpos))
               != NULL);
        if (c == -1  || (!cpo_J && (c == ' ' || c == '\t')) || c == NUL
            || (cpo_J && (c == ' ' && inc(&tpos) >= 0
                          && gchar_pos(&tpos) == ' '))) {
          pos = tpos;
          if (gchar_pos(&pos) == NUL)           /* skip NUL at EOL */
            inc(&pos);
          break;
        }
      }
      if ((*func)(&pos) == -1) {
        if (count)
          return FAIL;
        noskip = TRUE;
        break;
      }
    }
found:
    /* skip white space */
    while (!noskip && ((c = gchar_pos(&pos)) == ' ' || c == '\t'))
      if (incl(&pos) == -1)
        break;
  }

  setpcmark();
  curwin->w_cursor = pos;
  return OK;
}

/*
 * Find the next paragraph or section in direction 'dir'.
 * Paragraphs are currently supposed to be separated by empty lines.
 * If 'what' is NUL we go to the next paragraph.
 * If 'what' is '{' or '}' we go to the next section.
 * If 'both' is TRUE also stop at '}'.
 * Return TRUE if the next paragraph or section was found.
 */
int 
findpar (
    int *pincl,             /* Return: TRUE if last char is to be included */
    int dir,
    long count,
    int what,
    int both
)
{
  linenr_T curr;
  int did_skip;             /* TRUE after separating lines have been skipped */
  int first;                /* TRUE on first line */
  int posix = (vim_strchr(p_cpo, CPO_PARA) != NULL);
  linenr_T fold_first;      /* first line of a closed fold */
  linenr_T fold_last;       /* last line of a closed fold */
  int fold_skipped;           /* TRUE if a closed fold was skipped this
                                 iteration */

  curr = curwin->w_cursor.lnum;

  while (count--) {
    did_skip = FALSE;
    for (first = TRUE;; first = FALSE) {
      if (*ml_get(curr) != NUL)
        did_skip = TRUE;

      /* skip folded lines */
      fold_skipped = FALSE;
      if (first && hasFolding(curr, &fold_first, &fold_last)) {
        curr = ((dir > 0) ? fold_last : fold_first) + dir;
        fold_skipped = TRUE;
      }

      /* POSIX has it's own ideas of what a paragraph boundary is and it
       * doesn't match historical Vi: It also stops at a "{" in the
       * first column and at an empty line. */
      if (!first && did_skip && (startPS(curr, what, both)
                                 || (posix && what == NUL && *ml_get(curr) ==
                                     '{')))
        break;

      if (fold_skipped)
        curr -= dir;
      if ((curr += dir) < 1 || curr > curbuf->b_ml.ml_line_count) {
        if (count)
          return FALSE;
        curr -= dir;
        break;
      }
    }
  }
  setpcmark();
  if (both && *ml_get(curr) == '}')     /* include line with '}' */
    ++curr;
  curwin->w_cursor.lnum = curr;
  if (curr == curbuf->b_ml.ml_line_count && what != '}') {
    if ((curwin->w_cursor.col = (colnr_T)STRLEN(ml_get(curr))) != 0) {
      --curwin->w_cursor.col;
      *pincl = TRUE;
    }
  } else
    curwin->w_cursor.col = 0;
  return TRUE;
}

/*
 * check if the string 's' is a nroff macro that is in option 'opt'
 */
static int inmacro(char_u *opt, char_u *s)
{
  char_u      *macro;

  for (macro = opt; macro[0]; ++macro) {
    /* Accept two characters in the option being equal to two characters
     * in the line.  A space in the option matches with a space in the
     * line or the line having ended. */
    if (       (macro[0] == s[0]
                || (macro[0] == ' '
                    && (s[0] == NUL || s[0] == ' ')))
               && (macro[1] == s[1]
                   || ((macro[1] == NUL || macro[1] == ' ')
                       && (s[0] == NUL || s[1] == NUL || s[1] == ' '))))
      break;
    ++macro;
    if (macro[0] == NUL)
      break;
  }
  return macro[0] != NUL;
}

/*
 * startPS: return TRUE if line 'lnum' is the start of a section or paragraph.
 * If 'para' is '{' or '}' only check for sections.
 * If 'both' is TRUE also stop at '}'
 */
int startPS(linenr_T lnum, int para, int both)
{
  char_u      *s;

  s = ml_get(lnum);
  if (*s == para || *s == '\f' || (both && *s == '}'))
    return TRUE;
  if (*s == '.' && (inmacro(p_sections, s + 1) ||
                    (!para && inmacro(p_para, s + 1))))
    return TRUE;
  return FALSE;
}

/*
 * The following routines do the word searches performed by the 'w', 'W',
 * 'b', 'B', 'e', and 'E' commands.
 */

/*
 * To perform these searches, characters are placed into one of three
 * classes, and transitions between classes determine word boundaries.
 *
 * The classes are:
 *
 * 0 - white space
 * 1 - punctuation
 * 2 or higher - keyword characters (letters, digits and underscore)
 */

static int cls_bigword;         /* TRUE for "W", "B" or "E" */

/*
 * cls() - returns the class of character at curwin->w_cursor
 *
 * If a 'W', 'B', or 'E' motion is being done (cls_bigword == TRUE), chars
 * from class 2 and higher are reported as class 1 since only white space
 * boundaries are of interest.
 */
static int cls(void)
{
  int c;

  c = gchar_cursor();
  if (p_altkeymap && c == F_BLANK)
    return 0;
  if (c == ' ' || c == '\t' || c == NUL)
    return 0;
  if (enc_dbcs != 0 && c > 0xFF) {
    /* If cls_bigword, report multi-byte chars as class 1. */
    if (enc_dbcs == DBCS_KOR && cls_bigword)
      return 1;

    /* process code leading/trailing bytes */
    return dbcs_class(((unsigned)c >> 8), (c & 0xFF));
  }
  if (enc_utf8) {
    c = utf_class(c);
    if (c != 0 && cls_bigword)
      return 1;
    return c;
  }

  /* If cls_bigword is TRUE, report all non-blanks as class 1. */
  if (cls_bigword)
    return 1;

  if (vim_iswordc(c))
    return 2;
  return 1;
}

/*
 * fwd_word(count, type, eol) - move forward one word
 *
 * Returns FAIL if the cursor was already at the end of the file.
 * If eol is TRUE, last word stops at end of line (for operators).
 */
int 
fwd_word (
    long count,
    int bigword,                /* "W", "E" or "B" */
    int eol
)
{
  int sclass;               /* starting class */
  int i;
  int last_line;

  curwin->w_cursor.coladd = 0;
  cls_bigword = bigword;
  while (--count >= 0) {
    /* When inside a range of folded lines, move to the last char of the
     * last line. */
    if (hasFolding(curwin->w_cursor.lnum, NULL, &curwin->w_cursor.lnum))
      coladvance((colnr_T)MAXCOL);
    sclass = cls();

    /*
     * We always move at least one character, unless on the last
     * character in the buffer.
     */
    last_line = (curwin->w_cursor.lnum == curbuf->b_ml.ml_line_count);
    i = inc_cursor();
    if (i == -1 || (i >= 1 && last_line))     /* started at last char in file */
      return FAIL;
    if (i >= 1 && eol && count == 0)          /* started at last char in line */
      return OK;

    /*
     * Go one char past end of current word (if any)
     */
    if (sclass != 0)
      while (cls() == sclass) {
        i = inc_cursor();
        if (i == -1 || (i >= 1 && eol && count == 0))
          return OK;
      }

    /*
     * go to next non-white
     */
    while (cls() == 0) {
      /*
       * We'll stop if we land on a blank line
       */
      if (curwin->w_cursor.col == 0 && *get_cursor_line_ptr() == NUL)
        break;

      i = inc_cursor();
      if (i == -1 || (i >= 1 && eol && count == 0))
        return OK;
    }
  }
  return OK;
}

/*
 * bck_word() - move backward 'count' words
 *
 * If stop is TRUE and we are already on the start of a word, move one less.
 *
 * Returns FAIL if top of the file was reached.
 */
int bck_word(long count, int bigword, int stop)
{
  int sclass;               /* starting class */

  curwin->w_cursor.coladd = 0;
  cls_bigword = bigword;
  while (--count >= 0) {
    /* When inside a range of folded lines, move to the first char of the
     * first line. */
    if (hasFolding(curwin->w_cursor.lnum, &curwin->w_cursor.lnum, NULL))
      curwin->w_cursor.col = 0;
    sclass = cls();
    if (dec_cursor() == -1)             /* started at start of file */
      return FAIL;

    if (!stop || sclass == cls() || sclass == 0) {
      /*
       * Skip white space before the word.
       * Stop on an empty line.
       */
      while (cls() == 0) {
        if (curwin->w_cursor.col == 0
            && lineempty(curwin->w_cursor.lnum))
          goto finished;
        if (dec_cursor() == -1)         /* hit start of file, stop here */
          return OK;
      }

      /*
       * Move backward to start of this word.
       */
      if (skip_chars(cls(), BACKWARD))
        return OK;
    }

    inc_cursor();                       /* overshot - forward one */
finished:
    stop = FALSE;
  }
  return OK;
}

/*
 * end_word() - move to the end of the word
 *
 * There is an apparent bug in the 'e' motion of the real vi. At least on the
 * System V Release 3 version for the 80386. Unlike 'b' and 'w', the 'e'
 * motion crosses blank lines. When the real vi crosses a blank line in an
 * 'e' motion, the cursor is placed on the FIRST character of the next
 * non-blank line. The 'E' command, however, works correctly. Since this
 * appears to be a bug, I have not duplicated it here.
 *
 * Returns FAIL if end of the file was reached.
 *
 * If stop is TRUE and we are already on the end of a word, move one less.
 * If empty is TRUE stop on an empty line.
 */
int end_word(long count, int bigword, int stop, int empty)
{
  int sclass;               /* starting class */

  curwin->w_cursor.coladd = 0;
  cls_bigword = bigword;
  while (--count >= 0) {
    /* When inside a range of folded lines, move to the last char of the
     * last line. */
    if (hasFolding(curwin->w_cursor.lnum, NULL, &curwin->w_cursor.lnum))
      coladvance((colnr_T)MAXCOL);
    sclass = cls();
    if (inc_cursor() == -1)
      return FAIL;

    /*
     * If we're in the middle of a word, we just have to move to the end
     * of it.
     */
    if (cls() == sclass && sclass != 0) {
      /*
       * Move forward to end of the current word
       */
      if (skip_chars(sclass, FORWARD))
        return FAIL;
    } else if (!stop || sclass == 0) {
      /*
       * We were at the end of a word. Go to the end of the next word.
       * First skip white space, if 'empty' is TRUE, stop at empty line.
       */
      while (cls() == 0) {
        if (empty && curwin->w_cursor.col == 0
            && lineempty(curwin->w_cursor.lnum))
          goto finished;
        if (inc_cursor() == -1)             /* hit end of file, stop here */
          return FAIL;
      }

      /*
       * Move forward to the end of this word.
       */
      if (skip_chars(cls(), FORWARD))
        return FAIL;
    }
    dec_cursor();                       /* overshot - one char backward */
finished:
    stop = FALSE;                       /* we move only one word less */
  }
  return OK;
}

/*
 * Move back to the end of the word.
 *
 * Returns FAIL if start of the file was reached.
 */
int 
bckend_word (
    long count,
    int bigword,                /* TRUE for "B" */
    int eol                    /* TRUE: stop at end of line. */
)
{
  int sclass;               /* starting class */
  int i;

  curwin->w_cursor.coladd = 0;
  cls_bigword = bigword;
  while (--count >= 0) {
    sclass = cls();
    if ((i = dec_cursor()) == -1)
      return FAIL;
    if (eol && i == 1)
      return OK;

    /*
     * Move backward to before the start of this word.
     */
    if (sclass != 0) {
      while (cls() == sclass)
        if ((i = dec_cursor()) == -1 || (eol && i == 1))
          return OK;
    }

    /*
     * Move backward to end of the previous word
     */
    while (cls() == 0) {
      if (curwin->w_cursor.col == 0 && lineempty(curwin->w_cursor.lnum))
        break;
      if ((i = dec_cursor()) == -1 || (eol && i == 1))
        return OK;
    }
  }
  return OK;
}

/*
 * Skip a row of characters of the same class.
 * Return TRUE when end-of-file reached, FALSE otherwise.
 */
static int skip_chars(int cclass, int dir)
{
  while (cls() == cclass)
    if ((dir == FORWARD ? inc_cursor() : dec_cursor()) == -1)
      return TRUE;
  return FALSE;
}

/*
 * Go back to the start of the word or the start of white space
 */
static void back_in_line(void)
{
  int sclass;                       /* starting class */

  sclass = cls();
  for (;; ) {
    if (curwin->w_cursor.col == 0)          /* stop at start of line */
      break;
    dec_cursor();
    if (cls() != sclass) {                  /* stop at start of word */
      inc_cursor();
      break;
    }
  }
}

static void find_first_blank(pos_T *posp)
{
  int c;

  while (decl(posp) != -1) {
    c = gchar_pos(posp);
    if (!vim_iswhite(c)) {
      incl(posp);
      break;
    }
  }
}

/*
 * Skip count/2 sentences and count/2 separating white spaces.
 */
static void 
findsent_forward (
    long count,
    int at_start_sent              /* cursor is at start of sentence */
)
{
  while (count--) {
    findsent(FORWARD, 1L);
    if (at_start_sent)
      find_first_blank(&curwin->w_cursor);
    if (count == 0 || at_start_sent)
      decl(&curwin->w_cursor);
    at_start_sent = !at_start_sent;
  }
}

/*
 * Find word under cursor, cursor at end.
 * Used while an operator is pending, and in Visual mode.
 */
int 
current_word (
    oparg_T *oap,
    long count,
    int include,                    /* TRUE: include word and white space */
    int bigword                    /* FALSE == word, TRUE == WORD */
)
{
  pos_T start_pos;
  pos_T pos;
  int inclusive = TRUE;
  int include_white = FALSE;

  cls_bigword = bigword;
  clearpos(&start_pos);

  /* Correct cursor when 'selection' is exclusive */
  if (VIsual_active && *p_sel == 'e' && lt(VIsual, curwin->w_cursor))
    dec_cursor();

  /*
   * When Visual mode is not active, or when the VIsual area is only one
   * character, select the word and/or white space under the cursor.
   */
  if (!VIsual_active || equalpos(curwin->w_cursor, VIsual)) {
    /*
     * Go to start of current word or white space.
     */
    back_in_line();
    start_pos = curwin->w_cursor;

    /*
     * If the start is on white space, and white space should be included
     * ("	word"), or start is not on white space, and white space should
     * not be included ("word"), find end of word.
     */
    if ((cls() == 0) == include) {
      if (end_word(1L, bigword, TRUE, TRUE) == FAIL)
        return FAIL;
    } else {
      /*
       * If the start is not on white space, and white space should be
       * included ("word	 "), or start is on white space and white
       * space should not be included ("	 "), find start of word.
       * If we end up in the first column of the next line (single char
       * word) back up to end of the line.
       */
      fwd_word(1L, bigword, TRUE);
      if (curwin->w_cursor.col == 0)
        decl(&curwin->w_cursor);
      else
        oneleft();

      if (include)
        include_white = TRUE;
    }

    if (VIsual_active) {
      /* should do something when inclusive == FALSE ! */
      VIsual = start_pos;
      redraw_curbuf_later(INVERTED);            /* update the inversion */
    } else {
      oap->start = start_pos;
      oap->motion_type = MCHAR;
    }
    --count;
  }

  /*
   * When count is still > 0, extend with more objects.
   */
  while (count > 0) {
    inclusive = TRUE;
    if (VIsual_active && lt(curwin->w_cursor, VIsual)) {
      /*
       * In Visual mode, with cursor at start: move cursor back.
       */
      if (decl(&curwin->w_cursor) == -1)
        return FAIL;
      if (include != (cls() != 0)) {
        if (bck_word(1L, bigword, TRUE) == FAIL)
          return FAIL;
      } else {
        if (bckend_word(1L, bigword, TRUE) == FAIL)
          return FAIL;
        (void)incl(&curwin->w_cursor);
      }
    } else {
      /*
       * Move cursor forward one word and/or white area.
       */
      if (incl(&curwin->w_cursor) == -1)
        return FAIL;
      if (include != (cls() == 0)) {
        if (fwd_word(1L, bigword, TRUE) == FAIL && count > 1)
          return FAIL;
        /*
         * If end is just past a new-line, we don't want to include
         * the first character on the line.
         * Put cursor on last char of white.
         */
        if (oneleft() == FAIL)
          inclusive = FALSE;
      } else {
        if (end_word(1L, bigword, TRUE, TRUE) == FAIL)
          return FAIL;
      }
    }
    --count;
  }

  if (include_white && (cls() != 0
                        || (curwin->w_cursor.col == 0 && !inclusive))) {
    /*
     * If we don't include white space at the end, move the start
     * to include some white space there. This makes "daw" work
     * better on the last word in a sentence (and "2daw" on last-but-one
     * word).  Also when "2daw" deletes "word." at the end of the line
     * (cursor is at start of next line).
     * But don't delete white space at start of line (indent).
     */
    pos = curwin->w_cursor;     /* save cursor position */
    curwin->w_cursor = start_pos;
    if (oneleft() == OK) {
      back_in_line();
      if (cls() == 0 && curwin->w_cursor.col > 0) {
        if (VIsual_active)
          VIsual = curwin->w_cursor;
        else
          oap->start = curwin->w_cursor;
      }
    }
    curwin->w_cursor = pos;     /* put cursor back at end */
  }

  if (VIsual_active) {
    if (*p_sel == 'e' && inclusive && ltoreq(VIsual, curwin->w_cursor))
      inc_cursor();
    if (VIsual_mode == 'V') {
      VIsual_mode = 'v';
      redraw_cmdline = TRUE;                    /* show mode later */
    }
  } else
    oap->inclusive = inclusive;

  return OK;
}

/*
 * Find sentence(s) under the cursor, cursor at end.
 * When Visual active, extend it by one or more sentences.
 */
int current_sent(oparg_T *oap, long count, int include)
{
  pos_T start_pos;
  pos_T pos;
  int start_blank;
  int c;
  int at_start_sent;
  long ncount;

  start_pos = curwin->w_cursor;
  pos = start_pos;
  findsent(FORWARD, 1L);        /* Find start of next sentence. */

  /*
   * When the Visual area is bigger than one character: Extend it.
   */
  if (VIsual_active && !equalpos(start_pos, VIsual)) {
extend:
    if (lt(start_pos, VIsual)) {
      /*
       * Cursor at start of Visual area.
       * Find out where we are:
       * - in the white space before a sentence
       * - in a sentence or just after it
       * - at the start of a sentence
       */
      at_start_sent = TRUE;
      decl(&pos);
      while (lt(pos, curwin->w_cursor)) {
        c = gchar_pos(&pos);
        if (!vim_iswhite(c)) {
          at_start_sent = FALSE;
          break;
        }
        incl(&pos);
      }
      if (!at_start_sent) {
        findsent(BACKWARD, 1L);
        if (equalpos(curwin->w_cursor, start_pos))
          at_start_sent = TRUE;            /* exactly at start of sentence */
        else
          /* inside a sentence, go to its end (start of next) */
          findsent(FORWARD, 1L);
      }
      if (include)              /* "as" gets twice as much as "is" */
        count *= 2;
      while (count--) {
        if (at_start_sent)
          find_first_blank(&curwin->w_cursor);
        c = gchar_cursor();
        if (!at_start_sent || (!include && !vim_iswhite(c)))
          findsent(BACKWARD, 1L);
        at_start_sent = !at_start_sent;
      }
    } else {
      /*
       * Cursor at end of Visual area.
       * Find out where we are:
       * - just before a sentence
       * - just before or in the white space before a sentence
       * - in a sentence
       */
      incl(&pos);
      at_start_sent = TRUE;
      if (!equalpos(pos, curwin->w_cursor)) {     /* not just before a sentence */
        at_start_sent = FALSE;
        while (lt(pos, curwin->w_cursor)) {
          c = gchar_pos(&pos);
          if (!vim_iswhite(c)) {
            at_start_sent = TRUE;
            break;
          }
          incl(&pos);
        }
        if (at_start_sent)              /* in the sentence */
          findsent(BACKWARD, 1L);
        else                    /* in/before white before a sentence */
          curwin->w_cursor = start_pos;
      }

      if (include)              /* "as" gets twice as much as "is" */
        count *= 2;
      findsent_forward(count, at_start_sent);
      if (*p_sel == 'e')
        ++curwin->w_cursor.col;
    }
    return OK;
  }

  /*
   * If the cursor started on a blank, check if it is just before the start
   * of the next sentence.
   */
  while (c = gchar_pos(&pos), vim_iswhite(c))   /* vim_iswhite() is a macro */
    incl(&pos);
  if (equalpos(pos, curwin->w_cursor)) {
    start_blank = TRUE;
    find_first_blank(&start_pos);       /* go back to first blank */
  } else {
    start_blank = FALSE;
    findsent(BACKWARD, 1L);
    start_pos = curwin->w_cursor;
  }
  if (include)
    ncount = count * 2;
  else {
    ncount = count;
    if (start_blank)
      --ncount;
  }
  if (ncount > 0)
    findsent_forward(ncount, TRUE);
  else
    decl(&curwin->w_cursor);

  if (include) {
    /*
     * If the blank in front of the sentence is included, exclude the
     * blanks at the end of the sentence, go back to the first blank.
     * If there are no trailing blanks, try to include leading blanks.
     */
    if (start_blank) {
      find_first_blank(&curwin->w_cursor);
      c = gchar_pos(&curwin->w_cursor);         /* vim_iswhite() is a macro */
      if (vim_iswhite(c))
        decl(&curwin->w_cursor);
    } else if (c = gchar_cursor(), !vim_iswhite(c))
      find_first_blank(&start_pos);
  }

  if (VIsual_active) {
    /* Avoid getting stuck with "is" on a single space before a sentence. */
    if (equalpos(start_pos, curwin->w_cursor))
      goto extend;
    if (*p_sel == 'e')
      ++curwin->w_cursor.col;
    VIsual = start_pos;
    VIsual_mode = 'v';
    redraw_curbuf_later(INVERTED);      /* update the inversion */
  } else {
    /* include a newline after the sentence, if there is one */
    if (incl(&curwin->w_cursor) == -1)
      oap->inclusive = TRUE;
    else
      oap->inclusive = FALSE;
    oap->start = start_pos;
    oap->motion_type = MCHAR;
  }
  return OK;
}

/*
 * Find block under the cursor, cursor at end.
 * "what" and "other" are two matching parenthesis/brace/etc.
 */
int 
current_block (
    oparg_T *oap,
    long count,
    int include,                    /* TRUE == include white space */
    int what,                       /* '(', '{', etc. */
    int other                      /* ')', '}', etc. */
)
{
  pos_T old_pos;
  pos_T       *pos = NULL;
  pos_T start_pos;
  pos_T       *end_pos;
  pos_T old_start, old_end;
  char_u      *save_cpo;
  int sol = FALSE;                      /* '{' at start of line */

  old_pos = curwin->w_cursor;
  old_end = curwin->w_cursor;           /* remember where we started */
  old_start = old_end;

  /*
   * If we start on '(', '{', ')', '}', etc., use the whole block inclusive.
   */
  if (!VIsual_active || equalpos(VIsual, curwin->w_cursor)) {
    setpcmark();
    if (what == '{')                    /* ignore indent */
      while (inindent(1))
        if (inc_cursor() != 0)
          break;
    if (gchar_cursor() == what)
      /* cursor on '(' or '{', move cursor just after it */
      ++curwin->w_cursor.col;
  } else if (lt(VIsual, curwin->w_cursor)) {
    old_start = VIsual;
    curwin->w_cursor = VIsual;              /* cursor at low end of Visual */
  } else
    old_end = VIsual;

  /*
   * Search backwards for unclosed '(', '{', etc..
   * Put this position in start_pos.
   * Ignore quotes here.
   */
  save_cpo = p_cpo;
  p_cpo = (char_u *)"%";
  while (count-- > 0) {
    if ((pos = findmatch(NULL, what)) == NULL)
      break;
    curwin->w_cursor = *pos;
    start_pos = *pos;       /* the findmatch for end_pos will overwrite *pos */
  }
  p_cpo = save_cpo;

  /*
   * Search for matching ')', '}', etc.
   * Put this position in curwin->w_cursor.
   */
  if (pos == NULL || (end_pos = findmatch(NULL, other)) == NULL) {
    curwin->w_cursor = old_pos;
    return FAIL;
  }
  curwin->w_cursor = *end_pos;

  /*
   * Try to exclude the '(', '{', ')', '}', etc. when "include" is FALSE.
   * If the ending '}' is only preceded by indent, skip that indent.
   * But only if the resulting area is not smaller than what we started with.
   */
  while (!include) {
    incl(&start_pos);
    sol = (curwin->w_cursor.col == 0);
    decl(&curwin->w_cursor);
    if (what == '{')
      while (inindent(1)) {
        sol = TRUE;
        if (decl(&curwin->w_cursor) != 0)
          break;
      }
    /*
     * In Visual mode, when the resulting area is not bigger than what we
     * started with, extend it to the next block, and then exclude again.
     */
    if (!lt(start_pos, old_start) && !lt(old_end, curwin->w_cursor)
        && VIsual_active) {
      curwin->w_cursor = old_start;
      decl(&curwin->w_cursor);
      if ((pos = findmatch(NULL, what)) == NULL) {
        curwin->w_cursor = old_pos;
        return FAIL;
      }
      start_pos = *pos;
      curwin->w_cursor = *pos;
      if ((end_pos = findmatch(NULL, other)) == NULL) {
        curwin->w_cursor = old_pos;
        return FAIL;
      }
      curwin->w_cursor = *end_pos;
    } else
      break;
  }

  if (VIsual_active) {
    if (*p_sel == 'e')
      ++curwin->w_cursor.col;
    if (sol && gchar_cursor() != NUL)
      inc(&curwin->w_cursor);           /* include the line break */
    VIsual = start_pos;
    VIsual_mode = 'v';
    redraw_curbuf_later(INVERTED);      /* update the inversion */
    showmode();
  } else {
    oap->start = start_pos;
    oap->motion_type = MCHAR;
    oap->inclusive = FALSE;
    if (sol)
      incl(&curwin->w_cursor);
    else if (ltoreq(start_pos, curwin->w_cursor))
      /* Include the character under the cursor. */
      oap->inclusive = TRUE;
    else
      /* End is before the start (no text in between <>, [], etc.): don't
       * operate on any text. */
      curwin->w_cursor = start_pos;
  }

  return OK;
}


/*
 * Return TRUE if the cursor is on a "<aaa>" tag.  Ignore "<aaa/>".
 * When "end_tag" is TRUE return TRUE if the cursor is on "</aaa>".
 */
static int in_html_tag(int end_tag)
{
  char_u      *line = get_cursor_line_ptr();
  char_u      *p;
  int c;
  int lc = NUL;
  pos_T pos;

  if (enc_dbcs) {
    char_u  *lp = NULL;

    /* We search forward until the cursor, because searching backwards is
     * very slow for DBCS encodings. */
    for (p = line; p < line + curwin->w_cursor.col; mb_ptr_adv(p))
      if (*p == '>' || *p == '<') {
        lc = *p;
        lp = p;
      }
    if (*p != '<') {        /* check for '<' under cursor */
      if (lc != '<')
        return FALSE;
      p = lp;
    }
  } else {
    for (p = line + curwin->w_cursor.col; p > line; ) {
      if (*p == '<')            /* find '<' under/before cursor */
        break;
      mb_ptr_back(line, p);
      if (*p == '>')            /* find '>' before cursor */
        break;
    }
    if (*p != '<')
      return FALSE;
  }

  pos.lnum = curwin->w_cursor.lnum;
  pos.col = (colnr_T)(p - line);

  mb_ptr_adv(p);
  if (end_tag)
    /* check that there is a '/' after the '<' */
    return *p == '/';

  /* check that there is no '/' after the '<' */
  if (*p == '/')
    return FALSE;

  /* check that the matching '>' is not preceded by '/' */
  for (;; ) {
    if (inc(&pos) < 0)
      return FALSE;
    c = *ml_get_pos(&pos);
    if (c == '>')
      break;
    lc = c;
  }
  return lc != '/';
}

/*
 * Find tag block under the cursor, cursor at end.
 */
int 
current_tagblock (
    oparg_T *oap,
    long count_arg,
    int include                    /* TRUE == include white space */
)
{
  long count = count_arg;
  long n;
  pos_T old_pos;
  pos_T start_pos;
  pos_T end_pos;
  pos_T old_start, old_end;
  char_u      *spat, *epat;
  char_u      *p;
  char_u      *cp;
  int len;
  int r;
  int do_include = include;
  bool save_p_ws = p_ws;
  int retval = FAIL;

  p_ws = false;

  old_pos = curwin->w_cursor;
  old_end = curwin->w_cursor;               /* remember where we started */
  old_start = old_end;
  if (!VIsual_active || *p_sel == 'e')
    decl(&old_end);                         /* old_end is inclusive */

  /*
   * If we start on "<aaa>" select that block.
   */
  if (!VIsual_active || equalpos(VIsual, curwin->w_cursor)) {
    setpcmark();

    /* ignore indent */
    while (inindent(1))
      if (inc_cursor() != 0)
        break;

    if (in_html_tag(FALSE)) {
      /* cursor on start tag, move to its '>' */
      while (*get_cursor_pos_ptr() != '>')
        if (inc_cursor() < 0)
          break;
    } else if (in_html_tag(TRUE)) {
      /* cursor on end tag, move to just before it */
      while (*get_cursor_pos_ptr() != '<')
        if (dec_cursor() < 0)
          break;
      dec_cursor();
      old_end = curwin->w_cursor;
    }
  } else if (lt(VIsual, curwin->w_cursor)) {
    old_start = VIsual;
    curwin->w_cursor = VIsual;              /* cursor at low end of Visual */
  } else
    old_end = VIsual;

again:
  /*
   * Search backwards for unclosed "<aaa>".
   * Put this position in start_pos.
   */
  for (n = 0; n < count; ++n) {
    if (do_searchpair((char_u *)
            "<[^ \t>/!]\\+\\%(\\_s\\_[^>]\\{-}[^/]>\\|$\\|\\_s\\=>\\)",
            (char_u *)"",
            (char_u *)"</[^>]*>", BACKWARD, (char_u *)"", 0,
            NULL, (linenr_T)0, 0L) <= 0) {
      curwin->w_cursor = old_pos;
      goto theend;
    }
  }
  start_pos = curwin->w_cursor;

  /*
   * Search for matching "</aaa>".  First isolate the "aaa".
   */
  inc_cursor();
  p = get_cursor_pos_ptr();
  for (cp = p; *cp != NUL && *cp != '>' && !vim_iswhite(*cp); mb_ptr_adv(cp))
    ;
  len = (int)(cp - p);
  if (len == 0) {
    curwin->w_cursor = old_pos;
    goto theend;
  }
  spat = xmalloc(len + 31);
  epat = xmalloc(len + 9);
  sprintf((char *)spat, "<%.*s\\>\\%%(\\s\\_[^>]\\{-}[^/]>\\|>\\)\\c", len, p);
  sprintf((char *)epat, "</%.*s>\\c", len, p);

  r = do_searchpair(spat, (char_u *)"", epat, FORWARD, (char_u *)"",
      0, NULL, (linenr_T)0, 0L);

  free(spat);
  free(epat);

  if (r < 1 || lt(curwin->w_cursor, old_end)) {
    /* Can't find other end or it's before the previous end.  Could be a
     * HTML tag that doesn't have a matching end.  Search backwards for
     * another starting tag. */
    count = 1;
    curwin->w_cursor = start_pos;
    goto again;
  }

  if (do_include || r < 1) {
    /* Include up to the '>'. */
    while (*get_cursor_pos_ptr() != '>')
      if (inc_cursor() < 0)
        break;
  } else {
    /* Exclude the '<' of the end tag. */
    if (*get_cursor_pos_ptr() == '<')
      dec_cursor();
  }
  end_pos = curwin->w_cursor;

  if (!do_include) {
    /* Exclude the start tag. */
    curwin->w_cursor = start_pos;
    while (inc_cursor() >= 0)
      if (*get_cursor_pos_ptr() == '>') {
        inc_cursor();
        start_pos = curwin->w_cursor;
        break;
      }
    curwin->w_cursor = end_pos;

    /* If we now have the same text as before reset "do_include" and try
     * again. */
    if (equalpos(start_pos, old_start) && equalpos(end_pos, old_end)) {
      do_include = TRUE;
      curwin->w_cursor = old_start;
      count = count_arg;
      goto again;
    }
  }

  if (VIsual_active) {
    /* If the end is before the start there is no text between tags, select
     * the char under the cursor. */
    if (lt(end_pos, start_pos))
      curwin->w_cursor = start_pos;
    else if (*p_sel == 'e')
      ++curwin->w_cursor.col;
    VIsual = start_pos;
    VIsual_mode = 'v';
    redraw_curbuf_later(INVERTED);      /* update the inversion */
    showmode();
  } else {
    oap->start = start_pos;
    oap->motion_type = MCHAR;
    if (lt(end_pos, start_pos)) {
      /* End is before the start: there is no text between tags; operate
       * on an empty area. */
      curwin->w_cursor = start_pos;
      oap->inclusive = FALSE;
    } else
      oap->inclusive = TRUE;
  }
  retval = OK;

theend:
  p_ws = save_p_ws;
  return retval;
}

int 
current_par (
    oparg_T *oap,
    long count,
    int include,                    /* TRUE == include white space */
    int type                       /* 'p' for paragraph, 'S' for section */
)
{
  linenr_T start_lnum;
  linenr_T end_lnum;
  int white_in_front;
  int dir;
  int start_is_white;
  int prev_start_is_white;
  int retval = OK;
  int do_white = FALSE;
  int t;
  int i;

  if (type == 'S')          /* not implemented yet */
    return FAIL;

  start_lnum = curwin->w_cursor.lnum;

  /*
   * When visual area is more than one line: extend it.
   */
  if (VIsual_active && start_lnum != VIsual.lnum) {
extend:
    if (start_lnum < VIsual.lnum)
      dir = BACKWARD;
    else
      dir = FORWARD;
    for (i = count; --i >= 0; ) {
      if (start_lnum ==
          (dir == BACKWARD ? 1 : curbuf->b_ml.ml_line_count)) {
        retval = FAIL;
        break;
      }

      prev_start_is_white = -1;
      for (t = 0; t < 2; ++t) {
        start_lnum += dir;
        start_is_white = linewhite(start_lnum);
        if (prev_start_is_white == start_is_white) {
          start_lnum -= dir;
          break;
        }
        for (;; ) {
          if (start_lnum == (dir == BACKWARD
                             ? 1 : curbuf->b_ml.ml_line_count))
            break;
          if (start_is_white != linewhite(start_lnum + dir)
              || (!start_is_white
                  && startPS(start_lnum + (dir > 0
                                           ? 1 : 0), 0, 0)))
            break;
          start_lnum += dir;
        }
        if (!include)
          break;
        if (start_lnum == (dir == BACKWARD
                           ? 1 : curbuf->b_ml.ml_line_count))
          break;
        prev_start_is_white = start_is_white;
      }
    }
    curwin->w_cursor.lnum = start_lnum;
    curwin->w_cursor.col = 0;
    return retval;
  }

  /*
   * First move back to the start_lnum of the paragraph or white lines
   */
  white_in_front = linewhite(start_lnum);
  while (start_lnum > 1) {
    if (white_in_front) {           /* stop at first white line */
      if (!linewhite(start_lnum - 1))
        break;
    } else {          /* stop at first non-white line of start of paragraph */
      if (linewhite(start_lnum - 1) || startPS(start_lnum, 0, 0))
        break;
    }
    --start_lnum;
  }

  /*
   * Move past the end of any white lines.
   */
  end_lnum = start_lnum;
  while (end_lnum <= curbuf->b_ml.ml_line_count && linewhite(end_lnum))
    ++end_lnum;

  --end_lnum;
  i = count;
  if (!include && white_in_front)
    --i;
  while (i--) {
    if (end_lnum == curbuf->b_ml.ml_line_count)
      return FAIL;

    if (!include)
      do_white = linewhite(end_lnum + 1);

    if (include || !do_white) {
      ++end_lnum;
      /*
       * skip to end of paragraph
       */
      while (end_lnum < curbuf->b_ml.ml_line_count
             && !linewhite(end_lnum + 1)
             && !startPS(end_lnum + 1, 0, 0))
        ++end_lnum;
    }

    if (i == 0 && white_in_front && include)
      break;

    /*
     * skip to end of white lines after paragraph
     */
    if (include || do_white)
      while (end_lnum < curbuf->b_ml.ml_line_count
             && linewhite(end_lnum + 1))
        ++end_lnum;
  }

  /*
   * If there are no empty lines at the end, try to find some empty lines at
   * the start (unless that has been done already).
   */
  if (!white_in_front && !linewhite(end_lnum) && include)
    while (start_lnum > 1 && linewhite(start_lnum - 1))
      --start_lnum;

  if (VIsual_active) {
    /* Problem: when doing "Vipipip" nothing happens in a single white
     * line, we get stuck there.  Trap this here. */
    if (VIsual_mode == 'V' && start_lnum == curwin->w_cursor.lnum)
      goto extend;
    VIsual.lnum = start_lnum;
    VIsual_mode = 'V';
    redraw_curbuf_later(INVERTED);      /* update the inversion */
    showmode();
  } else {
    oap->start.lnum = start_lnum;
    oap->start.col = 0;
    oap->motion_type = MLINE;
  }
  curwin->w_cursor.lnum = end_lnum;
  curwin->w_cursor.col = 0;

  return OK;
}


/*
 * Search quote char from string line[col].
 * Quote character escaped by one of the characters in "escape" is not counted
 * as a quote.
 * Returns column number of "quotechar" or -1 when not found.
 */
static int 
find_next_quote (
    char_u *line,
    int col,
    int quotechar,
    char_u *escape            /* escape characters, can be NULL */
)
{
  int c;

  for (;; ) {
    c = line[col];
    if (c == NUL)
      return -1;
    else if (escape != NULL && vim_strchr(escape, c))
      ++col;
    else if (c == quotechar)
      break;
    if (has_mbyte)
      col += (*mb_ptr2len)(line + col);
    else
      ++col;
  }
  return col;
}

/*
 * Search backwards in "line" from column "col_start" to find "quotechar".
 * Quote character escaped by one of the characters in "escape" is not counted
 * as a quote.
 * Return the found column or zero.
 */
static int 
find_prev_quote (
    char_u *line,
    int col_start,
    int quotechar,
    char_u *escape            /* escape characters, can be NULL */
)
{
  int n;

  while (col_start > 0) {
    --col_start;
    col_start -= (*mb_head_off)(line, line + col_start);
    n = 0;
    if (escape != NULL)
      while (col_start - n > 0 && vim_strchr(escape,
                 line[col_start - n - 1]) != NULL)
        ++n;
    if (n & 1)
      col_start -= n;           /* uneven number of escape chars, skip it */
    else if (line[col_start] == quotechar)
      break;
  }
  return col_start;
}

/*
 * Find quote under the cursor, cursor at end.
 * Returns TRUE if found, else FALSE.
 */
int 
current_quote (
    oparg_T *oap,
    long count,
    int include,                    /* TRUE == include quote char */
    int quotechar                  /* Quote character */
)
{
  char_u      *line = get_cursor_line_ptr();
  int col_end;
  int col_start = curwin->w_cursor.col;
  int inclusive = FALSE;
  int vis_empty = TRUE;                 /* Visual selection <= 1 char */
  int vis_bef_curs = FALSE;             /* Visual starts before cursor */
  int inside_quotes = FALSE;            /* Looks like "i'" done before */
  int selected_quote = FALSE;           /* Has quote inside selection */
  int i;

  /* Correct cursor when 'selection' is exclusive */
  if (VIsual_active) {
    vis_bef_curs = lt(VIsual, curwin->w_cursor);
    if (*p_sel == 'e' && vis_bef_curs)
      dec_cursor();
    vis_empty = equalpos(VIsual, curwin->w_cursor);
  }

  if (!vis_empty) {
    /* Check if the existing selection exactly spans the text inside
     * quotes. */
    if (vis_bef_curs) {
      inside_quotes = VIsual.col > 0
                      && line[VIsual.col - 1] == quotechar
                      && line[curwin->w_cursor.col] != NUL
                      && line[curwin->w_cursor.col + 1] == quotechar;
      i = VIsual.col;
      col_end = curwin->w_cursor.col;
    } else {
      inside_quotes = curwin->w_cursor.col > 0
                      && line[curwin->w_cursor.col - 1] == quotechar
                      && line[VIsual.col] != NUL
                      && line[VIsual.col + 1] == quotechar;
      i = curwin->w_cursor.col;
      col_end = VIsual.col;
    }

    /* Find out if we have a quote in the selection. */
    while (i <= col_end)
      if (line[i++] == quotechar) {
        selected_quote = TRUE;
        break;
      }
  }

  if (!vis_empty && line[col_start] == quotechar) {
    /* Already selecting something and on a quote character.  Find the
     * next quoted string. */
    if (vis_bef_curs) {
      /* Assume we are on a closing quote: move to after the next
       * opening quote. */
      col_start = find_next_quote(line, col_start + 1, quotechar, NULL);
      if (col_start < 0)
        return FALSE;
      col_end = find_next_quote(line, col_start + 1, quotechar,
          curbuf->b_p_qe);
      if (col_end < 0) {
        /* We were on a starting quote perhaps? */
        col_end = col_start;
        col_start = curwin->w_cursor.col;
      }
    } else {
      col_end = find_prev_quote(line, col_start, quotechar, NULL);
      if (line[col_end] != quotechar)
        return FALSE;
      col_start = find_prev_quote(line, col_end, quotechar,
          curbuf->b_p_qe);
      if (line[col_start] != quotechar) {
        /* We were on an ending quote perhaps? */
        col_start = col_end;
        col_end = curwin->w_cursor.col;
      }
    }
  } else if (line[col_start] == quotechar
             || !vis_empty
             ) {
    int first_col = col_start;

    if (!vis_empty) {
      if (vis_bef_curs)
        first_col = find_next_quote(line, col_start, quotechar, NULL);
      else
        first_col = find_prev_quote(line, col_start, quotechar, NULL);
    }
    /* The cursor is on a quote, we don't know if it's the opening or
     * closing quote.  Search from the start of the line to find out.
     * Also do this when there is a Visual area, a' may leave the cursor
     * in between two strings. */
    col_start = 0;
    for (;; ) {
      /* Find open quote character. */
      col_start = find_next_quote(line, col_start, quotechar, NULL);
      if (col_start < 0 || col_start > first_col)
        return FALSE;
      /* Find close quote character. */
      col_end = find_next_quote(line, col_start + 1, quotechar,
          curbuf->b_p_qe);
      if (col_end < 0)
        return FALSE;
      /* If is cursor between start and end quote character, it is
       * target text object. */
      if (col_start <= first_col && first_col <= col_end)
        break;
      col_start = col_end + 1;
    }
  } else {
    /* Search backward for a starting quote. */
    col_start = find_prev_quote(line, col_start, quotechar, curbuf->b_p_qe);
    if (line[col_start] != quotechar) {
      /* No quote before the cursor, look after the cursor. */
      col_start = find_next_quote(line, col_start, quotechar, NULL);
      if (col_start < 0)
        return FALSE;
    }

    /* Find close quote character. */
    col_end = find_next_quote(line, col_start + 1, quotechar,
        curbuf->b_p_qe);
    if (col_end < 0)
      return FALSE;
  }

  /* When "include" is TRUE, include spaces after closing quote or before
   * the starting quote. */
  if (include) {
    if (vim_iswhite(line[col_end + 1]))
      while (vim_iswhite(line[col_end + 1]))
        ++col_end;
    else
      while (col_start > 0 && vim_iswhite(line[col_start - 1]))
        --col_start;
  }

  /* Set start position.  After vi" another i" must include the ".
   * For v2i" include the quotes. */
  if (!include && count < 2
      && (vis_empty || !inside_quotes)
      )
    ++col_start;
  curwin->w_cursor.col = col_start;
  if (VIsual_active) {
    /* Set the start of the Visual area when the Visual area was empty, we
     * were just inside quotes or the Visual area didn't start at a quote
     * and didn't include a quote.
     */
    if (vis_empty
        || (vis_bef_curs
            && !selected_quote
            && (inside_quotes
                || (line[VIsual.col] != quotechar
                    && (VIsual.col == 0
                        || line[VIsual.col - 1] != quotechar))))) {
      VIsual = curwin->w_cursor;
      redraw_curbuf_later(INVERTED);
    }
  } else {
    oap->start = curwin->w_cursor;
    oap->motion_type = MCHAR;
  }

  /* Set end position. */
  curwin->w_cursor.col = col_end;
  if ((include || count > 1
       /* After vi" another i" must include the ". */
       || (!vis_empty && inside_quotes)
       ) && inc_cursor() == 2)
    inclusive = TRUE;
  if (VIsual_active) {
    if (vis_empty || vis_bef_curs) {
      /* decrement cursor when 'selection' is not exclusive */
      if (*p_sel != 'e')
        dec_cursor();
    } else {
      /* Cursor is at start of Visual area.  Set the end of the Visual
       * area when it was just inside quotes or it didn't end at a
       * quote. */
      if (inside_quotes
          || (!selected_quote
              && line[VIsual.col] != quotechar
              && (line[VIsual.col] == NUL
                  || line[VIsual.col + 1] != quotechar))) {
        dec_cursor();
        VIsual = curwin->w_cursor;
      }
      curwin->w_cursor.col = col_start;
    }
    if (VIsual_mode == 'V') {
      VIsual_mode = 'v';
      redraw_cmdline = TRUE;                    /* show mode later */
    }
  } else {
    /* Set inclusive and other oap's flags. */
    oap->inclusive = inclusive;
  }

  return OK;
}



/*
 * Find next search match under cursor, cursor at end.
 * Used while an operator is pending, and in Visual mode.
 * TODO: redo only works when used in operator pending mode
 */
int 
current_search (
    long count,
    int forward                    /* move forward or backwards */
)
{
  pos_T start_pos;              /* position before the pattern */
  pos_T orig_pos;               /* position of the cursor at beginning */
  pos_T pos;                    /* position after the pattern */
  int i;
  int dir;
  int result;                   /* result of various function calls */
  bool old_p_ws = p_ws;
  int flags = 0;
  pos_T save_VIsual = VIsual;
  int one_char;

  /* wrapping should not occur */
  p_ws = false;

  /* Correct cursor when 'selection' is exclusive */
  if (VIsual_active && *p_sel == 'e' && lt(VIsual, curwin->w_cursor))
    dec_cursor();

  if (VIsual_active) {
    orig_pos = curwin->w_cursor;

    pos = curwin->w_cursor;
    start_pos = VIsual;

    /* make sure, searching further will extend the match */
    if (VIsual_active) {
      if (forward)
        incl(&pos);
      else
        decl(&pos);
    }
  } else
    orig_pos = pos = start_pos = curwin->w_cursor;

  /* Is the pattern is zero-width? */
  one_char = is_one_char(spats[last_idx].pat);
  if (one_char == -1) {
    p_ws = old_p_ws;
    return FAIL;      /* pattern not found */
  }

  /*
   * The trick is to first search backwards and then search forward again,
   * so that a match at the current cursor position will be correctly
   * captured.
   */
  for (i = 0; i < 2; i++) {
    if (forward)
      dir = i;
    else
      dir = !i;

    flags = 0;
    if (!dir && !one_char)
      flags = SEARCH_END;

    result = searchit(curwin, curbuf, &pos, (dir ? FORWARD : BACKWARD),
        spats[last_idx].pat, (long) (i ? count : 1),
        SEARCH_KEEP | flags, RE_SEARCH, 0, NULL);

    /* First search may fail, but then start searching from the
     * beginning of the file (cursor might be on the search match)
     * except when Visual mode is active, so that extending the visual
     * selection works. */
    if (!result && i) {   /* not found, abort */
      curwin->w_cursor = orig_pos;
      if (VIsual_active)
        VIsual = save_VIsual;
      p_ws = old_p_ws;
      return FAIL;
    } else if (!i && !result) {
      if (forward) {     /* try again from start of buffer */
        clearpos(&pos);
      } else { /* try again from end of buffer */
                 /* searching backwards, so set pos to last line and col */
        pos.lnum = curwin->w_buffer->b_ml.ml_line_count;
        pos.col  = (colnr_T)STRLEN(
            ml_get(curwin->w_buffer->b_ml.ml_line_count));
      }
    }
    p_ws = old_p_ws;
  }

  start_pos = pos;
  flags = forward ? SEARCH_END : 0;

  /* move to match, except for zero-width matches, in which case, we are
   * already on the next match */
  if (!one_char)
    result = searchit(curwin, curbuf, &pos, (forward ? FORWARD : BACKWARD),
        spats[last_idx].pat, 0L, flags | SEARCH_KEEP, RE_SEARCH, 0, NULL);

  if (!VIsual_active)
    VIsual = start_pos;

  curwin->w_cursor = pos;
  VIsual_active = TRUE;
  VIsual_mode = 'v';

  if (VIsual_active) {
    redraw_curbuf_later(INVERTED);      /* update the inversion */
    if (*p_sel == 'e') {
      /* Correction for exclusive selection depends on the direction. */
      if (forward && ltoreq(VIsual, curwin->w_cursor))
        inc_cursor();
      else if (!forward && ltoreq(curwin->w_cursor, VIsual))
        inc(&VIsual);
    }

  }

  if (fdo_flags & FDO_SEARCH && KeyTyped)
    foldOpenCursor();

  may_start_select('c');
  setmouse();
  redraw_curbuf_later(INVERTED);
  showmode();

  return OK;
}

/*
 * Check if the pattern is one character or zero-width.
 * Returns TRUE, FALSE or -1 for failure.
 */
static int is_one_char(char_u *pattern)
{
  regmmatch_T regmatch;
  int nmatched = 0;
  int result = -1;
  pos_T pos;
  int save_called_emsg = called_emsg;

  if (search_regcomp(pattern, RE_SEARCH, RE_SEARCH,
          SEARCH_KEEP, &regmatch) == FAIL)
    return -1;

  /* move to match */
  clearpos(&pos);
  if (searchit(curwin, curbuf, &pos, FORWARD, spats[last_idx].pat, 1,
          SEARCH_KEEP, RE_SEARCH, 0, NULL) != FAIL) {
    /* Zero-width pattern should match somewhere, then we can check if
     * start and end are in the same position. */
    called_emsg = FALSE;
    nmatched = vim_regexec_multi(&regmatch, curwin, curbuf,
        pos.lnum, (colnr_T)0, NULL);

    if (!called_emsg)
      result = (nmatched != 0
                && regmatch.startpos[0].lnum == regmatch.endpos[0].lnum
                && regmatch.startpos[0].col == regmatch.endpos[0].col);

    if (!result && inc(&pos) >= 0 && pos.col == regmatch.endpos[0].col)
      result = TRUE;
  }

  called_emsg |= save_called_emsg;
  vim_regfree(regmatch.regprog);
  return result;
}

/*
 * return TRUE if line 'lnum' is empty or has white chars only.
 */
int linewhite(linenr_T lnum)
{
  char_u  *p;

  p = skipwhite(ml_get(lnum));
  return *p == NUL;
}

/*
 * Find identifiers or defines in included files.
 * If p_ic && (compl_cont_status & CONT_SOL) then ptr must be in lowercase.
 */
void 
find_pattern_in_path (
    char_u *ptr,               /* pointer to search pattern */
    int dir,                 /* direction of expansion */
    int len,                        /* length of search pattern */
    int whole,                      /* match whole words only */
    int skip_comments,              /* don't match inside comments */
    int type,                       /* Type of search; are we looking for a type?
                                   a macro? */
    long count,
    int action,                     /* What to do when we find it */
    linenr_T start_lnum,            /* first line to start searching */
    linenr_T end_lnum              /* last line for searching */
)
{
  SearchedFile *files;                  /* Stack of included files */
  SearchedFile *bigger;                 /* When we need more space */
  int max_path_depth = 50;
  long match_count = 1;

  char_u      *pat;
  char_u      *new_fname;
  char_u      *curr_fname = curbuf->b_fname;
  char_u      *prev_fname = NULL;
  linenr_T lnum;
  int depth;
  int depth_displayed;                  /* For type==CHECK_PATH */
  int old_files;
  int already_searched;
  char_u      *file_line;
  char_u      *line;
  char_u      *p;
  char_u save_char;
  int define_matched;
  regmatch_T regmatch;
  regmatch_T incl_regmatch;
  regmatch_T def_regmatch;
  int matched = FALSE;
  int did_show = FALSE;
  int found = FALSE;
  int i;
  char_u      *already = NULL;
  char_u      *startp = NULL;
  char_u      *inc_opt = NULL;
  win_T       *curwin_save = NULL;

  regmatch.regprog = NULL;
  incl_regmatch.regprog = NULL;
  def_regmatch.regprog = NULL;

  file_line = xmalloc(LSIZE);

  if (type != CHECK_PATH && type != FIND_DEFINE
      /* when CONT_SOL is set compare "ptr" with the beginning of the line
       * is faster than quote_meta/regcomp/regexec "ptr" -- Acevedo */
      && !(compl_cont_status & CONT_SOL)
      ) {
    pat = xmalloc(len + 5);
    sprintf((char *)pat, whole ? "\\<%.*s\\>" : "%.*s", len, ptr);
    /* ignore case according to p_ic, p_scs and pat */
    regmatch.rm_ic = ignorecase(pat);
    regmatch.regprog = vim_regcomp(pat, p_magic ? RE_MAGIC : 0);
    free(pat);
    if (regmatch.regprog == NULL)
      goto fpip_end;
  }
  inc_opt = (*curbuf->b_p_inc == NUL) ? p_inc : curbuf->b_p_inc;
  if (*inc_opt != NUL) {
    incl_regmatch.regprog = vim_regcomp(inc_opt, p_magic ? RE_MAGIC : 0);
    if (incl_regmatch.regprog == NULL)
      goto fpip_end;
    incl_regmatch.rm_ic = FALSE;        /* don't ignore case in incl. pat. */
  }
  if (type == FIND_DEFINE && (*curbuf->b_p_def != NUL || *p_def != NUL)) {
    def_regmatch.regprog = vim_regcomp(*curbuf->b_p_def == NUL
        ? p_def : curbuf->b_p_def, p_magic ? RE_MAGIC : 0);
    if (def_regmatch.regprog == NULL)
      goto fpip_end;
    def_regmatch.rm_ic = FALSE;         /* don't ignore case in define pat. */
  }
  files = xcalloc(max_path_depth, sizeof(SearchedFile));
  if (files == NULL)
    goto fpip_end;
  old_files = max_path_depth;
  depth = depth_displayed = -1;

  lnum = start_lnum;
  if (end_lnum > curbuf->b_ml.ml_line_count)
    end_lnum = curbuf->b_ml.ml_line_count;
  if (lnum > end_lnum)                  /* do at least one line */
    lnum = end_lnum;
  line = ml_get(lnum);

  for (;; ) {
    if (incl_regmatch.regprog != NULL
        && vim_regexec(&incl_regmatch, line, (colnr_T)0)) {
      char_u *p_fname = (curr_fname == curbuf->b_fname)
                        ? curbuf->b_ffname : curr_fname;

      if (inc_opt != NULL && strstr((char *)inc_opt, "\\zs") != NULL)
        /* Use text from '\zs' to '\ze' (or end) of 'include'. */
        new_fname = find_file_name_in_path(incl_regmatch.startp[0],
            (int)(incl_regmatch.endp[0] - incl_regmatch.startp[0]),
            FNAME_EXP|FNAME_INCL|FNAME_REL, 1L, p_fname);
      else
        /* Use text after match with 'include'. */
        new_fname = file_name_in_line(incl_regmatch.endp[0], 0,
            FNAME_EXP|FNAME_INCL|FNAME_REL, 1L, p_fname, NULL);
      already_searched = FALSE;
      if (new_fname != NULL) {
        /* Check whether we have already searched in this file */
        for (i = 0;; i++) {
          if (i == depth + 1)
            i = old_files;
          if (i == max_path_depth)
            break;
          if (path_full_compare(new_fname, files[i].name, TRUE) & kEqualFiles) {
            if (type != CHECK_PATH &&
                action == ACTION_SHOW_ALL && files[i].matched) {
              msg_putchar('\n');                    /* cursor below last one */
              if (!got_int) {                       /* don't display if 'q'
                                                       typed at "--more--"
                                                       message */
                msg_home_replace_hl(new_fname);
                MSG_PUTS(_(" (includes previously listed match)"));
                prev_fname = NULL;
              }
            }
            free(new_fname);
            new_fname = NULL;
            already_searched = TRUE;
            break;
          }
        }
      }

      if (type == CHECK_PATH && (action == ACTION_SHOW_ALL
                                 || (new_fname == NULL &&
                                     !already_searched))) {
        if (did_show)
          msg_putchar('\n');                /* cursor below last one */
        else {
          gotocmdline(TRUE);                /* cursor at status line */
          MSG_PUTS_TITLE(_("--- Included files "));
          if (action != ACTION_SHOW_ALL)
            MSG_PUTS_TITLE(_("not found "));
          MSG_PUTS_TITLE(_("in path ---\n"));
        }
        did_show = TRUE;
        while (depth_displayed < depth && !got_int) {
          ++depth_displayed;
          for (i = 0; i < depth_displayed; i++)
            MSG_PUTS("  ");
          msg_home_replace(files[depth_displayed].name);
          MSG_PUTS(" -->\n");
        }
        if (!got_int) {                     /* don't display if 'q' typed
                                               for "--more--" message */
          for (i = 0; i <= depth_displayed; i++)
            MSG_PUTS("  ");
          if (new_fname != NULL) {
            /* using "new_fname" is more reliable, e.g., when
             * 'includeexpr' is set. */
            msg_outtrans_attr(new_fname, hl_attr(HLF_D));
          } else {
            /*
             * Isolate the file name.
             * Include the surrounding "" or <> if present.
             */
            if (inc_opt != NULL
                && strstr((char *)inc_opt, "\\zs") != NULL) {
              /* pattern contains \zs, use the match */
              p = incl_regmatch.startp[0];
              i = (int)(incl_regmatch.endp[0]
                        - incl_regmatch.startp[0]);
            } else {
              /* find the file name after the end of the match */
              for (p = incl_regmatch.endp[0];
                   *p && !vim_isfilec(*p); p++)
                ;
              for (i = 0; vim_isfilec(p[i]); i++)
                ;
            }

            if (i == 0) {
              /* Nothing found, use the rest of the line. */
              p = incl_regmatch.endp[0];
              i = (int)STRLEN(p);
            }
            /* Avoid checking before the start of the line, can
             * happen if \zs appears in the regexp. */
            else if (p > line) {
              if (p[-1] == '"' || p[-1] == '<') {
                --p;
                ++i;
              }
              if (p[i] == '"' || p[i] == '>')
                ++i;
            }
            save_char = p[i];
            p[i] = NUL;
            msg_outtrans_attr(p, hl_attr(HLF_D));
            p[i] = save_char;
          }

          if (new_fname == NULL && action == ACTION_SHOW_ALL) {
            if (already_searched)
              MSG_PUTS(_("  (Already listed)"));
            else
              MSG_PUTS(_("  NOT FOUND"));
          }
        }
        out_flush();                /* output each line directly */
      }

      if (new_fname != NULL) {
        /* Push the new file onto the file stack */
        if (depth + 1 == old_files) {
          bigger = xmalloc(max_path_depth * 2 * sizeof(SearchedFile));
          for (i = 0; i <= depth; i++)
            bigger[i] = files[i];
          for (i = depth + 1; i < old_files + max_path_depth; i++) {
            bigger[i].fp = NULL;
            bigger[i].name = NULL;
            bigger[i].lnum = 0;
            bigger[i].matched = FALSE;
          }
          for (i = old_files; i < max_path_depth; i++)
            bigger[i + max_path_depth] = files[i];
          old_files += max_path_depth;
          max_path_depth *= 2;
          free(files);
          files = bigger;
        }
        if ((files[depth + 1].fp = mch_fopen((char *)new_fname, "r"))
            == NULL)
          free(new_fname);
        else {
          if (++depth == old_files) {
            // Something wrong. We will forget one of our already visited files
            // now.
            free(files[old_files].name);
            ++old_files;
          }
          files[depth].name = curr_fname = new_fname;
          files[depth].lnum = 0;
          files[depth].matched = FALSE;
          if (action == ACTION_EXPAND) {
            msg_hist_off = TRUE;                /* reset in msg_trunc_attr() */
            vim_snprintf((char*)IObuff, IOSIZE,
                _("Scanning included file: %s"),
                (char *)new_fname);
            msg_trunc_attr(IObuff, TRUE, hl_attr(HLF_R));
          } else if (p_verbose >= 5) {
            verbose_enter();
            smsg((char_u *)_("Searching included file %s"),
                (char *)new_fname);
            verbose_leave();
          }

        }
      }
    } else {
      /*
       * Check if the line is a define (type == FIND_DEFINE)
       */
      p = line;
search_line:
      define_matched = FALSE;
      if (def_regmatch.regprog != NULL
          && vim_regexec(&def_regmatch, line, (colnr_T)0)) {
        /*
         * Pattern must be first identifier after 'define', so skip
         * to that position before checking for match of pattern.  Also
         * don't let it match beyond the end of this identifier.
         */
        p = def_regmatch.endp[0];
        while (*p && !vim_iswordc(*p))
          p++;
        define_matched = TRUE;
      }

      /*
       * Look for a match.  Don't do this if we are looking for a
       * define and this line didn't match define_prog above.
       */
      if (def_regmatch.regprog == NULL || define_matched) {
        if (define_matched
            || (compl_cont_status & CONT_SOL)
            ) {
          /* compare the first "len" chars from "ptr" */
          startp = skipwhite(p);
          if (p_ic)
            matched = !MB_STRNICMP(startp, ptr, len);
          else
            matched = !STRNCMP(startp, ptr, len);
          if (matched && define_matched && whole
              && vim_iswordc(startp[len]))
            matched = FALSE;
        } else if (regmatch.regprog != NULL
                   && vim_regexec(&regmatch, line, (colnr_T)(p - line))) {
          matched = TRUE;
          startp = regmatch.startp[0];
          /*
           * Check if the line is not a comment line (unless we are
           * looking for a define).  A line starting with "# define"
           * is not considered to be a comment line.
           */
          if (!define_matched && skip_comments) {
            if ((*line != '#' ||
                 STRNCMP(skipwhite(line + 1), "define", 6) != 0)
                && get_leader_len(line, NULL, FALSE, TRUE))
              matched = FALSE;

            /*
             * Also check for a "/ *" or "/ /" before the match.
             * Skips lines like "int backwards;  / * normal index
             * * /" when looking for "normal".
             * Note: Doesn't skip "/ *" in comments.
             */
            p = skipwhite(line);
            if (matched
                || (p[0] == '/' && p[1] == '*') || p[0] == '*')
              for (p = line; *p && p < startp; ++p) {
                if (matched
                    && p[0] == '/'
                    && (p[1] == '*' || p[1] == '/')) {
                  matched = FALSE;
                  /* After "//" all text is comment */
                  if (p[1] == '/')
                    break;
                  ++p;
                } else if (!matched && p[0] == '*' && p[1] == '/') {
                  /* Can find match after "* /". */
                  matched = TRUE;
                  ++p;
                }
              }
          }
        }
      }
    }
    if (matched) {
      if (action == ACTION_EXPAND) {
        int reuse = 0;
        int add_r;
        char_u  *aux;

        if (depth == -1 && lnum == curwin->w_cursor.lnum)
          break;
        found = TRUE;
        aux = p = startp;
        if (compl_cont_status & CONT_ADDING) {
          p += compl_length;
          if (vim_iswordp(p))
            goto exit_matched;
          p = find_word_start(p);
        }
        p = find_word_end(p);
        i = (int)(p - aux);

        if ((compl_cont_status & CONT_ADDING) && i == compl_length) {
          /* IOSIZE > compl_length, so the STRNCPY works */
          STRNCPY(IObuff, aux, i);

          /* Get the next line: when "depth" < 0  from the current
           * buffer, otherwise from the included file.  Jump to
           * exit_matched when past the last line. */
          if (depth < 0) {
            if (lnum >= end_lnum)
              goto exit_matched;
            line = ml_get(++lnum);
          } else if (vim_fgets(line = file_line,
                         LSIZE, files[depth].fp))
            goto exit_matched;

          /* we read a line, set "already" to check this "line" later
           * if depth >= 0 we'll increase files[depth].lnum far
           * bellow  -- Acevedo */
          already = aux = p = skipwhite(line);
          p = find_word_start(p);
          p = find_word_end(p);
          if (p > aux) {
            if (*aux != ')' && IObuff[i-1] != TAB) {
              if (IObuff[i-1] != ' ')
                IObuff[i++] = ' ';
              /* IObuf =~ "\(\k\|\i\).* ", thus i >= 2*/
              if (p_js
                  && (IObuff[i-2] == '.'
                      || (vim_strchr(p_cpo, CPO_JOINSP) == NULL
                          && (IObuff[i-2] == '?'
                              || IObuff[i-2] == '!'))))
                IObuff[i++] = ' ';
            }
            /* copy as much as possible of the new word */
            if (p - aux >= IOSIZE - i)
              p = aux + IOSIZE - i - 1;
            STRNCPY(IObuff + i, aux, p - aux);
            i += (int)(p - aux);
            reuse |= CONT_S_IPOS;
          }
          IObuff[i] = NUL;
          aux = IObuff;

          if (i == compl_length)
            goto exit_matched;
        }

        add_r = ins_compl_add_infercase(aux, i, p_ic,
            curr_fname == curbuf->b_fname ? NULL : curr_fname,
            dir, reuse);
        if (add_r == OK)
          /* if dir was BACKWARD then honor it just once */
          dir = FORWARD;
        else if (add_r == FAIL)
          break;
      } else if (action == ACTION_SHOW_ALL) {
        found = TRUE;
        if (!did_show)
          gotocmdline(TRUE);                    /* cursor at status line */
        if (curr_fname != prev_fname) {
          if (did_show)
            msg_putchar('\n');                  /* cursor below last one */
          if (!got_int)                         /* don't display if 'q' typed
                                                    at "--more--" message */
            msg_home_replace_hl(curr_fname);
          prev_fname = curr_fname;
        }
        did_show = TRUE;
        if (!got_int)
          show_pat_in_path(line, type, TRUE, action,
              (depth == -1) ? NULL : files[depth].fp,
              (depth == -1) ? &lnum : &files[depth].lnum,
              match_count++);

        /* Set matched flag for this file and all the ones that
         * include it */
        for (i = 0; i <= depth; ++i)
          files[i].matched = TRUE;
      } else if (--count <= 0) {
        found = TRUE;
        if (depth == -1 && lnum == curwin->w_cursor.lnum
            && g_do_tagpreview == 0
            )
          EMSG(_("E387: Match is on current line"));
        else if (action == ACTION_SHOW) {
          show_pat_in_path(line, type, did_show, action,
              (depth == -1) ? NULL : files[depth].fp,
              (depth == -1) ? &lnum : &files[depth].lnum, 1L);
          did_show = TRUE;
        } else {
          /* ":psearch" uses the preview window */
          if (g_do_tagpreview != 0) {
            curwin_save = curwin;
            prepare_tagpreview(true);
          }
          if (action == ACTION_SPLIT) {
            if (win_split(0, 0) == FAIL)
              break;
            RESET_BINDING(curwin);
          }
          if (depth == -1) {
            /* match in current file */
            if (g_do_tagpreview != 0) {
              if (getfile(0, curwin_save->w_buffer->b_fname,
                      NULL, TRUE, lnum, FALSE) > 0)
                break;                  /* failed to jump to file */
            } else
              setpcmark();
            curwin->w_cursor.lnum = lnum;
          } else {
            if (getfile(0, files[depth].name, NULL, TRUE,
                    files[depth].lnum, FALSE) > 0)
              break;                    /* failed to jump to file */
            /* autocommands may have changed the lnum, we don't
             * want that here */
            curwin->w_cursor.lnum = files[depth].lnum;
          }
        }
        if (action != ACTION_SHOW) {
          curwin->w_cursor.col = (colnr_T)(startp - line);
          curwin->w_set_curswant = TRUE;
        }

        if (g_do_tagpreview != 0
            && curwin != curwin_save && win_valid(curwin_save)) {
          /* Return cursor to where we were */
          validate_cursor();
          redraw_later(VALID);
          win_enter(curwin_save, true);
        }
        break;
      }
exit_matched:
      matched = FALSE;
      /* look for other matches in the rest of the line if we
       * are not at the end of it already */
      if (def_regmatch.regprog == NULL
          && action == ACTION_EXPAND
          && !(compl_cont_status & CONT_SOL)
          && *startp != NUL
          && *(p = startp + MB_PTR2LEN(startp)) != NUL)
        goto search_line;
    }
    line_breakcheck();
    if (action == ACTION_EXPAND)
      ins_compl_check_keys(30);
    if (got_int || compl_interrupted)
      break;

    /*
     * Read the next line.  When reading an included file and encountering
     * end-of-file, close the file and continue in the file that included
     * it.
     */
    while (depth >= 0 && !already
           && vim_fgets(line = file_line, LSIZE, files[depth].fp)) {
      fclose(files[depth].fp);
      --old_files;
      files[old_files].name = files[depth].name;
      files[old_files].matched = files[depth].matched;
      --depth;
      curr_fname = (depth == -1) ? curbuf->b_fname
                   : files[depth].name;
      if (depth < depth_displayed)
        depth_displayed = depth;
    }
    if (depth >= 0) {           /* we could read the line */
      files[depth].lnum++;
      /* Remove any CR and LF from the line. */
      i = (int)STRLEN(line);
      if (i > 0 && line[i - 1] == '\n')
        line[--i] = NUL;
      if (i > 0 && line[i - 1] == '\r')
        line[--i] = NUL;
    } else if (!already) {
      if (++lnum > end_lnum)
        break;
      line = ml_get(lnum);
    }
    already = NULL;
  }
  /* End of big for (;;) loop. */

  /* Close any files that are still open. */
  for (i = 0; i <= depth; i++) {
    fclose(files[i].fp);
    free(files[i].name);
  }
  for (i = old_files; i < max_path_depth; i++)
    free(files[i].name);
  free(files);

  if (type == CHECK_PATH) {
    if (!did_show) {
      if (action != ACTION_SHOW_ALL)
        MSG(_("All included files were found"));
      else
        MSG(_("No included files"));
    }
  } else if (!found
             && action != ACTION_EXPAND
             ) {
    if (got_int || compl_interrupted)
      EMSG(_(e_interr));
    else if (type == FIND_DEFINE)
      EMSG(_("E388: Couldn't find definition"));
    else
      EMSG(_("E389: Couldn't find pattern"));
  }
  if (action == ACTION_SHOW || action == ACTION_SHOW_ALL)
    msg_end();

fpip_end:
  free(file_line);
  vim_regfree(regmatch.regprog);
  vim_regfree(incl_regmatch.regprog);
  vim_regfree(def_regmatch.regprog);
}

static void show_pat_in_path(char_u *line, int type, int did_show, int action, FILE *fp, linenr_T *lnum, long count)
{
  char_u  *p;

  if (did_show)
    msg_putchar('\n');          /* cursor below last one */
  else if (!msg_silent)
    gotocmdline(TRUE);          /* cursor at status line */
  if (got_int)                  /* 'q' typed at "--more--" message */
    return;
  for (;; ) {
    p = line + STRLEN(line) - 1;
    if (fp != NULL) {
      /* We used fgets(), so get rid of newline at end */
      if (p >= line && *p == '\n')
        --p;
      if (p >= line && *p == '\r')
        --p;
      *(p + 1) = NUL;
    }
    if (action == ACTION_SHOW_ALL) {
      sprintf((char *)IObuff, "%3ld: ", count);         /* show match nr */
      msg_puts(IObuff);
      sprintf((char *)IObuff, "%4ld", *lnum);           /* show line nr */
      /* Highlight line numbers */
      msg_puts_attr(IObuff, hl_attr(HLF_N));
      MSG_PUTS(" ");
    }
    msg_prt_line(line, FALSE);
    out_flush();                        /* show one line at a time */

    /* Definition continues until line that doesn't end with '\' */
    if (got_int || type != FIND_DEFINE || p < line || *p != '\\')
      break;

    if (fp != NULL) {
      if (vim_fgets(line, LSIZE, fp))       /* end of file */
        break;
      ++*lnum;
    } else {
      if (++*lnum > curbuf->b_ml.ml_line_count)
        break;
      line = ml_get(*lnum);
    }
    msg_putchar('\n');
  }
}

int read_viminfo_search_pattern(vir_T *virp, int force)
{
  char_u      *lp;
  int idx = -1;
  int magic = FALSE;
  int no_scs = FALSE;
  int off_line = FALSE;
  int off_end = 0;
  long off = 0;
  int setlast = FALSE;
  static int hlsearch_on = FALSE;
  char_u      *val;

  /*
   * Old line types:
   * "/pat", "&pat": search/subst. pat
   * "~/pat", "~&pat": last used search/subst. pat
   * New line types:
   * "~h", "~H": hlsearch highlighting off/on
   * "~<magic><smartcase><line><end><off><last><which>pat"
   * <magic>: 'm' off, 'M' on
   * <smartcase>: 's' off, 'S' on
   * <line>: 'L' line offset, 'l' char offset
   * <end>: 'E' from end, 'e' from start
   * <off>: decimal, offset
   * <last>: '~' last used pattern
   * <which>: '/' search pat, '&' subst. pat
   */
  lp = virp->vir_line;
  if (lp[0] == '~' && (lp[1] == 'm' || lp[1] == 'M')) { /* new line type */
    if (lp[1] == 'M')                   /* magic on */
      magic = TRUE;
    if (lp[2] == 's')
      no_scs = TRUE;
    if (lp[3] == 'L')
      off_line = TRUE;
    if (lp[4] == 'E')
      off_end = SEARCH_END;
    lp += 5;
    off = getdigits(&lp);
  }
  if (lp[0] == '~') {           /* use this pattern for last-used pattern */
    setlast = TRUE;
    lp++;
  }
  if (lp[0] == '/')
    idx = RE_SEARCH;
  else if (lp[0] == '&')
    idx = RE_SUBST;
  else if (lp[0] == 'h')        /* ~h: 'hlsearch' highlighting off */
    hlsearch_on = FALSE;
  else if (lp[0] == 'H')        /* ~H: 'hlsearch' highlighting on */
    hlsearch_on = TRUE;
  if (idx >= 0) {
    if (force || spats[idx].pat == NULL) {
      val = viminfo_readstring(virp, (int)(lp - virp->vir_line + 1),
          TRUE);
      if (val != NULL) {
        set_last_search_pat(val, idx, magic, setlast);
        free(val);
        spats[idx].no_scs = no_scs;
        spats[idx].off.line = off_line;
        spats[idx].off.end = off_end;
        spats[idx].off.off = off;
        if (setlast) {
          SET_NO_HLSEARCH(!hlsearch_on);
        }
      }
    }
  }
  return viminfo_readline(virp);
}

void write_viminfo_search_pattern(FILE *fp)
{
  if (get_viminfo_parameter('/') != 0) {
    fprintf(fp, "\n# hlsearch on (H) or off (h):\n~%c",
        (no_hlsearch || find_viminfo_parameter('h') != NULL) ? 'h' : 'H');
    wvsp_one(fp, RE_SEARCH, "", '/');
    wvsp_one(fp, RE_SUBST, _("Substitute "), '&');
  }
}

static void 
wvsp_one (
    FILE *fp,        /* file to write to */
    int idx,                /* spats[] index */
    char *s,         /* search pat */
    int sc                 /* dir char */
)
{
  if (spats[idx].pat != NULL) {
    fprintf(fp, _("\n# Last %sSearch Pattern:\n~"), s);
    /* off.dir is not stored, it's reset to forward */
    fprintf(fp, "%c%c%c%c%" PRId64 "%s%c",
        spats[idx].magic    ? 'M' : 'm',                /* magic */
        spats[idx].no_scs   ? 's' : 'S',                /* smartcase */
        spats[idx].off.line ? 'L' : 'l',                /* line offset */
        spats[idx].off.end  ? 'E' : 'e',                /* offset from end */
        (int64_t)spats[idx].off.off,                    /* offset */
        last_idx == idx     ? "~" : "",                 /* last used pat */
        sc);
    viminfo_writestring(fp, spats[idx].pat);
  }
}
