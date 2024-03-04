local cdoc_grammar = require('scripts.cdoc_grammar')
local c_grammar = require('src.nvim.generators.c_grammar')

--- @class nvim.cdoc.parser.param
--- @field name string
--- @field type string
--- @field desc string

--- @class nvim.cdoc.parser.return
--- @field name string
--- @field type string
--- @field desc string

--- @class nvim.cdoc.parser.note
--- @field desc string

--- @class nvim.cdoc.parser.brief
--- @field kind 'brief'
--- @field desc string

--- @class nvim.cdoc.parser.fun
--- @field name string
--- @field params nvim.cdoc.parser.param[]
--- @field returns nvim.cdoc.parser.return[]
--- @field desc string
--- @field deprecated? true
--- @field since? string
--- @field attrs? table<string,any>
--- @field nodoc? true
--- @field notes? nvim.cdoc.parser.note[]
--- @field see? nvim.cdoc.parser.note[]

--- @class nvim.cdoc.parser.State
--- @field doc_lines? string[]
--- @field cur_obj? nvim.cdoc.parser.obj
--- @field last_doc_item? nvim.cdoc.parser.param|nvim.cdoc.parser.return|nvim.cdoc.parser.note
--- @field last_doc_item_indent? integer

--- @alias nvim.cdoc.parser.obj
--- | nvim.cdoc.parser.fun
--- | nvim.cdoc.parser.brief

--- If we collected any `---` lines. Add them to the existing (or new) object
--- Used for function/class descriptions and multiline param descriptions.
--- @param state nvim.cdoc.parser.State
local function add_doc_lines_to_obj(state)
  if state.doc_lines then
    state.cur_obj = state.cur_obj or {}
    local cur_obj = assert(state.cur_obj)
    local txt = table.concat(state.doc_lines, '\n')
    if cur_obj.desc then
      cur_obj.desc = cur_obj.desc .. '\n' .. txt
    else
      cur_obj.desc = txt
    end
    state.doc_lines = nil
  end
end

--- @param line string
--- @param state nvim.cdoc.parser.State
local function process_doc_line(line, state)
  line = line:gsub('^%s+@', '@')

  local parsed = cdoc_grammar:match(line)

  if not parsed then
    if line:match('^ ') then
      line = line:sub(2)
    end

    if state.last_doc_item then
      if not state.last_doc_item_indent then
        state.last_doc_item_indent = #line:match('^%s*') + 1
      end
      state.last_doc_item.desc = (state.last_doc_item.desc or '')
        .. '\n'
        .. line:sub(state.last_doc_item_indent or 1)
    else
      state.doc_lines = state.doc_lines or {}
      table.insert(state.doc_lines, line)
    end
    return
  end

  state.last_doc_item_indent = nil
  state.last_doc_item = nil

  local kind = parsed.kind

  state.cur_obj = state.cur_obj or {}
  local cur_obj = assert(state.cur_obj)

  if kind == 'brief' then
    state.cur_obj = {
      kind = 'brief',
      desc = parsed.desc,
    }
  elseif kind == 'param' then
    state.last_doc_item_indent = nil
    cur_obj.params = cur_obj.params or {}
    state.last_doc_item = {
      name = parsed.name,
      desc = parsed.desc,
    }
    table.insert(cur_obj.params, state.last_doc_item)
  elseif kind == 'return' then
    cur_obj.returns = { {
      desc = parsed.desc,
    } }
    state.last_doc_item_indent = nil
    state.last_doc_item = cur_obj.returns[1]
  elseif kind == 'deprecated' then
    cur_obj.deprecated = true
  elseif kind == 'nodoc' then
    cur_obj.nodoc = true
  elseif kind == 'since' then
    cur_obj.since = parsed.desc
  elseif kind == 'see' then
    cur_obj.see = cur_obj.see or {}
    table.insert(cur_obj.see, { desc = parsed.desc })
  elseif kind == 'note' then
    state.last_doc_item_indent = nil
    state.last_doc_item = {
      desc = parsed.desc,
    }
    cur_obj.notes = cur_obj.notes or {}
    table.insert(cur_obj.notes, state.last_doc_item)
  else
    error('Unhandled' .. vim.inspect(parsed))
  end
end

--- @param item nvim.c_grammar.Proto
--- @param state nvim.cdoc.parser.State
local function process_proto(item, state)
  state.cur_obj = state.cur_obj or {}
  local cur_obj = assert(state.cur_obj)
  cur_obj.name = item.name
  cur_obj.params = cur_obj.params or {}

  for _, p in ipairs(item.parameters) do
    local param = { name = p[2], type = p[1] }
    local added = false
    for _, cp in ipairs(cur_obj.params) do
      if cp.name == param.name then
        cp.type = param.type
        added = true
        break
      end
    end

    if not added then
      table.insert(cur_obj.params, param)
    end
  end

  cur_obj.returns = cur_obj.returns or { {} }
  cur_obj.returns[1].type = item.return_type
  cur_obj.attrs = item.attrs or {}

  -- Remove some arguments
  for i = #cur_obj.params, 1, -1 do
    local p = cur_obj.params[i]
    if p.name == 'channel_id' or vim.tbl_contains({ 'lstate', 'arena', 'error' }, p.type) then
      table.remove(cur_obj.params, i)
    end
  end
end

local M = {}

--- @param txt string
--- @return {} classes
--- @return nvim.cdoc.parser.fun[] funs
--- @return string[] briefs
function M.parse_str(txt)
  local funs = {} --- @type nvim.cdoc.parser.fun[]
  local briefs = {} --- @type string[]
  local state = {} --- @type nvim.cdoc.parser.State

  for _, item in ipairs(c_grammar.grammar:match(txt)) do
    if item[1] == 'comment' then
      --- @cast item nvim.c_grammar.Comment
      process_doc_line(item.comment, state)
    else
      add_doc_lines_to_obj(state)
      if item[1] == 'proto' then
        --- @cast item nvim.c_grammar.Proto
        process_proto(item, state)
        table.insert(funs, state.cur_obj)
      end
      local cur_obj = state.cur_obj
      if cur_obj and cur_obj.kind == 'brief' then
        table.insert(briefs, cur_obj.desc)
      end
      state = {}
    end
  end

  return {}, funs, briefs
end

--- @param filename string
--- @return {} classes
--- @return nvim.cdoc.parser.fun[] funs
--- @return string[] briefs
function M.parse(filename)
  local f = assert(io.open(filename, 'r'))
  local txt = f:read('*all')

  f:close()
  return M.parse_str(txt)
end

return M
