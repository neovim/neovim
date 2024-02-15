#!/usr/bin/env -S nvim -l
--- Generates Nvim :help docs from Lua/C docstrings
---
--- The generated :help text for each function is formatted as follows:
--- - Max width of 78 columns (`TEXT_WIDTH`).
--- - Indent with spaces (not tabs).
--- - Indent of 4 columns for body text (`INDENTATION`).
--- - Function signature and helptag (right-aligned) on the same line.
---   - Signature and helptag must have a minimum of 8 spaces between them.
---   - If the signature is too long, it is placed on the line after the helptag.
---     Signature wraps with subsequent lines indented to the open parenthesis.
---   - Subsection bodies are indented an additional 4 spaces.
--- - Body consists of function description, parameters, return description, and
---   C declaration (`INCLUDE_C_DECL`).
--- - Parameters are omitted for the `void` and `Error *` types, or if the
---   parameter is marked as [out].
--- - Each function documentation is separated by a single line.

local luacats_parser = require('scripts.luacats_parser')
local cdoc_parser = require('scripts.cdoc_parser')
local text_utils = require('scripts.text_utils')

local fmt = string.format

local wrap = text_utils.wrap
local md_to_vimdoc = text_utils.md_to_vimdoc

local TEXT_WIDTH = 78
local INDENTATION = 4

--- @class (exact) nvim.gen_vimdoc.Config
---
--- Generated documentation target, e.g. api.txt
--- @field filename string
---
--- @field section_order string[]
---
--- List of files/directories for doxygen to read, relative to `base_dir`.
--- @field files string[]
---
--- @field exclude_types? true
---
--- Section name overrides. Key: filename (e.g., vim.c)
--- @field section_name? table<string,string>
---
--- @field fn_name_pat? string
---
--- @field fn_xform? fun(fun: nvim.luacats.parser.fun)
---
--- For generated section names.
--- @field section_fmt fun(name: string): string
---
--- @field helptag_fmt fun(name: string): string
---
--- Per-function helptag.
--- @field fn_helptag_fmt? fun(fun: nvim.luacats.parser.fun): string
---
--- @field append_only? string[]

local function contains(t, xs)
  return vim.tbl_contains(xs, t)
end

--- @type {level:integer, prerelease:boolean}?
local nvim_api_info_

--- @return {level: integer, prerelease:boolean}
local function nvim_api_info()
  if not nvim_api_info_ then
    --- @type integer?, boolean?
    local level, prerelease
    for l in io.lines('CMakeLists.txt') do
      --- @cast l string
      if level and prerelease then
        break
      end
      local m1 = l:match('^set%(NVIM_API_LEVEL%s+(%d+)%)')
      if m1 then
        level = tonumber(m1) --[[@as integer]]
      end
      local m2 = l:match('^set%(NVIM_API_PRERELEASE%s+(%w+)%)')
      if m2 then
        prerelease = m2 == 'true'
      end
    end
    nvim_api_info_ = { level = level, prerelease = prerelease }
  end

  return nvim_api_info_
end

--- @param fun nvim.luacats.parser.fun
--- @return string
local function fn_helptag_fmt_common(fun)
  local fn_sfx = fun.table and '' or '()'
  if fun.classvar then
    return fmt('*%s:%s%s*', fun.classvar, fun.name, fn_sfx)
  end
  if fun.module then
    return fmt('*%s.%s%s*', fun.module, fun.name, fn_sfx)
  end
  return fmt('*%s%s*', fun.name, fn_sfx)
end

