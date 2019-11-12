// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Implements extended marks for plugins. Each mark exists in a btree of
// lines containing btrees of columns.
//
// The btree provides efficent range lookups.
// A map of pointers to the marks is used for fast lookup by mark id.
//
// Marks are moved by calls to: extmark_col_adjust, extmark_adjust, or
// extmark_col_adjust_delete which are based on col_adjust and mark_adjust from
// mark.c
//
// Undo/Redo of marks is implemented by storing the call arguments to
// extmark_col_adjust or extmark_adjust. The list of arguments
// is applied in extmark_apply_undo. The only case where we have to
// copy extmarks is for the area being effected by a delete.
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
#include "nvim/vim.h"
#include "charset.h"
#include "nvim/mark_extended.h"
#include "nvim/memline.h"
#include "nvim/pos.h"
#include "nvim/globals.h"
#include "nvim/map.h"
#include "nvim/lib/kbtree.h"
#include "nvim/undo.h"
#include "nvim/buffer.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark_extended.c.generated.h"
#endif


/// Create or update an extmark
///
/// must not be used during iteration!
/// @returns whether a new mark was created
int extmark_set(buf_T *buf, uint64_t ns, uint64_t id,
                linenr_T lnum, colnr_T col, ExtmarkOp op)
{
  Extmark *extmark = extmark_from_id(buf, ns, id);
  if (!extmark) {
    extmark_create(buf, ns, id, lnum, col, op);
    return true;
  } else {
    ExtmarkLine *extmarkline = extmark->line;
    extmark_update(extmark, buf, ns, id, lnum,  col, op, NULL);
    if (kb_size(&extmarkline->items) == 0) {
      kb_del(extmarklines, &buf->b_extlines, extmarkline);
      extmarkline_free(extmarkline);
    }
    return false;
  }
}

// Remove an extmark
// Returns 0 on missing id
int extmark_del(buf_T *buf, uint64_t ns, uint64_t id, ExtmarkOp op)
{
  Extmark *extmark = extmark_from_id(buf, ns, id);
  if (!extmark) {
    return 0;
  }
  return extmark_delete(extmark, buf, ns, id, op);
}

// Free extmarks in a ns between lines
// if ns = 0, it means clear all namespaces
void extmark_clear(buf_T *buf, uint64_t ns,
                   linenr_T l_lnum, linenr_T u_lnum, ExtmarkOp undo)
{
  if (!buf->b_extmark_ns) {
    return;
  }

  bool marks_cleared = false;
  if (undo == kExtmarkUndo) {
    // Copy marks that would be effected by clear
    u_extmark_copy(buf, ns, l_lnum, 0, u_lnum, MAXCOL);
  }

  bool all_ns = ns == 0 ? true : false;
  ExtmarkNs *ns_obj;
  if (!all_ns) {
    ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
    if (!ns_obj) {
      // nothing to do
      return;
    }
  }

  FOR_ALL_EXTMARKLINES(buf, l_lnum, u_lnum, {
    FOR_ALL_EXTMARKS_IN_LINE(extmarkline->items, 0, MAXCOL, {
            if (extmark->ns_id == ns || all_ns) {
              marks_cleared = true;
              if (all_ns) {
                ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, extmark->ns_id);
              } else {
                ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
              }
              pmap_del(uint64_t)(ns_obj->map, extmark->mark_id);
              kb_del_itr(markitems, &extmarkline->items, &mitr);
            }
    });
    if (kb_size(&extmarkline->items) == 0) {
      kb_del_itr(extmarklines, &buf->b_extlines, &itr);
      extmarkline_free(extmarkline);
    }
  });

  // Record the undo for the actual move
  if (marks_cleared && undo == kExtmarkUndo) {
    u_extmark_clear(buf, ns, l_lnum, u_lnum);
  }
}

// Returns the position of marks between a range,
// marks found at the start or end index will be included,
// if upper_lnum or upper_col are negative the buffer
// will be searched to the start, or end
// dir can be set to control the order of the array
// amount = amount of marks to find or -1 for all
ExtmarkArray extmark_get(buf_T *buf, uint64_t ns,
                         linenr_T l_lnum, colnr_T l_col,
                         linenr_T u_lnum, colnr_T u_col,
                         int64_t amount, bool reverse)
{
  ExtmarkArray array = KV_INITIAL_VALUE;
  // Find all the marks
  if (!reverse) {
    FOR_ALL_EXTMARKS(buf, ns, l_lnum, l_col, u_lnum, u_col, {
      if (extmark->ns_id == ns) {
        kv_push(array, extmark);
        if (kv_size(array) == (size_t)amount) {
          return array;
        }
      }
    })
  } else {
    FOR_ALL_EXTMARKS_PREV(buf, ns, l_lnum, l_col, u_lnum, u_col, {
      if (extmark->ns_id == ns) {
        kv_push(array, extmark);
        if (kv_size(array) == (size_t)amount) {
          return array;
        }
      }
    })
  }
  return array;
}

