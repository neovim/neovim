// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>

#include "nvim/buffer.h"
#include "nvim/decoration.h"
#include "nvim/drawscreen.h"
#include "nvim/extmark.h"
#include "nvim/fold.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/pos.h"
#include "nvim/sign_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration.c.generated.h"
#endif

/// Add highlighting to a buffer, bounded by two cursor positions,
/// with an offset.
///
/// TODO(bfredl): make decoration powerful enough so that this
/// can be done with a single ephemeral decoration.
///
/// @param buf Buffer to add highlights to
/// @param src_id src_id to use or 0 to use a new src_id group,
///               or -1 for ungrouped highlight.
/// @param hl_id Highlight group id
/// @param pos_start Cursor position to start the highlighting at
/// @param pos_end Cursor position to end the highlighting at
/// @param offset Move the whole highlighting this many columns to the right
void bufhl_add_hl_pos_offset(buf_T *buf, int src_id, int hl_id, lpos_T pos_start, lpos_T pos_end,
                             colnr_T offset)
{
  colnr_T hl_start = 0;
  colnr_T hl_end = 0;
  Decoration decor = DECORATION_INIT;
  decor.hl_id = hl_id;

  // TODO(bfredl): if decoration had blocky mode, we could avoid this loop
  for (linenr_T lnum = pos_start.lnum; lnum <= pos_end.lnum; lnum++) {
    int end_off = 0;
    if (pos_start.lnum < lnum && lnum < pos_end.lnum) {
      // TODO(bfredl): This is quite ad-hoc, but the space between |num| and
      // text being highlighted is the indication of \n being part of the
      // substituted text. But it would be more consistent to highlight
      // a space _after_ the previous line instead (like highlight EOL list
      // char)
      hl_start = MAX(offset - 1, 0);
      end_off = 1;
      hl_end = 0;
    } else if (lnum == pos_start.lnum && lnum < pos_end.lnum) {
      hl_start = pos_start.col + offset;
      end_off = 1;
      hl_end = 0;
    } else if (pos_start.lnum < lnum && lnum == pos_end.lnum) {
      hl_start = MAX(offset - 1, 0);
      hl_end = pos_end.col + offset;
    } else if (pos_start.lnum == lnum && pos_end.lnum == lnum) {
      hl_start = pos_start.col + offset;
      hl_end = pos_end.col + offset;
    }
    extmark_set(buf, (uint32_t)src_id, NULL,
                (int)lnum - 1, hl_start, (int)lnum - 1 + end_off, hl_end,
                &decor, true, false, kExtmarkNoUndo, NULL);
  }
}

void decor_redraw(buf_T *buf, int row1, int row2, Decoration *decor)
{
  if (row2 >= row1) {
    if (!decor
        || decor->hl_id
        || decor_has_sign(decor)
        || decor->conceal
        || decor->spell != kNone) {
      redraw_buf_range_later(buf, row1 + 1, row2 + 1);
    }
  }

  if (decor && decor_virt_pos(decor)) {
    redraw_buf_line_later(buf, row1 + 1, false);
    if (decor->virt_text_pos == kVTInline) {
      changed_line_display_buf(buf);
    }
  }

  if (decor && kv_size(decor->virt_lines)) {
    redraw_buf_line_later(buf, row1 + 1 + (decor->virt_lines_above ? 0 : 1), true);
    changed_line_display_buf(buf);
  }
}

void decor_remove(buf_T *buf, int row, int row2, Decoration *decor)
{
  decor_redraw(buf, row, row2, decor);
  if (decor) {
    if (kv_size(decor->virt_text) && decor->virt_text_pos == kVTInline) {
      assert(buf->b_virt_text_inline > 0);
      buf->b_virt_text_inline--;
    }
    if (kv_size(decor->virt_lines)) {
      assert(buf->b_virt_line_blocks > 0);
      buf->b_virt_line_blocks--;
    }
    if (decor_has_sign(decor)) {
      assert(buf->b_signs > 0);
      buf->b_signs--;
      if (decor->sign_text) {
        assert(buf->b_signs_with_text > 0);
        buf->b_signs_with_text--;
        if (row2 >= row) {
          buf_signcols_del_check(buf, row + 1, row2 + 1);
        }
      }
    }
  }
  decor_free(decor);
}

