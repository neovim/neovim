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
---Custom headers to send with the request. Supports basic key/value headers and empty headers as
---supported by curl. Does not support "@filename" style, internal header deletion ("Header:").
---A list value expands to one header per item: `{ Accept = { 'text/html', 'application/json' } }`.
---@field headers? table<string, string|string[]>

---@class vim.net.request.Response
---
---The HTTP body of the request.
---@field body string
---
---HTTP status code of the last response (after redirects), or 0 if the URL is not HTTP (`file://`).
---@field status integer
---
---Headers of the last response. Names are lowercase; a repeated header's values are a list:
---`{ ['content-type'] = 'text/html', ['set-cookie'] = { 'a=1', 'b=2' } }`
---@field headers table<string, string|string[]>

--- Makes an HTTP request to the given URL, asynchronously passing the result to the specified
--- `on_response`, `outpath` or `outbuf`.
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
--- @param method vim.net.HttpMethod (default: GET) The HTTP method (GET, POST, PUT, PATCH, HEAD, DELETE).
--- @param url string|vim.Uri The URL for the request.
--- @param opts? vim.net.request.Opts
--- @param on_response? fun(err?: string, response?: vim.net.request.Response) Invoked (|deferred|)
---   on request completion. On HTTP status >= 400, `err` is set and `response` has the status and
---   headers (empty `body`).
--- @overload fun(url: string|vim.Uri, opts?: vim.net.request.Opts, on_response?: fun(err?: string, response?: vim.net.request.Response)): vim.async.Closable
--- @return vim.async.Closable # Cancels the request or checks its status.
function M.request(method, url, opts, on_response)
  -- If no `method`, assume overload signature `request(url, opts, on_response)`.
  if type(method) ~= 'string' or vim.uri.parse(method) then
    on_response = opts --[[@as function?]]
    opts = url --[[@as table?]]
    url = method
    method = 'GET'
  end
  ---@cast opts vim.net.request.Opts?
  url = tostring(url)
  opts = opts or {}

  vim.validate('method', method, function(m)
    return http_methods[m] == true
  end, 'method should be one of GET, POST, PUT, PATCH, HEAD, DELETE')
  vim.validate('url', url, function(u)
    return vim.uri.parse(u) ~= nil
  end, 'URI')
  vim.validate('opts', opts, 'table', true)
  vim.validate('opts.headers', opts.headers, 'table', true)
  vim.validate('opts.body', opts.body, function(b)
    return (b == nil and true) or (type(b) == 'string' and not b:match('^@'))
  end, true, 'body should be string and not start with @')
  vim.validate('on_response', on_response, 'function', true)
  ---@cast on_response -vim.net.request.Opts

  local retry = opts.retry or 3
  local outbuf = opts.outbuf == 0 and vim.api.nvim_get_current_buf() or opts.outbuf

  -- Build curl command. `--fail`: don't write error response to `outpath`/`outbuf`.
  local args = { 'curl', '--fail', '--globoff', '--location', '--retry', tostring(retry) }
  vim.list_extend(args, opts.verbose and { '--verbose' } or { '--silent', '--show-error' })

  if opts.outpath then
    vim.list_extend(args, { '--output', opts.outpath })
  end

  -- curl -X HEAD does not work and advises to use --head instead. `--no-include`: the headers are
  -- in `header_json`, not the output.
  vim.list_extend(
    args,
    method == 'HEAD' and { '--head', '--no-include' } or { '--request', method }
  )

  if vim.list_contains({ 'POST', 'PUT', 'PATCH' }, method) and opts.body then
    vim.list_extend(args, { '--data-binary', '@-' })
  end

  if opts.headers then
    for key, value in pairs(opts.headers) do
      for _, v in ipairs(type(value) == 'table' and value or { value }) do
        if type(key) ~= 'string' or type(v) ~= 'string' then
          error('headers keys and values must be strings')
        end

        if key:match(':$') or key:match(';$') or key:match('^@') then
          error('header keys must not start with @ or end with : and ;')
        end

        if v == '' then
          vim.list_extend(args, { '--header', key .. ';' })
        else
          vim.list_extend(args, { '--header', key .. ': ' .. v })
        end
      end
    end
  end

  vim.list_extend(
    args,
    { '--write-out', '%{header_json}\\n%{response_code} %{size_download}', url }
  )

  local system_opts = opts.body and { stdin = opts.body } or {}
  local closing = false -- close() was called.
  local on_close --- @type fun()?
  local job = vim.system(args, system_opts, function(res)
    --- @cast res.stdout -?
    local status, headers, body = parse_output(res.stdout, not opts.outpath)
    local err ---@type string?
    if res.signal ~= 0 then
      err = ('Request killed with signal %d'):format(res.signal)
    elseif status >= 400 then
      err = ('Request failed with status %d'):format(status)
    elseif res.code ~= 0 then
      err = res.stderr ~= '' and res.stderr or ('Request failed with exit code %d'):format(res.code)
    end
    -- An HTTP error has a response; a failed transfer (e.g. DNS) does not.
    local response = (not err or status >= 400)
        and { body = body, status = status, headers = headers }
      or nil

    if on_close then
      on_close()
    end
    vim.schedule(function() -- Deferred so `outbuf` and `on_response` may call non-fast API.
      if res.code == 0 and outbuf and vim.api.nvim_buf_is_loaded(outbuf) then
        local lines = vim.split(body, '\n', { plain = true })
        vim.api.nvim_buf_set_lines(outbuf, 0, -1, true, lines)
      end
      if on_response then
        on_response(err, response)
      end
    end)
  end)

  return {
    -- Calls `callback` after the request stops. |vim.async.Closable|
    --- @param callback? fun()
    close = function(_, callback)
      closing = true
      if job:is_closing() then -- Stopped already.
        if callback then
          callback()
        end
        return
      end
      on_close = callback
      job:kill('sigint')
    end,
    -- Returns true if close() was called, or the request stopped.
    is_closing = function()
      return closing or job:is_closing()
    end,
  }
end

return M
