-- https://tools.ietf.org/html/rfc3986
-- https://tools.ietf.org/html/rfc2732
-- https://tools.ietf.org/html/rfc2396
-- https://tools.ietf.org/html/rfc8089

local M = {}
local sbyte = string.byte
local schar = string.char
local tohex = require('bit').tohex
local iswin = package.config:sub(1, 1) == '\\'
local PATTERNS = {
  -- RFC 2396 https://tools.ietf.org/html/rfc2396#section-2.3
  rfc2396 = "^A-Za-z0-9%-_.!~*'()",
  -- RFC 2732 https://tools.ietf.org/html/rfc2732
  rfc2732 = "^A-Za-z0-9%-_.!~*'()%[%]",
  -- RFC 3986 https://tools.ietf.org/html/rfc3986#section-3.3
  rfc3986 = "^A-Za-z0-9%-._~!$&'()*+,;=:@/",
}

---Converts hex to char
---@param hex string
---@return string
local function hex_to_char(hex)
  return schar(vim._assert_integer(hex, 16))
end

---@param char string
---@return string
local function percent_encode_char(char)
  return '%' .. tohex(sbyte(char), 2)
end

local uri_mt = {
  --- @param uri vim.Uri
  --- @return string
  __tostring = function(uri)
    return ('%s:%s%s%s%s'):format(
      uri.scheme,
      uri.authority and ('//%s'):format(uri.authority) or '',
      uri.path,
      uri.query and ('?%s'):format(uri.query) or '',
      uri.fragment and ('#%s'):format(uri.fragment) or ''
    )
  end,
}

--- @class vim.Uri
---
--- Scheme, e.g. "https".
--- @field scheme string
---
--- Authority (after "//"), e.g. "user@example.com:8080". Empty for "file:///a", nil for "file:/a".
--- @field authority? string
---
--- Path, e.g. "/a/b". Empty for "https://example.com".
--- @field path string
---
--- Query (after "?"), e.g. "q=1".
--- @field query? string
---
--- Fragment (after "#"), e.g. "section".
--- @field fragment? string

