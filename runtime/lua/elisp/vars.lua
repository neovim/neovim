--- Lua-ls doesn't handle vararg typing well
---@alias vim.elisp.F_fun_normal
---| fun():vim.elisp.obj
---| fun(a:vim.elisp.obj):vim.elisp.obj
---| fun(a:vim.elisp.obj,b:vim.elisp.obj):vim.elisp.obj
---| fun(a:vim.elisp.obj,b:vim.elisp.obj,c:vim.elisp.obj):vim.elisp.obj
---| fun(a:vim.elisp.obj,b:vim.elisp.obj,c:vim.elisp.obj,d:vim.elisp.obj):vim.elisp.obj
---| fun(a:vim.elisp.obj,b:vim.elisp.obj,c:vim.elisp.obj,d:vim.elisp.obj,e:vim.elisp.obj):vim.elisp.obj
---| fun(a:vim.elisp.obj,b:vim.elisp.obj,c:vim.elisp.obj,d:vim.elisp.obj,e:vim.elisp.obj,f:vim.elisp.obj):vim.elisp.obj
---| fun(a:vim.elisp.obj,b:vim.elisp.obj,c:vim.elisp.obj,d:vim.elisp.obj,e:vim.elisp.obj,f:vim.elisp.obj,g:vim.elisp.obj):vim.elisp.obj
---@alias vim.elisp.F_fun_args
---| fun(args:vim.elisp.obj[]):vim.elisp.obj
---@alias vim.elisp.F_fun vim.elisp.F_fun_normal|vim.elisp.F_fun_args

---@class vim.elisp.F.entry
---@field [1] string name
---@field [2] number minargs
---@field [3] number maxargs
---@field [4] string|0|nil intspec
---@field [5] string docs
---@field f vim.elisp.F_fun_normal?
---@field fa vim.elisp.F_fun_args?
---@alias vim.elisp.F table<string,vim.elisp.F.entry>

---@class vim.elisp.vars
---@field F table<string,vim.elisp.F_fun>
---@field V table<string,vim.elisp.obj>
---@field modifier_symbols (0|vim.elisp.obj)[]
---@field lisp_eval_depth number
---@field charset_ascii number
---@field charset_iso_8859_1 number
---@field charset_unicode number
---@field charset_emacs number
---@field charset_eight_bit number
---@field charset_table vim.elisp.charset[]
---@field iso_charset_table number[][][]
---@field emacs_mule_charset number[]
---@field emacs_mule_bytes number[]
---@field charset_ordered_list_tick number
---@field charset_jisx0201_roman number
---@field charset_jisx0208_1978 number
---@field charset_jisx0208 number
---@field charset_ksc5601 number
---@field safe_terminal_coding vim.elisp.coding_system
---@field charset_unibyte number
---@field [string] vim.elisp.obj
local vars = {}

local Qsymbols = {}
local Qsymbols_later = {}
if not _G.vim_elisp_debug then
  Qsymbols_later = vars
  Qsymbols = vars
end
---@param name string
---@param symname string
function vars.defsym(name, symname)
  assert(name:sub(1, 1) == 'Q', 'DEV: Internal symbol must start with Q')
  assert(
    not Qsymbols_later[name] and not Qsymbols[name],
    'DEV: Internal symbol already defined: ' .. name
  )
  local lread = require 'elisp.lread'
  local lisp = require 'elisp.lisp'
  local sym
  local found = lread.lookup(vars.initial_obarray, symname)
  if type(found) == 'number' then
    sym = lisp.make_empty_ptr(lisp.type.symbol)
    if symname == 'nil' then
      Qsymbols[name] = sym
    else
      Qsymbols_later[name] = sym
    end
    lread.define_symbol(sym, symname)
  else
    Qsymbols_later[name] = found
  end
end
if _G.vim_elisp_debug then
  function vars.commit_qsymbols()
    Qsymbols = setmetatable(Qsymbols_later, { __index = Qsymbols })
    Qsymbols_later = {}
  end
else
  vars.commit_qsymbols = function() end
end

---@type table<string,vim.elisp.obj>
local Vsymbols = {}
---@param name string?
---@param symname string?
---@param doc string?
---@return vim.elisp.obj
function vars.defvar_lisp(name, symname, doc)
  if name then
    assert(not name:match('%-'), 'DEV: Internal variable names must not contain -')
    assert(name:sub(1, 1) ~= 'V', 'DEV: Internal variable names must not start with V')
    assert(not Vsymbols[name], 'DEV: Internal variable already defined: ' .. name)
  end
  assert(
    not symname or not symname:match('_'),
    'DEV: Internal variable symbol names must should probably not contain _'
  )
  local lread = require 'elisp.lread'
  local lisp = require 'elisp.lisp'
  local sym
  if symname then
    local found = lread.lookup(vars.initial_obarray, symname)
    if type(found) == 'number' then
      sym = lisp.make_empty_ptr(lisp.type.symbol)
      lread.define_symbol(sym, symname)
    else
      sym = found
    end
  else
    assert(name, 'DEV: Internal variable must have a name or a symbol name')
    sym = lisp.make_empty_ptr(lisp.type.symbol)
    local alloc = require 'elisp.alloc'
    alloc.init_symbol(sym, alloc.make_pure_c_string(name))
  end
  if name then
    Vsymbols[name] = sym
  end
  if doc then
    if _G.vim_elisp_later then
      error('TODO')
    end
  end
  return sym
