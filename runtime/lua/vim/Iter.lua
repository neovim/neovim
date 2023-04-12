--- Iterator implementation.

---@class Iter
---@field fn function
local Iter = {}

Iter.__index = Iter

Iter.__call = function(self)
  return self:next()
end

--- Add a filter/map step to the iterator.
---
--- Example:
--- <pre>
--- -- Remove odd numbers
--- vim.iter({1, 2, 3, 4}):filter_map(function(v)
---   return v % 2 == 0 and v else nil
--- end)
--- </pre>
---
--- @param f function(...):any Mapping function. Takes all values returned from the previous stage
---                            in the pipeline as arguments and returns a new value. Nil values
---                            returned from `f` are filtered from the output.
--- @return Iter
function Iter.filter_map(self, f)
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

--- Call a function once for each item in the pipeline.
---
--- This is used for functions which have side effects. To modify the values in the iterator, use
--- |Iter.filter_map()|.
---
--- This function drains the iterator.
---
--- @param f function(...) Function to execute for each item in the pipeline. Takes all of the
---                        values returned by the previous stage in the pipeline as arguments.
function Iter.foreach(self, f)
  while true do
    local args = { self.fn() }
    if args[1] == nil then
      break
    end
    f(unpack(args))
  end
end

--- Drain the iterator into a table.
---
--- The final stage in the iterator pipeline must return 1 or 2 values. If only one value is
--- returned, or if two values are returned and the first value is a number, an "array-like" table
--- is returned. Otherwise, the first return value is used as the table key and the second return
--- value as the table value.
---
--- @param opts ?table Optional arguments:
---                     - sort (boolean|function): If true, sort the resulting table before
---                       returning. If a function is provided, that function is used as the
---                       comparator function to |table.sort()|.
--- @return table
function Iter.collect(self, opts)
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
  if opts and opts.sort then
    local f = type(opts.sort) == 'function' and opts.sort or nil
    table.sort(t, f)
  end
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
--- Only iterators on tables can be reversed.
---
--- @return Iter
function Iter.rev(self)
  assert(self.head and self.tail, 'Non-table iterators cannot be reversed')
  local inc =  self.head < self.tail and -1 or 1
  self.head, self.tail = self.tail + inc, self.head + inc
  return self
end

--- Skip values in the iterator.
---
--- @param n number Number of values to skip.
--- @return Iter
function Iter.skip(self, n)
  for _ = 1, n do
    local _ = self.fn()
  end
  return self
end

--- Return the nth value in the iterator.
---
--- This function advances the iterator.
---
--- @param n number The index of the value to return.
--- @return any
function Iter.nth(self, n)
  if n > 0 then
    return self:skip(n - 1):next()
  end
end

--- Create a new Iter object from a table of value.
---
--- @param src table|function Table or iterator to drain values from
--- @return Iter
function Iter.new(src)
  local t = {}

  if type(src) == 'table' then
    t.head = 1
    t.tail = #src + 1
    t.fn = function()
      if t.head ~= t.tail then
        local i = t.head
        local v = src[i]
        if v ~= nil then
          local inc = t.head < t.tail and 1 or -1
          t.head = t.head + inc
          return i, v
        end
      end
    end
  elseif type(src) == 'function' then
    t.fn = src
  end
  assert(t.fn, 'src must be a table or function')

  setmetatable(t, Iter)
  return t
end


return Iter
