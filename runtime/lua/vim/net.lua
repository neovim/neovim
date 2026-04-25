local M = {}

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
---@field headers? table<string, string>

---@class vim.net.request.Response
---
---The HTTP body of the request
---@field body string

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
--- vim.net.request(
---   'https://api.github.com/repos/neovim/neovim',
---   {},
---   function (err, res)
---     if err then return end
---     local stars = vim.json.decode(res.body).stargazers_count
---     vim.print(('Neovim currently has %d stars'):format(stars))
---   end
--- )
---
--- -- Write to both file and current buffer, but cancel it.
--- local job = vim.net.request('https://neovim.io/charter/', {
---   outpath = 'vision.html',
---   outbuf = 0,
--- })
--- job:close()
---
--- -- Add custom headers in the request.
--- vim.net.request('https://neovim.io/charter/', {
---   headers = { Authorization = 'Bearer XYZ' },
--- })
---
--- -- POST request with body.
--- vim.net.request('POST', 'https://example.com/api', {
---   body = '{"key": "value"}',
--- })
--- ```
---
--- @param method string The HTTP method (GET, POST, PUT, PATCH, HEAD, DELETE) or URL for GET request.
--- @param url string The URL for the request or opts table.
--- @param opts? vim.net.request.Opts
--- @param on_response? fun(err: string?, response: vim.net.request.Response?)
--- Callback invoked on request completion. The `body` field in the response
--- parameter contains the raw response data (text or binary).
--- @return { close: fun() } # Object with `close()` method which cancels the request.
function M.request(method, url, opts, on_response)
  local http_methods = {
    GET = true,
    POST = true,
    PUT = true,
    PATCH = true,
    HEAD = true,
    DELETE = true,
  }

  if on_response == nil then
    -- old behavior
    vim.validate('url', method, 'string')
    vim.validate('opts', url, 'table', true)
    vim.validate('on_response', opts, 'function', true)

    local original_opts = url
    local original_on_resp = opts
    url = method
    method = 'GET'
    opts = original_opts or {}
    on_response = original_on_resp
  else
    -- new behavior
    vim.validate('method', method, 'string')
    vim.validate('url', url, 'string')
    vim.validate('opts', opts, 'table', true)
    vim.validate('on_response', on_response, 'function', true)

    opts = opts or {}
    method = method:upper()

    if not http_methods[method:upper()] then
      error(
        'invalid HTTP method: '
          .. method
          .. '. Supported methods: GET, POST, PUT, PATCH, HEAD, DELETE'
      )
    end
  end

  local retry = opts.retry or 3

  -- Build curl command
  local args = { 'curl' }
  if opts.verbose then
    table.insert(args, '--verbose')
  else
    vim.list_extend(args, { '--silent', '--show-error', '--fail' })
  end
  vim.list_extend(args, { '--location', '--retry', tostring(retry) })

  if opts.outpath then
    vim.list_extend(args, { '--output', opts.outpath })
  end

  if method == 'HEAD' then
    table.insert(args, '-I')
  elseif vim.tbl_contains({ 'POST', 'PUT', 'PATCH' }, method) then
    if opts.body ~= nil then
      vim.validate('opts.body', opts.body, 'string')
      vim.list_extend(args, { '-d', opts.body })
    end
  end

  if opts.headers then
    vim.validate('opts.headers', opts.headers, 'table', true)
    for key, value in pairs(opts.headers) do
      if type(key) ~= 'string' or type(value) ~= 'string' then
        error('headers keys and values must be strings')
      end

      if key:match(':$') or key:match(';$') or key:match('^@') then
        error('header keys must not start with @ or end with : and ;')
      end

      if value == '' then
        vim.list_extend(args, { '-H', key .. ';' })
      else
        vim.list_extend(args, { '-H', key .. ': ' .. value })
      end
    end
  end

  table.insert(args, url)

  local job = vim.system(args, {}, function(res)
    ---@type string?, vim.net.request.Response?
    local err, response = nil, nil
    if res.signal ~= 0 then
      err = ('Request killed with signal %d'):format(res.signal)
    elseif res.code ~= 0 then
      err = res.stderr ~= '' and res.stderr or ('Request failed with exit code %d'):format(res.code)
    else
      if on_response then
        response = { body = res.stdout or '' }
      end
    end

    -- nvim_buf_is_loaded and nvim_buf_set_lines are not allowed in fast context
    vim.schedule(function()
      if res.code == 0 and opts.outbuf and vim.api.nvim_buf_is_loaded(opts.outbuf) then
        local lines = vim.split(res.stdout, '\n', { plain = true })
        vim.api.nvim_buf_set_lines(opts.outbuf, 0, -1, true, lines)
      end
    end)

    if on_response then
      on_response(err, response)
    end
  end)

  return {
    close = function()
      job:kill('sigint')
    end,
  }
end

return M
