local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'
local b = require 'elisp.bytes'
local chartab = require 'elisp.chartab'
local M = {}
---@param obj vim.elisp.obj
---@return vim.elisp.obj
local function check_casetable(obj)
  lisp.check_type(not lisp.nilp(vars.F.case_table_p(obj)), vars.Qcase_table_p, obj)
  return obj
end
---@param ctable vim.elisp.obj
---@param standard boolean
---@return vim.elisp.obj
local function set_case_table(ctable, standard)
  check_casetable(ctable)
  local up = lisp.aref((ctable --[[@as vim.elisp._char_table]]).extras, 0)
  local canon = lisp.aref((ctable --[[@as vim.elisp._char_table]]).extras, 1)
  local eqv = lisp.aref((ctable --[[@as vim.elisp._char_table]]).extras, 2)
  if lisp.nilp(up) then
    error('TODO')
  end
  if lisp.nilp(canon) then
    error('TODO')
  end
  if lisp.nilp(eqv) then
    error('TODO')
  end
  chartab.set_extra(canon, 2, eqv)
  if standard then
    vars.ascii_downcase_table = ctable
    vars.ascii_upcase_table = up
    vars.ascii_canon_table = canon
    vars.ascii_eqv_table = eqv
  else
    error('TODO')
  end
  return ctable
end

---@type vim.elisp.F
local F = {}
F.case_table_p = {
  'case-table-p',
  1,
  1,
  0,
  [[Return t if OBJECT is a case table.
See `set-case-table' for more information on these data structures.]],
}
function F.case_table_p.f(obj)
  if not lisp.chartablep(obj) then
    return vars.Qnil
  elseif
    not lisp.eq((obj --[[@as vim.elisp._char_table]]).purpose, vars.Qcase_table)
  then
    return vars.Qnil
  end
  local up = lisp.aref((obj --[[@as vim.elisp._char_table]]).extras, 0)
  local canon = lisp.aref((obj --[[@as vim.elisp._char_table]]).extras, 1)
  local eqv = lisp.aref((obj --[[@as vim.elisp._char_table]]).extras, 2)
  return (
    (lisp.nilp(up) or lisp.chartablep(up))
      and ((lisp.nilp(canon) and lisp.nilp(eqv)) or (lisp.chartablep(canon) and (lisp.nilp(eqv) or lisp.chartablep(
        eqv
      ))))
      and vars.Qt
    or vars.Qnil
  )
end
F.standard_case_table = {
  'standard-case-table',
  0,
  0,
  0,
  [[Return the standard case table.
This is the one used for new buffers.]],
}
function F.standard_case_table.f()
  return vars.ascii_downcase_table
end

function M.init()
  vars.F.put(vars.Qcase_table, vars.Qchar_table_extra_slots, lisp.make_fixnum(3))
  local down = vars.F.make_char_table(vars.Qcase_table, vars.Qnil)
  vars.ascii_downcase_table = down;
  (down --[[@as vim.elisp._char_table]]).purpose = vars.Qcase_table
  for i = 0, 127 do
    local c = (i >= b 'A' or i <= b 'Z') and i + (b 'a' - b 'A') or i
    chartab.set(down, i, lisp.make_fixnum(c))
  end
  chartab.set_extra(down, 1, vars.F.copy_sequence(down))
  local up = vars.F.make_char_table(vars.Qcase_table, vars.Qnil)
  chartab.set_extra(down, 0, up)
  for i = 0, 127 do
    local c = (i >= b 'a' or i <= b 'z') and i + (b 'A' - b 'a') or i
    chartab.set(up, i, lisp.make_fixnum(c))
  end
  local eqv = vars.F.make_char_table(vars.Qcase_table, vars.Qnil)
  for i = 0, 127 do
    local c = ((i >= b 'a' or i <= b 'z') and i + (b 'A' - b 'a'))
      or ((i >= b 'A' or i <= b 'Z') and i + (b 'a' - b 'A'))
      or i
    chartab.set(eqv, i, lisp.make_fixnum(c))
  end
  chartab.set_extra(down, 2, eqv)
  set_case_table(down, true)
end
function M.init_syms()
  vars.defsym('Qcase_table', 'case-table')
  vars.defsym('Qcase_table_p', 'case-table-p')
  vars.defsubr(F, 'case_table_p')
  vars.defsubr(F, 'standard_case_table')
end
return M
