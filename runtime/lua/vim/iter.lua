--- @brief
---
--- [vim.iter()]() is an interface for [iterable]s: it wraps a table or function argument into an
--- [Iter]() object with methods (such as [Iter:filter()] and [Iter:map()]) that transform the
--- underlying source data. These methods can be chained to create iterator "pipelines": the output
--- of each pipeline stage is input to the next stage. The first stage depends on the type passed to
--- `vim.iter()`:
---
--- - Lists or arrays (|lua-list|) yield only the value of each element.
---   - Holes (nil values) are allowed (but discarded).
---   - Use pairs() to treat array/list tables as dicts (preserve holes and non-contiguous integer
---     keys): `vim.iter(pairs(…))`.
---   - Use |Iter:enumerate()| to also pass the index to the next stage.
---     - Or initialize with ipairs(): `vim.iter(ipairs(…))`.
--- - Non-list tables (|lua-dict|) yield both the key and value of each element.
--- - Function |iterator|s yield all values returned by the underlying function.
--- - Tables with a |__call()| metamethod are treated as function iterators.
---
--- The iterator pipeline terminates when the underlying |iterable| is exhausted (for function
--- iterators this means it returned nil).
---
--- Note: `vim.iter()` scans table input to decide if it is a list or a dict; to avoid this cost you
--- can wrap the table with an iterator e.g. `vim.iter(ipairs({…}))`, but that precludes the use of
--- |list-iterator| operations such as |Iter:rev()|).
---
--- Examples:
---
--- ```lua
--- local it = vim.iter({ 1, 2, 3, 4, 5 })
--- it:map(function(v)
---   return v * 3
--- end)
--- it:rev()
--- it:skip(2)
--- it:totable()
--- -- { 9, 6, 3 }
---
--- -- ipairs() is a function iterator which returns both the index (i) and the value (v)
--- vim.iter(ipairs({ 1, 2, 3, 4, 5 })):map(function(i, v)
---   if i > 2 then return v end
--- end):totable()
--- -- { 3, 4, 5 }
---
--- local it = vim.iter(vim.gsplit('1,2,3,4,5', ','))
--- it:map(function(s) return tonumber(s) end)
--- for i, d in it:enumerate() do
---   print(string.format("Column %d is %d", i, d))
--- end
--- -- Column 1 is 1
--- -- Column 2 is 2
--- -- Column 3 is 3
--- -- Column 4 is 4
--- -- Column 5 is 5
---
--- vim.iter({ a = 1, b = 2, c = 3, z = 26 }):any(function(k, v)
---   return k == 'z'
--- end)
--- -- true
---
--- local rb = vim.ringbuf(3)
--- rb:push("a")
--- rb:push("b")
--- vim.iter(rb):totable()
--- -- { "a", "b" }
--- ```

--- LuaLS is bad at generics which this module mostly deals with
--- @diagnostic disable:no-unknown

---@nodoc
---@class IterMod
---@operator call:Iter

local M = {}

---@nodoc
---@class Iter
local Iter = {}
Iter.__index = Iter
Iter.__call = function(self)
  return self:next()
end

--- Special case implementations for iterators on list tables.
---@nodoc
---@class ArrayIter : Iter
---@field _table table Underlying table data
---@field _head number Index to the front of a table iterator
---@field _tail number Index to the end of a table iterator (exclusive)
local ArrayIter = {}
ArrayIter.__index = setmetatable(ArrayIter, Iter)
ArrayIter.__call = function(self)
  return self:next()
end

--- Packed tables use this as their metatable
local packedmt = {}

local function unpack(t)
  if type(t) == 'table' and getmetatable(t) == packedmt then
    return _G.unpack(t, 1, t.n)
  end
  return t
end

local function pack(...)
  local n = select('#', ...)
  if n > 1 then
    return setmetatable({ n = n, ... }, packedmt)
  end
  return ...
end

local function sanitize(t)
  if type(t) == 'table' and getmetatable(t) == packedmt then
    -- Remove length tag and metatable
    t.n = nil
    setmetatable(t, nil)
  end
  return t
end

