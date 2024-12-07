// Implements extended marks for plugins. Marks sit in a MarkTree
// datastructure which provides both efficient mark insertations/lookups
// and adjustment to text changes. See marktree.c for more details.
//
// A map of pointers to the marks is used for fast lookup by mark id.
//
// Marks are moved by calls to extmark_splice. Some standard interfaces
// mark_adjust and inserted_bytes already adjust marks, check if these are
// being used before adding extmark_splice calls!
//
// Undo/Redo of marks is implemented by storing the call arguments to
// extmark_splice. The list of arguments is applied in extmark_apply_undo.
// We have to copy extmark positions when the extmarks are within a
// deleted/changed region.
//
// Marks live in namespaces that allow plugins/users to segregate marks
// from other users.
//
// Deleting marks only happens when explicitly calling extmark_del, deleting
// over a range of marks will only move the marks. Deleting on a mark will
// leave it in same position unless it is on the EOL of a line.
//
// Extmarks are used to implement buffer decoration. Decoration is mostly
// regarded as an application of extmarks, however for practical reasons code
// that deletes an extmark with decoration will call back into the decoration
// code for redrawing the line with the deleted decoration.

#include <assert.h>
#include <stddef.h>

#include "nvim/api/private/defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/buffer_updates.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/extmark.h"
#include "nvim/extmark_defs.h"
#include "nvim/globals.h"
#include "nvim/map_defs.h"
#include "nvim/marktree.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"
#include "nvim/undo.h"
#include "nvim/undo_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "extmark.c.generated.h"
#endif

/// Create or update an extmark
///
/// must not be used during iteration!
void extmark_set(buf_T *buf, uint32_t ns_id, uint32_t *idp, int row, colnr_T col, int end_row,
                 colnr_T end_col, DecorInline decor, uint16_t decor_flags, bool right_gravity,
                 bool end_right_gravity, bool no_undo, bool invalidate, Error *err)
{
  uint32_t *ns = map_put_ref(uint32_t, uint32_t)(buf->b_extmark_ns, ns_id, NULL, NULL);
  uint32_t id = idp ? *idp : 0;

  uint16_t flags = mt_flags(right_gravity, no_undo, invalidate, decor.ext) | decor_flags;
  if (id == 0) {
    id = ++*ns;
  } else {
    MarkTreeIter itr[1] = { 0 };
    MTKey old_mark = marktree_lookup_ns(buf->b_marktree, ns_id, id, false, itr);
    if (old_mark.id) {
      if (mt_paired(old_mark) || end_row > -1) {
        extmark_del_id(buf, ns_id, id);
      } else {
        assert(marktree_itr_valid(itr));
        if (old_mark.pos.row == row && old_mark.pos.col == col) {
          // not paired: we can revise in place
          if (!mt_invalid(old_mark) && mt_decor_any(old_mark)) {
            mt_itr_rawkey(itr).flags &= (uint16_t) ~MT_FLAG_EXTERNAL_MASK;
            buf_decor_remove(buf, row, row, col, mt_decor(old_mark), true);
          }
          mt_itr_rawkey(itr).flags |= flags;
          mt_itr_rawkey(itr).decor_data = decor.data;
          marktree_revise_meta(buf->b_marktree, itr, old_mark);
          goto revised;
        }
        marktree_del_itr(buf->b_marktree, itr, false);
        if (!mt_invalid(old_mark)) {
          buf_decor_remove(buf, old_mark.pos.row, old_mark.pos.row, old_mark.pos.col,
                           mt_decor(old_mark), true);
        }
      }
    } else {
      *ns = MAX(*ns, id);
    }
  }

  MTKey mark = { { row, col }, ns_id, id, flags, decor.data };

  marktree_put(buf->b_marktree, mark, end_row, end_col, end_right_gravity);

revised:
  if (decor_flags || decor.ext) {
    buf_put_decor(buf, decor, row, end_row > -1 ? end_row : row);
    decor_redraw(buf, row, end_row > -1 ? end_row : row, col, decor);
  }

  if (idp) {
    *idp = id;
  }
}

