local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local signal = require 'elisp.signal'
local alloc = require 'elisp.alloc'
local chars = require 'elisp.chars'
local bytes = require 'elisp.bytes'

local M = {}
local CHARTAB_SIZE_BITS_0 = 6
local CHARTAB_SIZE_BITS_1 = 4
local CHARTAB_SIZE_BITS_2 = 5
local CHARTAB_SIZE_BITS_3 = 7
local chartab_bits = { --(1-indexed)
  (CHARTAB_SIZE_BITS_1 + CHARTAB_SIZE_BITS_2 + CHARTAB_SIZE_BITS_3),
  (CHARTAB_SIZE_BITS_2 + CHARTAB_SIZE_BITS_3),
  CHARTAB_SIZE_BITS_3,
  0,
}
local chartab_chars = { --(1-indexed)
  bit.lshift(1, chartab_bits[1]),
  bit.lshift(1, chartab_bits[2]),
  bit.lshift(1, chartab_bits[3]),
  bit.lshift(1, chartab_bits[4]),
}
local chartab_size = { --(1-indexed)
  bit.lshift(1, CHARTAB_SIZE_BITS_0),
  bit.lshift(1, CHARTAB_SIZE_BITS_1),
  bit.lshift(1, CHARTAB_SIZE_BITS_2),
  bit.lshift(1, CHARTAB_SIZE_BITS_3),
}
M.chartab_size = chartab_size
local uniprop_decoder = { --(1-indexed)
  function(ctable, value)
    local tbl = ctable --[[@as vim.elisp._char_table]]
    if lisp.vectorp(lisp.aref(tbl.extras, 4)) then
      local valvec = lisp.aref(tbl.extras, 4)
      if lisp.fixnum(value) >= 0 and lisp.fixnum(value) < lisp.asize(valvec) then
        value = lisp.aref(valvec, lisp.fixnum(value))
      end
    end
    return value
  end,
}
local function chartab_idx(c, depth, min_char)
  return bit.rshift(c - min_char, assert(chartab_bits[depth + 1]))
end
---@param depth number
---@param min_char number
---@param default vim.elisp.obj|'nil'
---@return vim.elisp.obj
function M.make_subchartable(depth, min_char, default)
  local v = alloc.make_vector(chartab_size[depth + 1], default) --[[@as vim.elisp._sub_char_table]]
  v.depth = depth
  v.min_char = min_char
  return lisp.make_vectorlike_ptr(v, lisp.pvec.sub_char_table)
end
---@param tbl vim.elisp.obj
---@param idx number
---@param val vim.elisp.obj
local function set_char_table_contents(tbl, idx, val)
  assert(0 <= idx and idx <= chartab_size[1]);
  (tbl --[[@as vim.elisp._char_table]]).contents[idx + 1] = val
end
---@param t vim.elisp._char_table
---@return number
local function chartable_extra_slots(t)
  return lisp.asize(t.extras)
end
---@param t vim.elisp.obj
---@return boolean
local function uniproptablep(t)
  return lisp.eq((t --[[@as vim.elisp._char_table]]).purpose, vars.Qchar_code_property_table)
    and chartable_extra_slots(t --[[@as vim.elisp._char_table]]) == 5
end
---@param ctable vim.elisp.obj
---@param c number
---@param val vim.elisp.obj
---@param is_uniprop boolean
local function sub_char_table_set(ctable, c, val, is_uniprop)
  local tbl = ctable --[[@as vim.elisp._sub_char_table]]
  local depth = tbl.depth
  local min_char = tbl.min_char
  local i = chartab_idx(c, depth, min_char)
  if depth == 3 then
    tbl.contents[i + 1] = val
  else
    local sub = tbl.contents[i + 1] or vars.Qnil
    if not lisp.subchartablep(sub) then
      if is_uniprop then
        error('TODO')
      else
        sub = M.make_subchartable(depth + 1, min_char + i * chartab_chars[depth + 1], sub)
        tbl.contents[i + 1] = sub
      end
    end
    sub_char_table_set(sub, c, val, is_uniprop)
  end
