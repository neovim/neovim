--- Iterator implementation.

---@class Iter
---@field fn function
local Iter = {}

Iter.__index = Iter

Iter.__call = function(self)
  return self.fn()
end

--- Add a filter step to the iterator.
---
--- @param f function(...):boolean Filtering function. Takes all values returned from the previous
---                                stage in the pipeline as arguments and returns a truthy value if
---                                those items should be kept.
--- @return Iter
function Iter.filter(self, f)
  local fn = self.fn
  self.fn = function()
    while true do
      local args = { fn() }
      if args[1] == nil then
        break
      end
      if f(unpack(args)) then
        return unpack(args)
      end
    end
  end
  return self
end

--- Add a map step to the iterator.
---
--- @param f function(...):any Mapping function. Takes all values returned from the previous stage
---                            in the pipeline as arguments and returns a new value. Nil values
---                            returned from `f` are filtered from the output.
--- @return Iter
function Iter.map(self, f)
  local fn = self.fn
  self.fn = function()
    while true do
      local args = { fn() }
      if args[1] == nil then
        break
      end
      local result = { f(unpack(args)) }
      if result[1] ~= nil then
        return unpack(result)
      end
    end
  end
  return self
end

--- Create a new Iter object from a table of value.
---
--- @param src table|function Table or iterator to drain values from
--- @return Iter
function Iter.new(src)
  local fn
  if type(src) == 'table' then
    local f, s, var = ipairs(src)
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

--- Call a function once for each item in the pipeline.
---
--- This is used for functions which have side effects. To modify the values in the iterator, use
--- |Iter.map()|.
---
--- Invalidates the iterator.
---
--- @param f function(...) Function to execute for each item in the pipeline. Takes all of the
---                        values from the previous stage in the pipeline as arguments.
function Iter.foreach(self, f)
  while true do
    local args = { self.fn() }
    if args[1] == nil then
      break
    end
    f(unpack(args))
  end
end

--- Fold an iterator into a single value.
---
--- Invalidates the iterator.
---
--- Example:
--- <pre>
--- local it = Iter.new({1, 2, 3, 4, 5})
--- local sum = it:fold(0, function(acc, _, v) return acc + v end)
--- assert(sum == 15)
--- </pre>
---
--- @generic A
---
--- @param acc A Value to accumulate into.
--- @param f function(acc:A, ...):A Accumulation function. Takes the current accumulated value and
---                                 all of the values from the previous stage in the pipeline as
---                                 arguments, and returns the updated accumulation value.
--- @return A
function Iter.fold(self, acc, f)
  local result = acc
  self:foreach(function(...)
    local args = { n = select('#', ...), ... }
    assert(args.n > 0, 'Cannot fold iterator with no return value')
    result = f(result, unpack(args, 1, args.n))
  end)
  return result
end

--- Create a new table from all of the steps in the iterator.
---
--- The final stage in the iterator pipeline must return 1 or 2 values. If only one value is
--- returned, or if two values are returned and the first value is a number, an "array-like" table
--- is returned. Otherwise, the first return value is used as the table key and the second return
--- value as the table value.
---
--- Invalidates the iterator.
---
--- @return table
function Iter.collect(self)
  local t = {}
  self:foreach(function(...)
    local args = { n = select('#', ...), ... }
    if args.n == 1 then
      t[#t + 1] = args[1]
    elseif args.n == 2 then
      if type(args[1]) == 'number' then
        t[#t + 1] = args[2]
      else
        t[args[1]] = args[2]
      end
    else
      error(string.format('Cannot collect iterator with %d return values', args.n))
    end
  end)
  return t
end

--- Return the next value from the iterator.
---
--- @return any
function Iter.next(self)
  return self.fn()
end

--- Reverse an iterator.
---
--- @return Iter
function Iter.rev(self)
  local t = self:collect()
  local i = #t
  local n = 0
  self.fn = function()
    if i > 0 then
      local v = t[i]
      i = i - 1
      n = n + 1
      return n, v
    end
  end
  return self
end

--- Sort an iterator
---
--- @param comp function Comparison function. See |table.sort()| for details.
--- @return Iter
function Iter.sort(self, comp)
  local t = self:collect()
  table.sort(t, comp)
  local f, s, var = ipairs(t)
  self.fn = function()
    local k, v = f(s, var)
    var = k
    return k, v
  end
  return self
end

return Iter
