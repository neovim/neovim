#include "tree_sitter/api.h"
#include "./alloc.h"
#include "./array.h"
#include "./bits.h"
#include "./point.h"
#include "./tree_cursor.h"
#include <wctype.h>

/*
 * Stream - A sequence of unicode characters derived from a UTF8 string.
 * This struct is used in parsing queries from S-expressions.
 */
typedef struct {
  const char *input;
  const char *end;
  int32_t next;
  uint8_t next_size;
} Stream;

/*
 * QueryStep - A step in the process of matching a query. Each node within
 * a query S-expression maps to one of these steps. An entire pattern is
 * represented as a sequence of these steps. Fields:
 *
 * - `symbol` - The grammar symbol to match. A zero value represents the
 *    wildcard symbol, '*'.
 * - `field` - The field name to match. A zero value means that a field name
 *    was not specified.
 * - `capture_id` - An integer representing the name of the capture associated
 *    with this node in the pattern. A `NONE` value means this node is not
 *    captured in this pattern.
 * - `depth` - The depth where this node occurs in the pattern. The root node
 *    of the pattern has depth zero.
 */
typedef struct {
  TSSymbol symbol;
  TSFieldId field;
  uint16_t capture_id;
  uint16_t depth: 15;
  bool contains_captures: 1;
} QueryStep;

/*
 * Slice - A slice of an external array. Within a query, capture names,
 * literal string values, and predicate step informations are stored in three
 * contiguous arrays. Individual captures, string values, and predicates are
 * represented as slices of these three arrays.
 */
typedef struct {
  uint32_t offset;
  uint32_t length;
} Slice;

/*
 * SymbolTable - a two-way mapping of strings to ids.
 */
typedef struct {
  Array(char) characters;
  Array(Slice) slices;
} SymbolTable;

/*
 * PatternEntry - The set of steps needed to match a particular pattern,
 * represented as a slice of a shared array. These entries are stored in a
 * 'pattern map' - a sorted array that makes it possible to efficiently lookup
 * patterns based on the symbol for their first step.
 */
typedef struct {
  uint16_t step_index;
  uint16_t pattern_index;
} PatternEntry;

/*
 * QueryState - The state of an in-progress match of a particular pattern
 * in a query. While executing, a `TSQueryCursor` must keep track of a number
 * of possible in-progress matches. Each of those possible matches is
 * represented as one of these states.
 */
typedef struct {
  uint16_t start_depth;
  uint16_t pattern_index;
  uint16_t step_index;
  uint16_t capture_count;
  uint16_t capture_list_id;
  uint16_t consumed_capture_count;
  uint32_t id;
} QueryState;

/*
 * CaptureListPool - A collection of *lists* of captures. Each QueryState
 * needs to maintain its own list of captures. They are all represented as
 * slices of one shared array. The CaptureListPool keeps track of which
 * parts of the shared array are currently in use by a QueryState.
 */
typedef struct {
  Array(TSQueryCapture) list;
  uint32_t usage_map;
} CaptureListPool;

/*
 * TSQuery - A tree query, compiled from a string of S-expressions. The query
 * itself is immutable. The mutable state used in the process of executing the
 * query is stored in a `TSQueryCursor`.
 */
struct TSQuery {
  SymbolTable captures;
  SymbolTable predicate_values;
  Array(QueryStep) steps;
  Array(PatternEntry) pattern_map;
  Array(TSQueryPredicateStep) predicate_steps;
  Array(Slice) predicates_by_pattern;
  Array(uint32_t) start_bytes_by_pattern;
  const TSLanguage *language;
  uint16_t max_capture_count;
  uint16_t wildcard_root_pattern_count;
  TSSymbol *symbol_map;
};

/*
 * TSQueryCursor - A stateful struct used to execute a query on a tree.
 */
struct TSQueryCursor {
  const TSQuery *query;
  TSTreeCursor cursor;
  Array(QueryState) states;
  Array(QueryState) finished_states;
  CaptureListPool capture_list_pool;
  uint32_t depth;
  uint32_t start_byte;
  uint32_t end_byte;
  uint32_t next_state_id;
  TSPoint start_point;
  TSPoint end_point;
  bool ascending;
};

static const TSQueryError PARENT_DONE = -1;
static const uint8_t PATTERN_DONE_MARKER = UINT8_MAX;
static const uint16_t NONE = UINT16_MAX;
static const TSSymbol WILDCARD_SYMBOL = 0;
static const uint16_t MAX_STATE_COUNT = 32;

// #define LOG printf
#define LOG(...)

/**********
 * Stream
 **********/

// Advance to the next unicode code point in the stream.
static bool stream_advance(Stream *self) {
  self->input += self->next_size;
  if (self->input < self->end) {
    uint32_t size = ts_decode_utf8(
      (const uint8_t *)self->input,
      self->end - self->input,
      &self->next
    );
    if (size > 0) {
      self->next_size = size;
      return true;
    }
  } else {
    self->next_size = 0;
    self->next = '\0';
  }
  return false;
}

// Reset the stream to the given input position, represented as a pointer
// into the input string.
static void stream_reset(Stream *self, const char *input) {
  self->input = input;
  self->next_size = 0;
  stream_advance(self);
}

