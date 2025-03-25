local lisp = require 'elisp.lisp'
local signal = require 'elisp.signal'
local vars = require 'elisp.vars'
local specpdl = require 'elisp.specpdl'
local eval = require 'elisp.eval'
local fns = require 'elisp.fns'
local data = require 'elisp.data'
local handler = require 'elisp.handler'

local ins = {
  stack_ref = 0,
  stack_ref1 = 1,
  stack_ref2 = 2,
  stack_ref3 = 3,
  stack_ref4 = 4,
  stack_ref5 = 5,
  stack_ref6 = 6,
  stack_ref7 = 7,
  varref = 8,
  varref1 = 9,
  varref2 = 10,
  varref3 = 11,
  varref4 = 12,
  varref5 = 13,
  varref6 = 14,
  varref7 = 15,
  varset = 16,
  varset1 = 17,
  varset2 = 18,
  varset3 = 19,
  varset4 = 20,
  varset5 = 21,
  varset6 = 22,
  varset7 = 23,
  varbind = 24,
  varbind1 = 25,
  varbind2 = 26,
  varbind3 = 27,
  varbind4 = 28,
  varbind5 = 29,
  varbind6 = 30,
  varbind7 = 31,
  call = 32,
  call1 = 33,
  call2 = 34,
  call3 = 35,
  call4 = 36,
  call5 = 37,
  call6 = 38,
  call7 = 39,
  unbind = 40,
  unbind1 = 41,
  unbind2 = 42,
  unbind3 = 43,
  unbind4 = 44,
  unbind5 = 45,
  unbind6 = 46,
  unbind7 = 47,
  pophandler = 48,
  pushconditioncase = 49,
  pushcatch = 50,
  nth = 56,
  symbolp = 57,
  consp = 58,
  stringp = 59,
  listp = 60,
  eq = 61,
  memq = 62,
  ['not'] = 63,
  car = 64,
  cdr = 65,
  cons = 66,
  list1 = 67,
  list2 = 68,
  list3 = 69,
  list4 = 70,
  length = 71,
  aref = 72,
  aset = 73,
  symbol_value = 74,
  symbol_function = 75,
  set = 76,
  fset = 77,
  get = 78,
  substring = 79,
  concat2 = 80,
  concat3 = 81,
  concat4 = 82,
  sub1 = 83,
  add1 = 84,
  eqlsign = 85,
  gtr = 86,
  lss = 87,
  leq = 88,
  geq = 89,
  diff = 90,
  negate = 91,
  plus = 92,
  max = 93,
  min = 94,
  mult = 95,
  point = 96,
  --save_current_buffer_OBSOLETE=97,
  goto_char = 98,
  insert = 99,
  point_max = 100,
  point_min = 101,
  char_after = 102,
  following_char = 103,
  preceding_char = 104,
  current_column = 105,
  indent_to = 106,
  eolp = 108,
  eobp = 109,
  bolp = 110,
  bobp = 111,
  current_buffer = 112,
  set_buffer = 113,
  save_current_buffer = 114,
  --interactive_p=116,
  forward_char = 117,
  forward_word = 118,
  skip_chars_forward = 119,
  skip_chars_backward = 120,
  forward_line = 121,
  char_syntax = 122,
  buffer_substring = 123,
  delete_region = 124,
  narrow_to_region = 125,
  widen = 126,
  end_of_line = 127,
  constant2 = 129,
  ['goto'] = 130,
  gotoifnil = 131,
  gotoifnonnil = 132,
  gotoifnilelsepop = 133,
  gotoifnonnilelsepop = 134,
  ['return'] = 135,
  discard = 136,
  dup = 137,
  save_excursion = 138,
  --save_window_excursion=139,
  save_restriction = 140,
  --catch=141,
  unwind_protect = 142,
  --condition_case=143,
  --temp_output_buffer_setup=144,
  --temp_output_buffer_show=145,
  set_marker = 147,
  match_beginning = 148,
  match_end = 149,
  upcase = 150,
  downcase = 151,
  stringeqlsign = 152,
  stringlss = 153,
  equal = 154,
  nthcdr = 155,
  elt = 156,
  member = 157,
  assq = 158,
  nreverse = 159,
  setcar = 160,
  setcdr = 161,
  car_safe = 162,
  cdr_safe = 163,
  nconc = 164,
  quo = 165,
  rem = 166,
  numberp = 167,
  integerp = 168,
  listN = 175,
  concatN = 176,
  insertN = 177,
  stack_set = 178,
  stack_set2 = 179,
  discardN = 182,
  switch = 183,
  constant = 192,
}

