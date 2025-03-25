local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local lread = require 'elisp.lread'
local signal = require 'elisp.signal'
local b = require 'elisp.bytes'

local M = {}

---@type vim.elisp.F
local F = {}
F.assoc_string = {
  'assoc-string',
  2,
  3,
  0,
  [[Like `assoc' but specifically for strings (and symbols).

This returns the first element of LIST whose car matches the string or
symbol KEY, or nil if no match exists.  When performing the
comparison, symbols are first converted to strings, and unibyte
strings to multibyte.  If the optional arg CASE-FOLD is non-nil, both
KEY and the elements of LIST are upcased for comparison.

Unlike `assoc', KEY can also match an entry in LIST consisting of a
single string, rather than a cons cell whose car is a string.]],
}
function F.assoc_string.f(key, list, case_fold)
  if lisp.symbolp(key) then
    key = vars.F.symbol_name(key)
  end
  while lisp.consp(list) do
    local tem
    local elt = lisp.xcar(list)
    local thiscar = lisp.consp(elt) and lisp.xcar(elt) or elt
    if lisp.symbolp(thiscar) then
      thiscar = vars.F.symbol_name(thiscar)
    elseif not lisp.stringp(thiscar) then
      goto continue
    end
    tem = vars.F.compare_strings(
      thiscar,
      lisp.make_fixnum(0),
      vars.Qnil,
      key,
      lisp.make_fixnum(0),
      vars.Qnil,
      case_fold
    )
    if lisp.eq(tem, vars.Qt) then
      return elt
    end
    ::continue::
    list = lisp.xcdr(list)
  end
  return vars.Qnil
end
---@param str vim.elisp.obj
---@param regexps vim.elisp.obj
---@param ignore_case boolean
---@return boolean
local function match_regexps(str, regexps, ignore_case)
  while lisp.consp(regexps) do
    error('TODO')
  end
  return true
