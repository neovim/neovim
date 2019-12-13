#ifndef NVIM_MARK_EXTENDED_H
#define NVIM_MARK_EXTENDED_H

#include "nvim/mark_extended_defs.h"
#include "nvim/buffer_defs.h"  // for buf_T


// Macro Documentation: FOR_ALL_?
// Search exclusively using the range values given.
// Use MAXCOL/MAXLNUM for the start and end of the line/col.
// The ns parameter: Unless otherwise stated, this is only a starting point
//    for the btree to searched in, the results being itterated over will
//    still contain extmarks from other namespaces.

// see FOR_ALL_? for documentation
#define FOR_ALL_EXTMARKLINES(buf, l_lnum, u_lnum, code)\
  kbitr_t(extmarklines) itr;\
  ExtmarkLine t;\
  t.lnum = l_lnum;\
  if (!kb_itr_get(extmarklines, &buf->b_extlines, &t, &itr)) { \
    kb_itr_next(extmarklines, &buf->b_extlines, &itr);\
  }\
  ExtmarkLine *extmarkline;\
  for (; kb_itr_valid(&itr); kb_itr_next(extmarklines, \
                                         &buf->b_extlines, &itr)) { \
    extmarkline = kb_itr_key(&itr);\
    if (extmarkline->lnum > u_lnum) { \
      break;\
    }\
      code;\
    }

// see FOR_ALL_? for documentation
#define FOR_ALL_EXTMARKLINES_PREV(buf, l_lnum, u_lnum, code)\
  kbitr_t(extmarklines) itr;\
  ExtmarkLine t;\
  t.lnum = u_lnum;\
  if (!kb_itr_get(extmarklines, &buf->b_extlines, &t, &itr)) { \
    kb_itr_prev(extmarklines, &buf->b_extlines, &itr);\
  }\
  ExtmarkLine *extmarkline;\
  for (; kb_itr_valid(&itr); kb_itr_prev(extmarklines, \
                                         &buf->b_extlines, &itr)) { \
    extmarkline = kb_itr_key(&itr);\
    if (extmarkline->lnum < l_lnum) { \
      break;\
    }\
    code;\
  }

// see FOR_ALL_? for documentation
#define FOR_ALL_EXTMARKS(buf, ns, l_lnum, l_col, u_lnum, u_col, code)\
  kbitr_t(markitems) mitr;\
  Extmark mt;\
  mt.ns_id = ns;\
  mt.mark_id = 0;\
  mt.line = NULL;\
  FOR_ALL_EXTMARKLINES(buf, l_lnum, u_lnum, { \
    mt.col = (extmarkline->lnum != l_lnum) ? MINCOL : l_col;\
    if (!kb_itr_get(markitems, &extmarkline->items, mt, &mitr)) { \
        kb_itr_next(markitems, &extmarkline->items, &mitr);\
    } \
    Extmark *extmark;\
    for (; \
         kb_itr_valid(&mitr); \
         kb_itr_next(markitems, &extmarkline->items, &mitr)) { \
      extmark = &kb_itr_key(&mitr);\
      if (extmark->line->lnum == u_lnum \
          && extmark->col > u_col) { \
        break;\
      }\
      code;\
    }\
  })


// see FOR_ALL_? for documentation
#define FOR_ALL_EXTMARKS_PREV(buf, ns, l_lnum, l_col, u_lnum, u_col, code)\
  kbitr_t(markitems) mitr;\
  Extmark mt;\
  mt.mark_id = sizeof(uint64_t);\
  mt.ns_id = ns;\
  FOR_ALL_EXTMARKLINES_PREV(buf, l_lnum, u_lnum, { \
    mt.col = (extmarkline->lnum != u_lnum) ? MAXCOL : u_col;\
    if (!kb_itr_get(markitems, &extmarkline->items, mt, &mitr)) { \
        kb_itr_prev(markitems, &extmarkline->items, &mitr);\
    } \
    Extmark *extmark;\
    for (; \
         kb_itr_valid(&mitr); \
         kb_itr_prev(markitems, &extmarkline->items, &mitr)) { \
      extmark = &kb_itr_key(&mitr);\
      if (extmark->line->lnum == l_lnum \
          && extmark->col < l_col) { \
          break;\
      }\
      code;\
    }\
  })


#define FOR_ALL_EXTMARKS_IN_LINE(items, l_col, u_col, code)\
  kbitr_t(markitems) mitr;\
  Extmark mt;\
  mt.ns_id = 0;\
  mt.mark_id = 0;\
  mt.line = NULL;\
  mt.col = l_col;\
  colnr_T extmarkline_u_col = u_col;\
  if (!kb_itr_get(markitems, &items, mt, &mitr)) { \
    kb_itr_next(markitems, &items, &mitr);\
  } \
  Extmark *extmark;\
  for (; kb_itr_valid(&mitr); kb_itr_next(markitems, &items, &mitr)) { \
    extmark = &kb_itr_key(&mitr);\
    if (extmark->col > extmarkline_u_col) { \
      break;\
    }\
    code;\
  }


