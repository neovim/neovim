#include <assert.h>
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>

#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/decoration.h"
#include "nvim/drawscreen.h"
#include "nvim/extmark.h"
#include "nvim/fold.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/map_defs.h"
#include "nvim/marktree.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/option_vars.h"
#include "nvim/pos_defs.h"
#include "nvim/sign.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration.c.generated.h"
#endif

// TODO(bfredl): These should maybe be per-buffer, so that all resources
// associated with a buffer can be freed when the buffer is unloaded.
kvec_t(DecorSignHighlight) decor_items = KV_INITIAL_VALUE;
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

void decor_redraw(buf_T *buf, int row1, int row2, DecorInline decor)
{
  if (row2 >= row1) {
    redraw_buf_range_later(buf, row1 + 1, row2 + 1);
  }

  if (decor.ext) {
    DecorVirtText *vt = decor.data.ext.vt;
    while (vt) {
      if (vt->flags & kVTIsLines) {
        redraw_buf_line_later(buf, row1 + 1 + ((vt->flags & kVTLinesAbove) ? 0 : 1), true);
        changed_line_display_buf(buf);
      } else {
        if (vt->pos == kVPosInline) {
          changed_line_display_buf(buf);
        }
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
  if (sh.hl_id || (sh.flags & (kSHIsSign|kSHSpellOn|kSHSpellOff))) {
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
    .text.sc[0] = item.conceal_char,
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
    DecorVirtText *vt = decor.data.ext.vt;
    while (vt) {
      buf_put_decor_virt(buf, vt);
      vt = vt->next;
    }

    uint32_t idx = decor.data.ext.sh_idx;
    while (idx != DECOR_ID_INVALID) {
      DecorSignHighlight *sh = &kv_A(decor_items, idx);
      buf_put_decor_sh(buf, sh, row, row2);
      idx = sh->next;
    }
  }
}

void buf_put_decor_virt(buf_T *buf, DecorVirtText *vt)
{
  if (vt->flags &kVTIsLines) {
    buf->b_virt_line_blocks++;
  } else {
    if (vt->pos == kVPosInline) {
      buf->b_virt_text_inline++;
    }
  }
  if (vt->next) {
    buf_put_decor_virt(buf, vt->next);
  }
}

static int sign_add_id = 0;
void buf_put_decor_sh(buf_T *buf, DecorSignHighlight *sh, int row1, int row2)
{
  if (sh->flags & kSHIsSign) {
    sh->sign_add_id = sign_add_id++;
    buf->b_signs++;
    if (sh->text.ptr) {
      buf->b_signs_with_text++;
      buf_signcols_invalidate_range(buf, row1, row2, 1);
    }
  }
}

void buf_decor_remove(buf_T *buf, int row1, int row2, DecorInline decor, bool free)
{
  decor_redraw(buf, row1, row2, decor);
  if (decor.ext) {
    DecorVirtText *vt = decor.data.ext.vt;
    while (vt) {
      buf_remove_decor_virt(buf, vt);
      vt = vt->next;
    }
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

void buf_remove_decor_virt(buf_T *buf, DecorVirtText *vt)
{
  if (vt->flags &kVTIsLines) {
    assert(buf->b_virt_line_blocks > 0);
    buf->b_virt_line_blocks--;
  } else {
    if (vt->pos == kVPosInline) {
      assert(buf->b_virt_text_inline > 0);
      buf->b_virt_text_inline--;
    }
  }
}

void buf_remove_decor_sh(buf_T *buf, int row1, int row2, DecorSignHighlight *sh)
{
  if (sh->flags & kSHIsSign) {
    assert(buf->b_signs > 0);
    buf->b_signs--;
    if (sh->text.ptr) {
      assert(buf->b_signs_with_text > 0);
      buf->b_signs_with_text--;
      if (row2 >= row1) {
        buf_signcols_invalidate_range(buf, row1, row2, -1);
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

void decor_free_inner(DecorVirtText *vt, uint32_t first_idx)
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
      xfree(sh->text.ptr);
    }
    if (sh->flags & kSHIsSign) {
      xfree(sh->sign_name);
    }
    sh->flags = 0;
    if (sh->next == DECOR_ID_INVALID) {
      sh->next = decor_freelist;
      decor_freelist = first_idx;
      break;
    }
    idx = sh->next;
  }
}

void decor_check_to_be_deleted(void)
{
  assert(!decor_state.running_decor_provider);
  decor_free_inner(to_free_virt, to_free_sh);
  to_free_virt = NULL;
  to_free_sh = DECOR_ID_INVALID;
}

void decor_state_free(DecorState *state)
{
  kv_destroy(state->active);
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
    if ((it->flags & kSHConceal) && schar_high(it->text.sc[0])) {
      it->text.sc[0] = schar_from_char(schar_get_first_codepoint(it->text.sc[0]));
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
    *attr = hl_combine_attr(*attr, hl_id > 0 ? syn_id2attr(hl_id) : 0);
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
    } else if (mt_invalid(mark) || !(mark.flags & MT_FLAG_DECOR_EXT)) {
      goto next_mark;
    }
    DecorVirtText *decor = mark.decor_data.ext.vt;
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
  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange item = kv_A(state->active, i);
    if (item.owned && item.kind == kDecorKindVirtText) {
      clear_virttext(&item.data.vt->data.virt_text);
      xfree(item.data.vt);
    }
  }
  kv_size(state->active) = 0;
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

static void decor_range_insert(DecorState *state, DecorRange range)
{
  kv_pushp(state->active);
  size_t index;
  for (index = kv_size(state->active) - 1; index > 0; index--) {
    DecorRange item = kv_A(state->active, index - 1);
    if (item.priority <= range.priority) {
      break;
    }
    kv_A(state->active, index) = kv_A(state->active, index - 1);
  }
  kv_A(state->active, index) = range;
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
  decor_range_insert(state, range);
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

  if (sh->hl_id || (sh->flags & (kSHConceal | kSHSpellOn | kSHSpellOff))) {
    if (sh->hl_id) {
      range.attr_id = syn_id2attr(sh->hl_id);
    }
    decor_range_insert(state, range);
  }

  if (sh->flags & (kSHUIWatched)) {
    range.kind = kDecorKindUIWatched;
    range.data.ui.ns_id = ns;
    range.data.ui.mark_id = mark_id;
    range.data.ui.pos = (sh->flags & kSHUIWatchedOverlay) ? kVPosOverlay : kVPosEndOfLine;
    decor_range_insert(state, range);
  }
}

/// Initialize the draw_col of a newly-added virtual text item.
static void decor_init_draw_col(int win_col, bool hidden, DecorRange *item)
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

    if (mt_invalid(mark) || mt_end(mark) || !mt_decor_any(mark)) {
      goto next_mark;
    }

    MTPos endpos = marktree_get_altpos(buf->b_marktree, mark, NULL);
    if (endpos.row == -1) {
      endpos = mark.pos;
    }

    decor_range_add_from_inline(state, mark.pos.row, mark.pos.col, endpos.row, endpos.col,
                                mt_decor(mark), false, mark.ns, mark.id);

next_mark:
    marktree_itr_next(buf->b_marktree, state->itr);
  }

  int attr = 0;
  size_t j = 0;
  int conceal = 0;
  schar_T conceal_char = 0;
  int conceal_attr = 0;
  TriState spell = kNone;

  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange item = kv_A(state->active, i);
    bool active = false, keep = true;
    if (item.end_row < state->row
        || (item.end_row == state->row && item.end_col <= col)) {
      if (!(item.start_row >= state->row && decor_virt_pos(&item))) {
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
    if (active && item.kind == kDecorKindHighlight && (item.data.sh.flags & kSHConceal)) {
      conceal = 1;
      if (item.start_row == state->row && item.start_col == col) {
        DecorSignHighlight *sh = &item.data.sh;
        conceal = 2;
        conceal_char = sh->text.sc[0];
        state->col_until = MIN(state->col_until, item.start_col);
        conceal_attr = item.attr_id;
      }
    }
    if (active && item.kind == kDecorKindHighlight) {
      if (item.data.sh.flags & kSHSpellOn) {
        spell = kTrue;
      } else if (item.data.sh.flags & kSHSpellOff) {
        spell = kFalse;
      }
    }
    if (item.start_row == state->row && item.start_col <= col
        && decor_virt_pos(&item) && item.draw_col == -10) {
      decor_init_draw_col(win_col, hidden, &item);
    }
    if (keep) {
      kv_A(state->active, j++) = item;
    } else if (item.owned && item.kind == kDecorKindVirtText) {
      clear_virttext(&item.data.vt->data.virt_text);
      xfree(item.data.vt);
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

typedef struct {
  DecorSignHighlight *sh;
  uint32_t id;
} SignItem;

int sign_item_cmp(const void *p1, const void *p2)
{
  const SignItem *s1 = (SignItem *)p1;
  const SignItem *s2 = (SignItem *)p2;
  int n = s2->sh->priority - s1->sh->priority;

  return n ? n : (n = (int)(s2->id - s1->id))
         ? n : (s2->sh->sign_add_id - s1->sh->sign_add_id);
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
  if (!marktree_itr_get_overlap(buf->b_marktree, row, 0, itr)) {
    return;
  }

  MTPair pair;
  int num_text = 0;
  kvec_t(SignItem) signs = KV_INITIAL_VALUE;
  // TODO(bfredl): integrate with main decor loop.
  while (marktree_itr_step_overlap(buf->b_marktree, itr, &pair)) {
    if (!mt_invalid(pair.start) && mt_decor_sign(pair.start)) {
      DecorSignHighlight *sh = decor_find_sign(mt_decor(pair.start));
      num_text += (sh->text.ptr != NULL);
      kv_push(signs, ((SignItem){ sh, pair.start.id }));
    }
  }

  while (itr->x) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row != row) {
      break;
    }
    if (!mt_end(mark) && !mt_invalid(mark) && mt_decor_sign(mark)) {
      DecorSignHighlight *sh = decor_find_sign(mt_decor(mark));
      num_text += (sh->text.ptr != NULL);
      kv_push(signs, ((SignItem){ sh, mark.id }));
    }

    marktree_itr_next(buf->b_marktree, itr);
  }

  if (kv_size(signs)) {
    int width = wp->w_minscwidth == SCL_NUM ? 1 : wp->w_scwidth;
    int idx = MIN(width, num_text) - 1;
    qsort((void *)&kv_A(signs, 0), kv_size(signs), sizeof(kv_A(signs, 0)), sign_item_cmp);

    for (size_t i = 0; i < kv_size(signs); i++) {
      DecorSignHighlight *sh = kv_A(signs, i).sh;
      if (idx >= 0 && sh->text.ptr) {
        sattrs[idx].text = sh->text.ptr;
        sattrs[idx--].hl_id = sh->hl_id;
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

static void buf_signcols_validate_row(buf_T *buf, int count, int add)
{
  // If "count" is greater than current max, set it and reset "max_count".
  if (count > buf->b_signcols.max) {
    buf->b_signcols.max = count;
    buf->b_signcols.max_count = 0;
    buf->b_signcols.resized = true;
  }
  // If row has or had "max" signs, adjust "max_count" with sign of "add".
  if (count == buf->b_signcols.max - (add < 0 ? -add : 0)) {
    buf->b_signcols.max_count += (add > 0) - (add < 0);
  }
}

/// Validate a range by counting the number of overlapping signs and adjusting
/// "b_signcols" accordingly.
static void buf_signcols_validate_range(buf_T *buf, int row1, int row2, int add)
{
  if (-add == buf->b_signcols.max) {
    buf->b_signcols.max_count -= (row2 + 1 - row1);
    return;  // max signs were removed from the range, no need to count.
  }

  int currow = row1;
  MTPair pair = { 0 };
  MarkTreeIter itr[1];

  // Allocate an array of integers holding the overlapping signs in the range.
  assert(row2 >= row1);
  int *overlap = xcalloc(sizeof(int), (size_t)(row2 + 1 - row1));

  // First find the number of overlapping signs at "row1".
  (void)marktree_itr_get_overlap(buf->b_marktree, currow, 0, itr);
  while (marktree_itr_step_overlap(buf->b_marktree, itr, &pair)) {
    if (!mt_invalid(pair.start) && pair.start.flags & MT_FLAG_DECOR_SIGNTEXT) {
      overlap[0]++;
    }
  }

  // Continue traversing the marktree until beyond "row2".
  while (itr->x) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row > row2) {
      break;
    }
    // Finish the count at the previous row.
    if (mark.pos.row != currow) {
      buf_signcols_validate_row(buf, overlap[currow - row1], add);
      currow = mark.pos.row;
    }
    // Increment overlap array for the start and range of a paired sign mark.
    if (!mt_invalid(mark) && !mt_end(mark) && (mark.flags & MT_FLAG_DECOR_SIGNTEXT)) {
      MTPos end = marktree_get_altpos(buf->b_marktree, mark, NULL);
      for (int i = currow; i <= MIN(row2, end.row < 0 ? currow : end.row); i++) {
        overlap[i - row1]++;
      }
    }

    marktree_itr_next(buf->b_marktree, itr);
  }
  buf_signcols_validate_row(buf, overlap[currow - row1], add);
  xfree(overlap);
}

int buf_signcols_validate(win_T *wp, buf_T *buf, bool stc_check)
{
  if (!map_size(buf->b_signcols.invalid)) {
    return buf->b_signcols.max;
  }

  int start;
  SignRange range;
  map_foreach(buf->b_signcols.invalid, start, range, {
    // Leave rest of the ranges invalid if max is already at configured
    // maximum or resize is detected for a 'statuscolumn' rebuild.
    if ((stc_check && buf->b_signcols.resized)
        || (!stc_check && range.add > 0 && buf->b_signcols.max >= wp->w_maxscwidth)) {
      return wp->w_maxscwidth;
    }
    buf_signcols_validate_range(buf, start, range.end, range.add);
  });

  // Check if we need to scan the entire buffer.
  if (buf->b_signcols.max_count == 0) {
    buf->b_signcols.max = 0;
    buf->b_signcols.resized = true;
    buf_signcols_validate_range(buf, 0, buf->b_ml.ml_line_count, 1);
  }

  map_clear(int, buf->b_signcols.invalid);
  return buf->b_signcols.max;
}

static void buf_signcols_invalidate_range(buf_T *buf, int row1, int row2, int add)
{
  if (!buf->b_signs_with_text) {
    buf->b_signcols.max = buf->b_signcols.max_count = 0;
    buf->b_signcols.resized = true;
    map_clear(int, buf->b_signcols.invalid);
    return;
  }

  // Remove an invalid range if sum of added/removed signs is now 0.
  SignRange *srp = map_ref(int, SignRange)(buf->b_signcols.invalid, row1, NULL);
  if (srp && srp->end == row2 && srp->add + add == 0) {
    map_del(int, SignRange)(buf->b_signcols.invalid, row1, NULL);
    return;
  }

  // Merge with overlapping invalid range.
  int start;
  SignRange range;
  map_foreach(buf->b_signcols.invalid, start, range, {
    if (row1 <= range.end && start <= row2) {
      row1 = MIN(row1, start);
      row2 = MAX(row2, range.end);
      break;
    }
  });

  srp = map_put_ref(int, SignRange)(buf->b_signcols.invalid, row1, NULL, NULL);
  srp->end = row2;
  srp->add += add;
}

void decor_redraw_end(DecorState *state)
{
  state->win = NULL;
}

bool decor_redraw_eol(win_T *wp, DecorState *state, int *eol_attr, int eol_col)
{
  decor_redraw_col(wp, MAXCOL, MAXCOL, false, state);
  state->eol_col = eol_col;
  bool has_virt_pos = false;
  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange item = kv_A(state->active, i);
    if (item.start_row == state->row && decor_virt_pos(&item)) {
      has_virt_pos = true;
    }

    if (item.kind == kDecorKindHighlight
        && (item.data.sh.flags & kSHHlEol) && item.start_row <= state->row) {
      *eol_attr = hl_combine_attr(*eol_attr, item.attr_id);
    }
  }
  return has_virt_pos;
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
    } else if (mt_end(mark) || !(mark.flags & MT_FLAG_DECOR_VIRT_LINES)) {
      goto next_mark;
    }
    DecorVirtText *vt = mark.decor_data.ext.vt;
    while (vt) {
      if (vt->flags & kVTIsLines) {
        bool above = vt->flags & kVTLinesAbove;
        int draw_row = mark.pos.row + (above ? 0 : 1);
        if (draw_row == row) {
          virt_lines += (int)kv_size(vt->data.virt_lines);
          if (lines) {
            kv_splice(*lines, vt->data.virt_lines);
          }
        }
      }
      vt = vt->next;
    }
next_mark:
    marktree_itr_next(buf->b_marktree, itr);
  }

  return virt_lines;
}

/// This assumes maximum one entry of each kind, which will not always be the case.
void decor_to_dict_legacy(Dictionary *dict, DecorInline decor, bool hl_name)
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
    PUT(*dict, "hl_group", hl_group_name(sh_hl.hl_id, hl_name));
    PUT(*dict, "hl_eol", BOOLEAN_OBJ(sh_hl.flags & kSHHlEol));
    if (sh_hl.flags & kSHConceal) {
      char buf[MAX_SCHAR_SIZE];
      schar_get(buf, sh_hl.text.sc[0]);
      PUT(*dict, "conceal", CSTR_TO_OBJ(buf));
    }

    if (sh_hl.flags & kSHSpellOn) {
      PUT(*dict, "spell", BOOLEAN_OBJ(true));
    } else if (sh_hl.flags & kSHSpellOff) {
      PUT(*dict, "spell", BOOLEAN_OBJ(false));
    }

    priority = sh_hl.priority;
  }

  if (sh_hl.flags & kSHUIWatched) {
    PUT(*dict, "ui_watched", BOOLEAN_OBJ(true));
  }

  if (virt_text) {
    if (virt_text->hl_mode) {
      PUT(*dict, "hl_mode", CSTR_TO_OBJ(hl_mode_str[virt_text->hl_mode]));
    }

    Array chunks = virt_text_to_array(virt_text->data.virt_text, hl_name);
    PUT(*dict, "virt_text", ARRAY_OBJ(chunks));
    PUT(*dict, "virt_text_hide", BOOLEAN_OBJ(virt_text->flags & kVTHide));
    if (virt_text->pos == kVPosWinCol) {
      PUT(*dict, "virt_text_win_col", INTEGER_OBJ(virt_text->col));
    }
    PUT(*dict, "virt_text_pos",
        CSTR_TO_OBJ(virt_text_pos_str[virt_text->pos]));
    priority = virt_text->priority;
  }

  if (virt_lines) {
    Array all_chunks = ARRAY_DICT_INIT;
    bool virt_lines_leftcol = false;
    for (size_t i = 0; i < kv_size(virt_lines->data.virt_lines); i++) {
      virt_lines_leftcol = kv_A(virt_lines->data.virt_lines, i).left_col;
      Array chunks = virt_text_to_array(kv_A(virt_lines->data.virt_lines, i).line, hl_name);
      ADD(all_chunks, ARRAY_OBJ(chunks));
    }
    PUT(*dict, "virt_lines", ARRAY_OBJ(all_chunks));
    PUT(*dict, "virt_lines_above", BOOLEAN_OBJ(virt_lines->flags & kVTLinesAbove));
    PUT(*dict, "virt_lines_leftcol", BOOLEAN_OBJ(virt_lines_leftcol));
    priority = virt_lines->priority;
  }

  if (sh_sign.flags & kSHIsSign) {
    if (sh_sign.text.ptr) {
      PUT(*dict, "sign_text", CSTR_TO_OBJ(sh_sign.text.ptr));
    }

    if (sh_sign.sign_name) {
      PUT(*dict, "sign_name", CSTR_TO_OBJ(sh_sign.sign_name));
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
        PUT(*dict, hls[j].name, hl_group_name(hls[j].val, hl_name));
      }
    }
    priority = sh_sign.priority;
  }

  if (priority != -1) {
    PUT(*dict, "priority", INTEGER_OBJ(priority));
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
    return CSTR_TO_OBJ(syn_id2name(hl_id));
  } else {
    return INTEGER_OBJ(hl_id);
  }
}
