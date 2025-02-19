#pragma once

#include "nvim/decoration_defs.h"
#include "nvim/types_defs.h"

/// Sign attributes. Used by the screen refresh routines.
typedef struct {
  schar_T text[SIGN_WIDTH];
  int hl_id;
} SignTextAttrs;

/// Struct to hold the sign properties.
typedef struct {
  char *sn_name;   // name of sign
  char *sn_icon;   // name of pixmap
  schar_T sn_text[SIGN_WIDTH];   // text used instead of pixmap
  int sn_line_hl;  // highlight ID for line
  int sn_text_hl;  // highlight ID for text
  int sn_cul_hl;   // highlight ID for text on current line when 'cursorline' is set
  int sn_num_hl;   // highlight ID for line number
  int sn_priority;  // default priority of this sign, -1 means SIGN_DEF_PRIO
} sign_T;

typedef struct {
  DecorSignHighlight *sh;
  uint32_t id;
} SignItem;

enum { SIGN_SHOW_MAX = 9, };  ///< Maximum number of signs shown on a single line
enum { SIGN_DEF_PRIO = 10, };  ///< Default sign highlight priority
