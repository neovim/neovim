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
#include <sys/types.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/buffer_updates.h"
#include "nvim/decoration.h"
#include "nvim/extmark.h"
#include "nvim/extmark_defs.h"
#include "nvim/globals.h"
#include "nvim/map.h"
#include "nvim/marktree.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/pos.h"
#include "nvim/undo.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "extmark.c.generated.h"
#endif

/// Create or update an extmark
///
/// must not be used during iteration!
void extmark_set(buf_T *buf, uint32_t ns_id, uint32_t *idp, int row, colnr_T col, int end_row,
                 colnr_T end_col, Decoration *decor, bool right_gravity, bool end_right_gravity,
                 ExtmarkOp op, Error *err)
{
  uint32_t *ns = map_put_ref(uint32_t, uint32_t)(buf->b_extmark_ns, ns_id, NULL, NULL);
  uint32_t id = idp ? *idp : 0;
  bool decor_full = false;

  uint8_t decor_level = kDecorLevelNone;  // no decor
  if (decor) {
    if (kv_size(decor->virt_text)
        || kv_size(decor->virt_lines)
        || decor->conceal
        || decor_has_sign(decor)
        || decor->ui_watched
        || decor->spell != kNone) {
      decor_full = true;
      decor = xmemdup(decor, sizeof *decor);
    }
    decor_level = kDecorLevelVisible;  // decor affects redraw
    if (kv_size(decor->virt_lines)) {
      decor_level = kDecorLevelVirtLine;  // decor affects horizontal size
    }
  }

  if (id == 0) {
    id = ++*ns;
  } else {
    MarkTreeIter itr[1] = { 0 };
    MTKey old_mark = marktree_lookup_ns(buf->b_marktree, ns_id, id, false, itr);
    if (old_mark.id) {
      if (decor_state.running_on_lines) {
        if (err) {
          api_set_error(err, kErrorTypeException,
                        "Cannot change extmarks during on_line callbacks");
        }
        goto error;
      }
      if (mt_paired(old_mark) || end_row > -1) {
        extmark_del(buf, ns_id, id);
      } else {
        // TODO(bfredl): we need to do more if "revising" a decoration mark.
        assert(marktree_itr_valid(itr));
        if (old_mark.pos.row == row && old_mark.pos.col == col) {
          if (marktree_decor_level(old_mark) > kDecorLevelNone) {
            decor_remove(buf, row, row, old_mark.decor_full);
            old_mark.decor_full = NULL;
          }
          old_mark.flags = 0;
          if (decor_full) {
            old_mark.decor_full = decor;
          } else if (decor) {
            old_mark.hl_id = decor->hl_id;
            // Workaround: the gcc compiler of functionaltest-lua build
            // apparently incapable of handling basic integer constants.
            // This can be underanged as soon as we bump minimal gcc version.
            old_mark.flags = (uint16_t)(old_mark.flags
                                        | (decor->hl_eol ? (uint16_t)MT_FLAG_HL_EOL : (uint16_t)0));
            old_mark.priority = decor->priority;
          }
          marktree_revise(buf->b_marktree, itr, decor_level, old_mark);
          goto revised;
        }
        decor_remove(buf, old_mark.pos.row, old_mark.pos.row, old_mark.decor_full);
        marktree_del_itr(buf->b_marktree, itr, false);
      }
    } else {
      *ns = MAX(*ns, id);
    }
  }

  MTKey mark = { { row, col }, ns_id, id, 0,
                 mt_flags(right_gravity, decor_level), 0, NULL };
  if (decor_full) {
    mark.decor_full = decor;
  } else if (decor) {
    mark.hl_id = decor->hl_id;
    // workaround: see above
    mark.flags = (uint16_t)(mark.flags | (decor->hl_eol ? (uint16_t)MT_FLAG_HL_EOL : (uint16_t)0));
    mark.priority = decor->priority;
  }

  marktree_put(buf->b_marktree, mark, end_row, end_col, end_right_gravity);

revised:
  if (op != kExtmarkNoUndo) {
    // TODO(bfredl): this doesn't cover all the cases and probably shouldn't
    // be done "prematurely". Any movement in undo history might necessitate
    // adding new marks to old undo headers. add a test case for this (doesn't
    // fail extmark_spec.lua, and it should)
    uint64_t mark_id = mt_lookup_id(ns_id, id, false);
    u_extmark_set(buf, mark_id, row, col);
  }

  if (decor) {
    if (kv_size(decor->virt_text) && decor->virt_text_pos == kVTInline) {
      buf->b_virt_text_inline++;
    }
    if (kv_size(decor->virt_lines)) {
      buf->b_virt_line_blocks++;
    }
    if (decor_has_sign(decor)) {
      buf->b_signs++;
    }
    if (decor->sign_text) {
      buf->b_signs_with_text++;
      // TODO(lewis6991): smarter invalidation
      buf_signcols_add_check(buf, NULL);
    }
    decor_redraw(buf, row, end_row > -1 ? end_row : row, decor);
  }

  if (idp) {
    *idp = id;
  }

  return;

error:
  if (decor_full) {
    decor_free(decor);
  }
}