typedef struct ExtmarkNs {  // For namespacing extmarks
  PMap(uint64_t) *map;      // For fast lookup
  uint64_t free_id;         // For automatically assigning id's
} ExtmarkNs;


typedef kvec_t(Extmark *) ExtmarkArray;


// Undo/redo extmarks

typedef enum {
  kExtmarkNOOP,        // Extmarks shouldn't be moved
  kExtmarkUndo,        // Operation should be reversable/undoable
  kExtmarkNoUndo,      // Operation should not be reversable
  kExtmarkUndoNoRedo,  // Operation should be undoable, but not redoable
} ExtmarkOp;


// adjust line numbers only, corresponding to mark_adjust call
typedef struct {
  linenr_T line1;
  linenr_T line2;
  long amount;
  long amount_after;
} Adjust;

// adjust columns after split/join line, like mark_col_adjust
typedef struct {
  linenr_T lnum;
  colnr_T mincol;
  long col_amount;
  long lnum_amount;
} ColAdjust;

// delete the columns between mincol and endcol
typedef struct {
    linenr_T lnum;
    colnr_T mincol;
    colnr_T endcol;
    int eol;
} ColAdjustDelete;

// adjust linenumbers after :move operation
typedef struct {
  linenr_T line1;
  linenr_T line2;
  linenr_T last_line;
  linenr_T dest;
  linenr_T num_lines;
  linenr_T extra;
} AdjustMove;

// TODO(bfredl): reconsider if we really should track mark creation/updating
// itself, these are not really "edit" operation.
// extmark was created
typedef struct {
  uint64_t ns_id;
  uint64_t mark_id;
  linenr_T lnum;
  colnr_T col;
} ExtmarkSet;

// extmark was updated
typedef struct {
  uint64_t ns_id;
  uint64_t mark_id;
  linenr_T old_lnum;
  colnr_T old_col;
  linenr_T lnum;
  colnr_T col;
} ExtmarkUpdate;

// copied mark before deletion (as operation is destructive)
typedef struct {
  uint64_t ns_id;
  uint64_t mark_id;
  linenr_T lnum;
  colnr_T col;
} ExtmarkCopy;

// also used as part of :move operation? probably can be simplified to one
// event.
typedef struct {
  linenr_T l_lnum;
  colnr_T l_col;
  linenr_T u_lnum;
  colnr_T u_col;
  linenr_T p_lnum;
  colnr_T p_col;
} ExtmarkCopyPlace;

// extmark was cleared.
// TODO(bfredl): same reconsideration as for ExtmarkSet/ExtmarkUpdate
typedef struct {
  uint64_t ns_id;
  linenr_T l_lnum;
  linenr_T u_lnum;
} ExtmarkClear;


typedef enum {
  kLineAdjust,
  kColAdjust,
  kColAdjustDelete,
  kAdjustMove,
  kExtmarkSet,
  kExtmarkDel,
  kExtmarkUpdate,
  kExtmarkCopy,
  kExtmarkCopyPlace,
  kExtmarkClear,
} UndoObjectType;

// TODO(bfredl): reduce the number of undo action types
struct undo_object {
  UndoObjectType type;
  union {
    Adjust adjust;
    ColAdjust col_adjust;
    ColAdjustDelete col_adjust_delete;
    AdjustMove move;
    ExtmarkSet set;
    ExtmarkUpdate update;
    ExtmarkCopy copy;
    ExtmarkCopyPlace copy_place;
    ExtmarkClear clear;
  } data;
};


// For doing move of extmarks in substitutions
typedef struct {
  lpos_T startpos;
  lpos_T endpos;
  linenr_T lnum;
  int sublen;
} ExtmarkSubSingle;

// For doing move of extmarks in substitutions
typedef struct {
  lpos_T startpos;
  lpos_T endpos;
  linenr_T lnum;
  linenr_T newline_in_pat;
  linenr_T newline_in_sub;
  linenr_T lnum_added;
  lpos_T cm_start;  // start of the match
  lpos_T cm_end;    // end of the match
  int eol;    // end of the match
} ExtmarkSubMulti;

typedef kvec_t(ExtmarkSubSingle) extmark_sub_single_vec_t;
typedef kvec_t(ExtmarkSubMulti) extmark_sub_multi_vec_t;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark_extended.h.generated.h"
#endif

#endif  // NVIM_MARK_EXTENDED_H
