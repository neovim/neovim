#ifndef NVIM_MARK_EXTENDED_DEFS_H
#define NVIM_MARK_EXTENDED_DEFS_H

#include "nvim/pos.h"  // for colnr_T
#include "nvim/map.h"  // for uint64_t
#include "nvim/lib/kbtree.h"
#include "nvim/lib/kvec.h"

struct ExtmarkLine;

typedef struct Extmark
{
  uint64_t ns_id;
  uint64_t mark_id;
  struct ExtmarkLine *line;
  colnr_T col;
} Extmark;


// We only need to compare columns as rows are stored in a different tree.
// Marks are ordered by: position, namespace, mark_id
// This improves moving marks but slows down all other use cases (searches)
static inline int extmark_cmp(Extmark a, Extmark b)
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
KBTREE_INIT(markitems, Extmark, markitems_cmp, 10)

typedef struct ExtmarkLine
{
  linenr_T lnum;
  kbtree_t(markitems) items;
} ExtmarkLine;

#define EXTMARKLINE_CMP(a, b) (kb_generic_cmp((a)->lnum, (b)->lnum))
KBTREE_INIT(extmarklines, ExtmarkLine *, EXTMARKLINE_CMP, 10)


typedef struct undo_object ExtmarkUndoObject;
typedef kvec_t(ExtmarkUndoObject) extmark_undo_vec_t;


#endif  // NVIM_MARK_EXTENDED_DEFS_H
