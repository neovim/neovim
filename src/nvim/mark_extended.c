// mark_extended.c --
// Implements extended marks for text widgets.
// Each Mark exists in a btree of lines containing btrees
// of columns.
//
// The btree provides efficent range lookus.
// A map of pointers to the marks is used for fast lookup by mark id.
//
// Marks are moved by calls to: extmark_col_adjust, extmark_adjust, or
// extmark_col_adjust_delete which are based on col_adjust and mark_adjust from
// mark.c
//
// TODO(timeyyy): document the header file here..
// Undo/Redo of marks is implemented by storing the call arguments to
// extmark_col_adjust or extmark_adjust. The list of arguments
// is applied in extmark_apply_undo. The only case where we have to
// copy extmarks is for the area being effected by a delete.
//
// TODO(timeyyy): documentaion needs to be update
// Marks live in namespaces that allow plugins/users to segregate marks
// from other users, namespaces have to be initialized before usage
//
// For possible ideas for efficency improvements see:
// http://blog.atom.io/2015/06/16/optimizing-an-important-atom-primitive.html
// Other implementations exist in gtk and tk toolkits.
//
//
// Some Notes and misconeption points
// ----------------------------------
// Deleting marks only happens explicitly extmark_del, deleteing over a
// range of marks will only move the marks.
//
// deleting on a mark will leave it in that same position unless it is on
// the eol of the line.
//
// Testing for correct mark behavior.
// ----------------------------------
// To play around with what the marks SHOULD do, check out the tk
// text marks to use as a reference (for off by one behaviour etc)
//
// Warning: tkinter col starts at 0 while neovim starts at 1
//
// from a python3 shell:
//
// from tkinter import *
// text = Text()
// text.pack()
// # Check the net for a full guide but in general the following are useful:
// # text.mark_set("1", "1.5")
// # text.index("1")
// # text.get("1")

#include <assert.h>
#include "nvim/vim.h"
#include "charset.h"           // skipwhite
#include "nvim/mark_extended.h"
#include "nvim/memline.h"      // ml_get_buf
#include "nvim/pos.h"          // MAXLNUM
#include "nvim/globals.h"      // FOR_ALL_BUFFERS
#include "nvim/map.h"          // pmap ...
#include "nvim/lib/kbtree.h"   // kbitr ...
#include "nvim/undo.h"         // force_get_undo_header

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark_extended.c.generated.h"
#include "mark_extended.h"

#endif

colnr_T BufPosStartCol = 1;
linenr_T BufPosStartRow = 1;

static linenr_T check_lnum(buf_T *buf, linenr_T lnum)
{
  linenr_T maxlen = buf->b_ml.ml_line_count + 1;
  if (lnum > maxlen) {
    return maxlen;
  }
  return lnum;
}

static colnr_T check_col(buf_T *buf, linenr_T lnum, colnr_T col)
{
  int line_len = len_of_line_inclusive_white_space(buf, lnum);
  colnr_T maxlen = (colnr_T)line_len + 1;
  if (col > maxlen) {
    return maxlen;
  }
  return col;
}

// Create or update an extmark, marks are force to a valid position.
// Returns 1 on new mark created
// Returns 2 on succesful update
int extmark_set(buf_T *buf,
                uint64_t ns,
                uint64_t id,
                linenr_T _lnum,
                colnr_T _col,
                ExtmarkOp op)
{
  linenr_T lnum = check_lnum(buf, _lnum);
  colnr_T col = check_col(buf, lnum, _col);

  ExtendedMark *extmark = extmark_from_id(buf, ns, id);
  if (!extmark) {
    return extmark_create(buf, ns, id, lnum, col, op);
  } else {
    extmark_update(extmark, buf, ns, id, lnum,  col, op, NULL);
    return 2;
  }
}