end
local function uniprop_compressed_form_p(obj)
  return lisp.stringp(obj)
    and lisp.schars(obj) > 0
    and (lisp.sref(obj, 0) == 1 or lisp.sref(obj, 0) == 2)
end
---@param ctable vim.elisp.obj
---@return vim.elisp.obj
local function char_table_ascii(ctable)
  local sub = (ctable --[[@as vim.elisp._char_table]]).contents[1] or vars.Qnil
  if not lisp.subchartablep(sub) then
    return sub
  end
  sub = (sub --[[@as vim.elisp._sub_char_table]]).contents[1] or vars.Qnil
  if not lisp.subchartablep(sub) then
    return sub
  end
  local val = (sub --[[@as vim.elisp._sub_char_table]]).contents[1] or vars.Qnil
  if uniproptablep(ctable) and uniprop_compressed_form_p(val) then
    error('TODO')
  end
  return val
end
---@param ctable vim.elisp.obj
---@param c number
---@param val vim.elisp.obj
function M.set(ctable, c, val)
  local tbl = ctable --[[@as vim.elisp._char_table]]
  if chars.asciicharp(c) and lisp.subchartablep(tbl.ascii) then
    (tbl.ascii --[[@as vim.elisp._sub_char_table]]).contents[c + 1] = val
  else
    local i = chartab_idx(c, 0, 0)
    local sub = tbl.contents[i + 1] or vars.Qnil
    if not lisp.subchartablep(sub) then
      sub = M.make_subchartable(1, i * chartab_chars[1], sub)
      set_char_table_contents(ctable, i, sub)
    end
    sub_char_table_set(sub, c, val, uniproptablep(ctable))
    if chars.asciicharp(c) then
      tbl.ascii = char_table_ascii(ctable)
    end
  end
end
---@param ctable vim.elisp.obj
---@param c number
---@param is_uniprop boolean
---@return vim.elisp.obj
local function sub_char_table_ref(ctable, c, is_uniprop)
  local tbl = ctable --[[@as vim.elisp._sub_char_table]]
  local idx = chartab_idx(c, tbl.depth, tbl.min_char)
  local val = tbl.contents[idx + 1] or vars.Qnil
  if is_uniprop then
    error('TODO')
  end
  if lisp.subchartablep(val) then
    val = sub_char_table_ref(val, c, is_uniprop)
  end
  return val
end
---@param ctable vim.elisp.obj
---@param c number
---@return vim.elisp.obj
function M.ref(ctable, c)
  local tbl = ctable --[[@as vim.elisp._char_table]]
  local val
  if chars.asciicharp(c) then
    val = tbl.ascii
    if lisp.subchartablep(val) then
      val = (val --[[@as vim.elisp._sub_char_table]]).contents[c + 1] or vars.Qnil
    end
  else
    val = tbl.contents[chartab_idx(c, 0, 0) + 1] or vars.Qnil
    if lisp.subchartablep(val) then
      val = sub_char_table_ref(val, c, uniproptablep(ctable))
    end
  end
  if lisp.nilp(val) then
    val = tbl.default
    if lisp.nilp(val) and lisp.chartablep(tbl.parent) then
      M.ref(tbl.parent, c)
    end
  end
  return val
end
local sub_char_table_ref_and_range
---@return vim.elisp.obj
local function char_table_ref_simple(
  ctable,
  idx,
  c,
  fromptr,
  toptr,
  default,
  is_uniprop,
  is_subtable
)
  local val = is_subtable
      and (
        (ctable --[[@as vim.elisp._sub_char_table]]).contents[idx + 1] or vars.Qnil
      )
    or (
      (ctable --[[@as vim.elisp._char_table]]).contents[idx + 1] or vars.Qnil
    )
  if is_uniprop then
    error('TODO')
  end
  if lisp.subchartablep(val) then
    val = sub_char_table_ref_and_range(val, c, fromptr, toptr, default, is_uniprop)
  elseif lisp.nilp(val) then
    val = default
  end
  return val
