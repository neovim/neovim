local bytes = require 'elisp.bytes'
local signal = require 'elisp.signal'
local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'
local alloc = require 'elisp.alloc'
local M = {}

local function charvalidp(c)
  return 0 <= c and c <= bytes.MAX_CHAR
end
function M.characterp(x)
  return lisp.fixnump(x) and charvalidp(lisp.fixnum(x))
end
---@param x vim.elisp.obj
function M.check_character(x)
  lisp.check_type(M.characterp(x), vars.Qcharacterp, x)
end

---@overload fun(c:number):boolean
function M.charbyte8p(c)
  return bytes.MAX_5_BYTE_CHAR < c
end
---@overload fun(c:number):boolean
function M.asciicharp(c)
  return 0 <= c and c < 0x80
end
---@overload fun(c:number):boolean
function M.charbyte8headp(c)
  return c == 0xc0 or c == 0xc1
end
---@overload fun(c:number):boolean
function M.singlebytecharp(c)
  return 0 <= c and c < 0x100
end

---@param c number
---@return string
function M.byte8string(c)
  return string.char(
    bit.bor(0xc0, bit.band(bit.rshift(c, 6), 0x01)),
    bit.bor(0x80, bit.band(c, 0x3f))
  )
end
---@param c number
---@return string
function M.charstring(c)
  assert(0 <= c)
  if bit.band(c, bytes.CHAR_MODIFIER_MASK) > 0 then
    error('TODO')
  end
  if c <= bytes.MAX_1_BYTE_CHAR then
    return string.char(c)
  elseif c <= bytes.MAX_2_BYTE_CHAR then
    return string.char(bit.bor(0xc0, bit.rshift(c, 6)), bit.bor(0x80, bit.band(c, 0x3f)))
  elseif c <= bytes.MAX_3_BYTE_CHAR then
    return string.char(
      bit.bor(0xe0, bit.rshift(c, 12)),
      bit.bor(0x80, bit.band(bit.rshift(c, 6), 0x3f)),
      bit.bor(0x80, bit.band(c, 0x3f))
    )
  elseif c <= bytes.MAX_4_BYTE_CHAR then
    error('TODO')
  elseif c <= bytes.MAX_5_BYTE_CHAR then
    error('TODO')
  elseif c <= bytes.MAX_CHAR then
    c = M.chartobyte8(c)
    return M.byte8string(c)
  else
    signal.error('Invalid character: %x', c)
    error('unreachable')
  end
end
---@param s string
---@return string
function M.strasunibyte(s)
  local out = ''
  local p = 1
  while p <= #s do
    local c = string.byte(s, p)
    local len = M.bytesbycharhead(c)
    if M.charbyte8headp(c) then
      len, c = M.stringcharandlength(s:sub(p))
      p = p + len
      out = out .. string.char(M.chartobyte8(c))
    else
      for _ = 1, len do
        out = out .. s:sub(p, p)
        p = p + 1
      end
    end
  end
  return out
end
---@param s string
---@return number
function M.stringchar(s)
  return select(2, M.stringcharandlength(s))
end
---@param s string
---@return number
---@return number
function M.stringcharandlength(s)
  local c, p1, p2, p3, p4 = string.byte(s, 1, 5)
  assert(c)
  if bit.band(c, 0x80) == 0 then
    return 1, c
  end
  assert(0xc0 <= c and p1)
  local d = bit.lshift(c, 6) + p1 - (bit.lshift(0xc0, 6) + 0x80)
  if bit.band(c, 0x20) == 0 then
    return 2, d + (c < 0xc2 and 0x3fff80 or 0)
  end
  assert(p2)
  d = bit.lshift(d, 6) + p2 - (bit.lshift(0x20, 12) + 0x80)
  if bit.band(c, 0x10) == 0 then
    assert(bytes.MAX_2_BYTE_CHAR < d and d <= bytes.MAX_3_BYTE_CHAR)
    return 3, d
  end
  assert(p3)
  d = bit.lshift(d, 6) + p3 - (bit.lshift(0x10, 18) + 0x80)
  if bit.band(c, 0x08) == 0 then
    assert(bytes.MAX_3_BYTE_CHAR < d and d <= bytes.MAX_4_BYTE_CHAR)
    return 4, d
  end
  error('TODO')
  assert(p4)
end
---@param str vim.elisp.obj
---@param i_bytes number
---@return number,number
function M.fetchstringcharadvance(str, i_bytes)
  if lisp.string_multibyte(str) then
    local s = lisp.sdata(str):sub(i_bytes + 1)
    local len, char = M.stringcharandlength(s)
    return char, len
  else
    return lisp.sref(str, i_bytes), 1
  end
end

---@param c number
function M.chartobyte8(c)
  return M.charbyte8p(c) and c - 0x3fff00 or bit.band(c, 0xff)
end
---@param c number
function M.byte8tochar(c)
  return c + 0x3fff00
end
---@param c number
---@return number
function M.bytesbycharhead(c)
  return (bit.band(c, 0x80) == 0 and 1)
    or (bit.band(c, 0x20) == 0 and 2)
    or (bit.band(c, 0x10) == 0 and 3)
    or (bit.band(c, 0x08) == 0 and 4)
    or 5
