--- TODO: This is implemented only for files now.
-- https://tools.ietf.org/html/rfc3986
-- https://tools.ietf.org/html/rfc2732
-- https://tools.ietf.org/html/rfc2396

local URI = {}

URI.__index = URI
URI.new = function(scheme, authority, path, query, fragment)
  local obj = setmetatable({
      scheme = scheme,
      authority = authority,
      path = path,
      query = query,
      fragment = fragment,
    }, URI)
  return obj
end

URI.tostring = function(self)
  local res = ''
  local scheme = self.scheme
  local authority = self.authority
  local path = self.path

  res = res..scheme..':'

  if authority or scheme == 'file'then
    if URI.is_windows_filepath(path) then
      res = res..'///'
    else
      res = res..'//'
    end
  end

  return res..path
end

URI.from_filepath = function(path)
  if URI.is_windows_filepath(path) then
    local volume_path = vim.api.nvim_call_function('substitute', { path, '\\(^\\c[A-Z]:\\)\\(.*\\)', '\\1', '' })
    local file_path = vim.api.nvim_call_function('substitute', { path, '\\(^\\c[A-Z]:\\)\\(.*\\)', '\\2', '' })

    path = volume_path..URI.encode(vim.api.nvim_call_function('substitute', { file_path, '\\', '/', 'g'}))
  else
    path = URI.encode(path)
  end

  return URI.new('file', nil, path, nil, nil)
end

URI.is_windows_filepath = function(path)
  if not (path:find('^[A-Z]:') == nil) then
    return true
  end
  return false
end

URI.is_windows_uri = function(uri)
  if uri:gsub('^file://', ''):find('^/[A-Z]:') then
    return true
  end
  return false
end

URI.from_bufnr = function(bufnr)
  if bufnr == nil then
    bufnr = vim.api.nvim_get_current_buf()
  end

  return URI.from_filepath(vim.api.nvim_buf_get_name(bufnr))
end


URI.filepath_from_uri = function(uri)
  if URI.is_windows_uri(uri) then
    uri = uri:gsub('^file:///', '')
    uri = uri:gsub('/', '\\')
  else
    uri = uri:gsub('^file://', '')
  end

  return URI.decode(uri)
end

URI.decode = function(str)
  return vim.api.nvim_call_function(
    "substitute",
    { str, "%\\([a-fA-F0-9]\\{2}\\)", "\\=printf('%c', str2nr(submatch(1), 16))", "g" }
  )
end

URI.encode = function(text, rfc)
    if not text then return end

    local pattern

    if rfc == 'rfc2396' then
      --- RFC 2396
      -- https://tools.ietf.org/html/rfc2396#section-2.2
      pattern = "^A-Za-z0-9%-_.!~*'()"
    elseif rfc == 'rfc2732' then
      --- RFC 2732
      -- https://tools.ietf.org/html/rfc2732
      pattern = "^A-Za-z0-9%-_.!~*'()[]"
    elseif rfc == 'rfc3986' or rfc == nil then
      --- RFC 3986
      -- https://tools.ietf.org/html/rfc3986#section-2.2
      pattern = "^A-Za-z0-9%-._~!$&'()*+,;=:@/"
    end

    return text:gsub(
      "([" .. pattern .. "])",
      function (char) return URI.percent_encode_char(char) end
    )
end

URI.percent_encode_char = function(char)
  local nr = vim.api.nvim_call_function('char2nr', { char })
  return vim.api.nvim_call_function('printf', { '%%%02X', nr })
end

return URI