end
---@return vim.elisp.obj
function sub_char_table_ref_and_range(ctable, c, fromptr, toptr, default, is_uniprop)
  local tbl = ctable --[[@as vim.elisp._sub_char_table]]
  local depth = tbl.depth
  local min_char = tbl.min_char
  local ct_idx = chartab_idx(c, depth, min_char)
  local val = char_table_ref_simple(ctable, ct_idx, c, fromptr, toptr, default, is_uniprop, true)
  local idx = ct_idx
  while idx > 0 and fromptr[1] < min_char + idx * chartab_chars[depth + 1] do
    c = min_char + idx * chartab_chars[depth + 1] - 1
    idx = idx - 1
    local this_val =
      char_table_ref_simple(ctable, idx, c, fromptr, toptr, default, is_uniprop, true)
    if not lisp.eq(this_val, val) then
      fromptr[1] = c + 1
      break
    end
  end
  while true do
    c = (ct_idx + 1) * chartab_chars[depth + 1]
    if not (c < chartab_chars[depth]) then
      break
    end
    c = c + min_char
    if not (c <= toptr[1]) then
      break
    end
    ct_idx = ct_idx + 1
    local this_val =
      char_table_ref_simple(ctable, ct_idx, c, fromptr, toptr, default, is_uniprop, true)
    if not lisp.eq(this_val, val) then
      toptr[1] = c - 1
      break
    end
  end
  return val
end
---@param ctable vim.elisp.obj
---@param c number
---@param fromptr number[]
---@param toptr number[]
---@return vim.elisp.obj
function M.char_table_ref_and_range(ctable, c, fromptr, toptr)
  local tbl = ctable --[[@as vim.elisp._char_table]]
  local ct_idx = chartab_idx(c, 0, 0)
  local is_uniprop = uniproptablep(ctable)
  if fromptr[1] < 0 then
    fromptr[1] = 0
  end
  if toptr[1] < 0 then
    toptr[1] = bytes.MAX_CHAR
  end
  local val =
    char_table_ref_simple(ctable, ct_idx, c, fromptr, toptr, tbl.default, is_uniprop, false)

  local idx = ct_idx
  while fromptr[1] < idx * chartab_chars[1] do
    c = idx * chartab_chars[1] - 1
    idx = idx - 1
    local this_val =
      char_table_ref_simple(ctable, idx, c, fromptr, toptr, tbl.default, is_uniprop, false)
    if not lisp.eq(this_val, val) then
      fromptr[1] = c + 1
      break
    end
  end
  while toptr[1] > (ct_idx + 1) * chartab_chars[1] do
    ct_idx = ct_idx + 1
    c = ct_idx * chartab_chars[1]
    local this_val =
      char_table_ref_simple(ctable, ct_idx, c, fromptr, toptr, tbl.default, is_uniprop, false)
    if not lisp.eq(this_val, val) then
      toptr[1] = c - 1
      break
    end
  end
  return val
end
---@param ctable vim.elisp.obj
---@return vim.elisp.obj
local function copy_sub_char_table(ctable)
  local tbl = ctable --[[@as vim.elisp._sub_char_table]]
  local depth = tbl.depth
  local min_char = tbl.min_char
  local copy = M.make_subchartable(depth, min_char, vars.Qnil)
  for i = 0, chartab_size[depth + 1] - 1 do
    local val = (ctable --[[@as vim.elisp._sub_char_table]]).contents[i + 1] or vars.Qnil;
    (copy --[[@as vim.elisp._sub_char_table]]).contents[i + 1] = (
      lisp.subchartablep(val) and copy_sub_char_table(val) or val
    )
  end
  return copy
end
---@param ctable vim.elisp.obj
---@return vim.elisp.obj
function M.copy_char_table(ctable)
  local tbl = ctable --[[@as vim.elisp._char_table]]
  local size = lisp.asize(ctable)
  local copy = alloc.make_vector(size, 'nil') --[[@as vim.elisp._char_table]]
  copy.default = tbl.default
  copy.parent = tbl.parent
  copy.purpose = tbl.purpose
  for i = 0, chartab_size[1] - 1 do
    copy.contents[i + 1] = (
      lisp.subchartablep(tbl.contents[i + 1] or vars.Qnil)
        and copy_sub_char_table(tbl.contents[i + 1] or vars.Qnil)
      or tbl.contents[i + 1]
      or vars.Qnil
    )
  end
  local obj = lisp.make_vectorlike_ptr(copy, lisp.pvec.char_table)
  copy.ascii = char_table_ascii(obj)
  copy.extras = alloc.make_vector(chartable_extra_slots(tbl), 'nil')
  for i = 0, chartable_extra_slots(tbl) - 1 do
    M.set_extra(obj, i, lisp.aref(tbl.extras, i))
  end
  return obj
