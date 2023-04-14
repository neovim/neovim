--- Iterator implementation.

---@class Iter
---@field next function Return the next value in the iterator
---@field _table ?table Underlying table data (table iterators only)
---@field _head ?number Index to the front of a table iterator (table iterators only)
---@field _tail ?number Index to the end of a table iterator (table iterators only)
local Iter = {}
Iter.__index = Iter
Iter.__call = function(self)
  return self:next()
end

--- Special case implementations for iterators on list-like tables.
local ListIter = {}
ListIter.__index = setmetatable(ListIter, Iter)
ListIter.__call = function(self)
  return self:next()
end

--- Special case implementations for iterators on map-like tables.
local MapIter = {}
MapIter.__index = setmetatable(MapIter, Iter)
MapIter.__call = function(self)
  return self:next()
end

---@private
local function unpack(t)
  if type(t) == 'table' then
    return _G.unpack(t)
  end
  return t
end

---@private
local function pack(...)
  if select('#', ...) > 1 then
    return { ... }
  end
  return ...
end

--- Add a filter step to the iterator pipeline.
---
--- Example:
--- <pre>lua
--- local bufs = vim.iter(vim.api.nvim_list_bufs()):filter(vim.api.nvim_buf_is_loaded)
--- </pre>
---
---@param f function(...):bool Takes all values returned from the previous stage in the pipeline and
---                            returns false or nil if the current iterator element should be
---                            removed.
---@return Iter
function Iter.filter(self, f)
  local next = self.next
  self.next = function(this)
    while true do
      local args = pack(next(this))
      if args == nil then
        break
      end
      if f(unpack(args)) then
        return unpack(args)
      end
    end
  end
  return self
end

---@private
function ListIter.filter(self, f)
  local inc = self._head < self._tail and 1 or -1
  local n = self._head
  for i = self._head, self._tail - inc, inc do
    local v = self._table[i]
    if f(unpack(v)) then
      self._table[n] = v
      n = n + inc
    end
  end
  self._tail = n
  return self
end

--- Add a map and filter step to the iterator pipeline.
---
--- Example:
--- <pre>lua
--- local it = vim.iter({ 1, 2, 3, 4 }):filtermap(function(v)
---   if v % 2 == 0 then
---     return v * 3
---   end
--- end)
--- it:collect()
--- -- { 6, 12 }
--- </pre>
---
---@param f function(...):any Mapping function. Takes all values returned from the previous stage
---                            in the pipeline as arguments and returns one or more new values,
---                            which are used in the next pipeline stage. Nil return values returned
---                            are filtered from the output.
---@return Iter
function Iter.filtermap(self, f)
  local next = self.next
  self.next = function(this)
    while true do
      local args = pack(next(this))
      if args == nil then
        break
      end
      local result = pack(f(unpack(args)))
      if result ~= nil then
        return unpack(result)
      end
    end
  end
  return self
end

---@private
function ListIter.filtermap(self, f)
  local inc = self._head < self._tail and 1 or -1
  local n = self._head
  for i = self._head, self._tail - inc, inc do
    local v = pack(f(unpack(self._table[i])))
    if v ~= nil then
      self._table[n] = v
      n = n + inc
    end
  end
  self._tail = n
  return self
end

--- Call a function once for each item in the pipeline.
---
--- This is used for functions which have side effects. To modify the values in the iterator, use
--- |Iter:filtermap()|.
---
--- This function drains the iterator.
---
---@param f function(...) Function to execute for each item in the pipeline. Takes all of the
---                        values returned by the previous stage in the pipeline as arguments.
function Iter.each(self, f)
  while true do
    local args = pack(self:next())
    if args == nil then
      break
    end
    f(unpack(args))
  end
end

---@private
function ListIter.each(self, f)
  local inc = self._head < self._tail and 1 or -1
  for i = self._head, self._tail - inc, inc do
    f(unpack(self._table[i]))
  end
  self._head = self._tail
end

