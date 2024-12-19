// highlight_group.c: code for managing highlight groups

#include <assert.h>
#include <ctype.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor_shape.h"
#include "nvim/decoration_provider.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_docmd.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/time.h"
#include "nvim/runtime.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"

/// \addtogroup SG_SET
/// @{
enum {
  SG_CTERM = 2,  // cterm has been set
  SG_GUI = 4,    // gui has been set
  SG_LINK = 8,   // link has been set
};
/// @}

#define MAX_SYN_NAME 200

// builtin |highlight-groups|
static garray_T highlight_ga = GA_EMPTY_INIT_VALUE;

// arena for object with same lifetime as highlight_ga (aka hl_table)
Arena highlight_arena = ARENA_EMPTY;

Map(cstr_t, int) highlight_unames = MAP_INIT;

/// The "term", "cterm" and "gui" arguments can be any combination of the
/// following names, separated by commas (but no spaces!).
static char *(hl_name_table[]) =
{ "bold", "standout", "underline",
  "undercurl", "underdouble", "underdotted", "underdashed",
  "italic", "reverse", "inverse", "strikethrough", "altfont",
  "nocombine", "NONE" };
static int hl_attr_table[] =
{ HL_BOLD, HL_STANDOUT, HL_UNDERLINE,
  HL_UNDERCURL, HL_UNDERDOUBLE, HL_UNDERDOTTED, HL_UNDERDASHED,
  HL_ITALIC, HL_INVERSE, HL_INVERSE, HL_STRIKETHROUGH, HL_ALTFONT,
  HL_NOCOMBINE, 0 };

/// Structure that stores information about a highlight group.
/// The ID of a highlight group is also called group ID.  It is the index in
/// the highlight_ga array PLUS ONE.
typedef struct {
  char *sg_name;                ///< highlight group name
  char *sg_name_u;              ///< uppercase of sg_name
  bool sg_cleared;              ///< "hi clear" was used
  int sg_attr;                  ///< Screen attr @see ATTR_ENTRY
  int sg_link;                  ///< link to this highlight group ID
  int sg_deflink;               ///< default link; restored in highlight_clear()
  int sg_set;                   ///< combination of flags in \ref SG_SET
  sctx_T sg_deflink_sctx;       ///< script where the default link was set
  sctx_T sg_script_ctx;         ///< script in which the group was last set for terminal UIs
  int sg_cterm;                 ///< "cterm=" highlighting attr
                                ///< (combination of \ref HlAttrFlags)
  int sg_cterm_fg;              ///< terminal fg color number + 1
  int sg_cterm_bg;              ///< terminal bg color number + 1
  bool sg_cterm_bold;           ///< bold attr was set for light color for RGB UIs
  int sg_gui;                   ///< "gui=" highlighting attributes
                                ///< (combination of \ref HlAttrFlags)
  RgbValue sg_rgb_fg;           ///< RGB foreground color
  RgbValue sg_rgb_bg;           ///< RGB background color
  RgbValue sg_rgb_sp;           ///< RGB special color
  int sg_rgb_fg_idx;            ///< RGB foreground color index
  int sg_rgb_bg_idx;            ///< RGB background color index
  int sg_rgb_sp_idx;            ///< RGB special color index

  int sg_blend;                 ///< blend level (0-100 inclusive), -1 if unset

  int sg_parent;                ///< parent of @nested.group
} HlGroup;

