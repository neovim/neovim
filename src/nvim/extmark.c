// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Implements extended marks for plugins. Each mark exists in a btree of
// lines containing btrees of columns.
//
// The btree provides efficient range lookups.
// A map of pointers to the marks is used for fast lookup by mark id.
//
// Marks are moved by calls to extmark_splice. Additionally mark_adjust
// might adjust extmarks to line inserts/deletes.
//
// Undo/Redo of marks is implemented by storing the call arguments to
// extmark_splice. The list of arguments is applied in extmark_apply_undo.
// The only case where we have to copy extmarks is for the area being effected
// by a delete.
//
// Marks live in namespaces that allow plugins/users to segregate marks
// from other users.
//
// For possible ideas for efficency improvements see:
// http://blog.atom.io/2015/06/16/optimizing-an-important-atom-primitive.html
// TODO(bfredl): These ideas could be used for an enhanced btree, which
// wouldn't need separate line and column layers.
// Other implementations exist in gtk and tk toolkits.
//
// Deleting marks only happens when explicitly calling extmark_del, deleteing
// over a range of marks will only move the marks. Deleting on a mark will
// leave it in same position unless it is on the EOL of a line.

#include <assert.h>
#include "nvim/api/vim.h"
#include "nvim/vim.h"
#include "nvim/charset.h"
#include "nvim/extmark.h"
#include "nvim/buffer_updates.h"
#include "nvim/memline.h"
#include "nvim/pos.h"
#include "nvim/globals.h"
#include "nvim/map.h"
#include "nvim/lib/kbtree.h"
#include "nvim/undo.h"
#include "nvim/buffer.h"
#include "nvim/syntax.h"
#include "nvim/highlight.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "extmark.c.generated.h"
#endif

static ExtmarkNs *buf_ns_ref(buf_T *buf, uint64_t ns_id, bool put) {
  if (!buf->b_extmark_ns) {
    if (!put) {
      return NULL;
    }
    buf->b_extmark_ns = map_new(uint64_t, ExtmarkNs)();
    buf->b_extmark_index = map_new(uint64_t, ExtmarkItem)();
  }

  ExtmarkNs *ns = map_ref(uint64_t, ExtmarkNs)(buf->b_extmark_ns, ns_id, put);
  if (put && ns->map == NULL) {
    ns->map = map_new(uint64_t, uint64_t)();
    ns->free_id = 1;
  }
  return ns;
}


/// Create or update an extmark
///
/// must not be used during iteration!
/// @returns the mark id
uint64_t extmark_set(buf_T *buf, uint64_t ns_id, uint64_t id,
                     int row, colnr_T col, ExtmarkOp op)
{
  ExtmarkNs *ns = buf_ns_ref(buf, ns_id, true);
  mtpos_t old_pos;
  uint64_t mark = 0;

  if (id == 0) {
    id = ns->free_id++;
  } else {
    uint64_t old_mark = map_get(uint64_t, uint64_t)(ns->map, id);
    if (old_mark) {
      if (old_mark & MARKTREE_PAIRED_FLAG) {
        extmark_del(buf, ns_id, id);
      } else {
        // TODO(bfredl): we need to do more if "revising" a decoration mark.
        MarkTreeIter itr[1] = { 0 };
        old_pos = marktree_lookup(buf->b_marktree, old_mark, itr);
        assert(itr->node);
        if (old_pos.row == row && old_pos.col == col) {
          map_del(uint64_t, ExtmarkItem)(buf->b_extmark_index, old_mark);
          mark = marktree_revise(buf->b_marktree, itr);
          goto revised;
        }
        marktree_del_itr(buf->b_marktree, itr, false);
      }
    } else {
      ns->free_id = MAX(ns->free_id, id+1);
    }
  }

  mark = marktree_put(buf->b_marktree, row, col, true);
revised:
  map_put(uint64_t, ExtmarkItem)(buf->b_extmark_index, mark,
                                 (ExtmarkItem){ ns_id, id, 0,
                                                KV_INITIAL_VALUE });
  map_put(uint64_t, uint64_t)(ns->map, id, mark);

  if (op != kExtmarkNoUndo) {
    // TODO(bfredl): this doesn't cover all the cases and probably shouldn't
    // be done "prematurely". Any movement in undo history might necessitate
    // adding new marks to old undo headers.
    u_extmark_set(buf, mark, row, col);
  }
  return id;
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

  if (mark & MARKTREE_PAIRED_FLAG) {
    mtpos_t pos2 = marktree_lookup(buf->b_marktree,
                                   mark|MARKTREE_END_FLAG, itr);
    assert(pos2.row >= 0);
    marktree_del_itr(buf->b_marktree, itr, false);
    if (item.hl_id && pos2.row >= pos.row) {
      redraw_buf_range_later(buf, pos.row+1, pos2.row+1);
    }
  }

  if (kv_size(item.virt_text)) {
    redraw_buf_line_later(buf, pos.row+1);
  }
  clear_virttext(&item.virt_text);

  map_del(uint64_t, uint64_t)(ns->map, id);
  map_del(uint64_t, ExtmarkItem)(buf->b_extmark_index, mark);

  // TODO(bfredl): delete it from current undo header, opportunistically?

  return true;
}