static void extmark_create(buf_T *buf, uint64_t ns, uint64_t id,
                           linenr_T lnum, colnr_T col, ExtmarkOp op)
{
  if (!buf->b_extmark_ns) {
    buf->b_extmark_ns = pmap_new(uint64_t)();
  }
  ExtmarkNs *ns_obj = NULL;
  ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
  // Initialize a new namespace for this buffer
  if (!ns_obj) {
    ns_obj = xmalloc(sizeof(ExtmarkNs));
    ns_obj->map = pmap_new(uint64_t)();
    pmap_put(uint64_t)(buf->b_extmark_ns, ns, ns_obj);
  }

  // Create or get a line
  ExtmarkLine *extmarkline = extmarkline_ref(buf, lnum, true);
  // Create and put mark on the line
  extmark_put(col, id, extmarkline, ns);

  // Marks do not have stable address so we have to look them up
  // by using the line instead of the mark
  pmap_put(uint64_t)(ns_obj->map, id, extmarkline);
  if (op != kExtmarkNoUndo) {
    u_extmark_set(buf, ns, id, lnum, col, kExtmarkSet);
  }

  // Set a free id so extmark_free_id_get works
  extmark_free_id_set(ns_obj, id);
}

// update the position of an extmark
// to update while iterating pass the markitems itr
static void extmark_update(Extmark *extmark, buf_T *buf,
                           uint64_t ns, uint64_t id,
                           linenr_T lnum, colnr_T col,
                           ExtmarkOp op, kbitr_t(markitems) *mitr)
{
  assert(op != kExtmarkNOOP);
  if (op != kExtmarkNoUndo) {
    u_extmark_update(buf, ns, id, extmark->line->lnum, extmark->col,
                     lnum, col);
  }
  ExtmarkLine *old_line = extmark->line;
  // Move the mark to a new line and update column
  if (old_line->lnum != lnum) {
    ExtmarkLine *ref_line = extmarkline_ref(buf, lnum, true);
    extmark_put(col, id, ref_line, ns);
    // Update the hashmap
    ExtmarkNs *ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
    pmap_put(uint64_t)(ns_obj->map, id, ref_line);
    // Delete old mark
    if (mitr != NULL) {
      kb_del_itr(markitems, &(old_line->items), mitr);
    } else {
      kb_del(markitems, &old_line->items, *extmark);
    }
  // Just update the column
  } else {
    if (mitr != NULL) {
      // The btree stays organized during iteration with kbitr_t
      extmark->col = col;
    } else {
      // Keep the btree in order
      kb_del(markitems, &old_line->items, *extmark);
      extmark_put(col, id, old_line, ns);
    }
  }
}

static int extmark_delete(Extmark *extmark,
                          buf_T *buf,
                          uint64_t ns,
                          uint64_t id,
                          ExtmarkOp op)
{
  if (op != kExtmarkNoUndo) {
    u_extmark_set(buf, ns, id, extmark->line->lnum, extmark->col,
                  kExtmarkDel);
  }

  // Remove our key from the namespace
  ExtmarkNs *ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
  pmap_del(uint64_t)(ns_obj->map, id);

  // Remove the mark mark from the line
  ExtmarkLine *extmarkline = extmark->line;
  kb_del(markitems, &extmarkline->items, *extmark);
  // Remove the line if there are no more marks in the line
  if (kb_size(&extmarkline->items) == 0) {
    kb_del(extmarklines, &buf->b_extlines, extmarkline);
    extmarkline_free(extmarkline);
  }
  return true;
}

// Lookup an extmark by id
Extmark *extmark_from_id(buf_T *buf, uint64_t ns, uint64_t id)
{
  if (!buf->b_extmark_ns) {
    return NULL;
  }
  ExtmarkNs *ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
  if (!ns_obj || !kh_size(ns_obj->map->table)) {
    return NULL;
  }
  ExtmarkLine *extmarkline = pmap_get(uint64_t)(ns_obj->map, id);
  if (!extmarkline) {
    return NULL;
  }

  FOR_ALL_EXTMARKS_IN_LINE(extmarkline->items, 0, MAXCOL, {
    if (extmark->ns_id == ns
        && extmark->mark_id == id) {
      return extmark;
    }
  })
  return NULL;
}

// Lookup an extmark by position
Extmark *extmark_from_pos(buf_T *buf, uint64_t ns, linenr_T lnum, colnr_T col)
{
  if (!buf->b_extmark_ns) {
    return NULL;
  }
  FOR_ALL_EXTMARKS(buf, ns, lnum, col, lnum, col, {
    if (extmark->ns_id == ns) {
      if (extmark->col == col) {
        return extmark;
      }
    }
  })
  return NULL;
}

