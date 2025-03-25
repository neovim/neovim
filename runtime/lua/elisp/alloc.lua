local specpdl = require 'elisp.specpdl'
local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'

local M = {}
---@param len number
---@param init vim.elisp.obj|'zero'|'nil'
function M.make_vector(len, init)
  local v = {}
  ---@cast v vim.elisp._normal_vector
  v.size = len
  v.contents = {}
  ---@cast init vim.elisp.obj
  if init == 'zero' then
    ---Needed because make_vector is used before Qnil is inited
    local zero = lisp.make_fixnum(0)
    for i = 1, len do
      v.contents[i] = zero
    end
  elseif init ~= 'nil' and not lisp.nilp(init) then
    for i = 1, len do
      v.contents[i] = init
    end
  end
  return lisp.make_vectorlike_ptr(v, lisp.pvec.normal_vector)
end
---@param num number (float)
---@return vim.elisp.obj
function M.make_float(num)
  local new = lisp.make_empty_ptr(lisp.type.float)
  lisp.xfloat_init(new, num)
  return new
end
---@param data string
---@return vim.elisp.obj
function M.make_pure_c_string(data)
  local s = {}
  ---@cast s vim.elisp._string
  s.size_chars = nil
  s[2] = data
  s.intervals = nil
  return lisp.make_ptr(s, lisp.type.string)
end
---@param c string
---@return vim.elisp.obj
function M.make_string(c)
  if _G.vim_elisp_later then
    error('TODO: multibyte')
  end
  return M.make_unibyte_string(c)
end
---@param c string
---@return vim.elisp.obj
function M.make_unibyte_string(c)
  local s = {}
  ---@cast s vim.elisp._string
  s[2] = c
  s.size_chars = nil
  s.intervals = nil
  return lisp.make_ptr(s, lisp.type.string)
