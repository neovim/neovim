/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

#ifndef NVIM_ASCII_H
#define NVIM_ASCII_H

// Definitions of various common control characters.

#define CharOrd(x)      ((x) < 'a' ? (x) - 'A' : (x) - 'a')
#define CharOrdLow(x)   ((x) - 'a')
#define CharOrdUp(x)    ((x) - 'A')
#define ROT13(c, a)     (((((c) - (a)) + 13) % 26) + (a))

#define NUL             '\000'
#define BELL            '\007'
#define BS              '\010'
#define TAB             '\011'
#define NL              '\012'
#define NL_STR          (char_u *)"\012"
#define FF              '\014'
#define CAR             '\015'  /* CR is used by Mac OS X */
#define ESC             '\033'
#define ESC_STR         (char_u *)"\033"
#define ESC_STR_nc      "\033"
#define DEL             0x7f
#define DEL_STR         (char_u *)"\177"
#define CSI             0x9b    /* Control Sequence Introducer */
#define CSI_STR         "\233"
#define DCS             0x90    /* Device Control String */
#define STERM           0x9c    /* String Terminator */

#define POUND           0xA3

#define Ctrl_chr(x)     (TOUPPER_ASC(x) ^ 0x40) /* '?' -> DEL, '@' -> ^@, etc. */
#define Meta(x)         ((x) | 0x80)

#define CTRL_F_STR      "\006"
#define CTRL_H_STR      "\010"
#define CTRL_V_STR      "\026"

#define Ctrl_AT         0   /* @ */
#define Ctrl_A          1
#define Ctrl_B          2
#define Ctrl_C          3
#define Ctrl_D          4
#define Ctrl_E          5
#define Ctrl_F          6
#define Ctrl_G          7
#define Ctrl_H          8
#define Ctrl_I          9
#define Ctrl_J          10
#define Ctrl_K          11
#define Ctrl_L          12
#define Ctrl_M          13
#define Ctrl_N          14
#define Ctrl_O          15
#define Ctrl_P          16
#define Ctrl_Q          17
#define Ctrl_R          18
#define Ctrl_S          19
#define Ctrl_T          20
#define Ctrl_U          21
#define Ctrl_V          22
#define Ctrl_W          23
#define Ctrl_X          24
#define Ctrl_Y          25
#define Ctrl_Z          26
/* CTRL- [ Left Square Bracket == ESC*/
#define Ctrl_BSL        28  /* \ BackSLash */
#define Ctrl_RSB        29  /* ] Right Square Bracket */
#define Ctrl_HAT        30  /* ^ */
#define Ctrl__          31


/*
 * Character that separates dir names in a path.
 */
#ifdef BACKSLASH_IN_FILENAME
# define PATHSEP        psepc
# define PATHSEPSTR     pseps
#else
# define PATHSEP        '/'
# define PATHSEPSTR     "/"
#endif

#endif /* NVIM_ASCII_H */