static void extmark_setraw(buf_T *buf, uint64_t mark, int row, colnr_T col, bool invalid)
{
  MarkTreeIter itr[1] = { 0 };
  MTKey key = marktree_lookup(buf->b_marktree, mark, itr);
  bool move = key.pos.row >= 0 && (key.pos.row != row || key.pos.col != col);
  // Already valid keys were being revalidated, presumably when encountering a
  // SavePos from a modified mark. Avoid adding that to the decor again.
  invalid = invalid && mt_invalid(key);

  // Only the position before undo needs to be redrawn here,
  // as the position after undo should be marked as changed.
  if (!invalid && mt_decor_any(key) && key.pos.row != row) {
    decor_redraw(buf, key.pos.row, key.pos.row, key.pos.col, mt_decor(key));
  }

  int row1 = 0;
  int row2 = 0;
  if (invalid) {
    mt_itr_rawkey(itr).flags &= (uint16_t) ~MT_FLAG_INVALID;
    marktree_revise_meta(buf->b_marktree, itr, key);
  } else if (move && key.flags & MT_FLAG_DECOR_SIGNTEXT && buf->b_signcols.autom) {
    MTPos end = marktree_get_altpos(buf->b_marktree, key, NULL);
    row1 = MIN(end.row, MIN(key.pos.row, row));
    row2 = MAX(end.row, MAX(key.pos.row, row));
    buf_signcols_count_range(buf, row1, row2, 0, kTrue);
  }

  if (move) {
    marktree_move(buf->b_marktree, itr, row, col);
  }

  if (invalid) {
    row2 = mt_paired(key) ? marktree_get_altpos(buf->b_marktree, key, NULL).row : row;
    buf_put_decor(buf, mt_decor(key), row, row2);
  } else if (move && key.flags & MT_FLAG_DECOR_SIGNTEXT && buf->b_signcols.autom) {
    buf_signcols_count_range(buf, row1, row2, 0, kNone);
  }
}

/// Remove an extmark in "ns_id" by "id"
///
/// @return false on missing id
bool extmark_del_id(buf_T *buf, uint32_t ns_id, uint32_t id)
{
  MarkTreeIter itr[1] = { 0 };
  MTKey key = marktree_lookup_ns(buf->b_marktree, ns_id, id, false, itr);
  if (key.id) {
    extmark_del(buf, itr, key, false);
  }

  return key.id > 0;
}

/// Remove a (paired) extmark "key" pointed to by "itr"
void extmark_del(buf_T *buf, MarkTreeIter *itr, MTKey key, bool restore)
{
  assert(key.pos.row >= 0);

  MTKey key2 = key;
  uint64_t other = marktree_del_itr(buf->b_marktree, itr, false);
  if (other) {
    key2 = marktree_lookup(buf->b_marktree, other, itr);
    assert(key2.pos.row >= 0);
    marktree_del_itr(buf->b_marktree, itr, false);
    if (restore) {
      marktree_itr_get(buf->b_marktree, key.pos.row, key.pos.col, itr);
    }
  }

  if (mt_decor_any(key)) {
    if (mt_invalid(key)) {
      decor_free(mt_decor(key));
    } else {
      buf_decor_remove(buf, key.pos.row, key2.pos.row, key.pos.col, mt_decor(key), true);
    }
  }

  // TODO(bfredl): delete it from current undo header, opportunistically?
}

/// Free extmarks in a ns between lines
/// if ns = 0, it means clear all namespaces
bool extmark_clear(buf_T *buf, uint32_t ns_id, int l_row, colnr_T l_col, int u_row, colnr_T u_col)
{
  if (!map_size(buf->b_extmark_ns)) {
    return false;
  }

  bool all_ns = (ns_id == 0);
  uint32_t *ns = NULL;
  if (!all_ns) {
    ns = map_ref(uint32_t, uint32_t)(buf->b_extmark_ns, ns_id, NULL);
    if (!ns) {
      // nothing to do
      return false;
    }
  }

  bool marks_cleared_any = false;
  bool marks_cleared_all = l_row == 0 && l_col == 0;

  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, l_row, l_col, itr);
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0
        || mark.pos.row > u_row
        || (mark.pos.row == u_row && mark.pos.col > u_col)) {
      if (mark.pos.row >= 0) {
        marks_cleared_all = false;
      }
      break;
    }
    if (mark.ns == ns_id || all_ns) {
      marks_cleared_any = true;
      extmark_del(buf, itr, mark, true);
    } else {
      marktree_itr_next(buf->b_marktree, itr);
    }
  }

  if (marks_cleared_all) {
    if (all_ns) {
      map_destroy(uint32_t, buf->b_extmark_ns);
      *buf->b_extmark_ns = (Map(uint32_t, uint32_t)) MAP_INIT;
    } else {
      map_del(uint32_t, uint32_t)(buf->b_extmark_ns, ns_id, NULL);
    }
  }

  return marks_cleared_any;
}