end
---@param ctable vim.elisp.obj
---@param idx number
---@param val vim.elisp.obj
function M.set_extra(ctable, idx, val)
  assert(0 <= idx and idx < chartable_extra_slots(ctable --[[@as vim.elisp._char_table]]))
  lisp.aset((ctable --[[@as vim.elisp._char_table]]).extras, idx, val)
end
local function sub_char_table_set_range(ctable, from, to, val, is_uniprop)
  local tbl = ctable --[[@as vim.elisp._sub_char_table]]
  local depth = tbl.depth
  local min_char = tbl.min_char
  local chars_in_block = chartab_chars[depth + 1]
  local lim = chartab_size[depth + 1]
  if from < min_char then
    from = min_char
  end
  local i = chartab_idx(from, depth, min_char)
  local c = min_char + chars_in_block * i
  while i < lim do
    if c > to then
      break
    end
    if from <= c and c + chars_in_block - 1 <= to then
      tbl.contents[i + 1] = val
    else
      local sub = tbl.contents[i + 1] or vars.Qnil
      if not lisp.subchartablep(sub) then
        if is_uniprop then
          error('TODO')
        else
          sub = M.make_subchartable(depth + 1, c, sub)
          tbl.contents[i + 1] = sub
        end
      end
      sub_char_table_set_range(sub, from, to, val, is_uniprop)
    end

    i = i + 1
    c = c + chars_in_block
  end
end
---@param ctable vim.elisp.obj
---@param from number
---@param to number
---@param val vim.elisp.obj
function M.set_range(ctable, from, to, val)
  local tbl = ctable --[[@as vim.elisp._char_table]]
  if from == to then
    M.set(ctable, from, val)
    return
  end
  local is_uniprop = uniproptablep(ctable)
  local lim = chartab_idx(to, 0, 0)

  local i = chartab_idx(from, 0, 0)
  local c = i * chartab_chars[1]
  while i <= lim do
    if c > to then
      break
    end
    if from <= c and c + chartab_chars[1] - 1 <= to then
      set_char_table_contents(ctable, i, val)
    else
      local sub = tbl.contents[i + 1] or vars.Qnil
      if not lisp.subchartablep(sub) then
        sub = M.make_subchartable(1, i * chartab_chars[1], sub)
        set_char_table_contents(ctable, i, sub)
      end
      sub_char_table_set_range(sub, from, to, val, is_uniprop)
    end
    i = i + 1
    c = c + chartab_chars[1]
  end
  if chars.asciicharp(from) then
    tbl.ascii = char_table_ascii(ctable)
  end
end
local function uniprop_get_decoder_(tbl)
  if
    not lisp.fixnump(lisp.aref((tbl --[[@as vim.elisp._char_table]]).extras, 1))
  then
    return nil
  end
  local i = lisp.fixnum(lisp.aref((tbl --[[@as vim.elisp._char_table]]).extras, 1))
  if i < 0 or i >= #uniprop_decoder then
    return nil
  end
  return uniprop_decoder[i + 1]
end
local function uniprop_get_decoder_if(tbl)
  return uniproptablep(tbl) and uniprop_get_decoder_(tbl) or nil
