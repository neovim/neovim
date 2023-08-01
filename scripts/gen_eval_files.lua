#!/usr/bin/env -S nvim -l
-- Generator for src/nvim/eval.lua

--- @class vim.api.metadata
--- @field name string
--- @field parameters {[1]:string,[2]:string}[]
--- @field return_type string
--- @field deprecated_since integer
--- @field eval boolean
--- @field fast boolean
--- @field handler_id integer
--- @field impl_name string
--- @field lua boolean
--- @field method boolean
--- @field remote boolean
--- @field since integer

local LUA_META_HEADER = {
  '--- @meta',
  '-- THIS FILE IS GENERATED',
  '-- DO NOT EDIT',
  "error('Cannot require a meta file')",
}

local LUA_API_META_HEADER = {
  '--- @meta',
  '-- THIS FILE IS GENERATED',
  '-- DO NOT EDIT',
  "error('Cannot require a meta file')",
  '',
  'vim.api = {}',
}

local LUA_KEYWORDS = {
  ['and'] = true,
  ['end'] = true,
  ['function'] = true,
  ['or'] = true,
  ['if'] = true,
  ['while'] = true,
  ['repeat'] = true,
}

local API_TYPES = {
  Window = 'integer',
  Tabpage = 'integer',
  Buffer = 'integer',
  Boolean = 'boolean',
  Object = 'any',
  Integer = 'integer',
  String = 'string',
  Array = 'any[]',
  LuaRef = 'function',
  Dictionary = 'table<string,any>',
  Float = 'number',
  void = '',
}

--- Convert an API type to Lua
--- @param t string
--- @return string
local function api_type(t)
  if t:match('^ArrayOf%(([z-aA-Z]+), %d+%') then
    print(t:match('^ArrayOf%(([z-aA-Z]+), %d+%'))
  end
  local as0 = t:match('^ArrayOf%((.*)%)')
  if as0 then
    local as = vim.split(as0, ', ', { plain = true })
    return api_type(as[1]) .. '[]'
  end

  local d = t:match('^Dict%((.*)%)')
  if d then
    return 'vim.api.keyset.' .. d
  end

  local d0 = t:match('^DictionaryOf%((.*)%)')
  if d0 then
    return 'table<string,' .. api_type(d0) .. '>'
  end

  return API_TYPES[t] or t
end

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
--- @param params {[1]:string,[2]:string,[3]:string}[]
--- @return {[1]:string,[2]:string,[3]:string}[]
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

--- @class vim.gen_vim_doc_fun
--- @field signature string
--- @field doc string[]
--- @field parameters_doc table<string,string>
--- @field return string[]
--- @field seealso string[]
--- @field annotations string[]

--- @return table<string, vim.EvalFn>
local function get_api_funcs()
  local mpack_f = assert(io.open('build/api_metadata.mpack', 'rb'))
  local metadata = vim.mpack.decode(mpack_f:read('*all')) --[[@as vim.api.metadata[] ]]
  local ret = {} --- @type table<string, vim.EvalFn>

  local doc_mpack_f = assert(io.open('runtime/doc/api.mpack', 'rb'))
  local doc_metadata = vim.mpack.decode(doc_mpack_f:read('*all')) --[[@as table<string,vim.gen_vim_doc_fun>]]

  for _, fun in ipairs(metadata) do
    local fdoc = doc_metadata[fun.name]

    local params = {} --- @type {[1]:string,[2]:string}[]
    for _, p in ipairs(fun.parameters) do
      local ptype, pname = p[1], p[2]
      params[#params + 1] = {
        pname,
        api_type(ptype),
        fdoc and fdoc.parameters_doc[pname] or nil,
      }
    end

    local r = {
      signature = 'NA',
      name = fun.name,
      params = params,
      returns = api_type(fun.return_type),
      deprecated = fun.deprecated_since ~= nil,
    }

    if fdoc then
      if #fdoc.doc > 0 then
        r.desc = table.concat(fdoc.doc, '\n')
      end
      r.return_desc = (fdoc['return'] or {})[1]
    end

    ret[fun.name] = r
  end
  return ret
end

--- Convert vimdoc references to markdown literals
--- Convert vimdoc codeblocks to markdown codeblocks
--- @param x string
--- @return string
local function norm_text(x)
  return (
    x:gsub('|([^ ]+)|', '`%1`')
      :gsub('>lua', '\n```lua')
      :gsub('>vim', '\n```vim')
      :gsub('\n<$', '\n```')
      :gsub('\n<\n', '\n```\n')
  )
end

