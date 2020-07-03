local a = vim.api

-- support reload for quick experimentation
local TSHighlighter = rawget(vim.treesitter, 'TSHighlighter') or {}
TSHighlighter.__index = TSHighlighter
local ts_hs_ns = a.nvim_create_namespace("treesitter_hl")

-- These are conventions defined by tree-sitter, though it
-- needs to be user extensible also.
-- TODO(bfredl): this is very much incomplete, we will need to
-- go through a few tree-sitter provided queries and decide
-- on translations that makes the most sense.
TSHighlighter.hl_map = {
    keyword="Keyword",
    string="String",
    type="Type",
    comment="Comment",
    constant="Constant",
    operator="Operator",
    number="Number",
    label="Label",
    ["function"]="Function",
    ["function.special"]="Function",
}

function TSHighlighter.new(query, bufnr, ft)
  local self = setmetatable({}, TSHighlighter)
  self.parser = vim.treesitter.get_parser(bufnr, ft, function(...) self:on_change(...) end)
  self.buf = self.parser.bufnr

  local tree = self.parser:parse()
  self.root = tree:root()
  self:set_query(query)
  self.edit_count = 0
  self.redraw_count = 0
  self.line_count = {}
  a.nvim_buf_set_option(self.buf, "syntax", "")
  a.nvim_buf_attach(self.buf, false, {
    on_lines=function(_) self.root = self.parser:parse():root() end
  })

  -- Tricky: if syntax hasn't been enabled, we need to reload color scheme
  -- but use synload.vim rather than syntax.vim to not enable
  -- syntax FileType autocmds. Later on we should integrate with the
  -- `:syntax` and `set syntax=...` machinery properly.
  if vim.g.syntax_on ~= 1 then
    vim.api.nvim_command("runtime! syntax/synload.vim")
  end

  return self
end

function TSHighlighter:set_query(query)
  if type(query) == "string" then
    query = vim.treesitter.parse_query(self.parser.lang, query)
  end
  self.query = query

  self:on_change({{self.root:range()}})
end

function TSHighlighter:on_change(changes)
  -- Get a fresh root
  self.root = self.parser.tree:root()

  for _, ch in ipairs(changes or {}) do
    -- Try to be as exact as possible
    local changed_node = self.root:descendant_for_range(ch[1], ch[2], ch[3], ch[4])

    a.nvim_buf_clear_namespace(self.buf, ts_hs_ns, ch[1], ch[3])

    for capture, node in self.query:iter_captures(changed_node, self.buf, ch[1], ch[3] + 1) do
      local start_row, start_col, end_row, end_col = node:range()
      local capture_name = self.query.captures[capture]

      local firstc = string.sub(capture_name, 1, 1)
      local hl
      -- TODO(vigoux): maybe we want to cache the capture -> highlight relation
      if firstc ~= string.lower(firstc) then
        hl = vim.split(capture_name, '.', true)[1]
      else
        hl = TSHighlighter.hl_map[capture_name]
      end

      if hl then
        a.nvim__buf_add_decoration(self.buf, ts_hs_ns, hl,
          start_row, start_col,
          end_row, end_col,
          {})
      end
    end
  end
end

return TSHighlighter
