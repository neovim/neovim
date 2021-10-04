-- Functions shared by Nvim and its test-suite.
--
-- The singular purpose of this module is to share code with the Nvim
-- test-suite. If, in the future, Nvim itself is used to run the test-suite
-- instead of "vanilla Lua", these functions could move to src/nvim/lua/vim.lua

local vim = vim or {}

--- Returns a deep copy of the given object. Non-table objects are copied as
--- in a typical Lua assignment, whereas table objects are copied recursively.
--- Functions are naively copied, so functions in the copied table point to the
--- same functions as those in the input table. Userdata and threads are not
--- copied and will throw an error.
---
---@param orig Table to copy
---@returns New table of copied keys and (nested) values.
function vim.deepcopy(orig) end  -- luacheck: no unused
vim.deepcopy = (function()
  local function _id(v)
    return v
  end

  local deepcopy_funcs = {
    table = function(orig)
      local copy = {}

      if vim._empty_dict_mt ~= nil and getmetatable(orig) == vim._empty_dict_mt then
        copy = vim.empty_dict()
      end

      for k, v in pairs(orig) do
        copy[vim.deepcopy(k)] = vim.deepcopy(v)
      end
      return copy
    end,
    number = _id,
    string = _id,
    ['nil'] = _id,
    boolean = _id,
    ['function'] = _id,
  }

  return function(orig)
    local f = deepcopy_funcs[type(orig)]
    if f then
      return f(orig)
    else
      error("Cannot deepcopy object of type "..type(orig))
    end
  end
end)()

--- Splits a string at each instance of a separator.
---
---@see |vim.split()|
---@see https://www.lua.org/pil/20.2.html
---@see http://lua-users.org/wiki/StringLibraryTutorial
---
---@param s String to split
---@param sep Separator string or pattern
---@param plain If `true` use `sep` literally (passed to String.find)
---@returns Iterator over the split components
function vim.gsplit(s, sep, plain)
  vim.validate{s={s,'s'},sep={sep,'s'},plain={plain,'b',true}}

  local start = 1
  local done = false

  local function _pass(i, j, ...)
    if i then
      assert(j+1 > start, "Infinite loop detected")
      local seg = s:sub(start, i - 1)
      start = j + 1
      return seg, ...
    else
      done = true
      return s:sub(start)
    end
  end

  return function()
    if done or (s == '' and sep == '') then
      return
    end
    if sep == '' then
      if start == #s then
        done = true
      end
      return _pass(start+1, start)
    end
    return _pass(s:find(sep, start, plain))
  end
end

--- Splits a string at each instance of a separator.
---
--- Examples:
--- <pre>
---  split(":aa::b:", ":")     --> {'','aa','','b',''}
---  split("axaby", "ab?")     --> {'','x','y'}
---  split("x*yz*o", "*", {plain=true})  --> {'x','yz','o'}
---  split("|x|y|z|", "|", {trimempty=true}) --> {'x', 'y', 'z'}
--- </pre>
---
---@see |vim.gsplit()|
---
---@param s String to split
---@param sep Separator string or pattern
---@param kwargs Keyword arguments:
---       - plain: (boolean) If `true` use `sep` literally (passed to string.find)
---       - trimempty: (boolean) If `true` remove empty items from the front
---         and back of the list
---@returns List-like table of the split components.
function vim.split(s, sep, kwargs)
  local plain
  local trimempty = false
  if type(kwargs) == 'boolean' then
    -- Support old signature for backward compatibility
    plain = kwargs
  else
    vim.validate { kwargs = {kwargs, 't', true} }
    kwargs = kwargs or {}
    plain = kwargs.plain
    trimempty = kwargs.trimempty
  end

  local t = {}
  local skip = trimempty
  for c in vim.gsplit(s, sep, plain) do
    if c ~= "" then
      skip = false
    end

    if not skip then
      table.insert(t, c)
    end
  end

  if trimempty then
    for i = #t, 1, -1 do
      if t[i] ~= "" then
        break
      end
      table.remove(t, i)
    end
  end

  return t
end

