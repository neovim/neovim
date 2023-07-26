#!/usr/bin/env -S nvim -l

--- @class vim.EvalFn2 : vim.EvalFn
--- @field signature string
--- @field desc string[]
--- @field params {[1]: string, [2]: string}[]

--- @param filename string
--- @return string
local function safe_read(filename)
  local file, err = io.open(filename, 'r')
  if not file then
    error(err)
  end
  local content = file:read('*a')
  io.close(file)
  return content
end

local nvim_eval = require'src/nvim/eval'

local funcs = nvim_eval.funcs --[[@as table<string,vim.EvalFn2>]]

local LUA_KEYWORDS = {
  ['and'] = true,
  ['end'] = true,
  ['function'] = true,
  ['or'] = true,
  ['if'] = true,
  ['while'] = true,
  ['repeat'] = true
}

local SOURCES = {
  {
    path = 'runtime/doc/builtin.txt',
    from = '^2. Details',
    to = '==========',
  },
  {
    path = 'runtime/doc/sign.txt',
    from = '^3. Functions',
    to = 'vim:'
  },
  {
    path = 'runtime/doc/testing.txt',
    from = '^3. Assert functions',
    to = 'vim:'
  }
}

local ARG_NAME_TYPES = {
  col = 'integer',
  nosuf = 'boolean',
  dir = 'string',
  mode = 'string',
  width = 'integer',
  height = 'integer',
  timeout = 'integer',
  libname = 'string',
  funcname = 'string',
  end_ = 'integer',
  file = 'string',
  flags = 'string',
  fname = 'integer',
  idx = 'integer',
  lnum = 'integer',
  mods = 'string',
  name = 'string',
  nr = 'integer',
  options = 'table',
  opts = 'table',
  path = 'string',
  regname = 'string',
  silent = 'boolean',
  string = 'string',
  tabnr = 'integer',
  varname = 'string',
  winid = 'integer',
  winnr = 'integer',
}

local function process_source(source)
  local src_txt = safe_read(source.path)

  --- @type string[]
  local src_lines = vim.split(src_txt, '\n', { plain = true })

  local s = 0
  for i, l in ipairs(src_lines) do
    if l:match(source.from) then
      s = i+1
    end
  end

  local lines = {} --- @type string[]
  local last_f --- @type string?
  local last_l --- @type string?

  for i = s, #src_lines do
    local l = src_lines[i]
    if not l or l:match(source.to) then
      break
    end
    local f = l:match('^([a-z][a-zA-Z0-9_]*)%(')
    if f then
      if last_f then
        if last_l and last_l:find('*' .. f .. '()*', 1, true) then
          lines[#lines] = nil
        end
        funcs[last_f].desc = lines
      end
      last_f = f
      local sig = l:match('[^)]+%)')
      local params = {} --- @type table[]
      if sig then
        for param in string.gmatch(sig, '{([a-z][a-zA-Z0-9_]*)}') do
          local t = ARG_NAME_TYPES[param] or 'any'
          params[#params+1] = {param, t}
        end
      else
        print('error parsing', l)
      end

      funcs[last_f].signature = sig
      funcs[last_f].params = params

      lines = {}
    else
      lines[#lines+1] = l:gsub('^(<?)\t\t', '%1'):gsub('\t', '  ')
    end
    last_l = l
  end

  if last_f then
    funcs[last_f].desc = lines
  end
end

local function render_fun_sig(f, params)
  local param_str --- @type string
  if params == true then
    param_str = '...'
  else
    param_str = table.concat(vim.tbl_map(function(v)
      return v[1]
    end, params), ', ')
  end

  if LUA_KEYWORDS[f] then
    return string.format('vim.fn[\'%s\'] = function(%s) end', f, param_str)
  else
    return string.format('function vim.fn.%s(%s) end', f, param_str)
  end
end

--- Uniquify names
--- Fix any names that are lua keywords
--- @param fun vim.EvalFn2
local function process_params(fun)
  if not fun.params then
    return
  end

  local seen = {} --- @type table<string,true>
  local sfx = 1

  for _, p in ipairs(fun.params) do
    if LUA_KEYWORDS[p[1]] then
      p[1] = p[1]..'_'
    end
    if seen[p[1]] then
      p[1] = p[1]..sfx
      sfx = sfx + 1
    else
      seen[p[1]] = true
    end
  end
end

--- @param funname string
--- @param fun vim.EvalFn2
--- @param write fun(line: string)
local function render_fun(funname, fun, write)
  if fun.deprecated then
    write('')
    write('--- @deprecated')
    for _, l in ipairs(fun.deprecated) do
      write('--- '.. l)
    end
    write(render_fun_sig(funname, true))
    return
  end

  if fun.desc and fun.signature then
    write('')
    for _, l in ipairs(fun.desc) do
      write('--- '.. l:gsub('@', '\\@'))
    end

    local req_args = type(fun.args) == 'table' and fun.args[1] or fun.args or 0

    for i, param in ipairs(fun.params) do
      if i <= req_args then
        write('--- @param '..param[1]..' '..param[2])
      else
        write('--- @param '..param[1]..'? '..param[2])
      end
    end
    if fun.returns ~= false then
      write('--- @return '..(fun.returns or 'any'))
    end
    write(render_fun_sig(funname, fun.params))
    return
  end

  print('no doc for', funname)
end

local function main(outfile)
  local o = assert(io.open(outfile, 'w'))

  local function write(l)
    local l1 = l:gsub('%s+$', '')
    o:write(l1)
    o:write('\n')
  end

  for _, source in ipairs(SOURCES) do
    process_source(source)
  end

  --- @type string[]
  local fnames = vim.tbl_keys(funcs)
  table.sort(fnames)

  write('--- @meta')
  write('-- THIS FILE IS GENERATED')
  write('-- DO NOT EDIT')

  for _, f in ipairs(fnames) do
    local fun = funcs[f]
    process_params(fun)
    render_fun(f, fun, write)
  end
end

main('runtime/lua/vim/_meta/vimfn.lua')

