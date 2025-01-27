#include <assert.h>
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/decoration.h"
#include "nvim/drawscreen.h"
#include "nvim/extmark.h"
#include "nvim/fold.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/marktree.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/option_vars.h"
#include "nvim/pos_defs.h"
#include "nvim/sign.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration.c.generated.h"
#endif

uint32_t decor_freelist = UINT32_MAX;

// Decorations might be requested to be deleted in a callback in the middle of redrawing.
// In this case, there might still be live references to the memory allocated for the decoration.
// Keep a "to free" list which can be safely processed when redrawing is done.
DecorVirtText *to_free_virt = NULL;
uint32_t to_free_sh = UINT32_MAX;

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
  DecorInline decor = DECOR_INLINE_INIT;
  decor.data.hl.hl_id = hl_id;

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
                decor, MT_FLAG_DECOR_HL, true, false, true, false, NULL);
  }
}

void decor_redraw(buf_T *buf, int row1, int row2, int col1, DecorInline decor)
{
  if (decor.ext) {
    DecorVirtText *vt = decor.data.ext.vt;
    while (vt) {
      bool below = (vt->flags & kVTIsLines) && !(vt->flags & kVTLinesAbove);
      linenr_T vt_lnum = row1 + 1 + below;
      redraw_buf_line_later(buf, vt_lnum, true);
      if (vt->flags & kVTIsLines || vt->pos == kVPosInline) {
        // changed_lines_redraw_buf(buf, vt_lnum, vt_lnum + 1, 0);
        colnr_T vt_col = vt->flags & kVTIsLines ? 0 : col1;
        changed_lines_invalidate_buf(buf, vt_lnum, vt_col, vt_lnum + 1, 0);
      }
      vt = vt->next;
    }

    uint32_t idx = decor.data.ext.sh_idx;
    while (idx != DECOR_ID_INVALID) {
      DecorSignHighlight *sh = &kv_A(decor_items, idx);
      decor_redraw_sh(buf, row1, row2, *sh);
      idx = sh->next;
    }
  } else {
    decor_redraw_sh(buf, row1, row2, decor_sh_from_inline(decor.data.hl));
  }
}

void decor_redraw_sh(buf_T *buf, int row1, int row2, DecorSignHighlight sh)
{
  if (sh.hl_id || (sh.url != NULL)
      || (sh.flags & (kSHIsSign | kSHSpellOn | kSHSpellOff | kSHConceal))) {
    if (row2 >= row1) {
      redraw_buf_range_later(buf, row1 + 1, row2 + 1);
    }
  }
  if (sh.flags & kSHUIWatched) {
    redraw_buf_line_later(buf, row1 + 1, false);
  }
}

uint32_t decor_put_sh(DecorSignHighlight item)
{
  if (decor_freelist != UINT32_MAX) {
    uint32_t pos = decor_freelist;
    decor_freelist = kv_A(decor_items, decor_freelist).next;
    kv_A(decor_items, pos) = item;
    return pos;
  } else {
    uint32_t pos = (uint32_t)kv_size(decor_items);
    kv_push(decor_items, item);
    return pos;
  }
}

DecorVirtText *decor_put_vt(DecorVirtText vt, DecorVirtText *next)
{
  DecorVirtText *decor_alloc = xmalloc(sizeof *decor_alloc);
  *decor_alloc = vt;
  decor_alloc->next = next;
  return decor_alloc;
}

DecorSignHighlight decor_sh_from_inline(DecorHighlightInline item)
{
  // TODO(bfredl): Eventually simple signs will be inlinable as well
  assert(!(item.flags & kSHIsSign));
  DecorSignHighlight conv = {
    .flags = item.flags,
    .priority = item.priority,
    .text[0] = item.conceal_char,
    .hl_id = item.hl_id,
    .number_hl_id = 0,
    .line_hl_id = 0,
    .cursorline_hl_id = 0,
    .next = DECOR_ID_INVALID,
  };

  return conv;
}

void buf_put_decor(buf_T *buf, DecorInline decor, int row, int row2)
{
  if (decor.ext) {
    uint32_t idx = decor.data.ext.sh_idx;
    while (idx != DECOR_ID_INVALID) {
      DecorSignHighlight *sh = &kv_A(decor_items, idx);
      buf_put_decor_sh(buf, sh, row, row2);
      idx = sh->next;
    }
  }
}

/// When displaying signs in the 'number' column, if the width of the number
/// column is less than 2, then force recomputing the width after placing or
/// unplacing the first sign in "buf".
static void may_force_numberwidth_recompute(buf_T *buf, bool unplace)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == buf
        && wp->w_minscwidth == SCL_NUM
        && (wp->w_p_nu || wp->w_p_rnu)
        && (unplace || wp->w_nrwidth_width < 2)) {
      wp->w_nrwidth_line_count = 0;
    }
  }
}

static int sign_add_id = 0;
void buf_put_decor_sh(buf_T *buf, DecorSignHighlight *sh, int row1, int row2)
{
  if (sh->flags & kSHIsSign) {
    sh->sign_add_id = sign_add_id++;
    if (sh->text[0]) {
      buf_signcols_count_range(buf, row1, row2, 1, kFalse);
      may_force_numberwidth_recompute(buf, false);
    }
  }
}