// Free extmarks in a ns between lines
// if ns = 0, it means clear all namespaces
bool extmark_clear(buf_T *buf, uint64_t ns_id,
                   int l_row, colnr_T l_col,
                   int u_row, colnr_T u_col)
{
  if (!buf->b_extmark_ns) {
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
  static Map(uint64_t, uint64_t) *delete_set = NULL;
  if (delete_set == NULL) {
    delete_set = map_new(uint64_t, uint64_t)();
  }

  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get(buf->b_marktree, l_row, l_col, itr);
  while (true) {
    mtmark_t mark = marktree_itr_current(itr);
    if (mark.row < 0
        || mark.row > u_row
        || (mark.row == u_row && mark.col > u_col)) {
      break;
    }
    uint64_t *del_status = map_ref(uint64_t, uint64_t)(delete_set, mark.id,
                                                       false);
    if (del_status) {
      marktree_del_itr(buf->b_marktree, itr, false);
      map_del(uint64_t, uint64_t)(delete_set, mark.id);
      if (*del_status > 0) {
        redraw_buf_range_later(buf, (linenr_T)(*del_status), mark.row+1);
      }
      continue;
    }

    uint64_t start_id = mark.id & ~MARKTREE_END_FLAG;
    ExtmarkItem item = map_get(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                      start_id);

    assert(item.ns_id > 0 && item.mark_id > 0);
    if (item.mark_id > 0 && (item.ns_id == ns_id || all_ns)) {
      if (kv_size(item.virt_text)) {
        redraw_buf_line_later(buf, mark.row+1);
      }
      clear_virttext(&item.virt_text);
      marks_cleared = true;
      if (mark.id & MARKTREE_PAIRED_FLAG) {
        uint64_t other = mark.id ^ MARKTREE_END_FLAG;
        uint64_t status = item.hl_id ? ((uint64_t)mark.row+1) : 0;
        map_put(uint64_t, uint64_t)(delete_set, other, status);
      }
      ExtmarkNs *my_ns = all_ns ? buf_ns_ref(buf, item.ns_id, false) : ns;
      map_del(uint64_t, uint64_t)(my_ns->map, item.mark_id);
      map_del(uint64_t, ExtmarkItem)(buf->b_extmark_index, mark.id);
      marktree_del_itr(buf->b_marktree, itr, false);
    } else {
      marktree_itr_next(buf->b_marktree, itr);
    }
  }
  uint64_t id, status;
  map_foreach(delete_set, id, status, {
    mtpos_t pos = marktree_lookup(buf->b_marktree, id, itr);
    assert(itr->node);
    marktree_del_itr(buf->b_marktree, itr, false);
    if (status > 0) {
      redraw_buf_range_later(buf, (linenr_T)status, pos.row+1);
    }
  });
  map_clear(uint64_t, uint64_t)(delete_set);
  return marks_cleared;
}

// Returns the position of marks between a range,
// marks found at the start or end index will be included,
// if upper_lnum or upper_col are negative the buffer
// will be searched to the start, or end
// dir can be set to control the order of the array
// amount = amount of marks to find or -1 for all
ExtmarkArray extmark_get(buf_T *buf, uint64_t ns_id,
                         int l_row, colnr_T l_col,
                         int u_row, colnr_T u_col,
                         int64_t amount, bool reverse)
{
  ExtmarkArray array = KV_INITIAL_VALUE;
  MarkTreeIter itr[1] = { 0 };
  // Find all the marks
  marktree_itr_get_ext(buf->b_marktree, (mtpos_t){ l_row, l_col },
                       itr, reverse, false, NULL);
  int order = reverse ? -1 : 1;
  while ((int64_t)kv_size(array) < amount) {
    mtmark_t mark = marktree_itr_current(itr);
    if (mark.row < 0
        || (mark.row - u_row) * order > 0
        || (mark.row == u_row && (mark.col - u_col) * order > 0)) {
      break;
    }
    ExtmarkItem item = map_get(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                      mark.id);
    if (item.ns_id == ns_id) {
      kv_push(array, ((ExtmarkInfo) { .ns_id = item.ns_id,
                                      .mark_id = item.mark_id,
                                      .row = mark.row, .col = mark.col }));
    }
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
  ExtmarkInfo ret = { 0, 0, -1, -1 };
  if (!ns) {
    return ret;
  }

  uint64_t mark = map_get(uint64_t, uint64_t)(ns->map, id);
  if (!mark) {
    return ret;
  }

  mtpos_t pos = marktree_lookup(buf->b_marktree, mark, NULL);
  assert(pos.row >= 0);

  ret.ns_id = ns_id;
  ret.mark_id = id;
  ret.row = pos.row;
  ret.col = pos.col;

  return ret;
}


// free extmarks from the buffer
void extmark_free_all(buf_T *buf)
{
  if (!buf->b_extmark_ns) {
    return;
  }

  uint64_t id;
  ExtmarkNs ns;
  ExtmarkItem item;

  marktree_clear(buf->b_marktree);

  map_foreach(buf->b_extmark_ns, id, ns, {
    (void)id;
    map_free(uint64_t, uint64_t)(ns.map);
  });
  map_free(uint64_t, ExtmarkNs)(buf->b_extmark_ns);
  buf->b_extmark_ns = NULL;

  map_foreach(buf->b_extmark_index, id, item, {
    (void)id;
    clear_virttext(&item.virt_text);
  });
  map_free(uint64_t, ExtmarkItem)(buf->b_extmark_index);
  buf->b_extmark_index = NULL;
}


// Save info for undo/redo of set marks
static void u_extmark_set(buf_T *buf, uint64_t mark,
                          int row, colnr_T col)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
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
void u_extmark_copy(buf_T *buf,
                    int l_row, colnr_T l_col,
                    int u_row, colnr_T u_col)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
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
      extmark_splice(curbuf,
                     splice.start_row, splice.start_col,
                     splice.newextent_row, splice.newextent_col,
                     splice.oldextent_row, splice.oldextent_col,
                     kExtmarkNoUndo);

    } else {
      extmark_splice(curbuf,
                     splice.start_row, splice.start_col,
                     splice.oldextent_row, splice.oldextent_col,
                     splice.newextent_row, splice.newextent_col,
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
                          move.new_row, move.new_col,
                          move.extent_row, move.extent_col,
                          move.start_row, move.start_col,
                          kExtmarkNoUndo);
    } else {
      extmark_move_region(curbuf,
                          move.start_row, move.start_col,
                          move.extent_row, move.extent_col,
                          move.new_row, move.new_col,
                          kExtmarkNoUndo);
    }
  }
}