void decor_clear(Decoration *decor)
{
  clear_virttext(&decor->virt_text);
  for (size_t i = 0; i < kv_size(decor->virt_lines); i++) {
    clear_virttext(&kv_A(decor->virt_lines, i).line);
  }
  kv_destroy(decor->virt_lines);
  xfree(decor->sign_text);
}

void decor_free(Decoration *decor)
{
  if (decor) {
    decor_clear(decor);
    xfree(decor);
  }
}

void decor_state_free(DecorState *state)
{
  xfree(state->active.items);
}

void clear_virttext(VirtText *text)
{
  for (size_t i = 0; i < kv_size(*text); i++) {
    xfree(kv_A(*text, i).text);
  }
  kv_destroy(*text);
  *text = (VirtText)KV_INITIAL_VALUE;
}

Decoration *decor_find_virttext(buf_T *buf, int row, uint64_t ns_id)
{
  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, row, 0,  itr);
  while (true) {
    mtkey_t mark = marktree_itr_current(itr);
    if (mark.pos.row < 0 || mark.pos.row > row) {
      break;
    } else if (marktree_decor_level(mark) < kDecorLevelVisible) {
      goto next_mark;
    }
    Decoration *decor = mark.decor_full;
    if ((ns_id == 0 || ns_id == mark.ns)
        && decor && kv_size(decor->virt_text)) {
      return decor;
    }
next_mark:
    marktree_itr_next(buf->b_marktree, itr);
  }
  return NULL;
}

bool decor_redraw_reset(win_T *wp, DecorState *state)
{
  state->row = -1;
  state->win = wp;
  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange item = kv_A(state->active, i);
    if (item.virt_text_owned) {
      clear_virttext(&item.decor.virt_text);
    }
  }
  kv_size(state->active) = 0;
  return wp->w_buffer->b_marktree->n_keys;
}

Decoration get_decor(mtkey_t mark)
{
  if (mark.decor_full) {
    return *mark.decor_full;
  }
  Decoration fake = DECORATION_INIT;
  fake.hl_id = mark.hl_id;
  fake.priority = mark.priority;
  fake.hl_eol = (mark.flags & MT_FLAG_HL_EOL);
  return fake;
}

/// @return true if decor has a virtual position (virtual text or ui_watched)
bool decor_virt_pos(const Decoration *const decor)
{
  return kv_size(decor->virt_text) || decor->ui_watched;
}

bool decor_redraw_start(win_T *wp, int top_row, DecorState *state)
{
  buf_T *buf = wp->w_buffer;
  state->top_row = top_row;
  marktree_itr_get(buf->b_marktree, top_row, 0, state->itr);
  if (!state->itr->node) {
    return false;
  }
  marktree_itr_rewind(buf->b_marktree, state->itr);
  while (true) {
    mtkey_t mark = marktree_itr_current(state->itr);
    if (mark.pos.row < 0) {  // || mark.row > end_row
      break;
    }
    if ((mark.pos.row < top_row && mt_end(mark))
        || marktree_decor_level(mark) < kDecorLevelVisible) {
      goto next_mark;
    }

    Decoration decor = get_decor(mark);

    mtpos_t altpos = marktree_get_altpos(buf->b_marktree, mark, NULL);

    // Exclude start marks if the end mark position is above the top row
    // Exclude end marks if we have already added the start mark
    if ((mt_start(mark) && altpos.row < top_row && !decor_virt_pos(&decor))
        || (mt_end(mark) && altpos.row >= top_row)) {
      goto next_mark;
    }

    if (mt_end(mark)) {
      decor_add(state, altpos.row, altpos.col, mark.pos.row, mark.pos.col,
                &decor, false, mark.ns, mark.id);
    } else {
      if (altpos.row == -1) {
        altpos.row = mark.pos.row;
        altpos.col = mark.pos.col;
      }
      decor_add(state, mark.pos.row, mark.pos.col, altpos.row, altpos.col,
                &decor, false, mark.ns, mark.id);
    }

next_mark:
    if (marktree_itr_node_done(state->itr)) {
      marktree_itr_next(buf->b_marktree, state->itr);
      break;
    }
    marktree_itr_next(buf->b_marktree, state->itr);
  }

  return true;  // TODO(bfredl): check if available in the region
}