// Remove an extmark
// Returns 0 on missing id
int extmark_del(buf_T *buf,
                uint64_t ns,
                uint64_t id,
                ExtmarkOp op)
{
  ExtendedMark *extmark = extmark_from_id(buf, ns, id);
  if (!extmark) {
    return 0;
  }
  return extmark_delete(extmark, buf, ns, id, op);
}

// Returns the position of marks between a range,
// marks found at the start or end index will be included,
// if upper_lnum or upper_col are negative the buffer
// will be searched to the start, or end
// dir can be set to control the order of the array
// amount = amount of marks to find or -1 for all
ExtmarkArray extmark_get(buf_T *buf,
                         uint64_t ns,
                         linenr_T l_lnum,
                         colnr_T l_col,
                         linenr_T u_lnum,
                         colnr_T u_col,
                         int64_t amount,
                         int dir)
{
  ExtmarkArray array = KV_INITIAL_VALUE;
  // Find all the marks
  if (amount == -1) {
    if (dir == FORWARD) {
      FOR_ALL_EXTMARKS(buf, ns, l_lnum, l_col, u_lnum, u_col, {
        if (extmark->ns_id == ns) {
          kv_push(array, extmark);
        }
      })
    } else {
      FOR_ALL_EXTMARKS_PREV(buf, ns, l_lnum, l_col, u_lnum, u_col, {
        if (extmark->ns_id == ns) {
          kv_push(array, extmark);
        }
      })
    }
  // Find only a certain amount of marks (only thing extra is the size check )
  } else {
    if (dir == FORWARD) {
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
  }
  return array;
}

static bool extmark_create(buf_T *buf,
                           uint64_t ns,
                           uint64_t id,
                           linenr_T lnum,
                           colnr_T col,
                           ExtmarkOp op)
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
  ExtMarkLine *extline = extline_ref(&buf->b_extlines, lnum);
  // Create and put mark on the line
  extmark_put(col, id, extline, ns);

  // Marks do not have stable address so we have to look them up
  // by using the line instead of the mark
  pmap_put(uint64_t)(ns_obj->map, id, extline);
  if (op != kExtmarkNoUndo) {
    u_extmark_set(buf, ns, id, lnum, col, kExtmarkSet);
  }

  // Set a free id so extmark_free_id_get works
  extmark_free_id_set(ns_obj, id);
  return true;
}

// update the position of an extmark
// to update while iterating pass the markitems itr
static void extmark_update(ExtendedMark *extmark,
                           buf_T *buf,
                           uint64_t ns,
                           uint64_t id,
                           linenr_T lnum,
                           colnr_T col,
                           ExtmarkOp op,
                           kbitr_t(markitems) *mitr)
{
  assert(op != kExtmarkNOOP);
  if (op != kExtmarkNoUndo) {
    u_extmark_update(buf, ns, id, extmark->line->lnum, extmark->col,
                     lnum, col);
  }
  ExtMarkLine *old_line = extmark->line;
  // Move the mark to a new line and update column
  if (old_line->lnum != lnum) {
    ExtMarkLine *ref_line = extline_ref(&buf->b_extlines, lnum);
    extmark_put(col, id, ref_line, ns);
    // Update the hashmap
    ExtmarkNs *ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
    pmap_put(uint64_t)(ns_obj->map, id, ref_line);
    // Delete old mark
    if (mitr != NULL) {
      kb_del_itr(markitems, &(old_line->items), mitr);
    } else {
      kb_del(markitems, &(old_line->items), *extmark);
    }
  // Just update the column
  } else {
    extmark->col = col;
  }
}

static int extmark_delete(ExtendedMark *extmark,
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
  ExtMarkLine *extline = extmark->line;
  kb_del(markitems, &extline->items, *extmark);
  // Remove the line if there are no more marks in the line
  if (kb_size(&extline->items) == 0) {
    kb_del(extlines, &buf->b_extlines, extline);
  }
  return true;
}

