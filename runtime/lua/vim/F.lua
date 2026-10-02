local F = {}

-- Failure returns no values, so every result becomes optional.
--- @nodoc
--- @alias vim.F.OptionalReturns<T> { [K in keyof T]: T[K]|nil }

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
  vim.deprecate('vim.F.if_nil', 'vim.nonnil', '0.15')
  return vim.nonnil(...)
end

-- Use in combination with pcall
--- @deprecated
--- @generic T...
--- @param status boolean
--- @param ... T...
--- @return vim.F.OptionalReturns<T>...
function F.ok_or_nil(status, ...)
  vim.deprecate('vim.F.ok_or_nil', 'actual error handling', '0.15')
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
  vim.deprecate('vim.F.npcall', 'vim.npcall', '0.15')
  return vim.npcall(fn, ...)
end

--- Wrap a function to return nil if it fails, otherwise the value
--- @deprecated
--- @generic A..., R...
--- @param fn fun(...: A...): R...
--- @return fun(...: A...): vim.F.OptionalReturns<R>...
function F.nil_wrap(fn)
  vim.deprecate('vim.F.nil_wrap', 'vim.npcall', '0.15')
  return function(...)
    return vim.npcall(fn, ...)
  end
end

-- TODO: deprecate `F.pack_len` and `F.unpack_len`

--- like {...} except preserve the length explicitly
--- @param ... any
--- @return { [integer]: any, n: integer }
function F.pack_len(...)
  return { n = select('#', ...), ... }
end

--- like unpack() but use the length set by F.pack_len if present
--- @param t { [integer]: any, n?: integer }
--- @return any...
function F.unpack_len(t)
  return unpack(t, 1, t.n or #t)
end

return F
