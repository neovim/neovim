// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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

#include "nvim/api/vim.h"
#include "nvim/buffer.h"
#include "nvim/buffer_updates.h"
#include "nvim/charset.h"
#include "nvim/decoration.h"
#include "nvim/extmark.h"
#include "nvim/globals.h"
#include "nvim/lib/kbtree.h"
#include "nvim/map.h"
#include "nvim/memline.h"
#include "nvim/pos.h"
#include "nvim/undo.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "extmark.c.generated.h"
#endif

static ExtmarkNs *buf_ns_ref(buf_T *buf, uint64_t ns_id, bool put) {
  return map_ref(uint64_t, ExtmarkNs)(buf->b_extmark_ns, ns_id, put);
}


/// Create or update an extmark
///
/// must not be used during iteration!
/// @returns the internal mark id
uint64_t extmark_set(buf_T *buf, uint64_t ns_id, uint64_t *idp, int row, colnr_T col, int end_row,
                     colnr_T end_col, Decoration *decor, bool right_gravity, bool end_right_gravity,
                     ExtmarkOp op)
{
  ExtmarkNs *ns = buf_ns_ref(buf, ns_id, true);
  assert(ns != NULL);
  mtpos_t old_pos;
  uint64_t mark = 0;
  uint64_t id = idp ? *idp : 0;

  if (id == 0) {
    id = ns->free_id++;
  } else {
    uint64_t old_mark = map_get(uint64_t, uint64_t)(ns->map, id);
    if (old_mark) {
      if (old_mark & MARKTREE_PAIRED_FLAG || end_row > -1) {
        extmark_del(buf, ns_id, id);
      } else {
        // TODO(bfredl): we need to do more if "revising" a decoration mark.
        MarkTreeIter itr[1] = { 0 };
        old_pos = marktree_lookup(buf->b_marktree, old_mark, itr);
        assert(itr->node);
        if (old_pos.row == row && old_pos.col == col) {
          ExtmarkItem it = map_del(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                          old_mark);
          if (it.decor) {
            decor_redraw(buf, row, row, it.decor);
            decor_free(it.decor);
          }
          mark = marktree_revise(buf->b_marktree, itr);
          goto revised;
        }
        marktree_del_itr(buf->b_marktree, itr, false);
      }
    } else {
      ns->free_id = MAX(ns->free_id, id+1);
    }
  }

  if (end_row > -1) {
    mark = marktree_put_pair(buf->b_marktree,
                             row, col, right_gravity,
                             end_row, end_col, end_right_gravity);
  } else {
    mark = marktree_put(buf->b_marktree, row, col, right_gravity);
  }

revised:
  map_put(uint64_t, ExtmarkItem)(buf->b_extmark_index, mark,
                                 (ExtmarkItem){ ns_id, id, decor });
  map_put(uint64_t, uint64_t)(ns->map, id, mark);

  if (op != kExtmarkNoUndo) {
    // TODO(bfredl): this doesn't cover all the cases and probably shouldn't
    // be done "prematurely". Any movement in undo history might necessitate
    // adding new marks to old undo headers.
    u_extmark_set(buf, mark, row, col);
  }

  if (decor) {
    decor_redraw(buf, row, end_row > -1 ? end_row : row, decor);
  }

  if (idp) {
    *idp = id;
  }
  return mark;
}

static bool extmark_setraw(buf_T *buf, uint64_t mark, int row, colnr_T col)
{
  MarkTreeIter itr[1] = { 0 };
  mtpos_t pos = marktree_lookup(buf->b_marktree, mark, itr);
  if (pos.row == -1) {
    return false;
  }

  if (pos.row == row && pos.col == col) {
    return true;
  }

  marktree_move(buf->b_marktree, itr, row, col);
  return true;
}

// Remove an extmark
// Returns 0 on missing id
bool extmark_del(buf_T *buf, uint64_t ns_id, uint64_t id)
{
  ExtmarkNs *ns = buf_ns_ref(buf, ns_id, false);
  if (!ns) {
    return false;
  }

  uint64_t mark = map_get(uint64_t, uint64_t)(ns->map, id);
  if (!mark) {
    return false;
  }

  MarkTreeIter itr[1] = { 0 };
  mtpos_t pos = marktree_lookup(buf->b_marktree, mark, itr);
  assert(pos.row >= 0);
  marktree_del_itr(buf->b_marktree, itr, false);
  ExtmarkItem item = map_get(uint64_t, ExtmarkItem)(buf->b_extmark_index, mark);
  mtpos_t pos2 = pos;

  if (mark & MARKTREE_PAIRED_FLAG) {
    pos2 = marktree_lookup(buf->b_marktree, mark|MARKTREE_END_FLAG, itr);
    assert(pos2.row >= 0);
    marktree_del_itr(buf->b_marktree, itr, false);
  }

  if (item.decor) {
    decor_redraw(buf, pos.row, pos2.row, item.decor);
    decor_free(item.decor);
  }

  if (mark == buf->b_virt_line_mark) {
    clear_virt_lines(buf, pos.row);
  }

  map_del(uint64_t, uint64_t)(ns->map, id);
  map_del(uint64_t, ExtmarkItem)(buf->b_extmark_index, mark);

  // TODO(bfredl): delete it from current undo header, opportunistically?
  return true;
}

