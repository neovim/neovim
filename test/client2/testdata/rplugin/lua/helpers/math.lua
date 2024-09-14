local function add(...)
  local result = 0
  for _, v in pairs {...} do
    result = result + v
  end
  return result
end

local function sub(...)
  local result = 0
  for _, v in pairs {...} do
    result = result - v
  end
  return result
end

return { add = add, sub = sub }
