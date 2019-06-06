#include <time.h>
#include <assert.h>
#include <stdio.h>
#include <limits.h>
#include <stdbool.h>
#include "tree_sitter/api.h"
#include "./alloc.h"
#include "./array.h"
#include "./atomic.h"
#include "./clock.h"
#include "./error_costs.h"
#include "./get_changed_ranges.h"
#include "./language.h"
#include "./length.h"
#include "./lexer.h"
#include "./reduce_action.h"
#include "./reusable_node.h"
#include "./stack.h"
#include "./subtree.h"
#include "./tree.h"

#define LOG(...)                                                                            \
  if (self->lexer.logger.log || self->dot_graph_file) {                                     \
    snprintf(self->lexer.debug_buffer, TREE_SITTER_SERIALIZATION_BUFFER_SIZE, __VA_ARGS__); \
    ts_parser__log(self);                                                                   \
  }

#define LOG_STACK()                                                              \
  if (self->dot_graph_file) {                                                    \
    ts_stack_print_dot_graph(self->stack, self->language, self->dot_graph_file); \
    fputs("\n\n", self->dot_graph_file);                                         \
  }

#define LOG_TREE(tree)                                                      \
  if (self->dot_graph_file) {                                               \
    ts_subtree_print_dot_graph(tree, self->language, self->dot_graph_file); \
    fputs("\n", self->dot_graph_file);                                      \
  }

#define SYM_NAME(symbol) ts_language_symbol_name(self->language, symbol)

#define TREE_NAME(tree) SYM_NAME(ts_subtree_symbol(tree))

static const unsigned MAX_VERSION_COUNT = 6;
static const unsigned MAX_VERSION_COUNT_OVERFLOW = 4;
static const unsigned MAX_SUMMARY_DEPTH = 16;
static const unsigned MAX_COST_DIFFERENCE = 16 * ERROR_COST_PER_SKIPPED_TREE;
static const unsigned OP_COUNT_PER_TIMEOUT_CHECK = 100;

typedef struct {
  Subtree token;
  Subtree last_external_token;
  uint32_t byte_index;
} TokenCache;

struct TSParser {
  Lexer lexer;
  Stack *stack;
  SubtreePool tree_pool;
  const TSLanguage *language;
  ReduceActionSet reduce_actions;
  Subtree finished_tree;
  SubtreeHeapData scratch_tree_data;
  MutableSubtree scratch_tree;
  TokenCache token_cache;
  ReusableNode reusable_node;
  void *external_scanner_payload;
  FILE *dot_graph_file;
  TSClock end_clock;
  TSDuration timeout_duration;
  unsigned accept_count;
  unsigned operation_count;
  const volatile size_t *cancellation_flag;
  bool halt_on_error;
  Subtree old_tree;
  TSRangeArray included_range_differences;
  unsigned included_range_difference_index;
};

typedef struct {
  unsigned cost;
  unsigned node_count;
  int dynamic_precedence;
  bool is_in_error;
} ErrorStatus;

typedef enum {
  ErrorComparisonTakeLeft,
  ErrorComparisonPreferLeft,
  ErrorComparisonNone,
  ErrorComparisonPreferRight,
  ErrorComparisonTakeRight,
} ErrorComparison;

typedef struct {
  const char *string;
  uint32_t length;
} TSStringInput;

// StringInput

static const char *ts_string_input_read(
  void *_self,
  uint32_t byte,
  TSPoint _,
  uint32_t *length
) {
  TSStringInput *self = (TSStringInput *)_self;
  if (byte >= self->length) {
    *length = 0;
    return "";
  } else {
    *length = self->length - byte;
    return self->string + byte;
  }
}

// Parser - Private

static void ts_parser__log(TSParser *self) {
  if (self->lexer.logger.log) {
    self->lexer.logger.log(
      self->lexer.logger.payload,
      TSLogTypeParse,
      self->lexer.debug_buffer
    );
  }

  if (self->dot_graph_file) {
    fprintf(self->dot_graph_file, "graph {\nlabel=\"");
    for (char *c = &self->lexer.debug_buffer[0]; *c != 0; c++) {
      if (*c == '"') fputc('\\', self->dot_graph_file);
      fputc(*c, self->dot_graph_file);
    }
    fprintf(self->dot_graph_file, "\"\n}\n\n");
  }
}

static bool ts_parser__breakdown_top_of_stack(
  TSParser *self,
  StackVersion version
) {
  bool did_break_down = false;
  bool pending = false;

  do {
    StackSliceArray pop = ts_stack_pop_pending(self->stack, version);
    if (!pop.size) break;

    did_break_down = true;
    pending = false;
    for (uint32_t i = 0; i < pop.size; i++) {
      StackSlice slice = pop.contents[i];
      TSStateId state = ts_stack_state(self->stack, slice.version);
      Subtree parent = *array_front(&slice.subtrees);

      for (uint32_t j = 0, n = ts_subtree_child_count(parent); j < n; j++) {
        Subtree child = parent.ptr->children[j];
        pending = ts_subtree_child_count(child) > 0;

        if (ts_subtree_is_error(child)) {
          state = ERROR_STATE;
        } else if (!ts_subtree_extra(child)) {
          state = ts_language_next_state(self->language, state, ts_subtree_symbol(child));
        }

        ts_subtree_retain(child);
        ts_stack_push(self->stack, slice.version, child, pending, state);
      }

      for (uint32_t j = 1; j < slice.subtrees.size; j++) {
        Subtree tree = slice.subtrees.contents[j];
        ts_stack_push(self->stack, slice.version, tree, false, state);
      }

      ts_subtree_release(&self->tree_pool, parent);
      array_delete(&slice.subtrees);

      LOG("breakdown_top_of_stack tree:%s", TREE_NAME(parent));
      LOG_STACK();
    }
  } while (pending);

  return did_break_down;
}

static void ts_parser__breakdown_lookahead(
  TSParser *self,
  Subtree *lookahead,
  TSStateId state,
  ReusableNode *reusable_node
) {
  bool did_descend = false;
  Subtree tree = reusable_node_tree(reusable_node);
  while (ts_subtree_child_count(tree) > 0 && ts_subtree_parse_state(tree) != state) {
    LOG("state_mismatch sym:%s", TREE_NAME(tree));
    reusable_node_descend(reusable_node);
    tree = reusable_node_tree(reusable_node);
    did_descend = true;
  }

  if (did_descend) {
    ts_subtree_release(&self->tree_pool, *lookahead);
    *lookahead = tree;
    ts_subtree_retain(*lookahead);
  }
}

static ErrorComparison ts_parser__compare_versions(
  TSParser *self,
  ErrorStatus a,
  ErrorStatus b
) {
  if (!a.is_in_error && b.is_in_error) {
    if (a.cost < b.cost) {
      return ErrorComparisonTakeLeft;
    } else {
      return ErrorComparisonPreferLeft;
    }
  }

  if (a.is_in_error && !b.is_in_error) {
    if (b.cost < a.cost) {
      return ErrorComparisonTakeRight;
    } else {
      return ErrorComparisonPreferRight;
    }
  }

  if (a.cost < b.cost) {
    if ((b.cost - a.cost) * (1 + a.node_count) > MAX_COST_DIFFERENCE) {
      return ErrorComparisonTakeLeft;
    } else {
      return ErrorComparisonPreferLeft;
    }
  }

  if (b.cost < a.cost) {
    if ((a.cost - b.cost) * (1 + b.node_count) > MAX_COST_DIFFERENCE) {
      return ErrorComparisonTakeRight;
    } else {
      return ErrorComparisonPreferRight;
    }
  }

  if (a.dynamic_precedence > b.dynamic_precedence) return ErrorComparisonPreferLeft;
  if (b.dynamic_precedence > a.dynamic_precedence) return ErrorComparisonPreferRight;
  return ErrorComparisonNone;
}

static ErrorStatus ts_parser__version_status(
  TSParser *self,
  StackVersion version
) {
  unsigned cost = ts_stack_error_cost(self->stack, version);
  bool is_paused = ts_stack_is_paused(self->stack, version);
  if (is_paused) cost += ERROR_COST_PER_SKIPPED_TREE;
  return (ErrorStatus) {
    .cost = cost,
    .node_count = ts_stack_node_count_since_error(self->stack, version),
    .dynamic_precedence = ts_stack_dynamic_precedence(self->stack, version),
    .is_in_error = is_paused || ts_stack_state(self->stack, version) == ERROR_STATE
  };
}