static Stream stream_new(const char *string, uint32_t length) {
  Stream self = {
    .next = 0,
    .input = string,
    .end = string + length,
  };
  stream_advance(&self);
  return self;
}

static void stream_skip_whitespace(Stream *stream) {
  for (;;) {
    if (iswspace(stream->next)) {
      stream_advance(stream);
    } else if (stream->next == ';') {
      // skip over comments
      stream_advance(stream);
      while (stream->next && stream->next != '\n') {
        if (!stream_advance(stream)) break;
      }
    } else {
      break;
    }
  }
}

static bool stream_is_ident_start(Stream *stream) {
  return iswalnum(stream->next) || stream->next == '_' || stream->next == '-';
}

static void stream_scan_identifier(Stream *stream) {
  do {
    stream_advance(stream);
  } while (
    iswalnum(stream->next) ||
    stream->next == '_' ||
    stream->next == '-' ||
    stream->next == '.' ||
    stream->next == '?' ||
    stream->next == '!'
  );
}

/******************
 * CaptureListPool
 ******************/

static CaptureListPool capture_list_pool_new() {
  return (CaptureListPool) {
    .list = array_new(),
    .usage_map = UINT32_MAX,
  };
}

static void capture_list_pool_reset(CaptureListPool *self, uint16_t list_size) {
  self->usage_map = UINT32_MAX;
  uint32_t total_size = MAX_STATE_COUNT * list_size;
  array_reserve(&self->list, total_size);
  self->list.size = total_size;
}

static void capture_list_pool_delete(CaptureListPool *self) {
  array_delete(&self->list);
}

static TSQueryCapture *capture_list_pool_get(CaptureListPool *self, uint16_t id) {
  return &self->list.contents[id * (self->list.size / MAX_STATE_COUNT)];
}

static uint16_t capture_list_pool_acquire(CaptureListPool *self) {
  // In the usage_map bitmask, ones represent free lists, and zeros represent
  // lists that are in use. A free list id can quickly be found by counting
  // the leading zeros in the usage map. An id of zero corresponds to the
  // highest-order bit in the bitmask.
  uint16_t id = count_leading_zeros(self->usage_map);
  if (id == 32) return NONE;
  self->usage_map &= ~bitmask_for_index(id);
  return id;
}

static void capture_list_pool_release(CaptureListPool *self, uint16_t id) {
  self->usage_map |= bitmask_for_index(id);
}

/**************
 * SymbolTable
 **************/

static SymbolTable symbol_table_new() {
  return (SymbolTable) {
    .characters = array_new(),
    .slices = array_new(),
  };
}

static void symbol_table_delete(SymbolTable *self) {
  array_delete(&self->characters);
  array_delete(&self->slices);
}

static int symbol_table_id_for_name(
  const SymbolTable *self,
  const char *name,
  uint32_t length
) {
  for (unsigned i = 0; i < self->slices.size; i++) {
    Slice slice = self->slices.contents[i];
    if (
      slice.length == length &&
      !strncmp(&self->characters.contents[slice.offset], name, length)
    ) return i;
  }
  return -1;
}

static const char *symbol_table_name_for_id(
  const SymbolTable *self,
  uint16_t id,
  uint32_t *length
) {
  Slice slice = self->slices.contents[id];
  *length = slice.length;
  return &self->characters.contents[slice.offset];
}

static uint16_t symbol_table_insert_name(
  SymbolTable *self,
  const char *name,
  uint32_t length
) {
  int id = symbol_table_id_for_name(self, name, length);
  if (id >= 0) return (uint16_t)id;
  Slice slice = {
    .offset = self->characters.size,
    .length = length,
  };
  array_grow_by(&self->characters, length + 1);
  memcpy(&self->characters.contents[slice.offset], name, length);
  self->characters.contents[self->characters.size - 1] = 0;
  array_push(&self->slices, slice);
  return self->slices.size - 1;
}

/*********
 * Query
 *********/

static TSSymbol ts_query_intern_node_name(
  const TSQuery *self,
  const char *name,
  uint32_t length,
  TSSymbolType symbol_type
) {
  if (!strncmp(name, "ERROR", length)) return ts_builtin_sym_error;
  uint32_t symbol_count = ts_language_symbol_count(self->language);
  for (TSSymbol i = 0; i < symbol_count; i++) {
    if (ts_language_symbol_type(self->language, i) != symbol_type) continue;
    const char *symbol_name = ts_language_symbol_name(self->language, i);
    if (!strncmp(symbol_name, name, length) && !symbol_name[length]) return i;
  }
  return 0;
}

