#include <assert.h>
#include <limits.h>

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
#include "nvim/sign.h"

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
                &decor, true, false, true, false, NULL);
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

static int sign_add_id = 0;

void decor_add(buf_T *buf, int row, int row2, Decoration *decor, bool hl_id)
{
  if (decor) {
    if (kv_size(decor->virt_text) && decor->virt_text_pos == kVTInline) {
      buf->b_virt_text_inline++;
    }
    if (kv_size(decor->virt_lines)) {
      buf->b_virt_line_blocks++;
    }
    if (decor_has_sign(decor)) {
      decor->sign_add_id = sign_add_id++;
      buf->b_signs++;
    }
    if (decor->sign_text) {
      buf->b_signs_with_text++;
      buf_signcols_add_check(buf, row + 1);
    }
  }
  if (decor || hl_id) {
    decor_redraw(buf, row, row2 > -1 ? row2 : row, decor);
  }
}

void decor_remove(buf_T *buf, int row, int row2, Decoration *decor, bool invalidate)
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
  if (!invalidate) {
    decor_free(decor);
  }
}

void decor_clear(Decoration *decor)
{
  clear_virttext(&decor->virt_text);
  for (size_t i = 0; i < kv_size(decor->virt_lines); i++) {
    clear_virttext(&kv_A(decor->virt_lines, i).line);
  }
  kv_destroy(decor->virt_lines);
  xfree(decor->sign_text);
  xfree(decor->sign_name);
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

/// Get the next chunk of a virtual text item.
///
/// @param[in]     vt    The virtual text item
/// @param[in,out] pos   Position in the virtual text item
/// @param[in,out] attr  Highlight attribute
///
/// @return  The text of the chunk, or NULL if there are no more chunks
char *next_virt_text_chunk(VirtText vt, size_t *pos, int *attr)
{
  char *text = NULL;
  for (; text == NULL && *pos < kv_size(vt); (*pos)++) {
    text = kv_A(vt, *pos).text;
    int hl_id = kv_A(vt, *pos).hl_id;
    *attr = hl_combine_attr(*attr, hl_id > 0 ? syn_id2attr(hl_id) : 0);
  }
  return text;
}

Decoration *decor_find_virttext(buf_T *buf, int row, uint64_t ns_id)
{
  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, row, 0,  itr);
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0 || mark.pos.row > row) {
      break;
    } else if (mt_invalid(mark) || marktree_decor_level(mark) < kDecorLevelVisible) {
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

Decoration get_decor(MTKey mark)
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
  if (!marktree_itr_get_overlap(buf->b_marktree, top_row, 0, state->itr)) {
    return false;
  }
  MTPair pair;

  while (marktree_itr_step_overlap(buf->b_marktree, state->itr, &pair)) {
    if (mt_invalid(pair.start) || marktree_decor_level(pair.start) < kDecorLevelVisible) {
      continue;
    }

    Decoration decor = get_decor(pair.start);

    decor_push(state, pair.start.pos.row, pair.start.pos.col, pair.end_pos.row, pair.end_pos.col,
               &decor, false, pair.start.ns, pair.start.id);
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

  if (kv_size(state->active)) {
    return true;
  }

  MTKey k = marktree_itr_current(state->itr);
  return (k.pos.row >= 0 && k.pos.row <= row);
}

static void decor_push(DecorState *state, int start_row, int start_col, int end_row, int end_col,
                       Decoration *decor, bool owned, uint64_t ns_id, uint64_t mark_id)
{
  int attr_id = decor->hl_id > 0 ? syn_id2attr(decor->hl_id) : 0;

  DecorRange range = { start_row, start_col, end_row, end_col,
                       *decor, attr_id,
                       kv_size(decor->virt_text) && owned, -10, ns_id, mark_id };

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

/// Initialize the draw_col of a newly-added virtual text item.
static void decor_init_draw_col(int win_col, bool hidden, DecorRange *item)
{
  if (win_col < 0 && item->decor.virt_text_pos != kVTInline) {
    item->draw_col = win_col;
  } else if (item->decor.virt_text_pos == kVTOverlay) {
    item->draw_col = (item->decor.virt_text_hide && hidden) ? INT_MIN : win_col;
  } else {
    item->draw_col = -1;
  }
}

void decor_recheck_draw_col(int win_col, bool hidden, DecorState *state)
{
  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange *item = &kv_A(state->active, i);
    if (item->draw_col == -3) {
      decor_init_draw_col(win_col, hidden, item);
    }
  }
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
    MTKey mark = marktree_itr_current(state->itr);
    if (mark.pos.row < 0 || mark.pos.row > state->row) {
      break;
    } else if (mark.pos.row == state->row && mark.pos.col > col) {
      state->col_until = mark.pos.col - 1;
      break;
    }

    if (mt_invalid(mark) || mt_end(mark) || marktree_decor_level(mark) < kDecorLevelVisible) {
      goto next_mark;
    }

    Decoration decor = get_decor(mark);

    MTPos endpos = marktree_get_altpos(buf->b_marktree, mark, NULL);
    if (endpos.row == -1) {
      endpos = mark.pos;
    }

    decor_push(state, mark.pos.row, mark.pos.col, endpos.row, endpos.col,
               &decor, false, mark.ns, mark.id);

next_mark:
    marktree_itr_next(buf->b_marktree, state->itr);
  }

  int attr = 0;
  size_t j = 0;
  int conceal = 0;
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
      conceal = 1;
      if (item.start_row == state->row && item.start_col == col) {
        conceal = 2;
        conceal_char = item.decor.conceal_char;
        state->col_until = MIN(state->col_until, item.start_col);
        conceal_attr = item.attr_id;
      }
    }
    if (active && item.decor.spell != kNone) {
      spell = item.decor.spell;
    }
    if (item.start_row == state->row && item.start_col <= col
        && decor_virt_pos(&item.decor) && item.draw_col == -10) {
      decor_init_draw_col(win_col, hidden, &item);
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

/// Return the sign attributes on the currently refreshed row.
///
/// @param[out] sattrs Output array for sign text and texthl id
/// @param[out] line_attr Highest priority linehl id
/// @param[out] cul_attr Highest priority culhl id
/// @param[out] num_attr Highest priority numhl id
void decor_redraw_signs(win_T *wp, buf_T *buf, int row, SignTextAttrs sattrs[], int *line_id,
                        int *cul_id, int *num_id)
{
  MarkTreeIter itr[1];
  if (!buf->b_signs || !marktree_itr_get_overlap(buf->b_marktree, row, 0, itr)) {
    return;
  }

  MTPair pair;
  int num_text = 0;
  kvec_t(MTKey) signs = KV_INITIAL_VALUE;
  // TODO(bfredl): integrate with main decor loop.
  while (marktree_itr_step_overlap(buf->b_marktree, itr, &pair)) {
    if (!mt_invalid(pair.start) && pair.start.decor_full && decor_has_sign(pair.start.decor_full)) {
      pair.start.pos.row = row;
      num_text += (pair.start.decor_full->sign_text != NULL);
      kv_push(signs, pair.start);
    }
  }

  while (itr->x) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row != row) {
      break;
    }
    if (!mt_end(mark) && !mt_invalid(mark) && mark.decor_full && decor_has_sign(mark.decor_full)) {
      num_text += (mark.decor_full->sign_text != NULL);
      kv_push(signs, mark);
    }
    marktree_itr_next(buf->b_marktree, itr);
  }

  if (kv_size(signs)) {
    int width = (*wp->w_p_scl == 'n' && *(wp->w_p_scl + 1) == 'u') ? 1 : wp->w_scwidth;
    int idx = MIN(width, num_text) - 1;
    qsort((void *)&kv_A(signs, 0), kv_size(signs), sizeof(MTKey), sign_cmp);

    for (size_t i = 0; i < kv_size(signs); i++) {
      Decoration *decor = kv_A(signs, i).decor_full;
      if (idx >= 0 && decor->sign_text) {
        sattrs[idx].text = decor->sign_text;
        sattrs[idx--].hl_id = decor->sign_hl_id;
      }
      if (*num_id == 0) {
        *num_id = decor->number_hl_id;
      }
      if (*line_id == 0) {
        *line_id = decor->line_hl_id;
      }
      if (*cul_id == 0) {
        *cul_id = decor->cursorline_hl_id;
      }
    }
    kv_destroy(signs);
  }
}

