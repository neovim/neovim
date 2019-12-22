#ifndef TREE_SITTER_LANGUAGE_H_
#define TREE_SITTER_LANGUAGE_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "./subtree.h"
#include "tree_sitter/parser.h"

#define ts_builtin_sym_error_repeat (ts_builtin_sym_error - 1)
#define TREE_SITTER_LANGUAGE_VERSION_WITH_FIELDS 10
#define TREE_SITTER_LANGUAGE_VERSION_WITH_SYMBOL_DEDUPING 11
#define TREE_SITTER_LANGUAGE_VERSION_WITH_SMALL_STATES 11

typedef struct {
  const TSParseAction *actions;
  uint32_t action_count;
  bool is_reusable;
} TableEntry;

void ts_language_table_entry(const TSLanguage *, TSStateId, TSSymbol, TableEntry *);

TSSymbolMetadata ts_language_symbol_metadata(const TSLanguage *, TSSymbol);

TSSymbol ts_language_public_symbol(const TSLanguage *, TSSymbol);

static inline bool ts_language_is_symbol_external(const TSLanguage *self, TSSymbol symbol) {
  return 0 < symbol && symbol < self->external_token_count + 1;
}

static inline const TSParseAction *ts_language_actions(const TSLanguage *self,
                                                       TSStateId state,
                                                       TSSymbol symbol,
                                                       uint32_t *count) {
  TableEntry entry;
  ts_language_table_entry(self, state, symbol, &entry);
  *count = entry.action_count;
  return entry.actions;
}

static inline bool ts_language_has_actions(const TSLanguage *self,
                                           TSStateId state,
                                           TSSymbol symbol) {
  TableEntry entry;
  ts_language_table_entry(self, state, symbol, &entry);
  return entry.action_count > 0;
}

static inline bool ts_language_has_reduce_action(const TSLanguage *self,
                                                 TSStateId state,
                                                 TSSymbol symbol) {
  TableEntry entry;
  ts_language_table_entry(self, state, symbol, &entry);
  return entry.action_count > 0 && entry.actions[0].type == TSParseActionTypeReduce;
}

static inline uint16_t ts_language_lookup(
  const TSLanguage *self,
  TSStateId state,
  TSSymbol symbol
) {
  if (
    self->version >= TREE_SITTER_LANGUAGE_VERSION_WITH_SMALL_STATES &&
    state >= self->large_state_count
  ) {
    uint32_t index = self->small_parse_table_map[state - self->large_state_count];
    const uint16_t *data = &self->small_parse_table[index];
    uint16_t section_count = *(data++);
    for (unsigned i = 0; i < section_count; i++) {
      uint16_t section_value = *(data++);
      uint16_t symbol_count = *(data++);
      for (unsigned i = 0; i < symbol_count; i++) {
        if (*(data++) == symbol) return section_value;
      }
    }
    return 0;
  } else {
    return self->parse_table[state * self->symbol_count + symbol];
  }
}

static inline TSStateId ts_language_next_state(const TSLanguage *self,
                                               TSStateId state,
                                               TSSymbol symbol) {
  if (symbol == ts_builtin_sym_error || symbol == ts_builtin_sym_error_repeat) {
    return 0;
  } else if (symbol < self->token_count) {
    uint32_t count;
    const TSParseAction *actions = ts_language_actions(self, state, symbol, &count);
    if (count > 0) {
      TSParseAction action = actions[count - 1];
      if (action.type == TSParseActionTypeShift || action.type == TSParseActionTypeRecover) {
        return action.params.state;
      }
    }
    return 0;
  } else {
    return ts_language_lookup(self, state, symbol);
  }
}

static inline const bool *
ts_language_enabled_external_tokens(const TSLanguage *self,
                                    unsigned external_scanner_state) {
  if (external_scanner_state == 0) {
    return NULL;
  } else {
    return self->external_scanner.states + self->external_token_count * external_scanner_state;
  }
}

static inline const TSSymbol *
ts_language_alias_sequence(const TSLanguage *self, uint32_t production_id) {
  return production_id > 0 ?
    self->alias_sequences + production_id * self->max_alias_sequence_length :
    NULL;
}

static inline void ts_language_field_map(
  const TSLanguage *self,
  uint32_t production_id,
  const TSFieldMapEntry **start,
  const TSFieldMapEntry **end
) {
  if (self->version < TREE_SITTER_LANGUAGE_VERSION_WITH_FIELDS || self->field_count == 0) {
    *start = NULL;
    *end = NULL;
    return;
  }

  TSFieldMapSlice slice = self->field_map_slices[production_id];
  *start = &self->field_map_entries[slice.index];
  *end = &self->field_map_entries[slice.index] + slice.length;
}

#ifdef __cplusplus
}
#endif

#endif  // TREE_SITTER_LANGUAGE_H_
