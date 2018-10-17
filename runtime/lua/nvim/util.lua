
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

util.is_filtetype_open_in_tab = function(filetype, checker)
  for _, buffer_id  in ipairs(vim.api.nvim_call_function('tabpagebuflist', {})) do
    if vim.api.nvim_buf_get_option(buffer_id, 'filetype') == filetype then
      if checker ~= nil and checker(buffer_id) then
        return true
      end
    end
  end

  return false
end

util.is_loclist_open = function()
  return util.is_filtetype_open_in_tab('qf', function(buffer_id)
    return (#vim.api.nvim_call_function('getloclist', { buffer_id }) ~= 0)
  end)
end

util.is_quickfix_open = function()
  return util.is_filtetype_open_in_tab('qf', function(buffer_id)
    return (#vim.api.nvim_call_function('getloclist', { buffer_id }) == 0)
  end)
end

util.table.is_empty = function(table)
  if table == nil then
    return true
  end

  if not table then
    return true
  end

  if type(table) ~= type({}) and type(table) ~= 'userdata' then
    return true
  end

  if table == {} then
    return true
  end

  return false
end

--- Combine the contents of two tables.
-- It will override existing values in t1 if they are already in t2.
--
-- @note: This does not modify t1. It returns a new table
-- @return: A new table with the combined contents of t1 and t2
util.table.combine = function(t1, t2)
  local t3 = {}

  util.table.merge(t3, t1)
  util.table.merge(t3, t2)

  return t3
end


--- Combine the contents of two tables.
-- It will override existing values in t1 if they are already in t2.
--
-- @note: This modifies t1.
util.table.merge = function(t1, t2)
  for k, v in pairs(t2) do
    t1[k] = v
  end

  return t1
end

--- Concatenate list t2 to the end of t1.
-- Only useful for lists with numberic indeces.
--
-- NOTE: It NOT modify t1
--
-- @returns: A new table with t1 concatenated with t2
util.table.chain = function(t1, t2)
  local t3 = {}

  util.table.extend(t3, t1)
  util.table.extend(t3, t2)

  return t3
end


--- Concatenate list t2 to the end of t1.
--
-- Only useful for lists with numberic indeces.
--
-- NOTE: It will modify table t1.
--
-- @returns: Modified t1
util.table.extend = function(t1, t2)
  if not util.table.is_empty(t2) then
    local len_t1 = #t1

    for i, v in ipairs(t2) do
      t1[len_t1 + i] = v
    end
  end

  return t1
end

return util