end
---@param c string
---@param nchars number|-1
---@return vim.elisp.obj
function M.make_multibyte_string(c, nchars)
  local s = {}
  ---@cast s vim.elisp._string
  s[2] = c
  s.size_chars = vim.str_utfindex(c, #c)
  assert(nchars == s.size_chars or nchars == -1)
  s.intervals = nil
  return lisp.make_ptr(s, lisp.type.string)
end
---@param data string
---@param nchars number|-1
---@param multibyte boolean
function M.make_specified_string(data, nchars, multibyte)
  if multibyte then
    return M.make_multibyte_string(data, nchars < 0 and -1 or nchars)
  end
  return M.make_unibyte_string(data)
end
---@param data string
---@param nchars number
---@return vim.elisp.obj
function M.make_string_from_bytes(data, nchars)
  if #data == nchars then
    return M.make_unibyte_string(data)
  end
  return M.make_multibyte_string(data, nchars)
end

---@param sym vim.elisp.obj
---@param name vim.elisp.obj
function M.set_symbol_name(sym, name)
  (sym --[[@as vim.elisp._symbol]]).name = name
end
---@param val vim.elisp.obj
---@param name vim.elisp.obj
function M.init_symbol(val, name)
  assert(lisp.baresymbolp(val))
  local p = val --[[@as vim.elisp._symbol]]
  M.set_symbol_name(val, name)
  lisp.set_symbol_plist(val, vars.Qnil)
  p.redirect = lisp.symbol_redirect.plainval
  lisp.set_symbol_val(p, nil)
  lisp.set_symbol_function(val, vars.Qnil)
  p.interned = lisp.symbol_interned.uninterned
  p.trapped_write = lisp.symbol_trapped_write.untrapped
  p.declared_special = nil --false
end

---@type vim.elisp.F
local F = {}
F.list = {
  'list',
  0,
  -2,
  0,
  [[Return a newly created list with specified arguments as elements.
Allows any number of arguments, including zero.
usage: (list &rest OBJECTS)]],
}
function F.list.fa(args)
  local val = vars.Qnil
  for i = #args, 1, -1 do
    val = vars.F.cons(args[i], val)
  end
  return val
end
---@param car vim.elisp.obj
---@param cdr vim.elisp.obj
---@return vim.elisp.obj
M.cons = function(car, cdr)
  local val = lisp.make_empty_ptr(lisp.type.cons)
  lisp.xsetcar(val, car)
  lisp.xsetcdr(val, cdr)
  return val
end
F.cons =
  { 'cons', 2, 2, 0, [[Create a new cons, give it CAR and CDR as components, and return it.]] }
function F.cons.f(car, cdr)
  return M.cons(car, cdr)
end
F.purecopy = {
  'purecopy',
  1,
  1,
  0,
  [[Make a copy of object OBJ in pure storage.
Recursively copies contents of vectors and cons cells.
Does not copy symbols.  Copies strings without text properties.]],
}
function F.purecopy.f(obj)
  return obj
end
F.make_vector = {
  'make-vector',
  2,
  2,
  0,
  [[Return a newly created vector of length LENGTH, with each element being INIT.
See also the function `vector'.]],
}
function F.make_vector.f(length, init)
  lisp.check_type(lisp.fixnatp(length), vars.Qwholenump, length)
  return M.make_vector(lisp.fixnum(length), init)
end
---@param name vim.elisp.obj
---@return vim.elisp.obj
function M.make_symbol(name)
  local val = lisp.make_empty_ptr(lisp.type.symbol)
  M.init_symbol(val, name)
  return val
end
F.make_symbol = {
  'make-symbol',
  1,
  1,
  0,
  [[Return a newly allocated uninterned symbol whose name is NAME.
Its value is void, and its function definition and property list are nil.]],
}
function F.make_symbol.f(name)
  lisp.check_string(name)
  return M.make_symbol(name)
end
F.vector = {
  'vector',
  0,
  -2,
  0,
  [[Return a newly created vector with specified arguments as elements.
Allows any number of arguments, including zero.
usage: (vector &rest OBJECTS)]],
}
function F.vector.fa(args)
  local vec = M.make_vector(#args, 'nil')
  for i = 1, #args do
    (vec --[[@as vim.elisp._normal_vector]]).contents[i] = args[i]
  end
  return vec
end
F.make_byte_code = {
  'make-byte-code',
  4,
  -2,
  0,
  [[Create a byte-code object with specified arguments as elements.
The arguments should be the ARGLIST, bytecode-string BYTE-CODE, constant
vector CONSTANTS, maximum stack size DEPTH, (optional) DOCSTRING,
and (optional) INTERACTIVE-SPEC.
The first four arguments are required; at most six have any
significance.
The ARGLIST can be either like the one of `lambda', in which case the arguments
will be dynamically bound before executing the byte code, or it can be an
integer of the form NNNNNNNRMMMMMMM where the 7bit MMMMMMM specifies the
minimum number of arguments, the 7-bit NNNNNNN specifies the maximum number
of arguments (ignoring &rest) and the R bit specifies whether there is a &rest
argument to catch the left-over arguments.  If such an integer is used, the
arguments will not be dynamically bound but will be instead pushed on the
stack before executing the byte-code.
usage: (make-byte-code ARGLIST BYTE-CODE CONSTANTS DEPTH &optional DOCSTRING INTERACTIVE-SPEC &rest ELEMENTS)]],
}
function F.make_byte_code.fa(args)
  local cidx = lisp.compiled_idx
  if
    not (
      (
        lisp.fixnump(args[cidx.arglist])
        or lisp.consp(args[cidx.arglist])
        or lisp.nilp(args[cidx.arglist])
      )
      and lisp.stringp(args[cidx.bytecode])
      and not lisp.string_multibyte(args[cidx.bytecode])
      and lisp.vectorp(args[cidx.constants])
      and lisp.fixnatp(args[cidx.stack_depth])
    )
  then
    require 'elisp.signal'.error('Invalid byte-code object')
  end
  local val = vars.F.vector(args) --[[@as vim.elisp._normal_vector]]
  return lisp.make_vectorlike_ptr(val, lisp.pvec.compiled)
end
F.make_closure = {
  'make-closure',
  1,
  -2,
  0,
  [[Create a byte-code closure from PROTOTYPE and CLOSURE-VARS.
Return a copy of PROTOTYPE, a byte-code object, with CLOSURE-VARS
replacing the elements in the beginning of the constant-vector.
usage: (make-closure PROTOTYPE &rest CLOSURE-VARS)]],
}
function F.make_closure.fa(args)
  local protofn = args[1]
  lisp.check_type(lisp.compiledp(protofn), vars.Qbyte_code_function_p, protofn)
  local protovec = (protofn --[[@as vim.elisp._compiled]]).contents
  local proto_constvec = protovec[lisp.compiled_idx.constants]
  local constsize = lisp.asize(proto_constvec)
  local nvars = #args - 1
  if nvars > constsize then
    require 'elisp.signal'.error('Closure vars do not fit in constvec')
  end
  local constvec = M.make_vector(constsize, 'nil')
  for i = 0, constsize - 1 do
    lisp.aset(constvec, i, args[i + 2] or lisp.aref(proto_constvec, i))
  end
  local protosize = lisp.asize(protofn)
  local v = M.make_vector(protosize, 'nil');
  (v --[[@as vim.elisp._vectorlike]]).header = (protofn --[[@as vim.elisp._vectorlike]]).header
  for i = 0, protosize - 1 do
    lisp.aset(v, i, lisp.aref(protofn, i))
  end
  (v --[[@as vim.elisp._compiled]]).contents[lisp.compiled_idx.constants] = constvec
  return v
end
F.garbage_collect = {
  'garbage-collect',
  0,
  0,
  '',
  [[Reclaim storage for Lisp objects no longer needed.
Garbage collection happens automatically if you cons more than
`gc-cons-threshold' bytes of Lisp data since previous garbage collection.
`garbage-collect' normally returns a list with info on amount of space in use,
where each entry has the form (NAME SIZE USED FREE), where:
- NAME is a symbol describing the kind of objects this entry represents,
- SIZE is the number of bytes used by each one,
- USED is the number of those objects that were found live in the heap,
- FREE is the number of those objects that are not live but that Emacs
  keeps around for future allocations (maybe because it does not know how
  to return them to the OS).

However, if there was overflow in pure space, and Emacs was dumped
using the \"unexec\" method, `garbage-collect' returns nil, because
real GC can't be done.

Note that calling this function does not guarantee that absolutely all
unreachable objects will be garbage-collected.  Emacs uses a
mark-and-sweep garbage collector, but is conservative when it comes to
collecting objects in some circumstances.

For further details, see Info node `(elisp)Garbage Collection'.]],
}
function F.garbage_collect.f()
  collectgarbage()
  return vars.Qnil
end
F.record = {
  'record',
  1,
  -2,
  0,
  [[Create a new record.
TYPE is its type as returned by `type-of'; it should be either a
symbol or a type descriptor.  SLOTS is used to initialize the record
slots with shallow copies of the arguments.
usage: (record TYPE &rest SLOTS)]],
}
function F.record.fa(args)
  local elems = {}
  for k, v in ipairs(args) do
    elems[k] = v
  end
  ---@type vim.elisp._record
  local vec = {
    size = #args,
    contents = elems,
  }
  return lisp.make_vectorlike_ptr(vec, lisp.pvec.record)
end
F.make_marker =
  { 'make-marker', 0, 0, 0, [[Return a newly allocated marker which does not point at any place.]] }
function F.make_marker.f()
  local nvim = require 'elisp.nvim'
  return nvim.marker_make()
end
function M.make_bool_vector(length, init)
  local v = {}
  ---@cast v vim.elisp._bool_vector
  v.contents = {}
  for i = 1, length do
    v.contents[i] = not lisp.nilp(init)
  end
  return lisp.make_vectorlike_ptr(v, lisp.pvec.bool_vector)
end
F.make_bool_vector = {
  'make-bool-vector',
  2,
  2,
  0,
  [[Return a new bool-vector of length LENGTH, using INIT for each element.
LENGTH must be a number.  INIT matters only in whether it is t or nil.]],
}
function F.make_bool_vector.f(length, init)
  lisp.check_fixnat(length)
  return M.make_bool_vector(lisp.fixnum(length), init)
end

function M.init_syms()
  vars.defsubr(F, 'list')
  vars.defsubr(F, 'cons')
  vars.defsubr(F, 'purecopy')
  vars.defsubr(F, 'make_vector')
  vars.defsubr(F, 'make_symbol')
  vars.defsubr(F, 'vector')
  vars.defsubr(F, 'make_byte_code')
  vars.defsubr(F, 'make_closure')
  vars.defsubr(F, 'garbage_collect')
  vars.defsubr(F, 'record')
  vars.defsubr(F, 'make_marker')
  vars.defsubr(F, 'make_bool_vector')

  vars.defsym('Qchar_table_extra_slots', 'char-table-extra-slots')
end
return M
