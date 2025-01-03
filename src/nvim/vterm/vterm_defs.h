#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/types_defs.h"

typedef struct VTerm VTerm;
typedef struct VTermState VTermState;
typedef struct VTermScreen VTermScreen;

typedef struct {
  int row;
  int col;
} VTermPos;

// some small utility functions; we can just keep these static here

typedef struct {
  int start_row;
  int end_row;
  int start_col;
  int end_col;
} VTermRect;

// Tagged union storing either an RGB color or an index into a colour palette. In order to convert
// indexed colours to RGB, you may use the vterm_state_convert_color_to_rgb() or
// vterm_screen_convert_color_to_rgb() functions which lookup the RGB colour from the palette
// maintained by a VTermState or VTermScreen instance.
typedef union {
  // Tag indicating which union member is actually valid. This variable coincides with the `type`
  // member of the `rgb` and the `indexed` struct in memory. Please use the `VTERM_COLOR_IS_*` test
  // macros to check whether a particular type flag is set.
  uint8_t type;

  // Valid if `VTERM_COLOR_IS_RGB(type)` is true. Holds the RGB colour values.
  struct {
    // Same as the top-level `type` member stored in VTermColor.
    uint8_t type;

    // The actual 8-bit red, green, blue colour values.
    uint8_t red, green, blue;
  } rgb;

  // If `VTERM_COLOR_IS_INDEXED(type)` is true, this member holds the index into the colour palette.
  struct {
    // Same as the top-level `type` member stored in VTermColor.
    uint8_t type;

    // Index into the colour map.
    uint8_t idx;
  } indexed;
} VTermColor;

typedef struct {
  unsigned bold      : 1;
  unsigned underline : 2;
  unsigned italic    : 1;
  unsigned blink     : 1;
  unsigned reverse   : 1;
  unsigned conceal   : 1;
  unsigned strike    : 1;
  unsigned font      : 4;  // 0 to 9
  unsigned dwl       : 1;  // On a DECDWL or DECDHL line
  unsigned dhl       : 2;  // On a DECDHL line (1=top 2=bottom)
  unsigned small     : 1;
  unsigned baseline  : 2;
} VTermScreenCellAttrs;

typedef struct {
  schar_T schar;
  char width;
  VTermScreenCellAttrs attrs;
  VTermColor fg, bg;
  int uri;
} VTermScreenCell;

typedef enum {
  // VTERM_PROP_NONE = 0
  VTERM_PROP_CURSORVISIBLE = 1,  // bool
  VTERM_PROP_CURSORBLINK,       // bool
  VTERM_PROP_ALTSCREEN,         // bool
  VTERM_PROP_TITLE,             // string
  VTERM_PROP_ICONNAME,          // string
  VTERM_PROP_REVERSE,           // bool
  VTERM_PROP_CURSORSHAPE,       // number
  VTERM_PROP_MOUSE,             // number
  VTERM_PROP_FOCUSREPORT,       // bool

  VTERM_N_PROPS,
} VTermProp;

typedef struct {
  const char *str;
  size_t len : 30;
  bool initial : 1;
  bool final : 1;
} VTermStringFragment;

typedef union {
  int boolean;
  int number;
  VTermStringFragment string;
  VTermColor color;
} VTermValue;

typedef struct {
  int (*damage)(VTermRect rect, void *user);
  int (*moverect)(VTermRect dest, VTermRect src, void *user);
  int (*movecursor)(VTermPos pos, VTermPos oldpos, int visible, void *user);
  int (*settermprop)(VTermProp prop, VTermValue *val, void *user);
  int (*bell)(void *user);
  int (*resize)(int rows, int cols, void *user);
  int (*sb_pushline)(int cols, const VTermScreenCell *cells, void *user);
  int (*sb_popline)(int cols, VTermScreenCell *cells, void *user);
  int (*sb_clear)(void *user);
} VTermScreenCallbacks;

typedef struct {
  int (*control)(uint8_t control, void *user);
  int (*csi)(const char *leader, const long args[], int argcount, const char *intermed,
             char command, void *user);
  int (*osc)(int command, VTermStringFragment frag, void *user);
  int (*dcs)(const char *command, size_t commandlen, VTermStringFragment frag, void *user);
  int (*apc)(VTermStringFragment frag, void *user);
  int (*pm)(VTermStringFragment frag, void *user);
  int (*sos)(VTermStringFragment frag, void *user);
} VTermStateFallbacks;

