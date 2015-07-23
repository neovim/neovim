/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

#ifndef NVIM_TYPES_H
#define NVIM_TYPES_H

#include <stdint.h>

// dummy to pass an ACL to a function
typedef void *vim_acl_T;

// Shorthand for unsigned variables. Many systems, but not all, have u_char
// already defined, so we use char_u to avoid trouble.
typedef unsigned char char_u;

// Can hold one decoded UTF-8 character.
typedef uint32_t u8char_T;

// A three-valued 'boolean' type.
// Note: kTriMaybe is non-zero and will therefore evaluate to true in a boolean
// context. See also: TRUE, FALSE and MAYBE definitions in vim.h
typedef enum {
    kTriFalse = 0,
    kTriTrue = 1,
    kTriMaybe = 2,
} TriState;

#endif  // NVIM_TYPES_H
