local M = {}

local http_methods = {
  GET = true,
  POST = true,
  PUT = true,
  PATCH = true,
  HEAD = true,
  DELETE = true,
}

--- Splits curl stdout `<body><header_json>\n<status> <body size>` (see `--write-out`) into the
--- status, headers and body of the last response (after redirects).
--- @param stdout string
--- @param has_body boolean False if the body is in `--output`.
--- @return integer status 0 if there is no HTTP response (e.g. `file://`).
--- @return table<string, string|string[]> headers
--- @return string body
local function parse_output(stdout, has_body)
  local trailer, _, code, body_size = stdout:find('\n(%d+) (%d+)$')
  if not trailer then -- Killed.
    return 0, {}, stdout
  end
  local status = tonumber(code) --[[@as integer]]
  local body_end = (has_body and tonumber(body_size) or 0) --[[@as integer]]
  local ok, json = pcall(vim.json.decode, stdout:sub(body_end + 1, trailer - 1))
  ---@cast json table<string, string[]>
  local headers = {} ---@type table<string, string|string[]>
  for name, values in pairs(ok and json or {}) do
    headers[name] = #values == 1 and values[1] or values
  end
  return status, headers, stdout:sub(1, body_end)
end

---@alias vim.net.HttpMethod string "GET" | "POST" | "PUT" | "PATCH" | "HEAD" | "DELETE"

---@class vim.net.request.Opts
---@inlinedoc
---
---Enables verbose output.
---@field verbose? boolean
---
---Number of retries on transient failures (default: 3).
---@field retry? integer
---
---Request body for POST/PUT/PATCH requests.
---@field body? string
---
---File path to save the response body to.
---@field outpath? string
---
---Buffer to save the response body to.
---@field outbuf? integer
---
---Custom headers to send with the request (not visible to other processes, for security, unlike
---curl args). Supports key/value, or empty value; does not support "@filename" style, nor internal
---header deletion ("Header:"). List value expands to one header per item: `{ Accept = { 'text/html', 'application/json' } }`.
---@field headers? table<string, string|string[]>

---@class vim.net.request.Response
---
---The HTTP body of the request.
---@field body string
---
---Status code of the last response (after redirects), or 0 if the protocol has none (`file://`).
---@field status integer
---
---Headers of the last response. Names are lowercase; a repeated header's values are a list:
---`{ ['content-type'] = 'text/html', ['set-cookie'] = { 'a=1', 'b=2' } }`
---@field headers table<string, string|string[]>

