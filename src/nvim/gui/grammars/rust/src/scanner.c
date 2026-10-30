#include "tree_sitter/alloc.h"
#include "tree_sitter/parser.h"

#include <wctype.h>

enum TokenType {
    STRING_CONTENT,
    STRING_CLOSE,
    RAW_STRING_LITERAL_START,
    RAW_STRING_LITERAL_CONTENT,
    RAW_STRING_LITERAL_END,
    FLOAT_LITERAL,
    BLOCK_OUTER_DOC_MARKER,
    BLOCK_INNER_DOC_MARKER,
    BLOCK_COMMENT_CONTENT,
    LINE_DOC_CONTENT,
    ERROR_SENTINEL
};

typedef struct {
    uint8_t opening_hash_count;
} Scanner;

void *tree_sitter_rust_external_scanner_create() { return ts_calloc(1, sizeof(Scanner)); }

void tree_sitter_rust_external_scanner_destroy(void *payload) { ts_free((Scanner *)payload); }

unsigned tree_sitter_rust_external_scanner_serialize(void *payload, char *buffer) {
    Scanner *scanner = (Scanner *)payload;
    buffer[0] = (char)scanner->opening_hash_count;
    return 1;
}

void tree_sitter_rust_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
    Scanner *scanner = (Scanner *)payload;
    scanner->opening_hash_count = 0;
    if (length == 1) {
        Scanner *scanner = (Scanner *)payload;
        scanner->opening_hash_count = buffer[0];
    }
}

static inline bool is_num_char(int32_t c) { return c == '_' || iswdigit(c); }

static inline void advance(TSLexer *lexer) { lexer->advance(lexer, false); }

static inline void skip(TSLexer *lexer) { lexer->advance(lexer, true); }

static inline bool process_string(TSLexer *lexer) {
    bool has_content = false;
    for (;;) {
        if (lexer->lookahead == '\"' || lexer->lookahead == '\\') {
            break;
        }
        if (lexer->eof(lexer)) {
            return false;
        }
        has_content = true;
        advance(lexer);
    }
    lexer->result_symbol = STRING_CONTENT;
    lexer->mark_end(lexer);
    return has_content;
}

static inline bool scan_raw_string_start(Scanner *scanner, TSLexer *lexer) {
    if (lexer->lookahead == 'b' || lexer->lookahead == 'c') {
        advance(lexer);
    }
    if (lexer->lookahead != 'r') {
        return false;
    }
    advance(lexer);

    uint8_t opening_hash_count = 0;
    while (lexer->lookahead == '#') {
        advance(lexer);
        opening_hash_count++;
    }

    if (lexer->lookahead != '"') {
        return false;
    }
    advance(lexer);
    scanner->opening_hash_count = opening_hash_count;

    lexer->result_symbol = RAW_STRING_LITERAL_START;
    return true;
}

static inline bool scan_raw_string_content(Scanner *scanner, TSLexer *lexer) {
    for (;;) {
        if (lexer->eof(lexer)) {
            return false;
        }
        if (lexer->lookahead == '"') {
            lexer->mark_end(lexer);
            advance(lexer);
            unsigned hash_count = 0;
            while (lexer->lookahead == '#' && hash_count < scanner->opening_hash_count) {
                advance(lexer);
                hash_count++;
            }
            if (hash_count == scanner->opening_hash_count) {
                lexer->result_symbol = RAW_STRING_LITERAL_CONTENT;
                return true;
            }
        } else {
            advance(lexer);
        }
    }
}

static inline bool scan_raw_string_end(Scanner *scanner, TSLexer *lexer) {
    advance(lexer);
    for (unsigned i = 0; i < scanner->opening_hash_count; i++) {
        advance(lexer);
    }
    lexer->result_symbol = RAW_STRING_LITERAL_END;
    return true;
}