typedef enum {
  VTERM_DAMAGE_CELL,    // every cell
  VTERM_DAMAGE_ROW,     // entire rows
  VTERM_DAMAGE_SCREEN,  // entire screen
  VTERM_DAMAGE_SCROLL,  // entire screen + scrollrect

  VTERM_N_DAMAGES,
} VTermDamageSize;

typedef enum {
  VTERM_ATTR_BOLD_MASK       = 1 << 0,
  VTERM_ATTR_UNDERLINE_MASK  = 1 << 1,
  VTERM_ATTR_ITALIC_MASK     = 1 << 2,
  VTERM_ATTR_BLINK_MASK      = 1 << 3,
  VTERM_ATTR_REVERSE_MASK    = 1 << 4,
  VTERM_ATTR_STRIKE_MASK     = 1 << 5,
  VTERM_ATTR_FONT_MASK       = 1 << 6,
  VTERM_ATTR_FOREGROUND_MASK = 1 << 7,
  VTERM_ATTR_BACKGROUND_MASK = 1 << 8,
  VTERM_ATTR_CONCEAL_MASK    = 1 << 9,
  VTERM_ATTR_SMALL_MASK      = 1 << 10,
  VTERM_ATTR_BASELINE_MASK   = 1 << 11,
  VTERM_ATTR_URI_MASK        = 1 << 12,

  VTERM_ALL_ATTRS_MASK = (1 << 13) - 1,
} VTermAttrMask;

typedef enum {
  // VTERM_VALUETYPE_NONE = 0
  VTERM_VALUETYPE_BOOL = 1,
  VTERM_VALUETYPE_INT,
  VTERM_VALUETYPE_STRING,
  VTERM_VALUETYPE_COLOR,

  VTERM_N_VALUETYPES,
} VTermValueType;

typedef enum {
  // VTERM_ATTR_NONE = 0
  VTERM_ATTR_BOLD = 1,   // bool:   1, 22
  VTERM_ATTR_UNDERLINE,  // number: 4, 21, 24
  VTERM_ATTR_ITALIC,     // bool:   3, 23
  VTERM_ATTR_BLINK,      // bool:   5, 25
  VTERM_ATTR_REVERSE,    // bool:   7, 27
  VTERM_ATTR_CONCEAL,    // bool:   8, 28
  VTERM_ATTR_STRIKE,     // bool:   9, 29
  VTERM_ATTR_FONT,       // number: 10-19
  VTERM_ATTR_FOREGROUND,  // color:  30-39 90-97
  VTERM_ATTR_BACKGROUND,  // color:  40-49 100-107
  VTERM_ATTR_SMALL,      // bool:   73, 74, 75
  VTERM_ATTR_BASELINE,   // number: 73, 74, 75
  VTERM_ATTR_URI,        // number

  VTERM_N_ATTRS,
} VTermAttr;

enum {
  VTERM_PROP_CURSORSHAPE_BLOCK = 1,
  VTERM_PROP_CURSORSHAPE_UNDERLINE,
  VTERM_PROP_CURSORSHAPE_BAR_LEFT,

  VTERM_N_PROP_CURSORSHAPES,
};

enum {
  VTERM_PROP_MOUSE_NONE = 0,
  VTERM_PROP_MOUSE_CLICK,
  VTERM_PROP_MOUSE_DRAG,
  VTERM_PROP_MOUSE_MOVE,

  VTERM_N_PROP_MOUSES,
};

typedef enum {
  VTERM_SELECTION_CLIPBOARD = (1<<0),
  VTERM_SELECTION_PRIMARY   = (1<<1),
  VTERM_SELECTION_SECONDARY = (1<<2),
  VTERM_SELECTION_SELECT    = (1<<3),
  VTERM_SELECTION_CUT0      = (1<<4),  // also CUT1 .. CUT7 by bitshifting
} VTermSelectionMask;

typedef struct {
  schar_T schar;
  int width;
  unsigned protected_cell:1;  // DECSCA-protected against DECSEL/DECSED
  unsigned dwl:1;             // DECDWL or DECDHL double-width line
  unsigned dhl:2;             // DECDHL double-height line (1=top 2=bottom)
} VTermGlyphInfo;