--- @param _f string
--- @param fun vim.EvalFn
--- @param write fun(line: string)
local function render_api_fun(_f, fun, write)
  if not vim.startswith(fun.name, 'nvim_') then
    return
  end

  write('')

  if vim.startswith(fun.name, 'nvim__') then
    write('--- @private')
  end

  if fun.deprecated then
    write('--- @deprecated')
  end

  local desc = fun.desc
  if desc then
    for _, l in ipairs(vim.split(norm_text(desc), '\n', { plain = true })) do
      write('--- ' .. l)
    end
    write('---')
  end

  local param_names = {} --- @type string[]
  local params = process_params(fun.params)
  for _, p in ipairs(params) do
    param_names[#param_names + 1] = p[1]
    local pdesc = p[3]
    if pdesc then
      local pdesc_a = vim.split(norm_text(pdesc), '\n', { plain = true })
      write('--- @param ' .. p[1] .. ' ' .. p[2] .. ' ' .. pdesc_a[1])
      for i = 2, #pdesc_a do
        if not pdesc_a[i] then
          break
        end
        write('--- ' .. pdesc_a[i])
      end
    else
      write('--- @param ' .. p[1] .. ' ' .. p[2])
    end
  end
  if fun.returns ~= '' then
    if fun.returns_desc then
      write('--- @return ' .. fun.returns .. ' : ' .. fun.returns_desc)
    else
      write('--- @return ' .. fun.returns)
    end
  end
  local param_str = table.concat(param_names, ', ')

  write(string.format('function vim.api.%s(%s) end', fun.name, param_str))
end

--- @return table<string, vim.EvalFn>
local function get_api_keysets()
  local mpack_f = assert(io.open('build/api_metadata.mpack', 'rb'))

  --- @diagnostic disable-next-line:no-unknown
  local metadata = assert(vim.mpack.decode(mpack_f:read('*all')))

  local ret = {} --- @type table<string, vim.EvalFn>

  --- @type {[1]: string, [2]: {[1]: string, [2]: string}[] }[]
  local keysets = metadata.keysets

  for _, keyset in ipairs(keysets) do
    local kname = keyset[1]
    local kdef = keyset[2]
    for _, field in ipairs(kdef) do
      field[2] = api_type(field[2])
    end
    ret[kname] = {
      signature = 'NA',
      name = kname,
      params = kdef,
    }
  end

  return ret
end

--- @param _f string
--- @param fun vim.EvalFn
--- @param write fun(line: string)
local function render_api_keyset(_f, fun, write)
  write('')
  write('--- @class vim.api.keyset.' .. fun.name)
  for _, p in ipairs(fun.params) do
    write('--- @field ' .. p[1] .. ' ' .. p[2])
  end
end

--- @return table<string, vim.EvalFn>
local function get_eval_funcs()
  return require('src/nvim/eval').funcs
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
      --- @type string
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

--- @param name string
--- @param fun vim.EvalFn
--- @param write fun(line: string)
local function render_sig_and_tag(name, fun, write)
  local tags = { '*' .. name .. '()*' }

  if fun.tags then
    for _, t in ipairs(fun.tags) do
      tags[#tags + 1] = '*' .. t .. '*'
    end
  end

  local tag = table.concat(tags, ' ')
  local siglen = #fun.signature
  local conceal_offset = 2*(#tags - 1)
  local tag_pad_len = math.max(1, 80 - #tag + conceal_offset)

  if siglen + #tag > 80 then
    write(string.rep(' ', tag_pad_len) .. tag)
    write(fun.signature)
  else
    write(string.format('%s%s%s', fun.signature, string.rep(' ', tag_pad_len - siglen), tag))
  end
end

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

  if rendered_tags[name] then
    write(fun.signature)
  else
    render_sig_and_tag(name, fun, write)
    rendered_tags[name] = true
  end

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
--- @field funcs fun(): table<string, vim.EvalFn>
--- @field render fun(f:string,fun:vim.EvalFn,write:fun(line:string))
--- @field header? string[]
--- @field footer? string[]

--- @type nvim.gen_eval_files.elem[]
local CONFIG = {
  {
    path = 'runtime/lua/vim/_meta/vimfn.lua',
    header = LUA_META_HEADER,
    funcs = get_eval_funcs,
    render = render_vimfn,
  },
  {
    path = 'runtime/lua/vim/_meta/api.lua',
    header = LUA_API_META_HEADER,
    funcs = get_api_funcs,
    render = render_api_fun,
  },
  {
    path = 'runtime/lua/vim/_meta/api_keysets.lua',
    header = LUA_META_HEADER,
    funcs = get_api_keysets,
    render = render_api_keyset,
  },
  {
    path = 'runtime/doc/builtin.txt',
    funcs = get_eval_funcs,
    render = render_eval_doc,
    header = {
      '*builtin.txt*	Nvim',
      '',
      '',
      '\t\t  NVIM REFERENCE MANUAL',
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
      '>vim',
      '\tlet a = "aaaa\\nxxxx"',
      '\techo matchstr(a, "..\\n..")',
      '\t" aa',
      '\t" xx',
      '\techo matchstr(a, "a.x")',
      '\t" a',
      '\t" x',
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

  local funcs = elem.funcs()

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
