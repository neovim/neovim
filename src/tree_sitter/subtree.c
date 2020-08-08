#include <assert.h>
#include <ctype.h>
#include <limits.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include "./alloc.h"
#include "./atomic.h"
#include "./subtree.h"
#include "./length.h"
#include "./language.h"
#include "./error_costs.h"
#include <stddef.h>

typedef struct {
  Length start;
  Length old_end;
  Length new_end;
} Edit;

#define TS_MAX_INLINE_TREE_LENGTH UINT8_MAX
#define TS_MAX_TREE_POOL_SIZE 32

static const ExternalScannerState empty_state = {{.short_data = {0}}, .length = 0};

// ExternalScannerState

void ts_external_scanner_state_init(ExternalScannerState *self, const char *data, unsigned length) {
  self->length = length;
  if (length > sizeof(self->short_data)) {
    self->long_data = ts_malloc(length);
    memcpy(self->long_data, data, length);
  } else {
    memcpy(self->short_data, data, length);
  }
}

ExternalScannerState ts_external_scanner_state_copy(const ExternalScannerState *self) {
  ExternalScannerState result = *self;
  if (self->length > sizeof(self->short_data)) {
    result.long_data = ts_malloc(self->length);
    memcpy(result.long_data, self->long_data, self->length);
  }
  return result;
}

void ts_external_scanner_state_delete(ExternalScannerState *self) {
  if (self->length > sizeof(self->short_data)) {
    ts_free(self->long_data);
  }
}

const char *ts_external_scanner_state_data(const ExternalScannerState *self) {
  if (self->length > sizeof(self->short_data)) {
    return self->long_data;
  } else {
    return self->short_data;
  }
}

bool ts_external_scanner_state_eq(const ExternalScannerState *a, const ExternalScannerState *b) {
  return a == b || (
    a->length == b->length &&
    !memcmp(ts_external_scanner_state_data(a), ts_external_scanner_state_data(b), a->length)
  );
}

// SubtreeArray

void ts_subtree_array_copy(SubtreeArray self, SubtreeArray *dest) {
  dest->size = self.size;
  dest->capacity = self.capacity;
  dest->contents = self.contents;
  if (self.capacity > 0) {
    dest->contents = ts_calloc(self.capacity, sizeof(Subtree));
    memcpy(dest->contents, self.contents, self.size * sizeof(Subtree));
    for (uint32_t i = 0; i < self.size; i++) {
      ts_subtree_retain(dest->contents[i]);
    }
  }
}

void ts_subtree_array_delete(SubtreePool *pool, SubtreeArray *self) {
  for (uint32_t i = 0; i < self->size; i++) {
    ts_subtree_release(pool, self->contents[i]);
  }
  array_delete(self);
}

SubtreeArray ts_subtree_array_remove_trailing_extras(SubtreeArray *self) {
  SubtreeArray result = array_new();

  uint32_t i = self->size - 1;
  for (; i + 1 > 0; i--) {
    Subtree child = self->contents[i];
    if (!ts_subtree_extra(child)) break;
    array_push(&result, child);
  }

  self->size = i + 1;
  ts_subtree_array_reverse(&result);
  return result;
}

void ts_subtree_array_reverse(SubtreeArray *self) {
  for (uint32_t i = 0, limit = self->size / 2; i < limit; i++) {
    size_t reverse_index = self->size - 1 - i;
    Subtree swap = self->contents[i];
    self->contents[i] = self->contents[reverse_index];
    self->contents[reverse_index] = swap;
  }
}

// SubtreePool

SubtreePool ts_subtree_pool_new(uint32_t capacity) {
  SubtreePool self = {array_new(), array_new()};
  array_reserve(&self.free_trees, capacity);
  return self;
}

void ts_subtree_pool_delete(SubtreePool *self) {
  if (self->free_trees.contents) {
    for (unsigned i = 0; i < self->free_trees.size; i++) {
      ts_free(self->free_trees.contents[i].ptr);
    }
    array_delete(&self->free_trees);
  }
  if (self->tree_stack.contents) array_delete(&self->tree_stack);
}

static SubtreeHeapData *ts_subtree_pool_allocate(SubtreePool *self) {
  if (self->free_trees.size > 0) {
    return array_pop(&self->free_trees).ptr;
  } else {
    return ts_malloc(sizeof(SubtreeHeapData));
  }
}

static void ts_subtree_pool_free(SubtreePool *self, SubtreeHeapData *tree) {
  if (self->free_trees.capacity > 0 && self->free_trees.size + 1 <= TS_MAX_TREE_POOL_SIZE) {
    array_push(&self->free_trees, (MutableSubtree) {.ptr = tree});
  } else {
    ts_free(tree);
  }
}

// Subtree