bool decor_redraw_line(win_T *wp, int row, DecorState *state)
{
  if (state->row == -1) {
    decor_redraw_start(wp, row, state);
  }
  state->row = row;
  state->col_until = -1;
  state->eol_col = -1;
  return true;  // TODO(bfredl): be more precise
}

static void decor_add(DecorState *state, int start_row, int start_col, int end_row, int end_col,
                      Decoration *decor, bool owned, uint64_t ns_id, uint64_t mark_id)
{
  int attr_id = decor->hl_id > 0 ? syn_id2attr(decor->hl_id) : 0;

  DecorRange range = { start_row, start_col, end_row, end_col,
                       *decor, attr_id,
                       kv_size(decor->virt_text) && owned, -1, ns_id, mark_id };

  kv_pushp(state->active);
  size_t index;
  for (index = kv_size(state->active) - 1; index > 0; index--) {
    DecorRange item = kv_A(state->active, index - 1);
    if (item.decor.priority <= range.decor.priority) {
      break;
    }
    kv_A(state->active, index) = kv_A(state->active, index - 1);
  }
  kv_A(state->active, index) = range;
}

int decor_redraw_col(win_T *wp, int col, int win_col, bool hidden, DecorState *state)
{
  buf_T *buf = wp->w_buffer;
  if (col <= state->col_until) {
    return state->current;
  }
  state->col_until = MAXCOL;
  while (true) {
    // TODO(bfredl): check duplicate entry in "intersection"
    // branch
    mtkey_t mark = marktree_itr_current(state->itr);
    if (mark.pos.row < 0 || mark.pos.row > state->row) {
      break;
    } else if (mark.pos.row == state->row && mark.pos.col > col) {
      state->col_until = mark.pos.col - 1;
      break;
    }

    if (mt_end(mark)
        || marktree_decor_level(mark) < kDecorLevelVisible) {
      goto next_mark;
    }

    Decoration decor = get_decor(mark);

    mtpos_t endpos = marktree_get_altpos(buf->b_marktree, mark, NULL);

    if (endpos.row == -1) {
      endpos = mark.pos;
    }

    decor_add(state, mark.pos.row, mark.pos.col, endpos.row, endpos.col,
              &decor, false, mark.ns, mark.id);

next_mark:
    marktree_itr_next(buf->b_marktree, state->itr);
  }

  int attr = 0;
  size_t j = 0;
  bool conceal = 0;
  int conceal_char = 0;
  int conceal_attr = 0;
  TriState spell = kNone;

  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange item = kv_A(state->active, i);
    bool active = false, keep = true;
    if (item.end_row < state->row
        || (item.end_row == state->row && item.end_col <= col)) {
      if (!(item.start_row >= state->row && decor_virt_pos(&item.decor))) {
        keep = false;
      }
    } else {
      if (item.start_row < state->row
          || (item.start_row == state->row && item.start_col <= col)) {
        active = true;
        if (item.end_row == state->row && item.end_col > col) {
          state->col_until = MIN(state->col_until, item.end_col - 1);
        }
      } else {
        if (item.start_row == state->row) {
          state->col_until = MIN(state->col_until, item.start_col - 1);
        }
      }
    }
    if (active && item.attr_id > 0) {
      attr = hl_combine_attr(attr, item.attr_id);
    }
    if (active && item.decor.conceal) {
      conceal = true;
      if (item.start_row == state->row && item.start_col == col && item.decor.conceal_char) {
        conceal_char = item.decor.conceal_char;
        state->col_until = MIN(state->col_until, item.start_col);
        conceal_attr = item.attr_id;
      }
    }
    if (active && item.decor.spell != kNone) {
      spell = item.decor.spell;
    }
    if (item.start_row == state->row && decor_virt_pos(&item.decor)
        && item.draw_col != INT_MIN) {
      if (item.start_col <= col) {
        if (item.decor.virt_text_pos == kVTOverlay && item.draw_col == -1) {
          item.draw_col = (item.decor.virt_text_hide && hidden) ? INT_MIN : win_col;
        } else if (item.draw_col == -3) {
          item.draw_col = -1;
        }
      } else if (wp->w_p_wrap
                 && (item.decor.virt_text_pos == kVTRightAlign
                     || item.decor.virt_text_pos == kVTWinCol)) {
        item.draw_col = -3;
      }
    }
    if (keep) {
      kv_A(state->active, j++) = item;
    } else if (item.virt_text_owned) {
      clear_virttext(&item.decor.virt_text);
    }
  }
  kv_size(state->active) = j;
  state->current = attr;
  state->conceal = conceal;
  state->conceal_char = conceal_char;
  state->conceal_attr = conceal_attr;
  state->spell = spell;
  return attr;
}

