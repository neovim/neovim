local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local alloc = require 'elisp.alloc'
local M = {}

---@type vim.elisp.F
local F = {}
---@param num vim.elisp.obj
---@return number (float)
local function extract_float(num)
  lisp.check_number(num)
  return lisp.xfloatint(num)
end
F.atan = {
  'atan',
  1,
  2,
  0,
  [[Return the inverse tangent of the arguments.
If only one argument Y is given, return the inverse tangent of Y.
If two arguments Y and X are given, return the inverse tangent of Y
divided by X, i.e. the angle in radians between the vector (X, Y)
and the x-axis.]],
}
function F.atan.f(y, x)
  local d = extract_float(y)
  if lisp.nilp(x) then
    d = math.atan(d)
  else
    error('TODO')
  end
  return alloc.make_float(d)
end
F.exp = { 'exp', 1, 1, 0, [[Return the exponential base e of ARG.]] }
function F.exp.f(arg)
  local d = extract_float(arg)
  d = math.exp(d)
  return alloc.make_float(d)
end

function M.init_syms()
  vars.defsubr(F, 'atan')
  vars.defsubr(F, 'exp')
end
return M