local M = {}
M.ins = ins
---@type table<vim.elisp.obj,fun(vectorp:vim.elisp.obj[],stack:vim.elisp.obj[]):vim.elisp.obj>
M._cache = {}
local rev_ins = {}
for k, v in pairs(ins) do
  rev_ins[v] = k
end
local function debug_print(stack, op)
  vars.F.Xprint(stack)
  print(vim.inspect(op <= ins.constant and rev_ins[op] or 'constant0' .. op - ins.constant))
end

---@param fun vim.elisp.obj
---@param args_template number
---@param args vim.elisp.obj[]
---@return vim.elisp.obj
function M.exec_byte_code(fun, args_template, args)
  local cidx = lisp.compiled_idx
  local tfun = (fun --[[@as vim.elisp._compiled]]).contents --[[@as (vim.elisp.obj[])]]
  local vector = tfun[cidx.constants]
  local vectorp = (vector --[[@as vim.elisp._compiled]]).contents --[[@as (vim.elisp.obj[])]]
  local stack = {}

  local rest = bit.band(args_template, 128) ~= 0
  local mandatory = bit.band(args_template, 127)
  local nonreset = bit.rshift(args_template, 8)
  local nargs = #args
  if not (mandatory <= nargs and (rest or nargs <= nonreset)) then
    vars.F.signal(
      vars.Qwrong_number_of_arguments,
      lisp.list(
        vars.F.cons(lisp.make_fixnum(mandatory), lisp.make_fixnum(nonreset)),
        lisp.make_fixnum(nargs)
      )
    )
  end
  local pushedargs = math.min(nonreset, nargs)
  for _ = 1, pushedargs do
    table.insert(stack, table.remove(args, 1))
  end
  if nonreset < nargs then
    table.insert(stack, vars.F.list(args))
  else
    for _ = nargs - (rest and 1 or 0), nonreset - 1 do
      table.insert(stack, vars.Qnil)
    end
  end

  if M._cache[fun] then
    return M._cache[fun](vectorp, stack)
  end
  --TODO: include file name
  return require 'elisp.comp-lisp-to-lua'.compiled_to_fun(fun)(vectorp, stack)
end
---@type vim.elisp.F
local F = {}
F.byte_code = {
  'byte-code',
  3,
  3,
  0,
  [[Function used internally in byte-compiled code.
The first argument, BYTESTR, is a string of byte code;
the second, VECTOR, a vector of constants;
the third, MAXDEPTH, the maximum stack depth used in this function.
If the third argument is incorrect, Emacs may crash.]],
}
function F.byte_code.f(bytestr, vector, maxdepth)
  if not (lisp.stringp(bytestr) and lisp.vectorp(vector) and lisp.fixnatp(maxdepth)) then
    signal.error('Invalid byte-code')
  end
  if lisp.string_multibyte(bytestr) then
    bytestr = vars.F.string_as_unibyte(bytestr)
  end
  local fun = vars.F.make_byte_code({ vars.Qnil, bytestr, vector, maxdepth })
  return M.exec_byte_code(fun, 0, {})
end
function M.init_syms()
  vars.defsubr(F, 'byte_code')
end
return M
