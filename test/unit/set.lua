-- a set class for fast union/diff, can always return a table with the lines
-- in the same relative order in which they were added by calling the
-- to_table method. It does this by keeping two lua tables that mirror each
-- other:
-- 1) index => item
-- 2) item => index
--- @class Set
--- @field nelem integer
--- @field items string[]
--- @field tbl table
local Set = {}

--- @param items? string[]
function Set:new(items)
  local obj = {} --- @type Set
  setmetatable(obj, self)
  self.__index = self

  if type(items) == 'table' then
    local tempset = Set:new()
    tempset:union_table(items)
    obj.tbl = tempset:raw_tbl()
    obj.items = tempset:raw_items()
    obj.nelem = tempset:size()
  else
    obj.tbl = {}
    obj.items = {}
    obj.nelem = 0
  end

  return obj
end

--- @return Set
function Set:copy()
  local obj = { nelem = self.nelem, tbl = {}, items = {} } --- @type Set
  for k, v in pairs(self.tbl) do
    obj.tbl[k] = v
  end
  for k, v in pairs(self.items) do
    obj.items[k] = v
  end
  setmetatable(obj, Set)
  obj.__index = Set
  return obj
end

-- adds the argument Set to this Set
--- @param other Set
function Set:union(other)
  for e in other:iterator() do
    self:add(e)
  end
end

-- adds the argument table to this Set
function Set:union_table(t)
  for _, v in pairs(t) do
    self:add(v)
  end
end

-- subtracts the argument Set from this Set
--- @param other Set
function Set:diff(other)
  if other:size() > self:size() then
    -- this set is smaller than the other set
    for e in self:iterator() do
      if other:contains(e) then
        self:remove(e)
      end
    end
  else
    -- this set is larger than the other set
    for e in other:iterator() do
      if self.items[e] then
        self:remove(e)
      end
    end
  end
end

--- @param it string
function Set:add(it)
  if not self:contains(it) then
    local idx = #self.tbl + 1
    self.tbl[idx] = it
    self.items[it] = idx
    self.nelem = self.nelem + 1
  end
end

--- @param it string
function Set:remove(it)
  if self:contains(it) then
    local idx = self.items[it]
    self.tbl[idx] = nil
    self.items[it] = nil
    self.nelem = self.nelem - 1
  end
end

--- @param it string
--- @return boolean
function Set:contains(it)
  return self.items[it] or false
end

--- @return integer
function Set:size()
  return self.nelem
end

function Set:raw_tbl()
  return self.tbl
end

function Set:raw_items()
  return self.items
end

function Set:iterator()
  return pairs(self.items)
end

--- @return string[]
function Set:to_table()
  -- there might be gaps in @tbl, so we have to be careful and sort first
  local keys = {} --- @type string[]
  for idx, _ in pairs(self.tbl) do
    keys[#keys + 1] = idx
  end

  table.sort(keys)
  local copy = {} --- @type string[]
  for _, idx in ipairs(keys) do
    copy[#copy + 1] = self.tbl[idx]
  end
  return copy
end

return Set