// Lookup an extmark by id
ExtendedMark *extmark_from_id(buf_T *buf, uint64_t ns, uint64_t id)
{
  if (!buf->b_extmark_ns) {
    return NULL;
  }
  ExtmarkNs *ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
  if (!ns_obj || !kh_size(ns_obj->map->table)) {
    return NULL;
  }
  ExtMarkLine *extline = pmap_get(uint64_t)(ns_obj->map, id);
  if (!extline) {
    return NULL;
  }

  FOR_ALL_EXTMARKS_IN_LINE(extline->items, {
    if (extmark->ns_id == ns
        && extmark->mark_id == id) {
      return extmark;
    }
  })
  return NULL;
}

// Lookup an extmark by position
ExtendedMark *extmark_from_pos(buf_T *buf,
                               uint64_t ns, linenr_T lnum, colnr_T col)
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
  uint64_t free_id = 0;

  if (!buf->b_extmark_ns) {
    return free_id;
  }
  ExtmarkNs *ns_obj = pmap_get(uint64_t)(buf->b_extmark_ns, ns);
  if (!ns_obj) {
    return free_id;
  }
  return ns_obj->free_id;
}

// Set the next free id in a namesapce
static void extmark_free_id_set(ExtmarkNs *ns_obj, uint64_t id)
{
  // Simply Heurstic, the largest id + 1
  ns_obj->free_id = id + 1;
}

// free extmarks from the buffej
void extmark_free_all(buf_T *buf)
{
  if (!buf->b_extmark_ns) {
    return;
  }

  uint64_t ns;
  ExtmarkNs *ns_obj;

  map_foreach(buf->b_extmark_ns, ns, ns_obj, {
     FOR_ALL_EXTMARKS(buf, ns, MINLNUM, MINCOL, MAXLNUM, MAXCOL, {
       kb_del_itr(markitems, &extline->items, &mitr);
     });
    pmap_free(uint64_t)(ns_obj->map);
    xfree(ns_obj);
  });

  pmap_free(uint64_t)(buf->b_extmark_ns);

  FOR_ALL_EXTMARKLINES(buf, MINLNUM, MAXLNUM, {
    kb_destroy(markitems, (&extline->items));
    kb_del_itr(extlines, &buf->b_extlines, &itr);
    xfree(extline);
  })
  // k?_init called to set pointers to NULL
  kb_destroy(extlines, (&buf->b_extlines));
  kb_init(&buf->b_extlines);

  kv_destroy(buf->b_extmark_move_space);
  kv_init(buf->b_extmark_move_space);
}


