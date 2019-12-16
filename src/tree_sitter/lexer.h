#ifndef TREE_SITTER_LEXER_H_
#define TREE_SITTER_LEXER_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "./length.h"
#include "./subtree.h"
#include "tree_sitter/api.h"
#include "tree_sitter/parser.h"

typedef struct {
  TSLexer data;
  Length current_position;
  Length token_start_position;
  Length token_end_position;

  TSRange * included_ranges;
  size_t included_range_count;
  size_t current_included_range_index;

  const char *chunk;
  uint32_t chunk_start;
  uint32_t chunk_size;
  uint32_t lookahead_size;

  TSInput input;
  TSLogger logger;
  char debug_buffer[TREE_SITTER_SERIALIZATION_BUFFER_SIZE];
} Lexer;

void ts_lexer_init(Lexer *);
void ts_lexer_delete(Lexer *);
void ts_lexer_set_input(Lexer *, TSInput);
void ts_lexer_reset(Lexer *, Length);
void ts_lexer_start(Lexer *);
void ts_lexer_finish(Lexer *, uint32_t *);
void ts_lexer_advance_to_end(Lexer *);
void ts_lexer_mark_end(Lexer *);
void ts_lexer_set_included_ranges(Lexer *self, const TSRange *ranges, uint32_t count);
TSRange *ts_lexer_included_ranges(const Lexer *self, uint32_t *count);

#ifdef __cplusplus
}
#endif

#endif  // TREE_SITTER_LEXER_H_