static inline bool ts_subtree_can_inline(Length padding, Length size, uint32_t lookahead_bytes) {
  return
    padding.bytes < TS_MAX_INLINE_TREE_LENGTH &&
    padding.extent.row < 16 &&
    padding.extent.column < TS_MAX_INLINE_TREE_LENGTH &&
    size.extent.row == 0 &&
    size.extent.column < TS_MAX_INLINE_TREE_LENGTH &&
    lookahead_bytes < 16;
}

Subtree ts_subtree_new_leaf(
  SubtreePool *pool, TSSymbol symbol, Length padding, Length size,
  uint32_t lookahead_bytes, TSStateId parse_state, bool has_external_tokens,
  bool is_keyword, const TSLanguage *language
) {
  TSSymbolMetadata metadata = ts_language_symbol_metadata(language, symbol);
  bool extra = symbol == ts_builtin_sym_end;

  bool is_inline = (
    symbol <= UINT8_MAX &&
    !has_external_tokens &&
    ts_subtree_can_inline(padding, size, lookahead_bytes)
  );

  if (is_inline) {
    return (Subtree) {{
      .parse_state = parse_state,
      .symbol = symbol,
      .padding_bytes = padding.bytes,
      .padding_rows = padding.extent.row,
      .padding_columns = padding.extent.column,
      .size_bytes = size.bytes,
      .lookahead_bytes = lookahead_bytes,
      .visible = metadata.visible,
      .named = metadata.named,
      .extra = extra,
      .has_changes = false,
      .is_missing = false,
      .is_keyword = is_keyword,
      .is_inline = true,
    }};
  } else {
    SubtreeHeapData *data = ts_subtree_pool_allocate(pool);
    *data = (SubtreeHeapData) {
      .ref_count = 1,
      .padding = padding,
      .size = size,
      .lookahead_bytes = lookahead_bytes,
      .error_cost = 0,
      .child_count = 0,
      .symbol = symbol,
      .parse_state = parse_state,
      .visible = metadata.visible,
      .named = metadata.named,
      .extra = extra,
      .fragile_left = false,
      .fragile_right = false,
      .has_changes = false,
      .has_external_tokens = has_external_tokens,
      .is_missing = false,
      .is_keyword = is_keyword,
      {{.first_leaf = {.symbol = 0, .parse_state = 0}}}
    };
    return (Subtree) {.ptr = data};
  }
}

void ts_subtree_set_symbol(
  MutableSubtree *self,
  TSSymbol symbol,
  const TSLanguage *language
) {
  TSSymbolMetadata metadata = ts_language_symbol_metadata(language, symbol);
  if (self->data.is_inline) {
    assert(symbol < UINT8_MAX);
    self->data.symbol = symbol;
    self->data.named = metadata.named;
    self->data.visible = metadata.visible;
  } else {
    self->ptr->symbol = symbol;
    self->ptr->named = metadata.named;
    self->ptr->visible = metadata.visible;
  }
}

Subtree ts_subtree_new_error(
  SubtreePool *pool, int32_t lookahead_char, Length padding, Length size,
  uint32_t bytes_scanned, TSStateId parse_state, const TSLanguage *language
) {
  Subtree result = ts_subtree_new_leaf(
    pool, ts_builtin_sym_error, padding, size, bytes_scanned,
    parse_state, false, false, language
  );
  SubtreeHeapData *data = (SubtreeHeapData *)result.ptr;
  data->fragile_left = true;
  data->fragile_right = true;
  data->lookahead_char = lookahead_char;
  return result;
}

MutableSubtree ts_subtree_make_mut(SubtreePool *pool, Subtree self) {
  if (self.data.is_inline) return (MutableSubtree) {self.data};
  if (self.ptr->ref_count == 1) return ts_subtree_to_mut_unsafe(self);

  SubtreeHeapData *result = ts_subtree_pool_allocate(pool);
  memcpy(result, self.ptr, sizeof(SubtreeHeapData));
  if (result->child_count > 0) {
    result->children = ts_calloc(self.ptr->child_count, sizeof(Subtree));
    memcpy(result->children, self.ptr->children, result->child_count * sizeof(Subtree));
    for (uint32_t i = 0; i < result->child_count; i++) {
      ts_subtree_retain(result->children[i]);
    }
  } else if (result->has_external_tokens) {
    result->external_scanner_state = ts_external_scanner_state_copy(&self.ptr->external_scanner_state);
  }
  result->ref_count = 1;
  ts_subtree_release(pool, self);
  return (MutableSubtree) {.ptr = result};
}