// The `pattern_map` contains a mapping from TSSymbol values to indices in the
// `steps` array. For a given syntax node, the `pattern_map` makes it possible
// to quickly find the starting steps of all of the patterns whose root matches
// that node. Each entry has two fields: a `pattern_index`, which identifies one
// of the patterns in the query, and a `step_index`, which indicates the start
// offset of that pattern's steps pattern within the `steps` array.
//
// The entries are sorted by the patterns' root symbols, and lookups use a
// binary search. This ensures that the cost of this initial lookup step
// scales logarithmically with the number of patterns in the query.
//
// This returns `true` if the symbol is present and `false` otherwise.
// If the symbol is not present `*result` is set to the index where the
// symbol should be inserted.
static inline bool ts_query__pattern_map_search(
  const TSQuery *self,
  TSSymbol needle,
  uint32_t *result
) {
  uint32_t base_index = self->wildcard_root_pattern_count;
  uint32_t size = self->pattern_map.size - base_index;
  if (size == 0) {
    *result = base_index;
    return false;
  }
  while (size > 1) {
    uint32_t half_size = size / 2;
    uint32_t mid_index = base_index + half_size;
    TSSymbol mid_symbol = self->steps.contents[
      self->pattern_map.contents[mid_index].step_index
    ].symbol;
    if (needle > mid_symbol) base_index = mid_index;
    size -= half_size;
  }

  TSSymbol symbol = self->steps.contents[
    self->pattern_map.contents[base_index].step_index
  ].symbol;

  if (needle > symbol) {
    base_index++;
    if (base_index < self->pattern_map.size) {
      symbol = self->steps.contents[
        self->pattern_map.contents[base_index].step_index
      ].symbol;
    }
  }

  *result = base_index;
  return needle == symbol;
}

// Insert a new pattern's start index into the pattern map, maintaining
// the pattern map's ordering invariant.
static inline void ts_query__pattern_map_insert(
  TSQuery *self,
  TSSymbol symbol,
  uint32_t start_step_index
) {
  uint32_t index;
  ts_query__pattern_map_search(self, symbol, &index);
  array_insert(&self->pattern_map, index, ((PatternEntry) {
    .step_index = start_step_index,
    .pattern_index = self->pattern_map.size,
  }));
}

static void ts_query__finalize_steps(TSQuery *self) {
  for (unsigned i = 0; i < self->steps.size; i++) {
    QueryStep *step = &self->steps.contents[i];
    uint32_t depth = step->depth;
    if (step->capture_id != NONE) {
      step->contains_captures = true;
    } else {
      step->contains_captures = false;
      for (unsigned j = i + 1; j < self->steps.size; j++) {
        QueryStep *s = &self->steps.contents[j];
        if (s->depth == PATTERN_DONE_MARKER || s->depth <= depth) break;
        if (s->capture_id != NONE) step->contains_captures = true;
      }
    }
  }
}

// Parse a single predicate associated with a pattern, adding it to the
// query's internal `predicate_steps` array. Predicates are arbitrary
// S-expressions associated with a pattern which are meant to be handled at
// a higher level of abstraction, such as the Rust/JavaScript bindings. They
// can contain '@'-prefixed capture names, double-quoted strings, and bare
// symbols, which also represent strings.
static TSQueryError ts_query_parse_predicate(
  TSQuery *self,
  Stream *stream
) {
  if (stream->next == ')') return PARENT_DONE;
  if (stream->next != '(') return TSQueryErrorSyntax;
  stream_advance(stream);
  stream_skip_whitespace(stream);

  unsigned step_count = 0;
  for (;;) {
    if (stream->next == ')') {
      stream_advance(stream);
      stream_skip_whitespace(stream);
      array_back(&self->predicates_by_pattern)->length++;
      array_push(&self->predicate_steps, ((TSQueryPredicateStep) {
        .type = TSQueryPredicateStepTypeDone,
        .value_id = 0,
      }));
      break;
    }

    // Parse an '@'-prefixed capture name
    else if (stream->next == '@') {
      stream_advance(stream);

      // Parse the capture name
      if (!stream_is_ident_start(stream)) return TSQueryErrorSyntax;
      const char *capture_name = stream->input;
      stream_scan_identifier(stream);
      uint32_t length = stream->input - capture_name;

      // Add the capture id to the first step of the pattern
      int capture_id = symbol_table_id_for_name(
        &self->captures,
        capture_name,
        length
      );
      if (capture_id == -1) {
        stream_reset(stream, capture_name);
        return TSQueryErrorCapture;
      }

      array_back(&self->predicates_by_pattern)->length++;
      array_push(&self->predicate_steps, ((TSQueryPredicateStep) {
        .type = TSQueryPredicateStepTypeCapture,
        .value_id = capture_id,
      }));
    }

    // Parse a string literal
    else if (stream->next == '"') {
      stream_advance(stream);

      // Parse the string content
      const char *string_content = stream->input;
      while (stream->next != '"') {
        if (stream->next == '\n' || !stream_advance(stream)) {
          stream_reset(stream, string_content - 1);
          return TSQueryErrorSyntax;
        }
      }
      uint32_t length = stream->input - string_content;

      // Add a step for the node
      uint16_t id = symbol_table_insert_name(
        &self->predicate_values,
        string_content,
        length
      );
      array_back(&self->predicates_by_pattern)->length++;
      array_push(&self->predicate_steps, ((TSQueryPredicateStep) {
        .type = TSQueryPredicateStepTypeString,
        .value_id = id,
      }));

      if (stream->next != '"') return TSQueryErrorSyntax;
      stream_advance(stream);
    }

    // Parse a bare symbol
    else if (stream_is_ident_start(stream)) {
      const char *symbol_start = stream->input;
      stream_scan_identifier(stream);
      uint32_t length = stream->input - symbol_start;
      uint16_t id = symbol_table_insert_name(
        &self->predicate_values,
        symbol_start,
        length
      );
      array_back(&self->predicates_by_pattern)->length++;
      array_push(&self->predicate_steps, ((TSQueryPredicateStep) {
        .type = TSQueryPredicateStepTypeString,
        .value_id = id,
      }));
    }

    else {
      return TSQueryErrorSyntax;
    }

    step_count++;
    stream_skip_whitespace(stream);
  }

  return 0;
}

