--- Iterator implementation.

---@class Iter
---@field fn function
---@field head ?number
---@field tail ?number
local Iter = {}

Iter.__index = Iter

Iter.__call = function(self)
  return self:next()
end

--- Add a filter/map step to the iterator.
---
--- Example:
--- <pre>
--- > local it = vim.iter({ 1, 2, 3, 4 }):filter_map(function(i, v)
--- >   if v % 2 == 0 then
--- >     return i, v * 3
--- >   end
--- > end)
--- > it:collect()
--- { 6, 12 }
--- </pre>
---
---@param f function(...):any Mapping function. Takes all values returned from the previous stage
---                            in the pipeline as arguments and returns a new value. Nil values
---                            returned from `f` are filtered from the output.
---@return Iter
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
---@param f function(...) Function to execute for each item in the pipeline. Takes all of the
---                        values returned by the previous stage in the pipeline as arguments.
function Iter.foreach(self, f)
  while true do
    local args = { self:next() }
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
--- Example:
--- <pre>
---
--- > local it1 = vim.iter(string.gmatch('100 20 50', '%d+')):filter_map(tonumber)
--- > it1:collect()
--- { 100, 20, 50 }
--- > local it2 = vim.iter(string.gmatch('100 20 50', '%d+')):filter_map(tonumber)
--- > it2:collect({ sort = true })
--- { 20, 50, 100 }
---
--- </pre>
---
---@param opts ?table Optional arguments:
---                     - sort (boolean|function): If true, sort the resulting table before
---                       returning. If a function is provided, that function is used as the
---                       comparator function to |table.sort()|.
---@return table
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
--- Example:
--- <pre>
---
--- > local it = vim.iter(string.gmatch('1 2 3', '%d+')):filter_map(tonumber)
--- > it:next()
--- 1
--- > it:next()
--- 2
--- > it:next()
--- 3
---
--- </pre>
---
---@return any
function Iter.next(self)
  return self.fn()
end

--- Reverse an iterator.
---
--- Only iterators on tables can be reversed.
---
--- Example:
--- <pre>
---
--- > local it = vim.iter({ 3, 6, 9, 12 }):rev()
--- > it:collect()
--- { 12, 9, 6, 3 }
---
--- </pre>
---
---@return Iter
function Iter.rev(self)
  assert(self.head and self.tail, 'Non-table iterators cannot be reversed')
  local inc = self.head < self.tail and 1 or -1
  self.head, self.tail = self.tail - inc, self.head - inc
  return self
end

--- Skip values in the iterator.
---
--- Example:
--- <pre>
---
--- > local it = vim.iter({ 3, 6, 9, 12 }):skip(2)
--- > it:next()
--- 9
---
--- </pre>
---
---@param n number Number of values to skip.
---@return Iter
function Iter.skip(self, n)
  if self.head and self.tail then
    local inc = self.head < self.tail and n or -n
    self.head = self.head + inc
  else
    for _ = 1, n do
      local _ = self:next()
    end
  end
  return self
end

--- Return the nth value in the iterator.
---
--- This function advances the iterator.
---
--- Example:
--- <pre>
---
--- > local it = vim.iter({ 3, 6, 9, 12 })
--- > it:nth(2)
--- 6
--- > it:nth(2)
--- 12
---
--- </pre>
---
---@param n number The index of the value to return.
---@return any
function Iter.nth(self, n)
  if n > 0 then
    return self:skip(n - 1):next()
  end
end

--- Return true if any of the items in the iterator match the given predicate.
---
---@param pred function(...):bool Predicate function. Takes all values returned from the previous
---                                stage in the pipeline as arguments and returns true if the
---                                predicate matches.
function Iter.any(self, pred)
  local any = false
  while true do
    local args = { self:next() }
    if args[1] == nil then
      break
    end
    if pred(unpack(args)) then
      any = true
      break
    end
  end
  return any
end

--- Return true if all of the items in the iterator match the given predicate.
---
---@param pred function(...):bool Predicate function. Takes all values returned from the previous
---                                stage in the pipeline as arguments and returns true if the
---                                predicate matches.
function Iter.all(self, pred)
  local all = true
  while true do
    local args = { self:next() }
    if args[1] == nil then
      break
    end
    if not pred(unpack(args)) then
      all = false
      break
    end
  end
  return all
end

--- Return the last item in the iterator.
---
--- Drains the iterator.
---
--- Example:
--- <pre>
---
--- > local it = vim.iter(vim.gsplit('abcdefg', ''))
--- > it:last()
--- 'g'
---
--- > local it = vim.iter({ 3, 6, 9, 12, 15 })
--- > it:last()
--- 5	15
---
--- </pre>
---
---@return any
function Iter.last(self)
  if self.head and self.tail then
    local inc = self.head < self.tail and 1 or -1
    self.head = self.tail - inc
    return self:next()
  end

  local last = self:next()
  local cur = self:next()
  while cur do
    last = cur
    cur = self:next()
  end
  return last
end

--- Add an iterator stage that returns the current iterator count as well as the iterator value.
---
--- Example:
--- <pre>
---
--- > local it = vim.iter(vim.gsplit('abc', '')):enumerate()
--- > it:next()
--- 1	'a'
--- > it:next()
--- 2	'b'
--- > it:next()
--- 3	'c'
---
--- </pre>
---
---@return Iter
function Iter.enumerate(self)
  local i = 0
  return self:filter_map(function(...)
    i = i + 1
    return i, ...
  end)
end

--- Create a new Iter object from a table of value.
---
---@param src table|function Table or iterator to drain values from
---@return Iter
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