static void ts_subtree__compress(MutableSubtree self, unsigned count, const TSLanguage *language,
                                 MutableSubtreeArray *stack) {
  unsigned initial_stack_size = stack->size;

  MutableSubtree tree = self;
  TSSymbol symbol = tree.ptr->symbol;
  for (unsigned i = 0; i < count; i++) {
    if (tree.ptr->ref_count > 1 || tree.ptr->child_count < 2) break;

    MutableSubtree child = ts_subtree_to_mut_unsafe(tree.ptr->children[0]);
    if (
      child.data.is_inline ||
      child.ptr->child_count < 2 ||
      child.ptr->ref_count > 1 ||
      child.ptr->symbol != symbol
    ) break;

    MutableSubtree grandchild = ts_subtree_to_mut_unsafe(child.ptr->children[0]);
    if (
      grandchild.data.is_inline ||
      grandchild.ptr->child_count < 2 ||
      grandchild.ptr->ref_count > 1 ||
      grandchild.ptr->symbol != symbol
    ) break;

    tree.ptr->children[0] = ts_subtree_from_mut(grandchild);
    child.ptr->children[0] = grandchild.ptr->children[grandchild.ptr->child_count - 1];
    grandchild.ptr->children[grandchild.ptr->child_count - 1] = ts_subtree_from_mut(child);
    array_push(stack, tree);
    tree = grandchild;
  }

  while (stack->size > initial_stack_size) {
    tree = array_pop(stack);
    MutableSubtree child = ts_subtree_to_mut_unsafe(tree.ptr->children[0]);
    MutableSubtree grandchild = ts_subtree_to_mut_unsafe(child.ptr->children[child.ptr->child_count - 1]);
    ts_subtree_set_children(grandchild, grandchild.ptr->children, grandchild.ptr->child_count, language);
    ts_subtree_set_children(child, child.ptr->children, child.ptr->child_count, language);
    ts_subtree_set_children(tree, tree.ptr->children, tree.ptr->child_count, language);
  }
}

void ts_subtree_balance(Subtree self, SubtreePool *pool, const TSLanguage *language) {
  array_clear(&pool->tree_stack);

  if (ts_subtree_child_count(self) > 0 && self.ptr->ref_count == 1) {
    array_push(&pool->tree_stack, ts_subtree_to_mut_unsafe(self));
  }

  while (pool->tree_stack.size > 0) {
    MutableSubtree tree = array_pop(&pool->tree_stack);

    if (tree.ptr->repeat_depth > 0) {
      Subtree child1 = tree.ptr->children[0];
      Subtree child2 = tree.ptr->children[tree.ptr->child_count - 1];
      long repeat_delta = (long)ts_subtree_repeat_depth(child1) - (long)ts_subtree_repeat_depth(child2);
      if (repeat_delta > 0) {
        unsigned n = repeat_delta;
        for (unsigned i = n / 2; i > 0; i /= 2) {
          ts_subtree__compress(tree, i, language, &pool->tree_stack);
          n -= i;
        }
      }
    }

    for (uint32_t i = 0; i < tree.ptr->child_count; i++) {
      Subtree child = tree.ptr->children[i];
      if (ts_subtree_child_count(child) > 0 && child.ptr->ref_count == 1) {
        array_push(&pool->tree_stack, ts_subtree_to_mut_unsafe(child));
      }
    }
  }
}