static bool ts_parser__better_version_exists(
  TSParser *self,
  StackVersion version,
  bool is_in_error,
  unsigned cost
) {
  if (self->finished_tree.ptr && ts_subtree_error_cost(self->finished_tree) <= cost) {
    return true;
  }

  Length position = ts_stack_position(self->stack, version);
  ErrorStatus status = {
    .cost = cost,
    .is_in_error = is_in_error,
    .dynamic_precedence = ts_stack_dynamic_precedence(self->stack, version),
    .node_count = ts_stack_node_count_since_error(self->stack, version),
  };

  for (StackVersion i = 0, n = ts_stack_version_count(self->stack); i < n; i++) {
    if (i == version ||
        !ts_stack_is_active(self->stack, i) ||
        ts_stack_position(self->stack, i).bytes < position.bytes) continue;
    ErrorStatus status_i = ts_parser__version_status(self, i);
    switch (ts_parser__compare_versions(self, status, status_i)) {
      case ErrorComparisonTakeRight:
        return true;
      case ErrorComparisonPreferRight:
        if (ts_stack_can_merge(self->stack, i, version)) return true;
      default:
        break;
    }
  }

  return false;
}

static void ts_parser__restore_external_scanner(
  TSParser *self,
  Subtree external_token
) {
  if (external_token.ptr) {
    self->language->external_scanner.deserialize(
      self->external_scanner_payload,
      ts_external_scanner_state_data(&external_token.ptr->external_scanner_state),
      external_token.ptr->external_scanner_state.length
    );
  } else {
    self->language->external_scanner.deserialize(self->external_scanner_payload, NULL, 0);
  }
}

static bool ts_parser__can_reuse_first_leaf(
  TSParser *self,
  TSStateId state,
  Subtree tree,
  TableEntry *table_entry
) {
  TSLexMode current_lex_mode = self->language->lex_modes[state];
  TSSymbol leaf_symbol = ts_subtree_leaf_symbol(tree);
  TSStateId leaf_state = ts_subtree_leaf_parse_state(tree);
  TSLexMode leaf_lex_mode = self->language->lex_modes[leaf_state];

  // If the token was created in a state with the same set of lookaheads, it is reusable.
  if (
    table_entry->action_count > 0 &&
    memcmp(&leaf_lex_mode, &current_lex_mode, sizeof(TSLexMode)) == 0 &&
    (
      leaf_symbol != self->language->keyword_capture_token ||
      (!ts_subtree_is_keyword(tree) && ts_subtree_parse_state(tree) == state)
    )
  ) return true;

  // Empty tokens are not reusable in states with different lookaheads.
  if (ts_subtree_size(tree).bytes == 0 && leaf_symbol != ts_builtin_sym_end) return false;

  // If the current state allows external tokens or other tokens that conflict with this
  // token, this token is not reusable.
  return current_lex_mode.external_lex_state == 0 && table_entry->is_reusable;
}

static Subtree ts_parser__lex(
  TSParser *self,
  StackVersion version,
  TSStateId parse_state
) {
  Length start_position = ts_stack_position(self->stack, version);
  Subtree external_token = ts_stack_last_external_token(self->stack, version);
  TSLexMode lex_mode = self->language->lex_modes[parse_state];
  const bool *valid_external_tokens = ts_language_enabled_external_tokens(
    self->language,
    lex_mode.external_lex_state
  );

  bool found_external_token = false;
  bool error_mode = parse_state == ERROR_STATE;
  bool skipped_error = false;
  int32_t first_error_character = 0;
  Length error_start_position = length_zero();
  Length error_end_position = length_zero();
  uint32_t lookahead_end_byte = 0;
  ts_lexer_reset(&self->lexer, start_position);

  for (;;) {
    Length current_position = self->lexer.current_position;

    if (valid_external_tokens) {
      LOG(
        "lex_external state:%d, row:%u, column:%u",
        lex_mode.external_lex_state,
        current_position.extent.row + 1,
        current_position.extent.column
      );
      ts_lexer_start(&self->lexer);
      ts_parser__restore_external_scanner(self, external_token);
      bool found_token = self->language->external_scanner.scan(
        self->external_scanner_payload,
        &self->lexer.data,
        valid_external_tokens
      );
      ts_lexer_finish(&self->lexer, &lookahead_end_byte);

      // Zero-length external tokens are generally allowed, but they're not
      // allowed right after a syntax error. This is for two reasons:
      // 1. After a syntax error, the lexer is looking for any possible token,
      //    as opposed to the specific set of tokens that are valid in some
      //    parse state. In this situation, it's very easy for an external
      //    scanner to produce unwanted zero-length tokens.
      // 2. The parser sometimes inserts *missing* tokens to recover from
      //    errors. These tokens are also zero-length. If we allow more
      //    zero-length tokens to be created after missing tokens, it
      //    can lead to infinite loops. Forbidding zero-length tokens
      //    right at the point of error recovery is a conservative strategy
      //    for preventing this kind of infinite loop.
      if (found_token && (
        self->lexer.token_end_position.bytes > current_position.bytes ||
        (!error_mode && ts_stack_has_advanced_since_error(self->stack, version))
      )) {
        found_external_token = true;
        break;
      }

      ts_lexer_reset(&self->lexer, current_position);
    }

    LOG(
      "lex_internal state:%d, row:%u, column:%u",
      lex_mode.lex_state,
      current_position.extent.row + 1,
      current_position.extent.column
    );
    ts_lexer_start(&self->lexer);
    bool found_token = self->language->lex_fn(&self->lexer.data, lex_mode.lex_state);
    ts_lexer_finish(&self->lexer, &lookahead_end_byte);
    if (found_token) break;

    if (!error_mode) {
      error_mode = true;
      lex_mode = self->language->lex_modes[ERROR_STATE];
      valid_external_tokens = ts_language_enabled_external_tokens(
        self->language,
        lex_mode.external_lex_state
      );
      ts_lexer_reset(&self->lexer, start_position);
      continue;
    }

    if (!skipped_error) {
      LOG("skip_unrecognized_character");
      skipped_error = true;
      error_start_position = self->lexer.token_start_position;
      error_end_position = self->lexer.token_start_position;
      first_error_character = self->lexer.data.lookahead;
    }

    if (self->lexer.current_position.bytes == error_end_position.bytes) {
      if (self->lexer.data.lookahead == 0) {
        self->lexer.data.result_symbol = ts_builtin_sym_error;
        break;
      }
      self->lexer.data.advance(&self->lexer.data, false);
    }

    error_end_position = self->lexer.current_position;
  }

  Subtree result;
  if (skipped_error) {
    Length padding = length_sub(error_start_position, start_position);
    Length size = length_sub(error_end_position, error_start_position);
    uint32_t lookahead_bytes = lookahead_end_byte - error_end_position.bytes;
    result = ts_subtree_new_error(
      &self->tree_pool,
      first_error_character,
      padding,
      size,
      lookahead_bytes,
      parse_state,
      self->language
    );

    LOG(
      "lexed_lookahead sym:%s, size:%u, character:'%c'",
      SYM_NAME(ts_subtree_symbol(result)),
      ts_subtree_total_size(result).bytes,
      first_error_character
    );
  } else {
    if (self->lexer.token_end_position.bytes < self->lexer.token_start_position.bytes) {
      self->lexer.token_start_position = self->lexer.token_end_position;
    }

    bool is_keyword = false;
    TSSymbol symbol = self->lexer.data.result_symbol;
    Length padding = length_sub(self->lexer.token_start_position, start_position);
    Length size = length_sub(self->lexer.token_end_position, self->lexer.token_start_position);
    uint32_t lookahead_bytes = lookahead_end_byte - self->lexer.token_end_position.bytes;

    if (found_external_token) {
      symbol = self->language->external_scanner.symbol_map[symbol];
    } else if (symbol == self->language->keyword_capture_token && symbol != 0) {
      uint32_t end_byte = self->lexer.token_end_position.bytes;
      ts_lexer_reset(&self->lexer, self->lexer.token_start_position);
      ts_lexer_start(&self->lexer);
      if (
        self->language->keyword_lex_fn(&self->lexer.data, 0) &&
        self->lexer.token_end_position.bytes == end_byte &&
        ts_language_has_actions(self->language, parse_state, self->lexer.data.result_symbol)
      ) {
        is_keyword = true;
        symbol = self->lexer.data.result_symbol;
      }
    }

    result = ts_subtree_new_leaf(
      &self->tree_pool,
      symbol,
      padding,
      size,
      lookahead_bytes,
      parse_state,
      found_external_token,
      is_keyword,
      self->language
    );

    if (found_external_token) {
      unsigned length = self->language->external_scanner.serialize(
        self->external_scanner_payload,
        self->lexer.debug_buffer
      );
      ts_external_scanner_state_init(
        &((SubtreeHeapData *)result.ptr)->external_scanner_state,
        self->lexer.debug_buffer,
        length
      );
    }

    LOG(
      "lexed_lookahead sym:%s, size:%u",
      SYM_NAME(ts_subtree_symbol(result)),
      ts_subtree_total_size(result).bytes
    );
  }

  return result;
}

