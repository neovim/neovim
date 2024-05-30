-- Functions shared by Nvim and its test-suite.
--
-- These are "pure" lua functions not depending of the state of the editor.
-- Thus they should always be available whenever nvim-related lua code is run,
-- regardless if it is code in the editor itself, or in worker threads/processes,
-- or the test suite. (Eventually the test suite will be run in a worker process,
-- so this wouldn't be a separate case to consider)

---@nodoc
---@diagnostic disable-next-line: lowercase-global
vim = vim or {}

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
    vim.validate({ s = { s, 's' }, sep = { sep, 's' }, opts = { opts, 't', true } })
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
  vim.validate({ func = { func, 'c' }, t = { t, 't' } })
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
  vim.validate({ func = { func, 'c' }, t = { t, 't' } })
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
  vim.validate({ t = { t, 't' }, opts = { opts, 't', true } })
  --- @cast t table<any,any>

  local pred --- @type fun(v: any): boolean?
  if opts and opts.predicate then
    vim.validate({ value = { value, 'c' } })
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

--- We only merge empty tables or tables that are not an array (indexed by integers)
local function can_merge(v)
  return type(v) == 'table' and (vim.tbl_isempty(v) or not vim.isarray(v))
end

local function tbl_extend(behavior, deep_extend, ...)
  if behavior ~= 'error' and behavior ~= 'keep' and behavior ~= 'force' then
    error('invalid "behavior": ' .. tostring(behavior))
  end

  if select('#', ...) < 2 then
    error(
      'wrong number of arguments (given '
        .. tostring(1 + select('#', ...))
        .. ', expected at least 3)'
    )
  end

  local ret = {} --- @type table<any,any>
  if vim._empty_dict_mt ~= nil and getmetatable(select(1, ...)) == vim._empty_dict_mt then
    ret = vim.empty_dict()
  end

  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    vim.validate('after the second argument', tbl, 'table')
    --- @cast tbl table<any,any>
    if tbl then
      for k, v in pairs(tbl) do
        if deep_extend and can_merge(v) and can_merge(ret[k]) then
          ret[k] = tbl_extend(behavior, true, ret[k], v)
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
  local keys = { ... }
  if #keys == 0 then
    return nil
  end
  for i, k in ipairs(keys) do
    o = o[k] --- @type any
    if o == nil then
      return nil
    elseif type(o) ~= 'table' and next(keys, i) then
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
  vim.validate({
    dst = { dst, 't' },
    src = { src, 't' },
    start = { start, 'n', true },
    finish = { finish, 'n', true },
  })
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
  --- @alias vim.validate.Type
  --- | 't' | 'table'
  --- | 's' | 'string'
  --- | 'n' | 'number'
  --- | 'f' | 'function'
  --- | 'c' | 'callable'
  --- | 'nil'
  --- | 'thread'
  --- | 'userdata

  local type_names = {
    ['table'] = 'table',
    t = 'table',
    ['string'] = 'string',
    s = 'string',
    ['number'] = 'number',
    n = 'number',
    ['boolean'] = 'boolean',
    b = 'boolean',
    ['function'] = 'function',
    f = 'function',
    ['callable'] = 'callable',
    c = 'callable',
    ['nil'] = 'nil',
    ['thread'] = 'thread',
    ['userdata'] = 'userdata',
  }

  --- @nodoc
  --- @class vim.validate.Spec {[1]: any, [2]: string|string[], [3]: boolean }
  --- @field [1] any Argument value
  --- @field [2] string|string[]|fun(v:any):boolean, string? Type name, or callable
  --- @field [3]? boolean

  local function _is_type(val, t)
    return type(val) == t or (t == 'callable' and vim.is_callable(val))
  end

  --- @param param_name string
  --- @param spec vim.validate.Spec
  --- @return string?
  local function is_param_valid(param_name, spec)
    if type(spec) ~= 'table' then
      return string.format('opt[%s]: expected table, got %s', param_name, type(spec))
    end

    local val = spec[1] -- Argument value
    local types = spec[2] -- Type name, or callable
    local optional = (true == spec[3])

    if type(types) == 'string' then
      types = { types }
    end

    if vim.is_callable(types) then
      -- Check user-provided validation function
      local valid, optional_message = types(val)
      if not valid then
        local error_message =
          string.format('%s: expected %s, got %s', param_name, (spec[3] or '?'), tostring(val))
        if optional_message ~= nil then
          error_message = string.format('%s. Info: %s', error_message, optional_message)
        end

        return error_message
      end
    elseif type(types) == 'table' then
      local success = false
      for i, t in ipairs(types) do
        local t_name = type_names[t]
        if not t_name then
          return string.format('invalid type name: %s', t)
        end
        types[i] = t_name

        if (optional and val == nil) or _is_type(val, t_name) then
          success = true
          break
        end
      end
      if not success then
        return string.format(
          '%s: expected %s, got %s',
          param_name,
          table.concat(types, '|'),
          type(val)
        )
      end
    else
      return string.format('invalid type name: %s', tostring(types))
    end
  end

  --- @param opt table<vim.validate.Type,vim.validate.Spec>
  --- @return boolean, string?
  local function is_valid(opt)
    if type(opt) ~= 'table' then
      return false, string.format('opt: expected table, got %s', type(opt))
    end

    local report --- @type table<string,string>?

    for param_name, spec in pairs(opt) do
      local msg = is_param_valid(param_name, spec)
      if msg then
        report = report or {}
        report[param_name] = msg
      end
    end

    if report then
      for _, msg in vim.spairs(report) do -- luacheck: ignore
        return false, msg
      end
    end

    return true
  end

  --- Validate function arguments.
  ---
  --- This function has two valid forms:
  ---
  --- 1. vim.validate(name: str, value: any, type: string, optional?: bool)
  --- 2. vim.validate(spec: table)
  ---
  --- Form 1 validates that argument {name} with value {value} has the type
  --- {type}. {type} must be a value returned by |lua-type()|. If {optional} is
  --- true, then {value} may be null. This form is significantly faster and
  --- should be preferred for simple cases.
  ---
  --- Example:
  ---
  --- ```lua
  --- function vim.startswith(s, prefix)
  ---   vim.validate('s', s, 'string')
  ---   vim.validate('prefix', prefix, 'string')
  ---   ...
  --- end
  --- ```
  ---
  --- Form 2 validates a parameter specification (types and values). Specs are
  --- evaluated in alphanumeric order, until the first failure.
  ---
  --- Usage example:
  ---
  --- ```lua
  --- function user.new(name, age, hobbies)
  ---   vim.validate{
  ---     name={name, 'string'},
  ---     age={age, 'number'},
  ---     hobbies={hobbies, 'table'},
  ---   }
  ---   ...
  --- end
  --- ```
  ---
  --- Examples with explicit argument values (can be run directly):
  ---
  --- ```lua
  --- vim.validate{arg1={{'foo'}, 'table'}, arg2={'foo', 'string'}}
  ---    --> NOP (success)
  ---
  --- vim.validate{arg1={1, 'table'}}
  ---    --> error('arg1: expected table, got number')
  ---
  --- vim.validate{arg1={3, function(a) return (a % 2) == 0 end, 'even number'}}
  ---    --> error('arg1: expected even number, got 3')
  --- ```
  ---
  --- If multiple types are valid they can be given as a list.
  ---
  --- ```lua
  --- vim.validate{arg1={{'foo'}, {'table', 'string'}}, arg2={'foo', {'table', 'string'}}}
  --- -- NOP (success)
  ---
  --- vim.validate{arg1={1, {'string', 'table'}}}
  --- -- error('arg1: expected string|table, got number')
  --- ```
  ---
  ---@param opt table<vim.validate.Type,vim.validate.Spec> (table) Names of parameters to validate. Each key is a parameter
  ---          name; each value is a tuple in one of these forms:
  ---          1. (arg_value, type_name, optional)
  ---             - arg_value: argument value
  ---             - type_name: string|table type name, one of: ("table", "t", "string",
  ---               "s", "number", "n", "boolean", "b", "function", "f", "nil",
  ---               "thread", "userdata") or list of them.
  ---             - optional: (optional) boolean, if true, `nil` is valid
  ---          2. (arg_value, fn, msg)
  ---             - arg_value: argument value
  ---             - fn: any function accepting one argument, returns true if and
  ---               only if the argument is valid. Can optionally return an additional
  ---               informative error message as the second returned value.
  ---             - msg: (optional) error string if validation fails
  --- @overload fun(name: string, val: any, expected: string, optional?: boolean)
  function vim.validate(opt, ...)
    local ok = false
    local err_msg ---@type string?
    local narg = select('#', ...)
    if narg == 0 then
      ok, err_msg = is_valid(opt)
    elseif narg >= 2 then
      -- Overloaded signature for fast/simple cases
      local name = opt --[[@as string]]
      local v, expected, optional = ... ---@type string, string, boolean?
      local actual = type(v)

      ok = (actual == expected) or (v == nil and optional == true)
      if not ok then
        err_msg = ('%s: expected %s, got %s%s'):format(
          name,
          expected,
          actual,
          v and (' (%s)'):format(v) or ''
        )
      end
    else
      error('invalid arguments')
    end

    if not ok then
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
  return type(m.__call) == 'function'
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
  return setmetatable({}, {
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

return vim
