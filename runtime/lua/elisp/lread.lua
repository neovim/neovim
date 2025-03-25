local chars = require 'elisp.chars'
local lisp = require 'elisp.lisp'
local b = require 'elisp.bytes'
local vars = require 'elisp.vars'
local signal = require 'elisp.signal'
local fns = require 'elisp.fns'
local specpdl = require 'elisp.specpdl'
local overflow = require 'elisp.overflow'
local alloc = require 'elisp.alloc'
local handler = require 'elisp.handler'
local caching = require 'elisp.caching'
local nvim = require 'elisp.nvim'

local M = {}

function M.init_once()
  vars.initial_obarray = alloc.make_vector(15121, 'zero')

  vars.defsym('Qnil', 'nil')
  vars.defsym('Qt', 't')
  vars.defsym('Qvariable_documentation', 'variable-documentation')
  vars.defsym('Qobarray_cache', 'obarray-cache')
  vars.defsym('Qbyte_boolean_vars', 'byte-boolean-vars')
end
---@param obarray vim.elisp.obj
---@return vim.elisp.obj
function M.obarray_check(obarray)
  if not lisp.vectorp(obarray) or lisp.asize(obarray) == 0 then
    error('TODO')
  end
  return obarray
end
---@param obarray vim.elisp.obj
---@param name string
---@return vim.elisp.obj|number
function M.lookup(obarray, name)
  obarray = M.obarray_check(obarray)
  local obsize = lisp.asize(obarray)
  local hash = fns.hash_string(name) % obsize
  local bucket = assert(lisp.aref(obarray, hash))
  if bucket == lisp.make_fixnum(0) then
  elseif not lisp.symbolp(bucket) then
    error('TODO')
  else
    local tail = bucket
    while true do
      if lisp.sdata(lisp.symbol_name(tail)) == name then
        return tail
      end
      tail = (tail --[[@as vim.elisp._symbol]]).next
      if tail == nil then
        break
      end
    end
  end
  return hash
end
---@param obarray vim.elisp.obj
---@param sym string
---@return vim.elisp.obj|number
---@return string?
function M.lookup_considering_shorthand(obarray, sym)
  local tail = vars.V.read_symbol_shorthands
  assert(tail == vars.Qnil, 'TODO')
  return M.lookup(obarray, sym), nil
end
---@param sym vim.elisp.obj
---@param obarray vim.elisp.obj
---@param bucket number
local function intern_sym(sym, obarray, bucket)
  assert(type(bucket) == 'number')
  local in_initial_obarray = vars.initial_obarray == obarray
  if in_initial_obarray then
    (sym --[[@as vim.elisp._symbol]]).interned = lisp.symbol_interned.interned_in_initial_obarray
  else
    (sym --[[@as vim.elisp._symbol]]).interned = lisp.symbol_interned.interned
  end
  if lisp.sref(lisp.symbol_name(sym), 0) == b ':' and in_initial_obarray then
    lisp.make_symbol_constant(sym)
    sym --[[@as vim.elisp._symbol]].redirect = lisp.symbol_redirect.plainval
    sym --[[@as vim.elisp._symbol]].declared_special = true
    lisp.set_symbol_val(sym --[[@as vim.elisp._symbol]], sym)
  end
  local old_sym = assert(lisp.aref(obarray, bucket))
  lisp.set_symbol_next(sym, lisp.symbolp(old_sym) and old_sym or nil)
  lisp.aset(obarray, bucket, sym)
  return sym
end
---@param sym vim.elisp.obj
---@param name string
function M.define_symbol(sym, name)
  local s = alloc.make_pure_c_string(name)
  alloc.init_symbol(sym, s)
  if name == 'unbound' then
    error("DEV: we don't use unbound, we use lua-nil instead")
  end
  local bucket = M.lookup(vars.initial_obarray, name)
  assert(type(bucket) == 'number')
  intern_sym(sym, vars.initial_obarray, bucket)
end
---@param name vim.elisp.obj
---@param obarray vim.elisp.obj
---@param bucket number
function M.intern_drive(name, obarray, bucket)
  lisp.set_symbol_val(vars.Qobarray_cache --[[@as vim.elisp._symbol]], vars.Qnil)
  return intern_sym(alloc.make_symbol(name), obarray, bucket)
end
local has_inited_syms = false
---@param name string
---@return vim.elisp.obj
function M.intern_c_string(name)
  local obarray
  if has_inited_syms then
    obarray = M.obarray_check(vars.V.obarray)
  else
    obarray = vars.initial_obarray
  end
  local tem = M.lookup(obarray, name)
  if type(tem) == 'number' then
    local s = alloc.make_string(name)
    tem = M.intern_drive(s, obarray, tem)
  end
  return tem
end
---@param name string
---@return vim.elisp.obj
function M.intern(name)
  local obarray = M.obarray_check(vars.V.obarray)
  local tem = M.lookup(obarray, name)
  if type(tem) == 'number' then
    local s = alloc.make_unibyte_string(name)
    tem = M.intern_drive(s, obarray, tem)
  end
  return tem
end
---@param obarray vim.elisp.obj
---@param fn fun(sym:vim.elisp.obj):nil
function M.map_obarray(obarray, fn)
  lisp.check_vector(obarray)
  for i = lisp.asize(obarray) - 1, 0, -1 do
    local tail = lisp.aref(obarray, i)
    if lisp.symbolp(tail) then
      while true do
        fn(tail)
        if
          (tail --[[@as vim.elisp._symbol]]).next == nil
        then
          break
        end
        tail = (tail --[[@as vim.elisp._symbol]]).next
      end
    end
  end
end

local function end_of_file_error()
  if lisp.stringp(vars.V.load_true_file_name) then
    signal.xsignal(vars.Qend_of_file, vars.V.load_true_file_name)
  end
  signal.xsignal(vars.Qend_of_file)
end
---@param s string
---@param readcharfun vim.elisp.lread.readcharfun
local function invalid_syntax(s, readcharfun)
  if lisp.bufferp(readcharfun.obj) then
    error('TODO')
  else
    signal.xsignal(vars.Qinvalid_read_syntax, alloc.make_string(s))
  end
end
---@param base number
---@param readcharfun vim.elisp.lread.readcharfun
local function invalid_radix_integer(base, readcharfun)
  local buf = ('integer, radix %d'):format(base)
  invalid_syntax(buf, readcharfun)
end

---@class vim.elisp.lread.readcharfun
---@field ismultibyte boolean
---@field idx number
---@field read fun():number
---@field unread fun(c:number?)
---@field obj vim.elisp.obj
---@field read_object_map table<number,vim.elisp.obj>

---@param obj vim.elisp.obj
---@param idx number?
---@param end_ number?
---@return vim.elisp.lread.readcharfun
function M.make_readcharfun(obj, idx, end_)
  assert(end_ == nil, 'TODO')
  if lisp.stringp(obj) then
    local readcharfun
    ---@type vim.elisp.lread.readcharfun
    assert(not lisp.string_multibyte(obj), 'TODO')
    local len = lisp.sbytes(obj)
    ---@type vim.elisp.lread.readcharfun
    readcharfun = {
      ismultibyte = lisp.string_multibyte(obj),
      obj = obj,
      idx = (idx or 0) - 1,
      read = function()
        readcharfun.idx = readcharfun.idx + 1
        if len <= readcharfun.idx then
          return -1
        end
        return lisp.sref(obj, readcharfun.idx)
      end,
      unread = function()
        readcharfun.idx = readcharfun.idx - 1
      end,
      read_object_map = {},
    }
    return readcharfun
  end
  error('TODO')
end
---@param readcharfun vim.elisp.lread.readcharfun
function M.skip_space_and_comment(readcharfun)
  while true do
    local c = readcharfun.read()
    if c == b ';' then
      while c ~= b '\n' and c >= 0 do
        c = readcharfun.read()
      end
    end
    if c < 0 then
      end_of_file_error()
    end
    if c > 32 and c ~= b.no_break_space then
      readcharfun.unread()
      return
    end
  end
