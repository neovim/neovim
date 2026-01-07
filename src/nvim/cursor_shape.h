#pragma once

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/memory_defs.h"  // IWYU pragma: keep

/// struct to store values from 'guicursor' and 'mouseshape'
/// Indexes in shape_table[]
typedef enum {
  SHAPE_IDX_N      = 0,       ///< Normal mode
  SHAPE_IDX_V      = 1,       ///< Visual mode
  SHAPE_IDX_I      = 2,       ///< Insert mode
  SHAPE_IDX_R      = 3,       ///< Replace mode
  SHAPE_IDX_C      = 4,       ///< Command line Normal mode
  SHAPE_IDX_CI     = 5,       ///< Command line Insert mode
  SHAPE_IDX_CR     = 6,       ///< Command line Replace mode
  SHAPE_IDX_O      = 7,       ///< Operator-pending mode
  SHAPE_IDX_VE     = 8,       ///< Visual mode with 'selection' exclusive
  SHAPE_IDX_CLINE  = 9,       ///< On command line
  SHAPE_IDX_STATUS = 10,      ///< On status line
  SHAPE_IDX_SDRAG  = 11,      ///< dragging a status line
  SHAPE_IDX_VSEP   = 12,      ///< On vertical separator line
  SHAPE_IDX_VDRAG  = 13,      ///< dragging a vertical separator line
  SHAPE_IDX_MORE   = 14,      ///< Hit-return or More
  SHAPE_IDX_MOREL  = 15,      ///< Hit-return or More in last line
  SHAPE_IDX_SM     = 16,      ///< showing matching paren
  SHAPE_IDX_TERM   = 17,      ///< Terminal mode
  SHAPE_IDX_COUNT  = 18,
} ModeShape;

typedef enum {
  SHAPE_BLOCK     = 0,       ///< block cursor
  SHAPE_HOR       = 1,       ///< horizontal bar cursor
  SHAPE_VER       = 2,  ///< vertical bar cursor
} CursorShape;

// Kitty mouse pointer shape names (OSC 22)
// https://sw.kovidgoyal.net/kitty/pointer-shapes/
#define MSHAPE_ALIAS          "alias"
#define MSHAPE_CELL           "cell"
#define MSHAPE_COPY           "copy"
#define MSHAPE_CROSSHAIR      "crosshair"
#define MSHAPE_DEFAULT        "default"
#define MSHAPE_E_RESIZE       "e-resize"
#define MSHAPE_EW_RESIZE      "ew-resize"
#define MSHAPE_GRAB           "grab"
#define MSHAPE_GRABBING       "grabbing"
#define MSHAPE_HELP           "help"
#define MSHAPE_MOVE           "move"
#define MSHAPE_N_RESIZE       "n-resize"
#define MSHAPE_NE_RESIZE      "ne-resize"
#define MSHAPE_NESW_RESIZE    "nesw-resize"
#define MSHAPE_NO_DROP        "no-drop"
#define MSHAPE_NOT_ALLOWED    "not-allowed"
#define MSHAPE_NS_RESIZE      "ns-resize"
#define MSHAPE_NW_RESIZE      "nw-resize"
#define MSHAPE_NWSE_RESIZE    "nwse-resize"
#define MSHAPE_POINTER        "pointer"
#define MSHAPE_PROGRESS       "progress"
#define MSHAPE_S_RESIZE       "s-resize"
#define MSHAPE_SE_RESIZE      "se-resize"
#define MSHAPE_SW_RESIZE      "sw-resize"
#define MSHAPE_TEXT           "text"
#define MSHAPE_VERTICAL_TEXT  "vertical-text"
#define MSHAPE_W_RESIZE       "w-resize"
#define MSHAPE_WAIT           "wait"
#define MSHAPE_ZOOM_IN        "zoom-in"
#define MSHAPE_ZOOM_OUT       "zoom-out"

#define SHAPE_MOUSE     1       // used for mouse pointer shape
#define SHAPE_CURSOR    2       // used for text cursor shape

typedef struct {
  char *full_name;        ///< mode description
  CursorShape shape;      ///< cursor shape: one of the SHAPE_ defines
  char *mshape;           ///< mouse shape: one of the MSHAPE defines
  int percentage;         ///< percentage of cell for bar
  int blinkwait;          ///< blinking, wait time before blinking starts
  int blinkon;            ///< blinking, on time
  int blinkoff;           ///< blinking, off time
  int id;                 ///< highlight group ID
  int id_lm;              ///< highlight group ID for :lmap mode
  char *name;             ///< mode short name
  char used_for;          ///< SHAPE_MOUSE and/or SHAPE_CURSOR
} cursorentry_T;

extern cursorentry_T shape_table[SHAPE_IDX_COUNT];

#include "cursor_shape.h.generated.h"