// Adjust extmark row for inserted/deleted rows (columns stay fixed).
void extmark_adjust(buf_T *buf,
                    linenr_T line1,
                    linenr_T line2,
                    long amount,
                    long amount_after,
                    ExtmarkOp undo)
{
  if (!curbuf_splice_pending) {
    int old_extent, new_extent;
    if (amount == MAXLNUM) {
      old_extent = (int)(line2 - line1+1);
      new_extent = (int)(amount_after + old_extent);
    } else {
      // A region is either deleted (amount == MAXLNUM) or
      // added (line2 == MAXLNUM). The only other case is :move
      // which is handled by a separate entry point extmark_move_region.
      assert(line2 == MAXLNUM);
      old_extent = 0;
      new_extent = (int)amount;
    }
    extmark_splice(buf,
                   (int)line1-1, 0,
                   old_extent, 0,
                   new_extent, 0, undo);
  }
}

void extmark_splice(buf_T *buf,
                    int start_row, colnr_T start_col,
                    int oldextent_row, colnr_T oldextent_col,
                    int newextent_row, colnr_T newextent_col,
                    ExtmarkOp undo)
{
  buf_updates_send_splice(buf, start_row, start_col,
                          oldextent_row, oldextent_col,
                          newextent_row, newextent_col);

  if (undo == kExtmarkUndo && (oldextent_row > 0 || oldextent_col > 0)) {
    // Copy marks that would be effected by delete
    // TODO(bfredl): Be "smart" about gravity here, left-gravity at the
    // beginning and right-gravity at the end need not be preserved.
    // Also be smart about marks that already have been saved (important for
    // merge!)
    int end_row = start_row + oldextent_row;
    int end_col = (oldextent_row ? 0 : start_col) + oldextent_col;
    u_extmark_copy(buf, start_row, start_col, end_row, end_col);
  }


  marktree_splice(buf->b_marktree, start_row, start_col,
                  oldextent_row, oldextent_col,
                  newextent_row, newextent_col);

  if (undo == kExtmarkUndo) {
    u_header_T  *uhp = u_force_get_undo_header(buf);
    if (!uhp) {
      return;
    }

    bool merged = false;
    // TODO(bfredl): this is quite rudimentary. We merge small (within line)
    // inserts with each other and small deletes with each other. Add full
    // merge algorithm later.
    if (oldextent_row == 0 && newextent_row == 0 && kv_size(uhp->uh_extmark))  {
      ExtmarkUndoObject *item = &kv_A(uhp->uh_extmark,
                                      kv_size(uhp->uh_extmark)-1);
      if (item->type == kExtmarkSplice) {
        ExtmarkSplice *splice = &item->data.splice;
        if (splice->start_row == start_row && splice->oldextent_row == 0
            && splice->newextent_row == 0) {
          if (oldextent_col == 0 && start_col >= splice->start_col
              && start_col <= splice->start_col+splice->newextent_col) {
            splice->newextent_col += newextent_col;
            merged = true;
          } else if (newextent_col == 0
                     && start_col == splice->start_col+splice->newextent_col) {
            splice->oldextent_col += oldextent_col;
            merged = true;
          } else if (newextent_col == 0
                     && start_col + oldextent_col == splice->start_col) {
            splice->start_col = start_col;
            splice->oldextent_col += oldextent_col;
            merged = true;
          }
        }
      }
    }

    if (!merged) {
      ExtmarkSplice splice;
      splice.start_row = start_row;
      splice.start_col = start_col;
      splice.oldextent_row = oldextent_row;
      splice.oldextent_col = oldextent_col;
      splice.newextent_row = newextent_row;
      splice.newextent_col = newextent_col;

      kv_push(uhp->uh_extmark,
              ((ExtmarkUndoObject){ .type = kExtmarkSplice,
                                    .data.splice = splice }));
    }
  }
}


