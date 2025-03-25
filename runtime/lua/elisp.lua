--- @brief
---
--- TODO: docs

local lread = require 'elisp.lread'
local eval = require 'elisp.eval'
local main_thread = require 'elisp.main_thread'
local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'
local alloc = require 'elisp.alloc'
local specpdl = require 'elisp.specpdl'

local inited=false

--- Lua table representing an elisp object.
---@class vim.elisp.obj

local M = {}
--- A promise object. Most often returned when `(recursive-edit)` is called.
---@class vim.elisp.eval.promise
---@field [1] 'promise'
---  Always the string `'promise'`. Useful to distinguish from
---  `vim.elisp.obj` whose first element will never be `'promise'`.
---@field [2] true|'error'|nil
--- - When `nil`: The promise is still pending.
--- - When `true`: The promise is resolved.
--- - When `'error'`: There was an error while evaluating.
---@field [3] vim.elisp.obj|nil
--- - The value of the resolved promise.

--- Evaluates a string or an |vim.elisp.object|.
---@param form string|vim.elisp.obj
---@param callback fun(ret:vim.elisp.obj?)?
--- Runs when the promise is resolved.
---@return vim.elisp.obj|vim.elisp.eval.promise?
--- The last value, simplar to `(progn ...)`.
--- If there's no such value (happens when {form} is empty or just comments)
--- then `nil` is returned.
--- If `(recursive-edit)` is called, returns `vim.elisp.eval.promise`.
function M.eval(form, callback)
  if not inited then
    error('elisp module not initialized, run `require("elisp").init()`')
  end
  ---@type vim.elisp.eval.promise?
  local promise
  local done
  local ret
  local noerr, errmsg = main_thread.call(function()
    local count = specpdl.index()
    local is_error = true
    specpdl.record_unwind_protect(function()
      if is_error and promise then
        promise[2] = 'error'
      elseif promise then
        promise[2] = true
        promise[3] = ret
      elseif is_error then
      else
        done = true
      end
    end)
    if type(form) == 'string' then
      for _, cons in ipairs(lread.full_read_lua_string(form)) do
        ret = eval.eval_sub(cons)
      end
      is_error = false
    else
      ret = eval.eval_sub(form)
      is_error = false
    end
    if callback then
      callback(ret)
    end
    specpdl.unbind_to(count, nil)
  end)
  if not noerr then
    error(errmsg, 0)
  elseif done then
    return ret
  else
    promise = { 'promise' }
    return promise
  end
end

--- Loads a lisp file.
---@param path string
---@return vim.elisp.obj|vim.elisp.eval.promise?
---  See |vim.elisp.eval|'s return value explanation.
function M.load(path)
  return M.eval(lisp.list(vars.Qload, alloc.make_string(path)))
end

--- Initializes the elisp module.
---
--- (TODO: change this later) You must/may set the following global lua
--- variables before calling this function:
--- - `_G.vim_elisp_load_path` (`string[]`) NEEDED, a list of lisp
---   directories. Typically `{'/usr/share/emacs/29.4/lisp/'}`
--- - `_G.vim_elisp_data_path` (`string`) NEEDED, the data directory.
---   Typically {'/usr/share/emacs/29.4/etc/'}
--- - `_G.vim_elisp_optimize_jit` (`boolean?`) Optional, optimizes the jit by
---   disabling it in specific places. Defaults to `false`.
--- - `_G.vim_elisp_compile_lisp_to_lua_path` (`string?`) Optional, where to
---   place compiled lisp files.
---
---@return nil
function M.init()
  inited=true
  require 'elisp.initer'
end
return M