// Returns an avaliable id in a namespace
uint64_t extmark_free_id_get(buf_T *buf, uint64_t ns)
{
  if (!buf->b_extmark_ns) {
    return 1;
  }
  ExtmarkNs *ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
  if (!ns_obj) {
    return 1;
  }
  return ns_obj->free_id;
}

// Set the next free id in a namesapce
static void extmark_free_id_set(ExtmarkNs *ns_obj, uint64_t id)
{
  // Simply Heurstic, the largest id + 1
  ns_obj->free_id = id + 1;
}

// free extmarks from the buffer
void extmark_free_all(buf_T *buf)
{
  if (!buf->b_extmark_ns) {
    return;
  }

  uint64_t ns;
  ExtmarkNs *ns_obj;

  FOR_ALL_EXTMARKLINES(buf, 1, MAXLNUM, {
    kb_del_itr(extmarklines, &buf->b_extlines, &itr);
    extmarkline_free(extmarkline);
  })

  map_foreach(buf->b_extmark_ns, ns, ns_obj, {
    (void)ns;
    pmap_free(uint64_t)(ns_obj->map);
    xfree(ns_obj);
  });

  pmap_free(uint64_t)(buf->b_extmark_ns);
  buf->b_extmark_ns = NULL;

  // k?_init called to set pointers to NULL
  kb_destroy(extmarklines, (&buf->b_extlines));
  kb_init(&buf->b_extlines);

  kv_destroy(buf->b_extmark_move_space);
  kv_init(buf->b_extmark_move_space);
}


// Save info for undo/redo of set marks
static void u_extmark_set(buf_T *buf, uint64_t ns, uint64_t id,
                          linenr_T lnum, colnr_T col, UndoObjectType undo_type)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  ExtmarkSet set;
  set.ns_id = ns;
  set.mark_id = id;
  set.lnum = lnum;
  set.col = col;

  ExtmarkUndoObject undo = { .type = undo_type,
                             .data.set = set };

  kv_push(uhp->uh_extmark, undo);
}

// Save info for undo/redo of deleted marks
static void u_extmark_update(buf_T *buf, uint64_t ns, uint64_t id,
                             linenr_T old_lnum, colnr_T old_col,
                             linenr_T lnum, colnr_T col)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  ExtmarkUpdate update;
  update.ns_id = ns;
  update.mark_id = id;
  update.old_lnum = old_lnum;
  update.old_col = old_col;
  update.lnum = lnum;
  update.col = col;

  ExtmarkUndoObject undo = { .type = kExtmarkUpdate,
                             .data.update = update };
  kv_push(uhp->uh_extmark, undo);
}

// Hueristic works only for when the user is typing in insert mode
// - Instead of 1 undo object for each char inserted,
//   we create 1 undo objet for all text inserted before the user hits esc
// Return True if we compacted else False
static bool u_compact_col_adjust(buf_T *buf, linenr_T lnum, colnr_T mincol,
                                 long lnum_amount, long col_amount)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return false;
  }

  if (kv_size(uhp->uh_extmark) < 1) {
    return false;
  }
  // Check the last action
  ExtmarkUndoObject object = kv_last(uhp->uh_extmark);

  if (object.type != kColAdjust) {
    return false;
  }
  ColAdjust undo = object.data.col_adjust;
  bool compactable = false;

  if (!undo.lnum_amount && !lnum_amount) {
    if (undo.lnum == lnum) {
      if ((undo.mincol + undo.col_amount) >= mincol) {
          compactable = true;
  } } }

  if (!compactable) {
    return false;
  }

  undo.col_amount = undo.col_amount + col_amount;
  ExtmarkUndoObject new_undo = { .type = kColAdjust,
                                 .data.col_adjust = undo };
  kv_last(uhp->uh_extmark) = new_undo;
  return true;
}

// Save col_adjust info so we can undo/redo
void u_extmark_col_adjust(buf_T *buf, linenr_T lnum, colnr_T mincol,
                          long lnum_amount, long col_amount)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  if (!u_compact_col_adjust(buf, lnum, mincol, lnum_amount, col_amount)) {
    ColAdjust col_adjust;
    col_adjust.lnum = lnum;
    col_adjust.mincol = mincol;
    col_adjust.lnum_amount = lnum_amount;
    col_adjust.col_amount = col_amount;

    ExtmarkUndoObject undo = { .type = kColAdjust,
                               .data.col_adjust = col_adjust };

    kv_push(uhp->uh_extmark, undo);
  }
}

