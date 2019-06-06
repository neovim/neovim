// The Tree-sitter library can be built by compiling this one source file.
//
// The following directories must be added to the include path:
//   - include
//   - utf8proc

#define _POSIX_C_SOURCE 200112L
#define UTF8PROC_STATIC

#include "./get_changed_ranges.c"
#include "./language.c"
#include "./lexer.c"
#include "./node.c"
#include "./parser.c"
#include "./stack.c"
#include "./subtree.c"
#include "./tree_cursor.c"
#include "./tree.c"
#include "./utf16.c"
#include "utf8proc.c"