--- Return a list of all keys used in a table.
--- However, the order of the return table of keys is not guaranteed.
---
---@see From https://github.com/premake/premake-core/blob/master/src/base/table.lua
---
---@param t Table
---@returns list of keys
function vim.tbl_keys(t)
  assert(type(t) == 'table', string.format("Expected table, got %s", type(t)))

  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end

--- Return a list of all values used in a table.
--- However, the order of the return table of values is not guaranteed.
---
---@param t Table
---@returns list of values
function vim.tbl_values(t)
  assert(type(t) == 'table', string.format("Expected table, got %s", type(t)))

  local values = {}
  for _, v in pairs(t) do
    table.insert(values, v)
  end
  return values
end

--- Apply a function to all values of a table.
---
---@param func function or callable table
---@param t table
function vim.tbl_map(func, t)
  vim.validate{func={func,'c'},t={t,'t'}}

  local rettab = {}
  for k, v in pairs(t) do
    rettab[k] = func(v)
  end
  return rettab
end

--- Filter a table using a predicate function
---
---@param func function or callable table
---@param t table
function vim.tbl_filter(func, t)
  vim.validate{func={func,'c'},t={t,'t'}}

  local rettab = {}
  for _, entry in pairs(t) do
    if func(entry) then
      table.insert(rettab, entry)
    end
  end
  return rettab
end

--- Checks if a list-like (vector) table contains `value`.
---
---@param t Table to check
---@param value Value to compare
---@returns true if `t` contains `value`
function vim.tbl_contains(t, value)
  vim.validate{t={t,'t'}}

  for _,v in ipairs(t) do
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
---@param t Table to check
function vim.tbl_isempty(t)
  assert(type(t) == 'table', string.format("Expected table, got %s", type(t)))
  return next(t) == nil
end

--- we only merge empty tables or tables that are not a list
---@private
local function can_merge(v)
  return type(v) == "table" and (vim.tbl_isempty(v) or not vim.tbl_islist(v))
end

local function tbl_extend(behavior, deep_extend, ...)
  if (behavior ~= 'error' and behavior ~= 'keep' and behavior ~= 'force') then
    error('invalid "behavior": '..tostring(behavior))
  end

  if select('#', ...) < 2 then
    error('wrong number of arguments (given '..tostring(1 + select('#', ...))..', expected at least 3)')
  end

  local ret = {}
  if vim._empty_dict_mt ~= nil and getmetatable(select(1, ...)) == vim._empty_dict_mt then
    ret = vim.empty_dict()
  end

  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    vim.validate{["after the second argument"] = {tbl,'t'}}
    if tbl then
      for k, v in pairs(tbl) do
        if deep_extend and can_merge(v) and can_merge(ret[k]) then
          ret[k] = tbl_extend(behavior, true, ret[k], v)
        elseif behavior ~= 'force' and ret[k] ~= nil then
          if behavior == 'error' then
            error('key found in more than one map: '..k)
          end  -- Else behavior is "keep".
        else
          ret[k] = v
        end
      end
    end
  end
  return ret
end

--- Merges two or more map-like tables.
---
---@see |extend()|
---
---@param behavior Decides what to do if a key is found in more than one map:
---      - "error": raise an error
---      - "keep":  use value from the leftmost map
---      - "force": use value from the rightmost map
---@param ... Two or more map-like tables.
function vim.tbl_extend(behavior, ...)
  return tbl_extend(behavior, false, ...)
end

--- Merges recursively two or more map-like tables.
---
---@see |tbl_extend()|
---
---@param behavior Decides what to do if a key is found in more than one map:
---      - "error": raise an error
---      - "keep":  use value from the leftmost map
---      - "force": use value from the rightmost map
---@param ... Two or more map-like tables.
function vim.tbl_deep_extend(behavior, ...)
  return tbl_extend(behavior, true, ...)
end