void ts_subtree_set_children(
  MutableSubtree self, Subtree *children, uint32_t child_count, const TSLanguage *language
) {
  assert(!self.data.is_inline);

  if (self.ptr->child_count > 0 && children != self.ptr->children) {
    ts_free(self.ptr->children);
  }

  self.ptr->child_count = child_count;
  self.ptr->children = children;
  self.ptr->named_child_count = 0;
  self.ptr->visible_child_count = 0;
  self.ptr->error_cost = 0;
  self.ptr->repeat_depth = 0;
  self.ptr->node_count = 1;
  self.ptr->has_external_tokens = false;
  self.ptr->dynamic_precedence = 0;

  uint32_t non_extra_index = 0;
  const TSSymbol *alias_sequence = ts_language_alias_sequence(language, self.ptr->production_id);
  uint32_t lookahead_end_byte = 0;

  for (uint32_t i = 0; i < self.ptr->child_count; i++) {
    Subtree child = self.ptr->children[i];

    if (i == 0) {
      self.ptr->padding = ts_subtree_padding(child);
      self.ptr->size = ts_subtree_size(child);
    } else {
      self.ptr->size = length_add(self.ptr->size, ts_subtree_total_size(child));
    }

    uint32_t child_lookahead_end_byte =
      self.ptr->padding.bytes +
      self.ptr->size.bytes +
      ts_subtree_lookahead_bytes(child);
    if (child_lookahead_end_byte > lookahead_end_byte) lookahead_end_byte = child_lookahead_end_byte;

    if (ts_subtree_symbol(child) != ts_builtin_sym_error_repeat) {
      self.ptr->error_cost += ts_subtree_error_cost(child);
    }

    self.ptr->dynamic_precedence += ts_subtree_dynamic_precedence(child);
    self.ptr->node_count += ts_subtree_node_count(child);

    if (alias_sequence && alias_sequence[non_extra_index] != 0 && !ts_subtree_extra(child)) {
      self.ptr->visible_child_count++;
      if (ts_language_symbol_metadata(language, alias_sequence[non_extra_index]).named) {
        self.ptr->named_child_count++;
      }
    } else if (ts_subtree_visible(child)) {
      self.ptr->visible_child_count++;
      if (ts_subtree_named(child)) self.ptr->named_child_count++;
    } else if (ts_subtree_child_count(child) > 0) {
      self.ptr->visible_child_count += child.ptr->visible_child_count;
      self.ptr->named_child_count += child.ptr->named_child_count;
    }

    if (ts_subtree_has_external_tokens(child)) self.ptr->has_external_tokens = true;

    if (ts_subtree_is_error(child)) {
      self.ptr->fragile_left = self.ptr->fragile_right = true;
      self.ptr->parse_state = TS_TREE_STATE_NONE;
    }

    if (!ts_subtree_extra(child)) non_extra_index++;
  }

  self.ptr->lookahead_bytes = lookahead_end_byte - self.ptr->size.bytes - self.ptr->padding.bytes;

  if (self.ptr->symbol == ts_builtin_sym_error || self.ptr->symbol == ts_builtin_sym_error_repeat) {
    self.ptr->error_cost +=
      ERROR_COST_PER_RECOVERY +
      ERROR_COST_PER_SKIPPED_CHAR * self.ptr->size.bytes +
      ERROR_COST_PER_SKIPPED_LINE * self.ptr->size.extent.row;
    for (uint32_t i = 0; i < self.ptr->child_count; i++) {
      Subtree child = self.ptr->children[i];
      uint32_t grandchild_count = ts_subtree_child_count(child);
      if (ts_subtree_extra(child)) continue;
      if (ts_subtree_is_error(child) && grandchild_count == 0) continue;
      if (ts_subtree_visible(child)) {
        self.ptr->error_cost += ERROR_COST_PER_SKIPPED_TREE;
      } else if (grandchild_count > 0) {
        self.ptr->error_cost += ERROR_COST_PER_SKIPPED_TREE * child.ptr->visible_child_count;
      }
    }
  }

  if (self.ptr->child_count > 0) {
    Subtree first_child = self.ptr->children[0];
    Subtree last_child = self.ptr->children[self.ptr->child_count - 1];

    self.ptr->first_leaf.symbol = ts_subtree_leaf_symbol(first_child);
    self.ptr->first_leaf.parse_state = ts_subtree_leaf_parse_state(first_child);

    if (ts_subtree_fragile_left(first_child)) self.ptr->fragile_left = true;
    if (ts_subtree_fragile_right(last_child)) self.ptr->fragile_right = true;

    if (
      self.ptr->child_count >= 2 &&
      !self.ptr->visible &&
      !self.ptr->named &&
      ts_subtree_symbol(first_child) == self.ptr->symbol
    ) {
      if (ts_subtree_repeat_depth(first_child) > ts_subtree_repeat_depth(last_child)) {
        self.ptr->repeat_depth = ts_subtree_repeat_depth(first_child) + 1;
      } else {
        self.ptr->repeat_depth = ts_subtree_repeat_depth(last_child) + 1;
      }
    }
  }
}

MutableSubtree ts_subtree_new_node(SubtreePool *pool, TSSymbol symbol,
                                   SubtreeArray *children, unsigned production_id,
                                   const TSLanguage *language) {
  TSSymbolMetadata metadata = ts_language_symbol_metadata(language, symbol);
  bool fragile = symbol == ts_builtin_sym_error || symbol == ts_builtin_sym_error_repeat;
  SubtreeHeapData *data = ts_subtree_pool_allocate(pool);
  *data = (SubtreeHeapData) {
    .ref_count = 1,
    .symbol = symbol,
    .visible = metadata.visible,
    .named = metadata.named,
    .has_changes = false,
    .fragile_left = fragile,
    .fragile_right = fragile,
    .is_keyword = false,
    {{
      .node_count = 0,
      .production_id = production_id,
      .first_leaf = {.symbol = 0, .parse_state = 0},
    }}
  };
  MutableSubtree result = {.ptr = data};
  ts_subtree_set_children(result, children->contents, children->size, language);
  return result;
}

Subtree ts_subtree_new_error_node(SubtreePool *pool, SubtreeArray *children,
                                  bool extra, const TSLanguage *language) {
  MutableSubtree result = ts_subtree_new_node(
    pool, ts_builtin_sym_error, children, 0, language
  );
  result.ptr->extra = extra;
  return ts_subtree_from_mut(result);
}