// Read one S-expression pattern from the stream, and incorporate it into
// the query's internal state machine representation. For nested patterns,
// this function calls itself recursively.
static TSQueryError ts_query_parse_pattern(
  TSQuery *self,
  Stream *stream,
  uint32_t depth,
  uint32_t *capture_count
) {
  uint16_t starting_step_index = self->steps.size;

  if (stream->next == 0) return TSQueryErrorSyntax;

  // Finish the parent S-expression
  if (stream->next == ')') {
    return PARENT_DONE;
  }

  // Parse a parenthesized node expression
  else if (stream->next == '(') {
    stream_advance(stream);
    stream_skip_whitespace(stream);

    // Parse a nested list, which represents a pattern followed by
    // zero-or-more predicates.
    if (stream->next == '(' && depth == 0) {
      TSQueryError e = ts_query_parse_pattern(self, stream, 0, capture_count);
      if (e) return e;

      // Parse the predicates.
      stream_skip_whitespace(stream);
      for (;;) {
        TSQueryError e = ts_query_parse_predicate(self, stream);
        if (e == PARENT_DONE) {
          stream_advance(stream);
          stream_skip_whitespace(stream);
          return 0;
        } else if (e) {
          return e;
        }
      }
    }

    TSSymbol symbol;

    // Parse the wildcard symbol
    if (stream->next == '*') {
      symbol = WILDCARD_SYMBOL;
      stream_advance(stream);
    }

    // Parse a normal node name
    else if (stream_is_ident_start(stream)) {
      const char *node_name = stream->input;
      stream_scan_identifier(stream);
      uint32_t length = stream->input - node_name;
      symbol = ts_query_intern_node_name(
        self,
        node_name,
        length,
        TSSymbolTypeRegular
      );
      if (!symbol) {
        stream_reset(stream, node_name);
        return TSQueryErrorNodeType;
      }
    } else {
      return TSQueryErrorSyntax;
    }

    // Add a step for the node.
    array_push(&self->steps, ((QueryStep) {
      .depth = depth,
      .symbol = symbol,
      .field = 0,
      .capture_id = NONE,
      .contains_captures = false,
    }));

    // Parse the child patterns
    stream_skip_whitespace(stream);
    for (;;) {
      TSQueryError e = ts_query_parse_pattern(self, stream, depth + 1, capture_count);
      if (e == PARENT_DONE) {
        stream_advance(stream);
        break;
      } else if (e) {
        return e;
      }
    }
  }

  // Parse a double-quoted anonymous leaf node expression
  else if (stream->next == '"') {
    stream_advance(stream);

    // Parse the string content
    const char *string_content = stream->input;
    while (stream->next != '"') {
      if (!stream_advance(stream)) {
        stream_reset(stream, string_content - 1);
        return TSQueryErrorSyntax;
      }
    }
    uint32_t length = stream->input - string_content;

    // Add a step for the node
    TSSymbol symbol = ts_query_intern_node_name(
      self,
      string_content,
      length,
      TSSymbolTypeAnonymous
    );
    if (!symbol) {
      stream_reset(stream, string_content);
      return TSQueryErrorNodeType;
    }
    array_push(&self->steps, ((QueryStep) {
      .depth = depth,
      .symbol = symbol,
      .field = 0,
      .capture_id = NONE,
      .contains_captures = false,
    }));

    if (stream->next != '"') return TSQueryErrorSyntax;
    stream_advance(stream);
  }

  // Parse a field-prefixed pattern
  else if (stream_is_ident_start(stream)) {
    // Parse the field name
    const char *field_name = stream->input;
    stream_scan_identifier(stream);
    uint32_t length = stream->input - field_name;
    stream_skip_whitespace(stream);

    if (stream->next != ':') {
      stream_reset(stream, field_name);
      return TSQueryErrorSyntax;
    }
    stream_advance(stream);
    stream_skip_whitespace(stream);

    // Parse the pattern
    uint32_t step_index = self->steps.size;
    TSQueryError e = ts_query_parse_pattern(self, stream, depth, capture_count);
    if (e == PARENT_DONE) return TSQueryErrorSyntax;
    if (e) return e;

    // Add the field name to the first step of the pattern
    TSFieldId field_id = ts_language_field_id_for_name(
      self->language,
      field_name,
      length
    );
    if (!field_id) {
      stream->input = field_name;
      return TSQueryErrorField;
    }
    self->steps.contents[step_index].field = field_id;
  }

  // Parse a wildcard pattern
  else if (stream->next == '*') {
    stream_advance(stream);
    stream_skip_whitespace(stream);

    // Add a step that matches any kind of node
    array_push(&self->steps, ((QueryStep) {
      .depth = depth,
      .symbol = WILDCARD_SYMBOL,
      .field = 0,
      .contains_captures = false,
    }));
  }

  else {
    return TSQueryErrorSyntax;
  }

  stream_skip_whitespace(stream);

  // Parse an '@'-prefixed capture pattern
  if (stream->next == '@') {
    stream_advance(stream);

    // Parse the capture name
    if (!stream_is_ident_start(stream)) return TSQueryErrorSyntax;
    const char *capture_name = stream->input;
    stream_scan_identifier(stream);
    uint32_t length = stream->input - capture_name;

    // Add the capture id to the first step of the pattern
    uint16_t capture_id = symbol_table_insert_name(
      &self->captures,
      capture_name,
      length
    );
    self->steps.contents[starting_step_index].capture_id = capture_id;
    (*capture_count)++;

    stream_skip_whitespace(stream);
  }

  return 0;
}