--- Drain the iterator into a table.
---
--- The final stage in the iterator pipeline must return 1 or 2 values. If only one value is
--- returned, or if two values are returned and the first value is a number, an "array-like" table
--- is returned. Otherwise, the first return value is used as the table key and the second return
--- value as the table value.
---
--- Example:
--- <pre>lua
--- local it1 = vim.iter(string.gmatch('100 20 50', '%d+')):filtermap(tonumber)
--- it1:collect()
--- -- { 100, 20, 50 }
---
--- local it2 = vim.iter(string.gmatch('100 20 50', '%d+')):filtermap(tonumber)
--- it2:collect({ sort = true })
--- -- { 20, 50, 100 }
--- </pre>
---
---@return table
function Iter.collect(self)
  local t = {}
  while true do
    local args = pack(self:next())
    if args == nil then
      break
    end
    t[#t + 1] = args
  end
  return t
end

---@private
function ListIter.collect(self, opts)
  -- Skip a table copy if possible
  if self._head == 1 and self._tail == #self._table + 1 then
    return self._table
  end

  local t = {}
  local inc = self._head < self._tail and 1 or -1
  for i = self._head, self._tail - inc, inc do
    t[#t + 1] = self._table[i]
  end
  return t
end

---@private
function MapIter.collect(self)
  local t = {}
  for k, v in self do
    t[k] = v
  end
  return t
end

--- Fold an iterator or table into a single value.
---
---@generic A
---
---@param init A Initial value of the accumulator.
---@param f function(acc:A, ...):A Accumulation function.
---@return A
function Iter.fold(self, init, f)
  local acc = init
  while true do
    local args = pack(self.next())
    if args == nil then
      break
    end
    acc = f(acc, unpack(args))
  end
  return acc
end

---@private
function ListIter.fold(self, init, f)
  local acc = init
  local inc = self._head < self._tail and 1 or -1
  for i = self._head, self._tail - inc, inc do
    acc = f(acc, unpack(self._table[i]))
  end
  return acc
end

--- Return the next value from the iterator.
---
--- Example:
--- <pre>lua
---
--- local it = vim.iter(string.gmatch('1 2 3', '%d+')):filtermap(tonumber)
--- it:next()
--- -- 1
--- it:next()
--- -- 2
--- it:next()
--- -- 3
---
--- </pre>
---
---@return any
function Iter.next(self) -- luacheck: no unused args
  -- This function is provided by the source iterator in Iter.new. This definition exists only for
  -- the docstring
end

---@private
function ListIter.next(self)
  if self._head ~= self._tail then
    local v = self._table[self._head]
    local inc = self._head < self._tail and 1 or -1
    self._head = self._head + inc
    return unpack(v)
  end
end

--- Reverse an iterator.
---
--- Only iterators on tables can be reversed.
---
--- Example:
--- <pre>lua
---
--- local it = vim.iter({ 3, 6, 9, 12 }):rev()
--- it:collect()
--- -- { 12, 9, 6, 3 }
---
--- </pre>
---
---@return Iter
function Iter.rev(self)
  error('Function iterators cannot be reversed')
  return self
end

---@private
function ListIter.rev(self)
  local inc = self._head < self._tail and 1 or -1
  self._head, self._tail = self._tail - inc, self._head - inc
  return self
end

--- Peek at the next value in the iterator without consuming it.
---
--- Only iterators on tables can be peeked.
---
--- Example:
--- <pre>lua
---
--- local it = vim.iter({ 3, 6, 9, 12 })
--- it:peek()
--- -- 3
--- it:peek()
--- -- 3
--- it:next()
--- -- 3
---
--- </pre>
---
---@return any
function Iter.peek(self) -- luacheck: no unused args
  error('Function iterators are not peekable')
end

---@private
function ListIter.peek(self)
  if self._head ~= self._tail then
    return self._table[self._head]
  end
end

--- Find the first value in the iterator that satisfies the given predicate.
---
--- Advances the iterator. Returns nil and drains the iterator if no value is found.
---
--- Examples:
--- <pre>lua
---
--- local it = vim.iter({ 3, 6, 9, 12 })
--- it:find(12)
--- -- 12
---
--- local it = vim.iter({ 3, 6, 9, 12 })
--- it:find(20)
--- -- nil
---
--- local it = vim.iter({ 3, 6, 9, 12 })
--- it:find(function(v) return v % 4 == 0 end)
--- -- 12
---
--- </pre>
---
---@return any
function Iter.find(self, f)
  if type(f) ~= 'function' then
    local val = f
    f = function(v)
      return v == val
    end
  end

  while true do
    local cur = pack(self:next())
    if cur == nil then
      break
    end

    if f(unpack(cur)) then
      return unpack(cur)
    end
  end
end

--- Find the first value in the iterator that satisfies the given predicate, starting from the end.
---
--- Advances the iterator. Returns nil and drains the iterator if no value is found.
---
--- Only supported for iterators on tables.
---
--- Examples:
--- <pre>lua
---
--- local it = vim.iter({ 1, 2, 3, 2, 1 }):enumerate()
--- it:rfind(1)
--- -- 5	1
--- it:rfind(1)
--- -- 1	1
---
--- </pre>
---
---@see Iter.find
---
---@return any
function Iter.rfind(self, f) -- luacheck: no unused args
  error('Function iterators cannot read from the end')
end

function ListIter.rfind(self, f)
  if type(f) ~= 'function' then
    local val = f
    f = function(v)
      return v == val
    end
  end

  while true do
    local cur = pack(self:nextback())
    if cur == nil then
      break
    end

    if f(unpack(cur)) then
      return unpack(cur)
    end
  end
end
--- Return the next value from the end of the iterator.
---
--- Only supported for iterators on tables.
---
--- Example:
--- <pre>lua
--- local it = vim.iter({1, 2, 3, 4})
--- it:nextback()
--- -- 4
--- it:nextback()
--- -- 3
--- </pre>
---
---@return any
function Iter.nextback(self) -- luacheck: no unused args
  error('Function iterators cannot read from the end')
end

function ListIter.nextback(self)
  if self._head ~= self._tail then
    local inc = self._head < self._tail and 1 or -1
    self._tail = self._tail - inc
    return self._table[self._tail]
  end
end

--- Return the next value from the end of the iterator without consuming it.
---
--- Only supported for iterators on tables.
---
--- Example:
--- <pre>lua
--- local it = vim.iter({1, 2, 3, 4})
--- it:peekback()
--- -- 4
--- it:peekback()
--- -- 4
--- it:nextback()
--- -- 4
--- </pre>
---
---@return any
function Iter.peekback(self) -- luacheck: no unused args
  error('Function iterators cannot read from the end')
end

function ListIter.peekback(self)
  if self._head ~= self._tail then
    local inc = self._head < self._tail and 1 or -1
    return self._table[self._tail - inc]
  end
end

--- Skip values in the iterator.
---
--- Example:
--- <pre>lua
---
--- local it = vim.iter({ 3, 6, 9, 12 }):skip(2)
--- it:next()
--- -- 9
---
--- </pre>
---
---@param n number Number of values to skip.
---@return Iter
function Iter.skip(self, n)
  for _ = 1, n do
    local _ = self:next()
  end
  return self
end

---@private
function ListIter.skip(self, n)
  local inc = self._head < self._tail and n or -n
  self._head = self._head + inc
  if (inc > 0 and self._head > self._tail) or (inc < 0 and self._head < self._tail) then
    self._head = self._tail
  end
  return self
end

--- Skip values in the iterator starting from the end.
---
--- Only supported for iterators on tables.
---
--- Example:
--- <pre>lua
--- local it = vim.iter({ 1, 2, 3, 4, 5 }):skipback(2)
--- it:next()
--- -- 1
--- it:nextback()
--- -- 3
--- </pre>
---
---@param n number Number of values to skip.
---@return Iter
function Iter.skipback(self, n) -- luacheck: no unused args
  error('Function iterators cannot skip from the end')
  return self
end

---@private
function ListIter.skipback(self, n)
  local inc = self._head < self._tail and n or -n
  self._tail = self._tail - inc
  if (inc > 0 and self._head > self._tail) or (inc < 0 and self._head < self._tail) then
    self._head = self._tail
  end
  return self
end

--- Return the nth value in the iterator.
---
--- This function advances the iterator.
---
--- Example:
--- <pre>lua
---
--- local it = vim.iter({ 3, 6, 9, 12 })
--- it:nth(2)
--- -- 6
--- it:nth(2)
--- -- 12
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

--- Return the nth value from the end of the iterator.
---
--- This function advances the iterator.
---
--- Only supported for iterators on tables.
---
--- Example:
--- <pre>lua
---
--- local it = vim.iter({ 3, 6, 9, 12 })
--- it:nthback(2)
--- -- 9
--- it:nthback(2)
--- -- 3
---
--- </pre>
---
---@param n number The index of the value to return.
---@return any
function Iter.nthback(self, n)
  if n > 0 then
    return self:skipback(n - 1):nextback()
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
    local args = pack(self:next())
    if args == nil then
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
    local args = pack(self:next())
    if args == nil then
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
--- <pre>lua
---
--- local it = vim.iter(vim.gsplit('abcdefg', ''))
--- it:last()
--- -- 'g'
---
--- local it = vim.iter({ 3, 6, 9, 12, 15 })
--- it:last()
--- -- 15
---
--- </pre>
---
---@return any
function Iter.last(self)
  local last = self:next()
  local cur = self:next()
  while cur do
    last = cur
    cur = self:next()
  end
  return last
end

---@private
function ListIter.last(self)
  local inc = self._head < self._tail and 1 or -1
  local v = self._table[self._tail - inc]
  self._head = self._tail
  return v
end

--- Add an iterator stage that returns the current iterator count as well as the iterator value.
---
--- Example:
--- <pre>lua
---
--- local it = vim.iter(vim.gsplit('abc', '')):enumerate()
--- it:next()
--- -- 1	'a'
--- it:next()
--- -- 2	'b'
--- it:next()
--- -- 3	'c'
---
--- </pre>
---
---@return Iter
function Iter.enumerate(self)
  local i = 0
  return self:filtermap(function(...)
    i = i + 1
    return i, ...
  end)
end

---@private
function ListIter.enumerate(self)
  local inc = self._head < self._tail and 1 or -1
  for i = self._head, self._tail - inc, inc do
    local v = self._table[i]
    self._table[i] = { i, v }
  end
  return self
end

--- Create a new Iter object from a table of value.
---
---@param src table|function Table or iterator to drain values from
---@return Iter
function Iter.new(src, ...)
  local it = {}
  if type(src) == 'table' then
    local t = {}

    -- Check if source table can be treated like a list (indices are consecutive integers
    -- starting from 1)
    local count = 0
    for _ in pairs(src) do
      count = count + 1
      local v = src[count]
      if v == nil then
        return MapIter.new(src)
      end
      t[count] = v
    end
    return ListIter.new(t)
  end

  if type(src) == 'function' then
    local s, var = ...
    function it.next()
      local vars = pack(src(s, var))
      if vars ~= nil then
        var = vars[1]
        return unpack(vars)
      end
    end
    setmetatable(it, Iter)
  else
    error('src must be a table or function')
  end
  return it
end

--- Create a new ListIter
---
---@param t table List-like table. Caller guarantees that this table is a valid list.
---@return Iter
---@private
function ListIter.new(t)
  local it = {}
  it._table = t
  it._head = 1
  it._tail = #t + 1
  setmetatable(it, ListIter)
  return it
end

--- Create a new MapIter
---
---@param t table Table to iterate over. For list-like tables, use ListIter.new instead.
---@return Iter
---@private
function MapIter.new(t)
  local it = {}

  local index = nil
  function it.next()
    local k, v = next(t, index)
    if k ~= nil then
      index = k
      return k, v
    end
  end

  setmetatable(it, MapIter)
  return it
end

return Iter
