// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// match.c: functions for highlighting matches

#include <stdbool.h>

#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/fold.h"
#include "nvim/highlight_group.h"
#include "nvim/match.h"
#include "nvim/memline.h"
#include "nvim/regexp.h"
#include "nvim/runtime.h"
#include "nvim/screen.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "match.c.generated.h"
#endif

static char *e_invalwindow = N_("E957: Invalid window number");

#define SEARCH_HL_PRIORITY 0

/// Add match to the match list of window 'wp'.  The pattern 'pat' will be
/// highlighted with the group 'grp' with priority 'prio'.
/// Optionally, a desired ID 'id' can be specified (greater than or equal to 1).
///
/// @param[in] id a desired ID 'id' can be specified
///               (greater than or equal to 1). -1 must be specified if no
///               particular ID is desired
/// @param[in] conceal_char pointer to conceal replacement char
/// @return ID of added match, -1 on failure.
static int match_add(win_T *wp, const char *const grp, const char *const pat, int prio, int id,
                     list_T *pos_list, const char *const conceal_char)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  matchitem_T *cur;
  matchitem_T *prev;
  matchitem_T *m;
  int hlg_id;
  regprog_T *regprog = NULL;
  int rtype = SOME_VALID;

  if (*grp == NUL || (pat != NULL && *pat == NUL)) {
    return -1;
  }
  if (id < -1 || id == 0) {
    semsg(_("E799: Invalid ID: %" PRId64
            " (must be greater than or equal to 1)"),
          (int64_t)id);
    return -1;
  }
  if (id != -1) {
    cur = wp->w_match_head;
    while (cur != NULL) {
      if (cur->id == id) {
        semsg(_("E801: ID already taken: %" PRId64), (int64_t)id);
        return -1;
      }
      cur = cur->next;
    }
  }
  if ((hlg_id = syn_check_group(grp, strlen(grp))) == 0) {
    return -1;
  }
  if (pat != NULL && (regprog = vim_regcomp((char *)pat, RE_MAGIC)) == NULL) {
    semsg(_(e_invarg2), pat);
    return -1;
  }

  // Find available match ID.
  while (id == -1) {
    cur = wp->w_match_head;
    while (cur != NULL && cur->id != wp->w_next_match_id) {
      cur = cur->next;
    }
    if (cur == NULL) {
      id = wp->w_next_match_id;
    }
    wp->w_next_match_id++;
  }

  // Build new match.
  m = xcalloc(1, sizeof(matchitem_T));
  m->id = id;
  m->priority = prio;
  m->pattern = pat == NULL ? NULL: (char_u *)xstrdup(pat);
  m->hlg_id = hlg_id;
  m->match.regprog = regprog;
  m->match.rmm_ic = false;
  m->match.rmm_maxcol = 0;
  m->conceal_char = 0;
  if (conceal_char != NULL) {
    m->conceal_char = utf_ptr2char(conceal_char);
  }

  // Set up position matches
  if (pos_list != NULL) {
    linenr_T toplnum = 0;
    linenr_T botlnum = 0;

    int i = 0;
    TV_LIST_ITER(pos_list, li, {
      linenr_T lnum = 0;
      colnr_T col = 0;
      int len = 1;
      bool error = false;

      if (TV_LIST_ITEM_TV(li)->v_type == VAR_LIST) {
        const list_T *const subl = TV_LIST_ITEM_TV(li)->vval.v_list;
        const listitem_T *subli = tv_list_first(subl);
        if (subli == NULL) {
          semsg(_("E5030: Empty list at position %d"),
                (int)tv_list_idx_of_item(pos_list, li));
          goto fail;
        }
        lnum = tv_get_number_chk(TV_LIST_ITEM_TV(subli), &error);
        if (error) {
          goto fail;
        }
        if (lnum <= 0) {
          continue;
        }
        m->pos.pos[i].lnum = lnum;
        subli = TV_LIST_ITEM_NEXT(subl, subli);
        if (subli != NULL) {
          col = (colnr_T)tv_get_number_chk(TV_LIST_ITEM_TV(subli), &error);
          if (error) {
            goto fail;
          }
          if (col < 0) {
            continue;
          }
          subli = TV_LIST_ITEM_NEXT(subl, subli);
          if (subli != NULL) {
            len = (colnr_T)tv_get_number_chk(TV_LIST_ITEM_TV(subli), &error);
            if (len < 0) {
              continue;
            }
            if (error) {
              goto fail;
            }
          }
        }
        m->pos.pos[i].col = col;
        m->pos.pos[i].len = len;
      } else if (TV_LIST_ITEM_TV(li)->v_type == VAR_NUMBER) {
        if (TV_LIST_ITEM_TV(li)->vval.v_number <= 0) {
          continue;
        }
        m->pos.pos[i].lnum = TV_LIST_ITEM_TV(li)->vval.v_number;
        m->pos.pos[i].col = 0;
        m->pos.pos[i].len = 0;
      } else {
        semsg(_("E5031: List or number required at position %d"),
              (int)tv_list_idx_of_item(pos_list, li));
        goto fail;
      }
      if (toplnum == 0 || lnum < toplnum) {
        toplnum = lnum;
      }
      if (botlnum == 0 || lnum >= botlnum) {
        botlnum = lnum + 1;
      }
      i++;
      if (i >= MAXPOSMATCH) {
        break;
      }
    });

    // Calculate top and bottom lines for redrawing area
    if (toplnum != 0) {
      if (wp->w_buffer->b_mod_set) {
        if (wp->w_buffer->b_mod_top > toplnum) {
          wp->w_buffer->b_mod_top = toplnum;
        }
        if (wp->w_buffer->b_mod_bot < botlnum) {
          wp->w_buffer->b_mod_bot = botlnum;
        }
      } else {
        wp->w_buffer->b_mod_set = true;
        wp->w_buffer->b_mod_top = toplnum;
        wp->w_buffer->b_mod_bot = botlnum;
        wp->w_buffer->b_mod_xlines = 0;
      }
      m->pos.toplnum = toplnum;
      m->pos.botlnum = botlnum;
      rtype = VALID;
    }
  }

  // Insert new match.  The match list is in ascending order with regard to
  // the match priorities.
  cur = wp->w_match_head;
  prev = cur;
  while (cur != NULL && prio >= cur->priority) {
    prev = cur;
    cur = cur->next;
  }
  if (cur == prev) {
    wp->w_match_head = m;
  } else {
    prev->next = m;
  }
  m->next = cur;

  redraw_later(wp, rtype);
  return id;