end
---@param readcharfun vim.elisp.lread.readcharfun
---@param base number
---@return vim.elisp.obj
function M.read_integer(readcharfun, base)
  local str_number = ''
  local c = readcharfun.read()
  local valid = -1
  if c == b '+' or c == b '-' then
    str_number = str_number .. (c == b '-' and '-' or '+')
    c = readcharfun.read()
  end
  if c == b '0' then
    valid = 1
    while c == b '0' do
      c = readcharfun.read()
    end
  end
  while true do
    local digit = M.digit_to_number(c, base)
    if digit == -1 then
      valid = 0
    elseif digit < 0 then
      break
    end
    if valid < 0 then
      valid = 1
    end
    str_number = str_number .. string.char(c)
    c = readcharfun.read()
  end
  readcharfun.unread()
  if valid ~= 1 then
    invalid_radix_integer(base, readcharfun)
  end
  return assert((M.string_to_number(str_number, base)))
end
---@param readcharfun vim.elisp.lread.readcharfun
---@return number
function M.read_escape(readcharfun)
  local c = readcharfun.read()
  local function mod_key(mod)
    c = readcharfun.read()
    if c ~= b '-' then
      signal.error('Invalid escape character syntax')
    end
    c = readcharfun.read()
    if c == b '\\' then
      c = M.read_escape(readcharfun)
    end
    return bit.bor(mod, c)
  end
  if c == -1 then
    end_of_file_error()
    error('unreachable')
  elseif c == b 'a' then
    return b '\a'
  elseif c == b 'b' then
    return b '\b'
  elseif c == b 'd' then
    return 127
  elseif c == b 'e' then
    return 27
  elseif c == b 'f' then
    return b '\f'
  elseif c == b 'n' then
    return b '\n'
  elseif c == b 'r' then
    return b '\r'
  elseif c == b 't' then
    return b '\t'
  elseif c == b 'v' then
    return b '\v'
  elseif c == b '\n' then
    signal.error('Invalid escape character syntax')
    error('unreachable')
  elseif c == b 'M' then
    return mod_key(b.CHAR_META)
  elseif c == b 'S' then
    return mod_key(b.CHAR_SHIFT)
  elseif c == b 'H' then
    return mod_key(b.CHAR_HYPER)
  elseif c == b 'A' then
    return mod_key(b.CHAR_ALT)
  elseif c == b 's' then
    c = readcharfun.read()
    if c ~= b '-' then
      readcharfun.unread()
      return b ' '
    end
    readcharfun.unread()
    return mod_key(b.CHAR_SUPER)
  elseif c == b '^' or c == b 'C' then
    if c == b 'C' then
      c = readcharfun.read()
      if c ~= b '-' then
        signal.error('Invalid escape character syntax')
      end
    end
    c = readcharfun.read()
    if c == b '\\' then
      c = M.read_escape(readcharfun)
    end
    if bit.band(c, bit.bnot(b.CHAR_MODIFIER_MASK)) == b '?' then
      return bit.bor(127, bit.band(c, b.CHAR_MODIFIER_MASK))
    elseif not chars.asciicharp(bit.band(c, bit.bnot(b.CHAR_MODIFIER_MASK))) then
      return bit.bor(c, b.CHAR_CTL)
    elseif bit.band(c, 95) >= 65 and bit.band(c, 95) <= 90 then
      return bit.band(c, bit.bor(31, bit.bnot(127)))
    elseif bit.band(c, 127) >= 64 and bit.band(c, 127) <= 95 then
      return bit.band(c, bit.bor(31, bit.bnot(127)))
    else
      return bit.band(c, b.CHAR_CTL)
    end
  elseif string.char(c):match '[0-7]' then
    local i = c - b '0'
    for _ = 1, 2 do
      c = readcharfun.read()
      if string.char(c):match '[0-7]' then
        i = i * 8 + c - b '0'
      else
        readcharfun.unread()
        break
      end
    end
    if i >= 0x80 and i < 0x100 then
      i = chars.byte8tochar(i)
    end
    return i
  elseif c == b 'x' then
    local i = 0
    local count = 0
    while true do
      c = readcharfun.read()
      local digit = chars.charhexdigit(c)
      if digit < 0 then
        readcharfun.unread()
        break
      end
      i = i * 16 + digit
      if bit.bor(b.CHAR_META, b.CHAR_META - 1) < i then
        signal.error('Hex character out of range: \\x%x...', i)
      end
      count = count + (count < 3 and 1 or 0)
    end
    if count < 3 and i >= 0x80 then
      return chars.byte8tochar(i)
    end
    return i
  elseif c == b 'U' then
    error('TODO')
  elseif c == b 'u' then
    error('TODO')
  elseif c == b 'N' then
    error('TODO')
  else
    return c
  end
end
---@param readcharfun vim.elisp.lread.readcharfun
function M.read_string_literal(readcharfun)
  local c = readcharfun.read()
  local s = ''
  local force_singlebyte = false
  local force_multibyte = false
  if readcharfun.ismultibyte then
    error('TODO')
  end
  while c ~= -1 and c ~= b '"' do
    if c == b '\\' then
      c = readcharfun.read()
      if c == b '\n' or c == b ' ' then
        goto continue
      elseif c == b 's' then
        c = b ' '
      else
        readcharfun.unread()
        c = M.read_escape(readcharfun)
      end
      local mods = bit.band(c, b.CHAR_MODIFIER_MASK)
      c = bit.band(c, bit.bnot(b.CHAR_MODIFIER_MASK))
      if chars.charbyte8p(c) then
        force_singlebyte = true
      elseif not chars.asciicharp(c) then
        force_multibyte = true
      else
        if mods == b.CHAR_CTL and c == b ' ' then
          c = 0
          mods = 0
        end
        if bit.band(mods, b.CHAR_SHIFT) > 0 then
          error('TODO')
        end
        if bit.band(mods, b.CHAR_META) > 0 then
          mods = bit.band(mods, bit.bnot(b.CHAR_META))
          c = chars.byte8tochar(bit.bor(c, 0x80))
          force_singlebyte = true
        end
      end
      if mods > 0 then
        invalid_syntax('Invalid modifier in string', readcharfun)
      end
      s = s .. chars.charstring(c)
    else
      s = s .. string.char(c)
      if chars.charbyte8p(c) then
        force_singlebyte = true
      elseif not chars.asciicharp(c) then
        force_multibyte = true
      end
    end
    ::continue::
    c = readcharfun.read()
  end
  if c < 0 then
    end_of_file_error()
  end
  if not force_multibyte and force_singlebyte then
    s = chars.strasunibyte(s)
  end
  local obj = alloc.make_specified_string(s, -1, force_multibyte)
  return obj --TODO: may need unbind_to
end
---@param digit number
---@param base number
---@return number
function M.digit_to_number(digit, base)
  if b '0' <= digit and digit <= b '9' then
    digit = digit - b '0'
  elseif b 'a' <= digit and digit <= b 'z' then
    digit = digit - b 'a' + 10
  elseif b 'A' <= digit and digit <= b 'Z' then
    digit = digit - b 'A' + 10
  else
    return -2
  end
  return digit < base and digit or -1
end
---@param s string
---@param base number
---@return vim.elisp.obj?
---@return boolean whether the whole `s` was parsed, or only the beginning
function M.string_to_number(s, base)
  if _G.vim_elisp_later then
    error('TODO: create own implementation of number parser')
  end
  local num = tonumber(s == '' and '0' or s, base)
  if not num then
    return nil, false
  end
  if num == math.huge or num == -math.huge or math.floor(num) ~= num or num == tonumber('nan') then
    return alloc.make_float(num), false
  end
  return lisp.make_fixnum(num), false