TSQuery *ts_query_new(
  const TSLanguage *language,
  const char *source,
  uint32_t source_len,
  uint32_t *error_offset,
  TSQueryError *error_type
) {
  // Work around the fact that multiple symbols can currently be
  // associated with the same name, due to "simple aliases".
  // In the next language ABI version, this map should be contained
  // within the language itself.
  uint32_t symbol_count = ts_language_symbol_count(language);
  TSSymbol *symbol_map = ts_malloc(sizeof(TSSymbol) * symbol_count);
  for (unsigned i = 0; i < symbol_count; i++) {
    const char *name = ts_language_symbol_name(language, i);
    const TSSymbolType symbol_type = ts_language_symbol_type(language, i);

    symbol_map[i] = i;
    for (unsigned j = 0; j < i; j++) {
      if (ts_language_symbol_type(language, j) == symbol_type) {
        if (!strcmp(name, ts_language_symbol_name(language, j))) {
          symbol_map[i] = j;
          break;
        }
      }
    }
  }

  TSQuery *self = ts_malloc(sizeof(TSQuery));
  *self = (TSQuery) {
    .steps = array_new(),
    .pattern_map = array_new(),
    .captures = symbol_table_new(),
    .predicate_values = symbol_table_new(),
    .predicate_steps = array_new(),
    .predicates_by_pattern = array_new(),
    .symbol_map = symbol_map,
    .wildcard_root_pattern_count = 0,
    .max_capture_count = 0,
    .language = language,
  };

  // Parse all of the S-expressions in the given string.
  Stream stream = stream_new(source, source_len);
  stream_skip_whitespace(&stream);
  uint32_t start_step_index;
  while (stream.input < stream.end) {
    start_step_index = self->steps.size;
    uint32_t capture_count = 0;
    array_push(&self->start_bytes_by_pattern, stream.input - source);
    array_push(&self->predicates_by_pattern, ((Slice) {
      .offset = self->predicate_steps.size,
      .length = 0,
    }));
    *error_type = ts_query_parse_pattern(self, &stream, 0, &capture_count);
    array_push(&self->steps, ((QueryStep) { .depth = PATTERN_DONE_MARKER }));

    // If any pattern could not be parsed, then report the error information
    // and terminate.
    if (*error_type) {
      *error_offset = stream.input - source;
      ts_query_delete(self);
      return NULL;
    }

    // Maintain a map that can look up patterns for a given root symbol.
    ts_query__pattern_map_insert(
      self,
      self->steps.contents[start_step_index].symbol,
      start_step_index
    );
    if (self->steps.contents[start_step_index].symbol == WILDCARD_SYMBOL) {
      self->wildcard_root_pattern_count++;
    }

    // Keep track of the maximum number of captures in pattern, because
    // that numer determines how much space is needed to store each capture
    // list.
    if (capture_count > self->max_capture_count) {
      self->max_capture_count = capture_count;
    }
  }

  ts_query__finalize_steps(self);
  return self;
}

void ts_query_delete(TSQuery *self) {
  if (self) {
    array_delete(&self->steps);
    array_delete(&self->pattern_map);
    array_delete(&self->predicate_steps);
    array_delete(&self->predicates_by_pattern);
    array_delete(&self->start_bytes_by_pattern);
    symbol_table_delete(&self->captures);
    symbol_table_delete(&self->predicate_values);
    ts_free(self->symbol_map);
    ts_free(self);
  }
}

uint32_t ts_query_pattern_count(const TSQuery *self) {
  return self->predicates_by_pattern.size;
}

uint32_t ts_query_capture_count(const TSQuery *self) {
  return self->captures.slices.size;
}

uint32_t ts_query_string_count(const TSQuery *self) {
  return self->predicate_values.slices.size;
}

const char *ts_query_capture_name_for_id(
  const TSQuery *self,
  uint32_t index,
  uint32_t *length
) {
  return symbol_table_name_for_id(&self->captures, index, length);
}

const char *ts_query_string_value_for_id(
  const TSQuery *self,
  uint32_t index,
  uint32_t *length
) {
  return symbol_table_name_for_id(&self->predicate_values, index, length);
}

const TSQueryPredicateStep *ts_query_predicates_for_pattern(
  const TSQuery *self,
  uint32_t pattern_index,
  uint32_t *step_count
) {
  Slice slice = self->predicates_by_pattern.contents[pattern_index];
  *step_count = slice.length;
  return &self->predicate_steps.contents[slice.offset];
}

uint32_t ts_query_start_byte_for_pattern(
  const TSQuery *self,
  uint32_t pattern_index
) {
  return self->start_bytes_by_pattern.contents[pattern_index];
}