fail:
  xfree(m);
  return -1;
}

/// Delete match with ID 'id' in the match list of window 'wp'.
///
/// @param perr  print error messages if true.
static int match_delete(win_T *wp, int id, bool perr)
{
  matchitem_T *cur = wp->w_match_head;
  matchitem_T *prev = cur;
  int rtype = SOME_VALID;

  if (id < 1) {
    if (perr) {
      semsg(_("E802: Invalid ID: %" PRId64
              " (must be greater than or equal to 1)"),
            (int64_t)id);
    }
    return -1;
  }
  while (cur != NULL && cur->id != id) {
    prev = cur;
    cur = cur->next;
  }
  if (cur == NULL) {
    if (perr) {
      semsg(_("E803: ID not found: %" PRId64), (int64_t)id);
    }
    return -1;
  }
  if (cur == prev) {
    wp->w_match_head = cur->next;
  } else {
    prev->next = cur->next;
  }
  vim_regfree(cur->match.regprog);
  xfree(cur->pattern);
  if (cur->pos.toplnum != 0) {
    if (wp->w_buffer->b_mod_set) {
      if (wp->w_buffer->b_mod_top > cur->pos.toplnum) {
        wp->w_buffer->b_mod_top = cur->pos.toplnum;
      }
      if (wp->w_buffer->b_mod_bot < cur->pos.botlnum) {
        wp->w_buffer->b_mod_bot = cur->pos.botlnum;
      }
    } else {
      wp->w_buffer->b_mod_set = true;
      wp->w_buffer->b_mod_top = cur->pos.toplnum;
      wp->w_buffer->b_mod_bot = cur->pos.botlnum;
      wp->w_buffer->b_mod_xlines = 0;
    }
    rtype = VALID;
  }
  xfree(cur);
  redraw_later(wp, rtype);
  return 0;
}

/// Delete all matches in the match list of window 'wp'.
void clear_matches(win_T *wp)
{
  matchitem_T *m;

  while (wp->w_match_head != NULL) {
    m = wp->w_match_head->next;
    vim_regfree(wp->w_match_head->match.regprog);
    xfree(wp->w_match_head->pattern);
    xfree(wp->w_match_head);
    wp->w_match_head = m;
  }
  redraw_later(wp, SOME_VALID);
}

/// Get match from ID 'id' in window 'wp'.
/// Return NULL if match not found.
matchitem_T *get_match(win_T *wp, int id)
{
  matchitem_T *cur = wp->w_match_head;

  while (cur != NULL && cur->id != id) {
    cur = cur->next;
  }
  return cur;
}

/// Init for calling prepare_search_hl().
void init_search_hl(win_T *wp, match_T *search_hl)
  FUNC_ATTR_NONNULL_ALL
{
  // Setup for match and 'hlsearch' highlighting.  Disable any previous
  // match
  matchitem_T *cur = wp->w_match_head;
  while (cur != NULL) {
    cur->hl.rm = cur->match;
    if (cur->hlg_id == 0) {
      cur->hl.attr = 0;
    } else {
      cur->hl.attr = syn_id2attr(cur->hlg_id);
    }
    cur->hl.buf = wp->w_buffer;
    cur->hl.lnum = 0;
    cur->hl.first_lnum = 0;
    // Set the time limit to 'redrawtime'.
    cur->hl.tm = profile_setlimit(p_rdt);
    cur = cur->next;
  }
  search_hl->buf = wp->w_buffer;
  search_hl->lnum = 0;
  search_hl->first_lnum = 0;
  search_hl->attr = win_hl_attr(wp, HLF_L);

  // time limit is set at the toplevel, for all windows
}

