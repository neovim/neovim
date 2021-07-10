// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/vim.h"
#include "nvim/lua/executor.h"
#include "nvim/extmark.h"
#include "nvim/decoration.h"
#include "nvim/screen.h"
#include "nvim/syntax.h"
#include "nvim/highlight.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration.c.generated.h"
#endif

static PMap(uint64_t) *hl_decors;

void decor_init(void)
{
  hl_decors = pmap_new(uint64_t)();
}

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
void bufhl_add_hl_pos_offset(buf_T *buf,
                             int src_id,
                             int hl_id,
                             lpos_T pos_start,
                             lpos_T pos_end,
                             colnr_T offset)
{
  colnr_T hl_start = 0;
  colnr_T hl_end = 0;
  Decoration *decor = decor_hl(hl_id);

  decor->priority = DECOR_PRIORITY_BASE;
  // TODO(bfredl): if decoration had blocky mode, we could avoid this loop
  for (linenr_T lnum = pos_start.lnum; lnum <= pos_end.lnum; lnum ++) {
    int end_off = 0;
    if (pos_start.lnum < lnum && lnum < pos_end.lnum) {
      // TODO(bfredl): This is quite ad-hoc, but the space between |num| and
      // text being highlighted is the indication of \n being part of the
      // substituted text. But it would be more consistent to highlight
      // a space _after_ the previous line instead (like highlight EOL list
      // char)
      hl_start = MAX(offset-1, 0);
      end_off = 1;
      hl_end = 0;
    } else if (lnum == pos_start.lnum && lnum < pos_end.lnum) {
      hl_start = pos_start.col + offset;
      end_off = 1;
      hl_end = 0;
    } else if (pos_start.lnum < lnum && lnum == pos_end.lnum) {
      hl_start = MAX(offset-1, 0);
      hl_end = pos_end.col + offset;
    } else if (pos_start.lnum == lnum && pos_end.lnum == lnum) {
      hl_start = pos_start.col + offset;
      hl_end = pos_end.col + offset;
    }
    (void)extmark_set(buf, (uint64_t)src_id, 0,
                      (int)lnum-1, hl_start, (int)lnum-1+end_off, hl_end,
                      decor, true, false, kExtmarkNoUndo);
  }
}

Decoration *decor_hl(int hl_id)
{
  assert(hl_id > 0);
  Decoration **dp = (Decoration **)pmap_ref(uint64_t)(hl_decors,
                                                      (uint64_t)hl_id, true);
  if (*dp) {
    return *dp;
  }

  Decoration *decor = xcalloc(1, sizeof(*decor));
  decor->hl_id = hl_id;
  decor->shared = true;
  decor->priority = DECOR_PRIORITY_BASE;
  *dp = decor;
  return decor;
}

void decor_redraw(buf_T *buf, int row1, int row2, Decoration *decor)
{
  if (decor->hl_id && row2 >= row1) {
    redraw_buf_range_later(buf, row1+1, row2+1);
  }

  if (kv_size(decor->virt_text)) {
    redraw_buf_line_later(buf, row1+1);
  }
}

void decor_free(Decoration *decor)
{
  if (decor && !decor->shared) {
    clear_virttext(&decor->virt_text);
    xfree(decor);
  }
}

void clear_virttext(VirtText *text)
{
  for (size_t i = 0; i < kv_size(*text); i++) {
    xfree(kv_A(*text, i).text);
  }
  kv_destroy(*text);
  *text = (VirtText)KV_INITIAL_VALUE;
}

VirtText *decor_find_virttext(buf_T *buf, int row, uint64_t ns_id)
{
  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, row, 0,  itr);
  while (true) {
    mtmark_t mark = marktree_itr_current(itr);
    if (mark.row < 0 || mark.row > row) {
      break;
    }
    ExtmarkItem *item = map_ref(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                       mark.id, false);
    if (item && (ns_id == 0 || ns_id == item->ns_id)
        && item->decor && kv_size(item->decor->virt_text)) {
      return &item->decor->virt_text;
    }
    marktree_itr_next(buf->b_marktree, itr);
  }
  return NULL;
}

bool decor_redraw_reset(buf_T *buf, DecorState *state)
{
  state->row = -1;
  state->buf = buf;
  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange item = kv_A(state->active, i);
    if (item.virt_text_owned) {
      clear_virttext(&item.decor.virt_text);
    }
  }
  kv_size(state->active) = 0;
  return buf->b_extmark_index;
}