--- Deep compare values for equality
---
--- Tables are compared recursively unless they both provide the `eq` methamethod.
--- All other types are compared using the equality `==` operator.
---@param a first value
---@param b second value
---@returns `true` if values are equals, else `false`.
function vim.deep_equal(a, b)
  if a == b then return true end
  if type(a) ~= type(b) then return false end
  if type(a) == 'table' then
    for k, v in pairs(a) do
      if not vim.deep_equal(v, b[k]) then
        return false
      end
    end
    for k, _ in pairs(b) do
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
--
--Do note that it *modifies* the input.
---@param o table The table to add the reverse to.
function vim.tbl_add_reverse_lookup(o)
  local keys = vim.tbl_keys(o)
  for _, k in ipairs(keys) do
    local v = o[k]
    if o[v] then
      error(string.format("The reverse lookup found an existing value for %q while processing key %q", tostring(v), tostring(k)))
    end
    o[v] = k
  end
  return o
end

--- Extends a list-like table with the values of another list-like table.
---
--- NOTE: This mutates dst!
---
---@see |vim.tbl_extend()|
---
---@param dst list which will be modified and appended to.
---@param src list from which values will be inserted.
---@param start Start index on src. defaults to 1
---@param finish Final index on src. defaults to #src
---@returns dst
function vim.list_extend(dst, src, start, finish)
  vim.validate {
    dst = {dst, 't'};
    src = {src, 't'};
    start = {start, 'n', true};
    finish = {finish, 'n', true};
  }
  for i = start or 1, finish or #src do
    table.insert(dst, src[i])
  end
  return dst
end

--- Creates a copy of a list-like table such that any nested tables are
--- "unrolled" and appended to the result.
---
---@see From https://github.com/premake/premake-core/blob/master/src/base/table.lua
---
---@param t List-like table
---@returns Flattened copy of the given list-like table.
function vim.tbl_flatten(t)
  local result = {}
  local function _tbl_flatten(_t)
    local n = #_t
    for i = 1, n do
      local v = _t[i]
      if type(v) == "table" then
        _tbl_flatten(v)
      elseif v then
        table.insert(result, v)
      end
    end
  end
  _tbl_flatten(t)
  return result
end

--- Tests if a Lua table can be treated as an array.
---
--- Empty table `{}` is assumed to be an array, unless it was created by
--- |vim.empty_dict()| or returned as a dict-like |API| or Vimscript result,
--- for example from |rpcrequest()| or |vim.fn|.
---
---@param t Table
---@returns `true` if array-like table, else `false`.
function vim.tbl_islist(t)
  if type(t) ~= 'table' then
    return false
  end

  local count = 0

  for k, _ in pairs(t) do
    if type(k) == "number" then
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
      return nil
    end
    return getmetatable(t) ~= vim._empty_dict_mt
  end
end

--- Counts the number of non-nil values in table `t`.
---
--- <pre>
--- vim.tbl_count({ a=1, b=2 }) => 2
--- vim.tbl_count({ 1, 2 }) => 2
--- </pre>
---
---@see https://github.com/Tieske/Penlight/blob/master/lua/pl/tablex.lua
---@param t Table
---@returns Number that is the number of the value in table
function vim.tbl_count(t)
  vim.validate{t={t,'t'}}

  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

