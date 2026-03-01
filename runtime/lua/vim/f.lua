local M = {}

--- Returns the first argument which is not nil.
---
--- If all arguments are nil, returns nil.
---
--- Examples:
---
--- ```lua
--- local a = nil
--- local b = nil
--- local c = 42
--- local d = true
--- assert(vim.f.if_nil(a, b, c, d) == 42)
--- ```
---
---@generic T
---@param ... T
---@return T
function M.if_nil(...)
  vim.deprecate('vim.F.if_nil', '(a or b or …)', '0.13')
  local nargs = select('#', ...)
  for i = 1, nargs do
    local v = select(i, ...)
    if v ~= nil then
      return v
    end
  end
  return nil
end

---@deprecated
function M.ok_or_nil(status, ...)
  vim.deprecate('vim.f.ok_or_nil', 'actual error handling', '0.13')
  if not status then
    return
  end
  return ...
end

-- Nil pcall.
--- @generic T
--- @param fn  fun(...):T
--- @param ... T?
--- @return T
function M.npcall(fn, ...)
  return M.ok_or_nil(pcall(fn, ...))
end

---@deprecated
function M.nil_wrap(fn)
  vim.deprecate('vim.f.nil_wrap', 'actual error handling', '0.13')
  return function(...)
    return M.npcall(fn, ...)
  end
end

--- like {...} except preserve the length explicitly
function M.pack_len(...)
  return { n = select('#', ...), ... }
end

--- like unpack() but use the length set by f.pack_len if present
function M.unpack_len(t)
  return unpack(t, 1, t.n)
end

return M