void ts_query_disable_capture(
  TSQuery *self,
  const char *name,
  uint32_t length
) {
  int id = symbol_table_id_for_name(&self->captures, name, length);
  if (id != -1) {
    for (unsigned i = 0; i < self->steps.size; i++) {
      QueryStep *step = &self->steps.contents[i];
      if (step->capture_id == id) {
        step->capture_id = NONE;
      }
    }
  }
  ts_query__finalize_steps(self);
}

/***************
 * QueryCursor
 ***************/

TSQueryCursor *ts_query_cursor_new() {
  TSQueryCursor *self = ts_malloc(sizeof(TSQueryCursor));
  *self = (TSQueryCursor) {
    .ascending = false,
    .states = array_new(),
    .finished_states = array_new(),
    .capture_list_pool = capture_list_pool_new(),
    .start_byte = 0,
    .end_byte = UINT32_MAX,
    .start_point = {0, 0},
    .end_point = POINT_MAX,
  };
  array_reserve(&self->states, MAX_STATE_COUNT);
  array_reserve(&self->finished_states, MAX_STATE_COUNT);
  return self;
}

void ts_query_cursor_delete(TSQueryCursor *self) {
  array_delete(&self->states);
  array_delete(&self->finished_states);
  ts_tree_cursor_delete(&self->cursor);
  capture_list_pool_delete(&self->capture_list_pool);
  ts_free(self);
}

void ts_query_cursor_exec(
  TSQueryCursor *self,
  const TSQuery *query,
  TSNode node
) {
  array_clear(&self->states);
  array_clear(&self->finished_states);
  ts_tree_cursor_reset(&self->cursor, node);
  capture_list_pool_reset(&self->capture_list_pool, query->max_capture_count);
  self->next_state_id = 0;
  self->depth = 0;
  self->ascending = false;
  self->query = query;
}

void ts_query_cursor_set_byte_range(
  TSQueryCursor *self,
  uint32_t start_byte,
  uint32_t end_byte
) {
  if (end_byte == 0) {
    start_byte = 0;
    end_byte = UINT32_MAX;
  }
  self->start_byte = start_byte;
  self->end_byte = end_byte;
}

void ts_query_cursor_set_point_range(
  TSQueryCursor *self,
  TSPoint start_point,
  TSPoint end_point
) {
  if (end_point.row == 0 && end_point.column == 0) {
    start_point = POINT_ZERO;
    end_point = POINT_MAX;
  }
  self->start_point = start_point;
  self->end_point = end_point;
}

static QueryState *ts_query_cursor_copy_state(
  TSQueryCursor *self,
  const QueryState *state
) {
  uint32_t new_list_id = capture_list_pool_acquire(&self->capture_list_pool);
  if (new_list_id == NONE) return NULL;
  array_push(&self->states, *state);
  QueryState *new_state = array_back(&self->states);
  new_state->capture_list_id = new_list_id;
  TSQueryCapture *old_captures = capture_list_pool_get(
    &self->capture_list_pool,
    state->capture_list_id
  );
  TSQueryCapture *new_captures = capture_list_pool_get(
    &self->capture_list_pool,
    new_list_id
  );
  memcpy(new_captures, old_captures, state->capture_count * sizeof(TSQueryCapture));
  return new_state;
}

