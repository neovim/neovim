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
  error()
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

local module = {
  deepcopy = deepcopy,
  tbl_contains = tbl_contains,
  tbl_extend = tbl_extend,
  tbl_flatten = tbl_flatten,
}
return module
