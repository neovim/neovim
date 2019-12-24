#include "./language.h"
#include "./subtree.h"
#include "./error_costs.h"
#include <string.h>

uint32_t ts_language_symbol_count(const TSLanguage *self) {
  return self->symbol_count + self->alias_count;
}

uint32_t ts_language_version(const TSLanguage *self) {
  return self->version;
}

uint32_t ts_language_field_count(const TSLanguage *self) {
  if (self->version >= TREE_SITTER_LANGUAGE_VERSION_WITH_FIELDS) {
    return self->field_count;
  } else {
    return 0;
  }
}

void ts_language_table_entry(
  const TSLanguage *self,
  TSStateId state,
  TSSymbol symbol,
  TableEntry *result
) {
  if (symbol == ts_builtin_sym_error || symbol == ts_builtin_sym_error_repeat) {
    result->action_count = 0;
    result->is_reusable = false;
    result->actions = NULL;
  } else {
    assert(symbol < self->token_count);
    uint32_t action_index = ts_language_lookup(self, state, symbol);
    const TSParseActionEntry *entry = &self->parse_actions[action_index];
    result->action_count = entry->count;
    result->is_reusable = entry->reusable;
    result->actions = (const TSParseAction *)(entry + 1);
  }
}

TSSymbolMetadata ts_language_symbol_metadata(
  const TSLanguage *self,
  TSSymbol symbol
) {
  if (symbol == ts_builtin_sym_error)  {
    return (TSSymbolMetadata){.visible = true, .named = true};
  } else if (symbol == ts_builtin_sym_error_repeat) {
    return (TSSymbolMetadata){.visible = false, .named = false};
  } else {
    return self->symbol_metadata[symbol];
  }
}

TSSymbol ts_language_public_symbol(
  const TSLanguage *self,
  TSSymbol symbol
) {
  if (symbol == ts_builtin_sym_error) return symbol;
  if (self->version >= TREE_SITTER_LANGUAGE_VERSION_WITH_SYMBOL_DEDUPING) {
    return self->public_symbol_map[symbol];
  } else {
    return symbol;
  }
}

const char *ts_language_symbol_name(
  const TSLanguage *self,
  TSSymbol symbol
) {
  if (symbol == ts_builtin_sym_error) {
    return "ERROR";
  } else if (symbol == ts_builtin_sym_error_repeat) {
    return "_ERROR";
  } else {
    return self->symbol_names[symbol];
  }
}

TSSymbol ts_language_symbol_for_name(
  const TSLanguage *self,
  const char *string,
  uint32_t length,
  bool is_named
) {
  if (!strncmp(string, "ERROR", length)) return ts_builtin_sym_error;
  uint32_t count = ts_language_symbol_count(self);
  for (TSSymbol i = 0; i < count; i++) {
    TSSymbolMetadata metadata = ts_language_symbol_metadata(self, i);
    if (!metadata.visible || metadata.named != is_named) continue;
    const char *symbol_name = self->symbol_names[i];
    if (!strncmp(symbol_name, string, length) && !symbol_name[length]) {
      if (self->version >= TREE_SITTER_LANGUAGE_VERSION_WITH_SYMBOL_DEDUPING) {
        return self->public_symbol_map[i];
      } else {
        return i;
      }
    }
  }
  return 0;
}

TSSymbolType ts_language_symbol_type(
  const TSLanguage *self,
  TSSymbol symbol
) {
  TSSymbolMetadata metadata = ts_language_symbol_metadata(self, symbol);
  if (metadata.named) {
    return TSSymbolTypeRegular;
  } else if (metadata.visible) {
    return TSSymbolTypeAnonymous;
  } else {
    return TSSymbolTypeAuxiliary;
  }
}

const char *ts_language_field_name_for_id(
  const TSLanguage *self,
  TSFieldId id
) {
  uint32_t count = ts_language_field_count(self);
  if (count) {
    return self->field_names[id];
  } else {
    return NULL;
  }
}

TSFieldId ts_language_field_id_for_name(
  const TSLanguage *self,
  const char *name,
  uint32_t name_length
) {
  uint32_t count = ts_language_field_count(self);
  for (TSSymbol i = 1; i < count + 1; i++) {
    switch (strncmp(name, self->field_names[i], name_length)) {
      case 0:
        if (self->field_names[i][name_length] == 0) return i;
        break;
      case -1:
        return 0;
      default:
        break;
    }
  }
  return 0;
}
