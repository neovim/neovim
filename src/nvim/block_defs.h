#pragma once

#include "nvim/pos_defs.h"

/// structure used by block_prep, op_delete and op_yank for blockwise operators
/// also op_change, op_shift, op_insert, op_replace - AKelly
struct block_def {
  int startspaces;           ///< 'extra' cols before first char
  int endspaces;             ///< 'extra' cols after last char
  int textlen;               ///< chars in block
  char *textstart;           ///< pointer to 1st char (partially) in block
  colnr_T textcol;           ///< index of chars (partially) in block
  colnr_T start_vcol;        ///< start col of 1st char wholly inside block
  colnr_T end_vcol;          ///< start col of 1st char wholly after block
  int is_short;              ///< true if line is too short to fit in block
  int is_MAX;                ///< true if curswant==MAXCOL when starting
  int is_oneChar;            ///< true if block within one character
  int pre_whitesp;           ///< screen cols of ws before block
  int pre_whitesp_c;         ///< chars of ws before block
  colnr_T end_char_vcols;    ///< number of vcols of post-block char
  colnr_T start_char_vcols;  ///< number of vcols of pre-block char
};