end
local function uniprop_table_uncompress(ctable, idx)
  local tbl = ctable --[[@as vim.elisp._sub_char_table]]
  local val = assert(tbl.contents[idx + 1])
  local min_char = tbl.min_char + chartab_chars[3] * idx
  local sub = M.make_subchartable(3, min_char, vars.Qnil)
  tbl.contents[idx + 1] = sub
  local p = lisp.sdata(val)
  local pidx = 2
  if p:sub(1, 1) == '\1' then
    local len, v = chars.stringcharandlength(p:sub(pidx))
    idx = v
    pidx = pidx + len
    while pidx <= #p and idx < chartab_chars[3] do
      len, v = chars.stringcharandlength(p:sub(pidx))
      pidx = pidx + len
      lisp.aset(sub, idx, v > 0 and lisp.make_fixnum(v) or vars.Qnil)
      idx = idx + 1
    end
  elseif p:sub(1, 1) == '\2' then
    idx = 0
    while pidx <= #p do
      local len, v = chars.stringcharandlength(p:sub(pidx))
      pidx = pidx + len
      local count = 1
      if pidx <= #p then
        len, count = chars.stringcharandlength(p:sub(pidx))
        if count < 128 then
          count = 1
        else
          pidx = pidx + len
          count = count - 128
        end
      end
      for _ = 1, count do
        lisp.aset(sub, idx, lisp.make_fixnum(v))
        idx = idx + 1
      end
    end
    assert(idx == 128)
  else
    error('unreachable')
  end
  return sub
end
local function map_sub_char_table(c_fun, fun, ctable, val, range, top)
  local from = lisp.fixnum(lisp.xcar(range))
  local to = lisp.fixnum(lisp.xcdr(range))
  local is_uniprop = uniproptablep(top)
  local decoder = uniprop_get_decoder_if(top)
  local depth, min_char, max_char
  if lisp.subchartablep(ctable) then
    local tbl = ctable --[[@as vim.elisp._sub_char_table]]
    depth = tbl.depth
    min_char = tbl.min_char
    max_char = min_char + chartab_chars[depth] - 1
  else
    depth = 0
    min_char = 0
    max_char = bytes.MAX_CHAR
  end
  local chars_in_block = chartab_chars[depth + 1]
  if to < max_char then
    max_char = to
  end
  local i
  if from <= min_char then
    i = 0
  else
    i = math.floor((from - min_char) / chars_in_block)
  end
  local c = min_char + chars_in_block * i
  while c <= max_char do
    local this = lisp.aref(ctable, i)
    local nextc = c + chars_in_block
    if is_uniprop and uniprop_compressed_form_p(this) then
      this = uniprop_table_uncompress(ctable, i)
    end
    if lisp.subchartablep(this) then
      if to >= nextc then
        lisp.xsetcdr(range, lisp.make_fixnum(nextc - 1))
      end
      val = map_sub_char_table(c_fun, fun, this, val, range, top)
    elseif lisp.nilp(this) then
      this = (top --[[@as vim.elisp._char_table]]).default
    end
    if not lisp.subchartablep(this) and not lisp.eq(val, this) then
      local different_value = true
      if
        lisp.nilp(val) and not lisp.nilp((top--[[@as vim.elisp._char_table]]).parent)
      then
        error('TODO')
      end
      if not lisp.nilp(val) and different_value then
        lisp.xsetcdr(range, lisp.make_fixnum(c - 1))
        if lisp.eq(lisp.xcar(range), lisp.xcdr(range)) then
          if c_fun then
            c_fun(lisp.xcar(range), val)
          else
            if decoder then
              val = decoder(top, val)
            end
            vars.F.funcall { fun, lisp.xcar(range), val }
          end
        else
          if c_fun then
            c_fun(range, val)
          else
            if decoder then
              val = decoder(top, val)
            end
            vars.F.funcall { fun, range, val }
          end
        end
      end
      val = this
      from = c
      lisp.xsetcar(range, lisp.make_fixnum(c))
    end
    lisp.xsetcdr(range, lisp.make_fixnum(to))
    i = i + 1
    c = c + chars_in_block
  end
  return val