--- Creates a copy of a table containing only elements from start to end (inclusive)
---
---@param list table table
---@param start integer Start range of slice
---@param finish integer End range of slice
---@returns Copy of table sliced from start to finish (inclusive)
function vim.list_slice(list, start, finish)
  local new_list = {}
  for i = start or 1, finish or #list do
    new_list[#new_list+1] = list[i]
  end
  return new_list
end

--- Trim whitespace (Lua pattern "%s") from both sides of a string.
---
---@see https://www.lua.org/pil/20.2.html
---@param s String to trim
---@returns String with whitespace removed from its beginning and end
function vim.trim(s)
  vim.validate{s={s,'s'}}
  return s:match('^%s*(.*%S)') or ''
end

--- Escapes magic chars in a Lua pattern.
---
---@see https://github.com/rxi/lume
---@param s  String to escape
---@returns  %-escaped pattern string
function vim.pesc(s)
  vim.validate{s={s,'s'}}
  return s:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%1')
end

--- Tests if `s` starts with `prefix`.
---
---@param s (string) a string
---@param prefix (string) a prefix
---@return (boolean) true if `prefix` is a prefix of s
function vim.startswith(s, prefix)
  vim.validate { s = {s, 's'}; prefix = {prefix, 's'}; }
  return s:sub(1, #prefix) == prefix
end

--- Tests if `s` ends with `suffix`.
---
---@param s (string) a string
---@param suffix (string) a suffix
---@return (boolean) true if `suffix` is a suffix of s
function vim.endswith(s, suffix)
  vim.validate { s = {s, 's'}; suffix = {suffix, 's'}; }
  return #suffix == 0 or s:sub(-#suffix) == suffix
end

--- Validates a parameter specification (types and values).
---
--- Usage example:
--- <pre>
---  function user.new(name, age, hobbies)
---    vim.validate{
---      name={name, 'string'},
---      age={age, 'number'},
---      hobbies={hobbies, 'table'},
---    }
---    ...
---  end
--- </pre>
---
--- Examples with explicit argument values (can be run directly):
--- <pre>
---  vim.validate{arg1={{'foo'}, 'table'}, arg2={'foo', 'string'}}
---     => NOP (success)
---
---  vim.validate{arg1={1, 'table'}}
---     => error('arg1: expected table, got number')
---
---  vim.validate{arg1={3, function(a) return (a % 2) == 0 end, 'even number'}}
---     => error('arg1: expected even number, got 3')
--- </pre>
---
---@param opt Map of parameter names to validations. Each key is a parameter
---          name; each value is a tuple in one of these forms:
---          1. (arg_value, type_name, optional)
---             - arg_value: argument value
---             - type_name: string type name, one of: ("table", "t", "string",
---               "s", "number", "n", "boolean", "b", "function", "f", "nil",
---               "thread", "userdata")
---             - optional: (optional) boolean, if true, `nil` is valid
---          2. (arg_value, fn, msg)
---             - arg_value: argument value
---             - fn: any function accepting one argument, returns true if and
---               only if the argument is valid. Can optionally return an additional
---               informative error message as the second returned value.
---             - msg: (optional) error string if validation fails
function vim.validate(opt) end  -- luacheck: no unused

do
  local type_names = {
    ['table']    = 'table',    t = 'table',
    ['string']   = 'string',   s = 'string',
    ['number']   = 'number',   n = 'number',
    ['boolean']  = 'boolean',  b = 'boolean',
    ['function'] = 'function', f = 'function',
    ['callable'] = 'callable', c = 'callable',
    ['nil']      = 'nil',
    ['thread']   = 'thread',
    ['userdata'] = 'userdata',
  }

  local function _is_type(val, t)
    return type(val) == t or (t == 'callable' and vim.is_callable(val))
  end

  local function is_valid(opt)
    if type(opt) ~= 'table' then
      return false, string.format('opt: expected table, got %s', type(opt))
    end

    for param_name, spec in pairs(opt) do
      if type(spec) ~= 'table' then
        return false, string.format('opt[%s]: expected table, got %s', param_name, type(spec))
      end

      local val = spec[1]   -- Argument value.
      local t = spec[2]     -- Type name, or callable.
      local optional = (true == spec[3])

      if type(t) == 'string' then
        local t_name = type_names[t]
        if not t_name then
          return false, string.format('invalid type name: %s', t)
        end

        if (not optional or val ~= nil) and not _is_type(val, t_name) then
          return false, string.format("%s: expected %s, got %s", param_name, t_name, type(val))
        end
      elseif vim.is_callable(t) then
        -- Check user-provided validation function.
        local valid, optional_message = t(val)
        if not valid then
          local error_message = string.format("%s: expected %s, got %s", param_name, (spec[3] or '?'), val)
          if optional_message ~= nil then
            error_message = error_message .. string.format(". Info: %s", optional_message)
          end

          return false, error_message
        end
      else
        return false, string.format("invalid type name: %s", tostring(t))
      end
    end

    return true, nil
  end

  function vim.validate(opt)
    local ok, err_msg = is_valid(opt)
    if not ok then
      error(debug.traceback(err_msg, 2), 2)
    end
  end
end
--- Returns true if object `f` can be called as a function.
---
---@param f Any object
---@return true if `f` is callable, else false
function vim.is_callable(f)
  if type(f) == 'function' then return true end
  local m = getmetatable(f)
  if m == nil then return false end
  return type(m.__call) == 'function'
end

return vim
-- vim:sw=2 ts=2 et