// Save col_adjust_delete info so we can undo/redo
void u_extmark_col_adjust_delete(buf_T *buf, linenr_T lnum,
                                 colnr_T mincol, colnr_T endcol, int eol)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  ColAdjustDelete col_adjust_delete;
  col_adjust_delete.lnum = lnum;
  col_adjust_delete.mincol = mincol;
  col_adjust_delete.endcol = endcol;
  col_adjust_delete.eol = eol;

  ExtmarkUndoObject undo = { .type = kColAdjustDelete,
                             .data.col_adjust_delete = col_adjust_delete };

  kv_push(uhp->uh_extmark, undo);
}

// Save adjust info so we can undo/redo
static void u_extmark_adjust(buf_T * buf, linenr_T line1, linenr_T line2,
                             long amount, long amount_after)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  Adjust adjust;
  adjust.line1 = line1;
  adjust.line2 = line2;
  adjust.amount = amount;
  adjust.amount_after = amount_after;

  ExtmarkUndoObject undo = { .type = kLineAdjust,
                             .data.adjust = adjust };

  kv_push(uhp->uh_extmark, undo);
}

// save info to undo/redo a :move
void u_extmark_move(buf_T *buf, linenr_T line1, linenr_T line2,
                    linenr_T last_line, linenr_T dest, linenr_T num_lines,
                    linenr_T extra)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  AdjustMove move;
  move.line1 = line1;
  move.line2 = line2;
  move.last_line = last_line;
  move.dest = dest;
  move.num_lines = num_lines;
  move.extra = extra;

  ExtmarkUndoObject undo = { .type = kAdjustMove,
                             .data.move = move };

  kv_push(uhp->uh_extmark, undo);
}

// copy extmarks data between range, useful when we cannot simply reverse
// the operation. This will do nothing on redo, enforces correct position when
// undo.
// if ns = 0, it means copy all namespaces
void u_extmark_copy(buf_T *buf, uint64_t ns,
                    linenr_T l_lnum, colnr_T l_col,
                    linenr_T u_lnum, colnr_T u_col)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  bool all_ns = ns == 0 ? true : false;

  ExtmarkCopy copy;
  ExtmarkUndoObject undo;
  FOR_ALL_EXTMARKS(buf, 1, l_lnum, l_col, u_lnum, u_col, {
    if (all_ns || extmark->ns_id == ns) {
      copy.ns_id = extmark->ns_id;
      copy.mark_id = extmark->mark_id;
      copy.lnum = extmark->line->lnum;
      copy.col = extmark->col;

      undo.data.copy = copy;
      undo.type = kExtmarkCopy;
      kv_push(uhp->uh_extmark, undo);
    }
  });
}

void u_extmark_copy_place(buf_T *buf,
                          linenr_T l_lnum, colnr_T l_col,
                          linenr_T u_lnum, colnr_T u_col,
                          linenr_T p_lnum, colnr_T p_col)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  ExtmarkCopyPlace copy_place;
  copy_place.l_lnum = l_lnum;
  copy_place.l_col = l_col;
  copy_place.u_lnum = u_lnum;
  copy_place.u_col = u_col;
  copy_place.p_lnum = p_lnum;
  copy_place.p_col = p_col;

  ExtmarkUndoObject undo = { .type = kExtmarkCopyPlace,
                             .data.copy_place = copy_place };

  kv_push(uhp->uh_extmark, undo);
}

// Save info for undo/redo of extmark_clear
static void u_extmark_clear(buf_T *buf, uint64_t ns,
                            linenr_T l_lnum, linenr_T u_lnum)
{
  u_header_T  *uhp = u_force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  ExtmarkClear clear;
  clear.ns_id = ns;
  clear.l_lnum = l_lnum;
  clear.u_lnum = u_lnum;

  ExtmarkUndoObject undo = { .type = kExtmarkClear,
                             .data.clear = clear };
  kv_push(uhp->uh_extmark, undo);
}

