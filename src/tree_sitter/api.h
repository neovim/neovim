#ifndef TREE_SITTER_API_H_
#define TREE_SITTER_API_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

/****************************/
/* Section - ABI Versioning */
/****************************/

#define TREE_SITTER_LANGUAGE_VERSION 11
#define TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION 9

/*******************/
/* Section - Types */
/*******************/

typedef uint16_t TSSymbol;
typedef uint16_t TSFieldId;
typedef struct TSLanguage TSLanguage;
typedef struct TSParser TSParser;
typedef struct TSTree TSTree;

typedef enum {
  TSInputEncodingUTF8,
  TSInputEncodingUTF16,
} TSInputEncoding;

typedef enum {
  TSSymbolTypeRegular,
  TSSymbolTypeAnonymous,
  TSSymbolTypeAuxiliary,
} TSSymbolType;

typedef struct {
  uint32_t row;
  uint32_t column;
} TSPoint;

typedef struct {
  TSPoint start_point;
  TSPoint end_point;
  uint32_t start_byte;
  uint32_t end_byte;
} TSRange;

typedef struct {
  void *payload;
  const char *(*read)(void *payload, uint32_t byte_index, TSPoint position, uint32_t *bytes_read);
  TSInputEncoding encoding;
} TSInput;

typedef enum {
  TSLogTypeParse,
  TSLogTypeLex,
} TSLogType;

typedef struct {
  void *payload;
  void (*log)(void *payload, TSLogType, const char *);
} TSLogger;

typedef struct {
  uint32_t start_byte;
  uint32_t old_end_byte;
  uint32_t new_end_byte;
  TSPoint start_point;
  TSPoint old_end_point;
  TSPoint new_end_point;
} TSInputEdit;

typedef struct {
  uint32_t context[4];
  const void *id;
  const TSTree *tree;
} TSNode;

typedef struct {
  const void *tree;
  const void *id;
  uint32_t context[2];
} TSTreeCursor;

/********************/
/* Section - Parser */
/********************/

/**
 * Create a new parser.
 */
TSParser *ts_parser_new(void);

/**
 * Delete the parser, freeing all of the memory that it used.
 */
void ts_parser_delete(TSParser *parser);

/**
 * Set the language that the parser should use for parsing.
 *
 * Returns a boolean indicating whether or not the language was successfully
 * assigned. True means assignment succeeded. False means there was a version
 * mismatch: the language was generated with an incompatible version of the
 * Tree-sitter CLI. Check the language's version using `ts_language_version`
 * and compare it to this library's `TREE_SITTER_LANGUAGE_VERSION` and
 * `TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION` constants.
 */
bool ts_parser_set_language(TSParser *self, const TSLanguage *language);

/**
 * Get the parser's current language.
 */
const TSLanguage *ts_parser_language(const TSParser *self);

/**
 * Set the spans of text that the parser should include when parsing.
 *
 * By default, the parser will always include entire documents. This function
 * allows you to parse only a *portion* of a document but still return a syntax
 * tree whose ranges match up with the document as a whole. You can also pass
 * multiple disjoint ranges.
 *
 * The second and third parameters specify the location and length of an array
 * of ranges. The parser does *not* take ownership of these ranges; it copies
 * the data, so it doesn't matter how these ranges are allocated.
 */
void ts_parser_set_included_ranges(
  TSParser *self,
  const TSRange *ranges,
  uint32_t length
);

/**
 * Get the ranges of text that the parser will include when parsing.
 *
 * The returned pointer is owned by the parser. The caller should not free it
 * or write to it. The length of the array will be written to the given
 * `length` pointer.
 */
const TSRange *ts_parser_included_ranges(
  const TSParser *self,
  uint32_t *length
);

