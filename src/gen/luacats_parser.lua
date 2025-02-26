local luacats_grammar = require('gen.luacats_grammar')

--- @class nvim.luacats.parser.param : nvim.luacats.Param

--- @class nvim.luacats.parser.return
--- @field name string
--- @field type string
--- @field desc string

--- @class nvim.luacats.parser.note
--- @field desc string

--- @class nvim.luacats.parser.brief
--- @field kind 'brief'
--- @field desc string

--- @class nvim.luacats.parser.alias
--- @field kind 'alias'
--- @field type string[]
--- @field desc string

--- @class nvim.luacats.parser.fun
--- @field name string
--- @field params nvim.luacats.parser.param[]
--- @field returns nvim.luacats.parser.return[]
--- @field desc string
--- @field access? 'private'|'package'|'protected'
--- @field class? string
--- @field module? string
--- @field modvar? string
--- @field classvar? string
--- @field deprecated? true
--- @field since? string
--- @field attrs? string[]
--- @field nodoc? true
--- @field generics? table<string,string>
--- @field table? true
--- @field notes? nvim.luacats.parser.note[]
--- @field see? nvim.luacats.parser.note[]

--- @class nvim.luacats.parser.field : nvim.luacats.Field
--- @field classvar? string
--- @field nodoc? true

--- @class nvim.luacats.parser.class : nvim.luacats.Class
--- @field desc? string
--- @field nodoc? true
--- @field inlinedoc? true
--- @field fields nvim.luacats.parser.field[]
--- @field notes? string[]

--- @class nvim.luacats.parser.State
--- @field doc_lines? string[]
--- @field cur_obj? nvim.luacats.parser.obj
--- @field last_doc_item? nvim.luacats.parser.param|nvim.luacats.parser.return|nvim.luacats.parser.note
--- @field last_doc_item_indent? integer

--- @alias nvim.luacats.parser.obj
--- | nvim.luacats.parser.class
--- | nvim.luacats.parser.fun
--- | nvim.luacats.parser.brief
--- | nvim.luacats.parser.alias

-- Remove this when we document classes properly
--- Some doc lines have the form:
---   param name some.complex.type (table) description
--- if so then transform the line to remove the complex type:
---   param name (table) description
--- @param line string
local function use_type_alt(line)
  for _, type in ipairs({ 'table', 'function' }) do
    line = line:gsub('@param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. ')%)', '@param %1 %2')
    line = line:gsub('@param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. '|nil)%)', '@param %1 %2')
    line = line:gsub('@param%s+([a-zA-Z_?]+)%s+.*%((' .. type .. '%?)%)', '@param %1 %2')

    line = line:gsub('@return%s+.*%((' .. type .. ')%)', '@return %1')
    line = line:gsub('@return%s+.*%((' .. type .. '|nil)%)', '@return %1')
    line = line:gsub('@return%s+.*%((' .. type .. '%?)%)', '@return %1')
  end
  return line
end

