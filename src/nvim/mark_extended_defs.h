#ifndef NVIM_MARK_EXTENDED_DEFS_H
#define NVIM_MARK_EXTENDED_DEFS_H

#include "nvim/pos.h"  // for colnr_T
#include "nvim/map.h"  // for uint64_t
#include "nvim/lib/kbtree.h"
#include "nvim/lib/kvec.h"

struct ExtMarkLine;

typedef struct ExtendedMark
{
  uint64_t ns_id;
  uint64_t mark_id;
  struct ExtMarkLine *line;
  colnr_T col;
} ExtendedMark;


// We only need to compare columns as rows are stored in a different tree.
// Marks are ordered by: position, namespace, mark_id
// This improves moving marks but slows down all other use cases (searches)
static inline int extmark_cmp(ExtendedMark a, ExtendedMark b)
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


#define markitems_cmp(a, b) (extmark_cmp((a), (b)))
KBTREE_INIT(markitems, ExtendedMark, markitems_cmp, 10)

typedef struct ExtMarkLine
{
  linenr_T lnum;
  kbtree_t(markitems) items;
} ExtMarkLine;

#define extline_cmp(a, b) (kb_generic_cmp((a)->lnum, (b)->lnum))
KBTREE_INIT(extlines, ExtMarkLine *, extline_cmp, 10)


typedef struct undo_object ExtmarkUndoObject;
typedef kvec_t(ExtmarkUndoObject) extmark_undo_vec_t;


#endif  // NVIM_MARK_EXTENDED_DEFS_H
