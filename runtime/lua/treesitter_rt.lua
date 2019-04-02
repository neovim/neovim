_G.a = vim.api
local a = vim.api

if __treesitter_rt_ns == nil then
    __treesitter_rt_ns = a.nvim_buf_add_highlight(0, 0, "", 0, 0, 0)
    __treesitter_rt_syn_ns = a.nvim_buf_add_highlight(0, 0, "", 0, 0, 0)
end
local my_ns = __treesitter_rt_ns
local my_syn_ns = __treesitter_rt_syn_ns

function js_sheet()
  local path = '.deps/build/src/treesitter-javascript/src/highlights.json'
  a.nvim_set_var("_ts_path", path)
  local obj = a.nvim_eval("json_decode(readfile(g:_ts_path,'b'))")
  for k in pairs(obj) do print(k) end
  --obj.property_sets[2]

  states = obj.states
  s = states[1]
  for k in pairs(s) do print(k) end

  t = s.transitions[2]
  for k in pairs(t) do print(k) end

  parser = vim.ts_parser("javascript")
  symbs = parser:symbols()
  named = {}
  anonymous = {}
  for i, symb in pairs(symbs) do
    local dict
    if symb[2] == "named" then
      dict = named
      --named[symb[1]] = i
    elseif symb[2] == "anonymous" then
      dict = anonymous
      --anonymous[symb[1]] = i
    else
      dict = {} -- SKRAPET
    end
    -- TODO: duplicate symbols might be a bug
    if dict[symb[1]] == nil then
      dict[symb[1]] = {}
    end
    table.insert(dict[symb[1]], i)
  end
  lut = {[true]=named, [false]=anonymous}

  local sheet = vim.ts_propertysheet(#states, #symbs)
  for _, s in pairs(states) do
      local id = s.id
      sheet:add_state(id, s.default_next_state_id, s.property_set_id)
      for _,t in pairs(s.transitions) do
        if t.text == nil then
            local kinds = lut[t.named][t.type]
            for _,kind in ipairs(kinds) do
              sheet:add_transition(id, kind, t.state_id, t.index)
            end
        end
      end
  end

  scope = {}
  for i,prop in ipairs(obj.property_sets) do
    scope[i-1] = prop.scope
  end
  return sheet
end
print(lut[true]['identifier'])

--luadev = require'luadev'
--i = require'inspect'


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
  tsstate.tree = tsstate.parser:parse_buf(tsstate.bufnr)
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

sheet = js_sheet()
function ts_inspect2(row,col)
  local tree = parse_tree(theparser)
  icursor = tree:root():to_cursor(sheet)
  local startbyte = a.nvim_buf_get_offset(theparser.bufnr, row)
  ipos = startbyte+col+1
  ii = 0
  repeat
    node, propid = icursor:forward(ipos)
    r,c, start_byte = node:start()
    ii = ii + 1
  until propid > 0 or start_byte > ipos
  show_node(node,true)
  print(ii, scope[propid], node:type())
end

function ts_iforward()
  node, propid = icursor:forward(ipos)
  show_node(node,true)
  print(node:type(), scope[propid])
end

function show_node(node,subtle)
  if node == nil then
    return
  end
  a.nvim_buf_clear_highlight(0, my_ns, 0, -1)
  shown_node = node
  if not subtle then
    print(node:type())
  end
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
  --ts_inspect_pos(row-1, col)
  ts_inspect2(row-1, col)
end

hl_map = {
  primitive_type="Type",
  type_identifier="Identifier",
  const="Type",
  struct="Type",
  typedef="Type",
  enum="Type",
  static="Type",
  ["if"]="Statement",
  ["for"]="Statement",
  ["while"]="Statement",
  ["return"]="Statement",
  number_literal="Number",
  string_literal="String",
  comment="Comment",
  ["#include"]="PreProc",
  ["#define"]="PreProc",
  ["#ifdef"]="PreProc",
  ["#else"]="PreProc",
  ["#endif"]="PreProc",
}

hl_scope_map = {
  constant='Constant',
  number='Number',
  keyword='Statement',
  string='String',
  escape='Special',
  ['function']='Identifier',
}

id_map = {}
for k,v in pairs(hl_map) do
  id_map[k] = a.nvim__syn_attr(v)
end

scope_map = {}
id_scope_map = {}
for i,s in pairs(scope) do
  if hl_scope_map[s] then
    scope_map[i] = hl_scope_map[s]
    id_scope_map[i] = a.nvim__syn_attr(hl_scope_map[s])
  end
end


function ts_line(line,endl,drawing)
  if endl == nil then endl = line+1 end
  if not drawing then
    a.nvim_buf_clear_highlight(0, my_syn_ns, line, endl)
  end
  tree = parse_tree(theparser)
  local root = tree:root()
  local cursor = root:to_cursor(sheet)
  print(cursor)
  local startbyte = a.nvim_buf_get_offset(theparser.bufnr, line)
  local node = root
  local continue = true
  local i = 800
  local nscope = 0
  while continue do
    --print(inspect_node(node))
    if true then
      print(nscope)
      local map = (drawing and id_scope_map) or scope_map
      hl = map[nscope]
    else
      local name = node:type()
      local map = (drawing and id_map) or hl_map
      local hl = map[name]
    end
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
          a.nvim_buf_add_highlight(theparser.bufnr, my_syn_ns, hl, start_row, start_col, end_col)
        end
      end
    end
    if start_row >= endl then
      continue = false
    end
    node, nscope = cursor:forward(startbyte)
    if node == nil then
      continue = false
    end

    i = i - 1
    if i == 0 then
      continue = false
    end
  end
end

if false then
  ts_line(0,800)
end


function ts_on_winhl(win, buf, lnum)
  ts_line(lnum, lnum+1, true)
end

function ts_syntax()
  a.nvim_buf_set_luahl(theparser.bufnr, "return ts_on_winhl(...)")
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
