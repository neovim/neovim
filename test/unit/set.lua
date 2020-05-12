-- a set class for fast union/diff, can always return a table with the lines
-- in the same relative order in which they were added by calling the
-- to_table method. It does this by keeping two lua tables that mirror each
-- other:
-- 1) index => item
-- 2) item => index
local Set = {}

function Set:new(items)
  local obj = {}
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

function Set:copy()
  local obj = {}
  obj.nelem = self.nelem
  obj.tbl = {}
  obj.items = {}
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

function Set:add(it)
  if not self:contains(it) then
    local idx = #self.tbl + 1
    self.tbl[idx] = it
    self.items[it] = idx
    self.nelem = self.nelem + 1
  end
end

function Set:remove(it)
  if self:contains(it) then
    local idx = self.items[it]
    self.tbl[idx] = nil
    self.items[it] = nil
    self.nelem = self.nelem - 1
  end
end

function Set:contains(it)
  return self.items[it] or false
end

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

function Set:to_table()
  -- there might be gaps in @tbl, so we have to be careful and sort first
  local keys
  do
    local _accum_0 = { }
    local _len_0 = 1
    for idx, _ in pairs(self.tbl) do
      _accum_0[_len_0] = idx
      _len_0 = _len_0 + 1
    end
    keys = _accum_0
  end
  table.sort(keys)
  local copy
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #keys do
      local idx = keys[_index_0]
      _accum_0[_len_0] = self.tbl[idx]
      _len_0 = _len_0 + 1
    end
    copy = _accum_0
  end
  return copy
end

return Set
