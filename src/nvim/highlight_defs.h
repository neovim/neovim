#ifndef NVIM_HIGHLIGHT_DEFS_H
#define NVIM_HIGHLIGHT_DEFS_H

#include <inttypes.h>

#include "nvim/macros.h"
#include "nvim/types.h"

typedef int32_t RgbValue;

/// Highlighting attribute bits.
///
/// sign bit should not be used here, as it identifies invalid highlight
typedef enum {
  HL_INVERSE         = 0x01,
  HL_BOLD            = 0x02,
  HL_ITALIC          = 0x04,
  // The next three bits are all underline styles
  HL_UNDERLINE_MASK  = 0x38,
  HL_UNDERLINE       = 0x08,
  HL_UNDERCURL       = 0x10,
  HL_UNDERDOUBLE     = 0x18,
  HL_UNDERDOTTED     = 0x20,
  HL_UNDERDASHED     = 0x28,
  // 0x30 and 0x38 spare for underline styles
  HL_STANDOUT      = 0x0040,
  HL_STRIKETHROUGH = 0x0080,
  HL_ALTFONT       = 0x0100,
  // 0x0200 spare
  HL_NOCOMBINE     = 0x0400,
  HL_BG_INDEXED    = 0x0800,
  HL_FG_INDEXED    = 0x1000,
  HL_DEFAULT       = 0x2000,
  HL_GLOBAL        = 0x4000,
} HlAttrFlags;

/// Stores a complete highlighting entry, including colors and attributes
/// for both TUI and GUI.
typedef struct attr_entry {
  int16_t rgb_ae_attr, cterm_ae_attr;  ///< HlAttrFlags
  RgbValue rgb_fg_color, rgb_bg_color, rgb_sp_color;
  int cterm_fg_color, cterm_bg_color;
  int hl_blend;
} HlAttrs;

#define HLATTRS_INIT (HlAttrs) { \
  .rgb_ae_attr = 0, \
  .cterm_ae_attr = 0, \
  .rgb_fg_color = -1, \
  .rgb_bg_color = -1, \
  .rgb_sp_color = -1, \
  .cterm_fg_color = 0, \
  .cterm_bg_color = 0, \
  .hl_blend = -1, \
}

/// Values for index in highlight_attr[].
/// When making changes, also update hlf_names below!
typedef enum {
  HLF_8 = 0,        // Meta & special keys listed with ":map", text that is
                    // displayed different from what it is
  HLF_EOB,        // after the last line in the buffer
  HLF_TERM,       // terminal cursor focused
  HLF_TERMNC,     // terminal cursor unfocused
  HLF_AT,          // @ characters at end of screen, characters that don't really exist in the text
  HLF_D,          // directories in CTRL-D listing
  HLF_E,          // error messages
  HLF_I,          // incremental search
  HLF_L,          // last search string
  HLF_LC,         // current search match
  HLF_M,          // "--More--" message
  HLF_CM,         // Mode (e.g., "-- INSERT --")
  HLF_N,          // line number for ":number" and ":#" commands
  HLF_LNA,        // LineNrAbove
  HLF_LNB,        // LineNrBelow
  HLF_CLN,        // current line number when 'cursorline' is set
  HLF_CLS,        // current line sign column
  HLF_CLF,        // current line fold
  HLF_R,          // return to continue message and yes/no questions
  HLF_S,          // status lines
  HLF_SNC,        // status lines of not-current windows
  HLF_C,          // window split separators
  HLF_VSP,        // VertSplit
  HLF_T,          // Titles for output from ":set all", ":autocmd" etc.
  HLF_V,          // Visual mode
  HLF_VNC,        // Visual mode, autoselecting and not clipboard owner
  HLF_W,          // warning messages
  HLF_WM,         // Wildmenu highlight
  HLF_FL,         // Folded line
  HLF_FC,         // Fold column
  HLF_ADD,        // Added diff line
  HLF_CHD,        // Changed diff line
  HLF_DED,        // Deleted diff line
  HLF_TXD,        // Text Changed in diff line
  HLF_SC,         // Sign column
  HLF_CONCEAL,    // Concealed text
  HLF_SPB,        // SpellBad
  HLF_SPC,        // SpellCap
  HLF_SPR,        // SpellRare
  HLF_SPL,        // SpellLocal
  HLF_PNI,        // popup menu normal item
  HLF_PSI,        // popup menu selected item
  HLF_PNK,        // popup menu normal item "kind"
  HLF_PSK,        // popup menu selected item "kind"
  HLF_PNX,        // popup menu normal item "menu" (extra text)
  HLF_PSX,        // popup menu selected item "menu" (extra text)
  HLF_PSB,        // popup menu scrollbar
  HLF_PST,        // popup menu scrollbar thumb
  HLF_TP,         // tabpage line
  HLF_TPS,        // tabpage line selected
  HLF_TPF,        // tabpage line filler
  HLF_CUC,        // 'cursorcolumn'
  HLF_CUL,        // 'cursorline'
  HLF_MC,         // 'colorcolumn'
  HLF_QFL,        // selected quickfix line
  HLF_0,          // Whitespace
  HLF_INACTIVE,   // NormalNC: Normal text in non-current windows
  HLF_MSGSEP,     // message separator line
  HLF_NFLOAT,     // Floating window
  HLF_MSG,        // Message area
  HLF_BORDER,     // Floating window border
  HLF_WBR,        // Window bars
  HLF_WBRNC,      // Window bars of not-current windows
  HLF_CU,         // Cursor
  HLF_BTITLE,     // Float Border Title
  HLF_COUNT,      // MUST be the last one
} hlf_T;

