local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'
local signal = require 'elisp.signal'
local lread = require 'elisp.lread'
local overflow = require 'elisp.overflow'
local alloc = require 'elisp.alloc'
local chartab = require 'elisp.chartab'
local nvim = require 'elisp.nvim'
local fns = require 'elisp.fns'
local chars = require 'elisp.chars'
local buffer_ = require 'elisp.buffer'

---@class vim.elisp.buffer_local_value
---@field local_if_set boolean?
---@field default_value vim.elisp.obj?

local M = {}
---@param sym vim.elisp.obj
---@param newval vim.elisp.obj?
---@param where vim.elisp.obj
---@param bindflag 'SET'|'BIND'|'UNBIND'|'THREAD_SWITCH'
function M.set_internal(sym, newval, where, bindflag)
  lisp.check_symbol(sym)
  local s = sym --[[@as vim.elisp._symbol]]
  if s.trapped_write == lisp.symbol_trapped_write.nowrite then
    error('TODO')
  elseif s.trapped_write == lisp.symbol_trapped_write.trapped then
    error('TODO')
  end
  if s.redirect == lisp.symbol_redirect.plainval then
    lisp.set_symbol_val(s, newval)
  elseif s.redirect == lisp.symbol_redirect.localized then
    if lisp.nilp(where) then
      where = nvim.buffer_get_current()
    end
    local blv = s.value --[[@as vim.elisp.buffer_local_value]]
    local buffer = where --[[@as vim.elisp._buffer]]
    if nvim.buffer_get_var(buffer, s) or blv.local_if_set then
      nvim.buffer_set_var(buffer, s, newval)
    else
      blv.default_value = newval
    end
  elseif s.redirect == lisp.symbol_redirect.forwarded then
    local fwd = s.value --[[@as vim.elisp.forward]]
    if newval == nil then
      error('TODO')
    end
    if fwd.isbuffer then
      local buf
      if lisp.bufferp(where) then
        buf = where --[[@as vim.elisp._buffer]]
      end
      fwd[2](newval, { buffer = buf })
    else
      fwd[2](newval, {})
    end
  else
    error('TODO')
  end
end
---@return vim.elisp.obj?
function M.find_symbol_value(sym)
  lisp.check_symbol(sym)
  local s = sym --[[@as vim.elisp._symbol]]
  if s.redirect == lisp.symbol_redirect.plainval then
    return lisp.symbol_val(sym)
  elseif s.redirect == lisp.symbol_redirect.forwarded then
    return s.value[1]({})
  elseif s.redirect == lisp.symbol_redirect.localized then
    local var = nvim.buffer_get_var(nvim.buffer_get_current() --[[@as vim.elisp._buffer]], s)
    if var then
      return var
    end
    local blv = s.value --[[@as vim.elisp.buffer_local_value]]
    return blv.default_value
  else
    error('TODO')
  end
end

---@type vim.elisp.F
local F = {}
F.symbol_value = {
  'symbol-value',
  1,
  1,
  0,
  [[Return SYMBOL's value.  Error if that is void.
Note that if `lexical-binding' is in effect, this returns the
global value outside of any lexical scope.]],
}
---@param sym vim.elisp.obj
---@return vim.elisp.obj
function F.symbol_value.f(sym)
  lisp.check_symbol(sym)
  local val = M.find_symbol_value(sym)
  if val then
    return val
  end
  signal.xsignal(vars.Qvoid_variable, sym)
  error('unreachable')
end
---@param sym vim.elisp._symbol
---@return vim.elisp._symbol
local function indirect_variable(sym)
  local hare = sym
  local tortoise = hare
  while hare.redirect == lisp.symbol_redirect.varalias do
    hare = lisp.symbol_alias(hare)
    if hare.redirect ~= lisp.symbol_redirect.varalias then
      break
    end
    hare = lisp.symbol_alias(hare)
    tortoise = lisp.symbol_alias(tortoise)
    if hare == tortoise then
      -- Hmm: sym is a vim.elisp._symbol, but xsignal expects a vim.elisp.obj
      signal.xsignal(vars.Qcyclic_variable_indirection, sym)
    end
  end
  return hare
end
---@return vim.elisp.obj?
local function default_value(sym)
  lisp.check_symbol(sym)
  local s = sym --[[@as vim.elisp._symbol]]
  ::start::
  if s.redirect == lisp.symbol_redirect.plainval then
    return lisp.symbol_val(s)
  elseif s.redirect == lisp.symbol_redirect.localized then
    local blv = lisp.symbol_blv(s)
    return blv.default_value
  elseif s.redirect == lisp.symbol_redirect.varalias then
    s = indirect_variable(s)
    goto start
  else
    error('TODO')
  end
end
F.default_value = {
  'default-value',
  1,
  1,
  0,
  [[Return SYMBOL's default value.
This is the value that is seen in buffers that do not have their own values
for this variable.  The default value is meaningful for variables with
local bindings in certain buffers.]],
}
function F.default_value.f(sym)
  local val = default_value(sym)
  if val then
    return val
  end
  signal.xsignal(vars.Qvoid_variable, sym)
  error('unreachable')
end
F.symbol_function =
  { 'symbol-function', 1, 1, 0, [[Return SYMBOL's function definition, or nil if that is void.]] }
function F.symbol_function.f(sym)
  lisp.check_symbol(sym)
  return (sym --[[@as vim.elisp._symbol]]).fn
end
F.symbol_name = {
  'symbol-name',
  1,
  1,
  0,
  [[Return SYMBOL's name, a string.

Warning: never alter the string returned by `symbol-name'.
Doing that might make Emacs dysfunctional, and might even crash Emacs.]],
}
function F.symbol_name.f(sym)
  lisp.check_symbol(sym)
  return lisp.symbol_name(sym)
end
F.bare_symbol =
  { 'bare-symbol', 1, 1, 0, [[Extract, if need be, the bare symbol from SYM, a symbol.]] }
function F.bare_symbol.f(sym)
  if lisp.symbolp(sym) then
    return sym
  end
  error('TODO')
end
---@param obarray vim.elisp.obj
---@param symbol vim.elisp.obj
local function harmonize_variable_watchers(obarray, symbol)
  local trap = (symbol --[[@as vim.elisp._symbol]]).trapped_write
  lread.map_obarray(obarray, function(alias)
    if not lisp.eq(alias, symbol) and lisp.eq(symbol, vars.F.indirect_variable(alias)) then
      lisp.set_symbol_trapped_write(alias, trap)
    end
  end)