/**
 * Use the parser to parse some source code and create a syntax tree.
 *
 * If you are parsing this document for the first time, pass `NULL` for the
 * `old_tree` parameter. Otherwise, if you have already parsed an earlier
 * version of this document and the document has since been edited, pass the
 * previous syntax tree so that the unchanged parts of it can be reused.
 * This will save time and memory. For this to work correctly, you must have
 * already edited the old syntax tree using the `ts_tree_edit` function in a
 * way that exactly matches the source code changes.
 *
 * The `TSInput` parameter lets you specify how to read the text. It has the
 * following three fields:
 * 1. `read`: A function to retrieve a chunk of text at a given byte offset
 *    and (row, column) position. The function should return a pointer to the
 *    text and write its length to the the `bytes_read` pointer. The parser
 *    does not take ownership of this buffer; it just borrows it until it has
 *    finished reading it. The function should write a zero value to the
 *    `bytes_read` pointer to indicate the end of the document.
 * 2. `payload`: An arbitrary pointer that will be passed to each invocation
 *    of the `read` function.
 * 3. `encoding`: An indication of how the text is encoded. Either
 *    `TSInputEncodingUTF8` or `TSInputEncodingUTF16`.
 *
 * This function returns a syntax tree on success, and `NULL` on failure. There
 * are three possible reasons for failure:
 * 1. The parser does not have a language assigned. Check for this using the
      `ts_parser_language` function.
 * 2. Parsing was cancelled due to a timeout that was set by an earlier call to
 *    the `ts_parser_set_timeout_micros` function. You can resume parsing from
 *    where the parser left out by calling `ts_parser_parse` again with the
 *    same arguments. Or you can start parsing from scratch by first calling
 *    `ts_parser_reset`.
 * 3. Parsing was cancelled using a cancellation flag that was set by an
 *    earlier call to `ts_parser_set_cancellation_flag`. You can resume parsing
 *    from where the parser left out by calling `ts_parser_parse` again with
 *    the same arguments.
 */
TSTree *ts_parser_parse(
  TSParser *self,
  const TSTree *old_tree,
  TSInput input
);

/**
 * Use the parser to parse some source code stored in one contiguous buffer.
 * The first two parameters are the same as in the `ts_parser_parse` function
 * above. The second two parameters indicate the location of the buffer and its
 * length in bytes.
 */
TSTree *ts_parser_parse_string(
  TSParser *self,
  const TSTree *old_tree,
  const char *string,
  uint32_t length
);

/**
 * Use the parser to parse some source code stored in one contiguous buffer with
 * a given encoding. The first four parameters work the same as in the
 * `ts_parser_parse_string` method above. The final parameter indicates whether
 * the text is encoded as UTF8 or UTF16.
 */
TSTree *ts_parser_parse_string_encoding(
  TSParser *self,
  const TSTree *old_tree,
  const char *string,
  uint32_t length,
  TSInputEncoding encoding
);

/**
 * Instruct the parser to start the next parse from the beginning.
 *
 * If the parser previously failed because of a timeout or a cancellation, then
 * by default, it will resume where it left off on the next call to
 * `ts_parser_parse` or other parsing functions. If you don't want to resume,
 * and instead intend to use this parser to parse some other document, you must
 * call this `ts_parser_reset` first.
 */
void ts_parser_reset(TSParser *self);

/**
 * Set the maximum duration in microseconds that parsing should be allowed to
 * take before halting. If parsing takes longer than this, it will halt early,
 * returning NULL. See `ts_parser_parse` for more information.
 */
void ts_parser_set_timeout_micros(TSParser *self, uint64_t timeout);

/**
 * Get the duration in microseconds that parsing is allowed to take.
 */
uint64_t ts_parser_timeout_micros(const TSParser *self);

/**
 * Set the parser's current cancellation flag pointer. If a non-null pointer is
 * assigned, then the parser will periodically read from this pointer during
 * parsing. If it reads a non-zero value, it will halt early, returning NULL.
 * See `ts_parser_parse` for more information.
 */
void ts_parser_set_cancellation_flag(TSParser *self, const size_t *flag);

