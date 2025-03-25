local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'

---@class vim.elisp.specpdl.index: number

---@class vim.elisp.specpdl.entry
---@field type vim.elisp.specpdl.type

---@class vim.elisp.specpdl.backtrace_entry: vim.elisp.specpdl.entry
---@field type vim.elisp.specpdl.type.backtrace
---@field debug_on_exit boolean
---@field func vim.elisp.obj
---@field args vim.elisp.obj[]
---@field nargs number|'UNEVALLED'

---@class vim.elisp.specpdl.let_entry: vim.elisp.specpdl.entry
---@field type vim.elisp.specpdl.type.let
---@field symbol vim.elisp.obj
---@field old_value vim.elisp.obj?

---@class vim.elisp.specpdl.let_local_entry: vim.elisp.specpdl.let_entry
---@field type vim.elisp.specpdl.type.let_local
---@field where vim.elisp.obj

---@class vim.elisp.specpdl.unwind_entry: vim.elisp.specpdl.entry
---@field type vim.elisp.specpdl.type.unwind
---@field func function
---@field lisp_eval_depth number

---@alias vim.elisp.specpdl.all_entries vim.elisp.specpdl.backtrace_entry|vim.elisp.specpdl.let_entry|vim.elisp.specpdl.unwind_entry

---@type (vim.elisp.specpdl.all_entries)[]
local specpdl = {}

local M = {}

---@enum vim.elisp.specpdl.type
M.type = {
  backtrace = 1,
  unwind = 2,
  let = 100,
  let_local = 101,
}

---@return vim.elisp.specpdl.index
function M.index()
  return #specpdl + 1 --[[@as vim.elisp.specpdl.index]]
end
---@generic T
---@param index vim.elisp.specpdl.index
---@param val T
---@return T
function M.unbind_to(index, val, assert_ignore)
  if not assert_ignore then
    assert(index ~= M.index(), 'DEV: index not changed, unbind_to may be unnecessary')
  end
  while M.index() > index do
    ---@type vim.elisp.specpdl.all_entries
    local entry = table.remove(specpdl)
    if
      entry.type == M.type.let
      and lisp.symbolp(entry.symbol)
      and (entry.symbol --[[@as vim.elisp._symbol]]).redirect == lisp.symbol_redirect.plainval
    then
      if
        (entry.symbol --[[@as vim.elisp._symbol]]).trapped_write
        == lisp.symbol_trapped_write.untrapped
      then
        lisp.set_symbol_val(entry.symbol --[[@as vim.elisp._symbol]], entry.old_value)
      else
        error('TODO')
      end
    elseif
      entry.type == M.type.let_local
      and lisp.symbolp(entry.symbol)
      and (entry.symbol --[[@as vim.elisp._symbol]]).redirect == lisp.symbol_redirect.forwarded
    then
      if
        (entry.symbol --[[@as vim.elisp._symbol]]).trapped_write
        == lisp.symbol_trapped_write.untrapped
      then
        require 'elisp.data'.set_internal(entry.symbol, entry.old_value, vars.Qnil, 'UNBIND')
      else
        error('TODO')
      end
    elseif entry.type == M.type.let or entry.type == M.type.let_local then
      error('TODO')
    elseif entry.type == M.type.backtrace then
    elseif entry.type == M.type.unwind then
      vars.lisp_eval_depth = entry.lisp_eval_depth
      entry.func()
    else
      error('TODO')
    end
  end
  return val
end
---@param func vim.elisp.obj
---@param args vim.elisp.obj[]
---@param nargs number|'UNEVALLED'
function M.record_in_backtrace(func, args, nargs)
  local index = M.index()
  table.insert(specpdl, {
    type = M.type.backtrace --[[@as vim.elisp.specpdl.type.backtrace]],
    debug_on_exit = false,
    func = func,
    args = args,
    nargs = nargs,
  } --[[@as vim.elisp.specpdl.backtrace_entry]])
  return index
end
function M.record_unwind_protect(func)
  table.insert(specpdl, {
    type = M.type.unwind --[[@as vim.elisp.specpdl.type.unwind]],
    func = func,
    lisp_eval_depth = vars.lisp_eval_depth,
  } --[[@as vim.elisp.specpdl.unwind_entry]])
