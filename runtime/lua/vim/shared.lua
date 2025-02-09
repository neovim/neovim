-- Functions shared by Nvim and its test-suite.
--
-- These are "pure" lua functions not depending of the state of the editor.
-- Thus they should always be available whenever nvim-related lua code is run,
-- regardless if it is code in the editor itself, or in worker threads/processes,
-- or the test suite. (Eventually the test suite will be run in a worker process,
-- so this wouldn't be a separate case to consider)

---@nodoc
_G.vim = _G.vim or {}

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
--- @see |lua-patterns|
--- @see https://www.lua.org/pil/20.2.html
--- @see http://lua-users.org/wiki/StringLibraryTutorial
---
--- @param s string String to split
--- @param sep string Separator or pattern
--- @param opts? vim.gsplit.Opts Keyword arguments |kwargs|:
--- @return fun():string? : Iterator over the split components
function vim.gsplit(s, sep, opts)
  local plain --- @type boolean?
  local trimempty = false
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

--- Apply a function to all values of a table.
---
---@generic T
---@param func fun(value: T): any Function
---@param t table<any, T> Table
---@return table : Table of transformed values
function vim.tbl_map(func, t)
  vim.validate('func', func, 'callable')
  vim.validate('t', t, 'table')
  --- @cast t table<any,any>

  local rettab = {} --- @type table<any,any>
  for k, v in pairs(t) do
    rettab[k] = func(v)
  end
  return rettab
end

--- Filter a table using a predicate function
---
---@generic T
---@param func fun(value: T): boolean (function) Function
---@param t table<any, T> (table) Table
---@return T[] : Table of filtered values
function vim.tbl_filter(func, t)
  vim.validate('func', func, 'callable')
  vim.validate('t', t, 'table')
  --- @cast t table<any,any>

  local rettab = {} --- @type table<any,any>
  for _, entry in pairs(t) do
    if func(entry) then
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
--- @param behavior 'error'|'keep'|'force'
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

--- @param behavior 'error'|'keep'|'force'
--- @param deep_extend boolean
--- @param ... table<any,any>
local function tbl_extend(behavior, deep_extend, ...)
  if behavior ~= 'error' and behavior ~= 'keep' and behavior ~= 'force' then
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
---@param behavior 'error'|'keep'|'force' Decides what to do if a key is found in more than one map:
---      - "error": raise an error
---      - "keep":  use value from the leftmost map
---      - "force": use value from the rightmost map
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
---@param behavior 'error'|'keep'|'force' Decides what to do if a key is found in more than one map:
---      - "error": raise an error
---      - "keep":  use value from the leftmost map
---      - "force": use value from the rightmost map
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

--- Index into a table (first argument) via string keys passed as subsequent arguments.
--- Return `nil` if the key does not exist.
---
--- Examples:
---
--- ```lua
--- vim.tbl_get({ key = { nested_key = true }}, 'key', 'nested_key') == true
--- vim.tbl_get({ key = {}}, 'key', 'nested_key') == nil
--- ```
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
  local keys = {}
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
---@param t? table
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
---@param t? table
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
---@see |lua-patterns|
---@see https://www.lua.org/pil/20.2.html
---@param s string String to trim
---@return string String with whitespace removed from its beginning and end
function vim.trim(s)
  vim.validate('s', s, 'string')
  return s:match('^%s*(.*%S)') or ''
end

--- Escapes magic chars in |lua-patterns|.
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
  --- @param message? string
  --- @param allow_alias? boolean Allow short type names: 'n', 's', 't', 'b', 'f', 'c'
  --- @return string?
  local function is_valid(param_name, val, validator, message, allow_alias)
    if type(validator) == 'string' then
      local expected = allow_alias and type_aliases[validator] or validator

      if not expected then
        return string.format('invalid type name: %s', validator)
      end

      if not is_type(val, expected) then
        return string.format('%s: expected %s, got %s', param_name, expected, type(val))
      end
    elseif vim.is_callable(validator) then
      -- Check user-provided validation function
      local valid, opt_msg = validator(val)
      if not valid then
        local err_msg =
          string.format('%s: expected %s, got %s', param_name, message or '?', tostring(val))

        if opt_msg then
          err_msg = string.format('%s. Info: %s', err_msg, opt_msg)
        end

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
  --- @param validator vim.validate.Validator
  ---   - (`string|string[]`): Any value that can be returned from |lua-type()| in addition to
  ---     `'callable'`: `'boolean'`, `'callable'`, `'function'`, `'nil'`, `'number'`, `'string'`, `'table'`,
  ---     `'thread'`, `'userdata'`.
  ---   - (`fun(val:any): boolean, string?`) A function that returns a boolean and an optional
  ---     string message.
  --- @param optional? boolean Argument is optional (may be omitted)
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
      vim.deprecate('vim.validate', 'vim.validate(name, value, validator, optional_or_msg)', '1.0')
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
---@param f any Any object
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

--- @private
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

--- @private
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
      res[sc][name] = res[sc][name] or vim[sc][name] or vim.NIL

      -- Always track global option value to properly restore later.
      -- This matters for at least `o` and `wo` (which might set either/both
      -- local and global option values).
      if sc ~= 'env' then
        res.go[name] = res.go[name] or vim.go[name]
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
--- @param x elem_or_list<T>?
--- @return T[]
function vim._ensure_list(x)
  if type(x) == 'table' then
    return x
  end
  return { x }
end

return vim
