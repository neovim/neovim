#include <stdio.h>
#include "./lexer.h"
#include "./subtree.h"
#include "./length.h"
#include "./utf16.h"
#include "utf8proc.h"

#define LOG(...)                                                                      \
  if (self->logger.log) {                                                             \
    snprintf(self->debug_buffer, TREE_SITTER_SERIALIZATION_BUFFER_SIZE, __VA_ARGS__); \
    self->logger.log(self->logger.payload, TSLogTypeLex, self->debug_buffer);         \
  }

#define LOG_CHARACTER(message, character) \
  LOG(                                    \
    32 <= character && character < 127 ?  \
    message " character:'%c'" :           \
    message " character:%d", character    \
  )

static const char empty_chunk[3] = { 0, 0 };

static const int32_t BYTE_ORDER_MARK = 0xFEFF;

static void ts_lexer__get_chunk(Lexer *self) {
  self->chunk_start = self->current_position.bytes;
  self->chunk = self->input.read(
    self->input.payload,
    self->current_position.bytes,
    self->current_position.extent,
    &self->chunk_size
  );
  if (!self->chunk_size) self->chunk = empty_chunk;
}

typedef utf8proc_ssize_t (*DecodeFunction)(
  const utf8proc_uint8_t *,
  utf8proc_ssize_t,
  utf8proc_int32_t *
);

static void ts_lexer__get_lookahead(Lexer *self) {
  uint32_t position_in_chunk = self->current_position.bytes - self->chunk_start;
  const uint8_t *chunk = (const uint8_t *)self->chunk + position_in_chunk;
  uint32_t size = self->chunk_size - position_in_chunk;

  if (size == 0) {
    self->lookahead_size = 1;
    self->data.lookahead = '\0';
    return;
  }

  DecodeFunction decode =
    self->input.encoding == TSInputEncodingUTF8 ? utf8proc_iterate : utf16_iterate;

  self->lookahead_size = decode(chunk, size, &self->data.lookahead);

  // If this chunk ended in the middle of a multi-byte character,
  // try again with a fresh chunk.
  if (self->data.lookahead == -1 && size < 4) {
    ts_lexer__get_chunk(self);
    chunk = (const uint8_t *)self->chunk;
    size = self->chunk_size;
    self->lookahead_size = decode(chunk, size, &self->data.lookahead);
  }

  if (self->data.lookahead == -1) {
    self->lookahead_size = 1;
  }
}

static void ts_lexer__advance(TSLexer *payload, bool skip) {
  Lexer *self = (Lexer *)payload;
  if (self->chunk == empty_chunk)
    return;

  if (self->lookahead_size) {
    self->current_position.bytes += self->lookahead_size;
    if (self->data.lookahead == '\n') {
      self->current_position.extent.row++;
      self->current_position.extent.column = 0;
    } else {
      self->current_position.extent.column += self->lookahead_size;
    }
  }

  TSRange *current_range = &self->included_ranges[self->current_included_range_index];
  if (self->current_position.bytes == current_range->end_byte) {
    self->current_included_range_index++;
    if (self->current_included_range_index == self->included_range_count) {
      self->data.lookahead = '\0';
      self->lookahead_size = 1;
      return;
    } else {
      current_range++;
      self->current_position = (Length) {
        current_range->start_byte,
        current_range->start_point,
      };
    }
  }

  if (skip) {
    LOG_CHARACTER("skip", self->data.lookahead);
    self->token_start_position = self->current_position;
  } else {
    LOG_CHARACTER("consume", self->data.lookahead);
  }

  if (self->current_position.bytes >= self->chunk_start + self->chunk_size) {
    ts_lexer__get_chunk(self);
  }

  ts_lexer__get_lookahead(self);
}

static void ts_lexer__mark_end(TSLexer *payload) {
  Lexer *self = (Lexer *)payload;
  TSRange *current_included_range = &self->included_ranges[self->current_included_range_index];
  if (self->current_included_range_index > 0 &&
      self->current_position.bytes == current_included_range->start_byte) {
    TSRange *previous_included_range = current_included_range - 1;
    self->token_end_position = (Length) {
      previous_included_range->end_byte,
      previous_included_range->end_point,
    };
  } else {
    self->token_end_position = self->current_position;
  }
}

static uint32_t ts_lexer__get_column(TSLexer *payload) {
  Lexer *self = (Lexer *)payload;
  uint32_t goal_byte = self->current_position.bytes;

  self->current_position.bytes -= self->current_position.extent.column;
  self->current_position.extent.column = 0;

  if (self->current_position.bytes < self->chunk_start) {
    ts_lexer__get_chunk(self);
  }

  uint32_t result = 0;
  while (self->current_position.bytes < goal_byte) {
    ts_lexer__advance(payload, false);
    result++;
  }

  return result;
}

static bool ts_lexer__is_at_included_range_start(TSLexer *payload) {
  const Lexer *self = (const Lexer *)payload;
  TSRange *current_range = &self->included_ranges[self->current_included_range_index];
  return self->current_position.bytes == current_range->start_byte;
}