/// @return  the position of marks between a range,
///          marks found at the start or end index will be included.
///
/// if upper_lnum or upper_col are negative the buffer
/// will be searched to the start, or end
/// reverse can be set to control the order of the array
/// amount = amount of marks to find or INT64_MAX for all
ExtmarkInfoArray extmark_get(buf_T *buf, uint32_t ns_id, int l_row, colnr_T l_col, int u_row,
                             colnr_T u_col, int64_t amount, bool reverse, ExtmarkType type_filter,
                             bool overlap)
{
  ExtmarkInfoArray array = KV_INITIAL_VALUE;
  MarkTreeIter itr[1];

  if (overlap) {
    // Find all the marks overlapping the start position
    if (!marktree_itr_get_overlap(buf->b_marktree, l_row, l_col, itr)) {
      return array;
    }

    MTPair pair;
    while (marktree_itr_step_overlap(buf->b_marktree, itr, &pair)) {
      push_mark(&array, ns_id, type_filter, pair);
    }
  } else {
    // Find all the marks beginning with the start position
    marktree_itr_get_ext(buf->b_marktree, MTPos(l_row, l_col),
                         itr, reverse, false, NULL, NULL);
  }

  int order = reverse ? -1 : 1;
  while ((int64_t)kv_size(array) < amount) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0
        || (mark.pos.row - u_row) * order > 0
        || (mark.pos.row == u_row && (mark.pos.col - u_col) * order > 0)) {
      break;
    }
    if (mt_end(mark)) {
      goto next_mark;
    }

    MTKey end = marktree_get_alt(buf->b_marktree, mark, NULL);
    push_mark(&array, ns_id, type_filter, mtpair_from(mark, end));
next_mark:
    if (reverse) {
      marktree_itr_prev(buf->b_marktree, itr);
    } else {
      marktree_itr_next(buf->b_marktree, itr);
    }
  }
  return array;
}

static void push_mark(ExtmarkInfoArray *array, uint32_t ns_id, ExtmarkType type_filter, MTPair mark)
{
  if (!(ns_id == UINT32_MAX || mark.start.ns == ns_id)) {
    return;
  }
  if (type_filter != kExtmarkNone) {
    if (!mt_decor_any(mark.start)) {
      return;
    }
    uint16_t type_flags = decor_type_flags(mt_decor(mark.start));

    if (!(type_flags & type_filter)) {
      return;
    }
  }

  kv_push(*array, mark);
}

/// Lookup an extmark by id
MTPair extmark_from_id(buf_T *buf, uint32_t ns_id, uint32_t id)
{
  MTKey mark = marktree_lookup_ns(buf->b_marktree, ns_id, id, false, NULL);
  if (!mark.id) {
    return mtpair_from(mark, mark);  // invalid
  }
  assert(mark.pos.row >= 0);
  MTKey end = marktree_get_alt(buf->b_marktree, mark, NULL);

  return mtpair_from(mark, end);
}

/// free extmarks from the buffer
void extmark_free_all(buf_T *buf)
{
  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, 0, 0, itr);
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0) {
      break;
    }

    // don't free mark.decor twice for a paired mark.
    if (!(mt_paired(mark) && mt_end(mark))) {
      decor_free(mt_decor(mark));
    }

    marktree_itr_next(buf->b_marktree, itr);
  }

  marktree_clear(buf->b_marktree);

  buf->b_signcols.max = 0;
  CLEAR_FIELD(buf->b_signcols.count);

  map_destroy(uint32_t, buf->b_extmark_ns);
  *buf->b_extmark_ns = (Map(uint32_t, uint32_t)) MAP_INIT;
}