static bool extmark_setraw(buf_T *buf, uint64_t mark, int row, colnr_T col)
{
  MarkTreeIter itr[1] = { 0 };
  MTKey key = marktree_lookup(buf->b_marktree, mark, itr);
  if (key.pos.row == -1) {
    return false;
  }

  if (key.pos.row == row && key.pos.col == col) {
    return true;
  }

  marktree_move(buf->b_marktree, itr, row, col);
  return true;
}

/// Remove an extmark
///
/// @return  0 on missing id
bool extmark_del(buf_T *buf, uint32_t ns_id, uint32_t id)
{
  MarkTreeIter itr[1] = { 0 };
  MTKey key = marktree_lookup_ns(buf->b_marktree, ns_id, id, false, itr);
  if (!key.id) {
    return false;
  }
  assert(key.pos.row >= 0);
  uint64_t other = marktree_del_itr(buf->b_marktree, itr, false);

  MTKey key2 = key;

  if (other) {
    key2 = marktree_lookup(buf->b_marktree, other, itr);
    assert(key2.pos.row >= 0);
    marktree_del_itr(buf->b_marktree, itr, false);
  }

  if (marktree_decor_level(key) > kDecorLevelNone) {
    decor_remove(buf, key.pos.row, key2.pos.row, key.decor_full);
  }

  // TODO(bfredl): delete it from current undo header, opportunistically?
  return true;
}

/// Free extmarks in a ns between lines
/// if ns = 0, it means clear all namespaces
bool extmark_clear(buf_T *buf, uint32_t ns_id, int l_row, colnr_T l_col, int u_row, colnr_T u_col)
{
  if (!map_size(buf->b_extmark_ns)) {
    return false;
  }

  bool marks_cleared = false;

  bool all_ns = (ns_id == 0);
  uint32_t *ns = NULL;
  if (!all_ns) {
    ns = map_ref(uint32_t, uint32_t)(buf->b_extmark_ns, ns_id, NULL);
    if (!ns) {
      // nothing to do
      return false;
    }
  }

  // the value is either zero or the lnum (row+1) if highlight was present.
  static Map(uint64_t, ssize_t) delete_set = MAP_INIT;
  typedef struct { int row1; } DecorItem;
  static kvec_t(DecorItem) decors;

  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, l_row, l_col, itr);
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0
        || mark.pos.row > u_row
        || (mark.pos.row == u_row && mark.pos.col > u_col)) {
      break;
    }
    ssize_t *del_status = map_ref(uint64_t, ssize_t)(&delete_set, mt_lookup_key(mark), NULL);
    if (del_status) {
      marktree_del_itr(buf->b_marktree, itr, false);
      if (*del_status >= 0) {  // we had a decor_id
        DecorItem it = kv_A(decors, *del_status);
        decor_remove(buf, it.row1, mark.pos.row, mark.decor_full);
      }
      map_del(uint64_t, ssize_t)(&delete_set, mt_lookup_key(mark), NULL);
      continue;
    }

    assert(mark.ns > 0 && mark.id > 0);
    if (mark.ns == ns_id || all_ns) {
      marks_cleared = true;
      if (mark.decor_full && !mt_paired(mark)) {  // if paired: deal with it later
        decor_remove(buf, mark.pos.row, mark.pos.row, mark.decor_full);
      }
      uint64_t other = marktree_del_itr(buf->b_marktree, itr, false);
      if (mt_paired(mark)) {
        ssize_t decor_id = -1;
        if (marktree_decor_level(mark) > kDecorLevelNone) {
          // Save the decoration and the first pos. Clear the decoration
          // later when we know the full range.
          decor_id = (ssize_t)kv_size(decors);
          kv_push(decors,
                  ((DecorItem) { .row1 = mark.pos.row }));
        }
        map_put(uint64_t, ssize_t)(&delete_set, other, decor_id);
      }
    } else {
      marktree_itr_next(buf->b_marktree, itr);
    }
  }
  uint64_t id;
  ssize_t decor_id;
  map_foreach(&delete_set, id, decor_id, {
    MTKey mark = marktree_lookup(buf->b_marktree, id, itr);
    assert(marktree_itr_valid(itr));
    marktree_del_itr(buf->b_marktree, itr, false);
    if (decor_id >= 0) {
      DecorItem it = kv_A(decors, decor_id);
      decor_remove(buf, it.row1, mark.pos.row, mark.decor_full);
    }
  });
  map_clear(uint64_t, &delete_set);
  kv_size(decors) = 0;
  return marks_cleared;
}

