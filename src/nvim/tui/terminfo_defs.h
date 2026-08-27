#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/tui/terminfo_enum_defs.h"

typedef struct {
  bool back_color_erase;
  // these extended booleans indicate likely 24-color support
  bool Tc;
  bool RGB;
  bool Su;

  int max_colors;
  int lines;
  int columns;
  const char *defs[kTermCount];
  const char *keys[kTermKeyCount][2];
  const char *f_keys[kTerminfoFuncKeyMax];
} TerminfoEntry;