// undo or redo an extmark operation
void extmark_apply_undo(ExtmarkUndoObject undo_info, bool undo)
{
  linenr_T lnum;
  colnr_T mincol;
  long lnum_amount;
  long col_amount;
  linenr_T line1;
  linenr_T line2;
  long amount;
  long amount_after;

  // use extmark_col_adjust
  if (undo_info.type == kColAdjust) {
    // Undo
    if (undo) {
      lnum = (undo_info.data.col_adjust.lnum
              + undo_info.data.col_adjust.lnum_amount);
      lnum_amount = -undo_info.data.col_adjust.lnum_amount;
      col_amount = -undo_info.data.col_adjust.col_amount;
      mincol = (undo_info.data.col_adjust.mincol
                + (colnr_T)undo_info.data.col_adjust.col_amount);
    // Redo
    } else {
      lnum = undo_info.data.col_adjust.lnum;
      col_amount = undo_info.data.col_adjust.col_amount;
      lnum_amount = undo_info.data.col_adjust.lnum_amount;
      mincol = undo_info.data.col_adjust.mincol;
    }
    extmark_col_adjust(curbuf,
                       lnum, mincol, lnum_amount, col_amount, kExtmarkNoUndo);
  // use extmark_col_adjust_delete
  } else if (undo_info.type == kColAdjustDelete) {
    if (undo) {
      mincol = undo_info.data.col_adjust_delete.mincol;
      col_amount = (undo_info.data.col_adjust_delete.endcol
                    - undo_info.data.col_adjust_delete.mincol) + 1;
      extmark_col_adjust(curbuf,
                         undo_info.data.col_adjust_delete.lnum,
                         mincol,
                         0,
                         col_amount,
                         kExtmarkNoUndo);
    // Redo
    } else {
      extmark_col_adjust_delete(curbuf,
                                undo_info.data.col_adjust_delete.lnum,
                                undo_info.data.col_adjust_delete.mincol,
                                undo_info.data.col_adjust_delete.endcol,
                                kExtmarkNoUndo,
                                undo_info.data.col_adjust_delete.eol);
    }
  // use extmark_adjust
  } else if (undo_info.type == kLineAdjust) {
    if (undo) {
      // Undo - call signature type one - insert now
      if (undo_info.data.adjust.amount == MAXLNUM) {
        line1 = undo_info.data.adjust.line1;
        line2 = MAXLNUM;
        amount = -undo_info.data.adjust.amount_after;
        amount_after = 0;
      // Undo - call singature type two - delete now
      } else if (undo_info.data.adjust.line2 == MAXLNUM) {
        line1 = undo_info.data.adjust.line1;
        line2 = undo_info.data.adjust.line2;
        amount = -undo_info.data.adjust.amount;
        amount_after = undo_info.data.adjust.amount_after;
      // Undo - call signature three - move lines
      } else {
        line1 = (undo_info.data.adjust.line1
                 + undo_info.data.adjust.amount);
        line2 = (undo_info.data.adjust.line2
                 + undo_info.data.adjust.amount);
        amount = -undo_info.data.adjust.amount;
        amount_after = -undo_info.data.adjust.amount_after;
      }
    // redo
    } else {
      line1 = undo_info.data.adjust.line1;
      line2 = undo_info.data.adjust.line2;
      amount = undo_info.data.adjust.amount;
      amount_after = undo_info.data.adjust.amount_after;
    }
    extmark_adjust(curbuf,
                   line1, line2, amount, amount_after, kExtmarkNoUndo, false);
  // kExtmarkCopy
  } else if (undo_info.type == kExtmarkCopy) {
    // Redo should be handled by kColAdjustDelete or kExtmarkCopyPlace
    if (undo) {
      extmark_set(curbuf,
                  undo_info.data.copy.ns_id,
                  undo_info.data.copy.mark_id,
                  undo_info.data.copy.lnum,
                  undo_info.data.copy.col,
                  kExtmarkNoUndo);
    }
  // uses extmark_copy_and_place
  } else if (undo_info.type == kExtmarkCopyPlace) {
    // Redo, undo is handle by kExtmarkCopy
    if (!undo) {
      extmark_copy_and_place(curbuf,
                             undo_info.data.copy_place.l_lnum,
                             undo_info.data.copy_place.l_col,
                             undo_info.data.copy_place.u_lnum,
                             undo_info.data.copy_place.u_col,
                             undo_info.data.copy_place.p_lnum,
                             undo_info.data.copy_place.p_col,
                             kExtmarkNoUndo, true, NULL);
    }
  // kExtmarkClear
  } else if (undo_info.type == kExtmarkClear) {
    // Redo, undo is handle by kExtmarkCopy
    if (!undo) {
      extmark_clear(curbuf,
                    undo_info.data.clear.ns_id,
                    undo_info.data.clear.l_lnum,
                    undo_info.data.clear.u_lnum,
                    kExtmarkNoUndo);
    }
  // kAdjustMove
  } else if (undo_info.type == kAdjustMove) {
    apply_undo_move(undo_info, undo);
  // extmark_set
  } else if (undo_info.type == kExtmarkSet) {
    if (undo) {
      extmark_del(curbuf,
                  undo_info.data.set.ns_id,
                  undo_info.data.set.mark_id,
                  kExtmarkNoUndo);
    // Redo
    } else {
      extmark_set(curbuf,
                  undo_info.data.set.ns_id,
                  undo_info.data.set.mark_id,
                  undo_info.data.set.lnum,
                  undo_info.data.set.col,
                  kExtmarkNoUndo);
    }
  // extmark_set into update
  } else if (undo_info.type == kExtmarkUpdate) {
    if (undo) {
      extmark_set(curbuf,
                  undo_info.data.update.ns_id,
                  undo_info.data.update.mark_id,
                  undo_info.data.update.old_lnum,
                  undo_info.data.update.old_col,
                  kExtmarkNoUndo);
    // Redo
    } else {
      extmark_set(curbuf,
                  undo_info.data.update.ns_id,
                  undo_info.data.update.mark_id,
                  undo_info.data.update.lnum,
                  undo_info.data.update.col,
                  kExtmarkNoUndo);
    }
  // extmark_del
  } else if (undo_info.type == kExtmarkDel)  {
    if (undo) {
      extmark_set(curbuf,
                  undo_info.data.set.ns_id,
                  undo_info.data.set.mark_id,
                  undo_info.data.set.lnum,
                  undo_info.data.set.col,
                  kExtmarkNoUndo);
    // Redo
    } else {
      extmark_del(curbuf,
                  undo_info.data.set.ns_id,
                  undo_info.data.set.mark_id,
                  kExtmarkNoUndo);
    }
  }
}