/**
 * Get the parser's current cancellation flag pointer.
 */
const size_t *ts_parser_cancellation_flag(const TSParser *self);

/**
 * Set the logger that a parser should use during parsing.
 *
 * The parser does not take ownership over the logger payload. If a logger was
 * previously assigned, the caller is responsible for releasing any memory
 * owned by the previous logger.
 */
void ts_parser_set_logger(TSParser *self, TSLogger logger);

/**
 * Get the parser's current logger.
 */
TSLogger ts_parser_logger(const TSParser *self);

/**
 * Set the file descriptor to which the parser should write debugging graphs
 * during parsing. The graphs are formatted in the DOT language. You may want
 * to pipe these graphs directly to a `dot(1)` process in order to generate
 * SVG output. You can turn off this logging by passing a negative number.
 */
void ts_parser_print_dot_graphs(TSParser *self, int file);

/**
 * Set whether or not the parser should halt immediately upon detecting an
 * error. This will generally result in a syntax tree with an error at the
 * root, and one or more partial syntax trees within the error. This behavior
 * may not be supported long-term.
 */
void ts_parser_halt_on_error(TSParser *self, bool halt);

/******************/
/* Section - Tree */
/******************/

/**
 * Create a shallow copy of the syntax tree. This is very fast.
 *
 * You need to copy a syntax tree in order to use it on more than one thread at
 * a time, as syntax trees are not thread safe.
 */
TSTree *ts_tree_copy(const TSTree *self);

/**
 * Delete the syntax tree, freeing all of the memory that it used.
 */
void ts_tree_delete(TSTree *self);

/**
 * Get the root node of the syntax tree.
 */
TSNode ts_tree_root_node(const TSTree *self);

/**
 * Get the language that was used to parse the syntax tree.
 */
const TSLanguage *ts_tree_language(const TSTree *);

/**
 * Edit the syntax tree to keep it in sync with source code that has been
 * edited.
 *
 * You must describe the edit both in terms of byte offsets and in terms of
 * (row, column) coordinates.
 */
void ts_tree_edit(TSTree *self, const TSInputEdit *edit);

/**
 * Compare a new syntax tree to a previous syntax tree representing the same
 * document, returning an array of ranges whose syntactic structure has changed.
 *
 * For this to work correctly, the old syntax tree must have been edited such
 * that its ranges match up to the new tree. Generally, you'll want to call
 * this function right after calling one of the `ts_parser_parse` functions,
 * passing in the new tree that was returned from `ts_parser_parse` and the old
 * tree that was passed as a parameter.
 *
 * The returned array is allocated using `malloc` and the caller is responsible
 * for freeing it using `free`. The length of the array will be written to the
 * given `length` pointer.
 */
TSRange *ts_tree_get_changed_ranges(
  const TSTree *self,
  const TSTree *old_tree,
  uint32_t *length
);

/**
 * Write a DOT graph describing the syntax tree to the given file.
 */
void ts_tree_print_dot_graph(const TSTree *, FILE *);

/******************/
/* Section - Node */
/******************/

/**
 * Get the node's type as a null-terminated string.
 */
const char *ts_node_type(TSNode);

/**
 * Get the node's type as a numerical id.
 */
TSSymbol ts_node_symbol(TSNode);

/**
 * Get the node's start byte.
 */
uint32_t ts_node_start_byte(TSNode);

/**
 * Get the node's start position in terms of rows and columns.
 */
TSPoint ts_node_start_point(TSNode);

/**
 * Get the node's end byte.
 */
uint32_t ts_node_end_byte(TSNode);

/**
 * Get the node's end position in terms of rows and columns.
 */
TSPoint ts_node_end_point(TSNode);

/**
 * Get an S-expression representing the node as a string.
 *
 * This string is allocated with `malloc` and the caller is responsible for
 * freeing it using `free`.
 */
char *ts_node_string(TSNode);

