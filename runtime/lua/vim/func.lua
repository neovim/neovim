local M = {}

table.pack = table.pack or function(...) return { n = select("#", ...), ... } end
local _on_fun_map = setmetatable({}, { __mode = 'kv' })  -- weaktable

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
    }
    for _,v in pairs(_on_fun_map) do
      if v == true then
        -- TODO: yucky... skip wrapper placeholder items
      else
        local info = v(_on_fun_map)
        local depth = 1
        local f = info.basefn
        while f and depth < 9999 do
          depth = depth + 1
          f = f(_on_fun_map).basefn
        end
        report[tostring(info.container)] = report[tostring(info.container)] or {}
        local item = report[tostring(info.container)]
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

  local basefn = container[key] or function() end  -- !Intentionally allow container.key to be nil.
  local info = type(_on_fun_map[fn]) == 'function' and _on_fun_map[fn](_on_fun_map) or setmetatable({
    last_set_by = nil,
    container = nil,
    basefn = nil,
    name = nil,
  }, { __mode = 'v' })  -- weaktable

  -- Skip redundant invocations.
  -- This won't work if the same fn exists on, and is overridden in, multiple containers.
  if basefn == fn or (key == info.name and info.container == tostring(container)) then
    return {
      skip = true,
      unhook = function()
        container[key] = basefn
      end,
    }
  end
  info.name = key
  info.container = tostring(container)
  -- Only store known basefn (so we can invoke its "Info mode").
  info.basefn = _on_fun_map[basefn] and basefn or nil

  local caller = nil
  for i=2,4 do
    local c = debug.getinfo(i, 'n')
    if c == nil or c.name == nil then break end
    caller = caller and ('%s/%s'):format(caller, c.name) or c.name
  end
  info.last_set_by = caller

  local wrapper = function(...)
    -- "Info" mode (use _on_fun_map as a sigil).
    if ({...})[1] == _on_fun_map then
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
  _on_fun_map[fn] = wrapper  -- weaktable reference
  -- TODO: yucky... wrapper placeholder
  _on_fun_map[wrapper] = _on_fun_map[wrapper] or true

  return {
    unhook = function()
      container[key] = basefn
    end,
  }
end

return M
