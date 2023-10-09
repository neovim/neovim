#!/usr/bin/env -S nvim -l
-- Generator for various vimdoc and Lua type files

local DEP_API_METADATA = 'build/api_metadata.mpack'
local DEP_API_DOC  = 'runtime/doc/api.mpack'

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
  '--- @meta _',
  '-- THIS FILE IS GENERATED',
  '-- DO NOT EDIT',
  "error('Cannot require a meta file')",
}

local LUA_API_META_HEADER = {
  '--- @meta _',
  '-- THIS FILE IS GENERATED',
  '-- DO NOT EDIT',
  "error('Cannot require a meta file')",
  '',
  'vim.api = {}',
}

local LUA_OPTION_META_HEADER = {
  '--- @meta _',
  '-- THIS FILE IS GENERATED',
  '-- DO NOT EDIT',
  "error('Cannot require a meta file')",
  '',
  '---@class vim.bo',
  '---@field [integer] vim.bo',
  'vim.bo = vim.bo',
  '',
  '---@class vim.wo',
  '---@field [integer] vim.wo',
  'vim.wo = vim.wo',
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

local OPTION_TYPES = {
  bool = 'boolean',
  number = 'integer',
  string = 'string',
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

--- @param x string
--- @param sep? string
--- @return string[]
local function split(x, sep)
  return vim.split(x, sep or '\n', { plain = true })
end

--- Convert an API type to Lua
--- @param t string
--- @return string
local function api_type(t)
  local as0 = t:match('^ArrayOf%((.*)%)')
  if as0 then
    local as = split(as0, ', ')
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
--- @return string
local function render_fun_sig(f, params)
  local param_str --- @type string
  if params == true then
    param_str = '...'
  else
    param_str = table.concat(
      vim.tbl_map(
        --- @param v {[1]:string,[2]:string}
        --- @return string
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
local function get_api_meta()
  local mpack_f = assert(io.open(DEP_API_METADATA, 'rb'))
  local metadata = vim.mpack.decode(mpack_f:read('*all')) --[[@as vim.api.metadata[] ]]
  local ret = {} --- @type table<string, vim.EvalFn>

  local doc_mpack_f = assert(io.open(DEP_API_DOC, 'rb'))
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
---
--- Ensure code blocks have one empty line before the start fence and after the closing fence.
---
--- @param x string
--- @return string
local function norm_text(x)
  return (
    x:gsub('|([^ ]+)|', '`%1`')
      :gsub('\n*>lua', '\n\n```lua')
      :gsub('\n*>vim', '\n\n```vim')
      :gsub('\n+<$', '\n```')
      :gsub('\n+<\n+', '\n```\n\n')
      :gsub('%s+>\n+', '\n```\n')
      :gsub('\n+<%s+\n?', '\n```\n')
  )
end

--- @param _f string
--- @param fun vim.EvalFn
--- @param write fun(line: string)
local function render_api_meta(_f, fun, write)
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
    for _, l in ipairs(split(norm_text(desc))) do
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
      local pdesc_a = split(norm_text(pdesc))
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
local function get_api_keysets_meta()
  local mpack_f = assert(io.open(DEP_API_METADATA, 'rb'))

  --- @diagnostic disable-next-line:no-unknown
  local metadata = assert(vim.mpack.decode(mpack_f:read('*all')))

  local ret = {} --- @type table<string, vim.EvalFn>

  --- @type {name: string, keys: string[], types: table<string,string>}[]
  local keysets = metadata.keysets

  for _, k in ipairs(keysets) do
    local params = {}
    for _, key in ipairs(k.keys) do
      table.insert(params, {key..'?', api_type(k.types[key] or 'any')})
    end
    ret[k.name] = {
      signature = 'NA',
      name = k.name,
      params = params,
    }
  end

  return ret
end

--- @param _f string
--- @param fun vim.EvalFn
--- @param write fun(line: string)
local function render_api_keyset_meta(_f, fun, write)
  write('')
  write('--- @class vim.api.keyset.' .. fun.name)
  for _, p in ipairs(fun.params) do
    write('--- @field ' .. p[1] .. ' ' .. p[2])
  end
end

--- @return table<string, vim.EvalFn>
local function get_eval_meta()
  return require('src/nvim/eval').funcs
end

--- @param f string
--- @param fun vim.EvalFn
--- @param write fun(line: string)
local function render_eval_meta(f, fun, write)
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
      for _, l in ipairs(split(desc)) do
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
  local desc_l = split(desc)
  for _, l in ipairs(desc_l) do
    l = l:gsub('^      ', '')
    if vim.startswith(l, '<') and not l:match('^<[^ \t]+>') then
      write('<\t\t' .. l:sub(2))
    elseif l:match('^>[a-z0-9]*$') then
      write(l)
    else
      write('\t\t' .. l)
    end
  end

  if #desc_l > 0 and not desc_l[#desc_l]:match('^<?$') then
    write('')
  end
end

--- @param d vim.option_defaults
--- @param vimdoc? boolean
--- @return string
local function render_option_default(d, vimdoc)
  local dt --- @type integer|boolean|string|fun(): string
  if d.if_false ~= nil then
    dt = d.if_false
  else
    dt = d.if_true
  end

  if vimdoc then
    if d.doc then
      return d.doc
    end
    if type(dt) == 'boolean' then
      return dt and 'on' or 'off'
    end
  end

  if dt == "" or dt == nil or type(dt) == 'function' then
    dt = d.meta
  end

  local v --- @type string
  if not vimdoc then
    v = vim.inspect(dt) --[[@as string]]
  else
    v = type(dt) == 'string' and '"'..dt..'"' or tostring(dt)
  end

  --- @type table<string, string|false>
  local envvars = {
    TMPDIR = false,
    VIMRUNTIME = false,
    XDG_CONFIG_HOME = vim.env.HOME..'/.local/config',
    XDG_DATA_HOME = vim.env.HOME..'/.local/share',
    XDG_STATE_HOME = vim.env.HOME..'/.local/state',
  }

  for name, default in pairs(envvars) do
    local value = vim.env[name] or default
    if value then
      v = v:gsub(vim.pesc(value), '$'..name)
    end
  end

  return v
end

--- @param _f string
--- @param opt vim.option_meta
--- @param write fun(line: string)
local function render_option_meta(_f, opt, write)
  write('')
  for _, l in ipairs(split(norm_text(opt.desc))) do
    write('--- '..l)
  end

  write('--- @type '..OPTION_TYPES[opt.type])
  write('vim.o.'..opt.full_name..' = '..render_option_default(opt.defaults))
  if opt.abbreviation then
    write('vim.o.'..opt.abbreviation..' = vim.o.'..opt.full_name)
  end

  for _, s in pairs {
    {'wo', 'window'},
    {'bo', 'buffer'},
    {'go', 'global'},
  } do
    local id, scope = s[1], s[2]
    if vim.list_contains(opt.scope, scope) or (id == 'go' and #opt.scope > 1) then
      local pfx = 'vim.'..id..'.'
      write(pfx..opt.full_name..' = vim.o.'..opt.full_name)
      if opt.abbreviation then
        write(pfx..opt.abbreviation..' = '..pfx..opt.full_name)
      end
    end
  end
end

--- @param s string[]
--- @return string
local function scope_to_doc(s)
  local m = {
    global = 'global',
    buffer = 'local to buffer',
    window = 'local to window',
    tab = 'local to tab page'
  }

  if #s == 1 then
    return m[s[1]]
  end
  assert(s[1] == 'global')
  return 'global or '..m[s[2]]..' |global-local|'
end

-- @param o vim.option_meta
-- @return string
local function scope_more_doc(o)
  if
    vim.list_contains({
      'bufhidden',
      'buftype',
      'filetype',
      'modified',
      'previewwindow',
      'readonly',
      'scroll',
      'syntax',
      'winfixheight',
      'winfixwidth',
    }, o.full_name)
  then
    return '  |local-noglobal|'
  end

  return ''
end

--- @return table<string,vim.option_meta>
local function get_option_meta()
  local opts = require('src/nvim/options').options
  local optinfo = vim.api.nvim_get_all_options_info()
  local ret = {} --- @type table<string,vim.option_meta>
  for _, o in ipairs(opts) do
    if o.desc then
      if o.full_name == 'cmdheight' then
        table.insert(o.scope, 'tab')
      end
      local r = vim.deepcopy(o) --[[@as vim.option_meta]]
      r.desc = o.desc:gsub('^        ', ''):gsub('\n        ', '\n')
      r.defaults = r.defaults or {}
      if r.defaults.meta == nil then
        r.defaults.meta = optinfo[o.full_name].default
      end
      ret[o.full_name] = r
    end
  end
  return ret
end

--- @param opt vim.option_meta
--- @return string[]
local function build_option_tags(opt)
  --- @type string[]
  local tags = { opt.full_name }

  tags[#tags+1] = opt.abbreviation
  if opt.type == 'bool' then
    for i = 1, #tags do
      tags[#tags+1] = 'no'..tags[i]
    end
  end

  for i, t in ipairs(tags) do
    tags[i] = "'"..t.."'"
  end

  for _, t in ipairs(opt.tags or {}) do
    tags[#tags+1] = t
  end

  for i, t in ipairs(tags) do
    tags[i] = "*"..t.."*"
  end

  return tags
end

--- @param _f string
--- @param opt vim.option_meta
--- @param write fun(line: string)
local function render_option_doc(_f, opt, write)
  local tags = build_option_tags(opt)
  local tag_str = table.concat(tags, ' ')
  local conceal_offset = 2*(#tags - 1)
  local tag_pad = string.rep('\t', math.ceil((64 - #tag_str + conceal_offset) / 8))
  -- local pad = string.rep(' ', 80 - #tag_str + conceal_offset)
  write(tag_pad..tag_str)

  local name_str --- @type string
  if opt.abbreviation then
    name_str = string.format("'%s' '%s'", opt.full_name, opt.abbreviation)
  else
    name_str = string.format("'%s'", opt.full_name)
  end

  local otype = opt.type == 'bool' and 'boolean' or opt.type
  if opt.defaults.doc or opt.defaults.if_true ~= nil or opt.defaults.meta ~= nil then
    local v = render_option_default(opt.defaults, true)
    local pad = string.rep('\t', math.max(1, math.ceil((24 - #name_str) / 8)))
    if opt.defaults.doc then
      local deflen = #string.format('%s%s%s (', name_str, pad, otype)
      --- @type string
      v = v:gsub('\n', '\n'..string.rep(' ', deflen - 2))
    end
    write(string.format('%s%s%s\t(default %s)', name_str, pad, otype, v))
  else
    write(string.format('%s\t%s', name_str, otype))
  end

  write('\t\t\t'..scope_to_doc(opt.scope)..scope_more_doc(opt))
  for _, l in ipairs(split(opt.desc)) do
    if l == '<' or l:match('^<%s') then
      write(l)
    else
      write('\t'..l:gsub('\\<', '<'))
    end
  end
end

--- @class nvim.gen_eval_files.elem
--- @field path string
--- @field from? string Skip lines in path until this pattern is reached.
--- @field funcs fun(): table<string, table>
--- @field render fun(f:string,obj:table,write:fun(line:string))
--- @field header? string[]
--- @field footer? string[]

--- @type nvim.gen_eval_files.elem[]
local CONFIG = {
  {
    path = 'runtime/lua/vim/_meta/vimfn.lua',
    header = LUA_META_HEADER,
    funcs = get_eval_meta,
    render = render_eval_meta,
  },
  {
    path = 'runtime/lua/vim/_meta/api.lua',
    header = LUA_API_META_HEADER,
    funcs = get_api_meta,
    render = render_api_meta,
  },
  {
    path = 'runtime/lua/vim/_meta/api_keysets.lua',
    header = LUA_META_HEADER,
    funcs = get_api_keysets_meta,
    render = render_api_keyset_meta,
  },
  {
    path = 'runtime/doc/builtin.txt',
    funcs = get_eval_meta,
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
  {
    path = 'runtime/lua/vim/_meta/options.lua',
    header = LUA_OPTION_META_HEADER,
    funcs = get_option_meta,
    render = render_option_meta,
  },
  {
    path = 'runtime/doc/options.txt',
    header = { '' },
    from = 'A jump table for the options with a short description can be found at |Q_op|.',
    footer = {
      ' vim:tw=78:ts=8:noet:ft=help:norl:'
    },
    funcs = get_option_meta,
    render = render_option_doc,
  }
}

--- @param elem nvim.gen_eval_files.elem
local function render(elem)
  print('Rendering '..elem.path)
  local from_lines = {}  --- @type string[]
  local from = elem.from
  if from then
    for line in io.lines(elem.path) do
      from_lines[#from_lines+1] = line
      if line:match(from) then
        break
      end
    end
  end

  local o = assert(io.open(elem.path, 'w'))

  --- @param l string
  local function write(l)
    local l1 = l:gsub('%s+$', '')
    o:write(l1)
    o:write('\n')
  end

  for _, l in ipairs(from_lines) do
    write(l)
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
