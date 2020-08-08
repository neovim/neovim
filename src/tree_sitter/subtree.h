#ifndef TREE_SITTER_SUBTREE_H_
#define TREE_SITTER_SUBTREE_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include "./length.h"
#include "./array.h"
#include "./error_costs.h"
#include "tree_sitter/api.h"
#include "tree_sitter/parser.h"

static const TSStateId TS_TREE_STATE_NONE = USHRT_MAX;
#define NULL_SUBTREE ((Subtree) {.ptr = NULL})

typedef union Subtree Subtree;
typedef union MutableSubtree MutableSubtree;

typedef struct {
  union {
    char *long_data;
    char short_data[24];
  };
  uint32_t length;
} ExternalScannerState;

typedef struct {
  bool is_inline : 1;
  bool visible : 1;
  bool named : 1;
  bool extra : 1;
  bool has_changes : 1;
  bool is_missing : 1;
  bool is_keyword : 1;
  uint8_t symbol;
  uint8_t padding_bytes;
  uint8_t size_bytes;
  uint8_t padding_columns;
  uint8_t padding_rows : 4;
  uint8_t lookahead_bytes : 4;
  uint16_t parse_state;
} SubtreeInlineData;

typedef struct {
  volatile uint32_t ref_count;
  Length padding;
  Length size;
  uint32_t lookahead_bytes;
  uint32_t error_cost;
  uint32_t child_count;
  TSSymbol symbol;
  TSStateId parse_state;

  bool visible : 1;
  bool named : 1;
  bool extra : 1;
  bool fragile_left : 1;
  bool fragile_right : 1;
  bool has_changes : 1;
  bool has_external_tokens : 1;
  bool is_missing : 1;
  bool is_keyword : 1;

  union {
    // Non-terminal subtrees (`child_count > 0`)
    struct {
      Subtree *children;
      uint32_t visible_child_count;
      uint32_t named_child_count;
      uint32_t node_count;
      uint32_t repeat_depth;
      int32_t dynamic_precedence;
      uint16_t production_id;
      struct {
        TSSymbol symbol;
        TSStateId parse_state;
      } first_leaf;
    };

    // External terminal subtrees (`child_count == 0 && has_external_tokens`)
    ExternalScannerState external_scanner_state;

    // Error terminal subtrees (`child_count == 0 && symbol == ts_builtin_sym_error`)
    int32_t lookahead_char;
  };
} SubtreeHeapData;

union Subtree {
  SubtreeInlineData data;
  const SubtreeHeapData *ptr;
};

union MutableSubtree {
  SubtreeInlineData data;
  SubtreeHeapData *ptr;
};

typedef Array(Subtree) SubtreeArray;
typedef Array(MutableSubtree) MutableSubtreeArray;

typedef struct {
  MutableSubtreeArray free_trees;
  MutableSubtreeArray tree_stack;
} SubtreePool;

void ts_external_scanner_state_init(ExternalScannerState *, const char *, unsigned);
const char *ts_external_scanner_state_data(const ExternalScannerState *);

void ts_subtree_array_copy(SubtreeArray, SubtreeArray *);
void ts_subtree_array_delete(SubtreePool *, SubtreeArray *);
SubtreeArray ts_subtree_array_remove_trailing_extras(SubtreeArray *);
void ts_subtree_array_reverse(SubtreeArray *);

SubtreePool ts_subtree_pool_new(uint32_t capacity);
void ts_subtree_pool_delete(SubtreePool *);

Subtree ts_subtree_new_leaf(
  SubtreePool *, TSSymbol, Length, Length, uint32_t,
  TSStateId, bool, bool, const TSLanguage *
);
Subtree ts_subtree_new_error(
  SubtreePool *, int32_t, Length, Length, uint32_t, TSStateId, const TSLanguage *
);
MutableSubtree ts_subtree_new_node(SubtreePool *, TSSymbol, SubtreeArray *, unsigned, const TSLanguage *);
Subtree ts_subtree_new_error_node(SubtreePool *, SubtreeArray *, bool, const TSLanguage *);
Subtree ts_subtree_new_missing_leaf(SubtreePool *, TSSymbol, Length, const TSLanguage *);
MutableSubtree ts_subtree_make_mut(SubtreePool *, Subtree);
void ts_subtree_retain(Subtree);
void ts_subtree_release(SubtreePool *, Subtree);
bool ts_subtree_eq(Subtree, Subtree);
int ts_subtree_compare(Subtree, Subtree);
void ts_subtree_set_symbol(MutableSubtree *, TSSymbol, const TSLanguage *);
void ts_subtree_set_children(MutableSubtree, Subtree *, uint32_t, const TSLanguage *);
void ts_subtree_balance(Subtree, SubtreePool *, const TSLanguage *);
Subtree ts_subtree_edit(Subtree, const TSInputEdit *edit, SubtreePool *);
char *ts_subtree_string(Subtree, const TSLanguage *, bool include_all);
void ts_subtree_print_dot_graph(Subtree, const TSLanguage *, FILE *);
Subtree ts_subtree_last_external_token(Subtree);
bool ts_subtree_external_scanner_state_eq(Subtree, Subtree);

#define SUBTREE_GET(self, name) (self.data.is_inline ? self.data.name : self.ptr->name)