/// @return  the position of marks between a range,
///          marks found at the start or end index will be included.
///
/// if upper_lnum or upper_col are negative the buffer
/// will be searched to the start, or end
/// dir can be set to control the order of the array
/// amount = amount of marks to find or -1 for all
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
      push_mark(&array, ns_id, type_filter, pair.start, pair.end_pos, pair.end_right_gravity);
    }
  } else {
    // Find all the marks beginning with the start position
    marktree_itr_get_ext(buf->b_marktree, MTPos(l_row, l_col),
                         itr, reverse, false, NULL);
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
    push_mark(&array, ns_id, type_filter, mark, end.pos, mt_right(end));
next_mark:
    if (reverse) {
      marktree_itr_prev(buf->b_marktree, itr);
    } else {
      marktree_itr_next(buf->b_marktree, itr);
    }
  }
  return array;
}

static void push_mark(ExtmarkInfoArray *array, uint32_t ns_id, ExtmarkType type_filter, MTKey mark,
                      MTPos end_pos, bool end_right)
{
  if (!(ns_id == UINT32_MAX || mark.ns == ns_id)) {
    return;
  }
  uint16_t type_flags = kExtmarkNone;
  if (type_filter != kExtmarkNone) {
    Decoration *decor = mark.decor_full;
    if (decor && (decor->sign_text || decor->number_hl_id)) {
      type_flags |= kExtmarkSign;
    }
    if (decor && decor->virt_text.size) {
      type_flags |= kExtmarkVirtText;
    }
    if (decor && decor->virt_lines.size) {
      type_flags |= kExtmarkVirtLines;
    }
    if ((decor && (decor->line_hl_id || decor->cursorline_hl_id))
        || mark.hl_id) {
      type_flags |= kExtmarkHighlight;
    }

    if (!(type_flags & type_filter)) {
      return;
    }
  }

  kv_push(*array, ((ExtmarkInfo) { .ns_id = mark.ns,
                                   .mark_id = mark.id,
                                   .row = mark.pos.row, .col = mark.pos.col,
                                   .end_row = end_pos.row,
                                   .end_col = end_pos.col,
                                   .right_gravity = mt_right(mark),
                                   .end_right_gravity = end_right,
                                   .decor = get_decor(mark) }));
}

/// Lookup an extmark by id
ExtmarkInfo extmark_from_id(buf_T *buf, uint32_t ns_id, uint32_t id)
{
  ExtmarkInfo ret = { 0, 0, -1, -1, -1, -1, false, false, DECORATION_INIT };
  MTKey mark = marktree_lookup_ns(buf->b_marktree, ns_id, id, false, NULL);
  if (!mark.id) {
    return ret;
  }
  assert(mark.pos.row >= 0);
  MTKey end = marktree_get_alt(buf->b_marktree, mark, NULL);

  ret.ns_id = ns_id;
  ret.mark_id = id;
  ret.row = mark.pos.row;
  ret.col = mark.pos.col;
  ret.end_row = end.pos.row;
  ret.end_col = end.pos.col;
  ret.right_gravity = mt_right(mark);
  ret.end_right_gravity = mt_right(end);
  ret.decor = get_decor(mark);

  return ret;
}

/// free extmarks from the buffer
void extmark_free_all(buf_T *buf)
{
  if (!map_size(buf->b_extmark_ns)) {
    return;
  }

  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, 0, 0, itr);
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0) {
      break;
    }

    // don't free mark.decor_full twice for a paired mark.
    if (!(mt_paired(mark) && mt_end(mark))) {
      decor_free(mark.decor_full);
    }

    marktree_itr_next(buf->b_marktree, itr);
  }

  marktree_clear(buf->b_marktree);

  map_destroy(uint32_t, buf->b_extmark_ns);
  *buf->b_extmark_ns = (Map(uint32_t, uint32_t)) MAP_INIT;
}

/// Save info for undo/redo of set marks
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
  marktree_itr_get(buf->b_marktree, (int32_t)l_row, l_col, itr);
  while (true) {
    MTKey mark = marktree_itr_current(itr);
    if (mark.pos.row < 0
        || mark.pos.row > u_row
        || (mark.pos.row == u_row && mark.pos.col > u_col)) {
      break;
    }
    ExtmarkSavePos pos;
    pos.mark = mt_lookup_key(mark);
    pos.old_row = mark.pos.row;
    pos.old_col = mark.pos.col;
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
}

/// Adjust extmark row for inserted/deleted rows (columns stay fixed).
void extmark_adjust(buf_T *buf, linenr_T line1, linenr_T line2, linenr_T amount,
                    linenr_T amount_after, ExtmarkOp undo)
{
  if (curbuf_splice_pending) {
    return;
  }
  bcount_t start_byte = ml_find_line_or_offset(buf, line1, NULL, true);
  bcount_t old_byte = 0, new_byte = 0;
  int old_row, new_row;
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

  marktree_splice(buf->b_marktree, (int32_t)start_row, start_col,
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
