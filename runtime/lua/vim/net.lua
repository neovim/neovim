local M = {}

--- Makes an HTTP GET request to the given URL (asynchronous).
---
--- This function operates in one mode:
---   - Asynchronous (non-blocking): Returns immediately and passes the response object to the
---   provided `on_response` handler on completetion.
---
--- @param url string The URL for the request.
--- @param opts? table Optional parameters:
---   - `verbose` (boolean|nil): Enables verbose output.
---   - `retry`   (integer|nil): Number of retries on transient failures (default: 3).
---   - `outpath`  (string|nil): File path to save the response body to. If set, the `body` value in the Response Object will be `true` instead of the response body.
--- @param on_response fun(err?: string, response?: { body: string|boolean }) Callback invoked on request
--- completetion. The `body` field in the response object contains the raw response data (text or binary).
--- Called with (err, nil) on failure, or (nil, { body = string|boolean }) on success.
function M.request(url, opts, on_response)
  vim.validate({
    url = { url, 'string' },
    opts = { opts, 'table', true },
    on_response = { on_response, 'function' },
  })

  opts = opts or {}
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

  table.insert(args, url)

  local function on_exit(res)
    local err_msg = nil
    local response = nil

    if res.code ~= 0 then
      err_msg = (res.stderr ~= '' and res.stderr)
        or string.format('Request failed with exit code %d', res.code)
    else
      response = {
        body = opts.outpath and true or res.stdout,
      }
    end

    if on_response then
      on_response(err_msg, response)
    end
  end

  vim.system(args, {}, on_exit)
end

return M
