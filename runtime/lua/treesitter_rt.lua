local a = vim.api

if __treesitter_rt_ns == nil then
    __treesitter_rt_ns = a.nvim_buf_add_highlight(0, 0, "", 0, 0, 0)
    __treesitter_rt_syn_ns = a.nvim_buf_add_highlight(0, 0, "", 0, 0, 0)
end
local my_ns = __treesitter_rt_ns
local my_syn_ns = __treesitter_rt_syn_ns

local path = '.deps/build/src/treesitter-javascript/src/highlights.json'
a.nvim_set_var("_ts_path", path)
obj = a.nvim_eval("json_decode(readfile(g:_ts_path,'b'))")


--luadev = require'luadev'
--i = require'inspect'


function parse_tree(tsstate, force)
  if tsstate.valid and not force then
    return tsstate.tree
  end
  tsstate.tree = tsstate.parser:parse_buf(tsstate.bufnr)
  tsstate.valid = true
  return tsstate.tree
end

function the_cb(tsstate, ev, bufnr, tick, start_row, oldstopline, stop_row)
  local start_byte = a.nvim_buf_get_offset(bufnr,start_row)
  -- a bit messy, should we expose edited but not reparsed tree?
  -- are multiple edits safe in general?
  local root = tsstate.parser:tree():root()
  -- TODO: add proper lookup function!
  local inode = root:descendant_for_point_range(oldstopline+9000,0, oldstopline,0)
  local edit
  if inode == nil then
    local stop_byte = a.nvim_buf_get_offset(bufnr,stop_row)
    tsstate.parser:edit(start_byte,stop_byte,stop_byte,start_row,0,stop_row,0,stop_row,0)
  else
    local fakeoldstoprow, fakeoldstopcol, fakebyteoldstop = inode:start()
    local fake_rows = fakeoldstoprow-oldstopline
    local fakestop = stop_row+fake_rows
    local fakebytestop = a.nvim_buf_get_offset(bufnr,fakestop)+fakeoldstopcol
    tsstate.parser:edit(start_byte,fakebyteoldstop,fakebytestop,start_row,0,fakeoldstoprow,fakeoldstopcol,fakestop,fakeoldstopcol)
  end
  tsstate.valid = false
  --luadev.append_buf({i{edit.start_byte,edit.old_end_byte,edit.new_end_byte},
  --                   i{edit.start_point, edit.old_end_point, edit.new_end_point}})
end

function attach_buf(tsstate)
  local function cb(ev, ...)
    return the_cb(tsstate, ev, ...)
  end
  a.nvim_buf_attach(tsstate.bufnr, false, {on_lines=cb})
end

function create_parser(bufnr)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  local ft = a.nvim_buf_get_option(bufnr, "filetype")
  local tsstate = {}
  tsstate.bufnr = bufnr
  tsstate.parser = vim.ts_parser(ft)
  parse_tree(tsstate)
  attach_buf(tsstate)
  return tsstate
end

function ts_inspect_pos(row,col)
  local tree = parse_tree(theparser)
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
