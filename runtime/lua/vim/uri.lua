-- TODO: This is implemented only for files currently.
-- https://tools.ietf.org/html/rfc3986
-- https://tools.ietf.org/html/rfc2732
-- https://tools.ietf.org/html/rfc2396

local M = {}
local sbyte = string.byte
local schar = string.char
local tohex = require('bit').tohex
local URI_SCHEME_PATTERN = '^([a-zA-Z]+[a-zA-Z0-9.+-]*):.*'
local WINDOWS_URI_SCHEME_PATTERN = '^([a-zA-Z]+[a-zA-Z0-9.+-]*):[a-zA-Z]:.*'
local PATTERNS = {
  -- RFC 2396
  -- https://tools.ietf.org/html/rfc2396#section-2.2
  rfc2396 = "^A-Za-z0-9%-_.!~*'()",
  -- RFC 2732
  -- https://tools.ietf.org/html/rfc2732
  rfc2732 = "^A-Za-z0-9%-_.!~*'()[]",
  -- RFC 3986
  -- https://tools.ietf.org/html/rfc3986#section-2.2
  rfc3986 = "^A-Za-z0-9%-._~!$&'()*+,;=:@/",
}

---Converts hex to char
---@param hex string
---@return string
local function hex_to_char(hex)
  return schar(tonumber(hex, 16))
end

---@param char string
---@return string
local function percent_encode_char(char)
  return '%' .. tohex(sbyte(char), 2)
end

---@param uri string
---@return boolean
local function is_windows_file_uri(uri)
  return uri:match('^file:/+[a-zA-Z]:') ~= nil
end

---URI-encodes a string using percent escapes.
---@param str string string to encode
---@param rfc "rfc2396" | "rfc2732" | "rfc3986" | nil
---@return string encoded string
function M.uri_encode(str, rfc)
  local pattern = PATTERNS[rfc] or PATTERNS.rfc3986
  return (str:gsub('([' .. pattern .. '])', percent_encode_char)) -- clamped to 1 retval with ()
end

---URI-decodes a string containing percent escapes.
---@param str string string to decode
---@return string decoded string
function M.uri_decode(str)
  return (str:gsub('%%([a-fA-F0-9][a-fA-F0-9])', hex_to_char)) -- clamped to 1 retval with ()
end

---Gets a URI from a file path.
---@param path string Path to file
---@return string URI
function M.uri_from_fname(path)
  local volume_path, fname = path:match('^([a-zA-Z]:)(.*)') ---@type string?
  local is_windows = volume_path ~= nil
  if is_windows then
    path = volume_path .. M.uri_encode(fname:gsub('\\', '/'))
  else
    path = M.uri_encode(path)
  end
  local uri_parts = { 'file://' }
  if is_windows then
    table.insert(uri_parts, '/')
  end
  table.insert(uri_parts, path)
  return table.concat(uri_parts)
end

---Gets a URI from a bufnr.
---@param bufnr integer
---@return string URI
function M.uri_from_bufnr(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local volume_path = fname:match('^([a-zA-Z]:).*')
  local is_windows = volume_path ~= nil
  local scheme ---@type string?
  if is_windows then
    fname = fname:gsub('\\', '/')
    scheme = fname:match(WINDOWS_URI_SCHEME_PATTERN)
  else
    scheme = fname:match(URI_SCHEME_PATTERN)
  end
  if scheme then
    return fname
  else
    return M.uri_from_fname(fname)
  end
end

---Gets a filename from a URI.
---@param uri string
---@return string filename or unchanged URI for non-file URIs
function M.uri_to_fname(uri)
  local scheme = assert(uri:match(URI_SCHEME_PATTERN), 'URI must contain a scheme: ' .. uri)
  if scheme ~= 'file' then
    return uri
  end
  local fragment_index = uri:find('#')
  if fragment_index ~= nil then
    uri = uri:sub(1, fragment_index - 1)
  end
  uri = M.uri_decode(uri)
  --TODO improve this.
  if is_windows_file_uri(uri) then
    uri = uri:gsub('^file:/+', ''):gsub('/', '\\')
  else
    uri = uri:gsub('^file:/+', '/') ---@type string
  end
  return uri
end

---Gets the buffer for a uri.
---Creates a new unloaded buffer if no buffer for the uri already exists.
---@param uri string
---@return integer bufnr
function M.uri_to_bufnr(uri)
  return vim.fn.bufadd(M.uri_to_fname(uri))
end

return M