/// invalidate extmarks between range and copy to undo header
///
/// copying is useful when we cannot simply reverse the operation. This will do
/// nothing on redo, enforces correct position when undo.
void extmark_splice_delete(buf_T *buf, int l_row, colnr_T l_col, int u_row, colnr_T u_col,
                           extmark_undo_vec_t *uvp, bool only_copy, ExtmarkOp op)
{
  MarkTreeIter itr[1] = { 0 };
  ExtmarkUndoObject undo;

  marktree_itr_get(buf->b_marktree, (int32_t)l_row, l_col, itr);
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0 || mark.pos.row > u_row) {
      break;
    }

    bool copy = true;
    // No need to copy left gravity marks at the beginning of the range,
    // and right gravity marks at the end of the range, unless invalidated.
    if (mark.pos.row == l_row && mark.pos.col - !mt_right(mark) < l_col) {
      copy = false;
    } else if (mark.pos.row == u_row) {
      if (mark.pos.col > u_col + 1) {
        break;
      } else if (mark.pos.col + mt_right(mark) > u_col) {
        copy = false;
      }
    }

    bool invalidated = false;
    // Invalidate/delete mark
    if (!only_copy && !mt_invalid(mark) && mt_invalidate(mark) && !mt_end(mark)) {
      MTPos endpos = marktree_get_altpos(buf->b_marktree, mark, NULL);
      // Invalidate unpaired marks in deleted lines and paired marks whose entire
      // range has been deleted.
      if ((!mt_paired(mark) && mark.pos.row < u_row)
          || (mt_paired(mark)
              && (endpos.col <= u_col || (!u_col && endpos.row == mark.pos.row))
              && mark.pos.col >= l_col
              && mark.pos.row >= l_row && endpos.row <= u_row - (u_col ? 0 : 1))) {
        if (mt_no_undo(mark)) {
          extmark_del(buf, itr, mark, true);
          continue;
        } else {
          copy = true;
          invalidated = true;
          mt_itr_rawkey(itr).flags |= MT_FLAG_INVALID;
          marktree_revise_meta(buf->b_marktree, itr, mark);
          buf_decor_remove(buf, mark.pos.row, endpos.row, mark.pos.col, mt_decor(mark), false);
        }
      }
    }

    // Push mark to undo header
    if (copy && (only_copy || (uvp != NULL && op == kExtmarkUndo && !mt_no_undo(mark)))) {
      ExtmarkSavePos pos = {
        .mark = mt_lookup_key(mark),
        .invalidated = invalidated,
        .old_row = mark.pos.row,
        .old_col = mark.pos.col
      };
      undo.data.savepos = pos;
      undo.type = kExtmarkSavePos;
      kv_push(*uvp, undo);
    }

    marktree_itr_next(buf->b_marktree, itr);
  }
}

/// undo or redo an extmark operation
void extmark_apply_undo(ExtmarkUndoObject undo_info, bool undo)
{
  // splice: any text operation changing position (except :move)
  if (undo_info.type == kExtmarkSplice) {
    // Undo
    ExtmarkSplice splice = undo_info.data.splice;
    if (undo) {
      extmark_splice_impl(curbuf,
                          splice.start_row, splice.start_col, splice.start_byte,
                          splice.new_row, splice.new_col, splice.new_byte,
                          splice.old_row, splice.old_col, splice.old_byte,
                          kExtmarkNoUndo);
    } else {
      extmark_splice_impl(curbuf,
                          splice.start_row, splice.start_col, splice.start_byte,
                          splice.old_row, splice.old_col, splice.old_byte,
                          splice.new_row, splice.new_col, splice.new_byte,
                          kExtmarkNoUndo);
    }
    // kExtmarkSavePos
  } else if (undo_info.type == kExtmarkSavePos) {
    ExtmarkSavePos pos = undo_info.data.savepos;
    if (undo && pos.old_row >= 0) {
      extmark_setraw(curbuf, pos.mark, pos.old_row, pos.old_col, pos.invalidated);
    }
    // No Redo since kExtmarkSplice will move marks back
  } else if (undo_info.type == kExtmarkMove) {
    ExtmarkMove move = undo_info.data.move;
    if (undo) {
      extmark_move_region(curbuf,
                          move.new_row, move.new_col, move.new_byte,
                          move.extent_row, move.extent_col, move.extent_byte,
                          move.start_row, move.start_col, move.start_byte,
                          kExtmarkNoUndo);
    } else {
      extmark_move_region(curbuf,
                          move.start_row, move.start_col, move.start_byte,
                          move.extent_row, move.extent_col, move.extent_byte,
                          move.new_row, move.new_col, move.new_byte,
                          kExtmarkNoUndo);
    }
  }
}

