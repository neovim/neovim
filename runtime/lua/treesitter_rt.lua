local a = vim.api
local ffi = require'ffi'

local path = a.nvim_get_var("ts_test_path")
local data = io.open(path..'/treesitter_rt_ffi.h'):read('*all')

if __treesitter_rt_ns == nil then
    __treesitter_rt_ns = a.nvim_buf_add_highlight(0, 0, "", 0, 0, 0)
end
local my_ns = __treesitter_rt_ns

--luadev = require'luadev'
--i = require'inspect'

if did_def == nil then
ffi.cdef(data)
ffi.cdef([[ const TSLanguage * tree_sitter_c(); ]])

ffi.cdef([[
  const char nvim_ts_read_cb(void *payload, uint32_t byte_index, TSPoint position, uint32_t *bytes_read);
  void *nvim_ts_read_payload(int bufnr);
]])
did_def = true
TSPoint = ffi.metatype("TSPoint", {
  __tostring=function(p)
      return "TSPoint("..p.row..", "..p.column..")"
  end
})
else
TSPoint = ffi.typeof("TSPoint")
end

--ffi.load(path..'/../utf8proc/libutf8proc.so',true)
--l = ffi.load(path..'/../tree-sitter/build/libtreesitter_rt.so')
l = ffi.C

function inspect_node(node)
  node = root
  start = l.ts_node_start_point(node)
  endpos = l.ts_node_start_point(node)
  print(start.row)
end

TSInput = ffi.typeof("TSInput")
TSInputEdit = ffi.typeof("TSInputEdit")
read_cb = ffi.typeof("const char *(*)(void *payload, uint32_t byte_index, TSPoint position, uint32_t *bytes_read)")
fake_read_cb = ffi.typeof("const char *(*)(void *payload, uint32_t byte_index, uint32_t row, uint32_t *bytes_read)")


function reader(payload, byte_index, position, bytes_read)
  val, status = pcall(function ()
  end)
  return ""
end

--print(read_cb(reader))

function parse_tree(tsstate, force)
  if tsstate.valid and not force then
    return tsstate.tree
  end
  local old_tree = (not force) and tsstate.tree or nil
  payload = ffi.C.nvim_ts_read_payload(tsstate.bufnr) -- check NULL!
  local input = TSInput(payload, ffi.C.nvim_ts_read_cb, "TSInputEncodingUTF8")
  --print(input.read)
  tsstate.tree = l.ts_parser_parse(tsstate.parser, old_tree, input)
  tsstate.valid = true
  return tsstate.tree
end

function the_cb(tsstate, ev, ...)
  if ev == "nvim_buf_lines_event" then
    --luadev.print(require'inspect'({...}))
    bufnr, tick, start_row, oldstopline, lines, more = ...
    local nlines = #lines
    local stop_row = start_row + nlines
    local start_byte = a.nvim_buf_get_offset(bufnr,start_row)
    local root = l.ts_tree_root_node(tsstate.tree)
    local inode = l.ts_node_descendant_for_point_range(root, TSPoint(oldstopline+9000,0), TSPoint(oldstopline,0))
    local edit
    if l.ts_node_is_null(inode) then
      local stop_byte = a.nvim_buf_get_offset(bufnr,stop_row)
      edit = TSInputEdit(start_byte,stop_byte,stop_byte,TSPoint(start_row,0),TSPoint(stop_row,0),TSPoint(stop_row,0))
    else
      local fakebyteoldstop = l.ts_node_start_byte(inode)
      local fakeoldstoppoint = l.ts_node_start_point(inode)
      local fake_rows = fakeoldstoppoint.row-oldstopline
      local fakestop = stop_row+fake_rows
      local fakebytestop = a.nvim_buf_get_offset(bufnr,fakestop)+fakeoldstoppoint.column
      edit = TSInputEdit(start_byte,fakebyteoldstop,fakebytestop,TSPoint(start_row,0),fakeoldstoppoint,TSPoint(fakestop,fakeoldstoppoint.column))
    end
    l.ts_tree_edit(tsstate.tree,edit)
    tsstate.valid = false
    --luadev.append_buf({i{edit.start_byte,edit.old_end_byte,edit.new_end_byte},
    --                   i{edit.start_point, edit.old_end_point, edit.new_end_point}})
  end
end

function attach_buf(tsstate)
  local function cb(ev, ...)
    return the_cb(tsstate, ev, ...)
  end
  a.nvim_buf_attach(tsstate.bufnr, false, {on_event=cb})
end

function create_parser(bufnr)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  local tsstate = {}
  tsstate.bufnr = bufnr
  tsstate.parser = l.ts_parser_new()
  clang = l.tree_sitter_c()
  l.ts_parser_set_language(tsstate.parser,clang)
  --tree = l.ts_parser_parse_string(tsstate.parser, nil, data, string.len(data))
  parse_tree(tsstate)
  attach_buf(tsstate)
  return tsstate
end

function ts_inspect_pos(row,col)
  tree = parse_tree(theparser)
  root = l.ts_tree_root_node(tree)
  node = l.ts_node_descendant_for_point_range(root, TSPoint(row,col), TSPoint(row,col))
  show_node(node)
end

function show_node(node)
  if l.ts_node_is_null(node) then
    return
  end
  a.nvim_buf_clear_highlight(0, my_ns, 0, -1)
  shown_node = node
  print(ffi.string(l.ts_node_type(node)))
  start = l.ts_node_start_point(node)
  endp = l.ts_node_end_point(node)
  a.nvim_buf_add_highlight(0, my_ns, "ErrorMsg", start.row, start.column, start.column+1)
  if endp.column >= 1 then
    endp.column = endp.column - 1
  end

  a.nvim_buf_add_highlight(0, my_ns, "ErrorMsg", endp.row, endp.column, endp.column+1)
end

function ts_expand_node()
  if shown_node == nil then
    return
  end
  parent = l.ts_node_parent(shown_node)
  show_node(parent)
end

function ts_cursor()
  row, col = unpack(a.nvim_win_get_cursor(0))
  ts_inspect_pos(row-1, col)
end

