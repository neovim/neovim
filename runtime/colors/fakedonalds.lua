vim.o.background = 'dark'

vim.cmd.highlight 'clear'
if vim.g.syntax_on then vim.cmd.syntax 'reset' end

vim.g.colors_name = 'fakedonalds'

local McRed='#c1192a'
local McYellow='#fdaf17'
local McWhite='#ffffff'

vim.g.terminal_color_0 = McYellow
vim.g.terminal_color_1 = McYellow
vim.g.terminal_color_2 = McYellow
vim.g.terminal_color_3 = McYellow
vim.g.terminal_color_4 = McYellow
vim.g.terminal_color_5 = McWhite
vim.g.terminal_color_6 = McYellow
vim.g.terminal_color_7 = McYellow
vim.g.terminal_color_8 = McYellow
vim.g.terminal_color_9 = McYellow
vim.g.terminal_color_10 = McYellow
vim.g.terminal_color_11 = McYellow
vim.g.terminal_color_12 = McYellow
vim.g.terminal_color_13 = McWhite
vim.g.terminal_color_14 = McYellow
vim.g.terminal_color_15 = McYellow

local theme = {
  -- base
  Bold = { fg = McWhite, bold = true },
  Italic = { fg = McWhite, italic = true },
  Underlined = { fg = McYellow, special = McYellow, underline = true },

  Normal = { fg = McYellow, bg = McRed },
  Visual = { bg = McYellow },
  VisualNOS = { bg = McYellow },
  Search = { fg = McYellow, bg = McYellow },
  IncSearch = { fg = McYellow, bg = McYellow },
  CurSearch = { fg = McYellow, bg = McYellow },
  MatchParen = { fg = McYellow, bg = McYellow },

  NonText = { fg = McYellow },
  Whitespace = { fg = McYellow },
  EndOfBuffer = { fg = McYellow },

  Question = { fg = McYellow },
  Title = { fg = McYellow },
  Directory = { fg = McYellow },
  SpecialKey = { fg = McYellow },
  ErrorMsg = { fg = McYellow },
  WarningMsg = { fg = McYellow },
  ModeMsg = { fg = McWhite },
  MoreMsg = { fg = McYellow },
  MsgSeparator = { bg = McYellow },
  MsgArea = { link = 'Normal' },

  Cursor = { fg = McRed, bg = McWhite },
  iCursor = { fg = McRed, bg = McWhite },
  TermCursorNC = { bg = McYellow },
  CursorColumn = { bg = McYellow },
  CursorLine = { bg = McYellow },
  CursorLineNr = { fg = McWhite, bg = McYellow },
  ColorColumn = { bg = McYellow },
  LineNr = { fg = McYellow },
  SignColumn = { fg = McYellow, bg = McRed },

  WinSeparator = { fg = McYellow },

  TabLine = { fg = McYellow, bg = McYellow },
  TabLineSel = { fg = McYellow, bg = McYellow },
  TabLineFill = { fg = McYellow, bg = McYellow },

  Pmenu = { fg = McWhite, bg = McYellow },
  PmenuSel = { fg = McYellow, bg = McYellow },
  PmenuSbar = { bg = McYellow },
  PmenuThumb = { bg = McYellow },
  Wildmenu = { link = 'Pmenu' },

  NormalFloat = { link = 'Normal' },
  FloatBorder = { fg = McYellow, bg = McRed },

  SpellBad = { fg = McYellow, bg = McRed, special = McYellow, undercurl = true },
  SpellCap = { fg = McYellow, bg = McRed, special = McYellow, undercurl = true },
  SpellLocal = { fg = McYellow, bg = McRed, special = McYellow, undercurl = true },
  SpellRare = { fg = McYellow, bg = McRed, special = McYellow, undercurl = true },

  DiagnosticError = { fg = McYellow },
  DiagnosticWarn = { fg = McYellow },
  DiagnosticInfo = { fg = McYellow },
  DiagnosticHint = { fg = McYellow },

  DiagnosticVirtualTextError = { fg = McYellow, italic = true },
  DiagnosticVirtualTextWarn = { fg = McYellow, italic = true },
  DiagnosticVirtualTextInfo = { fg = McYellow, italic = true },
  DiagnosticVirtualTextHint = { fg = McYellow, italic = true },

  DiagnosticUnderlineError = { special = McYellow, underline = true },
  DiagnosticUnderlineWarn = { special = McYellow, underline = true },
  DiagnosticUnderlineInfo = { special = McYellow, underline = true },
  DiagnosticUnderlineHint = { special = McYellow, underline = true },

  healthError = { fg = McYellow, bg = McRed },
  healthSuccess = { fg = McYellow, bg = McRed },
  healthWarning = { fg = McYellow, bg = McRed },

  -- builtin
  Boolean = { fg = McWhite },
  Character = { fg = McYellow },
  Comment = { fg = McYellow, italic = true },
  Conditional = { fg = McYellow },
  Constant = { fg = McWhite },
  Decorator = { fg = McYellow },
  Debug = { fg = McYellow },
  Define = { fg = McYellow },
  Delimiter = { fg = McYellow },
  Error = { fg = McYellow, bg = McRed },
  Exception = { fg = McYellow },
  Float = { fg = McWhite },
  Function = { fg = McYellow },
  Identifier = { fg = McWhite },
  Include = { fg = McYellow },
  Keyword = { fg = McYellow },
  Label = { fg = McYellow },
  Macro = { fg = McYellow },
  Number = { fg = McWhite },
  Operator = { fg = McYellow },
  PreCondit = { fg = McYellow },
  PreProc = { fg = McYellow },
  Repeat = { fg = McYellow },
  Special = { fg = McWhite },
  SpecialChar = { fg = McYellow },
  SpecialComment = { fg = McYellow, italic = true },
  Statement = { fg = McYellow },
  StorageClass = { fg = McYellow },
  String = { fg = McYellow },
  Structure = { fg = McYellow },
  Tag = { fg = McYellow },
  Todo = { fg = McYellow, bg = McYellow },
  Type = { fg = McYellow },
  Typedef = { fg = McYellow },

  DiffAdd = { fg = McYellow, bg = McYellow },
  DiffChange = { fg = McYellow, bg = McYellow },
  DiffDelete = { fg = McYellow, bg = McYellow },
  DiffText = { fg = McYellow, bg = McYellow },
  diffAdded = { link = 'DiffAdd' },
  diffRemoved = { link = 'DiffDelete' },

  helpCommand = { fg = McYellow },
  helpExample = { fg = McYellow },
  helpHyperTextEntry = { fg = McYellow },
  helpHyperTextJump = { fg = McYellow, special = McYellow, underline = true },
  helpNote = { fg = McWhite },
  helpOption = { fg = McYellow },
  helpVim = { fg = McYellow },
  helpSpecial = { link = 'String' },
  helpIgnore = { link = 'Special' },
  helpBacktick = { link = 'Special' },
  helpBar = { link = 'Special' },
  helpStar = { link = 'Special' },

  vimCmdSep = { fg = McYellow },
  vimCommand = { fg = McYellow },
  vimGroup = { fg = McYellow },
  vimHiGroup = { fg = McYellow },
  vimIsCommand = { fg = McYellow },
  vimSynMtchOpt = { fg = McYellow },
  vimSynType = { fg = McYellow },
  vimFuncName = { fg = McYellow },
  vimVar = { fg = McYellow },
  vimCommentString = { link = 'Comment' },
  vimFunc = { link = 'Function' },
  vimUserFunc = { link = 'Function' },

  pythonFunction = { fg = McYellow },
  pythonStatement = { fg = McYellow },
  pythonBuiltin = { link = 'Type' },
  pythonEscape = { link = 'SpecialChar' },

  juliaParDelim = { link = 'Delimiter' },
  juliaSemicolon = { link = 'Delimiter' },
  juliaComma = { link = 'Delimiter' },
  juliaFunctionCall = { link = 'Function' },
  juliaSymbol = { link = 'Constant' },

  markdownBlockquote = { fg = McYellow },
  markdownCode = { fg = McYellow },
  markdownCodeDelimiter = { fg = McYellow },
  markdownFootnote = { fg = McYellow },
  markdownId = { fg = McYellow },
  markdownIdDeclaration = { fg = McYellow },
  markdownH1 = { fg = McYellow },
  markdownHeadingDelimiter = { fg = McWhite },
  markdownRule = { fg = McWhite },
  markdownLinkText = { fg = McYellow },
  markdownUrl = { link = 'Underlined' },
  markdownBold = { link = 'Bold' },
  markdownItalic = { link = 'Italic' },
  markdownBoldDelimiter = { link = 'Keyword' },
  markdownItalicDelimiter = { link = 'Keyword' },
  markdownFootnoteDefinition = { link = 'markdownFootnote' },
  markdownH2 = { link = 'markdownH1' },
  markdownH3 = { link = 'markdownH1' },
  markdownH4 = { link = 'markdownH1' },
  markdownH5 = { link = 'markdownH1' },
  markdownH6 = { link = 'markdownH1' },
  markdownIdDelimiter = { link = 'Keyword' },
  markdownLinkDelimiter = { link = 'Keyword' },
  markdownLinkTextDelimiter = { link = 'Keyword' },
  markdownListMarker = { link = 'Keyword' },

  htmlArg = { fg = McYellow },
  htmlLink = { link = 'markdownUrl' },
  htmlItalic = { link = 'Italic' },
  htmlBold = { link = 'Bold' },
  htmlH1 = { link = 'markdownH1' },
  htmlH2 = { link = 'markdownH1' },
  htmlH3 = { link = 'markdownH1' },
  htmlH4 = { link = 'markdownH1' },
  htmlH5 = { link = 'markdownH1' },
  htmlH6 = { link = 'markdownH1' },
  htmlSpecialChar = { link = 'SpecialChar' },
  htmlTag = { link = 'Keyword' },
  htmlTagN = { link = 'htmlTag' },
  htmlEndTag = { link = 'htmlTag' },

  -- plugins
  GitSignsAdd = { fg = McYellow },
  GitSignsChange = { fg = McYellow },
  GitSignsChangeDelete = { fg = McYellow },
  GitSignsDelete = { fg = McYellow },
  GitSignsAddInline = { fg = McYellow, bg = McYellow },
  GitSignsChangeInline = { fg = McYellow, bg = McYellow },
  GitSignsDeleteInline = { fg = McYellow, bg = McYellow },

  gitcommitDiscardedFile = { fg = McYellow },
  gitcommitUntrackedFile = { fg = McYellow },
  gitcommitSelectedFile = { fg = McYellow },

  LspReferenceRead = { bold = true },
  LspReferenceWrite = { reverse = true },
  LspReferenceText = { link = 'LspReferenceRead' },

  TelescopeMatching = { fg = McYellow, bold = true },
  TelescopeMultiSelection = { link = 'Visual' },
  TelescopePreviewLine = { link = 'Visual' },
  TelescopePreviewMatch = { link = 'Search' },

  HopCursor = { bg = McWhite },
  HopUnmatched = { fg = McYellow },
  HopNextKey = { fg = McYellow },
  HopNextKey1 = { fg = McYellow },
  HopNextKey2 = { fg = McYellow },

  statusOuter = { fg = McYellow, bg = McYellow },
  statusMiddle = { fg = McYellow, bg = McYellow },
  statusInner = { fg = McWhite, bg = McYellow },
  statusInactive = { fg = McYellow, bg = McYellow },
  statusInsert = { fg = McRed, bg = McYellow },
  statusVisual = { fg = McRed, bg = McYellow },
  statusReplace = { fg = McRed, bg = McYellow },

  -- vimtex
  texCmd = { fg = McYellow },
  texArg = { fg = McYellow },
  texOpt = { fg = McYellow },
  texCmdSize = { link = 'texCmd' },

  -- vimtex: sectioning etc.
  texCmdPart = { fg = McYellow },
  texPartArgTitle = { fg = McYellow },
  texCmdTitle = { fg = McYellow },
  texCmdAuthor = { fg = McYellow },
  texTitleArg = { fg = McYellow, bold = true },
  texAuthorArg = { fg = McYellow, italic = true },
  texFootnoteArg = { fg = McWhite, italic = true },

  -- vimtex: environments
  texCmdEnv = { fg = McYellow },
  texEnvArgName = { fg = McYellow },
  texEnvOpt = { fg = McYellow },

  -- vimtex: math
  texMathZone = { fg = McYellow },
  texMathCmd = { fg = McYellow },
  texMathDelim = { fg = McYellow },
  texMathDelimZone = { fg = McYellow },
  texMathCmdEnv = { fg = McYellow },
  texMathEnvArgName = { fg = McYellow },
  texMathCmdText = { link = 'texCmdMathEnv' },
  texCmdMathEnv = { link = 'texMathCmdEnv' },
  texCmdEnvM = { link = 'texMathCmdEnv' },
  texEnvMArgName = { link = 'texMathCmdEnv' },

  -- vimtex: references
  texCmdRef = { fg = McYellow },
  texRefArg = { fg = McYellow },
  texRefOpt = { fg = McWhite },
  texUrlArg = { fg = McYellow, special = McYellow, underline = true },
  texCmdCRef = { link = 'texCmdRef' },
  texHrefArgLink = { link = 'texUrlArg' },
  texHrefArgText = { link = 'texOpt' },

  -- vimtex: symbols
  texSymbol = { fg = McWhite },
  texSpecialChar = { fg = McYellow },
  texDelim = { link = 'texSymbol' },
  texTabularChar = { link = 'texSymbol' },

  -- vimtex: files
  texFileArg = { fg = McWhite },
  texFileOpt = { fg = McYellow },

  -- vimtex: bib
  bibType = { fg = McYellow },
  bibKey = { fg = McYellow },
  bibEntryKw = { fg = McYellow },
  bibVariable = { fg = McYellow },
}

for k, v in pairs(theme) do
  vim.api.nvim_set_hl(0, k, v)
end
