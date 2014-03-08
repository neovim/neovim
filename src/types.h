/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

#ifndef NEOVIM_TYPES_H
#define NEOVIM_TYPES_H

#include <stdint.h>

/*
 * Shorthand for unsigned variables. Many systems, but not all, have u_char
 * already defined, so we use char_u to avoid trouble.
 */
typedef uint8_t  char_u;
/*
 * FIXME: Remove these?
 */
typedef uint16_t short_u;
typedef uint32_t int_u;
/*
 * FIXME; Replace long_u by size_t, uintptr_t, uint64_t, etc. in the source.
 * XXX: Right now long_u must hold a pointer.
 */
typedef uint64_t long_u;
typedef int64_t  long_i;

#endif /* NEOVIM_TYPES_H */