static inline TSSymbol ts_subtree_symbol(Subtree self) { return SUBTREE_GET(self, symbol); }
static inline bool ts_subtree_visible(Subtree self) { return SUBTREE_GET(self, visible); }
static inline bool ts_subtree_named(Subtree self) { return SUBTREE_GET(self, named); }
static inline bool ts_subtree_extra(Subtree self) { return SUBTREE_GET(self, extra); }
static inline bool ts_subtree_has_changes(Subtree self) { return SUBTREE_GET(self, has_changes); }
static inline bool ts_subtree_missing(Subtree self) { return SUBTREE_GET(self, is_missing); }
static inline bool ts_subtree_is_keyword(Subtree self) { return SUBTREE_GET(self, is_keyword); }
static inline TSStateId ts_subtree_parse_state(Subtree self) { return SUBTREE_GET(self, parse_state); }
static inline uint32_t ts_subtree_lookahead_bytes(Subtree self) { return SUBTREE_GET(self, lookahead_bytes); }

#undef SUBTREE_GET

static inline void ts_subtree_set_extra(MutableSubtree *self) {
  if (self->data.is_inline) {
    self->data.extra = true;
  } else {
    self->ptr->extra = true;
  }
}

static inline TSSymbol ts_subtree_leaf_symbol(Subtree self) {
  if (self.data.is_inline) return self.data.symbol;
  if (self.ptr->child_count == 0) return self.ptr->symbol;
  return self.ptr->first_leaf.symbol;
}

static inline TSStateId ts_subtree_leaf_parse_state(Subtree self) {
  if (self.data.is_inline) return self.data.parse_state;
  if (self.ptr->child_count == 0) return self.ptr->parse_state;
  return self.ptr->first_leaf.parse_state;
}

static inline Length ts_subtree_padding(Subtree self) {
  if (self.data.is_inline) {
    Length result = {self.data.padding_bytes, {self.data.padding_rows, self.data.padding_columns}};
    return result;
  } else {
    return self.ptr->padding;
  }
}

static inline Length ts_subtree_size(Subtree self) {
  if (self.data.is_inline) {
    Length result = {self.data.size_bytes, {0, self.data.size_bytes}};
    return result;
  } else {
    return self.ptr->size;
  }
}

static inline Length ts_subtree_total_size(Subtree self) {
  return length_add(ts_subtree_padding(self), ts_subtree_size(self));
}

static inline uint32_t ts_subtree_total_bytes(Subtree self) {
  return ts_subtree_total_size(self).bytes;
}

static inline uint32_t ts_subtree_child_count(Subtree self) {
  return self.data.is_inline ? 0 : self.ptr->child_count;
}

static inline uint32_t ts_subtree_repeat_depth(Subtree self) {
  return self.data.is_inline ? 0 : self.ptr->repeat_depth;
}

static inline uint32_t ts_subtree_node_count(Subtree self) {
  return (self.data.is_inline || self.ptr->child_count == 0) ? 1 : self.ptr->node_count;
}

static inline uint32_t ts_subtree_visible_child_count(Subtree self) {
  if (ts_subtree_child_count(self) > 0) {
    return self.ptr->visible_child_count;
  } else {
    return 0;
  }
}

static inline uint32_t ts_subtree_error_cost(Subtree self) {
  if (ts_subtree_missing(self)) {
    return ERROR_COST_PER_MISSING_TREE + ERROR_COST_PER_RECOVERY;
  } else {
    return self.data.is_inline ? 0 : self.ptr->error_cost;
  }
}

static inline int32_t ts_subtree_dynamic_precedence(Subtree self) {
  return (self.data.is_inline || self.ptr->child_count == 0) ? 0 : self.ptr->dynamic_precedence;
}

static inline uint16_t ts_subtree_production_id(Subtree self) {
  if (ts_subtree_child_count(self) > 0) {
    return self.ptr->production_id;
  } else {
    return 0;
  }
}

static inline bool ts_subtree_fragile_left(Subtree self) {
  return self.data.is_inline ? false : self.ptr->fragile_left;
}

static inline bool ts_subtree_fragile_right(Subtree self) {
  return self.data.is_inline ? false : self.ptr->fragile_right;
}

static inline bool ts_subtree_has_external_tokens(Subtree self) {
  return self.data.is_inline ? false : self.ptr->has_external_tokens;
}

static inline bool ts_subtree_is_fragile(Subtree self) {
  return self.data.is_inline ? false : (self.ptr->fragile_left || self.ptr->fragile_right);
}

static inline bool ts_subtree_is_error(Subtree self) {
  return ts_subtree_symbol(self) == ts_builtin_sym_error;
}

static inline bool ts_subtree_is_eof(Subtree self) {
  return ts_subtree_symbol(self) == ts_builtin_sym_end;
}

static inline Subtree ts_subtree_from_mut(MutableSubtree self) {
  Subtree result;
  result.data = self.data;
  return result;
}

static inline MutableSubtree ts_subtree_to_mut_unsafe(Subtree self) {
  MutableSubtree result;
  result.data = self.data;
  return result;
}

#ifdef __cplusplus
}
#endif

#endif  // TREE_SITTER_SUBTREE_H_
