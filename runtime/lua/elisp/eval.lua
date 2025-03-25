local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'
local specpdl = require 'elisp.specpdl'
local signal = require 'elisp.signal'
local data = require 'elisp.data'
local handler = require 'elisp.handler'
local overflow = require 'elisp.overflow'
local lread = require 'elisp.lread'
local alloc = require 'elisp.alloc'
local M = {}

---@return vim.elisp.obj
local function fetch_and_exec_byte_code(fun, args_template, args)
  if
    lisp.consp((fun --[[@as vim.elisp._compiled]]).contents[lisp.compiled_idx.bytecode])
  then
    error('TODO')
  end
  return require 'elisp.bytecode'.exec_byte_code(fun, args_template, args)
end
local function funcall_lambda(fun, args)
  local lexenv, syms_left
  local count = specpdl.index()
  if lisp.consp(fun) then
    if lisp.eq(lisp.xcar(fun), vars.Qclosure) then
      local cdr = lisp.xcdr(fun)
      if not lisp.consp(cdr) then
        signal.xsignal(vars.Qinvalid_function, fun)
      end
      fun = cdr
      lexenv = lisp.xcar(fun)
    else
      lexenv = vars.Qnil
    end
    syms_left = lisp.xcdr(fun)
    if lisp.consp(syms_left) then
      syms_left = lisp.xcar(syms_left)
    else
      signal.xsignal(vars.Qinvalid_function, fun)
    end
  elseif lisp.compiledp(fun) then
    syms_left = (fun --[[@as vim.elisp._compiled]]).contents[lisp.compiled_idx.arglist]
    if lisp.fixnump(syms_left) then
      return fetch_and_exec_byte_code(fun, lisp.fixnum(syms_left), args)
    end
    lexenv = vars.Qnil
  end
  local idx = 1
  local rest = false
  local optional = false
  local previous_rest = false
  while lisp.consp(syms_left) do
    local next_ = lisp.xcar(syms_left)
    if not lisp.symbolp(next_) then
      signal.xsignal(vars.Qinvalid_function, fun)
    end
    if lisp.eq(next_, vars.Qand_rest) then
      if rest or previous_rest then
        signal.xsignal(vars.Qinvalid_function, fun)
      end
      rest = true
      previous_rest = true
    elseif lisp.eq(next_, vars.Qand_optional) then
      if optional or rest or previous_rest then
        signal.xsignal(vars.Qinvalid_function, fun)
      end
      optional = true
    else
      local arg
      if rest then
        arg = vars.F.list({ unpack(args, idx) })
        idx = #args + 1
      elseif idx <= #args then
        arg = args[idx]
        idx = idx + 1
      elseif not optional then
        signal.xsignal(vars.Qwrong_number_of_arguments, fun, lisp.make_fixnum(#args))
      else
        arg = vars.Qnil
      end
      if not lisp.nilp(lexenv) and lisp.symbolp(next_) then
        lexenv = vars.F.cons(vars.F.cons(next_, arg), lexenv)
      else
        specpdl.bind(next_, arg)
      end
      previous_rest = false
    end
    syms_left = lisp.xcdr(syms_left)
  end
  if not lisp.nilp(syms_left) or previous_rest then
    signal.xsignal(vars.Qinvalid_function, fun)
  elseif idx <= #args then
    signal.xsignal(vars.Qwrong_number_of_arguments, fun, lisp.make_fixnum(idx))
  end
  if not lisp.eq(lexenv, vars.V.internal_interpreter_environment) then
    specpdl.bind(vars.Qinternal_interpreter_environment, lexenv)
  end
  local val
  if lisp.consp(fun) then
    val = vars.F.progn(lisp.xcdr(lisp.xcdr(fun)))
  else
    error('TODO')
  end
  return specpdl.unbind_to(count, val)
end
local function apply_lambda(fun, args, count)
  local arg_vector = {}
  local args_left = args
  for _ = 1, lisp.list_length(args) do
    local tem = vars.F.car(args_left)
    args_left = vars.F.cdr(args_left)
    tem = M.eval_sub(tem)
    table.insert(arg_vector, tem)
  end
  specpdl.set_backtrace_args(count, arg_vector)
  local val = funcall_lambda(fun, arg_vector)
  vars.lisp_eval_depth = vars.lisp_eval_depth - 1
  if specpdl.backtrace_debug_on_exit(count) then
    error('TODO')
  end
  return specpdl.unbind_to(specpdl.index() - 1, val)
end
local function apply1(fn, args)
  return lisp.nilp(arg) and vars.F.funcall({ fn }) or vars.F.apply({ fn, args })
end
---@param form vim.elisp.obj
---@return vim.elisp.obj
function M.eval_sub(form)
  if lisp.symbolp(form) then
    local lex_binding = vars.F.assq(form, vars.V.internal_interpreter_environment)
    return not lisp.nilp(lex_binding) and lisp.xcdr(lex_binding) or vars.F.symbol_value(form)
  end
  if not lisp.consp(form) then
    return form
  end

  vars.lisp_eval_depth = vars.lisp_eval_depth + 1
  if vars.lisp_eval_depth > lisp.fixnum(vars.V.max_lisp_eval_depth) then
    if lisp.fixnum(vars.V.max_lisp_eval_depth) < 100 then
      vars.V.max_lisp_eval_depth = lisp.make_fixnum(100)
    end
    if vars.lisp_eval_depth > lisp.fixnum(vars.V.max_lisp_eval_depth) then
      signal.xsignal(
        vars.Qexcessive_lisp_nesting,
        lisp.make_fixnum(vars.lisp_eval_depth --[[@as number]])
      )
    end
  end
  local original_fun = lisp.xcar(form)
  local original_args = lisp.xcdr(form)
  local val
  lisp.check_list(original_args)
  local count = specpdl.record_in_backtrace(original_fun, { original_args }, 'UNEVALLED')
  if not lisp.nilp(vars.V.debug_on_next_call) then
    error('TODO')
  end
  ::retry::
  local fun = original_fun
  if not lisp.symbolp(fun) then
    error('TODO')
  elseif not lisp.nilp(fun) then
    fun = (fun --[[@as vim.elisp._symbol]]).fn
    if lisp.symbolp(fun) then
      fun = data.indirect_function(fun)
    end
  end
  if lisp.subrp(fun) and not lisp.subr_native_compiled_dynp(fun) then
    local args_left = original_args
    local numargs = lisp.list_length(args_left)
    local t = fun --[[@as vim.elisp._subr]]
    if numargs < t.minargs or (t.maxargs >= 0 and numargs > t.maxargs) then
      signal.xsignal(vars.Qwrong_number_of_arguments, original_fun, lisp.make_fixnum(numargs))
    elseif t.maxargs == -1 then
      val = t.fn(args_left)
    elseif t.maxargs == -2 or t.maxargs > 8 then
      local vals = {}
      while lisp.consp(args_left) and #vals < numargs do
        local arg = lisp.xcar(args_left)
        args_left = lisp.xcdr(args_left)
        table.insert(vals, M.eval_sub(arg))
      end

      specpdl.set_backtrace_args(count, vals)
      val = t.fn(vals)
    else
      local argvals = {}
      for _ = 1, t.maxargs do
        table.insert(argvals, M.eval_sub(vars.F.car(args_left)))
        args_left = vars.F.cdr(args_left)
      end
      specpdl.set_backtrace_args(count, argvals)
      val = t.fn(unpack(argvals))
    end
  elseif
    lisp.compiledp(fun)
    or lisp.subr_native_compiled_dynp(fun)
    or lisp.module_functionp(fun)
  then
    return apply_lambda(fun, original_args, count)
  else
    if lisp.nilp(fun) then
      signal.xsignal(vars.Qvoid_function, original_fun)
    elseif not lisp.consp(fun) then
      signal.xsignal(vars.Qinvalid_function, original_fun)
    end
    local funcar = lisp.xcar(fun)
    if not lisp.symbolp(funcar) then
      signal.xsignal(vars.Qinvalid_function, original_fun)
    elseif lisp.eq(funcar, vars.Qautoload) then
      vars.F.autoload_do_load(fun, original_fun, vars.Qnil)
      goto retry
    elseif lisp.eq(funcar, vars.Qmacro) then
      local count1 = specpdl.index()
      specpdl.bind(
        vars.Qlexical_binding,
        lisp.nilp(vars.V.internal_interpreter_environment) and vars.Qnil or vars.Qt
      )
      local p = vars.V.internal_interpreter_environment
      local dynvars = vars.V.macroexp__dynvars
      while not lisp.nilp(p) do
        local e = lisp.xcar(p)
        if lisp.symbolp(e) then
          dynvars = vars.F.cons(e, dynvars)
        end
        p = lisp.xcdr(p)
      end
      if lisp.eq(dynvars, vars.V.macroexp__dynvars) then
        specpdl.bind(vars.Qmacroexp__dynvars, dynvars)
      end
      local exp = apply1(vars.F.cdr(fun), original_args)
      exp = specpdl.unbind_to(count1, exp)
      val = M.eval_sub(exp)
    elseif lisp.eq(funcar, vars.Qlambda) or lisp.eq(funcar, vars.Qclosure) then
      return apply_lambda(fun, original_args, count)
    else
      signal.xsignal(vars.Qinvalid_function, original_fun)
    end
  end
  vars.lisp_eval_depth = vars.lisp_eval_depth - 1
  if specpdl.backtrace_debug_on_exit(count) then
    error('TODO')
  end
  return specpdl.unbind_to(specpdl.index() - 1, assert(val, "DEV: function didn't return a value"))
end
function M.init_once()
  vars.run_hooks = vars.Qnil
end
function M.init()
  vars.lisp_eval_depth = 0
  if _G.vim_elisp_later then
    vars.F.make_variable_buffer_local(vars.Qlexical_binding)
  end
  vars.autoload_queue = vars.Qnil
  vars.signaling_function = vars.Qnil
end

---@type vim.elisp.F
local F = {}
F.setq = {
  'setq',
  0,
  -1,
  0,
  [[Set each SYM to the value of its VAL.
The symbols SYM are variables; they are literal (not evaluated).
The values VAL are expressions; they are evaluated.
Thus, (setq x (1+ y)) sets `x' to the value of `(1+ y)'.
The second VAL is not computed until after the first SYM is set, and so on;
each VAL can use the new value of variables set earlier in the `setq'.
The return value of the `setq' form is the value of the last VAL.
usage: (setq [SYM VAL]...)]],
}
function F.setq.f(args)
  local val = args
  local tail = args
  local nargs = 0
  while lisp.consp(tail) do
    local sym = lisp.xcar(tail)
    tail = lisp.xcdr(tail)
    if not lisp.consp(tail) then
      signal.xsignal(vars.Qwrong_type_argument, vars.Qsetq, lisp.make_fixnum(nargs + 1))
    end
    local arg = lisp.xcar(tail)
    tail = lisp.xcdr(tail)
    val = M.eval_sub(arg)
    local lex_binding = lisp.symbolp(sym)
        and vars.F.assq(sym, vars.V.internal_interpreter_environment)
      or vars.Qnil
    if not lisp.nilp(lex_binding) then
      lisp.xsetcdr(lex_binding, val)
    else
      vars.F.set(sym, val)
    end
    nargs = nargs + 2
  end
  return val
end
F.let = {
  'let',
  1,
  -1,
  0,
  [[Bind variables according to VARLIST then eval BODY.
The value of the last form in BODY is returned.
Each element of VARLIST is a symbol (which is bound to nil)
or a list (SYMBOL VALUEFORM) (which binds SYMBOL to the value of VALUEFORM).
All the VALUEFORMs are evalled before any symbols are bound.
usage: (let VARLIST BODY...)]],
}
function F.let.f(args)
  local count = specpdl.index()
  local varlist = lisp.xcar(args)
  local varlist_len = lisp.list_length(varlist)
  local elt
  local temps = {}
  local argnum = 0
  while argnum < varlist_len and lisp.consp(varlist) do
    elt = lisp.xcar(varlist)
    varlist = lisp.xcdr(varlist)
    if lisp.symbolp(elt) then
      temps[argnum] = vars.Qnil
    elseif not lisp.nilp(vars.F.cdr(vars.F.cdr(elt))) then
      signal.signal_error("`let' bindings can have only one value-form", elt)
    else
      temps[argnum] = M.eval_sub(vars.F.car(vars.F.cdr(elt)))
    end
    argnum = argnum + 1
  end
  varlist = lisp.xcar(args)
  local lexenv = vars.V.internal_interpreter_environment
  argnum = 0
  while argnum < varlist_len and lisp.consp(varlist) do
    elt = lisp.xcar(varlist)
    varlist = lisp.xcdr(varlist)
    local var = lisp.symbolp(elt) and elt or vars.F.car(elt)
    local tem = temps[argnum]
    argnum = argnum + 1
    if
      not lisp.nilp(lexenv)
      and lisp.symbolp(var)
      and not (var --[[@as vim.elisp._symbol]]).declared_special
      and lisp.nilp(vars.F.memq(var, vars.V.internal_interpreter_environment))
    then
      lexenv = vars.F.cons(vars.F.cons(var, tem), lexenv)
    else
      specpdl.bind(var, tem)
    end
  end
  if not lisp.eq(lexenv, vars.V.internal_interpreter_environment) then
    specpdl.bind(vars.Qinternal_interpreter_environment, lexenv)
  end
  elt = vars.F.progn(vars.F.cdr(args))
  return specpdl.unbind_to(count, elt)
end
F.letX = {
  'let*',
  1,
  -1,
  0,
  [[Bind variables according to VARLIST then eval BODY.
The value of the last form in BODY is returned.
Each element of VARLIST is a symbol (which is bound to nil)
or a list (SYMBOL VALUEFORM) (which binds SYMBOL to the value of VALUEFORM).
Each VALUEFORM can refer to the symbols already bound by this VARLIST.
usage: (let* VARLIST BODY...)]],
}
function F.letX.f(args)
  local count = specpdl.index()
  local lexenv = vars.V.internal_interpreter_environment
  local _, tail = lisp.for_each_tail(lisp.xcar(args), function(varlist)
    local elt = lisp.xcar(varlist)
    local var, val
    if lisp.symbolp(elt) then
      var = elt
      val = vars.Qnil
    else
      var = vars.F.car(elt)
      if not lisp.nilp(vars.F.cdr(lisp.xcdr(elt))) then
        signal.signal_error("`let' bindings can have only one value-form", elt)
      end
      val = M.eval_sub(vars.F.car(lisp.xcdr(elt)))
    end
    if
      not lisp.nilp(lexenv)
      and lisp.symbolp(var)
      and not (var --[[@as vim.elisp._symbol]]).declared_special
      and lisp.nilp(vars.F.memq(var, vars.V.internal_interpreter_environment))
    then
      local newenv = vars.F.cons(vars.F.cons(var, val), vars.V.internal_interpreter_environment)
      if lisp.eq(vars.V.internal_interpreter_environment, lexenv) then
        specpdl.bind(vars.Qinternal_interpreter_environment, newenv)
      else
        vars.V.internal_interpreter_environment = newenv
      end
    else
      specpdl.bind(var, val)
    end
  end)
  lisp.check_list_end(tail, lisp.xcar(args))
  local val = vars.F.progn(lisp.xcdr(args))
  return specpdl.unbind_to(count, val)
end
---@return vim.elisp.specpdl.let_entry?
local function default_toplevel_binding(sym)
  local binding = nil
  for pdl in specpdl.riter() do
    if pdl.type == specpdl.type.let or pdl.type == specpdl.type.let_default then
      ---@cast pdl vim.elisp.specpdl.let_entry
      if lisp.eq(pdl.symbol, sym) then
        binding = pdl
      end
    end
  end
  return binding
end
local function defvar(sym, initvalue, docstring, eval)
  lisp.check_symbol(sym)
  local tem = vars.F.default_boundp(sym)
  vars.F.internal__define_uninitialized_variable(sym, docstring)
  if lisp.nilp(tem) then
    vars.F.set_default(sym, eval and M.eval_sub(initvalue) or initvalue)
  else
    local binding = default_toplevel_binding(sym)
    if binding and binding.old_value == nil then
      error('TODO')
    end
  end
  return sym
end
F.defvar = {
  'defvar',
  1,
  -1,
  0,
  [[Define SYMBOL as a variable, and return SYMBOL.
You are not required to define a variable in order to use it, but
defining it lets you supply an initial value and documentation, which
can be referred to by the Emacs help facilities and other programming
tools.  The `defvar' form also declares the variable as \"special\",
so that it is always dynamically bound even if `lexical-binding' is t.

If SYMBOL's value is void and the optional argument INITVALUE is
provided, INITVALUE is evaluated and the result used to set SYMBOL's
value.  If SYMBOL is buffer-local, its default value is what is set;
buffer-local values are not affected.  If INITVALUE is missing,
SYMBOL's value is not set.

If SYMBOL is let-bound, then this form does not affect the local let
binding but the toplevel default binding instead, like
`set-toplevel-default-binding`.
(`defcustom' behaves similarly in this respect.)

The optional argument DOCSTRING is a documentation string for the
variable.

To define a user option, use `defcustom' instead of `defvar'.

To define a buffer-local variable, use `defvar-local'.
usage: (defvar SYMBOL &optional INITVALUE DOCSTRING)]],
}
function F.defvar.f(args)
  local sym = lisp.xcar(args)
  local tail = lisp.xcdr(args)
  lisp.check_symbol(sym)
  if not lisp.nilp(tail) then
    if not lisp.nilp(lisp.xcdr(tail)) and not lisp.nilp(lisp.xcdr(lisp.xcdr(tail))) then
      signal.error('Too many arguments')
    end
    local exp = lisp.xcar(tail)
    tail = lisp.xcdr(tail)
    return defvar(sym, exp, vars.F.car(tail), true)
  elseif
    not lisp.nilp(vars.V.internal_interpreter_environment)
    and lisp.symbolp(sym)
    and not (sym --[[@as vim.elisp._symbol]]).declared_special
  then
    vars.V.internal_interpreter_environment =
      vars.F.cons(sym, vars.V.internal_interpreter_environment)
    return sym
  else
    return sym
  end
end
F.defvaralias = {
  'defvaralias',
  2,
  3,
  0,
  [[Make NEW-ALIAS a variable alias for symbol BASE-VARIABLE.
Aliased variables always have the same value; setting one sets the other.
Third arg DOCSTRING, if non-nil, is documentation for NEW-ALIAS.  If it is
omitted or nil, NEW-ALIAS gets the documentation string of BASE-VARIABLE,
or of the variable at the end of the chain of aliases, if BASE-VARIABLE is
itself an alias.  If NEW-ALIAS is bound, and BASE-VARIABLE is not,
then the value of BASE-VARIABLE is set to that of NEW-ALIAS.
The return value is BASE-VARIABLE.]],
}
function F.defvaralias.f(new_alias, base_variable, docstring)
  lisp.check_symbol(new_alias)
  lisp.check_symbol(base_variable)
  if lisp.symbolconstantp(new_alias) then
    signal.error('Cannot make a constant an alias: %s', lisp.sdata(lisp.symbol_name(new_alias)))
  end
  local s = new_alias --[[@as vim.elisp._symbol]]
  if s.redirect == lisp.symbol_redirect.localized then
    signal.error(
      "Don't know how to make a buffer-local variable an alias: %s",
      lisp.sdata(lisp.symbol_name(new_alias))
    )
  end
  if lisp.nilp(vars.F.boundp(base_variable)) then
    data.set_internal(base_variable, data.find_symbol_value(new_alias), vars.Qnil, 'BIND')
  elseif
    not lisp.nilp(vars.F.fboundp(base_variable))
    and not lisp.eq(
      data.find_symbol_value(new_alias) or vars.Qunique,
      data.find_symbol_value(base_variable) or vars.Qunique
    )
  then
    error('TODO')
  end
  for entry in specpdl.riter() do
    if entry.type >= specpdl.type.let and lisp.eq(new_alias, entry.symbol) then
      signal.error(
        "Don't know how to make a let-bound variable an alias: %s",
        lisp.sdata(lisp.symbol_name(new_alias))
      )
    end
  end
  if s.trapped_write == lisp.symbol_trapped_write.trapped then
    error('TODO')
  end
  s.declared_special = true;
  (base_variable --[[@as vim.elisp._symbol]]).declared_special = true
  s.redirect = lisp.symbol_redirect.varalias
  lisp.set_symbol_alias(s, base_variable --[[@as vim.elisp._symbol]])
  s.trapped_write = (base_variable --[[@as vim.elisp._symbol]]).trapped_write
  lisp.loadhist_attach(new_alias)
  vars.F.put(new_alias, vars.Qvariable_documentation, docstring)
  return base_variable
end
F.defvar_1 = {
  'defvar-1',
  2,
  3,
  0,
  [[Like `defvar' but as a function.
More specifically behaves like (defvar SYM 'INITVALUE DOCSTRING).]],
}
function F.defvar_1.f(sym, initvalue, docstring)
  return defvar(sym, initvalue, docstring, false)
end
F.make_var_non_special = { 'internal-make-var-non-special', 1, 1, 0, [[Internal function.]] }
function F.make_var_non_special.f(sym)
  lisp.check_symbol(sym);
  (sym --[[@as vim.elisp._symbol]]).declared_special = false
  return vars.Qnil
end
local function lexbound_p(sym)
  for i in specpdl.riter() do
    if i.type == specpdl.type.let or i.type == specpdl.type.let_default then
      if lisp.eq(i.symbol, vars.Qinternal_interpreter_environment) then
        local env = i.old_value
        if env and lisp.consp(env) and not lisp.nilp(vars.F.assq(sym, env)) then
          return true
        end
      end
    end
  end
  return false
end
F.internal__define_uninitialized_variable = {
  'internal--define-uninitialized-variable',
  1,
  2,
  0,
  [[Define SYMBOL as a variable, with DOC as its docstring.
This is like `defvar' and `defconst' but without affecting the variable's
value.]],
}
function F.internal__define_uninitialized_variable.f(sym, doc)
  if
    not (sym --[[@as vim.elisp._symbol]]).declared_special and lexbound_p(sym)
  then
    signal.xsignal(
      vars.Qerror,
      alloc.make_string('Defining as dynamic an already lexical var'),
      sym
    )
  end
  (sym --[[@as vim.elisp._symbol]]).declared_special = true
  if not lisp.nilp(doc) then
    vars.F.put(sym, vars.Qvariable_documentation, doc)
  end
  lisp.loadhist_attach(sym)
  return vars.Qnil
end
F.defconst = {
  'defconst',
  2,
  -1,
  0,
  [[Define SYMBOL as a constant variable.
This declares that neither programs nor users should ever change the
value.  This constancy is not actually enforced by Emacs Lisp, but
SYMBOL is marked as a special variable so that it is never lexically
bound.

The `defconst' form always sets the value of SYMBOL to the result of
evalling INITVALUE.  If SYMBOL is buffer-local, its default value is
what is set; buffer-local values are not affected.  If SYMBOL has a
local binding, then this form sets the local binding's value.
However, you should normally not make local bindings for variables
defined with this form.

The optional DOCSTRING specifies the variable's documentation string.
usage: (defconst SYMBOL INITVALUE [DOCSTRING])]],
}
function F.defconst.f(args)
  local sym = lisp.xcar(args)
  lisp.check_symbol(sym)
  local docstring = vars.Qnil
  if not lisp.nilp(lisp.xcdr(lisp.xcdr(args))) then
    if not lisp.nilp(lisp.xcdr(lisp.xcdr(lisp.xcdr(args)))) then
      signal.error('Too many arguments')
    end
    docstring = lisp.xcar(lisp.xcdr(lisp.xcdr(args)))
  end
  local tem = M.eval_sub(lisp.xcar(lisp.xcdr(args)))
  return vars.F.defconst_1(sym, tem, docstring)
end
F.defconst_1 = {
  'defconst-1',
  2,
  3,
  0,
  [[Like `defconst' but as a function.
More specifically, behaves like (defconst SYM 'INITVALUE DOCSTRING).]],
}
function F.defconst_1.f(sym, initvalue, docstring)
  lisp.check_symbol(sym)
  local tem = initvalue
  vars.F.internal__define_uninitialized_variable(sym, docstring)
  vars.F.set_default(sym, tem)
  vars.F.put(sym, vars.Qrisky_local_variable, vars.Qt)
  return sym
end
F.if_ = {
  'if',
  2,
  -1,
  0,
  [[If COND yields non-nil, do THEN, else do ELSE...
Returns the value of THEN or the value of the last of the ELSE's.
THEN must be one expression, but ELSE... can be zero or more expressions.
If COND yields nil, and there are no ELSE's, the value is nil.
usage: (if COND THEN ELSE...)]],
}
function F.if_.f(args)
  local cond = M.eval_sub(lisp.xcar(args))
  if not lisp.nilp(cond) then
    return M.eval_sub(vars.F.car(lisp.xcdr(args)))
  end
  return vars.F.progn(vars.F.cdr(lisp.xcdr(args)))
end
F.while_ = {
  'while',
  1,
  -1,
  0,
  [[If TEST yields non-nil, eval BODY... and repeat.
The order of execution is thus TEST, BODY, TEST, BODY and so on
until TEST returns nil.

The value of a `while' form is always nil.

usage: (while TEST BODY...)]],
}
function F.while_.f(args)
  local test = lisp.xcar(args)
  local body = lisp.xcdr(args)
  while not lisp.nilp(M.eval_sub(test)) do
    vars.F.progn(body)
  end
  return vars.Qnil
end
F.cond = {
  'cond',
  0,
  -1,
  0,
  [[Try each clause until one succeeds.
Each clause looks like (CONDITION BODY...).  CONDITION is evaluated
and, if the value is non-nil, this clause succeeds:
then the expressions in BODY are evaluated and the last one's
value is the value of the cond-form.
If a clause has one element, as in (CONDITION), then the cond-form
returns CONDITION's value, if that is non-nil.
If no clause succeeds, cond returns nil.
usage: (cond CLAUSES...)]],
}
function F.cond.f(args)
  local val = args
  while lisp.consp(args) do
    local clause = lisp.xcar(args)
    val = M.eval_sub(vars.F.car(clause))
    if not lisp.nilp(val) then
      if not lisp.nilp(lisp.xcdr(clause)) then
        val = vars.F.progn(lisp.xcdr(clause))
      end
      break
    end
    args = lisp.xcdr(args)
  end
  return val
end
F.or_ = {
  'or',
  0,
  -1,
  0,
  [[Eval args until one of them yields non-nil, then return that value.
The remaining args are not evalled at all.
If all args return nil, return nil.
usage: (or CONDITIONS...)]],
}
function F.or_.f(args)
  local val = vars.Qnil
  while lisp.consp(args) do
    local arg = lisp.xcar(args)
    args = lisp.xcdr(args)
    val = M.eval_sub(arg)
    if not lisp.nilp(val) then
      break
    end
  end
  return val
end
F.and_ = {
  'and',
  0,
  -1,
  0,
  [[Eval args until one of them yields nil, then return nil.
The remaining args are not evalled at all.
If no arg yields nil, return the last arg's value.
usage: (and CONDITIONS...)]],
}
function F.and_.f(args)
  local val = lisp.T
  while lisp.consp(args) do
    local arg = lisp.xcar(args)
    args = lisp.xcdr(args)
    val = M.eval_sub(arg)
    if lisp.nilp(val) then
      break
    end
  end
  return val
end
F.quote = {
  'quote',
  1,
  -1,
  0,
  [[Return the argument, without evaluating it.  `(quote x)' yields `x'.
Warning: `quote' does not construct its return value, but just returns
the value that was pre-constructed by the Lisp reader (see info node
`(elisp)Printed Representation').
This means that \\='(a . b) is not identical to (cons \\='a \\='b): the former
does not cons.  Quoting should be reserved for constants that will
never be modified by side-effects, unless you like self-modifying code.
See the common pitfall in info node `(elisp)Rearrangement' for an example
of unexpected results when a quoted object is modified.
usage: (quote ARG)]],
}
function F.quote.f(args)
  if not lisp.nilp(lisp.xcdr(args)) then
    signal.xsignal(vars.Qwrong_number_of_arguments, vars.Qquote, vars.F.length(args))
  end
  return lisp.xcar(args)
end
F.progn = {
  'progn',
  0,
  -1,
  0,
  [[Eval BODY forms sequentially and return value of last one.
usage: (progn BODY...)]],
}
function F.progn.f(body)
  local val = vars.Qnil
  while lisp.consp(body) do
    local form = lisp.xcar(body)
    body = lisp.xcdr(body)
    val = M.eval_sub(form)
  end
  return val
end
F.prog1 = {
  'prog1',
  1,
  -1,
  0,
  [[Eval FIRST and BODY sequentially; return value from FIRST.
The value of FIRST is saved during the evaluation of the remaining args,
whose values are discarded.
usage: (prog1 FIRST BODY...)]],
}
function F.prog1.f(args)
  local val = M.eval_sub(lisp.xcar(args))
  vars.F.progn(lisp.xcdr(args))
  return val
end
F.eval = {
  'eval',
  1,
  2,
  0,
  [[Evaluate FORM and return its value.
If LEXICAL is t, evaluate using lexical scoping.
LEXICAL can also be an actual lexical environment, in the form of an
alist mapping symbols to their value.]],
}
function F.eval.f(form, lexical)
  local count = specpdl.index()
  specpdl.bind(
    vars.Qinternal_interpreter_environment,
    (lisp.consp(lexical) or lisp.nilp(lexical)) and lexical or lisp.list(vars.Qt)
  )
  return specpdl.unbind_to(count, M.eval_sub(form))
end
function M.funcall_subr(fun, args)
  local numargs = #args
  local s = fun --[[@as vim.elisp._subr]]
  if numargs >= s.minargs then
    if numargs <= s.maxargs and s.maxargs <= 8 then
      local a = {}
      if numargs < s.maxargs then
        for i = 1, s.maxargs do
          table.insert(a, args[i] or vars.Qnil)
        end
      else
        a = args
      end
      return s.fn(unpack(a))
    elseif s.maxargs == -2 or s.maxargs > 8 then
      return s.fn(args)
    end
  end
  if s.maxargs == -1 then
    signal.xsignal(vars.Qinvalid_function, fun)
  else
    signal.xsignal(vars.Qwrong_number_of_arguments, fun, lisp.make_fixnum(numargs))
  end
end
function M.funcall_general(fun, args)
  local original_fun = fun
  if lisp.symbolp(fun) and not lisp.nilp(fun) then
    fun = (fun --[[@as vim.elisp._symbol]]).fn
    if lisp.symbolp(fun) then
      fun = data.indirect_function(fun)
    end
  end
  if lisp.subrp(fun) and not lisp.subr_native_compiled_dynp(fun) then
    return M.funcall_subr(fun, args)
  elseif
    lisp.compiledp(fun)
    or lisp.subr_native_compiled_dynp(fun)
    or lisp.module_functionp(fun)
  then
    return funcall_lambda(fun, args)
  end
  if lisp.nilp(fun) then
    signal.xsignal(vars.Qvoid_function, original_fun)
  elseif not lisp.consp(fun) then
    signal.xsignal(vars.Qinvalid_function, original_fun)
  end
  local funcar = lisp.xcar(fun)
  if not lisp.symbolp(funcar) then
    signal.xsignal(vars.Qinvalid_function, original_fun)
  elseif lisp.eq(funcar, vars.Qlambda) or lisp.eq(funcar, vars.Qclosure) then
    return funcall_lambda(fun, args)
  elseif lisp.eq(funcar, vars.Qautoload) then
    error('TODO')
  else
    signal.xsignal(vars.Qinvalid_function, original_fun)
  end
end
F.funcall = {
  'funcall',
  1,
  -2,
  0,
  [[Call first argument as a function, passing remaining arguments to it.
Return the value that function returns.
Thus, (funcall \\='cons \\='x \\='y) returns (x . y).
usage: (funcall FUNCTION &rest ARGUMENTS)]],
}
function F.funcall.fa(args)
  vars.lisp_eval_depth = vars.lisp_eval_depth + 1
  if vars.lisp_eval_depth > lisp.fixnum(vars.V.max_lisp_eval_depth) then
    if lisp.fixnum(vars.V.max_lisp_eval_depth) < 100 then
      vars.V.max_lisp_eval_depth = lisp.make_fixnum(100)
    end
    if vars.lisp_eval_depth > lisp.fixnum(vars.V.max_lisp_eval_depth) then
      signal.xsignal(vars.Qexcessive_lisp_nesting, lisp.make_fixnum(vars.lisp_eval_depth))
    end
  end
  local fun_args = { unpack(args, 2) }
  local count = specpdl.record_in_backtrace(args[1], fun_args, #fun_args)
  if not lisp.nilp(vars.V.debug_on_next_call) then
    error('TODO')
  end
  local val = M.funcall_general(args[1], fun_args)
  vars.lisp_eval_depth = vars.lisp_eval_depth - 1
  if specpdl.backtrace_debug_on_exit(count) then
    error('TODO')
  end
  return specpdl.unbind_to(specpdl.index() - 1, val)
end
F.apply = {
  'apply',
  1,
  -2,
  0,
  [[Call FUNCTION with our remaining args, using our last arg as list of args.
Then return the value FUNCTION returns.
With a single argument, call the argument's first element using the
other elements as args.
Thus, (apply \\='+ 1 2 \\='(3 4)) returns 10.
usage: (apply FUNCTION &rest ARGUMENTS)]],
}
function F.apply.fa(args)
  local spread_arg = args[#args]
  local numargs = lisp.list_length(spread_arg)
  local fun = args[1]
  if numargs == 0 then
    args[#args] = nil
    return vars.F.funcall(args)
  elseif numargs == 1 then
    args[#args] = lisp.xcar(spread_arg)
    return vars.F.funcall(args)
  end
  numargs = numargs + #args - 2
  if lisp.symbolp(fun) and not lisp.nilp(fun) then
    fun = (fun --[[@as vim.elisp._symbol]]).fn
    if lisp.symbolp(fun) then
      error('TODO')
    end
  end
  local funcall_args = {}
  for _, v in ipairs(args) do
    table.insert(funcall_args, v)
  end
  local i = #args
  while not lisp.nilp(spread_arg) do
    funcall_args[i] = lisp.xcar(spread_arg)
    i = i + 1
    spread_arg = lisp.xcdr(spread_arg)
  end
  return vars.F.funcall(funcall_args)
end
F.function_ = {
  'function',
  0,
  -1,
  0,
  [[Like `quote', but preferred for objects which are functions.
In byte compilation, `function' causes its argument to be handled by
the byte compiler.  Similarly, when expanding macros and expressions,
ARG can be examined and possibly expanded.  If `quote' is used
instead, this doesn't happen.

usage: (function ARG)]],
}
function F.function_.f(args)
  local quoted = lisp.xcar(args)
  if not lisp.nilp(lisp.xcdr(args)) then
    signal.xsignal(vars.Qwrong_number_of_arguments, vars.Qfunction, vars.F.length(args))
  end
  if
    not lisp.nilp(vars.V.internal_interpreter_environment)
    and lisp.consp(quoted)
    and lisp.eq(lisp.xcar(quoted), vars.Qlambda)
  then
    local cdr = lisp.xcdr(quoted)
    local tmp = cdr
    if lisp.consp(tmp) then
      tmp = lisp.xcdr(tmp)
      if lisp.consp(tmp) then
        tmp = lisp.xcar(tmp)
        if lisp.consp(tmp) and lisp.eq(lisp.xcar(tmp), vars.QCdocumentation) then
          error('TODO')
        end
      end
    end
    if lisp.nilp(vars.V.internal_make_interpreted_closure_function) then
      return vars.F.cons(vars.Qclosure, vars.F.cons(vars.V.internal_interpreter_environment, cdr))
    else
      return vars.F.funcall {
        vars.V.internal_make_interpreted_closure_function,
        vars.F.cons(vars.Qlambda, cdr),
        vars.V.internal_interpreter_environment,
      }
    end
  end
  return quoted
end
F.commandp = {
  'commandp',
  1,
  2,
  0,
  [[Non-nil if FUNCTION makes provisions for interactive calling.
This means it contains a description for how to read arguments to give it.
The value is nil for an invalid function or a symbol with no function
definition.

Interactively callable functions include strings and vectors (treated
as keyboard macros), lambda-expressions that contain a top-level call
to `interactive', autoload definitions made by `autoload' with non-nil
fourth argument, and some of the built-in functions of Lisp.

Also, a symbol satisfies `commandp' if its function definition does so.

If the optional argument FOR-CALL-INTERACTIVELY is non-nil,
then strings and vectors are not accepted.]],
}
function F.commandp.f(function_, for_call_interactively)
  local fun = function_
  fun = data.indirect_function(fun)
  if lisp.nilp(fun) then
    return vars.Qnil
  end
  local genfun = false
  if lisp.subrp(fun) then
    if
      (fun --[[@as vim.elisp._subr]]).intspec
    then
      return vars.Qt
    end
  elseif lisp.compiledp(fun) then
    if lisp.asize(fun) >= lisp.compiled_idx.interactive then
      return vars.Qt
    elseif lisp.asize(fun) >= lisp.compiled_idx.doc_string then
      local doc = (fun --[[@as vim.elisp._compiled]]).contents[lisp.compiled_idx.doc_string]
      genfun = not (lisp.nilp(doc) or lisp.valid_docstring_p(doc))
    end
  elseif lisp.stringp(fun) or lisp.vectorp(fun) then
    return lisp.nilp(for_call_interactively) and vars.Qt or vars.Qnil
  elseif not lisp.consp(fun) then
    return vars.Qnil
  else
    local funcar = lisp.xcar(fun)
    if lisp.eq(funcar, vars.Qautoload) then
      if not lisp.nilp(vars.F.car(vars.F.cdr(vars.F.cdr(lisp.xcdr(fun))))) then
        return vars.Qt
      end
    else
      local body = vars.F.cdr_safe(lisp.xcdr(fun))
      if lisp.eq(funcar, vars.Qclosure) then
        body = vars.F.cdr_safe(body)
      elseif not lisp.eq(funcar, vars.Qlambda) then
        return vars.Qnil
      end
      if not lisp.nilp(vars.Fassq(vars.Qinteractive, body)) then
        return vars.Qt
      elseif lisp.valid_docstring_p(vars.F.car_safe(body)) then
        genfun = true
      end
    end
  end
  error('TODO')
end
F.autoload = {
  'autoload',
  2,
  5,
  0,
  [[Define FUNCTION to autoload from FILE.
FUNCTION is a symbol; FILE is a file name string to pass to `load'.

Third arg DOCSTRING is documentation for the function.

Fourth arg INTERACTIVE if non-nil says function can be called
interactively.  If INTERACTIVE is a list, it is interpreted as a list
of modes the function is applicable for.

Fifth arg TYPE indicates the type of the object:
   nil or omitted says FUNCTION is a function,
   `keymap' says FUNCTION is really a keymap, and
   `macro' or t says FUNCTION is really a macro.

Third through fifth args give info about the real definition.
They default to nil.

If FUNCTION is already defined other than as an autoload,
this does nothing and returns nil.]],
}
function F.autoload.f(func, file, docstring, interactive, type_)
  lisp.check_symbol(func)
  lisp.check_string(file)
  if
    not lisp.nilp((func --[[@as vim.elisp._symbol]]).fn)
    and not lisp.autoloadp((func --[[@as vim.elisp._symbol]]).fn)
  then
    return vars.Qnil
  end
  return vars.F.defalias(
    func,
    lisp.list(vars.Qautoload, file, docstring, interactive, type_),
    vars.Qnil
  )
end
function M.load_with_autoload_queue(file, noerror, nomessage, nosuffix, must_suffix)
  local count = specpdl.index()
  local oldqueue = vars.autoload_queue
  specpdl.record_unwind_protect(function()
    local queue = vars.autoload_queue
    vars.autoload_queue = oldqueue
    while lisp.consp(queue) do
      error('TODO')
    end
  end)
  vars.autoload_queue = vars.Qt
  local tem = lread.save_match_data_load(file, noerror, nomessage, nosuffix, must_suffix)
  vars.autoload_queue = vars.Qt
  specpdl.unbind_to(count, nil)
  return tem
end
F.autoload_do_load = {
  'autoload-do-load',
  1,
  3,
  0,
  [[Load FUNDEF which should be an autoload.
If non-nil, FUNNAME should be the symbol whose function value is FUNDEF,
in which case the function returns the new autoloaded function value.
If equal to `macro', MACRO-ONLY specifies that FUNDEF should only be loaded if
it defines a macro.]],
}
function F.autoload_do_load.f(fundef, funname, macro_only)
  if not lisp.consp(fundef) or not lisp.eq(vars.Qautoload, lisp.xcar(fundef)) then
    return fundef
  end
  local kind = vars.F.nth(lisp.make_fixnum(4), fundef)
  if
    lisp.eq(macro_only, vars.Qmacro) and not (lisp.eq(kind, vars.Qt) or lisp.eq(kind, vars.Qmacro))
  then
    return fundef
  end
  lisp.check_symbol(funname)
  local ignore_errors = (lisp.eq(kind, vars.Qt) or lisp.eq(kind, vars.Qmacro)) and vars.Qnil
    or macro_only
  M.load_with_autoload_queue(
    vars.F.car(vars.F.cdr(fundef)),
    ignore_errors,
    vars.Qt,
    vars.Qnil,
    vars.Qt
  )
  if lisp.nilp(funname) or not lisp.nilp(ignore_errors) then
    return vars.Qnil
  else
    error('TODO')
  end
end
F.throw = {
  'throw',
  2,
  2,
  0,
  [[Throw to the catch for TAG and return VALUE from it.
Both TAG and VALUE are evalled.]],
}
function F.throw.f(tag, value)
  if not lisp.nilp(tag) then
    for _, c in ipairs(handler.handlerlist) do
      if c.type == 'CATCHER_ALL' then
        handler.unwind_to_catch(c.id, vars.F.cons(tag, value), 'THROW')
      elseif c.type == 'CATCHER' and lisp.eq(c.tag_or_ch, tag) then
        handler.unwind_to_catch(c.id, value, 'THROW')
      end
    end
  end
  signal.xsignal(vars.Qno_catch, tag, value)
  error('unreachable')
end
F.unwind_protect = {
  'unwind-protect',
  1,
  -1,
  0,
  [[Do BODYFORM, protecting with UNWINDFORMS.
If BODYFORM completes normally, its value is returned
after executing the UNWINDFORMS.
If BODYFORM exits nonlocally, the UNWINDFORMS are executed anyway.
usage: (unwind-protect BODYFORM UNWINDFORMS...)]],
}
function F.unwind_protect.f(args)
  local count = specpdl.index()
  specpdl.record_unwind_protect(function()
    vars.F.progn(lisp.xcdr(args))
  end)
  local val = M.eval_sub(lisp.xcar(args))
  return specpdl.unbind_to(count, val)
end
local function run_hook_with_args(args, fn)
  if lisp.nilp(vars.run_hooks) then
    return vars.Qnil
  end
  local sym = args[1]
  local val = data.find_symbol_value(sym)
  if val == nil or lisp.nilp(val) then
    return vars.Qnil
  elseif not lisp.consp(val) or lisp.functionp(val) then
    error('TODO')
  end
  error('TODO')
end
F.condition_case = {
  'condition-case',
  2,
  -1,
  0,
  [[Regain control when an error is signaled.
Executes BODYFORM and returns its value if no error happens.
Each element of HANDLERS looks like (CONDITION-NAME BODY...)
or (:success BODY...), where the BODY is made of Lisp expressions.

A handler is applicable to an error if CONDITION-NAME is one of the
error's condition names.  Handlers may also apply when non-error
symbols are signaled (e.g., `quit').  A CONDITION-NAME of t applies to
any symbol, including non-error symbols.  If multiple handlers are
applicable, only the first one runs.

The car of a handler may be a list of condition names instead of a
single condition name; then it handles all of them.  If the special
condition name `debug' is present in this list, it allows another
condition in the list to run the debugger if `debug-on-error' and the
other usual mechanisms say it should (otherwise, `condition-case'
suppresses the debugger).

When a handler handles an error, control returns to the `condition-case'
and it executes the handler's BODY...
with VAR bound to (ERROR-SYMBOL . SIGNAL-DATA) from the error.
\(If VAR is nil, the handler can't access that information.)
Then the value of the last BODY form is returned from the `condition-case'
expression.

The special handler (:success BODY...) is invoked if BODYFORM terminated
without signaling an error.  BODY is then evaluated with VAR bound to
the value returned by BODYFORM.

See also the function `signal' for more info.
usage: (condition-case VAR BODYFORM &rest HANDLERS)]],
}
function F.condition_case.f(args)
  local var = lisp.xcar(args)
  local bodyform = lisp.xcar(lisp.xcdr(args))
  local handlers = lisp.xcdr(lisp.xcdr(args))
  return handler.internal_lisp_condition_case(var, bodyform, handlers)
end
F.catch = {
  'catch',
  1,
  -1,
  0,
  [[Eval BODY allowing nonlocal exits using `throw'.
TAG is evalled to get the tag to use; it must not be nil.

Then the BODY is executed.
Within BODY, a call to `throw' with the same TAG exits BODY and this `catch'.
If no throw happens, `catch' returns the value of the last BODY form.
If a throw happens, it specifies the value to return from `catch'.
usage: (catch TAG BODY...)]],
}
function F.catch.f(args)
  local tag = M.eval_sub(lisp.xcar(args))
  return handler.internal_catch(tag, vars.F.progn, lisp.xcdr(args))
end
local function ensure_room(n)
  local sum = overflow.add(vars.lisp_eval_depth, n) or overflow.max
  if sum > lisp.fixnum(vars.V.max_lisp_eval_depth) then
    vars.V.max_lisp_eval_depth = lisp.make_fixnum(sum)
  end
end
local function find_handler_clause(handlers, conditions)
  if lisp.eq(handlers, vars.Qt) then
    return vars.Qt
  end
  if lisp.eq(handlers, vars.Qerror) then
    return vars.Qt
  end
  local h = handlers
  while lisp.consp(h) do
    local hand = lisp.xcar(h)
    if not lisp.nilp(vars.F.memq(hand, conditions)) or lisp.eq(hand, vars.Qt) then
      return handlers
    end
    h = lisp.xcdr(h)
  end
  return vars.Qnil
end
local function signal_quit_p(sig)
  local list
  return lisp.eq(sig, vars.Qquit)
    or (
      not lisp.nilp(vars.F.symbolp(sig))
      and lisp.consp((function()
        list = vars.F.get(sig, vars.Qerror_conditions)
        return list
      end)())
      and not lisp.nilp(vars.F.memq(vars.Qquit, list))
    )
end
local function wants_debugger(list, conditions)
  if lisp.nilp(list) then
    return false
  end
  if not lisp.consp(list) then
    return true
  end
  error('TODO')
end
local function maybe_call_debugger(conditions, sig, d)
  local combined_data = vars.F.cons(sig, d)
  if _G.vim_elisp_later then
    error('TODO: emacs does an if which basically checks if the debugger had an error')
    --The if: when_entered_debugger < num_nonmacro_input_events
  end
  local s = signal_quit_p(sig)
  if
    lisp.nilp(vars.V.inhibit_debugger)
    and ((s and not lisp.nilp(vars.V.debug_on_quit)) or (not s and wants_debugger(
      vars.V.debug_on_error,
      conditions
    )))
    and not skip_debugger(conditions, combined_data)
  then
    error('TODO')
  end
  return false
end
local function signal_or_quit(error_symbol, d, keyboard_quit)
  if not lisp.nilp(vars.V.signal_hook_function) and not lisp.nilp(error_symbol) then
    ensure_room(20)
    vars.F.funcall({ vars.V.signal_hook_function, error_symbol, d })
  end
  local real_error_symbol = lisp.nilp(error_symbol) and vars.F.car(d) or error_symbol
  local conditions = vars.F.get(real_error_symbol, vars.Qerror_conditions)
  vars.signaling_function = vars.Qnil
  if not lisp.nilp(error_symbol) then
    local pdl, idx = specpdl.backtrace_next()
    if pdl and lisp.eq(pdl.func, vars.Qerror) then
      error('TODO')
    end
    if pdl then
      vars.signaling_function = pdl.func
    end
  end
  local clause = vars.Qnil
  local h
  for _, h1 in ipairs(handler.handlerlist) do
    h = h1
    if h1.type == 'CATCHER_ALL' then
      clause = vars.Qt
      break
    end
    if h1.type == 'CONDITION_CASE' then
      clause = find_handler_clause(h1.tag_or_ch, conditions)
      if not lisp.nilp(clause) then
        break
      end
    end
  end
  local debugger_called = false
  if
    not lisp.nilp(error_symbol)
    and (
      not lisp.nilp(vars.V.debug_on_signal)
      or lisp.nilp(clause)
      or (lisp.consp(clause) and not lisp.nilp(vars.F.memq(vars.Qdebug, clause)))
      or (h and lisp.eq(h.tag_or_ch, vars.Qerror))
    )
  then
    debugger_called = maybe_call_debugger(conditions, error_symbol, d)
    if debugger_called and keyboard_quit and lisp.eq(real_error_symbol, vars.Qquit) then
      return vars.Qnil
    end
  end
  if _G.vim_elisp_later then
    error('TODO: will we ever need to do backtrace on redisplay error?')
    error('TODO: we will (for now) not support batch (noninteractive) mode')
  end
  if not lisp.nilp(clause) then
    local unwind_data = lisp.nilp(error_symbol) and d or vars.F.cons(error_symbol, d)
    handler.unwind_to_catch(h.id, unwind_data, 'SIGNAL')
  else
    vars.F.throw(vars.Qtop_level, vars.Qt)
  end
end
F.signal = {
  'signal',
  2,
  2,
  0,
  [[Signal an error.  Args are ERROR-SYMBOL and associated DATA.
        This function does not return.

        When `noninteractive' is non-nil (in particular, in batch mode), an
        unhandled error calls `kill-emacs', which terminates the Emacs
        session with a non-zero exit code.

        An error symbol is a symbol with an `error-conditions' property
        that is a list of condition names.  The symbol should be non-nil.
        A handler for any of those names will get to handle this signal.
        The symbol `error' should normally be one of them.

        DATA should be a list.  Its elements are printed as part of the error message.
        See Info anchor `(elisp)Definition of signal' for some details on how this
        error message is constructed.
        If the signal is handled, DATA is made available to the handler.
        See also the function `condition-case'.]],
}
function F.signal.f(error_symbol, d)
  if lisp.nilp(error_symbol) and lisp.nilp(d) then
    error_symbol = vars.Qerror
  end
  signal_or_quit(error_symbol, d, false)
  error('unreachable')
end
F.backtrace_frame_internal = {
  'backtrace-frame--internal',
  3,
  3,
  nil,
  [[Call FUNCTION on stack frame NFRAMES away from BASE.
Return the result of FUNCTION, or nil if no matching frame could be found.]],
}
function F.backtrace_frame_internal.f(function_, nframes, base)
  return specpdl.backtrace_frame_apply(function_, specpdl.get_backtrace_frame(nframes, base))
end
F.run_hook_with_args = {
  'run-hook-with-args',
  1,
  -2,
  0,
  [[Run HOOK with the specified arguments ARGS.
        HOOK should be a symbol, a hook variable.  The value of HOOK
        may be nil, a function, or a list of functions.  Call each
        function in order with arguments ARGS.  The final return value
        is unspecified.

        Do not use `make-local-variable' to make a hook variable buffer-local.
        Instead, use `add-hook' and specify t for the LOCAL argument.
        usage: (run-hook-with-args HOOK &rest ARGS)]],
}
function F.run_hook_with_args.fa(args)
  return run_hook_with_args(args, function(a)
    vars.F.funcall(a)
    return vars.Qnil
  end)
end
F.run_hook_with_args_until_success = {
  'run-hook-with-args-until-success',
  1,
  -2,
  0,
  [[Run HOOK with the specified arguments ARGS.
HOOK should be a symbol, a hook variable.  The value of HOOK
may be nil, a function, or a list of functions.  Call each
function in order with arguments ARGS, stopping at the first
one that returns non-nil, and return that value.  Otherwise (if
all functions return nil, or if there are no functions to call),
return nil.

Do not use `make-local-variable' to make a hook variable buffer-local.
Instead, use `add-hook' and specify t for the LOCAL argument.
usage: (run-hook-with-args-until-success HOOK &rest ARGS)]],
}
function F.run_hook_with_args_until_success.fa(args)
  return run_hook_with_args(args, vars.F.funcall)
end
F.run_hooks = {
  'run-hooks',
  0,
  -2,
  0,
  [[Run each hook in HOOKS.
        Each argument should be a symbol, a hook variable.
        These symbols are processed in the order specified.
        If a hook symbol has a non-nil value, that value may be a function
        or a list of functions to be called to run the hook.
        If the value is a function, it is called with no arguments.
        If it is a list, the elements are called, in order, with no arguments.

        Major modes should not use this function directly to run their mode
        hook; they should use `run-mode-hooks' instead.

        Do not use `make-local-variable' to make a hook variable buffer-local.
        Instead, use `add-hook' and specify t for the LOCAL argument.
        usage: (run-hooks &rest HOOKS)]],
}
function F.run_hooks.fa(args)
  for _, v in ipairs(args) do
    vars.F.run_hook_with_args({ v })
  end
  return vars.Qnil
end
F.default_toplevel_value = {
  'default-toplevel-value',
  1,
  1,
  0,
  [[Return SYMBOL's toplevel default value.
        "Toplevel" means outside of any let binding.]],
}
function F.default_toplevel_value.f(sym)
  local binding = default_toplevel_binding(sym)
  local value = binding and binding.old_value or nil
  if value == nil then
    value = vars.F.default_value(sym)
    if value == nil then
      signal.xsignal(vars.Qvoid_variable, sym)
      error('unreachable')
    end
  end
  return value
end
F.set_default_toplevel_value = {
  'set-default-toplevel-value',
  2,
  2,
  0,
  [[Set SYMBOL's toplevel default value to VALUE.
"Toplevel" means outside of any let binding.]],
}
function F.set_default_toplevel_value.f(sym, val)
  local binding = default_toplevel_binding(sym)
  if binding then
    binding.old_value = val
  else
    vars.F.set_default(sym, val)
  end
  return vars.Qnil
end

function M.init_syms()
  vars.defsubr(F, 'setq')
  vars.defsubr(F, 'let')
  vars.defsubr(F, 'letX')
  vars.defsubr(F, 'defvar')
  vars.defsubr(F, 'defvaralias')
  vars.defsubr(F, 'defvar_1')
  vars.defsubr(F, 'make_var_non_special')
  vars.defsubr(F, 'internal__define_uninitialized_variable')
  vars.defsubr(F, 'defconst')
  vars.defsubr(F, 'defconst_1')
  vars.defsubr(F, 'if_')
  vars.defsubr(F, 'while_')
  vars.defsubr(F, 'cond')
  vars.defsubr(F, 'or_')
  vars.defsubr(F, 'and_')
  vars.defsubr(F, 'quote')
  vars.defsubr(F, 'progn')
  vars.defsubr(F, 'prog1')
  vars.defsubr(F, 'eval')
  vars.defsubr(F, 'funcall')
  vars.defsubr(F, 'apply')
  vars.defsubr(F, 'function_')
  vars.defsubr(F, 'commandp')
  vars.defsubr(F, 'autoload')
  vars.defsubr(F, 'autoload_do_load')
  vars.defsubr(F, 'throw')
  vars.defsubr(F, 'unwind_protect')
  vars.defsubr(F, 'catch')
  vars.defsubr(F, 'condition_case')
  vars.defsubr(F, 'backtrace_frame_internal')
  vars.defsubr(F, 'signal')
  vars.defsubr(F, 'run_hook_with_args')
  vars.defsubr(F, 'run_hook_with_args_until_success')
  vars.defsubr(F, 'run_hooks')
  vars.defsubr(F, 'default_toplevel_value')
  vars.defsubr(F, 'set_default_toplevel_value')

  vars.defvar_lisp(
    'max_lisp_eval_depth',
    'max-lisp-eval-depth',
    [[Limit on depth in `eval', `apply' and `funcall' before error.

        This limit serves to catch infinite recursions for you before they cause
        actual stack overflow in C, which would be fatal for Emacs.
        You can safely make it considerably larger than its default value,
        if that proves inconveniently small.  However, if you increase it too far,
        Emacs could overflow the real C stack, and crash.]]
  )
  vars.V.max_lisp_eval_depth = lisp.make_fixnum(1600)

  vars.defvar_bool(
    'debug_on_next_call',
    'debug-on-next-call',
    [[Non-nil means enter debugger before next `eval', `apply' or `funcall'.]]
  )
  vars.V.debug_on_next_call = vars.Qnil

  local sym = vars.defvar_lisp(
    'internal_interpreter_environment',
    nil,
    [[If non-nil, the current lexical environment of the lisp interpreter.
        When lexical binding is not being used, this variable is nil.
        A value of `(t)' indicates an empty environment, otherwise it is an
        alist of active lexical bindings.]]
  )
  vars.V.internal_interpreter_environment = vars.Qnil
  vars.Qinternal_interpreter_environment = sym

  vars.defsym('Qautoload', 'autoload')
  vars.defsym('Qmacro', 'macro')
  vars.defsym('Qand_rest', '&rest')
  vars.defsym('Qand_optional', '&optional')
  vars.defsym('Qclosure', 'closure')
  vars.defsym('Qexit', 'exit')
  vars.defsym('Qdebug', 'debug')

  vars.defsym('Qlexical_binding', 'lexical-binding')
  vars.defsym('QCsuccess', ':success')
  vars.defsym('QCdocumentation', ':documentation')

  vars.defsym('Qinteractive', 'interactive')
  vars.defsym('Qcommandp', 'commandp')

  vars.run_hooks = lread.intern_c_string('run-hooks')

  vars.defvar_lisp(
    'internal_make_interpreted_closure_function',
    'internal-make-interpreted-closure-function',
    [[Function to filter the env when constructing a closure.]]
  )
  vars.V.internal_make_interpreted_closure_function = vars.Qnil

  vars.defvar_lisp(
    'signal_hook_function',
    'signal-hook-function',
    [[If non-nil, this is a function for `signal' to call.
        It receives the same arguments that `signal' was given.
        The Edebug package uses this to regain control.]]
  )
  vars.V.signal_hook_function = vars.Qnil

  vars.defvar_lisp(
    'debug_on_signal',
    'debug-on-signal',
    [[Non-nil means call the debugger regardless of condition handlers.
        Note that `debug-on-error', `debug-on-quit' and friends
        still determine whether to handle the particular condition.]]
  )
  vars.V.debug_on_signal = vars.Qnil

  vars.defvar_lisp(
    'inhibit_debugger',
    'inhibit-debugger',
    [[Non-nil means never enter the debugger.
        Normally set while the debugger is already active, to avoid recursive
        invocations.]]
  )
  vars.V.inhibit_debugger = vars.Qnil

  vars.defvar_lisp(
    'debug_on_error',
    'debug-on-error',
    [[Non-nil means enter debugger if an error is signaled.
Does not apply to errors handled by `condition-case' or those
matched by `debug-ignored-errors'.
If the value is a list, an error only means to enter the debugger
if one of its condition symbols appears in the list.
When you evaluate an expression interactively, this variable
is temporarily non-nil if `eval-expression-debug-on-error' is non-nil.
The command `toggle-debug-on-error' toggles this.
See also the variable `debug-on-quit' and `inhibit-debugger'.]]
  )
  vars.V.debug_on_error = vars.Qnil
end
return M
