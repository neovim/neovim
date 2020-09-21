--- TODO: This is implemented only for files now.
-- https://tools.ietf.org/html/rfc3986
-- https://tools.ietf.org/html/rfc2732
-- https://tools.ietf.org/html/rfc2396


local uri_decode
do
  local schar = string.char

  --- Convert hex to char
  --@private
  local function hex_to_char(hex)
    return schar(tonumber(hex, 16))
  end
  uri_decode = function(str)
    return str:gsub("%%([a-fA-F0-9][a-fA-F0-9])", hex_to_char)
  end
end

local uri_encode
do
  local PATTERNS = {
    --- RFC 2396
    -- https://tools.ietf.org/html/rfc2396#section-2.2
    rfc2396 = "^A-Za-z0-9%-_.!~*'()";
    --- RFC 2732
    -- https://tools.ietf.org/html/rfc2732
    rfc2732 = "^A-Za-z0-9%-_.!~*'()[]";
    --- RFC 3986
    -- https://tools.ietf.org/html/rfc3986#section-2.2
    rfc3986 = "^A-Za-z0-9%-._~!$&'()*+,;=:@/";
  }
  local sbyte, tohex = string.byte
  if jit then
    tohex = require'bit'.tohex
  else
    tohex = function(b) return string.format("%02x", b) end
  end

  --@private
  local function percent_encode_char(char)
    return "%"..tohex(sbyte(char), 2)
  end
  uri_encode = function(text, rfc)
    if not text then return end
    local pattern = PATTERNS[rfc] or PATTERNS.rfc3986
    return text:gsub("(["..pattern.."])", percent_encode_char)
  end
end


--@private
-- For test cases, uri is hard-coded.
-- So control the return value through a variable parameter
-- If we test a windows uri param is 0
local function is_windows(...)
  local arg = ... or 1
  if arg == 1 then
    return vim.loop.os_uname().sysname == "Windows"
  else
    return true
  end
end

--- Get a URI from a file path.
--@param path (string): Path to file
--@return URI
local function uri_from_fname(path,...)
  local volume_path, fname = path:match("^([a-zA-Z]:)(.*)")
  local eq_windows = is_windows(...)
  if eq_windows then
    path = volume_path..uri_encode(fname:gsub("\\", "/"))
  else
    path = uri_encode(path)
  end
  local uri_parts = {"file://"}
  if eq_windows then
    table.insert(uri_parts, "/")
  end
  table.insert(uri_parts, path)
  return table.concat(uri_parts)
end

local URI_SCHEME_PATTERN = '^([a-zA-Z]+[a-zA-Z0-9+-.]*)://.*'

--- Get a URI from a bufnr
--@param bufnr (number): Buffer number
--@return URI
local function uri_from_bufnr(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local scheme = fname:match(URI_SCHEME_PATTERN)
  if scheme then
    return fname
  else
    return uri_from_fname(fname)
  end
end

--- Get a filename from a URI
--@param uri (string): The URI
--@return Filename
local function uri_to_fname(uri,...)
  local scheme = assert(uri:match(URI_SCHEME_PATTERN), 'URI must contain a scheme: ' .. uri)
  if scheme ~= 'file' then
    return uri
  end
  uri = uri_decode(uri)

  if is_windows(...) then
    uri = uri:gsub('^file:///', '')
    uri = uri:gsub('/', '\\')
  else
    uri = uri:gsub('^file://', '')
  end
  return uri
end

--- Return or create a buffer for a uri.
--@param uri (string): The URI
--@return bufnr.
--@note Creates buffer but does not load it
local function uri_to_bufnr(uri)
  local scheme = assert(uri:match(URI_SCHEME_PATTERN), 'URI must contain a scheme: ' .. uri)
  if scheme == 'file' then
    return vim.fn.bufadd(uri_to_fname(uri))
  else
    return vim.fn.bufadd(uri)
  end
end

return {
  uri_from_fname = uri_from_fname,
  uri_from_bufnr = uri_from_bufnr,
  uri_to_fname = uri_to_fname,
  uri_to_bufnr = uri_to_bufnr,
}
-- vim:sw=2 ts=2 et
