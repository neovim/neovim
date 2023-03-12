local M = {}

table.pack = table.pack or function(...) return { n = select("#", ...), ... } end
-- function_id:info map
local _wrs = {}

--- @private
---
--- For `on_fun()`. Returns info about all hooks, for use by :checkhealth.
local function _on_fun_report()
  local report = {
    maxdepth = 0,
    total = 0,
  }
  for _,info in pairs(_wrs) do
    local depth = 0
    local w = info.basefn
    while w and depth < 9999 do
      depth = depth + 1
      w = _wrs[tostring(w)] and _wrs[tostring(w)].basefn or nil
    end
    local cid = tostring(info.container)
    report[cid] = report[cid] or {}
    local item = report[cid]
    if not item[info.name] or depth > item[info.name].depth then
      item[info.name] = {
        last_set_by = info.last_set_by,
        depth = depth,
      }
    end
    report.total = report.total + 1
    report.maxdepth = depth > report.maxdepth and depth or report.maxdepth
  end
  return report
end

--- @private
---
--- For `on_fun()`. Disposes (unhooks) an `on_fun()` wrapper.
---
--- This intentionally lives outside of on_fun to make it obvious what scope it closes over: must
--- not hold references to `fn`, `container`, etc., so the weaktable works correctly.
---
--- @param wid string wrapper id
local function _on_fun_return_handle(wid)
  return {
    --- @private
    ---
    --- @return boolean true if successfully disposed, false if already disposed
    clear = function()
      local info = _wrs[wid]
      if not info then  -- Already disposed.
        return false
      end

      while info do
        _wrs[tostring(info.wrapper)] = nil
        info.container[info.name] = info.basefn
        info = _wrs[tostring(info.basefn)] or nil
      end

      -- if (depth < 9999) then
      --   -- TODO: logging ...
      -- end
      -- TODO Clean up any dangling hooks.

      return true
    end,

    --- @private
    ---
    --- Dispose/delete/remove a hook from the chain of hooks.
    --- @return boolean true if successfully disposed, false if already disposed
    unhook = function()
      local info = _wrs[wid]
      if not info then  -- Already disposed.
        return false
      end
      -- O(n): find the child whose parent (basefn) is the one being disposed.
      local child = vim.tbl_filter(function(w)
          return w.basefn == _wrs[wid].wrapper and _wrs[wid].container == w.container
        end, vim.tbl_values(_wrs))
      if child[1] then
        -- To delete (unhook) the hook we are disposing,
        -- 1. Set its parent to the grandparent.
        child[1].basefn = info.basefn
        -- 2. Redefine it as a passthrough wrapper. Lets GC collect it.
        info.container[info.name] = function(...)
          info.basefn(...)
          child[1].wrapper(...)
        end
      else  -- Disposing the "head" hook, so just point to its parent (basefn).
        info.container[info.name] = info.basefn
      end
      _wrs[wid] = nil
      return true
    end,
  }
end

local function foo()
end

--- Sets function `container[key]` to a new (wrapper) function that calls `fn()` before optionally
--- calling the original ("base") function.
---
--- The result of `fn()` decides how the base function is invoked. Given `fn()`:
--- <pre>lua
---   function()
---     …
---     return [r1, […, rn]]
---   end
--- </pre>
---
---   - no result: invoke base function with the original args.
---   - r1=false: skip base function; wrapper returns `[…, rn]`.
---   - r1=true: invoke base function with args `[…, rn]`, or original args if `[…, rn]` is empty.
---   - r1=function: like "r1=true", and invoke this "after" function after invoking the base
---     function. Result of "after function" decides the return value(s) of the wrapped function.
---
--- Modification of container-like parameters by fn() affects the parameters passed to the base
--- function.
---
--- Example: increment a counter when vim.paste() is called.
--- <pre>lua
--- vim.on_fun(vim, 'paste', function()
---   counter = counter + 1
--- end)
--- </pre>
---
--- Example: modify the config during an LSP request (compare the old `vim.lsp.with()` function):
--- <pre>lua
--- vim.on_fun(vim.lsp.handlers, 'textDocument/definition', function(err, result, ctx, config)
---   config.signs = true
---   config.virtual_text = false
---   return true, err, result, ctx, config
--- end)
--- </pre>
---
--- Compared to this Lua idiom:
--- <pre>lua
--- vim.foo = (function(basefn)
---   return function(...)
---     -- do stuff...
---     basefn(...)
---   end
--- end)(vim.foo)
--- </pre>
---
--- the difference is that vim.on_fun:
---   - ✓ supports .unhook()
---   - ✓ supports inspection (visiblity)
---   - ✗ does logging
---   - ✗ supports auto-removal tied to a container scope (via weaktables)
---   - ✗ supports buf/win/tab-local definitions
---   - ✗ supports namespaces
---   - ✗ idempontent (safe to call redundantly with identical args, will be ignored)
---
--- @param container table
--- @param key string
--- @param fn function Hook handler
--- @return table with .unhook()
function M.on_fun(container, key, fn)
  if container == nil and key == nil and fn == nil then
    -- "Report mode": gather info from all wrapper functions.
    return _on_fun_report()
  end

  local basefn = container[key] or function(...) end  -- !Intentionally allow container.key to be nil?

  local caller = nil
  for i=2,4 do
    local c = debug.getinfo(i, 'n')
    if c == nil or c.name == nil then break end
    caller = caller and ('%s/%s'):format(caller, c.name) or c.name
  end

  local info = setmetatable({
    basefn = basefn,
    container = container,
    last_set_by = caller,
    name = key,
    wrapper = nil,
  }, { __mode = 'v' })  -- weaktable

  local wrapper = function(...)  -- New wrapper.
    local r = table.pack(fn(...))
    -- Like pcall: r1 is "status", rest are args to basefn.
    local r1 = r[1]
    if r.n == 0 then  -- Invoke base function with the original args.
      return basefn(...)
    elseif r1 == false then  -- Skip base function.
      return unpack(r, 2, r.n)
    elseif r1 == true then  -- Invoke base function with args returned by fn().
      return basefn(unpack(r, 2, r.n))
    elseif type(r1) == 'function' then  -- "after" function.
      local rbase = table.pack(basefn(unpack(r, 2, r.n)))
      local r2 = table.pack(r1(...))
      if r2[1] == false then  -- "after" fn returned false, thus it controls the rv of the wrapper.
        return unpack(r2, 2, r2.n)
      end
      return unpack(rbase)
    else
      vim.validate{ fn = { fn, function() return false end, 'function() returning true[,…] false[,…] or nothing' } }
    end
  end
  container[key] = wrapper

  -- bookkeeping (weaktable)
  info.wrapper = wrapper
  _wrs[tostring(wrapper)] = info

  return _on_fun_return_handle(tostring(wrapper))
end

return M
