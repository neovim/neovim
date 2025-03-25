local vars = require 'elisp.vars'
local specpdl = require 'elisp.specpdl'
local lisp = require 'elisp.lisp'
local print_ = require 'elisp.print'
local signal = require 'elisp.signal'
local bytecode = require 'elisp.bytecode'
local M = {}

local inspect = function(x)
  local printcharfun = print_.make_printcharfun()
  print_.print_obj(x, true, printcharfun)
  return printcharfun.out()
end

---@type vim.elisp.F
local F = {}
F.Xprint = { '!print', 1, 1, 0, [[internal function]] }
function F.Xprint.f(x)
  if type(lisp.xtype(x)) == 'table' then
    for k, v in ipairs(x) do
      print(k .. ' : ' .. inspect(v))
    end
  elseif #x == 0 then
    print('(!print): empty table')
  else
    print(inspect(x))
  end
  return vars.Qt
end
F.Xbacktrace = { '!backtrace', 0, 0, 0, [[internal function]] }
function F.Xbacktrace.f()
  print 'Backtrace:'
  for entry in specpdl.riter() do
    if entry.type == specpdl.type.backtrace then
      local str_args = {}
      for _, arg in ipairs(entry.args) do
        if not pcall(function()
          table.insert(str_args, inspect(arg))
        end) then
          table.insert(str_args, '...')
        end
      end
      ---@cast entry vim.elisp.specpdl.backtrace_entry
      print('  (' .. inspect(entry.func) .. ' ' .. table.concat(str_args, ' ') .. ')')
    end
  end
  return vars.Qt
end
F.Xerror = { '!error', 0, 1, 0, [[internal function]] }
function F.Xerror.f(x)
  error(inspect(x))
  return vars.Qt
end
F.Xlua_exec = { '!lua-exec', 1, -2, 0, [[internal function]] }
function F.Xlua_exec.fa(args)
  local x = args[1]
  lisp.check_string(x)
  local s = lisp.sdata(x)
  loadstring(s)(unpack(args, 2))
  return vars.Qnil
end
F.Xbyte_code = { '!byte-code', 4, 4, 0, [[internal function]] }
function F.Xbyte_code.f(lua_str, bytestr, vector, maxdepth)
  if not (lisp.stringp(bytestr) and lisp.vectorp(vector) and lisp.fixnatp(maxdepth)) then
    signal.error('Invalid byte-code')
  end
  if lisp.string_multibyte(bytestr) then
    bytestr = vars.F.string_as_unibyte(bytestr)
  end
  local fun = vars.F.make_byte_code({ vars.Qnil, bytestr, vector, maxdepth })
  bytecode._cache[fun] = require 'elisp.comp-lisp-to-lua'._str_to_fun(lisp.sdata(lua_str))
  return bytecode.exec_byte_code(fun, 0, {})
end

function M.init_syms()
  vars.defsubr(F, 'Xprint')
  vars.defsubr(F, 'Xbacktrace')
  vars.defsubr(F, 'Xerror')
  vars.defsubr(F, 'Xlua_exec')
  vars.defsubr(F, 'Xbyte_code')

  vars.defsym('QXbyte_code', '!byte-code')
end
return M
