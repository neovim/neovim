local vars = require 'elisp.vars'
local alloc = require 'elisp.alloc'
local lisp = require 'elisp.lisp'
local M = {}

---@type vim.elisp.F
local F = {}
F.capitalize = {
  'capitalize',
  1,
  1,
  0,
  [[Convert argument to capitalized form and return that.
This means that each word's first character is converted to either
title case or upper case, and the rest to lower case.

The argument may be a character or string.  The result has the same
type.  (See `downcase' for further details about the type.)

The argument object is not altered--the value is a copy.  If argument
is a character, characters which map to multiple code points when
cased, e.g. ﬁ, are returned unchanged.]],
}
function F.capitalize.f(arg)
  if _G.vim_elisp_later then
    error('TODO')
  end
  local s = lisp.sdata(arg)
  local f = function(c, rest, r)
    return c:upper() .. rest:lower() .. (r or '')
  end
  s = s:gsub('(%w)(%w*)(%W)', f)
  s = s:gsub('(%w)(%w*)$', f)
  s = s:gsub('^(%w)(%w*)', f)
  return alloc.make_string(s)
end
F.downcase = {
  'downcase',
  1,
  1,
  0,
  [[Convert argument to lower case and return that.
The argument may be a character or string.  The result has the same type,
including the multibyteness of the string.

This means that if this function is called with a unibyte string
argument, and downcasing it would turn it into a multibyte string
(according to the current locale), the downcasing is done using ASCII
\"C\" rules instead.  To accurately downcase according to the current
locale, the string must be converted into multibyte first.

The argument object is not altered--the value is a copy.]],
}
function F.downcase.f(arg)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return alloc.make_string(vim.fn.tolower(lisp.sdata(arg)))
end
F.upcase = {
  'upcase',
  1,
  1,
  0,
  [[Convert argument to upper case and return that.
The argument may be a character or string.  The result has the same
type.  (See `downcase' for further details about the type.)

The argument object is not altered--the value is a copy.  If argument
is a character, characters which map to multiple code points when
cased, e.g. ﬁ, are returned unchanged.

See also `capitalize', `downcase' and `upcase-initials'.]],
}
function F.upcase.f(obj)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return alloc.make_string(vim.fn.toupper(lisp.sdata(obj)))
end
function M.init_syms()
  vars.defsubr(F, 'capitalize')
  vars.defsubr(F, 'downcase')
  vars.defsubr(F, 'upcase')
end
return M
