-- Functions shared by Nvim and its test-suite.
--
-- These are "pure" lua functions not depending of the state of the editor.
-- Thus they should always be available whenever nvim-related lua code is run,
-- regardless if it is code in the editor itself, or in worker threads/processes,
-- or the test suite. (Eventually the test suite will be run in a worker process,
-- so this wouldn't be a separate case to consider)

---@nodoc
_G.vim = _G.vim or {} --[[@as table]]
-- TODO(lewis6991): better fix for flaky luals

---@generic T
---@param orig T
---@param cache? table<any,any>
---@return T
local function deepcopy(orig, cache)
  if orig == vim.NIL then
    return vim.NIL
  elseif type(orig) == 'userdata' or type(orig) == 'thread' then
    error('Cannot deepcopy object of type ' .. type(orig))
  elseif type(orig) ~= 'table' then
    return orig
  end

  --- @cast orig table<any,any>

  if cache and cache[orig] then
    return cache[orig]
  end

  local copy = {} --- @type table<any,any>

  if cache then
    cache[orig] = copy
  end

  for k, v in pairs(orig) do
    copy[deepcopy(k, cache)] = deepcopy(v, cache)
  end

  return setmetatable(copy, getmetatable(orig))
end

--- Returns a deep copy of the given object. Non-table objects are copied as
--- in a typical Lua assignment, whereas table objects are copied recursively.
--- Functions are naively copied, so functions in the copied table point to the
--- same functions as those in the input table. Userdata and threads are not
--- copied and will throw an error.
---
--- Note: `noref=true` is much more performant on tables with unique table
--- fields, while `noref=false` is more performant on tables that reuse table
--- fields.
---
---@generic T: table
---@param orig T Table to copy
---@param noref? boolean
--- When `false` (default) a contained table is only copied once and all
--- references point to this single copy. When `true` every occurrence of a
--- table results in a new copy. This also means that a cyclic reference can
--- cause `deepcopy()` to fail.
---@return T Table of copied keys and (nested) values.
function vim.deepcopy(orig, noref)
  return deepcopy(orig, not noref and {} or nil)
end

--- @class vim.gsplit.Opts
--- @inlinedoc
---
--- Use `sep` literally (as in string.find).
--- @field plain? boolean
---
--- Discard empty segments at start and end of the sequence.
--- @field trimempty? boolean

--- Gets an |iterator| that splits a string at each instance of a separator, in "lazy" fashion
--- (as opposed to |vim.split()| which is "eager").
---
--- Example:
---
--- ```lua
--- for s in vim.gsplit(':aa::b:', ':', {plain=true}) do
---   print(s)
--- end
--- ```
---
--- If you want to also inspect the separator itself (instead of discarding it), use
--- |string.gmatch()|. Example:
---
--- ```lua
--- for word, num in ('foo111bar222'):gmatch('([^0-9]*)(%d*)') do
---   print(('word: %s num: %s'):format(word, num))
--- end
--- ```
---
--- @see |string.gmatch()|
--- @see |vim.split()|
--- @see |lua-pattern|s
--- @see https://www.lua.org/pil/20.2.html
--- @see http://lua-users.org/wiki/StringLibraryTutorial
---
--- @param s string String to split
--- @param sep string Separator or pattern
--- @param opts? vim.gsplit.Opts Keyword arguments |kwargs|:
--- @return fun():string? : Iterator over the split components
function vim.gsplit(s, sep, opts)
  local plain --- @type boolean?
  local trimempty = false --- @type boolean?
  if type(opts) == 'boolean' then
    plain = opts -- For backwards compatibility.
  else
    vim.validate('s', s, 'string')
    vim.validate('sep', sep, 'string')
    vim.validate('opts', opts, 'table', true)
    opts = opts or {}
    plain, trimempty = opts.plain, opts.trimempty
  end

  local start = 1
  local done = false

  -- For `trimempty`: queue of collected segments, to be emitted at next pass.
  local segs = {}
  local empty_start = true -- Only empty segments seen so far.

  --- @param i integer?
  --- @param j integer
  --- @param ... unknown
  --- @return string
  --- @return ...
  local function _pass(i, j, ...)
    if i then
      assert(j + 1 > start, 'Infinite loop detected')
      local seg = s:sub(start, i - 1)
      start = j + 1
      return seg, ...
    else
      done = true
      return s:sub(start)
    end
  end

  return function()
    if trimempty and #segs > 0 then
      -- trimempty: Pop the collected segments.
      return table.remove(segs)
    elseif done or (s == '' and sep == '') then
      return nil
    elseif sep == '' then
      if start == #s then
        done = true
      end
      return _pass(start + 1, start)
    end

    local seg = _pass(s:find(sep, start, plain))

    -- Trim empty segments from start/end.
    if trimempty and seg ~= '' then
      empty_start = false
    elseif trimempty and seg == '' then
      while not done and seg == '' do
        table.insert(segs, 1, '')
        seg = _pass(s:find(sep, start, plain))
      end
      if done and seg == '' then
        return nil
      elseif empty_start then
        empty_start = false
        segs = {}
        return seg
      end
      if seg ~= '' then
        table.insert(segs, 1, seg)
      end
      return table.remove(segs)
    end

    return seg
  end
end

--- Splits a string at each instance of a separator and returns the result as a table (unlike
--- |vim.gsplit()|).
---
--- Examples:
---
--- ```lua
--- split(":aa::b:", ":")                   --> {'','aa','','b',''}
--- split("axaby", "ab?")                   --> {'','x','y'}
--- split("x*yz*o", "*", {plain=true})      --> {'x','yz','o'}
--- split("|x|y|z|", "|", {trimempty=true}) --> {'x', 'y', 'z'}
--- ```
---
---@see |vim.gsplit()|
---@see |string.gmatch()|
---
---@param s string String to split
---@param sep string Separator or pattern
---@param opts? vim.gsplit.Opts Keyword arguments |kwargs|:
---@return string[] : List of split components
function vim.split(s, sep, opts)
  local t = {}
  for c in vim.gsplit(s, sep, opts) do
    table.insert(t, c)
  end
  return t
end

--- Return a list of all keys used in a table.
--- However, the order of the return table of keys is not guaranteed.
---
---@see From https://github.com/premake/premake-core/blob/master/src/base/table.lua
---
---@generic T
---@param t table<T, any> (table) Table
---@return T[] : List of keys
function vim.tbl_keys(t)
  vim.validate('t', t, 'table')
  --- @cast t table<any,any>

  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end

--- Return a list of all values used in a table.
--- However, the order of the return table of values is not guaranteed.
---
---@generic T
---@param t table<any, T> (table) Table
---@return T[] : List of values
function vim.tbl_values(t)
  vim.validate('t', t, 'table')

  local values = {}
  for _, v in
    pairs(t --[[@as table<any,any>]])
  do
    table.insert(values, v)
  end
  return values
end

--- Applies function `fn` to all values of table `t`, in `pairs()` iteration order (which is not
--- guaranteed to be stable, even when the data doesn't change).
---
---@generic T
---@param fn fun(value: T): any Function
---@param t table<any, T> Table
---@return table : Table of transformed values
function vim.tbl_map(fn, t)
  vim.validate('fn', fn, 'callable')
  vim.validate('t', t, 'table')
  --- @cast t table<any,any>

  local rettab = {} --- @type table<any,any>
  for k, v in pairs(t) do
    rettab[k] = fn(v)
  end
  return rettab
end

--- Filter a table using a predicate function
---
---@generic T
---@param fn fun(value: T): boolean (function) Function
---@param t table<any, T> (table) Table
---@return T[] : Table of filtered values
function vim.tbl_filter(fn, t)
  vim.validate('fn', fn, 'callable')
  vim.validate('t', t, 'table')
  --- @cast t table<any,any>

  local rettab = {} --- @type table<any,any>
  for _, entry in pairs(t) do
    if fn(entry) then
      rettab[#rettab + 1] = entry
    end
  end
  return rettab
end

--- @class vim.tbl_contains.Opts
--- @inlinedoc
---
--- `value` is a function reference to be checked (default false)
--- @field predicate? boolean

--- Checks if a table contains a given value, specified either directly or via
--- a predicate that is checked for each value.
---
--- Example:
---
--- ```lua
--- vim.tbl_contains({ 'a', { 'b', 'c' } }, function(v)
---   return vim.deep_equal(v, { 'b', 'c' })
--- end, { predicate = true })
--- -- true
--- ```
---
---@see |vim.list_contains()| for checking values in list-like tables
---
---@param t table Table to check
---@param value any Value to compare or predicate function reference
---@param opts? vim.tbl_contains.Opts Keyword arguments |kwargs|:
---@return boolean `true` if `t` contains `value`
function vim.tbl_contains(t, value, opts)
  vim.validate('t', t, 'table')
  vim.validate('opts', opts, 'table', true)
  --- @cast t table<any,any>

  local pred --- @type fun(v: any): boolean?
  if opts and opts.predicate then
    vim.validate('value', value, 'callable')
    pred = value
  else
    pred = function(v)
      return v == value
    end
  end

  for _, v in pairs(t) do
    if pred(v) then
      return true
    end
  end
  return false
end

--- Checks if a list-like table (integer keys without gaps) contains `value`.
---
---@see |vim.tbl_contains()| for checking values in general tables
---
---@param t table Table to check (must be list-like, not validated)
---@param value any Value to compare
---@return boolean `true` if `t` contains `value`
function vim.list_contains(t, value)
  vim.validate('t', t, 'table')
  --- @cast t table<any,any>

  for _, v in ipairs(t) do
    if v == value then
      return true
    end
  end
  return false
end

vim.list = {}

---TODO(ofseed): memoize, string value support, type alias.
---@generic T
---@param v T
---@param key? fun(v: T): any
---@return any
local function key_fn(v, key)
  return key and key(v) or v
end

--- Removes duplicate values from a |lua-list| in-place.
---
--- Only the first occurrence of each value is kept.
--- The operation is performed in-place and the input table is modified.
---
--- Accepts an optional `key` argument, which if provided is called for each
--- value in the list to compute a hash key for uniqueness comparison.
--- This is useful for deduplicating table values or complex objects.
--- If `key` returns `nil` for a value, that value will be considered unique,
--- even if multiple values return `nil`.
---
--- Example:
--- ```lua
---
--- local t = {1, 2, 2, 3, 1}
--- vim.list.unique(t)
--- -- t is now {1, 2, 3}
---
--- local t = { {id=1}, {id=2}, {id=1} }
--- vim.list.unique(t, function(x) return x.id end)
--- -- t is now { {id=1}, {id=2} }
--- ```
---
--- @since 14
--- @generic T
--- @param t T[]
--- @param key? fun(x: T): any Optional hash function to determine uniqueness of values
--- @return T[] : The deduplicated list
--- @see |Iter:unique()|
function vim.list.unique(t, key)
  vim.validate('t', t, 'table')
  local seen = {} --- @type table<any,boolean>

  local finish = #t

  local j = 1
  for i = 1, finish do
    local v = t[i]
    local vh = key_fn(v, key)
    if not seen[vh] then
      t[j] = v
      if vh ~= nil then
        seen[vh] = true
      end
      j = j + 1
    end
  end

  for i = j, finish do
    t[i] = nil
  end

  return t
end

---@class vim.list.bisect.Opts
---@inlinedoc
---
--- Start index of the list.
--- (default: `1`)
---@field lo? integer
---
--- End index of the list, exclusive.
--- (default: `#t + 1`)
---@field hi? integer
---
--- Optional, compare the return value instead of the {val} itself if provided.
---@field key? fun(val: any): any
---
--- Specifies the search variant.
---   - "lower": returns the first position
---     where inserting {val} keeps the list sorted.
---   - "upper": returns the last position
---     where inserting {val} keeps the list sorted..
--- (default: `'lower'`)
---@field bound? 'lower' | 'upper'

---@generic T
---@param t T[]
---@param val T
---@param key? fun(val: any): any
---@param lo integer
---@param hi integer
---@return integer i in range such that `t[j]` < {val} for all j < i,
---                and `t[j]` >= {val} for all j >= i,
---                or return {hi} if no such index is found.
local function lower_bound(t, val, lo, hi, key)
  local bit = require('bit') -- Load bitop on demand
  local val_key = key_fn(val, key)
  while lo < hi do
    local mid = bit.rshift(lo + hi, 1) -- Equivalent to floor((lo + hi) / 2)
    if key_fn(t[mid], key) < val_key then
      lo = mid + 1
    else
      hi = mid
    end
  end
  return lo
end

---@generic T
---@param t T[]
---@param val T
---@param key? fun(val: any): any
---@param lo integer
---@param hi integer
---@return integer i in range such that `t[j]` <= {val} for all j < i,
---                and `t[j]` > {val} for all j >= i,
---                or return {hi} if no such index is found.
local function upper_bound(t, val, lo, hi, key)
  local bit = require('bit') -- Load bitop on demand
  local val_key = key_fn(val, key)
  while lo < hi do
    local mid = bit.rshift(lo + hi, 1) -- Equivalent to floor((lo + hi) / 2)
    if val_key < key_fn(t[mid], key) then
      hi = mid
    else
      lo = mid + 1
    end
  end
  return lo
end

--- Search for a position in a sorted |lua-list| {t} where {val} can be inserted while keeping the
--- list sorted.
---
--- Use {bound} to determine whether to return the first or the last position,
--- defaults to "lower", i.e., the first position.
---
--- NOTE: Behavior is undefined on unsorted lists!
---
--- Example:
--- ```lua
---
--- local t = { 1, 2, 2, 3, 3, 3 }
--- local first = vim.list.bisect(t, 3)
--- -- `first` is `val`'s first index if found,
--- -- useful for existence checks.
--- print(t[first]) -- 3
---
--- local last = vim.list.bisect(t, 3, { bound = 'upper' })
--- -- Note that `last` is 7, not 6,
--- -- this is suitable for insertion.
---
--- table.insert(t, last, 4)
--- -- t is now { 1, 2, 2, 3, 3, 3, 4 }
---
--- -- You can use lower bound and upper bound together
--- -- to obtain the range of occurrences of `val`.
---
--- -- 3 is in [first, last)
--- for i = first, last - 1 do
---   print(t[i]) -- { 3, 3, 3 }
--- end
--- ```
---@since 14
---@generic T
---@param t T[] A comparable list.
---@param val T The value to search.
---@param opts? vim.list.bisect.Opts
---@return integer index serves as either the lower bound or the upper bound position.
function vim.list.bisect(t, val, opts)
  vim.validate('t', t, 'table')
  vim.validate('opts', opts, 'table', true)

  opts = opts or {}
  local lo = opts.lo or 1
  local hi = opts.hi or #t + 1
  local key = opts.key

  if opts.bound == 'upper' then
    return upper_bound(t, val, lo, hi, key)
  else
    return lower_bound(t, val, lo, hi, key)
  end
end

--- Checks if a table is empty.
---
---@see https://github.com/premake/premake-core/blob/master/src/base/table.lua
---
---@param t table Table to check
---@return boolean `true` if `t` is empty
function vim.tbl_isempty(t)
  vim.validate('t', t, 'table')
  return next(t) == nil
end

--- We only merge empty tables or tables that are not list-like (indexed by consecutive integers
--- starting from 1)
local function can_merge(v)
  return type(v) == 'table' and (vim.tbl_isempty(v) or not vim.islist(v))
end

--- Recursive worker for tbl_extend
--- @param behavior 'error'|'keep'|'force'|fun(key:any, prev_value:any?, value:any): any
--- @param deep_extend boolean
--- @param ... table<any,any>
local function tbl_extend_rec(behavior, deep_extend, ...)
  local ret = {} --- @type table<any,any>
  if vim._empty_dict_mt ~= nil and getmetatable(select(1, ...)) == vim._empty_dict_mt then
    ret = vim.empty_dict()
  end

  for i = 1, select('#', ...) do
    local tbl = select(i, ...) --[[@as table<any,any>]]
    if tbl then
      for k, v in pairs(tbl) do
        if deep_extend and can_merge(v) and can_merge(ret[k]) then
          ret[k] = tbl_extend_rec(behavior, true, ret[k], v)
        elseif type(behavior) == 'function' then
          ret[k] = behavior(k, ret[k], v)
        elseif behavior ~= 'force' and ret[k] ~= nil then
          if behavior == 'error' then
            error('key found in more than one map: ' .. k)
          end -- Else behavior is "keep".
        else
          ret[k] = v
        end
      end
    end
  end

  return ret
end

--- @param behavior 'error'|'keep'|'force'|fun(key:any, prev_value:any?, value:any): any
--- @param deep_extend boolean
--- @param ... table<any,any>
local function tbl_extend(behavior, deep_extend, ...)
  if
    behavior ~= 'error'
    and behavior ~= 'keep'
    and behavior ~= 'force'
    and type(behavior) ~= 'function'
  then
    error('invalid "behavior": ' .. tostring(behavior))
  end

  local nargs = select('#', ...)

  if nargs < 2 then
    error(('wrong number of arguments (given %d, expected at least 3)'):format(1 + nargs))
  end

  for i = 1, nargs do
    vim.validate('after the second argument', select(i, ...), 'table')
  end

  return tbl_extend_rec(behavior, deep_extend, ...)
end

--- Merges two or more tables.
---
---@see |extend()|
---
---@param behavior 'error'|'keep'|'force'|fun(key:any, prev_value:any?, value:any): any Decides what to do if a key is found in more than one map:
---      - "error": raise an error
---      - "keep":  use value from the leftmost map
---      - "force": use value from the rightmost map
---      - If a function, it receives the current key, the previous value in the currently merged table (if present), the current value and should
---        return the value for the given key in the merged table.
---@param ... table Two or more tables
---@return table : Merged table
function vim.tbl_extend(behavior, ...)
  return tbl_extend(behavior, false, ...)
end

--- Merges recursively two or more tables.
---
--- Only values that are empty tables or tables that are not |lua-list|s (indexed by consecutive
--- integers starting from 1) are merged recursively. This is useful for merging nested tables
--- like default and user configurations where lists should be treated as literals (i.e., are
--- overwritten instead of merged).
---
---@see |vim.tbl_extend()|
---
---@generic T1: table
---@generic T2: table
---@param behavior 'error'|'keep'|'force'|fun(key:any, prev_value:any?, value:any): any Decides what to do if a key is found in more than one map:
---      - "error": raise an error
---      - "keep":  use value from the leftmost map
---      - "force": use value from the rightmost map
---      - If a function, it receives the current key, the previous value in the currently merged table (if present), the current value and should
---        return the value for the given key in the merged table.
---@param ... T2 Two or more tables
---@return T1|T2 (table) Merged table
function vim.tbl_deep_extend(behavior, ...)
  return tbl_extend(behavior, true, ...)
end

--- Deep compare values for equality
---
--- Tables are compared recursively unless they both provide the `eq` metamethod.
--- All other types are compared using the equality `==` operator.
---@param a any First value
---@param b any Second value
---@return boolean `true` if values are equals, else `false`
function vim.deep_equal(a, b)
  if a == b then
    return true
  end
  if type(a) ~= type(b) then
    return false
  end
  if type(a) == 'table' then
    --- @cast a table<any,any>
    --- @cast b table<any,any>
    for k, v in pairs(a) do
      if not vim.deep_equal(v, b[k]) then
        return false
      end
    end
    for k in pairs(b) do
      if a[k] == nil then
        return false
      end
    end
    return true
  end
  return false
end

--- Add the reverse lookup values to an existing table.
--- For example:
--- `tbl_add_reverse_lookup { A = 1 } == { [1] = 'A', A = 1 }`
---
--- Note that this *modifies* the input.
---@deprecated
---@param o table Table to add the reverse to
---@return table o
function vim.tbl_add_reverse_lookup(o)
  vim.deprecate('vim.tbl_add_reverse_lookup', nil, '0.12')

  --- @cast o table<any,any>
  --- @type any[]
  local keys = vim.tbl_keys(o)
  for _, k in ipairs(keys) do
    local v = o[k]
    if o[v] then
      error(
        string.format(
          'The reverse lookup found an existing value for %q while processing key %q',
          tostring(v),
          tostring(k)
        )
      )
    end
    o[v] = k
  end
  return o
end

--- Gets a value from (nested) table `o` given by the sequence of keys `...`, or `nil` if not found.
---
--- Examples:
---
--- ```lua
--- vim.tbl_get({ key = { nested_key = true }}, 'key', 'nested_key') == true
--- vim.tbl_get({ key = {}}, 'key', 'nested_key') == nil
--- ```
---@see |unpack()|
---
---@param o table Table to index
---@param ... any Optional keys (0 or more, variadic) via which to index the table
---@return any # Nested value indexed by key (if it exists), else nil
function vim.tbl_get(o, ...)
  local nargs = select('#', ...)
  if nargs == 0 then
    return nil
  end
  for i = 1, nargs do
    o = o[select(i, ...)] --- @type any
    if o == nil then
      return nil
    elseif type(o) ~= 'table' and i ~= nargs then
      return nil
    end
  end
  return o
end

--- Extends a list-like table with the values of another list-like table.
---
--- NOTE: This mutates dst!
---
---@see |vim.tbl_extend()|
---
---@generic T: table
---@param dst T List which will be modified and appended to
---@param src table List from which values will be inserted
---@param start integer? Start index on src. Defaults to 1
---@param finish integer? Final index on src. Defaults to `#src`
---@return T dst
function vim.list_extend(dst, src, start, finish)
  vim.validate('dst', dst, 'table')
  vim.validate('src', src, 'table')
  vim.validate('start', start, 'number', true)
  vim.validate('finish', finish, 'number', true)
  for i = start or 1, finish or #src do
    table.insert(dst, src[i])
  end
  return dst
end

--- @deprecated
--- Creates a copy of a list-like table such that any nested tables are
--- "unrolled" and appended to the result.
---
---@see From https://github.com/premake/premake-core/blob/master/src/base/table.lua
---
---@param t table List-like table
---@return table Flattened copy of the given list-like table
function vim.tbl_flatten(t)
  vim.deprecate('vim.tbl_flatten', 'vim.iter(…):flatten():totable()', '0.13')
  local result = {}
  --- @param _t table<any,any>
  local function _tbl_flatten(_t)
    local n = #_t
    for i = 1, n do
      local v = _t[i]
      if type(v) == 'table' then
        _tbl_flatten(v)
      elseif v then
        table.insert(result, v)
      end
    end
  end
  _tbl_flatten(t)
  return result
end

--- Enumerates key-value pairs of a table, ordered by key.
---
---@see Based on https://github.com/premake/premake-core/blob/master/src/base/table.lua
---
---@generic T: table, K, V
---@param t T Dict-like table
---@return fun(table: table<K, V>, index?: K):K, V # |for-in| iterator over sorted keys and their values
---@return T
function vim.spairs(t)
  vim.validate('t', t, 'table')
  --- @cast t table<any,any>

  -- collect the keys
  local keys = {} --- @type string[]
  for k in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys)

  -- Return the iterator function.
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end,
    t
end

--- Tests if `t` is an "array": a table indexed _only_ by integers (potentially non-contiguous).
---
--- If the indexes start from 1 and are contiguous then the array is also a list. |vim.islist()|
---
--- Empty table `{}` is an array, unless it was created by |vim.empty_dict()| or returned as
--- a dict-like |API| or Vimscript result, for example from |rpcrequest()| or |vim.fn|.
---
---@see https://github.com/openresty/luajit2#tableisarray
---
---@param t? any
---@return boolean `true` if array-like table, else `false`.
function vim.isarray(t)
  if type(t) ~= 'table' then
    return false
  end

  --- @cast t table<any,any>

  local count = 0

  for k, _ in pairs(t) do
    -- Check if the number k is an integer
    if type(k) == 'number' and k == math.floor(k) then
      count = count + 1
    else
      return false
    end
  end

  if count > 0 then
    return true
  else
    -- TODO(bfredl): in the future, we will always be inside nvim
    -- then this check can be deleted.
    if vim._empty_dict_mt == nil then
      return false
    end
    return getmetatable(t) ~= vim._empty_dict_mt
  end
end

--- @deprecated
function vim.tbl_islist(t)
  vim.deprecate('vim.tbl_islist', 'vim.islist', '0.12')
  return vim.islist(t)
end

--- Tests if `t` is a "list": a table indexed _only_ by contiguous integers starting from 1 (what
--- |lua-length| calls a "regular array").
---
--- Empty table `{}` is a list, unless it was created by |vim.empty_dict()| or returned as
--- a dict-like |API| or Vimscript result, for example from |rpcrequest()| or |vim.fn|.
---
---@see |vim.isarray()|
---
---@param t? any
---@return boolean `true` if list-like table, else `false`.
function vim.islist(t)
  if type(t) ~= 'table' then
    return false
  end

  if next(t) == nil then
    return getmetatable(t) ~= vim._empty_dict_mt
  end

  local j = 1
  for _ in
    pairs(t--[[@as table<any,any>]])
  do
    if t[j] == nil then
      return false
    end
    j = j + 1
  end

  return true
end

--- Counts the number of non-nil values in table `t`.
---
--- ```lua
--- vim.tbl_count({ a=1, b=2 })  --> 2
--- vim.tbl_count({ 1, 2 })      --> 2
--- ```
---
---@see https://github.com/Tieske/Penlight/blob/master/lua/pl/tablex.lua
---@param t table Table
---@return integer : Number of non-nil values in table
function vim.tbl_count(t)
  vim.validate('t', t, 'table')
  --- @cast t table<any,any>

  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

--- Creates a copy of a table containing only elements from start to end (inclusive)
---
---@generic T
---@param list T[] Table
---@param start integer|nil Start range of slice
---@param finish integer|nil End range of slice
---@return T[] Copy of table sliced from start to finish (inclusive)
function vim.list_slice(list, start, finish)
  local new_list = {} --- @type `T`[]
  for i = start or 1, finish or #list do
    new_list[#new_list + 1] = list[i]
  end
  return new_list
end

--- Efficiently insert items into the middle of a list.
---
--- Calling table.insert() in a loop will re-index the tail of the table on
--- every iteration, instead this function will re-index  the table exactly
--- once.
---
--- Based on https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating/53038524#53038524
---
---@param t any[]
---@param first integer
---@param last integer
---@param v any
function vim._list_insert(t, first, last, v)
  local n = #t

  -- Shift table forward
  for i = n - first, 0, -1 do
    t[last + 1 + i] = t[first + i]
  end

  -- Fill in new values
  for i = first, last do
    t[i] = v
  end
end

--- Efficiently remove items from middle of a list.
---
--- Calling table.remove() in a loop will re-index the tail of the table on
--- every iteration, instead this function will re-index  the table exactly
--- once.
---
--- Based on https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating/53038524#53038524
---
---@param t any[]
---@param first integer
---@param last integer
function vim._list_remove(t, first, last)
  local n = #t
  for i = 0, n - first do
    t[first + i] = t[last + 1 + i]
    t[last + 1 + i] = nil
  end
end

--- Trim whitespace (Lua pattern "%s") from both sides of a string.
---
---@see |lua-pattern|s
---@see https://www.lua.org/pil/20.2.html
---@param s string String to trim
---@return string String with whitespace removed from its beginning and end
function vim.trim(s)
  vim.validate('s', s, 'string')
  -- `s:match('^%s*(.*%S)')` is slow for long whitespace strings,
  -- so we are forced to split it into two parts to prevent this
  return s:gsub('^%s+', ''):match('^.*%S') or ''
end

--- Escapes magic chars in |lua-pattern|s.
---
---@see https://github.com/rxi/lume
---@param s string String to escape
---@return string %-escaped pattern string
function vim.pesc(s)
  vim.validate('s', s, 'string')
  return (s:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%1'))
end

--- Tests if `s` starts with `prefix`.
---
---@param s string String
---@param prefix string Prefix to match
---@return boolean `true` if `prefix` is a prefix of `s`
function vim.startswith(s, prefix)
  vim.validate('s', s, 'string')
  vim.validate('prefix', prefix, 'string')
  return s:sub(1, #prefix) == prefix
end

--- Tests if `s` ends with `suffix`.
---
---@param s string String
---@param suffix string Suffix to match
---@return boolean `true` if `suffix` is a suffix of `s`
function vim.endswith(s, suffix)
  vim.validate('s', s, 'string')
  vim.validate('suffix', suffix, 'string')
  return #suffix == 0 or s:sub(-#suffix) == suffix
end

do
  --- @alias vim.validate.Validator
  --- | type
  --- | 'callable'
  --- | (type|'callable')[]
  --- | fun(v:any):boolean, string?

  local type_aliases = {
    b = 'boolean',
    c = 'callable',
    f = 'function',
    n = 'number',
    s = 'string',
    t = 'table',
  }

  --- @nodoc
  --- @class vim.validate.Spec
  --- @field [1] any Argument value
  --- @field [2] vim.validate.Validator Argument validator
  --- @field [3]? boolean|string Optional flag or error message

  local function is_type(val, t)
    return type(val) == t or (t == 'callable' and vim.is_callable(val))
  end

  --- @param param_name string
  --- @param val any
  --- @param validator vim.validate.Validator
  --- @param message? string "Expected" message
  --- @param allow_alias? boolean Allow short type names: 'n', 's', 't', 'b', 'f', 'c'
  --- @return string?
  local function is_valid(param_name, val, validator, message, allow_alias)
    if type(validator) == 'string' then
      local expected = allow_alias and type_aliases[validator] or validator

      if not expected then
        return string.format('invalid type name: %s', validator)
      end

      if not is_type(val, expected) then
        return ('%s: expected %s, got %s'):format(param_name, message or expected, type(val))
      end
    elseif vim.is_callable(validator) then
      -- Check user-provided validation function
      local valid, opt_msg = validator(val)
      if not valid then
        local err_msg = ('%s: expected %s, got %s'):format(
          param_name,
          message or '?',
          tostring(val)
        )
        err_msg = opt_msg and ('%s. Info: %s'):format(err_msg, opt_msg) or err_msg

        return err_msg
      end
    elseif type(validator) == 'table' then
      for _, t in ipairs(validator) do
        local expected = allow_alias and type_aliases[t] or t
        if not expected then
          return string.format('invalid type name: %s', t)
        end

        if is_type(val, expected) then
          return -- success
        end
      end

      -- Normalize validator types for error message
      if allow_alias then
        for i, t in ipairs(validator) do
          validator[i] = type_aliases[t] or t
        end
      end

      return string.format(
        '%s: expected %s, got %s',
        param_name,
        table.concat(validator, '|'),
        type(val)
      )
    else
      return string.format('invalid validator: %s', tostring(validator))
    end
  end

  --- @param opt table<type|'callable',vim.validate.Spec>
  --- @return string?
  local function validate_spec(opt)
    local report --- @type table<string,string>?

    for param_name, spec in pairs(opt) do
      local err_msg --- @type string?
      if type(spec) ~= 'table' then
        err_msg = string.format('opt[%s]: expected table, got %s', param_name, type(spec))
      else
        local value, validator = spec[1], spec[2]
        local msg = type(spec[3]) == 'string' and spec[3] or nil --[[@as string?]]
        local optional = spec[3] == true
        if not (optional and value == nil) then
          err_msg = is_valid(param_name, value, validator, msg, true)
        end
      end

      if err_msg then
        report = report or {}
        report[param_name] = err_msg
      end
    end

    if report then
      for _, msg in vim.spairs(report) do -- luacheck: ignore
        return msg
      end
    end
  end

  --- Validate function arguments.
  ---
  --- This function has two valid forms:
  ---
  --- 1. `vim.validate(name, value, validator[, optional][, message])`
  ---
  ---     Validates that argument {name} with value {value} satisfies
  ---     {validator}. If {optional} is given and is `true`, then {value} may be
  ---     `nil`. If {message} is given, then it is used as the expected type in the
  ---     error message.
  ---
  ---     Example:
  ---
  ---     ```lua
  ---       function vim.startswith(s, prefix)
  ---         vim.validate('s', s, 'string')
  ---         vim.validate('prefix', prefix, 'string')
  ---         -- ...
  ---       end
  ---     ```
  ---
  --- 2. `vim.validate(spec)` (deprecated)
  ---     where `spec` is of type
  ---    `table<string,[value:any, validator: vim.validate.Validator, optional_or_msg? : boolean|string]>)`
  ---
  ---     Validates a argument specification.
  ---     Specs are evaluated in alphanumeric order, until the first failure.
  ---
  ---     Example:
  ---
  ---     ```lua
  ---       function user.new(name, age, hobbies)
  ---         vim.validate{
  ---           name={name, 'string'},
  ---           age={age, 'number'},
  ---           hobbies={hobbies, 'table'},
  ---         }
  ---         -- ...
  ---       end
  ---     ```
  ---
  --- Examples with explicit argument values (can be run directly):
  ---
  --- ```lua
  --- vim.validate('arg1', {'foo'}, 'table')
  ---    --> NOP (success)
  --- vim.validate('arg2', 'foo', 'string')
  ---    --> NOP (success)
  ---
  --- vim.validate('arg1', 1, 'table')
  ---    --> error('arg1: expected table, got number')
  ---
  --- vim.validate('arg1', 3, function(a) return (a % 2) == 0 end, 'even number')
  ---    --> error('arg1: expected even number, got 3')
  --- ```
  ---
  --- If multiple types are valid they can be given as a list.
  ---
  --- ```lua
  --- vim.validate('arg1', {'foo'}, {'table', 'string'})
  --- vim.validate('arg2', 'foo', {'table', 'string'})
  --- -- NOP (success)
  ---
  --- vim.validate('arg1', 1, {'string', 'table'})
  --- -- error('arg1: expected string|table, got number')
  --- ```
  ---
  --- @note `validator` set to a value returned by |lua-type()| provides the
  --- best performance.
  ---
  --- @param name string Argument name
  --- @param value any Argument value
  --- @param validator vim.validate.Validator :
  ---   - (`string|string[]`): Any value that can be returned from |lua-type()| in addition to
  ---     `'callable'`: `'boolean'`, `'callable'`, `'function'`, `'nil'`, `'number'`, `'string'`, `'table'`,
  ---     `'thread'`, `'userdata'`.
  ---   - (`fun(val:any): boolean, string?`) A function that returns a boolean and an optional
  ---     string message.
  --- @param optional? boolean Parameter is optional (may be omitted or nil)
  --- @param message? string message when validation fails
  --- @overload fun(name: string, val: any, validator: vim.validate.Validator, message: string)
  --- @overload fun(spec: table<string,[any, vim.validate.Validator, boolean|string]>)
  function vim.validate(name, value, validator, optional, message)
    local err_msg --- @type string?
    if validator then -- Form 1
      -- Check validator as a string first to optimize the common case.
      local ok = (type(value) == validator) or (value == nil and optional == true)
      if not ok then
        local msg = type(optional) == 'string' and optional or message --[[@as string?]]
        -- Check more complicated validators
        err_msg = is_valid(name, value, validator, msg, false)
      end
    elseif type(name) == 'table' then -- Form 2
      vim.deprecate('vim.validate{<table>}', 'vim.validate(<params>)', '1.0')
      err_msg = validate_spec(name)
    else
      error('invalid arguments')
    end

    if err_msg then
      error(err_msg, 2)
    end
  end
end

--- Returns true if object `f` can be called as a function.
---
---@param f? any Any object
---@return boolean `true` if `f` is callable, else `false`
function vim.is_callable(f)
  if type(f) == 'function' then
    return true
  end
  local m = getmetatable(f)
  if m == nil then
    return false
  end
  return type(rawget(m, '__call')) == 'function'
end

--- Creates a table whose missing keys are provided by {createfn} (like Python's "defaultdict").
---
--- If {createfn} is `nil` it defaults to defaulttable() itself, so accessing nested keys creates
--- nested tables:
---
--- ```lua
--- local a = vim.defaulttable()
--- a.b.c = 1
--- ```
---
---@param createfn? fun(key:any):any Provides the value for a missing `key`.
---@return table # Empty table with `__index` metamethod.
function vim.defaulttable(createfn)
  createfn = createfn or function(_)
    return vim.defaulttable()
  end
  return setmetatable({}, {
    __index = function(tbl, key)
      rawset(tbl, key, createfn(key))
      return rawget(tbl, key)
    end,
  })
end

do
  ---@class vim.Ringbuf<T>
  ---@field private _items table[]
  ---@field private _idx_read integer
  ---@field private _idx_write integer
  ---@field private _size integer
  ---@overload fun(self): table?
  local Ringbuf = {}

  --- Clear all items
  function Ringbuf.clear(self)
    self._items = {}
    self._idx_read = 0
    self._idx_write = 0
  end

  --- Adds an item, overriding the oldest item if the buffer is full.
  ---@generic T
  ---@param item T
  function Ringbuf.push(self, item)
    self._items[self._idx_write] = item
    self._idx_write = (self._idx_write + 1) % self._size
    if self._idx_write == self._idx_read then
      self._idx_read = (self._idx_read + 1) % self._size
    end
  end

  --- Removes and returns the first unread item
  ---@generic T
  ---@return T?
  function Ringbuf.pop(self)
    local idx_read = self._idx_read
    if idx_read == self._idx_write then
      return nil
    end
    local item = self._items[idx_read]
    self._items[idx_read] = nil
    self._idx_read = (idx_read + 1) % self._size
    return item
  end

  --- Returns the first unread item without removing it
  ---@generic T
  ---@return T?
  function Ringbuf.peek(self)
    if self._idx_read == self._idx_write then
      return nil
    end
    return self._items[self._idx_read]
  end

  --- Create a ring buffer limited to a maximal number of items.
  --- Once the buffer is full, adding a new entry overrides the oldest entry.
  ---
  --- ```lua
  --- local ringbuf = vim.ringbuf(4)
  --- ringbuf:push("a")
  --- ringbuf:push("b")
  --- ringbuf:push("c")
  --- ringbuf:push("d")
  --- ringbuf:push("e")    -- overrides "a"
  --- print(ringbuf:pop()) -- returns "b"
  --- print(ringbuf:pop()) -- returns "c"
  ---
  --- -- Can be used as iterator. Pops remaining items:
  --- for val in ringbuf do
  ---   print(val)
  --- end
  --- ```
  ---
  --- Returns a Ringbuf instance with the following methods:
  ---
  --- - |Ringbuf:push()|
  --- - |Ringbuf:pop()|
  --- - |Ringbuf:peek()|
  --- - |Ringbuf:clear()|
  ---
  ---@param size integer
  ---@return vim.Ringbuf ringbuf
  function vim.ringbuf(size)
    local ringbuf = {
      _items = {},
      _size = size + 1,
      _idx_read = 0,
      _idx_write = 0,
    }
    return setmetatable(ringbuf, {
      __index = Ringbuf,
      __call = function(self)
        return self:pop()
      end,
    })
  end
end

--- @generic T
--- @param root string
--- @param mod T
--- @return T
function vim._defer_require(root, mod)
  return setmetatable({ _submodules = mod }, {
    ---@param t table<string, any>
    ---@param k string
    __index = function(t, k)
      if not mod[k] then
        return
      end
      local name = string.format('%s.%s', root, k)
      t[k] = require(name)
      return t[k]
    end,
  })
end

--- Creates a module alias/shim that lazy-loads a target module.
---
--- Unlike `vim.defaulttable()` this also:
--- - implements __call
--- - calls vim.deprecate()
---
--- @param old_name string Name of the deprecated module, which will be shimmed.
--- @param new_name string Name of the new module, which will be loaded by require().
function vim._defer_deprecated_module(old_name, new_name)
  return setmetatable({}, {
    ---@param _ table<string, any>
    ---@param k string
    __index = function(_, k)
      vim.deprecate(old_name, new_name, '2.0.0', nil, false)
      --- @diagnostic disable-next-line:no-unknown
      local target = require(new_name)
      return target[k]
    end,
    __call = function(self)
      vim.deprecate(old_name, new_name, '2.0.0', nil, false)
      --- @diagnostic disable-next-line:no-unknown
      local target = require(new_name)
      return target(self)
    end,
  })
end

--- @nodoc
--- @class vim.context.mods
--- @field bo? table<string, any>
--- @field buf? integer
--- @field emsg_silent? boolean
--- @field env? table<string, any>
--- @field go? table<string, any>
--- @field hide? boolean
--- @field keepalt? boolean
--- @field keepjumps? boolean
--- @field keepmarks? boolean
--- @field keeppatterns? boolean
--- @field lockmarks? boolean
--- @field noautocmd? boolean
--- @field o? table<string, any>
--- @field sandbox? boolean
--- @field silent? boolean
--- @field unsilent? boolean
--- @field win? integer
--- @field wo? table<string, any>

--- @nodoc
--- @class vim.context.state
--- @field bo? table<string, any>
--- @field env? table<string, any>
--- @field go? table<string, any>
--- @field wo? table<string, any>

local scope_map = { buf = 'bo', global = 'go', win = 'wo' }
local scope_order = { 'o', 'wo', 'bo', 'go', 'env' }
local state_restore_order = { 'bo', 'wo', 'go', 'env' }

--- Gets data about current state, enough to properly restore specified options/env/etc.
--- @param context vim.context.mods
--- @return vim.context.state
local get_context_state = function(context)
  --- @type vim.context.state
  local res = { bo = {}, env = {}, go = {}, wo = {} }

  -- Use specific order from possibly most to least intrusive
  for _, scope in ipairs(scope_order) do
    for name, _ in
      pairs(context[scope] or {} --[[@as table<string,any>]])
    do
      local sc = scope == 'o' and scope_map[vim.api.nvim_get_option_info2(name, {}).scope] or scope

      -- Do not override already set state and fall back to `vim.NIL` for
      -- state `nil` values (which still needs restoring later)
      res[sc][name] = vim.F.if_nil(res[sc][name], vim[sc][name], vim.NIL)

      -- Always track global option value to properly restore later.
      -- This matters for at least `o` and `wo` (which might set either/both
      -- local and global option values).
      if sc ~= 'env' and res.go[name] == nil then
        res.go[name] = vim.go[name]
      end
    end
  end

  return res
end

--- Executes function `f` with the given context specification.
---
--- Notes:
--- - Context `{ buf = buf }` has no guarantees about current window when
---   inside context.
--- - Context `{ buf = buf, win = win }` is yet not allowed, but this seems
---   to be an implementation detail.
--- - There should be no way to revert currently set `context.sandbox = true`
---   (like with nested `vim._with()` calls). Otherwise it kind of breaks the
---   whole purpose of sandbox execution.
--- - Saving and restoring option contexts (`bo`, `go`, `o`, `wo`) trigger
---   `OptionSet` events. This is an implementation issue because not doing it
---   seems to mean using either 'eventignore' option or extra nesting with
---   `{ noautocmd = true }` (which itself is a wrapper for 'eventignore').
---   As `{ go = { eventignore = '...' } }` is a valid context which should be
---   properly set and restored, this is not a good approach.
---   Not triggering `OptionSet` seems to be a good idea, though. So probably
---   only moving context save and restore to lower level might resolve this.
---
--- @param context vim.context.mods
--- @param f function
--- @return any
function vim._with(context, f)
  vim.validate('context', context, 'table')
  vim.validate('f', f, 'function')

  vim.validate('context.bo', context.bo, 'table', true)
  vim.validate('context.buf', context.buf, 'number', true)
  vim.validate('context.emsg_silent', context.emsg_silent, 'boolean', true)
  vim.validate('context.env', context.env, 'table', true)
  vim.validate('context.go', context.go, 'table', true)
  vim.validate('context.hide', context.hide, 'boolean', true)
  vim.validate('context.keepalt', context.keepalt, 'boolean', true)
  vim.validate('context.keepjumps', context.keepjumps, 'boolean', true)
  vim.validate('context.keepmarks', context.keepmarks, 'boolean', true)
  vim.validate('context.keeppatterns', context.keeppatterns, 'boolean', true)
  vim.validate('context.lockmarks', context.lockmarks, 'boolean', true)
  vim.validate('context.noautocmd', context.noautocmd, 'boolean', true)
  vim.validate('context.o', context.o, 'table', true)
  vim.validate('context.sandbox', context.sandbox, 'boolean', true)
  vim.validate('context.silent', context.silent, 'boolean', true)
  vim.validate('context.unsilent', context.unsilent, 'boolean', true)
  vim.validate('context.win', context.win, 'number', true)
  vim.validate('context.wo', context.wo, 'table', true)

  -- Check buffer exists
  if context.buf then
    if not vim.api.nvim_buf_is_valid(context.buf) then
      error('Invalid buffer id: ' .. context.buf)
    end
  end

  -- Check window exists
  if context.win then
    if not vim.api.nvim_win_is_valid(context.win) then
      error('Invalid window id: ' .. context.win)
    end
    -- TODO: Maybe allow it?
    if context.buf and vim.api.nvim_win_get_buf(context.win) ~= context.buf then
      error('Can not set both `buf` and `win` context.')
    end
  end

  -- Decorate so that save-set-restore options is done in correct window-buffer
  local callback = function()
    -- Cache current values to be changed by context
    -- Abort early in case of bad context value
    local ok, state = pcall(get_context_state, context)
    if not ok then
      error(state, 0)
    end

    -- Apply some parts of the context in specific order
    -- NOTE: triggers `OptionSet` event
    for _, scope in ipairs(scope_order) do
      for name, context_value in
        pairs(context[scope] or {} --[[@as table<string,any>]])
      do
        --- @diagnostic disable-next-line:no-unknown
        vim[scope][name] = context_value
      end
    end

    -- Execute
    local res = { pcall(f) }

    -- Restore relevant cached values in specific order, global scope last
    -- NOTE: triggers `OptionSet` event
    for _, scope in ipairs(state_restore_order) do
      for name, cached_value in
        pairs(state[scope] --[[@as table<string,any>]])
      do
        --- @diagnostic disable-next-line:no-unknown
        vim[scope][name] = cached_value
      end
    end

    -- Return
    if not res[1] then
      error(res[2], 0)
    end
    table.remove(res, 1)
    return unpack(res, 1, table.maxn(res))
  end

  return vim._with_c(context, callback)
end

--- @param bufnr? integer
--- @return integer
function vim._resolve_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  vim.validate('bufnr', bufnr, 'number')
  return bufnr
end

--- @generic T
--- @param x T|T[]
--- @return T[]
function vim._ensure_list(x)
  if type(x) == 'table' then
    return x
  end
  return { x }
end

--- Coerces {x} to an integer, like `tonumber()`, but rejects fractional values.
---
--- Returns `nil` if {x} cannot be converted with `tonumber()`, or if the
--- resulting number is not integral.
---
--- @param x any Value to convert.
--- @param base? integer Numeric base passed to `tonumber()`.
--- @return integer? integer Converted integer value, or `nil`.
function vim._tointeger(x, base)
  --- @diagnostic disable-next-line:param-type-mismatch optional `base` is equivalent to `tonumber(x)`
  local nx = tonumber(x, base)
  if nx and nx == math.floor(nx) then
    --- @cast nx integer
    return nx
  end
end

--- Coerces {x} to an integer and errors if conversion fails.
---
--- This is the throwing counterpart to |vim._tointeger()| and should be used
--- when non-integer input is a programming error.
---
--- @param x any Value to convert.
--- @param base? integer Numeric base passed to `tonumber()`.
--- @return integer integer Converted integer value.
function vim._assert_integer(x, base)
  return vim._tointeger(x, base) or error(('Cannot convert %s to integer'):format(x))
end

--- Returns whether or not the given integer is even.
---
--- @param n integer The integer to check for parity.
--- @return boolean parity The parity.
function vim.isEven(n)
  n = vim._assert_integer(n)

  -- Convert negative integer to positive in O(2) time.
  if vim.startswith(tostring(n), '-') then
    n = tonumber(tostring(n):sub(2)) --[[@as integer]]
  end

  -- TODO(ribru17): Eventually we will need vim.isOdd(), but for now a viable workaround is to
  -- use `vim.isEven(n - 1)`.
  return n == 0
    or n == 2
    or n == 4
    or n == 6
    or n == 8
    or n == 10
    or n == 12
    or n == 14
    or n == 16
    or n == 18
    or n == 20
    or n == 22
    or n == 24
    or n == 26
    or n == 28
    or n == 30
    or n == 32
    or n == 34
    or n == 36
    or n == 38
    or n == 40
    or n == 42
    or n == 44
    or n == 46
    or n == 48
    or n == 50
    or n == 52
    or n == 54
    or n == 56
    or n == 58
    or n == 60
    or n == 62
    or n == 64
    or n == 66
    or n == 68
    or n == 70
    or n == 72
    or n == 74
    or n == 76
    or n == 78
    or n == 80
    or n == 82
    or n == 84
    or n == 86
    or n == 88
    or n == 90
    or n == 92
    or n == 94
    or n == 96
    or n == 98
    or n == 100
    or n == 102
    or n == 104
    or n == 106
    or n == 108
    or n == 110
    or n == 112
    or n == 114
    or n == 116
    or n == 118
    or n == 120
    or n == 122
    or n == 124
    or n == 126
    or n == 128
    or n == 130
    or n == 132
    or n == 134
    or n == 136
    or n == 138
    or n == 140
    or n == 142
    or n == 144
    or n == 146
    or n == 148
    or n == 150
    or n == 152
    or n == 154
    or n == 156
    or n == 158
    or n == 160
    or n == 162
    or n == 164
    or n == 166
    or n == 168
    or n == 170
    or n == 172
    or n == 174
    or n == 176
    or n == 178
    or n == 180
    or n == 182
    or n == 184
    or n == 186
    or n == 188
    or n == 190
    or n == 192
    or n == 194
    or n == 196
    or n == 198
    or n == 200
    or n == 202
    or n == 204
    or n == 206
    or n == 208
    or n == 210
    or n == 212
    or n == 214
    or n == 216
    or n == 218
    or n == 220
    or n == 222
    or n == 224
    or n == 226
    or n == 228
    or n == 230
    or n == 232
    or n == 234
    or n == 236
    or n == 238
    or n == 240
    or n == 242
    or n == 244
    or n == 246
    or n == 248
    or n == 250
    or n == 252
    or n == 254
    or n == 256
    or n == 258
    or n == 260
    or n == 262
    or n == 264
    or n == 266
    or n == 268
    or n == 270
    or n == 272
    or n == 274
    or n == 276
    or n == 278
    or n == 280
    or n == 282
    or n == 284
    or n == 286
    or n == 288
    or n == 290
    or n == 292
    or n == 294
    or n == 296
    or n == 298
    or n == 300
    or n == 302
    or n == 304
    or n == 306
    or n == 308
    or n == 310
    or n == 312
    or n == 314
    or n == 316
    or n == 318
    or n == 320
    or n == 322
    or n == 324
    or n == 326
    or n == 328
    or n == 330
    or n == 332
    or n == 334
    or n == 336
    or n == 338
    or n == 340
    or n == 342
    or n == 344
    or n == 346
    or n == 348
    or n == 350
    or n == 352
    or n == 354
    or n == 356
    or n == 358
    or n == 360
    or n == 362
    or n == 364
    or n == 366
    or n == 368
    or n == 370
    or n == 372
    or n == 374
    or n == 376
    or n == 378
    or n == 380
    or n == 382
    or n == 384
    or n == 386
    or n == 388
    or n == 390
    or n == 392
    or n == 394
    or n == 396
    or n == 398
    or n == 400
    or n == 402
    or n == 404
    or n == 406
    or n == 408
    or n == 410
    or n == 412
    or n == 414
    or n == 416
    or n == 418
    or n == 420
    or n == 422
    or n == 424
    or n == 426
    or n == 428
    or n == 430
    or n == 432
    or n == 434
    or n == 436
    or n == 438
    or n == 440
    or n == 442
    or n == 444
    or n == 446
    or n == 448
    or n == 450
    or n == 452
    or n == 454
    or n == 456
    or n == 458
    or n == 460
    or n == 462
    or n == 464
    or n == 466
    or n == 468
    or n == 470
    or n == 472
    or n == 474
    or n == 476
    or n == 478
    or n == 480
    or n == 482
    or n == 484
    or n == 486
    or n == 488
    or n == 490
    or n == 492
    or n == 494
    or n == 496
    or n == 498
    or n == 500
    or n == 502
    or n == 504
    or n == 506
    or n == 508
    or n == 510
    -- TODO
    -- or n == 512
    or n == 514
    or n == 516
    or n == 518
    or n == 520
    or n == 522
    or n == 524
    or n == 526
    or n == 528
    or n == 530
    or n == 532
    or n == 534
    or n == 536
    or n == 538
    or n == 540
    or n == 542
    or n == 544
    or n == 546
    or n == 548
    or n == 550
    or n == 552
    or n == 554
    or n == 556
    or n == 558
    or n == 560
    or n == 562
    or n == 564
    or n == 566
    or n == 568
    or n == 570
    or n == 572
    or n == 574
    or n == 576
    or n == 578
    or n == 580
    or n == 582
    or n == 584
    or n == 586
    or n == 588
    or n == 590
    or n == 592
    or n == 594
    or n == 596
    or n == 598
    or n == 600
    or n == 602
    or n == 604
    or n == 606
    or n == 608
    or n == 610
    or n == 612
    or n == 614
    or n == 616
    or n == 618
    or n == 620
    or n == 622
    or n == 624
    or n == 626
    or n == 628
    or n == 630
    or n == 632
    or n == 634
    or n == 636
    or n == 638
    or n == 640
    or n == 642
    or n == 644
    or n == 646
    or n == 648
    or n == 650
    or n == 652
    or n == 654
    or n == 656
    or n == 658
    or n == 660
    or n == 662
    or n == 664
    or n == 666
    or n == 668
    or n == 670
    or n == 672
    or n == 674
    or n == 676
    or n == 678
    or n == 680
    or n == 682
    or n == 684
    or n == 686
    or n == 688
    or n == 690
    or n == 692
    or n == 694
    or n == 696
    or n == 698
    or n == 700
    or n == 702
    or n == 704
    or n == 706
    or n == 708
    or n == 710
    or n == 712
    or n == 714
    or n == 716
    or n == 718
    or n == 720
    or n == 722
    or n == 724
    or n == 726
    or n == 728
    or n == 730
    or n == 732
    or n == 734
    or n == 736
    or n == 738
    or n == 740
    or n == 742
    or n == 744
    or n == 746
    or n == 748
    or n == 750
    or n == 752
    or n == 754
    or n == 756
    or n == 758
    or n == 760
    or n == 762
    or n == 764
    or n == 766
    or n == 768
    or n == 770
    or n == 772
    or n == 774
    or n == 776
    or n == 778
    or n == 780
    or n == 782
    or n == 784
    or n == 786
    or n == 788
    or n == 790
    or n == 792
    or n == 794
    or n == 796
    or n == 798
    or n == 800
    or n == 802
    or n == 804
    or n == 806
    or n == 808
    or n == 810
    or n == 812
    or n == 814
    or n == 816
    or n == 818
    or n == 820
    or n == 822
    or n == 824
    or n == 826
    or n == 828
    or n == 830
    or n == 832
    or n == 834
    or n == 836
    or n == 838
    or n == 840
    or n == 842
    or n == 844
    or n == 846
    or n == 848
    or n == 850
    or n == 852
    or n == 854
    or n == 856
    or n == 858
    or n == 860
    or n == 862
    or n == 864
    or n == 866
    or n == 868
    or n == 870
    or n == 872
    or n == 874
    or n == 876
    or n == 878
    or n == 880
    or n == 882
    or n == 884
    or n == 886
    or n == 888
    or n == 890
    or n == 892
    or n == 894
    or n == 896
    or n == 898
    or n == 900
    or n == 902
    or n == 904
    or n == 906
    or n == 908
    or n == 910
    or n == 912
    or n == 914
    or n == 916
    or n == 918
    or n == 920
    or n == 922
    or n == 924
    or n == 926
    or n == 928
    or n == 930
    or n == 932
    or n == 934
    or n == 936
    or n == 938
    or n == 940
    or n == 942
    or n == 944
    or n == 946
    or n == 948
    or n == 950
    or n == 952
    or n == 954
    or n == 956
    or n == 958
    or n == 960
    or n == 962
    or n == 964
    or n == 966
    or n == 968
    or n == 970
    or n == 972
    or n == 974
    or n == 976
    or n == 978
    or n == 980
    or n == 982
    or n == 984
    or n == 986
    or n == 988
    or n == 990
    or n == 992
    or n == 994
    or n == 996
    or n == 998
    or n == 1000
    or n == 1002
    or n == 1004
    or n == 1006
    or n == 1008
    or n == 1010
    or n == 1012
    or n == 1014
    or n == 1016
    or n == 1018
    or n == 1020
    or n == 1022
    or n == 1024
    or n == 1026
    or n == 1028
    or n == 1030
    or n == 1032
    or n == 1034
    or n == 1036
    or n == 1038
    or n == 1040
    or n == 1042
    or n == 1044
    or n == 1046
    or n == 1048
    or n == 1050
    or n == 1052
    or n == 1054
    or n == 1056
    or n == 1058
    or n == 1060
    or n == 1062
    or n == 1064
    or n == 1066
    or n == 1068
    or n == 1070
    or n == 1072
    or n == 1074
    or n == 1076
    or n == 1078
    or n == 1080
    or n == 1082
    or n == 1084
    or n == 1086
    or n == 1088
    or n == 1090
    or n == 1092
    or n == 1094
    or n == 1096
    or n == 1098
    or n == 1100
    or n == 1102
    or n == 1104
    or n == 1106
    or n == 1108
    or n == 1110
    or n == 1112
    or n == 1114
    or n == 1116
    or n == 1118
    or n == 1120
    or n == 1122
    or n == 1124
    or n == 1126
    or n == 1128
    or n == 1130
    or n == 1132
    or n == 1134
    or n == 1136
    or n == 1138
    or n == 1140
    or n == 1142
    or n == 1144
    or n == 1146
    or n == 1148
    or n == 1150
    or n == 1152
    or n == 1154
    or n == 1156
    or n == 1158
    or n == 1160
    or n == 1162
    or n == 1164
    or n == 1166
    or n == 1168
    or n == 1170
    or n == 1172
    or n == 1174
    or n == 1176
    or n == 1178
    or n == 1180
    or n == 1182
    or n == 1184
    or n == 1186
    or n == 1188
    or n == 1190
    or n == 1192
    or n == 1194
    or n == 1196
    or n == 1198
    or n == 1200
    or n == 1202
    or n == 1204
    or n == 1206
    or n == 1208
    or n == 1210
    or n == 1212
    or n == 1214
    or n == 1216
    or n == 1218
    or n == 1220
    or n == 1222
    or n == 1224
    or n == 1226
    or n == 1228
    or n == 1230
    or n == 1232
    or n == 1234
    or n == 1236
    or n == 1238
    or n == 1240
    or n == 1242
    or n == 1244
    or n == 1246
    or n == 1248
    or n == 1250
    or n == 1252
    or n == 1254
    or n == 1256
    or n == 1258
    or n == 1260
    or n == 1262
    or n == 1264
    or n == 1266
    or n == 1268
    or n == 1270
    or n == 1272
    or n == 1274
    or n == 1276
    or n == 1278
    or n == 1280
    or n == 1282
    or n == 1284
    or n == 1286
    or n == 1288
    or n == 1290
    or n == 1292
    or n == 1294
    or n == 1296
    or n == 1298
    or n == 1300
    or n == 1302
    or n == 1304
    or n == 1306
    or n == 1308
    or n == 1310
    or n == 1312
    or n == 1314
    or n == 1316
    or n == 1318
    or n == 1320
    or n == 1322
    or n == 1324
    or n == 1326
    or n == 1328
    or n == 1330
    or n == 1332
    or n == 1334
    or n == 1336
    or n == 1338
    or n == 1340
    or n == 1342
    or n == 1344
    or n == 1346
    or n == 1348
    or n == 1350
    or n == 1352
    or n == 1354
    or n == 1356
    or n == 1358
    or n == 1360
    or n == 1362
    or n == 1364
    -- TODO(ribru17): Support larger numbers. Once the mathematics community discovers the parity of
    -- numbers larger than 1364 we can add them to this list.
end

-- Use max 32-bit signed int value to avoid overflow on 32-bit systems. #31633
vim._maxint = 2 ^ 32 - 1

return vim
