#pragma once

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/tui/terminfo_enum_defs.h"

typedef struct {
  bool bce;
  // these extended booleans indicate likely 24-color support
  bool has_Tc_or_RGB;
  bool Su;

  int max_colors;
  int lines;
  int columns;
  const char *defs[kTermCount];
} TerminfoEntry;

typedef struct {
  long num;
  char *string;
} TPVAR;

#include "tui/terminfo.h.generated.h"