enum {
  kColorIdxNone = -1,
  kColorIdxHex = -2,
  kColorIdxFg = -3,
  kColorIdxBg = -4,
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "highlight_group.c.generated.h"
#endif

static const char e_highlight_group_name_not_found_str[]
  = N_("E411: Highlight group not found: %s");
static const char e_group_has_settings_highlight_link_ignored[]
  = N_("E414: Group has settings, highlight link ignored");
static const char e_unexpected_equal_sign_str[]
  = N_("E415: Unexpected equal sign: %s");
static const char e_missing_equal_sign_str_2[]
  = N_("E416: Missing equal sign: %s");
static const char e_missing_argument_str[]
  = N_("E417: Missing argument: %s");

#define hl_table ((HlGroup *)((highlight_ga.ga_data)))

// The default highlight groups.  These are compiled-in for fast startup and
// they still work when the runtime files can't be found.

static const char *highlight_init_both[] = {
  "Cursor            guifg=bg      guibg=fg",
  "CursorLineNr      gui=bold      cterm=bold",
  "PmenuMatch        gui=bold      cterm=bold",
  "PmenuMatchSel     gui=bold      cterm=bold",
  "PmenuSel          gui=reverse   cterm=reverse,underline blend=0",
  "RedrawDebugNormal gui=reverse   cterm=reverse",
  "TabLineSel        gui=bold      cterm=bold",
  "TermCursor        gui=reverse   cterm=reverse",
  "Underlined        gui=underline cterm=underline",
  "lCursor           guifg=bg      guibg=fg",

  // UI
  "default link CursorIM         Cursor",
  "default link CursorLineFold   FoldColumn",
  "default link CursorLineSign   SignColumn",
  "default link EndOfBuffer      NonText",
  "default link FloatBorder      NormalFloat",
  "default link FloatFooter      FloatTitle",
  "default link FloatTitle       Title",
  "default link FoldColumn       SignColumn",
  "default link IncSearch        CurSearch",
  "default link LineNrAbove      LineNr",
  "default link LineNrBelow      LineNr",
  "default link MsgSeparator     StatusLine",
  "default link MsgArea          NONE",
  "default link NormalNC         NONE",
  "default link PmenuExtra       Pmenu",
  "default link PmenuExtraSel    PmenuSel",
  "default link PmenuKind        Pmenu",
  "default link PmenuKindSel     PmenuSel",
  "default link PmenuSbar        Pmenu",
  "default link ComplMatchIns    NONE",
  "default link Substitute       Search",
  "default link StatusLineTerm   StatusLine",
  "default link StatusLineTermNC StatusLineNC",
  "default link TabLine          StatusLineNC",
  "default link TabLineFill      TabLine",
  "default link VertSplit        WinSeparator",
  "default link VisualNOS        Visual",
  "default link Whitespace       NonText",
  "default link WildMenu         PmenuSel",
  "default link WinSeparator     Normal",

  // Syntax
  "default link Character      Constant",
  "default link Number         Constant",
  "default link Boolean        Constant",
  "default link Float          Number",
  "default link Conditional    Statement",
  "default link Repeat         Statement",
  "default link Label          Statement",
  "default link Keyword        Statement",
  "default link Exception      Statement",
  "default link Include        PreProc",
  "default link Define         PreProc",
  "default link Macro          PreProc",
  "default link PreCondit      PreProc",
  "default link StorageClass   Type",
  "default link Structure      Type",
  "default link Typedef        Type",
  "default link Tag            Special",
  "default link SpecialChar    Special",
  "default link SpecialComment Special",
  "default link Debug          Special",
  "default link Ignore         Normal",

  // Built-in LSP
  "default link LspCodeLens                 NonText",
  "default link LspCodeLensSeparator        LspCodeLens",
  "default link LspInlayHint                NonText",
  "default link LspReferenceRead            LspReferenceText",
  "default link LspReferenceText            Visual",
  "default link LspReferenceWrite           LspReferenceText",
  "default link LspReferenceTarget          LspReferenceText",
  "default link LspSignatureActiveParameter Visual",
  "default link SnippetTabstop              Visual",

  // Diagnostic
  "default link DiagnosticFloatingError    DiagnosticError",
  "default link DiagnosticFloatingWarn     DiagnosticWarn",
  "default link DiagnosticFloatingInfo     DiagnosticInfo",
  "default link DiagnosticFloatingHint     DiagnosticHint",
  "default link DiagnosticFloatingOk       DiagnosticOk",
  "default link DiagnosticVirtualTextError DiagnosticError",
  "default link DiagnosticVirtualTextWarn  DiagnosticWarn",
  "default link DiagnosticVirtualTextInfo  DiagnosticInfo",
  "default link DiagnosticVirtualTextHint  DiagnosticHint",
  "default link DiagnosticVirtualTextOk    DiagnosticOk",
  "default link DiagnosticSignError        DiagnosticError",
  "default link DiagnosticSignWarn         DiagnosticWarn",
  "default link DiagnosticSignInfo         DiagnosticInfo",
  "default link DiagnosticSignHint         DiagnosticHint",
  "default link DiagnosticSignOk           DiagnosticOk",
  "default link DiagnosticUnnecessary      Comment",

  // Treesitter standard groups
  "default link @variable.builtin           Special",
  "default link @variable.parameter.builtin Special",

  "default link @constant         Constant",
  "default link @constant.builtin Special",

  "default link @module         Structure",
  "default link @module.builtin Special",
  "default link @label          Label",

  "default link @string             String",
  "default link @string.regexp      @string.special",
  "default link @string.escape      @string.special",
  "default link @string.special     SpecialChar",
  "default link @string.special.url Underlined",

  "default link @character         Character",
  "default link @character.special SpecialChar",

  "default link @boolean      Boolean",
  "default link @number       Number",
  "default link @number.float Float",

  "default link @type         Type",
  "default link @type.builtin Special",

  "default link @attribute         Macro",
  "default link @attribute.builtin Special",
  "default link @property          Identifier",

  "default link @function         Function",
  "default link @function.builtin Special",

  "default link @constructor Special",
  "default link @operator    Operator",

  "default link @keyword Keyword",

  "default link @punctuation         Delimiter",  // fallback for subgroups; never used itself
  "default link @punctuation.special Special",

  "default link @comment Comment",

  "default link @comment.error   DiagnosticError",
  "default link @comment.warning DiagnosticWarn",
  "default link @comment.note    DiagnosticInfo",
  "default link @comment.todo    Todo",

  "@markup.strong        gui=bold          cterm=bold",
  "@markup.italic        gui=italic        cterm=italic",
  "@markup.strikethrough gui=strikethrough cterm=strikethrough",
  "@markup.underline     gui=underline     cterm=underline",

  "default link @markup         Special",  // fallback for subgroups; never used itself
  "default link @markup.heading Title",
  "default link @markup.link    Underlined",

  "default link @diff.plus  Added",
  "default link @diff.minus Removed",
  "default link @diff.delta Changed",

  "default link @tag         Tag",
  "default link @tag.builtin Special",

  // :help
  // Highlight "===" and "---" heading delimiters specially.
  "default @markup.heading.1.delimiter.vimdoc guibg=bg guifg=bg guisp=fg gui=underdouble,nocombine ctermbg=NONE ctermfg=NONE cterm=underdouble,nocombine",
  "default @markup.heading.2.delimiter.vimdoc guibg=bg guifg=bg guisp=fg gui=underline,nocombine ctermbg=NONE ctermfg=NONE cterm=underline,nocombine",

  // LSP semantic tokens
  "default link @lsp.type.class         @type",
  "default link @lsp.type.comment       @comment",
  "default link @lsp.type.decorator     @attribute",
  "default link @lsp.type.enum          @type",
  "default link @lsp.type.enumMember    @constant",
  "default link @lsp.type.event         @type",
  "default link @lsp.type.function      @function",
  "default link @lsp.type.interface     @type",
  "default link @lsp.type.keyword       @keyword",
  "default link @lsp.type.macro         @constant.macro",
  "default link @lsp.type.method        @function.method",
  "default link @lsp.type.modifier      @type.qualifier",
  "default link @lsp.type.namespace     @module",
  "default link @lsp.type.number        @number",
  "default link @lsp.type.operator      @operator",
  "default link @lsp.type.parameter     @variable.parameter",
  "default link @lsp.type.property      @property",
  "default link @lsp.type.regexp        @string.regexp",
  "default link @lsp.type.string        @string",
  "default link @lsp.type.struct        @type",
  "default link @lsp.type.type          @type",
  "default link @lsp.type.typeParameter @type.definition",
  "default link @lsp.type.variable      @variable",

  "default link @lsp.mod.deprecated DiagnosticDeprecated",

  NULL
};

// Default colors only used with a light background.
static const char *highlight_init_light[] = {
  "Normal guifg=NvimDarkGrey2 guibg=NvimLightGrey2 ctermfg=NONE ctermbg=NONE",

  // UI
  "Added                guifg=NvimDarkGreen                                  ctermfg=2",
  "Changed              guifg=NvimDarkCyan                                   ctermfg=6",
  "ColorColumn                               guibg=NvimLightGrey4            cterm=reverse",
  "Conceal              guifg=NvimLightGrey4",
  "CurSearch            guifg=NvimLightGrey1 guibg=NvimDarkYellow            ctermfg=15 ctermbg=3",
  "CursorColumn                              guibg=NvimLightGrey3",
  "CursorLine                                guibg=NvimLightGrey3",
  "DiffAdd              guifg=NvimDarkGrey1  guibg=NvimLightGreen            ctermfg=15 ctermbg=2",
  "DiffChange           guifg=NvimDarkGrey1  guibg=NvimLightGrey4",
  "DiffDelete           guifg=NvimDarkRed                          gui=bold  ctermfg=1 cterm=bold",
  "DiffText             guifg=NvimDarkGrey1  guibg=NvimLightCyan             ctermfg=15 ctermbg=6",
  "Directory            guifg=NvimDarkCyan                                   ctermfg=6",
  "ErrorMsg             guifg=NvimDarkRed                                    ctermfg=1",
  "FloatShadow                               guibg=NvimLightGrey4            ctermbg=0 blend=80",
  "FloatShadowThrough                        guibg=NvimLightGrey4            ctermbg=0 blend=100",
  "Folded               guifg=NvimDarkGrey4  guibg=NvimLightGrey3",
  "LineNr               guifg=NvimLightGrey4",
  "MatchParen                                guibg=NvimLightGrey4  gui=bold  cterm=bold,underline",
  "ModeMsg              guifg=NvimDarkGreen                                  ctermfg=2",
  "MoreMsg              guifg=NvimDarkCyan                                   ctermfg=6",
  "NonText              guifg=NvimLightGrey4",
  "NormalFloat                               guibg=NvimLightGrey1",
  "Pmenu                                     guibg=NvimLightGrey3            cterm=reverse",
  "PmenuThumb                                guibg=NvimLightGrey4",
  "Question             guifg=NvimDarkCyan                                   ctermfg=6",
  "QuickFixLine         guifg=NvimDarkCyan                                   ctermfg=6",
  "RedrawDebugClear                          guibg=NvimLightYellow           ctermfg=15 ctermbg=3",
  "RedrawDebugComposed                       guibg=NvimLightGreen            ctermfg=15 ctermbg=2",
  "RedrawDebugRecompose                      guibg=NvimLightRed              ctermfg=15 ctermbg=1",
  "Removed              guifg=NvimDarkRed                                    ctermfg=1",
  "Search               guifg=NvimDarkGrey1  guibg=NvimLightYellow           ctermfg=15 ctermbg=3",
  "SignColumn           guifg=NvimLightGrey4",
  "SpecialKey           guifg=NvimLightGrey4",
  "SpellBad             guisp=NvimDarkRed    gui=undercurl                   cterm=undercurl",
  "SpellCap             guisp=NvimDarkYellow gui=undercurl                   cterm=undercurl",
  "SpellLocal           guisp=NvimDarkGreen  gui=undercurl                   cterm=undercurl",
  "SpellRare            guisp=NvimDarkCyan   gui=undercurl                   cterm=undercurl",
  "StatusLine           guifg=NvimLightGrey3 guibg=NvimDarkGrey3             cterm=reverse",
  "StatusLineNC         guifg=NvimDarkGrey3  guibg=NvimLightGrey3            cterm=bold,underline",
  "Title                guifg=NvimDarkGrey2                        gui=bold  cterm=bold",
  "Visual                                    guibg=NvimLightGrey4            ctermfg=15 ctermbg=0",
  "WarningMsg           guifg=NvimDarkYellow                                 ctermfg=3",
  "WinBar               guifg=NvimDarkGrey4  guibg=NvimLightGrey1  gui=bold  cterm=bold",
  "WinBarNC             guifg=NvimDarkGrey4  guibg=NvimLightGrey1            cterm=bold",

  // Syntax
  "Constant   guifg=NvimDarkGrey2",  // Use only `Normal` foreground to be usable on different background
  "Operator   guifg=NvimDarkGrey2",
  "PreProc    guifg=NvimDarkGrey2",
  "Type       guifg=NvimDarkGrey2",
  "Delimiter  guifg=NvimDarkGrey2",

  "Comment    guifg=NvimDarkGrey4",
  "String     guifg=NvimDarkGreen                    ctermfg=2",
  "Identifier guifg=NvimDarkBlue                     ctermfg=4",
  "Function   guifg=NvimDarkCyan                     ctermfg=6",
  "Statement  guifg=NvimDarkGrey2 gui=bold           cterm=bold",
  "Special    guifg=NvimDarkCyan                     ctermfg=6",
  "Error      guifg=NvimDarkGrey1 guibg=NvimLightRed ctermfg=15 ctermbg=1",
  "Todo       guifg=NvimDarkGrey2 gui=bold           cterm=bold",

  // Diagnostic
  "DiagnosticError          guifg=NvimDarkRed                      ctermfg=1",
  "DiagnosticWarn           guifg=NvimDarkYellow                   ctermfg=3",
  "DiagnosticInfo           guifg=NvimDarkCyan                     ctermfg=6",
  "DiagnosticHint           guifg=NvimDarkBlue                     ctermfg=4",
  "DiagnosticOk             guifg=NvimDarkGreen                    ctermfg=2",
  "DiagnosticUnderlineError guisp=NvimDarkRed    gui=underline     cterm=underline",
  "DiagnosticUnderlineWarn  guisp=NvimDarkYellow gui=underline     cterm=underline",
  "DiagnosticUnderlineInfo  guisp=NvimDarkCyan   gui=underline     cterm=underline",
  "DiagnosticUnderlineHint  guisp=NvimDarkBlue   gui=underline     cterm=underline",
  "DiagnosticUnderlineOk    guisp=NvimDarkGreen  gui=underline     cterm=underline",
  "DiagnosticDeprecated     guisp=NvimDarkRed    gui=strikethrough cterm=strikethrough",

  // Treesitter standard groups
  "@variable guifg=NvimDarkGrey2",
  NULL
};

// Default colors only used with a dark background.
static const char *highlight_init_dark[] = {
  "Normal guifg=NvimLightGrey2 guibg=NvimDarkGrey2 ctermfg=NONE ctermbg=NONE",

  // UI
  "Added                guifg=NvimLightGreen                                ctermfg=10",
  "Changed              guifg=NvimLightCyan                                 ctermfg=14",
  "ColorColumn                                guibg=NvimDarkGrey4           cterm=reverse",
  "Conceal              guifg=NvimDarkGrey4",
  "CurSearch            guifg=NvimDarkGrey1   guibg=NvimLightYellow         ctermfg=0 ctermbg=11",
  "CursorColumn                               guibg=NvimDarkGrey3",
  "CursorLine                                 guibg=NvimDarkGrey3",
  "DiffAdd              guifg=NvimLightGrey1  guibg=NvimDarkGreen           ctermfg=0 ctermbg=10",
  "DiffChange           guifg=NvimLightGrey1  guibg=NvimDarkGrey4",
  "DiffDelete           guifg=NvimLightRed                         gui=bold ctermfg=9 cterm=bold",
  "DiffText             guifg=NvimLightGrey1  guibg=NvimDarkCyan            ctermfg=0 ctermbg=14",
  "Directory            guifg=NvimLightCyan                                 ctermfg=14",
  "ErrorMsg             guifg=NvimLightRed                                  ctermfg=9",
  "FloatShadow                                guibg=NvimDarkGrey4           ctermbg=0 blend=80",
  "FloatShadowThrough                         guibg=NvimDarkGrey4           ctermbg=0 blend=100",
  "Folded               guifg=NvimLightGrey4  guibg=NvimDarkGrey3",
  "LineNr               guifg=NvimDarkGrey4",
  "MatchParen                                 guibg=NvimDarkGrey4  gui=bold cterm=bold,underline",
  "ModeMsg              guifg=NvimLightGreen                                ctermfg=10",
  "MoreMsg              guifg=NvimLightCyan                                 ctermfg=14",
  "NonText              guifg=NvimDarkGrey4",
  "NormalFloat                                guibg=NvimDarkGrey1",
  "Pmenu                                      guibg=NvimDarkGrey3           cterm=reverse",
  "PmenuThumb                                 guibg=NvimDarkGrey4",
  "Question             guifg=NvimLightCyan                                 ctermfg=14",
  "QuickFixLine         guifg=NvimLightCyan                                 ctermfg=14",
  "RedrawDebugClear                           guibg=NvimDarkYellow          ctermfg=0 ctermbg=11",
  "RedrawDebugComposed                        guibg=NvimDarkGreen           ctermfg=0 ctermbg=10",
  "RedrawDebugRecompose                       guibg=NvimDarkRed             ctermfg=0 ctermbg=9",
  "Removed              guifg=NvimLightRed                                  ctermfg=9",
  "Search               guifg=NvimLightGrey1  guibg=NvimDarkYellow          ctermfg=0 ctermbg=11",
  "SignColumn           guifg=NvimDarkGrey4",
  "SpecialKey           guifg=NvimDarkGrey4",
  "SpellBad             guisp=NvimLightRed    gui=undercurl                 cterm=undercurl",
  "SpellCap             guisp=NvimLightYellow gui=undercurl                 cterm=undercurl",
  "SpellLocal           guisp=NvimLightGreen  gui=undercurl                 cterm=undercurl",
  "SpellRare            guisp=NvimLightCyan   gui=undercurl                 cterm=undercurl",
  "StatusLine           guifg=NvimDarkGrey3   guibg=NvimLightGrey3          cterm=reverse",
  "StatusLineNC         guifg=NvimLightGrey3  guibg=NvimDarkGrey3           cterm=bold,underline",
  "Title                guifg=NvimLightGrey2                       gui=bold cterm=bold",
  "Visual                                     guibg=NvimDarkGrey4           ctermfg=0 ctermbg=15",
  "WarningMsg           guifg=NvimLightYellow                               ctermfg=11",
  "WinBar               guifg=NvimLightGrey4  guibg=NvimDarkGrey1  gui=bold cterm=bold",
  "WinBarNC             guifg=NvimLightGrey4  guibg=NvimDarkGrey1           cterm=bold",

  // Syntax
  "Constant   guifg=NvimLightGrey2",  // Use only `Normal` foreground to be usable on different background
  "Operator   guifg=NvimLightGrey2",
  "PreProc    guifg=NvimLightGrey2",
  "Type       guifg=NvimLightGrey2",
  "Delimiter  guifg=NvimLightGrey2",

  "Comment    guifg=NvimLightGrey4",
  "String     guifg=NvimLightGreen                   ctermfg=10",
  "Identifier guifg=NvimLightBlue                    ctermfg=12",
  "Function   guifg=NvimLightCyan                    ctermfg=14",
  "Statement  guifg=NvimLightGrey2 gui=bold          cterm=bold",
  "Special    guifg=NvimLightCyan                    ctermfg=14",
  "Error      guifg=NvimLightGrey1 guibg=NvimDarkRed ctermfg=0 ctermbg=9",
  "Todo       guifg=NvimLightGrey2 gui=bold          cterm=bold",

  // Diagnostic
  "DiagnosticError          guifg=NvimLightRed                      ctermfg=9",
  "DiagnosticWarn           guifg=NvimLightYellow                   ctermfg=11",
  "DiagnosticInfo           guifg=NvimLightCyan                     ctermfg=14",
  "DiagnosticHint           guifg=NvimLightBlue                     ctermfg=12",
  "DiagnosticOk             guifg=NvimLightGreen                    ctermfg=10",
  "DiagnosticUnderlineError guisp=NvimLightRed    gui=underline     cterm=underline",
  "DiagnosticUnderlineWarn  guisp=NvimLightYellow gui=underline     cterm=underline",
  "DiagnosticUnderlineInfo  guisp=NvimLightCyan   gui=underline     cterm=underline",
  "DiagnosticUnderlineHint  guisp=NvimLightBlue   gui=underline     cterm=underline",
  "DiagnosticUnderlineOk    guisp=NvimLightGreen  gui=underline     cterm=underline",
  "DiagnosticDeprecated     guisp=NvimLightRed    gui=strikethrough cterm=strikethrough",

  // Treesitter standard groups
  "@variable guifg=NvimLightGrey2",
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
char *highlight_group_name(int id)
{
  return hl_table[id].sg_name;
}

/// Returns the ID of the link to a highlight group.
int highlight_link_id(int id)
{
  return hl_table[id].sg_link;
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
  static bool had_both = false;

  // Try finding the color scheme file.  Used when a color file was loaded
  // and 'background' or 't_Co' is changed.
  char *p = get_var_value("g:colors_name");
  if (p != NULL) {
    // Value of g:colors_name could be freed in load_colors() and make
    // p invalid, so copy it.
    char *copy_p = xstrdup(p);
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

  syn_init_cmdline_highlight(false, false);
}

/// Load color file "name".
///
/// @return  OK for success, FAIL for failure.
int load_colors(char *name)
{
  static bool recursive = false;

  // When being called recursively, this is probably because setting
  // 'background' caused the highlighting to be reloaded.  This means it is
  // working, thus we should return OK.
  if (recursive) {
    return OK;
  }

  recursive = true;
  size_t buflen = strlen(name) + 12;
  char *buf = xmalloc(buflen);
  apply_autocmds(EVENT_COLORSCHEMEPRE, name, curbuf->b_fname, false, curbuf);
  snprintf(buf, buflen, "colors/%s.*", name);
  int retval = source_runtime_vim_lua(buf, DIP_START + DIP_OPT);
  xfree(buf);
  if (retval == OK) {
    apply_autocmds(EVENT_COLORSCHEME, name, curbuf->b_fname, false, curbuf);
  }

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
// "boldp" will be set to kTrue or kFalse for a foreground color when using 8
// colors, otherwise it will be unchanged.
static int lookup_color(const int idx, const bool foreground, TriState *const boldp)
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
  if (is_default && hl_has_settings(idx, true) && !dict->force) {
    return;
  }

  HlGroup *g = &hl_table[idx];
  g->sg_cleared = false;

  if (link_id > 0) {
    g->sg_link = link_id;
    g->sg_script_ctx = current_sctx;
    g->sg_script_ctx.sc_lnum += SOURCING_LNUM;
    nlua_set_sctx(&g->sg_script_ctx);
    g->sg_set |= SG_LINK;
    if (is_default) {
      g->sg_deflink = link_id;
      g->sg_deflink_sctx = current_sctx;
      g->sg_deflink_sctx.sc_lnum += SOURCING_LNUM;
      nlua_set_sctx(&g->sg_deflink_sctx);
    }
  } else {
    g->sg_link = 0;
  }

  g->sg_gui = attrs.rgb_ae_attr &~HL_DEFAULT;

  g->sg_rgb_fg = attrs.rgb_fg_color;
  g->sg_rgb_bg = attrs.rgb_bg_color;
  g->sg_rgb_sp = attrs.rgb_sp_color;

  struct {
    int *dest; RgbValue val; Object name;
  } cattrs[] = {
    { &g->sg_rgb_fg_idx, g->sg_rgb_fg,
      HAS_KEY(dict, highlight, fg) ? dict->fg : dict->foreground },
    { &g->sg_rgb_bg_idx, g->sg_rgb_bg,
      HAS_KEY(dict, highlight, bg) ? dict->bg : dict->background },
    { &g->sg_rgb_sp_idx, g->sg_rgb_sp, HAS_KEY(dict, highlight, sp) ? dict->sp : dict->special },
    { NULL, -1, NIL },
  };

  for (int j = 0; cattrs[j].dest; j++) {
    if (cattrs[j].val < 0) {
      *cattrs[j].dest = kColorIdxNone;
    } else if (cattrs[j].name.type == kObjectTypeString && cattrs[j].name.data.string.size) {
      name_to_color(cattrs[j].name.data.string.data, cattrs[j].dest);
    } else {
      *cattrs[j].dest = kColorIdxHex;
    }
  }

  g->sg_cterm = attrs.cterm_ae_attr &~HL_DEFAULT;
  g->sg_cterm_bg = attrs.cterm_bg_color;
  g->sg_cterm_fg = attrs.cterm_fg_color;
  g->sg_cterm_bold = g->sg_cterm & HL_BOLD;
  g->sg_blend = attrs.hl_blend;

  g->sg_script_ctx = current_sctx;
  g->sg_script_ctx.sc_lnum += SOURCING_LNUM;
  nlua_set_sctx(&g->sg_script_ctx);

  g->sg_attr = hl_get_syn_attr(0, id, attrs);

  // 'Normal' is special
  if (strcmp(g->sg_name_u, "NORMAL") == 0) {
    cterm_normal_fg_color = g->sg_cterm_fg;
    cterm_normal_bg_color = g->sg_cterm_bg;
    bool did_changed = false;
    if (normal_bg != g->sg_rgb_bg || normal_fg != g->sg_rgb_fg || normal_sp != g->sg_rgb_sp) {
      did_changed = true;
    }
    normal_fg = g->sg_rgb_fg;
    normal_bg = g->sg_rgb_bg;
    normal_sp = g->sg_rgb_sp;

    if (did_changed) {
      highlight_attr_set_all();
    }
    ui_default_colors_set();
  } else {
    // a cursor style uses this syn_id, make sure its attribute is updated.
    if (cursor_mode_uses_syn_id(id)) {
      ui_mode_info_set();
    }
  }

  if (!updating_screen) {
    redraw_all_later(UPD_NOT_VALID);
  }
  need_highlight_changed = true;
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
  // If no argument, list current highlighting.
  if (!init && ends_excmd((uint8_t)(*line))) {
    msg_ext_set_kind("list_cmd");
    for (int i = 1; i <= highlight_ga.ga_len && !got_int; i++) {
      // TODO(brammool): only call when the group has attributes set
      highlight_list_one(i);
    }
    return;
  }

  bool dodefault = false;

  // Isolate the name.
  const char *name_end = skiptowhite(line);
  const char *linep = skipwhite(name_end);

  // Check for "default" argument.
  if (strncmp(line, "default", (size_t)(name_end - line)) == 0) {
    dodefault = true;
    line = linep;
    name_end = skiptowhite(line);
    linep = skipwhite(name_end);
  }

  bool doclear = false;
  bool dolink = false;

  // Check for "clear" or "link" argument.
  if (strncmp(line, "clear", (size_t)(name_end - line)) == 0) {
    doclear = true;
  } else if (strncmp(line, "link", (size_t)(name_end - line)) == 0) {
    dolink = true;
  }

  // ":highlight {group-name}": list highlighting for one group.
  if (!doclear && !dolink && ends_excmd((uint8_t)(*linep))) {
    int id = syn_name2id_len(line, (size_t)(name_end - line));
    if (id == 0) {
      semsg(_(e_highlight_group_name_not_found_str), line);
    } else {
      msg_ext_set_kind("list_cmd");
      highlight_list_one(id);
    }
    return;
  }

  // Handle ":highlight link {from} {to}" command.
  if (dolink) {
    const char *from_start = linep;
    int to_id;
    HlGroup *hlgroup = NULL;

    const char *from_end = skiptowhite(from_start);
    const char *to_start = skipwhite(from_end);
    const char *to_end = skiptowhite(to_start);

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

    int from_id = syn_check_group(from_start, (size_t)(from_end - from_start));
    if (strncmp(to_start, "NONE", 4) == 0) {
      to_id = 0;
    } else {
      to_id = syn_check_group(to_start, (size_t)(to_end - to_start));
    }

    if (from_id > 0) {
      hlgroup = &hl_table[from_id - 1];
      if (dodefault && (forceit || hlgroup->sg_deflink == 0)) {
        hlgroup->sg_deflink = to_id;
        hlgroup->sg_deflink_sctx = current_sctx;
        hlgroup->sg_deflink_sctx.sc_lnum += SOURCING_LNUM;
        nlua_set_sctx(&hlgroup->sg_deflink_sctx);
      }
    }

    if (from_id > 0 && (!init || hlgroup->sg_set == 0)) {
      // Don't allow a link when there already is some highlighting
      // for the group, unless '!' is used
      if (to_id > 0 && !forceit && !init
          && hl_has_settings(from_id - 1, dodefault)) {
        if (SOURCING_NAME == NULL && !dodefault) {
          emsg(_(e_group_has_settings_highlight_link_ignored));
        }
      } else if (hlgroup->sg_link != to_id
                 || hlgroup->sg_script_ctx.sc_sid != current_sctx.sc_sid
                 || hlgroup->sg_cleared) {
        if (!init) {
          hlgroup->sg_set |= SG_LINK;
        }
        hlgroup->sg_link = to_id;
        hlgroup->sg_script_ctx = current_sctx;
        hlgroup->sg_script_ctx.sc_lnum += SOURCING_LNUM;
        nlua_set_sctx(&hlgroup->sg_script_ctx);
        hlgroup->sg_cleared = false;
        redraw_all_later(UPD_SOME_VALID);

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
      do_unlet(S_LEN("g:colors_name"), true);
      restore_cterm_colors();

      // Clear all default highlight groups and load the defaults.
      for (int j = 0; j < highlight_ga.ga_len; j++) {
        highlight_clear(j);
      }
      init_highlight(true, true);
      highlight_changed();
      redraw_all_later(UPD_NOT_VALID);
      return;
    }
    name_end = skiptowhite(line);
    linep = skipwhite(name_end);
  }

  // Find the group name in the table.  If it does not exist yet, add it.
  int id = syn_check_group(line, (size_t)(name_end - line));
  if (id == 0) {  // Failed (out of memory).
    return;
  }
  int idx = id - 1;  // Index is ID minus one.

  // Return if "default" was used and the group already has settings
  if (dodefault && hl_has_settings(idx, true)) {
    return;
  }

  // Make a copy so we can check if any attribute actually changed
  HlGroup item_before = hl_table[idx];
  bool is_normal_group = (strcmp(hl_table[idx].sg_name_u, "NORMAL") == 0);

  // Clear the highlighting for ":hi clear {group}" and ":hi clear".
  if (doclear || (forceit && init)) {
    highlight_clear(idx);
    if (!doclear) {
      hl_table[idx].sg_set = 0;
    }
  }

  bool did_change = false;
  bool error = false;

  char key[64];
  char arg[512];
  if (!doclear) {
    const char *arg_start;

    while (!ends_excmd((uint8_t)(*linep))) {
      const char *key_start = linep;
      if (*linep == '=') {
        semsg(_(e_unexpected_equal_sign_str), key_start);
        error = true;
        break;
      }

      // Isolate the key ("term", "ctermfg", "ctermbg", "font", "guifg",
      // "guibg" or "guisp").
      while (*linep && !ascii_iswhite(*linep) && *linep != '=') {
        linep++;
      }
      size_t key_len = (size_t)(linep - key_start);
      if (key_len > sizeof(key) - 1) {
        emsg(_("E423: Illegal argument"));
        error = true;
        break;
      }
      vim_memcpy_up(key, key_start, key_len);
      key[key_len] = NUL;
      linep = skipwhite(linep);

      if (strcmp(key, "NONE") == 0) {
        if (!init || hl_table[idx].sg_set == 0) {
          if (!init) {
            hl_table[idx].sg_set |= SG_CTERM + SG_GUI;
          }
          highlight_clear(idx);
        }
        continue;
      }

      // Check for the equal sign.
      if (*linep != '=') {
        semsg(_(e_missing_equal_sign_str_2), key_start);
        error = true;
        break;
      }
      linep++;

      // Isolate the argument.
      linep = skipwhite(linep);
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
        linep = skiptowhite(linep);
      }
      if (linep == arg_start) {
        semsg(_(e_missing_argument_str), key_start);
        error = true;
        break;
      }
      size_t arg_len = (size_t)(linep - arg_start);
      if (arg_len > sizeof(arg) - 1) {
        emsg(_("E423: Illegal argument"));
        error = true;
        break;
      }
      memcpy(arg, arg_start, arg_len);
      arg[arg_len] = NUL;

      if (*linep == '\'') {
        linep++;
      }

      // Store the argument.
      if (strcmp(key, "TERM") == 0
          || strcmp(key, "CTERM") == 0
          || strcmp(key, "GUI") == 0) {
        int attr = 0;
        int off = 0;
        int i;
        while (arg[off] != NUL) {
          for (i = ARRAY_SIZE(hl_attr_table); --i >= 0;) {
            int len = (int)strlen(hl_name_table[i]);
            if (STRNICMP(arg + off, hl_name_table[i], len) == 0) {
              if (hl_attr_table[i] & HL_UNDERLINE_MASK) {
                attr &= ~HL_UNDERLINE_MASK;
              }
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
          if (!init || !(hl_table[idx].sg_set & SG_CTERM)) {
            if (!init) {
              hl_table[idx].sg_set |= SG_CTERM;
            }
            hl_table[idx].sg_cterm = attr;
            hl_table[idx].sg_cterm_bold = false;
          }
        } else if (*key == 'G') {
          if (!init || !(hl_table[idx].sg_set & SG_GUI)) {
            if (!init) {
              hl_table[idx].sg_set |= SG_GUI;
            }
            hl_table[idx].sg_gui = attr;
          }
        }
      } else if (strcmp(key, "FONT") == 0) {
        // in non-GUI fonts are simply ignored
      } else if (strcmp(key, "CTERMFG") == 0 || strcmp(key, "CTERMBG") == 0) {
        if (!init || !(hl_table[idx].sg_set & SG_CTERM)) {
          if (!init) {
            hl_table[idx].sg_set |= SG_CTERM;
          }

          // When setting the foreground color, and previously the "bold"
          // flag was set for a light color, reset it now
          if (key[5] == 'F' && hl_table[idx].sg_cterm_bold) {
            hl_table[idx].sg_cterm &= ~HL_BOLD;
            hl_table[idx].sg_cterm_bold = false;
          }

          int color;
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
            int off = TOUPPER_ASC(*arg);
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
              hl_table[idx].sg_cterm |= HL_BOLD;
              hl_table[idx].sg_cterm_bold = true;
            } else if (bold == kFalse) {
              hl_table[idx].sg_cterm &= ~HL_BOLD;
            }
          }
          // Add one to the argument, to avoid zero.  Zero is used for
          // "NONE", then "color" is -1.
          if (key[5] == 'F') {
            hl_table[idx].sg_cterm_fg = color + 1;
            if (is_normal_group) {
              cterm_normal_fg_color = color + 1;
            }
          } else {
            hl_table[idx].sg_cterm_bg = color + 1;
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
                      && !option_was_set(kOptBackground)) {
                    set_option_value_give_err(kOptBackground,
                                              CSTR_AS_OPTVAL(dark ? "dark" : "light"), 0);
                    reset_option_was_set(kOptBackground);
                  }
                }
              }
            }
          }
        }
      } else if (strcmp(key, "GUIFG") == 0) {
        int *indexp = &hl_table[idx].sg_rgb_fg_idx;

        if (!init || !(hl_table[idx].sg_set & SG_GUI)) {
          if (!init) {
            hl_table[idx].sg_set |= SG_GUI;
          }

          RgbValue old_color = hl_table[idx].sg_rgb_fg;
          int old_idx = hl_table[idx].sg_rgb_fg_idx;

          if (strcmp(arg, "NONE") != 0) {
            hl_table[idx].sg_rgb_fg = name_to_color(arg, indexp);
          } else {
            hl_table[idx].sg_rgb_fg = -1;
            hl_table[idx].sg_rgb_fg_idx = kColorIdxNone;
          }

          did_change = hl_table[idx].sg_rgb_fg != old_color || hl_table[idx].sg_rgb_fg != old_idx;
        }

        if (is_normal_group) {
          normal_fg = hl_table[idx].sg_rgb_fg;
        }
      } else if (strcmp(key, "GUIBG") == 0) {
        int *indexp = &hl_table[idx].sg_rgb_bg_idx;

        if (!init || !(hl_table[idx].sg_set & SG_GUI)) {
          if (!init) {
            hl_table[idx].sg_set |= SG_GUI;
          }

          RgbValue old_color = hl_table[idx].sg_rgb_bg;
          int old_idx = hl_table[idx].sg_rgb_bg_idx;

          if (strcmp(arg, "NONE") != 0) {
            hl_table[idx].sg_rgb_bg = name_to_color(arg, indexp);
          } else {
            hl_table[idx].sg_rgb_bg = -1;
            hl_table[idx].sg_rgb_bg_idx = kColorIdxNone;
          }

          did_change = hl_table[idx].sg_rgb_bg != old_color || hl_table[idx].sg_rgb_bg != old_idx;
        }

        if (is_normal_group) {
          normal_bg = hl_table[idx].sg_rgb_bg;
        }
      } else if (strcmp(key, "GUISP") == 0) {
        int *indexp = &hl_table[idx].sg_rgb_sp_idx;

        if (!init || !(hl_table[idx].sg_set & SG_GUI)) {
          if (!init) {
            hl_table[idx].sg_set |= SG_GUI;
          }

          RgbValue old_color = hl_table[idx].sg_rgb_sp;
          int old_idx = hl_table[idx].sg_rgb_sp_idx;

          if (strcmp(arg, "NONE") != 0) {
            hl_table[idx].sg_rgb_sp = name_to_color(arg, indexp);
          } else {
            hl_table[idx].sg_rgb_sp = -1;
          }

          did_change = hl_table[idx].sg_rgb_sp != old_color || hl_table[idx].sg_rgb_sp != old_idx;
        }

        if (is_normal_group) {
          normal_sp = hl_table[idx].sg_rgb_sp;
        }
      } else if (strcmp(key, "START") == 0 || strcmp(key, "STOP") == 0) {
        // Ignored for now
      } else if (strcmp(key, "BLEND") == 0) {
        if (strcmp(arg, "NONE") != 0) {
          hl_table[idx].sg_blend = (int)strtol(arg, NULL, 10);
        } else {
          hl_table[idx].sg_blend = -1;
        }
      } else {
        semsg(_("E423: Illegal argument: %s"), key_start);
        error = true;
        break;
      }
      hl_table[idx].sg_cleared = false;

      // When highlighting has been given for a group, don't link it.
      if (!init || !(hl_table[idx].sg_set & SG_LINK)) {
        hl_table[idx].sg_link = 0;
      }

      // Continue with next argument.
      linep = skipwhite(linep);
    }
  }

  bool did_highlight_changed = false;

  if (!error && is_normal_group) {
    // Need to update all groups, because they might be using "bg" and/or
    // "fg", which have been changed now.
    highlight_attr_set_all();

    if (!ui_has(kUILinegrid) && starting == 0) {
      // Older UIs assume that we clear the screen after normal group is
      // changed
      ui_refresh();
    } else {
      // TUI and newer UIs will repaint the screen themselves. UPD_NOT_VALID
      // redraw below will still handle usages of guibg=fg etc.
      ui_default_colors_set();
    }
    did_highlight_changed = true;
    redraw_all_later(UPD_NOT_VALID);
  } else {
    set_hl_attr(idx);
  }
  hl_table[idx].sg_script_ctx = current_sctx;
  hl_table[idx].sg_script_ctx.sc_lnum += SOURCING_LNUM;
  nlua_set_sctx(&hl_table[idx].sg_script_ctx);

  // Only call highlight_changed() once, after a sequence of highlight
  // commands, and only if an attribute actually changed
  if ((did_change
       || memcmp(&hl_table[idx], &item_before, sizeof(item_before)) != 0)
      && !did_highlight_changed) {
    // Do not trigger a redraw when highlighting is changed while
    // redrawing.  This may happen when evaluating 'statusline' changes the
    // StatusLine group.
    if (!updating_screen) {
      redraw_all_later(UPD_NOT_VALID);
    }
    need_highlight_changed = true;
  }
}