// Free extmarks in a ns between lines
// if ns = 0, it means clear all namespaces
bool extmark_clear(buf_T *buf, uint64_t ns_id, int l_row, colnr_T l_col, int u_row, colnr_T u_col)
{
  if (!map_size(buf->b_extmark_ns)) {
    return false;
  }

  bool marks_cleared = false;

  bool all_ns = (ns_id == 0);
  ExtmarkNs *ns = NULL;
  if (!all_ns) {
    ns = buf_ns_ref(buf, ns_id, false);
    if (!ns) {
      // nothing to do
      return false;
    }

    // TODO(bfredl): if map_size(ns->map) << buf->b_marktree.n_nodes
    // it could be faster to iterate over the map instead
  }

  // the value is either zero or the lnum (row+1) if highlight was present.
  static Map(uint64_t, ssize_t) delete_set = MAP_INIT;
  typedef struct { Decoration *decor; int row1; } DecorItem;
  static kvec_t(DecorItem) decors;

  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, l_row, l_col, itr);
  while (true) {
    mtmark_t mark = marktree_itr_current(itr);
    if (mark.row < 0
        || mark.row > u_row
        || (mark.row == u_row && mark.col > u_col)) {
      break;
    }
    ssize_t *del_status = map_ref(uint64_t, ssize_t)(&delete_set, mark.id,
                                                     false);
    if (del_status) {
      marktree_del_itr(buf->b_marktree, itr, false);
      if (*del_status >= 0) {  // we had a decor_id
        DecorItem it = kv_A(decors, *del_status);
        decor_redraw(buf, it.row1, mark.row, it.decor);
        decor_free(it.decor);
      }
      map_del(uint64_t, ssize_t)(&delete_set, mark.id);
      continue;
    }

    uint64_t start_id = mark.id & ~MARKTREE_END_FLAG;
    if (start_id == buf->b_virt_line_mark) {
      clear_virt_lines(buf, mark.row);
    }
    ExtmarkItem item = map_get(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                      start_id);

    assert(item.ns_id > 0 && item.mark_id > 0);
    if (item.mark_id > 0 && (item.ns_id == ns_id || all_ns)) {
      marks_cleared = true;
      if (mark.id & MARKTREE_PAIRED_FLAG) {
        uint64_t other = mark.id ^ MARKTREE_END_FLAG;
        ssize_t decor_id = -1;
        if (item.decor) {
          // Save the decoration and the first pos. Clear the decoration
          // later when we know the full range.
          decor_id = (ssize_t)kv_size(decors);
          kv_push(decors,
                  ((DecorItem) { .decor = item.decor, .row1 = mark.row }));
        }
        map_put(uint64_t, ssize_t)(&delete_set, other, decor_id);
      } else if (item.decor) {
        decor_redraw(buf, mark.row, mark.row, item.decor);
        decor_free(item.decor);
      }
      ExtmarkNs *my_ns = all_ns ? buf_ns_ref(buf, item.ns_id, false) : ns;
      map_del(uint64_t, uint64_t)(my_ns->map, item.mark_id);
      map_del(uint64_t, ExtmarkItem)(buf->b_extmark_index, start_id);
      marktree_del_itr(buf->b_marktree, itr, false);
    } else {
      marktree_itr_next(buf->b_marktree, itr);
    }
  }
  uint64_t id;
  ssize_t decor_id;
  map_foreach(&delete_set, id, decor_id, {
    mtpos_t pos = marktree_lookup(buf->b_marktree, id, itr);
    assert(itr->node);
    marktree_del_itr(buf->b_marktree, itr, false);
    if (decor_id >= 0) {
      DecorItem it = kv_A(decors, decor_id);
      decor_redraw(buf, it.row1, pos.row, it.decor);
      decor_free(it.decor);
    }
  });
  map_clear(uint64_t, ssize_t)(&delete_set);
  kv_size(decors) = 0;
  return marks_cleared;
}

