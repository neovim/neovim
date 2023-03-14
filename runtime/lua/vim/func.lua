--- Nvim "functional" and "iterable" stdlib.
---
--- TODO(justinmk):
---   - vim.fu.merge()
---   - deprecate vim.tbl_xx

local M = {}

table.pack = table.pack or function(...) return { n = select("#", ...), ... } end
-- Map of wrappers id:info.
local _wrs = {}  ---@type table<string,table<string,any>>

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
--- For `on_fun()`. Disposes (unhooks) a function created by `on_fun()`.
---
--- This intentionally lives outside of on_fun to make it obvious what scope it closes over: must
--- not hold references to `fn`, `container`, etc., so GC works.
---
--- @param wid string wrapper function id
local function _on_fun_return_handle(wid)
  local unhook = function()
    local info = _wrs[wid]
    if not info then  -- Already disposed.
      return nil
    end

    -- O(n): find the child whose parent (basefn) is the one being disposed.
    local child = vim.tbl_filter(function(w)
        return w.basefn == _wrs[wid].wrapper and _wrs[wid].container == w.container
      end, vim.tbl_values(_wrs))

    _wrs[wid] = nil

    if not child[1] then
      -- Direction: UP
      -- Deleting the "head" hook, update head to its parent (basefn).
      info.container[info.name] = info.basefn
      -- Return a handle to the replacement hook.
      return _on_fun_return_handle(tostring(info.basefn))
    else
      -- Direction: DOWN
      -- To delete the hook without breaking the "chain", set its parent to the grandparent.
      child[1].basefn = info.basefn
      -- Return a handle to the child.
      return _on_fun_return_handle(tostring(child[1].wrapper))
    end
  end

  return {
    --- @private
    ---
    --- Clears all descendant hooks.
    clear = function()
      local r = unhook()
      if not r then
        -- Nothing to do. No more hooks in the chain.
        return false
      end
      while r do
        r = r.unhook()
      end
      return true
      -- if (depth < 9999) then
      --   -- TODO: logging ...
      -- end
      -- TODO Clean up any dangling hooks.
    end,

    --- @private
    ---
    --- Disposes/deletes/removes a hook from the chain of hooks, and returns a handle to the child
    --- hook (if any) or else the parent hook, or nil if the chain is empty.
    ---
    --- This bi-directional behavior means that calling handle.unhook().unhook().… until `nil` is
    --- returned, removes all hooks in the chain.
    ---
    --- @return table|nil handle with { .unhook() } to the next hook if successfully disposed, or
    --- nil if already disposed or 
    unhook = unhook,
  }
end

local function _ignore() end

--- Sets function `container[key]` to a new "wrapper" function `function(fn, args)`, where `fn` is
--- the original ("base") function and `args` contains the packed args.
---
--- Returns an object with `.unhook()` which can be used to "unhook" the function (remove it from
--- the chain of `container[key]` hooks):
---     <pre>lua
---     local h = vim.func.on_fun(vim, 'print', function(fn, args)
---       fn(('%s hooked'):format(args[1]))
---     end)
---     vim.print('x')  -- => "x hooked"
---     h.unhook()
---     vim.print('x')  -- => "x"
---     </pre>
---
--- Examples:
---     <pre>lua
---     -- Do something BEFORE the original function:
---     vim.on_fun(vim, 'paste', function(fn, args)
---       vim.print('before')
---       return fn(unpack(args))
---     end)
---
---     -- Do something AFTER the original function:
---     vim.on_fun(vim, 'paste', function(fn, args)
---       local r = pack(fn(unpack(args)))
---       vim.print('after')
---       return unpack(r)
---     end)
---
---     -- Modify the config of an LSP request (like the old "vim.lsp.with()"):
---     vim.on_fun(vim.lsp.handlers, 'textDocument/definition', function(fn, args)
---       args.config.signs = true
---       args.config.virtual_text = false
---       return fn(unpack(args))
---     end)
---     </pre>
---
--- Compared to this Lua idiom:
---     <pre>lua
---     vim.foo = (function(fn)
---       return function(...)
---         vim.print('before')
---         fn(...)
---       end
---     end)(vim.foo)
---     </pre>
---
--- on_fun() has these differences:
--- - ✓ supports .unhook()
--- - ✓ supports inspection (visiblity)
--- - ✗ does logging
--- - ✗ supports auto-removal tied to a container scope (via weaktables)
--- - ✗ supports buf/win/tab-local definitions
--- - ✗ supports namespaces
--- - ✗ idempontent (safe to call redundantly with identical args, will be ignored)
---
--- @param container table
--- @param key string Function field on `container`
--- @param fn function Function that hooks into `container[key]`
--- @return table handle provides `.unhook()`
function M.on_fun(container, key, fn)
  if container == nil and key == nil and fn == nil then
    -- "Report mode": gather info from all wrapper functions.
    return _on_fun_report()
  end

  local basefn = container[key] or nil
  -- TODO(justinmk): Allow container.key to be nil?
  assert(basefn)

  local wid = {}
  local wrapper = function(...)
    -- TODO(justinmk): logging/tracing
    local args = table.pack(...)
    return fn(_wrs[wid[1]].basefn, args)
  end
  container[key] = wrapper
  -- Tricky: Let the function gets its own id, instead of referencing `basefn` directly.
  -- So GC works after .unhook().
  wid[1] = tostring(wrapper)

  -- Get caller, for debugging/inspection.
  local caller = nil
  for i=2,4 do
    local c = debug.getinfo(i, 'n')
    if c == nil or c.name == nil then break end
    caller = caller and ('%s/%s'):format(caller, c.name) or c.name
  end

  -- bookkeeping
  _wrs[tostring(wrapper)] = { -- setmetatable({
    basefn = basefn,
    container = container,
    last_set_by = caller,
    name = key,
    wrapper = wrapper,
  } --, { __mode = 'v' })  -- weaktable

  return _on_fun_return_handle(tostring(wrapper))
end

return M