// Walk the tree, processing patterns until at least one pattern finishes,
// If one or more patterns finish, return `true` and store their states in the
// `finished_states` array. Multiple patterns can finish on the same node. If
// there are no more matches, return `false`.
static inline bool ts_query_cursor__advance(TSQueryCursor *self) {
  do {
    if (self->ascending) {
      LOG("leave node %s\n", ts_node_type(ts_tree_cursor_current_node(&self->cursor)));

      // When leaving a node, remove any unfinished states whose next step
      // needed to match something within that node.
      uint32_t deleted_count = 0;
      for (unsigned i = 0, n = self->states.size; i < n; i++) {
        QueryState *state = &self->states.contents[i];
        QueryStep *step = &self->query->steps.contents[state->step_index];

        if (state->start_depth + step->depth > self->depth) {
          LOG(
            "  failed to match. pattern:%u, step:%u\n",
            state->pattern_index,
            state->step_index
          );

          capture_list_pool_release(
            &self->capture_list_pool,
            state->capture_list_id
          );
          deleted_count++;
        } else if (deleted_count > 0) {
          self->states.contents[i - deleted_count] = *state;
        }
      }

      self->states.size -= deleted_count;

      if (ts_tree_cursor_goto_next_sibling(&self->cursor)) {
        self->ascending = false;
      } else if (ts_tree_cursor_goto_parent(&self->cursor)) {
        self->depth--;
      } else {
        return self->finished_states.size > 0;
      }
    } else {
      bool can_have_later_siblings;
      bool can_have_later_siblings_with_this_field;
      TSFieldId field_id = ts_tree_cursor_current_status(
        &self->cursor,
        &can_have_later_siblings,
        &can_have_later_siblings_with_this_field
      );
      TSNode node = ts_tree_cursor_current_node(&self->cursor);
      TSSymbol symbol = ts_node_symbol(node);
      if (symbol != ts_builtin_sym_error) {
        symbol = self->query->symbol_map[symbol];
      }

      // If this node is before the selected range, then avoid descending
      // into it.
      if (
        ts_node_end_byte(node) <= self->start_byte ||
        point_lte(ts_node_end_point(node), self->start_point)
      ) {
        if (!ts_tree_cursor_goto_next_sibling(&self->cursor)) {
          self->ascending = true;
        }
        continue;
      }

      // If this node is after the selected range, then stop walking.
      if (
        self->end_byte <= ts_node_start_byte(node) ||
        point_lte(self->end_point, ts_node_start_point(node))
      ) return false;

      LOG(
        "enter node %s. row:%u state_count:%u, finished_state_count: %u\n",
        ts_node_type(node),
        ts_node_start_point(node).row,
        self->states.size,
        self->finished_states.size
      );

      // Add new states for any patterns whose root node is a wildcard.
      for (unsigned i = 0; i < self->query->wildcard_root_pattern_count; i++) {
        PatternEntry *slice = &self->query->pattern_map.contents[i];
        QueryStep *step = &self->query->steps.contents[slice->step_index];

        // If this node matches the first step of the pattern, then add a new
        // state at the start of this pattern.
        if (step->field && field_id != step->field) continue;
        uint32_t capture_list_id = capture_list_pool_acquire(
          &self->capture_list_pool
        );
        if (capture_list_id == NONE) break;
        array_push(&self->states, ((QueryState)  {
          .step_index = slice->step_index,
          .pattern_index = slice->pattern_index,
          .capture_list_id = capture_list_id,
          .capture_count = 0,
          .consumed_capture_count = 0,
        }));
      }

      // Add new states for any patterns whose root node matches this node.
      unsigned i;
      if (ts_query__pattern_map_search(self->query, symbol, &i)) {
        PatternEntry *slice = &self->query->pattern_map.contents[i];
        QueryStep *step = &self->query->steps.contents[slice->step_index];
        do {
          if (step->field && field_id != step->field) continue;

          LOG("  start state. pattern:%u\n", slice->pattern_index);

          // If this node matches the first step of the pattern, then add a
          // new in-progress state. First, acquire a list to hold the pattern's
          // captures.
          uint32_t capture_list_id = capture_list_pool_acquire(
            &self->capture_list_pool
          );
          if (capture_list_id == NONE) {
            LOG("  too many states.");
            break;
          }

          array_push(&self->states, ((QueryState) {
            .pattern_index = slice->pattern_index,
            .step_index = slice->step_index,
            .start_depth = self->depth,
            .capture_list_id = capture_list_id,
            .capture_count = 0,
            .consumed_capture_count = 0,
          }));

          // Advance to the next pattern whose root node matches this node.
          i++;
          if (i == self->query->pattern_map.size) break;
          slice = &self->query->pattern_map.contents[i];
          step = &self->query->steps.contents[slice->step_index];
        } while (step->symbol == symbol);
      }

      // Update all of the in-progress states with current node.
      for (unsigned i = 0, n = self->states.size; i < n; i++) {
        QueryState *state = &self->states.contents[i];
        QueryStep *step = &self->query->steps.contents[state->step_index];

        // Check that the node matches all of the criteria for the next
        // step of the pattern.if (
        if (state->start_depth + step->depth != self->depth) continue;

        // Determine if this node matches this step of the pattern, and also
        // if this node can have later siblings that match this step of the
        // pattern.
        bool node_does_match = !step->symbol || step->symbol == symbol;
        bool later_sibling_can_match = can_have_later_siblings;
        if (step->field) {
          if (step->field == field_id) {
            if (!can_have_later_siblings_with_this_field) {
              later_sibling_can_match = false;
            }
          } else {
            node_does_match = false;
          }
        }

        if (!node_does_match) {
          if (!later_sibling_can_match) {
            LOG(
              "  discard state. pattern:%u, step:%u\n",
              state->pattern_index,
              state->step_index
            );
            capture_list_pool_release(
              &self->capture_list_pool,
              state->capture_list_id
            );
            array_erase(&self->states, i);
            i--;
            n--;
          }
          continue;
        }

        // Some patterns can match their root node in multiple ways,
        // capturing different children. If this pattern step could match
        // later children within the same parent, then this query state
        // cannot simply be updated in place. It must be split into two
        // states: one that matches this node, and one which skips over
        // this node, to preserve the possibility of matching later
        // siblings.
        QueryState *next_state = state;
        if (
          step->depth > 0 &&
          step->contains_captures &&
          later_sibling_can_match
        ) {
          LOG(
            "  split state. pattern:%u, step:%u\n",
            state->pattern_index,
            state->step_index
          );
          QueryState *copy = ts_query_cursor_copy_state(self, state);
          if (copy) next_state = copy;
        }

        LOG(
          "  advance state. pattern:%u, step:%u\n",
          next_state->pattern_index,
          next_state->step_index
        );

        // If the current node is captured in this pattern, add it to the
        // capture list.
        if (step->capture_id != NONE) {
          LOG(
            "  capture node. pattern:%u, capture_id:%u\n",
            next_state->pattern_index,
            step->capture_id
          );
          TSQueryCapture *capture_list = capture_list_pool_get(
            &self->capture_list_pool,
            next_state->capture_list_id
          );
          capture_list[next_state->capture_count++] = (TSQueryCapture) {
            node,
            step->capture_id
          };
        }

        // If the pattern is now done, then remove it from the list of
        // in-progress states, and add it to the list of finished states.
        next_state->step_index++;
        QueryStep *next_step = step + 1;
        if (next_step->depth == PATTERN_DONE_MARKER) {
          LOG("  finish pattern %u\n", next_state->pattern_index);

          next_state->id = self->next_state_id++;
          array_push(&self->finished_states, *next_state);
          if (next_state == state) {
            array_erase(&self->states, i);
            i--;
            n--;
          } else {
            array_pop(&self->states);
          }
        }
      }

      // Continue descending if possible.
      if (ts_tree_cursor_goto_first_child(&self->cursor)) {
        self->depth++;
      } else {
        self->ascending = true;
      }
    }
  } while (self->finished_states.size == 0);

  return true;
}

