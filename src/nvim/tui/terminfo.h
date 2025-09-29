#pragma once

#include <unibilium.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep

#include "nvim/tui/terminfo_enum.h"

typedef struct {
  bool bce;
  // these extended booleans indiciate likely 24-color support
  bool has_Tc_or_RGB;
  bool Su;

  int max_colors;
  int lines;
  int columns;
  const char *defs[kTermCount];
} NeoTerminfo;

#include "tui/terminfo.h.generated.h"
