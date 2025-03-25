local M = {}
M.max = 0x1fffffffffffff
M.min = -0x20000000000000
local function check_overflow(res, a, b, undo)
  if res >= 0x20000000000000 or res < -0x20000000000000 then
    return nil
  elseif res == -0x20000000000000 then
    if undo(a) == b and undo(b) == a then
      return res
    end
    return nil
  end
  return res
end
---@param a number|nil
---@param b number|nil
---@return number|nil
function M.mul(a, b)
  if a == nil or b == nil then
    return nil
  end
  local res = a * b
  return check_overflow(res, a, b, function(x)
    return res / x
  end)
end
---@param a number|nil
---@param b number|nil
---@return number|nil
function M.add(a, b)
  if a == nil or b == nil then
    return nil
  end
  local res = a + b
  return check_overflow(res, a, b, function(x)
    return res - x
  end)
end
---@param a number|nil
---@param b number|nil
---@return number|nil
function M.sub(a, b)
  if a == nil or b == nil then
    return nil
  end
  local res = a - b
  return check_overflow(res, a, b, function(x)
    return res + x
  end)
end
---@param a number|nil
---@param b number|nil
---@return number|nil
function M.mul_2exp(a, b)
  if a == nil or b == nil then
    return nil
  end
  assert(math.floor(b) == b and b > 0)
  for _ = 1, b do
    a = M.mul(a, 2)
    if a == nil then
      return nil
    end
  end
  return a
end
return M
