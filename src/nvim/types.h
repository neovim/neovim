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

typedef struct expand expand_T;

#define MAX_MCO        6                 // maximum value for 'maxcombine'

/*
 * The characters and attributes cached for the screen.
 */
typedef char_u schar_T;
typedef unsigned short sattr_T;

// TODO(bfredl): find me a good home
typedef struct {
  schar_T  *ScreenLines;
  sattr_T  *ScreenAttrs;
  unsigned *LineOffset;
  char_u   *LineWraps;

  u8char_T *ScreenLinesUC;
  u8char_T *ScreenLinesC[MAX_MCO];
  int Screen_mco;

  int Rows;
  int Columns;
} ScreenGrid;

#endif  // NVIM_TYPES_H
