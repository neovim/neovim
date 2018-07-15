
local meta = {}

meta.Enum = {
  new = function(self, map)
    return setmetatable(map, self)
  end,

  __index = function(t, k)
    error("attempt to get unknown enum " .. k .. "from " .. tostring(t), 2)
  end,

  __newindex = function(t, k, v)
    error(
      string.format("attempt to update enum table with %s, %s, %s", t, k, v),
      2)
  end
}

return meta