bool decor_redraw_start(buf_T *buf, int top_row, DecorState *state)
{
  state->top_row = top_row;
  marktree_itr_get(buf->b_marktree, top_row, 0, state->itr);
  if (!state->itr->node) {
    return false;
  }
  marktree_itr_rewind(buf->b_marktree, state->itr);
  while (true) {
    mtmark_t mark = marktree_itr_current(state->itr);
    if (mark.row < 0) {  // || mark.row > end_row
      break;
    }
    if ((mark.row < top_row && mark.id&MARKTREE_END_FLAG)) {
      goto next_mark;
    }
    mtpos_t altpos = marktree_lookup(buf->b_marktree,
                                     mark.id^MARKTREE_END_FLAG, NULL);

    uint64_t start_id = mark.id & ~MARKTREE_END_FLAG;
    ExtmarkItem *item = map_ref(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                       start_id, false);
    if (!item || !item->decor) {
    // TODO(bfredl): dedicated flag for being a decoration?
      goto next_mark;
    }
    Decoration *decor = item->decor;

    if ((!(mark.id&MARKTREE_END_FLAG) && altpos.row < top_row
         && !kv_size(decor->virt_text))
        || ((mark.id&MARKTREE_END_FLAG) && altpos.row >= top_row)) {
      goto next_mark;
    }

    if (mark.id&MARKTREE_END_FLAG) {
      decor_add(state, altpos.row, altpos.col, mark.row, mark.col,
                decor, false);
    } else {
      if (altpos.row == -1) {
        altpos.row = mark.row;
        altpos.col = mark.col;
      }
      decor_add(state, mark.row, mark.col, altpos.row, altpos.col,
                decor, false);
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

bool decor_redraw_line(buf_T *buf, int row, DecorState *state)
{
  if (state->row == -1) {
    decor_redraw_start(buf, row, state);
  }
  state->row = row;
  state->col_until = -1;
  return true;  // TODO(bfredl): be more precise
}

static void decor_add(DecorState *state, int start_row, int start_col,
                      int end_row, int end_col, Decoration *decor, bool owned)
{
  int attr_id = decor->hl_id > 0 ? syn_id2attr(decor->hl_id) : 0;

  DecorRange range = { start_row, start_col, end_row, end_col,
                       *decor, attr_id,
                    kv_size(decor->virt_text) && owned, -1 };

  if (decor->virt_text_pos == kVTEndOfLine) {
    range.win_col = -2;  // handled separately
  }

  kv_pushp(state->active);
  size_t index;
  for (index = kv_size(state->active)-1; index > 0; index--) {
    DecorRange item = kv_A(state->active, index-1);
    if (item.decor.priority <= range.decor.priority) {
      break;
    }
    kv_A(state->active, index) = kv_A(state->active, index-1);
  }
  kv_A(state->active, index) = range;
}

int decor_redraw_col(buf_T *buf, int col, int win_col, bool hidden,
                     DecorState *state)
{
  if (col <= state->col_until) {
    return state->current;
  }
  state->col_until = MAXCOL;
  while (true) {
    // TODO(bfredl): check duplicate entry in "intersection"
    // branch
    mtmark_t mark = marktree_itr_current(state->itr);
    if (mark.row < 0 || mark.row > state->row) {
      break;
    } else if (mark.row == state->row && mark.col > col) {
      state->col_until = mark.col-1;
      break;
    }

    if ((mark.id&MARKTREE_END_FLAG)) {
       // TODO(bfredl): check decoration flag
      goto next_mark;
    }
    mtpos_t endpos = marktree_lookup(buf->b_marktree,
                                     mark.id|MARKTREE_END_FLAG, NULL);

    ExtmarkItem *item = map_ref(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                       mark.id, false);
    if (!item || !item->decor) {
    // TODO(bfredl): dedicated flag for being a decoration?
      goto next_mark;
    }
    Decoration *decor = item->decor;

    if (endpos.row == -1) {
      endpos.row = mark.row;
      endpos.col = mark.col;
    }

    if (endpos.row < mark.row
        || (endpos.row == mark.row && endpos.col <= mark.col)) {
      if (!kv_size(decor->virt_text)) {
        goto next_mark;
      }
    }

    decor_add(state, mark.row, mark.col, endpos.row, endpos.col,
              decor, false);

next_mark:
    marktree_itr_next(buf->b_marktree, state->itr);
  }

  int attr = 0;
  size_t j = 0;
  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange item = kv_A(state->active, i);
    bool active = false, keep = true;
    if (item.end_row < state->row
        || (item.end_row == state->row && item.end_col <= col)) {
      if (!(item.start_row >= state->row && kv_size(item.decor.virt_text))) {
        keep = false;
      }
    } else {
      if (item.start_row < state->row
          || (item.start_row == state->row && item.start_col <= col)) {
        active = true;
        if (item.end_row == state->row && item.end_col > col) {
          state->col_until = MIN(state->col_until, item.end_col-1);
        }
      } else {
        if (item.start_row == state->row) {
          state->col_until = MIN(state->col_until, item.start_col-1);
        }
      }
    }
    if (active && item.attr_id > 0) {
      attr = hl_combine_attr(attr, item.attr_id);
    }
    if ((item.start_row == state->row && item.start_col <= col)
        && kv_size(item.decor.virt_text)
        && item.decor.virt_text_pos == kVTOverlay && item.win_col == -1) {
      item.win_col = (item.decor.virt_text_hide && hidden) ? -2 : win_col;
    }
    if (keep) {
      kv_A(state->active, j++) = item;
    } else if (item.virt_text_owned) {
      clear_virttext(&item.decor.virt_text);
    }
  }
  kv_size(state->active) = j;
  state->current = attr;
  return attr;
}

void decor_redraw_end(DecorState *state)
{
  state->buf = NULL;
}

VirtText decor_redraw_eol(buf_T *buf, DecorState *state, int *eol_attr,
                          bool *aligned)
{
  decor_redraw_col(buf, MAXCOL, MAXCOL, false, state);
  VirtText text = VIRTTEXT_EMPTY;
  for (size_t i = 0; i < kv_size(state->active); i++) {
    DecorRange item = kv_A(state->active, i);
    if (item.start_row == state->row && kv_size(item.decor.virt_text)) {
      if (!kv_size(text) && item.decor.virt_text_pos == kVTEndOfLine) {
        text = item.decor.virt_text;
      } else if (item.decor.virt_text_pos == kVTRightAlign
                 || item.decor.virt_text_pos == kVTWinCol) {
        *aligned = true;
      }
    }


    if (item.decor.hl_eol && item.start_row <= state->row) {
      *eol_attr = hl_combine_attr(*eol_attr, item.attr_id);
    }
  }

  return text;
}

void decor_add_ephemeral(int start_row, int start_col, int end_row, int end_col,
                         Decoration *decor)
{
  if (end_row == -1) {
    end_row = start_row;
    end_col = start_col;
  }
  decor_add(&decor_state, start_row, start_col, end_row, end_col, decor, true);
}


DecorProvider *get_decor_provider(NS ns_id, bool force)
{
  size_t i;
  size_t len = kv_size(decor_providers);
  for (i = 0; i < len; i++) {
    DecorProvider *item = &kv_A(decor_providers, i);
    if (item->ns_id == ns_id) {
      return item;
    } else if (item->ns_id > ns_id) {
      break;
    }
  }

  if (!force) {
    return NULL;
  }

  // Adding a new provider, so allocate room in the vector
  (void)kv_a(decor_providers, len);
  if (i < len) {
    // New ns_id needs to be inserted between existing providers to maintain
    // ordering, so shift other providers with larger ns_id
    memmove(&kv_A(decor_providers, i + 1),
            &kv_A(decor_providers, i),
            (len - i) * sizeof(kv_a(decor_providers, i)));
  }
  DecorProvider *item = &kv_a(decor_providers, i);
  *item = DECORATION_PROVIDER_INIT(ns_id);

  return item;
}

void decor_provider_clear(DecorProvider *p)
{
  if (p == NULL) {
    return;
  }
  NLUA_CLEAR_REF(p->redraw_start);
  NLUA_CLEAR_REF(p->redraw_buf);
  NLUA_CLEAR_REF(p->redraw_win);
  NLUA_CLEAR_REF(p->redraw_line);
  NLUA_CLEAR_REF(p->redraw_end);
  p->active = false;
}

void decor_free_all_mem(void)
{
  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    decor_provider_clear(&kv_A(decor_providers, i));
  }
  kv_destroy(decor_providers);
}