end
---@param index vim.elisp.specpdl.index|vim.elisp.specpdl.backtrace_entry
function M.backtrace_debug_on_exit(index)
  local entry
  if type(index) == 'number' then
    entry = specpdl[index]
  else
    entry = index
  end
  assert(entry.type == M.type.backtrace)
  return entry.debug_on_exit
end
---@param args vim.elisp.obj[]
---@param index vim.elisp.specpdl.index
function M.set_backtrace_args(index, args)
  local entry = specpdl[index]
  assert(entry.type == M.type.backtrace)
  entry.args = args
  entry.nargs = #args
end
---@param sym vim.elisp.obj
---@param val vim.elisp.obj
function M.bind(sym, val)
  lisp.check_symbol(sym)
  local s = sym --[[@as vim.elisp._symbol]]
  if s.redirect == lisp.symbol_redirect.plainval then
    table.insert(specpdl, {
      type = M.type.let --[[@as vim.elisp.specpdl.type.let]],
      symbol = sym,
      old_value = lisp.symbol_val(s),
    } --[[@as vim.elisp.specpdl.let_entry]])
    if s.trapped_write == lisp.symbol_trapped_write.untrapped then
      lisp.set_symbol_val(s, val)
    else
      error('TODO')
    end
  elseif s.redirect == lisp.symbol_redirect.forwarded then
    local data = require 'elisp.data'
    local ovalue = data.find_symbol_value(s)
    table.insert(specpdl, {
      type = M.type.let_local --[[@as vim.elisp.specpdl.type.let_local]],
      symbol = sym,
      old_value = ovalue,
      where = vars.F.current_buffer(),
    })
    data.set_internal(sym, val, vars.Qnil, 'BIND')
  else
    error('TODO')
  end
end
---@param idx number?
---@return fun():vim.elisp.specpdl.all_entries,number
function M.riter(idx)
  return coroutine.wrap(function()
    for i = (idx or #specpdl), 1, -1 do
      coroutine.yield(specpdl[i], i)
    end
  end)
end
---@return vim.elisp.specpdl.backtrace_entry?
---@param idx_ number?
---@return number
function M.backtrace_next(idx_)
  for i, idx in M.riter(idx_) do
    if i.type == M.type.backtrace and idx ~= idx_ then
      return i, --[[@as vim.elisp.specpdl.backtrace_entry]]
        idx
    end
  end
  return nil, 0
end
---@param base vim.elisp.obj
---@return vim.elisp.specpdl.entry?
---@return number
function M.get_backtrace_starting_at(base)
  local pdl, idx = M.backtrace_next()
  if not lisp.nilp(base) then
    base = vars.F.indirect_function(base, vars.Qt)
    while pdl and not lisp.eq(vars.F.indirect_function(pdl.func, vars.Qt), base) do
      pdl, idx = M.backtrace_next(idx)
    end
  end
  return pdl, idx
end
---@return vim.elisp.specpdl.entry?
function M.get_backtrace_frame(nframes, base)
  lisp.check_fixnat(nframes)
  local pdl, idx = M.get_backtrace_starting_at(base)
  for _ = 1, lisp.fixnum(nframes) do
    pdl, idx = M.backtrace_next(idx)
    if not pdl then
      break
    end
  end
  return pdl
end
---@param function_ vim.elisp.obj
---@param pdl vim.elisp.specpdl.backtrace_entry?
---@return vim.elisp.obj
function M.backtrace_frame_apply(function_, pdl)
  if not pdl then
    return vars.Qnil
  end
  local flags = vars.Qnil
  if M.backtrace_debug_on_exit(pdl) then
    error('TODO')
  end
  if pdl.nargs == 'UNEVALLED' then
    return vars.F.funcall({ function_, vars.Qnil, pdl.func, pdl.args[1], flags })
  else
    local tem = vars.F.list(pdl.args)
    return vars.F.funcall({ function_, vars.Qt, pdl.func, tem, flags })
  end
end
return M