/// @param shl       points to a match. Fill on match.
/// @param posmatch  match positions
/// @param mincol    minimal column for a match
///
/// @return one on match, otherwise return zero.
static int next_search_hl_pos(match_T *shl, linenr_T lnum, posmatch_T *posmatch, colnr_T mincol)
  FUNC_ATTR_NONNULL_ALL
{
  int i;
  int found = -1;

  shl->lnum = 0;
  for (i = posmatch->cur; i < MAXPOSMATCH; i++) {
    llpos_T *pos = &posmatch->pos[i];

    if (pos->lnum == 0) {
      break;
    }
    if (pos->len == 0 && pos->col < mincol) {
      continue;
    }
    if (pos->lnum == lnum) {
      if (found >= 0) {
        // if this match comes before the one at "found" then swap
        // them
        if (pos->col < posmatch->pos[found].col) {
          llpos_T tmp = *pos;

          *pos = posmatch->pos[found];
          posmatch->pos[found] = tmp;
        }
      } else {
        found = i;
      }
    }
  }
  posmatch->cur = 0;
  if (found >= 0) {
    colnr_T start = posmatch->pos[found].col == 0
                    ? 0: posmatch->pos[found].col - 1;
    colnr_T end = posmatch->pos[found].col == 0
                  ? MAXCOL : start + posmatch->pos[found].len;

    shl->lnum = lnum;
    shl->rm.startpos[0].lnum = 0;
    shl->rm.startpos[0].col = start;
    shl->rm.endpos[0].lnum = 0;
    shl->rm.endpos[0].col = end;
    shl->is_addpos = true;
    shl->has_cursor = false;
    posmatch->cur = found + 1;
    return 1;
  }
  return 0;
}

/// Search for a next 'hlsearch' or match.
/// Uses shl->buf.
/// Sets shl->lnum and shl->rm contents.
/// Note: Assumes a previous match is always before "lnum", unless
/// shl->lnum is zero.
/// Careful: Any pointers for buffer lines will become invalid.
///
/// @param shl     points to search_hl or a match
/// @param mincol  minimal column for a match
/// @param cur     to retrieve match positions if any
static void next_search_hl(win_T *win, match_T *search_hl, match_T *shl, linenr_T lnum,
                           colnr_T mincol, matchitem_T *cur)
  FUNC_ATTR_NONNULL_ARG(2)
{
  linenr_T l;
  colnr_T matchcol;
  long nmatched = 0;
  int save_called_emsg = called_emsg;

  // for :{range}s/pat only highlight inside the range
  if (lnum < search_first_line || lnum > search_last_line) {
    shl->lnum = 0;
    return;
  }

  if (shl->lnum != 0) {
    // Check for three situations:
    // 1. If the "lnum" is below a previous match, start a new search.
    // 2. If the previous match includes "mincol", use it.
    // 3. Continue after the previous match.
    l = shl->lnum + shl->rm.endpos[0].lnum - shl->rm.startpos[0].lnum;
    if (lnum > l) {
      shl->lnum = 0;
    } else if (lnum < l || shl->rm.endpos[0].col > mincol) {
      return;
    }
  }

  // Repeat searching for a match until one is found that includes "mincol"
  // or none is found in this line.
  called_emsg = false;
  for (;;) {
    // Stop searching after passing the time limit.
    if (profile_passed_limit(shl->tm)) {
      shl->lnum = 0;                    // no match found in time
      break;
    }
    // Three situations:
    // 1. No useful previous match: search from start of line.
    // 2. Not Vi compatible or empty match: continue at next character.
    //    Break the loop if this is beyond the end of the line.
    // 3. Vi compatible searching: continue at end of previous match.
    if (shl->lnum == 0) {
      matchcol = 0;
    } else if (vim_strchr(p_cpo, CPO_SEARCH) == NULL
               || (shl->rm.endpos[0].lnum == 0
                   && shl->rm.endpos[0].col <= shl->rm.startpos[0].col)) {
      char_u *ml;

      matchcol = shl->rm.startpos[0].col;
      ml = ml_get_buf(shl->buf, lnum, false) + matchcol;
      if (*ml == NUL) {
        matchcol++;
        shl->lnum = 0;
        break;
      }
      matchcol += utfc_ptr2len((char *)ml);
    } else {
      matchcol = shl->rm.endpos[0].col;
    }

    shl->lnum = lnum;
    if (shl->rm.regprog != NULL) {
      // Remember whether shl->rm is using a copy of the regprog in
      // cur->match.
      bool regprog_is_copy = (shl != search_hl
                              && cur != NULL
                              && shl == &cur->hl
                              && cur->match.regprog == cur->hl.rm.regprog);
      int timed_out = false;

      nmatched = vim_regexec_multi(&shl->rm, win, shl->buf, lnum, matchcol,
                                   &(shl->tm), &timed_out);
      // Copy the regprog, in case it got freed and recompiled.
      if (regprog_is_copy) {
        cur->match.regprog = cur->hl.rm.regprog;
      }
      if (called_emsg || got_int || timed_out) {
        // Error while handling regexp: stop using this regexp.
        if (shl == search_hl) {
          // don't free regprog in the match list, it's a copy
          vim_regfree(shl->rm.regprog);
          set_no_hlsearch(true);
        }
        shl->rm.regprog = NULL;
        shl->lnum = 0;
        got_int = false;  // avoid the "Type :quit to exit Vim" message
        break;
      }
    } else if (cur != NULL) {
      nmatched = next_search_hl_pos(shl, lnum, &(cur->pos), matchcol);
    }
    if (nmatched == 0) {
      shl->lnum = 0;                    // no match found
      break;
    }
    if (shl->rm.startpos[0].lnum > 0
        || shl->rm.startpos[0].col >= mincol
        || nmatched > 1
        || shl->rm.endpos[0].col > mincol) {
      shl->lnum += shl->rm.startpos[0].lnum;
      break;                            // useful match found
    }

    // Restore called_emsg for assert_fails().
    called_emsg = save_called_emsg;
  }
}