end
---@param c_fun fun(key:vim.elisp.obj,val:vim.elisp.obj)?
---@param fun vim.elisp.obj
---@param ctable vim.elisp.obj
function M.map_char_table(c_fun, fun, ctable)
  local decoder = uniprop_get_decoder_if(ctable)
  local range = vars.F.cons(lisp.make_fixnum(0), lisp.make_fixnum(bytes.MAX_CHAR))
  local val = (ctable --[[@as vim.elisp._char_table]]).ascii
  if lisp.subchartablep(val) then
    val = lisp.aref(val, 0)
  end
  val = map_sub_char_table(c_fun, fun, ctable, val, range, ctable)
  while
    lisp.nilp(val) and not lisp.nilp((ctable --[[@as vim.elisp._char_table]]).parent)
  do
    local from = lisp.fixnum(lisp.xcar(range))
    local parent = (ctable --[[@as vim.elisp._char_table]]).parent
    local tmp = (parent --[[@as vim.elisp._char_table]]).parent;
    (parent --[[@as vim.elisp._char_table]]).parent = vars.Qnil
    val = M.ref(parent, from);
    (parent --[[@as vim.elisp._char_table]]).parent = tmp
    val = map_sub_char_table(c_fun, fun, parent, val, range, parent)
    ctable = parent
  end
  if lisp.nilp(val) then
    return
  end
  if lisp.eq(lisp.xcar(range), lisp.xcdr(range)) then
    if c_fun then
      c_fun(lisp.xcar(range), val)
    else
      if decoder then
        val = decoder(ctable, val)
      end
      vars.F.funcall { fun, lisp.xcar(range), val }
    end
  else
    if c_fun then
      c_fun(range, val)
    else
      if decoder then
        val = decoder(ctable, val)
      end
      vars.F.funcall { fun, range, val }
    end
  end
end