typedef struct {
  unsigned doublewidth:1;     // DECDWL or DECDHL line
  unsigned doubleheight:2;    // DECDHL line (1=top 2=bottom)
  unsigned continuation:1;    // Line is a flow continuation of the previous
} VTermLineInfo;

// Copies of VTermState fields that the 'resize' callback might have reason to edit. 'resize'
// callback gets total control of these fields and may free-and-reallocate them if required. They
// will be copied back from the struct after the callback has returned.
typedef struct {
  VTermPos pos;                // current cursor position
  VTermLineInfo *lineinfos[2];  // [1] may be NULL
} VTermStateFields;

typedef struct {
  // libvterm relies on this memory to be zeroed out before it is returned by the allocator.
  void *(*malloc)(size_t size, void *allocdata);
  void (*free)(void *ptr, void *allocdata);
} VTermAllocatorFunctions;

// Setting output callback will override the buffer logic
typedef void VTermOutputCallback(const char *s, size_t len, void *user);

struct VTermBuilder {
  int ver;  // currently unused but reserved for some sort of ABI version flag

  int rows, cols;

  const VTermAllocatorFunctions *allocator;
  void *allocdata;

  // Override default sizes for various structures
  size_t outbuffer_len;  // default: 4096
  size_t tmpbuffer_len;  // default: 4096
};

typedef struct {
  int (*putglyph)(VTermGlyphInfo *info, VTermPos pos, void *user);
  int (*movecursor)(VTermPos pos, VTermPos oldpos, int visible, void *user);
  int (*scrollrect)(VTermRect rect, int downward, int rightward, void *user);
  int (*moverect)(VTermRect dest, VTermRect src, void *user);
  int (*erase)(VTermRect rect, int selective, void *user);
  int (*initpen)(void *user);
  int (*setpenattr)(VTermAttr attr, VTermValue *val, void *user);
  int (*settermprop)(VTermProp prop, VTermValue *val, void *user);
  int (*bell)(void *user);
  int (*resize)(int rows, int cols, VTermStateFields *fields, void *user);
  int (*setlineinfo)(int row, const VTermLineInfo *newinfo, const VTermLineInfo *oldinfo,
                     void *user);
  int (*sb_clear)(void *user);
} VTermStateCallbacks;

typedef struct {
  int (*set)(VTermSelectionMask mask, VTermStringFragment frag, void *user);
  int (*query)(VTermSelectionMask mask, void *user);
} VTermSelectionCallbacks;

typedef struct {
  int (*text)(const char *bytes, size_t len, void *user);
  int (*control)(uint8_t control, void *user);
  int (*escape)(const char *bytes, size_t len, void *user);
  int (*csi)(const char *leader, const long args[], int argcount, const char *intermed,
             char command, void *user);
  int (*osc)(int command, VTermStringFragment frag, void *user);
  int (*dcs)(const char *command, size_t commandlen, VTermStringFragment frag, void *user);
  int (*apc)(VTermStringFragment frag, void *user);
  int (*pm)(VTermStringFragment frag, void *user);
  int (*sos)(VTermStringFragment frag, void *user);
  int (*resize)(int rows, int cols, void *user);
} VTermParserCallbacks;

// State of the pen at some moment in time, also used in a cell
typedef struct {
  // After the bitfield
  VTermColor fg, bg;

  // Opaque ID that maps to a URI in a set
  int uri;

  unsigned bold      : 1;
  unsigned underline : 2;
  unsigned italic    : 1;
  unsigned blink     : 1;
  unsigned reverse   : 1;
  unsigned conceal   : 1;
  unsigned strike    : 1;
  unsigned font      : 4;  // 0 to 9
  unsigned small     : 1;
  unsigned baseline  : 2;

  // Extra state storage that isn't strictly pen-related
  unsigned protected_cell : 1;
  unsigned dwl            : 1;  // on a DECDWL or DECDHL line
  unsigned dhl            : 2;  // on a DECDHL line (1=top 2=bottom)
} ScreenPen;

// Internal representation of a screen cell
typedef struct {
  schar_T schar;
  ScreenPen pen;
} ScreenCell;
