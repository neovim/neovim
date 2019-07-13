local util = {
  quickfix = {},
}

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

return util