Subtree ts_subtree_new_missing_leaf(SubtreePool *pool, TSSymbol symbol, Length padding,
                                    const TSLanguage *language) {
  Subtree result = ts_subtree_new_leaf(
    pool, symbol, padding, length_zero(), 0,
    0, false, false, language
  );

  if (result.data.is_inline) {
    result.data.is_missing = true;
  } else {
    ((SubtreeHeapData *)result.ptr)->is_missing = true;
  }

  return result;
}

void ts_subtree_retain(Subtree self) {
  if (self.data.is_inline) return;
  assert(self.ptr->ref_count > 0);
  atomic_inc((volatile uint32_t *)&self.ptr->ref_count);
  assert(self.ptr->ref_count != 0);
}

void ts_subtree_release(SubtreePool *pool, Subtree self) {
  if (self.data.is_inline) return;
  array_clear(&pool->tree_stack);

  assert(self.ptr->ref_count > 0);
  if (atomic_dec((volatile uint32_t *)&self.ptr->ref_count) == 0) {
    array_push(&pool->tree_stack, ts_subtree_to_mut_unsafe(self));
  }

  while (pool->tree_stack.size > 0) {
    MutableSubtree tree = array_pop(&pool->tree_stack);
    if (tree.ptr->child_count > 0) {
      for (uint32_t i = 0; i < tree.ptr->child_count; i++) {
        Subtree child = tree.ptr->children[i];
        if (child.data.is_inline) continue;
        assert(child.ptr->ref_count > 0);
        if (atomic_dec((volatile uint32_t *)&child.ptr->ref_count) == 0) {
          array_push(&pool->tree_stack, ts_subtree_to_mut_unsafe(child));
        }
      }
      ts_free(tree.ptr->children);
    } else if (tree.ptr->has_external_tokens) {
      ts_external_scanner_state_delete(&tree.ptr->external_scanner_state);
    }
    ts_subtree_pool_free(pool, tree.ptr);
  }
}

bool ts_subtree_eq(Subtree self, Subtree other) {
  if (self.data.is_inline || other.data.is_inline) {
    return memcmp(&self, &other, sizeof(SubtreeInlineData)) == 0;
  }

  if (self.ptr) {
    if (!other.ptr) return false;
  } else {
    return !other.ptr;
  }

  if (self.ptr->symbol != other.ptr->symbol) return false;
  if (self.ptr->visible != other.ptr->visible) return false;
  if (self.ptr->named != other.ptr->named) return false;
  if (self.ptr->padding.bytes != other.ptr->padding.bytes) return false;
  if (self.ptr->size.bytes != other.ptr->size.bytes) return false;
  if (self.ptr->symbol == ts_builtin_sym_error) return self.ptr->lookahead_char == other.ptr->lookahead_char;
  if (self.ptr->child_count != other.ptr->child_count) return false;
  if (self.ptr->child_count > 0) {
    if (self.ptr->visible_child_count != other.ptr->visible_child_count) return false;
    if (self.ptr->named_child_count != other.ptr->named_child_count) return false;

    for (uint32_t i = 0; i < self.ptr->child_count; i++) {
      if (!ts_subtree_eq(self.ptr->children[i], other.ptr->children[i])) {
        return false;
      }
    }
  }
  return true;
}

int ts_subtree_compare(Subtree left, Subtree right) {
  if (ts_subtree_symbol(left) < ts_subtree_symbol(right)) return -1;
  if (ts_subtree_symbol(right) < ts_subtree_symbol(left)) return 1;
  if (ts_subtree_child_count(left) < ts_subtree_child_count(right)) return -1;
  if (ts_subtree_child_count(right) < ts_subtree_child_count(left)) return 1;
  for (uint32_t i = 0, n = ts_subtree_child_count(left); i < n; i++) {
    Subtree left_child = left.ptr->children[i];
    Subtree right_child = right.ptr->children[i];
    switch (ts_subtree_compare(left_child, right_child)) {
      case -1: return -1;
      case 1: return 1;
      default: break;
    }
  }
  return 0;
}

static inline void ts_subtree_set_has_changes(MutableSubtree *self) {
  if (self->data.is_inline) {
    self->data.has_changes = true;
  } else {
    self->ptr->has_changes = true;
  }
}