bool ts_query_cursor_next_match(
  TSQueryCursor *self,
  TSQueryMatch *match
) {
  if (self->finished_states.size == 0) {
    if (!ts_query_cursor__advance(self)) {
      return false;
    }
  }

  QueryState *state = &self->finished_states.contents[0];
  match->id = state->id;
  match->pattern_index = state->pattern_index;
  match->capture_count = state->capture_count;
  match->captures = capture_list_pool_get(
    &self->capture_list_pool,
    state->capture_list_id
  );
  capture_list_pool_release(&self->capture_list_pool, state->capture_list_id);
  array_erase(&self->finished_states, 0);
  return true;
}

void ts_query_cursor_remove_match(
  TSQueryCursor *self,
  uint32_t match_id
) {
  for (unsigned i = 0; i < self->finished_states.size; i++) {
    const QueryState *state = &self->finished_states.contents[i];
    if (state->id == match_id) {
      capture_list_pool_release(
        &self->capture_list_pool,
        state->capture_list_id
      );
      array_erase(&self->finished_states, i);
      return;
    }
  }
}

bool ts_query_cursor_next_capture(
  TSQueryCursor *self,
  TSQueryMatch *match,
  uint32_t *capture_index
) {
  for (;;) {
    // The goal here is to return captures in order, even though they may not
    // be discovered in order, because patterns can overlap. If there are any
    // finished patterns, then try to find one that contains a capture that
    // is *definitely* before any capture in an *unfinished* pattern.
    if (self->finished_states.size > 0) {
      // First, identify the position of the earliest capture in an unfinished
      // match. For a finished capture to be returned, it must be *before*
      // this position.
      uint32_t first_unfinished_capture_byte = UINT32_MAX;
      uint32_t first_unfinished_pattern_index = UINT32_MAX;
      for (unsigned i = 0; i < self->states.size; i++) {
        const QueryState *state = &self->states.contents[i];
        if (state->capture_count > 0) {
          const TSQueryCapture *captures = capture_list_pool_get(
            &self->capture_list_pool,
            state->capture_list_id
          );
          uint32_t capture_byte = ts_node_start_byte(captures[0].node);
          if (
            capture_byte < first_unfinished_capture_byte ||
            (
              capture_byte == first_unfinished_capture_byte &&
              state->pattern_index < first_unfinished_pattern_index
            )
          ) {
            first_unfinished_capture_byte = capture_byte;
            first_unfinished_pattern_index = state->pattern_index;
          }
        }
      }

      // Find the earliest capture in a finished match.
      int first_finished_state_index = -1;
      uint32_t first_finished_capture_byte = first_unfinished_capture_byte;
      uint32_t first_finished_pattern_index = first_unfinished_pattern_index;
      for (unsigned i = 0; i < self->finished_states.size; i++) {
        const QueryState *state = &self->finished_states.contents[i];
        if (state->capture_count > state->consumed_capture_count) {
          const TSQueryCapture *captures = capture_list_pool_get(
            &self->capture_list_pool,
            state->capture_list_id
          );
          uint32_t capture_byte = ts_node_start_byte(
            captures[state->consumed_capture_count].node
          );
          if (
            capture_byte < first_finished_capture_byte ||
            (
              capture_byte == first_finished_capture_byte &&
              state->pattern_index < first_finished_pattern_index
            )
          ) {
            first_finished_state_index = i;
            first_finished_capture_byte = capture_byte;
            first_finished_pattern_index = state->pattern_index;
          }
        } else {
          capture_list_pool_release(
            &self->capture_list_pool,
            state->capture_list_id
          );
          array_erase(&self->finished_states, i);
          i--;
        }
      }

      // If there is finished capture that is clearly before any unfinished
      // capture, then return its match, and its capture index. Internally
      // record the fact that the capture has been 'consumed'.
      if (first_finished_state_index != -1) {
        QueryState *state = &self->finished_states.contents[
          first_finished_state_index
        ];
        match->id = state->id;
        match->pattern_index = state->pattern_index;
        match->capture_count = state->capture_count;
        match->captures = capture_list_pool_get(
          &self->capture_list_pool,
          state->capture_list_id
        );
        *capture_index = state->consumed_capture_count;
        state->consumed_capture_count++;
        return true;
      }
    }

    // If there are no finished matches that are ready to be returned, then
    // continue finding more matches.
    if (!ts_query_cursor__advance(self)) return false;
  }
}

#undef LOG