static Subtree ts_parser__get_cached_token(
  TSParser *self,
  TSStateId state,
  size_t position,
  Subtree last_external_token,
  TableEntry *table_entry
) {
  TokenCache *cache = &self->token_cache;
  if (
    cache->token.ptr && cache->byte_index == position &&
    ts_subtree_external_scanner_state_eq(cache->last_external_token, last_external_token)
  ) {
    ts_language_table_entry(self->language, state, ts_subtree_symbol(cache->token), table_entry);
    if (ts_parser__can_reuse_first_leaf(self, state, cache->token, table_entry)) {
      ts_subtree_retain(cache->token);
      return cache->token;
    }
  }
  return NULL_SUBTREE;
}

static void ts_parser__set_cached_token(
  TSParser *self,
  size_t byte_index,
  Subtree last_external_token,
  Subtree token
) {
  TokenCache *cache = &self->token_cache;
  if (token.ptr) ts_subtree_retain(token);
  if (last_external_token.ptr) ts_subtree_retain(last_external_token);
  if (cache->token.ptr) ts_subtree_release(&self->tree_pool, cache->token);
  if (cache->last_external_token.ptr) ts_subtree_release(&self->tree_pool, cache->last_external_token);
  cache->token = token;
  cache->byte_index = byte_index;
  cache->last_external_token = last_external_token;
}

static bool ts_parser__has_included_range_difference(
  const TSParser *self,
  uint32_t start_position,
  uint32_t end_position
) {
  return ts_range_array_intersects(
    &self->included_range_differences,
    self->included_range_difference_index,
    start_position,
    end_position
  );
}

static Subtree ts_parser__reuse_node(
  TSParser *self,
  StackVersion version,
  TSStateId *state,
  uint32_t position,
  Subtree last_external_token,
  TableEntry *table_entry
) {
  Subtree result;
  while ((result = reusable_node_tree(&self->reusable_node)).ptr) {
    uint32_t byte_offset = reusable_node_byte_offset(&self->reusable_node);
    uint32_t end_byte_offset = byte_offset + ts_subtree_total_bytes(result);

    if (byte_offset > position) {
      LOG("before_reusable_node symbol:%s", TREE_NAME(result));
      break;
    }

    if (byte_offset < position) {
      LOG("past_reusable_node symbol:%s", TREE_NAME(result));
      if (end_byte_offset <= position || !reusable_node_descend(&self->reusable_node)) {
        reusable_node_advance(&self->reusable_node);
      }
      continue;
    }

    if (!ts_subtree_external_scanner_state_eq(self->reusable_node.last_external_token, last_external_token)) {
      LOG("reusable_node_has_different_external_scanner_state symbol:%s", TREE_NAME(result));
      reusable_node_advance(&self->reusable_node);
      continue;
    }

    const char *reason = NULL;
    if (ts_subtree_has_changes(result)) {
      reason = "has_changes";
    } else if (ts_subtree_is_error(result)) {
      reason = "is_error";
    } else if (ts_subtree_missing(result)) {
      reason = "is_missing";
    } else if (ts_subtree_is_fragile(result)) {
      reason = "is_fragile";
    } else if (ts_parser__has_included_range_difference(self, byte_offset, end_byte_offset)) {
      reason = "contains_different_included_range";
    }

    if (reason) {
      LOG("cant_reuse_node_%s tree:%s", reason, TREE_NAME(result));
      if (!reusable_node_descend(&self->reusable_node)) {
        reusable_node_advance(&self->reusable_node);
        ts_parser__breakdown_top_of_stack(self, version);
        *state = ts_stack_state(self->stack, version);
      }
      continue;
    }

    TSSymbol leaf_symbol = ts_subtree_leaf_symbol(result);
    ts_language_table_entry(self->language, *state, leaf_symbol, table_entry);
    if (!ts_parser__can_reuse_first_leaf(self, *state, result, table_entry)) {
      LOG(
        "cant_reuse_node symbol:%s, first_leaf_symbol:%s",
        TREE_NAME(result),
        SYM_NAME(leaf_symbol)
      );
      reusable_node_advance_past_leaf(&self->reusable_node);
      break;
    }

    LOG("reuse_node symbol:%s", TREE_NAME(result));
    ts_subtree_retain(result);
    return result;
  }

  return NULL_SUBTREE;
}

static bool ts_parser__select_tree(TSParser *self, Subtree left, Subtree right) {
  if (!left.ptr) return true;
  if (!right.ptr) return false;

  if (ts_subtree_error_cost(right) < ts_subtree_error_cost(left)) {
    LOG("select_smaller_error symbol:%s, over_symbol:%s", TREE_NAME(right), TREE_NAME(left));
    return true;
  }

  if (ts_subtree_error_cost(left) < ts_subtree_error_cost(right)) {
    LOG("select_smaller_error symbol:%s, over_symbol:%s", TREE_NAME(left), TREE_NAME(right));
    return false;
  }

  if (ts_subtree_dynamic_precedence(right) > ts_subtree_dynamic_precedence(left)) {
    LOG("select_higher_precedence symbol:%s, prec:%u, over_symbol:%s, other_prec:%u",
        TREE_NAME(right), ts_subtree_dynamic_precedence(right), TREE_NAME(left),
        ts_subtree_dynamic_precedence(left));
    return true;
  }

  if (ts_subtree_dynamic_precedence(left) > ts_subtree_dynamic_precedence(right)) {
    LOG("select_higher_precedence symbol:%s, prec:%u, over_symbol:%s, other_prec:%u",
        TREE_NAME(left), ts_subtree_dynamic_precedence(left), TREE_NAME(right),
        ts_subtree_dynamic_precedence(right));
    return false;
  }

  if (ts_subtree_error_cost(left) > 0) return true;

  int comparison = ts_subtree_compare(left, right);
  switch (comparison) {
    case -1:
      LOG("select_earlier symbol:%s, over_symbol:%s", TREE_NAME(left), TREE_NAME(right));
      return false;
      break;
    case 1:
      LOG("select_earlier symbol:%s, over_symbol:%s", TREE_NAME(right), TREE_NAME(left));
      return true;
    default:
      LOG("select_existing symbol:%s, over_symbol:%s", TREE_NAME(left), TREE_NAME(right));
      return false;
  }
}

static void ts_parser__shift(
  TSParser *self,
  StackVersion version,
  TSStateId state,
  Subtree lookahead,
  bool extra
) {
  Subtree subtree_to_push;
  if (extra != ts_subtree_extra(lookahead)) {
    MutableSubtree result = ts_subtree_make_mut(&self->tree_pool, lookahead);
    ts_subtree_set_extra(&result);
    subtree_to_push = ts_subtree_from_mut(result);
  } else {
    subtree_to_push = lookahead;
  }

  bool is_pending = ts_subtree_child_count(subtree_to_push) > 0;
  ts_stack_push(self->stack, version, subtree_to_push, is_pending, state);
  if (ts_subtree_has_external_tokens(subtree_to_push)) {
    ts_stack_set_last_external_token(
      self->stack, version, ts_subtree_last_external_token(subtree_to_push)
    );
  }
}

