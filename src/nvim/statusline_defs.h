#pragma once

#include <stddef.h>

#include "nvim/fold_defs.h"
#include "nvim/macros.h"
#include "nvim/os/os_defs.h"
#include "nvim/sign_defs.h"

/// Status line click definition
typedef struct {
  enum {
    kStlClickDisabled = 0,  ///< Clicks to this area are ignored.
    kStlClickTabSwitch,     ///< Switch to the given tab.
    kStlClickTabClose,      ///< Close given tab.
    kStlClickFuncRun,       ///< Run user function.
  } type;      ///< Type of the click.
  int tabnr;   ///< Tab page number.
  char *func;  ///< Function to run.
} StlClickDefinition;

/// Used for tabline clicks
typedef struct {
  StlClickDefinition def;  ///< Click definition.
  const char *start;       ///< Location where region starts.
} StlClickRecord;

/// Used for highlighting in the status line.
typedef struct stl_hlrec stl_hlrec_t;
struct stl_hlrec {
  char *start;
  int userhl;                   // 0: no HL, 1-9: User HL, < 0 for syn ID
};

/// Used for building the status line.
typedef struct stl_item stl_item_t;
struct stl_item {
  // Where the item starts in the status line output buffer
  char *start;
  // Function to run for ClickFunc items.
  char *cmd;
  // The minimum width of the item
  int minwid;
  // The maximum width of the item
  int maxwid;
  enum {
    Normal,
    Empty,
    Group,
    Separate,
    Highlight,
    TabPage,
    ClickFunc,
    Trunc,
  } type;
};

/// Struct to hold info for 'statuscolumn'
typedef struct statuscol statuscol_T;

struct statuscol {
  int width;                           ///< width of the status column
  int cur_attr;                        ///< current attributes in text
  int num_attr;                        ///< default highlight attr
  int sign_cul_id;                     ///< cursorline sign highlight id
  int truncate;                        ///< truncated width
  bool draw;                           ///< whether to draw the statuscolumn
  bool use_cul;                        ///< whether to use cursorline attrs
  char text[MAXPATHL];                 ///< text in status column
  char *textp;                         ///< current position in text
  char *text_end;                      ///< end of text (the NUL byte)
  stl_hlrec_t *hlrec;                  ///< highlight groups
  stl_hlrec_t *hlrecp;                 ///< current highlight group
  foldinfo_T foldinfo;                 ///< fold information
  SignTextAttrs *sattrs;               ///< sign attributes
};
