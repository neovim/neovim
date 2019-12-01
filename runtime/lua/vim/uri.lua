--- TODO: This is implemented only for files now.
-- https://tools.ietf.org/html/rfc3986
-- https://tools.ietf.org/html/rfc2732
-- https://tools.ietf.org/html/rfc2396


local uri_decode
do
  local schar = string.char
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
  local function percent_encode_char(char)
    return "%"..tohex(sbyte(char), 2)
  end
  uri_encode = function(text, rfc)
    if not text then return end
    local pattern = PATTERNS[rfc] or PATTERNS.rfc3986
    return text:gsub("(["..pattern.."])", percent_encode_char)
  end
end


local function is_windows_file_uri(uri)
  return uri:match('^file:///[a-zA-Z]:') ~= nil
end

local function uri_from_fname(path)
  local volume_path, fname = path:match("^([a-zA-Z]:)(.*)")
  local is_windows = volume_path ~= nil
  if is_windows then
    path = volume_path..uri_encode(fname:gsub("\\", "/"))
  else
    path = uri_encode(path)
  end
  local uri_parts = {"file://"}
  if is_windows then
    table.insert(uri_parts, "/")
  end
  table.insert(uri_parts, path)
  return table.concat(uri_parts)
end

local function uri_from_bufnr(bufnr)
  return uri_from_fname(vim.api.nvim_buf_get_name(bufnr))
end

local function uri_to_fname(uri)
  -- TODO improve this.
  if is_windows_file_uri(uri) then
    uri = uri:gsub('^file:///', '')
    uri = uri:gsub('/', '\\')
  else
    uri = uri:gsub('^file://', '')
  end
  return uri_decode(uri)
end

-- Return or create a buffer for a uri.
local function uri_to_bufnr(uri)
  return vim.fn.bufadd((uri_to_fname(uri)))
end

return {
  uri_from_fname = uri_from_fname,
  uri_from_bufnr = uri_from_bufnr,
  uri_to_fname = uri_to_fname,
  uri_to_bufnr = uri_to_bufnr,
}
-- vim:sw=2 ts=2 et