end
F.add_variable_watcher = {
  'add-variable-watcher',
  2,
  2,
  0,
  [[Cause WATCH-FUNCTION to be called when SYMBOL is about to be set.

It will be called with 4 arguments: (SYMBOL NEWVAL OPERATION WHERE).
SYMBOL is the variable being changed.
NEWVAL is the value it will be changed to.  (The variable still has
the old value when WATCH-FUNCTION is called.)
OPERATION is a symbol representing the kind of change, one of: `set',
`let', `unlet', `makunbound', and `defvaralias'.
WHERE is a buffer if the buffer-local value of the variable is being
changed, nil otherwise.

All writes to aliases of SYMBOL will call WATCH-FUNCTION too.]],
}
function F.add_variable_watcher.f(symbol, watch_function)
  symbol = vars.F.indirect_variable(symbol)
  lisp.check_symbol(symbol)
  lisp.set_symbol_trapped_write(symbol, lisp.symbol_trapped_write.trapped)
  harmonize_variable_watchers(vars.V.obarray, symbol)
  local watchers = vars.F.get(symbol, vars.Qwatchers)
  local member = vars.F.member(watch_function, watchers)
  if lisp.nilp(member) then
    vars.F.put(symbol, vars.Qwatchers, vars.F.cons(watch_function, watchers))
  end
  return vars.Qnil
