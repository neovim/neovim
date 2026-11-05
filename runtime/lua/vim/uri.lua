-- https://tools.ietf.org/html/rfc3986
-- https://tools.ietf.org/html/rfc2732
-- https://tools.ietf.org/html/rfc2396
-- https://tools.ietf.org/html/rfc8089

local M = {}
local sbyte = string.byte
local schar = string.char
local iswin = package.config:sub(1, 1) == '\\'
local PATTERNS = {
  -- RFC 2396 https://tools.ietf.org/html/rfc2396#section-2.3
  rfc2396 = "^A-Za-z0-9%-_.!~*'()",
  -- RFC 2732 https://tools.ietf.org/html/rfc2732
  rfc2732 = "^A-Za-z0-9%-_.!~*'()%[%]",
  -- RFC 3986 https://tools.ietf.org/html/rfc3986#section-3.3
  rfc3986 = "^A-Za-z0-9%-._~!$&'()*+,;=:@/",
}
-- Default ports of the WHATWG URL "special" schemes.
local default_ports = { ftp = 21, http = 80, https = 443, ws = 80, wss = 443 }
-- RFC 3986 "unreserved" and "sub-delims" chars (Lua pattern set).
local authority_chars = "A-Za-z0-9%-._~!$&'()*+,;="
-- Scheme (Lua pattern). Requires 2+ chars, so drive letters ("C:/a") are not schemes.
local scheme_pat = '%a[%w+.-]+'

--- Encodes a user, password, or host: keeps only `authority_chars`. Uses uppercase hex (RFC 3986
--- 2.1).
---@param s string
---@return string
local function encode_authority_part(s)
  return (
    s:gsub(('[^%s]'):format(authority_chars), function(c)
      return ('%%%02X'):format(sbyte(c))
    end)
  )
end

--- Checks that `s` has only `chars` (Lua pattern set), "%XX", and non-ASCII bytes (an unencoded
--- international name).
---@param s string
---@param chars string
---@return boolean
local function has_only(s, chars)
  return not s:gsub('%%%x%x', ''):find(('[^%s\128-\255]'):format(chars))
end

--- Gets the querystring of `uri`: `querystr`, else the encoded `query`.
---@param uri vim.Uri
---@return string?
local function query_string(uri)
  if uri.querystr or not (uri.query and next(uri.query)) then
    return uri.querystr
  end
  return M.encode_query(uri.query)
end

local uri_mt = {
  --- @param uri vim.Uri
  --- @return string
  __tostring = function(uri)
    local authority --- @type string?
    if uri.host then
      local password = uri.password and (':%s'):format(encode_authority_part(uri.password)) or ''
      local userinfo = uri.user and ('%s%s@'):format(encode_authority_part(uri.user), password)
        or ''
      -- IPv6 in brackets, "%" of a zone ID encoded: "fe80::1%en0" => "[fe80::1%25en0]".
      local host = uri.host:find(':', 1, true) and ('[%s]'):format((uri.host:gsub('%%', '%%25')))
        or encode_authority_part(uri.host)
      local port = uri.port and (':%d'):format(uri.port) or ''
      authority = ('%s%s%s'):format(userinfo, host, port)
    end
    local query = query_string(uri)
    return ('%s:%s%s%s%s'):format(
      uri.scheme,
      authority and ('//%s'):format(authority) or '',
      uri.path,
      query and ('?%s'):format(query) or '',
      uri.fragment and ('#%s'):format(uri.fragment) or ''
    )
  end,
  --- @param a vim.Uri
  --- @param b vim.Uri
  --- @return boolean
  __eq = function(a, b)
    return tostring(a) == tostring(b)
  end,
}

--- Creates a |vim.Uri| from unvalidated fields.
---@param fields vim.Uri `path` defaults to "".
---@return vim.Uri
local function _new(fields)
  return setmetatable({
    -- Lowercase, as specified by RFC.
    scheme = fields.scheme:lower(),
    user = fields.user,
    password = fields.password,
    host = fields.host and fields.host:lower(),
    port = fields.port,
    path = fields.path or '',
    query = fields.query,
    querystr = fields.querystr,
    fragment = fields.fragment,
  }, uri_mt)
end

