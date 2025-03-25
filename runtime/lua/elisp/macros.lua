local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'

local M = {}

function M.init_syms()
  vars.defvar_lisp(
    'executing_kbd_macro',
    'executing-kbd-macro',
    [[Currently executing keyboard macro (string or vector).
This is nil when not executing a keyboard macro.]]
  )
  vars.V.executing_kbd_macro = vars.Qnil
end
return M
