local alloc = require 'elisp.alloc'
local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local chartab = require 'elisp.chartab'
local b = require 'elisp.bytes'
local chars = require 'elisp.chars'
local nvim = require 'elisp.nvim'
local signal = require 'elisp.signal'

---@enum elisp.syntax_code
local syntax_code = {
  whitespace = 0,
  punct = 1,
  word = 2,
  symbol = 3,
  open = 4,
  close = 5,
  quote = 6,
  string = 7,
  math = 8,
  escape = 9,
  charquote = 10,
  comment = 11,
  endcomment = 12,
  inherit = 13,
  comment_fence = 14,
  string_fence = 15,
  max = 16,
}
local syntax_spec_code = {
  [0] = 255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  syntax_code.whitespace,
  syntax_code.comment_fence,
  syntax_code.string,
  255,
  syntax_code.math,
  255,
  255,
  syntax_code.quote,
  syntax_code.open,
  syntax_code.close,
  255,
  255,
  255,
  syntax_code.whitespace,
  syntax_code.punct,
  syntax_code.charquote,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  syntax_code.comment,
  255,
  syntax_code.endcomment,
  255,
  syntax_code.inherit,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  syntax_code.word,
  255,
  255,
  255,
  255,
  syntax_code.escape,
  255,
  255,
  syntax_code.symbol,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  255,
  syntax_code.word,
  255,
  255,
  255,
  255,
  syntax_code.string_fence,
  255,
  255,
  255,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
}
assert(#syntax_spec_code == 256 - 1)
local syntax_code_object

---@type vim.elisp.F
local F = {}
F.standard_syntax_table = {
  'standard-syntax-table',
  0,
  0,
  0,
  [[Return the standard syntax table.
This is the one used for new buffers.]],
}
function F.standard_syntax_table.f()
  return vars.standard_syntax_table
end
local function check_syntax_table(obj)
  lisp.check_type(
    lisp.chartablep(obj)
      and lisp.eq((obj --[[@as vim.elisp._char_table]]).purpose, vars.Qsyntax_table),
    vars.Qsyntax_table_p,
    obj
  )
end
F.modify_syntax_entry = {
  'modify-syntax-entry',
  2,
  3,
  'cSet syntax for character: \nsSet syntax for %s to: ',
  [[Set syntax for character CHAR according to string NEWENTRY.
The syntax is changed only for table SYNTAX-TABLE, which defaults to
 the current buffer's syntax table.
CHAR may be a cons (MIN . MAX), in which case, syntaxes of all characters
in the range MIN to MAX are changed.
The first character of NEWENTRY should be one of the following:
  Space or -  whitespace syntax.    w   word constituent.
  _           symbol constituent.   .   punctuation.
  (           open-parenthesis.     )   close-parenthesis.
  "           string quote.         \\   escape.
  $           paired delimiter.     \\='   expression quote or prefix operator.
  <           comment starter.      >   comment ender.
  /           character-quote.      @   inherit from parent table.
  |           generic string fence. !   generic comment fence.

Only single-character comment start and end sequences are represented thus.
Two-character sequences are represented as described below.
The second character of NEWENTRY is the matching parenthesis,
 used only if the first character is `(' or `)'.
Any additional characters are flags.
Defined flags are the characters 1, 2, 3, 4, b, p, and n.
 1 means CHAR is the start of a two-char comment start sequence.
 2 means CHAR is the second character of such a sequence.
 3 means CHAR is the start of a two-char comment end sequence.
 4 means CHAR is the second character of such a sequence.

There can be several orthogonal comment sequences.  This is to support
language modes such as C++.  By default, all comment sequences are of style
a, but you can set the comment sequence style to b (on the second character
of a comment-start, and the first character of a comment-end sequence) and/or
c (on any of its chars) using this flag:
 b means CHAR is part of comment sequence b.
 c means CHAR is part of comment sequence c.
 n means CHAR is part of a nestable comment sequence.

 p means CHAR is a prefix character for `backward-prefix-chars';
   such characters are treated as whitespace when they occur
   between expressions.
usage: (modify-syntax-entry CHAR NEWENTRY &optional SYNTAX-TABLE)]],
}
function F.modify_syntax_entry.f(c, newentry, syntax_table)
  if lisp.consp(c) then
    chars.check_character(lisp.xcar(c))
    chars.check_character(lisp.xcdr(c))
  else
    chars.check_character(c)
  end
  if lisp.nilp(syntax_table) then
    syntax_table = nvim.bvar(true, 'syntax_table')
  else
    check_syntax_table(syntax_table)
  end
  newentry = vars.F.string_to_syntax(newentry)
  if lisp.consp(c) then
    vars.F.set_char_table_range(syntax_table, c, newentry)
  else
    chartab.set(syntax_table, lisp.fixnum(c), newentry)
  end
  return vars.Qnil
end
F.string_to_syntax = {
  'string-to-syntax',
  1,
  1,
  0,
  [[Convert a syntax descriptor STRING into a raw syntax descriptor.
STRING should be a string of the form allowed as argument of
`modify-syntax-entry'.  The return value is a raw syntax descriptor: a
cons cell (CODE . MATCHING-CHAR) which can be used, for example, as
the value of a `syntax-table' text property.]],
}
function F.string_to_syntax.f(str)
  lisp.check_string(str)
  local val = syntax_spec_code[lisp.sref(str, 0)]
  if val == 255 then
    signal.error('Invalid syntax description letter: %c', lisp.sref(str, 0))
  end
  if val == syntax_code.inherit then
    return vars.Qnil
  end
  local match
  local p = 1
  if lisp.sref(str, p) ~= 0 then
    local len, char = chars.stringcharandlength(lisp.sdata(str):sub(2))
    match = lisp.make_fixnum(char)
    if lisp.fixnum(match) == b ' ' then
      match = vars.Qnil
    end
    p = p + len
  else
    match = vars.Qnil
  end
  while true do
    local c = lisp.sref(str, p)
    p = p + 1
    if c == 0 then
      break
    elseif c == b '1' then
      val = bit.bor(val, bit.lshift(1, 16))
    elseif c == b '2' then
      val = bit.bor(val, bit.lshift(1, 17))
    elseif c == b '3' then
      val = bit.bor(val, bit.lshift(1, 18))
    elseif c == b '4' then
      val = bit.bor(val, bit.lshift(1, 19))
    elseif c == b 'p' then
      val = bit.bor(val, bit.lshift(1, 20))
    elseif c == b 'b' then
      val = bit.bor(val, bit.lshift(1, 21))
    elseif c == b 'n' then
      val = bit.bor(val, bit.lshift(1, 22))
    elseif c == b 'c' then
      val = bit.bor(val, bit.lshift(1, 23))
    end
  end
  if val < lisp.asize(syntax_code_object) and lisp.nilp(match) then
    return lisp.aref(syntax_code_object, val)
  else
    return vars.F.cons(lisp.make_fixnum(val), match)
  end
end

local M = {}
function M.init()
  syntax_code_object = alloc.make_vector(syntax_code.max, 'nil')
  for i = 0, syntax_code.max - 1 do
    lisp.aset(syntax_code_object, i, lisp.list(lisp.make_fixnum(i)))
  end

  vars.F.put(vars.Qsyntax_table, vars.Qchar_table_extra_slots, lisp.make_fixnum(0))
  local temp = lisp.aref(syntax_code_object, syntax_code.whitespace)
  vars.standard_syntax_table = vars.F.make_char_table(vars.Qsyntax_table, temp)

  temp = lisp.aref(syntax_code_object, syntax_code.punct)
  for i = 0, (b ' ' - 1) do
    chartab.set(vars.standard_syntax_table, i, temp)
  end
  chartab.set(vars.standard_syntax_table, b.no_break_space, temp)

  temp = lisp.aref(syntax_code_object, syntax_code.whitespace)
  chartab.set(vars.standard_syntax_table, b ' ', temp)
  chartab.set(vars.standard_syntax_table, b '\t', temp)
  chartab.set(vars.standard_syntax_table, b '\n', temp)
  chartab.set(vars.standard_syntax_table, b '\r', temp)
  chartab.set(vars.standard_syntax_table, b '\f', temp)

  temp = lisp.aref(syntax_code_object, syntax_code.word)
  for i = b 'a', b 'z' do
    chartab.set(vars.standard_syntax_table, i, temp)
  end
  for i = b 'A', b 'Z' do
    chartab.set(vars.standard_syntax_table, i, temp)
  end
  for i = b '0', b '9' do
    chartab.set(vars.standard_syntax_table, i, temp)
  end
  chartab.set(vars.standard_syntax_table, b '$', temp)
  chartab.set(vars.standard_syntax_table, b '%', temp)

  chartab.set(
    vars.standard_syntax_table,
    b '(',
    vars.F.cons(lisp.make_fixnum(syntax_code.open), lisp.make_fixnum(b ')'))
  )
  chartab.set(
    vars.standard_syntax_table,
    b ')',
    vars.F.cons(lisp.make_fixnum(syntax_code.close), lisp.make_fixnum(b '('))
  )
  chartab.set(
    vars.standard_syntax_table,
    b '[',
    vars.F.cons(lisp.make_fixnum(syntax_code.open), lisp.make_fixnum(b ']'))
  )
  chartab.set(
    vars.standard_syntax_table,
    b ']',
    vars.F.cons(lisp.make_fixnum(syntax_code.close), lisp.make_fixnum(b '['))
  )
  chartab.set(
    vars.standard_syntax_table,
    b '{',
    vars.F.cons(lisp.make_fixnum(syntax_code.open), lisp.make_fixnum(b '}'))
  )
  chartab.set(
    vars.standard_syntax_table,
    b '}',
    vars.F.cons(lisp.make_fixnum(syntax_code.close), lisp.make_fixnum(b '{'))
  )
  chartab.set(
    vars.standard_syntax_table,
    b '"',
    vars.F.cons(lisp.make_fixnum(syntax_code.string), vars.Qnil)
  )
  chartab.set(
    vars.standard_syntax_table,
    b '\\',
    vars.F.cons(lisp.make_fixnum(syntax_code.escape), vars.Qnil)
  )

  temp = lisp.aref(syntax_code_object, syntax_code.symbol)
  for c in ('_-+*/&|<>='):gmatch '.' do
    chartab.set(vars.standard_syntax_table, b[c], temp)
  end

  temp = lisp.aref(syntax_code_object, syntax_code.punct)
  for c in (".,;:?!#@~^'`"):gmatch '.' do
    chartab.set(vars.standard_syntax_table, b[c], temp)
  end

  temp = lisp.aref(syntax_code_object, syntax_code.word)
  chartab.set_range(vars.standard_syntax_table, 0x80, b.MAX_CHAR, temp)
end
function M.init_syms()
  vars.defsym('Qsyntax_table', 'syntax-table')
  vars.defsym('Qsyntax_table_p', 'syntax-table-p')

  vars.defsubr(F, 'standard_syntax_table')
  vars.defsubr(F, 'modify_syntax_entry')
  vars.defsubr(F, 'string_to_syntax')
end
return M