void buf_decor_remove(buf_T *buf, int row1, int row2, int col1, DecorInline decor, bool free)
{
  decor_redraw(buf, row1, row2, col1, decor);
  if (decor.ext) {
    uint32_t idx = decor.data.ext.sh_idx;
    while (idx != DECOR_ID_INVALID) {
      DecorSignHighlight *sh = &kv_A(decor_items, idx);
      buf_remove_decor_sh(buf, row1, row2, sh);
      idx = sh->next;
    }
    if (free) {
      decor_free(decor);
    }
  }
}

void buf_remove_decor_sh(buf_T *buf, int row1, int row2, DecorSignHighlight *sh)
{
  if (sh->flags & kSHIsSign) {
    if (sh->text[0]) {
      if (buf_meta_total(buf, kMTMetaSignText)) {
        buf_signcols_count_range(buf, row1, row2, -1, kFalse);
      } else {
        may_force_numberwidth_recompute(buf, true);
        buf->b_signcols.resized = true;
        buf->b_signcols.max = buf->b_signcols.count[0] = 0;
      }
    }
  }
}

void decor_free(DecorInline decor)
{
  if (!decor.ext) {
    return;
  }
  DecorVirtText *vt = decor.data.ext.vt;
  uint32_t idx = decor.data.ext.sh_idx;

  if (decor_state.running_decor_provider) {
    while (vt) {
      if (vt->next == NULL) {
        vt->next = to_free_virt;
        to_free_virt = decor.data.ext.vt;
        break;
      }
      vt = vt->next;
    }
    while (idx != DECOR_ID_INVALID) {
      DecorSignHighlight *sh = &kv_A(decor_items, idx);
      if (sh->next == DECOR_ID_INVALID) {
        sh->next = to_free_sh;
        to_free_sh = decor.data.ext.sh_idx;
        break;
      }
      idx = sh->next;
    }
  } else {
    // safe to delete right now
    decor_free_inner(vt, idx);
  }
}

static void decor_free_inner(DecorVirtText *vt, uint32_t first_idx)
{
  while (vt) {
    if (vt->flags & kVTIsLines) {
      clear_virtlines(&vt->data.virt_lines);
    } else {
      clear_virttext(&vt->data.virt_text);
    }
    DecorVirtText *tofree = vt;
    vt = vt->next;
    xfree(tofree);
  }

  uint32_t idx = first_idx;
  while (idx != DECOR_ID_INVALID) {
    DecorSignHighlight *sh = &kv_A(decor_items, idx);
    if (sh->flags & kSHIsSign) {
      XFREE_CLEAR(sh->sign_name);
    }
    sh->flags = 0;
    if (sh->url != NULL) {
      XFREE_CLEAR(sh->url);
    }
    if (sh->next == DECOR_ID_INVALID) {
      sh->next = decor_freelist;
      decor_freelist = first_idx;
      break;
    }
    idx = sh->next;
  }
}

/// Check if we are in a callback while drawing, which might invalidate the marktree iterator.
///
/// This should be called whenever a structural modification has been done to a
/// marktree in a public API function (i e any change which adds or deletes marks).
void decor_state_invalidate(buf_T *buf)
{
  if (decor_state.win && decor_state.win->w_buffer == buf) {
    decor_state.itr_valid = false;
  }
}

void decor_check_to_be_deleted(void)
{
  assert(!decor_state.running_decor_provider);
  decor_free_inner(to_free_virt, to_free_sh);
  to_free_virt = NULL;
  to_free_sh = DECOR_ID_INVALID;
  decor_state.win = NULL;
}

void decor_state_free(DecorState *state)
{
  kv_destroy(state->slots);
  kv_destroy(state->ranges_i);
}

void clear_virttext(VirtText *text)
{
  for (size_t i = 0; i < kv_size(*text); i++) {
    xfree(kv_A(*text, i).text);
  }
  kv_destroy(*text);
  *text = (VirtText)KV_INITIAL_VALUE;
}

void clear_virtlines(VirtLines *lines)
{
  for (size_t i = 0; i < kv_size(*lines); i++) {
    clear_virttext(&kv_A(*lines, i).line);
  }
  kv_destroy(*lines);
  *lines = (VirtLines)KV_INITIAL_VALUE;
}

void decor_check_invalid_glyphs(void)
{
  for (size_t i = 0; i < kv_size(decor_items); i++) {
    DecorSignHighlight *it = &kv_A(decor_items, i);
    int width = (it->flags & kSHIsSign) ? SIGN_WIDTH : ((it->flags & kSHConceal) ? 1 : 0);
    for (int j = 0; j < width; j++) {
      if (schar_high(it->text[j])) {
        it->text[j] = schar_from_char(schar_get_first_codepoint(it->text[j]));
      }
    }
  }
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
    if (hl_id >= 0) {
      *attr = MAX(*attr, 0);
      if (hl_id > 0) {
        *attr = hl_combine_attr(*attr, syn_id2attr(hl_id));
      }
    }
  }
  return text;
}