// Returns the position of marks between a range,
// marks found at the start or end index will be included,
// if upper_lnum or upper_col are negative the buffer
// will be searched to the start, or end
// dir can be set to control the order of the array
// amount = amount of marks to find or -1 for all
ExtmarkInfoArray extmark_get(buf_T *buf, uint64_t ns_id, int l_row, colnr_T l_col, int u_row,
                             colnr_T u_col, int64_t amount, bool reverse)
{
  ExtmarkInfoArray array = KV_INITIAL_VALUE;
  MarkTreeIter itr[1];
  // Find all the marks
  marktree_itr_get_ext(buf->b_marktree, (mtpos_t){ l_row, l_col },
                       itr, reverse, false, NULL);
  int order = reverse ? -1 : 1;
  while ((int64_t)kv_size(array) < amount) {
    mtmark_t mark = marktree_itr_current(itr);
    mtpos_t endpos = { -1, -1 };
    if (mark.row < 0
        || (mark.row - u_row) * order > 0
        || (mark.row == u_row && (mark.col - u_col) * order > 0)) {
      break;
    }
    if (mark.id & MARKTREE_END_FLAG) {
      goto next_mark;
    } else if (mark.id & MARKTREE_PAIRED_FLAG) {
      endpos = marktree_lookup(buf->b_marktree, mark.id | MARKTREE_END_FLAG,
                               NULL);
    }


    ExtmarkItem item = map_get(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                      mark.id);
    if (item.ns_id == ns_id) {
      kv_push(array, ((ExtmarkInfo) { .ns_id = item.ns_id,
                                      .mark_id = item.mark_id,
                                      .row = mark.row, .col = mark.col,
                                      .end_row = endpos.row,
                                      .end_col = endpos.col,
                                      .decor = item.decor }));
    }
next_mark:
    if (reverse) {
      marktree_itr_prev(buf->b_marktree, itr);
    } else {
      marktree_itr_next(buf->b_marktree, itr);
    }
  }
  return array;
}

// Lookup an extmark by id
ExtmarkInfo extmark_from_id(buf_T *buf, uint64_t ns_id, uint64_t id)
{
  ExtmarkNs *ns = buf_ns_ref(buf, ns_id, false);
  ExtmarkInfo ret = { 0, 0, -1, -1, -1, -1, NULL };
  if (!ns) {
    return ret;
  }

  uint64_t mark = map_get(uint64_t, uint64_t)(ns->map, id);
  if (!mark) {
    return ret;
  }

  mtpos_t pos = marktree_lookup(buf->b_marktree, mark, NULL);
  mtpos_t endpos = { -1, -1 };
  if (mark & MARKTREE_PAIRED_FLAG) {
    endpos = marktree_lookup(buf->b_marktree, mark | MARKTREE_END_FLAG, NULL);
  }
  assert(pos.row >= 0);

  ExtmarkItem item = map_get(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                    mark);

  ret.ns_id = ns_id;
  ret.mark_id = id;
  ret.row = pos.row;
  ret.col = pos.col;
  ret.end_row = endpos.row;
  ret.end_col = endpos.col;
  ret.decor = item.decor;

  return ret;
}


// free extmarks from the buffer
void extmark_free_all(buf_T *buf)
{
  if (!map_size(buf->b_extmark_ns)) {
    return;
  }

  uint64_t id;
  ExtmarkNs ns;
  ExtmarkItem item;

  marktree_clear(buf->b_marktree);

  map_foreach(buf->b_extmark_ns, id, ns, {
    (void)id;
    map_destroy(uint64_t, uint64_t)(ns.map);
  });
  map_destroy(uint64_t, ExtmarkNs)(buf->b_extmark_ns);
  map_init(uint64_t, ExtmarkNs, buf->b_extmark_ns);

  map_foreach(buf->b_extmark_index, id, item, {
    (void)id;
    decor_free(item.decor);
  });
  map_destroy(uint64_t, ExtmarkItem)(buf->b_extmark_index);
  map_init(uint64_t, ExtmarkItem, buf->b_extmark_index);
}


// Save info for undo/redo of set marks
static void u_extmark_set(buf_T *buf, uint64_t mark, int row, colnr_T col)
{
  u_header_T *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  ExtmarkSavePos pos;
  pos.mark = mark;
  pos.old_row = -1;
  pos.old_col = -1;
  pos.row = row;
  pos.col = col;

  ExtmarkUndoObject undo = { .type = kExtmarkSavePos,
                             .data.savepos = pos };

  kv_push(uhp->uh_extmark, undo);
}