static bool ts_parser__replace_children(
  TSParser *self,
  MutableSubtree *tree,
  SubtreeArray *children
) {
  *self->scratch_tree.ptr = *tree->ptr;
  self->scratch_tree.ptr->child_count = 0;
  ts_subtree_set_children(self->scratch_tree, children->contents, children->size, self->language);
  if (ts_parser__select_tree(self, ts_subtree_from_mut(*tree), ts_subtree_from_mut(self->scratch_tree))) {
    *tree->ptr = *self->scratch_tree.ptr;
    return true;
  } else {
    return false;
  }
}

static StackVersion ts_parser__reduce(
  TSParser *self,
  StackVersion version,
  TSSymbol symbol,
  uint32_t count,
  int dynamic_precedence,
  uint16_t production_id,
  bool fragile
) {
  uint32_t initial_version_count = ts_stack_version_count(self->stack);
  uint32_t removed_version_count = 0;
  StackSliceArray pop = ts_stack_pop_count(self->stack, version, count);

  for (uint32_t i = 0; i < pop.size; i++) {
    StackSlice slice = pop.contents[i];
    StackVersion slice_version = slice.version - removed_version_count;

    // Error recovery can sometimes cause lots of stack versions to merge,
    // such that a single pop operation can produce a lots of slices.
    // Avoid creating too many stack versions in that situation.
    if (i > 0 && slice_version > MAX_VERSION_COUNT + MAX_VERSION_COUNT_OVERFLOW) {
      ts_stack_remove_version(self->stack, slice_version);
      ts_subtree_array_delete(&self->tree_pool, &slice.subtrees);
      removed_version_count++;
      while (i + 1 < pop.size) {
        StackSlice next_slice = pop.contents[i + 1];
        if (next_slice.version != slice.version) break;
        ts_subtree_array_delete(&self->tree_pool, &next_slice.subtrees);
        i++;
      }
      continue;
    }

    // Extra tokens on top of the stack should not be included in this new parent
    // node. They will be re-pushed onto the stack after the parent node is
    // created and pushed.
    SubtreeArray children = slice.subtrees;
    while (children.size > 0 && ts_subtree_extra(children.contents[children.size - 1])) {
      children.size--;
    }

    MutableSubtree parent = ts_subtree_new_node(&self->tree_pool,
      symbol, &children, production_id, self->language
    );

    // This pop operation may have caused multiple stack versions to collapse
    // into one, because they all diverged from a common state. In that case,
    // choose one of the arrays of trees to be the parent node's children, and
    // delete the rest of the tree arrays.
    while (i + 1 < pop.size) {
      StackSlice next_slice = pop.contents[i + 1];
      if (next_slice.version != slice.version) break;
      i++;

      SubtreeArray children = next_slice.subtrees;
      while (children.size > 0 && ts_subtree_extra(children.contents[children.size - 1])) {
        children.size--;
      }

      if (ts_parser__replace_children(self, &parent, &children)) {
        ts_subtree_array_delete(&self->tree_pool, &slice.subtrees);
        slice = next_slice;
      } else {
        ts_subtree_array_delete(&self->tree_pool, &next_slice.subtrees);
      }
    }

    parent.ptr->dynamic_precedence += dynamic_precedence;
    parent.ptr->production_id = production_id;

    TSStateId state = ts_stack_state(self->stack, slice_version);
    TSStateId next_state = ts_language_next_state(self->language, state, symbol);
    if (fragile || pop.size > 1 || initial_version_count > 1) {
      parent.ptr->fragile_left = true;
      parent.ptr->fragile_right = true;
      parent.ptr->parse_state = TS_TREE_STATE_NONE;
    } else {
      parent.ptr->parse_state = state;
    }

    // Push the parent node onto the stack, along with any extra tokens that
    // were previously on top of the stack.
    ts_stack_push(self->stack, slice_version, ts_subtree_from_mut(parent), false, next_state);
    for (uint32_t j = parent.ptr->child_count; j < slice.subtrees.size; j++) {
      ts_stack_push(self->stack, slice_version, slice.subtrees.contents[j], false, next_state);
    }

    for (StackVersion j = 0; j < slice_version; j++) {
      if (j == version) continue;
      if (ts_stack_merge(self->stack, j, slice_version)) {
        removed_version_count++;
        break;
      }
    }
  }

  // Return the first new stack version that was created.
  return ts_stack_version_count(self->stack) > initial_version_count
    ? initial_version_count
    : STACK_VERSION_NONE;
}

static void ts_parser__accept(
  TSParser *self,
  StackVersion version,
  Subtree lookahead
) {
  assert(ts_subtree_is_eof(lookahead));
  ts_stack_push(self->stack, version, lookahead, false, 1);

  StackSliceArray pop = ts_stack_pop_all(self->stack, version);
  for (uint32_t i = 0; i < pop.size; i++) {
    SubtreeArray trees = pop.contents[i].subtrees;

    Subtree root = NULL_SUBTREE;
    for (uint32_t j = trees.size - 1; j + 1 > 0; j--) {
      Subtree child = trees.contents[j];
      if (!ts_subtree_extra(child)) {
        assert(!child.data.is_inline);
        uint32_t child_count = ts_subtree_child_count(child);
        for (uint32_t k = 0; k < child_count; k++) {
          ts_subtree_retain(child.ptr->children[k]);
        }
        array_splice(&trees, j, 1, child_count, child.ptr->children);
        root = ts_subtree_from_mut(ts_subtree_new_node(
          &self->tree_pool,
          ts_subtree_symbol(child),
          &trees,
          child.ptr->production_id,
          self->language
        ));
        ts_subtree_release(&self->tree_pool, child);
        break;
      }
    }

    assert(root.ptr);
    self->accept_count++;

    if (self->finished_tree.ptr) {
      if (ts_parser__select_tree(self, self->finished_tree, root)) {
        ts_subtree_release(&self->tree_pool, self->finished_tree);
        self->finished_tree = root;
      } else {
        ts_subtree_release(&self->tree_pool, root);
      }
    } else {
      self->finished_tree = root;
    }
  }

  ts_stack_remove_version(self->stack, pop.contents[0].version);
  ts_stack_halt(self->stack, version);
}

static bool ts_parser__do_all_potential_reductions(
  TSParser *self,
  StackVersion starting_version,
  TSSymbol lookahead_symbol
) {
  uint32_t initial_version_count = ts_stack_version_count(self->stack);

  bool can_shift_lookahead_symbol = false;
  StackVersion version = starting_version;
  for (unsigned i = 0; true; i++) {
    uint32_t version_count = ts_stack_version_count(self->stack);
    if (version >= version_count) break;

    bool merged = false;
    for (StackVersion i = initial_version_count; i < version; i++) {
      if (ts_stack_merge(self->stack, i, version)) {
        merged = true;
        break;
      }
    }
    if (merged) continue;

    TSStateId state = ts_stack_state(self->stack, version);
    bool has_shift_action = false;
    array_clear(&self->reduce_actions);

    TSSymbol first_symbol, end_symbol;
    if (lookahead_symbol != 0) {
      first_symbol = lookahead_symbol;
      end_symbol = lookahead_symbol + 1;
    } else {
      first_symbol = 1;
      end_symbol = self->language->token_count;
    }

    for (TSSymbol symbol = first_symbol; symbol < end_symbol; symbol++) {
      TableEntry entry;
      ts_language_table_entry(self->language, state, symbol, &entry);
      for (uint32_t i = 0; i < entry.action_count; i++) {
        TSParseAction action = entry.actions[i];
        switch (action.type) {
          case TSParseActionTypeShift:
          case TSParseActionTypeRecover:
            if (!action.params.extra && !action.params.repetition) has_shift_action = true;
            break;
          case TSParseActionTypeReduce:
            if (action.params.child_count > 0)
              ts_reduce_action_set_add(&self->reduce_actions, (ReduceAction){
                .symbol = action.params.symbol,
                .count = action.params.child_count,
                .dynamic_precedence = action.params.dynamic_precedence,
                .production_id = action.params.production_id,
              });
          default:
            break;
        }
      }
    }

    StackVersion reduction_version = STACK_VERSION_NONE;
    for (uint32_t i = 0; i < self->reduce_actions.size; i++) {
      ReduceAction action = self->reduce_actions.contents[i];

      reduction_version = ts_parser__reduce(
        self, version, action.symbol, action.count,
        action.dynamic_precedence, action.production_id,
        true
      );
    }

    if (has_shift_action) {
      can_shift_lookahead_symbol = true;
    } else if (reduction_version != STACK_VERSION_NONE && i < MAX_VERSION_COUNT) {
      ts_stack_renumber_version(self->stack, reduction_version, version);
      continue;
    } else if (lookahead_symbol != 0) {
      ts_stack_remove_version(self->stack, version);
    }

    if (version == starting_version) {
      version = version_count;
    } else {
      version++;
    }
  }

  return can_shift_lookahead_symbol;
}