end
---@param readcharfun vim.elisp.lread.readcharfun
---@return vim.elisp.obj
function M.read_char_literal(readcharfun)
  local ch = readcharfun.read()
  if ch < 0 then
    end_of_file_error()
  end
  if ch == b ' ' or ch == b '\t' then
    return lisp.make_fixnum(ch)
  end
  if ch == b '(' or ch == b ')' or ch == b '[' or ch == b ']' or ch == b '"' or ch == b ';' then
    error('TODO')
  end
  if ch == b '\\' then
    ch = M.read_escape(readcharfun)
  end
  local mods = bit.band(ch, b.CHAR_MODIFIER_MASK)
  ch = bit.band(ch, bit.bnot(b.CHAR_MODIFIER_MASK))
  if chars.charbyte8p(ch) then
    ch = chars.chartobyte8(ch)
  end
  ch = bit.bor(ch, mods)
  local nch = readcharfun.read()
  if _G.vim_elisp_later then
    error('TODO: remove once multibyte read is implemented')
  elseif nch >= 128 then
    local s = string.char(ch)
    while nch >= 128 do
      s = s .. string.char(nch)
      nch = readcharfun.read()
    end
    ch = chars.stringchar(s)
  end
  readcharfun.unread()
  if nch <= 32 or nch == b.no_break_space or string.char(nch):match '[]"\';()[#?`,.]' then
    return lisp.make_fixnum(ch)
  end
  invalid_syntax('?', readcharfun)
  error('unreachable')
end
--- Important, DO NOT readcharfun.unread() before calling this function
---@param readcharfun vim.elisp.lread.readcharfun
---@param uninterned_symbol boolean
---@param skip_shorthand boolean
---@param locate_syms boolean
---@return vim.elisp.obj
function M.read_symbol(readcharfun, uninterned_symbol, skip_shorthand, locate_syms)
  assert(not locate_syms, 'TODO')
  readcharfun.unread()
  local c = readcharfun.read()
  local sym = ''
  local quoted = false
  while c > 32 and c ~= b.no_break_space and not string.char(c):match '[]["\';#()`,]' do
    if c == b '\\' then
      c = readcharfun.read()
      quoted = true
    end
    assert(not readcharfun.ismultibyte, 'TODO')
    sym = sym .. string.char(c)
    c = readcharfun.read()
  end
  readcharfun.unread()
  local c0 = sym:sub(1, 1)
  if
    (c0:match '%d' or c0 == '-' or c0 == '+' or c0 == '.')
    and not quoted
    and not uninterned_symbol
    and not skip_shorthand
  then
    local result, extra = M.string_to_number(sym, 10)
    if result and not extra then
      return result
    end
  end
  if uninterned_symbol then
    local name = alloc.make_specified_string(sym, -1, readcharfun.ismultibyte)
    if locate_syms then
      error('TODO')
    end
    return vars.F.make_symbol(name)
  end
  local obarray = M.obarray_check(vars.V.obarray)
  local found, longhand
  if skip_shorthand then
    error('TODO')
  else
    found, longhand = M.lookup_considering_shorthand(obarray, sym)
  end
  if
    type(found) ~= 'number' and lisp.baresymbolp(found --[[@as vim.elisp.obj]])
  then
  elseif longhand then
    error('TODO')
  else
    assert(type(found) == 'number')
    local name = alloc.make_specified_string(sym, -1, readcharfun.ismultibyte)
    found = M.intern_drive(name, obarray, found)
  end
  if locate_syms then
    error('TODO')
  end
  return found
end
function M.hash_table_from_plist(plist)
  local params = {}
  local function addparam(name)
    local val = fns.plist_get(plist, vars['Q' .. name])
    if not lisp.nilp(val) then
      table.insert(params, vars['QC' .. name])
      table.insert(params, val)
    end
  end
  addparam('size')
  addparam('test')
  addparam('weakness')
  addparam('rehash_size')
  addparam('rehash_threshold')
  addparam('purecopy')
  local data = fns.plist_get(plist, vars.Qdata)
  local ht = vars.F.make_hash_table(params)
  local last = data

  local has_visited = {}
  while lisp.consp(data) do
    local key = lisp.xcar(data)
    data = lisp.xcdr(data)
    if not lisp.consp(data) then
      break
    end
    local val = lisp.xcar(data)
    last = lisp.xcdr(data)
    vars.F.puthash(key, val, ht)
    data = lisp.xcdr(data)
    if has_visited[data] then
      data = vars.Qnil
    end
    has_visited[data] = true
  end
  if not lisp.nilp(last) then
    signal.error('Hash table data is not a list of even length')
  end
  return ht
end
local function fromfilep(readcharfun)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return false
end
local function skip_dyn_eof(readcharfun)
  if fromfilep(readcharfun) then
    error('TODO')
  else
    while readcharfun.read() >= 0 do
    end
  end
end
local function skip_dyn_bytes(readcharfun, n)
  if fromfilep(readcharfun) then
    error('TODO')
  else
    local c = readcharfun.read()
    while c >= 0 and c ~= b '\31' do
      c = readcharfun.read()
    end
  end
end
local function skip_lazy_string(readcharfun)
  ---@type number?
  local nskip = 0
  local digits = 0
  while true do
    local c = readcharfun.read()
    if c < b '0' or c > b '9' then
      if nskip > 0 then
        nskip = nskip - 1
      else
        readcharfun.unread()
      end
      break
    end
    nskip = overflow.mul(nskip, 10)
    nskip = overflow.add(nskip, c - b '0')
    if not nskip then
      invalid_syntax('#@', readcharfun)
    end
    digits = digits + 1
    if digits == 2 and nskip == 0 then
      skip_dyn_eof(readcharfun)
      return false
    end
  end
  if vars.V.load_force_doc_strings and fromfilep(readcharfun) then
    error('TODO')
  else
    skip_dyn_bytes(readcharfun, nskip)
  end
  return true
end
---@return vim.elisp.obj
function M.bytecode_from_list(elems, readcharfun)
  local cidx = lisp.compiled_idx
  local size = #elems
  if
    not (
      size >= cidx.stack_depth
      and size <= cidx.interactive
      and (lisp.fixnump(elems[cidx.arglist]) or lisp.consp(elems[cidx.arglist]) or lisp.nilp(
        elems[cidx.arglist]
      ))
      and lisp.fixnatp(elems[cidx.stack_depth])
    )
  then
    vim.print(lisp.fixnatp(elems[cidx.stack_depth]))
    invalid_syntax('Invalid byte-code object', readcharfun)
  end
  if
    vars.V.load_force_doc_strings
    and lisp.nilp(elems[cidx.constants])
    and lisp.stringp(elems[cidx.bytecode])
  then
    error('TODO')
  end
  if
    not (
      (lisp.stringp(elems[cidx.bytecode]) and lisp.vectorp(elems[cidx.constants]))
      or lisp.consp(elems[cidx.bytecode])
    )
  then
    invalid_syntax('Invalid byte-code object', readcharfun)
  end
  if lisp.stringp(elems[cidx.bytecode]) then
    if lisp.string_multibyte(elems[cidx.bytecode]) then
      elems[cidx.bytecode] = vars.F.string_as_unibyte(elems[cidx.bytecode])
    end
  end
  ---@type vim.elisp._compiled
  local vec = {
    size = size,
    contents = elems,
  }
  return lisp.make_vectorlike_ptr(vec, lisp.pvec.compiled)
end
---@return vim.elisp.obj
function M.sub_char_table_from_list(elems)
  if #elems < 2 then
    signal.error('Invalid size of sub-char-table')
  elseif not lisp.ranged_fixnump(1, elems[1], 3) then
    signal.error('Invalid depth in sub-char-table')
  end
  local depth = lisp.fixnum(elems[1])
  local chartab = require 'elisp.chartab'
  if chartab.chartab_size[depth + 1] ~= #elems - 2 then
    signal.error('Invalid size in sub-char-table')
  end
  table.remove(elems, 1)
  if not lisp.ranged_fixnump(0, elems[1], b.MAX_CHAR) then
    signal.error('Invalid minimum character in sub-char-table')
  end
  local min_char = lisp.fixnum(elems[1])
  table.remove(elems, 1)
  local tbl = chartab.make_subchartable(depth, min_char, 'nil')
  for i = 1, #elems do
    (tbl --[[@as vim.elisp._sub_char_table]]).contents[i] = elems[i]
  end
  return tbl