end
F.all_completions = {
  'all-completions',
  2,
  4,
  0,
  [[Search for partial matches of STRING in COLLECTION.

Test each possible completion specified by COLLECTION
to see if it begins with STRING.  The possible completions may be
strings or symbols.  Symbols are converted to strings before testing,
by using `symbol-name'.

The value is a list of all the possible completions that match STRING.

If COLLECTION is an alist, the keys (cars of elements) are the
possible completions.  If an element is not a cons cell, then the
element itself is the possible completion.
If COLLECTION is a hash-table, all the keys that are strings or symbols
are the possible completions.
If COLLECTION is an obarray, the names of all symbols in the obarray
are the possible completions.

COLLECTION can also be a function to do the completion itself.
It receives three arguments: STRING, PREDICATE and t.
Whatever it returns becomes the value of `all-completions'.

If optional third argument PREDICATE is non-nil, it must be a function
of one or two arguments, and is used to test each possible completion.
A possible completion is accepted only if PREDICATE returns non-nil.

The argument given to PREDICATE is either a string or a cons cell (whose
car is a string) from the alist, or a symbol from the obarray.
If COLLECTION is a hash-table, PREDICATE is called with two arguments:
the string key and the associated value.

To be acceptable, a possible completion must also match all the regexps
in `completion-regexp-list' (unless COLLECTION is a function, in
which case that function should itself handle `completion-regexp-list').

An obsolete optional fourth argument HIDE-SPACES is still accepted for
backward compatibility.  If non-nil, strings in COLLECTION that start
with a space are ignored unless STRING itself starts with a space.]],
}
function F.all_completions.f(str, collection, predicate, hide_spaces)
  local typ = lisp.hashtablep(collection) and 3
    or lisp.vectorp(collection) and 2
    or (lisp.nilp(collection) or (lisp.consp(collection) and not lisp.functionp(collection))) and 1
    or 0
  lisp.check_string(str)
  if typ == 0 then
    return vars.F.funcall { collection, str, predicate, vars.Qt }
  end
  local allmatches = vars.Qnil
  local bucket = allmatches
  local obsize = 0
  local idx = 0
  if typ == 2 then
    collection = lread.obarray_check(collection)
    obsize = lisp.asize(collection)
    bucket = lisp.aref(collection, idx)
  end
  local zero = lisp.make_fixnum(0)
  local tail = collection
  local elt, eltstring
  while true do
    ::continue::
    if typ == 1 then
      error('TODO')
    elseif typ == 2 then
      if not lisp.eq(bucket, zero) then
        if not lisp.symbolp(bucket) then
          signal.error('Bad data in guts of obarray')
        end
        elt = bucket
        eltstring = elt
        if
          (bucket --[[@as vim.elisp._symbol]]).next
        then
          bucket = (bucket --[[@as vim.elisp._symbol]]).next
        else
          bucket = zero
        end
      elseif (idx + 1) >= obsize then
        idx = idx + 1
        break
      else
        idx = idx + 1
        bucket = lisp.aref(collection, idx)
        goto continue
      end
    else
      assert(typ == 3)
      error('TODO')
    end
    if lisp.symbolp(eltstring) then
      eltstring = vars.F.symbol_name(eltstring)
    end
    if
      lisp.stringp(eltstring)
      and lisp.schars(str) <= lisp.schars(eltstring)
      and (lisp.nilp(hide_spaces) or (lisp.sbytes(str) > 0 and lisp.sref(str, 0) == b ' ') or lisp.sref(
        eltstring,
        0
      ) ~= b ' ')
      and (function()
        local tem = vars.F.compare_strings(
          eltstring,
          zero,
          lisp.make_fixnum(lisp.schars(str)),
          str,
          zero,
          lisp.make_fixnum(lisp.schars(str)),
          vars.V.completion_ignore_case
        )
        return lisp.eq(tem, vars.Qt)
      end)()
    then
      if
        not match_regexps(
          eltstring,
          vars.V.completion_regexp_list,
          not lisp.nilp(vars.V.completion_ignore_case)
        )
      then
        goto continue
      end
      if not lisp.nilp(predicate) then
        local tem
        if lisp.eq(predicate, vars.Qcommandp) then
          tem = vars.F.commandp(eltstring)
        elseif typ == 3 then
          error('TODO')
        else
          error('TODO')
        end
        if lisp.nilp(tem) then
          goto continue
        end
      end
      allmatches = vars.F.cons(eltstring, allmatches)
    end
  end
  return vars.F.nreverse(allmatches)
end

function M.init()
  vars.V.minibuffer_prompt_properties = lisp.list(vars.Qread_only, vars.Qt)
end
function M.init_syms()
  vars.defsubr(F, 'assoc_string')
  vars.defsubr(F, 'all_completions')

  vars.defvar_lisp(
    'minibuffer_prompt_properties',
    'minibuffer-prompt-properties',
    [[Text properties that are added to minibuffer prompts.
These are in addition to the basic `field' property, and stickiness
properties.]]
  )

  vars.defvar_bool(
    'completion_ignore_case',
    'completion-ignore-case',
    [[Non-nil means don't consider case significant in completion.
For file-name completion, `read-file-name-completion-ignore-case'
controls the behavior, rather than this variable.
For buffer name completion, `read-buffer-completion-ignore-case'
controls the behavior, rather than this variable.]]
  )
  vars.V.completion_ignore_case = vars.Qnil

  vars.defvar_lisp(
    'completion_regexp_list',
    'completion-regexp-list',
    [[List of regexps that should restrict possible completions.
The basic completion functions only consider a completion acceptable
if it matches all regular expressions in this list, with
`case-fold-search' bound to the value of `completion-ignore-case'.
See Info node `(elisp)Basic Completion', for a description of these
functions.

Do not set this variable to a non-nil value globally, as that is not
safe and will probably cause errors in completion commands.  This
variable should be only let-bound to non-nil values around calls to
basic completion functions like `try-completion' and `all-completions'.]]
  )
  vars.V.completion_regexp_list = vars.Qnil

  vars.defsym('Qread_only', 'read-only')
end
return M
