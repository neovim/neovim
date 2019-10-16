#ifndef TREE_SITTER_UTF16_H_
#define TREE_SITTER_UTF16_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdlib.h>
#include "utf8proc.h"

// Analogous to utf8proc's utf8proc_iterate function. Reads one code point from
// the given UTF16 string and stores it in the location pointed to by `code_point`.
// Returns the number of bytes in `string` that were read.
utf8proc_ssize_t utf16_iterate(const utf8proc_uint8_t *, utf8proc_ssize_t, utf8proc_int32_t *);

#ifdef __cplusplus
}
#endif

#endif  // TREE_SITTER_UTF16_H_
