local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local b = require 'elisp.bytes'
local signal = require 'elisp.signal'
local alloc = require 'elisp.alloc'
local chars = require 'elisp.chars'
local M = {}

---@class vim.elisp.print.printcharfun
---@field write fun(s:string|number)
---@field out fun():string
---@field print_depth number
---@field being_printed table<number,vim.elisp.obj>

---@param x vim.elisp.obj
---@return string
function M.fixnum_to_string(x)
  return ('%d'):format(lisp.fixnum(x))
end
---@return vim.elisp.print.printcharfun
function M.make_printcharfun()
  local strbuf = require 'string.buffer'
  local out = strbuf.new(100)
  ---@type vim.elisp.print.printcharfun
  return {
    write = function(x)
      if type(x) == 'number' then
        x = chars.charstring(x)
      end
      out:put(x)
    end,
    out = function()
      return out:tostring()
    end,
    print_depth = 0,
    being_printed = {},
  }
end
---@param obj vim.elisp.obj
---@param escapeflag boolean
---@param printcharfun vim.elisp.print.printcharfun
function M.print_obj(obj, escapeflag, printcharfun)
  local out = {}
  if _G.vim_elisp_later then
    error('TODO: implement print_depth')
  end
  local base_depth = printcharfun.print_depth
  local stack = {}
  ::print_obj::
  local typ = lisp.xtype(obj)
  if lisp.nilp(vars.V.print_circle) then
    if printcharfun.print_depth >= 200 then
      signal.error('Apparently circular structure being printed')
    end
    for i = 0, printcharfun.print_depth - 1 do
      if printcharfun.being_printed[i] == obj then
        printcharfun.write(('#%d'):format(i))
        goto next_obj
      end
    end
    printcharfun.being_printed[printcharfun.print_depth] = obj
  else
    error('TODO')
  end
  printcharfun.print_depth = printcharfun.print_depth + 1
  if typ == lisp.type.int0 then
    if not lisp.nilp(vars.V.print_integers_as_characters) then
      error('TODO')
    else
      printcharfun.write(M.fixnum_to_string(obj))
    end
  elseif typ == lisp.type.string then
    if not escapeflag then
      if lisp.sbytes(obj) == lisp.schars(obj) then
        printcharfun.write(lisp.sdata(obj))
      else
        error('TODO')
      end
      goto break_
    end
    local multibyte = lisp.string_multibyte(obj)
    assert(lisp.sbytes(obj) == lisp.schars(obj) or not multibyte, 'TODO')
    local has_properties = lisp.string_intervals(obj)
    assert(not has_properties, 'TODO')
    printcharfun.write('"')
    local need_nohex = false
    for i = 0, lisp.sbytes(obj) - 1 do
      local c = lisp.sref(obj, i)
      if
        chars.singlebytecharp(c)
        and not chars.asciicharp(c)
        and not lisp.nilp(vars.V.print_escape_nonascii)
      then
        error('TODO')
      else
        if
          need_nohex and (
            (b '0' <= c and c <= b '9')
            or (b 'a' <= c and c <= b 'f')
            or (b 'A' <= c and c <= b 'F')
          )
        then
          error('TODO')
        elseif
          (c == b '\n' or c == b '\f') and not lisp.nilp(vars.V.print_escape_newlines)
          or c == b '"'
          or c == b '\\'
        then
          printcharfun.write('\\')
          printcharfun.write(c == b '\n' and 'n' or c == b '\f' and 'f' or c)
        elseif
          (b '\0' <= c and c <= b '\x1f' or c == b '\x7f')
          and not lisp.nilp(vars.V.print_escape_control_characters)
        then
          error('TODO')
        elseif not multibyte and chars.singlebytecharp(c) and not chars.asciicharp(c) then
          error('TODO')
        else
          printcharfun.write(c)
        end
        need_nohex = false
      end
    end
    printcharfun.write('"')
  elseif typ == lisp.type.symbol then
    local name = lisp.symbol_name(obj)
    local c =
      lisp.sref(name, (lisp.sref(name, 0) == b '-' or lisp.sref(name, 0) == b '+') and 1 or 0)
    local confusing = (((b '0' <= c and c <= b '9') or c == b '.') and error('TODO'))
      or c == b '?'
      or c == b '.'
    if not lisp.nilp(vars.V.print_gensym) and not lisp.symbolinternedininitialobarrayp(obj) then
      printcharfun.write('#:')
    elseif lisp.sbytes(name) == 0 then
      printcharfun.write('##')
    else
      for i = 0, lisp.sbytes(name) - 1 do
        c = lisp.sref(name, i)
        if
          escapeflag and c <= 32
          or c == b.no_break_space
          or string.char(c):match('[]"\\\';#(),`[]')
          or confusing
        then
          printcharfun.write('\\')
          confusing = false
        end
        printcharfun.write(c)
      end
    end
  elseif typ == lisp.type.cons then
    local print_quoted = not lisp.nilp(vars.V.print_quoted)
    if
      lisp.fixnump(vars.V.print_level)
      and printcharfun.print_depth > lisp.fixnum(vars.V.print_level)
    then
      printcharfun.write('...')
      goto break_
    elseif print_quoted and lisp.consp(lisp.xcdr(obj)) and lisp.nilp(lisp.xcdr(lisp.xcdr(obj))) then
      local c
      if lisp.eq(lisp.xcar(obj), vars.Qquote) then
        c = "'"
      elseif lisp.eq(lisp.xcar(obj), vars.Qfunction) then
        c = "#'"
      elseif lisp.eq(lisp.xcar(obj), vars.Qbackquote) then
        c = '`'
      elseif lisp.eq(lisp.xcar(obj), vars.Qcomma) or lisp.eq(lisp.xcar(obj), vars.Qcomma_at) then
        M.print_obj(lisp.xcar(obj), false, printcharfun)
        M.print_obj(lisp.xcar(lisp.xcdr(obj)), escapeflag, printcharfun)
        goto break_
      end
      if c then
        printcharfun.write(c)
        obj = lisp.xcar(lisp.xcdr(obj))
        printcharfun.print_depth = printcharfun.print_depth - 1
        goto print_obj
      end
    end
    table.insert(stack, {
      t = 'list',
      last = obj,
      tortoise = obj,
      n = 2,
      m = 2,
      tortoise_idx = 0,
    })
    printcharfun.write('(')
    obj = lisp.xcar(obj)
    goto print_obj
  elseif typ == lisp.type.vectorlike then
    local ptyp = lisp.pseudovector_type(obj)
    if _G.vim_elisp_later then
      error('TODO')
    end
    if ptyp == lisp.pvec.normal_vector then
      printcharfun.write('[')
      table.insert(stack, {
        t = 'vector',
        printed = 0,
        obj = obj,
        nobjs = lisp.asize(obj),
      })
      goto next_obj
    end
    if ptyp == lisp.pvec.hash_table then
      printcharfun.write('#s(hash-table size 0 data (')
      table.insert(stack, {
        t = 'hash',
        printed = 0,
        nobjs = 0,
      })
      goto next_obj
    end
    printcharfun.write(('#<No print for (PVEC 0x%x)>'):format(ptyp))
    --printcharfun.write('#<EMACS BUG: INVALID DATATYPE ')
    --printcharfun.write(('(PVEC 0x%x)'):format(ptyp))
    --printcharfun.write(' Save your buffers immediately and please report this bug>')
    --printcharfun.write(' Save your buffers immediately>')
  else
    printcharfun.write('#<EMACS BUG: INVALID DATATYPE ')
    printcharfun.write(('(0x%x)'):format(typ))
    --printcharfun.write(' Save your buffers immediately and please report this bug>')
    printcharfun.write(' Save your buffers immediately>')
  end
  ::break_::
  printcharfun.print_depth = printcharfun.print_depth - 1
  ::next_obj::
  if #stack > 0 then
    local e = stack[#stack]
    if e.t == 'hash' then
      if e.printed >= e.nobjs then
        printcharfun.write('))')
        table.remove(stack)
        printcharfun.print_depth = printcharfun.print_depth - 1
        goto next_obj
      end
      error('TODO')
    elseif e.t == 'list' then
      local next_ = lisp.xcdr(e.last)
      if lisp.nilp(next_) then
        printcharfun.write(')')
        table.remove(stack)
        printcharfun.print_depth = printcharfun.print_depth - 1
        goto next_obj
      elseif lisp.consp(next_) then
        if not lisp.nilp(vars.V.print_circle) then
          error('TODO')
        end
        printcharfun.write(' ')
        e.last = next_
        e.n = e.n - 1
        if e.n == 0 then
          e.tortoise_idx = e.tortoise_idx + e.m
          e.m = e.m * 2
          e.n = e.m
          e.tortoise = next_
        elseif next_ == e.tortoise then
          printcharfun.write(('. #%d)'):format(e.tortoise_idx))
          table.remove(stack)
          printcharfun.print_depth = printcharfun.print_depth - 1
          goto next_obj
        end
        obj = lisp.xcar(next_)
      else
        printcharfun.write(' . ')
        obj = next_
        e.t = 'rbrac'
      end
    elseif e.t == 'rbrac' then
      printcharfun.write(')')
      table.remove(stack)
      printcharfun.print_depth = printcharfun.print_depth - 1
      goto next_obj
    elseif e.t == 'vector' then
      if e.printed >= e.nobjs then
        printcharfun.write(']')
        table.remove(stack)
        printcharfun.print_depth = printcharfun.print_depth - 1
        goto next_obj
      end
      if e.printed > 0 then
        printcharfun.write(' ')
      end
      obj = lisp.aref(e.obj, e.printed)
      e.printed = e.printed + 1
    else
      error('TODO')
    end
    goto print_obj
  end
  assert(printcharfun.print_depth == base_depth)
  return table.concat(out, '')
end

---@type vim.elisp.F
local F = {}
F.prin1_to_string = {
  'prin1-to-string',
  1,
  3,
  0,
  [[Return a string containing the printed representation of OBJECT.
OBJECT can be any Lisp object.  This function outputs quoting characters
when necessary to make output that `read' can handle, whenever possible,
unless the optional second argument NOESCAPE is non-nil.  For complex objects,
the behavior is controlled by `print-level' and `print-length', which see.

OBJECT is any of the Lisp data types: a number, a string, a symbol,
a list, a buffer, a window, a frame, etc.

See `prin1' for the meaning of OVERRIDES.

A printed representation of an object is text which describes that object.]],
}
function F.prin1_to_string.f(obj, noescape, overrides)
  if _G.vim_elisp_later then
    error('TODO')
  end
  if not lisp.nilp(overrides) then
    error('TODO')
  end
  local printcharfun = M.make_printcharfun()
  M.print_obj(obj, lisp.nilp(noescape), printcharfun)
  obj = alloc.make_string(printcharfun.out())
  return obj
end
F.prin1 = {
  'prin1',
  1,
  3,
  0,
  [[Output the printed representation of OBJECT, any Lisp object.
Quoting characters are printed when needed to make output that `read'
can handle, whenever this is possible.  For complex objects, the behavior
is controlled by `print-level' and `print-length', which see.

OBJECT is any of the Lisp data types: a number, a string, a symbol,
a list, a buffer, a window, a frame, etc.

A printed representation of an object is text which describes that object.

Optional argument PRINTCHARFUN is the output stream, which can be one
of these:

   - a buffer, in which case output is inserted into that buffer at point;
   - a marker, in which case output is inserted at marker's position;
   - a function, in which case that function is called once for each
     character of OBJECT's printed representation;
   - a symbol, in which case that symbol's function definition is called; or
   - t, in which case the output is displayed in the echo area.

If PRINTCHARFUN is omitted, the value of `standard-output' (which see)
is used instead.

Optional argument OVERRIDES should be a list of settings for print-related
variables.  An element in this list can be the symbol t, which means "reset
all the values to their defaults".  Otherwise, an element should be a pair,
where the `car' or the pair is the setting symbol, and the `cdr' is the
value of the setting to use for this `prin1' call.

For instance:

  (prin1 object nil \\='((length . 100) (circle . t))).

See Info node `(elisp)Output Overrides' for a list of possible values.

As a special case, OVERRIDES can also simply be the symbol t, which
means "use default values for all the print-related settings".]],
}
function F.prin1.f(obj, printcharfun, overrides)
  if _G.vim_elisp_later then
    error('TODO')
  end
  assert(lisp.nilp(printcharfun), 'TODO')
  assert(lisp.nilp(overrides), 'TODO')
  local printcharfun_ = M.make_printcharfun()
  M.print_obj(obj, true, printcharfun_)
  print(printcharfun_.out())
  return obj
end

function M.init_syms()
  vars.defsubr(F, 'prin1_to_string')
  vars.defsubr(F, 'prin1')

  vars.defvar_bool(
    'print_integers_as_characters',
    'print-integers-as-characters',
    [[Non-nil means integers are printed using characters syntax.
Only independent graphic characters, and control characters with named
escape sequences such as newline, are printed this way.  Other
integers, including those corresponding to raw bytes, are printed
as numbers the usual way.]]
  )
  vars.V.print_integers_as_characters = vars.Qnil

  vars.defvar_bool(
    'print_escape_newlines',
    'print-escape-newlines',
    [[Non-nil means print newlines in strings as `\\n'.
Also print formfeeds as `\\f'.]]
  )
  vars.V.print_escape_newlines = vars.Qnil

  vars.defvar_bool(
    'print_escape_control_characters',
    'print-escape-control-characters',
    [[Non-nil means print control characters in strings as `\\OOO'.
\(OOO is the octal representation of the character code.)]]
  )
  vars.V.print_escape_control_characters = vars.Qnil

  vars.defvar_lisp(
    'print_circle',
    'print-circle',
    [[Non-nil means print recursive structures using #N= and #N# syntax.
If nil, printing proceeds recursively and may lead to
`max-lisp-eval-depth' being exceeded or an error may occur:
\"Apparently circular structure being printed.\"  Also see
`print-length' and `print-level'.
If non-nil, shared substructures anywhere in the structure are printed
with `#N=' before the first occurrence (in the order of the print
representation) and `#N#' in place of each subsequent occurrence,
where N is a positive decimal integer.]]
  )
  vars.V.print_circle = vars.Qnil

  vars.defvar_lisp(
    'print_gensym',
    'print-gensym',
    [[Non-nil means print uninterned symbols so they will read as uninterned.
I.e., the value of (make-symbol \"foobar\") prints as #:foobar.
When the uninterned symbol appears multiple times within the printed
expression, and `print-circle' is non-nil, in addition use the #N#
and #N= constructs as needed, so that multiple references to the same
symbol are shared once again when the text is read back.]]
  )
  vars.V.print_gensym = vars.Qnil

  vars.defvar_lisp(
    'print_level',
    'print-level',
    [[Maximum depth of list nesting to print before abbreviating.
A value of nil means no limit.  See also `eval-expression-print-level'.]]
  )
  vars.V.print_level = vars.Qnil

  vars.defvar_bool(
    'print_quoted',
    'print-quoted',
    [[Non-nil means print quoted forms with reader syntax.
I.e., (quote foo) prints as \\='foo, (function foo) as #\\='foo.]]
  )
  vars.V.print_quoted = vars.Qt

  vars.defvar_bool(
    'print_escape_nonascii',
    'print-escape-nonascii',
    [[Non-nil means print unibyte non-ASCII chars in strings as \\OOO.
\(OOO is the octal representation of the character code.)
Only single-byte characters are affected, and only in `prin1'.
When the output goes in a multibyte buffer, this feature is
enabled regardless of the value of the variable.]]
  )
  vars.V.print_escape_nonascii = vars.Qnil
end
return M
