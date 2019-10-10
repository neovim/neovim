_G.a = vim.api
local a = vim.api

do local s, l = pcall(require,'luadev') if s then _G.luadev = l end end
if luadev then
    d = vim.schedule_wrap(luadev.print)
else
    function d() end
end

-- TSHighlighter = {}
-- what is autoreload? 
TSHighlighter = _G.TSHighlighter or {}
TSHighlighter.__index = TSHighlighter

-- these are conventions defined by tree-sitter, though it
-- needs to be user extensible also
TSHighlighter.hl_map = {
    keyword="Keyword",
    string="String",
    type="Type",
    ["type.user"]="Identifier",
    comment="Comment",
    ["keyword.preproc"]="PreProc",
    ["keyword.storagecls"]="StorageClass",
    number="Number",
    --["function"]="Function"
    ["function.static"]="Identifier",
    ["dup"]="WarningMsg",
}

-- TODO: redo on ColorScheme! (or on any :hi really)
TSHighlighter.id_map = {}
for k,v in pairs(TSHighlighter.hl_map) do
  TSHighlighter.id_map[k] = a.nvim__syn_attr(v)
end

function TSHighlighter.new(query, bufnr, ft)
  local self = setmetatable({}, TSHighlighter)
  self.parser = vim.treesitter.get_parser(bufnr, ft)
  self.buf = self.parser.bufnr
  if type(query) == "string" then
    query = vim.treesitter.parse_query(self.parser.lang, query)
  end
  self.query = query
  self.iquery = query:inspect()
  a.nvim_buf_set_option(self.buf, "syntax", "")
  a.nvim_buf_set_luahl(self.buf, {
    on_start=function(...) self:on_start(...) end,
    on_line=function(...) self:on_line(...) end,
  })
end

function TSHighlighter:on_start(_, win, buf, line)
  local tree, changes = self.parser:parse()
  local root = tree:root()
  --d(vim.inspect(changes))
  -- TODO: win_update should give the max height (in buflines)
  self.iter = root:query(self.query,line,a.nvim_buf_line_count(buf))
  self.active_nodes = {}
  self.nextrow = 0
  self.first_line = line
end


local function get_node_text(node, buf)
  local start_row, start_col, end_row, end_col = node:range()
  if start_row ~= end_row then
    return nil
  end
  local line = a.nvim_buf_get_lines(buf, start_row, start_row+1, true)[1]
  return string.sub(line, start_col+1, end_col)
end

function TSHighlighter:run_pred(match)
  local preds = self.iquery.patterns[match.pattern]
  for _, pred in pairs(preds) do
    if pred[1] == "eq?" then
      local node = match[pred[2]]
      local node_text = get_node_text(node, self.buf)

      local str
      if type(pred[3]) == "string" then
        -- (eq? @aa "foo")
        str = pred[3]
      else
        -- (eq? @aa @bb)
        str = get_node_text(match[pred[3]], self.buf)
      end

      if node_text ~= str or str == nil then
        return false
      end
    end
  end
  return true
end

function TSHighlighter:on_line(_, win, buf, line)
  count = 0
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
    count = count + 1
    local start_row, start_col, end_row, end_col = node:range()
    local hl = self.id_map[capture]
    if hl and active then
      if start_row == line and end_row == line then
        a.nvim__put_attr(hl, start_col, end_col)
      elseif end_row >= line then
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
  --return (self.first_line+1) .." ".. tostring(count)
end

return TSHighlighter