static void ts_parser__handle_error(
  TSParser *self,
  StackVersion version,
  TSSymbol lookahead_symbol
) {
  uint32_t previous_version_count = ts_stack_version_count(self->stack);

  // Perform any reductions that can happen in this state, regardless of the lookahead. After
  // skipping one or more invalid tokens, the parser might find a token that would have allowed
  // a reduction to take place.
  ts_parser__do_all_potential_reductions(self, version, 0);
  uint32_t version_count = ts_stack_version_count(self->stack);
  Length position = ts_stack_position(self->stack, version);

  // Push a discontinuity onto the stack. Merge all of the stack versions that
  // were created in the previous step.
  bool did_insert_missing_token = false;
  for (StackVersion v = version; v < version_count;) {
    if (!did_insert_missing_token) {
      TSStateId state = ts_stack_state(self->stack, v);
      for (TSSymbol missing_symbol = 1;
           missing_symbol < self->language->token_count;
           missing_symbol++) {
        TSStateId state_after_missing_symbol = ts_language_next_state(
          self->language, state, missing_symbol
        );
        if (state_after_missing_symbol == 0) continue;

        if (ts_language_has_reduce_action(
          self->language,
          state_after_missing_symbol,
          lookahead_symbol
        )) {
          // In case the parser is currently outside of any included range, the lexer will
          // snap to the beginning of the next included range. The missing token's padding
          // must be assigned to position it within the next included range.
          ts_lexer_reset(&self->lexer, position);
          ts_lexer_mark_end(&self->lexer);
          Length padding = length_sub(self->lexer.token_end_position, position);

          StackVersion version_with_missing_tree = ts_stack_copy_version(self->stack, v);
          Subtree missing_tree = ts_subtree_new_missing_leaf(
            &self->tree_pool, missing_symbol, padding, self->language
          );
          ts_stack_push(
            self->stack, version_with_missing_tree,
            missing_tree, false,
            state_after_missing_symbol
          );

          if (ts_parser__do_all_potential_reductions(
            self, version_with_missing_tree,
            lookahead_symbol
          )) {
            LOG(
              "recover_with_missing symbol:%s, state:%u",
              SYM_NAME(missing_symbol),
              ts_stack_state(self->stack, version_with_missing_tree)
            );
            did_insert_missing_token = true;
            break;
          }
        }
      }
    }

    ts_stack_push(self->stack, v, NULL_SUBTREE, false, ERROR_STATE);
    v = (v == version) ? previous_version_count : v + 1;
  }

  for (unsigned i = previous_version_count; i < version_count; i++) {
    bool did_merge = ts_stack_merge(self->stack, version, previous_version_count);
    assert(did_merge);
  }

  ts_stack_record_summary(self->stack, version, MAX_SUMMARY_DEPTH);
  LOG_STACK();
}

static void ts_parser__halt_parse(TSParser *self) {
  LOG("halting_parse");
  LOG_STACK();

  ts_lexer_advance_to_end(&self->lexer);
  Length remaining_length = length_sub(
    self->lexer.current_position,
    ts_stack_position(self->stack, 0)
  );

  Subtree filler_node = ts_subtree_new_error(
    &self->tree_pool,
    0,
    length_zero(),
    remaining_length,
    remaining_length.bytes,
    0,
    self->language
  );
  ts_subtree_to_mut_unsafe(filler_node).ptr->visible = false;
  ts_stack_push(self->stack, 0, filler_node, false, 0);

  SubtreeArray children = array_new();
  Subtree root_error = ts_subtree_new_error_node(&self->tree_pool, &children, false, self->language);
  ts_stack_push(self->stack, 0, root_error, false, 0);

  Subtree eof = ts_subtree_new_leaf(
    &self->tree_pool,
    ts_builtin_sym_end,
    length_zero(),
    length_zero(),
    0,
    0,
    false,
    false,
    self->language
  );
  ts_parser__accept(self, 0, eof);
}

static bool ts_parser__recover_to_state(
  TSParser *self,
  StackVersion version,
  unsigned depth,
  TSStateId goal_state
) {
  StackSliceArray pop = ts_stack_pop_count(self->stack, version, depth);
  StackVersion previous_version = STACK_VERSION_NONE;

  for (unsigned i = 0; i < pop.size; i++) {
    StackSlice slice = pop.contents[i];

    if (slice.version == previous_version) {
      ts_subtree_array_delete(&self->tree_pool, &slice.subtrees);
      array_erase(&pop, i--);
      continue;
    }

    if (ts_stack_state(self->stack, slice.version) != goal_state) {
      ts_stack_halt(self->stack, slice.version);
      ts_subtree_array_delete(&self->tree_pool, &slice.subtrees);
      array_erase(&pop, i--);
      continue;
    }

    SubtreeArray error_trees = ts_stack_pop_error(self->stack, slice.version);
    if (error_trees.size > 0) {
      assert(error_trees.size == 1);
      Subtree error_tree = error_trees.contents[0];
      uint32_t error_child_count = ts_subtree_child_count(error_tree);
      if (error_child_count > 0) {
        array_splice(&slice.subtrees, 0, 0, error_child_count, error_tree.ptr->children);
        for (unsigned j = 0; j < error_child_count; j++) {
          ts_subtree_retain(slice.subtrees.contents[j]);
        }
      }
      ts_subtree_array_delete(&self->tree_pool, &error_trees);
    }

    SubtreeArray trailing_extras = ts_subtree_array_remove_trailing_extras(&slice.subtrees);

    if (slice.subtrees.size > 0) {
      Subtree error = ts_subtree_new_error_node(&self->tree_pool, &slice.subtrees, true, self->language);
      ts_stack_push(self->stack, slice.version, error, false, goal_state);
    } else {
      array_delete(&slice.subtrees);
    }

    for (unsigned j = 0; j < trailing_extras.size; j++) {
      Subtree tree = trailing_extras.contents[j];
      ts_stack_push(self->stack, slice.version, tree, false, goal_state);
    }

    previous_version = slice.version;
    array_delete(&trailing_extras);
  }

  return previous_version != STACK_VERSION_NONE;
}