end
---@return vim.elisp.obj
function M.char_table_from_list(elems, readcharfun)
  local chartab = require 'elisp.chartab'
  if #elems < 4 + chartab.chartab_size[1] then
    invalid_syntax('Invalid size char-table', readcharfun)
  end
  local obj = alloc.make_vector(chartab.chartab_size[1], 'nil') --[[@as vim.elisp._char_table]]
  obj.default = table.remove(elems, 1)
  obj.parent = table.remove(elems, 1)
  obj.purpose = table.remove(elems, 1)
  obj.ascii = table.remove(elems, 1)
  for i = 1, chartab.chartab_size[1] do
    (obj --[[@as vim.elisp._char_table]]).contents[i] = table.remove(elems, 1)
  end
  obj.extras = alloc.make_vector(#elems, 'nil')
  for i = 0, #elems - 1 do
    lisp.aset(obj.extras, i, elems[i + 1])
  end
  return lisp.make_vectorlike_ptr(obj, lisp.pvec.char_table)
end
---@return vim.elisp.obj
local function string_props_from_list(elems, readcharfun)
  if #elems < 1 or not lisp.stringp(elems[1]) then
    invalid_syntax('#', readcharfun)
  end
  local obj = table.remove(elems, 1)
  while #elems > 0 do
    local beg = table.remove(elems, 1)
    if #elems < 1 then
      invalid_syntax('Invalid string property list', readcharfun)
    end
    local end_ = table.remove(elems, 1)
    if #elems < 1 then
      invalid_syntax('Invalid string property list', readcharfun)
    end
    local plist = table.remove(elems, 1)
    vars.F.set_text_properties(beg, end_, plist, obj)
  end
  return obj
end
---@param readcharfun vim.elisp.lread.readcharfun
---@param locate_syms boolean
---@return vim.elisp.obj
function M.read0(readcharfun, locate_syms)
  assert(not locate_syms, 'TODO')
  local obj = nil
  local stack = {}
  ::read_obj::
  local c = readcharfun.read()
  if c < 0 then
    end_of_file_error()
    error('unreachable')
  elseif c == b '(' then
    table.insert(stack, { t = 'list_start' })
    goto read_obj
  elseif c == b ')' then
    local t = stack[#stack]
    if not t then
      invalid_syntax(')', readcharfun)
      error('unreachable')
    elseif t.t == 'list_start' then
      table.remove(stack)
      obj = vars.Qnil
    elseif t.t == 'list' then
      table.remove(stack)
      obj = t.head
    elseif t.t == 'record' then
      t = table.remove(stack)
      locate_syms = t.old_locate_syms
      if #t.elems == 0 then
        invalid_syntax('#s', readcharfun)
      end
      if t.elems[1] == vars.Qhash_table then
        obj = M.hash_table_from_plist(lisp.xcdr(lisp.list(unpack(t.elems))))
      else
        error('TODO')
      end
    elseif t.t == 'string_props' then
      t = table.remove(stack)
      locate_syms = t.old_locate_syms
      obj = string_props_from_list(t.elems, readcharfun)
    else
      error('TODO')
    end
  elseif c == b '[' then
    table.insert(stack, { t = 'vector', elems = {}, old_locate_syms = locate_syms })
    goto read_obj
  elseif c == b ']' then
    local t = stack[#stack]
    if not t then
      invalid_syntax(']', readcharfun)
      error('unreachable')
    elseif t.t == 'vector' then
      table.remove(stack)
      locate_syms = t.old_locate_syms
      obj = alloc.make_vector(#t.elems, 'nil')
      for i = 1, #t.elems do
        (obj --[[@as vim.elisp._normal_vector]]).contents[i] = t.elems[i]
      end
    elseif t.t == 'byte_code' then
      table.remove(stack)
      locate_syms = t.old_locate_syms
      obj = M.bytecode_from_list(t.elems, readcharfun)
    elseif t.t == 'char_table' then
      table.remove(stack)
      locate_syms = t.old_locate_syms
      obj = M.char_table_from_list(t.elems, readcharfun)
    elseif t.t == 'sub_char_table' then
      table.remove(stack)
      locate_syms = t.old_locate_syms
      obj = M.sub_char_table_from_list(t.elems)
    else
      error('TODO')
    end
  elseif c == b '#' then
    local ch = readcharfun.read()
    if ch == b "'" then
      table.insert(stack, { t = 'special', sym = vars.Qfunction })
      goto read_obj
    elseif ch == b 'x' or ch == b 'X' then
      obj = M.read_integer(readcharfun, 16)
    elseif ch == b 'o' or ch == b 'O' then
      obj = M.read_integer(readcharfun, 8)
    elseif ch == b 's' then
      ch = readcharfun.read()
      if ch ~= b '(' then
        readcharfun.unread(ch)
        invalid_syntax('%s', readcharfun)
      end
      table.insert(stack, {
        t = 'record',
        elems = {},
        old_locate_syms = locate_syms,
      })
      locate_syms = false
      goto read_obj
    elseif ch == b '@' then
      if skip_lazy_string(readcharfun) then
        goto read_obj
      end
      obj = vars.Qnil
    elseif ch == b '[' then
      table.insert(stack, {
        t = 'byte_code',
        elems = {},
        old_locate_syms = locate_syms,
      })
      locate_syms = false
      goto read_obj
    elseif ch == b '$' then
      obj = vars.V.load_file_name
    elseif ch >= b '0' and ch <= b '9' then
      local n = ch - b '0'
      while true do
        c = readcharfun.read()
        if c < b '0' or c > b '9' then
          break
        end
        n = overflow.add(overflow.mul(n, 10), c - b '0')
        if n == nil then
          invalid_syntax('#', readcharfun)
          error('unreachable')
        end
      end
      if c == b 'r' or c == b 'R' then
        error('TODO')
      elseif not lisp.nilp(vars.V.read_circle) then
        if c == b '=' then
          local placeholder = vars.F.cons(vars.Qnil, vars.Qnil)
          readcharfun.read_object_map[n] = placeholder
          table.insert(stack, {
            t = 'numbered',
            number = n,
            placeholder = placeholder,
          })
          goto read_obj
        elseif c == b '#' then
          obj = readcharfun.read_object_map[n]
          if not obj then
            invalid_syntax('#', readcharfun)
          end
        else
          invalid_syntax('#', readcharfun)
          error('unreachable')
        end
      else
        invalid_syntax('#', readcharfun)
        error('unreachable')
      end
    elseif ch == b '#' then
      obj = vars.F.intern(alloc.make_pure_c_string(''), vars.Qnil)
    elseif ch == b '^' then
      ch = readcharfun.read()
      if ch == b '^' then
        ch = readcharfun.read()
        if ch == b '[' then
          table.insert(stack, {
            t = 'sub_char_table',
            elems = {},
            old_locate_syms = locate_syms,
          })
          locate_syms = false
          goto read_obj
        else
          invalid_syntax('#^^', readcharfun)
        end
      elseif ch == b '[' then
        table.insert(stack, {
          t = 'char_table',
          elems = {},
          old_locate_syms = locate_syms,
        })
        locate_syms = false
        goto read_obj
      else
        invalid_syntax('#^', readcharfun)
      end
      error('unreachable')
    elseif ch == b ':' then
      c = readcharfun.read()
      if c <= 32 or c == b.no_break_space or string.char(c):match '[]"\';#()[`,]' then
        readcharfun.unread()
        obj = vars.F.make_symbol(alloc.make_pure_c_string(''))
      else
        obj = M.read_symbol(readcharfun, true, false, locate_syms)
      end
    elseif ch == b '(' then
      table.insert(stack, {
        t = 'string_props',
        elems = {},
        old_locate_syms = locate_syms,
      })
      locate_syms = false
      goto read_obj
    else
      error('TODO')
    end
  elseif c == b '?' then
    obj = M.read_char_literal(readcharfun)
  elseif c == b '"' then
    obj = M.read_string_literal(readcharfun)
  elseif c == b "'" then
    table.insert(stack, { t = 'special', sym = vars.Qquote })
    goto read_obj
  elseif c == b '`' then
    table.insert(stack, { t = 'special', sym = vars.Qbackquote })
    goto read_obj
  elseif c == b ',' then
    local ch = readcharfun.read()
    local sym
    if ch == b '@' then
      sym = vars.Qcomma_at
    else
      if ch >= 0 then
        readcharfun.unread()
      end
      sym = vars.Qcomma
    end
    table.insert(stack, { t = 'special', sym = sym })
    goto read_obj
  elseif c == b ';' then
    while true do
      c = readcharfun.read()
      if c == b '\n' or c == -1 then
        break
      end
    end
    goto read_obj
  elseif c == b '.' then
    local nch = readcharfun.read()
    readcharfun.unread()
    if nch <= 32 or nch == b.no_break_space or string.char(nch):match '["\';([#?`,]' then
      local t = stack[#stack]
      if t and t.t == 'list' then
        t.t = 'list_dot'
        goto read_obj
      end
      invalid_syntax('.', readcharfun)
    end
    if c <= 32 or c == b.no_break_space then
      goto read_obj
    end
    obj = M.read_symbol(readcharfun, false, false, locate_syms)
  else
    if c <= 32 or c == b.no_break_space then
      goto read_obj
    end
    obj = M.read_symbol(readcharfun, false, false, locate_syms)
  end
  while #stack > 0 do
    local t = stack[#stack]
    if t.t == 'list_start' then
      t.t = 'list'
      t.head = alloc.cons(obj, vars.Qnil)
      t.tail = t.head
      goto read_obj
    elseif t.t == 'list' then
      local new_tail = alloc.cons(obj, vars.Qnil)
      lisp.xsetcdr(t.tail, new_tail)
      t.tail = new_tail
      goto read_obj
    elseif t.t == 'special' then
      table.remove(stack)
      obj = alloc.cons(t.sym, alloc.cons(obj, vars.Qnil))
    elseif
      t.t == 'vector'
      or t.t == 'record'
      or t.t == 'byte_code'
      or t.t == 'char_table'
      or t.t == 'sub_char_table'
      or t.t == 'string_props'
    then
      table.insert(t.elems, obj)
      goto read_obj
    elseif t.t == 'list_dot' then
      M.skip_space_and_comment(readcharfun)
      local ch = readcharfun.read()
      if ch ~= b ')' then
        invalid_syntax('expected )', readcharfun)
      end
      lisp.xsetcdr(t.tail, obj)
      table.remove(stack)
      obj = t.head
      if not lisp.nilp(vars.V.load_force_doc_strings) then
        error('TODO')
      end
    elseif t.t == 'numbered' then
      table.remove(stack)
      local placeholder = t.placeholder
      if lisp.consp(obj) then
        if obj == placeholder then
          invalid_syntax('nonsensical self-reference', readcharfun)
        end
        vars.F.setcar(placeholder, lisp.xcar(obj))
        vars.F.setcdr(placeholder, lisp.xcdr(obj))
        readcharfun.read_object_map[t.number] = placeholder
        obj = placeholder
      else
        vars.F.lread__substitute_object_in_subtree(obj, placeholder, vars.Qt)
        readcharfun.read_object_map[t.number] = obj
      end
    else
      error('TODO')
    end
  end
  return obj
end

---@class vim.elisp.lread.objlist
---@field [number] vim.elisp.obj

---@param s string
---@return vim.elisp.lread.objlist
function M.full_read_lua_string(s)
  if _G.vim_elisp_later then
    --local readcharfun=M.make_readcharfun(str.make(s,(s:match('[\x80-\xff]') and true or false)))
    error('TODO')
    error('TODO: remove jit.on and jit.off')
  end
  local readcharfun = M.make_readcharfun(alloc.make_string(s))
  local ret = {}
  local jit_on
  if _G.vim_elisp_optimize_jit then
    jit_on = jit.status()
    --We may turn off JIT because it's faster, but this function runs faster with it on
    jit.on()
  end
  while true do
    local c = readcharfun.read()
    if c == b ';' then
      while true do
        c = readcharfun.read()
        if c == b '\n' or c == -1 then
          break
        end
      end
      goto read_next
    end
    if c < 0 then
      break
    end
    if
      c == b ' '
      or c == b '\n'
      or c == b '\t'
      or c == b '\r'
      or c == b '\f'
      or c == b.no_break_space
    then
      goto read_next
    end
    readcharfun.unread()
    table.insert(ret, M.read0(readcharfun, false))
    ::read_next::
  end
  if _G.vim_elisp_optimize_jit and not jit_on then
    jit.off()
  end
  return ret
end
function M.save_match_data_load(file, noerror, nomessage, nosuffix, mustsuffix)
  local count = specpdl.index()
  local matchdata = vars.F.match_data(vars.Qnil, vars.Qnil, vars.Qnil)
  specpdl.record_unwind_protect(function()
    vars.F.set_match_data(matchdata, vars.Qt)
  end)
  local result = vars.F.load(file, noerror, nomessage, nosuffix, mustsuffix)
  return specpdl.unbind_to(count, result)
end

---@type vim.elisp.F
local F = {}
local function suffix_p(s, suffix)
  return lisp.sdata(s):sub(-#suffix) == suffix
end
local function complete_filename_p(pathname)
  if lisp.IS_DIRECTORY_SEP(lisp.sref(pathname, 0)) then
    return true
  end
  if lisp.schars(pathname) < 2 then
    return false
  end
  if
    lisp.IS_DIRECTORY_SEP(lisp.sref(pathname, 1))
    and lisp.IS_DIRECTORY_SEP(lisp.sref(pathname, 2))
  then
    return true
  end
  return false
end
---@param path vim.elisp.obj
---@param s vim.elisp.obj
---@param suffixes vim.elisp.obj
---@param storep table?
---@param predicate vim.elisp.obj
---@param newer boolean
---@param no_native boolean
---@return -1|file*
function M.openp(path, s, suffixes, storep, predicate, newer, no_native)
  local _ = no_native
  ---@type -1|file*
  local save_fd = -1
  local save_mtime = -math.huge
  local save_string
  lisp.check_string(s)
  lisp.for_each_tail_safe(suffixes, function(tail)
    lisp.check_string_car(tail)
  end)
  if storep then
    storep[1] = vars.Qnil
  end
  local absolute = complete_filename_p(s)
  local just_use_str = lisp.list(vars.Qnil)
  if lisp.nilp(path) then
    path = just_use_str
  end
  local ret = lisp.for_each_tail_safe(path, function(p)
    local filename
    if lisp.eq(p, just_use_str) then
      filename = s
    else
      filename = vars.F.expand_file_name(s, lisp.xcar(p))
    end
    if not complete_filename_p(filename) then
      filename =
        vars.F.expand_file_name(filename, nvim.bvar(true, require 'elisp.buffer'.bvar.directory))
      if not complete_filename_p(filename) then
        return 'continue'
      end
    end
    local ofn = lisp.sdata(filename):gsub('^:/', '')
    local ret = lisp.for_each_tail_safe(
      lisp.nilp(suffixes) and lisp.list(alloc.make_unibyte_string('')) or suffixes,
      function(tail)
        local suffix = lisp.xcar(tail)
        local fn = ofn .. lisp.sdata(suffix)
        local fstr
        if not lisp.string_intervals(suffix) and not lisp.string_intervals(filename) then
          fstr = alloc.make_unibyte_string(fn)
        else
          error('TODO')
        end
        local handler_ = vars.F.find_file_name_handler(fstr, vars.Qfile_exists_p)
        if
          (
            not lisp.nilp(handler_) or (
              not lisp.nilp(predicate) and not lisp.eq(predicate, vars.Qt)
            )
          ) and not lisp.fixnatp(predicate)
        then
          error('TODO')
        else
          ---@type -1|file*
          local fd
          local encoded_fn = require 'elisp.coding'.encode_file_name(fstr)
          local pfn = lisp.sdata(encoded_fn)
          if lisp.fixnatp(predicate) then
            error('TODO')
          else
            local info = vim.uv.fs_stat(pfn)
            if not info or info.type == 'directory' then
              fd = -1
            else
              fd = io.open(pfn, 'r') or -1
            end
          end
          if fd ~= -1 then
            if newer and not lisp.fixnatp(predicate) then
              local info = assert(vim.uv.fs_stat(pfn))
              local mtime = info.mtime.sec * 1000 + info.mtime.nsec / 1000000
              if mtime <= save_mtime then
                io.close(fd --[[@as file*]])
              else
                if save_fd ~= -1 then
                  io.close(save_fd --[[@as file*]])
                end
                save_fd = fd
                save_mtime = mtime
                save_string = fstr
              end
            else
              if storep then
                storep[1] = fstr
              end
              return fd
            end
          end
          if save_fd ~= -1 and not lisp.consp(lisp.xcdr(tail)) then
            assert(save_string)
            if storep then
              storep[1] = save_string
            end
            return save_fd
          end
        end
      end
    )
    if ret then
      return ret
    end
    if absolute then
      return 'break'
    end
  end)
  if ret then
    return ret --[[@as unknown]]
  end
  return -1
end
local function lisp_file_lexically_bound_p(content)
  if _G.vim_elisp_later then
    error('TODO')
  end
  local l = assert(vim.lpeg, 'vim.lpeg not found, neovim version too old')
  local patt1 = l.P({
    l.V 'shabang' ^ -1 * l.V 'comment',
    shabang = l.P '#!' * (l.P(1) - l.P '\n') ^ 0 * l.P '\n',
    comment = l.P ';' * (l.P(1) - l.P '\n' - l.P '-*-') ^ 0 * l.V 'opts',
    opts = l.P '-*-' * l.C((l.P(1) - l.P '\n' - l.P '-*-') ^ 0) * (l.P '-*-' + l.P '\n'),
  })
  local file_vars = patt1:match(content)
  if not file_vars then
    return false
  end
  return file_vars:match('[ \t;]lexical%-binding:[ \t]*t[ \t;]') and true or false
end
F.load = {
  'load',
  1,
  5,
  0,
  [[Execute a file of Lisp code named FILE.
First try FILE with `.elc' appended, then try with `.el', then try
with a system-dependent suffix of dynamic modules (see `load-suffixes'),
then try FILE unmodified (the exact suffixes in the exact order are
determined by `load-suffixes').  Environment variable references in
FILE are replaced with their values by calling `substitute-in-file-name'.
This function searches the directories in `load-path'.

If optional second arg NOERROR is non-nil,
report no error if FILE doesn't exist.
Print messages at start and end of loading unless
optional third arg NOMESSAGE is non-nil (but `force-load-messages'
overrides that).
If optional fourth arg NOSUFFIX is non-nil, don't try adding
suffixes to the specified name FILE.
If optional fifth arg MUST-SUFFIX is non-nil, insist on
the suffix `.elc' or `.el' or the module suffix; don't accept just
FILE unless it ends in one of those suffixes or includes a directory name.

If NOSUFFIX is nil, then if a file could not be found, try looking for
a different representation of the file by adding non-empty suffixes to
its name, before trying another file.  Emacs uses this feature to find
compressed versions of files when Auto Compression mode is enabled.
If NOSUFFIX is non-nil, disable this feature.

The suffixes that this function tries out, when NOSUFFIX is nil, are
given by the return value of `get-load-suffixes' and the values listed
in `load-file-rep-suffixes'.  If MUST-SUFFIX is non-nil, only the
return value of `get-load-suffixes' is used, i.e. the file name is
required to have a non-empty suffix.

When searching suffixes, this function normally stops at the first
one that exists.  If the option `load-prefer-newer' is non-nil,
however, it tries all suffixes, and uses whichever file is the newest.

Loading a file records its definitions, and its `provide' and
`require' calls, in an element of `load-history' whose
car is the file name loaded.  See `load-history'.

While the file is in the process of being loaded, the variable
`load-in-progress' is non-nil and the variable `load-file-name'
is bound to the file's name.

Return t if the file exists and loads successfully.]],
}
function F.load.f(file, noerror, nomessage, nosuffix, mustsuffix)
  if _G.vim_elisp_later then
    error('TODO')
  end
  local count = specpdl.index()
  lisp.check_string(file)
  if _G.vim_elisp_later then
    error(
      'TODO: these files require a really long time to load (5+ seconds), so just skip them for now'
    )
  else
    local name = lisp.sdata(file):gsub('^.*/', '')
    if name == 'eucjp-ms' then
      return vars.Qnil
    end
  end
  local handler_ = vars.F.find_file_name_handler(file, vars.Qload)
  if not lisp.nilp(handler_) then
    error('TODO')
  end
  if not lisp.nilp(noerror) then
    file = handler.internal_condition_case(
      function()
        return vars.F.substitute_in_file_name(file)
      end,
      vars.Qt,
      function()
        return vars.Qnil
      end
    )
    if lisp.nilp(file) then
      return vars.Qnil
    end
  else
    file = vars.F.substitute_in_file_name(file)
  end
  local no_native = suffix_p(file, '.elc')
  local fd
  local found = { vars.Qnil }
  if lisp.schars(file) == 0 then
    fd = -1
  else
    local suffixes
    if not lisp.nilp(mustsuffix) then
      if suffix_p(file, '.el') or suffix_p(file, '.elc') then
        mustsuffix = vars.Qnil
      elseif not lisp.nilp(vars.F.file_name_directory(file)) then
        mustsuffix = vars.Qnil
      end
    end
    if not lisp.nilp(nosuffix) then
      suffixes = vars.Qnil
    else
      suffixes = vars.F.get_load_suffixes()
      if lisp.nilp(mustsuffix) then
        suffixes = vars.F.append({ suffixes, vars.V.load_file_rep_suffixes })
      end
    end
    fd = M.openp(
      vars.V.load_path,
      file,
      suffixes,
      found,
      vars.Qnil,
      not lisp.nilp(vars.V.load_prefer_newer),
      no_native
    )
  end
  if fd == -1 then
    if lisp.nilp(noerror) then
      error('TODO')
    end
    return vars.Qnil
  end
  if lisp.eq(vars.Qt, vars.V.user_init_file) then
    vars.V.user_init_file = found[1]
  end
  if fd == -2 then
    error('TODO')
  end
  ---@cast fd file*
  specpdl.record_unwind_protect(function()
    io.close(fd)
  end)
  if _G.vim_elisp_later then
    error('TODO: a lot of stuff should be set up here')
  else
    specpdl.bind(vars.Qload_in_progress, vars.Qnil)
    specpdl.bind(vars.Qlexical_binding, vars.Qnil)
    local content = fd:read('*all')
    if lisp_file_lexically_bound_p(content) then
      vars.F.set(vars.Qlexical_binding, vars.Qt)
    end
    local lex_bound = require 'elisp.data'.find_symbol_value(vars.Qlexical_binding)
    specpdl.bind(
      vars.Qinternal_interpreter_environment,
      (lex_bound == nil or lisp.nilp(lex_bound)) and vars.Qnil or lisp.list(vars.Qt)
    )
    local code = caching.cache(lisp.sdata(found[1]), function(cache_content)
      return require 'elisp.comp-lisp-to-lua'.read(cache_content)
    end, function(code)
      return require 'elisp.comp-lisp-to-lua'.compiles(code, lisp.sdata(file))
    end, function()
      return M.full_read_lua_string(content)
    end, true)
    for _, v in ipairs(code) do
      require 'elisp.eval'.eval_sub(v)
    end
    specpdl.unbind_to(count, nil)
  end
  return vars.Qt
end
F.get_load_suffixes = {
  'get-load-suffixes',
  0,
  0,
  0,
  [[Return the suffixes that `load' should try if a suffix is \
required.
This uses the variables `load-suffixes' and `load-file-rep-suffixes'.]],
}
function F.get_load_suffixes.f()
  local ret_suffixes = {}
  lisp.for_each_tail(vars.V.load_suffixes, function(suffixes)
    local suffix = lisp.xcar(suffixes)
    lisp.for_each_tail(vars.V.load_file_rep_suffixes, function(exts)
      table.insert(ret_suffixes, fns.concat_to_string({ suffix, lisp.xcar(exts) }))
    end)
  end)
  return lisp.list(unpack(ret_suffixes))
end
F.intern = {
  'intern',
  1,
  2,
  0,
  [[Return the canonical symbol whose name is STRING.
If there is none, one is created by this function and returned.
A second optional argument specifies the obarray to use;
it defaults to the value of `obarray'.]],
}
function F.intern.f(s, obarray)
  obarray = M.obarray_check(lisp.nilp(obarray) and vars.V.obarray or obarray)
  lisp.check_string(s)
  local found, longhand = M.lookup_considering_shorthand(obarray, lisp.sdata(s))
  if type(found) == 'number' then
    if longhand then
      error('TODO')
    else
      found = M.intern_drive(s, obarray, found)
    end
  end
  return found
end
F.read_from_string = {
  'read-from-string',
  1,
  3,
  0,
  [[Read one Lisp expression which is represented as text by STRING.
Returns a cons: (OBJECT-READ . FINAL-STRING-INDEX).
FINAL-STRING-INDEX is an integer giving the position of the next
remaining character in STRING.  START and END optionally delimit
a substring of STRING from which to read;  they default to 0 and
\(length STRING) respectively.  Negative values are counted from
the end of STRING.]],
}
function F.read_from_string.f(s, start, end_)
  assert(lisp.nilp(start) and lisp.nilp(end_), 'TODO')
  if _G.vim_elisp_later then
    error('TODO')
  end
  lisp.check_string(s)
  local iter = M.make_readcharfun(s)
  local val = M.read0(iter, false)
  return vars.F.cons(val, lisp.make_fixnum(iter.idx))
end
F.read = {
  'read',
  0,
  1,
  0,
  [[Read one Lisp expression as text from STREAM, return as Lisp object.
If STREAM is nil, use the value of `standard-input' (which see).
STREAM or the value of `standard-input' may be:
 a buffer (read from point and advance it)
 a marker (read from where it points and advance it)
 a function (call it with no arguments for each character,
     call it with a char as argument to push a char back)
 a string (takes text from string, starting at the beginning)
 t (read text line using minibuffer and use it, or read from
    standard input in batch mode).]],
}
function F.read.f(stream)
  if lisp.nilp(stream) then
    error('TODO')
  end
  if _G.vim_elisp_later then
    error('TODO')
  elseif lisp.stringp(stream) then
    return lisp.xcar(vars.F.read_from_string(stream, vars.Qnil, vars.Qnil))
  else
    error('TODO')
  end
end
---@return vim.elisp.obj
local function substitute_object_recurse(subst, subtree)
  if lisp.eq(subst[2], subtree) then
    return subst[1]
  end
  if
    lisp.symbolp(subtree)
    or lisp.numberp(subtree)
    or (lisp.stringp(subtree) and not lisp.string_intervals(subtree))
  then
    return subtree
  end
  if subst[4][subtree] then
    return subtree
  end
  if lisp.eq(subst[3], vars.Qt) or error('TODO') then
    assert(not lisp.symbolwithposp(subtree))
    subst[4][subtree] = true
  end
  local typ = lisp.xtype(subtree)
  if typ == lisp.type.vectorlike then
    local ptyp = lisp.pseudovector_type(subtree)
    if ptyp == lisp.pvec.normal_vector then
      for i = 0, lisp.asize(subtree) - 1 do
        lisp.aset(subtree, i, substitute_object_recurse(subst, lisp.aref(subtree, i)))
      end
      return subtree
    else
      error('TODO')
    end
  elseif typ == lisp.type.cons then
    lisp.xsetcar(subtree, substitute_object_recurse(subst, lisp.xcar(subtree)))
    lisp.xsetcdr(subtree, substitute_object_recurse(subst, lisp.xcdr(subtree)))
    return subtree
  elseif typ == lisp.type.string then
    error('TODO')
  else
    return subtree
  end
end
F.lread__substitute_object_in_subtree = {
  'lread--substitute-object-in-subtree',
  3,
  3,
  0,
  [[In OBJECT, replace every occurrence of PLACEHOLDER with OBJECT.
COMPLETED is a hash table of objects that might be circular, or is t
if any object might be circular.]],
}
function F.lread__substitute_object_in_subtree.f(object, placeholder, completed)
  local subst = { object, placeholder, completed, {} }
  local check_object = substitute_object_recurse(subst, object)
  if not lisp.eq(check_object, object) then
    signal.error('Unexpected mutation error in reader')
  end
  return vars.Qnil
end
F.locate_file_internal = {
  'locate-file-internal',
  2,
  4,
  0,
  [[Search for FILENAME through PATH.
Returns the file's name in absolute form, or nil if not found.
If SUFFIXES is non-nil, it should be a list of suffixes to append to
file name when searching.
If non-nil, PREDICATE is used instead of `file-readable-p'.
PREDICATE can also be an integer to pass to the faccessat(2) function,
in which case file-name-handlers are ignored.
This function will normally skip directories, so if you want it to find
directories, make sure the PREDICATE function returns `dir-ok' for them.]],
}
function F.locate_file_internal.f(filename, path, suffixes, predicate)
  local file = {}
  local fd = M.openp(path, filename, suffixes, file, predicate, false, true)
  if lisp.nilp(predicate) and fd ~= -1 then
    io.close(fd --[[@as file*]])
  end
  return file[1]
end

function M.init()
  if _G.vim_elisp_later then
    error('TODO: initialize load path')
  end
  vars.V.load_file_name = vars.Qnil --I don't know why emacs sets it to nil twice

  lisp.set_symbol_val(vars.Qnil --[[@as vim.elisp._symbol]], vars.Qnil)
  lisp.make_symbol_constant(vars.Qnil);
  (vars.Qnil --[[@as vim.elisp._symbol]]).declared_special = true

  lisp.set_symbol_val(vars.Qt --[[@as vim.elisp._symbol]], vars.Qt)
  lisp.make_symbol_constant(vars.Qt);
  (vars.Qt --[[@as vim.elisp._symbol]]).declared_special = true
end
function M.init_syms()
  vars.defsubr(F, 'load')
  vars.defsubr(F, 'get_load_suffixes')
  vars.defsubr(F, 'intern')
  vars.defsubr(F, 'read_from_string')
  vars.defsubr(F, 'read')
  vars.defsubr(F, 'lread__substitute_object_in_subtree')
  vars.defsubr(F, 'locate_file_internal')

  vars.defvar_lisp(
    'obarray',
    'obarray',
    [[Symbol table for use by `intern' and `read'.
It is a vector whose length ought to be prime for best results.
The vector's contents don't make sense if examined from Lisp programs;
to find all the symbols in an obarray, use `mapatoms'.]]
  )
  vars.V.obarray = vars.initial_obarray

  vars.defvar_lisp(
    'load_suffixes',
    'load-suffixes',
    [[List of suffixes for Emacs Lisp files and dynamic modules.
This list includes suffixes for both compiled and source Emacs Lisp files.
This list should not include the empty string.
`load' and related functions try to append these suffixes, in order,
to the specified file name if a suffix is allowed or required.]]
  )
  vars.V.load_suffixes =
    lisp.list(alloc.make_pure_c_string('.elc'), alloc.make_pure_c_string('.el'))

  vars.defvar_lisp(
    'load_file_rep_suffixes',
    'load-file-rep-suffixes',
    [[List of suffixes that indicate representations of \
the same file.
This list should normally start with the empty string.

Enabling Auto Compression mode appends the suffixes in
`jka-compr-load-suffixes' to this list and disabling Auto Compression
mode removes them again.  `load' and related functions use this list to
determine whether they should look for compressed versions of a file
and, if so, which suffixes they should try to append to the file name
in order to do so.  However, if you want to customize which suffixes
the loading functions recognize as compression suffixes, you should
customize `jka-compr-load-suffixes' rather than the present variable.]]
  )
  vars.V.load_file_rep_suffixes = lisp.list(alloc.make_pure_c_string(''))

  vars.defvar_lisp(
    'read_symbol_shorthands',
    'read-symbol-shorthands',
    [[Alist of known symbol-name shorthands.
This variable's value can only be set via file-local variables.
See Info node `(elisp)Shorthands' for more details.]]
  )
  vars.V.read_symbol_shorthands = vars.Qnil

  vars.defvar_lisp(
    'byte_boolean_vars',
    'byte-boolean-vars',
    [[List of all DEFVAR_BOOL variables, used by the byte code optimizer.]]
  )
  vars.V.byte_boolean_vars = vars.Qnil

  vars.defvar_bool(
    'load_force_doc_strings',
    'load-force-doc-strings',
    [[Non-nil means `load' should force-load all dynamic doc strings.
This is useful when the file being loaded is a temporary copy.]]
  )
  vars.V.load_force_doc_strings = vars.Qnil

  vars.defsym('Qbackquote', '`')
  vars.defsym('Qcomma', ',')
  vars.defsym('Qcomma_at', ',@')

  vars.defsym('Qfunction', 'function')
  vars.defsym('Qload', 'load')

  vars.defsym('Qhash_table', 'hash-table')
  vars.defsym('Qdata', 'data')
  vars.defsym('Qsize', 'size')
  vars.defsym('Qtest', 'test')
  vars.defsym('Qweakness', 'weakness')
  vars.defsym('Qrehash_size', 'rehash-size')
  vars.defsym('Qrehash_threshold', 'rehash-threshold')
  vars.defsym('Qpurecopy', 'purecopy')

  --    vars.defvar_forward('load_path','load-path',[[List of directories to search for files to load.
  --Each element is a string (directory file name) or nil (meaning
  --`default-directory').
  --This list is consulted by the `require' function.
  --Initialized during startup as described in Info node `(elisp)Library Search'.
  --Use `directory-file-name' when adding items to this path.  However, Lisp
  --programs that process this list should tolerate directories both with
  --and without trailing slashes.]],function ()
  --            if _G.vim_elisp_later then
  --                error('TODO: the returned value may be changed (by setcdr/setcar)')
  --                error('TODO: also, it may be changed by neovim and not reflected')
  --                error('TODO: implement forwarding cons cells')
  --            end
  --            return lisp.list(unpack(vim.tbl_map(alloc.make_string,vim.opt.runtimepath:get())))
  --        end,function (obj)
  --            error('TODO')
  --        end)
  vars.defvar_lisp(
    'load_path',
    'load-path',
    [[List of directories to search for files to load.
Each element is a string (directory file name) or nil (meaning
`default-directory').
This list is consulted by the `require' function.
Initialized during startup as described in Info node `(elisp)Library Search'.
Use `directory-file-name' when adding items to this path.  However, Lisp
programs that process this list should tolerate directories both with
and without trailing slashes.]]
  )
  vars.V.load_path = lisp.list(unpack(vim.tbl_map(alloc.make_string, _G.vim_elisp_load_path)))

  vars.defsym('Qmacroexp__dynvars', 'macroexp--dynvars')
  vars.defvar_lisp(
    'macroexp__dynvars',
    'macroexp--dynvars',
    [[List of variables declared dynamic in the current scope.
Only valid during macro-expansion.  Internal use only.]]
  )
  vars.V.macroexp__dynvars = vars.Qnil

  vars.defvar_lisp(
    'after_load_alist',
    'after-load-alist',
    [[An alist of functions to be evalled when particular files are loaded.
Each element looks like (REGEXP-OR-FEATURE FUNCS...).

REGEXP-OR-FEATURE is either a regular expression to match file names, or
a symbol (a feature name).

When `load' is run and the file-name argument matches an element's
REGEXP-OR-FEATURE, or when `provide' is run and provides the symbol
REGEXP-OR-FEATURE, the FUNCS in the element are called.

An error in FUNCS does not undo the load, but does prevent calling
the rest of the FUNCS.]]
  )
  vars.V.after_load_alist = vars.Qnil

  vars.defvar_bool(
    'load_prefer_newer',
    'load-prefer-newer',
    [[Non-nil means `load' prefers the newest version of a file.
This applies when a filename suffix is not explicitly specified and
`load' is trying various possible suffixes (see `load-suffixes' and
`load-file-rep-suffixes').  Normally, it stops at the first file
that exists unless you explicitly specify one or the other.  If this
option is non-nil, it checks all suffixes and uses whichever file is
newest.
Note that if you customize this, obviously it will not affect files
that are loaded before your customizations are read!]]
  )
  vars.V.load_prefer_newer = vars.Qnil

  vars.defvar_lisp(
    'user_init_file',
    'user-init-file',
    [[File name, including directory, of user's initialization file.
If the file loaded had extension `.elc', and the corresponding source file
exists, this variable contains the name of source file, suitable for use
by functions like `custom-save-all' which edit the init file.
While Emacs loads and evaluates any init file, value is the real name
of the file, regardless of whether or not it has the `.elc' extension.]]
  )
  vars.V.user_init_file = vars.Qnil

  vars.defvar_lisp(
    'load_file_name',
    'load-file-name',
    [[Full name of file being loaded by `load'.

In case of native code being loaded this is indicating the
corresponding bytecode filename.  Use `load-true-file-name' to obtain
the .eln filename.]]
  )
  vars.V.load_file_name = vars.Qnil

  vars.defvar_lisp('load_in_progress', 'load-in-progress', [[Non-nil if inside of `load'.]])
  vars.V.load_in_progress = vars.Qnil
  vars.defsym('Qload_in_progress', 'load-in-progress')

  vars.defvar_lisp(
    'current_load_list',
    'current-load-list',
    [[Used for internal purposes by `load'.]]
  )
  vars.V.current_load_list = vars.Qnil
  has_inited_syms = true

  vars.defvar_lisp(
    'read_circle',
    'read-circle',
    [[Non-nil means read recursive structures using #N= and #N# syntax.]]
  )
  vars.V.read_circle = vars.Qt

  vars.defvar_lisp(
    'load_history',
    'load-history',
    [[Alist mapping loaded file names to symbols and features.
Each alist element should be a list (FILE-NAME ENTRIES...), where
FILE-NAME is the name of a file that has been loaded into Emacs.
The file name is absolute and true (i.e. it doesn't contain symlinks).
As an exception, one of the alist elements may have FILE-NAME nil,
for symbols and features not associated with any file.

The remaining ENTRIES in the alist element describe the functions and
variables defined in that file, the features provided, and the
features required.  Each entry has the form `(provide . FEATURE)',
`(require . FEATURE)', `(defun . FUNCTION)', `(defface . SYMBOL)',
 `(define-type . SYMBOL)', or `(cl-defmethod METHOD SPECIALIZERS)'.
In addition, entries may also be single symbols,
which means that symbol was defined by `defvar' or `defconst'.

During preloading, the file name recorded is relative to the main Lisp
directory.  These file names are converted to absolute at startup.]]
  )
  vars.V.load_history = vars.Qnil
end
return M