DecorVirtText *decor_find_virttext(buf_T *buf, int row, uint64_t ns_id)
{
  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, row, 0,  itr);
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0 || mark.pos.row > row) {
      break;
    } else if (mt_invalid(mark)) {
      goto next_mark;
    }
    DecorVirtText *decor = mt_decor_virt(mark);
    while (decor && (decor->flags & kVTIsLines)) {
      decor = decor->next;
    }
    if ((ns_id == 0 || ns_id == mark.ns) && decor) {
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

  int *const indices = state->ranges_i.items;
  DecorRangeSlot *const slots = state->slots.items;

  int const beg_pos[] = { 0, state->future_begin };
  int const end_pos[] = { state->current_end, (int)kv_size(state->ranges_i) };

  for (int pos_i = 0; pos_i < 2; pos_i++) {
    for (int i = beg_pos[pos_i]; i < end_pos[pos_i]; i++) {
      DecorRange *const r = &slots[indices[i]].range;
      if (r->owned && r->kind == kDecorKindVirtText) {
        clear_virttext(&r->data.vt->data.virt_text);
        xfree(r->data.vt);
      }
    }
  }

  kv_size(state->slots) = 0;
  kv_size(state->ranges_i) = 0;
  state->free_slot_i = -1;
  state->current_end = 0;
  state->future_begin = 0;
  state->new_range_ordering = 0;

  return wp->w_buffer->b_marktree->n_keys;
}

/// @return true if decor has a virtual position (virtual text or ui_watched)
bool decor_virt_pos(const DecorRange *decor)
{
  return (decor->kind == kDecorKindVirtText || decor->kind == kDecorKindUIWatched);
}

VirtTextPos decor_virt_pos_kind(const DecorRange *decor)
{
  if (decor->kind == kDecorKindVirtText) {
    return decor->data.vt->pos;
  }
  if (decor->kind == kDecorKindUIWatched) {
    return decor->data.ui.pos;
  }
  return kVPosEndOfLine;  // not used; return whatever
}

bool decor_redraw_start(win_T *wp, int top_row, DecorState *state)
{
  buf_T *buf = wp->w_buffer;
  state->top_row = top_row;
  state->itr_valid = true;

  if (!marktree_itr_get_overlap(buf->b_marktree, top_row, 0, state->itr)) {
    return false;
  }
  MTPair pair;

  while (marktree_itr_step_overlap(buf->b_marktree, state->itr, &pair)) {
    MTKey m = pair.start;
    if (mt_invalid(m) || !mt_decor_any(m)) {
      continue;
    }

    decor_range_add_from_inline(state, pair.start.pos.row, pair.start.pos.col, pair.end_pos.row,
                                pair.end_pos.col,
                                mt_decor(m), false, m.ns, m.id);
  }

  return true;  // TODO(bfredl): check if available in the region
}

bool decor_redraw_line(win_T *wp, int row, DecorState *state)
{
  int count = (int)kv_size(state->ranges_i);
  int const cur_end = state->current_end;
  int fut_beg = state->future_begin;

  // Move future ranges to start right after current ranges.
  // Otherwise future ranges will grow forward indefinitely.
  if (fut_beg == count) {
    fut_beg = count = cur_end;
  } else if (fut_beg != cur_end) {
    int *const indices = state->ranges_i.items;
    memmove(indices + cur_end, indices + fut_beg, (size_t)(count - fut_beg) * sizeof(indices[0]));

    count = cur_end + (count - fut_beg);
    fut_beg = cur_end;
  }

  kv_size(state->ranges_i) = (size_t)count;
  state->future_begin = fut_beg;

  if (state->row == -1) {
    decor_redraw_start(wp, row, state);
  } else if (!state->itr_valid) {
    marktree_itr_get(wp->w_buffer->b_marktree, row, 0, state->itr);
    state->itr_valid = true;
  }

  state->row = row;
  state->col_until = -1;
  state->eol_col = -1;

  if (cur_end != 0 || fut_beg != count) {
    return true;
  }

  MTKey k = marktree_itr_current(state->itr);
  return (k.pos.row >= 0 && k.pos.row <= row);
}

static void decor_range_add_from_inline(DecorState *state, int start_row, int start_col,
                                        int end_row, int end_col, DecorInline decor, bool owned,
                                        uint32_t ns, uint32_t mark_id)
{
  if (decor.ext) {
    DecorVirtText *vt = decor.data.ext.vt;
    while (vt) {
      decor_range_add_virt(state, start_row, start_col, end_row, end_col, vt, owned);
      vt = vt->next;
    }
    uint32_t idx = decor.data.ext.sh_idx;
    while (idx != DECOR_ID_INVALID) {
      DecorSignHighlight *sh = &kv_A(decor_items, idx);
      decor_range_add_sh(state, start_row, start_col, end_row, end_col, sh, owned, ns, mark_id);
      idx = sh->next;
    }
  } else {
    DecorSignHighlight sh = decor_sh_from_inline(decor.data.hl);
    decor_range_add_sh(state, start_row, start_col, end_row, end_col, &sh, owned, ns, mark_id);
  }
}