Subtree ts_subtree_edit(Subtree self, const TSInputEdit *edit, SubtreePool *pool) {
  typedef struct {
    Subtree *tree;
    Edit edit;
  } StackEntry;

  Array(StackEntry) stack = array_new();
  array_push(&stack, ((StackEntry) {
    .tree = &self,
    .edit = (Edit) {
      .start = {edit->start_byte, edit->start_point},
      .old_end = {edit->old_end_byte, edit->old_end_point},
      .new_end = {edit->new_end_byte, edit->new_end_point},
    },
  }));

  while (stack.size) {
    StackEntry entry = array_pop(&stack);
    Edit edit = entry.edit;
    bool is_noop = edit.old_end.bytes == edit.start.bytes && edit.new_end.bytes == edit.start.bytes;
    bool is_pure_insertion = edit.old_end.bytes == edit.start.bytes;

    Length size = ts_subtree_size(*entry.tree);
    Length padding = ts_subtree_padding(*entry.tree);
    uint32_t lookahead_bytes = ts_subtree_lookahead_bytes(*entry.tree);
    uint32_t end_byte = padding.bytes + size.bytes + lookahead_bytes;
    if (edit.start.bytes > end_byte || (is_noop && edit.start.bytes == end_byte)) continue;

    // If the edit is entirely within the space before this subtree, then shift this
    // subtree over according to the edit without changing its size.
    if (edit.old_end.bytes <= padding.bytes) {
      padding = length_add(edit.new_end, length_sub(padding, edit.old_end));
    }

    // If the edit starts in the space before this subtree and extends into this subtree,
    // shrink the subtree's content to compensate for the change in the space before it.
    else if (edit.start.bytes < padding.bytes) {
      size = length_sub(size, length_sub(edit.old_end, padding));
      padding = edit.new_end;
    }

    // If the edit is a pure insertion right at the start of the subtree,
    // shift the subtree over according to the insertion.
    else if (edit.start.bytes == padding.bytes && is_pure_insertion) {
      padding = edit.new_end;
    }

    // If the edit is within this subtree, resize the subtree to reflect the edit.
    else {
      uint32_t total_bytes = padding.bytes + size.bytes;
      if (edit.start.bytes < total_bytes ||
         (edit.start.bytes == total_bytes && is_pure_insertion)) {
        size = length_add(
          length_sub(edit.new_end, padding),
          length_sub(size, length_sub(edit.old_end, padding))
        );
      }
    }

    MutableSubtree result = ts_subtree_make_mut(pool, *entry.tree);

    if (result.data.is_inline) {
      if (ts_subtree_can_inline(padding, size, lookahead_bytes)) {
        result.data.padding_bytes = padding.bytes;
        result.data.padding_rows = padding.extent.row;
        result.data.padding_columns = padding.extent.column;
        result.data.size_bytes = size.bytes;
      } else {
        SubtreeHeapData *data = ts_subtree_pool_allocate(pool);
        data->ref_count = 1;
        data->padding = padding;
        data->size = size;
        data->lookahead_bytes = lookahead_bytes;
        data->error_cost = 0;
        data->child_count = 0;
        data->symbol = result.data.symbol;
        data->parse_state = result.data.parse_state;
        data->visible = result.data.visible;
        data->named = result.data.named;
        data->extra = result.data.extra;
        data->fragile_left = false;
        data->fragile_right = false;
        data->has_changes = false;
        data->has_external_tokens = false;
        data->is_missing = result.data.is_missing;
        data->is_keyword = result.data.is_keyword;
        result.ptr = data;
      }
    } else {
      result.ptr->padding = padding;
      result.ptr->size = size;
    }

    ts_subtree_set_has_changes(&result);
    *entry.tree = ts_subtree_from_mut(result);

    Length child_left, child_right = length_zero();
    for (uint32_t i = 0, n = ts_subtree_child_count(*entry.tree); i < n; i++) {
      Subtree *child = &result.ptr->children[i];
      Length child_size = ts_subtree_total_size(*child);
      child_left = child_right;
      child_right = length_add(child_left, child_size);

      // If this child ends before the edit, it is not affected.
      if (child_right.bytes + ts_subtree_lookahead_bytes(*child) < edit.start.bytes) continue;

      // If this child starts after the edit, then we're done processing children.
      if (child_left.bytes > edit.old_end.bytes ||
          (child_left.bytes == edit.old_end.bytes && child_size.bytes > 0 && i > 0)) break;

      // Transform edit into the child's coordinate space.
      Edit child_edit = {
        .start = length_sub(edit.start, child_left),
        .old_end = length_sub(edit.old_end, child_left),
        .new_end = length_sub(edit.new_end, child_left),
      };

      // Clamp child_edit to the child's bounds.
      if (edit.start.bytes < child_left.bytes) child_edit.start = length_zero();
      if (edit.old_end.bytes < child_left.bytes) child_edit.old_end = length_zero();
      if (edit.new_end.bytes < child_left.bytes) child_edit.new_end = length_zero();
      if (edit.old_end.bytes > child_right.bytes) child_edit.old_end = child_size;

      // Interpret all inserted text as applying to the *first* child that touches the edit.
      // Subsequent children are only never have any text inserted into them; they are only
      // shrunk to compensate for the edit.
      if (child_right.bytes > edit.start.bytes ||
          (child_right.bytes == edit.start.bytes && is_pure_insertion)) {
        edit.new_end = edit.start;
      }

      // Children that occur before the edit are not reshaped by the edit.
      else {
        child_edit.old_end = child_edit.start;
        child_edit.new_end = child_edit.start;
      }

      // Queue processing of this child's subtree.
      array_push(&stack, ((StackEntry) {
        .tree = child,
        .edit = child_edit,
      }));
    }
  }

  array_delete(&stack);
  return self;
}