/// Advance to the match in window "wp" line "lnum" or past it.
void prepare_search_hl(win_T *wp, match_T *search_hl, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  matchitem_T *cur;       // points to the match list
  match_T *shl;       // points to search_hl or a match
  bool shl_flag;  // flag to indicate whether search_hl
                  // has been processed or not

  // When using a multi-line pattern, start searching at the top
  // of the window or just after a closed fold.
  // Do this both for search_hl and the match list.
  cur = wp->w_match_head;
  shl_flag = false;
  while (cur != NULL || shl_flag == false) {
    if (shl_flag == false) {
      shl = search_hl;
      shl_flag = true;
    } else {
      shl = &cur->hl;  // -V595
    }
    if (shl->rm.regprog != NULL
        && shl->lnum == 0
        && re_multiline(shl->rm.regprog)) {
      if (shl->first_lnum == 0) {
        for (shl->first_lnum = lnum;
             shl->first_lnum > wp->w_topline;
             shl->first_lnum--) {
          if (hasFoldingWin(wp, shl->first_lnum - 1, NULL, NULL, true, NULL)) {
            break;
          }
        }
      }
      if (cur != NULL) {
        cur->pos.cur = 0;
      }
      bool pos_inprogress = true;  // mark that a position match search is
                                   // in progress
      int n = 0;
      while (shl->first_lnum < lnum && (shl->rm.regprog != NULL
                                        || (cur != NULL && pos_inprogress))) {
        next_search_hl(wp, search_hl, shl, shl->first_lnum, (colnr_T)n,
                       shl == search_hl ? NULL : cur);
        pos_inprogress = !(cur == NULL || cur->pos.cur == 0);
        if (shl->lnum != 0) {
          shl->first_lnum = shl->lnum
                            + shl->rm.endpos[0].lnum
                            - shl->rm.startpos[0].lnum;
          n = shl->rm.endpos[0].col;
        } else {
          shl->first_lnum++;
          n = 0;
        }
      }
    }
    if (shl != search_hl && cur != NULL) {
      cur = cur->next;
    }
  }
}

/// Update "shl->has_cursor" based on the match in "shl" and the cursor
/// position.
static void check_cur_search_hl(win_T *wp, match_T *shl)
{
  linenr_T linecount = shl->rm.endpos[0].lnum - shl->rm.startpos[0].lnum;

  if (wp->w_cursor.lnum >= shl->lnum
      && wp->w_cursor.lnum <= shl->lnum + linecount
      && (wp->w_cursor.lnum > shl->lnum || wp->w_cursor.col >= shl->rm.startpos[0].col)
      && (wp->w_cursor.lnum < shl->lnum + linecount || wp->w_cursor.col < shl->rm.endpos[0].col)) {
    shl->has_cursor = true;
  } else {
    shl->has_cursor = false;
  }
}

