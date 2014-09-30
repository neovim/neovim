/// @file farsi.h
///
/// Farsi characters are categorized into following types:
///
/// TyA  (for capital letter representation)
/// TyB  (for types that look like _X  e.g. AYN)
/// TyC  (for types that look like X_  e.g. YE_)
/// TyD  (for types that look like _X_  e.g. _AYN_)
/// TyE  (for types that look like X  e.g. RE)

#ifndef NVIM_FARSI_H
#define NVIM_FARSI_H

#include "nvim/normal.h"
#include "nvim/types.h"

// Farsi character set definition

// Begin of the non-standard part

#define TEE_            0x80
#define ALEF_U_H_       0x81
#define ALEF_           0x82
#define _BE             0x83
#define _PE             0x84
#define _TE             0x85
#define _SE             0x86
#define _JIM            0x87
#define _CHE            0x88
#define _HE_J           0x89
#define _XE             0x8a
#define _SIN            0x8b
#define _SHIN           0x8c
#define _SAD            0x8d
#define _ZAD            0x8e
#define _AYN            0x8f
#define _AYN_           0x90
#define AYN_            0x91
#define _GHAYN          0x92
#define _GHAYN_         0x93
#define GHAYN_          0x94
#define _FE             0x95
#define _GHAF           0x96
#define _KAF            0x97
#define _GAF            0x98
#define _LAM            0x99
#define LA              0x9a
#define _MIM            0x9b
#define _NOON           0x9c
#define _HE             0x9d
#define _HE_            0x9e
#define _YE             0x9f
#define _IE             0xec
#define IE_             0xed
#define IE              0xfb
#define _YEE            0xee
#define YEE_            0xef
#define YE_             0xff

// End of the non-standard part

// Standard part

#define F_BLANK         0xa0    // Farsi ' ' (SP) character
#define F_PSP           0xa1    // PSP for capitalizing of a character
#define F_PCN           0xa2    // PCN for redefining of the hamye meaning
#define F_EXCL          0xa3    // Farsi ! character
#define F_CURRENCY      0xa4    // Farsi Rial character
#define F_PERCENT       0xa5    // Farsi % character
#define F_PERIOD        0xa6    // Farsi '.' character
#define F_COMMA         0xa7    // Farsi ',' character
#define F_LPARENT       0xa8    // Farsi '(' character
#define F_RPARENT       0xa9    // Farsi ')' character
#define F_MUL           0xaa    // Farsi 'x' character
#define F_PLUS          0xab    // Farsi '+' character
#define F_BCOMMA        0xac    // Farsi comma character
#define F_MINUS         0xad    // Farsi '-' character
#define F_DIVIDE        0xae    // Farsi divide (/) character
#define F_SLASH         0xaf    // Farsi '/' character

#define FARSI_0         0xb0
#define FARSI_1         0xb1
#define FARSI_2         0xb2
#define FARSI_3         0xb3
#define FARSI_4         0xb4
#define FARSI_5         0xb5
#define FARSI_6         0xb6
#define FARSI_7         0xb7
#define FARSI_8         0xb8
#define FARSI_9         0xb9

#define F_DCOLON        0xba    // Farsi ':' character
#define F_SEMICOLON     0xbb    // Farsi ';' character
#define F_GREATER       0xbc    // Farsi '>' character
#define F_EQUALS        0xbd    // Farsi '=' character
#define F_LESS          0xbe    // Farsi '<' character
#define F_QUESTION      0xbf    // Farsi ? character

#define ALEF_A  0xc0
#define ALEF    0xc1
#define HAMZE   0xc2
#define BE      0xc3
#define PE      0xc4
#define TE      0xc5
#define SE      0xc6
#define JIM     0xc7
#define CHE     0xc8
#define HE_J    0xc9
#define XE      0xca
#define DAL     0xcb
#define ZAL     0xcc
#define RE      0xcd
#define ZE      0xce
#define JE      0xcf
#define SIN     0xd0
#define SHIN    0xd1
#define SAD     0xd2
#define ZAD     0xd3
#define _TA     0xd4
#define _ZA     0xd5
#define AYN     0xd6
#define GHAYN   0xd7
#define FE      0xd8
#define GHAF    0xd9
#define KAF     0xda
#define GAF     0xdb
#define LAM     0xdc
#define MIM     0xdd
#define NOON    0xde
#define WAW     0xdf
#define F_HE    0xe0            // F_ added for name clash with Perl
#define YE      0xe1
#define TEE     0xfc
#define _KAF_H  0xfd
#define YEE     0xfe

#define F_LBRACK        0xe2    // Farsi '[' character
#define F_RBRACK        0xe3    // Farsi ']' character
#define F_LBRACE        0xe4    // Farsi '{' character
#define F_RBRACE        0xe5    // Farsi '}' character
#define F_LQUOT         0xe6    // Farsi left quotation character
#define F_RQUOT         0xe7    // Farsi right quotation character
#define F_STAR          0xe8    // Farsi '*' character
#define F_UNDERLINE     0xe9    // Farsi '_' character
#define F_PIPE          0xea    // Farsi '|' character
#define F_BSLASH        0xeb    // Farsi '\' character

#define MAD             0xf0
#define JAZR            0xf1
#define OW              0xf2
#define MAD_N           0xf3
#define JAZR_N          0xf4
#define OW_OW           0xf5
#define TASH            0xf6
#define OO              0xf7
#define ALEF_U_H        0xf8
#define WAW_H           0xf9
#define ALEF_D_H        0xfa

// definitions for the window dependent functions (w_farsi).
#define W_CONV 0x1
#define W_R_L  0x2

// special Farsi text messages
extern const char_u farsi_text_1[];
extern const char_u farsi_text_2[];
extern const char_u farsi_text_3[];
extern const char_u farsi_text_5[];


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "farsi.h.generated.h"
#endif
#endif  // NVIM_FARSI_H
