// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// highlight_group.c: code for managing highlight groups

#include <stdbool.h>

#include "nvim/api/private/helpers.h"
#include "nvim/autocmd.h"
#include "nvim/charset.h"
#include "nvim/cursor_shape.h"
#include "nvim/fold.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/lua/executor.h"
#include "nvim/match.h"
#include "nvim/option.h"
#include "nvim/runtime.h"
#include "nvim/screen.h"

/// \addtogroup SG_SET
/// @{
#define SG_CTERM        2       // cterm has been set
#define SG_GUI          4       // gui has been set
#define SG_LINK         8       // link has been set
/// @}

#define MAX_SYN_NAME 200

// builtin |highlight-groups|
static garray_T highlight_ga = GA_EMPTY_INIT_VALUE;

Map(cstr_t, int) highlight_unames = MAP_INIT;

/// The "term", "cterm" and "gui" arguments can be any combination of the
/// following names, separated by commas (but no spaces!).
static char *(hl_name_table[]) =
{ "bold", "standout", "underline", "underlineline", "undercurl", "underdot",
  "underdash", "italic", "reverse", "inverse", "strikethrough", "nocombine", "NONE" };
static int hl_attr_table[] =
{ HL_BOLD, HL_STANDOUT, HL_UNDERLINE, HL_UNDERLINELINE, HL_UNDERCURL, HL_UNDERDOT, HL_UNDERDASH,
  HL_ITALIC, HL_INVERSE, HL_INVERSE, HL_STRIKETHROUGH, HL_NOCOMBINE, 0 };

/// Structure that stores information about a highlight group.
/// The ID of a highlight group is also called group ID.  It is the index in
/// the highlight_ga array PLUS ONE.
typedef struct {
  char_u *sg_name;         ///< highlight group name
  char *sg_name_u;       ///< uppercase of sg_name
  bool sg_cleared;              ///< "hi clear" was used
  int sg_attr;                  ///< Screen attr @see ATTR_ENTRY
  int sg_link;                  ///< link to this highlight group ID
  int sg_deflink;               ///< default link; restored in highlight_clear()
  int sg_set;                   ///< combination of flags in \ref SG_SET
  sctx_T sg_deflink_sctx;       ///< script where the default link was set
  sctx_T sg_script_ctx;         ///< script in which the group was last set
  // for terminal UIs
  int sg_cterm;                 ///< "cterm=" highlighting attr
                                ///< (combination of \ref HlAttrFlags)
  int sg_cterm_fg;              ///< terminal fg color number + 1
  int sg_cterm_bg;              ///< terminal bg color number + 1
  bool sg_cterm_bold;           ///< bold attr was set for light color
  // for RGB UIs
  int sg_gui;                   ///< "gui=" highlighting attributes
                                ///< (combination of \ref HlAttrFlags)
  RgbValue sg_rgb_fg;           ///< RGB foreground color
  RgbValue sg_rgb_bg;           ///< RGB background color
  RgbValue sg_rgb_sp;           ///< RGB special color
  char *sg_rgb_fg_name;         ///< RGB foreground color name
  char *sg_rgb_bg_name;         ///< RGB background color name
  char *sg_rgb_sp_name;         ///< RGB special color name

  int sg_blend;                 ///< blend level (0-100 inclusive), -1 if unset
} HlGroup;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "highlight_group.c.generated.h"
#endif

static inline HlGroup *HL_TABLE(void)
{
  return ((HlGroup *)((highlight_ga.ga_data)));
}

// The default highlight groups.  These are compiled-in for fast startup and
// they still work when the runtime files can't be found.
//
// When making changes here, also change runtime/colors/default.vim!

static const char *highlight_init_both[] = {
  "Conceal      ctermbg=DarkGrey ctermfg=LightGrey guibg=DarkGrey guifg=LightGrey",
  "Cursor       guibg=fg guifg=bg",
  "lCursor      guibg=fg guifg=bg",
  "DiffText     cterm=bold ctermbg=Red gui=bold guibg=Red",
  "ErrorMsg     ctermbg=DarkRed ctermfg=White guibg=Red guifg=White",
  "IncSearch    cterm=reverse gui=reverse",
  "ModeMsg      cterm=bold gui=bold",
  "NonText      ctermfg=Blue gui=bold guifg=Blue",
  "Normal       cterm=NONE gui=NONE",
  "PmenuSbar    ctermbg=Grey guibg=Grey",
  "StatusLine   cterm=reverse,bold gui=reverse,bold",
  "StatusLineNC cterm=reverse gui=reverse",
  "TabLineFill  cterm=reverse gui=reverse",
  "TabLineSel   cterm=bold gui=bold",
  "TermCursor   cterm=reverse gui=reverse",
  "WinBar       cterm=bold gui=bold",
  "WildMenu     ctermbg=Yellow ctermfg=Black guibg=Yellow guifg=Black",
  "default link VertSplit Normal",
  "default link WinSeparator VertSplit",
  "default link WinBarNC WinBar",
  "default link EndOfBuffer NonText",
  "default link LineNrAbove LineNr",
  "default link LineNrBelow LineNr",
  "default link QuickFixLine Search",
  "default link CursorLineSign SignColumn",
  "default link CursorLineFold FoldColumn",
  "default link Substitute Search",
  "default link Whitespace NonText",
  "default link MsgSeparator StatusLine",
  "default link NormalFloat Pmenu",
  "default link FloatBorder WinSeparator",
  "default FloatShadow blend=80 guibg=Black",
  "default FloatShadowThrough blend=100 guibg=Black",
  "RedrawDebugNormal cterm=reverse gui=reverse",
  "RedrawDebugClear ctermbg=Yellow guibg=Yellow",
  "RedrawDebugComposed ctermbg=Green guibg=Green",
  "RedrawDebugRecompose ctermbg=Red guibg=Red",
  "Error term=reverse cterm=NONE ctermfg=White ctermbg=Red gui=NONE guifg=White guibg=Red",
  "Todo term=standout cterm=NONE ctermfg=Black ctermbg=Yellow gui=NONE guifg=Blue guibg=Yellow",
  "default link String Constant",
  "default link Character Constant",
  "default link Number Constant",
  "default link Boolean Constant",
  "default link Float Number",
  "default link Function Identifier",
  "default link Conditional Statement",
  "default link Repeat Statement",
  "default link Label Statement",
  "default link Operator Statement",
  "default link Keyword Statement",
  "default link Exception Statement",
  "default link Include PreProc",
  "default link Define PreProc",
  "default link Macro PreProc",
  "default link PreCondit PreProc",
  "default link StorageClass Type",
  "default link Structure Type",
  "default link Typedef Type",
  "default link Tag Special",
  "default link SpecialChar Special",
  "default link Delimiter Special",
  "default link SpecialComment Special",
  "default link Debug Special",
  "default DiagnosticError ctermfg=1 guifg=Red",
  "default DiagnosticWarn ctermfg=3 guifg=Orange",
  "default DiagnosticInfo ctermfg=4 guifg=LightBlue",
  "default DiagnosticHint ctermfg=7 guifg=LightGrey",
  "default DiagnosticUnderlineError cterm=underline gui=underline guisp=Red",
  "default DiagnosticUnderlineWarn cterm=underline gui=underline guisp=Orange",
  "default DiagnosticUnderlineInfo cterm=underline gui=underline guisp=LightBlue",
  "default DiagnosticUnderlineHint cterm=underline gui=underline guisp=LightGrey",
  "default link DiagnosticVirtualTextError DiagnosticError",
  "default link DiagnosticVirtualTextWarn DiagnosticWarn",
  "default link DiagnosticVirtualTextInfo DiagnosticInfo",
  "default link DiagnosticVirtualTextHint DiagnosticHint",
  "default link DiagnosticFloatingError DiagnosticError",
  "default link DiagnosticFloatingWarn DiagnosticWarn",
  "default link DiagnosticFloatingInfo DiagnosticInfo",
  "default link DiagnosticFloatingHint DiagnosticHint",
  "default link DiagnosticSignError DiagnosticError",
  "default link DiagnosticSignWarn DiagnosticWarn",
  "default link DiagnosticSignInfo DiagnosticInfo",
  "default link DiagnosticSignHint DiagnosticHint",
  NULL
};

// Default colors only used with a light background.
static const char *highlight_init_light[] = {
  "ColorColumn  ctermbg=LightRed guibg=LightRed",
  "CursorColumn ctermbg=LightGrey guibg=Grey90",
  "CursorLine   cterm=underline guibg=Grey90",
  "CursorLineNr cterm=underline ctermfg=Brown gui=bold guifg=Brown",
  "DiffAdd      ctermbg=LightBlue guibg=LightBlue",
  "DiffChange   ctermbg=LightMagenta guibg=LightMagenta",
  "DiffDelete   ctermfg=Blue ctermbg=LightCyan gui=bold guifg=Blue guibg=LightCyan",
  "Directory    ctermfg=DarkBlue guifg=Blue",
  "FoldColumn   ctermbg=Grey ctermfg=DarkBlue guibg=Grey guifg=DarkBlue",
  "Folded       ctermbg=Grey ctermfg=DarkBlue guibg=LightGrey guifg=DarkBlue",
  "LineNr       ctermfg=Brown guifg=Brown",
  "MatchParen   ctermbg=Cyan guibg=Cyan",
  "MoreMsg      ctermfg=DarkGreen gui=bold guifg=SeaGreen",
  "Pmenu        ctermbg=LightMagenta ctermfg=Black guibg=LightMagenta",
  "PmenuSel     ctermbg=LightGrey ctermfg=Black guibg=Grey",
  "PmenuThumb   ctermbg=Black guibg=Black",
  "Question     ctermfg=DarkGreen gui=bold guifg=SeaGreen",
  "Search       ctermbg=Yellow ctermfg=NONE guibg=Yellow guifg=NONE",
  "SignColumn   ctermbg=Grey ctermfg=DarkBlue guibg=Grey guifg=DarkBlue",
  "SpecialKey   ctermfg=DarkBlue guifg=Blue",
  "SpellBad     ctermbg=LightRed guisp=Red gui=undercurl",
  "SpellCap     ctermbg=LightBlue guisp=Blue gui=undercurl",
  "SpellLocal   ctermbg=Cyan guisp=DarkCyan gui=undercurl",
  "SpellRare    ctermbg=LightMagenta guisp=Magenta gui=undercurl",
  "TabLine      cterm=underline ctermfg=black ctermbg=LightGrey gui=underline guibg=LightGrey",
  "Title        ctermfg=DarkMagenta gui=bold guifg=Magenta",
  "Visual       guibg=LightGrey",
  "WarningMsg   ctermfg=DarkRed guifg=Red",
  "Comment      term=bold cterm=NONE ctermfg=DarkBlue ctermbg=NONE gui=NONE guifg=Blue guibg=NONE",
  "Constant     term=underline cterm=NONE ctermfg=DarkRed ctermbg=NONE gui=NONE guifg=Magenta guibg=NONE",
  "Special      term=bold cterm=NONE ctermfg=DarkMagenta ctermbg=NONE gui=NONE guifg=#6a5acd guibg=NONE",
  "Identifier   term=underline cterm=NONE ctermfg=DarkCyan ctermbg=NONE gui=NONE guifg=DarkCyan guibg=NONE",
  "Statement    term=bold cterm=NONE ctermfg=Brown ctermbg=NONE gui=bold guifg=Brown guibg=NONE",
  "PreProc      term=underline cterm=NONE ctermfg=DarkMagenta ctermbg=NONE gui=NONE guifg=#6a0dad guibg=NONE",
  "Type         term=underline cterm=NONE ctermfg=DarkGreen ctermbg=NONE gui=bold guifg=SeaGreen guibg=NONE",
  "Underlined   term=underline cterm=underline ctermfg=DarkMagenta gui=underline guifg=SlateBlue",
  "Ignore       term=NONE cterm=NONE ctermfg=white ctermbg=NONE gui=NONE guifg=bg guibg=NONE",
  NULL
};

// Default colors only used with a dark background.
static const char *highlight_init_dark[] = {
  "ColorColumn  ctermbg=DarkRed guibg=DarkRed",
  "CursorColumn ctermbg=DarkGrey guibg=Grey40",
  "CursorLine   cterm=underline guibg=Grey40",
  "CursorLineNr cterm=underline ctermfg=Yellow gui=bold guifg=Yellow",
  "DiffAdd      ctermbg=DarkBlue guibg=DarkBlue",
  "DiffChange   ctermbg=DarkMagenta guibg=DarkMagenta",
  "DiffDelete   ctermfg=Blue ctermbg=DarkCyan gui=bold guifg=Blue guibg=DarkCyan",
  "Directory    ctermfg=LightCyan guifg=Cyan",
  "FoldColumn   ctermbg=DarkGrey ctermfg=Cyan guibg=Grey guifg=Cyan",
  "Folded       ctermbg=DarkGrey ctermfg=Cyan guibg=DarkGrey guifg=Cyan",
  "LineNr       ctermfg=Yellow guifg=Yellow",
  "MatchParen   ctermbg=DarkCyan guibg=DarkCyan",
  "MoreMsg      ctermfg=LightGreen gui=bold guifg=SeaGreen",
  "Pmenu        ctermbg=Magenta ctermfg=Black guibg=Magenta",
  "PmenuSel     ctermbg=Black ctermfg=DarkGrey guibg=DarkGrey",
  "PmenuThumb   ctermbg=White guibg=White",
  "Question     ctermfg=LightGreen gui=bold guifg=Green",
  "Search       ctermbg=Yellow ctermfg=Black guibg=Yellow guifg=Black",
  "SignColumn   ctermbg=DarkGrey ctermfg=Cyan guibg=Grey guifg=Cyan",
  "SpecialKey   ctermfg=LightBlue guifg=Cyan",
  "SpellBad     ctermbg=Red guisp=Red gui=undercurl",
  "SpellCap     ctermbg=Blue guisp=Blue gui=undercurl",
  "SpellLocal   ctermbg=Cyan guisp=Cyan gui=undercurl",
  "SpellRare    ctermbg=Magenta guisp=Magenta gui=undercurl",
  "TabLine      cterm=underline ctermfg=white ctermbg=DarkGrey gui=underline guibg=DarkGrey",
  "Title        ctermfg=LightMagenta gui=bold guifg=Magenta",
  "Visual       guibg=DarkGrey",
  "WarningMsg   ctermfg=LightRed guifg=Red",
  "Comment      term=bold cterm=NONE ctermfg=Cyan ctermbg=NONE gui=NONE guifg=#80a0ff guibg=NONE",
  "Constant     term=underline cterm=NONE ctermfg=Magenta ctermbg=NONE gui=NONE guifg=#ffa0a0 guibg=NONE",
  "Special      term=bold cterm=NONE ctermfg=LightRed ctermbg=NONE gui=NONE guifg=Orange guibg=NONE",
  "Identifier   term=underline cterm=bold ctermfg=Cyan ctermbg=NONE gui=NONE guifg=#40ffff guibg=NONE",
  "Statement    term=bold cterm=NONE ctermfg=Yellow ctermbg=NONE gui=bold guifg=#ffff60 guibg=NONE",
  "PreProc      term=underline cterm=NONE ctermfg=LightBlue ctermbg=NONE gui=NONE guifg=#ff80ff guibg=NONE",
  "Type         term=underline cterm=NONE ctermfg=LightGreen ctermbg=NONE gui=bold guifg=#60ff60 guibg=NONE",
  "Underlined   term=underline cterm=underline ctermfg=LightBlue gui=underline guifg=#80a0ff",
  "Ignore       term=NONE cterm=NONE ctermfg=black ctermbg=NONE gui=NONE guifg=bg guibg=NONE",
  NULL
};

