local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local M = {}

---@type vim.elisp.F
local F = {}
local function default_to_grave_quoting_style()
  if _G.vim_elisp_later then
    error('TODO')
  end
  return true
end
F.text_quoting_style = {
  'text-quoting-style',
  0,
  0,
  0,
  [[Return the current effective text quoting style.
If the variable `text-quoting-style' is `grave', `straight' or
`curve', just return that value.  If it is nil (the default), return
`grave' if curved quotes cannot be displayed (for instance, on a
terminal with no support for these characters), otherwise return
`quote'.  Any other value is treated as `grave'.

Note that in contrast to the variable `text-quoting-style', this
function will never return nil.]],
}
function F.text_quoting_style.f()
  if
    (lisp.nilp(vars.V.text_quoting_style) and default_to_grave_quoting_style())
    or lisp.eq(vars.V.text_quoting_style, vars.Qgrave)
  then
    return vars.Qgrave
  elseif lisp.eq(vars.V.text_quoting_style, vars.Qstraight) then
    return vars.Qstraight
  else
    return vars.Qcurve
  end
end
function M.init_syms()
  vars.defsubr(F, 'text_quoting_style')

  vars.defsym('Qfunction_documentation', 'function-documentation')
  vars.defvar_lisp(
    'text_quoting_style',
    'text-quoting-style',
    [[Style to use for single quotes in help and messages.

The value of this variable determines substitution of grave accents
and apostrophes in help output (but not for display of Info
manuals) and in functions like `message' and `format-message', but not
in `format'.

The value should be one of these symbols:
  `curve':    quote with curved single quotes ‘like this’.
  `straight': quote with straight apostrophes \\='like this\\='.
  `grave':    quote with grave accent and apostrophe \\=`like this\\=';
	      i.e., do not alter the original quote marks.
  nil:        like `curve' if curved single quotes are displayable,
	      and like `grave' otherwise.  This is the default.

You should never read the value of this variable directly from a Lisp
program.  Use the function `text-quoting-style' instead, as that will
compute the correct value for the current terminal in the nil case.]]
  )
  vars.V.text_quoting_style = vars.Qnil
end
return M