// undo/redo an kExtmarkMove operation
static void apply_undo_move(ExtmarkUndoObject undo_info, bool undo)
{
  // 3 calls are required , see comment in function do_move (ex_cmds.c)
  linenr_T line1 = undo_info.data.move.line1;
  linenr_T line2 = undo_info.data.move.line2;
  linenr_T last_line = undo_info.data.move.last_line;
  linenr_T dest = undo_info.data.move.dest;
  linenr_T num_lines = undo_info.data.move.num_lines;
  linenr_T extra = undo_info.data.move.extra;

  if (undo) {
    if (dest >= line2) {
      extmark_adjust(curbuf, dest - num_lines + 1, dest,
                     last_line - dest + num_lines - 1, 0L, kExtmarkNoUndo,
                     true);
      extmark_adjust(curbuf, dest - line2, dest - line1,
                     dest - line2, 0L, kExtmarkNoUndo, false);
    } else {
      extmark_adjust(curbuf, line1-num_lines, line2-num_lines,
                     last_line - (line1-num_lines), 0L, kExtmarkNoUndo, true);
      extmark_adjust(curbuf, (line1-num_lines) + 1, (line2-num_lines) + 1,
                     -num_lines, 0L, kExtmarkNoUndo, false);
    }
    extmark_adjust(curbuf, last_line, last_line + num_lines - 1,
                   line1 - last_line, 0L, kExtmarkNoUndo, true);
  // redo
  } else {
    extmark_adjust(curbuf, line1, line2,
                   last_line - line2, 0L, kExtmarkNoUndo, true);
    if (dest >= line2) {
      extmark_adjust(curbuf, line2 + 1, dest,
                     -num_lines, 0L, kExtmarkNoUndo, false);
    } else {
      extmark_adjust(curbuf, dest + 1, line1 - 1,
                     num_lines, 0L, kExtmarkNoUndo, false);
    }
  extmark_adjust(curbuf, last_line - num_lines + 1, last_line,
                 -(last_line - dest - extra), 0L, kExtmarkNoUndo, true);
  }
}


/// Get the column position for EOL on a line
///
/// If the lnum doesn't exist, returns 0
colnr_T extmark_eol_col(buf_T *buf, linenr_T lnum)
{
  if (lnum > buf->b_ml.ml_line_count) {
    return 0;
  }
  return (colnr_T)STRLEN(ml_get_buf(buf, lnum, false)) + 1;
}


// Adjust columns and rows for extmarks
// based off mark_col_adjust in mark.c
// returns true if something was moved otherwise false
static bool extmark_col_adjust_impl(buf_T *buf, linenr_T lnum,
                                    colnr_T mincol, long lnum_amount,
                                    bool for_delete,
                                    long update_col)
{
  bool marks_exist = false;

  ExtmarkLine *extmarkline = extmarkline_ref(buf, lnum, false);
  if (!extmarkline) {
    return false;
  }

  FOR_ALL_EXTMARKS_IN_LINE(extmarkline->items, mincol, MAXCOL, {
    marks_exist = true;

    // Calculate desired col amount where the adjustment should take place
    // (not taking) eol into account
    long col_amount;
    if (for_delete) {
      if (extmark->col < update_col) {
        // When mark inside range
        colnr_T start_effected_range = mincol - 1;
        col_amount = -(extmark->col - start_effected_range);
      } else {
        // Mark outside of range
        // -1 because a delete of width 0 should still move marks
        col_amount = -(update_col - mincol) - 1;
      }
    } else {
      // for anything other than deletes
      col_amount = update_col;
    }

    // No update required for this guy
    if (col_amount == 0 && lnum_amount == 0) {
      continue;
    }

    // Set mark to start of line
    if (col_amount < 0
        && extmark->col <= (colnr_T)-col_amount) {
      extmark_update(extmark, buf, extmark->ns_id, extmark->mark_id,
                     extmarkline->lnum + lnum_amount,
                     1, kExtmarkNoUndo, &mitr);
      // Update the mark
    } else {
      // Note: The undo is handled by u_extmark_col_adjust, NoUndo here
      extmark_update(extmark, buf, extmark->ns_id, extmark->mark_id,
                     extmarkline->lnum + lnum_amount,
                     extmark->col + (colnr_T)col_amount, kExtmarkNoUndo, &mitr);
    }
  })

  if (kb_size(&extmarkline->items) == 0) {
    kb_del(extmarklines, &buf->b_extlines, extmarkline);
    extmarkline_free(extmarkline);
  }

  return marks_exist;
}