static void ts_parser__recover(
  TSParser *self,
  StackVersion version,
  Subtree lookahead
) {
  bool did_recover = false;
  unsigned previous_version_count = ts_stack_version_count(self->stack);
  Length position = ts_stack_position(self->stack, version);
  StackSummary *summary = ts_stack_get_summary(self->stack, version);
  unsigned node_count_since_error = ts_stack_node_count_since_error(self->stack, version);
  unsigned current_error_cost = ts_stack_error_cost(self->stack, version);

  // When the parser is in the error state, there are two strategies for recovering with a
  // given lookahead token:
  // 1. Find a previous state on the stack in which that lookahead token would be valid. Then,
  //    create a new stack version that is in that state again. This entails popping all of the
  //    subtrees that have been pushed onto the stack since that previous state, and wrapping
  //    them in an ERROR node.
  // 2. Wrap the lookahead token in an ERROR node, push that ERROR node onto the stack, and
  //    move on to the next lookahead token, remaining in the error state.
  //
  // First, try the strategy 1. Upon entering the error state, the parser recorded a summary
  // of the previous parse states and their depths. Look at each state in the summary, to see
  // if the current lookahead token would be valid in that state.
  if (summary && !ts_subtree_is_error(lookahead)) {
    for (unsigned i = 0; i < summary->size; i++) {
      StackSummaryEntry entry = summary->contents[i];

      if (entry.state == ERROR_STATE) continue;
      if (entry.position.bytes == position.bytes) continue;
      unsigned depth = entry.depth;
      if (node_count_since_error > 0) depth++;

      // Do not recover in ways that create redundant stack versions.
      bool would_merge = false;
      for (unsigned j = 0; j < previous_version_count; j++) {
        if (
          ts_stack_state(self->stack, j) == entry.state &&
          ts_stack_position(self->stack, j).bytes == position.bytes
        ) {
          would_merge = true;
          break;
        }
      }
      if (would_merge) continue;

      // Do not recover if the result would clearly be worse than some existing stack version.
      unsigned new_cost =
        current_error_cost +
        entry.depth * ERROR_COST_PER_SKIPPED_TREE +
        (position.bytes - entry.position.bytes) * ERROR_COST_PER_SKIPPED_CHAR +
        (position.extent.row - entry.position.extent.row) * ERROR_COST_PER_SKIPPED_LINE;
      if (ts_parser__better_version_exists(self, version, false, new_cost)) break;

      // If the current lookahead token is valid in some previous state, recover to that state.
      // Then stop looking for further recoveries.
      if (ts_language_has_actions(self->language, entry.state, ts_subtree_symbol(lookahead))) {
        if (ts_parser__recover_to_state(self, version, depth, entry.state)) {
          did_recover = true;
          LOG("recover_to_previous state:%u, depth:%u", entry.state, depth);
          LOG_STACK();
          break;
        }
      }
    }
  }

  // In the process of attemping to recover, some stack versions may have been created
  // and subsequently halted. Remove those versions.
  for (unsigned i = previous_version_count; i < ts_stack_version_count(self->stack); i++) {
    if (!ts_stack_is_active(self->stack, i)) {
      ts_stack_remove_version(self->stack, i--);
    }
  }

  // If strategy 1 succeeded, a new stack version will have been created which is able to handle
  // the current lookahead token. Now, in addition, try strategy 2 described above: skip the
  // current lookahead token by wrapping it in an ERROR node.

  // Don't pursue this additional strategy if there are already too many stack versions.
  if (did_recover && ts_stack_version_count(self->stack) > MAX_VERSION_COUNT) {
    ts_stack_halt(self->stack, version);
    ts_subtree_release(&self->tree_pool, lookahead);
    return;
  }

  // If the parser is still in the error state at the end of the file, just wrap everything
  // in an ERROR node and terminate.
  if (ts_subtree_is_eof(lookahead)) {
    LOG("recover_eof");
    SubtreeArray children = array_new();
    Subtree parent = ts_subtree_new_error_node(&self->tree_pool, &children, false, self->language);
    ts_stack_push(self->stack, version, parent, false, 1);
    ts_parser__accept(self, version, lookahead);
    return;
  }

  // Do not recover if the result would clearly be worse than some existing stack version.
  unsigned new_cost =
    current_error_cost + ERROR_COST_PER_SKIPPED_TREE +
    ts_subtree_total_bytes(lookahead) * ERROR_COST_PER_SKIPPED_CHAR +
    ts_subtree_total_size(lookahead).extent.row * ERROR_COST_PER_SKIPPED_LINE;
  if (ts_parser__better_version_exists(self, version, false, new_cost)) {
    ts_stack_halt(self->stack, version);
    ts_subtree_release(&self->tree_pool, lookahead);
    return;
  }

  // If the current lookahead token is an extra token, mark it as extra. This means it won't
  // be counted in error cost calculations.
  unsigned n;
  const TSParseAction *actions = ts_language_actions(self->language, 1, ts_subtree_symbol(lookahead), &n);
  if (n > 0 && actions[n - 1].type == TSParseActionTypeShift && actions[n - 1].params.extra) {
    MutableSubtree mutable_lookahead = ts_subtree_make_mut(&self->tree_pool, lookahead);
    ts_subtree_set_extra(&mutable_lookahead);
    lookahead = ts_subtree_from_mut(mutable_lookahead);
  }

  // Wrap the lookahead token in an ERROR.
  LOG("skip_token symbol:%s", TREE_NAME(lookahead));
  SubtreeArray children = array_new();
  array_reserve(&children, 1);
  array_push(&children, lookahead);
  MutableSubtree error_repeat = ts_subtree_new_node(
    &self->tree_pool,
    ts_builtin_sym_error_repeat,
    &children,
    0,
    self->language
  );

  // If other tokens have already been skipped, so there is already an ERROR at the top of the
  // stack, then pop that ERROR off the stack and wrap the two ERRORs together into one larger
  // ERROR.
  if (node_count_since_error > 0) {
    StackSliceArray pop = ts_stack_pop_count(self->stack, version, 1);

    // TODO: Figure out how to make this condition occur.
    // See https://github.com/atom/atom/issues/18450#issuecomment-439579778
    // If multiple stack versions have merged at this point, just pick one of the errors
    // arbitrarily and discard the rest.
    if (pop.size > 1) {
      for (unsigned i = 1; i < pop.size; i++) {
        ts_subtree_array_delete(&self->tree_pool, &pop.contents[i].subtrees);
      }
      while (ts_stack_version_count(self->stack) > pop.contents[0].version + 1) {
        ts_stack_remove_version(self->stack, pop.contents[0].version + 1);
      }
    }

    ts_stack_renumber_version(self->stack, pop.contents[0].version, version);
    array_push(&pop.contents[0].subtrees, ts_subtree_from_mut(error_repeat));
    error_repeat = ts_subtree_new_node(
      &self->tree_pool,
      ts_builtin_sym_error_repeat,
      &pop.contents[0].subtrees,
      0,
      self->language
    );
  }

  // Push the new ERROR onto the stack.
  ts_stack_push(self->stack, version, ts_subtree_from_mut(error_repeat), false, ERROR_STATE);
  if (ts_subtree_has_external_tokens(lookahead)) {
    ts_stack_set_last_external_token(
      self->stack, version, ts_subtree_last_external_token(lookahead)
    );
  }
}

