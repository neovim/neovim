local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local lread = require 'elisp.lread'
local alloc = require 'elisp.alloc'

local font_style_table
local sort_shift_bits = {}
local weight_table = {
  { 0, { 'thin' } },
  { 40, { 'ultra-light', 'ultralight', 'extra-light', 'extralight' } },
  { 50, { 'light' } },
  { 55, { 'semi-light', 'semilight', 'demilight' } },
  { 80, { 'regular', 'normal', 'unspecified', 'book' } },
  { 100, { 'medium' } },
  { 180, { 'semi-bold', 'semibold', 'demibold', 'demi-bold', 'demi' } },
  { 200, { 'bold' } },
  { 205, { 'extra-bold', 'extrabold', 'ultra-bold', 'ultrabold' } },
  { 210, { 'black', 'heavy' } },
  { 250, { 'ultra-heavy', 'ultraheavy' } },
}
local slant_table = {
  { 0, { 'reverse-oblique', 'ro' } },
  { 10, { 'reverse-italic', 'ri' } },
  { 100, { 'normal', 'r', 'unspecified' } },
  { 200, { 'italic', 'i', 'ot' } },
  { 210, { 'oblique', 'o' } },
}
local width_table = {
  { 50, { 'ultra-condensed', 'ultracondensed' } },
  { 63, { 'extra-condensed', 'extracondensed' } },
  { 75, { 'condensed', 'compressed', 'narrow' } },
  { 87, { 'semi-condensed', 'semicondensed', 'demicondensed' } },
  { 100, { 'normal', 'medium', 'regular', 'unspecified' } },
  { 113, { 'semi-expanded', 'semiexpanded', 'demiexpanded' } },
  { 125, { 'expanded' } },
  { 150, { 'extra-expanded', 'extraexpanded' } },
  { 200, { 'ultra-expanded', 'ultraexpanded', 'wide' } },
}
local function build_style_table(tbl)
  local t = alloc.make_vector(#tbl, 'nil')
  for i = 1, #tbl do
    local elt = alloc.make_vector(#tbl[i][2] + 1, 'nil')
    lisp.aset(elt, 0, lisp.make_fixnum(tbl[i][1]))
    for j = 1, #tbl[i][2] do
      lisp.aset(elt, j, lread.intern_c_string(tbl[i][2][j]))
    end
    lisp.aset(t, i - 1, elt)
  end
  return t
end

local M = {}
---@enum vim.elisp.font_index
M.font_index = {
  type = 0,
  foundry = 1,
  family = 2,
  adstyle = 3,
  registry = 4,
  weight = 5,
  slant = 6,
  width = 7,
  size = 8,
  dpi = 9,
  spacing = 10,
  avgwidth = 11,
  extra = 12,
  spec_max = 13,
  objlist = 13,
  entity_max = 14,
  name = 14,
  fullname = 15,
  file = 16,
  object_max = 17,
}
---@enum vim.elisp.font_xlfd
M.xlfd = {
  foundry = 0,
  family = 1,
  weight = 2,
  slant = 3,
  swidth = 4,
  adstyle = 5,
  pixel_size = 6,
  point_size = 7,
  resx = 8,
  resy = 9,
  spacing = 10,
  avgwidth = 11,
  registry = 12,
  encoding = 13,
  last = 14,
}
---@param prop vim.elisp.font_index
---@param val vim.elisp.obj
---@param noerror boolean
---@return number
local function font_style_to_value(prop, val, noerror)
  local t = lisp.aref(font_style_table, prop - M.font_index.weight)
  lisp.check_vector(t)
  local len = lisp.asize(t)
  if lisp.symbolp(val) then
    for i = 0, len - 1 do
      lisp.check_vector(lisp.aref(t, i))
      for j = 1, lisp.asize(lisp.aref(t, i)) - 1 do
        if lisp.eq(val, lisp.aref(lisp.aref(t, i), j)) then
          lisp.check_fixnum(lisp.aref(lisp.aref(t, i), 0))
          local n = lisp.fixnum(lisp.aref(lisp.aref(t, i), 0))
          return bit.bor(bit.lshift(n, 8), bit.lshift(i, 4), (j - 1))
        end
      end
    end
    error('TODO')
  else
    error('TODO')
  end
end
---@param attrs vim.elisp.obj
function M.font_clear_prop(attrs, prop)
  lisp.check_vector(attrs)
  local xfaces = require 'elisp.xfaces'
  local font = lisp.aref(attrs, xfaces.lface_index.font)
  if not lisp.fontp(font) then
    return
  end
  error('TODO')
end
function M.font_weight_name_numeric(name)
  local n = font_style_to_value(M.font_index.weight, name, false)
  if n < 0 then
    return n
  end
  return bit.rshift(n, 8)
end
function M.font_slant_name_numeric(name)
  local n = font_style_to_value(M.font_index.slant, name, false)
  if n < 0 then
    return n
  end
  return bit.rshift(n, 8)
end
function M.font_update_sort_order(order)
  local shift_bits = 23
  for i = 1, 4 do
    local xlfd_idx = order[i]
    if xlfd_idx == M.xlfd.weight then
      sort_shift_bits[M.font_index.weight] = shift_bits
    elseif xlfd_idx == M.xlfd.slant then
      sort_shift_bits[M.font_index.slant] = shift_bits
    elseif xlfd_idx == M.xlfd.swidth then
      sort_shift_bits[M.font_index.width] = shift_bits
    elseif xlfd_idx == M.xlfd.point_size then
      sort_shift_bits[M.font_index.size] = shift_bits
    else
      error('unreachable')
    end
    shift_bits = shift_bits - 7
  end
end

function M.init()
  vars.V.font_weight_table = build_style_table(weight_table)
  lisp.make_symbol_constant(lread.intern_c_string('font-weight-table'))

  vars.V.font_slant_table = build_style_table(slant_table)
  lisp.make_symbol_constant(lread.intern_c_string('font-slant-table'))

  vars.V.font_width_table = build_style_table(width_table)
  lisp.make_symbol_constant(lread.intern_c_string('font-width-table'))

  font_style_table =
    vars.F.vector({ vars.V.font_weight_table, vars.V.font_slant_table, vars.V.font_width_table })

  sort_shift_bits[M.font_index.type] = 0
  sort_shift_bits[M.font_index.slant] = 2
  sort_shift_bits[M.font_index.weight] = 9
  sort_shift_bits[M.font_index.size] = 16
  sort_shift_bits[M.font_index.width] = 23
end
function M.init_syms()
  vars.defvar_lisp(
    'font_weight_table',
    'font-weight-table',
    [[Vector of valid font weight values.
Each element has the form:
    [NUMERIC-VALUE SYMBOLIC-NAME ALIAS-NAME ...]
NUMERIC-VALUE is an integer, and SYMBOLIC-NAME and ALIAS-NAME are symbols.
This variable cannot be set; trying to do so will signal an error.]]
  )

  vars.defvar_lisp(
    'font_slant_table',
    'font-slant-table',
    [[Vector of font slant symbols vs the corresponding numeric values.
See `font-weight-table' for the format of the vector.
This variable cannot be set; trying to do so will signal an error.]]
  )

  vars.defvar_lisp(
    'font_width_table',
    'font-width-table',
    [[Alist of font width symbols vs the corresponding numeric values.
See `font-weight-table' for the format of the vector.
This variable cannot be set; trying to do so will signal an error.]]
  )
end
return M