const char *const highlight_init_cmdline[] = {
  // XXX When modifying a list modify it in both valid and invalid halves.
  // TODO(ZyX-I): merge valid and invalid groups via a macros.

  // NvimInternalError should appear only when highlighter has a bug.
  "NvimInternalError ctermfg=Red ctermbg=Red guifg=Red guibg=Red",

  // Highlight groups (links) used by parser:

  "default link NvimAssignment Operator",
  "default link NvimPlainAssignment NvimAssignment",
  "default link NvimAugmentedAssignment NvimAssignment",
  "default link NvimAssignmentWithAddition NvimAugmentedAssignment",
  "default link NvimAssignmentWithSubtraction NvimAugmentedAssignment",
  "default link NvimAssignmentWithConcatenation NvimAugmentedAssignment",

  "default link NvimOperator Operator",

  "default link NvimUnaryOperator NvimOperator",
  "default link NvimUnaryPlus NvimUnaryOperator",
  "default link NvimUnaryMinus NvimUnaryOperator",
  "default link NvimNot NvimUnaryOperator",

  "default link NvimBinaryOperator NvimOperator",
  "default link NvimComparison NvimBinaryOperator",
  "default link NvimComparisonModifier NvimComparison",
  "default link NvimBinaryPlus NvimBinaryOperator",
  "default link NvimBinaryMinus NvimBinaryOperator",
  "default link NvimConcat NvimBinaryOperator",
  "default link NvimConcatOrSubscript NvimConcat",
  "default link NvimOr NvimBinaryOperator",
  "default link NvimAnd NvimBinaryOperator",
  "default link NvimMultiplication NvimBinaryOperator",
  "default link NvimDivision NvimBinaryOperator",
  "default link NvimMod NvimBinaryOperator",

  "default link NvimTernary NvimOperator",
  "default link NvimTernaryColon NvimTernary",

  "default link NvimParenthesis Delimiter",
  "default link NvimLambda NvimParenthesis",
  "default link NvimNestingParenthesis NvimParenthesis",
  "default link NvimCallingParenthesis NvimParenthesis",

  "default link NvimSubscript NvimParenthesis",
  "default link NvimSubscriptBracket NvimSubscript",
  "default link NvimSubscriptColon NvimSubscript",
  "default link NvimCurly NvimSubscript",

  "default link NvimContainer NvimParenthesis",
  "default link NvimDict NvimContainer",
  "default link NvimList NvimContainer",

  "default link NvimIdentifier Identifier",
  "default link NvimIdentifierScope NvimIdentifier",
  "default link NvimIdentifierScopeDelimiter NvimIdentifier",
  "default link NvimIdentifierName NvimIdentifier",
  "default link NvimIdentifierKey NvimIdentifier",

  "default link NvimColon Delimiter",
  "default link NvimComma Delimiter",
  "default link NvimArrow Delimiter",

  "default link NvimRegister SpecialChar",
  "default link NvimNumber Number",
  "default link NvimFloat NvimNumber",
  "default link NvimNumberPrefix Type",

  "default link NvimOptionSigil Type",
  "default link NvimOptionName NvimIdentifier",
  "default link NvimOptionScope NvimIdentifierScope",
  "default link NvimOptionScopeDelimiter NvimIdentifierScopeDelimiter",

  "default link NvimEnvironmentSigil NvimOptionSigil",
  "default link NvimEnvironmentName NvimIdentifier",

  "default link NvimString String",
  "default link NvimStringBody NvimString",
  "default link NvimStringQuote NvimString",
  "default link NvimStringSpecial SpecialChar",

  "default link NvimSingleQuote NvimStringQuote",
  "default link NvimSingleQuotedBody NvimStringBody",
  "default link NvimSingleQuotedQuote NvimStringSpecial",

  "default link NvimDoubleQuote NvimStringQuote",
  "default link NvimDoubleQuotedBody NvimStringBody",
  "default link NvimDoubleQuotedEscape NvimStringSpecial",

  "default link NvimFigureBrace NvimInternalError",
  "default link NvimSingleQuotedUnknownEscape NvimInternalError",

  "default link NvimSpacing Normal",

  // NvimInvalid groups:

  "default link NvimInvalidSingleQuotedUnknownEscape NvimInternalError",

  "default link NvimInvalid Error",

  "default link NvimInvalidAssignment NvimInvalid",
  "default link NvimInvalidPlainAssignment NvimInvalidAssignment",
  "default link NvimInvalidAugmentedAssignment NvimInvalidAssignment",
  "default link NvimInvalidAssignmentWithAddition NvimInvalidAugmentedAssignment",
  "default link NvimInvalidAssignmentWithSubtraction NvimInvalidAugmentedAssignment",
  "default link NvimInvalidAssignmentWithConcatenation NvimInvalidAugmentedAssignment",

  "default link NvimInvalidOperator NvimInvalid",

  "default link NvimInvalidUnaryOperator NvimInvalidOperator",
  "default link NvimInvalidUnaryPlus NvimInvalidUnaryOperator",
  "default link NvimInvalidUnaryMinus NvimInvalidUnaryOperator",
  "default link NvimInvalidNot NvimInvalidUnaryOperator",

  "default link NvimInvalidBinaryOperator NvimInvalidOperator",
  "default link NvimInvalidComparison NvimInvalidBinaryOperator",
  "default link NvimInvalidComparisonModifier NvimInvalidComparison",
  "default link NvimInvalidBinaryPlus NvimInvalidBinaryOperator",
  "default link NvimInvalidBinaryMinus NvimInvalidBinaryOperator",
  "default link NvimInvalidConcat NvimInvalidBinaryOperator",
  "default link NvimInvalidConcatOrSubscript NvimInvalidConcat",
  "default link NvimInvalidOr NvimInvalidBinaryOperator",
  "default link NvimInvalidAnd NvimInvalidBinaryOperator",
  "default link NvimInvalidMultiplication NvimInvalidBinaryOperator",
  "default link NvimInvalidDivision NvimInvalidBinaryOperator",
  "default link NvimInvalidMod NvimInvalidBinaryOperator",

  "default link NvimInvalidTernary NvimInvalidOperator",
  "default link NvimInvalidTernaryColon NvimInvalidTernary",

  "default link NvimInvalidDelimiter NvimInvalid",

  "default link NvimInvalidParenthesis NvimInvalidDelimiter",
  "default link NvimInvalidLambda NvimInvalidParenthesis",
  "default link NvimInvalidNestingParenthesis NvimInvalidParenthesis",
  "default link NvimInvalidCallingParenthesis NvimInvalidParenthesis",

  "default link NvimInvalidSubscript NvimInvalidParenthesis",
  "default link NvimInvalidSubscriptBracket NvimInvalidSubscript",
  "default link NvimInvalidSubscriptColon NvimInvalidSubscript",
  "default link NvimInvalidCurly NvimInvalidSubscript",

  "default link NvimInvalidContainer NvimInvalidParenthesis",
  "default link NvimInvalidDict NvimInvalidContainer",
  "default link NvimInvalidList NvimInvalidContainer",

  "default link NvimInvalidValue NvimInvalid",

  "default link NvimInvalidIdentifier NvimInvalidValue",
  "default link NvimInvalidIdentifierScope NvimInvalidIdentifier",
  "default link NvimInvalidIdentifierScopeDelimiter NvimInvalidIdentifier",
  "default link NvimInvalidIdentifierName NvimInvalidIdentifier",
  "default link NvimInvalidIdentifierKey NvimInvalidIdentifier",

  "default link NvimInvalidColon NvimInvalidDelimiter",
  "default link NvimInvalidComma NvimInvalidDelimiter",
  "default link NvimInvalidArrow NvimInvalidDelimiter",

  "default link NvimInvalidRegister NvimInvalidValue",
  "default link NvimInvalidNumber NvimInvalidValue",
  "default link NvimInvalidFloat NvimInvalidNumber",
  "default link NvimInvalidNumberPrefix NvimInvalidNumber",

  "default link NvimInvalidOptionSigil NvimInvalidIdentifier",
  "default link NvimInvalidOptionName NvimInvalidIdentifier",
  "default link NvimInvalidOptionScope NvimInvalidIdentifierScope",
  "default link NvimInvalidOptionScopeDelimiter NvimInvalidIdentifierScopeDelimiter",

  "default link NvimInvalidEnvironmentSigil NvimInvalidOptionSigil",
  "default link NvimInvalidEnvironmentName NvimInvalidIdentifier",

  // Invalid string bodies and specials are still highlighted as valid ones to
  // minimize the red area.
  "default link NvimInvalidString NvimInvalidValue",
  "default link NvimInvalidStringBody NvimStringBody",
  "default link NvimInvalidStringQuote NvimInvalidString",
  "default link NvimInvalidStringSpecial NvimStringSpecial",

  "default link NvimInvalidSingleQuote NvimInvalidStringQuote",
  "default link NvimInvalidSingleQuotedBody NvimInvalidStringBody",
  "default link NvimInvalidSingleQuotedQuote NvimInvalidStringSpecial",

  "default link NvimInvalidDoubleQuote NvimInvalidStringQuote",
  "default link NvimInvalidDoubleQuotedBody NvimInvalidStringBody",
  "default link NvimInvalidDoubleQuotedEscape NvimInvalidStringSpecial",
  "default link NvimInvalidDoubleQuotedUnknownEscape NvimInvalidValue",

  "default link NvimInvalidFigureBrace NvimInvalidDelimiter",

  "default link NvimInvalidSpacing ErrorMsg",

  // Not actually invalid, but we show the user that they are doing something
  // wrong.
  "default link NvimDoubleQuotedUnknownEscape NvimInvalidValue",
  NULL,
};

/// Returns the number of highlight groups.
int highlight_num_groups(void)
{
  return highlight_ga.ga_len;
}

/// Returns the name of a highlight group.
char_u *highlight_group_name(int id)
{
  return HL_TABLE()[id].sg_name;
}

/// Returns the ID of the link to a highlight group.
int highlight_link_id(int id)
{
  return HL_TABLE()[id].sg_link;
}

/// Create default links for Nvim* highlight groups used for cmdline coloring
void syn_init_cmdline_highlight(bool reset, bool init)
{
  for (size_t i = 0; highlight_init_cmdline[i] != NULL; i++) {
    do_highlight(highlight_init_cmdline[i], reset, init);
  }
}

/// Load colors from a file if "g:colors_name" is set, otherwise load builtin
/// colors
///
/// @param both include groups where 'bg' doesn't matter
/// @param reset clear groups first
void init_highlight(bool both, bool reset)
{
  static int had_both = false;

  // Try finding the color scheme file.  Used when a color file was loaded
  // and 'background' or 't_Co' is changed.
  char_u *p = get_var_value("g:colors_name");
  if (p != NULL) {
    // Value of g:colors_name could be freed in load_colors() and make
    // p invalid, so copy it.
    char_u *copy_p = vim_strsave(p);
    bool okay = load_colors(copy_p);
    xfree(copy_p);
    if (okay) {
      return;
    }
  }

  // Didn't use a color file, use the compiled-in colors.
  if (both) {
    had_both = true;
    const char *const *const pp = highlight_init_both;
    for (size_t i = 0; pp[i] != NULL; i++) {
      do_highlight(pp[i], reset, true);
    }
  } else if (!had_both) {
    // Don't do anything before the call with both == true from main().
    // Not everything has been setup then, and that call will overrule
    // everything anyway.
    return;
  }

  const char *const *const pp = ((*p_bg == 'l')
                                 ? highlight_init_light
                                 : highlight_init_dark);
  for (size_t i = 0; pp[i] != NULL; i++) {
    do_highlight(pp[i], reset, true);
  }

  // Reverse looks ugly, but grey may not work for 8 colors.  Thus let it
  // depend on the number of colors available.
  // With 8 colors brown is equal to yellow, need to use black for Search fg
  // to avoid Statement highlighted text disappears.
  // Clear the attributes, needed when changing the t_Co value.
  if (t_colors > 8) {
    do_highlight((*p_bg == 'l'
                  ? "Visual cterm=NONE ctermbg=LightGrey"
                  : "Visual cterm=NONE ctermbg=DarkGrey"), false, true);
  } else {
    do_highlight("Visual cterm=reverse ctermbg=NONE", false, true);
    if (*p_bg == 'l') {
      do_highlight("Search ctermfg=black", false, true);
    }
  }

  syn_init_cmdline_highlight(false, false);
}

/// Load color file "name".
/// Return OK for success, FAIL for failure.
int load_colors(char_u *name)
{
  char_u *buf;
  int retval = FAIL;
  static bool recursive = false;

  // When being called recursively, this is probably because setting
  // 'background' caused the highlighting to be reloaded.  This means it is
  // working, thus we should return OK.
  if (recursive) {
    return OK;
  }

  recursive = true;
  size_t buflen = STRLEN(name) + 12;
  buf = xmalloc(buflen);
  apply_autocmds(EVENT_COLORSCHEMEPRE, (char *)name, curbuf->b_fname, false, curbuf);
  snprintf((char *)buf, buflen, "colors/%s.vim", name);
  retval = source_runtime((char *)buf, DIP_START + DIP_OPT);
  if (retval == FAIL) {
    snprintf((char *)buf, buflen, "colors/%s.lua", name);
    retval = source_runtime((char *)buf, DIP_START + DIP_OPT);
  }
  xfree(buf);
  apply_autocmds(EVENT_COLORSCHEME, (char *)name, curbuf->b_fname, false, curbuf);

  recursive = false;

  return retval;
}

static char *(color_names[28]) = {
  "Black", "DarkBlue", "DarkGreen", "DarkCyan",
  "DarkRed", "DarkMagenta", "Brown", "DarkYellow",
  "Gray", "Grey", "LightGray", "LightGrey",
  "DarkGray", "DarkGrey",
  "Blue", "LightBlue", "Green", "LightGreen",
  "Cyan", "LightCyan", "Red", "LightRed", "Magenta",
  "LightMagenta", "Yellow", "LightYellow", "White", "NONE"
};
// indices:
// 0, 1, 2, 3,
// 4, 5, 6, 7,
// 8, 9, 10, 11,
// 12, 13,
// 14, 15, 16, 17,
// 18, 19, 20, 21, 22,
// 23, 24, 25, 26, 27
static int color_numbers_16[28] = { 0, 1, 2, 3,
                                    4, 5, 6, 6,
                                    7, 7, 7, 7,
                                    8, 8,
                                    9, 9, 10, 10,
                                    11, 11, 12, 12, 13,
                                    13, 14, 14, 15, -1 };
// for xterm with 88 colors...
static int color_numbers_88[28] = { 0, 4, 2, 6,
                                    1, 5, 32, 72,
                                    84, 84, 7, 7,
                                    82, 82,
                                    12, 43, 10, 61,
                                    14, 63, 9, 74, 13,
                                    75, 11, 78, 15, -1 };
// for xterm with 256 colors...
static int color_numbers_256[28] = { 0, 4, 2, 6,
                                     1, 5, 130, 3,
                                     248, 248, 7, 7,
                                     242, 242,
                                     12, 81, 10, 121,
                                     14, 159, 9, 224, 13,
                                     225, 11, 229, 15, -1 };
// for terminals with less than 16 colors...
static int color_numbers_8[28] = { 0, 4, 2, 6,
                                   1, 5, 3, 3,
                                   7, 7, 7, 7,
                                   0 + 8, 0 + 8,
                                   4 + 8, 4 + 8, 2 + 8, 2 + 8,
                                   6 + 8, 6 + 8, 1 + 8, 1 + 8, 5 + 8,
                                   5 + 8, 3 + 8, 3 + 8, 7 + 8, -1 };

// Lookup the "cterm" value to be used for color with index "idx" in
// color_names[].
// "boldp" will be set to TRUE or FALSE for a foreground color when using 8
// colors, otherwise it will be unchanged.
int lookup_color(const int idx, const bool foreground, TriState *const boldp)
{
  int color = color_numbers_16[idx];

  // Use the _16 table to check if it's a valid color name.
  if (color < 0) {
    return -1;
  }

  if (t_colors == 8) {
    // t_Co is 8: use the 8 colors table
    color = color_numbers_8[idx];
    if (foreground) {
      // set/reset bold attribute to get light foreground
      // colors (on some terminals, e.g. "linux")
      if (color & 8) {
        *boldp = kTrue;
      } else {
        *boldp = kFalse;
      }
    }
    color &= 7;   // truncate to 8 colors
  } else if (t_colors == 16) {
    color = color_numbers_8[idx];
  } else if (t_colors == 88) {
    color = color_numbers_88[idx];
  } else if (t_colors >= 256) {
    color = color_numbers_256[idx];
  }
  return color;
}