--- @type table<string,nvim.gen_vimdoc.Config>
local config = {
  api = {
    filename = 'api.txt',
    section_order = {
      'vim.c',
      'vimscript.c',
      'command.c',
      'options.c',
      'buffer.c',
      'extmark.c',
      'window.c',
      'win_config.c',
      'tabpage.c',
      'autocmd.c',
      'ui.c',
    },
    exclude_types = true,
    fn_name_pat = 'nvim_.*',
    files = { 'src/nvim/api' },
    section_name = {
      ['vim.c'] = 'Global',
    },
    section_fmt = function(name)
      return name .. ' Functions'
    end,
    helptag_fmt = function(name)
      return fmt('*api-%s*', name:lower())
    end,
  },
  lua = {
    filename = 'lua.txt',
    section_order = {
      'highlight.lua',
      'diff.lua',
      'mpack.lua',
      'json.lua',
      'base64.lua',
      'spell.lua',
      'builtin.lua',
      '_options.lua',
      '_editor.lua',
      '_inspector.lua',
      'shared.lua',
      'loader.lua',
      'uri.lua',
      'ui.lua',
      'filetype.lua',
      'keymap.lua',
      'fs.lua',
      'glob.lua',
      'lpeg.lua',
      're.lua',
      'regex.lua',
      'secure.lua',
      'version.lua',
      'iter.lua',
      'snippet.lua',
      'text.lua',
    },
    files = {
      'runtime/lua/vim/iter.lua',
      'runtime/lua/vim/_editor.lua',
      'runtime/lua/vim/_options.lua',
      'runtime/lua/vim/shared.lua',
      'runtime/lua/vim/loader.lua',
      'runtime/lua/vim/uri.lua',
      'runtime/lua/vim/ui.lua',
      'runtime/lua/vim/filetype.lua',
      'runtime/lua/vim/keymap.lua',
      'runtime/lua/vim/fs.lua',
      'runtime/lua/vim/highlight.lua',
      'runtime/lua/vim/secure.lua',
      'runtime/lua/vim/version.lua',
      'runtime/lua/vim/_inspector.lua',
      'runtime/lua/vim/snippet.lua',
      'runtime/lua/vim/text.lua',
      'runtime/lua/vim/glob.lua',
      'runtime/lua/vim/_meta/builtin.lua',
      'runtime/lua/vim/_meta/diff.lua',
      'runtime/lua/vim/_meta/mpack.lua',
      'runtime/lua/vim/_meta/json.lua',
      'runtime/lua/vim/_meta/base64.lua',
      'runtime/lua/vim/_meta/regex.lua',
      'runtime/lua/vim/_meta/lpeg.lua',
      'runtime/lua/vim/_meta/re.lua',
      'runtime/lua/vim/_meta/spell.lua',
    },
    fn_xform = function(fun)
      if contains(fun.module, { 'vim.uri', 'vim.shared', 'vim._editor' }) then
        fun.module = 'vim'
      end

      if fun.module == 'vim' and contains(fun.name, { 'cmd', 'inspect' }) then
        fun.table = nil
      end

      if fun.classvar or vim.startswith(fun.name, 'vim.') or fun.module == 'vim.iter' then
        return
      end

      fun.name = fmt('%s.%s', fun.module, fun.name)
    end,
    section_name = {
      ['_inspector.lua'] = 'inspector',
    },
    section_fmt = function(name)
      name = name:lower()
      if name == '_editor' then
        return 'Lua module: vim'
      elseif name == '_options' then
        return 'LUA-VIMSCRIPT BRIDGE'
      elseif name == 'builtin' then
        return 'VIM'
      end
      if
        contains(name, {
          'highlight',
          'mpack',
          'json',
          'base64',
          'diff',
          'spell',
          'regex',
          'lpeg',
          're',
        })
      then
        return 'VIM.' .. name:upper()
      end
      return 'Lua module: vim.' .. name
    end,
    helptag_fmt = function(name)
      if name == '_editor' then
        return '*lua-vim*'
      elseif name == '_options' then
        return '*lua-vimscript*'
      end
      return '*vim.' .. name:lower() .. '*'
    end,
    fn_helptag_fmt = function(fun)
      local name = fun.name

      if vim.startswith(name, 'vim.') then
        local fn_sfx = fun.table and '' or '()'
        return fmt('*%s%s*', name, fn_sfx)
      elseif fun.classvar == 'Option' then
        return fmt('*vim.opt:%s()*', name)
      end

      return fn_helptag_fmt_common(fun)
    end,
    append_only = {
      'shared.lua',
    },
  },
  lsp = {
    filename = 'lsp.txt',
    section_order = {
      'lsp.lua',
      'buf.lua',
      'diagnostic.lua',
      'codelens.lua',
      'inlay_hint.lua',
      'tagfunc.lua',
      'semantic_tokens.lua',
      'handlers.lua',
      'util.lua',
      'log.lua',
      'rpc.lua',
      'protocol.lua',
    },
    files = {
      'runtime/lua/vim/lsp',
      'runtime/lua/vim/lsp.lua',
    },
    fn_xform = function(fun)
      fun.name = fun.name:gsub('result%.', '')
    end,
    section_fmt = function(name)
      if name:lower() == 'lsp' then
        return 'Lua module: vim.lsp'
      end
      return 'Lua module: vim.lsp.' .. name:lower()
    end,
    helptag_fmt = function(name)
      if name:lower() == 'lsp' then
        return '*lsp-core*'
      end
      return fmt('*lsp-%s*', name:lower())
    end,
  },
  diagnostic = {
    filename = 'diagnostic.txt',
    section_order = {
      'diagnostic.lua',
    },
    files = { 'runtime/lua/vim/diagnostic.lua' },
    section_fmt = function()
      return 'Lua module: vim.diagnostic'
    end,
    helptag_fmt = function()
      return '*diagnostic-api*'
    end,
  },
  treesitter = {
    filename = 'treesitter.txt',
    section_order = {
      'treesitter.lua',
      'language.lua',
      'query.lua',
      'highlighter.lua',
      'languagetree.lua',
      'dev.lua',
    },
    files = {
      'runtime/lua/vim/treesitter.lua',
      'runtime/lua/vim/treesitter/',
    },
    section_fmt = function(name)
      if name:lower() == 'treesitter' then
        return 'Lua module: vim.treesitter'
      end
      return 'Lua module: vim.treesitter.' .. name:lower()
    end,
    helptag_fmt = function(name)
      if name:lower() == 'treesitter' then
        return '*lua-treesitter-core*'
      end
      return '*lua-treesitter-' .. name:lower() .. '*'
    end,
  },
}

