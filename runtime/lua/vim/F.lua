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
--- @deprecated
--- @generic T
--- @param ... T
--- @return T
function F.if_nil(...)
  vim.deprecate('vim.F.if_nil', 'vim.nonnil', '0.14')
  return vim.nonnil(...)
end

-- Use in combination with pcall
--- @deprecated
function F.ok_or_nil(status, ...)
  vim.deprecate('vim.F.ok_or_nil', 'actual error handling', '0.14')
  if not status then
    return
  end
  return ...
end

-- Nil pcall.
--- @deprecated
--- @generic T
--- @param fn  fun(...):T
--- @param ... T?
--- @return T
function F.npcall(fn, ...)
  vim.deprecate('vim.F.npcall', 'vim.npcall', '0.14')
  return vim.npcall(fn, ...)
end

--- Wrap a function to return nil if it fails, otherwise the value
--- @deprecated
function F.nil_wrap(fn)
  vim.deprecate('vim.F.nil_wrap', 'vim.npcall', '0.14')
  return function(...)
    return vim.npcall(fn, ...)
  end
end

-- TODO: deprecate `F.pack_len` and `F.unpack_len`

--- like {...} except preserve the length explicitly
function F.pack_len(...)
  return { n = select('#', ...), ... }
end

--- like unpack() but use the length set by F.pack_len if present
function F.unpack_len(t)
  return unpack(t, 1, t.n)
end

return F