void decor_redraw_signs(buf_T *buf, int row, int *num_signs, SignTextAttrs sattrs[],
                        HlPriId *num_id, HlPriId *line_id, HlPriId *cul_id)
{
  if (!buf->b_signs) {
    return;
  }

  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, row, 0, itr);

  while (true) {
    mtkey_t mark = marktree_itr_current(itr);
    if (mark.pos.row < 0 || mark.pos.row > row) {
      break;
    }

    if (mt_end(mark) || marktree_decor_level(mark) < kDecorLevelVisible) {
      goto next_mark;
    }

    Decoration *decor = mark.decor_full;

    if (!decor || !decor_has_sign(decor)) {
      goto next_mark;
    }

    if (decor->sign_text) {
      int j;
      for (j = (*num_signs); j > 0; j--) {
        if (sattrs[j - 1].priority >= decor->priority) {
          break;
        }
        if (j < SIGN_SHOW_MAX) {
          sattrs[j] = sattrs[j - 1];
        }
      }
      if (j < SIGN_SHOW_MAX) {
        sattrs[j] = (SignTextAttrs) {
          .text = decor->sign_text,
          .hl_id = decor->sign_hl_id,
          .priority = decor->priority
        };
        (*num_signs)++;
      }
    }

    struct { HlPriId *dest; int hl; } cattrs[] = {
      { line_id, decor->line_hl_id        },
      { num_id,  decor->number_hl_id      },
      { cul_id,  decor->cursorline_hl_id  },
      { NULL, -1 },
    };
    for (int i = 0; cattrs[i].dest; i++) {
      if (cattrs[i].hl != 0 && decor->priority >= cattrs[i].dest->priority) {
        *cattrs[i].dest = (HlPriId) {
          .hl_id = cattrs[i].hl,
          .priority = decor->priority
        };
      }
    }

next_mark:
    marktree_itr_next(buf->b_marktree, itr);
  }
}