// Save info for undo/redo of set marks
static void u_extmark_set(buf_T *buf,
                          uint64_t ns,
                          uint64_t id,
                          linenr_T lnum,
                          colnr_T col,
                          UndoObjectType undo_type)
{
  u_header_T  *uhp = force_get_undo_header(buf);
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
static void u_extmark_update(buf_T *buf,
                             uint64_t ns,
                             uint64_t id,
                             linenr_T old_lnum,
                             colnr_T old_col,
                             linenr_T lnum,
                             colnr_T col)
{
  u_header_T  *uhp = force_get_undo_header(buf);
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
static bool u_compact_col_adjust(buf_T *buf,
                                 linenr_T lnum,
                                 colnr_T mincol,
                                 long lnum_amount,
                                 long col_amount)
{
  u_header_T  *uhp = force_get_undo_header(buf);
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
void u_extmark_col_adjust(buf_T *buf,
                          linenr_T lnum,
                          colnr_T mincol,
                          long lnum_amount,
                          long col_amount)
{
  u_header_T  *uhp = force_get_undo_header(buf);
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
void u_extmark_col_adjust_delete(buf_T *buf,
                                 linenr_T lnum,
                                 colnr_T mincol,
                                 colnr_T endcol)
{
  u_header_T  *uhp = force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  ColAdjustDelete col_adjust_delete;
  col_adjust_delete.lnum = lnum;
  col_adjust_delete.mincol = mincol;
  col_adjust_delete.endcol = endcol;

  ExtmarkUndoObject undo = { .type = kColAdjustDelete,
                             .data.col_adjust_delete = col_adjust_delete };

  kv_push(uhp->uh_extmark, undo);
}

// Save adjust info so we can undo/redo
static void u_extmark_adjust(buf_T * buf,
                             linenr_T line1,
                             linenr_T line2,
                             long amount,
                             long amount_after)
{
  u_header_T  *uhp = force_get_undo_header(buf);
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
void u_extmark_move(buf_T *buf,
                    linenr_T line1,
                    linenr_T line2,
                    linenr_T last_line,
                    linenr_T dest,
                    linenr_T num_lines,
                    linenr_T extra)
{
  u_header_T  *uhp = force_get_undo_header(buf);
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
// undo
void u_extmark_copy(buf_T *buf,
                    linenr_T l_lnum,
                    colnr_T l_col,
                    linenr_T u_lnum,
                    colnr_T u_col)
{
  u_header_T  *uhp = force_get_undo_header(buf);
  if (!uhp) {
    return;
  }

  ExtmarkCopy copy;
  ExtmarkUndoObject undo;
  FOR_ALL_EXTMARKS(buf, STARTING_NAMESPACE, l_lnum, l_col, u_lnum, u_col, {
    copy.ns_id = extmark->ns_id;
    copy.mark_id = extmark->mark_id;
    copy.lnum = extmark->line->lnum;
    copy.col = extmark->col;

    undo.data.copy = copy;
    undo.type = kExtmarkCopy;
    kv_push(uhp->uh_extmark, undo);
  });
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
                                kExtmarkNoUndo);
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
    // Redo should be handled by kColAdjustDelete
    if (undo) {
      extmark_set(curbuf,
                  undo_info.data.copy.ns_id,
                  undo_info.data.copy.mark_id,
                  undo_info.data.copy.lnum,
                  undo_info.data.copy.col,
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
      extmark_adjust(curbuf,
                     dest - num_lines + 1,
                     dest,
                     last_line - dest + num_lines - 1,
                     0L,
                     kExtmarkNoUndo,
                     true);
      extmark_adjust(curbuf,
                     dest - line2,
                     dest - line1,
                     dest - line2,
                     0L,
                     kExtmarkNoUndo,
                     false);
    } else {
      extmark_adjust(curbuf,
                     line1-num_lines,
                     line2-num_lines,
                     last_line - (line1-num_lines),
                     0L,
                     kExtmarkNoUndo,
                     true);
      extmark_adjust(curbuf,
                     (line1-num_lines) + 1,
                     (line2-num_lines) + 1,
                     -num_lines,
                     0L,
                     kExtmarkNoUndo,
                     false);
    }
    extmark_adjust(curbuf,
                   last_line,
                   last_line + num_lines - 1,
                   line1 - last_line,
                   0L,
                   kExtmarkNoUndo,
                   true);
  // redo
  } else {
    extmark_adjust(curbuf,
                   line1,
                   line2,
                   last_line - line2,
                   0L,
                   kExtmarkNoUndo,
                   true);
    if (dest >= line2) {
      extmark_adjust(curbuf,
                     line2 + 1,
                     dest,
                     -num_lines,
                     0L,
                     kExtmarkNoUndo,
                     false);
    } else {
      extmark_adjust(curbuf,
                     dest + 1,
                     line1 - 1,
                     num_lines,
                     0L,
                     kExtmarkNoUndo,
                     false);
    }
  extmark_adjust(curbuf,
                 last_line - num_lines + 1,
                 last_line,
                 -(last_line - dest - extra),
                 0L,
                 kExtmarkNoUndo,
                 true);
  }
}

// for anything other than deletes
// Return, desired col amount where the adjustment should take place
// (not taking) eol into account
long update_constantly(colnr_T _, colnr_T __, long col_amount)
{
  return col_amount;
}

// for deletes,
// Return, desired col amount where the adjustment should take place
// (not taking) eol into account
long update_variably(colnr_T mincol, colnr_T current, long endcol)
{
  colnr_T start_effected_range = mincol - 1;
  long col_amount;
  // When mark inside range
  if (current < endcol) {
    col_amount = -(current - start_effected_range);
  // Mark outside of range
  } else {
    // -1 because a delete of width 0 should still move marks
    col_amount = -(endcol - start_effected_range);
  }
  return col_amount;
}


// Return pointer to line.
char_u *get_line_ptr(linenr_T lnum)
{
  return ml_get_buf(curbuf, lnum, false);
}

// TODO(timeyyy): Does this belong somewhere else?
// Get the length of the current line, including trailing white space.
// If the lnum doesn't exist, returns 0
// based from ex_cmds.c/linelen
int len_of_line_inclusive_white_space(buf_T *buf, linenr_T lnum)
{
  if (lnum > buf->b_ml.ml_line_count) {
    return 0;
  }
  char_u *line = get_line_ptr(lnum);
  int len = linetabsize(line);
  return len;
}

// original kb_itr_get as exists in upstream klib
// just modified the return arguments to 0 and 1 instaed of -1 and 0
static inline int debug_original_get(kbtree_markitems_t *b, ExtendedMark * __restrict k, kbitr_markitems_t *itr)
{
  int i, r = 0;
  itr->p = itr->stack;
  itr->p->x = b->root; itr->p->i = 0;
  while (itr->p->x) {
    i = __kb_getp_aux_markitems(itr->p->x, k, &r);
    if (i >= 0 && r == 0)
      return 1;
    if (itr->p->x->is_internal == 0)
      return 0;
    itr->p[1].x = __KB_PTR(b, itr->p->x)[i + 1];
    itr->p[1].i = i;
    ++itr->p;
  }
  return 0;
}

static inline int debug_itr_get(kbtree_markitems_t *b, ExtendedMark k, kbitr_markitems_t *itr) {
  return debug_itr_getp(b,&k,itr);
}

static inline int debug_itr_getp(kbtree_markitems_t *b, ExtendedMark * __restrict k, kbitr_markitems_t *itr) {
  if (b->n_keys == 0) {
    itr->p = NULL;
    return 0;
  }
  int i, r = 0;
  itr->p = itr->stack;
  itr->p->x = b->root;
  while (itr->p->x) {
    i = __kb_getp_aux_markitems(itr->p->x, k, &r);
     itr->p->i = i;
    if (i >= 0 && r == 0)
      return 1;
    ++itr->p->i;
    itr->p[1].x = itr->p->x->is_internal? __KB_PTR(b, itr->p->x)[i + 1] : 0;
    ++itr->p;
  }
  return 0;
}

static inline int debug_itr_next_markitems(kbtree_markitems_t *b, kbitr_markitems_t *itr) {
  if (itr->p < itr->stack)
    return 0;
  for (;;) {
    ++itr->p->i; // BOOM
    while (itr->p->x && itr->p->i <= itr->p->x->n) {
      itr->p[1].i = 0;
      itr->p[1].x = itr->p->x->is_internal? __KB_PTR(b, itr->p->x)[itr->p->i] : 0;
      ++itr->p;
    }
    --itr->p;
    if (itr->p < itr->stack)
      return 0;
    if (itr->p->x && itr->p->i < itr->p->x->n)
      return 1;
  }
}


// Adjust columns and rows for extmarks
// based off mark_col_adjust in mark.c
// returns true if something was moved otherwise false
static bool _extmark_col_adjust(buf_T *buf, linenr_T lnum,
                                colnr_T mincol, long lnum_amount,
                                long (*calc_amount)(colnr_T, colnr_T, long),
                                long func_arg)
{
  bool marks_exist = false;
  colnr_T *cp;
  long col_amount;

  kbitr_extlines_t itr;
  ExtMarkLine t;
  t.lnum = lnum == -1 ? 1 : lnum;
  if (!kb_itr_get_extlines(&buf->b_extlines, &t, &itr)) {
    kb_itr_next_extlines(&buf->b_extlines, &itr);
  }
  ExtMarkLine *extline;
  for (; ((&itr)->p >= (&itr)->stack); kb_itr_next_extlines(&buf->b_extlines, &itr)) {
    extline = ((&itr)->p->x->key)[(&itr)->p->i];
    if (extline->lnum > lnum && lnum != -1) { break; }
    {
      kbitr_markitems_t mitr;
      ExtendedMark mt;
      mt.ns_id = 0;
      mt.mark_id = 0;
      mt.line = ((void *) 0);
      mt.col = 0;

      if (!debug_itr_get(&extline->items, mt, &mitr)) {
     // if (!debug_original_get(&extline->items, &mt, &mitr)) {
     // if (!kb_itr_get_markitems(&extline->items, mt, &mitr)) {
        // kb_itr_next_markitems(&extline->items, &mitr);
        debug_itr_next_markitems(&extline->items, &mitr);

      }
      ExtendedMark *extmark;
      for (; ((&mitr)->p >= (&mitr)->stack); kb_itr_next_markitems(
              &extline->items, &mitr)) {
        extmark = &((&mitr)->p->x->key)[(&mitr)->p->i];
        {
          marks_exist = 1;
          cp = &(extmark->col);
          col_amount = (*calc_amount)(mincol, *cp, func_arg);
          if (col_amount == 0 && lnum_amount == 0) { continue; }
          if (col_amount < 0 && *cp <= (colnr_T) -col_amount && *cp > mincol) {
            extmark_update(extmark, buf, extmark->ns_id, extmark->mark_id,
                           extline->lnum + lnum_amount, BufPosStartCol,
                           kExtmarkNoUndo, &mitr);
          }
          else if (*cp >= mincol) {
            extmark_update(extmark, buf, extmark->ns_id, extmark->mark_id,
                           extline->lnum + lnum_amount,
                           *cp + (colnr_T) col_amount, kExtmarkNoUndo, &mitr);
          }
        };
      }
    };
  }
  if (marks_exist) {
      return true;
  } else {
      return false;
  }
}

// use _extmark_col_adjust to move columns by inserting
void extmark_col_adjust(buf_T *buf, linenr_T lnum,
                        colnr_T mincol, long lnum_amount,
                        long col_amount, ExtmarkOp undo)
{
  assert(col_amount > INT_MIN && col_amount <= INT_MAX);

  bool marks_moved =  _extmark_col_adjust(buf, lnum, mincol, lnum_amount,
                                          &update_constantly, col_amount);

  if (undo == kExtmarkUndo && marks_moved) {
    u_extmark_col_adjust(buf, lnum, mincol, lnum_amount, col_amount);
  }
}

// Adjust marks by doing a delete on a line
// TODO(timeyyy): change mincol to be for the mark to be copied, not moved
// mincol: First column that needs to be moved (start of delete range)
// endcol: Last column which needs to be copied (end of delete range + 1)
void extmark_col_adjust_delete(buf_T *buf, linenr_T lnum,
                               colnr_T mincol, colnr_T endcol,
                               ExtmarkOp undo)
{
  colnr_T start_effected_range = mincol - 1;
  assert(start_effected_range <= endcol);

  bool marks_moved;
  if (undo == kExtmarkUndo) {
    // Copy marks that would be effected by delete
    // -1 because we need to restore if a mark existed at the start pos
    u_extmark_copy(buf, lnum, start_effected_range, lnum, endcol);
  }

  marks_moved = _extmark_col_adjust(buf, lnum, mincol, 0,
                                    &update_variably, (long)endcol);

  // Deletes at the end of the line have different behaviour than the normal
  // case when deleted.
  // Cleanup any marks that are floating beyond the end of line.
  int line_length = len_of_line_inclusive_white_space(buf, lnum);
  if (line_length == 0) {
    line_length = BufPosStartCol;
  }
  FOR_ALL_EXTMARKS(buf, STARTING_NAMESPACE, lnum, line_length, lnum, -1, {
    extmark_update(extmark, buf, extmark->ns_id, extmark->mark_id,
                   extline->lnum, (colnr_T)line_length, kExtmarkNoUndo, &mitr);
  })

  // Record the undo for the actual move
  if (marks_moved && undo == kExtmarkUndo) {
    u_extmark_col_adjust_delete(buf, lnum, mincol, endcol);
  }
}

// Adjust extmark row for inserted/deleted rows (columns stay fixed).
void extmark_adjust(buf_T * buf,
                    linenr_T line1,
                    linenr_T line2,
                    long amount,
                    long amount_after,
                    ExtmarkOp undo,
                    bool end_temp)
{
  ExtMarkLine *_extline;

  // btree needs to be kept ordered to work, so far only :move requires this
  // 2nd call with end_temp =  unpack the lines from the temp position
  if (end_temp && amount < 0) {
    for (size_t i = 0; i < kv_size(buf->b_extmark_move_space); i++) {
      _extline = kv_A(buf->b_extmark_move_space, i);
      _extline->lnum += amount;
      kb_put(extlines, &buf->b_extlines, _extline);
    }
    kv_size(buf->b_extmark_move_space) = 0;
    return;
  }

  bool marks_exist = false;
  linenr_T *lp;
  FOR_ALL_EXTMARKLINES(buf, MINLNUM, MAXLNUM, {
    marks_exist = true;
    lp = &(extline->lnum);
    if (*lp >= line1 && *lp <= line2) {
      // 1st call with end_temp = true, store the lines in a temp position
      if (end_temp && amount > 0) {
        kb_del_itr(extlines, &buf->b_extlines, &itr);
        kv_push(buf->b_extmark_move_space, extline);
      }

      // Delete the line
      if (amount == MAXLNUM) {
        FOR_ALL_EXTMARKS_IN_LINE(extline->items, {
          extmark_del(buf, extmark->ns_id, extmark->mark_id, kExtmarkUndo);
        })
        // TODO(timeyyy): make freeing the line a undoable action
        // see branch extmarks_broken_delete_lines
      } else {
        *lp += amount;
      }
    } else if (amount_after && *lp > line2) {
      *lp += amount_after;
    }
  })

  if (undo == kExtmarkUndo && marks_exist) {
    u_extmark_adjust(buf, line1, line2, amount, amount_after);
  }
}

// Get reference to line in kbtree_t, allocating it if neccessary.
ExtMarkLine *extline_ref(kbtree_t(extlines) *b, linenr_T lnum)
{
  ExtMarkLine t, **pp;
  t.lnum = lnum;

  pp = kb_get(extlines, b, &t);
  if (!pp) {
    ExtMarkLine *p = xcalloc(sizeof(ExtMarkLine), 1);
    p->lnum = lnum;
    // p->items zero initialized
    kb_put(extlines, b, p);
    return p;
  }
  // Return existing
  return *pp;
}

// Put an extmark into a line, combination of id and ns_id must be unique
void extmark_put(colnr_T col,
                 uint64_t id,
                 ExtMarkLine *extline,
                 uint64_t ns)
{
  ExtendedMark t;
  t.col = col;
  t.mark_id = id;
  t.line = extline;
  t.ns_id = ns;

  kbtree_t(markitems) *b = &(extline->items);
  // kb_put requries the key to not be there
  assert(!kb_getp(markitems, b, &t));

  kb_put(markitems, b, t);
}

// We only need to compare columns as rows are stored in different trees.
// Marks are ordered by: position, namespace, mark_id
// This improves moving marks but slows down all other use cases (searches)
int mark_cmp(ExtendedMark a, ExtendedMark b)
{
  int cmp = kb_generic_cmp(a.col, b.col);
  if (cmp != 0) {
    return cmp;
  }
  cmp = kb_generic_cmp(a.ns_id, b.ns_id);
  if (cmp != 0) {
    return cmp;
  }
  return kb_generic_cmp(a.mark_id, b.mark_id);
}