static inline bool process_float_literal(TSLexer *lexer) {
    lexer->result_symbol = FLOAT_LITERAL;

    advance(lexer);
    while (is_num_char(lexer->lookahead)) {
        advance(lexer);
    }

    bool has_fraction = false, has_exponent = false;

    if (lexer->lookahead == '.') {
        has_fraction = true;
        advance(lexer);
        if (iswalpha(lexer->lookahead)) {
            // The dot is followed by a letter: 1.max(2) => not a float but an integer
            return false;
        }

        if (lexer->lookahead == '.') {
            return false;
        }
        while (is_num_char(lexer->lookahead)) {
            advance(lexer);
        }
    }

    lexer->mark_end(lexer);

    if (lexer->lookahead == 'e' || lexer->lookahead == 'E') {
        has_exponent = true;
        advance(lexer);
        if (lexer->lookahead == '+' || lexer->lookahead == '-') {
            advance(lexer);
        }
        if (!is_num_char(lexer->lookahead)) {
            return true;
        }
        advance(lexer);
        while (is_num_char(lexer->lookahead)) {
            advance(lexer);
        }

        lexer->mark_end(lexer);
    }

    if (!has_exponent && !has_fraction) {
        return false;
    }

    if (lexer->lookahead != 'u' && lexer->lookahead != 'i' && lexer->lookahead != 'f') {
        return true;
    }
    advance(lexer);
    if (!iswdigit(lexer->lookahead)) {
        return true;
    }

    while (iswdigit(lexer->lookahead)) {
        advance(lexer);
    }

    lexer->mark_end(lexer);
    return true;
}

static inline bool process_line_doc_content(TSLexer *lexer) {
    lexer->result_symbol = LINE_DOC_CONTENT;
    for (;;) {
        if (lexer->eof(lexer)) {
            return true;
        }
        if (lexer->lookahead == '\n') {
            // Include the newline in the doc content node.
            // Line endings are useful for markdown injection.
            advance(lexer);
            return true;
        }
        advance(lexer);
    }
}

typedef enum {
    LeftForwardSlash,
    LeftAsterisk,
    Continuing,
} BlockCommentState;

typedef struct {
    BlockCommentState state;
    unsigned nestingDepth;
} BlockCommentProcessing;

static inline void process_left_forward_slash(BlockCommentProcessing *processing, char current) {
    if (current == '*') {
        processing->nestingDepth += 1;
    }
    processing->state = Continuing;
};

static inline void process_left_asterisk(BlockCommentProcessing *processing, char current, TSLexer *lexer) {
    if (current == '*') {
        lexer->mark_end(lexer);
        processing->state = LeftAsterisk;
        return;
    }

    if (current == '/') {
        processing->nestingDepth -= 1;
    }

    processing->state = Continuing;
}

static inline void process_continuing(BlockCommentProcessing *processing, char current) {
    switch (current) {
        case '/':
            processing->state = LeftForwardSlash;
            break;
        case '*':
            processing->state = LeftAsterisk;
            break;
    }
}

