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

--- Special case implementations for iterators on tables.
---@private
local TableIter = {}

TableIter.__index = setmetatable(TableIter, Iter)

TableIter.__call = function(self)
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

--- Add a filter/map step to the iterator.
---
--- Example:
--- <pre>lua
--- local it = vim.iter({ 1, 2, 3, 4 }):filter_map(function(v)
---   if v % 2 == 0 then
---     return v * 3
---   end
--- end)
--- it:collect()
--- -- { 6, 12 }
--- </pre>
---
---@param f function(...):any Mapping function. Takes all values returned from the previous stage
---                            in the pipeline as arguments and returns a new value. Nil values
---                            returned from `f` are filtered from the output.
---@return Iter
function Iter.filter_map(self, f)
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
function TableIter.filter_map(self, f)
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
--- |Iter:filter_map()|.
---
--- This function drains the iterator.
---
---@param f function(...) Function to execute for each item in the pipeline. Takes all of the
---                        values returned by the previous stage in the pipeline as arguments.
function Iter.foreach(self, f)
  while true do
    local args = pack(self:next())
    if args == nil then
      break
    end
    f(unpack(args))
  end
end

---@private
function TableIter.foreach(self, f)
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
---
--- local it1 = vim.iter(string.gmatch('100 20 50', '%d+')):filter_map(tonumber)
--- it1:collect()
--- -- { 100, 20, 50 }
---
--- local it2 = vim.iter(string.gmatch('100 20 50', '%d+')):filter_map(tonumber)
--- it2:collect({ sort = true })
--- -- { 20, 50, 100 }
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

  if self._table then
    local inc = self._head < self._tail and 1 or -1
    for i = self._head, self._tail - inc, inc do
      t[#t + 1] = self._table[i]
    end
  else
    while true do
      local args = pack(self:next())
      if args == nil then
        break
      end
      t[#t + 1] = args
    end
  end

  if opts and opts.sort then
    local f = type(opts.sort) == 'function' and opts.sort or nil
    table.sort(t, f)
  end

  return t
end

--- Return the next value from the iterator.
---
--- Example:
--- <pre>lua
---
--- local it = vim.iter(string.gmatch('1 2 3', '%d+')):filter_map(tonumber)
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
function TableIter.next(self)
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
function TableIter.rev(self)
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
function TableIter.peek(self)
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

function TableIter.rfind(self, f)
  if type(f) ~= 'function' then
    local val = f
    f = function(v)
      return v == val
    end
  end

  while true do
    local cur = pack(self:next_back())
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
--- it:next_back()
--- -- 4
--- it:next_back()
--- -- 3
--- </pre>
---
---@return any
function Iter.next_back(self) -- luacheck: no unused args
  error('Function iterators cannot read from the end')
end

function TableIter.next_back(self)
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
--- it:peek_back()
--- -- 4
--- it:peek_back()
--- -- 4
--- it:next_back()
--- -- 4
--- </pre>
---
---@return any
function Iter.peek_back(self) -- luacheck: no unused args
  error('Function iterators cannot read from the end')
end

function TableIter.peek_back(self)
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
function TableIter.skip(self, n)
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
--- local it = vim.iter({ 1, 2, 3, 4, 5 }):skip_back(2)
--- it:next()
--- -- 1
--- it:next_back()
--- -- 3
--- </pre>
---
---@param n number Number of values to skip.
---@return Iter
function Iter.skip_back(self, n) -- luacheck: no unused args
  error('Function iterators cannot skip from the end')
  return self
end

---@private
function TableIter.skip_back(self, n)
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
--- it:nth_back(2)
--- -- 9
--- it:nth_back(2)
--- -- 3
---
--- </pre>
---
---@param n number The index of the value to return.
---@return any
function Iter.nth_back(self, n)
  if n > 0 then
    return self:skip_back(n - 1):next_back()
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
function TableIter.last(self)
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
  return self:filter_map(function(...)
    i = i + 1
    return i, ...
  end)
end

---@private
function TableIter.enumerate(self)
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
function Iter.new(src)
  local it = {}
  if type(src) == 'table' then
    it._table = {}
    for i = 1, #src do
      it._table[i] = src[i]
    end
    it._head = 1
    it._tail = #src + 1
    setmetatable(it, TableIter)
  elseif type(src) == 'function' then
    function it.next()
      return src()
    end
    setmetatable(it, Iter)
  else
    error('src must be a table or function')
  end
  return it
end

return Iter
