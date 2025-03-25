local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'
local signal = require 'elisp.signal'
local print_ = require 'elisp.print'
local textprop = require 'elisp.textprop'
local alloc = require 'elisp.alloc'
local overflow = require 'elisp.overflow'
local chartab = require 'elisp.chartab'
local chars = require 'elisp.chars'
local specpdl = require 'elisp.specpdl'

local M = {}

local function hash_combine(a, b)
  return math.abs(bit.tobit(a * 33 + b))
end
---@param str string
---@return number
function M.hash_string(str)
  if _G.vim_elisp_later then
    error('TODO: placeholder hash algorithm')
  end
  local hash = 0
  for i = 1, #str do
    hash = hash_combine(hash, str:byte(i))
  end
  return hash
end
---@param obj vim.elisp.obj
---@param _depth number?
---@return number
local function sxhash(obj, _depth)
  if _G.vim_elisp_later then
    error('TODO')
  end
  local depth = _depth or 0
  if depth > 3 then
    return 0
  end
  local typ = lisp.xtype(obj)
  if typ == lisp.type.int0 then
    return lisp.fixnum(obj)
  elseif typ == lisp.type.symbol then
    return lisp.xhash(obj)
  elseif typ == lisp.type.string then
    return M.hash_string(lisp.sdata(obj))
  elseif typ == lisp.type.vectorlike then
    local pvec = lisp.pseudovector_type(obj)
    if
      pvec == lisp.pvec.normal_vector
      or pvec == lisp.pvec.char_table
      or pvec == lisp.pvec.sub_char_table
      or pvec == lisp.pvec.compiled
      or pvec == lisp.pvec.record
      or pvec == lisp.pvec.font
    then
      if lisp.subchartablep(obj) then
        return 42
      end
      local hash = lisp.asize(obj)
      for i = 0, math.min(7, hash) - 1 do
        hash = hash_combine(hash, sxhash(lisp.aref(obj, i), depth + 1))
      end
      return hash
    else
      error('TODO')
    end
  elseif typ == lisp.type.cons then
    local hash = 0
    local i = 0
    while lisp.consp(obj) and i < 7 do
      hash = hash_combine(hash, sxhash(lisp.xcar(obj), depth + 1))
      obj = lisp.xcdr(obj)
      i = i + 1
    end
    if not lisp.nilp(obj) then
      hash = hash_combine(hash, sxhash(obj, depth + 1))
    end
    return hash
  elseif typ == lisp.type.float then
    error('TODO')
  else
    error('unreachable')
  end
end
function M.concat_to_string(args)
  local dest_multibyte = false
  local some_multibyte = false
  for _, arg in ipairs(args) do
    if lisp.stringp(arg) then
      if lisp.string_multibyte(arg) then
        dest_multibyte = true
      else
        some_multibyte = true
      end
    elseif lisp.nilp(arg) then
    elseif lisp.consp(arg) then
      while lisp.consp(arg) do
        local ch = lisp.xcar(arg)
        chars.check_character(ch)
        local c = lisp.fixnum(ch)
        if not chars.asciicharp(c) and not chars.charbyte8p(c) then
          dest_multibyte = true
        end
        arg = lisp.xcdr(arg)
      end
    elseif lisp.vectorp(arg) then
      error('TODO')
    end
  end
  local buf = print_.make_printcharfun()
  for _, arg in ipairs(args) do
    if lisp.stringp(arg) then
      if lisp.string_intervals(arg) then
        if _G.vim_elisp_later then
          error('TODO')
        end
      end
      if lisp.string_multibyte(arg) == dest_multibyte then
        buf.write(lisp.sdata(arg))
      else
        buf.write(chars.str_to_multibyte(lisp.sdata(arg)))
      end
    elseif lisp.vectorp(arg) then
      error('TODO')
    elseif lisp.nilp(arg) then
    elseif lisp.consp(arg) then
      local tail = arg
      while not lisp.nilp(tail) do
        local c = lisp.fixnum(lisp.xcar(tail))
        if dest_multibyte then
          buf.write(chars.charstring(c))
        else
          buf.write(c)
        end
        tail = lisp.xcdr(tail)
      end
    else
      signal.wrong_type_argument(vars.Qsequencep, arg)
    end
  end
  return dest_multibyte and alloc.make_multibyte_string(buf.out(), -1)
    or alloc.make_unibyte_string(buf.out())
end
local function concat_to_vector(args)
  local result_len = 0
  for _, arg in ipairs(args) do
    if
      not (
        lisp.vectorp(arg)
        or lisp.consp(arg)
        or lisp.nilp(arg)
        or lisp.stringp(arg)
        or lisp.boolvectorp(arg)
        or lisp.compiledp(arg)
      )
    then
      signal.wrong_type_argument(vars.Qsequencep, arg)
    end
    result_len = result_len + lisp.fixnum(vars.F.length(arg))
  end
  local result = alloc.make_vector(result_len, 'nil')
  local dst = 0
  for _, arg in ipairs(args) do
    if lisp.vectorp(arg) then
      for i = 0, lisp.asize(arg) - 1 do
        lisp.aset(result, dst, lisp.aref(arg, i))
        dst = dst + 1
      end
    elseif lisp.consp(arg) then
      while not lisp.nilp(arg) do
        lisp.aset(result, dst, lisp.xcar(arg))
        dst = dst + 1
        arg = lisp.xcdr(arg)
      end
    elseif lisp.nilp(arg) then
    elseif lisp.stringp(arg) then
      if lisp.string_multibyte(arg) then
        error('TODO')
      else
        for i = 0, lisp.schars(arg) - 1 do
          lisp.aset(result, dst, lisp.make_fixnum(lisp.sref(arg, i)))
          dst = dst + 1
        end
      end
    elseif lisp.boolvectorp(arg) then
      error('TODO')
    else
      error('TODO')
    end
  end
  return result
end