static void decor_range_insert(DecorState *state, DecorRange *range)
{
  range->ordering = state->new_range_ordering++;

  int index;
  // Get space for a new `DecorRange` from the freelist or allocate.
  if (state->free_slot_i >= 0) {
    index = state->free_slot_i;
    DecorRangeSlot *slot = &kv_A(state->slots, index);
    state->free_slot_i = slot->next_free_i;
    slot->range = *range;
  } else {
    index = (int)kv_size(state->slots);
    kv_pushp(state->slots)->range = *range;
  }

  int const row = range->start_row;
  int const col = range->start_col;

  int const count = (int)kv_size(state->ranges_i);
  int *const indices = state->ranges_i.items;
  DecorRangeSlot *const slots = state->slots.items;

  int begin = state->future_begin;
  int end = count;
  while (begin < end) {
    int const mid = begin + ((end - begin) >> 1);
    DecorRange *const mr = &slots[indices[mid]].range;

    int const mrow = mr->start_row;
    int const mcol = mr->start_col;
    if (mrow < row || (mrow == row && mcol <= col)) {
      begin = mid + 1;
      if (mrow == row && mcol == col) {
        break;
      }
    } else {
      end = mid;
    }
  }

  kv_pushp(state->ranges_i);
  int *const item = &kv_A(state->ranges_i, begin);
  memmove(item + 1, item, (size_t)(count - begin) * sizeof(*item));
  *item = index;
}

void decor_range_add_virt(DecorState *state, int start_row, int start_col, int end_row, int end_col,
                          DecorVirtText *vt, bool owned)
{
  bool is_lines = vt->flags & kVTIsLines;
  DecorRange range = {
    .start_row = start_row, .start_col = start_col, .end_row = end_row, .end_col = end_col,
    .kind = is_lines ? kDecorKindVirtLines : kDecorKindVirtText,
    .data.vt = vt,
    .attr_id = 0,
    .owned = owned,
    .priority = vt->priority,
    .draw_col = -10,
  };
  decor_range_insert(state, &range);
}

void decor_range_add_sh(DecorState *state, int start_row, int start_col, int end_row, int end_col,
                        DecorSignHighlight *sh, bool owned, uint32_t ns, uint32_t mark_id)
{
  if (sh->flags & kSHIsSign) {
    return;
  }

  DecorRange range = {
    .start_row = start_row, .start_col = start_col, .end_row = end_row, .end_col = end_col,
    .kind = kDecorKindHighlight,
    .data.sh = *sh,
    .attr_id = 0,
    .owned = owned,
    .priority = sh->priority,
    .draw_col = -10,
  };

  if (sh->hl_id || (sh->url != NULL)
      || (sh->flags & (kSHConceal | kSHSpellOn | kSHSpellOff))) {
    if (sh->hl_id) {
      range.attr_id = syn_id2attr(sh->hl_id);
    }
    decor_range_insert(state, &range);
  }

  if (sh->flags & (kSHUIWatched)) {
    range.kind = kDecorKindUIWatched;
    range.data.ui.ns_id = ns;
    range.data.ui.mark_id = mark_id;
    range.data.ui.pos = (sh->flags & kSHUIWatchedOverlay) ? kVPosOverlay : kVPosEndOfLine;
    decor_range_insert(state, &range);
  }
}

/// Initialize the draw_col of a newly-added virtual text item.
void decor_init_draw_col(int win_col, bool hidden, DecorRange *item)
{
  DecorVirtText *vt = item->kind == kDecorKindVirtText ? item->data.vt : NULL;
  VirtTextPos pos = decor_virt_pos_kind(item);
  if (win_col < 0 && pos != kVPosInline) {
    item->draw_col = win_col;
  } else if (pos == kVPosOverlay) {
    item->draw_col = (vt && (vt->flags & kVTHide) && hidden) ? INT_MIN : win_col;
  } else {
    item->draw_col = -1;
  }
}

void decor_recheck_draw_col(int win_col, bool hidden, DecorState *state)
{
  int const end = state->current_end;
  int *const indices = state->ranges_i.items;
  DecorRangeSlot *const slots = state->slots.items;

  for (int i = 0; i < end; i++) {
    DecorRange *const r = &slots[indices[i]].range;
    if (r->draw_col == -3) {
      decor_init_draw_col(win_col, hidden, r);
    }
  }
}

