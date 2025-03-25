local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'
local doprnt = require 'elisp.doprnt'
local alloc = require 'elisp.alloc'

local function vformat_string(fmt, ...)
  return doprnt.doprnt(fmt, { ... }, false)
end
local M = {}
function M.xsignal(error_symbol, ...)
  local data = lisp.list(...)
  vars.F.signal(error_symbol, data)
end
---@param fmt string
---@param ... string|number
function M.error(fmt, ...)
  M.xsignal(vars.Qerror, alloc.make_string(vformat_string(fmt, ...)))
end
function M.wrong_type_argument(predicate, x)
  M.xsignal(vars.Qwrong_type_argument, predicate, x)
end
function M.args_out_of_range(a1, a2, a3)
  if a3 then
    M.xsignal(vars.Qargs_out_of_range, a1, a2, a3)
  else
    M.xsignal(vars.Qargs_out_of_range, a1, a2)
  end
end
function M.signal_error(s, arg)
  if lisp.nilp(vars.F.proper_list_p(arg)) then
    arg = lisp.list(arg)
  end
  lisp.xsignal(vars.Qerror, vars.F.cons(alloc.make_string(s), arg))
end

return M