/// Prepare for 'hlsearch' and match highlighting in one window line.
/// Return true if there is such highlighting and set "search_attr" to the
/// current highlight attribute.
bool prepare_search_hl_line(win_T *wp, linenr_T lnum, colnr_T mincol, char_u **line,
                            match_T *search_hl, int *search_attr, bool *search_attr_from_match)
{
  matchitem_T *cur = wp->w_match_head;  // points to the match list
  match_T *shl;                     // points to search_hl or a match
  bool shl_flag = false;        // flag to indicate whether search_hl
                                // has been processed or not
  bool area_highlighting = false;

  // Handle highlighting the last used search pattern and matches.
  // Do this for both search_hl and the match list.
  while (cur != NULL || !shl_flag) {
    if (!shl_flag) {
      shl = search_hl;
      shl_flag = true;
    } else {
      shl = &cur->hl;  // -V595
    }
    shl->startcol = MAXCOL;
    shl->endcol = MAXCOL;
    shl->attr_cur = 0;
    shl->is_addpos = false;
    shl->has_cursor = false;
    if (cur != NULL) {
      cur->pos.cur = 0;
    }
    next_search_hl(wp, search_hl, shl, lnum, mincol,
                   shl == search_hl ? NULL : cur);

    // Need to get the line again, a multi-line regexp may have made it
    // invalid.
    *line = ml_get_buf(wp->w_buffer, lnum, false);

    if (shl->lnum != 0 && shl->lnum <= lnum) {
      if (shl->lnum == lnum) {
        shl->startcol = shl->rm.startpos[0].col;
      } else {
        shl->startcol = 0;
      }
      if (lnum == shl->lnum + shl->rm.endpos[0].lnum
          - shl->rm.startpos[0].lnum) {
        shl->endcol = shl->rm.endpos[0].col;
      } else {
        shl->endcol = MAXCOL;
      }

      // check if the cursor is in the match before changing the columns
      if (shl == search_hl) {
        check_cur_search_hl(wp, shl);
      }

      // Highlight one character for an empty match.
      if (shl->startcol == shl->endcol) {
        if ((*line)[shl->endcol] != NUL) {
          shl->endcol += utfc_ptr2len((char *)(*line) + shl->endcol);
        } else {
          shl->endcol++;
        }
      }
      if ((long)shl->startcol < mincol) {   // match at leftcol
        shl->attr_cur = shl->attr;
        *search_attr = shl->attr;
        *search_attr_from_match = shl != search_hl;
      }
      area_highlighting = true;
    }
    if (shl != search_hl && cur != NULL) {
      cur = cur->next;
    }
  }
  return area_highlighting;
}

/// For a position in a line: Check for start/end of 'hlsearch' and other
/// matches.
/// After end, check for start/end of next match.
/// When another match, have to check for start again.
/// Watch out for matching an empty string!
/// Return the updated search_attr.
int update_search_hl(win_T *wp, linenr_T lnum, colnr_T col, char_u **line, match_T *search_hl,
                     int *has_match_conc, int *match_conc, int lcs_eol_one,
                     bool *search_attr_from_match)
{
  matchitem_T *cur = wp->w_match_head;  // points to the match list
  match_T *shl;                     // points to search_hl or a match
  bool shl_flag = false;        // flag to indicate whether search_hl
                                // has been processed or not
  int search_attr = 0;

  // Do this for 'search_hl' and the match list (ordered by priority).
  while (cur != NULL || !shl_flag) {
    if (!shl_flag
        && (cur == NULL || cur->priority > SEARCH_HL_PRIORITY)) {
      shl = search_hl;
      shl_flag = true;
    } else {
      shl = &cur->hl;
    }
    if (cur != NULL) {
      cur->pos.cur = 0;
    }
    bool pos_inprogress = true;  // mark that a position match search is
                                 // in progress
    while (shl->rm.regprog != NULL
           || (cur != NULL && pos_inprogress)) {
      if (shl->startcol != MAXCOL
          && col >= shl->startcol
          && col < shl->endcol) {
        int next_col = col + utfc_ptr2len((char *)(*line) + col);

        if (shl->endcol < next_col) {
          shl->endcol = next_col;
        }
        // Highlight the match were the cursor is using the CurSearch
        // group.
        if (shl == search_hl && shl->has_cursor && (HL_ATTR(HLF_LC) || wp->w_hl_ids[HLF_LC])) {
          shl->attr_cur = win_hl_attr(wp, HLF_LC) ? win_hl_attr(wp, HLF_LC) : HL_ATTR(HLF_LC);
        } else {
          shl->attr_cur = shl->attr;
        }
        // Match with the "Conceal" group results in hiding
        // the match.
        if (cur != NULL
            && shl != search_hl
            && syn_name2id("Conceal") == cur->hlg_id) {
          *has_match_conc = col == shl->startcol ? 2 : 1;
          *match_conc = cur->conceal_char;
        } else {
          *has_match_conc = 0;
        }
      } else if (col == shl->endcol) {
        shl->attr_cur = 0;

        next_search_hl(wp, search_hl, shl, lnum, col,
                       shl == search_hl ? NULL : cur);
        pos_inprogress = !(cur == NULL || cur->pos.cur == 0);

        // Need to get the line again, a multi-line regexp
        // may have made it invalid.
        *line = ml_get_buf(wp->w_buffer, lnum, false);

        if (shl->lnum == lnum) {
          shl->startcol = shl->rm.startpos[0].col;
          if (shl->rm.endpos[0].lnum == 0) {
            shl->endcol = shl->rm.endpos[0].col;
          } else {
            shl->endcol = MAXCOL;
          }

          // check if the cursor is in the match
          if (shl == search_hl) {
            check_cur_search_hl(wp, shl);
          }

          if (shl->startcol == shl->endcol) {
            // highlight empty match, try again after it
            shl->endcol += utfc_ptr2len((char *)(*line) + shl->endcol);
          }

          // Loop to check if the match starts at the
          // current position
          continue;
        }
      }
      break;
    }
    if (shl != search_hl && cur != NULL) {
      cur = cur->next;
    }
  }

  // Use attributes from match with highest priority among
  // 'search_hl' and the match list.
  *search_attr_from_match = false;
  search_attr = search_hl->attr_cur;
  cur = wp->w_match_head;
  shl_flag = false;
  while (cur != NULL || !shl_flag) {
    if (!shl_flag
        && (cur == NULL || cur->priority > SEARCH_HL_PRIORITY)) {
      shl = search_hl;
      shl_flag = true;
    } else {
      shl = &cur->hl;
    }
    if (shl->attr_cur != 0) {
      search_attr = shl->attr_cur;
      *search_attr_from_match = shl != search_hl;
    }
    if (shl != search_hl && cur != NULL) {
      cur = cur->next;
    }
  }
  // Only highlight one character after the last column.
  if (*(*line + col) == NUL && (wp->w_p_list && lcs_eol_one == -1)) {
    search_attr = 0;
  }
  return search_attr;
}

