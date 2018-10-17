
local meta = {}

---
-- Provide a "strongly typed" dictionary in Lua.
--
-- Does not allow insertion or deletion after creation.
-- Only allows retrieval of created keys are allowed.
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

---
-- Provide a dictionary that will continue providing empty dictionaries upon access.
--
-- This allows you to do something like:
--  local myEmpty =- meta.EmptyDictionary({a = 'b'})
--  if myEmpty.b.a.c.d.e.f.g.i == nil then
--      // Do some error stuff here
--  end
meta.EmptyDictionary = {
  new = function(self, dictionary)
    if dictionary == nil then
      dictionary = {}
    end

    return setmetatable(dictionary, self)
  end,

  __index = function(self, key)
    if rawget(self, key) ~= nil then
      return rawget(self, key)
    end

    return setmetatable({}, self)
  end,
}

return meta