/// copy extmarks data between range
///
/// useful when we cannot simply reverse the operation. This will do nothing on
/// redo, enforces correct position when undo.
void u_extmark_copy(buf_T *buf, int l_row, colnr_T l_col, int u_row, colnr_T u_col)
{
  u_header_T *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  ExtmarkUndoObject undo;

  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, l_row, l_col, itr);
  while (true) {
    mtmark_t mark = marktree_itr_current(itr);
    if (mark.row < 0
        || mark.row > u_row
        || (mark.row == u_row && mark.col > u_col)) {
      break;
    }
    ExtmarkSavePos pos;
    pos.mark = mark.id;
    pos.old_row = mark.row;
    pos.old_col = mark.col;
    pos.row = -1;
    pos.col = -1;

    undo.data.savepos = pos;
    undo.type = kExtmarkSavePos;
    kv_push(uhp->uh_extmark, undo);

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
    if (undo) {
      if (pos.old_row >= 0) {
        extmark_setraw(curbuf, pos.mark, pos.old_row, pos.old_col);
      }
      // Redo
    } else {
      if (pos.row >= 0) {
        extmark_setraw(curbuf, pos.mark, pos.row, pos.col);
      }
    }
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
  curbuf->b_virt_line_pos = -1;
}


// Adjust extmark row for inserted/deleted rows (columns stay fixed).
void extmark_adjust(buf_T *buf, linenr_T line1, linenr_T line2, long amount, long amount_after,
                    ExtmarkOp undo)
{
  if (curbuf_splice_pending) {
    return;
  }
  bcount_t start_byte = ml_find_line_or_offset(buf, line1, NULL, true);
  bcount_t old_byte = 0, new_byte = 0;
  int old_row, new_row;
  if (amount == MAXLNUM) {
    old_row = (int)(line2 - line1+1);
    // TODO(bfredl): ej kasta?
    old_byte = (bcount_t)buf->deleted_bytes2;

    new_row = (int)(amount_after + old_row);
  } else {
    // A region is either deleted (amount == MAXLNUM) or
    // added (line2 == MAXLNUM). The only other case is :move
    // which is handled by a separate entry point extmark_move_region.
    assert(line2 == MAXLNUM);
    old_row = 0;
    new_row = (int)amount;
  }
  if (new_row > 0) {
    new_byte = ml_find_line_or_offset(buf, line1+new_row, NULL, true)
               - start_byte;
  }
  extmark_splice_impl(buf,
                      (int)line1-1, 0, start_byte,
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
  long offset = ml_find_line_or_offset(buf, start_row + 1, NULL, true);

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
  buf->b_virt_line_pos = -1;
  buf_updates_send_splice(buf, start_row, start_col, start_byte,
                          old_row, old_col, old_byte,
                          new_row, new_col, new_byte);

  if (undo == kExtmarkUndo && (old_row > 0 || old_col > 0)) {
    // Copy marks that would be effected by delete
    // TODO(bfredl): Be "smart" about gravity here, left-gravity at the
    // beginning and right-gravity at the end need not be preserved.
    // Also be smart about marks that already have been saved (important for
    // merge!)
    int end_row = start_row + old_row;
    int end_col = (old_row ? 0 : start_col) + old_col;
    u_extmark_copy(buf, start_row, start_col, end_row, end_col);
  }


  marktree_splice(buf->b_marktree, start_row, start_col,
                  old_row, old_col,
                  new_row, new_col);

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
                                      kv_size(uhp->uh_extmark)-1);
      if (item->type == kExtmarkSplice) {
        ExtmarkSplice *splice = &item->data.splice;
        if (splice->start_row == start_row && splice->old_row == 0
            && splice->new_row == 0) {
          if (old_col == 0 && start_col >= splice->start_col
              && start_col <= splice->start_col+splice->new_col) {
            splice->new_col += new_col;
            splice->new_byte += new_byte;
            merged = true;
          } else if (new_col == 0
                     && start_col == splice->start_col+splice->new_col) {
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
  buf->b_virt_line_pos = -1;
  // TODO(bfredl): this is not synced to the buffer state inside the callback.
  // But unless we make the undo implementation smarter, this is not ensured
  // anyway.
  buf_updates_send_splice(buf, start_row, start_col, start_byte,
                          extent_row, extent_col, extent_byte,
                          0, 0, 0);

  marktree_move_region(buf->b_marktree, start_row, start_col,
                       extent_row, extent_col,
                       new_row, new_col);

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

uint64_t src2ns(Integer *src_id)
{
  if (*src_id == 0) {
    *src_id = (Integer)nvim_create_namespace((String)STRING_INIT);
  }
  if (*src_id < 0) {
    return UINT64_MAX;
  } else {
    return (uint64_t)(*src_id);
  }
}

