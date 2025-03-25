local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local alloc = require 'elisp.alloc'
local signal = require 'elisp.signal'
local overflow = require 'elisp.overflow'

local ccl_header_buf_mag = 0
local ccl_header_eof = 1
local ccl_header_main = 2
---@type vim.elisp.obj
local ccl_program_table

local function ascending_order(lo, med, hi)
  return lo <= med and med <= hi
end
local M = {}

---@type vim.elisp.F
local F = {}
---@param ccl vim.elisp.obj
---@return vim.elisp.obj
local function resolve_symbol_ccl_program(ccl)
  if not (ccl_header_main < lisp.asize(ccl) and lisp.asize(ccl) <= overflow.max) then
    return vars.Qnil
  end
  local result = vars.F.copy_sequence(ccl)
  local veclen = lisp.asize(result)
  local unresolved = false

  for i = 0, veclen - 1 do
    local contents = lisp.aref(result, i)
    if
      lisp.fixnump(contents)
      and -0x80000000 <= lisp.fixnum(contents)
      and lisp.fixnum(contents) <= 0x7fffffff
    then
    elseif lisp.consp(contents) then
      error('TODO')
    elseif lisp.symbolp(contents) then
      error('TODO')
    else
      return vars.Qnil
    end
  end
  if
    not (
      0 <= lisp.fixnum(lisp.aref(result, ccl_header_buf_mag))
      and ascending_order(0, lisp.fixnum(lisp.aref(result, ccl_header_eof)), lisp.asize(ccl))
    )
  then
    return vars.Qnil
  end
  return (unresolved and vars.Qt or result)
end
F.register_ccl_program = {
  'register-ccl-program',
  2,
  2,
  0,
  [[Register CCL program CCL-PROG as NAME in `ccl-program-table'.
CCL-PROG should be a compiled CCL program (vector), or nil.
If it is nil, just reserve NAME as a CCL program name.
Return index number of the registered CCL program.]],
}
function F.register_ccl_program.f(name, ccl_prog)
  local len = lisp.asize(ccl_program_table)
  lisp.check_symbol(name)

  local resolved = vars.Qnil
  if not lisp.nilp(ccl_prog) then
    lisp.check_vector(ccl_prog)
    resolved = resolve_symbol_ccl_program(ccl_prog)
    if lisp.nilp(resolved) then
      signal.error('Error in CCL program')
    end
    if lisp.vectorp(resolved) then
      ccl_prog = resolved
      resolved = vars.Qt
    else
      resolved = vars.Qnil
    end
  end

  local idx = 0
  while idx < len do
    local slot = lisp.aref(ccl_program_table, idx)
    if not lisp.vectorp(slot) then
      break
    end
    if lisp.eq(name, lisp.aref(slot, 0)) then
      lisp.aset(slot, 1, ccl_prog)
      lisp.aset(slot, 2, resolved)
      lisp.aset(slot, 3, vars.Qt)
      return lisp.make_fixnum(idx)
    end
    idx = idx + 1
  end

  if idx == len then
    local tmp = alloc.make_vector(len + 1, vars.Qnil)
    for i = 0, len - 1 do
      lisp.aset(tmp, i, lisp.aref(ccl_program_table, i))
    end
    ccl_program_table = tmp
  end

  lisp.aset(ccl_program_table, idx, vars.F.vector(name, ccl_prog, resolved, vars.Qt))
  vars.F.put(name, vars.Qccl_program_idx, lisp.make_fixnum(idx))
  return lisp.make_fixnum(idx)
end

function M.init()
  ccl_program_table = alloc.make_vector(32, 'nil')
end
function M.init_syms()
  vars.defsubr(F, 'register_ccl_program')

  vars.defsym('Qccl_program_idx', 'ccl-program-idx')

  vars.defvar_lisp(
    'font_ccl_encoder_alist',
    'font-ccl-encoder-alist',
    [[Alist of fontname patterns vs corresponding CCL program.
Each element looks like (REGEXP . CCL-CODE),
 where CCL-CODE is a compiled CCL program.
When a font whose name matches REGEXP is used for displaying a character,
 CCL-CODE is executed to calculate the code point in the font
 from the charset number and position code(s) of the character which are set
 in CCL registers R0, R1, and R2 before the execution.
The code point in the font is set in CCL registers R1 and R2
 when the execution terminated.
 If the font is single-byte font, the register R2 is not used.]]
  )
  vars.V.font_ccl_encoder_alist = vars.Qnil
end
return M
