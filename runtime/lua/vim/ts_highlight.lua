_G.a = vim.api
local a = vim.api
if __treesitter_rt_ns == nil then
    __treesitter_rt_ns = a.nvim_buf_add_highlight(0, 0, "", 0, 0, 0)
    __treesitter_rt_syn_ns = a.nvim_buf_add_highlight(0, 0, "", 0, 0, 0)
end
local my_ns = __treesitter_rt_ns
local my_syn_ns = __treesitter_rt_syn_ns


vim.treesitter.add_language("/home/bjorn/dev/tree-sitter-c/bin/c.so", "c")
parser = vim.treesitter.get_parser(1)
root = parser:parse():root()

-- these are conventions defined by tree-sitter, eventually there will be a "standard query" for
-- c highlighting we can import.
hl_map = {keyword="Keyword", string="String", type="Type", comment="Comment"}

id_map = {}
for k,v in pairs(hl_map) do
  id_map[k] = a.nvim__syn_attr(v)
end

cquery_src = [[
"const" @keyword
"else" @keyword
"for" @keyword
"if" @keyword
"return" @keyword
"static" @keyword
"while" @keyword
(string_literal) @string
(primitive_type) @type
(comment) @comment
]]
cquery = vim.treesitter.parse_query("c", cquery_src)


line,endl,drawing = 134, 135, false

function ts_line(line,endl,drawing)
  if endl == nil then endl = line+1 end
  if not drawing then
    a.nvim_buf_clear_highlight(parser.bufnr, my_syn_ns, line, endl)
  end
  local root = parser:parse():root()
  local continue = true
  local i = 800
  for capture,node in root:query(cquery,line,endl) do
    --print(inspect_node(node))
    local map = (drawing and id_map) or hl_map
    hl = map[capture]
    local start_row, start_col, end_row, end_col = node:range()
    if hl then
      if not drawing then
        --print(inspect_node(node))
        print(hl)
      end
      if start_row == end_row then
        if drawing then
          if start_row == line then
            a.nvim__put_attr(hl, start_col, end_col)
          end
        else
          a.nvim_buf_add_highlight(parser.bufnr, my_syn_ns, hl, start_row, start_col, end_col)
        end
      end
    end
    if start_row >= endl then
      break
    end
    i = i - 1
    if i == 0 then
      break
    end
  end
end
if false then
  ts_line(132,140)
end

hlstate = {}
function on_start(_, win, buf, line)
  local root = parser:parse():root()
  -- TODO: win_update should give the max height (in buflines)
  hlstate.iter = root:query(cquery,line,a.nvim_buf_line_count(buf))
  hlstate.active_nodes = {}
  hlstate.nextrow = 0
  hlstate.first_line = line
end

function on_line(_, win, buf, line)
  count = 0
  while line >= hlstate.nextrow do
    local capture, node = hlstate.iter()
    if capture == nil then
      break
    end
    count = count + 1
    local start_row, start_col, end_row, end_col = node:range()
    local hl = id_map[capture]
    if hl then
      if start_row == line and end_row == line then
        a.nvim__put_attr(hl, start_col, end_col)
      elseif end_row >= line then
        hlstate.active_nodes[{hl=hl, start_row=start_row, start_col=start_col, end_row=end_row, end_col=end_col}] = true
      end
    end
    if start_row > line then
      hlstate.nextrow = start_row
    end
  end
  for node,_ in pairs(hlstate.active_nodes) do
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
      hlstate.active_nodes[node] = nil
    end
  end
  return (hlstate.first_line+1) .." ".. tostring(count)
end

function ts_syntax()
  a.nvim_buf_set_option(parser.bufnr, "syntax", "")
  a.nvim_buf_set_luahl(parser.bufnr, {on_start=on_start, on_line=on_line})
end
ts_syntax()