void extmark_move_region(buf_T *buf,
                         int start_row, colnr_T start_col,
                         int extent_row, colnr_T extent_col,
                         int new_row, colnr_T new_col,
                         ExtmarkOp undo)
{
  // TODO(bfredl): this is not synced to the buffer state inside the callback.
  // But unless we make the undo implementation smarter, this is not ensured
  // anyway.
  buf_updates_send_splice(buf, start_row, start_col,
                          extent_row, extent_col,
                          0, 0);

  marktree_move_region(buf->b_marktree, start_row, start_col,
                       extent_row, extent_col,
                       new_row, new_col);

  buf_updates_send_splice(buf, new_row, new_col,
                          0, 0,
                          extent_row, extent_col);


  if (undo == kExtmarkUndo) {
    u_header_T  *uhp = u_force_get_undo_header(buf);
    if (!uhp) {
      return;
    }

    ExtmarkMove move;
    move.start_row = start_row;
    move.start_col = start_col;
    move.extent_row = extent_row;
    move.extent_col = extent_col;
    move.new_row = new_row;
    move.new_col = new_col;

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

/// Adds a decoration to a buffer.
///
/// Unlike matchaddpos() highlights, these follow changes to the the buffer
/// texts. Decorations are represented internally and in the API as extmarks.
///
/// @param buf The buffer to add decorations to
/// @param ns_id A valid namespace id.
/// @param hl_id Id of the highlight group to use (or zero)
/// @param start_row The line to highlight
/// @param start_col First column to highlight
/// @param end_row The line to highlight
/// @param end_col The last column to highlight
/// @param virt_text Virtual text (currently placed at the EOL of start_row)
/// @return The extmark id inside the namespace
uint64_t extmark_add_decoration(buf_T *buf, uint64_t ns_id, int hl_id,
                                int start_row, colnr_T start_col,
                                int end_row, colnr_T end_col,
                                VirtText virt_text)
{
  ExtmarkNs *ns = buf_ns_ref(buf, ns_id, true);
  ExtmarkItem item;
  item.ns_id = ns_id;
  item.mark_id = ns->free_id++;
  item.hl_id = hl_id;
  item.virt_text = virt_text;

  uint64_t mark;

  if (end_row > -1) {
    mark = marktree_put_pair(buf->b_marktree,
                             start_row, start_col, true,
                             end_row, end_col, false);
  } else {
    mark = marktree_put(buf->b_marktree, start_row, start_col, true);
  }

  map_put(uint64_t, ExtmarkItem)(buf->b_extmark_index, mark, item);
  map_put(uint64_t, uint64_t)(ns->map, item.mark_id, mark);

  redraw_buf_range_later(buf, start_row+1,
                         (end_row >= 0 ? end_row : start_row) + 1);
  return item.mark_id;
}

/// Add highlighting to a buffer, bounded by two cursor positions,
/// with an offset.
///
/// @param buf Buffer to add highlights to
/// @param src_id src_id to use or 0 to use a new src_id group,
///               or -1 for ungrouped highlight.
/// @param hl_id Highlight group id
/// @param pos_start Cursor position to start the hightlighting at
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
    (void)extmark_add_decoration(buf, (uint64_t)src_id, hl_id,
                                 (int)lnum-1, hl_start,
                                 (int)lnum-1+end_off, hl_end,
                                 VIRTTEXT_EMPTY);
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

VirtText *extmark_find_virttext(buf_T *buf, int row, uint64_t ns_id)
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
        && kv_size(item->virt_text)) {
      return &item->virt_text;
    }
    marktree_itr_next(buf->b_marktree, itr);
  }
  return NULL;
}