int decor_redraw_col_impl(win_T *wp, int col, int win_col, bool hidden, DecorState *state)
{
  buf_T *const buf = wp->w_buffer;
  int const row = state->row;
  int col_until = MAXCOL;

  while (true) {
    // TODO(bfredl): check duplicate entry in "intersection"
    // branch
    MTKey mark = marktree_itr_current(state->itr);
    if (mark.pos.row < 0 || mark.pos.row > row) {
      break;
    } else if (mark.pos.row == row && mark.pos.col > col) {
      col_until = mark.pos.col - 1;
      break;
    }

    if (mt_invalid(mark) || mt_end(mark) || !mt_decor_any(mark) || !ns_in_win(mark.ns, wp)) {
      goto next_mark;
    }

    MTPos endpos = marktree_get_altpos(buf->b_marktree, mark, NULL);
    decor_range_add_from_inline(state, mark.pos.row, mark.pos.col, endpos.row, endpos.col,
                                mt_decor(mark), false, mark.ns, mark.id);

next_mark:
    marktree_itr_next(buf->b_marktree, state->itr);
  }

  int *const indices = state->ranges_i.items;
  DecorRangeSlot *const slots = state->slots.items;

  int count = (int)kv_size(state->ranges_i);
  int cur_end = state->current_end;
  int fut_beg = state->future_begin;

  // Promote future ranges before the cursor to active.
  for (; fut_beg < count; fut_beg++) {
    int const index = indices[fut_beg];
    DecorRange *const r = &slots[index].range;
    if (r->start_row > row || (r->start_row == row && r->start_col > col)) {
      break;
    }
    int const ordering = r->ordering;
    DecorPriority const priority = r->priority;

    int begin = 0;
    int end = cur_end;
    while (begin < end) {
      int mid = begin + ((end - begin) >> 1);
      int mi = indices[mid];
      DecorRange *mr = &slots[mi].range;
      if (mr->priority < priority || (mr->priority == priority && mr->ordering < ordering)) {
        begin = mid + 1;
      } else {
        end = mid;
      }
    }

    int *const item = indices + begin;
    memmove(item + 1, item, (size_t)(cur_end - begin) * sizeof(*item));
    *item = index;
    cur_end++;
  }

  if (fut_beg < count) {
    DecorRange *r = &slots[indices[fut_beg]].range;
    if (r->start_row == row) {
      col_until = MIN(col_until, r->start_col - 1);
    }
  }

  int new_cur_end = 0;

  int attr = 0;
  int conceal = 0;
  schar_T conceal_char = 0;
  int conceal_attr = 0;
  TriState spell = kNone;

  for (int i = 0; i < cur_end; i++) {
    int const index = indices[i];
    DecorRangeSlot *const slot = slots + index;
    DecorRange *const r = &slot->range;

    bool keep;
    if (r->end_row < row || (r->end_row == row && r->end_col <= col)) {
      keep = r->start_row >= row && decor_virt_pos(r);
    } else {
      keep = true;

      if (r->end_row == row && r->end_col > col) {
        col_until = MIN(col_until, r->end_col - 1);
      }

      if (r->attr_id > 0) {
        attr = hl_combine_attr(attr, r->attr_id);
      }

      if (r->kind == kDecorKindHighlight && (r->data.sh.flags & kSHConceal)) {
        conceal = 1;
        if (r->start_row == row && r->start_col == col) {
          DecorSignHighlight *sh = &r->data.sh;
          conceal = 2;
          conceal_char = sh->text[0];
          col_until = MIN(col_until, r->start_col);
          conceal_attr = r->attr_id;
        }
      }

      if (r->kind == kDecorKindHighlight) {
        if (r->data.sh.flags & kSHSpellOn) {
          spell = kTrue;
        } else if (r->data.sh.flags & kSHSpellOff) {
          spell = kFalse;
        }
        if (r->data.sh.url != NULL) {
          attr = hl_add_url(attr, r->data.sh.url);
        }
      }
    }

    if (r->start_row == row && r->start_col <= col
        && decor_virt_pos(r) && r->draw_col == -10) {
      decor_init_draw_col(win_col, hidden, r);
    }

    if (keep) {
      indices[new_cur_end++] = index;
    } else {
      if (r->owned) {
        if (r->kind == kDecorKindVirtText) {
          clear_virttext(&r->data.vt->data.virt_text);
          xfree(r->data.vt);
        } else if (r->kind == kDecorKindHighlight) {
          xfree((void *)r->data.sh.url);
        }
      }

      int *fi = &state->free_slot_i;
      slot->next_free_i = *fi;
      *fi = index;
    }
  }
  cur_end = new_cur_end;

  if (fut_beg == count) {
    fut_beg = count = cur_end;
  }

  kv_size(state->ranges_i) = (size_t)count;
  state->future_begin = fut_beg;
  state->current_end = cur_end;
  state->col_until = col_until;

  state->current = attr;
  state->conceal = conceal;
  state->conceal_char = conceal_char;
  state->conceal_attr = conceal_attr;
  state->spell = spell;
  return attr;
}

int sign_item_cmp(const void *p1, const void *p2)
{
  const SignItem *s1 = (SignItem *)p1;
  const SignItem *s2 = (SignItem *)p2;

  if (s1->sh->priority != s2->sh->priority) {
    return s1->sh->priority < s2->sh->priority ? 1 : -1;
  }

  if (s1->id != s2->id) {
    return s1->id < s2->id ? 1 : -1;
  }

  if (s1->sh->sign_add_id != s2->sh->sign_add_id) {
    return s1->sh->sign_add_id < s2->sh->sign_add_id ? 1 : -1;
  }

  return 0;
}

static const uint32_t sign_filter[4] = {[kMTMetaSignText] = kMTFilterSelect,
                                        [kMTMetaSignHL] = kMTFilterSelect };

