#!/usr/bin/env -S nvim -l
-- Generator for src/nvim/eval.lua

local funcs = require('src/nvim/eval').funcs

local LUA_KEYWORDS = {
  ['and'] = true,
  ['end'] = true,
  ['function'] = true,
  ['or'] = true,
  ['if'] = true,
  ['while'] = true,
  ['repeat'] = true,
}

--- @param f string
--- @param params {[1]:string,[2]:string}[]|true
local function render_fun_sig(f, params)
  local param_str --- @type string
  if params == true then
    param_str = '...'
  else
    param_str = table.concat(
      vim.tbl_map(
        --- @param v {[1]:string,[2]:string}
        function(v)
          return v[1]
        end,
        params
      ),
      ', '
    )
  end

  if LUA_KEYWORDS[f] then
    return string.format("vim.fn['%s'] = function(%s) end", f, param_str)
  else
    return string.format('function vim.fn.%s(%s) end', f, param_str)
  end
end

--- Uniquify names
--- Fix any names that are lua keywords
--- @param params {[1]:string,[2]:string}[]
--- @return {[1]:string,[2]:string}[]
local function process_params(params)
  local seen = {} --- @type table<string,true>
  local sfx = 1

  for _, p in ipairs(params) do
    if LUA_KEYWORDS[p[1]] then
      p[1] = p[1] .. '_'
    end
    if seen[p[1]] then
      p[1] = p[1] .. sfx
      sfx = sfx + 1
    else
      seen[p[1]] = true
    end
  end

  return params
end

--- @param f string
--- @param fun vim.EvalFn
--- @param write fun(line: string)
local function render_vimfn(f, fun, write)
  if fun.lua == false then
    return
  end

  local funname = fun.name or f

  local params = process_params(fun.params)

  if fun.signature then
    write('')
    if fun.deprecated then
      write('--- @deprecated')
    end

    local desc = fun.desc

    if desc then
      desc = desc:gsub('\n%s*\n%s*$', '\n')
      for _, l in ipairs(vim.split(desc, '\n', { plain = true })) do
        l = l:gsub('^      ', ''):gsub('\t', '  '):gsub('@', '\\@')
        write('--- ' .. l)
      end
    end

    local req_args = type(fun.args) == 'table' and fun.args[1] or fun.args or 0

    for i, param in ipairs(params) do
      local pname, ptype = param[1], param[2]
      local optional = (pname ~= '...' and i > req_args) and '?' or ''
      write(string.format('--- @param %s%s %s', pname, optional, ptype))
    end

    if fun.returns ~= false then
      write('--- @return ' .. (fun.returns or 'any'))
    end

    write(render_fun_sig(funname, params))

    return
  end

  print('no doc for', funname)
end

--- @type table<string,true>
local rendered_tags = {}

--- @param f string
--- @param fun vim.EvalFn
--- @param write fun(line: string)
local function render_eval_doc(f, fun, write)
  if fun.deprecated then
    return
  end

  if not fun.signature then
    return
  end

  local desc = fun.desc

  if not desc then
    write(fun.signature)
    return
  end

  local name = fun.name or f
  local tags = { '*' .. name .. '()*' }
  if fun.tags then
    for _, t in ipairs(fun.tags) do
      tags[#tags + 1] = '*' .. t .. '*'
    end
  end
  local tag = table.concat(tags, ' ')

  local siglen = #fun.signature
  if rendered_tags[name] then
    write(fun.signature)
  else
    if siglen + #tag > 80 then
      write(string.rep('\t', 6) .. tag)
      write(fun.signature)
    else
      local tt = math.max(1, (76 - siglen - #tag) / 8)
      write(string.format('%s%s%s', fun.signature, string.rep('\t', tt), tag))
    end
  end
  rendered_tags[name] = true

  desc = vim.trim(desc)
  local desc_l = vim.split(desc, '\n', { plain = true })
  for _, l in ipairs(desc_l) do
    l = l:gsub('^      ', '')
    if vim.startswith(l, '<') and not l:match('^<[A-Z][A-Z]') then
      write('<\t\t' .. l:sub(2))
    else
      write('\t\t' .. l)
    end
  end

  if #desc_l > 0 and not desc_l[#desc_l]:match('^<?$') then
    write('')
  end
end

--- @class nvim.gen_eval_files.elem
--- @field path string
--- @field render fun(f:string,fun:vim.EvalFn,write:fun(line:string))
--- @field header? string[]
--- @field footer? string[]

--- @type nvim.gen_eval_files.elem[]
local CONFIG = {
  {
    path = 'runtime/lua/vim/_meta/vimfn.lua',
    render = render_vimfn,
    header = {
      '--- @meta',
      '-- THIS FILE IS GENERATED',
      '-- DO NOT EDIT',
    },
  },
  {
    path = 'runtime/doc/builtin.txt',
    render = render_eval_doc,
    header = {
      '*builtin.txt*	Nvim',
      '',
      '',
      '\t\t  VIM REFERENCE MANUAL\t  by Bram Moolenaar',
      '',
      '',
      'Builtin functions\t\t*vimscript-functions* *builtin-functions*',
      '',
      'For functions grouped by what they are used for see |function-list|.',
      '',
      '\t\t\t\t      Type |gO| to see the table of contents.',
      '==============================================================================',
      '1. Details					*builtin-function-details*',
      '',
    },
    footer = {
      '==============================================================================',
      '2. Matching a pattern in a String			*string-match*',
      '',
      'This is common between several functions. A regexp pattern as explained at',
      '|pattern| is normally used to find a match in the buffer lines.  When a',
      'pattern is used to find a match in a String, almost everything works in the',
      'same way.  The difference is that a String is handled like it is one line.',
      'When it contains a "\\n" character, this is not seen as a line break for the',
      'pattern.  It can be matched with a "\\n" in the pattern, or with ".".  Example:',
      '>',
      '\t:let a = "aaaa\\nxxxx"',
      '\t:echo matchstr(a, "..\\n..")',
      '\taa',
      '\txx',
      '\t:echo matchstr(a, "a.x")',
      '\ta',
      '\tx',
      '',
      'Don\'t forget that "^" will only match at the first character of the String and',
      '"$" at the last character of the string.  They don\'t match after or before a',
      '"\\n".',
      '',
      ' vim:tw=78:ts=8:noet:ft=help:norl:',
    },
  },
}

--- @param elem nvim.gen_eval_files.elem
local function render(elem)
  local o = assert(io.open(elem.path, 'w'))

  --- @param l string
  local function write(l)
    local l1 = l:gsub('%s+$', '')
    o:write(l1)
    o:write('\n')
  end

  for _, l in ipairs(elem.header or {}) do
    write(l)
  end

  --- @type string[]
  local fnames = vim.tbl_keys(funcs)
  table.sort(fnames)

  for _, f in ipairs(fnames) do
    elem.render(f, funcs[f], write)
  end

  for _, l in ipairs(elem.footer or {}) do
    write(l)
  end

  o:close()
end

local function main()
  for _, c in ipairs(CONFIG) do
    render(c)
  end
end

main()