bool decorations_redraw_reset(buf_T *buf, DecorationRedrawState *state)
{
  state->row = -1;
  kv_size(state->active) = 0;
  return buf->b_extmark_index || buf->b_luahl;
}


bool decorations_redraw_start(buf_T *buf, int top_row,
                              DecorationRedrawState *state)
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
    // TODO(bfredl): dedicated flag for being a decoration?
    if ((mark.row < top_row && mark.id&MARKTREE_END_FLAG)) {
      goto next_mark;
    }
    mtpos_t altpos = marktree_lookup(buf->b_marktree,
                                     mark.id^MARKTREE_END_FLAG, NULL);

    uint64_t start_id = mark.id & ~MARKTREE_END_FLAG;
    ExtmarkItem *item = map_ref(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                       start_id, false);
    if ((!(mark.id&MARKTREE_END_FLAG) && altpos.row < top_row
         && !kv_size(item->virt_text))
        || ((mark.id&MARKTREE_END_FLAG) && altpos.row >= top_row)) {
      goto next_mark;
    }

    if (item && (item->hl_id > 0 || kv_size(item->virt_text))) {
      int attr_id = item->hl_id > 0 ? syn_id2attr(item->hl_id) : 0;
      VirtText *vt = kv_size(item->virt_text) ? &item->virt_text : NULL;
      HlRange range;
      if (mark.id&MARKTREE_END_FLAG) {
        range = (HlRange){ altpos.row, altpos.col, mark.row, mark.col,
                           attr_id, vt };
      } else {
        range = (HlRange){ mark.row, mark.col, altpos.row,
                           altpos.col, attr_id, vt };
      }
      kv_push(state->active, range);
    }