static bool ts_parser__advance(
  TSParser *self,
  StackVersion version,
  bool allow_node_reuse
) {
  TSStateId state = ts_stack_state(self->stack, version);
  uint32_t position = ts_stack_position(self->stack, version).bytes;
  Subtree last_external_token = ts_stack_last_external_token(self->stack, version);

  bool did_reuse = true;
  Subtree lookahead = NULL_SUBTREE;
  TableEntry table_entry = {.action_count = 0};

  // If possible, reuse a node from the previous syntax tree.
  if (allow_node_reuse) {
    lookahead = ts_parser__reuse_node(
      self, version, &state, position, last_external_token, &table_entry
    );
  }

  // If no node from the previous syntax tree could be reused, then try to
  // reuse the token previously returned by the lexer.
  if (!lookahead.ptr) {
    did_reuse = false;
    lookahead = ts_parser__get_cached_token(
      self, state, position, last_external_token, &table_entry
    );
  }

  // Otherwise, re-run the lexer.
  if (!lookahead.ptr) {
    lookahead = ts_parser__lex(self, version, state);
    ts_parser__set_cached_token(self, position, last_external_token, lookahead);
    ts_language_table_entry(self->language, state, ts_subtree_symbol(lookahead), &table_entry);
  }

  for (;;) {
    // If a cancellation flag or a timeout was provided, then check every
    // time a fixed number of parse actions has been processed.
    if (++self->operation_count == OP_COUNT_PER_TIMEOUT_CHECK) {
      self->operation_count = 0;
    }
    if (
      self->operation_count == 0 &&
      ((self->cancellation_flag && atomic_load(self->cancellation_flag)) ||
       (!clock_is_null(self->end_clock) && clock_is_gt(clock_now(), self->end_clock)))
    ) {
      ts_subtree_release(&self->tree_pool, lookahead);
      return false;
    }

    // Process each parse action for the current lookahead token in
    // the current state. If there are multiple actions, then this is
    // an ambiguous state. REDUCE actions always create a new stack
    // version, whereas SHIFT actions update the existing stack version
    // and terminate this loop.
    StackVersion last_reduction_version = STACK_VERSION_NONE;
    for (uint32_t i = 0; i < table_entry.action_count; i++) {
      TSParseAction action = table_entry.actions[i];

      switch (action.type) {
        case TSParseActionTypeShift: {
          if (action.params.repetition) break;
          TSStateId next_state;
          if (action.params.extra) {

            // TODO: remove when TREE_SITTER_LANGUAGE_VERSION 9 is out.
            if (state == ERROR_STATE) continue;

            next_state = state;
            LOG("shift_extra");
          } else {
            next_state = action.params.state;
            LOG("shift state:%u", next_state);
          }

          if (ts_subtree_child_count(lookahead) > 0) {
            ts_parser__breakdown_lookahead(self, &lookahead, state, &self->reusable_node);
            next_state = ts_language_next_state(self->language, state, ts_subtree_symbol(lookahead));
          }

          ts_parser__shift(self, version, next_state, lookahead, action.params.extra);
          if (did_reuse) reusable_node_advance(&self->reusable_node);
          return true;
        }

        case TSParseActionTypeReduce: {
          bool is_fragile = table_entry.action_count > 1;
          LOG("reduce sym:%s, child_count:%u", SYM_NAME(action.params.symbol), action.params.child_count);
          StackVersion reduction_version = ts_parser__reduce(
            self, version, action.params.symbol, action.params.child_count,
            action.params.dynamic_precedence, action.params.production_id,
            is_fragile
          );
          if (reduction_version != STACK_VERSION_NONE) {
            last_reduction_version = reduction_version;
          }
          break;
        }

        case TSParseActionTypeAccept: {
          LOG("accept");
          ts_parser__accept(self, version, lookahead);
          return true;
        }

        case TSParseActionTypeRecover: {
          if (ts_subtree_child_count(lookahead) > 0) {
            ts_parser__breakdown_lookahead(self, &lookahead, ERROR_STATE, &self->reusable_node);
          }

          ts_parser__recover(self, version, lookahead);
          if (did_reuse) reusable_node_advance(&self->reusable_node);
          return true;
        }
      }
    }

    // If a reduction was performed, then replace the current stack version
    // with one of the stack versions created by a reduction, and continue
    // processing this version of the stack with the same lookahead symbol.
    if (last_reduction_version != STACK_VERSION_NONE) {
      ts_stack_renumber_version(self->stack, last_reduction_version, version);
      LOG_STACK();
      state = ts_stack_state(self->stack, version);
      ts_language_table_entry(
        self->language,
        state,
        ts_subtree_leaf_symbol(lookahead),
        &table_entry
      );
      continue;
    }

    // If there were no parse actions for the current lookahead token, then
    // it is not valid in this state. If the current lookahead token is a
    // keyword, then switch to treating it as the normal word token if that
    // token is valid in this state.
    if (
      ts_subtree_is_keyword(lookahead) &&
      ts_subtree_symbol(lookahead) != self->language->keyword_capture_token
    ) {
      ts_language_table_entry(self->language, state, self->language->keyword_capture_token, &table_entry);
      if (table_entry.action_count > 0) {
        LOG(
          "switch from_keyword:%s, to_word_token:%s",
          TREE_NAME(lookahead),
          SYM_NAME(self->language->keyword_capture_token)
        );

        MutableSubtree mutable_lookahead = ts_subtree_make_mut(&self->tree_pool, lookahead);
        ts_subtree_set_symbol(&mutable_lookahead, self->language->keyword_capture_token, self->language);
        lookahead = ts_subtree_from_mut(mutable_lookahead);
        continue;
      }
    }

    // If the current lookahead token is not valid and the parser is
    // already in the error state, restart the error recovery process.
    // TODO - can this be unified with the other `RECOVER` case above?
    if (state == ERROR_STATE) {
      ts_parser__recover(self, version, lookahead);
      return true;
    }

    // If the current lookahead token is not valid and the previous
    // subtree on the stack was reused from an old tree, it isn't actually
    // valid to reuse it. Remove it from the stack, and in its place,
    // push each of its children. Then try again to process the current
    // lookahead.
    if (ts_parser__breakdown_top_of_stack(self, version)) {
      continue;
    }

    // At this point, the current lookahead token is definitely not valid
    // for this parse stack version. Mark this version as paused and continue
    // processing any other stack versions that might exist. If some other
    // version advances successfully, then this version can simply be removed.
    // But if all versions end up paused, then error recovery is needed.
    LOG("detect_error");
    ts_stack_pause(self->stack, version, ts_subtree_leaf_symbol(lookahead));
    ts_subtree_release(&self->tree_pool, lookahead);
    return true;
  }
}

static unsigned ts_parser__condense_stack(TSParser *self) {
  bool made_changes = false;
  unsigned min_error_cost = UINT_MAX;
  for (StackVersion i = 0; i < ts_stack_version_count(self->stack); i++) {
    // Prune any versions that have been marked for removal.
    if (ts_stack_is_halted(self->stack, i)) {
      ts_stack_remove_version(self->stack, i);
      i--;
      continue;
    }

    // Keep track of the minimum error cost of any stack version so
    // that it can be returned.
    ErrorStatus status_i = ts_parser__version_status(self, i);
    if (!status_i.is_in_error && status_i.cost < min_error_cost) {
      min_error_cost = status_i.cost;
    }

    // Examine each pair of stack versions, removing any versions that
    // are clearly worse than another version. Ensure that the versions
    // are ordered from most promising to least promising.
    for (StackVersion j = 0; j < i; j++) {
      ErrorStatus status_j = ts_parser__version_status(self, j);

      switch (ts_parser__compare_versions(self, status_j, status_i)) {
        case ErrorComparisonTakeLeft:
          made_changes = true;
          ts_stack_remove_version(self->stack, i);
          i--;
          j = i;
          break;

        case ErrorComparisonPreferLeft:
        case ErrorComparisonNone:
          if (ts_stack_merge(self->stack, j, i)) {
            made_changes = true;
            i--;
            j = i;
          }
          break;

        case ErrorComparisonPreferRight:
          made_changes = true;
          if (ts_stack_merge(self->stack, j, i)) {
            i--;
            j = i;
          } else {
            ts_stack_swap_versions(self->stack, i, j);
          }
          break;

        case ErrorComparisonTakeRight:
          made_changes = true;
          ts_stack_remove_version(self->stack, j);
          i--;
          j--;
          break;
      }
    }
  }

  // Enfore a hard upper bound on the number of stack versions by
  // discarding the least promising versions.
  while (ts_stack_version_count(self->stack) > MAX_VERSION_COUNT) {
    ts_stack_remove_version(self->stack, MAX_VERSION_COUNT);
    made_changes = true;
  }

  // If the best-performing stack version is currently paused, or all
  // versions are paused, then resume the best paused version and begin
  // the error recovery process. Otherwise, remove the paused versions.
  if (ts_stack_version_count(self->stack) > 0) {
    bool has_unpaused_version = false;
    for (StackVersion i = 0, n = ts_stack_version_count(self->stack); i < n; i++) {
      if (ts_stack_is_paused(self->stack, i)) {
        if (!has_unpaused_version && self->accept_count < MAX_VERSION_COUNT) {
          LOG("resume version:%u", i);
          min_error_cost = ts_stack_error_cost(self->stack, i);
          TSSymbol lookahead_symbol = ts_stack_resume(self->stack, i);
          ts_parser__handle_error(self, i, lookahead_symbol);
          has_unpaused_version = true;
        } else {
          ts_stack_remove_version(self->stack, i);
          i--;
          n--;
        }
      } else {
        has_unpaused_version = true;
      }
    }
  }

  if (made_changes) {
    LOG("condense");
    LOG_STACK();
  }

  return min_error_cost;
}

static bool ts_parser_has_outstanding_parse(TSParser *self) {
  return (
    self->lexer.current_position.bytes > 0 ||
    ts_stack_state(self->stack, 0) != 1
  );
}

// Parser - Public

