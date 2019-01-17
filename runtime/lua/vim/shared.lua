--- Shared functions
--    - Used by Nvim and tests
--    - Can run in vanilla Lua (do not require a running instance of Nvim)


--- Merge map-like tables.
--
--@see |extend()|
--
-- behavior: Decides what to do if a key is found in more than one map:
--           "error": raise an error
--           "keep":  skip
--           "force": set the item again
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

local module = {
  tbl_extend = tbl_extend,
}
return module