end
F.indirect_variable = {
  'indirect-variable',
  1,
  1,
  0,
  [[Return the variable at the end of OBJECT's variable chain.
If OBJECT is a symbol, follow its variable indirections (if any), and
return the variable at the end of the chain of aliases.  See Info node
`(elisp)Variable Aliases'.

If OBJECT is not a symbol, just return it.  If there is a loop in the
chain of aliases, signal a `cyclic-variable-indirection' error.]],
}
function F.indirect_variable.f(object)
  if lisp.symbolp(object) then
    local sym = indirect_variable(object --[[@as vim.elisp._symbol]])
    return sym --[[@as vim.elisp.obj]]
  end
  return object
end
---@param obj vim.elisp.obj
---@return vim.elisp.obj
function M.indirect_function(obj)
  ---@type vim.elisp.obj
  local hare = obj
  local tortoise = obj
  while true do
    if not lisp.symbolp(hare) or lisp.nilp(hare) then
      break
    end
    hare = (hare --[[@as vim.elisp._symbol]]).fn
    if not lisp.symbolp(hare) or lisp.nilp(hare) then
      break
    end
    hare = (hare --[[@as vim.elisp._symbol]]).fn
    tortoise = (tortoise --[[@as vim.elisp._symbol]]).fn
    if lisp.eq(hare, tortoise) then
      signal.xsignal(vars.Qcyclic_function_indirection, obj)
    end
  end
  return hare
end
F.indirect_function = {
  'indirect-function',
  1,
  2,
  0,
  [[Return the function at the end of OBJECT's function chain.
If OBJECT is not a symbol, just return it.  Otherwise, follow all
function indirections to find the final function binding and return it.
Signal a cyclic-function-indirection error if there is a loop in the
function chain of symbols.]],
}
function F.indirect_function.f(obj, _)
  local result = obj
  if lisp.symbolp(result) and not lisp.nilp(result) then
    result = (result --[[@as vim.elisp._symbol]]).fn
    if lisp.symbolp(result) then
      result = M.indirect_function(result)
    end
  end
  return result
end
F.fmakunbound = {
  'fmakunbound',
  1,
  1,
  0,
  [[Make SYMBOL's function definition be void.
Return SYMBOL.

If a function definition is void, trying to call a function by that
name will cause a `void-function' error.  For more details, see Info
node `(elisp) Function Cells'.

See also `makunbound'.]],
}
function F.fmakunbound.f(sym)
  lisp.check_symbol(sym)
  if lisp.nilp(sym) or lisp.eq(sym, vars.Qt) then
    signal.xsignal(vars.Qsetting_constant, sym)
  end
  lisp.set_symbol_function(sym, vars.Qnil)
  return sym
end
F.aref = {
  'aref',
  2,
  2,
  0,
  [[Return the element of ARRAY at index IDX.
ARRAY may be a vector, a string, a char-table, a bool-vector, a record,
or a byte-code object.  IDX starts at 0.]],
}
function F.aref.f(array, idx)
  lisp.check_fixnum(idx)
  local idxval = lisp.fixnum(idx)
  if lisp.stringp(array) then
    if idxval < 0 or idxval >= lisp.schars(array) then
      signal.args_out_of_range(array, idx)
    elseif not lisp.string_multibyte(array) then
      return lisp.make_fixnum(lisp.sref(array, idxval))
    end
    local idxval_byte = fns.string_char_to_byte(array, idxval)
    local c = chars.stringchar(lisp.sdata(array):sub(idxval_byte + 1))
    return lisp.make_fixnum(c)
  elseif lisp.chartablep(array) then
    lisp.check_chartable(array)
    return chartab.ref(array, idxval)
  else
    local size
    if lisp.vectorp(array) or lisp.compiledp(array) or lisp.recordp(array) then
      size = lisp.asize(array)
    else
      signal.wrong_type_argument(vars.Qarrayp, array)
    end
    if idxval < 0 or idxval >= size then
      signal.args_out_of_range(array, idx)
    end
    return lisp.aref(array, idxval)
  end
end
F.aset = {
  'aset',
  3,
  3,
  0,
  [[Store into the element of ARRAY at index IDX the value NEWELT.
Return NEWELT.  ARRAY may be a vector, a string, a char-table or a
bool-vector.  IDX starts at 0.]],
}
function F.aset.f(array, idx, newval)
  lisp.check_fixnum(idx)
  local idxval = lisp.fixnum(idx)
  if not lisp.recordp(array) then
    lisp.check_array(array, vars.Qarrayp)
  end
  if lisp.chartablep(array) then
    lisp.check_chartable(array)
    chartab.set(array, idxval, newval)
  elseif lisp.vectorp(array) or lisp.recordp(array) then
    if idxval < 0 or idxval >= lisp.asize(array) then
      signal.args_out_of_range(array, idx)
    end
    lisp.aset(array, idxval, newval)
  else
    error('TODO')
  end
  return newval
end
F.set = { 'set', 2, 2, 0, [[Set SYMBOL's value to NEWVAL, and return NEWVAL.]] }
---@param sym vim.elisp.obj
---@param newval vim.elisp.obj
function F.set.f(sym, newval)
  M.set_internal(sym, newval, vars.Qnil, 'SET')
  return newval
end
F.car = {
  'car',
  1,
  1,
  0,
  [[Return the car of LIST.  If LIST is nil, return nil.
Error if LIST is not nil and not a cons cell.  See also `car-safe'.

See Info node `(elisp)Cons Cells' for a discussion of related basic
Lisp concepts such as car, cdr, cons cell and list.]],
}
function F.car.f(list)
  if lisp.consp(list) then
    return lisp.xcar(list)
  elseif lisp.nilp(list) then
    return list
  else
    signal.wrong_type_argument(vars.Qlistp, list)
    error('unreachable')
  end
end
F.car_safe =
  { 'car-safe', 1, 1, 0, [[Return the car of OBJECT if it is a cons cell, or else nil.]] }
function F.car_safe.f(obj)
  return lisp.consp(obj) and lisp.xcar(obj) or vars.Qnil
end
F.setcar = { 'setcar', 2, 2, 0, [[Set the car of CELL to be NEWCAR.  Returns NEWCAR.]] }
function F.setcar.f(cell, newcar)
  lisp.check_cons(cell)
  lisp.xsetcar(cell, newcar)
  return newcar
end
F.cdr = {
  'cdr',
  1,
  1,
  0,
  [[Return the cdr of LIST.  If LIST is nil, return nil.
Error if LIST is not nil and not a cons cell.  See also `cdr-safe'.

See Info node `(elisp)Cons Cells' for a discussion of related basic
Lisp concepts such as cdr, car, cons cell and list.]],
}
function F.cdr.f(list)
  if lisp.consp(list) then
    return lisp.xcdr(list)
  elseif lisp.nilp(list) then
    return list
  else
    signal.wrong_type_argument(vars.Qlistp, list)
    error('unreachable')
  end
end
F.cdr_safe =
  { 'cdr-safe', 1, 1, 0, [[Return the cdr of OBJECT if it is a cons cell, or else nil.]] }
function F.cdr_safe.f(obj)
  return lisp.consp(obj) and lisp.xcdr(obj) or vars.Qnil
end
F.setcdr = { 'setcdr', 2, 2, 0, [[Set the cdr of CELL to be NEWCDR.  Returns NEWCDR.]] }
function F.setcdr.f(cell, newcdr)
  lisp.check_cons(cell)
  lisp.xsetcdr(cell, newcdr)
  return newcdr
end
F.eq = { 'eq', 2, 2, 0, [[Return t if the two args are the same Lisp object.]] }
function F.eq.f(a, b)
  if lisp.eq(a, b) then
    return vars.Qt
  end
  return vars.Qnil
end
F.fset =
  { 'fset', 2, 2, 0, [[Set SYMBOL's function definition to DEFINITION, and return DEFINITION.]] }
function F.fset.f(sym, definition)
  lisp.check_symbol(sym)
  if lisp.nilp(sym) and not lisp.nilp(definition) then
    signal.xsignal(vars.Qsetting_constant, sym)
  end
  lisp.set_symbol_function(sym, definition)
  return definition
end
F.defalias = {
  'defalias',
  2,
  3,
  0,
  [[Set SYMBOL's function definition to DEFINITION.
Associates the function with the current load file, if any.
The optional third argument DOCSTRING specifies the documentation string
for SYMBOL; if it is omitted or nil, SYMBOL uses the documentation string
determined by DEFINITION.

Internally, this normally uses `fset', but if SYMBOL has a
`defalias-fset-function' property, the associated value is used instead.

The return value is undefined.]],
}
function F.defalias.f(sym, definition, docstring)
  lisp.check_symbol(sym)
  if _G.vim_elisp_later then
    error('TODO')
  end
  vars.F.fset(sym, definition)
  if not lisp.nilp(docstring) then
    vars.F.put(sym, vars.Qfunction_documentation, docstring)
  end
  return sym
end
---@param s vim.elisp._symbol
---@param val vim.elisp.obj
---@return vim.elisp.buffer_local_value
local function make_blv(s, val)
  if s.redirect == lisp.symbol_redirect.plainval then
    ---@type vim.elisp.buffer_local_value
    return {
      default_value = val,
    }
  else
    error('TODO')
  end
end
F.make_variable_buffer_local = {
  'make-variable-buffer-local',
  1,
  1,
  'vMake Variable Buffer Local: ',
  [[Make VARIABLE become buffer-local whenever it is set.
At any time, the value for the current buffer is in effect,
unless the variable has never been set in this buffer,
in which case the default value is in effect.
Note that binding the variable with `let', or setting it while
a `let'-style binding made in this buffer is in effect,
does not make the variable buffer-local.  Return VARIABLE.

This globally affects all uses of this variable, so it belongs together with
the variable declaration, rather than with its uses (if you just want to make
a variable local to the current buffer for one particular use, use
`make-local-variable').  Buffer-local bindings are normally cleared
while setting up a new major mode, unless they have a `permanent-local'
property.

The function `default-value' gets the default value and `set-default' sets it.

See also `defvar-local'.]],
}
function F.make_variable_buffer_local.f(var)
  lisp.check_symbol(var)
  local s = var --[[@as vim.elisp._symbol]]
  local val
  ---@type vim.elisp.buffer_local_value
  local blv
  if s.redirect == lisp.symbol_redirect.plainval then
    val = lisp.symbol_val(s) or vars.Qnil
  elseif s.redirect == lisp.symbol_redirect.localized then
    blv = lisp.symbol_blv(s)
  else
    error('TODO')
  end
  if lisp.symbolconstantp(var) then
    signal.xsignal(vars.Qsetting_constant, var)
  end
  if not blv then
    blv = make_blv(s, val)
    s.redirect = lisp.symbol_redirect.localized
    lisp.set_symbol_blv(s, blv)
  end
  blv.local_if_set = true
  return var
end
---@param bindflag 'SET'|'BIND'|'UNBIND'|'THREAD_SWITCH'
function M.set_default_internal(sym, val, bindflag)
  lisp.check_symbol(sym)
  local s = sym --[[@as vim.elisp._symbol]]
  if s.trapped_write == lisp.symbol_trapped_write.nowrite then
    error('TODO')
  elseif s.trapped_write == lisp.symbol_trapped_write.trapped then
    error('TODO')
  end
  if s.redirect == lisp.symbol_redirect.plainval then
    M.set_internal(sym, val, vars.Qnil, bindflag)
  elseif s.redirect == lisp.symbol_redirect.localized then
    local blv = lisp.symbol_blv(s)
    blv.default_value = val
  else
    error('TODO')
  end
end
F.set_default = {
  'set-default',
  2,
  2,
  0,
  [[Set SYMBOL's default value to VALUE.  SYMBOL and VALUE are evaluated.
The default value is seen in buffers that do not have their own values
for this variable.]],
}
F.set_default.f = function(sym, val)
  M.set_default_internal(sym, val, 'SET')
  return val
end
---@param code '+'|'-'|'or'|'/'|'*'|'and'
---@param args (number|vim.elisp.obj)[]
---@return vim.elisp.obj
local function arith_driver(code, args)
  local function call(over, float)
    ---@type number|nil
    local acc = 0
    local is_float = false
    for _, v in ipairs(args) do
      if type(v) ~= 'number' and lisp.floatp(v) then
        is_float = true
        over = float
        break
      end
    end
    for k, v in ipairs(args) do
      if k == 1 then
        if type(v) == 'number' then
          acc = v
        elseif lisp.fixnump(v) then
          acc = lisp.fixnum(v)
        elseif lisp.floatp(v) then
          assert(is_float)
          acc = lisp.xfloat_data(v)
        else
          error('TODO')
        end
      elseif type(v) == 'number' then
        acc = over(acc, v)
      elseif lisp.bignump(v) then
        error('TODO')
      elseif lisp.fixnump(v) then
        acc = over(acc, lisp.fixnum(v))
      elseif lisp.floatp(v) then
        assert(is_float)
        acc = over(acc, lisp.xfloat_data(v))
      else
        error('TODO')
      end
      if acc == nil then
        error('TODO')
      end
    end
    if is_float then
      return alloc.make_float(acc)
    end
    return lisp.make_fixnum(acc)
  end
  if _G.vim_elisp_later then
    error('TODO: args may contain markers')
  end
  if code == '+' then
    return call(overflow.add, function(a, b)
      return a + b
    end)
  elseif code == '-' then
    return call(overflow.sub, function(a, b)
      return a - b
    end)
  elseif code == '*' then
    return call(overflow.mul, function(a, b)
      return a * b
    end)
  elseif code == '/' then
    local fn = function(a, b)
      if b == 0 then
        signal.xsignal(vars.Qarith_error)
      end
      if a == overflow.min and b == -1 then
        return nil
      end
      return a / b
    end
    return call(fn, function(a, b)
      return a / b
    end)
  elseif code == 'or' or code == 'and' then
    if _G.vim_elisp_later then
      error('TODO: bit can only do numbers up to 32 bit, fixnum is 52 bit')
      error('TODO: a number being negative is treated as it having infinite ones at the left side')
    end
    local f = (code == 'and' and bit.band) or (code == 'or' and bit.bor) or error('TODO')
    local acc = (code == 'and' and -1) or (code == 'or' and 0) or error('TODO')
    for _, v in ipairs(args) do
      if type(v) == 'number' then
        acc = f(acc, v)
      elseif lisp.bignump(v) then
        error('TODO')
      elseif lisp.floatp(v) then
        error('TODO')
      elseif lisp.fixnump(v) then
        acc = f(acc, lisp.fixnum(v))
      else
        error('unreachable')
      end
    end
    return lisp.make_fixnum(acc)
  else
    error('TODO')
  end
end
---@param code '='|'<='|'/='
---@return boolean
local function arithcompare(a, b, code)
  if _G.vim_elisp_later then
    error('TODO: args may contain markers')
  end
  local lt, gt, eq
  if lisp.fixnump(a) then
    if lisp.fixnump(b) then
      local i1 = lisp.fixnum(a)
      local i2 = lisp.fixnum(b)
      lt = i1 < i2
      gt = i1 > i2
      eq = i1 == i2
    else
      error('TODO')
    end
  else
    error('TODO')
  end

  if code == '=' then
    return eq
  elseif code == '/=' then
    return not eq
  elseif code == '<=' then
    return lt or eq
  elseif code == '<' then
    return lt
  elseif code == '>=' then
    return gt or eq
  elseif code == '>' then
    return gt
  else
    error('TODO')
  end
end
---@param code '='|'<='
---@param args (number|vim.elisp.obj)[]
local function arithcompare_driver(code, args)
  for i = 1, #args - 1 do
    if not arithcompare(args[i], args[i + 1], code) then
      return vars.Qnil
    end
  end
  return vars.Qt
end
F.add1 = {
  '1+',
  1,
  1,
  0,
  [[Return NUMBER plus one.  NUMBER may be a number or a marker.
Markers are converted to integers.]],
}
function F.add1.f(num)
  num = lisp.check_number_coerce_marker(num)
  if lisp.fixnump(num) then
    return arith_driver('+', { num, 1 })
  else
    error('TODO')
  end
end
F.sub1 = {
  '1-',
  1,
  1,
  0,
  [[Return NUMBER minus one.  NUMBER may be a number or a marker.
Markers are converted to integers.]],
}
function F.sub1.f(num)
  num = lisp.check_number_coerce_marker(num)
  if lisp.fixnump(num) then
    return arith_driver('-', { num, 1 })
  else
    error('TODO')
  end
end
F.quo = {
  '/',
  1,
  -2,
  0,
  [[Divide number by divisors and return the result.
With two or more arguments, return first argument divided by the rest.
With one argument, return 1 divided by the argument.
The arguments must be numbers or markers.
usage: (/ NUMBER &rest DIVISORS)]],
}
function F.quo.fa(args)
  if #args == 1 then
    error('TODO')
  end
  return arith_driver('/', args)
end
F.times = {
  '*',
  0,
  -2,
  0,
  [[Return product of any number of arguments, which are numbers or markers.
usage: (* &rest NUMBERS-OR-MARKERS)]],
}
function F.times.fa(args)
  if #args == 0 then
    return lisp.make_fixnum(1)
  end
  return arith_driver('*', args)
end
F.plus = {
  '+',
  0,
  -2,
  0,
  [[Return sum of any number of arguments, which are numbers or markers.
usage: (+ &rest NUMBERS-OR-MARKERS)]],
}
function F.plus.fa(args)
  if #args == 0 then
    return lisp.make_fixnum(0)
  elseif #args == 1 then
    return args[1]
  end
  return arith_driver('+', args)
end
F.minus = {
  '-',
  0,
  -2,
  0,
  [[Negate number or subtract numbers or markers and return the result.
With one arg, negates it.  With more than one arg,
subtracts all but the first from the first.
usage: (- &optional NUMBER-OR-MARKER &rest MORE-NUMBERS-OR-MARKERS)]],
}
function F.minus.fa(args)
  if #args == 0 then
    return lisp.make_fixnum(0)
  elseif #args == 1 then
    local a = lisp.check_number_coerce_marker(args[1])
    if lisp.fixnump(a) then
      local ret = assert(overflow.sub(0, lisp.fixnum(a)))
      if ret ~= nil then
        return lisp.make_fixnum(ret)
      end
    elseif lisp.floatp(a) then
      error('TODO')
    end
    error('TODO')
  end
  return arith_driver('-', args)
end
F.ash = {
  'ash',
  2,
  2,
  0,
  [[Return integer VALUE with its bits shifted left by COUNT bit positions.
If COUNT is negative, shift VALUE to the right instead.
VALUE and COUNT must be integers.
Mathematically, the return value is VALUE multiplied by 2 to the
power of COUNT, rounded down.  If the result is non-zero, its sign
is the same as that of VALUE.
In terms of bits, when COUNT is positive, the function moves
the bits of VALUE to the left, adding zero bits on the right; when
COUNT is negative, it moves the bits of VALUE to the right,
discarding bits.]],
}
function F.ash.f(value, count)
  lisp.check_integer(value)
  lisp.check_integer(count)
  if not lisp.fixnump(count) then
    error('TODO')
  end
  if lisp.fixnum(count) <= 0 then
    if lisp.fixnum(count) == 0 then
      return value
    end
    error('TODO')
  end
  local res = overflow.mul_2exp(lisp.fixnum(value), lisp.fixnum(count))
  if res == nil then
    error('TODO')
  end
  return lisp.make_fixnum(res)
end
F.lss = {
  '<',
  1,
  -2,
  0,
  [[Return t if each arg (a number or marker), is less than the next arg.
usage: (< NUMBER-OR-MARKER &rest NUMBERS-OR-MARKERS)]],
}
function F.lss.fa(args)
  if #args == 2 and lisp.fixnump(args[1]) and lisp.fixnump(args[2]) then
    return lisp.fixnum(args[1]) < lisp.fixnum(args[2]) and vars.Qt or vars.Qnil
  end
  error('TODO')
end
F.leq = {
  '<=',
  1,
  -2,
  0,
  [[Return t if each arg (a number or marker) is less than or equal to the next.
usage: (<= NUMBER-OR-MARKER &rest NUMBERS-OR-MARKERS)]],
}
function F.leq.fa(args)
  if #args == 2 and lisp.fixnump(args[1]) and lisp.fixnump(args[2]) then
    return lisp.fixnum(args[1]) <= lisp.fixnum(args[2]) and vars.Qt or vars.Qnil
  end
  return arithcompare_driver('<=', args)
end
F.gtr = {
  '>',
  1,
  -2,
  0,
  [[Return t if each arg (a number or marker) is greater than the next arg.
usage: (> NUMBER-OR-MARKER &rest NUMBERS-OR-MARKERS)]],
}
function F.gtr.fa(args)
  if #args == 2 and lisp.fixnump(args[1]) and lisp.fixnump(args[2]) then
    return lisp.fixnum(args[1]) > lisp.fixnum(args[2]) and vars.Qt or vars.Qnil
  end
  error('TODO')
end
F.geq = {
  '>=',
  1,
  -2,
  0,
  [[Return t if each arg (a number or marker) is greater than or equal to the next.
usage: (>= NUMBER-OR-MARKER &rest NUMBERS-OR-MARKERS)]],
}
function F.geq.fa(args)
  if #args == 2 and lisp.fixnump(args[1]) and lisp.fixnump(args[2]) then
    return lisp.fixnum(args[1]) >= lisp.fixnum(args[2]) and vars.Qt or vars.Qnil
  end
  error('TODO')
end
F.logior = {
  'logior',
  0,
  -2,
  0,
  [[Return bitwise-or of all the arguments.
Arguments may be integers, or markers converted to integers.
usage: (logior &rest INTS-OR-MARKERS)]],
}
function F.logior.fa(args)
  if #args == 0 then
    return lisp.make_fixnum(0)
  end
  local a = lisp.check_number_coerce_marker(args[1])
  return #args == 1 and a or arith_driver('or', args)
end
F.logand = {
  'logand',
  0,
  -2,
  0,
  [[Return bitwise-and of all the arguments.
Arguments may be integers, or markers converted to integers.
usage: (logand &rest INTS-OR-MARKERS)]],
}
function F.logand.fa(args)
  if #args == 0 then
    return lisp.make_fixnum(-1)
  end
  local a = lisp.check_number_coerce_marker(args[1])
  return #args == 1 and a or arith_driver('and', args)
end
F.eqlsign = {
  '=',
  1,
  -2,
  0,
  [[Return t if args, all numbers or markers, are equal.
usage: (= NUMBER-OR-MARKER &rest NUMBERS-OR-MARKERS)]],
}
function F.eqlsign.fa(args)
  return arithcompare_driver('=', args)
end
F.neq = {
  '/=',
  2,
  2,
  0,
  [[Return t if first arg is not equal to second arg.  Both must be numbers or markers.]],
}
function F.neq.f(a, b)
  return arithcompare(a, b, '/=') and vars.Qt or vars.Qnil
end
local function minmax_driver(args, comperison)
  local accum = args[1]
  for idx = 2, #args do
    local val = lisp.check_number_coerce_marker(args[idx])
    if arithcompare(val, accum, comperison) then
      accum = val
    elseif lisp.floatp(val) then
      error('TODO')
    end
  end
  return accum
end
F.max = {
  'max',
  1,
  -2,
  0,
  [[Return largest of all the arguments (which must be numbers or markers).
The value is always a number; markers are converted to numbers.
usage: (max NUMBER-OR-MARKER &rest NUMBERS-OR-MARKERS)]],
}
function F.max.fa(args)
  return minmax_driver(args, '>')
end
F.min = {
  'min',
  1,
  -2,
  0,
  [[Return smallest of all the arguments (which must be numbers or markers).
The value is always a number; markers are converted to numbers.
usage: (min NUMBER-OR-MARKER &rest NUMBERS-OR-MARKERS)]],
}
function F.min.fa(args)
  return minmax_driver(args, '<')
end
F.local_variable_if_set_p = {
  'local-variable-if-set-p',
  1,
  2,
  0,
  [[Non-nil if VARIABLE is local in buffer BUFFER when set there.
BUFFER defaults to the current buffer.

More precisely, return non-nil if either VARIABLE already has a local
value in BUFFER, or if VARIABLE is automatically buffer-local (see
`make-variable-buffer-local').]],
}
function F.local_variable_if_set_p.f(variable, buffer)
  lisp.check_symbol(variable)
  local s = variable --[[@as vim.elisp._symbol]]
  if s.redirect == lisp.symbol_redirect.plainval then
    return vars.Qnil
  end
  error('TODO')
end
F.local_variable_p = {
  'local-variable-p',
  1,
  2,
  0,
  [[Non-nil if VARIABLE has a local binding in buffer BUFFER.
BUFFER defaults to the current buffer.

Also see `buffer-local-boundp'.]],
}
function F.local_variable_p.f(variable, buffer)
  local buf = buffer_.decode_buffer(buffer)
  lisp.check_symbol(variable)
  local sym = variable --[[@as vim.elisp._symbol]]
  if sym.redirect == lisp.symbol_redirect.plainval then
    return vars.Qnil
  else
    error('TODO')
  end
end
F.string_to_number = {
  'string-to-number',
  1,
  2,
  0,
  [[Parse STRING as a decimal number and return the number.
Ignore leading spaces and tabs, and all trailing chars.  Return 0 if
STRING cannot be parsed as an integer or floating point number.

If BASE, interpret STRING as a number in that base.  If BASE isn't
present, base 10 is used.  BASE must be between 2 and 16 (inclusive).
If the base used is not 10, STRING is always parsed as an integer.]],
}
function F.string_to_number.f(s, base)
  lisp.check_string(s)
  local b
  if lisp.nilp(base) then
    b = 10
  else
    lisp.check_fixnum(base)
    if not (lisp.fixnum(base) >= 2 and lisp.fixnum(base) <= 16) then
      signal.xsignal(vars.Qargs_out_of_range, base)
    end
    b = lisp.fixnum(base)
  end
  local p = lisp.sdata(s):gsub('^[ \t]+', '')
  local val = lread.string_to_number(p, b)
  return val ~= nil and val or lisp.make_fixnum(0)
end
F.type_of = {
  'type-of',
  1,
  1,
  0,
  [[Return a symbol representing the type of OBJECT.
The symbol returned names the object's basic type;
for example, (type-of 1) returns `integer'.]],
}
function F.type_of.f(object)
  local typ = lisp.xtype(object)
  if typ == lisp.type.int0 then
    return vars.Qinteger
  elseif typ == lisp.type.symbol then
    return vars.Qsymbol
  elseif typ == lisp.type.string then
    return vars.Qstring
  elseif typ == lisp.type.cons then
    return vars.Qcons
  elseif typ == lisp.type.float then
    return vars.Qfloat
  end
  assert(typ == lisp.type.vectorlike)
  local ptyp = lisp.pseudovector_type(object)
  if ptyp == lisp.pvec.normal_vector then
    return vars.Qvector
  elseif ptyp == lisp.pvec.bignum then
    return vars.Qinteger
  elseif ptyp == lisp.pvec.marker then
    return vars.Qmarker
  elseif ptyp == lisp.pvec.symbol_with_pos then
    return vars.Qsymbol_with_pos
  elseif ptyp == lisp.pvec.overlay then
    return vars.Qoverlay
  elseif ptyp == lisp.pvec.finalizer then
    return vars.Qfinalizer
  elseif ptyp == lisp.pvec.user_ptr then
    return vars.Quser_ptr
  elseif ptyp == lisp.pvec.window_configuration then
    return vars.Qwindow_configuration
  elseif ptyp == lisp.pvec.process then
    return vars.Qprocess
  elseif ptyp == lisp.pvec.window then
    return vars.Qwindow
  elseif ptyp == lisp.pvec.subr then
    return vars.Qsubr
  elseif ptyp == lisp.pvec.compiled then
    return vars.Qcompiled_function
  elseif ptyp == lisp.pvec.buffer then
    return vars.Qbuffer
  elseif ptyp == lisp.pvec.char_table then
    return vars.Qchar_table
  elseif ptyp == lisp.pvec.bool_vector then
    return vars.Qbool_vector
  elseif ptyp == lisp.pvec.frame then
    return vars.Qframe
  elseif ptyp == lisp.pvec.hash_table then
    return vars.vars.Qhash_table
  elseif ptyp == lisp.pvec.font then
    error('TODO')
  elseif ptyp == lisp.pvec.thread then
    return vars.Qthread
  elseif ptyp == lisp.pvec.mutex then
    return vars.Qmutex
  elseif ptyp == lisp.pvec.condvar then
    return vars.Qcondition_variable
  elseif ptyp == lisp.pvec.terminal then
    return vars.vars.Qterminal
  elseif ptyp == lisp.pvec.record then
    local t = lisp.aref(object, 0)
    if lisp.recordp(t) and lisp.asize(t) > 1 then
      return lisp.aref(t, 1)
    else
      return t
    end
  elseif ptyp == lisp.pvec.module_function then
    return vars.Qmodule_function
  elseif ptyp == lisp.pvec.native_comp_unit then
    return vars.Qnative_comp_unit
  elseif ptyp == lisp.pvec.xwidget then
    return vars.Qxwidget
  elseif ptyp == lisp.pvec.xwidget_view then
    return vars.Qxwidget_view
  elseif ptyp == lisp.pvec.ts_parser then
    return vars.Qtreesit_parser
  elseif ptyp == lisp.pvec.ts_node then
    return vars.Qtreesit_node
  elseif ptyp == lisp.pvec.ts_compiled_query then
    return vars.Qtreesit_compiled_query
  elseif ptyp == lisp.pvec.sqlite then
    return vars.Qsqlite
  end
  error('unreachable')
end
F.default_boundp = {
  'default-boundp',
  1,
  1,
  0,
  [[Return t if SYMBOL has a non-void default value.
A variable may have a buffer-local value.  This function says whether
the variable has a non-void value outside of the current buffer
context.  Also see `default-value'.]],
}
function F.default_boundp.f(sym)
  local value = default_value(sym)
  return value == nil and vars.Qnil or vars.Qt
end
F.boundp = {
  'boundp',
  1,
  1,
  0,
  [[Return t if SYMBOL's value is not void.
Note that if `lexical-binding' is in effect, this refers to the
global value outside of any lexical scope.]],
}
function F.boundp.f(sym)
  lisp.check_symbol(sym)
  local s = sym --[[@as vim.elisp._symbol]]
  ::start::
  if s.redirect == lisp.symbol_redirect.plainval then
    return lisp.symbol_val(s) == nil and vars.Qnil or vars.Qt
  elseif s.redirect == lisp.symbol_redirect.varalias then
    s = indirect_variable(s)
    goto start
  elseif s.redirect == lisp.symbol_redirect.localized then
    return nvim.buffer_get_var(nvim.buffer_get_current() --[[@as vim.elisp._buffer]], s) == nil
        and vars.Qnil
      or vars.Qt
  else
    error('TODO')
  end
end
F.fboundp = { 'fboundp', 1, 1, 0, [[Return t if SYMBOL's function definition is not void.]] }
function F.fboundp.f(sym)
  lisp.check_symbol(sym)
  return lisp.nilp((sym --[[@as vim.elisp._symbol]]).fn) and vars.Qnil or vars.Qt
end
F.keywordp = {
  'keywordp',
  1,
  1,
  0,
  [[Return t if OBJECT is a keyword.
This means that it is a symbol with a print name beginning with `:'
interned in the initial obarray.]],
}
function F.keywordp.f(a)
  if
    lisp.symbolp(a)
    and lisp.sref(lisp.symbol_name(a), 0) == (require 'elisp.bytes')[':']
    and lisp.symbolinternedininitialobarrayp(a)
  then
    return vars.Qt
  end
  return vars.Qnil
end
F.multibyte_string_p = {
  'multibyte-string-p',
  1,
  1,
  0,
  [[Return t if OBJECT is a multibyte string.
Return nil if OBJECT is either a unibyte string, or not a string.]],
}
function F.multibyte_string_p.f(a)
  if lisp.stringp(a) and lisp.string_multibyte(a) then
    return vars.Qt
  end
  return vars.Qnil
end
F.natnump = { 'natnump', 1, 1, 0, [[Return t if OBJECT is a nonnegative integer.]] }
function F.natnump.f(a)
  if lisp.bignump(a) then
    error('TODO')
  end
  return (lisp.fixnump(a) and lisp.fixnum(a) >= 0) and vars.Qt or vars.Qnil
end
F.stringp = { 'stringp', 1, 1, 0, [[Return t if OBJECT is a string.]] }
function F.stringp.f(a)
  return lisp.stringp(a) and vars.Qt or vars.Qnil
end
F.null = { 'null', 1, 1, 0, [[Return t if OBJECT is nil, and return nil otherwise.]] }
function F.null.f(a)
  return lisp.nilp(a) and vars.Qt or vars.Qnil
end
F.numberp = { 'numberp', 1, 1, 0, [[Return t if OBJECT is a number (floating point or integer).]] }
function F.numberp.f(a)
  return lisp.numberp(a) and vars.Qt or vars.Qnil
end
F.listp = {
  'listp',
  1,
  1,
  0,
  [[Return t if OBJECT is a list, that is, a cons cell or nil.
Otherwise, return nil.]],
}
function F.listp.f(a)
  return (lisp.consp(a) or lisp.nilp(a)) and vars.Qt or vars.Qnil
end
F.symbolp = { 'symbolp', 1, 1, 0, [[Return t if OBJECT is a symbol.]] }
function F.symbolp.f(a)
  return lisp.symbolp(a) and vars.Qt or vars.Qnil
end
F.floatp = { 'floatp', 1, 1, 0, [[Return t if OBJECT is a floating point number.]] }
function F.floatp.f(a)
  return lisp.floatp(a) and vars.Qt or vars.Qnil
end
F.vectorp = { 'vectorp', 1, 1, 0, [[Return t if OBJECT is a vector.]] }
function F.vectorp.f(a)
  return lisp.vectorp(a) and vars.Qt or vars.Qnil
end
F.atom = { 'atom', 1, 1, 0, [[Return t if OBJECT is not a cons cell.  This includes nil.]] }
function F.atom.f(a)
  return lisp.consp(a) and vars.Qnil or vars.Qt
end
F.consp = { 'consp', 1, 1, 0, [[Return t if OBJECT is a cons cell.]] }
function F.consp.f(a)
  return lisp.consp(a) and vars.Qt or vars.Qnil
end
F.integerp = { 'integerp', 1, 1, 0, [[Return t if OBJECT is an integer.]] }
function F.integerp.f(a)
  return lisp.integerp(a) and vars.Qt or vars.Qnil
end
F.functionp = {
  'functionp',
  1,
  1,
  0,
  [[Return t if OBJECT is a function.

An object is a function if it is callable via `funcall'; this includes
symbols with function bindings, but excludes macros and special forms.

Ordinarily return nil if OBJECT is not a function, although t might be
returned in rare cases.]],
}
function F.functionp.f(a)
  return lisp.functionp(a) and vars.Qt or vars.Qnil
end
F.hash_table_p = { 'hash-table-p', 1, 1, 0, [[Return t if OBJ is a Lisp hash table object.]] }
function F.hash_table_p.f(a)
  return lisp.hashtablep(a) and vars.Qt or vars.Qnil
end
F.subrp = { 'subrp', 1, 1, 0, [[Return t if OBJECT is a built-in function.]] }
function F.subrp.f(a)
  return lisp.subrp(a) and vars.Qt or vars.Qnil
end
F.byte_code_function_p =
  { 'byte-code-function-p', 1, 1, 0, [[Return t if OBJECT is a byte-compiled function object.]] }
function F.byte_code_function_p.f(a)
  return lisp.compiledp(a) and vars.Qt or vars.Qnil
end
F.recordp = { 'recordp', 1, 1, 0, [[Return t if OBJECT is a record.]] }
function F.recordp.f(object)
  return lisp.recordp(object) and vars.Qt or vars.Qnil
end
F.char_table_p = { 'char-table-p', 1, 1, 0, [[Return t if OBJECT is a char-table.]] }
function F.char_table_p.f(a)
  return lisp.chartablep(a) and vars.Qt or vars.Qnil
end

function M.init()
  local error_tail = alloc.cons(vars.Qerror, vars.Qnil)
  vars.F.put(vars.Qerror, vars.Qerror_conditions, error_tail)
  vars.F.put(vars.Qerror, vars.Qerror_message, alloc.make_pure_c_string('error'))
  local function put_error(sym, tail, msg)
    vars.F.put(sym, vars.Qerror_conditions, alloc.cons(sym, tail))
    vars.F.put(sym, vars.Qerror_message, alloc.make_pure_c_string(msg))
  end
  put_error(vars.Qquit, vars.Qnil, 'Quit')
  put_error(vars.Qvoid_variable, error_tail, "Symbol's value as variable is void")
  put_error(vars.Qvoid_function, error_tail, "Symbol's function definition is void")
  put_error(vars.Qwrong_type_argument, error_tail, 'Wrong type argument')
  put_error(vars.Qargs_out_of_range, error_tail, 'Args out of range')
end
function M.init_syms()
  ---These are errors and should have corresponding `put_error`
  vars.defsym('Qerror', 'error')
  vars.defsym('Qquit', 'quit')
  vars.defsym('Qvoid_variable', 'void-variable')
  vars.defsym('Qvoid_function', 'void-function')
  vars.defsym('Qwrong_type_argument', 'wrong-type-argument')
  vars.defsym('Qargs_out_of_range', 'args-out-of-range')

  vars.defsubr(F, 'symbol_value')
  vars.defsubr(F, 'default_value')
  vars.defsubr(F, 'symbol_function')
  vars.defsubr(F, 'symbol_name')
  vars.defsubr(F, 'bare_symbol')
  vars.defsubr(F, 'add_variable_watcher')
  vars.defsubr(F, 'indirect_variable')
  vars.defsubr(F, 'indirect_function')
  vars.defsubr(F, 'fmakunbound')
  vars.defsubr(F, 'aref')
  vars.defsubr(F, 'aset')
  vars.defsubr(F, 'car')
  vars.defsubr(F, 'car_safe')
  vars.defsubr(F, 'setcar')
  vars.defsubr(F, 'cdr')
  vars.defsubr(F, 'cdr_safe')
  vars.defsubr(F, 'setcdr')

  vars.defsubr(F, 'fset')
  vars.defsubr(F, 'set')
  vars.defsubr(F, 'set_default')

  vars.defsubr(F, 'eq')
  vars.defsubr(F, 'defalias')
  vars.defsubr(F, 'make_variable_buffer_local')

  vars.defsubr(F, 'add1')
  vars.defsubr(F, 'sub1')
  vars.defsubr(F, 'quo')
  vars.defsubr(F, 'times')
  vars.defsubr(F, 'plus')
  vars.defsubr(F, 'minus')
  vars.defsubr(F, 'logior')
  vars.defsubr(F, 'logand')
  vars.defsubr(F, 'ash')
  vars.defsubr(F, 'lss')
  vars.defsubr(F, 'leq')
  vars.defsubr(F, 'gtr')
  vars.defsubr(F, 'geq')
  vars.defsubr(F, 'eqlsign')
  vars.defsubr(F, 'neq')
  vars.defsubr(F, 'max')
  vars.defsubr(F, 'min')

  vars.defsubr(F, 'string_to_number')
  vars.defsubr(F, 'type_of')

  vars.defsubr(F, 'local_variable_if_set_p')
  vars.defsubr(F, 'local_variable_p')
  vars.defsubr(F, 'default_boundp')
  vars.defsubr(F, 'boundp')
  vars.defsubr(F, 'fboundp')
  vars.defsubr(F, 'keywordp')
  vars.defsubr(F, 'multibyte_string_p')
  vars.defsubr(F, 'natnump')
  vars.defsubr(F, 'stringp')
  vars.defsubr(F, 'null')
  vars.defsubr(F, 'numberp')
  vars.defsubr(F, 'listp')
  vars.defsubr(F, 'symbolp')
  vars.defsubr(F, 'floatp')
  vars.defsubr(F, 'vectorp')
  vars.defsubr(F, 'atom')
  vars.defsubr(F, 'consp')
  vars.defsubr(F, 'integerp')
  vars.defsubr(F, 'functionp')
  vars.defsubr(F, 'hash_table_p')
  vars.defsubr(F, 'subrp')
  vars.defsubr(F, 'byte_code_function_p')
  vars.defsubr(F, 'recordp')
  vars.defsubr(F, 'char_table_p')

  vars.defsym('Qquote', 'quote')
  vars.defsym('Qlambda', 'lambda')
  vars.defsym('Qtop_level', 'top-level')
  vars.defsym('Qerror_conditions', 'error-conditions')
  vars.defsym('Qerror_message', 'error-message')

  vars.defsym('Qlistp', 'listp')
  vars.defsym('Qsymbolp', 'symbolp')
  vars.defsym('Qintegerp', 'integerp')
  vars.defsym('Qstringp', 'stringp')
  vars.defsym('Qconsp', 'consp')
  vars.defsym('Qwholenump', 'wholenump')
  vars.defsym('Qfixnump', 'fixnump')
  vars.defsym('Qarrayp', 'arrayp')
  vars.defsym('Qchartablep', 'chartablep')
  vars.defsym('Qvectorp', 'vectorp')
  vars.defsym('Qnumber_or_marker_p', 'number-or-markerp')
  vars.defsym('Qbyte_code_function_p', 'byte-code-function-p')
  vars.defsym('Qbuffer_or_string_p', 'buffer-or-string-p')
  vars.defsym('Qframe_live_p', 'frame-live-p')
  vars.defsym('Qbufferp', 'bufferp')
  vars.defsym('Qnumberp', 'numberp')

  vars.defsym('QCtest', ':test')
  vars.defsym('QCsize', ':size')
  vars.defsym('QCpurecopy', ':purecopy')
  vars.defsym('QCrehash_size', ':rehash-size')
  vars.defsym('QCrehash_threshold', ':rehash-threshold')
  vars.defsym('QCweakness', ':weakness')

  vars.defsym('Qcurve', 'curve')
  vars.defsym('Qstraight', 'straight')
  vars.defsym('Qgrave', 'grave')

  vars.defsym('Qinteger', 'integer')
  vars.defsym('Qsymbol', 'symbol')
  vars.defsym('Qstring', 'string')
  vars.defsym('Qcons', 'cons')
  vars.defsym('Qfloat', 'float')
  vars.defsym('Qvector', 'vector')
  vars.defsym('Qmarker', 'marker')
  vars.defsym('Qsymbol_with_pos', 'symbol-with-pos')
  vars.defsym('Qoverlay', 'overlay')
  vars.defsym('Qfinalizer', 'finalizer')
  vars.defsym('Quser_ptr', 'user-ptr')
  vars.defsym('Qwindow_configuration', 'window-configuration')
  vars.defsym('Qprocess', 'process')
  vars.defsym('Qwindow', 'window')
  vars.defsym('Qsubr', 'subr')
  vars.defsym('Qcompiled_function', 'compiled-function')
  vars.defsym('Qbuffer', 'buffer')
  vars.defsym('Qchar_table', 'char-table')
  vars.defsym('Qbool_vector', 'bool-vector')
  vars.defsym('Qframe', 'frame')
  vars.defsym('Qthread', 'thread')
  vars.defsym('Qmutex', 'mutex')
  vars.defsym('Qcondition_variable', 'condition-variable')
  vars.defsym('Qterminal', 'terminal')
  vars.defsym('Qmodule_function', 'module-function')
  vars.defsym('Qnative_comp_unit', 'native-comp-unit')
  vars.defsym('Qxwidget', 'xwidget')
  vars.defsym('Qxwidget_view', 'xwidget-view')
  vars.defsym('Qtreesit_parser', 'treesit-parser')
  vars.defsym('Qtreesit_node', 'treesit-node')
  vars.defsym('Qtreesit_compiled_query', 'treesit-compiled-query')
  vars.defsym('Qsqlite', 'sqlite')
  vars.defsym('Qbyte_code', 'byte-code')

  vars.defsym('Qwatchers', 'watchers')
  vars.Qunique = alloc.make_symbol(alloc.make_pure_c_string 'unbound')
end
return M