void set_hl_group(int id, HlAttrs attrs, Dict(highlight) *dict, int link_id)
{
  int idx = id - 1;  // Index is ID minus one.

  bool is_default = attrs.rgb_ae_attr & HL_DEFAULT;

  // Return if "default" was used and the group already has settings
  if (is_default && hl_has_settings(idx, true)) {
    return;
  }

  HlGroup *g = &HL_TABLE()[idx];

  if (link_id > 0) {
    g->sg_cleared = false;
    g->sg_link = link_id;
    g->sg_script_ctx = current_sctx;
    g->sg_script_ctx.sc_lnum += sourcing_lnum;
    g->sg_set |= SG_LINK;
    if (is_default) {
      g->sg_deflink = link_id;
      g->sg_deflink_sctx = current_sctx;
      g->sg_deflink_sctx.sc_lnum += sourcing_lnum;
    }
    return;
  }

  g->sg_cleared = false;
  g->sg_link = 0;
  g->sg_gui = attrs.rgb_ae_attr;

  g->sg_rgb_fg = attrs.rgb_fg_color;
  g->sg_rgb_bg = attrs.rgb_bg_color;
  g->sg_rgb_sp = attrs.rgb_sp_color;

  struct {
    char **dest; RgbValue val; Object name;
  } cattrs[] = {
    { &g->sg_rgb_fg_name, g->sg_rgb_fg, HAS_KEY(dict->fg) ? dict->fg : dict->foreground },
    { &g->sg_rgb_bg_name, g->sg_rgb_bg, HAS_KEY(dict->bg) ? dict->bg : dict->background },
    { &g->sg_rgb_sp_name, g->sg_rgb_sp, HAS_KEY(dict->sp) ? dict->sp : dict->special },
    { NULL, -1, NIL },
  };

  char hex_name[8];
  char *name;

  for (int j = 0; cattrs[j].dest; j++) {
    if (cattrs[j].val < 0) {
      XFREE_CLEAR(*cattrs[j].dest);
      continue;
    }

    if (cattrs[j].name.type == kObjectTypeString && cattrs[j].name.data.string.size) {
      name = cattrs[j].name.data.string.data;
    } else {
      snprintf(hex_name, sizeof(hex_name), "#%06x", cattrs[j].val);
      name = hex_name;
    }

    if (!*cattrs[j].dest
        || STRCMP(*cattrs[j].dest, name) != 0) {
      xfree(*cattrs[j].dest);
      *cattrs[j].dest = xstrdup(name);
    }
  }

  g->sg_cterm = attrs.cterm_ae_attr;
  g->sg_cterm_bg = attrs.cterm_bg_color;
  g->sg_cterm_fg = attrs.cterm_fg_color;
  g->sg_cterm_bold = g->sg_cterm & HL_BOLD;
  g->sg_blend = attrs.hl_blend;

  g->sg_script_ctx = current_sctx;
  g->sg_script_ctx.sc_lnum += sourcing_lnum;

  // 'Normal' is special
  if (STRCMP(g->sg_name_u, "NORMAL") == 0) {
    cterm_normal_fg_color = g->sg_cterm_fg;
    cterm_normal_bg_color = g->sg_cterm_bg;
    normal_fg = g->sg_rgb_fg;
    normal_bg = g->sg_rgb_bg;
    normal_sp = g->sg_rgb_sp;
    ui_default_colors_set();
  } else {
    g->sg_attr = hl_get_syn_attr(0, id, attrs);

    // a cursor style uses this syn_id, make sure its attribute is updated.
    if (cursor_mode_uses_syn_id(id)) {
      ui_mode_info_set();
    }
  }
}

/// Handle ":highlight" command
///
/// When using ":highlight clear" this is called recursively for each group with
/// forceit and init being both true.
///
/// @param[in]  line  Command arguments.
/// @param[in]  forceit  True when bang is given, allows to link group even if
///                      it has its own settings.
/// @param[in]  init  True when initializing.
void do_highlight(const char *line, const bool forceit, const bool init)
  FUNC_ATTR_NONNULL_ALL
{
  const char *name_end;
  const char *linep;
  const char *key_start;
  const char *arg_start;
  int off;
  int len;
  int attr;
  int id;
  int idx;
  HlGroup item_before;
  bool did_change = false;
  bool dodefault = false;
  bool doclear = false;
  bool dolink = false;
  bool error = false;
  int color;
  bool is_normal_group = false;   // "Normal" group
  bool did_highlight_changed = false;

  // If no argument, list current highlighting.
  if (ends_excmd((uint8_t)(*line))) {
    for (int i = 1; i <= highlight_ga.ga_len && !got_int; i++) {
      // TODO(brammool): only call when the group has attributes set
      highlight_list_one(i);
    }
    return;
  }

  // Isolate the name.
  name_end = (const char *)skiptowhite((const char_u *)line);
  linep = (const char *)skipwhite(name_end);

  // Check for "default" argument.
  if (strncmp(line, "default", (size_t)(name_end - line)) == 0) {
    dodefault = true;
    line = linep;
    name_end = (const char *)skiptowhite((const char_u *)line);
    linep = (const char *)skipwhite(name_end);
  }

  // Check for "clear" or "link" argument.
  if (strncmp(line, "clear", (size_t)(name_end - line)) == 0) {
    doclear = true;
  } else if (strncmp(line, "link", (size_t)(name_end - line)) == 0) {
    dolink = true;
  }

  // ":highlight {group-name}": list highlighting for one group.
  if (!doclear && !dolink && ends_excmd((uint8_t)(*linep))) {
    id = syn_name2id_len((const char_u *)line, (size_t)(name_end - line));
    if (id == 0) {
      semsg(_("E411: highlight group not found: %s"), line);
    } else {
      highlight_list_one(id);
    }
    return;
  }

  // Handle ":highlight link {from} {to}" command.
  if (dolink) {
    const char *from_start = linep;
    const char *from_end;
    const char *to_start;
    const char *to_end;
    int from_id;
    int to_id;
    HlGroup *hlgroup = NULL;

    from_end = (const char *)skiptowhite((const char_u *)from_start);
    to_start = (const char *)skipwhite(from_end);
    to_end   = (const char *)skiptowhite((const char_u *)to_start);

    if (ends_excmd((uint8_t)(*from_start))
        || ends_excmd((uint8_t)(*to_start))) {
      semsg(_("E412: Not enough arguments: \":highlight link %s\""),
            from_start);
      return;
    }

    if (!ends_excmd(*skipwhite(to_end))) {
      semsg(_("E413: Too many arguments: \":highlight link %s\""), from_start);
      return;
    }

    from_id = syn_check_group(from_start, (size_t)(from_end - from_start));
    if (strncmp(to_start, "NONE", 4) == 0) {
      to_id = 0;
    } else {
      to_id = syn_check_group(to_start, (size_t)(to_end - to_start));
    }

    if (from_id > 0) {
      hlgroup = &HL_TABLE()[from_id - 1];
      if (dodefault && (forceit || hlgroup->sg_deflink == 0)) {
        hlgroup->sg_deflink = to_id;
        hlgroup->sg_deflink_sctx = current_sctx;
        hlgroup->sg_deflink_sctx.sc_lnum += sourcing_lnum;
        nlua_set_sctx(&hlgroup->sg_deflink_sctx);
      }
    }

    if (from_id > 0 && (!init || hlgroup->sg_set == 0)) {
      // Don't allow a link when there already is some highlighting
      // for the group, unless '!' is used
      if (to_id > 0 && !forceit && !init
          && hl_has_settings(from_id - 1, dodefault)) {
        if (sourcing_name == NULL && !dodefault) {
          emsg(_("E414: group has settings, highlight link ignored"));
        }
      } else if (hlgroup->sg_link != to_id
                 || hlgroup->sg_script_ctx.sc_sid != current_sctx.sc_sid
                 || hlgroup->sg_cleared) {
        if (!init) {
          hlgroup->sg_set |= SG_LINK;
        }
        hlgroup->sg_link = to_id;
        hlgroup->sg_script_ctx = current_sctx;
        hlgroup->sg_script_ctx.sc_lnum += sourcing_lnum;
        nlua_set_sctx(&hlgroup->sg_script_ctx);
        hlgroup->sg_cleared = false;
        redraw_all_later(SOME_VALID);

        // Only call highlight changed() once after multiple changes
        need_highlight_changed = true;
      }
    }

    return;
  }

  if (doclear) {
    // ":highlight clear [group]" command.
    line = linep;
    if (ends_excmd((uint8_t)(*line))) {
      do_unlet(S_LEN("colors_name"), true);
      restore_cterm_colors();

      // Clear all default highlight groups and load the defaults.
      for (int j = 0; j < highlight_ga.ga_len; j++) {
        highlight_clear(j);
      }
      init_highlight(true, true);
      highlight_changed();
      redraw_all_later(NOT_VALID);
      return;
    }
    name_end = (const char *)skiptowhite((const char_u *)line);
    linep = (const char *)skipwhite(name_end);
  }

  // Find the group name in the table.  If it does not exist yet, add it.
  id = syn_check_group(line, (size_t)(name_end - line));
  if (id == 0) {  // Failed (out of memory).
    return;
  }
  idx = id - 1;  // Index is ID minus one.

  // Return if "default" was used and the group already has settings
  if (dodefault && hl_has_settings(idx, true)) {
    return;
  }

  // Make a copy so we can check if any attribute actually changed
  item_before = HL_TABLE()[idx];
  is_normal_group = (STRCMP(HL_TABLE()[idx].sg_name_u, "NORMAL") == 0);

  // Clear the highlighting for ":hi clear {group}" and ":hi clear".
  if (doclear || (forceit && init)) {
    highlight_clear(idx);
    if (!doclear) {
      HL_TABLE()[idx].sg_set = 0;
    }
  }

  char *key = NULL;
  char *arg = NULL;
  if (!doclear) {
    while (!ends_excmd((uint8_t)(*linep))) {
      key_start = linep;
      if (*linep == '=') {
        semsg(_("E415: unexpected equal sign: %s"), key_start);
        error = true;
        break;
      }

      // Isolate the key ("term", "ctermfg", "ctermbg", "font", "guifg",
      // "guibg" or "guisp").
      while (*linep && !ascii_iswhite(*linep) && *linep != '=') {
        linep++;
      }
      xfree(key);
      key = (char *)vim_strnsave_up((const char_u *)key_start,
                                    (size_t)(linep - key_start));
      linep = (const char *)skipwhite(linep);

      if (strcmp(key, "NONE") == 0) {
        if (!init || HL_TABLE()[idx].sg_set == 0) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_CTERM + SG_GUI;
          }
          highlight_clear(idx);
        }
        continue;
      }

      // Check for the equal sign.
      if (*linep != '=') {
        semsg(_("E416: missing equal sign: %s"), key_start);
        error = true;
        break;
      }
      linep++;

      // Isolate the argument.
      linep = (const char *)skipwhite(linep);
      if (*linep == '\'') {  // guifg='color name'
        arg_start = ++linep;
        linep = strchr(linep, '\'');
        if (linep == NULL) {
          semsg(_(e_invarg2), key_start);
          error = true;
          break;
        }
      } else {
        arg_start = linep;
        linep = (const char *)skiptowhite((const char_u *)linep);
      }
      if (linep == arg_start) {
        semsg(_("E417: missing argument: %s"), key_start);
        error = true;
        break;
      }
      xfree(arg);
      arg = xstrndup(arg_start, (size_t)(linep - arg_start));

      if (*linep == '\'') {
        linep++;
      }

      // Store the argument.
      if (strcmp(key, "TERM") == 0
          || strcmp(key, "CTERM") == 0
          || strcmp(key, "GUI") == 0) {
        attr = 0;
        off = 0;
        int i;
        while (arg[off] != NUL) {
          for (i = ARRAY_SIZE(hl_attr_table); --i >= 0;) {
            len = (int)STRLEN(hl_name_table[i]);
            if (STRNICMP(arg + off, hl_name_table[i], len) == 0) {
              attr |= hl_attr_table[i];
              off += len;
              break;
            }
          }
          if (i < 0) {
            semsg(_("E418: Illegal value: %s"), arg);
            error = true;
            break;
          }
          if (arg[off] == ',') {  // Another one follows.
            off++;
          }
        }
        if (error) {
          break;
        }
        if (*key == 'C') {
          if (!init || !(HL_TABLE()[idx].sg_set & SG_CTERM)) {
            if (!init) {
              HL_TABLE()[idx].sg_set |= SG_CTERM;
            }
            HL_TABLE()[idx].sg_cterm = attr;
            HL_TABLE()[idx].sg_cterm_bold = false;
          }
        } else if (*key == 'G') {
          if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
            if (!init) {
              HL_TABLE()[idx].sg_set |= SG_GUI;
            }
            HL_TABLE()[idx].sg_gui = attr;
          }
        }
      } else if (STRCMP(key, "FONT") == 0) {
        // in non-GUI fonts are simply ignored
      } else if (STRCMP(key, "CTERMFG") == 0 || STRCMP(key, "CTERMBG") == 0) {
        if (!init || !(HL_TABLE()[idx].sg_set & SG_CTERM)) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_CTERM;
          }

          // When setting the foreground color, and previously the "bold"
          // flag was set for a light color, reset it now
          if (key[5] == 'F' && HL_TABLE()[idx].sg_cterm_bold) {
            HL_TABLE()[idx].sg_cterm &= ~HL_BOLD;
            HL_TABLE()[idx].sg_cterm_bold = false;
          }

          if (ascii_isdigit(*arg)) {
            color = atoi(arg);
          } else if (STRICMP(arg, "fg") == 0) {
            if (cterm_normal_fg_color) {
              color = cterm_normal_fg_color - 1;
            } else {
              emsg(_("E419: FG color unknown"));
              error = true;
              break;
            }
          } else if (STRICMP(arg, "bg") == 0) {
            if (cterm_normal_bg_color > 0) {
              color = cterm_normal_bg_color - 1;
            } else {
              emsg(_("E420: BG color unknown"));
              error = true;
              break;
            }
          } else {
            // Reduce calls to STRICMP a bit, it can be slow.
            off = TOUPPER_ASC(*arg);
            int i;
            for (i = ARRAY_SIZE(color_names); --i >= 0;) {
              if (off == color_names[i][0]
                  && STRICMP(arg + 1, color_names[i] + 1) == 0) {
                break;
              }
            }
            if (i < 0) {
              semsg(_("E421: Color name or number not recognized: %s"),
                    key_start);
              error = true;
              break;
            }

            TriState bold = kNone;
            color = lookup_color(i, key[5] == 'F', &bold);

            // set/reset bold attribute to get light foreground
            // colors (on some terminals, e.g. "linux")
            if (bold == kTrue) {
              HL_TABLE()[idx].sg_cterm |= HL_BOLD;
              HL_TABLE()[idx].sg_cterm_bold = true;
            } else if (bold == kFalse) {
              HL_TABLE()[idx].sg_cterm &= ~HL_BOLD;
            }
          }
          // Add one to the argument, to avoid zero.  Zero is used for
          // "NONE", then "color" is -1.
          if (key[5] == 'F') {
            HL_TABLE()[idx].sg_cterm_fg = color + 1;
            if (is_normal_group) {
              cterm_normal_fg_color = color + 1;
            }
          } else {
            HL_TABLE()[idx].sg_cterm_bg = color + 1;
            if (is_normal_group) {
              cterm_normal_bg_color = color + 1;
              if (!ui_rgb_attached()) {
                if (color >= 0) {
                  int dark = -1;

                  if (t_colors < 16) {
                    dark = (color == 0 || color == 4);
                  } else if (color < 16) {
                    // Limit the heuristic to the standard 16 colors
                    dark = (color < 7 || color == 8);
                  }
                  // Set the 'background' option if the value is
                  // wrong.
                  if (dark != -1
                      && dark != (*p_bg == 'd')
                      && !option_was_set("bg")) {
                    set_option_value("bg", 0L, (dark ? "dark" : "light"), 0);
                    reset_option_was_set("bg");
                  }
                }
              }
            }
          }
        }
      } else if (strcmp(key, "GUIFG") == 0) {
        char **namep = &HL_TABLE()[idx].sg_rgb_fg_name;

        if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_GUI;
          }

          if (*namep == NULL || STRCMP(*namep, arg) != 0) {
            xfree(*namep);
            if (strcmp(arg, "NONE") != 0) {
              *namep = xstrdup(arg);
              HL_TABLE()[idx].sg_rgb_fg = name_to_color(arg);
            } else {
              *namep = NULL;
              HL_TABLE()[idx].sg_rgb_fg = -1;
            }
            did_change = true;
          }
        }

        if (is_normal_group) {
          normal_fg = HL_TABLE()[idx].sg_rgb_fg;
        }
      } else if (STRCMP(key, "GUIBG") == 0) {
        char **const namep = &HL_TABLE()[idx].sg_rgb_bg_name;

        if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_GUI;
          }

          if (*namep == NULL || STRCMP(*namep, arg) != 0) {
            xfree(*namep);
            if (STRCMP(arg, "NONE") != 0) {
              *namep = xstrdup(arg);
              HL_TABLE()[idx].sg_rgb_bg = name_to_color(arg);
            } else {
              *namep = NULL;
              HL_TABLE()[idx].sg_rgb_bg = -1;
            }
            did_change = true;
          }
        }

        if (is_normal_group) {
          normal_bg = HL_TABLE()[idx].sg_rgb_bg;
        }
      } else if (strcmp(key, "GUISP") == 0) {
        char **const namep = &HL_TABLE()[idx].sg_rgb_sp_name;

        if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
          if (!init) {
            HL_TABLE()[idx].sg_set |= SG_GUI;
          }

          if (*namep == NULL || STRCMP(*namep, arg) != 0) {
            xfree(*namep);
            if (strcmp(arg, "NONE") != 0) {
              *namep = xstrdup(arg);
              HL_TABLE()[idx].sg_rgb_sp = name_to_color(arg);
            } else {
              *namep = NULL;
              HL_TABLE()[idx].sg_rgb_sp = -1;
            }
            did_change = true;
          }
        }

        if (is_normal_group) {
          normal_sp = HL_TABLE()[idx].sg_rgb_sp;
        }
      } else if (strcmp(key, "START") == 0 || strcmp(key, "STOP") == 0) {
        // Ignored for now
      } else if (strcmp(key, "BLEND") == 0) {
        if (strcmp(arg, "NONE") != 0) {
          HL_TABLE()[idx].sg_blend = (int)strtol(arg, NULL, 10);
        } else {
          HL_TABLE()[idx].sg_blend = -1;
        }
      } else {
        semsg(_("E423: Illegal argument: %s"), key_start);
        error = true;
        break;
      }
      HL_TABLE()[idx].sg_cleared = false;

      // When highlighting has been given for a group, don't link it.
      if (!init || !(HL_TABLE()[idx].sg_set & SG_LINK)) {
        HL_TABLE()[idx].sg_link = 0;
      }

      // Continue with next argument.
      linep = (const char *)skipwhite(linep);
    }
  }

  // If there is an error, and it's a new entry, remove it from the table.
  if (error && idx == highlight_ga.ga_len) {
    syn_unadd_group();
  } else {
    if (!error && is_normal_group) {
      // Need to update all groups, because they might be using "bg" and/or
      // "fg", which have been changed now.
      highlight_attr_set_all();

      if (!ui_has(kUILinegrid) && starting == 0) {
        // Older UIs assume that we clear the screen after normal group is
        // changed
        ui_refresh();
      } else {
        // TUI and newer UIs will repaint the screen themselves. NOT_VALID
        // redraw below will still handle usages of guibg=fg etc.
        ui_default_colors_set();
      }
      did_highlight_changed = true;
      redraw_all_later(NOT_VALID);
    } else {
      set_hl_attr(idx);
    }
    HL_TABLE()[idx].sg_script_ctx = current_sctx;
    HL_TABLE()[idx].sg_script_ctx.sc_lnum += sourcing_lnum;
    nlua_set_sctx(&HL_TABLE()[idx].sg_script_ctx);
  }
  xfree(key);
  xfree(arg);

  // Only call highlight_changed() once, after a sequence of highlight
  // commands, and only if an attribute actually changed
  if ((did_change
       || memcmp(&HL_TABLE()[idx], &item_before, sizeof(item_before)) != 0)
      && !did_highlight_changed) {
    // Do not trigger a redraw when highlighting is changed while
    // redrawing.  This may happen when evaluating 'statusline' changes the
    // StatusLine group.
    if (!updating_screen) {
      redraw_all_later(NOT_VALID);
    }
    need_highlight_changed = true;
  }
}

