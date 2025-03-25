local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'

---@type vim.elisp.obj
local gstring_hash_table

---@type vim.elisp.F
local F = {}
F.clear_composition_cache =
  { 'clear-composition-cache', 0, 0, 0, [[Internal use only.
Clear composition cache.]] }
function F.clear_composition_cache.f()
  gstring_hash_table =
    vars.F.make_hash_table(vars.QCtest, vars.Qequal, vars.QCsize, lisp.make_fixnum(311))
  return vars.F.clear_face_cache(vars.Qt)
end

local M = {}
function M.init()
  vars.V.composition_function_table = vars.F.make_char_table(vars.Qnil, vars.Qnil)

  local args = { vars.QCtest, vars.Qequal, vars.QCsize, lisp.make_fixnum(311) }
  gstring_hash_table = vars.F.make_hash_table(unpack(args))
end
function M.init_syms()
  vars.defsubr(F, 'clear_composition_cache')

  vars.defvar_lisp(
    'composition_function_table',
    'composition-function-table',
    [[Char-table of functions for automatic character composition.
For each character that has to be composed automatically with
preceding and/or following characters, this char-table contains
a function to call to compose that character.

The element at index C in the table, if non-nil, is a list of
composition rules of the form ([PATTERN PREV-CHARS FUNC] ...);
the rules must be specified in the descending order of PREV-CHARS
values.

PATTERN is a regular expression which C and the surrounding
characters must match.

PREV-CHARS is a non-negative integer (less than 4) specifying how many
characters before C to check the matching with PATTERN.  If it is 0,
PATTERN must match C and the following characters.  If it is 1,
PATTERN must match a character before C and the following characters.

If PREV-CHARS is 0, PATTERN can be nil, which means that the
single character C should be composed.

FUNC is a function to return a glyph-string representing a
composition of the characters that match PATTERN.  It is
called with one argument GSTRING.

GSTRING is a template of a glyph-string to return.  It is already
filled with a proper header for the characters to compose, and
glyphs corresponding to those characters one by one.  The
function must return a new glyph-string with the same header as
GSTRING, or modify GSTRING itself and return it.

See also the documentation of `auto-composition-mode'.]]
  )
end
return M