--- Makes an HTTP request to the given URL, asynchronously passing the result to the specified
--- `on_response`, `outpath` or `outbuf`.
---
--- Ignores user ".curlrc". Use environment variables to set a proxy or CA bundle (`https_proxy`,
--- `no_proxy`, `CURL_CA_BUNDLE`).
---
--- Examples:
--- ```lua
--- -- Write response body to file.
--- vim.net.request('https://neovim.io/charter/', {
---   outpath = 'vision.html',
--- })
---
--- -- Process the response.
--- vim.net.request('https://api.github.com/repos/neovim/neovim', {}, function(err, res)
---   if err then return end
---   local stars = vim.json.decode(res.body).stargazers_count
---   vim.print(('Neovim currently has %d stars'):format(stars))
---   vim.print(res.status, res.headers['content-type'])
--- end)
---
--- -- Write to both file and current buffer, but cancel it.
--- local job = vim.net.request('https://neovim.io/charter/', {
---   outpath = 'vision.html',
---   outbuf = 0,
--- })
--- job:close()
---
--- -- Await the response in a task (|lua-async|). Closing the task cancels the request.
--- vim.async.run(function()
---   local err, res = vim.async.await(3, vim.net.request, 'https://neovim.io/charter/', {})
--- end)
---
--- -- Add custom headers in the request.
--- local url = vim.uri.new({
---   scheme = 'https',
---   host = 'api.github.com',
---   path = '/search/repositories',
---   query = { q = 'vim lua' },
--- })
--- vim.net.request(url, {
---   headers = { Authorization = 'Bearer XYZ' },
--- })
---
--- -- POST request with body.
--- vim.net.request('POST', 'https://example.com/api', {
---   body = '{"key": "value"}',
---   headers = {['Content-Type'] = 'application/json' }
--- })
--- ```
---
--- @param method? vim.net.HttpMethod (default: GET) The HTTP method (GET, POST, PUT, PATCH, HEAD, DELETE).
--- @param url string|vim.Uri The URL for the request.
--- @param opts? vim.net.request.Opts
--- @param on_response? fun(err?: string, response?: vim.net.request.Response) Invoked (|deferred|)
---   on request completion. On HTTP status >= 400, `err` is set and `response` has the status and
---   headers (empty `body`). `err` is also set after `close()`, or if writing `outbuf` fails
---   (`response` is complete).
--- @overload fun(url: string|vim.Uri, opts?: vim.net.request.Opts, on_response?: fun(err?: string, response?: vim.net.request.Response)): vim.async.Closable
--- @return vim.async.Closable # Cancels the request or checks its status.
function M.request(method, url, opts, on_response)
  -- If `url` is `opts`, assume overload signature `request(url, opts, on_response)`.
  if url == nil or (type(url) == 'table' and url.scheme == nil) then
    on_response = opts --[[@as function?]]
    opts = url --[[@as table?]]
    url = method --[[@as string|vim.Uri]]
    method = nil
  end
  ---@cast opts vim.net.request.Opts?
  method = method or 'GET'
  if type(url) == 'table' then
    url = tostring(vim.uri.new(url))
  end
  opts = opts or {}

  vim.validate('method', method, function(m)
    return http_methods[m] == true
  end, 'method should be one of GET, POST, PUT, PATCH, HEAD, DELETE')
  vim.validate('url', url, function(u)
    return type(u) == 'string' and vim.uri.parse(u) ~= nil
  end, 'URI')
  ---@cast url string
  vim.validate('opts', opts, 'table', true)
  vim.validate('opts.headers', opts.headers, 'table', true)
  vim.validate('opts.outpath', opts.outpath, 'string', true)
  vim.validate('opts.outbuf', opts.outbuf, 'number', true)
  vim.validate('opts.retry', opts.retry, 'number', true)
  vim.validate('opts.body', opts.body, 'string', true)
  vim.validate('on_response', on_response, 'function', true)
  ---@cast on_response -vim.net.request.Opts

  local retry = opts.retry or 3
  local outbuf = opts.outbuf == 0 and vim.api.nvim_get_current_buf() or opts.outbuf
  local outpath = opts.outpath and vim.fs.abspath(opts.outpath) -- Absolute in case of :cd.

  -- Build curl command.
  -- --disable: (must be first) ignore ".curlrc", which can change the output.
  -- --fail: don't write error response to `outpath`/`outbuf`.
  local args =
    { 'curl', '--disable', '--fail', '--globoff', '--location', '--retry', tostring(retry) }
  vim.list_extend(args, opts.verbose and { '--verbose' } or { '--silent', '--show-error' })

  if outpath then
    -- --remove-on-error: don't leave a partial file.
    vim.list_extend(args, { '--output', outpath, '--remove-on-error' })
  end

  local req_body = vim.list_contains({ 'POST', 'PUT', 'PATCH' }, method) and opts.body or nil
  if method == 'HEAD' then
    -- curl -X HEAD does not work and advises to use --head instead.
    -- --no-include: headers are in `header_json`, not the output.
    vim.list_extend(args, { '--head', '--no-include' })
  elseif method ~= 'GET' and not (method == 'POST' and req_body) then
    -- Not for GET, or POST with body (--data-binary): --request also forces the method after a
    -- 301/302/303 redirect, which should switch to GET.
    vim.list_extend(args, { '--request', method })
  end

  -- Headers (may contain secrets) go on stdin instead of argv, for security.
  local header_stdin = {} ---@type string[]
  if opts.headers then
    for key, value in pairs(opts.headers) do
      local values = type(value) == 'table' and value or { value }
      if type(key) ~= 'string' or not vim.islist(values) then
        error('headers keys/values must be strings')
      end

      if key:match(':$') or key:match(';$') or key:match('^@') then
        error('header keys must not start with @ or end with : and ;')
      end

      for _, v in ipairs(values) do
        if type(v) ~= 'string' then
          error('headers keys/values must be strings')
        end

        if key:find('[\r\n]') or v:find('[\r\n]') then
          error('headers must not contain CR or LF')
        end

        -- "Key: " would delete the header, "Key;" sends it empty.
        local header = v:match('^%s*$') and ('%s;'):format(key) or ('%s: %s'):format(key, v)
        table.insert(header_stdin, header)
      end
    end
  end

  -- Body is sent via tempfile bc stdin has the headers. Written last, after validation.
  local body_path ---@type string?
  if req_body then
    local tmpl = vim.fs.joinpath(assert(vim.uv.os_tmpdir()), 'nvim.net.XXXXXX')
    local fd, path = assert(vim.uv.fs_mkstemp(tmpl)) -- Permissions: 0600.
    assert(vim.uv.fs_write(fd, req_body))
    vim.uv.fs_close(fd)
    body_path = path
    vim.list_extend(args, { '--data-binary', ('@%s'):format(path) })
  end

  vim.list_extend(args, {
    '--write-out',
    '%{header_json}\\n%{response_code} %{size_download}',
    '--header',
    '@-',
    url,
  })

  local system_opts = { stdin = table.concat(header_stdin, '\n') }
  local closing = false -- close() was called.
  local job = vim.system(args, system_opts, function(res)
    if body_path then
      os.remove(body_path)
    end
    vim.schedule(function() -- Deferred so `outbuf` and `on_response` may call non-fast API.
      --- @cast res.stdout -?
      local killed = closing or res.signal ~= 0 -- If curl is killed: partial output, no trailer.
      local status, headers, body = parse_output(killed and '' or res.stdout, not outpath)
      local err ---@type string?
      if closing then
        err = 'Request closed'
      elseif res.signal ~= 0 then
        err = ('Request killed with signal %d'):format(res.signal)
      elseif status >= 400 then
        err = ('Request failed with status %d'):format(status)
      elseif res.code ~= 0 then
        err = res.stderr ~= '' and res.stderr
          or ('Request failed with exit code %d'):format(res.code)
      end
      -- An HTTP error has a response; a failed transfer (e.g. DNS) does not.
      local response = (not err or status >= 400)
          and { body = body, status = status, headers = headers }
        or nil

      if not err and outbuf and vim.api.nvim_buf_is_loaded(outbuf) then
        local ok, write_err = pcall(function()
          local text = outpath and vim.fn.readblob(outpath) or body
          vim.api.nvim_buf_set_lines(outbuf, 0, -1, true, text)
        end)
        if not ok then
          err = write_err
          if not on_response then
            error(err, 0)
          end
        end
      end
      if on_response then
        on_response(err, response)
      end
    end)
  end)

  return {
    -- Calls `on_close` after the request stops. |vim.async.Closable|
    --- @param on_close? fun()
    close = function(_, on_close)
      closing = true
      job:close(on_close)
    end,
    -- Returns true if close() was called, or the request stopped.
    is_closing = function()
      return closing or job:is_closing()
    end,
  }
end

return M