// The lexer's methods are stored as a struct field so that generated
// parsers can call them without needing to be linked against this library.

void ts_lexer_init(Lexer *self) {
  *self = (Lexer) {
    .data = {
      .advance = ts_lexer__advance,
      .mark_end = ts_lexer__mark_end,
      .get_column = ts_lexer__get_column,
      .is_at_included_range_start = ts_lexer__is_at_included_range_start,
      .lookahead = 0,
      .result_symbol = 0,
    },
    .chunk = NULL,
    .chunk_start = 0,
    .current_position = {UINT32_MAX, {0, 0}},
    .logger = {
      .payload = NULL,
      .log = NULL
    },
    .current_included_range_index = 0,
  };

  self->included_ranges = NULL;
  ts_lexer_set_included_ranges(self, NULL, 0);
  ts_lexer_reset(self, length_zero());
}

void ts_lexer_delete(Lexer *self) {
  ts_free(self->included_ranges);
}

void ts_lexer_set_input(Lexer *self, TSInput input) {
  self->input = input;
  self->data.lookahead = 0;
  self->lookahead_size = 0;
  self->chunk = 0;
  self->chunk_start = 0;
  self->chunk_size = 0;
}

static void ts_lexer_goto(Lexer *self, Length position) {
  bool found_included_range = false;
  for (unsigned i = 0; i < self->included_range_count; i++) {
    TSRange *included_range = &self->included_ranges[i];
    if (included_range->end_byte > position.bytes) {
      if (included_range->start_byte > position.bytes) {
        position = (Length) {
          .bytes = included_range->start_byte,
          .extent = included_range->start_point,
        };
      }

      self->current_included_range_index = i;
      found_included_range = true;
      break;
    }
  }

  if (!found_included_range) {
    TSRange *last_included_range = &self->included_ranges[self->included_range_count - 1];
    position = (Length) {
      .bytes = last_included_range->end_byte,
      .extent = last_included_range->end_point,
    };
    self->chunk = empty_chunk;
    self->chunk_start = position.bytes;
    self->chunk_size = 2;
  }

  self->token_start_position = position;
  self->token_end_position = LENGTH_UNDEFINED;
  self->current_position = position;

  if (self->chunk && (position.bytes < self->chunk_start ||
                      position.bytes >= self->chunk_start + self->chunk_size)) {
    self->chunk = 0;
    self->chunk_start = 0;
    self->chunk_size = 0;
  }

  self->lookahead_size = 0;
  self->data.lookahead = 0;
}

void ts_lexer_reset(Lexer *self, Length position) {
  if (position.bytes != self->current_position.bytes) ts_lexer_goto(self, position);
}

void ts_lexer_start(Lexer *self) {
  self->token_start_position = self->current_position;
  self->token_end_position = LENGTH_UNDEFINED;
  self->data.result_symbol = 0;
  if (!self->chunk) ts_lexer__get_chunk(self);
  if (!self->lookahead_size) ts_lexer__get_lookahead(self);
  if (
    self->current_position.bytes == 0 &&
    self->data.lookahead == BYTE_ORDER_MARK
  ) ts_lexer__advance((TSLexer *)self, true);
}

void ts_lexer_finish(Lexer *self, uint32_t *lookahead_end_byte) {
  if (length_is_undefined(self->token_end_position)) {
    ts_lexer__mark_end(&self->data);
  }

  uint32_t current_lookahead_end_byte = self->current_position.bytes + 1;

  // In order to determine that a byte sequence is invalid UTF8 or UTF16,
  // the character decoding algorithm may have looked at the following byte.
  // Therefore, the next byte *after* the current (invalid) character
  // affects the interpretation of the current character.
  if (self->data.lookahead == -1) {
    current_lookahead_end_byte++;
  }

  if (current_lookahead_end_byte > *lookahead_end_byte) {
    *lookahead_end_byte = current_lookahead_end_byte;
  }
}

void ts_lexer_advance_to_end(Lexer *self) {
  while (self->data.lookahead != 0) {
    ts_lexer__advance((TSLexer *)self, false);
  }
}

void ts_lexer_mark_end(Lexer *self) {
  ts_lexer__mark_end(&self->data);
}

static const TSRange DEFAULT_RANGES[] = {
  {
    .start_point = {
      .row = 0,
      .column = 0,
    },
    .end_point = {
      .row = UINT32_MAX,
      .column = UINT32_MAX,
    },
    .start_byte = 0,
    .end_byte = UINT32_MAX
  }
};

void ts_lexer_set_included_ranges(Lexer *self, const TSRange *ranges, uint32_t count) {
  if (!ranges) {
    ranges = DEFAULT_RANGES;
    count = 1;
  }

  size_t sz = count * sizeof(TSRange);
  self->included_ranges = ts_realloc(self->included_ranges, sz);
  memcpy(self->included_ranges, ranges, sz);
  self->included_range_count = count;
  ts_lexer_goto(self, self->current_position);
}

TSRange *ts_lexer_included_ranges(const Lexer *self, uint32_t *count) {
  *count = self->included_range_count;
  return self->included_ranges;
}

#undef LOG