end
---@param doc string?
---@param name string
---@param symname string
function vars.defvar_bool(name, symname, doc)
  vars.defvar_lisp(name, symname, doc)
  local alloc = require 'elisp.alloc'
  local lisp = require 'elisp.lisp'
  lisp.set_symbol_val(
    vars.Qbyte_boolean_vars --[[@as vim.elisp._symbol]],
    alloc.cons(Vsymbols[name], lisp.symbol_val(vars.Qbyte_boolean_vars --[[@as vim.elisp._symbol]]))
  )
end
---@param doc string
---@param name string?
---@param symname string
---@param get vim.elisp.forward.getfn
---@param set vim.elisp.forward.setfn
---@param inbuffer boolean?
vars.defvar_forward = function(name, symname, doc, get, set, inbuffer)
  local sym = vars.defvar_lisp(name, symname, doc)
  local p = sym --[[@as vim.elisp._symbol]]
  local lisp = require 'elisp.lisp'
  p.redirect = lisp.symbol_redirect.forwarded
  p.value = { get, set, isbuffer = inbuffer } --[[@as vim.elisp.forward]]
end
vars.V = setmetatable({}, {
  __index = function(_, k)
    local sym = assert(Vsymbols[k], 'DEV: Not an internal variable: ' .. tostring(k)) --[[@as vim.elisp._symbol]]
    local lisp = require 'elisp.lisp'
    if sym.redirect == lisp.symbol_redirect.plainval then
      return assert(lisp.symbol_val(sym), 'DEV: Internal variable not set: ' .. tostring(k))
    elseif sym.redirect == lisp.symbol_redirect.forwarded then
      return sym.value[1]({})
    elseif sym.redirect == lisp.symbol_redirect.localized then
      local data = require 'elisp.data'
      return data.find_symbol_value(sym)
    else
      error('TODO')
    end
  end,
  __newindex = function(_, k, v)
    assert(type(v) == 'table' and type(v[1]) == 'number')
    local lisp = require 'elisp.lisp'
    local sym = assert(Vsymbols[k], 'DEV: Not an internal variable: ' .. tostring(k)) --[[@as vim.elisp._symbol]]
    if sym.redirect == lisp.symbol_redirect.plainval then
      lisp.set_symbol_val(sym, v)
    elseif sym.redirect == lisp.symbol_redirect.forwarded then
      return sym.value[2](v, {})
    else
      error('TODO')
    end
  end,
})

vars.F = {}
---@param map vim.elisp.F
---@param name string
function vars.defsubr(map, name)
  assert(not vars.F[name], 'DEV: internal function already defined: ' .. name)
  local d = assert(map[name])
  assert(type(d[1]) == 'string')
  assert(type(d[2]) == 'number')
  assert(type(d[3]) == 'number')
  assert(type(d[4]) == 'string' or d[4] == 0 or d[4] == nil)
  assert(type(d[5]) == 'string')
  local f
  if d[3] == -2 then
    assert(type(d.fa) == 'function', d[1])
    f = assert(d.fa)
  else
    assert(type(d.f) == 'function')
    f = assert(d.f)
  end
  vars.F[name] = f
  local symname = d[1]
  if d[3] >= 0 and d[3] <= 8 then
    assert(debug.getinfo(f, 'u').nparams == d[3])
  else
    assert(debug.getinfo(f, 'u').nparams == 1)
  end
  local lread = require 'elisp.lread'
  local sym = lread.intern_c_string(symname)
  local lisp = require 'elisp.lisp'
  local subr = lisp.make_vectorlike_ptr({
    fn = f,
    minargs = d[2],
    maxargs = d[3],
    symbol_name = symname,
    intspec = d[4] ~= 0 and d[4] --[[@as string]]
      or nil,
    docs = d[5],
  } --[[@as vim.elisp._subr]], lisp.pvec.subr)
  lisp.set_symbol_function(sym, subr)
end

if not _G.vim_elisp_debug then
  return vars
end
return setmetatable(vars, {
  __index = function(_, k)
    if Qsymbols[k] then
      return Qsymbols[k]
    end
    error('DEV: try to index out of bounds: ' .. tostring(k))
  end,
})