/// Adjust extmark row for inserted/deleted rows (columns stay fixed).
void extmark_adjust(buf_T *buf, linenr_T line1, linenr_T line2, linenr_T amount,
                    linenr_T amount_after, ExtmarkOp undo)
{
  if (curbuf_splice_pending) {
    return;
  }
  bcount_t start_byte = ml_find_line_or_offset(buf, line1, NULL, true);
  bcount_t old_byte = 0;
  bcount_t new_byte = 0;
  int old_row;
  int new_row;
  if (amount == MAXLNUM) {
    old_row = line2 - line1 + 1;
    // TODO(bfredl): ej kasta?
    old_byte = (bcount_t)buf->deleted_bytes2;
    new_row = amount_after + old_row;
  } else {
    // A region is either deleted (amount == MAXLNUM) or
    // added (line2 == MAXLNUM). The only other case is :move
    // which is handled by a separate entry point extmark_move_region.
    assert(line2 == MAXLNUM);
    old_row = 0;
    new_row = (int)amount;
  }
  if (new_row > 0) {
    new_byte = ml_find_line_or_offset(buf, line1 + new_row, NULL, true)
               - start_byte;
  }
  extmark_splice_impl(buf,
                      (int)line1 - 1, 0, start_byte,
                      old_row, 0, old_byte,
                      new_row, 0, new_byte, undo);
}

// Adjust extmarks following a text edit.
//
// @param buf
// @param start_row   Start row of the region to be changed
// @param start_col   Start col of the region to be changed
// @param old_row     End row of the region to be changed.
//                      Encoded as an offset to start_row.
// @param old_col     End col of the region to be changed. Encodes
//                      an offset from start_col if old_row = 0; otherwise,
//                      encodes the end column of the old region.
// @param old_byte    Byte extent of the region to be changed.
// @param new_row     Row offset of the new region.
// @param new_col     Col offset of the new region. Encodes an offset from
//                      start_col if new_row = 0; otherwise, encodes
//                      the end column of the new region.
// @param new_byte    Byte extent of the new region.
// @param undo
void extmark_splice(buf_T *buf, int start_row, colnr_T start_col, int old_row, colnr_T old_col,
                    bcount_t old_byte, int new_row, colnr_T new_col, bcount_t new_byte,
                    ExtmarkOp undo)
{
  int offset = ml_find_line_or_offset(buf, start_row + 1, NULL, true);

  // On empty buffers, when editing the first line, the line is buffered,
  // causing offset to be < 0. While the buffer is not actually empty, the
  // buffered line has not been flushed (and should not be) yet, so the call is
  // valid but an edge case.
  //
  // TODO(vigoux): maybe the is a better way of testing that ?
  if (offset < 0 && buf->b_ml.ml_chunksize == NULL) {
    offset = 0;
  }
  extmark_splice_impl(buf, start_row, start_col, offset + start_col,
                      old_row, old_col, old_byte, new_row, new_col, new_byte,
                      undo);
}