// Adjust columns and rows for extmarks
//
// based off mark_col_adjust in mark.c
// use extmark_col_adjust_impl to move columns by inserting
// Doesn't take the eol into consideration (possible to put marks in invalid
// positions)
void extmark_col_adjust(buf_T *buf, linenr_T lnum,
                        colnr_T mincol, long lnum_amount,
                        long col_amount, ExtmarkOp undo)
{
  assert(col_amount > INT_MIN && col_amount <= INT_MAX);

  bool marks_moved =  extmark_col_adjust_impl(buf, lnum, mincol, lnum_amount,
                                              false, col_amount);

  if (undo == kExtmarkUndo && marks_moved) {
    u_extmark_col_adjust(buf, lnum, mincol, lnum_amount, col_amount);
  }
}

// Adjust marks after a delete on a line
//
// Automatically readjusts to take the eol into account
// TODO(timeyyy): change mincol to be for the mark to be copied, not moved
//
// @param mincol First column that needs to be moved (start of delete range) + 1
// @param endcol Last column which needs to be copied (end of delete range + 1)
void extmark_col_adjust_delete(buf_T *buf, linenr_T lnum,
                               colnr_T mincol, colnr_T endcol,
                               ExtmarkOp undo, int _eol)
{
  colnr_T start_effected_range = mincol;

  bool marks_moved;
  if (undo == kExtmarkUndo) {
    // Copy marks that would be effected by delete
    // -1 because we need to restore if a mark existed at the start pos
    u_extmark_copy(buf, 0, lnum, start_effected_range, lnum, endcol);
  }

  marks_moved = extmark_col_adjust_impl(buf, lnum, mincol, 0,
                                        true, (long)endcol);

  // Deletes at the end of the line have different behaviour than the normal
  // case when deleted.
  // Cleanup any marks that are floating beyond the end of line.
  // we allow this to be passed in as well because the buffer may have already
  // been mutated.
  int eol = _eol;
  if (!eol) {
    eol = extmark_eol_col(buf, lnum);
  }
  FOR_ALL_EXTMARKS(buf, 1, lnum, eol, lnum, -1, {
    extmark_update(extmark, buf, extmark->ns_id, extmark->mark_id,
                   extmarkline->lnum, (colnr_T)eol, kExtmarkNoUndo, &mitr);
  })

  // Record the undo for the actual move
  if (marks_moved && undo == kExtmarkUndo) {
    u_extmark_col_adjust_delete(buf, lnum, mincol, endcol, eol);
  }
}

// Adjust extmark row for inserted/deleted rows (columns stay fixed).
void extmark_adjust(buf_T *buf,
                    linenr_T line1,
                    linenr_T line2,
                    long amount,
                    long amount_after,
                    ExtmarkOp undo,
                    bool end_temp)
{
  ExtmarkLine *_extline;

  // btree needs to be kept ordered to work, so far only :move requires this
  // 2nd call with end_temp = true unpack the lines from the temp position
  if (end_temp && amount < 0) {
    for (size_t i = 0; i < kv_size(buf->b_extmark_move_space); i++) {
      _extline = kv_A(buf->b_extmark_move_space, i);
      _extline->lnum += amount;
      kb_put(extmarklines, &buf->b_extlines, _extline);
    }
    kv_size(buf->b_extmark_move_space) = 0;
    return;
  }

  bool marks_exist = false;
  linenr_T *lp;

  linenr_T adj_start = line1;
  if (amount == MAXLNUM) {
    // Careful! marks from deleted region can end up on en extisting extmarkline
    // that is goinig to be adjusted to the target position.
    linenr_T join_num = line1 - amount_after;
    ExtmarkLine *joinline = (join_num > line2
                             ? extmarkline_ref(buf, join_num, false) : NULL);

    // extmark_adjust is already redoable, the copy should only be for undo
    marks_exist = extmark_copy_and_place(curbuf,
                                         line1, 1,
                                         line2, MAXCOL,
                                         line1, 1,
                                         kExtmarkUndoNoRedo, true, joinline);
    adj_start = line2+1;
  }
  FOR_ALL_EXTMARKLINES(buf, adj_start, MAXLNUM, {
    marks_exist = true;
    lp = &(extmarkline->lnum);
    if (*lp <= line2) {
      // 1st call with end_temp = true, store the lines in a temp position
      if (end_temp && amount > 0) {
          kb_del_itr_extmarklines(&buf->b_extlines, &itr);
          kv_push(buf->b_extmark_move_space, extmarkline);
      }

      *lp += amount;
    } else if (amount_after && *lp > line2) {
      *lp += amount_after;
    }
  })

  if (undo == kExtmarkUndo && marks_exist) {
    u_extmark_adjust(buf, line1, line2, amount, amount_after);
  }
}