#if defined(EXITFREE)
void free_highlight(void)
{
  for (int i = 0; i < highlight_ga.ga_len; i++) {
    highlight_clear(i);
    xfree(HL_TABLE()[i].sg_name);
    xfree(HL_TABLE()[i].sg_name_u);
  }
  ga_clear(&highlight_ga);
  map_destroy(cstr_t, int)(&highlight_unames);
}

#endif

/// Reset the cterm colors to what they were before Vim was started, if
/// possible.  Otherwise reset them to zero.
void restore_cterm_colors(void)
{
  normal_fg = -1;
  normal_bg = -1;
  normal_sp = -1;
  cterm_normal_fg_color = 0;
  cterm_normal_bg_color = 0;
}

/// @param check_link  if true also check for an existing link.
///
/// @return TRUE if highlight group "idx" has any settings.
static int hl_has_settings(int idx, bool check_link)
{
  return HL_TABLE()[idx].sg_cleared == 0
         && (HL_TABLE()[idx].sg_attr != 0
             || HL_TABLE()[idx].sg_cterm_fg != 0
             || HL_TABLE()[idx].sg_cterm_bg != 0
             || HL_TABLE()[idx].sg_rgb_fg_name != NULL
             || HL_TABLE()[idx].sg_rgb_bg_name != NULL
             || HL_TABLE()[idx].sg_rgb_sp_name != NULL
             || (check_link && (HL_TABLE()[idx].sg_set & SG_LINK)));
}

/// Clear highlighting for one group.
static void highlight_clear(int idx)
{
  HL_TABLE()[idx].sg_cleared = true;

  HL_TABLE()[idx].sg_attr = 0;
  HL_TABLE()[idx].sg_cterm = 0;
  HL_TABLE()[idx].sg_cterm_bold = false;
  HL_TABLE()[idx].sg_cterm_fg = 0;
  HL_TABLE()[idx].sg_cterm_bg = 0;
  HL_TABLE()[idx].sg_gui = 0;
  HL_TABLE()[idx].sg_rgb_fg = -1;
  HL_TABLE()[idx].sg_rgb_bg = -1;
  HL_TABLE()[idx].sg_rgb_sp = -1;
  XFREE_CLEAR(HL_TABLE()[idx].sg_rgb_fg_name);
  XFREE_CLEAR(HL_TABLE()[idx].sg_rgb_bg_name);
  XFREE_CLEAR(HL_TABLE()[idx].sg_rgb_sp_name);
  HL_TABLE()[idx].sg_blend = -1;
  // Restore default link and context if they exist. Otherwise clears.
  HL_TABLE()[idx].sg_link = HL_TABLE()[idx].sg_deflink;
  // Since we set the default link, set the location to where the default
  // link was set.
  HL_TABLE()[idx].sg_script_ctx = HL_TABLE()[idx].sg_deflink_sctx;
}

/// \addtogroup LIST_XXX
/// @{
#define LIST_ATTR   1
#define LIST_STRING 2
#define LIST_INT    3
/// @}

static void highlight_list_one(const int id)
{
  const HlGroup *sgp = &HL_TABLE()[id - 1];  // index is ID minus one
  bool didh = false;

  if (message_filtered(sgp->sg_name)) {
    return;
  }

  didh = highlight_list_arg(id, didh, LIST_ATTR,
                            sgp->sg_cterm, NULL, "cterm");
  didh = highlight_list_arg(id, didh, LIST_INT,
                            sgp->sg_cterm_fg, NULL, "ctermfg");
  didh = highlight_list_arg(id, didh, LIST_INT,
                            sgp->sg_cterm_bg, NULL, "ctermbg");

  didh = highlight_list_arg(id, didh, LIST_ATTR,
                            sgp->sg_gui, NULL, "gui");
  didh = highlight_list_arg(id, didh, LIST_STRING,
                            0, sgp->sg_rgb_fg_name, "guifg");
  didh = highlight_list_arg(id, didh, LIST_STRING,
                            0, sgp->sg_rgb_bg_name, "guibg");
  didh = highlight_list_arg(id, didh, LIST_STRING,
                            0, sgp->sg_rgb_sp_name, "guisp");

  didh = highlight_list_arg(id, didh, LIST_INT,
                            sgp->sg_blend + 1, NULL, "blend");

  if (sgp->sg_link && !got_int) {
    (void)syn_list_header(didh, 0, id, true);
    didh = true;
    msg_puts_attr("links to", HL_ATTR(HLF_D));
    msg_putchar(' ');
    msg_outtrans(HL_TABLE()[HL_TABLE()[id - 1].sg_link - 1].sg_name);
  }

  if (!didh) {
    highlight_list_arg(id, didh, LIST_STRING, 0, "cleared", "");
  }
  if (p_verbose > 0) {
    last_set_msg(sgp->sg_script_ctx);
  }
}

Dictionary get_global_hl_defs(void)
{
  Dictionary rv = ARRAY_DICT_INIT;
  for (int i = 1; i <= highlight_ga.ga_len && !got_int; i++) {
    Dictionary attrs = ARRAY_DICT_INIT;
    HlGroup *h = &HL_TABLE()[i - 1];
    if (h->sg_attr > 0) {
      attrs = hlattrs2dict(syn_attr2entry(h->sg_attr), true);
    } else if (h->sg_link > 0) {
      const char *link = (const char *)HL_TABLE()[h->sg_link - 1].sg_name;
      PUT(attrs, "link", STRING_OBJ(cstr_to_string(link)));
    }
    PUT(rv, (const char *)h->sg_name, DICTIONARY_OBJ(attrs));
  }

  return rv;
}

/// Outputs a highlight when doing ":hi MyHighlight"
///
/// @param type one of \ref LIST_XXX
/// @param iarg integer argument used if \p type == LIST_INT
/// @param sarg string used if \p type == LIST_STRING
static bool highlight_list_arg(const int id, bool didh, const int type, int iarg, char *const sarg,
                               const char *const name)
{
  char buf[100];

  if (got_int) {
    return false;
  }
  if (type == LIST_STRING ? (sarg != NULL) : (iarg != 0)) {
    char *ts = buf;
    if (type == LIST_INT) {
      snprintf((char *)buf, sizeof(buf), "%d", iarg - 1);
    } else if (type == LIST_STRING) {
      ts = sarg;
    } else {    // type == LIST_ATTR
      buf[0] = NUL;
      for (int i = 0; hl_attr_table[i] != 0; i++) {
        if (iarg & hl_attr_table[i]) {
          if (buf[0] != NUL) {
            xstrlcat(buf, ",", 100);
          }
          xstrlcat(buf, hl_name_table[i], 100);
          iarg &= ~hl_attr_table[i];                // don't want "inverse"
        }
      }
    }

    (void)syn_list_header(didh, vim_strsize((char_u *)ts) + (int)STRLEN(name) + 1, id, false);
    didh = true;
    if (!got_int) {
      if (*name != NUL) {
        msg_puts_attr(name, HL_ATTR(HLF_D));
        msg_puts_attr("=", HL_ATTR(HLF_D));
      }
      msg_outtrans((char_u *)ts);
    }
  }
  return didh;
}

/// Check whether highlight group has attribute
///
/// @param[in]  id  Highlight group to check.
/// @param[in]  flag  Attribute to check.
/// @param[in]  modec  'g' for GUI, 'c' for term.
///
/// @return "1" if highlight group has attribute, NULL otherwise.
const char *highlight_has_attr(const int id, const int flag, const int modec)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  int attr;

  if (id <= 0 || id > highlight_ga.ga_len) {
    return NULL;
  }

  if (modec == 'g') {
    attr = HL_TABLE()[id - 1].sg_gui;
  } else {
    attr = HL_TABLE()[id - 1].sg_cterm;
  }

  return (attr & flag) ? "1" : NULL;
}

/// Return color name of the given highlight group
///
/// @param[in]  id  Highlight group to work with.
/// @param[in]  what  What to return: one of "font", "fg", "bg", "sp", "fg#",
///                   "bg#" or "sp#".
/// @param[in]  modec  'g' for GUI, 'c' for cterm and 't' for term.
///
/// @return color name, possibly in a static buffer. Buffer will be overwritten
///         on next highlight_color() call. May return NULL.
const char *highlight_color(const int id, const char *const what, const int modec)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  static char name[20];
  int n;
  bool fg = false;
  bool sp = false;
  bool font = false;

  if (id <= 0 || id > highlight_ga.ga_len) {
    return NULL;
  }

  if (TOLOWER_ASC(what[0]) == 'f' && TOLOWER_ASC(what[1]) == 'g') {
    fg = true;
  } else if (TOLOWER_ASC(what[0]) == 'f' && TOLOWER_ASC(what[1]) == 'o'
             && TOLOWER_ASC(what[2]) == 'n' && TOLOWER_ASC(what[3]) == 't') {
    font = true;
  } else if (TOLOWER_ASC(what[0]) == 's' && TOLOWER_ASC(what[1]) == 'p') {
    sp = true;
  } else if (!(TOLOWER_ASC(what[0]) == 'b' && TOLOWER_ASC(what[1]) == 'g')) {
    return NULL;
  }
  if (modec == 'g') {
    if (what[2] == '#' && ui_rgb_attached()) {
      if (fg) {
        n = HL_TABLE()[id - 1].sg_rgb_fg;
      } else if (sp) {
        n = HL_TABLE()[id - 1].sg_rgb_sp;
      } else {
        n = HL_TABLE()[id - 1].sg_rgb_bg;
      }
      if (n < 0 || n > 0xffffff) {
        return NULL;
      }
      snprintf(name, sizeof(name), "#%06x", n);
      return name;
    }
    if (fg) {
      return (const char *)HL_TABLE()[id - 1].sg_rgb_fg_name;
    }
    if (sp) {
      return (const char *)HL_TABLE()[id - 1].sg_rgb_sp_name;
    }
    return (const char *)HL_TABLE()[id - 1].sg_rgb_bg_name;
  }
  if (font || sp) {
    return NULL;
  }
  if (modec == 'c') {
    if (fg) {
      n = HL_TABLE()[id - 1].sg_cterm_fg - 1;
    } else {
      n = HL_TABLE()[id - 1].sg_cterm_bg - 1;
    }
    if (n < 0) {
      return NULL;
    }
    snprintf(name, sizeof(name), "%d", n);
    return name;
  }
  // term doesn't have color.
  return NULL;
}

/// Output the syntax list header.
///
/// @param did_header did header already
/// @param outlen length of string that comes
/// @param id highlight group id
/// @param force_newline always start a new line
/// @return true when started a new line.
bool syn_list_header(const bool did_header, const int outlen, const int id, bool force_newline)
{
  int endcol = 19;
  bool newline = true;
  int name_col = 0;
  bool adjust = true;

  if (!did_header) {
    msg_putchar('\n');
    if (got_int) {
      return true;
    }
    msg_outtrans(HL_TABLE()[id - 1].sg_name);
    name_col = msg_col;
    endcol = 15;
  } else if ((ui_has(kUIMessages) || msg_silent) && !force_newline) {
    msg_putchar(' ');
    adjust = false;
  } else if (msg_col + outlen + 1 >= Columns || force_newline) {
    msg_putchar('\n');
    if (got_int) {
      return true;
    }
  } else {
    if (msg_col >= endcol) {    // wrap around is like starting a new line
      newline = false;
    }
  }

  if (adjust) {
    if (msg_col >= endcol) {
      // output at least one space
      endcol = msg_col + 1;
    }

    msg_advance(endcol);
  }

  // Show "xxx" with the attributes.
  if (!did_header) {
    if (endcol == Columns - 1 && endcol <= name_col) {
      msg_putchar(' ');
    }
    msg_puts_attr("xxx", syn_id2attr(id));
    msg_putchar(' ');
  }

  return newline;
}

/// Set the attribute numbers for a highlight group.
/// Called after one of the attributes has changed.
/// @param idx corrected highlight index
static void set_hl_attr(int idx)
{
  HlAttrs at_en = HLATTRS_INIT;
  HlGroup *sgp = HL_TABLE() + idx;

  at_en.cterm_ae_attr = (int16_t)sgp->sg_cterm;
  at_en.cterm_fg_color = sgp->sg_cterm_fg;
  at_en.cterm_bg_color = sgp->sg_cterm_bg;
  at_en.rgb_ae_attr = (int16_t)sgp->sg_gui;
  // FIXME(tarruda): The "unset value" for rgb is -1, but since hlgroup is
  // initialized with 0(by garray functions), check for sg_rgb_{f,b}g_name
  // before setting attr_entry->{f,g}g_color to a other than -1
  at_en.rgb_fg_color = sgp->sg_rgb_fg_name ? sgp->sg_rgb_fg : -1;
  at_en.rgb_bg_color = sgp->sg_rgb_bg_name ? sgp->sg_rgb_bg : -1;
  at_en.rgb_sp_color = sgp->sg_rgb_sp_name ? sgp->sg_rgb_sp : -1;
  at_en.hl_blend = sgp->sg_blend;

  sgp->sg_attr = hl_get_syn_attr(0, idx + 1, at_en);

  // a cursor style uses this syn_id, make sure its attribute is updated.
  if (cursor_mode_uses_syn_id(idx + 1)) {
    ui_mode_info_set();
  }
}

int syn_name2id(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  return syn_name2id_len((char_u *)name, STRLEN(name));
}

/// Lookup a highlight group name and return its ID.
///
/// @param highlight name e.g. 'Cursor', 'Normal'
/// @return the highlight id, else 0 if \p name does not exist
int syn_name2id_len(const char_u *name, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  char name_u[MAX_SYN_NAME + 1];

  if (len == 0 || len > MAX_SYN_NAME) {
    return 0;
  }

  // Avoid using stricmp() too much, it's slow on some systems */
  // Avoid alloc()/free(), these are slow too.
  memcpy(name_u, name, len);
  name_u[len] = '\0';
  vim_strup((char_u *)name_u);

  // map_get(..., int) returns 0 when no key is present, which is
  // the expected value for missing highlight group.
  return map_get(cstr_t, int)(&highlight_unames, name_u);
}

/// Lookup a highlight group name and return its attributes.
/// Return zero if not found.
int syn_name2attr(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  int id = syn_name2id((char *)name);

  if (id != 0) {
    return syn_id2attr(id);
  }
  return 0;
}

/// Return TRUE if highlight group "name" exists.
int highlight_exists(const char *name)
{
  return syn_name2id(name) > 0;
}

/// Return the name of highlight group "id".
/// When not a valid ID return an empty string.
char_u *syn_id2name(int id)
{
  if (id <= 0 || id > highlight_ga.ga_len) {
    return (char_u *)"";
  }
  return HL_TABLE()[id - 1].sg_name;
}