end
---@param c number
---@return number
function M.charhexdigit(c)
  return ({
    [bytes '0'] = 0,
    [bytes '1'] = 1,
    [bytes '2'] = 2,
    [bytes '3'] = 3,
    [bytes '4'] = 4,
    [bytes '5'] = 5,
    [bytes '6'] = 6,
    [bytes '7'] = 7,
    [bytes '8'] = 8,
    [bytes '9'] = 9,
    [bytes 'a'] = 10,
    [bytes 'b'] = 11,
    [bytes 'c'] = 12,
    [bytes 'd'] = 13,
    [bytes 'e'] = 14,
    [bytes 'f'] = 15,
    [bytes 'A'] = 10,
    [bytes 'B'] = 11,
    [bytes 'C'] = 12,
    [bytes 'D'] = 13,
    [bytes 'E'] = 14,
    [bytes 'F'] = 15,
  })[c] or -1
end
---@param s string
---@return string
function M.str_to_multibyte(s)
  return (s:gsub('[\x80-\xff]', function(c)
    return M.byte8string(string.byte(c))
  end))
end
---@param s string
---@return number
function M.count_size_as_multibyte(s)
  local len = #s
  for i = 1, #s do
    if s:byte(i) > 127 then
      len = len + 1
    end
  end
  return len
end
---@param c number
---@return boolean
function M.charheadp(c)
  return bit.band(c, 0xc0) ~= 0x80
end

---@type vim.elisp.F
local F = {}
F.max_char = {
  'max-char',
  0,
  1,
  0,
  [[Return the maximum character code.
If UNICODE is non-nil, return the maximum character code defined
by the Unicode Standard.]],
}
function F.max_char.f(unicode)
  if lisp.nilp(unicode) then
    return lisp.make_fixnum(bytes.MAX_CHAR)
  end
  return lisp.make_fixnum(bytes.MAX_UNICODE_CHAR)
end
F.characterp = {
  'characterp',
  1,
  2,
  0,
  [[Return non-nil if OBJECT is a character.
In Emacs Lisp, characters are represented by character codes, which
are non-negative integers.  The function `max-char' returns the
maximum character code.
usage: (characterp OBJECT)]],
}
function F.characterp.f(obj, _)
  return M.characterp(obj) and vars.Qt or vars.Qnil
end
F.string = {
  'string',
  0,
  -2,
  0,
  [[
Concatenate all the argument characters and make the result a string.
usage: (string &rest CHARACTERS)]],
}
function F.string.fa(args)
  local is_ascii = true
  local str = ''
  for i = 1, #args do
    M.check_character(args[i])
    if not M.asciicharp(lisp.fixnum(args[i])) then
      is_ascii = false
    end
    str = str .. M.charstring(lisp.fixnum(args[i]))
  end
  return alloc.make_specified_string(str, #args, is_ascii)
end

function M.init()
  local chartab = require 'elisp.chartab'

  vars.V.auto_fill_chars = vars.F.make_char_table(vars.Qauto_fill_chars, vars.Qnil)
  chartab.set(vars.V.auto_fill_chars, bytes ' ', vars.Qt)
  chartab.set(vars.V.auto_fill_chars, bytes '\n', vars.Qt)

  vars.V.char_width_table = vars.F.make_char_table(vars.Qnil, lisp.make_fixnum(1))
  chartab.set_range(vars.V.char_width_table, 0x80, 0x9f, lisp.make_fixnum(4))
  chartab.set_range(
    vars.V.char_width_table,
    bytes.MAX_5_BYTE_CHAR + 1,
    bytes.MAX_CHAR,
    lisp.make_fixnum(4)
  )

  vars.F.put(vars.Qchar_script_table, vars.Qchar_table_extra_slots, lisp.make_fixnum(1))
  vars.V.char_script_table = vars.F.make_char_table(vars.Qchar_script_table, vars.Qnil)

  vars.V.translation_table_vector = alloc.make_vector(16, 'nil')
end
function M.init_syms()
  vars.defsubr(F, 'max_char')
  vars.defsubr(F, 'characterp')
  vars.defsubr(F, 'string')

  vars.defsym('Qcharacterp', 'character')
  vars.defsym('Qauto_fill_chars', 'auto-fill-chars')
  vars.defsym('Qchar_script_table', 'char-script-table')

  vars.defvar_lisp(
    'auto_fill_chars',
    'auto-fill-chars',
    [[A char-table for characters which invoke auto-filling.
Such characters have value t in this table.]]
  )

  vars.defvar_lisp(
    'char_width_table',
    'char-width-table',
    'A char-table for width (columns) of each character.'
  )

  vars.defvar_lisp(
    'char_script_table',
    'char-script-table',
    [[Char table of script symbols.
It has one extra slot whose value is a list of script symbols.]]
  )

  vars.defvar_lisp(
    'translation_table_vector',
    'translation-table-vector',
    [[
Vector recording all translation tables ever defined.
Each element is a pair (SYMBOL . TABLE) relating the table to the
symbol naming it.  The ID of a translation table is an index into this vector.]]
  )
end
return M
