-- biscide's colours: the UI's after JetBrains' Islands Dark, the code's in
-- the palette biscide paints tree-sitter's captures with.
vim.cmd("highlight clear")
vim.g.colors_name = "biscide"
vim.o.background = "dark"

local function hl(group, spec)
  vim.api.nvim_set_hl(0, group, spec)
end

local ui = {
  Normal = { fg = "#BCBEC4", bg = "#1E1F22" },
  NormalFloat = { link = "Normal" },
  NormalNC = { link = "Normal" },
  EndOfBuffer = { fg = "#1E1F22" },
  NonText = { fg = "#4B5059" },
  Visual = { bg = "#214283" },
  Search = { bg = "#114957" },
  IncSearch = { bg = "#32593D" },
  CurSearch = { bg = "#32593D" },
  MatchParen = { bg = "#43454A", bold = true },
  Pmenu = { fg = "#BCBEC4", bg = "#2B2D30" },
  PmenuSel = { bg = "#2E436E" },
  CursorLine = { bg = "#2A4371" },
  ErrorMsg = { fg = "#F75464" },
  WarningMsg = { fg = "#E0BB65" },
  MsgArea = { fg = "#9FA2A8", bg = "#26282C" },
  ModeMsg = { fg = "#3871E1" },
  Directory = { fg = "#C3C5CB" },
  BiscideGoFile = { fg = "#2AACB8" },
  BiscideRustFile = { fg = "#CF8E6D" },
  Comment = { fg = "#7A7E85" },
}
for group, spec in pairs(ui) do
  hl(group, spec)
end

-- Each capture biscide knows, in its colour.
local keyword, str, number, comment = "#CF8E6D", "#6AAB73", "#2AACB8", "#7A7E85"
local ty, fn, prop, plain, attr = "#2FBAA3", "#56A8F5", "#C77DBB", "#BCBEC4", "#32B8AF"
local captures = {
  attribute = attr,
  comment = comment,
  constant = prop,
  ["constant.builtin"] = keyword,
  constructor = ty,
  escape = keyword,
  ["string.escape"] = keyword,
  ["function"] = fn,
  ["function.builtin"] = fn,
  ["function.macro"] = fn,
  ["function.method"] = fn,
  keyword = keyword,
  label = attr,
  number = number,
  operator = plain,
  property = prop,
  punctuation = plain,
  string = str,
  type = ty,
  ["type.builtin"] = keyword,
  variable = plain,
  ["variable.builtin"] = plain,
  ["variable.parameter"] = plain,
}
for capture, color in pairs(captures) do
  hl("@" .. capture, { fg = color })
end

-- Vim's syntax groups (a file without a parser), as the captures.
local syntax = {
  String = "@string", Character = "@string", Number = "@number", Float = "@number",
  Boolean = "@constant.builtin", Constant = "@constant", Keyword = "@keyword",
  Statement = "@keyword", Conditional = "@keyword", Repeat = "@keyword",
  Exception = "@keyword", StorageClass = "@keyword", Structure = "@keyword",
  Include = "@keyword", Function = "@function", Type = "@type", Typedef = "@type",
  Identifier = "@variable", Operator = "@operator", Delimiter = "@punctuation",
  Special = "@escape", SpecialChar = "@escape", PreProc = "@attribute", Label = "@label",
}
for group, capture in pairs(syntax) do
  hl(group, { link = capture })
end