bool get_prevcol_hl_flag(win_T *wp, match_T *search_hl, long curcol)
{
  long prevcol = curcol;
  matchitem_T *cur;                      // points to the match list

  // we're not really at that column when skipping some text
  if ((long)(wp->w_p_wrap ? wp->w_skipcol : wp->w_leftcol) > prevcol) {
    prevcol++;
  }

  if (!search_hl->is_addpos && prevcol == search_hl->startcol) {
    return true;
  } else {
    cur = wp->w_match_head;
    while (cur != NULL) {
      if (!cur->hl.is_addpos && prevcol == cur->hl.startcol) {
        return true;
      }
      cur = cur->next;
    }
  }
  return false;
}

/// Get highlighting for the char after the text in "char_attr" from 'hlsearch'
/// or match highlighting.
void get_search_match_hl(win_T *wp, match_T *search_hl, long col, int *char_attr)
{
  matchitem_T *cur = wp->w_match_head;  // points to the match list
  match_T *shl;                     // points to search_hl or a match
  bool shl_flag = false;        // flag to indicate whether search_hl
                                // has been processed or not

  *char_attr = search_hl->attr;
  while (cur != NULL || !shl_flag) {
    if (!shl_flag
        && (cur == NULL || cur->priority > SEARCH_HL_PRIORITY)) {
      shl = search_hl;
      shl_flag = true;
    } else {
      shl = &cur->hl;
    }
    if (col - 1 == (long)shl->startcol
        && (shl == search_hl || !shl->is_addpos)) {
      *char_attr = shl->attr;
    }
    if (shl != search_hl && cur != NULL) {
      cur = cur->next;
    }
  }
}

static int matchadd_dict_arg(typval_T *tv, const char **conceal_char, win_T **win)
{
  dictitem_T *di;

  if (tv->v_type != VAR_DICT) {
    emsg(_(e_dictreq));
    return FAIL;
  }

  if ((di = tv_dict_find(tv->vval.v_dict, S_LEN("conceal"))) != NULL) {
    *conceal_char = tv_get_string(&di->di_tv);
  }

  if ((di = tv_dict_find(tv->vval.v_dict, S_LEN("window"))) != NULL) {
    *win = find_win_by_nr_or_id(&di->di_tv);
    if (*win == NULL) {
      emsg(_(e_invalwindow));
      return FAIL;
    }
  }

  return OK;
}

/// "clearmatches()" function
void f_clearmatches(typval_T *argvars, typval_T *rettv, FunPtr fptr)
{
  win_T *win = get_optional_window(argvars, 0);

  if (win != NULL) {
    clear_matches(win);
  }
}

/// "getmatches()" function
void f_getmatches(typval_T *argvars, typval_T *rettv, FunPtr fptr)
{
  matchitem_T *cur;
  int i;
  win_T *win = get_optional_window(argvars, 0);

  if (win == NULL) {
    return;
  }

  tv_list_alloc_ret(rettv, kListLenMayKnow);
  cur = win->w_match_head;
  while (cur != NULL) {
    dict_T *dict = tv_dict_alloc();
    if (cur->match.regprog == NULL) {
      // match added with matchaddpos()
      for (i = 0; i < MAXPOSMATCH; i++) {
        llpos_T *llpos;
        char buf[30];  // use 30 to avoid compiler warning

        llpos = &cur->pos.pos[i];
        if (llpos->lnum == 0) {
          break;
        }
        list_T *const l = tv_list_alloc(1 + (llpos->col > 0 ? 2 : 0));
        tv_list_append_number(l, (varnumber_T)llpos->lnum);
        if (llpos->col > 0) {
          tv_list_append_number(l, (varnumber_T)llpos->col);
          tv_list_append_number(l, (varnumber_T)llpos->len);
        }
        int len = snprintf(buf, sizeof(buf), "pos%d", i + 1);
        assert((size_t)len < sizeof(buf));
        tv_dict_add_list(dict, buf, (size_t)len, l);
      }
    } else {
      tv_dict_add_str(dict, S_LEN("pattern"), (const char *)cur->pattern);
    }
    tv_dict_add_str(dict, S_LEN("group"),
                    (const char *)syn_id2name(cur->hlg_id));
    tv_dict_add_nr(dict, S_LEN("priority"), (varnumber_T)cur->priority);
    tv_dict_add_nr(dict, S_LEN("id"), (varnumber_T)cur->id);

    if (cur->conceal_char) {
      char buf[MB_MAXBYTES + 1];

      buf[utf_char2bytes(cur->conceal_char, buf)] = NUL;
      tv_dict_add_str(dict, S_LEN("conceal"), buf);
    }

    tv_list_append_dict(rettv->vval.v_list, dict);
    cur = cur->next;
  }
}