--- @param ty string
--- @param generics table<string,string>
--- @return string
local function replace_generics(ty, generics)
  if ty:sub(-2) == '[]' then
    local ty0 = ty:sub(1, -3)
    if generics[ty0] then
      return generics[ty0] .. '[]'
    end
  elseif ty:sub(-1) == '?' then
    local ty0 = ty:sub(1, -2)
    if generics[ty0] then
      return generics[ty0] .. '?'
    end
  end

  return generics[ty] or ty
end

--- @param ty string
--- @param generics? table<string,string>
local function render_type(ty, generics)
  if generics then
    ty = replace_generics(ty, generics)
  end
  ty = ty:gsub('%s*|%s*nil', '?')
  ty = ty:gsub('nil%s*|%s*(.*)', '%1?')
  ty = ty:gsub('%s*|%s*', '|')
  return fmt('(`%s`)', ty)
end

--- @param p nvim.luacats.parser.param|nvim.luacats.parser.field
local function should_render_param(p)
  return not p.access and not contains(p.name, { '_', 'self' })
end

--- @param xs (nvim.luacats.parser.param|nvim.luacats.parser.field)[]
--- @param generics? table<string,string>
--- @param exclude_types? true
local function render_fields_or_params(xs, generics, exclude_types)
  local ret = {} --- @type string[]

  xs = vim.tbl_filter(should_render_param, xs)

  local indent = 0
  for _, p in ipairs(xs) do
    if p.type or p.desc then
      indent = math.max(indent, #p.name + 3)
    end
    if exclude_types then
      p.type = nil
    end
  end

  for _, p in ipairs(xs) do
    local nm, ty = p.name, p.type
    local desc = p.desc
    local pnm = fmt('      • %-' .. indent .. 's', '{' .. nm .. '}')
    if ty then
      local pty = render_type(ty, generics)
      if desc then
        desc = fmt('%s %s', pty, desc)
        table.insert(ret, pnm)
        table.insert(ret, md_to_vimdoc(desc, 1, 9 + indent, TEXT_WIDTH, true))
      else
        table.insert(ret, fmt('%s %s\n', pnm, pty))
      end
    else
      if desc then
        table.insert(ret, pnm)
        table.insert(ret, md_to_vimdoc(desc, 1, 9 + indent, TEXT_WIDTH, true))
      end
    end
  end

  return table.concat(ret)
end

-- --- @param class lua2vimdoc.class
-- local function render_class(class)
--   writeln(fmt('*%s*', class.name))
--   writeln()
--   if #class.fields > 0 then
--     writeln('    Fields: ~')
--     render_fields_or_params(class.fields)
--   end
--   writeln()
-- end

-- --- @param cls table<string,lua2vimdoc.class>
-- local function render_classes(cls)
--   --- @diagnostic disable-next-line:no-unknown
--   for _, class in vim.spairs(cls) do
--     render_class(class)
--   end
-- end

--- @param fun nvim.luacats.parser.fun
--- @param cfg nvim.gen_vimdoc.Config
local function render_fun_header(fun, cfg)
  local ret = {} --- @type string[]

  local args = {} --- @type string[]
  for _, p in ipairs(fun.params or {}) do
    if p.name ~= 'self' then
      args[#args + 1] = fmt('{%s}', p.name:gsub('%?$', ''))
    end
  end

  local nm = fun.name
  if fun.classvar then
    nm = fmt('%s:%s', fun.classvar, nm)
  end

  local proto = fun.table and nm or nm .. '(' .. table.concat(args, ', ') .. ')'

  if not cfg.fn_helptag_fmt then
    cfg.fn_helptag_fmt = fn_helptag_fmt_common
  end

  local tag = cfg.fn_helptag_fmt(fun)

  if #proto + #tag > TEXT_WIDTH - 8 then
    table.insert(ret, fmt('%78s\n', tag))
    local name, pargs = proto:match('([^(]+%()(.*)')
    table.insert(ret, name)
    table.insert(ret, wrap(pargs, 0, #name, TEXT_WIDTH))
  else
    local pad = TEXT_WIDTH - #proto - #tag
    table.insert(ret, proto .. string.rep(' ', pad) .. tag)
  end

  return table.concat(ret)
end

--- @param returns nvim.luacats.parser.return[]
--- @param generics? table<string,string>
--- @param exclude_types boolean
local function render_returns(returns, generics, exclude_types)
  local ret = {} --- @type string[]

  returns = vim.deepcopy(returns)
  if exclude_types then
    for _, r in ipairs(returns) do
      r.type = nil
    end
  end

  if #returns > 1 then
    table.insert(ret, '    Return (multiple): ~\n')
  elseif #returns == 1 and next(returns[1]) then
    table.insert(ret, '    Return: ~\n')
  end

  for _, p in ipairs(returns) do
    local rnm, ty, desc = p.name, p.type, p.desc
    local blk = ''
    if ty then
      blk = render_type(ty, generics)
    end
    if rnm then
      blk = blk .. ' ' .. rnm
    end
    if desc then
      blk = blk .. ' ' .. desc
    end
    table.insert(ret, md_to_vimdoc(blk, 8, 8, TEXT_WIDTH, true))
  end

  return table.concat(ret)
end

--- @param fun nvim.luacats.parser.fun
--- @param cfg nvim.gen_vimdoc.Config
local function render_fun(fun, cfg)
  if fun.access or fun.deprecated or fun.nodoc then
    return
  end

  if cfg.fn_name_pat and not fun.name:match(cfg.fn_name_pat) then
    return
  end

  if vim.startswith(fun.name, '_') or fun.name:find('[:.]_') then
    return
  end

  local ret = {} --- @type string[]

  table.insert(ret, render_fun_header(fun, cfg))
  table.insert(ret, '\n')

  if fun.desc then
    table.insert(ret, md_to_vimdoc(fun.desc, INDENTATION, INDENTATION, TEXT_WIDTH))
  end

  if fun.since then
    local since = tonumber(fun.since)
    local info = nvim_api_info()
    if since and (since > info.level or since == info.level and info.prerelease) then
      fun.notes = fun.notes or {}
      table.insert(fun.notes, { desc = 'This API is pre-release (unstable).' })
    end
  end

  if fun.notes then
    table.insert(ret, '\n    Note: ~\n')
    for _, p in ipairs(fun.notes) do
      table.insert(ret, '      • ' .. md_to_vimdoc(p.desc, 0, 8, TEXT_WIDTH, true))
    end
  end

  if fun.attrs then
    table.insert(ret, '\n    Attributes: ~\n')
    for _, attr in ipairs(fun.attrs) do
      local attr_str = ({
        textlock = 'not allowed when |textlock| is active or in the |cmdwin|',
        textlock_allow_cmdwin = 'not allowed when |textlock| is active',
        fast = '|api-fast|',
        remote_only = '|RPC| only',
        lua_only = 'Lua |vim.api| only',
      })[attr] or attr
      table.insert(ret, fmt('        %s\n', attr_str))
    end
  end

  if fun.params and #fun.params > 0 then
    local param_txt = render_fields_or_params(fun.params, fun.generics, cfg.exclude_types)
    if not param_txt:match('^%s*$') then
      table.insert(ret, '\n    Parameters: ~\n')
      ret[#ret + 1] = param_txt
    end
  end

  if fun.returns then
    local txt = render_returns(fun.returns, fun.generics, cfg.exclude_types)
    if not txt:match('^%s*$') then
      table.insert(ret, '\n')
      ret[#ret + 1] = txt
    end
  end

  if fun.see then
    table.insert(ret, '\n    See also: ~\n')
    for _, p in ipairs(fun.see) do
      table.insert(ret, '      • ' .. md_to_vimdoc(p.desc, 0, 8, TEXT_WIDTH, true))
    end
  end

  table.insert(ret, '\n')
  return table.concat(ret)
end

--- @param funs nvim.luacats.parser.fun[]
--- @param cfg nvim.gen_vimdoc.Config
local function render_funs(funs, cfg)
  local ret = {} --- @type string[]

  for _, f in ipairs(funs) do
    if cfg.fn_xform then
      cfg.fn_xform(f)
    end
    ret[#ret + 1] = render_fun(f, cfg)
  end

  -- Sort via prototype
  table.sort(ret, function(a, b)
    local a1 = ('\n' .. a):match('\n[a-zA-Z_][^\n]+\n')
    local b1 = ('\n' .. b):match('\n[a-zA-Z_][^\n]+\n')
    return a1:lower() < b1:lower()
  end)

  return table.concat(ret)
end

--- @return string
local function get_script_path()
  local str = debug.getinfo(2, 'S').source:sub(2)
  return str:match('(.*[/\\])') or './'
end

local script_path = get_script_path()
local base_dir = vim.fs.dirname(assert(vim.fs.dirname(script_path)))

local function delete_lines_below(doc_file, tokenstr)
  local lines = {} --- @type string[]
  local found = false
  for line in io.lines(doc_file) do
    if line:find(vim.pesc(tokenstr)) then
      found = true
      break
    end
    lines[#lines + 1] = line
  end
  if not found then
    error(fmt('not found: %s in %s', tokenstr, doc_file))
  end
  lines[#lines] = nil
  local fp = assert(io.open(doc_file, 'w'))
  fp:write(table.concat(lines, '\n'))
  fp:write('\n')
  fp:close()
end

--- @param x string
local function mktitle(x)
  if x == 'ui' then
    return 'UI'
  end
  return x:sub(1, 1):upper() .. x:sub(2)
end

--- @class nvim.gen_vimdoc.Section
--- @field name string
--- @field title string
--- @field help_tag string
--- @field funs_txt string
--- @field doc? string[]

--- @param filename string
--- @param cfg nvim.gen_vimdoc.Config
--- @param section_docs table<string,nvim.gen_vimdoc.Section>
--- @param funs_txt string
--- @return nvim.gen_vimdoc.Section?
local function make_section(filename, cfg, section_docs, funs_txt)
  -- filename: e.g., 'autocmd.c'
  -- name: e.g. 'autocmd'
  local name = filename:match('(.*)%.[a-z]+')

  -- Formatted (this is what's going to be written in the vimdoc)
  -- e.g., "Autocmd Functions"
  local sectname = cfg.section_name and cfg.section_name[filename] or mktitle(name)

  -- section tag: e.g., "*api-autocmd*"
  local help_tag = cfg.helptag_fmt(sectname)

  if funs_txt == '' and #section_docs == 0 then
    return
  end

  return {
    name = sectname,
    title = cfg.section_fmt(sectname),
    help_tag = help_tag,
    funs_txt = funs_txt,
    doc = section_docs,
  }
end

--- @param section nvim.gen_vimdoc.Section
--- @param add_header? boolean
local function render_section(section, add_header)
  local doc = {} --- @type string[]

  if add_header ~= false then
    vim.list_extend(doc, {
      string.rep('=', TEXT_WIDTH),
      '\n',
      section.title,
      fmt('%' .. (TEXT_WIDTH - section.title:len()) .. 's', section.help_tag),
    })
  end

  if section.doc and #section.doc > 0 then
    table.insert(doc, '\n\n')
    vim.list_extend(doc, section.doc)
  end

  if section.funs_txt then
    table.insert(doc, '\n\n')
    table.insert(doc, section.funs_txt)
  end

  return table.concat(doc)
end

local parsers = {
  lua = luacats_parser.parse,
  c = cdoc_parser.parse,
  h = cdoc_parser.parse,
}

--- @param files string[]
local function expand_files(files)
  for k, f in pairs(files) do
    if vim.fn.isdirectory(f) == 1 then
      table.remove(files, k)
      for path, ty in vim.fs.dir(f) do
        if ty == 'file' then
          table.insert(files, vim.fs.joinpath(f, path))
        end
      end
    end
  end
end

--- @param cfg nvim.gen_vimdoc.Config
local function gen_target(cfg)
  local sections = {} --- @type table<string,nvim.gen_vimdoc.Section>

  expand_files(cfg.files)

  for _, f in pairs(cfg.files) do
    local ext = assert(f:match('%.([^.]+)$')) --[[@as 'h'|'c'|'lua']]
    local parser = assert(parsers[ext])
    local _, funs, briefs = parser(f)
    local briefs_txt = {} --- @type string[]
    for _, b in ipairs(briefs) do
      briefs_txt[#briefs_txt + 1] = md_to_vimdoc(b, 0, 0, TEXT_WIDTH)
    end
    local funs_txt = render_funs(funs, cfg)
    -- FIXME: Using f_base will confuse `_meta/protocol.lua` with `protocol.lua`
    local f_base = assert(vim.fs.basename(f))
    sections[f_base] = make_section(f_base, cfg, briefs_txt, funs_txt)
  end

  local first_section_tag = sections[cfg.section_order[1]].help_tag
  local docs = {} --- @type string[]
  for _, f in ipairs(cfg.section_order) do
    local section = sections[f]
    if section then
      local add_sep_and_header = not vim.tbl_contains(cfg.append_only or {}, f)
      table.insert(docs, render_section(section, add_sep_and_header))
    end
  end

  table.insert(
    docs,
    fmt(' vim:tw=78:ts=8:sw=%d:sts=%d:et:ft=help:norl:\n', INDENTATION, INDENTATION)
  )

  local doc_file = vim.fs.joinpath(base_dir, 'runtime', 'doc', cfg.filename)

  if vim.uv.fs_stat(doc_file) then
    delete_lines_below(doc_file, first_section_tag)
  end

  local fp = assert(io.open(doc_file, 'a'))
  fp:write(table.concat(docs, '\n'))
  fp:close()
end

local function run()
  for _, cfg in pairs(config) do
    gen_target(cfg)
  end
end

run()
