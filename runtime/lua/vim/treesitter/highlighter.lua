local a = vim.api

-- support reload for quick experimentation
local TSHighlighter = rawget(vim.treesitter, 'TSHighlighter') or {}
TSHighlighter.__index = TSHighlighter

TSHighlighter.active = TSHighlighter.active or {}

local ns = a.nvim_create_namespace("treesitter/highlighter")

-- These are conventions defined by nvim-treesitter, though it
-- needs to be user extensible also.
TSHighlighter.hl_map = {
    ["error"] = "Error",

-- Miscs
    ["comment"] = "Comment",
    ["punctuation.delimiter"] = "Delimiter",
    ["punctuation.bracket"] = "Delimiter",
    ["punctuation.special"] = "Delimiter",

-- Constants
    ["constant"] = "Constant",
    ["constant.builtin"] = "Special",
    ["constant.macro"] = "Define",
    ["string"] = "String",
    ["string.regex"] = "String",
    ["string.escape"] = "SpecialChar",
    ["character"] = "Character",
    ["number"] = "Number",
    ["boolean"] = "Boolean",
    ["float"] = "Float",

-- Functions
    ["function"] = "Function",
    ["function.special"] = "Function",
    ["function.builtin"] = "Special",
    ["function.macro"] = "Macro",
    ["parameter"] = "Identifier",
    ["method"] = "Function",
    ["field"] = "Identifier",
    ["property"] = "Identifier",
    ["constructor"] = "Special",

-- Keywords
    ["conditional"] = "Conditional",
    ["repeat"] = "Repeat",
    ["label"] = "Label",
    ["operator"] = "Operator",
    ["keyword"] = "Keyword",
    ["exception"] = "Exception",

    ["type"] = "Type",
    ["type.builtin"] = "Type",
    ["structure"] = "Structure",
    ["include"] = "Include",
}

function TSHighlighter.new(parser, query)
  local self = setmetatable({}, TSHighlighter)

  self.parser = parser
  parser:register_cbs {
    on_changedtree = function(...) self:on_changedtree(...) end
  }

  self:set_query(query)
  self.edit_count = 0
  self.redraw_count = 0
  self.line_count = {}
  self.root = self.parser:parse():root()
  a.nvim_buf_set_option(self.buf, "syntax", "")

  -- TODO(bfredl): can has multiple highlighters per buffer????
  if not TSHighlighter.active[parser.bufnr] then
    TSHighlighter.active[parser.bufnr] = {}
  end

  TSHighlighter.active[parser.bufnr][parser.lang] = self

  -- Tricky: if syntax hasn't been enabled, we need to reload color scheme
  -- but use synload.vim rather than syntax.vim to not enable
  -- syntax FileType autocmds. Later on we should integrate with the
  -- `:syntax` and `set syntax=...` machinery properly.
  if vim.g.syntax_on ~= 1 then
    vim.api.nvim_command("runtime! syntax/synload.vim")
  end
  return self
end

local function is_highlight_name(capture_name)
  local firstc = string.sub(capture_name, 1, 1)
  return firstc ~= string.lower(firstc)
end

function TSHighlighter:get_hl_from_capture(capture)

  local name = self.query.captures[capture]

  if is_highlight_name(name) then
    -- From "Normal.left" only keep "Normal"
    return vim.split(name, '.', true)[1]
  else
    -- Default to false to avoid recomputing
    local hl = TSHighlighter.hl_map[name]
    return hl and a.nvim_get_hl_id_by_name(hl) or 0
  end
end

function TSHighlighter:on_changedtree(changes)
  for _, ch in ipairs(changes or {}) do
    a.nvim__buf_redraw_range(self.buf, ch[1], ch[3]+1)
  end
end

function TSHighlighter:set_query(query)
  if type(query) == "string" then
    query = vim.treesitter.parse_query(self.parser.lang, query)
  end

  self.query = query

  self.hl_cache = setmetatable({}, {
    __index = function(table, capture)
      local hl = self:get_hl_from_capture(capture)
      rawset(table, capture, hl)

      return hl
    end
  })

  a.nvim__buf_redraw_range(self.parser.bufnr, 0, a.nvim_buf_line_count(self.parser.bufnr))
end

local function iter_active_tshl(buf, fn)
  for _, hl in pairs(TSHighlighter.active[buf] or {}) do
    fn(hl)
  end
end

local function on_line_impl(self, buf, line)
  if self.root == nil then
    return -- parser bought the farm already
  end

  if self.iter == nil then
    self.iter = self.query:iter_captures(self.root,buf,line,self.botline)
  end
  while line >= self.nextrow do
    local capture, node = self.iter()
    if capture == nil then
      break
    end
    local start_row, start_col, end_row, end_col = node:range()
    local hl = self.hl_cache[capture]
    if hl and end_row >= line then
      a.nvim_buf_set_extmark(buf, ns, start_row, start_col,
                             { end_line = end_row, end_col = end_col,
                               hl_group = hl,
                               ephemeral = true,
                              })
    end
    if start_row > line then
      self.nextrow = start_row
    end
  end
end

function TSHighlighter._on_line(_, _win, buf, line, highlighter)
  -- on_line is only called when this is non-nil
  if highlighter then
    on_line_impl(highlighter, buf, line)
  else
    iter_active_tshl(buf, function(self)
      on_line_impl(self, buf, line)
    end)
  end
end

function TSHighlighter._on_buf(_, buf)
  iter_active_tshl(buf, function(self)
    if self then
      local tree = self.parser:parse()
      self.root = (tree and tree:root()) or nil
    end
  end)
end

function TSHighlighter._on_win(_, _win, buf, _topline, botline)
  iter_active_tshl(buf, function(self)
    if not self then
      return false
    end

    self.iter = nil
    self.nextrow = 0
    self.botline = botline
    self.redraw_count = self.redraw_count + 1
    return true
  end)
  return true
end

a.nvim_set_decoration_provider(ns, {
  on_buf = TSHighlighter._on_buf;
  on_win = TSHighlighter._on_win;
  on_line = TSHighlighter._on_line;
})

return TSHighlighter
