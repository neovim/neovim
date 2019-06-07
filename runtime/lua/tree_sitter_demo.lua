local a = vim.api
_G.a = vim.api

if __treesitter_rt_ns == nil then
    __treesitter_rt_ns = a.nvim_create_namespace("treesitter_demp")
end
local my_ns = __treesitter_rt_ns

function ts_inspect_pos(row,col)
  local tree = theparser:parse_tree()
  local root = tree:root()
  local node = root:descendant_for_point_range(row,col,row,col)
  show_node(node)
end

function show_node(node)
  if node == nil then
    return
  end
  a.nvim_buf_clear_highlight(0, my_ns, 0, -1)
  shown_node = node
  print(node:type())
  local start_row, start_col, end_row, end_col = node:range()

  a.nvim_buf_add_highlight(0, my_ns, "ErrorMsg", start_row, start_col, start_col+1)

  if end_col >= 1 then
    end_col = end_col - 1
  end
  a.nvim_buf_add_highlight(0, my_ns, "ErrorMsg", end_row, end_col, end_col+1)
end

function ts_expand_node()
  if shown_node == nil then
    return
  end
  parent = shown_node:parent()
  show_node(parent)
end

function ts_cursor()
  local row, col = unpack(a.nvim_win_get_cursor(0))
  ts_inspect_pos(row-1, col)
end

if false then
  ctree = theparser.tree
  root = ctree:root()
  cursor = root:to_cursor()
  node = cursor:forward(5000) if true then return node end
  print(#root)
  c = root:child(50)
  print(require'inspect'{c:extent()})
  type(ctree.__tostring)
  root:__tostring()
  print(_tslua_debug())
end
