local F = {}

--- Returns {a} if it is not nil, otherwise returns {b}.
---
---@param a
---@param b
function F.if_nil(a, b)
  if a == nil then
    return b
  end
  return a
end

-- Use in combination with pcall
function F.ok_or_nil(status, ...)
  if not status then
    return
  end
  return ...
end

-- Nil pcall.
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