---@type vim.elisp.F
local F = {}
local function concat_to_list(args)
  local nargs = #args - 1
  local last_tail = args[#args]
  local result = vars.Qnil
  local last = vars.Qnil
  for i = 1, nargs do
    local arg = args[i]
    if lisp.consp(arg) then
      local head = vars.F.cons(lisp.xcar(arg), vars.Qnil)
      local prev = head
      arg = lisp.xcdr(arg)
      local _, _end = lisp.for_each_tail(arg, function(a)
        local next_ = vars.F.cons(lisp.xcar(a), vars.Qnil)
        lisp.xsetcdr(prev, next_)
        prev = next_
      end)
      lisp.check_list_end(_end, arg)
      if lisp.nilp(result) then
        result = head
      else
        lisp.xsetcdr(last, head)
      end
      last = prev
    elseif lisp.nilp(arg) then
    elseif
      lisp.vectorp(arg)
      or lisp.stringp(arg)
      or lisp.boolvectorp(arg)
      or lisp.compiledp(arg)
    then
      local arglen = lisp.fixnum(vars.F.length(arg))
      for idx = 0, arglen - 1 do
        local elt
        if lisp.stringp(arg) then
          error('TODO')
        elseif lisp.boolvectorp(arg) then
          error('TODO')
        else
          return lisp.aref(arg, idx)
        end
        local node = vars.F.cons(elt, vars.Qnil)
        if lisp.nilp(result) then
          result = node
        else
          lisp.xsetcdr(last, node)
        end
        last = node
      end
    else
      signal.wrong_type_argument(vars.Qsequencep, arg)
    end
  end
  if result == vars.Qnil then
    result = last_tail
  else
    lisp.xsetcdr(last, last_tail)
  end
  return result
end
F.append = {
  'append',
  0,
  -2,
  0,
  [[Concatenate all the arguments and make the result a list.
The result is a list whose elements are the elements of all the arguments.
Each argument may be a list, vector or string.

All arguments except the last argument are copied.  The last argument
is just used as the tail of the new list.

usage: (append &rest SEQUENCES)]],
}
function F.append.fa(args)
  if #args == 0 then
    return vars.Qnil
  end
  return concat_to_list(args)
end
F.assq = {
  'assq',
  2,
  2,
  0,
  [[Return non-nil if KEY is `eq' to the car of an element of ALIST.
The value is actually the first element of ALIST whose car is KEY.
Elements of ALIST that are not conses are ignored.]],
}
---@param key vim.elisp.obj
---@param alist vim.elisp.obj
---@return vim.elisp.obj
function F.assq.f(key, alist)
  local ret, tail = lisp.for_each_tail(alist, function(tail)
    if lisp.consp(lisp.xcar(tail)) and lisp.eq(lisp.xcar(lisp.xcar(tail)), key) then
      return lisp.xcar(tail)
    end
  end)
  if ret then
    return ret
  end
  lisp.check_list_end(tail, alist)
  return vars.Qnil
end
F.rassq = {
  'rassq',
  2,
  2,
  0,
  [[Return non-nil if KEY is `eq' to the cdr of an element of ALIST.
The value is actually the first element of ALIST whose cdr is KEY.]],
}
function F.rassq.f(key, alist)
  local ret, tail = lisp.for_each_tail(alist, function(tail)
    if lisp.consp(lisp.xcar(tail)) and lisp.eq(lisp.xcdr(lisp.xcar(tail)), key) then
      return lisp.xcar(tail)
    end
  end)
  if ret then
    return ret
  end
  lisp.check_list_end(tail, alist)
  return vars.Qnil
end
F.assoc = {
  'assoc',
  2,
  3,
  0,
  [[Return non-nil if KEY is equal to the car of an element of ALIST.
The value is actually the first element of ALIST whose car equals KEY.

Equality is defined by the function TESTFN, defaulting to `equal'.
TESTFN is called with 2 arguments: a car of an alist element and KEY.]],
}
function F.assoc.f(key, alist, testfn)
  if (lisp.symbolp(key) or lisp.fixnump(key)) and lisp.nilp(testfn) then
    return vars.F.assq(key, alist)
  end
  local ret, tail = lisp.for_each_tail(alist, function(tail)
    local car = lisp.xcar(tail)
    if lisp.consp(car) then
      if
        lisp.nilp(testfn)
        and (lisp.eq(lisp.xcar(car), key) or not lisp.nilp(vars.F.equal(lisp.xcar(car), key)))
      then
        return car
      elseif
        not lisp.nilp(testfn)
        and not lisp.nilp(vars.F.funcall({ testfn, lisp.xcar(car), key }))
      then
        return car
      end
    end
  end)
  if ret then
    return ret
  end
  lisp.check_list_end(tail, alist)
  return vars.Qnil
end
function M.assq_no_quit(key, alist)
  while not lisp.nilp(alist) do
    if lisp.consp(lisp.xcar(alist)) and lisp.eq(lisp.xcar(lisp.xcar(alist)), key) then
      return lisp.xcar(alist)
    end
    alist = lisp.xcdr(alist)
  end
  return vars.Qnil
end
F.member = {
  'member',
  2,
  2,
  0,
  [[Return non-nil if ELT is an element of LIST.  Comparison done with `equal'.
The value is actually the tail of LIST whose car is ELT.]],
}
function F.member.f(elt, list)
  if lisp.symbolp(elt) or lisp.fixnump(elt) then
    return vars.F.memq(elt, list)
  end
  local ret, tail = lisp.for_each_tail(list, function(tail)
    if not lisp.nilp(vars.F.equal(elt, lisp.xcar(tail))) then
      return tail
    end
  end)
  if ret then
    return ret
  end
  lisp.check_list_end(tail, list)
  return vars.Qnil
end
F.memq = {
  'memq',
  2,
  2,
  0,
  [[Return non-nil if ELT is an element of LIST.  Comparison done with `eq'.
The value is actually the tail of LIST whose car is ELT.]],
}
function F.memq.f(elt, list)
  local ret, tail = lisp.for_each_tail(list, function(tail)
    if lisp.eq(lisp.xcar(tail), elt) then
      return tail
    end
  end)
  if ret then
    return ret
  end
  lisp.check_list_end(tail, list)
  return vars.Qnil
end
F.nthcdr = { 'nthcdr', 2, 2, 0, [[Take cdr N times on LIST, return the result.]] }
function F.nthcdr.f(n, list)
  local tail = list
  lisp.check_integer(n)
  local num
  if lisp.fixnump(n) then
    num = lisp.fixnum(n)
    if num <= 127 then
      for _ = 1, num do
        if not lisp.consp(tail) then
          lisp.check_list_end(tail, list)
          return vars.Qnil
        end
        tail = lisp.xcdr(tail)
      end
      return tail
    end
  else
    error('TODO')
  end
  error('TODO')
end
F.nth = {
  'nth',
  2,
  2,
  0,
  [[Return the Nth element of LIST.
N counts from zero.  If LIST is not that long, nil is returned.]],
}
function F.nth.f(n, list)
  return vars.F.car(vars.F.nthcdr(n, list))
end
local function mapcar1(leni, vals, fn, seq)
  if lisp.nilp(seq) then
    return 0
  elseif lisp.consp(seq) then
    local tail = seq
    for i = 0, leni - 1 do
      if not lisp.consp(tail) then
        return i
      end
      local dummy = vars.F.funcall({ fn, lisp.xcar(tail) })
      if vals then
        vals[i + 1] = dummy
      end
      tail = lisp.xcdr(tail)
    end
  elseif lisp.stringp(seq) then
    local i_bytes = 0
    for i = 0, leni - 1 do
      local c, len = chars.fetchstringcharadvance(seq, i_bytes)
      i_bytes = i_bytes + len
      local dummy = vars.F.funcall({ fn, lisp.make_fixnum(c) })
      if vals then
        vals[i + 1] = dummy
      end
    end
  else
    error('TODO')
  end
  return leni
end
F.mapconcat = {
  'mapconcat',
  2,
  3,
  0,
  [[Apply FUNCTION to each element of SEQUENCE, and concat the results as strings.
In between each pair of results, stick in SEPARATOR.  Thus, " " as
  SEPARATOR results in spaces between the values returned by FUNCTION.

SEQUENCE may be a list, a vector, a bool-vector, or a string.

Optional argument SEPARATOR must be a string, a vector, or a list of
characters; nil stands for the empty string.

FUNCTION must be a function of one argument, and must return a value
  that is a sequence of characters: either a string, or a vector or
  list of numbers that are valid character codepoints.]],
}
function F.mapconcat.f(func, sequence, separator)
  if lisp.chartablep(sequence) then
    signal.wrong_type_argument(vars.Qlistp, sequence)
  end
  local leni = lisp.fixnum(vars.F.length(sequence))
  if leni == 0 then
    return alloc.make_multibyte_string('', 0)
  end
  local args = {}
  assert(mapcar1(leni, args, func, sequence) == leni)
  if lisp.nilp(separator) or (lisp.stringp(separator) and lisp.schars(separator) == 0) then
  else
    for i = 1, leni - 1 do
      table.insert(args, i * 2, separator)
    end
  end
  return vars.F.concat(args)
end
F.mapcar = {
  'mapcar',
  2,
  2,
  0,
  [[Apply FUNCTION to each element of SEQUENCE, and make a list of the results.
The result is a list just as long as SEQUENCE.
SEQUENCE may be a list, a vector, a bool-vector, or a string.]],
}
function F.mapcar.f(func, sequence)
  if lisp.chartablep(sequence) then
    signal.wrong_type_argument(vars.Qlistp, sequence)
  end
  local leni = lisp.fixnum(vars.F.length(sequence))
  local args = {}
  local nmapped = mapcar1(leni, args, func, sequence)
  return vars.F.list({ unpack(args, 1, nmapped) })
end
F.mapc = {
  'mapc',
  2,
  2,
  0,
  [[Apply FUNCTION to each element of SEQUENCE for side effects only.
Unlike `mapcar', don't accumulate the results.  Return SEQUENCE.
SEQUENCE may be a list, a vector, a bool-vector, or a string.]],
}
function F.mapc.f(func, sequence)
  local leni = lisp.fixnum(vars.F.length(sequence))
  if lisp.chartablep(sequence) then
    signal.wrong_type_argument(vars.Qlistp, sequence)
  end
  mapcar1(leni, nil, func, sequence)
  return sequence
end
---@param obj vim.elisp.obj
---@return vim.elisp._hash_table
local function check_hash_table(obj)
  lisp.check_hash_table(obj)
  return obj --[[@as vim.elisp._hash_table]]
end
F.maphash = {
  'maphash',
  2,
  2,
  0,
  [[Call FUNCTION for all entries in hash table TABLE.
FUNCTION is called with two arguments, KEY and VALUE.
`maphash' always returns nil.]],
}
function F.maphash.f(func, table)
  local h = check_hash_table(table)
  for i = 0, lisp.asize(h.next) - 1 do
    local k = lisp.aref(h.key_and_value, i * 2)
    if k ~= vars.Qunique then
      vars.F.funcall({ func, k, lisp.aref(h.key_and_value, i * 2 + 1) })
    end
  end
  return vars.Qnil
end
F.nreverse = {
  'nreverse',
  1,
  1,
  0,
  [[Reverse order of items in a list, vector or string SEQ.
If SEQ is a list, it should be nil-terminated.
This function may destructively modify SEQ to produce the value.]],
}
function F.nreverse.f(seq)
  if lisp.nilp(seq) then
    return seq
  elseif lisp.consp(seq) then
    local prev = vars.Qnil
    local tail = seq
    while lisp.consp(tail) do
      local next_ = lisp.xcdr(tail)
      if next_ == seq then
        require 'elisp.signal'.xsignal(vars.Qcircular_list, seq)
      end
      vars.F.setcdr(tail, prev)
      prev = tail
      tail = next_
    end
    lisp.check_list_end(tail, seq)
    return prev
  else
    error('TODO')
  end
end
F.reverse = {
  'reverse',
  1,
  1,
  0,
  [[Return the reversed copy of list, vector, or string SEQ.
See also the function `nreverse', which is used more often.]],
}
function F.reverse.f(seq)
  if lisp.nilp(seq) then
    return vars.Qnil
  elseif lisp.consp(seq) then
    local new = vars.Qnil
    local _, t = lisp.for_each_tail(seq, function(t)
      new = vars.F.cons(lisp.xcar(t), new)
    end)
    lisp.check_list_end(t, seq)
    return new
  else
    error('TODO')
  end
end
F.nconc = {
  'nconc',
  0,
  -2,
  0,
  [[Concatenate any number of lists by altering them.
Only the last argument is not altered, and need not be a list.
usage: (nconc &rest LISTS)]],
}
function F.nconc.fa(args)
  local val = vars.Qnil
  for k, v in ipairs(args) do
    local tem = v
    if lisp.nilp(tem) then
      goto continue
    elseif lisp.nilp(val) then
      val = tem
    end
    if k == #args then
      break
    end
    lisp.check_cons(tem)
    local tail, _
    _, tem = lisp.for_each_tail(tem, function(t)
      tail = t
    end)
    tem = args[k + 1]
    vars.F.setcdr(tail, tem)
    if lisp.nilp(tem) then
      args[k + 1] = tail
    end
    ::continue::
  end
  return val
end
F.length = {
  'length',
  1,
  1,
  0,
  [[Return the length of vector, list or string SEQUENCE.
A byte-code function object is also allowed.

If the string contains multibyte characters, this is not necessarily
the number of bytes in the string; it is the number of characters.
To get the number of bytes, use `string-bytes'.

If the length of a list is being computed to compare to a (small)
number, the `length<', `length>' and `length=' functions may be more
efficient.]],
}
function F.length.f(sequence)
  local val
  if lisp.consp(sequence) then
    val = lisp.list_length(sequence)
  elseif lisp.nilp(sequence) then
    val = 0
  elseif lisp.stringp(sequence) then
    val = lisp.schars(sequence)
  elseif lisp.vectorp(sequence) or lisp.compiledp(sequence) then
    val = lisp.asize(sequence)
  else
    error('TODO')
    signal.wrong_type_argument(vars.Qsequencep, sequence)
  end
  return lisp.make_fixnum(val)
end
F.safe_length = {
  'safe-length',
  1,
  1,
  0,
  [[Return the length of a list, but avoid error or infinite loop.
This function never gets an error.  If LIST is not really a list,
it returns 0.  If LIST is circular, it returns an integer that is at
least the number of distinct elements.]],
}
function F.safe_length.f(list)
  local len = 0
  lisp.for_each_tail_safe(list, function()
    len = len + 1
  end)
  return lisp.make_fixnum(len)
end
---@param h vim.elisp._hash_table
---@param idx number
---@return number
local function hash_index(h, idx)
  return lisp.fixnum(lisp.aref(h.index, idx))
end
---@param h vim.elisp._hash_table
---@param key vim.elisp.obj
---@return number
---@return number
function M.hash_lookup(h, key)
  local hash_code = h.test.hashfn(key, h)
  assert(type(hash_code) == 'number')
  local i = hash_index(h, hash_code % lisp.asize(h.index))
  while 0 <= i do
    if
      lisp.eq(key, lisp.aref(h.key_and_value, i * 2))
      or (
        h.test.cmpfn ~= 0
        and lisp.eq(lisp.make_fixnum(hash_code), lisp.aref(h.hash, i))
        and h.test.cmpfn(key, lisp.aref(h.key_and_value, i * 2), h)
      )
    then
      break
    end
    i = lisp.fixnum(lisp.aref(h.next, i))
  end
  return i, hash_code
end
local function larger_vecalloc(vec, nitems_max)
  local old_size = lisp.asize(vec)
  local v = alloc.make_vector(nitems_max, 'nil')
  for i = 0, old_size - 1 do
    lisp.aset(v, i, lisp.aref(vec, i))
  end
  return v
end
---@param rehash_threshold number (float)
---@param size number
---@return number
local function hash_index_size(rehash_threshold, size)
  local n = math.floor(size / rehash_threshold)
  n = n - n % 2
  while true do
    if n > overflow.max then
      signal.error('Hash table too large')
    end
    if n % 3 ~= 0 and n % 5 ~= 0 and n % 7 ~= 0 then
      return n
    end
    n = n + 2
  end
end
---@param h vim.elisp._hash_table
local function maybe_resize_hash_table(h)
  if not (h.next_free < 0) then
    return
  end
  local old_size = lisp.asize(h.next)
  local new_size
  local rehash_size = h.rehash_size
  if rehash_size < 0 then
    new_size = overflow.sub(old_size, rehash_size) or overflow.max
  else
    new_size = overflow.mul(old_size, rehash_size + 1) or overflow.max
  end
  if new_size <= old_size then
    new_size = old_size + 1
  end
  local next_ = larger_vecalloc(h.next, math.floor(new_size))
  local next_size = lisp.asize(next_)
  for i = old_size, next_size - 2 do
    lisp.aset(next_, i, lisp.make_fixnum(i + 1))
  end
  lisp.aset(next_, next_size - 1, lisp.make_fixnum(-1))
  local key_and_value = larger_vecalloc(h.key_and_value, next_size * 2)
  for i = 2 * old_size, 2 * next_size - 1 do
    lisp.aset(key_and_value, i, vars.Qunique)
  end
  local hash = larger_vecalloc(h.hash, next_size)
  local index_size = hash_index_size(h.rehash_threshold, next_size)
  h.index = alloc.make_vector(index_size, lisp.make_fixnum(-1))
  h.key_and_value = key_and_value
  h.hash = hash
  h.next = next_
  h.next_free = old_size
  for i = 0, old_size - 1 do
    if not lisp.nilp(lisp.aref(h.hash, i)) then
      local hash_code = lisp.fixnum(lisp.aref(h.hash, i))
      local start_of_bucket = hash_code % lisp.asize(h.index)
      lisp.aset(h.next, i, lisp.aref(h.index, start_of_bucket))
      lisp.aset(h.index, start_of_bucket, lisp.make_fixnum(i))
    end
  end
end
---@param h vim.elisp._hash_table
---@param key vim.elisp.obj
---@param val vim.elisp.obj
---@param hash number
---@return number
function M.hash_put(h, key, val, hash)
  maybe_resize_hash_table(h)
  h.count = h.count + 1
  local i = h.next_free
  assert(lisp.nilp(lisp.aref(h.hash, i)))
  assert(lisp.aref(h.key_and_value, i * 2) == vars.Qunique)
  h.next_free = lisp.fixnum(lisp.aref(h.next, i))
  lisp.aset(h.key_and_value, i * 2, key)
  lisp.aset(h.key_and_value, i * 2 + 1, val)
  lisp.aset(h.hash, i, lisp.make_fixnum(hash))
  local start_of_bucket = hash % lisp.asize(h.index)
  lisp.aset(h.next, i, lisp.aref(h.index, start_of_bucket))
  lisp.aset(h.index, start_of_bucket, lisp.make_fixnum(i))
  return i
end
---@param a vim.elisp.obj
---@param b vim.elisp.obj
---@param kind 'plain'|'no_quit'|'including_properties'
---@param depth number
---@param ht table
---@return boolean
local function internal_equal(a, b, kind, depth, ht)
  if depth > 10 then
    assert(kind ~= 'no_quit')
    if depth > 200 then
      signal.error('Stack overflow in equal')
    end
    local t = lisp.xtype(a)
    if t == lisp.type.cons or t == lisp.type.vectorlike then
      local val = ht[a]
      if val then
        if not lisp.nilp(vars.F.memq(b, val)) then
          return true
        else
          ht[a] = vars.F.cons(b, ht[a])
        end
      else
        ht[a] = vars.F.cons(b, vars.Qnil)
      end
    end
  end
  if lisp.symbolwithposp(a) then
    error('TODO')
  end
  if lisp.symbolwithposp(b) then
    error('TODO')
  end
  if a == b then
    return true
  elseif lisp.xtype(a) ~= lisp.xtype(b) then
    return false
  end
  local t = lisp.xtype(a)
  if t == lisp.type.float then
    error('TODO')
  elseif t == lisp.type.cons then
    if kind == 'no_quit' then
      error('TODO')
    else
      if not internal_equal(lisp.xcar(a), lisp.xcar(b), kind, depth + 1, ht) then
        return false
      end
      if not internal_equal(lisp.xcdr(a), lisp.xcdr(b), kind, depth + 1, ht) then
        return false
      end
      return true
    end
  elseif t == lisp.type.vectorlike then
    local pvec = lisp.pseudovector_type(a)
    if pvec ~= lisp.pseudovector_type(b) then
      return false
    end
    if
      pvec == lisp.pvec.normal_vector
      or pvec == lisp.pvec.char_table
      or pvec == lisp.pvec.sub_char_table
      or pvec == lisp.pvec.compiled
      or pvec == lisp.pvec.record
    then
      if lisp.asize(a) ~= lisp.asize(b) then
        return false
      end
      for k, v in pairs(a) do
        if type(v) ~= 'table' then
          if a[k] ~= b[k] then
            return false
          end
        elseif k == 'contents' then
          for i = 0, lisp.asize(a) - 1 do
            if not internal_equal(lisp.aref(a, i), lisp.aref(b, i), kind, depth + 1, ht) then
              return false
            end
          end
        else
          if not internal_equal(a[k], b[k], kind, depth + 1, ht) then
            return false
          end
        end
      end
      return true
    elseif pvec == lisp.pvec.bool_vector then
      local oa = a --[[@as vim.elisp._bool_vector]]
      local ob = b --[[@as vim.elisp._bool_vector]]
      if #oa.contents ~= #ob.contents then
        return false
      end
      for i = 1, #oa.contents do
        if oa.contents[i] ~= ob.contents[i] then
          return false
        end
      end
      return true
    else
      error('TODO')
    end
  elseif t == lisp.type.string then
    return lisp.schars(a) == lisp.schars(b)
      and lisp.sdata(a) == lisp.sdata(b)
      and (kind ~= 'including_properties' or error('TODO'))
  end
  return false
end
F.equal = {
  'equal',
  2,
  2,
  0,
  [[Return t if two Lisp objects have similar structure and contents.
They must have the same data type.
Conses are compared by comparing the cars and the cdrs.
Vectors and strings are compared element by element.
Numbers are compared via `eql', so integers do not equal floats.
\(Use `=' if you want integers and floats to be able to be equal.)
Symbols must match exactly.]],
}
function F.equal.f(a, b)
  return internal_equal(a, b, 'plain', 0, {}) and vars.Qt or vars.Qnil
end
F.eql = {
  'eql',
  2,
  2,
  0,
  [[Return t if the two args are `eq' or are indistinguishable numbers.
Integers with the same value are `eql'.
Floating-point values with the same sign, exponent and fraction are `eql'.
This differs from numeric comparison: (eql 0.0 -0.0) returns nil and
\(eql 0.0e+NaN 0.0e+NaN) returns t, whereas `=' does the opposite.]],
}
function F.eql.f(obj1, obj2)
  if lisp.floatp(obj1) then
    error('TODO')
  elseif lisp.bignump(obj1) then
    error('TODO')
  else
    return lisp.eq(obj1, obj2) and vars.Qt or vars.Qnil
  end
end
function M.plist_put(plist, prop, val)
  local prev = vars.Qnil
  local tail = plist
  local has_visited = {}
  while lisp.consp(tail) do
    if not lisp.consp(lisp.xcdr(tail)) then
      break
    end
    if lisp.eq(lisp.xcar(tail), prop) then
      vars.F.setcar(lisp.xcdr(tail), val)
      return plist
    end
    if has_visited[tail] then
      require 'elisp.signal'.xsignal(vars.Qcircular_list, plist)
    end
    prev = tail
    tail = lisp.xcdr(tail)
    has_visited[tail] = true
    tail = lisp.xcdr(tail)
  end
  lisp.check_type(lisp.nilp(tail), vars.Qplistp, plist)
  if lisp.nilp(prev) then
    return vars.F.cons(prop, vars.F.cons(val, plist))
  end
  local newcell = vars.F.cons(prop, vars.F.cons(val, lisp.xcdr(lisp.xcdr(prev))))
  vars.F.setcdr(lisp.xcdr(prev), newcell)
  return plist
end
F.put = {
  'put',
  3,
  3,
  0,
  [[Store SYMBOL's PROPNAME property with value VALUE.
It can be retrieved with `(get SYMBOL PROPNAME)'.]],
}
function F.put.f(sym, propname, value)
  lisp.check_symbol(sym)
  lisp.set_symbol_plist(sym, M.plist_put((sym --[[@as vim.elisp._symbol]]).plist, propname, value))
  return value
end
F.plist_put = {
  'plist-put',
  3,
  4,
  0,
  [[Change value in PLIST of PROP to VAL.
PLIST is a property list, which is a list of the form
\(PROP1 VALUE1 PROP2 VALUE2 ...).

The comparison with PROP is done using PREDICATE, which defaults to `eq'.

If PROP is already a property on the list, its value is set to VAL,
otherwise the new PROP VAL pair is added.  The new plist is returned;
use `(setq x (plist-put x prop val))' to be sure to use the new value.
The PLIST is modified by side effects.]],
}
function F.plist_put.f(plist, prop, val, predicate)
  if lisp.nilp(predicate) then
    return M.plist_put(plist, prop, val)
  end
  error('TODO')
end
function M.plist_get(plist, prop)
  local tail = plist
  local has_visited = {}
  while lisp.consp(tail) do
    if not lisp.consp(lisp.xcdr(tail)) then
      break
    end
    if lisp.eq(lisp.xcar(tail), prop) then
      return lisp.xcar(lisp.xcdr(tail))
    end
    if has_visited[tail] then
      require 'elisp.signal'.xsignal(vars.Qcircular_list, plist)
    end
    has_visited[tail] = true
    tail = lisp.xcdr(tail)
    tail = lisp.xcdr(tail)
  end
  return vars.Qnil
end
F.plist_get = {
  'plist-get',
  2,
  3,
  0,
  [[Extract a value from a property list.
PLIST is a property list, which is a list of the form
\(PROP1 VALUE1 PROP2 VALUE2...).

This function returns the value corresponding to the given PROP, or
nil if PROP is not one of the properties on the list.  The comparison
with PROP is done using PREDICATE, which defaults to `eq'.

This function doesn't signal an error if PLIST is invalid.]],
}
function F.plist_get.f(plist, prop, predicate)
  if lisp.nilp(predicate) then
    return M.plist_get(plist, prop)
  end
  error('TODO')
end
F.get = {
  'get',
  2,
  2,
  0,
  [[Return the value of SYMBOL's PROPNAME property.
This is the last value stored with `(put SYMBOL PROPNAME VALUE)'.]],
}
function F.get.f(sym, propname)
  lisp.check_symbol(sym)
  local propval =
    M.plist_get(vars.F.cdr(vars.F.assq(sym, vars.V.overriding_plist_environment)), propname)
  if not lisp.nilp(propval) then
    return propval
  end
  return M.plist_get((sym --[[@as vim.elisp._symbol]]).plist, propname)
end
F.featurep = {
  'featurep',
  1,
  2,
  0,
  [[Return t if FEATURE is present in this Emacs.

Use this to conditionalize execution of lisp code based on the
presence or absence of Emacs or environment extensions.
Use `provide' to declare that a feature is available.  This function
looks at the value of the variable `features'.  The optional argument
SUBFEATURE can be used to check a specific subfeature of FEATURE.]],
}
function F.featurep.f(feature, subfeature)
  lisp.check_symbol(feature)
  local tem = vars.F.memq(feature, vars.V.features)
  if not lisp.nilp(tem) and not lisp.nilp(subfeature) then
    error('TODO')
  end
  return lisp.nilp(tem) and vars.Qnil or vars.Qt
end
F.provide = {
  'provide',
  1,
  2,
  0,
  [[Announce that FEATURE is a feature of the current Emacs.
The optional argument SUBFEATURES should be a list of symbols listing
particular subfeatures supported in this version of FEATURE.]],
}
function F.provide.f(feature, subfeatures)
  lisp.check_symbol(feature)
  lisp.check_list(subfeatures)
  if not lisp.nilp(vars.autoload_queue) then
    vars.autoload_queue =
      vars.F.cons(vars.F.cons(lisp.make_fixnum(0), vars.V.features), vars.autoload_queue)
  end
  local tem = vars.F.memq(feature, vars.V.features)
  if lisp.nilp(tem) then
    vars.V.features = vars.F.cons(feature, vars.V.features)
  end
  if not lisp.nilp(subfeatures) then
    vars.F.put(feature, vars.Qsubfeatures, subfeatures)
  end
  lisp.loadhist_attach(vars.F.cons(vars.Qprovide, feature))
  tem = vars.F.assq(feature, vars.V.after_load_alist)
  if lisp.consp(tem) then
    error('TODO')
  end
  return feature
end
---@param test vim.elisp.hash_table_test
---@param size number
---@param rehash_size number (float)
---@param rehash_threshold number (float)
---@param weak vim.elisp.obj
local function make_hash_table(test, size, rehash_size, rehash_threshold, weak)
  ---@type vim.elisp._hash_table
  local h = {
    test = test,
    weak = weak,
    rehash_threshold = rehash_threshold,
    rehash_size = rehash_size,
    count = 0,
    key_and_value = alloc.make_vector(size * 2, vars.Qunique),
    hash = alloc.make_vector(size, 'nil'),
    next = alloc.make_vector(size, lisp.make_fixnum(-1)),
    index = alloc.make_vector(hash_index_size(rehash_threshold, size), lisp.make_fixnum(-1)),
    mutable = true,
    next_free = 0,
  }
  for i = 0, size - 2 do
    lisp.aset(h.next, i, lisp.make_fixnum(i + 1))
  end
  return lisp.make_vectorlike_ptr(h, lisp.pvec.hash_table)
end
---@param key vim.elisp.obj
---@param args vim.elisp.obj[]
---@param used table<number,true?>
---@return vim.elisp.obj|false
local function get_key_arg(key, args, used)
  for i = 2, #args do
    if not used[i - 1] and lisp.eq(args[i - 1], key) then
      used[i - 1] = true
      used[i] = true
      return args[i]
    end
  end
  return false
end
local function hashfn_eq(key, _)
  assert(not lisp.symbolwithposp(key), 'TODO')
  -- Do we need ...^XTYPE(key)?
  return lisp.xhash(key)
end
local function cmpfn_equal(key1, key2, _)
  return not lisp.nilp(vars.F.equal(key1, key2))
end
local function hashfn_equal(key, _)
  return sxhash(key)
end
local function cmpfn_eql(key1, key2, _)
  return not lisp.nilp(vars.F.eql(key1, key2))
end
local function hashfn_eql(key, h)
  return ((lisp.floatp(key) or lisp.bignump(key)) and hashfn_equal or hashfn_eq)(key, h)
end
F.make_hash_table = {
  'make-hash-table',
  0,
  -2,
  0,
  [[Create and return a new hash table.

Arguments are specified as keyword/argument pairs.  The following
arguments are defined:

:test TEST -- TEST must be a symbol that specifies how to compare
keys.  Default is `eql'.  Predefined are the tests `eq', `eql', and
`equal'.  User-supplied test and hash functions can be specified via
`define-hash-table-test'.

:size SIZE -- A hint as to how many elements will be put in the table.
Default is 65.

:rehash-size REHASH-SIZE - Indicates how to expand the table when it
fills up.  If REHASH-SIZE is an integer, increase the size by that
amount.  If it is a float, it must be > 1.0, and the new size is the
old size multiplied by that factor.  Default is 1.5.

:rehash-threshold THRESHOLD -- THRESHOLD must a float > 0, and <= 1.0.
Resize the hash table when the ratio (table entries / table size)
exceeds an approximation to THRESHOLD.  Default is 0.8125.

:weakness WEAK -- WEAK must be one of nil, t, `key', `value',
`key-or-value', or `key-and-value'.  If WEAK is not nil, the table
returned is a weak table.  Key/value pairs are removed from a weak
hash table when there are no non-weak references pointing to their
key, value, one of key or value, or both key and value, depending on
WEAK.  WEAK t is equivalent to `key-and-value'.  Default value of WEAK
is nil.

:purecopy PURECOPY -- If PURECOPY is non-nil, the table can be copied
to pure storage when Emacs is being dumped, making the contents of the
table read only. Any further changes to purified tables will result
in an error.

usage: (make-hash-table &rest KEYWORD-ARGS)]],
}
function F.make_hash_table.fa(args)
  local used = {}
  local test = get_key_arg(vars.QCtest, args, used) or vars.Qeql
  local testdesc
  if lisp.eq(test, vars.Qeq) then
    ---@type vim.elisp.hash_table_test
    testdesc = {
      name = vars.Qeq,
      user_cmp_function = vars.Qnil,
      user_hash_function = vars.Qnil,
      cmpfn = 0,
      hashfn = hashfn_eq,
    }
  elseif lisp.eq(test, vars.Qeql) then
    ---@type vim.elisp.hash_table_test
    testdesc = {
      name = vars.Qeql,
      user_cmp_function = vars.Qnil,
      user_hash_function = vars.Qnil,
      cmpfn = cmpfn_eql,
      hashfn = hashfn_eql,
    }
  elseif lisp.eq(test, vars.Qequal) then
    ---@type vim.elisp.hash_table_test
    testdesc = {
      name = vars.Qequal,
      user_cmp_function = vars.Qnil,
      user_hash_function = vars.Qnil,
      cmpfn = cmpfn_equal,
      hashfn = hashfn_equal,
    }
  else
    error('TODO')
  end
  local _ = get_key_arg(vars.QCpurecopy, args, used)
  local size_arg = get_key_arg(vars.QCsize, args, used) or vars.Qnil
  local size
  if lisp.nilp(size_arg) then
    size = 65
  elseif lisp.fixnatp(size_arg) then
    size = lisp.fixnum(size_arg)
  else
    signal.signal_error('Invalid hash table size', size_arg)
  end
  local rehash_size_arg = get_key_arg(vars.QCrehash_size, args, used)
  local rehash_size
  if rehash_size_arg == false then
    rehash_size = 1.5 - 1
  elseif lisp.fixnump(rehash_size_arg) and 0 < lisp.fixnum(rehash_size_arg) then
    rehash_size = -lisp.fixnum(rehash_size_arg)
  elseif lisp.floatp(rehash_size_arg) and 0 < lisp.xfloat_data(rehash_size_arg) - 1 then
    rehash_size = lisp.xfloat_data(rehash_size_arg) - 1
  else
    signal.signal_error('Invalid hash table rehash size', rehash_size_arg)
  end
  local rehash_threshold_arg = get_key_arg(vars.QCrehash_threshold, args, used) --[[@as vim.elisp.obj]]
  local rehash_threshold = rehash_threshold_arg == false and 0.8125
    or not lisp.floatp(rehash_threshold_arg) and 0
    or lisp.xfloat_data(rehash_threshold_arg)
  if not (0 < rehash_threshold and rehash_threshold <= 1) then
    signal.signal_error('Invalid hash table rehash threshold', rehash_threshold_arg)
  end
  local weak = get_key_arg(vars.QCweakness, args, used) or vars.Qnil
  if lisp.eq(weak, vars.Qt) then
    weak = vars.Qkey_and_value
  end
  if
    not lisp.nilp(weak)
    and not lisp.eq(weak, vars.Qkey)
    and not lisp.eq(weak, vars.Qvalue)
    and not lisp.eq(weak, vars.Qkey_or_value)
    and not lisp.eq(weak, vars.Qkey_and_value)
  then
    lisp.signal_error('Invalid hash table weakness', weak)
  end
  for i = 1, #args - 1 do
    if not used[i] then
      lisp.signal_error('Invalid hash table weakness', args[i])
    end
  end
  return make_hash_table(testdesc, size, rehash_size, rehash_threshold, weak)
end
---@param obj vim.elisp.obj
---@param h vim.elisp._hash_table
local function check_mutable_hash_table(obj, h)
  if not h.mutable then
    signal.signal_error('hash table test modifies table', obj)
  end
end
F.puthash = {
  'puthash',
  3,
  3,
  0,
  [[Associate KEY with VALUE in hash table TABLE.
If KEY is already present in table, replace its current value with
VALUE.  In any case, return VALUE.]],
}
function F.puthash.f(key, value, t)
  local h = check_hash_table(t)
  check_mutable_hash_table(t, h)
  local i, hash = M.hash_lookup(h, key)
  if i >= 0 then
    lisp.aset(h.key_and_value, 2 * i + 1, value)
  else
    M.hash_put(h, key, value, hash)
  end
  return value
end
F.gethash = {
  'gethash',
  2,
  3,
  0,
  [[Look up KEY in TABLE and return its associated value.
If KEY is not found, return DFLT which defaults to nil.]],
}
function F.gethash.f(key, table, dflt)
  local h = check_hash_table(table)
  local i = M.hash_lookup(h, key)
  return i >= 0 and lisp.aref(h.key_and_value, 2 * i + 1) or dflt
end
F.hash_table_rehash_size =
  { 'hash-table-rehash-size', 1, 1, 0, [[Return the current rehash size of TABLE.]] }
function F.hash_table_rehash_size.f(ctable)
  local rehash_size = check_hash_table(ctable).rehash_size
  if rehash_size < 0 then
    local s = -rehash_size
    return lisp.make_fixnum(math.min(s, overflow.max))
  end
  return alloc.make_float(rehash_size + 1)
end
F.hash_table_rehash_threshold =
  { 'hash-table-rehash-threshold', 1, 1, 0, [[Return the current rehash threshold of TABLE.]] }
function F.hash_table_rehash_threshold.f(ctable)
  return alloc.make_float(check_hash_table(ctable).rehash_threshold)
end
F.delq = {
  'delq',
  2,
  2,
  0,
  [[Delete members of LIST which are `eq' to ELT, and return the result.
More precisely, this function skips any members `eq' to ELT at the
front of LIST, then removes members `eq' to ELT from the remaining
sublist by modifying its list structure, then returns the resulting
list.

Write `(setq foo (delq element foo))' to be sure of correctly changing
the value of a list `foo'.  See also `remq', which does not modify the
argument.]],
}
function F.delq.f(elt, list)
  local prev = vars.Qnil
  local _, tail = lisp.for_each_tail(list, function(tail)
    local tem = lisp.xcar(tail)
    if lisp.eq(tem, elt) then
      if lisp.nilp(prev) then
        list = lisp.xcdr(tail)
      else
        vars.F.setcdr(prev, lisp.xcdr(tail))
      end
    else
      prev = tail
    end
  end)
  lisp.check_list_end(tail, list)
  return list
end
F.delete = {
  'delete',
  2,
  2,
  0,
  [[Delete members of SEQ which are `equal' to ELT, and return the result.
SEQ must be a sequence (i.e. a list, a vector, or a string).
The return value is a sequence of the same type.

If SEQ is a list, this behaves like `delq', except that it compares
with `equal' instead of `eq'.  In particular, it may remove elements
by altering the list structure.

If SEQ is not a list, deletion is never performed destructively;
instead this function creates and returns a new vector or string.

Write `(setq foo (delete element foo))' to be sure of correctly
changing the value of a sequence `foo'.  See also `remove', which
does not modify the argument.]],
}
function F.delete.f(elt, seq)
  if lisp.vectorp(seq) then
    error('TODO')
  elseif lisp.stringp(seq) then
    error('TODO')
  else
    local prev = vars.Qnil
    local _, tail = lisp.for_each_tail(seq, function(tail)
      if not lisp.nilp(vars.F.equal(elt, lisp.xcar(tail))) then
        if lisp.nilp(prev) then
          seq = lisp.xcdr(tail)
        else
          vars.F.setcdr(prev, lisp.xcdr(tail))
        end
      else
        prev = tail
      end
    end)
    lisp.check_list_end(tail, seq)
  end
  return seq
end
F.concat = {
  'concat',
  0,
  -2,
  0,
  [[Concatenate all the arguments and make the result a string.
The result is a string whose elements are the elements of all the arguments.
Each argument may be a string or a list or vector of characters (integers).

Values of the `composition' property of the result are not guaranteed
to be `eq'.
usage: (concat &rest SEQUENCES)]],
}
function F.concat.fa(args)
  return M.concat_to_string(args)
end
F.vconcat = {
  'vconcat',
  0,
  -2,
  0,
  [[Concatenate all the arguments and make the result a vector.
The result is a vector whose elements are the elements of all the arguments.
Each argument may be a list, vector or string.
usage: (vconcat &rest SEQUENCES)]],
}
function F.vconcat.fa(args)
  return concat_to_vector(args)
end
F.copy_sequence = {
  'copy-sequence',
  1,
  1,
  0,
  [[Return a copy of a list, vector, string, char-table or record.
The elements of a list, vector or record are not copied; they are
shared with the original.  See Info node `(elisp) Sequence Functions'
for more details about this sharing and its effects.
If the original sequence is empty, this function may return
the same empty object instead of its copy.]],
}
function F.copy_sequence.f(arg)
  if lisp.nilp(arg) then
    return arg
  elseif lisp.consp(arg) then
    local val = vars.F.cons(vars.F.car(arg), vars.Qnil)
    local prev = val
    local _, tail = lisp.for_each_tail(lisp.xcdr(arg), function(tail)
      local c = vars.F.cons(lisp.xcar(tail), vars.Qnil)
      lisp.xsetcdr(prev, c)
      prev = c
    end)
    lisp.check_list_end(tail, tail)
    return val
  elseif lisp.chartablep(arg) then
    return chartab.copy_char_table(arg)
  elseif lisp.vectorp(arg) then
    local vec = alloc.make_vector(lisp.asize(arg), 'nil')
    for i = 1, lisp.asize(arg) do
      (vec --[[@as vim.elisp._normal_vector]]).contents[i] = (
        arg --[[@as vim.elisp._normal_vector]]
      ).contents[i]
    end
    return vec
  elseif lisp.stringp(arg) then
    local val = lisp.string_multibyte(arg)
        and alloc.make_multibyte_string(lisp.sdata(arg), lisp.schars(arg))
      or alloc.make_unibyte_string(lisp.sdata(arg))
    local vis = lisp.string_intervals(arg)
    if vis then
      error('TODO')
    end
    return val
  elseif lisp.boolvectorp(arg) then
    local bvec = alloc.make_bool_vector(lisp.bool_vector_size(arg), vars.Qnil)
    for i = 0, lisp.bool_vector_size(arg) - 1 do
      lisp.bool_vector_set(bvec, i, lisp.bool_vector_bitref(arg, i))
    end
    return bvec
  else
    error('TODO')
    signal.wrong_type_argument(vars.Qsequencep, arg)
  end
end
F.copy_alist = {
  'copy-alist',
  1,
  1,
  0,
  [[Return a copy of ALIST.
This is an alist which represents the same mapping from objects to objects,
but does not share the alist structure with ALIST.
The objects mapped (cars and cdrs of elements of the alist)
are shared, however.
Elements of ALIST that are not conses are also shared.]],
}
function F.copy_alist.f(alist)
  lisp.check_list(alist)
  if lisp.nilp(alist) then
    return alist
  end
  alist = vars.F.copy_sequence(alist)
  local tem = alist
  while not lisp.nilp(tem) do
    local car = lisp.xcar(tem)
    if lisp.consp(car) then
      lisp.xsetcar(tem, vars.F.cons(lisp.xcar(car), lisp.xcdr(car)))
    end
    tem = lisp.xcdr(tem)
  end
  return alist
end
local function validate_subarray(array, from, to, size)
  local f, t
  if lisp.fixnump(from) then
    f = lisp.fixnum(from)
    if f < 0 then
      f = size + f
    end
  elseif lisp.nilp(from) then
    f = 0
  else
    signal.wrong_type_argument(vars.Qintegerp, from)
  end
  if lisp.fixnump(to) then
    t = lisp.fixnum(to)
    if t < 0 then
      t = size + t
    end
  elseif lisp.nilp(to) then
    t = size
  else
    signal.wrong_type_argument(vars.Qintegerp, to)
  end
  if 0 <= f and f <= t and t <= size then
    return f, t
  end
  signal.args_out_of_range(array, from, to)
  error('unreachable')
end
function M.string_char_to_byte(s, idx)
  if lisp.schars(s) == lisp.sbytes(s) then
    return idx
  end
  return vim.str_byteindex(lisp.sdata(s), idx)
end
F.string_to_multibyte = {
  'string-to-multibyte',
  1,
  1,
  0,
  [[Return a multibyte string with the same individual chars as STRING.
If STRING is multibyte, the result is STRING itself.
Otherwise it is a newly created string, with no text properties.

If STRING is unibyte and contains an 8-bit byte, it is converted to
the corresponding multibyte character of charset `eight-bit'.

This differs from `string-as-multibyte' by converting each byte of a correct
utf-8 sequence to an eight-bit character, not just bytes that don't form a
correct sequence.]],
}
function F.string_to_multibyte.f(s)
  lisp.check_string(s)
  if lisp.string_multibyte(s) then
    return s
  end
  local nchars = lisp.schars(s)
  local data = lisp.sdata(s)
  if data:find('[\x80-\xff]') then
    data = chars.str_to_multibyte(data)
  end
  return alloc.make_multibyte_string(data, nchars)
end
F.string_as_unibyte = {
  'string-as-unibyte',
  1,
  1,
  0,
  [[Return a unibyte string with the same individual bytes as STRING.
If STRING is unibyte, the result is STRING itself.
Otherwise it is a newly created string, with no text properties.
If STRING is multibyte and contains a character of charset
`eight-bit', it is converted to the corresponding single byte.]],
}
function F.string_as_unibyte.f(s)
  lisp.check_string(s)
  if lisp.string_multibyte(s) then
    local bytes = chars.strasunibyte(lisp.sdata(s))
    s = alloc.make_unibyte_string(bytes)
  end
  return s
end
F.substring = {
  'substring',
  1,
  3,
  0,
  [[Return a new string whose contents are a substring of STRING.
The returned string consists of the characters between index FROM
\(inclusive) and index TO (exclusive) of STRING.  FROM and TO are
zero-indexed: 0 means the first character of STRING.  Negative values
are counted from the end of STRING.  If TO is nil, the substring runs
to the end of STRING.

The STRING argument may also be a vector.  In that case, the return
value is a new vector that contains the elements between index FROM
\(inclusive) and index TO (exclusive) of that vector argument.

With one argument, just copy STRING (with properties, if any).]],
}
function F.substring.f(s, from, to)
  local size = lisp.check_vector_or_string(s)
  local f, t = validate_subarray(s, from, to, size)
  local res
  if lisp.stringp(s) then
    local from_byte = f ~= 0 and M.string_char_to_byte(s, f) or 0
    local to_byte = t == size and lisp.sbytes(s) or M.string_char_to_byte(s, t)
    res = alloc.make_specified_string(
      lisp.sdata(s):sub(from_byte + 1, to_byte),
      t - f,
      lisp.string_multibyte(s)
    )
    textprop.copy_textprop(
      lisp.make_fixnum(f),
      lisp.make_fixnum(t),
      s,
      lisp.make_fixnum(0),
      res,
      vars.Qnil
    )
  else
    error('TODO')
  end
  return res
end
F.string_equal = {
  'string-equal',
  2,
  2,
  0,
  [[Return t if two strings have identical contents.
Case is significant, but text properties are ignored.
Symbols are also allowed; their print names are used instead.

See also `string-equal-ignore-case'.]],
}
function F.string_equal.f(a, b)
  if lisp.symbolp(a) then
    a = lisp.symbol_name(a)
  end
  if lisp.symbolp(b) then
    b = lisp.symbol_name(b)
  end
  lisp.check_string(a)
  lisp.check_string(b)
  return lisp.sdata(a) == lisp.sdata(b) and vars.Qt or vars.Qnil
end
local function string_ascii_p(s)
  if lisp.string_multibyte(s) then
    return lisp.schars(s) == lisp.sbytes(s)
  end
  for c in lisp.sdata(s):gmatch('.') do
    if c:byte() > 127 then
      return false
    end
  end
  return true
end
local function string_byte_to_char(s, idx)
  local best_above = lisp.schars(s)
  local best_above_byte = lisp.sbytes(s)
  if best_above == best_above_byte then
    return idx
  end
  error('TODO')
end
F.string_search = {
  'string-search',
  2,
  3,
  0,
  [[Search for the string NEEDLE in the string HAYSTACK.
The return value is the position of the first occurrence of NEEDLE in
HAYSTACK, or nil if no match was found.

The optional START-POS argument says where to start searching in
HAYSTACK and defaults to zero (start at the beginning).
It must be between zero and the length of HAYSTACK, inclusive.

Case is always significant and text properties are ignored.]],
}
function F.string_search.f(needle, haystack, start_pos)
  lisp.check_string(needle)
  lisp.check_string(haystack)
  local start = 0
  if not lisp.nilp(start_pos) then
    lisp.check_fixnum(start_pos)
    start = lisp.fixnum(start_pos)
    if start < 0 or start > lisp.schars(haystack) then
      signal.args_out_of_range(haystack, start_pos)
    end
    start = M.string_char_to_byte(haystack, start)
  end
  local res
  if
    lisp.string_multibyte(haystack) == lisp.string_multibyte(needle)
    or (string_ascii_p(haystack) and string_ascii_p(needle))
  then
    res = lisp.sdata(haystack):find(lisp.sdata(needle), start + 1, true)
    if res then
      res = res - 1
    end
  else
    error('TODO')
  end
  if not res then
    return vars.Qnil
  end
  return lisp.make_fixnum(string_byte_to_char(haystack, res))
end
local require_nesting_list
F.require = {
  'require',
  1,
  3,
  0,
  [[If FEATURE is not already loaded, load it from FILENAME.
If FEATURE is not a member of the list `features', then the feature was
not yet loaded; so load it from file FILENAME.

If FILENAME is omitted, the printname of FEATURE is used as the file
name, and `load' is called to try to load the file by that name, after
appending the suffix `.elc', `.el', or the system-dependent suffix for
dynamic module files, in that order; but the function will not try to
load the file without any suffix.  See `get-load-suffixes' for the
complete list of suffixes.

To find the file, this function searches the directories in `load-path'.

If the optional third argument NOERROR is non-nil, then, if
the file is not found, the function returns nil instead of signaling
an error.  Normally the return value is FEATURE.

The normal messages issued by `load' at start and end of loading
FILENAME are suppressed.]],
}
function F.require.f(feature, filename, noerror)
  lisp.check_symbol(feature)
  local from_file = not lisp.nilp(vars.V.load_in_progress)
  if not from_file then
    if _G.vim_elisp_later then
      error('TODO')
    end
  end
  local tem
  if from_file then
    tem = vars.F.cons(vars.Qrequire, feature)
    if lisp.nilp(vars.F.member(tem, vars.V.current_load_list)) then
      lisp.loadhist_attach(tem)
    end
  end
  tem = vars.F.memq(feature, vars.V.features)
  if lisp.nilp(tem) then
    local count = specpdl.index()
    local old_require_nesting_list = require_nesting_list or vars.Qnil
    local nesting = 0
    while not lisp.nilp(old_require_nesting_list) do
      if not lisp.nilp(vars.F.equal(feature, lisp.xcar(old_require_nesting_list))) then
        nesting = nesting + 1
      end
      old_require_nesting_list = lisp.xcdr(old_require_nesting_list)
    end
    if nesting > 3 then
      signal.error("Recursive `require' for feature `%s'", lisp.sdata(lisp.symbol_name(feature)))
    end
    specpdl.record_unwind_protect(function()
      require_nesting_list = old_require_nesting_list
    end)
    require_nesting_list = vars.F.cons(feature, require_nesting_list)

    local eval = require 'elisp.eval'
    tem = eval.load_with_autoload_queue(
      lisp.nilp(filename) and lisp.symbol_name(feature) or filename,
      noerror,
      vars.Qt,
      vars.Qnil,
      lisp.nilp(filename) and vars.Qt or vars.Qnil
    )

    if lisp.nilp(tem) then
      return specpdl.unbind_to(count, vars.Qnil)
    end
    tem = vars.F.memq(feature, vars.V.features)
    if lisp.nilp(tem) then
      error('TODO')
    end
    feature = specpdl.unbind_to(count, feature)
  end
  return feature
end
F.secure_hash_algorithms = {
  'secure-hash-algorithms',
  0,
  0,
  0,
  [[Return a list of all the supported `secure-hash' algorithms.]],
}
function F.secure_hash_algorithms.f()
  return lisp.list(vars.Qmd5, vars.Qsha1, vars.Qsha224, vars.Qsha256, vars.Qsha384, vars.Qsha512)
end
F.identity = { 'identity', 1, 1, 0, [[Return the ARGUMENT unchanged.]] }
function F.identity.f(argument)
  return argument
end
---@param predicate vim.elisp.obj
---@param seq table<number,vim.elisp.obj|nil> (1-indexed)
---@param len number
local function tim_sort(predicate, seq, len)
  if len < 2 then
    return
  end
  if lisp.symbolp(predicate) then
    local fun = (predicate --[[@as vim.elisp._symbol]]).fn
    if lisp.symbolp(fun) then
      local data = require 'elisp.data'
      fun = data.indirect_function(fun)
    end
    if lisp.nilp(fun) or (lisp.consp(fun) and lisp.eq(lisp.xcar(fun), vars.Qautoload)) then
    else
      predicate = fun
    end
  end
  local newseq = {}
  for i = 1, len do
    if seq[i] == nil then
      seq[i] = vars.Qnil
    end
    newseq[i] = { seq[i], i }
  end
  table.sort(newseq, function(a, b)
    if not lisp.nilp(vars.F.funcall({ predicate, a[1], b[1] })) then
      return true
    end
    if not lisp.nilp(vars.F.funcall({ predicate, b[1], a[1] })) then
      return false
    end
    return a[2] < b[2]
  end)
  for k, v in ipairs(newseq) do
    seq[k] = v[1]
  end
end
F.sort = {
  'sort',
  2,
  2,
  0,
  [[Sort SEQ, stably, comparing elements using PREDICATE.
Returns the sorted sequence.  SEQ should be a list or vector.  SEQ is
modified by side effects.  PREDICATE is called with two elements of
SEQ, and should return non-nil if the first element should sort before
the second.]],
}
function F.sort.f(seq, predicate)
  if lisp.vectorp(seq) then
    tim_sort(predicate, (seq --[[@as vim.elisp._normal_vector]]).contents, lisp.asize(seq))
  elseif lisp.consp(seq) then
    local result = {}
    local _, tail = lisp.for_each_tail(seq, function(tail)
      table.insert(result, vars.F.car(tail))
    end)
    lisp.check_list_end(tail, seq)
    tim_sort(predicate, result, #result)
    lisp.for_each_tail(seq, function(tail_)
      lisp.xsetcar(tail_, table.remove(result, 1))
    end)
  else
    signal.wrong_type_argument(vars.Qlist_or_vector_p, seq)
  end
  return seq
end
F.string_lessp = {
  'string-lessp',
  2,
  2,
  0,
  [[Return non-nil if STRING1 is less than STRING2 in lexicographic order.
Case is significant.
Symbols are also allowed; their print names are used instead.]],
}
function F.string_lessp.f(string1, string2)
  if lisp.symbolp(string1) then
    string1 = lisp.symbol_name(string1)
  else
    lisp.check_string(string1)
  end
  if lisp.symbolp(string2) then
    string2 = lisp.symbol_name(string2)
  else
    lisp.check_string(string2)
  end
  if
    (lisp.schars(string1) == lisp.sbytes(string1) or not lisp.string_multibyte(string1))
    and (lisp.schars(string2) == lisp.sbytes(string2) or not lisp.string_multibyte(string2))
  then
    return lisp.sdata(string1) < lisp.sdata(string2) and vars.Qt or vars.Qnil
  else
    error('TODO')
  end
end
F.compare_strings = {
  'compare-strings',
  6,
  7,
  0,
  [[Compare the contents of two strings, converting to multibyte if needed.
The arguments START1, END1, START2, and END2, if non-nil, are
positions specifying which parts of STR1 or STR2 to compare.  In
string STR1, compare the part between START1 (inclusive) and END1
\(exclusive).  If START1 is nil, it defaults to 0, the beginning of
the string; if END1 is nil, it defaults to the length of the string.
Likewise, in string STR2, compare the part between START2 and END2.
Like in `substring', negative values are counted from the end.

The strings are compared by the numeric values of their characters.
For instance, STR1 is "less than" STR2 if its first differing
character has a smaller numeric value.  If IGNORE-CASE is non-nil,
characters are converted to upper-case before comparing them.  Unibyte
strings are converted to multibyte for comparison.

The value is t if the strings (or specified portions) match.
If string STR1 is less, the value is a negative number N;
  - 1 - N is the number of characters that match at the beginning.
If string STR1 is greater, the value is a positive number N;
  N - 1 is the number of characters that match at the beginning.]],
}
function F.compare_strings.f(str1, start1, end1, str2, start2, end2, ignore_case)
  lisp.check_string(str1)
  lisp.check_string(str2)

  if lisp.fixnump(end1) and lisp.schars(str1) < lisp.fixnum(end1) then
    end1 = lisp.make_fixnum(lisp.schars(str1))
  end
  if lisp.fixnump(end2) and lisp.schars(str2) < lisp.fixnum(end2) then
    end2 = lisp.make_fixnum(lisp.schars(str2))
  end
  local from1, to1 = validate_subarray(str1, start1, end1, lisp.schars(str1))
  local from2, to2 = validate_subarray(str2, start2, end2, lisp.schars(str2))
  local i1 = from1
  local i2 = from2
  local i1_bytes = string_byte_to_char(str1, i1)
  local i2_bytes = string_byte_to_char(str2, i2)

  while i1 < to1 and i2 < to2 do
    local c1, c2, len
    c1, len = chars.fetchstringcharadvance(str1, i1_bytes)
    i1_bytes = i1_bytes + len
    i1 = i1 + 1
    c2, len = chars.fetchstringcharadvance(str2, i2_bytes)
    i2_bytes = i2_bytes + len
    i2 = i2 + 1
    if c1 ~= c2 and not lisp.nilp(ignore_case) then
      c1 = lisp.fixnum(vars.F.upcase(lisp.make_fixnum(c1)))
      c2 = lisp.fixnum(vars.F.upcase(lisp.make_fixnum(c2)))
    end

    if c1 == c2 then
    elseif c1 < c2 then
      return lisp.make_fixnum(-i1 + from1)
    else
      return lisp.make_fixnum(i1 - from1)
    end
  end

  if i1 < to1 then
    return lisp.make_fixnum(i1 - from1 + 1)
  elseif i2 < to2 then
    return lisp.make_fixnum(-i1 + from1 - 1)
  end
  return vars.Qt
end

function M.init()
  vars.V.features = lisp.list(vars.Qemacs)
  vars.F.make_var_non_special(vars.Qfeatures)
end
function M.init_syms()
  vars.defsubr(F, 'append')
  vars.defsubr(F, 'assq')
  vars.defsubr(F, 'rassq')
  vars.defsubr(F, 'assoc')
  vars.defsubr(F, 'member')
  vars.defsubr(F, 'memq')
  vars.defsubr(F, 'nthcdr')
  vars.defsubr(F, 'nth')
  vars.defsubr(F, 'mapconcat')
  vars.defsubr(F, 'mapcar')
  vars.defsubr(F, 'mapc')
  vars.defsubr(F, 'maphash')
  vars.defsubr(F, 'nreverse')
  vars.defsubr(F, 'reverse')
  vars.defsubr(F, 'nconc')
  vars.defsubr(F, 'length')
  vars.defsubr(F, 'safe_length')
  vars.defsubr(F, 'equal')
  vars.defsubr(F, 'eql')
  vars.defsubr(F, 'plist_put')
  vars.defsubr(F, 'put')
  vars.defsubr(F, 'plist_get')
  vars.defsubr(F, 'get')
  vars.defsubr(F, 'featurep')
  vars.defsubr(F, 'provide')
  vars.defsubr(F, 'make_hash_table')
  vars.defsubr(F, 'puthash')
  vars.defsubr(F, 'gethash')
  vars.defsubr(F, 'hash_table_rehash_size')
  vars.defsubr(F, 'hash_table_rehash_threshold')
  vars.defsubr(F, 'delq')
  vars.defsubr(F, 'delete')
  vars.defsubr(F, 'concat')
  vars.defsubr(F, 'vconcat')
  vars.defsubr(F, 'copy_sequence')
  vars.defsubr(F, 'copy_alist')
  vars.defsubr(F, 'string_to_multibyte')
  vars.defsubr(F, 'string_as_unibyte')
  vars.defsubr(F, 'substring')
  vars.defsubr(F, 'string_equal')
  vars.defsubr(F, 'string_search')
  vars.defsubr(F, 'require')
  vars.defsubr(F, 'secure_hash_algorithms')
  vars.defsubr(F, 'identity')
  vars.defsubr(F, 'sort')
  vars.defsubr(F, 'string_lessp')
  vars.defsubr(F, 'compare_strings')

  vars.defvar_lisp(
    'features',
    'features',
    [[A list of symbols which are the features of the executing Emacs.
Used by `featurep' and `require', and altered by `provide'.]]
  )
  vars.defsym('Qfeatures', 'features')
  vars.defsym('Qsubfeatures', 'subfeatures')

  vars.defvar_lisp(
    'overriding_plist_environment',
    'overriding-plist-environment',
    [[An alist that overrides the plists of the symbols which it lists.
Used by the byte-compiler to apply `define-symbol-prop' during
compilation.]]
  )
  vars.V.overriding_plist_environment = vars.Qnil

  vars.defsym('Qhash_table_p', 'hash-table-p')
  vars.defsym('Qplistp', 'plistp')
  vars.defsym('Qprovide', 'provide')
  vars.defsym('Qrequire', 'require')
  vars.defsym('Qeq', 'eq')
  vars.defsym('Qeql', 'eql')
  vars.defsym('Qequal', 'equal')

  vars.defsym('Qkey', 'key')
  vars.defsym('Qvalue', 'value')
  vars.defsym('Qkey_or_value', 'key-or-value')
  vars.defsym('Qkey_and_value', 'key-and-value')

  vars.defsym('Qmd5', 'md5')
  vars.defsym('Qsha1', 'sha1')
  vars.defsym('Qsha224', 'sha224')
  vars.defsym('Qsha256', 'sha256')
  vars.defsym('Qsha384', 'sha384')
  vars.defsym('Qsha512', 'sha512')
end
return M