---@type vim.elisp.F
local F = {}
F.char_table_extra_slot =
  { 'char-table-extra-slot', 2, 2, 0, [[Return the value of CHAR-TABLE's extra-slot number N.]] }
function F.char_table_extra_slot.f(ctable, n)
  lisp.check_chartable(ctable)
  lisp.check_fixnum(n)
  if
    lisp.fixnum(n) < 0
    or lisp.fixnum(n) >= chartable_extra_slots(ctable --[[@as vim.elisp._char_table]])
  then
    signal.args_out_of_range(ctable, n)
  end
  return lisp.aref((ctable --[[@as vim.elisp._char_table]]).extras, lisp.fixnum(n))
end
F.set_char_table_extra_slot =
  { 'set-char-table-extra-slot', 3, 3, 0, [[Set CHAR-TABLE's extra-slot number N to VALUE.]] }
function F.set_char_table_extra_slot.f(ctable, n, value)
  lisp.check_chartable(ctable)
  lisp.check_fixnum(n)
  if
    lisp.fixnum(n) < 0
    or lisp.fixnum(n) >= chartable_extra_slots(ctable --[[@as vim.elisp._char_table]])
  then
    signal.args_out_of_range(ctable, n)
  end
  lisp.aset((ctable --[[@as vim.elisp._char_table]]).extras, lisp.fixnum(n), value)
  return value
end
F.make_char_table = {
  'make-char-table',
  1,
  2,
  0,
  [[Return a newly created char-table, with purpose PURPOSE.
Each element is initialized to INIT, which defaults to nil.

PURPOSE should be a symbol.  If it has a `char-table-extra-slots'
property, the property's value should be an integer between 0 and 10
that specifies how many extra slots the char-table has.  Otherwise,
the char-table has no extra slot.]],
}
function F.make_char_table.f(purpose, init)
  lisp.check_symbol(purpose)
  local n = vars.F.get(purpose, vars.Qchar_table_extra_slots)
  local n_extras
  if lisp.nilp(n) then
    n_extras = 0
  else
    lisp.check_fixnat(n)
    if lisp.fixnum(n) > 10 then
      signal.args_out_of_range(n, vars.Qnil)
    end
    n_extras = lisp.fixnum(n)
  end
  local vector = alloc.make_vector(chartab_size[1], init) --[[@as vim.elisp._char_table]]
  -- Is this correct?:
  vector.ascii = init
  vector.default = init
  vector.extras = alloc.make_vector(n_extras, init)
  --vector.ascii=vars.Qnil
  --vector.default=vars.Qnil
  vector.parent = vars.Qnil
  vector.purpose = purpose
  return lisp.make_vectorlike_ptr(vector, lisp.pvec.char_table)
end
F.set_char_table_range = {
  'set-char-table-range',
  3,
  3,
  0,
  [[Set the value in CHAR-TABLE for a range of characters RANGE to VALUE.
RANGE should be t (for all characters), nil (for the default value),
a cons of character codes (for characters in the range),
or a character code.  Return VALUE.]],
}
function F.set_char_table_range.f(ctable, range, value)
  lisp.check_chartable(ctable)
  if lisp.eq(range, vars.Qt) then
    error('TODO')
  elseif lisp.nilp(range) then
    error('TODO')
  elseif chars.characterp(range) then
    M.set(ctable, lisp.fixnum(range), value)
  elseif lisp.consp(range) then
    chars.check_character(lisp.xcar(range))
    chars.check_character(lisp.xcdr(range))
    M.set_range(ctable, lisp.fixnum(lisp.xcar(range)), lisp.fixnum(lisp.xcdr(range)), value)
  else
    signal.error("Invalid RANGE argument to `set-char-table-range'")
  end
  return value
end
F.set_char_table_parent = {
  'set-char-table-parent',
  2,
  2,
  0,
  [[Set the parent char-table of CHAR-TABLE to PARENT.
Return PARENT.  PARENT must be either nil or another char-table.]],
}
function F.set_char_table_parent.f(ctable, parent)
  lisp.check_chartable(ctable)
  if not lisp.nilp(parent) then
    lisp.check_chartable(parent)
    local temp = parent
    while not lisp.nilp(temp) do
      if lisp.eq(temp, ctable) then
        signal.error('Attempt to make a chartable be its own parent')
      end
      temp = (temp --[[@as vim.elisp._char_table]]).parent
    end
  end
  (ctable --[[@as vim.elisp._char_table]]).parent = parent
  return parent
end
F.char_table_subtype = {
  'char-table-subtype',
  1,
  1,
  0,
  [[
Return the subtype of char-table CHAR-TABLE.  The value is a symbol.]],
}
function F.char_table_subtype.f(char_table)
  lisp.check_chartable(char_table)
  return (char_table --[[@as vim.elisp._char_table]]).purpose
end
local function uniprop_table(prop)
  local val = vars.F.assq(prop, vars.V.char_code_property_alist)
  if not lisp.consp(val) then
    return vars.Qnil
  end
  local ctable = lisp.xcdr(val)
  if lisp.stringp(ctable) then
    local intl = alloc.make_unibyte_string('international/')
    local lread = require 'elisp.lread'
    local fns = require 'elisp.fns'
    local result = lread.save_match_data_load(
      fns.concat_to_string { intl, ctable },
      vars.Qt,
      vars.Qt,
      vars.Qt,
      vars.Qt
    )
    if lisp.nilp(result) then
      return vars.Qnil
    end
    ctable = lisp.xcdr(val)
  end
  if not lisp.chartablep(ctable) or not uniproptablep(ctable) then
    return vars.Qnil
  end
  val = lisp.aref((ctable --[[@as vim.elisp._char_table]]).extras, 1)
  if lisp.fixnump(val) then
    if lisp.fixnum(val) < 0 or lisp.fixnum(val) >= #uniprop_decoder then
      return vars.Qnil
    end
  elseif not lisp.nilp(val) then
    return vars.Qnil
  end
  (ctable --[[@as vim.elisp._char_table]]).ascii = char_table_ascii(ctable)
  return ctable
end
F.unicode_property_table_internal = {
  'unicode-property-table-internal',
  1,
  1,
  0,
  [[Return a char-table for Unicode character property PROP.
Use `get-unicode-property-internal' and
`put-unicode-property-internal' instead of `aref' and `aset' to get
and put an element value.]],
}
function F.unicode_property_table_internal.f(prop)
  if not _G.vim_elisp_later then
    -- These tables are used in some really slow functions (e.g. map-char-table), so we just lie and say they don't exist
    return vars.Qnil
  else
    rawget(_G, 'error')('TODO: speedup map-char-table')
  end
  local ctable = uniprop_table(prop)
  if lisp.chartablep(ctable) then
    return ctable
  end
  return vars.F.cdr(vars.F.assq(prop, vars.V.char_code_property_alist))
end
F.map_char_table = {
  'map-char-table',
  2,
  2,
  0,
  [[Call FUNCTION for each character in CHAR-TABLE that has non-nil value.
FUNCTION is called with two arguments, KEY and VALUE.
KEY is a character code or a cons of character codes specifying a
range of characters that have the same value.
VALUE is what (char-table-range CHAR-TABLE KEY) returns.]],
}
function F.map_char_table.f(func, char_table)
  lisp.check_chartable(char_table)
  M.map_char_table(nil, func, char_table)
  return vars.Qnil
end
local function optimize_sub_char_table(ctable, test)
  local first = lisp.aref(ctable, 0)
  if lisp.subchartablep(first) then
    lisp.aset(ctable, 0, optimize_sub_char_table(first, test))
  end
  local optimizable = true
  for i = 1, lisp.asize(ctable) - 1 do
    local this = lisp.aref(ctable, i)
    if lisp.subchartablep(this) then
      lisp.aset(ctable, i, optimize_sub_char_table(this, test))
    end
    if optimizable then
      if lisp.nilp(test) then
        if lisp.nilp(vars.F.equal(this, first)) then
          optimizable = false
        end
      else
        error('TODO')
      end
    end
  end
  if optimizable then
    return first
  end
  return ctable
end
F.optimize_char_table = {
  'optimize-char-table',
  1,
  2,
  0,
  [[Optimize CHAR-TABLE.
TEST is the comparison function used to decide whether two entries are
equivalent and can be merged.  It defaults to `equal'.]],
}
function F.optimize_char_table.f(char_table, test)
  lisp.check_chartable(char_table)
  for i = 0, chartab_size[1] - 1 do
    if lisp.subchartablep(lisp.aref(char_table, i)) then
      lisp.aset(char_table, i, optimize_sub_char_table(lisp.aref(char_table, i), test))
    end
  end
  (char_table --[[@as vim.elisp._char_table]]).ascii = char_table_ascii(char_table)
  return vars.Qnil
end
F.char_table_range = {
  'char-table-range',
  2,
  2,
  0,
  [[Return the value in CHAR-TABLE for a range of characters RANGE.
RANGE should be nil (for the default value),
a cons of character codes (for characters in the range), or a character code.
If RANGE is a cons (FROM . TO), the function returns the value for FROM.]],
}
function F.char_table_range.f(char_table, range)
  lisp.check_chartable(char_table)
  if lisp.nilp(range) then
    return (char_table --[[@as vim.elisp._char_table]]).default
  elseif chars.characterp(range) then
    return M.ref(char_table, lisp.fixnum(range))
  elseif lisp.consp(range) then
    chars.check_character(lisp.xcar(range))
    chars.check_character(lisp.xcdr(range))
    local from = lisp.fixnum(lisp.xcar(range))
    local to = lisp.fixnum(lisp.xcdr(range))
    return M.char_table_ref_and_range(char_table, from, { from }, { to })
  else
    signal.error("Invalid RANGE argument to `char-table-range'")
    error('unreachable')
  end
end

function M.init_syms()
  vars.defsym('Qchar_code_property_table', 'char-code-property-table')

  vars.defsubr(F, 'make_char_table')
  vars.defsubr(F, 'char_table_extra_slot')
  vars.defsubr(F, 'set_char_table_extra_slot')
  vars.defsubr(F, 'set_char_table_range')
  vars.defsubr(F, 'set_char_table_parent')
  vars.defsubr(F, 'char_table_subtype')
  vars.defsubr(F, 'unicode_property_table_internal')
  vars.defsubr(F, 'map_char_table')
  vars.defsubr(F, 'optimize_char_table')
  vars.defsubr(F, 'char_table_range')

  vars.defvar_lisp(
    'char_code_property_alist',
    'char-code-property-alist',
    [[Alist of character property name vs char-table containing property values.
Internal use only.]]
  )
  vars.V.char_code_property_alist = vars.Qnil
end
return M