/// Return the sign attributes on the currently refreshed row.
///
/// @param[out] sattrs Output array for sign text and texthl id
/// @param[out] line_id Highest priority linehl id
/// @param[out] cul_id Highest priority culhl id
/// @param[out] num_id Highest priority numhl id
void decor_redraw_signs(win_T *wp, buf_T *buf, int row, SignTextAttrs sattrs[], int *line_id,
                        int *cul_id, int *num_id)
{
  if (!buf_has_signs(buf)) {
    return;
  }

  MTPair pair;
  int num_text = 0;
  MarkTreeIter itr[1];
  kvec_t(SignItem) signs = KV_INITIAL_VALUE;
  // TODO(bfredl): integrate with main decor loop.
  marktree_itr_get_overlap(buf->b_marktree, row, 0, itr);
  while (marktree_itr_step_overlap(buf->b_marktree, itr, &pair)) {
    if (!mt_invalid(pair.start) && mt_decor_sign(pair.start)) {
      DecorSignHighlight *sh = decor_find_sign(mt_decor(pair.start));
      num_text += (sh->text[0] != NUL);
      kv_push(signs, ((SignItem){ sh, pair.start.id }));
    }
  }

  marktree_itr_step_out_filter(buf->b_marktree, itr, sign_filter);

  while (itr->x) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row != row) {
      break;
    }
    if (!mt_invalid(mark) && !mt_end(mark) && mt_decor_sign(mark) && ns_in_win(mark.ns, wp)) {
      DecorSignHighlight *sh = decor_find_sign(mt_decor(mark));
      num_text += (sh->text[0] != NUL);
      kv_push(signs, ((SignItem){ sh, mark.id }));
    }

    marktree_itr_next_filter(buf->b_marktree, itr, row + 1, 0, sign_filter);
  }

  if (kv_size(signs)) {
    int width = wp->w_minscwidth == SCL_NUM ? 1 : wp->w_scwidth;
    int len = MIN(width, num_text);
    int idx = 0;
    qsort((void *)&kv_A(signs, 0), kv_size(signs), sizeof(kv_A(signs, 0)), sign_item_cmp);

    for (size_t i = 0; i < kv_size(signs); i++) {
      DecorSignHighlight *sh = kv_A(signs, i).sh;
      if (idx < len && sh->text[0]) {
        memcpy(sattrs[idx].text, sh->text, SIGN_WIDTH * sizeof(sattr_T));
        sattrs[idx++].hl_id = sh->hl_id;
      }
      if (*num_id == 0) {
        *num_id = sh->number_hl_id;
      }
      if (*line_id == 0) {
        *line_id = sh->line_hl_id;
      }
      if (*cul_id == 0) {
        *cul_id = sh->cursorline_hl_id;
      }
    }
    kv_destroy(signs);
  }
}

DecorSignHighlight *decor_find_sign(DecorInline decor)
{
  if (!decor.ext) {
    return NULL;
  }
  uint32_t decor_id = decor.data.ext.sh_idx;
  while (true) {
    if (decor_id == DECOR_ID_INVALID) {
      return NULL;
    }
    DecorSignHighlight *sh = &kv_A(decor_items, decor_id);
    if (sh->flags & kSHIsSign) {
      return sh;
    }
    decor_id = sh->next;
  }
}

static const uint32_t signtext_filter[4] = {[kMTMetaSignText] = kMTFilterSelect };

/// Count the number of signs in a range after adding/removing a sign, or to
/// (re-)initialize a range in "b_signcols.count".
///
/// @param add  1, -1 or 0 for an added, deleted or initialized range.
/// @param clear  kFalse, kTrue or kNone for an, added/deleted, cleared, or initialized range.
void buf_signcols_count_range(buf_T *buf, int row1, int row2, int add, TriState clear)
{
  if (!buf->b_signcols.autom || row2 < row1 || !buf_meta_total(buf, kMTMetaSignText)) {
    return;
  }

  // Allocate an array of integers holding the number of signs in the range.
  int *count = xcalloc((size_t)(row2 + 1 - row1), sizeof(int));
  MarkTreeIter itr[1];
  MTPair pair = { 0 };

  // Increment count array for signs that start before "row1" but do overlap the range.
  marktree_itr_get_overlap(buf->b_marktree, row1, 0, itr);
  while (marktree_itr_step_overlap(buf->b_marktree, itr, &pair)) {
    if ((pair.start.flags & MT_FLAG_DECOR_SIGNTEXT) && !mt_invalid(pair.start)) {
      for (int i = row1; i <= MIN(row2, pair.end_pos.row); i++) {
        count[i - row1]++;
      }
    }
  }

  marktree_itr_step_out_filter(buf->b_marktree, itr, signtext_filter);

  // Continue traversing the marktree until beyond "row2".
  while (itr->x) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row > row2) {
      break;
    }
    if ((mark.flags & MT_FLAG_DECOR_SIGNTEXT) && !mt_invalid(mark) && !mt_end(mark)) {
      // Increment count array for the range of a paired sign mark.
      MTPos end = marktree_get_altpos(buf->b_marktree, mark, NULL);
      for (int i = mark.pos.row; i <= MIN(row2, end.row); i++) {
        count[i - row1]++;
      }
    }

    marktree_itr_next_filter(buf->b_marktree, itr, row2 + 1, 0, signtext_filter);
  }

  // For each row increment "b_signcols.count" at the number of counted signs,
  // and decrement at the previous number of signs. These two operations are
  // split in separate calls if "clear" is not kFalse (surrounding a marktree splice).
  for (int i = 0; i < row2 + 1 - row1; i++) {
    int prevwidth = MIN(SIGN_SHOW_MAX, count[i] - add);
    if (clear != kNone && prevwidth > 0) {
      buf->b_signcols.count[prevwidth - 1]--;
      assert(buf->b_signcols.count[prevwidth - 1] >= 0);
    }
    int width = MIN(SIGN_SHOW_MAX, count[i]);
    if (clear != kTrue && width > 0) {
      buf->b_signcols.count[width - 1]++;
      if (width > buf->b_signcols.max) {
        buf->b_signcols.resized = true;
        buf->b_signcols.max = width;
      }
    }
  }

  xfree(count);
}