// Get the maximum required amount of sign columns needed between row and
// end_row.
int decor_signcols(buf_T *buf, DecorState *state, int row, int end_row, int max)
{
  int count = 0;         // count for the number of signs on a given row
  int count_remove = 0;  // how much to decrement count by when iterating marks for a new row
  int signcols = 0;      // highest value of count
  int currow = -1;       // current row

  if (max <= 1 && buf->b_signs_with_text >= (size_t)max) {
    return max;
  }

  if (buf->b_signs_with_text == 0) {
    return 0;
  }

  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, 0, -1, itr);
  while (true) {
    mtkey_t mark = marktree_itr_current(itr);
    if (mark.pos.row < 0 || mark.pos.row > end_row) {
      break;
    }

    if ((mark.pos.row < row && mt_end(mark))
        || marktree_decor_level(mark) < kDecorLevelVisible
        || !mark.decor_full) {
      goto next_mark;
    }

    Decoration decor = get_decor(mark);

    if (!decor.sign_text) {
      goto next_mark;
    }

    if (mark.pos.row > currow) {
      count -= count_remove;
      count_remove = 0;
      currow = mark.pos.row;
    }

    if (!mt_paired(mark)) {
      if (mark.pos.row >= row) {
        count++;
        if (count > signcols) {
          signcols = count;
          if (signcols >= max) {
            return max;
          }
        }
        count_remove++;
      }
      goto next_mark;
    }

    mtpos_t altpos = marktree_get_altpos(buf->b_marktree, mark, NULL);

    if (mt_end(mark)) {
      if (mark.pos.row >= row && altpos.row <= end_row) {
        count_remove++;
      }
    } else {
      if (altpos.row >= row) {
        count++;
        if (count > signcols) {
          signcols = count;
          if (signcols >= max) {
            return max;
          }
        }
      }
    }

next_mark:
    marktree_itr_next(buf->b_marktree, itr);
  }

  return signcols;
}

void decor_redraw_end(DecorState *state)
{
  state->win = NULL;
}

bool decor_redraw_eol(win_T *wp, DecorState *state, int *eol_attr, int eol_col)
{
  decor_redraw_col(wp, MAXCOL, MAXCOL, false, state);
  state->eol_col = eol_col;
  bool has_virttext = false;
  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange item = kv_A(state->active, i);
    if (item.start_row == state->row && decor_virt_pos(&item.decor)) {
      has_virttext = true;
    }

    if (item.decor.hl_eol && item.start_row <= state->row) {
      *eol_attr = hl_combine_attr(*eol_attr, item.attr_id);
    }
  }
  return has_virttext;
}

void decor_add_ephemeral(int start_row, int start_col, int end_row, int end_col, Decoration *decor,
                         uint64_t ns_id, uint64_t mark_id)
{
  if (end_row == -1) {
    end_row = start_row;
    end_col = start_col;
  }
  decor_add(&decor_state, start_row, start_col, end_row, end_col, decor, true, ns_id, mark_id);
}

/// @param has_fold  whether line "lnum" has a fold, or kNone when not calculated yet
int decor_virt_lines(win_T *wp, linenr_T lnum, VirtLines *lines, TriState has_fold)
{
  buf_T *buf = wp->w_buffer;
  if (!buf->b_virt_line_blocks) {
    // Only pay for what you use: in case virt_lines feature is not active
    // in a buffer, plines do not need to access the marktree at all
    return 0;
  }

  int virt_lines = 0;
  int row = MAX(lnum - 2, 0);
  int end_row = (int)lnum;
  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, row, 0,  itr);
  bool below_fold = lnum > 1 && hasFoldingWin(wp, lnum - 1, NULL, NULL, true, NULL);
  if (has_fold == kNone) {
    has_fold = hasFoldingWin(wp, lnum, NULL, NULL, true, NULL);
  }
  while (true) {
    mtkey_t mark = marktree_itr_current(itr);
    if (mark.pos.row < 0 || mark.pos.row >= end_row) {
      break;
    } else if (mt_end(mark) || marktree_decor_level(mark) < kDecorLevelVirtLine) {
      goto next_mark;
    }
    bool above = mark.pos.row > (lnum - 2);
    bool has_fold_cur = above ? has_fold : below_fold;
    Decoration *decor = mark.decor_full;
    if (!has_fold_cur && decor && decor->virt_lines_above == above) {
      virt_lines += (int)kv_size(decor->virt_lines);
      if (lines) {
        kv_splice(*lines, decor->virt_lines);
      }
    }
next_mark:
    marktree_itr_next(buf->b_marktree, itr);
  }

  return virt_lines;
}