/// Range points to copy
///
/// if part of a larger iteration we can't delete, then the caller
/// must check for empty lines.
bool extmark_copy_and_place(buf_T *buf,
                            linenr_T l_lnum, colnr_T l_col,
                            linenr_T u_lnum, colnr_T u_col,
                            linenr_T p_lnum, colnr_T p_col,
                            ExtmarkOp undo, bool delete,
                            ExtmarkLine *destline)

{
  bool marks_moved = false;
  if (undo == kExtmarkUndo || undo == kExtmarkUndoNoRedo) {
    // Copy marks that would be effected by delete
    u_extmark_copy(buf, 0, l_lnum, l_col, u_lnum, u_col);
  }

  // Move extmarks to their final position
  // Careful: if we move items within the same line, we might change order of
  // marks within the same extmarkline. Too keep it simple, first delete all
  // items from the extmarkline and put them back in the right order.
  FOR_ALL_EXTMARKLINES(buf, l_lnum, u_lnum, {
    kvec_t(Extmark) temp_space = KV_INITIAL_VALUE;
    bool same_line = extmarkline == destline;
    FOR_ALL_EXTMARKS_IN_LINE(extmarkline->items,
                             (extmarkline->lnum > l_lnum) ? 0 : l_col,
                             (extmarkline->lnum < u_lnum) ? MAXCOL : u_col, {
      if (!destline) {
        destline = extmarkline_ref(buf, p_lnum, true);
        same_line = extmarkline == destline;
      }
      marks_moved = true;
      if (!same_line) {
        extmark_put(p_col, extmark->mark_id, destline, extmark->ns_id);
        ExtmarkNs *ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns,
                                               extmark->ns_id);
        pmap_put(uint64_t)(ns_obj->map, extmark->mark_id, destline);
      } else {
        kv_push(temp_space, *extmark);
      }
      // Delete old mark
      kb_del_itr(markitems, &extmarkline->items, &mitr);
    })
    if (same_line) {
      for (size_t i = 0; i < kv_size(temp_space); i++) {
        Extmark mark = kv_A(temp_space, i);
        extmark_put(p_col, mark.mark_id, extmarkline, mark.ns_id);
      }
      kv_destroy(temp_space);
    } else if (delete && kb_size(&extmarkline->items) == 0) {
      kb_del_itr(extmarklines, &buf->b_extlines, &itr);
      extmarkline_free(extmarkline);
    }
  })

  // Record the undo for the actual move
  if (marks_moved && undo == kExtmarkUndo) {
    u_extmark_copy_place(buf, l_lnum, l_col, u_lnum, u_col, p_lnum, p_col);
  }

  return marks_moved;
}

// Get reference to line in kbtree_t, allocating it if neccessary.
ExtmarkLine *extmarkline_ref(buf_T *buf, linenr_T lnum, bool put)
{
  kbtree_t(extmarklines) *b = &buf->b_extlines;
  ExtmarkLine t, **pp;
  t.lnum = lnum;

  pp = kb_get(extmarklines, b, &t);
  if (!pp) {
    if (!put) {
      return NULL;
    }
    ExtmarkLine *p = xcalloc(sizeof(ExtmarkLine), 1);
    p->lnum = lnum;
    // p->items zero initialized
    kb_put(extmarklines, b, p);
    return p;
  }
  // Return existing
  return *pp;
}

void extmarkline_free(ExtmarkLine *extmarkline)
{
  kb_destroy(markitems, (&extmarkline->items));
  xfree(extmarkline);
}

/// Put an extmark into a line,
///
/// caller must ensure combination of id and ns_id isn't in use.
void extmark_put(colnr_T col, uint64_t id,
                 ExtmarkLine *extmarkline, uint64_t ns)
{
  Extmark t;
  t.col = col;
  t.mark_id = id;
  t.line = extmarkline;
  t.ns_id = ns;

  kbtree_t(markitems) *b = &(extmarkline->items);
  // kb_put requries the key to not be there
  assert(!kb_getp(markitems, b, &t));

  kb_put(markitems, b, t);
}


