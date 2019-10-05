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

if false then
  node = root:descendant_for_range(246,0,246,10)
  node:sexpr()

end

-- these are conventions defined by tree-sitter, eventually there will be a "standard query" for
-- c highlighting we can import.
hl_map = {
    keyword="Keyword",
    string="String",
    type="Type",
    ["type.user"]="Identifier",
    comment="Comment",
    ["keyword.preproc"]="PreProc",
    ["keyword.storagecls"]="StorageClass",
    number="Number",
    --["function"]="Function"
    ["function.static"]="Identifier"
}

id_map = {}
for k,v in pairs(hl_map) do
  id_map[k] = a.nvim__syn_attr(v)
end

cquery_src = [[
"break" @keyword
"case" @keyword
"continue" @keyword
"do" @keyword
"else" @keyword
"for" @keyword
"if" @keyword
"return" @keyword
"sizeof" @keyword
"switch" @keyword
"while" @keyword

"const" @keyword.storagecls
"static" @keyword.storagecls
"struct" @keyword.storagecls
"inline" @keyword.storagecls
"enum" @keyword.storagecls
"extern" @keyword.storagecls
"typedef" @keyword.storagecls
"union" @keyword.storagecls

"#define" @keyword.preproc
"#else" @keyword.preproc
"#endif" @keyword.preproc
"#if" @keyword.preproc
"#ifdef" @keyword.preproc
"#ifndef" @keyword.preproc
"#include" @keyword.preproc
(preproc_directive) @keyword.preproc

(string_literal) @string
(system_lib_string) @string

(number_literal) @number
(char_literal) @string

(field_identifier) @property

(type_identifier) @type.user
(primitive_type) @type
(sized_type_specifier) @type

((function_definition (storage_class_specifier) @funcclass declarator: (function_declarator (identifier) @function.static))  (eq? @funcclass "static"))

(comment) @comment

(call_expression
  function: (identifier) @function)
(function_declarator
  declarator: (identifier) @function)
(preproc_function_def
  name: (identifier) @function)
]]
cquery = vim.treesitter.parse_query("c", cquery_src)
iquery = cquery:inspect()


line,endl = 134, 135

function oldline(line,endl)
  if endl == nil then endl = line+1 end
    a.nvim_buf_clear_highlight(parser.bufnr, my_syn_ns, line, endl)
  local root = parser:parse():root()
  local continue = true
  local i = 800
  for capture,node in root:query(cquery,line,endl) do
    --print(inspect_node(node))
    hl = hl_map[capture]
    local start_row, start_col, end_row, end_col = node:range()
    if hl then
      if start_row == end_row then
        a.nvim_buf_add_highlight(parser.bufnr, my_syn_ns, hl, start_row, start_col, end_col)
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
  oldline(132,140)
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


do local s, l = pcall(require,'luadev') if s then _G.luadev = l end end
if luadev then
    d = vim.schedule_wrap(luadev.print)
else
    function d() end
end

function run_pred(match,buf)
  local preds = iquery.patterns[match.pattern]
  for _, pred in pairs(preds) do
    if pred[1] == "eq?" then
      local node = match[pred[2]]
      -- TODO: support (eq? @aa @bb)
      local str = pred[3]
      local start_row, start_col, end_row, end_col = node:range()
      if start_row ~= end_row then
        return false
      end
      local line = a.nvim_buf_get_lines(buf, start_row, start_row+1, true)[1]
      local text = string.sub(line, start_col+1, end_col)
      if str ~= text then
          return false
      end
    end
  end
  return true
end

function on_line(_, win, buf, line)
  count = 0
  while line >= hlstate.nextrow do
    local capture, node, match = hlstate.iter()
    local active = true
    if capture == nil then
      break
    end
    if match ~= nil then
      active = run_pred(match, buf)
      match.active = active
    end
    count = count + 1
    local start_row, start_col, end_row, end_col = node:range()
    local hl = id_map[capture]
    if hl and active then
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
  --return (hlstate.first_line+1) .." ".. tostring(count)
end

function ts_syntax()
  a.nvim_buf_set_option(parser.bufnr, "syntax", "")
  a.nvim_buf_set_luahl(parser.bufnr, {on_start=on_start, on_line=on_line})
end
ts_syntax()

