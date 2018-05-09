
local util = {
  table = {},
}

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
  if type(table) ~= 'table' then
    return false
  end

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

util.get_file_line = function(file_name, line_number)
  local f = assert(io.open(file_name, 'r'))

  local count = 1
  for line in f:lines() do
    if count == line_number then
      f:close()
      return line
    end

    count = count + 1
  end

  return ''
end

util.get_key = function(table, ...)
  if type(table) ~= 'table' then
    return nil
  end

  local result = table
  for _, key in ipairs({...}) do
    result = result[key]

    if result == nil then
      return nil
    end
  end

  return result
end

util.is_loclist_open = function()
  for _, buffer_id  in ipairs(vim.api.nvim_call_function('tabpagebuflist', {})) do
    if vim.api.nvim_buf_get_option(buffer_id, 'filetype') == 'qf' then
      return true
    end
  end

  return false
end

util.table.is_empty = function(table)
  if table == nil then
    return true
  end

  if type(table) ~= type({}) then
    return true
  end

  if table == {} then
    return true
  end

  return false
end

util.table.combine = function(t1, t2)
  local t3 = {}

  util.table.merge(t3, t1)
  util.table.merge(t3, t2)

  return t3
end

util.table.merge = function(t1, t2)
  for k, v in pairs(t2) do
    t1[k] = v
  end

  return t1
end

util.table.chain = function(t1, t2)
  local len_t1 = #t1

  local t3 = {}
  for i, v in ipairs(t1) do
    t3[i] = v
  end

  if t2 == {} or t2 == nil then
    return t3
  end

  for i, v in ipairs(t2) do
    t3[len_t1 + i] = v
  end

  return t3
end

return util
