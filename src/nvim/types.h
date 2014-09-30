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

// According to the vanilla Vim docs, long_u needs to be big enough to hold
// a pointer for the platform. On C99, this is easy to do with the uintptr_t
// type in lieu of the platform-specific typedefs that existed before.
typedef uintptr_t long_u;

/*
 * Shorthand for unsigned variables. Many systems, but not all, have u_char
 * already defined, so we use char_u to avoid trouble.
 */
typedef unsigned char char_u;

// The u8char_T can hold one decoded UTF-8 character. We normally use 32
// bits now, since some Asian characters don't fit in 16 bits. u8char_T is
// only used for displaying, it could be 16 bits to save memory.
#ifdef UNICODE16
typedef uint16_t u8char_T;
#else
typedef uint32_t u8char_T;
#endif

#endif /* NVIM_TYPES_H */
