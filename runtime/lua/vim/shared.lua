-- Functions shared by Nvim and its test-suite.
--
-- The singular purpose of this module is to share code with the Nvim
-- test-suite. If, in the future, Nvim itself is used to run the test-suite
-- instead of "vanilla Lua", these functions could move to src/nvim/lua/vim.lua


--- Returns a deep copy of the given object. Non-table objects are copied as
--- in a typical Lua assignment, whereas table objects are copied recursively.
---
--@param orig Table to copy
--@returns New table of copied keys and (nested) values.
local function deepcopy(orig)
  error(orig)
end
local function _id(v)
  return v
end
local deepcopy_funcs = {
  table = function(orig)
    local copy = {}
    for k, v in pairs(orig) do
      copy[deepcopy(k)] = deepcopy(v)
    end
    return copy
  end,
  number = _id,
  string = _id,
  ['nil'] = _id,
  boolean = _id,
}
deepcopy = function(orig)
  return deepcopy_funcs[type(orig)](orig)
end

--- Splits a string at each instance of a separator.
---
--@see |vim.split()|
--@see https://www.lua.org/pil/20.2.html
--@see http://lua-users.org/wiki/StringLibraryTutorial
---
--@param s String to split
--@param sep Separator string or pattern
--@param plain If `true` use `sep` literally (passed to String.find)
--@returns Iterator over the split components
local function gsplit(s, sep, plain)
  assert(type(s) == "string")
  assert(type(sep) == "string")
  assert(type(plain) == "boolean" or type(plain) == "nil")

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
    if done then
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
---  split(":aa::b:", ":")     --> {'','aa','','bb',''}
---  split("axaby", "ab?")     --> {'','x','y'}
---  split(x*yz*o, "*", true)  --> {'x','yz','o'}
--- </pre>
--
--@see |vim.gsplit()|
---
--@param s String to split
--@param sep Separator string or pattern
--@param plain If `true` use `sep` literally (passed to String.find)
--@returns List-like table of the split components.
local function split(s,sep,plain)
  local t={} for c in gsplit(s, sep, plain) do table.insert(t,c) end
  return t
end

--- Checks if a list-like (vector) table contains `value`.
---
--@param t Table to check
--@param value Value to compare
--@returns true if `t` contains `value`
local function tbl_contains(t, value)
  if type(t) ~= 'table' then
    error('t must be a table')
  end
  for _,v in ipairs(t) do
    if v == value then
      return true
    end
  end
  return false
end

--- Merges two or more map-like tables.
---
--@see |extend()|
---
--@param behavior Decides what to do if a key is found in more than one map:
---      - "error": raise an error
---      - "keep":  use value from the leftmost map
---      - "force": use value from the rightmost map
--@param ... Two or more map-like tables.
local function tbl_extend(behavior, ...)
  if (behavior ~= 'error' and behavior ~= 'keep' and behavior ~= 'force') then
    error('invalid "behavior": '..tostring(behavior))
  end
  local ret = {}
  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    if tbl then
      for k, v in pairs(tbl) do
        if behavior ~= 'force' and ret[k] ~= nil then
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

--- Creates a copy of a list-like table such that any nested tables are
--- "unrolled" and appended to the result.
---
--@param t List-like table
--@returns Flattened copy of the given list-like table.
local function tbl_flatten(t)
  -- From https://github.com/premake/premake-core/blob/master/src/base/table.lua
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

--- Trim whitespace (Lua pattern "%s") from both sides of a string.
---
--@see https://www.lua.org/pil/20.2.html
--@param s String to trim
--@returns String with whitespace removed from its beginning and end
local function trim(s)
  assert(type(s) == 'string', 'Only strings can be trimmed')
  return s:match('^%s*(.*%S)') or ''
end

--- Escapes magic chars in a Lua pattern string.
---
--@see https://github.com/rxi/lume
--@param s  String to escape
--@returns  %-escaped pattern string
local function pesc(s)
  assert(type(s) == 'string')
  return s:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%1')
end

local module = {
  deepcopy = deepcopy,
  gsplit = gsplit,
  pesc = pesc,
  split = split,
  tbl_contains = tbl_contains,
  tbl_extend = tbl_extend,
  tbl_flatten = tbl_flatten,
  trim = trim,
}
return module
