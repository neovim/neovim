local a = vim.api

-- support reload for quick experimentation
local TSHighlighter = rawget(vim.treesitter, 'TSHighlighter') or {}
TSHighlighter.__index = TSHighlighter

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
  -- TODO(bfredl): perhaps on_start should be called uncondionally, instead for only on mod?
  local tree = self.parser:parse()
  self.root = tree:root()
  self:set_query(query)
  self.edit_count = 0
  self.redraw_count = 0
  self.line_count = {}
  a.nvim_buf_set_option(self.buf, "syntax", "")
  a.nvim__buf_set_luahl(self.buf, {
    on_start=function(...) return self:on_start(...) end,
    on_window=function(...) return self:on_window(...) end,
    on_line=function(...) return self:on_line(...) end,
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

  self.id_map = {}
  for i, capture in ipairs(self.query.captures) do
    local hl = 0
    local firstc = string.sub(capture, 1, 1)
    local hl_group = self.hl_map[capture]
    if firstc ~= string.lower(firstc) then
      hl_group = vim.split(capture, '.', true)[1]
    end
    if hl_group then
      hl = a.nvim_get_hl_id_by_name(hl_group)
    end
    self.id_map[i] = hl
  end
end

function TSHighlighter:on_change(changes)
  for _, ch in ipairs(changes or {}) do
    a.nvim__buf_redraw_range(self.buf, ch[1], ch[3]+1)
  end
  self.edit_count = self.edit_count + 1
end

function TSHighlighter:on_start(_, _buf, _tick)
  local tree = self.parser:parse()
  self.root = tree:root()
end

function TSHighlighter:on_window(_, _win, _buf, _topline, botline)
  self.iter = nil
  self.active_nodes = {}
  self.nextrow = 0
  self.botline = botline
  self.redraw_count = self.redraw_count + 1
end

function TSHighlighter:on_line(_, _win, buf, line)
  if self.iter == nil then
    self.iter = self.query:iter_captures(self.root,buf,line,self.botline)
  end
  while line >= self.nextrow do
    local capture, node, match = self.iter()
    local active = true
    if capture == nil then
      break
    end
    if match ~= nil then
      active = self:run_pred(match)
      match.active = active
    end
    local start_row, start_col, end_row, end_col = node:range()
    local hl = self.id_map[capture]
    if hl > 0 and active then
      if start_row == line and end_row == line then
        a.nvim__put_attr(hl, start_col, end_col)
      elseif end_row >= line then
        -- TODO(bfredl): this is quite messy. Togheter with multiline bufhl we should support
        -- luahl generating multiline highlights (and other kinds of annotations)
        self.active_nodes[{hl=hl, start_row=start_row, start_col=start_col, end_row=end_row, end_col=end_col}] = true
      end
    end
    if start_row > line then
      self.nextrow = start_row
    end
  end
  for node,_ in pairs(self.active_nodes) do
    if node.start_row <= line and node.end_row >= line then
      local start_col, end_col = node.start_col, node.end_col
      if node.start_row < line then
        start_col = 0
      end
      if node.end_row > line then
        end_col = 9000
      end
      a.nvim__put_attr(node.hl, start_col, end_col)
    end
    if node.end_row <= line then
      self.active_nodes[node] = nil
    end
  end
  self.line_count[line] = (self.line_count[line] or 0) + 1
  --return tostring(self.line_count[line])
end

return TSHighlighter