/// Find highlight group name in the table and return its ID.
/// If it doesn't exist yet, a new entry is created.
///
/// @param pp Highlight group name
/// @param len length of \p pp
///
/// @return 0 for failure else the id of the group
int syn_check_group(const char *name, size_t len)
{
  if (len > MAX_SYN_NAME) {
    emsg(_(e_highlight_group_name_too_long));
    return 0;
  }
  int id = syn_name2id_len((char_u *)name, len);
  if (id == 0) {  // doesn't exist yet
    return syn_add_group(vim_strnsave((char_u *)name, len));
  }
  return id;
}

/// Add new highlight group and return its ID.
///
/// @param name must be an allocated string, it will be consumed.
/// @return 0 for failure, else the allocated group id
/// @see syn_check_group syn_unadd_group
static int syn_add_group(char_u *name)
{
  char_u *p;

  // Check that the name is ASCII letters, digits and underscore.
  for (p = name; *p != NUL; p++) {
    if (!vim_isprintc(*p)) {
      emsg(_("E669: Unprintable character in group name"));
      xfree(name);
      return 0;
    } else if (!ASCII_ISALNUM(*p) && *p != '_') {
      // This is an error, but since there previously was no check only give a warning.
      msg_source(HL_ATTR(HLF_W));
      msg(_("W18: Invalid character in group name"));
      break;
    }
  }

  // First call for this growarray: init growing array.
  if (highlight_ga.ga_data == NULL) {
    highlight_ga.ga_itemsize = sizeof(HlGroup);
    ga_set_growsize(&highlight_ga, 10);
  }

  if (highlight_ga.ga_len >= MAX_HL_ID) {
    emsg(_("E849: Too many highlight and syntax groups"));
    xfree(name);
    return 0;
  }

  char *const name_up = (char *)vim_strsave_up(name);

  // Append another syntax_highlight entry.
  HlGroup *hlgp = GA_APPEND_VIA_PTR(HlGroup, &highlight_ga);
  memset(hlgp, 0, sizeof(*hlgp));
  hlgp->sg_name = name;
  hlgp->sg_rgb_bg = -1;
  hlgp->sg_rgb_fg = -1;
  hlgp->sg_rgb_sp = -1;
  hlgp->sg_blend = -1;
  hlgp->sg_name_u = name_up;

  int id = highlight_ga.ga_len;  // ID is index plus one

  map_put(cstr_t, int)(&highlight_unames, name_up, id);

  return id;
}

/// When, just after calling syn_add_group(), an error is discovered, this
/// function deletes the new name.
static void syn_unadd_group(void)
{
  highlight_ga.ga_len--;
  HlGroup *item = &HL_TABLE()[highlight_ga.ga_len];
  map_del(cstr_t, int)(&highlight_unames, item->sg_name_u);
  xfree(item->sg_name);
  xfree(item->sg_name_u);
}

/// Translate a group ID to highlight attributes.
/// @see syn_attr2entry
int syn_id2attr(int hl_id)
{
  hl_id = syn_get_final_id(hl_id);
  HlGroup *sgp = &HL_TABLE()[hl_id - 1];  // index is ID minus one

  int attr = ns_get_hl(-1, hl_id, false, sgp->sg_set);
  if (attr >= 0) {
    return attr;
  }
  return sgp->sg_attr;
}

/// Translate a group ID to the final group ID (following links).
int syn_get_final_id(int hl_id)
{
  int count;

  if (hl_id > highlight_ga.ga_len || hl_id < 1) {
    return 0;                           // Can be called from eval!!
  }

  // Follow links until there is no more.
  // Look out for loops!  Break after 100 links.
  for (count = 100; --count >= 0;) {
    HlGroup *sgp = &HL_TABLE()[hl_id - 1];  // index is ID minus one

    // ACHTUNG: when using "tmp" attribute (no link) the function might be
    // called twice. it needs be smart enough to remember attr only to
    // syn_id2attr time
    int check = ns_get_hl(-1, hl_id, true, sgp->sg_set);
    if (check == 0) {
      return hl_id;  // how dare! it broke the link!
    } else if (check > 0) {
      hl_id = check;
      continue;
    }

    if (sgp->sg_link == 0 || sgp->sg_link > highlight_ga.ga_len) {
      break;
    }
    hl_id = sgp->sg_link;
  }

  return hl_id;
}

/// Refresh the color attributes of all highlight groups.
void highlight_attr_set_all(void)
{
  for (int idx = 0; idx < highlight_ga.ga_len; idx++) {
    HlGroup *sgp = &HL_TABLE()[idx];
    if (sgp->sg_rgb_bg_name != NULL) {
      sgp->sg_rgb_bg = name_to_color(sgp->sg_rgb_bg_name);
    }
    if (sgp->sg_rgb_fg_name != NULL) {
      sgp->sg_rgb_fg = name_to_color(sgp->sg_rgb_fg_name);
    }
    if (sgp->sg_rgb_sp_name != NULL) {
      sgp->sg_rgb_sp = name_to_color(sgp->sg_rgb_sp_name);
    }
    set_hl_attr(idx);
  }
}

// Apply difference between User[1-9] and HLF_S to HLF_SNC.
static void combine_stl_hlt(int id, int id_S, int id_alt, int hlcnt, int i, int hlf, int *table)
  FUNC_ATTR_NONNULL_ALL
{
  HlGroup *const hlt = HL_TABLE();

  if (id_alt == 0) {
    memset(&hlt[hlcnt + i], 0, sizeof(HlGroup));
    hlt[hlcnt + i].sg_cterm = highlight_attr[hlf];
    hlt[hlcnt + i].sg_gui = highlight_attr[hlf];
  } else {
    memmove(&hlt[hlcnt + i], &hlt[id_alt - 1], sizeof(HlGroup));
  }
  hlt[hlcnt + i].sg_link = 0;

  hlt[hlcnt + i].sg_cterm ^= hlt[id - 1].sg_cterm ^ hlt[id_S - 1].sg_cterm;
  if (hlt[id - 1].sg_cterm_fg != hlt[id_S - 1].sg_cterm_fg) {
    hlt[hlcnt + i].sg_cterm_fg = hlt[id - 1].sg_cterm_fg;
  }
  if (hlt[id - 1].sg_cterm_bg != hlt[id_S - 1].sg_cterm_bg) {
    hlt[hlcnt + i].sg_cterm_bg = hlt[id - 1].sg_cterm_bg;
  }
  hlt[hlcnt + i].sg_gui ^= hlt[id - 1].sg_gui ^ hlt[id_S - 1].sg_gui;
  if (hlt[id - 1].sg_rgb_fg != hlt[id_S - 1].sg_rgb_fg) {
    hlt[hlcnt + i].sg_rgb_fg = hlt[id - 1].sg_rgb_fg;
  }
  if (hlt[id - 1].sg_rgb_bg != hlt[id_S - 1].sg_rgb_bg) {
    hlt[hlcnt + i].sg_rgb_bg = hlt[id - 1].sg_rgb_bg;
  }
  if (hlt[id - 1].sg_rgb_sp != hlt[id_S - 1].sg_rgb_sp) {
    hlt[hlcnt + i].sg_rgb_sp = hlt[id - 1].sg_rgb_sp;
  }
  highlight_ga.ga_len = hlcnt + i + 1;
  set_hl_attr(hlcnt + i);  // At long last we can apply
  table[i] = syn_id2attr(hlcnt + i + 1);
}

/// Translate highlight groups into attributes in highlight_attr[] and set up
/// the user highlights User1..9. A set of corresponding highlights to use on
/// top of HLF_SNC is computed.  Called only when nvim starts and upon first
/// screen redraw after any :highlight command.
void highlight_changed(void)
{
  int id;
  char userhl[30];  // use 30 to avoid compiler warning
  int id_S = -1;
  int id_SNC = 0;
  int hlcnt;

  need_highlight_changed = false;

  /// Translate builtin highlight groups into attributes for quick lookup.
  for (int hlf = 0; hlf < HLF_COUNT; hlf++) {
    id = syn_check_group(hlf_names[hlf], STRLEN(hlf_names[hlf]));
    if (id == 0) {
      abort();
    }
    int final_id = syn_get_final_id(id);
    if (hlf == HLF_SNC) {
      id_SNC = final_id;
    } else if (hlf == HLF_S) {
      id_S = final_id;
    }

    highlight_attr[hlf] = hl_get_ui_attr(hlf, final_id,
                                         (hlf == HLF_INACTIVE || hlf == HLF_LC));

    if (highlight_attr[hlf] != highlight_attr_last[hlf]) {
      if (hlf == HLF_MSG) {
        clear_cmdline = true;
      }
      ui_call_hl_group_set(cstr_as_string((char *)hlf_names[hlf]),
                           highlight_attr[hlf]);
      highlight_attr_last[hlf] = highlight_attr[hlf];
    }
  }

  //
  // Setup the user highlights
  //
  // Temporarily utilize 10 more hl entries:
  // 9 for User1-User9 combined with StatusLineNC
  // 1 for StatusLine default
  // Must to be in there simultaneously in case of table overflows in
  // get_attr_entry()
  ga_grow(&highlight_ga, 10);
  hlcnt = highlight_ga.ga_len;
  if (id_S == -1) {
    // Make sure id_S is always valid to simplify code below. Use the last entry
    memset(&HL_TABLE()[hlcnt + 9], 0, sizeof(HlGroup));
    id_S = hlcnt + 10;
  }
  for (int i = 0; i < 9; i++) {
    snprintf(userhl, sizeof(userhl), "User%d", i + 1);
    id = syn_name2id(userhl);
    if (id == 0) {
      highlight_user[i] = 0;
      highlight_stlnc[i] = 0;
    } else {
      highlight_user[i] = syn_id2attr(id);
      combine_stl_hlt(id, id_S, id_SNC, hlcnt, i, HLF_SNC, highlight_stlnc);
    }
  }
  highlight_ga.ga_len = hlcnt;
}

/// Handle command line completion for :highlight command.
void set_context_in_highlight_cmd(expand_T *xp, const char *arg)
{
  // Default: expand group names.
  xp->xp_context = EXPAND_HIGHLIGHT;
  xp->xp_pattern = (char *)arg;
  include_link = 2;
  include_default = 1;

  // (part of) subcommand already typed
  if (*arg != NUL) {
    const char *p = (const char *)skiptowhite((const char_u *)arg);
    if (*p != NUL) {  // Past "default" or group name.
      include_default = 0;
      if (strncmp("default", arg, (unsigned)(p - arg)) == 0) {
        arg = (const char *)skipwhite(p);
        xp->xp_pattern = (char *)arg;
        p = (const char *)skiptowhite((const char_u *)arg);
      }
      if (*p != NUL) {                          // past group name
        include_link = 0;
        if (arg[1] == 'i' && arg[0] == 'N') {
          highlight_list();
        }
        if (strncmp("link", arg, (unsigned)(p - arg)) == 0
            || strncmp("clear", arg, (unsigned)(p - arg)) == 0) {
          xp->xp_pattern = skipwhite(p);
          p = (const char *)skiptowhite((char_u *)xp->xp_pattern);
          if (*p != NUL) {  // Past first group name.
            xp->xp_pattern = skipwhite(p);
            p = (const char *)skiptowhite((char_u *)xp->xp_pattern);
          }
        }
        if (*p != NUL) {  // Past group name(s).
          xp->xp_context = EXPAND_NOTHING;
        }
      }
    }
  }
}

/// List highlighting matches in a nice way.
static void highlight_list(void)
{
  int i;

  for (i = 10; --i >= 0;) {
    highlight_list_two(i, HL_ATTR(HLF_D));
  }
  for (i = 40; --i >= 0;) {
    highlight_list_two(99, 0);
  }
}

static void highlight_list_two(int cnt, int attr)
{
  msg_puts_attr(&("N \bI \b!  \b"[cnt / 11]), attr);
  msg_clr_eos();
  ui_flush();
  os_delay(cnt == 99 ? 40L : (uint64_t)cnt * 50L, false);
}

/// Function given to ExpandGeneric() to obtain the list of group names.
const char *get_highlight_name(expand_T *const xp, int idx)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return get_highlight_name_ext(xp, idx, true);
}

/// Obtain a highlight group name.
///
/// @param skip_cleared  if true don't return a cleared entry.
const char *get_highlight_name_ext(expand_T *xp, int idx, bool skip_cleared)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (idx < 0) {
    return NULL;
  }

  // Items are never removed from the table, skip the ones that were cleared.
  if (skip_cleared && idx < highlight_ga.ga_len && HL_TABLE()[idx].sg_cleared) {
    return "";
  }

  if (idx == highlight_ga.ga_len && include_none != 0) {
    return "none";
  } else if (idx == highlight_ga.ga_len + include_none
             && include_default != 0) {
    return "default";
  } else if (idx == highlight_ga.ga_len + include_none + include_default
             && include_link != 0) {
    return "link";
  } else if (idx == highlight_ga.ga_len + include_none + include_default + 1
             && include_link != 0) {
    return "clear";
  } else if (idx >= highlight_ga.ga_len) {
    return NULL;
  }
  return (const char *)HL_TABLE()[idx].sg_name;
}

