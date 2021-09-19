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

--- Wrap a function to return nil if it fails, otherwise the value
function F.nil_wrap(fn)
  return function(...)
    return F.npcall(fn, ...)
  end
end


return F