--- Parses a URI into its RFC 3986 components, without decoding them. Unlike RFC 3986, a one-letter
--- scheme is a drive letter, so `C:/a` is not a URI.
---
--- Example:
---
--- ```lua
--- vim.uri.parse('https://example.com/a%20b?q=1#section')
--- --> { scheme = 'https', authority = 'example.com', path = '/a%20b', query = 'q=1', fragment = 'section' }
--- vim.uri.parse('/a/b') --> nil
--- vim.uri.parse('C:/a') --> nil
--- tostring(vim.uri.parse('file:///a?b')) --> 'file:///a?b'
--- ```
---
---@since 15
---@param uri string
---@return vim.Uri? # URI components, or nil if `uri` has no scheme.
function M.parse(uri)
  -- Requires 2+ chars, so drive letters ("C:/a") are not schemes.
  local scheme = uri:match('^(%a[%w+.-]+):')
  if not scheme then
    return nil
  end
  local rest = uri:sub(#scheme + 2)
  local fragment_i = rest:find('#', 1, true)
  local fragment = fragment_i and rest:sub(fragment_i + 1) or nil
  rest = rest:sub(1, (fragment_i or 0) - 1)
  local query_i = rest:find('?', 1, true)
  local query = query_i and rest:sub(query_i + 1) or nil
  rest = rest:sub(1, (query_i or 0) - 1)
  local authority, path = rest:match('^//([^/]*)(.*)$') --- @type string?, string?
  return setmetatable({
    scheme = scheme,
    authority = authority,
    path = path or rest,
    query = query,
    fragment = fragment,
  }, uri_mt)
end

---URI-encodes a string.
---@since 15
---@param str string string to encode
---@param rfc "rfc2396" | "rfc2732" | "rfc3986" | nil
---@return string encoded string
function M.encode(str, rfc)
  local pattern = PATTERNS[rfc] or PATTERNS.rfc3986
  return (str:gsub('([' .. pattern .. '])', percent_encode_char)) -- clamped to 1 retval with ()
end

---Decodes a URI-encoded string.
---@since 15
---@param str string string to decode
---@return string decoded string
function M.decode(str)
  return (str:gsub('%%([a-fA-F0-9][a-fA-F0-9])', hex_to_char)) -- clamped to 1 retval with ()
end

---Gets a URI from a file path. Relative paths are resolved to |current-directory| (RFC 8089
---disallows relative URIs).
---
---Example:
---
---```lua
---vim.uri.from_fname('/a b/c#') --> 'file:///a%20b/c%23'
---vim.uri.from_fname('C:\\a\\b') --> 'file:///C:/a/b'
---vim.uri.from_fname('//server/share/a') --> 'file://server/share/a' (UNC)
---vim.uri.from_fname('a') --> 'file:///home/user/a' (if CWD is "/home/user")
---```
---
---@since 15
---@param path string Path to file
---@return string URI
function M.from_fname(path)
  if iswin or path:find('^%a:') then
    path = path:gsub('\\', '/') ---@type string
  end
  if path ~= '' and not path:find('^/') and not path:find('^%a:') then
    path = vim.fs.normalize(vim.fs.abspath(path, { plain = true }), { plain = true }) -- Force absolute, RFC 8089 disallows relative.
  end
  local host = path:match('^//([^/]+)') ---@type string?
  if host then -- UNC path.
    return ('file://%s%s'):format(M.encode(host), M.encode(path:sub(#host + 3)))
  end
  local drive = path:match('^%a:') ---@type string?
  if drive then -- Windows drive letter.
    return ('file:///%s%s'):format(drive, M.encode(path:sub(3)))
  end
  return ('file://%s'):format(M.encode(path))
end

---Gets a URI from a buffer.
---@since 15
---@param buf integer
---@return string URI
function M.from_buf(buf)
  local fname = vim.api.nvim_buf_get_name(buf)
  if M.parse(fname) then
    return fname
  end
  return M.from_fname(fname)
end

---Gets a filename from a URI. Drops the query and fragment, so "?" and "#" in a filename must be
---percent-encoded.
---
---Example:
---
---```lua
---vim.uri.to_fname('file:///a%3Fb?c#d') --> '/a?b'
---vim.uri.to_fname('file:///C:/a/b') --> 'C:/a/b'
---vim.uri.to_fname('file://server/share/a') --> '//server/share/a'
---vim.uri.to_fname('jdt://a/b') --> 'jdt://a/b'
---```
---
---@since 15
---@param uri string
---@return string filename or unchanged URI for non-file URIs
function M.to_fname(uri)
  local parts = M.parse(uri)
  if not parts and uri:find('^%a:') then -- Drive letter: already a filename.
    return uri
  end
  parts = parts or error(('URI must contain a scheme: %s'):format(uri))
  if parts.scheme:lower() ~= 'file' then
    return uri
  end
  local host = M.decode(parts.authority or '')
  local path = M.decode(parts.path)
  if host:find('^%a:') then
    -- Drive letter, not a host (like WHATWG URL): "file://C:/a" => "C:/a".
    host, path = '', ('%s%s'):format(host, path)
  end
  -- Collapses leading slashes: "file:a" => "/a", "file:////a" => "/a".
  -- TODO(justinmk): Error on a relative path ("file:a"), like Rust `Url::to_file_path()`, unless
  -- LSP servers send those?
  path = path:gsub('^/*', '/') ---@type string
  -- TODO: On Windows, accessing "//host/…" connects to the host (and may send NTLM credentials).
  -- If users report it, allowlist hosts via a new option (like VS Code "security.allowedUNCHosts").
  if host ~= '' and host:lower() ~= 'localhost' then -- UNC path.
    return ('//%s%s'):format(host, path)
  end
  -- Drive letter: "/C:/a" => "C:/a".
  return path:match('^/(%a:.*)$') or path
end

---Gets the buffer for a uri.
---Creates a new unloaded buffer if no buffer for the uri already exists.
---@since 15
---@param uri string
---@return integer buf
function M.to_buf(uri)
  return vim.fn.bufadd(M.to_fname(uri))
end

return M
