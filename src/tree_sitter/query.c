#include "tree_sitter/api.h"
#include "./alloc.h"
#include "./array.h"
#include "./bits.h"
#include "./language.h"
#include "./point.h"
#include "./tree_cursor.h"
#include "./unicode.h"
#include <wctype.h>

// #define LOG(...) fprintf(stderr, __VA_ARGS__)
#define LOG(...)

#define MAX_CAPTURE_LIST_COUNT 32
#define MAX_STEP_CAPTURE_COUNT 3

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
 *    wildcard symbol, '_'.
 * - `field` - The field name to match. A zero value means that a field name
 *    was not specified.
 * - `capture_ids` - An array of integers representing the names of captures
 *    associated with this node in the pattern, terminated by a `NONE` value.
 * - `depth` - The depth where this node occurs in the pattern. The root node
 *    of the pattern has depth zero.
 * - `alternative_index` - The index of a different query step that serves as
 *    an alternative to this step.
 */
typedef struct {
  TSSymbol symbol;
  TSFieldId field;
  uint16_t capture_ids[MAX_STEP_CAPTURE_COUNT];
  uint16_t alternative_index;
  uint16_t depth;
  bool contains_captures: 1;
  bool is_immediate: 1;
  bool is_last_child: 1;
  bool is_pass_through: 1;
  bool is_dead_end: 1;
  bool alternative_is_immediate: 1;
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
 * PatternEntry - Information about the starting point for matching a
 * particular pattern, consisting of the index of the pattern within the query,
 * and the index of the patter's first step in the shared `steps` array. These
 * entries are stored in a 'pattern map' - a sorted array that makes it
 * possible to efficiently lookup patterns based on the symbol for their first
 * step.
 */
typedef struct {
  uint16_t step_index;
  uint16_t pattern_index;
} PatternEntry;

/*
 * QueryState - The state of an in-progress match of a particular pattern
 * in a query. While executing, a `TSQueryCursor` must keep track of a number
 * of possible in-progress matches. Each of those possible matches is
 * represented as one of these states. Fields:
 * - `id` - A numeric id that is exposed to the public API. This allows the
 *    caller to remove a given match, preventing any more of its captures
 *    from being returned.
 * - `start_depth` - The depth in the tree where the first step of the state's
 *    pattern was matched.
 * - `pattern_index` - The pattern that the state is matching.
 * - `consumed_capture_count` - The number of captures from this match that
 *    have already been returned.
 * - `capture_list_id` - A numeric id that can be used to retrieve the state's
 *    list of captures from the `CaptureListPool`.
 * - `seeking_immediate_match` - A flag that indicates that the state's next
 *    step must be matched by the very next sibling. This is used when
 *    processing repetitions.
 * - `has_in_progress_alternatives` - A flag that indicates that there is are
 *    other states that have the same captures as this state, but are at
 *    different steps in their pattern. This means that in order to obey the
 *    'longest-match' rule, this state should not be returned as a match until
 *    it is clear that there can be no longer match.
 */
typedef struct {
  uint32_t id;
  uint16_t start_depth;
  uint16_t step_index;
  uint16_t pattern_index;
  uint16_t capture_list_id;
  uint16_t consumed_capture_count: 12;
  bool seeking_immediate_match: 1;
  bool has_in_progress_alternatives: 1;
  bool dead: 1;
} QueryState;

typedef Array(TSQueryCapture) CaptureList;

/*
 * CaptureListPool - A collection of *lists* of captures. Each QueryState
 * needs to maintain its own list of captures. To avoid repeated allocations,
 * the reuses a fixed set of capture lists, and keeps track of which ones
 * are currently in use.
 */
typedef struct {
  CaptureList list[MAX_CAPTURE_LIST_COUNT];
  CaptureList empty_list;
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
  bool halted;
};

static const TSQueryError PARENT_DONE = -1;
static const uint16_t PATTERN_DONE_MARKER = UINT16_MAX;
static const uint16_t NONE = UINT16_MAX;
static const TSSymbol WILDCARD_SYMBOL = 0;
static const TSSymbol NAMED_WILDCARD_SYMBOL = UINT16_MAX - 1;

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

static CaptureListPool capture_list_pool_new(void) {
  return (CaptureListPool) {
    .empty_list = array_new(),
    .usage_map = UINT32_MAX,
  };
}

static void capture_list_pool_reset(CaptureListPool *self) {
  self->usage_map = UINT32_MAX;
  for (unsigned i = 0; i < MAX_CAPTURE_LIST_COUNT; i++) {
    array_clear(&self->list[i]);
  }
}

static void capture_list_pool_delete(CaptureListPool *self) {
  for (unsigned i = 0; i < MAX_CAPTURE_LIST_COUNT; i++) {
    array_delete(&self->list[i]);
  }
}

static const CaptureList *capture_list_pool_get(const CaptureListPool *self, uint16_t id) {
  if (id >= MAX_CAPTURE_LIST_COUNT) return &self->empty_list;
  return &self->list[id];
}

static CaptureList *capture_list_pool_get_mut(CaptureListPool *self, uint16_t id) {
  assert(id < MAX_CAPTURE_LIST_COUNT);
  return &self->list[id];
}

static bool capture_list_pool_is_empty(const CaptureListPool *self) {
  return self->usage_map == 0;
}

static uint16_t capture_list_pool_acquire(CaptureListPool *self) {
  // In the usage_map bitmask, ones represent free lists, and zeros represent
  // lists that are in use. A free list id can quickly be found by counting
  // the leading zeros in the usage map. An id of zero corresponds to the
  // highest-order bit in the bitmask.
  uint16_t id = count_leading_zeros(self->usage_map);
  if (id >= MAX_CAPTURE_LIST_COUNT) return NONE;
  self->usage_map &= ~bitmask_for_index(id);
  array_clear(&self->list[id]);
  return id;
}

static void capture_list_pool_release(CaptureListPool *self, uint16_t id) {
  if (id >= MAX_CAPTURE_LIST_COUNT) return;
  array_clear(&self->list[id]);
  self->usage_map |= bitmask_for_index(id);
}

/**************
 * SymbolTable
 **************/

static SymbolTable symbol_table_new(void) {
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

static uint16_t symbol_table_insert_name_with_escapes(
  SymbolTable *self,
  const char *escaped_name,
  uint32_t escaped_length
) {
  Slice slice = {
    .offset = self->characters.size,
    .length = 0,
  };
  array_grow_by(&self->characters, escaped_length + 1);

  // Copy the contents of the literal into the characters buffer, processing escape
  // sequences like \n and \". This needs to be done before checking if the literal
  // is already present, in order to do the string comparison.
  bool is_escaped = false;
  for (unsigned i = 0; i < escaped_length; i++) {
    const char *src = &escaped_name[i];
    char *dest = &self->characters.contents[slice.offset + slice.length];
    if (is_escaped) {
      switch (*src) {
        case 'n':
          *dest = '\n';
          break;
        case 'r':
          *dest = '\r';
          break;
        case 't':
          *dest = '\t';
          break;
        case '0':
          *dest = '\0';
          break;
        default:
          *dest = *src;
          break;
      }
      is_escaped = false;
      slice.length++;
    } else {
      if (*src == '\\') {
        is_escaped = true;
      } else {
        *dest = *src;
        slice.length++;
      }
    }
  }

  // If the string is already present, remove the redundant content from the characters
  // buffer and return the existing id.
  int id = symbol_table_id_for_name(self, &self->characters.contents[slice.offset], slice.length);
  if (id >= 0) {
    self->characters.size -= (escaped_length + 1);
    return id;
  }

  self->characters.contents[slice.offset + slice.length] = 0;
  array_push(&self->slices, slice);
  return self->slices.size - 1;
}

/************
 * QueryStep
 ************/

static QueryStep query_step__new(
  TSSymbol symbol,
  uint16_t depth,
  bool is_immediate
) {
  return (QueryStep) {
    .symbol = symbol,
    .depth = depth,
    .field = 0,
    .capture_ids = {NONE, NONE, NONE},
    .alternative_index = NONE,
    .contains_captures = false,
    .is_last_child = false,
    .is_pass_through = false,
    .is_dead_end = false,
    .is_immediate = is_immediate,
    .alternative_is_immediate = false,
  };
}

static void query_step__add_capture(QueryStep *self, uint16_t capture_id) {
  for (unsigned i = 0; i < MAX_STEP_CAPTURE_COUNT; i++) {
    if (self->capture_ids[i] == NONE) {
      self->capture_ids[i] = capture_id;
      break;
    }
  }
}

static void query_step__remove_capture(QueryStep *self, uint16_t capture_id) {
  for (unsigned i = 0; i < MAX_STEP_CAPTURE_COUNT; i++) {
    if (self->capture_ids[i] == capture_id) {
      self->capture_ids[i] = NONE;
      while (i + 1 < MAX_STEP_CAPTURE_COUNT) {
        if (self->capture_ids[i + 1] == NONE) break;
        self->capture_ids[i] = self->capture_ids[i + 1];
        self->capture_ids[i + 1] = NONE;
        i++;
      }
      break;
    }
  }
}

/*********
 * Query
 *********/

// The `pattern_map` contains a mapping from TSSymbol values to indices in the
// `steps` array. For a given syntax node, the `pattern_map` makes it possible
// to quickly find the starting steps of all of the patterns whose root matches
// that node. Each entry has two fields: a `pattern_index`, which identifies one
// of the patterns in the query, and a `step_index`, which indicates the start
// offset of that pattern's steps within the `steps` array.
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
  uint32_t start_step_index,
  uint32_t pattern_index
) {
  uint32_t index;
  ts_query__pattern_map_search(self, symbol, &index);

  // Ensure that the entries are sorted not only by symbol, but also
  // by pattern_index. This way, states for earlier patterns will be
  // initiated first, which allows the ordering of the states array
  // to be maintained more efficiently.
  while (index < self->pattern_map.size) {
    PatternEntry *entry = &self->pattern_map.contents[index];
    if (
      self->steps.contents[entry->step_index].symbol == symbol &&
      entry->pattern_index < pattern_index
    ) {
      index++;
    } else {
      break;
    }
  }

  array_insert(&self->pattern_map, index, ((PatternEntry) {
    .step_index = start_step_index,
    .pattern_index = pattern_index,
  }));
}

static void ts_query__finalize_steps(TSQuery *self) {
  for (unsigned i = 0; i < self->steps.size; i++) {
    QueryStep *step = &self->steps.contents[i];
    uint32_t depth = step->depth;
    if (step->capture_ids[0] != NONE) {
      step->contains_captures = true;
    } else {
      step->contains_captures = false;
      for (unsigned j = i + 1; j < self->steps.size; j++) {
        QueryStep *s = &self->steps.contents[j];
        if (s->depth == PATTERN_DONE_MARKER || s->depth <= depth) break;
        if (s->capture_ids[0] != NONE) step->contains_captures = true;
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
static TSQueryError ts_query__parse_predicate(
  TSQuery *self,
  Stream *stream
) {
  if (!stream_is_ident_start(stream)) return TSQueryErrorSyntax;
  const char *predicate_name = stream->input;
  stream_scan_identifier(stream);
  uint32_t length = stream->input - predicate_name;
  uint16_t id = symbol_table_insert_name(
    &self->predicate_values,
    predicate_name,
    length
  );
  array_back(&self->predicates_by_pattern)->length++;
  array_push(&self->predicate_steps, ((TSQueryPredicateStep) {
    .type = TSQueryPredicateStepTypeString,
    .value_id = id,
  }));
  stream_skip_whitespace(stream);

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
      bool is_escaped = false;
      const char *string_content = stream->input;
      for (;;) {
        if (is_escaped) {
          is_escaped = false;
        } else {
          if (stream->next == '\\') {
            is_escaped = true;
          } else if (stream->next == '"') {
            break;
          } else if (stream->next == '\n') {
            stream_reset(stream, string_content - 1);
            return TSQueryErrorSyntax;
          }
        }
        if (!stream_advance(stream)) {
          stream_reset(stream, string_content - 1);
          return TSQueryErrorSyntax;
        }
      }
      uint32_t length = stream->input - string_content;

      // Add a step for the node
      uint16_t id = symbol_table_insert_name_with_escapes(
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

    stream_skip_whitespace(stream);
  }

  return 0;
}

// Read one S-expression pattern from the stream, and incorporate it into
// the query's internal state machine representation. For nested patterns,
// this function calls itself recursively.
static TSQueryError ts_query__parse_pattern(
  TSQuery *self,
  Stream *stream,
  uint32_t depth,
  uint32_t *capture_count,
  bool is_immediate
) {
  const uint32_t starting_step_index = self->steps.size;

  if (stream->next == 0) return TSQueryErrorSyntax;

  // Finish the parent S-expression.
  if (stream->next == ')' || stream->next == ']') {
    return PARENT_DONE;
  }

  // An open bracket is the start of an alternation.
  else if (stream->next == '[') {
    stream_advance(stream);
    stream_skip_whitespace(stream);

    // Parse each branch, and add a placeholder step in between the branches.
    Array(uint32_t) branch_step_indices = array_new();
    for (;;) {
      uint32_t start_index = self->steps.size;
      TSQueryError e = ts_query__parse_pattern(
        self,
        stream,
        depth,
        capture_count,
        is_immediate
      );

      if (e == PARENT_DONE && stream->next == ']' && branch_step_indices.size > 0) {
        stream_advance(stream);
        break;
      } else if (e) {
        array_delete(&branch_step_indices);
        return e;
      }

      array_push(&branch_step_indices, start_index);
      array_push(&self->steps, query_step__new(0, depth, false));
    }
    (void)array_pop(&self->steps);

    // For all of the branches except for the last one, add the subsequent branch as an
    // alternative, and link the end of the branch to the current end of the steps.
    for (unsigned i = 0; i < branch_step_indices.size - 1; i++) {
      uint32_t step_index = branch_step_indices.contents[i];
      uint32_t next_step_index = branch_step_indices.contents[i + 1];
      QueryStep *start_step = &self->steps.contents[step_index];
      QueryStep *end_step = &self->steps.contents[next_step_index - 1];
      start_step->alternative_index = next_step_index;
      end_step->alternative_index = self->steps.size;
      end_step->is_dead_end = true;
    }

    array_delete(&branch_step_indices);
  }

  // An open parenthesis can be the start of three possible constructs:
  // * A grouped sequence
  // * A predicate
  // * A named node
  else if (stream->next == '(') {
    stream_advance(stream);
    stream_skip_whitespace(stream);

    // If this parenthesis is followed by a node, then it represents a grouped sequence.
    if (stream->next == '(' || stream->next == '"' || stream->next == '[') {
      bool child_is_immediate = false;
      for (;;) {
        if (stream->next == '.') {
          child_is_immediate = true;
          stream_advance(stream);
          stream_skip_whitespace(stream);
        }
        TSQueryError e = ts_query__parse_pattern(
          self,
          stream,
          depth,
          capture_count,
          child_is_immediate
        );
        if (e == PARENT_DONE && stream->next == ')') {
          stream_advance(stream);
          break;
        } else if (e) {
          return e;
        }

        child_is_immediate = false;
      }
    }

    // A dot/pound character indicates the start of a predicate.
    else if (stream->next == '.' || stream->next == '#') {
      stream_advance(stream);
      return ts_query__parse_predicate(self, stream);
    }

    // Otherwise, this parenthesis is the start of a named node.
    else {
      TSSymbol symbol;

      // Parse the wildcard symbol
      if (
        stream->next == '_' ||

        // TODO - remove.
        // For temporary backward compatibility, handle '*' as a wildcard.
        stream->next == '*'
      ) {
        symbol = depth > 0 ? NAMED_WILDCARD_SYMBOL : WILDCARD_SYMBOL;
        stream_advance(stream);
      }

      // Parse a normal node name
      else if (stream_is_ident_start(stream)) {
        const char *node_name = stream->input;
        stream_scan_identifier(stream);
        uint32_t length = stream->input - node_name;

        // TODO - remove.
        // For temporary backward compatibility, handle predicates without the leading '#' sign.
        if (length > 0 && (node_name[length - 1] == '!' || node_name[length - 1] == '?')) {
          stream_reset(stream, node_name);
          return ts_query__parse_predicate(self, stream);
        }

        symbol = ts_language_symbol_for_name(
          self->language,
          node_name,
          length,
          true
        );
        if (!symbol) {
          stream_reset(stream, node_name);
          return TSQueryErrorNodeType;
        }
      } else {
        return TSQueryErrorSyntax;
      }

      // Add a step for the node.
      array_push(&self->steps, query_step__new(symbol, depth, is_immediate));

      // Parse the child patterns
      stream_skip_whitespace(stream);
      bool child_is_immediate = false;
      uint16_t child_start_step_index = self->steps.size;
      for (;;) {
        if (stream->next == '.') {
          child_is_immediate = true;
          stream_advance(stream);
          stream_skip_whitespace(stream);
        }

        TSQueryError e = ts_query__parse_pattern(
          self,
          stream,
          depth + 1,
          capture_count,
          child_is_immediate
        );
        if (e == PARENT_DONE && stream->next == ')') {
          if (child_is_immediate) {
            self->steps.contents[child_start_step_index].is_last_child = true;
          }
          stream_advance(stream);
          break;
        } else if (e) {
          return e;
        }

        child_is_immediate = false;
      }
    }
  }

  // Parse a wildcard pattern
  else if (
    stream->next == '_' ||

    // TODO remove.
    // For temporary backward compatibility, handle '*' as a wildcard.
    stream->next == '*'
  ) {
    stream_advance(stream);
    stream_skip_whitespace(stream);

    // Add a step that matches any kind of node
    array_push(&self->steps, query_step__new(WILDCARD_SYMBOL, depth, is_immediate));
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
    TSSymbol symbol = ts_language_symbol_for_name(
      self->language,
      string_content,
      length,
      false
    );
    if (!symbol) {
      stream_reset(stream, string_content);
      return TSQueryErrorNodeType;
    }
    array_push(&self->steps, query_step__new(symbol, depth, is_immediate));

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
    TSQueryError e = ts_query__parse_pattern(
      self,
      stream,
      depth,
      capture_count,
      is_immediate
    );
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

    uint32_t step_index = starting_step_index;
    QueryStep *step = &self->steps.contents[step_index];
    for (;;) {
      step->field = field_id;
      if (
        step->alternative_index != NONE &&
        step->alternative_index > step_index &&
        step->alternative_index < self->steps.size
      ) {
        step_index = step->alternative_index;
        step = &self->steps.contents[step_index];
      } else {
        break;
      }
    }
  }

  else {
    return TSQueryErrorSyntax;
  }

  stream_skip_whitespace(stream);

  // Parse suffixes modifiers for this pattern
  for (;;) {
    QueryStep *step = &self->steps.contents[starting_step_index];

    // Parse the one-or-more operator.
    if (stream->next == '+') {
      stream_advance(stream);
      stream_skip_whitespace(stream);

      QueryStep repeat_step = query_step__new(WILDCARD_SYMBOL, depth, false);
      repeat_step.alternative_index = starting_step_index;
      repeat_step.is_pass_through = true;
      repeat_step.alternative_is_immediate = true;
      array_push(&self->steps, repeat_step);
    }

    // Parse the zero-or-more repetition operator.
    else if (stream->next == '*') {
      stream_advance(stream);
      stream_skip_whitespace(stream);

      QueryStep repeat_step = query_step__new(WILDCARD_SYMBOL, depth, false);
      repeat_step.alternative_index = starting_step_index;
      repeat_step.is_pass_through = true;
      repeat_step.alternative_is_immediate = true;
      array_push(&self->steps, repeat_step);

      while (step->alternative_index != NONE) {
        step = &self->steps.contents[step->alternative_index];
      }
      step->alternative_index = self->steps.size;
    }

    // Parse the optional operator.
    else if (stream->next == '?') {
      stream_advance(stream);
      stream_skip_whitespace(stream);

      while (step->alternative_index != NONE) {
        step = &self->steps.contents[step->alternative_index];
      }
      step->alternative_index = self->steps.size;
    }

    // Parse an '@'-prefixed capture pattern
    else if (stream->next == '@') {
      stream_advance(stream);
      if (!stream_is_ident_start(stream)) return TSQueryErrorSyntax;
      const char *capture_name = stream->input;
      stream_scan_identifier(stream);
      uint32_t length = stream->input - capture_name;
      stream_skip_whitespace(stream);

      // Add the capture id to the first step of the pattern
      uint16_t capture_id = symbol_table_insert_name(
        &self->captures,
        capture_name,
        length
      );

      uint32_t step_index = starting_step_index;
      for (;;) {
        query_step__add_capture(step, capture_id);
        if (
          step->alternative_index != NONE &&
          step->alternative_index > step_index &&
          step->alternative_index < self->steps.size
        ) {
          step_index = step->alternative_index;
          step = &self->steps.contents[step_index];
        } else {
          break;
        }
      }

      (*capture_count)++;
    }

    // No more suffix modifiers
    else {
      break;
    }
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
  TSSymbol *symbol_map;
  if (ts_language_version(language) >= TREE_SITTER_LANGUAGE_VERSION_WITH_SYMBOL_DEDUPING) {
    symbol_map = NULL;
  } else {
    // Work around the fact that multiple symbols can currently be
    // associated with the same name, due to "simple aliases".
    // In the next language ABI version, this map will be contained
    // in the language's `public_symbol_map` field.
    uint32_t symbol_count = ts_language_symbol_count(language);
    symbol_map = ts_malloc(sizeof(TSSymbol) * symbol_count);
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
    .language = language,
  };

  // Parse all of the S-expressions in the given string.
  Stream stream = stream_new(source, source_len);
  stream_skip_whitespace(&stream);
  while (stream.input < stream.end) {
    uint32_t pattern_index = self->predicates_by_pattern.size;
    uint32_t start_step_index = self->steps.size;
    uint32_t capture_count = 0;
    array_push(&self->start_bytes_by_pattern, stream.input - source);
    array_push(&self->predicates_by_pattern, ((Slice) {
      .offset = self->predicate_steps.size,
      .length = 0,
    }));
    *error_type = ts_query__parse_pattern(self, &stream, 0, &capture_count, false);
    array_push(&self->steps, query_step__new(0, PATTERN_DONE_MARKER, false));

    // If any pattern could not be parsed, then report the error information
    // and terminate.
    if (*error_type) {
      if (*error_type == PARENT_DONE) *error_type = TSQueryErrorSyntax;
      *error_offset = stream.input - source;
      ts_query_delete(self);
      return NULL;
    }

    // If a pattern has a wildcard at its root, optimize the matching process
    // by skipping matching the wildcard.
    if (
      self->steps.contents[start_step_index].symbol == WILDCARD_SYMBOL
    ) {
      QueryStep *second_step = &self->steps.contents[start_step_index + 1];
      if (second_step->symbol != WILDCARD_SYMBOL && second_step->depth != PATTERN_DONE_MARKER) {
        start_step_index += 1;
      }
    }

    // Maintain a map that can look up patterns for a given root symbol.
    for (;;) {
      QueryStep *step = &self->steps.contents[start_step_index];
      ts_query__pattern_map_insert(self, step->symbol, start_step_index, pattern_index);
      if (step->symbol == WILDCARD_SYMBOL) {
        self->wildcard_root_pattern_count++;
      }

      // If there are alternatives or options at the root of the pattern,
      // then add multiple entries to the pattern map.
      if (step->alternative_index != NONE) {
        start_step_index = step->alternative_index;
        step->alternative_index = NONE;
      } else {
        break;
      }
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
  if (self->predicate_steps.contents == NULL) {
    return NULL;
  }
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
  // Remove capture information for any pattern step that previously
  // captured with the given name.
  int id = symbol_table_id_for_name(&self->captures, name, length);
  if (id != -1) {
    for (unsigned i = 0; i < self->steps.size; i++) {
      QueryStep *step = &self->steps.contents[i];
      query_step__remove_capture(step, id);
    }
    ts_query__finalize_steps(self);
  }
}

void ts_query_disable_pattern(
  TSQuery *self,
  uint32_t pattern_index
) {
  // Remove the given pattern from the pattern map. Its steps will still
  // be in the `steps` array, but they will never be read.
  for (unsigned i = 0; i < self->pattern_map.size; i++) {
    PatternEntry *pattern = &self->pattern_map.contents[i];
    if (pattern->pattern_index == pattern_index) {
      array_erase(&self->pattern_map, i);
      i--;
    }
  }
}

/***************
 * QueryCursor
 ***************/

TSQueryCursor *ts_query_cursor_new(void) {
  TSQueryCursor *self = ts_malloc(sizeof(TSQueryCursor));
  *self = (TSQueryCursor) {
    .ascending = false,
    .halted = false,
    .states = array_new(),
    .finished_states = array_new(),
    .capture_list_pool = capture_list_pool_new(),
    .start_byte = 0,
    .end_byte = UINT32_MAX,
    .start_point = {0, 0},
    .end_point = POINT_MAX,
  };
  array_reserve(&self->states, 8);
  array_reserve(&self->finished_states, 8);
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
  capture_list_pool_reset(&self->capture_list_pool);
  self->next_state_id = 0;
  self->depth = 0;
  self->ascending = false;
  self->halted = false;
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

// Search through all of the in-progress states, and find the captured
// node that occurs earliest in the document.
static bool ts_query_cursor__first_in_progress_capture(
  TSQueryCursor *self,
  uint32_t *state_index,
  uint32_t *byte_offset,
  uint32_t *pattern_index
) {
  bool result = false;
  *state_index = UINT32_MAX;
  *byte_offset = UINT32_MAX;
  *pattern_index = UINT32_MAX;
  for (unsigned i = 0; i < self->states.size; i++) {
    const QueryState *state = &self->states.contents[i];
    if (state->dead) continue;
    const CaptureList *captures = capture_list_pool_get(
      &self->capture_list_pool,
      state->capture_list_id
    );
    if (captures->size > 0) {
      uint32_t capture_byte = ts_node_start_byte(captures->contents[0].node);
      if (
        !result ||
        capture_byte < *byte_offset ||
        (capture_byte == *byte_offset && state->pattern_index < *pattern_index)
      ) {
        result = true;
        *state_index = i;
        *byte_offset = capture_byte;
        *pattern_index = state->pattern_index;
      }
    }
  }
  return result;
}

// Determine which node is first in a depth-first traversal
int ts_query_cursor__compare_nodes(TSNode left, TSNode right) {
  if (left.id != right.id) {
    uint32_t left_start = ts_node_start_byte(left);
    uint32_t right_start = ts_node_start_byte(right);
    if (left_start < right_start) return -1;
    if (left_start > right_start) return 1;
    uint32_t left_node_count = ts_node_end_byte(left);
    uint32_t right_node_count = ts_node_end_byte(right);
    if (left_node_count > right_node_count) return -1;
    if (left_node_count < right_node_count) return 1;
  }
  return 0;
}

// Determine if either state contains a superset of the other state's captures.
void ts_query_cursor__compare_captures(
  TSQueryCursor *self,
  QueryState *left_state,
  QueryState *right_state,
  bool *left_contains_right,
  bool *right_contains_left
) {
  const CaptureList *left_captures = capture_list_pool_get(
    &self->capture_list_pool,
    left_state->capture_list_id
  );
  const CaptureList *right_captures = capture_list_pool_get(
    &self->capture_list_pool,
    right_state->capture_list_id
  );
  *left_contains_right = true;
  *right_contains_left = true;
  unsigned i = 0, j = 0;
  for (;;) {
    if (i < left_captures->size) {
      if (j < right_captures->size) {
        TSQueryCapture *left = &left_captures->contents[i];
        TSQueryCapture *right = &right_captures->contents[j];
        if (left->node.id == right->node.id && left->index == right->index) {
          i++;
          j++;
        } else {
          switch (ts_query_cursor__compare_nodes(left->node, right->node)) {
            case -1:
              *right_contains_left = false;
              i++;
              break;
            case 1:
              *left_contains_right = false;
              j++;
              break;
            default:
              *right_contains_left = false;
              *left_contains_right = false;
              i++;
              j++;
              break;
          }
        }
      } else {
        *right_contains_left = false;
        break;
      }
    } else {
      if (j < right_captures->size) {
        *left_contains_right = false;
      }
      break;
    }
  }
}

static void ts_query_cursor__add_state(
  TSQueryCursor *self,
  const PatternEntry *pattern
) {
  QueryStep *step = &self->query->steps.contents[pattern->step_index];
  uint32_t start_depth = self->depth - step->depth;

  // Keep the states array in ascending order of start_depth and pattern_index,
  // so that it can be processed more efficiently elsewhere. Usually, there is
  // no work to do here because of two facts:
  // * States with lower start_depth are naturally added first due to the
  //   order in which nodes are visited.
  // * Earlier patterns are naturally added first because of the ordering of the
  //   pattern_map data structure that's used to initiate matches.
  //
  // This loop is only needed in cases where two conditions hold:
  // * A pattern consists of more than one sibling node, so that its states
  //   remain in progress after exiting the node that started the match.
  // * The first node in the pattern matches against multiple nodes at the
  //   same depth.
  //
  // An example of this is the pattern '((comment)* (function))'. If multiple
  // `comment` nodes appear in a row, then we may initiate a new state for this
  // pattern while another state for the same pattern is already in progress.
  // If there are multiple patterns like this in a query, then this loop will
  // need to execute in order to keep the states ordered by pattern_index.
  uint32_t index = self->states.size;
  while (index > 0) {
    QueryState *prev_state = &self->states.contents[index - 1];
    if (prev_state->start_depth < start_depth) break;
    if (prev_state->start_depth == start_depth) {
      if (prev_state->pattern_index < pattern->pattern_index) break;
      if (prev_state->pattern_index == pattern->pattern_index) {
        // Avoid unnecessarily inserting an unnecessary duplicate state,
        // which would be immediately pruned by the longest-match criteria.
        if (prev_state->step_index == pattern->step_index) return;
      }
    }
    index--;
  }

  LOG(
    "  start state. pattern:%u, step:%u\n",
    pattern->pattern_index,
    pattern->step_index
  );
  array_insert(&self->states, index, ((QueryState) {
    .capture_list_id = NONE,
    .step_index = pattern->step_index,
    .pattern_index = pattern->pattern_index,
    .start_depth = start_depth,
    .consumed_capture_count = 0,
    .seeking_immediate_match = true,
    .has_in_progress_alternatives = false,
    .dead = false,
  }));
}

// Acquire a capture list for this state. If there are no capture lists left in the
// pool, this will steal the capture list from another existing state, and mark that
// other state as 'dead'.
static CaptureList *ts_query_cursor__prepare_to_capture(
  TSQueryCursor *self,
  QueryState *state,
  unsigned state_index_to_preserve
) {
  if (state->capture_list_id == NONE) {
    state->capture_list_id = capture_list_pool_acquire(&self->capture_list_pool);

    // If there are no capture lists left in the pool, then terminate whichever
    // state has captured the earliest node in the document, and steal its
    // capture list.
    if (state->capture_list_id == NONE) {
      uint32_t state_index, byte_offset, pattern_index;
      if (
        ts_query_cursor__first_in_progress_capture(
          self,
          &state_index,
          &byte_offset,
          &pattern_index
        ) &&
        state_index != state_index_to_preserve
      ) {
        LOG(
          "  abandon state. index:%u, pattern:%u, offset:%u.\n",
          state_index, pattern_index, byte_offset
        );
        QueryState *other_state = &self->states.contents[state_index];
        state->capture_list_id = other_state->capture_list_id;
        other_state->capture_list_id = NONE;
        other_state->dead = true;
        CaptureList *list = capture_list_pool_get_mut(
          &self->capture_list_pool,
          state->capture_list_id
        );
        array_clear(list);
        return list;
      } else {
        LOG("  ran out of capture lists");
        return NULL;
      }
    }
  }
  return capture_list_pool_get_mut(&self->capture_list_pool, state->capture_list_id);
}

// Duplicate the given state and insert the newly-created state immediately after
// the given state in the `states` array. Ensures that the given state reference is
// still valid, even if the states array is reallocated.
static QueryState *ts_query_cursor__copy_state(
  TSQueryCursor *self,
  QueryState **state_ref
) {
  const QueryState *state = *state_ref;
  uint32_t state_index = state - self->states.contents;
  QueryState copy = *state;
  copy.capture_list_id = NONE;

  // If the state has captures, copy its capture list.
  if (state->capture_list_id != NONE) {
    CaptureList *new_captures = ts_query_cursor__prepare_to_capture(self, &copy, state_index);
    if (!new_captures) return NULL;
    const CaptureList *old_captures = capture_list_pool_get(
      &self->capture_list_pool,
      state->capture_list_id
    );
    array_push_all(new_captures, old_captures);
  }

  array_insert(&self->states, state_index + 1, copy);
  *state_ref = &self->states.contents[state_index];
  return &self->states.contents[state_index + 1];
}

// Walk the tree, processing patterns until at least one pattern finishes,
// If one or more patterns finish, return `true` and store their states in the
// `finished_states` array. Multiple patterns can finish on the same node. If
// there are no more matches, return `false`.
static inline bool ts_query_cursor__advance(TSQueryCursor *self) {
  bool did_match = false;
  for (;;) {
    if (self->halted) {
      while (self->states.size > 0) {
        QueryState state = array_pop(&self->states);
        capture_list_pool_release(
          &self->capture_list_pool,
          state.capture_list_id
        );
      }
    }

    if (did_match || self->halted) return did_match;

    if (self->ascending) {
      LOG("leave node. type:%s\n", ts_node_type(ts_tree_cursor_current_node(&self->cursor)));

      // Leave this node by stepping to its next sibling or to its parent.
      if (ts_tree_cursor_goto_next_sibling(&self->cursor)) {
        self->ascending = false;
      } else if (ts_tree_cursor_goto_parent(&self->cursor)) {
        self->depth--;
      } else {
        self->halted = true;
      }

      // After leaving a node, remove any states that cannot make further progress.
      uint32_t deleted_count = 0;
      for (unsigned i = 0, n = self->states.size; i < n; i++) {
        QueryState *state = &self->states.contents[i];
        QueryStep *step = &self->query->steps.contents[state->step_index];

        // If a state completed its pattern inside of this node, but was deferred from finishing
        // in order to search for longer matches, mark it as finished.
        if (step->depth == PATTERN_DONE_MARKER) {
          if (state->start_depth > self->depth || self->halted) {
            LOG("  finish pattern %u\n", state->pattern_index);
            state->id = self->next_state_id++;
            array_push(&self->finished_states, *state);
            did_match = true;
            deleted_count++;
            continue;
          }
        }

        // If a state needed to match something within this node, then remove that state
        // as it has failed to match.
        else if ((uint32_t)state->start_depth + (uint32_t)step->depth > self->depth) {
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
          continue;
        }

        if (deleted_count > 0) {
          self->states.contents[i - deleted_count] = *state;
        }
      }
      self->states.size -= deleted_count;
    } else {
      // If this node is before the selected range, then avoid descending into it.
      TSNode node = ts_tree_cursor_current_node(&self->cursor);
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
      ) {
        self->halted = true;
        continue;
      }

      // Get the properties of the current node.
      TSSymbol symbol = ts_node_symbol(node);
      bool is_named = ts_node_is_named(node);
      if (symbol != ts_builtin_sym_error && self->query->symbol_map) {
        symbol = self->query->symbol_map[symbol];
      }
      bool can_have_later_siblings;
      bool can_have_later_siblings_with_this_field;
      TSFieldId field_id = ts_tree_cursor_current_status(
        &self->cursor,
        &can_have_later_siblings,
        &can_have_later_siblings_with_this_field
      );
      LOG(
        "enter node. type:%s, field:%s, row:%u state_count:%u, finished_state_count:%u\n",
        ts_node_type(node),
        ts_language_field_name_for_id(self->query->language, field_id),
        ts_node_start_point(node).row,
        self->states.size,
        self->finished_states.size
      );

      // Add new states for any patterns whose root node is a wildcard.
      for (unsigned i = 0; i < self->query->wildcard_root_pattern_count; i++) {
        PatternEntry *pattern = &self->query->pattern_map.contents[i];
        QueryStep *step = &self->query->steps.contents[pattern->step_index];

        // If this node matches the first step of the pattern, then add a new
        // state at the start of this pattern.
        if (step->field && field_id != step->field) continue;
        ts_query_cursor__add_state(self, pattern);
      }

      // Add new states for any patterns whose root node matches this node.
      unsigned i;
      if (ts_query__pattern_map_search(self->query, symbol, &i)) {
        PatternEntry *pattern = &self->query->pattern_map.contents[i];
        QueryStep *step = &self->query->steps.contents[pattern->step_index];
        do {
          // If this node matches the first step of the pattern, then add a new
          // state at the start of this pattern.
          if (step->field && field_id != step->field) continue;
          ts_query_cursor__add_state(self, pattern);

          // Advance to the next pattern whose root node matches this node.
          i++;
          if (i == self->query->pattern_map.size) break;
          pattern = &self->query->pattern_map.contents[i];
          step = &self->query->steps.contents[pattern->step_index];
        } while (step->symbol == symbol);
      }

      // Update all of the in-progress states with current node.
      for (unsigned i = 0, copy_count = 0; i < self->states.size; i += 1 + copy_count) {
        QueryState *state = &self->states.contents[i];
        QueryStep *step = &self->query->steps.contents[state->step_index];
        state->has_in_progress_alternatives = false;
        copy_count = 0;

        // Check that the node matches all of the criteria for the next
        // step of the pattern.
        if ((uint32_t)state->start_depth + (uint32_t)step->depth != self->depth) continue;

        // Determine if this node matches this step of the pattern, and also
        // if this node can have later siblings that match this step of the
        // pattern.
        bool node_does_match =
          step->symbol == symbol ||
          step->symbol == WILDCARD_SYMBOL ||
          (step->symbol == NAMED_WILDCARD_SYMBOL && is_named);
        bool later_sibling_can_match = can_have_later_siblings;
        if ((step->is_immediate && is_named) || state->seeking_immediate_match) {
          later_sibling_can_match = false;
        }
        if (step->is_last_child && can_have_later_siblings) {
          node_does_match = false;
        }
        if (step->field) {
          if (step->field == field_id) {
            if (!can_have_later_siblings_with_this_field) {
              later_sibling_can_match = false;
            }
          } else {
            node_does_match = false;
          }
        }

        // Remove states immediately if it is ever clear that they cannot match.
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
          }
          continue;
        }

        // Some patterns can match their root node in multiple ways, capturing different
        // children. If this pattern step could match later children within the same
        // parent, then this query state cannot simply be updated in place. It must be
        // split into two states: one that matches this node, and one which skips over
        // this node, to preserve the possibility of matching later siblings.
        if (later_sibling_can_match && step->contains_captures) {
          if (ts_query_cursor__copy_state(self, &state)) {
            LOG(
              "  split state for capture. pattern:%u, step:%u\n",
              state->pattern_index,
              state->step_index
            );
            copy_count++;
          }
        }

        // If the current node is captured in this pattern, add it to the capture list.
        if (step->capture_ids[0] != NONE) {
          CaptureList *capture_list = ts_query_cursor__prepare_to_capture(self, state, UINT32_MAX);
          if (!capture_list) {
            array_erase(&self->states, i);
            i--;
            continue;
          }

          for (unsigned j = 0; j < MAX_STEP_CAPTURE_COUNT; j++) {
            uint16_t capture_id = step->capture_ids[j];
            if (step->capture_ids[j] == NONE) break;
            array_push(capture_list, ((TSQueryCapture) { node, capture_id }));
            LOG(
              "  capture node. pattern:%u, capture_id:%u, capture_count:%u\n",
              state->pattern_index,
              capture_id,
              capture_list->size
            );
          }
        }

        // Advance this state to the next step of its pattern.
        state->step_index++;
        state->seeking_immediate_match = false;
        LOG(
          "  advance state. pattern:%u, step:%u\n",
          state->pattern_index,
          state->step_index
        );

        // If this state's next step has an alternative step, then copy the state in order
        // to pursue both alternatives. The alternative step itself may have an alternative,
        // so this is an interative process.
        unsigned end_index = i + 1;
        for (unsigned j = i; j < end_index; j++) {
          QueryState *state = &self->states.contents[j];
          QueryStep *next_step = &self->query->steps.contents[state->step_index];
          if (next_step->alternative_index != NONE) {
            if (next_step->is_dead_end) {
              state->step_index = next_step->alternative_index;
              j--;
              continue;
            }

            if (next_step->is_pass_through) {
              state->step_index++;
              j--;
            }

            QueryState *copy = ts_query_cursor__copy_state(self, &state);
            if (copy) {
              LOG(
                "  split state for branch. pattern:%u, from_step:%u, to_step:%u, immediate:%d, capture_count: %u\n",
                copy->pattern_index,
                copy->step_index,
                next_step->alternative_index,
                next_step->alternative_is_immediate,
                capture_list_pool_get(&self->capture_list_pool, copy->capture_list_id)->size
              );
              end_index++;
              copy_count++;
              copy->step_index = next_step->alternative_index;
              if (next_step->alternative_is_immediate) {
                copy->seeking_immediate_match = true;
              }
            }
          }
        }
      }

      for (unsigned i = 0; i < self->states.size; i++) {
        QueryState *state = &self->states.contents[i];
        if (state->dead) {
          array_erase(&self->states, i);
          i--;
          continue;
        }

        // Enfore the longest-match criteria. When a query pattern contains optional or
        // repeated nodes, this is necessary to avoid multiple redundant states, where
        // one state has a strict subset of another state's captures.
        bool did_remove = false;
        for (unsigned j = i + 1; j < self->states.size; j++) {
          QueryState *other_state = &self->states.contents[j];

          // Query states are kept in ascending order of start_depth and pattern_index.
          // Since the longest-match criteria is only used for deduping matches of the same
          // pattern and root node, we only need to perform pairwise comparisons within a
          // small slice of the states array.
          if (
            other_state->start_depth != state->start_depth ||
            other_state->pattern_index != state->pattern_index
          ) break;

          bool left_contains_right, right_contains_left;
          ts_query_cursor__compare_captures(
            self,
            state,
            other_state,
            &left_contains_right,
            &right_contains_left
          );
          if (left_contains_right) {
            if (state->step_index == other_state->step_index) {
              LOG(
                "  drop shorter state. pattern: %u, step_index: %u\n",
                state->pattern_index,
                state->step_index
              );
              capture_list_pool_release(&self->capture_list_pool, other_state->capture_list_id);
              array_erase(&self->states, j);
              j--;
              continue;
            }
            other_state->has_in_progress_alternatives = true;
          }
          if (right_contains_left) {
            if (state->step_index == other_state->step_index) {
              LOG(
                "  drop shorter state. pattern: %u, step_index: %u\n",
                state->pattern_index,
                state->step_index
              );
              capture_list_pool_release(&self->capture_list_pool, state->capture_list_id);
              array_erase(&self->states, i);
              i--;
              did_remove = true;
              break;
            }
            state->has_in_progress_alternatives = true;
          }
        }

        // If there the state is at the end of its pattern, remove it from the list
        // of in-progress states and add it to the list of finished states.
        if (!did_remove) {
          LOG(
            "  keep state. pattern: %u, start_depth: %u, step_index: %u, capture_count: %u\n",
            state->pattern_index,
            state->start_depth,
            state->step_index,
            capture_list_pool_get(&self->capture_list_pool, state->capture_list_id)->size
          );
          QueryStep *next_step = &self->query->steps.contents[state->step_index];
          if (next_step->depth == PATTERN_DONE_MARKER) {
            if (state->has_in_progress_alternatives) {
              LOG("  defer finishing pattern %u\n", state->pattern_index);
            } else {
              LOG("  finish pattern %u\n", state->pattern_index);
              state->id = self->next_state_id++;
              array_push(&self->finished_states, *state);
              array_erase(&self->states, state - self->states.contents);
              did_match = true;
              i--;
            }
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
  }
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
  const CaptureList *captures = capture_list_pool_get(
    &self->capture_list_pool,
    state->capture_list_id
  );
  match->captures = captures->contents;
  match->capture_count = captures->size;
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
      uint32_t first_unfinished_capture_byte;
      uint32_t first_unfinished_pattern_index;
      uint32_t first_unfinished_state_index;
      ts_query_cursor__first_in_progress_capture(
        self,
        &first_unfinished_state_index,
        &first_unfinished_capture_byte,
        &first_unfinished_pattern_index
      );

      // Find the earliest capture in a finished match.
      int first_finished_state_index = -1;
      uint32_t first_finished_capture_byte = first_unfinished_capture_byte;
      uint32_t first_finished_pattern_index = first_unfinished_pattern_index;
      for (unsigned i = 0; i < self->finished_states.size; i++) {
        const QueryState *state = &self->finished_states.contents[i];
        const CaptureList *captures = capture_list_pool_get(
          &self->capture_list_pool,
          state->capture_list_id
        );
        if (captures->size > state->consumed_capture_count) {
          uint32_t capture_byte = ts_node_start_byte(
            captures->contents[state->consumed_capture_count].node
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
        const CaptureList *captures = capture_list_pool_get(
          &self->capture_list_pool,
          state->capture_list_id
        );
        match->captures = captures->contents;
        match->capture_count = captures->size;
        *capture_index = state->consumed_capture_count;
        state->consumed_capture_count++;
        return true;
      }

      if (capture_list_pool_is_empty(&self->capture_list_pool)) {
        LOG(
          "  abandon state. index:%u, pattern:%u, offset:%u.\n",
          first_unfinished_state_index,
          first_unfinished_pattern_index,
          first_unfinished_capture_byte
        );
        capture_list_pool_release(
          &self->capture_list_pool,
          self->states.contents[first_unfinished_state_index].capture_list_id
        );
        array_erase(&self->states, first_unfinished_state_index);
      }
    }

    // If there are no finished matches that are ready to be returned, then
    // continue finding more matches.
    if (
      !ts_query_cursor__advance(self) &&
      self->finished_states.size == 0
    ) return false;
  }
}

#undef LOG