#if defined(EXITFREE)
void free_highlight(void)
{
  ga_clear(&highlight_ga);
  map_destroy(cstr_t, &highlight_unames);
  arena_mem_free(arena_finish(&highlight_arena));
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
/// @return true if highlight group "idx" has any settings.
static bool hl_has_settings(int idx, bool check_link)
{
  return hl_table[idx].sg_cleared == 0
         && (hl_table[idx].sg_attr != 0
             || hl_table[idx].sg_cterm_fg != 0
             || hl_table[idx].sg_cterm_bg != 0
             || hl_table[idx].sg_rgb_fg_idx != kColorIdxNone
             || hl_table[idx].sg_rgb_bg_idx != kColorIdxNone
             || hl_table[idx].sg_rgb_sp_idx != kColorIdxNone
             || (check_link && (hl_table[idx].sg_set & SG_LINK)));
}

/// Clear highlighting for one group.
static void highlight_clear(int idx)
{
  hl_table[idx].sg_cleared = true;

  hl_table[idx].sg_attr = 0;
  hl_table[idx].sg_cterm = 0;
  hl_table[idx].sg_cterm_bold = false;
  hl_table[idx].sg_cterm_fg = 0;
  hl_table[idx].sg_cterm_bg = 0;
  hl_table[idx].sg_gui = 0;
  hl_table[idx].sg_rgb_fg = -1;
  hl_table[idx].sg_rgb_bg = -1;
  hl_table[idx].sg_rgb_sp = -1;
  hl_table[idx].sg_rgb_fg_idx = kColorIdxNone;
  hl_table[idx].sg_rgb_bg_idx = kColorIdxNone;
  hl_table[idx].sg_rgb_sp_idx = kColorIdxNone;
  hl_table[idx].sg_blend = -1;
  // Restore default link and context if they exist. Otherwise clears.
  hl_table[idx].sg_link = hl_table[idx].sg_deflink;
  // Since we set the default link, set the location to where the default
  // link was set.
  hl_table[idx].sg_script_ctx = hl_table[idx].sg_deflink_sctx;
}

/// \addtogroup LIST_XXX
/// @{
#define LIST_ATTR   1
#define LIST_STRING 2
#define LIST_INT    3
/// @}

static void highlight_list_one(const int id)
{
  const HlGroup *sgp = &hl_table[id - 1];  // index is ID minus one
  bool didh = false;

  if (message_filtered(sgp->sg_name)) {
    return;
  }

  // don't list specialized groups if a parent is used instead
  if (sgp->sg_parent && sgp->sg_cleared) {
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
  char hexbuf[8];
  didh = highlight_list_arg(id, didh, LIST_STRING, 0,
                            coloridx_to_name(sgp->sg_rgb_fg_idx, sgp->sg_rgb_fg, hexbuf), "guifg");
  didh = highlight_list_arg(id, didh, LIST_STRING, 0,
                            coloridx_to_name(sgp->sg_rgb_bg_idx, sgp->sg_rgb_bg, hexbuf), "guibg");
  didh = highlight_list_arg(id, didh, LIST_STRING, 0,
                            coloridx_to_name(sgp->sg_rgb_sp_idx, sgp->sg_rgb_sp, hexbuf), "guisp");

  didh = highlight_list_arg(id, didh, LIST_INT,
                            sgp->sg_blend + 1, NULL, "blend");

  if (sgp->sg_link && !got_int) {
    syn_list_header(didh, 0, id, true);
    didh = true;
    msg_puts_hl("links to", HLF_D, false);
    msg_putchar(' ');
    msg_outtrans(hl_table[hl_table[id - 1].sg_link - 1].sg_name, 0, false);
  }

  if (!didh) {
    highlight_list_arg(id, didh, LIST_STRING, 0, "cleared", "");
  }
  if (p_verbose > 0) {
    last_set_msg(sgp->sg_script_ctx);
  }
}

static bool hlgroup2dict(Dict *hl, NS ns_id, int hl_id, Arena *arena)
{
  HlGroup *sgp = &hl_table[hl_id - 1];
  int link = ns_id == 0 ? sgp->sg_link : ns_get_hl(&ns_id, hl_id, true, sgp->sg_set);
  if (link == -1) {
    return false;
  }
  if (ns_id == 0 && sgp->sg_cleared && sgp->sg_set == 0) {
    // table entry was created but not ever set
    return false;
  }
  HlAttrs attr =
    syn_attr2entry(ns_id == 0 ? sgp->sg_attr : ns_get_hl(&ns_id, hl_id, false, sgp->sg_set));
  *hl = arena_dict(arena, HLATTRS_DICT_SIZE + 1);
  if (attr.rgb_ae_attr & HL_DEFAULT) {
    PUT_C(*hl, "default", BOOLEAN_OBJ(true));
  }
  if (link > 0) {
    assert(1 <= link && link <= highlight_ga.ga_len);
    PUT_C(*hl, "link", CSTR_AS_OBJ(hl_table[link - 1].sg_name));
  }
  Dict hl_cterm = arena_dict(arena, HLATTRS_DICT_SIZE);
  hlattrs2dict(hl, NULL, attr, true, true);
  hlattrs2dict(hl, &hl_cterm, attr, false, true);
  if (kv_size(hl_cterm)) {
    PUT_C(*hl, "cterm", DICT_OBJ(hl_cterm));
  }
  return true;
}

Dict ns_get_hl_defs(NS ns_id, Dict(get_highlight) *opts, Arena *arena, Error *err)
{
  Boolean link = GET_BOOL_OR_TRUE(opts, get_highlight, link);
  int id = -1;
  if (HAS_KEY(opts, get_highlight, name)) {
    Boolean create = GET_BOOL_OR_TRUE(opts, get_highlight, create);
    id = create ? syn_check_group(opts->name.data, opts->name.size)
                : syn_name2id_len(opts->name.data, opts->name.size);
    if (id == 0 && !create) {
      Dict attrs = ARRAY_DICT_INIT;
      return attrs;
    }
  } else if (HAS_KEY(opts, get_highlight, id)) {
    id = (int)opts->id;
  }

  if (id != -1) {
    VALIDATE(1 <= id && id <= highlight_ga.ga_len, "%s", "Highlight id out of bounds", {
      goto cleanup;
    });
    Dict attrs = ARRAY_DICT_INIT;
    hlgroup2dict(&attrs, ns_id, link ? id : syn_get_final_id(id), arena);
    return attrs;
  }
  if (ERROR_SET(err)) {
    goto cleanup;
  }

  Dict rv = arena_dict(arena, (size_t)highlight_ga.ga_len);
  for (int i = 1; i <= highlight_ga.ga_len; i++) {
    Dict attrs = ARRAY_DICT_INIT;
    if (!hlgroup2dict(&attrs, ns_id, i, arena)) {
      continue;
    }
    PUT_C(rv, hl_table[(link ? i : syn_get_final_id(i)) - 1].sg_name, DICT_OBJ(attrs));
  }

  return rv;

cleanup:
  return (Dict)ARRAY_DICT_INIT;
}

/// Outputs a highlight when doing ":hi MyHighlight"
///
/// @param type one of \ref LIST_XXX
/// @param iarg integer argument used if \p type == LIST_INT
/// @param sarg string used if \p type == LIST_STRING
static bool highlight_list_arg(const int id, bool didh, const int type, int iarg, const char *sarg,
                               const char *const name)
{
  if (got_int) {
    return false;
  }

  if (type == LIST_STRING ? (sarg == NULL) : (iarg == 0)) {
    return didh;
  }

  char buf[100];
  const char *ts = buf;
  if (type == LIST_INT) {
    snprintf(buf, sizeof(buf), "%d", iarg - 1);
  } else if (type == LIST_STRING) {
    ts = sarg;
  } else {    // type == LIST_ATTR
    buf[0] = NUL;
    for (int i = 0; hl_attr_table[i] != 0; i++) {
      if (((hl_attr_table[i] & HL_UNDERLINE_MASK)
           && ((iarg & HL_UNDERLINE_MASK) == hl_attr_table[i]))
          || (!(hl_attr_table[i] & HL_UNDERLINE_MASK)
              && (iarg & hl_attr_table[i]))) {
        if (buf[0] != NUL) {
          xstrlcat(buf, ",", 100);
        }
        xstrlcat(buf, hl_name_table[i], 100);
        if (!(hl_attr_table[i] & HL_UNDERLINE_MASK)) {
          iarg &= ~hl_attr_table[i];  // don't want "inverse"
        }
      }
    }
  }

  syn_list_header(didh, vim_strsize(ts) + (int)strlen(name) + 1, id, false);
  didh = true;
  if (!got_int) {
    if (*name != NUL) {
      msg_puts_hl(name, HLF_D, false);
      msg_puts_hl("=", HLF_D, false);
    }
    msg_outtrans(ts, 0, false);
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
  if (id <= 0 || id > highlight_ga.ga_len) {
    return NULL;
  }

  int attr;

  if (modec == 'g') {
    attr = hl_table[id - 1].sg_gui;
  } else {
    attr = hl_table[id - 1].sg_cterm;
  }

  if (flag & HL_UNDERLINE_MASK) {
    int ul = attr & HL_UNDERLINE_MASK;
    return ul == flag ? "1" : NULL;
  } else {
    return (attr & flag) ? "1" : NULL;
  }
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

  int n;

  if (modec == 'g') {
    if (what[2] == '#' && ui_rgb_attached()) {
      if (fg) {
        n = hl_table[id - 1].sg_rgb_fg;
      } else if (sp) {
        n = hl_table[id - 1].sg_rgb_sp;
      } else {
        n = hl_table[id - 1].sg_rgb_bg;
      }
      if (n < 0 || n > 0xffffff) {
        return NULL;
      }
      snprintf(name, sizeof(name), "#%06x", n);
      return name;
    }
    if (fg) {
      return coloridx_to_name(hl_table[id - 1].sg_rgb_fg_idx, hl_table[id - 1].sg_rgb_fg, name);
    } else if (sp) {
      return coloridx_to_name(hl_table[id - 1].sg_rgb_sp_idx, hl_table[id - 1].sg_rgb_sp, name);
    } else {
      return coloridx_to_name(hl_table[id - 1].sg_rgb_bg_idx, hl_table[id - 1].sg_rgb_bg, name);
    }
  }
  if (font || sp) {
    return NULL;
  }
  if (modec == 'c') {
    if (fg) {
      n = hl_table[id - 1].sg_cterm_fg - 1;
    } else {
      n = hl_table[id - 1].sg_cterm_bg - 1;
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
    msg_col = name_col = msg_outtrans(hl_table[id - 1].sg_name, 0, false);
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
    msg_puts_hl("xxx", id, false);
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
  HlGroup *sgp = hl_table + idx;

  at_en.cterm_ae_attr = (int16_t)sgp->sg_cterm;
  at_en.cterm_fg_color = (int16_t)sgp->sg_cterm_fg;
  at_en.cterm_bg_color = (int16_t)sgp->sg_cterm_bg;
  at_en.rgb_ae_attr = (int16_t)sgp->sg_gui;
  // FIXME(tarruda): The "unset value" for rgb is -1, but since hlgroup is
  // initialized with 0 (by garray functions), check for sg_rgb_{f,b}g_name
  // before setting attr_entry->{f,g}g_color to a other than -1
  at_en.rgb_fg_color = sgp->sg_rgb_fg_idx != kColorIdxNone ? sgp->sg_rgb_fg : -1;
  at_en.rgb_bg_color = sgp->sg_rgb_bg_idx != kColorIdxNone ? sgp->sg_rgb_bg : -1;
  at_en.rgb_sp_color = sgp->sg_rgb_sp_idx != kColorIdxNone ? sgp->sg_rgb_sp : -1;
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
  if (name[0] == '@') {
    // if we look up @aaa.bbb, we have to consider @aaa as well
    return syn_check_group(name, strlen(name));
  }
  return syn_name2id_len(name, strlen(name));
}

/// Lookup a highlight group name and return its ID.
///
/// @param highlight name e.g. 'Cursor', 'Normal'
/// @return the highlight id, else 0 if \p name does not exist
int syn_name2id_len(const char *name, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  char name_u[MAX_SYN_NAME + 1];

  if (len == 0 || len > MAX_SYN_NAME) {
    return 0;
  }

  // Avoid using stricmp() too much, it's slow on some systems
  // Avoid alloc()/free(), these are slow too.
  vim_memcpy_up(name_u, name, len);
  name_u[len] = NUL;

  // map_get(..., int) returns 0 when no key is present, which is
  // the expected value for missing highlight group.
  return map_get(cstr_t, int)(&highlight_unames, name_u);
}

/// Lookup a highlight group name and return its attributes.
/// Return zero if not found.
int syn_name2attr(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  int id = syn_name2id(name);

  if (id != 0) {
    return syn_id2attr(id);
  }
  return 0;
}

/// Return true if highlight group "name" exists.
int highlight_exists(const char *name)
{
  return syn_name2id(name) > 0;
}

/// Return the name of highlight group "id".
/// When not a valid ID return an empty string.
char *syn_id2name(int id)
{
  if (id <= 0 || id > highlight_ga.ga_len) {
    return "";
  }
  return hl_table[id - 1].sg_name;
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
  int id = syn_name2id_len(name, len);
  if (id == 0) {  // doesn't exist yet
    return syn_add_group(name, len);
  }
  return id;
}

/// Add new highlight group and return its ID.
///
/// @param name must be an allocated string, it will be consumed.
/// @return 0 for failure, else the allocated group id
/// @see syn_check_group
static int syn_add_group(const char *name, size_t len)
{
  // Check that the name is valid (ASCII letters, digits, '_', '.', '@', '-').
  for (size_t i = 0; i < len; i++) {
    int c = (uint8_t)name[i];
    if (!vim_isprintc(c)) {
      emsg(_("E669: Unprintable character in group name"));
      return 0;
    } else if (!ASCII_ISALNUM(c) && c != '_' && c != '.' && c != '@' && c != '-') {
      // '.' and '@' are allowed characters for use with treesitter capture names.
      msg_source(HLF_W);
      emsg(_(e_highlight_group_name_invalid_char));
      return 0;
    }
  }

  int scoped_parent = 0;
  if (len > 1 && name[0] == '@') {
    char *delim = xmemrchr(name, '.', len);
    if (delim) {
      scoped_parent = syn_check_group(name, (size_t)(delim - name));
    }
  }

  // First call for this growarray: init growing array.
  if (highlight_ga.ga_data == NULL) {
    highlight_ga.ga_itemsize = sizeof(HlGroup);
    ga_set_growsize(&highlight_ga, 10);
    // 265 builtin groups, will always be used, plus some space
    ga_grow(&highlight_ga, 300);
  }

  if (highlight_ga.ga_len >= MAX_HL_ID) {
    emsg(_("E849: Too many highlight and syntax groups"));
    return 0;
  }

  // Append another syntax_highlight entry.
  HlGroup *hlgp = GA_APPEND_VIA_PTR(HlGroup, &highlight_ga);
  CLEAR_POINTER(hlgp);
  hlgp->sg_name = arena_memdupz(&highlight_arena, name, len);
  hlgp->sg_rgb_bg = -1;
  hlgp->sg_rgb_fg = -1;
  hlgp->sg_rgb_sp = -1;
  hlgp->sg_rgb_bg_idx = kColorIdxNone;
  hlgp->sg_rgb_fg_idx = kColorIdxNone;
  hlgp->sg_rgb_sp_idx = kColorIdxNone;
  hlgp->sg_blend = -1;
  hlgp->sg_name_u = arena_memdupz(&highlight_arena, name, len);
  hlgp->sg_parent = scoped_parent;
  // will get set to false by caller if settings are added
  hlgp->sg_cleared = true;
  vim_strup(hlgp->sg_name_u);

  int id = highlight_ga.ga_len;  // ID is index plus one

  map_put(cstr_t, int)(&highlight_unames, hlgp->sg_name_u, id);

  return id;
}

/// Translate a group ID to highlight attributes.
/// @see syn_attr2entry
int syn_id2attr(int hl_id)
{
  bool optional = false;
  return syn_ns_id2attr(-1, hl_id, &optional);
}

int syn_ns_id2attr(int ns_id, int hl_id, bool *optional)
  FUNC_ATTR_NONNULL_ALL
{
  if (syn_ns_get_final_id(&ns_id, &hl_id)) {
    // If the namespace explicitly defines a group to be empty, it is not optional
    *optional = false;
  }
  HlGroup *sgp = &hl_table[hl_id - 1];  // index is ID minus one

  int attr = ns_get_hl(&ns_id, hl_id, false, sgp->sg_set);

  // if a highlight group is optional, don't use the global value
  if (attr >= 0 || (*optional && ns_id > 0)) {
    return attr;
  }
  return sgp->sg_attr;
}

/// Translate a group ID to the final group ID (following links).
int syn_get_final_id(int hl_id)
{
  int ns_id = curwin->w_ns_hl_active;
  syn_ns_get_final_id(&ns_id, &hl_id);
  return hl_id;
}

bool syn_ns_get_final_id(int *ns_id, int *hl_idp)
{
  int hl_id = *hl_idp;
  bool used = false;

  if (hl_id > highlight_ga.ga_len || hl_id < 1) {
    *hl_idp = 0;
    return false;  // Can be called from eval!!
  }

  // Follow links until there is no more.
  // Look out for loops!  Break after 100 links.
  for (int count = 100; --count >= 0;) {
    HlGroup *sgp = &hl_table[hl_id - 1];  // index is ID minus one

    // TODO(bfredl): when using "tmp" attribute (no link) the function might be
    // called twice. it needs be smart enough to remember attr only to
    // syn_id2attr time
    int check = ns_get_hl(ns_id, hl_id, true, sgp->sg_set);
    if (check == 0) {
      *hl_idp = hl_id;
      return true;  // how dare! it broke the link!
    } else if (check > 0) {
      used = true;
      hl_id = check;
      continue;
    }

    if (sgp->sg_link > 0 && sgp->sg_link <= highlight_ga.ga_len) {
      hl_id = sgp->sg_link;
    } else if (sgp->sg_cleared && sgp->sg_parent > 0) {
      hl_id = sgp->sg_parent;
    } else {
      break;
    }
  }

  *hl_idp = hl_id;
  return used;
}

/// Refresh the color attributes of all highlight groups.
void highlight_attr_set_all(void)
{
  for (int idx = 0; idx < highlight_ga.ga_len; idx++) {
    HlGroup *sgp = &hl_table[idx];
    if (sgp->sg_rgb_bg_idx == kColorIdxFg) {
      sgp->sg_rgb_bg = normal_fg;
    } else if (sgp->sg_rgb_bg_idx == kColorIdxBg) {
      sgp->sg_rgb_bg = normal_bg;
    }
    if (sgp->sg_rgb_fg_idx == kColorIdxFg) {
      sgp->sg_rgb_fg = normal_fg;
    } else if (sgp->sg_rgb_fg_idx == kColorIdxBg) {
      sgp->sg_rgb_fg = normal_bg;
    }
    if (sgp->sg_rgb_sp_idx == kColorIdxFg) {
      sgp->sg_rgb_sp = normal_fg;
    } else if (sgp->sg_rgb_sp_idx == kColorIdxBg) {
      sgp->sg_rgb_sp = normal_bg;
    }
    set_hl_attr(idx);
  }
}

// Apply difference between User[1-9] and HLF_S to HLF_SNC.
static void combine_stl_hlt(int id, int id_S, int id_alt, int hlcnt, int i, int hlf, int *table)
  FUNC_ATTR_NONNULL_ALL
{
  HlGroup *const hlt = hl_table;

  if (id_alt == 0) {
    CLEAR_POINTER(&hlt[hlcnt + i]);
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
  char userhl[30];  // use 30 to avoid compiler warning
  int id_S = -1;
  int id_SNC = 0;

  need_highlight_changed = false;

  // sentinel value. used when no highlight is active
  highlight_attr[HLF_NONE] = 0;

  /// Translate builtin highlight groups into attributes for quick lookup.
  for (int hlf = 1; hlf < HLF_COUNT; hlf++) {
    int id = syn_check_group(hlf_names[hlf], strlen(hlf_names[hlf]));
    if (id == 0) {
      abort();
    }
    int ns_id = -1;
    int final_id = id;
    syn_ns_get_final_id(&ns_id, &final_id);
    if (hlf == HLF_SNC) {
      id_SNC = final_id;
    } else if (hlf == HLF_S) {
      id_S = final_id;
    }

    highlight_attr[hlf] = hl_get_ui_attr(ns_id, hlf, final_id, hlf == HLF_INACTIVE);

    if (highlight_attr[hlf] != highlight_attr_last[hlf]) {
      if (hlf == HLF_MSG) {
        clear_cmdline = true;
        HlAttrs attrs = syn_attr2entry(highlight_attr[hlf]);
        msg_grid.blending = attrs.hl_blend > -1;
      }
      ui_call_hl_group_set(cstr_as_string(hlf_names[hlf]),
                           highlight_attr[hlf]);
      highlight_attr_last[hlf] = highlight_attr[hlf];
    }
  }

  // Setup the user highlights
  //
  // Temporarily utilize 10 more hl entries:
  // 9 for User1-User9 combined with StatusLineNC
  // 1 for StatusLine default
  // Must to be in there simultaneously in case of table overflows in
  // get_attr_entry()
  ga_grow(&highlight_ga, 10);
  int hlcnt = highlight_ga.ga_len;
  if (id_S == -1) {
    // Make sure id_S is always valid to simplify code below. Use the last entry
    CLEAR_POINTER(&hl_table[hlcnt + 9]);
    id_S = hlcnt + 10;
  }
  for (int i = 0; i < 9; i++) {
    snprintf(userhl, sizeof(userhl), "User%d", i + 1);
    int id = syn_name2id(userhl);
    if (id == 0) {
      highlight_user[i] = 0;
      highlight_stlnc[i] = 0;
    } else {
      highlight_user[i] = syn_id2attr(id);
      combine_stl_hlt(id, id_S, id_SNC, hlcnt, i, HLF_SNC, highlight_stlnc);
    }
  }
  highlight_ga.ga_len = hlcnt;

  decor_provider_invalidate_hl();
}

/// Handle command line completion for :highlight command.
void set_context_in_highlight_cmd(expand_T *xp, const char *arg)
{
  // Default: expand group names.
  xp->xp_context = EXPAND_HIGHLIGHT;
  xp->xp_pattern = (char *)arg;
  include_link = 2;
  include_default = 1;

  if (*arg == NUL) {
    return;
  }

  // (part of) subcommand already typed
  const char *p = skiptowhite(arg);
  if (*p == NUL) {
    return;
  }

  // past "default" or group name
  include_default = 0;
  if (strncmp("default", arg, (unsigned)(p - arg)) == 0) {
    arg = skipwhite(p);
    xp->xp_pattern = (char *)arg;
    p = skiptowhite(arg);
  }
  if (*p == NUL) {
    return;
  }

  // past group name
  include_link = 0;
  if (arg[1] == 'i' && arg[0] == 'N') {
    highlight_list();
  }
  if (strncmp("link", arg, (unsigned)(p - arg)) == 0
      || strncmp("clear", arg, (unsigned)(p - arg)) == 0) {
    xp->xp_pattern = skipwhite(p);
    p = skiptowhite(xp->xp_pattern);
    if (*p != NUL) {  // past first group name
      xp->xp_pattern = skipwhite(p);
      p = skiptowhite(xp->xp_pattern);
    }
  }
  if (*p != NUL) {  // past group name(s)
    xp->xp_context = EXPAND_NOTHING;
  }
}

/// List highlighting matches in a nice way.
static void highlight_list(void)
{
  for (int i = 10; --i >= 0;) {
    highlight_list_two(i, HLF_D);
  }
  for (int i = 40; --i >= 0;) {
    highlight_list_two(99, 0);
  }
}

static void highlight_list_two(int cnt, int id)
{
  msg_puts_hl(&("N \bI \b!  \b"[cnt / 11]), id, false);
  msg_clr_eos();
  ui_flush();
  os_delay(cnt == 99 ? 40 : (uint64_t)cnt * 50, false);
}

/// Function given to ExpandGeneric() to obtain the list of group names.
char *get_highlight_name(expand_T *const xp, int idx)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (char *)get_highlight_name_ext(xp, idx, true);
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
  if (skip_cleared && idx < highlight_ga.ga_len && hl_table[idx].sg_cleared) {
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
  return hl_table[idx].sg_name;
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
  { "DarkGoldenrod", RGB_(0xb8, 0x86, 0x0b) },
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
  { "Goldenrod", RGB_(0xda, 0xa5, 0x20) },
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
  { "LightGoldenrodYellow", RGB_(0xfa, 0xfa, 0xd2) },
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
  // Default Neovim palettes.
  // Dark/light palette is used for background in dark/light color scheme and
  // for foreground in light/dark color scheme.
  { "NvimDarkBlue", RGB_(0x00, 0x4c, 0x73) },
  { "NvimDarkCyan", RGB_(0x00, 0x73, 0x73) },
  { "NvimDarkGray1", RGB_(0x07, 0x08, 0x0d) },
  { "NvimDarkGray2", RGB_(0x14, 0x16, 0x1b) },
  { "NvimDarkGray3", RGB_(0x2c, 0x2e, 0x33) },
  { "NvimDarkGray4", RGB_(0x4f, 0x52, 0x58) },
  { "NvimDarkGreen", RGB_(0x00, 0x55, 0x23) },
  { "NvimDarkGrey1", RGB_(0x07, 0x08, 0x0d) },
  { "NvimDarkGrey2", RGB_(0x14, 0x16, 0x1b) },
  { "NvimDarkGrey3", RGB_(0x2c, 0x2e, 0x33) },
  { "NvimDarkGrey4", RGB_(0x4f, 0x52, 0x58) },
  { "NvimDarkMagenta", RGB_(0x47, 0x00, 0x45) },
  { "NvimDarkRed", RGB_(0x59, 0x00, 0x08) },
  { "NvimDarkYellow", RGB_(0x6b, 0x53, 0x00) },
  { "NvimLightBlue", RGB_(0xa6, 0xdb, 0xff) },
  { "NvimLightCyan", RGB_(0x8c, 0xf8, 0xf7) },
  { "NvimLightGray1", RGB_(0xee, 0xf1, 0xf8) },
  { "NvimLightGray2", RGB_(0xe0, 0xe2, 0xea) },
  { "NvimLightGray3", RGB_(0xc4, 0xc6, 0xcd) },
  { "NvimLightGray4", RGB_(0x9b, 0x9e, 0xa4) },
  { "NvimLightGreen", RGB_(0xb3, 0xf6, 0xc0) },
  { "NvimLightGrey1", RGB_(0xee, 0xf1, 0xf8) },
  { "NvimLightGrey2", RGB_(0xe0, 0xe2, 0xea) },
  { "NvimLightGrey3", RGB_(0xc4, 0xc6, 0xcd) },
  { "NvimLightGrey4", RGB_(0x9b, 0x9e, 0xa4) },
  { "NvimLightMagenta", RGB_(0xff, 0xca, 0xff) },
  { "NvimLightRed", RGB_(0xff, 0xc0, 0xb9) },
  { "NvimLightYellow", RGB_(0xfc, 0xe0, 0x94) },
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
  { "PaleGoldenrod", RGB_(0xee, 0xe8, 0xaa) },
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
/// @param[out] idx index in color table or special value
/// return the hex value or -1 if could not find a correct value
RgbValue name_to_color(const char *name, int *idx)
{
  if (name[0] == '#' && isxdigit((uint8_t)name[1]) && isxdigit((uint8_t)name[2])
      && isxdigit((uint8_t)name[3]) && isxdigit((uint8_t)name[4]) && isxdigit((uint8_t)name[5])
      && isxdigit((uint8_t)name[6]) && name[7] == NUL) {
    // rgb hex string
    *idx = kColorIdxHex;
    return (RgbValue)strtol(name + 1, NULL, 16);
  } else if (!STRICMP(name, "bg") || !STRICMP(name, "background")) {
    *idx = kColorIdxBg;
    return normal_bg;
  } else if (!STRICMP(name, "fg") || !STRICMP(name, "foreground")) {
    *idx = kColorIdxFg;
    return normal_fg;
  }

  int lo = 0;
  int hi = ARRAY_SIZE(color_name_table) - 1;  // don't count NULL element
  while (lo < hi) {
    int m = (lo + hi) / 2;
    int cmp = STRICMP(name, color_name_table[m].name);
    if (cmp < 0) {
      hi = m;
    } else if (cmp > 0) {
      lo = m + 1;
    } else {  // found match
      *idx = m;
      return color_name_table[m].color;
    }
  }

  *idx = kColorIdxNone;
  return -1;
}

const char *coloridx_to_name(int idx, int val, char hexbuf[8])
{
  if (idx >= 0) {
    return color_name_table[idx].name;
  }
  switch (idx) {
  case kColorIdxNone:
    return NULL;
  case kColorIdxFg:
    return "fg";
  case kColorIdxBg:
    return "bg";
  case kColorIdxHex:
    snprintf(hexbuf, 7 + 1, "#%06x", val);
    return hexbuf;
  default:
    abort();
  }
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