next_mark:
    if (marktree_itr_node_done(state->itr)) {
      break;
    }
    marktree_itr_next(buf->b_marktree, state->itr);
  }

  return true;  // TODO(bfredl): check if available in the region
}

bool decorations_redraw_line(buf_T *buf, int row, DecorationRedrawState *state)
{
  if (state->row == -1) {
    decorations_redraw_start(buf, row, state);
  }
  state->row = row;
  state->col_until = -1;
  return true;  // TODO(bfredl): be more precise
}

int decorations_redraw_col(buf_T *buf, int col, DecorationRedrawState *state)
{
  if (col <= state->col_until) {
    return state->current;
  }
  state->col_until = MAXCOL;
  while (true) {
    mtmark_t mark = marktree_itr_current(state->itr);
    if (mark.row < 0 || mark.row > state->row) {
      break;
    } else if (mark.row == state->row && mark.col > col) {
      state->col_until = mark.col-1;
      break;
    }

    if ((mark.id&MARKTREE_END_FLAG)) {
       // TODO(bfredl): check decorations flag
      goto next_mark;
    }
    mtpos_t endpos = marktree_lookup(buf->b_marktree,
                                     mark.id|MARKTREE_END_FLAG, NULL);

    ExtmarkItem *item = map_ref(uint64_t, ExtmarkItem)(buf->b_extmark_index,
                                                       mark.id, false);

    if (endpos.row < mark.row
        || (endpos.row == mark.row && endpos.col <= mark.col)) {
      if (!kv_size(item->virt_text)) {
        goto next_mark;
      }
    }

    if (item && (item->hl_id > 0 || kv_size(item->virt_text))) {
      int attr_id = item->hl_id > 0 ? syn_id2attr(item->hl_id) : 0;
      VirtText *vt = kv_size(item->virt_text) ? &item->virt_text : NULL;
      kv_push(state->active, ((HlRange){ mark.row, mark.col,
                                         endpos.row, endpos.col,
                                         attr_id, vt }));
    }

next_mark:
    marktree_itr_next(buf->b_marktree, state->itr);
  }

  int attr = 0;
  size_t j = 0;
  for (size_t i = 0; i < kv_size(state->active); i++) {
    HlRange item = kv_A(state->active, i);
    bool active = false, keep = true;
    if (item.end_row < state->row
        || (item.end_row == state->row && item.end_col <= col)) {
      if (!(item.start_row >= state->row && item.virt_text)) {
        keep = false;
      }
    } else {
      if (item.start_row < state->row
          || (item.start_row == state->row && item.start_col <= col)) {
        active = true;
        if (item.end_row == state->row) {
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
    if (keep) {
      kv_A(state->active, j++) = kv_A(state->active, i);
    }
  }
  kv_size(state->active) = j;
  state->current = attr;
  return attr;
}

VirtText *decorations_redraw_virt_text(buf_T *buf, DecorationRedrawState *state)
{
  decorations_redraw_col(buf, MAXCOL, state);
  for (size_t i = 0; i < kv_size(state->active); i++) {
    HlRange item = kv_A(state->active, i);
    if (item.start_row == state->row && item.virt_text) {
      return item.virt_text;
    }
  }
  return NULL;
}