--- If we collected any `---` lines. Add them to the existing (or new) object
--- Used for function/class descriptions and multiline param descriptions.
--- @param state nvim.luacats.parser.State
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
--- @param state nvim.luacats.parser.State
local function process_doc_line(line, state)
  line = line:sub(4):gsub('^%s+@', '@')
  line = use_type_alt(line)

  local parsed = luacats_grammar:match(line)

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
  state.cur_obj = state.cur_obj or {}
  local cur_obj = assert(state.cur_obj)

  local kind = parsed.kind

  if kind == 'brief' then
    state.cur_obj = {
      kind = 'brief',
      desc = parsed.desc,
    }
  elseif kind == 'class' then
    --- @cast parsed nvim.luacats.Class
    cur_obj.kind = 'class'
    cur_obj.name = parsed.name
    cur_obj.parent = parsed.parent
    cur_obj.access = parsed.access
    cur_obj.desc = state.doc_lines and table.concat(state.doc_lines, '\n') or nil
    state.doc_lines = nil
    cur_obj.fields = {}
  elseif kind == 'field' then
    --- @cast parsed nvim.luacats.Field
    parsed.desc = parsed.desc or state.doc_lines and table.concat(state.doc_lines, '\n') or nil
    if parsed.desc then
      parsed.desc = vim.trim(parsed.desc)
    end
    table.insert(cur_obj.fields, parsed)
    state.doc_lines = nil
  elseif kind == 'operator' then
    parsed.desc = parsed.desc or state.doc_lines and table.concat(state.doc_lines, '\n') or nil
    if parsed.desc then
      parsed.desc = vim.trim(parsed.desc)
    end
    table.insert(cur_obj.fields, parsed)
    state.doc_lines = nil
  elseif kind == 'param' then
    state.last_doc_item_indent = nil
    cur_obj.params = cur_obj.params or {}
    if vim.endswith(parsed.name, '?') then
      parsed.name = parsed.name:sub(1, -2)
      parsed.type = parsed.type .. '?'
    end
    state.last_doc_item = {
      name = parsed.name,
      type = parsed.type,
      desc = parsed.desc,
    }
    table.insert(cur_obj.params, state.last_doc_item)
  elseif kind == 'return' then
    cur_obj.returns = cur_obj.returns or {}
    for _, t in ipairs(parsed) do
      table.insert(cur_obj.returns, {
        name = t.name,
        type = t.type,
        desc = parsed.desc,
      })
    end
    state.last_doc_item_indent = nil
    state.last_doc_item = cur_obj.returns[#cur_obj.returns]
  elseif kind == 'private' then
    cur_obj.access = 'private'
  elseif kind == 'package' then
    cur_obj.access = 'package'
  elseif kind == 'protected' then
    cur_obj.access = 'protected'
  elseif kind == 'deprecated' then
    cur_obj.deprecated = true
  elseif kind == 'inlinedoc' then
    cur_obj.inlinedoc = true
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
  elseif kind == 'type' then
    cur_obj.desc = parsed.desc
    parsed.desc = nil
    parsed.kind = nil
    cur_obj.type = parsed
  elseif kind == 'alias' then
    state.cur_obj = {
      kind = 'alias',
      desc = parsed.desc,
    }
  elseif kind == 'enum' then
    -- TODO
    state.doc_lines = nil
  elseif
    vim.tbl_contains({
      'diagnostic',
      'cast',
      'overload',
      'meta',
    }, kind)
  then
    -- Ignore
    return
  elseif kind == 'generic' then
    cur_obj.generics = cur_obj.generics or {}
    cur_obj.generics[parsed.name] = parsed.type or 'any'
  else
    error('Unhandled' .. vim.inspect(parsed))
  end
end

--- @param fun nvim.luacats.parser.fun
--- @return nvim.luacats.parser.field
local function fun2field(fun)
  local parts = { 'fun(' }

  local params = {} ---@type string[]
  for _, p in ipairs(fun.params or {}) do
    params[#params + 1] = string.format('%s: %s', p.name, p.type)
  end
  parts[#parts + 1] = table.concat(params, ', ')
  parts[#parts + 1] = ')'
  if fun.returns then
    parts[#parts + 1] = ': '
    local tys = {} --- @type string[]
    for _, p in ipairs(fun.returns) do
      tys[#tys + 1] = p.type
    end
    parts[#parts + 1] = table.concat(tys, ', ')
  end

  return {
    name = fun.name,
    type = table.concat(parts, ''),
    access = fun.access,
    desc = fun.desc,
    nodoc = fun.nodoc,
  }
end

--- Function to normalize known form for declaring functions and normalize into a more standard
--- form.
--- @param line string
--- @return string
local function filter_decl(line)
  -- M.fun = vim._memoize(function(...)
  --   ->
  -- function M.fun(...)
  line = line:gsub('^local (.+) = memoize%([^,]+, function%((.*)%)$', 'local function %1(%2)')
  line = line:gsub('^(.+) = memoize%([^,]+, function%((.*)%)$', 'function %1(%2)')
  return line
end

--- @param line string
--- @param state nvim.luacats.parser.State
--- @param classes table<string,nvim.luacats.parser.class>
--- @param classvars table<string,string>
--- @param has_indent boolean
local function process_lua_line(line, state, classes, classvars, has_indent)
  line = filter_decl(line)

  if state.cur_obj and state.cur_obj.kind == 'class' then
    local nm = line:match('^local%s+([a-zA-Z0-9_]+)%s*=')
    if nm then
      classvars[nm] = state.cur_obj.name
    end
    return
  end

  do
    local parent_tbl, sep, fun_or_meth_nm =
      line:match('^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(')
    if parent_tbl then
      -- Have a decl. Ensure cur_obj
      state.cur_obj = state.cur_obj or {}
      local cur_obj = assert(state.cur_obj)

      -- Match `Class:foo` methods for defined classes
      local class = classvars[parent_tbl]
      if class then
        --- @cast cur_obj nvim.luacats.parser.fun
        cur_obj.name = fun_or_meth_nm
        cur_obj.class = class
        cur_obj.classvar = parent_tbl
        -- Add self param to methods
        if sep == ':' then
          cur_obj.params = cur_obj.params or {}
          table.insert(cur_obj.params, 1, {
            name = 'self',
            type = class,
          })
        end

        -- Add method as the field to the class
        local cls = classes[class]
        local field = fun2field(cur_obj)
        field.classvar = cur_obj.classvar
        table.insert(cls.fields, field)
        return
      end

      -- Match `M.foo`
      if cur_obj and parent_tbl == cur_obj.modvar then
        cur_obj.name = fun_or_meth_nm
        return
      end
    end
  end

  do
    -- Handle: `function A.B.C.foo(...)`
    local fn_nm = line:match('^function%s+([.a-zA-Z0-9_]+)%s*%(')
    if fn_nm then
      state.cur_obj = state.cur_obj or {}
      state.cur_obj.name = fn_nm
      return
    end
  end

  do
    -- Handle: `M.foo = {...}` where `M` is the modvar
    local parent_tbl, tbl_nm = line:match('([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=')
    if state.cur_obj and parent_tbl and parent_tbl == state.cur_obj.modvar then
      state.cur_obj.name = tbl_nm
      state.cur_obj.table = true
      return
    end
  end

  do
    -- Handle: `foo = {...}`
    local tbl_nm = line:match('^([a-zA-Z0-9_]+)%s*=')
    if tbl_nm and not has_indent then
      state.cur_obj = state.cur_obj or {}
      state.cur_obj.name = tbl_nm
      state.cur_obj.table = true
      return
    end
  end

  do
    -- Handle: `vim.foo = {...}`
    local tbl_nm = line:match('^(vim%.[a-zA-Z0-9_]+)%s*=')
    if state.cur_obj and tbl_nm and not has_indent then
      state.cur_obj.name = tbl_nm
      state.cur_obj.table = true
      return
    end
  end

  if state.cur_obj then
    if line:find('^%s*%-%- luacheck:') then
      state.cur_obj = nil
    elseif line:find('^%s*local%s+') then
      state.cur_obj = nil
    elseif line:find('^%s*return%s+') then
      state.cur_obj = nil
    elseif line:find('^%s*[a-zA-Z_.]+%(%s+') then
      state.cur_obj = nil
    end
  end
end

--- Determine the table name used to export functions of a module
--- Usually this is `M`.
--- @param str string
--- @return string?
local function determine_modvar(str)
  local modvar --- @type string?
  for line in vim.gsplit(str, '\n') do
    do
      --- @type string?
      local m = line:match('^return%s+([a-zA-Z_]+)')
      if m then
        modvar = m
      end
    end
    do
      --- @type string?
      local m = line:match('^return%s+setmetatable%(([a-zA-Z_]+),')
      if m then
        modvar = m
      end
    end
  end
  return modvar
end

--- @param obj nvim.luacats.parser.obj
--- @param funs nvim.luacats.parser.fun[]
--- @param classes table<string,nvim.luacats.parser.class>
--- @param briefs string[]
--- @param uncommitted nvim.luacats.parser.obj[]
local function commit_obj(obj, classes, funs, briefs, uncommitted)
  local commit = false
  if obj.kind == 'class' then
    --- @cast obj nvim.luacats.parser.class
    if not classes[obj.name] then
      classes[obj.name] = obj
      commit = true
    end
  elseif obj.kind == 'alias' then
    -- Just pretend
    commit = true
  elseif obj.kind == 'brief' then
    --- @cast obj nvim.luacats.parser.brief`
    briefs[#briefs + 1] = obj.desc
    commit = true
  else
    --- @cast obj nvim.luacats.parser.fun`
    if obj.name then
      funs[#funs + 1] = obj
      commit = true
    end
  end
  if not commit then
    table.insert(uncommitted, obj)
  end
  return commit
end

--- @param filename string
--- @param uncommitted nvim.luacats.parser.obj[]
-- luacheck: no unused
local function dump_uncommitted(filename, uncommitted)
  local out_path = 'luacats-uncommited/' .. filename:gsub('/', '%%') .. '.txt'
  if #uncommitted > 0 then
    print(string.format('Could not commit %d objects in %s', #uncommitted, filename))
    vim.fn.mkdir(vim.fs.dirname(out_path), 'p')
    local f = assert(io.open(out_path, 'w'))
    for i, x in ipairs(uncommitted) do
      f:write(i)
      f:write(': ')
      f:write(vim.inspect(x))
      f:write('\n')
    end
    f:close()
  else
    vim.fn.delete(out_path)
  end
end

local M = {}

function M.parse_str(str, filename)
  local funs = {} --- @type nvim.luacats.parser.fun[]
  local classes = {} --- @type table<string,nvim.luacats.parser.class>
  local briefs = {} --- @type string[]

  local mod_return = determine_modvar(str)

  --- @type string
  local module = filename:match('.*/lua/([a-z_][a-z0-9_/]+)%.lua') or filename
  module = module:gsub('/', '.')

  local classvars = {} --- @type table<string,string>

  local state = {} --- @type nvim.luacats.parser.State

  -- Keep track of any partial objects we don't commit
  local uncommitted = {} --- @type nvim.luacats.parser.obj[]

  for line in vim.gsplit(str, '\n') do
    local has_indent = line:match('^%s+') ~= nil
    line = vim.trim(line)
    if vim.startswith(line, '---') then
      process_doc_line(line, state)
    else
      add_doc_lines_to_obj(state)

      if state.cur_obj then
        state.cur_obj.modvar = mod_return
        state.cur_obj.module = module
      end

      process_lua_line(line, state, classes, classvars, has_indent)

      -- Commit the object
      local cur_obj = state.cur_obj
      if cur_obj then
        if not commit_obj(cur_obj, classes, funs, briefs, uncommitted) then
          --- @diagnostic disable-next-line:inject-field
          cur_obj.line = line
        end
      end

      state = {}
    end
  end

  -- dump_uncommitted(filename, uncommitted)

  return classes, funs, briefs, uncommitted
end

--- @param filename string
function M.parse(filename)
  local f = assert(io.open(filename, 'r'))
  local txt = f:read('*all')
  f:close()

  return M.parse_str(txt, filename)
end

return M
