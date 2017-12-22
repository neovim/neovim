
local util = {}

vim = vim or {}

util.split = function(s, sep, nMax, bRegexp)
  assert(sep ~= '')
  assert(nMax == nil or nMax >= 1)

  local aRecord = {}

  if s:len() > 0 then
    local bPlain = not bRegexp
    nMax = nMax or -1

    local nField, nStart = 1, 1
    local nFirst, nLast = s:find(sep, nStart, bPlain)
    while nFirst and nMax ~= 0 do
      aRecord[nField] = s:sub(nStart, nFirst - 1)
      nField = nField + 1
      nStart = nLast + 1
      nFirst, nLast = s:find(sep, nStart, bPlain)
      nMax = nMax - 1
    end

    aRecord[nField] = s:sub(nStart)
  end

  return aRecord
end
util.tostring = function(obj)
  local stringified = ''
  if type(obj) == 'table' then
    stringified = stringified .. '{'
    for k, v in pairs(obj) do
      stringified = stringified .. util.tostring(k) .. '=' .. util.tostring(v) .. ','
    end
    stringified = stringified .. '}'
  else
    stringified = tostring(obj)
  end

  return stringified
end
util.trim = function(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end
util.handle_uri = function(uri)
  local file_prefix = 'file://'
  if string.sub(uri, 1, #file_prefix) == file_prefix then
    return string.sub(uri, #file_prefix + 1, #uri)
  end

  return uri
end


-- Determine whether a Lua table can be treated as an array.
-- Returns:
--  true    A non-empty array
--  false   A non-empty table
--  nil     An empty table
util.is_array = function(table)
  local count = 0

  for k, _ in pairs(table) do
    if type(k) == "number" then
      count = count + 1
    else
      return false
    end
  end

  if count > 0 then
    return true
  else
    return nil
  end
end

return util