void decor_redraw_end(DecorState *state)
{
  state->win = NULL;
}

bool decor_redraw_eol(win_T *wp, DecorState *state, int *eol_attr, int eol_col)
{
  decor_redraw_col(wp, MAXCOL, MAXCOL, false, state);
  state->eol_col = eol_col;

  int const count = state->current_end;
  int *const indices = state->ranges_i.items;
  DecorRangeSlot *const slots = state->slots.items;

  bool has_virt_pos = false;
  for (int i = 0; i < count; i++) {
    DecorRange *r = &slots[indices[i]].range;
    has_virt_pos |= r->start_row == state->row && decor_virt_pos(r);

    if (r->kind == kDecorKindHighlight && (r->data.sh.flags & kSHHlEol)) {
      *eol_attr = hl_combine_attr(*eol_attr, r->attr_id);
    }
  }
  return has_virt_pos;
}

static const uint32_t lines_filter[4] = {[kMTMetaLines] = kMTFilterSelect };

/// @param apply_folds Only count virtual lines that are not in folds.
int decor_virt_lines(win_T *wp, int start_row, int end_row, VirtLines *lines, bool apply_folds)
{
  buf_T *buf = wp->w_buffer;
  if (!buf_meta_total(buf, kMTMetaLines)) {
    // Only pay for what you use: in case virt_lines feature is not active
    // in a buffer, plines do not need to access the marktree at all
    return 0;
  }

  MarkTreeIter itr[1] = { 0 };
  if (!marktree_itr_get_filter(buf->b_marktree, MAX(start_row - 1, 0), 0, end_row, 0,
                               lines_filter, itr)) {
    return 0;
  }

  assert(start_row >= 0);

  int virt_lines = 0;
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    DecorVirtText *vt = mt_decor_virt(mark);
    if (!mt_invalid(mark) && ns_in_win(mark.ns, wp)) {
      while (vt) {
        if (vt->flags & kVTIsLines) {
          bool above = vt->flags & kVTLinesAbove;
          int mrow = mark.pos.row;
          int draw_row = mrow + (above ? 0 : 1);
          if (draw_row >= start_row && draw_row < end_row
              && (!apply_folds || !hasFolding(wp, mrow + 1, NULL, NULL))) {
            virt_lines += (int)kv_size(vt->data.virt_lines);
            if (lines) {
              kv_splice(*lines, vt->data.virt_lines);
            }
          }
        }
        vt = vt->next;
      }
    }

    if (!marktree_itr_next_filter(buf->b_marktree, itr, end_row, 0, lines_filter)) {
      break;
    }
  }

  return virt_lines;
}

