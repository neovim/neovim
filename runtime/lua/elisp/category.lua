local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local alloc = require 'elisp.alloc'
local signal = require 'elisp.signal'
local nvim = require 'elisp.nvim'
local b = require 'elisp.bytes'
local chars = require 'elisp.chars'
local chartab = require 'elisp.chartab'
local fns = require 'elisp.fns'

local M = {}

---@type vim.elisp.F
local F = {}
local function categoryp(c)
  return lisp.ranged_fixnump(0x20, c, 0x7e)
end
local function check_category(c)
  lisp.check_type(categoryp(c), vars.Qcategoryp, c)
end
local function check_category_table(tbl)
  if lisp.nilp(tbl) then
    return nvim.bvar(true, 'category_table')
  end
  error('TODO')
end
local function category_docstring(tbl, c)
  return lisp.aref(vars.F.char_table_extra_slot(tbl, lisp.make_fixnum(0)), c - b ' ')
end
local function set_category_docstring(tbl, c, docstring)
  lisp.aset(vars.F.char_table_extra_slot(tbl, lisp.make_fixnum(0)), c - b ' ', docstring)
end
F.define_category = {
  'define-category',
  2,
  3,
  0,
  [[Define CATEGORY as a category which is described by DOCSTRING.
CATEGORY should be an ASCII printing character in the range ` ' to `~'.
DOCSTRING is the documentation string of the category.  The first line
should be a terse text (preferably less than 16 characters),
and the rest lines should be the full description.
The category is defined only in category table TABLE, which defaults to
the current buffer's category table.]],
}
function F.define_category.f(category, docstring, tbl)
  check_category(category)
  lisp.check_string(docstring)
  tbl = check_category_table(tbl)
  if not lisp.nilp(category_docstring(tbl, lisp.fixnum(category))) then
    signal.error("Category `%c' is already defined", lisp.fixnum(category))
  end
  set_category_docstring(tbl, lisp.fixnum(category), docstring)
  return vars.Qnil
end
local function hash_get_category_set(ctable, category_set)
  if
    lisp.nilp(lisp.aref((ctable --[[@as vim.elisp._char_table]]).extras, 1))
  then
    chartab.set_extra(ctable, 1, vars.F.make_hash_table(vars.QCtest, vars.Qequal))
  end
  local h = lisp.aref((ctable --[[@as vim.elisp._char_table]]).extras, 1) --[[@as vim.elisp._hash_table]]
  local i, hash = fns.hash_lookup(h, category_set)
  if i >= 0 then
    return lisp.aref(h.key_and_value, 2 * i)
  end
  fns.hash_put(h, category_set, vars.Qnil, hash)
  return category_set
end
F.modify_category_entry = {
  'modify-category-entry',
  2,
  4,
  0,
  [[Modify the category set of CHARACTER by adding CATEGORY to it.
The category is changed only for table TABLE, which defaults to
the current buffer's category table.
CHARACTER can be either a single character or a cons representing the
lower and upper ends of an inclusive character range to modify.
CATEGORY must be a category name (a character between ` ' and `~').
Use `describe-categories' to see existing category names.
If optional fourth argument RESET is non-nil,
then delete CATEGORY from the category set instead of adding it.]],
}
function F.modify_category_entry.f(character, category, ctable, reset)
  local start, end_
  if lisp.fixnump(character) then
    chars.check_character(character)
    start = lisp.fixnum(character)
    end_ = start
  else
    lisp.check_cons(character)
    chars.check_character(lisp.xcar(character))
    chars.check_character(lisp.xcdr(character))
    start = lisp.fixnum(lisp.xcar(character))
    end_ = lisp.fixnum(lisp.xcdr(character))
  end
  check_category(category)
  ctable = check_category_table(ctable)
  if lisp.nilp(category_docstring(ctable, lisp.fixnum(category))) then
    signal.error('Undefined category: %c', lisp.fixnum(category))
  end
  local set_value = lisp.nilp(reset)
  while start <= end_ do
    local fromptr = { start }
    local toptr = { end_ }
    local category_set = chartab.char_table_ref_and_range(ctable, start, fromptr, toptr)
    if lisp.bool_vector_bitref(category_set, lisp.fixnum(category)) ~= lisp.nilp(reset) then
      category_set = vars.F.copy_sequence(category_set)
      lisp.bool_vector_set(category_set, lisp.fixnum(category), set_value)
      category_set = hash_get_category_set(ctable, category_set)
      chartab.set_range(ctable, start, toptr[1], category_set)
    end
    start = toptr[1] + 1
  end
  return vars.Qnil
end
F.standard_category_table = {
  'standard-category-table',
  0,
  0,
  0,
  [[Return the standard category table.
This is the one used for new buffers.]],
}
function F.standard_category_table.f()
  return vars.standard_category_table
end

function M.init()
  vars.F.put(vars.Qcategory_table, vars.Qchar_table_extra_slots, lisp.make_fixnum(2))
  vars.standard_category_table = vars.F.make_char_table(vars.Qcategory_table, vars.Qnil)
  vars
    .standard_category_table --[[@as vim.elisp._char_table]]
    .default =
    vars.F.make_bool_vector(lisp.make_fixnum(128), vars.Qnil)
  vars.F.set_char_table_extra_slot(
    vars.standard_category_table,
    lisp.make_fixnum(0),
    alloc.make_vector(95, 'nil')
  )
end
function M.init_syms()
  vars.defsubr(F, 'define_category')
  vars.defsubr(F, 'modify_category_entry')
  vars.defsubr(F, 'standard_category_table')

  vars.defsym('Qcategory_table', 'category-table')
  vars.defsym('Qcategoryp', 'categoryp')
end
return M