/**
 * Check if the node is null. Functions like `ts_node_child` and
 * `ts_node_next_sibling` will return a null node to indicate that no such node
 * was found.
 */
bool ts_node_is_null(TSNode);

/**
 * Check if the node is *named*. Named nodes correspond to named rules in the
 * grammar, whereas *anonymous* nodes correspond to string literals in the
 * grammar.
 */
bool ts_node_is_named(TSNode);

/**
 * Check if the node is *missing*. Missing nodes are inserted by the parser in
 * order to recover from certain kinds of syntax errors.
 */
bool ts_node_is_missing(TSNode);

/**
 * Check if the node is *missing*. Missing nodes are inserted by the parser in
 * order to recover from certain kinds of syntax errors.
 */
bool ts_node_is_extra(TSNode);

/**
 * Check if a syntax node has been edited.
 */
bool ts_node_has_changes(TSNode);

/**
 * Check if the node is a syntax error or contains any syntax errors.
 */
bool ts_node_has_error(TSNode);

/**
 * Get the node's immediate parent.
 */
TSNode ts_node_parent(TSNode);

/**
 * Get the node's child at the given index, where zero represents the first
 * child.
 */
TSNode ts_node_child(TSNode, uint32_t);

/**
 * Get the node's number of children.
 */
uint32_t ts_node_child_count(TSNode);

/**
 * Get the node's *named* child at the given index.
 *
 * See also `ts_node_is_named`.
 */
TSNode ts_node_named_child(TSNode, uint32_t);

/**
 * Get the node's number of *named* children.
 *
 * See also `ts_node_is_named`.
 */
uint32_t ts_node_named_child_count(TSNode);

/**
 * Get the node's child with the given field name.
 */
TSNode ts_node_child_by_field_name(
  TSNode self,
  const char *field_name,
  uint32_t field_name_length
);

/**
 * Get the node's child with the given numerical field id.
 *
 * You can convert a field name to an id using the
 * `ts_language_field_id_for_name` function.
 */
TSNode ts_node_child_by_field_id(TSNode, TSFieldId);

/**
 * Get the node's next / previous sibling.
 */
TSNode ts_node_next_sibling(TSNode);
TSNode ts_node_prev_sibling(TSNode);

/**
 * Get the node's next / previous *named* sibling.
 */
TSNode ts_node_next_named_sibling(TSNode);
TSNode ts_node_prev_named_sibling(TSNode);

/**
 * Get the node's first child that extends beyond the given byte offset.
 */
TSNode ts_node_first_child_for_byte(TSNode, uint32_t);

/**
 * Get the node's first named child that extends beyond the given byte offset.
 */
TSNode ts_node_first_named_child_for_byte(TSNode, uint32_t);

/**
 * Get the smallest node within this node that spans the given range of bytes
 * or (row, column) positions.
 */
TSNode ts_node_descendant_for_byte_range(TSNode, uint32_t, uint32_t);
TSNode ts_node_descendant_for_point_range(TSNode, TSPoint, TSPoint);

/**
 * Get the smallest named node within this node that spans the given range of
 * bytes or (row, column) positions.
 */
TSNode ts_node_named_descendant_for_byte_range(TSNode, uint32_t, uint32_t);
TSNode ts_node_named_descendant_for_point_range(TSNode, TSPoint, TSPoint);

/**
 * Edit the node to keep it in-sync with source code that has been edited.
 *
 * This function is only rarely needed. When you edit a syntax tree with the
 * `ts_tree_edit` function, all of the nodes that you retrieve from the tree
 * afterward will already reflect the edit. You only need to use `ts_node_edit`
 * when you have a `TSNode` instance that you want to keep and continue to use
 * after an edit.
 */
void ts_node_edit(TSNode *, const TSInputEdit *);

/**
 * Check if two nodes are identical.
 */
bool ts_node_eq(TSNode, TSNode);

/************************/
/* Section - TreeCursor */
/************************/

