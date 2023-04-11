--- Iterator implementation.

---@class Iter
---@field fn function
local Iter = {}

Iter.__index = Iter

--- Add a filter step to the iterator.
---
--- @param f function(k:any, v:any):boolean Filtering function. Takes the key and value of the
---                                         current item and returns a truthy value if the item
---                                         should be kept
--- @return Iter
function Iter.filter(self, f)
  local fn = self.fn
  self.fn = function()
    while true do
      local args = { fn() }
      if args[1] == nil then break end
      if f(unpack(args)) then
        return unpack(args)
      end
    end
  end
  return self
end

--- Add a map step to the iterator.
---
--- @param f function(k:any, v:any):any Mapping function. Replace the given value with the return
---                                     value of this function.
--- @return Iter
function Iter.map(self, f)
  local fn = self.fn
  self.fn = function()
    local args = { fn() }
    if args[1] ~= nil then
      return f(unpack(args))
    end
  end
  return self
end

--- Create a new Iter object from a table of value.
---
--- @param src table|function Table or iterator to drain values from
--- @return Iter
function Iter.new(src)
  local iter = {}
  local fn
  if type(src) == 'table' then
    local f, s, var = pairs(src)
    fn = function()
      local k, v = f(s, var)
      var = k
      return k, v
    end
  elseif type(src) == 'function' then
    fn = src
  end
  assert(fn, 'src must be a table or function')

  local iter = { fn = fn }
  setmetatable(iter, Iter)
  return iter
end

function Iter.foreach(self, f)
  while true do
    local args = { self.fn() }
    if args[1] == nil then break end
    f(unpack(args))
  end
end

--- Fold an iterator into a single value.
---
--- Example:
--- <pre>
--- local it = Iter.new({1, 2, 3, 4, 5})
--- local sum = Iter.fold(0, function(acc, i, v) return acc + v end)
--- assert(sum == 15)
--- </pre>
---
--- @generic A
---
--- @param acc A Value to accumulate into.
--- @param f function(acc:A, k:any, v:any):A Accumulation function.
--- @return A
function Iter.fold(self, acc, f)
  local result = acc
  self:foreach(function(...)
    local args = { n = select('#', ...), ... }
    assert(args.n > 0, 'No value returned from accumulate function')
    result = f(result, unpack(args, 1, args.n))
  end)
  return result
end

--- Create a new table from all of the steps in the iterator.
---
--- @return table
function Iter.collect(self)
  local t = {}
  self:foreach(function(...)
    local args = { n = select('#', ...), ... }
    if args.n == 1 or (args.n == 2 and type(args[1]) == 'number') then
      t[#t + 1] = args[1]
    elseif args.n == 2 then
      t[args[1]] = args[2]
    else
      error(string.format('Cannot collect function with %d return values', args.n))
    end
  end)
  return t
end

return Iter