/// This assumes maximum one entry of each kind, which will not always be the case.
///
/// NB: assumes caller has allocated enough space in dict for all fields!
void decor_to_dict_legacy(Dict *dict, DecorInline decor, bool hl_name, Arena *arena)
{
  DecorSignHighlight sh_hl = DECOR_SIGN_HIGHLIGHT_INIT;
  DecorSignHighlight sh_sign = DECOR_SIGN_HIGHLIGHT_INIT;
  DecorVirtText *virt_text = NULL;
  DecorVirtText *virt_lines = NULL;
  int32_t priority = -1;  // sentinel value which cannot actually be set

  if (decor.ext) {
    DecorVirtText *vt = decor.data.ext.vt;
    while (vt) {
      if (vt->flags & kVTIsLines) {
        virt_lines = vt;
      } else {
        virt_text = vt;
      }
      vt = vt->next;
    }

    uint32_t idx = decor.data.ext.sh_idx;
    while (idx != DECOR_ID_INVALID) {
      DecorSignHighlight *sh = &kv_A(decor_items, idx);
      if (sh->flags & (kSHIsSign)) {
        sh_sign = *sh;
      } else {
        sh_hl = *sh;
      }
      idx = sh->next;
    }
  } else {
    sh_hl = decor_sh_from_inline(decor.data.hl);
  }

  if (sh_hl.hl_id) {
    PUT_C(*dict, "hl_group", hl_group_name(sh_hl.hl_id, hl_name));
    PUT_C(*dict, "hl_eol", BOOLEAN_OBJ(sh_hl.flags & kSHHlEol));
    priority = sh_hl.priority;
  }

  if (sh_hl.flags & kSHConceal) {
    char buf[MAX_SCHAR_SIZE];
    schar_get(buf, sh_hl.text[0]);
    PUT_C(*dict, "conceal", CSTR_TO_ARENA_OBJ(arena, buf));
  }

  if (sh_hl.flags & kSHSpellOn) {
    PUT_C(*dict, "spell", BOOLEAN_OBJ(true));
  } else if (sh_hl.flags & kSHSpellOff) {
    PUT_C(*dict, "spell", BOOLEAN_OBJ(false));
  }

  if (sh_hl.flags & kSHUIWatched) {
    PUT_C(*dict, "ui_watched", BOOLEAN_OBJ(true));
  }

  if (sh_hl.url != NULL) {
    PUT_C(*dict, "url", STRING_OBJ(cstr_as_string(sh_hl.url)));
  }

  if (virt_text) {
    if (virt_text->hl_mode) {
      PUT_C(*dict, "hl_mode", CSTR_AS_OBJ(hl_mode_str[virt_text->hl_mode]));
    }

    Array chunks = virt_text_to_array(virt_text->data.virt_text, hl_name, arena);
    PUT_C(*dict, "virt_text", ARRAY_OBJ(chunks));
    PUT_C(*dict, "virt_text_hide", BOOLEAN_OBJ(virt_text->flags & kVTHide));
    PUT_C(*dict, "virt_text_repeat_linebreak", BOOLEAN_OBJ(virt_text->flags & kVTRepeatLinebreak));
    if (virt_text->pos == kVPosWinCol) {
      PUT_C(*dict, "virt_text_win_col", INTEGER_OBJ(virt_text->col));
    }
    PUT_C(*dict, "virt_text_pos", CSTR_AS_OBJ(virt_text_pos_str[virt_text->pos]));
    priority = virt_text->priority;
  }

  if (virt_lines) {
    Array all_chunks = arena_array(arena, kv_size(virt_lines->data.virt_lines));
    bool virt_lines_leftcol = false;
    for (size_t i = 0; i < kv_size(virt_lines->data.virt_lines); i++) {
      virt_lines_leftcol = kv_A(virt_lines->data.virt_lines, i).left_col;
      Array chunks = virt_text_to_array(kv_A(virt_lines->data.virt_lines, i).line, hl_name, arena);
      ADD(all_chunks, ARRAY_OBJ(chunks));
    }
    PUT_C(*dict, "virt_lines", ARRAY_OBJ(all_chunks));
    PUT_C(*dict, "virt_lines_above", BOOLEAN_OBJ(virt_lines->flags & kVTLinesAbove));
    PUT_C(*dict, "virt_lines_leftcol", BOOLEAN_OBJ(virt_lines_leftcol));
    priority = virt_lines->priority;
  }

  if (sh_sign.flags & kSHIsSign) {
    if (sh_sign.text[0]) {
      char buf[SIGN_WIDTH * MAX_SCHAR_SIZE];
      describe_sign_text(buf, sh_sign.text);
      PUT_C(*dict, "sign_text", CSTR_TO_ARENA_OBJ(arena, buf));
    }

    if (sh_sign.sign_name) {
      PUT_C(*dict, "sign_name", CSTR_AS_OBJ(sh_sign.sign_name));
    }

    // uncrustify:off

    struct { char *name; const int val; } hls[] = {
      { "sign_hl_group"      , sh_sign.hl_id            },
      { "number_hl_group"    , sh_sign.number_hl_id     },
      { "line_hl_group"      , sh_sign.line_hl_id       },
      { "cursorline_hl_group", sh_sign.cursorline_hl_id },
      { NULL, 0 },
    };

    // uncrustify:on

    for (int j = 0; hls[j].name; j++) {
      if (hls[j].val) {
        PUT_C(*dict, hls[j].name, hl_group_name(hls[j].val, hl_name));
      }
    }
    priority = sh_sign.priority;
  }

  if (priority != -1) {
    PUT_C(*dict, "priority", INTEGER_OBJ(priority));
  }
}

uint16_t decor_type_flags(DecorInline decor)
{
  if (decor.ext) {
    uint16_t type_flags = kExtmarkNone;
    DecorVirtText *vt = decor.data.ext.vt;
    while (vt) {
      type_flags |= (vt->flags & kVTIsLines) ? kExtmarkVirtLines : kExtmarkVirtText;
      vt = vt->next;
    }
    uint32_t idx = decor.data.ext.sh_idx;
    while (idx != DECOR_ID_INVALID) {
      DecorSignHighlight *sh = &kv_A(decor_items, idx);
      type_flags |= (sh->flags & kSHIsSign) ? kExtmarkSign : kExtmarkHighlight;
      idx = sh->next;
    }
    return type_flags;
  } else {
    return (decor.data.hl.flags & kSHIsSign) ? kExtmarkSign : kExtmarkHighlight;
  }
}

Object hl_group_name(int hl_id, bool hl_name)
{
  if (hl_name) {
    return CSTR_AS_OBJ(syn_id2name(hl_id));
  } else {
    return INTEGER_OBJ(hl_id);
  }
}