static inline bool process_block_comment(TSLexer *lexer, const bool *valid_symbols) {
    char first = (char)lexer->lookahead;
    // The first character is stored so we can safely advance inside
    // these if blocks. However, because we only store one, we can only
    // safely advance 1 time. Since there's a chance that an advance could
    // happen in one state, we must advance in all states to ensure that
    // the program ends up in a sane state prior to processing the block
    // comment if need be.
    if (valid_symbols[BLOCK_INNER_DOC_MARKER] && first == '!') {
        lexer->result_symbol = BLOCK_INNER_DOC_MARKER;
        advance(lexer);
        return true;
    }
    if (valid_symbols[BLOCK_OUTER_DOC_MARKER] && first == '*') {
        advance(lexer);
        lexer->mark_end(lexer);
        // If the next token is a / that means that it's an empty block comment.
        if (lexer->lookahead == '/') {
            return false;
        }
        // If the next token is a * that means that this isn't a BLOCK_OUTER_DOC_MARKER
        // as BLOCK_OUTER_DOC_MARKER's only have 2 * not 3 or more.
        if (lexer->lookahead != '*') {
            lexer->result_symbol = BLOCK_OUTER_DOC_MARKER;
            return true;
        }
    } else {
        advance(lexer);
    }

    if (valid_symbols[BLOCK_COMMENT_CONTENT]) {
        BlockCommentProcessing processing = {Continuing, 1};
        // Manually set the current state based on the first character
        switch (first) {
            case '*':
                processing.state = LeftAsterisk;
                if (lexer->lookahead == '/') {
                    // This case can happen in an empty doc block comment
                    // like /*!*/. The comment has no contents, so bail.
                    return false;
                }
                break;
            case '/':
                processing.state = LeftForwardSlash;
                break;
            default:
                processing.state = Continuing;
                break;
        }

        // For the purposes of actually parsing rust code, this
        // is incorrect as it considers an unterminated block comment
        // to be an error. However, for the purposes of syntax highlighting
        // this should be considered successful as otherwise you are not able
        // to syntax highlight a block of code prior to closing the
        // block comment
        while (!lexer->eof(lexer) && processing.nestingDepth != 0) {
            // Set first to the current lookahead as that is the second character
            // as we force an advance in the above code when we are checking if we
            // need to handle a block comment inner or outer doc comment signifier
            // node
            first = (char)lexer->lookahead;
            switch (processing.state) {
                case LeftForwardSlash:
                    process_left_forward_slash(&processing, first);
                    break;
                case LeftAsterisk:
                    process_left_asterisk(&processing, first, lexer);
                    break;
                case Continuing:
                    lexer->mark_end(lexer);
                    process_continuing(&processing, first);
                    break;
                default:
                    break;
            }
            advance(lexer);
            if (first == '/' && processing.nestingDepth != 0) {
                lexer->mark_end(lexer);
            }
        }
        lexer->result_symbol = BLOCK_COMMENT_CONTENT;
        return true;
    }

    return false;
}

bool tree_sitter_rust_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
    // The documentation states that if the lexical analysis fails for some reason
    // they will mark every state as valid and pass it to the external scanner
    // However, we can't do anything to help them recover in that case so we
    // should just fail.
    /*
      link: https://tree-sitter.github.io/tree-sitter/creating-parsers#external-scanners
      If a syntax error is encountered during regular parsing, Tree-sitter’s
      first action during error recovery will be to call the external scanner’s
      scan function with all tokens marked valid. The scanner should detect this
      case and handle it appropriately. One simple method of detection is to add
      an unused token to the end of the externals array, for example

      externals: $ => [$.token1, $.token2, $.error_sentinel],

      then check whether that token is marked valid to determine whether
      Tree-sitter is in error correction mode.
    */
    if (valid_symbols[ERROR_SENTINEL]) {
        return false;
    }

    Scanner *scanner = (Scanner *)payload;

    if (valid_symbols[BLOCK_COMMENT_CONTENT] || valid_symbols[BLOCK_INNER_DOC_MARKER] ||
        valid_symbols[BLOCK_OUTER_DOC_MARKER]) {
        return process_block_comment(lexer, valid_symbols);
    }

    if (valid_symbols[STRING_CONTENT] && !valid_symbols[FLOAT_LITERAL]) {
        if (process_string(lexer)) return true;
        // process_string returns false when the next char is '"' or '\' (no
        // content to emit). Fall through so STRING_CLOSE can consume the '"'.
    }

    if (valid_symbols[STRING_CLOSE] && lexer->lookahead == '"') {
        advance(lexer);
        lexer->result_symbol = STRING_CLOSE;
        lexer->mark_end(lexer);
        return true;
    }

    if (valid_symbols[LINE_DOC_CONTENT]) {
        return process_line_doc_content(lexer);
    }

    while (iswspace(lexer->lookahead)) {
        skip(lexer);
    }

    if (valid_symbols[RAW_STRING_LITERAL_START] &&
        (lexer->lookahead == 'r' || lexer->lookahead == 'b' || lexer->lookahead == 'c')) {
        return scan_raw_string_start(scanner, lexer);
    }

    if (valid_symbols[RAW_STRING_LITERAL_CONTENT]) {
        return scan_raw_string_content(scanner, lexer);
    }

    if (valid_symbols[RAW_STRING_LITERAL_END] && lexer->lookahead == '"') {
        return scan_raw_string_end(scanner, lexer);
    }

    if (valid_symbols[FLOAT_LITERAL] && iswdigit(lexer->lookahead)) {
        return process_float_literal(lexer);
    }

    return false;
}