Subtree ts_subtree_last_external_token(Subtree tree) {
  if (!ts_subtree_has_external_tokens(tree)) return NULL_SUBTREE;
  while (tree.ptr->child_count > 0) {
    for (uint32_t i = tree.ptr->child_count - 1; i + 1 > 0; i--) {
      Subtree child = tree.ptr->children[i];
      if (ts_subtree_has_external_tokens(child)) {
        tree = child;
        break;
      }
    }
  }
  return tree;
}

static size_t ts_subtree__write_char_to_string(char *s, size_t n, int32_t c) {
  if (c == -1)
    return snprintf(s, n, "INVALID");
  else if (c == '\0')
    return snprintf(s, n, "'\\0'");
  else if (c == '\n')
    return snprintf(s, n, "'\\n'");
  else if (c == '\t')
    return snprintf(s, n, "'\\t'");
  else if (c == '\r')
    return snprintf(s, n, "'\\r'");
  else if (0 < c && c < 128 && isprint(c))
    return snprintf(s, n, "'%c'", c);
  else
    return snprintf(s, n, "%d", c);
}

static void ts_subtree__write_dot_string(FILE *f, const char *string) {
  for (const char *c = string; *c; c++) {
    if (*c == '"') {
      fputs("\\\"", f);
    } else if (*c == '\n') {
      fputs("\\n", f);
    } else {
      fputc(*c, f);
    }
  }
}

static const char *ROOT_FIELD = "__ROOT__";

static size_t ts_subtree__write_to_string(
  Subtree self, char *string, size_t limit,
  const TSLanguage *language, bool include_all,
  TSSymbol alias_symbol, bool alias_is_named, const char *field_name
) {
  if (!self.ptr) return snprintf(string, limit, "(NULL)");

  char *cursor = string;
  char **writer = (limit > 0) ? &cursor : &string;
  bool is_root = field_name == ROOT_FIELD;
  bool is_visible =
    include_all ||
    ts_subtree_missing(self) ||
    (
      alias_symbol
        ? alias_is_named
        : ts_subtree_visible(self) && ts_subtree_named(self)
    );

  if (is_visible) {
    if (!is_root) {
      cursor += snprintf(*writer, limit, " ");
      if (field_name) {
        cursor += snprintf(*writer, limit, "%s: ", field_name);
      }
    }

    if (ts_subtree_is_error(self) && ts_subtree_child_count(self) == 0 && self.ptr->size.bytes > 0) {
      cursor += snprintf(*writer, limit, "(UNEXPECTED ");
      cursor += ts_subtree__write_char_to_string(*writer, limit, self.ptr->lookahead_char);
    } else {
      TSSymbol symbol = alias_symbol ? alias_symbol : ts_subtree_symbol(self);
      const char *symbol_name = ts_language_symbol_name(language, symbol);
      if (ts_subtree_missing(self)) {
        cursor += snprintf(*writer, limit, "(MISSING ");
        if (alias_is_named || ts_subtree_named(self)) {
          cursor += snprintf(*writer, limit, "%s", symbol_name);
        } else {
          cursor += snprintf(*writer, limit, "\"%s\"", symbol_name);
        }
      } else {
        cursor += snprintf(*writer, limit, "(%s", symbol_name);
      }
    }
  } else if (is_root) {
    TSSymbol symbol = ts_subtree_symbol(self);
    const char *symbol_name = ts_language_symbol_name(language, symbol);
    cursor += snprintf(*writer, limit, "(\"%s\")", symbol_name);
  }

  if (ts_subtree_child_count(self)) {
    const TSSymbol *alias_sequence = ts_language_alias_sequence(language, self.ptr->production_id);
    const TSFieldMapEntry *field_map, *field_map_end;
    ts_language_field_map(
      language,
      self.ptr->production_id,
      &field_map,
      &field_map_end
    );

    uint32_t structural_child_index = 0;
    for (uint32_t i = 0; i < self.ptr->child_count; i++) {
      Subtree child = self.ptr->children[i];
      if (ts_subtree_extra(child)) {
        cursor += ts_subtree__write_to_string(
          child, *writer, limit,
          language, include_all,
          0, false, NULL
        );
      } else {
        TSSymbol alias_symbol = alias_sequence
          ? alias_sequence[structural_child_index]
          : 0;
        bool alias_is_named = alias_symbol
          ? ts_language_symbol_metadata(language, alias_symbol).named
          : false;

        const char *child_field_name = is_visible ? NULL : field_name;
        for (const TSFieldMapEntry *i = field_map; i < field_map_end; i++) {
          if (!i->inherited && i->child_index == structural_child_index) {
            child_field_name = language->field_names[i->field_id];
            break;
          }
        }

        cursor += ts_subtree__write_to_string(
          child, *writer, limit,
          language, include_all,
          alias_symbol, alias_is_named, child_field_name
        );
        structural_child_index++;
      }
    }
  }

  if (is_visible) cursor += snprintf(*writer, limit, ")");

  return cursor - string;
}

