#ifndef TREE_SITTER_TREE_H_
#define TREE_SITTER_TREE_H_

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  const Subtree *child;
  const Subtree *parent;
  Length position;
  TSSymbol alias_symbol;
} ParentCacheEntry;

struct TSTree {
  Subtree root;
  const TSLanguage *language;
  ParentCacheEntry *parent_cache;
  uint32_t parent_cache_start;
  uint32_t parent_cache_size;
  TSRange *included_ranges;
  unsigned included_range_count;
};

TSTree *ts_tree_new(Subtree root, const TSLanguage *language, const TSRange *, unsigned);
TSNode ts_node_new(const TSTree *, const Subtree *, Length, TSSymbol);
TSNode ts_tree_get_cached_parent(const TSTree *, const TSNode *);
void ts_tree_set_cached_parent(const TSTree *, const TSNode *, const TSNode *);

#ifdef __cplusplus
}
#endif

#endif  // TREE_SITTER_TREE_H_