EXTERN const char *hlf_names[] INIT(= {
  [HLF_8] = "SpecialKey",
  [HLF_EOB] = "EndOfBuffer",
  [HLF_TERM] = "TermCursor",
  [HLF_TERMNC] = "TermCursorNC",
  [HLF_AT] = "NonText",
  [HLF_D] = "Directory",
  [HLF_E] = "ErrorMsg",
  [HLF_I] = "IncSearch",
  [HLF_L] = "Search",
  [HLF_LC] = "CurSearch",
  [HLF_M] = "MoreMsg",
  [HLF_CM] = "ModeMsg",
  [HLF_N] = "LineNr",
  [HLF_LNA] = "LineNrAbove",
  [HLF_LNB] = "LineNrBelow",
  [HLF_CLN] = "CursorLineNr",
  [HLF_CLS] = "CursorLineSign",
  [HLF_CLF] = "CursorLineFold",
  [HLF_R] = "Question",
  [HLF_S] = "StatusLine",
  [HLF_SNC] = "StatusLineNC",
  [HLF_C] = "WinSeparator",
  [HLF_T] = "Title",
  [HLF_V] = "Visual",
  [HLF_VNC] = "VisualNC",
  [HLF_VSP] = "VertSplit",
  [HLF_W] = "WarningMsg",
  [HLF_WM] = "WildMenu",
  [HLF_FL] = "Folded",
  [HLF_FC] = "FoldColumn",
  [HLF_ADD] = "DiffAdd",
  [HLF_CHD] = "DiffChange",
  [HLF_DED] = "DiffDelete",
  [HLF_TXD] = "DiffText",
  [HLF_SC] = "SignColumn",
  [HLF_CONCEAL] = "Conceal",
  [HLF_SPB] = "SpellBad",
  [HLF_SPC] = "SpellCap",
  [HLF_SPR] = "SpellRare",
  [HLF_SPL] = "SpellLocal",
  [HLF_PNI] = "Pmenu",
  [HLF_PSI] = "PmenuSel",
  [HLF_PNK] = "PmenuKind",
  [HLF_PSK] = "PmenuKindSel",
  [HLF_PNX] = "PmenuExtra",
  [HLF_PSX] = "PmenuExtraSel",
  [HLF_PSB] = "PmenuSbar",
  [HLF_PST] = "PmenuThumb",
  [HLF_TP] = "TabLine",
  [HLF_TPS] = "TabLineSel",
  [HLF_TPF] = "TabLineFill",
  [HLF_CUC] = "CursorColumn",
  [HLF_CUL] = "CursorLine",
  [HLF_MC] = "ColorColumn",
  [HLF_QFL] = "QuickFixLine",
  [HLF_0] = "Whitespace",
  [HLF_INACTIVE] = "NormalNC",
  [HLF_MSGSEP] = "MsgSeparator",
  [HLF_NFLOAT] = "NormalFloat",
  [HLF_MSG] = "MsgArea",
  [HLF_BORDER] = "FloatBorder",
  [HLF_WBR] = "WinBar",
  [HLF_WBRNC] = "WinBarNC",
  [HLF_CU] = "Cursor",
  [HLF_BTITLE] = "FloatTitle",
});

EXTERN int highlight_attr[HLF_COUNT + 1];     // Highl. attr for each context.
EXTERN int highlight_attr_last[HLF_COUNT];  // copy for detecting changed groups
EXTERN int highlight_user[9];                   // User[1-9] attributes
EXTERN int highlight_stlnc[9];                  // On top of user
EXTERN int cterm_normal_fg_color INIT(= 0);
EXTERN int cterm_normal_bg_color INIT(= 0);
EXTERN RgbValue normal_fg INIT(= -1);
EXTERN RgbValue normal_bg INIT(= -1);
EXTERN RgbValue normal_sp INIT(= -1);

EXTERN NS ns_hl_global INIT(= 0);  // global highlight namespace
EXTERN NS ns_hl_win INIT(= -1);    // highlight namespace for the current window
EXTERN NS ns_hl_fast INIT(= -1);   // highlight namespace specified in a fast callback
EXTERN NS ns_hl_active INIT(= 0);  // currently active/cached namespace

EXTERN int *hl_attr_active INIT(= highlight_attr);

typedef enum {
  kHlUnknown,
  kHlUI,
  kHlSyntax,
  kHlTerminal,
  kHlCombine,
  kHlBlend,
  kHlBlendThrough,
} HlKind;

typedef struct {
  HlAttrs attr;
  HlKind kind;
  int id1;
  int id2;
  int winid;
} HlEntry;

typedef struct {
  int ns_id;
  int syn_id;
} ColorKey;
#define ColorKey(n, s) (ColorKey) { .ns_id = (int)(n), .syn_id = (s) }

typedef struct {
  int attr_id;
  int link_id;
  int version;
  bool is_default;
  bool link_global;
} ColorItem;
#define COLOR_ITEM_INITIALIZER { .attr_id = -1, .link_id = -1, .version = -1, \
                                 .is_default = false, .link_global = false }

/// highlight attributes with associated priorities
typedef struct {
  int hl_id;
  int priority;
} HlPriId;

#endif  // NVIM_HIGHLIGHT_DEFS_H
