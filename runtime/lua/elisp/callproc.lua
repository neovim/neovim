local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local alloc = require 'elisp.alloc'
local b = require 'elisp.bytes'
local M = {}

---@type vim.elisp.F
local F = {}
---@return true|string|nil
local function getenv_internal_1(variable, env)
  while lisp.consp(env) do
    local entry = lisp.xcar(env)
    if lisp.stringp(entry) and lisp.sdata(entry):sub(1, #variable) == variable then
      if lisp.sref(entry, #variable) == b '=' then
        return lisp.sdata(entry):sub(#variable + 2)
      else
        return true
      end
    end
    env = lisp.xcdr(env)
  end
end
---@return true|string|false
local function getenv_internal(variable, env)
  local value = getenv_internal_1(variable, vars.V.process_environment)
  if value then
    return value
  end
  if variable == 'DISPLAY' then
    error('TODO')
  end
  return false
end
F.getenv_internal = {
  'getenv-internal',
  1,
  2,
  0,
  [[Get the value of environment variable VARIABLE.
VARIABLE should be a string.  Value is nil if VARIABLE is undefined in
the environment.  Otherwise, value is a string.

This function searches `process-environment' for VARIABLE.

If optional parameter ENV is a list, then search this list instead of
`process-environment', and return t when encountering a negative entry
\(an entry for a variable with no value).]],
}
function F.getenv_internal.f(variable, env)
  lisp.check_string(variable)
  if lisp.consp(env) then
    error('TODO')
  end
  local value = getenv_internal(lisp.sdata(variable), env)
  if value and value ~= true then
    return alloc.make_string(value)
  end
  return vars.Qnil
end

function M.init_syms()
  vars.defsubr(F, 'getenv_internal')

  vars.defvar_forward(
    'process_environment',
    'process-environment',
    [[List of overridden environment variables for subprocesses to inherit.
Each element should be a string of the form ENVVARNAME=VALUE.

Entries in this list take precedence to those in the frame-local
environments.  Therefore, let-binding `process-environment' is an easy
way to temporarily change the value of an environment variable,
irrespective of where it comes from.  To use `process-environment' to
remove an environment variable, include only its name in the list,
without "=VALUE".

This variable is set to nil when Emacs starts.

If multiple entries define the same variable, the first one always
takes precedence.

Non-ASCII characters are encoded according to the initial value of
`locale-coding-system', i.e. the elements must normally be decoded for
use.

See `setenv' and `getenv'.]],
    function()
      if _G.vim_elisp_later then
        error('TODO: the returned value may be changed (by setcdr/setcar)')
        error('TODO: also, it may be changed by neovim and not reflected')
      end
      local list = vars.Qnil
      for k, v in pairs(vim.fn.environ()) do
        if v == '' then
          list = vars.F.cons(alloc.make_string(k), list)
        else
          list = vars.F.cons(alloc.make_string(k .. '=' .. v), list)
        end
      end
      return list
    end,
    function(obj)
      error('TODO')
    end
  )

  vars.defvar_lisp(
    'data_directory',
    'data-directory',
    [[Directory of machine-independent files that come with GNU Emacs.
These are files intended for Emacs to use while it runs.]]
  )
  vars.V.data_directory = alloc.make_string(_G.vim_elisp_data_path)
end
return M
