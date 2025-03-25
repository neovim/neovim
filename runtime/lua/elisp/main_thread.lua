local handler = require 'elisp.handler'
local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local print_ = require 'elisp.print'
local M = {}
local function co_init()
  if M.co then
    return
  end
  M.co = coroutine.create(function()
    while true do
      handler.internal_catch_lua(function()
        M.recursive_edit(true)
      end, function(msg)
        M.co = nil
        assert(#handler.handlerlist == 0, 'TODO')
        error(msg, 0)
      end)
    end
  end)
  coroutine.resume(M.co)
end
local function command_loop_1()
  local fn = coroutine.yield()
  while true do
    fn()
    fn = coroutine.yield()
  end
end
local function cmd_error(d, _msg)
  if _G.vim_elisp_later then
    error('TODO')
  end
  local sig = lisp.xcar(d)
  if lisp.eq(sig, vars.Qvoid_function) then
    local cdr = lisp.xcdr(d)
    if lisp.consp(cdr) then
      error('TODO: MAYBE need to implement: ' .. lisp.sdata(lisp.symbol_name(lisp.xcar(cdr))))
    end
  end
  local readcharfun = print_.make_printcharfun()
  print_.print_obj(d, true, readcharfun)
  --error('\n\nError (elisp):\n'..readcharfun.out()..'\n\n'.._msg.backtrace)
  error('\n\nError (elisp):\n' .. readcharfun.out() .. '\n')
end
local function command_loop_2(handlers)
  local val
  while true do
    val = handler.internal_condition_case(command_loop_1, handlers, cmd_error)
    if lisp.nilp(val) then
      break
    end
  end
end
function M.recursive_edit(top_level)
  if top_level then
    if _G.vim_elisp_later then
      error('TODO: call the function in top-level')
    end
    while true do
      handler.internal_catch(vars.Qtop_level, command_loop_2, vars.Qerror)
    end
  end
  local val = handler.internal_catch(vars.Qexit, command_loop_2, vars.Qerror)
  return val
end
---@return boolean,string|nil
function M.call(fn)
  co_init()
  if M.co == coroutine.running() then
    return fn()
  end
  local jit_on
  if _G.vim_elisp_later then
    error('TODO: remove jit.on and jit.off')
  elseif _G.vim_elisp_optimize_jit then
    jit_on = jit.status()
    jit.off() --luajit makes the code slower (why?)
  end
  local noerr, errmsg = coroutine.resume(M.co, fn)
  if _G.vim_elisp_optimize_jit and jit_on then
    jit.on()
  end
  return noerr, errmsg
end
return M
