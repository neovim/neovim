--- Shared functions
--    - Used by Nvim and tests
--    - Can run in vanilla Lua (do not require a running instance of Nvim)


-- Checks if a list-like (vector) table contains `value`.
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
--
--@see |extend()|
--
-- behavior: Decides what to do if a key is found in more than one map:
--           "error": raise an error
--           "keep":  use value from the leftmost map
--           "force": use value from the rightmost map
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

-- Flattens a list-like table: unrolls and appends nested tables to table `t`.
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
  tbl_contains = tbl_contains,
  tbl_extend = tbl_extend,
  tbl_flatten = tbl_flatten,
}
return module
