local F = {}

--- Returns {a} if it is not nil, otherwise returns {b}.
---
--@param a
--@param b
function F.if_nil(a, b)
  if a == nil then return b end
  return a
end

-- Use in combination with pcall
function F.ok_or_nil(status, ...)
  if not status then return end
  return ...
end

-- Nil pcall.
function F.npcall(fn, ...)
  return F.ok_or_nil(pcall(fn, ...))
end


return F
