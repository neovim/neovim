#pragma once

/// Sign attributes. Used by the screen refresh routines.
typedef struct {
  char *text;
  int hl_id;
} SignTextAttrs;

/// Struct to hold the sign properties.
typedef struct sign {
  char *sn_name;   // name of sign
  char *sn_icon;   // name of pixmap
  char *sn_text;   // text used instead of pixmap
  int sn_line_hl;  // highlight ID for line
  int sn_text_hl;  // highlight ID for text
  int sn_cul_hl;   // highlight ID for text on current line when 'cursorline' is set
  int sn_num_hl;   // highlight ID for line number
} sign_T;

enum { SIGN_WIDTH = 2, };  ///< Number of display cells for a sign in the signcolumn
enum { SIGN_SHOW_MAX = 9, };  ///< Maximum number of signs shown on a single line
enum { SIGN_DEF_PRIO = 10, };  ///< Default sign highlight priority
