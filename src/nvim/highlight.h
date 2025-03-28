#pragma once

#include <stdbool.h>

#include "nvim/api/keysets_defs.h"  // IWYU pragma: keep
#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/buffer_defs.h"
#include "nvim/highlight_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/option_vars.h"
#include "nvim/types_defs.h"
#include "nvim/ui_defs.h"  // IWYU pragma: keep

EXTERN const char *hlf_names[] INIT( = {
  [HLF_8] = "SpecialKey",
  [HLF_EOB] = "EndOfBuffer",
  [HLF_TERM] = "TermCursor",
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
  [HLF_TXA] = "DiffTextAdd",
  [HLF_SC] = "SignColumn",
  [HLF_CONCEAL] = "Conceal",
  [HLF_SPB] = "SpellBad",
  [HLF_SPC] = "SpellCap",
  [HLF_SPR] = "SpellRare",
  [HLF_SPL] = "SpellLocal",
  [HLF_PNI] = "Pmenu",
  [HLF_PSI] = "PmenuSel",
  [HLF_PMNI] = "PmenuMatch",
  [HLF_PMSI] = "PmenuMatchSel",
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
  [HLF_BFOOTER] = "FloatFooter",
  [HLF_TS] = "StatusLineTerm",
  [HLF_TSNC] = "StatusLineTermNC",
});

EXTERN int highlight_attr[HLF_COUNT];     // Highl. attr for each context.
EXTERN int highlight_attr_last[HLF_COUNT];  // copy for detecting changed groups
EXTERN int highlight_user[9];                   // User[1-9] attributes
EXTERN int highlight_stlnc[9];                  // On top of user
EXTERN int cterm_normal_fg_color INIT( = 0);
EXTERN int cterm_normal_bg_color INIT( = 0);
EXTERN RgbValue normal_fg INIT( = -1);
EXTERN RgbValue normal_bg INIT( = -1);
EXTERN RgbValue normal_sp INIT( = -1);

EXTERN NS ns_hl_global INIT( = 0);  // global highlight namespace
EXTERN NS ns_hl_win INIT( = -1);    // highlight namespace for the current window
EXTERN NS ns_hl_fast INIT( = -1);   // highlight namespace specified in a fast callback
EXTERN NS ns_hl_active INIT( = 0);  // currently active/cached namespace

EXTERN int *hl_attr_active INIT( = highlight_attr);

// Enums need a typecast to be used as array index.
#define HL_ATTR(n)      hl_attr_active[(int)(n)]

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "highlight.h.generated.h"
#endif

static inline int win_hl_attr(win_T *wp, int hlf)
{
  // wp->w_ns_hl_attr might be null if we check highlights
  // prior to entering redraw
  return ((wp->w_ns_hl_attr && ns_hl_fast < 0) ? wp->w_ns_hl_attr : hl_attr_active)[hlf];
}

#define HL_SET_DEFAULT_COLORS(rgb_fg, rgb_bg, rgb_sp) \
  do { \
    bool dark_ = (*p_bg == 'd'); \
    rgb_fg = rgb_fg != -1 ? rgb_fg : (dark_ ? 0xFFFFFF : 0x000000); \
    rgb_bg = rgb_bg != -1 ? rgb_bg : (dark_ ? 0x000000 : 0xFFFFFF); \
    rgb_sp = rgb_sp != -1 ? rgb_sp : 0xFF0000; \
  } while (0);
