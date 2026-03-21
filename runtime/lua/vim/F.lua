local F = {}

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
--- assert(vim.F.if_nil(a, b, c, d) == 42)
--- ```
---
---@generic T
---@param ... T
---@return T
function F.if_nil(...)
  local nargs = select('#', ...)
  for i = 1, nargs do
    local v = select(i, ...)
    if v ~= nil then
      return v
    end
  end
  return nil
end

-- Use in combination with pcall
function F.ok_or_nil(status, ...)
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
function F.npcall(fn, ...)
  return F.ok_or_nil(pcall(fn, ...))
end

--- Wrap a function to return nil if it fails, otherwise the value
function F.nil_wrap(fn)
  return function(...)
    return F.npcall(fn, ...)
  end
end

--- like {...} except preserve the length explicitly
function F.pack_len(...)
  return { n = select('#', ...), ... }
end

--- like unpack() but use the length set by F.pack_len if present
function F.unpack_len(t)
  return unpack(t, 1, t.n)
end

return F