TSParser *ts_parser_new(void) {
  TSParser *self = ts_calloc(1, sizeof(TSParser));
  ts_lexer_init(&self->lexer);
  array_init(&self->reduce_actions);
  array_reserve(&self->reduce_actions, 4);
  self->tree_pool = ts_subtree_pool_new(32);
  self->stack = ts_stack_new(&self->tree_pool);
  self->finished_tree = NULL_SUBTREE;
  self->reusable_node = reusable_node_new();
  self->dot_graph_file = NULL;
  self->halt_on_error = false;
  self->cancellation_flag = NULL;
  self->timeout_duration = 0;
  self->end_clock = clock_null();
  self->operation_count = 0;
  self->old_tree = NULL_SUBTREE;
  self->scratch_tree.ptr = &self->scratch_tree_data;
  self->included_range_differences = (TSRangeArray) array_new();
  self->included_range_difference_index = 0;
  ts_parser__set_cached_token(self, 0, NULL_SUBTREE, NULL_SUBTREE);
  return self;
}

void ts_parser_delete(TSParser *self) {
  if (!self) return;

  ts_stack_delete(self->stack);
  if (self->reduce_actions.contents) {
    array_delete(&self->reduce_actions);
  }
  if (self->included_range_differences.contents) {
    array_delete(&self->included_range_differences);
  }
  if (self->old_tree.ptr) {
    ts_subtree_release(&self->tree_pool, self->old_tree);
    self->old_tree = NULL_SUBTREE;
  }
  ts_lexer_delete(&self->lexer);
  ts_parser__set_cached_token(self, 0, NULL_SUBTREE, NULL_SUBTREE);
  ts_subtree_pool_delete(&self->tree_pool);
  reusable_node_delete(&self->reusable_node);
  ts_parser_set_language(self, NULL);
  ts_free(self);
}

const TSLanguage *ts_parser_language(const TSParser *self) {
  return self->language;
}

bool ts_parser_set_language(TSParser *self, const TSLanguage *language) {
  if (language) {
    if (language->version > TREE_SITTER_LANGUAGE_VERSION) return false;
    if (language->version < TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION) return false;
  }

  if (self->external_scanner_payload && self->language->external_scanner.destroy) {
    self->language->external_scanner.destroy(self->external_scanner_payload);
  }

  if (language && language->external_scanner.create) {
    self->external_scanner_payload = language->external_scanner.create();
  } else {
    self->external_scanner_payload = NULL;
  }

  self->language = language;
  return true;
}

TSLogger ts_parser_logger(const TSParser *self) {
  return self->lexer.logger;
}

void ts_parser_set_logger(TSParser *self, TSLogger logger) {
  self->lexer.logger = logger;
}

void ts_parser_print_dot_graphs(TSParser *self, int fd) {
  if (self->dot_graph_file) {
    fclose(self->dot_graph_file);
  }

  if (fd >= 0) {
    self->dot_graph_file = fdopen(fd, "a");
  } else {
    self->dot_graph_file = NULL;
  }
}

void ts_parser_halt_on_error(TSParser *self, bool should_halt_on_error) {
  self->halt_on_error = should_halt_on_error;
}

const size_t *ts_parser_cancellation_flag(const TSParser *self) {
  return (const size_t *)self->cancellation_flag;
}

void ts_parser_set_cancellation_flag(TSParser *self, const size_t *flag) {
  self->cancellation_flag = (const volatile size_t *)flag;
}

uint64_t ts_parser_timeout_micros(const TSParser *self) {
  return duration_to_micros(self->timeout_duration);
}

void ts_parser_set_timeout_micros(TSParser *self, uint64_t timeout_micros) {
  self->timeout_duration = duration_from_micros(timeout_micros);
}

void ts_parser_set_included_ranges(TSParser *self, const TSRange *ranges, uint32_t count) {
  ts_lexer_set_included_ranges(&self->lexer, ranges, count);
}

const TSRange *ts_parser_included_ranges(const TSParser *self, uint32_t *count) {
  return ts_lexer_included_ranges(&self->lexer, count);
}

void ts_parser_reset(TSParser *self) {
  if (self->language->external_scanner.deserialize) {
    self->language->external_scanner.deserialize(self->external_scanner_payload, NULL, 0);
  }

  if (self->old_tree.ptr) {
    ts_subtree_release(&self->tree_pool, self->old_tree);
    self->old_tree = NULL_SUBTREE;
  }

  reusable_node_clear(&self->reusable_node);
  ts_lexer_reset(&self->lexer, length_zero());
  ts_stack_clear(self->stack);
  ts_parser__set_cached_token(self, 0, NULL_SUBTREE, NULL_SUBTREE);
  if (self->finished_tree.ptr) {
    ts_subtree_release(&self->tree_pool, self->finished_tree);
    self->finished_tree = NULL_SUBTREE;
  }
  self->accept_count = 0;
}

TSTree *ts_parser_parse(
  TSParser *self,
  const TSTree *old_tree,
  TSInput input
) {
  if (!self->language || !input.read) return NULL;

  ts_lexer_set_input(&self->lexer, input);

  array_clear(&self->included_range_differences);
  self->included_range_difference_index = 0;

  if (ts_parser_has_outstanding_parse(self)) {
    LOG("resume_parsing");
  } else if (old_tree) {
    ts_subtree_retain(old_tree->root);
    self->old_tree = old_tree->root;
    ts_range_array_get_changed_ranges(
      old_tree->included_ranges, old_tree->included_range_count,
      self->lexer.included_ranges, self->lexer.included_range_count,
      &self->included_range_differences
    );
    reusable_node_reset(&self->reusable_node, old_tree->root);
    LOG("parse_after_edit");
    LOG_TREE(self->old_tree);
    for (unsigned i = 0; i < self->included_range_differences.size; i++) {
      TSRange *range = &self->included_range_differences.contents[i];
      LOG("different_included_range %u - %u", range->start_byte, range->end_byte);
    }
  } else {
    reusable_node_clear(&self->reusable_node);
    LOG("new_parse");
  }

  uint32_t position = 0, last_position = 0, version_count = 0;
  self->operation_count = 0;
  if (self->timeout_duration) {
    self->end_clock = clock_after(clock_now(), self->timeout_duration);
  } else {
    self->end_clock = clock_null();
  }

  do {
    for (StackVersion version = 0;
         version_count = ts_stack_version_count(self->stack), version < version_count;
         version++) {
      bool allow_node_reuse = version_count == 1;
      while (ts_stack_is_active(self->stack, version)) {
        LOG("process version:%d, version_count:%u, state:%d, row:%u, col:%u",
            version, ts_stack_version_count(self->stack),
            ts_stack_state(self->stack, version),
            ts_stack_position(self->stack, version).extent.row + 1,
            ts_stack_position(self->stack, version).extent.column);

        if (!ts_parser__advance(self, version, allow_node_reuse)) return NULL;
        LOG_STACK();

        position = ts_stack_position(self->stack, version).bytes;
        if (position > last_position || (version > 0 && position == last_position)) {
          last_position = position;
          break;
        }
      }
    }

    unsigned min_error_cost = ts_parser__condense_stack(self);
    if (self->finished_tree.ptr && ts_subtree_error_cost(self->finished_tree) < min_error_cost) {
      break;
    } else if (self->halt_on_error && min_error_cost > 0) {
      ts_parser__halt_parse(self);
      break;
    }

    while (self->included_range_difference_index < self->included_range_differences.size) {
      TSRange *range = &self->included_range_differences.contents[self->included_range_difference_index];
      if (range->end_byte <= position) {
        self->included_range_difference_index++;
      } else {
        break;
      }
    }
  } while (version_count != 0);

  ts_subtree_balance(self->finished_tree, &self->tree_pool, self->language);
  LOG("done");
  LOG_TREE(self->finished_tree);

  TSTree *result = ts_tree_new(
    self->finished_tree,
    self->language,
    self->lexer.included_ranges,
    self->lexer.included_range_count
  );
  self->finished_tree = NULL_SUBTREE;
  ts_parser_reset(self);
  return result;
}

TSTree *ts_parser_parse_string(
  TSParser *self,
  const TSTree *old_tree,
  const char *string,
  uint32_t length
) {
  return ts_parser_parse_string_encoding(self, old_tree, string, length, TSInputEncodingUTF8);
}

TSTree *ts_parser_parse_string_encoding(TSParser *self, const TSTree *old_tree,
                                        const char *string, uint32_t length, TSInputEncoding encoding) {
  TSStringInput input = {string, length};
  return ts_parser_parse(self, old_tree, (TSInput) {
    &input,
    ts_string_input_read,
    encoding,
  });
}

#undef LOG