--- Flattens a single array-like table. Errors if it attempts to flatten a
--- dict-like table
---@param t table table which should be flattened
---@param max_depth number depth to which the table should be flattened
---@param depth number current iteration depth
---@param result table output table that contains flattened result
---@return table|nil flattened table if it can be flattened, otherwise nil
local function flatten(t, max_depth, depth, result)
  if depth < max_depth and type(t) == 'table' then
    for k, v in pairs(t) do
      if type(k) ~= 'number' or k <= 0 or math.floor(k) ~= k then
        -- short-circuit: this is not a list like table
        return nil
      end

      if flatten(v, max_depth, depth + 1, result) == nil then
        return nil
      end
    end
  elseif t ~= nil then
    result[#result + 1] = t
  end

  return result
end

--- Determine if the current iterator stage should continue.
---
--- If any arguments are passed to this function, then return those arguments
--- and stop the current iterator stage. Otherwise, return true to signal that
--- the current stage should continue.
---
---@param ... any Function arguments.
---@return boolean True if the iterator stage should continue, false otherwise
---@return any Function arguments.
local function continue(...)
  if select(1, ...) ~= nil then
    return false, ...
  end
  return true
end

--- If no input arguments are given return false, indicating the current
--- iterator stage should stop. Otherwise, apply the arguments to the function
--- f. If that function returns no values, the current iterator stage continues.
--- Otherwise, those values are returned.
---
---@param f function Function to call with the given arguments
---@param ... any Arguments to apply to f
---@return boolean True if the iterator pipeline should continue, false otherwise
---@return any Return values of f
local function apply(f, ...)
  if select(1, ...) ~= nil then
    return continue(f(...))
  end
  return false
end

--- Filters an iterator pipeline.
---
--- Example:
---
--- ```lua
--- local bufs = vim.iter(vim.api.nvim_list_bufs()):filter(vim.api.nvim_buf_is_loaded)
--- ```
---
---@param f fun(...):boolean Takes all values returned from the previous stage
---                       in the pipeline and returns false or nil if the
---                       current iterator element should be removed.
---@return Iter
function Iter:filter(f)
  return self:map(function(...)
    if f(...) then
      return ...
    end
  end)
end

---@private
function ArrayIter:filter(f)
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

--- Flattens a |list-iterator|, un-nesting nested values up to the given {depth}.
--- Errors if it attempts to flatten a dict-like value.
---
--- Examples:
---
--- ```lua
--- vim.iter({ 1, { 2 }, { { 3 } } }):flatten():totable()
--- -- { 1, 2, { 3 } }
---
--- vim.iter({1, { { a = 2 } }, { 3 } }):flatten():totable()
--- -- { 1, { a = 2 }, 3 }
---
--- vim.iter({ 1, { { a = 2 } }, { 3 } }):flatten(math.huge):totable()
--- -- error: attempt to flatten a dict-like table
--- ```
---
---@param depth? number Depth to which |list-iterator| should be flattened
---                        (defaults to 1)
---@return Iter
---@diagnostic disable-next-line:unused-local
function Iter:flatten(depth) -- luacheck: no unused args
  error('flatten() requires an array-like table')
end

---@private
function ArrayIter:flatten(depth)
  depth = depth or 1
  local inc = self._head < self._tail and 1 or -1
  local target = {}

  for i = self._head, self._tail - inc, inc do
    local flattened = flatten(self._table[i], depth, 0, {})

    -- exit early if we try to flatten a dict-like table
    if flattened == nil then
      error('flatten() requires an array-like table')
    end

    for _, v in pairs(flattened) do
      target[#target + 1] = v
    end
  end

  self._head = 1
  self._tail = #target + 1
  self._table = target
  return self
end

--- Maps the items of an iterator pipeline to the values returned by `f`.
---
--- If the map function returns nil, the value is filtered from the iterator.
---
--- Example:
---
--- ```lua
--- local it = vim.iter({ 1, 2, 3, 4 }):map(function(v)
---   if v % 2 == 0 then
---     return v * 3
---   end
--- end)
--- it:totable()
--- -- { 6, 12 }
--- ```
---
---@param f fun(...):...:any Mapping function. Takes all values returned from
---                      the previous stage in the pipeline as arguments
---                      and returns one or more new values, which are used
---                      in the next pipeline stage. Nil return values
---                      are filtered from the output.
---@return Iter
function Iter:map(f)
  -- Implementation note: the reader may be forgiven for observing that this
  -- function appears excessively convoluted. The problem to solve is that each
  -- stage of the iterator pipeline can return any number of values, and the
  -- number of values could even change per iteration. And the return values
  -- must be checked to determine if the pipeline has ended, so we cannot
  -- naively forward them along to the next stage.
  --
  -- A simple approach is to pack all of the return values into a table, check
  -- for nil, then unpack the table for the next stage. However, packing and
  -- unpacking tables is quite slow. There is no other way in Lua to handle an
  -- unknown number of function return values than to simply forward those
  -- values along to another function. Hence the intricate function passing you
  -- see here.

  local next = self.next

  --- Drain values from the upstream iterator source until a value can be
  --- returned.
  ---
  --- This is a recursive function. The base case is when the first argument is
  --- false, which indicates that the rest of the arguments should be returned
  --- as the values for the current iteration stage.
  ---
  ---@param cont boolean If true, the current iterator stage should continue to
  ---                    pull values from its upstream pipeline stage.
  ---                    Otherwise, this stage is complete and returns the
  ---                    values passed.
  ---@param ... any Values to return if cont is false.
  ---@return any
  local function fn(cont, ...)
    if cont then
      return fn(apply(f, next(self)))
    end
    return ...
  end

  self.next = function()
    return fn(apply(f, next(self)))
  end
  return self
end

---@private
function ArrayIter:map(f)
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

--- Calls a function once for each item in the pipeline, draining the iterator.
---
--- For functions with side effects. To modify the values in the iterator, use |Iter:map()|.
---
---@param f fun(...) Function to execute for each item in the pipeline.
---                  Takes all of the values returned by the previous stage
---                  in the pipeline as arguments.
function Iter:each(f)
  local function fn(...)
    if select(1, ...) ~= nil then
      f(...)
      return true
    end
  end
  while fn(self:next()) do
  end
end

---@private
function ArrayIter:each(f)
  local inc = self._head < self._tail and 1 or -1
  for i = self._head, self._tail - inc, inc do
    f(unpack(self._table[i]))
  end
  self._head = self._tail
end

--- Collect the iterator into a table.
---
--- The resulting table depends on the initial source in the iterator pipeline.
--- Array-like tables and function iterators will be collected into an array-like
--- table. If multiple values are returned from the final stage in the iterator
--- pipeline, each value will be included in a table.
---
--- Examples:
---
--- ```lua
--- vim.iter(string.gmatch('100 20 50', '%d+')):map(tonumber):totable()
--- -- { 100, 20, 50 }
---
--- vim.iter({ 1, 2, 3 }):map(function(v) return v, 2 * v end):totable()
--- -- { { 1, 2 }, { 2, 4 }, { 3, 6 } }
---
--- vim.iter({ a = 1, b = 2, c = 3 }):filter(function(k, v) return v % 2 ~= 0 end):totable()
--- -- { { 'a', 1 }, { 'c', 3 } }
--- ```
---
--- The generated table is an array-like table with consecutive, numeric indices.
--- To create a map-like table with arbitrary keys, use |Iter:fold()|.
---
---
---@return table
function Iter:totable()
  local t = {}

  while true do
    local args = pack(self:next())
    if args == nil then
      break
    end

    t[#t + 1] = sanitize(args)
  end
  return t
end

---@private
function ArrayIter:totable()
  if self.next ~= ArrayIter.next or self._head >= self._tail then
    return Iter.totable(self)
  end

  local needs_sanitize = getmetatable(self._table[self._head]) == packedmt

  -- Reindex and sanitize.
  local len = self._tail - self._head

  if needs_sanitize then
    for i = 1, len do
      self._table[i] = sanitize(self._table[self._head - 1 + i])
    end
  else
    for i = 1, len do
      self._table[i] = self._table[self._head - 1 + i]
    end
  end

  for i = len + 1, table.maxn(self._table) do
    self._table[i] = nil
  end

  self._head = 1
  self._tail = len + 1

  return self._table
end

--- Collect the iterator into a delimited string.
---
--- Each element in the iterator is joined into a string separated by {delim}.
---
--- Consumes the iterator.
---
--- @param delim string Delimiter
--- @return string
function Iter:join(delim)
  return table.concat(self:totable(), delim)
end

--- Folds ("reduces") an iterator into a single value. [Iter:reduce()]()
---
--- Examples:
---
--- ```lua
--- -- Create a new table with only even values
--- vim.iter({ a = 1, b = 2, c = 3, d = 4 })
---   :filter(function(k, v) return v % 2 == 0 end)
---   :fold({}, function(acc, k, v)
---     acc[k] = v
---     return acc
---   end) --> { b = 2, d = 4 }
---
--- -- Get the "maximum" item of an iterable.
--- vim.iter({ -99, -4, 3, 42, 0, 0, 7 })
---   :fold({}, function(acc, v)
---     acc.max = math.max(v, acc.max or v)
---     return acc
---   end) --> { max = 42 }
--- ```
---
---@generic A
---
---@param init A Initial value of the accumulator.
---@param f fun(acc:A, ...):A Accumulation function.
---@return A
function Iter:fold(init, f)
  local acc = init

  --- Use a closure to handle var args returned from iterator
  local function fn(...)
    if select(1, ...) ~= nil then
      acc = f(acc, ...)
      return true
    end
  end

  while fn(self:next()) do
  end
  return acc
end

---@private
function ArrayIter:fold(init, f)
  local acc = init
  local inc = self._head < self._tail and 1 or -1
  for i = self._head, self._tail - inc, inc do
    acc = f(acc, unpack(self._table[i]))
  end
  return acc
end

--- Gets the next value from the iterator.
---
--- Example:
---
--- ```lua
---
--- local it = vim.iter(string.gmatch('1 2 3', '%d+')):map(tonumber)
--- it:next()
--- -- 1
--- it:next()
--- -- 2
--- it:next()
--- -- 3
---
--- ```
---
---@return any
function Iter:next()
  -- This function is provided by the source iterator in Iter.new. This definition exists only for
  -- the docstring
end

---@private
function ArrayIter:next()
  if self._head ~= self._tail then
    local v = self._table[self._head]
    local inc = self._head < self._tail and 1 or -1
    self._head = self._head + inc
    return unpack(v)
  end
end

--- Reverses a |list-iterator| pipeline.
---
--- Example:
---
--- ```lua
---
--- local it = vim.iter({ 3, 6, 9, 12 }):rev()
--- it:totable()
--- -- { 12, 9, 6, 3 }
---
--- ```
---
---@return Iter
function Iter:rev()
  error('rev() requires an array-like table')
end

---@private
function ArrayIter:rev()
  local inc = self._head < self._tail and 1 or -1
  self._head, self._tail = self._tail - inc, self._head - inc
  return self
end

--- Gets the next value in a |list-iterator| without consuming it.
---
--- Example:
---
--- ```lua
---
--- local it = vim.iter({ 3, 6, 9, 12 })
--- it:peek()
--- -- 3
--- it:peek()
--- -- 3
--- it:next()
--- -- 3
---
--- ```
---
---@return any
function Iter:peek()
  error('peek() requires an array-like table')
end

---@private
function ArrayIter:peek()
  if self._head ~= self._tail then
    return self._table[self._head]
  end
end

--- Find the first value in the iterator that satisfies the given predicate.
---
--- Advances the iterator. Returns nil and drains the iterator if no value is found.
---
--- Examples:
---
--- ```lua
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
--- ```
---@param f any
---@return any
function Iter:find(f)
  if type(f) ~= 'function' then
    local val = f
    f = function(v)
      return v == val
    end
  end

  local result = nil

  --- Use a closure to handle var args returned from iterator
  local function fn(...)
    if select(1, ...) ~= nil then
      if f(...) then
        result = pack(...)
      else
        return true
      end
    end
  end

  while fn(self:next()) do
  end
  return unpack(result)
end

--- Gets the first value satisfying a predicate, from the end of a |list-iterator|.
---
--- Advances the iterator. Returns nil and drains the iterator if no value is found.
---
--- Examples:
---
--- ```lua
---
--- local it = vim.iter({ 1, 2, 3, 2, 1 }):enumerate()
--- it:rfind(1)
--- -- 5	1
--- it:rfind(1)
--- -- 1	1
---
--- ```
---
---@see Iter.find
---
---@param f any
---@return any
---@diagnostic disable-next-line: unused-local
function Iter:rfind(f) -- luacheck: no unused args
  error('rfind() requires an array-like table')
end

---@private
function ArrayIter:rfind(f)
  if type(f) ~= 'function' then
    local val = f
    f = function(v)
      return v == val
    end
  end

  local inc = self._head < self._tail and 1 or -1
  for i = self._tail - inc, self._head, -inc do
    local v = self._table[i]
    if f(unpack(v)) then
      self._tail = i
      return unpack(v)
    end
  end
  self._head = self._tail
end

--- Transforms an iterator to yield only the first n values.
---
--- Example:
---
--- ```lua
--- local it = vim.iter({ 1, 2, 3, 4 }):take(2)
--- it:next()
--- -- 1
--- it:next()
--- -- 2
--- it:next()
--- -- nil
--- ```
---
---@param n integer
---@return Iter
function Iter:take(n)
  local next = self.next
  local i = 0
  self.next = function()
    if i < n then
      i = i + 1
      return next(self)
    end
  end
  return self
end

---@private
function ArrayIter:take(n)
  local inc = self._head < self._tail and n or -n
  local cmp = self._head < self._tail and math.min or math.max
  self._tail = cmp(self._tail, self._head + inc)
  return self
end

--- "Pops" a value from a |list-iterator| (gets the last value and decrements the tail).
---
--- Example:
---
--- ```lua
--- local it = vim.iter({1, 2, 3, 4})
--- it:pop()
--- -- 4
--- it:pop()
--- -- 3
--- ```
---
---@return any
function Iter:pop()
  error('pop() requires an array-like table')
end

--- @nodoc
function ArrayIter:pop()
  if self._head ~= self._tail then
    local inc = self._head < self._tail and 1 or -1
    self._tail = self._tail - inc
    return self._table[self._tail]
  end
end

--- Gets the last value of a |list-iterator| without consuming it.
---
--- Example:
---
--- ```lua
--- local it = vim.iter({1, 2, 3, 4})
--- it:rpeek()
--- -- 4
--- it:rpeek()
--- -- 4
--- it:pop()
--- -- 4
--- ```
---
---@see Iter.last
---
---@return any
function Iter:rpeek()
  error('rpeek() requires an array-like table')
end

---@nodoc
function ArrayIter:rpeek()
  if self._head ~= self._tail then
    local inc = self._head < self._tail and 1 or -1
    return self._table[self._tail - inc]
  end
end

--- Skips `n` values of an iterator pipeline.
---
--- Example:
---
--- ```lua
---
--- local it = vim.iter({ 3, 6, 9, 12 }):skip(2)
--- it:next()
--- -- 9
---
--- ```
---
---@param n number Number of values to skip.
---@return Iter
function Iter:skip(n)
  for _ = 1, n do
    local _ = self:next()
  end
  return self
end

---@private
function ArrayIter:skip(n)
  local inc = self._head < self._tail and n or -n
  self._head = self._head + inc
  if (inc > 0 and self._head > self._tail) or (inc < 0 and self._head < self._tail) then
    self._head = self._tail
  end
  return self
end

--- Discards `n` values from the end of a |list-iterator| pipeline.
---
--- Example:
---
--- ```lua
--- local it = vim.iter({ 1, 2, 3, 4, 5 }):rskip(2)
--- it:next()
--- -- 1
--- it:pop()
--- -- 3
--- ```
---
---@param n number Number of values to skip.
---@return Iter
---@diagnostic disable-next-line: unused-local
function Iter:rskip(n) -- luacheck: no unused args
  error('rskip() requires an array-like table')
end

---@private
function ArrayIter:rskip(n)
  local inc = self._head < self._tail and n or -n
  self._tail = self._tail - inc
  if (inc > 0 and self._head > self._tail) or (inc < 0 and self._head < self._tail) then
    self._head = self._tail
  end
  return self
end

--- Gets the nth value of an iterator (and advances to it).
---
--- If `n` is negative, offsets from the end of a |list-iterator|.
---
--- Example:
---
--- ```lua
--- local it = vim.iter({ 3, 6, 9, 12 })
--- it:nth(2)
--- -- 6
--- it:nth(2)
--- -- 12
---
--- local it2 = vim.iter({ 3, 6, 9, 12 })
--- it2:nth(-2)
--- -- 9
--- it2:nth(-2)
--- -- 3
--- ```
---
---@param n number Index of the value to return. May be negative if the source is a |list-iterator|.
---@return any
function Iter:nth(n)
  if n > 0 then
    return self:skip(n - 1):next()
  elseif n < 0 then
    return self:rskip(math.abs(n) - 1):pop()
  end
end

--- Sets the start and end of a |list-iterator| pipeline.
---
--- Equivalent to `:skip(first - 1):rskip(len - last + 1)`.
---
---@param first number
---@param last number
---@return Iter
---@diagnostic disable-next-line: unused-local
function Iter:slice(first, last) -- luacheck: no unused args
  error('slice() requires an array-like table')
end

---@private
function ArrayIter:slice(first, last)
  return self:skip(math.max(0, first - 1)):rskip(math.max(0, self._tail - last - 1))
end

--- Returns true if any of the items in the iterator match the given predicate.
---
---@param pred fun(...):boolean Predicate function. Takes all values returned from the previous
---                          stage in the pipeline as arguments and returns true if the
---                          predicate matches.
function Iter:any(pred)
  local any = false

  --- Use a closure to handle var args returned from iterator
  local function fn(...)
    if select(1, ...) ~= nil then
      if pred(...) then
        any = true
      else
        return true
      end
    end
  end

  while fn(self:next()) do
  end
  return any
end

--- Returns true if all items in the iterator match the given predicate.
---
---@param pred fun(...):boolean Predicate function. Takes all values returned from the previous
---                          stage in the pipeline as arguments and returns true if the
---                          predicate matches.
function Iter:all(pred)
  local all = true

  local function fn(...)
    if select(1, ...) ~= nil then
      if not pred(...) then
        all = false
      else
        return true
      end
    end
  end

  while fn(self:next()) do
  end
  return all
end

--- Drains the iterator and returns the last item.
---
--- Example:
---
--- ```lua
---
--- local it = vim.iter(vim.gsplit('abcdefg', ''))
--- it:last()
--- -- 'g'
---
--- local it = vim.iter({ 3, 6, 9, 12, 15 })
--- it:last()
--- -- 15
---
--- ```
---
---@see Iter.rpeek
---
---@return any
function Iter:last()
  local last = self:next()
  local cur = self:next()
  while cur do
    last = cur
    cur = self:next()
  end
  return last
end

---@private
function ArrayIter:last()
  local inc = self._head < self._tail and 1 or -1
  local v = self._table[self._tail - inc]
  self._head = self._tail
  return v
end

--- Yields the item index (count) and value for each item of an iterator pipeline.
---
--- For list tables, this is more efficient:
---
--- ```lua
--- vim.iter(ipairs(t))
--- ```
---
--- instead of:
---
--- ```lua
--- vim.iter(t):enumerate()
--- ```
---
--- Example:
---
--- ```lua
---
--- local it = vim.iter(vim.gsplit('abc', '')):enumerate()
--- it:next()
--- -- 1	'a'
--- it:next()
--- -- 2	'b'
--- it:next()
--- -- 3	'c'
---
--- ```
---
---@return Iter
function Iter:enumerate()
  local i = 0
  return self:map(function(...)
    i = i + 1
    return i, ...
  end)
end

---@private
function ArrayIter:enumerate()
  local inc = self._head < self._tail and 1 or -1
  for i = self._head, self._tail - inc, inc do
    local v = self._table[i]
    self._table[i] = pack(i, v)
  end
  return self
end

--- Creates a new Iter object from a table or other |iterable|.
---
---@param src table|function Table or iterator to drain values from
---@return Iter
---@private
function Iter.new(src, ...)
  local it = {}
  if type(src) == 'table' then
    local mt = getmetatable(src)
    if mt and type(mt.__call) == 'function' then
      ---@private
      function it.next()
        return src()
      end

      setmetatable(it, Iter)
      return it
    end

    local t = {}

    -- O(n): scan the source table to decide if it is an array (only positive integer indices).
    for k, v in pairs(src) do
      if type(k) ~= 'number' or k <= 0 or math.floor(k) ~= k then
        return Iter.new(pairs(src))
      end
      t[#t + 1] = v -- Coerce to list-like table.
    end
    return ArrayIter.new(t)
  end

  if type(src) == 'function' then
    local s, var = ...

    --- Use a closure to handle var args returned from iterator
    local function fn(...)
      -- Per the Lua 5.1 reference manual, an iterator is complete when the first returned value is
      -- nil (even if there are other, non-nil return values). See |for-in|.
      if select(1, ...) ~= nil then
        var = select(1, ...)
        return ...
      end
    end

    ---@private
    function it.next()
      return fn(src(s, var))
    end

    setmetatable(it, Iter)
  else
    error('src must be a table or function')
  end
  return it
end

--- Create a new ArrayIter
---
---@param t table Array-like table. Caller guarantees that this table is a valid array. Can have
---               holes (nil values).
---@return Iter
---@private
function ArrayIter.new(t)
  local it = {}
  it._table = t
  it._head = 1
  it._tail = #t + 1
  setmetatable(it, ArrayIter)
  return it
end

return setmetatable(M, {
  __call = function(_, ...)
    return Iter.new(...)
  end,
}) --[[@as IterMod]]