void extmark_splice_impl(buf_T *buf, int start_row, colnr_T start_col, bcount_t start_byte,
                         int old_row, colnr_T old_col, bcount_t old_byte, int new_row,
                         colnr_T new_col, bcount_t new_byte, ExtmarkOp undo)
{
  buf->deleted_bytes2 = 0;
  buf_updates_send_splice(buf, start_row, start_col, start_byte,
                          old_row, old_col, old_byte,
                          new_row, new_col, new_byte);

  if (old_row > 0 || old_col > 0) {
    // Copy and invalidate marks that would be effected by delete
    // TODO(bfredl): Be smart about marks that already have been
    // saved (important for merge!)
    int end_row = start_row + old_row;
    int end_col = (old_row ? 0 : start_col) + old_col;
    u_header_T *uhp = u_force_get_undo_header(buf);
    extmark_undo_vec_t *uvp = uhp ? &uhp->uh_extmark : NULL;
    extmark_splice_delete(buf, start_row, start_col, end_row, end_col, uvp, false, undo);
  }

  // Remove signs inside edited region from "b_signcols.count", add after splicing.
  if (old_row > 0 || new_row > 0) {
    buf_signcols_count_range(buf, start_row, start_row + old_row, 0, kTrue);
  }

  marktree_splice(buf->b_marktree, (int32_t)start_row, start_col,
                  old_row, old_col,
                  new_row, new_col);

  if (old_row > 0 || new_row > 0) {
    buf_signcols_count_range(buf, start_row, start_row + new_row, 0, kNone);
  }

  if (undo == kExtmarkUndo) {
    u_header_T *uhp = u_force_get_undo_header(buf);
    if (!uhp) {
      return;
    }

    bool merged = false;
    // TODO(bfredl): this is quite rudimentary. We merge small (within line)
    // inserts with each other and small deletes with each other. Add full
    // merge algorithm later.
    if (old_row == 0 && new_row == 0 && kv_size(uhp->uh_extmark)) {
      ExtmarkUndoObject *item = &kv_A(uhp->uh_extmark,
                                      kv_size(uhp->uh_extmark) - 1);
      if (item->type == kExtmarkSplice) {
        ExtmarkSplice *splice = &item->data.splice;
        if (splice->start_row == start_row && splice->old_row == 0
            && splice->new_row == 0) {
          if (old_col == 0 && start_col >= splice->start_col
              && start_col <= splice->start_col + splice->new_col) {
            splice->new_col += new_col;
            splice->new_byte += new_byte;
            merged = true;
          } else if (new_col == 0
                     && start_col == splice->start_col + splice->new_col) {
            splice->old_col += old_col;
            splice->old_byte += old_byte;
            merged = true;
          } else if (new_col == 0
                     && start_col + old_col == splice->start_col) {
            splice->start_col = start_col;
            splice->start_byte = start_byte;
            splice->old_col += old_col;
            splice->old_byte += old_byte;
            merged = true;
          }
        }
      }
    }

    if (!merged) {
      ExtmarkSplice splice;
      splice.start_row = start_row;
      splice.start_col = start_col;
      splice.start_byte = start_byte;
      splice.old_row = old_row;
      splice.old_col = old_col;
      splice.old_byte = old_byte;
      splice.new_row = new_row;
      splice.new_col = new_col;
      splice.new_byte = new_byte;

      kv_push(uhp->uh_extmark,
              ((ExtmarkUndoObject){ .type = kExtmarkSplice,
                                    .data.splice = splice }));
    }
  }
}

void extmark_splice_cols(buf_T *buf, int start_row, colnr_T start_col, colnr_T old_col,
                         colnr_T new_col, ExtmarkOp undo)
{
  extmark_splice(buf, start_row, start_col,
                 0, old_col, old_col,
                 0, new_col, new_col, undo);
}

void extmark_move_region(buf_T *buf, int start_row, colnr_T start_col, bcount_t start_byte,
                         int extent_row, colnr_T extent_col, bcount_t extent_byte, int new_row,
                         colnr_T new_col, bcount_t new_byte, ExtmarkOp undo)
{
  buf->deleted_bytes2 = 0;
  // TODO(bfredl): this is not synced to the buffer state inside the callback.
  // But unless we make the undo implementation smarter, this is not ensured
  // anyway.
  buf_updates_send_splice(buf, start_row, start_col, start_byte,
                          extent_row, extent_col, extent_byte,
                          0, 0, 0);

  int row1 = MIN(start_row, new_row);
  int row2 = MAX(start_row, new_row) + extent_row;
  buf_signcols_count_range(buf, row1, row2, 0, kTrue);

  marktree_move_region(buf->b_marktree, start_row, start_col,
                       extent_row, extent_col,
                       new_row, new_col);

  buf_signcols_count_range(buf, row1, row2, 0, kNone);

  buf_updates_send_splice(buf, new_row, new_col, new_byte,
                          0, 0, 0,
                          extent_row, extent_col, extent_byte);

  if (undo == kExtmarkUndo) {
    u_header_T *uhp = u_force_get_undo_header(buf);
    if (!uhp) {
      return;
    }

    ExtmarkMove move;
    move.start_row = start_row;
    move.start_col = start_col;
    move.start_byte = start_byte;
    move.extent_row = extent_row;
    move.extent_col = extent_col;
    move.extent_byte = extent_byte;
    move.new_row = new_row;
    move.new_col = new_col;
    move.new_byte = new_byte;

    kv_push(uhp->uh_extmark,
            ((ExtmarkUndoObject){ .type = kExtmarkMove,
                                  .data.move = move }));
  }
}
