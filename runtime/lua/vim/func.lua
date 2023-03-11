local M = {}

table.pack = table.pack or function(...) return { n = select("#", ...), ... } end
-- function:wrapper map, where "function" itself may be a wrapper.
local _fns = setmetatable({}, { __mode = 'kv' })  -- weaktable

--- Sets function `container[key]` to a new (wrapper) function that calls `fn()` before optionally
--- calling the original ("base") function.
---
--- The result of `fn()` decides how the base function is invoked. Given `fn()`:
--- <pre>
---   function()
---     …
---     return [r1, […, rn]]
---   end
--- </pre>
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
--- <pre>
--- vim.on_fun(vim, 'paste', function()
---   counter = counter + 1
--- end)
--- </pre>
---
--- Example: to modify the config during an LSP request (like the old `vim.lsp.with()` function):
--- <pre>
--- vim.on_fun(vim.lsp.handlers, 'textDocument/definition', function(err, result, ctx, config)
---   return true, err, result, ctx, vim.tbl_deep_extend('force', config or {}, override_config)
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
---   - ✓ XXX ??? idempontent (safe to call redundantly with identical args, will be ignored)
---   - ✓ supports :unhook()
---   - ✓ supports inspection (visiblity)
---   - ✗ does logging
---   - ✗ supports auto-removal tied to a container scope (via weaktables)
---   - ✗ supports buf/win/tab-local definitions
---   - ✗ supports namespaces
---
---@param container table
---@param key string
---@param fn function Hook handler
---@return table with .unhook()
function M.on_fun(container, key, fn)
  -- "Report mode": gather info from all wrapper functions.
  if container == nil and key == nil and fn == nil then
    local report = {
      maxdepth = 0,
      total = 0,
      rawcount = 0,
    }
    for k,v in pairs(_fns) do
      report.rawcount = report.rawcount + 1
      local info = v(_fns)
      if info and k ~= v then
        local depth = 1
        local w = info.basefn
        -- O(n^2): calculate depth.
        while w and depth < 9999 do
          depth = depth + 1
          -- O(n): check if w is a wrapper function.
          local iswrapper = #vim.tbl_filter(function(o) return w == o end,
            vim.tbl_values(_fns)) > 0
          w = iswrapper and w(_fns).basefn or nil
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
        report.maxdepth = report.maxdepth > depth and report.maxdepth or depth
      end
    end
    return report
  end

  local basefn = container[key] or function() end  -- !Intentionally allow container.key to be nil?
  local old_wrapper = _fns[fn]
  local info = old_wrapper and old_wrapper(_fns) or setmetatable({
    last_set_by = nil,
    container = nil,
    basefn = nil,
    name = nil,
  }, { __mode = 'v' })  -- weaktable

  local function unhooker(wrapper_)
    return {
      clear = function()
        container[key] = basefn
      end,

      unhook = function()
        -- O(n): find the "child" whose parent (basefn) is the one being disposed.
        local child = vim.tbl_filter(function(w)
            local info = w(_fns)
            return info and info.basefn == wrapper_ and container == info.container
          end, vim.tbl_values(_fns))
        if child[1] then
          -- To delete (unhook) the current hook,
          -- set the child's parent to its grandparent.
          child[1](_fns).basefn = basefn
        else
          container[key] = basefn
        end
      end,
    }
  end

  -- Skip redundant invocations.
  -- XXX: Doesn't work if the same fn is overridden in multiple containers.
  if basefn == fn or (key == info.name and info.container == container) then
    local un = unhooker(old_wrapper)
    un.skip = true
    return un
  end

  info.name = key
  info.container = container
  info.basefn = basefn

  local caller = nil
  for i=2,4 do
    local c = debug.getinfo(i, 'n')
    if c == nil or c.name == nil then break end
    caller = caller and ('%s/%s'):format(caller, c.name) or c.name
  end
  info.last_set_by = caller

  local wrapper = function(...)  -- New wrapper.
    -- "Info" mode (use _fns as a sigil).
    if ({...})[1] == _fns then
      return info
    end

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

  -- housekeeping (weaktable)
  _fns[fn] = wrapper
  _fns[wrapper] = wrapper

  return unhooker(wrapper)
end

return M