// Get the maximum required amount of sign columns needed between row and
// end_row.
int decor_signcols(buf_T *buf, int row, int end_row, int max)
{
  if (max <= 1 && buf->b_signs_with_text >= (size_t)max) {
    return max;
  }

  if (buf->b_signs_with_text == 0) {
    return 0;
  }

  int signcols = 0;  // highest value of count
  for (int currow = row; currow <= end_row; currow++) {
    MarkTreeIter itr[1];
    if (!marktree_itr_get_overlap(buf->b_marktree, currow, 0, itr)) {
      continue;
    }

    int count = 0;
    MTPair pair;
    while (marktree_itr_step_overlap(buf->b_marktree, itr, &pair)) {
      if (!mt_invalid(pair.start) && pair.start.decor_full && pair.start.decor_full->sign_text) {
        count++;
      }
    }

    while (itr->x) {
      MTKey mark = marktree_itr_current(itr);
      if (mark.pos.row != currow) {
        break;
      }
      if (!mt_invalid(mark) && !mt_end(mark) && mark.decor_full && mark.decor_full->sign_text) {
        count++;
      }
      marktree_itr_next(buf->b_marktree, itr);
    }

    if (count > signcols) {
      if (row != end_row) {
        buf->b_signcols.sentinel = currow + 1;
      }
      if (count >= max) {
        return max;
      }
      signcols = count;
    }
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

void decor_push_ephemeral(int start_row, int start_col, int end_row, int end_col, Decoration *decor,
                          uint64_t ns_id, uint64_t mark_id)
{
  if (end_row == -1) {
    end_row = start_row;
    end_col = start_col;
  }
  decor_push(&decor_state, start_row, start_col, end_row, end_col, decor, true, ns_id, mark_id);
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

  assert(lnum > 0);
  bool below_fold = lnum > 1 && hasFoldingWin(wp, lnum - 1, NULL, NULL, true, NULL);
  if (has_fold == kNone) {
    has_fold = hasFoldingWin(wp, lnum, NULL, NULL, true, NULL);
  }

  const int row = lnum - 1;
  const int start_row = below_fold ? row : MAX(row - 1, 0);
  const int end_row = has_fold ? row : row + 1;
  if (start_row >= end_row) {
    return 0;
  }

  int virt_lines = 0;
  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, start_row, 0, itr);
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0 || mark.pos.row >= end_row) {
      break;
    } else if (mt_end(mark)
               || marktree_decor_level(mark) < kDecorLevelVirtLine
               || !mark.decor_full) {
      goto next_mark;
    }
    Decoration *const decor = mark.decor_full;
    const int draw_row = mark.pos.row + (decor->virt_lines_above ? 0 : 1);
    if (draw_row == row) {
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
