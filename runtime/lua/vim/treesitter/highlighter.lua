local a = vim.api

-- support reload for quick experimentation
local TSHighlighter = rawget(vim.treesitter, 'TSHighlighter') or {}
TSHighlighter.__index = TSHighlighter
local ts_hs_ns = a.nvim_create_namespace("treesitter_hl")

-- These are conventions defined by tree-sitter, though it
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

function TSHighlighter.new(query, bufnr, ft)
  local self = setmetatable({}, TSHighlighter)
  self.parser = vim.treesitter.get_parser(
    bufnr,
    ft,
    {
      on_changedtree = function(...) self:on_changedtree(...) end,
      on_lines = function() self.root = self.parser:parse():root() end
    }
  )

  self.buf = self.parser.bufnr

  local tree = self.parser:parse()
  self.root = tree:root()
  self:set_query(query)
  self.edit_count = 0
  self.redraw_count = 0
  self.line_count = {}
  a.nvim_buf_set_option(self.buf, "syntax", "")

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

function TSHighlighter:set_query(query)
  if type(query) == "string" then
    query = vim.treesitter.parse_query(self.parser.lang, query)
  elseif query == nil then
    query = vim.treesitter.get_query(self.parser.lang, 'highlights')

    if query == nil then
      a.nvim_err_writeln("No highlights.scm query found for " .. self.parser.lang)
      query = vim.treesitter.parse_query(self.parser.lang, "")
    end
  end

  self.query = query

  self.hl_cache = setmetatable({}, {
    __index = function(table, capture)
      local hl = self:get_hl_from_capture(capture)
      rawset(table, capture, hl)

      return hl
    end
  })

  self:on_changedtree({{self.root:range()}})
end

function TSHighlighter:on_changedtree(changes)
  -- Get a fresh root
  self.root = self.parser.tree:root()

  for _, ch in ipairs(changes or {}) do
    -- Try to be as exact as possible
    local changed_node = self.root:descendant_for_range(ch[1], ch[2], ch[3], ch[4])

    a.nvim_buf_clear_namespace(self.buf, ts_hs_ns, ch[1], ch[3])

    for capture, node in self.query:iter_captures(changed_node, self.buf, ch[1], ch[3] + 1) do
      local start_row, start_col, end_row, end_col = node:range()
      local hl = self.hl_cache[capture]
      if hl then
        a.nvim_buf_set_extmark(self.buf, ts_hs_ns, start_row, start_col, {
          end_col = end_col,
          end_line = end_row,
          hl_group = hl
        })
      end
    end
  end
end

return TSHighlighter