/**
 * Create a new tree cursor starting from the given node.
 *
 * A tree cursor allows you to walk a syntax tree more efficiently than is
 * possible using the `TSNode` functions. It is a mutable object that is always
 * on a certain syntax node, and can be moved imperatively to different nodes.
 */
TSTreeCursor ts_tree_cursor_new(TSNode);

/**
 * Delete a tree cursor, freeing all of the memory that it used.
 */
void ts_tree_cursor_delete(TSTreeCursor *);

/**
 * Re-initialize a tree cursor to start at a different ndoe.
 */
void ts_tree_cursor_reset(TSTreeCursor *, TSNode);

/**
 * Get the tree cursor's current node.
 */
TSNode ts_tree_cursor_current_node(const TSTreeCursor *);

/**
 * Get the field name of the tree cursor's current node.
 *
 * This returns `NULL` if the current node doesn't have a field.
 * See also `ts_node_child_by_field_name`.
 */
const char *ts_tree_cursor_current_field_name(const TSTreeCursor *);

/**
 * Get the field name of the tree cursor's current node.
 *
 * This returns zero if the current node doesn't have a field.
 * See also `ts_node_child_by_field_id`, `ts_language_field_id_for_name`.
 */
TSFieldId ts_tree_cursor_current_field_id(const TSTreeCursor *);

/**
 * Move the cursor to the parent of its current node.
 *
 * This returns `true` if the cursor successfully moved, and returns `false`
 * if there was no parent node (the cursor was already on the root node).
 */
bool ts_tree_cursor_goto_parent(TSTreeCursor *);

/**
 * Move the cursor to the next sibling of its current node.
 *
 * This returns `true` if the cursor successfully moved, and returns `false`
 * if there was no next sibling node.
 */
bool ts_tree_cursor_goto_next_sibling(TSTreeCursor *);

/**
 * Move the cursor to the first schild of its current node.
 *
 * This returns `true` if the cursor successfully moved, and returns `false`
 * if there were no children.
 */
bool ts_tree_cursor_goto_first_child(TSTreeCursor *);

/**
 * Move the cursor to the first schild of its current node that extends beyond
 * the given byte offset.
 *
 * This returns the index of the child node if one was found, and returns -1
 * if no such child was found.
 */
int64_t ts_tree_cursor_goto_first_child_for_byte(TSTreeCursor *, uint32_t);

TSTreeCursor ts_tree_cursor_copy(const TSTreeCursor *);

/**********************/
/* Section - Language */
/**********************/

/**
 * Get the number of distinct node types in the language.
 */
uint32_t ts_language_symbol_count(const TSLanguage *);

/**
 * Get a node type string for the given numerical id.
 */
const char *ts_language_symbol_name(const TSLanguage *, TSSymbol);

/**
 * Get the numerical id for the given node type string.
 */
TSSymbol ts_language_symbol_for_name(const TSLanguage *, const char *);

/**
 * Get the number of distinct field names in the language.
 */
uint32_t ts_language_field_count(const TSLanguage *);

/**
 * Get the field name string for the given numerical id.
 */
const char *ts_language_field_name_for_id(const TSLanguage *, TSFieldId);

/**
 * Get the numerical id for the given field name string.
 */
TSFieldId ts_language_field_id_for_name(const TSLanguage *, const char *, uint32_t);

/**
 * Check whether the given node type id belongs to named nodes, anonymous nodes,
 * or a hidden nodes.
 *
 * See also `ts_node_is_named`. Hidden nodes are never returned from the API.
 */
TSSymbolType ts_language_symbol_type(const TSLanguage *, TSSymbol);

/**
 * Get the ABI version number for this language. This version number is used
 * to ensure that languages were generated by a compatible version of
 * Tree-sitter.
 *
 * See also `ts_parser_set_language`.
 */
uint32_t ts_language_version(const TSLanguage *);

#ifdef __cplusplus
}
#endif

#endif  // TREE_SITTER_API_H_
