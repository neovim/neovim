--- TODO: This is implemented only for files now.
-- https://tools.ietf.org/html/rfc3986
-- https://tools.ietf.org/html/rfc2732
-- https://tools.ietf.org/html/rfc2396

local function _is_windows_fname(path)
  if not (path:find('^[A-Z]:') == nil) then
    return true
  end
  return false
end

local function _is_windows_file_uri(uri)
  if uri:gsub('^file://', ''):find('^/[A-Z]:') then
    return true
  end
  return false
end

local function _uri_decode(str)
  return vim.api.nvim_call_function(
    "substitute",
    { str, "%\\([a-fA-F0-9]\\{2}\\)", "\\=printf('%c', str2nr(submatch(1), 16))", "g" }
  )
end

local function _percent_encode_char(char)
  local nr = vim.api.nvim_call_function('char2nr', { char })
  return vim.api.nvim_call_function('printf', { '%%%02X', nr })
end

local function _uri_encode(text, rfc)
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
      function (char) return _percent_encode_char(char) end
    )
end

local function uri_from_fname(path)
  if _is_windows_fname(path) then
    local volume_path = vim.api.nvim_call_function('substitute', { path, '\\(^\\c[A-Z]:\\)\\(.*\\)', '\\1', '' })
    local fname = vim.api.nvim_call_function('substitute', { path, '\\(^\\c[A-Z]:\\)\\(.*\\)', '\\2', '' })

    path = volume_path.._uri_encode(vim.api.nvim_call_function('substitute', { fname, '\\', '/', 'g'}))
  else
    path = _uri_encode(path)
  end

  local uri = 'file:'

  if _is_windows_fname(path) then
    uri = uri..'///'
  else
    uri = uri..'//'
  end

  return uri..path
end

local function uri_from_bufnr(bufnr)
  return uri_from_fname(vim.api.nvim_buf_get_name(bufnr))
end

local function uri_to_fname (uri)
  if _is_windows_file_uri(uri) then
    uri = uri:gsub('^file:///', '')
    uri = uri:gsub('/', '\\')
  else
    uri = uri:gsub('^file://', '')
  end

  return _uri_decode(uri)
end

local module = {
  uri_from_fname = uri_from_fname,
  uri_from_bufnr = uri_from_bufnr,
  uri_to_fname = uri_to_fname,
}

return module