color_name_table_T color_name_table[] = {
  // Colors from rgb.txt
  { "AliceBlue", RGB_(0xf0, 0xf8, 0xff) },
  { "AntiqueWhite", RGB_(0xfa, 0xeb, 0xd7) },
  { "AntiqueWhite1", RGB_(0xff, 0xef, 0xdb) },
  { "AntiqueWhite2", RGB_(0xee, 0xdf, 0xcc) },
  { "AntiqueWhite3", RGB_(0xcd, 0xc0, 0xb0) },
  { "AntiqueWhite4", RGB_(0x8b, 0x83, 0x78) },
  { "Aqua", RGB_(0x00, 0xff, 0xff) },
  { "Aquamarine", RGB_(0x7f, 0xff, 0xd4) },
  { "Aquamarine1", RGB_(0x7f, 0xff, 0xd4) },
  { "Aquamarine2", RGB_(0x76, 0xee, 0xc6) },
  { "Aquamarine3", RGB_(0x66, 0xcd, 0xaa) },
  { "Aquamarine4", RGB_(0x45, 0x8b, 0x74) },
  { "Azure", RGB_(0xf0, 0xff, 0xff) },
  { "Azure1", RGB_(0xf0, 0xff, 0xff) },
  { "Azure2", RGB_(0xe0, 0xee, 0xee) },
  { "Azure3", RGB_(0xc1, 0xcd, 0xcd) },
  { "Azure4", RGB_(0x83, 0x8b, 0x8b) },
  { "Beige", RGB_(0xf5, 0xf5, 0xdc) },
  { "Bisque", RGB_(0xff, 0xe4, 0xc4) },
  { "Bisque1", RGB_(0xff, 0xe4, 0xc4) },
  { "Bisque2", RGB_(0xee, 0xd5, 0xb7) },
  { "Bisque3", RGB_(0xcd, 0xb7, 0x9e) },
  { "Bisque4", RGB_(0x8b, 0x7d, 0x6b) },
  { "Black", RGB_(0x00, 0x00, 0x00) },
  { "BlanchedAlmond", RGB_(0xff, 0xeb, 0xcd) },
  { "Blue", RGB_(0x00, 0x00, 0xff) },
  { "Blue1", RGB_(0x0, 0x0, 0xff) },
  { "Blue2", RGB_(0x0, 0x0, 0xee) },
  { "Blue3", RGB_(0x0, 0x0, 0xcd) },
  { "Blue4", RGB_(0x0, 0x0, 0x8b) },
  { "BlueViolet", RGB_(0x8a, 0x2b, 0xe2) },
  { "Brown", RGB_(0xa5, 0x2a, 0x2a) },
  { "Brown1", RGB_(0xff, 0x40, 0x40) },
  { "Brown2", RGB_(0xee, 0x3b, 0x3b) },
  { "Brown3", RGB_(0xcd, 0x33, 0x33) },
  { "Brown4", RGB_(0x8b, 0x23, 0x23) },
  { "BurlyWood", RGB_(0xde, 0xb8, 0x87) },
  { "Burlywood1", RGB_(0xff, 0xd3, 0x9b) },
  { "Burlywood2", RGB_(0xee, 0xc5, 0x91) },
  { "Burlywood3", RGB_(0xcd, 0xaa, 0x7d) },
  { "Burlywood4", RGB_(0x8b, 0x73, 0x55) },
  { "CadetBlue", RGB_(0x5f, 0x9e, 0xa0) },
  { "CadetBlue1", RGB_(0x98, 0xf5, 0xff) },
  { "CadetBlue2", RGB_(0x8e, 0xe5, 0xee) },
  { "CadetBlue3", RGB_(0x7a, 0xc5, 0xcd) },
  { "CadetBlue4", RGB_(0x53, 0x86, 0x8b) },
  { "ChartReuse", RGB_(0x7f, 0xff, 0x00) },
  { "Chartreuse1", RGB_(0x7f, 0xff, 0x0) },
  { "Chartreuse2", RGB_(0x76, 0xee, 0x0) },
  { "Chartreuse3", RGB_(0x66, 0xcd, 0x0) },
  { "Chartreuse4", RGB_(0x45, 0x8b, 0x0) },
  { "Chocolate", RGB_(0xd2, 0x69, 0x1e) },
  { "Chocolate1", RGB_(0xff, 0x7f, 0x24) },
  { "Chocolate2", RGB_(0xee, 0x76, 0x21) },
  { "Chocolate3", RGB_(0xcd, 0x66, 0x1d) },
  { "Chocolate4", RGB_(0x8b, 0x45, 0x13) },
  { "Coral", RGB_(0xff, 0x7f, 0x50) },
  { "Coral1", RGB_(0xff, 0x72, 0x56) },
  { "Coral2", RGB_(0xee, 0x6a, 0x50) },
  { "Coral3", RGB_(0xcd, 0x5b, 0x45) },
  { "Coral4", RGB_(0x8b, 0x3e, 0x2f) },
  { "CornFlowerBlue", RGB_(0x64, 0x95, 0xed) },
  { "Cornsilk", RGB_(0xff, 0xf8, 0xdc) },
  { "Cornsilk1", RGB_(0xff, 0xf8, 0xdc) },
  { "Cornsilk2", RGB_(0xee, 0xe8, 0xcd) },
  { "Cornsilk3", RGB_(0xcd, 0xc8, 0xb1) },
  { "Cornsilk4", RGB_(0x8b, 0x88, 0x78) },
  { "Crimson", RGB_(0xdc, 0x14, 0x3c) },
  { "Cyan", RGB_(0x00, 0xff, 0xff) },
  { "Cyan1", RGB_(0x0, 0xff, 0xff) },
  { "Cyan2", RGB_(0x0, 0xee, 0xee) },
  { "Cyan3", RGB_(0x0, 0xcd, 0xcd) },
  { "Cyan4", RGB_(0x0, 0x8b, 0x8b) },
  { "DarkBlue", RGB_(0x00, 0x00, 0x8b) },
  { "DarkCyan", RGB_(0x00, 0x8b, 0x8b) },
  { "DarkGoldenRod", RGB_(0xb8, 0x86, 0x0b) },
  { "DarkGoldenrod1", RGB_(0xff, 0xb9, 0xf) },
  { "DarkGoldenrod2", RGB_(0xee, 0xad, 0xe) },
  { "DarkGoldenrod3", RGB_(0xcd, 0x95, 0xc) },
  { "DarkGoldenrod4", RGB_(0x8b, 0x65, 0x8) },
  { "DarkGray", RGB_(0xa9, 0xa9, 0xa9) },
  { "DarkGreen", RGB_(0x00, 0x64, 0x00) },
  { "DarkGrey", RGB_(0xa9, 0xa9, 0xa9) },
  { "DarkKhaki", RGB_(0xbd, 0xb7, 0x6b) },
  { "DarkMagenta", RGB_(0x8b, 0x00, 0x8b) },
  { "DarkOliveGreen", RGB_(0x55, 0x6b, 0x2f) },
  { "DarkOliveGreen1", RGB_(0xca, 0xff, 0x70) },
  { "DarkOliveGreen2", RGB_(0xbc, 0xee, 0x68) },
  { "DarkOliveGreen3", RGB_(0xa2, 0xcd, 0x5a) },
  { "DarkOliveGreen4", RGB_(0x6e, 0x8b, 0x3d) },
  { "DarkOrange", RGB_(0xff, 0x8c, 0x00) },
  { "DarkOrange1", RGB_(0xff, 0x7f, 0x0) },
  { "DarkOrange2", RGB_(0xee, 0x76, 0x0) },
  { "DarkOrange3", RGB_(0xcd, 0x66, 0x0) },
  { "DarkOrange4", RGB_(0x8b, 0x45, 0x0) },
  { "DarkOrchid", RGB_(0x99, 0x32, 0xcc) },
  { "DarkOrchid1", RGB_(0xbf, 0x3e, 0xff) },
  { "DarkOrchid2", RGB_(0xb2, 0x3a, 0xee) },
  { "DarkOrchid3", RGB_(0x9a, 0x32, 0xcd) },
  { "DarkOrchid4", RGB_(0x68, 0x22, 0x8b) },
  { "DarkRed", RGB_(0x8b, 0x00, 0x00) },
  { "DarkSalmon", RGB_(0xe9, 0x96, 0x7a) },
  { "DarkSeaGreen", RGB_(0x8f, 0xbc, 0x8f) },
  { "DarkSeaGreen1", RGB_(0xc1, 0xff, 0xc1) },
  { "DarkSeaGreen2", RGB_(0xb4, 0xee, 0xb4) },
  { "DarkSeaGreen3", RGB_(0x9b, 0xcd, 0x9b) },
  { "DarkSeaGreen4", RGB_(0x69, 0x8b, 0x69) },
  { "DarkSlateBlue", RGB_(0x48, 0x3d, 0x8b) },
  { "DarkSlateGray", RGB_(0x2f, 0x4f, 0x4f) },
  { "DarkSlateGray1", RGB_(0x97, 0xff, 0xff) },
  { "DarkSlateGray2", RGB_(0x8d, 0xee, 0xee) },
  { "DarkSlateGray3", RGB_(0x79, 0xcd, 0xcd) },
  { "DarkSlateGray4", RGB_(0x52, 0x8b, 0x8b) },
  { "DarkSlateGrey", RGB_(0x2f, 0x4f, 0x4f) },
  { "DarkTurquoise", RGB_(0x00, 0xce, 0xd1) },
  { "DarkViolet", RGB_(0x94, 0x00, 0xd3) },
  { "DarkYellow", RGB_(0xbb, 0xbb, 0x00) },
  { "DeepPink", RGB_(0xff, 0x14, 0x93) },
  { "DeepPink1", RGB_(0xff, 0x14, 0x93) },
  { "DeepPink2", RGB_(0xee, 0x12, 0x89) },
  { "DeepPink3", RGB_(0xcd, 0x10, 0x76) },
  { "DeepPink4", RGB_(0x8b, 0xa, 0x50) },
  { "DeepSkyBlue", RGB_(0x00, 0xbf, 0xff) },
  { "DeepSkyBlue1", RGB_(0x0, 0xbf, 0xff) },
  { "DeepSkyBlue2", RGB_(0x0, 0xb2, 0xee) },
  { "DeepSkyBlue3", RGB_(0x0, 0x9a, 0xcd) },
  { "DeepSkyBlue4", RGB_(0x0, 0x68, 0x8b) },
  { "DimGray", RGB_(0x69, 0x69, 0x69) },
  { "DimGrey", RGB_(0x69, 0x69, 0x69) },
  { "DodgerBlue", RGB_(0x1e, 0x90, 0xff) },
  { "DodgerBlue1", RGB_(0x1e, 0x90, 0xff) },
  { "DodgerBlue2", RGB_(0x1c, 0x86, 0xee) },
  { "DodgerBlue3", RGB_(0x18, 0x74, 0xcd) },
  { "DodgerBlue4", RGB_(0x10, 0x4e, 0x8b) },
  { "Firebrick", RGB_(0xb2, 0x22, 0x22) },
  { "Firebrick1", RGB_(0xff, 0x30, 0x30) },
  { "Firebrick2", RGB_(0xee, 0x2c, 0x2c) },
  { "Firebrick3", RGB_(0xcd, 0x26, 0x26) },
  { "Firebrick4", RGB_(0x8b, 0x1a, 0x1a) },
  { "FloralWhite", RGB_(0xff, 0xfa, 0xf0) },
  { "ForestGreen", RGB_(0x22, 0x8b, 0x22) },
  { "Fuchsia", RGB_(0xff, 0x00, 0xff) },
  { "Gainsboro", RGB_(0xdc, 0xdc, 0xdc) },
  { "GhostWhite", RGB_(0xf8, 0xf8, 0xff) },
  { "Gold", RGB_(0xff, 0xd7, 0x00) },
  { "Gold1", RGB_(0xff, 0xd7, 0x0) },
  { "Gold2", RGB_(0xee, 0xc9, 0x0) },
  { "Gold3", RGB_(0xcd, 0xad, 0x0) },
  { "Gold4", RGB_(0x8b, 0x75, 0x0) },
  { "GoldenRod", RGB_(0xda, 0xa5, 0x20) },
  { "Goldenrod1", RGB_(0xff, 0xc1, 0x25) },
  { "Goldenrod2", RGB_(0xee, 0xb4, 0x22) },
  { "Goldenrod3", RGB_(0xcd, 0x9b, 0x1d) },
  { "Goldenrod4", RGB_(0x8b, 0x69, 0x14) },
  { "Gray", RGB_(0x80, 0x80, 0x80) },
  { "Gray0", RGB_(0x0, 0x0, 0x0) },
  { "Gray1", RGB_(0x3, 0x3, 0x3) },
  { "Gray10", RGB_(0x1a, 0x1a, 0x1a) },
  { "Gray100", RGB_(0xff, 0xff, 0xff) },
  { "Gray11", RGB_(0x1c, 0x1c, 0x1c) },
  { "Gray12", RGB_(0x1f, 0x1f, 0x1f) },
  { "Gray13", RGB_(0x21, 0x21, 0x21) },
  { "Gray14", RGB_(0x24, 0x24, 0x24) },
  { "Gray15", RGB_(0x26, 0x26, 0x26) },
  { "Gray16", RGB_(0x29, 0x29, 0x29) },
  { "Gray17", RGB_(0x2b, 0x2b, 0x2b) },
  { "Gray18", RGB_(0x2e, 0x2e, 0x2e) },
  { "Gray19", RGB_(0x30, 0x30, 0x30) },
  { "Gray2", RGB_(0x5, 0x5, 0x5) },
  { "Gray20", RGB_(0x33, 0x33, 0x33) },
  { "Gray21", RGB_(0x36, 0x36, 0x36) },
  { "Gray22", RGB_(0x38, 0x38, 0x38) },
  { "Gray23", RGB_(0x3b, 0x3b, 0x3b) },
  { "Gray24", RGB_(0x3d, 0x3d, 0x3d) },
  { "Gray25", RGB_(0x40, 0x40, 0x40) },
  { "Gray26", RGB_(0x42, 0x42, 0x42) },
  { "Gray27", RGB_(0x45, 0x45, 0x45) },
  { "Gray28", RGB_(0x47, 0x47, 0x47) },
  { "Gray29", RGB_(0x4a, 0x4a, 0x4a) },
  { "Gray3", RGB_(0x8, 0x8, 0x8) },
  { "Gray30", RGB_(0x4d, 0x4d, 0x4d) },
  { "Gray31", RGB_(0x4f, 0x4f, 0x4f) },
  { "Gray32", RGB_(0x52, 0x52, 0x52) },
  { "Gray33", RGB_(0x54, 0x54, 0x54) },
  { "Gray34", RGB_(0x57, 0x57, 0x57) },
  { "Gray35", RGB_(0x59, 0x59, 0x59) },
  { "Gray36", RGB_(0x5c, 0x5c, 0x5c) },
  { "Gray37", RGB_(0x5e, 0x5e, 0x5e) },
  { "Gray38", RGB_(0x61, 0x61, 0x61) },
  { "Gray39", RGB_(0x63, 0x63, 0x63) },
  { "Gray4", RGB_(0xa, 0xa, 0xa) },
  { "Gray40", RGB_(0x66, 0x66, 0x66) },
  { "Gray41", RGB_(0x69, 0x69, 0x69) },
  { "Gray42", RGB_(0x6b, 0x6b, 0x6b) },
  { "Gray43", RGB_(0x6e, 0x6e, 0x6e) },
  { "Gray44", RGB_(0x70, 0x70, 0x70) },
  { "Gray45", RGB_(0x73, 0x73, 0x73) },
  { "Gray46", RGB_(0x75, 0x75, 0x75) },
  { "Gray47", RGB_(0x78, 0x78, 0x78) },
  { "Gray48", RGB_(0x7a, 0x7a, 0x7a) },
  { "Gray49", RGB_(0x7d, 0x7d, 0x7d) },
  { "Gray5", RGB_(0xd, 0xd, 0xd) },
  { "Gray50", RGB_(0x7f, 0x7f, 0x7f) },
  { "Gray51", RGB_(0x82, 0x82, 0x82) },
  { "Gray52", RGB_(0x85, 0x85, 0x85) },
  { "Gray53", RGB_(0x87, 0x87, 0x87) },
  { "Gray54", RGB_(0x8a, 0x8a, 0x8a) },
  { "Gray55", RGB_(0x8c, 0x8c, 0x8c) },
  { "Gray56", RGB_(0x8f, 0x8f, 0x8f) },
  { "Gray57", RGB_(0x91, 0x91, 0x91) },
  { "Gray58", RGB_(0x94, 0x94, 0x94) },
  { "Gray59", RGB_(0x96, 0x96, 0x96) },
  { "Gray6", RGB_(0xf, 0xf, 0xf) },
  { "Gray60", RGB_(0x99, 0x99, 0x99) },
  { "Gray61", RGB_(0x9c, 0x9c, 0x9c) },
  { "Gray62", RGB_(0x9e, 0x9e, 0x9e) },
  { "Gray63", RGB_(0xa1, 0xa1, 0xa1) },
  { "Gray64", RGB_(0xa3, 0xa3, 0xa3) },
  { "Gray65", RGB_(0xa6, 0xa6, 0xa6) },
  { "Gray66", RGB_(0xa8, 0xa8, 0xa8) },
  { "Gray67", RGB_(0xab, 0xab, 0xab) },
  { "Gray68", RGB_(0xad, 0xad, 0xad) },
  { "Gray69", RGB_(0xb0, 0xb0, 0xb0) },
  { "Gray7", RGB_(0x12, 0x12, 0x12) },
  { "Gray70", RGB_(0xb3, 0xb3, 0xb3) },
  { "Gray71", RGB_(0xb5, 0xb5, 0xb5) },
  { "Gray72", RGB_(0xb8, 0xb8, 0xb8) },
  { "Gray73", RGB_(0xba, 0xba, 0xba) },
  { "Gray74", RGB_(0xbd, 0xbd, 0xbd) },
  { "Gray75", RGB_(0xbf, 0xbf, 0xbf) },
  { "Gray76", RGB_(0xc2, 0xc2, 0xc2) },
  { "Gray77", RGB_(0xc4, 0xc4, 0xc4) },
  { "Gray78", RGB_(0xc7, 0xc7, 0xc7) },
  { "Gray79", RGB_(0xc9, 0xc9, 0xc9) },
  { "Gray8", RGB_(0x14, 0x14, 0x14) },
  { "Gray80", RGB_(0xcc, 0xcc, 0xcc) },
  { "Gray81", RGB_(0xcf, 0xcf, 0xcf) },
  { "Gray82", RGB_(0xd1, 0xd1, 0xd1) },
  { "Gray83", RGB_(0xd4, 0xd4, 0xd4) },
  { "Gray84", RGB_(0xd6, 0xd6, 0xd6) },
  { "Gray85", RGB_(0xd9, 0xd9, 0xd9) },
  { "Gray86", RGB_(0xdb, 0xdb, 0xdb) },
  { "Gray87", RGB_(0xde, 0xde, 0xde) },
  { "Gray88", RGB_(0xe0, 0xe0, 0xe0) },
  { "Gray89", RGB_(0xe3, 0xe3, 0xe3) },
  { "Gray9", RGB_(0x17, 0x17, 0x17) },
  { "Gray90", RGB_(0xe5, 0xe5, 0xe5) },
  { "Gray91", RGB_(0xe8, 0xe8, 0xe8) },
  { "Gray92", RGB_(0xeb, 0xeb, 0xeb) },
  { "Gray93", RGB_(0xed, 0xed, 0xed) },
  { "Gray94", RGB_(0xf0, 0xf0, 0xf0) },
  { "Gray95", RGB_(0xf2, 0xf2, 0xf2) },
  { "Gray96", RGB_(0xf5, 0xf5, 0xf5) },
  { "Gray97", RGB_(0xf7, 0xf7, 0xf7) },
  { "Gray98", RGB_(0xfa, 0xfa, 0xfa) },
  { "Gray99", RGB_(0xfc, 0xfc, 0xfc) },
  { "Green", RGB_(0x00, 0x80, 0x00) },
  { "Green1", RGB_(0x0, 0xff, 0x0) },
  { "Green2", RGB_(0x0, 0xee, 0x0) },
  { "Green3", RGB_(0x0, 0xcd, 0x0) },
  { "Green4", RGB_(0x0, 0x8b, 0x0) },
  { "GreenYellow", RGB_(0xad, 0xff, 0x2f) },
  { "Grey", RGB_(0x80, 0x80, 0x80) },
  { "Grey0", RGB_(0x0, 0x0, 0x0) },
  { "Grey1", RGB_(0x3, 0x3, 0x3) },
  { "Grey10", RGB_(0x1a, 0x1a, 0x1a) },
  { "Grey100", RGB_(0xff, 0xff, 0xff) },
  { "Grey11", RGB_(0x1c, 0x1c, 0x1c) },
  { "Grey12", RGB_(0x1f, 0x1f, 0x1f) },
  { "Grey13", RGB_(0x21, 0x21, 0x21) },
  { "Grey14", RGB_(0x24, 0x24, 0x24) },
  { "Grey15", RGB_(0x26, 0x26, 0x26) },
  { "Grey16", RGB_(0x29, 0x29, 0x29) },
  { "Grey17", RGB_(0x2b, 0x2b, 0x2b) },
  { "Grey18", RGB_(0x2e, 0x2e, 0x2e) },
  { "Grey19", RGB_(0x30, 0x30, 0x30) },
  { "Grey2", RGB_(0x5, 0x5, 0x5) },
  { "Grey20", RGB_(0x33, 0x33, 0x33) },
  { "Grey21", RGB_(0x36, 0x36, 0x36) },
  { "Grey22", RGB_(0x38, 0x38, 0x38) },
  { "Grey23", RGB_(0x3b, 0x3b, 0x3b) },
  { "Grey24", RGB_(0x3d, 0x3d, 0x3d) },
  { "Grey25", RGB_(0x40, 0x40, 0x40) },
  { "Grey26", RGB_(0x42, 0x42, 0x42) },
  { "Grey27", RGB_(0x45, 0x45, 0x45) },
  { "Grey28", RGB_(0x47, 0x47, 0x47) },
  { "Grey29", RGB_(0x4a, 0x4a, 0x4a) },
  { "Grey3", RGB_(0x8, 0x8, 0x8) },
  { "Grey30", RGB_(0x4d, 0x4d, 0x4d) },
  { "Grey31", RGB_(0x4f, 0x4f, 0x4f) },
  { "Grey32", RGB_(0x52, 0x52, 0x52) },
  { "Grey33", RGB_(0x54, 0x54, 0x54) },
  { "Grey34", RGB_(0x57, 0x57, 0x57) },
  { "Grey35", RGB_(0x59, 0x59, 0x59) },
  { "Grey36", RGB_(0x5c, 0x5c, 0x5c) },
  { "Grey37", RGB_(0x5e, 0x5e, 0x5e) },
  { "Grey38", RGB_(0x61, 0x61, 0x61) },
  { "Grey39", RGB_(0x63, 0x63, 0x63) },
  { "Grey4", RGB_(0xa, 0xa, 0xa) },
  { "Grey40", RGB_(0x66, 0x66, 0x66) },
  { "Grey41", RGB_(0x69, 0x69, 0x69) },
  { "Grey42", RGB_(0x6b, 0x6b, 0x6b) },
  { "Grey43", RGB_(0x6e, 0x6e, 0x6e) },
  { "Grey44", RGB_(0x70, 0x70, 0x70) },
  { "Grey45", RGB_(0x73, 0x73, 0x73) },
  { "Grey46", RGB_(0x75, 0x75, 0x75) },
  { "Grey47", RGB_(0x78, 0x78, 0x78) },
  { "Grey48", RGB_(0x7a, 0x7a, 0x7a) },
  { "Grey49", RGB_(0x7d, 0x7d, 0x7d) },
  { "Grey5", RGB_(0xd, 0xd, 0xd) },
  { "Grey50", RGB_(0x7f, 0x7f, 0x7f) },
  { "Grey51", RGB_(0x82, 0x82, 0x82) },
  { "Grey52", RGB_(0x85, 0x85, 0x85) },
  { "Grey53", RGB_(0x87, 0x87, 0x87) },
  { "Grey54", RGB_(0x8a, 0x8a, 0x8a) },
  { "Grey55", RGB_(0x8c, 0x8c, 0x8c) },
  { "Grey56", RGB_(0x8f, 0x8f, 0x8f) },
  { "Grey57", RGB_(0x91, 0x91, 0x91) },
  { "Grey58", RGB_(0x94, 0x94, 0x94) },
  { "Grey59", RGB_(0x96, 0x96, 0x96) },
  { "Grey6", RGB_(0xf, 0xf, 0xf) },
  { "Grey60", RGB_(0x99, 0x99, 0x99) },
  { "Grey61", RGB_(0x9c, 0x9c, 0x9c) },
  { "Grey62", RGB_(0x9e, 0x9e, 0x9e) },
  { "Grey63", RGB_(0xa1, 0xa1, 0xa1) },
  { "Grey64", RGB_(0xa3, 0xa3, 0xa3) },
  { "Grey65", RGB_(0xa6, 0xa6, 0xa6) },
  { "Grey66", RGB_(0xa8, 0xa8, 0xa8) },
  { "Grey67", RGB_(0xab, 0xab, 0xab) },
  { "Grey68", RGB_(0xad, 0xad, 0xad) },
  { "Grey69", RGB_(0xb0, 0xb0, 0xb0) },
  { "Grey7", RGB_(0x12, 0x12, 0x12) },
  { "Grey70", RGB_(0xb3, 0xb3, 0xb3) },
  { "Grey71", RGB_(0xb5, 0xb5, 0xb5) },
  { "Grey72", RGB_(0xb8, 0xb8, 0xb8) },
  { "Grey73", RGB_(0xba, 0xba, 0xba) },
  { "Grey74", RGB_(0xbd, 0xbd, 0xbd) },
  { "Grey75", RGB_(0xbf, 0xbf, 0xbf) },
  { "Grey76", RGB_(0xc2, 0xc2, 0xc2) },
  { "Grey77", RGB_(0xc4, 0xc4, 0xc4) },
  { "Grey78", RGB_(0xc7, 0xc7, 0xc7) },
  { "Grey79", RGB_(0xc9, 0xc9, 0xc9) },
  { "Grey8", RGB_(0x14, 0x14, 0x14) },
  { "Grey80", RGB_(0xcc, 0xcc, 0xcc) },
  { "Grey81", RGB_(0xcf, 0xcf, 0xcf) },
  { "Grey82", RGB_(0xd1, 0xd1, 0xd1) },
  { "Grey83", RGB_(0xd4, 0xd4, 0xd4) },
  { "Grey84", RGB_(0xd6, 0xd6, 0xd6) },
  { "Grey85", RGB_(0xd9, 0xd9, 0xd9) },
  { "Grey86", RGB_(0xdb, 0xdb, 0xdb) },
  { "Grey87", RGB_(0xde, 0xde, 0xde) },
  { "Grey88", RGB_(0xe0, 0xe0, 0xe0) },
  { "Grey89", RGB_(0xe3, 0xe3, 0xe3) },
  { "Grey9", RGB_(0x17, 0x17, 0x17) },
  { "Grey90", RGB_(0xe5, 0xe5, 0xe5) },
  { "Grey91", RGB_(0xe8, 0xe8, 0xe8) },
  { "Grey92", RGB_(0xeb, 0xeb, 0xeb) },
  { "Grey93", RGB_(0xed, 0xed, 0xed) },
  { "Grey94", RGB_(0xf0, 0xf0, 0xf0) },
  { "Grey95", RGB_(0xf2, 0xf2, 0xf2) },
  { "Grey96", RGB_(0xf5, 0xf5, 0xf5) },
  { "Grey97", RGB_(0xf7, 0xf7, 0xf7) },
  { "Grey98", RGB_(0xfa, 0xfa, 0xfa) },
  { "Grey99", RGB_(0xfc, 0xfc, 0xfc) },
  { "Honeydew", RGB_(0xf0, 0xff, 0xf0) },
  { "Honeydew1", RGB_(0xf0, 0xff, 0xf0) },
  { "Honeydew2", RGB_(0xe0, 0xee, 0xe0) },
  { "Honeydew3", RGB_(0xc1, 0xcd, 0xc1) },
  { "Honeydew4", RGB_(0x83, 0x8b, 0x83) },
  { "HotPink", RGB_(0xff, 0x69, 0xb4) },
  { "HotPink1", RGB_(0xff, 0x6e, 0xb4) },
  { "HotPink2", RGB_(0xee, 0x6a, 0xa7) },
  { "HotPink3", RGB_(0xcd, 0x60, 0x90) },
  { "HotPink4", RGB_(0x8b, 0x3a, 0x62) },
  { "IndianRed", RGB_(0xcd, 0x5c, 0x5c) },
  { "IndianRed1", RGB_(0xff, 0x6a, 0x6a) },
  { "IndianRed2", RGB_(0xee, 0x63, 0x63) },
  { "IndianRed3", RGB_(0xcd, 0x55, 0x55) },
  { "IndianRed4", RGB_(0x8b, 0x3a, 0x3a) },
  { "Indigo", RGB_(0x4b, 0x00, 0x82) },
  { "Ivory", RGB_(0xff, 0xff, 0xf0) },
  { "Ivory1", RGB_(0xff, 0xff, 0xf0) },
  { "Ivory2", RGB_(0xee, 0xee, 0xe0) },
  { "Ivory3", RGB_(0xcd, 0xcd, 0xc1) },
  { "Ivory4", RGB_(0x8b, 0x8b, 0x83) },
  { "Khaki", RGB_(0xf0, 0xe6, 0x8c) },
  { "Khaki1", RGB_(0xff, 0xf6, 0x8f) },
  { "Khaki2", RGB_(0xee, 0xe6, 0x85) },
  { "Khaki3", RGB_(0xcd, 0xc6, 0x73) },
  { "Khaki4", RGB_(0x8b, 0x86, 0x4e) },
  { "Lavender", RGB_(0xe6, 0xe6, 0xfa) },
  { "LavenderBlush", RGB_(0xff, 0xf0, 0xf5) },
  { "LavenderBlush1", RGB_(0xff, 0xf0, 0xf5) },
  { "LavenderBlush2", RGB_(0xee, 0xe0, 0xe5) },
  { "LavenderBlush3", RGB_(0xcd, 0xc1, 0xc5) },
  { "LavenderBlush4", RGB_(0x8b, 0x83, 0x86) },
  { "LawnGreen", RGB_(0x7c, 0xfc, 0x00) },
  { "LemonChiffon", RGB_(0xff, 0xfa, 0xcd) },
  { "LemonChiffon1", RGB_(0xff, 0xfa, 0xcd) },
  { "LemonChiffon2", RGB_(0xee, 0xe9, 0xbf) },
  { "LemonChiffon3", RGB_(0xcd, 0xc9, 0xa5) },
  { "LemonChiffon4", RGB_(0x8b, 0x89, 0x70) },
  { "LightBlue", RGB_(0xad, 0xd8, 0xe6) },
  { "LightBlue1", RGB_(0xbf, 0xef, 0xff) },
  { "LightBlue2", RGB_(0xb2, 0xdf, 0xee) },
  { "LightBlue3", RGB_(0x9a, 0xc0, 0xcd) },
  { "LightBlue4", RGB_(0x68, 0x83, 0x8b) },
  { "LightCoral", RGB_(0xf0, 0x80, 0x80) },
  { "LightCyan", RGB_(0xe0, 0xff, 0xff) },
  { "LightCyan1", RGB_(0xe0, 0xff, 0xff) },
  { "LightCyan2", RGB_(0xd1, 0xee, 0xee) },
  { "LightCyan3", RGB_(0xb4, 0xcd, 0xcd) },
  { "LightCyan4", RGB_(0x7a, 0x8b, 0x8b) },
  { "LightGoldenrod", RGB_(0xee, 0xdd, 0x82) },
  { "LightGoldenrod1", RGB_(0xff, 0xec, 0x8b) },
  { "LightGoldenrod2", RGB_(0xee, 0xdc, 0x82) },
  { "LightGoldenrod3", RGB_(0xcd, 0xbe, 0x70) },
  { "LightGoldenrod4", RGB_(0x8b, 0x81, 0x4c) },
  { "LightGoldenRodYellow", RGB_(0xfa, 0xfa, 0xd2) },
  { "LightGray", RGB_(0xd3, 0xd3, 0xd3) },
  { "LightGreen", RGB_(0x90, 0xee, 0x90) },
  { "LightGrey", RGB_(0xd3, 0xd3, 0xd3) },
  { "LightMagenta", RGB_(0xff, 0xbb, 0xff) },
  { "LightPink", RGB_(0xff, 0xb6, 0xc1) },
  { "LightPink1", RGB_(0xff, 0xae, 0xb9) },
  { "LightPink2", RGB_(0xee, 0xa2, 0xad) },
  { "LightPink3", RGB_(0xcd, 0x8c, 0x95) },
  { "LightPink4", RGB_(0x8b, 0x5f, 0x65) },
  { "LightRed", RGB_(0xff, 0xbb, 0xbb) },
  { "LightSalmon", RGB_(0xff, 0xa0, 0x7a) },
  { "LightSalmon1", RGB_(0xff, 0xa0, 0x7a) },
  { "LightSalmon2", RGB_(0xee, 0x95, 0x72) },
  { "LightSalmon3", RGB_(0xcd, 0x81, 0x62) },
  { "LightSalmon4", RGB_(0x8b, 0x57, 0x42) },
  { "LightSeaGreen", RGB_(0x20, 0xb2, 0xaa) },
  { "LightSkyBlue", RGB_(0x87, 0xce, 0xfa) },
  { "LightSkyBlue1", RGB_(0xb0, 0xe2, 0xff) },
  { "LightSkyBlue2", RGB_(0xa4, 0xd3, 0xee) },
  { "LightSkyBlue3", RGB_(0x8d, 0xb6, 0xcd) },
  { "LightSkyBlue4", RGB_(0x60, 0x7b, 0x8b) },
  { "LightSlateBlue", RGB_(0x84, 0x70, 0xff) },
  { "LightSlateGray", RGB_(0x77, 0x88, 0x99) },
  { "LightSlateGrey", RGB_(0x77, 0x88, 0x99) },
  { "LightSteelBlue", RGB_(0xb0, 0xc4, 0xde) },
  { "LightSteelBlue1", RGB_(0xca, 0xe1, 0xff) },
  { "LightSteelBlue2", RGB_(0xbc, 0xd2, 0xee) },
  { "LightSteelBlue3", RGB_(0xa2, 0xb5, 0xcd) },
  { "LightSteelBlue4", RGB_(0x6e, 0x7b, 0x8b) },
  { "LightYellow", RGB_(0xff, 0xff, 0xe0) },
  { "LightYellow1", RGB_(0xff, 0xff, 0xe0) },
  { "LightYellow2", RGB_(0xee, 0xee, 0xd1) },
  { "LightYellow3", RGB_(0xcd, 0xcd, 0xb4) },
  { "LightYellow4", RGB_(0x8b, 0x8b, 0x7a) },
  { "Lime", RGB_(0x00, 0xff, 0x00) },
  { "LimeGreen", RGB_(0x32, 0xcd, 0x32) },
  { "Linen", RGB_(0xfa, 0xf0, 0xe6) },
  { "Magenta", RGB_(0xff, 0x00, 0xff) },
  { "Magenta1", RGB_(0xff, 0x0, 0xff) },
  { "Magenta2", RGB_(0xee, 0x0, 0xee) },
  { "Magenta3", RGB_(0xcd, 0x0, 0xcd) },
  { "Magenta4", RGB_(0x8b, 0x0, 0x8b) },
  { "Maroon", RGB_(0x80, 0x00, 0x00) },
  { "Maroon1", RGB_(0xff, 0x34, 0xb3) },
  { "Maroon2", RGB_(0xee, 0x30, 0xa7) },
  { "Maroon3", RGB_(0xcd, 0x29, 0x90) },
  { "Maroon4", RGB_(0x8b, 0x1c, 0x62) },
  { "MediumAquamarine", RGB_(0x66, 0xcd, 0xaa) },
  { "MediumBlue", RGB_(0x00, 0x00, 0xcd) },
  { "MediumOrchid", RGB_(0xba, 0x55, 0xd3) },
  { "MediumOrchid1", RGB_(0xe0, 0x66, 0xff) },
  { "MediumOrchid2", RGB_(0xd1, 0x5f, 0xee) },
  { "MediumOrchid3", RGB_(0xb4, 0x52, 0xcd) },
  { "MediumOrchid4", RGB_(0x7a, 0x37, 0x8b) },
  { "MediumPurple", RGB_(0x93, 0x70, 0xdb) },
  { "MediumPurple1", RGB_(0xab, 0x82, 0xff) },
  { "MediumPurple2", RGB_(0x9f, 0x79, 0xee) },
  { "MediumPurple3", RGB_(0x89, 0x68, 0xcd) },
  { "MediumPurple4", RGB_(0x5d, 0x47, 0x8b) },
  { "MediumSeaGreen", RGB_(0x3c, 0xb3, 0x71) },
  { "MediumSlateBlue", RGB_(0x7b, 0x68, 0xee) },
  { "MediumSpringGreen", RGB_(0x00, 0xfa, 0x9a) },
  { "MediumTurquoise", RGB_(0x48, 0xd1, 0xcc) },
  { "MediumVioletRed", RGB_(0xc7, 0x15, 0x85) },
  { "MidnightBlue", RGB_(0x19, 0x19, 0x70) },
  { "MintCream", RGB_(0xf5, 0xff, 0xfa) },
  { "MistyRose", RGB_(0xff, 0xe4, 0xe1) },
  { "MistyRose1", RGB_(0xff, 0xe4, 0xe1) },
  { "MistyRose2", RGB_(0xee, 0xd5, 0xd2) },
  { "MistyRose3", RGB_(0xcd, 0xb7, 0xb5) },
  { "MistyRose4", RGB_(0x8b, 0x7d, 0x7b) },
  { "Moccasin", RGB_(0xff, 0xe4, 0xb5) },
  { "NavajoWhite", RGB_(0xff, 0xde, 0xad) },
  { "NavajoWhite1", RGB_(0xff, 0xde, 0xad) },
  { "NavajoWhite2", RGB_(0xee, 0xcf, 0xa1) },
  { "NavajoWhite3", RGB_(0xcd, 0xb3, 0x8b) },
  { "NavajoWhite4", RGB_(0x8b, 0x79, 0x5e) },
  { "Navy", RGB_(0x00, 0x00, 0x80) },
  { "NavyBlue", RGB_(0x0, 0x0, 0x80) },
  { "OldLace", RGB_(0xfd, 0xf5, 0xe6) },
  { "Olive", RGB_(0x80, 0x80, 0x00) },
  { "OliveDrab", RGB_(0x6b, 0x8e, 0x23) },
  { "OliveDrab1", RGB_(0xc0, 0xff, 0x3e) },
  { "OliveDrab2", RGB_(0xb3, 0xee, 0x3a) },
  { "OliveDrab3", RGB_(0x9a, 0xcd, 0x32) },
  { "OliveDrab4", RGB_(0x69, 0x8b, 0x22) },
  { "Orange", RGB_(0xff, 0xa5, 0x00) },
  { "Orange1", RGB_(0xff, 0xa5, 0x0) },
  { "Orange2", RGB_(0xee, 0x9a, 0x0) },
  { "Orange3", RGB_(0xcd, 0x85, 0x0) },
  { "Orange4", RGB_(0x8b, 0x5a, 0x0) },
  { "OrangeRed", RGB_(0xff, 0x45, 0x00) },
  { "OrangeRed1", RGB_(0xff, 0x45, 0x0) },
  { "OrangeRed2", RGB_(0xee, 0x40, 0x0) },
  { "OrangeRed3", RGB_(0xcd, 0x37, 0x0) },
  { "OrangeRed4", RGB_(0x8b, 0x25, 0x0) },
  { "Orchid", RGB_(0xda, 0x70, 0xd6) },
  { "Orchid1", RGB_(0xff, 0x83, 0xfa) },
  { "Orchid2", RGB_(0xee, 0x7a, 0xe9) },
  { "Orchid3", RGB_(0xcd, 0x69, 0xc9) },
  { "Orchid4", RGB_(0x8b, 0x47, 0x89) },
  { "PaleGoldenRod", RGB_(0xee, 0xe8, 0xaa) },
  { "PaleGreen", RGB_(0x98, 0xfb, 0x98) },
  { "PaleGreen1", RGB_(0x9a, 0xff, 0x9a) },
  { "PaleGreen2", RGB_(0x90, 0xee, 0x90) },
  { "PaleGreen3", RGB_(0x7c, 0xcd, 0x7c) },
  { "PaleGreen4", RGB_(0x54, 0x8b, 0x54) },
  { "PaleTurquoise", RGB_(0xaf, 0xee, 0xee) },
  { "PaleTurquoise1", RGB_(0xbb, 0xff, 0xff) },
  { "PaleTurquoise2", RGB_(0xae, 0xee, 0xee) },
  { "PaleTurquoise3", RGB_(0x96, 0xcd, 0xcd) },
  { "PaleTurquoise4", RGB_(0x66, 0x8b, 0x8b) },
  { "PaleVioletRed", RGB_(0xdb, 0x70, 0x93) },
  { "PaleVioletRed1", RGB_(0xff, 0x82, 0xab) },
  { "PaleVioletRed2", RGB_(0xee, 0x79, 0x9f) },
  { "PaleVioletRed3", RGB_(0xcd, 0x68, 0x89) },
  { "PaleVioletRed4", RGB_(0x8b, 0x47, 0x5d) },
  { "PapayaWhip", RGB_(0xff, 0xef, 0xd5) },
  { "PeachPuff", RGB_(0xff, 0xda, 0xb9) },
  { "PeachPuff1", RGB_(0xff, 0xda, 0xb9) },
  { "PeachPuff2", RGB_(0xee, 0xcb, 0xad) },
  { "PeachPuff3", RGB_(0xcd, 0xaf, 0x95) },
  { "PeachPuff4", RGB_(0x8b, 0x77, 0x65) },
  { "Peru", RGB_(0xcd, 0x85, 0x3f) },
  { "Pink", RGB_(0xff, 0xc0, 0xcb) },
  { "Pink1", RGB_(0xff, 0xb5, 0xc5) },
  { "Pink2", RGB_(0xee, 0xa9, 0xb8) },
  { "Pink3", RGB_(0xcd, 0x91, 0x9e) },
  { "Pink4", RGB_(0x8b, 0x63, 0x6c) },
  { "Plum", RGB_(0xdd, 0xa0, 0xdd) },
  { "Plum1", RGB_(0xff, 0xbb, 0xff) },
  { "Plum2", RGB_(0xee, 0xae, 0xee) },
  { "Plum3", RGB_(0xcd, 0x96, 0xcd) },
  { "Plum4", RGB_(0x8b, 0x66, 0x8b) },
  { "PowderBlue", RGB_(0xb0, 0xe0, 0xe6) },
  { "Purple", RGB_(0x80, 0x00, 0x80) },
  { "Purple1", RGB_(0x9b, 0x30, 0xff) },
  { "Purple2", RGB_(0x91, 0x2c, 0xee) },
  { "Purple3", RGB_(0x7d, 0x26, 0xcd) },
  { "Purple4", RGB_(0x55, 0x1a, 0x8b) },
  { "RebeccaPurple", RGB_(0x66, 0x33, 0x99) },
  { "Red", RGB_(0xff, 0x00, 0x00) },
  { "Red1", RGB_(0xff, 0x0, 0x0) },
  { "Red2", RGB_(0xee, 0x0, 0x0) },
  { "Red3", RGB_(0xcd, 0x0, 0x0) },
  { "Red4", RGB_(0x8b, 0x0, 0x0) },
  { "RosyBrown", RGB_(0xbc, 0x8f, 0x8f) },
  { "RosyBrown1", RGB_(0xff, 0xc1, 0xc1) },
  { "RosyBrown2", RGB_(0xee, 0xb4, 0xb4) },
  { "RosyBrown3", RGB_(0xcd, 0x9b, 0x9b) },
  { "RosyBrown4", RGB_(0x8b, 0x69, 0x69) },
  { "RoyalBlue", RGB_(0x41, 0x69, 0xe1) },
  { "RoyalBlue1", RGB_(0x48, 0x76, 0xff) },
  { "RoyalBlue2", RGB_(0x43, 0x6e, 0xee) },
  { "RoyalBlue3", RGB_(0x3a, 0x5f, 0xcd) },
  { "RoyalBlue4", RGB_(0x27, 0x40, 0x8b) },
  { "SaddleBrown", RGB_(0x8b, 0x45, 0x13) },
  { "Salmon", RGB_(0xfa, 0x80, 0x72) },
  { "Salmon1", RGB_(0xff, 0x8c, 0x69) },
  { "Salmon2", RGB_(0xee, 0x82, 0x62) },
  { "Salmon3", RGB_(0xcd, 0x70, 0x54) },
  { "Salmon4", RGB_(0x8b, 0x4c, 0x39) },
  { "SandyBrown", RGB_(0xf4, 0xa4, 0x60) },
  { "SeaGreen", RGB_(0x2e, 0x8b, 0x57) },
  { "SeaGreen1", RGB_(0x54, 0xff, 0x9f) },
  { "SeaGreen2", RGB_(0x4e, 0xee, 0x94) },
  { "SeaGreen3", RGB_(0x43, 0xcd, 0x80) },
  { "SeaGreen4", RGB_(0x2e, 0x8b, 0x57) },
  { "SeaShell", RGB_(0xff, 0xf5, 0xee) },
  { "Seashell1", RGB_(0xff, 0xf5, 0xee) },
  { "Seashell2", RGB_(0xee, 0xe5, 0xde) },
  { "Seashell3", RGB_(0xcd, 0xc5, 0xbf) },
  { "Seashell4", RGB_(0x8b, 0x86, 0x82) },
  { "Sienna", RGB_(0xa0, 0x52, 0x2d) },
  { "Sienna1", RGB_(0xff, 0x82, 0x47) },
  { "Sienna2", RGB_(0xee, 0x79, 0x42) },
  { "Sienna3", RGB_(0xcd, 0x68, 0x39) },
  { "Sienna4", RGB_(0x8b, 0x47, 0x26) },
  { "Silver", RGB_(0xc0, 0xc0, 0xc0) },
  { "SkyBlue", RGB_(0x87, 0xce, 0xeb) },
  { "SkyBlue1", RGB_(0x87, 0xce, 0xff) },
  { "SkyBlue2", RGB_(0x7e, 0xc0, 0xee) },
  { "SkyBlue3", RGB_(0x6c, 0xa6, 0xcd) },
  { "SkyBlue4", RGB_(0x4a, 0x70, 0x8b) },
  { "SlateBlue", RGB_(0x6a, 0x5a, 0xcd) },
  { "SlateBlue1", RGB_(0x83, 0x6f, 0xff) },
  { "SlateBlue2", RGB_(0x7a, 0x67, 0xee) },
  { "SlateBlue3", RGB_(0x69, 0x59, 0xcd) },
  { "SlateBlue4", RGB_(0x47, 0x3c, 0x8b) },
  { "SlateGray", RGB_(0x70, 0x80, 0x90) },
  { "SlateGray1", RGB_(0xc6, 0xe2, 0xff) },
  { "SlateGray2", RGB_(0xb9, 0xd3, 0xee) },
  { "SlateGray3", RGB_(0x9f, 0xb6, 0xcd) },
  { "SlateGray4", RGB_(0x6c, 0x7b, 0x8b) },
  { "SlateGrey", RGB_(0x70, 0x80, 0x90) },
  { "Snow", RGB_(0xff, 0xfa, 0xfa) },
  { "Snow1", RGB_(0xff, 0xfa, 0xfa) },
  { "Snow2", RGB_(0xee, 0xe9, 0xe9) },
  { "Snow3", RGB_(0xcd, 0xc9, 0xc9) },
  { "Snow4", RGB_(0x8b, 0x89, 0x89) },
  { "SpringGreen", RGB_(0x00, 0xff, 0x7f) },
  { "SpringGreen1", RGB_(0x0, 0xff, 0x7f) },
  { "SpringGreen2", RGB_(0x0, 0xee, 0x76) },
  { "SpringGreen3", RGB_(0x0, 0xcd, 0x66) },
  { "SpringGreen4", RGB_(0x0, 0x8b, 0x45) },
  { "SteelBlue", RGB_(0x46, 0x82, 0xb4) },
  { "SteelBlue1", RGB_(0x63, 0xb8, 0xff) },
  { "SteelBlue2", RGB_(0x5c, 0xac, 0xee) },
  { "SteelBlue3", RGB_(0x4f, 0x94, 0xcd) },
  { "SteelBlue4", RGB_(0x36, 0x64, 0x8b) },
  { "Tan", RGB_(0xd2, 0xb4, 0x8c) },
  { "Tan1", RGB_(0xff, 0xa5, 0x4f) },
  { "Tan2", RGB_(0xee, 0x9a, 0x49) },
  { "Tan3", RGB_(0xcd, 0x85, 0x3f) },
  { "Tan4", RGB_(0x8b, 0x5a, 0x2b) },
  { "Teal", RGB_(0x00, 0x80, 0x80) },
  { "Thistle", RGB_(0xd8, 0xbf, 0xd8) },
  { "Thistle1", RGB_(0xff, 0xe1, 0xff) },
  { "Thistle2", RGB_(0xee, 0xd2, 0xee) },
  { "Thistle3", RGB_(0xcd, 0xb5, 0xcd) },
  { "Thistle4", RGB_(0x8b, 0x7b, 0x8b) },
  { "Tomato", RGB_(0xff, 0x63, 0x47) },
  { "Tomato1", RGB_(0xff, 0x63, 0x47) },
  { "Tomato2", RGB_(0xee, 0x5c, 0x42) },
  { "Tomato3", RGB_(0xcd, 0x4f, 0x39) },
  { "Tomato4", RGB_(0x8b, 0x36, 0x26) },
  { "Turquoise", RGB_(0x40, 0xe0, 0xd0) },
  { "Turquoise1", RGB_(0x0, 0xf5, 0xff) },
  { "Turquoise2", RGB_(0x0, 0xe5, 0xee) },
  { "Turquoise3", RGB_(0x0, 0xc5, 0xcd) },
  { "Turquoise4", RGB_(0x0, 0x86, 0x8b) },
  { "Violet", RGB_(0xee, 0x82, 0xee) },
  { "VioletRed", RGB_(0xd0, 0x20, 0x90) },
  { "VioletRed1", RGB_(0xff, 0x3e, 0x96) },
  { "VioletRed2", RGB_(0xee, 0x3a, 0x8c) },
  { "VioletRed3", RGB_(0xcd, 0x32, 0x78) },
  { "VioletRed4", RGB_(0x8b, 0x22, 0x52) },
  { "WebGray", RGB_(0x80, 0x80, 0x80) },
  { "WebGreen", RGB_(0x0, 0x80, 0x0) },
  { "WebGrey", RGB_(0x80, 0x80, 0x80) },
  { "WebMaroon", RGB_(0x80, 0x0, 0x0) },
  { "WebPurple", RGB_(0x80, 0x0, 0x80) },
  { "Wheat", RGB_(0xf5, 0xde, 0xb3) },
  { "Wheat1", RGB_(0xff, 0xe7, 0xba) },
  { "Wheat2", RGB_(0xee, 0xd8, 0xae) },
  { "Wheat3", RGB_(0xcd, 0xba, 0x96) },
  { "Wheat4", RGB_(0x8b, 0x7e, 0x66) },
  { "White", RGB_(0xff, 0xff, 0xff) },
  { "WhiteSmoke", RGB_(0xf5, 0xf5, 0xf5) },
  { "X11Gray", RGB_(0xbe, 0xbe, 0xbe) },
  { "X11Green", RGB_(0x0, 0xff, 0x0) },
  { "X11Grey", RGB_(0xbe, 0xbe, 0xbe) },
  { "X11Maroon", RGB_(0xb0, 0x30, 0x60) },
  { "X11Purple", RGB_(0xa0, 0x20, 0xf0) },
  { "Yellow", RGB_(0xff, 0xff, 0x00) },
  { "Yellow1", RGB_(0xff, 0xff, 0x0) },
  { "Yellow2", RGB_(0xee, 0xee, 0x0) },
  { "Yellow3", RGB_(0xcd, 0xcd, 0x0) },
  { "Yellow4", RGB_(0x8b, 0x8b, 0x0) },
  { "YellowGreen", RGB_(0x9a, 0xcd, 0x32) },
  { NULL, 0 },
};