--- Parses a URI reference (URI or relative reference, RFC 3986 4.1) into |vim.Uri| fields, with a
--- nil `scheme` for a relative reference: "../a?q" => `{ path = "../a", querystr = "q", … }`.
---@param ref string
---@return vim.Uri? # Fields, or nil if the authority is invalid.
local function parse_ref(ref)
  -- Splits (RFC 3986 Appendix B).
  local scheme = ref:match(('^(%s):'):format(scheme_pat)) --- @type string?
  local rest = scheme and ref:sub(#scheme + 2) or ref
  local fragment_i = rest:find('#', 1, true)
  local fragment = fragment_i and rest:sub(fragment_i + 1) or nil
  rest = rest:sub(1, (fragment_i or 0) - 1)
  local query_i = rest:find('?', 1, true)
  local query = query_i and rest:sub(query_i + 1) or nil
  rest = rest:sub(1, (query_i or 0) - 1)
  local authority, path = rest:match('^//([^/]*)(.*)$') --- @type string?, string?
  path = path or rest

  -- Exception: a drive letter in the host position is not a host (like WHATWG URL):
  -- "file://C:/a" => host "", path "/C:/a". But "file://h:22/a" has a port.
  local decoded = scheme and scheme:lower() == 'file' and authority and M.decode(authority) or ''
  if decoded:find('^%a:$') or decoded:find('^%a:\\') then
    authority, path = '', ('/%s%s'):format(authority, path)
  end

  local user, password, host, port --- @type string?, string?, string?, integer?
  if authority then
    local userinfo, hostport = authority:match('^(.*)@(.*)$') --- @type string?, string?
    hostport = hostport or authority
    -- IP literal in brackets: "[::1]:22" => "[::1]", ":22".
    local h, tail = hostport:match('^(%b[])(.*)$') --- @type string?, string?
    if not h then
      h, tail = hostport:match('^([^:]*)(.*)$')
    end
    ---@cast h string
    ---@cast tail string
    local p = tail:match('^:(%d*)$') --- @type string?
    local ip = h:match('^%[(.*)%]$') --- @type string?
    port = vim._tointeger(p)

    -- Validation
    if
      not (tail == '' or p)
      or (port and port > 65535)
      or (userinfo and not has_only(userinfo, ('%s:'):format(authority_chars)))
      -- IPv6, with zone ID ("fe80::1%25en0"), or IPvFuture ("v1.x").
      or (ip and not (ip:find('^[%x:.]+$') or ip:find('^[%x:.]+%%25.') or ip:find('^v%x+%.')))
      or (not ip and not has_only(h, authority_chars))
    then
      return nil
    end

    if userinfo then
      local u, pw = userinfo:match('^([^:]*):(.*)$') --- @type string?, string?
      user, password = M.decode(u or userinfo), pw and M.decode(pw)
    end
    -- Drops IPv6 brackets: "[::1]" => "::1".
    host = M.decode(ip or h)
  end
  return {
    scheme = scheme,
    user = user,
    password = password,
    host = host,
    port = port,
    path = path,
    query = query and M.decode_query(query),
    querystr = query,
    fragment = fragment,
  } --[[@as vim.Uri]]
end

--- URI components (see |vim.uri.parse()|). `tostring()` gives the URI as a string. Can be compared
--- for equality (`==`):
---
--- ```lua
--- vim.uri.parse('HTTP://h/a') == vim.uri.new({ scheme = 'http', host = 'h', path = '/a' }) --> true
--- ```
---
--- @class vim.Uri
---
--- Scheme (lowercase): "HTTPS://example.com" => "https".
--- @field scheme string
---
--- User (URI-decoded): "ssh://a%40b@host" => "a@b".
--- @field user? string
---
--- Password (URI-decoded): "https://u:p%40ss@host" => "p@ss".
--- @field password? string
---
--- Host (lowercase, URI-decoded): `ssh://Me@[::1]:22` => "::1", "https://Example.com" =>
--- "example.com". Empty for "file:///a", nil for "file:/a".
--- @field host? string
---
--- Port: "https://example.com:8080" => 8080.
--- @field port? integer
---
--- Path (URI-encoded): "https://h/a%20b" => "/a%20b". Empty for "https://h".
--- @field path string
---
--- Query (decoded by |vim.uri.decode_query()|): "https://h?q=a+b" => `{ q = "a b" }`.
--- @field query? table<string, string|string[]>
---
--- Querystring (URI-encoded): "https://h?q=a+b" => "q=a+b". Takes precedence over `query` in
--- `tostring()`.
--- @field querystr? string
---
--- Fragment (URI-encoded): "https://h#a%20b" => "a%20b".
--- @field fragment? string

--- Parses a URI into its RFC 3986 components. Exception: a one-letter scheme is a drive letter, "C:/a" is not a URI.
---
--- Example:
---
--- ```lua
--- vim.uri.parse('https://u:p%40ss@example.com:80/a%20b?q=1#section')
--- --> { scheme = 'https', user = 'u', password = 'p@ss', host = 'example.com', port = 80,
---      path = '/a%20b', query = { q = '1' }, querystr = 'q=1', fragment = 'section' }
--- vim.uri.parse('/a/b') --> nil
--- vim.uri.parse('C:/a') --> nil
--- vim.uri.parse('https://h:x') --> nil
---
--- -- tostring() builds the URI from the fields.
--- local u = vim.uri.parse('https://example.com/a')
--- u.host, u.port = '::1', 8080
--- tostring(u) --> 'https://[::1]:8080/a'
--- ```
---
---@since 15
---@param uri string
---@return vim.Uri? # URI components, or nil if invalid.
function M.parse(uri)
  local fields = parse_ref(uri)
  return fields and fields.scheme and _new(fields) or nil
end

--- Creates a |vim.Uri| from components.
---
--- Example:
---
--- ```lua
--- tostring(vim.uri.new({ scheme = 'https', host = '::1', port = 8080, path = '/a' }))
--- --> 'https://[::1]:8080/a'
--- tostring(vim.uri.new({ scheme = 'https', host = 'h', path = '/s', query = { q = 'a b' } }))
--- --> 'https://h/s?q=a+b'
--- ```
---
---@since 15
---@param uri vim.Uri `path` defaults to "".
---@return vim.Uri
function M.new(uri)
  vim.validate('uri', uri, 'table')
  vim.validate('uri.scheme', uri.scheme, 'string')
  vim.validate('uri.port', uri.port, 'number', true)
  vim.validate('uri.query', uri.query, 'table', true)
  for _, k in ipairs({ 'user', 'password', 'host', 'path', 'querystr', 'fragment' }) do
    vim.validate(('uri.%s'):format(k), uri[k], 'string', true)
  end
  local u = _new(uri)
  u.query = u.query or (u.querystr and M.decode_query(u.querystr))
  return u
end

--- Removes "." and ".." segments (RFC 3986 5.2.4): "/a/./b/../c" => "/a/c".
---@param path string
---@return string
local function remove_dot_segments(path)
  local out = {} --- @type string[]
  while path ~= '' do
    local dots = path:match('^%.%.?/') --- @type string?
    if dots then
      path = path:sub(#dots + 1)
    elseif path == '/.' or path:find('^/%./') then
      path = ('/%s'):format(path:sub(4))
    elseif path == '/..' or path:find('^/%.%./') then
      path = ('/%s'):format(path:sub(5))
      out[#out] = nil
    elseif path == '.' or path == '..' then
      path = ''
    else
      local segment = path:match('^/?[^/]*') --[[@as string]]
      out[#out + 1] = segment
      path = path:sub(#segment + 1)
    end
  end
  return table.concat(out)
end

--- Appends path segments to the path of `base`, like |vim.fs.joinpath()|, and removes "." and ".."
--- segments, but never above the root or a Windows drive letter. Each segment is URI-encoded, so
--- "#" or "?" in a file name is part of the path.
---
--- Example:
---
--- ```lua
--- tostring(vim.uri.join('file:///home/u/proj', 'src', 'a#1.lua'))
--- --> 'file:///home/u/proj/src/a%231.lua'
--- tostring(vim.uri.join('file:///C:/a', '../../x')) --> 'file:///C:/x'
--- tostring(vim.uri.join('https://h/api/?v=1', 'users/')) --> 'https://h/api/users/?v=1'
--- vim.uri.join('file:///a', 'file:///b') --> error: a segment can't be a URI
--- ```
---
---@since 15
---@param base string|vim.Uri
---@param ... string Path segments (not URI-encoded), not URIs.
---@return vim.Uri
function M.join(base, ...)
  vim.validate('base', base, { 'string', 'table' })
  local u = type(base) == 'table' and _new(base)
    or M.parse(base --[[@as string]])
    or error(('Invalid URI: %s'):format(base))
  local path = u.path
  for i = 1, select('#', ...) do
    local segment = select(i, ...) --- @type string
    vim.validate('segment', segment, 'string')
    if segment:find(('^%s://'):format(scheme_pat)) then
      error(('Segment is a URI: %s'):format(segment))
    end
    path = ('%s/%s'):format(path, M.encode(segment))
  end
  path = path:gsub('/+', '/')
  -- Keeps a drive letter as the root: "/C:/a/../.." => "/C:/".
  local drive = u.scheme == 'file' and path:match('^/%a:') or ''
  u.path = ('%s%s'):format(drive, remove_dot_segments(path:sub(#drive + 1)))
  return u
end

--- Normalizes percent-encoding (RFC 3986 6.2.2.2): decodes "unreserved" chars, and uppercases the
--- hex of others: "%7e%2f" => "~%2F".
---@param s string
---@return string
local function normalize_percent(s)
  return (
    s:gsub('%%(%x%x)', function(hex)
      local c = schar(vim._assert_integer(hex, 16))
      return c:find('^[A-Za-z0-9%-._~]$') and c or ('%%%s'):format(hex:upper())
    end)
  )
end

--- Normalizes `uri` (RFC 3986 6), so equivalent URIs are equal (`==`). Besides the normalizations
--- of |vim.uri.parse()| and `tostring()`, it normalizes percent-encoding, removes "." and ".."
--- segments, and drops a default port.
---
--- Example:
---
--- ```lua
--- tostring(vim.uri.normalize('HTTPS://Example.COM:443/a/./b/../%7e%2f'))
--- --> 'https://example.com/a/~%2F'
--- vim.uri.normalize('HTTP://h:80') == vim.uri.normalize('http://h/') --> true
--- ```
---
---@since 15
---@param uri string|vim.Uri
---@return vim.Uri
function M.normalize(uri)
  vim.validate('uri', uri, { 'string', 'table' })
  local u = type(uri) == 'table' and _new(uri)
    or M.parse(uri --[[@as string]])
    or error(('Invalid URI: %s'):format(uri))
  -- "file://localhost/a" => "file:///a" (RFC 8089 2).
  if u.scheme == 'file' and u.host == 'localhost' then
    u.host = ''
  end
  local default_port = default_ports[u.scheme]
  u.port = u.port ~= default_port and u.port or nil
  u.path = normalize_percent(u.path)
  if u.path:find('^/') then
    u.path = remove_dot_segments(u.path)
  elseif u.host and u.path == '' and default_port then
    -- Empty path of a "special" scheme: "http://h" => "http://h/".
    u.path = '/'
  end
  local querystr = query_string(u)
  u.querystr = querystr and normalize_percent(querystr)
  u.fragment = u.fragment and normalize_percent(u.fragment)
  return u
end

--- URI-encodes (percent-encodes) a string. For a querystring, use |vim.uri.encode_query()|.
---
--- Example:
---
--- ```lua
--- vim.uri.encode('/a b?') --> '/a%20b%3f'
--- vim.uri.encode('/a b?', 'rfc2396') --> '%2fa%20b%3f'
--- ```
---
---@since 15
---@param str string Arbitrary string.
---@param rfc? "rfc2396"|"rfc2732"|"rfc3986" Chars to keep:
---   - "rfc2396": only `A-Za-z0-9-_.!~*'()`.
---   - "rfc2732": "rfc2396" plus `[` and `]`.
---   - "rfc3986" (default): those valid in a path, e.g. "/", ":", "@", "&", "=".
---@return string # URI-encoded string.
function M.encode(str, rfc)
  local pattern = PATTERNS[rfc] or PATTERNS.rfc3986
  -- TODO(justinmk): Uppercase hex (RFC 3986 2.1), like `encode_authority_part()`? Would change
  -- `from_fname()` URIs of non-ASCII paths sent to LSP servers.
  return (
    str:gsub(('[%s]'):format(pattern), function(c)
      return ('%%%02x'):format(sbyte(c))
    end)
  )
end

--- Encodes `params` as a querystring (`application/x-www-form-urlencoded`, as HTML forms send it):
--- space is "+", and a list value repeats its key. Sorts the keys.
---
--- Example:
---
--- ```lua
--- vim.uri.encode_query({ q = 'a b&c', tag = { 'x', 'y' }, n = 1 })
--- --> 'n=1&q=a+b%26c&tag=x&tag=y'
--- ```
---
---@since 15
---@param params table<string, string|number|boolean|(string|number|boolean)[]>
---@return string
function M.encode_query(params)
  vim.validate('params', params, 'table')
  -- Keeps only the chars that HTML forms keep: "a b&c" => "a+b%26c".
  local function encode(s)
    local encoded = tostring(s):gsub('[^A-Za-z0-9*%-._ ]', function(c)
      return ('%%%02X'):format(sbyte(c))
    end)
    return (encoded:gsub(' ', '+'))
  end
  local keys = vim.tbl_keys(params)
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  local items = {} --- @type string[]
  for _, k in ipairs(keys) do
    local v = params[k]
    for _, item in ipairs(type(v) == 'table' and v or { v }) do
      items[#items + 1] = ('%s=%s'):format(encode(k), encode(item))
    end
  end
  return table.concat(items, '&')
end

--- Decodes a querystring (`application/x-www-form-urlencoded`, as HTML forms send it): "+" is
--- space, and a repeated key gives a list.
---
--- Example:
---
--- ```lua
--- vim.uri.decode_query('q=a+b%26c&tag=x&tag=y&flag')
--- --> { q = 'a b&c', tag = { 'x', 'y' }, flag = '' }
--- ```
---
---@since 15
---@param query string? Querystring, e.g. a form body.
---@return table<string, string|string[]>
function M.decode_query(query)
  vim.validate('query', query, 'string', true)
  local params = {} --- @type table<string, string|string[]>
  for pair in (query or ''):gmatch('[^&]+') do
    pair = pair:gsub('%+', ' ')
    local eq_i = pair:find('=', 1, true)
    local k = M.decode(pair:sub(1, (eq_i or 0) - 1))
    local v = M.decode(eq_i and pair:sub(eq_i + 1) or '')
    local prev = params[k]
    if prev == nil then
      params[k] = v
    elseif type(prev) == 'table' then
      prev[#prev + 1] = v
    else
      params[k] = { prev, v }
    end
  end
  return params
end

---Decodes a URI-encoded string. (Use |vim.uri.parse()| to get the structured form.)
---@since 15
---@param str string URI-encoded string.
---@return string # Decoded string.
function M.decode(str)
  return (str:gsub('%%(%x%x)', function(hex)
    return schar(vim._assert_integer(hex, 16))
  end))
end

---Gets a URI from a file path, or returns `path` if already a URI. Relative paths are resolved to
---|current-directory| (RFC 8089 disallows relative URIs).
---
---Example:
---
---```lua
---vim.uri.from_fname('/a b/c#') --> 'file:///a%20b/c%23'
---vim.uri.from_fname('C:\\a\\b') --> 'file:///C:/a/b'
---vim.uri.from_fname('//server/share/a') --> 'file://server/share/a' (UNC)
---vim.uri.from_fname('a') --> 'file:///home/user/a' (if CWD is "/home/user")
---vim.uri.from_fname('jdt://a/b') --> 'jdt://a/b'
---```
---
---@since 15
---@param path string Path to file
---@return string URI
function M.from_fname(path)
  if M.parse(path) then
    return path
  end
  if iswin or path:find('^%a:') then
    path = path:gsub('\\', '/') ---@type string
  end
  if path ~= '' and not path:find('^/') and not path:find('^%a:') then
    path = vim.fs.normalize(vim.fs.abspath(path, { plain = true }), { plain = true }) -- Force absolute, RFC 8089 disallows relative.
  end
  local host = path:match('^//([^/]+)') ---@type string?
  if host then -- UNC path.
    path = path:sub(#host + 3)
  elseif path:find('^%a:') then -- Windows drive letter.
    path = ('/%s'):format(path)
  end
  return tostring(_new({ scheme = 'file', host = host or '', path = M.encode(path) }))
end

---Gets a URI from a buffer.
---@since 15
---@param buf integer
---@return string URI
function M.from_buf(buf)
  return M.from_fname(vim.api.nvim_buf_get_name(buf))
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
---@param uri string|vim.Uri
---@return string filename or unchanged URI for non-file URIs
function M.to_fname(uri)
  local parts = type(uri) == 'table' and uri or M.parse(uri --[[@as string]])
  if not parts then
    local str = uri --[[@as string]]
    if not str:find('^%a:') then
      error(('Invalid URI: %s'):format(str))
    end
    return str -- Drive letter: already a filename.
  end
  if parts.scheme ~= 'file' then
    return tostring(uri)
  end
  local host = parts.host or ''
  local path = M.decode(parts.path)
  -- Collapses leading slashes: "file:a" => "/a", "file:////a" => "/a".
  -- TODO(justinmk): Error on a relative path ("file:a"), like Rust `Url::to_file_path()`, unless
  -- LSP servers send those?
  path = path:gsub('^/*', '/') ---@type string
  -- TODO: On Windows, accessing "//host/…" connects to the host (and may send NTLM credentials).
  -- If users report it, allowlist hosts via a new option (like VS Code "security.allowedUNCHosts").
  if host ~= '' and host ~= 'localhost' then -- UNC path.
    return ('//%s%s'):format(host, path)
  end
  -- Drive letter: "/C:/a" => "C:/a".
  return path:match('^/(%a:.*)$') or path
end

---Gets the buffer for a uri.
---Creates a new unloaded buffer if no buffer for the uri already exists.
---@since 15
---@param uri string|vim.Uri
---@return integer buf
function M.to_buf(uri)
  return vim.fn.bufadd(M.to_fname(uri))
end

return M