/// "setmatches()" function
void f_setmatches(typval_T *argvars, typval_T *rettv, FunPtr fptr)
{
  dict_T *d;
  list_T *s = NULL;
  win_T *win = get_optional_window(argvars, 1);

  rettv->vval.v_number = -1;
  if (argvars[0].v_type != VAR_LIST) {
    emsg(_(e_listreq));
    return;
  }
  if (win == NULL) {
    return;
  }

  list_T *const l = argvars[0].vval.v_list;
  // To some extent make sure that we are dealing with a list from
  // "getmatches()".
  int li_idx = 0;
  TV_LIST_ITER_CONST(l, li, {
    if (TV_LIST_ITEM_TV(li)->v_type != VAR_DICT
        || (d = TV_LIST_ITEM_TV(li)->vval.v_dict) == NULL) {
      semsg(_("E474: List item %d is either not a dictionary "
              "or an empty one"), li_idx);
      return;
    }
    if (!(tv_dict_find(d, S_LEN("group")) != NULL
          && (tv_dict_find(d, S_LEN("pattern")) != NULL
              || tv_dict_find(d, S_LEN("pos1")) != NULL)
          && tv_dict_find(d, S_LEN("priority")) != NULL
          && tv_dict_find(d, S_LEN("id")) != NULL)) {
      semsg(_("E474: List item %d is missing one of the required keys"),
            li_idx);
      return;
    }
    li_idx++;
  });

  clear_matches(win);
  bool match_add_failed = false;
  TV_LIST_ITER_CONST(l, li, {
    int i = 0;

    d = TV_LIST_ITEM_TV(li)->vval.v_dict;
    dictitem_T *const di = tv_dict_find(d, S_LEN("pattern"));
    if (di == NULL) {
      if (s == NULL) {
        s = tv_list_alloc(9);
      }

      // match from matchaddpos()
      for (i = 1; i < 9; i++) {
        char buf[30];  // use 30 to avoid compiler warning
        snprintf(buf, sizeof(buf), "pos%d", i);
        dictitem_T *const pos_di = tv_dict_find(d, buf, -1);
        if (pos_di != NULL) {
          if (pos_di->di_tv.v_type != VAR_LIST) {
            return;
          }

          tv_list_append_tv(s, &pos_di->di_tv);
          tv_list_ref(s);
        } else {
          break;
        }
      }
    }

    // Note: there are three number buffers involved:
    // - group_buf below.
    // - numbuf in tv_dict_get_string().
    // - mybuf in tv_get_string().
    //
    // If you change this code make sure that buffers will not get
    // accidentally reused.
    char group_buf[NUMBUFLEN];
    const char *const group = tv_dict_get_string_buf(d, "group", group_buf);
    const int priority = (int)tv_dict_get_number(d, "priority");
    const int id = (int)tv_dict_get_number(d, "id");
    dictitem_T *const conceal_di = tv_dict_find(d, S_LEN("conceal"));
    const char *const conceal = (conceal_di != NULL
                                 ? tv_get_string(&conceal_di->di_tv)
                                 : NULL);
    if (i == 0) {
      if (match_add(win, group,
                    tv_dict_get_string(d, "pattern", false),
                    priority, id, NULL, conceal) != id) {
        match_add_failed = true;
      }
    } else {
      if (match_add(win, group, NULL, priority, id, s, conceal) != id) {
        match_add_failed = true;
      }
      tv_list_unref(s);
      s = NULL;
    }
  });
  if (!match_add_failed) {
    rettv->vval.v_number = 0;
  }
}

/// "matchadd()" function
void f_matchadd(typval_T *argvars, typval_T *rettv, FunPtr fptr)
{
  char grpbuf[NUMBUFLEN];
  char patbuf[NUMBUFLEN];
  // group
  const char *const grp = tv_get_string_buf_chk(&argvars[0], grpbuf);
  // pattern
  const char *const pat = tv_get_string_buf_chk(&argvars[1], patbuf);
  // default priority
  int prio = 10;
  int id = -1;
  bool error = false;
  const char *conceal_char = NULL;
  win_T *win = curwin;

  rettv->vval.v_number = -1;

  if (grp == NULL || pat == NULL) {
    return;
  }
  if (argvars[2].v_type != VAR_UNKNOWN) {
    prio = (int)tv_get_number_chk(&argvars[2], &error);
    if (argvars[3].v_type != VAR_UNKNOWN) {
      id = (int)tv_get_number_chk(&argvars[3], &error);
      if (argvars[4].v_type != VAR_UNKNOWN
          && matchadd_dict_arg(&argvars[4], &conceal_char, &win) == FAIL) {
        return;
      }
    }
  }
  if (error) {
    return;
  }
  if (id >= 1 && id <= 3) {
    semsg(_("E798: ID is reserved for \":match\": %" PRId64), (int64_t)id);
    return;
  }

  rettv->vval.v_number = match_add(win, grp, pat, prio, id, NULL, conceal_char);
}