char *ts_subtree_string(
  Subtree self,
  const TSLanguage *language,
  bool include_all
) {
  char scratch_string[1];
  size_t size = ts_subtree__write_to_string(
    self, scratch_string, 0,
    language, include_all,
    0, false, ROOT_FIELD
  ) + 1;
  char *result = malloc(size * sizeof(char));
  ts_subtree__write_to_string(
    self, result, size,
    language, include_all,
    0, false, ROOT_FIELD
  );
  return result;
}

void ts_subtree__print_dot_graph(const Subtree *self, uint32_t start_offset,
                                 const TSLanguage *language, TSSymbol alias_symbol,
                                 FILE *f) {
  TSSymbol subtree_symbol = ts_subtree_symbol(*self);
  TSSymbol symbol = alias_symbol ? alias_symbol : subtree_symbol;
  uint32_t end_offset = start_offset + ts_subtree_total_bytes(*self);
  fprintf(f, "tree_%p [label=\"", self);
  ts_subtree__write_dot_string(f, ts_language_symbol_name(language, symbol));
  fprintf(f, "\"");

  if (ts_subtree_child_count(*self) == 0) fprintf(f, ", shape=plaintext");
  if (ts_subtree_extra(*self)) fprintf(f, ", fontcolor=gray");

  fprintf(f, ", tooltip=\""
    "range: %u - %u\n"
    "state: %d\n"
    "error-cost: %u\n"
    "has-changes: %u\n"
    "repeat-depth: %u\n"
    "lookahead-bytes: %u",
    start_offset, end_offset,
    ts_subtree_parse_state(*self),
    ts_subtree_error_cost(*self),
    ts_subtree_has_changes(*self),
    ts_subtree_repeat_depth(*self),
    ts_subtree_lookahead_bytes(*self)
  );

  if (ts_subtree_is_error(*self) && ts_subtree_child_count(*self) == 0) {
    fprintf(f, "\ncharacter: '%c'", self->ptr->lookahead_char);
  }

  fprintf(f, "\"]\n");

  uint32_t child_start_offset = start_offset;
  uint32_t child_info_offset =
    language->max_alias_sequence_length *
    ts_subtree_production_id(*self);
  for (uint32_t i = 0, n = ts_subtree_child_count(*self); i < n; i++) {
    const Subtree *child = &self->ptr->children[i];
    TSSymbol alias_symbol = 0;
    if (!ts_subtree_extra(*child) && child_info_offset) {
      alias_symbol = language->alias_sequences[child_info_offset];
      child_info_offset++;
    }
    ts_subtree__print_dot_graph(child, child_start_offset, language, alias_symbol, f);
    fprintf(f, "tree_%p -> tree_%p [tooltip=%u]\n", self, child, i);
    child_start_offset += ts_subtree_total_bytes(*child);
  }
}

void ts_subtree_print_dot_graph(Subtree self, const TSLanguage *language, FILE *f) {
  fprintf(f, "digraph tree {\n");
  fprintf(f, "edge [arrowhead=none]\n");
  ts_subtree__print_dot_graph(&self, 0, language, 0, f);
  fprintf(f, "}\n");
}

bool ts_subtree_external_scanner_state_eq(Subtree self, Subtree other) {
  const ExternalScannerState *state1 = &empty_state;
  const ExternalScannerState *state2 = &empty_state;
  if (self.ptr && ts_subtree_has_external_tokens(self) && !self.ptr->child_count) {
    state1 = &self.ptr->external_scanner_state;
  }
  if (other.ptr && ts_subtree_has_external_tokens(other) && !other.ptr->child_count) {
    state2 = &other.ptr->external_scanner_state;
  }
  return ts_external_scanner_state_eq(state1, state2);
}