/// Translate to RgbValue if \p name is an hex value (e.g. #XXXXXX),
/// else look into color_name_table to translate a color name to  its
/// hex value
///
/// @param[in] name string value to convert to RGB
/// return the hex value or -1 if could not find a correct value
RgbValue name_to_color(const char *name)
{
  if (name[0] == '#' && isxdigit(name[1]) && isxdigit(name[2])
      && isxdigit(name[3]) && isxdigit(name[4]) && isxdigit(name[5])
      && isxdigit(name[6]) && name[7] == NUL) {
    // rgb hex string
    return (RgbValue)strtol((char *)(name + 1), NULL, 16);
  } else if (!STRICMP(name, "bg") || !STRICMP(name, "background")) {
    return normal_bg;
  } else if (!STRICMP(name, "fg") || !STRICMP(name, "foreground")) {
    return normal_fg;
  }

  for (int i = 0; color_name_table[i].name != NULL; i++) {
    if (!STRICMP(name, color_name_table[i].name)) {
      return color_name_table[i].color;
    }
  }

  return -1;
}

int name_to_ctermcolor(const char *name)
{
  int i;
  int off = TOUPPER_ASC(*name);
  for (i = ARRAY_SIZE(color_names); --i >= 0;) {
    if (off == color_names[i][0]
        && STRICMP(name + 1, color_names[i] + 1) == 0) {
      break;
    }
  }
  if (i < 0) {
    return -1;
  }
  TriState bold = kNone;
  return lookup_color(i, false, &bold);
}