/// "matchaddpo()" function
void f_matchaddpos(typval_T *argvars, typval_T *rettv, FunPtr fptr)
{
  rettv->vval.v_number = -1;

  char buf[NUMBUFLEN];
  const char *const group = tv_get_string_buf_chk(&argvars[0], buf);
  if (group == NULL) {
    return;
  }

  if (argvars[1].v_type != VAR_LIST) {
    semsg(_(e_listarg), "matchaddpos()");
    return;
  }

  list_T *l;
  l = argvars[1].vval.v_list;
  if (l == NULL) {
    return;
  }

  bool error = false;
  int prio = 10;
  int id = -1;
  const char *conceal_char = NULL;
  win_T *win = curwin;

  if (argvars[2].v_type != VAR_UNKNOWN) {
    prio = (int)tv_get_number_chk(&argvars[2], &error);
    if (argvars[3].v_type != VAR_UNKNOWN) {
      id = (int)tv_get_number_chk(&argvars[3], &error);
      if (argvars[4].v_type != VAR_UNKNOWN
          && matchadd_dict_arg(&argvars[4], &conceal_char, &win) == FAIL) {
        return;
      }
    }
  }
  if (error == true) {
    return;
  }

  // id == 3 is ok because matchaddpos() is supposed to substitute :3match
  if (id == 1 || id == 2) {
    semsg(_("E798: ID is reserved for \"match\": %" PRId64), (int64_t)id);
    return;
  }

  rettv->vval.v_number = match_add(win, group, NULL, prio, id, l, conceal_char);
}

/// "matcharg()" function
void f_matcharg(typval_T *argvars, typval_T *rettv, FunPtr fptr)
{
  const int id = (int)tv_get_number(&argvars[0]);

  tv_list_alloc_ret(rettv, (id >= 1 && id <= 3
                            ? 2
                            : 0));

  if (id >= 1 && id <= 3) {
    matchitem_T *const m = get_match(curwin, id);

    if (m != NULL) {
      tv_list_append_string(rettv->vval.v_list,
                            (const char *)syn_id2name(m->hlg_id), -1);
      tv_list_append_string(rettv->vval.v_list, (const char *)m->pattern, -1);
    } else {
      tv_list_append_string(rettv->vval.v_list, NULL, 0);
      tv_list_append_string(rettv->vval.v_list, NULL, 0);
    }
  }
}

/// "matchdelete()" function
void f_matchdelete(typval_T *argvars, typval_T *rettv, FunPtr fptr)
{
  win_T *win = get_optional_window(argvars, 1);
  if (win == NULL) {
    rettv->vval.v_number = -1;
  } else {
    rettv->vval.v_number = match_delete(win,
                                        (int)tv_get_number(&argvars[0]), true);
  }
}

/// ":[N]match {group} {pattern}"
/// Sets nextcmd to the start of the next command, if any.  Also called when
/// skipping commands to find the next command.
void ex_match(exarg_T *eap)
{
  char_u *p;
  char_u *g = NULL;
  char_u *end;
  int c;
  int id;

  if (eap->line2 <= 3) {
    id = (int)eap->line2;
  } else {
    emsg(e_invcmd);
    return;
  }

  // First clear any old pattern.
  if (!eap->skip) {
    match_delete(curwin, id, false);
  }

  if (ends_excmd(*eap->arg)) {
    end = (char_u *)eap->arg;
  } else if ((STRNICMP(eap->arg, "none", 4) == 0
              && (ascii_iswhite(eap->arg[4]) || ends_excmd(eap->arg[4])))) {
    end = (char_u *)eap->arg + 4;
  } else {
    p = skiptowhite((char_u *)eap->arg);
    if (!eap->skip) {
      g = vim_strnsave((char_u *)eap->arg, (size_t)(p - (char_u *)eap->arg));
    }
    p = (char_u *)skipwhite((char *)p);
    if (*p == NUL) {
      // There must be two arguments.
      xfree(g);
      semsg(_(e_invarg2), eap->arg);
      return;
    }
    end = skip_regexp(p + 1, *p, true, NULL);
    if (!eap->skip) {
      if (*end != NUL && !ends_excmd(*skipwhite((char *)end + 1))) {
        xfree(g);
        eap->errmsg = e_trailing;
        return;
      }
      if (*end != *p) {
        xfree(g);
        semsg(_(e_invarg2), p);
        return;
      }

      c = *end;
      *end = NUL;
      match_add(curwin, (const char *)g, (const char *)p + 1, 10, id,
                NULL, NULL);
      xfree(g);
      *end = (char_u)c;
    }
  }
  eap->nextcmd = (char *)find_nextcmd(end);
}
