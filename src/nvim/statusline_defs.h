#pragma once

#include <stdbool.h>

#include "nvim/fold_defs.h"
#include "nvim/sign_defs.h"

/// 'statusline' item flags
typedef enum {
  STL_FILEPATH        = 'f',  ///< Path of file in buffer.
  STL_FULLPATH        = 'F',  ///< Full path of file in buffer.
  STL_FILENAME        = 't',  ///< Last part (tail) of file path.
  STL_COLUMN          = 'c',  ///< Column og cursor.
  STL_VIRTCOL         = 'v',  ///< Virtual column.
  STL_VIRTCOL_ALT     = 'V',  ///< - with 'if different' display.
  STL_LINE            = 'l',  ///< Line number of cursor.
  STL_NUMLINES        = 'L',  ///< Number of lines in buffer.
  STL_BUFNO           = 'n',  ///< Current buffer number.
  STL_KEYMAP          = 'k',  ///< 'keymap' when active.
  STL_OFFSET          = 'o',  ///< Offset of character under cursor.
  STL_OFFSET_X        = 'O',  ///< - in hexadecimal.
  STL_BYTEVAL         = 'b',  ///< Byte value of character.
  STL_BYTEVAL_X       = 'B',  ///< - in hexadecimal.
  STL_ROFLAG          = 'r',  ///< Readonly flag.
  STL_ROFLAG_ALT      = 'R',  ///< - other display.
  STL_HELPFLAG        = 'h',  ///< Window is showing a help file.
  STL_HELPFLAG_ALT    = 'H',  ///< - other display.
  STL_FILETYPE        = 'y',  ///< 'filetype'.
  STL_FILETYPE_ALT    = 'Y',  ///< - other display.
  STL_PREVIEWFLAG     = 'w',  ///< Window is showing the preview buf.
  STL_PREVIEWFLAG_ALT = 'W',  ///< - other display.
  STL_MODIFIED        = 'm',  ///< Modified flag.
  STL_MODIFIED_ALT    = 'M',  ///< - other display.
  STL_QUICKFIX        = 'q',  ///< Quickfix window description.
  STL_PERCENTAGE      = 'p',  ///< Percentage through file.
  STL_ALTPERCENT      = 'P',  ///< Percentage as TOP BOT ALL or NN%.
  STL_ARGLISTSTAT     = 'a',  ///< Argument list status as (x of y).
  STL_PAGENUM         = 'N',  ///< Page number (when printing).
  STL_SHOWCMD         = 'S',  ///< 'showcmd' buffer
  STL_FOLDCOL         = 'C',  ///< Fold column for 'statuscolumn'
  STL_SIGNCOL         = 's',  ///< Sign column for 'statuscolumn'
  STL_VIM_EXPR        = '{',  ///< Start of expression to substitute.
  STL_SEPARATE        = '=',  ///< Separation between alignment sections.
  STL_TRUNCMARK       = '<',  ///< Truncation mark if line is too long.
  STL_USER_HL         = '*',  ///< Highlight from (User)1..9 or 0.
  STL_HIGHLIGHT       = '#',  ///< Highlight name.
  STL_TABPAGENR       = 'T',  ///< Tab page label nr.
  STL_TABCLOSENR      = 'X',  ///< Tab page close nr.
  STL_CLICK_FUNC      = '@',  ///< Click region start.
} StlFlag;

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
  char *start;             ///< Where the item starts in the status line output buffer
  int userhl;              ///< 0: no HL, 1-9: User HL, < 0 for syn ID
  StlFlag item;            ///< Item flag belonging to highlight (used for 'statuscolumn')
};

/// Used for building the status line.
typedef struct stl_item stl_item_t;
struct stl_item {
  char *start;             ///< Where the item starts in the status line output buffer
  char *cmd;               ///< Function to run for ClickFunc items
  int minwid;              ///< The minimum width of the item
  int maxwid;              ///< The maximum width of the item
  enum {
    Normal,
    Empty,
    Group,
    Separate,
    Highlight,
    HighlightSign,
    HighlightFold,
    TabPage,
    ClickFunc,
    Trunc,
  } type;
};

/// Struct to hold info for 'statuscolumn'
typedef struct {
  int width;                           ///< width of the status column
  int sign_cul_id;                     ///< cursorline sign highlight id
  bool draw;                           ///< whether to draw the statuscolumn
  stl_hlrec_t *hlrec;                  ///< highlight groups
  foldinfo_T foldinfo;                 ///< fold information
  colnr_T fold_vcol[9];                ///< vcol array filled for fold item
  SignTextAttrs *sattrs;               ///< sign attributes
} statuscol_T;
