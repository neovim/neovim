--- TODO: This is implementted only for file now.
-- https://tools.ietf.org/html/rfc3986
-- https://tools.ietf.org/html/rfc2732
-- https://tools.ietf.org/html/rfc2396

local URI = {}

URI.__index = URI

URI.new = function(scheme, authority, path, query, fragment, is_win)
  local obj = setmetatable({
      scheme = scheme,
      authority = authority,
      path = path,
      query = query,
      fragment = fragment,
      is_win = is_win,
    }, URI)
  return obj
end

URI.from_filepath = function(path)
  local is_win = vim.api.nvim_call_function('has', { 'win32' }) == 1 or
    vim.api.nvim_call_function('has', { 'win64' }) == 1

  if is_win then
    local volume_path = vim.api.nvim_call_function('substitute', { path, '\\(^\\c[A-Z]:\\)\\(.*\\)', '\\1', '' })
    local file_path = vim.api.nvim_call_function('substitute', { path, '\\(^\\c[A-Z]:\\)\\(.*\\)', '\\2', '' })

    path = volume_path..URI.uri_encode(vim.api.nvim_call_function('substitute', { file_path, '\\', '/', 'g'}))
  else
    path = URI.uri_encode(path)
  end

  return URI.new('file', nil, path, nil, nil, is_win)
end

URI.from_bufnr = function(bufnr)
  if bufnr == nil then
    bufnr = vim.api.nvim_get_current_buf()
  end

  return URI.from_filepath(vim.api.nvim_buf_get_name(bufnr))
end

URI.tostring = function(self)
  local res = ''
  local scheme = self.scheme
  local authority = self.authority
  local path = self.path
  local is_win = self.is_win

  res = res..scheme..':'

  if authority or scheme == 'file'then
    if is_win then
      res = res..'//'
    else
      res = res..'///'
    end
  end

  return res..path
end

URI.filepath_from_uri = function(uri)
  local is_win = vim.api.nvim_call_function('has', { 'win32' }) == 1 or
    vim.api.nvim_call_function('has', { 'win64' }) == 1
  local encoded_filepath
  if is_win then
    encoded_filepath = vim.api.nvim_call_function('substitute', { uri, '^file:///', '', 'v' })
  else
    encoded_filepath = vim.api.nvim_call_function('substitute', { uri, '^file://', '', 'v' })
  end

  return URI.decode_uri_encode(encoded_filepath)
end

URI.decode_uri_encode = function(str)
  return vim.api.nvim_call_function(
    "substitute",
    { str, "%\\([a-fA-F0-9]\\{2}\\)", "\\=printf('%c', str2nr(submatch(1), 16))", "g" }
  )
end

URI.uri_encode = function(text, rfc)
    if not text then return end

    local pattern

    if rfc == 'rfc2396' then
      --- RFC 2396
      -- https://tools.ietf.org/html/rfc2396#section-2.2
      pattern = "^A-Za-z0-9%-_.!~*'()[]"
    elseif rfc == 'rfc2732' then
      --- RFC 2732
      -- https://tools.ietf.org/html/rfc2732
      pattern = "^A-Za-z0-9%-_.!~*'()"
    elseif rfc == 'rfc2732' or rfc == nil then
      --- RFC 3986
      -- https://tools.ietf.org/html/rfc3986#section-2.2
      pattern = "^A-Za-z0-9%-_.!~"
    end

    return text:gsub(
      "([" .. pattern .. "])",
      function (char) return URI.uri_encode_char(char) end
    )
end

URI.uri_encode_char = function(char)
  local nr = vim.api.nvim_call_function('char2nr', { char })
  return vim.api.nvim_call_function('printf', { '%%%02X', nr })
end

return URI
